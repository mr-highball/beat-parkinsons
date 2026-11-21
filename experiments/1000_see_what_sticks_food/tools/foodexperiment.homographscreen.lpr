{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentHomographScreen;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata, foodexperiment.homograph;

const
  CReviewHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9 +
    'local_reference'#9'rationale';
  CLf = #10;

type
  TOverlayMeta = class
    Title: String;
    Journal: String;
    AbstractText: String;
    Pmid: String;
    Doi: String;
    Source: String;
    SourceId: String;
  end;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function ReadFileText(const APath: String): String;
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, Integer(LStream.Size));
    if LBytes <> '' then
    begin
      LStream.ReadBuffer(LBytes[1], Length(LBytes));
    end;
    Result := String(LBytes);
  finally
    LStream.Free;
  end;
end;

function IsEligibleArchiveScope(const AScope: String): Boolean;
begin
  Result := (AScope = 'body before references') or
    (AScope = 'text before references') or
    (AScope = 'body to end');
end;

function ColumnIndex(const AHeader: TFields; const AName: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AHeader) do
  begin
    if AHeader[I] = AName then
    begin
      Exit(I);
    end;
  end;
  raise EConvertError.Create('Missing required TSV column: ' + AName);
end;

procedure RunBenchmark(const ARoot, AAllPairsPath: String);
var
  LFile: TextFile;
  LBuffer: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader: TFields;
  LFields: TFields;
  CId, CSource, CIng, CState, CRole, CArchState, CArchScope, CArchPath: Integer;
  LIng, LScope, LArchPath, LRole, LFullPath: String;
  LRes: THomographResult;
  LCheckedExcl, LCaughtExcl, LCheckedRel, LFalseExcl: Integer;
  LCache: TStringList;
  LCacheIdx: Integer;
  LCacheKey: String;
