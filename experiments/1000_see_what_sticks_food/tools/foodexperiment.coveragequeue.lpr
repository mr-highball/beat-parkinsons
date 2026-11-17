{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentCoverageQueue;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, FPSHA256, foodexperiment.externaldata;

const
  ClaimCount = 1000;
  Tab = #9;
  CategoryNames: array[0..4] of String = ('all', 'food', 'herb', 'oil', 'spice');
  DirectionNames: array[0..2] of String = ('all', 'reduces', 'worsens');
  VerdictNames: array[0..4] of String =
    ('True', 'Maybe True', 'Unknown', 'Maybe False', 'False');
  UnknownVerdict = 2;

type
  TTable = class
  private
    FFile: Text;
    FOpened: Boolean;
    FPath: String;
    FHeader: TFields;
    FRow: TFields;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    function Next: Boolean;
    function Value(const AColumn: String): String;
  end;

  TClaim = record
    Category: Integer;
    Direction: Integer;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    IngredientIndex: Integer;
    Verdict: Integer;
    Assessments: Integer;
    Pending: Integer;
    FirstPassSpecific: Boolean;
    QueryKeys: Int64;
    ArchivedPairs: Int64;
    ExpandedLocalPairs: Int64;
    ExpandedLocalFocusedPairs: Int64;
    DepthAssessments: Int64;
    HasDepth: Boolean;
  end;

  TClaims = array[1..ClaimCount] of TClaim;
  TFreezeCounts = array[1..4, 1..2] of Integer;
  TIngredientGaps = array[0..ClaimCount - 1] of Integer;

  TStratum = record
    Claims: Integer;
    Verdicts: array[0..4] of Integer;
    AnyAssessment: Integer;
    Nonpending: Integer;
    PendingOnly: Integer;
    AssessedWithPending: Integer;
    UnknownGaps: Integer;
    FirstPassSpecific: Integer;
    NonzeroQuery: Integer;
    NonzeroArchive: Integer;
    NonzeroExpanded: Integer;
    DepthCountMismatches: Integer;
  end;

constructor TTable.Create(const APath: String);
var
  LLine: UTF8String;
begin
  inherited Create;
  FPath := APath;
  AssignFile(FFile, APath);
  Reset(FFile);
  FOpened := True;
  SetTextCodePage(FFile, CP_UTF8);
  ReadLn(FFile, LLine);
  if Copy(LLine, 1, 3) = #$EF#$BB#$BF then
  begin
    Delete(LLine, 1, 3);
  end;
  FHeader := SplitFields(LLine, Tab);
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
  LLine: UTF8String;
begin
  Result := not Eof(FFile);
  if Result then
  begin
    ReadLn(FFile, LLine);
    FRow := SplitFields(LLine, Tab);
    if Length(FRow) <> Length(FHeader) then
    begin
      raise EConvertError.Create('TSV row width mismatch in ' + FPath);
    end;
  end;
end;

function TTable.Value(const AColumn: String): String;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FHeader) do
  begin
    if FHeader[LIndex] = AColumn then
    begin
      Exit(FRow[LIndex]);
    end;
  end;
  raise EConvertError.CreateFmt('No %s column in %s', [AColumn, FPath]);
end;

function ClaimId(AIndex: Integer): String;
begin
  Result := Format('%.4d', [AIndex]);
end;

function ClaimIndex(const AId: String): Integer;
begin
  if not TryStrToInt(AId, Result) or (Result < 1) or (Result > ClaimCount) or
    (ClaimId(Result) <> AId) then
  begin
    raise EConvertError.Create('Invalid claim ID ' + AId);
  end;
end;

function LabelIndex(const AValue: String; const ALabels: array of String): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(ALabels) do
  begin
    if AValue = ALabels[LIndex] then
    begin
      Exit(LIndex);
    end;
  end;
  raise EConvertError.Create('Invalid ledger label ' + AValue);
end;

