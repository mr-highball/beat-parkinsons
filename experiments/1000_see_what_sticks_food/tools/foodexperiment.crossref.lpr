{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentCrossref;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, fpjson, jsonparser, RegExpr, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

const
  Tab = #9;
  ContextHeader = 'work_id'#9'language'#9'indexed_abstract'#9'coverage'#9'stage';
  OpenAlexHeader = 'query_id'#9'page'#9'work_id'#9'doi'#9'pmid'#9'title'#9'publication_date'#9 +
    'language'#9'type'#9'landing_page'#9'has_abstract';
  MetadataHeader = 'work_id'#9'language'#9'doi'#9'pmid'#9'lookup_status'#9 +
    'deposited_abstract'#9'reference_rows'#9'published_online'#9'published_print'#9'issued';
  ReferencesHeader = 'work_id'#9'row'#9'doi'#9'article_title'#9'journal_title'#9'year'#9 +
    'author'#9'volume'#9'first_page'#9'unstructured';
  IndexHeader = 'work_id'#9'language'#9'title'#9'indexed_abstract';
  ReferenceIndexHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'indexed_abstract';
  TopicsHeader = 'docid'#9'presentation_id'#9'topics';
  TopicReviewHeader = 'docid'#9'disposition'#9'assessment'#9'source'#9'local_reference';
  RequestSpacingMs = 1100;

function OpenAlexId(const AId: UTF8String): Boolean;
begin
  Result := ExecRegExpr('^https://openalex\.org/W[0-9]+$', AId);
end;

procedure LoadBibliography(const APath: String; ARecords: TStringList);
var
  LRows: TStringList;
  LFields: TFields;
  LRow: Integer;
  LIndex: Integer;
  LEntry: UTF8String;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count < 2) or (LRows[0] <> OpenAlexHeader) then
    begin
      raise EConvertError.Create('Missing OpenAlex result inventory or unexpected header');
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 11) or not OpenAlexId(LFields[2]) then
      begin
        raise EConvertError.CreateFmt('Invalid OpenAlex result row %d', [LRow + 1]);
      end;
      LEntry := LowerCase(LFields[3]) + Tab + LFields[4] + Tab + LFields[5];
      LIndex := ARecords.IndexOfName(LFields[2]);
      if LIndex < 0 then
      begin
        ARecords.Add(LFields[2] + Tab + LEntry);
      end
      else if ARecords.ValueFromIndex[LIndex] <> LEntry then
      begin
        raise EConvertError.Create('Conflicting OpenAlex bibliographic metadata: ' + LFields[2]);
      end;
    end;
  finally
    LRows.Free;
  end;
end;

function JsonText(AData: TJSONData; const AName: String): UTF8String;
var
  LValue: TJSONData;
begin
  Result := '';
  LValue := AData.FindPath(AName);
  if Assigned(LValue) and (LValue.JSONType in [jtString, jtNumber]) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

function DateParts(AData: TJSONData; const AName: String): UTF8String;
var
  LDate: TJSONData;
  LParts: TJSONData;
  LIndex: Integer;
begin
  Result := '';
  LDate := AData.FindPath(AName + '.date-parts');
  if not Assigned(LDate) or (LDate.JSONType <> jtArray) or (LDate.Count = 0) then
  begin
    Exit;
  end;
  LParts := LDate.Items[0];
  if (LParts.JSONType <> jtArray) or (LParts.Count > 3) then
  begin
    raise EConvertError.Create('Invalid Crossref date parts: ' + AName);
  end;
  for LIndex := 0 to LParts.Count - 1 do
  begin
    if LIndex = 0 then
    begin
      Result := Format('%.4d', [LParts.Items[LIndex].AsInteger]);
    end
    else
    begin
      Result := Result + Format('-%.2d', [LParts.Items[LIndex].AsInteger]);
    end;
  end;
end;

function WriteReferences(AWork: TJSONData; const AId, ALanguage: UTF8String;
  var AOutput, AIndex: Text): Integer;
var
  LReferences: TJSONData;
  LReference: TJSONData;
  LIndex: Integer;
  LId: UTF8String;
  LDoi: UTF8String;
  LTitle: UTF8String;
  LJournal: UTF8String;
  LUnstructured: UTF8String;
