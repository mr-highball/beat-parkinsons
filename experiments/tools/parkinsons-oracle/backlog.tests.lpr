{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program BacklogTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, fpjson, parkinsonsoracle.claims, parkinsonsoracle.trend;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run(const ARepoRoot: String);
var
  LIndex: TClaimIndex;
  LStatus: TJSONObject;
  LBacklog: TJSONObject;
  LQuery: TClaimQuery;
  LFull: TJSONObject;
  LCompact: TJSONObject;
  LUnscored: TJSONObject;
  LRecorded: TJSONObject;
  LClaimFull: TJSONObject;
  LClaimCompact: TJSONObject;
  LRejected: Boolean;
  LDirectional: Integer;
  LWithCard: Integer;
  LWithoutCard: Integer;
  LTremor: TJSONObject;
  LOptions: TJSONArray;
  LRow: TJSONObject;
  LIdx: Integer;
  LRank: Integer;
  LPrevRank: Integer;
  LHasEases: Boolean;
  LHasUnknown: Boolean;
begin
  LIndex := TClaimIndex.Create(ARepoRoot);
  try
    LStatus := LIndex.Status;
    try
      LDirectional := LStatus.Integers['directional_verdicts'];
      LWithCard := LStatus.Integers['directional_with_scorecard'];
      LWithoutCard := LStatus.Integers['directional_without_scorecard'];
      Check(LWithCard + LWithoutCard = LDirectional,
        'Directional scorecard counts must partition directional_verdicts.');
      Check(LStatus.Integers['v1_scorecards'] >= LWithCard,
        'v1_scorecards must be at least directional_with_scorecard.');
      Check(LStatus.Integers['scorecard_mismatches'] >= 0,
        'scorecard_mismatches must be nonnegative.');
    finally
      LStatus.Free;
    end;

    LBacklog := LIndex.Backlog;
    try
      Check(LBacklog.Arrays['rounds'].Count = CRoundCount,
        'Backlog must report all frozen rounds.');
      Check(LBacklog.Arrays['directional_without_v1_scorecard'].Count = LWithoutCard,
        'Backlog legacy directional count must match status.');
      Check(LBacklog.Arrays['scorecard_mismatches'].Count =
        LBacklog.Objects['summary'].Integers['scorecard_mismatches'],
        'Backlog mismatch array must match status.');
    finally
      LBacklog.Free;
    end;

    LQuery := Default(TClaimQuery);
    LQuery.Ingredient := 'fig';
    LQuery.Symptom := 'drooling';
    LQuery.Scope := 'assessed';
    LQuery.Limit := 5;
    LFull := LIndex.Query(LQuery);
    LQuery.OmitCulture := True;
    LCompact := LIndex.Query(LQuery);
    try
      Check(LFull.Find('culture_sources') <> nil,
        'Default query must retain culture_sources.');
      Check(LCompact.Find('culture_sources') = nil,
        'OmitCulture query must omit culture_sources.');
      Check(LFull.Integers['total_matches'] = LCompact.Integers['total_matches'],
        'OmitCulture must preserve total_matches.');
      Check(LFull.Arrays['options'].AsJSON = LCompact.Arrays['options'].AsJSON,
        'OmitCulture must preserve options and order.');
      Check(Length(LCompact.AsJSON) < Length(LFull.AsJSON),
        'OmitCulture must reduce payload size for a culturally matched pair.');
    finally
      LCompact.Free;
      LFull.Free;
    end;

    LQuery := Default(TClaimQuery);
    LQuery.Scope := 'directional';
    LQuery.OmitCulture := True;
    LQuery.Limit := 100;
    LQuery.ScorecardStatus := 'no_scorecard';
    LUnscored := LIndex.Query(LQuery);
    LQuery.ScorecardStatus := 'recorded';
    LRecorded := LIndex.Query(LQuery);
    try
      Check(LUnscored.Strings['scorecard_status_filter'] = 'no_scorecard',
        'Query must echo scorecard_status_filter.');
      Check(LUnscored.Integers['total_matches'] + LRecorded.Integers['total_matches'] <=
        LDirectional,
        'Scorecard partitions cannot exceed directional_verdicts.');
      Check(LRecorded.Integers['total_matches'] = LWithCard,
        'Recorded directional query must match directional_with_scorecard.');
    finally
      LRecorded.Free;
      LUnscored.Free;
    end;

    LClaimFull := LIndex.Claim(1, '0188', 0, 8, '', True);
    LClaimCompact := LIndex.Claim(1, '0188', 0, 8, '', False);
    try
      Check(LClaimFull.Find('culture_sources') <> nil,
        'Default claim lookup must retain culture_sources.');
      Check(LClaimCompact.Find('culture_sources') = nil,
        'Compact claim lookup must omit culture_sources.');
      Check(LClaimCompact.Strings['scorecard_status'] = 'recorded',
        'Claim lookup must expose scorecard_status.');
      Check(LClaimFull.Arrays['assessments'].AsJSON =
        LClaimCompact.Arrays['assessments'].AsJSON,
        'Compact claim lookup must preserve assessments.');
    finally
      LClaimCompact.Free;
      LClaimFull.Free;
    end;

    LRejected := False;
    LQuery := Default(TClaimQuery);
    LQuery.Scope := 'directional';
    LQuery.Limit := 10;
    LQuery.ScorecardStatus := 'invalid_status';
    try
      LFull := LIndex.Query(LQuery);
      LFull.Free;
    except
      on EConvertError do
      begin
        LRejected := True;
      end;
    end;
    Check(LRejected, 'Invalid scorecard_status filter must be rejected.');

    LQuery := Default(TClaimQuery);
    LQuery.Symptom := 'rest tremor severity';
    LQuery.Scope := 'frozen';
    LQuery.OmitCulture := True;
    LQuery.Limit := 100;
    LTremor := LIndex.Query(LQuery);
    try
      LOptions := LTremor.Arrays['options'];
      Check(LOptions.Count > 0, 'Tremor query must return claims.');
      LPrevRank := -1;
      LHasEases := False;
      LHasUnknown := False;
      for LIdx := 0 to LOptions.Count - 1 do
      begin
        LRow := LOptions.Objects[LIdx];
        LRank := ClaimUsefulnessRank(LRow.Strings['verdict'],
          LRow.Strings['hypothesis_direction'], LRow.Strings['research_status']);
        Check(LRank >= LPrevRank,
          'Claim query results must be ordered descending by usefulness.');
        if LRank in [0, 1] then
          LHasEases := True;
        if LRank in [5, 6] then
          LHasUnknown := True;
        LPrevRank := LRank;
      end;
      Check(LHasEases and LHasUnknown,
        'Tremor frozen query should span directional easing and unknown tiers.');
      LRow := LOptions.Objects[0];
      Check(ClaimUsefulnessRank(LRow.Strings['verdict'],
        LRow.Strings['hypothesis_direction'], LRow.Strings['research_status']) in [0, 1],
        'First tremor result under frozen scope must lean toward easing.');
    finally
      LTremor.Free;
    end;
  finally
    LIndex.Free;
  end;
  WriteLn('BacklogTests passed.');
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if ParamCount <> 1 then
    begin
      raise EConvertError.Create('Pass the beat-parkinsons repository root.');
    end;
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
