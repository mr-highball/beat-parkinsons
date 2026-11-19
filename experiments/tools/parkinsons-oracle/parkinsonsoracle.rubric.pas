
{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.rubric;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses fpjson;

const
  EvidenceRubricVersion = '1';

procedure AddEvidenceScorecard(AResponse: TJSONObject;
  const ADecisions, ASources, AId, ADirection, AVerdict: String;
  AConfidence: Currency; ADraft: Boolean = False);

implementation

uses Classes, SysUtils, StrUtils, foodexperiment.externaldata, foodexperiment.confidence;

const
  CDecisionHeader: array[0..4] of String =
    ('id', 'rubric_version', 'tier', 'symptom_effect', 'rationale');
  CSourceHeader: array[0..16] of String = ('id', 'family', 'kind', 'reporter', 'provenance',
    'observed_effect', 'claim_effect', 'exposure_fit', 'population_fit', 'outcome_fit',
    'attribution_fit', 'reliability_fit', 'independence', 'n', 'unit', 'local_reference', 'rationale');
  CFitFields: array[0..4] of String =
    ('exposure_fit', 'population_fit', 'outcome_fit', 'attribution_fit', 'reliability_fit');
  CTiers: array[0..4] of String =
    ('open', 'minimal_signal', 'limited_clinical_link', 'direct_clinical_signal',
    'strong_directional_evidence');
  CAnchors: array[0..4] of Currency = (50, 50.005, 51, 55, 60);

function RowsForClaim(const AText, AId, ALabel: String;
  const AHeader: array of String; ADraft: Boolean): TJSONArray;
var
  LLines: TStringList;
  LFields: TFields;
  LRow: TJSONObject;
  LIndex: Integer;
  LColumn: Integer;
begin
  Result := TJSONArray.Create;
  LLines := TStringList.Create;
  try
    try
      LLines.Text := AText;
      if LLines.Count = 0 then
        raise EConvertError.Create('Missing header in published ' + ALabel + '.');
      LFields := SplitFields(LLines[0], #9);
      if Length(LFields) <> Length(AHeader) then
        raise EConvertError.Create('Invalid header in published ' + ALabel + '.');
      for LColumn := Low(AHeader) to High(AHeader) do
      begin
        if LFields[LColumn] <> AHeader[LColumn] then
          raise EConvertError.Create('Invalid header in published ' + ALabel + '.');
      end;
      for LIndex := 1 to LLines.Count - 1 do
      begin
        if LLines[LIndex] = '' then
          Continue;
        LFields := SplitFields(LLines[LIndex], #9);
        if Length(LFields) <> Length(AHeader) then
          raise EConvertError.CreateFmt('Invalid row width in %s at line %d.',
            [ALabel, LIndex + 1]);
        if LFields[0] <> AId then
        begin
          if ADraft then
          begin
            raise EConvertError.CreateFmt('Draft %s row %d must use claim ID %s.',
              [ALabel, LIndex + 1, AId]);
          end;
          Continue;
        end;
        LRow := TJSONObject.Create;
        Result.Add(LRow);
        for LColumn := Low(AHeader) to High(AHeader) do
        begin
          if (AHeader[LColumn] <> 'n') and (Trim(LFields[LColumn]) = '') then
            raise EConvertError.CreateFmt('Missing %s in %s for claim %s.',
              [AHeader[LColumn], ALabel, AId]);
          LRow.Add(AHeader[LColumn], LFields[LColumn]);
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LLines.Free;
  end;
end;

function QualifyingTier(ARow: TJSONObject): Integer;
var
  LFit: String;
  LObserved: String;
  LEffect: String;
  LProvenance: String;
  LFitValue: String;
  LSize: Integer;
begin
  LObserved := ARow.Strings['observed_effect'];
  LEffect := ARow.Strings['claim_effect'];
  LProvenance := ARow.Strings['provenance'];
  if not MatchStr(LObserved, ['eases', 'worsens', 'null', 'mixed', 'unreported']) or
    not MatchStr(LEffect, ['eases', 'worsens', 'none']) or
    not MatchStr(LProvenance, ['original', 'traceable', 'untraced']) or
    not MatchStr(ARow.Strings['independence'], ['confirmed', 'uncertain']) then
    raise EConvertError.Create('Invalid source role, provenance or effect.');
  if (ARow.Strings['n'] <> '') and
    (not TryStrToInt(ARow.Strings['n'], LSize) or (LSize < 1)) then
    raise EConvertError.Create('An analyzed sample size must be a positive integer.');
  for LFit in CFitFields do
  begin
    LFitValue := ARow.Strings[LFit];
    if not MatchStr(LFitValue, ['direct', 'partial', 'remote', 'unusable']) then
      raise EConvertError.Create('Invalid source rating for ' + LFit + '.');
    if (LEffect <> 'none') and (LFitValue = 'unusable') then
      raise EConvertError.Create('An ineligible fit cannot support a direction.');
  end;
  if LEffect = 'none' then
    Exit(0);
  if (LEffect <> LObserved) or (LProvenance = 'untraced') or
    (ARow.Strings['outcome_fit'] = 'remote') or (ARow.Strings['attribution_fit'] = 'remote') then
    raise EConvertError.Create('A signed source requires an interpretable, traceable comparison.');
  Result := 1;
  if (ARow.Strings['population_fit'] <> 'direct') or (ARow.Strings['outcome_fit'] <> 'direct') or
    (ARow.Strings['reliability_fit'] = 'remote') or
    not MatchStr(ARow.Strings['kind'], ['trial', 'observational', 'clinical_case', 'registry']) then
    Exit;
  Result := 2;
  if (ARow.Strings['exposure_fit'] = 'direct') and (ARow.Strings['attribution_fit'] = 'direct') then
    Result := 3;
end;

procedure CountFamily(ACounts: TJSONObject; const AColumn: String);
begin
  ACounts.Integers[AColumn] := ACounts.Get(AColumn, 0) + 1;
end;

procedure AddEvidenceScorecard(AResponse: TJSONObject;
  const ADecisions, ASources, AId, ADirection, AVerdict: String;
  AConfidence: Currency; ADraft: Boolean);
var
  LDecisions: TJSONArray;
  LSources: TJSONArray;
  LDecision: TJSONObject;
  LFamilyRows: TStringList;
  LTypes: TJSONObject;
  LCounts: TJSONObject;
  LTypeCounts: TJSONObject;
  LSource: TJSONObject;
  LSourceIndex: Integer;
  LCountKey: String;
  LEffect: String;
  LKind: String;
  LExpectedVerdict: String;
  LTier: Integer;
  LMinimumTier: Integer;
  LSupportedTier: Integer;
  LSourceTier: Integer;
begin
  if not ADraft and (ADecisions = '') and (ASources = '') then
  begin
    AResponse.Add('review_status', 'no_scorecard');
    Exit;
  end;
  LDecisions := nil;
  LSources := nil;
  LFamilyRows := TStringList.Create;
  try
    LFamilyRows.CaseSensitive := True;
    LFamilyRows.Sorted := True;
    LFamilyRows.Duplicates := dupError;
    LDecisions := RowsForClaim(ADecisions, AId, 'scorecards', CDecisionHeader, ADraft);
    LSources := RowsForClaim(ASources, AId, 'scorecard sources', CSourceHeader, ADraft);
    if not ADraft and (LDecisions.Count = 0) and (LSources.Count = 0) then
    begin
      AResponse.Add('review_status', 'no_scorecard');
      Exit;
    end;
    if LDecisions.Count <> 1 then
      raise EConvertError.Create('Expected one scorecard for claim ' + AId + '.');
    LDecision := LDecisions.Objects[0];
    if LDecision.Strings['rubric_version'] <> EvidenceRubricVersion then
    begin
      if ADraft then
      begin
        raise EConvertError.Create('Use rubric version ' + EvidenceRubricVersion + ' for drafts.');
      end;
      AResponse.Add('review_status', 'historical_scorecard');
      AResponse.Add('scorecard', LDecision.Clone);
      AResponse.Add('sources', LSources.Clone);
      Exit;
    end;
    LTier := IndexStr(LDecision.Strings['tier'], CTiers);
    LEffect := LDecision.Strings['symptom_effect'];
    if (LTier < 0) or ((LTier = 0) and (LEffect <> 'none')) or
      ((LTier > 0) and not MatchStr(LEffect, ['eases', 'worsens'])) then
      raise EConvertError.Create('Invalid tier and effect for claim ' + AId + '.');
    LCounts := TJSONObject.Create(['eases', 0, 'worsens', 0, 'context', 0, 'uncertain', 0]);
    AResponse.Add('family_counts', LCounts);
    LTypes := TJSONObject.Create;
    AResponse.Add('family_counts_by_kind', LTypes);
    LSupportedTier := 0;
    for LSourceIndex := 0 to LSources.Count - 1 do
    begin
      LSource := LSources.Objects[LSourceIndex];
      LFamilyRows.Add(LSource.Strings['family']);
      LSourceTier := QualifyingTier(LSource);
      if (LSource.Strings['claim_effect'] = LEffect) and (LSourceTier > LSupportedTier) then
        LSupportedTier := LSourceTier;
      LCountKey := LSource.Strings['claim_effect'];
      if LSource.Strings['independence'] = 'uncertain' then
        LCountKey := 'uncertain'
      else if LCountKey = 'none' then
        LCountKey := 'context';
      CountFamily(LCounts, LCountKey);
      LKind := LSource.Strings['kind'];
      LTypeCounts := LTypes.Get(LKind, TJSONObject(nil));
      if LTypeCounts = nil then
      begin
        LTypeCounts := TJSONObject.Create(['eases', 0, 'worsens', 0, 'context', 0, 'uncertain', 0]);
        LTypes.Add(LKind, LTypeCounts);
      end;
      CountFamily(LTypeCounts, LCountKey);
    end;
    LMinimumTier := LTier;
    if LTier = High(CTiers) then
      LMinimumTier := High(CTiers) - 1;
    if LSupportedTier < LMinimumTier then
      raise EConvertError.Create('Source fits do not meet the tier prerequisites for ' + AId + '.');
    LExpectedVerdict := 'Unknown';
    if LTier > 0 then
    begin
      if (ADirection = 'reduces') = (LEffect = 'eases') then
        LExpectedVerdict := 'True'
      else
        LExpectedVerdict := 'False';
      if LTier < High(CTiers) then
        LExpectedVerdict := 'Maybe ' + LExpectedVerdict;
    end;
    if ADraft then
      AResponse.Add('review_status', 'valid_draft')
    else if (LExpectedVerdict = AVerdict) and (CAnchors[LTier] = AConfidence) then
      AResponse.Add('review_status', 'recorded')
    else
      AResponse.Add('review_status', 'verdict_mismatch');
    LDecision.Add('score_anchor', ReviewConfidenceText(CAnchors[LTier]));
    LDecision.Add('expected_verdict', LExpectedVerdict);
    AResponse.Add('scorecard', LDecision.Clone);
    if not ADraft then
    begin
      AResponse.Add('sources', LSources.Clone);
    end;
  finally
    LFamilyRows.Free;
    LSources.Free;
    LDecisions.Free;
  end;
end;

end.
