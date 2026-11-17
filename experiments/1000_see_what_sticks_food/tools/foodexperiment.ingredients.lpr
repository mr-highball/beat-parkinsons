{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.ingredients;

{$mode delphi}
{$H+}

uses
  Windows, Classes, SysUtils, Math, fpjson, jsonparser, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.bibliography;

const
  Tab = #9;
  QueryHeader = 'query_id'#9'category'#9'ingredient'#9'searched_utc'#9'query'#9'status'#9 +
    'hit_count'#9'retrieved_count'#9'pages'#9'error';
  ExpressionHeader = 'query_id'#9'category'#9'ingredient'#9'query';
  ResultHeader = BibliographyHeader;
  DiseaseQuery = '(TITLE_ABS:parkinson* OR TITLE_ABS:"shaking palsy" OR ' +
    'TITLE_ABS:"paralysis agitans")';
  DefaultPageSize = 100;
  MaximumPageSize = 1000;
  RequestSpacingMs = 160;
  MaximumAttempts = 4;
  DefaultWorkers = 6;
  MaximumWorkers = 8;

type
  TIngredientQuery = record
    Id: UTF8String;
    Category: UTF8String;
    Ingredient: UTF8String;
    Expression: UTF8String;
  end;

  TIngredientQueries = array of TIngredientQuery;

  TIngredientResult = record
    Date: UTF8String;
    HitCount: Int64;
    Retrieved: Int64;
    Pages: Integer;
    Status: UTF8String;
    Error: UTF8String;
  end;

  TSearchRun = class
  private
    FLock: TRTLCriticalSection;
    FQueries: TIngredientQueries;
    FNextQuery: Integer;
    FNextRequest: QWord;
    FCompleted: Integer;
    FFailed: Integer;
    FQueryFile: TFileStream;
    FResultFile: TFileStream;
    FSort: UTF8String;
    FPageSize: Integer;
    procedure RestoreCompleted(const APriorDir: String);
  public
    constructor Create(const AQueries: TIngredientQueries; const AOutputDir, APriorDir: String;
      const ASort: UTF8String; APageSize: Integer);
    destructor Destroy; override;
    function TakeQuery(out AQuery: TIngredientQuery): Boolean;
    procedure WaitForRequest;
    procedure DelayRequests(ADelayMs: DWORD);
    procedure WriteResult(const AQuery: TIngredientQuery; const AResult: TIngredientResult;
      ARows: TStream);
    property Failed: Integer read FFailed;
    property Sort: UTF8String read FSort;
    property PageSize: Integer read FPageSize;
  end;

  TSearchWorker = class(TThread)
  private
    FRun: TSearchRun;
    FClient: TEuropePmc;
    function FetchPage(const AQuery, ACursor: UTF8String): UTF8String;
    procedure SearchIngredient(const AQuery: TIngredientQuery; ARows: TStream;
      var AResult: TIngredientResult);
  protected
    procedure Execute; override;
  public
    constructor Create(ARun: TSearchRun);
  end;

procedure WriteLine(AStream: TStream; const AValue: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := AValue + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

function ReadUtf8(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

function SearchTerm(const AValue: UTF8String): UTF8String;
begin
  Result := 'TITLE_ABS:"' + StringReplace(String(AValue), '"', '\"', [rfReplaceAll]) + '"';
end;

function BuildExposure(const ATerms: UTF8String): UTF8String;
var
  LTerm: UTF8String;
  LUnique: TStringList;
begin
  Result := '';
  LUnique := TStringList.Create;
  try
    LUnique.CaseSensitive := False;
    for LTerm in SplitFields(ATerms, '|') do
    begin
      if (Trim(LTerm) = '') or (LUnique.IndexOf(LTerm) >= 0) or
        SameText(LTerm, 'date') or SameText(LTerm, 'fig') or SameText(LTerm, 'sage') then
      begin
        Continue;
      end;
      LUnique.Add(LTerm);
      if Result <> '' then
      begin
        Result := Result + ' OR ';
      end;
      if SameText(LTerm, 'turkey') then
      begin
        Result := Result + '(TITLE_ABS:turkey AND (TITLE_ABS:poultry OR TITLE_ABS:meat))';
      end
      else if SameText(LTerm, 'cod') then
      begin
        Result := Result + '(TITLE_ABS:cod AND (TITLE_ABS:fish OR TITLE_ABS:seafood))';
      end
      else if SameText(LTerm, 'rocket') then
      begin
        Result := Result + '(TITLE_ABS:rocket AND (TITLE_ABS:salad OR TITLE_ABS:vegetable))';
      end
      else
      begin
        Result := Result + SearchTerm(LTerm);
      end;
    end;
  finally
    LUnique.Free;
  end;
end;

procedure LoadExposureExpansions(const APath: String; ANames, ARelated: TStringList);
var
  LRows: TFields;
  LFields: TFields;
  LTarget: TStringList;
  I: Integer;
begin
  LRows := SplitFields(ReadUtf8(APath), #10);
  if (Length(LRows) < 2) or (Trim(LRows[0]) <> 'ingredient'#9'relation'#9'terms') then
  begin
    raise EConvertError.Create('Unexpected exposure expansions header');
  end;
  for I := 1 to High(LRows) do
  begin
    if Trim(LRows[I]) = '' then
    begin
      Continue;
    end;
    LFields := SplitFields(StringReplace(String(LRows[I]), #13, '', [rfReplaceAll]), Tab);
    if (Length(LFields) <> 3) or (LFields[0] = '') or (LFields[2] = '') then
    begin
      raise EConvertError.CreateFmt('Invalid exposure expansion row %d', [I + 1]);
    end;
    if LFields[1] = 'name' then
    begin
      LTarget := ANames;
    end
    else if LFields[1] = 'related' then
    begin
      LTarget := ARelated;
    end
    else
    begin
      raise EConvertError.CreateFmt('Unexpected exposure expansion relation on row %d', [I + 1]);
    end;
    LTarget.Values[LFields[0]] := LTarget.Values[LFields[0]] + '|' + LFields[2];
  end;
end;

function LoadIngredientQueries(const AExperimentDir: String): TIngredientQueries;
var
  LRows: TFields;
  LFields: TFields;
  LNames: TStringList;
  LRelatedTerms: TStringList;
  LIngredient: UTF8String;
  LRelated: UTF8String;
  LCategory: UTF8String;
  LCount: Integer;
  I: Integer;

  procedure AddQuery(const AId, ATerms: UTF8String);
  var
    LIndex: Integer;
  begin
    LIndex := Length(Result);
    SetLength(Result, LIndex + 1);
    Result[LIndex].Id := AId;
    Result[LIndex].Category := LCategory;
    Result[LIndex].Ingredient := LIngredient;
    Result[LIndex].Expression := DiseaseQuery + ' AND (' + BuildExposure(ATerms) + ')';
  end;

begin
  Result := nil;
  LRows := SplitFields(ReadUtf8(IncludeTrailingPathDelimiter(AExperimentDir) +
    'ingredients.tsv'), #10);
  if (Length(LRows) < 2) or
    (Trim(LRows[0]) <> 'category'#9'ingredient'#9'forms'#9'aliases') then
  begin
    raise EConvertError.Create('Unexpected ingredient vocabulary header');
  end;
  LNames := TStringList.Create;
  LRelatedTerms := TStringList.Create;
  try
    LoadExposureExpansions(IncludeTrailingPathDelimiter(AExperimentDir) +
      'exposure-expansions.tsv', LNames, LRelatedTerms);
    LCount := 0;
    for I := 1 to High(LRows) do
    begin
      LRows[I] := StringReplace(String(LRows[I]), #13, '', [rfReplaceAll]);
      if LRows[I] = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LRows[I], Tab);
      if (Length(LFields) <> 4) or (LFields[0] = '') or (LFields[1] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient vocabulary row %d', [I + 1]);
      end;
      Inc(LCount);
      LCategory := LFields[0];
      LIngredient := LFields[1];
      AddQuery(Format('E%.3d', [LCount]), LIngredient + '|' + LFields[3] + '|' +
        UTF8String(LNames.Values[LIngredient]));
      LRelated := UTF8String(LRelatedTerms.Values[LIngredient]);
      if LRelated <> '' then
      begin
        AddQuery(Format('R%.3d', [LCount]), LRelated);
      end;
    end;
    if LCount = 0 then
    begin
      raise EConvertError.Create('No ingredients were loaded');
    end;
  finally
    LRelatedTerms.Free;
    LNames.Free;
  end;
end;

function LoadClaimQueries(const AExperimentDir: String): TIngredientQueries;
var
  LRoot: String;
  LRows: TFields;
  LFields: TFields;
  LClaims: TIngredientQueries;
  LIds: TStringList;
  LClaim: Integer;
  LCount: Integer;
  I: Integer;
begin
  Result := nil;
  SetLength(LClaims, 1001);
  LRoot := IncludeTrailingPathDelimiter(AExperimentDir);
  LRows := SplitFields(ReadUtf8(LRoot + 'freeze.tsv'), #10);
  if Trim(LRows[0]) <> 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9 +
    'direction'#9'statement' then
  begin
    raise EConvertError.Create('Unexpected frozen claim header');
  end;
  for I := 1 to High(LRows) do
  begin
    if Trim(LRows[I]) = '' then
    begin
      Continue;
    end;
    LFields := SplitFields(LRows[I], Tab);
    if (Length(LFields) <> 7) or not TryStrToInt(LFields[0], LClaim) or
      (LClaim < 1) or (LClaim > High(LClaims)) then
    begin
      raise EConvertError.CreateFmt('Invalid frozen claim row %d', [I + 1]);
    end;
    if LClaims[LClaim].Ingredient <> '' then
    begin
      raise EConvertError.Create('Repeated frozen claim ' + LFields[0]);
    end;
    LClaims[LClaim].Category := LFields[1];
    LClaims[LClaim].Ingredient := LFields[2];
  end;
  LRows := SplitFields(ReadUtf8(LRoot + 'queries.tsv'), #10);
  if Trim(LRows[0]) <> 'query_id'#9'provider'#9'searched_on'#9'query'#9'result_count'#9 +
    'screened_count'#9'status'#9'notes' then
  begin
    raise EConvertError.Create('Unexpected first-pass query header');
  end;
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    SetLength(Result, Length(LRows) - 1);
    LCount := 0;
    for I := 1 to High(LRows) do
    begin
      if Trim(LRows[I]) = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LRows[I], Tab);
      if (Length(LFields) <> 8) or (LFields[1] <> 'Europe PMC') or (LFields[3] = '') or
        not TryStrToInt(Copy(LFields[0], 1, 4), LClaim) or (LClaim < 1) or
        (LClaim > High(LClaims)) or (LClaims[LClaim].Ingredient = '') then
      begin
        raise EConvertError.CreateFmt('Invalid first-pass query row %d', [I + 1]);
      end;
      LIds.Add(LFields[0]);
      Result[LCount] := LClaims[LClaim];
      Result[LCount].Id := LFields[0];
      Result[LCount].Expression := LFields[3];
      Inc(LCount);
    end;
    if LCount <> High(LClaims) * 2 then
    begin
      raise EConvertError.Create('Expected two first-pass queries per frozen claim');
    end;
    for LClaim := 1 to High(LClaims) do
    begin
      if (LIds.IndexOf(Format('%.4d-1', [LClaim])) < 0) or
        (LIds.IndexOf(Format('%.4d-2', [LClaim])) < 0) then
      begin
        raise EConvertError.CreateFmt('Missing query for frozen claim %.4d', [LClaim]);
      end;
    end;
    SetLength(Result, LCount);
  finally
    LIds.Free;
  end;
end;

function LoadExpressions(const APath: String): TIngredientQueries;
var
  LRows: TFields;
  LFields: TFields;
  LIds: TStringList;
  LCount: Integer;
  I: Integer;
begin
  Result := nil;
  LRows := SplitFields(ReadUtf8(APath), #10);
  if (Length(LRows) = 0) or (Trim(LRows[0]) <> ExpressionHeader) then
  begin
    raise EConvertError.Create('Unexpected focused expression header');
  end;
  SetLength(Result, Length(LRows) - 1);
  LCount := 0;
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    for I := 1 to High(LRows) do
    begin
      if Trim(LRows[I]) = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(Trim(LRows[I]), Tab);
      if (Length(LFields) <> 4) or (Trim(LFields[0]) = '') or (Trim(LFields[1]) = '') or
        (Trim(LFields[2]) = '') or (Trim(LFields[3]) = '') then
      begin
        raise EConvertError.CreateFmt('Invalid focused expression row %d', [I + 1]);
      end;
      LIds.Add(LFields[0]);
      Result[LCount].Id := LFields[0];
      Result[LCount].Category := LFields[1];
      Result[LCount].Ingredient := LFields[2];
      Result[LCount].Expression := LFields[3];
      Inc(LCount);
    end;
  finally
    LIds.Free;
  end;
  if LCount = 0 then
  begin
    raise EConvertError.Create('No focused expressions were loaded');
  end;
  SetLength(Result, LCount);
end;

constructor TSearchRun.Create(const AQueries: TIngredientQueries; const AOutputDir,
  APriorDir: String; const ASort: UTF8String; APageSize: Integer);
var
  LDirectory: String;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FQueries := AQueries;
  FSort := ASort;
  FPageSize := APageSize;
  LDirectory := IncludeTrailingPathDelimiter(AOutputDir);
  if (APriorDir <> '') and (SameText(LDirectory, IncludeTrailingPathDelimiter(APriorDir)) or
    FileExists(LDirectory + 'ingredient_queries.tsv') or
    FileExists(LDirectory + 'ingredient_results.tsv')) then
  begin
    raise EInOutError.Create('Resume into a fresh output directory to preserve the checkpoint');
  end;
  if not ForceDirectories(LDirectory) then
  begin
    raise EInOutError.CreateFmt('Cannot create output directory "%s"', [LDirectory]);
  end;
  FQueryFile := TFileStream.Create(LDirectory + 'ingredient_queries.tsv',
    fmCreate or fmShareDenyWrite);
  FResultFile := TFileStream.Create(LDirectory + 'ingredient_results.tsv',
    fmCreate or fmShareDenyWrite);
  WriteLine(FQueryFile, QueryHeader);
  WriteLine(FResultFile, ResultHeader);
  if APriorDir <> '' then
  begin
    RestoreCompleted(IncludeTrailingPathDelimiter(APriorDir));
  end;
end;

procedure TSearchRun.RestoreCompleted(const APriorDir: String);
type
  TCheckpoint = record
    QueryRow: UTF8String;
    Expected: Integer;
    Copied: Integer;
  end;
var
  LIndex: TStringList;
  LCheckpoint: array of TCheckpoint;
  LRows: TFields;
  LFields: TFields;
  LRemaining: TIngredientQueries;
  LResults: Text;
  LLine: UTF8String;
  LFound: Integer;
  LQuery: Integer;
  LReported: Integer;
  LRetrieved: Integer;
  LRank: Integer;
  LCount: Integer;
  I: Integer;
begin
  LIndex := TStringList.Create;
  try
    LIndex.Sorted := True;
    for I := 0 to High(FQueries) do
    begin
      LIndex.AddObject(FQueries[I].Id, TObject(PtrInt(I + 1)));
    end;
    SetLength(LCheckpoint, Length(FQueries));
    LRows := SplitFields(ReadUtf8(APriorDir + 'ingredient_queries.tsv'), #10);
    if Trim(LRows[0]) <> QueryHeader then
    begin
      raise EConvertError.Create('Unexpected prior query ledger header');
    end;
    for I := 1 to High(LRows) do
    begin
      LLine := LRows[I];
      if (LLine <> '') and (LLine[Length(LLine)] = #13) then
      begin
        SetLength(LLine, Length(LLine) - 1);
      end;
      LFields := SplitFields(LLine, Tab);
      if (Length(LFields) <> 10) or (LFields[5] <> 'Retrieved') or
        not LIndex.Find(LFields[0], LFound) then
      begin
        Continue;
      end;
      LQuery := PtrInt(LIndex.Objects[LFound]) - 1;
      if (LCheckpoint[LQuery].QueryRow <> '') or (LFields[4] <> FQueries[LQuery].Expression) or
        not TryStrToInt(LFields[6], LReported) or not TryStrToInt(LFields[7], LRetrieved) or
        (LRetrieved < 0) or (LReported <> LRetrieved) then
      begin
        raise EConvertError.Create('Invalid prior completed query ' + LFields[0]);
      end;
      LCheckpoint[LQuery].QueryRow := LLine;
      LCheckpoint[LQuery].Expected := LRetrieved;
    end;
    AssignFile(LResults, APriorDir + 'ingredient_results.tsv');
    Reset(LResults);
    SetTextCodePage(LResults, CP_UTF8);
    try
      ReadLn(LResults, LLine);
      if LLine <> ResultHeader then
      begin
        raise EConvertError.Create('Unexpected prior result ledger header');
      end;
      while not Eof(LResults) do
      begin
        ReadLn(LResults, LLine);
        LFields := SplitFields(LLine, Tab);
        if (Length(LFields) = 0) or not LIndex.Find(LFields[0], LFound) then
        begin
          Continue;
        end;
        LQuery := PtrInt(LIndex.Objects[LFound]) - 1;
        if LCheckpoint[LQuery].QueryRow = '' then
        begin
          Continue;
        end;
        Inc(LCheckpoint[LQuery].Copied);
        if (Length(LFields) <> 15) or not TryStrToInt(LFields[3], LRank) or
          (LRank <> LCheckpoint[LQuery].Copied) then
        begin
          raise EConvertError.Create('Invalid prior result row for ' + LFields[0]);
        end;
        WriteLine(FResultFile, LLine);
      end;
    finally
      CloseFile(LResults);
    end;
    LCount := 0;
    SetLength(LRemaining, Length(FQueries));
    for I := 0 to High(FQueries) do
    begin
      if LCheckpoint[I].QueryRow = '' then
      begin
        LRemaining[LCount] := FQueries[I];
        Inc(LCount);
        Continue;
      end;
      if LCheckpoint[I].Copied <> LCheckpoint[I].Expected then
      begin
        raise EConvertError.Create('Prior result count mismatch for ' + FQueries[I].Id);
      end;
      WriteLine(FQueryFile, LCheckpoint[I].QueryRow);
    end;
    WriteLn(Length(FQueries) - LCount, ' reconciled prior queries reused, ', LCount, ' remaining');
    SetLength(LRemaining, LCount);
    FQueries := LRemaining;
  finally
    LIndex.Free;
  end;
end;

destructor TSearchRun.Destroy;
begin
  FResultFile.Free;
  FQueryFile.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TSearchRun.TakeQuery(out AQuery: TIngredientQuery): Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FNextQuery < Length(FQueries);
    if Result then
    begin
      AQuery := FQueries[FNextQuery];
      Inc(FNextQuery);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSearchRun.WaitForRequest;
var
  LNow: QWord;
  LWait: DWORD;
begin
  repeat
    EnterCriticalSection(FLock);
    try
      LNow := GetTickCount64;
      if LNow >= FNextRequest then
      begin
        FNextRequest := LNow + RequestSpacingMs;
        Exit;
      end;
      LWait := FNextRequest - LNow;
    finally
      LeaveCriticalSection(FLock);
    end;
    Sleep(LWait);
  until False;
end;

procedure TSearchRun.DelayRequests(ADelayMs: DWORD);
var
  LNext: QWord;
begin
  EnterCriticalSection(FLock);
  try
    LNext := GetTickCount64 + ADelayMs;
    if LNext > FNextRequest then
    begin
      FNextRequest := LNext;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSearchRun.WriteResult(const AQuery: TIngredientQuery;
  const AResult: TIngredientResult; ARows: TStream);
begin
  EnterCriticalSection(FLock);
  try
    ARows.Position := 0;
    if ARows.Size > 0 then
    begin
      FResultFile.CopyFrom(ARows, ARows.Size);
    end;
    WriteLine(FQueryFile, AQuery.Id + Tab + AQuery.Category + Tab + AQuery.Ingredient +
      Tab + AResult.Date + Tab + AQuery.Expression + Tab + AResult.Status +
      Tab + IntToStr(AResult.HitCount) + Tab + IntToStr(AResult.Retrieved) +
      Tab + IntToStr(AResult.Pages) + Tab + CleanField(AResult.Error));
    Inc(FCompleted);
    if AResult.Status <> 'Retrieved' then
    begin
      Inc(FFailed);
      WriteLn(StdErr, AQuery.Id, ' ', AQuery.Ingredient, ': ', AResult.Error);
    end;
    if (FCompleted mod 20 = 0) or (FCompleted = Length(FQueries)) then
    begin
      WriteLn(FCompleted, '/', Length(FQueries), ' ingredient queries recorded (',
        FFailed, ' incomplete)');
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

constructor TSearchWorker.Create(ARun: TSearchRun);
begin
  inherited Create(True);
  FRun := ARun;
end;

function TSearchWorker.FetchPage(const AQuery, ACursor: UTF8String): UTF8String;
var
  LResponse: TSearchResponse;
  LError: String;
  I: Integer;
begin
  LError := '';
  for I := 1 to MaximumAttempts do
  begin
    FRun.WaitForRequest;
    try
      if FClient = nil then
      begin
        FClient := TEuropePmc.Create;
      end;
      LResponse := FClient.SearchPage(AQuery, ACursor, FRun.PageSize, FRun.Sort);
      if LResponse.Status = 200 then
      begin
        Exit(LResponse.Body);
      end;
      LError := 'Europe PMC HTTP ' + IntToStr(LResponse.Status);
      if LResponse.Status = 429 then
      begin
        FRun.DelayRequests(Max(2000, Min(60, LResponse.RetryAfterSeconds) * 1000));
      end
      else if (LResponse.Status <> 408) and (LResponse.Status < 500) then
      begin
        Break;
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

procedure TSearchWorker.SearchIngredient(const AQuery: TIngredientQuery; ARows: TStream;
  var AResult: TIngredientResult);
var
  LCursor: UTF8String;
  LNextCursor: UTF8String;
  LJson: TJSONData;
  LCount: TJSONData;
  LResults: TJSONData;
  LRow: TJSONData;
  LSeenRecords: TStringList;
  LSeenCursors: TStringList;
  LSource: UTF8String;
  LSourceId: UTF8String;
  LKey: UTF8String;
  I: Integer;
begin
  LCursor := '*';
  LSeenRecords := TStringList.Create;
  LSeenCursors := TStringList.Create;
  try
    LSeenRecords.Sorted := True;
    LSeenRecords.CaseSensitive := True;
    LSeenCursors.CaseSensitive := True;
    LSeenCursors.Add(LCursor);
    repeat
      LJson := GetJSON(FetchPage(AQuery.Expression, LCursor), True);
      try
        if JsonText(LJson, 'request.queryString') <> AQuery.Expression then
        begin
          raise EConvertError.Create('Europe PMC response query does not match the request');
        end;
        LCount := LJson.FindPath('hitCount');
        LResults := LJson.FindPath('resultList.result');
        if not Assigned(LCount) or (LCount.JSONType <> jtNumber) or
          not Assigned(LResults) or (LResults.JSONType <> jtArray) then
        begin
          raise EConvertError.Create('Unexpected Europe PMC response structure');
        end;
        if AResult.Pages = 0 then
        begin
          AResult.HitCount := LCount.AsInt64;
        end
        else if AResult.HitCount <> LCount.AsInt64 then
        begin
          raise EConvertError.CreateFmt('Hit count changed between pages (%d to %d)',
            [AResult.HitCount, LCount.AsInt64]);
        end;
        if (LResults.Count > FRun.PageSize) or
          (AResult.Retrieved + LResults.Count > AResult.HitCount) then
        begin
          raise EConvertError.Create('Inconsistent Europe PMC page counts');
        end;
        Inc(AResult.Pages);
        for I := 0 to LResults.Count - 1 do
        begin
          LRow := LResults.Items[I];
          LSource := JsonText(LRow, 'source');
          LSourceId := JsonText(LRow, 'id');
          if (LSource = '') or (LSourceId = '') then
          begin
            raise EConvertError.Create('Europe PMC returned a record without source and ID');
          end;
          LKey := LSource + ':' + LSourceId;
          if LSeenRecords.IndexOf(LKey) >= 0 then
          begin
            raise EConvertError.Create('Duplicate record in cursor results: ' + LKey);
          end;
          LSeenRecords.Add(LKey);
          WriteLine(ARows, BibliographyRow(AQuery.Id, AQuery.Category, AQuery.Ingredient, LRow,
            LSource, LSourceId, AResult.Retrieved + 1));
          Inc(AResult.Retrieved);
        end;
        if AResult.Retrieved = AResult.HitCount then
        begin
          AResult.Status := 'Retrieved';
          Exit;
        end;
        LNextCursor := JsonText(LJson, 'nextCursorMark');
        if (LResults.Count = 0) or (LNextCursor = '') or
          (LSeenCursors.IndexOf(LNextCursor) >= 0) then
        begin
          raise EConvertError.Create('Cursor ended or repeated before all results were retrieved');
        end;
        LSeenCursors.Add(LNextCursor);
        LCursor := LNextCursor;
      finally
        LJson.Free;
      end;
    until False;
  finally
    LSeenCursors.Free;
    LSeenRecords.Free;
  end;
end;

procedure TSearchWorker.Execute;
var
  LQuery: TIngredientQuery;
  LResult: TIngredientResult;
  LRows: TMemoryStream;
begin
  LRows := TMemoryStream.Create;
  try
    while FRun.TakeQuery(LQuery) do
    begin
      LRows.Clear;
      LResult := Default(TIngredientResult);
      LResult.Date := UtcTimestamp;
      LResult.HitCount := -1;
      try
        SearchIngredient(LQuery, LRows, LResult);
      except
        on LException: Exception do
        begin
          if LResult.Retrieved > 0 then
          begin
            LResult.Status := 'Partial';
          end
          else
          begin
            LResult.Status := 'Failed';
          end;
          LResult.Error := LException.Message;
        end;
      end;
      FRun.WriteResult(LQuery, LResult, LRows);
    end;
  finally
    LRows.Free;
    FClient.Free;
  end;
end;

procedure RunSearch(const AQueries: TIngredientQueries; const AOutputDir, APriorDir: String;
  const ASort: UTF8String; AWorkerCount, APageSize: Integer);
var
  LRun: TSearchRun;
  LWorkers: array of TSearchWorker;
  LWorker: TSearchWorker;
  I: Integer;
begin
  LRun := TSearchRun.Create(AQueries, AOutputDir, APriorDir, ASort, APageSize);
  try
    SetLength(LWorkers, AWorkerCount);
    try
      for I := 0 to High(LWorkers) do
      begin
        LWorkers[I] := TSearchWorker.Create(LRun);
        LWorkers[I].Start;
      end;
      for LWorker in LWorkers do
      begin
        LWorker.WaitFor;
        if Assigned(LWorker.FatalException) then
        begin
          raise Exception.Create(Exception(LWorker.FatalException).Message);
        end;
      end;
      if LRun.Failed > 0 then
      begin
        ExitCode := 2;
      end;
    finally
      for LWorker in LWorkers do
      begin
        LWorker.Free;
      end;
    end;
  finally
    LRun.Free;
  end;
end;

procedure Run;
var
  LQueries: TIngredientQueries;
  LWorkerCount: Integer;
  LPageSize: Integer;
  LPriorDir: String;
  LSort: UTF8String;
begin
  if not (ParamCount in [2, 3, 4, 5, 6, 7]) or ((ParamCount >= 4) and
    (ParamStr(4) <> 'claims') and (ParamStr(4) <> 'ingredients') and
    (ParamStr(4) <> 'expressions')) then
  begin
    raise EConvertError.Create('Usage: foodexperiment.ingredients <experiment-dir|expression-tsv> ' +
      '<output-dir> [workers [claims|ingredients|expressions [prior-output-dir [sort [page-size]]]]]');
  end;
  LWorkerCount := DefaultWorkers;
  if (ParamCount >= 3) and (not TryStrToInt(ParamStr(3), LWorkerCount) or
    (LWorkerCount < 1) or (LWorkerCount > MaximumWorkers)) then
  begin
    raise EConvertError.CreateFmt('Workers must be between 1 and %d', [MaximumWorkers]);
  end;
  LPageSize := DefaultPageSize;
  if (ParamCount >= 7) and (not TryStrToInt(ParamStr(7), LPageSize) or
    (LPageSize < 1) or (LPageSize > MaximumPageSize)) then
  begin
    raise EConvertError.CreateFmt('Page size must be between 1 and %d', [MaximumPageSize]);
  end;
  LPriorDir := '';
  if (ParamCount >= 5) and (ParamStr(5) <> '-') then
  begin
    LPriorDir := ExpandFileName(ParamStr(5));
  end;
  if ParamStr(4) = 'claims' then
  begin
    LQueries := LoadClaimQueries(ExpandFileName(ParamStr(1)));
    WriteLn('Retrieving all pages for ', Length(LQueries), ' first-pass claim queries');
  end
  else if ParamStr(4) = 'expressions' then
  begin
    LQueries := LoadExpressions(ExpandFileName(ParamStr(1)));
    WriteLn('Retrieving all pages for ', Length(LQueries), ' focused expressions');
  end
  else
  begin
    LQueries := LoadIngredientQueries(ExpandFileName(ParamStr(1)));
    WriteLn('Retrieving ', Length(LQueries), ' exposure and related-compound queries');
  end;
  LSort := ParamStr(6);
  if LSort = '-' then
  begin
    LSort := '';
  end;
  RunSearch(LQueries, ExpandFileName(ParamStr(2)), LPriorDir, LSort, LWorkerCount, LPageSize);
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
