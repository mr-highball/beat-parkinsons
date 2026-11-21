{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentRoundTransferTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, FPSha256, Process, foodexperiment.transfer;

const
  CLf = #10;
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CScorecardHeader = 'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale';
  CScorecardSourceHeader = 'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9 +
    'claim_effect'#9'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9 +
    'reliability_fit'#9'independence'#9'n'#9'unit'#9'local_reference'#9'rationale';
  CAssessmentHeader = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment';

var
  GPassed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    WriteLn(StdErr, 'FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure WriteUtf8(const APath: String; const AValue: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AValue <> '' then
    begin
      LStream.WriteBuffer(AValue[1], Length(AValue));
    end;
  finally
    LStream.Free;
  end;
end;

function ReadUtf8(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(Result, Integer(LStream.Size));
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteFreezeAndHash(const ADir: String; const AFreeze: UTF8String);
var
  LBytes: TBytes;
  LHash: AnsiString;
begin
  Check(ForceDirectories(ADir), 'Cannot create fixture dir: ' + ADir);
  WriteUtf8(IncludeTrailingPathDelimiter(ADir) + 'freeze.tsv', AFreeze);
  SetLength(LBytes, Length(AFreeze));
  Move(AFreeze[1], LBytes[0], Length(LBytes));
  TSHA256.DigestHexa(LBytes, LHash);
  WriteUtf8(IncludeTrailingPathDelimiter(ADir) + 'freeze.sha256',
    UTF8String(LowerCase(String(LHash))) + CLf);
end;

procedure TestMatrixKeys;
begin
  Check(MatrixFamilyKey('walnut') = MatrixFamilyKey('walnut oil'),
    'walnut and walnut oil should share matrix family');
  Check(MatrixFamilyKey('cilantro') = MatrixFamilyKey('coriander seed'),
    'cilantro and coriander seed should share matrix family');
  Check(MatrixFamilyKey('celery stalk') = MatrixFamilyKey('celery leaf'),
    'celery stalk and celery leaf should share matrix family');
  Check(MatrixFamilyKey('apple') <> MatrixFamilyKey('pineapple'),
    'apple and pineapple must remain distinct');
  Check(MatrixFamilyKey('sesame seed') = MatrixFamilyKey('sesame oil'),
    'sesame seed and sesame oil should share matrix family');
  Inc(GPassed);
end;

procedure TestSyntheticTransferAndGuards(const AExe, ABuildDir: String);
var
  LGuid: TGuid;
  LRoot, LSrc, LTgt, LBadTgt, LOutTsv: String;
  LSrcFreeze, LTgtFreeze, LBadFreeze, LScorecards, LSources, LAssessments: UTF8String;
  LSummary: TTransferSummary;
  LOutText: UTF8String;
  LLines: TStringList;
  LCliOut: String;
  LCliOk: Boolean;
begin
  Check(CreateGuid(LGuid) = 0, 'GUID generation failed');
  LRoot := IncludeTrailingPathDelimiter(ABuildDir) + 'rt-fixture-' + GuidToString(LGuid);
  LSrc := LRoot + PathDelim + 'round1';
  LTgt := LRoot + PathDelim + 'round2';
  LBadTgt := LRoot + PathDelim + 'round2-bad';
  LOutTsv := LRoot + PathDelim + 'transfer.tsv';

  Check(ForceDirectories(LSrc + PathDelim + 'followup'), 'Create round1 followup failed');

  LSrcFreeze := CFreezeHeader + CLf +
    '0001'#9'spice'#9'saffron'#9'ground'#9'depressive symptom severity'#9'worsens'#9'Saffron depression.' + CLf +
    '0002'#9'oil'#9'walnut oil'#9'cold-pressed'#9'pain severity'#9'reduces'#9'Walnut oil pain.' + CLf +
    '0003'#9'food'#9'apple'#9'raw'#9'drooling severity'#9'reduces'#9'Apple drooling.' + CLf;
  WriteFreezeAndHash(LSrc, LSrcFreeze);

  LScorecards := CScorecardHeader + CLf +
    '0001'#9'1'#9'direct_clinical_signal'#9'eases'#9'Saffron PD RCT.' + CLf +
    '0002'#9'1'#9'minimal_signal'#9'eases'#9'Walnut oil animal.' + CLf +
    '0003'#9'1'#9'open'#9'none'#9'No drooling trial.' + CLf;
  WriteUtf8(LSrc + PathDelim + 'followup' + PathDelim + 'scorecards.tsv', LScorecards);

  LSources := CScorecardSourceHeader + CLf +
    '0001'#9'saffron-pd-rct'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
    'direct'#9'direct'#9'direct'#9'direct'#9'partial'#9'confirmed'#9'92'#9'people'#9 +
    'research/2025-2029/saffron.txt'#9'Primary PD RCT.' + CLf +
    '0002'#9'walnut-oil-pain'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
    'partial'#9'remote'#9'partial'#9'partial'#9'partial'#9'confirmed'#9'40'#9'mice'#9 +
    'research/2020-2024/walnut-oil.txt'#9'Mouse assay.' + CLf;
  WriteUtf8(LSrc + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv', LSources);

  LAssessments := CAssessmentHeader + CLf +
    '0001'#9'PMID:11111111'#9'supporting'#9'direct'#9'research/2025-2029/saffron.txt'#9'PD RCT.' + CLf +
    '0002'#9'PMID:22222222'#9'related'#9'indirect'#9'research/2020-2024/walnut-oil.txt'#9'Oil study.' + CLf +
    '0003'#9'PMID:33333333'#9'related'#9'indirect'#9'research/2020-2024/apple.txt'#9'Chewing test.' + CLf +
    '0003'#9'PMID:99999999'#9'excluded'#9'none'#9'research/2020-2024/excl.txt'#9'Excluded row.' + CLf;
  WriteUtf8(LSrc + PathDelim + 'followup' + PathDelim + 'assessments.tsv', LAssessments);

  { Target round has 5 distinct classes:
    0001 saffron/drooling -> direct_ingredient_scorecard (zero_dir_symptom=true)
    0002 apple/pain -> ingredient_assessed (zero_dir_symptom=false)
    0003 walnut/drooling -> matrix_related via walnut oil (r1_ing_claims=0!)
    0004 adzuki beans/drooling -> cold_start_zero_dir_symptom
    0005 adzuki beans/pain -> cold_start }
  LTgtFreeze := CFreezeHeader + CLf +
    '0001'#9'spice'#9'saffron'#9'ground'#9'drooling severity'#9'reduces'#9'Saffron drooling.' + CLf +
    '0002'#9'food'#9'apple'#9'baked'#9'pain severity'#9'reduces'#9'Apple pain.' + CLf +
    '0003'#9'food'#9'walnut'#9'raw'#9'drooling severity'#9'worsens'#9'Walnut drooling.' + CLf +
    '0004'#9'food'#9'adzuki beans'#9'cooked'#9'drooling severity'#9'reduces'#9'Adzuki drooling.' + CLf +
    '0005'#9'food'#9'adzuki beans'#9'cooked'#9'pain severity'#9'worsens'#9'Adzuki pain.' + CLf;
  WriteFreezeAndHash(LTgt, LTgtFreeze);

  LSummary := BuildRoundTransfer(LSrc, LTgt, LOutTsv);
  Check(LSummary.SourceClaims = 3, 'Expected 3 source claims');
  Check(LSummary.TargetClaims = 5, 'Expected 5 target claims');
  Check(LSummary.DirectIngredientScorecard = 1, 'Expected 1 direct_ingredient_scorecard');
  Inc(GPassed);

  Check(LSummary.IngredientAssessed = 1, 'Expected 1 ingredient_assessed');
  Check(LSummary.MatrixRelated = 1, 'Expected 1 matrix_related');
  Check(LSummary.ColdStartZeroDirSymptom = 1, 'Expected 1 cold_start_zero_dir_symptom');
  Check(LSummary.ColdStart = 1, 'Expected 1 cold_start');
  Check(LSummary.TargetZeroDirSymptomClaims = 3, 'Expected 3 zero-dir symptom target claims');
  Inc(GPassed);

  LOutText := ReadUtf8(LOutTsv);
  Check((Copy(LOutText, 1, 3) <> #$EF#$BB#$BF) and (Pos(#13, LOutText) = 0),
    'Output TSV must be UTF-8 without BOM and LF-only');
  LLines := TStringList.Create;
  try
    LLines.StrictDelimiter := True;
    LLines.Delimiter := #10;
    LLines.DelimitedText := String(LOutText);
    Check(LLines[0] = CRoundTransferHeader, 'Unexpected TSV header');
    Check(ContainsStr(LLines[1], #9'direct_ingredient_scorecard'#9'true'#9'1'#9'1'#9'0'#9'1'#9'0001'#9'saffron-pd-rct|PMID:11111111'),
      'Row 1 saffron direct_ingredient_scorecard mismatch: ' + LLines[1]);
    Check(ContainsStr(LLines[2], #9'ingredient_assessed'#9'false'#9'1'#9'0'#9'1'#9'1'#9'0003'#9'PMID:33333333'),
      'Row 2 apple ingredient_assessed mismatch (excluded row must be ignored): ' + LLines[2]);
    Check(ContainsStr(LLines[3], #9'matrix_related'#9'true'#9'0'#9'0'#9'0'#9'0'#9#9#9#9'walnut oil'#9'1'#9'1'),
      'Row 3 walnut matrix_related must NOT inflate r1_ing counts: ' + LLines[3]);
    Check(ContainsStr(LLines[4], #9'cold_start_zero_dir_symptom'#9'true'#9),
      'Row 4 adzuki cold_start_zero_dir_symptom mismatch: ' + LLines[4]);
    Check(ContainsStr(LLines[5], #9'cold_start'#9'false'#9),
      'Row 5 adzuki cold_start mismatch: ' + LLines[5]);
  finally
    LLines.Free;
  end;
  Inc(GPassed);

  { Test CLI invocation succeeds }
  LCliOk := RunCommand(AExe, [LSrc, LTgt, LOutTsv], LCliOut, [poStderrToOutPut]);
  Check(LCliOk and (Pos('ROUND_TRANSFER source_claims=3 target_claims=5', LCliOut) > 0),
    'CLI invocation failed: ' + LCliOut);
  Inc(GPassed);

  { Test duplicate (ingredient, symptom) hard rejection }
  LBadFreeze := CFreezeHeader + CLf +
    '0001'#9'spice'#9'saffron'#9'dried'#9'depressive symptom severity'#9'reduces'#9'Dup saffron.' + CLf;
  WriteFreezeAndHash(LBadTgt, LBadFreeze);
  LCliOk := RunCommand(AExe, [LSrc, LBadTgt, LOutTsv], LCliOut, [poStderrToOutPut]);
  Check((not LCliOk) and (Pos('Cross-round duplicate', LCliOut) > 0),
    'Expected duplicate pair rejection, got: ' + LCliOut);
  Inc(GPassed);

  { Test freeze.sha256 digest mismatch hard rejection }
  WriteUtf8(LBadTgt + PathDelim + 'freeze.sha256', '0000badhash' + CLf);
  LCliOk := RunCommand(AExe, [LSrc, LBadTgt, LOutTsv], LCliOut, [poStderrToOutPut]);
  Check((not LCliOk) and (Pos('SHA-256 mismatch', LCliOut) > 0),
    'Expected SHA-256 mismatch rejection, got: ' + LCliOut);
  Inc(GPassed);

  { Test invalid arg count fails cleanly }
  LCliOk := RunCommand(AExe, [LSrc], LCliOut, [poStderrToOutPut]);
  Check((not LCliOk) and (Pos('Usage:', LCliOut) > 0),
    'Expected Usage error, got: ' + LCliOut);
  Inc(GPassed);
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Check(ParamCount = 2, 'Pass roundtransfer executable and isolated build directory.');
  TestMatrixKeys;
  TestSyntheticTransferAndGuards(ParamStr(1), ParamStr(2));
  WriteLn('RoundTransferTests passed (', GPassed, '/8).');
end.
