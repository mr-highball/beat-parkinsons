{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentProceedings;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, DOM, XMLRead, foodexperiment.matching;

const
  Tab = #9;
  IndexHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'indexed_abstract';
  InventoryHeader = 'docid'#9'presentation_id'#9'program_code'#9'section'#9'track'#9 +
    'title'#9'body_blocks'#9'topics';
  LexicalHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'has_abstract'#9 +
    'ingredients'#9'symptoms'#9'title_ingredients'#9'title_symptoms'#9'joint_claim_ids';
  ReviewHeader = 'presentation_id'#9'disposition'#9'assessment';

function LoadProceedings(const APath: String): TXMLDocument;
var
  LBytes: RawByteString;
  LDeclaration: RawByteString;
  LEnd: Integer;
  LParser: TDOMParser;
  LInput: TXMLInputSource;
begin
  LBytes := TrimLeft(ReadBytes(APath));
  if Pos('<!DOCTYPE article', LBytes) = 1 then
  begin
    LEnd := Pos('>', LBytes);
    LDeclaration := Copy(LBytes, 1, LEnd);
    if (Pos('JATS-archivearticle1-4-mathml3.dtd">', LDeclaration) = 0) or
      (Pos('[', LDeclaration) > 0) then
    begin
      raise EConvertError.Create('Unexpected proceedings DOCTYPE declaration');
    end;
    // The PMC export has a self-contained body. Drop its external DTD reference for replay.
    Delete(LBytes, 1, LEnd);
  end;
  LParser := TDOMParser.Create;
  try
    LParser.Options.DisallowDoctype := True;
    LParser.Options.ExpandEntities := True;
    LParser.Options.IgnoreComments := True;
    LInput := TXMLInputSource.Create(AnsiString(LBytes));
    try
      Result := nil;
      try
        LParser.Parse(LInput, Result);
      except
        Result.Free;
        raise;
      end;
    finally
      LInput.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function Flatten(ANode: TDOMNode): String;
var
  LChild: TDOMNode;
begin
  Result := '';
  if ANode.NodeName = 'ref-list' then
  begin
    Exit;
  end;
  if ANode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE] then
  begin
    Exit(UTF8Encode(ANode.NodeValue));
  end;
  LChild := ANode.FirstChild;
  while Assigned(LChild) do
  begin
    Result := Result + Flatten(LChild);
    LChild := LChild.NextSibling;
  end;
  if (ANode.NodeName = 'break') or (ANode.NodeName = 'p') or
    (ANode.NodeName = 'td') or (ANode.NodeName = 'th') then
  begin
    Result := Result + ' ';
  end;
end;

procedure ExtractRecords(ADocument: TXMLDocument; AIndex, AInventory, ATopicNames: TStrings;
  ATopicMatcher: TMatcher);
var
  LRoot: TDOMElement;
  LBody: TDOMNode;
  LSection: TDOMNode;
  LTitle: TDOMNode;
  LBreak: TDOMNode;
  LBlock: TDOMNode;
  LGroup: String;
  LTrack: String;
  LCode: String;
  LRecordId: String;
  LLanguage: String;
  LTitleText: String;
  LAbstract: String;
  LBlockText: String;
  LTopicFlags: TMatchFlags;
  LBlocks: Integer;
  LOccurrence: Integer;
  LRow: Integer;
  LSeen: TStringList;
