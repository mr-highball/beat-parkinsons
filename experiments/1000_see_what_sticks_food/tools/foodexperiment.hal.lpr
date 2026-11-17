{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentHal;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, fpjson, jsonparser, RegExpr, foodexperiment.https,
  foodexperiment.externaldata;

const
  Tab = #9;
  Host = 'api.archives-ouvertes.fr';
  PageSize = 50;
  RequestSpacingMs = 1000;
  PlanHeader = 'query_id'#9'expression';
  ResultHeader = 'query_id'#9'page'#9'docid'#9'hal_id'#9'title'#9'doi'#9'pmid'#9 +
    'produced_date'#9'submitted_date'#9'language'#9'type'#9'landing_page'#9'has_abstract';
  AuditHeader = 'query_id'#9'started_utc'#9'reported'#9'retrieved'#9'pages'#9'status'#9'detail';
  Fields = 'docid,halId_s,title_s,abstract_s,doiId_s,pmidId_s,producedDate_s,submittedDate_s,' +
    'language_s,docType_s,uri_s,fileMain_s,authFullName_s';

function Field(AObject: TJSONData; const AName: String): UTF8String;
var
  LValue: TJSONData;
begin
  Result := '';
  LValue := AObject.FindPath(AName);
  if (LValue is TJSONArray) and (LValue.Count > 0) then
  begin
    LValue := LValue.Items[0];
  end;
  if Assigned(LValue) and (LValue.JSONType = jtString) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

function Fetch(AClient: TEuropePmc; const APath, AFile: UTF8String): TJSONData;
var
  LResponse: TSearchResponse;
  LStream: TFileStream;
  LAttempt: Integer;
  LDelay: DWORD;
begin
  LDelay := RequestSpacingMs;
  for LAttempt := 1 to 3 do
  begin
    Sleep(LDelay);
    LResponse := AClient.GetPath(APath);
    if not ((LResponse.Status = 429) or
      ((LResponse.Status >= 502) and (LResponse.Status <= 504))) then
    begin
      Break;
    end;
    if LResponse.RetryAfterSeconds > 30 then
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
    raise EInOutError.CreateFmt('HAL HTTP %d, Retry-After %d seconds',
      [LResponse.Status, LResponse.RetryAfterSeconds]);
  end;
  if LResponse.Body = '' then
  begin
    raise EInOutError.Create('HAL returned an empty response');
  end;
  LStream := TFileStream.Create(AFile, fmCreate);
  try
    LStream.WriteBuffer(LResponse.Body[1], Length(LResponse.Body));
  finally
    LStream.Free;
  end;
  Result := GetJSON(LResponse.Body);
end;

procedure AppendRecord(var AOutput: Text; AWork: TJSONData; const AQueryId: UTF8String;
  APage: Integer; ASeen: TStringList);
var
  LId: UTF8String;
  LHalId: UTF8String;
  LTitle: UTF8String;
begin
  LId := Field(AWork, 'docid');
  LHalId := Field(AWork, 'halId_s');
  LTitle := Field(AWork, 'title_s');
  if not ExecRegExpr('^[0-9]+$', LId) or (LHalId = '') or (LTitle = '') then
  begin
    raise EConvertError.Create('HAL record has an invalid ID or missing title');
  end;
  ASeen.Add(LId);
  Write(AOutput, AQueryId, Tab, APage, Tab, LId, Tab, LHalId, Tab, LTitle, Tab,
    Field(AWork, 'doiId_s'), Tab, Field(AWork, 'pmidId_s'), Tab, Field(AWork, 'producedDate_s'),
    Tab, Field(AWork, 'submittedDate_s'), Tab, Field(AWork, 'language_s'), Tab,
    Field(AWork, 'docType_s'), Tab, Field(AWork, 'uri_s'), Tab,
    BoolToStr(Field(AWork, 'abstract_s') <> '', True), #10);
end;

function Retrieve(AClient: TEuropePmc; const AQuery: TFields; const ADirectory: String;
  var AResults, AAudit: Text): Boolean;
var
  LBase: UTF8String;
  LCursor: UTF8String;
  LNext: UTF8String;
  LStarted: UTF8String;
  LDetail: UTF8String;
  LSeen: TStringList;
  LPage: TJSONData;
  LCount: TJSONData;
  LExact: TJSONData;
  LRecords: TJSONData;
  LReported: Integer;
  LPages: Integer;
  I: Integer;
begin
  LBase := '/search/?q=' + UrlEncode(AQuery[1]) + '&wt=json&rows=' + IntToStr(PageSize) +
    '&sort=docid%20asc&fl=' + Fields + '&cursorMark=';
  LCursor := '*';
  LStarted := UtcTimestamp;
  LReported := -1;
  LPages := 0;
  LDetail := '';
  LSeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    try
      repeat
        LPage := Fetch(AClient, LBase + UrlEncode(LCursor),
          ADirectory + Format('%s-%d.json', [AQuery[0], LPages + 1]));
        try
          LCount := LPage.FindPath('response.numFound');
          LExact := LPage.FindPath('response.numFoundExact');
          LRecords := LPage.FindPath('response.docs');
          LNext := Field(LPage, 'nextCursorMark');
          if not Assigned(LCount) or (LCount.JSONType <> jtNumber) or (LCount.AsInteger < 0) or
            not Assigned(LExact) or (LExact.JSONType <> jtBoolean) or not LExact.AsBoolean or
            not (LRecords is TJSONArray) or (LNext = '') then
          begin
            raise EConvertError.Create('HAL response lacks an exact count, records or cursor');
          end;
          if LReported < 0 then
          begin
            LReported := LCount.AsInteger;
          end;
          if LCount.AsInteger <> LReported then
          begin
            raise EConvertError.Create('HAL count changed during pagination');
          end;
          Inc(LPages);
          for I := 0 to LRecords.Count - 1 do
          begin
            AppendRecord(AResults, LRecords.Items[I], AQuery[0], LPages, LSeen);
          end;
          if LSeen.Count > LReported then
          begin
            raise EConvertError.Create('Retrieved more records than HAL reported');
          end;
          if LNext = LCursor then
          begin
            if (LRecords.Count <> 0) or (LSeen.Count <> LReported) then
            begin
              raise EConvertError.Create('HAL cursor ended before counts reconciled');
            end;
            Break;
          end;
          if LRecords.Count = 0 then
          begin
            raise EConvertError.Create('HAL cursor advanced with no records');
          end;
          LCursor := LNext;
        finally
          LPage.Free;
        end;
      until False;
    except
      on LException: Exception do
      begin
        LDetail := CleanField(LException.Message);
      end;
    end;
    Result := LDetail = '';
    Write(AAudit, AQuery[0], Tab, LStarted, Tab, LReported, Tab, LSeen.Count, Tab,
      LPages, Tab, BoolToStr(Result, 'Retrieved', 'Partial'), Tab, LDetail, #10);
    Flush(AResults);
    Flush(AAudit);
    WriteLn(AQuery[0], ': ', LSeen.Count, '/', LReported, ' in ', LPages, ' responses');
  finally
    LSeen.Free;
  end;
end;

procedure Run(const APlan, AOutput: String);
var
  LPlan: TStringList;
  LIds: TStringList;
  LQuery: TFields;
  LDirectory: String;
  LClient: TEuropePmc;
  LResults: Text;
  LAudit: Text;
  LComplete: Boolean;
  I: Integer;
begin
  LPlan := TStringList.Create;
  LIds := TStringList.Create;
  try
    LPlan.LoadFromFile(APlan);
    if (LPlan.Count < 2) or (LPlan[0] <> PlanHeader) then
    begin
      raise EConvertError.Create('Missing HAL query plan or unexpected header');
    end;
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    for I := 1 to LPlan.Count - 1 do
    begin
      LQuery := SplitFields(LPlan[I], Tab);
      if (Length(LQuery) <> 2) or not ExecRegExpr('^[a-z0-9-]+$', LQuery[0]) or
        (Trim(LQuery[1]) = '') then
      begin
        raise EConvertError.Create('Invalid HAL query row: ' + LPlan[I]);
      end;
      LIds.Add(LQuery[0]);
    end;
    LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
    if not ForceDirectories(LDirectory) or FileExists(LDirectory + 'queries.tsv') or
      FileExists(LDirectory + 'results.tsv') then
    begin
      raise EInOutError.Create('Use a separate HAL output directory for each run');
    end;
    LClient := TEuropePmc.Create(Host);
    try
      AssignFile(LResults, LDirectory + 'results.tsv');
      Rewrite(LResults);
      try
        AssignFile(LAudit, LDirectory + 'queries.tsv');
        Rewrite(LAudit);
        try
          SetTextCodePage(LResults, CP_UTF8);
          SetTextCodePage(LAudit, CP_UTF8);
          Write(LResults, ResultHeader, #10);
          Write(LAudit, AuditHeader, #10);
          LComplete := True;
          for I := 1 to LPlan.Count - 1 do
          begin
            if not Retrieve(LClient, SplitFields(LPlan[I], Tab), LDirectory, LResults, LAudit) then
            begin
              LComplete := False;
            end;
          end;
          if not LComplete then
          begin
            raise EInOutError.Create('Some HAL queries were partial. See queries.tsv');
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
    LIds.Free;
    LPlan.Free;
  end;
end;

function IndexedAbstract(ARecord: TJSONData): UTF8String;
var
  LAbstracts: TJSONData;
  LText: UTF8String;
  I: Integer;
begin
  Result := '';
  LAbstracts := ARecord.FindPath('abstract_s');
  if not (LAbstracts is TJSONArray) then
  begin
    Result := Field(ARecord, 'abstract_s');
    Exit;
  end;
  for I := 0 to LAbstracts.Count - 1 do
  begin
    LText := CleanField(LAbstracts.Items[I].AsString);
    if LText = '' then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + ' | ';
    end;
    Result := Result + LText;
  end;
end;

procedure ReadAbstracts(const ACaptures, AOutput: String);
var
  LDirectory: String;
  LFileName: String;
  LSearch: TSearchRec;
  LFiles: TStringList;
  LSeen: TStringList;
  LStream: TFileStream;
  LPage: TJSONData;
  LRecords: TJSONData;
  LRecord: TJSONData;
  LId: UTF8String;
  LOutput: Text;
  I: Integer;
begin
  LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ACaptures));
  LFiles := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LFiles.Sorted := True;
    LSeen.Sorted := True;
    if SysUtils.FindFirst(LDirectory + '*.json', faAnyFile and not faDirectory, LSearch) <> 0 then
    begin
      raise EInOutError.Create('No HAL page captures found');
    end;
    try
      repeat
        LFiles.Add(LSearch.Name);
      until SysUtils.FindNext(LSearch) <> 0;
    finally
      SysUtils.FindClose(LSearch);
    end;
    if FileExists(AOutput) then
    begin
      raise EInOutError.Create('Use a new HAL abstract output file');
    end;
    AssignFile(LOutput, AOutput);
    Rewrite(LOutput);
    try
      SetTextCodePage(LOutput, CP_UTF8);
      Write(LOutput, 'docid'#9'hal_id'#9'language'#9'title'#9'indexed_abstract', #10);
      for LFileName in LFiles do
      begin
        LStream := TFileStream.Create(LDirectory + LFileName, fmOpenRead or fmShareDenyWrite);
        try
          LPage := GetJSON(LStream);
        finally
          LStream.Free;
        end;
        try
          LRecords := LPage.FindPath('response.docs');
          if not (LRecords is TJSONArray) then
          begin
            raise EConvertError.Create('Missing HAL records in ' + LFileName);
          end;
          for I := 0 to LRecords.Count - 1 do
          begin
            LRecord := LRecords.Items[I];
            LId := Field(LRecord, 'docid');
            if not ExecRegExpr('^[0-9]+$', LId) then
            begin
              raise EConvertError.Create('Invalid HAL document ID in ' + LFileName);
            end;
            if LSeen.IndexOf(LId) >= 0 then
            begin
              Continue;
            end;
            LSeen.Add(LId);
            Write(LOutput, LId, Tab, Field(LRecord, 'halId_s'), Tab, Field(LRecord, 'language_s'),
              Tab, Field(LRecord, 'title_s'), Tab, IndexedAbstract(LRecord), #10);
          end;
        finally
          LPage.Free;
        end;
      end;
    finally
      CloseFile(LOutput);
    end;
    WriteLn(LSeen.Count, ' distinct HAL records reconstructed');
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
    else if ParamCount = 2 then
    begin
      Run(ParamStr(1), ParamStr(2));
    end
    else
    begin
      raise EArgumentException.Create('Usage: foodexperiment.hal QUERY_TSV OUTPUT_DIR' +
        LineEnding + '       foodexperiment.hal abstracts CAPTURE_DIR BUILD_TSV');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
