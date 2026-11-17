{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentDrks;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, fpjson, jsonscanner, jsonparser, foodexperiment.https,
  foodexperiment.externaldata, foodexperiment.matching;

const
  ExportUrl = 'https://drks.de/search/de/download/all-json';
  TrialUrl = 'https://drks.de/search/en/trial/';
  Scope = 'Parkinson, paralysis agitans, shaking palsy, paralysie agitante,' +
    ' Schüttellähmung, Schuettellaehmung, or ICD-10 G20 prefix';
  ExposureTerms = 'diet|diets|dietary|food|foods|nutrition|nutritional|nutrition therapy|' +
    'meal|meals|drink|feeding|herb|herbal|botanical|spice|oil|ketogenic|prebiotic|probiotic|' +
    'supplement|supplementation|fiber|fibre|mucuna|ashwagandha|capsaicin|mediterranean|' +
    'polyphenol|omega 3|fatty acid|vitamin|caffeine|koffein|kaffee|tee|ernährung|' +
    'ernährungsberatung|ernährungstherapie|ernährungsintervention|nahrung|' +
    'nahrungsergänzung|diät|lebensmittel|speiseöl|ballaststoffe|pflanzlich|probiotika|' +
    'präbiotika|kräuter|gewürz|öl|mahlzeit';

type
  TTrialVisitor = procedure(ATrial: TJSONData) of object;

  TTrialArrayReader = class(TJSONParser)
  public
    procedure ReadTrials(AVisit: TTrialVisitor);
  end;

  TTrialVersion = class
    Updated: String;
    Status: String;
  end;

  TDrksScan = class
  private
    FIds: TStringList;
    FLabels: TStringList;
    FMatcher: TMatcher;
    FMatches: TMatchFlags;
    FInventory: Text;
    FDetails: Text;
    FDuplicates: Text;
    FExportRows: Integer;
    FParkinsonRows: Integer;
    FFlaggedRows: Integer;
    procedure LoadTerms(const ARoot: String);
    procedure InspectTrial(ATrial: TJSONData);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, AInput, AOutput: String);
  end;

function Cell(AData: TJSONData; const APath: String): UTF8String;
var
  LValue: TJSONData;
begin
  Result := '';
  LValue := AData.FindPath(APath);
  if Assigned(LValue) and (LValue.JSONType in [jtString, jtBoolean, jtNumber]) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

function ListCell(AData: TJSONData; const AList, AField: String): UTF8String;
var
  LList: TJSONData;
  LValue: UTF8String;
  LIndex: Integer;
begin
  Result := '';
  LList := AData.FindPath(AList);
  if not Assigned(LList) or (LList.JSONType <> jtArray) then
  begin
    Exit;
  end;
  for LIndex := 0 to LList.Count - 1 do
  begin
    LValue := Cell(LList.Items[LIndex], AField);
    if LValue = '' then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + ' | ';
    end;
    Result := Result + LValue;
  end;
end;

function MentionsParkinson(const AText: UTF8String): Boolean;
var
  LText: UTF8String;
begin
  LText := UTF8Encode(UnicodeLowerCase(UTF8Decode(AText)));
  Result := (Pos('parkinson', LText) > 0) or (Pos('paralysis agitans', LText) > 0) or
    (Pos('shaking palsy', LText) > 0) or (Pos('paralysie agitante', LText) > 0) or
    (Pos('schüttellähmung', LText) > 0) or (Pos('schuettellaehmung', LText) > 0);
end;

procedure TTrialArrayReader.ReadTrials(AVisit: TTrialVisitor);
var
  LRecord: TJSONData;
  LSeparator: TJSONToken;
begin
  if GetNextToken <> tkSquaredBraceOpen then
  begin
    raise EConvertError.Create('Expected a DRKS JSON array');
  end;
  repeat
    { joSingle parses one object without collecting the entire top-level array. }
    LRecord := Parse;
    try
      if LRecord.JSONType <> jtObject then
      begin
        raise EConvertError.Create('Expected an object in the DRKS export');
      end;
      AVisit(LRecord);
    finally
      LRecord.Free;
    end;
    LSeparator := GetNextToken;
  until LSeparator <> tkComma;
  if (LSeparator <> tkSquaredBraceClose) or (GetNextToken <> tkEOF) then
  begin
    raise EConvertError.Create('Expected the end of the DRKS JSON array');
  end;
end;

constructor TDrksScan.Create;
begin
  inherited Create;
  FIds := TStringList.Create;
  FIds.Sorted := True;
  FIds.Duplicates := dupError;
  FIds.OwnsObjects := True;
  FLabels := TStringList.Create;
  FMatcher := TMatcher.Create;
end;

destructor TDrksScan.Destroy;
begin
  FMatcher.Free;
  FLabels.Free;
  FIds.Free;
  inherited Destroy;
end;

procedure TDrksScan.LoadTerms(const ARoot: String);
var
  LRows: TStringList;
  LParts: TFields;
  LTerm: UTF8String;
  LRow: Integer;
  LIndex: Integer;
