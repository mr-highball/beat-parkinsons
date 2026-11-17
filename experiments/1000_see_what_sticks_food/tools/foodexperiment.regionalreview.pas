{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.regionalreview;

{$mode delphi}
{$H+}

interface

procedure AuditRegionalContext(const AIndex, APriority, ASpanish, APortuguese, AFrenchRussian,
  AOutput: String);
procedure AuditRegionalPairs(const ALexical, AReviews: String);

implementation

uses
  Classes, SysUtils, foodexperiment.externaldata, foodexperiment.matching;

const
  Tab = #9;
  IndexHeader = 'work_id'#9'language'#9'title'#9'indexed_abstract';
  PriorityHeader = 'work_id'#9'review_state'#9'assessment'#9'local_reference';
  ContextHeader = 'work_id'#9'stage'#9'reason'#9'primary_url';
  LanguageContextHeader = 'work_id'#9'language'#9'indexed_abstract'#9'stage'#9'reason'#9'primary_url';
  LexicalHeader = 'docid'#9'work_id'#9'language'#9'title'#9'has_abstract'#9'ingredients'#9 +
    'symptoms'#9'title_ingredients'#9'title_symptoms'#9'joint_claim_ids';
  PairReviewHeader = 'work_id'#9'claim_ids'#9'disposition'#9'assessment';

type
  TRegionalWork = record
    Language: String;
    AbstractState: String;
    Coverage: String;
    Stage: String;
  end;

  TRegionalWorks = array of TRegionalWork;
  TReviewLane = (rlPriority, rlSpanish, rlPortuguese, rlFrenchRussian);

function IsWorkId(const AValue: String): Boolean;
const
  CPrefix = 'https://openalex.org/W';
var
  LPosition: Integer;
begin
  Result := False;
  if (Copy(AValue, 1, Length(CPrefix)) <> CPrefix) or
    (Length(AValue) <= Length(CPrefix)) then
  begin
    Exit;
  end;
  for LPosition := Length(CPrefix) + 1 to Length(AValue) do
  begin
    if not (AValue[LPosition] in ['0'..'9']) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

procedure LoadWorks(const APath: String; AKeys: TStringList; out AWorks: TRegionalWorks);
var
  LRows: TStringList;
  LFields: TFields;
  LRow: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count < 2) or (LRows[0] <> IndexHeader) then
    begin
      raise EConvertError.Create('Missing OpenAlex index or unexpected header');
    end;
    SetLength(AWorks, LRows.Count - 1);
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 4) or not IsWorkId(LFields[0]) or
        (LFields[1] = '') or (LFields[2] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid OpenAlex index row %d', [LRow + 1]);
      end;
      if AKeys.IndexOf(LFields[0]) >= 0 then
      begin
        raise EConvertError.Create('Duplicate OpenAlex work: ' + LFields[0]);
      end;
      AKeys.Add(LFields[0]);
      AWorks[LRow - 1].Language := LFields[1];
      AWorks[LRow - 1].AbstractState := 'missing';
      if LFields[3] <> '' then
      begin
        AWorks[LRow - 1].AbstractState := 'present';
      end;
    end;
  finally
    LRows.Free;
  end;
end;

function LaneMatches(const AWork: TRegionalWork; const AFields: TFields;
  ALane: TReviewLane): Boolean;
begin
  case ALane of
    rlPriority: Result := True;
    rlSpanish: Result := AWork.Language = 'es';
    rlPortuguese: Result := AWork.Language = 'pt';
    rlFrenchRussian: Result := ((AWork.Language = 'fr') or (AWork.Language = 'ru')) and
      (AFields[1] = AWork.Language) and (AFields[2] = AWork.AbstractState);
  end;
end;

procedure LoadReviews(const APath: String; ALane: TReviewLane; AKeys: TStringList;
  var AWorks: TRegionalWorks; var ARelatedCount: Integer);
var
  LRows: TStringList;
  LRelatedKeys: TStringList;
  LHeader: String;
  LFields: TFields;
  LStageIndex: Integer;
  LRow: Integer;
  LWork: Integer;
  LReference: String;
  LAnchor: Integer;
begin
  if APath = '-' then
  begin
    Exit;
  end;
  LHeader := ContextHeader;
  LStageIndex := 1;
  case ALane of
    rlPriority: LHeader := PriorityHeader;
    rlFrenchRussian:
      begin
        LHeader := LanguageContextHeader;
        LStageIndex := 3;
      end;
  end;
  LRows := TStringList.Create;
  LRelatedKeys := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count = 0) or (LRows[0] <> LHeader) then
    begin
      raise EConvertError.Create('Missing review table or unexpected header: ' + APath);
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> LStageIndex + 3) or not IsWorkId(LFields[0]) or
        (Trim(LFields[LStageIndex]) = '') or (Trim(LFields[LStageIndex + 1]) = '') then
      begin
        raise EConvertError.CreateFmt('Invalid review row %d in %s', [LRow + 1, APath]);
      end;
      if ALane = rlPriority then
      begin
        LReference := LFields[3];
        LAnchor := Pos('#', LReference);
        if LAnchor > 0 then
        begin
          SetLength(LReference, LAnchor - 1);
        end;
        if not FileExists(LReference) then
        begin
          raise EConvertError.Create('Missing priority review source: ' + LReference);
        end;
      end;
      LWork := AKeys.IndexOf(LFields[0]);
      if (ALane = rlPriority) and (LWork < 0) then
      begin
        if LRelatedKeys.IndexOf(LFields[0]) >= 0 then
        begin
          raise EConvertError.Create('Duplicate related work review: ' + LFields[0]);
        end;
        LRelatedKeys.Add(LFields[0]);
        Inc(ARelatedCount);
        Continue;
      end;
      if (LWork < 0) or not LaneMatches(AWorks[LWork], LFields, ALane) or
        (AWorks[LWork].Coverage <> '') then
      begin
        raise EConvertError.Create('Unexpected or duplicate work review: ' + LFields[0]);
      end;
      AWorks[LWork].Stage := LFields[LStageIndex];
      AWorks[LWork].Coverage := 'context';
      if ALane = rlPriority then
      begin
        AWorks[LWork].Coverage := 'priority';
      end;
    end;
  finally
    LRelatedKeys.Free;
    LRows.Free;
  end;
