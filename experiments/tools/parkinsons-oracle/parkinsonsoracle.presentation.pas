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
