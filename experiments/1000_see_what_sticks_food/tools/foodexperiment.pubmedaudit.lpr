{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPubMedAudit;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Generics.Collections, foodexperiment.externaldata;

const
  Tab = #9;

type
  TRows = TDictionary<UTF8String, TFields>;

procedure Require(ACondition: Boolean; const AContext: UTF8String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AContext);
  end;
end;

procedure LoadRows(ARows: TRows; const APath: String; AKeyColumn, AWidth: Integer;
  AAllowReplacement: Boolean = False);
var
  LFile: Text;
  LLine: UTF8String;
  LFields: TFields;
  LKey: UTF8String;
begin
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    Require(Length(SplitFields(LLine, Tab)) = AWidth, 'Unexpected TSV header in ' + APath);
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, Tab);
      Require(Length(LFields) = AWidth, 'Unexpected TSV row in ' + APath);
      LKey := LFields[AKeyColumn];
      Require(LKey <> '', 'Missing TSV row key in ' + APath);
      if AAllowReplacement then
      begin
        ARows.AddOrSetValue(LKey, LFields);
      end
      else
      begin
        ARows.Add(LKey, LFields);
      end;
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure CountIds(const APath: String; AQueries, ARecords: TRows;
  ACounts: TDictionary<UTF8String, Integer>; ASeenIds, ASeenAppearances: TStringList);
var
  LFile: Text;
  LLine: UTF8String;
  LFields: TFields;
  LQuery: TFields;
  LCount: Integer;
begin
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    Require(LLine = 'query_id'#9'category'#9'ingredient'#9'rank'#9'pmid'#9 +
      'europe_pmc_pmid_overlap', 'Unexpected PubMed ID header in ' + APath);
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, Tab);
      Require(Length(LFields) = 6, 'Unexpected ID row in ' + APath);
      Require(AQueries.TryGetValue(LFields[0], LQuery), 'Unknown query ' + LFields[0]);
      Require((LFields[1] = LQuery[1]) and (LFields[2] = LQuery[2]),
        'Query ingredient mismatch for ' + LFields[0]);
      Require(ARecords.ContainsKey(LFields[4]), 'Missing summary for PMID ' + LFields[4]);
      ACounts.TryGetValue(LFields[0], LCount);
      Inc(LCount);
      Require(StrToInt(LFields[3]) = LCount, 'Missing or unordered rank for ' + LFields[0]);
      ACounts.AddOrSetValue(LFields[0], LCount);
      ASeenIds.Add(LFields[4]);
      ASeenAppearances.Add(LFields[0] + Tab + LFields[4]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure Audit(const ADirectory: String);
var
  LQueries: TRows;
  LRecords: TRows;
  LDispositions: TRows;
  LCounts: TDictionary<UTF8String, Integer>;
  LSeenIds: TStringList;
  LSeenAppearances: TStringList;
  LDirectory: String;
  LKey: UTF8String;
  LFields: TFields;
  LDisposition: TFields;
  LCount: Integer;
  LZero: Integer;
  LWarnings: Integer;
  LNovel: Integer;
  LAbstracts: Integer;
begin
  LQueries := TRows.Create;
  LRecords := TRows.Create;
  LDispositions := TRows.Create;
  LCounts := TDictionary<UTF8String, Integer>.Create;
  LSeenIds := TStringList.Create;
  LSeenAppearances := TStringList.Create;
  try
    LSeenIds.Sorted := True;
    LSeenIds.Duplicates := dupIgnore;
    LSeenAppearances.Sorted := True;
    LSeenAppearances.Duplicates := dupError;
    LDirectory := IncludeTrailingPathDelimiter(ADirectory);
    LoadRows(LQueries, LDirectory + 'pubmed_queries.tsv', 0, 12);
    LoadRows(LQueries, LDirectory + 'query-retry-pubmed_queries.tsv', 0, 12, True);
    LoadRows(LRecords, LDirectory + 'pubmed_records.tsv', 1, 10);
    LoadRows(LRecords, LDirectory + 'summary-retry-pubmed_records.tsv', 1, 10, True);
    LoadRows(LRecords, LDirectory + 'query-retry-pubmed_records.tsv', 1, 10, True);
    LoadRows(LDispositions, LDirectory + 'pubmed_novel_dispositions.tsv', 1, 6);
    CountIds(LDirectory + 'pubmed_ids.tsv', LQueries, LRecords, LCounts,
      LSeenIds, LSeenAppearances);
    CountIds(LDirectory + 'query-retry-pubmed_ids.tsv', LQueries, LRecords, LCounts,
      LSeenIds, LSeenAppearances);
    LZero := 0;
    LWarnings := 0;
    for LKey in LQueries.Keys do
    begin
      LFields := LQueries[LKey];
      LCounts.TryGetValue(LKey, LCount);
      Require((LFields[6] = 'Retrieved') and (StrToInt(LFields[7]) = LCount) and
        (StrToInt(LFields[8]) = LCount), 'Unreconciled query ' + LKey);
      if LCount = 0 then
      begin
        Inc(LZero);
      end;
      if LFields[10] <> '' then
      begin
        Inc(LWarnings);
      end;
    end;
    Require(LSeenIds.Count = LRecords.Count, 'Summaries contain unexpected PMIDs');
    LNovel := 0;
    LAbstracts := 0;
    for LKey in LRecords.Keys do
    begin
      LFields := LRecords[LKey];
      Require(LFields[0] = 'PMID:' + LKey, 'Incorrect record key for PMID ' + LKey);
      if LFields[9] = 'Novel' then
      begin
        Inc(LNovel);
        Require(LDispositions.TryGetValue(LKey, LDisposition), 'Missing disposition for ' + LKey);
        Require((LDisposition[0] = LFields[0]) and (LDisposition[3] <> '') and
          (LDisposition[5] <> ''), 'Incomplete disposition for PMID ' + LKey);
        Require((LDisposition[2] = 'Retrieved') or (LDisposition[2] = 'NoAbstract'),
          'Unresolved abstract access for PMID ' + LKey);
        if LDisposition[2] = 'Retrieved' then
        begin
          Inc(LAbstracts);
        end;
      end;
    end;
    Require(LDispositions.Count = LNovel, 'Disposition ledger contains non-novel PMIDs');
    WriteLn('Queries: ', LQueries.Count, ' completed, ', LZero, ' with no hits, ',
      LWarnings, ' with PubMed warning-list entries');
    WriteLn('Result appearances: ', LSeenAppearances.Count, '. Distinct PMIDs: ', LRecords.Count);
    WriteLn('Novel PMIDs: ', LNovel, '. Abstracts: ', LAbstracts, ' available, ',
      LNovel - LAbstracts, ' unavailable');
  finally
    LSeenAppearances.Free;
    LSeenIds.Free;
    LCounts.Free;
    LDispositions.Free;
    LRecords.Free;
    LQueries.Free;
  end;
end;

begin
  if ParamCount <> 1 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.pubmedaudit <pubmed-ledger-directory>');
    Halt(1);
  end;
  try
    Audit(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
