{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program SelectionTests;

{$mode delphi}{$H+}

uses SysUtils, parkinsonsoracle.selection;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
  Inc(GChecks);
end;

procedure Run;
var
  LValues: TStringValues;
  LPrior: TStringValues;
  LClaims: TClaimIdentities;
  LOrder: TClaimIndices;
begin
  LValues := nil;
  LValues := AddSelection(LValues, 'rest tremor severity');
  LPrior := LValues;
  LValues := AddSelection(LValues, 'pain severity');
  Check((Length(LValues) = 2) and HasSelection(LValues, 'rest tremor severity') and
    HasSelection(LValues, 'pain severity'), 'Adding pain preserves tremor.');
  Check(Length(LPrior) = 1, 'Selection operations do not mutate prior arrays.');
  LValues := AddSelection(LValues, 'pain severity');
  Check(Length(LValues) = 2, 'Duplicate selections do not add clauses.');
  LValues := AddSelection(LValues, '');
  Check(Length(LValues) = 2, 'Empty selection does not match everything.');
  LValues := RemoveSelection(LValues, 'rest tremor severity');
  Check((Length(LValues) = 1) and (LValues[0] = 'pain severity'),
    'Removing one pill preserves the other.');
  LValues := RemoveSelection(LValues, 'missing');
  Check(Length(LValues) = 1, 'Removing an absent pill is harmless.');
  LValues := RemoveSelection(LValues, 'pain severity');
  Check(Length(LValues) = 0, 'Removing the last pill clears the set.');
  LClaims := nil;
  Check(Length(OrderedUniqueClaims(LClaims)) = 0, 'Empty union remains empty.');
  SetLength(LClaims, 5);
  LClaims[0].Round := 2;
  LClaims[0].Id := '0001';
  LClaims[1].Round := 1;
  LClaims[1].Id := '0904';
  LClaims[2].Round := 1;
  LClaims[2].Id := '0281';
  LClaims[3].Round := 1;
  LClaims[3].Id := '0904';
  LClaims[4].Round := 1;
  LClaims[4].Id := '0001';
  LOrder := OrderedUniqueClaims(LClaims);
  Check(Length(LOrder) = 4, 'OR union removes repeated claim identities.');
  Check((LOrder[0] = 4) and (LOrder[1] = 2) and (LOrder[2] = 1) and
    (LOrder[3] = 0), 'Union order is stable by round and frozen ID.');
  Check(LClaims[0].Round = 2, 'Sorting does not mutate source identities.');
  WriteLn(GChecks, ' multi-selection and stable claim-union checks passed.');
end;

begin
  Run;
end.
