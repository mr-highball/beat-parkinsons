{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentScorecardMerge;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, Generics.Collections, fpjson, FPSha256,
  foodexperiment.externaldata, foodexperiment.confidence, parkinsonsoracle.rubric;

const
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CVerdictHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9 +
    'search_record'#9'local_verdict';
  CDecisionHeader = 'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale';
  CSourceHeader = 'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9 +
    'claim_effect'#9'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9 +
    'reliability_fit'#9'independence'#9'n'#9'unit'#9'local_reference'#9'rationale';
  CLf = #10;

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
  LRoundTrip: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= High(Integer), 'Input file is too large: ' + APath);
    SetLength(Result, Integer(LStream.Size));
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
  Require((Copy(Result, 1, 3) <> #$EF#$BB#$BF) and (Pos(#0, Result) = 0),
    'Unexpected BOM or NUL byte: ' + APath);
  LRoundTrip := UTF8Encode(UTF8Decode(Result));
  Require(LRoundTrip = Result, 'Invalid UTF-8 encoding: ' + APath);
end;

procedure WriteUtf8Lf(const APath: String; const ALines: TStrings);
var
  LStream: TFileStream;
  LText: UTF8String;
  LIndex: Integer;
begin
  LText := '';
  for LIndex := 0 to ALines.Count - 1 do
  begin
    LText := LText + UTF8String(ALines[LIndex]) + CLf;
  end;
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if LText <> '' then
    begin
      LStream.WriteBuffer(LText[1], Length(LText));
    end;
  finally
    LStream.Free;
  end;
end;

procedure LoadLines(ALines: TStrings; const AText, ALabel: String);
var
  LNormalized: String;
begin
  Require(Pos(#13, AText) = 0, ALabel + ' must use LF line endings.');
  Require((AText <> '') and (AText[Length(AText)] = CLf),
    ALabel + ' must end with a newline.');
  LNormalized := Copy(AText, 1, Length(AText) - 1);
  ALines.Clear;
  ALines.LineBreak := CLf;
  ALines.Text := LNormalized;
end;

function Sha256Hex(const AText: UTF8String): String;
var
  LBytes: TBytes;
  LHex: AnsiString;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
  begin
    Move(AText[1], LBytes[0], Length(AText));
  end;
  TSHA256.DigestHexa(LBytes, LHex);
  Result := LowerCase(String(LHex));
end;

function FindFrozenDirection(const AExperiment, AClaimId: String): String;
var
  LFreezeText: UTF8String;
  LFreezeHash: String;
  LLines: TStringList;
  LFields: TFields;
  LIndex: Integer;
begin
  LFreezeText := ReadUtf8Text(IncludeTrailingPathDelimiter(AExperiment) + 'freeze.tsv');
  LFreezeHash := Trim(String(ReadUtf8Text(IncludeTrailingPathDelimiter(AExperiment) + 'freeze.sha256')));
  Require(Sha256Hex(LFreezeText) = LFreezeHash, 'Frozen claim SHA-256 digest mismatch.');
  LLines := TStringList.Create;
  try
    LoadLines(LLines, String(LFreezeText), 'freeze.tsv');
    Require((LLines.Count > 1) and (LLines[0] = CFreezeHeader), 'Invalid freeze.tsv header.');
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      Require(Length(LFields) = 7, 'Malformed freeze.tsv row ' + IntToStr(LIndex + 1));
      if LFields[0] = AClaimId then
      begin
        Require((LFields[5] = 'reduces') or (LFields[5] = 'worsens'),
          'Unexpected frozen direction for claim ' + AClaimId);
        Exit(LFields[5]);
      end;
    end;
  finally
    LLines.Free;
  end;
  raise EConvertError.Create('Claim ID not found in freeze.tsv: ' + AClaimId);
end;

function ValidRepoReference(const ARoot, AReference: String): Boolean;
var
  LPath: String;
  LFullPath: String;
begin
  LPath := SplitFields(AReference, '#')[0];
  if (LPath = '') or ContainsStr(LPath, '..') or StartsStr('/', LPath) or
    StartsStr('\', LPath) or not StartsStr('research/', LPath) then
  begin
    Exit(False);
  end;
  LFullPath := IncludeTrailingPathDelimiter(ARoot) +
    StringReplace(LPath, '/', PathDelim, [rfReplaceAll]);
  Result := FileExists(LFullPath);
end;

function MergeReferences(const ARoot, AExisting: String;
  const ASources: TStrings): String;
var
  LList: TStringList;
  LRef: String;
  LFields: TFields;
  LIndex: Integer;
begin
  LList := TStringList.Create;
  try
    LList.CaseSensitive := True;
    for LIndex := 1 to ASources.Count - 1 do
    begin
      if ASources[LIndex] = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(ASources[LIndex], #9);
      Require(Length(LFields) = 17, 'Malformed draft source row ' + IntToStr(LIndex + 1));
      LRef := Trim(LFields[15]);
      Require(ValidRepoReference(ARoot, LRef),
        'Missing or invalid research local_reference: ' + LRef);
      if LList.IndexOf(LRef) < 0 then
      begin
        LList.Add(LRef);
      end;
    end;
    for LRef in SplitFields(AExisting, '|') do
    begin
      if (LRef <> '') and (LList.IndexOf(LRef) < 0) then
      begin
        LList.Add(LRef);
      end;
    end;
    Result := '';
    for LIndex := 0 to LList.Count - 1 do
    begin
      if LIndex > 0 then
      begin
        Result := Result + '|';
      end;
      Result := Result + LList[LIndex];
    end;
  finally
    LList.Free;
  end;
end;

procedure Run(const AExperiment, ADraftDecisionPath, ADraftSourcesPath, AStagedDir: String);
var
  LExpDir: String;
  LRoot: String;
  LStaged: String;
  LDraftDecisionText: String;
  LDraftSourcesText: String;
  LDraftDecisions: TStringList;
  LDraftSources: TStringList;
  LCurrentDecisions: TStringList;
  LCurrentSources: TStringList;
  LVerdicts: TStringList;
  LNextSources: TStringList;
  LFields: TFields;
  LClaimId: String;
  LDirection: String;
  LDecisionRow: String;
  LCheck: TJSONObject;
  LExpectedVerdict: String;
  LAnchorText: String;
  LAnchorValue: Currency;
  LRationale: String;
  LMergedRefs: String;
  LReplacedDecision: Boolean;
  LReplacedVerdict: Boolean;
  LRemovedSources: Integer;
  LIndex: Integer;
  LScorecardsPath: String;
  LSourcesPath: String;
  LVerdictsPath: String;
  LStagedDecisionsText: String;
  LStagedSourcesText: String;
begin
  LExpDir := ExcludeTrailingPathDelimiter(ExpandFileName(AExperiment));
  Require(DirectoryExists(LExpDir), 'Experiment directory does not exist: ' + LExpDir);
  Require(SameText(ExtractFileName(ExtractFileDir(LExpDir)), 'experiments'),
    'Pass an experiment directory directly beneath experiments/.');
  LRoot := ExtractFileDir(ExtractFileDir(LExpDir));
  LStaged := ExcludeTrailingPathDelimiter(ExpandFileName(AStagedDir));
  Require(not SameFileName(LStaged, LExpDir) and
    not SameFileName(LStaged, LExpDir + PathDelim + 'followup'),
    'Choose a staging directory distinct from the experiment directory.');
  Require(ForceDirectories(LStaged), 'Cannot create staging directory: ' + LStaged);

  LDraftDecisionText := String(ReadUtf8Text(ADraftDecisionPath));
  LDraftSourcesText := String(ReadUtf8Text(ADraftSourcesPath));

  LDraftDecisions := TStringList.Create;
  LDraftSources := TStringList.Create;
  LCurrentDecisions := TStringList.Create;
  LCurrentSources := TStringList.Create;
  LNextSources := TStringList.Create;
  LVerdicts := TStringList.Create;
  try
    LoadLines(LDraftDecisions, LDraftDecisionText, 'draft decision');
    LoadLines(LDraftSources, LDraftSourcesText, 'draft sources');
    Require((LDraftDecisions.Count = 2) and (LDraftDecisions[0] = CDecisionHeader),
      'Draft decision table must contain the canonical header and one decision row.');
    Require((LDraftSources.Count >= 1) and (LDraftSources[0] = CSourceHeader),
      'Draft sources table must start with the canonical header.');

    LDecisionRow := LDraftDecisions[1];
    LFields := SplitFields(LDecisionRow, #9);
    Require(Length(LFields) = 5, 'Draft decision row must have 5 tab-separated columns.');
    LClaimId := LFields[0];
    LRationale := LFields[4];
    LDirection := FindFrozenDirection(LExpDir, LClaimId);

    LCheck := TJSONObject.Create;
    try
      AddEvidenceScorecard(LCheck, LDraftDecisionText, LDraftSourcesText, LClaimId,
        LDirection, '', 0, True);
      Require(LCheck.Strings['review_status'] = 'valid_draft',
        'Draft failed rubric validation.');
      LExpectedVerdict := LCheck.Objects['scorecard'].Strings['expected_verdict'];
      LAnchorText := LCheck.Objects['scorecard'].Strings['score_anchor'];
      LAnchorValue := ReadReviewConfidence(LAnchorText, LExpectedVerdict, LClaimId);
    finally
      LCheck.Free;
    end;

    LScorecardsPath := LExpDir + PathDelim + 'followup' + PathDelim + 'scorecards.tsv';
    LSourcesPath := LExpDir + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv';
    LVerdictsPath := LExpDir + PathDelim + 'verdicts.tsv';

    if FileExists(LScorecardsPath) then
    begin
      LoadLines(LCurrentDecisions, String(ReadUtf8Text(LScorecardsPath)), 'scorecards.tsv');
      Require((LCurrentDecisions.Count >= 1) and (LCurrentDecisions[0] = CDecisionHeader),
        'Invalid existing scorecards.tsv header.');
    end
    else
    begin
      LCurrentDecisions.Add(CDecisionHeader);
    end;

    if FileExists(LSourcesPath) then
    begin
      LoadLines(LCurrentSources, String(ReadUtf8Text(LSourcesPath)), 'scorecard-sources.tsv');
      Require((LCurrentSources.Count >= 1) and (LCurrentSources[0] = CSourceHeader),
        'Invalid existing scorecard-sources.tsv header.');
    end
    else
    begin
      LCurrentSources.Add(CSourceHeader);
    end;

    LoadLines(LVerdicts, String(ReadUtf8Text(LVerdictsPath)), 'verdicts.tsv');
    Require((LVerdicts.Count > 1) and (LVerdicts[0] = CVerdictHeader),
      'Invalid existing verdicts.tsv header.');

    LReplacedDecision := False;
    for LIndex := 1 to LCurrentDecisions.Count - 1 do
    begin
      LFields := SplitFields(LCurrentDecisions[LIndex], #9);
      Require(Length(LFields) = 5, 'Malformed existing scorecards.tsv row ' + IntToStr(LIndex + 1));
      if LFields[0] = LClaimId then
      begin
        Require(not LReplacedDecision, 'Duplicate existing decision row for ' + LClaimId);
        LCurrentDecisions[LIndex] := LDecisionRow;
        LReplacedDecision := True;
      end;
    end;
    if not LReplacedDecision then
    begin
      LCurrentDecisions.Add(LDecisionRow);
    end;

    LRemovedSources := 0;
    LNextSources.Add(CSourceHeader);
    for LIndex := 1 to LCurrentSources.Count - 1 do
    begin
      LFields := SplitFields(LCurrentSources[LIndex], #9);
      Require(Length(LFields) = 17,
        'Malformed existing scorecard-sources.tsv row ' + IntToStr(LIndex + 1));
      if LFields[0] = LClaimId then
      begin
        Inc(LRemovedSources);
      end
      else
      begin
        LNextSources.Add(LCurrentSources[LIndex]);
      end;
    end;
    for LIndex := 1 to LDraftSources.Count - 1 do
    begin
      if LDraftSources[LIndex] <> '' then
      begin
        LNextSources.Add(LDraftSources[LIndex]);
      end;
    end;

    LReplacedVerdict := False;
    for LIndex := 1 to LVerdicts.Count - 1 do
    begin
      LFields := SplitFields(LVerdicts[LIndex], #9);
      Require(Length(LFields) = 7, 'Malformed existing verdicts.tsv row ' + IntToStr(LIndex + 1));
      if LFields[0] = LClaimId then
      begin
        Require(not LReplacedVerdict, 'Duplicate verdict row for ' + LClaimId);
        LMergedRefs := MergeReferences(LRoot, LFields[4], LDraftSources);
        Require((LExpectedVerdict = 'Unknown') or (LMergedRefs <> ''),
          'A directional verdict requires at least one verified local reference.');
        LVerdicts[LIndex] := LClaimId + #9 + LExpectedVerdict + #9 + LAnchorText + #9 +
          LRationale + #9 + LMergedRefs + #9 + LFields[5] + #9 + LFields[6];
        LReplacedVerdict := True;
      end;
    end;
    Require(LReplacedVerdict, 'Claim ID not found in verdicts.tsv: ' + LClaimId);

    WriteUtf8Lf(LStaged + PathDelim + 'scorecards.tsv', LCurrentDecisions);
    WriteUtf8Lf(LStaged + PathDelim + 'scorecard-sources.tsv', LNextSources);
    WriteUtf8Lf(LStaged + PathDelim + 'verdicts.tsv', LVerdicts);

    // Re-verify the exact staged bytes against the shared rubric checker.
    LStagedDecisionsText := String(ReadUtf8Text(LStaged + PathDelim + 'scorecards.tsv'));
    LStagedSourcesText := String(ReadUtf8Text(LStaged + PathDelim + 'scorecard-sources.tsv'));
    LCheck := TJSONObject.Create;
    try
      AddEvidenceScorecard(LCheck, LStagedDecisionsText, LStagedSourcesText, LClaimId,
        LDirection, LExpectedVerdict, LAnchorValue, False);
      Require(LCheck.Strings['review_status'] = 'recorded',
        'Staged scorecard failed post-write verification.');
      WriteLn('claim=', LClaimId, ' direction=', LDirection, ' verdict=', LExpectedVerdict,
        ' anchor=', LAnchorText, ' replaced_decision=', BoolToStr(LReplacedDecision, True),
        ' removed_prior_sources=', LRemovedSources, ' staged_sources=', LDraftSources.Count - 1,
        ' total_scorecards=', LCurrentDecisions.Count - 1, ' status=recorded');
    finally
      LCheck.Free;
    end;
  finally
    LVerdicts.Free;
    LNextSources.Free;
    LCurrentSources.Free;
    LCurrentDecisions.Free;
    LDraftSources.Free;
    LDraftDecisions.Free;
  end;
end;

procedure RunBatch(const AExperiment, ADraftDecisionPath, ADraftSourcesPath, AStagedDir: String);
var
  LExpDir: String;
  LRoot: String;
  LStaged: String;
  LFreezeText: UTF8String;
  LFreezeHash: String;
  LDraftDecisionText: String;
  LDraftSourcesText: String;
  LFreezeLines: TStringList;
  LDraftDecisions: TStringList;
  LDraftSources: TStringList;
  LCurrentDecisions: TStringList;
  LCurrentSources: TStringList;
  LNextSources: TStringList;
  LVerdicts: TStringList;
  LDirections: TDictionary<String, String>;
  LDraftMap: TDictionary<String, String>;
  LDraftSrcMap: TObjectDictionary<String, TStringList>;
  LDecisionPos: TDictionary<String, Integer>;
  LVerdictPos: TDictionary<String, Integer>;
  LFields: TFields;
  LClaimId: String;
  LDirection: String;
  LDecisionRow: String;
  LSrcList: TStringList;
  LSingleSrcText: String;
  LCheck: TJSONObject;
  LScorecardIndex: TScorecardIndex;
  LExpectedVerdict: String;
  LAnchorText: String;
  LAnchorValue: Currency;
  LRationale: String;
  LMergedRefs: String;
  LIndex: Integer;
  LJ: Integer;
  LReplaced: Integer;
  LAppended: Integer;
  LRemovedSources: Integer;
  LStagedSources: Integer;
  LScorecardsPath: String;
  LSourcesPath: String;
  LVerdictsPath: String;
  LStagedDecisionsText: String;
  LStagedSourcesText: String;
begin
  LExpDir := ExcludeTrailingPathDelimiter(ExpandFileName(AExperiment));
  Require(DirectoryExists(LExpDir), 'Experiment directory does not exist: ' + LExpDir);
  Require(SameText(ExtractFileName(ExtractFileDir(LExpDir)), 'experiments'),
    'Pass an experiment directory directly beneath experiments/.');
  LRoot := ExtractFileDir(ExtractFileDir(LExpDir));
  LStaged := ExcludeTrailingPathDelimiter(ExpandFileName(AStagedDir));
  Require(not SameFileName(LStaged, LExpDir) and
    not SameFileName(LStaged, LExpDir + PathDelim + 'followup'),
    'Choose a staging directory distinct from the experiment directory.');
  Require(ForceDirectories(LStaged), 'Cannot create staging directory: ' + LStaged);

  LFreezeText := ReadUtf8Text(LExpDir + PathDelim + 'freeze.tsv');
  LFreezeHash := Trim(String(ReadUtf8Text(LExpDir + PathDelim + 'freeze.sha256')));
  Require(Sha256Hex(LFreezeText) = LFreezeHash, 'Frozen claim SHA-256 digest mismatch.');

  LDraftDecisionText := String(ReadUtf8Text(ADraftDecisionPath));
  LDraftSourcesText := String(ReadUtf8Text(ADraftSourcesPath));

  LFreezeLines := TStringList.Create;
  LDraftDecisions := TStringList.Create;
  LDraftSources := TStringList.Create;
  LCurrentDecisions := TStringList.Create;
  LCurrentSources := TStringList.Create;
  LNextSources := TStringList.Create;
  LVerdicts := TStringList.Create;
  LDirections := TDictionary<String, String>.Create;
  LDraftMap := TDictionary<String, String>.Create;
  LDraftSrcMap := TObjectDictionary<String, TStringList>.Create([doOwnsValues]);
  LDecisionPos := TDictionary<String, Integer>.Create;
  LVerdictPos := TDictionary<String, Integer>.Create;
  try
    LoadLines(LFreezeLines, String(LFreezeText), 'freeze.tsv');
    Require((LFreezeLines.Count > 1) and (LFreezeLines[0] = CFreezeHeader),
      'Invalid freeze.tsv header.');
    for LIndex := 1 to LFreezeLines.Count - 1 do
    begin
      LFields := SplitFields(LFreezeLines[LIndex], #9);
      Require(Length(LFields) = 7, 'Malformed freeze.tsv row ' + IntToStr(LIndex + 1));
      Require((LFields[5] = 'reduces') or (LFields[5] = 'worsens'),
        'Unexpected frozen direction for claim ' + LFields[0]);
      LDirections.Add(LFields[0], LFields[5]);
    end;

    LoadLines(LDraftDecisions, LDraftDecisionText, 'draft decisions');
    LoadLines(LDraftSources, LDraftSourcesText, 'draft sources');
    Require((LDraftDecisions.Count >= 2) and (LDraftDecisions[0] = CDecisionHeader),
      'Batch draft decisions must contain canonical header and at least one row.');
    Require((LDraftSources.Count >= 1) and (LDraftSources[0] = CSourceHeader),
      'Batch draft sources must start with canonical header.');

    for LIndex := 1 to LDraftDecisions.Count - 1 do
    begin
      if LDraftDecisions[LIndex] = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LDraftDecisions[LIndex], #9);
      Require(Length(LFields) = 5, 'Draft decision row must have 5 columns at line ' +
        IntToStr(LIndex + 1));
      LClaimId := LFields[0];
      Require(LDirections.ContainsKey(LClaimId), 'Claim ID not in freeze.tsv: ' + LClaimId);
      Require(not LDraftMap.ContainsKey(LClaimId), 'Duplicate batch draft decision for ' + LClaimId);
      LDraftMap.Add(LClaimId, LDraftDecisions[LIndex]);
    end;

    for LIndex := 1 to LDraftSources.Count - 1 do
    begin
      if LDraftSources[LIndex] = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LDraftSources[LIndex], #9);
      Require(Length(LFields) = 17, 'Malformed batch draft source row ' + IntToStr(LIndex + 1));
      LClaimId := LFields[0];
      Require(LDraftMap.ContainsKey(LClaimId),
        'Batch draft source references claim absent from draft decisions: ' + LClaimId);
      if not LDraftSrcMap.TryGetValue(LClaimId, LSrcList) then
      begin
        LSrcList := TStringList.Create;
        LSrcList.Add(CSourceHeader);
        LDraftSrcMap.Add(LClaimId, LSrcList);
      end;
      LSrcList.Add(LDraftSources[LIndex]);
    end;

    LScorecardsPath := LExpDir + PathDelim + 'followup' + PathDelim + 'scorecards.tsv';
    LSourcesPath := LExpDir + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv';
    LVerdictsPath := LExpDir + PathDelim + 'verdicts.tsv';

    if FileExists(LScorecardsPath) then
    begin
      LoadLines(LCurrentDecisions, String(ReadUtf8Text(LScorecardsPath)), 'scorecards.tsv');
      Require((LCurrentDecisions.Count >= 1) and (LCurrentDecisions[0] = CDecisionHeader),
        'Invalid existing scorecards.tsv header.');
    end
    else
    begin
      LCurrentDecisions.Add(CDecisionHeader);
    end;
    for LIndex := 1 to LCurrentDecisions.Count - 1 do
    begin
      LFields := SplitFields(LCurrentDecisions[LIndex], #9);
      Require(Length(LFields) = 5, 'Malformed existing scorecards.tsv row ' + IntToStr(LIndex + 1));
      Require(not LDecisionPos.ContainsKey(LFields[0]),
        'Duplicate existing decision row for ' + LFields[0]);
      LDecisionPos.Add(LFields[0], LIndex);
    end;

    if FileExists(LSourcesPath) then
    begin
      LoadLines(LCurrentSources, String(ReadUtf8Text(LSourcesPath)), 'scorecard-sources.tsv');
      Require((LCurrentSources.Count >= 1) and (LCurrentSources[0] = CSourceHeader),
        'Invalid existing scorecard-sources.tsv header.');
    end
    else
    begin
      LCurrentSources.Add(CSourceHeader);
    end;

    LoadLines(LVerdicts, String(ReadUtf8Text(LVerdictsPath)), 'verdicts.tsv');
    Require((LVerdicts.Count > 1) and (LVerdicts[0] = CVerdictHeader),
      'Invalid existing verdicts.tsv header.');
    for LIndex := 1 to LVerdicts.Count - 1 do
    begin
      LFields := SplitFields(LVerdicts[LIndex], #9);
      Require(Length(LFields) = 7, 'Malformed existing verdicts.tsv row ' + IntToStr(LIndex + 1));
      Require(not LVerdictPos.ContainsKey(LFields[0]),
        'Duplicate verdict row for ' + LFields[0]);
      LVerdictPos.Add(LFields[0], LIndex);
    end;

    LReplaced := 0;
    LAppended := 0;
    for LIndex := 1 to LDraftDecisions.Count - 1 do
    begin
      if LDraftDecisions[LIndex] = '' then
      begin
        Continue;
      end;
      LDecisionRow := LDraftDecisions[LIndex];
      LFields := SplitFields(LDecisionRow, #9);
      LClaimId := LFields[0];
      LRationale := LFields[4];
      LDirection := LDirections[LClaimId];

      if LDraftSrcMap.TryGetValue(LClaimId, LSrcList) then
      begin
        LSingleSrcText := '';
        for LJ := 0 to LSrcList.Count - 1 do
        begin
          LSingleSrcText := LSingleSrcText + LSrcList[LJ] + CLf;
        end;
      end
      else
      begin
        LSrcList := nil;
        LSingleSrcText := CSourceHeader + CLf;
      end;

      LCheck := TJSONObject.Create;
      try
        AddEvidenceScorecard(LCheck, CDecisionHeader + CLf + LDecisionRow + CLf,
          LSingleSrcText, LClaimId, LDirection, '', 0, True);
        Require(LCheck.Strings['review_status'] = 'valid_draft',
          'Draft failed rubric validation for ' + LClaimId);
        LExpectedVerdict := LCheck.Objects['scorecard'].Strings['expected_verdict'];
        LAnchorText := LCheck.Objects['scorecard'].Strings['score_anchor'];
        LAnchorValue := ReadReviewConfidence(LAnchorText, LExpectedVerdict, LClaimId);
      finally
        LCheck.Free;
      end;

      if LDecisionPos.TryGetValue(LClaimId, LJ) then
      begin
        LCurrentDecisions[LJ] := LDecisionRow;
        Inc(LReplaced);
      end
      else
      begin
        LDecisionPos.Add(LClaimId, LCurrentDecisions.Add(LDecisionRow));
        Inc(LAppended);
      end;

      Require(LVerdictPos.TryGetValue(LClaimId, LJ),
        'Claim ID not found in verdicts.tsv: ' + LClaimId);
      LFields := SplitFields(LVerdicts[LJ], #9);
      if LSrcList <> nil then
      begin
        LMergedRefs := MergeReferences(LRoot, LFields[4], LSrcList);
      end
      else
      begin
        LMergedRefs := LFields[4];
      end;
      Require((LExpectedVerdict = 'Unknown') or (LMergedRefs <> ''),
        'A directional verdict requires at least one verified local reference for ' + LClaimId);
      LVerdicts[LJ] := LClaimId + #9 + LExpectedVerdict + #9 + LAnchorText + #9 +
        LRationale + #9 + LMergedRefs + #9 + LFields[5] + #9 + LFields[6];
    end;

    LRemovedSources := 0;
    LStagedSources := 0;
    LNextSources.Add(CSourceHeader);
    for LIndex := 1 to LCurrentSources.Count - 1 do
    begin
      LFields := SplitFields(LCurrentSources[LIndex], #9);
      Require(Length(LFields) = 17,
        'Malformed existing scorecard-sources.tsv row ' + IntToStr(LIndex + 1));
      if LDraftMap.ContainsKey(LFields[0]) then
      begin
        Inc(LRemovedSources);
      end
      else
      begin
        LNextSources.Add(LCurrentSources[LIndex]);
      end;
    end;
    for LIndex := 1 to LDraftSources.Count - 1 do
    begin
      if LDraftSources[LIndex] <> '' then
      begin
        LNextSources.Add(LDraftSources[LIndex]);
        Inc(LStagedSources);
      end;
    end;

    WriteUtf8Lf(LStaged + PathDelim + 'scorecards.tsv', LCurrentDecisions);
    WriteUtf8Lf(LStaged + PathDelim + 'scorecard-sources.tsv', LNextSources);
    WriteUtf8Lf(LStaged + PathDelim + 'verdicts.tsv', LVerdicts);

    LStagedDecisionsText := String(ReadUtf8Text(LStaged + PathDelim + 'scorecards.tsv'));
    LStagedSourcesText := String(ReadUtf8Text(LStaged + PathDelim + 'scorecard-sources.tsv'));
    LScorecardIndex := TScorecardIndex.Create(LStagedDecisionsText, LStagedSourcesText);
    try
      for LIndex := 1 to LDraftDecisions.Count - 1 do
      begin
        if LDraftDecisions[LIndex] = '' then
        begin
          Continue;
        end;
        LFields := SplitFields(LDraftDecisions[LIndex], #9);
        LClaimId := LFields[0];
        LDirection := LDirections[LClaimId];
        LJ := LVerdictPos[LClaimId];
        LFields := SplitFields(LVerdicts[LJ], #9);
        LExpectedVerdict := LFields[1];
        LAnchorValue := ReadReviewConfidence(LFields[2], LExpectedVerdict, LClaimId);
        LCheck := TJSONObject.Create;
        try
          LScorecardIndex.AddEvidenceScorecardFor(LCheck, LClaimId, LDirection, LExpectedVerdict, LAnchorValue);
          Require(LCheck.Strings['review_status'] = 'recorded',
            'Staged batch scorecard failed post-write verification for ' + LClaimId);
        finally
          LCheck.Free;
        end;
      end;
    finally
      LScorecardIndex.Free;
    end;

    WriteLn('batch_claims=', LDraftMap.Count, ' appended=', LAppended, ' replaced=', LReplaced,
      ' removed_prior_sources=', LRemovedSources, ' staged_sources=', LStagedSources,
      ' total_scorecards=', LCurrentDecisions.Count - 1, ' status=recorded');
  finally
    LVerdictPos.Free;
    LDecisionPos.Free;
    LDraftSrcMap.Free;
    LDraftMap.Free;
    LDirections.Free;
    LVerdicts.Free;
    LNextSources.Free;
    LCurrentSources.Free;
    LCurrentDecisions.Free;
    LDraftSources.Free;
    LDraftDecisions.Free;
    LFreezeLines.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if (ParamCount = 5) and (ParamStr(1) = '--batch') then
    begin
      RunBatch(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else
    begin
      Require(ParamCount = 4,
        'Usage: foodexperiment.scorecardmerge [--batch] <experiment-dir> <draft-decision.tsv> ' +
        '<draft-sources.tsv> <staged-output-dir>');
      Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
