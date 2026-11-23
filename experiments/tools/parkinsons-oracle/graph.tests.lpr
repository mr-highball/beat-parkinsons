{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program GraphTests;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, parkinsonsoracle.graph;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

begin
  Check(GraphClaimLabel('Maybe True', 'reduces') = 'May ease', 'Supported relief direction.');
  Check(GraphClaimLabel('Maybe True', 'worsens') = 'May worsen', 'Supported worsening direction.');
  Check(GraphClaimLabel('Unknown', 'worsens') = 'Open hypothesis', 'An assigned direction is not a finding.');
  Check(GraphClaimLabel('Maybe False', 'worsens') = 'May ease', 'A weak easing finding reverses worsening.');
  Check(GraphClaimLabel('Maybe False', 'reduces') = 'May worsen', 'A weak worsening finding reverses easing.');
  Check(GraphClaimLabel('False', 'reduces') = 'Hypothesis challenged', 'False is not automatic worsening.');
  Check(GraphAssessmentTrend('related', 'reduces') = '', 'Related caffeine context is not green.');
  Check(GraphAssessmentTrend('related', 'worsens') = '', 'Related green tea context is not red.');
  Check(GraphAssessmentTrend('pending', 'reduces') = '', 'Pending evidence has no trend.');
  Check(GraphAssessmentTrend('inconclusive', 'worsens') = '', 'Inconclusive evidence has no trend.');
  Check(GraphAssessmentTrend('opposes', 'worsens') = '', 'Opposition cannot reverse an effect.');
  Check(GraphAssessmentLabel('opposes', 'worsens') = 'Challenges hypothesis',
    'An opposing study retains its actual ledger role.');
  Check(GraphAssessmentTrend('supports', 'reduces') = 'eases', 'Support retains the tested direction.');
  Check(GraphAssessmentTrend('supports', 'worsens') = 'worsens', 'Support can describe harm.');
  Check(GraphAssessmentLabel('pending', 'reduces') = 'Awaiting evidence', 'Access gaps remain visible.');
  Check(GraphAssessmentLabel('inconclusive', 'reduces') = 'Inconclusive', 'Keep uncertainty explicit.');
  Check(GraphClaimLabelWithStatus('Unknown', 'reduces', 'researched') = 'Unknown (Researched)',
    'Exhaustively researched Unknown surfaces as Unknown (Researched).');
  Check(GraphClaimLabelWithStatus('Unknown', 'worsens', 'partial') = 'Open hypothesis',
    'Unfinished Unknown retains Open hypothesis.');
  Check(GraphClaimLabelWithStatus('Maybe False', 'worsens', 'researched') = 'May ease',
    'Directional verdicts keep directional graph labels when researched.');
  Check(GraphClaimLabelWithStatus('Unreviewed', 'reduces', 'unreviewed') = 'Awaiting review',
    'Unreviewed claims surface as Awaiting review.');
  Check(GraphClaimLabelWithStatus('', 'worsens', '') = 'Awaiting review',
    'Empty verdicts surface as Awaiting review.');
  WriteLn(GChecks, ' graph evidence-direction checks passed.');
end.
