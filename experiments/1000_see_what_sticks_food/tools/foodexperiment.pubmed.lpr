{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPubMed;

{$mode delphi}
{$H+}

uses
  Windows, Classes, SysUtils, StrUtils, Math, fpjson, jsonparser,
  foodexperiment.externaldata, foodexperiment.https, foodexperiment.pubmedquery;

const
  Tab = #9;
  Host = 'eutils.ncbi.nlm.nih.gov';
  ApiPath = '/entrez/eutils/';
  ToolParameter = '&tool=beat_parkinsons_food_experiment';
  SearchLimit = 9999;
  SummaryBatchSize = 120;
  RequestSpacingMs = 400;
  MaximumAttempts = 4;
  FirstEdYear = 1800;
  LastEdYear = 2100;

type
  TSearchAudit = record
    Hits: Int64;
    Requests: Integer;
    Translation: UTF8String;
    Warnings: UTF8String;
  end;

  TPubMedRun = class
  private
    FClient: TEuropePmc;
    FNextRequest: QWord;
    FContactParameter: UTF8String;
    FKnown: TStringList;
    FAllIds: TStringList;
    FMesh: TStringList;
    FQueries: TFileStream;
    FPartitions: TFileStream;
    FIds: TFileStream;
    FRecords: TFileStream;
    FSummaryBatches: TFileStream;
    FIncomplete: Integer;
    function Fetch(const APath: UTF8String): UTF8String;
    procedure LoadKnown(const APath: String);
    procedure LoadMesh(const APath: String);
    function SearchSet(const AQuery, AQueryId, AScope: UTF8String; AIds, ASeen: TStringList;
      var AAudit: TSearchAudit): Int64;
    function SearchRange(const AQuery, AQueryId: UTF8String; AFirst, ALast: Integer;
      AIds, ASeen: TStringList; var AAudit: TSearchAudit): Int64;
    procedure SearchIngredient(const AQueryId, ACategory, AIngredient, AQuery: UTF8String);
    procedure Summarize;
  public
    constructor Create(const AKnownPath, AMeshPath, AOutputDir: String);
    destructor Destroy; override;
    procedure Run(const AQueriesPath, ASelection: String);
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

function MakeSet: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := False;
  Result.Duplicates := dupIgnore;
end;

function IsPmid(const AValue: UTF8String): Boolean;
var
  LChar: Char;
begin
  if AValue = '' then
  begin
    Exit(False);
  end;
  for LChar in AValue do
  begin
    if not (LChar in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

function DateRange(AFirst, ALast: Integer): UTF8String;
begin
  Result := Format('("%.4d/01/01"[edat] : "%.4d/12/31"[edat])', [AFirst, ALast]);
end;

constructor TPubMedRun.Create(const AKnownPath, AMeshPath, AOutputDir: String);
var
  LOutput: String;
  LEmail: UTF8String;
begin
  inherited Create;
  FKnown := MakeSet;
  FAllIds := MakeSet;
  FMesh := TStringList.Create;
  LoadKnown(AKnownPath);
  LoadMesh(AMeshPath);
  LOutput := IncludeTrailingPathDelimiter(AOutputDir);
  if not ForceDirectories(LOutput) then
  begin
    raise EInOutError.CreateFmt('Cannot create output directory %s', [LOutput]);
  end;
  FQueries := TFileStream.Create(LOutput + 'pubmed_queries.tsv', fmCreate or fmShareDenyWrite);
  FPartitions := TFileStream.Create(LOutput + 'pubmed_partitions.tsv', fmCreate or fmShareDenyWrite);
  FIds := TFileStream.Create(LOutput + 'pubmed_ids.tsv', fmCreate or fmShareDenyWrite);
  FRecords := TFileStream.Create(LOutput + 'pubmed_records.tsv', fmCreate or fmShareDenyWrite);
  FSummaryBatches := TFileStream.Create(LOutput + 'pubmed_summary_batches.tsv',
    fmCreate or fmShareDenyWrite);
  WriteLine(FQueries, 'query_id'#9'category'#9'ingredient'#9'searched_utc'#9'query'#9 +
    'translation'#9'status'#9'hit_count'#9'retrieved_count'#9'esearch_requests'#9'warnings'#9'error');
  WriteLine(FPartitions, 'query_id'#9'searched_utc'#9'scope'#9'query'#9'hit_count'#9 +
    'retrieved_count'#9'status'#9'warnings'#9'error');
  WriteLine(FIds, 'query_id'#9'category'#9'ingredient'#9'rank'#9'pmid'#9'europe_pmc_pmid_overlap');
  WriteLine(FRecords, 'source_key'#9'pmid'#9'doi'#9'pmcid'#9'title'#9'journal'#9 +
    'publication_date'#9'publication_types'#9'has_abstract'#9'europe_pmc_overlap');
  WriteLine(FSummaryBatches, 'batch_id'#9'searched_utc'#9'pmids'#9'requested'#9'retrieved'#9 +
    'status'#9'error');
  LEmail := Trim(GetEnvironmentVariable('NCBI_EMAIL'));
  if LEmail <> '' then
  begin
    FContactParameter := '&email=' + UrlEncode(LEmail);
  end;
  FClient := TEuropePmc.Create(Host);
end;

destructor TPubMedRun.Destroy;
begin
  FClient.Free;
  FSummaryBatches.Free;
  FRecords.Free;
  FIds.Free;
  FPartitions.Free;
  FQueries.Free;
  FMesh.Free;
  FAllIds.Free;
  FKnown.Free;
  inherited Destroy;
end;

function TPubMedRun.Fetch(const APath: UTF8String): UTF8String;
var
  LNow: QWord;
  LResponse: TSearchResponse;
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
      LResponse := FClient.GetPath(ApiPath + APath + ToolParameter + FContactParameter);
      if LResponse.Status = 200 then
      begin
        Exit(LResponse.Body);
      end;
      LError := 'NCBI HTTP ' + IntToStr(LResponse.Status);
      if LResponse.Status = 429 then
      begin
        FNextRequest := GetTickCount64 + Max(2000, Min(60, LResponse.RetryAfterSeconds) * 1000);
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

procedure TPubMedRun.LoadKnown(const APath: String);
var
  LFile: Text;
  LLine: UTF8String;
  LFields: TFields;
begin
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    if not StartsStr('query_id'#9'category'#9'ingredient'#9'rank'#9'source_key'#9'source'#9 +
      'source_id'#9'pmid'#9'doi'#9'pmcid'#9, LLine) then
    begin
      raise EConvertError.Create('Unexpected Europe PMC result header');
    end;
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, Tab);
      if Length(LFields) <> 15 then
      begin
        raise EConvertError.Create('Invalid Europe PMC result row');
      end;
      if LFields[7] <> '' then FKnown.Add('PMID:' + LFields[7]);
      if LFields[8] <> '' then FKnown.Add('DOI:' + LFields[8]);
      if LFields[9] <> '' then FKnown.Add('PMCID:' + LFields[9]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TPubMedRun.LoadMesh(const APath: String);
var
  LRows: TStringList;
  LFields: TFields;
  I: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(APath, TEncoding.UTF8);
    if (LRows.Count = 0) or (LRows[0] <> 'ingredient_query_id'#9'mesh_headings') then
    begin
      raise EConvertError.Create('Unexpected PubMed MeSH vocabulary header');
    end;
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], Tab);
      if (Length(LFields) <> 2) or (LFields[0] = '') or (LFields[1] = '') or
        (FMesh.IndexOfName(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid PubMed MeSH vocabulary row %d', [I + 1]);
      end;
      FMesh.Values[LFields[0]] := LFields[1];
    end;
  finally
    LRows.Free;
  end;
end;

function TPubMedRun.SearchSet(const AQuery, AQueryId, AScope: UTF8String; AIds, ASeen: TStringList;
  var AAudit: TSearchAudit): Int64;
var
  LJson: TJSONData;
  LIds: TJSONData;
  LWarnings: TJSONData;
  LError: TJSONData;
  LTimestamp: UTF8String;
  LStatus: UTF8String;
  LWarningText: UTF8String;
  LErrorText: UTF8String;
  LPmid: UTF8String;
  LBefore: Integer;
  I: Integer;
begin
  Result := -1;
  LTimestamp := UtcTimestamp;
  LBefore := AIds.Count;
  LStatus := 'Failed';
  LErrorText := '';
  LWarningText := '';
  Inc(AAudit.Requests);
  try
    try
      LJson := GetJSON(Fetch('esearch.fcgi?db=pubmed&retmode=json&retmax=' +
        IntToStr(SearchLimit) + '&term=' + UrlEncode(AQuery)), True);
      try
        LWarnings := LJson.FindPath('esearchresult.warninglist');
        if Assigned(LWarnings) then LWarningText := CleanField(LWarnings.AsJSON);
        LError := LJson.FindPath('esearchresult.errorlist');
        if Assigned(LError) then
        begin
          if LWarningText <> '' then LWarningText := LWarningText + ' ';
          LWarningText := LWarningText + CleanField(LError.AsJSON);
        end;
        if AScope = 'root' then
        begin
          AAudit.Translation := JsonText(LJson, 'esearchresult.querytranslation');
          AAudit.Warnings := LWarningText;
        end;
        if not TryStrToInt64(JsonText(LJson, 'esearchresult.count'), Result) or (Result < 0) then
        begin
          LErrorText := JsonText(LJson, 'esearchresult.ERROR');
          if LErrorText = '' then LErrorText := JsonText(LJson, 'error');
          if LErrorText = '' then LErrorText := JsonText(LJson, 'ERROR');
          if LErrorText <> '' then LErrorText := ' (' + LErrorText + ')';
          raise EConvertError.Create('PubMed response omitted a usable search count' + LErrorText);
        end;
        if AScope = 'root' then
        begin
          AAudit.Hits := Result;
          LErrorText := PubMedTranslationError(AQuery, AAudit.Translation);
          if LErrorText <> '' then
          begin
            raise EConvertError.Create(LErrorText);
          end;
        end;
        if Result > SearchLimit then
        begin
          LStatus := 'PartitionRequired';
          Exit;
        end;
        LIds := LJson.FindPath('esearchresult.idlist');
        if not Assigned(LIds) or (LIds.JSONType <> jtArray) or (LIds.Count <> Result) then
        begin
          raise EConvertError.Create('ESearch PMID count disagrees with reported hits');
        end;
        for I := 0 to LIds.Count - 1 do
        begin
          LPmid := LIds.Items[I].AsString;
          if not IsPmid(LPmid) or (ASeen.IndexOf(LPmid) >= 0) then
          begin
            raise EConvertError.Create('Invalid or repeated PubMed ID ' + LPmid);
          end;
          ASeen.Add(LPmid);
          AIds.Add(LPmid);
        end;
        LStatus := 'Retrieved';
      finally
        LJson.Free;
      end;
    except
      on LException: Exception do
      begin
        LErrorText := CleanField(LException.Message);
        raise;
      end;
    end;
  finally
    WriteLine(FPartitions, AQueryId + Tab + LTimestamp + Tab + AScope + Tab + AQuery + Tab +
      IntToStr(Result) + Tab + IntToStr(AIds.Count - LBefore) + Tab + LStatus + Tab +
      LWarningText + Tab + LErrorText);
  end;
end;

function TPubMedRun.SearchRange(const AQuery, AQueryId: UTF8String; AFirst, ALast: Integer;
  AIds, ASeen: TStringList; var AAudit: TSearchAudit): Int64;
var
  LMid: Integer;
  LFirstCount: Int64;
  LSecondCount: Int64;
begin
  Result := SearchSet('(' + AQuery + ') AND ' + DateRange(AFirst, ALast), AQueryId,
    Format('edat %d-%d', [AFirst, ALast]), AIds, ASeen, AAudit);
  if Result <= SearchLimit then Exit;
  if AFirst = ALast then
  begin
    raise EInOutError.CreateFmt('EDAT year %d exceeds the PubMed ESearch limit. ' +
      'Split by EDAT month or use Entrez Direct', [AFirst]);
  end;
  LMid := (AFirst + ALast) div 2;
  LFirstCount := SearchRange(AQuery, AQueryId, AFirst, LMid, AIds, ASeen, AAudit);
  LSecondCount := SearchRange(AQuery, AQueryId, LMid + 1, ALast, AIds, ASeen, AAudit);
  if LFirstCount + LSecondCount <> Result then
  begin
    raise EConvertError.Create('Child EDAT partitions disagree with their parent count');
  end;
end;

procedure TPubMedRun.SearchIngredient(const AQueryId, ACategory, AIngredient, AQuery: UTF8String);
var
  LIds: TStringList;
  LSeen: TStringList;
  LAudit: TSearchAudit;
  LInside: Int64;
  LOutside: Int64;
  LTimestamp: UTF8String;
  LStatus: UTF8String;
  LError: UTF8String;
  LPmid: UTF8String;
  LOverlap: UTF8String;
  I: Integer;
begin
  LIds := TStringList.Create;
  LSeen := MakeSet;
  try
    LTimestamp := UtcTimestamp;
    LAudit := Default(TSearchAudit);
    LAudit.Hits := -1;
    LError := '';
    try
      if SearchSet(AQuery, AQueryId, 'root', LIds, LSeen, LAudit) > SearchLimit then
      begin
        LInside := SearchRange(AQuery, AQueryId, FirstEdYear, LastEdYear, LIds, LSeen, LAudit);
        LOutside := SearchSet('(' + AQuery + ') NOT ' + DateRange(FirstEdYear, LastEdYear),
          AQueryId, 'outside EDAT partition', LIds, LSeen, LAudit);
        if LOutside > SearchLimit then
        begin
          raise EInOutError.Create('Out-of-range EDAT records exceed the ESearch limit. ' +
            'Broaden the EDAT date partitions or use Entrez Direct');
        end;
        if LInside + LOutside <> LAudit.Hits then
        begin
          raise EConvertError.Create('EDAT partitions do not reconcile to the root count');
        end;
      end;
      if LIds.Count <> LAudit.Hits then
      begin
        raise EConvertError.Create('Distinct PubMed IDs do not match the root count');
      end;
      LStatus := 'Retrieved';
    except
      on LException: Exception do
      begin
        LError := CleanField(LException.Message);
        if LIds.Count > 0 then LStatus := 'Partial' else LStatus := 'Failed';
        Inc(FIncomplete);
      end;
    end;
    for I := 0 to LIds.Count - 1 do
    begin
      LPmid := LIds[I];
      FAllIds.Add(LPmid);
      if FKnown.IndexOf('PMID:' + LPmid) >= 0 then LOverlap := 'Yes' else LOverlap := 'No';
      WriteLine(FIds, AQueryId + Tab + ACategory + Tab + AIngredient + Tab + IntToStr(I + 1) +
        Tab + LPmid + Tab + LOverlap);
    end;
    WriteLine(FQueries, AQueryId + Tab + ACategory + Tab + AIngredient + Tab + LTimestamp + Tab +
      AQuery + Tab + LAudit.Translation + Tab + LStatus + Tab + IntToStr(LAudit.Hits) + Tab +
      IntToStr(LIds.Count) + Tab + IntToStr(LAudit.Requests) + Tab + LAudit.Warnings + Tab + LError);
  finally
    LSeen.Free;
    LIds.Free;
  end;
end;

function JsonItems(AObject: TJSONData; const APath: String): UTF8String;
var
  LArray: TJSONData;
  I: Integer;
begin
  Result := '';
  LArray := AObject.FindPath(APath);
  if Assigned(LArray) and (LArray.JSONType = jtArray) then
  begin
    for I := 0 to LArray.Count - 1 do
    begin
      if Result <> '' then Result := Result + '|';
      Result := Result + CleanField(LArray.Items[I].AsString);
    end;
  end;
end;

procedure TPubMedRun.Summarize;
var
  LJson: TJSONData;
  LRecord: TJSONData;
  LArticleIds: TJSONData;
  LIds: UTF8String;
  LPmid: UTF8String;
  LDoi: UTF8String;
  LPmcid: UTF8String;
  LIdType: UTF8String;
  LTitle: UTF8String;
  LJournal: UTF8String;
  LOverlap: UTF8String;
  LTimestamp: UTF8String;
  LError: UTF8String;
  LStatus: UTF8String;
  LHasAbstract: UTF8String;
  LOffset: Integer;
  LCount: Integer;
  LWritten: Integer;
  LBatch: Integer;
  I: Integer;
  J: Integer;
begin
  LOffset := 0;
  LBatch := 0;
  while LOffset < FAllIds.Count do
  begin
    Inc(LBatch);
    LCount := Min(SummaryBatchSize, FAllIds.Count - LOffset);
    LIds := FAllIds[LOffset];
    for I := 1 to LCount - 1 do LIds := LIds + ',' + FAllIds[LOffset + I];
    LTimestamp := UtcTimestamp;
    LWritten := 0;
    LError := '';
    try
      LJson := GetJSON(Fetch('esummary.fcgi?db=pubmed&retmode=json&version=2.0&id=' + LIds), True);
      try
        for I := 0 to LCount - 1 do
        begin
          LPmid := FAllIds[LOffset + I];
          LRecord := LJson.FindPath('result.' + LPmid);
          if not Assigned(LRecord) or (JsonText(LRecord, 'uid') <> LPmid) then
          begin
            if LError <> '' then LError := LError + ', ';
            LError := LError + LPmid;
            Continue;
          end;
          LTitle := JsonText(LRecord, 'title');
          LJournal := JsonText(LRecord, 'fulljournalname');
          if LTitle = '' then LTitle := JsonText(LRecord, 'booktitle');
          if LTitle = '' then LTitle := JsonText(LRecord, 'sorttitle');
          if LJournal = '' then LJournal := JsonText(LRecord, 'publishername');
          LDoi := '';
          LPmcid := '';
          LArticleIds := LRecord.FindPath('articleids');
          if Assigned(LArticleIds) and (LArticleIds.JSONType = jtArray) then
          begin
            for J := 0 to LArticleIds.Count - 1 do
            begin
              LIdType := JsonText(LArticleIds.Items[J], 'idtype');
              if LIdType = 'doi' then LDoi := LowerCase(JsonText(LArticleIds.Items[J], 'value'));
              if LIdType = 'pmc' then LPmcid := JsonText(LArticleIds.Items[J], 'value');
            end;
          end;
          LOverlap := 'Novel';
          if FKnown.IndexOf('PMID:' + LPmid) >= 0 then LOverlap := 'PMID'
          else if (LDoi <> '') and (FKnown.IndexOf('DOI:' + LDoi) >= 0) then LOverlap := 'DOI'
          else if (LPmcid <> '') and (FKnown.IndexOf('PMCID:' + LPmcid) >= 0) then LOverlap := 'PMCID';
          if Pos('Has Abstract', JsonItems(LRecord, 'attributes')) > 0 then
            LHasAbstract := 'Yes' else LHasAbstract := 'Unmarked';
          WriteLine(FRecords, 'PMID:' + LPmid + Tab + LPmid + Tab + LDoi + Tab + LPmcid + Tab +
            LTitle + Tab + LJournal + Tab +
            JsonText(LRecord, 'sortpubdate') + Tab + JsonItems(LRecord, 'pubtype') + Tab +
            LHasAbstract + Tab + LOverlap);
          Inc(LWritten);
        end;
        if LError <> '' then LError := 'Missing or unusable summary for PMID ' + LError;
      finally
        LJson.Free;
      end;
    except
      on LException: Exception do LError := CleanField(LException.Message);
    end;
    if LWritten = LCount then
    begin
      LStatus := 'Retrieved';
    end
    else
    begin
      if LWritten = 0 then LStatus := 'Failed' else LStatus := 'Partial';
      Inc(FIncomplete);
    end;
    WriteLine(FSummaryBatches, IntToStr(LBatch) + Tab + LTimestamp + Tab + LIds + Tab +
      IntToStr(LCount) + Tab + IntToStr(LWritten) + Tab + LStatus + Tab + LError);
    Inc(LOffset, LCount);
  end;
end;

procedure TPubMedRun.Run(const AQueriesPath, ASelection: String);
var
  LRows: TStringList;
  LFields: TFields;
  LSeen: TStringList;
  LCount: Integer;
  LPmid: UTF8String;
  I: Integer;
begin
  if StartsStr('summary:', ASelection) then
  begin
    LPmid := Copy(ASelection, Length('summary:') + 1, MaxInt);
    if not IsPmid(LPmid) then
    begin
      raise EConvertError.Create('Expected a numeric PMID after summary:');
    end;
    FAllIds.Add(LPmid);
    Summarize;
    if FIncomplete > 0 then ExitCode := 2;
    Exit;
  end;
  LRows := TStringList.Create;
  LSeen := MakeSet;
  try
    LRows.LoadFromFile(AQueriesPath, TEncoding.UTF8);
    if (LRows.Count < 2) or not StartsStr('query_id'#9'category'#9'ingredient'#9'searched_utc'#9 +
      'query'#9, LRows[0]) then
    begin
      raise EConvertError.Create('Unexpected Europe PMC ingredient query header');
    end;
    if ASelection = '' then
      WriteLn('Searching PubMed for ', LRows.Count - 1, ' ingredient and related queries')
    else
      WriteLn('Retrying PubMed query ', ASelection);
    LCount := 0;
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], Tab);
      if (Length(LFields) <> 10) or not ValidProviderQueryId(LFields[0]) or
        (LSeen.IndexOf(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid Europe PMC ingredient query row %d', [I + 1]);
      end;
      LSeen.Add(LFields[0]);
      if (ASelection <> '') and (ASelection <> 'P' + LFields[0]) then Continue;
      SearchIngredient('P' + LFields[0], LFields[1], LFields[2], MakePubMedQuery(LFields[4],
        LFields[0], FMesh.Values[LFields[0]]));
      Inc(LCount);
      if LCount mod 20 = 0 then WriteLn(LCount, '/', LRows.Count - 1, ' PubMed searches recorded');
    end;
    if LCount = 0 then
    begin
      raise EConvertError.Create('No PubMed queries selected');
    end;
    WriteLn('Retrieving ESummary metadata for ', FAllIds.Count, ' distinct PMIDs');
    Summarize;
    WriteLn(LCount, ' search queries, ', FAllIds.Count, ' distinct PMIDs, ',
      FIncomplete, ' incomplete searches or summary batches');
    if FIncomplete > 0 then ExitCode := 2;
  finally
    LSeen.Free;
    LRows.Free;
  end;
end;

procedure Run;
var
  LPubMed: TPubMedRun;
begin
  if not (ParamCount in [4, 5]) then
  begin
    raise EConvertError.Create('Usage: foodexperiment.pubmed <ingredient-query-tsv> ' +
      '<ingredient-result-tsv> <mesh-tsv> <output-dir> [query-id|summary:pmid]');
  end;
  LPubMed := TPubMedRun.Create(ExpandFileName(ParamStr(2)), ExpandFileName(ParamStr(3)),
    ExpandFileName(ParamStr(4)));
  try
    LPubMed.Run(ExpandFileName(ParamStr(1)), ParamStr(5));
  finally
    LPubMed.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
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
