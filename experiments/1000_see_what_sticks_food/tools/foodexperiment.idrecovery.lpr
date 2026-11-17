{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentIdRecovery;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, foodexperiment.bibliography,
  foodexperiment.externaldata, foodexperiment.https, foodexperiment.matching;

const
  Tab = #9;
  BatchSize = 70;
  MaximumAttempts = 4;
  RequestSpacingMs = 200;

type
  TProviderRecord = class
    Key: UTF8String;
    Source: UTF8String;
    Id: UTF8String;
    Rank: Integer;
    Row: UTF8String;
    Origin: UTF8String;
    OriginQuery: UTF8String;
    Batch: UTF8String;
    MissingReason: UTF8String;
    HasAbstract: Boolean;
  end;

  TProviderRecords = array of TProviderRecord;

  TRecovery = class
  private
    FQuery: TFields;
    FOutput: String;
    FIds: TStringList;
    FRanked: TProviderRecords;
    FClient: TEuropePmc;
    FRequests: Text;
    FSameQueryRows: Integer;
    FSameQueryOverlap: Integer;
    FRequestsThisRun: Integer;
    procedure LoadIds(const ADirectory: String);
    procedure LoadCore(const ADirectory: String; const AQueryId: UTF8String);
    procedure SaveOutputs;
    procedure Recover;
    procedure ProcessBatch(const AName: String; const ARecords: TProviderRecords;
      const AField: UTF8String; AIndividualFallback: Boolean);
    function Fetch(const AName, AExpression: UTF8String; ACount: Integer;
      out AResponse: TSearchResponse): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const AIdsDir, ACoreDir, AQueryId, AOutput: String);
  end;

procedure OpenTsv(var AFile: Text; const APath: String; AAppend: Boolean = False);
begin
  Assign(AFile, APath);
  SetTextCodePage(AFile, CP_UTF8);
  if AAppend then
  begin
    Append(AFile);
  end
  else
  begin
    Rewrite(AFile);
  end;
end;

procedure WriteRow(var AFile: Text; const AFields: array of UTF8String);
var
  I: Integer;
