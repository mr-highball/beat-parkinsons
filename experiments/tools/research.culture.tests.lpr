{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program ResearchCultureTests;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, Process;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

procedure WriteText(const APath, AText: String);
var
  LLines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  LLines := TStringList.Create;
  try
    LLines.LineBreak := #10;
    LLines.Text := AText;
    LLines.WriteBOM := False;
    LLines.SaveToFile(APath, TEncoding.UTF8);
  finally
    LLines.Free;
  end;
end;

function ReadText(const APath: String): String;
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(APath, TEncoding.UTF8);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function NewFixture(const ABase, AName: String): String;
var
  LYear: Integer;
begin
  Result := IncludeTrailingPathDelimiter(ABase) + AName + PathDelim;
  Check(not DirectoryExists(Result), 'Use a fresh fixture root.');
  WriteText(Result + 'research/Cultural-and-Experiential.md', 'Synthetic fixture policy.');
  LYear := 1865;
  while LYear <= 2025 do
  begin
    WriteText(Result + 'research/' + IntToStr(LYear) + '-' + IntToStr(LYear + 4) +
      '/README.md', 'Preserve this period introduction.');
    Inc(LYear, 5);
  end;
end;

procedure AddHistorical(const ARoot, APeriod, ADate: String; AIndex: Boolean);
var
  LDirectory: String;
begin
  LDirectory := ARoot + 'research/' + APeriod + '/';
  if AIndex then
  begin
    WriteText(LDirectory + 'README.md', 'Historical source context.');
  end;
  WriteText(LDirectory + 'Cultural-and-Experiential/README.md', 'Keep this custom guide.');
  WriteText(LDirectory + 'Cultural-and-Experiential/Traditional-Practices/fixture.txt',
    'Title: Synthetic fixture, no real claim'#10 +
    'Collection: Cultural and experiential'#10 +
    'Source kind: Synthetic test'#10 +
    'Source: https://example.invalid/fixture'#10 +
    'Publication date: ' + ADate + #10 +
    'Date basis: Test fixture year'#10 +
    'Reviewed: 2026-11-18'#10 +
    'Reported direction: Unspecified'#10 +
    'Authenticity: Fixture only'#10 +
    'Efficacy evidence: None; synthetic fixture'#10);
end;

function RunTool(const AExecutable, ARoot: String; out AOutput: String): Boolean;
var
  LProcess: TProcess;
  LBuffer: array[0..1023] of Char;
  LCount: Integer;
  LPart: String;
begin
  AOutput := '';
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := AExecutable;
    LProcess.Parameters.Add(ARoot);
    LProcess.Parameters.Add('2025');
    LProcess.Options := [poUsePipes, poWaitOnExit, poStderrToOutPut];
    LProcess.Execute;
    repeat
      LCount := LProcess.Output.Read(LBuffer, SizeOf(LBuffer));
      if LCount > 0 then
      begin
        SetString(LPart, PChar(@LBuffer[0]), LCount);
        AOutput := AOutput + LPart;
      end;
    until LCount = 0;
    Result := LProcess.ExitStatus = 0;
  finally
    LProcess.Free;
  end;
end;

procedure Run;
var
  LExecutable: String;
  LBase: String;
  LRoot: String;
  LOutput: String;
  LBefore: String;
begin
  Check(ParamCount = 2, 'Pass the tool executable and a new ignored fixture directory.');
  LExecutable := ExpandFileName(ParamStr(1));
  LBase := ExpandFileName(ParamStr(2));
  Check(Pos(PathDelim + 'build' + PathDelim, LBase) > 0,
    'Fixtures must remain under an ignored build directory.');
  LRoot := NewFixture(LBase, 'two-historical-periods');
  AddHistorical(LRoot, '1595-1599', '1597', True);
  AddHistorical(LRoot, '1660-1664', '1664', True);
  LBefore := ReadText(LRoot + 'research/1595-1599/Cultural-and-Experiential/README.md');
  Check(RunTool(LExecutable, LRoot, LOutput), 'Valid historical periods: ' + LOutput);
  Check((Pos('periods=33 ', LOutput) > 0) and
    (Pos('historical_periods=2', LOutput) > 0) and
    (Pos('cultural_records_verified=2 ', LOutput) > 0), 'Reconcile modern/history counts.');
  Check(not DirectoryExists(LRoot + 'research/1600-1604') and
    not DirectoryExists(LRoot + 'research/1665-1669'), 'Do not pad absent periods.');
  Check(ReadText(LRoot + 'research/1595-1599/Cultural-and-Experiential/README.md') =
    LBefore, 'Preserve an existing cultural guide.');
  Check(RunTool(LExecutable, LRoot, LOutput) and
    (Pos('category_readmes_created=0 index_links_added=0', LOutput) > 0),
    'Repeat initialization is idempotent.');

  LRoot := NewFixture(LBase, 'wrong-year');
  AddHistorical(LRoot, '1595-1599', '1600', True);
  Check(not RunTool(LExecutable, LRoot, LOutput) and
    (Pos('outside its period', LOutput) > 0), 'Reject out-of-bucket publication.');

  LRoot := NewFixture(LBase, 'misaligned-period');
  AddHistorical(LRoot, '1661-1665', '1664', True);
  Check(not RunTool(LExecutable, LRoot, LOutput) and
    (Pos('Invalid historical five-year period', LOutput) > 0), 'Reject shifted period.');

  LRoot := NewFixture(LBase, 'wrong-end');
  AddHistorical(LRoot, '1660-1665', '1664', True);
  Check(not RunTool(LExecutable, LRoot, LOutput) and
    (Pos('Invalid historical five-year period', LOutput) > 0), 'Reject wrong end year.');

  LRoot := NewFixture(LBase, 'missing-index');
  AddHistorical(LRoot, '1660-1664', '1664', False);
  Check(not RunTool(LExecutable, LRoot, LOutput) and
    (Pos('Missing historical period index', LOutput) > 0), 'Require historical index.');
  WriteLn(GChecks, ' historical chronology, preservation and failure checks passed.');
end;

begin
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
