{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.externaldata;

{$mode delphi}
{$H+}

interface

type
  TFields = array of UTF8String;

  TQuery = record
    Id: UTF8String;
    ClaimId: UTF8String;
    Variant: UTF8String;
    Text: UTF8String;
  end;

  TQueries = array of TQuery;

  TSearchRows = record
    HitCount: Int64;
    Rows: TFields;
  end;

function SplitFields(const AText: UTF8String; ADelimiter: Char): TFields;
function LoadQueries(const AExperimentDir: String): TQueries;
function ParseResults(const AQuery: TQuery; const ABody: UTF8String): TSearchRows;
function CleanField(const AText: UTF8String): UTF8String;

implementation

uses
  Classes, SysUtils, StrUtils, fpjson, jsonparser;

const
  Tab = #9;
  MaximumPageSize = 20;

function SplitFields(const AText: UTF8String; ADelimiter: Char): TFields;
var
  LStart: Integer;
  LField: Integer;
  I: Integer;
begin
  Result := nil;
  SetLength(Result, 1);
  for I := 1 to Length(AText) do
  begin
    if AText[I] = ADelimiter then
    begin
      SetLength(Result, Length(Result) + 1);
    end;
  end;
  LStart := 1;
  LField := 0;
  for I := 1 to Length(AText) do
  begin
    if AText[I] = ADelimiter then
    begin
      Result[LField] := Copy(AText, LStart, I - LStart);
      LStart := I + 1;
      Inc(LField);
    end;
  end;
  Result[LField] := Copy(AText, LStart);
end;

function Quote(const AValue: UTF8String): UTF8String;
begin
  Result := '"' + StringReplace(StringReplace(AValue, '\', '\\',
    [rfReplaceAll]), '"', '\"', [rfReplaceAll]) + '"';
end;

function AlternativeTerms(const ATerms: UTF8String): UTF8String;
var
  LTerms: TFields;
  LTerm: UTF8String;
begin
  Result := '';
  LTerms := SplitFields(ATerms, '|');
  for LTerm in LTerms do
  begin
    if LTerm = '' then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + ' OR ';
    end;
    Result := Result + Quote(LTerm);
  end;
  if Result = '' then
  begin
    raise EConvertError.Create('Search group has no terms');
  end;
  Result := '(' + Result + ')';
end;

function SymptomFocus(const ASymptom: UTF8String): UTF8String;
const
  CMeasureSuffixes: array[0..2] of String = (' severity', ' frequency', ' performance');
var
  LSuffix: String;
begin
  Result := ASymptom;
  for LSuffix in CMeasureSuffixes do
  begin
    if EndsStr(LSuffix, ASymptom) then
    begin
      Exit(Copy(ASymptom, 1, Length(ASymptom) - Length(LSuffix)));
    end;
  end;
end;

function PreparationTerms(const AForm: UTF8String): UTF8String;
const
  CTerms: array[0..31] of UTF8String = (
    'baked|baking',
    'boiled|boiling',
    'braised|braising',
    'brewed|infusion',
    'canned|tinned',
    'cold-pressed|cold pressed',
    'cooked|cooking',
    'cracked|coarsely ground',
    'decaffeinated|decaf',
    'dried|dehydrated',
    'extra-virgin|extra virgin',
    'fermented|fermentation',
    'fresh|undried',
    'frozen|quick-frozen',
    'grated|shredded',
    'grilled|grilling',
    'ground|powder',
    'minced|finely chopped',
    'pasteurized|pasteurised',
    'pickled|pickling',
    'plain|unflavored|unflavoured',
    'poached|poaching',
    'raw|uncooked',
    'refined|refining',
    'roasted|roasting',
    'rolled|flaked',
    'scrambled|scrambling',
    'smoked|smoking',
    'steamed|steaming',
    'strained|straining',
    'toasted|toasting',
    'virgin|unrefined'
  );
var
  LTerm: UTF8String;
begin
  for LTerm in CTerms do
  begin
    if Copy(LTerm, 1, Pos('|', LTerm) - 1) = AForm then
    begin
      Exit(LTerm);
    end;
  end;
  raise EConvertError.CreateFmt('No external search terms for preparation "%s"', [AForm]);
end;

function ColumnIndex(const AHeaders: TFields; const AColumn: UTF8String): Integer;
var
  I: Integer;
begin
  for I := Low(AHeaders) to High(AHeaders) do
  begin
    if AHeaders[I] = AColumn then
    begin
      Exit(I);
    end;
  end;
  raise EConvertError.CreateFmt('Missing TSV column "%s"', [AColumn]);
end;

procedure ReadVocabulary(const APath, ALabelColumn: String; AAliases: TStringList);
var
  LLines: TStringList;
  LFields: TFields;
  LLabelColumn: Integer;
  LAliasColumn: Integer;
  I: Integer;
begin
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    LFields := SplitFields(LLines[0], Tab);
    LLabelColumn := ColumnIndex(LFields, ALabelColumn);
    LAliasColumn := ColumnIndex(LFields, 'aliases');
    for I := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[I], Tab);
      AAliases.Add(LFields[LLabelColumn] + '=' + LFields[LAliasColumn]);
    end;
  finally
    LLines.Free;
  end;
