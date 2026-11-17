{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentDepth;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.externaldata, foodexperiment.matching,
  foodexperiment.localtext, foodexperiment.archiveidentity
  {$ifdef windows}, Windows{$endif};

const
  ClaimCount = 1000;

type
  TTable = class
  private
    FFile: Text;
    FHeaders: TFields;
    FFields: TFields;
    FPath: String;
    FOpened: Boolean;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    function Next: Boolean;
    function Value(const AName: String): String;
  end;

  TIngredient = record
    CompletedQueries: Integer;
    IncompleteQueries: Integer;
    Retrieved: Int64;
    DistinctRecords: Integer;
    HumanCandidates: Integer;
    ReferenceLeads: Integer;
    RegistryMentions: Integer;
    RegistryInterventions: Integer;
  end;

  TClaim = record
    Category: String;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    Direction: String;
    IngredientIndex: Integer;
    SymptomIndex: Integer;
    FirstVerdict: String;
    FirstClaimSpecific: Boolean;
    LocalPairs: Integer;
    ExpandedLocalPairs: Integer;
    ExpandedLocalFocused: Integer;
    OriginalHits: Int64;
    OriginalReturned: Integer;
    OriginalCapped: Boolean;
    HumanOutcomeCandidates: Integer;
    ClaimQueriesCompleted: Integer;
    ClaimQueryResults: Int64;
    ClaimQueryKeys: Integer;
    ClaimQueryAlternateDispositions: Integer;
    ArchivedTextPairs: Integer;
    ArchivedTextNewFlags: Integer;
    ArchivedTextHumanCandidates: Integer;
    AssessedSources: Integer;
    SupportingSources: Integer;
    OpposingSources: Integer;
    InconclusiveSources: Integer;
    RelatedSources: Integer;
    PendingSources: Integer;
  end;

  TDepth = class
  private
    FNames: TStringList;
    FSymptoms: TStringList;
    FIngredients: array of TIngredient;
    FClaims: array[1..ClaimCount] of TClaim;
    FClaimsByIngredient: array of array of Integer;
    FExposureMatcher: TMatcher;
    FBodyExposureMatcher: TMatcher;
    FExposureFlags: TMatchFlags;
    FOutcomeMatcher: TMatcher;
    FOutcomeFlags: TMatchFlags;
    FRegistryComplete: Boolean;
    FClaimSearchIncluded: Boolean;
    FAcademicRows: Integer;
    procedure LoadBaseline(const ARoot: String);
    procedure LoadExpandedLocal(const ADirectory: String);
    procedure LoadQueries(const ADirectory: String);
    procedure ScreenArticles(const ADirectory, AOutput: String);
    procedure ScreenClaimQueries(const ADirectory, AOutput, ARepo: String);
    procedure SweepArchive(const ARepo, AOutput: String);
    procedure LoadRegistry(const ADirectory: String);
    procedure LoadAssessments(const ARepo, AOutput: String);
    procedure WriteLedgers(const AOutput: String);
    procedure AddExposure(const ATerm: UTF8String; AIndex: Integer);
    procedure LoadExposureForms(const APath: String);
    function IngredientIndex(const AName: String): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, AAcademic, ARegistry, AOutput, AClaimSearch,
      AExpandedLocal: String; AArchiveSweep: Boolean);
  end;

constructor TTable.Create(const APath: String);
var
  LHeader: String;
