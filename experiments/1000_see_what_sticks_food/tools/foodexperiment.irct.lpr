{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentIrct;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, RegExpr, foodexperiment.externaldata,
  foodexperiment.https, foodexperiment.matching;

type
  TRegistryRow = record
    Path: UTF8String;
    TrialId: UTF8String;
    Title: UTF8String;
    Summary: UTF8String;
  end;

  TRegistryRows = array of TRegistryRow;

  TSearchPage = record
    Total: Integer;
    FirstRank: Integer;
    LastRank: Integer;
    NextPath: UTF8String;
    Rows: TRegistryRows;
  end;

function AsUtf8(const AValue: RawByteString): UTF8String;
var
  LValue: RawByteString;
begin
  LValue := AValue;
  SetCodePage(LValue, CP_UTF8, False);
  Result := LValue;
end;

procedure WriteLine(AStream: TStream; const ALine: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := ALine + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

function ParsePage(const AHtml: UTF8String; APersian: Boolean): TSearchPage;
var
  LPattern: TRegExpr;
  LCount: Integer;
begin
  Result := Default(TSearchPage);
  LPattern := TRegExpr.Create;
  try
    if APersian then
    begin
      LPattern.Expression := 'نمایش\s*<strong>(\d+)</strong>\s*تا\s*' +
        '<strong>(\d+)</strong>\s*از\s*<strong>(\d+)</strong>';
    end
    else
    begin
      LPattern.Expression :=
        'Displaying\s*<strong>(\d+)-(\d+)</strong>\s*of\s*<strong>(\d+)</strong>';
    end;
    if not LPattern.Exec(AHtml) then
    begin
      raise EInOutError.Create('IRCT search count is missing');
    end;
    Result.FirstRank := StrToInt(LPattern.Match[1]);
    Result.LastRank := StrToInt(LPattern.Match[2]);
    Result.Total := StrToInt(LPattern.Match[3]);

    LPattern.Expression := '(?is)class="result-title">\s*<a href="(/trial/\d+)">' +
      '(.*?)</a></div>\s*<div class="result-summary">(.*?)</div>\s*' +
      '<div class="result-irct-id">IRCTID:\s*(.*?)</div>';
    if LPattern.Exec(AHtml) then
    begin
      repeat
        LCount := Length(Result.Rows);
        SetLength(Result.Rows, LCount + 1);
        Result.Rows[LCount].Path := UTF8String(LPattern.Match[1]);
        Result.Rows[LCount].Title := CleanField(AsUtf8(LPattern.Match[2]));
        Result.Rows[LCount].Summary := CleanField(AsUtf8(LPattern.Match[3]));
        Result.Rows[LCount].TrialId := CleanField(AsUtf8(LPattern.Match[4]));
      until not LPattern.ExecNext;
    end;

    LPattern.Expression := 'href="(/search/result\?[^"]+)"\s+rel="next"';
    if LPattern.Exec(AHtml) then
    begin
      Result.NextPath := UTF8String(StringReplace(LPattern.Match[1], '&amp;', '&',
        [rfReplaceAll]));
    end;
  finally
    LPattern.Free;
  end;
end;

procedure SaveBytes(const APath: String; const ABody: UTF8String);
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath + '.tmp', fmCreate);
  try
    if ABody <> '' then
    begin
      LFile.WriteBuffer(ABody[1], Length(ABody));
    end;
  finally
    LFile.Free;
  end;
  if not RenameFile(APath + '.tmp', APath) then
  begin
    raise EInOutError.CreateFmt('Cannot publish %s', [APath]);
  end;
end;

function GetPage(AClient: TEuropePmc; const APath: UTF8String): UTF8String;
var
  LResponse: TSearchResponse;
begin
  LResponse := AClient.GetPath(APath);
  if LResponse.Status <> 200 then
  begin
    raise EInOutError.CreateFmt('HTTP %d for %s', [LResponse.Status, APath]);
  end;
  Result := LResponse.Body;
end;

procedure Search(AClient: TEuropePmc; const AHost, AOutput: String;
  const AQuery: UTF8String);
var
  LPath: UTF8String;
  LBody: UTF8String;
  LConfig: UTF8String;
  LCache: String;
  LPage: TSearchPage;
  LPageNumber: Integer;
  LRead: Integer;
  LTotal: Integer;
  LRow: TRegistryRow;
  LTrials: TStringList;
  LLedger: TMemoryStream;
  LLine: UTF8String;
begin
  LConfig := UTF8String(AHost) + #9 + AQuery + #10;
  LCache := AOutput + 'query.txt';
  if not FileExists(LCache) then
  begin
    SaveBytes(LCache, LConfig);
  end;
  if AsUtf8(ReadBytes(LCache)) <> LConfig then
  begin
    raise EInOutError.Create('Saved IRCT query identity does not match this run');
  end;

  LPath := '/search/result?query=' + UrlEncode(AQuery);
  LPageNumber := 0;
  LRead := 0;
  LTotal := -1;
  LTrials := TStringList.Create;
  LLedger := TMemoryStream.Create;
  try
    LTrials.Sorted := True;
    WriteLine(LLedger, 'rank'#9'trial_id'#9'url'#9'title'#9'index_summary');
    repeat
      Inc(LPageNumber);
      LCache := AOutput + Format('search-%.3d.html', [LPageNumber]);
      if FileExists(LCache) then
      begin
        LBody := AsUtf8(ReadBytes(LCache));
      end
      else
      begin
        LBody := GetPage(AClient, LPath);
      end;
      LPage := ParsePage(LBody, AHost = 'fa.irct.ir');
      if LTotal < 0 then
      begin
        LTotal := LPage.Total;
      end;
      if (LPage.Total <> LTotal) or ((LTotal > 0) and
        ((LPage.FirstRank <> LRead + 1) or
        (LPage.LastRank <> LRead + Length(LPage.Rows)) or
        (Length(LPage.Rows) = 0))) then
      begin
        raise EInOutError.CreateFmt('IRCT result range changed on page %d', [LPageNumber]);
      end;
      for LRow in LPage.Rows do
      begin
        if (LTrials.IndexOf(String(LRow.Path)) >= 0) or (LRow.TrialId = '') then
        begin
          raise EInOutError.CreateFmt('Duplicate or unidentified IRCT row %s', [LRow.Path]);
        end;
        LTrials.Add(String(LRow.Path));
        Inc(LRead);
        LLine := UTF8String(IntToStr(LRead)) + #9 + LRow.TrialId + #9 +
          'https://' + UTF8String(AHost) + LRow.Path + #9 + LRow.Title + #9 + LRow.Summary;
        WriteLine(LLedger, LLine);
      end;
      if not FileExists(LCache) then
      begin
        SaveBytes(LCache, LBody);
      end;
      LPath := LPage.NextPath;
    until LPath = '';
    if LRead <> LTotal then
    begin
      raise EInOutError.CreateFmt('IRCT reported %d rows and supplied %d', [LTotal, LRead]);
    end;
    LCache := AOutput + 'trials.tsv';
    SetLength(LLine, LLedger.Size);
    Move(LLedger.Memory^, LLine[1], Length(LLine));
    if not FileExists(LCache) then
    begin
      SaveBytes(LCache, LLine);
    end
    else if AsUtf8(ReadBytes(LCache)) <> LLine then
    begin
      raise EInOutError.Create('IRCT ledger differs from saved result pages');
    end;
    WriteLn(LRead, ' IRCT records across ', LPageNumber, ' pages');
  finally
    LLedger.Free;
    LTrials.Free;
  end;
end;

procedure FetchTrials(AClient: TEuropePmc; const AOutput: String);
var
  LIndex: Integer;
  LId: String;
  LCache: String;
  LBody: UTF8String;
begin
  for LIndex := 4 to ParamCount do
  begin
    LId := ParamStr(LIndex);
    if not ExecRegExpr('^\d+$', LId) then
    begin
      raise EArgumentException.CreateFmt('Invalid IRCT trial page number %s', [LId]);
    end;
    LCache := AOutput + LId + '.html';
    if not FileExists(LCache) then
    begin
      LBody := GetPage(AClient, '/trial/' + UTF8String(LId));
      if not ExecRegExpr('(?i)<strong>IRCT\d{10,}(N\d+)?</strong>', LBody) then
      begin
        raise EInOutError.CreateFmt('IRCT trial %s has no registry ID', [LId]);
      end;
      SaveBytes(LCache, LBody);
    end;
  end;
end;

procedure Run;
var
  LAction: String;
  LHost: String;
  LOutput: String;
  LQuery: UTF8String;
  LClient: TEuropePmc;
begin
  LAction := ParamStr(1);
  LHost := ParamStr(2);
  if ((LAction <> 'search') and (LAction <> 'detail')) or
    ((LHost <> 'irct.ir') and (LHost <> 'fa.irct.ir')) or (ParamCount < 4) then
  begin
    raise EArgumentException.Create(
      'Usage: foodexperiment.irct search|detail irct.ir|fa.irct.ir OUTPUT ' +
      'QUERY|--query-file UTF8_FILE|PAGE-ID...');
  end;
  LOutput := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3)));
  if not ForceDirectories(LOutput) and not DirectoryExists(LOutput) then
  begin
    raise EInOutError.CreateFmt('Cannot create %s', [LOutput]);
  end;
  LClient := TEuropePmc.Create(UnicodeString(LHost));
  try
    if LAction = 'search' then
    begin
      if (ParamCount = 5) and (ParamStr(4) = '--query-file') then
      begin
        LQuery := Trim(AsUtf8(ReadBytes(ParamStr(5))));
      end
      else if ParamCount = 4 then
      begin
        LQuery := UTF8Encode(UnicodeString(ParamStr(4)));
      end
      else
      begin
        raise EArgumentException.Create('Provide one IRCT query or a UTF-8 query file');
      end;
      if LQuery = '' then
      begin
        raise EArgumentException.Create('IRCT query is empty');
      end;
      Search(LClient, LHost, LOutput, LQuery);
    end
    else
    begin
      FetchTrials(LClient, LOutput);
    end;
  finally
    LClient.Free;
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
