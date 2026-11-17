{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentMdsOcr;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, FPSHA256, foodexperiment.externaldata,
  foodexperiment.matching, foodexperiment.winocr;

const
  Tab = #9;
  AssetHeader = 'docid'#9'url'#9'cache_file'#9'status'#9'bytes'#9'sha256'#9'detail';
  OcrHeader = 'asset_id'#9'docid'#9'url'#9'image_sha256'#9'language'#9 +
    'status'#9'text_bytes'#9'text_sha256'#9'detail';
  IndexHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'indexed_abstract';
  LexicalHeader = 'docid'#9'presentation_id'#9'language'#9'title'#9'has_abstract'#9 +
    'ingredients'#9'symptoms'#9'title_ingredients'#9'title_symptoms'#9'joint_claim_ids';
  DeltaHeader = 'docid'#9'claim_ids'#9'disposition'#9'assessment';
  ImageReviewHeader = 'asset_id'#9'docid'#9'url'#9'disposition'#9'assessment';
  OcrCacheVersion = '3';

function IsSha256(const AValue: String): Boolean;
var
  LChar: Char;
begin
  Result := False;
  if Length(AValue) <> 64 then
  begin
    Exit;
  end;
  for LChar in AValue do
  begin
    if not (LChar in ['0'..'9', 'a'..'f']) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

procedure LoadInventory(const APath: String; ARows: TStrings);
var
  LSeen: TStringList;
  LFields: TFields;
  LExtension: String;
  LRow: Integer;
  LDocId: Integer;
  LSize: Int64;
begin
  ARows.Text := ReadBytes(APath);
  if (ARows.Count < 2) or (ARows[0] <> AssetHeader) then
  begin
    raise EConvertError.Create('Missing attachment inventory or unexpected header');
  end;
  LSeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    for LRow := 1 to ARows.Count - 1 do
    begin
      LFields := SplitFields(ARows[LRow], Tab);
      if (Length(LFields) <> 7) or not TryStrToInt(LFields[0], LDocId) or
        (LDocId <= 0) or (LFields[1] = '') then
      begin
        raise EConvertError.CreateFmt('Malformed attachment inventory row %d', [LRow + 1]);
      end;
      LExtension := ExtractFileExt(LFields[2]);
      if not IsSha256(ChangeFileExt(LFields[2], '')) or
        ((LExtension <> '.jpg') and (LExtension <> '.jpeg') and (LExtension <> '.png')) then
      begin
        raise EConvertError.CreateFmt('Malformed attachment cache key on row %d', [LRow + 1]);
      end;
      if LFields[3] = 'retrieved' then
      begin
        if not TryStrToInt64(LFields[4], LSize) or (LSize < 8) or not IsSha256(LFields[5]) then
        begin
          raise EConvertError.CreateFmt('Missing attachment provenance on row %d', [LRow + 1]);
        end;
      end
      else if LFields[3] <> 'pending' then
      begin
        raise EConvertError.CreateFmt('Unknown attachment status on row %d', [LRow + 1]);
      end;
      LSeen.Add(LFields[2]);
    end;
  finally
    LSeen.Free;
  end;
end;

procedure VerifyImage(const APath: String; ASize: Int64; const AHash: String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    if (LFile.Size <> ASize) or (LowerCase(TSHA256.StreamHexa(LFile)) <> AHash) then
    begin
      raise EConvertError.Create('Cached image differs from the attachment inventory');
    end;
  finally
    LFile.Free;
  end;
end;

function RecognizeImage(AOcr: TWindowsOcr; const AImage, ATextCache: String): RawByteString;
var
  LStream: TFileStream;
  LStage: String;
begin
  if FileExists(ATextCache) then
  begin
    Result := ReadBytes(ATextCache);
    Exit;
  end;
  Result := AOcr.Recognize(UTF8Decode(AImage));
  LStage := ATextCache + '.part';
  LStream := TFileStream.Create(LStage, fmCreate);
  try
    if Result <> '' then
    begin
      LStream.WriteBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
  if FileExists(ATextCache) or not RenameFile(LStage, ATextCache) then
  begin
    raise EInOutError.Create('Could not publish recognized text');
  end;
end;

procedure WriteIndex(ARows: TStrings; AOcr: TWindowsOcr;
  const AImageCache, AOutput, ALanguage: String);
var
  LLedger: Text;
  LIndex: Text;
  LRow: Integer;
  LExtracted: Integer;
  LEmpty: Integer;
  LPending: Integer;
  LFields: TFields;
  LId: String;
  LImage: String;
  LTextPath: String;
  LText: RawByteString;
  LStatus: String;
  LDetail: String;
  LHash: String;
begin
  AssignFile(LLedger, AOutput + 'ocr.tsv');
  Rewrite(LLedger);
  try
    AssignFile(LIndex, AOutput + 'index.tsv');
    Rewrite(LIndex);
    try
      SetTextCodePage(LLedger, CP_UTF8);
      SetTextCodePage(LIndex, CP_UTF8);
      Write(LLedger, OcrHeader, #10);
      Write(LIndex, IndexHeader, #10);
      LExtracted := 0;
      LEmpty := 0;
      LPending := 0;
      for LRow := 1 to ARows.Count - 1 do
      begin
        LFields := SplitFields(ARows[LRow], Tab);
        LId := ChangeFileExt(LFields[2], '');
        LStatus := 'pending image';
        LDetail := LFields[6];
        LText := '';
        LHash := '';
        if LFields[3] = 'retrieved' then
        begin
          LImage := AImageCache + LFields[2];
          LTextPath := AOutput + 'text-' + OcrCacheVersion + '-' + ALanguage + '-' +
            LFields[5] + '.txt';
          try
            VerifyImage(LImage, StrToInt64(LFields[4]), LFields[5]);
            LText := RecognizeImage(AOcr, LImage, LTextPath);
            TSHA256.DigestHexa(BytesOf(LText), LHash);
            LHash := LowerCase(LHash);
            if Trim(LText) = '' then
            begin
              LStatus := 'no text';
              Inc(LEmpty);
            end
            else
            begin
              LStatus := 'recognized';
              Write(LIndex, LId, Tab, LFields[0], Tab, ALanguage, Tab, 'Attachment', Tab,
                CleanCell(LText), #10);
              Inc(LExtracted);
            end;
          except
            on LException: Exception do
            begin
              LStatus := 'extraction failed';
              LDetail := CleanCell(LException.Message);
            end;
          end;
        end;
        Write(LLedger, LId, Tab, LFields[0], Tab, LFields[1], Tab, LFields[5], Tab, ALanguage, Tab,
          LStatus, Tab);
        if LHash = '' then
        begin
          Write(LLedger, Tab, Tab);
          Inc(LPending);
        end
        else
        begin
          Write(LLedger, Length(LText), Tab, LHash, Tab);
        end;
        Write(LLedger, LDetail, #10);
        if LRow mod 25 = 0 then
        begin
          Flush(LLedger);
          Flush(LIndex);
          WriteLn(LExtracted, ' recognized, ', LEmpty, ' without text, ',
            LPending, ' pending of ', LRow, ' processed');
        end;
      end;
      WriteLn(LExtracted, ' recognized, ', LEmpty, ' without text, ',
        LPending, ' pending of ', ARows.Count - 1);
      if LPending <> 0 then
      begin
        ExitCode := 2;
      end;
    finally
      CloseFile(LIndex);
    end;
  finally
    CloseFile(LLedger);
  end;
end;

procedure Run(const AInventory, ACache, AOutput, ALanguage: String);
var
  LRows: TStringList;
  LOcr: TWindowsOcr;
  LOutput: String;
  LChar: Char;
begin
  if ALanguage = '' then
  begin
    raise EArgumentException.Create('Expected an OCR language tag');
  end;
  for LChar in ALanguage do
  begin
    if not (LChar in ['A'..'Z', 'a'..'z', '0'..'9', '-']) then
    begin
      raise EArgumentException.Create('Invalid OCR language tag');
    end;
  end;
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
  if SameText(ExpandFileName(AInventory), LOutput + 'ocr.tsv') or
    SameText(ExpandFileName(AInventory), LOutput + 'index.tsv') then
  begin
    raise EArgumentException.Create('Use separate input and output ledgers');
  end;
  LRows := TStringList.Create;
  try
    LoadInventory(AInventory, LRows);
    if not ForceDirectories(LOutput) then
    begin
      raise EInOutError.Create('Could not create the OCR output directory');
    end;
    LOcr := TWindowsOcr.Create(UTF8Decode(ALanguage));
    try
      WriteIndex(LRows, LOcr, IncludeTrailingPathDelimiter(ExpandFileName(ACache)), LOutput,
        ALanguage);
    finally
      LOcr.Free;
    end;
  finally
    LRows.Free;
  end;
end;

procedure LoadIndex(const APath: String; ARows: TStrings);
begin
  ARows.Text := ReadBytes(APath);
  if (ARows.Count < 2) or (ARows[0] <> IndexHeader) then
  begin
    raise EConvertError.CreateFmt('Missing proceedings index: %s', [APath]);
  end;
end;

procedure JoinIndexes(const ABodyIndex, AAttachmentIndex, AOutput: String);
var
  LBodies: TStringList;
  LAttachments: TStringList;
  LBodyKeys: TStringList;
  LAttachmentText: TStringList;
  LSeen: TStringList;
  LRow: Integer;
  LFields: TFields;
  LKey: String;
  LText: String;
  LOutput: Text;
begin
  if SameText(ExpandFileName(ABodyIndex), ExpandFileName(AOutput)) or
    SameText(ExpandFileName(AAttachmentIndex), ExpandFileName(AOutput)) then
  begin
    raise EArgumentException.Create('Use a separate joined index output path');
  end;
  LBodies := TStringList.Create;
  LAttachments := TStringList.Create;
  LBodyKeys := TStringList.Create;
  LAttachmentText := TStringList.Create;
  LSeen := TStringList.Create;
  try
    LoadIndex(ABodyIndex, LBodies);
    LoadIndex(AAttachmentIndex, LAttachments);
    LBodyKeys.Sorted := True;
    LBodyKeys.Duplicates := dupError;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    for LRow := 1 to LBodies.Count - 1 do
    begin
      LFields := SplitFields(LBodies[LRow], Tab);
      if (Length(LFields) <> 5) or (LFields[0] = '') or (LFields[0] <> LFields[1]) then
      begin
        raise EConvertError.CreateFmt('Invalid body index row %d', [LRow + 1]);
      end;
      LBodyKeys.Add(LFields[0]);
    end;
    for LRow := 1 to LAttachments.Count - 1 do
    begin
      LFields := SplitFields(LAttachments[LRow], Tab);
      if (Length(LFields) <> 5) or not IsSha256(LFields[0]) or
        (LBodyKeys.IndexOf(LFields[1]) < 0) or (LFields[4] = '') then
      begin
        raise EConvertError.CreateFmt('Invalid OCR index row %d', [LRow + 1]);
      end;
      LSeen.Add(LFields[0]);
      LKey := LFields[1];
      LAttachmentText.Values[LKey] := LAttachmentText.Values[LKey] + ' ' + LFields[4];
    end;
    AssignFile(LOutput, AOutput);
    Rewrite(LOutput);
    try
      SetTextCodePage(LOutput, CP_UTF8);
      Write(LOutput, IndexHeader, #10);
      for LRow := 1 to LBodies.Count - 1 do
      begin
        LFields := SplitFields(LBodies[LRow], Tab);
        LText := LAttachmentText.Values[LFields[0]];
        if LText <> '' then
        begin
          Write(LOutput, LBodies[LRow], LText, #10);
        end;
      end;
      WriteLn(LAttachmentText.Count, ' presentation bodies joined to ',
        LSeen.Count, ' recognized attachments');
    finally
      CloseFile(LOutput);
    end;
  finally
    LSeen.Free;
    LAttachmentText.Free;
    LBodyKeys.Free;
    LAttachments.Free;
    LBodies.Free;
  end;
end;

procedure LoadJointClaims(const APath: String; AClaims: TStrings);
var
  LRows: TStringList;
  LRow: Integer;
  LFields: TFields;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count < 2) or (LRows[0] <> LexicalHeader) then
    begin
      raise EConvertError.CreateFmt('Missing presentation lexical screen: %s', [APath]);
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 10) or (LFields[0] = '') or (LFields[0] <> LFields[1]) or
        (AClaims.IndexOfName(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid lexical screen row %d in %s', [LRow + 1, APath]);
      end;
      AClaims.Add(LFields[0] + '=' + LFields[9]);
    end;
  finally
    LRows.Free;
  end;
end;

procedure VerifyJoinedClaims(const ABodyScreen, AJoinedScreen, AReviewPath: String);
var
  LBody: TStringList;
  LJoined: TStringList;
  LPending: TStringList;
  LReviews: TStringList;
  LIndex: Integer;
  LBodyIndex: Integer;
  LReviewIndex: Integer;
  LDocId: String;
  LBase: String;
  LAdded: String;
  LClaim: String;
  LFields: TFields;
  LReviewed: Integer;
begin
  LBody := TStringList.Create;
  LJoined := TStringList.Create;
  LPending := TStringList.Create;
  LReviews := TStringList.Create;
  try
    LoadJointClaims(ABodyScreen, LBody);
    LoadJointClaims(AJoinedScreen, LJoined);
    for LIndex := 0 to LJoined.Count - 1 do
    begin
      LDocId := LJoined.Names[LIndex];
      LBodyIndex := LBody.IndexOfName(LDocId);
      if LBodyIndex < 0 then
      begin
        raise EConvertError.Create('Joined presentation absent from the body screen: ' + LDocId);
      end;
      LBase := '|' + LBody.ValueFromIndex[LBodyIndex] + '|';
      LAdded := '';
      for LClaim in SplitFields(LJoined.ValueFromIndex[LIndex], '|') do
      begin
        if (LClaim <> '') and (Pos('|' + LClaim + '|', LBase) = 0) then
        begin
          if LAdded <> '' then
          begin
            LAdded := LAdded + '|';
          end;
          LAdded := LAdded + LClaim;
        end;
      end;
      if LAdded <> '' then
      begin
        LPending.Add(LDocId + Tab + LAdded);
      end;
    end;
    LReviewed := 0;
    if AReviewPath <> '-' then
    begin
      LReviews.Text := ReadBytes(AReviewPath);
      if (LReviews.Count = 0) or (LReviews[0] <> DeltaHeader) then
      begin
        raise EConvertError.Create('Missing joined claim dispositions or unexpected header');
      end;
      for LIndex := 1 to LReviews.Count - 1 do
      begin
        LFields := SplitFields(LReviews[LIndex], Tab);
        if (Length(LFields) <> 4) or (LFields[2] = '') or (LFields[3] = '') then
        begin
          raise EConvertError.CreateFmt('Invalid joined claim disposition row %d', [LIndex + 1]);
        end;
        LReviewIndex := LPending.IndexOf(LFields[0] + Tab + LFields[1]);
        if LReviewIndex < 0 then
        begin
          raise EConvertError.Create('Duplicate or unexpected joined claim disposition: ' +
            LFields[0]);
        end;
        LPending.Delete(LReviewIndex);
        Inc(LReviewed);
      end;
    end;
    WriteLn(LReviewed, ' joined presentations reviewed, ', LPending.Count, ' pending');
    for LIndex := 0 to LPending.Count - 1 do
    begin
      WriteLn(LPending[LIndex]);
    end;
    if LPending.Count <> 0 then
    begin
      ExitCode := 2;
    end;
  finally
    LReviews.Free;
    LPending.Free;
    LJoined.Free;
    LBody.Free;
  end;
end;

procedure AuditNoText(const AOcrLedger, AReviewPath: String);
var
  LRows: TStringList;
  LExpected: TStringList;
  LFields: TFields;
  LRow: Integer;
  LIndex: Integer;
  LReviewed: Integer;
begin
  LRows := TStringList.Create;
  LExpected := TStringList.Create;
  try
    LExpected.Sorted := True;
    LExpected.CaseSensitive := True;
    LExpected.Duplicates := dupError;
    LRows.Text := ReadBytes(AOcrLedger);
    if (LRows.Count < 2) or (LRows[0] <> OcrHeader) then
    begin
      raise EConvertError.Create('Missing OCR ledger or unexpected header');
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 9) or not IsSha256(LFields[0]) then
      begin
        raise EConvertError.CreateFmt('Malformed OCR ledger row %d', [LRow + 1]);
      end;
      if LFields[5] = 'no text' then
      begin
        LExpected.Add(LFields[0] + Tab + LFields[1] + Tab + LFields[2]);
      end
      else if LFields[5] <> 'recognized' then
      begin
        raise EConvertError.Create('Resolve OCR extraction failures before auditing blank results: ' +
          LFields[0]);
      end;
    end;
    LReviewed := 0;
    if AReviewPath <> '-' then
    begin
      LRows.Text := ReadBytes(AReviewPath);
      if (LRows.Count = 0) or (LRows[0] <> ImageReviewHeader) then
      begin
        raise EConvertError.Create('Missing image reviews or unexpected header');
      end;
      for LRow := 1 to LRows.Count - 1 do
      begin
        LFields := SplitFields(LRows[LRow], Tab);
        if (Length(LFields) <> 5) or (Trim(LFields[3]) = '') or (Trim(LFields[4]) = '') then
        begin
          raise EConvertError.CreateFmt('Malformed image review row %d', [LRow + 1]);
        end;
        LIndex := LExpected.IndexOf(LFields[0] + Tab + LFields[1] + Tab + LFields[2]);
        if LIndex < 0 then
        begin
          raise EConvertError.Create('Duplicate or unexpected image review: ' + LFields[0]);
        end;
        LExpected.Delete(LIndex);
        Inc(LReviewed);
      end;
    end;
    WriteLn(LReviewed, ' images without OCR text reviewed, ', LExpected.Count, ' pending');
    for LRow := 0 to LExpected.Count - 1 do
    begin
      WriteLn(LExpected[LRow]);
    end;
    if LExpected.Count <> 0 then
    begin
      ExitCode := 2;
    end;
  finally
    LExpected.Free;
    LRows.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount = 3) and (ParamStr(1) = 'audit-no-text') then
    begin
      AuditNoText(ParamStr(2), ParamStr(3));
    end
    else if ParamCount <> 4 then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.mdsocr ASSET_INVENTORY IMAGE_CACHE OUTPUT_DIRECTORY LANGUAGE' +
        LineEnding + '       foodexperiment.mdsocr join BODY_INDEX OCR_INDEX OUTPUT_INDEX' +
        LineEnding + '       foodexperiment.mdsocr delta BODY_LEXICAL JOINED_LEXICAL REVIEWS_OR_DASH' +
        LineEnding + '       foodexperiment.mdsocr audit-no-text OCR_LEDGER REVIEWS_OR_DASH');
    end
    else if ParamStr(1) = 'join' then
    begin
      JoinIndexes(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else if ParamStr(1) = 'delta' then
    begin
      VerifyJoinedClaims(ParamStr(2), ParamStr(3), ParamStr(4));
    end
    else
    begin
      Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
