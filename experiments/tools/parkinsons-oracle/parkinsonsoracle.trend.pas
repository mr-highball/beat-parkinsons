{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.trend;

{$mode delphi}{$H+}

interface

function ClaimTrend(const AVerdict, ADirection: String): String;
function ClaimUsefulnessRank(const AVerdict, ADirection, AResearchStatus: String): Integer;
function CompareClaimUsefulness(ARankA: Integer; AConfA: Double; ARoundA: Integer;
  const AIdA: String; ARankB: Integer; AConfB: Double; ARoundB: Integer;
  const AIdB: String): Integer;

implementation

uses SysUtils;

function ClaimTrend(const AVerdict, ADirection: String): String;
begin
  Result := '';
  if AVerdict = 'Maybe False' then
  begin
    if ADirection = 'worsens' then
      Result := 'eases'
    else if ADirection = 'reduces' then
      Result := 'worsens';
    Exit;
  end;
  if (AVerdict <> 'True') and (AVerdict <> 'Maybe True') then
  begin
    Exit;
  end;
  if ADirection = 'reduces' then
  begin
    Result := 'eases';
  end
  else if ADirection = 'worsens' then
  begin
    Result := 'worsens';
  end;
end;

function ClaimUsefulnessRank(const AVerdict, ADirection, AResearchStatus: String): Integer;
var
  LTrend: String;
  LStatus: String;
begin
  LTrend := ClaimTrend(AVerdict, ADirection);
  if LTrend = 'eases' then
  begin
    if AVerdict = 'True' then
      Exit(0);
    Exit(1);
  end;
  if LTrend = 'worsens' then
  begin
    if AVerdict = 'True' then
      Exit(2);
    Exit(3);
  end;
  if AVerdict = 'False' then
    Exit(4);
  LStatus := LowerCase(Trim(AResearchStatus));
  if (AVerdict = 'Unknown (Researched)') or
    ((AVerdict = 'Unknown') and (LStatus = 'researched')) then
    Exit(5);
  if AVerdict = 'Unknown' then
    Exit(6);
  Result := 7;
end;

function CompareClaimUsefulness(ARankA: Integer; AConfA: Double; ARoundA: Integer;
  const AIdA: String; ARankB: Integer; AConfB: Double; ARoundB: Integer;
  const AIdB: String): Integer;
begin
  if ARankA < ARankB then
    Exit(-1);
  if ARankA > ARankB then
    Exit(1);
  if AConfA > AConfB then
    Exit(-1);
  if AConfA < AConfB then
    Exit(1);
  if ARoundA < ARoundB then
    Exit(-1);
  if ARoundA > ARoundB then
    Exit(1);
  Result := CompareStr(AIdA, AIdB);
end;

end.
