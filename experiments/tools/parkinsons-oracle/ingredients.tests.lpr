{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program IngredientEffectsTests;

{$mode delphi}
{$H+}

uses SysUtils, fpjson, parkinsonsoracle.ingredients;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure AddSignal(var ASignals: TIngredientSignals; const AIngredient, ASymptom,
  APreparation, AVerdict, APremise, AClaimId: String);
var
  LIndex: Integer;
begin
  LIndex := Length(ASignals);
  SetLength(ASignals, LIndex + 1);
  ASignals[LIndex].Ingredient := AIngredient;
  ASignals[LIndex].Symptom := ASymptom;
  ASignals[LIndex].Preparation := APreparation;
  ASignals[LIndex].Verdict := AVerdict;
  ASignals[LIndex].HypothesisDirection := APremise;
  ASignals[LIndex].Round := 1;
  ASignals[LIndex].ClaimId := AClaimId;
  ASignals[LIndex].LocalReference := 'research/2020-2024/fixture.txt';
end;

procedure Run;
var
  LSignals: TIngredientSignals;
  LProfile: TJSONObject;
  LRows: TJSONArray;
  LIngredient: TJSONObject;
begin
  LSignals := nil;
  AddSignal(LSignals, 'olive oil', 'constipation', 'extra-virgin',
    'Maybe False', 'worsens', '0001');
  AddSignal(LSignals, 'olive oil', 'tremors', 'refined', 'Maybe True', 'worsens', '0002');
  AddSignal(LSignals, 'blueberry', 'constipation', 'raw', 'True', 'reduces', '0003');
  AddSignal(LSignals, 'nutmeg', 'constipation', 'ground', 'Maybe True', 'worsens', '0004');
  AddSignal(LSignals, 'ginger', 'nausea', 'brewed', 'False', 'worsens', '0005');
  AddSignal(LSignals, 'cumin', 'nausea', 'ground', 'Unknown', 'reduces', '0006');
  AddSignal(LSignals, 'fig', 'pain', 'dried', 'Maybe True', 'reduces', '0007');
  LProfile := IngredientEffects('fixture', ['constipation', 'tremors', 'nausea', 'tremors'],
    ['cumin', 'nutmeg', 'olive oil', 'ginger', 'blueberry'], LSignals);
  try
    Check(LProfile.Arrays['symptoms'].Count = 3, 'Duplicate selections collapse.');
    Check(LProfile.Integers['ingredient_count'] = 5, 'Each ingredient belongs to one group.');
    Check(LProfile.Integers['directional_ingredient_count'] = 3,
      'Separate directional findings from unresolved ingredients.');
    LRows := LProfile.Arrays['unresolved'];
    Check((LRows.Count = 2) and (LRows.Strings[0] = 'cumin') and
      (LRows.Strings[1] = 'ginger'), 'Unresolved ingredients are retained alphabetically.');
    Check(LProfile.Integers['finding_count'] = 4,
      'Open, opposed-only, or unrelated findings do not acquire a direction.');
    Check(LProfile.Arrays['unresolved_symptoms'].Strings[0] = 'nausea',
      'A selected symptom without a direction is present in the response.');
    LIngredient := LProfile.Arrays['mixed'].Objects[0];
    Check(LIngredient.Strings['ingredient'] = 'olive oil', 'Mixed findings stay together.');
    LRows := LIngredient.Arrays['findings'];
    Check((LRows.Objects[0].Strings['trend'] = 'eases') and
      (LRows.Objects[1].Strings['trend'] = 'worsens'), 'Evidence follows the verdict sign.');
    Check((LRows.Objects[0].Strings['preparation'] = 'extra-virgin') and
      (LRows.Objects[1].Strings['preparation'] = 'refined'), 'Keep the specific preparations.');
    Check((LRows.Objects[0].Strings['claim_id'] = '0001') and
      (LRows.Objects[0].Strings['local_reference'] <> ''), 'Keep the evidence locator.');
    LIngredient := LProfile.Arrays['may_ease'].Objects[0];
    Check(LIngredient.Strings['ingredient'] = 'blueberry', 'Easing-only group is correct.');
    Check(LIngredient.Arrays['unresolved_symptoms'].Count = 2,
      'An easing finding leaves the ingredient’s other symptom questions open.');
    Check(LProfile.Arrays['may_worsen'].Objects[0].Strings['ingredient'] = 'nutmeg',
      'Worsening-only group is correct.');
  finally
    LProfile.Free;
  end;
  WriteLn('Ingredient grouping, mixed effects, unknowns and provenance passed.');
end;

begin
  Run;
end.
