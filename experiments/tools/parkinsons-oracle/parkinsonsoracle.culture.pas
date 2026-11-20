{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.culture;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses fpjson;

function CulturalMetadata(const APath, AText: String): TJSONObject;
function HasCulturalTopic(ATopics: TJSONArray; const AValue: String): Boolean;

implementation

uses Classes, SysUtils, StrUtils, parkinsonsoracle.presentation;

function HasCulturalTopic(ATopics: TJSONArray; const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  if (ATopics <> nil) and (AValue <> '') then
    for LIndex := 0 to ATopics.Count - 1 do
      if ATopics.Strings[LIndex] = AValue then
        Exit(True);
  Result := False;
end;

function SourceAddress(const AValue: String): String;
var
  LStart: Integer;
  LEnd: Integer;
  LValue: String;
begin
  LValue := LowerCase(AValue);
  LStart := Pos('https://', LValue);
  if LStart = 0 then
    LStart := Pos('http://', LValue);
  if LStart = 0 then
    Exit('');
  LEnd := LStart;
  while (LEnd <= Length(AValue)) and
    not CharInSet(AValue[LEnd], [#9, #13, #10, ' ', '<', '>', '"', '''', ']']) do
    Inc(LEnd);
  while (LEnd > LStart) and CharInSet(AValue[LEnd - 1], ['.', ',', ';']) do
    Dec(LEnd);
  Result := Copy(AValue, LStart, LEnd - LStart);
end;

function CulturalMetadata(const APath, AText: String): TJSONObject;
var
  LLines: TStringList;
  LLine: String;
  LField: String;
  LValue: String;
  LSummary: String;
  LExposure: String;
  LSplit: Integer;
  LInHeader: Boolean;
  LSummaryComplete: Boolean;

  procedure AddField(const AKey, AValue: String);
  begin
    if (AValue <> '') and (Result.Find(AKey) = nil) then
      Result.Add(AKey, UTF8String(AValue));
  end;

begin
  LLines := TStringList.Create;
  Result := TJSONObject.Create;
  try
    try
      if IsConversationSource(APath) then
        Result.Add('collection', 'conversations')
      else
        Result.Add('collection', 'cultural');
      Result.Add('evidence_role', 'cultural_context');
      LLines.Text := AText;
      LInHeader := True;
      LSummaryComplete := False;
      LSummary := '';
      LExposure := '';
      for LLine in LLines do
      begin
        LValue := Trim(LLine);
        if LValue = '' then
        begin
          LInHeader := False;
          LSummaryComplete := LSummary <> '';
          Continue;
        end;
        LSplit := Pos(':', LValue);
        LField := '';
        if LSplit > 0 then
        begin
          LField := LowerCase(Trim(Copy(LValue, 1, LSplit - 1)));
          LValue := Trim(Copy(LValue, LSplit + 1, MaxInt));
        end;
        case IndexStr(LField, ['title', 'source kind', 'source', 'publication date',
          'date basis', 'reported direction', 'evidence and limits', 'efficacy evidence',
          'exposure', 'exposure and reported symptom', 'summary', 'capture date']) of
          0: if LInHeader then AddField('title', LValue);
          1: if LInHeader then AddField('source_kind', LValue);
          2: if LInHeader then AddField('source_url', SourceAddress(LValue));
          3: if LInHeader then AddField('publication_date', LValue);
          4: if LInHeader then AddField('date_basis', LValue);
          5: AddField('reported_direction', LValue);
          6, 7: AddField('evidence_limits', LValue);
          8, 9: if LExposure = '' then LExposure := LValue;
          10: AddField('summary', LValue);
          11: if LInHeader then AddField('capture_date', LValue);
        else
          if not LInHeader and not LSummaryComplete then
          begin
            if LSummary <> '' then
              LSummary := LSummary + ' ';
            LSummary := LSummary + Trim(LLine);
          end;
        end;
      end;
      if LSummary = '' then
        LSummary := LExposure;
      if Length(LSummary) > 720 then
      begin
        LSplit := 720;
        while (LSplit > 0) and (LSummary[LSplit] <> ' ') do
          Dec(LSplit);
        if LSplit > 0 then
          LSummary := Copy(LSummary, 1, LSplit - 1) + '...';
      end;
      AddField('summary', LSummary);
    except
      Result.Free;
      raise;
    end;
  finally
    LLines.Free;
  end;
end;

end.
