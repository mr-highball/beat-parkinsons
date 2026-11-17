{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentWhoIctrp;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, DOM, XMLRead, RegExpr,
  foodexperiment.externaldata, foodexperiment.matching;

const
  RootElement = 'Trials_downloaded_from_ICTRP';
  FoodTerms = 'diet|dietary|food|nutrition|nutritional|meal|drink|feeding|herb|herbal|' +
    'botanical|spice|oil|ketogenic|prebiotic|probiotic|supplement|supplementation|fiber|' +
    'fibre|mucuna|ashwagandha|capsaicin|mediterranean|polyphenol|omega 3|fatty acid|' +
    'vitamin|caffeine|kampo|aromatherapy|butyrate|medium chain triglyceride|hop bitter acids|' +
    'kestose|inulin|natto|psyllium|majainhwan|mashiningan|yokukansan|yokukansankachimpihange';
  AsianFoodTerms = '栄養|食事|食品|サプリ|漢方|乳酸菌|コーヒー|カフェイン|緑茶|抹茶|' +
    'レモングラス|精油|ハーブ|生姜|ウコン|ソラマメ|大豆|オリーブ|食用油|ココナッツ|' +
    '大建中湯|抑肝散|六君子湯|麻子仁丸|ハッショウマメ|ビタミン|ケトン|発酵|' +
    '식이|식품|식사|영양|한약|한방|생약|카페인|커피|녹차|생강|인삼|계피|강황|' +
    '올리브|허브|레몬그라스|케톤|비타민|식이섬유';
  RegistrationPattern = '^(NCT[0-9]{8}|[0-9]{4}-[0-9]{6}-[0-9]{2}(-[A-Z]{2}|-[0-9]{2})?|' +
    'DRKS[0-9]{8}|ISRCTN[0-9]{8}|ACTRN[0-9]{14}|CHICTR[0-9]{10}|ITMCTR[0-9]{10}|' +
    'UMIN[0-9]{9}|JRCT[A-Z]?[0-9]{9,10}|JMA-IIA[0-9]{5}|KCT[0-9]{7}|' +
    'IRCT[0-9]{14}N[0-9]+|TCTR[0-9]{11}|CTRI/[0-9]{4}/[0-9]{2}/[0-9]{6}|' +
    'RBR-[A-Z0-9]{5,10}|NL-OMON[0-9]+|PACTR[0-9]{15}|RPCEC[0-9]{8}|PER-[0-9]+-[0-9]{2})$';

type
  TTrial = record
    Id: UTF8String;
    Provider: UTF8String;
    OtherRecords: UTF8String;
    SecondaryIds: UTF8String;
    Registered: UTF8String;
    Refreshed: UTF8String;
    Status: UTF8String;
    StudyType: UTF8String;
    Title: UTF8String;
    ScientificTitle: UTF8String;
    Condition: UTF8String;
    Intervention: UTF8String;
    PrimaryOutcome: UTF8String;
    SecondaryOutcome: UTF8String;
    Url: UTF8String;
    ResultsStatus: UTF8String;
    ResultsDate: UTF8String;
    ResultsPublication: UTF8String;
    ResultsUrl: UTF8String;
    Names: UTF8String;
    Related: UTF8String;
    Broad: UTF8String;
    Context: UTF8String;
    ParkinsonScope: UTF8String;
    Priority: UTF8String;
  end;

  TBridge = record
    Source: Integer;
    Target: Integer;
    Key: UTF8String;
    Basis: UTF8String;
  end;

  TProviderCount = record
    Rows: Integer;
    Candidates: Integer;
    MarkedOther: Integer;
    LinkedRows: Integer;
  end;

  TWhoScreen = class
  private
    FMatcher: TMatcher;
    FNames: TStringList;
    FBroad: TStringList;
    FIdentifiers: TStringList;
    FInternalIds: TStringList;
    FProviders: TStringList;
    FPattern: TRegExpr;
    FAsianTerms: TFields;
    FTrials: array of TTrial;
    FGroups: array of Integer;
    FGroupSizes: array of Integer;
    FProviderCounts: array of TProviderCount;
    FBridges: array of TBridge;
    FExportDate: UTF8String;
    procedure AddTerms(const ATerms: UTF8String; AIndex: Integer);
    procedure LoadVocabulary(const ARoot: String);
    procedure MatchTrial(var ATrial: TTrial; const AInclusion, AExclusion: UTF8String);
    procedure ReadTrial(ANode: TDOMNode; AIndex: Integer);
    procedure ReadExport(const APath: String; AExpected: Integer);
    function CanonicalId(const AValue: UTF8String): UTF8String;
    function GroupRoot(AIndex: Integer): Integer;
    procedure Link(AFrom, ATo: Integer; const AKey, ABasis: UTF8String);
    procedure GroupTrials;
    procedure WriteOutputs(const AOutput: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, AInput, AOutput: String; AExpected: Integer);
  end;

function Field(ANode: TDOMNode; const AName: DOMString): UTF8String;
var
  LChild: TDOMNode;
begin
  Result := '';
  LChild := ANode.FindNode(AName);
  if Assigned(LChild) then
  begin
    Result := Trim(UTF8Encode(LChild.TextContent));
  end;
end;

procedure WriteRow(var AFile: Text; const AValues: array of UTF8String);
var
  I: Integer;
begin
  for I := 0 to High(AValues) do
  begin
    if I > 0 then
    begin
      Write(AFile, #9);
    end;
    Write(AFile, CleanField(AValues[I]));
  end;
  Write(AFile, #10);
end;

procedure OpenTsv(var AFile: Text; const APath: String);
begin
  AssignFile(AFile, APath);
  Rewrite(AFile);
  SetTextCodePage(AFile, CP_UTF8);
end;

procedure AppendTerm(var AValue: UTF8String; const ATerm: UTF8String);
begin
  if AValue <> '' then
  begin
    AValue := AValue + '|';
  end;
  AValue := AValue + ATerm;
end;

function HasParkinson(const AText: UTF8String): Boolean;
var
  LText: UTF8String;
begin
  LText := LowerCase(AText);
  Result := (Pos('parkinson', LText) > 0) or (Pos('paralysis agitans', LText) > 0) or
    (Pos('shaking palsy', LText) > 0) or (Pos('paralysie agitante', LText) > 0) or
    (Pos('パーキンソン', AText) > 0) or (Pos('振戦麻痺', AText) > 0) or
    (Pos('帕金森', AText) > 0) or (Pos('파킨슨', AText) > 0) or
    (Pos('پارکینسون', AText) > 0);
end;

constructor TWhoScreen.Create;
begin
  inherited Create;
  FMatcher := TMatcher.Create;
  FNames := TStringList.Create;
  FBroad := TStringList.Create;
  FIdentifiers := TStringList.Create;
  FIdentifiers.Sorted := True;
  FIdentifiers.Duplicates := dupError;
  FInternalIds := TStringList.Create;
  FInternalIds.Sorted := True;
  FInternalIds.Duplicates := dupError;
  FProviders := TStringList.Create;
  FPattern := TRegExpr.Create;
  FPattern.Expression := RegistrationPattern;
  FAsianTerms := SplitFields(AsianFoodTerms, '|');
end;

destructor TWhoScreen.Destroy;
begin
  FPattern.Free;
  FProviders.Free;
  FInternalIds.Free;
  FIdentifiers.Free;
  FBroad.Free;
  FNames.Free;
  FMatcher.Free;
  inherited Destroy;
end;

procedure TWhoScreen.AddTerms(const ATerms: UTF8String; AIndex: Integer);
var
  LTerm: UTF8String;
begin
  for LTerm in SplitFields(ATerms, '|') do
  begin
    FMatcher.Add(Trim(LTerm), AIndex);
  end;
end;

procedure TWhoScreen.LoadVocabulary(const ARoot: String);
var
  LRows: TStringList;
  LFields: TFields;
  LTerm: UTF8String;
  LIndex: Integer;
  I: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(ARoot + 'ingredients.tsv');
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], #9);
      if Length(LFields) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [I + 1]);
      end;
      LIndex := FNames.Add(LFields[1]);
      AddTerms(LFields[1] + '|' + LFields[3], LIndex * 2);
    end;
    LRows.Text := ReadBytes(ARoot + 'exposure-expansions.tsv');
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], #9);
      if Length(LFields) <> 3 then
      begin
        raise EConvertError.CreateFmt('Invalid exposure expansion row %d', [I + 1]);
      end;
      LIndex := FNames.IndexOf(LFields[0]);
      if (LIndex < 0) or ((LFields[1] <> 'name') and (LFields[1] <> 'related')) then
      begin
        raise EConvertError.CreateFmt('Invalid expansion at row %d', [I + 1]);
      end;
      AddTerms(LFields[2], LIndex * 2 + Ord(LFields[1] = 'related'));
    end;
    for LTerm in SplitFields(FoodTerms, '|') do
    begin
      FMatcher.Add(LTerm, FNames.Count * 2 + FBroad.Add(LTerm));
    end;
  finally
    LRows.Free;
  end;
  FMatcher.Prepare;
