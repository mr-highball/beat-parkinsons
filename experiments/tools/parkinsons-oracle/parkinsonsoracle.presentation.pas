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
