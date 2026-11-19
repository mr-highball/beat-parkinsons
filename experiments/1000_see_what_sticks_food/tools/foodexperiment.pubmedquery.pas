{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.pubmedquery;

{$mode delphi}
{$H+}

interface

function ValidProviderQueryId(const AValue: UTF8String): Boolean;
function MakePubMedQuery(const AExpression, AQueryId, AMeshHeadings: UTF8String): UTF8String;
function PubMedTranslationError(const AQuery, ATranslation: UTF8String): UTF8String;

implementation

uses
  SysUtils, foodexperiment.externaldata;

const
  EpmcDisease = '(TITLE_ABS:parkinson* OR TITLE_ABS:"shaking palsy" OR ' +
    'TITLE_ABS:"paralysis agitans")';
  PubMedDisease = '("Parkinson Disease"[mh] OR "Parkinsonian Disorders"[mh:noexp] OR ' +
    '"Parkinson Disease, Secondary"[mh:noexp] OR parkinson*[tiab] OR ' +
    '"shaking palsy"[tiab] OR "paralysis agitans"[tiab])';
  TitleField = 'TITLE_ABS:';
  AuthorField = 'AUTH:';
  TokenSeparators = [#9, #10, #13, ' ', '(', ')', '"', '[', ']'];

function ValidProviderQueryId(const AValue: UTF8String): Boolean;
var
  LIndex: Integer;
begin
  if (Length(AValue) < 4) or not (AValue[1] in ['E', 'R']) then
  begin
    Exit(False);
  end;
  for LIndex := 2 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9']) then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

procedure ReadPhrase(const AExpression, AQueryId: UTF8String; var AIndex: Integer);
begin
  Inc(AIndex);
  while AIndex <= Length(AExpression) do
  begin
    if AExpression[AIndex] = '"' then
    begin
      Inc(AIndex);
      Exit;
    end;
    if AExpression[AIndex] = '\' then
    begin
      Inc(AIndex);
    end;
    Inc(AIndex);
  end;
  raise EConvertError.Create('Unterminated PubMed input phrase for ' + AQueryId);
end;

function HasLiteralPubMedOperator(const AQuery, AOperator: UTF8String): Boolean;
var
  LTaggedOperator: UTF8String;
  LSeparator: Char;
begin
  LTaggedOperator := AOperator + '[';
  if (Pos('"' + AOperator + '"', AQuery) > 0) or
    (Copy(AQuery, 1, Length(LTaggedOperator)) = LTaggedOperator) then
  begin
    Exit(True);
  end;
  for LSeparator in TokenSeparators do
  begin
    if Pos(LSeparator + LTaggedOperator, AQuery) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function PubMedTranslationError(const AQuery, ATranslation: UTF8String): UTF8String;
var
  LQuery: UTF8String;
  LStart: Integer;
  LIndex: Integer;
  LTerm: UTF8String;
begin
  LQuery := UpperCase(AQuery);
  LIndex := 1;
  while LIndex <= Length(ATranslation) do
  begin
    if ATranslation[LIndex] <> '"' then
    begin
      Inc(LIndex);
      Continue;
    end;
    LStart := LIndex + 1;
    ReadPhrase(ATranslation, 'provider query translation', LIndex);
    if (LIndex <= Length(ATranslation)) and (ATranslation[LIndex] = '[') then
    begin
      LTerm := UpperCase(Trim(Copy(ATranslation, LStart, LIndex - LStart - 1)));
      if LTerm = '' then
      begin
        Exit('PubMed translated a search term to an empty field phrase');
      end;
      if ((LTerm = 'OR') or (LTerm = 'AND') or (LTerm = 'NOT')) and
        not HasLiteralPubMedOperator(LQuery, LTerm) then
      begin
        Exit('PubMed translated a Boolean operator to a literal search term: ' + LTerm);
      end;
    end;
  end;
  Result := '';
end;

function TranslateExpression(const AExpression, AQueryId: UTF8String;
  out ASingleGroup, ASimpleExposure: Boolean): UTF8String;
var
  LIndex: Integer;
  LStart: Integer;
  LDepth: Integer;
  LToken: UTF8String;
  LField: UTF8String;
  LTag: UTF8String;
  LExpectTerm: Boolean;
begin
  if AExpression = '' then
  begin
    raise EConvertError.Create('Empty PubMed input expression for ' + AQueryId);
  end;
  Result := '';
  ASingleGroup := AExpression[1] = '(';
  ASimpleExposure := True;
  LExpectTerm := True;
  LIndex := 1;
  LDepth := 0;
  while LIndex <= Length(AExpression) do
  begin
    LStart := LIndex;
    case AExpression[LIndex] of
      '(':
        begin
          Inc(LDepth);
          ASimpleExposure := ASimpleExposure and (LDepth = 1);
          Inc(LIndex);
        end;
      ')':
        begin
          Dec(LDepth);
          ASimpleExposure := ASimpleExposure and not LExpectTerm;
          if LDepth < 0 then
          begin
            raise EConvertError.Create('Unbalanced PubMed input groups for ' + AQueryId);
          end;
          if (LDepth = 0) and (LIndex < Length(AExpression)) then
          begin
            ASingleGroup := False;
          end;
          Inc(LIndex);
        end;
      '"':
        begin
          ASimpleExposure := False;
          ReadPhrase(AExpression, AQueryId, LIndex);
        end;
      '[':
        begin
          ASimpleExposure := False;
          Inc(LIndex);
          while (LIndex <= Length(AExpression)) and (AExpression[LIndex] <> ']') do
          begin
            Inc(LIndex);
          end;
          if LIndex > Length(AExpression) then
          begin
            raise EConvertError.Create('Unterminated PubMed input field for ' + AQueryId);
          end;
          Inc(LIndex);
        end;
      #9, #10, #13, ' ', ']':
        Inc(LIndex);
      else
        begin
          LField := '';
          if Copy(AExpression, LIndex, Length(TitleField)) = TitleField then
          begin
            LField := TitleField;
            LTag := '[tiab]';
          end
          else if Copy(AExpression, LIndex, Length(AuthorField)) = AuthorField then
          begin
            LField := AuthorField;
            LTag := '[au]';
          end;
          if LField <> '' then
          begin
            ASimpleExposure := ASimpleExposure and (LField = TitleField) and
              (LDepth = 1) and LExpectTerm;
            LExpectTerm := False;
            Inc(LIndex, Length(LField));
            LStart := LIndex;
            if (LIndex <= Length(AExpression)) and (AExpression[LIndex] = '"') then
            begin
              ReadPhrase(AExpression, AQueryId, LIndex);
            end
            else
            begin
              while (LIndex <= Length(AExpression)) and
                not (AExpression[LIndex] in TokenSeparators) do
              begin
                Inc(LIndex);
              end;
            end;
            if LIndex = LStart then
            begin
              raise EConvertError.Create('Empty Europe PMC term for ' + AQueryId);
            end;
            Result := Result + Copy(AExpression, LStart, LIndex - LStart) + LTag;
            Continue;
          end;
          while (LIndex <= Length(AExpression)) and
            not (AExpression[LIndex] in TokenSeparators) do
          begin
            Inc(LIndex);
          end;
          LToken := Copy(AExpression, LStart, LIndex - LStart);
          ASimpleExposure := ASimpleExposure and (LDepth = 1) and not LExpectTerm and
            SameText(LToken, 'OR');
          LExpectTerm := True;
        end;
    end;
    Result := Result + Copy(AExpression, LStart, LIndex - LStart);
  end;
  if LDepth <> 0 then
  begin
    raise EConvertError.Create('Unbalanced PubMed input groups for ' + AQueryId);
  end;
end;

function MakePubMedQuery(const AExpression, AQueryId, AMeshHeadings: UTF8String): UTF8String;
const
  LegacyPrefix = EpmcDisease + ' AND ';
var
  LExpression: UTF8String;
  LFirst: Integer;
  LLast: Integer;
  LExposure: UTF8String;
  LHeading: UTF8String;
  LSingleGroup: Boolean;
  LSimpleExposure: Boolean;
begin
  LFirst := 1;
  LLast := Length(AExpression);
  while (LFirst <= LLast) and (AExpression[LFirst] in [#9, #10, #13, ' ']) do
  begin
    Inc(LFirst);
  end;
  while (LLast >= LFirst) and (AExpression[LLast] in [#9, #10, #13, ' ']) do
  begin
    Dec(LLast);
  end;
  LExpression := Copy(AExpression, LFirst, LLast - LFirst + 1);
  if Copy(LExpression, 1, Length(LegacyPrefix)) = LegacyPrefix then
  begin
    LExposure := TranslateExpression(Copy(LExpression, Length(LegacyPrefix) + 1, MaxInt),
      AQueryId, LSingleGroup, LSimpleExposure);
    if LSingleGroup then
    begin
      // Only the generated, disjunctive exposure group can safely inherit a MeSH alias.
      if LSimpleExposure and (AMeshHeadings <> '') then
      begin
        SetLength(LExposure, Length(LExposure) - 1);
        for LHeading in SplitFields(AMeshHeadings, '|') do
        begin
          LExposure := LExposure + ' OR "' + LHeading + '"[mh:noexp]';
        end;
        LExposure := LExposure + ')';
      end;
      Exit(PubMedDisease + ' AND ' + LExposure);
    end;
  end;
  Result := TranslateExpression(LExpression, AQueryId, LSingleGroup, LSimpleExposure);
end;

end.