end;

procedure TWhoScreen.MatchTrial(var ATrial: TTrial; const AInclusion, AExclusion: UTF8String);
var
  LPrimary: TMatchFlags;
  LContext: TMatchFlags;
  LTerm: UTF8String;
  LTitle: UTF8String;
  I: Integer;
begin
  SetLength(LPrimary, FNames.Count * 2 + FBroad.Count);
  SetLength(LContext, Length(LPrimary));
  FMatcher.Match(ATrial.Title, LPrimary);
  FMatcher.Match(ATrial.ScientificTitle, LPrimary);
  FMatcher.Match(ATrial.Intervention, LPrimary);
  FMatcher.Match(ATrial.Condition, LContext);
  FMatcher.Match(AInclusion, LContext);
  FMatcher.Match(AExclusion, LContext);
  FMatcher.Match(ATrial.PrimaryOutcome, LContext);
  FMatcher.Match(ATrial.SecondaryOutcome, LContext);
  for I := 0 to FNames.Count - 1 do
  begin
    if LPrimary[I * 2] then
    begin
      AppendTerm(ATrial.Names, FNames[I]);
    end;
    if LPrimary[I * 2 + 1] then
    begin
      AppendTerm(ATrial.Related, FNames[I]);
    end;
    if LContext[I * 2] or LContext[I * 2 + 1] then
    begin
      AppendTerm(ATrial.Context, FNames[I]);
    end;
  end;
  ATrial.Broad := JoinMatches(FBroad, LPrimary, FNames.Count * 2);
  LTitle := ATrial.Title + ' | ' + ATrial.ScientificTitle;
  for LTerm in FAsianTerms do
  begin
    if (Pos(LTerm, LTitle) > 0) or (Pos(LTerm, ATrial.Intervention) > 0) then
    begin
      AppendTerm(ATrial.Broad, LTerm);
    end;
  end;
  if HasParkinson(LTitle + ' | ' + ATrial.Condition) or (UpperCase(ATrial.Condition) = 'G20') then
  begin
    ATrial.ParkinsonScope := 'title-or-condition';
  end
  else if HasParkinson(AInclusion + ' | ' + ATrial.PrimaryOutcome + ' | ' +
    ATrial.SecondaryOutcome + ' | ' + ATrial.Intervention) then
  begin
    ATrial.ParkinsonScope := 'other-study-fields';
  end
  else if HasParkinson(AExclusion) then
  begin
    ATrial.ParkinsonScope := 'exclusion-only';
  end;
  if ATrial.Names <> '' then
  begin
    ATrial.Priority := 'ingredient-name';
  end
  else if ATrial.Related <> '' then
  begin
    ATrial.Priority := 'related-exposure';
  end
  else if ATrial.Broad <> '' then
  begin
    ATrial.Priority := 'food-related-term';
  end
  else if ATrial.Context <> '' then
  begin
    ATrial.Priority := 'context-only';
  end;
