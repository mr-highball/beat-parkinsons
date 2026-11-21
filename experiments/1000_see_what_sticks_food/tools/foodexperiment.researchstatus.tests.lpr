{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentResearchStatusTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, Classes, FPSha256, foodexperiment.auditstatus;

const
  CLf = #10;

var
  GPassed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create('FAIL: ' + AMessage);
  end;
  Inc(GPassed);
end;

procedure WriteUtf8(const APath, AText: String);
var
  LStream: TFileStream;
  LUtf8: UTF8String;
begin
  ForceDirectories(ExtractFileDir(APath));
  LUtf8 := UTF8String(AText);
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if LUtf8 <> '' then
    begin
      LStream.WriteBuffer(LUtf8[1], Length(LUtf8));
    end;
  finally
    LStream.Free;
  end;
end;

function Sha256Text(const AText: String): String;
var
  LUtf8: UTF8String;
  LBytes: TBytes;
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

procedure SetupFixture(const ARoot, AStatusRows: String; AIncludeScorecard: Boolean);
var
  LFreeze: String;
  LVerdicts: String;
  LScorecards: String;
  LSources: String;
begin
  LFreeze :=
    'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement' + CLf +
    '0001'#9'food'#9'apple'#9'raw'#9'rest tremor severity'#9'reduces'#9'Test claim 1.' + CLf +
    '0002'#9'spice'#9'saffron'#9'ground'#9'fatigue severity'#9'worsens'#9'Test claim 2.' + CLf;
  LVerdicts :=
    'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9'search_record'#9'local_verdict' + CLf +
    '0001'#9'Unknown'#9'50'#9'Open after exhaustive audit.'#9''#9'0001-1'#9'Unknown' + CLf +
    '0002'#9'Maybe False'#9'50.005'#9'Minimal signal eases.'#9'research/2020-2024/sample.md'#9'0002-1'#9'Unknown' + CLf;
  LScorecards :=
    'id'#9'rubric_version'#9'tier'#9'symptom_effect'#9'rationale' + CLf;
  LSources :=
    'id'#9'family'#9'kind'#9'reporter'#9'provenance'#9'observed_effect'#9'claim_effect'#9 +
    'exposure_fit'#9'population_fit'#9'outcome_fit'#9'attribution_fit'#9'reliability_fit'#9 +
    'independence'#9'n'#9'unit'#9'local_reference'#9'rationale' + CLf;
  if AIncludeScorecard then
  begin
    LScorecards := LScorecards +
      '0001'#9'1'#9'open'#9'none'#9'No eligible directional signal.' + CLf +
      '0002'#9'1'#9'minimal_signal'#9'eases'#9'Minimal easing signal.' + CLf;
    LSources := LSources +
      '0002'#9'fam1'#9'trial'#9'investigators'#9'original'#9'eases'#9'eases'#9 +
      'partial'#9'partial'#9'partial'#9'direct'#9'partial'#9'confirmed'#9'30'#9'people'#9 +
      'research/2020-2024/sample.md'#9'Sample randomized trial.' + CLf;
  end;
  WriteUtf8(ARoot + PathDelim + 'freeze.tsv', LFreeze);
  WriteUtf8(ARoot + PathDelim + 'freeze.sha256', Sha256Text(LFreeze) + CLf);
  WriteUtf8(ARoot + PathDelim + 'verdicts.tsv', LVerdicts);
  WriteUtf8(ARoot + PathDelim + 'followup' + PathDelim + 'scorecards.tsv', LScorecards);
  WriteUtf8(ARoot + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv', LSources);
  WriteUtf8(ARoot + PathDelim + 'followup' + PathDelim + 'research-status.tsv',
    CResearchStatusHeader + CLf + AStatusRows);
end;

procedure RunTests(const AFixtureDir: String);
var
  LSummary: TResearchStatusSummary;
  LFailed: Boolean;
begin
  // 1. DisplayVerdictLabel & ValidIsoUtcDate
  Check(DisplayVerdictLabel('Unknown', 'researched') = 'Unknown (Researched)',
    'Researched Unknown formats as Unknown (Researched).');
  Check(DisplayVerdictLabel('Unknown', 'partial') = 'Unknown',
    'Partial Unknown stays Unknown.');
  Check(DisplayVerdictLabel('Maybe True', 'researched') = 'Maybe True',
    'Directional verdict keeps its verdict label.');
  Check(ValidIsoUtcDate('2026-11-21') and ValidIsoUtcDate('2026-11-21T17:15:00Z') and
    not ValidIsoUtcDate('11/21/2026'),
    'ISO UTC date validation accepts YYYY-MM-DD and full UTC timestamp only.');

  // 2. Valid complete researched fixture passes verify-complete
  SetupFixture(AFixtureDir + PathDelim + 'f1',
    '0001'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+CT.gov+Cultural'#9'No direct human PD trial' + CLf +
    '0002'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+CT.gov+Cultural'#9'Non-PD sample' + CLf,
    True);
  LSummary := VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f1', True);
  Check((LSummary.TotalFrozen = 2) and (LSummary.Researched = 2) and
    (LSummary.UnknownResearched = 1) and (LSummary.UnknownUnresearched = 0) and
    (LSummary.DirectionalResearched = 1),
    'Complete researched fixture tallies Unknown (Researched) and Directional cleanly.');

  // 3. Rejects researched claim lacking cultural check
  SetupFixture(AFixtureDir + PathDelim + 'f2',
    '0001'#9'researched'#9'yes'#9'no'#9'yes'#9'2026-11-21'#9'PubMed only'#9'Cultural missing' + CLf,
    True);
  LFailed := False;
  try
    VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f2', False);
  except
    on EConvertError do LFailed := True;
  end;
  Check(LFailed, 'Reject researched claim when cultural_checked=no.');

  // 4. Rejects researched claim lacking recorded v1 scorecard
  SetupFixture(AFixtureDir + PathDelim + 'f3',
    '0001'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+Cultural'#9'None' + CLf,
    False);
  LFailed := False;
  try
    VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f3', False);
  except
    on EConvertError do LFailed := True;
  end;
  Check(LFailed, 'Reject researched claim without recorded v1 scorecard.');

  // 5. Partial coverage works under verify, rejected under verify-complete
  SetupFixture(AFixtureDir + PathDelim + 'f4',
    '0001'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+Cultural'#9'None' + CLf,
    True);
  LSummary := VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f4', False);
  Check((LSummary.Researched = 1) and (LSummary.Partial = 1) and
    (LSummary.UnknownResearched = 1) and (LSummary.DirectionalUnresearched = 1),
    'Partial coverage counts missing rows as partial when verdicts exist.');
  LFailed := False;
  try
    VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f4', True);
  except
    on EConvertError do LFailed := True;
  end;
  Check(LFailed, 'verify-complete rejects partial coverage.');

  // 6. Rejects unsorted claim IDs
  SetupFixture(AFixtureDir + PathDelim + 'f5',
    '0002'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+Cultural'#9'None' + CLf +
    '0001'#9'researched'#9'yes'#9'yes'#9'yes'#9'2026-11-21'#9'PubMed+Cultural'#9'None' + CLf,
    True);
  LFailed := False;
  try
    VerifyExperimentResearchStatus(AFixtureDir + PathDelim + 'f5', False);
  except
    on EConvertError do LFailed := True;
  end;
  Check(LFailed, 'Reject unsorted research-status.tsv rows.');

  WriteLn('ResearchStatusTests passed (', GPassed, '/', GPassed, ').');
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if ParamCount <> 1 then
    begin
      raise EArgumentException.Create('Pass a temporary fixture directory.');
    end;
    RunTests(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
