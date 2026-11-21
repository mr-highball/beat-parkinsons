{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentScorecardMergeTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Process, FPSha256;

const
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CVerdictHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9 +
    'search_record'#9'local_verdict';
  CDecisionHeader = 'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale';
  CSourceHeader = 'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9 +
    'claim_effect'#9'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9 +
    'reliability_fit'#9'independence'#9'n'#9'unit'#9'local_reference'#9'rationale';
  CLf = #10;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

procedure WriteUtf8(const APath, AText: String);
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  Check(ForceDirectories(ExtractFileDir(APath)), 'Cannot create directory for ' + APath);
  LBytes := UTF8String(AText);
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if LBytes <> '' then
    begin
      LStream.WriteBuffer(LBytes[1], Length(LBytes));
    end;
  finally
    LStream.Free;
  end;
end;

function ReadUtf8(const APath: String): String;
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, Integer(LStream.Size));
    if LBytes <> '' then
    begin
      LStream.ReadBuffer(LBytes[1], Length(LBytes));
    end;
    Result := String(LBytes);
  finally
    LStream.Free;
  end;
end;

function Sha256Of(const AText: String): String;
var
  LBytes: TBytes;
  LUtf8: UTF8String;
  LHex: AnsiString;
begin
  LUtf8 := UTF8String(AText);
  SetLength(LBytes, Length(LUtf8));
  if Length(LUtf8) > 0 then
  begin
    Move(LUtf8[1], LBytes[0], Length(LUtf8));
  end;
  TSHA256.DigestHexa(LBytes, LHex);
  Result := LowerCase(String(LHex));
end;

function InvokeMerger(const AExe: String; const AArgs: array of String;
  out AOutput: String): Integer;
var
  LProcess: TProcess;
  LArg: String;
  LOut: TMemoryStream;
  LBuffer: array[0..4095] of Byte;
  LRead: LongInt;
begin
  LProcess := TProcess.Create(nil);
  LOut := TMemoryStream.Create;
  try
    LProcess.Executable := AExe;
    for LArg in AArgs do
    begin
      LProcess.Parameters.Add(LArg);
    end;
    LProcess.Options := [poUsePipes, poStderrToOutPut];
    LProcess.ShowWindow := swoHide;
    LProcess.Execute;
    repeat
      LRead := LProcess.Output.Read(LBuffer, SizeOf(LBuffer));
      if LRead > 0 then
      begin
        LOut.WriteBuffer(LBuffer, LRead);
      end;
    until LRead = 0;
    LProcess.WaitOnExit;
    SetLength(AOutput, LOut.Size);
    if LOut.Size > 0 then
    begin
      LOut.Position := 0;
      LOut.ReadBuffer(AOutput[1], LOut.Size);
    end;
    Result := LProcess.ExitStatus;
  finally
    LOut.Free;
    LProcess.Free;
  end;
end;

procedure Run(const AExe, AFixtureRoot: String);
var
  LRoot: String;
  LExp: String;
  LFreeze: String;
  LOutput: String;
  LStaged1: String;
  LStaged2: String;
  LStagedBad: String;
  LDraftDir: String;
  LCode: Integer;
  LVerdicts: String;
  LScorecards: String;
  LSources: String;