begin
  Result := 0;
  LReferences := AWork.FindPath('reference');
  if not Assigned(LReferences) then
  begin
    Exit;
  end;
  if LReferences.JSONType <> jtArray then
  begin
    raise EConvertError.Create('Invalid Crossref reference array: ' + AId);
  end;
  for LIndex := 0 to LReferences.Count - 1 do
  begin
    LReference := LReferences.Items[LIndex];
    LId := AId + '#' + IntToStr(LIndex + 1);
    LDoi := LowerCase(JsonText(LReference, 'DOI'));
    LTitle := JsonText(LReference, 'article-title');
    LJournal := JsonText(LReference, 'journal-title');
    LUnstructured := JsonText(LReference, 'unstructured');
    WriteLn(AOutput, AId, Tab, LIndex + 1, Tab, LDoi, Tab, LTitle, Tab, LJournal, Tab,
      JsonText(LReference, 'year'), Tab, JsonText(LReference, 'author'), Tab,
      JsonText(LReference, 'volume'), Tab, JsonText(LReference, 'first-page'), Tab, LUnstructured);
    if LTitle = '' then
    begin
      LTitle := Trim(LUnstructured + ' ' + LJournal);
    end;
    if LTitle = '' then
    begin
      LTitle := LId;
    end;
    { The language tag is inherited from the citing work. }
    WriteLn(AIndex, LId, Tab, LId, Tab, ALanguage, Tab, LTitle, Tab);
  end;
  Result := LReferences.Count;
end;

procedure CacheResponse(const AFile: String; const ABody: RawByteString);
var
  LOutput: TFileStream;
begin
  LOutput := TFileStream.Create(AFile, fmCreate);
  try
    if ABody <> '' then
    begin
      LOutput.WriteBuffer(ABody[1], Length(ABody));
    end;
  finally
    LOutput.Free;
  end;
end;

function ExactWork(const ABody, AExpectedDoi: UTF8String): TJSONData;
var
  LMessage: TJSONData;
begin
  Result := GetJSON(ABody);
  LMessage := Result.FindPath('message');
  if not Assigned(LMessage) or (LMessage.JSONType <> jtObject) or
    (LowerCase(JsonText(LMessage, 'DOI')) <> AExpectedDoi) then
  begin
    Result.Free;
    raise EConvertError.Create('Crossref DOI mismatch: ' + AExpectedDoi);
  end;
end;

function Fetch(AClient: TEuropePmc; const ADoi, AFile: UTF8String;
  var AStatus: UTF8String; var ADeferred: Boolean): TJSONData;
var
  LResponse: TSearchResponse;
begin
  Result := nil;
  if FileExists(AFile) then
  begin
    AStatus := 'exact';
    Exit(ExactWork(ReadBytes(AFile), ADoi));
  end;
  if ADeferred then
  begin
    AStatus := 'deferred';
    Exit;
  end;
  Sleep(RequestSpacingMs);
  try
    LResponse := AClient.GetPath('/works/' + UrlEncode(ADoi));
  except
    on LException: EOSError do
    begin
      AStatus := 'transport error';
      ADeferred := True;
      Exit;
    end;
  end;
  AStatus := 'HTTP ' + IntToStr(LResponse.Status);
  if LResponse.Status <> 200 then
  begin
    ADeferred := (LResponse.Status = 429) or (LResponse.Status >= 500);
    Exit;
  end;
  Result := ExactWork(LResponse.Body, ADoi);
  CacheResponse(AFile, LResponse.Body);
  AStatus := 'exact';
end;

procedure WriteIndexRow(AClient: TEuropePmc; const AContext, ABibliography: TFields;
  const ACacheDir: String; var AMetadata, AIndex, AReferences, AReferenceIndex: Text;
  var ADeferred: Boolean);
const
  CDoiPrefix = 'https://doi.org/';
  CPubMedPrefix = 'https://pubmed.ncbi.nlm.nih.gov/';
  CWorkPrefix = 'https://openalex.org/';
var
  LData: TJSONData;
  LWork: TJSONData;
  LDoi: UTF8String;
  LPmid: UTF8String;
  LStatus: UTF8String;
  LAbstract: UTF8String;
