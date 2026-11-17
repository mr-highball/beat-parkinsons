{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentIdOverlay;

{$mode delphi}
{$H+}

uses Classes, SysUtils, StrUtils, foodexperiment.bibliography, foodexperiment.externaldata;

const
  Tab = #9;
  QueryHeader = 'query_id'#9'category'#9'ingredient'#9'searched_utc'#9'query'#9'status'#9 +
    'hit_count'#9'retrieved_count'#9'pages'#9'error';

function DirectoryPath(const APath: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(APath));
end;

procedure OpenInput(var AFile: Text; const APath: String);
begin
  Assign(AFile, APath);
  SetTextCodePage(AFile, CP_UTF8);
  Reset(AFile);
end;

procedure OpenOutput(var AFile: Text; const APath: String);
begin
  Assign(AFile, APath);
  SetTextCodePage(AFile, CP_UTF8);
  Rewrite(AFile);
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
    Write(AFile, AFields[I]);
  end;
  Write(AFile, #10);
end;

function CountPages(const ADirectory: String): Integer;
begin
  Result := 0;
  while FileExists(ADirectory + Format('page-%.5d.txt', [Result + 1])) do
  begin
    Inc(Result);
  end;
end;

procedure Overlay(const AIds, ACore, ARecovery, AQueryId, AOutput: String);
var
  LIds, LRows, LSeen, LAudit, LWork, LBatches: TStringList;
  LSummary, LPrior, LFields: TFields;
  LLock: TFileStream;
  LInput, LOutput: Text;
  LLine, LKey, LOriginalError: UTF8String;
  LOverlayFound: Boolean;
  LOldRows, LOtherRows, LRequestAttempts, LHttpSuccess, LPageCount, I, J: Integer;
  LResultPath, LAuditPath, LProvenancePath: String;
begin
  if SameText(AOutput, AIds) or SameText(AOutput, ACore) or SameText(AOutput, ARecovery) then
  begin
    raise EArgumentException.Create('Choose a directory separate from every input snapshot');
  end;
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create overlay directory');
  end;
  LLock := TFileStream.Create(AOutput + 'overlay.lock', fmCreate or fmShareExclusive);
  LIds := TStringList.Create;
  LRows := TStringList.Create;
  LSeen := TStringList.Create;
  LAudit := TStringList.Create;
  LWork := TStringList.Create;
  LBatches := TStringList.Create;
  try
    LResultPath := AOutput + 'ingredient_results.tsv';
    LAuditPath := AOutput + 'ingredient_queries.tsv';
    LProvenancePath := AOutput + 'overlay-provenance.tsv';
    if FileExists(LResultPath) or FileExists(LAuditPath) or FileExists(LProvenancePath) then
    begin
      raise EInOutError.Create('Overlay output already exists. Choose a new output directory.');
    end;
    LIds.LoadFromFile(AIds + 'source-ids.txt');
    LIds.CaseSensitive := True;
    LIds.Sorted := True;
    LPageCount := CountPages(AIds);
    LWork.LoadFromFile(ARecovery + 'summary.tsv');
    if LWork.Count <> 2 then
    begin
      raise EConvertError.Create('Unexpected recovery summary');
    end;
    LSummary := SplitFields(LWork[1], Tab);
    if (Length(LSummary) <> 9) or (LSummary[0] <> AQueryId) or (LSummary[6] <> '0') or
      (StrToInt(LSummary[1]) <> LIds.Count) then
    begin
      raise EConvertError.Create('Recovery summary does not cover the identifier snapshot');
    end;
    LRows.LoadFromFile(ARecovery + 'merged_metadata.tsv');
    if (LRows.Count <> LIds.Count + 1) or (LRows[0] <> BibliographyHeader) then
    begin
      raise EConvertError.Create('Merged metadata count or header is invalid');
    end;
    LSeen.CaseSensitive := True;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], Tab);
      if (Length(LFields) <> 15) or (LFields[0] <> AQueryId) or (StrToInt(LFields[3]) <> I) then
      begin
        raise EConvertError.CreateFmt('Invalid merged metadata row %d', [I + 1]);
      end;
      LKey := LFields[5] + ':' + LFields[6];
      if LIds.IndexOf(LKey) < 0 then
      begin
        raise EConvertError.Create('Unexpected provider key in merged metadata: ' + LKey);
      end;
      LSeen.Add(LKey);
    end;
    LBatches.Sorted := True;
    LBatches.Duplicates := dupIgnore;
    LWork.LoadFromFile(ARecovery + 'batch-ids.tsv');
    if (LWork.Count <> StrToInt(LSummary[5]) + 1) then
    begin
      raise EConvertError.Create('Recovery plan differs from the recovered row count');
    end;
    for I := 1 to LWork.Count - 1 do
    begin
      LFields := SplitFields(LWork[I], Tab);
      if (Length(LFields) <> 4) or (LFields[0] <> AQueryId) then
      begin
        raise EConvertError.Create('Invalid exact lookup batch plan');
      end;
      LBatches.Add(LFields[1]);
    end;
    LWork.LoadFromFile(ARecovery + 'requests.tsv');
    LRequestAttempts := LWork.Count - 1;
    LHttpSuccess := 0;
    for I := 1 to LWork.Count - 1 do
    begin
      LFields := SplitFields(LWork[I], Tab);
      if Length(LFields) <> 8 then
      begin
        raise EConvertError.Create('Invalid exact lookup request log');
      end;
      Inc(LHttpSuccess, Ord(LFields[4] = '200'));
    end;
    LAudit.LoadFromFile(ACore + 'ingredient_queries.tsv');
    if (LAudit.Count = 0) or (LAudit[0] <> QueryHeader) then
    begin
      raise EConvertError.Create('Invalid original query audit');
    end;
    LOverlayFound := False;
    for I := 1 to LAudit.Count - 1 do
    begin
      LFields := SplitFields(LAudit[I], Tab);
      if (Length(LFields) <> 10) then
      begin
        raise EConvertError.Create('Invalid original query audit row');
      end;
      if LFields[0] <> AQueryId then
      begin
        Continue;
      end;
      if LOverlayFound or (LFields[6] <> LSummary[1]) or (LFields[7] <> LSummary[2]) then
      begin
        raise EConvertError.Create('Original query audit disagrees with recovery');
      end;
      LPrior := Copy(LFields);
      LOriginalError := LFields[9];
      LFields[5] := 'Retrieved';
      LFields[7] := LSummary[1];
      LFields[9] := '';
      LAudit[I] := LFields[0];
      for J := 1 to High(LFields) do
      begin
        LAudit[I] := LAudit[I] + Tab + LFields[J];
      end;
      LOverlayFound := True;
    end;
    if not LOverlayFound then
    begin
      raise EConvertError.Create('Query missing from original audit');
    end;
    LOldRows := 0;
    LOtherRows := 0;
    OpenInput(LInput, ACore + 'ingredient_results.tsv');
    try
      ReadLn(LInput, LLine);
      if LLine <> BibliographyHeader then
      begin
        raise EConvertError.Create('Invalid original bibliography header');
      end;
      OpenOutput(LOutput, LResultPath + '.tmp');
      try
        Write(LOutput, LLine, #10);
        while not Eof(LInput) do
        begin
          ReadLn(LInput, LLine);
          if not StartsStr(AQueryId + Tab, LLine) then
          begin
            Write(LOutput, LLine, #10);
            Inc(LOtherRows);
            Continue;
          end;
          if LOldRows = 0 then
          begin
            for I := 1 to LRows.Count - 1 do
            begin
              Write(LOutput, LRows[I], #10);
            end;
          end;
          Inc(LOldRows);
        end;
      finally
        Close(LOutput);
      end;
    finally
      Close(LInput);
    end;
    if LOldRows <> StrToInt(LPrior[7]) then
    begin
      raise EConvertError.Create('Original bibliography changed while writing overlay');
    end;
    OpenOutput(LOutput, LAuditPath + '.tmp');
    try
      for LLine in LAudit do
      begin
        Write(LOutput, LLine, #10);
      end;
    finally
      Close(LOutput);
    end;
    if not RenameFile(LResultPath + '.tmp', LResultPath) or
      not RenameFile(LAuditPath + '.tmp', LAuditPath) then
    begin
      raise EInOutError.Create('Cannot publish overlay outputs');
    end;
    OpenOutput(LOutput, LProvenancePath);
    try
      WriteRow(LOutput, ['query_id', 'original_status', 'final_status', 'original_core_pages',
        'idlist_pages', 'exact_lookup_batches', 'exact_lookup_request_attempts', 'exact_lookup_http_200',
        'provider_ids', 'original_core_rows', 'cross_query_rows', 'exact_lookup_rows',
        'unchanged_other_query_rows', 'original_core_error']);
      WriteRow(LOutput, [AQueryId, LPrior[5], 'Retrieved', LPrior[8], IntToStr(LPageCount),
        IntToStr(LBatches.Count), IntToStr(LRequestAttempts), IntToStr(LHttpSuccess),
        LSummary[1], LSummary[3], LSummary[4], LSummary[5], IntToStr(LOtherRows), LOriginalError]);
    finally
      Close(LOutput);
    end;
    WriteLn('Overlay published with ', LIds.Count, ' provider IDs and ', LOtherRows,
      ' original rows from other queries');
  finally
    LBatches.Free;
    LWork.Free;
    LAudit.Free;
    LSeen.Free;
    LRows.Free;
    LIds.Free;
    LLock.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  if ParamCount <> 5 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.idoverlay ID_REPLAY_DIR CORE_DIR RECOVERY_DIR QUERY_ID OUTPUT_DIR');
    Halt(2);
  end;
  Overlay(DirectoryPath(ParamStr(1)), DirectoryPath(ParamStr(2)), DirectoryPath(ParamStr(3)),
    ParamStr(4), DirectoryPath(ParamStr(5)));
end.
