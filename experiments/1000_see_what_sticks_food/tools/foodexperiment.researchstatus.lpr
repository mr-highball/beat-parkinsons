{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentResearchStatus;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, foodexperiment.auditstatus;

procedure PrintSummary(const ASummary: TResearchStatusSummary);
begin
  WriteLn('total_frozen=', ASummary.TotalFrozen,
    ' rows_present=', ASummary.RowsPresent,
    ' researched=', ASummary.Researched,
    ' partial=', ASummary.Partial,
    ' unreviewed=', ASummary.Unreviewed,
    ' unknown_researched=', ASummary.UnknownResearched,
    ' unknown_unresearched=', ASummary.UnknownUnresearched,
    ' directional_researched=', ASummary.DirectionalResearched,
    ' directional_unresearched=', ASummary.DirectionalUnresearched);
end;

var
  LCommand: String;
  LSummary: TResearchStatusSummary;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if ParamCount <> 2 then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.researchstatus <verify|verify-complete|summary> <experiment-dir>');
    end;
    LCommand := LowerCase(ParamStr(1));
    if LCommand = 'verify' then
    begin
      LSummary := VerifyExperimentResearchStatus(ParamStr(2), False);
      PrintSummary(LSummary);
    end
    else if LCommand = 'verify-complete' then
    begin
      LSummary := VerifyExperimentResearchStatus(ParamStr(2), True);
      PrintSummary(LSummary);
    end
    else if LCommand = 'summary' then
    begin
      LSummary := VerifyExperimentResearchStatus(ParamStr(2), False);
      PrintSummary(LSummary);
    end
    else
    begin
      raise EArgumentException.Create('Unknown command: ' + ParamStr(1));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