end;

procedure TWhoScreen.ReadTrial(ANode: TDOMNode; AIndex: Integer);
var
  LTrial: TTrial;
  LDate: UTF8String;
  LInternal: UTF8String;
  LProvider: Integer;
begin
  LTrial := Default(TTrial);
  LTrial.Id := Field(ANode, 'TrialID');
  LTrial.Provider := Field(ANode, 'Source_Register');
  LInternal := Field(ANode, 'Internal_Number');
  LDate := Field(ANode, 'Export_date');
  if (LTrial.Id = '') or (LTrial.Provider = '') or (LInternal = '') or (LDate = '') then
  begin
    raise EConvertError.CreateFmt('Trial row %d lacks required WHO fields', [AIndex + 1]);
  end;
  if FExportDate = '' then
  begin
    FExportDate := LDate;
  end
  else if LDate <> FExportDate then
  begin
    raise EConvertError.CreateFmt('Mixed WHO export dates in trial row %d', [AIndex + 1]);
  end;
  FIdentifiers.AddObject(LTrial.Id, TObject(PtrInt(AIndex)));
  FInternalIds.Add(LInternal);
  LTrial.OtherRecords := Field(ANode, 'other_records');
  LTrial.SecondaryIds := Field(ANode, 'Secondary_ID');
  LTrial.Registered := Field(ANode, 'Date_registration');
  LTrial.Refreshed := Field(ANode, 'Last_Refreshed_on');
  LTrial.Status := Field(ANode, 'Recruitment_Status');
  LTrial.StudyType := Field(ANode, 'Study_type');
  LTrial.Title := Field(ANode, 'Public_title');
  LTrial.ScientificTitle := Field(ANode, 'Scientific_title');
  LTrial.Condition := Field(ANode, 'Condition');
  LTrial.Intervention := Field(ANode, 'Intervention');
  LTrial.PrimaryOutcome := Field(ANode, 'Primary_outcome');
  LTrial.SecondaryOutcome := Field(ANode, 'Secondary_outcome');
  LTrial.Url := Field(ANode, 'web_address');
  LTrial.ResultsStatus := Field(ANode, 'results_yes_no');
  LTrial.ResultsDate := Field(ANode, 'results_date_posted');
  LTrial.ResultsPublication := Field(ANode, 'results_date_first_publication');
  LTrial.ResultsUrl := Field(ANode, 'results_url_link');
  MatchTrial(LTrial, Field(ANode, 'Inclusion_Criteria'), Field(ANode, 'Exclusion_Criteria'));
  FTrials[AIndex] := LTrial;
  LProvider := FProviders.IndexOf(LTrial.Provider);
  if LProvider < 0 then
  begin
    LProvider := FProviders.Add(LTrial.Provider);
    SetLength(FProviderCounts, FProviders.Count);
  end;
  Inc(FProviderCounts[LProvider].Rows);
  if LTrial.Priority <> '' then
  begin
    Inc(FProviderCounts[LProvider].Candidates);
  end;
  if SameText(LTrial.OtherRecords, 'Yes') then
  begin
    Inc(FProviderCounts[LProvider].MarkedOther);
  end;
