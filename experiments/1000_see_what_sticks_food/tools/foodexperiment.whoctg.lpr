{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentWhoCtg;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, StrUtils, RegExpr, foodexperiment.externaldata, foodexperiment.matching;

const
  Tab = #9;
  RegistryPrefix = 'https://clinicaltrials.gov/study/';
  ReviewHeader = 'nct_id'#9'exposure_role'#9'assessment'#9'publication_status'#9'research_note';
  CrosswalkHeader = 'nct_id'#9'who_priority'#9'who_parkinson_scope'#9'state'#9 +
    'prior_candidate_rows'#9'prior_disposition_rows'#9'prior_recheck_rows'#9'first_posted'#9 +
    'archive_status'#9'archive_results_posted'#9'exposure_role'#9'assessment'#9'publication_status'#9 +
    'research_note'#9'local_registry_text'#9'primary_registry_url';

function ReadTable(const APath, AFirstHeader: String; AWidth: Integer): TStringList;
var
  LLine: String;
begin
  Result := TStringList.Create;
  try
    Result.Text := ReadBytes(APath);
    if (Result.Count = 0) or (SplitFields(Result[0], Tab)[0] <> AFirstHeader) then
      raise EConvertError.Create('Unexpected table header in ' + APath);
    for LLine in Result do
      if Length(SplitFields(LLine, Tab)) <> AWidth then
        raise EConvertError.Create('Unexpected table width in ' + APath);
    Result.Delete(0);
  except
    Result.Free;
    raise;
  end;
end;

function ReadReviews(const APath: String): TStringList;
var
  LTable: TStringList;
  LLine: String;
  LFields: TFields;
begin
  Result := TStringList.Create;
  try
    if APath = '' then
      Exit;
    LTable := TStringList.Create;
    try
      LTable.Text := ReadBytes(APath);
      if LTable.Count = 0 then
        raise EConvertError.Create('Missing review header in ' + APath);
      if LTable[0] = ReviewHeader then
      begin
        LTable.Delete(0);
        for LLine in LTable do
        begin
          if Length(SplitFields(LLine, Tab)) <> 5 then
            raise EConvertError.Create('Unexpected review width in ' + APath);
          Result.Add(LLine);
        end;
      end
      else if LTable[0] = CrosswalkHeader then
      begin
        LTable.Delete(0);
        for LLine in LTable do
        begin
          LFields := SplitFields(LLine, Tab);
          if Length(LFields) <> 16 then
            raise EConvertError.Create('Unexpected crosswalk width in ' + APath);
          if LFields[3] = 'reviewed' then
            Result.Add(LFields[0] + Tab + LFields[10] + Tab + LFields[11] + Tab +
              LFields[12] + Tab + LFields[13]);
        end;
      end
      else
        raise EConvertError.Create('Unexpected review header in ' + APath);
    finally
      LTable.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CountId(ATable: TStrings; const AId: String): Integer;
var
  LLine: String;
begin
  Result := 0;
  for LLine in ATable do
    if StartsStr(AId + Tab, LLine) then
      Inc(Result);
end;

function RegistryRecord(const AId: String): String;
var
  LFolder: TSearchRec;
  LPath: String;
begin
  Result := '';
  if FindFirst('research/*', faDirectory, LFolder) <> 0 then
    Exit;
  try
    repeat
      if not ExecRegExpr('^[0-9]{4}-[0-9]{4}$', LFolder.Name) then
        Continue;
      LPath := 'research/' + LFolder.Name + '/Source-Text/Trials/' + AId + '.txt';
      if FileExists(LPath) then
      begin
        if Result <> '' then
          raise EConvertError.Create('Duplicate local ClinicalTrials.gov record ' + AId);
        Result := LPath;
      end;
    until FindNext(LFolder) <> 0;
  finally
    FindClose(LFolder);
  end;
end;

function HeaderValue(ALines: TStrings; const ALabel: String): String;
var
  LLine: String;
begin
  for LLine in ALines do
    if StartsStr(ALabel + ': ', LLine) then
      Exit(Copy(LLine, Length(ALabel) + 3, MaxInt));
  Result := '';
end;

procedure Join(const AExperiment, AWhoFile, AOutput, AReviews: String);
var
  LWho, LCandidates, LPrior, LRechecks, LReviews, LSeen, LUsed, LRegistry, LOutput: TStringList;
  LRow, LReview, LId, LPath, LState, LFirst, LStatus, LResults, LRole, LAssessment, LNote,
    LPublication: String;
  LFields, LDecision, LRecheckFields: TFields;
  LCandidateRows, LPriorRows, LRecheckRows, LPriorCount, LReviewedCount, LPendingCount,
    LArchivedCount: Integer;
begin
  LWho := nil;
  LCandidates := nil;
  LPrior := nil;
  LRechecks := nil;
  LReviews := nil;
  LSeen := TStringList.Create;
  LUsed := TStringList.Create;
  LRegistry := TStringList.Create;
  LOutput := TStringList.Create;
  try
    LWho := ReadTable(AWhoFile, 'trial_id', 23);
    LCandidates := ReadTable(AExperiment + '/followup/registry-exposure-candidates.tsv', 'nct_id', 11);
    LPrior := ReadTable(AExperiment + '/followup/registry-dispositions.tsv', 'nct_id', 11);
    LRechecks := ReadTable(AExperiment + '/followup/clinicaltrials-results-recheck.tsv', 'nct_id', 20);
    LReviews := ReadReviews(AReviews);
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LUsed.Sorted := True;
    LUsed.Duplicates := dupError;
    LPriorCount := 0;
    LReviewedCount := 0;
    LPendingCount := 0;
    LArchivedCount := 0;
    LOutput.Add(CrosswalkHeader);
    for LRow in LWho do
    begin
      LFields := SplitFields(LRow, Tab);
      if LFields[1] <> 'ClinicalTrials.gov' then
        Continue;
      LId := LFields[0];
      if not ExecRegExpr('^NCT[0-9]{8}$', LId) then
        raise EConvertError.Create('Invalid ClinicalTrials.gov identifier ' + LId);
      LSeen.Add(LId);
      LCandidateRows := CountId(LCandidates, LId);
      LPriorRows := CountId(LPrior, LId);
      LRecheckRows := CountId(LRechecks, LId);
      LPath := RegistryRecord(LId);
      LFirst := '';
      LStatus := '';
      LResults := '';
      if LPath <> '' then
      begin
        LRegistry.Text := ReadBytes(LPath);
        if HeaderValue(LRegistry, 'NCT ID') <> LId then
          raise EConvertError.Create('Unexpected identifier in ' + LPath);
        LFirst := HeaderValue(LRegistry, 'First posted');
        LStatus := HeaderValue(LRegistry, 'Overall status');
        LResults := HeaderValue(LRegistry, 'Posted summary results');
        Inc(LArchivedCount);
      end;
      LRole := '';
      LAssessment := '';
      LNote := '';
      LPublication := '';
      LState := 'pending';
      if LPriorRows > 0 then
      begin
        LState := 'previously reviewed';
        LAssessment := 'Exact identifier match in registry-dispositions.tsv';
        if LRecheckRows > 0 then
        begin
          LAssessment := LAssessment + ' and clinicaltrials-results-recheck.tsv';
          if LRecheckRows = 1 then
            for LReview in LRechecks do
              if StartsStr(LId + Tab, LReview) then
              begin
                LRecheckFields := SplitFields(LReview, Tab);
                LPublication := LRecheckFields[15];
                LNote := LRecheckFields[17];
                Break;
              end;
        end;
        Inc(LPriorCount);
      end;
      for LReview in LReviews do
        if StartsStr(LId + Tab, LReview) then
        begin
          LUsed.Add(LId);
          LDecision := SplitFields(LReview, Tab);
          LState := 'reviewed';
          LRole := LDecision[1];
          LAssessment := LDecision[2];
          LPublication := LDecision[3];
          LNote := LDecision[4];
          if (LRole = '') or (LAssessment = '') then
            raise EConvertError.Create('Review role or assessment missing for ' + LId);
        end;
      if (LNote <> '') and not FileExists(SplitFields(LNote, '#')[0]) then
        raise EConvertError.Create('Missing research note ' + LNote);
      if LState = 'reviewed' then
      begin
        Inc(LReviewedCount);
        if LPriorRows > 0 then
          Dec(LPriorCount);
      end
      else if LState = 'pending' then
        Inc(LPendingCount);
      LOutput.Add(LId + Tab + LFields[3] + Tab + LFields[4] + Tab + LState + Tab +
        IntToStr(LCandidateRows) + Tab + IntToStr(LPriorRows) + Tab + IntToStr(LRecheckRows) + Tab +
        LFirst + Tab + LStatus + Tab + LResults + Tab + LRole + Tab + LAssessment + Tab +
        LPublication + Tab + LNote + Tab + LPath + Tab + RegistryPrefix + LId);
    end;
    if LUsed.Count <> LReviews.Count then
      raise EConvertError.Create('At least one review is outside the WHO ClinicalTrials.gov set');
    LOutput.SaveToFile(AOutput);
    WriteLn('WHO ClinicalTrials.gov ', LSeen.Count, ', local records ', LArchivedCount,
      ', previously reviewed ', LPriorCount, ', newly reviewed ', LReviewedCount, ', pending ', LPendingCount);
  finally
    LOutput.Free;
    LRegistry.Free;
    LUsed.Free;
    LSeen.Free;
    LReviews.Free;
    LRechecks.Free;
    LPrior.Free;
    LCandidates.Free;
    LWho.Free;
  end;
end;

begin
  if not (ParamCount in [3, 4]) then
    raise EArgumentException.Create('Usage: foodexperiment.whoctg EXPERIMENT WHO_CANDIDATES OUTPUT [REVIEWS_OR_CROSSWALK]');
  Join(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
end.
