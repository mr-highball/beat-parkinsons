{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentReview;

{$mode delphi}
{$H+}

uses
  Classes, Generics.Collections, SysUtils, FPSha256, foodexperiment.confidence
  {$ifdef windows}, Windows{$endif};

const
  ClaimCount = 1000;
  FreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  ReviewHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9 +
    'search_record'#9'local_verdict';
  QueryHeader = 'query_id'#9'provider'#9'searched_on'#9'query'#9'result_count'#9 +
    'screened_count'#9'status'#9'notes';
  FieldLabels: array[0..11] of String = (
    'ID:', 'Category:', 'Ingredient:', 'Preparation:', 'Symptom:', 'Direction:', 'Statement:',
    'Verdict:', 'Confidence:', 'Rationale:', 'Local references:', 'Search record:');
  Lf = #10;

type
  TVerdict = (vUnknown, vMaybeTrue, vMaybeFalse, vTrue, vFalse);
  TCategory = (cFood, cHerb, cSpice, cOil);
  TDirection = (dReduces, dWorsens);
  TTextFields = TArray<UTF8String>;
  TClaim = record
    Fields: TTextFields;
    Category: TCategory;
    Direction: TDirection;
  end;
  TClaims = array[1..ClaimCount] of TClaim;
  TReview = record
    Seen: Boolean;
    Verdict: TVerdict;
    Confidence: Currency;
    Rationale: UTF8String;
    References: UTF8String;
    SearchRecord: UTF8String;
    LocalVerdict: TVerdict;
  end;
  TReviews = array[1..ClaimCount] of TReview;
  TBaseline = array[1..ClaimCount] of UTF8String;
  TQueries = TDictionary<UTF8String, UTF8String>;
  TCounts = array[TVerdict] of Integer;
  TQuotaCounts = array[TCategory, TDirection] of Integer;
  TStratifiedCounts = array[TCategory, TDirection] of TCounts;
  TReviewInputs = record
    FreezeText: UTF8String;
    FreezeHash: UTF8String;
    Queries: UTF8String;
    Reviews: UTF8String;
  end;

const
  VerdictNames: array[TVerdict] of String = ('Unknown', 'Maybe True', 'Maybe False', 'True', 'False');
  CategoryNames: array[TCategory] of String = ('food', 'herb', 'spice', 'oil');
  DirectionNames: array[TDirection] of String = ('reduces', 'worsens');

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

function JoinPath(const ADirectory, AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ADirectory) + AName;
end;

function ClaimId(AIndex: Integer): String;
begin
  Result := Format('%.4d', [AIndex]);
end;

function ClaimFile(const ADirectory: String; AIndex: Integer): String;
begin
  Result := JoinPath(ADirectory, ClaimId(AIndex) + '.txt');
end;

function ReadText(const APath: String): UTF8String;
var
  LStream: TFileStream;
  LRoundTrip: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= High(Integer), 'Review input is too large: ' + APath);
    SetLength(Result, Integer(LStream.Size));
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
  Require((Copy(Result, 1, 3) <> #$EF#$BB#$BF) and (Pos(#0, Result) = 0),
    'Unexpected BOM or NUL: ' + APath);
  LRoundTrip := UTF8Encode(UTF8Decode(Result));
  Require(LRoundTrip = Result, 'Invalid UTF-8: ' + APath);
end;

procedure WriteText(const APath: String; const AText: UTF8String);
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

function Split(const AText: UTF8String; ADelimiter: AnsiChar): TTextFields;
var
  LIndex: Integer;
  LStart: Integer;
  LField: Integer;
  LCount: Integer;
begin
  LCount := 1;
  for LIndex := 1 to Length(AText) do
  begin
    if AText[LIndex] = ADelimiter then
    begin
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
  LStart := 1;
  LField := 0;
  for LIndex := 1 to Length(AText) do
  begin
    if AText[LIndex] = ADelimiter then
    begin
      Result[LField] := Copy(AText, LStart, LIndex - LStart);
      Inc(LField);
      LStart := LIndex + 1;
    end;
  end;
  Result[LField] := Copy(AText, LStart, MaxInt);
end;

function LinesOf(const AText: UTF8String; const ALabel: String): TTextFields;
begin
  Require((AText <> '') and (AText[Length(AText)] = Lf) and (Pos(#13, AText) = 0),
    ALabel + ' must use LF and end with a newline.');
  Result := Split(Copy(AText, 1, Length(AText) - 1), Lf);
end;

function ReadInteger(const AText: UTF8String; const ALabel: String;
  AMinimum, AMaximum: Integer): Integer;
var
  LCharacter: AnsiChar;
begin
  Require(AText <> '', 'Missing ' + ALabel);
  for LCharacter in AText do
  begin
    Require(LCharacter in ['0'..'9'], 'Invalid ' + ALabel + ': ' + String(AText));
  end;
  Require(TryStrToInt(String(AText), Result) and (Result >= AMinimum) and (Result <= AMaximum),
    'Out-of-range ' + ALabel + ': ' + String(AText));
end;

function ReadVerdict(const AValue: UTF8String; const ALabel: String): TVerdict;
var
  LVerdict: TVerdict;
begin
  for LVerdict := Low(TVerdict) to High(TVerdict) do
  begin
    if AValue = VerdictNames[LVerdict] then
    begin
      Exit(LVerdict);
    end;
  end;
  raise Exception.Create(ALabel + ': invalid verdict ' + String(AValue));
end;

function ReadCategory(const AValue: UTF8String): TCategory;
var
  LCategory: TCategory;
begin
  for LCategory := Low(TCategory) to High(TCategory) do
  begin
    if AValue = CategoryNames[LCategory] then
    begin
      Exit(LCategory);
    end;
  end;
  raise Exception.Create('Invalid frozen category: ' + String(AValue));
end;

function ReadDirection(const AValue: UTF8String): TDirection;
var
  LDirection: TDirection;
begin
  for LDirection := Low(TDirection) to High(TDirection) do
  begin
    if AValue = DirectionNames[LDirection] then
    begin
      Exit(LDirection);
    end;
  end;
  raise Exception.Create('Invalid frozen direction: ' + String(AValue));
end;

function ClaimNumber(const AValue: UTF8String): Integer;
begin
  Result := ReadInteger(AValue, 'claim ID', 1, ClaimCount);
  Require(AValue = ClaimId(Result), 'Claim ID must have four digits: ' + String(AValue));
end;

procedure ReadFreeze(const AInputs: TReviewInputs; out AClaims: TClaims);
var
  LLines: TTextFields;
  LFields: TTextFields;
  LBytes: TBytes;
  LHash: AnsiString;
  LIndex: Integer;
  LField: Integer;
  LPairs: TDictionary<UTF8String, Boolean>;
  LQuotas: TQuotaCounts;
  LCategory: TCategory;
  LDirection: TDirection;
begin
  Require(AInputs.FreezeText <> '', 'Frozen claim ledger is empty.');
  SetLength(LBytes, Length(AInputs.FreezeText));
  Move(AInputs.FreezeText[1], LBytes[0], Length(LBytes));
  TSHA256.DigestHexa(LBytes, LHash);
  Require(AInputs.FreezeHash = LowerCase(LHash) + Lf, 'Frozen claim digest mismatch.');
  LLines := LinesOf(AInputs.FreezeText, 'freeze.tsv');
  Require((Length(LLines) = ClaimCount + 1) and (LLines[0] = FreezeHeader),
    'Invalid frozen header or claim count.');
  LPairs := TDictionary<UTF8String, Boolean>.Create;
  try
    LQuotas := Default(TQuotaCounts);
    for LIndex := 1 to ClaimCount do
    begin
      LFields := Split(LLines[LIndex], #9);
      Require((Length(LFields) = 7) and (LFields[0] = ClaimId(LIndex)),
        'Invalid frozen row ' + ClaimId(LIndex));
      for LField := 1 to High(LFields) do
      begin
        Require(Trim(LFields[LField]) <> '', 'Empty frozen field in ' + ClaimId(LIndex));
      end;
      AClaims[LIndex].Fields := LFields;
      LCategory := ReadCategory(LFields[1]);
      LDirection := ReadDirection(LFields[5]);
      AClaims[LIndex].Category := LCategory;
      AClaims[LIndex].Direction := LDirection;
      Require(not LPairs.ContainsKey(LFields[2] + #9 + LFields[4]),
        'Repeated ingredient and symptom in frozen row ' + ClaimId(LIndex));
      LPairs.Add(LFields[2] + #9 + LFields[4], True);
      Inc(LQuotas[LCategory, LDirection]);
    end;
    for LCategory := Low(TCategory) to High(TCategory) do
    begin
      for LDirection := Low(TDirection) to High(TDirection) do
      begin
        Require(LQuotas[LCategory, LDirection] = 125, 'Frozen category or direction quota mismatch.');
      end;
    end;
  finally
    LPairs.Free;
  end;
end;

procedure ReadQueries(const AText: UTF8String; AQueries: TQueries);
var
  LLines: TTextFields;
  LFields: TTextFields;
  LCharacter: AnsiChar;
  LYear: Word;
  LMonth: Word;
  LDay: Word;
  LDate: TDateTime;
  LScreened: Integer;
  LIndex: Integer;
begin
  LLines := LinesOf(AText, 'queries.tsv');
  Require(LLines[0] = QueryHeader, 'Unexpected queries.tsv header.');
  for LIndex := 1 to High(LLines) do
  begin
    LFields := Split(LLines[LIndex], #9);
    Require(Length(LFields) = 8, 'Invalid query row ' + IntToStr(LIndex + 1));
    Require(LFields[0] <> '', 'Missing query ID.');
    for LCharacter in LFields[0] do
    begin
      Require(LCharacter in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-'],
        'Invalid query ID: ' + String(LFields[0]));
    end;
    Require(not AQueries.ContainsKey(LFields[0]), 'Repeated query ID: ' + String(LFields[0]));
    Require((Trim(LFields[1]) <> '') and (Trim(LFields[3]) <> ''), 'Missing query or provider.');
    Require((Length(LFields[2]) = 10) and (LFields[2][5] = '-') and (LFields[2][8] = '-'),
      'Expected ISO date for query ' + String(LFields[0]));
    LYear := ReadInteger(Copy(LFields[2], 1, 4), 'search year', 1, 9999);
    LMonth := ReadInteger(Copy(LFields[2], 6, 2), 'search month', 1, 12);
    LDay := ReadInteger(Copy(LFields[2], 9, 2), 'search day', 1, 31);
    Require(TryEncodeDate(LYear, LMonth, LDay, LDate), 'Invalid query date: ' + String(LFields[2]));
    LScreened := ReadInteger(LFields[5], 'screened count', 0, 20);
    if LFields[4] <> '' then
    begin
      ReadInteger(LFields[4], 'result count', LScreened, High(Integer));
    end;
    Require(LFields[6] = 'Completed', 'Incomplete query: ' + String(LFields[0]));
    AQueries.Add(LFields[0], LowerCase(Trim(LFields[1]) + #9 + Trim(LFields[3])));
  end;
end;

function ValidateReferences(const AReferences: UTF8String; const ARoot, AExperiment: String): Boolean;
var
  LReference: UTF8String;
  LPath: UTF8String;
  LPart: UTF8String;
  LHashAt: Integer;
  LExperimentPrefix: UTF8String;
begin
  Result := False;
  if AReferences = '' then
  begin
    Exit;
  end;
  LExperimentPrefix := 'experiments/' + UTF8String(ExtractFileName(AExperiment)) + '/';
  for LReference in Split(AReferences, '|') do
  begin
    LPath := LReference;
    LHashAt := Pos('#', LPath);
    if LHashAt > 0 then
    begin
      Require(LHashAt < Length(LPath), 'Empty source locator: ' + String(LReference));
      LPath := Copy(LPath, 1, LHashAt - 1);
    end;
    Require((Pos('\', LPath) = 0) and (Pos(':', LPath) = 0) and
      ((Copy(LPath, 1, 9) = 'research/') or
        (Copy(LPath, 1, Length(LExperimentPrefix)) = LExperimentPrefix)),
      'Expected a repo-relative research or experiment reference: ' + String(LReference));
    for LPart in Split(LPath, '/') do
    begin
      Require((LPart <> '') and (LPart <> '.') and (LPart <> '..') and (LPart = Trim(LPart)),
        'Invalid source path: ' + String(LReference));
    end;
    Require(FileExists(JoinPath(ARoot, StringReplace(String(LPath), '/', PathDelim, [rfReplaceAll]))),
      'Missing local reference: ' + String(LReference));
    Result := Result or (Copy(LPath, 1, 9) = 'research/');
  end;
end;

function NeedsExternal(AVerdict: TVerdict): Boolean;
begin
  Result := AVerdict in [vUnknown, vMaybeTrue, vMaybeFalse];
end;

procedure ValidateSearch(const AId, ARecord: UTF8String; ALocalVerdict: TVerdict; AQueries: TQueries);
var
  LSeen: TDictionary<UTF8String, Boolean>;
  LQueryId: UTF8String;
  LQueryKey: UTF8String;
begin
  if ARecord = '' then
  begin
    Require(not NeedsExternal(ALocalVerdict), String(AId) + ' requires two external queries.');
    Exit;
  end;
  LSeen := TDictionary<UTF8String, Boolean>.Create;
  try
    for LQueryId in Split(ARecord, '|') do
    begin
      Require(AQueries.TryGetValue(LQueryId, LQueryKey), String(AId) + ' references missing query ' +
        String(LQueryId));
      Require(not LSeen.ContainsKey(LQueryKey), String(AId) + ' repeats an external search.');
      LSeen.Add(LQueryKey, True);
    end;
    if NeedsExternal(ALocalVerdict) then
    begin
      Require(LSeen.Count >= 2, String(AId) + ' requires two distinct external queries.');
    end;
  finally
    LSeen.Free;
  end;
end;

procedure ReadReviews(const AText: UTF8String; const ARoot, AExperiment: String; AQueries: TQueries;
  out AReviews: TReviews);
var
  LLines: TTextFields;
  LFields: TTextFields;
  LIndex: Integer;
  LClaim: Integer;
  LReview: TReview;
  LHasResearch: Boolean;
begin
  AReviews := Default(TReviews);
  LLines := LinesOf(AText, 'verdicts.tsv');
  Require((Length(LLines) = ClaimCount + 1) and (LLines[0] = ReviewHeader),
    'Invalid verdict header or verdict count.');
  for LIndex := 1 to High(LLines) do
  begin
    LFields := Split(LLines[LIndex], #9);
    Require(Length(LFields) = 7, 'Invalid verdict row ' + IntToStr(LIndex + 1));
    LClaim := ClaimNumber(LFields[0]);
    Require(not AReviews[LClaim].Seen, 'Repeated verdict for ' + String(LFields[0]));
    LReview := Default(TReview);
    LReview.Seen := True;
    LReview.Verdict := ReadVerdict(LFields[1], String(LFields[0]));
    LReview.Confidence := ReadReviewConfidence(String(LFields[2]), VerdictNames[LReview.Verdict],
      String(LFields[0]));
    LReview.Rationale := LFields[3];
    LReview.References := LFields[4];
    LReview.SearchRecord := LFields[5];
    LReview.LocalVerdict := ReadVerdict(LFields[6], String(LFields[0]) + ' local verdict');
    Require(Trim(LReview.Rationale) <> '', 'Missing rationale for ' + String(LFields[0]));
    LHasResearch := ValidateReferences(LReview.References, ARoot, AExperiment);
    if LReview.Verdict <> vUnknown then
    begin
      Require(LHasResearch, 'Directional verdict needs a local research source: ' +
        String(LFields[0]));
    end;
    ValidateSearch(LFields[0], LReview.SearchRecord, LReview.LocalVerdict, AQueries);
    AReviews[LClaim] := LReview;
  end;
end;

function RenderClaimPrefix(const AClaim: TClaim): UTF8String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AClaim.Fields) do
  begin
    Result := Result + UTF8String(FieldLabels[LIndex]) + ' ' + AClaim.Fields[LIndex] + Lf;
  end;
end;

function RenderField(ALabel: Integer; const AValue: UTF8String): UTF8String;
begin
  Result := UTF8String(FieldLabels[ALabel]);
  if AValue <> '' then
  begin
    Result := Result + ' ' + AValue;
  end;
  Result := Result + Lf;
end;

function RenderReviewed(const AClaim: TClaim; const AReview: TReview): UTF8String;
begin
  Result := RenderClaimPrefix(AClaim) +
    RenderField(7, UTF8String(VerdictNames[AReview.Verdict])) +
    RenderField(8, UTF8String(ReviewConfidenceText(AReview.Confidence))) +
    RenderField(9, AReview.Rationale) +
    RenderField(10, AReview.References) +
    RenderField(11, AReview.SearchRecord);
end;

function ReadDirectory(const APath: String): Integer;
var
  LEntry: TSearchRec;
  LId: Integer;
begin
  Require(DirectoryExists(APath), 'Missing statement directory: ' + APath);
  Result := 0;
  if FindFirst(JoinPath(APath, '*'), faAnyFile, LEntry) = 0 then
  begin
    try
      repeat
        if (LEntry.Name = '.') or (LEntry.Name = '..') then
        begin
          Continue;
        end;
        Require(((LEntry.Attr and faDirectory) = 0) and (Length(LEntry.Name) = 8) and
          (Copy(LEntry.Name, 5, 4) = '.txt'), 'Unexpected item in statement directory: ' +
          JoinPath(APath, LEntry.Name));
        LId := ClaimNumber(UTF8String(Copy(LEntry.Name, 1, 4)));
        Require(LEntry.Name = ClaimId(LId) + '.txt', 'Invalid statement filename: ' + LEntry.Name);
        Inc(Result);
      until FindNext(LEntry) <> 0;
    finally
      SysUtils.FindClose(LEntry);
    end;
  end;
end;

procedure CheckStatement(const AText: UTF8String; const AClaim: TClaim);
var
  LLines: TTextFields;
  LPrefix: UTF8String;
  LIndex: Integer;
begin
  LLines := LinesOf(AText, String(AClaim.Fields[0]) + '.txt');
  Require(Length(LLines) = Length(FieldLabels), 'Expected twelve fields in ' +
    String(AClaim.Fields[0]));
  LPrefix := RenderClaimPrefix(AClaim);
  Require(Copy(AText, 1, Length(LPrefix)) = LPrefix, 'Frozen statement was edited: ' +
    String(AClaim.Fields[0]));
  for LIndex := 7 to High(FieldLabels) do
  begin
    Require((LLines[LIndex] = FieldLabels[LIndex]) or
      (Copy(LLines[LIndex], 1, Length(FieldLabels[LIndex]) + 1) = FieldLabels[LIndex] + ' '),
      'Invalid review field in ' + String(AClaim.Fields[0]) + ': ' + FieldLabels[LIndex]);
  end;
end;

procedure CheckStatements(const APath: String; const AClaims: TClaims; const AReviews: TReviews;
  ARequireReviewed: Boolean; out ABaseline: TBaseline);
var
  LIndex: Integer;
begin
  Require(ReadDirectory(APath) = ClaimCount, 'Expected exactly 1,000 statement files: ' + APath);
  for LIndex := 1 to ClaimCount do
  begin
    ABaseline[LIndex] := ReadText(ClaimFile(APath, LIndex));
    CheckStatement(ABaseline[LIndex], AClaims[LIndex]);
    if ARequireReviewed then
    begin
      Require(ABaseline[LIndex] = RenderReviewed(AClaims[LIndex], AReviews[LIndex]),
        'Statement review differs from the verdict ledger: ' + ClaimId(LIndex));
    end;
  end;
end;

procedure RemoveGeneratedDirectory(const APath: String);
var
  LIndex: Integer;
  LPath: String;
begin
  if not DirectoryExists(APath) then
  begin
    Exit;
  end;
  ReadDirectory(APath);
  for LIndex := 1 to ClaimCount do
  begin
    LPath := ClaimFile(APath, LIndex);
    if FileExists(LPath) then
    begin
      Require(SysUtils.DeleteFile(LPath), 'Cannot remove generated review file: ' + LPath);
    end;
  end;
  Require(RemoveDir(APath), 'Cannot remove generated review directory: ' + APath);
end;

function ReadInputs(const AExperiment: String): TReviewInputs;
begin
  Result.FreezeText := ReadText(JoinPath(AExperiment, 'freeze.tsv'));
  Result.FreezeHash := ReadText(JoinPath(AExperiment, 'freeze.sha256'));
  Result.Queries := ReadText(JoinPath(AExperiment, 'queries.tsv'));
  Result.Reviews := ReadText(JoinPath(AExperiment, 'verdicts.tsv'));
end;

procedure CheckUnchanged(const AExperiment: String; const AInputs: TReviewInputs);
var
  LNow: TReviewInputs;
begin
  LNow := ReadInputs(AExperiment);
  Require((LNow.FreezeText = AInputs.FreezeText) and (LNow.FreezeHash = AInputs.FreezeHash) and
    (LNow.Queries = AInputs.Queries) and (LNow.Reviews = AInputs.Reviews),
    'Freeze or review inputs changed during application. Run apply again.');
end;

procedure PublishReviews(const AExperiment: String; const AInputs: TReviewInputs;
  const AClaims: TClaims; const AReviews: TReviews; const ABaseline: TBaseline);
var
  LPath: String;
  LCandidate: String;
  LBackup: String;
  LIndex: Integer;
  LValidated: TBaseline;
begin
  LPath := JoinPath(AExperiment, 'statements');
  LCandidate := JoinPath(AExperiment, 'statements.review-next');
  LBackup := JoinPath(AExperiment, 'statements.review-backup');
  RemoveGeneratedDirectory(LCandidate);
  RemoveGeneratedDirectory(LBackup);
  Require(CreateDir(LCandidate), 'Cannot create review staging directory: ' + LCandidate);
  try
    for LIndex := 1 to ClaimCount do
    begin
      WriteText(ClaimFile(LCandidate, LIndex), RenderReviewed(AClaims[LIndex], AReviews[LIndex]));
    end;
    CheckStatements(LCandidate, AClaims, AReviews, True, LValidated);
    CheckUnchanged(AExperiment, AInputs);
    Require(ReadDirectory(LPath) = ClaimCount, 'Statement set changed during application.');
    for LIndex := 1 to ClaimCount do
    begin
      Require(ReadText(ClaimFile(LPath, LIndex)) = ABaseline[LIndex],
        'Statement changed during application: ' + ClaimId(LIndex));
    end;
    Require(RenameFile(LPath, LBackup), 'Cannot preserve the baseline statement directory.');
    if not RenameFile(LCandidate, LPath) then
    begin
      Require(RenameFile(LBackup, LPath), 'Publication failed. Baseline remains at ' + LBackup);
      raise Exception.Create('Publication failed. Baseline statements were restored.');
    end;
    RemoveGeneratedDirectory(LBackup);
  finally
    RemoveGeneratedDirectory(LCandidate);
  end;
end;

procedure RestoreInterruptedPublish(const AExperiment: String);
var
  LPath: String;
  LBackup: String;
begin
  LPath := JoinPath(AExperiment, 'statements');
  LBackup := JoinPath(AExperiment, 'statements.review-backup');
  if not DirectoryExists(LPath) and DirectoryExists(LBackup) then
  begin
    Require(ReadDirectory(LBackup) = ClaimCount, 'Incomplete statement backup: ' + LBackup);
    Require(RenameFile(LBackup, LPath), 'Cannot restore interrupted statement publication.');
  end;
end;

procedure ReplaceText(const APath: String; const AText: UTF8String);
var
  LTemporary: String;
begin
  LTemporary := APath + '.review-next';
  WriteText(LTemporary, AText);
  try
    {$ifdef windows}
    Require(MoveFileExW(PWideChar(UnicodeString(LTemporary)), PWideChar(UnicodeString(APath)),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH),
      'Cannot publish summary: ' + APath);
    {$else}
    Require(RenameFile(LTemporary, APath), 'Cannot publish summary: ' + APath);
    {$endif}
  finally
    if FileExists(LTemporary) then
    begin
      Require(SysUtils.DeleteFile(LTemporary), 'Cannot remove temporary summary: ' + LTemporary);
    end;
  end;
end;

procedure WriteSummary(const AExperiment: String; const AClaims: TClaims; const AReviews: TReviews;
  AQueryCount: Integer; const AFreezeHash: UTF8String);
var
  LCounts: TCounts;
  LByGroup: TStratifiedCounts;
  LLocal: TCounts;
  LIndex: Integer;
  LExternalClaims: Integer;
  LVerdict: TVerdict;
  LCategory: TCategory;
  LDirection: TDirection;
  LTable: UTF8String;
  LManifest: UTF8String;
  LFindings: String;
  LCoverage: String;
  LId: UTF8String;
begin
  LCounts := Default(TCounts);
  LLocal := Default(TCounts);
  LByGroup := Default(TStratifiedCounts);
  LExternalClaims := 0;
  for LIndex := 1 to ClaimCount do
  begin
    LVerdict := AReviews[LIndex].Verdict;
    Inc(LCounts[LVerdict]);
    Inc(LLocal[AReviews[LIndex].LocalVerdict]);
    Inc(LByGroup[AClaims[LIndex].Category, AClaims[LIndex].Direction][LVerdict]);
    if AReviews[LIndex].SearchRecord <> '' then
    begin
      Inc(LExternalClaims);
    end;
  end;
  LManifest := '# Parkinson''s food thought experiment results' + Lf + Lf +
    'Verdicts are tracked for **1,000** frozen statements. Confidence values are reviewer judgments.' + Lf + Lf +
    '- Frozen SHA-256 `' + UTF8String(Trim(AFreezeHash)) + '`' + Lf +
    '- [Statement verdict ledger](verdicts.tsv)' + Lf +
    '- [First-pass search ledger](queries.tsv) with ' + UTF8String(IntToStr(AQueryCount)) +
      ' completed records and ' + UTF8String(IntToStr(LExternalClaims)) + ' statements covered' + Lf;
  LCoverage := JoinPath(AExperiment, 'local-coverage.tsv');
  if FileExists(LCoverage) then
  begin
    LManifest := LManifest + '- [Local file coverage](local-coverage.tsv)' + Lf;
  end;
  if FileExists(JoinPath(AExperiment, 'local-screening.tsv')) then
  begin
    LManifest := LManifest + '- [Local candidate screening](local-screening.tsv)' + Lf;
  end;
  LManifest := LManifest + '- [Counts by category and claim direction](results-summary.tsv)' + Lf + Lf +
    '## Verdict counts' + Lf + Lf +
    '| Verdict | Local review | Current verdict |' + Lf +
    '| --- | ---: | ---: |' + Lf;
  LTable := 'stage'#9'category'#9'direction'#9'verdict'#9'count' + Lf;
  for LVerdict := Low(TVerdict) to High(TVerdict) do
  begin
    LManifest := LManifest + '| ' + UTF8String(VerdictNames[LVerdict]) + ' | ' +
      UTF8String(IntToStr(LLocal[LVerdict])) + ' | ' + UTF8String(IntToStr(LCounts[LVerdict])) +
      ' |' + Lf;
    LTable := LTable + 'local'#9'all'#9'all'#9 + UTF8String(VerdictNames[LVerdict]) + #9 +
      UTF8String(IntToStr(LLocal[LVerdict])) + Lf +
      'final'#9'all'#9'all'#9 + UTF8String(VerdictNames[LVerdict]) + #9 +
      UTF8String(IntToStr(LCounts[LVerdict])) + Lf;
    for LCategory := Low(TCategory) to High(TCategory) do
    begin
      for LDirection := Low(TDirection) to High(TDirection) do
      begin
        LTable := LTable + 'final'#9 + UTF8String(CategoryNames[LCategory]) + #9 +
          UTF8String(DirectionNames[LDirection]) + #9 + UTF8String(VerdictNames[LVerdict]) + #9 +
          UTF8String(IntToStr(LByGroup[LCategory, LDirection][LVerdict])) + Lf;
      end;
    end;
  end;
  LFindings := JoinPath(AExperiment, 'findings.md');
  if FileExists(LFindings) then
  begin
    LManifest := LManifest + Lf + UTF8String(Trim(ReadText(LFindings))) + Lf;
  end;
  LManifest := LManifest + Lf + '## Directional verdicts' + Lf + Lf;
  if LCounts[vTrue] + LCounts[vFalse] + LCounts[vMaybeTrue] + LCounts[vMaybeFalse] = 0 then
  begin
    LManifest := LManifest + 'Every statement remains Unknown under the experiment rules.' + Lf;
  end
  else
  begin
    for LIndex := 1 to ClaimCount do
    begin
      LVerdict := AReviews[LIndex].Verdict;
      if LVerdict = vUnknown then
      begin
        Continue;
      end;
      LId := UTF8String(ClaimId(LIndex));
      LManifest := LManifest + '- [' + LId + '](statements/' + LId + '.txt) **' +
        UTF8String(VerdictNames[LVerdict]) + '** (' +
        UTF8String(ReviewConfidenceText(AReviews[LIndex].Confidence)) + '%) ' +
        AClaims[LIndex].Fields[6] + Lf;
    end;
  end;
  ReplaceText(JoinPath(AExperiment, 'results-summary.tsv'), LTable);
  ReplaceText(JoinPath(AExperiment, 'manifest.md'), LManifest);
end;

procedure Run(const ACommand, AExperiment: String);
var
  LRoot: String;
  LStatementPath: String;
  LInputs: TReviewInputs;
  LClaims: TClaims;
  LReviews: TReviews;
  LQueries: TQueries;
  LBaseline: TBaseline;
  LLock: String;
begin
  Require((ACommand = 'apply') or (ACommand = 'verify') or (ACommand = 'summary'),
    'Expected apply, verify, or summary.');
  Require(DirectoryExists(AExperiment), 'Experiment directory does not exist: ' + AExperiment);
  Require(ExtractFileName(ExtractFileDir(AExperiment)) = 'experiments',
    'Pass a directory directly beneath the repo''s experiments folder.');
  LRoot := ExtractFileDir(ExtractFileDir(AExperiment));
  LStatementPath := JoinPath(AExperiment, 'statements');
  LLock := JoinPath(AExperiment, '.review-lock');
  Require(CreateDir(LLock), 'Review is busy. After an interrupted process, remove the empty lock ' +
    'only once no review tool is running: ' + LLock);
  LQueries := TQueries.Create;
  try
    if ACommand = 'apply' then
    begin
      RestoreInterruptedPublish(AExperiment);
    end;
    LInputs := ReadInputs(AExperiment);
    ReadFreeze(LInputs, LClaims);
    ReadQueries(LInputs.Queries, LQueries);
    ReadReviews(LInputs.Reviews, LRoot, AExperiment, LQueries, LReviews);
    CheckStatements(LStatementPath, LClaims, LReviews, ACommand <> 'apply', LBaseline);
    if ACommand = 'apply' then
    begin
      PublishReviews(AExperiment, LInputs, LClaims, LReviews, LBaseline);
    end;
    if ACommand = 'summary' then
    begin
      CheckUnchanged(AExperiment, LInputs);
      WriteSummary(AExperiment, LClaims, LReviews, LQueries.Count, LInputs.FreezeHash);
    end;
    WriteLn(ACommand, ' validated ', ClaimCount, ' frozen claims and ', LQueries.Count,
      ' completed external query records.');
  finally
    LQueries.Free;
    Require(RemoveDir(LLock), 'Cannot release review lock: ' + LLock);
  end;
end;

begin
  try
    Require(ParamCount = 2, 'Usage: foodexperiment.review <apply|verify|summary> <experiment-dir>');
    Run(ParamStr(1), ExcludeTrailingPathDelimiter(ExpandFileName(ParamStr(2))));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
