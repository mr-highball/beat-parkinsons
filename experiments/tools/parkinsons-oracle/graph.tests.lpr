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
  Check(GraphClaimLabel('Maybe False', 'worsens') = 'Hypothesis challenged', 'Opposition is not inverse efficacy.');
  Check(GraphClaimLabel('False', 'reduces') = 'Hypothesis challenged', 'False is not automatic worsening.');
  Check(GraphAssessmentTrend('related', 'reduces') = '', 'Related caffeine context is not green.');
  Check(GraphAssessmentTrend('related', 'worsens') = '', 'Related green tea context is not red.');
  Check(GraphAssessmentTrend('pending', 'reduces') = '', 'Pending evidence has no trend.');
  Check(GraphAssessmentTrend('inconclusive', 'worsens') = '', 'Inconclusive evidence has no trend.');
  Check(GraphAssessmentTrend('oppose', 'worsens') = '', 'Opposition cannot reverse an effect.');
  Check(GraphAssessmentTrend('support', 'reduces') = 'eases', 'Support retains the tested direction.');
  Check(GraphAssessmentTrend('support', 'worsens') = 'worsens', 'Support can describe harm.');
  Check(GraphAssessmentLabel('pending', 'reduces') = 'Awaiting evidence', 'Access gaps remain visible.');
  Check(GraphAssessmentLabel('inconclusive', 'reduces') = 'Inconclusive', 'Keep uncertainty explicit.');
  WriteLn(GChecks, ' graph evidence-direction checks passed.');
end.
