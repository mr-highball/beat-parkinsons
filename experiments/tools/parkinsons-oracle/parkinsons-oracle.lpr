{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program ParkinsonsOracle;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, fpjson, jsonparser, parkinsonsoracle.claims,
  parkinsonsoracle.catalog, parkinsonsoracle.http;

const
  CProtocol = '2025-11-25';
  DefaultAssessmentPageSize = 8;
  MaximumAssessmentPageSize = 100;
  CToolsJSON =
    '{"tools":[' +
    '{"name":"oracle_query","description":"Find frozen local claims with the requested symptom, ' +
      'ingredient, preparation, hypothesis direction, evidence trend, and scope. Default scope returns ' +
      'only directional verdicts with assessments. Maybe remains provisional.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},"inputSchema":{"type":"object",' +
      '"additionalProperties":false,"properties":{"symptom":{"type":"string"},' +
      '"ingredient":{"type":"string"},"preparation":{"type":"string"},' +
      '"direction":{"enum":["reduces","worsens"]},"trend":{"enum":["eases","worsens",""]},' +
      '"scope":{"enum":["directional","assessed","frozen"]},' +
      '"verdict":{"enum":["True","False","Maybe True","Maybe False","Unknown","Unreviewed"]},' +
      '"round":{"type":"integer","minimum":1,"maximum":7},"offset":{"type":"integer","minimum":0},' +
      '"limit":{"type":"integer","minimum":1,"maximum":100}}}},' +
    '{"name":"oracle_claim","description":"Read one frozen claim with its rationale, study ' +
      'assessments, citations and queue counts. Use assessment_limit for a smaller first reply ' +
      'and next_assessment_offset to continue. Use assessment_study in place of pagination ' +
      'to select one exact case-sensitive ledger key. With neither, all assessments are returned.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},"inputSchema":{"type":"object",' +
      '"additionalProperties":false,"required":["round","id"],"properties":{' +
      '"round":{"type":"integer","minimum":1,"maximum":7},' +
      '"id":{"type":"string","pattern":"^[0-9]{4}$"},' +
      '"assessment_offset":{"type":"integer","minimum":0},' +
      '"assessment_limit":{"type":"integer","minimum":1,"maximum":100},' +
      '"assessment_study":{"type":"string","minLength":1}},' +
      '"not":{"anyOf":[{"required":["assessment_study","assessment_offset"]},' +
      '{"required":["assessment_study","assessment_limit"]}]}}},' +
    '{"name":"oracle_search_catalog","description":"Search the local research text index with ' +
      'literal terms. Word matches are discovery leads and carry no evidence or direction grade.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},"inputSchema":{"type":"object",' +
      '"additionalProperties":false,"required":["terms"],"properties":{"terms":{"type":"string"},' +
      '"period":{"type":"string","pattern":"^[0-9]{4}-[0-9]{4}$"},' +
      '"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":100}}}},' +
    '{"name":"oracle_find_sources","description":"Find archived source documents by PMID, PMCID, ' +
      'DOI, NCT, ACTRN, ISRCTN, IRCT, DRKS or TCTR ID. Matches come from source metadata. ' +
      'Use oracle_search_catalog for citation ' +
      'mentions and other catalog notes.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},"inputSchema":{"type":"object",' +
      '"additionalProperties":false,"required":["identifiers"],"properties":{"identifiers":{' +
      '"type":"array","minItems":1,"maxItems":100,"items":{"type":"string","minLength":1}}}}},' +
    '{"name":"oracle_status","description":"Check the pinned claim revision, evidence counts and ' +
      'the local research text index coverage and freshness.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},' +
      '"inputSchema":{"type":"object","additionalProperties":false}},' +
    '{"name":"oracle_filter_options","description":"List frozen symptom, ingredient and preparation ' +
      'choices and their unambiguous aliases.",' +
      '"annotations":{"readOnlyHint":true,"openWorldHint":false},' +
      '"inputSchema":{"type":"object","additionalProperties":false}}]}';

type
  TOracle = class
  private
    FRepoRoot: String;
    FClaims: TClaimIndex;
    FCatalog: TResearchCatalog;
    function Index: TClaimIndex;
    function Catalog: TResearchCatalog;
    function Status: TJSONObject;
  public
    constructor Create(const ARepoRoot: String);
    destructor Destroy; override;
    procedure RefreshCatalog;
    function Invoke(const AName: String; AArguments: TJSONObject): TJSONObject;
    function InvokeWeb(const AName: String; AArguments: TJSONObject): TJSONObject;
  end;

function ReadString(AArguments: TJSONObject; const AName, ADefault: String): String;
var
  LData: TJSONData;
begin
  LData := AArguments.Find(AName);
  if LData = nil then
    Exit(ADefault);
  if LData.JSONType <> jtString then
    raise EConvertError.Create('Expected a string for ' + AName + '.');
  Result := LData.AsString;
end;

function ReadInteger(AArguments: TJSONObject; const AName: String;
  ADefault, AMinimum, AMaximum: Integer): Integer;
var
  LData: TJSONData;
begin
  LData := AArguments.Find(AName);
  if LData = nil then
    Exit(ADefault);
  if (LData.JSONType <> jtNumber) or not TryStrToInt(LData.AsJSON, Result) or
    (Result < AMinimum) or (Result > AMaximum) then
    raise EConvertError.Create('Invalid integer for ' + AName + '.');
end;

procedure RequireFields(AArguments: TJSONObject; const AAllowed: array of String);
var
  LIndex: Integer;
  LName: String;
  LExpected: String;
  LFound: Boolean;
begin
  for LIndex := 0 to AArguments.Count - 1 do
  begin
    LName := AArguments.Names[LIndex];
    LFound := False;
    for LExpected in AAllowed do
      if LName = LExpected then
      begin
        LFound := True;
        Break;
      end;
    if not LFound then
      raise EConvertError.Create('Unknown argument: ' + LName);
  end;
end;

constructor TOracle.Create(const ARepoRoot: String);
begin
  inherited Create;
  FRepoRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARepoRoot));
  if not DirectoryExists(FRepoRoot + 'research') or not DirectoryExists(FRepoRoot + 'experiments') then
    raise EInOutError.Create('Pass the beat-parkinsons repository root.');
