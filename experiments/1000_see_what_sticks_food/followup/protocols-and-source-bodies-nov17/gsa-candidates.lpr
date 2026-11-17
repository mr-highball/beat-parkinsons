{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program GsaBodyCandidates;

{$mode delphi}
{$H+}

uses Classes, SysUtils, StrUtils, foodexperiment.externaldata;

const
  CPageMarker = '# Page ';
  CExpectedPages = 1112;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise EConvertError.Create(AMessage);
end;

function SearchWords(const AText: String): String;
var
  LChar: Char;
  LWordStart: Boolean;
  LLength: SizeInt;
begin
  SetLength(Result, Length(AText) + 2);
  LLength := 1;
  Result[LLength] := ' ';
  LWordStart := True;
  for LChar in AText do
    if LChar in ['a'..'z', 'A'..'Z', '0'..'9'] then
    begin
      Inc(LLength);
      Result[LLength] := LowerCase(LChar);
      LWordStart := False;
    end
    else if not LWordStart then
    begin
      Inc(LLength);
      Result[LLength] := ' ';
      LWordStart := True;
    end;
  if not LWordStart then
  begin
    Inc(LLength);
    Result[LLength] := ' ';
  end;
  SetLength(Result, LLength);
end;

procedure RecordPage(const APage: String; APageNumber: Integer;
  AAliases, AOutput: TStrings);
var
  LScope, LTerm: String;
  LFields: TFields;
  LAlias: Integer;
begin
  LScope := SearchWords(APage);
  for LAlias := 1 to AAliases.Count - 1 do
  begin
    LFields := SplitFields(AAliases[LAlias], #9);
    Require(Length(LFields) = 2, 'Bad alias record');
    LTerm := SearchWords(LFields[1]);
    Require(LTerm <> ' ', 'Empty matching term');
    if Pos(LTerm, LScope) > 0 then
      AOutput.Add(LFields[0] + #9 + LFields[1] + #9 + IntToStr(APageNumber));
  end;
end;

procedure Scan(const ABook, AAliasFile, ATarget: String);
var
  LAliases, LBook, LOutput: TStringList;
  LIndex, LPage, LNewPage: Integer;
  LBuffer, LText: String;
begin
  LAliases := TStringList.Create;
  LBook := TStringList.Create;
  LOutput := TStringList.Create;
  try
    LAliases.LoadFromFile(AAliasFile, TEncoding.UTF8);
    LBook.LoadFromFile(ABook, TEncoding.UTF8);
    Require(LAliases[0] = 'ingredient'#9'alias', 'Alias columns differ');
    LOutput.Add('ingredient'#9'alias'#9'pdf_page');
    LPage := 0;
    LBuffer := '';
    for LIndex := 0 to LBook.Count - 1 do
    begin
      LText := Trim(LBook[LIndex]);
      if StartsStr(CPageMarker, LText) then
      begin
        LNewPage := StrToInt(Copy(LText, Length(CPageMarker) + 1));
        Require(LNewPage = LPage + 1, 'Unexpected page number ' + LText);
        if LPage > 0 then
          RecordPage(LBuffer, LPage, LAliases, LOutput);
        LPage := LNewPage;
        LBuffer := '';
      end
      else if LText <> '' then
        LBuffer := LBuffer + ' ' + LText;
    end;
    Require(LPage = CExpectedPages, 'Incomplete book extraction');
    RecordPage(LBuffer, LPage, LAliases, LOutput);
    LOutput.LineBreak := #10;
    LOutput.SaveToFile(ATarget, TEncoding.UTF8);
    WriteLn('Scanned ', LPage, ' PDF pages using ', LAliases.Count - 1,
      ' ingredient terms. Recorded ', LOutput.Count - 1, ' term-page memberships.');
  finally
    LOutput.Free;
    LBook.Free;
    LAliases.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Require(ParamCount = 3, 'Pass extracted book text, alias list and candidate output');
  Scan(ParamStr(1), ParamStr(2), ParamStr(3));
end.