end;

function FindAliases(AVocabulary: TStringList; const ALabel: UTF8String): UTF8String;
var
  LIndex: Integer;
begin
  LIndex := AVocabulary.IndexOfName(ALabel);
  if LIndex < 0 then
  begin
    raise EConvertError.CreateFmt('Frozen vocabulary term "%s" is missing', [ALabel]);
  end;
  Result := AVocabulary.ValueFromIndex[LIndex];
end;

procedure ValidateId(const AId: UTF8String);
var
  LChar: Char;
begin
  if AId = '' then
  begin
    raise EConvertError.Create('Empty frozen claim ID');
  end;
  for LChar in AId do
  begin
    if not (LChar in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
    begin
      raise EConvertError.CreateFmt('Unsafe frozen claim ID "%s"', [AId]);
    end;
  end;
end;

function LoadQueries(const AExperimentDir: String): TQueries;
const
  CParkinson = ' AND ("Parkinson disease" OR "Parkinson''s disease" OR "Parkinson")';
var
  LLines: TStringList;
  LIngredientAliases: TStringList;
  LSymptomAliases: TStringList;
  LClaimIds: TStringList;
  LHeaders: TFields;
  LFields: TFields;
  LIdColumn: Integer;
  LIngredientColumn: Integer;
  LFormColumn: Integer;
  LSymptomColumn: Integer;
  LClaimId: UTF8String;
  LIngredient: UTF8String;
  LForm: UTF8String;
  LSymptom: UTF8String;
  LFocus: UTF8String;
  LQueryIndex: Integer;
  I: Integer;
begin
  Result := nil;
  LLines := TStringList.Create;
  LIngredientAliases := TStringList.Create;
  LSymptomAliases := TStringList.Create;
  LClaimIds := TStringList.Create;
  try
    LClaimIds.Sorted := True;
    LClaimIds.Duplicates := dupError;
    ReadVocabulary(IncludeTrailingPathDelimiter(AExperimentDir) + 'ingredients.tsv',
      'ingredient', LIngredientAliases);
    ReadVocabulary(IncludeTrailingPathDelimiter(AExperimentDir) + 'symptoms.tsv',
      'symptom', LSymptomAliases);
    LLines.LoadFromFile(IncludeTrailingPathDelimiter(AExperimentDir) + 'freeze.tsv');
    if LLines.Count < 2 then
    begin
      raise EConvertError.Create('The freeze table has no claim rows');
    end;
    LHeaders := SplitFields(LLines[0], Tab);
    LIdColumn := ColumnIndex(LHeaders, 'id');
    LIngredientColumn := ColumnIndex(LHeaders, 'ingredient');
    LFormColumn := ColumnIndex(LHeaders, 'preparation');
    LSymptomColumn := ColumnIndex(LHeaders, 'symptom');
    SetLength(Result, (LLines.Count - 1) * 2);
    for I := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[I], Tab);
      if Length(LFields) <> Length(LHeaders) then
      begin
        raise EConvertError.CreateFmt('Invalid frozen row %d', [I + 1]);
      end;
      LClaimId := LFields[LIdColumn];
      ValidateId(LClaimId);
      LClaimIds.Add(LClaimId);
      LIngredient := LFields[LIngredientColumn];
      LForm := LFields[LFormColumn];
      LSymptom := LFields[LSymptomColumn];
      LFocus := SymptomFocus(LSymptom);
      LQueryIndex := (I - 1) * 2;
      Result[LQueryIndex].Id := LClaimId + '-1';
      Result[LQueryIndex].ClaimId := LClaimId;
      Result[LQueryIndex].Variant := 'exact';
      Result[LQueryIndex].Text := Quote(LIngredient) + ' AND ' +
        AlternativeTerms(PreparationTerms(LForm)) + ' AND ' + Quote(LFocus) + CParkinson;
      Inc(LQueryIndex);
      Result[LQueryIndex].Id := LClaimId + '-2';
      Result[LQueryIndex].ClaimId := LClaimId;
      Result[LQueryIndex].Variant := 'aliases';
      Result[LQueryIndex].Text :=
        AlternativeTerms(LIngredient + '|' + FindAliases(LIngredientAliases, LIngredient)) +
        ' AND ' + AlternativeTerms(LFocus + '|' + FindAliases(LSymptomAliases, LSymptom)) +
        CParkinson;
    end;
  finally
    LClaimIds.Free;
    LSymptomAliases.Free;
    LIngredientAliases.Free;
    LLines.Free;
  end;
