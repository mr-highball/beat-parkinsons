{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.transfer;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Generics.Collections;

const
  CRoundTransferHeader =
    'target_id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9 +
    'transfer_class'#9'zero_dir_symptom'#9'r1_ing_claims'#9'r1_ing_dir_scorecards'#9 +
    'r1_ing_open_scorecards'#9'r1_ing_assessments'#9'r1_ing_claim_ids'#9 +
    'r1_top_studies'#9'r1_top_references'#9'matrix_siblings'#9 +
    'matrix_dir_scorecards'#9'matrix_assessments'#9'r1_sym_dir_scorecards'#9 +
    'r1_sym_open_scorecards';

type
  TTransferClass = (
    tcDirectIngredientScorecard,
    tcIngredientAssessed,
    tcMatrixRelated,
    tcColdStartZeroDirSymptom,
    tcColdStart
  );

  TFrozenRow = record
    Id: String;
    Category: String;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    Direction: String;
  end;

  TTransferSummary = record
    SourceClaims: Integer;
    TargetClaims: Integer;
    DirectIngredientScorecard: Integer;
    IngredientAssessed: Integer;
    MatrixRelated: Integer;
    ColdStartZeroDirSymptom: Integer;
    ColdStart: Integer;
    TargetZeroDirSymptomClaims: Integer;
  end;

function CanonicalKey(const AText: String): String;
function MatrixFamilyKey(const AIngredient: String): String;
function TransferClassName(AClass: TTransferClass): String;
function VerifyAndLoadFreeze(const ARoundDir: String): TArray<TFrozenRow>;
function BuildRoundTransfer(const ASourceRoundDir, ATargetRoundDir, AOutputTsvPath: String): TTransferSummary;

implementation

uses
  StrUtils, FPSha256, foodexperiment.externaldata;

const
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CScorecardHeader = 'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale';
  CScorecardSourceHeader = 'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9 +
    'claim_effect'#9'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9 +
    'reliability_fit'#9'independence'#9'n'#9'unit'#9'local_reference'#9'rationale';
  CAssessmentHeader = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment';
  CMaxItemsPerCell = 8;

type
  TIngredientEvidence = class
    Ingredient: String;
    ClaimIds: TStringList;
    DirScorecards: Integer;
    OpenScorecards: Integer;
    Assessments: Integer;
    TopStudies: TStringList;
    TopReferences: TStringList;
    constructor Create(const AIngredient: String);
    destructor Destroy; override;
    procedure AddUniqueBounded(AList: TStringList; const AValue: String; AMax: Integer);
  end;

  TSymptomStats = record
    DirScorecards: Integer;
    OpenScorecards: Integer;
  end;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function ReadUtf8Text(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  Require(FileExists(APath), 'Missing required file: ' + APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Integer(LStream.Size));
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
  Require((Copy(Result, 1, 3) <> #$EF#$BB#$BF) and (Pos(#0, Result) = 0),
    'Unexpected BOM or NUL in file: ' + APath);
end;

procedure WriteUtf8Text(const APath: String; const AText: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function SplitLinesNormalized(const AText: UTF8String): TArray<String>;
var
  LList: TStringList;
  LNorm: String;
  I: Integer;
begin
  LNorm := StringReplace(String(AText), #13#10, #10, [rfReplaceAll]);
  LNorm := StringReplace(LNorm, #13, #10, [rfReplaceAll]);
  LList := TStringList.Create;
  try
    LList.StrictDelimiter := True;
    LList.Delimiter := #10;
    LList.DelimitedText := LNorm;
    if (LList.Count > 0) and (LList[LList.Count - 1] = '') then
    begin
      LList.Delete(LList.Count - 1);
    end;
    Result := nil;
    SetLength(Result, LList.Count);
    for I := 0 to LList.Count - 1 do
    begin
      Result[I] := LList[I];
    end;
  finally
    LList.Free;
  end;
end;

function CanonicalKey(const AText: String): String;
var
  I: Integer;
  LInSpace: Boolean;
  LChar: Char;
begin
  Result := '';
  LInSpace := False;
  for I := 1 to Length(AText) do
  begin
    LChar := AText[I];
    if LChar in [' ', #9, #10, #13] then
    begin
      if (Result <> '') and (not LInSpace) then
      begin
        Result := Result + ' ';
        LInSpace := True;
      end;
    end
    else
    begin
      if (LChar >= 'A') and (LChar <= 'Z') then
      begin
        LChar := Chr(Ord(LChar) + 32);
      end;
      Result := Result + LChar;
      LInSpace := False;
    end;
  end;
  Result := Trim(Result);
end;

function MatrixFamilyKey(const AIngredient: String): String;
var
  LKey: String;
begin
  LKey := CanonicalKey(AIngredient);
  if (LKey = 'cilantro') or (LKey = 'coriander leaf') or (LKey = 'coriander seed') then
  begin
    Exit('coriander');
  end;
  if (LKey = 'celery stalk') or (LKey = 'celery leaf') or (LKey = 'celery seed') then
  begin
    Exit('celery');
  end;
  if (LKey = 'fennel bulb') or (LKey = 'fennel seed') then
  begin
    Exit('fennel');
  end;
  if (LKey = 'mustard greens') or (LKey = 'mustard seed') or (LKey = 'mustard oil') then
  begin
    Exit('mustard');
  end;
  if (LKey = 'grape') or (LKey = 'grapeseed oil') then
  begin
    Exit('grape');
  end;
  if (LKey = 'flaxseed') or (LKey = 'flaxseed oil') then
  begin
    Exit('flaxseed');
  end;
  if (LKey = 'sesame seed') or (LKey = 'sesame oil') then
  begin
    Exit('sesame');
  end;
  if (LKey = 'sunflower seed') or (LKey = 'sunflower oil') then
  begin
    Exit('sunflower');
  end;
  if (LKey = 'pumpkin seed') or (LKey = 'pumpkin seed oil') then
  begin
    Exit('pumpkin seed');
  end;
  if (LKey = 'hemp seed') or (LKey = 'hemp seed oil') then
  begin
    Exit('hemp seed');
  end;
  if (LKey = 'chia seed') or (LKey = 'chia oil') then
  begin
    Exit('chia');
  end;
  if (LKey = 'olive') or (LKey = 'olives') or (LKey = 'olive oil') then
  begin
    Exit('olive');
  end;
  if (LKey = 'walnut') or (LKey = 'walnuts') or (LKey = 'walnut oil') then
  begin
    Exit('walnut');
  end;
  if (LKey = 'almond') or (LKey = 'almonds') or (LKey = 'almond oil') then
  begin
    Exit('almond');
  end;
  if (LKey = 'peanut') or (LKey = 'peanuts') or (LKey = 'peanut oil') then
  begin
    Exit('peanut');
  end;
  if (LKey = 'hazelnut') or (LKey = 'hazelnuts') or (LKey = 'hazelnut oil') then
  begin
    Exit('hazelnut');
  end;
  if (LKey = 'macadamia') or (LKey = 'macadamia nut') or (LKey = 'macadamia oil') then
  begin
    Exit('macadamia');
  end;
  if (LKey = 'pistachio') or (LKey = 'pistachios') or (LKey = 'pistachio oil') then
  begin
    Exit('pistachio');
  end;
  if (LKey = 'coconut') or (LKey = 'coconut oil') then
  begin
    Exit('coconut');
  end;
  if (LKey = 'avocado') or (LKey = 'avocado oil') then
  begin
    Exit('avocado');
  end;
  if (LKey = 'corn') or (LKey = 'sweet corn') or (LKey = 'corn oil') then
  begin
    Exit('corn');
  end;
  if (LKey = 'soybean') or (LKey = 'soybeans') or (LKey = 'edamame') or (LKey = 'soybean oil') then
  begin
    Exit('soy');
  end;
  if EndsStr(' oil', LKey) and (Length(LKey) > 4) then
  begin
    Exit(Trim(Copy(LKey, 1, Length(LKey) - 4)));
  end;
  Result := LKey;
end;

function TransferClassName(AClass: TTransferClass): String;
begin
  case AClass of
    tcDirectIngredientScorecard: Result := 'direct_ingredient_scorecard';
    tcIngredientAssessed: Result := 'ingredient_assessed';
    tcMatrixRelated: Result := 'matrix_related';
    tcColdStartZeroDirSymptom: Result := 'cold_start_zero_dir_symptom';
    tcColdStart: Result := 'cold_start';
  end;
end;

function JoinPipe(AList: TStringList): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AList.Count - 1 do
  begin
    if I > 0 then
    begin
      Result := Result + '|';
    end;
    Result := Result + AList[I];
  end;
end;

function JoinPath(const ADir, AChild: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ADir) + AChild;
end;

function VerifyAndLoadFreeze(const ARoundDir: String): TArray<TFrozenRow>;
var
  LFreezeBytes: UTF8String;
  LHashText: UTF8String;
  LBytes: TBytes;
  LComputed: AnsiString;
  LLines: TArray<String>;
  LFields: TFields;
  LPairs: TDictionary<String, Boolean>;
  LPairKey: String;
  I: Integer;
begin
  LFreezeBytes := ReadUtf8Text(JoinPath(ARoundDir, 'freeze.tsv'));
  LHashText := ReadUtf8Text(JoinPath(ARoundDir, 'freeze.sha256'));
  Require(LFreezeBytes <> '', 'Empty freeze.tsv in ' + ARoundDir);
  SetLength(LBytes, Length(LFreezeBytes));
  Move(LFreezeBytes[1], LBytes[0], Length(LBytes));
  TSHA256.DigestHexa(LBytes, LComputed);
  Require(LowerCase(Trim(String(LHashText))) = LowerCase(String(LComputed)),
    'Freeze SHA-256 mismatch in ' + ARoundDir);

  LLines := SplitLinesNormalized(LFreezeBytes);
  Require((Length(LLines) >= 2) and (LLines[0] = CFreezeHeader),
    'Invalid freeze.tsv header or empty rows in ' + ARoundDir);

  Result := nil;
  SetLength(Result, Length(LLines) - 1);
  LPairs := TDictionary<String, Boolean>.Create;
  try
    for I := 1 to High(LLines) do
    begin
      LFields := SplitFields(LLines[I], #9);
      Require(Length(LFields) = 7, 'Malformed freeze row ' + IntToStr(I + 1) + ' in ' + ARoundDir);
      Result[I - 1].Id := Trim(LFields[0]);
      Result[I - 1].Category := CanonicalKey(LFields[1]);
      Result[I - 1].Ingredient := CanonicalKey(LFields[2]);
      Result[I - 1].Preparation := CanonicalKey(LFields[3]);
      Result[I - 1].Symptom := CanonicalKey(LFields[4]);
      Result[I - 1].Direction := CanonicalKey(LFields[5]);
      LPairKey := Result[I - 1].Ingredient + #9 + Result[I - 1].Symptom;
      Require(not LPairs.ContainsKey(LPairKey),
        'Duplicate pair inside ' + ARoundDir + ': ' + LPairKey);
      LPairs.Add(LPairKey, True);
    end;
  finally
    LPairs.Free;
  end;
end;

{ TIngredientEvidence }

constructor TIngredientEvidence.Create(const AIngredient: String);
begin
  inherited Create;
  Ingredient := AIngredient;
  ClaimIds := TStringList.Create;
  ClaimIds.Sorted := False;
  TopStudies := TStringList.Create;
  TopStudies.Sorted := False;
  TopReferences := TStringList.Create;
  TopReferences.Sorted := False;
end;

destructor TIngredientEvidence.Destroy;
begin
  TopReferences.Free;
  TopStudies.Free;
  ClaimIds.Free;
  inherited Destroy;
end;

procedure TIngredientEvidence.AddUniqueBounded(AList: TStringList; const AValue: String;
  AMax: Integer);
var
  LClean: String;
begin
  LClean := Trim(AValue);
  if (LClean = '') or (AList.Count >= AMax) then
  begin
    Exit;
  end;
  if AList.IndexOf(LClean) < 0 then
  begin
    AList.Add(LClean);
  end;
end;

function BuildRoundTransfer(const ASourceRoundDir, ATargetRoundDir, AOutputTsvPath: String): TTransferSummary;
var
  LSourceRows: TArray<TFrozenRow>;
  LTargetRows: TArray<TFrozenRow>;
  LSourcePairs: TDictionary<String, String>;
  LSourceClaimById: TDictionary<String, Integer>;
  LIngMap: TObjectDictionary<String, TIngredientEvidence>;
  LMatrixMap: TObjectDictionary<String, TStringList>;
  LSymMap: TDictionary<String, TSymptomStats>;
  LIngEv: TIngredientEvidence;
  LMatList: TStringList;
  LSymStat: TSymptomStats;
  LPath: String;
  LLines: TArray<String>;
  LFields: TFields;
  LClaimIdx: Integer;
  LIngKey, LMatKey, LSymKey, LPairKey, LExistingId: String;
  LOut: TStringBuilder;
  LSiblingNames: TStringList;
  LMatDirCount, LMatAssessCount: Integer;
  LSibEv: TIngredientEvidence;
  LZeroDir: Boolean;
  LClass: TTransferClass;
  I, J: Integer;
begin
  Result := Default(TTransferSummary);
  LSourceRows := VerifyAndLoadFreeze(ASourceRoundDir);
  LTargetRows := VerifyAndLoadFreeze(ATargetRoundDir);
  Result.SourceClaims := Length(LSourceRows);
  Result.TargetClaims := Length(LTargetRows);

  LSourcePairs := TDictionary<String, String>.Create;
  LSourceClaimById := TDictionary<String, Integer>.Create;
  LIngMap := TObjectDictionary<String, TIngredientEvidence>.Create([doOwnsValues]);
  LMatrixMap := TObjectDictionary<String, TStringList>.Create([doOwnsValues]);
  LSymMap := TDictionary<String, TSymptomStats>.Create;
  try
    for I := 0 to High(LSourceRows) do
    begin
      LPairKey := LSourceRows[I].Ingredient + #9 + LSourceRows[I].Symptom;
      LSourcePairs.Add(LPairKey, LSourceRows[I].Id);
      LSourceClaimById.Add(LSourceRows[I].Id, I);

      LIngKey := LSourceRows[I].Ingredient;
      if not LIngMap.TryGetValue(LIngKey, LIngEv) then
      begin
        LIngEv := TIngredientEvidence.Create(LIngKey);
        LIngMap.Add(LIngKey, LIngEv);
      end;
      LIngEv.AddUniqueBounded(LIngEv.ClaimIds, LSourceRows[I].Id, 64);

      LMatKey := MatrixFamilyKey(LIngKey);
      if not LMatrixMap.TryGetValue(LMatKey, LMatList) then
      begin
        LMatList := TStringList.Create;
        LMatList.Sorted := True;
        LMatList.Duplicates := dupIgnore;
        LMatrixMap.Add(LMatKey, LMatList);
      end;
      LMatList.Add(LIngKey);

      LSymKey := LSourceRows[I].Symptom;
      if not LSymMap.ContainsKey(LSymKey) then
      begin
        LSymMap.Add(LSymKey, Default(TSymptomStats));
      end;
    end;

    { Enforce global duplicate prohibition across rounds }
    for I := 0 to High(LTargetRows) do
    begin
      LPairKey := LTargetRows[I].Ingredient + #9 + LTargetRows[I].Symptom;
      if LSourcePairs.TryGetValue(LPairKey, LExistingId) then
      begin
        raise EConvertError.Create('Cross-round duplicate (ingredient, symptom) pair: ' +
          LTargetRows[I].Ingredient + ' / ' + LTargetRows[I].Symptom +
          ' (source ' + LExistingId + ', target ' + LTargetRows[I].Id + ')');
      end;
    end;

    { Load Round 1 checked v1 scorecards if present }
    LPath := JoinPath(ASourceRoundDir, 'followup/scorecards.tsv');
    if FileExists(LPath) then
    begin
      LLines := SplitLinesNormalized(ReadUtf8Text(LPath));
      Require((Length(LLines) >= 1) and (LLines[0] = CScorecardHeader),
        'Invalid scorecards.tsv header in ' + ASourceRoundDir);
      for I := 1 to High(LLines) do
      begin
        LFields := SplitFields(LLines[I], #9);
        Require(Length(LFields) = 5, 'Malformed scorecards.tsv row ' + IntToStr(I + 1));
        if LSourceClaimById.TryGetValue(Trim(LFields[0]), LClaimIdx) then
        begin
          LIngEv := LIngMap[LSourceRows[LClaimIdx].Ingredient];
          LSymKey := LSourceRows[LClaimIdx].Symptom;
          LSymStat := LSymMap[LSymKey];
          if Trim(LFields[2]) = 'open' then
          begin
            Inc(LIngEv.OpenScorecards);
            Inc(LSymStat.OpenScorecards);
          end
          else
          begin
            Inc(LIngEv.DirScorecards);
            Inc(LSymStat.DirScorecards);
          end;
          LSymMap[LSymKey] := LSymStat;
        end;
      end;
    end;

    { Load Round 1 scorecard sources first so top clinical study families come first }
    LPath := JoinPath(ASourceRoundDir, 'followup/scorecard-sources.tsv');
    if FileExists(LPath) then
    begin
      LLines := SplitLinesNormalized(ReadUtf8Text(LPath));
      Require((Length(LLines) >= 1) and (LLines[0] = CScorecardSourceHeader),
        'Invalid scorecard-sources.tsv header in ' + ASourceRoundDir);
      for I := 1 to High(LLines) do
      begin
        LFields := SplitFields(LLines[I], #9);
        Require(Length(LFields) = 17, 'Malformed scorecard-sources.tsv row ' + IntToStr(I + 1));
        if LSourceClaimById.TryGetValue(Trim(LFields[0]), LClaimIdx) then
        begin
          LIngEv := LIngMap[LSourceRows[LClaimIdx].Ingredient];
          LIngEv.AddUniqueBounded(LIngEv.TopStudies, Trim(LFields[1]), CMaxItemsPerCell);
          LIngEv.AddUniqueBounded(LIngEv.TopReferences, Trim(LFields[15]), CMaxItemsPerCell);
        end;
      end;
    end;

    { Load Round 1 study assessments (non-excluded rows) }
    LPath := JoinPath(ASourceRoundDir, 'followup/assessments.tsv');
    if FileExists(LPath) then
    begin
      LLines := SplitLinesNormalized(ReadUtf8Text(LPath));
      Require((Length(LLines) >= 1) and (LLines[0] = CAssessmentHeader),
        'Invalid assessments.tsv header in ' + ASourceRoundDir);
      for I := 1 to High(LLines) do
      begin
        LFields := SplitFields(LLines[I], #9);
        Require(Length(LFields) = 6, 'Malformed assessments.tsv row ' + IntToStr(I + 1));
        if Trim(LFields[2]) = 'excluded' then
        begin
          Continue;
        end;
        if LSourceClaimById.TryGetValue(Trim(LFields[0]), LClaimIdx) then
        begin
          LIngEv := LIngMap[LSourceRows[LClaimIdx].Ingredient];
          Inc(LIngEv.Assessments);
          LIngEv.AddUniqueBounded(LIngEv.TopStudies, Trim(LFields[1]), CMaxItemsPerCell);
          LIngEv.AddUniqueBounded(LIngEv.TopReferences, Trim(LFields[4]), CMaxItemsPerCell);
        end;
      end;
    end;

    { Emit deterministic transfer index }
    LOut := TStringBuilder.Create;
    LSiblingNames := TStringList.Create;
    try
      LOut.Append(CRoundTransferHeader).Append(#10);
      for I := 0 to High(LTargetRows) do
      begin
        LIngKey := LTargetRows[I].Ingredient;
        LSymKey := LTargetRows[I].Symptom;
        LMatKey := MatrixFamilyKey(LIngKey);

        if not LIngMap.TryGetValue(LIngKey, LIngEv) then
        begin
          LIngEv := nil;
        end;

        if not LSymMap.TryGetValue(LSymKey, LSymStat) then
        begin
          LSymStat := Default(TSymptomStats);
        end;
        LZeroDir := LSymStat.DirScorecards = 0;
        if LZeroDir then
        begin
          Inc(Result.TargetZeroDirSymptomClaims);
        end;

        LSiblingNames.Clear;
        LMatDirCount := 0;
        LMatAssessCount := 0;
        if LMatrixMap.TryGetValue(LMatKey, LMatList) then
        begin
          for J := 0 to LMatList.Count - 1 do
          begin
            if LMatList[J] <> LIngKey then
            begin
              LSiblingNames.Add(LMatList[J]);
              if LIngMap.TryGetValue(LMatList[J], LSibEv) then
              begin
                Inc(LMatDirCount, LSibEv.DirScorecards);
                Inc(LMatAssessCount, LSibEv.Assessments);
              end;
            end;
          end;
        end;

        if (LIngEv <> nil) and (LIngEv.DirScorecards > 0) then
        begin
          LClass := tcDirectIngredientScorecard;
          Inc(Result.DirectIngredientScorecard);
        end
        else if (LIngEv <> nil) and ((LIngEv.OpenScorecards > 0) or (LIngEv.Assessments > 0)) then
        begin
          LClass := tcIngredientAssessed;
          Inc(Result.IngredientAssessed);
        end
        else if (LSiblingNames.Count > 0) and ((LMatDirCount > 0) or (LMatAssessCount > 0)) then
        begin
          LClass := tcMatrixRelated;
          Inc(Result.MatrixRelated);
        end
        else if LZeroDir then
        begin
          LClass := tcColdStartZeroDirSymptom;
          Inc(Result.ColdStartZeroDirSymptom);
        end
        else
        begin
          LClass := tcColdStart;
          Inc(Result.ColdStart);
        end;

        LOut.Append(LTargetRows[I].Id).Append(#9)
          .Append(LTargetRows[I].Category).Append(#9)
          .Append(LTargetRows[I].Ingredient).Append(#9)
          .Append(LTargetRows[I].Preparation).Append(#9)
          .Append(LTargetRows[I].Symptom).Append(#9)
          .Append(LTargetRows[I].Direction).Append(#9)
          .Append(TransferClassName(LClass)).Append(#9);
        if LZeroDir then
        begin
          LOut.Append('true').Append(#9);
        end
        else
        begin
          LOut.Append('false').Append(#9);
        end;

        if LIngEv <> nil then
        begin
          LOut.Append(IntToStr(LIngEv.ClaimIds.Count)).Append(#9)
            .Append(IntToStr(LIngEv.DirScorecards)).Append(#9)
            .Append(IntToStr(LIngEv.OpenScorecards)).Append(#9)
            .Append(IntToStr(LIngEv.Assessments)).Append(#9)
            .Append(JoinPipe(LIngEv.ClaimIds)).Append(#9)
            .Append(JoinPipe(LIngEv.TopStudies)).Append(#9)
            .Append(JoinPipe(LIngEv.TopReferences)).Append(#9);
        end
        else
        begin
          LOut.Append('0'#9'0'#9'0'#9'0'#9#9#9#9);
        end;

        LOut.Append(JoinPipe(LSiblingNames)).Append(#9)
          .Append(IntToStr(LMatDirCount)).Append(#9)
          .Append(IntToStr(LMatAssessCount)).Append(#9)
          .Append(IntToStr(LSymStat.DirScorecards)).Append(#9)
          .Append(IntToStr(LSymStat.OpenScorecards)).Append(#10);
      end;

      WriteUtf8Text(AOutputTsvPath, UTF8String(LOut.ToString));
    finally
      LSiblingNames.Free;
      LOut.Free;
    end;
  finally
    LSymMap.Free;
    LMatrixMap.Free;
    LIngMap.Free;
    LSourceClaimById.Free;
    LSourcePairs.Free;
  end;
end;

end.