begin
  LDoi := ABibliography[0];
  if Copy(LDoi, 1, Length(CDoiPrefix)) = CDoiPrefix then
  begin
    Delete(LDoi, 1, Length(CDoiPrefix));
  end;
  LPmid := ABibliography[1];
  if Copy(LPmid, 1, Length(CPubMedPrefix)) = CPubMedPrefix then
  begin
    Delete(LPmid, 1, Length(CPubMedPrefix));
  end;
  LStatus := 'no DOI';
  LData := nil;
  if LDoi <> '' then
  begin
    if Copy(LDoi, 1, 3) <> '10.' then
    begin
      raise EConvertError.Create('Invalid normalized DOI: ' + LDoi);
    end;
    LData := Fetch(AClient, LDoi, ACacheDir + Copy(AContext[0], Length(CWorkPrefix) + 1) +
      '.json', LStatus, ADeferred);
  end;
  LAbstract := '';
  try
    Write(AMetadata, AContext[0], Tab, AContext[1], Tab, LDoi, Tab, LPmid, Tab, LStatus, Tab);
    if Assigned(LData) then
    begin
      LWork := LData.FindPath('message');
      LAbstract := ReplaceRegExpr('<[^>]+>', JsonText(LWork, 'abstract'), ' ', False);
      WriteLn(AMetadata, BoolToStr(Trim(LAbstract) <> '', True), Tab,
        WriteReferences(LWork, AContext[0], AContext[1], AReferences, AReferenceIndex),
        Tab, DateParts(LWork, 'published-online'),
        Tab, DateParts(LWork, 'published-print'), Tab, DateParts(LWork, 'issued'));
    end
    else
    begin
      WriteLn(AMetadata, Tab, Tab, Tab, Tab);
    end;
    WriteLn(AIndex, AContext[0], Tab, AContext[1], Tab, ABibliography[2], Tab, Trim(LAbstract));
  finally
    LData.Free;
  end;
end;

procedure OpenOutput(var AFile: Text; const APath, AHeader: String);
begin
  AssignFile(AFile, APath);
  Rewrite(AFile);
  SetTextCodePage(AFile, CP_UTF8);
  WriteLn(AFile, AHeader);
end;

procedure Run(const AContext, AResults, ADirectory: String);
var
  LContext: TStringList;
  LRecords: TStringList;
  LSeen: TStringList;
  LClient: TEuropePmc;
  LFields: TFields;
  LIndex: Integer;
  LRow: Integer;
  LCount: Integer;
  LDeferred: Boolean;
  LDirectory: String;
  LCache: String;
  LMetadata: Text;
  LReferences: Text;
  LIndexFile: Text;
  LReferenceIndex: Text;
begin
  LDirectory := IncludeTrailingPathDelimiter(ADirectory);
  LCache := LDirectory + 'responses' + PathDelim;
  if not ForceDirectories(LCache) then
  begin
    raise EInOutError.Create('Could not create capture directory');
  end;
  LContext := TStringList.Create;
  LRecords := TStringList.Create;
  LSeen := TStringList.Create;
  LClient := TEuropePmc.Create('api.crossref.org');
  try
    LRecords.NameValueSeparator := Tab;
    LRecords.CaseSensitive := True;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LSeen.CaseSensitive := True;
    LoadBibliography(AResults, LRecords);
    LContext.Text := ReadBytes(AContext);
    if (LContext.Count < 2) or (LContext[0] <> ContextHeader) then
    begin
      raise EConvertError.Create('Missing regional context coverage or unexpected header');
    end;
    OpenOutput(LMetadata, LDirectory + 'metadata.tsv', MetadataHeader);
    OpenOutput(LIndexFile, LDirectory + 'abstracts.tsv', IndexHeader);
    OpenOutput(LReferences, LDirectory + 'references.tsv', ReferencesHeader);
    OpenOutput(LReferenceIndex, LDirectory + 'reference-index.tsv', ReferenceIndexHeader);
    try
      LCount := 0;
      LDeferred := False;
      for LRow := 1 to LContext.Count - 1 do
      begin
        LFields := SplitFields(LContext[LRow], Tab);
        if (Length(LFields) <> 5) or not OpenAlexId(LFields[0]) or
          ((LFields[2] <> 'missing') and (LFields[2] <> 'present')) then
        begin
          raise EConvertError.CreateFmt('Invalid regional coverage row %d', [LRow + 1]);
        end;
        LSeen.Add(LFields[0]);
        LIndex := LRecords.IndexOfName(LFields[0]);
        if LIndex < 0 then
        begin
          raise EConvertError.Create('Missing OpenAlex bibliography: ' + LFields[0]);
        end;
        if LFields[2] = 'missing' then
        begin
          Inc(LCount);
          WriteIndexRow(LClient, LFields, SplitFields(LRecords.ValueFromIndex[LIndex], Tab),
            LCache, LMetadata, LIndexFile, LReferences, LReferenceIndex, LDeferred);
        end;
      end;
      WriteLn(LCount, ' regional works without OpenAlex abstracts accounted for');
      if LDeferred then
      begin
        ExitCode := 2;
      end;
    finally
      CloseFile(LReferenceIndex);
      CloseFile(LReferences);
      CloseFile(LIndexFile);
      CloseFile(LMetadata);
    end;
  finally
    LClient.Free;
    LSeen.Free;
    LRecords.Free;
    LContext.Free;
  end;
