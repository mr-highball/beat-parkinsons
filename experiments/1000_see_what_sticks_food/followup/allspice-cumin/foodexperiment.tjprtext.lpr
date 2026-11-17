{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperiment.TjprText;

{$mode objfpc}{$H+}{$codepage UTF8}

uses
  Classes, RegExpr, SysUtils;

const
  CStart = '<H4 id="l4" style=';
  CEnd = '<!-- Body of article ends -->';
  CLicense = 'creativecommons.org/licenses/by/4.0';
  CParagraph = #30;

procedure DecodeEntities(var AText: UTF8String);
begin
  AText := StringReplace(AText, '&nbsp;', ' ', [rfReplaceAll]);
  AText := StringReplace(AText, '&ndash;', '–', [rfReplaceAll]);
  AText := StringReplace(AText, '&mdash;', '—', [rfReplaceAll]);
  AText := StringReplace(AText, '&lsquo;', '‘', [rfReplaceAll]);
  AText := StringReplace(AText, '&rsquo;', '’', [rfReplaceAll]);
  AText := StringReplace(AText, '&ldquo;', '“', [rfReplaceAll]);
  AText := StringReplace(AText, '&rdquo;', '”', [rfReplaceAll]);
  AText := StringReplace(AText, '&#39;', '''', [rfReplaceAll]);
  AText := StringReplace(AText, '&#169;', '©', [rfReplaceAll]);
  AText := StringReplace(AText, '&quot;', '"', [rfReplaceAll]);
  AText := StringReplace(AText, '&plusmn;', '±', [rfReplaceAll]);
  AText := StringReplace(AText, '&times;', '×', [rfReplaceAll]);
  AText := StringReplace(AText, '&alpha;', 'α', [rfReplaceAll]);
  AText := StringReplace(AText, '&beta;', 'β', [rfReplaceAll]);
  AText := StringReplace(AText, '&deg;', '°', [rfReplaceAll]);
  AText := StringReplace(AText, '&micro;', 'µ', [rfReplaceAll]);
  AText := StringReplace(AText, '&mu;', 'μ', [rfReplaceAll]);
  AText := StringReplace(AText, '&lt;', '<', [rfReplaceAll]);
  AText := StringReplace(AText, '&gt;', '>', [rfReplaceAll]);
  AText := StringReplace(AText, '&amp;', '&', [rfReplaceAll]);
end;

procedure ExtractArticle(const AHtml, AOutput, ASourceHash: string);
var
  LSource, LOutput, LParagraphs: TStringList;
  LText, LParagraph: UTF8String;
  LStart, LEnd: SizeInt;
begin
  LSource := TStringList.Create;
  LOutput := TStringList.Create;
  LParagraphs := TStringList.Create;
  try
    LSource.LoadFromFile(AHtml, TEncoding.UTF8);
    LText := LSource.Text;
    LStart := Pos(CStart, LText);
    LEnd := Pos(CEnd, LText);
    if (LStart = 0) or (LEnd <= LStart) or (Pos(CLicense, LText) = 0) then
      raise EConvertError.Create('Expected the publisher article bounds and CC BY license');
    LText := Copy(LText, LStart, LEnd - LStart);
    LText := ReplaceRegExpr('<!--[\s\S]*?-->', LText, '', False);
    LText := ReplaceRegExpr('(?i)</(?:p|div|h4|li)>|<br\s*/?>', LText, CParagraph, False);
    LText := ReplaceRegExpr('<[^>]*>', LText, '', False);
    DecodeEntities(LText);
    LText := ReplaceRegExpr('[\t\r\n ]+', LText, ' ', False);
    if ExecRegExpr('&(?:#[0-9]+|[a-zA-Z][a-zA-Z0-9]+);', LText) then
      raise EConvertError.Create('The article contains an unmapped entity');
    LParagraphs.StrictDelimiter := True;
    LParagraphs.Delimiter := CParagraph;
    LParagraphs.QuoteChar := #0;
    LParagraphs.DelimitedText := LText;
    LOutput.Add('Cuminum cyminum Linn (Apiaceae) extract attenuates MPTP-induced oxidative stress and behavioral impairments in mouse model of Parkinson disease');
    LOutput.Add('Jong-Bo Kim, Spandana Rajendra Kopalli and Sushruta Koppula.');
    LOutput.Add('Tropical Journal of Pharmaceutical Research 15(4), 765–772. Published April 30, 2016.');
    LOutput.Add('DOI: 10.4314/tjpr.v15i4.14');
    LOutput.Add('Source: https://tjpr.org/home/abstract.php?id=437');
    LOutput.Add('Publisher HTML SHA-256: ' + ASourceHash);
    LOutput.Add('License: CC BY 4.0, per the publisher HTML. https://creativecommons.org/licenses/by/4.0/');
    LOutput.Add('Scope: Publisher article text, including abstract, main text and references. Layout and figure images are omitted.');
    LOutput.Add('Original figures: https://www.ajol.info/index.php/tjpr/article/download/135164/124657');
    LOutput.Add('');
    for LParagraph in LParagraphs do
    begin
      if Trim(LParagraph) <> '' then
        LOutput.Add(Trim(LParagraph));
    end;
    LOutput.SaveToFile(AOutput, TEncoding.UTF8);
  finally
    LParagraphs.Free;
    LOutput.Free;
    LSource.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  if ParamCount <> 3 then
    raise EArgumentException.Create('Usage: foodexperiment.tjprtext ARTICLE_HTML OUTPUT_TXT SOURCE_SHA256');
  ExtractArticle(ParamStr(1), ParamStr(2), ParamStr(3));
end.
