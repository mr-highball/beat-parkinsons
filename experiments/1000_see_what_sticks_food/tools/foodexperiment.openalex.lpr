{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentOpenAlex;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, fpjson, jsonparser, RegExpr, foodexperiment.https,
  foodexperiment.externaldata, foodexperiment.regionalreview;

const
  Tab = #9;
  Host = 'api.openalex.org';
  SortValue = 'ids.openalex:asc';
  PageSize = 100;
  MaximumOffsetResults = 10000;
  RequestSpacingMs = 1250;
  RequestAttempts = 3;
  LongRetrySeconds = 30;
  QueryHeader = 'query_id'#9'language'#9'expression';
  ResultHeader = 'query_id'#9'page'#9'work_id'#9'doi'#9'pmid'#9'title'#9'publication_date'#9 +
    'language'#9'type'#9'landing_page'#9'has_abstract';
  AuditHeader = 'query_id'#9'language'#9'expression'#9'started_utc'#9 +
    'reported'#9'retrieved'#9'pages'#9'status'#9'detail';
  SearchPath = '/works?search.title_and_abstract=';
  SelectedFields = 'id,doi,ids,title,publication_date,language,type,primary_location,' +
    'abstract_inverted_index';

type
  TPageData = record
    Reported: Integer;
    Ids: TFields;
    Rows: TFields;
  end;

  TPriorQuery = record
    Started: UTF8String;
    Complete: Boolean;
    Reported: Integer;
    Retrieved: Integer;
    Pages: Integer;
    FirstResult: Integer;
    Boundary: TFields;
  end;

  TPriorQueries = array of TPriorQuery;

function Field(AData: TJSONData; const APath: String): UTF8String;
var
  LValue: TJSONData;
begin
  Result := '';
  LValue := AData.FindPath(APath);
  if Assigned(LValue) and (LValue.JSONType = jtString) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

procedure SavePage(const APath: String; const ABody: UTF8String);
var
  LTemp: String;
  LStream: TFileStream;
begin
  LTemp := APath + '.tmp';
  LStream := TFileStream.Create(LTemp, fmCreate);
  try
    try
      if ABody <> '' then
      begin
        LStream.WriteBuffer(ABody[1], Length(ABody));
      end;
    finally
      LStream.Free;
    end;
    if not RenameFile(LTemp, APath) then
    begin
      raise EInOutError.Create('Cannot save OpenAlex page: ' + APath);
    end;
  finally
    if FileExists(LTemp) then
    begin
      SysUtils.DeleteFile(LTemp);
    end;
  end;
end;

function ReadPageBody(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > High(SizeInt) then
    begin
      raise EInOutError.Create('OpenAlex capture is too large: ' + APath);
    end;
    SetLength(Result, LStream.Size);
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

function FetchPage(AClient: TEuropePmc; const APath: UTF8String): UTF8String;
var
  LResponse: TSearchResponse;
  LDelay: DWORD;
  LAttempt: Integer;
begin
  LDelay := RequestSpacingMs;
  for LAttempt := 1 to RequestAttempts do
  begin
    Sleep(LDelay);
    LResponse := AClient.GetPath(APath);
    if not ((LResponse.Status = 429) or
      ((LResponse.Status >= 502) and (LResponse.Status <= 504))) or
      (LResponse.RetryAfterSeconds > LongRetrySeconds) then
    begin
      Break;
    end;
    LDelay := LDelay * 2;
    if LResponse.RetryAfterSeconds * 1000 > LDelay then
    begin
      LDelay := LResponse.RetryAfterSeconds * 1000;
    end;
  end;
  if LResponse.Status <> 200 then
  begin
    if LResponse.RetryAfterSeconds > 0 then
    begin
      raise EInOutError.CreateFmt('HTTP %d, Retry-After %d seconds',
        [LResponse.Status, LResponse.RetryAfterSeconds]);
    end;
    raise EInOutError.CreateFmt('HTTP %d', [LResponse.Status]);
  end;
  Result := LResponse.Body;
end;

function PageFileName(const AQueryId: UTF8String; APageNumber: Integer): String;
begin
  Result := Format('%s-%d.json', [AQueryId, APageNumber]);
end;

function NonnegativeInteger(AData: TJSONData; const APath: String): Integer;
var
  LValue: TJSONData;
begin
  LValue := AData.FindPath(APath);
  if not Assigned(LValue) or (LValue.JSONType <> jtNumber) or
    not TryStrToInt(LValue.AsString, Result) or (Result < 0) then
  begin
    raise EConvertError.Create('Invalid OpenAlex ' + APath);
  end;
end;

function ExpectedPageRows(AReported, APageNumber: Integer): Integer;
begin
  Result := AReported - (APageNumber - 1) * PageSize;
  if Result > PageSize then
  begin
    Result := PageSize;
  end;
end;

function ParsePage(const ABody, AQueryId: UTF8String; APageNumber, AExpected: Integer;
  ASeen: TStringList; ASorted: Boolean; const APreviousId: UTF8String = ''): TPageData;
var
  LData: TJSONData;
  LResults: TJSONData;
  LWork: TJSONData;
  LPageIds: TStringList;
  LId: UTF8String;
  LAbstract: TJSONData;
  LPreviousId: UTF8String;
  I: Integer;
begin
  Result := Default(TPageData);
  LData := GetJSON(ABody);
  try
    if NonnegativeInteger(LData, 'meta.page') <> APageNumber then
    begin
      raise EConvertError.Create('OpenAlex returned a different page');
    end;
    if NonnegativeInteger(LData, 'meta.per_page') <> PageSize then
    begin
      raise EConvertError.Create('OpenAlex returned a different page size');
    end;
    if ASorted and (Pos('&sort=' + SortValue + '&',
      Field(LData, 'meta.x_query.url') + '&') = 0) then
    begin
      raise EConvertError.Create('Provider did not echo the requested works sort');
    end;
    Result.Reported := NonnegativeInteger(LData, 'meta.count');
    if (AExpected >= 0) and (Result.Reported <> AExpected) then
    begin
      raise EConvertError.Create('Provider count changed during pagination');
    end;
    LResults := LData.FindPath('results');
    if not (LResults is TJSONArray) then
    begin
      raise EConvertError.Create('Missing OpenAlex result array');
    end;
    if LResults.Count <> ExpectedPageRows(Result.Reported, APageNumber) then
    begin
      raise EConvertError.CreateFmt('Page %d has %d rows, expected %d',
        [APageNumber, LResults.Count, ExpectedPageRows(Result.Reported, APageNumber)]);
    end;
    SetLength(Result.Ids, LResults.Count);
    SetLength(Result.Rows, LResults.Count);
    LPageIds := TStringList.Create;
    try
      LPageIds.CaseSensitive := True;
      LPageIds.Sorted := True;
      LPreviousId := APreviousId;
      for I := 0 to LResults.Count - 1 do
      begin
        LWork := LResults.Items[I];
        LId := Field(LWork, 'id');
        if not ExecRegExpr('^https://openalex\.org/W[0-9]+$', LId) then
        begin
          raise EConvertError.Create('Invalid work ID: ' + LId);
        end;
        if (LPageIds.IndexOf(LId) >= 0) or
          (Assigned(ASeen) and (ASeen.IndexOf(LId) >= 0)) then
        begin
          raise EConvertError.Create('Repeated work ID: ' + LId);
        end;
        if ASorted then
        begin
          if (Field(LWork, 'ids.openalex') <> LId) or (LId <= LPreviousId) then
          begin
            raise EConvertError.Create('Unexpected OpenAlex ID sort order at ' + LId);
          end;
          LPreviousId := LId;
        end;
        LPageIds.Add(LId);
        Result.Ids[I] := LId;
        LAbstract := LWork.FindPath('abstract_inverted_index');
        Result.Rows[I] := AQueryId + Tab + IntToStr(APageNumber) + Tab + LId + Tab +
          Field(LWork, 'doi') + Tab + Field(LWork, 'ids.pmid') + Tab +
          Field(LWork, 'title') + Tab + Field(LWork, 'publication_date') + Tab +
          Field(LWork, 'language') + Tab + Field(LWork, 'type') + Tab +
          Field(LWork, 'primary_location.landing_page_url') + Tab +
          BoolToStr(Assigned(LAbstract) and (LAbstract.JSONType = jtObject), True);
      end;
    finally
      LPageIds.Free;
    end;
  finally
    LData.Free;
  end;
end;

procedure CheckBoundary(const AExpected, ALive: TFields; APageNumber: Integer);
var
  I: Integer;
begin
  if Length(AExpected) <> Length(ALive) then
  begin
    raise EConvertError.CreateFmt('Live overlap length changed at page %d', [APageNumber]);
  end;
  for I := 0 to High(AExpected) do
  begin
    if AExpected[I] <> ALive[I] then
    begin
      raise EConvertError.CreateFmt('Live overlap changed at page %d, position %d',
        [APageNumber, I + 1]);
    end;
  end;
end;

procedure CheckPriorFiles(const ADirectory: String; AExpected: TStringList);
var
  LSearch: TSearchRec;
  LCount: Integer;
begin
  LCount := 0;
  if SysUtils.FindFirst(ADirectory + '*.json', faAnyFile and not faDirectory, LSearch) = 0 then
  begin
    try
      repeat
        if AExpected.IndexOf(LSearch.Name) < 0 then
        begin
          raise EConvertError.Create('Unexpected prior page file: ' + LSearch.Name);
        end;
        Inc(LCount);
      until SysUtils.FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
  end;
  if LCount <> AExpected.Count then
  begin
    raise EConvertError.Create('Prior page files do not match the audit');
  end;
end;

function RequestPath(const AQuery: TFields; ASorted: Boolean): UTF8String;
begin
  Result := SearchPath + UrlEncode(AQuery[2]) + '&filter=language%3A' + AQuery[1] +
    '&per_page=' + IntToStr(PageSize) + '&select=' + SelectedFields;
  if ASorted then
  begin
    Result := Result + '&sort=' + UrlEncode(SortValue);
  end;
  Result := Result + '&page=';
end;

function SortedMethod(const AQuery: TFields): UTF8String;
begin
  Result := 'GET https://' + Host + RequestPath(AQuery, True) + '{page}';
end;

function QueryAuditHeader(ASorted: Boolean): UTF8String;
begin
  Result := AuditHeader;
  if ASorted then
  begin
    Result := Result + Tab + 'request_method';
  end;
end;

procedure ValidatePrior(const ADirectory: String; AQueries, AOldRows: TStringList;
  ASorted: Boolean; out APrior: TPriorQueries);
var
  LAudit: TStringList;
  LNames: TStringList;
  LSeen: TStringList;
  LFields: TFields;
  LPage: TPageData;
  LName: String;
  LRow: UTF8String;
  LId: UTF8String;
  LIndex: Integer;
  LPageNumber: Integer;
  LPreviousId: UTF8String;
  LFieldCount: Integer;
  I: Integer;
begin
  LAudit := TStringList.Create;
  LNames := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LNames.Sorted := True;
    LSeen.CaseSensitive := True;
    LSeen.Sorted := True;
    LAudit.LoadFromFile(ADirectory + 'queries.tsv');
    AOldRows.LoadFromFile(ADirectory + 'results.tsv');
    LFieldCount := 9 + Ord(ASorted);
    if (LAudit.Count <> AQueries.Count + 1) or (LAudit[0] <> QueryAuditHeader(ASorted)) or
      (AOldRows.Count = 0) or (AOldRows[0] <> ResultHeader) then
    begin
      raise EConvertError.Create('Prior query plan or receipt header does not match');
    end;
    SetLength(APrior, AQueries.Count);
    LIndex := 1;
    for I := 0 to AQueries.Count - 1 do
    begin
      LFields := SplitFields(LAudit[I + 1], Tab);
      if (Length(LFields) <> LFieldCount) or
        (LFields[0] + Tab + LFields[1] + Tab + LFields[2] <> AQueries[I]) then
      begin
        raise EConvertError.CreateFmt('Prior query identity differs at row %d', [I + 2]);
      end;
      if ASorted and (LFields[9] <> SortedMethod(SplitFields(AQueries[I], Tab))) then
      begin
        raise EConvertError.CreateFmt('Prior sorted method differs at row %d', [I + 2]);
      end;
      with APrior[I] do
      begin
        Started := LFields[3];
        Complete := LFields[7] = 'Retrieved';
        FirstResult := LIndex;
        if not TryStrToInt(LFields[4], Reported) or
          not TryStrToInt(LFields[5], Retrieved) or
          not TryStrToInt(LFields[6], Pages) or (Pages < 0) or
          (Pages > MaximumOffsetResults div PageSize) or (Retrieved < 0) or
          ((LFields[7] <> 'Partial') and not Complete) or
          not ExecRegExpr('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$', Started) then
        begin
          raise EConvertError.Create('Invalid prior audit fields: ' + LFields[0]);
        end;
        if ((Pages = 0) and ((Reported <> -1) or (Retrieved <> 0) or Complete)) or
          ((Pages > 0) and ((Reported < Retrieved) or (Complete <> (Reported = Retrieved)) or
            (ExpectedPageRows(Reported, Pages) < 0) or
            ((ExpectedPageRows(Reported, Pages) = 0) and (Pages > 1)) or
            (Retrieved <> (Pages - 1) * PageSize + ExpectedPageRows(Reported, Pages)))) then
        begin
          raise EConvertError.Create('Inconsistent prior counts: ' + LFields[0]);
        end;
        LSeen.Clear;
        LPreviousId := '';
        for LPageNumber := 1 to Pages do
        begin
          LName := PageFileName(LFields[0], LPageNumber);
          LNames.Add(LName);
          try
            LPage := ParsePage(ReadPageBody(ADirectory + LName), LFields[0],
              LPageNumber, Reported, LSeen, ASorted, LPreviousId);
            for LRow in LPage.Rows do
            begin
              if (LIndex >= AOldRows.Count) or (LRow <> AOldRows[LIndex]) then
              begin
                raise EConvertError.CreateFmt('Prior result row differs at line %d', [LIndex + 1]);
              end;
              Inc(LIndex);
            end;
            for LId in LPage.Ids do
            begin
              LSeen.Add(LId);
              LPreviousId := LId;
            end;
            Boundary := LPage.Ids;
          except
            on LException: Exception do
            begin
              raise EConvertError.Create(LName + ': ' + LException.Message);
            end;
          end;
        end;
      end;
    end;
    if LIndex <> AOldRows.Count then
    begin
      raise EConvertError.Create('Extra rows in prior results.tsv');
    end;
    CheckPriorFiles(ADirectory, LNames);
  finally
    LSeen.Free;
    LNames.Free;
    LAudit.Free;
  end;
end;

function Retrieve(AClient: TEuropePmc; const AQuery: TFields; const AOutputDir,
  APriorDir: String; const APrior: TPriorQuery; AOldRows: TStringList;
  ASorted: Boolean; var AResults, AAudit: Text): Boolean;
var
  LSeen: TStringList;
  LPage: TPageData;
  LPath: UTF8String;
  LBody: UTF8String;
  LRow: UTF8String;
  LId: UTF8String;
  LName: String;
  LStarted: UTF8String;
  LPreviousId: UTF8String;
  LReported: Integer;
  LPages: Integer;
  LStatus: String;
  LDetail: String;
  I: Integer;
begin
  LStarted := UtcTimestamp;
  LPreviousId := '';
  LReported := -1;
  LPages := 0;
  LStatus := 'Partial';
  LDetail := '';
  LSeen := TStringList.Create;
  try
    LSeen.CaseSensitive := True;
    LSeen.Sorted := True;
    if APriorDir <> '' then
    begin
      LReported := APrior.Reported;
      LPages := APrior.Pages;
      LDetail := Format('Prior %d/%d in %d pages (%s | %s)', [APrior.Retrieved,
        LReported, LPages, APrior.Started, CleanField(APriorDir)]);
      for I := 1 to LPages do
      begin
        LName := PageFileName(AQuery[0], I);
        SavePage(AOutputDir + LName, ReadPageBody(APriorDir + LName));
      end;
      for I := APrior.FirstResult to APrior.FirstResult + APrior.Retrieved - 1 do
      begin
        LRow := AOldRows[I];
        LPreviousId := SplitFields(LRow, Tab)[2];
        LSeen.Add(LPreviousId);
        Write(AResults, LRow, #10);
      end;
    end;
    if APrior.Complete then
    begin
      LStarted := APrior.Started;
      LStatus := 'Retrieved';
      LDetail := LDetail + '. Complete capture reused';
    end
    else
    begin
      LPath := RequestPath(AQuery, ASorted);
      try
        if LPages > 0 then
        begin
          LDetail := LDetail + Format('. Live overlap page %d', [LPages]);
          LBody := FetchPage(AClient, LPath + IntToStr(LPages));
          LPage := ParsePage(LBody, AQuery[0], LPages, LReported, nil, ASorted);
          CheckBoundary(APrior.Boundary, LPage.Ids, LPages);
          LDetail := LDetail + ' matched';
        end;
        repeat
          if LPages >= MaximumOffsetResults div PageSize then
          begin
            raise EInOutError.Create('OpenAlex offset limit reached. Cursor retrieval is needed');
          end;
          LName := PageFileName(AQuery[0], LPages + 1);
          LBody := FetchPage(AClient, LPath + IntToStr(LPages + 1));
          LPage := ParsePage(LBody, AQuery[0], LPages + 1, LReported, LSeen,
            ASorted, LPreviousId);
          SavePage(AOutputDir + LName, LBody);
          for LId in LPage.Ids do
          begin
            LSeen.Add(LId);
            LPreviousId := LId;
          end;
          for LRow in LPage.Rows do
          begin
            Write(AResults, LRow, #10);
          end;
          Inc(LPages);
          LReported := LPage.Reported;
        until LSeen.Count = LReported;
        LStatus := 'Retrieved';
      except
        on LException: Exception do
        begin
          if LDetail <> '' then
          begin
            LDetail := LDetail + '. ';
          end;
          LDetail := LDetail + CleanField(LException.Message);
        end;
      end;
    end;
    Write(AAudit, AQuery[0], Tab, AQuery[1], Tab, AQuery[2], Tab, LStarted, Tab,
      LReported, Tab, LSeen.Count, Tab, LPages, Tab, LStatus, Tab, LDetail);
    if ASorted then
    begin
      Write(AAudit, Tab, SortedMethod(AQuery));
    end;
    Write(AAudit, #10);
    Flush(AResults);
    Flush(AAudit);
    WriteLn(AQuery[0], ': ', LSeen.Count, '/', LReported, ' in ', LPages, ' pages ', LStatus);
    Result := LStatus = 'Retrieved';
  finally
    LSeen.Free;
  end;
end;

procedure LoadPlan(const APath: String; AQueries: TStringList);
var
  LIds: TStringList;
  LFields: TFields;
  LRow: String;
begin
  AQueries.LoadFromFile(APath);
  if (AQueries.Count < 2) or (AQueries[0] <> QueryHeader) then
  begin
    raise EConvertError.Create('Missing OpenAlex query plan or unexpected header');
  end;
  AQueries.Delete(0);
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    for LRow in AQueries do
    begin
      LFields := SplitFields(LRow, Tab);
      if (Length(LFields) <> 3) or not ExecRegExpr('^[a-z0-9-]+$', LFields[0]) or
        not ExecRegExpr('^[a-z]{2,3}$', LFields[1]) or (Trim(LFields[2]) = '') then
      begin
        raise EConvertError.Create('Invalid OpenAlex query row: ' + LRow);
      end;
      LIds.Add(LFields[0]);
    end;
  finally
    LIds.Free;
  end;
end;

procedure RequireFreshOutput(const ADirectory: String);
var
  LSearch: TSearchRec;
begin
  if not ForceDirectories(ADirectory) then
  begin
    raise EInOutError.Create('Cannot create OpenAlex output folder');
  end;
  if SysUtils.FindFirst(ADirectory + '*', faAnyFile, LSearch) = 0 then
  begin
    try
      repeat
        if (LSearch.Name <> '.') and (LSearch.Name <> '..') then
        begin
          raise EInOutError.Create('Use a fresh output directory to preserve prior captures');
        end;
      until SysUtils.FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
  end;
end;

procedure Run(const APlan, AOutput: String; const APrior: String = '';
  ASorted: Boolean = False);
var
  LQueries: TStringList;
  LOldRows: TStringList;
  LPriorQueries: TPriorQueries;
  LClient: TEuropePmc;
  LResults: Text;
  LAudit: Text;
  LOutput: String;
  LPrior: String;
  LComplete: Boolean;
  I: Integer;
begin
  LQueries := TStringList.Create;
  LOldRows := TStringList.Create;
  try
    LoadPlan(APlan, LQueries);
    LOutput := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
    if APrior <> '' then
    begin
      LPrior := IncludeTrailingPathDelimiter(ExpandFileName(APrior));
      if SameText(Copy(LOutput, 1, Length(LPrior)), LPrior) then
      begin
        raise EInOutError.Create('Use an output directory outside the prior capture');
      end;
      ValidatePrior(LPrior, LQueries, LOldRows, ASorted, LPriorQueries);
    end
    else
    begin
      LPrior := '';
      SetLength(LPriorQueries, LQueries.Count);
    end;
    if ASorted or (LPrior <> '') then
    begin
      RequireFreshOutput(LOutput);
    end
    else
    begin
      if not ForceDirectories(LOutput) then
      begin
        raise EInOutError.Create('Cannot create OpenAlex output folder');
      end;
      if FileExists(LOutput + 'queries.tsv') or FileExists(LOutput + 'results.tsv') then
      begin
        raise EInOutError.Create('Use a separate output directory to preserve the prior run');
      end;
    end;
    LClient := TEuropePmc.Create(Host);
    try
      AssignFile(LResults, LOutput + 'results.tsv');
      Rewrite(LResults);
      try
        AssignFile(LAudit, LOutput + 'queries.tsv');
        Rewrite(LAudit);
        try
          SetTextCodePage(LResults, CP_UTF8);
          SetTextCodePage(LAudit, CP_UTF8);
          Write(LResults, ResultHeader, #10);
          Write(LAudit, QueryAuditHeader(ASorted), #10);
          LComplete := True;
          for I := 0 to LQueries.Count - 1 do
          begin
            if not Retrieve(LClient, SplitFields(LQueries[I], Tab), LOutput, LPrior,
              LPriorQueries[I], LOldRows, ASorted, LResults, LAudit) then
            begin
              LComplete := False;
            end;
          end;
          if not LComplete then
          begin
            raise EInOutError.Create('At least one query did not reconcile. See queries.tsv');
          end;
        finally
          CloseFile(LAudit);
        end;
      finally
        CloseFile(LResults);
      end;
    finally
      LClient.Free;
    end;
  finally
    LOldRows.Free;
    LQueries.Free;
  end;
end;

procedure VerifySortedCapture(const APlan, ACapture: String);
var
  LQueries: TStringList;
  LOldRows: TStringList;
  LPrior: TPriorQueries;
  I: Integer;
begin
  LQueries := TStringList.Create;
  LOldRows := TStringList.Create;
  try
    LoadPlan(APlan, LQueries);
    ValidatePrior(IncludeTrailingPathDelimiter(ExpandFileName(ACapture)), LQueries,
      LOldRows, True, LPrior);
    for I := 0 to High(LPrior) do
    begin
      WriteLn(SplitFields(LQueries[I], Tab)[0], ': ', LPrior[I].Retrieved, '/',
        LPrior[I].Reported, ' in ', LPrior[I].Pages, ' sorted pages validated');
    end;
  finally
    LOldRows.Free;
    LQueries.Free;
  end;
end;

function AbstractText(AIndex: TJSONData): UTF8String;
var
  LIndex: TJSONObject;
  LPositions: TJSONData;
  LWords: TFields;
  LPosition: Integer;
  I: Integer;
  J: Integer;
begin
  Result := '';
  if not (AIndex is TJSONObject) then
  begin
    Exit;
  end;
  LIndex := TJSONObject(AIndex);
  LWords := nil;
  for I := 0 to LIndex.Count - 1 do
  begin
    LPositions := LIndex.Items[I];
    if LPositions.JSONType <> jtArray then
    begin
      raise EConvertError.Create('Invalid OpenAlex abstract token positions');
    end;
    for J := 0 to LPositions.Count - 1 do
    begin
      if LPositions.Items[J].JSONType <> jtNumber then
      begin
        raise EConvertError.Create('Invalid OpenAlex abstract token position');
      end;
      LPosition := LPositions.Items[J].AsInteger;
      if LPosition < 0 then
      begin
        raise EConvertError.Create('Negative OpenAlex abstract token position');
      end;
      if LPosition >= Length(LWords) then
      begin
        SetLength(LWords, LPosition + 1);
      end;
      if LWords[LPosition] <> '' then
      begin
        raise EConvertError.Create('Repeated OpenAlex abstract token position');
      end;
      LWords[LPosition] := LIndex.Names[I];
    end;
  end;
  for I := 0 to High(LWords) do
  begin
    if I > 0 then
    begin
      Result := Result + ' ';
    end;
    Result := Result + LWords[I];
  end;
  Result := CleanField(Result);
end;

procedure ReadAbstracts(const ACaptures, AOutput: String);
var
  LCaptures: String;
  LFiles: TStringList;
  LSeen: TStringList;
  LSearch: TSearchRec;
  LPage: TJSONData;
  LResults: TJSONData;
  LWork: TJSONData;
  LStream: TFileStream;
  LOutput: Text;
  LFile: String;
  LId: UTF8String;
  I: Integer;
begin
  LCaptures := IncludeTrailingPathDelimiter(ExpandFileName(ACaptures));
  LFiles := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LFiles.Sorted := True;
    LSeen.Sorted := True;
    if SysUtils.FindFirst(LCaptures + '*.json', faAnyFile and not faDirectory, LSearch) <> 0 then
    begin
      raise EInOutError.Create('No OpenAlex page captures found');
    end;
    try
      repeat
        LFiles.Add(LSearch.Name);
      until SysUtils.FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
    AssignFile(LOutput, AOutput);
    Rewrite(LOutput);
    try
      SetTextCodePage(LOutput, CP_UTF8);
      Write(LOutput, 'work_id'#9'language'#9'title'#9'indexed_abstract', #10);
      for LFile in LFiles do
      begin
        LStream := TFileStream.Create(LCaptures + LFile, fmOpenRead or fmShareDenyWrite);
        try
          LPage := GetJSON(LStream);
        finally
          LStream.Free;
        end;
        try
          LResults := LPage.FindPath('results');
          if not (LResults is TJSONArray) then
          begin
            raise EConvertError.Create('Missing OpenAlex result array in ' + LFile);
          end;
          for I := 0 to LResults.Count - 1 do
          begin
            LWork := LResults.Items[I];
            LId := Field(LWork, 'id');
            if not ExecRegExpr('^https://openalex\.org/W[0-9]+$', LId) then
            begin
              raise EConvertError.Create('Invalid OpenAlex work ID in ' + LFile);
            end;
            if LSeen.IndexOf(LId) >= 0 then
            begin
              Continue;
            end;
            LSeen.Add(LId);
            Write(LOutput, LId, Tab, Field(LWork, 'language'), Tab, Field(LWork, 'title'), Tab,
              AbstractText(LWork.FindPath('abstract_inverted_index')), #10);
          end;
        finally
          LPage.Free;
        end;
      end;
    finally
      CloseFile(LOutput);
    end;
  finally
    LSeen.Free;
    LFiles.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount = 3) and (ParamStr(1) = 'abstracts') then
    begin
      ReadAbstracts(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'audit-pairs') then
    begin
      AuditRegionalPairs(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 7) and (ParamStr(1) = 'audit-context') then
    begin
      AuditRegionalContext(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6),
        ParamStr(7));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'resume') and (ParamStr(3) <> '') then
    begin
      Run(ParamStr(2), ParamStr(4), ParamStr(3));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'sorted') then
    begin
      Run(ParamStr(2), ParamStr(3), '', True);
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'resume-sorted') and (ParamStr(3) <> '') then
    begin
      Run(ParamStr(2), ParamStr(4), ParamStr(3), True);
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'verify-sorted') then
    begin
      VerifySortedCapture(ParamStr(2), ParamStr(3));
    end
    else if ParamCount = 2 then
    begin
      Run(ParamStr(1), ParamStr(2));
    end
    else
    begin
      raise EArgumentException.Create('Usage: foodexperiment.openalex QUERY_TSV OUTPUT_DIR' +
        LineEnding + '       foodexperiment.openalex resume QUERY_TSV PRIOR_CAPTURE_DIR FRESH_OUTPUT_DIR' +
        LineEnding + '       foodexperiment.openalex sorted QUERY_TSV OUTPUT_DIR' +
        LineEnding + '       foodexperiment.openalex resume-sorted QUERY_TSV PRIOR_DIR OUTPUT_DIR' +
        LineEnding + '       foodexperiment.openalex verify-sorted QUERY_TSV CAPTURE_DIR' +
        LineEnding + '       foodexperiment.openalex abstracts CAPTURE_DIR BUILD_TSV' +
        LineEnding + '       foodexperiment.openalex audit-context INDEX PRIORITY ES PT FR_RU OUTPUT' +
        LineEnding + '       foodexperiment.openalex audit-pairs LEXICAL REVIEWS_OR_DASH');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
