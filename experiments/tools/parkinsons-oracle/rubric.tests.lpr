
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

procedure CheckRejected(const ADecisions, ASources, ALabel: String; ADraft: Boolean = False);
var
  LResult: TJSONObject;
  LRejected: Boolean;
begin
  LRejected := False;
  LResult := TJSONObject.Create;
  try
    try
      AddEvidenceScorecard(LResult, ADecisions, ASources, '0281', 'worsens',
        'Maybe False', 50.005, ADraft);
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

function LedgerHeader(AFields: TJSONArray): String;
var
  LIndex: Integer;
begin
  Result := AFields.Strings[0];
  for LIndex := 1 to AFields.Count - 1 do
  begin
    Result := Result + #9 + AFields.Strings[LIndex];
  end;
  Result := Result + #10;
end;

procedure Run;
var
  LResult: TJSONObject;
  LDecisions: String;
  LContext: String;
begin
  LDecisions := Decision('minimal_signal', 'eases');
  LContext := StringReplace(CConversation, #9'conversation'#9, #9'customary_use'#9, []);
  LResult := TJSONObject.Create;
  try
    AddEvidenceRubricSchema(LResult);
    Check(LResult.Arrays['tiers'].Count = 5, 'Expected five published tiers.');
    Check(LResult.Arrays['tiers'].Objects[1].Strings['tier'] = 'minimal_signal',
      'The schema must identify the minimal signal.');
    Check(LedgerHeader(LResult.Arrays['decision_fields']) = CDecisions,
      'The decision field order must match the accepted TSV header.');
    Check(LedgerHeader(LResult.Arrays['source_fields']) = CSources,
      'The source field order must match the accepted TSV header.');
    Check(LResult.Arrays['fit_fields'].Count = 5, 'Expected five separate fits.');
    Check(LResult.Arrays['tiers'].Objects[1].Strings['score_anchor'] = '50.005',
      'The schema must preserve the exact anchor.');
    Check(LResult.Arrays['tiers'].Objects[4].Strings['minimum_source_tier'] =
      'direct_clinical_signal', 'Strong evidence needs at least a direct clinical source.');
    Check(LResult.Objects['field_values'].Arrays['independence'].Strings[1] = 'uncertain',
      'The schema must show how to record uncertain independence.');
    Check(LResult.Arrays['context_only_source_kinds'].Count = 7,
      'The schema must expose context-only source kinds.');
    LResult.Clear;
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
    LResult.Clear;
    AddEvidenceScorecard(LResult, LDecisions, CSources + CConversation,
      '0281', 'worsens', 'Unknown', 50, True);
    Check(LResult.Strings['review_status'] = 'valid_draft', 'Expected a valid draft.');
    Check(LResult.Objects['scorecard'].Strings['expected_verdict'] = 'Maybe False',
      'The draft verdict must come from the frozen direction.');
    Check(LResult.Objects['scorecard'].Strings['score_anchor'] = '50.005',
      'The draft must return the exact tier anchor.');
    LResult.Clear;
    AddEvidenceScorecard(LResult, Decision('open', 'none'), CSources,
      '0281', 'worsens', 'Unknown', 50, True);
    Check(LResult.Strings['review_status'] = 'valid_draft',
      'An open draft may have no material sources.');
    LResult.Clear;
    AddEvidenceScorecard(LResult, Decision('open', 'none'), CSources +
      StringReplace(LContext, #9'eases'#9'eases'#9, #9'unreported'#9'none'#9, []),
      '0281', 'worsens', 'Unknown', 50, True);
    Check(LResult.Objects['family_counts'].Integers['context'] = 1,
      'Keep recorded customary use visible as context.');
  finally
    LResult.Free;
  end;
  CheckRejected(LDecisions, CSources + CConversation + CConversation,
    'The same family cannot contribute twice.');
  CheckRejected(Decision('limited_clinical_link', 'eases'), CSources + CConversation,
    'The limited clinical tier needs a clinical comparison.');
  CheckRejected(LDecisions, CSources + StringReplace(CConversation, #9'eases'#9'eases'#9,
    #9'null'#9'eases'#9, []), 'A null source cannot provide a signed effect.');
  CheckRejected(LDecisions, CSources + LContext,
    'Customary use without an observed response cannot supply a sign.', True);
  CheckRejected(LDecisions, CSources + StringReplace(CConversation, #9'conversation'#9,
    #9'professional_opinion'#9, []), 'A professional opinion alone cannot supply a sign.', True);
  CheckRejected(LDecisions, CSources + StringReplace(CConversation, #9'conversation'#9,
    #9'review'#9, []), 'A review points to the underlying evidence family.', True);
  CheckRejected(CDecisions, CSources, 'A draft requires a decision row.', True);
  CheckRejected(LDecisions, CSources + StringReplace(CConversation, '0281', '0100', []),
    'A draft must not silently drop evidence for another claim.', True);
  CheckRejected(StringReplace(LDecisions, #9 + EvidenceRubricVersion + #9, #9'0'#9, []),
    CSources + CConversation, 'A historical version must not pass draft validation.', True);
  CheckRejected(Decision('limited_clinical_link', 'eases'), CSources + CConversation,
    'Drafts use the published tier prerequisites.', True);
end;

begin
  Run;
  WriteLn('Evidence rubric tests passed.');
end.