begin
  LRoot := ExcludeTrailingPathDelimiter(ExpandFileName(AFixtureRoot));
  LExp := LRoot + PathDelim + 'experiments' + PathDelim + 'sample_round';
  LDraftDir := LRoot + PathDelim + 'drafts';
  LStaged1 := LRoot + PathDelim + 'staged1';
  LStaged2 := LRoot + PathDelim + 'staged2';
  LStagedBad := LRoot + PathDelim + 'staged-bad';

  WriteUtf8(LRoot + PathDelim + 'research' + PathDelim + '2020-2024' + PathDelim +
    'olive-trial.txt', 'Sample primary trial.' + CLf);
  WriteUtf8(LRoot + PathDelim + 'research' + PathDelim + '2020-2024' + PathDelim +
    'existing-note.md', 'Existing note.' + CLf);

  LFreeze := CFreezeHeader + CLf +
    '0001'#9'oil'#9'olive oil'#9'extra-virgin'#9'constipation severity'#9'reduces'#9 +
      'Consuming extra-virgin olive oil reduces constipation severity.' + CLf +
    '0002'#9'spice'#9'saffron'#9'ground'#9'fatigue severity'#9'worsens'#9 +
      'Consuming ground saffron worsens fatigue severity.' + CLf;
  WriteUtf8(LExp + PathDelim + 'freeze.tsv', LFreeze);
  WriteUtf8(LExp + PathDelim + 'freeze.sha256', Sha256Of(LFreeze) + CLf);
  WriteUtf8(LExp + PathDelim + 'verdicts.tsv',
    CVerdictHeader + CLf +
    '0001'#9'Maybe True'#9'53'#9'Legacy rationale.'#9'research/2020-2024/existing-note.md'#9'0001-1|0001-2'#9'Unknown' + CLf +
    '0002'#9'Unknown'#9'50'#9'Untested.'#9#9'0002-1|0002-2'#9'Unknown' + CLf);
  WriteUtf8(LExp + PathDelim + 'followup' + PathDelim + 'scorecards.tsv',
    CDecisionHeader + CLf +
    '0002'#9'1'#9'open'#9'none'#9'Open baseline.' + CLf);
  WriteUtf8(LExp + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv',
    CSourceHeader + CLf);

  // 1. Valid append of a new minimal_signal scorecard for 0001.
  WriteUtf8(LDraftDir + PathDelim + 'd1.tsv',
    CDecisionHeader + CLf +
    '0001'#9'1'#9'minimal_signal'#9'eases'#9'Controlled non-PD trial favors easing.' + CLf);
  WriteUtf8(LDraftDir + PathDelim + 's1.tsv',
    CSourceHeader + CLf +
    '0001'#9'olive-2021'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
    'direct'#9'partial'#9'direct'#9'direct'#9'direct'#9'confirmed'#9'50'#9'people'#9 +
    'research/2020-2024/olive-trial.txt'#9'Controlled olive oil stool trial.' + CLf);

  LCode := InvokeMerger(AExe, [LExp, LDraftDir + PathDelim + 'd1.tsv',
    LDraftDir + PathDelim + 's1.tsv', LStaged1], LOutput);
  Check(LCode = 0, 'Valid minimal_signal merge must succeed: ' + LOutput);
  LVerdicts := ReadUtf8(LStaged1 + PathDelim + 'verdicts.tsv');
  Check(Pos('0001'#9'Maybe True'#9'50.005'#9'Controlled non-PD trial favors easing.'#9 +
    'research/2020-2024/olive-trial.txt|research/2020-2024/existing-note.md'#9'0001-1|0001-2'#9'Unknown',
    LVerdicts) > 0, 'Verdict row must update anchor, rationale and merged references.');
  Check(Pos('0002'#9'Unknown'#9'50'#9'Untested.'#9#9'0002-1|0002-2'#9'Unknown', LVerdicts) > 0,
    'Unrelated verdict rows must stay intact.');
  LScorecards := ReadUtf8(LStaged1 + PathDelim + 'scorecards.tsv');
  Check((Pos('0002'#9'1'#9'open', LScorecards) > 0) and
    (Pos('0001'#9'1'#9'minimal_signal', LScorecards) > 0),
    'Staged scorecards must preserve prior rows and append the new row.');

  // 2. Replace existing scorecard 0002 from open -> Maybe False (direct_clinical_signal eases worsening).
  WriteUtf8(LDraftDir + PathDelim + 'd2.tsv',
    CDecisionHeader + CLf +
    '0002'#9'1'#9'direct_clinical_signal'#9'eases'#9'Matched PD trial favors less fatigue.' + CLf);
  WriteUtf8(LDraftDir + PathDelim + 's2.tsv',
    CSourceHeader + CLf +
    '0002'#9'saffron-pd'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
    'direct'#9'direct'#9'direct'#9'direct'#9'direct'#9'confirmed'#9'92'#9'people'#9 +
    'research/2020-2024/olive-trial.txt'#9'Direct PD randomized trial.' + CLf);
  LCode := InvokeMerger(AExe, [LExp, LDraftDir + PathDelim + 'd2.tsv',
    LDraftDir + PathDelim + 's2.tsv', LStaged2], LOutput);
  Check(LCode = 0, 'Replacing an existing scorecard must succeed: ' + LOutput);
  LVerdicts := ReadUtf8(LStaged2 + PathDelim + 'verdicts.tsv');
  Check(Pos('0002'#9'Maybe False'#9'55'#9, LVerdicts) > 0,
    'Easing on a worsens claim at direct_clinical_signal must emit Maybe False 55.');
  LSources := ReadUtf8(LStaged2 + PathDelim + 'scorecard-sources.tsv');
  Check(Pos('0002'#9'saffron-pd', LSources) > 0, 'Replacement sources must be staged.');

  // 3. Reject missing research file reference.
  WriteUtf8(LDraftDir + PathDelim + 's-missing.tsv',
    CSourceHeader + CLf +
    '0001'#9'olive-2021'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
    'direct'#9'partial'#9'direct'#9'direct'#9'direct'#9'confirmed'#9'50'#9'people'#9 +
    'research/2020-2024/does-not-exist.txt'#9'Missing file.' + CLf);
  LCode := InvokeMerger(AExe, [LExp, LDraftDir + PathDelim + 'd1.tsv',
    LDraftDir + PathDelim + 's-missing.tsv', LStagedBad], LOutput);
  Check(LCode <> 0, 'Missing local_reference must fail.');

  // 4. Reject tier prerequisite violation (limited_clinical_link without direct PD population).
  WriteUtf8(LDraftDir + PathDelim + 'd-badtier.tsv',
    CDecisionHeader + CLf +
    '0001'#9'1'#9'limited_clinical_link'#9'eases'#9'Overclaimed tier.' + CLf);
  LCode := InvokeMerger(AExe, [LExp, LDraftDir + PathDelim + 'd-badtier.tsv',
    LDraftDir + PathDelim + 's1.tsv', LStagedBad], LOutput);
  Check(LCode <> 0, 'Tier prerequisite violation must fail.');

  // 5. Reject staging directly into experiment directory.
  LCode := InvokeMerger(AExe, [LExp, LDraftDir + PathDelim + 'd1.tsv',
    LDraftDir + PathDelim + 's1.tsv', LExp], LOutput);
  Check(LCode <> 0, 'In-place staging into experiment dir must fail.');

  WriteLn('ScorecardMergeTests passed (5/5).');
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    Check(ParamCount = 2,
      'Usage: foodexperiment.scorecardmerge.tests <merger-exe> <fresh-fixture-dir>');
    Run(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