end;

destructor TOracle.Destroy;
begin
  FCatalog.Free;
  FClaims.Free;
  inherited Destroy;
end;

function TOracle.Index: TClaimIndex;
begin
  if (FClaims <> nil) and not FClaims.IsCurrent then
    FreeAndNil(FClaims);
  if FClaims = nil then
    FClaims := TClaimIndex.Create(FRepoRoot);
  Result := FClaims;
end;

function TOracle.Catalog: TResearchCatalog;
var
  LDirectory: String;
begin
  if FCatalog = nil then
  begin
    LDirectory := FRepoRoot + 'build' + PathDelim + 'parkinsons-oracle';
    if not ForceDirectories(LDirectory) then
      raise EInOutError.Create('Unable to open the local oracle build directory.');
    FCatalog := TResearchCatalog.Create(FRepoRoot, LDirectory + PathDelim + 'catalog.sqlite3');
  end;
  Result := FCatalog;
end;

function TOracle.Status: TJSONObject;
var
  LCatalogState: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('claims', Index.Status);
    try
      LCatalogState := Catalog.Status;
    except
      on LException: Exception do
        LCatalogState := TJSONObject.Create(['ready', False, 'error', LException.Message]);
    end;
    Result.Add('catalog', LCatalogState);
  except
    Result.Free;
    raise;
  end;
end;

procedure TOracle.RefreshCatalog;
begin
  Catalog.Refresh;
end;

function TOracle.Invoke(const AName: String; AArguments: TJSONObject): TJSONObject;
var
  LQuery: TClaimQuery;
  LId: String;
  LDigit: Char;
  LPeriod: String;
  LIndex: Integer;
  LTerms: String;
  LAssessmentOffset: Integer;
  LAssessmentLimit: Integer;
  LAssessmentStudy: String;
  LIdentifiers: TJSONData;
