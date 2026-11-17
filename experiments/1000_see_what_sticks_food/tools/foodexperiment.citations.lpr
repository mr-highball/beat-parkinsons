{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentCitations;

{$mode delphi}
{$H+}

uses
  Windows, Classes, SysUtils, Math, fpjson, jsonparser, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

const
  Tab = #9;
  PageSize = 100;
  RequestSpacingMs = 160;
  MaximumAttempts = 4;
  ApiPath = '/europepmc/webservices/rest/';
  SeedHeader = 'group'#9'exposure_terms'#9'outcome_terms'#9'source'#9'source_id';
  QueryHeader = 'group'#9'depth'#9'from_source'#9'from_id'#9'direction'#9'searched_utc'#9 +
    'path_prefix'#9'status'#9'hit_count'#9'retrieved_count'#9'pages'#9'error';
  EdgeHeader = 'group'#9'depth'#9'from_source'#9'from_id'#9'direction'#9'rank'#9 +
    'target_source'#9'target_id'#9'doi'#9'title'#9'year'#9'type'#9'routing';

type
  TDirection = (cdReferences, cdCitations);

const
  DirectionName: array[TDirection] of UTF8String = ('references', 'citations');
  ResultPath: array[TDirection] of String = ('referenceList.reference', 'citationList.citation');

type
  TCitationGroup = class
  private
    FMatcher: TMatcher;
    FName: UTF8String;
    FExposures: UTF8String;
    FOutcomes: UTF8String;
  public
    constructor Create(const AName, AExposures, AOutcomes: UTF8String);
    destructor Destroy; override;
    function RouteTitle(const ATitle: UTF8String): UTF8String;
    property Name: UTF8String read FName;
    property Exposures: UTF8String read FExposures;
    property Outcomes: UTF8String read FOutcomes;
  end;

  TCitationNode = record
    Group: TCitationGroup;
    Source: UTF8String;
    Id: UTF8String;
    Depth: Integer;
  end;

  TPageResult = record
    HitCount: Int64;
    Retrieved: Int64;
    Pages: Integer;
    Status: UTF8String;
    Error: UTF8String;
  end;

  TCitationRun = class
  private
    FGroups: TStringList;
    FSeen: TStringList;
    FNodes: array of TCitationNode;
    FClient: TEuropePmc;
    FQueryFile: TFileStream;
    FEdgeFile: TFileStream;
    FNextRequest: QWord;
    FIncomplete: Integer;
    function Enqueue(AGroup: TCitationGroup; const ASource, AId: UTF8String;
      ADepth: Integer): Boolean;
    procedure LoadSeeds(const APath: String);
    function Fetch(const APath: UTF8String): TSearchResponse;
    procedure RecordEdge(const ANode: TCitationNode; ADirection: TDirection;
      ARow: TJSONData; ARank: Int64);
    procedure ReadPages(const ANode: TCitationNode; ADirection: TDirection;
      const APrefix: UTF8String; var AResult: TPageResult);
    procedure SearchNode(const ANode: TCitationNode; ADirection: TDirection);
  public
    constructor Create(const ASeedPath, AOutputDir: String);
    destructor Destroy; override;
    procedure Run;
  end;

procedure WriteLine(AStream: TStream; const AValue: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := AValue + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

function JsonText(AObject: TJSONData; const APath: String): UTF8String;
var
  LValue: TJSONData;
begin
  LValue := AObject.FindPath(APath);
  Result := '';
  if Assigned(LValue) and (LValue.JSONType in [jtString, jtNumber]) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

constructor TCitationGroup.Create(const AName, AExposures, AOutcomes: UTF8String);
var
  LTerm: UTF8String;
begin
  inherited Create;
  FName := AName;
  FExposures := AExposures;
  FOutcomes := AOutcomes;
  FMatcher := TMatcher.Create;
  for LTerm in SplitFields('parkinson|parkinsonism|parkinsonian|shaking palsy|paralysis agitans', '|') do
  begin
    FMatcher.Add(LTerm, 0);
  end;
  for LTerm in SplitFields(FExposures, '|') do
  begin
    FMatcher.Add(LTerm, 1);
  end;
  for LTerm in SplitFields(FOutcomes, '|') do
  begin
    FMatcher.Add(LTerm, 2);
  end;
  FMatcher.Prepare;
end;

destructor TCitationGroup.Destroy;
begin
  FMatcher.Free;
  inherited Destroy;
end;

function TCitationGroup.RouteTitle(const ATitle: UTF8String): UTF8String;
var
  LFound: TMatchFlags;
begin
  SetLength(LFound, 3);
  FMatcher.Match(ATitle, LFound);
  if LFound[0] and LFound[1] and (LFound[2] or (FOutcomes = '')) then
  begin
    Result := 'Eligible';
  end
  else if LFound[1] and (LFound[0] or LFound[2]) then
  begin
    Result := 'Context';
  end
  else
  begin
    Result := 'Other';
  end;
end;

constructor TCitationRun.Create(const ASeedPath, AOutputDir: String);
var
  LDirectory: String;
begin
  inherited Create;
  FGroups := TStringList.Create;
  FGroups.OwnsObjects := True;
  FSeen := TStringList.Create;
  FSeen.Sorted := True;
  FSeen.CaseSensitive := True;
  LoadSeeds(ASeedPath);
  LDirectory := IncludeTrailingPathDelimiter(AOutputDir);
  if not ForceDirectories(LDirectory) then
  begin
    raise EInOutError.CreateFmt('Cannot create output directory %s', [LDirectory]);
  end;
  FQueryFile := TFileStream.Create(LDirectory + 'citation_queries.tsv',
    fmCreate or fmShareDenyWrite);
  FEdgeFile := TFileStream.Create(LDirectory + 'citation_edges.tsv',
    fmCreate or fmShareDenyWrite);
  WriteLine(FQueryFile, QueryHeader);
  WriteLine(FEdgeFile, EdgeHeader);
  FClient := TEuropePmc.Create;
end;

destructor TCitationRun.Destroy;
begin
  FClient.Free;
  FEdgeFile.Free;
  FQueryFile.Free;
  FSeen.Free;
  FGroups.Free;
  inherited Destroy;
end;

function TCitationRun.Enqueue(AGroup: TCitationGroup; const ASource, AId: UTF8String;
  ADepth: Integer): Boolean;
var
  LKey: UTF8String;
  LIndex: Integer;
begin
  LKey := AGroup.Name + Tab + ASource + Tab + AId;
  Result := FSeen.IndexOf(LKey) < 0;
  if Result then
  begin
    FSeen.Add(LKey);
    LIndex := Length(FNodes);
    SetLength(FNodes, LIndex + 1);
    FNodes[LIndex].Group := AGroup;
    FNodes[LIndex].Source := ASource;
    FNodes[LIndex].Id := AId;
    FNodes[LIndex].Depth := ADepth;
  end;
end;

procedure TCitationRun.LoadSeeds(const APath: String);
var
  LSeeds: TStringList;
  LFields: TFields;
  LGroup: TCitationGroup;
  LIndex: Integer;
  I: Integer;
begin
  LSeeds := TStringList.Create;
  try
    LSeeds.LoadFromFile(APath);
    if (LSeeds.Count < 2) or (LSeeds[0] <> SeedHeader) then
    begin
      raise EConvertError.Create('Unexpected citation seed header or missing seed data');
    end;
    for I := 1 to LSeeds.Count - 1 do
    begin
      LFields := SplitFields(LSeeds[I], Tab);
      if (Length(LFields) <> 5) or (LFields[0] = '') or (LFields[1] = '') or
        (LFields[3] = '') or (LFields[4] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid citation seed row %d', [I + 1]);
      end;
      LIndex := FGroups.IndexOf(LFields[0]);
      if LIndex >= 0 then
      begin
        LGroup := TCitationGroup(FGroups.Objects[LIndex]);
        if (LGroup.Exposures <> LFields[1]) or (LGroup.Outcomes <> LFields[2]) then
        begin
          raise EConvertError.CreateFmt('Inconsistent citation group terms on row %d', [I + 1]);
        end;
      end
      else
      begin
        LGroup := TCitationGroup.Create(LFields[0], LFields[1], LFields[2]);
        FGroups.AddObject(LFields[0], LGroup);
      end;
      if not Enqueue(LGroup, LFields[3], LFields[4], 0) then
      begin
        raise EConvertError.CreateFmt('Duplicate citation seed on row %d', [I + 1]);
      end;
    end;
  finally
    LSeeds.Free;
  end;
end;

function TCitationRun.Fetch(const APath: UTF8String): TSearchResponse;
var
  LNow: QWord;
  LError: String;
  I: Integer;
begin
  LError := '';
  for I := 1 to MaximumAttempts do
  begin
    LNow := GetTickCount64;
    if FNextRequest > LNow then
    begin
      Sleep(FNextRequest - LNow);
    end;
    FNextRequest := GetTickCount64 + RequestSpacingMs;
    try
      Result := FClient.GetPath(APath);
      if (Result.Status <> 408) and (Result.Status <> 429) and (Result.Status < 500) then
      begin
        Exit;
      end;
      LError := 'Europe PMC HTTP ' + IntToStr(Result.Status);
      if Result.Status = 429 then
      begin
        FNextRequest := GetTickCount64 + Max(2000, Min(60, Result.RetryAfterSeconds) * 1000);
      end;
    except
      on LException: Exception do
      begin
        LError := LException.Message;
      end;
    end;
    if I < MaximumAttempts then
    begin
      Sleep(1000 shl (I - 1));
    end;
  end;
  raise EInOutError.Create(LError);
end;

procedure TCitationRun.RecordEdge(const ANode: TCitationNode; ADirection: TDirection;
  ARow: TJSONData; ARank: Int64);
var
  LSource: UTF8String;
  LId: UTF8String;
  LTitle: UTF8String;
  LRouting: UTF8String;
begin
  LSource := JsonText(ARow, 'source');
  LId := JsonText(ARow, 'id');
  LTitle := JsonText(ARow, 'title');
  LRouting := ANode.Group.RouteTitle(LTitle);
  if (LSource = '') or (LId = '') then
  begin
    LRouting := LRouting + 'Unlinked';
  end
  else if LRouting = 'Eligible' then
  begin
    if Enqueue(ANode.Group, LSource, LId, ANode.Depth + 1) then
    begin
      LRouting := 'Queued';
    end
    else
    begin
      LRouting := 'AlreadyQueued';
    end;
  end;
  WriteLine(FEdgeFile, ANode.Group.Name + Tab + IntToStr(ANode.Depth) + Tab +
    ANode.Source + Tab + ANode.Id + Tab + DirectionName[ADirection] + Tab +
    IntToStr(ARank) + Tab + LSource + Tab + LId + Tab + JsonText(ARow, 'doi') + Tab +
    LTitle + Tab + JsonText(ARow, 'pubYear') + Tab + JsonText(ARow, 'citationType') + Tab + LRouting);
end;

procedure TCitationRun.ReadPages(const ANode: TCitationNode; ADirection: TDirection;
  const APrefix: UTF8String; var AResult: TPageResult);
var
  LResponse: TSearchResponse;
  LJson: TJSONData;
  LHits: TJSONData;
  LRows: TJSONData;
  LSeenPages: TStringList;
  LPageSignature: UTF8String;
  I: Integer;
begin
  LSeenPages := TStringList.Create;
  try
    LSeenPages.CaseSensitive := True;
    repeat
      LResponse := Fetch(APrefix + '&page=' + IntToStr(AResult.Pages + 1));
      if LResponse.Status <> 200 then
      begin
        if (AResult.Pages = 0) and ((LResponse.Status = 403) or (LResponse.Status = 404)) then
        begin
          AResult.Status := 'Unavailable';
        end;
        raise EInOutError.CreateFmt('Europe PMC HTTP %d', [LResponse.Status]);
      end;
      LJson := GetJSON(LResponse.Body, True);
      try
        LHits := LJson.FindPath('hitCount');
        if not Assigned(LHits) or (LHits.JSONType <> jtNumber) then
        begin
          raise EConvertError.Create('Citation endpoint omitted numeric hitCount');
        end;
        if AResult.Pages = 0 then
        begin
          AResult.HitCount := LHits.AsInt64;
        end
        else if AResult.HitCount <> LHits.AsInt64 then
        begin
          raise EConvertError.Create('Citation endpoint hitCount changed between pages');
        end;
        LRows := LJson.FindPath(ResultPath[ADirection]);
        if (AResult.HitCount = 0) and not Assigned(LRows) then
        begin
          Inc(AResult.Pages);
          AResult.Status := 'Retrieved';
          Exit;
        end;
        if not Assigned(LRows) or (LRows.JSONType <> jtArray) then
        begin
          raise EConvertError.Create('Citation endpoint omitted expected result array');
        end;
        if (LRows.Count > PageSize) or (AResult.Retrieved + LRows.Count > AResult.HitCount) then
        begin
          raise EConvertError.Create('Citation endpoint returned inconsistent page counts');
        end;
        LPageSignature := LRows.AsJSON;
        if LSeenPages.IndexOf(LPageSignature) >= 0 then
        begin
          raise EConvertError.Create('Citation endpoint repeated a result page');
        end;
        LSeenPages.Add(LPageSignature);
        Inc(AResult.Pages);
        for I := 0 to LRows.Count - 1 do
        begin
          RecordEdge(ANode, ADirection, LRows.Items[I], AResult.Retrieved + 1);
          Inc(AResult.Retrieved);
        end;
        if AResult.Retrieved = AResult.HitCount then
        begin
          AResult.Status := 'Retrieved';
          Exit;
        end;
        if LRows.Count = 0 then
        begin
          raise EConvertError.Create('Citation endpoint ran out of pages before its reported total');
        end;
      finally
        LJson.Free;
      end;
    until False;
  finally
    LSeenPages.Free;
  end;
end;

procedure TCitationRun.SearchNode(const ANode: TCitationNode; ADirection: TDirection);
var
  LResult: TPageResult;
  LStart: UTF8String;
  LPrefix: UTF8String;
begin
  LResult := Default(TPageResult);
  LResult.HitCount := -1;
  LStart := UtcTimestamp;
  LPrefix := ApiPath + UrlEncode(ANode.Source) + '/' + UrlEncode(ANode.Id) + '/' +
    DirectionName[ADirection] + '?format=json&pageSize=' + IntToStr(PageSize);
  try
    ReadPages(ANode, ADirection, LPrefix, LResult);
  except
    on LException: Exception do
    begin
      if LResult.Retrieved > 0 then
      begin
        LResult.Status := 'Partial';
      end
      else if LResult.Status = '' then
      begin
        LResult.Status := 'Failed';
      end;
      Inc(FIncomplete);
      LResult.Error := CleanField(LException.Message);
    end;
  end;
  WriteLine(FQueryFile, ANode.Group.Name + Tab + IntToStr(ANode.Depth) + Tab + ANode.Source +
    Tab + ANode.Id + Tab + DirectionName[ADirection] + Tab + LStart + Tab + LPrefix + Tab +
    LResult.Status + Tab + IntToStr(LResult.HitCount) + Tab + IntToStr(LResult.Retrieved) +
    Tab + IntToStr(LResult.Pages) + Tab + LResult.Error);
end;

procedure TCitationRun.Run;
var
  LNode: TCitationNode;
  LDirection: TDirection;
  LNext: Integer;
begin
  WriteLn('Following references and citing records from ', Length(FNodes), ' seed records');
  LNext := 0;
  while LNext < Length(FNodes) do
  begin
    LNode := FNodes[LNext];
    for LDirection := Low(TDirection) to High(TDirection) do
    begin
      SearchNode(LNode, LDirection);
    end;
    Inc(LNext);
    if LNext mod 10 = 0 then
    begin
      WriteLn(LNext, ' article routes visited, ', Length(FNodes) - LNext, ' in queue');
    end;
  end;
  WriteLn(LNext, ' article routes visited, ', FIncomplete, ' endpoints incomplete');
  if FIncomplete > 0 then
  begin
    ExitCode := 2;
  end;
end;

procedure Run;
var
  LCitations: TCitationRun;
begin
  if ParamCount <> 2 then
  begin
    raise EArgumentException.Create('Usage: foodexperiment.citations <seed-tsv> <output-dir>');
  end;
  LCitations := TCitationRun.Create(ExpandFileName(ParamStr(1)), ExpandFileName(ParamStr(2)));
  try
    LCitations.Run;
  finally
    LCitations.Free;
  end;
end;

begin
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
