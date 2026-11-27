{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.presentation;

{$mode delphi}
{$H+}

interface

type
  TSourceIndices = array of Integer;
  TSourceSelection = record
    Indices: TSourceIndices;
    Examined: Integer;
  end;

const
  SourceKindAll = 0;
  SourceKindStudies = 1;
  SourceKindCulture = 2;
  ConversationSourceLabel = 'Conversation';

function IsCulturalSource(const APath: String): Boolean;
function IsConversationSource(const APath: String): Boolean;
function MatchesSourceKind(const APath: String; AKind: Integer): Boolean;
function RelatedSourceTerms(const AIngredient, ASymptom: String; AKind: Integer): String;
function FormatCulturalBadgeCount(ACount: Integer): String;
function GitHubRawURL(const ARepository, ARevision, ALocalPath: String): String;
function SourceDocumentYear(const APath, APeriod: String): Integer;
function SourceDocumentSortKey(const APath, APeriod: String): Integer;
function CompareSourcesByYearDesc(const APathA, APeriodA, APathB, APeriodB: String): Integer;
function SelectSourcePage(const APaths: array of String; AKind,
  ARemaining: Integer): TSourceSelection;

implementation

uses
  SysUtils;

const
  CCultureDirectory = '/cultural-and-experiential/';

function IsInCulturalDirectory(const APath, ADirectory: String): Boolean;
const
  CResearchPrefix = 'research/';
var
  LPath: String;
  LPeriodEnd: Integer;
begin
  LPath := LowerCase(StringReplace(APath, '\', '/', [rfReplaceAll]));
  LPeriodEnd := Pos('/', Copy(LPath, Length(CResearchPrefix) + 1, MaxInt));
  Result := (Pos(CResearchPrefix, LPath) = 1) and (LPeriodEnd > 1) and
    (Copy(LPath, Length(CResearchPrefix) + LPeriodEnd, Length(ADirectory)) = ADirectory);
end;

function IsCulturalSource(const APath: String): Boolean;
begin
  Result := IsInCulturalDirectory(APath, CCultureDirectory);
end;

function IsConversationSource(const APath: String): Boolean;
begin
  Result := IsInCulturalDirectory(APath, CCultureDirectory + 'conversations/');
end;

function MatchesSourceKind(const APath: String; AKind: Integer): Boolean;
begin
  case AKind of
    SourceKindAll: Result := True;
    SourceKindStudies: Result := not IsCulturalSource(APath);
    SourceKindCulture: Result := IsCulturalSource(APath);
  else
    raise EArgumentException.Create('Unknown source collection.');
  end;
end;

function RelatedSourceTerms(const AIngredient, ASymptom: String; AKind: Integer): String;
var
  LSymptom: String;
begin
  LSymptom := ASymptom;
  if LSymptom = 'rest tremor severity' then
  begin
    LSymptom := 'tremor';
  end;
  Result := Trim(AIngredient + ' ' + LSymptom);
  if (Result <> '') and (AKind = SourceKindCulture) then
  begin
    Result := Result + ' cultural experiential';
  end;
end;

function FormatCulturalBadgeCount(ACount: Integer): String;
begin
  if ACount <= 0 then
    Exit('0');
  if ACount > 99 then
    Exit('99+');
  Result := IntToStr(ACount);
end;

function EncodeUrlSegment(const ASegment: String): String;
const
  CHex = '0123456789ABCDEF';
var
  LIndex: Integer;
  LCode: Integer;
  LCh: Char;
begin
  Result := '';
  for LIndex := 1 to Length(ASegment) do
  begin
    LCh := ASegment[LIndex];
    LCode := Ord(LCh);
    if ((LCode >= Ord('A')) and (LCode <= Ord('Z'))) or
      ((LCode >= Ord('a')) and (LCode <= Ord('z'))) or
      ((LCode >= Ord('0')) and (LCode <= Ord('9'))) or
      (LCh = '-') or (LCh = '_') or (LCh = '.') or (LCh = '~') then
      Result := Result + LCh
    else if LCode < 256 then
      Result := Result + '%' + CHex[(LCode shr 4) + 1] + CHex[(LCode and $0F) + 1]
    else
      Result := Result + LCh;
  end;
end;

function GitHubRawURL(const ARepository, ARevision, ALocalPath: String): String;
const
  CGitHubPrefix = 'https://github.com/';
var
  LRepo: String;
  LSlug: String;
  LSlash: Integer;
  LOwner: String;
  LName: String;
  LRev: String;
  LPath: String;
  LHash: Integer;
  LStart: Integer;
  LIndex: Integer;
  LSeg: String;
begin
  Result := '';
  LRepo := Trim(ARepository);
  while (Length(LRepo) > 0) and (LRepo[Length(LRepo)] = '/') do
    Delete(LRepo, Length(LRepo), 1);
  if (Length(LRepo) > 4) and (LowerCase(Copy(LRepo, Length(LRepo) - 3, 4)) = '.git') then
    Delete(LRepo, Length(LRepo) - 3, 4);
  if LowerCase(Copy(LRepo, 1, Length(CGitHubPrefix))) <> CGitHubPrefix then
    Exit;
  LSlug := Copy(LRepo, Length(CGitHubPrefix) + 1, MaxInt);
  LSlash := Pos('/', LSlug);
  if (LSlash <= 1) or (LSlash >= Length(LSlug)) then
    Exit;
  LOwner := Copy(LSlug, 1, LSlash - 1);
  LName := Copy(LSlug, LSlash + 1, MaxInt);
  if (Pos('/', LName) > 0) or (LOwner = '.') or (LOwner = '..') or
    (LName = '.') or (LName = '..') then
    Exit;

  LRev := Trim(ARevision);
  if (LRev = '') or (Pos('/', LRev) > 0) or (Pos('\', LRev) > 0) or
    (Pos(' ', LRev) > 0) or (Pos('..', LRev) > 0) then
    Exit;

  LPath := Trim(StringReplace(ALocalPath, '\', '/', [rfReplaceAll]));
  LHash := Pos('#', LPath);
  if LHash > 0 then
    LPath := Copy(LPath, 1, LHash - 1);
  if Copy(LPath, 1, 9) <> 'research/' then
    Exit;

  Result := 'https://raw.githubusercontent.com/' + EncodeUrlSegment(LOwner) + '/' +
    EncodeUrlSegment(LName) + '/' + EncodeUrlSegment(LRev);
  LStart := 1;
  for LIndex := 1 to Length(LPath) + 1 do
  begin
    if (LIndex > Length(LPath)) or (LPath[LIndex] = '/') then
    begin
      LSeg := Copy(LPath, LStart, LIndex - LStart);
      if (LSeg = '') or (LSeg = '.') or (LSeg = '..') then
        Exit('');
      Result := Result + '/' + EncodeUrlSegment(LSeg);
      LStart := LIndex + 1;
    end;
  end;
end;

function IsAsciiDigit(ACh: Char): Boolean;
begin
  Result := (ACh >= '0') and (ACh <= '9');
end;

function ParseFourDigitYear(const AText: String; AStart: Integer): Integer;
var
  LYear: Integer;
begin
  Result := 0;
  if (AStart < 1) or (AStart + 3 > Length(AText)) then
    Exit;
  if not (IsAsciiDigit(AText[AStart]) and IsAsciiDigit(AText[AStart + 1]) and
    IsAsciiDigit(AText[AStart + 2]) and IsAsciiDigit(AText[AStart + 3])) then
    Exit;
  LYear := (Ord(AText[AStart]) - Ord('0')) * 1000 +
    (Ord(AText[AStart + 1]) - Ord('0')) * 100 +
    (Ord(AText[AStart + 2]) - Ord('0')) * 10 +
    (Ord(AText[AStart + 3]) - Ord('0'));
  if (LYear >= 1500) and (LYear <= 2100) then
    Result := LYear;
end;

function LeadingFilenameYear(const APath: String): Integer;
var
  LIndex: Integer;
  LBaseStart: Integer;
  LNextIndex: Integer;
  LNext: Char;
begin
  Result := 0;
  LBaseStart := 1;
  for LIndex := Length(APath) downto 1 do
  begin
    if (APath[LIndex] = '/') or (APath[LIndex] = '\') then
    begin
      LBaseStart := LIndex + 1;
      Break;
    end;
  end;
  Result := ParseFourDigitYear(APath, LBaseStart);
  if Result = 0 then
    Exit;
  LNextIndex := LBaseStart + 4;
  if LNextIndex <= Length(APath) then
  begin
    LNext := APath[LNextIndex];
    if (LNext <> '-') and (LNext <> '_') and (LNext <> ' ') and (LNext <> '.') then
      Result := 0;
  end;
end;

function PeriodStartYear(const APath, APeriod: String): Integer;
const
  CResearchPrefix = 'research/';
var
  LTrimmed: String;
  LNormalized: String;
begin
  LTrimmed := Trim(APeriod);
  Result := ParseFourDigitYear(LTrimmed, 1);
  if (Result > 0) and (Length(LTrimmed) > 4) and (LTrimmed[5] <> '-') then
    Result := 0;
  if Result > 0 then
    Exit;
  LNormalized := LowerCase(StringReplace(Trim(APath), '\', '/', [rfReplaceAll]));
  if Pos(CResearchPrefix, LNormalized) = 1 then
  begin
    Result := ParseFourDigitYear(LNormalized, Length(CResearchPrefix) + 1);
    if (Result > 0) and (Length(LNormalized) >= Length(CResearchPrefix) + 5) and
      (LNormalized[Length(CResearchPrefix) + 5] <> '-') then
      Result := 0;
  end;
end;

function SourceDocumentYear(const APath, APeriod: String): Integer;
begin
  Result := LeadingFilenameYear(APath);
  if Result = 0 then
    Result := PeriodStartYear(APath, APeriod);
end;

function SourceDocumentSortKey(const APath, APeriod: String): Integer;
var
  LExactYear: Integer;
  LPeriodYear: Integer;
  LYear: Integer;
  LHasExact: Integer;
begin
  LExactYear := LeadingFilenameYear(APath);
  LPeriodYear := PeriodStartYear(APath, APeriod);
  if LExactYear > 0 then
  begin
    LYear := LExactYear;
    LHasExact := 1;
  end
  else
  begin
    LYear := LPeriodYear;
    LHasExact := 0;
  end;
  Result := (LYear * 8192) + (LHasExact * 4096) + LPeriodYear;
end;

function CompareSourcesByYearDesc(const APathA, APeriodA, APathB, APeriodB: String): Integer;
var
  LKeyA: Integer;
  LKeyB: Integer;
begin
  LKeyA := SourceDocumentSortKey(APathA, APeriodA);
  LKeyB := SourceDocumentSortKey(APathB, APeriodB);
  if LKeyA > LKeyB then
    Exit(-1);
  if LKeyA < LKeyB then
    Exit(1);
  Result := CompareStr(APathA, APathB);
end;

function SelectSourcePage(const APaths: array of String; AKind,
  ARemaining: Integer): TSourceSelection;
var
  LIndex: Integer;
  LCount: Integer;
begin
  if ARemaining < 1 then
  begin
    raise EArgumentException.Create('The remaining page size must be positive.');
  end;
  if (AKind < SourceKindAll) or (AKind > SourceKindCulture) then
  begin
    raise EArgumentException.Create('Unknown source collection.');
  end;
  Result.Indices := nil;
  Result.Examined := 0;
  for LIndex := Low(APaths) to High(APaths) do
  begin
    Inc(Result.Examined);
    if MatchesSourceKind(APaths[LIndex], AKind) then
    begin
      LCount := Length(Result.Indices);
      SetLength(Result.Indices, LCount + 1);
      Result.Indices[LCount] := LIndex;
      if Length(Result.Indices) = ARemaining then
      begin
        Break;
      end;
    end;
  end;
end;

end.
