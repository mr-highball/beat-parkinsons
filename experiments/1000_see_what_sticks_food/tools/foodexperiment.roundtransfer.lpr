{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentRoundTransfer;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, foodexperiment.transfer;

var
  GSummary: TTransferSummary;
  GSourceDir, GTargetDir, GOutPath: String;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if ParamCount <> 3 then
    begin
      WriteLn(StdErr,
        'Usage: foodexperiment.roundtransfer <source-round-dir> <target-round-dir> <out-tsv>');
      Halt(1);
    end;
    GSourceDir := ExcludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
    GTargetDir := ExcludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
    GOutPath := ExpandFileName(ParamStr(3));
    GSummary := BuildRoundTransfer(GSourceDir, GTargetDir, GOutPath);
    WriteLn('ROUND_TRANSFER source_claims=', GSummary.SourceClaims,
      ' target_claims=', GSummary.TargetClaims,
      ' direct_ingredient_scorecard=', GSummary.DirectIngredientScorecard,
      ' ingredient_assessed=', GSummary.IngredientAssessed,
      ' matrix_related=', GSummary.MatrixRelated,
      ' cold_start_zero_dir_symptom=', GSummary.ColdStartZeroDirSymptom,
      ' cold_start=', GSummary.ColdStart,
      ' target_zero_dir_symptom_claims=', GSummary.TargetZeroDirSymptomClaims);
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
