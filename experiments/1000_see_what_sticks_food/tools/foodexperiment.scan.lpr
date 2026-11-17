{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentScan;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, FPSHA256, foodexperiment.matching;

type
  TIndexClaim = record
    Id: String;
    IngredientIndex: Integer;
    SymptomIndex: Integer;
    ExposureCount: Integer;
    TitleExposureCount: Integer;
    JointCount: Integer;
    TitleJointCount: Integer;
  end;

  TIndexClaims = array of TIndexClaim;

  TCatalogScanner = class
  private
    FMatcher: TMatcher;
    FIngredients: TStringList;
    FSymptoms: TStringList;
    FFlags: TMatchFlags;
    FFocus: TMatchFlags;
    FColumns: TStringList;
    FCoverage: Text;
    FMatches: Text;
    FCoverageBuffer: array[0..65535] of Byte;
    FMatchBuffer: array[0..65535] of Byte;
    FFileCount: Integer;
    FRecordCount: Integer;
    FMatchCount: Integer;
    FFailureCount: Integer;
    procedure LoadTerms(const ADirectory: String; AExpanded: Boolean;
      const AExtraTerms: String = '');
    procedure LoadExtraTerms(const APath: String);
    function LoadIndexClaims(const APath: String): TIndexClaims;
    procedure GatherFiles(const ARoot, ARelative: String; AFiles: TStrings);
    procedure ScanFile(const ARoot, ARelative: String);
    procedure ScanTable(const APath: String; const AContent: RawByteString);
    procedure ScanDocument(const APath: String; const AContent: RawByteString);
    function Mark(const AContent: RawByteString): Boolean;
    procedure WriteCandidate(const APath, ALocator, ATitle: String);
  public
    constructor Create(ARussian: Boolean = False);
    destructor Destroy; override;
    procedure Scan(const AExperiment, AResearch, AOutput: String; AExpanded: Boolean);
    procedure ScanIndex(const AExperiment, AIndex, AExtraTerms, AOutput, ALanguage: String);
  end;

const
  CatalogCoverageHeader = 'path'#9'bytes'#9'kind'#9'status'#9'records_scanned'#9'detail';
  CatalogMatchesHeader = 'path'#9'locator'#9'title'#9'ingredients'#9'symptoms'#9 +
    'focused_ingredients'#9'focused_symptoms';
  IndexHeader = 'docid'#9'hal_id'#9'language'#9'title'#9'indexed_abstract';
  ThesisIndexHeader = 'docid'#9'nnt'#9'language'#9'title'#9'indexed_abstract';
  ProceedingsIndexHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'indexed_abstract';
  OpenAlexIndexHeader = 'work_id'#9'language'#9'title'#9'indexed_abstract';
  IndexScreenFields = 'language'#9'title'#9'has_abstract'#9 +
    'ingredients'#9'symptoms'#9'title_ingredients'#9'title_symptoms'#9'joint_claim_ids';

procedure RequireFreeze(const AExperiment: String);
var
  LBytes: RawByteString;
  LInput: TBytes;
  LExpected: String;
  LActual: AnsiString;
begin
  LExpected := Trim(ReadBytes(IncludeTrailingPathDelimiter(AExperiment) + 'freeze.sha256'));
  LBytes := ReadBytes(IncludeTrailingPathDelimiter(AExperiment) + 'freeze.tsv');
  SetLength(LInput, Length(LBytes));
  if Length(LInput) > 0 then
  begin
    Move(LBytes[1], LInput[0], Length(LInput));
  end;
  TSHA256.DigestHexa(LInput, LActual);
  if not SameText(LExpected, LActual) then
  begin
    raise EInvalidOp.Create('Frozen claim hash does not match');
  end;
end;

procedure AddTerms(AMatcher: TMatcher; const AValue: String; AIndex: Integer);
var
  LTerms: TStringArray;
  LTerm: String;
begin
  LTerms := AValue.Split(['|']);
  for LTerm in LTerms do
  begin
    AMatcher.Add(Trim(LTerm), AIndex);
  end;
end;

constructor TCatalogScanner.Create(ARussian: Boolean);
begin
  inherited Create;
  FMatcher := TMatcher.Create(ARussian);
  FIngredients := TStringList.Create;
  FSymptoms := TStringList.Create;
  FColumns := TStringList.Create;
  FColumns.StrictDelimiter := True;
  FColumns.Delimiter := #9;
end;

destructor TCatalogScanner.Destroy;
begin
  FColumns.Free;
  FSymptoms.Free;
  FIngredients.Free;
  FMatcher.Free;
  inherited Destroy;
end;

procedure TCatalogScanner.LoadTerms(const ADirectory: String; AExpanded: Boolean;
  const AExtraTerms: String);
var
  LLines: TStringList;
  LFields: TStringArray;
  LRow: Integer;
  LIndex: Integer;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := ReadBytes(ADirectory + 'ingredients.tsv');
    for LRow := 1 to LLines.Count - 1 do
    begin
      LFields := LLines[LRow].Split([#9]);
      if Length(LFields) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [LRow + 1]);
      end;
      LIndex := FIngredients.Add(LFields[1]);
      if (AExtraTerms = '') or ((LFields[1] <> 'date') and (LFields[1] <> 'fig')) then
      begin
        FMatcher.Add(LFields[1], LIndex);
      end;
      AddTerms(FMatcher, LFields[3], LIndex);
    end;
    if AExpanded then
    begin
      LLines.Text := ReadBytes(ADirectory + 'exposure-expansions.tsv');
      for LRow := 1 to LLines.Count - 1 do
      begin
        LFields := LLines[LRow].Split([#9]);
        if Length(LFields) <> 3 then
        begin
          raise EConvertError.CreateFmt('Invalid exposure expansion row %d', [LRow + 1]);
        end;
        LIndex := FIngredients.IndexOf(LFields[0]);
        if (LIndex < 0) or ((LFields[1] <> 'name') and (LFields[1] <> 'related')) then
        begin
          raise EConvertError.CreateFmt('Unrecognized exposure expansion row %d', [LRow + 1]);
        end;
        AddTerms(FMatcher, LFields[2], LIndex);
      end;
    end;
    LLines.Text := ReadBytes(ADirectory + 'symptoms.tsv');
    for LRow := 1 to LLines.Count - 1 do
    begin
      LFields := LLines[LRow].Split([#9]);
      if Length(LFields) <> 2 then
      begin
        raise EConvertError.CreateFmt('Invalid symptom row %d', [LRow + 1]);
      end;
      LIndex := FIngredients.Count + FSymptoms.Add(LFields[0]);
      FMatcher.Add(LFields[0], LIndex);
      AddTerms(FMatcher, LFields[1], LIndex);
    end;
  finally
    LLines.Free;
  end;
  if AExtraTerms <> '' then
  begin
    LoadExtraTerms(AExtraTerms);
  end;
  SetLength(FFlags, FIngredients.Count + FSymptoms.Count);
  SetLength(FFocus, Length(FFlags));
  FMatcher.Prepare;
end;

procedure TCatalogScanner.LoadExtraTerms(const APath: String);
var
  LLines: TStringList;
  LFields: TStringArray;
  LRow: Integer;
  LIndex: Integer;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := ReadBytes(APath);
    if (LLines.Count < 2) or (LLines[0] <> 'scope'#9'label'#9'terms') then
    begin
      raise EConvertError.Create('Missing index vocabulary or unexpected header');
    end;
    for LRow := 1 to LLines.Count - 1 do
    begin
      LFields := LLines[LRow].Split([#9]);
      if (Length(LFields) <> 3) or (Trim(LFields[2]) = '') then
      begin
        raise EConvertError.CreateFmt('Invalid index vocabulary row %d', [LRow + 1]);
      end;
      LIndex := -1;
      if LFields[0] = 'ingredient' then
      begin
        LIndex := FIngredients.IndexOf(LFields[1]);
      end
      else if LFields[0] = 'symptom' then
      begin
        LIndex := FSymptoms.IndexOf(LFields[1]);
        if LIndex >= 0 then
        begin
          Inc(LIndex, FIngredients.Count);
        end;
      end;
      if LIndex < 0 then
      begin
        raise EConvertError.CreateFmt('Unknown index vocabulary label on row %d', [LRow + 1]);
      end;
      AddTerms(FMatcher, LFields[2], LIndex);
    end;
  finally
    LLines.Free;
  end;
end;

procedure TCatalogScanner.GatherFiles(const ARoot, ARelative: String; AFiles: TStrings);
var
  LEntry: TSearchRec;
  LPath: String;
  LStatus: Integer;
begin
  LStatus := FindFirst(ARoot + ARelative + '*', faAnyFile, LEntry);
  if LStatus <> 0 then
  begin
    if (LStatus <> 2) and (LStatus <> 18) then
    begin
      raise EInOutError.CreateFmt('Cannot enumerate %s (error %d)', [ARelative, LStatus]);
    end;
    Exit;
  end;
  try
    repeat
      if (LEntry.Name = '.') or (LEntry.Name = '..') then
      begin
        Continue;
      end;
      LPath := ARelative + LEntry.Name;
      if (LEntry.Attr and faDirectory) <> 0 then
      begin
        GatherFiles(ARoot, LPath + PathDelim, AFiles);
      end
      else
      begin
        AFiles.Add(LPath);
      end;
    until FindNext(LEntry) <> 0;
  finally
    FindClose(LEntry);
  end;
end;

function TCatalogScanner.Mark(const AContent: RawByteString): Boolean;
var
  LIndex: Integer;
begin
  FillChar(FFlags[0], Length(FFlags) * SizeOf(Boolean), 0);
  FMatcher.Match(AContent, FFlags);
  for LIndex := 0 to FIngredients.Count - 1 do
  begin
    if FFlags[LIndex] then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TCatalogScanner.WriteCandidate(const APath, ALocator, ATitle: String);
begin
  Inc(FMatchCount);
  Write(FMatches, APath, #9, CleanCell(ALocator), #9, CleanCell(ATitle), #9,
    JoinMatches(FIngredients, FFlags, 0), #9,
    JoinMatches(FSymptoms, FFlags, FIngredients.Count), #9,
    JoinMatches(FIngredients, FFocus, 0), #9,
    JoinMatches(FSymptoms, FFocus, FIngredients.Count), #10);
end;

procedure TCatalogScanner.ScanTable(const APath: String; const AContent: RawByteString);
var
  LRow: Integer;
  LFirst: Integer;
  LEnd: Integer;
  LText: RawByteString;
  LTitleIndex: Integer;
  LIdIndex: Integer;
  LTitle: String;
  LLocator: String;
begin
  LRow := 0;
  LFirst := 1;
  LTitleIndex := -1;
  LIdIndex := -1;
  while LFirst <= Length(AContent) do
  begin
    LEnd := LFirst;
    while (LEnd <= Length(AContent)) and (AContent[LEnd] <> #10) do
    begin
      Inc(LEnd);
    end;
    LText := TrimRight(Copy(AContent, LFirst, LEnd - LFirst));
    Inc(LRow);
    LFirst := LEnd + 1;
    if LRow = 1 then
    begin
      FColumns.DelimitedText := LText;
      LTitleIndex := FColumns.IndexOf('title');
      LIdIndex := FColumns.IndexOf('pmid');
      if LIdIndex < 0 then
      begin
        LIdIndex := FColumns.IndexOf('nct_id');
      end;
    end;
    if LText = '' then
    begin
      Continue;
    end;
    Inc(FRecordCount);
    if not Mark(LText) then
    begin
      Continue;
    end;
    FillChar(FFocus[0], Length(FFocus) * SizeOf(Boolean), 0);
    FColumns.DelimitedText := LText;
    LTitle := '';
    LLocator := 'L' + IntToStr(LRow);
    if (LTitleIndex >= 0) and (LTitleIndex < FColumns.Count) then
    begin
      LTitle := FColumns[LTitleIndex];
      FMatcher.Match(LTitle, FFocus);
    end;
    if (LIdIndex >= 0) and (LIdIndex < FColumns.Count) then
    begin
      LLocator := LLocator + ' ' + FColumns[LIdIndex];
    end;
    WriteCandidate(APath, LLocator, LTitle);
  end;
end;

procedure TCatalogScanner.ScanDocument(const APath: String; const AContent: RawByteString);
var
  LEnd: Integer;
  LTitle: String;
begin
  Inc(FRecordCount);
  if not Mark(AContent) then
  begin
    Exit;
  end;
  LEnd := Pos(#10, AContent);
  if LEnd = 0 then
  begin
    LEnd := Length(AContent) + 1;
  end;
  LTitle := Trim(Copy(AContent, 1, LEnd - 1));
  if LTitle.StartsWith('Title: ') then
  begin
    Delete(LTitle, 1, 7);
  end;
  FillChar(FFocus[0], Length(FFocus) * SizeOf(Boolean), 0);
  FMatcher.Match(Copy(AContent, 1, 8000), FFocus);
  WriteCandidate(APath, '', LTitle);
end;

procedure TCatalogScanner.ScanFile(const ARoot, ARelative: String);
var
  LContent: RawByteString;
  LPath: String;
  LExtension: String;
  LKind: String;
  LStatus: String;
  LDetail: String;
  LBefore: Integer;
  LSize: Int64;
begin
  Inc(FFileCount);
  LPath := 'research/' + StringReplace(ARelative, PathDelim, '/', [rfReplaceAll]);
  LExtension := LowerCase(ExtractFileExt(ARelative));
  LBefore := FRecordCount;
  LSize := 0;
  LDetail := '';
  LStatus := 'Scanned';
  if LExtension = '.txt' then
  begin
    LKind := 'source_text';
  end
  else if LExtension = '.tsv' then
  begin
    LKind := 'tabular_catalog';
  end
  else if LExtension = '.md' then
  begin
    LKind := 'annotation';
  end
  else if LExtension = '.py' then
  begin
    LKind := 'archive_tool';
  end
  else
  begin
    LKind := 'other';
  end;
  if LKind = 'archive_tool' then
  begin
    LStatus := 'Noncatalog';
    LDetail := 'Repository collector source code';
  end
  else if LKind = 'other' then
  begin
    LStatus := 'Unsupported';
    LDetail := 'No text extraction for this extension';
    Inc(FFailureCount);
  end
  else
  begin
    try
      LContent := ReadBytes(ARoot + ARelative);
      LSize := Length(LContent);
    except
      on LException: Exception do
      begin
        LStatus := 'Unreadable';
        LDetail := LException.Message;
        Inc(FFailureCount);
      end;
    end;
    if LStatus = 'Scanned' then
    begin
      if LKind = 'tabular_catalog' then
      begin
        ScanTable(LPath, LContent);
      end
      else
      begin
        ScanDocument(LPath, LContent);
      end;
    end;
  end;
  Write(FCoverage, LPath, #9, LSize, #9, LKind, #9, LStatus, #9,
    FRecordCount - LBefore, #9, CleanCell(LDetail), #10);
  if (FFileCount mod 5000) = 0 then
  begin
    WriteLn(FFileCount, ' catalog paths scanned');
  end;
end;

procedure TCatalogScanner.Scan(const AExperiment, AResearch, AOutput: String; AExpanded: Boolean);
var
  LFiles: TStringList;
  LRelative: String;
  LOutput: String;
  LResearch: String;
begin
  RequireFreeze(AExperiment);
  LoadTerms(IncludeTrailingPathDelimiter(AExperiment), AExpanded);
  LResearch := IncludeTrailingPathDelimiter(AResearch);
  LOutput := IncludeTrailingPathDelimiter(AOutput);
  if not DirectoryExists(AResearch) then
  begin
    raise EInOutError.Create('Research directory does not exist');
  end;
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create scanner output directory');
  end;
  LFiles := TStringList.Create;
  try
    GatherFiles(LResearch, '', LFiles);
    LFiles.Sort;
    AssignFile(FCoverage, LOutput + 'local-coverage.tsv');
    SetTextBuf(FCoverage, FCoverageBuffer);
    Rewrite(FCoverage);
    try
      AssignFile(FMatches, LOutput + 'local-matches.tsv');
      SetTextBuf(FMatches, FMatchBuffer);
      Rewrite(FMatches);
      try
        Write(FCoverage, CatalogCoverageHeader, #10);
        Write(FMatches, CatalogMatchesHeader, #10);
        for LRelative in LFiles do
        begin
          ScanFile(LResearch, LRelative);
        end;
      finally
        CloseFile(FMatches);
      end;
    finally
      CloseFile(FCoverage);
    end;
  finally
    LFiles.Free;
  end;
  WriteLn('Paths ', FFileCount, ', records ', FRecordCount, ', matches ', FMatchCount,
    ', extraction failures ', FFailureCount);
end;

procedure CheckMatcher;
var
  LMatcher: TMatcher;
  LFlags: TMatchFlags;
begin
  LMatcher := TMatcher.Create;
  try
    LMatcher.Add('olive oil', 0);
    LMatcher.Add('oil', 1);
    LMatcher.Add('rest tremor', 2);
    LMatcher.Add('cafe', 3);
    LMatcher.Add('apple', 4);
    LMatcher.Add(#$C5#$93'uf', 5);
    LMatcher.Prepare;
    SetLength(LFlags, 6);
    LMatcher.Match('OLIVE-oil, café, and REST' + #10 + 'TREMOR. Pineapple.', LFlags);
    Assert(LFlags[0] and LFlags[1] and LFlags[2] and LFlags[3] and not LFlags[4]);
    LMatcher.Match('UF Health', LFlags);
    Assert(not LFlags[5]);
    LMatcher.Match(#$C5#$92'UF', LFlags);
    Assert(LFlags[5]);
    LFlags[5] := False;
    LMatcher.Match('oeuf', LFlags);
    Assert(LFlags[5]);
  finally
    LMatcher.Free;
  end;

  LMatcher := TMatcher.Create(True);
  try
    LMatcher.Add('свёкла', 0);
    LMatcher.Add('тремор покоя', 1);
    LMatcher.Add('cafe', 2);
    LMatcher.Prepare;
    FillChar(LFlags[0], Length(LFlags) * SizeOf(Boolean), 0);
    LMatcher.Match('подсвекла и тремор покоящийся', LFlags);
    Assert(not LFlags[0] and not LFlags[1]);
    LMatcher.Match('СВЕКЛА, ТРЕМОР-ПОКОЯ и café', LFlags);
    Assert(LFlags[0] and LFlags[1] and LFlags[2]);
  finally
    LMatcher.Free;
  end;
  WriteLn('PASS catalog matcher fixtures');
end;

function TCatalogScanner.LoadIndexClaims(const APath: String): TIndexClaims;
var
  LLines: TStringList;
  LFields: TStringArray;
  LRow: Integer;
  LIngredient: Integer;
  LSymptom: Integer;
begin
  Result := nil;
  LLines := TStringList.Create;
  try
    LLines.Text := ReadBytes(APath);
    if (LLines.Count <> 1001) or
      (LLines[0] <> 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9 +
        'statement') then
    begin
      raise EConvertError.Create('Unexpected frozen claim format');
    end;
    SetLength(Result, LLines.Count - 1);
    for LRow := 1 to LLines.Count - 1 do
    begin
      LFields := LLines[LRow].Split([#9]);
      if (Length(LFields) <> 7) or (LFields[0] <> Format('%.4d', [LRow])) then
      begin
        raise EConvertError.CreateFmt('Invalid frozen claim row %d', [LRow + 1]);
      end;
      LIngredient := FIngredients.IndexOf(LFields[2]);
      LSymptom := FSymptoms.IndexOf(LFields[4]);
      if (LIngredient < 0) or (LSymptom < 0) then
      begin
        raise EConvertError.CreateFmt('Missing vocabulary for claim %s', [LFields[0]]);
      end;
      Result[LRow - 1].Id := LFields[0];
      Result[LRow - 1].IngredientIndex := LIngredient;
      Result[LRow - 1].SymptomIndex := FIngredients.Count + LSymptom;
    end;
  finally
    LLines.Free;
  end;
end;

function MarkIndexClaims(var AClaims: TIndexClaims; const AFlags, ATitle: TMatchFlags): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AClaims) do
  begin
    with AClaims[LIndex] do
    begin
      if not AFlags[IngredientIndex] then
      begin
        Continue;
      end;
      Inc(ExposureCount);
      if ATitle[IngredientIndex] then
      begin
        Inc(TitleExposureCount);
        if ATitle[SymptomIndex] then
        begin
          Inc(TitleJointCount);
        end;
      end;
      if AFlags[SymptomIndex] then
      begin
        Inc(JointCount);
        if Result <> '' then
        begin
          Result := Result + '|';
        end;
        Result := Result + Id;
      end;
    end;
  end;
end;

procedure WriteIndexClaimCounts(const APath: String; const AClaims: TIndexClaims);
var
  LOutput: Text;
  LClaim: TIndexClaim;
begin
  AssignFile(LOutput, APath);
  Rewrite(LOutput);
  try
    SetTextCodePage(LOutput, CP_UTF8);
    Write(LOutput, 'id'#9'exposure_records'#9'title_exposure_records'#9'joint_records'#9 +
      'title_joint_records', #10);
    for LClaim in AClaims do
    begin
      Write(LOutput, LClaim.Id, #9, LClaim.ExposureCount, #9, LClaim.TitleExposureCount, #9,
        LClaim.JointCount, #9, LClaim.TitleJointCount, #10);
    end;
  finally
    CloseFile(LOutput);
  end;
end;

procedure TCatalogScanner.ScanIndex(const AExperiment, AIndex, AExtraTerms, AOutput,
  ALanguage: String);
var
  LLines: TStringList;
  LSeen: TStringList;
  LFields: TStringArray;
  LIdentifier: String;
  LRecordId: String;
  LLanguage: String;
  LTitle: String;
  LAbstract: String;
  LClaimOutput: String;
  LClaims: TIndexClaims;
  LOutput: Text;
  LRow: Integer;
  LIndex: Integer;
  LTitleIndex: Integer;
  LOpenAlex: Boolean;
  LScanned: Integer;
begin
  RequireFreeze(AExperiment);
  LoadTerms(IncludeTrailingPathDelimiter(AExperiment), True, AExtraTerms);
  LClaimOutput := ChangeFileExt(AOutput, '.claims.tsv');
  if FileExists(AOutput) or FileExists(LClaimOutput) then
  begin
    raise EInOutError.Create('Use a new index screen output path');
  end;
  LClaims := LoadIndexClaims(IncludeTrailingPathDelimiter(AExperiment) + 'freeze.tsv');
  LLines := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LLines.Text := ReadBytes(AIndex);
    if (LLines.Count < 2) or ((LLines[0] <> IndexHeader) and (LLines[0] <> ThesisIndexHeader) and
      (LLines[0] <> ProceedingsIndexHeader) and (LLines[0] <> OpenAlexIndexHeader)) then
    begin
      raise EConvertError.Create('Missing bibliographic index or unexpected header');
    end;
    LOpenAlex := LLines[0] = OpenAlexIndexHeader;
    if LOpenAlex then
    begin
      LIdentifier := 'work_id';
      LTitleIndex := 2;
    end
    else
    begin
      LFields := LLines[0].Split([#9]);
      LIdentifier := LFields[1];
      LTitleIndex := 3;
    end;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LScanned := 0;
    AssignFile(LOutput, AOutput);
    Rewrite(LOutput);
    try
      SetTextCodePage(LOutput, CP_UTF8);
      Write(LOutput, 'docid', #9, LIdentifier, #9, IndexScreenFields, #10);
      for LRow := 1 to LLines.Count - 1 do
      begin
        LFields := LLines[LRow].Split([#9]);
        if Length(LFields) <> LTitleIndex + 2 then
        begin
          raise EConvertError.CreateFmt('Invalid bibliographic index row %d', [LRow + 1]);
        end;
        LRecordId := LFields[0];
        if not LOpenAlex then
        begin
          LRecordId := LFields[1];
        end;
        LTitle := LFields[LTitleIndex];
        LAbstract := LFields[LTitleIndex + 1];
        if (LFields[0] = '') or (LRecordId = '') or (LTitle = '') then
        begin
          raise EConvertError.CreateFmt('Missing index identifier or title on row %d', [LRow + 1]);
        end;
        LSeen.Add(LFields[0]);
        LLanguage := LFields[LTitleIndex - 1];
        if (ALanguage <> '') and (LLanguage <> ALanguage) then
        begin
          Continue;
        end;
        Inc(LScanned);
        Mark(LTitle);
        for LIndex := 0 to High(FFlags) do
        begin
          FFocus[LIndex] := FFlags[LIndex];
        end;
        FMatcher.Match(LAbstract, FFlags);
        Write(LOutput, LFields[0], #9, LRecordId, #9, LLanguage, #9, LTitle, #9,
          BoolToStr(LAbstract <> '', True), #9, JoinMatches(FIngredients, FFlags, 0), #9,
          JoinMatches(FSymptoms, FFlags, FIngredients.Count), #9,
          JoinMatches(FIngredients, FFocus, 0), #9,
          JoinMatches(FSymptoms, FFocus, FIngredients.Count), #9,
          MarkIndexClaims(LClaims, FFlags, FFocus), #10);
      end;
    finally
      CloseFile(LOutput);
    end;
    WriteIndexClaimCounts(LClaimOutput, LClaims);
    WriteLn(LScanned, ' bibliographic records screened for vocabulary matches');
  finally
    LSeen.Free;
    LLines.Free;
  end;
end;

procedure ScanTopics(const AIndex, ATerms, AOutput: String);
var
  LLines: TStringList;
  LNames: TStringList;
  LMatcher: TMatcher;
  LFields: TStringArray;
  LFlags: TMatchFlags;
  LOutput: Text;
  LRow: Integer;
begin
  if FileExists(AOutput) then
  begin
    raise EInOutError.Create('Use a new topic screen output path');
  end;
  LLines := TStringList.Create;
  LNames := TStringList.Create;
  LMatcher := TMatcher.Create;
  try
    LLines.Text := ReadBytes(AIndex);
    if (LLines.Count < 2) or (LLines[0] <> ProceedingsIndexHeader) then
    begin
      raise EConvertError.Create('Missing proceedings index or unexpected header');
    end;
    LoadTermGroups(ATerms, LMatcher, LNames);
    SetLength(LFlags, LNames.Count);
    AssignFile(LOutput, AOutput);
    Rewrite(LOutput);
    try
      SetTextCodePage(LOutput, CP_UTF8);
      Write(LOutput, 'docid'#9'presentation_id'#9'topics'#10);
      for LRow := 1 to LLines.Count - 1 do
      begin
        LFields := LLines[LRow].Split([#9]);
        if (Length(LFields) <> 5) or (LFields[0] = '') or (LFields[1] = '') or
          (LFields[3] = '') then
        begin
          raise EConvertError.CreateFmt('Invalid proceedings index row %d', [LRow + 1]);
        end;
        FillChar(LFlags[0], Length(LFlags) * SizeOf(Boolean), 0);
        LMatcher.Match(LFields[3], LFlags);
        LMatcher.Match(LFields[4], LFlags);
        Write(LOutput, LFields[0], #9, LFields[1], #9, JoinMatches(LNames, LFlags, 0), #10);
      end;
    finally
      CloseFile(LOutput);
    end;
    WriteLn(LLines.Count - 1, ' proceedings records screened for topic terms');
  finally
    LMatcher.Free;
    LNames.Free;
    LLines.Free;
  end;
end;

var
  GScanner: TCatalogScanner;

begin
  try
    if (ParamCount = 1) and (ParamStr(1) = 'check') then
    begin
      CheckMatcher;
    end
    else if ((ParamCount = 5) or (ParamCount = 6)) and (ParamStr(1) = 'scan-index') then
    begin
      SetMultiByteConversionCodePage(CP_UTF8);
      GScanner := TCatalogScanner.Create(ParamStr(6) = 'ru');
      try
        GScanner.ScanIndex(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5), ParamStr(6));
      finally
        GScanner.Free;
      end;
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'scan-topics') then
    begin
      SetMultiByteConversionCodePage(CP_UTF8);
      ScanTopics(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 4) and ((ParamStr(1) = 'scan') or (ParamStr(1) = 'scan-expanded')) then
    begin
      GScanner := TCatalogScanner.Create;
      try
        GScanner.Scan(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(1) = 'scan-expanded');
      finally
        GScanner.Free;
      end;
    end
    else
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.scan check | scan|scan-expanded <experiment> <research> <output>' +
        LineEnding + '       foodexperiment.scan scan-index EXPERIMENT INDEX EXTRA_TERMS OUTPUT [LANGUAGE]' +
        LineEnding + '       foodexperiment.scan scan-topics INDEX TOPICS OUTPUT');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
