{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentUnknownAdjudication;

{$mode delphi}
{$H+}

uses Classes, SysUtils, FPSha256, foodexperiment.externaldata;

const
  ClaimCount = 1000;
  EvidenceFingerprintPrefix = 'sha256-v1:';
  EvidenceFingerprintDomain = 'beat-parkinsons:assessment-evidence:v1'#10;
  Categories: array[0..3] of String = ('food', 'herb', 'spice', 'oil');
  Directions: array[0..1] of String = ('reduces', 'worsens');
  Lanes: array[0..4] of String = ('human_comparison_hint', 'open_context_source_hint',
    'other_assessed', 'no_nonpending_assessment', 'prior_weak_lean_adjudication');

type
  TPriorReview = record
    AssessmentRows: Integer;
    Locator: String;
    EvidenceFingerprint: String;
  end;

  TClaim = record
    Category: Integer;
    Direction: Integer;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    Verdict: String;
    References: String;
    PriorReview: TPriorReview;
    EvidenceFingerprint: String;
    Assessments: Integer;
    Pending: Integer;
    Comparisons: Integer;
    UncitedComparisons: Integer;
    AllOriginal: Integer;
    OpenOriginal: Integer;
    PriorityOneOrTwo: Integer;
    PriorityThree: Integer;
    JoinedArchive: Integer;
  end;
  TClaims = array[1..ClaimCount] of TClaim;
  TCounts = array[0..3, 0..1] of Integer;
  TAssessmentDigests = array[1..ClaimCount] of TStringList;
  TBucketLists = array[0..High(Lanes), 0..7] of TStringList;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function ClaimNumber(const AId: String): Integer;
begin
  Result := StrToIntDef(AId, 0);
  Require((Result >= 1) and (Result <= ClaimCount) and (Format('%.4d', [Result]) = AId),
    'Invalid exact claim ID: ' + AId);
end;

function LabelIndex(const AValue: String; const AValues: array of String): Integer;
begin
  for Result := Low(AValues) to High(AValues) do
  begin
    if AValues[Result] = AValue then
    begin
      Exit;
    end;
  end;
  raise EConvertError.Create('Unknown label: ' + AValue);
end;

function ContainsAny(const AValue: String; const AOptions: array of String): Boolean;
var
  LOption: String;
begin
  for LOption in AOptions do
  begin
    if Pos(LOption, AValue) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function HasHumanComparisonHint(const AFit, AAssessment: String): Boolean;
var
  LText: String;
begin
  LText := ' ' + LowerCase(AFit + ' ' + AAssessment) + ' ';
  Result := ContainsAny(LText, ['random', 'crossover', 'cross-over', 'placebo',
      'controlled trial', 'clinical trial', 'between-arm', 'group-by-time', 'adjusted']) and
    ContainsAny(LText, ['human', 'participant', 'patient', 'adult', 'menopaus', 'women',
      ' healthy ', ' volunteers', 'students', 'dietary', 'cohort', 'person']) and
    not ContainsAny(LowerCase(AFit), ['mice', 'mouse', 'rats', ' rat ', 'fly model',
      'animal', 'cell model', 'cell line', 'fibroblast', 'canine', 'rabbit', 'pig bladder']);
end;

procedure SaveTsv(AList: TStringList; const APath: String);
begin
  AList.LineBreak := #10;
  AList.WriteBOM := False;
  AList.SaveToFile(APath, TEncoding.UTF8);
end;

procedure LoadClaims(const AInput: String; var AClaims: TClaims);
var
  LRows: TStringList;
  LStream: TFileStream;
  LFields: TFields;
  LCounts: TCounts;
  LId: Integer;
  LRow: Integer;
  LCategory: Integer;
  LDirection: Integer;
begin
  LCounts := Default(TCounts);
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(AInput + 'freeze.sha256', TEncoding.UTF8);
    LStream := TFileStream.Create(AInput + 'freeze.tsv', fmOpenRead or fmShareDenyWrite);
    try
      Require((LRows.Count = 1) and SameText(Trim(LRows[0]), TSHA256.StreamHexa(LStream)),
        'Freeze SHA-256 differs');
    finally
      LStream.Free;
    end;
    LRows.LoadFromFile(AInput + 'freeze.tsv', TEncoding.UTF8);
    Require((LRows.Count = ClaimCount + 1) and (LRows[0] =
      'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement'),
      'Unexpected freeze schema');
    for LRow := 1 to ClaimCount do
    begin
      LFields := SplitFields(LRows[LRow], #9);
      Require((Length(LFields) = 7) and (ClaimNumber(LFields[0]) = LRow), 'Invalid freeze row');
      LCategory := LabelIndex(LFields[1], Categories);
      LDirection := LabelIndex(LFields[5], Directions);
      Inc(LCounts[LCategory, LDirection]);
      AClaims[LRow].Category := LCategory;
      AClaims[LRow].Direction := LDirection;
      AClaims[LRow].Ingredient := LFields[2];
      AClaims[LRow].Preparation := LFields[3];
      AClaims[LRow].Symptom := LFields[4];
    end;
    for LCategory := 0 to High(Categories) do
    begin
      for LDirection := 0 to High(Directions) do
      begin
        Require(LCounts[LCategory, LDirection] = 125, 'Freeze stratum differs');
      end;
    end;
    LRows.LoadFromFile(AInput + 'verdicts.tsv', TEncoding.UTF8);
    Require((LRows.Count = ClaimCount + 1) and (LRows[0] =
      'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9'search_record'#9'local_verdict'),
      'Unexpected verdict schema');
    for LRow := 1 to ClaimCount do
    begin
      LFields := SplitFields(LRows[LRow], #9);
      Require(Length(LFields) = 7, 'Invalid verdict row');
      LId := ClaimNumber(LFields[0]);
      Require(AClaims[LId].Verdict = '', 'Duplicate verdict ' + LFields[0]);
      LabelIndex(LFields[1], ['True', 'False', 'Unknown', 'Maybe True', 'Maybe False']);
      AClaims[LId].Verdict := LFields[1];
      AClaims[LId].References := '|' + LowerCase(LFields[4]) + '|';
    end;
    LRows.LoadFromFile(AInput + 'coverage-by-claim.tsv', TEncoding.UTF8);
    Require((LRows.Count = ClaimCount + 1) and (LRows[0] = 'id'#9'category'#9'ingredient'#9 +
      'overlay_pairs'#9'joined_archive'#9'no_exact_review_imported'#9'pending_or_access_only'#9 +
      'title_index_reviewed'#9'abstract_context_reviewed'#9'exact_assessment_basis_unspecified'#9 +
      'body_or_primary_context_reviewed'#9'queue_priority_1'#9'queue_priority_2'#9 +
      'queue_priority_3'#9'queue_priority_4'#9'queue_priority_5'#9'queue_priority_6'),
      'Unexpected context coverage schema');
    for LRow := 1 to ClaimCount do
    begin
      LFields := SplitFields(LRows[LRow], #9);
      Require((Length(LFields) = 17) and (ClaimNumber(LFields[0]) = LRow),
        'Invalid context coverage row');
      Require((LFields[1] = Categories[AClaims[LRow].Category]) and
        (LFields[2] = AClaims[LRow].Ingredient), 'Context scope differs from freeze: ' + LFields[0]);
      AClaims[LRow].AllOriginal := StrToInt(LFields[3]);
      AClaims[LRow].JoinedArchive := StrToInt(LFields[4]);
      AClaims[LRow].PriorityOneOrTwo := StrToInt(LFields[11]) + StrToInt(LFields[12]);
      AClaims[LRow].PriorityThree := StrToInt(LFields[13]);
      AClaims[LRow].OpenOriginal := AClaims[LRow].PriorityOneOrTwo + AClaims[LRow].PriorityThree +
        StrToInt(LFields[14]) + StrToInt(LFields[15]) + StrToInt(LFields[16]);
      Require(AClaims[LRow].OpenOriginal <= AClaims[LRow].AllOriginal,
        'Open context count exceeds original denominator ' + LFields[0]);
    end;
  finally
    LRows.Free;
  end;
end;

function EvidenceDigest(const ABytes: RawByteString): String;
var
  LHash: TSHA256;
  LHex: AnsiString;
begin
  LHash.Init;
  if ABytes <> '' then
  begin
    LHash.Update(PByte(Pointer(ABytes)), Length(ABytes));
  end;
  LHash.Final;
  LHash.OutputHexa(LHex);
  Result := LowerCase(LHex);
end;

function ClaimEvidenceFingerprint(AId: Integer; ADigests: TStringList): String;
var
  LPayload: UTF8String;
begin
  LPayload := EvidenceFingerprintDomain + UTF8String(Format('%.4d'#10, [AId]));
  if Assigned(ADigests) then
  begin
    ADigests.Sort;
    LPayload := LPayload + UTF8String(ADigests.Text);
  end;
  Result := EvidenceFingerprintPrefix + EvidenceDigest(LPayload);
end;

procedure LoadAssessments(const AInput: String; var AClaims: TClaims; AHints: TStringList);
var
  LFile: Text;
  LLine: UTF8String;
  LFields: TFields;
  LDigests: TAssessmentDigests;
  LId: Integer;
  LRole: String;
  LHasHint: Boolean;
  LCited: Boolean;
begin
  LDigests := Default(TAssessmentDigests);
  AssignFile(LFile, AInput + 'assessments.tsv');
  Reset(LFile);
  try
    SetTextCodePage(LFile, CP_UTF8);
    Require(not Eof(LFile), 'Unexpected assessment schema');
    ReadLn(LFile, LLine);
    if (Length(LLine) >= 3) and (Byte(LLine[1]) = $EF) and
      (Byte(LLine[2]) = $BB) and (Byte(LLine[3]) = $BF) then
    begin
      Delete(LLine, 1, 3);
    end;
    Require(LLine = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment',
      'Unexpected assessment schema');
    AHints.Add('id'#9'study'#9'evidence_role'#9'research_locator'#9 +
      'human_comparison_text_hint'#9'exact_reference_in_current_verdict');
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, #9);
      Require(Length(LFields) = 6, 'Invalid assessment row');
      LId := ClaimNumber(LFields[0]);
      LRole := LFields[2];
      LabelIndex(LRole, ['related', 'pending', 'inconclusive', 'excluded', 'supports', 'opposes']);
      if not Assigned(LDigests[LId]) then
      begin
        LDigests[LId] := TStringList.Create;
        LDigests[LId].CaseSensitive := True;
        LDigests[LId].UseLocale := False;
        LDigests[LId].LineBreak := #10;
      end;
      // Hash raw UTF-8 field bytes after the claim ID and retain repeated rows.
      LDigests[LId].Add(EvidenceDigest(Copy(LLine, Pos(#9, LLine) + 1, Length(LLine))));
      Inc(AClaims[LId].Assessments);
      if LRole = 'pending' then
      begin
        Inc(AClaims[LId].Pending);
      end;
      if AClaims[LId].Verdict <> 'Unknown' then
      begin
        Continue;
      end;
      LCited := (LFields[4] <> '') and
        (Pos('|' + LowerCase(LFields[4]) + '|', AClaims[LId].References) > 0);
      LHasHint := (LRole <> 'pending') and (LRole <> 'excluded') and
        HasHumanComparisonHint(LFields[3], LFields[5]);
      if LHasHint then
      begin
        Inc(AClaims[LId].Comparisons);
        if not LCited then
        begin
          Inc(AClaims[LId].UncitedComparisons);
        end;
      end;
      AHints.Add(Format('%s'#9'%s'#9'%s'#9'%s'#9'%d'#9'%d',
        [LFields[0], LFields[1], LRole, LFields[4], Ord(LHasHint), Ord(LCited)]));
    end;
    for LId := 1 to ClaimCount do
    begin
      AClaims[LId].EvidenceFingerprint := ClaimEvidenceFingerprint(LId, LDigests[LId]);
    end;
  finally
    for LId := 1 to ClaimCount do
    begin
      LDigests[LId].Free;
    end;
    CloseFile(LFile);
  end;
end;

procedure ValidateAuditLocator(const ALocator, AId: String);
var
  LParts: TFields;
  LSegment: String;
begin
  LParts := SplitFields(ALocator, '#');
  Require((Length(LParts) in [1, 2]) and (ALocator = Trim(ALocator)) and
    (Pos(':', ALocator) = 0) and (Pos('\', ALocator) = 0),
    'Invalid audit locator: ' + AId);
  if Length(LParts) = 2 then
  begin
    Require(Trim(LParts[1]) <> '', 'Empty audit locator fragment: ' + AId);
  end;
  for LSegment in SplitFields(LParts[0], '/') do
  begin
    Require((LSegment <> '') and (LSegment <> '.') and (LSegment <> '..') and
      (LSegment = Trim(LSegment)), 'Invalid relative audit locator: ' + AId);
  end;
end;

function ParseReviewedFingerprint(const AValue, AId: String): String;
var
  LIndex: Integer;
  LPrefixLength: Integer;
begin
  Result := LowerCase(AValue);
  if Result = '' then
  begin
    Exit;
  end;
  LPrefixLength := Length(EvidenceFingerprintPrefix);
  Require((Length(Result) = LPrefixLength + 64) and
    (Copy(Result, 1, LPrefixLength) = EvidenceFingerprintPrefix),
    'Invalid reviewed evidence fingerprint: ' + AId);
  for LIndex := LPrefixLength + 1 to Length(Result) do
  begin
    Require(Result[LIndex] in ['0'..'9', 'a'..'f'], 'Invalid reviewed evidence fingerprint: ' + AId);
  end;
end;

procedure LoadPriorReviews(const AInput: String; var AClaims: TClaims);
const
  CPriorHeader = 'id'#9'reviewed_assessment_rows'#9'audit_locator';
var
  LRows: TStringList;
  LFields: TFields;
  LRow: Integer;
  LId: Integer;
  LCount: Integer;
  LExpectedFields: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(AInput + 'prior-adjudications.tsv', TEncoding.UTF8);
    Require((LRows.Count > 0) and ((LRows[0] = CPriorHeader) or
      (LRows[0] = CPriorHeader + #9'reviewed_evidence_fingerprint')), 'Unexpected prior review schema');
    LExpectedFields := Length(SplitFields(LRows[0], #9));
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], #9);
      Require(Length(LFields) = LExpectedFields, 'Invalid prior review row: ' + IntToStr(LRow + 1));
      LId := ClaimNumber(LFields[0]);
      Require(AClaims[LId].PriorReview.Locator = '', 'Duplicate prior review ID: ' + LFields[0]);
      Require(TryStrToInt(LFields[1], LCount) and (LCount >= 0) and
        (IntToStr(LCount) = LFields[1]), 'Invalid reviewed assessment count: ' + LFields[0]);
      ValidateAuditLocator(LFields[2], LFields[0]);
      AClaims[LId].PriorReview.AssessmentRows := LCount;
      AClaims[LId].PriorReview.Locator := LFields[2];
      if LExpectedFields = 4 then
      begin
        AClaims[LId].PriorReview.EvidenceFingerprint :=
          ParseReviewedFingerprint(LFields[3], LFields[0]);
      end;
    end;
  finally
    LRows.Free;
  end;
end;

function PriorReviewState(const AClaim: TClaim): String;
begin
  if AClaim.PriorReview.Locator = '' then
  begin
    Exit('none');
  end;
  if AClaim.PriorReview.AssessmentRows <> AClaim.Assessments then
  begin
    Exit('assessment_count_changed');
  end;
  if (AClaim.PriorReview.EvidenceFingerprint <> '') and
    (AClaim.PriorReview.EvidenceFingerprint <> AClaim.EvidenceFingerprint) then
  begin
    Exit('assessment_evidence_changed');
  end;
  Result := 'current';
end;

function PriorReviewColumns(const AClaim: TClaim): String;
begin
  Result := PriorReviewState(AClaim) + #9;
  if AClaim.PriorReview.Locator <> '' then
  begin
    Result := Result + IntToStr(AClaim.PriorReview.AssessmentRows);
  end;
  Result := Result + #9 + AClaim.PriorReview.Locator + #9 +
    AClaim.PriorReview.EvidenceFingerprint + #9 + AClaim.EvidenceFingerprint;
end;

function ReviewLane(const AClaim: TClaim): Integer;
begin
  if PriorReviewState(AClaim) = 'current' then
  begin
    Exit(4);
  end;
  if AClaim.Comparisons > 0 then
  begin
    Exit(0);
  end;
  if AClaim.Assessments = AClaim.Pending then
  begin
    Exit(3);
  end;
  if (AClaim.PriorityOneOrTwo > 0) or (AClaim.PriorityThree > 0) then
  begin
    Exit(1);
  end;
  Result := 2;
end;

procedure WritePriorReviews(const AOutput: String; const AClaims: TClaims);
var
  LReviews: TStringList;
  LIndex: Integer;
  LClaim: TClaim;
  LRoute: String;
begin
  LReviews := TStringList.Create;
  try
    LReviews.Add('id'#9'current_verdict'#9'current_assessment_rows'#9'next_review'#9 +
      'prior_review_state'#9'reviewed_assessment_rows'#9'audit_locator'#9 +
      'reviewed_evidence_fingerprint'#9'current_evidence_fingerprint');
    for LIndex := 1 to ClaimCount do
    begin
      LClaim := AClaims[LIndex];
      if LClaim.PriorReview.Locator = '' then
      begin
        Continue;
      end;
      LRoute := 'no_longer_unknown';
      if LClaim.Verdict = 'Unknown' then
      begin
        LRoute := Lanes[ReviewLane(LClaim)];
      end;
      LReviews.Add(Format('%.4d'#9'%s'#9'%d'#9'%s'#9, [LIndex, LClaim.Verdict,
        LClaim.Assessments, LRoute]) + PriorReviewColumns(LClaim));
    end;
    SaveTsv(LReviews, AOutput + 'prior-review-status.tsv');
    WriteLn(LReviews.Count - 1, ' prior review records retained');
  finally
    LReviews.Free;
  end;
end;

procedure WriteEvidenceFingerprints(const AOutput: String; const AClaims: TClaims);
var
  LRows: TStringList;
  LId: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Add('id'#9'current_assessment_rows'#9'current_evidence_fingerprint');
    for LId := 1 to ClaimCount do
    begin
      LRows.Add(Format('%.4d'#9'%d'#9'%s', [LId, AClaims[LId].Assessments,
        AClaims[LId].EvidenceFingerprint]));
    end;
    SaveTsv(LRows, AOutput + 'claim-evidence-fingerprints.tsv');
  finally
    LRows.Free;
  end;
end;

procedure WriteQueue(const AOutput: String; const AClaims: TClaims);
var
  LBuckets: TBucketLists;
  LCounts: TCounts;
  LQueue: TStringList;
  LStrata: TStringList;
  LRanked: TStringList;
  LIndex: Integer;
  LLane: Integer;
  LStratum: Integer;
  LRound: Integer;
  LUnknown: Integer;
  LQueued: Integer;
  LClaim: TClaim;
  LId: String;
  LKey: String;
  LDidWrite: Boolean;
begin
  LCounts := Default(TCounts);
  LUnknown := 0;
  LQueued := 0;
  LQueue := TStringList.Create;
  LStrata := TStringList.Create;
  for LLane := 0 to High(Lanes) do
  begin
    for LStratum := 0 to 7 do
    begin
      LBuckets[LLane, LStratum] := TStringList.Create;
      LBuckets[LLane, LStratum].Sorted := True;
      LBuckets[LLane, LStratum].Duplicates := dupError;
    end;
  end;
  try
    LQueue.Add('rank'#9'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'next_review'#9 +
      'assessments'#9'pending_assessments'#9'human_comparison_hints'#9'uncited_comparison_hints'#9 +
      'original_pairs'#9'open_original_pairs'#9'priority_1or2'#9'priority_3'#9'joined_archive'#9 +
      'prior_review_state'#9'reviewed_assessment_rows'#9'audit_locator'#9 +
      'reviewed_evidence_fingerprint'#9'current_evidence_fingerprint');
    LStrata.Add('category'#9'frozen_direction'#9'frozen_denominator'#9'unknown'#9'next_review'#9 +
      'lane_claims');
    for LIndex := 1 to ClaimCount do
    begin
      LClaim := AClaims[LIndex];
      if LClaim.Verdict <> 'Unknown' then
      begin
        Continue;
      end;
      Inc(LUnknown);
      Inc(LCounts[LClaim.Category, LClaim.Direction]);
      LId := Format('%.4d', [LIndex]);
      LLane := ReviewLane(LClaim);
      LKey := Format('%.10d%s', [Ord(LClaim.UncitedComparisons = 0), LId]);
      LBuckets[LLane, LClaim.Category * 2 + LClaim.Direction].Add(LKey);
    end;
    for LLane := 0 to High(Lanes) do
    begin
      LRound := 0;
      repeat
        LDidWrite := False;
        for LStratum := 0 to 7 do
        begin
          LRanked := LBuckets[LLane, LStratum];
          if LRound >= LRanked.Count then
          begin
            Continue;
          end;
          LId := Copy(LRanked[LRound], 11, 4);
          LClaim := AClaims[ClaimNumber(LId)];
          Inc(LQueued);
          LDidWrite := True;
          LQueue.Add(Format('%d'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9 +
            '%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
            [LQueued, LId, Categories[LClaim.Category], LClaim.Ingredient, LClaim.Preparation,
            LClaim.Symptom, Lanes[LLane], LClaim.Assessments, LClaim.Pending, LClaim.Comparisons,
            LClaim.UncitedComparisons, LClaim.AllOriginal, LClaim.OpenOriginal,
            LClaim.PriorityOneOrTwo, LClaim.PriorityThree, LClaim.JoinedArchive]) + #9 +
            PriorReviewColumns(LClaim));
        end;
        Inc(LRound);
      until not LDidWrite;
      for LStratum := 0 to 7 do
      begin
        LStrata.Add(Format('%s'#9'%s'#9'125'#9'%d'#9'%s'#9'%d',
          [Categories[LStratum div 2], Directions[LStratum mod 2],
          LCounts[LStratum div 2, LStratum mod 2], Lanes[LLane], LBuckets[LLane, LStratum].Count]));
      end;
    end;
    Require((LQueued = LUnknown) and (LQueued = LQueue.Count - 1), 'Unknown membership lost');
    SaveTsv(LQueue, AOutput + 'unknown-worklist-masked.tsv');
    SaveTsv(LStrata, AOutput + 'unknown-worklist-strata.tsv');
    WriteLn(LUnknown, ' Unknown claims emitted once across all eight balanced freeze strata');
  finally
    for LLane := 0 to High(Lanes) do
    begin
      for LStratum := 0 to 7 do
      begin
        LBuckets[LLane, LStratum].Free;
      end;
    end;
    LStrata.Free;
    LQueue.Free;
  end;
end;

procedure Run;
var
  LClaims: TClaims;
  LInput: String;
  LOutput: String;
  LHints: TStringList;
begin
  Require(ParamCount = 2, 'Usage: foodexperiment.unknownadjudication INPUT_DIR OUTPUT_DIR');
  LInput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
  Require(DirectoryExists(LOutput), 'Output directory must exist');
  LClaims := Default(TClaims);
  LHints := TStringList.Create;
  try
    LoadClaims(LInput, LClaims);
    LoadPriorReviews(LInput, LClaims);
    LoadAssessments(LInput, LClaims, LHints);
    WriteQueue(LOutput, LClaims);
    WritePriorReviews(LOutput, LClaims);
    WriteEvidenceFingerprints(LOutput, LClaims);
    SaveTsv(LHints, LOutput + 'unknown-assessment-locators.tsv');
    WriteLn(LHints.Count - 1, ' current Unknown assessment rows retained separately');
  finally
    LHints.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
