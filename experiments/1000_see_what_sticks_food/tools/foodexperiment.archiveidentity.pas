{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.archiveidentity;

{$mode delphi}
{$H+}

interface

const
  ArchiveHeaderBytes = 8192;

type
  TArchiveIdentity = record
    Pmcid: String;
    Pmid: String;
    Doi: String;
    Title: String;
  end;

function ReadArchiveIdentity(const APath: String): TArchiveIdentity;
function ParseArchiveIdentity(const AText: RawByteString): TArchiveIdentity;
function ParseTrialArchiveIdentifier(const AText: RawByteString;
  const AExpected: String): String;
function NormalizeArchiveIdentifier(const AValue: String): String;
function ArchiveIdentityConflicts(const AExpected, AArchive: TArchiveIdentity): String;
function SameTitledArchive(const AExpected, AArchive: TArchiveIdentity): Boolean;

implementation

uses
  Classes, SysUtils, StrUtils;

function DigitsOnly(const AValue: String): Boolean;
var
  C: Char;
begin
  if AValue = '' then
    Exit(False);
  for C in AValue do
    if not (C in ['0'..'9']) then
      Exit(False);
  Result := True;
end;

function NormalizeDoi(const AValue: String): String;
const
  Prefixes: array[0..4] of String = ('https://doi.org/', 'http://doi.org/', 'https://dx.doi.org/',
    'http://dx.doi.org/', 'doi:');
var
  LPrefix: String;
  LSlash: Integer;
  LIndex: Integer;
begin
  Result := LowerCase(Trim(AValue));
  for LPrefix in Prefixes do
    if AnsiStartsStr(LPrefix, Result) then
    begin
      Delete(Result, 1, Length(LPrefix));
      Break;
    end;
  Result := Trim(Result);
  LSlash := Pos('/', Result);
  if not AnsiStartsStr('10.', Result) or (LSlash < 5) or (LSlash = Length(Result)) or
    (Pos(' ', Result) > 0) or (Pos(#0, Result) > 0) or (Pos(#9, Result) > 0) or
    (Pos(#10, Result) > 0) or (Pos(#13, Result) > 0) then
    Exit('');
  for LIndex := 4 to LSlash - 1 do
  begin
    if (Result[LIndex] = '.') and (Result[LIndex - 1] in ['0'..'9']) and
      (Result[LIndex + 1] in ['0'..'9']) then
      Continue;
    if not (Result[LIndex] in ['0'..'9']) then
      Exit('');
  end;
end;

function NormalizeArchiveIdentifier(const AValue: String): String;
var
  LValue: String;
  LDoi: String;
begin
  LValue := UpperCase(Trim(AValue));
  if AnsiStartsStr('PMID:', LValue) then
  begin
    LValue := Trim(Copy(LValue, 6, MaxInt));
    if DigitsOnly(LValue) then
      Exit('PMID:' + LValue);
    Exit('');
  end;
  if DigitsOnly(LValue) then
    Exit('PMID:' + LValue);
  if AnsiStartsStr('PMCID:', LValue) then
  begin
    LValue := Trim(Copy(LValue, 7, MaxInt));
    if not (AnsiStartsStr('PMC', LValue) and DigitsOnly(Copy(LValue, 4, MaxInt))) then
      Exit('');
  end;
  if AnsiStartsStr('PMC', LValue) and DigitsOnly(Copy(LValue, 4, MaxInt)) then
    Exit('PMCID:' + LValue);
  if AnsiStartsStr('NCT', LValue) and (Length(LValue) = 11) and
    DigitsOnly(Copy(LValue, 4, MaxInt)) then
    Exit(LValue);
  LDoi := NormalizeDoi(AValue);
  if LDoi <> '' then
    Exit('DOI:' + LDoi);
  Result := '';
end;

function ReadArchiveIdentity(const APath: String): TArchiveIdentity;
var
  LFile: TFileStream;
  LText: RawByteString;
begin
  if not FileExists(APath) then
    Exit(Default(TArchiveIdentity));
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LText, ArchiveHeaderBytes);
    SetLength(LText, LFile.Read(LText[1], ArchiveHeaderBytes));
  finally
    LFile.Free;
  end;
  Result := ParseArchiveIdentity(LText);
end;

function ParseTrialArchiveIdentifier(const AText: RawByteString;
  const AExpected: String): String;
const
  CSource = 'Source: https://clinicaltrials.gov/study/';
  CIdentity = 'NCT ID: ';
  CRegistryHeaderBytes = 1024;
var
  LText: RawByteString;
  LStart: Integer;
  LEnd: Integer;
  LSuffix: Integer;
  LLine: String;
  LSource: String;
begin
  Result := '';
  if not AnsiStartsStr('NCT', AExpected) then
    Exit;
  LText := Copy(AText, 1, CRegistryHeaderBytes);
  LSource := '';
  LStart := 1;
  while LStart <= Length(LText) do
  begin
    LEnd := PosEx(#10, LText, LStart);
    if LEnd = 0 then
      Exit;
    LLine := Trim(Copy(LText, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    if AnsiStartsStr(CSource, LLine) then
    begin
      LSuffix := Pos('?', LLine);
      if LSuffix <> 0 then
        SetLength(LLine, LSuffix - 1);
      LSuffix := Pos('#', LLine);
      if LSuffix <> 0 then
        SetLength(LLine, LSuffix - 1);
      LSource := NormalizeArchiveIdentifier(Copy(LLine, Length(CSource) + 1, MaxInt));
    end
    else if AnsiStartsStr(CIdentity, LLine) then
    begin
      if (LSource = AExpected) and
        (LSource = NormalizeArchiveIdentifier(Copy(LLine, Length(CIdentity) + 1, MaxInt))) then
        Result := LSource;
      Exit;
    end;
  end;
end;

function ParseArchiveIdentity(const AText: RawByteString): TArchiveIdentity;
var
  LText: RawByteString;
  LLine: String;
  LValue: String;
  LInHeader: Boolean;
  LWrapped: Boolean;
  LStart: Integer;
  LEnd: Integer;
  LSplit: Integer;
begin
  Result := Default(TArchiveIdentity);
  LText := Copy(AText, 1, ArchiveHeaderBytes);
  if Copy(LText, 1, 3) = #$EF#$BB#$BF then
    Delete(LText, 1, 3);
  LWrapped := AnsiStartsStr('Title:', LText);
  LInHeader := LWrapped;
  if not LInHeader and
    (Pos('JOURNAL INFORMATION', Trim(Copy(LText, 1, 32))) <> 1) then
    Exit;
  LStart := 1;
  while LStart <= Length(LText) do
  begin
    LEnd := PosEx(#10, LText, LStart);
    if LEnd = 0 then
      Break;
    LLine := Trim(Copy(LText, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    if not LInHeader then
    begin
      LInHeader := LLine = 'ARTICLE INFORMATION';
      Continue;
    end;
    if LLine = '' then
    begin
      if not LWrapped then
      begin
        LEnd := PosEx(#10, LText, LStart);
        if LEnd > LStart then
          Result.Title := Trim(Copy(LText, LStart, LEnd - LStart));
      end;
      Break;
    end;
    LSplit := Pos(':', LLine);
    if LSplit = 0 then
      Continue;
    LValue := Trim(Copy(LLine, LSplit + 1, MaxInt));
    case IndexStr(Copy(LLine, 1, LSplit - 1), ['PMCID', 'PMID', 'DOI', 'Title']) of
      0:
        if AnsiStartsText('PMC', LValue) and DigitsOnly(Copy(LValue, 4, MaxInt)) then
          Result.Pmcid := UpperCase(LValue);
      1:
        if DigitsOnly(LValue) then
          Result.Pmid := LValue;
      2:
        Result.Doi := NormalizeDoi(LValue);
      3:
        Result.Title := LValue;
    end;
  end;
end;

function IsCollectionTitle(const ATitle: String): Boolean;
var
  LTitle: String;
begin
  LTitle := LowerCase(Trim(ATitle));
  Result := (LTitle = 'abstracts') or (LTitle = 'posters') or
    AnsiStartsStr('abstracts of ', LTitle) or AnsiStartsStr('annual symposium of ', LTitle) or
    AnsiStartsStr('meeting abstracts ', LTitle) or AnsiStartsStr('proceedings of ', LTitle) or
    ((AnsiEndsStr(' abstracts', LTitle) or AnsiEndsStr(' abstracts.', LTitle)) and
     ((Pos(' meeting', LTitle) > 0) or (Pos(' congress', LTitle) > 0) or
      (Pos(' conference', LTitle) > 0) or (Pos(' symposium', LTitle) > 0)));
end;

function ArchiveIdentityConflicts(const AExpected, AArchive: TArchiveIdentity): String;
var
  LExpectedDoi, LArchiveDoi: String;

  procedure Compare(const AField, ALeft, ARight: String);
  begin
    if (ALeft = '') or (ARight = '') or SameText(ALeft, ARight) then
      Exit;
    if Result <> '' then
      Result := Result + ',';
    Result := Result + AField;
  end;

begin
  Result := '';
  Compare('pmcid', AExpected.Pmcid, AArchive.Pmcid);
  Compare('pmid', AExpected.Pmid, AArchive.Pmid);
  LExpectedDoi := NormalizeDoi(AExpected.Doi);
  LArchiveDoi := NormalizeDoi(AArchive.Doi);
  Compare('doi', LExpectedDoi, LArchiveDoi);
  { Some PMC collections carry an individual article's identifiers. }
  if (Result = '') and (AExpected.Title <> '') and (AExpected.Pmcid <> '') and
    (AExpected.Pmid <> '') and SameText(AExpected.Pmcid, AArchive.Pmcid) and
    SameText(AExpected.Pmid, AArchive.Pmid) and IsCollectionTitle(AArchive.Title) and
    not IsCollectionTitle(AExpected.Title) then
    Result := 'collection_title';
end;

function SameTitledArchive(const AExpected, AArchive: TArchiveIdentity): Boolean;
var
  LTitle: String;

  function FoldTitle(const ATitle: String): String;
  var
    C: Char;
  begin
    Result := '';
    for C in LowerCase(ATitle) do
      if C in ['a'..'z', '0'..'9'] then
        Result := Result + C;
  end;

begin
  LTitle := FoldTitle(AExpected.Title);
  Result := (AExpected.Pmcid <> '') and (AExpected.Pmid <> '') and
    SameText(AExpected.Pmcid, AArchive.Pmcid) and SameText(AExpected.Pmid, AArchive.Pmid) and
    (LTitle <> '') and (LTitle = FoldTitle(AArchive.Title));
end;
end.
