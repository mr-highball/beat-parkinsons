{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentEudract;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, RegExpr, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

const
  RegistryHost = 'www.clinicaltrialsregister.eu';
  ResultTable = '<table class="result">';

function AsUtf8(const ABytes: RawByteString): UTF8String;
var
  LBytes: RawByteString;
begin
  LBytes := ABytes;
  SetCodePage(LBytes, CP_UTF8, False);
  Result := LBytes;
end;

function IndexField(const ABlock, ALabel: UTF8String): UTF8String;
var
  LStart: Integer;
  LEnd: Integer;
begin
  Result := '';
  LStart := Pos(RawByteString(ALabel), RawByteString(ABlock));
  if LStart = 0 then
  begin
    Exit;
  end;
  Inc(LStart, Length(ALabel));
  LEnd := Pos(RawByteString('</td>'), RawByteString(ABlock), LStart);
  if LEnd > 0 then
  begin
    Result := CleanField(Copy(ABlock, LStart, LEnd - LStart));
  end;
end;

function Capture(const APattern, AText: UTF8String): UTF8String;
var
  LRegex: TRegExpr;
begin
  Result := '';
  LRegex := TRegExpr.Create(APattern);
  try
    if LRegex.Exec(AText) then
    begin
      Result := AsUtf8(LRegex.Match[1]);
    end;
  finally
    LRegex.Free;
  end;
end;

procedure SaveOrVerify(const APath: String; const AValue: UTF8String);
var
  LStream: TFileStream;
begin
  if FileExists(APath) then
  begin
    if AsUtf8(ReadBytes(APath)) <> AValue then
    begin
      raise EInOutError.CreateFmt('Saved content differs from this run: %s', [APath]);
    end;
    Exit;
  end;
  LStream := TFileStream.Create(APath + '.tmp', fmCreate);
  try
    if AValue <> '' then
    begin
      LStream.WriteBuffer(AValue[1], Length(AValue));
    end;
  finally
    LStream.Free;
  end;
  if not RenameFile(APath + '.tmp', APath) then
  begin
    raise EInOutError.CreateFmt('Cannot publish %s', [APath]);
  end;
end;

procedure WriteLine(AStream: TStream; const ALine: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := ALine + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

procedure ParsePage(const ABody: UTF8String; ASeen: TStringList;
  ALedger: TStream; var ATotal: Integer);
var
  LCount: Integer;
  LStart: Integer;
  LNext: Integer;
  LBlock: UTF8String;
  LId: UTF8String;
  LTitle: UTF8String;
  LCondition: UTF8String;
  LProtocolUrl: UTF8String;
  LResultsUrl: UTF8String;
  LRank: Integer;
  LCountText: UTF8String;
begin
  LCountText := Capture('(\d+)\s+result\(s\) found for:', ABody);
  if not TryStrToInt(LCountText, LCount) or (LCount < 0) then
  begin
    raise EInOutError.Create('Registry result count is unavailable');
  end;
  if ATotal < 0 then
  begin
    ATotal := LCount;
  end;
  if ATotal <> LCount then
  begin
    raise EInOutError.CreateFmt('Registry changed its count from %d to %d', [ATotal, LCount]);
  end;
  LRank := ASeen.Count;
  LStart := Pos(RawByteString(ResultTable), RawByteString(ABody));
  while LStart > 0 do
  begin
    LNext := Pos(RawByteString(ResultTable), RawByteString(ABody),
      LStart + Length(ResultTable));
    if LNext > 0 then
    begin
      LBlock := Copy(ABody, LStart, LNext - LStart);
    end
    else
    begin
      LBlock := Copy(ABody, LStart, Length(ABody) - LStart + 1);
    end;
    LId := Capture('EudraCT Number:</span>\s*(\d{4}-\d{6}-\d{2})', LBlock);
    LTitle := IndexField(LBlock, 'Full Title:</span>');
    LCondition := IndexField(LBlock, 'Medical condition:</span>');
    if (LId = '') or (ASeen.IndexOf(String(LId)) >= 0) then
    begin
      raise EInOutError.CreateFmt('Registry ID "%s" is missing or repeated at rank %d',
        [LId, LRank + 1]);
    end;
    ASeen.Add(String(LId));
    Inc(LRank);
    LResultsUrl := Capture('href="(/ctr-search/trial/' + LId + '/results)"', LBlock);
    if LResultsUrl <> '' then
    begin
      LResultsUrl := 'https://' + RegistryHost + LResultsUrl;
    end;
    LProtocolUrl := Capture('href="(/ctr-search/trial/' + LId + '/[A-Z]{2})"', LBlock);
    if LProtocolUrl <> '' then
    begin
      LProtocolUrl := 'https://' + RegistryHost + LProtocolUrl;
    end;
    WriteLine(ALedger, UTF8String(IntToStr(LRank)) + #9 + LId + #9 +
      LTitle + #9 + LCondition + #9 + LProtocolUrl + #9 + LResultsUrl);
    LStart := LNext;
  end;
  if ASeen.Count > ATotal then
  begin
    raise EInOutError.Create('Registry supplied more records than reported');
  end;
end;

procedure Run;
var
  LQuery: UTF8String;
  LOutput: String;
  LCache: String;
  LBody: UTF8String;
  LPath: UTF8String;
  LResponse: TSearchResponse;
  LPage: Integer;
  LTotal: Integer;
  LPrevious: Integer;
  LSeen: TStringList;
  LLedger: TMemoryStream;
  LClient: TEuropePmc;
begin
  if (ParamCount <> 2) or (Trim(ParamStr(1)) = '') or (Trim(ParamStr(2)) = '') then
  begin
    raise EArgumentException.Create('Usage: foodexperiment.eudract OUTPUT SEARCH_EXPRESSION');
  end;
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  if not ForceDirectories(LOutput) and not DirectoryExists(LOutput) then
  begin
    raise EInOutError.CreateFmt('Cannot create %s', [LOutput]);
  end;
  LQuery := UTF8Encode(UnicodeString(ParamStr(2)));
  SaveOrVerify(LOutput + 'query.txt', LQuery + #10);
  LSeen := TStringList.Create;
  LLedger := nil;
  LClient := nil;
  try
    LLedger := TMemoryStream.Create;
    LClient := TEuropePmc.Create(RegistryHost);
    LSeen.Sorted := True;
    LTotal := -1;
    LPage := 0;
    WriteLine(LLedger, 'rank'#9'eudract_id'#9'index_title'#9'medical_condition'#9 +
      'first_protocol_url'#9'results_url');
    repeat
      Inc(LPage);
      LPrevious := LSeen.Count;
      LCache := LOutput + Format('search-%.3d.html', [LPage]);
      if FileExists(LCache) then
      begin
        LBody := AsUtf8(ReadBytes(LCache));
      end
      else
      begin
        LPath := '/ctr-search/search?query=' + UrlEncode(LQuery) +
          '&page=' + UTF8String(IntToStr(LPage));
        LResponse := LClient.GetPath(LPath);
        if LResponse.Status <> 200 then
        begin
          raise EInOutError.CreateFmt('HTTP %d on registry page %d', [LResponse.Status, LPage]);
        end;
        LBody := LResponse.Body;
      end;
      ParsePage(LBody, LSeen, LLedger, LTotal);
      if (LSeen.Count = LPrevious) and (LSeen.Count < LTotal) then
      begin
        raise EInOutError.CreateFmt('Registry page %d has no new rows', [LPage]);
      end;
      SaveOrVerify(LCache, LBody);
    until LSeen.Count = LTotal;
    SetLength(LBody, LLedger.Size);
    Move(LLedger.Memory^, LBody[1], Length(LBody));
    SaveOrVerify(LOutput + 'trials.tsv', LBody);
    WriteLn(LTotal, ' EudraCT records across ', LPage, ' pages');
  finally
    LClient.Free;
    LLedger.Free;
    LSeen.Free;
  end;
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