function CountValue(const AValue: String): Int64;
begin
  if not TryStrToInt64(AValue, Result) or (Result < 0) then
  begin
    raise EConvertError.Create('Invalid nonnegative count ' + AValue);
  end;
end;

procedure VerifyFreezeHash(const ARoot: String);
var
  LHash: TStringList;
  LFreeze: TFileStream;
begin
  LHash := TStringList.Create;
  try
    LHash.LoadFromFile(ARoot + 'freeze.sha256', TEncoding.UTF8);
    LFreeze := TFileStream.Create(ARoot + 'freeze.tsv', fmOpenRead or fmShareDenyWrite);
    try
      if (LHash.Count <> 1) or
        not SameText(Trim(LHash[0]), TSHA256.StreamHexa(LFreeze)) then
      begin
        raise EConvertError.Create('Freeze SHA-256 differs from freeze.sha256');
      end;
    finally
      LFreeze.Free;
    end;
  finally
    LHash.Free;
  end;
end;

procedure LoadFreeze(const APath: String; var AClaims: TClaims; AIngredients: TStringList);
var
  LTable: TTable;
  LIndex: Integer;
  LCategory: Integer;
  LDirection: Integer;
  LCounts: TFreezeCounts;
begin
  LCounts := Default(TFreezeCounts);
  LTable := TTable.Create(APath);
  try
    LIndex := 0;
    while LTable.Next do
    begin
      Inc(LIndex);
      if ClaimIndex(LTable.Value('id')) <> LIndex then
      begin
        raise EConvertError.Create('Frozen IDs are not consecutive and ordered');
      end;
      LCategory := LabelIndex(LTable.Value('category'), CategoryNames);
      LDirection := LabelIndex(LTable.Value('direction'), DirectionNames);
      if (LCategory = 0) or (LDirection = 0) then
      begin
        raise EConvertError.Create('Frozen claims require a category and direction');
      end;
      Inc(LCounts[LCategory, LDirection]);
      AClaims[LIndex].Category := LCategory;
      AClaims[LIndex].Direction := LDirection;
      AClaims[LIndex].Ingredient := LTable.Value('ingredient');
      AClaims[LIndex].Preparation := LTable.Value('preparation');
      AClaims[LIndex].Symptom := LTable.Value('symptom');
      AClaims[LIndex].IngredientIndex := AIngredients.IndexOf(AClaims[LIndex].Ingredient);
      if AClaims[LIndex].IngredientIndex < 0 then
      begin
        AClaims[LIndex].IngredientIndex := AIngredients.Add(AClaims[LIndex].Ingredient);
      end;
    end;
    if LIndex <> ClaimCount then
    begin
      raise EConvertError.Create('Freeze must contain 1,000 claims');
    end;
    for LCategory := 1 to High(CategoryNames) do
    begin
      for LDirection := 1 to High(DirectionNames) do
      begin
        if LCounts[LCategory, LDirection] <> 125 then
        begin
          raise EConvertError.Create('Freeze category/direction must contain 125 claims');
        end;
      end;
    end;
  finally
    LTable.Free;
  end;
end;

procedure LoadVerdicts(const APath: String; var AClaims: TClaims);
var
  LTable: TTable;
  LIndex: Integer;
  LCount: Integer;
  LIds: TStringList;
begin
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    LTable := TTable.Create(APath);
    try
      LCount := 0;
      while LTable.Next do
      begin
        LIndex := ClaimIndex(LTable.Value('id'));
        LIds.Add(ClaimId(LIndex));
        AClaims[LIndex].Verdict := LabelIndex(LTable.Value('verdict'), VerdictNames);
        Inc(LCount);
      end;
      if LCount <> ClaimCount then
      begin
        raise EConvertError.Create('Active verdict ledger must cover every frozen claim');
      end;
    finally
      LTable.Free;
    end;
  finally
    LIds.Free;
  end;
end;

procedure LoadDepth(const APath: String; var AClaims: TClaims);
var
  LTable: TTable;
  LIndex: Integer;
  LCount: Integer;
  LClaim: ^TClaim;
