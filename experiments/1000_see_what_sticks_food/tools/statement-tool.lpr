{
  Copyright (c) 2026 the beat-parkinsons contributors.
  All rights reserved.
}
program StatementTool;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, FPSHA256;

const
  DefaultSeed: Cardinal = $18652026;
  ClaimsPerCategory = 250;
  ClaimsPerDirection = ClaimsPerCategory div 2;
  ClaimCount = 1000;
  Algorithm = 'xorshift32-rejection-fisher-yates-v1';
  FreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  Artifacts: array[0..3] of String = ('freeze.tsv', 'freeze.sha256', 'seed.txt', 'statements');
  FieldNames: array[0..11] of String = (
    'ID', 'Category', 'Ingredient', 'Preparation', 'Symptom', 'Direction',
    'Statement', 'Verdict', 'Confidence', 'Rationale', 'Local references', 'Search record');
  CategoryNames: array[0..3] of String = ('food', 'herb', 'spice', 'oil');
  Verdicts: array[0..5] of String = (
    'Pending', 'True', 'False', 'Maybe True', 'Maybe False', 'Unknown');

type
  TFields = array of String;
  TTable = array of TFields;

  TPair = record
    Ingredient: Integer;
    Symptom: Integer;
  end;

  TPairs = array of TPair;

  TRandomState = record
    State: Cardinal;
    function Draw(const ABound: Integer): Integer;
  end;

