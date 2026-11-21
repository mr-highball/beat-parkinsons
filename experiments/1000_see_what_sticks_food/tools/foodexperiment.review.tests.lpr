{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentReviewTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, FPSha256, Process;

const
  Lf = #10;
  FreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  ReviewHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9 +
    'search_record'#9'local_verdict';
  QueryHeader = 'query_id'#9'provider'#9'searched_on'#9'query'#9'result_count'#9 +
    'screened_count'#9'status'#9'notes';
  CategoryNames: array[0..3] of String = ('food', 'herb', 'spice', 'oil');
  TestRationale: UTF8String = 'Synthetic directional fixture with café in the text.';

function JoinPath(const ADirectory, AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ADirectory) + AName;
end;

procedure WriteText(const APath: String; const AValue: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(AValue[1], Length(AValue));
  finally
    LStream.Free;
  end;
end;

function ReadText(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(Result, Integer(LStream.Size));
    LStream.ReadBuffer(Result[1], Length(Result));
  finally
    LStream.Free;
  end;
end;

procedure Exercise(const AExecutable, ACommand, APath: String; const AExpectedError: String = '');
var
  LSucceeded: Boolean;
  LOutput: String;
begin
  LSucceeded := RunCommand(AExecutable, [ACommand, APath], LOutput, [poStderrToOutPut]);
  if AExpectedError = '' then
  begin
    Assert(LSucceeded, ACommand + ' failed unexpectedly: ' + LOutput);
  end
  else
  begin
    Assert(not LSucceeded and (Pos(AExpectedError, LOutput) > 0), 'Expected ' + AExpectedError +
      ' from ' + ACommand + ', got ' + LOutput);
  end;
end;

procedure BuildFixture(const AExperiment: String; AClaimCount: Integer; AUnbalanced: Boolean;
  out AReviews, AQueries: UTF8String);
var
  LFreeze: UTF8String;
  LId: UTF8String;
  LCategory: UTF8String;
  LIngredient: UTF8String;
  LDirection: UTF8String;
  LStatement: UTF8String;
  LClaim: UTF8String;
  LReviewsPath: String;
  LStream: TFileStream;
  LHash: UTF8String;
  LIndex: Integer;
begin
  Assert(ForceDirectories(JoinPath(AExperiment, 'statements')));
  LFreeze := FreezeHeader + Lf;
  AReviews := ReviewHeader + Lf;
  for LIndex := 1 to AClaimCount do
  begin
    LId := UTF8String(Format('%.4d', [LIndex]));
    if AUnbalanced then
    begin
      if LIndex <= (AClaimCount * 7) div 10 then
      begin
        LCategory := 'food';
      end
      else if LIndex <= (AClaimCount * 8) div 10 then
      begin
        LCategory := 'herb';
      end
      else if LIndex <= (AClaimCount * 9) div 10 then
      begin
        LCategory := 'spice';
      end
      else
      begin
        LCategory := 'oil';
      end;
    end
    else
    begin
      LCategory := UTF8String(CategoryNames[(LIndex - 1) div 250]);
    end;
    LIngredient := 'fixture ' + LId;
    if Odd(LIndex) then
    begin
      LDirection := 'reduces';
    end
    else
    begin
      LDirection := 'worsens';
    end;
    LStatement := 'Synthetic claim ' + LId + '.';
    LFreeze := LFreeze + LId + #9 + LCategory + #9 + LIngredient +
      #9'cooked'#9'test symptom'#9 + LDirection + #9 + LStatement + Lf;
    LClaim := 'ID: ' + LId + Lf + 'Category: ' + LCategory + Lf +
      'Ingredient: ' + LIngredient + Lf + 'Preparation: cooked' + Lf +
      'Symptom: test symptom' + Lf + 'Direction: ' + LDirection + Lf +
      'Statement: ' + LStatement + Lf + 'Verdict: Pending' + Lf + 'Confidence:' + Lf +
      'Rationale:' + Lf + 'Local references:' + Lf + 'Search record:' + Lf;
    WriteText(JoinPath(AExperiment, 'statements/' + String(LId) + '.txt'), LClaim);
    case LIndex of
      1:
      begin
        AReviews := AReviews + LId + #9'True'#9'60'#9 + TestRationale +
          #9'research/source.txt#section'#9'Q1|Q2'#9'Unknown' + Lf;
      end;
      2:
      begin
        AReviews := AReviews + LId + #9'False'#9'85'#9'Fixture rationale.'#9 +
          'research/source.txt'#9#9'False' + Lf;
      end;
      3:
      begin
        AReviews := AReviews + LId + #9'Maybe True'#9'50.005'#9'Fixture rationale.'#9 +
          'research/source.txt'#9'Q1|Q2'#9'Maybe True' + Lf;
      end;
      4:
      begin
        AReviews := AReviews + LId + #9'Maybe False'#9'59.9999'#9'Fixture rationale.'#9 +
          'research/source.txt'#9'Q1|Q2'#9'Unknown' + Lf;
      end;
      else
      begin
        AReviews := AReviews + LId + #9'Unknown'#9'50'#9'Fixture rationale.'#9#9 +
          'Q1|Q2'#9'Unknown' + Lf;
      end;
    end;
  end;
  WriteText(JoinPath(AExperiment, 'freeze.tsv'), LFreeze);
  LStream := TFileStream.Create(JoinPath(AExperiment, 'freeze.tsv'), fmOpenRead);
  try
    LHash := UTF8String(LowerCase(TSHA256.StreamHexa(LStream)));
  finally
    LStream.Free;
  end;
  WriteText(JoinPath(AExperiment, 'freeze.sha256'), LHash + Lf);
  LReviewsPath := JoinPath(AExperiment, 'verdicts.tsv');
  WriteText(LReviewsPath, AReviews);
  AQueries := QueryHeader + Lf +
    'Q1'#9'fixture'#9'2026-11-11'#9'exact test phrase'#9'30'#9'20'#9'Completed'#9 + Lf +
    'Q2'#9'fixture'#9'2026-11-11'#9'broad test phrase'#9#9'3'#9'Completed'#9 + Lf;
  WriteText(JoinPath(AExperiment, 'queries.tsv'), AQueries);
end;

procedure RunRound7Tests(const AExecutable, ABuildDirectory: String);
var
  LGuid: TGuid;
  LFixture: String;
  LExperiment: String;
  LBadRound1Fixture: String;
  LBadRound1: String;
  LReviews: UTF8String;
  LQueries: UTF8String;
  LLastPath: String;
  LReviewedLast: UTF8String;
  LManifest: UTF8String;
  LHash: UTF8String;
begin
  Assert(CreateGuid(LGuid) = 0);
  LFixture := JoinPath(ABuildDirectory, 'review-round7-fixture-' + GuidToString(LGuid));
  LExperiment := JoinPath(LFixture, 'experiments/1000_see_what_sticks_food_round_7');
  Assert(ForceDirectories(JoinPath(LFixture, 'research')));
  WriteText(JoinPath(LFixture, 'research/source.txt'), 'Synthetic source.' + Lf);
  BuildFixture(LExperiment, 930, True, LReviews, LQueries);
  LLastPath := JoinPath(LExperiment, 'statements/0930.txt');

  Exercise(AExecutable, 'verify', LExperiment, 'review differs');
  LHash := ReadText(JoinPath(LExperiment, 'freeze.sha256'));
  WriteText(JoinPath(LExperiment, 'freeze.sha256'), 'bad' + Lf);
  Exercise(AExecutable, 'apply', LExperiment, 'digest mismatch');
  WriteText(JoinPath(LExperiment, 'freeze.sha256'), LHash);

  Exercise(AExecutable, 'apply', LExperiment);
  Exercise(AExecutable, 'verify', LExperiment);
  Exercise(AExecutable, 'summary', LExperiment);
  LManifest := ReadText(JoinPath(LExperiment, 'manifest.md'));
  Assert(Pos('**930** frozen statements', LManifest) > 0, 'Expected 930 statement count.');
  Assert(Pos('| Unknown | 928 | 926 |', LManifest) > 0, 'Expected 930-claim unknown counts.');
  Assert(Pos('[0003](statements/0003.txt) **Maybe True** (50.005%)', LManifest) > 0);

  LReviewedLast := ReadText(LLastPath);
  WriteText(LLastPath, UTF8String(StringReplace(String(LReviewedLast), 'Synthetic claim 0930.',
    'Edited claim.', [])));
  Exercise(AExecutable, 'verify', LExperiment, 'Frozen statement was edited');
  WriteText(LLastPath, LReviewedLast);
  Exercise(AExecutable, 'verify', LExperiment);

  Assert(CreateGuid(LGuid) = 0);
  LBadRound1Fixture := JoinPath(ABuildDirectory, 'review-quota-fixture-' + GuidToString(LGuid));
  LBadRound1 := JoinPath(LBadRound1Fixture, 'experiments/1000_see_what_sticks_food');
  Assert(ForceDirectories(JoinPath(LBadRound1Fixture, 'research')));
  WriteText(JoinPath(LBadRound1Fixture, 'research/source.txt'), 'Synthetic source.' + Lf);
  BuildFixture(LBadRound1, 1000, True, LReviews, LQueries);
  Exercise(AExecutable, 'apply', LBadRound1, 'quota mismatch');
end;

procedure RunTests(const AExecutable, ABuildDirectory: String);
var
  LGuid: TGuid;
  LFixture: String;
  LExperiment: String;
  LReviews: UTF8String;
  LQueries: UTF8String;
  LReviewsPath: String;
  LStatementPath: String;
  LPending: UTF8String;
  LReviewed: UTF8String;
  LManifest: UTF8String;
  LHash: UTF8String;
begin
  Assert(CreateGuid(LGuid) = 0);
  LFixture := JoinPath(ABuildDirectory, 'review-fixture-' + GuidToString(LGuid));
  LExperiment := JoinPath(LFixture, 'experiments/1000_see_what_sticks_food');
  Assert(ForceDirectories(JoinPath(LFixture, 'research')));
  WriteText(JoinPath(LFixture, 'research/source.txt'), 'Synthetic source.' + Lf);
  BuildFixture(LExperiment, 1000, False, LReviews, LQueries);
  LReviewsPath := JoinPath(LExperiment, 'verdicts.tsv');
  LStatementPath := JoinPath(LExperiment, 'statements/0001.txt');
  LPending := ReadText(LStatementPath);
  Exercise(AExecutable, 'verify', LExperiment, 'review differs');

  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), #9'True'#9'60'#9,
    #9'True'#9'59'#9, [])));
  Exercise(AExecutable, 'apply', LExperiment, 'at least 60');
  Assert(ReadText(LStatementPath) = LPending);
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), #9'Maybe True'#9'50.005'#9,
    #9'Maybe True'#9'50'#9, [])));
  Exercise(AExecutable, 'apply', LExperiment, 'above 50 and below 60');
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), #9'Maybe False'#9'59.9999'#9,
    #9'Maybe False'#9'60'#9, [])));
  Exercise(AExecutable, 'apply', LExperiment, 'above 50 and below 60');
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), #9'Unknown'#9'50'#9,
    #9'Unknown'#9'50.0001'#9, [])));
  Exercise(AExecutable, 'apply', LExperiment, 'Unknown requires 50');
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), #9'Maybe True'#9'50.005'#9,
    #9'Maybe True'#9'50.00001'#9, [])));
  Exercise(AExecutable, 'apply', LExperiment, 'Invalid confidence decimal');
  Assert(ReadText(LStatementPath) = LPending);
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), 'Q1|Q2', 'Q1', [])));
  Exercise(AExecutable, 'apply', LExperiment, 'two distinct external queries');
  Assert(ReadText(LStatementPath) = LPending);
  WriteText(LReviewsPath, UTF8String(StringReplace(String(LReviews), 'research/source.txt',
    'research/../source.txt', [])));
  Exercise(AExecutable, 'apply', LExperiment, 'Invalid source path');
  Assert(ReadText(LStatementPath) = LPending);

  WriteText(LReviewsPath, LReviews);
  LHash := ReadText(JoinPath(LExperiment, 'freeze.sha256'));
  WriteText(JoinPath(LExperiment, 'freeze.sha256'), 'bad' + Lf);
  Exercise(AExecutable, 'apply', LExperiment, 'digest mismatch');
  Assert(ReadText(LStatementPath) = LPending);
  WriteText(JoinPath(LExperiment, 'freeze.sha256'), LHash);

  Exercise(AExecutable, 'apply', LExperiment);
  Exercise(AExecutable, 'verify', LExperiment);
  LReviewed := ReadText(LStatementPath);
  Assert(Pos('Verdict: True' + Lf + 'Confidence: 60', LReviewed) > 0);
  Assert(Pos('Verdict: Maybe True' + Lf + 'Confidence: 50.005' + Lf,
    ReadText(JoinPath(LExperiment, 'statements/0003.txt'))) > 0, 'Expected a fractional lean.');
  Assert(Pos('Verdict: Maybe False' + Lf + 'Confidence: 59.9999' + Lf,
    ReadText(JoinPath(LExperiment, 'statements/0004.txt'))) > 0, 'Expected exact decimal storage.');
  Assert(Pos(UTF8String(TestRationale), LReviewed) > 0, 'Expected UTF-8 rationale to round-trip.');
  Assert(Pos('Local references: research/source.txt#section', LReviewed) > 0);
  Assert(not DirectoryExists(JoinPath(LExperiment, 'statements.review-backup')));
  Exercise(AExecutable, 'apply', LExperiment);
  Assert(ReadText(LStatementPath) = LReviewed);

  WriteText(JoinPath(LExperiment, 'findings.md'), '## Synthetic findings' + Lf);
  Exercise(AExecutable, 'summary', LExperiment);
  LManifest := ReadText(JoinPath(LExperiment, 'manifest.md'));
  Assert(Pos('**1,000** frozen statements', LManifest) > 0, 'Expected 1,000 statement count.');
  Assert(Pos('| Unknown | 998 | 996 |', LManifest) > 0);
  Assert(Pos('[0001](statements/0001.txt) **True** (60%)', LManifest) > 0);
  Assert(Pos('[0003](statements/0003.txt) **Maybe True** (50.005%)', LManifest) > 0);
  Assert(Pos('## Synthetic findings', LManifest) > 0);
  Exercise(AExecutable, 'summary', LExperiment);
  Assert(ReadText(JoinPath(LExperiment, 'manifest.md')) = LManifest);

  WriteText(LStatementPath, UTF8String(StringReplace(String(LReviewed), 'Synthetic claim 0001.',
    'Edited claim.', [])));
  Exercise(AExecutable, 'verify', LExperiment, 'Frozen statement was edited');
  WriteText(LStatementPath, LReviewed);
  Exercise(AExecutable, 'verify', LExperiment);
end;

begin
  Assert(ParamCount = 2, 'Pass the review executable and an isolated build directory.');
  RunTests(ParamStr(1), ParamStr(2));
  RunRound7Tests(ParamStr(1), ParamStr(2));
  WriteLn('PASS synthetic review fixtures (1,000-claim balanced Round 1 + 930-claim unbalanced Round 7).');
end.