begin
  LRoot := ADocument.DocumentElement;
  if not Assigned(LRoot) or (LRoot.NodeName <> 'article') then
  begin
    raise EConvertError.Create('Expected a JATS article');
  end;
  LBody := LRoot.FindNode('body');
  if not Assigned(LBody) then
  begin
    raise EConvertError.Create('Missing proceedings body');
  end;
  LLanguage := UTF8Encode(LRoot.GetAttribute('xml:lang'));
  SetLength(LTopicFlags, ATopicNames.Count);
  LSeen := TStringList.Create;
  try
    LGroup := '';
    LTrack := '';
    LSection := LBody.FirstChild;
    while Assigned(LSection) do
    begin
      LTitle := LSection.FindNode('title');
      if (LSection.NodeName <> 'sec') or not Assigned(LTitle) then
      begin
        raise EConvertError.Create('Expected a titled section in the proceedings body');
      end;
      LBreak := LTitle.FindNode('break');
      if not Assigned(LBreak) then
      begin
        LTitleText := Trim(CleanCell(Flatten(LTitle)));
        if (Length(LTitleText) > 2) and (LTitleText[1] in ['1'..'9']) and
          (LTitleText[2] = '-') then
        begin
          LGroup := LTitleText;
          LTrack := '';
        end
        else
        begin
          LTrack := LTitleText;
        end;
        if Assigned(LTitle.NextSibling) and (LTitleText <> 'AUTHOR INDEX') then
        begin
          raise EConvertError.CreateFmt('Unnumbered section with body text: %s', [LTitleText]);
        end;
        LSection := LSection.NextSibling;
        Continue;
      end;
      LCode := '';
      LBlock := LTitle.FirstChild;
      while LBlock <> LBreak do
      begin
        LCode := LCode + Flatten(LBlock);
        LBlock := LBlock.NextSibling;
      end;
      LCode := Trim(CleanCell(LCode));
      LTitleText := '';
      LBlock := LBreak.NextSibling;
      while Assigned(LBlock) do
      begin
        LTitleText := LTitleText + Flatten(LBlock);
        LBlock := LBlock.NextSibling;
      end;
      LTitleText := Trim(CleanCell(LTitleText));
      if (LCode = '') or (LTitleText = '') or (LGroup = '') then
      begin
        raise EConvertError.Create('Presentation is missing its code, title, or section');
      end;
      LOccurrence := StrToIntDef(LSeen.Values[LCode], 0) + 1;
      LSeen.Values[LCode] := IntToStr(LOccurrence);
      LRecordId := LCode;
      if LOccurrence > 1 then
      begin
        LRecordId := LCode + '-' + IntToStr(LOccurrence);
      end;
      LAbstract := '';
      LBlocks := 0;
      LBlock := LTitle.NextSibling;
      while Assigned(LBlock) do
      begin
        LBlockText := Trim(CleanCell(Flatten(LBlock)));
        if LBlockText <> '' then
        begin
          if LBlocks > 0 then
          begin
            LAbstract := LAbstract + ' ';
          end;
          LAbstract := LAbstract + LBlockText;
          Inc(LBlocks);
        end;
        LBlock := LBlock.NextSibling;
      end;
      LRow := AIndex.Count;
      FillChar(LTopicFlags[0], Length(LTopicFlags) * SizeOf(Boolean), 0);
      ATopicMatcher.Match(LTitleText, LTopicFlags);
      ATopicMatcher.Match(LAbstract, LTopicFlags);
      AIndex.Add(IntToStr(LRow) + Tab + LRecordId + Tab + LLanguage + Tab +
        LTitleText + Tab + LAbstract);
      AInventory.Add(IntToStr(LRow) + Tab + LRecordId + Tab + LCode + Tab +
        LGroup + Tab + LTrack + Tab + LTitleText + Tab + IntToStr(LBlocks) + Tab +
        JoinMatches(ATopicNames, LTopicFlags, 0));
      LSection := LSection.NextSibling;
    end;
    if AIndex.Count < 2 then
    begin
      raise EConvertError.Create('No numbered presentations found');
    end;
    WriteLn(AIndex.Count - 1, ' presentations and ', LSeen.Count, ' distinct printed codes');
  finally
    LSeen.Free;
  end;
end;

procedure Run(const ASource, ATopics, AOutput: String);
var
  LDirectory: String;
  LDocument: TXMLDocument;
  LIndex: TStringList;
  LInventory: TStringList;
  LTopicNames: TStringList;
  LTopicMatcher: TMatcher;
begin
  LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
  if FileExists(LDirectory + 'abstracts.tsv') or FileExists(LDirectory + 'inventory.tsv') then
  begin
    raise EInOutError.Create('Use a new proceedings output directory');
  end;
  LDocument := LoadProceedings(ASource);
  try
    LIndex := TStringList.Create;
    try
      LInventory := TStringList.Create;
      try
        LIndex.LineBreak := #10;
        LInventory.LineBreak := #10;
        LIndex.Add(IndexHeader);
        LInventory.Add(InventoryHeader);
        LTopicMatcher := TMatcher.Create;
        try
          LTopicNames := TStringList.Create;
          try
    LoadTermGroups(ATopics, LTopicMatcher, LTopicNames);
            ExtractRecords(LDocument, LIndex, LInventory, LTopicNames, LTopicMatcher);
          finally
            LTopicNames.Free;
          end;
        finally
          LTopicMatcher.Free;
        end;
        if not ForceDirectories(LDirectory) then
        begin
          raise EInOutError.Create('Unable to create proceedings output directory');
        end;
        LIndex.SaveToFile(LDirectory + 'abstracts.tsv');
        LInventory.SaveToFile(LDirectory + 'inventory.tsv');
      finally
        LInventory.Free;
      end;
    finally
      LIndex.Free;
    end;
  finally
    LDocument.Free;
  end;
