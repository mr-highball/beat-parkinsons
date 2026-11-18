{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program ResearchCulture;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, Classes, StrUtils;

var
  GRecordsVerified: Integer;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EArgumentException.Create(AMessage);
  end;
end;

procedure SaveText(const APath, AText: String);
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    LLines.LineBreak := #10;
    LLines.WriteBOM := False;
    LLines.SaveToFile(APath, TEncoding.UTF8);
  finally
    LLines.Free;
  end;
end;

function Field(ALines: TStringList; const AName: String): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to ALines.Count - 1 do
  begin
    if StartsText(AName + ':', ALines[LIndex]) then
    begin
      Result := Trim(Copy(ALines[LIndex], Length(AName) + 2, MaxInt));
      Exit;
    end;
  end;
end;

procedure VerifyRecords(const ADirectory, ARepo: String; AYear: Integer;
  AConversation: Boolean = False);
const
  CRequired: array[0..2] of String = ('Title', 'Source', 'Date basis');
  CFullRecord: array[0..5] of String = ('Source kind', 'Publication date',
    'Reviewed', 'Reported direction', 'Authenticity', 'Efficacy evidence');
var
  LSearch: TSearchRec;
  LPath: String;
  LValue: String;
  LLines: TStringList;
  LIndex: Integer;
  LSourceYear: Integer;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, LSearch) <> 0 then
  begin
    Exit;
  end;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
      begin
        Continue;
      end;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      Require((LSearch.Attr and faSymLink) = 0,
        'Linked cultural input is not supported: ' + LPath);
      if (LSearch.Attr and faDirectory) <> 0 then
      begin
        VerifyRecords(LPath, ARepo, AYear, AConversation or
          (SameText(ExtractFileName(ADirectory), 'Cultural-and-Experiential') and
           SameText(LSearch.Name, 'Conversations')));
      end
      else if SameText(ExtractFileExt(LPath), '.txt') then
      begin
        LLines := TStringList.Create;
        try
          LLines.LoadFromFile(LPath, TEncoding.UTF8);
          Require(Field(LLines, 'Collection') = 'Cultural and experiential',
            'Missing searchable cultural collection metadata: ' + LPath);
          for LIndex := Low(CRequired) to High(CRequired) do
          begin
            Require(Field(LLines, CRequired[LIndex]) <> '',
              'Missing ' + CRequired[LIndex] + ': ' + LPath);
          end;
          if not AConversation then
          begin
            for LIndex := Low(CFullRecord) to High(CFullRecord) do
            begin
              Require(Field(LLines, CFullRecord[LIndex]) <> '',
                'Missing ' + CFullRecord[LIndex] + ': ' + LPath);
            end;
          end;
          LValue := Field(LLines, 'Publication date');
          if not TryStrToInt(Copy(LValue, 1, 4), LSourceYear) then
          begin
            Require(ContainsText(Field(LLines, 'Date basis'), 'capture'),
              'Undated source needs an explicit capture basis: ' + LPath);
            Require(TryStrToInt(Copy(Field(LLines, 'Capture date'), 1, 4), LSourceYear),
              'Undated source needs a capture date: ' + LPath);
          end;
          Require((LSourceYear >= AYear) and (LSourceYear <= AYear + 4),
            'Source date is outside its period: ' + LPath);
          LValue := Field(LLines, 'Existing accession');
          if LValue <> '' then
          begin
            Require(FileExists(IncludeTrailingPathDelimiter(ARepo) + LValue),
              'Missing prior accession: ' + LPath);
          end;
          Inc(GRecordsVerified);
        finally
          LLines.Free;
        end;
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

procedure Run;
const
  CLink = '- [Cultural, traditional and experiential accounts](Cultural-and-Experiential/README.md).';
var
  LRoot: String;
  LResearch: String;
  LPeriod: String;
  LDirectory: String;
  LIndex: String;
  LLines: TStringList;
  LYear: Integer;
  LLastBucket: Integer;
  LPeriods: Integer;
  LHistoricalPeriods: Integer;
  LYears: TStringList;
  LYearIndex: Integer;
  LSearch: TSearchRec;
  LStartYear: Integer;
  LEndYear: Integer;
  LCreated: Integer;
  LLinked: Integer;
