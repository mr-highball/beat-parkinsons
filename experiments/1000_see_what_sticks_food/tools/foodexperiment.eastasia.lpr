{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentEastAsia;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, bufstream, csvreadwrite, RegExpr, DOM, XMLRead,
  foodexperiment.externaldata, foodexperiment.matching, foodexperiment.https;

const
  ExposureTerms = 'diet|dietary|food|nutrition|nutritional|meal|drink|feeding|herb|herbal|' +
    'botanical|spice|oil|ketogenic|prebiotic|probiotic|supplement|supplementation|fiber|' +
    'fibre|mucuna|ashwagandha|capsaicin|mediterranean|polyphenol|omega 3|fatty acid|' +
    'vitamin|caffeine|kampo|aromatherapy|butyrate|medium chain triglyceride|hop bitter acids|' +
    'kestose|inulin|natto|psyllium|majainhwan|mashiningan|yokukansan|yokukansankachimpihange';
  AsianExposureTerms = '栄養|食事|食品|食餌|サプリ|漢方|乳酸菌|プロバイオ|プレバイオ|' +
    '食物繊維|コーヒー|カフェイン|緑茶|抹茶|レモングラス|精油|ハーブ|生姜|ウコン|' +
    'ソラマメ|そら豆|大豆|ゴマ|胡麻|オリーブ|食用油|ココナッツ|山椒|唐辛子|カプサイシン|' +
    '大建中湯|抑肝散|六君子湯|麻子仁丸|人参|ハッショウマメ|ムクナ|水素水|ビタミン|' +
    'ケトン|ケトジェニック|黒豆|酪酸|香気|香り|醗酵|発酵|カレー|シナモン|栄養補助|' +
    'ホップ|納豆|サイリウム|ケストース|イヌリン|ビフィズス|抑肝散加陳皮半夏|' +
    '식이|식품|식사|영양|한약|한방|생약|유산균|프로바이오|프리바이오|카페인|커피|' +
    '녹차|생강|홍삼|인삼|계피|강황|캡사이신|올리브|허브|레몬그라스|아로마|케톤|' +
    '비타민|식이섬유|발효|건강기능식품|억간산|마자인환';
  Tab = #9;
  JrctHost = 'jrct.mhlw.go.jp';
  CrisHost = 'cris.nih.go.kr';

type
  TRegistryQuery = record
    Name: UTF8String;
    Prefix: UTF8String;
    Text: UTF8String;
  end;

const
  JrctQueries: array[0..6] of TRegistryQuery = (
    (Name: 'ja-keyword'; Prefix: 'free'; Text: 'パーキンソン'),
    (Name: 'en-keyword'; Prefix: 'free'; Text: 'Parkinson'),
    (Name: 'ja-condition'; Prefix: 'dis'; Text: 'パーキンソン'),
    (Name: 'en-condition'; Prefix: 'dis'; Text: 'Parkinson'),
    (Name: 'ja-historical'; Prefix: 'free'; Text: '振戦麻痺'),
    (Name: 'en-historical-1'; Prefix: 'free'; Text: 'paralysis agitans'),
    (Name: 'en-historical-2'; Prefix: 'free'; Text: 'shaking palsy'));
  CrisQueries: array[0..4] of TRegistryQuery = (
    (Name: 'ko-keyword'; Prefix: ''; Text: '파킨슨'),
    (Name: 'en-keyword'; Prefix: ''; Text: 'Parkinson'),
    (Name: 'ko-historical'; Prefix: ''; Text: '진전마비'),
    (Name: 'en-historical-1'; Prefix: ''; Text: 'paralysis agitans'),
    (Name: 'en-historical-2'; Prefix: ''; Text: 'shaking palsy'));

type
  TExposureMatcher = class
  private
    FTerms: TStringList;
    FAsian: TFields;
    FMatcher: TMatcher;
    FMatches: TMatchFlags;
  public
    constructor Create(const ARoot: String);
    destructor Destroy; override;
    function Find(const AValue: UTF8String): UTF8String;
  end;

function AsUtf8(const AValue: RawByteString): UTF8String;
var
  LValue: RawByteString;
begin
  LValue := AValue;
  SetCodePage(LValue, CP_UTF8, False);
  Result := LValue;
end;

function HasParkinson(const AValue: UTF8String): Boolean;
var
  LText: UTF8String;
begin
  LText := LowerCase(AValue);
  Result := (Pos('parkinson', LText) > 0) or (Pos('paralysis agitans', LText) > 0) or
    (Pos('shaking palsy', LText) > 0) or (Pos('paralysie agitante', LText) > 0) or
    (Pos('パーキンソン', AValue) > 0) or (Pos('パ−キンソン', AValue) > 0) or
    (Pos('ﾊﾟｰｷﾝｿﾝ', AValue) > 0) or (Pos('振戦麻痺', AValue) > 0) or
    (Pos('파킨슨', AValue) > 0) or (Pos('진전마비', AValue) > 0);
end;

function ParkinsonField(const ATitle, ACondition, AContext, AExclusion: UTF8String): UTF8String;
begin
  if HasParkinson(ATitle + ' ' + ACondition) or (UpperCase(Trim(ACondition)) = 'G20') then
  begin
    Exit('title-or-condition');
  end;
  if HasParkinson(AContext) then
  begin
    Exit('other-study-fields');
  end;
  if HasParkinson(AExclusion) then
  begin
    Exit('exclusion-only');
  end;
  Result := '';
end;

constructor TExposureMatcher.Create(const ARoot: String);
var
  LRows: TStringList;
  LFields: TFields;
  LTerm: UTF8String;
  LIndex: Integer;
  I: Integer;
begin
  inherited Create;
  FTerms := TStringList.Create;
  FMatcher := TMatcher.Create;
  FAsian := SplitFields(AsianExposureTerms, '|');
  LRows := TStringList.Create;
  try
    for LTerm in SplitFields(ExposureTerms, '|') do
    begin
      FMatcher.Add(LTerm, FTerms.Add(LTerm));
    end;
    LRows.Text := ReadBytes(ARoot + 'ingredients.tsv');
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], Tab);
      if Length(LFields) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [I + 1]);
      end;
      LIndex := FTerms.Add(LFields[1]);
      for LTerm in SplitFields(LFields[1] + '|' + LFields[3], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
    LRows.Text := ReadBytes(ARoot + 'exposure-expansions.tsv');
    for I := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[I], Tab);
      if Length(LFields) <> 3 then
      begin
        raise EConvertError.CreateFmt('Invalid exposure expansion row %d', [I + 1]);
      end;
      LIndex := FTerms.IndexOf(LFields[0]);
      if LIndex < 0 then
      begin
        raise EConvertError.CreateFmt('Unknown ingredient at expansion row %d', [I + 1]);
      end;
      for LTerm in SplitFields(LFields[2], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
  finally
    LRows.Free;
  end;
  SetLength(FMatches, FTerms.Count);
  FMatcher.Prepare;
end;

destructor TExposureMatcher.Destroy;
begin
  FMatcher.Free;
  FTerms.Free;
  inherited Destroy;
end;

function TExposureMatcher.Find(const AValue: UTF8String): UTF8String;
var
  LTerm: UTF8String;
begin
  FillChar(FMatches[0], Length(FMatches) * SizeOf(Boolean), 0);
  FMatcher.Match(AValue, FMatches);
  Result := JoinMatches(FTerms, FMatches, 0);
  for LTerm in FAsian do
  begin
    if Pos(LTerm, AValue) > 0 then
    begin
      if Result <> '' then
      begin
        Result := Result + '|';
      end;
      Result := Result + LTerm;
    end;
  end;
end;

procedure OpenTsv(var AFile: Text; const APath: String);
begin
  Assign(AFile, APath);
  SetTextCodePage(AFile, CP_UTF8);
  Rewrite(AFile);
end;

procedure WriteRow(var AFile: Text; const AValues: array of UTF8String);
var
  I: Integer;
begin
  for I := 0 to High(AValues) do
  begin
    if I > 0 then
    begin
      Write(AFile, Tab);
    end;
    Write(AFile, CleanField(AValues[I]));
  end;
  Write(AFile, #10);
end;

function Joined(const ARow: TFields; AStart, AEnd: Integer): UTF8String;
var
  I: Integer;
begin
  Result := '';
  for I := AStart to AEnd do
  begin
    if Trim(ARow[I]) = '' then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + ' | ';
    end;
    Result := Result + ARow[I];
  end;
end;

procedure ScanUmin(const AInput, AOutput: String; AMatcher: TExposureMatcher);
var
  LFile: TBufferedFileStream;
  LParser: TCSVParser;
  LIds: TStringList;
  LRow: TFields;
  LOutput, LCounts: Text;
  LRecords, LMatches, LTitleCondition, LFlags, LDuplicates, LCurrentRow, LWidth: Integer;

  procedure InspectRow;
  var
    LTitle, LCondition, LContext, LArms, LOutcome, LField, LExposure: UTF8String;
  begin
    if LCurrentRow = 0 then
    begin
      Exit;
    end;
    if LWidth < 144 then
    begin
      raise EConvertError.CreateFmt('UMIN row %d has only %d fields', [LCurrentRow + 1, LWidth]);
    end;
    if LCurrentRow = 1 then
    begin
      if (Pos('/Unique ID issued by UMIN', LRow[1]) = 0) or
        (Pos('/Condition', LRow[11]) = 0) or (Pos('/Interventions/Control_1', LRow[42]) = 0) or
        (Pos('/Recruitment status', LRow[124]) = 0) or (LRow[137] <> UTF8String('URL(英語)')) then
      begin
        raise EConvertError.Create('Unrecognized UMIN CSV column layout');
      end;
    end;
    if LCurrentRow < 2 then
    begin
      Exit;
    end;
    Inc(LRecords);
    if (LRow[0] = '') or (LRow[1] = '') then
    begin
      raise EConvertError.CreateFmt('Missing UMIN identifiers at row %d', [LCurrentRow + 1]);
    end;
    if LIds.IndexOf(LRow[1]) >= 0 then
    begin
      Inc(LDuplicates);
    end;
    LIds.Add(LRow[1]);
    LTitle := Joined(LRow, 2, 9);
    LCondition := Joined(LRow, 11, 12);
    LContext := Joined(LRow, 16, 20);
    LOutcome := Joined(LRow, 24, 27);
    LArms := Joined(LRow, 42, 61);
    LField := ParkinsonField(LTitle, LCondition,
      LContext + ' ' + LOutcome + ' ' + LArms + ' ' + Joined(LRow, 65, 66), Joined(LRow, 67, 68));
    if LField = '' then
    begin
      Exit;
    end;
    Inc(LMatches);
    if LField = 'title-or-condition' then
    begin
      Inc(LTitleCondition);
    end;
    LExposure := AMatcher.Find(LTitle + ' ' + LContext + ' ' + LArms + ' ' + LOutcome);
    if LExposure <> '' then
    begin
      Inc(LFlags);
    end;
    WriteRow(LOutput, [LRow[1], LRow[0], LField, LExposure, LRow[134], LRow[100],
      LRow[135], LRow[124], LRow[28], LRow[29], LRow[69], LTitle, LCondition, LArms, LOutcome,
      LContext, LRow[102], LRow[103], Joined(LRow, 105, 106), LRow[107], LRow[111],
      LRow[92], LRow[95], LRow[137]]);
  end;

begin
  LFile := TBufferedFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
  LParser := TCSVParser.Create;
  LIds := TStringList.Create;
  try
    LIds.Sorted := True;
    LIds.Duplicates := dupIgnore;
    OpenTsv(LOutput, AOutput + 'umin-screen.tsv');
    try
      WriteRow(LOutput, ['id', 'receipt', 'parkinson_field', 'exposure_flags', 'registered', 'disclosed',
        'modified', 'status', 'type', 'design', 'target_n', 'title', 'condition', 'interventions',
        'outcomes', 'objectives', 'result_status', 'result_url', 'results', 'result_posted',
        'first_journal_publication', 'alternate_id_1', 'alternate_id_2', 'url']);
      LParser.DetectBOM := True;
      LParser.SetSource(LFile);
      LCurrentRow := 0;
      LWidth := 0;
      LRecords := 0;
      LMatches := 0;
      LTitleCondition := 0;
      LFlags := 0;
      LDuplicates := 0;
      SetLength(LRow, 145);
      while LParser.ParseNextCell do
      begin
        if LParser.CurrentRow <> LCurrentRow then
        begin
          InspectRow;
          LCurrentRow := LParser.CurrentRow;
          LWidth := 0;
        end;
        if LParser.CurrentCol >= Length(LRow) then
        begin
          raise EConvertError.CreateFmt('Unexpected UMIN column at row %d', [LCurrentRow + 1]);
        end;
        LRow[LParser.CurrentCol] := AsUtf8(LParser.CurrentCellText);
        Inc(LWidth);
      end;
      InspectRow;
    finally
      Close(LOutput);
    end;
    OpenTsv(LCounts, AOutput + 'umin-counts.tsv');
    try
      WriteRow(LCounts, ['input_bytes', 'data_rows', 'unique_ids', 'duplicate_rows',
        'parkinson_mentions', 'title_or_condition', 'exposure_flags']);
      WriteRow(LCounts, [IntToStr(LFile.Size), IntToStr(LRecords), IntToStr(LIds.Count),
        IntToStr(LDuplicates), IntToStr(LMatches), IntToStr(LTitleCondition), IntToStr(LFlags)]);
    finally
      Close(LCounts);
    end;
  finally
    LIds.Free;
    LParser.Free;
    LFile.Free;
  end;
end;

function Fetch(AClient: TEuropePmc; const APath: UTF8String): TSearchResponse;
var
  LAttempt: Integer;
begin
  for LAttempt := 0 to 3 do
  begin
    try
      Result := AClient.GetPath(APath);
    except
      on E: EOSError do
      begin
        if LAttempt = 3 then
        begin
          raise;
        end;
        Sleep(1000 shl LAttempt);
        Continue;
      end;
    end;
    if ((Result.Status <> 429) and ((Result.Status < 500) or (Result.Status > 504))) or
      (LAttempt = 3) then
    begin
      Exit;
    end;
    if (Result.RetryAfterSeconds > 0) and (Result.RetryAfterSeconds <= 60) then
    begin
      Sleep(Result.RetryAfterSeconds * 1000);
    end
    else
    begin
      Sleep(1000 shl LAttempt);
    end;
  end;
end;

procedure SaveBody(const APath: String; const ABody: UTF8String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmCreate);
  try
    if ABody <> '' then
    begin
      LFile.WriteBuffer(ABody[1], Length(ABody));
    end;
  finally
    LFile.Free;
  end;
end;

function FirstGroup(const APattern, AText: UTF8String): UTF8String;
var
  LPattern: TRegExpr;
begin
  Result := '';
  LPattern := TRegExpr.Create(APattern);
  try
    if LPattern.Exec(AText) then
    begin
      Result := AsUtf8(LPattern.Match[1]);
    end;
  finally
    LPattern.Free;
  end;
end;

function PlainHtml(const AText: UTF8String): UTF8String;
begin
  Result := AsUtf8(ReplaceRegExpr('<[^>]+>', AText, ' ', False));
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&#039;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&#39;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := Trim(AsUtf8(ReplaceRegExpr('\s+', Result, ' ', False)));
end;

function Cells(const AHtml, ATag: UTF8String): TFields;
var
  LPattern: TRegExpr;
begin
  Result := nil;
  LPattern := TRegExpr.Create('(?is)<' + ATag + '\b[^>]*>(.*?)</' + ATag + '>');
  try
    if not LPattern.Exec(AHtml) then
    begin
      Exit;
    end;
    repeat
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := PlainHtml(AsUtf8(LPattern.Match[1]));
    until not LPattern.ExecNext;
  finally
    LPattern.Free;
  end;
end;

function XmlText(ANode: TDOMNode; const AName: DOMString): UTF8String;
var
  LNode: TDOMNode;
begin
  LNode := ANode.FindNode(AName);
  if LNode = nil then
  begin
    Exit('');
  end;
  Result := UTF8Encode(LNode.TextContent);
end;

procedure ScanLive(const AProvider, AOutput, AReplayDir: String; AMatcher: TExposureMatcher);
var
  LClient: TEuropePmc;
  LSeen, LQuerySeen: TStringList;
  LInventory, LLog: Text;
  LIsJrct: Boolean;
  LHost, LPath, LBase, LCountText: UTF8String;
  LExpected, LPages, LPage, LRows, LTotal, LNew: Integer;
  LQuery: TRegistryQuery;
  LResponse: TSearchResponse;

  procedure AddRecord(const AId: UTF8String; const AFields: array of UTF8String);
  var
    LRecord: TFields;
    I: Integer;
  begin
    if AId = '' then
    begin
      raise EConvertError.Create('Missing public registry identifier');
    end;
    LQuerySeen.Add(AId);
    Inc(LRows);
    if LSeen.IndexOf(AId) >= 0 then
    begin
      Exit;
    end;
    LSeen.Add(AId);
    Inc(LNew);
    SetLength(LRecord, Length(AFields) + 1);
    LRecord[0] := AId;
    for I := 0 to High(AFields) do
    begin
      LRecord[I + 1] := AFields[I];
    end;
    WriteRow(LInventory, LRecord);
  end;

  procedure ReadJrct(const ABody: UTF8String);
  var
    LTable: UTF8String;
    LPattern: TRegExpr;
    LCells: TFields;
  begin
    LCountText := FirstGroup('>([0-9]+)件検索完了', ABody);
    if LCountText = '' then
    begin
      raise EConvertError.Create('Missing jRCT reported result count');
    end;
    LExpected := StrToInt(LCountText);
    LPages := (LExpected + 49) div 50;
    LTable := FirstGroup('(?is)<table class="table table-sm table-search">.*?<tbody>(.*?)</tbody>', ABody);
    LPattern := TRegExpr.Create('(?is)<tr\b[^>]*>(.*?)</tr>');
    try
      if not LPattern.Exec(LTable) then
      begin
        Exit;
      end;
      repeat
        LCells := Cells(AsUtf8(LPattern.Match[1]), 'td');
        if Length(LCells) <> 6 then
        begin
          raise EConvertError.Create('Unexpected jRCT result row');
        end;
        AddRecord(LCells[0], [LQuery.Name, IntToStr(LPage), LCells[1], LCells[2],
          LCells[3], LCells[4], ParkinsonField(LCells[1], LCells[2], '', ''),
          AMatcher.Find(LCells[1] + ' ' + LCells[2]), 'https://' + LHost + '/latest-detail/' + LCells[0]]);
      until not LPattern.ExecNext;
    finally
      LPattern.Free;
    end;
  end;

  procedure ReadCris(const ABody: UTF8String);
  var
    LStream: TStringStream;
    LDocument: TXMLDocument;
    LNode: TDOMNode;
    LTitle, LCondition, LInclusion, LExclusion, LArms, LOutcomes: UTF8String;
  begin
    if ABody = '' then
    begin
      { The public CRIS search UI displays an empty result for an empty body. }
      LExpected := 0;
      LPages := 0;
      Exit;
    end;
    LStream := TStringStream.Create(ABody);
    LDocument := nil;
    try
      ReadXMLFile(LDocument, LStream);
      if LDocument.DocumentElement.NodeName <> 'items' then
      begin
        raise EConvertError.Create('Unexpected CRIS result document');
      end;
      LExpected := StrToInt(XmlText(LDocument.DocumentElement, 'totalDataCnt'));
      LCountText := XmlText(LDocument.DocumentElement, 'totalCnt');
      LPages := StrToInt(StringReplace(LCountText, '.0', '', []));
      LNode := LDocument.DocumentElement.FirstChild;
      while Assigned(LNode) do
      begin
        if LNode.NodeName = 'item' then
        begin
          LTitle := XmlText(LNode, 'research_title_kr') + ' | ' + XmlText(LNode, 'research_title_en');
          LCondition := XmlText(LNode, 'cp_contents');
          LInclusion := XmlText(LNode, 'target_in_kr') + ' | ' + XmlText(LNode, 'target_in_en');
          LExclusion := XmlText(LNode, 'target_out_kr') + ' | ' + XmlText(LNode, 'target_out_en');
          LArms := XmlText(LNode, 'arm_desc_kr') + ' | ' + XmlText(LNode, 'arm_desc_en');
          LOutcomes := XmlText(LNode, 'outcome') + ' | ' + XmlText(LNode, 'outcome_en');
          AddRecord(XmlText(LNode, 'system_number'), [LQuery.Name, IntToStr(LPage),
            XmlText(LNode, 'ins_date'), XmlText(LNode, 'research_kind'), XmlText(LNode, 'research_step'),
            LTitle, LCondition, LArms, LOutcomes, XmlText(LNode, 'final_result_yn'),
            ParkinsonField(LTitle, LCondition, LArms + ' ' + LOutcomes + ' ' + LInclusion, LExclusion),
            AMatcher.Find(LTitle + ' ' + LArms + ' ' + LOutcomes),
            'https://' + LHost + '/cris/search/detailSearch.do/' + XmlText(LNode, 'seq')]);
        end;
        LNode := LNode.NextSibling;
      end;
    finally
      LDocument.Free;
      LStream.Free;
    end;
  end;

  procedure Query(const AQuery: TRegistryQuery);
  var
    LReported, LReportedPages: Integer;
    LRawName, LSource: String;
  begin
    LQuery := AQuery;
    LPage := 1;
    LTotal := 0;
    LNew := 0;
    LQuerySeen.Clear;
    LReported := -1;
    LReportedPages := -1;
    if LIsJrct then
    begin
      if LQuery.Prefix = 'free' then
      begin
        LBase := '/search?searched=1&dis_op=0&free_op=1&sort=record_cert_date&free=';
      end
      else
      begin
        LBase := '/search?searched=1&dis_op=0&dis=';
      end;
      LBase := LBase + UrlEncode(LQuery.Text);
    end
    else
    begin
      LBase := '/cris/search/selectBasic.do?searchWord=' + UrlEncode(LQuery.Text) +
        '&search_list=' + UrlEncode(LQuery.Text);
    end;
    repeat
      LPath := LBase + '&page=' + IntToStr(LPage);
      LRawName := AProvider + '-' + LQuery.Name + '-' + IntToStr(LPage) + '.raw';
      if AReplayDir = '' then
      begin
        LResponse := Fetch(LClient, LPath);
        SaveBody(AOutput + LRawName, LResponse.Body);
        LSource := 'live';
      end
      else
      begin
        if not FileExists(AReplayDir + LRawName) and (LPage = 1) then
        begin
          Exit;
        end;
        LResponse.Status := 0;
        LResponse.Body := AsUtf8(ReadBytes(AReplayDir + LRawName));
        LSource := 'saved-body';
      end;
      LRows := 0;
      if (AReplayDir = '') and (LResponse.Status <> 200) then
      begin
        WriteRow(LLog, [LQuery.Name, LQuery.Text, IntToStr(LPage), IntToStr(LResponse.Status), '', '', '', '',
          'https://' + LHost + LPath, UtcTimestamp, LSource]);
        raise EInOutError.CreateFmt('%s returned HTTP %d', [LPath, LResponse.Status]);
      end;
      if LIsJrct then
      begin
        ReadJrct(LResponse.Body);
      end
      else
      begin
        ReadCris(LResponse.Body);
      end;
      if LPage = 1 then
      begin
        LReported := LExpected;
        LReportedPages := LPages;
      end;
      Inc(LTotal, LRows);
      WriteRow(LLog, [LQuery.Name, LQuery.Text, IntToStr(LPage), IntToStr(LResponse.Status),
        IntToStr(LExpected), IntToStr(LPages), IntToStr(LRows), IntToStr(LNew),
        'https://' + LHost + LPath, UtcTimestamp, LSource]);
      Flush(LLog);
      Flush(LInventory);
      if (LExpected <> LReported) or (LPages <> LReportedPages) then
      begin
        raise EConvertError.CreateFmt('Reported total changed during %s pagination', [LQuery.Name]);
      end;
      Inc(LPage);
    until LPage > LReportedPages;
    if LTotal <> LReported then
    begin
      raise EConvertError.CreateFmt('%s returned %d of %d records', [LQuery.Name, LTotal, LReported]);
    end;
  end;

var
  LDefinition: TRegistryQuery;
begin
  LIsJrct := AProvider = 'jrct';
  if LIsJrct then
  begin
    LHost := JrctHost;
  end
  else
  begin
    LHost := CrisHost;
  end;
  LClient := nil;
  if AReplayDir = '' then
  begin
    LClient := TEuropePmc.Create(UTF8Decode(LHost));
  end;
  LSeen := TStringList.Create;
  LQuerySeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LQuerySeen.Sorted := True;
    LQuerySeen.Duplicates := dupError;
    OpenTsv(LInventory, AOutput + AProvider + '-screen.tsv');
    try
      OpenTsv(LLog, AOutput + AProvider + '-pages.tsv');
      try
        WriteRow(LLog, ['query', 'terms', 'page', 'status', 'reported_rows', 'reported_pages',
          'page_rows', 'new_ids_in_query_so_far', 'url', 'processed_utc', 'source']);
        if LIsJrct then
        begin
          WriteRow(LInventory, ['id', 'first_query', 'first_page', 'title', 'condition', 'status',
            'display_date', 'parkinson_field', 'exposure_flags', 'url']);
          for LDefinition in JrctQueries do
          begin
            Query(LDefinition);
          end;
        end
        else
        begin
          WriteRow(LInventory, ['id', 'first_query', 'first_page', 'registration', 'type', 'status',
            'title', 'condition', 'interventions', 'outcomes', 'result_indicator', 'parkinson_field',
            'exposure_flags', 'url']);
          for LDefinition in CrisQueries do
          begin
            Query(LDefinition);
          end;
        end;
      finally
        Close(LLog);
      end;
    finally
      Close(LInventory);
    end;
  finally
    LQuerySeen.Free;
    LSeen.Free;
    LClient.Free;
  end;
end;

var
  LMatcher: TExposureMatcher;
  LOutput, LReplayDir: String;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  if not (((ParamCount = 4) and (ParamStr(1) = 'umin')) or
    ((ParamCount in [3, 4]) and ((ParamStr(1) = 'jrct') or (ParamStr(1) = 'cris')))) then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.eastasia umin EXPERIMENT_DIR OUTPUT_DIR UMIN_CSV');
    WriteLn(StdErr, '       foodexperiment.eastasia jrct|cris EXPERIMENT_DIR OUTPUT_DIR [SAVED_PAGE_DIR]');
    Halt(2);
  end;
  LOutput := IncludeTrailingPathDelimiter(ParamStr(3));
  LReplayDir := '';
  if (ParamCount = 4) and (ParamStr(1) <> 'umin') then
  begin
    LReplayDir := IncludeTrailingPathDelimiter(ParamStr(4));
  end;
  ForceDirectories(LOutput);
  LMatcher := TExposureMatcher.Create(IncludeTrailingPathDelimiter(ParamStr(2)));
  try
    if ParamStr(1) = 'umin' then
    begin
      ScanUmin(ParamStr(4), LOutput, LMatcher);
    end
    else
    begin
      ScanLive(ParamStr(1), LOutput, LReplayDir, LMatcher);
    end;
  finally
    LMatcher.Free;
  end;
end.