end;

procedure TWhoScreen.ReadExport(const APath: String; AExpected: Integer);
var
  LDocument: TXMLDocument;
  LNode: TDOMNode;
  LCount: Integer;
begin
  SetLength(FTrials, AExpected);
  LDocument := nil;
  try
    ReadXMLFile(LDocument, APath);
    if not Assigned(LDocument.DocumentElement) or
      (LDocument.DocumentElement.TagName <> RootElement) then
    begin
      raise EConvertError.Create('Unexpected WHO ICTRP XML root');
    end;
    LCount := 0;
    LNode := LDocument.DocumentElement.FirstChild;
    while Assigned(LNode) do
    begin
      if LNode.NodeType = ELEMENT_NODE then
      begin
        if LNode.NodeName <> 'Trial' then
        begin
          raise EConvertError.Create('Unexpected element under the WHO ICTRP XML root');
        end;
        if LCount = AExpected then
        begin
          raise EConvertError.CreateFmt('WHO export has more than %d trial rows', [AExpected]);
        end;
        ReadTrial(LNode, LCount);
        Inc(LCount);
      end;
      LNode := LNode.NextSibling;
    end;
    if LCount <> AExpected then
    begin
      raise EConvertError.CreateFmt('Expected %d WHO trial rows, read %d', [AExpected, LCount]);
    end;
  finally
    LDocument.Free;
  end;
end;

function TWhoScreen.CanonicalId(const AValue: UTF8String): UTF8String;
begin
  Result := UpperCase(Trim(AValue));
  if Copy(Result, 1, 5) = 'JPRN-' then
  begin
    Delete(Result, 1, 5);
  end
  else if Copy(Result, 1, 4) = 'CTIS' then
  begin
    Delete(Result, 1, 4);
  end
  else if Copy(Result, 1, 5) = 'EUCTR' then
  begin
    Delete(Result, 1, 5);
  end;
  if not FPattern.Exec(Result) then
  begin
    Exit('');
  end;
  if (Length(Result) = 17) and (Result[5] = '-') and (Result[16] in ['A'..'Z']) then
  begin
    SetLength(Result, 14);
  end;