begin
  case IndexStr(AName, ['oracle_query', 'oracle_claim', 'oracle_search_catalog',
    'oracle_status', 'oracle_filter_options', 'oracle_find_sources']) of
    0:
      begin
        RequireFields(AArguments, ['symptom', 'ingredient', 'preparation', 'direction',
          'trend', 'scope', 'verdict', 'round', 'offset', 'limit']);
        LQuery := Default(TClaimQuery);
        LQuery.Symptom := ReadString(AArguments, 'symptom', '');
        LQuery.Ingredient := ReadString(AArguments, 'ingredient', '');
        LQuery.Preparation := ReadString(AArguments, 'preparation', '');
        LQuery.Direction := ReadString(AArguments, 'direction', '');
        LQuery.Trend := ReadString(AArguments, 'trend', '');
        LQuery.Scope := ReadString(AArguments, 'scope', 'directional');
        LQuery.Verdict := ReadString(AArguments, 'verdict', '');
        LQuery.Round := ReadInteger(AArguments, 'round', 0, 1, 7);
        LQuery.Offset := ReadInteger(AArguments, 'offset', 0, 0, MaxInt);
        LQuery.Limit := ReadInteger(AArguments, 'limit', 12, 1, 100);
        Result := Index.Query(LQuery);
      end;
    1:
      begin
        RequireFields(AArguments, ['round', 'id', 'assessment_offset', 'assessment_limit',
          'assessment_study']);
        LId := ReadString(AArguments, 'id', '');
        LIndex := ReadInteger(AArguments, 'round', 0, 1, 7);
        if (Length(LId) <> 4) or (LIndex = 0) then
          raise EConvertError.Create('Provide the round and four-digit claim ID.');
        for LDigit in LId do
          if not (LDigit in ['0'..'9']) then
            raise EConvertError.Create('Provide a four-digit claim ID.');
        LAssessmentStudy := ReadString(AArguments, 'assessment_study', '');
        if AArguments.Find('assessment_study') <> nil then
        begin
          if (Trim(LAssessmentStudy) = '') or (Pos(#0, LAssessmentStudy) <> 0) then
          begin
            raise EConvertError.Create('Provide a nonempty assessment study key.');
          end;
          if (AArguments.Find('assessment_offset') <> nil) or
            (AArguments.Find('assessment_limit') <> nil) then
          begin
            raise EConvertError.Create('Use assessment_study without assessment paging.');
          end;
        end;
        LAssessmentOffset := ReadInteger(AArguments, 'assessment_offset', 0, 0, MaxInt);
        LAssessmentLimit := ReadInteger(AArguments, 'assessment_limit', -1, 1,
          MaximumAssessmentPageSize);
        if (LAssessmentLimit = -1) and (AArguments.Find('assessment_offset') <> nil) then
        begin
          LAssessmentLimit := DefaultAssessmentPageSize;
        end;
        Result := Index.Claim(LIndex, LId, LAssessmentOffset, LAssessmentLimit,
          LAssessmentStudy);
      end;
    2:
      begin
        RequireFields(AArguments, ['terms', 'period', 'offset', 'limit']);
        LTerms := ReadString(AArguments, 'terms', '');
        LPeriod := ReadString(AArguments, 'period', '');
        LIndex := ReadInteger(AArguments, 'offset', 0, 0, MaxInt);
        if (Trim(LTerms) = '') or (Length(LTerms) > 512) then
          raise EConvertError.Create('Provide nonempty search terms of at most 512 bytes.');
        Result := Catalog.Search(LTerms, LPeriod, LIndex,
          ReadInteger(AArguments, 'limit', 12, 1, 100));
      end;
    3:
      begin
        RequireFields(AArguments, []);
        Result := Status;
      end;
    4:
      begin
        RequireFields(AArguments, []);
        Result := Index.FilterOptions;
      end;
    5:
      begin
        RequireFields(AArguments, ['identifiers']);
        LIdentifiers := AArguments.Find('identifiers');
        if not (LIdentifiers is TJSONArray) then
        begin
          raise EConvertError.Create('Provide an array of source identifiers.');
        end;
        Result := Catalog.FindSources(TJSONArray(LIdentifiers));
      end;
  else
    raise EConvertError.Create('Unknown tool: ' + AName);
  end;
end;

function TOracle.InvokeWeb(const AName: String; AArguments: TJSONObject): TJSONObject;
var
  LPath: String;
  LOffset: Integer;
begin
  if AName <> 'oracle_read_source' then
  begin
    Exit(Invoke(AName, AArguments));
  end;
  RequireFields(AArguments, ['path', 'offset']);
  LPath := ReadString(AArguments, 'path', '');
  LOffset := ReadInteger(AArguments, 'offset', 0, 0, MaxInt);
  try
    Result := Catalog.ReadSource(LPath, LOffset);
  except
    on ESourceReadError do
    begin
      raise;
    end;
    on Exception do
    begin
      raise EConvertError.Create('Cannot read the currently indexed source.');
    end;
  end;
end;

function RpcError(AId: TJSONData; ACode: Integer; const AMessage: String): TJSONObject;
var
  LId: TJSONData;
begin
  if AId = nil then
    LId := TJSONNull.Create
  else
    LId := AId.Clone;
  Result := TJSONObject.Create(['jsonrpc', '2.0', 'id', LId, 'error',
    TJSONObject.Create(['code', ACode, 'message', AMessage])]);
end;

function ToolContent(const AText: String; AFailed: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create(['content',
    TJSONArray.Create([TJSONObject.Create(['type', 'text', 'text', AText])])]);
  if AFailed then
    Result.Add('isError', True);
end;

function CallTool(AOracle: TOracle; AParams: TJSONObject): TJSONObject;
var
  LName: String;
  LArguments: TJSONData;
  LArgumentsOwned: TJSONObject;
  LData: TJSONObject;
begin
  LArgumentsOwned := nil;
  try
    try
      LName := ReadString(AParams, 'name', '');
      LArguments := AParams.Find('arguments');
      if LArguments = nil then
      begin
        LArgumentsOwned := TJSONObject.Create;
        LArguments := LArgumentsOwned;
      end;
      if LArguments.JSONType <> jtObject then
        raise EConvertError.Create('Tool arguments must be an object.');
      LData := AOracle.Invoke(LName, TJSONObject(LArguments));
      try
        Result := ToolContent(LData.AsJSON, False);
      finally
        LData.Free;
      end;
    except
      on LException: Exception do
        Result := ToolContent(LException.Message, True);
    end;
  finally
    LArgumentsOwned.Free;
  end;
end;

function HandleRequest(AOracle: TOracle; AData: TJSONData): TJSONObject;
var
  LRequest: TJSONObject;
  LMethod: TJSONData;
  LRpVersion: TJSONData;
  LId: TJSONData;
  LParams: TJSONData;
  LOwnedParams: TJSONObject;
  LResult: TJSONData;
  LVersion: String;
begin
  if AData.JSONType <> jtObject then
    Exit(RpcError(nil, -32600, 'Invalid Request'));
  LRequest := TJSONObject(AData);
  LMethod := LRequest.Find('method');
  LRpVersion := LRequest.Find('jsonrpc');
  LId := LRequest.Find('id');
  if (LRpVersion = nil) or (LRpVersion.JSONType <> jtString) or
    (LRpVersion.AsString <> '2.0') or (LMethod = nil) or (LMethod.JSONType <> jtString) then
    Exit(RpcError(nil, -32600, 'Invalid Request'));
  if LId = nil then
    Exit(nil);
  if not (LId.JSONType in [jtString, jtNumber]) then
    Exit(RpcError(nil, -32600, 'Invalid request ID'));
  LParams := LRequest.Find('params');
  LOwnedParams := nil;
  if LParams = nil then
  begin
    LOwnedParams := TJSONObject.Create;
    LParams := LOwnedParams;
  end;
  try
    if LParams.JSONType <> jtObject then
      Exit(RpcError(LId, -32602, 'Invalid params'));
    case IndexStr(LMethod.AsString, ['initialize', 'ping', 'tools/list', 'tools/call']) of
      0:
        begin
          LVersion := TJSONObject(LParams).Get('protocolVersion', CProtocol);
          if (LVersion <> '2025-06-18') and (LVersion <> '2025-03-26') and
            (LVersion <> '2024-11-05') then
            LVersion := CProtocol;
          LResult := TJSONObject.Create(['protocolVersion', LVersion,
            'capabilities', TJSONObject.Create(['tools', TJSONObject.Create]),
            'serverInfo', TJSONObject.Create(['name', 'parkinsons-oracle', 'version', '0.1.0']),
            'instructions', 'Use reviewed claims and source locators before searching elsewhere. ' +
              'Hypothesis direction is the frozen wording. An Unknown is an open question.']);
        end;
      1: LResult := TJSONObject.Create;
      2: LResult := GetJSON(CToolsJSON, True);
      3: LResult := CallTool(AOracle, TJSONObject(LParams));
    else
      Exit(RpcError(LId, -32601, 'Method not found'));
    end;
    Result := TJSONObject.Create(['jsonrpc', '2.0', 'id', LId.Clone, 'result', LResult]);
  finally
    LOwnedParams.Free;
  end;
end;

procedure Serve(AOracle: TOracle);
var
  LLine: String;
  LData: TJSONData;
  LResponse: TJSONObject;
begin
  while not Eof(Input) do
  begin
    ReadLn(Input, LLine);
    LData := nil;
    LResponse := nil;
    try
      try
        LData := GetJSON(LLine, True);
        if LData = nil then
          LResponse := RpcError(nil, -32700, 'Parse error');
      except
        on EParserError do
          LResponse := RpcError(nil, -32700, 'Parse error');
        on EJSON do
          LResponse := RpcError(nil, -32700, 'Parse error');
      end;
      if LData <> nil then
      begin
        try
          LResponse := HandleRequest(AOracle, LData);
        except
          on LException: Exception do
          begin
            WriteLn(StdErr, LException.Message);
            LResponse := RpcError(nil, -32603, 'Internal error');
          end;
        end;
      end;
      if LResponse <> nil then
      begin
        WriteLn(LResponse.AsJSON);
        Flush(Output);
      end;
    finally
      LResponse.Free;
      LData.Free;
    end;
  end;
end;

procedure Run;
var
  LOracle: TOracle;
  LResult: TJSONObject;
  LCommand: String;
  LPort: Integer;
  LWebRoot: String;
  LLanBinding: String;
  LOutputDirectory: String;
  LRepository: String;
  LFile: TStringStream;
begin
  if ParamCount < 2 then
    raise EConvertError.Create('Use serve, index, status, web or model, followed by the repository path.');
  LCommand := ParamStr(1);
  LOracle := TOracle.Create(ParamStr(2));
  try
    case IndexStr(LCommand, ['serve', 'index', 'status', 'web', 'model']) of
      0: Serve(LOracle);
      1:
        begin
          LOracle.RefreshCatalog;
          LResult := LOracle.Catalog.Status;
          try
            WriteLn(LResult.AsJSON);
          finally
            LResult.Free;
          end;
        end;
      2:
        begin
          LResult := LOracle.Status;
          try
            WriteLn(LResult.AsJSON);
          finally
            LResult.Free;
          end;
        end;
      3:
        begin
          LPort := 8795;
          if ParamCount >= 3 then
            LPort := StrToInt(ParamStr(3));
          if (LPort < 1) or (LPort > 65535) then
            raise EConvertError.Create('The web port must be between 1 and 65535.');
          LWebRoot := LOracle.FRepoRoot + 'build' + PathDelim + 'parkinsons-oracle' +
            PathDelim + 'web';
          LLanBinding := '';
          if ParamCount >= 4 then
            LLanBinding := ParamStr(4);
          if ParamCount > 4 then
            raise EArgumentException.Create('Use web <repo> [port] [private-ipv4/prefix].');
          ServeOracleWeb(LWebRoot, LPort, LOracle.InvokeWeb, LLanBinding);
        end;
      4:
        begin
          if (ParamCount < 3) or (ParamCount > 4) then
            raise EArgumentException.Create('Use model <repo> <output-dir> [repository-url].');
          LOutputDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3)));
          if DirectoryExists(LOutputDirectory) or
            FileExists(ExcludeTrailingPathDelimiter(LOutputDirectory)) then
            raise EInOutError.Create('The public model requires a new output directory.');
          LRepository := '';
          if ParamCount = 4 then
            LRepository := ParamStr(4);
          if (LRepository <> '') and not StartsStr('https://github.com/', LRepository) then
            raise EArgumentException.Create('Use an HTTPS GitHub repository URL for citations.');
          if not ForceDirectories(LOutputDirectory) then
            raise EInOutError.Create('Unable to create the public model directory.');
          LOracle.RefreshCatalog;
          LResult := LOracle.Index.StaticModel(LRepository);
          try
            LResult.Add('catalog', LOracle.Catalog.Status(False));
            LFile := TStringStream.Create(LResult.AsJSON);
            try
              LFile.SaveToFile(LOutputDirectory + 'claims.json');
            finally
              LFile.Free;
            end;
          finally
            LResult.Free;
          end;
          LOracle.Catalog.ExportSearch(LOutputDirectory + 'search');
        end;
    else
      raise EConvertError.Create('Unknown command: ' + LCommand);
    end;
  finally
    LOracle.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  SetTextCodePage(Input, CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  SetTextCodePage(StdErr, CP_UTF8);
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
