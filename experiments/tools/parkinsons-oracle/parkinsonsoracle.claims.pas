{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.claims;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses Classes, SysUtils, Generics.Collections, fpjson;

type
  TClaimQuery = record
    Symptom: String;
    Ingredient: String;
    Preparation: String;
    Direction: String;
    Trend: String;
    Scope: String;
    Verdict: String;
    Round: Integer;
    Offset: Integer;
    Limit: Integer;
  end;

  TClaim = class
  public
    Round: Integer;
    Id: String;
    Category: String;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    Direction: String;
    Statement: String;
    Verdict: String;
    Confidence: Integer;
    Rationale: String;
    References: TJSONArray;
    Evidence: TJSONArray;
    AssessedRows: Integer;
    PendingRows: Integer;
    OriginalPairs: Integer;
    QueuedPairs: Integer;
    constructor Create;
    destructor Destroy; override;
    function IsDirectional: Boolean;
    function View(ADetailed: Boolean): TJSONObject;
  end;

  TClaimIndex = class
  private
    FRoot: String;
    FRevision: String;
    FClaims: TObjectList<TClaim>;
    FIdentities: TDictionary<String, TClaim>;
    FBySymptom: TObjectDictionary<String, TList<TClaim>>;
    FByIngredient: TObjectDictionary<String, TList<TClaim>>;
    FSymptomAliases: TDictionary<String, String>;
    FIngredientAliases: TDictionary<String, String>;
    FSourceRows: Integer;
    FDirectional: Integer;
    FUnknown: Integer;
    function Git(const AArguments: array of String): String;
    function Blob(const APath: String): String;
    procedure LoadRound(ARound: Integer);
  public
    constructor Create(const ARepoRoot: String);
    destructor Destroy; override;
    function IsCurrent: Boolean;
    function Status: TJSONObject;
    function Query(const AQuery: TClaimQuery): TJSONObject;
    function Claim(ARound: Integer; const AId: String): TJSONObject;
    function FilterOptions: TJSONObject;
    function StaticModel(const ARepository: String): TJSONObject;
  end;

implementation

uses Process, StrUtils, FPSHA256, foodexperiment.externaldata, parkinsonsoracle.trend,
  wfc;

const
  CBase = 'experiments/1000_see_what_sticks_food';
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CVerdictHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9'search_record'#9 +
    'local_verdict';
  CEvidenceHeader = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment';
  CCoverageHeader = 'id'#9'category'#9'ingredient'#9'overlay_pairs'#9'joined_archive'#9 +
    'no_exact_review_imported'#9'pending_or_access_only'#9'title_index_reviewed'#9 +
    'abstract_context_reviewed'#9'exact_assessment_basis_unspecified'#9 +
    'body_or_primary_context_reviewed'#9'queue_priority_1'#9'queue_priority_2'#9 +
    'queue_priority_3'#9'queue_priority_4'#9'queue_priority_5'#9'queue_priority_6';

function Key(ARound: Integer; const AId: String): String;
begin
  Result := IntToStr(ARound) + ':' + AId;
end;

function Normalize(const AText: String): String;
begin
  Result := LowerCase(Trim(AText));
end;

function LookupAlias(const AText: String; AAliases: TDictionary<String, String>): String;
var
  LCanonical: String;
begin
  Result := Normalize(AText);
  if AAliases.TryGetValue(Result, LCanonical) then
  begin
    if LCanonical = '' then
      raise EConvertError.CreateFmt('Ambiguous input "%s". Use the canonical wording.', [AText]);
    Result := LCanonical;
  end;
end;

procedure AddAlias(ATarget: TDictionary<String, String>; const AAlias, ACanonical: String);
var
  LKey: String;
  LPrior: String;
begin
  LKey := Normalize(AAlias);
  if LKey = '' then
    Exit;
  if ATarget.TryGetValue(LKey, LPrior) then
  begin
    if LPrior <> ACanonical then
      ATarget[LKey] := '';
  end
  else
    ATarget.Add(LKey, ACanonical);
end;

procedure AddPosting(AIndex: TObjectDictionary<String, TList<TClaim>>;
  const AKey: String; AClaim: TClaim);
var
  LList: TList<TClaim>;
begin
  if not AIndex.TryGetValue(AKey, LList) then
  begin
    LList := TList<TClaim>.Create;
    AIndex.Add(AKey, LList);
  end;
  LList.Add(AClaim);
end;

procedure ReadTable(ALines: TStrings; const AData, AHeader: String);
begin
  ALines.Text := AData;
  if (ALines.Count = 0) or (ALines[0] <> AHeader) then
    raise EConvertError.Create('Unexpected published table schema: ' + AHeader);
end;

function HashText(const AData: String): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(AData);
  try
    TSHA256.StreamHexa(LStream, Result);
    Result := LowerCase(Result);
  finally
    LStream.Free;
  end;
end;

constructor TClaim.Create;
begin
  inherited Create;
  Confidence := -1;
  OriginalPairs := -1;
  QueuedPairs := -1;
  Verdict := 'Unreviewed';
  References := TJSONArray.Create;
  Evidence := TJSONArray.Create;
end;

destructor TClaim.Destroy;
begin
  Evidence.Free;
  References.Free;
  inherited Destroy;
end;

function TClaim.IsDirectional: Boolean;
begin
  Result := IndexStr(Verdict, ['True', 'False', 'Maybe True', 'Maybe False']) >= 0;
end;

function TClaim.View(ADetailed: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create([
    'round', Round, 'claim_id', Id, 'category', Category, 'ingredient', Ingredient,
    'preparation', Preparation, 'symptom', Symptom, 'hypothesis_direction', Direction,
    'verdict', Verdict, 'assessment_rows', AssessedRows + PendingRows,
    'nonpending_assessments', AssessedRows, 'pending_assessments', PendingRows]);
  if Confidence >= 0 then
    Result.Add('confidence', Confidence);
  if QueuedPairs >= 0 then
  begin
    Result.Add('original_europe_pmc_pairs', OriginalPairs);
    Result.Add('queued_original_pairs', QueuedPairs);
  end;
  Result.Add('statement', Statement);
  if Rationale <> '' then
    Result.Add('rationale', Rationale);
  if ADetailed then
  begin
    Result.Add('local_references', References.Clone);
    Result.Add('assessments', Evidence.Clone);
  end
  else if References.Count > 0 then
    Result.Add('first_local_reference', References.Strings[0]);
end;

constructor TClaimIndex.Create(const ARepoRoot: String);
var
  LRound: Integer;
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARepoRoot));
  FClaims := TObjectList<TClaim>.Create(True);
  FIdentities := TDictionary<String, TClaim>.Create;
  FBySymptom := TObjectDictionary<String, TList<TClaim>>.Create([doOwnsValues]);
  FByIngredient := TObjectDictionary<String, TList<TClaim>>.Create([doOwnsValues]);
  FSymptomAliases := TDictionary<String, String>.Create;
  FIngredientAliases := TDictionary<String, String>.Create;
  FRevision := Trim(Git(['rev-parse', '--verify', 'HEAD']));
  for LRound := 1 to 7 do
    LoadRound(LRound);
  AddAlias(FSymptomAliases, 'tremor', 'rest tremor severity');
  AddAlias(FSymptomAliases, 'tremors', 'rest tremor severity');
  AddAlias(FSymptomAliases, 'attention', 'attention impairment');
