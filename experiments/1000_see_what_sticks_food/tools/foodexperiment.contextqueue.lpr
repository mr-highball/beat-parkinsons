{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.contextqueue;

{$mode delphi}
{$H+}

uses Classes, SysUtils, StrUtils, Windows, RegExpr, foodexperiment.externaldata, foodexperiment.archiveidentity;

const
  Tab = #9;
  ReportBufferSize = 65536;
  CandidateHeader = 'priority'#9'reason'#9'id'#9'source_key'#9'category'#9'ingredient'#9 +
    'preparation'#9'symptom'#9'query_1_rank'#9'query_2_rank'#9'triage'#9 +
    'indexed_ingredient'#9'indexed_related'#9'indexed_outcome'#9 +
    'body_ingredient'#9'body_related'#9'body_outcome'#9'pmid'#9'pmcid'#9'doi'#9 +
    'publication_date'#9'title'#9'review_state'#9'prior_role'#9'review_basis'#9 +
    'review_receipt'#9'review_count'#9'archive_state'#9'archive_scope'#9'archive_path'#9 +
    'indexed_abstract'#9'access_receipt'#9'prior_access_level'#9'known_access_gap'#9 +
    'pmc_pipeline_status'#9'pmc_pipeline_receipt'#9'pmc_pipeline_license'#9'pmc_pipeline_version';
  ReviewStates: array[0..5] of String = ('no_exact_review_imported', 'pending_or_access_only',
    'title_index_reviewed', 'abstract_context_reviewed', 'exact_assessment_basis_unspecified',
    'body_or_primary_context_reviewed');
  Reasons: array[1..6] of String = ('human_or_protocol_with_body_pair',
    'human_or_protocol_with_indexed_pair', 'other_tier_with_body_or_indexed_pair',
    'human_or_protocol_without_paired_lexical_flags',
    'other_tier_with_single_lexical_side', 'retrieved_without_lexical_flags');

type
  TTsv = class
  private
    FFile: TextFile;
    FBuffer: array[0..65535] of Byte;
    FHeader: TFields;
    FFields: TFields;
    FPath: String;
    FLine: Integer;
  public
    constructor Create(const APath: String);
    destructor Destroy; override;
    function Next: Boolean;
    function Value(const AColumn: String): String;
    property Line: Integer read FLine;
  end;

  TClaim = record
    Id: String;
    Category: String;
    Ingredient: String;
    Preparation: String;
    Symptom: String;
    Pairs: Integer;
    JoinCount: Integer;
    Review: array[0..5] of Integer;
    Queue: array[1..6] of Integer;
  end;

  TSource = class
    Key: String;
    Pmid: String;
    Pmcid: String;
    Doi: String;
    Title: String;
    Date: String;
    HasAbstract: Boolean;
    ArchiveIdentityPath: String;
    ArchiveIdentity: TArchiveIdentity;
    PipelineStatus: String;
    PipelineReceipt: String;
    PipelineLicense: String;
    PipelineVersion: String;
    QueuedPairs: Integer;
    QueuedArchivePairs: Integer;
    QueueByPriority: array[1..6] of Integer;
  end;

  TPair = class
    Claim: Integer;
    Source: TSource;
    Ranks: array[1..2] of Integer;
    Triage: String;
    IndexedFlags: array[0..2] of Boolean;
    BodyFlags: array[0..2] of Boolean;
    ArchiveRowSeen: Boolean;
    ArchiveScope: String;
    ArchivePath: String;
    ReviewLevel: Integer;
    ReviewCount: Integer;
    ReviewRole: String;
    ReviewBasis: String;
    ReviewReceipt: String;
  end;

  TAccess = class
    Receipt: String;
    Level: String;
    Gap: String;
  end;

var
  GRoot: String;
  GOutput: String;
  GClaims: array[1..1000] of TClaim;
  GSources: TStringList;
  GAliases: TStringList;
  GCollisionKeys: TStringList;
  GPairs: TStringList;
  GAccess: TStringList;
  GReviewFiles: TStringList;
  GMemberships: Integer;
  GScreenRows: Integer;
  GBodyRows: Integer;
  GArchiveIdentityConflicts: Integer;
  GAssessmentAliasConflicts: Integer;
  GArchiveIdentityAdvisories: Integer;
  GReviewedJoins: Integer;
  GInputProof: TextFile;
  GReviewSeen: Integer;
  GSourceMismatches: Integer;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function NewMap(AOwnsObjects: Boolean): TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.Duplicates := dupError;
  Result.OwnsObjects := AOwnsObjects;
end;

constructor TTsv.Create(const APath: String);
var
  LHeader: UTF8String;
begin
  inherited Create;
  FPath := APath;
  AssignFile(FFile, APath);
  SetTextBuf(FFile, FBuffer);
  Reset(FFile);
  ReadLn(FFile, LHeader);
  if Copy(LHeader, 1, 3) = #$EF#$BB#$BF then
  begin
    Delete(LHeader, 1, 3);
  end;
  FHeader := SplitFields(LHeader, Tab);
  FLine := 1;
end;

destructor TTsv.Destroy;
begin
  CloseFile(FFile);
  inherited Destroy;
end;

function TTsv.Next: Boolean;
var
  LLine: UTF8String;
begin
  while not EOF(FFile) do
  begin
    ReadLn(FFile, LLine);
    Inc(FLine);
    if LLine <> '' then
    begin
      FFields := SplitFields(LLine, Tab);
      Require(Length(FFields) = Length(FHeader), FPath + ':' + IntToStr(FLine) +
        ' does not match its header');
      Exit(True);
    end;
  end;
  Result := False;
end;

function TTsv.Value(const AColumn: String): String;
var
  I: Integer;
begin
  for I := 0 to High(FHeader) do
  begin
    if FHeader[I] = AColumn then
    begin
      Exit(FFields[I]);
    end;
  end;
  Result := '';
end;

function ClaimNumber(const AId: String): Integer;
begin
  if (Length(AId) <> 4) or not TryStrToInt(AId, Result) or
    (Result < Low(GClaims)) or (Result > High(GClaims)) or
    (Format('%.4d', [Result]) <> AId) then
  begin
    raise EConvertError.Create('Invalid frozen claim ID ' + AId);
  end;
end;

function DigitsOnly(const AText: String): Boolean;
var
  LChar: Char;
begin
  if AText = '' then
  begin
    Exit(False);
  end;
  for LChar in AText do
  begin
    if not (LChar in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

function Normalize(const AKey: String): String;
var
  LKey: String;
  LSuffix: String;
begin
  LKey := Trim(AKey);
  if AnsiStartsText('PMID', LKey) then
  begin
    LSuffix := Trim(Copy(LKey, 5, MaxInt));
    if AnsiStartsStr(':', LSuffix) then
    begin
      LSuffix := Trim(Copy(LSuffix, 2, MaxInt));
    end;
    if DigitsOnly(LSuffix) then
    begin
      Exit('PMID:' + LSuffix);
    end;
  end;
  if AnsiStartsText('PMCID', LKey) then
  begin
    LSuffix := Trim(Copy(LKey, 6, MaxInt));
    if AnsiStartsStr(':', LSuffix) then
    begin
      LSuffix := Trim(Copy(LSuffix, 2, MaxInt));
    end;
    if DigitsOnly(LSuffix) then
    begin
      Exit('PMCID:PMC' + LSuffix);
    end;
  end;
  if AnsiStartsText('MED:', LKey) then
  begin
    Exit('PMID:' + Copy(LKey, 5, MaxInt));
  end;
  if AnsiStartsText('PMC:PMC', LKey) then
  begin
    Exit('PMCID:' + UpperCase(Copy(LKey, 5, MaxInt)));
  end;
  if AnsiStartsText('PMCID:', LKey) then
  begin
    Exit(UpperCase(LKey));
  end;
  if (Length(LKey) >= 4) and AnsiStartsText('PMC', LKey) and
    (LKey[4] in ['0'..'9']) then
  begin
    Exit('PMCID:' + UpperCase(LKey));
  end;
  if AnsiStartsText('https://doi.org/', LKey) then
  begin
    LKey := Copy(LKey, 17, MaxInt);
  end
  else if AnsiStartsText('DOI:', LKey) then
  begin
    LKey := Trim(Copy(LKey, 5, MaxInt));
  end
  else if AnsiStartsText('DOI10.', LKey) then
  begin
    LKey := Copy(LKey, 4, MaxInt);
  end;
  if AnsiStartsText('10.', LKey) then
  begin
    Exit('DOI:' + LowerCase(LKey));
  end;
  Result := LKey;
end;

function FindObject(AMap: TStringList; const AKey: String): TObject;
var
  LIndex: Integer;
begin
  Result := nil;
  if AMap.Find(AKey, LIndex) then
  begin
    Require(AMap[LIndex] = AKey, 'Nonexact comparison for key ' + AKey);
    Result := AMap.Objects[LIndex];
  end;
end;

function PairKey(AClaim: Integer; const ASourceKey: String): String;
begin
  Result := GClaims[AClaim].Id + Tab + ASourceKey;
end;

procedure AddAlias(const AAlias: String; ASource: TSource);
var
  LIndex: Integer;
  LAlias: String;
  LFirst: TSource;
begin
  LAlias := Normalize(AAlias);
  if LAlias = '' then
  begin
    Exit;
  end;
  if GAliases.Find(LAlias, LIndex) then
  begin
    LFirst := TSource(GAliases.Objects[LIndex]);
    if LFirst <> ASource then
    begin
      if LFirst <> nil then
      begin
        GCollisionKeys.Add(LAlias + Tab + LFirst.Key);
      end;
      GCollisionKeys.Add(LAlias + Tab + ASource.Key);
      GAliases.Objects[LIndex] := nil;
    end;
  end
  else
  begin
    GAliases.AddObject(LAlias, ASource);
  end;
end;

function ResolveSource(const AId: String): TSource;
var
  LKey: String;
begin
  LKey := Normalize(AId);
  Result := TSource(FindObject(GSources, LKey));
  if Result = nil then
  begin
    Result := TSource(FindObject(GAliases, LKey));
  end;
end;

function FindPair(AClaim: Integer; const ASource: String): TPair;
var
  LSource: TSource;
begin
  LSource := ResolveSource(ASource);
  Result := nil;
  if LSource <> nil then
  begin
    Result := TPair(FindObject(GPairs, PairKey(AClaim, LSource.Key)));
  end;
end;

function ReadFlag(const AValue: String): Boolean;
begin
  Require((AValue = 'True') or (AValue = 'False'), 'Unexpected lexical flag ' + AValue);
  Result := AValue = 'True';
end;

procedure LoadClaims;
var
  LTable: TTsv;
  LIndex: Integer;
  I: Integer;
begin
  LTable := TTsv.Create(GRoot + 'freeze.tsv');
  try
    while LTable.Next do
    begin
      LIndex := ClaimNumber(LTable.Value('id'));
      Require(GClaims[LIndex].Id = '', 'Repeated frozen claim ID');
      GClaims[LIndex].Id := LTable.Value('id');
      GClaims[LIndex].Category := LTable.Value('category');
      GClaims[LIndex].Ingredient := LTable.Value('ingredient');
      GClaims[LIndex].Preparation := LTable.Value('preparation');
      GClaims[LIndex].Symptom := LTable.Value('symptom');
    end;
  finally
    LTable.Free;
  end;
  for I := Low(GClaims) to High(GClaims) do
  begin
    Require(GClaims[I].Id <> '', 'Freeze is missing a claim');
  end;
end;

procedure LoadOverlay(const APath: String);
var
  LTable: TTsv;
  LSource: TSource;
  LPair: TPair;
  LQuery: String;
  LKey: String;
  LPmid: String;
  LPmcid: String;
  LDoi: String;
  LIndex: Integer;
  LVariant: Integer;
begin
  LTable := TTsv.Create(GRoot + APath);
  try
    while LTable.Next do
    begin
      Inc(GMemberships);
      LQuery := LTable.Value('query_id');
      Require((Length(LQuery) = 6) and (LQuery[5] = '-') and (LQuery[6] in ['1', '2']),
        'Invalid overlay query ID ' + LQuery);
      LIndex := ClaimNumber(Copy(LQuery, 1, 4));
      LVariant := Ord(LQuery[6]) - Ord('0');
      LKey := LTable.Value('source_key');
      Require((LKey <> '') and (Normalize(LKey) = LKey) and
        (LTable.Value('ingredient') = GClaims[LIndex].Ingredient) and
        (LTable.Value('category') = GClaims[LIndex].Category), 'Overlay key or claim mismatch');
      LSource := TSource(FindObject(GSources, LKey));
      if LSource = nil then
      begin
        LSource := TSource.Create;
        GSources.AddObject(LKey, LSource);
        LSource.Key := LKey;
        LSource.Title := LTable.Value('title');
        LSource.Date := LTable.Value('publication_date');
      end;
      LPmid := LTable.Value('pmid');
      LPmcid := LTable.Value('pmcid');
      LDoi := LTable.Value('doi');
      if LPmid <> '' then
      begin
        AddAlias('PMID:' + LPmid, LSource);
        LSource.Pmid := LPmid;
      end;
      if LPmcid <> '' then
      begin
        AddAlias(LPmcid, LSource);
        LSource.Pmcid := LPmcid;
      end;
      if LDoi <> '' then
      begin
        AddAlias(LDoi, LSource);
        LSource.Doi := LDoi;
      end;
      LSource.HasAbstract := LSource.HasAbstract or (LTable.Value('abstract') <> '');
      LKey := PairKey(LIndex, LKey);
      LPair := TPair(FindObject(GPairs, LKey));
      if LPair = nil then
      begin
        LPair := TPair.Create;
        LPair.Claim := LIndex;
        LPair.Source := LSource;
        GPairs.AddObject(LKey, LPair);
      end;
      Require(LPair.Ranks[LVariant] = 0, 'Repeated overlay result for ' + LKey);
      LPair.Ranks[LVariant] := StrToInt(LTable.Value('rank'));
      Require(LPair.Ranks[LVariant] > 0, 'Invalid rank for ' + LKey);
    end;
  finally
    LTable.Free;
  end;
end;

procedure LoadScreens;
var
  LTable: TTsv;
  LPair: TPair;
  LSource: TSource;
  LClaim: Integer;
  LExpected: TArchiveIdentity;
  LRowPmcid, LPath, LConflict, LDisposition: String;
  LConflictFile: TextFile;
begin
  LTable := TTsv.Create(GRoot + 'followup/claim-query-screen.tsv');
  try
    while LTable.Next do
    begin
      LClaim := ClaimNumber(LTable.Value('id'));
      LPair := FindPair(LClaim, LTable.Value('source_key'));
      Require((LPair <> nil) and (LPair.Triage = ''), 'Screen does not match overlay');
      LPair.Triage := LTable.Value('triage');
      LPair.IndexedFlags[0] := ReadFlag(LTable.Value('ingredient_terms'));
      LPair.IndexedFlags[1] := ReadFlag(LTable.Value('related_exposure_terms'));
      LPair.IndexedFlags[2] := ReadFlag(LTable.Value('claim_symptom_terms'));
      Inc(GScreenRows);
    end;
  finally
    LTable.Free;
  end;
  Require(GScreenRows = GPairs.Count, 'Bibliographic screen and overlay coverage differ');
  AssignFile(LConflictFile, GOutput + 'archive-identity-conflicts.tsv');
  Rewrite(LConflictFile);
  try
    WriteLn(LConflictFile, 'id', Tab, 'source_key', Tab, 'local_reference', Tab, 'conflict',
      Tab, 'overlay_pmcid', Tab, 'overlay_pmid', Tab, 'overlay_doi', Tab, 'screen_pmcid',
      Tab, 'archive_pmcid', Tab, 'archive_pmid', Tab, 'archive_doi', Tab, 'disposition');
    LTable := TTsv.Create(GRoot + 'followup/claim-local-text-screen.tsv');
    try
      while LTable.Next do
      begin
        LClaim := ClaimNumber(LTable.Value('id'));
        LPair := FindPair(LClaim, LTable.Value('source_key'));
        Require((LPair <> nil) and not LPair.ArchiveRowSeen, 'Duplicate or unmatched body join');
        LPair.ArchiveRowSeen := True;
        LSource := LPair.Source;
        LExpected.Pmcid := LSource.Pmcid;
        LExpected.Pmid := LSource.Pmid;
        LExpected.Doi := LSource.Doi;
        LExpected.Title := LSource.Title;
        LRowPmcid := LTable.Value('pmcid');
        LPath := LTable.Value('local_reference');
        if LSource.ArchiveIdentityPath <> LPath then
        begin
          LSource.ArchiveIdentity := ReadArchiveIdentity(GRoot + '../../' + LPath);
          LSource.ArchiveIdentityPath := LPath;
        end;
        LConflict := ArchiveIdentityConflicts(LExpected, LSource.ArchiveIdentity);
        if (LRowPmcid <> '') and (LExpected.Pmcid <> '') and
          not SameText(LRowPmcid, LExpected.Pmcid) then
        begin
          if LConflict <> '' then
            LConflict := LConflict + ',';
          LConflict := LConflict + 'screen_pmcid';
        end;
        if LConflict <> '' then
        begin
          LDisposition := 'held';
          if (LConflict = 'doi') and SameTitledArchive(LExpected, LSource.ArchiveIdentity) then
          begin
            LDisposition := 'retained_title_and_identifier_match';
            Inc(GArchiveIdentityAdvisories);
          end
          else
          begin
            Inc(GArchiveIdentityConflicts);
          end;
          WriteLn(LConflictFile, GClaims[LClaim].Id, Tab, LSource.Key, Tab, LPath, Tab,
            LConflict, Tab, LExpected.Pmcid, Tab, LExpected.Pmid, Tab, LExpected.Doi, Tab,
            LRowPmcid, Tab, LSource.ArchiveIdentity.Pmcid, Tab, LSource.ArchiveIdentity.Pmid,
            Tab, LSource.ArchiveIdentity.Doi, Tab, LDisposition);
          if LDisposition = 'held' then
            Continue;
        end;
        LPair.ArchivePath := LPath;
        LPair.ArchiveScope := LTable.Value('text_scope');
        LPair.BodyFlags[0] := ReadFlag(LTable.Value('text_ingredient'));
        LPair.BodyFlags[1] := ReadFlag(LTable.Value('text_related'));
        LPair.BodyFlags[2] := ReadFlag(LTable.Value('text_outcome'));
        Inc(GBodyRows);
      end;
    finally
      LTable.Free;
    end;
  finally
    CloseFile(LConflictFile);
  end;
  WriteLn('Archive joins held for explicit identity discrepancies: ', GArchiveIdentityConflicts);
  WriteLn('Retained archive joins with DOI advisories: ', GArchiveIdentityAdvisories);
end;

function ConflictingPmcAssessment(ASource: TSource;
  const AStudy, AReference: String): Boolean;
var
  LArchive, LExpected: TArchiveIdentity;
  LStudy, LPath: String;
  LAnchor: Integer;
begin
  Result := False;
  LStudy := Normalize(AStudy);
  if (AReference = '') or (ASource.Key = LStudy) or
    not AnsiStartsStr('PMCID:', LStudy) then
    Exit;
  LPath := Trim(AReference);
  LAnchor := Pos('#', LPath);
  if LAnchor > 0 then
    SetLength(LPath, LAnchor - 1);
  if not AnsiStartsStr('research/', LPath) or (Pos('/Source-Text/', LPath) = 0) or
    not SameText(ExtractFileExt(LPath), '.txt') or (Pos('|', LPath) > 0) or
    (Pos(':', LPath) > 0) or (Pos('', LPath) > 0) or (Pos('/../', LPath + '/') > 0) then
    Exit;
  LArchive := ReadArchiveIdentity(GRoot + '../../' + LPath);
  if NormalizeArchiveIdentifier(LArchive.Pmcid) <> LStudy then
    Exit;
  LExpected := Default(TArchiveIdentity);
  LExpected.Pmcid := ASource.Pmcid;
  LExpected.Pmid := ASource.Pmid;
  LExpected.Doi := ASource.Doi;
  LExpected.Title := ASource.Title;
  Result := PmcAliasHasDoiConflict(LExpected, LArchive);
end;

procedure ApplyReview(const AClaim, ASource, ARole, ABasis, AReceipt: String;
  ALevel: Integer; const AReference: String = '');
var
  LPair: TPair;
begin
  if (AClaim = '') or (ASource = '') or (ARole = '') then
  begin
    Exit;
  end;
  Inc(GReviewSeen);
  LPair := FindPair(ClaimNumber(AClaim), ASource);
  if LPair = nil then
  begin
    Inc(GSourceMismatches);
    Exit;
  end;
  if (AReference <> '') and ConflictingPmcAssessment(LPair.Source, ASource, AReference) then
  begin
    Inc(GSourceMismatches);
    Inc(GAssessmentAliasConflicts);
    Exit;
  end;
  Inc(GReviewedJoins);
  Inc(LPair.ReviewCount);
  if ALevel > LPair.ReviewLevel then
  begin
    LPair.ReviewLevel := ALevel;
    LPair.ReviewRole := ARole;
    LPair.ReviewBasis := ABasis;
    LPair.ReviewReceipt := AReceipt;
  end;
end;

function FirstText(const AValues: array of String): String;
var
  LValue: String;
begin
  for LValue in AValues do
  begin
    if LValue <> '' then
    begin
      Exit(LValue);
    end;
  end;
  Result := '';
end;

procedure ImportReviews(const APath, AMode: String);
var
  LTable: TTsv;
  LIds: String;
  LId: String;
  LSource: String;
  LStudy: String;
  LStudyToken: String;
  LRole: String;
  LBasis: String;
  LLevel: Integer;
begin
  WriteLn(GInputProof, APath, Tab, AMode);
  LTable := TTsv.Create(GRoot + APath);
  try
    while LTable.Next do
    begin
      LIds := FirstText([LTable.Value('id'), LTable.Value('claim_ids'),
        LTable.Value('screened_claims')]);
      LSource := FirstText([LTable.Value('source_key'), LTable.Value('pmcid'),
        LTable.Value('study')]);
      LRole := FirstText([LTable.Value('result_role'), LTable.Value('disposition'),
        LTable.Value('role')]);
      LBasis := LTable.Value('review_basis');
      LLevel := 4;
      if AMode = 'date' then
      begin
        LIds := '0502';
        LSource := LTable.Value('provider_key');
        LRole := LTable.Value('context_disposition');
        LBasis := 'primary_text_exact_date_audit';
        LLevel := 5;
      end
      else if AMode = 'hidden' then
      begin
        LIds := Copy(LTable.Value('query_id'), 1, 4);
        LSource := LTable.Value('provider_key');
        LRole := 'excluded';
        LBasis := 'alternate_primary_text';
        LLevel := 5;
      end
      else if (LRole = 'pending') or (LRole = 'access pending') then
      begin
        LLevel := 1;
      end
      else if (LBasis = 'title_and_index') or (LRole = 'title screened') then
      begin
        LLevel := 2;
      end
      else if LBasis = 'abstract' then
      begin
        LLevel := 3;
      end
      else if (Pos('full_text', LBasis) > 0) or (AMode = 'body') or
        (LRole = 'body checked') or (Pos('citation checked', LRole) > 0) or
        (Pos('citations checked', LRole) > 0) then
      begin
        LLevel := 5;
      end;
      if LBasis = '' then
      begin
        LBasis := AMode;
      end;
      for LId in SplitFields(LIds, '|') do
      begin
        if AMode = 'assessment' then
        begin
          for LStudyToken in SplitFields(LSource, '|') do
          begin
            LStudy := Trim(LStudyToken);
            if DigitsOnly(LStudy) then
            begin
              LStudy := 'PMID:' + LStudy;
            end;
            ApplyReview(Trim(LId), LStudy, LRole, LBasis, APath + ':' + IntToStr(LTable.Line),
              LLevel, LTable.Value('local_reference'));
          end;
        end
        else
        begin
          ApplyReview(Trim(LId), LSource, LRole, LBasis, APath + ':' + IntToStr(LTable.Line),
            LLevel);
        end;
      end;
    end;
  finally
    LTable.Free;
  end;
end;

procedure ImportNarrative(const APath, AMode: String);
var
  LFile: TextFile;
  LContent: UTF8String;
  LCells: TFields;
  LSource: String;
  LId: String;
  LToken: String;
  LLine: Integer;
  LImported: Integer;
  LBefore: Integer;
  LClaimColumn: Integer;
  LSourceColumn: Integer;
  LIds: TStringList;
  LSources: TStringList;
  LTokens: TRegExpr;
  LPattern: TRegExpr;
begin
  AssignFile(LFile, GRoot + APath);
  Reset(LFile);
  LIds := NewMap(False);
  LSources := NewMap(False);
  LIds.Duplicates := dupIgnore;
  LSources.Duplicates := dupIgnore;
  LTokens := TRegExpr.Create('PMC[0-9]+|`[0-9]{4}`');
  LPattern := TRegExpr.Create('PMC[0-9]+');
  LLine := 0;
  LImported := 0;
  WriteLn(GInputProof, APath, Tab, AMode);
  try
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LContent);
      Inc(LLine);
      if not AnsiStartsStr('| ', LContent) then
      begin
        Continue;
      end;
      LCells := SplitFields(LContent, '|');
      if Length(LCells) < 5 then
      begin
        Continue;
      end;
      LBefore := GReviewSeen;
      if AMode = 'narrative_grouped_source' then
      begin
        LSource := '';
        if LTokens.Exec(LCells[2]) then
        begin
          repeat
            LToken := LTokens.Match[0];
            if AnsiStartsStr('PMC', LToken) then
            begin
              LSource := LToken;
            end
            else if LSource <> '' then
            begin
              ApplyReview(Copy(LToken, 2, 4), LSource, 'narrative disposition', AMode,
                APath + ':' + IntToStr(LLine), 5);
            end;
          until not LTokens.ExecNext;
        end;
      end
      else
      begin
        LSourceColumn := 1;
        LClaimColumn := 2;
        if AMode = 'narrative_protocol_or_titles' then
        begin
          LClaimColumn := 3;
        end
        else if AMode = 'narrative_orange' then
        begin
          LClaimColumn := 1;
          LSourceColumn := 2;
          if (Length(LCells) >= 6) and (Trim(LCells[3]) <> '') and
            (Trim(LCells[3])[1] in ['0'..'9']) then
          begin
            LSourceColumn := 4;
          end;
        end;
        LIds.Clear;
        LSources.Clear;
        if LTokens.Exec(LCells[LClaimColumn]) then
        begin
          repeat
            LToken := LTokens.Match[0];
            if LToken[1] = '`' then
            begin
              LIds.Add(Copy(LToken, 2, 4));
            end;
          until not LTokens.ExecNext;
        end;
        if LPattern.Exec(LCells[LSourceColumn]) then
        begin
          repeat
            LSources.Add(LPattern.Match[0]);
          until not LPattern.ExecNext;
        end;
        if (LIds.Count <= 1) or (LSources.Count <= 1) then
        begin
          for LId in LIds do
          begin
            for LSource in LSources do
            begin
              ApplyReview(LId, LSource, 'narrative disposition', AMode,
                APath + ':' + IntToStr(LLine), 5);
            end;
          end;
        end
        else
        begin
          WriteLn(StdErr, 'Narrative row requires manual exact-key mapping: ', APath, ':', LLine);
        end;
      end;
      Inc(LImported, GReviewSeen - LBefore);
    end;
  finally
    CloseFile(LFile);
    LPattern.Free;
    LTokens.Free;
    LSources.Free;
    LIds.Free;
  end;
  WriteLn(APath, ' explicit narrative review observations: ', LImported);
end;

procedure ImportExactReviews(const APath: String);
const
  CColumns: array[0..5] of String = ('id', 'source_key', 'result_role', 'review_basis',
    'local_reference', 'rationale');
var
  LTable: TTsv;
  LSeen: TStringList;
  LValidatedFiles: TStringList;
  LId: String;
  LKey: String;
  LRole: String;
  LBasis: String;
  LReference: String;
  LFile: String;
  LReceipt: String;
  LLevel: Integer;
  LHash: Integer;
  I: Integer;
begin
  LTable := TTsv.Create(GRoot + APath);
  LSeen := NewMap(False);
  LValidatedFiles := NewMap(False);
  try
    Require(Length(LTable.FHeader) = Length(CColumns), 'Invalid exact-review schema: ' + APath);
    for I := Low(CColumns) to High(CColumns) do
    begin
      Require(LTable.FHeader[I] = CColumns[I], 'Invalid exact-review schema: ' + APath);
    end;
    WriteLn(GInputProof, APath, Tab, 'strict_exact');
    while LTable.Next do
    begin
      LReceipt := APath + ':' + IntToStr(LTable.Line);
      LId := LTable.Value('id');
      LKey := LTable.Value('source_key');
      LRole := LTable.Value('result_role');
      LBasis := LTable.Value('review_basis');
      LReference := LTable.Value('local_reference');
      Require(FindObject(GPairs, PairKey(ClaimNumber(LId), LKey)) <> nil,
        'Exact review must match an overlay claim and provider key: ' + LReceipt);
      Require(LSeen.IndexOf(LId + Tab + LKey) < 0, 'Repeated exact review: ' + LReceipt);
      LSeen.Add(LId + Tab + LKey);
      Require(IndexStr(LRole, ['excluded', 'related', 'supports', 'opposes', 'inconclusive',
        'pending']) >= 0, 'Unknown exact-review role: ' + LReceipt);
      case IndexStr(LBasis, ['access_only', 'title_and_index', 'abstract',
        'assessment_unspecified', 'full_text', 'primary_source']) of
        0: LLevel := 1;
        1: LLevel := 2;
        2: LLevel := 3;
        3: LLevel := 4;
        4, 5: LLevel := 5;
      else
        raise EConvertError.Create('Unknown exact-review basis: ' + LReceipt);
      end;
      Require((LBasis <> 'access_only') or (LRole = 'pending'),
        'An access-only receipt requires pending role: ' + LReceipt);
      if LRole = 'pending' then
      begin
        LLevel := 1;
      end;
      LFile := LReference;
      LHash := Pos('#', LFile);
      if LHash > 0 then
      begin
        LFile := Copy(LFile, 1, LHash - 1);
      end;
      Require(((AnsiStartsStr('research/', LFile)) or
        (AnsiStartsStr('experiments/', LFile))) and (Pos(':', LFile) = 0) and
        (Pos('\', LFile) = 0) and (Pos('/../', LFile + '/') = 0),
        'Missing or invalid local review reference: ' + LReceipt);
      if LValidatedFiles.IndexOf(LFile) < 0 then
      begin
        Require(FileExists(GRoot + '../../' + LFile),
          'Missing or invalid local review reference: ' + LReceipt);
        LValidatedFiles.Add(LFile);
      end;
      Require(Trim(LTable.Value('rationale')) <> '', 'Missing exact-review rationale: ' + LReceipt);
      ApplyReview(LId, LKey, LRole, LBasis, LReceipt, LLevel);
    end;
  finally
    LValidatedFiles.Free;
    LSeen.Free;
    LTable.Free;
  end;
end;

procedure AddReviewGlob(const AGlob: String);
var
  LResult: TSearchRec;
begin
  if FindFirst(GRoot + 'followup/' + AGlob, faAnyFile, LResult) <> 0 then
  begin
    Exit;
  end;
  try
    repeat
      GReviewFiles.Add(LResult.Name);
    until FindNext(LResult) <> 0;
  finally
    SysUtils.FindClose(LResult);
  end;
end;

procedure LoadReviews(const AExtra: String);
var
  LFile: String;
  LFiles: TStringList;
  LFields: TFields;
begin
  AddReviewGlob('claim-query-*-dispositions.tsv');
  AddReviewGlob('claim-local-text-*-dispositions.tsv');
  AddReviewGlob('archive-body-*-dispositions.tsv');
  GReviewFiles.Add('local-citation-trail-food-dispositions.tsv');
  GReviewFiles.Add('assessments.tsv');
  for LFile in GReviewFiles do
  begin
    if AnsiStartsStr('archive-body-', LFile) or
      (LFile = 'claim-local-text-herb-spice-oil-dispositions.tsv') then
    begin
      ImportReviews('followup/' + LFile, 'body');
    end
    else if LFile = 'assessments.tsv' then
    begin
      ImportReviews('followup/' + LFile, 'assessment');
    end
    else
    begin
      ImportReviews('followup/' + LFile, 'exact_disposition_basis_unspecified');
    end;
  end;
  ImportReviews('followup/date-metadata-body-audit.tsv', 'date');
  ImportReviews('followup/claim-query-provider-hidden-records.tsv', 'hidden');
  LFiles := TStringList.Create;
  try
    LFiles.LoadFromFile(AExtra);
    for LFile in LFiles do
    begin
      if Trim(LFile) <> '' then
      begin
        LFields := SplitFields(LFile, Tab);
        Require(Length(LFields) = 2, 'Expected additional review path and basis');
        if AnsiStartsStr('narrative_', LFields[1]) then
        begin
          ImportNarrative(LFields[0], LFields[1]);
        end
        else if LFields[1] = 'strict_exact' then
        begin
          ImportExactReviews(LFields[0]);
        end
        else
        begin
          ImportReviews(LFields[0], LFields[1]);
        end;
      end;
    end;
  finally
    LFiles.Free;
  end;
  if FileExists(GRoot + 'followup/context-coverage/exact-reviews.tsv') then
  begin
    ImportExactReviews('followup/context-coverage/exact-reviews.tsv');
  end;
end;

procedure LoadArchiveRetrieval;
const
  CReceipt = 'research/PMC-Text-Retrieval.tsv';
var
  LTable: TTsv;
  LSource: TSource;
  LPmcid: String;
begin
  LTable := TTsv.Create(GRoot + '../../' + CReceipt);
  try
    while LTable.Next do
    begin
      LPmcid := LTable.Value('pmcid');
      LSource := ResolveSource(LPmcid);
      if (LSource = nil) or (LSource.Pmcid <> LPmcid) then
      begin
        Continue;
      end;
      Require(LSource.PipelineReceipt = '', 'Duplicate archive-retrieval source ' + LPmcid);
      LSource.PipelineStatus := LTable.Value('retrieval_status');
      LSource.PipelineReceipt := CReceipt + ':' + IntToStr(LTable.Line);
      LSource.PipelineLicense := LTable.Value('license');
      LSource.PipelineVersion := LTable.Value('version');
    end;
  finally
    LTable.Free;
  end;
end;

procedure LoadAccess;
var
  LTable: TTsv;
  LSource: TSource;
  LAccess: TAccess;
  LKey: String;
begin
  LTable := TTsv.Create(GRoot + 'followup/abstract-access.tsv');
  try
    while LTable.Next do
    begin
      LSource := ResolveSource(LTable.Value('source_key'));
      if LSource = nil then
      begin
        Continue;
      end;
      LKey := LTable.Value('ingredient') + Tab + LSource.Key;
      LAccess := TAccess(FindObject(GAccess, LKey));
      if LAccess = nil then
      begin
        LAccess := TAccess.Create;
        GAccess.AddObject(LKey, LAccess);
      end;
      LAccess.Level := LTable.Value('access_level');
      LAccess.Gap := LTable.Value('remaining_access_gap');
      LAccess.Receipt := 'followup/abstract-access.tsv:' + IntToStr(LTable.Line);
    end;
  finally
    LTable.Free;
  end;
end;

function Priority(APair: TPair): Integer;
var
  LClinical: Boolean;
  LIndexedExposure: Boolean;
  LBodyExposure: Boolean;
begin
  LClinical := (APair.Triage = 'human evidence candidate') or
    (APair.Triage = 'protocol or registration');
  LIndexedExposure := APair.IndexedFlags[0] or APair.IndexedFlags[1];
  LBodyExposure := APair.BodyFlags[0] or APair.BodyFlags[1];
  if LClinical and LBodyExposure and APair.BodyFlags[2] then
  begin
    Exit(1);
  end;
  if LClinical and LIndexedExposure and APair.IndexedFlags[2] then
  begin
    Exit(2);
  end;
  if (LBodyExposure and APair.BodyFlags[2]) or (LIndexedExposure and APair.IndexedFlags[2]) then
  begin
    Exit(3);
  end;
  if LClinical then
  begin
    Exit(4);
  end;
  if LIndexedExposure or LBodyExposure or APair.IndexedFlags[2] or APair.BodyFlags[2] then
  begin
    Exit(5);
  end;
  Result := 6;
end;

function PairRow(APair: TPair; APriority: Integer): String;
var
  LClaim: TClaim;
  LSource: TSource;
  LAccess: TAccess;
  LBodyFlags: String;
  LArchiveState: String;
  LAccessFields: String;
  I: Integer;
begin
  LClaim := GClaims[APair.Claim];
  LSource := APair.Source;
  LAccess := TAccess(FindObject(GAccess, LClaim.Ingredient + Tab + LSource.Key));
  LAccessFields := Tab + Tab;
  if LAccess <> nil then
  begin
    LAccessFields := LAccess.Receipt + Tab + LAccess.Level + Tab + LAccess.Gap;
  end;
  LArchiveState := 'no_archived_text_join';
  LBodyFlags := Tab + Tab + Tab;
  if APair.ArchivePath <> '' then
  begin
    LArchiveState := 'archived_text_joined';
    LBodyFlags := '';
    for I := 0 to 2 do
    begin
      LBodyFlags := LBodyFlags + BoolToStr(APair.BodyFlags[I], True) + Tab;
    end;
  end;
  Result := IntToStr(APriority) + Tab + Reasons[APriority] + Tab + LClaim.Id + Tab +
    LSource.Key + Tab + LClaim.Category + Tab + LClaim.Ingredient + Tab + LClaim.Preparation +
    Tab + LClaim.Symptom + Tab + IntToStr(APair.Ranks[1]) + Tab + IntToStr(APair.Ranks[2]) +
    Tab + APair.Triage + Tab;
  for I := 0 to 2 do
  begin
    Result := Result + BoolToStr(APair.IndexedFlags[I], True) + Tab;
  end;
  Result := Result + LBodyFlags + LSource.Pmid + Tab + LSource.Pmcid + Tab + LSource.Doi +
    Tab + LSource.Date + Tab + LSource.Title + Tab + ReviewStates[APair.ReviewLevel] + Tab +
    APair.ReviewRole + Tab + APair.ReviewBasis + Tab + APair.ReviewReceipt + Tab +
    IntToStr(APair.ReviewCount) + Tab + LArchiveState + Tab + APair.ArchiveScope + Tab +
    APair.ArchivePath + Tab + BoolToStr(LSource.HasAbstract, True) + Tab + LAccessFields + Tab +
    LSource.PipelineStatus + Tab + LSource.PipelineReceipt + Tab + LSource.PipelineLicense +
    Tab + LSource.PipelineVersion;
end;

procedure WriteSourceQueue(AExpectedPairs: Integer);
var
  LReport: TextFile;
  LReportBuffer: TBytes;
  LSource: TSource;
  LQueuedSources: Integer;
  LTotalPairs: Integer;
  I: Integer;
  J: Integer;
begin
  LQueuedSources := 0;
  LTotalPairs := 0;
  SetLength(LReportBuffer, ReportBufferSize);
  AssignFile(LReport, GOutput + 'context-queue-by-source.tsv');
  SetTextBuf(LReport, LReportBuffer[0], Length(LReportBuffer));
  Rewrite(LReport);
  try
    Write(LReport, 'source_key', Tab, 'title', Tab, 'publication_date', Tab, 'pmid', Tab,
      'pmcid', Tab, 'doi', Tab, 'queued_pairs', Tab, 'queued_archive_pairs', Tab,
      'indexed_abstract', Tab, 'pmc_pipeline_status');
    for J := Low(Reasons) to High(Reasons) do
    begin
      Write(LReport, Tab, 'queue_priority_', J);
    end;
    WriteLn(LReport);
    for I := 0 to GSources.Count - 1 do
    begin
      LSource := TSource(GSources.Objects[I]);
      if LSource.QueuedPairs = 0 then
      begin
        Continue;
      end;
      Inc(LQueuedSources);
      Inc(LTotalPairs, LSource.QueuedPairs);
      Write(LReport, LSource.Key, Tab, LSource.Title, Tab, LSource.Date, Tab, LSource.Pmid,
        Tab, LSource.Pmcid, Tab, LSource.Doi, Tab, LSource.QueuedPairs, Tab,
        LSource.QueuedArchivePairs, Tab, BoolToStr(LSource.HasAbstract, True), Tab,
        LSource.PipelineStatus);
      for J := Low(Reasons) to High(Reasons) do
      begin
        Write(LReport, Tab, LSource.QueueByPriority[J]);
      end;
      WriteLn(LReport);
    end;
  finally
    CloseFile(LReport);
  end;
  Require(LTotalPairs = AExpectedPairs, 'Source queue does not reconcile to the exact-pair queue.');
  WriteLn('Sources with queued pairs: ', LQueuedSources);
end;

procedure WriteReports;
var
  LAll: TextFile;
  LAllBuffer: TBytes;
  LQueue: TextFile;
  LQueueBuffer: TBytes;
  LPriorityLocal: TextFile;
  LPriorityIndexed: TextFile;
  LCoverage: TextFile;
  LPair: TPair;
  LRow: String;
  LLevel: Integer;
  LQueueCount: Integer;
  LReviewTotals: array[0..5] of Integer;
  LQueueTotals: array[1..6] of Integer;
  LAccessTotals: array[0..3] of Integer;
  LAccessIndex: Integer;
  I: Integer;
  J: Integer;
begin
  LQueueCount := 0;
  FillChar(LReviewTotals, SizeOf(LReviewTotals), 0);
  FillChar(LQueueTotals, SizeOf(LQueueTotals), 0);
  FillChar(LAccessTotals, SizeOf(LAccessTotals), 0);
  SetLength(LAllBuffer, ReportBufferSize);
  SetLength(LQueueBuffer, ReportBufferSize);
  AssignFile(LAll, GOutput + 'all-overlay-pairs.tsv');
  SetTextBuf(LAll, LAllBuffer[0], Length(LAllBuffer));
  AssignFile(LQueue, GOutput + 'context-queue.tsv');
  SetTextBuf(LQueue, LQueueBuffer[0], Length(LQueueBuffer));
  AssignFile(LPriorityLocal, GOutput + 'priority-1-local.tsv');
  AssignFile(LPriorityIndexed, GOutput + 'priority-2-indexed.tsv');
  AssignFile(LCoverage, GOutput + 'coverage-by-claim.tsv');
  Rewrite(LAll);
  try
    Rewrite(LQueue);
    try
      WriteLn(LAll, CandidateHeader);
      Rewrite(LPriorityLocal);
      Rewrite(LPriorityIndexed);
      WriteLn(LQueue, CandidateHeader);
      WriteLn(LPriorityLocal, CandidateHeader);
      WriteLn(LPriorityIndexed, CandidateHeader);
      for LLevel := Low(Reasons) to High(Reasons) do
      begin
        for I := 0 to GPairs.Count - 1 do
        begin
          LPair := TPair(GPairs.Objects[I]);
          if Priority(LPair) <> LLevel then
          begin
            Continue;
          end;
          Inc(GClaims[LPair.Claim].Pairs);
          Inc(GClaims[LPair.Claim].Review[LPair.ReviewLevel]);
          Inc(LReviewTotals[LPair.ReviewLevel]);
          LAccessIndex := 0;
          if LPair.Source.HasAbstract then
          begin
            Inc(LAccessIndex);
          end;
          if LPair.ArchivePath <> '' then
          begin
            Inc(GClaims[LPair.Claim].JoinCount);
            Inc(LAccessIndex, 2);
          end;
          Inc(LAccessTotals[LAccessIndex]);
          LRow := PairRow(LPair, LLevel);
          WriteLn(LAll, LRow);
          if LPair.ReviewLevel <= 2 then
          begin
            Inc(LQueueCount);
            Inc(LQueueTotals[LLevel]);
            Inc(GClaims[LPair.Claim].Queue[LLevel]);
            Inc(LPair.Source.QueuedPairs);
            Inc(LPair.Source.QueueByPriority[LLevel]);
            if LPair.ArchivePath <> '' then
            begin
              Inc(LPair.Source.QueuedArchivePairs);
            end;
            WriteLn(LQueue, LRow);
            if LLevel = 1 then
            begin
              WriteLn(LPriorityLocal, LRow);
            end
            else if LLevel = 2 then
            begin
              WriteLn(LPriorityIndexed, LRow);
            end;
          end;
        end;
      end;
    finally
      CloseFile(LPriorityIndexed);
      CloseFile(LPriorityLocal);
      CloseFile(LQueue);
    end;
  finally
    CloseFile(LAll);
  end;
  Rewrite(LCoverage);
  try
    Write(LCoverage, 'id', Tab, 'category', Tab, 'ingredient', Tab, 'overlay_pairs', Tab,
      'joined_archive');
    for J := Low(ReviewStates) to High(ReviewStates) do
    begin
      Write(LCoverage, Tab, ReviewStates[J]);
    end;
    for J := Low(Reasons) to High(Reasons) do
    begin
      Write(LCoverage, Tab, 'queue_priority_', J);
    end;
    WriteLn(LCoverage);
    for I := Low(GClaims) to High(GClaims) do
    begin
      Write(LCoverage, GClaims[I].Id, Tab, GClaims[I].Category, Tab, GClaims[I].Ingredient,
        Tab, GClaims[I].Pairs, Tab, GClaims[I].JoinCount);
      for J := Low(ReviewStates) to High(ReviewStates) do
      begin
        Write(LCoverage, Tab, GClaims[I].Review[J]);
      end;
      for J := Low(Reasons) to High(Reasons) do
      begin
        Write(LCoverage, Tab, GClaims[I].Queue[J]);
      end;
      WriteLn(LCoverage);
    end;
  finally
    CloseFile(LCoverage);
  end;
  WriteLn('Ambiguous alias-source links: ', GCollisionKeys.Count);
  GCollisionKeys.Sorted := False;
  GCollisionKeys.Insert(0, 'alias' + Tab + 'overlay_source_key');
  GCollisionKeys.SaveToFile(GOutput + 'ambiguous-source-aliases.tsv');
  WriteLn('Retrieved memberships: ', GMemberships);
  WriteLn('Exact claim-source pairs: ', GPairs.Count, ' across ', GSources.Count, ' source keys');
  WriteLn('Lexical bibliographic rows: ', GScreenRows, '; archived join rows: ', GBodyRows);
  WriteLn('Review inputs: ', GReviewSeen, '; joined observations: ', GReviewedJoins,
    '; outside overlay or unresolved alias: ', GSourceMismatches);
  WriteLn('Assessments held for conflicting PMC aliases: ', GAssessmentAliasConflicts);
  for J := Low(ReviewStates) to High(ReviewStates) do
  begin
    WriteLn(ReviewStates[J], ': ', LReviewTotals[J]);
  end;
  WriteLn('Context queue: ', LQueueCount);
  WriteSourceQueue(LQueueCount);
  for J := Low(Reasons) to High(Reasons) do
  begin
    WriteLn('Priority ', J, ': ', LQueueTotals[J]);
  end;
  WriteLn('Access: neither abstract nor archive join ', LAccessTotals[0], '; abstract only ',
    LAccessTotals[1], '; archive join only ', LAccessTotals[2], '; both ', LAccessTotals[3]);
end;

procedure Run;
begin
  Require(ParamCount = 4,
    'Usage: foodexperiment.contextqueue EXPERIMENT OVERLAY_RESULTS OUTPUT EXTRA_REVIEW_PATHS');
  GRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  GOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3)));
  Require(ForceDirectories(GOutput), 'Cannot create staging output');
  GSources := NewMap(True);
  GAliases := NewMap(False);
  GCollisionKeys := NewMap(False);
  GCollisionKeys.Duplicates := dupIgnore;
  GPairs := NewMap(True);
  GAccess := NewMap(True);
  GReviewFiles := NewMap(False);
  try
    LoadClaims;
    LoadOverlay(ParamStr(2));
    LoadScreens;
    LoadAccess;
    LoadArchiveRetrieval;
    AssignFile(GInputProof, GOutput + 'review-inputs.tsv');
    Rewrite(GInputProof);
    try
      WriteLn(GInputProof, 'path', Tab, 'input_basis');
      LoadReviews(ParamStr(4));
    finally
      CloseFile(GInputProof);
    end;
    WriteReports;
  finally
    GReviewFiles.Free;
    GAccess.Free;
    GPairs.Free;
    GCollisionKeys.Free;
    GAliases.Free;
    GSources.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