end;

function TWhoScreen.GroupRoot(AIndex: Integer): Integer;
begin
  Result := AIndex;
  while FGroups[Result] <> Result do
  begin
    Result := FGroups[Result];
  end;
  FGroups[AIndex] := Result;
end;

procedure TWhoScreen.Link(AFrom, ATo: Integer; const AKey, ABasis: UTF8String);
var
  LFromRoot: Integer;
  LToRoot: Integer;
  LIndex: Integer;
begin
  if AFrom = ATo then
  begin
    Exit;
  end;
  LFromRoot := GroupRoot(AFrom);
  LToRoot := GroupRoot(ATo);
  if LFromRoot > LToRoot then
  begin
    FGroups[LFromRoot] := LToRoot;
  end
  else
  begin
    FGroups[LToRoot] := LFromRoot;
  end;
  LIndex := Length(FBridges);
  SetLength(FBridges, LIndex + 1);
  FBridges[LIndex].Source := AFrom;
  FBridges[LIndex].Target := ATo;
  FBridges[LIndex].Key := AKey;
  FBridges[LIndex].Basis := ABasis;
end;

procedure TWhoScreen.GroupTrials;
var
  LPrimary: TStringList;
  LSecondary: TStringList;
  LSeen: TStringList;
  LKey: UTF8String;
  LValue: UTF8String;
  LPosition: Integer;
  LProvider: Integer;
  I: Integer;
begin
  SetLength(FGroups, Length(FTrials));
  SetLength(FGroupSizes, Length(FTrials));
  LPrimary := TStringList.Create;
  LSecondary := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LPrimary.Sorted := True;
    LSecondary.Sorted := True;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupIgnore;
    for I := 0 to High(FTrials) do
    begin
      FGroups[I] := I;
      LKey := CanonicalId(FTrials[I].Id);
      if LKey = '' then
      begin
        LKey := UpperCase(FTrials[I].Id);
      end;
      if LPrimary.Find(LKey, LPosition) then
      begin
        Link(I, PtrInt(LPrimary.Objects[LPosition]), LKey, 'same-primary-accession');
      end
      else
      begin
        LPrimary.AddObject(LKey, TObject(PtrInt(I)));
      end;
    end;
    for I := 0 to High(FTrials) do
    begin
      LSeen.Clear;
      for LValue in SplitFields(FTrials[I].SecondaryIds, ';') do
      begin
        LKey := CanonicalId(LValue);
        if (LKey = '') and FIdentifiers.Find(Trim(LValue), LPosition) then
        begin
          LKey := UpperCase(Trim(LValue));
        end;
        if LKey <> '' then
        begin
          LSeen.Add(LKey);
        end;
      end;
      for LKey in LSeen do
      begin
        if LPrimary.Find(LKey, LPosition) then
        begin
          Link(I, PtrInt(LPrimary.Objects[LPosition]), LKey, 'secondary-to-primary');
        end
        else if LSecondary.Find(LKey, LPosition) then
        begin
          Link(I, PtrInt(LSecondary.Objects[LPosition]), LKey, 'shared-secondary-accession');
        end
        else
        begin
          LSecondary.AddObject(LKey, TObject(PtrInt(I)));
        end;
      end;
    end;
    for I := 0 to High(FTrials) do
    begin
      Inc(FGroupSizes[GroupRoot(I)]);
    end;
    for I := 0 to High(FTrials) do
    begin
      if FGroupSizes[GroupRoot(I)] > 1 then
      begin
        LProvider := FProviders.IndexOf(FTrials[I].Provider);
        Inc(FProviderCounts[LProvider].LinkedRows);
      end;
    end;
  finally
    LSeen.Free;
    LSecondary.Free;
    LPrimary.Free;
  end;
end;

procedure TWhoScreen.WriteOutputs(const AOutput: String);
var
  LInventory: Text;
  LCandidates: Text;
  LBridges: Text;
  LCounts: Text;
  LRow: TTrial;
  LBridge: TBridge;
  LGroup: Integer;
  LGroups: Integer;
  LCandidateRows: Integer;
  I: Integer;
