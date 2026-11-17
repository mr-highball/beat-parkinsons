{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentRegistryClaimScreen;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.externaldata, foodexperiment.matching;

const
  ScopeHeader = 'id'#9'ingredient'#9'registry_exposure_terms'#9'outcome_terms';
  DetailsHeader = 'nct_id'#9'interventions'#9'intervention_descriptions'#9'arms'#9 +
    'arm_descriptions'#9'primary_measures'#9'primary_descriptions'#9'secondary_measures'#9 +
    'secondary_descriptions'#9'other_measures'#9'other_descriptions'#9'brief_summary'#9 +
    'detailed_description';

function OpenRows(const AFile: String; AMinimumRows: Integer): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Text := ReadBytes(AFile);
    if Result.Count < AMinimumRows then
    begin
      raise EConvertError.Create('Missing data rows in ' + AFile);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure RegisterTerms(AMatcher: TMatcher; const ATerms: UTF8String; AIndex: Integer);
var
  LTerm: UTF8String;
begin
  for LTerm in SplitFields(ATerms, '|') do
  begin
    AMatcher.Add(LTerm, AIndex);
  end;
end;

function AddId(const AExisting, AId: String): String;
begin
  Result := AId;
  if AExisting <> '' then
  begin
    Result := AExisting + '|' + AId;
  end;
end;

procedure Scan(const AScopeFile, ADetailsFile, AOutputFile: String);
var
  LScope: TStringList;
  LRows: TStringList;
  LIds: TStringList;
  LRegistrations: TStringList;
  LAliases: TMatcher;
  LSymptoms: TMatcher;
  LInArms: TMatchFlags;
  LInDescription: TMatchFlags;
  LInMeasures: TMatchFlags;
  LFields: TFields;
  LOutput: Text;
  LIndex: Integer;
  LRow: Integer;
  LMatches: Integer;
  LArms: String;
  LNarrative: String;
  LMeasures: String;
  LDirect: String;
begin
  if SameFileName(ExpandFileName(AOutputFile), ExpandFileName(AScopeFile))
    or SameFileName(ExpandFileName(AOutputFile), ExpandFileName(ADetailsFile)) then
  begin
    raise EArgumentException.Create('The screening output must be separate from its inputs');
  end;
  LScope := nil;
  LRows := nil;
  LIds := nil;
  LRegistrations := nil;
  LAliases := nil;
  LSymptoms := nil;
  try
    LScope := OpenRows(AScopeFile, 2);
    LRows := OpenRows(ADetailsFile, 1);
    if (LScope[0] <> ScopeHeader) or (LRows[0] <> DetailsHeader) then
    begin
      raise EConvertError.Create('Unexpected registry scope or protocol details header');
    end;
    LIds := TStringList.Create;
    LRegistrations := TStringList.Create;
    LRegistrations.Sorted := True;
    LRegistrations.Duplicates := dupError;
    LAliases := TMatcher.Create;
    LSymptoms := TMatcher.Create;
    for LRow := 1 to LScope.Count - 1 do
    begin
      LFields := SplitFields(LScope[LRow], #9);
      if (Length(LFields) <> 4) or (Length(LFields[0]) <> 4) or (LFields[2] = '')
        or (LFields[3] = '')
        or (LIds.IndexOf(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid registry scope row %d', [LRow + 1]);
      end;
      LIndex := LIds.Add(LFields[0]);
      RegisterTerms(LAliases, LFields[2], LIndex);
      RegisterTerms(LSymptoms, LFields[3], LIndex);
    end;
    LAliases.Prepare;
    LSymptoms.Prepare;
    SetLength(LInArms, LIds.Count);
    SetLength(LInDescription, LIds.Count);
    SetLength(LInMeasures, LIds.Count);
    LMatches := 0;
    AssignFile(LOutput, AOutputFile);
    Rewrite(LOutput);
    SetTextCodePage(LOutput, CP_UTF8);
    try
      Write(LOutput, 'nct_id'#9'arm_exposure_claims'#9'narrative_exposure_claims'#9 +
        'measure_keyword_claims'#9'paired_arm_and_measure_claims'#10);
      for LRow := 1 to LRows.Count - 1 do
      begin
        LFields := SplitFields(LRows[LRow], #9);
        if (Length(LFields) <> 13) or (Length(LFields[0]) <> 11)
          or (Copy(LFields[0], 1, 3) <> 'NCT') then
        begin
          raise EConvertError.CreateFmt('Invalid official registry details row %d', [LRow + 1]);
        end;
        LRegistrations.Add(LFields[0]);
        FillChar(LInArms[0], Length(LInArms) * SizeOf(Boolean), 0);
        FillChar(LInDescription[0], Length(LInDescription) * SizeOf(Boolean), 0);
        FillChar(LInMeasures[0], Length(LInMeasures) * SizeOf(Boolean), 0);
        LAliases.Match(LFields[1] + ' ' + LFields[2] + ' ' + LFields[3] + ' ' +
          LFields[4], LInArms);
        LAliases.Match(LFields[11] + ' ' + LFields[12], LInDescription);
        LSymptoms.Match(LFields[5] + ' ' + LFields[6] + ' ' + LFields[7] + ' ' +
          LFields[8] + ' ' + LFields[9] + ' ' + LFields[10], LInMeasures);
        LArms := '';
        LNarrative := '';
        LMeasures := '';
        LDirect := '';
        for LIndex := 0 to LIds.Count - 1 do
        begin
          if LInArms[LIndex] then
          begin
            LArms := AddId(LArms, LIds[LIndex]);
          end;
          if LInDescription[LIndex] then
          begin
            LNarrative := AddId(LNarrative, LIds[LIndex]);
          end;
          if LInMeasures[LIndex] then
          begin
            LMeasures := AddId(LMeasures, LIds[LIndex]);
          end;
          if LInArms[LIndex] and LInMeasures[LIndex] then
          begin
            LDirect := AddId(LDirect, LIds[LIndex]);
          end;
        end;
        if LDirect <> '' then
        begin
          Inc(LMatches);
        end;
        Write(LOutput, LFields[0], #9, LArms, #9, LNarrative, #9, LMeasures, #9, LDirect, #10);
      end;
    finally
      CloseFile(LOutput);
    end;
    WriteLn(LRows.Count - 1, ' official protocols with lexical evidence flags; ',
      LMatches, ' with an arm and measure keyword for the same claim.');
  finally
    LSymptoms.Free;
    LAliases.Free;
    LRegistrations.Free;
    LIds.Free;
    LRows.Free;
    LScope.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if ParamCount <> 3 then
    begin
      raise EArgumentException.Create('Provide scope, registry details and screening output paths');
    end;
    Scan(ParamStr(1), ParamStr(2), ParamStr(3));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.

