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
    Source: String;
  end;

function ReadArchiveIdentity(const APath: String): TArchiveIdentity;
function ParseArchiveIdentity(const AText: RawByteString): TArchiveIdentity;
function ParseTrialArchiveIdentifier(const AText: RawByteString;
  const AExpected: String): String;
function OtherRegistryIdentifier(const AValue: String): String;
function RegistryArchiveFileIdentifier(const AFileName: String): String;
function OtherRegistryHeaderMatches(const AText: RawByteString;
  const AExpected: String): Boolean;
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

function OtherRegistryIdentifier(const AValue: String): String;
var
  LSeparator: Integer;
begin
  Result := '';
  if AnsiStartsStr('ACTRN', AValue) and (Length(AValue) = 19) and
    DigitsOnly(Copy(AValue, 6, MaxInt)) then
    Exit(AValue);
  if AnsiStartsStr('ISRCTN', AValue) and (Length(AValue) = 14) and
    DigitsOnly(Copy(AValue, 7, MaxInt)) then
    Exit(AValue);
  if AnsiStartsStr('DRKS', AValue) and (Length(AValue) = 12) and
    DigitsOnly(Copy(AValue, 5, MaxInt)) then
    Exit(AValue);
  if AnsiStartsStr('TCTR', AValue) and (Length(AValue) = 15) and
    DigitsOnly(Copy(AValue, 5, MaxInt)) then
  begin
    Exit(AValue);
  end;
  if AnsiStartsStr('UMIN', AValue) and (Length(AValue) = 13) and
    DigitsOnly(Copy(AValue, 5, MaxInt)) then
  begin
    Exit(AValue);
  end;
  if AnsiStartsStr('IRCT', AValue) then
  begin
    LSeparator := Pos('N', AValue);
    if (LSeparator >= 14) and DigitsOnly(Copy(AValue, 5, LSeparator - 5)) and
      DigitsOnly(Copy(AValue, LSeparator + 1, MaxInt)) then
      Exit(AValue);
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
  Result := OtherRegistryIdentifier(LValue);
  if Result <> '' then
    Exit;
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

function RegistryArchiveFileIdentifier(const AFileName: String): String;
var
  LName: String;
  LStart: Integer;
  LEnd: Integer;
begin
  LName := UpperCase(ChangeFileExt(AFileName, ''));
  LStart := 1;
  while (LStart <= Length(LName)) and (LName[LStart] in ['0'..'9', '-']) do
    Inc(LStart);
  LEnd := PosEx('-', LName, LStart);
  if LEnd = 0 then
    LEnd := Length(LName) + 1;
  LName := Copy(LName, LStart, LEnd - LStart);
  if AnsiStartsStr('NCT', LName) then
    Result := NormalizeArchiveIdentifier(LName)
  else
    Result := OtherRegistryIdentifier(LName);
end;

function TctrRegistryHeaderMatches(const AText: RawByteString; const AExpected: String): Boolean;
const
  COfficialHost = 'https://www.thaiclinicaltrials.org';
var
  LLine: String;
  LField: String;
  LValue: String;
  LStart: Integer;
  LEnd: Integer;
  LSeparator: Integer;