begin
  AssignFile(LFile, AAllPairsPath);
  SetTextBuf(LFile, LBuffer);
  Reset(LFile);
  LCache := TStringList.Create;
  try
    LCache.Sorted := True;
    LCache.CaseSensitive := True;
    LCache.Duplicates := dupIgnore;
    ReadLn(LFile, LLine);
    LHeader := SplitFields(LLine, #9);
    CId := ColumnIndex(LHeader, 'id');
    CSource := ColumnIndex(LHeader, 'source_key');
    CIng := ColumnIndex(LHeader, 'ingredient');
    CState := ColumnIndex(LHeader, 'review_state');
    CRole := ColumnIndex(LHeader, 'prior_role');
    CArchState := ColumnIndex(LHeader, 'archive_state');
    CArchScope := ColumnIndex(LHeader, 'archive_scope');
    CArchPath := ColumnIndex(LHeader, 'archive_path');

    LCheckedExcl := 0;
    LCaughtExcl := 0;
    LCheckedRel := 0;
    LFalseExcl := 0;

    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LLine, #9);
      LIng := LFields[CIng];
      if not IsSupportedHomograph(LIng) then
      begin
        Continue;
      end;
      if LFields[CArchState] <> 'archived_text_joined' then
      begin
        Continue;
      end;
      LScope := LFields[CArchScope];
      if not IsEligibleArchiveScope(LScope) then
      begin
        Continue;
      end;
      if LFields[CState] <> 'body_or_primary_context_reviewed' then
      begin
        Continue;
      end;
      LRole := LFields[CRole];
      if (LRole <> 'excluded') and (LRole <> 'related') then
      begin
        Continue;
      end;
      LArchPath := LFields[CArchPath];
      LFullPath := IncludeTrailingPathDelimiter(ARoot) +
        StringReplace(LArchPath, '/', PathDelim, [rfReplaceAll]);
      if not FileExists(LFullPath) then
      begin
        Continue;
      end;

      LCacheKey := LIng + #9 + LArchPath;
      if LCache.Find(LCacheKey, LCacheIdx) then
      begin
        LRes.Verdict := THomographVerdict(PtrInt(LCache.Objects[LCacheIdx]));
      end
      else
      begin
        LRes := ScreenHomographText(LIng, ReadFileText(LFullPath));
        LCache.AddObject(LCacheKey, TObject(PtrInt(Ord(LRes.Verdict))));
      end;

      if LRole = 'excluded' then
      begin
        Inc(LCheckedExcl);
        if LRes.Verdict in [hvPureCollision, hvZeroOccurrences] then
        begin
          Inc(LCaughtExcl);
        end;
      end
      else
      begin
        Inc(LCheckedRel);
        if LRes.Verdict in [hvPureCollision, hvZeroOccurrences] then
        begin
          Inc(LFalseExcl);
          WriteLn('RELATED_FLAGGED'#9, LFields[CId], #9, LFields[CSource], #9,
            LIng, #9, LArchPath, #9, Ord(LRes.Verdict));
        end;
      end;
    end;
    WriteLn('BENCHMARK checked_excluded=', LCheckedExcl, ' caught_excluded=', LCaughtExcl,
      ' checked_related=', LCheckedRel, ' related_flagged=', LFalseExcl);
  finally
    LCache.Free;
    CloseFile(LFile);
  end;
end;

procedure RunScreen(const ARoot, AQueuePath, AOutputProposalsPath, AOutputReportPath: String);
var
  LFile: TextFile;
  LBuffer: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader: TFields;
  LFields: TFields;
  CId, CSource, CIng, CArchState, CArchScope, CArchPath: Integer;
  LIng, LScope, LArchPath, LFullPath: String;
  LRes: THomographResult;
  LProposals: TStringList;
  LReport: TStringList;
  LTotalEligible, LExcluded, LFoodKept, LAmbiguousKept: Integer;
begin
  AssignFile(LFile, AQueuePath);
  SetTextBuf(LFile, LBuffer);
  Reset(LFile);
  LProposals := TStringList.Create;
  LReport := TStringList.Create;
  try
    LProposals.Add(CReviewHeader);
    LReport.Add('id'#9'source_key'#9'ingredient'#9'verdict'#9'total_hits'#9'collision_hits'#9 +
      'detail'#9'archive_path');
    ReadLn(LFile, LLine);
    LHeader := SplitFields(LLine, #9);
    CId := ColumnIndex(LHeader, 'id');
    CSource := ColumnIndex(LHeader, 'source_key');
    CIng := ColumnIndex(LHeader, 'ingredient');
    CArchState := ColumnIndex(LHeader, 'archive_state');
    CArchScope := ColumnIndex(LHeader, 'archive_scope');
    CArchPath := ColumnIndex(LHeader, 'archive_path');

    LTotalEligible := 0;
    LExcluded := 0;
    LFoodKept := 0;
    LAmbiguousKept := 0;

    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LLine, #9);
      LIng := LFields[CIng];
      if not IsSupportedHomograph(LIng) then
      begin
        Continue;
      end;
      if LFields[CArchState] <> 'archived_text_joined' then
      begin
        Continue;
      end;
      LScope := LFields[CArchScope];
      if not IsEligibleArchiveScope(LScope) then
      begin
        Continue;
      end;
      LArchPath := LFields[CArchPath];
      LFullPath := IncludeTrailingPathDelimiter(ARoot) +
        StringReplace(LArchPath, '/', PathDelim, [rfReplaceAll]);
      if not FileExists(LFullPath) then
      begin
        Continue;
      end;

      Inc(LTotalEligible);
      LRes := ScreenHomographText(LIng, ReadFileText(LFullPath));
      if LRes.Verdict in [hvPureCollision, hvZeroOccurrences] then
      begin
        Inc(LExcluded);
        LProposals.Add(LFields[CId] + #9 + LFields[CSource] + #9'excluded'#9'full_text'#9 +
          LArchPath + #9 + LRes.CollisionSummary);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'excluded'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          LRes.CollisionSummary + #9 + LArchPath);
      end
      else if LRes.Verdict = hvFoodMention then
      begin
        Inc(LFoodKept);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'kept_food_term'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          LRes.FoodTrigger + #9 + LArchPath);
      end
      else
      begin
        Inc(LAmbiguousKept);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'kept_ambiguous'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          StringReplace(LRes.UnexplainedSample, #9, ' ', [rfReplaceAll]) + #9 + LArchPath);
      end;
    end;

    LProposals.LineBreak := CLf;
    LProposals.WriteBOM := False;
    LProposals.SaveToFile(AOutputProposalsPath, TEncoding.UTF8);
    LReport.LineBreak := CLf;
    LReport.WriteBOM := False;
    LReport.SaveToFile(AOutputReportPath, TEncoding.UTF8);

    WriteLn('SCREEN eligible=', LTotalEligible, ' proposals_excluded=', LExcluded,
      ' kept_food_term=', LFoodKept, ' kept_ambiguous=', LAmbiguousKept);
  finally
    LReport.Free;
    LProposals.Free;
    CloseFile(LFile);
  end;
end;

function LoadOverlayMeta(const AOverlayPath: String): TStringList;
var
  LFile: TextFile;
  LBuffer: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader: TFields;
  LFields: TFields;
  CSrcKey, CSource, CSrcId, CPmid, CDoi, CTitle, CJournal, CAbstract, CIng: Integer;
  LKey: String;
  LIdx: Integer;
  LMeta: TOverlayMeta;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.Duplicates := dupIgnore;
  Result.OwnsObjects := True;
  AssignFile(LFile, AOverlayPath);
  SetTextBuf(LFile, LBuffer);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    LHeader := SplitFields(LLine, #9);
    CIng := ColumnIndex(LHeader, 'ingredient');
    CSrcKey := ColumnIndex(LHeader, 'source_key');
    CSource := ColumnIndex(LHeader, 'source');
    CSrcId := ColumnIndex(LHeader, 'source_id');
    CPmid := ColumnIndex(LHeader, 'pmid');
    CDoi := ColumnIndex(LHeader, 'doi');
    CTitle := ColumnIndex(LHeader, 'title');
    CJournal := ColumnIndex(LHeader, 'journal');
    CAbstract := ColumnIndex(LHeader, 'abstract');
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LLine, #9);
      if (Length(LFields) <= CAbstract) or not IsSupportedHomograph(LFields[CIng]) then
      begin
        Continue;
      end;
      LKey := LFields[CSrcKey];
      if Result.Find(LKey, LIdx) then
      begin
        LMeta := TOverlayMeta(Result.Objects[LIdx]);
        if (LMeta.AbstractText = '') and (LFields[CAbstract] <> '') then
        begin
          LMeta.AbstractText := LFields[CAbstract];
        end;
        Continue;
      end;
      LMeta := TOverlayMeta.Create;
      LMeta.Title := LFields[CTitle];
      LMeta.Journal := LFields[CJournal];
      LMeta.AbstractText := LFields[CAbstract];
      LMeta.Pmid := LFields[CPmid];
      LMeta.Doi := LFields[CDoi];
      LMeta.Source := LFields[CSource];
      LMeta.SourceId := LFields[CSrcId];
      Result.AddObject(LKey, LMeta);
    end;
  finally
    CloseFile(LFile);
  end;
end;

function MetaReference(AMeta: TOverlayMeta): String;
begin
  if AMeta.Pmid <> '' then
  begin
    Result := 'https://pubmed.ncbi.nlm.nih.gov/' + AMeta.Pmid + '/';
  end
  else if AMeta.Doi <> '' then
  begin
    Result := 'https://doi.org/' + AMeta.Doi;
  end
  else if (AMeta.Source <> '') and (AMeta.SourceId <> '') then
  begin
    Result := 'https://europepmc.org/article/' + AMeta.Source + '/' + AMeta.SourceId;
  end
  else
  begin
    Result := '';
  end;
end;

procedure RunAbstractBenchmark(const AOverlayPath, AAllPairsPath: String);
var
  LMetaMap: TStringList;
  LFile: TextFile;
  LBuffer: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader: TFields;
  LFields: TFields;
  CId, CSource, CIng, CState, CRole: Integer;
  LIng, LRole: String;
  LIdx: Integer;
  LMeta: TOverlayMeta;
  LRes: THomographResult;
  LCheckedExcl, LCaughtExcl, LCheckedRel, LRelFlagged: Integer;
begin
  LMetaMap := LoadOverlayMeta(AOverlayPath);
  AssignFile(LFile, AAllPairsPath);
  SetTextBuf(LFile, LBuffer);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    LHeader := SplitFields(LLine, #9);
    CId := ColumnIndex(LHeader, 'id');
    CSource := ColumnIndex(LHeader, 'source_key');
    CIng := ColumnIndex(LHeader, 'ingredient');
    CState := ColumnIndex(LHeader, 'review_state');
    CRole := ColumnIndex(LHeader, 'prior_role');

    LCheckedExcl := 0;
    LCaughtExcl := 0;
    LCheckedRel := 0;
    LRelFlagged := 0;

    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LLine, #9);
      LIng := LFields[CIng];
      if not IsSupportedHomograph(LIng) then
      begin
        Continue;
      end;
      if LFields[CState] <> 'body_or_primary_context_reviewed' then
      begin
        Continue;
      end;
      LRole := LFields[CRole];
      if (LRole <> 'excluded') and (LRole <> 'related') then
      begin
        Continue;
      end;
      if not LMetaMap.Find(LFields[CSource], LIdx) then
      begin
        Continue;
      end;
      LMeta := TOverlayMeta(LMetaMap.Objects[LIdx]);
      if Trim(LMeta.AbstractText) = '' then
      begin
        Continue;
      end;
      LRes := ScreenHomographText(LIng, LMeta.Title + ' ' + LMeta.Journal + ' ' + LMeta.AbstractText);
      if LRole = 'excluded' then
      begin
        Inc(LCheckedExcl);
        if LRes.Verdict = hvPureCollision then
        begin
          Inc(LCaughtExcl);
        end;
      end
      else
      begin
        Inc(LCheckedRel);
        if LRes.Verdict = hvPureCollision then
        begin
          Inc(LRelFlagged);
          WriteLn('ABS_RELATED_FLAGGED'#9, LFields[CId], #9, LFields[CSource], #9,
            LIng, #9, LRes.TotalHits, #9, LRes.CollisionSummary);
        end;
      end;
    end;
    WriteLn('ABSTRACT_BENCHMARK checked_excluded=', LCheckedExcl,
      ' caught_excluded=', LCaughtExcl, ' checked_related=', LCheckedRel,
      ' related_flagged=', LRelFlagged);
  finally
    CloseFile(LFile);
    LMetaMap.Free;
  end;
end;

procedure RunAbstractTriage(const AOverlayPath, AQueuePath, AOutputReportPath: String);
var
  LMetaMap: TStringList;
  LFile: TextFile;
  LBuffer: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader: TFields;
  LFields: TFields;
  CId, CSource, CIng, CArchState, CIdxAbs: Integer;
  LIng, LRef, LRationale: String;
  LIdx: Integer;
  LMeta: TOverlayMeta;
  LRes: THomographResult;
  LReport: TStringList;
  LTotalEligible, LCollision, LFoodKept, LZeroKept, LAmbiguousKept: Integer;
begin
  // Triage-only: surfaces unarchived abstracts that genuinely mention food/botanical
  // terms for prioritized review. Does NOT emit auto-exclusion proposals because
  // full text can mention a botanical synonym even when the abstract only has a
  // temporal/lexical collision (verified empirically on PMID:42123391).
  LMetaMap := LoadOverlayMeta(AOverlayPath);
  AssignFile(LFile, AQueuePath);
  SetTextBuf(LFile, LBuffer);
  Reset(LFile);
  LReport := TStringList.Create;
  try
    LReport.Add('id'#9'source_key'#9'ingredient'#9'triage'#9'total_hits'#9'collision_hits'#9 +
      'detail'#9'reference');
    ReadLn(LFile, LLine);
    LHeader := SplitFields(LLine, #9);
    CId := ColumnIndex(LHeader, 'id');
    CSource := ColumnIndex(LHeader, 'source_key');
    CIng := ColumnIndex(LHeader, 'ingredient');
    CArchState := ColumnIndex(LHeader, 'archive_state');
    CIdxAbs := ColumnIndex(LHeader, 'indexed_abstract');

    LTotalEligible := 0;
    LCollision := 0;
    LFoodKept := 0;
    LZeroKept := 0;
    LAmbiguousKept := 0;

    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(LLine, #9);
      LIng := LFields[CIng];
      if not IsSupportedHomograph(LIng) then
      begin
        Continue;
      end;
      if (LFields[CArchState] <> 'no_archived_text_join') or (LFields[CIdxAbs] <> 'True') then
      begin
        Continue;
      end;
      if not LMetaMap.Find(LFields[CSource], LIdx) then
      begin
        Continue;
      end;
      LMeta := TOverlayMeta(LMetaMap.Objects[LIdx]);
      if Trim(LMeta.AbstractText) = '' then
      begin
        Continue;
      end;
      LRef := MetaReference(LMeta);
      if LRef = '' then
      begin
        Continue;
      end;

      Inc(LTotalEligible);
      LRes := ScreenHomographText(LIng, LMeta.Title + ' ' + LMeta.Journal + ' ' + LMeta.AbstractText);
      if LRes.Verdict = hvPureCollision then
      begin
        Inc(LCollision);
        LRationale := StringReplace(LRes.CollisionSummary, 'Complete archived full text',
          'Indexed title, journal and abstract', []);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'abstract_collision'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          LRationale + #9 + LRef);
      end
      else if LRes.Verdict = hvFoodMention then
      begin
        Inc(LFoodKept);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'food_term_lead'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          LRes.FoodTrigger + #9 + LRef);
      end
      else if LRes.Verdict = hvZeroOccurrences then
      begin
        Inc(LZeroKept);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'zero_in_abstract'#9 +
          '0'#9'0'#9'Zero occurrences in abstract (likely body/reference match)'#9 + LRef);
      end
      else
      begin
        Inc(LAmbiguousKept);
        LReport.Add(LFields[CId] + #9 + LFields[CSource] + #9 + LIng + #9'ambiguous'#9 +
          IntToStr(LRes.TotalHits) + #9 + IntToStr(LRes.CollisionHits) + #9 +
          StringReplace(LRes.UnexplainedSample, #9, ' ', [rfReplaceAll]) + #9 + LRef);
      end;
    end;

    LReport.LineBreak := CLf;
    LReport.WriteBOM := False;
    LReport.SaveToFile(AOutputReportPath, TEncoding.UTF8);

    WriteLn('ABSTRACT_TRIAGE eligible=', LTotalEligible, ' abstract_collision=', LCollision,
      ' food_term_lead=', LFoodKept, ' zero_in_abstract=', LZeroKept,
      ' ambiguous=', LAmbiguousKept);
  finally
    LReport.Free;
    CloseFile(LFile);
    LMetaMap.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if (ParamCount = 3) and (ParamStr(1) = 'benchmark') then
    begin
      RunBenchmark(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 5) and (ParamStr(1) = 'screen') then
    begin
      RunScreen(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'benchmark-abstract') then
    begin
      RunAbstractBenchmark(ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'triage-abstract') then
    begin
      RunAbstractTriage(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else
    begin
      raise EConvertError.Create(
        'Usage: foodexperiment.homographscreen benchmark <repo> <all-overlay-pairs.tsv>' +
        LineEnding +
        '   or: foodexperiment.homographscreen screen <repo> <context-queue.tsv> ' +
        '<out-proposals.tsv> <out-report.tsv>' +
        LineEnding +
        '   or: foodexperiment.homographscreen benchmark-abstract <overlay.tsv> <all-overlay-pairs.tsv>' +
        LineEnding +
        '   or: foodexperiment.homographscreen triage-abstract <overlay.tsv> <context-queue.tsv> ' +
        '<out-report.tsv>');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
