{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.claims;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses Classes, Process, SysUtils, Generics.Collections, fpjson;

const
  CRoundCount = 7;

type
  TClaimQuery = record
    Symptom: String;
    Ingredient: String;
    Preparation: String;
    Direction: String;
    Trend: String;
    Scope: String;
    Verdict: String;
    ScorecardStatus: String;
    ResearchStatus: String;
    OmitCulture: Boolean;
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
    Confidence: Currency;
    Rationale: String;
    ScorecardStatus: String;
    ResearchStatus: String;
    LabClinicalChecked: Boolean;
    CulturalChecked: Boolean;
    ScorecardChecked: Boolean;
    LastCheckedUtc: String;
    SearchBasis: String;
    OpenGaps: String;
    References: TJSONArray;
    Evidence: TJSONArray;
    AssessedRows: Integer;
    PendingRows: Integer;
    OriginalPairs: Integer;
    QueuedPairs: Integer;
    constructor Create;
    destructor Destroy; override;
    function IsDirectional: Boolean;
    function DisplayVerdict: String;
    function View(ADetailed: Boolean; AAssessmentOffset: Integer = 0;
      AAssessmentLimit: Integer = -1; const AAssessmentStudy: String = ''): TJSONObject;
  end;

  TClaimDecision = (cdInclude, cdIdentityExcluded, cdPremiseExcluded, cdEvidenceExcluded);
  TClaimDecisions = array[0..7] of TClaimDecision;

  TClaimIndex = class
  private
    FRoot: String;
    FRevision: String;
    FRubric: String;
    FScorecards: array[1..CRoundCount] of String;
    FScorecardSources: array[1..CRoundCount] of String;
    FResearchStatus: array[1..CRoundCount] of String;
    FClaims: TObjectList<TClaim>;
    FIdentities: TDictionary<String, TClaim>;
    FBySymptom: TObjectDictionary<String, TList<TClaim>>;
    FByIngredient: TObjectDictionary<String, TList<TClaim>>;
    FByTrend: TObjectDictionary<String, TList<TClaim>>;
    FSymptomAliases: TDictionary<String, String>;
    FIngredientAliases: TDictionary<String, String>;
    FCulturalSources: TJSONArray;
    FSourceRows: Integer;
    FDirectional: Integer;
    FUnknown: Integer;
    FUnknownResearched: Integer;
    FUnknownUnresearched: Integer;
    FV1Scorecards: Integer;
    FDirectionalWithScorecard: Integer;
    FDirectionalWithoutScorecard: Integer;
    FScorecardMismatches: Integer;
    FDecisions: TClaimDecisions;
    {$IFDEF WINDOWS}
    FMayPinLooseHead: Boolean;
    FHeadRef: String;
    FHeadBytes: RawByteString;
    FHeadRefBytes: RawByteString;
    FConfigBytes: RawByteString;
    procedure LoadGitRevision(out ASimpleLayout: Boolean);
    procedure PinLooseHead;
    function LooseHeadIsCurrent: Boolean;
    {$ENDIF}
    function Git(const AArguments: array of String): String;
    function ReadBlob(AProcess: TProcess; const APath: String): String;
    function LoadCulturalSources: TJSONArray;
    function CulturalMatches(const ASymptom, AIngredient: String): TJSONArray;
    procedure LoadRound(ARound: Integer; AProcess: TProcess; APublishedTables: TStrings);
    procedure LoadScorecardStatuses;
    procedure LoadResearchStatuses;
  public
    constructor Create(const ARepoRoot: String);
    destructor Destroy; override;
    function IsCurrent: Boolean;
    function Status: TJSONObject;
    function Backlog: TJSONObject;
    function Query(const AQuery: TClaimQuery): TJSONObject;
    function Ingredients(ASymptoms: TJSONArray): TJSONObject;
    function Claim(ARound: Integer; const AId: String; AAssessmentOffset: Integer;
      AAssessmentLimit: Integer; const AAssessmentStudy: String;
      AIncludeCulture: Boolean = True): TJSONObject;
    function EvidenceRubric(ARound: Integer; const AId: String;
      AIncludeRules: Boolean): TJSONObject;
    function CheckScorecard(ARound: Integer;
      const AId, ARevision, ADecision, ASources: String): TJSONObject;
    function FilterOptions: TJSONObject;
    function StaticModel(const ARepository: String): TJSONObject;
  end;

implementation

uses {$IFDEF WINDOWS}Windows,{$ENDIF} StrUtils, parkinsonsoracle.compat, foodexperiment.externaldata,
  foodexperiment.confidence, foodexperiment.auditstatus, parkinsonsoracle.trend,
  parkinsonsoracle.rubric, parkinsonsoracle.ingredients, parkinsonsoracle.presentation,
  parkinsonsoracle.culture, wfc;

const
  CBase = 'experiments/1000_see_what_sticks_food';
  CVerdictPath = '/verdicts.tsv';
  CRubricPath = CBase + '/EVIDENCE-SCORECARD.md';
  CScorecardPath = '/followup/scorecards.tsv';
  CScorecardSourcesPath = '/followup/scorecard-sources.tsv';
  CResearchStatusPath = '/followup/research-status.tsv';
  CEvidencePath = '/followup/assessments.tsv';
  CCoveragePath = '/followup/context-coverage/coverage-by-claim.tsv';
  CIdentityBit = 4;
  CPremiseBit = 2;
  CEvidenceBit = 1;
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CVerdictHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9'search_record'#9 +
    'local_verdict';
  CEvidenceHeader = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment';
  CCoverageHeader = 'id'#9'category'#9'ingredient'#9'overlay_pairs'#9'joined_archive'#9 +
    'no_exact_review_imported'#9'pending_or_access_only'#9'title_index_reviewed'#9 +
    'abstract_context_reviewed'#9'exact_assessment_basis_unspecified'#9 +
    'body_or_primary_context_reviewed'#9'queue_priority_1'#9'queue_priority_2'#9 +
    'queue_priority_3'#9'queue_priority_4'#9'queue_priority_5'#9'queue_priority_6';

function ExperimentPath(ARound: Integer): String;
begin
  Result := CBase;
  if ARound > 1 then
  begin
    Result := Result + '_round_' + IntToStr(ARound);
  end;
end;

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
begin
  Result := ComputeSha256Hex(RawByteString(AData));
end;

constructor TClaim.Create;
begin
  inherited Create;
  Confidence := -1;
  OriginalPairs := -1;
  QueuedPairs := -1;
  Verdict := 'Unreviewed';
  ScorecardStatus := 'no_scorecard';
  ResearchStatus := 'unreviewed';
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

function TClaim.DisplayVerdict: String;
begin
  Result := DisplayVerdictLabel(Verdict, ResearchStatus);
end;

function TClaim.View(ADetailed: Boolean; AAssessmentOffset, AAssessmentLimit: Integer;
  const AAssessmentStudy: String): TJSONObject;
var
  LPage: TJSONArray;
  LStop: Integer;
  LIndex: Integer;
  LAssessment: TJSONObject;
begin
  Result := TJSONObject.Create([
    'round', Round, 'claim_id', Id, 'category', Category, 'ingredient', Ingredient,
    'preparation', Preparation, 'symptom', Symptom, 'hypothesis_direction', Direction,
    'verdict', Verdict, 'display_verdict', DisplayVerdict, 'research_status', ResearchStatus,
    'assessment_rows', AssessedRows + PendingRows,
    'nonpending_assessments', AssessedRows, 'pending_assessments', PendingRows]);
  try
    if Confidence >= 0 then
    begin
      if Frac(Confidence) = 0 then
        Result.Add('confidence', Trunc(Confidence))
      else
        Result.Add('confidence', Double(Confidence));
    end;
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
      Result.Add('scorecard_status', ScorecardStatus);
      if LastCheckedUtc <> '' then
      begin
        Result.Add('research_audit', TJSONObject.Create([
          'lab_clinical_checked', LabClinicalChecked,
          'cultural_checked', CulturalChecked,
          'scorecard_checked', ScorecardChecked,
          'last_checked_utc', LastCheckedUtc,
          'search_basis', SearchBasis,
          'open_gaps', OpenGaps]));
      end;
      Result.Add('local_references', References.Clone);
      if (AAssessmentStudy = '') and (AAssessmentLimit < 0) then
      begin
        Result.Add('assessments', Evidence.Clone);
        Exit;
      end;
      LPage := TJSONArray.Create;
      Result.Add('assessments', LPage);
      if AAssessmentStudy <> '' then
      begin
        for LIndex := 0 to Evidence.Count - 1 do
        begin
          LAssessment := Evidence.Objects[LIndex];
          if LAssessment.Strings['study'] = AAssessmentStudy then
          begin
            LPage.Add(LAssessment.Clone);
          end;
        end;
        Result.Add('assessment_study', AAssessmentStudy);
        Result.Add('matching_assessments', LPage.Count);
        Exit;
      end;
      Result.Add('assessment_offset', AAssessmentOffset);
      LStop := Evidence.Count;
      // Bound the addition by the available rows, including for an offset past the end.
      if (AAssessmentOffset < LStop) and (AAssessmentLimit < LStop - AAssessmentOffset) then
      begin
        LStop := AAssessmentOffset + AAssessmentLimit;
      end;
      for LIndex := AAssessmentOffset to LStop - 1 do
      begin
        LPage.Add(Evidence.Items[LIndex].Clone);
      end;
      if LStop < Evidence.Count then
        Result.Add('next_assessment_offset', LStop)
      else
        Result.Add('next_assessment_offset', TJSONNull.Create);
    end
    else if References.Count > 0 then
      Result.Add('first_local_reference', References.Strings[0]);
  except
    Result.Free;
    raise;
  end;
end;

function ClaimDecisionIndex(AIdentity, APremise, AEvidence: Boolean): Integer; inline;
begin
  Result := (Ord(AIdentity) * CIdentityBit) or (Ord(APremise) * CPremiseBit) or
    (Ord(AEvidence) * CEvidenceBit);
end;

function CompileClaimDecisions: TClaimDecisions;
var
  LGraph: TGraph;
  LReport: TGraphSolveReport;
  LIndex: Integer;
  LPass: Integer;
  LDecision: Integer;
begin
  // Only the three local pass results affect a decision. Solve all combinations once.
  LGraph := TGraph.Create;
  try
    LGraph.Seed := 0;
    LGraph.Reshape(Length(Result), 1, 1);
    LGraph.WrapNeighbors := False;
    LGraph.CurrentPass := 'identity';
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('match');
    LGraph.AddValue('other');
    for LIndex := Low(Result) to High(Result) do
    begin
      if (LIndex and CIdentityBit) <> 0 then
        LGraph.Entry[LIndex, 0, 0].Value := 'match'
      else
        LGraph.Entry[LIndex, 0, 0].Value := 'other';
    end;
    LGraph.SwitchToPass('premise');
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('match');
    LGraph.AddValue('other');
    for LIndex := Low(Result) to High(Result) do
    begin
      if (LIndex and CPremiseBit) <> 0 then
        LGraph.Entry[LIndex, 0, 0].Value := 'match'
      else
        LGraph.Entry[LIndex, 0, 0].Value := 'other';
    end;
    LGraph.SwitchToPass('evidence');
    LGraph.PassMode := gpmOverlay;
    LGraph.AddValue('eligible');
    LGraph.AddValue('ineligible');
    for LIndex := Low(Result) to High(Result) do
    begin
      if (LIndex and CEvidenceBit) <> 0 then
        LGraph.Entry[LIndex, 0, 0].Value := 'eligible'
      else
        LGraph.Entry[LIndex, 0, 0].Value := 'ineligible';
    end;
    LGraph.SwitchToPass('decision', LPass);
    LGraph.PassMode := gpmOverlay;

    // These branches are disjoint. Each combination has one decision, independent of seed.
    LGraph.AddValue('include').RequireFromPass('identity', 'match')
      .RequireFromPass('premise', 'match').RequireFromPass('evidence', 'eligible');
    LGraph.AddValue('identity_excluded').RequireFromPass('identity', 'other');
    LGraph.AddValue('premise_excluded').RequireFromPass('identity', 'match')
      .RequireFromPass('premise', 'other');
    LGraph.AddValue('evidence_excluded').RequireFromPass('identity', 'match')
      .RequireFromPass('premise', 'match').RequireFromPass('evidence', 'ineligible');
    if not LGraph.TrySolve(DefaultGraphSolveOptions, LReport) then
    begin
      raise EConvertError.CreateFmt('Constraint graph failed at pass %d.', [LReport.FailedPassIndex]);
    end;
    for LIndex := Low(Result) to High(Result) do
    begin
      LDecision := IndexStr(LGraph.PassGraph[LPass].Entry[LIndex, 0, 0].Value,
        ['include', 'identity_excluded', 'premise_excluded', 'evidence_excluded']);
      if LDecision < 0 then
      begin
        raise EConvertError.Create('Constraint graph returned an unknown decision.');
      end;
      Result[LIndex] := TClaimDecision(LDecision);
    end;
  finally
    LGraph.Free;
  end;
end;

{$IFDEF WINDOWS}
function RegularGitDirectory(const APath: String): Boolean;
var
  LAttributes: DWORD;
begin
  LAttributes := GetFileAttributesW(PWideChar(UTF8Decode(APath)));
  Result := (LAttributes <> INVALID_FILE_ATTRIBUTES) and
    ((LAttributes and (FILE_ATTRIBUTE_DIRECTORY or FILE_ATTRIBUTE_REPARSE_POINT)) =
      FILE_ATTRIBUTE_DIRECTORY);
end;

function SimpleGitLayout(const ADirectory: String): Boolean;
begin
  Result := RegularGitDirectory(ExcludeTrailingPathDelimiter(ADirectory)) and
    RegularGitDirectory(ADirectory + 'objects') and RegularGitDirectory(ADirectory + 'refs') and
    RegularGitDirectory(ADirectory + 'refs/heads') and
    (GetFileAttributesW(PWideChar(UTF8Decode(ADirectory + 'commondir'))) = INVALID_FILE_ATTRIBUTES) and
    (GetLastError = ERROR_FILE_NOT_FOUND);
end;

function ReadGitMetadata(const APath: String; out AData: RawByteString): Boolean;
const
  CMaxMetadataBytes = 8192;
  COpenReparsePoint = $00200000;
var
  LHandle: THandle;
  LInfo: TByHandleFileInformation;
  LBytes: DWORD;
begin
  Result := False;
  // Share deletes and close promptly so Git can replace a loose ref.
  LHandle := CreateFileW(PWideChar(UTF8Decode(APath)), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    COpenReparsePoint, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    Exit;
  end;
  try
    if (GetFileType(LHandle) <> FILE_TYPE_DISK) or
      not GetFileInformationByHandle(LHandle, LInfo) or
      ((LInfo.dwFileAttributes and (FILE_ATTRIBUTE_REPARSE_POINT or FILE_ATTRIBUTE_DIRECTORY)) <> 0) or
      (LInfo.nFileSizeHigh <> 0) or (LInfo.nFileSizeLow > CMaxMetadataBytes) then
    begin
      Exit;
    end;
    SetLength(AData, LInfo.nFileSizeLow + 1);
    if ReadFile(LHandle, AData[1], Length(AData), LBytes, nil) and (LBytes = LInfo.nFileSizeLow) then
    begin
      SetLength(AData, LBytes);
      Result := True;
    end;
  finally
    CloseHandle(LHandle);
  end;
end;

procedure TClaimIndex.LoadGitRevision(out ASimpleLayout: Boolean);
var
  LLayout: TStringList;
  LGitResult: String;
begin
  ASimpleLayout := False;
  if RunCommandIndir(FRoot, 'git', ['rev-parse', '--git-dir', '--git-common-dir',
    '--verify', 'HEAD'], LGitResult, [], swoHide) then
  begin
    LLayout := TStringList.Create;
    try
      LLayout.Text := LGitResult;
      if LLayout.Count = 3 then
      begin
        FRevision := Trim(LLayout[2]);
        ASimpleLayout := (LLayout[0] = '.git') and (LLayout[1] = '.git');
        Exit;
      end;
    finally
      LLayout.Free;
    end;
  end;
  FRevision := Trim(Git(['rev-parse', '--verify', 'HEAD']));
end;

procedure TClaimIndex.PinLooseHead;
const
  CBranchPrefix = 'ref: refs/heads/';
var
  LGitDir: String;
  LBranch: String;
  LRef: String;
  LChar: AnsiChar;
  LHead: RawByteString;
  LValue: RawByteString;
  LConfig: RawByteString;
  LVerifiedConfig: RawByteString;
  LGitResult: String;
begin
  LGitDir := FRoot + '.git' + PathDelim;
  if (SysUtils.GetEnvironmentVariable('GIT_NAMESPACE') <> '') or
    (SysUtils.GetEnvironmentVariable('GIT_OBJECT_DIRECTORY') <> '') or
    (SysUtils.GetEnvironmentVariable('GIT_CONFIG') <> '') or
    (SysUtils.GetEnvironmentVariable('GIT_CONFIG_COUNT') <> '') or
    (SysUtils.GetEnvironmentVariable('GIT_CONFIG_PARAMETERS') <> '') or
    not SimpleGitLayout(LGitDir) or not ReadGitMetadata(LGitDir + 'HEAD', LHead) or
    not StartsStr(CBranchPrefix, LHead) then
  begin
    Exit;
  end;
  LBranch := Trim(Copy(LHead, Length(CBranchPrefix) + 1, MaxInt));
  if (LBranch = '') or (LBranch[1] = '/') or (LBranch[Length(LBranch)] = '/') or
    (Pos('//', LBranch) <> 0) or (Pos('..', LBranch) <> 0) then
  begin
    Exit;
  end;
  for LChar in LBranch do
  begin
    if not (LChar in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.', '/']) then
    begin
      Exit;
    end;
  end;
  LRef := 'refs/heads';
  for LGitResult in SplitFields(LBranch, '/') do
  begin
    if (LGitResult = '') or (LGitResult[1] = '.') then
    begin
      Exit;
    end;
    if LRef <> 'refs/heads' then
    begin
      if not RegularGitDirectory(LGitDir + LRef) then
      begin
        Exit;
      end;
    end;
    LRef := LRef + '/' + LGitResult;
  end;
  LGitResult := '';
  if not ReadGitMetadata(LGitDir + LRef, LValue) or (Trim(LValue) <> FRevision) or
    not ReadGitMetadata(LGitDir + 'config', LConfig) then
  begin
    Exit;
  end;
  // Let Git confirm the traditional files backend and exclude configuration includes.
  if not RunCommandIndir(FRoot, 'git', ['config', '--local', '--get-regexp',
    '^(core\.repositoryformatversion|extensions\.|include)'], LGitResult, [], swoHide) or
    (Trim(LGitResult) <> 'core.repositoryformatversion 0') or
    not ReadGitMetadata(LGitDir + 'config', LVerifiedConfig) or (LVerifiedConfig <> LConfig) then
  begin
    Exit;
  end;
  FHeadBytes := LHead;
  FHeadRefBytes := LValue;
  FConfigBytes := LConfig;
  FHeadRef := LRef;
end;

function TClaimIndex.LooseHeadIsCurrent: Boolean;
var
  LGitDir: String;
  LData: RawByteString;
begin
  LGitDir := FRoot + '.git' + PathDelim;
  Result := SimpleGitLayout(LGitDir) and
    ReadGitMetadata(LGitDir + 'config', LData) and (LData = FConfigBytes) and
    ReadGitMetadata(LGitDir + 'HEAD', LData) and (LData = FHeadBytes) and
    ReadGitMetadata(LGitDir + FHeadRef, LData) and (LData = FHeadRefBytes) and
    ReadGitMetadata(LGitDir + 'HEAD', LData) and (LData = FHeadBytes);
end;
{$ENDIF}

constructor TClaimIndex.Create(const ARepoRoot: String);
const
  CTreeArguments = 5;
  COptionalPaths: array[0..5] of String = (CVerdictPath, CEvidencePath, CCoveragePath,
    CScorecardPath, CScorecardSourcesPath, CResearchStatusPath);
var
  LRound: Integer;
  LIndex: Integer;
  LSuffix: String;
  LArguments: TFields;
  LTables: TStringList;
  LProcess: TProcess;
  LClaim: TClaim;
  LTrend: String;
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARepoRoot));
  FClaims := TObjectList<TClaim>.Create(True);
  FIdentities := TDictionary<String, TClaim>.Create;
  FBySymptom := TObjectDictionary<String, TList<TClaim>>.Create([doOwnsValues]);
  FByIngredient := TObjectDictionary<String, TList<TClaim>>.Create([doOwnsValues]);
  FByTrend := TObjectDictionary<String, TList<TClaim>>.Create([doOwnsValues]);
  FSymptomAliases := TDictionary<String, String>.Create;
  FIngredientAliases := TDictionary<String, String>.Create;
  {$IFDEF WINDOWS}
  LoadGitRevision(FMayPinLooseHead);
  {$ELSE}
  FRevision := Trim(Git(['rev-parse', '--verify', 'HEAD']));
  {$ENDIF}
  // A batch "missing" response also covers unreadable objects. Check the
  // pinned tree once so a damaged published table cannot pass as absent.
  SetLength(LArguments, CTreeArguments + CRoundCount * Length(COptionalPaths) + 1);
  LArguments[0] := 'ls-tree';
  LArguments[1] := '-rt';
  LArguments[2] := '--name-only';
  LArguments[3] := FRevision;
  LArguments[4] := '--';
  LIndex := CTreeArguments;
  for LRound := 1 to CRoundCount do
  begin
    for LSuffix in COptionalPaths do
    begin
      LArguments[LIndex] := ExperimentPath(LRound) + LSuffix;
      Inc(LIndex);
    end;
  end;
  LArguments[LIndex] := CRubricPath;
  // Reuse one Git process and address every blob through the same commit.
  LProcess := nil;
  LTables := TStringList.Create;
  try
    LTables.CaseSensitive := True;
    LTables.Text := Git(LArguments);
    LProcess := TProcess.Create(nil);
    LProcess.Executable := 'git';
    LProcess.CurrentDirectory := FRoot;
    LProcess.Parameters.Add('cat-file');
    LProcess.Parameters.Add('--batch');
    LProcess.Options := [poUsePipes];
    LProcess.ShowWindow := swoHide;
    LProcess.Execute;
    if LTables.IndexOf(CRubricPath) >= 0 then
      FRubric := ReadBlob(LProcess, CRubricPath);
    for LRound := 1 to CRoundCount do
    begin
      LoadRound(LRound, LProcess, LTables);
      LSuffix := ExperimentPath(LRound);
      if LTables.IndexOf(LSuffix + CScorecardPath) >= 0 then
        FScorecards[LRound] := ReadBlob(LProcess, LSuffix + CScorecardPath);
      if LTables.IndexOf(LSuffix + CScorecardSourcesPath) >= 0 then
        FScorecardSources[LRound] := ReadBlob(LProcess, LSuffix + CScorecardSourcesPath);
      if LTables.IndexOf(LSuffix + CResearchStatusPath) >= 0 then
        FResearchStatus[LRound] := ReadBlob(LProcess, LSuffix + CResearchStatusPath);
    end;
    {$IF FPC_FULLVERSION >= 30300}
    // FPC's pipe stream owns the writer once Input has been accessed.
    LProcess.Input.DontClose := True;
    FileClose(LProcess.Input.Handle);
    {$ELSE}
    LProcess.CloseInput;
    {$ENDIF}
    if not LProcess.WaitOnExit or (LProcess.ExitStatus <> 0) then
    begin
      raise EInOutError.Create('Git could not finish reading the published experiment.');
    end;
  finally
    LProcess.Free;
    LTables.Free;
  end;
  AddAlias(FSymptomAliases, 'tremor', 'rest tremor severity');
  AddAlias(FSymptomAliases, 'tremors', 'rest tremor severity');
  AddAlias(FSymptomAliases, 'attention', 'attention impairment');
  AddAlias(FSymptomAliases, 'hallucination', 'visual hallucination frequency');
  AddAlias(FSymptomAliases, 'hallucinations', 'visual hallucination frequency');
  AddAlias(FSymptomAliases, 'seeing things', 'visual hallucination frequency');
  FDecisions := CompileClaimDecisions;
  LoadScorecardStatuses;
  LoadResearchStatuses;
  for LClaim in FClaims do
  begin
    LTrend := ClaimTrend(LClaim.Verdict, LClaim.Direction);
    if LTrend <> '' then
    begin
      AddPosting(FByTrend, LTrend, LClaim);
    end;
  end;
end;

destructor TClaimIndex.Destroy;
begin
  FCulturalSources.Free;
  FIngredientAliases.Free;
  FSymptomAliases.Free;
  FByTrend.Free;
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

function TClaimIndex.ReadBlob(AProcess: TProcess; const APath: String): String;
var
  LObjectName: String;
  LRequest: String;
  LHeader: String;
  LFields: TFields;
  LSize: Integer;
  LByte: AnsiChar;
begin
  LObjectName := FRevision + ':' + APath;
  LRequest := LObjectName + #10;
  AProcess.Input.WriteBuffer(LRequest[1], Length(LRequest));
  LHeader := '';
  repeat
    AProcess.Output.ReadBuffer(LByte, 1);
    if LByte = #10 then
    begin
      Break;
    end;
    if Length(LHeader) >= Length(LObjectName) + 64 then
    begin
      raise EInOutError.Create('Invalid Git response for ' + APath);
    end;
    LHeader := LHeader + LByte;
  until False;

  if LHeader = LObjectName + ' missing' then
  begin
    raise EInOutError.Create('Cannot read published experiment file: ' + APath);
  end;
  LFields := SplitFields(LHeader, ' ');
  if (Length(LFields) <> 3) or (LFields[1] <> 'blob') or
    not TryStrToInt(LFields[2], LSize) or (LSize < 0) then
  begin
    raise EInOutError.Create('Expected a Git blob for ' + APath);
  end;
  SetLength(Result, LSize);
  if LSize > 0 then
  begin
    AProcess.Output.ReadBuffer(Result[1], LSize);
  end;
  AProcess.Output.ReadBuffer(LByte, 1);
  if LByte <> #10 then
  begin
    raise EInOutError.Create('Invalid Git blob terminator for ' + APath);
  end;
end;

procedure TClaimIndex.LoadRound(ARound: Integer; AProcess: TProcess; APublishedTables: TStrings);
var
  LExperiment: String;
  LData: String;
  LHash: String;
  LLines: TStringList;
  LFields: TFields;
  LClaim: TClaim;
  LIndex: Integer;
  LField: String;
  LCanonical: String;
  LRoundClaims: Integer;

  function RoundBlob(const ASuffix: String): String;
  begin
    Result := ReadBlob(AProcess, LExperiment + ASuffix);
  end;

begin
  LExperiment := ExperimentPath(ARound);
  LData := RoundBlob('/freeze.tsv');
  LHash := Trim(RoundBlob('/freeze.sha256'));
  if HashText(LData) <> LHash then
    raise EConvertError.CreateFmt('Frozen claim hash mismatch in Round %d.', [ARound]);
  LLines := TStringList.Create;
  try
    ReadTable(LLines, RoundBlob('/symptoms.tsv'), 'symptom'#9'aliases');
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      LCanonical := Normalize(LFields[0]);
      AddAlias(FSymptomAliases, LCanonical, LCanonical);
      for LField in SplitFields(LFields[1], '|') do
        AddAlias(FSymptomAliases, LField, LCanonical);
    end;
    ReadTable(LLines, RoundBlob('/ingredients.tsv'),
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

    if APublishedTables.IndexOf(LExperiment + CVerdictPath) >= 0 then
    begin
      ReadTable(LLines, RoundBlob(CVerdictPath), CVerdictHeader);
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
        LClaim.Confidence := ReadReviewConfidence(LFields[2], LClaim.Verdict, LClaim.Id);
        LClaim.Rationale := LFields[3];
        for LField in SplitFields(LFields[4], '|') do
          if LField <> '' then
            LClaim.References.Add(LField);
        if LClaim.IsDirectional and (LClaim.References.Count = 0) then
          raise EConvertError.Create('Invalid published verdict: ' + LClaim.Id);
        if LClaim.IsDirectional then
          Inc(FDirectional)
        else
          Inc(FUnknown);
      end;
    end;
    if APublishedTables.IndexOf(LExperiment + CEvidencePath) >= 0 then
    begin
      ReadTable(LLines, RoundBlob(CEvidencePath), CEvidenceHeader);
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
    if APublishedTables.IndexOf(LExperiment + CCoveragePath) >= 0 then
    begin
      ReadTable(LLines, RoundBlob(CCoveragePath), CCoverageHeader);
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
  {$IFDEF WINDOWS}
  if FMayPinLooseHead then
  begin
    // One-shot callers do not pay for validating the shortcut.
    FMayPinLooseHead := False;
    PinLooseHead;
  end;
  if FHeadRef <> '' then
  begin
    if LooseHeadIsCurrent then
    begin
      Exit(True);
    end;
    FHeadRef := '';
  end;
  {$ENDIF}
  Result := Trim(Git(['rev-parse', '--verify', 'HEAD'])) = FRevision;
end;

procedure TClaimIndex.LoadScorecardStatuses;
var
  LRound: Integer;
  LIndex: Integer;
  LLines: TStringList;
  LFields: TFields;
  LClaim: TClaim;
  LCheck: TJSONObject;
  LStatus: String;
  LScorecardIndex: TScorecardIndex;
begin
  FV1Scorecards := 0;
  FDirectionalWithScorecard := 0;
  FDirectionalWithoutScorecard := 0;
  FScorecardMismatches := 0;
  LLines := TStringList.Create;
  try
    for LRound := 1 to CRoundCount do
    begin
      if FScorecards[LRound] = '' then
      begin
        Continue;
      end;
      LScorecardIndex := TScorecardIndex.Create(FScorecards[LRound], FScorecardSources[LRound]);
      try
        LLines.Text := FScorecards[LRound];
        for LIndex := 1 to LLines.Count - 1 do
        begin
          if LLines[LIndex] = '' then
          begin
            Continue;
          end;
          LFields := SplitFields(LLines[LIndex], #9);
          if (Length(LFields) < 1) or
            not FIdentities.TryGetValue(Key(LRound, LFields[0]), LClaim) then
          begin
            Continue;
          end;
          LCheck := TJSONObject.Create;
          try
            LScorecardIndex.AddEvidenceScorecardFor(LCheck, LClaim.Id, LClaim.Direction,
              LClaim.Verdict, LClaim.Confidence);
            LStatus := LCheck.Get('review_status', 'no_scorecard');
            LClaim.ScorecardStatus := LStatus;
          finally
            LCheck.Free;
          end;
        end;
      finally
        LScorecardIndex.Free;
      end;
    end;
  finally
    LLines.Free;
  end;
  for LClaim in FClaims do
  begin
    if (LClaim.ScorecardStatus = 'recorded') or (LClaim.ScorecardStatus = 'verdict_mismatch') then
    begin
      Inc(FV1Scorecards);
    end;
    if LClaim.ScorecardStatus = 'verdict_mismatch' then
    begin
      Inc(FScorecardMismatches);
    end;
    if LClaim.IsDirectional then
    begin
      if LClaim.ScorecardStatus = 'recorded' then
      begin
        Inc(FDirectionalWithScorecard);
      end
      else
      begin
        Inc(FDirectionalWithoutScorecard);
      end;
    end;
  end;
end;

procedure TClaimIndex.LoadResearchStatuses;
var
  LRound: Integer;
  LIndex: Integer;
  LLines: TStringList;
  LClaim: TClaim;
  LRow: TResearchStatusRow;
begin
  FUnknownResearched := 0;
  FUnknownUnresearched := 0;
  for LClaim in FClaims do
  begin
    if (LClaim.Verdict = 'Unreviewed') or (LClaim.Verdict = '') then
      LClaim.ResearchStatus := 'unreviewed'
    else
      LClaim.ResearchStatus := 'partial';
  end;
  LLines := TStringList.Create;
  try
    for LRound := 1 to CRoundCount do
    begin
      if FResearchStatus[LRound] = '' then
      begin
        Continue;
      end;
      ReadTable(LLines, FResearchStatus[LRound], CResearchStatusHeader);
      for LIndex := 1 to LLines.Count - 1 do
      begin
        if LLines[LIndex] = '' then
        begin
          Continue;
        end;
        LRow := ParseResearchStatusRow(LLines[LIndex], LIndex + 1);
        if not FIdentities.TryGetValue(Key(LRound, LRow.Id), LClaim) then
        begin
          raise EConvertError.Create('research-status.tsv references unknown claim ' + LRow.Id);
        end;
        LClaim.LabClinicalChecked := LRow.LabClinicalChecked;
        LClaim.CulturalChecked := LRow.CulturalChecked;
        LClaim.ScorecardChecked := LRow.ScorecardChecked;
        LClaim.LastCheckedUtc := LRow.LastCheckedUtc;
        LClaim.SearchBasis := LRow.SearchBasis;
        LClaim.OpenGaps := LRow.OpenGaps;
        LClaim.ResearchStatus := EffectiveResearchStatus(LRow.Status, LClaim.ScorecardStatus,
          LClaim.Verdict, LRow.LabClinicalChecked, LRow.CulturalChecked, LRow.ScorecardChecked);
      end;
    end;
  finally
    LLines.Free;
  end;
  for LClaim in FClaims do
  begin
    if LClaim.Verdict = 'Unknown' then
    begin
      if LClaim.ResearchStatus = 'researched' then
        Inc(FUnknownResearched)
      else
        Inc(FUnknownUnresearched);
    end;
  end;
end;

function TClaimIndex.Status: TJSONObject;
begin
  Result := TJSONObject.Create(['revision', FRevision, 'frozen_claims', FClaims.Count,
    'directional_verdicts', FDirectional, 'unknown_verdicts', FUnknown,
    'unknown_researched', FUnknownResearched, 'unknown_unresearched', FUnknownUnresearched,
    'unreviewed_claims', FClaims.Count - FDirectional - FUnknown, 'assessment_rows', FSourceRows,
    'v1_scorecards', FV1Scorecards, 'directional_with_scorecard', FDirectionalWithScorecard,
    'directional_without_scorecard', FDirectionalWithoutScorecard,
    'scorecard_mismatches', FScorecardMismatches]);
end;

function CompareLegacyDirectional(ALeft, ARight: Pointer): Integer;
var
  LLeft: TClaim;
  LRight: TClaim;
  LLeftRows: Integer;
  LRightRows: Integer;
begin
  LLeft := TClaim(ALeft);
  LRight := TClaim(ARight);
  if LLeft.Confidence > LRight.Confidence then
    Exit(-1);
  if LLeft.Confidence < LRight.Confidence then
    Exit(1);
  LLeftRows := LLeft.AssessedRows + LLeft.PendingRows;
  LRightRows := LRight.AssessedRows + LRight.PendingRows;
  if LLeftRows > LRightRows then
    Exit(-1);
  if LLeftRows < LRightRows then
    Exit(1);
  if LLeft.Round <> LRight.Round then
    Exit(LLeft.Round - LRight.Round);
  Result := CompareStr(LLeft.Id, LRight.Id);
end;

function TClaimIndex.Backlog: TJSONObject;
var
  LLegacy: TList;
  LClaim: TClaim;
  LLegacyJson: TJSONArray;
  LMismatchesJson: TJSONArray;
  LRoundsJson: TJSONArray;
  LZeroSymptomsJson: TJSONArray;
  LSymptomKeys: TStringList;
  LKey: String;
  LPostings: TList<TClaim>;
  LHasDirectional: Boolean;
  LAssessedCount: Integer;
  LRound: Integer;
  LFrozen: array[1..CRoundCount] of Integer;
  LDirectional: array[1..CRoundCount] of Integer;
  LUnknown: array[1..CRoundCount] of Integer;
  LUnknownResearched: array[1..CRoundCount] of Integer;
  LScorecards: array[1..CRoundCount] of Integer;
  I: Integer;
  LItem: TJSONObject;
begin
  FillChar(LFrozen, SizeOf(LFrozen), 0);
  FillChar(LDirectional, SizeOf(LDirectional), 0);
  FillChar(LUnknown, SizeOf(LUnknown), 0);
  FillChar(LUnknownResearched, SizeOf(LUnknownResearched), 0);
  FillChar(LScorecards, SizeOf(LScorecards), 0);
  LLegacy := TList.Create;
  LSymptomKeys := TStringList.Create;
  Result := TJSONObject.Create(['revision', FRevision]);
  try
    try
      LSymptomKeys.CaseSensitive := True;
      LSymptomKeys.UseLocale := False;
      LSymptomKeys.Sorted := True;
      LSymptomKeys.Duplicates := dupIgnore;
      Result.Add('summary', Status);
      LRoundsJson := TJSONArray.Create;
      Result.Add('rounds', LRoundsJson);
      LMismatchesJson := TJSONArray.Create;
      Result.Add('scorecard_mismatches', LMismatchesJson);
      LLegacyJson := TJSONArray.Create;
      Result.Add('directional_without_v1_scorecard', LLegacyJson);
      LZeroSymptomsJson := TJSONArray.Create;
      Result.Add('zero_directional_symptoms', LZeroSymptomsJson);
      for LClaim in FClaims do
      begin
        Inc(LFrozen[LClaim.Round]);
        if LClaim.IsDirectional then
          Inc(LDirectional[LClaim.Round])
        else if LClaim.Verdict = 'Unknown' then
        begin
          Inc(LUnknown[LClaim.Round]);
          if LClaim.ResearchStatus = 'researched' then
            Inc(LUnknownResearched[LClaim.Round]);
        end;
        if (LClaim.ScorecardStatus = 'recorded') or
          (LClaim.ScorecardStatus = 'verdict_mismatch') then
          Inc(LScorecards[LClaim.Round]);
        if LClaim.ScorecardStatus = 'verdict_mismatch' then
        begin
          LMismatchesJson.Add(TJSONObject.Create(['round', LClaim.Round, 'id', LClaim.Id,
            'verdict', LClaim.Verdict, 'ingredient', LClaim.Ingredient,
            'symptom', LClaim.Symptom]));
        end;
        if LClaim.IsDirectional and (LClaim.ScorecardStatus <> 'recorded') then
        begin
          LLegacy.Add(LClaim);
        end;
      end;
      LLegacy.Sort(@CompareLegacyDirectional);
      for I := 0 to LLegacy.Count - 1 do
      begin
        LClaim := TClaim(LLegacy[I]);
        LItem := TJSONObject.Create(['round', LClaim.Round, 'id', LClaim.Id,
          'verdict', LClaim.Verdict,
          'confidence', ReviewConfidenceText(LClaim.Confidence),
          'scorecard_status', LClaim.ScorecardStatus,
          'category', LClaim.Category, 'ingredient', LClaim.Ingredient,
          'preparation', LClaim.Preparation, 'symptom', LClaim.Symptom,
          'hypothesis_direction', LClaim.Direction,
          'assessment_rows', LClaim.AssessedRows + LClaim.PendingRows]);
        if LClaim.QueuedPairs >= 0 then
        begin
          LItem.Add('queued_original_pairs', LClaim.QueuedPairs);
        end;
        LLegacyJson.Add(LItem);
      end;
      for LRound := 1 to CRoundCount do
      begin
        LRoundsJson.Add(TJSONObject.Create(['round', LRound,
          'frozen', LFrozen[LRound],
          'directional', LDirectional[LRound],
          'unknown', LUnknown[LRound],
          'unknown_researched', LUnknownResearched[LRound],
          'unknown_unresearched', LUnknown[LRound] - LUnknownResearched[LRound],
          'unreviewed', LFrozen[LRound] - LDirectional[LRound] - LUnknown[LRound],
          'v1_scorecards', LScorecards[LRound]]));
      end;
      for LKey in FBySymptom.Keys do
      begin
        LSymptomKeys.Add(LKey);
      end;
      for LKey in LSymptomKeys do
      begin
        LPostings := FBySymptom[LKey];
        LHasDirectional := False;
        LAssessedCount := 0;
        for LClaim in LPostings do
        begin
          if LClaim.IsDirectional then
          begin
            LHasDirectional := True;
          end;
          if LClaim.AssessedRows > 0 then
          begin
            Inc(LAssessedCount);
          end;
        end;
        if not LHasDirectional then
        begin
          LZeroSymptomsJson.Add(TJSONObject.Create(['symptom', LPostings[0].Symptom,
            'frozen_claims', LPostings.Count, 'assessed_claims', LAssessedCount]));
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LSymptomKeys.Free;
    LLegacy.Free;
  end;
end;

function TClaimIndex.Claim(ARound: Integer; const AId: String;
  AAssessmentOffset, AAssessmentLimit: Integer; const AAssessmentStudy: String;
  AIncludeCulture: Boolean): TJSONObject;
var
  LClaim: TClaim;
begin
  if not FIdentities.TryGetValue(Key(ARound, AId), LClaim) then
    Exit(TJSONObject.Create(['revision', FRevision, 'found', False]));
  Result := LClaim.View(True, AAssessmentOffset, AAssessmentLimit, AAssessmentStudy);
  Result.Add('revision', FRevision);
  Result.Add('found', True);
  if AIncludeCulture then
  begin
    try
      Result.Add('culture_sources', CulturalMatches(LClaim.Symptom, LClaim.Ingredient));
    except
      Result.Free;
      raise;
    end;
  end;
end;

function TClaimIndex.EvidenceRubric(ARound: Integer; const AId: String;
  AIncludeRules: Boolean): TJSONObject;
var
  LClaim: TClaim;
begin
  if FRubric = '' then
    raise EInOutError.Create('The published evidence rubric is unavailable.');
  Result := TJSONObject.Create(['revision', FRevision, 'rubric_version', EvidenceRubricVersion,
    'rubric_path', CRubricPath, 'score_type', 'ordinal_review_tier']);
  try
    if AIncludeRules then
    begin
      Result.Add('rules', FRubric);
    end;
    if AIncludeRules or (AId = '') then
    begin
      AddEvidenceRubricSchema(Result);
    end;
    if AId = '' then
    begin
      Exit;
    end;
    Result.Add('round', ARound);
    Result.Add('id', AId);
    if not FIdentities.TryGetValue(Key(ARound, AId), LClaim) then
    begin
      Result.Add('review_status', 'claim_not_found');
      Exit;
    end;
    Result.Add('hypothesis_direction', LClaim.Direction);
    Result.Add('statement', LClaim.Statement);
    Result.Add('published_verdict', LClaim.Verdict);
    AddEvidenceScorecard(Result, FScorecards[ARound], FScorecardSources[ARound], AId,
      LClaim.Direction, LClaim.Verdict, LClaim.Confidence);
  except
    Result.Free;
    raise;
  end;
end;

function TClaimIndex.CheckScorecard(ARound: Integer;
  const AId, ARevision, ADecision, ASources: String): TJSONObject;
var
  LClaim: TClaim;
begin
  if FRubric = '' then
  begin
    raise EInOutError.Create('The published evidence rubric is unavailable.');
  end;
  if ARevision <> FRevision then
  begin
    raise EConvertError.Create('Claim revision changed. Read oracle_evidence_rubric again.');
  end;
  if not FIdentities.TryGetValue(Key(ARound, AId), LClaim) then
  begin
    raise EConvertError.Create('The draft claim ID was not found in that round.');
  end;
  Result := TJSONObject.Create(['revision', FRevision, 'rubric_version', EvidenceRubricVersion,
    'round', ARound, 'id', AId, 'hypothesis_direction', LClaim.Direction,
    'published_verdict', LClaim.Verdict]);
  try
    AddEvidenceScorecard(Result, ADecision, ASources, AId, LClaim.Direction, '', 0, True);
  except
    Result.Free;
    raise;
  end;
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
  Result := ((AQuery.Verdict = '') or SameText(AQuery.Verdict, AClaim.Verdict) or
      (SameText(AQuery.Verdict, 'Unknown (Researched)') and
        SameText(AClaim.Verdict, 'Unknown') and
        SameText(AClaim.ResearchStatus, 'researched'))) and
    ((AQuery.Trend = '') or (ClaimTrend(AClaim.Verdict, AClaim.Direction) = AQuery.Trend)) and
    ((AQuery.ScorecardStatus = '') or
      SameText(AQuery.ScorecardStatus, AClaim.ScorecardStatus)) and
    ((AQuery.ResearchStatus = '') or
      SameText(AQuery.ResearchStatus, AClaim.ResearchStatus));
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

function ResolveRows(ACandidates: TList<TClaim>; const AQuery: TClaimQuery;
  const ADecisions: TClaimDecisions): TQueryResolution;
var
  LClaim: TClaim;
  LIdentityMatches: Boolean;
  LPremiseMatches: Boolean;
  LEvidenceMatches: Boolean;
  LCombination: Integer;
begin
  Result := Default(TQueryResolution);
  Result.Options := TJSONArray.Create;
  try
    for LClaim in ACandidates do
    begin
      LIdentityMatches := ((AQuery.Symptom = '') or SameText(AQuery.Symptom, LClaim.Symptom)) and
        ((AQuery.Ingredient = '') or SameText(AQuery.Ingredient, LClaim.Ingredient)) and
        ((AQuery.Preparation = '') or SameText(AQuery.Preparation, LClaim.Preparation)) and
        ((AQuery.Round = 0) or (AQuery.Round = LClaim.Round));
      LPremiseMatches := (AQuery.Direction = '') or (AQuery.Direction = LClaim.Direction);
      LEvidenceMatches := EvidenceAllowed(LClaim, AQuery);
      LCombination := ClaimDecisionIndex(LIdentityMatches, LPremiseMatches, LEvidenceMatches);
      case ADecisions[LCombination] of
        cdInclude:
          begin
            if (Result.Selected >= AQuery.Offset) and (Result.Options.Count < AQuery.Limit) then
            begin
              Result.Options.Add(LClaim.View(False));
            end;
            Inc(Result.Selected);
          end;
        cdIdentityExcluded: Inc(Result.IdentityExcluded);
        cdPremiseExcluded: Inc(Result.PremiseExcluded);
        cdEvidenceExcluded: Inc(Result.EvidenceExcluded);
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
  LTrendCandidates: TList<TClaim>;
  LEmpty: TList<TClaim>;
  LCandidateCount: Integer;
  LResolved: TQueryResolution;
begin
  LQuery := AQuery;
  LQuery.Symptom := LookupAlias(AQuery.Symptom, FSymptomAliases);
  LQuery.Ingredient := LookupAlias(AQuery.Ingredient, FIngredientAliases);
  LQuery.Preparation := Normalize(AQuery.Preparation);
  LQuery.Direction := Normalize(AQuery.Direction);
  LQuery.Trend := Normalize(AQuery.Trend);
  LQuery.ScorecardStatus := Normalize(AQuery.ScorecardStatus);
  LQuery.ResearchStatus := Normalize(AQuery.ResearchStatus);
  if IndexStr(LQuery.Scope, ['directional', 'assessed', 'frozen']) < 0 then
    raise EConvertError.Create('Scope must be directional, assessed or frozen.');
  if IndexStr(LQuery.Direction, ['', 'reduces', 'worsens']) < 0 then
    raise EConvertError.Create('Direction must be reduces or worsens.');
  if IndexStr(LQuery.Trend, ['', 'eases', 'worsens']) < 0 then
    raise EConvertError.Create('Trend must be eases or worsens.');
  if IndexText(LQuery.Verdict, ['', 'True', 'False', 'Maybe True', 'Maybe False',
    'Unknown', 'Unknown (Researched)', 'Unreviewed']) < 0 then
    raise EConvertError.Create('Invalid verdict filter.');
  if IndexStr(LQuery.ScorecardStatus, ['', 'recorded', 'no_scorecard',
    'historical_scorecard', 'verdict_mismatch']) < 0 then
    raise EConvertError.Create('Invalid scorecard_status filter.');
  if IndexStr(LQuery.ResearchStatus, ['', 'researched', 'partial', 'unreviewed']) < 0 then
    raise EConvertError.Create('Invalid research_status filter.');
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
    LCandidateCount := LCandidates.Count;
    if (LCandidates = FClaims) and (LQuery.Trend <> '') and
      (LQuery.Preparation = '') and (LQuery.Round = 0) and (LQuery.Direction = '') then
    begin
      if FByTrend.TryGetValue(LQuery.Trend, LTrendCandidates) then
      begin
        LCandidates := LTrendCandidates;
      end
      else
      begin
        LEmpty := TList<TClaim>.Create;
        LCandidates := LEmpty;
      end;
    end;
    LResolved := ResolveRows(LCandidates, LQuery, FDecisions);
    try
      // The skipped rows would all reach the evidence pass and fail its trend filter.
      Inc(LResolved.EvidenceExcluded, LCandidateCount - LCandidates.Count);
      Result := TJSONObject.Create(['revision', FRevision, 'scope', LQuery.Scope,
        'symptom', LQuery.Symptom, 'ingredient', LQuery.Ingredient,
        'preparation', LQuery.Preparation, 'hypothesis_direction', LQuery.Direction,
        'verdict_filter', LQuery.Verdict, 'round_filter', LQuery.Round,
        'index_candidates', LCandidateCount, 'total_matches', LResolved.Selected,
        'offset', LQuery.Offset, 'identity_excluded', LResolved.IdentityExcluded,
        'hypothesis_excluded', LResolved.PremiseExcluded,
        'evidence_excluded', LResolved.EvidenceExcluded]);
      if not LQuery.OmitCulture then
      begin
        try
          Result.Add('culture_sources', CulturalMatches(LQuery.Symptom, LQuery.Ingredient));
        except
          Result.Free;
          raise;
        end;
      end;
      if LQuery.Trend <> '' then
        Result.Add('trend_filter', LQuery.Trend);
      if LQuery.ScorecardStatus <> '' then
        Result.Add('scorecard_status_filter', LQuery.ScorecardStatus);
      if LQuery.ResearchStatus <> '' then
        Result.Add('research_status_filter', LQuery.ResearchStatus);
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

function TClaimIndex.Ingredients(ASymptoms: TJSONArray): TJSONObject;
var
  LSelected: array of String;
  LIngredients: array of String;
  LIngredient: String;
  LUnique: TStringList;
  LSymptom: String;
  LPostings: TList<TClaim>;
  LClaim: TClaim;
  LSignals: TIngredientSignals;
  LIndex: Integer;
  LSelectedCount: Integer;
  LSignalCount: Integer;
begin
  if ASymptoms.Count = 0 then
  begin
    raise EConvertError.Create('Provide at least one symptom.');
  end;
  LUnique := TStringList.Create;
  try
    LSelectedCount := 0;
    LSignalCount := 0;
    SetLength(LSelected, ASymptoms.Count);
    for LIndex := 0 to ASymptoms.Count - 1 do
    begin
      if ASymptoms.Items[LIndex].JSONType <> jtString then
      begin
        raise EConvertError.Create('Provide symptoms as strings.');
      end;
      LSymptom := LookupAlias(ASymptoms.Strings[LIndex], FSymptomAliases);
      if not FBySymptom.TryGetValue(LSymptom, LPostings) then
      begin
        raise EConvertError.CreateFmt('Unknown symptom at position %d. Use oracle_filter_options.',
          [LIndex + 1]);
      end;
      if LUnique.IndexOf(LSymptom) >= 0 then
      begin
        Continue;
      end;
      LUnique.Add(LSymptom);
      LSelected[LSelectedCount] := LSymptom;
      Inc(LSelectedCount);
      for LClaim in LPostings do
      begin
        if (LClaim.AssessedRows = 0) or
          (ClaimTrend(LClaim.Verdict, LClaim.Direction) = '') then
        begin
          Continue;
        end;
        SetLength(LSignals, LSignalCount + 1);
        LSignals[LSignalCount].Ingredient := LClaim.Ingredient;
        LSignals[LSignalCount].Symptom := LClaim.Symptom;
        LSignals[LSignalCount].Preparation := LClaim.Preparation;
        LSignals[LSignalCount].Verdict := LClaim.Verdict;
        LSignals[LSignalCount].HypothesisDirection := LClaim.Direction;
        LSignals[LSignalCount].ClaimId := LClaim.Id;
        LSignals[LSignalCount].Round := LClaim.Round;
        if LClaim.References.Count > 0 then
        begin
          LSignals[LSignalCount].LocalReference := LClaim.References.Strings[0];
        end;
        Inc(LSignalCount);
      end;
    end;
    SetLength(LSelected, LSelectedCount);
    SetLength(LIngredients, FByIngredient.Count);
    LIndex := 0;
    for LIngredient in FByIngredient.Keys do
    begin
      LIngredients[LIndex] := FByIngredient[LIngredient][0].Ingredient;
      Inc(LIndex);
    end;
    Result := IngredientEffects(FRevision, LSelected, LIngredients, LSignals);
  finally
    LUnique.Free;
  end;
end;

function TClaimIndex.LoadCulturalSources: TJSONArray;
const
  CTopics = 'experiments/tools/parkinsons-oracle/cultural-graph-topics.tsv';
  CHeader = 'path'#9'ingredients'#9'symptoms';
var
  LPaths: TStringList;
  LFields: TFields;
  LTopics: TDictionary<String, TFields>;
  LLines: TStringList;
  LProcess: TProcess;
  LPath: String;
  LIndex: Integer;
  LSource: TJSONObject;

  procedure AddTopics(const AKey, AText: String; AChoices: TObjectDictionary<String, TList<TClaim>>);
  var
    LArray: TJSONArray;
    LValue: String;
  begin
    LArray := TJSONArray.Create;
    LSource.Add(AKey, LArray);
    if (AText = '') or (AText = '-') then
      Exit;
    for LValue in SplitFields(AText, ';') do
    begin
      if not AChoices.ContainsKey(LValue) or HasCulturalTopic(LArray, LValue) then
        raise EConvertError.Create('Invalid or repeated graph topic for ' + LPath + ': ' + LValue);
      LArray.Add(LValue);
    end;
  end;

begin
  LPaths := TStringList.Create;
  LLines := TStringList.Create;
  LTopics := TDictionary<String, TFields>.Create;
  LProcess := TProcess.Create(nil);
  Result := TJSONArray.Create;
  try
    try
      LPaths.CaseSensitive := True;
      LPaths.Text := Git(['-c', 'core.quotePath=false', 'ls-tree', '-r', '--name-only',
        FRevision, '--', 'research', CTopics]);
      LProcess.Executable := 'git';
      LProcess.CurrentDirectory := FRoot;
      LProcess.Parameters.Add('cat-file');
      LProcess.Parameters.Add('--batch');
      LProcess.Options := [poUsePipes];
      LProcess.ShowWindow := swoHide;
      LProcess.Execute;
      if LPaths.IndexOf(CTopics) >= 0 then
      begin
        LLines.Text := ReadBlob(LProcess, CTopics);
        if (LLines.Count = 0) or (LLines[0] <> CHeader) then
          raise EConvertError.Create('The cultural graph topic table has an invalid header.');
        for LIndex := 1 to LLines.Count - 1 do
        begin
          LFields := SplitFields(LLines[LIndex], #9);
          if Length(LFields) <> 3 then
            raise EConvertError.CreateFmt('Invalid cultural topic row %d.', [LIndex + 1]);
          LTopics.Add(LFields[0], LFields);
        end;
      end;
      for LPath in LPaths do
      begin
        if not IsCulturalSource(LPath) or not SameText(ExtractFileExt(LPath), '.txt') then
          Continue;
        LSource := CulturalMetadata(LPath, ReadBlob(LProcess, LPath));
        LSource.Add('path', LPath);
        Result.Add(LSource);
        if LTopics.TryGetValue(LPath, LFields) then
        begin
          AddTopics('ingredients', LFields[1], FByIngredient);
          AddTopics('symptoms', LFields[2], FBySymptom);
          LTopics.Remove(LPath);
        end;
      end;
      if LTopics.Count <> 0 then
        raise EConvertError.Create('Cultural graph topics reference missing source records.');
      {$IF FPC_FULLVERSION >= 30300}
    // FPC's pipe stream owns the writer once Input has been accessed.
    LProcess.Input.DontClose := True;
    FileClose(LProcess.Input.Handle);
    {$ELSE}
    LProcess.CloseInput;
    {$ENDIF}
      if not LProcess.WaitOnExit or (LProcess.ExitStatus <> 0) then
        raise EInOutError.Create('Git could not finish reading the published cultural sources.');
    except
      Result.Free;
      raise;
    end;
  finally
    LProcess.Free;
    LTopics.Free;
    LLines.Free;
    LPaths.Free;
  end;
end;

function TClaimIndex.CulturalMatches(const ASymptom, AIngredient: String): TJSONArray;
var
  LRank: Integer;
  LIndex: Integer;
  LMatchRank: Integer;
  LSource: TJSONObject;
  LMatch: TJSONObject;
  LIngredientMatch: Boolean;
  LSymptomMatch: Boolean;
begin
  Result := TJSONArray.Create;
  try
    if (ASymptom = '') and (AIngredient = '') then
      Exit;
    if FCulturalSources = nil then
      FCulturalSources := LoadCulturalSources;
    for LRank := 3 downto 1 do
      for LIndex := 0 to FCulturalSources.Count - 1 do
      begin
        LSource := FCulturalSources.Objects[LIndex];
        LIngredientMatch := HasCulturalTopic(LSource.Get('ingredients', TJSONArray(nil)),
          AIngredient);
        LSymptomMatch := HasCulturalTopic(LSource.Get('symptoms', TJSONArray(nil)), ASymptom);
        LMatchRank := 2 * Ord(LIngredientMatch) + Ord(LSymptomMatch);
        if LMatchRank <> LRank then
          Continue;
        LMatch := TJSONObject(LSource.Clone);
        Result.Add(LMatch);
        LMatch.Add('ingredient_match', LIngredientMatch);
        LMatch.Add('symptom_match', LSymptomMatch);
      end;
  except
    Result.Free;
    raise;
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
      LResolved := ResolveRows(FClaims, LQuery, FDecisions);
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
      if FCulturalSources = nil then
        FCulturalSources := LoadCulturalSources;
      Result.Add('culture_sources', FCulturalSources.Clone);
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