end;

function DecodeEntity(const AEntity: UTF8String): UTF8String;
var
  LCode: Integer;
  LNumber: UTF8String;
  LUnicode: UnicodeString;
begin
  case IndexStr(AEntity, ['amp', 'lt', 'gt', 'quot', 'apos', 'nbsp', 'ndash',
    'mdash', 'rsquo', 'lsquo', 'ldquo', 'rdquo']) of
    0: Exit('&');
    1: Exit('<');
    2: Exit('>');
    3: Exit('"');
    4: Exit('''');
    5: Exit(' ');
    6: Exit(UTF8Encode(WideChar($2013)));
    7: Exit(UTF8Encode(WideChar($2014)));
    8: Exit(UTF8Encode(WideChar($2019)));
    9: Exit(UTF8Encode(WideChar($2018)));
    10: Exit(UTF8Encode(WideChar($201C)));
    11: Exit(UTF8Encode(WideChar($201D)));
  end;
  if Copy(AEntity, 1, 1) = '#' then
  begin
    LNumber := Copy(AEntity, 2);
    if LowerCase(Copy(LNumber, 1, 1)) = 'x' then
    begin
      LNumber := '$' + Copy(LNumber, 2);
    end;
    if TryStrToInt(LNumber, LCode) and (LCode > 0) and (LCode <= $10FFFF) and
      ((LCode < $D800) or (LCode > $DFFF)) then
    begin
      if LCode <= $FFFF then
      begin
        Exit(UTF8Encode(WideChar(LCode)));
      end;
      Dec(LCode, $10000);
      SetLength(LUnicode, 2);
      LUnicode[1] := WideChar($D800 or (LCode shr 10));
      LUnicode[2] := WideChar($DC00 or (LCode and $3FF));
      Exit(UTF8Encode(LUnicode));
    end;
  end;
  Result := '&' + AEntity + ';';
end;

function FindByte(AChar: Char; const AText: UTF8String; AOffset: Integer): Integer;
var
  I: Integer;
begin
  for I := AOffset to Length(AText) do
  begin
    if AText[I] = AChar then
    begin
      Exit(I);
    end;
  end;
  Result := 0;
end;

function CleanField(const AText: UTF8String): UTF8String;
var
  LIndex: Integer;
  LEnd: Integer;
  LLength: Integer;
  LPart: UTF8String;
  LTag: UTF8String;
  LPendingSpace: Boolean;
begin
  SetLength(Result, Length(AText));
  LIndex := 1;
  LLength := 0;
  LPendingSpace := False;
  while LIndex <= Length(AText) do
  begin
    LPart := AText[LIndex];
    if (LPart = '<') and (LIndex < Length(AText)) and
      (AText[LIndex + 1] in ['a'..'z', 'A'..'Z', '/', '!']) then
    begin
      LEnd := FindByte('>', AText, LIndex + 1);
      if LEnd > 0 then
      begin
        LTag := LowerCase(Copy(AText, LIndex + 1, LEnd - LIndex - 1));
        if (LTag = '/p') or (LTag = '/h3') or (Copy(LTag, 1, 2) = 'br') then
        begin
          LPendingSpace := LLength > 0;
        end;
        LIndex := LEnd + 1;
        Continue;
      end;
    end;
    if LPart = '&' then
    begin
      LEnd := FindByte(';', AText, LIndex + 1);
      if (LEnd > LIndex) and (LEnd - LIndex <= 12) then
      begin
        LPart := DecodeEntity(Copy(AText, LIndex + 1, LEnd - LIndex - 1));
        LIndex := LEnd;
      end;
    end;
    if (Length(LPart) = 1) and (LPart[1] <= ' ') then
    begin
      LPendingSpace := LLength > 0;
    end
    else
    begin
      if LPendingSpace then
      begin
        Inc(LLength);
        Result[LLength] := ' ';
        LPendingSpace := False;
      end;
      Move(LPart[1], Result[LLength + 1], Length(LPart));
      Inc(LLength, Length(LPart));
    end;
    Inc(LIndex);
  end;
  SetLength(Result, LLength);
end;

function GetField(AResult: TJSONData; const AName: UTF8String): UTF8String;
var
  LField: TJSONData;
begin
  Result := '';
  LField := AResult.FindPath(AName);
  if Assigned(LField) and (LField.JSONType in [jtString, jtNumber]) then
  begin
    Result := CleanField(LField.AsString);
  end;
end;

function ParseResults(const AQuery: TQuery; const ABody: UTF8String): TSearchRows;
var
  LJson: TJSONData;
  LResults: TJSONData;
  LHitCount: TJSONData;
  LRecord: TJSONData;
  LJournal: UTF8String;
  LDate: UTF8String;
  I: Integer;
begin
  Result := Default(TSearchRows);
  LJson := GetJSON(ABody, True);
  try
    LHitCount := LJson.FindPath('hitCount');
    LResults := LJson.FindPath('resultList.result');
    if not Assigned(LHitCount) or (LHitCount.JSONType <> jtNumber) or
      not Assigned(LResults) or (LResults.JSONType <> jtArray) then
    begin
      raise EConvertError.Create('Europe PMC returned an unexpected result structure');
    end;
    Result.HitCount := LHitCount.AsInt64;
    if (Result.HitCount < LResults.Count) or (LResults.Count > MaximumPageSize) then
    begin
      raise EConvertError.Create('Europe PMC returned inconsistent result counts');
    end;
    SetLength(Result.Rows, LResults.Count);
    for I := 0 to LResults.Count - 1 do
    begin
      LRecord := LResults.Items[I];
      if LRecord.JSONType <> jtObject then
      begin
        raise EConvertError.Create('Europe PMC returned an invalid result row');
      end;
      LJournal := GetField(LRecord, 'journalInfo.journal.title');
      if LJournal = '' then
      begin
        LJournal := GetField(LRecord, 'journalTitle');
      end;
      LDate := GetField(LRecord, 'firstPublicationDate');
      if LDate = '' then
      begin
        LDate := GetField(LRecord, 'pubYear');
      end;
      Result.Rows[I] := AQuery.Id + Tab + AQuery.ClaimId + Tab + IntToStr(I + 1) +
        Tab + GetField(LRecord, 'pmid') + Tab + GetField(LRecord, 'doi') +
        Tab + GetField(LRecord, 'pmcid') + Tab + GetField(LRecord, 'title') +
        Tab + LJournal + Tab + LDate + Tab + GetField(LRecord, 'abstractText');
    end;
  finally
    LJson.Free;
  end;
end;

end.
