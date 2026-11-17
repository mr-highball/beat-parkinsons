{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.tctr;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.externaldata, foodexperiment.https;

const
  RegistryHost = 'www.thaiclinicaltrials.org';
  ExportPath = '/export/xml/';
  ExportFields: array[0..10] of UTF8String = (
    'public_title', 'hc_freetext', 'date_enrolment', 'target_size',
    'recruitment_status', 'i_freetext', 'prim_outcome', 'sec_outcome',
    'results_summary', 'results_date_posted', 'results_url_link'
  );

function IsTrialId(const AId: UTF8String): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (Length(AId) <> 15) or (Copy(AId, 1, 4) <> 'TCTR') then
  begin
    Exit;
  end;
  for LIndex := 5 to Length(AId) do
  begin
    if not (AId[LIndex] in ['0'..'9']) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function ExportField(const ABody, AName: UTF8String): UTF8String;
var
  LTag: UTF8String;
  LStart: Integer;
  LEnd: Integer;
begin
  Result := '';
  LTag := '<' + AName + '>';
  LStart := Pos(LTag, ABody);
  if LStart = 0 then
  begin
    Exit;
  end;
  Inc(LStart, Length(LTag));
  LTag := '</' + AName + '>';
  LEnd := Pos(LTag, ABody, LStart);
  if LEnd = 0 then
  begin
    raise Exception.Create('Unclosed export field ' + String(AName));
  end;
  { Older exports double-encode text and may contain HTML entities in XML. }
  Result := CleanField(CleanField(Copy(ABody, LStart, LEnd - LStart)));
end;

function RegistrationDate(const ABody, AId: UTF8String): UTF8String;
var
  LDate: UTF8String;
  LStamp: TDateTime;
  LYear: Word;
  LMonth: Word;
  LDay: Word;
begin
  LDate := ExportField(ABody, 'date_registration');
  LYear := StrToInt(Copy(AId, 5, 4));
  LMonth := StrToInt(Copy(AId, 9, 2));
  LDay := StrToInt(Copy(AId, 11, 2));
  if not TryEncodeDate(LYear, LMonth, LDay, LStamp) or
    (LDate <> FormatDateTime('dd"/"mm"/"yyyy', LStamp)) then
  begin
    raise Exception.Create('Export registration date disagrees with ID');
  end;
  Result := FormatDateTime('yyyy"-"mm"-"dd', LStamp);
end;

procedure SaveBytes(const APath: String; const ABytes: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if Length(ABytes) > 0 then
    begin
      LStream.WriteBuffer(ABytes[1], Length(ABytes));
    end;
  finally
    LStream.Free;
  end;
end;

procedure Run;
var
  LIds: TStringList;
  LOutput: TFileStream;
  LClient: TEuropePmc;
  LResponse: TSearchResponse;
  LPath: String;
  LField: UTF8String;
  LRow: UTF8String;
  LFields: UTF8String;
  LDate: UTF8String;
  LStatus: UTF8String;
  LId: UTF8String;
  LIndex: Integer;
  LSuccess: Integer;
begin
  if ParamCount < 2 then
  begin
    raise Exception.Create('Usage: foodexperiment.tctr OUTPUT_DIR TCTR_ID ...');
  end;
  LIds := TStringList.Create;
  try
    for LIndex := 2 to ParamCount do
    begin
      LId := ParamStr(LIndex);
      if not IsTrialId(LId) or (LIds.IndexOf(LId) >= 0) then
      begin
        raise Exception.Create('Invalid or duplicate TCTR ID: ' + String(LId));
      end;
      LIds.Add(LId);
    end;
    LPath := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
    if not ForceDirectories(LPath) then
    begin
      raise Exception.Create('Cannot create output directory ' + LPath);
    end;
    LClient := TEuropePmc.Create(RegistryHost);
    try
      LOutput := TFileStream.Create(LPath + 'trials.tsv', fmCreate);
      try
        LRow := 'checked_utc'#9'trial_id'#9'url'#9'http_status'#9'bytes'#9 +
          'access'#9'registration_date';
        for LField in ExportFields do
        begin
          LRow := LRow + #9 + LField;
        end;
        LRow := LRow + #10;
        LOutput.WriteBuffer(LRow[1], Length(LRow));
        LSuccess := 0;
        for LId in LIds do
        begin
          LResponse.Status := 0;
          LResponse.Body := '';
          LDate := '';
          LFields := '';
          try
            LResponse := LClient.GetPath(ExportPath + LId);
            if LResponse.Status <> 200 then
            begin
              raise Exception.Create('HTTP response without trial export');
            end;
            SaveBytes(LPath + LId + '.xml', LResponse.Body);
            if ExportField(LResponse.Body, 'trial_id') <> LId then
            begin
              raise Exception.Create('Export is missing requested trial ID');
            end;
            LDate := RegistrationDate(LResponse.Body, LId);
            for LField in ExportFields do
            begin
              LFields := LFields + #9 + ExportField(LResponse.Body, LField);
            end;
            LStatus := 'verified';
            Inc(LSuccess);
          except
            on LException: Exception do
            begin
              LStatus := CleanField(UTF8String(LException.Message));
              LFields := StringOfChar(#9, Length(ExportFields));
            end;
          end;
          LRow := UtcTimestamp + #9 + LId + #9 + 'https://' + RegistryHost +
            ExportPath + LId + #9 + IntToStr(LResponse.Status) + #9 +
            IntToStr(Length(LResponse.Body)) + #9 + LStatus + #9 +
            LDate + LFields + #10;
          LOutput.WriteBuffer(LRow[1], Length(LRow));
          WriteLn(LId, ' ', LStatus);
        end;
        WriteLn('Verified ', LSuccess, ' / ', LIds.Count, ' exact exports');
        if LSuccess <> LIds.Count then
        begin
          ExitCode := 1;
        end;
      finally
        LOutput.Free;
      end;
    finally
      LClient.Free;
    end;
  finally
    LIds.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
