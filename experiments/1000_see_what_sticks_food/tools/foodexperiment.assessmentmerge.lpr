{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentAssessmentMerge;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, StrUtils, SysUtils;

const
  Header = 'id'#9'study'#9'role'#9'fit'#9'local_reference'#9'assessment';
  AnnotationHeader = 'annotation_file'#9'annotation_heading'#9'link_label'#9'source_url'#9 +
    'pmid'#9'pmcid'#9'doi'#9'nct_id'#9'text_status'#9'text_coverage'#9'text_path';

procedure AddRows(const APath: String; ARows, AKeys: TStringList);
var
  LInput: TStringList;
  LFields: TStringArray;
  LReference: String;
  LAnchor: Integer;
  LClaimId: Integer;
  LIndex: Integer;
begin
  LInput := TStringList.Create;
  try
    LInput.LoadFromFile(APath, TEncoding.UTF8);
    if (LInput.Count = 0) or (LInput[0] <> Header) then
    begin
      raise EConvertError.Create('Invalid assessment header in ' + APath);
    end;
    for LIndex := 1 to LInput.Count - 1 do
    begin
      if LInput[LIndex] = '' then
      begin
        Continue;
      end;
      LFields := LInput[LIndex].Split([#9]);
      if (Length(LFields) <> 6) or (Length(LFields[0]) <> 4) or
        not TryStrToInt(LFields[0], LClaimId) or
        (LClaimId < 1) or (LClaimId > 1000) or (Format('%.4d', [LClaimId]) <> LFields[0]) or
        (LFields[1].Trim = '') or (LFields[3].Trim = '') or (LFields[5].Trim = '') or
        (IndexStr(LFields[2], ['supports', 'opposes', 'inconclusive', 'related', 'pending']) < 0) then
      begin
        raise EConvertError.CreateFmt('Invalid assessment in %s at line %d', [APath, LIndex + 1]);
      end;
      LReference := LFields[4];
      LAnchor := Pos('#', LReference);
      if LAnchor > 0 then
      begin
        SetLength(LReference, LAnchor - 1);
      end;
      if not FileExists(LReference) then
      begin
        raise EInOutError.Create('Missing local assessment reference: ' + LReference);
      end;
      if AKeys.IndexOf(LFields[0] + #9 + LFields[1]) >= 0 then
      begin
        raise EConvertError.Create('Duplicate claim and study: ' + LFields[0] + ' ' + LFields[1]);
      end;
      AKeys.Add(LFields[0] + #9 + LFields[1]);
      ARows.Add(LInput[LIndex]);
    end;
  finally
    LInput.Free;
  end;
end;

procedure SaveTable(ARows: TStringList; const APath: String);
begin
  if FileExists(APath) then
  begin
    raise EInOutError.Create('Use a new output file: ' + APath);
  end;
  ARows.LineBreak := #10;
  ARows.WriteBOM := False;
  ARows.SaveToFile(APath, TEncoding.UTF8);
end;

procedure CollectAnnotations;
var
  LInput: TStringList;
  LRows: TStringList;
  LFields: TStringArray;
  LBucket: String;
  LBase: String;
  LEntry: String;
  LIndex: Integer;
  LBatch: Integer;
  LCount: Integer;
begin
  LBucket := ParamStr(2);
  LBase := 'research/' + LBucket + '/Source-Text/';
  LRows := TStringList.Create;
  LInput := TStringList.Create;
  try
    LRows.LoadFromFile(LBase + 'Annotated-Sources.tsv', TEncoding.UTF8);
    if (LRows.Count = 0) or (LRows[0] <> AnnotationHeader) then
    begin
      raise EConvertError.Create('Invalid catalog header in ' + LBase);
    end;
    LCount := LRows.Count;
    for LBatch := 4 to ParamCount do
    begin
      LInput.LoadFromFile(ParamStr(LBatch), TEncoding.UTF8);
      if (LInput.Count = 0) or
        ((LInput[0] <> 'bucket'#9 + AnnotationHeader) and
          (LInput[0] <> 'period'#9 + AnnotationHeader)) then
      begin
        raise EConvertError.Create('Invalid annotation batch header in ' + ParamStr(LBatch));
      end;
      for LIndex := 1 to LInput.Count - 1 do
      begin
        LFields := LInput[LIndex].Split([#9]);
        if LFields[0] <> LBucket then
        begin
          Continue;
        end;
        if (Length(LFields) <> 12) or not FileExists(LBase + LFields[1]) or
          ((LFields[9] = 'text_available') and not FileExists(LBase + LFields[11])) then
        begin
          raise EConvertError.Create('Invalid annotation or missing text in ' + LInput[LIndex]);
        end;
        LEntry := Copy(LInput[LIndex], Length(LBucket) + 2, MaxInt);
        if LRows.IndexOf(LEntry) < 0 then
        begin
          LRows.Add(LEntry);
        end;
      end;
    end;
    SaveTable(LRows, ParamStr(3));
    WriteLn(LBucket, ': ', LRows.Count - LCount, ' annotations added');
  finally
    LInput.Free;
    LRows.Free;
  end;
end;

procedure Run;
var
  LRows: TStringList;
  LKeys: TStringList;
  LIndex: Integer;
  LBaselineCount: Integer;
  LOutput: String;
begin
  if (ParamCount >= 4) and (ParamStr(1) = 'annotations') then
  begin
    CollectAnnotations;
    Exit;
  end;
  if ParamCount < 3 then
  begin
    raise EArgumentException.Create(
      'Usage from repository root: foodexperiment.assessmentmerge BASELINE OUTPUT BATCH [BATCH ...]' +
      LineEnding + '  or foodexperiment.assessmentmerge annotations BUCKET OUTPUT BATCH [BATCH ...]');
  end;
  LOutput := ParamStr(2);
  if FileExists(LOutput) then
  begin
    raise EInOutError.Create('Use a new output file: ' + LOutput);
  end;
  LRows := TStringList.Create;
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    AddRows(ParamStr(1), LRows, LKeys);
    LBaselineCount := LRows.Count;
    for LIndex := 3 to ParamCount do
    begin
      AddRows(ParamStr(LIndex), LRows, LKeys);
    end;
    LRows.Sort;
    WriteLn(LRows.Count - LBaselineCount, ' assessments added, ', LRows.Count, ' total');
    LRows.Insert(0, Header);
    SaveTable(LRows, LOutput);
  finally
    LKeys.Free;
    LRows.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
