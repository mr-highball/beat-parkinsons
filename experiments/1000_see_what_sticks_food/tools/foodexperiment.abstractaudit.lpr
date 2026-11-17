{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentAbstractAudit;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.externaldata;

const
  SearchHeader = 'query_id'#9'category'#9'ingredient'#9'rank'#9'source_key'#9 +
    'source'#9'source_id'#9'pmid'#9'doi'#9'pmcid'#9'title'#9'journal'#9 +
    'publication_date'#9'publication_types'#9'abstract';
  ReviewHeader = 'ingredient'#9'source_key'#9'status'#9'access_level'#9'reason'#9 +
    'source_url'#9'local_record'#9'remaining_access_gap';

procedure CheckHeader(var AFile: Text; const APath, AHeader: String);
var
  LHeader: String;
begin
  SetTextCodePage(AFile, CP_UTF8);
  ReadLn(AFile, LHeader);
  if LHeader <> AHeader then
  begin
    raise EConvertError.Create('Unexpected TSV header: ' + APath);
  end;
end;

procedure LoadMissing(const APath: String; APairs, ASources: TStringList;
  out AAppearances: Integer);
var
  LFile: Text;
  LLine: String;
  LFields: TFields;
begin
  AAppearances := 0;
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    CheckHeader(LFile, APath, SearchHeader);
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, #9);
      if (Length(LFields) <> 15) or (LFields[2] = '') or (LFields[4] = '') then
      begin
        raise EConvertError.Create('Invalid ingredient search row: ' + APath);
      end;
      if Trim(LFields[14]) = '' then
      begin
        Inc(AAppearances);
        APairs.Add(LFields[2] + #9 + LFields[4]);
        ASources.Add(LFields[4]);
      end;
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure CheckReviews(const APath: String; APending: TStringList; out AReviewed: Integer);
var
  LFile: Text;
  LLine: String;
  LPair: String;
  LFields: TFields;
  LIndex: Integer;
begin
  AReviewed := 0;
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    CheckHeader(LFile, APath, ReviewHeader);
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, #9);
      if (Length(LFields) <> 8) or (LFields[2] = '') or (LFields[3] = '') or
        (LFields[4] = '') or (LFields[5] = '') then
      begin
        raise EConvertError.Create('Invalid abstract access review row: ' + APath);
      end;
      LPair := LFields[0] + #9 + LFields[1];
      LIndex := APending.IndexOf(LPair);
      if LIndex < 0 then
      begin
        raise EConvertError.Create('Unexpected or duplicate review: ' + LPair);
      end;
      APending.Delete(LIndex);
      Inc(AReviewed);
    end;
  finally
    CloseFile(LFile);
  end;
end;

procedure Run;
var
  LPending: TStringList;
  LSources: TStringList;
  LAppearances: Integer;
  LReviewed: Integer;
  LPair: String;
begin
  if (ParamCount < 2) or (ParamCount > 3) or
    ((ParamCount = 3) and (ParamStr(3) <> '--pending')) then
  begin
    raise EArgumentException.Create(
      'Usage: foodexperiment.abstractaudit INGREDIENT_RESULTS ACCESS_LEDGER [--pending]');
  end;
  LPending := TStringList.Create;
  try
    LSources := TStringList.Create;
    try
      LPending.CaseSensitive := True;
      LPending.Sorted := True;
      LPending.Duplicates := dupIgnore;
      LSources.CaseSensitive := True;
      LSources.Sorted := True;
      LSources.Duplicates := dupIgnore;
      LoadMissing(ParamStr(1), LPending, LSources, LAppearances);
      CheckReviews(ParamStr(2), LPending, LReviewed);
      WriteLn(StdErr, LAppearances, ' appearances without an abstract across ',
        LSources.Count, ' source keys. ', LReviewed, ' reviewed and ',
        LPending.Count, ' pending ingredient/source pairs.');
      if ParamCount = 3 then
      begin
        WriteLn('ingredient'#9'source_key');
        for LPair in LPending do
        begin
          WriteLn(LPair);
        end;
      end
      else if LPending.Count > 0 then
      begin
        raise EConvertError.Create('Missing abstract access reviews');
      end;
    finally
      LSources.Free;
    end;
  finally
    LPending.Free;
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