end;

procedure LoadRows(const APath, AHeader: String; ARows: TStrings);
begin
  ARows.Text := ReadBytes(APath);
  if (ARows.Count < 2) or (ARows[0] <> AHeader) then
  begin
    raise EConvertError.Create('Unexpected or empty TSV: ' + APath);
  end;
end;

procedure LoadReviewKeys(const AInventory, ALexical: String; AKeys: TStringList);
var
  LInventory: TStringList;
  LLexical: TStringList;
  LRow: Integer;
  LFields: TStringArray;
  LMatches: TStringArray;
begin
  LInventory := TStringList.Create;
  try
    LLexical := TStringList.Create;
    try
      LoadRows(AInventory, InventoryHeader, LInventory);
      LoadRows(ALexical, LexicalHeader, LLexical);
      if LInventory.Count <> LLexical.Count then
      begin
        raise EConvertError.Create('Inventory and lexical screen have different row counts');
      end;
      for LRow := 1 to LInventory.Count - 1 do
      begin
        LFields := LInventory[LRow].Split([Tab]);
        LMatches := LLexical[LRow].Split([Tab]);
        if (Length(LFields) <> 8) or (Length(LMatches) <> 10) or
          (LFields[0] <> IntToStr(LRow)) or (LFields[1] = '') or
          (LFields[0] <> LMatches[0]) or (LFields[1] <> LMatches[1]) or
          (LFields[5] <> LMatches[3]) then
        begin
          raise EConvertError.CreateFmt('Unmatched inventory or lexical row %d', [LRow + 1]);
        end;
        if (LFields[7] <> '') or (LMatches[5] <> '') then
        begin
          AKeys.Add(LFields[1]);
        end;
      end;
      WriteLn(LInventory.Count - 1, ' presentation records reconciled');
    finally
      LLexical.Free;
    end;
  finally
    LInventory.Free;
  end;
end;

procedure Audit(const AInventory, ALexical, AReviews: String);
var
  LKeys: TStringList;
  LRows: TStringList;
  LFields: TStringArray;
  LIndex: Integer;
  LRow: Integer;
begin
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    LKeys.Duplicates := dupError;
    LoadReviewKeys(AInventory, ALexical, LKeys);
    LRows := TStringList.Create;
    try
      LoadRows(AReviews, ReviewHeader, LRows);
      for LRow := 1 to LRows.Count - 1 do
      begin
        LFields := LRows[LRow].Split([Tab]);
        if (Length(LFields) <> 3) or (LFields[1] = '') or (LFields[2] = '') then
        begin
          raise EConvertError.CreateFmt('Invalid proceedings review row %d', [LRow + 1]);
        end;
        LIndex := LKeys.IndexOf(LFields[0]);
        if LIndex < 0 then
        begin
          raise EConvertError.Create('Unexpected or duplicate proceedings review: ' + LFields[0]);
        end;
        LKeys.Delete(LIndex);
      end;
      if LKeys.Count > 0 then
      begin
        raise EConvertError.Create('Missing proceedings reviews: ' + LKeys.CommaText);
      end;
      WriteLn(LRows.Count - 1, ' flagged presentations reviewed');
    finally
      LRows.Free;
    end;
  finally
    LKeys.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if ParamCount = 3 then
    begin
      Run(ParamStr(1), ParamStr(2), ParamStr(3));
    end
    else if (ParamCount = 4) and (ParamStr(1) = 'audit') then
    begin
      Audit(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.proceedings INPUT_XML TOPIC_TERMS OUTPUT_DIR' + LineEnding +
        '       foodexperiment.proceedings audit INVENTORY LEXICAL_SCREEN REVIEWS');
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