begin
  Require(ParamCount = 2, 'Usage: research.culture REPOSITORY LAST_BUCKET_START');
  Require(TryStrToInt(ParamStr(2), LLastBucket) and (LLastBucket >= 1865) and
    (LLastBucket <= 9995) and (((LLastBucket - 1865) mod 5) = 0),
    'The final bucket must be a five-year boundary starting at 1865.');
  LPeriods := ((LLastBucket - 1865) div 5) + 1;
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LResearch := LRoot + 'research' + DirectorySeparator;
  Require(FileExists(LResearch + 'Cultural-and-Experiential.md'), 'Missing record policy.');
  LYear := 1865;
  while LYear <= LLastBucket do
  begin
    LPeriod := IntToStr(LYear) + '-' + IntToStr(LYear + 4);
    Require(FileExists(LResearch + LPeriod + DirectorySeparator + 'README.md'),
      'Missing existing period: ' + LPeriod);
    Inc(LYear, 5);
  end;
  LCreated := 0;
  LLinked := 0;
  LHistoricalPeriods := 0;
  LLines := TStringList.Create;
  LYears := TStringList.Create;
  GRecordsVerified := 0;
  try
    LYear := 1865;
    while LYear <= LLastBucket do
    begin
      LYears.Add(IntToStr(LYear));
      Inc(LYear, 5);
    end;
    // Admit only explicitly existing historical collections; never pad missing centuries.
    if FindFirst(LResearch + '*', faAnyFile, LSearch) = 0 then
    begin
      try
        repeat
          if ((LSearch.Attr and faDirectory) = 0) or
            not TryStrToInt(Copy(LSearch.Name, 1, 4), LStartYear) or
            (LStartYear >= 1865) then
          begin
            Continue;
          end;
          LDirectory := LResearch + LSearch.Name + DirectorySeparator +
            'Cultural-and-Experiential';
          if not DirectoryExists(LDirectory) then
          begin
            Continue;
          end;
          Require((LSearch.Attr and faSymLink) = 0,
            'Linked historical period is not supported: ' + LSearch.Name);
          Require((Length(LSearch.Name) = 9) and (LSearch.Name[5] = '-') and
            (LStartYear >= 1000) and ((LStartYear mod 5) = 0) and
            TryStrToInt(Copy(LSearch.Name, 6, 4), LEndYear) and
            (LEndYear = LStartYear + 4),
            'Invalid historical five-year period: ' + LSearch.Name);
          Require(FileExists(LResearch + LSearch.Name + DirectorySeparator + 'README.md'),
            'Missing historical period index: ' + LSearch.Name);
          LYears.Add(IntToStr(LStartYear));
          Inc(LHistoricalPeriods);
        until FindNext(LSearch) <> 0;
      finally
        FindClose(LSearch);
      end;
    end;
    LYears.Sort;
    for LYearIndex := 0 to LYears.Count - 1 do
    begin
      LYear := StrToInt(LYears[LYearIndex]);
      LPeriod := IntToStr(LYear) + '-' + IntToStr(LYear + 4);
      LDirectory := LResearch + LPeriod + DirectorySeparator + 'Cultural-and-Experiential';
      Require(ForceDirectories(LDirectory), 'Cannot create period category.');
      if not FileExists(LDirectory + DirectorySeparator + 'README.md') then
      begin
        SaveText(LDirectory + DirectorySeparator + 'README.md',
          '# Cultural and experiential accounts, ' + LPeriod + #10#10 +
          'Collect traditional practices, ceremonial accounts, public personal reports and ' +
          'local knowledge here, separately from formal studies. An empty category does ' +
          'not establish that a practice or source is absent.' + #10#10 +
          'Follow the [source, date, privacy and evidence policy](../../Cultural-and-Experiential.md). ' +
          'Create the applicable subcategory when adding records, and cross-link prior research ' +
          'without duplicating studies.' + #10);
        Inc(LCreated);
      end;
      VerifyRecords(LDirectory, LRoot, LYear);
      LIndex := LResearch + LPeriod + DirectorySeparator + 'README.md';
      LLines.LoadFromFile(LIndex, TEncoding.UTF8);
      if Pos('Cultural-and-Experiential/README.md', LLines.Text) = 0 then
      begin
        LLines.Add('');
        LLines.Add(CLink);
        SaveText(LIndex, LLines.Text);
        Inc(LLinked);
      end;
    end;
  finally
    LYears.Free;
    LLines.Free;
  end;
  WriteLn('periods=', LPeriods, ' category_readmes_created=', LCreated,
    ' index_links_added=', LLinked, ' historical_periods=', LHistoricalPeriods);
  WriteLn('cultural_records_verified=', GRecordsVerified,
    ' collection_metadata_dates_provenance_and_reused_accessions=PASS');
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
