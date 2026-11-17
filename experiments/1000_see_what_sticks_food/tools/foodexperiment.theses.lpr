{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentTheses;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, StreamEx, ZStream, fpjson, jsonparser, foodexperiment.externaldata;

const
  Tab = #9;
  ProgressInterval = 100000;
  IndexHeader = 'docid'#9'nnt'#9'language'#9'title'#9'indexed_abstract';
  ResultsHeader = 'docid'#9'nnt'#9'language'#9'title'#9'defense_date'#9'discipline'#9 +
    'accessible'#9'has_abstract'#9'title_match'#9'abstract_match'#9'subject_match'#9'landing_page';

function CollectStrings(AData: TJSONData; const ASeparator: UTF8String): UTF8String;
var
  LValue: UTF8String;
  I: Integer;
begin
  Result := '';
  if not Assigned(AData) then
  begin
    Exit;
  end;
  case AData.JSONType of
    jtString:
      Result := CleanField(AData.AsString);
    jtArray, jtObject:
      for I := 0 to AData.Count - 1 do
      begin
        LValue := CollectStrings(AData.Items[I], ASeparator);
        if LValue = '' then
        begin
          Continue;
        end;
        if Result <> '' then
        begin
          Result := Result + ASeparator;
        end;
        Result := Result + LValue;
      end;
  else
    Exit;
  end;
end;

function HasCondition(const AText: UTF8String): Boolean;
var
  LText: UTF8String;
begin
  LText := LowerCase(AText);
  Result := (Pos('parkinson', LText) > 0) or
    (Pos('paralysie agitante', LText) > 0) or (Pos('shaking palsy', LText) > 0);
end;

procedure ProcessRecord(ARecord: TJSONData; ARecordNumber: Integer; ASeen: TStrings;
  var AIndex, AResults: Text);
var
  LTitle: UTF8String;
  LAbstract: UTF8String;
  LSubjects: UTF8String;
  LId: UTF8String;
  LLanguage: UTF8String;
  LTitleMatch: Boolean;
  LAbstractMatch: Boolean;
  LSubjectMatch: Boolean;
begin
  if not (ARecord is TJSONObject) then
  begin
    raise EConvertError.CreateFmt('Expected a thesis object on row %d', [ARecordNumber]);
  end;
  LTitle := CollectStrings(ARecord.FindPath('titres'), ' | ');
  LAbstract := CollectStrings(ARecord.FindPath('resumes'), ' | ');
  LSubjects := CollectStrings(ARecord.FindPath('sujets'), ' | ') + ' | ' +
    CollectStrings(ARecord.FindPath('sujets_rameau'), ' | ');
  LTitleMatch := HasCondition(LTitle);
  LAbstractMatch := HasCondition(LAbstract);
  LSubjectMatch := HasCondition(LSubjects);
  if not (LTitleMatch or LAbstractMatch or LSubjectMatch) then
  begin
    Exit;
  end;
  LId := CollectStrings(ARecord.FindPath('nnt'), '');
  if (LId = '') or (LTitle = '') then
  begin
    raise EConvertError.CreateFmt('Matched thesis lacks NNT or title on row %d', [ARecordNumber]);
  end;
  ASeen.Add(LId);
  LLanguage := CollectStrings(ARecord.FindPath('langues'), '|');
  Write(AIndex, ARecordNumber, Tab, LId, Tab, LLanguage, Tab, LTitle, Tab, LAbstract, #10);
  Write(AResults, ARecordNumber, Tab, LId, Tab, LLanguage, Tab, LTitle, Tab,
    CollectStrings(ARecord.FindPath('date_soutenance'), ''), Tab,
    CollectStrings(ARecord.FindPath('discipline'), ''), Tab,
    CollectStrings(ARecord.FindPath('accessible'), ''), Tab,
    BoolToStr(LAbstract <> '', True), Tab, BoolToStr(LTitleMatch, True), Tab,
    BoolToStr(LAbstractMatch, True), Tab, BoolToStr(LSubjectMatch, True), Tab,
    'https://theses.fr/', LId, #10);
end;

procedure Scan(AReader: TStreamReader; const AOutput: String);
var
  LIndex: Text;
  LResults: Text;
  LSeen: TStringList;
  LRecord: TJSONData;
  LCount: Integer;
begin
  LSeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    AssignFile(LIndex, AOutput + 'abstracts.tsv');
    Rewrite(LIndex);
    try
      AssignFile(LResults, AOutput + 'results.tsv');
      Rewrite(LResults);
      try
        SetTextCodePage(LIndex, CP_UTF8);
        SetTextCodePage(LResults, CP_UTF8);
        Write(LIndex, IndexHeader, #10);
        Write(LResults, ResultsHeader, #10);
        LCount := 0;
        while not AReader.EndOfStream do
        begin
          Inc(LCount);
          LRecord := GetJSON(AReader.ReadLine);
          try
            ProcessRecord(LRecord, LCount, LSeen, LIndex, LResults);
          finally
            LRecord.Free;
          end;
          if (LCount mod ProgressInterval) = 0 then
          begin
            WriteLn(LCount, ' thesis records read');
          end;
        end;
      finally
        CloseFile(LResults);
      end;
    finally
      CloseFile(LIndex);
    end;
    WriteLn(LCount, ' thesis records read, ', LSeen.Count, ' retained');
  finally
    LSeen.Free;
  end;
end;

procedure Run(const ASnapshot, AOutput: String);
var
  LInput: TFileStream;
  LDecompressed: TGZipDecompressionStream;
  LReader: TStreamReader;
  LDirectory: String;
begin
  LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(AOutput));
  if not ForceDirectories(LDirectory) or FileExists(LDirectory + 'results.tsv') or
    FileExists(LDirectory + 'abstracts.tsv') then
  begin
    raise EInOutError.Create('Use a new thesis screen output directory');
  end;
  LInput := TFileStream.Create(ASnapshot, fmOpenRead or fmShareDenyWrite);
  try
    LDecompressed := TGZipDecompressionStream.Create(LInput);
    try
      LReader := TStreamReader.Create(LDecompressed, 65536, False);
      try
        Scan(LReader, LDirectory);
      finally
        LReader.Free;
      end;
    finally
      LDecompressed.Free;
    end;
  finally
    LInput.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if ParamCount <> 2 then
    begin
      raise EArgumentException.Create('Usage: foodexperiment.theses SNAPSHOT_GZ OUTPUT_DIR');
    end;
    Run(ParamStr(1), ParamStr(2));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
