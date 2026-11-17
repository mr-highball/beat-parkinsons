{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentMds;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, RegExpr, FPSHA256, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

const
  Host = 'www.mdsabstracts.org';
  Origin = 'https://' + Host;
  ArchiveOrigin = 'https://live-mdsabstracts.pantheonsite.io';
  Journal = '/journals/mov-disord-vol-41-suppl-1/';
  Meeting = '/meetings/2026-international-congress/';
  JournalClass = 'journal-mov-disord-vol-41-suppl-1';
  MeetingClass = 'meeting-2026-international-congress';
  Tab = #9;
  LinkHeader = 'page'#9'position'#9'url'#9'title';
  PageHeader = 'page'#9'url'#9'rows'#9'bytes'#9'sha256';
  IndexHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'indexed_abstract';
  InventoryHeader = 'docid'#9'url'#9'title'#9'category'#9'assets'#9 +
    'status'#9'bytes'#9'sha256'#9'detail';
  TopicHeader = 'docid'#9'presentation_id'#9'topics';
  LexicalHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'has_abstract'#9 +
    'ingredients'#9'symptoms'#9'title_ingredients'#9'title_symptoms'#9'joint_claim_ids';
  ReviewHeader = 'docid'#9'disposition'#9'assessment';

function Capture(const APattern, AText: String): String;
var
  LExpression: TRegExpr;
begin
  LExpression := TRegExpr.Create;
  try
    LExpression.ModifierS := True;
    LExpression.Expression := APattern;
    Result := '';
    if LExpression.Exec(AText) then
    begin
      Result := LExpression.Match[1];
    end;
  finally
    LExpression.Free;
  end;
end;

function FileHash(const ABytes: RawByteString): String;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    if ABytes <> '' then
    begin
      LStream.WriteBuffer(ABytes[1], Length(ABytes));
    end;
    LStream.Position := 0;
    Result := LowerCase(TSHA256.StreamHexa(LStream));
  finally
    LStream.Free;
  end;
end;

procedure SaveNew(const APath: String; const ABytes: RawByteString);
var
  LStage: String;
  LStream: TFileStream;
begin
  LStage := APath + '.part';
  LStream := TFileStream.Create(LStage, fmCreate);
  try
    LStream.WriteBuffer(ABytes[1], Length(ABytes));
  finally
    LStream.Free;
  end;
  if FileExists(APath) or not RenameFile(LStage, APath) then
  begin
    raise EInOutError.Create('Could not publish cached response ' + APath);
  end;
end;

function Fetch(AClient: TEuropePmc; const APath: String): String;
var
  LResponse: TSearchResponse;
  LAttempt: Integer;
  LDelay: DWORD;
begin
  LDelay := 350;
  for LAttempt := 1 to 3 do
  begin
    Sleep(LDelay);
    LResponse := AClient.GetPath(APath);
    if (LResponse.Status <> 429) and
      ((LResponse.Status < 502) or (LResponse.Status > 504)) then
    begin
      Break;
    end;
    if LResponse.RetryAfterSeconds > 30 then
    begin
      Break;
    end;
    LDelay := 1000 shl LAttempt;
    if LResponse.RetryAfterSeconds * 1000 > LDelay then
    begin
      LDelay := LResponse.RetryAfterSeconds * 1000;
    end;
  end;
  if (LResponse.Status <> 200) or (LResponse.Body = '') then
  begin
    raise EInOutError.CreateFmt('%s HTTP %d, Retry-After %d seconds',
      [APath, LResponse.Status, LResponse.RetryAfterSeconds]);
  end;
  Result := LResponse.Body;
end;

function ArchivePath(APage: Integer; AByTitle: Boolean): String;
begin
  Result := Journal;
  if AByTitle then
  begin
    Result := Meeting;
  end;
  if APage > 1 then
  begin
    Result := Result + 'page/' + IntToStr(APage) + '/';
  end;
  if AByTitle then
  begin
    Result := Result + '?viewby=title';
  end;
end;

function DecodePath(const AValue: String): String;
var
  LPosition: Integer;
  LLength: Integer;
  LByte: Integer;
begin
  SetLength(Result, Length(AValue));
  LPosition := 1;
  LLength := 0;
  while LPosition <= Length(AValue) do
  begin
    Inc(LLength);
    if (AValue[LPosition] = '%') and (LPosition + 2 <= Length(AValue)) and
      TryStrToInt('$' + Copy(AValue, LPosition + 1, 2), LByte) and
      (LByte >= 0) and (LByte <= 255) then
    begin
      Result[LLength] := Char(LByte);
      Inc(LPosition, 3);
    end
    else
    begin
      Result[LLength] := AValue[LPosition];
      Inc(LPosition);
    end;
  end;
  SetLength(Result, LLength);
end;

function ReadArchivePage(const AHtml: String; APage: Integer; AByTitle: Boolean;
  ALinks, ASeen: TStrings): Boolean;
var
  LExpression: TRegExpr;
  LScope: String;
  LPath: String;
  LTitle: String;
  LMarker: String;
  LNext: String;
  LActive: String;
  LPosition: Integer;
begin
  LMarker := 'simple-search-list';
  if AByTitle then
  begin
    LMarker := 'abstract-list sorted-title';
  end;
  LScope := Capture('<ul class="' + LMarker + '">(.*?)</ul>', AHtml);
  LPosition := 0;
  LExpression := TRegExpr.Create;
  try
    LExpression.ModifierS := True;
    LExpression.Expression := '<h5(?: class="title")?><a href="' + Origin +
      '(/abstract/[^"]+/)">(.+?)</a></h5>';
    if LExpression.Exec(LScope) then
    begin
      repeat
        LPath := LExpression.Match[1];
        LTitle := CleanField(LExpression.Match[2]);
        if (LTitle = '') or (ASeen.IndexOf(LPath) >= 0) then
        begin
          raise EConvertError.CreateFmt('Empty title or duplicate link on page %d: %s',
            [APage, LPath]);
        end;
        ASeen.Add(LPath);
        Inc(LPosition);
        ALinks.Add(IntToStr(APage) + Tab + IntToStr(LPosition) + Tab +
          Origin + LPath + Tab + LTitle);
      until not LExpression.ExecNext;
    end;
  finally
    LExpression.Free;
  end;
  if LPosition = 0 then
  begin
    raise EConvertError.CreateFmt('No abstract links on archive page %d', [APage]);
  end;
  LNext := Capture('class="pagination-next"><a href="([^"]+)"', AHtml);
  Result := LNext <> '';
  LActive := Capture('aria-label="Current page">([0-9]+)</a>', AHtml);
  if (LActive <> IntToStr(APage)) or (Result and (LPosition <> 10)) or
    (LPosition > 10) then
  begin
    raise EConvertError.CreateFmt('Pagination or row count mismatch for page %d', [APage]);
  end;
  if Result and (LNext <> Origin + ArchivePath(APage + 1, AByTitle)) then
  begin
    raise EConvertError.Create('Unexpected next archive URL: ' + LNext);
  end;
end;

procedure Discover(AClient: TEuropePmc; const ADirectory: String; AByTitle: Boolean);
var
  LLinks: TStringList;
  LSeen: TStringList;
  LPages: TStringList;
  LPage: Integer;
  LBefore: Integer;
  LFile: String;
  LPath: String;
  LHtml: String;
  LHasNext: Boolean;
  LIsCached: Boolean;
begin
  LLinks := TStringList.Create;
  LSeen := TStringList.Create;
  LPages := TStringList.Create;
  try
    LLinks.Add(LinkHeader);
    LPages.Add(PageHeader);
    LSeen.Sorted := True;
    LPage := 0;
    repeat
      Inc(LPage);
      LFile := ADirectory + Format('listing-%.4d.html', [LPage]);
      LPath := ArchivePath(LPage, AByTitle);
      LIsCached := FileExists(LFile);
      if LIsCached then
      begin
        LHtml := ReadBytes(LFile);
      end
      else
      begin
        LHtml := Fetch(AClient, LPath);
      end;
      LBefore := LLinks.Count;
      LHasNext := ReadArchivePage(LHtml, LPage, AByTitle, LLinks, LSeen);
      if not LIsCached then
      begin
        SaveNew(LFile, LHtml);
      end;
      LPages.Add(IntToStr(LPage) + Tab + Origin + LPath + Tab +
        IntToStr(LLinks.Count - LBefore) + Tab + IntToStr(Length(LHtml)) + Tab +
        FileHash(LHtml));
      if LPage mod 25 = 0 then
      begin
        WriteLn(LPage, ' listing pages checked, ', LSeen.Count, ' distinct abstracts');
      end;
    until not LHasNext;
    LLinks.LineBreak := #10;
    LPages.LineBreak := #10;
    LLinks.SaveToFile(ADirectory + 'links.tsv');
    LPages.SaveToFile(ADirectory + 'pages.tsv');
    WriteLn(LPage, ' listing pages reconciled, ', LSeen.Count, ' distinct abstracts');
  finally
    LPages.Free;
    LSeen.Free;
    LLinks.Free;
  end;
end;

procedure ReadAbstract(const AHtml, AUrl: String;
  out AId, ATitle, ACategory, AText, AAssets: String);
var
  LCanonical: String;
  LClasses: String;
  LScope: String;
  LMetaEnd: Integer;
  LExpression: TRegExpr;
  LAssets: TStringList;
begin
  LCanonical := CleanField(Capture('<link rel="canonical" href="([^"]+)"', AHtml));
  if Pos(ArchiveOrigin + '/abstract/', LCanonical) = 1 then
  begin
    LCanonical := Origin + Copy(LCanonical, Length(ArchiveOrigin) + 1);
  end;
  if DecodePath(LCanonical) <> DecodePath(AUrl) then
  begin
    raise EConvertError.Create('Abstract canonical URL mismatch: ' + LCanonical);
  end;
  LClasses := Capture('<div class="(post-[0-9]+ mworthy_abstract [^"]+)"', AHtml);
  if (Pos(' ' + JournalClass + ' ', LClasses) = 0) or
    (Pos(' ' + MeetingClass + ' ', LClasses) = 0) then
  begin
    raise EConvertError.Create('Abstract is outside the 2026 congress journal');
  end;
  AId := Capture('^post-([0-9]+) ', LClasses);
  ATitle := CleanField(Capture('<h2 class="entry-title"[^>]*>(.*?)</h2>', AHtml));
  LScope := Capture('<div class="entry-content">(.*?)<!-- end entry-content -->', AHtml);
  LMetaEnd := Pos('<!-- end abstract-meta-info -->', LScope);
  if (ATitle = '') or (LMetaEnd = 0) then
  begin
    raise EConvertError.Create('Missing abstract title or text boundary');
  end;
  Delete(LScope, 1, LMetaEnd + Length('<!-- end abstract-meta-info -->') - 1);
  ACategory := CleanField(Capture('<div class="session-box[^"]*">(.*?)</div>', LScope));
  ACategory := Trim(Copy(ACategory, Length('Category:') + 1));
  LExpression := TRegExpr.Create;
  LAssets := TStringList.Create;
  try
    LExpression.ModifierS := True;
    LExpression.Expression := '<div class="session-box[^"]*">.*?</div>';
    LScope := LExpression.Replace(LScope, '', False);
    LExpression.Expression := '<div class="cite-box"|<div id="social-bar"|<p class="backto"';
    if LExpression.Exec(LScope) then
    begin
      SetLength(LScope, LExpression.MatchPos[0] - 1);
    end;
    LAssets.Sorted := True;
    LAssets.Duplicates := dupIgnore;
    LAssets.Delimiter := '|';
    LAssets.StrictDelimiter := True;
    LExpression.Expression := '(?:href|src)=["'']' + Origin +
      '(/wp-content/uploads/[^"''?]+)';
    if LExpression.Exec(LScope) then
    begin
      repeat
        LAssets.Add(Origin + LExpression.Match[1]);
      until not LExpression.ExecNext;
    end;
    AAssets := LAssets.DelimitedText;
    AText := CleanField(LScope);
    if (AText = '') and (AAssets = '') then
    begin
      raise EConvertError.Create('Abstract has neither indexable text nor attachments');
    end;
  finally
    LAssets.Free;
    LExpression.Free;
  end;
end;

procedure Collect(AClient: TEuropePmc; const ADirectory, AOutput: String);
var
  LLinks: TStringList;
  LSeen: TStringList;
  LInventory: Text;
  LIndex: Text;
  LRow: Integer;
  LDone: Integer;
  LFailed: Integer;
  LFields: TFields;
  LFile: String;
  LUrl: String;
  LHtml: String;
  LId: String;
  LTitle: String;
  LCategory: String;
  LText: String;
  LAssets: String;
  LIsCached: Boolean;
begin
  LLinks := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LLinks.Text := ReadBytes(ADirectory + 'links.tsv');
    if (LLinks.Count < 2) or (LLinks[0] <> LinkHeader) then
    begin
      raise EConvertError.Create('Missing archive links or unexpected header');
    end;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    AssignFile(LInventory, AOutput + 'inventory.tsv');
    Rewrite(LInventory);
    try
      AssignFile(LIndex, AOutput + 'abstracts.tsv');
      Rewrite(LIndex);
      try
        SetTextCodePage(LInventory, CP_UTF8);
        SetTextCodePage(LIndex, CP_UTF8);
        Write(LInventory, InventoryHeader, #10);
        Write(LIndex, IndexHeader, #10);
        LDone := 0;
        LFailed := 0;
        for LRow := 1 to LLinks.Count - 1 do
        begin
          LFields := SplitFields(LLinks[LRow], Tab);
          if (Length(LFields) <> 4) or (Pos(Origin + '/abstract/', LFields[2]) <> 1) then
          begin
            raise EConvertError.CreateFmt('Invalid archive link on row %d', [LRow + 1]);
          end;
          LUrl := LFields[2];
          LFile := ADirectory + 'abstract-' + FileHash(LUrl) + '.html';
          try
            LIsCached := FileExists(LFile);
            if LIsCached then
            begin
              LHtml := ReadBytes(LFile);
            end
            else if Assigned(AClient) then
            begin
              LHtml := Fetch(AClient, Copy(LUrl, Length(Origin) + 1));
            end
            else
            begin
              Write(LInventory, Tab, LUrl, Tab, LFields[3], Tab, Tab, Tab,
                'pending', Tab, Tab, Tab, 'Cached abstract not yet available', #10);
              Inc(LFailed);
              Continue;
            end;
            ReadAbstract(LHtml, LUrl, LId, LTitle, LCategory, LText, LAssets);
            LSeen.Add(LId);
            if not LIsCached then
            begin
              SaveNew(LFile, LHtml);
            end;
            Write(LIndex, LId, Tab, LId, Tab, 'en', Tab, LTitle, Tab, LText, #10);
            Write(LInventory, LId, Tab, LUrl, Tab, LTitle, Tab, LCategory, Tab, LAssets,
              Tab, 'retrieved', Tab, Length(LHtml), Tab, FileHash(LHtml), Tab, #10);
            Inc(LDone);
          except
            on LException: Exception do
            begin
              Write(LInventory, Tab, LUrl, Tab, LFields[3], Tab, Tab, Tab,
                'pending', Tab, Tab, Tab, CleanCell(LException.Message), #10);
              Inc(LFailed);
              WriteLn(StdErr, LException.Message);
            end;
          end;
          if LRow mod 25 = 0 then
          begin
            Flush(LInventory);
            Flush(LIndex);
            WriteLn(LDone, ' abstracts indexed, ', LFailed, ' pending');
          end;
        end;
        WriteLn(LDone, ' abstracts indexed, ', LFailed, ' pending of ', LLinks.Count - 1);
        if LFailed > 0 then
        begin
          ExitCode := 2;
        end;
      finally
        CloseFile(LIndex);
      end;
    finally
      CloseFile(LInventory);
    end;
  finally
    LSeen.Free;
    LLinks.Free;
  end;
end;

procedure Run(const AMode, ADirectory, AOutput: String);
var
  LClient: TEuropePmc;
  LDirectory: String;
  LOutput: String;
begin
  LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  if not ForceDirectories(LDirectory) then
  begin
    raise EInOutError.Create('Could not create ' + LDirectory);
  end;
  if AMode = 'replay' then
  begin
    LOutput := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
    if SameText(LDirectory, LOutput) then
    begin
      raise EArgumentException.Create('Use a separate output directory for replay');
    end;
    if not ForceDirectories(LOutput) then
    begin
      raise EInOutError.Create('Could not create ' + LOutput);
    end;
    Collect(nil, LDirectory, LOutput);
    Exit;
  end;
  LClient := TEuropePmc.Create(Host);
  try
    if AMode = 'collect' then
    begin
      Collect(LClient, LDirectory, LDirectory);
    end
    else
    begin
      Discover(LClient, LDirectory, AMode = 'title-list');
    end;
  finally
    LClient.Free;
  end;
end;

procedure LoadRows(const APath, AHeader: String; ARows: TStrings);
begin
  ARows.Text := ReadBytes(APath);
  if (ARows.Count = 0) or (ARows[0] <> AHeader) then
  begin
    raise EConvertError.Create('Unexpected TSV header in ' + APath);
  end;
end;

procedure Audit(const ATopics, ALexical, AReviews: String);
var
  LTopics: TStringList;
  LLexical: TStringList;
  LReviews: TStringList;
  LPending: TStringList;
  LTopic: TFields;
  LLex: TFields;
  LReview: TFields;
  LPosition: Integer;
  LRow: Integer;
begin
  LTopics := TStringList.Create;
  LLexical := TStringList.Create;
  LReviews := TStringList.Create;
  LPending := TStringList.Create;
  try
    LoadRows(ATopics, TopicHeader, LTopics);
    LoadRows(ALexical, LexicalHeader, LLexical);
    LoadRows(AReviews, ReviewHeader, LReviews);
    if LTopics.Count <> LLexical.Count then
    begin
      raise EConvertError.Create('Topic and lexical record counts differ');
    end;
    LPending.Sorted := True;
    LPending.Duplicates := dupError;
    for LRow := 1 to LTopics.Count - 1 do
    begin
      LTopic := SplitFields(LTopics[LRow], Tab);
      LLex := SplitFields(LLexical[LRow], Tab);
      if (Length(LTopic) <> 3) or (Length(LLex) <> 10) or (LTopic[0] = '') or
        (LTopic[0] <> LLex[0]) or (LTopic[1] <> LLex[1]) then
      begin
        raise EConvertError.CreateFmt('Topic and lexical keys differ on row %d', [LRow + 1]);
      end;
      if (LTopic[2] <> '') or (LLex[5] <> '') then
      begin
        LPending.Add(LTopic[0]);
      end;
    end;
    for LRow := 1 to LReviews.Count - 1 do
    begin
      LReview := SplitFields(LReviews[LRow], Tab);
      if (Length(LReview) <> 3) or (LReview[1] = '') or (LReview[2] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid review on row %d', [LRow + 1]);
      end;
      LPosition := LPending.IndexOf(LReview[0]);
      if LPosition < 0 then
      begin
        raise EConvertError.Create('Unexpected or duplicate review ' + LReview[0]);
      end;
      LPending.Delete(LPosition);
    end;
    WriteLn(LTopics.Count - 1, ' abstracts reconciled, ', LReviews.Count - 1,
      ' reviewed, ', LPending.Count, ' pending');
    if LPending.Count > 0 then
    begin
      for LRow := 0 to LPending.Count - 1 do
      begin
        WriteLn(LPending[LRow]);
      end;
      ExitCode := 2;
    end;
  finally
    LPending.Free;
    LReviews.Free;
    LLexical.Free;
    LTopics.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount = 4) and (ParamStr(1) = 'audit') then
    begin
      Audit(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if (ParamCount = 3) and (ParamStr(1) = 'replay') then
    begin
      Run(ParamStr(1), ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 2) and
      ((ParamStr(1) = 'journal-list') or (ParamStr(1) = 'title-list') or
        (ParamStr(1) = 'collect')) then
    begin
      Run(ParamStr(1), ParamStr(2), '');
    end
    else
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.mds journal-list|title-list|collect DIRECTORY' + LineEnding +
        '       foodexperiment.mds replay CACHE_DIRECTORY OUTPUT_DIRECTORY' + LineEnding +
        '       foodexperiment.mds audit TOPIC_SCREEN LEXICAL_SCREEN REVIEWS');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