begin
  inherited Create;
  FPath := APath;
  AssignFile(FFile, APath);
  Reset(FFile);
  SetTextCodePage(FFile, CP_UTF8);
  FOpened := True;
  ReadLn(FFile, LHeader);
  FHeaders := SplitFields(LHeader, #9);
end;

destructor TTable.Destroy;
begin
  if FOpened then
  begin
    CloseFile(FFile);
  end;
  inherited Destroy;
end;

function TTable.Next: Boolean;
var
  LLine: String;
begin
  Result := not Eof(FFile);
  if Result then
  begin
    ReadLn(FFile, LLine);
    FFields := SplitFields(LLine, #9);
    if Length(FFields) <> Length(FHeaders) then
    begin
      raise EConvertError.Create('TSV row width mismatch in ' + FPath);
    end;
  end;
end;

function TTable.Value(const AName: String): String;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FHeaders) do
  begin
    if FHeaders[LIndex] = AName then
    begin
      Exit(FFields[LIndex]);
    end;
  end;
  raise EConvertError.CreateFmt('Missing %s column in %s', [AName, FPath]);
end;

function ClaimNumber(const AId: String): Integer;
begin
  if (Length(AId) <> 4) or not TryStrToInt(AId, Result) or
    (Result < 1) or (Result > ClaimCount) then
  begin
    raise EConvertError.Create('Invalid claim ID ' + AId);
  end;
end;

function CountValue(const AValue: String): Int64;
begin
  if AValue = '' then
  begin
    Exit(0);
  end;
  if not TryStrToInt64(AValue, Result) or (Result < 0) then
  begin
    raise EConvertError.Create('Invalid nonnegative count ' + AValue);
  end;
end;

procedure WriteFields(var AFile: Text; const AValues: array of String);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AValues) do
  begin
    if LIndex > 0 then
    begin
      Write(AFile, #9);
    end;
    Write(AFile, CleanCell(AValues[LIndex]));
  end;
  Write(AFile, #10);
end;

constructor TDepth.Create;
begin
  inherited Create;
  FNames := TStringList.Create;
  FSymptoms := TStringList.Create;
  FExposureMatcher := TMatcher.Create;
  FBodyExposureMatcher := TMatcher.Create;
  FOutcomeMatcher := TMatcher.Create;
end;

destructor TDepth.Destroy;
begin
  FOutcomeMatcher.Free;
  FBodyExposureMatcher.Free;
  FExposureMatcher.Free;
  FSymptoms.Free;
  FNames.Free;
  inherited Destroy;
end;

function TDepth.IngredientIndex(const AName: String): Integer;
begin
  Result := FNames.IndexOf(AName);
  if Result < 0 then
  begin
    raise EConvertError.Create('Unknown frozen ingredient ' + AName);
  end;
end;

procedure TDepth.AddExposure(const ATerm: UTF8String; AIndex: Integer);
begin
  if not SameText(ATerm, 'date') and not SameText(ATerm, 'fig') then
  begin
    FExposureMatcher.Add(ATerm, AIndex);
    FBodyExposureMatcher.Add(ATerm, AIndex);
  end;
end;

procedure TDepth.LoadExposureForms(const APath: String);
var
  LTable: TTable;
  LTerm, LRelation: UTF8String;
  LIndex: Integer;
begin
  LTable := TTable.Create(APath);
  try
    while LTable.Next do
    begin
      LIndex := IngredientIndex(LTable.Value('ingredient')) * 2;
      LRelation := LTable.Value('relation');
      if LRelation = 'related' then
      begin
        Inc(LIndex);
      end
      else if LRelation <> 'name' then
      begin
        raise EConvertError.Create('Unknown exposure relation in ' + APath);
      end;
      for LTerm in SplitFields(LTable.Value('terms'), '|') do
      begin
        AddExposure(LTerm, LIndex);
      end;
    end;
  finally
    LTable.Free;
  end;
end;

procedure AddIndexedFruitNames(AMatcher: TMatcher; ADateIndex, AFigIndex: Integer);
const
  DateNames = 'p dactylifera|dried date|dried dates|whole dates|pitted dates|' +
    'fresh dates|date seed|date seeds|date kernel|date kernels|date pulp|date syrup|' +
    'date juice|date extract|date paste|date powder|date sap|ajwa date|ajwa dates|' +
    'ajwa seed|ajwa seeds|medjool date|medjool dates|zahedi date|zahedi dates|' +
    'barhi dates|deglet nour dates|fed dates|ate dates|eating dates';
  FigNames = 'f carica|raw fig|raw figs|fresh fig|fresh figs|dried fig|dried figs|' +
    'whole figs|edible figs|fig juice|fig extract|fig leaf|fig leaves|fig latex|' +
    'fig paste|fig pulp|fig consumption|eating figs';
var
  LTerm: UTF8String;
begin
  for LTerm in SplitFields(DateNames, '|') do
  begin
    AMatcher.Add(LTerm, ADateIndex);
  end;
  for LTerm in SplitFields(FigNames, '|') do
  begin
    AMatcher.Add(LTerm, AFigIndex);
  end;
end;

procedure TDepth.LoadBaseline(const ARoot: String);
var
  LTable: TTable;
  LTerm: UTF8String;
  LIndex: Integer;
  LClaim: Integer;
  LCount: Integer;
begin
  LTable := TTable.Create(ARoot + 'ingredients.tsv');
  try
    while LTable.Next do
    begin
      LIndex := FNames.Add(LTable.Value('ingredient'));
      AddExposure(FNames[LIndex], LIndex * 2);
      for LTerm in SplitFields(LTable.Value('aliases'), '|') do
      begin
        AddExposure(LTerm, LIndex * 2);
      end;
    end;
  finally
    LTable.Free;
  end;
  SetLength(FIngredients, FNames.Count);
  SetLength(FClaimsByIngredient, FNames.Count);
  SetLength(FExposureFlags, FNames.Count * 2);
  LoadExposureForms(ARoot + 'exposure-expansions.tsv');
  if FileExists(ARoot + 'contextual-exposure-forms.tsv') then
  begin
    LoadExposureForms(ARoot + 'contextual-exposure-forms.tsv');
  end;
  AddIndexedFruitNames(FExposureMatcher, IngredientIndex('date') * 2, IngredientIndex('fig') * 2);
  FExposureMatcher.Prepare;
  LIndex := IngredientIndex('date') * 2;
  FBodyExposureMatcher.Add('dried dates', LIndex);
  FBodyExposureMatcher.Add('ajwa', LIndex);
  FBodyExposureMatcher.Add('medjool', LIndex);
  LIndex := IngredientIndex('fig') * 2;
  FBodyExposureMatcher.Add('raw figs', LIndex);
  FBodyExposureMatcher.Add('fresh figs', LIndex);
  FBodyExposureMatcher.Add('dried figs', LIndex);
  FBodyExposureMatcher.Prepare;
  LTable := TTable.Create(ARoot + 'symptoms.tsv');
  try
    while LTable.Next do
    begin
      LIndex := FSymptoms.Add(LTable.Value('symptom'));
      FOutcomeMatcher.Add(FSymptoms[LIndex], LIndex);
      for LTerm in SplitFields(LTable.Value('aliases'), '|') do
      begin
        FOutcomeMatcher.Add(LTerm, LIndex);
      end;
    end;
  finally
    LTable.Free;
  end;
  FOutcomeMatcher.Prepare;
  SetLength(FOutcomeFlags, FSymptoms.Count);
  LTable := TTable.Create(ARoot + 'freeze.tsv');
  LCount := 0;
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(LTable.Value('id'));
      if FClaims[LClaim].Ingredient <> '' then
      begin
        raise EConvertError.Create('Duplicate frozen claim');
      end;
      Inc(LCount);
      FClaims[LClaim].Category := LTable.Value('category');
      FClaims[LClaim].Ingredient := LTable.Value('ingredient');
      FClaims[LClaim].Preparation := LTable.Value('preparation');
      FClaims[LClaim].Symptom := LTable.Value('symptom');
      FClaims[LClaim].Direction := LTable.Value('direction');
      FClaims[LClaim].FirstVerdict := 'Unknown';
      LIndex := IngredientIndex(FClaims[LClaim].Ingredient);
      FClaims[LClaim].IngredientIndex := LIndex;
      FClaims[LClaim].SymptomIndex := FSymptoms.IndexOf(FClaims[LClaim].Symptom);
      if FClaims[LClaim].SymptomIndex < 0 then
      begin
        raise EConvertError.Create('Unknown frozen symptom ' + FClaims[LClaim].Symptom);
      end;
      FClaimsByIngredient[LIndex] := Concat(FClaimsByIngredient[LIndex], [LClaim]);
    end;
  finally
    LTable.Free;
  end;
  if LCount <> ClaimCount then
  begin
    raise EConvertError.Create('Incomplete frozen statement set');
  end;
  LTable := TTable.Create(ARoot + 'reviewed-claims.tsv');
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(LTable.Value('id'));
      FClaims[LClaim].FirstClaimSpecific := True;
      FClaims[LClaim].FirstVerdict := LTable.Value('verdict');
    end;
  finally
    LTable.Free;
  end;
  LTable := TTable.Create(ARoot + 'claim-coverage.tsv');
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(LTable.Value('id'));
      FClaims[LClaim].LocalPairs := CountValue(LTable.Value('local_pair_hits'));
    end;
  finally
    LTable.Free;
  end;
  LTable := TTable.Create(ARoot + 'queries.tsv');
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(Copy(LTable.Value('query_id'), 1, 4));
      LCount := CountValue(LTable.Value('result_count'));
      Inc(FClaims[LClaim].OriginalHits, LCount);
      Inc(FClaims[LClaim].OriginalReturned, CountValue(LTable.Value('screened_count')));
      FClaims[LClaim].OriginalCapped := FClaims[LClaim].OriginalCapped or (LCount > 20);
    end;
  finally
    LTable.Free;
  end;
end;

procedure TDepth.LoadExpandedLocal(const ADirectory: String);
var
  LTable: TTable;

  procedure CountPairs(const AIngredients, ASymptoms: String; AFocused: Boolean);
  var
    LIngredient: UTF8String;
    LSymptom: UTF8String;
    LIndex: Integer;
    LClaim: Integer;
  begin
    if (AIngredients = '') or (ASymptoms = '') then
    begin
      Exit;
    end;
    FillChar(FOutcomeFlags[0], Length(FOutcomeFlags) * SizeOf(Boolean), 0);
    for LSymptom in SplitFields(ASymptoms, '|') do
    begin
      LIndex := FSymptoms.IndexOf(LSymptom);
      if LIndex < 0 then
      begin
        raise EConvertError.Create('Unrecognized local symptom ' + LSymptom);
      end;
      FOutcomeFlags[LIndex] := True;
    end;
    for LIngredient in SplitFields(AIngredients, '|') do
    begin
      for LClaim in FClaimsByIngredient[IngredientIndex(LIngredient)] do
      begin
        if not FOutcomeFlags[FClaims[LClaim].SymptomIndex] then
        begin
          Continue;
        end;
        if AFocused then
        begin
          Inc(FClaims[LClaim].ExpandedLocalFocused);
        end
        else
        begin
          Inc(FClaims[LClaim].ExpandedLocalPairs);
        end;
      end;
    end;
  end;

begin
  LTable := TTable.Create(ADirectory + 'local-matches.tsv');
  try
    while LTable.Next do
    begin
      CountPairs(LTable.Value('ingredients'), LTable.Value('symptoms'), False);
      CountPairs(LTable.Value('focused_ingredients'), LTable.Value('focused_symptoms'), True);
    end;
  finally
    LTable.Free;
  end;
end;

procedure TDepth.LoadQueries(const ADirectory: String);
var
  LTable: TTable;
  LIndex: Integer;
  LStatus: String;
begin
  LTable := TTable.Create(ADirectory + 'ingredient_queries.tsv');
  try
    while LTable.Next do
    begin
      LIndex := IngredientIndex(LTable.Value('ingredient'));
      LStatus := LTable.Value('status');
      Inc(FIngredients[LIndex].Retrieved, CountValue(LTable.Value('retrieved_count')));
      if SameText(LStatus, 'Completed') or SameText(LStatus, 'Retrieved') then
      begin
        Inc(FIngredients[LIndex].CompletedQueries);
      end
      else
      begin
        Inc(FIngredients[LIndex].IncompleteQueries);
      end;
    end;
  finally
    LTable.Free;
  end;
end;

function AnyTerm(const AText: String; const ATerms: array of String): Boolean;
var
  LTerm: String;
begin
  for LTerm in ATerms do
  begin
    if Pos(LTerm, AText) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function ClinicalTier(const ATitle, AAbstract, APublicationTypes: String): String;
var
  LTitle: String;
  LTypes: String;
  LAbstract: String;
begin
  LTitle := LowerCase(ATitle);
  LTypes := LowerCase(APublicationTypes);
  LAbstract := LowerCase(AAbstract);
  if AnyTerm(LTypes, ['systematic review', 'meta-analysis', 'review']) or
    AnyTerm(LTitle, [' review', 'meta-analysis', 'scoping review']) then
  begin
    Exit('citation trail');
  end;
  if AnyTerm(LTitle, [' protocol', 'study protocol', 'trial registration']) then
  begin
    Exit('protocol or registration');
  end;
  if AnyTerm(LTypes, ['clinical trial', 'observational study', 'comparative study',
    'case reports']) then
  begin
    Exit('human evidence candidate');
  end;
  if AnyTerm(LTitle, [' mice', ' mouse', ' rat ', ' rats', ' zebrafish',
    'drosophila', ' in vitro', 'cell model', 'animal model', 'rodent']) then
  begin
    Exit('animal or laboratory wording');
  end;
  if AnyTerm(LTitle + ' ' + LAbstract, ['patients with parkinson',
    'people with parkinson', 'parkinson disease patients', 'parkinson''s disease patients',
    'participants with parkinson', 'parkinson cohort', 'parkinson''s disease cohort']) and
    AnyTerm(LTitle + ' ' + LAbstract, ['random', 'trial', 'cross-sectional',
    'cohort', 'participants', 'patients', 'case report', 'case-control']) then
  begin
    Exit('human evidence candidate');
  end;
  if AAbstract = '' then
  begin
    Exit('title only, needs access');
  end;
  Result := 'unclassified abstract';
end;

procedure TDepth.ScreenArticles(const ADirectory, AOutput: String);
var
  LTable: TTable;
  LSeen: TStringList;
  LFile: Text;
  LBuffer: array[0..65535] of Byte;
  LIngredient: Integer;
  LClaim: Integer;
  LKey: String;
  LTier: String;
  LTitle: String;
  LAbstract: String;
  LMatched: String;
  LUnique: String;
begin
  LSeen := TStringList.Create;
  LSeen.Sorted := True;
  LTable := TTable.Create(ADirectory + 'ingredient_results.tsv');
  try
    AssignFile(LFile, AOutput + 'academic-screen.tsv');
    SetTextBuf(LFile, LBuffer);
    Rewrite(LFile);
    try
      WriteFields(LFile, ['ingredient', 'source_key', 'title', 'publication_date',
        'triage', 'symptom_terms']);
      while LTable.Next do
      begin
        Inc(FAcademicRows);
        LIngredient := IngredientIndex(LTable.Value('ingredient'));
        LKey := LTable.Value('source_key');
        LUnique := FNames[LIngredient] + #9 + LKey;
        if LSeen.IndexOf(LUnique) >= 0 then
        begin
          Continue;
        end;
        LSeen.Add(LUnique);
        Inc(FIngredients[LIngredient].DistinctRecords);
        LTitle := LTable.Value('title');
        LAbstract := LTable.Value('abstract');
        LTier := ClinicalTier(LTitle, LAbstract, LTable.Value('publication_types'));
        FillChar(FOutcomeFlags[0], Length(FOutcomeFlags) * SizeOf(Boolean), 0);
        FOutcomeMatcher.Match(LTitle + ' ' + LAbstract, FOutcomeFlags);
        LMatched := JoinMatches(FSymptoms, FOutcomeFlags, 0);
        if LTier = 'human evidence candidate' then
        begin
          Inc(FIngredients[LIngredient].HumanCandidates);
          for LClaim in FClaimsByIngredient[LIngredient] do
          begin
            if FOutcomeFlags[FClaims[LClaim].SymptomIndex] then
            begin
              Inc(FClaims[LClaim].HumanOutcomeCandidates);
            end;
          end;
        end
        else if LTier = 'citation trail' then
        begin
          Inc(FIngredients[LIngredient].ReferenceLeads);
        end;
        WriteFields(LFile, [FNames[LIngredient], LKey, LTitle,
          LTable.Value('publication_date'), LTier, LMatched]);
      end;
    finally
      CloseFile(LFile);
    end;
  finally
    LTable.Free;
    LSeen.Free;
  end;
end;

procedure TDepth.ScreenClaimQueries(const ADirectory, AOutput, ARepo: String);
type
  TQueryCounts = record
    Recorded: Boolean;
    Retrieved: Int64;
    Rows: Int64;
    ProviderGap: Int64;
    AlternateDispositions: Integer;
  end;
var
  LCounts: array of TQueryCounts;
  LTable: TTable;
  LSeen: TStringList;
  LFile: Text;
  LLocalFile: Text;
  LLocalOpen: Boolean;
  LIdentityFile: Text;
  LIdentityOpen: Boolean;
  LExpectedIdentity: TArchiveIdentity;
  LArchiveIdentity: TArchiveIdentity;
  LConflict: String;
  LDisposition: String;
  LBuffer: array[0..65535] of Byte;
  LLocalBuffer: array[0..65535] of Byte;
  LLocalIndex: TLocalTextIndex;
  LArticle: TLocalArticle;
  LClaim: Integer;
  LQuery: Integer;
  LIngredient: Integer;
  LId: String;
  LKey: String;
  LTitle: String;
  LAbstract: String;
  LTier: String;
  LPmcId: String;
  LAlternatePath: String;
  LReported: Int64;
  LRetrieved: Int64;
  I: Integer;

  function QueryIndex(const AId: String; out AClaim: Integer): Integer;
  begin
    AClaim := ClaimNumber(Copy(AId, 1, 4));
    if (Length(AId) <> 6) or (AId[5] <> '-') or not (AId[6] in ['1', '2']) then
    begin
      raise EConvertError.Create('Invalid uncapped query ID ' + AId);
    end;
    Result := (AClaim - 1) * 2 + Ord(AId[6]) - Ord('1');
  end;

begin
  SetLength(LCounts, ClaimCount * 2);
  FClaimSearchIncluded := True;
  LTable := TTable.Create(ADirectory + 'ingredient_queries.tsv');
  try
    while LTable.Next do
    begin
      LId := LTable.Value('query_id');
      LQuery := QueryIndex(LId, LClaim);
      if LCounts[LQuery].Recorded or (LTable.Value('ingredient') <> FClaims[LClaim].Ingredient) then
      begin
        raise EConvertError.Create('Duplicate or mismatched uncapped query ' + LId);
      end;
      LCounts[LQuery].Recorded := True;
      LRetrieved := CountValue(LTable.Value('retrieved_count'));
      LCounts[LQuery].Retrieved := LRetrieved;
      Inc(FClaims[LClaim].ClaimQueryResults, LRetrieved);
      if LTable.Value('status') = 'Retrieved' then
      begin
        LReported := CountValue(LTable.Value('hit_count'));
        if LReported <> LRetrieved then
        begin
          raise EConvertError.Create('Incomplete result count for ' + LId);
        end;
        Inc(FClaims[LClaim].ClaimQueriesCompleted);
      end
      else if LTable.Value('status') = 'Partial' then
      begin
        LReported := CountValue(LTable.Value('hit_count'));
        LCounts[LQuery].ProviderGap := LReported - LRetrieved;
      end;
    end;
  finally
    LTable.Free;
  end;

  LAlternatePath := AOutput + 'claim-query-provider-hidden-records.tsv';
  if FileExists(LAlternatePath) then
  begin
    LSeen := TStringList.Create;
    LTable := nil;
    try
      LSeen.Sorted := True;
      LTable := TTable.Create(LAlternatePath);
      while LTable.Next do
      begin
        LId := LTable.Value('query_id');
        LQuery := QueryIndex(LId, LClaim);
        LKey := LTable.Value('provider_key');
        if (LKey = '') or (LTable.Value('primary_disposition') = '') or
          (LTable.Value('primary_source') = '') or
          (LTable.Value('exact_http') <> '200') or
          (LTable.Value('exact_reported') <> '1') or
          (LTable.Value('exact_rows') <> '0') or
          (LSeen.IndexOf(LId + #9 + LKey) >= 0) or
          (LCounts[LQuery].AlternateDispositions >= LCounts[LQuery].ProviderGap) then
        begin
          raise EConvertError.Create('Invalid alternate result disposition for ' + LId + ' ' + LKey);
        end;
        LSeen.Add(LId + #9 + LKey);
        Inc(LCounts[LQuery].AlternateDispositions);
        Inc(FClaims[LClaim].ClaimQueryAlternateDispositions);
      end;
    finally
      LTable.Free;
      LSeen.Free;
    end;
  end;

  LSeen := TStringList.Create;
  LLocalIndex := nil;
  LLocalOpen := False;
  LIdentityOpen := False;
  LTable := nil;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupIgnore;
    if ARepo <> '' then
    begin
      LLocalIndex := TLocalTextIndex.Create(ARepo, FBodyExposureMatcher, FOutcomeMatcher,
        Length(FExposureFlags), Length(FOutcomeFlags));
      AssignFile(LLocalFile, AOutput + 'claim-local-text-screen.tsv');
      SetTextBuf(LLocalFile, LLocalBuffer);
      Rewrite(LLocalFile);
      LLocalOpen := True;
      AssignFile(LIdentityFile, AOutput + 'claim-local-text-identity-discrepancies.tsv');
      Rewrite(LIdentityFile);
      LIdentityOpen := True;
      WriteFields(LIdentityFile, ['id', 'source_key', 'local_reference', 'conflict',
        'overlay_pmcid', 'overlay_pmid', 'overlay_doi', 'archive_pmcid', 'archive_pmid',
        'archive_doi', 'disposition']);
      WriteFields(LLocalFile, ['id', 'source_key', 'pmcid', 'local_reference', 'text_scope',
        'triage', 'abstract_ingredient', 'abstract_related', 'abstract_outcome',
        'text_ingredient', 'text_related', 'text_outcome']);
    end;
    LTable := TTable.Create(ADirectory + 'ingredient_results.tsv');
    AssignFile(LFile, AOutput + 'claim-query-screen.tsv');
    SetTextBuf(LFile, LBuffer);
    Rewrite(LFile);
    try
      WriteFields(LFile, ['id', 'query_id', 'rank', 'source_key', 'title', 'publication_date',
        'triage', 'ingredient_terms', 'related_exposure_terms', 'claim_symptom_terms']);
      while LTable.Next do
      begin
        LId := LTable.Value('query_id');
        LQuery := QueryIndex(LId, LClaim);
        if not LCounts[LQuery].Recorded then
        begin
          Continue;
        end;
        Inc(LCounts[LQuery].Rows);
        if CountValue(LTable.Value('rank')) <> LCounts[LQuery].Rows then
        begin
          raise EConvertError.Create('Unexpected result rank for ' + LId);
        end;
        LKey := LTable.Value('source_key');
        if LSeen.Find(Copy(LId, 1, 4) + #9 + LKey, I) then
        begin
          Continue;
        end;
        LSeen.Add(Copy(LId, 1, 4) + #9 + LKey);
        Inc(FClaims[LClaim].ClaimQueryKeys);
        LTitle := LTable.Value('title');
        LAbstract := LTable.Value('abstract');
        LTier := ClinicalTier(LTitle, LAbstract, LTable.Value('publication_types'));
        LIngredient := FClaims[LClaim].IngredientIndex * 2;
        FillChar(FExposureFlags[0], Length(FExposureFlags) * SizeOf(Boolean), 0);
        FillChar(FOutcomeFlags[0], Length(FOutcomeFlags) * SizeOf(Boolean), 0);
        if (FClaims[LClaim].Ingredient = 'date') or (FClaims[LClaim].Ingredient = 'fig') then
        begin
          FExposureMatcher.Match(LTitle, FExposureFlags);
          FExposureMatcher.Match(LAbstract, FExposureFlags);
        end
        else
        begin
          FExposureMatcher.Match(LTitle + ' ' + LAbstract, FExposureFlags);
        end;
        FOutcomeMatcher.Match(LTitle + ' ' + LAbstract, FOutcomeFlags);
        WriteFields(LFile, [Copy(LId, 1, 4), LId, LTable.Value('rank'), LKey, LTitle,
          LTable.Value('publication_date'), LTier,
          BoolToStr(FExposureFlags[LIngredient], True),
          BoolToStr(FExposureFlags[LIngredient + 1], True),
          BoolToStr(FOutcomeFlags[FClaims[LClaim].SymptomIndex], True)]);
        if LLocalIndex <> nil then
        begin
          LPmcId := LTable.Value('pmcid');
          LArticle := LLocalIndex.Find(LPmcId);
          if LArticle <> nil then
          begin
            LExpectedIdentity.Pmcid := LPmcId;
            LExpectedIdentity.Pmid := LTable.Value('pmid');
            LExpectedIdentity.Doi := LTable.Value('doi');
            LExpectedIdentity.Title := LTitle;
            LArchiveIdentity := LLocalIndex.IdentityOf(LArticle);
            LConflict := ArchiveIdentityConflicts(LExpectedIdentity, LArchiveIdentity);
            if LConflict <> '' then
            begin
              LDisposition := 'held';
              if (LConflict = 'doi') and SameTitledArchive(LExpectedIdentity, LArchiveIdentity) then
              begin
                LDisposition := 'retained_title_and_identifier_match';
              end;
              WriteFields(LIdentityFile, [Copy(LId, 1, 4), LKey, LArticle.Path, LConflict,
                LPmcId, LExpectedIdentity.Pmid, LExpectedIdentity.Doi, LArchiveIdentity.Pmcid,
                LArchiveIdentity.Pmid, LArchiveIdentity.Doi, LDisposition]);
              if LDisposition = 'held' then
              begin
                Continue;
              end;
            end;
            Inc(FClaims[LClaim].ArchivedTextPairs);
            if (LArticle.Exposures[LIngredient] or LArticle.Exposures[LIngredient + 1]) and
              LArticle.Outcomes[FClaims[LClaim].SymptomIndex] and
              (not (FExposureFlags[LIngredient] or FExposureFlags[LIngredient + 1]) or
              not FOutcomeFlags[FClaims[LClaim].SymptomIndex]) then
            begin
              Inc(FClaims[LClaim].ArchivedTextNewFlags);
              if LTier = 'human evidence candidate' then
              begin
                Inc(FClaims[LClaim].ArchivedTextHumanCandidates);
              end;
            end;
            WriteFields(LLocalFile, [Copy(LId, 1, 4), LKey, LPmcId, LArticle.Path,
              LArticle.Scope, LTier, BoolToStr(FExposureFlags[LIngredient], True),
              BoolToStr(FExposureFlags[LIngredient + 1], True),
              BoolToStr(FOutcomeFlags[FClaims[LClaim].SymptomIndex], True),
              BoolToStr(LArticle.Exposures[LIngredient], True),
              BoolToStr(LArticle.Exposures[LIngredient + 1], True),
              BoolToStr(LArticle.Outcomes[FClaims[LClaim].SymptomIndex], True)]);
          end;
        end;
      end;
    finally
      CloseFile(LFile);
    end;
  finally
    if LLocalOpen then
    begin
      CloseFile(LLocalFile);
    end;
    if LIdentityOpen then
    begin
      CloseFile(LIdentityFile);
    end;
    LLocalIndex.Free;
    LTable.Free;
    LSeen.Free;
  end;
  for I := 0 to High(LCounts) do
  begin
    if LCounts[I].Recorded and (LCounts[I].Rows <> LCounts[I].Retrieved) then
    begin
      raise EConvertError.CreateFmt('Uncapped result count mismatch for %.4d-%d',
        [I div 2 + 1, I mod 2 + 1]);
    end;
  end;
end;

procedure PublishArchiveTable(const ATemporary, APath: String);
begin
  {$ifdef windows}
  if not MoveFileExW(PWideChar(UnicodeString(ATemporary)), PWideChar(UnicodeString(APath)),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
  {$else}
  if not RenameFile(ATemporary, APath) then
  {$endif}
  begin
    raise EInOutError.Create('Cannot publish archive table: ' + APath);
  end;
end;

procedure TDepth.SweepArchive(const ARepo, AOutput: String);
type
  TPairCounts = record
    All: Integer;
    OutsideJoin: Integer;
    IngredientInTitle: Integer;
    HumanCandidates: Integer;
  end;
var
  LCounts: array[1..ClaimCount] of TPairCounts;
  LTable: TTable;
  LJoined: TStringList;
  LArchive: TLocalTextIndex;
  LArticle: TLocalArticle;
  LFile: Text;
  LBuffer: array[0..65535] of Byte;
  LArticleIndex: Integer;
  LIngredient: Integer;
  LFlag: Integer;
  LClaim: Integer;
  LOutside: Integer;
  LClaimId: String;
  LTier: String;
  LPairsTemporary: String;
  LCoverageTemporary: String;
begin
  FillChar(LCounts, SizeOf(LCounts), 0);
  LOutside := 0;
  LJoined := TStringList.Create;
  LArchive := nil;
  LPairsTemporary := '';
  LCoverageTemporary := '';
  try
    LJoined.Sorted := True;
    LJoined.Duplicates := dupIgnore;
    LTable := TTable.Create(AOutput + 'claim-local-text-screen.tsv');
    try
      while LTable.Next do
      begin
        LJoined.Add(LTable.Value('id') + #9 + LTable.Value('pmcid'));
      end;
    finally
      LTable.Free;
    end;

    LArchive := TLocalTextIndex.Create(ARepo, FBodyExposureMatcher, FOutcomeMatcher,
      Length(FExposureFlags), Length(FOutcomeFlags));
    LPairsTemporary := SysUtils.GetTempFileName(ExpandFileName(AOutput), 'abp');
    if LPairsTemporary = '' then
    begin
      raise EInOutError.Create('Cannot create temporary archive pair table');
    end;
    AssignFile(LFile, LPairsTemporary);
    SetTextBuf(LFile, LBuffer);
    Rewrite(LFile);
    try
      WriteFields(LFile, ['id', 'category', 'ingredient', 'symptom', 'pmcid',
        'local_reference', 'title', 'text_scope', 'title_subject_triage', 'body_ingredient',
        'body_related', 'title_ingredient', 'title_related']);
      for LArticleIndex := 0 to LArchive.Count - 1 do
      begin
        LArticle := LArchive.ArticleAt(LArticleIndex);
        LTier := ClinicalTier(LArticle.Title, '', LArticle.Subjects);
        if LTier = 'title only, needs access' then
        begin
          LTier := 'unclassified title and subjects';
        end;
        FillChar(FExposureFlags[0], Length(FExposureFlags) * SizeOf(Boolean), 0);
        FBodyExposureMatcher.Match(LArticle.Title, FExposureFlags);
        for LIngredient := 0 to High(FClaimsByIngredient) do
        begin
          LFlag := LIngredient * 2;
          if not (LArticle.Exposures[LFlag] or LArticle.Exposures[LFlag + 1]) then
          begin
            Continue;
          end;
          for LClaim in FClaimsByIngredient[LIngredient] do
          begin
            if not LArticle.Outcomes[FClaims[LClaim].SymptomIndex] then
            begin
              Continue;
            end;
            Inc(LCounts[LClaim].All);
            LClaimId := Format('%.4d', [LClaim]);
            if LJoined.IndexOf(LClaimId + #9 + LArticle.PmcId) >= 0 then
            begin
              Continue;
            end;
            Inc(LOutside);
            Inc(LCounts[LClaim].OutsideJoin);
            if FExposureFlags[LFlag] or FExposureFlags[LFlag + 1] then
            begin
              Inc(LCounts[LClaim].IngredientInTitle);
            end;
            if LTier = 'human evidence candidate' then
            begin
              Inc(LCounts[LClaim].HumanCandidates);
            end;
            WriteFields(LFile, [LClaimId, FClaims[LClaim].Category, FClaims[LClaim].Ingredient,
              FClaims[LClaim].Symptom, LArticle.PmcId, LArticle.Path, LArticle.Title,
              LArticle.Scope, LTier, BoolToStr(LArticle.Exposures[LFlag], True),
              BoolToStr(LArticle.Exposures[LFlag + 1], True),
              BoolToStr(FExposureFlags[LFlag], True), BoolToStr(FExposureFlags[LFlag + 1], True)]);
          end;
        end;
      end;
    finally
      CloseFile(LFile);
    end;

    LCoverageTemporary := SysUtils.GetTempFileName(ExpandFileName(AOutput), 'abc');
    if LCoverageTemporary = '' then
    begin
      raise EInOutError.Create('Cannot create temporary archive coverage table');
    end;
    AssignFile(LFile, LCoverageTemporary);
    Rewrite(LFile);
    try
      WriteFields(LFile, ['id', 'category', 'archive_files_scanned', 'lexical_body_pairs',
        'pairs_outside_query_join', 'title_exposure_outside_join', 'human_candidate_outside_join']);
      for LClaim := 1 to ClaimCount do
      begin
        WriteFields(LFile, [Format('%.4d', [LClaim]), FClaims[LClaim].Category,
          IntToStr(LArchive.Count), IntToStr(LCounts[LClaim].All),
          IntToStr(LCounts[LClaim].OutsideJoin), IntToStr(LCounts[LClaim].IngredientInTitle),
          IntToStr(LCounts[LClaim].HumanCandidates)]);
      end;
    finally
      CloseFile(LFile);
    end;
    PublishArchiveTable(LPairsTemporary, AOutput + 'archive-body-outside-query.tsv');
    PublishArchiveTable(LCoverageTemporary, AOutput + 'archive-body-pair-coverage.tsv');
    WriteLn(LArchive.Count, ' archived PMC files scanned, ', LOutside,
      ' lexical pairs outside the original query join');
  finally
    if LPairsTemporary <> '' then
    begin
      SysUtils.DeleteFile(LPairsTemporary);
    end;
    if LCoverageTemporary <> '' then
    begin
      SysUtils.DeleteFile(LCoverageTemporary);
    end;
    LArchive.Free;
    LJoined.Free;
  end;
end;

procedure TDepth.LoadRegistry(const ADirectory: String);
var
  LTable: TTable;
  LSeen: TStringList;
  LPrimarySeen: TStringList;
  LIngredient: Integer;
  LKey: String;
begin
  LTable := TTable.Create(ADirectory + 'registry-query.tsv');
  try
    FRegistryComplete := LTable.Next and SameText(LTable.Value('status'), 'Completed')
      and (LTable.Value('reported') = LTable.Value('retrieved'));
  finally
    LTable.Free;
  end;
  LSeen := TStringList.Create;
  LPrimarySeen := TStringList.Create;
  LSeen.Sorted := True;
  LPrimarySeen.Sorted := True;
  LTable := TTable.Create(ADirectory + 'registry-exposure-candidates.tsv');
  try
    while LTable.Next do
    begin
      LIngredient := IngredientIndex(LTable.Value('ingredient'));
      LKey := FNames[LIngredient] + #9 + LTable.Value('nct_id');
      if LSeen.IndexOf(LKey) < 0 then
      begin
        LSeen.Add(LKey);
        Inc(FIngredients[LIngredient].RegistryMentions);
      end;
      if (LTable.Value('match_field') = 'intervention') and
        (LPrimarySeen.IndexOf(LKey) < 0) then
      begin
        LPrimarySeen.Add(LKey);
        Inc(FIngredients[LIngredient].RegistryInterventions);
      end;
    end;
  finally
    LTable.Free;
    LPrimarySeen.Free;
    LSeen.Free;
  end;
end;

procedure TDepth.LoadAssessments(const ARepo, AOutput: String);
var
  LTable: TTable;
  LSeen: TStringList;
  LClaim: Integer;
  LKey: String;
  LRole: String;
  LReference: String;
  LAnchor: Integer;
begin
  LSeen := TStringList.Create;
  LSeen.Sorted := True;
  LTable := TTable.Create(AOutput + 'assessments.tsv');
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(LTable.Value('id'));
      LRole := LTable.Value('role');
      LReference := LTable.Value('local_reference');
      LAnchor := Pos('#', LReference);
      if LAnchor > 0 then
      begin
        SetLength(LReference, LAnchor - 1);
      end;
      if (Copy(LReference, 1, 9) <> 'research/') or (Pos('..', LReference) > 0) or
        not FileExists(ARepo + LReference) then
      begin
        raise EConvertError.Create('Missing local research reference ' + LReference);
      end;
      if (LTable.Value('study') = '') or (LTable.Value('fit') = '') or
        (LTable.Value('assessment') = '') then
      begin
        raise EConvertError.Create('Incomplete assessment for ' + LTable.Value('id'));
      end;
      LKey := LTable.Value('id') + #9 + LTable.Value('study');
      if LSeen.IndexOf(LKey) >= 0 then
      begin
        raise EConvertError.Create('Repeated study for one claim ' + LKey);
      end;
      LSeen.Add(LKey);
      Inc(FClaims[LClaim].AssessedSources);
      if LRole = 'supports' then
      begin
        Inc(FClaims[LClaim].SupportingSources);
      end
      else if LRole = 'opposes' then
      begin
        Inc(FClaims[LClaim].OpposingSources);
      end
      else if LRole = 'inconclusive' then
      begin
        Inc(FClaims[LClaim].InconclusiveSources);
      end
      else if LRole = 'related' then
      begin
        Inc(FClaims[LClaim].RelatedSources);
      end
      else if LRole = 'pending' then
      begin
        Inc(FClaims[LClaim].PendingSources);
      end
      else
      begin
        raise EConvertError.Create('Unknown evidence role ' + LRole);
      end;
    end;
  finally
    LTable.Free;
    LSeen.Free;
  end;
end;

procedure TDepth.WriteLedgers(const AOutput: String);
var
  LFile: Text;
  LIndex: Integer;
  LClaim: Integer;
  LState: String;
  LRegistry: String;
begin
  if FRegistryComplete then
  begin
    LRegistry := 'completed';
  end
  else
  begin
    LRegistry := 'incomplete';
  end;
  AssignFile(LFile, AOutput + 'ingredient-coverage.tsv');
  Rewrite(LFile);
  try
    WriteFields(LFile, ['ingredient', 'academic_queries_completed', 'academic_queries_open',
      'academic_appearances', 'unique_academic_keys', 'human_candidates', 'citation_trails',
      'registry_mentions', 'registry_interventions', 'registry_scan']);
    for LIndex := 0 to FNames.Count - 1 do
    begin
      WriteFields(LFile, [FNames[LIndex], IntToStr(FIngredients[LIndex].CompletedQueries),
        IntToStr(FIngredients[LIndex].IncompleteQueries), IntToStr(FIngredients[LIndex].Retrieved),
        IntToStr(FIngredients[LIndex].DistinctRecords), IntToStr(FIngredients[LIndex].HumanCandidates),
        IntToStr(FIngredients[LIndex].ReferenceLeads), IntToStr(FIngredients[LIndex].RegistryMentions),
        IntToStr(FIngredients[LIndex].RegistryInterventions), LRegistry]);
    end;
  finally
    CloseFile(LFile);
  end;
  AssignFile(LFile, AOutput + 'claim-depth.tsv');
  Rewrite(LFile);
  try
    WriteFields(LFile, ['id', 'category', 'ingredient', 'preparation', 'symptom', 'working_direction',
      'first_pass_verdict', 'first_pass_claim_specific', 'original_hit_appearances',
      'original_rows_retrieved', 'original_any_capped', 'local_lexical_pairs',
      'expanded_local_pairs', 'expanded_local_focused_pairs',
      'uncapped_claim_queries_completed', 'uncapped_claim_query_rows', 'uncapped_claim_query_keys',
      'claim_query_appearances_screened_by_alternate_source',
      'archived_text_pairs', 'archived_text_new_flags', 'archived_text_human_candidates',
      'ingredient_academic_keys', 'human_outcome_term_candidates', 'registry_interventions',
      'studies_assessed_in_followup', 'supports', 'opposes', 'inconclusive', 'related', 'pending',
      'review_state']);
    for LClaim := 1 to ClaimCount do
    begin
      LIndex := FClaims[LClaim].IngredientIndex;
      LState := 'search ongoing, direct evidence unresolved';
      if (FIngredients[LIndex].CompletedQueries = 0) or
        (FIngredients[LIndex].IncompleteQueries > 0) or not FRegistryComplete then
      begin
        LState := 'open retrieval gap';
      end
      else if FClaimSearchIncluded and (FClaims[LClaim].ClaimQueriesCompleted < 2) then
      begin
        LState := 'open claim query retrieval';
      end
      else if FClaims[LClaim].AssessedSources > 0 then
      begin
        LState := 'study-level assessment recorded, citation trails open';
      end
      else if (FClaims[LClaim].HumanOutcomeCandidates > 0) or
        (FIngredients[LIndex].RegistryInterventions > 0) then
      begin
        LState := 'open clinical candidates';
      end;
      WriteFields(LFile, [Format('%.4d', [LClaim]), FClaims[LClaim].Category,
        FClaims[LClaim].Ingredient, FClaims[LClaim].Preparation, FClaims[LClaim].Symptom,
        FClaims[LClaim].Direction, FClaims[LClaim].FirstVerdict,
        BoolToStr(FClaims[LClaim].FirstClaimSpecific, True), IntToStr(FClaims[LClaim].OriginalHits),
        IntToStr(FClaims[LClaim].OriginalReturned), BoolToStr(FClaims[LClaim].OriginalCapped, True),
        IntToStr(FClaims[LClaim].LocalPairs), IntToStr(FClaims[LClaim].ExpandedLocalPairs),
        IntToStr(FClaims[LClaim].ExpandedLocalFocused), IntToStr(FClaims[LClaim].ClaimQueriesCompleted),
        IntToStr(FClaims[LClaim].ClaimQueryResults), IntToStr(FClaims[LClaim].ClaimQueryKeys),
        IntToStr(FClaims[LClaim].ClaimQueryAlternateDispositions),
        IntToStr(FClaims[LClaim].ArchivedTextPairs), IntToStr(FClaims[LClaim].ArchivedTextNewFlags),
        IntToStr(FClaims[LClaim].ArchivedTextHumanCandidates),
        IntToStr(FIngredients[LIndex].DistinctRecords),
        IntToStr(FClaims[LClaim].HumanOutcomeCandidates),
        IntToStr(FIngredients[LIndex].RegistryInterventions),
        IntToStr(FClaims[LClaim].AssessedSources), IntToStr(FClaims[LClaim].SupportingSources),
        IntToStr(FClaims[LClaim].OpposingSources), IntToStr(FClaims[LClaim].InconclusiveSources),
        IntToStr(FClaims[LClaim].RelatedSources), IntToStr(FClaims[LClaim].PendingSources), LState]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TDepth.Run(const ARoot, AAcademic, ARegistry, AOutput, AClaimSearch,
  AExpandedLocal: String; AArchiveSweep: Boolean);
var
  LOutput: String;
  LExperiment: String;
  LRepo: String;
begin
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create follow-up output folder');
  end;
  LOutput := IncludeTrailingPathDelimiter(AOutput);
  LExperiment := ExcludeTrailingPathDelimiter(ExpandFileName(ARoot));
  LoadBaseline(IncludeTrailingPathDelimiter(LExperiment));
  LoadAssessments(IncludeTrailingPathDelimiter(ExtractFileDir(ExtractFileDir(LExperiment))),
    LOutput);
  if AExpandedLocal <> '' then
  begin
    LoadExpandedLocal(IncludeTrailingPathDelimiter(AExpandedLocal));
  end;
  LoadQueries(IncludeTrailingPathDelimiter(AAcademic));
  ScreenArticles(IncludeTrailingPathDelimiter(AAcademic), LOutput);
  if AClaimSearch <> '' then
  begin
    LRepo := '';
    if AExpandedLocal <> '' then
    begin
      LRepo := ExtractFileDir(ExtractFileDir(LExperiment));
    end;
    ScreenClaimQueries(IncludeTrailingPathDelimiter(AClaimSearch), LOutput, LRepo);
    if AArchiveSweep then
    begin
      SweepArchive(LRepo, LOutput);
    end;
  end;
  LoadRegistry(IncludeTrailingPathDelimiter(ARegistry));
  WriteLedgers(LOutput);
  WriteLn(ClaimCount, ' frozen claims joined to ', FAcademicRows, ' academic appearances');
end;

var
  GDepth: TDepth;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if not (ParamCount in [4, 5, 6, 7]) or
      ((ParamCount = 7) and ((ParamStr(7) <> 'archive-sweep') or
      (ParamStr(5) = '') or (ParamStr(6) = ''))) then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.depth <experiment> <academic> <registry> <output> ' +
        '[claim-search [local-expanded [archive-sweep]]]');
    end;
    GDepth := TDepth.Create;
    try
      GDepth.Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6),
        ParamCount = 7);
    finally
      GDepth.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
