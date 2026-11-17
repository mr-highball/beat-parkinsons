{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentMdsAssets;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Windows, FPSHA256, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

const
  Host = 'www.mdsabstracts.org';
  Origin = 'https://' + Host;
  UploadPrefix = Origin + '/wp-content/uploads/';
  Tab = #9;
  BodyHeader = 'docid'#9'url'#9'title'#9'category'#9'assets'#9 +
    'status'#9'bytes'#9'sha256'#9'detail';
  AssetHeader = 'docid'#9'url'#9'cache_file'#9'status'#9'bytes'#9'sha256'#9'detail';

function AssetExtension(const AUrl: String): String;
begin
  Result := LowerCase(ExtractFileExt(AUrl));
  if (Pos(UploadPrefix, AUrl) <> 1) or
    ((Result <> '.jpg') and (Result <> '.jpeg') and (Result <> '.png')) then
  begin
    raise EConvertError.CreateFmt('Unexpected attachment URL: %s', [AUrl]);
  end;
end;

function CacheName(const AUrl: RawByteString): String;
var
  LHash: String;
begin
  TSHA256.DigestHexa(BytesOf(AUrl), LHash);
  Result := LowerCase(LHash) + AssetExtension(AUrl);
end;

procedure LoadAttachments(const AInventory: String; AAttachments: TStrings);
var
  LRows: TStringList;
  LSeen: TStringList;
  LDocs: TStringList;
  LFields: TFields;
  LUrls: TFields;
  LUrl: String;
  LRow: Integer;
  LDocId: Integer;
begin
  LRows := TStringList.Create;
  LSeen := TStringList.Create;
  LDocs := TStringList.Create;
  try
    LRows.Text := ReadBytes(AInventory);
    if (LRows.Count < 2) or (LRows[0] <> BodyHeader) then
    begin
      raise EConvertError.Create('Missing abstract inventory or unexpected header');
    end;
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LDocs.Sorted := True;
    LDocs.Duplicates := dupError;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := SplitFields(LRows[LRow], Tab);
      if (Length(LFields) <> 9) or (LFields[5] <> 'retrieved') or
        not TryStrToInt(LFields[0], LDocId) or (LDocId <= 0) then
      begin
        raise EConvertError.CreateFmt('Unreconciled abstract inventory row %d', [LRow + 1]);
      end;
      LDocs.Add(LFields[0]);
      if LFields[4] = '' then
      begin
        Continue;
      end;
      LUrls := SplitFields(LFields[4], '|');
      for LUrl in LUrls do
      begin
        AssetExtension(LUrl);
        LSeen.Add(LUrl);
        AAttachments.Add(LFields[0] + Tab + LUrl);
      end;
    end;
    if AAttachments.Count = 0 then
    begin
      raise EConvertError.Create('The inventory contains no attachments');
    end;
  finally
    LDocs.Free;
    LSeen.Free;
    LRows.Free;
  end;
end;

procedure InspectImage(const APath: String; out ASize: Int64; out AHash: String);
const
  PngMagic: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  LStream: TFileStream;
  LMagic: array[0..7] of Byte;
  LIsPng: Boolean;
  LIsJpeg: Boolean;
  LIsTiff: Boolean;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    LStream.ReadBuffer(LMagic, SizeOf(LMagic));
    LIsPng := CompareMem(@LMagic[0], @PngMagic[0], SizeOf(PngMagic));
    LIsJpeg := (LMagic[0] = $FF) and (LMagic[1] = $D8) and (LMagic[2] = $FF);
    LIsTiff := ((LMagic[0] = $49) and (LMagic[1] = $49) and
      (LMagic[2] = $2A) and (LMagic[3] = 0)) or
      ((LMagic[0] = $4D) and (LMagic[1] = $4D) and
      (LMagic[2] = 0) and (LMagic[3] = $2A));
    if not (LIsPng or LIsJpeg or LIsTiff) then
    begin
      raise EConvertError.Create('Unrecognized attachment image signature');
    end;
    ASize := LStream.Size;
    LStream.Position := 0;
    AHash := LowerCase(TSHA256.StreamHexa(LStream));
  finally
    LStream.Free;
  end;
end;

procedure FetchImage(AClient: TEuropePmc; const AUrl, APath: String;
  out ASize: Int64; out AHash: String);
var
  LStage: String;
  LStream: TFileStream;
  LResponse: TSearchResponse;
  LAttempt: Integer;
  LDelay: DWORD;
begin
  LStage := APath + '.part';
  LDelay := 350;
  for LAttempt := 1 to 3 do
  begin
    Sleep(LDelay);
    LStream := TFileStream.Create(LStage, fmCreate);
    try
      LResponse := AClient.GetPath(Copy(AUrl, Length(Origin) + 1), LStream);
    finally
      LStream.Free;
    end;
    if LResponse.Status = 200 then
    begin
      InspectImage(LStage, ASize, AHash);
      if FileExists(APath) or not RenameFile(LStage, APath) then
      begin
        raise EInOutError.Create('Could not publish the downloaded attachment');
      end;
      Exit;
    end;
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
  raise EInOutError.CreateFmt('HTTP %d, Retry-After %d seconds',
    [LResponse.Status, LResponse.RetryAfterSeconds]);
end;

procedure WriteInventory(AAttachments: TStrings; AClient: TEuropePmc;
  const ACache, AOutput: String);
var
  LOutput: Text;
  LRow: Integer;
  LDone: Integer;
  LFields: TFields;
  LName: String;
  LPath: String;
  LHash: String;
  LDetail: String;
  LSize: Int64;
begin
  AssignFile(LOutput, AOutput);
  Rewrite(LOutput);
  try
    SetTextCodePage(LOutput, CP_UTF8);
    Write(LOutput, AssetHeader, #10);
    LDone := 0;
    for LRow := 0 to AAttachments.Count - 1 do
    begin
      LFields := SplitFields(AAttachments[LRow], Tab);
      LName := CacheName(LFields[1]);
      LPath := ACache + LName;
      LDetail := '';
      try
        if FileExists(LPath) then
        begin
          InspectImage(LPath, LSize, LHash);
        end
        else if Assigned(AClient) then
        begin
          FetchImage(AClient, LFields[1], LPath, LSize, LHash);
        end
        else
        begin
          LDetail := 'Cached attachment not yet available';
        end;
      except
        on LException: Exception do
        begin
          LDetail := CleanCell(LException.Message);
        end;
      end;
      Write(LOutput, AAttachments[LRow], Tab, LName, Tab);
      if LDetail = '' then
      begin
        Write(LOutput, 'retrieved', Tab, LSize, Tab, LHash, Tab, #10);
        Inc(LDone);
      end
      else
      begin
        Write(LOutput, 'pending', Tab, Tab, Tab, LDetail, #10);
      end;
      if (LRow + 1) mod 25 = 0 then
      begin
        Flush(LOutput);
        WriteLn(LDone, ' attachments retrieved of ', LRow + 1, ' processed');
      end;
    end;
    WriteLn(LDone, ' attachments retrieved, ', AAttachments.Count - LDone,
      ' pending of ', AAttachments.Count);
    if LDone <> AAttachments.Count then
    begin
      ExitCode := 2;
    end;
  finally
    CloseFile(LOutput);
  end;
end;

procedure Run(const AMode, AInventory, ACache, AOutput: String);
var
  LAttachments: TStringList;
  LClient: TEuropePmc;
  LCache: String;
begin
  if SameText(ExpandFileName(AInventory), ExpandFileName(AOutput)) then
  begin
    raise EArgumentException.Create('Use separate input and output ledgers');
  end;
  LCache := IncludeTrailingPathDelimiter(ExpandFileName(ACache));
  if not ForceDirectories(LCache) then
  begin
    raise EInOutError.Create('Could not create the attachment cache');
  end;
  LClient := nil;
  LAttachments := TStringList.Create;
  try
    LoadAttachments(AInventory, LAttachments);
    if AMode = 'collect' then
    begin
      LClient := TEuropePmc.Create(Host);
    end;
    WriteInventory(LAttachments, LClient, LCache, AOutput);
  finally
    LClient.Free;
    LAttachments.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if (ParamCount <> 4) or ((ParamStr(1) <> 'collect') and (ParamStr(1) <> 'replay')) then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.mdsassets <collect|replay> BODY_INVENTORY CACHE OUTPUT_TSV');
    end;
    Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