end;

destructor TClaimIndex.Destroy;
begin
  FIngredientAliases.Free;
  FSymptomAliases.Free;
  FByIngredient.Free;
  FBySymptom.Free;
  FIdentities.Free;
  FClaims.Free;
  inherited Destroy;
end;

function TClaimIndex.Git(const AArguments: array of String): String;
begin
  if not RunCommandIndir(FRoot, 'git', AArguments, Result, [], swoHide) then
    raise EInOutError.CreateFmt('Unable to read the published experiment in %s.', [FRoot]);
end;

function TClaimIndex.Blob(const APath: String): String;
begin
  Result := Git(['show', FRevision + ':' + APath]);
end;

procedure TClaimIndex.LoadRound(ARound: Integer);
var
  LExperiment: String;
  LFiles: String;
  LData: String;
  LHash: String;
  LLines: TStringList;
  LFields: TFields;
  LClaim: TClaim;
  LIndex: Integer;
  LField: String;
  LThresholdValid: Boolean;
  LCanonical: String;
  LRoundClaims: Integer;
begin
  LExperiment := CBase;
  if ARound > 1 then
    LExperiment := LExperiment + '_round_' + IntToStr(ARound);
  LFiles := Git(['ls-tree', '-r', '--name-only', FRevision, '--',
    LExperiment + '/verdicts.tsv', LExperiment + '/followup/assessments.tsv',
    LExperiment + '/followup/context-coverage/coverage-by-claim.tsv']);
  LData := Blob(LExperiment + '/freeze.tsv');
  LHash := Trim(Blob(LExperiment + '/freeze.sha256'));
  if HashText(LData) <> LHash then
    raise EConvertError.CreateFmt('Frozen claim hash mismatch in Round %d.', [ARound]);
  LLines := TStringList.Create;
  try
    ReadTable(LLines, Blob(LExperiment + '/symptoms.tsv'), 'symptom'#9'aliases');
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      LCanonical := Normalize(LFields[0]);
      AddAlias(FSymptomAliases, LCanonical, LCanonical);
      for LField in SplitFields(LFields[1], '|') do
        AddAlias(FSymptomAliases, LField, LCanonical);
    end;
    ReadTable(LLines, Blob(LExperiment + '/ingredients.tsv'),
      'category'#9'ingredient'#9'forms'#9'aliases');
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      if not (Length(LFields) in [3, 4]) then
      begin
        raise EConvertError.CreateFmt('Malformed ingredient row %d in Round %d.',
          [LIndex + 1, ARound]);
      end;
      LCanonical := Normalize(LFields[1]);
      AddAlias(FIngredientAliases, LCanonical, LCanonical);
      // A legacy row may omit the empty trailing alias field.
      if Length(LFields) = 4 then
      begin
        for LField in SplitFields(LFields[3], '|') do
        begin
          AddAlias(FIngredientAliases, LField, LCanonical);
        end;
      end;
    end;

    ReadTable(LLines, LData, CFreezeHeader);
    LRoundClaims := LLines.Count - 1;
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      if Length(LFields) <> 7 then
        raise EConvertError.CreateFmt('Malformed frozen record in Round %d.', [ARound]);
      LClaim := TClaim.Create;
      FClaims.Add(LClaim);
      LClaim.Round := ARound;
      LClaim.Id := LFields[0];
      LClaim.Category := LFields[1];
      LClaim.Ingredient := LFields[2];
      LClaim.Preparation := LFields[3];
      LClaim.Symptom := LFields[4];
      LClaim.Direction := LFields[5];
      LClaim.Statement := LFields[6];
      FIdentities.Add(Key(ARound, LClaim.Id), LClaim);
      AddPosting(FBySymptom, Normalize(LClaim.Symptom), LClaim);
      AddPosting(FByIngredient, Normalize(LClaim.Ingredient), LClaim);
    end;

    if Pos(LExperiment + '/verdicts.tsv', LFiles) > 0 then
    begin
      ReadTable(LLines, Blob(LExperiment + '/verdicts.tsv'), CVerdictHeader);
      if LLines.Count - 1 <> LRoundClaims then
        raise EConvertError.Create('Published verdicts do not cover the frozen round.');
      for LIndex := 1 to LLines.Count - 1 do
      begin
        LFields := SplitFields(LLines[LIndex], #9);
        if Length(LFields) <> 7 then
          raise EConvertError.Create('Malformed published verdict.');
        LClaim := FIdentities[Key(ARound, LFields[0])];
        if LClaim.Confidence >= 0 then
          raise EConvertError.Create('Duplicate published verdict: ' + LClaim.Id);
        LClaim.Verdict := LFields[1];
        LClaim.Confidence := StrToInt(LFields[2]);
        LClaim.Rationale := LFields[3];
        LThresholdValid := False;
        case IndexStr(LClaim.Verdict, ['Unknown', 'Maybe True', 'Maybe False', 'True', 'False']) of
          0: LThresholdValid := LClaim.Confidence = 50;
          1, 2: LThresholdValid := (LClaim.Confidence > 50) and (LClaim.Confidence < 60);
          3, 4: LThresholdValid := (LClaim.Confidence >= 60) and (LClaim.Confidence <= 100);
        end;
        for LField in SplitFields(LFields[4], '|') do
          if LField <> '' then
            LClaim.References.Add(LField);
        if not LThresholdValid or (LClaim.IsDirectional and (LClaim.References.Count = 0)) then
          raise EConvertError.Create('Invalid published verdict: ' + LClaim.Id);
        if LClaim.IsDirectional then
          Inc(FDirectional)
        else
          Inc(FUnknown);
      end;
    end;
    if Pos(LExperiment + '/followup/assessments.tsv', LFiles) > 0 then
    begin
      ReadTable(LLines, Blob(LExperiment + '/followup/assessments.tsv'), CEvidenceHeader);
      for LIndex := 1 to LLines.Count - 1 do
      begin
        LFields := SplitFields(LLines[LIndex], #9);
        if Length(LFields) <> 6 then
          raise EConvertError.Create('Malformed published study assessment.');
        LClaim := FIdentities[Key(ARound, LFields[0])];
        LClaim.Evidence.Add(TJSONObject.Create(['study', LFields[1], 'role', LFields[2],
          'fit', LFields[3], 'local_reference', LFields[4], 'assessment', LFields[5]]));
        Inc(FSourceRows);
        if LFields[2] = 'pending' then
          Inc(LClaim.PendingRows)
        else
          Inc(LClaim.AssessedRows);
      end;
    end;
    if Pos(LExperiment + '/followup/context-coverage/coverage-by-claim.tsv', LFiles) > 0 then
    begin
      ReadTable(LLines, Blob(LExperiment + '/followup/context-coverage/coverage-by-claim.tsv'),
        CCoverageHeader);
      if LLines.Count - 1 <> LRoundClaims then
        raise EConvertError.Create('Published coverage does not cover the frozen round.');
      for LIndex := 1 to LLines.Count - 1 do
      begin
        LFields := SplitFields(LLines[LIndex], #9);
        if Length(LFields) <> 17 then
          raise EConvertError.Create('Malformed published coverage row.');
        LClaim := FIdentities[Key(ARound, LFields[0])];
        if LClaim.OriginalPairs >= 0 then
          raise EConvertError.Create('Duplicate published coverage row: ' + LClaim.Id);
        LClaim.OriginalPairs := StrToInt(LFields[3]);
        LClaim.QueuedPairs := 0;
        for LField in Copy(LFields, 11, 6) do
          Inc(LClaim.QueuedPairs, StrToInt(LField));
      end;
    end;
  finally
    LLines.Free;
  end;
end;

function TClaimIndex.IsCurrent: Boolean;
begin
  Result := Trim(Git(['rev-parse', '--verify', 'HEAD'])) = FRevision;
end;

function TClaimIndex.Status: TJSONObject;
begin
  Result := TJSONObject.Create(['revision', FRevision, 'frozen_claims', FClaims.Count,
    'directional_verdicts', FDirectional, 'unknown_verdicts', FUnknown,
    'unreviewed_claims', FClaims.Count - FDirectional - FUnknown, 'assessment_rows', FSourceRows]);
end;

function TClaimIndex.Claim(ARound: Integer; const AId: String): TJSONObject;
var
  LClaim: TClaim;
begin
  if not FIdentities.TryGetValue(Key(ARound, AId), LClaim) then
    Exit(TJSONObject.Create(['revision', FRevision, 'found', False]));
  Result := LClaim.View(True);
  Result.Add('revision', FRevision);
  Result.Add('found', True);
end;

function SortedValues: TStringList;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := True;
  Result.UseLocale := False;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
end;

function StringOptions(AValues: TStrings): TJSONArray;
var
  LValue: String;
begin
  Result := TJSONArray.Create;
  try
    for LValue in AValues do
    begin
      Result.Add(LValue);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function AliasesFor(const AKey: String; AAliases: TDictionary<String, String>): TJSONArray;
var
  LEntry: TPair<String, String>;
  LValues: TStringList;
begin
  LValues := SortedValues;
  try
    for LEntry in AAliases do
    begin
      // An empty target marks an ambiguous alias. The canonical value is separate.
      if (LEntry.Value = AKey) and (LEntry.Key <> AKey) then
      begin
        LValues.Add(LEntry.Key);
      end;
    end;
    Result := StringOptions(LValues);
  finally
    LValues.Free;
  end;
end;

function TClaimIndex.FilterOptions: TJSONObject;
var
  LKeys: TStringList;
  LIngredientPreparations: TStringList;
  LAllPreparations: TStringList;
  LSymptoms: TJSONArray;
  LIngredients: TJSONArray;
  LPreparations: TJSONArray;
  LOption: TJSONObject;
  LClaims: TList<TClaim>;
  LClaim: TClaim;
  LKey: String;
  LPreparation: String;
begin
  LKeys := nil;
  LIngredientPreparations := nil;
  LAllPreparations := nil;
  try
    LKeys := SortedValues;
    LIngredientPreparations := SortedValues;
    LAllPreparations := SortedValues;
    Result := TJSONObject.Create;
    try
      LSymptoms := TJSONArray.Create;
      Result.Add('symptoms', LSymptoms);
      for LKey in FBySymptom.Keys do
      begin
        LKeys.Add(LKey);
      end;
      for LKey in LKeys do
      begin
        LOption := TJSONObject.Create(['value', FBySymptom[LKey][0].Symptom]);
        LSymptoms.Add(LOption);
        LOption.Add('aliases', AliasesFor(LKey, FSymptomAliases));
      end;

      LIngredients := TJSONArray.Create;
      Result.Add('ingredients', LIngredients);
      LKeys.Clear;
      for LKey in FByIngredient.Keys do
      begin
        LKeys.Add(LKey);
      end;
      for LKey in LKeys do
      begin
        LClaims := FByIngredient[LKey];
        LIngredientPreparations.Clear;
        for LClaim in LClaims do
        begin
          LIngredientPreparations.Add(LClaim.Preparation);
          LAllPreparations.Add(LClaim.Preparation);
        end;
        LOption := TJSONObject.Create(['value', LClaims[0].Ingredient]);
        LIngredients.Add(LOption);
        LOption.Add('aliases', AliasesFor(LKey, FIngredientAliases));
        LOption.Add('preparations', StringOptions(LIngredientPreparations));
      end;

      LPreparations := TJSONArray.Create;
      Result.Add('preparations', LPreparations);
      for LPreparation in LAllPreparations do
      begin
        LPreparations.Add(TJSONObject.Create(['value', LPreparation]));
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LAllPreparations.Free;
    LIngredientPreparations.Free;
    LKeys.Free;
  end;
end;

function EvidenceAllowed(AClaim: TClaim; const AQuery: TClaimQuery): Boolean;
begin
  Result := ((AQuery.Verdict = '') or SameText(AQuery.Verdict, AClaim.Verdict)) and
    ((AQuery.Trend = '') or (ClaimTrend(AClaim.Verdict, AClaim.Direction) = AQuery.Trend));
  case IndexStr(AQuery.Scope, ['directional', 'assessed', 'frozen']) of
    0: Result := Result and AClaim.IsDirectional and (AClaim.AssessedRows > 0);
    1: Result := Result and (AClaim.AssessedRows > 0);
  end;
end;

type
  TQueryResolution = record
    Selected: Integer;
    IdentityExcluded: Integer;
    PremiseExcluded: Integer;
    EvidenceExcluded: Integer;
    Options: TJSONArray;
  end;

function ResolveRows(ACandidates: TList<TClaim>; const AQuery: TClaimQuery): TQueryResolution;
var
  LGraph: TGraph;
  LReport: TGraphSolveReport;
  LIndex: Integer;
  LClaim: TClaim;
  LDecision: Integer;
begin
  Result := Default(TQueryResolution);
  Result.Options := TJSONArray.Create;
  try
    if ACandidates.Count > 0 then
    begin
      LGraph := TGraph.Create;
      try
        LGraph.Seed := 0;
        LGraph.Reshape(ACandidates.Count, 1, 1);
        LGraph.WrapNeighbors := False;
        LGraph.CurrentPass := 'identity';
        LGraph.PassMode := gpmOverlay;
        LGraph.AddValue('match');
        LGraph.AddValue('other');
        for LIndex := 0 to ACandidates.Count - 1 do
        begin
          LClaim := ACandidates[LIndex];
          if ((AQuery.Symptom = '') or SameText(AQuery.Symptom, LClaim.Symptom)) and
            ((AQuery.Ingredient = '') or SameText(AQuery.Ingredient, LClaim.Ingredient)) and
            ((AQuery.Preparation = '') or SameText(AQuery.Preparation, LClaim.Preparation)) and
            ((AQuery.Round = 0) or (AQuery.Round = LClaim.Round)) then
            LGraph.Entry[LIndex, 0, 0].Value := 'match'
          else
            LGraph.Entry[LIndex, 0, 0].Value := 'other';
        end;
        LGraph.SwitchToPass('premise');
        LGraph.PassMode := gpmOverlay;
        LGraph.AddValue('match');
        LGraph.AddValue('other');
        for LIndex := 0 to ACandidates.Count - 1 do
          if (AQuery.Direction = '') or (AQuery.Direction = ACandidates[LIndex].Direction) then
            LGraph.Entry[LIndex, 0, 0].Value := 'match'
          else
            LGraph.Entry[LIndex, 0, 0].Value := 'other';
        LGraph.SwitchToPass('evidence');
        LGraph.PassMode := gpmOverlay;
        LGraph.AddValue('eligible');
        LGraph.AddValue('ineligible');
        for LIndex := 0 to ACandidates.Count - 1 do
          if EvidenceAllowed(ACandidates[LIndex], AQuery) then
            LGraph.Entry[LIndex, 0, 0].Value := 'eligible'
          else
            LGraph.Entry[LIndex, 0, 0].Value := 'ineligible';
        LGraph.SwitchToPass('decision', LDecision);
        LGraph.PassMode := gpmOverlay;

        // These branches are disjoint. Each row has one valid decision, independent of seed.
        LGraph.AddValue('include').RequireFromPass('identity', 'match')
          .RequireFromPass('premise', 'match').RequireFromPass('evidence', 'eligible');
        LGraph.AddValue('identity_excluded').RequireFromPass('identity', 'other');
        LGraph.AddValue('premise_excluded').RequireFromPass('identity', 'match')
          .RequireFromPass('premise', 'other');
        LGraph.AddValue('evidence_excluded').RequireFromPass('identity', 'match')
          .RequireFromPass('premise', 'match').RequireFromPass('evidence', 'ineligible');
        if not LGraph.TrySolve(DefaultGraphSolveOptions, LReport) then
          raise EConvertError.CreateFmt('Constraint graph failed at pass %d.', [LReport.FailedPassIndex]);
        for LIndex := 0 to ACandidates.Count - 1 do
          case IndexStr(LGraph.PassGraph[LDecision].Entry[LIndex, 0, 0].Value,
            ['include', 'identity_excluded', 'premise_excluded', 'evidence_excluded']) of
            0:
              begin
                if (Result.Selected >= AQuery.Offset) and
                  (Result.Options.Count < AQuery.Limit) then
                  Result.Options.Add(ACandidates[LIndex].View(False));
                Inc(Result.Selected);
              end;
            1: Inc(Result.IdentityExcluded);
            2: Inc(Result.PremiseExcluded);
            3: Inc(Result.EvidenceExcluded);
          else
            raise EConvertError.Create('Constraint graph returned an unknown decision.');
          end;
      finally
        LGraph.Free;
      end;
    end;
  except
    Result.Options.Free;
    raise;
  end;
end;

function TClaimIndex.Query(const AQuery: TClaimQuery): TJSONObject;
var
  LQuery: TClaimQuery;
  LBySymptom: TList<TClaim>;
  LByIngredient: TList<TClaim>;
  LCandidates: TList<TClaim>;
  LEmpty: TList<TClaim>;
  LResolved: TQueryResolution;
begin
  LQuery := AQuery;
  LQuery.Symptom := LookupAlias(AQuery.Symptom, FSymptomAliases);
  LQuery.Ingredient := LookupAlias(AQuery.Ingredient, FIngredientAliases);
  LQuery.Preparation := Normalize(AQuery.Preparation);
  LQuery.Direction := Normalize(AQuery.Direction);
  LQuery.Trend := Normalize(AQuery.Trend);
  if IndexStr(LQuery.Scope, ['directional', 'assessed', 'frozen']) < 0 then
    raise EConvertError.Create('Scope must be directional, assessed or frozen.');
  if IndexStr(LQuery.Direction, ['', 'reduces', 'worsens']) < 0 then
    raise EConvertError.Create('Direction must be reduces or worsens.');
  if IndexStr(LQuery.Trend, ['', 'eases', 'worsens']) < 0 then
    raise EConvertError.Create('Trend must be eases or worsens.');
  if IndexText(LQuery.Verdict, ['', 'True', 'False', 'Maybe True', 'Maybe False',
    'Unknown', 'Unreviewed']) < 0 then
    raise EConvertError.Create('Invalid verdict filter.');
  if (LQuery.Round < 0) or (LQuery.Round > 7) or (LQuery.Offset < 0) or
    (LQuery.Limit < 1) or (LQuery.Limit > 100) then
    raise EConvertError.Create('Invalid round or pagination.');

  if LQuery.Symptom = '' then
    LBySymptom := FClaims
  else
    FBySymptom.TryGetValue(LQuery.Symptom, LBySymptom);
  if LQuery.Ingredient = '' then
    LByIngredient := FClaims
  else
    FByIngredient.TryGetValue(LQuery.Ingredient, LByIngredient);
  LEmpty := nil;
  if (LBySymptom = nil) or (LByIngredient = nil) then
  begin
    LEmpty := TList<TClaim>.Create;
    LCandidates := LEmpty;
  end
  else if LBySymptom.Count < LByIngredient.Count then
    LCandidates := LBySymptom
  else
    LCandidates := LByIngredient;
  try
    LResolved := ResolveRows(LCandidates, LQuery);
    try
      Result := TJSONObject.Create(['revision', FRevision, 'scope', LQuery.Scope,
        'symptom', LQuery.Symptom, 'ingredient', LQuery.Ingredient,
        'preparation', LQuery.Preparation, 'hypothesis_direction', LQuery.Direction,
        'verdict_filter', LQuery.Verdict, 'round_filter', LQuery.Round,
        'index_candidates', LCandidates.Count, 'total_matches', LResolved.Selected,
        'offset', LQuery.Offset, 'identity_excluded', LResolved.IdentityExcluded,
        'hypothesis_excluded', LResolved.PremiseExcluded,
        'evidence_excluded', LResolved.EvidenceExcluded]);
      if LQuery.Trend <> '' then
        Result.Add('trend_filter', LQuery.Trend);
      Result.Add('options', LResolved.Options);
      LResolved.Options := nil;
      if (LQuery.Offset < LResolved.Selected) and
        (LQuery.Limit < LResolved.Selected - LQuery.Offset) then
        Result.Add('next_offset', LQuery.Offset + LQuery.Limit);
      if LResolved.Selected > 0 then
        Result.Add('state', 'matching_local_options')
      else
      begin
        Result.Add('state', 'no_matching_local_options');
        if LResolved.EvidenceExcluded > 0 then
          Result.Add('no_match_reason', 'evidence_filters')
        else if LResolved.PremiseExcluded > 0 then
          Result.Add('no_match_reason', 'hypothesis_filter')
        else
          Result.Add('no_match_reason', 'no_matching_identity');
      end;
    finally
      LResolved.Options.Free;
    end;
  finally
    LEmpty.Free;
  end;
end;

function TClaimIndex.StaticModel(const ARepository: String): TJSONObject;
const
  CScopes: array[0..1] of String = ('assessed', 'directional');
var
  LQuery: TClaimQuery;
  LResolved: TQueryResolution;
  LScopes: TDictionary<String, String>;
  LIndex: Integer;
  LScope: String;
  LRow: TJSONObject;
  LClaims: TJSONArray;
  LClaim: TClaim;
begin
  LScopes := TDictionary<String, String>.Create;
  try
    // Resolve the access scopes using the same WFC model as live lookups.
    LQuery := Default(TClaimQuery);
    LQuery.Limit := FClaims.Count;
    for LScope in CScopes do
    begin
      LQuery.Scope := LScope;
      LResolved := ResolveRows(FClaims, LQuery);
      try
        for LIndex := 0 to LResolved.Options.Count - 1 do
        begin
          LRow := LResolved.Options.Objects[LIndex];
          LScopes.AddOrSetValue(Key(LRow.Integers['round'], LRow.Strings['claim_id']), LScope);
        end;
      finally
        LResolved.Options.Free;
      end;
    end;

    Result := TJSONObject.Create(['schema', 'parkinsons-oracle-model-1',
      'repository', ARepository, 'revision', FRevision]);
    try
      Result.Add('status', Status);
      Result.Add('filter_options', FilterOptions);
      LClaims := TJSONArray.Create;
      Result.Add('claims', LClaims);
      for LClaim in FClaims do
      begin
        LRow := LClaim.View(True);
        LClaims.Add(LRow);
        if not LScopes.TryGetValue(Key(LClaim.Round, LClaim.Id), LScope) then
          LScope := 'frozen';
        LRow.Add('evidence_scope', LScope);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LScopes.Free;
  end;
end;

end.