end;

procedure LoadTopicReviews(const APath: String; ATopics: TStringList);
var
  LRows: TStringList;
  LFields: TFields;
  LRow: Integer;
  LIndex: Integer;
  LReference: String;
  LAnchor: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count = 0) or (LRows[0] <> TopicReviewHeader) then
    begin
      raise EConvertError.Create('Unexpected topic review header in ' + APath);
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 5) or (Trim(LFields[1]) = '') or (Trim(LFields[2]) = '') then
      begin
        raise EConvertError.CreateFmt('Invalid topic review row %d in %s', [LRow + 1, APath]);
      end;
      LIndex := ATopics.IndexOfName(LFields[0]);
      if (LIndex < 0) or (ATopics.ValueFromIndex[LIndex] <> '') then
      begin
        raise EConvertError.Create('Duplicate or unflagged topic review: ' + LFields[0]);
      end;
      LReference := LFields[4];
      LAnchor := Pos('#', LReference);
      if LAnchor > 0 then
      begin
        SetLength(LReference, LAnchor - 1);
      end;
      if (LFields[4] <> '') and not FileExists(LReference) then
      begin
        raise EConvertError.Create('Missing local topic reference: ' + LReference);
      end;
      ATopics.ValueFromIndex[LIndex] := LRows[LRow];
    end;
  finally
    LRows.Free;
  end;
end;

procedure AuditTopics;
var
  LTopics: TStringList;
  LRows: TStringList;
  LOutput: Text;
  LFields: TFields;
  LRow: Integer;
  LInput: Integer;
  LPending: Integer;
begin
  LTopics := TStringList.Create;
  LRows := TStringList.Create;
  try
    LTopics.NameValueSeparator := Tab;
    LTopics.CaseSensitive := True;
    LRows.Text := ReadBytes(ParamStr(2));
    if (LRows.Count < 2) or (LRows[0] <> TopicsHeader) then
    begin
      raise EConvertError.Create('Missing topic index or unexpected header');
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 3) or (LFields[0] = '') or (LFields[0] <> LFields[1]) then
      begin
        raise EConvertError.CreateFmt('Invalid citation topic row %d', [LRow + 1]);
      end;
      if LFields[2] <> '' then
      begin
        if LTopics.IndexOfName(LFields[0]) >= 0 then
        begin
          raise EConvertError.Create('Duplicate citation topic: ' + LFields[0]);
        end;
        LTopics.Add(LFields[0] + Tab);
      end;
    end;
    for LInput := 4 to ParamCount do
    begin
      LoadTopicReviews(ParamStr(LInput), LTopics);
    end;
    LPending := 0;
    for LRow := 0 to LTopics.Count - 1 do
    begin
      if LTopics.ValueFromIndex[LRow] = '' then
      begin
        Inc(LPending);
        WriteLn(StdErr, 'Pending: ', LTopics.Names[LRow]);
      end;
    end;
    WriteLn(LTopics.Count - LPending, ' reviewed, ', LPending, ' pending of ',
      LTopics.Count, ' flagged citation appearances');
    if LPending > 0 then
    begin
      ExitCode := 2;
      Exit;
    end;
    OpenOutput(LOutput, ParamStr(3), TopicReviewHeader);
    try
      for LRow := 0 to LTopics.Count - 1 do
      begin
        WriteLn(LOutput, LTopics.ValueFromIndex[LRow]);
      end;
    finally
      CloseFile(LOutput);
    end;
  finally
    LRows.Free;
    LTopics.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount >= 4) and (ParamStr(1) = 'audit-topics') then
    begin
      AuditTopics;
    end
    else if ParamCount = 3 then
    begin
      Run(ParamStr(1), ParamStr(2), ParamStr(3));
    end
    else
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.crossref CONTEXT_COVERAGE OPENALEX_RESULTS CAPTURE_DIRECTORY' +
        LineEnding + '       foodexperiment.crossref audit-topics TOPICS OUTPUT REVIEWS [...]');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