begin
  for I := 0 to High(AFields) do
  begin
    if I <> 0 then
    begin
      Write(AFile, Tab);
    end;
    Write(AFile, CleanField(AFields[I]));
  end;
  Write(AFile, #10);
end;

procedure SaveBytes(const APath: String; const ABytes: UTF8String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath + '.tmp', fmCreate);
  try
    if ABytes <> '' then
    begin
      LFile.WriteBuffer(ABytes[1], Length(ABytes));
    end;
  finally
    LFile.Free;
  end;
  if not RenameFile(APath + '.tmp', APath) then
  begin
    raise EInOutError.Create('Cannot publish ' + APath);
  end;
end;

constructor TRecovery.Create;
begin
  inherited Create;
  FIds := TStringList.Create;
  FIds.CaseSensitive := True;
  FIds.Sorted := True;
  FIds.Duplicates := dupError;
  FIds.OwnsObjects := True;
end;

destructor TRecovery.Destroy;
begin
  FClient.Free;
  FIds.Free;
  inherited Destroy;
end;

procedure TRecovery.LoadIds(const ADirectory: String);
var
  LPage: TStringList;
  LAuthoritativeIds: TStringList;
  LCursors: TStringList;
  LRecord: TProviderRecord;
  LName: String;
  LCursor: UTF8String;
  LTotal: Integer;
  LPageNumber: Integer;
  LRank: Integer;
  LSeparator: Integer;
  I: Integer;
begin
  LPage := TStringList.Create;
  LAuthoritativeIds := TStringList.Create;
  LCursors := TStringList.Create;
  try
    LAuthoritativeIds.LoadFromFile(ADirectory + 'source-ids.txt');
    LAuthoritativeIds.CaseSensitive := True;
    LAuthoritativeIds.Sort;
    LTotal := LAuthoritativeIds.Count;
    SetLength(FRanked, LTotal);
    LCursor := '*';
    LPageNumber := 0;
    LRank := 0;
    repeat
      if (LCursor = '') or (LCursors.IndexOf(LCursor) >= 0) then
      begin
        raise EConvertError.Create('Identifier replay cursor ended before the reported count');
      end;
      LCursors.Add(LCursor);
      Inc(LPageNumber);
      LName := ADirectory + Format('page-%.5d.txt', [LPageNumber]);
      LPage.LoadFromFile(LName);
      if (LPage.Count < 4) or (LPage[0] <> LCursor) or
        (StrToInt(LPage[2]) <> LTotal) or (StrToInt(LPage[3]) <> LPage.Count - 4) then
      begin
        raise EConvertError.Create('Invalid identifier checkpoint ' + LName);
      end;
      for I := 4 to LPage.Count - 1 do
      begin
        LSeparator := Pos(':', LPage[I]);
        if (LSeparator < 2) or (LSeparator = Length(LPage[I])) or (LRank >= LTotal) then
        begin
          raise EConvertError.Create('Invalid identifier in ' + LName);
        end;
        LRecord := TProviderRecord.Create;
        try
          LRecord.Key := LPage[I];
          LRecord.Source := Copy(LRecord.Key, 1, LSeparator - 1);
          LRecord.Id := Copy(LRecord.Key, LSeparator + 1, MaxInt);
          LRecord.Rank := LRank + 1;
          FIds.AddObject(LRecord.Key, LRecord);
        except
          LRecord.Free;
          raise;
        end;
        FRanked[LRank] := LRecord;
        Inc(LRank);
      end;
      LCursor := LPage[1];
    until (LRank = LTotal) or (LPage.Count = 4);
    if LRank <> LTotal then
    begin
      raise EConvertError.Create('Identifier checkpoint is incomplete');
    end;
    for I := 0 to FIds.Count - 1 do
    begin
      if FIds[I] <> LAuthoritativeIds[I] then
      begin
        raise EConvertError.Create('Ranked identifier pages differ from source-ids.txt');
      end;
    end;
  finally
    LCursors.Free;
    LAuthoritativeIds.Free;
    LPage.Free;
  end;
end;

procedure TRecovery.LoadCore(const ADirectory: String; const AQueryId: UTF8String);
var
  LInput: Text;
  LLine: UTF8String;
  LFields: TFields;
  LKey: UTF8String;
  LItem: TProviderRecord;
  LSameQuery: Boolean;
  LIndex: Integer;
  I: Integer;
begin
  Assign(LInput, ADirectory + 'ingredient_queries.tsv');
  SetTextCodePage(LInput, CP_UTF8);
  Reset(LInput);
  try
    while not Eof(LInput) do
    begin
      ReadLn(LInput, LLine);
      LFields := SplitFields(LLine, Tab);
      if (Length(LFields) = 10) and (LFields[0] = AQueryId) then
      begin
        FQuery := LFields;
        Break;
      end;
    end;
  finally
    Close(LInput);
  end;
  if Length(FQuery) = 0 then
  begin
    raise EConvertError.Create('Query missing in saved bibliography audit: ' + AQueryId);
  end;
  if StrToInt(FQuery[6]) <> FIds.Count then
  begin
    raise EConvertError.Create('Saved bibliography and identifier replay hit counts differ');
  end;
  Assign(LInput, ADirectory + 'ingredient_results.tsv');
  SetTextCodePage(LInput, CP_UTF8);
  Reset(LInput);
  try
    ReadLn(LInput, LLine);
    if LLine <> BibliographyHeader then
    begin
      raise EConvertError.Create('Unexpected saved bibliography header');
    end;
    while not Eof(LInput) do
    begin
      ReadLn(LInput, LLine);
      LFields := SplitFields(LLine, Tab);
      if Length(LFields) <> 15 then
      begin
        raise EConvertError.Create('Malformed saved bibliography row');
      end;
      LSameQuery := LFields[0] = AQueryId;
      if LSameQuery then
      begin
        Inc(FSameQueryRows);
      end;
      LKey := LFields[5] + ':' + LFields[6];
      LIndex := FIds.IndexOf(LKey);
      if LIndex < 0 then
      begin
        Continue;
      end;
      LItem := FIds.Objects[LIndex] as TProviderRecord;
      if LSameQuery and (LItem.Origin = 'same-query-core') then
      begin
        raise EConvertError.Create('Duplicate same-query bibliography key: ' + LKey);
      end;
      if not LSameQuery and ((LItem.Origin = 'same-query-core') or
        ((LItem.Row <> '') and (LItem.HasAbstract or (LFields[14] = '')))) then
      begin
        Continue;
      end;
      LItem.Origin := 'cross-query-core';
      if LSameQuery then
      begin
        LItem.Origin := 'same-query-core';
        Inc(FSameQueryOverlap);
      end;
      LItem.OriginQuery := LFields[0];
      LItem.HasAbstract := LFields[14] <> '';
      LItem.Row := FQuery[0] + Tab + FQuery[1] + Tab + FQuery[2] + Tab + IntToStr(LItem.Rank);
      for I := 4 to High(LFields) do
      begin
        LItem.Row := LItem.Row + Tab + LFields[I];
      end;
    end;
  finally
    Close(LInput);
  end;
  if FSameQueryRows <> StrToInt(FQuery[7]) then
  begin
    raise EConvertError.Create('Same-query bibliography row count disagrees with audit');
  end;
end;

function TRecovery.Fetch(const AName, AExpression: UTF8String; ACount: Integer;
  out AResponse: TSearchResponse): Boolean;
var
  LAttempt: Integer;
  LError: UTF8String;
  LDelay: Integer;
begin
  if FClient = nil then
  begin
    FClient := TEuropePmc.Create;
  end;
  for LAttempt := 1 to MaximumAttempts do
  begin
    LError := '';
    AResponse := Default(TSearchResponse);
    Inc(FRequestsThisRun);
    try
      AResponse := FClient.SearchPage(AExpression, '*', ACount);
    except
      on LException: EOSError do
      begin
        LError := LException.Message;
      end;
    end;
    WriteRow(FRequests, [UtcTimestamp, AName, IntToStr(LAttempt), IntToStr(ACount),
      IntToStr(AResponse.Status), IntToStr(Length(AResponse.Body)), AExpression, LError]);
    Flush(FRequests);
    Result := AResponse.Status = 200;
    if Result or ((AResponse.Status <> 0) and (AResponse.Status <> 429) and
      ((AResponse.Status < 500) or (AResponse.Status > 504))) then
    begin
      Sleep(RequestSpacingMs);
      Exit;
    end;
    if LAttempt < MaximumAttempts then
    begin
      LDelay := 1000 shl (LAttempt - 1);
      if (AResponse.RetryAfterSeconds > 0) and (AResponse.RetryAfterSeconds <= 60) then
      begin
        LDelay := AResponse.RetryAfterSeconds * 1000;
      end;
      Sleep(LDelay);
    end;
  end;
  Result := False;
end;

procedure TRecovery.ProcessBatch(const AName: String; const ARecords: TProviderRecords;
  const AField: UTF8String; AIndividualFallback: Boolean);
var
  LExpression: UTF8String;
  LBody: UTF8String;
  LPath: String;
  LResponse: TSearchResponse;
  LDocument: TJSONData;
  LHits: TJSONData;
  LResults: TJSONData;
  LRow: TJSONData;
  LId: UTF8String;
  LKey: UTF8String;
  LExpected: TStringList;
  LFound: TStringList;
  LRecord: TProviderRecord;
  LIndex: Integer;
  LFromCache: Boolean;
  I: Integer;
begin
  LExpected := TStringList.Create;
  LFound := TStringList.Create;
  try
    LExpected.CaseSensitive := True;
    LExpected.Sorted := True;
    LExpected.Duplicates := dupError;
    LFound.CaseSensitive := True;
    LFound.Sorted := True;
    LFound.Duplicates := dupError;
    LExpression := 'SRC:' + ARecords[0].Source + ' AND (';
    for I := 0 to High(ARecords) do
    begin
      LRecord := ARecords[I];
      if I > 0 then
      begin
        LExpression := LExpression + ' OR ';
      end;
      LExpression := LExpression + AField + ':"' +
        StringReplace(StringReplace(LRecord.Id, '\', '\\', [rfReplaceAll]),
          '"', '\"', [rfReplaceAll]) + '"';
      LExpected.AddObject(LRecord.Key, LRecord);
      LRecord.Batch := AName;
    end;
    LExpression := LExpression + ')';
    LPath := FOutput + AName + '.json';
    LFromCache := FileExists(LPath);
    if LFromCache then
    begin
      LBody := ReadBytes(LPath);
    end
    else if Fetch(AName, LExpression, Length(ARecords), LResponse) then
    begin
      LBody := LResponse.Body;
    end
    else
    begin
      for LRecord in ARecords do
      begin
        LRecord.MissingReason := 'transport or HTTP ' + IntToStr(LResponse.Status);
      end;
      Exit;
    end;
    LDocument := GetJSON(LBody, True);
    try
      LHits := LDocument.FindPath('hitCount');
      LResults := LDocument.FindPath('resultList.result');
      if not Assigned(LHits) or (LHits.JSONType <> jtNumber) or not Assigned(LResults) or
        (LResults.JSONType <> jtArray) or (LHits.AsInt64 <> LResults.Count) or
        (LResults.Count > Length(ARecords)) then
      begin
        raise EConvertError.Create('Invalid or incomplete exact-ID response for ' + AName);
      end;
      for I := 0 to LResults.Count - 1 do
      begin
        LRow := LResults.Items[I];
        LId := JsonText(LRow, 'id');
        LKey := JsonText(LRow, 'source') + ':' + LId;
        LIndex := LExpected.IndexOf(LKey);
        if LIndex < 0 then
        begin
          raise EConvertError.Create('Unexpected identifier ' + LKey + ' for ' + AName);
        end;
        LFound.Add(LKey);
      end;
      if not LFromCache then
      begin
        SaveBytes(LPath, LBody);
      end;
      for I := 0 to LResults.Count - 1 do
      begin
        LRow := LResults.Items[I];
        LId := JsonText(LRow, 'id');
        LKey := JsonText(LRow, 'source') + ':' + LId;
        LRecord := LExpected.Objects[LExpected.IndexOf(LKey)] as TProviderRecord;
        LRecord.Row := BibliographyRow(FQuery[0], FQuery[1], FQuery[2], LRow,
          LRecord.Source, LRecord.Id, LRecord.Rank);
        LRecord.Origin := 'provider-recovery';
        LRecord.HasAbstract := JsonText(LRow, 'abstractText') <> '';
        LRecord.MissingReason := '';
      end;
    finally
      LDocument.Free;
    end;
    for LRecord in ARecords do
    begin
      if LRecord.Row <> '' then
      begin
        Continue;
      end;
      LRecord.MissingReason := 'absent from exact-ID response';
      if AIndividualFallback then
      begin
        ProcessBatch(AName + '-rank-' + IntToStr(LRecord.Rank), [LRecord], 'EXT_ID', False);
        if (LRecord.Row = '') and (LRecord.Source = 'PMC') then
        begin
          ProcessBatch(AName + '-pmcid-' + IntToStr(LRecord.Rank), [LRecord], 'PMCID', False);
        end;
      end;
    end;
    WriteLn(AName, ' ', LFound.Count, '/', Length(ARecords), ' exact identifiers');
  finally
    LFound.Free;
    LExpected.Free;
  end;
end;

procedure TRecovery.Recover;
var
  LPlan: TStringList;
  LPrior: TStringList;
  LBatches: array of TProviderRecords;
  LBatch: TProviderRecords;
  LItem: TProviderRecord;
  LBatchName: UTF8String;
  LPlanPath: String;
  I: Integer;
begin
  LPlan := TStringList.Create;
  LPrior := TStringList.Create;
  try
    LPlan.Add('query_id' + Tab + 'batch' + Tab + 'rank' + Tab + 'provider_key');
    LBatches := nil;
    LBatch := nil;
    for I := 0 to FIds.Count - 1 do
    begin
      LItem := FIds.Objects[I] as TProviderRecord;
      if LItem.Row <> '' then
      begin
        Continue;
      end;
      if (Length(LBatch) = 0) or (Length(LBatch) >= BatchSize) or
        (LBatch[0].Source <> LItem.Source) then
      begin
        SetLength(LBatches, Length(LBatches) + 1);
        LBatch := nil;
      end;
      SetLength(LBatch, Length(LBatch) + 1);
      LBatch[High(LBatch)] := LItem;
      LBatches[High(LBatches)] := LBatch;
      LBatchName := Format('batch-%.5d', [Length(LBatches)]);
      LPlan.Add(FQuery[0] + Tab + LBatchName + Tab + IntToStr(LItem.Rank) + Tab + LItem.Key);
    end;
    LPlanPath := FOutput + 'batch-ids.tsv';
    if FileExists(LPlanPath) then
    begin
      LPrior.LoadFromFile(LPlanPath);
      if LPlan.Text <> LPrior.Text then
      begin
        raise EConvertError.Create('Recovery directory belongs to a different batch plan');
      end;
    end
    else
    begin
      SaveBytes(LPlanPath, LPlan.Text);
    end;
    WriteLn('Planned ', LPlan.Count - 1, ' missing IDs in ', Length(LBatches), ' batches');
    for I := 0 to High(LBatches) do
    begin
      ProcessBatch(Format('batch-%.5d', [I + 1]), LBatches[I], 'EXT_ID', True);
    end;
  finally
    LPrior.Free;
    LPlan.Free;
  end;
end;

procedure TRecovery.SaveOutputs;
var
  LMerged, LRecovered, LInventory, LSummary: Text;
  LItem: TProviderRecord;
  LOtherCore, LProvider, LMissing, LAbstracts: Integer;
begin
  LOtherCore := 0;
  LProvider := 0;
  LMissing := 0;
  LAbstracts := 0;
  OpenTsv(LMerged, FOutput + 'merged_metadata.tsv');
  OpenTsv(LRecovered, FOutput + 'recovered_metadata.tsv');
  OpenTsv(LInventory, FOutput + 'inventory.tsv');
  try
    Write(LMerged, BibliographyHeader, #10);
    Write(LRecovered, BibliographyHeader, #10);
    WriteRow(LInventory, ['idlist_rank', 'provider_key', 'origin', 'origin_query',
      'batch', 'has_abstract', 'missing_reason']);
    for LItem in FRanked do
    begin
      if LItem.Origin = 'cross-query-core' then
      begin
        Inc(LOtherCore);
      end;
      if LItem.Origin = 'provider-recovery' then
      begin
        Inc(LProvider);
        Write(LRecovered, LItem.Row, #10);
      end;
      if LItem.Row = '' then
      begin
        Inc(LMissing);
        if LItem.MissingReason = '' then
        begin
          LItem.MissingReason := 'pending';
        end;
      end
      else
      begin
        Write(LMerged, LItem.Row, #10);
      end;
      if LItem.HasAbstract then
      begin
        Inc(LAbstracts);
      end;
      WriteRow(LInventory, [IntToStr(LItem.Rank), LItem.Key, LItem.Origin,
        LItem.OriginQuery, LItem.Batch, IntToStr(Ord(LItem.HasAbstract)), LItem.MissingReason]);
    end;
  finally
    Close(LInventory);
    Close(LRecovered);
    Close(LMerged);
  end;
  OpenTsv(LSummary, FOutput + 'summary.tsv');
  try
    WriteRow(LSummary, ['query_id', 'provider_ids', 'same_query_core_rows',
      'same_query_core_overlap', 'cross_query_core_reused', 'provider_recovered',
      'unresolved', 'abstracts_present', 'requests_this_run']);
    WriteRow(LSummary, [FQuery[0], IntToStr(FIds.Count), IntToStr(FSameQueryRows),
      IntToStr(FSameQueryOverlap), IntToStr(LOtherCore), IntToStr(LProvider), IntToStr(LMissing),
      IntToStr(LAbstracts), IntToStr(FRequestsThisRun)]);
  finally
    Close(LSummary);
  end;
  WriteLn('Resolved ', FIds.Count - LMissing, '/', FIds.Count, ' with ', LAbstracts, ' abstracts');
  if LMissing > 0 then
  begin
    ExitCode := 2;
  end;
end;

procedure TRecovery.Run(const AIdsDir, ACoreDir, AQueryId, AOutput: String);
var
  LLock: TFileStream;
  LReplayQuery: TStringList;
  LHasLog: Boolean;
begin
  FOutput := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
  if SameText(FOutput, IncludeTrailingPathDelimiter(ExpandFileName(AIdsDir))) or
    SameText(FOutput, IncludeTrailingPathDelimiter(ExpandFileName(ACoreDir))) then
  begin
    raise EArgumentException.Create('Choose an output directory separate from both snapshots');
  end;
  if not ForceDirectories(FOutput) then
  begin
    raise EInOutError.Create('Cannot create recovery directory');
  end;
  LLock := TFileStream.Create(FOutput + 'recovery.lock', fmCreate or fmShareExclusive);
  LReplayQuery := TStringList.Create;
  try
    LoadIds(IncludeTrailingPathDelimiter(AIdsDir));
    LoadCore(IncludeTrailingPathDelimiter(ACoreDir), AQueryId);
    LReplayQuery.LoadFromFile(IncludeTrailingPathDelimiter(AIdsDir) + 'query.txt');
    if (LReplayQuery.Count <> 2) or (LReplayQuery[1] <> FQuery[4]) then
    begin
      raise EConvertError.Create('Identifier and bibliography snapshots use different queries');
    end;
    LHasLog := FileExists(FOutput + 'requests.tsv');
    OpenTsv(FRequests, FOutput + 'requests.tsv', LHasLog);
    try
      if not LHasLog then
      begin
        WriteRow(FRequests, ['retrieved_utc', 'batch', 'attempt', 'requested_ids',
          'http_status', 'response_bytes', 'query', 'transport_error']);
        Flush(FRequests);
      end;
      try
        Recover;
      finally
        SaveOutputs;
      end;
    finally
      Close(FRequests);
    end;
  finally
    LReplayQuery.Free;
    LLock.Free;
  end;
end;

var
  LRun: TRecovery;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  if ParamCount <> 4 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.idrecovery ID_REPLAY_DIR CORE_DIR QUERY_ID OUTPUT_DIR');
    Halt(2);
  end;
  LRun := TRecovery.Create;
  try
    try
      LRun.Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
    except
      on LException: Exception do
      begin
        WriteLn(StdErr, LException.Message);
        ExitCode := 1;
      end;
    end;
  finally
    LRun.Free;
  end;
end.
