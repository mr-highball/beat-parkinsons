{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.trend;

{$mode delphi}{$H+}

interface

function ClaimTrend(const AVerdict, ADirection: String): String;

implementation

function ClaimTrend(const AVerdict, ADirection: String): String;
begin
  Result := '';
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

end.