begin
  Result := False;
  LStart := 1;
  if Copy(AText, 1, 3) = #$EF#$BB#$BF then
  begin
    LStart := 4;
  end;
  while LStart <= Length(AText) do
  begin
    LEnd := PosEx(#10, AText, LStart);
    if LEnd = 0 then
    begin
      LEnd := Length(AText) + 1;
    end;
    LLine := Trim(Copy(AText, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    // The local extracts place their provenance before the first blank line.
    if LLine = '' then
    begin
      Break;
    end;
    LSeparator := Pos(':', LLine);
    if LSeparator = 0 then
    begin
      Continue;
    end;
    LField := Trim(Copy(LLine, 1, LSeparator - 1));
    LValue := Trim(Copy(LLine, LSeparator + 1, MaxInt));
    case IndexText(LField, ['registry', 'identifier', 'trial id', 'record', 'registration',
      'registration number', 'registry id', 'registry identifier', 'source', 'official source',
      'official record', 'official xml']) of
      0..7:
        if not ((UpperCase(LValue) = AExpected) or
          (SameText(LField, 'registry') and SameText(LValue, 'Thai Clinical Trials Registry'))) then
        begin
          Exit(False);
        end;
      8..11:
        begin
          if (LValue <> COfficialHost + '/show/' + AExpected) and
            (LValue <> COfficialHost + '/export/xml/' + AExpected) then
          begin
            Exit(False);
          end;
          Result := True;
        end;
    end;
  end;
end;

function UminRegistryHeaderMatches(const AText: RawByteString;
  const AExpected: String): Boolean;
const
  CHeaderBytes = 1024;
  CViewPrefixes: array[0..3] of String = (
    'https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=',
    'https://center6.umin.ac.jp/cgi-open-bin/ctr/ctr_view.cgi?recptno=',
    'https://center6.umin.ac.jp/cgi-open-bin/icdr_e/ctr_view.cgi?recptno=',
    'https://center6.umin.ac.jp/cgi-open-bin/icdr/ctr_view.cgi?recptno=');
var
  LHeader: String;
  LLine: String;
  LField: String;
  LValue: String;
  LIdentity: String;
  LPrefix: String;
  LReceipt: String;
  LSourceReceipt: String;
  LStart: Integer;
  LEnd: Integer;
  LSeparator: Integer;
  LHasIdentity: Boolean;
  LHasProvider: Boolean;
begin
  LHeader := Copy(AText, 1, CHeaderBytes);
  if Copy(LHeader, 1, 3) = #$EF#$BB#$BF then
  begin
    Delete(LHeader, 1, 3);
  end;
  LStart := 1;
  LHasIdentity := False;
  LHasProvider := False;
  LSourceReceipt := '';
  while LStart <= Length(LHeader) do
  begin
    LEnd := PosEx(#10, LHeader, LStart);
    if LEnd = 0 then
    begin
      LEnd := Length(LHeader) + 1;
    end;
    LLine := Trim(Copy(LHeader, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    LField := '';
    LValue := LLine;
    LSeparator := Pos(':', LLine);
    if (LSeparator > 0) and not AnsiStartsText('https://', LLine) then
    begin
      LField := Trim(Copy(LLine, 1, LSeparator - 1));
      LValue := Trim(Copy(LLine, LSeparator + 1, MaxInt));
    end;
    LIdentity := '';
    if OtherRegistryIdentifier(UpperCase(Copy(LLine, 1, 13))) <> '' then
    begin
      LIdentity := LLine;
    end
    else if AnsiStartsText('Official study UMIN', LLine) then
    begin
      LIdentity := Copy(LLine, Length('Official study ') + 1, MaxInt);
    end
    else if IndexText(LField, ['registry', 'identifier', 'trial id', 'record',
      'registration', 'registration number', 'registry id', 'registry identifier']) >= 0 then
    begin
      LIdentity := LValue;
    end
    else if AnsiStartsText('Source: UMIN Clinical Trials Registry', LLine) then
    begin
      LIdentity := Trim(Copy(LValue, Length('UMIN Clinical Trials Registry') + 1, MaxInt));
      if AnsiStartsStr(',', LIdentity) then
      begin
        LIdentity := Trim(Copy(LIdentity, 2, MaxInt));
      end;
    end;
    if AnsiStartsText('UMIN', LIdentity) and (Length(LIdentity) >= 13) and
      ((Length(LIdentity) = 13) or not (LIdentity[14] in ['a'..'z', 'A'..'Z', '0'..'9'])) then
    begin
      LIdentity := OtherRegistryIdentifier(UpperCase(Copy(LIdentity, 1, 13)));
      if LIdentity <> AExpected then
      begin
        Exit(False);
      end;
      LHasIdentity := True;
    end;
    // Receipt numbers and UMIN trial numbers are separate namespaces.
    if (LField = '') or (IndexText(LField, ['source', 'url', 'official record',
      'official registry', 'official source', 'source url', 'japanese source']) >= 0) then
    begin
      for LPrefix in CViewPrefixes do
      begin
        if AnsiStartsStr(LPrefix, LValue) then
        begin
          LReceipt := Copy(LValue, Length(LPrefix) + 1, MaxInt);
          if (Length(LReceipt) = 10) and (LReceipt[1] = 'R') and
            DigitsOnly(Copy(LReceipt, 2, MaxInt)) then
          begin
            if (LSourceReceipt <> '') and (LSourceReceipt <> LReceipt) then
            begin
              Exit(False);
            end;
            LSourceReceipt := LReceipt;
            LHasProvider := True;
          end;
        end;
      end;
    end;
  end;
  Result := LHasIdentity and LHasProvider;
end;

function OtherRegistryHeaderMatches(const AText: RawByteString;
  const AExpected: String): Boolean;
const
  CHeaderBytes = 1024;
  CAnzctrHeading = 'Official ANZCTR registration ';
var
  LHeader: String;
  LLine: String;
  LIdentity: String;
  LUrl: String;
  LStart: Integer;
  LEnd: Integer;
  LSplit: Integer;
  LHasIdentity: Boolean;
  LHasProvider: Boolean;
begin
  Result := False;
  if OtherRegistryIdentifier(AExpected) = '' then
    Exit;
  if AnsiStartsStr('TCTR', AExpected) then
  begin
    Exit(TctrRegistryHeaderMatches(AText, AExpected));
  end;
  if AnsiStartsStr('UMIN', AExpected) then
  begin
    Exit(UminRegistryHeaderMatches(AText, AExpected));
  end;
  LHeader := Copy(AText, 1, CHeaderBytes);
  LStart := 1;
  LHasIdentity := False;
  LHasProvider := False;
  while LStart <= Length(LHeader) do
  begin
    LEnd := PosEx(#10, LHeader, LStart);
    if LEnd = 0 then
      Break;
    LLine := Trim(Copy(LHeader, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    LSplit := Pos(':', LLine);
    if LSplit > 0 then
      case IndexText(Copy(LLine, 1, LSplit - 1),
        ['record', 'registration', 'registration number', 'registry id', 'registry identifier']) of
        0..4:
          begin
            LIdentity := OtherRegistryIdentifier(UpperCase(Trim(Copy(LLine,
              LSplit + 1, MaxInt))));
            if (LIdentity <> '') and (LIdentity <> AExpected) then
              Exit;
            LHasIdentity := LHasIdentity or (LIdentity = AExpected);
          end;
      end;
    LHasIdentity := LHasIdentity or AnsiStartsText(AExpected + '.', LLine);
    if AnsiStartsStr('ACTRN', AExpected) and
      AnsiStartsText(CAnzctrHeading, LLine) then
    begin
      LIdentity := Copy(LLine, Length(CAnzctrHeading) + 1, Length(AExpected));
      if (OtherRegistryIdentifier(UpperCase(LIdentity)) <> AExpected) or
        (Copy(LLine, Length(CAnzctrHeading) + Length(AExpected) + 1, 1) <> '.') then
        Exit;
      LHasIdentity := True;
    end;
    if AnsiStartsText('Source: https://', LLine) then
      LLine := Copy(LLine, Length('Source: ') + 1, MaxInt)
    else if AnsiStartsText('Primary source: https://', LLine) then
      LLine := Copy(LLine, Length('Primary source: ') + 1, MaxInt)
    else if AnsiStartsText('URL: https://', LLine) then
      LLine := Copy(LLine, Length('URL: ') + 1, MaxInt);
    LUrl := LowerCase(LLine);
    if AnsiStartsStr('ACTRN', AExpected) then
      LHasProvider := LHasProvider or
        AnsiStartsStr('https://anzctr.org.au/trial/registration/trialreview.aspx?id=', LUrl) or
        AnsiStartsStr('https://www.anzctr.org.au/trial/registration/trialreview.aspx?id=', LUrl) or
        (Pos(' https://anzctr.org.au/trial/registration/trialreview.aspx?id=', LUrl) > 0) or
        (LUrl = 'https://anzctr.org.au/' + LowerCase(AExpected) + '.aspx') or
        (LUrl = 'https://www.anzctr.org.au/' + LowerCase(AExpected) + '.aspx') or
        (LUrl = 'https://anzctr.org.au/trial/registration/trialreview.aspx?actrn=' +
          Copy(AExpected, 6, MaxInt)) or
        (LUrl = 'https://www.anzctr.org.au/trial/registration/trialreview.aspx?actrn=' +
          Copy(AExpected, 6, MaxInt))
    else if AnsiStartsStr('DRKS', AExpected) then
    begin
      if (LUrl = 'https://drks.de/search/en/trial/' + LowerCase(AExpected)) or
        (LUrl = 'https://drks.de/search/en/trial/' + LowerCase(AExpected) + '/details') or
        (LUrl = 'https://drks.de/search/de/trial/' + LowerCase(AExpected)) or
        (LUrl = 'https://drks.de/search/de/trial/' + LowerCase(AExpected) + '/details') then
      begin
        // The official path carries the record identity in older extracts.
        LHasProvider := True;
        LHasIdentity := True;
      end;
    end
    else if AnsiStartsStr('IRCT', AExpected) then
      LHasProvider := LHasProvider or AnsiStartsStr('https://irct.ir/trial/', LUrl) or
        AnsiStartsStr('https://en.irct.ir/trial/', LUrl)
    else
      LHasProvider := LHasProvider or (LUrl = 'https://www.isrctn.com/' +
        LowerCase(AExpected)) or (LUrl = 'https://www.isrctn.com/pdf/' + LowerCase(AExpected));
  end;
  Result := LHasIdentity and LHasProvider;
end;

function ParseTrialArchiveIdentifier(const AText: RawByteString;
  const AExpected: String): String;
const
  CRegistryHeaderBytes = 1024;
  SourcePrefixes: array[0..1] of String = (
    'https://clinicaltrials.gov/study/', 'https://clinicaltrials.gov/api/v2/studies/');
var
  LText: RawByteString;
  LStart: Integer;
  LEnd: Integer;
  LSeparator: Integer;
  LLine: String;
  LPrefix: String;
  LHasSource: Boolean;
begin
  Result := '';
  if not AnsiStartsStr('NCT', AExpected) or (NormalizeArchiveIdentifier(AExpected) <> AExpected) then
    Exit;
  LText := Copy(AText, 1, CRegistryHeaderBytes);
  if Copy(LText, 1, 3) = #$EF#$BB#$BF then
    Delete(LText, 1, 3);
  LHasSource := False;
  LStart := 1;
  while LStart <= Length(LText) do
  begin
    LEnd := PosEx(#10, LText, LStart);
    if LEnd = 0 then
    begin
      if Length(AText) > CRegistryHeaderBytes then
        Break;
      LEnd := Length(LText) + 1;
    end;
    LLine := Trim(Copy(LText, LStart, LEnd - LStart));
    LStart := LEnd + 1;
    LSeparator := Pos(':', LLine);
    if LSeparator > 0 then
    begin
      case IndexText(Copy(LLine, 1, LSeparator - 1),
        ['NCT ID', 'Registration', 'Registry ID', 'Registry identifier', 'Source',
          'URL', 'Official API', 'Primary source']) of
        0..3:
          if NormalizeArchiveIdentifier(Copy(LLine, LSeparator + 1, MaxInt)) <> AExpected then
            Exit;
        4..7:
          LLine := Trim(Copy(LLine, LSeparator + 1, MaxInt));
      end;
    end;
    for LPrefix in SourcePrefixes do
      if AnsiStartsText(LPrefix, LLine) then
      begin
        Delete(LLine, 1, Length(LPrefix));
        LSeparator := Pos('?', LLine);
        if LSeparator > 0 then
          SetLength(LLine, LSeparator - 1);
        LSeparator := Pos('#', LLine);
        if LSeparator > 0 then
          SetLength(LLine, LSeparator - 1);
        if NormalizeArchiveIdentifier(LLine) <> AExpected then
          Exit;
        LHasSource := True;
        Break;
      end;
  end;
  if LHasSource then
    Result := AExpected;
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
    case IndexStr(Copy(LLine, 1, LSplit - 1), ['PMCID', 'PMID', 'DOI', 'Title', 'Source']) of
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
      4:
        Result.Source := LValue;
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