begin
  LTable := TTable.Create(APath);
  try
    LCount := 0;
    while LTable.Next do
    begin
      LIndex := ClaimIndex(LTable.Value('id'));
      LClaim := @AClaims[LIndex];
      if LClaim^.HasDepth or
        (CategoryNames[LClaim^.Category] <> LTable.Value('category')) or
        (DirectionNames[LClaim^.Direction] <> LTable.Value('working_direction')) or
        (LClaim^.Ingredient <> LTable.Value('ingredient')) or
        (LClaim^.Preparation <> LTable.Value('preparation')) or
        (LClaim^.Symptom <> LTable.Value('symptom')) then
      begin
        raise EConvertError.Create('Duplicate or inconsistent depth identity ' + ClaimId(LIndex));
      end;
      LClaim^.FirstPassSpecific := StrToBool(LTable.Value('first_pass_claim_specific'));
      LClaim^.QueryKeys := CountValue(LTable.Value('uncapped_claim_query_keys'));
      LClaim^.ArchivedPairs := CountValue(LTable.Value('archived_text_pairs'));
      LClaim^.ExpandedLocalPairs := CountValue(LTable.Value('expanded_local_pairs'));
      LClaim^.ExpandedLocalFocusedPairs := CountValue(LTable.Value('expanded_local_focused_pairs'));
      LClaim^.DepthAssessments := CountValue(LTable.Value('studies_assessed_in_followup'));
      LClaim^.HasDepth := True;
      Inc(LCount);
    end;
    if LCount <> ClaimCount then
    begin
      raise EConvertError.Create('Native depth snapshot must cover every frozen claim');
    end;
  finally
    LTable.Free;
  end;
end;

function LoadAssessments(const APath: String; var AClaims: TClaims): Integer;
const
  CRoles: array[0..4] of String = ('pending', 'related', 'supports', 'opposes', 'inconclusive');
var
  LTable: TTable;
  LKeys: TStringList;
  LId: String;
  LIndex: Integer;
  LStudy: String;
begin
  Result := 0;
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    LKeys.CaseSensitive := True;
    LKeys.Duplicates := dupError;
    LTable := TTable.Create(APath);
    try
      while LTable.Next do
      begin
        LId := LTable.Value('id');
        LIndex := ClaimIndex(LId);
        LStudy := LTable.Value('study');
        if Trim(LStudy) = '' then
        begin
          raise EConvertError.Create('Empty study identifier for claim ' + LId);
        end;
        LKeys.Add(LId + Tab + LStudy);
        Inc(AClaims[LIndex].Assessments);
        if LabelIndex(LTable.Value('role'), CRoles) = 0 then
        begin
          Inc(AClaims[LIndex].Pending);
        end;
        Inc(Result);
      end;
    finally
      LTable.Free;
    end;
  finally
    LKeys.Free;
  end;
end;

function Nonpending(const AClaim: TClaim): Integer;
begin
  Result := AClaim.Assessments - AClaim.Pending;
end;

function IsGap(const AClaim: TClaim): Boolean;
begin
  Result := (AClaim.Verdict = UnknownVerdict) and (Nonpending(AClaim) = 0);
end;

procedure AddClaim(var AStratum: TStratum; const AClaim: TClaim);
begin
  Inc(AStratum.Claims);
  Inc(AStratum.Verdicts[AClaim.Verdict]);
  Inc(AStratum.AnyAssessment, Ord(AClaim.Assessments > 0));
  Inc(AStratum.Nonpending, Ord(Nonpending(AClaim) > 0));
  Inc(AStratum.PendingOnly, Ord((AClaim.Pending > 0) and (Nonpending(AClaim) = 0)));
  Inc(AStratum.AssessedWithPending, Ord((AClaim.Pending > 0) and (Nonpending(AClaim) > 0)));
  Inc(AStratum.UnknownGaps, Ord(IsGap(AClaim)));
  Inc(AStratum.FirstPassSpecific, Ord(AClaim.FirstPassSpecific));
  Inc(AStratum.NonzeroQuery, Ord(AClaim.QueryKeys > 0));
  Inc(AStratum.NonzeroArchive, Ord(AClaim.ArchivedPairs > 0));
  Inc(AStratum.NonzeroExpanded, Ord(AClaim.ExpandedLocalPairs > 0));
  Inc(AStratum.DepthCountMismatches, Ord(AClaim.Assessments <> AClaim.DepthAssessments));
