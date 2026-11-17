{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentArchiveAudit;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Generics.Collections, foodexperiment.externaldata;

const
  ClaimCount = 1000;
  CandidateHeader = 'id'#9'category'#9'ingredient'#9'symptom'#9'pmcid'#9'local_reference'#9 +
    'title'#9'text_scope'#9'title_subject_triage'#9'body_ingredient'#9'body_related'#9 +
    'title_ingredient'#9'title_related';
  DispositionHeader = 'pmcid'#9'claim_ids'#9'disposition'#9'assessment'#9'local_reference';

type
  TClaim = record
    Category: UTF8String;
    Candidates: Integer;
    Reviewed: Integer;
  end;

  TCandidate = record
    Claim: Integer;
    Reviewed: Boolean;
  end;

  TPairIndex = TDictionary<UTF8String, Integer>;
  TClaims = array[1..ClaimCount] of TClaim;

function ClaimIndex(const AId: UTF8String): Integer;
begin
  if not TryStrToInt(AId, Result) or (Result < 1) or (Result > ClaimCount) or
    (AId <> Format('%.4d', [Result])) then
  begin
    raise EConvertError.Create('Invalid frozen claim ID: ' + AId);
  end;
end;

procedure LoadClaims(const APath: String; out AClaims: TClaims);
var
  LRows: TStringList;
  LFields: TFields;
  I: Integer;
begin
  AClaims := Default(TClaims);
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(APath);
    if LRows.Count <> ClaimCount + 1 then
    begin
      raise EConvertError.Create('Frozen claim row count mismatch');
    end;
    for I := 1 to ClaimCount do
    begin
      LFields := SplitFields(LRows[I], #9);
      if (Length(LFields) < 2) or (ClaimIndex(LFields[0]) <> I) or
        (LFields[1] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid frozen claim row %d', [I]);
      end;
      AClaims[I].Category := LFields[1];
    end;
  finally
    LRows.Free;
  end;
end;

procedure LoadCandidates(ARows: TStringList; APairs: TPairIndex; var AClaims: TClaims;
  out ACandidates: TArray<TCandidate>);
var
  LFields: TFields;
  LClaim, I: Integer;
  LKey: UTF8String;
begin
  if (ARows.Count < 1) or (ARows[0] <> CandidateHeader) then
  begin
    raise EConvertError.Create('Missing archive candidate header');
  end;
  SetLength(ACandidates, ARows.Count);
  for I := 1 to ARows.Count - 1 do
  begin
    LFields := SplitFields(ARows[I], #9);
    if (Length(LFields) <> 13) or (Copy(LFields[4], 1, 3) <> 'PMC') then
    begin
      raise EConvertError.CreateFmt('Invalid archive candidate row %d', [I + 1]);
    end;
    LClaim := ClaimIndex(LFields[0]);
    if LFields[1] <> AClaims[LClaim].Category then
    begin
      raise EConvertError.CreateFmt('Candidate category mismatch for claim %s', [LFields[0]]);
    end;
    LKey := LFields[4] + '/' + LFields[0];
    if APairs.ContainsKey(LKey) then
    begin
      raise EConvertError.Create('Duplicate archive candidate: ' + LKey);
    end;
    APairs.Add(LKey, I);
    ACandidates[I].Claim := LClaim;
    Inc(AClaims[LClaim].Candidates);
  end;
end;

procedure ReadDispositions(const APath, ARepo: String; APairs: TPairIndex;
  var AClaims: TClaims; var ACandidates: TArray<TCandidate>);
var
  LRows: TStringList;
  LFields, LIds: TFields;
  LId, LKey, LReference: UTF8String;
  LAnchor, LIndex, I: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(APath);
    if (LRows.Count < 1) or (LRows[0] <> DispositionHeader) then
    begin
      raise EConvertError.Create('Invalid archive disposition header: ' + APath);
    end;
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], #9);
      if (Length(LFields) <> 5) or (LFields[2] = '') or (LFields[3] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid archive disposition in %s row %d', [APath, I + 1]);
      end;
      LReference := LFields[4];
      LAnchor := Pos('#', LReference);
      if LAnchor > 0 then
      begin
        SetLength(LReference, LAnchor - 1);
      end;
      if (Copy(LReference, 1, 9) <> 'research/') or
        not FileExists(ARepo + LReference) then
      begin
        raise EInOutError.Create('Missing disposition reference: ' + LFields[4]);
      end;
      LIds := SplitFields(LFields[1], '|');
      for LId in LIds do
      begin
        LKey := LFields[0] + '/' + LId;
        if not APairs.TryGetValue(LKey, LIndex) then
        begin
          raise EConvertError.Create('Disposition absent from archive inventory: ' + LKey);
        end;
        if ACandidates[LIndex].Reviewed then
        begin
          raise EConvertError.Create('Duplicate archive disposition: ' + LKey);
        end;
        ACandidates[LIndex].Reviewed := True;
        Inc(AClaims[ACandidates[LIndex].Claim].Reviewed);
      end;
    end;
  finally
    LRows.Free;
  end;
end;

procedure Run(const AExperiment: String; APending: Boolean);
var
  LExperiment, LFollowup, LRepo: String;
  LFiles: TSearchRec;
  LRows: TStringList;
  LIndex: TPairIndex;
  LClaims: TClaims;
  LCandidates: TArray<TCandidate>;
  LReviewed, I: Integer;
begin
  LExperiment := ExcludeTrailingPathDelimiter(ExpandFileName(AExperiment));
  LRepo := IncludeTrailingPathDelimiter(ExtractFileDir(ExtractFileDir(LExperiment)));
  LFollowup := LExperiment + PathDelim + 'followup' + PathDelim;
  LoadClaims(LExperiment + PathDelim + 'freeze.tsv', LClaims);
  LRows := TStringList.Create;
  LIndex := TPairIndex.Create;
  try
    LRows.LoadFromFile(LFollowup + 'archive-body-outside-query.tsv');
    LoadCandidates(LRows, LIndex, LClaims, LCandidates);
    if FindFirst(LFollowup + 'archive-body-*-dispositions.tsv', faAnyFile, LFiles) <> 0 then
    begin
      raise EInOutError.Create('No archive disposition tables found');
    end;
    try
      repeat
        ReadDispositions(LFollowup + LFiles.Name, LRepo, LIndex, LClaims, LCandidates);
      until FindNext(LFiles) <> 0;
    finally
      FindClose(LFiles);
    end;
    LReviewed := 0;
    if APending then
    begin
      WriteLn(LRows[0]);
      for I := 1 to LRows.Count - 1 do
      begin
        if not LCandidates[I].Reviewed then
        begin
          WriteLn(LRows[I]);
        end;
      end;
    end
    else
    begin
      WriteLn('id'#9'category'#9'archive_candidates'#9'context_reviewed'#9'context_pending');
      for I := 1 to ClaimCount do
      begin
        WriteLn(Format('%.4d'#9'%s'#9'%d'#9'%d'#9'%d',
          [I, LClaims[I].Category, LClaims[I].Candidates, LClaims[I].Reviewed,
           LClaims[I].Candidates - LClaims[I].Reviewed]));
      end;
    end;
    for I := 1 to ClaimCount do
    begin
      Inc(LReviewed, LClaims[I].Reviewed);
    end;
    WriteLn(StdErr, LReviewed, ' reviewed, ', LIndex.Count - LReviewed, ' pending of ',
      LIndex.Count, ' archive pairs');
  finally
    LIndex.Free;
    LRows.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if not (ParamCount in [1, 2]) or ((ParamCount = 2) and (ParamStr(2) <> '--pending')) then
    begin
      raise EArgumentException.Create('Usage: foodexperiment.archiveaudit EXPERIMENT [--pending]');
    end;
    Run(ParamStr(1), ParamCount = 2);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
