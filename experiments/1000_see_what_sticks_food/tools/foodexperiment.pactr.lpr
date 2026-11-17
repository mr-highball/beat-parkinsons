{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPactr;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, RegExpr, foodexperiment.externaldata, foodexperiment.https,
  foodexperiment.matching;

const
  RegistryHost = 'pactr.samrc.ac.za';
  SearchPath = '/Search_v2.aspx';
  SearchControl = 'ctl00$MainContent$ctrlSearch$';
  TrialPath = '/TrialDisplay.aspx?TrialID=';

procedure AddField(var AForm: UTF8String; const AName, AValue: UTF8String);
begin
  if AForm <> '' then
  begin
    AForm := AForm + '&';
  end;
  AForm := AForm + UrlEncode(AName) + '=' + UrlEncode(AValue);
end;

function FormData(const AHtml, ATarget, AQuery: UTF8String): UTF8String;
var
  LPattern: TRegExpr;
  LName: String;
  LValue: String;
  LHasViewState: Boolean;
  LHasValidation: Boolean;
begin
  Result := '';
  LHasViewState := False;
  LHasValidation := False;
  LPattern := TRegExpr.Create('<input\s+type="hidden"\s+name="([^"]+)"' +
    '[^>]*?\svalue="([^"]*)"');
  try
    if LPattern.Exec(AHtml) then
    begin
      repeat
        LName := LPattern.Match[1];
        LValue := LPattern.Match[2];
        if (LName <> '__EVENTTARGET') and (LName <> '__EVENTARGUMENT') then
        begin
          { The ASP.NET state fields are base64. The other hidden values are scalars. }
          if Pos('&', LValue) <> 0 then
          begin
            raise EConvertError.CreateFmt('Unexpected entity in PACTR form field %s', [LName]);
          end;
          AddField(Result, UTF8String(LName), UTF8String(LValue));
          LHasViewState := LHasViewState or (LName = '__VIEWSTATE');
          LHasValidation := LHasValidation or (LName = '__EVENTVALIDATION');
        end;
      until not LPattern.ExecNext;
    end;
  finally
    LPattern.Free;
  end;
  if not (LHasViewState and LHasValidation) then
  begin
    raise EConvertError.Create('PACTR form state is missing');
  end;
  AddField(Result, '__EVENTTARGET', ATarget);
  AddField(Result, '__EVENTARGUMENT', '');
  AddField(Result, SearchControl + 'txtSearchTerms', AQuery);
  AddField(Result, SearchControl + 'txtBasicSearch', AQuery);
end;

function CheckBody(const AResponse: TSearchResponse): UTF8String;
begin
  if AResponse.Status <> 200 then
  begin
    raise EInOutError.CreateFmt('PACTR returned HTTP %d', [AResponse.Status]);
  end;
  Result := AResponse.Body;
end;

function Capture(const AHtml, AExpression: UTF8String): UTF8String;
var
  LPattern: TRegExpr;
begin
  Result := '';
  LPattern := TRegExpr.Create(AExpression);
  try
    if LPattern.Exec(AHtml) then
    begin
      Result := UTF8String(LPattern.Match[1]);
    end;
  finally
    LPattern.Free;
  end;
end;

procedure ReadLinks(const AHtml: UTF8String; AIds: TStringList);
var
  LPattern: TRegExpr;
begin
  LPattern := TRegExpr.Create('href=''TrialDisplay\.aspx\?TrialID=([0-9]+)''');
  try
    if LPattern.Exec(AHtml) then
    begin
      repeat
        AIds.Add(LPattern.Match[1]);
      until not LPattern.ExecNext;
    end;
  finally
    LPattern.Free;
  end;
end;

function Search(AClient: TEuropePmc; const AQuery: UTF8String; AIds: TStringList): Integer;
var
  LHtml: UTF8String;
  LTarget: UTF8String;
  LTotal: Integer;
  LExpected: Integer;
  LPreviousCount: Integer;
begin
  LHtml := CheckBody(AClient.GetPath(SearchPath));
  LTarget := SearchControl + 'lbBasicSearch';
  LExpected := -1;
  Result := 0;
  repeat
    LHtml := CheckBody(AClient.PostForm(SearchPath, FormData(LHtml, LTarget, AQuery)));
    LPreviousCount := AIds.Count;
    ReadLinks(LHtml, AIds);
    Inc(Result);
    if not TryStrToInt(Capture(LHtml, 'id="lblTotalRecord"\s*>\s*([0-9]+)'), LTotal) then
    begin
      if (Result = 1) and (AIds.Count = 0) and
        (Capture(LHtml, '>\s*(No results found)\s*<') <> '') then
      begin
        Exit;
      end;
      raise EConvertError.CreateFmt('PACTR did not report a result count on page %d',
        [Result]);
    end;
    if LExpected = -1 then
    begin
      LExpected := LTotal;
    end;
    if LExpected <> LTotal then
    begin
      raise EConvertError.CreateFmt('PACTR result count changed from %d to %d on page %d',
        [LExpected, LTotal, Result]);
    end;
    if AIds.Count = LTotal then
    begin
      Exit;
    end;
    if (AIds.Count = LPreviousCount) or (AIds.Count > LTotal) then
    begin
      raise EConvertError.CreateFmt('PACTR could not reconcile %d of %d trial links',
        [AIds.Count, LTotal]);
    end;
    LTarget := Capture(LHtml, '__doPostBack\(&#39;([^&]+\$lbPageNumber)&#39;,' +
      '&#39;&#39;\)">' + IntToStr(Result + 1) + '</a>');
    if LTarget = '' then
    begin
      LTarget := Capture(LHtml, '__doPostBack\(&#39;([^&]+\$lbNextPage2)&#39;,');
    end;
    if LTarget = '' then
    begin
      raise EConvertError.CreateFmt('PACTR has %d of %d records and no next page',
        [AIds.Count, LTotal]);
    end;
  until False;
end;

procedure WriteLine(AStream: TStream; const AValue: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := AValue + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

procedure Run(const APlan, AOutput: String);
var
  LClient: TEuropePmc;
  LPlan: RawByteString;
  LIds: TStringList;
  LOutput: TMemoryStream;
  LTerm: UTF8String;
  LQuery: UTF8String;
  LId: String;
  LPageCount: Integer;
  LRow: UTF8String;
begin
  LIds := nil;
  LOutput := nil;
  LClient := TEuropePmc.Create(RegistryHost, 45000);
  try
    LIds := TStringList.Create;
    LOutput := TMemoryStream.Create;
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    WriteLine(LOutput, 'term'#9'pages'#9'reported_and_retrieved'#9'registry_path');
    LPlan := ReadBytes(APlan);
    SetCodePage(LPlan, CP_UTF8, False);
    if Copy(LPlan, 1, 3) = #$EF#$BB#$BF then
    begin
      Delete(LPlan, 1, 3);
    end;
    for LTerm in SplitFields(LPlan, #10) do
    begin
      LQuery := LTerm;
      if (LQuery <> '') and (LQuery[Length(LQuery)] = #13) then
      begin
        SetLength(LQuery, Length(LQuery) - 1);
      end;
      if Trim(LQuery) = '' then
      begin
        Continue;
      end;
      if Pos(#9, LQuery) <> 0 then
      begin
        raise EConvertError.Create('Enter one PACTR term per plan line');
      end;
      LIds.Clear;
      LPageCount := Search(LClient, LQuery, LIds);
      LRow := LQuery + #9 + IntToStr(LPageCount) + #9 + IntToStr(LIds.Count) + #9;
      if LIds.Count = 0 then
      begin
        WriteLine(LOutput, LRow);
      end;
      for LId in LIds do
      begin
        WriteLine(LOutput, LRow + TrialPath + LId);
      end;
    end;
    LOutput.SaveToFile(AOutput);
  finally
    LOutput.Free;
    LIds.Free;
    LClient.Free;
  end;
end;

begin
  try
    if ParamCount <> 2 then
    begin
      raise EArgumentException.Create('Usage: foodexperiment.pactr PLAN_FILE OUTPUT_TSV');
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
