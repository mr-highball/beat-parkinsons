{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentScreen;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.matching;

const
  ClaimCount = 1000;
  QueryCount = ClaimCount * 2;
  ExternalQueryHeader = 'query_id'#9'claim_id'#9'variant'#9'searched_utc'#9'query'#9 +
    'status'#9'hit_count'#9'returned_count'#9'error';
  ExternalResultHeader = 'query_id'#9'claim_id'#9'rank'#9'pmid'#9'doi'#9'pmcid'#9 +
    'title'#9'journal'#9'publication_date'#9'abstract';
  LocalMatchHeader = 'path'#9'locator'#9'title'#9'ingredients'#9'symptoms'#9 +
    'focused_ingredients'#9'focused_symptoms';
  ReviewHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9'local_verdict';

type
  TClaim = record
    Ingredient: String;
    Symptom: String;
    Category: String;
    Direction: String;
    IngredientIndex: Integer;
    SymptomIndex: Integer;
    LocalPairs: Integer;
    FocusedLocalPairs: Integer;
    RetrievedResults: Integer;
    ExternalCandidates: Integer;
    Verdict: String;
    Confidence: String;
    Rationale: String;
    References: String;
    LocalVerdict: String;
  end;

  TQuery = record
    SearchDate: String;
    Expression: String;
    Hits: Integer;
    Returned: Integer;
    Screened: Integer;
    Candidates: Integer;
    Retrieved: Boolean;
    Ranks: set of 1..20;
  end;

  TScreen = class
  private
    FClaims: array[1..ClaimCount] of TClaim;
    FQueries: array[1..QueryCount] of TQuery;
    FIngredients: TStringList;
    FSymptoms: TStringList;
    FDispositions: TStringList;
    FMatcher: TMatcher;
    FText: TMatchFlags;
    FTitle: TMatchFlags;
    procedure LoadVocabulary(const ARoot: String);
    procedure LoadClaims(const ARoot: String);
    procedure LoadQueries(const AExternal: String);
    procedure LoadDispositions(const ARoot: String);
    procedure ScreenExternal(const AExternal, AOutput: String);
    procedure ScreenLocal(const ALocal, AOutput: String);
    procedure LoadReview(const APath: String);
    procedure WriteCoverage(const AOutput: String);
    procedure WriteVerdicts(const ARoot: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, ALocal, AExternal, AOutput, AReview: String);
  end;

function ClaimNumber(const AValue: String): Integer;
begin
  if (Length(AValue) <> 4) or not TryStrToInt(AValue, Result)
    or (Result < 1) or (Result > ClaimCount) then
  begin
    raise EConvertError.Create('Invalid claim identifier ' + AValue);
  end;
end;

function ClaimId(AClaim: Integer): String;
begin
  Result := Format('%.4d', [AClaim]);
end;

function QueryId(AQuery: Integer): String;
begin
  Result := ClaimId((AQuery + 1) div 2) + '-' + IntToStr((AQuery - 1) mod 2 + 1);
end;

function QueryNumber(const AValue: String): Integer;
var
  LVariant: Integer;
begin
  if (Length(AValue) <> 6) or (AValue[5] <> '-')
    or not TryStrToInt(AValue[6], LVariant) or (LVariant < 1) or (LVariant > 2) then
  begin
    raise EConvertError.Create('Invalid query identifier ' + AValue);
  end;
  Result := (ClaimNumber(Copy(AValue, 1, 4)) - 1) * 2 + LVariant;
end;

function CountValue(const AValue: String): Integer;
begin
  if not TryStrToInt(AValue, Result) or (Result < 0) then
  begin
    raise EConvertError.Create('Invalid count ' + AValue);
  end;
end;

function HasValue(const AList, AValue: String): Boolean;
begin
  Result := Pos('|' + AValue + '|', '|' + AList + '|') > 0;
end;

procedure ReadHeader(var AFile: Text; const AExpected: String);
var
  LHeader: String;
begin
  ReadLn(AFile, LHeader);
  if LHeader <> AExpected then
  begin
    raise EConvertError.Create('Unexpected TSV header ' + LHeader);
  end;
end;

function ReadFields(var AFile: Text; ACount: Integer): TStringArray;
var
  LLine: String;
begin
  ReadLn(AFile, LLine);
  Result := LLine.Split([#9]);
  if Length(Result) <> ACount then
  begin
    raise EConvertError.CreateFmt('Expected %d TSV fields, received %d',
      [ACount, Length(Result)]);
  end;
end;

procedure WriteRow(var AFile: Text; const AFields: array of String);
var
  LIndex: Integer;
begin
  for LIndex := Low(AFields) to High(AFields) do
  begin
    if LIndex > Low(AFields) then
    begin
      Write(AFile, #9);
    end;
    Write(AFile, CleanCell(AFields[LIndex]));
  end;
  Write(AFile, #10);
end;

constructor TScreen.Create;
begin
  inherited Create;
  FIngredients := TStringList.Create;
  FSymptoms := TStringList.Create;
  FDispositions := TStringList.Create;
  FDispositions.NameValueSeparator := #9;
  FMatcher := TMatcher.Create;
end;

destructor TScreen.Destroy;
begin
  FMatcher.Free;
  FDispositions.Free;
  FSymptoms.Free;
  FIngredients.Free;
  inherited Destroy;
end;

procedure TScreen.LoadVocabulary(const ARoot: String);
var
  LFile: Text;
  LFields: TStringArray;
  LAliases: TStringArray;
  LTerm: String;
  LIndex: Integer;
begin
  AssignFile(LFile, ARoot + 'ingredients.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, 'category'#9'ingredient'#9'forms'#9'aliases');
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 4);
      LIndex := FIngredients.Add(LFields[1]);
      FMatcher.Add(LFields[1], LIndex);
      LAliases := LFields[3].Split(['|']);
      for LTerm in LAliases do
      begin
        FMatcher.Add(LTerm, LIndex);
      end;
    end;
  finally
    CloseFile(LFile);
  end;
  AssignFile(LFile, ARoot + 'symptoms.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, 'symptom'#9'aliases');
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 2);
      LIndex := FIngredients.Count + FSymptoms.Add(LFields[0]);
      FMatcher.Add(LFields[0], LIndex);
      LAliases := LFields[1].Split(['|']);
      for LTerm in LAliases do
      begin
        FMatcher.Add(LTerm, LIndex);
      end;
    end;
  finally
    CloseFile(LFile);
  end;
  FMatcher.Prepare;
  SetLength(FText, FIngredients.Count + FSymptoms.Count);
  SetLength(FTitle, Length(FText));
end;

procedure TScreen.LoadClaims(const ARoot: String);
var
  LFile: Text;
  LFields: TStringArray;
  LClaim: Integer;
  LNumber: Integer;
begin
  AssignFile(LFile, ARoot + 'freeze.tsv');
  Reset(LFile);
  LNumber := 0;
  try
    ReadHeader(LFile, 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9 +
      'direction'#9'statement');
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 7);
      LClaim := ClaimNumber(LFields[0]);
      if FClaims[LClaim].Ingredient <> '' then
      begin
        raise EConvertError.Create('Duplicate frozen claim ' + LFields[0]);
      end;
      Inc(LNumber);
      FClaims[LClaim].Category := LFields[1];
      FClaims[LClaim].Ingredient := LFields[2];
      FClaims[LClaim].Symptom := LFields[4];
      FClaims[LClaim].Direction := LFields[5];
      FClaims[LClaim].IngredientIndex := FIngredients.IndexOf(LFields[2]);
      FClaims[LClaim].SymptomIndex := FSymptoms.IndexOf(LFields[4]);
      if (FClaims[LClaim].IngredientIndex < 0) or (FClaims[LClaim].SymptomIndex < 0) then
      begin
        raise EConvertError.Create('Unknown frozen ingredient or symptom');
      end;
      Inc(FClaims[LClaim].SymptomIndex, FIngredients.Count);
    end;
  finally
    CloseFile(LFile);
  end;
  if LNumber <> ClaimCount then
  begin
    raise EConvertError.Create('Missing frozen claims');
  end;
end;

procedure TScreen.LoadQueries(const AExternal: String);
var
  LFile: Text;
  LFields: TStringArray;
  LQuery: Integer;
begin
  AssignFile(LFile, AExternal + 'external_queries.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, ExternalQueryHeader);
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 9);
      LQuery := QueryNumber(LFields[0]);
      if (FQueries[LQuery].Expression <> '') or (LFields[1] <> ClaimId((LQuery + 1) div 2)) then
      begin
        raise EConvertError.Create('Duplicate or mismatched query ' + LFields[0]);
      end;
      FQueries[LQuery].Expression := LFields[4];
      FQueries[LQuery].SearchDate := Copy(LFields[3], 1, 10);
      FQueries[LQuery].Retrieved := LFields[5] = 'Retrieved';
      if FQueries[LQuery].Retrieved then
      begin
        FQueries[LQuery].Hits := CountValue(LFields[6]);
        FQueries[LQuery].Returned := CountValue(LFields[7]);
      end;
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.LoadDispositions(const ARoot: String);
var
  LFile: Text;
  LFields: TStringArray;
begin
  AssignFile(LFile, ARoot + 'source-dispositions.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, 'source_key'#9'disposition');
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 2);
      if (LFields[0] = '') or (LFields[1] = '') or
        (FDispositions.IndexOfName(LFields[0]) >= 0) then
      begin
        raise EConvertError.Create('Invalid or duplicate source review ' + LFields[0]);
      end;
      FDispositions.Add(LFields[0] + #9 + LFields[1]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.ScreenExternal(const AExternal, AOutput: String);
var
  LFile: Text;
  LOutput: Text;
  LBuffer: array[0..65535] of Byte;
  LFields: TStringArray;
  LQuery: Integer;
  LClaim: Integer;
  LRank: Integer;
  LExposure: Integer;
  LSymptom: Integer;
  LStatus: String;
  LFocus: String;
  LLowerTitle: String;
  LSourceKey: String;
  LDisposition: String;
begin
  AssignFile(LFile, AExternal + 'external_results.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, ExternalResultHeader);
    AssignFile(LOutput, AOutput + 'external-screening.tsv');
    SetTextBuf(LOutput, LBuffer);
    Rewrite(LOutput);
    try
      WriteRow(LOutput, ['query_id', 'claim_id', 'rank', 'pmid', 'doi', 'pmcid',
        'title', 'screen', 'focus', 'source_key', 'disposition']);
      while not Eof(LFile) do
      begin
        LFields := ReadFields(LFile, 10);
        LQuery := QueryNumber(LFields[0]);
        LClaim := ClaimNumber(LFields[1]);
        LRank := CountValue(LFields[2]);
        if (LClaim <> (LQuery + 1) div 2) or not FQueries[LQuery].Retrieved
          or (LRank < 1) or (LRank > 20) or (LRank > FQueries[LQuery].Returned)
          or (LRank in FQueries[LQuery].Ranks) then
        begin
          raise EConvertError.Create('Invalid search result rank ' + LFields[0]);
        end;
        Include(FQueries[LQuery].Ranks, LRank);
        Inc(FQueries[LQuery].Screened);
        Inc(FClaims[LClaim].RetrievedResults);
        LExposure := FClaims[LClaim].IngredientIndex;
        LSymptom := FClaims[LClaim].SymptomIndex;
        FillChar(FText[0], Length(FText) * SizeOf(Boolean), 0);
        FillChar(FTitle[0], Length(FTitle) * SizeOf(Boolean), 0);
        FMatcher.Match(LFields[6], FTitle);
        FMatcher.Match(LFields[6] + ' ' + LFields[9], FText);
        LLowerTitle := LowerCase(LFields[6]);
        LFocus := '';
        if FTitle[LExposure] then
        begin
          LFocus := 'ingredient in title';
        end;
        if FTitle[LSymptom] then
        begin
          LFocus := LFocus + ' symptom in title';
        end;
        if (Pos(' review', ' ' + LLowerTitle) > 0) or
          (Pos('meta-analysis', LLowerTitle) > 0) then
        begin
          LStatus := 'Citation lead';
        end
        else if FTitle[LExposure] or (FText[LExposure] and FText[LSymptom]) or
          ((LFields[9] = '') and (FTitle[LSymptom] or (Pos('diet', LLowerTitle) > 0))) then
        begin
          LStatus := 'Check applicability';
          Inc(FQueries[LQuery].Candidates);
          Inc(FClaims[LClaim].ExternalCandidates);
        end
        else if LFields[9] = '' then
        begin
          LStatus := 'Title only, no relevant match';
        end
        else
        begin
          LStatus := 'No matched exposure and outcome in title or abstract';
        end;
        if LFields[3] <> '' then
        begin
          LSourceKey := 'PMID:' + LFields[3];
        end
        else if LFields[4] <> '' then
        begin
          LSourceKey := 'DOI:' + LFields[4];
        end
        else if LFields[5] <> '' then
        begin
          LSourceKey := 'PMCID:' + LFields[5];
        end
        else
        begin
          LSourceKey := 'TITLE:' + LFields[6];
        end;
        LDisposition := FDispositions.Values[LSourceKey];
        if (FDispositions.Count > 0) and (LStatus = 'Check applicability') and
          (LDisposition = '') then
        begin
          raise EConvertError.Create('Missing review disposition for ' + LSourceKey);
        end;
        WriteRow(LOutput, [LFields[0], LFields[1], LFields[2], LFields[3], LFields[4],
          LFields[5], LFields[6], LStatus, Trim(LFocus), LSourceKey, LDisposition]);
      end;
    finally
      CloseFile(LOutput);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.ScreenLocal(const ALocal, AOutput: String);
var
  LFile: Text;
  LOutput: Text;
  LBuffer: array[0..65535] of Byte;
  LFields: TStringArray;
  LNames: TStringArray;
  LName: String;
  LClaim: Integer;
  LByIngredient: array of array of Integer;
  LIngredient: Integer;
  LCount: Integer;
  LPriority: String;
  LTitle: String;
begin
  SetLength(LByIngredient, FIngredients.Count);
  for LClaim := 1 to ClaimCount do
  begin
    LIngredient := FClaims[LClaim].IngredientIndex;
    LCount := Length(LByIngredient[LIngredient]);
    SetLength(LByIngredient[LIngredient], LCount + 1);
    LByIngredient[LIngredient][LCount] := LClaim;
  end;
  AssignFile(LFile, ALocal + 'local-matches.tsv');
  Reset(LFile);
  try
    ReadHeader(LFile, LocalMatchHeader);
    AssignFile(LOutput, AOutput + 'local-screening.tsv');
    SetTextBuf(LOutput, LBuffer);
    Rewrite(LOutput);
    try
      WriteRow(LOutput, ['claim_id', 'path', 'locator', 'title', 'screen']);
      while not Eof(LFile) do
      begin
        LFields := ReadFields(LFile, 7);
        if (LFields[4] = '') or (LFields[1] = 'L1') or LFields[1].StartsWith('L1 ') then
        begin
          Continue;
        end;
        LNames := LFields[3].Split(['|']);
        FillChar(FTitle[0], Length(FTitle) * SizeOf(Boolean), 0);
        FMatcher.Match(LFields[2], FTitle);
        LTitle := LowerCase(LFields[2]);
        for LName in LNames do
        begin
          LIngredient := FIngredients.IndexOf(LName);
          if LIngredient < 0 then
          begin
            Continue;
          end;
          for LClaim in LByIngredient[LIngredient] do
          begin
            if not HasValue(LFields[4], FClaims[LClaim].Symptom) then
            begin
              Continue;
            end;
            Inc(FClaims[LClaim].LocalPairs);
            if FTitle[LIngredient] then
            begin
              LPriority := 'Ingredient in title';
            end
            else if HasValue(LFields[5], LName) and
              HasValue(LFields[6], FClaims[LClaim].Symptom) then
            begin
              LPriority := 'Exposure and outcome in first 8000 bytes';
            end
            else if Pos('diet', LTitle) > 0 then
            begin
              LPriority := 'Diet title with exposure and outcome terms';
            end
            else
            begin
              Continue;
            end;
            Inc(FClaims[LClaim].FocusedLocalPairs);
            WriteRow(LOutput, [ClaimId(LClaim), LFields[0], LFields[1], LFields[2], LPriority]);
          end;
        end;
      end;
    finally
      CloseFile(LOutput);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.LoadReview(const APath: String);
var
  LFile: Text;
  LFields: TStringArray;
  LClaim: Integer;
begin
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    ReadHeader(LFile, ReviewHeader);
    while not Eof(LFile) do
    begin
      LFields := ReadFields(LFile, 6);
      LClaim := ClaimNumber(LFields[0]);
      if FClaims[LClaim].Verdict <> '' then
      begin
        raise EConvertError.Create('Duplicate review for ' + LFields[0]);
      end;
      FClaims[LClaim].Verdict := LFields[1];
      FClaims[LClaim].Confidence := LFields[2];
      FClaims[LClaim].Rationale := LFields[3];
      FClaims[LClaim].References := LFields[4];
      FClaims[LClaim].LocalVerdict := LFields[5];
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.WriteCoverage(const AOutput: String);
var
  LFile: Text;
  LClaim: Integer;
begin
  AssignFile(LFile, AOutput + 'claim-coverage.tsv');
  Rewrite(LFile);
  try
    WriteRow(LFile, ['id', 'category', 'ingredient', 'symptom', 'direction', 'local_pair_hits',
      'focused_local_pair_hits', 'external_results_screened', 'external_candidates']);
    for LClaim := 1 to ClaimCount do
    begin
      WriteRow(LFile, [ClaimId(LClaim), FClaims[LClaim].Category, FClaims[LClaim].Ingredient,
        FClaims[LClaim].Symptom, FClaims[LClaim].Direction, IntToStr(FClaims[LClaim].LocalPairs),
        IntToStr(FClaims[LClaim].FocusedLocalPairs), IntToStr(FClaims[LClaim].RetrievedResults),
        IntToStr(FClaims[LClaim].ExternalCandidates)]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.WriteVerdicts(const ARoot: String);
var
  LFile: Text;
  LClaim: Integer;
  LQuery: Integer;
  LNotes: String;
begin
  for LQuery := 1 to QueryCount do
  begin
    if not FQueries[LQuery].Retrieved or (FQueries[LQuery].Expression = '') or
      (FQueries[LQuery].Screened <> FQueries[LQuery].Returned) then
    begin
      raise EConvertError.Create('External search is incomplete for ' + QueryId(LQuery));
    end;
  end;
  AssignFile(LFile, ARoot + 'queries.tsv');
  Rewrite(LFile);
  try
    WriteRow(LFile, ['query_id', 'provider', 'searched_on', 'query', 'result_count',
      'screened_count', 'status', 'notes']);
    for LQuery := 1 to QueryCount do
    begin
      LNotes := IntToStr(FQueries[LQuery].Candidates) + ' title/abstract applicability candidates';
      if FQueries[LQuery].Hits > FQueries[LQuery].Screened then
      begin
        LNotes := LNotes + '. Screened only the first returned page.';
      end;
      WriteRow(LFile, [QueryId(LQuery), 'Europe PMC', FQueries[LQuery].SearchDate,
        FQueries[LQuery].Expression, IntToStr(FQueries[LQuery].Hits),
        IntToStr(FQueries[LQuery].Screened), 'Completed', LNotes]);
    end;
  finally
    CloseFile(LFile);
  end;
  AssignFile(LFile, ARoot + 'verdicts.tsv');
  Rewrite(LFile);
  try
    WriteRow(LFile, ['id', 'verdict', 'confidence', 'rationale', 'local_references',
      'search_record', 'local_verdict']);
    for LClaim := 1 to ClaimCount do
    begin
      if FClaims[LClaim].Verdict = '' then
      begin
        FClaims[LClaim].Verdict := 'Unknown';
        FClaims[LClaim].Confidence := '50';
        FClaims[LClaim].LocalVerdict := 'Unknown';
        FClaims[LClaim].Rationale := Format(
          'No directly matched directional human Parkinson''s evidence qualified. ' +
          'Local lexical pairs: %d. External records screened: %d.',
          [FClaims[LClaim].LocalPairs, FClaims[LClaim].RetrievedResults]);
      end;
      WriteRow(LFile, [ClaimId(LClaim), FClaims[LClaim].Verdict, FClaims[LClaim].Confidence,
        FClaims[LClaim].Rationale, FClaims[LClaim].References,
        QueryId(LClaim * 2 - 1) + '|' + QueryId(LClaim * 2), FClaims[LClaim].LocalVerdict]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure TScreen.Run(const ARoot, ALocal, AExternal, AOutput, AReview: String);
var
  LRoot: String;
  LExternal: String;
  LOutput: String;
begin
  LRoot := IncludeTrailingPathDelimiter(ARoot);
  LExternal := IncludeTrailingPathDelimiter(AExternal);
  LOutput := IncludeTrailingPathDelimiter(AOutput);
  if not ForceDirectories(LOutput) then
  begin
    raise EInOutError.Create('Cannot create screening output directory');
  end;
  LoadVocabulary(LRoot);
  LoadClaims(LRoot);
  LoadQueries(LExternal);
  if AReview <> '' then
  begin
    LoadDispositions(LRoot);
    if FDispositions.Count = 0 then
    begin
      raise EConvertError.Create('Final review requires source dispositions');
    end;
  end;
  ScreenExternal(LExternal, LOutput);
  ScreenLocal(IncludeTrailingPathDelimiter(ALocal), LOutput);
  WriteCoverage(LOutput);
  if AReview <> '' then
  begin
    LoadReview(AReview);
    WriteVerdicts(LRoot);
  end;
end;

var
  GScreen: TScreen;

begin
  try
    if not (ParamCount in [4, 5]) then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.screen <experiment> <local-scan> <external> <output> [review.tsv]');
    end;
    GScreen := TScreen.Create;
    try
      GScreen.Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    finally
      GScreen.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
