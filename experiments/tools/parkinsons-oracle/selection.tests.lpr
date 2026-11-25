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

  SetLength(LClaims, 11);
  // Intentionally scrambled order across all usefulness tiers plus one duplicate.
  LClaims[0].Round := 1; LClaims[0].Id := '0001'; LClaims[0].Verdict := 'Unreviewed';
  LClaims[0].Direction := 'reduces'; LClaims[0].ResearchStatus := 'unreviewed'; LClaims[0].Confidence := -1;

  LClaims[1].Round := 1; LClaims[1].Id := '0002'; LClaims[1].Verdict := 'Unknown';
  LClaims[1].Direction := 'reduces'; LClaims[1].ResearchStatus := 'researched'; LClaims[1].Confidence := 50;

  LClaims[2].Round := 1; LClaims[2].Id := '0003'; LClaims[2].Verdict := 'Maybe True';
  LClaims[2].Direction := 'worsens'; LClaims[2].ResearchStatus := 'researched'; LClaims[2].Confidence := 51;

  LClaims[3].Round := 1; LClaims[3].Id := '0004'; LClaims[3].Verdict := 'Maybe True';
  LClaims[3].Direction := 'reduces'; LClaims[3].ResearchStatus := 'researched'; LClaims[3].Confidence := 50.005;

  LClaims[4].Round := 1; LClaims[4].Id := '0005'; LClaims[4].Verdict := 'Maybe False';
  LClaims[4].Direction := 'worsens'; LClaims[4].ResearchStatus := 'researched'; LClaims[4].Confidence := 55;

  LClaims[5].Round := 1; LClaims[5].Id := '0006'; LClaims[5].Verdict := 'True';
  LClaims[5].Direction := 'worsens'; LClaims[5].ResearchStatus := 'researched'; LClaims[5].Confidence := 85;

  LClaims[6].Round := 1; LClaims[6].Id := '0007'; LClaims[6].Verdict := 'True';
  LClaims[6].Direction := 'reduces'; LClaims[6].ResearchStatus := 'researched'; LClaims[6].Confidence := 80;

  LClaims[7].Round := 1; LClaims[7].Id := '0008'; LClaims[7].Verdict := 'False';
  LClaims[7].Direction := 'reduces'; LClaims[7].ResearchStatus := 'researched'; LClaims[7].Confidence := 70;

  LClaims[8].Round := 1; LClaims[8].Id := '0009'; LClaims[8].Verdict := 'Maybe False';
  LClaims[8].Direction := 'reduces'; LClaims[8].ResearchStatus := 'researched'; LClaims[8].Confidence := 50.005;

  LClaims[9].Round := 1; LClaims[9].Id := '0010'; LClaims[9].Verdict := 'Unknown';
  LClaims[9].Direction := 'reduces'; LClaims[9].ResearchStatus := 'partial'; LClaims[9].Confidence := 50;

  // Duplicate of LClaims[4] (Round 1, Id 0005)
  LClaims[10] := LClaims[4];

  LOrder := OrderedUniqueClaims(LClaims);
  Check(Length(LOrder) = 10, 'Usefulness-sorted union deduplicates repeated claims.');
  // Expected order:
  // 0: [6] True eases (80)
  // 1: [4] Maybe False worsens -> eases (55)
  // 2: [3] Maybe True reduces -> eases (50.005)
  // 3: [5] True worsens (85)
  // 4: [2] Maybe True worsens (51)
  // 5: [8] Maybe False reduces -> worsens (50.005)
  // 6: [7] False challenged (70)
  // 7: [1] Unknown (Researched)
  // 8: [9] Unknown (partial)
  // 9: [0] Unreviewed
  Check((LOrder[0] = 6) and (LOrder[1] = 4) and (LOrder[2] = 3) and
    (LOrder[3] = 5) and (LOrder[4] = 2) and (LOrder[5] = 8) and
    (LOrder[6] = 7) and (LOrder[7] = 1) and (LOrder[8] = 9) and
    (LOrder[9] = 0),
    'Union sorts descending by usefulness: eases, then worsens, challenged, unknown, unreviewed.');
  WriteLn(GChecks, ' multi-selection and usefulness-ordered claim-union checks passed.');
end;

begin
  Run;
end.
