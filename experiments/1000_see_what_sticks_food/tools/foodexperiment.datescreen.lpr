{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentDateScreen;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, fpjson, jsonparser, foodexperiment.bibliography,
  foodexperiment.externaldata, foodexperiment.https, foodexperiment.matching;

const
  Tab = #9;
  Exposures = 'phoenix dactylifera|p dactylifera|date palm|date palms|date fruit|date fruits|' +
    'dates fruit|dates fruits|dried date|dried dates|dry date|dry dates|whole date|whole dates|' +
    'fresh dates|palm date|palm dates|ajwa|ajwah|zahedi|zahdi|medjool|mejdool|deglet nour|' +
    'deglet noor|mazafati|mazafatti|khalas|khudri|sukkari|sukari|safawy|safawi|homayra|' +
    'khalal stage|rutab stage|tamr stage|tamr date|tamr fruit|tamar fruit|date seed|date seeds|' +
    'date pit|date pits|date stone|date stones|date spathe|date syrup|date paste|date jam|' +
    'date juice|date sap|date oil|date pollen|date pulp|date kernel|date powder|date fiber|' +
    'date fibre|date extract|date vinegar|date flavonoid|date press cake|date beverage|' +
    'date consumption|dates consumption|eating dates|consumed dates|consuming dates|consume dates|' +
    'ate dates|ingest dates|ingestion of dates|intake of dates|dates per day|grams of dates|' +
    'dates daily|dates and figs|figs and dates|date intake|dates intake|fed dates|pitted dates|' +
    'administered dates|dates powder|dates dried|palmier dattier|dattes séchées|fruit du dattier|' +
    'dátil de palma|dátiles secos|palmera datilera';
  OtherScriptExposures = 'خرما|التمر|نخيل التمر|枣椰|椰枣|ナツメヤシ|デーツ|대추야자';
  PainTerms = 'pain|pains|painful|analgesic|analgesics|analgesia|nociception|antinociception|' +
    'anti nociceptive|antinociceptive|nociceptive|nociceptor|nociceptors|hyperalgesia|allodynia|' +
    'writhing|tail flick|hot plate|cold plate|von frey|douleur|douleurs|dolor';
  ParkinsonTerms = 'parkinson|parkinsons|parkinsonian|parkinsonism|paralysis agitans|shaking palsy';
  ModelTerms = 'mptp|rotenone|paraquat|6 ohda|6 hydroxydopamine';
  InflammationTerms = 'edema|oedema|inflammation|inflammatory|anti inflammatory|arthritis';

type
  TCounts = record
    Rows: Integer;
    Abstracts: Integer;
    BareDate: Integer;
    Exposures: Integer;
    TitleExposures: Integer;
    Pain: Integer;
    Parkinson: Integer;
    PainAndParkinson: Integer;
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

procedure Scan(const AInput, AOutput: String);
var
  LMatcher: TMatcher;
  LSignals: TMatcher;
  LLabels: TStringList;
  LOrigins: TStringList;
  LLiteralTerms: TFields;
  LFlags: TMatchFlags;
  LSignalFlags: TMatchFlags;
  LCounts: array[0..3] of TCounts;
  LInput, LInventory, LCandidates, LSummary: Text;
  LLine, LInventoryLine, LRecordText, LKey, LTitleTerms, LAllTerms, LOrigin: UTF8String;
  LTerm: UTF8String;
  LRow, LProvenance: TFields;
  LRank, LOriginIndex, I: Integer;

  function DetectExposure(const AValue: UTF8String): UTF8String;
  var
    LLiteral: UTF8String;
  begin
    FillChar(LFlags[0], Length(LFlags) * SizeOf(Boolean), 0);
    LMatcher.Match(AValue, LFlags);
    Result := JoinMatches(LLabels, LFlags, 0);
    for LLiteral in LLiteralTerms do
    begin
      if Pos(LLiteral, AValue) = 0 then
      begin
        Continue;
      end;
      if Result <> '' then
      begin
        Result := Result + '|';
      end;
      Result := Result + LLiteral;
    end;
  end;

  procedure CountRow(var ACounts: TCounts);
  begin
    Inc(ACounts.Rows);
    Inc(ACounts.Abstracts, Ord(LRow[14] <> ''));
    Inc(ACounts.BareDate, Ord(LSignalFlags[0]));
    if LAllTerms = '' then
    begin
      Exit;
    end;
    Inc(ACounts.Exposures);
    Inc(ACounts.TitleExposures, Ord(LTitleTerms <> ''));
    Inc(ACounts.Pain, Ord(LSignalFlags[1]));
    Inc(ACounts.Parkinson, Ord(LSignalFlags[2]));
    Inc(ACounts.PainAndParkinson, Ord(LSignalFlags[1] and LSignalFlags[2]));
  end;

begin
  LMatcher := TMatcher.Create;
  LSignals := TMatcher.Create;
  LLabels := TStringList.Create;
  LOrigins := TStringList.Create;
  try
    LOrigins.Add('all');
    LOrigins.Add('same-query-core');
    LOrigins.Add('cross-query-core');
    LOrigins.Add('provider-recovery');
    for LTerm in SplitFields(Exposures, '|') do
    begin
      LMatcher.Add(LTerm, LLabels.Add(LTerm));
    end;
    for LTerm in SplitFields('date|dates', '|') do
    begin
      LSignals.Add(LTerm, 0);
    end;
    for LTerm in SplitFields(PainTerms, '|') do
    begin
      LSignals.Add(LTerm, 1);
    end;
    for LTerm in SplitFields(ParkinsonTerms, '|') do
    begin
      LSignals.Add(LTerm, 2);
    end;
    for LTerm in SplitFields(ModelTerms, '|') do
    begin
      LSignals.Add(LTerm, 3);
    end;
    for LTerm in SplitFields(InflammationTerms, '|') do
    begin
      LSignals.Add(LTerm, 4);
    end;
    LMatcher.Prepare;
    LSignals.Prepare;
    LLiteralTerms := SplitFields(OtherScriptExposures, '|');
    SetLength(LFlags, LLabels.Count);
    SetLength(LSignalFlags, 5);
    FillChar(LCounts, SizeOf(LCounts), 0);
    LRank := 0;
    OpenInput(LInput, AInput + 'merged_metadata.tsv');
    try
      OpenInput(LInventory, AInput + 'inventory.tsv');
      try
        OpenOutput(LCandidates, AOutput + 'date-exposure-candidates.tsv');
        try
          ReadLn(LInput, LLine);
          ReadLn(LInventory, LInventoryLine);
          if (LLine <> BibliographyHeader) or (Pos('idlist_rank' + Tab, LInventoryLine) <> 1) then
          begin
            raise EConvertError.Create('Unexpected recovery file header');
          end;
          WriteRow(LCandidates, ['rank', 'provider_key', 'source_key', 'origin', 'title_exposure_terms',
            'all_exposure_terms', 'pain_term', 'parkinson_term', 'model_term', 'inflammation_term',
            'publication_date', 'publication_types', 'title', 'abstract']);
          while not Eof(LInput) do
          begin
            Inc(LRank);
            ReadLn(LInput, LLine);
            ReadLn(LInventory, LInventoryLine);
            LRow := SplitFields(LLine, Tab);
            LProvenance := SplitFields(LInventoryLine, Tab);
            if (Length(LRow) <> 15) or (Length(LProvenance) <> 7) then
            begin
              raise EConvertError.CreateFmt('Invalid metadata at rank %d', [LRank]);
            end;
            LKey := LRow[5] + ':' + LRow[6];
            LOrigin := LProvenance[2];
            LOriginIndex := LOrigins.IndexOf(LOrigin);
            if (LRow[0] <> '0502-2') or (StrToInt(LRow[3]) <> LRank) or
              (LRow[3] <> LProvenance[0]) or (LKey <> LProvenance[1]) or (LOriginIndex <= 0) then
            begin
              raise EConvertError.CreateFmt('Mismatched metadata provenance at rank %d', [LRank]);
            end;
            LTitleTerms := DetectExposure(LRow[10]);
            LRecordText := LRow[10] + #10 + LRow[14];
            LAllTerms := DetectExposure(LRecordText);
            FillChar(LSignalFlags[0], Length(LSignalFlags) * SizeOf(Boolean), 0);
            LSignals.Match(LRecordText, LSignalFlags);
            CountRow(LCounts[0]);
            CountRow(LCounts[LOriginIndex]);
            if LAllTerms <> '' then
            begin
              WriteRow(LCandidates, [LRow[3], LKey, LRow[4], LOrigin, LTitleTerms, LAllTerms,
                IntToStr(Ord(LSignalFlags[1])), IntToStr(Ord(LSignalFlags[2])),
                IntToStr(Ord(LSignalFlags[3])), IntToStr(Ord(LSignalFlags[4])),
                LRow[12], LRow[13], LRow[10], LRow[14]]);
            end;
          end;
          if not Eof(LInventory) then
          begin
            raise EConvertError.Create('Recovery inventory has unresolved or extra ranks');
          end;
        finally
          Close(LCandidates);
        end;
      finally
        Close(LInventory);
      end;
    finally
      Close(LInput);
    end;
    OpenOutput(LSummary, AOutput + 'date-screen-counts.tsv');
    try
      WriteRow(LSummary, ['origin', 'rows_screened', 'abstracts_present', 'date_word_rows',
        'exposure_term_rows', 'exposure_term_in_title', 'exposure_plus_pain',
        'exposure_plus_parkinson', 'exposure_plus_pain_and_parkinson']);
      for I := 0 to High(LCounts) do
      begin
        WriteRow(LSummary, [LOrigins[I], IntToStr(LCounts[I].Rows), IntToStr(LCounts[I].Abstracts),
          IntToStr(LCounts[I].BareDate), IntToStr(LCounts[I].Exposures), IntToStr(LCounts[I].TitleExposures),
          IntToStr(LCounts[I].Pain), IntToStr(LCounts[I].Parkinson), IntToStr(LCounts[I].PainAndParkinson)]);
      end;
    finally
      Close(LSummary);
    end;
  finally
    LOrigins.Free;
    LLabels.Free;
    LSignals.Free;
    LMatcher.Free;
  end;
end;

procedure ScanBodies(const AInput, AOutput, AProbe: String);
var
  LDocument, LHits, LResults: TJSONData;
  LClient: TEuropePmc;
  LKeys: TStringList;
  LProbeTerms: TFields;
  LInput, LAccess, LContexts: Text;
  LLine, LKey, LBody, LLower, LTerm, LContext, LError, LId, LPath: UTF8String;
  LRow: TFields;
  LResponse: TSearchResponse;
  LIndex, LStart, LOccurrences, LMatched, I: Integer;
  LFile: TFileStream;
begin
  LDocument := GetJSON(ReadBytes(AProbe), True);
  LClient := nil;
  LKeys := TStringList.Create;
  try
    LHits := LDocument.FindPath('hitCount');
    LResults := LDocument.FindPath('resultList.result');
    if not Assigned(LHits) or (LHits.JSONType <> jtNumber) or not Assigned(LResults) or
      (LResults.JSONType <> jtArray) or (LHits.AsInt64 <> LResults.Count) then
    begin
      raise EConvertError.Create('The exact exposure provider result page is incomplete');
    end;
    LKeys.Sorted := True;
    LKeys.Duplicates := dupError;
    for I := 0 to LResults.Count - 1 do
    begin
      LKey := JsonText(LResults.Items[I], 'source') + ':' + JsonText(LResults.Items[I], 'id');
      LKeys.Add(LKey);
    end;
    LProbeTerms := SplitFields(Exposures, '|');
    LMatched := 0;
    OpenInput(LInput, AInput + 'merged_metadata.tsv');
    try
      ReadLn(LInput, LLine);
      if LLine <> BibliographyHeader then
      begin
        raise EConvertError.Create('Unexpected recovery bibliography header');
      end;
      OpenOutput(LAccess, AOutput + 'date-body-access.tsv');
      try
        OpenOutput(LContexts, AOutput + 'date-body-contexts.tsv');
        try
          WriteRow(LAccess, ['rank', 'provider_key', 'pmcid', 'title', 'status', 'bytes',
            'lexical_occurrences', 'access_note', 'retrieved_utc', 'url']);
          WriteRow(LContexts, ['rank', 'provider_key', 'pmcid', 'term', 'context']);
          while not Eof(LInput) do
          begin
            ReadLn(LInput, LLine);
            LRow := SplitFields(LLine, Tab);
            if Length(LRow) <> 15 then
            begin
              raise EConvertError.Create('Invalid recovery bibliography row');
            end;
            LKey := LRow[5] + ':' + LRow[6];
            if LKeys.IndexOf(LKey) < 0 then
            begin
              Continue;
            end;
            Inc(LMatched);
            LId := LRow[9];
            LPath := '/europepmc/webservices/rest/' + UrlEncode(LId) + '/fullTextXML';
            LResponse := Default(TSearchResponse);
            LError := '';
            LOccurrences := 0;
            if LId = '' then
            begin
              LError := 'No PMCID in metadata';
            end
            else if FileExists(AOutput + LId + '.xml') then
            begin
              LResponse.Status := 200;
              LResponse.Body := ReadBytes(AOutput + LId + '.xml');
              LError := 'Saved public XML';
            end
            else
            begin
              if LClient = nil then
              begin
                LClient := TEuropePmc.Create;
              end;
              try
                LResponse := LClient.GetPath(LPath);
              except
                on LException: Exception do
                begin
                  LError := CleanField(LException.Message);
                end;
              end;
              Sleep(200);
              if LResponse.Status = 200 then
              begin
                LFile := TFileStream.Create(AOutput + LId + '.xml', fmCreate);
                try
                  if LResponse.Body <> '' then
                  begin
                    LFile.WriteBuffer(LResponse.Body[1], Length(LResponse.Body));
                  end;
                finally
                  LFile.Free;
                end;
              end;
            end;
            if LResponse.Status = 200 then
            begin
              LBody := CleanField(LResponse.Body);
              LLower := LowerCase(LBody);
              for LTerm in LProbeTerms do
              begin
                LIndex := Pos(LTerm, LLower);
                while LIndex > 0 do
                begin
                  Inc(LOccurrences);
                  LStart := LIndex - 125;
                  if LStart < 1 then
                  begin
                    LStart := 1;
                  end;
                  LContext := Copy(LBody, LStart, LIndex - LStart + Length(LTerm) + 125);
                  WriteRow(LContexts, [LRow[3], LKey, LId, LTerm, LContext]);
                  LIndex := PosEx(LTerm, LLower, LIndex + Length(LTerm));
                end;
              end;
            end;
            WriteRow(LAccess, [LRow[3], LKey, LId, LRow[10], IntToStr(LResponse.Status),
              IntToStr(Length(LResponse.Body)), IntToStr(LOccurrences), LError, UtcTimestamp,
              'https://www.ebi.ac.uk' + LPath]);
            Flush(LAccess);
            Flush(LContexts);
          end;
          if LMatched <> LKeys.Count then
          begin
            raise EConvertError.Create('Exact exposure provider query includes IDs outside recovery');
          end;
        finally
          Close(LContexts);
        end;
      finally
        Close(LAccess);
      end;
    finally
      Close(LInput);
    end;
  finally
    LKeys.Free;
    LClient.Free;
    LDocument.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  if not (ParamCount in [2, 3]) then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.datescreen METADATA_RECOVERY_DIR OUTPUT_DIR [EXACT_ID_JSON]');
    Halt(2);
  end;
  if not ForceDirectories(ParamStr(2)) then
  begin
    raise EInOutError.Create('Cannot create date screen directory');
  end;
  Scan(IncludeTrailingPathDelimiter(ParamStr(1)), IncludeTrailingPathDelimiter(ParamStr(2)));
  if ParamCount = 3 then
  begin
    ScanBodies(IncludeTrailingPathDelimiter(ParamStr(1)), IncludeTrailingPathDelimiter(ParamStr(2)),
      ParamStr(3));
  end;
end.