end;

procedure WriteCoverage(const APath: String; AKeys: TStringList; const AWorks: TRegionalWorks;
  ARelatedCount: Integer);
var
  LOutput: Text;
  LIndex: Integer;
  LPriority: Integer;
  LContext: Integer;
  LPending: Integer;
  LCoverage: String;
begin
  AssignFile(LOutput, APath);
  Rewrite(LOutput);
  try
    SetTextCodePage(LOutput, CP_UTF8);
    Write(LOutput, 'work_id'#9'language'#9'indexed_abstract'#9'coverage'#9'stage', #10);
    LPriority := 0;
    LContext := 0;
    LPending := 0;
    for LIndex := 0 to High(AWorks) do
    begin
      LCoverage := AWorks[LIndex].Coverage;
      if LCoverage = 'priority' then
      begin
        Inc(LPriority);
      end
      else if LCoverage = 'context' then
      begin
        Inc(LContext);
      end
      else
      begin
        LCoverage := 'pending';
        Inc(LPending);
      end;
      Write(LOutput, AKeys[LIndex], Tab, AWorks[LIndex].Language, Tab,
        AWorks[LIndex].AbstractState, Tab, LCoverage, Tab, AWorks[LIndex].Stage, #10);
    end;
  finally
    CloseFile(LOutput);
  end;
  WriteLn(AKeys.Count, ' indexed works, ', LPriority, ' priority reviews, ', LContext,
    ' context reviews, ', LPending, ' pending, ', ARelatedCount, ' citation-derived reviews');
  if LPending <> 0 then
  begin
    ExitCode := 2;
  end;
end;

procedure AuditRegionalContext(const AIndex, APriority, ASpanish, APortuguese, AFrenchRussian,
  AOutput: String);
var
  LKeys: TStringList;
  LWorks: TRegionalWorks;
  LRelatedCount: Integer;
begin
  if FileExists(AOutput) then
  begin
    raise EInOutError.Create('Use a new regional coverage output path');
  end;
  LKeys := TStringList.Create;
  try
    LKeys.CaseSensitive := True;
    LoadWorks(AIndex, LKeys, LWorks);
    LRelatedCount := 0;
    LoadReviews(APriority, rlPriority, LKeys, LWorks, LRelatedCount);
    LoadReviews(ASpanish, rlSpanish, LKeys, LWorks, LRelatedCount);
    LoadReviews(APortuguese, rlPortuguese, LKeys, LWorks, LRelatedCount);
    LoadReviews(AFrenchRussian, rlFrenchRussian, LKeys, LWorks, LRelatedCount);
    WriteCoverage(AOutput, LKeys, LWorks, LRelatedCount);
  finally
    LKeys.Free;
  end;
end;

procedure AuditRegionalPairs(const ALexical, AReviews: String);
var
  LRows: TStringList;
  LWorkIds: TStringList;
  LPending: TStringList;
  LFields: TFields;
  LRow: Integer;
  LIndex: Integer;
  LReviewed: Integer;
begin
  LRows := TStringList.Create;
  LWorkIds := TStringList.Create;
  LPending := TStringList.Create;
  try
    LWorkIds.Sorted := True;
    LWorkIds.CaseSensitive := True;
    LWorkIds.Duplicates := dupError;
    LPending.Sorted := True;
    LPending.CaseSensitive := True;
    LPending.Duplicates := dupError;
    LRows.Text := ReadBytes(ALexical);
    if (LRows.Count < 2) or (LRows[0] <> LexicalHeader) then
    begin
      raise EConvertError.Create('Missing OpenAlex lexical screen or unexpected header');
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 10) or not IsWorkId(LFields[0]) or
        (LFields[0] <> LFields[1]) then
      begin
        raise EConvertError.CreateFmt('Invalid lexical screen row %d', [LRow + 1]);
      end;
      LWorkIds.Add(LFields[0]);
      if LFields[9] <> '' then
      begin
        LPending.Add(LFields[1] + Tab + LFields[9]);
      end;
    end;
    LReviewed := 0;
    if AReviews <> '-' then
    begin
      LRows.Text := ReadBytes(AReviews);
      if (LRows.Count = 0) or (LRows[0] <> PairReviewHeader) then
      begin
        raise EConvertError.Create('Missing pair reviews or unexpected header');
      end;
      for LRow := 1 to LRows.Count - 1 do
      begin
        LFields := SplitFields(LRows[LRow], Tab);
        if (Length(LFields) <> 4) or (Trim(LFields[2]) = '') or (Trim(LFields[3]) = '') then
        begin
          raise EConvertError.CreateFmt('Invalid pair review row %d', [LRow + 1]);
        end;
        LIndex := LPending.IndexOf(LFields[0] + Tab + LFields[1]);
        if LIndex < 0 then
        begin
          raise EConvertError.Create('Unexpected or duplicate pair review: ' + LFields[0]);
        end;
        LPending.Delete(LIndex);
        Inc(LReviewed);
      end;
    end;
    WriteLn(LReviewed, ' works with joint matches reviewed, ', LPending.Count, ' pending');
    for LRow := 0 to LPending.Count - 1 do
    begin
      WriteLn(LPending[LRow]);
    end;
    if LPending.Count <> 0 then
    begin
      ExitCode := 2;
    end;
  finally
    LPending.Free;
    LWorkIds.Free;
    LRows.Free;
  end;
end;

end.
