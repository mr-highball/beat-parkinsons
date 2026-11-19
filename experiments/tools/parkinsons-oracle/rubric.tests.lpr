
{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program RubricTests;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, parkinsonsoracle.rubric;

const
  CDecisions = 'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale'#10;
  CSources = 'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9'claim_effect'#9 +
    'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9'reliability_fit'#9 +
    'independence'#9'n'#9'unit'#9'local_reference'#9'rationale'#10;
  CConversation = '0281'#9'forum-1'#9'conversation'#9'patient'#9'original'#9'eases'#9'eases'#9 +
    'direct'#9'partial'#9'direct'#9'partial'#9'partial'#9'confirmed'#9'1'#9'account'#9 +
    'research/example.txt'#9'Firsthand report with repeated observed response.'#10;
  CUncertain = '0281'#9'forum-2'#9'conversation'#9'caregiver'#9'original'#9'worsens'#9'worsens'#9 +
    'direct'#9'partial'#9'direct'#9'partial'#9'partial'#9'uncertain'#9#9'accounts'#9 +
    'research/other.txt'#9'Overlap with another published report is unresolved.'#10;

procedure Check(ACondition: Boolean; const ALabel: String);
begin
  if not ACondition then
    raise Exception.Create(ALabel);
end;

function Decision(const ATier, AEffect: String): String;
begin
  Result := CDecisions + '0281'#9 + EvidenceRubricVersion + #9 + ATier + #9 + AEffect +
    #9'Tested evidence decision.'#10;
end;

procedure CheckRejected(const ADecisions, ASources, ALabel: String);
var
  LResult: TJSONObject;
  LRejected: Boolean;
begin
  LRejected := False;
  LResult := TJSONObject.Create;
  try
    try
      AddEvidenceScorecard(LResult, ADecisions, ASources, '0281', 'worsens',
        'Maybe False', 50.005);
    except
      on EConvertError do
        LRejected := True;
      on EStringListError do
        LRejected := True;
    end;
    Check(LRejected, ALabel);
  finally
    LResult.Free;
  end;
end;

procedure Run;
var
  LResult: TJSONObject;
  LDecisions: String;
begin
  LDecisions := Decision('minimal_signal', 'eases');
  LResult := TJSONObject.Create;
  try
    AddEvidenceScorecard(LResult, LDecisions, CSources + CConversation + CUncertain,
      '0281', 'worsens', 'Maybe False', 50.005);
    Check(LResult.Strings['review_status'] = 'recorded', 'Expected a recorded minimal signal.');
    Check(LResult.Objects['scorecard'].Strings['expected_verdict'] = 'Maybe False',
      'Easing a worsening hypothesis must yield Maybe False.');
    Check(LResult.Objects['family_counts'].Integers['eases'] = 1,
      'Expected one independent easing source.');
    Check(LResult.Objects['family_counts'].Integers['worsens'] = 0,
      'Uncertain independence must not count as independent worsening.');
    Check(LResult.Objects['family_counts'].Integers['uncertain'] = 1,
      'Keep the unresolved source separate.');
    Check(LResult.Objects['family_counts_by_kind'].Objects['conversation'].Integers['eases'] = 1,
      'A firsthand conversation can inform the minimal tier.');
    LResult.Clear;
    AddEvidenceScorecard(LResult, LDecisions, CSources + CConversation,
      '0281', 'worsens', 'Maybe False', 51);
    Check(LResult.Strings['review_status'] = 'verdict_mismatch', 'Expected a stale verdict score.');
    LResult.Clear;
    AddEvidenceScorecard(LResult, LDecisions, CSources + CConversation,
      '0100', 'worsens', 'Unknown', 50);
    Check(LResult.Strings['review_status'] = 'no_scorecard', 'Expected a legacy claim lookup.');
  finally
    LResult.Free;
  end;
  CheckRejected(LDecisions, CSources + CConversation + CConversation,
    'The same family cannot contribute twice.');
  CheckRejected(Decision('limited_clinical_link', 'eases'), CSources + CConversation,
    'The limited clinical tier needs a clinical comparison.');
  CheckRejected(LDecisions, CSources + StringReplace(CConversation, #9'eases'#9'eases'#9,
    #9'null'#9'eases'#9, []), 'A null source cannot provide a signed effect.');
end;

begin
  Run;
  WriteLn('Evidence rubric tests passed.');
end.
