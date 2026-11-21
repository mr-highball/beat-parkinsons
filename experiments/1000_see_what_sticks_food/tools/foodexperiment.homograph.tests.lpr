{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentHomographTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, foodexperiment.homograph;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure Run;
var
  LRes: THomographResult;
begin
  // 1. Pure figure-citation collision for fig.
  LRes := ScreenHomographText('fig',
    'Parkinson motor scores are plotted in Fig. 1 and Supplementary Fig S2 (Fig 3A).');
  Check(LRes.Verdict = hvPureCollision, 'Pure Fig. citations must classify as collision.');

  // 2. Adversarial: real fig fruit paper that ALSO contains Fig. 1 must NEVER exclude.
  LRes := ScreenHomographText('fig',
    'As shown in Fig. 1, participants ate 50 g of dried figs daily (Ficus carica).');
  Check(LRes.Verdict = hvFoodMention, 'Food mention alongside Fig. 1 must stay hvFoodMention.');

  // 3. Ambiguous bare word "fig" without period/number must stay ambiguous.
  LRes := ScreenHomographText('fig',
    'Patients consumed fig extract or syrup before meals.');
  Check(LRes.Verdict = hvFoodMention, 'fig extract must trigger food mention.');
  LRes := ScreenHomographText('fig',
    'A patient chewed a single fig after lunch.');
  Check(LRes.Verdict = hvAmbiguous, 'Unqualified dietary fig must remain ambiguous.');

  // 4. Pure temporal date collision.
  LRes := ScreenHomographText('date',
    'To date, enrollment date and date of onset were recorded alongside follow-up dates.');
  Check(LRes.Verdict = hvPureCollision, 'Pure temporal date phrases must classify as collision.');

  // 5. Adversarial: date palm paper that also says "to date" must NEVER exclude.
  LRes := ScreenHomographText('date',
    'To date, no trial of Phoenix dactylifera Ajwa dates has enrolled Parkinson patients.');
  Check(LRes.Verdict = hvFoodMention, 'Date palm mention alongside "to date" must stay hvFoodMention.');

  // 6. Ambiguous culinary date mention must remain ambiguous.
  LRes := ScreenHomographText('date',
    'Participants broke their fast with water and a sweet date.');
  Check(LRes.Verdict = hvAmbiguous, 'Culinary bare date must remain ambiguous.');

  // 7. Pure SAGE publisher / acronym collision vs Salvia officinalis.
  LRes := ScreenHomographText('sage',
    'Published by SAGE Publications (sagepub.com); analyzed WHO SAGE cohort data.');
  Check(LRes.Verdict = hvPureCollision, 'SAGE publisher and WHO SAGE must classify as collision.');
  LRes := ScreenHomographText('sage',
    'Published by SAGE Open. Oral Salvia officinalis extract improved alertness.');
  Check(LRes.Verdict = hvFoodMention, 'Salvia mention alongside SAGE Open must stay hvFoodMention.');

  // 8. Pure color/Agent Orange collision vs orange juice / citrus.
  LRes := ScreenHomographText('orange',
    'Acridine orange staining and Agent Orange exposure are shown in orange bars.');
  Check(LRes.Verdict = hvPureCollision, 'Color/stain/Agent Orange must classify as collision.');
  LRes := ScreenHomographText('orange',
    'Shown in orange bars, participants drank 200 mL orange juice daily.');
  Check(LRes.Verdict = hvFoodMention, 'Orange juice alongside orange bars must stay hvFoodMention.');

  // 9. Zero occurrences in complete text.
  LRes := ScreenHomographText('fig',
    'A randomized trial of deep brain stimulation for Parkinson disease.');
  Check(LRes.Verdict = hvZeroOccurrences, 'Zero occurrences must classify as hvZeroOccurrences.');

  // 10. Unsupported culinary ingredient must not be auto-excluded.
  LRes := ScreenHomographText('saffron', 'A Parkinson trial.');
  Check(LRes.Verdict = hvUnsupported, 'Non-homograph ingredient must return hvUnsupported.');

  WriteLn('HomographTests passed (10/10).');
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
