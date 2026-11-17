{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentIdReplay;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, foodexperiment.externaldata, foodexperiment.https;

const
  SearchPath = '/europepmc/webservices/rest/search?format=json&resultType=idlist&pageSize=100';

function ReadExpression(const AQueryAudit, AQueryId: String): UTF8String;
var
  LRows: TStringList;
  LLine: String;
  LFields: TFields;
begin
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(AQueryAudit);
    for LLine in LRows do
    begin
      LFields := SplitFields(LLine, #9);
      if (Length(LFields) = 10) and (LFields[0] = AQueryId) then
      begin
        Exit(LFields[4]);
      end;
    end;
  finally
    LRows.Free;
  end;
  raise EConvertError.Create('Query missing from audit: ' + AQueryId);
end;

procedure FetchPage(AClient: TEuropePmc; const AQuery, ACursor: UTF8String; APage: TStrings);
var
  LResponse: TSearchResponse;
  LDocument: TJSONObject;
  LResults: TJSONArray;
  LItem: TJSONObject;
  LSource: String;
  LId: String;
  I: Integer;
begin
  LResponse := AClient.GetPath(SearchPath + '&query=' + UrlEncode(AQuery) +
    '&cursorMark=' + UrlEncode(ACursor));
  if LResponse.Status <> 200 then
  begin
    raise EInOutError.CreateFmt('Europe PMC HTTP %d', [LResponse.Status]);
  end;
  LDocument := GetJSON(LResponse.Body, True) as TJSONObject;
  try
    LResults := LDocument.Objects['resultList'].Arrays['result'];
    APage.Clear;
    APage.Add(ACursor);
    APage.Add(LDocument.Get('nextCursorMark', ''));
    APage.Add(IntToStr(LDocument.Integers['hitCount']));
    APage.Add(IntToStr(LResults.Count));
    for I := 0 to LResults.Count - 1 do
    begin
      LItem := LResults.Objects[I];
      LSource := LItem.Strings['source'];
      LId := LItem.Strings['id'];
      if (LSource = '') or (LId = '') then
      begin
        raise EConvertError.Create('Empty identifier in Europe PMC response');
      end;
      APage.Add(LSource + ':' + LId);
    end;
  finally
    LDocument.Free;
  end;
end;

procedure Replay(const AQuery, AOutput: String);
var
  LClient: TEuropePmc;
  LPage: TStringList;
  LIds: TStringList;
  LCursors: TStringList;
  LLock: TFileStream;
  LCursor: UTF8String;
  LNext: UTF8String;
  LFile: String;
  LPageNumber: Integer;
  LTotal: Integer;
  LCount: Integer;
  LReadFromProvider: Boolean;
  I: Integer;
begin
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create replay directory');
  end;
  LPage := TStringList.Create;
  LIds := TStringList.Create;
  LCursors := TStringList.Create;
  LClient := nil;
  LLock := nil;
  try
    LLock := TFileStream.Create(AOutput + 'replay.lock', fmCreate or fmShareExclusive);
    LFile := AOutput + 'query.txt';
    if FileExists(LFile) then
    begin
      LPage.LoadFromFile(LFile);
      if (LPage.Count <> 2) or (LPage[0] <> SearchPath) or (LPage[1] <> AQuery) then
      begin
        raise EConvertError.Create('Identifier replay directory belongs to a different query');
      end;
    end
    else
    begin
      LPage.Add(SearchPath);
      LPage.Add(AQuery);
      LPage.SaveToFile(LFile);
    end;
    LIds.Sorted := True;
    LIds.Duplicates := dupError;
    LCursor := '*';
    LPageNumber := 0;
    LTotal := -1;
    repeat
      Inc(LPageNumber);
      LCursors.Add(LCursor);
      LFile := AOutput + Format('page-%.5d.txt', [LPageNumber]);
      LReadFromProvider := not FileExists(LFile);
      if LReadFromProvider then
      begin
        if LClient = nil then
        begin
          LClient := TEuropePmc.Create;
        end;
        FetchPage(LClient, AQuery, LCursor, LPage);
      end
      else
      begin
        LPage.LoadFromFile(LFile);
      end;
      if (LPage.Count < 4) or (LPage[0] <> LCursor) or
        (StrToInt(LPage[3]) <> LPage.Count - 4) then
      begin
        raise EConvertError.Create('Inconsistent identifier page: ' + LFile);
      end;
      LCount := StrToInt(LPage[2]);
      if LPageNumber = 1 then
      begin
        LTotal := LCount;
      end;
      if (LTotal < 0) or (LTotal <> LCount) then
      begin
        raise EConvertError.Create('Provider hit count changed within identifier replay');
      end;
      for I := 4 to LPage.Count - 1 do
      begin
        LIds.Add(LPage[I]);
      end;
      if LIds.Count > LTotal then
      begin
        raise EConvertError.Create('More unique identifiers than reported hits');
      end;
      if LReadFromProvider then
      begin
        LPage.SaveToFile(LFile + '.tmp');
        if not RenameFile(LFile + '.tmp', LFile) then
        begin
          raise EInOutError.Create('Cannot publish identifier page ' + LFile);
        end;
        WriteLn('Page ', LPageNumber, ': ', LIds.Count, '/', LTotal, ' unique identifiers');
      end;
      LNext := LPage[1];
      if (LIds.Count = LTotal) or (LPage.Count = 4) or (LNext = '') or
        (LCursors.IndexOf(LNext) >= 0) then
      begin
        Break;
      end;
      LCursor := LNext;
    until False;
    LIds.SaveToFile(AOutput + 'source-ids.txt');
    WriteLn('Finished at ', LIds.Count, '/', LTotal, ' after ', LPageNumber, ' pages');
    if LIds.Count <> LTotal then
    begin
      ExitCode := 2;
    end;
  finally
    LLock.Free;
    LClient.Free;
    LCursors.Free;
    LIds.Free;
    LPage.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if ParamCount <> 3 then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.idreplay <query-audit.tsv> <query-id> <output-directory>');
    end;
    Replay(ReadExpression(ParamStr(1), ParamStr(2)),
      IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3))));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
