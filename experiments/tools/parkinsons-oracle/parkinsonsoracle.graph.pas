{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.graph;

{$mode delphi}{$H+}{$codepage utf8}

interface

function GraphClaimLabel(const AVerdict, ADirection: String): String;
function GraphClaimLabelWithStatus(const AVerdict, ADirection, AResearchStatus: String): String;
function GraphAssessmentLabel(const ARole, ADirection: String): String;
function GraphAssessmentTrend(const ARole, ADirection: String): String;

implementation

uses parkinsonsoracle.trend;

function GraphClaimLabel(const AVerdict, ADirection: String): String;
var
  LTrend: String;
begin
  LTrend := ClaimTrend(AVerdict, ADirection);
  if LTrend = 'eases' then
  begin
    Exit('May ease');
  end;
  if LTrend = 'worsens' then
  begin
    Exit('May worsen');
  end;
  if (AVerdict = 'False') or (AVerdict = 'Maybe False') then
  begin
    Exit('Hypothesis challenged');
  end;
  Result := 'Open hypothesis';
end;

function GraphClaimLabelWithStatus(const AVerdict, ADirection, AResearchStatus: String): String;
begin
  if (AVerdict = 'Unknown') and (AResearchStatus = 'researched') then
  begin
    Exit('Unknown (Researched)');
  end;
  Result := GraphClaimLabel(AVerdict, ADirection);
end;

function GraphAssessmentTrend(const ARole, ADirection: String): String;
begin
  Result := '';
  if ARole = 'supports' then
  begin
    Result := ClaimTrend('Maybe True', ADirection);
  end;
end;

function GraphAssessmentLabel(const ARole, ADirection: String): String;
var
  LTrend: String;
begin
  LTrend := GraphAssessmentTrend(ARole, ADirection);
  if LTrend = 'eases' then
  begin
    Exit('Supports easing hypothesis');
  end;
  if LTrend = 'worsens' then
  begin
    Exit('Supports worsening hypothesis');
  end;
  if ARole = 'opposes' then
  begin
    Exit('Challenges hypothesis');
  end;
  if ARole = 'pending' then
  begin
    Exit('Awaiting evidence');
  end;
  if ARole = 'inconclusive' then
  begin
    Exit('Inconclusive');
  end;
  Result := 'Related context';
end;

end.
