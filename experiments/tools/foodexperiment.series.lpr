{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentSeries;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Windows, Generics.Collections, FPSHA256, foodexperiment.externaldata;

const
  OriginalName = '1000_see_what_sticks_food';
  OriginalHash = '0f1e21eac0ab9d28d12cac82656fe6bc9dda037f658631369c6a76747eda242f';
  IngredientHeader = 'category'#9'ingredient'#9'forms'#9'aliases';
  SymptomHeader = 'symptom'#9'aliases';
  PairHeader = 'round'#9'pair_id'#9'category'#9'ingredient'#9'symptom';
  FreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  Categories: array[0..3] of String = ('food', 'herb', 'spice', 'oil');
  InputFiles: array[0..2] of String = ('ingredients.tsv', 'symptoms.tsv',
    'additional-ingredients.tsv');
  FieldNames: array[0..11] of String = ('ID', 'Category', 'Ingredient',
    'Preparation', 'Symptom', 'Direction', 'Statement', 'Verdict', 'Confidence',
    'Rationale', 'Local references', 'Search record');
  FirstRound = 2;
  LastRound = 7;
  StandardCount = 1000;
  FinalCount = 930;
  FirstSeed = 409280552;
  Algorithm = 'xorshift32-rejection-fisher-yates-assigned-pairs-v1';

type
  TIngredient = record
    Name: String;
    SortName: String;
    Category: Integer;
    Forms: TFields;
    Aliases: String;
  end;
  TSymptom = record
    Name: String;
    SortName: String;
    Aliases: String;
  end;
  TPair = record
    Ingredient: Integer;
    Symptom: Integer;
  end;
  TPairArray = array of TPair;
  TStringsByRow = array of String;
  TCategoryCounts = array[0..3] of Integer;
  TNameMap = TDictionary<String, Integer>;
  TRandom = record
    State: Cardinal;
    function Draw(ABound: Cardinal): Integer;
  end;

  TSeries = class
  private
    FRoot: String;
    FIngredients: array of TIngredient;
    FSymptoms: array of TSymptom;
    FIngredientNames: TNameMap;
    FSymptomNames: TNameMap;
    FOriginal: TDictionary<Integer, Boolean>;
    FPairs: TPairArray;
    function OriginalDir: String;
    function RoundDir(ARound: Integer): String;
    function PairId(AIngredient, ASymptom: Integer): Integer;
    procedure LoadInputs;
    procedure LoadOriginal;
    procedure Allocate;
    procedure InspectSiblings;
    function PairLines(ARound: Integer): String;
    procedure CheckReservations(const APlan, AHash: String; ARequired: Boolean);
    procedure PublishReservations(const APlan, AHash: String);
    function BuildClaims(ARound: Integer; out ACategories: TCategoryCounts): TStringsByRow;
    procedure HandleRound(ARound: Integer; const AHash: String; const AAction: String;
      out ACounts: TCategoryCounts);
  public
    constructor Create(const ARoot: String);
    destructor Destroy; override;
    procedure Run(const AAction: String);
  end;

function NormalizeString(ANormForm: Integer; ASource: PWideChar;
  ASourceLength: Integer; ADestination: PWideChar;
  ADestinationLength: Integer): Integer; stdcall; external 'Normaliz.dll';

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function Child(const ADir, AName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ADir) + AName;
end;

function ReadBytes(const APath: String): String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if Length(Result) > 0 then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
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

function TextHash(const AText: String): String;
var
  LStream: TStringStream;
  LHex: AnsiString;
begin
  LStream := TStringStream.Create(AText);
  try
    TSHA256.StreamHexa(LStream, LHex);
    Result := LowerCase(LHex);
  finally
    LStream.Free;
  end;
end;

procedure RequireFile(const APath, AExpected: String; ARequired: Boolean);
begin
  if FileExists(APath) then
  begin
    Require(ReadBytes(APath) = AExpected, 'Existing artifact differs: ' + APath);
  end
  else
  begin
    Require(not ARequired, 'Missing artifact: ' + APath);
  end;
end;

procedure Publish(const APath, ABytes: String);
var
  LTemporary: String;
  LStream: TFileStream;
begin
  if FileExists(APath) then
  begin
    RequireFile(APath, ABytes, True);
    Exit;
  end;
  LTemporary := APath + '.new';
  LStream := TFileStream.Create(LTemporary, fmCreate or fmShareExclusive);
  try
    LStream.WriteBuffer(ABytes[1], Length(ABytes));
    if not FlushFileBuffers(LStream.Handle) then
    begin
      RaiseLastOSError;
    end;
  finally
    LStream.Free;
  end;
  RequireFile(LTemporary, ABytes, True);
  if not MoveFileW(PWideChar(UTF8Decode(LTemporary)), PWideChar(UTF8Decode(APath))) then
  begin
    RaiseLastOSError;
  end;
end;

function NameKey(const AName: String): String;
const
  CNormalizationKC = 5;
  CInvariantLocale = $007F;
var
  LSource: UnicodeString;
  LNormalized: UnicodeString;
  LLower: UnicodeString;
  LLength: Integer;
  LPendingSpace: Boolean;
  LChar: WideChar;
begin
  Result := '';
  LSource := UTF8Decode(AName);
  if LSource = '' then
  begin
    Exit;
  end;
  LLength := NormalizeString(CNormalizationKC, PWideChar(LSource), Length(LSource), nil, 0);
  Require(LLength > 0, 'Invalid Unicode name: ' + AName);
  SetLength(LNormalized, LLength);
  LLength := NormalizeString(CNormalizationKC, PWideChar(LSource), Length(LSource),
    PWideChar(LNormalized), Length(LNormalized));
  Require(LLength > 0, 'Cannot normalize name: ' + AName);
  SetLength(LNormalized, LLength);
  LLength := LCMapStringW(CInvariantLocale, LCMAP_LOWERCASE, PWideChar(LNormalized),
    Length(LNormalized), nil, 0);
  Require(LLength > 0, 'Cannot size normalized name: ' + AName);
  SetLength(LLower, LLength);
  Require(LCMapStringW(CInvariantLocale, LCMAP_LOWERCASE, PWideChar(LNormalized),
    Length(LNormalized), PWideChar(LLower), Length(LLower)) = LLength,
    'Cannot fold name: ' + AName);
  LNormalized := '';
  LPendingSpace := False;
  for LChar in LLower do
  begin
    case Ord(LChar) of
      9..13, 32, $85, $A0, $1680, $2000..$200A, $2028, $2029, $202F, $205F, $3000:
        LPendingSpace := LNormalized <> '';
      else
      begin
        if LPendingSpace then
        begin
          LNormalized := LNormalized + ' ';
          LPendingSpace := False;
        end;
        LNormalized := LNormalized + LChar;
      end;
    end;
  end;
  Result := UTF8Encode(LNormalized);
end;

procedure RequireCanonical(const AName: String);
var
  LChar: Char;
begin
  Require((Trim(AName) = AName) and (AName <> '') and (Pos('  ', AName) = 0),
    'Invalid canonical name: ' + AName);
  for LChar in AName do
  begin
    Require(LChar in [#32..#126], 'Canonical name must be printable ASCII: ' + AName);
  end;
end;

function OrdinalCompare(const ALeft, ARight: String): Integer;
var
  LIndex: Integer;
  LCommonLength: Integer;
begin
  LCommonLength := Length(ALeft);
  if Length(ARight) < LCommonLength then
  begin
    LCommonLength := Length(ARight);
  end;
  for LIndex := 1 to LCommonLength do
  begin
    Result := Ord(ALeft[LIndex]) - Ord(ARight[LIndex]);
    if Result <> 0 then
    begin
      Exit;
    end;
  end;
  Result := Length(ALeft) - Length(ARight);
end;

procedure RegisterName(AMap: TNameMap; const AName: String; AIndex: Integer);
var
  LKey: String;
  LExisting: Integer;
begin
  LKey := NameKey(AName);
  Require(LKey <> '', 'Empty vocabulary name');
  if AMap.TryGetValue(LKey, LExisting) then
  begin
    Require(LExisting = AIndex, 'Ambiguous vocabulary name: ' + AName);
  end
  else
  begin
    AMap.Add(LKey, AIndex);
  end;
end;

procedure RegisterIdentity(AMap: TNameMap; const AName, AAliases: String; AIndex: Integer);
var
  LAlias: String;
begin
  RegisterName(AMap, AName, AIndex);
  if AAliases <> '' then
  begin
    for LAlias in SplitFields(AAliases, '|') do
    begin
      RegisterName(AMap, LAlias, AIndex);
    end;
  end;
end;

function ReadTable(const APath, AHeader: String): TStringList;
begin
  Result := TStringList.Create;
  try
    Result.LoadFromFile(APath, TEncoding.UTF8);
    Require((Result.Count > 0) and (Result[0] = AHeader), 'Invalid table: ' + APath);
  except
    Result.Free;
    raise;
  end;
end;

function IngredientRow(const ARow: String): String;
begin
  Result := ARow;
  // The combined scaffold omits the final empty aliases field on hazelnut oil.
  if Length(SplitFields(ARow, #9)) = 3 then
  begin
    Result := ARow + #9;
  end;
end;

function CategoryIndex(const ACategory: String): Integer;
begin
  for Result := Low(Categories) to High(Categories) do
  begin
    if Categories[Result] = ACategory then
    begin
      Exit;
    end;
  end;
  raise EConvertError.Create('Unknown category: ' + ACategory);
end;

function RoundCount(ARound: Integer): Integer;
begin
  if ARound = LastRound then
  begin
    Exit(FinalCount);
  end;
  Result := StandardCount;
end;

function RoundStart(ARound: Integer): Integer;
begin
  Result := (ARound - FirstRound) * StandardCount;
end;

function LocalId(AIndex: Integer): String;
begin
  Result := Format('%.4d', [AIndex + 1]);
end;

function TRandom.Draw(ABound: Cardinal): Integer;
var
  LRejectionLimit: QWord;
begin
  Require(ABound > 0, 'Random bound must be positive');
  LRejectionLimit := (QWord(High(Cardinal)) div ABound) * ABound;
  repeat
    State := State xor (State shl 13);
    State := State xor (State shr 17);
    State := State xor (State shl 5);
  until QWord(State) <= LRejectionLimit;
  Result := Integer((State - 1) mod ABound);
end;

constructor TSeries.Create(const ARoot: String);
begin
  inherited Create;
  FRoot := ARoot;
  FIngredientNames := TNameMap.Create;
  FSymptomNames := TNameMap.Create;
  FOriginal := TDictionary<Integer, Boolean>.Create;
end;

destructor TSeries.Destroy;
begin
  FOriginal.Free;
  FSymptomNames.Free;
  FIngredientNames.Free;
  inherited;
end;

function TSeries.OriginalDir: String;
begin
  Result := Child(FRoot, OriginalName);
end;

function TSeries.RoundDir(ARound: Integer): String;
begin
  Result := Child(FRoot, OriginalName + '_round_' + IntToStr(ARound));
end;

function TSeries.PairId(AIngredient, ASymptom: Integer): Integer;
begin
  Result := AIngredient * Length(FSymptoms) + ASymptom;
end;

procedure TSeries.LoadInputs;
var
  LOriginalIngredients: TStringList;
  LAdditional: TStringList;
  LIngredients: TStringList;
  LSymptoms: TStringList;
  LInput: String;
  LHashes: String;
  LFile: String;
  LFields: TFields;
  LIngredient: TIngredient;
  LSymptom: TSymptom;
  LForm: String;
  LRound: Integer;
  LPosition: Integer;
  I: Integer;
begin
  LInput := RoundDir(FirstRound);
  LHashes := '';
  for LFile in InputFiles do
  begin
    LHashes := LHashes + FileHash(Child(LInput, LFile)) + '  ' + LFile + #10;
  end;
  for LRound := FirstRound to LastRound do
  begin
    Require(StringReplace(ReadBytes(Child(RoundDir(LRound), 'input-hashes.sha256')),
      #13#10, #10, [rfReplaceAll]) = LHashes, 'Invalid input manifest for round ' + IntToStr(LRound));
    for LFile in InputFiles do
    begin
      RequireFile(Child(RoundDir(LRound), LFile), ReadBytes(Child(LInput, LFile)), True);
    end;
  end;
  RequireFile(Child(OriginalDir, 'symptoms.tsv'), ReadBytes(Child(LInput, 'symptoms.tsv')), True);

  LOriginalIngredients := nil;
  LAdditional := nil;
  LIngredients := nil;
  LSymptoms := nil;
  try
    LOriginalIngredients := ReadTable(Child(OriginalDir, 'ingredients.tsv'), IngredientHeader);
    LAdditional := ReadTable(Child(LInput, 'additional-ingredients.tsv'), IngredientHeader);
    LIngredients := ReadTable(Child(LInput, 'ingredients.tsv'), IngredientHeader);
    LSymptoms := ReadTable(Child(LInput, 'symptoms.tsv'), SymptomHeader);
    Require((LOriginalIngredients.Count = 143) and (LAdditional.Count = 69) and
      (LIngredients.Count = 211) and (LSymptoms.Count = 34), 'Vocabulary counts differ');
    for I := 1 to LOriginalIngredients.Count - 1 do
    begin
      Require(IngredientRow(LIngredients[I]) = IngredientRow(LOriginalIngredients[I]), 'Original ingredient row differs');
    end;
    for I := 1 to LAdditional.Count - 1 do
    begin
      Require(LIngredients[I + LOriginalIngredients.Count - 1] = LAdditional[I],
        'Approved additional ingredient row differs');
    end;

    SetLength(FIngredients, LIngredients.Count - 1);
    for I := 1 to LIngredients.Count - 1 do
    begin
      LFields := SplitFields(IngredientRow(LIngredients[I]), #9);
      Require(Length(LFields) = 4, 'Ingredient row must have four fields');
      RequireCanonical(LFields[1]);
      LIngredient.Name := LFields[1];
      LIngredient.SortName := NameKey(LIngredient.Name);
      LIngredient.Category := CategoryIndex(LFields[0]);
      LIngredient.Forms := SplitFields(LFields[2], '|');
      LIngredient.Aliases := LFields[3];
      for LForm in LIngredient.Forms do
      begin
        RequireCanonical(LForm);
      end;
      LPosition := I - 1;
      while (LPosition > 0) and
        (OrdinalCompare(FIngredients[LPosition - 1].SortName, LIngredient.SortName) > 0) do
      begin
        FIngredients[LPosition] := FIngredients[LPosition - 1];
        Dec(LPosition);
      end;
      FIngredients[LPosition] := LIngredient;
    end;
    for I := 0 to High(FIngredients) do
    begin
      RegisterIdentity(FIngredientNames, FIngredients[I].Name, FIngredients[I].Aliases, I);
    end;
    Require(FIngredientNames.ContainsKey('beetroot'), 'Missing canonical beetroot');

    SetLength(FSymptoms, LSymptoms.Count - 1);
    for I := 1 to LSymptoms.Count - 1 do
    begin
      LFields := SplitFields(LSymptoms[I], #9);
      Require(Length(LFields) = 2, 'Symptom row must have two fields');
      RequireCanonical(LFields[0]);
      LSymptom.Name := LFields[0];
      LSymptom.SortName := NameKey(LSymptom.Name);
      LSymptom.Aliases := LFields[1];
      LPosition := I - 1;
      while (LPosition > 0) and (OrdinalCompare(FSymptoms[LPosition - 1].SortName, LSymptom.SortName) > 0) do
      begin
        FSymptoms[LPosition] := FSymptoms[LPosition - 1];
        Dec(LPosition);
      end;
      FSymptoms[LPosition] := LSymptom;
    end;
    for I := 0 to High(FSymptoms) do
    begin
      RegisterIdentity(FSymptomNames, FSymptoms[I].Name, FSymptoms[I].Aliases, I);
    end;
  finally
    LSymptoms.Free;
    LIngredients.Free;
    LAdditional.Free;
    LOriginalIngredients.Free;
  end;
end;

procedure TSeries.LoadOriginal;
var
  LPath: String;
  LLines: TStringList;
  LFields: TFields;
  LIngredient: Integer;
  LSymptom: Integer;
  LPairId: Integer;
  I: Integer;
begin
  LPath := Child(OriginalDir, 'freeze.tsv');
  Require(FileHash(LPath) = OriginalHash, 'Original freeze SHA-256 differs');
  LLines := ReadTable(LPath, FreezeHeader);
  try
    Require(LLines.Count = StandardCount + 1, 'Original freeze count differs');
    for I := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[I], #9);
      Require((Length(LFields) = 7) and (LFields[0] = LocalId(I - 1)),
        'Invalid original frozen row');
      Require(FIngredientNames.TryGetValue(NameKey(LFields[2]), LIngredient) and
        FSymptomNames.TryGetValue(NameKey(LFields[4]), LSymptom), 'Unknown original pair identity');
      Require(Categories[FIngredients[LIngredient].Category] = LFields[1],
        'Original category differs from vocabulary');
      LPairId := PairId(LIngredient, LSymptom);
      Require(not FOriginal.ContainsKey(LPairId), 'Duplicate canonical original pair');
      FOriginal.Add(LPairId, True);
    end;
  finally
    LLines.Free;
  end;
end;

procedure TSeries.Allocate;
var
  LIngredient: Integer;
  LSymptom: Integer;
  LNext: Integer;
begin
  SetLength(FPairs, Length(FIngredients) * Length(FSymptoms) - FOriginal.Count);
  Require(Length(FPairs) = 5930, 'Remainder must have exactly 5930 pairs');
  LNext := 0;
  for LIngredient := 0 to High(FIngredients) do
  begin
    for LSymptom := 0 to High(FSymptoms) do
    begin
      if not FOriginal.ContainsKey(PairId(LIngredient, LSymptom)) then
      begin
        FPairs[LNext].Ingredient := LIngredient;
        FPairs[LNext].Symptom := LSymptom;
        Inc(LNext);
      end;
    end;
  end;
  Require(LNext = Length(FPairs), 'Cartesian remainder is incomplete');
end;

procedure TSeries.InspectSiblings;
var
  LEntry: TSearchRec;
  LRound: Integer;
  LFound: Boolean;
begin
  if FindFirst(Child(FRoot, OriginalName + '_round_*'), faDirectory, LEntry) <> 0 then
  begin
    raise EInOutError.Create('No prepared rounds');
  end;
  try
    repeat
      if (LEntry.Attr and faDirectory) <> 0 then
      begin
        LFound := False;
        for LRound := FirstRound to LastRound do
        begin
          LFound := LFound or (LEntry.Name = ExtractFileName(RoundDir(LRound)));
        end;
        Require(LFound, 'Unexpected round directory: ' + LEntry.Name);
      end;
    until FindNext(LEntry) <> 0;
  finally
    SysUtils.FindClose(LEntry);
  end;
end;

function TSeries.PairLines(ARound: Integer): String;
var
  LText: TStringBuilder;
  LPair: TPair;
  LIndex: Integer;
  LAbsolute: Integer;
begin
  LText := TStringBuilder.Create;
  try
    for LIndex := 0 to RoundCount(ARound) - 1 do
    begin
      LAbsolute := RoundStart(ARound) + LIndex;
      LPair := FPairs[LAbsolute];
      LText.Append('round_').Append(IntToStr(ARound)).Append(#9)
        .Append(LocalId(LAbsolute)).Append(#9)
        .Append(Categories[FIngredients[LPair.Ingredient].Category]).Append(#9)
        .Append(FIngredients[LPair.Ingredient].Name).Append(#9)
        .Append(FSymptoms[LPair.Symptom].Name).Append(#10);
    end;
    Result := LText.ToString;
  finally
    LText.Free;
  end;
end;

procedure TSeries.CheckReservations(const APlan, AHash: String; ARequired: Boolean);
var
  LRound: Integer;
  LPlanPath: String;
  LHasPlan: Boolean;
  LReservedCount: Integer;
begin
  LPlanPath := Child(RoundDir(FirstRound), 'series-pairs.tsv');
  LHasPlan := FileExists(LPlanPath);
  RequireFile(LPlanPath, APlan, ARequired);
  RequireFile(Child(RoundDir(FirstRound), 'series-pairs.sha256'), AHash + #10, ARequired);
  LReservedCount := 0;
  for LRound := FirstRound to LastRound do
  begin
    if FileExists(Child(RoundDir(LRound), 'assigned-pairs.tsv')) then
    begin
      Inc(LReservedCount);
    end;
    RequireFile(Child(RoundDir(LRound), 'assigned-pairs.tsv'),
      PairHeader + #10 + PairLines(LRound), ARequired);
  end;
  Require((LReservedCount = 0) or LHasPlan, 'Round reservations exist without a shared plan');
end;

procedure TSeries.PublishReservations(const APlan, AHash: String);
var
  LRound: Integer;
  LReport: String;
begin
  Publish(Child(RoundDir(FirstRound), 'series-pairs.tsv'), APlan);
  Publish(Child(RoundDir(FirstRound), 'series-pairs.sha256'), AHash + #10);
  for LRound := FirstRound to LastRound do
  begin
    Publish(Child(RoundDir(LRound), 'assigned-pairs.tsv'),
      PairHeader + #10 + PairLines(LRound));
  end;
  CheckReservations(APlan, AHash, True);
  LReport := '# Reservation validation'#10#10
    + 'The original freeze matches SHA-256 `' + OriginalHash + '`. Its 1,000 canonical '
    + 'pairs are unique.'#10#10
    + 'All six rounds have the same verified input bytes. The 210 culinary exposures include '
    + 'the original 142, including beetroot, and the 68 approved additions. The 33 symptoms '
    + 'match the original vocabulary.'#10#10
    + 'The native validator replayed the 6,930-pair Cartesian product, removed the 1,000 '
    + 'original pairs and matched all 5,930 remaining pairs byte for byte to the shared plan '
    + 'and the six slices. Rounds 2 through 6 each have 1,000 pairs. Round 7 has 930. '
    + 'There are zero overlaps and no missing pairs.'#10#10
    + 'Ordering is ascending ASCII ordinal on the invariant lowercase ingredient, then '
    + 'on the invariant lowercase symptom. Canonical spellings retain their original case. '
    + 'The identity lookup applies NFKC, invariant lowercasing and Unicode whitespace '
    + 'normalization to canonical names and aliases.'#10#10
    + 'Reservation SHA-256 is `' + AHash + '`.'#10;
  Publish(Child(RoundDir(FirstRound), 'reservation-validation.md'), LReport);
end;

function TSeries.BuildClaims(ARound: Integer; out ACategories: TCategoryCounts): TStringsByRow;
var
  LDirections: array of Boolean;
  LRandom: TRandom;
  LSelected: Integer;
  LTemp: Boolean;
  LPair: TPair;
  LIngredient: TIngredient;
  LForm: String;
  LSymptom: String;
  LDirection: String;
  LStatement: String;
  I: Integer;
begin
  ACategories := Default(TCategoryCounts);
  SetLength(Result, RoundCount(ARound));
  SetLength(LDirections, Length(Result));
  LRandom.State := FirstSeed + Cardinal(ARound - FirstRound);
  for I := 0 to Length(Result) div 2 - 1 do
  begin
    LDirections[I] := True;
  end;
  for I := High(LDirections) downto 1 do
  begin
    LSelected := LRandom.Draw(Cardinal(I + 1));
    LTemp := LDirections[I];
    LDirections[I] := LDirections[LSelected];
    LDirections[LSelected] := LTemp;
  end;
  for I := 0 to High(Result) do
  begin
    LPair := FPairs[RoundStart(ARound) + I];
    LIngredient := FIngredients[LPair.Ingredient];
    LForm := LIngredient.Forms[LRandom.Draw(Cardinal(Length(LIngredient.Forms)))];
    LSymptom := FSymptoms[LPair.Symptom].Name;
    LDirection := 'worsens';
    if LDirections[I] then
    begin
      LDirection := 'reduces';
    end;
    LStatement := Format('Consuming %s %s %s %s in people with Parkinson''s disease.',
      [LForm, LIngredient.Name, LDirection, LSymptom]);
    Result[I] := LocalId(I) + #9 + Categories[LIngredient.Category] + #9 + LIngredient.Name
      + #9 + LForm + #9 + LSymptom + #9 + LDirection + #9 + LStatement;
    Inc(ACategories[LIngredient.Category]);
  end;
end;

function StatementText(const AClaim: String; AAppendEvidence: Boolean): String;
var
  LFields: TFields;
  I: Integer;
begin
  Result := '';
  LFields := SplitFields(AClaim, #9);
  for I := 0 to High(LFields) do
  begin
    Result := Result + FieldNames[I] + ': ' + LFields[I] + #10;
  end;
  if AAppendEvidence then
  begin
    Result := Result + 'Verdict: Pending'#10;
    for I := 8 to High(FieldNames) do
    begin
      Result := Result + FieldNames[I] + ':'#10;
    end;
  end;
end;

procedure CheckStatement(const APath, AClaim: String; APendingOnly: Boolean);
var
  LText: String;
  LLines: TFields;
  LPrefix: String;
  I: Integer;
begin
  if APendingOnly then
  begin
    RequireFile(APath, StatementText(AClaim, True), True);
    Exit;
  end;
  LText := ReadBytes(APath);
  LPrefix := StatementText(AClaim, False);
  Require(Copy(LText, 1, Length(LPrefix)) = LPrefix, 'Statement immutable fields differ: ' + APath);
  LLines := SplitFields(LText, #10);
  Require((Length(LLines) = Length(FieldNames) + 1) and
    (LLines[High(LLines)] = '') and (Pos(#13, LText) = 0), 'Invalid statement format: ' + APath);
  for I := 7 to High(FieldNames) do
  begin
    LPrefix := FieldNames[I] + ':';
    Require(Copy(LLines[I], 1, Length(LPrefix)) = LPrefix, 'Invalid evidence field: ' + APath);
  end;
end;

procedure CheckStatementDirectory(const ADirectory: String; ACount: Integer;
  ARequireAll: Boolean);
var
  LEntry: TSearchRec;
  LIndex: Integer;
  LCount: Integer;
begin
  LCount := 0;
  if FindFirst(Child(ADirectory, '*'), faAnyFile, LEntry) = 0 then
  begin
    try
      repeat
        if (LEntry.Name = '.') or (LEntry.Name = '..') then
        begin
          Continue;
        end;
        Require((LEntry.Attr and faDirectory = 0) and
          TryStrToInt(Copy(LEntry.Name, 1, 4), LIndex) and
          (LIndex >= 1) and (LIndex <= ACount) and
          ((LEntry.Name = LocalId(LIndex - 1) + '.txt') or
          ((not ARequireAll) and (LEntry.Name = LocalId(LIndex - 1) + '.txt.new'))),
          'Unexpected statement path: ' + Child(ADirectory, LEntry.Name));
        if ExtractFileExt(LEntry.Name) = '.txt' then
        begin
          Inc(LCount);
        end;
      until FindNext(LEntry) <> 0;
    finally
      SysUtils.FindClose(LEntry);
    end;
  end;
  Require(not ARequireAll or (LCount = ACount), 'Missing statement files: ' + ADirectory);
end;

procedure TSeries.HandleRound(ARound: Integer; const AHash, AAction: String;
  out ACounts: TCategoryCounts);
var
  LDir: String;
  LStatementDir: String;
  LClaims: TStringsByRow;
  LClaim: String;
  LFile: String;
  LMetadata: String;
  LText: TStringBuilder;
  LFreeze: String;
  LHash: String;
  LFrozen: Boolean;
  LRequireAll: Boolean;
  LGenerate: Boolean;
  I: Integer;
begin
  LDir := RoundDir(ARound);
  LStatementDir := Child(LDir, 'statements');
  LClaims := BuildClaims(ARound, ACounts);
  LText := TStringBuilder.Create;
  try
    LText.Append(FreezeHeader).Append(#10);
    for LClaim in LClaims do
    begin
      LText.Append(LClaim).Append(#10);
    end;
    LFreeze := LText.ToString;
  finally
    LText.Free;
  end;
  LHash := TextHash(LFreeze);
  LMetadata := 'seed=' + IntToStr(FirstSeed + ARound - FirstRound) + #10
    + 'algorithm=' + Algorithm + #10 + 'round=round_' + IntToStr(ARound) + #10
    + 'original-freeze.sha256=' + OriginalHash + #10
    + 'series-pairs.sha256=' + AHash + #10
    + 'assigned-pairs.sha256=' + TextHash(PairHeader + #10 + PairLines(ARound)) + #10;
  for LFile in InputFiles do
  begin
    LMetadata := LMetadata + LFile + '.sha256=' + FileHash(Child(LDir, LFile)) + #10;
  end;
  LFrozen := FileExists(Child(LDir, 'freeze.tsv'));
  LRequireAll := LFrozen or (AAction = 'verify');
  LGenerate := (AAction = 'generate') and not LFrozen;
  RequireFile(Child(LDir, 'freeze.tsv'), LFreeze, LRequireAll);
  RequireFile(Child(LDir, 'freeze.sha256'), LHash + #10, LRequireAll);
  RequireFile(Child(LDir, 'seed.txt'), LMetadata, LRequireAll);
  CheckStatementDirectory(LStatementDir, Length(LClaims), LRequireAll);
  if LGenerate then
  begin
    Require(ForceDirectories(LStatementDir), 'Cannot create ' + LStatementDir);
  end;
  for I := 0 to High(LClaims) do
  begin
    LFile := Child(LStatementDir, LocalId(I) + '.txt');
    if LGenerate then
    begin
      Publish(LFile, StatementText(LClaims[I], True));
    end;
    if FileExists(LFile) or LRequireAll then
    begin
      CheckStatement(LFile, LClaims[I], not LFrozen);
    end;
  end;
  if LGenerate then
  begin
    CheckStatementDirectory(LStatementDir, Length(LClaims), True);
    Publish(Child(LDir, 'seed.txt'), LMetadata);
    Publish(Child(LDir, 'freeze.sha256'), LHash + #10);
    Publish(Child(LDir, 'freeze.tsv'), LFreeze);
  end;
  if (AAction <> 'preflight') and (LFrozen or LGenerate) then
  begin
    WriteLn(ARound, #9, Length(LClaims), #9, Length(LClaims) div 2, #9,
      Length(LClaims) div 2, #9, ACounts[0], #9, ACounts[1], #9, ACounts[2], #9,
      ACounts[3], #9, LHash);
  end;
end;

procedure TSeries.Run(const AAction: String);
var
  LRound: Integer;
  LPlan: String;
  LHash: String;
  LCounts: TCategoryCounts;
  LLockPath: UnicodeString;
  LLock: THandle;
begin
  Require((AAction = 'reserve') or (AAction = 'generate') or (AAction = 'verify'),
    'Choose reserve, generate or verify');
  InspectSiblings;
  LLockPath := UTF8Decode(Child(RoundDir(FirstRound), '.series-generation.lock'));
  LLock := CreateFileW(PWideChar(LLockPath), GENERIC_WRITE, 0, nil, CREATE_NEW,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  Require(LLock <> INVALID_HANDLE_VALUE, 'Cannot acquire the series generation lock');
  try
    LoadInputs;
    LoadOriginal;
    Allocate;
    LPlan := PairHeader + #10;
    for LRound := FirstRound to LastRound do
    begin
      LPlan := LPlan + PairLines(LRound);
    end;
    LHash := TextHash(LPlan);
    CheckReservations(LPlan, LHash, AAction <> 'reserve');
    for LRound := FirstRound to LastRound do
    begin
      HandleRound(LRound, LHash, 'preflight', LCounts);
    end;
    if AAction = 'reserve' then
    begin
      PublishReservations(LPlan, LHash);
    end
    else
    begin
      Require(FileExists(Child(RoundDir(FirstRound), 'reservation-validation.md')),
        'Missing reservation validation report');
      WriteLn('round'#9'claims'#9'reduces'#9'worsens'#9'food'#9'herb'#9'spice'#9'oil'#9'freeze_sha256');
      for LRound := FirstRound to LastRound do
      begin
        HandleRound(LRound, LHash, AAction, LCounts);
      end;
    end;
    Require(FileHash(Child(OriginalDir, 'freeze.tsv')) = OriginalHash, 'Original freeze changed');
    WriteLn('Verified series union of 6930 pairs; reservation SHA-256 ', LHash);
  finally
    CloseHandle(LLock);
  end;
end;

var
  LSeries: TSeries;
begin
  try
    Require(ParamCount = 2, 'Usage: foodexperiment.series reserve|generate|verify <experiments>');
    LSeries := TSeries.Create(ExpandFileName(ParamStr(2)));
    try
      LSeries.Run(ParamStr(1));
    finally
      LSeries.Free;
    end;
  except
    on LError: Exception do
    begin
      WriteLn(StdErr, LError.Message);
      Halt(1);
    end;
  end;
end.