begin
  LRows := TStringList.Create;
  try
    for LTerm in SplitFields(ExposureTerms, '|') do
    begin
      FMatcher.Add(LTerm, FLabels.Add(LTerm));
    end;
    LRows.Text := ReadBytes(ARoot + 'ingredients.tsv');
    for LRow := 1 to LRows.Count - 1 do
    begin
      LParts := SplitFields(LRows[LRow], #9);
      if Length(LParts) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [LRow + 1]);
      end;
      LIndex := FLabels.IndexOf(LParts[1]);
      if LIndex < 0 then
      begin
        LIndex := FLabels.Add(LParts[1]);
      end;
      for LTerm in SplitFields(LParts[1] + '|' + LParts[3], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
    LRows.Text := ReadBytes(ARoot + 'exposure-expansions.tsv');
    for LRow := 1 to LRows.Count - 1 do
    begin
      LParts := SplitFields(LRows[LRow], #9);
      if Length(LParts) <> 3 then
      begin
        raise EConvertError.CreateFmt('Invalid exposure expansion row %d', [LRow + 1]);
      end;
      LIndex := FLabels.IndexOf(LParts[0]);
      if LIndex < 0 then
      begin
        raise EConvertError.CreateFmt('Unknown ingredient at expansion row %d', [LRow + 1]);
      end;
      for LTerm in SplitFields(LParts[2], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
  finally
    LRows.Free;
  end;
  SetLength(FMatches, FLabels.Count);
  FMatcher.Prepare;
end;

procedure TDrksScan.InspectTrial(ATrial: TJSONData);
var
  LId: UTF8String;
  LTitle: UTF8String;
  LConditions: UTF8String;
  LCode: UTF8String;
  LConditionList: TJSONData;
  LCondition: TJSONData;
  LIndex: Integer;
  LG20: Boolean;
  LArms: UTF8String;
  LSummary: UTF8String;
  LOutcome: UTF8String;
  LInclusion: UTF8String;
  LExclusion: UTF8String;
  LMatchField: UTF8String;
  LExposure: UTF8String;
  LRegistration: UTF8String;
  LResults: UTF8String;
  LPublications: TJSONData;
  LVersion: TTrialVersion;
  LUpdate: String;
  LStatus: String;
begin
  LId := Cell(ATrial, 'drksId');
  if (Copy(LId, 1, 4) <> 'DRKS') or (Length(LId) <> 12) then
  begin
    raise EConvertError.CreateFmt('Invalid DRKS identifier %s', [LId]);
  end;
  Inc(FExportRows);
  LIndex := FIds.IndexOf(LId);
  LUpdate := Cell(ATrial, 'lastUpdate');
  LStatus := Cell(ATrial, 'trialStatus');
  if LIndex < 0 then
  begin
    LVersion := TTrialVersion.Create;
    LVersion.Updated := LUpdate;
    LVersion.Status := LStatus;
    FIds.AddObject(LId, LVersion);
  end
  else
  begin
    LVersion := FIds.Objects[LIndex] as TTrialVersion;
    Write(FDuplicates, LId, #9, FExportRows, #9, LVersion.Updated, #9, LVersion.Status, #9,
      LUpdate, #9, LStatus, #10);
  end;
  LTitle := ListCell(ATrial, 'trialDescriptions', 'title');
  LConditions := '';
  LG20 := False;
  LConditionList := ATrial.FindPath('studiedHealthConditions');
  if Assigned(LConditionList) and (LConditionList.JSONType = jtArray) then
  begin
    for LIndex := 0 to LConditionList.Count - 1 do
    begin
      LCondition := LConditionList.Items[LIndex];
      LCode := Cell(LCondition, 'code');
      LG20 := LG20 or (Copy(LCode, 1, 3) = 'G20');
      LConditions := Trim(LConditions + ' ' + LCode + ' ' +
        ListCell(LCondition, 'studiedHealthConditionDescriptions', 'comment'));
    end;
  end;
  LArms := ListCell(ATrial, 'observationalGroups', 'comment');
  LSummary := ListCell(ATrial, 'trialDescriptions', 'summary') + ' ' +
    ListCell(ATrial, 'trialDescriptions', 'scientificSummary');
  LOutcome := ListCell(ATrial, 'studyCharacteristic.characteristicDescriptions', 'primaryOutcome') +
    ' ' + ListCell(ATrial, 'studyCharacteristic.characteristicDescriptions', 'secondaryOutcome');
  LInclusion := ListCell(ATrial, 'recruitment.recruitmentDescriptions', 'inclusionCriteria');
  LExclusion := ListCell(ATrial, 'recruitment.recruitmentDescriptions', 'exclusionCriteria');
  if LG20 or MentionsParkinson(LTitle + ' ' + LConditions) then
  begin
    LMatchField := 'title or condition';
  end
  else if MentionsParkinson(LSummary + ' ' + LArms + ' ' + LOutcome + ' ' + LInclusion) then
  begin
    LMatchField := 'description, arm, outcome or inclusion';
  end
  else if MentionsParkinson(LExclusion) then
  begin
    LMatchField := 'exclusion only';
  end
  else
  begin
    Exit;
  end;
  Inc(FParkinsonRows);
  FillChar(FMatches[0], Length(FMatches) * SizeOf(Boolean), 0);
  FMatcher.Match(LTitle + ' ' + LArms + ' ' + LSummary + ' ' + LOutcome, FMatches);
  LExposure := JoinMatches(FLabels, FMatches, 0);
  if LExposure <> '' then
  begin
    Inc(FFlaggedRows);
  end;
  LRegistration := Cell(ATrial, 'registrationDrks');
  LResults := ListCell(ATrial, 'trialResults.trialResultsDescriptions',
    'briefSummaryOfResultsDescription');
  LPublications := ATrial.FindPath('trialResults.publications');
  if Assigned(LPublications) and (LPublications.Count > 0) then
  begin
    LResults := Trim(LResults + ' ' + CleanField(LPublications.AsJSON));
  end;
  Write(FInventory, LId, #9, LRegistration, #9, LMatchField, #9, LTitle, #9, LConditions,
    #9, LExposure, #9, Cell(ATrial, 'recruitment.status'), #9,
    Cell(ATrial, 'trialResults.firstResultPublication'), #9, TrialUrl, LId, '/details', #10);
  Write(FDetails, LId, #9, LTitle, #9, LConditions, #9, LInclusion, #9, LExclusion, #9, LArms,
    #9, LSummary, #9, LOutcome, #9, LResults, #9, Cell(ATrial, 'secondaryIds.otherPrimaryRegisterId'),
    #9, Cell(ATrial, 'secondaryIds.eudraCtNumber'), #10);
end;

procedure TDrksScan.Run(const ARoot, AInput, AOutput: String);
var
  LOutput: String;
  LSource: TFileStream;
  LReader: TTrialArrayReader;
  LStart: String;
  LLedger: Text;
begin
  LoadTerms(IncludeTrailingPathDelimiter(ARoot));
  LOutput := IncludeTrailingPathDelimiter(AOutput);
  if not ForceDirectories(LOutput) then
  begin
    raise EInOutError.Create('Cannot create DRKS output directory');
  end;
  LStart := UtcTimestamp;
  AssignFile(FInventory, LOutput + 'drks-inventory.tsv');
  Rewrite(FInventory);
  SetTextCodePage(FInventory, CP_UTF8);
  try
    AssignFile(FDetails, LOutput + 'drks-detail.tsv');
    Rewrite(FDetails);
    SetTextCodePage(FDetails, CP_UTF8);
    try
      Write(FInventory, 'drks_id'#9'registered'#9'parkinson_match_field'#9'title'#9'conditions'#9,
        'exposure_flags'#9'recruitment_status'#9'first_result_publication'#9'registry_url'#10);
      Write(FDetails, 'drks_id'#9'title'#9'conditions'#9'inclusion'#9'exclusion'#9'arms'#9,
        'summary'#9'outcomes'#9'results_and_publications'#9'cross_registry_id'#9'eudract'#10);
      LSource := TFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
      try
        AssignFile(FDuplicates, LOutput + 'drks-duplicates.tsv');
        Rewrite(FDuplicates);
        try
          Write(FDuplicates, 'drks_id'#9'export_row'#9'first_row_last_update'#9,
            'first_row_status'#9'duplicate_last_update'#9'duplicate_status'#10);
          LReader := TTrialArrayReader.Create(LSource, [joUTF8, joStrict, joSingle]);
          try
            LReader.ReadTrials(InspectTrial);
          finally
            LReader.Free;
          end;
        finally
          CloseFile(FDuplicates);
        end;
      finally
        LSource.Free;
      end;
    finally
      CloseFile(FDetails);
    end;
  finally
    CloseFile(FInventory);
  end;
  AssignFile(LLedger, LOutput + 'drks-query.tsv');
  Rewrite(LLedger);
  SetTextCodePage(LLedger, CP_UTF8);
  try
    Write(LLedger, 'scanned_utc'#9'export_url'#9'export_member'#9'query_scope'#9,
      'records_parsed'#9'unique_ids'#9'parkinson_mentions'#9'exposure_flags'#9'status'#10);
    Write(LLedger, LStart, #9, ExportUrl, #9, ExtractFileName(AInput), #9, Scope, #9,
      FExportRows, #9, FIds.Count, #9, FParkinsonRows, #9, FFlaggedRows, #9, 'completed', #10);
  finally
    CloseFile(LLedger);
  end;
  WriteLn(FExportRows, ' DRKS export rows, ', FIds.Count, ' unique IDs, ',
    FParkinsonRows, ' Parkinson mentions, ', FFlaggedRows, ' exposure flags');
end;

var
  Scan: TDrksScan;
begin
  if ParamCount <> 3 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.drks <experiment-root> <export-json> <output-dir>');
    Halt(2);
  end;
  try
    Scan := TDrksScan.Create;
    try
      Scan.Run(ParamStr(1), ParamStr(2), ParamStr(3));
    finally
      Scan.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