begin
  LGroups := 0;
  LCandidateRows := 0;
  OpenTsv(LInventory, AOutput + 'who-ictrp-inventory.tsv');
  try
    OpenTsv(LCandidates, AOutput + 'who-ictrp-candidates.tsv');
    try
      WriteRow(LInventory, ['trial_id', 'provider', 'group_anchor', 'group_size', 'who_other_records',
        'registered', 'refreshed', 'parkinson_scope', 'priority']);
      WriteRow(LCandidates, ['trial_id', 'provider', 'group_anchor', 'priority', 'parkinson_scope',
        'ingredient_names', 'related_exposures', 'food_terms', 'context_ingredients', 'registered',
        'status', 'study_type', 'title', 'scientific_title', 'condition', 'intervention',
        'primary_outcome', 'secondary_outcome', 'results_status', 'results_date',
        'results_first_publication', 'results_url', 'registry_url']);
      for I := 0 to High(FTrials) do
      begin
        LRow := FTrials[I];
        LGroup := GroupRoot(I);
        Inc(LGroups, Ord(LGroup = I));
        WriteRow(LInventory, [LRow.Id, LRow.Provider, FTrials[LGroup].Id,
          IntToStr(FGroupSizes[LGroup]), LRow.OtherRecords, LRow.Registered, LRow.Refreshed,
          LRow.ParkinsonScope, LRow.Priority]);
        if LRow.Priority <> '' then
        begin
          Inc(LCandidateRows);
          WriteRow(LCandidates, [LRow.Id, LRow.Provider, FTrials[LGroup].Id, LRow.Priority,
            LRow.ParkinsonScope, LRow.Names, LRow.Related, LRow.Broad, LRow.Context, LRow.Registered,
            LRow.Status, LRow.StudyType, LRow.Title, LRow.ScientificTitle, LRow.Condition,
            LRow.Intervention, LRow.PrimaryOutcome, LRow.SecondaryOutcome, LRow.ResultsStatus,
            LRow.ResultsDate, LRow.ResultsPublication, LRow.ResultsUrl, LRow.Url]);
        end;
      end;
    finally
      CloseFile(LCandidates);
    end;
  finally
    CloseFile(LInventory);
  end;
  OpenTsv(LBridges, AOutput + 'who-ictrp-bridges.tsv');
  try
    WriteRow(LBridges, ['trial_id', 'other_trial_id', 'accession', 'basis']);
    for LBridge in FBridges do
    begin
      WriteRow(LBridges, [FTrials[LBridge.Source].Id, FTrials[LBridge.Target].Id, LBridge.Key,
        LBridge.Basis]);
    end;
  finally
    CloseFile(LBridges);
  end;
  OpenTsv(LCounts, AOutput + 'who-ictrp-provider-counts.tsv');
  try
    WriteRow(LCounts, ['who_export_date', 'provider', 'trial_rows', 'candidate_rows',
      'who_other_records_yes', 'rows_in_accession_groups']);
    for I := 0 to FProviders.Count - 1 do
    begin
      WriteRow(LCounts, [FExportDate, FProviders[I], IntToStr(FProviderCounts[I].Rows),
        IntToStr(FProviderCounts[I].Candidates), IntToStr(FProviderCounts[I].MarkedOther),
        IntToStr(FProviderCounts[I].LinkedRows)]);
    end;
  finally
    CloseFile(LCounts);
  end;
  WriteLn('WHO ICTRP processed ', FExportDate, '. Reconciled ', Length(FTrials), ' unique rows, ',
    FProviders.Count, ' providers, ', LGroups, ' accession groups, ', Length(FBridges),
    ' bridge edges, and ', LCandidateRows, ' candidate rows.');
end;

procedure TWhoScreen.Run(const ARoot, AInput, AOutput: String; AExpected: Integer);
begin
  LoadVocabulary(IncludeTrailingPathDelimiter(ARoot));
  ReadExport(AInput, AExpected);
  GroupTrials;
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create WHO screening output directory');
  end;
  WriteOutputs(IncludeTrailingPathDelimiter(AOutput));
end;

var
  LScreen: TWhoScreen;
  LExpected: Integer;
begin
  if (ParamCount <> 4) or not TryStrToInt(ParamStr(4), LExpected) or (LExpected <= 0) then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.whoictrp <experiment> <xml> <build-output> <row-count>');
    Halt(2);
  end;
  try
    LScreen := TWhoScreen.Create;
    try
      LScreen.Run(ParamStr(1), ParamStr(2), ParamStr(3), LExpected);
    finally
      LScreen.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