end;

procedure SaveTsv(AOutput: TStringList; const APath: String);
begin
  AOutput.LineBreak := #10;
  AOutput.WriteBOM := False;
  AOutput.SaveToFile(APath, TEncoding.UTF8);
end;

procedure WriteStrata(const AOutput: String; const AClaims: TClaims);
var
  LCoverage: TStringList;
  LGaps: TStringList;
  LCategory: Integer;
  LDirection: Integer;
  LClaim: TClaim;
  LStratum: TStratum;
  LPrefix: String;
begin
  LCoverage := TStringList.Create;
  LGaps := TStringList.Create;
  try
    LCoverage.Add('category'#9'frozen_direction'#9'claims'#9'true'#9'maybe_true'#9'unknown'#9 +
      'maybe_false'#9'false'#9'any_assessment_claims'#9'nonpending_assessment_claims'#9 +
      'first_pass_claim_specific_claims'#9'claim_query_nonzero_claims'#9 +
      'archived_query_join_nonzero_claims'#9'expanded_local_nonzero_claims');
    LGaps.Add('category'#9'frozen_direction'#9'claims'#9'unassessed_claims'#9 +
      'pending_only_claims'#9'assessed_with_pending_claims'#9'unknown_queue_claims'#9 +
      'depth_assessment_count_mismatches');
    for LCategory := 0 to High(CategoryNames) do
    begin
      for LDirection := 0 to High(DirectionNames) do
      begin
        LStratum := Default(TStratum);
        for LClaim in AClaims do
        begin
          if ((LCategory = 0) or (LClaim.Category = LCategory)) and
            ((LDirection = 0) or (LClaim.Direction = LDirection)) then
          begin
            AddClaim(LStratum, LClaim);
          end;
        end;
        LPrefix := CategoryNames[LCategory] + Tab + DirectionNames[LDirection] + Tab +
          IntToStr(LStratum.Claims) + Tab;
        LCoverage.Add(LPrefix + Format('%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d'#9'%d',
          [LStratum.Verdicts[0], LStratum.Verdicts[1], LStratum.Verdicts[2], LStratum.Verdicts[3],
           LStratum.Verdicts[4], LStratum.AnyAssessment, LStratum.Nonpending,
           LStratum.FirstPassSpecific, LStratum.NonzeroQuery, LStratum.NonzeroArchive,
           LStratum.NonzeroExpanded]));
        LGaps.Add(LPrefix + Format('%d'#9'%d'#9'%d'#9'%d'#9'%d',
          [LStratum.Claims - LStratum.AnyAssessment, LStratum.PendingOnly,
           LStratum.AssessedWithPending, LStratum.UnknownGaps, LStratum.DepthCountMismatches]));
      end;
    end;
    SaveTsv(LCoverage, AOutput + 'coverage-strata.tsv');
    SaveTsv(LGaps, AOutput + 'assessment-gaps.tsv');
  finally
    LGaps.Free;
    LCoverage.Free;
  end;
end;

procedure WriteQueue(const AOutput: String; const AClaims: TClaims);
const
  CIdentity = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom';
  CCoverage = 'gap_state'#9'ingredient_gap_claims'#9'query_pairs'#9'archived_pairs'#9 +
    'expanded_local_focused_pairs';
var
  LRanked: TStringList;
  LMasked: TStringList;
  LPrivate: TStringList;
  LIngredientGaps: TIngredientGaps;
  LIndex: Integer;
  LRankKey: String;
  LClaim: TClaim;
  LCount: Integer;
  LState: String;
  LIdentity: String;
  LCoverage: String;
begin
  LIngredientGaps := Default(TIngredientGaps);
  for LClaim in AClaims do
  begin
    if IsGap(LClaim) then
    begin
      Inc(LIngredientGaps[LClaim.IngredientIndex]);
    end;
  end;
  LRanked := TStringList.Create;
  LMasked := TStringList.Create;
  LPrivate := TStringList.Create;
  try
    LRanked.Sorted := True;
    LRanked.CaseSensitive := True;
    for LIndex := 1 to ClaimCount do
    begin
      LClaim := AClaims[LIndex];
      if IsGap(LClaim) then
      begin
        LCount := LIngredientGaps[LClaim.IngredientIndex];
        LRanked.Add(Format('%d'#9'%.4d'#9'%s'#9'%s',
          [Ord(LClaim.Pending > 0), ClaimCount - LCount, LClaim.Ingredient, ClaimId(LIndex)]));
      end;
    end;
    LMasked.Add('rank'#9 + CIdentity + Tab + CCoverage);
    LPrivate.Add('rank'#9 + CIdentity + Tab + 'frozen_direction'#9'assessments'#9'pending'#9 +
      CCoverage);
    for LIndex := 0 to LRanked.Count - 1 do
    begin
      LRankKey := LRanked[LIndex];
      LClaim := AClaims[ClaimIndex(RightStr(LRankKey, 4))];
      LState := 'unassessed';
      if LClaim.Pending > 0 then
      begin
        LState := 'pending_only';
      end;
      LIdentity := Format('%d'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s'#9,
        [LIndex + 1, RightStr(LRankKey, 4), CategoryNames[LClaim.Category], LClaim.Ingredient,
         LClaim.Preparation, LClaim.Symptom]);
      LCoverage := Format('%s'#9'%d'#9'%d'#9'%d'#9'%d',
        [LState, LIngredientGaps[LClaim.IngredientIndex], LClaim.QueryKeys, LClaim.ArchivedPairs,
         LClaim.ExpandedLocalFocusedPairs]);
      LMasked.Add(LIdentity + LCoverage);
      LPrivate.Add(LIdentity + Format('%s'#9'%d'#9'%d'#9,
        [DirectionNames[LClaim.Direction], LClaim.Assessments, LClaim.Pending]) + LCoverage);
    end;
    SaveTsv(LMasked, AOutput + 'claim-gap-queue-masked.tsv');
    SaveTsv(LPrivate, AOutput + 'claim-gap-queue.tsv');
    WriteLn(LRanked.Count, ' Unknown claims with no nonpending assessment');
  finally
    LPrivate.Free;
    LMasked.Free;
    LRanked.Free;
  end;
end;

procedure Run;
var
  LRoot: String;
  LOutput: String;
  LIngredients: TStringList;
  LClaims: TClaims;
  LAssessmentCount: Integer;
begin
  if ParamCount <> 2 then
  begin
    raise EArgumentException.Create('Usage: foodexperiment.coveragequeue EXPERIMENT_DIR OUTPUT_DIR');
  end;
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
  if not DirectoryExists(LOutput) then
  begin
    raise EArgumentException.Create('Output directory must exist');
  end;
  LClaims := Default(TClaims);
  LIngredients := TStringList.Create;
  try
    LIngredients.CaseSensitive := True;
    VerifyFreezeHash(LRoot);
    LoadFreeze(LRoot + 'freeze.tsv', LClaims, LIngredients);
    LoadVerdicts(LRoot + 'verdicts.tsv', LClaims);
    LoadDepth(LRoot + 'followup' + PathDelim + 'claim-depth.tsv', LClaims);
    LAssessmentCount := LoadAssessments(LRoot + 'followup' + PathDelim + 'assessments.tsv', LClaims);
    WriteLn(ClaimCount, ' frozen claims and ', LAssessmentCount, ' active assessments loaded');
    WriteStrata(LOutput, LClaims);
    WriteQueue(LOutput, LClaims);
  finally
    LIngredients.Free;
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
