{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentJsdr;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, StrUtils, Windows, FPSHA256, RegExpr, foodexperiment.externaldata,
  foodexperiment.matching;

const
  InventoryHeader = 'meeting'#9'year'#9'access'#9'pages'#9'bytes'#9'sha256'#9'source';
  PageHeader = 'docid'#9'meeting'#9'year'#9'pdf_page'#9'source'#9'utf8_bytes'#9'topics';
  KeyHeader = 'docid'#9'presentation_id'#9'topics';
  FreezeHeader = 'id'#9'category'#9'ingredient'#9'preparation'#9'symptom'#9'direction'#9'statement';
  PairHeader = 'docid'#9'claim_ids'#9'ingredient_labels'#9'symptom_labels';
  ClaimHeader = 'id'#9'parkinson_pages'#9'ingredient_pages'#9'symptom_pages'#9'joint_pages';
  IssueHeader = 'issue_key'#9'year'#9'volume'#9'issue'#9'expected_rows';
  IssueAuditHeader = 'issue_key'#9'source'#9'rows'#9'abstract_links'#9'bytes'#9'sha256';
  TocHeader = 'docid'#9'issue_key'#9'ordinal'#9'year'#9'printed_pages'#9'goods_id'#9 +
    'abstract_link'#9'source'#9'title'#9'authors'#9'affiliations'#9'topics';
  TocClaimHeader = 'id'#9'diagnosis_titles'#9'ingredient_titles'#9'symptom_titles'#9'joint_titles';
  IssueOrigin = 'https://mol.medicalonline.jp';
  RowMarker = '<div class="search-result-wrapper">';
  JapaneseEucCodePage = 51932;

type
  TJapaneseTerms = array of TFields;
  TClaim = record
    Id: UTF8String;
    Ingredient: Integer;
    Symptom: Integer;
    IngredientPages: Integer;
    SymptomPages: Integer;
    JointPages: Integer;
  end;
  TClaims = array of TClaim;
  TTocExpressions = record
    Title: TRegExpr;
    AuthorInfo: TRegExpr;
    Pages: TRegExpr;
    AbstractLink: TRegExpr;
    Download: TRegExpr;
  end;
  TTocCounts = record
    Rows: Integer;
    AbstractLinks: Integer;
    Flags: Integer;
    Diagnosis: Integer;
  end;

function ContainsNonAscii(const AText: UTF8String): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 1 to Length(AText) do
  begin
    if Ord(AText[LIndex]) > 127 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function CompactWhitespace(const AText: UTF8String): UTF8String;
var
  LText: UTF8String;
  LRead: Integer;
  LWrite: Integer;
begin
  LText := StringReplace(AText, #$E3#$80#$80, '', [rfReplaceAll]);
  SetLength(Result, Length(LText));
  LWrite := 0;
  for LRead := 1 to Length(LText) do
  begin
    if LText[LRead] > ' ' then
    begin
      Inc(LWrite);
      Result[LWrite] := LText[LRead];
    end;
  end;
  SetLength(Result, LWrite);
end;

procedure LoadTerms(const APath: String; AMatcher: TMatcher; ANames: TStringList;
  var AJapanese: TJapaneseTerms);
var
  LRows: TStringList;
  LFields: TFields;
  LPart: UTF8String;
  LTerm: UTF8String;
  LRow: Integer;
  LGroup: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count < 2) or (LRows[0] <> 'topic'#9'terms') then
    begin
      raise EConvertError.Create('Unexpected Japanese proceedings vocabulary header');
    end;
    SetLength(AJapanese, ANames.Count + LRows.Count - 1);
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], #9);
      if (Length(LFields) <> 2) or (Trim(LFields[0]) = '') or
        (ANames.IndexOf(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid topic row %d', [LRow + 1]);
      end;
      LGroup := ANames.Add(LFields[0]);
      for LPart in SplitFields(LFields[1], '|') do
      begin
        LTerm := Trim(LPart);
        if LTerm = '' then
        begin
          raise EConvertError.CreateFmt('Empty topic term in row %d', [LRow + 1]);
        end;
        if ContainsNonAscii(LTerm) then
        begin
          SetLength(AJapanese[LGroup], Length(AJapanese[LGroup]) + 1);
          AJapanese[LGroup][High(AJapanese[LGroup])] := CompactWhitespace(LTerm);
        end
        else
        begin
          AMatcher.Add(LTerm, LGroup);
        end;
      end;
    end;
  finally
    LRows.Free;
  end;
end;

function MatchPage(const AText: UTF8String; AMatcher: TMatcher;
  const AJapanese: TJapaneseTerms): TMatchFlags;
var
  LCompact: UTF8String;
  LGroup: Integer;
  LTerm: UTF8String;
begin
  Result := nil;
  SetLength(Result, Length(AJapanese));
  AMatcher.Match(AText, Result);
  LCompact := CompactWhitespace(AText);
  for LGroup := 0 to High(AJapanese) do
  begin
    for LTerm in AJapanese[LGroup] do
    begin
      if Pos(LTerm, LCompact) > 0 then
      begin
        Result[LGroup] := True;
        Break;
      end;
    end;
  end;
end;

procedure CheckPdf(const APath: String; const ABytes, AHash: UTF8String);
var
  LStream: TFileStream;
  LBytes: Int64;
begin
  if not TryStrToInt64(ABytes, LBytes) or (LBytes <= 0) then
  begin
    raise EConvertError.Create('Invalid PDF size for ' + APath);
  end;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size <> LBytes) or (LowerCase(TSHA256.StreamHexa(LStream)) <> AHash) then
    begin
      raise EConvertError.Create('PDF size or SHA-256 differs from the inventory: ' + APath);
    end;
  finally
    LStream.Free;
  end;
end;

procedure LoadClaims(const AExperiment: String; ANames: TStringList; out AClaims: TClaims);
var
  LDirectory: String;
  LStream: TFileStream;
  LRows: TStringList;
  LFields: TFields;
  LIndex: Integer;
begin
  LDirectory := IncludeTrailingPathDelimiter(AExperiment);
  LStream := TFileStream.Create(LDirectory + 'freeze.tsv', fmOpenRead or fmShareDenyWrite);
  try
    if not SameText(Trim(ReadBytes(LDirectory + 'freeze.sha256')), TSHA256.StreamHexa(LStream)) then
    begin
      raise EConvertError.Create('Frozen claim hash does not match');
    end;
    LRows := TStringList.Create;
    try
      LRows.Text := ReadBytes(LDirectory + 'freeze.tsv');
      if (LRows.Count <> 1001) or (LRows[0] <> FreezeHeader) then
      begin
        raise EConvertError.Create('Unexpected frozen claim inventory');
      end;
      SetLength(AClaims, LRows.Count - 1);
      for LIndex := 0 to High(AClaims) do
      begin
        LFields := SplitFields(LRows[LIndex + 1], #9);
        if (Length(LFields) <> 7) or (LFields[0] <> Format('%.4d', [LIndex + 1])) then
        begin
          raise EConvertError.CreateFmt('Invalid frozen claim row %d', [LIndex + 2]);
        end;
        AClaims[LIndex].Id := LFields[0];
        AClaims[LIndex].Ingredient := ANames.IndexOf('ingredient ' + LFields[2]);
        AClaims[LIndex].Symptom := ANames.IndexOf('symptom ' + LFields[4]);
        if (AClaims[LIndex].Ingredient < 0) or (AClaims[LIndex].Symptom < 0) then
        begin
          raise EConvertError.Create('Missing Japanese vocabulary for claim ' + LFields[0]);
        end;
      end;
    finally
      LRows.Free;
    end;
  finally
    LStream.Free;
  end;
end;

procedure ScreenClaims(const AText, AId: UTF8String; AMatcher: TMatcher; ANames: TStringList;
  const AJapanese: TJapaneseTerms; var AClaims: TClaims; var AOutput: Text);
var
  LFlags: TMatchFlags;
  LIndex: Integer;
  LJoint: UTF8String;
  LIngredients: UTF8String;
  LSymptoms: UTF8String;
begin
  LFlags := MatchPage(AText, AMatcher, AJapanese);
  LJoint := '';
  for LIndex := 0 to High(AClaims) do
  begin
    if LFlags[AClaims[LIndex].Ingredient] then
    begin
      Inc(AClaims[LIndex].IngredientPages);
    end;
    if LFlags[AClaims[LIndex].Symptom] then
    begin
      Inc(AClaims[LIndex].SymptomPages);
    end;
    if LFlags[AClaims[LIndex].Ingredient] and LFlags[AClaims[LIndex].Symptom] then
    begin
      Inc(AClaims[LIndex].JointPages);
      if LJoint <> '' then
      begin
        LJoint := LJoint + '|';
      end;
      LJoint := LJoint + AClaims[LIndex].Id;
    end;
  end;
  LIngredients := '';
  LSymptoms := '';
  for LIndex := 0 to High(LFlags) do
  begin
    if LFlags[LIndex] then
    begin
      if Copy(ANames[LIndex], 1, 11) = 'ingredient ' then
      begin
        LIngredients := LIngredients + '|' + Copy(ANames[LIndex], 12, MaxInt);
      end
      else
      begin
        LSymptoms := LSymptoms + '|' + Copy(ANames[LIndex], 9, MaxInt);
      end;
    end;
  end;
  Write(AOutput, AId, #9, LJoint, #9, Copy(LIngredients, 2, MaxInt), #9,
    Copy(LSymptoms, 2, MaxInt), #10);
end;

function HasIngredient(const ATitle: UTF8String; AMatcher: TMatcher;
  ANames: TStringList; const ATerms: TJapaneseTerms): Boolean;
var
  LFlags: TMatchFlags;
  LIndex: Integer;
begin
  LFlags := MatchPage(ATitle, AMatcher, ATerms);
  for LIndex := 0 to High(LFlags) do
  begin
    if LFlags[LIndex] and (Copy(ANames[LIndex], 1, 11) = 'ingredient ') then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure WriteVolume(const ABase, APrefix: String; const AFields: TFields; AMatcher: TMatcher;
  ANames: TStringList; const AJapanese: TJapaneseTerms; var APages, AKeys: Text;
  AClaimMatcher: TMatcher; AClaimNames: TStringList; const AClaimTerms: TJapaneseTerms;
  var AClaims: TClaims; var APairs: Text; var APageCount, AFlagCount, AParkinsonCount: Integer);
var
  LPages: TFields;
  LPageCount: Integer;
  LPage: Integer;
  LText: Text;
  LId: UTF8String;
  LTopics: UTF8String;
  LLength: Integer;
  LParkinson: Boolean;
begin
  if not TryStrToInt(AFields[3], LPageCount) or (LPageCount < 1) then
  begin
    raise EConvertError.Create('Invalid page count for meeting ' + AFields[0]);
  end;
  CheckPdf(ABase + '.pdf', AFields[4], AFields[5]);
  LPages := SplitFields(ReadBytes(ABase + '.formfeed'), #12);
  if (Length(LPages) <> LPageCount + 1) or (Trim(LPages[High(LPages)]) <> '') then
  begin
    raise EConvertError.Create('Extracted page count differs from the inventory: ' + ABase);
  end;
  AssignFile(LText, ABase + '.txt');
  Rewrite(LText);
  try
    SetTextCodePage(LText, CP_UTF8);
    for LPage := 1 to LPageCount do
    begin
      LId := APrefix + '-' + AFields[0] + '-' + IntToStr(LPage);
      LLength := Length(Trim(LPages[LPage - 1]));
      LTopics := JoinMatches(ANames, MatchPage(LPages[LPage - 1], AMatcher, AJapanese), 0);
      LParkinson := Pos('|Parkinson|', '|' + LTopics + '|') > 0;
      Write(APages, LId, #9, AFields[0], #9, AFields[1], #9, LPage, #9, AFields[6],
        '#page=', LPage, #9, LLength, #9, LTopics, #10);
      Write(LText, '=== PDF page ', LPage, ' ===', #10, LPages[LPage - 1], #10);
      if (LLength = 0) or LParkinson or
        (Pos('|potato and tubers|', '|' + LTopics + '|') > 0) then
      begin
        if LLength = 0 then
        begin
          LTopics := 'empty extraction';
        end;
        Write(AKeys, LId, #9, LId, #9, LTopics, #10);
        Inc(AFlagCount);
      end;
      if LParkinson then
      begin
        Inc(AParkinsonCount);
        ScreenClaims(LPages[LPage - 1], LId, AClaimMatcher, AClaimNames, AClaimTerms,
          AClaims, APairs);
      end;
    end;
    Inc(APageCount, LPageCount);
  finally
    CloseFile(LText);
  end;
end;

procedure Run(const AInventory, AVocabulary, ADirectory, AExperiment, AClaimVocabulary,
  APrefix: String);
var
  LRows: TStringList;
  LNames: TStringList;
  LMatcher: TMatcher;
  LClaimMatcher: TMatcher;
  LClaimNames: TStringList;
  LMeetings: TStringList;
  LClaimTerms: TJapaneseTerms;
  LClaims: TClaims;
  LJapanese: TJapaneseTerms;
  LFields: TFields;
  LPages: Text;
  LKeys: Text;
  LPairs: Text;
  LClaimOutput: Text;
  LDirectory: String;
  LPageCount: Integer;
  LFlagCount: Integer;
  LParkinsonCount: Integer;
  LRow: Integer;
  LClaim: TClaim;
begin
  if not ExecRegExpr('^[A-Z]+$', APrefix) then
  begin
    raise EArgumentException.Create('Proceedings prefix must use uppercase ASCII letters');
  end;
  LDirectory := IncludeTrailingPathDelimiter(ADirectory);
  LRows := TStringList.Create;
  LNames := TStringList.Create;
  LMatcher := TMatcher.Create;
  LClaimMatcher := TMatcher.Create;
  LClaimNames := TStringList.Create;
  LMeetings := TStringList.Create;
  LMeetings.Sorted := True;
  LMeetings.Duplicates := dupError;
  try
    LRows.Text := ReadBytes(AInventory);
    if (LRows.Count < 2) or (LRows[0] <> InventoryHeader) then
    begin
      raise EConvertError.Create('Unexpected Japanese proceedings inventory header');
    end;
    LoadTerms(AVocabulary, LMatcher, LNames, LJapanese);
    LoadTerms(AClaimVocabulary, LClaimMatcher, LClaimNames, LClaimTerms);
    LMatcher.Prepare;
    LClaimMatcher.Prepare;
    LoadClaims(AExperiment, LClaimNames, LClaims);
    AssignFile(LPages, LDirectory + 'pages.tsv');
    AssignFile(LKeys, LDirectory + 'review-keys.tsv');
    AssignFile(LPairs, LDirectory + 'claim-page-matches.tsv');
    Rewrite(LPages);
    try
      Rewrite(LKeys);
      try
        Rewrite(LPairs);
        try
          SetTextCodePage(LPages, CP_UTF8);
          SetTextCodePage(LKeys, CP_UTF8);
          SetTextCodePage(LPairs, CP_UTF8);
          Write(LPages, PageHeader, #10);
          Write(LKeys, KeyHeader, #10);
          Write(LPairs, PairHeader, #10);
          LPageCount := 0;
          LFlagCount := 0;
          LParkinsonCount := 0;
          for LRow := 1 to LRows.Count - 1 do
          begin
            LFields := SplitFields(LRows[LRow], #9);
            if (Length(LFields) <> 7) or
              not ExecRegExpr('^[0-9]+(-[0-9]+|-public-program)?$', LFields[0]) then
            begin
              raise EConvertError.CreateFmt('Invalid proceedings inventory row %d', [LRow + 1]);
            end;
            LMeetings.Add(LFields[0]);
            if LFields[3] <> '' then
            begin
              WriteVolume(LDirectory + LowerCase(APrefix) + '-' + LFields[0], APrefix,
                LFields, LMatcher, LNames, LJapanese, LPages, LKeys, LClaimMatcher,
                LClaimNames, LClaimTerms, LClaims, LPairs, LPageCount, LFlagCount, LParkinsonCount);
            end;
          end;
        finally
          CloseFile(LPairs);
        end;
      finally
        CloseFile(LKeys);
      end;
    finally
      CloseFile(LPages);
    end;
    AssignFile(LClaimOutput, LDirectory + 'claim-coverage.tsv');
    Rewrite(LClaimOutput);
    try
      Write(LClaimOutput, ClaimHeader, #10);
      for LClaim in LClaims do
      begin
        Write(LClaimOutput, LClaim.Id, #9, LParkinsonCount, #9, LClaim.IngredientPages,
          #9, LClaim.SymptomPages, #9, LClaim.JointPages, #10);
      end;
    finally
      CloseFile(LClaimOutput);
    end;
    WriteLn(LPageCount, ' verified pages, ', LFlagCount, ' pages for contextual review');
  finally
    LMeetings.Free;
    LClaimNames.Free;
    LClaimMatcher.Free;
    LMatcher.Free;
    LNames.Free;
    LRows.Free;
  end;
end;

function NewExpression(const APattern: String): TRegExpr;
begin
  Result := TRegExpr.Create;
  Result.ModifierS := True;
  Result.Expression := APattern;
end;

function ConvertINetMultiByteToUnicode(var AMode: DWORD; ACodePage: UINT;
  ASource: PAnsiChar; var ASourceLength: Integer; ADestination: PWideChar;
  var ADestinationLength: Integer): HRESULT; stdcall; external 'mlang.dll';

function DecodeIssue(const ABytes: RawByteString): UTF8String;
var
  LSourceLength: Integer;
  LDestinationLength: Integer;
  LMode: DWORD;
  LText: UnicodeString;
begin
  LSourceLength := Length(ABytes);
  LDestinationLength := LSourceLength;
  LMode := 0;
  SetLength(LText, LDestinationLength);
  if (ConvertINetMultiByteToUnicode(LMode, JapaneseEucCodePage, PAnsiChar(ABytes),
    LSourceLength, PWideChar(LText), LDestinationLength) <> 0) or
    (LSourceLength <> Length(ABytes)) or (LDestinationLength = 0) then
  begin
    raise EConvertError.Create('Windows MLang could not decode the EUC-JP issue');
  end;
  SetLength(LText, LDestinationLength);
  Result := UTF8Encode(LText);
  if Pos(#$EF#$BF#$BD, Result) > 0 then
  begin
    raise EConvertError.Create('Replacement character while decoding EUC-JP issue');
  end;
end;

function FlaggedTitle(const ATopics: UTF8String): Boolean;
var
  LTopic: UTF8String;
begin
  for LTopic in SplitFields(ATopics, '|') do
  begin
    if (LTopic = 'Parkinson') or (LTopic = 'related diagnosis') or
      (LTopic = 'potato and tubers') or (LTopic = 'chili and pepper') or
      (LTopic = 'levodopa and dietary components') or (LTopic = 'ingredient and swallowing') then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure WriteTocRow(const AHtml, ASource: UTF8String; const AIssue: TFields;
  const AExpressions: TTocExpressions; AMatcher: TMatcher; ANames: TStringList;
  const ATerms: TJapaneseTerms; AClaimMatcher: TMatcher; AClaimNames: TStringList;
  const AClaimTerms: TJapaneseTerms; var AClaims: TClaims; ASeen: TStringList;
  var ARows, AKeys, APairs: Text; var ACounts: TTocCounts);
var
  LId: UTF8String;
  LTitle: UTF8String;
  LAuthors: UTF8String;
  LAffiliations: UTF8String;
  LPages: UTF8String;
  LGoodsId: UTF8String;
  LSource: UTF8String;
  LAccess: UTF8String;
  LTopics: UTF8String;
begin
  Inc(ACounts.Rows);
  LId := 'JSDR-MOL-' + AIssue[0] + '-' + Format('%.4d', [ACounts.Rows]);
  if not AExpressions.Title.Exec(AHtml) or not AExpressions.AuthorInfo.Exec(AHtml) or
    not AExpressions.Pages.Exec(AHtml) or (AExpressions.Pages.Match[2] <> AIssue[1]) then
  begin
    raise EConvertError.Create('Incomplete or mismatched TOC row ' + LId);
  end;
  LTitle := CleanField(AExpressions.Title.Match[1]);
  if LTitle = '' then
  begin
    raise EConvertError.Create('Empty title in ' + LId);
  end;
  LAuthors := CleanField(AExpressions.AuthorInfo.Match[1]);
  LAffiliations := CleanField(AExpressions.AuthorInfo.Match[2]);
  LPages := CleanField(AExpressions.Pages.Match[1]);
  LGoodsId := '';
  LSource := ASource;
  LAccess := 'no-item-link';
  if AExpressions.AbstractLink.Exec(AHtml) then
  begin
    LGoodsId := AExpressions.AbstractLink.Match[1];
    LSource := IssueOrigin + '/journal/abstract?GoodsID=' + LGoodsId + '&name=' +
      AExpressions.AbstractLink.Match[2];
    LAccess := 'abstract-link-listed';
    Inc(ACounts.AbstractLinks);
  end
  else if AExpressions.Download.Exec(AHtml) then
  begin
    LGoodsId := AExpressions.Download.Match[1];
    LAccess := 'download-only';
  end;
  if LGoodsId <> '' then
  begin
    ASeen.Add(LGoodsId);
  end;
  LTopics := JoinMatches(ANames, MatchPage(LTitle, AMatcher, ATerms), 0);
  if (Pos('|swallowing and choking|', '|' + LTopics + '|') > 0) and
    HasIngredient(LTitle, AClaimMatcher, AClaimNames, AClaimTerms) then
  begin
    LTopics := LTopics + '|ingredient and swallowing';
  end;
  Write(ARows, LId, #9, AIssue[0], #9, ACounts.Rows, #9, AIssue[1], #9, LPages, #9,
    LGoodsId, #9, LAccess, #9, LSource, #9, LTitle, #9, LAuthors, #9, LAffiliations, #9,
    LTopics, #10);
  if FlaggedTitle(LTopics) then
  begin
    Write(AKeys, LId, #9, LId, #9, LTopics, #10);
    Inc(ACounts.Flags);
  end;
  if (Pos('|Parkinson|', '|' + LTopics + '|') > 0) or
    (Pos('|related diagnosis|', '|' + LTopics + '|') > 0) then
  begin
    Inc(ACounts.Diagnosis);
    ScreenClaims(LTitle, LId, AClaimMatcher, AClaimNames, AClaimTerms, AClaims, APairs);
  end;
end;

procedure WriteIssue(const ADirectory: String; const AIssue: TFields;
  const AExpressions: TTocExpressions; AMatcher: TMatcher; ANames: TStringList;
  const ATerms: TJapaneseTerms; AClaimMatcher: TMatcher; AClaimNames: TStringList;
  const AClaimTerms: TJapaneseTerms; var AClaims: TClaims; ASeen: TStringList;
  var ARows, AKeys, APairs, AAudit: Text; var ATotal: TTocCounts);
var
  LBytes: RawByteString;
  LHtml: UTF8String;
  LSource: UTF8String;
  LHash: String;
  LCounts: TTocCounts;
  LExpected: Integer;
  LStart: Integer;
  LEnd: Integer;
begin
  if (Length(AIssue) <> 5) or
    not ExecRegExpr('^[0-9]{4}-[0-9]+-([0-9]+|suppl)$', AIssue[0]) or
    (AIssue[0] <> AIssue[1] + '-' + IfThen(AIssue[2] = '', '0', AIssue[2]) + '-' + AIssue[3]) or
    not TryStrToInt(AIssue[4], LExpected) or (LExpected < 1) then
  begin
    raise EConvertError.Create('Invalid legacy issue row');
  end;
  LBytes := ReadBytes(ADirectory + AIssue[0] + '.html');
  TSHA256.DigestHexa(BytesOf(LBytes), LHash);
  if Pos('<meta charset="EUC-JP"', LBytes) = 0 then
  begin
    raise EConvertError.Create('Unexpected HTML encoding in ' + AIssue[0]);
  end;
  LHtml := DecodeIssue(LBytes);
  LSource := IssueOrigin + '/archive/search?issue=' + AIssue[3] + '&jo=cb5dvsph&vo=' +
    AIssue[2] + '&ye=' + AIssue[1];
  LCounts := Default(TTocCounts);
  LStart := Pos(RowMarker, LHtml);
  while (LStart > 0) and (LStart <= Length(LHtml)) do
  begin
    Inc(LStart, Length(RowMarker));
    LEnd := PosEx(RowMarker, LHtml, LStart);
    if LEnd = 0 then
    begin
      LEnd := Length(LHtml) + 1;
    end;
    WriteTocRow(Copy(LHtml, LStart, LEnd - LStart), LSource, AIssue, AExpressions,
      AMatcher, ANames, ATerms, AClaimMatcher, AClaimNames, AClaimTerms, AClaims, ASeen,
      ARows, AKeys, APairs, LCounts);
    LStart := LEnd;
  end;
  if LCounts.Rows <> LExpected then
  begin
    raise EConvertError.CreateFmt('%s has %d TOC rows, expected %d',
      [AIssue[0], LCounts.Rows, LExpected]);
  end;
  Inc(ATotal.Rows, LCounts.Rows);
  Inc(ATotal.AbstractLinks, LCounts.AbstractLinks);
  Inc(ATotal.Flags, LCounts.Flags);
  Inc(ATotal.Diagnosis, LCounts.Diagnosis);
  Write(AAudit, AIssue[0], #9, LSource, #9, LCounts.Rows, #9, LCounts.AbstractLinks, #9,
    Length(LBytes), #9, LowerCase(LHash), #10);
end;

procedure OpenOutput(var AFile: Text; const APath, AHeader: String);
begin
  AssignFile(AFile, APath);
  Rewrite(AFile);
  SetTextCodePage(AFile, CP_UTF8);
  Write(AFile, AHeader, #10);
end;

procedure RunLegacy(const AInventory, ADirectory, AExperiment, AFollowup: String);
var
  LDirectory: String;
  LFollowup: String;
  LIssues: TStringList;
  LSeen: TStringList;
  LNames: TStringList;
  LClaimNames: TStringList;
  LMatcher: TMatcher;
  LClaimMatcher: TMatcher;
  LTerms: TJapaneseTerms;
  LClaimTerms: TJapaneseTerms;
  LClaims: TClaims;
  LExpressions: TTocExpressions;
  LTotal: TTocCounts;
  LRows: Text;
  LKeys: Text;
  LPairs: Text;
  LAudit: Text;
  LCoverage: Text;
  LIndex: Integer;
  LClaim: TClaim;
begin
  LDirectory := IncludeTrailingPathDelimiter(ADirectory);
  LFollowup := IncludeTrailingPathDelimiter(AFollowup);
  LIssues := TStringList.Create;
  LSeen := TStringList.Create;
  LNames := TStringList.Create;
  LClaimNames := TStringList.Create;
  LMatcher := TMatcher.Create;
  LClaimMatcher := TMatcher.Create;
  LExpressions := Default(TTocExpressions);
  try
    LIssues.Text := ReadBytes(AInventory);
    if (LIssues.Count < 2) or (LIssues[0] <> IssueHeader) then
    begin
      raise EConvertError.Create('Unexpected legacy issue inventory header');
    end;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LExpressions.Title := NewExpression('<div class="search-result-title">(.*?)</div>');
    LExpressions.AuthorInfo := NewExpression('<div class="search-result-info">\s*(.*?)<br\s*/?>' +
      '(.*?)<br\s*/?>\s*<a href="/archive/select');
    LExpressions.Pages := NewExpression('</a>\s+([^<>\r\n]+),\s*(\d{4})\.<br\s*/>');
    LExpressions.AbstractLink := NewExpression('/journal/abstract\?GoodsID=([^"&]+)' +
      '&amp;name=([^"]+)"');
    LExpressions.Download := NewExpression('/journal/download\?GoodsID=([^"&]+)&');
    LoadTerms(LFollowup + 'jsdr-topic-vocabulary.tsv', LMatcher, LNames, LTerms);
    LoadTerms(LFollowup + 'jsdr-legacy-extra-topics.tsv', LMatcher, LNames, LTerms);
    LoadTerms(LFollowup + 'jsdr-claim-vocabulary.tsv', LClaimMatcher, LClaimNames, LClaimTerms);
    LMatcher.Prepare;
    LClaimMatcher.Prepare;
    LoadClaims(AExperiment, LClaimNames, LClaims);
    LTotal := Default(TTocCounts);
    OpenOutput(LRows, LDirectory + 'toc.tsv', TocHeader);
    try
      OpenOutput(LKeys, LDirectory + 'review-keys.tsv', KeyHeader);
      try
        OpenOutput(LPairs, LDirectory + 'claim-title-matches.tsv', PairHeader);
        try
          OpenOutput(LAudit, LDirectory + 'issue-audit.tsv', IssueAuditHeader);
          try
            for LIndex := 1 to LIssues.Count - 1 do
            begin
              WriteIssue(LDirectory, SplitFields(LIssues[LIndex], #9), LExpressions,
                LMatcher, LNames, LTerms, LClaimMatcher, LClaimNames, LClaimTerms, LClaims,
                LSeen, LRows, LKeys, LPairs, LAudit, LTotal);
            end;
          finally
            CloseFile(LAudit);
          end;
        finally
          CloseFile(LPairs);
        end;
      finally
        CloseFile(LKeys);
      end;
    finally
      CloseFile(LRows);
    end;
    OpenOutput(LCoverage, LDirectory + 'claim-coverage.tsv', TocClaimHeader);
    try
      for LClaim in LClaims do
      begin
        Write(LCoverage, LClaim.Id, #9, LTotal.Diagnosis, #9, LClaim.IngredientPages,
          #9, LClaim.SymptomPages, #9, LClaim.JointPages, #10);
      end;
    finally
      CloseFile(LCoverage);
    end;
    WriteLn(LTotal.Rows, ' reconciled TOC rows, ', LTotal.Flags, ' titles for review, ',
      LTotal.AbstractLinks, ' abstract links');
  finally
    LExpressions.Download.Free;
    LExpressions.AbstractLink.Free;
    LExpressions.Pages.Free;
    LExpressions.AuthorInfo.Free;
    LExpressions.Title.Free;
    LClaimMatcher.Free;
    LMatcher.Free;
    LClaimNames.Free;
    LNames.Free;
    LSeen.Free;
    LIssues.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount < 5) or (ParamCount > 6) or
      ((ParamStr(1) = 'legacy') and (ParamCount <> 5)) then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.jsdr INVENTORY TOPICS DIRECTORY EXPERIMENT CLAIM_VOCABULARY' +
        ' [PDF_PREFIX]' +
        LineEnding + '       foodexperiment.jsdr legacy INVENTORY DIRECTORY EXPERIMENT FOLLOWUP');
    end;
    if ParamStr(1) = 'legacy' then
    begin
      RunLegacy(ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
    end
    else
    begin
      Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5),
        IfThen(ParamCount = 6, ParamStr(6), 'JSDR'));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
