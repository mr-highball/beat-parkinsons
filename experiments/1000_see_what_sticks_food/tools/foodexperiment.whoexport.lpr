{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentWhoExport;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, RegExpr, foodexperiment.externaldata, foodexperiment.https;

const
  RegistryHost = 'trialsearch.who.int';
  ExportRoot = '<Trials_downloaded_from_ICTRP';

function MatchField(const APattern, AText: UTF8String): UTF8String;
var
  LRegex: TRegExpr;
begin
  LRegex := TRegExpr.Create(APattern);
  try
    if LRegex.Exec(AText) then
    begin
      Result := LRegex.Match[1];
    end
    else
    begin
      Result := '';
    end;
  finally
    LRegex.Free;
  end;
end;

function FormField(const AName, AValue: UTF8String): UTF8String;
begin
  Result := UrlEncode(AName) + '=' + UrlEncode(AValue);
end;

function HiddenForm(const AHtml: UTF8String): UTF8String;
var
  LInputs: TRegExpr;
  LTag, LName, LValue: UTF8String;
begin
  Result := '';
  LInputs := TRegExpr.Create('<input\b[^>]*type="hidden"[^>]*>');
  try
    if LInputs.Exec(AHtml) then
    begin
      repeat
        LTag := LInputs.Match[0];
        LName := MatchField('\bname="([^"]+)"', LTag);
        if LName <> '' then
        begin
          if Result <> '' then
          begin
            Result := Result + '&';
          end;
          LValue := CleanField(MatchField('\bvalue="([^"]*)"', LTag));
          Result := Result + FormField(LName, LValue);
        end;
      until not LInputs.ExecNext;
    end;
    if (Pos('__VIEWSTATE=', Result) = 0) or (Pos('__EVENTVALIDATION=', Result) = 0) then
    begin
      raise EConvertError.Create('WHO public form state fields are missing');
    end;
  finally
    LInputs.Free;
  end;
end;

procedure CheckResponse(const AResponse: TSearchResponse; const AStep: String);
begin
  if AResponse.Status <> 200 then
  begin
    raise EInOutError.CreateFmt('WHO %s HTTP %d', [AStep, AResponse.Status]);
  end;
end;

procedure Run(const ATerm, AOutput: UTF8String);
var
  LClient: TEuropePmc;
  LPage, LResults, LXmlForm, LExport: TSearchResponse;
  LForm, LCountText: UTF8String;
  LPath, LTemporary: String;
  LFile: TFileStream;
  LBytes: Int64;
  LCount: Integer;
  LPrefix: RawByteString;
begin
  if Trim(ATerm) = '' then
  begin
    raise EArgumentException.Create('Expected a public WHO search expression');
  end;
  LPath := ExpandFileName(AOutput);
  if FileExists(LPath) then
  begin
    raise EInOutError.Create('Export path already exists: ' + LPath);
  end;
  if not DirectoryExists(ExtractFileDir(LPath)) then
  begin
    raise EInOutError.Create('Export directory does not exist: ' + ExtractFileDir(LPath));
  end;
  LClient := TEuropePmc.Create(RegistryHost, 120000);
  try
    LPage := LClient.GetPath('/');
    CheckResponse(LPage, 'search form');
    LForm := HiddenForm(LPage.Body) + '&' + FormField('TextBox1', ATerm) +
      '&' + FormField('Button1', 'Search');
    LResults := LClient.PostForm('/', LForm);
    CheckResponse(LResults, 'search');
    LCountText := MatchField('([0-9,]+)\s+trials found', LResults.Body);
    if not TryStrToInt(StringReplace(LCountText, ',', '', [rfReplaceAll]), LCount) then
    begin
      raise EConvertError.Create('WHO search response did not give a result count');
    end;
    WriteLn(StdErr, ATerm, ': WHO reported ', LCount, ' trials');
    if LCount = 0 then
    begin
      Exit;
    end;
    LXmlForm := LClient.PostForm('/', HiddenForm(LResults.Body) + '&' +
      FormField('Button8', 'Export results to XML'));
    CheckResponse(LXmlForm, 'XML selection');
    if Pos('name="Button14"', LXmlForm.Body) = 0 then
    begin
      raise EConvertError.Create('WHO response did not offer an all-trials XML export');
    end;
    LTemporary := GetTempFileName(ExtractFileDir(LPath), 'who');
    if LTemporary = '' then
    begin
      raise EInOutError.Create('Could not create temporary WHO export file');
    end;
    try
      LFile := TFileStream.Create(LTemporary, fmCreate);
      try
        LExport := LClient.PostForm('/', HiddenForm(LXmlForm.Body) + '&' +
          FormField('Button14', 'Export all trials to XML'), LFile);
        CheckResponse(LExport, 'XML export');
        LBytes := LFile.Size;
        if (Pos('xml', LowerCase(LExport.ContentType)) = 0) or (LBytes = 0) then
        begin
          raise EConvertError.Create('WHO response did not return an XML export');
        end;
        LFile.Position := 0;
        SetLength(LPrefix, 4096);
        SetLength(LPrefix, LFile.Read(LPrefix[1], Length(LPrefix)));
        if Pos(ExportRoot, LPrefix) = 0 then
        begin
          raise EConvertError.Create('WHO XML export root not found');
        end;
      finally
        LFile.Free;
      end;
      if not RenameFile(LTemporary, LPath) then
      begin
        raise EInOutError.Create('Could not save WHO export: ' + LPath);
      end;
      WriteLn(UtcTimestamp, #9, ATerm, #9, LCount, #9, LBytes);
    finally
      if FileExists(LTemporary) then
      begin
        DeleteFile(LTemporary);
      end;
    end;
  finally
    LClient.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if ParamCount <> 2 then
    begin
      raise EArgumentException.Create('Usage: foodexperiment.whoexport EXPRESSION OUTPUT_XML');
    end;
    Run(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
