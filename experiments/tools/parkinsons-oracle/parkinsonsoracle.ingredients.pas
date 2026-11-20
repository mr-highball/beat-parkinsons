{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.ingredients;

{$mode delphi}
{$H+}

interface

uses fpjson;

type
  TIngredientSignal = record
    Ingredient: String;
    Symptom: String;
    Preparation: String;
    Verdict: String;
    HypothesisDirection: String;
    ClaimId: String;
    LocalReference: String;
    Round: Integer;
  end;

  TIngredientSignals = array of TIngredientSignal;

function IngredientEffects(const ARevision: String; const ASymptoms: array of String;
  const AIngredients: array of String; const ASignals: TIngredientSignals): TJSONObject;

implementation

uses Classes, SysUtils, parkinsonsoracle.trend;

function MissingSymptoms(ASymptoms, AObserved: TStrings): TJSONArray;
var
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  for LIndex := 0 to ASymptoms.Count - 1 do
  begin
    if AObserved.IndexOf(ASymptoms[LIndex]) < 0 then
    begin
      Result.Add(ASymptoms[LIndex]);
    end;
  end;
end;

function IngredientEffects(const ARevision: String; const ASymptoms: array of String;
  const AIngredients: array of String; const ASignals: TIngredientSignals): TJSONObject;
var
  LNames: TStringList;
  LUnresolvedNames: TStringList;
  LSymptoms: TStringList;
  LObserved: TStringList;
  LIngredientObserved: TStringList;
  LSelected: TJSONArray;
  LEases: TJSONArray;
  LWorsens: TJSONArray;
  LMixed: TJSONArray;
  LUnresolved: TJSONArray;
  LIngredient: String;
  LGroup: TJSONObject;
  LItem: TJSONObject;
  LRows: TJSONArray;
  LSignal: TIngredientSignal;
  LSymptom: String;
  LTrend: String;
  LIndex: Integer;
  LSignalIndex: Integer;
  LTotal: Integer;
  LDestination: TJSONArray;
begin
  LNames := TStringList.Create;
  LUnresolvedNames := TStringList.Create;
  LSymptoms := TStringList.Create;
  LObserved := TStringList.Create;
  LIngredientObserved := TStringList.Create;
  Result := TJSONObject.Create;
  try
    try
      LNames.Sorted := True;
      LUnresolvedNames.Sorted := True;
      Result.Add('revision', ARevision);
      LSelected := TJSONArray.Create;
      Result.Add('symptoms', LSelected);
      for LSymptom in ASymptoms do
      begin
        if LSymptoms.IndexOf(LSymptom) < 0 then
        begin
          LSymptoms.Add(LSymptom);
          LSelected.Add(LSymptom);
        end;
      end;
      LEases := TJSONArray.Create;
      LWorsens := TJSONArray.Create;
      LMixed := TJSONArray.Create;
      LUnresolved := TJSONArray.Create;
      Result.Add('may_ease', LEases);
      Result.Add('may_worsen', LWorsens);
      Result.Add('mixed', LMixed);
      Result.Add('unresolved', LUnresolved);
      LTotal := 0;
      for LSignal in ASignals do
      begin
        LTrend := ClaimTrend(LSignal.Verdict, LSignal.HypothesisDirection);
        if (LTrend = '') or (LSymptoms.IndexOf(LSignal.Symptom) < 0) then
        begin
          Continue;
        end;
        LObserved.Add(LSignal.Symptom);
        LIndex := LNames.IndexOf(LSignal.Ingredient);
        if LIndex < 0 then
        begin
          LGroup := TJSONObject.Create;
          LNames.AddObject(LSignal.Ingredient, LGroup);
          LGroup.Add('ingredient', LSignal.Ingredient);
          LGroup.Add('findings', TJSONArray.Create);
        end
        else
        begin
          LGroup := TJSONObject(LNames.Objects[LIndex]);
        end;
        LItem := TJSONObject.Create;
        LGroup.Arrays['findings'].Add(LItem);
        LItem.Add('symptom', LSignal.Symptom);
        LItem.Add('preparation', LSignal.Preparation);
        LItem.Add('trend', LTrend);
        LItem.Add('verdict', LSignal.Verdict);
        LItem.Add('round', LSignal.Round);
        LItem.Add('claim_id', LSignal.ClaimId);
        LItem.Add('local_reference', LSignal.LocalReference);
        Inc(LTotal);
      end;
      for LIndex := 0 to LNames.Count - 1 do
      begin
        LGroup := TJSONObject(LNames.Objects[LIndex]);
        LRows := LGroup.Arrays['findings'];
        LIngredientObserved.Clear;
        LDestination := LWorsens;
        if LRows.Objects[0].Strings['trend'] = 'eases' then
        begin
          LDestination := LEases;
        end;
        for LSignalIndex := 0 to LRows.Count - 1 do
        begin
          LItem := LRows.Objects[LSignalIndex];
          LIngredientObserved.Add(LItem.Strings['symptom']);
          if LItem.Strings['trend'] <> LRows.Objects[0].Strings['trend'] then
          begin
            LDestination := LMixed;
          end;
        end;
        LGroup.Add('unresolved_symptoms', MissingSymptoms(LSymptoms, LIngredientObserved));
        LDestination.Add(LGroup);
        LNames.Objects[LIndex] := nil;
      end;
      Result.Add('unresolved_symptoms', MissingSymptoms(LSymptoms, LObserved));
      for LIngredient in AIngredients do
      begin
        if (LNames.IndexOf(LIngredient) < 0) and (LUnresolvedNames.IndexOf(LIngredient) < 0) then
        begin
          LUnresolvedNames.Add(LIngredient);
        end;
      end;
      for LIndex := 0 to LUnresolvedNames.Count - 1 do
      begin
        LUnresolved.Add(LUnresolvedNames[LIndex]);
      end;
      Result.Add('ingredient_count', LNames.Count + LUnresolved.Count);
      Result.Add('directional_ingredient_count', LNames.Count);
      Result.Add('finding_count', LTotal);
    except
      Result.Free;
      raise;
    end;
  finally
    for LIndex := 0 to LNames.Count - 1 do
    begin
      LGroup := TJSONObject(LNames.Objects[LIndex]);
      LGroup.Free;
    end;
    LIngredientObserved.Free;
    LObserved.Free;
    LSymptoms.Free;
    LUnresolvedNames.Free;
    LNames.Free;
  end;
end;

end.
