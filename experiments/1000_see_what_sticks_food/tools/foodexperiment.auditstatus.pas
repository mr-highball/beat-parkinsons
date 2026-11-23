{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.auditstatus;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils;

const
  CResearchStatusHeader =
    'id'#9'research_status'#9'lab_clinical_checked'#9'cultural_checked'#9 +
    'scorecard_checked'#9'last_checked_utc'#9'search_basis'#9'open_gaps';

type
  TResearchStatusRow = record
    Id: String;
    Status: String;
    LabClinicalChecked: Boolean;
    CulturalChecked: Boolean;
    ScorecardChecked: Boolean;
    LastCheckedUtc: String;
    SearchBasis: String;
    OpenGaps: String;
  end;

  TResearchStatusSummary = record
    TotalFrozen: Integer;
    RowsPresent: Integer;
    Researched: Integer;
    Partial: Integer;
    Unreviewed: Integer;
    UnknownResearched: Integer;
    UnknownUnresearched: Integer;
    DirectionalResearched: Integer;
    DirectionalUnresearched: Integer;
  end;

function ValidIsoUtcDate(const AValue: String): Boolean;
function ParseYesNo(const AValue, AFieldName, AClaimId: String): Boolean;
function ParseResearchStatusRow(const ALine: String; ALineNumber: Integer): TResearchStatusRow;
function DisplayVerdictLabel(const AVerdict, AResearchStatus: String): String;
function EffectiveResearchStatus(const ADeclaredStatus, AScorecardStatus, AVerdict: String;
  ALabChecked, ACulturalChecked, AScorecardChecked: Boolean): String;
function VerifyExperimentResearchStatus(const AExperimentDir: String;
  ARequireFullCoverage: Boolean = False): TResearchStatusSummary;

implementation

uses
  StrUtils, Generics.Collections, fpjson, parkinsonsoracle.compat, foodexperiment.externaldata,
  foodexperiment.confidence, parkinsonsoracle.rubric;

const
  CFreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  CVerdictHeader = 'id'#9'verdict'#9'confidence'#9'rationale'#9'local_references'#9 +
    'search_record'#9'local_verdict';
  CLf = #10;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function ReadUtf8Text(const APath: String): UTF8String;
var
  LStream: TFileStream;
  LRoundTrip: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Require(LStream.Size <= High(Integer), 'Input file is too large: ' + APath);
    SetLength(Result, Integer(LStream.Size));
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
  Require((Copy(Result, 1, 3) <> #$EF#$BB#$BF) and (Pos(#0, Result) = 0),
    'Unexpected BOM or NUL byte: ' + APath);
  LRoundTrip := UTF8Encode(UTF8Decode(Result));
  Require(LRoundTrip = Result, 'Invalid UTF-8 encoding: ' + APath);
end;

procedure LoadLines(ALines: TStrings; const AText, ALabel: String);
var
  LNormalized: String;
begin
  Require(Pos(#13, AText) = 0, ALabel + ' must use LF line endings.');
  Require((AText <> '') and (AText[Length(AText)] = CLf),
    ALabel + ' must end with a newline.');
  LNormalized := Copy(AText, 1, Length(AText) - 1);
  ALines.Clear;
  ALines.LineBreak := CLf;
  ALines.Text := LNormalized;
end;

function Sha256Hex(const AText: UTF8String): String;
begin
  Result := ComputeSha256Hex(RawByteString(AText));
end;

function IsDigitRange(const AText: String; AStart, ALen: Integer): Boolean;
var
  I: Integer;
begin
  if AStart + ALen - 1 > Length(AText) then
  begin
    Exit(False);
  end;
  for I := AStart to AStart + ALen - 1 do
  begin
    if not (AText[I] in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

function ValidIsoUtcDate(const AValue: String): Boolean;
begin
  if Length(AValue) = 10 then
  begin
    Exit(IsDigitRange(AValue, 1, 4) and (AValue[5] = '-') and
      IsDigitRange(AValue, 6, 2) and (AValue[8] = '-') and
      IsDigitRange(AValue, 9, 2));
  end;
  if Length(AValue) = 20 then
  begin
    Exit(IsDigitRange(AValue, 1, 4) and (AValue[5] = '-') and
      IsDigitRange(AValue, 6, 2) and (AValue[8] = '-') and
      IsDigitRange(AValue, 9, 2) and (AValue[11] = 'T') and
      IsDigitRange(AValue, 12, 2) and (AValue[14] = ':') and
      IsDigitRange(AValue, 15, 2) and (AValue[17] = ':') and
      IsDigitRange(AValue, 18, 2) and (AValue[20] = 'Z'));
  end;
  Result := False;
end;

function ParseYesNo(const AValue, AFieldName, AClaimId: String): Boolean;
begin
  if AValue = 'yes' then
  begin
    Exit(True);
  end;
  if AValue = 'no' then
  begin
    Exit(False);
  end;
  raise EConvertError.Create('Invalid ' + AFieldName + ' value for claim ' + AClaimId +
    ': expected yes or no.');
end;

function ParseResearchStatusRow(const ALine: String; ALineNumber: Integer): TResearchStatusRow;
var
  LFields: TFields;
begin
  LFields := SplitFields(ALine, #9);
  Require(Length(LFields) = 8, 'Malformed research-status.tsv row ' + IntToStr(ALineNumber) +
    ': expected 8 tab-separated columns.');
  Result.Id := LFields[0];
  Require((Length(Result.Id) = 4) and IsDigitRange(Result.Id, 1, 4),
    'Invalid claim ID on research-status.tsv row ' + IntToStr(ALineNumber));
  Result.Status := LFields[1];
  Require(MatchStr(Result.Status, ['researched', 'partial', 'unreviewed']),
    'Invalid research_status on row ' + IntToStr(ALineNumber) + ': ' + Result.Status);
  Result.LabClinicalChecked := ParseYesNo(LFields[2], 'lab_clinical_checked', Result.Id);
  Result.CulturalChecked := ParseYesNo(LFields[3], 'cultural_checked', Result.Id);
  Result.ScorecardChecked := ParseYesNo(LFields[4], 'scorecard_checked', Result.Id);
  Result.LastCheckedUtc := LFields[5];
  Result.SearchBasis := LFields[6];
  Result.OpenGaps := LFields[7];
  if Result.Status = 'researched' then
  begin
    Require(Result.LabClinicalChecked and Result.CulturalChecked and Result.ScorecardChecked,
      'Claim ' + Result.Id + ' marked researched must have lab_clinical_checked=yes, ' +
      'cultural_checked=yes and scorecard_checked=yes.');
    Require(ValidIsoUtcDate(Result.LastCheckedUtc),
      'Claim ' + Result.Id + ' marked researched requires valid ISO UTC date.');
    Require(Trim(Result.SearchBasis) <> '',
      'Claim ' + Result.Id + ' marked researched requires non-empty search_basis.');
  end
  else if Result.LastCheckedUtc <> '' then
  begin
    Require(ValidIsoUtcDate(Result.LastCheckedUtc),
      'Invalid last_checked_utc on claim ' + Result.Id);
  end;
end;

function DisplayVerdictLabel(const AVerdict, AResearchStatus: String): String;
begin
  if (AVerdict = 'Unknown') and (AResearchStatus = 'researched') then
  begin
    Exit('Unknown (Researched)');
  end;
  Result := AVerdict;
end;

function EffectiveResearchStatus(const ADeclaredStatus, AScorecardStatus, AVerdict: String;
  ALabChecked, ACulturalChecked, AScorecardChecked: Boolean): String;
begin
  if (ADeclaredStatus = 'researched') and ALabChecked and ACulturalChecked and
    AScorecardChecked and (AScorecardStatus = 'recorded') then
  begin
    Exit('researched');
  end;
  if (AVerdict = 'Unreviewed') or (AVerdict = '') then
  begin
    Exit('unreviewed');
  end;
  Result := 'partial';
end;

function IsDirectionalVerdict(const AVerdict: String): Boolean;
begin
  Result := MatchStr(AVerdict, ['True', 'False', 'Maybe True', 'Maybe False']);
end;

function VerifyExperimentResearchStatus(const AExperimentDir: String;
  ARequireFullCoverage: Boolean): TResearchStatusSummary;
var
  LExpDir: String;
  LFreezeText: UTF8String;
  LFreezeHash: String;
  LVerdictText: UTF8String;
  LScorecardsText: String;
  LSourcesText: String;
  LStatusPath: String;
  LStatusText: UTF8String;
  LLines: TStringList;
  LFields: TFields;
  LFrozenDir: TDictionary<String, String>;
  LVerdicts: TDictionary<String, String>;
  LConfidences: TDictionary<String, Currency>;
  LSeen: TDictionary<String, Boolean>;
  LRow: TResearchStatusRow;
  LIndex: Integer;
  LPrevId: String;
  LClaimId: String;
  LVerdict: String;
  LDirection: String;
  LConf: Currency;
  LCheck: TJSONObject;
  LScorecardIndex: TScorecardIndex;
  LReviewStatus: String;
  LEffective: String;
begin
  Result := Default(TResearchStatusSummary);
  LExpDir := ExcludeTrailingPathDelimiter(ExpandFileName(AExperimentDir));
  Require(DirectoryExists(LExpDir), 'Experiment directory does not exist: ' + LExpDir);

  LFreezeText := ReadUtf8Text(LExpDir + PathDelim + 'freeze.tsv');
  LFreezeHash := Trim(String(ReadUtf8Text(LExpDir + PathDelim + 'freeze.sha256')));
  Require(Sha256Hex(LFreezeText) = LFreezeHash, 'Frozen claim SHA-256 digest mismatch.');

  LStatusPath := LExpDir + PathDelim + 'followup' + PathDelim + 'research-status.tsv';
  Require(FileExists(LStatusPath), 'Missing research-status ledger: ' + LStatusPath);

  LScorecardsText := '';
  if FileExists(LExpDir + PathDelim + 'followup' + PathDelim + 'scorecards.tsv') then
  begin
    LScorecardsText := String(ReadUtf8Text(LExpDir + PathDelim + 'followup' + PathDelim + 'scorecards.tsv'));
  end;
  LSourcesText := '';
  if FileExists(LExpDir + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv') then
  begin
    LSourcesText := String(ReadUtf8Text(LExpDir + PathDelim + 'followup' + PathDelim + 'scorecard-sources.tsv'));
  end;

  LFrozenDir := TDictionary<String, String>.Create;
  LVerdicts := TDictionary<String, String>.Create;
  LConfidences := TDictionary<String, Currency>.Create;
  LSeen := TDictionary<String, Boolean>.Create;
  LLines := TStringList.Create;
  LScorecardIndex := nil;
  try
    if (LScorecardsText <> '') or (LSourcesText <> '') then
    begin
      LScorecardIndex := TScorecardIndex.Create(LScorecardsText, LSourcesText);
    end;
    LoadLines(LLines, String(LFreezeText), 'freeze.tsv');
    Require((LLines.Count > 1) and (LLines[0] = CFreezeHeader), 'Invalid freeze.tsv header.');
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LFields := SplitFields(LLines[LIndex], #9);
      Require(Length(LFields) = 7, 'Malformed freeze.tsv row ' + IntToStr(LIndex + 1));
      LFrozenDir.Add(LFields[0], LFields[5]);
    end;
    Result.TotalFrozen := LFrozenDir.Count;

    if FileExists(LExpDir + PathDelim + 'verdicts.tsv') then
    begin
      LVerdictText := ReadUtf8Text(LExpDir + PathDelim + 'verdicts.tsv');
      LoadLines(LLines, String(LVerdictText), 'verdicts.tsv');
      Require((LLines.Count > 1) and (LLines[0] = CVerdictHeader), 'Invalid verdicts.tsv header.');
      for LIndex := 1 to LLines.Count - 1 do
      begin
        LFields := SplitFields(LLines[LIndex], #9);
        Require(Length(LFields) = 7, 'Malformed verdicts.tsv row ' + IntToStr(LIndex + 1));
        LVerdicts.Add(LFields[0], LFields[1]);
        LConfidences.Add(LFields[0], ReadReviewConfidence(LFields[2], LFields[1], LFields[0]));
      end;
    end;

    LStatusText := ReadUtf8Text(LStatusPath);
    LoadLines(LLines, String(LStatusText), 'research-status.tsv');
    Require((LLines.Count >= 1) and (LLines[0] = CResearchStatusHeader),
      'Invalid research-status.tsv header.');

    LPrevId := '';
    for LIndex := 1 to LLines.Count - 1 do
    begin
      LRow := ParseResearchStatusRow(LLines[LIndex], LIndex + 1);
      Require(LFrozenDir.TryGetValue(LRow.Id, LDirection),
        'research-status.tsv references unknown claim ID: ' + LRow.Id);
      Require(not LSeen.ContainsKey(LRow.Id),
        'Duplicate claim ID in research-status.tsv: ' + LRow.Id);
      Require((LPrevId = '') or (CompareStr(LPrevId, LRow.Id) < 0),
        'research-status.tsv must be sorted ascending by claim ID at ' + LRow.Id);
      LPrevId := LRow.Id;
      LSeen.Add(LRow.Id, True);
      Inc(Result.RowsPresent);

      if not LVerdicts.TryGetValue(LRow.Id, LVerdict) then
      begin
        LVerdict := 'Unreviewed';
        LConf := -1;
      end
      else
      begin
        LConf := LConfidences[LRow.Id];
      end;

      LReviewStatus := 'no_scorecard';
      if (LScorecardIndex <> nil) and (LVerdict <> 'Unreviewed') then
      begin
        LCheck := TJSONObject.Create;
        try
          LScorecardIndex.AddEvidenceScorecardFor(LCheck, LRow.Id,
            LDirection, LVerdict, LConf);
          LReviewStatus := LCheck.Get('review_status', 'no_scorecard');
        finally
          LCheck.Free;
        end;
      end;

      if LRow.ScorecardChecked then
      begin
        Require(LReviewStatus = 'recorded',
          'Claim ' + LRow.Id + ' sets scorecard_checked=yes but scorecard status is ' +
          LReviewStatus + '.');
      end;
      if LRow.Status = 'researched' then
      begin
        Require(LReviewStatus = 'recorded',
          'Claim ' + LRow.Id + ' marked researched requires a recorded v1 scorecard.');
      end;

      LEffective := EffectiveResearchStatus(LRow.Status, LReviewStatus, LVerdict,
        LRow.LabClinicalChecked, LRow.CulturalChecked, LRow.ScorecardChecked);
      if LEffective = 'researched' then
      begin
        Inc(Result.Researched);
        if IsDirectionalVerdict(LVerdict) then
          Inc(Result.DirectionalResearched)
        else if LVerdict = 'Unknown' then
          Inc(Result.UnknownResearched);
      end
      else if LEffective = 'partial' then
      begin
        Inc(Result.Partial);
        if IsDirectionalVerdict(LVerdict) then
          Inc(Result.DirectionalUnresearched)
        else if LVerdict = 'Unknown' then
          Inc(Result.UnknownUnresearched);
      end
      else
      begin
        Inc(Result.Unreviewed);
      end;
    end;

    for LClaimId in LFrozenDir.Keys do
    begin
      if LSeen.ContainsKey(LClaimId) then
      begin
        Continue;
      end;
      Require(not ARequireFullCoverage,
        'Missing research-status.tsv row for frozen claim ' + LClaimId);
      if not LVerdicts.TryGetValue(LClaimId, LVerdict) then
      begin
        Inc(Result.Unreviewed);
      end
      else
      begin
        Inc(Result.Partial);
        if IsDirectionalVerdict(LVerdict) then
          Inc(Result.DirectionalUnresearched)
        else if LVerdict = 'Unknown' then
          Inc(Result.UnknownUnresearched);
      end;
    end;
    if ARequireFullCoverage then
    begin
      Require(Result.Researched = Result.TotalFrozen,
        'Full round coverage requested, but only ' + IntToStr(Result.Researched) +
        ' of ' + IntToStr(Result.TotalFrozen) + ' claims are researched.');
    end;
  finally
    LScorecardIndex.Free;
    LLines.Free;
    LSeen.Free;
    LConfidences.Free;
    LVerdicts.Free;
    LFrozenDir.Free;
  end;
end;

end.