procedure Require(const ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EArgumentException.Create(AMessage);
  end;
end;

function ChildPath(const AParent, AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(AParent) + AName;
end;

function ReadUtf8(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= 4 * 1024 * 1024, 'Unexpectedly large input: ' + APath);
    SetLength(Result, LStream.Size);
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

procedure WriteUtf8(const APath, AText: String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function FileHash(const APath: String): String;
var
  LStream: TFileStream;
  LHex: AnsiString;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    TSHA256.StreamHexa(LStream, LHex);
    Result := LowerCase(LHex);
  finally
    LStream.Free;
  end;
end;

function Split(const AText: String; const ASeparator: Char): TFields;
var
  LStart: Integer;
  I: Integer;
begin
  Result := nil;
  LStart := 1;
  for I := 1 to Length(AText) do
  begin
    if AText[I] = ASeparator then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(AText, LStart, I - LStart);
      LStart := I + 1;
    end;
  end;
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := Copy(AText, LStart, MaxInt);
end;

procedure RequireLabel(const ALabel, AContext: String);
begin
  Require((ALabel <> '') and (Trim(ALabel) = ALabel) and (Pos(#0, ALabel) = 0),
    'Invalid label in ' + AContext);
end;

function LoadVocabulary(const APath, AHeader: String; const AColumns, AKey: Integer): TTable;
var
  LLines: TStringList;
  LNames: TStringList;
  LForm: String;
  I: Integer;
begin
  Result := nil;
  LLines := TStringList.Create;
  try
    LLines.Text := ReadUtf8(APath);
    Require((LLines.Count >= 2) and (LLines[0] = AHeader), 'Unexpected header: ' + APath);
    LNames := TStringList.Create;
    try
      LNames.Sorted := True;
      LNames.Duplicates := dupError;
      SetLength(Result, LLines.Count - 1);
      for I := 1 to LLines.Count - 1 do
      begin
        Result[I - 1] := Split(LLines[I], #9);
        Require(Length(Result[I - 1]) = AColumns, 'Invalid vocabulary row: ' + LLines[I]);
        RequireLabel(Result[I - 1][AKey], APath);
        LNames.Add(Result[I - 1][AKey]);
        if AColumns = 4 then
        begin
          Require((Result[I - 1][0] = 'food') or (Result[I - 1][0] = 'herb')
            or (Result[I - 1][0] = 'spice') or (Result[I - 1][0] = 'oil'),
            'Invalid category: ' + Result[I - 1][0]);
          for LForm in Split(Result[I - 1][2], '|') do
          begin
            RequireLabel(LForm, APath);
          end;
        end;
      end;
    finally
      LNames.Free;
    end;
  finally
    LLines.Free;
  end;
end;

function TRandomState.Draw(const ABound: Integer): Integer;
var
  LLimit: QWord;
  LSample: QWord;
begin
  Assert((State <> 0) and (ABound > 0));
  { Xorshift32 visits 1 through 2^32-1. Translate to a zero-based range before rejection. }
  LLimit := QWord(High(Cardinal)) - QWord(High(Cardinal)) mod QWord(ABound);
  repeat
    State := State xor (State shl 13);
    State := State xor (State shr 17);
    State := State xor (State shl 5);
    LSample := QWord(State) - 1;
  until LSample < LLimit;
  Result := Integer(LSample mod QWord(ABound));
end;

function BuildPairs(const AIngredients: TTable; const ASymptomCount: Integer;
  const ACategory: String): TPairs;
var
  LIngredientCount: Integer;
  LIndex: Integer;
  I: Integer;
  J: Integer;
begin
  Result := nil;
  LIngredientCount := 0;
  for I := 0 to High(AIngredients) do
  begin
    if AIngredients[I][0] = ACategory then
    begin
      Inc(LIngredientCount);
    end;
  end;
  SetLength(Result, LIngredientCount * ASymptomCount);
  Require(Length(Result) >= ClaimsPerCategory, 'Fewer than 250 unique pairs for ' + ACategory);
  LIndex := 0;
  for I := 0 to High(AIngredients) do
  begin
    if AIngredients[I][0] = ACategory then
    begin
      for J := 0 to ASymptomCount - 1 do
      begin
        Result[LIndex].Ingredient := I;
        Result[LIndex].Symptom := J;
        Inc(LIndex);
      end;
    end;
  end;
end;

function BuildClaims(const ADirectory: String; const ASeed: Cardinal): TTable;
var
  LIngredients: TTable;
  LSymptoms: TTable;
  LRandom: TRandomState;
  LCategory: String;
  LPairs: TPairs;
  LPair: TPair;
  LFields: TFields;
  LForms: TFields;
  LIndex: Integer;
  LSwap: Integer;
  I: Integer;
begin
  LIngredients := LoadVocabulary(ChildPath(ADirectory, 'ingredients.tsv'),
    'category'#9'ingredient'#9'forms'#9'aliases', 4, 1);
  LSymptoms := LoadVocabulary(ChildPath(ADirectory, 'symptoms.tsv'), 'symptom'#9'aliases', 2, 0);
  LRandom.State := ASeed;
  LIndex := 0;
  Result := nil;
  SetLength(Result, ClaimCount);
  for LCategory in CategoryNames do
  begin
    LPairs := BuildPairs(LIngredients, Length(LSymptoms), LCategory);
    for I := 0 to ClaimsPerCategory - 1 do
    begin
      LSwap := I + LRandom.Draw(Length(LPairs) - I);
      LPair := LPairs[LSwap];
      LPairs[LSwap] := LPairs[I];
      LPairs[I] := LPair;
      SetLength(Result[LIndex], 7);
      Result[LIndex][1] := LCategory;
      Result[LIndex][2] := LIngredients[LPair.Ingredient][1];
      LForms := Split(LIngredients[LPair.Ingredient][2], '|');
      Result[LIndex][3] := LForms[LRandom.Draw(Length(LForms))];
      Result[LIndex][4] := LSymptoms[LPair.Symptom][0];
      Result[LIndex][5] := 'reduces';
      if I >= ClaimsPerDirection then
      begin
        Result[LIndex][5] := 'worsens';
      end;
      Inc(LIndex);
    end;
  end;
  { Keep direction quotas while shuffling the on-disk order across categories. }
  for I := High(Result) downto 1 do
  begin
    LSwap := LRandom.Draw(I + 1);
    LFields := Result[LSwap];
    Result[LSwap] := Result[I];
    Result[I] := LFields;
  end;
  for I := 0 to High(Result) do
  begin
    Result[I][0] := Format('%.4d', [I + 1]);
    Result[I][6] := Format('Consuming %s %s %s %s in people with Parkinson''s disease.',
      [Result[I][3], Result[I][2], Result[I][5], Result[I][4]]);
  end;
end;

function FreezeText(const AClaims: TTable): String;
var
  LText: TStringBuilder;
  LFields: TFields;
  I: Integer;
begin
  LText := TStringBuilder.Create;
  try
    LText.Append(FreezeHeader).Append(#10);
    for LFields in AClaims do
    begin
      LText.Append(LFields[0]);
      for I := 1 to High(LFields) do
      begin
        LText.Append(#9).Append(LFields[I]);
      end;
      LText.Append(#10);
    end;
    Result := LText.ToString;
  finally
    LText.Free;
  end;
end;

function SeedValue(const AText: String): Cardinal;
var
  LValue: QWord;
  LCharacter: Char;
begin
  for LCharacter in AText do
  begin
    Require(LCharacter in ['0'..'9'], 'Seed must be an unsigned decimal integer');
  end;
  Require(TryStrToQWord(AText, LValue) and (LValue > 0) and (LValue <= High(Cardinal)),
    'Seed must be between 1 and 4294967295');
  Result := Cardinal(LValue);
end;

function SeedText(const ADirectory: String; const ASeed: Cardinal): String;
begin
  Result := 'seed=' + UIntToStr(ASeed) + #10 + 'algorithm=' + Algorithm + #10
    + 'ingredients.sha256=' + FileHash(ChildPath(ADirectory, 'ingredients.tsv')) + #10
    + 'symptoms.sha256=' + FileHash(ChildPath(ADirectory, 'symptoms.tsv')) + #10;
end;

function StatementText(const AFields: TFields): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AFields) do
  begin
    Result := Result + FieldNames[I] + ': ' + AFields[I] + #10;
  end;
  Result := Result + 'Verdict: Pending'#10;
  for I := 8 to High(FieldNames) do
  begin
    Result := Result + FieldNames[I] + ':'#10;
  end;
end;

procedure VerifyStatement(const APath: String; const AFields: TFields);
var
  LText: String;
  LLines: TFields;
  LLabel: String;
  LVerdict: String;
  LFound: Boolean;
  I: Integer;
begin
  LText := ReadUtf8(APath);
  LLines := Split(LText, #10);
  Require((Length(LLines) = Length(FieldNames) + 1) and (LLines[High(LLines)] = '')
    and (Pos(#13, LText) = 0), 'Expected 12 UTF-8 LF lines in ' + APath);
  for I := 0 to High(AFields) do
  begin
    Require(LLines[I] = FieldNames[I] + ': ' + AFields[I],
      'Frozen field differs in ' + APath + ' (' + FieldNames[I] + ')');
  end;
  LFound := False;
  for LVerdict in Verdicts do
  begin
    if LLines[7] = 'Verdict: ' + LVerdict then
    begin
      LFound := True;
    end;
  end;
  Require(LFound, 'Invalid verdict in ' + APath);
  for I := 8 to High(FieldNames) do
  begin
    LLabel := FieldNames[I] + ':';
    Require((LLines[I] = LLabel) or (Copy(LLines[I], 1, Length(LLabel) + 1) = LLabel + ' '),
      'Invalid field in ' + APath + ' (' + FieldNames[I] + ')');
  end;
end;

procedure VerifyFiles(const ADirectory: String; const AClaims: TTable);
var
  LDirectory: String;
  LFound: TSearchRec;
  LCount: Integer;
  LFields: TFields;
begin
  LDirectory := ChildPath(ADirectory, 'statements');
  LCount := 0;
  if FindFirst(ChildPath(LDirectory, '*'), faAnyFile, LFound) = 0 then
  begin
    try
      repeat
        if (LFound.Name <> '.') and (LFound.Name <> '..') then
        begin
          Require((LFound.Attr and faDirectory) = 0,
            'Unexpected directory in statements: ' + LFound.Name);
          Inc(LCount);
        end;
      until FindNext(LFound) <> 0;
    finally
      FindClose(LFound);
    end;
  end;
  Require(LCount = ClaimCount, 'Expected exactly 1000 files in ' + LDirectory);
  for LFields in AClaims do
  begin
    VerifyStatement(ChildPath(LDirectory, LFields[0] + '.txt'), LFields);
  end;
end;

procedure VerifyQuotas(const AClaims: TTable);
var
  LPairs: TStringList;
  LCounts: array[Low(CategoryNames)..High(CategoryNames), 0..1] of Integer;
  LFields: TFields;
  I: Integer;
begin
  FillChar(LCounts, SizeOf(LCounts), 0);
  LPairs := TStringList.Create;
  try
    LPairs.Sorted := True;
    LPairs.Duplicates := dupError;
    for LFields in AClaims do
    begin
      LPairs.Add(LFields[2] + #9 + LFields[4]);
      Require((LFields[5] = 'reduces') or (LFields[5] = 'worsens'), 'Invalid direction');
      for I := Low(CategoryNames) to High(CategoryNames) do
      begin
        if CategoryNames[I] = LFields[1] then
        begin
          Inc(LCounts[I, Ord(LFields[5] = 'worsens')]);
        end;
      end;
    end;
  finally
    LPairs.Free;
  end;
  for I := Low(CategoryNames) to High(CategoryNames) do
  begin
    Require((LCounts[I, 0] = ClaimsPerDirection) and (LCounts[I, 1] = ClaimsPerDirection),
      'Direction quota differs for ' + CategoryNames[I]);
  end;
end;

procedure Verify(const ADirectory, AVocabulary: String);
var
  LFreezePath: String;
  LSeedDocument: String;
  LSeedFields: TFields;
  LSeed: Cardinal;
  LClaims: TTable;
begin
  LFreezePath := ChildPath(ADirectory, 'freeze.tsv');
  Require(ReadUtf8(ChildPath(ADirectory, 'freeze.sha256')) = FileHash(LFreezePath) + #10,
    'Freeze digest differs');
  LSeedDocument := ReadUtf8(ChildPath(ADirectory, 'seed.txt'));
  LSeedFields := Split(LSeedDocument, #10);
  Require(Copy(LSeedFields[0], 1, 5) = 'seed=', 'Invalid seed.txt');
  LSeed := SeedValue(Copy(LSeedFields[0], 6, MaxInt));
  Require(LSeedDocument = SeedText(AVocabulary, LSeed), 'Seed or vocabulary metadata differs');
  LClaims := BuildClaims(AVocabulary, LSeed);
  VerifyQuotas(LClaims);
  Require(ReadUtf8(LFreezePath) = FreezeText(LClaims), 'Freeze cannot be reproduced from its inputs');
  VerifyFiles(ADirectory, LClaims);
end;

procedure RequireFresh(const ADirectory: String);
var
  LArtifact: String;
  LPath: String;
begin
  for LArtifact in Artifacts do
  begin
    LPath := ChildPath(ADirectory, LArtifact);
    Require(not FileExists(LPath) and not DirectoryExists(LPath),
      'Generation would overwrite an existing artifact: ' + LPath);
  end;
end;

procedure RemoveStage(const AStage: String; const AClaims: TTable);
var
  LDirectory: String;
  LFields: TFields;
  I: Integer;
begin
  LDirectory := ChildPath(AStage, 'statements');
  if DirectoryExists(LDirectory) then
  begin
    for LFields in AClaims do
    begin
      DeleteFile(ChildPath(LDirectory, LFields[0] + '.txt'));
    end;
    RemoveDir(LDirectory);
  end;
  for I := Low(Artifacts) to High(Artifacts) - 1 do
  begin
    DeleteFile(ChildPath(AStage, Artifacts[I]));
  end;
  RemoveDir(AStage);
end;

procedure Generate(const ADirectory: String; const ASeed: Cardinal);
var
  LStage: String;
  LStatementDir: String;
  LFreeze: String;
  LMetadata: String;
  LClaims: TTable;
  LFields: TFields;
  LLastPublished: Integer;
  I: Integer;
begin
  RequireFresh(ADirectory);
  LMetadata := SeedText(ADirectory, ASeed);
  LClaims := BuildClaims(ADirectory, ASeed);
  LStage := ChildPath(ADirectory, '.statement-generation');
  Require(CreateDir(LStage), 'Cannot acquire generation staging directory: ' + LStage);
  LLastPublished := -1;
  try
    LStatementDir := ChildPath(LStage, 'statements');
    Require(CreateDir(LStatementDir), 'Cannot create staged statements directory');
    for LFields in LClaims do
    begin
      WriteUtf8(ChildPath(LStatementDir, LFields[0] + '.txt'), StatementText(LFields));
    end;
    LFreeze := ChildPath(LStage, 'freeze.tsv');
    WriteUtf8(LFreeze, FreezeText(LClaims));
    WriteUtf8(ChildPath(LStage, 'freeze.sha256'), FileHash(LFreeze) + #10);
    WriteUtf8(ChildPath(LStage, 'seed.txt'), LMetadata);
    Verify(LStage, ADirectory);
    RequireFresh(ADirectory);
    for I := Low(Artifacts) to High(Artifacts) do
    begin
      Require(RenameFile(ChildPath(LStage, Artifacts[I]), ChildPath(ADirectory, Artifacts[I])),
        'Could not publish ' + Artifacts[I]);
      LLastPublished := I;
    end;
  except
    for I := LLastPublished downto Low(Artifacts) do
    begin
      Require(RenameFile(ChildPath(ADirectory, Artifacts[I]), ChildPath(LStage, Artifacts[I])),
        'Could not roll back publication of ' + Artifacts[I]);
    end;
    RemoveStage(LStage, LClaims);
    raise;
  end;
  Require(RemoveDir(LStage), 'Could not remove empty staging directory: ' + LStage);
end;

procedure Run;
var
  LCommand: String;
  LDirectory: String;
  LSeed: Cardinal;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Require(ParamCount >= 2, 'Usage: statement-tool generate <dir> [seed] | verify <dir>');
  LCommand := ParamStr(1);
  LDirectory := ExpandFileName(ParamStr(2));
  if LCommand = 'generate' then
  begin
    Require(ParamCount <= 3, 'Usage: statement-tool generate <dir> [seed]');
    LSeed := DefaultSeed;
    if ParamCount = 3 then
    begin
      LSeed := SeedValue(ParamStr(3));
    end;
    Generate(LDirectory, LSeed);
  end
  else if LCommand = 'verify' then
  begin
    Require(ParamCount = 2, 'Usage: statement-tool verify <dir>');
    Verify(LDirectory, LDirectory);
  end
  else
  begin
    raise EArgumentException.Create('Unknown command: ' + LCommand);
  end;
  WriteLn('Verified 1000 statements. SHA-256 ', FileHash(ChildPath(LDirectory, 'freeze.tsv')));
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
