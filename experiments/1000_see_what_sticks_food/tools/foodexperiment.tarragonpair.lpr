{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TarragonPairErrors;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils;

type
  TPairErrors = array[Boolean] of Integer;
  TAnimal = record
    Identifier: String;
    Genotype: String;
    Trials: TPairErrors;
    Errors: TPairErrors;
  end;
  TAnimals = array of TAnimal;

function AnimalIndex(const AAnimals: TAnimals; const AIdentifier: String): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AAnimals) do
  begin
    if AAnimals[LIndex].Identifier = AIdentifier then
    begin
      Exit(LIndex);
    end;
  end;
  raise EConvertError.Create('Missing animal ID: ' + AIdentifier);
end;

procedure ReadFile(const APath: String; var AAnimals: TAnimals;
  const AAutomatic, AGenotypes: Boolean);
var
  LLines: TStringList;
  LFields: TStringList;
  LRow: Integer;
  LIndex: Integer;
  LIdentifier: String;
  LReverse: Boolean;
  LTrials: Integer;
  LErrors: Integer;
begin
  LLines := TStringList.Create;
  LFields := TStringList.Create;
  try
    LFields.Delimiter := ',';
    LFields.StrictDelimiter := True;
    LLines.LoadFromFile(APath);
    for LRow := 1 to LLines.Count - 1 do
    begin
      if (LLines[LRow] = '') or (LLines[LRow][1] = '#') then
      begin
        Continue;
      end;
      LFields.DelimitedText := LLines[LRow];
      LIdentifier := LFields[0];
      if AGenotypes then
      begin
        LIndex := Length(AAnimals);
        SetLength(AAnimals, LIndex + 1);
        AAnimals[LIndex].Identifier := LIdentifier;
        AAnimals[LIndex].Genotype := LFields[2];
        Continue;
      end;

      if AAutomatic then
      begin
        if (LFields[4] <> 'OP 7') and (LFields[4] <> 'REV 7') then
        begin
          Continue;
        end;
        if LIdentifier = '1297' then
        begin
          LIdentifier := '1927';
        end;
        if not SameText(LFields[11], 'TARRAGON') and not SameText(LFields[12], 'TARRAGON') then
        begin
          raise EConvertError.Create('Pair 7 row lacks tarragon: ' + APath);
        end;
        LReverse := LFields[4] = 'REV 7';
        LTrials := Ord(SameText(LFields[20], 'FALSE'));
        LErrors := LTrials - Ord(SameText(LFields[22], 'TRUE'));
      end
      else
      begin
        if (LFields[1] <> '7') or not SameText(LFields[8], 'FALSE') then
        begin
          Continue;
        end;
        LReverse := LFields[2] = 'yes';
        LTrials := StrToInt(LFields[5]) + StrToInt(LFields[7]);
        LErrors := LTrials - StrToInt(LFields[4]) - StrToInt(LFields[6]);
      end;

      LIndex := AnimalIndex(AAnimals, LIdentifier);
      Inc(AAnimals[LIndex].Trials[LReverse], LTrials);
      Inc(AAnimals[LIndex].Errors[LReverse], LErrors);
    end;
  finally
    LFields.Free;
    LLines.Free;
  end;
end;

procedure ReadFolder(const APath: String; var AAnimals: TAnimals; const AAutomatic: Boolean);
var
  LEntry: TSearchRec;
begin
  if FindFirst(APath + '*.csv', faArchive, LEntry) = 0 then
  begin
    try
      repeat
        ReadFile(APath + LEntry.Name, AAnimals, AAutomatic, False);
      until FindNext(LEntry) <> 0;
    finally
      FindClose(LEntry);
    end;
  end;
end;

procedure Run(const ADataPath: String);
var
  LAnimals: TAnimals;
  LAnimal: TAnimal;
  LRoot: String;
begin
  LAnimals := nil;
  LRoot := IncludeTrailingPathDelimiter(ADataPath);
  ReadFile(LRoot + 'geno clean.csv', LAnimals, False, True);
  ReadFolder(LRoot + 'csvs' + PathDelim, LAnimals, False);
  ReadFolder(LRoot + 'auto' + PathDelim, LAnimals, True);
  WriteLn('animal'#9'genotype'#9'discrimination_trials'#9'discrimination_errors'#9,
    'reversal_trials'#9'reversal_errors');
  for LAnimal in LAnimals do
  begin
    if LAnimal.Trials[False] + LAnimal.Trials[True] > 0 then
    begin
      WriteLn(LAnimal.Identifier, #9, LAnimal.Genotype, #9, LAnimal.Trials[False], #9,
        LAnimal.Errors[False], #9, LAnimal.Trials[True], #9, LAnimal.Errors[True]);
    end;
  end;
end;

begin
  if ParamCount <> 1 then
  begin
    raise EArgumentException.Create('Usage: tarragon-pair-errors <author-data-directory>');
  end;
  Run(ParamStr(1));
end.
