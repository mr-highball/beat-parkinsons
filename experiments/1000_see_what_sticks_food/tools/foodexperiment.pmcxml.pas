{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.pmcxml;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils;

type
  TPmcScreenKind = (
    pkNoBody,
    pkPmidMismatch,
    pkCollectionHold,
    pkZeroBodyCollision,
    pkBodyMatch
  );

  TPmcScreenResult = record
    Kind: TPmcScreenKind;
    XmlPmid: String;
    ArticleTitle: String;
    BodyChars: Integer;
    TitleAbsHits: Integer;
    BodyHits: Integer;
    MetaBackHits: Integer;
    MatchedTerms: String;
    BodySnippet: String;
    MetaBackSnippet: String;
  end;

function PmcScreenKindName(AKind: TPmcScreenKind): String;
function ExtractXmlPmid(const AXml: String): String;
function ExtractArticleTitle(const AXml: String): String;
function StripXmlTags(const AXml: String): String;
function IngredientTermsFor(const AIngredient: String): TArray<String>;
function ScreenPmcJatsXml(const AXml, AExpectedPmid, AIngredient: String): TPmcScreenResult;
function ScreenPmcReaderHtml(const AHtml, AExpectedPmcid, AExpectedPmid,
  AExpectedDoi, AIngredient: String): TPmcScreenResult;

implementation

uses
  StrUtils;

function PmcScreenKindName(AKind: TPmcScreenKind): String;
begin
  case AKind of
    pkNoBody: Result := 'no_body';
    pkPmidMismatch: Result := 'pmid_mismatch';
    pkCollectionHold: Result := 'collection_hold';
    pkZeroBodyCollision: Result := 'zero_body_collision';
    pkBodyMatch: Result := 'body_match';
  end;
end;

function IsWordChar(AChar: Char): Boolean; inline;
begin
  Result := AChar in ['a'..'z', 'A'..'Z', '0'..'9'];
end;

function CollapseSpaces(const AText: String): String;
var
  I: Integer;
  LInSpace: Boolean;
  LOut: TStringBuilder;
  LCh: Char;
begin
  LOut := TStringBuilder.Create(Length(AText));
  try
    LInSpace := True;
    for I := 1 to Length(AText) do
    begin
      LCh := AText[I];
      if LCh in [' ', #9, #10, #13] then
      begin
        if not LInSpace then
        begin
          LOut.Append(' ');
          LInSpace := True;
        end;
      end
      else
      begin
        LOut.Append(LCh);
        LInSpace := False;
      end;
    end;
    Result := Trim(LOut.ToString);
  finally
    LOut.Free;
  end;
end;

function DecodeBasicEntities(const AText: String): String;
begin
  Result := StringReplace(AText, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&#x000a0;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&#160;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll]);
end;

function StripXmlTags(const AXml: String): String;
var
  I: Integer;
  LInTag: Boolean;
  LOut: TStringBuilder;
  LCh: Char;
begin
  LOut := TStringBuilder.Create(Length(AXml));
  try
    LInTag := False;
    for I := 1 to Length(AXml) do
    begin
      LCh := AXml[I];
      if LCh = '<' then
      begin
        if not LInTag then
        begin
          LOut.Append(' ');
        end;
        LInTag := True;
      end
      else if LCh = '>' then
      begin
        LInTag := False;
      end
      else if not LInTag then
      begin
        LOut.Append(LCh);
      end;
    end;
    Result := CollapseSpaces(DecodeBasicEntities(LOut.ToString));
  finally
    LOut.Free;
  end;
end;

function FindTagInner(const AXml, ATagName: String; AStartPos: Integer;
  out AInner: String; out ANextPos: Integer): Boolean;
var
  LOpenPos, LTagEnd, LClosePos: Integer;
  LOpenPrefix, LCloseTag: String;
  LNextCh: Char;
begin
  Result := False;
  AInner := '';
  ANextPos := 0;
  LOpenPrefix := '<' + ATagName;
  LCloseTag := '</' + ATagName + '>';
  LOpenPos := PosEx(LOpenPrefix, AXml, AStartPos);
  while LOpenPos > 0 do
  begin
    if LOpenPos + Length(LOpenPrefix) <= Length(AXml) then
    begin
      LNextCh := AXml[LOpenPos + Length(LOpenPrefix)];
      if (LNextCh = '>') or (LNextCh = ' ') or (LNextCh = #9) or (LNextCh = #10) or (LNextCh = #13) then
      begin
        LTagEnd := PosEx('>', AXml, LOpenPos + Length(LOpenPrefix));
        if LTagEnd = 0 then
        begin
          Exit;
        end;
        if (LTagEnd > 1) and (AXml[LTagEnd - 1] = '/') then
        begin
          { Self-closing empty tag }
          LOpenPos := PosEx(LOpenPrefix, AXml, LTagEnd + 1);
          Continue;
        end;
        LClosePos := PosEx(LCloseTag, AXml, LTagEnd + 1);
        if LClosePos = 0 then
        begin
          Exit;
        end;
        AInner := Copy(AXml, LTagEnd + 1, LClosePos - LTagEnd - 1);
        ANextPos := LClosePos + Length(LCloseTag);
        Exit(True);
      end;
    end;
    LOpenPos := PosEx(LOpenPrefix, AXml, LOpenPos + 1);
  end;
end;

function ExtractXmlPmid(const AXml: String): String;
var
  LFront, LMarker, LVal: String;
  LNext, LPos, LTagEnd, LClose: Integer;
begin
  Result := '';
  if not FindTagInner(AXml, 'article-meta', 1, LFront, LNext) then
  begin
    LFront := Copy(AXml, 1, 8000);
  end;
  LMarker := 'pub-id-type="pmid"';
  LPos := Pos(LMarker, LFront);
  if LPos = 0 then
  begin
    LMarker := 'pub-id-type=''pmid''';
    LPos := Pos(LMarker, LFront);
  end;
  if LPos = 0 then
  begin
    Exit;
  end;
  LTagEnd := PosEx('>', LFront, LPos);
  if LTagEnd = 0 then
  begin
    Exit;
  end;
  LClose := PosEx('</article-id>', LFront, LTagEnd + 1);
  if LClose = 0 then
  begin
    Exit;
  end;
  LVal := Trim(Copy(LFront, LTagEnd + 1, LClose - LTagEnd - 1));
  Result := LVal;
end;

function ExtractArticleTitle(const AXml: String): String;
var
  LMeta, LTitle: String;
  LNext: Integer;
begin
  Result := '';
  if FindTagInner(AXml, 'article-meta', 1, LMeta, LNext) then
  begin
    if FindTagInner(LMeta, 'article-title', 1, LTitle, LNext) then
    begin
      Result := StripXmlTags(LTitle);
    end;
  end
  else if FindTagInner(AXml, 'article-title', 1, LTitle, LNext) then
  begin
    Result := StripXmlTags(LTitle);
  end;
end;

function IsCollectionXml(const AXml, ATitle: String): Boolean;
var
  LLowerTitle: String;
  LFirstPos, LSecondPos: Integer;
begin
  LLowerTitle := LowerCase(Trim(ATitle));
  if (LLowerTitle = 'posters') or (LLowerTitle = 'abstracts') or
    (LLowerTitle = 'oral presentations') or (LLowerTitle = 'poster presentations') or
    (LLowerTitle = 'poster abstracts') or (LLowerTitle = 'late-breaking abstracts') or
    StartsStr('abstracts of ', LLowerTitle) or StartsStr('proceedings of ', LLowerTitle) then
  begin
    Exit(True);
  end;
  { Multiple sub-articles typically indicate conference proceedings or multi-commentary bundles }
  LFirstPos := Pos('<sub-article', AXml);
  if LFirstPos > 0 then
  begin
    LSecondPos := PosEx('<sub-article', AXml, LFirstPos + 12);
    if LSecondPos > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function AddTerms(const ABase: array of String): TArray<String>;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ABase));
  for I := 0 to High(ABase) do
  begin
    Result[I] := LowerCase(ABase[I]);
  end;
end;

function IngredientTermsFor(const AIngredient: String): TArray<String>;
var
  LKey: String;
begin
  LKey := LowerCase(Trim(AIngredient));
  if LKey = 'turmeric' then
    Exit(AddTerms(['turmeric', 'curcuma', 'curcumin', 'curcuminoid', 'demethoxycurcumin', 'bisdemethoxycurcumin']))
  else if LKey = 'coffee' then
    Exit(AddTerms(['coffee', 'coffea', 'caffeine', 'chlorogenic acid']))
  else if LKey = 'cinnamon' then
    Exit(AddTerms(['cinnamon', 'cinnamomum', 'cinnamaldehyde', 'cinnamic']))
  else if LKey = 'olive oil' then
    Exit(AddTerms(['olive oil', 'olive', 'olea europaea', 'oleuropein', 'oleocanthal', 'hydroxytyrosol', 'evoo']))
  else if LKey = 'saffron' then
    Exit(AddTerms(['saffron', 'crocus sativus', 'crocin', 'crocetin', 'safranal', 'picrocrocin']))
  else if LKey = 'grape' then
    Exit(AddTerms(['grape', 'grapes', 'vitis vinifera', 'resveratrol', 'proanthocyanidin']))
  else if LKey = 'grapeseed oil' then
    Exit(AddTerms(['grapeseed oil', 'grape seed oil', 'grape-seed oil']))
  else if LKey = 'green beans' then
    Exit(AddTerms(['green bean', 'green beans', 'string bean', 'string beans', 'snap bean',
      'snap beans', 'French beans']))
  else if LKey = 'corn oil' then
    Exit(AddTerms(['corn oil', 'maize oil', 'zea mays']))
  else if LKey = 'salmon' then
    Exit(AddTerms(['salmon', 'salmo salar', 'oncorhynchus']))
  else if LKey = 'ginger' then
    Exit(AddTerms(['ginger', 'zingiber', 'gingerol', 'shogaol', 'zingerone', 'paradol']))
  else if LKey = 'lemon balm' then
    Exit(AddTerms(['lemon balm', 'melissa officinalis', 'melissa']))
  else if LKey = 'sesame oil' then
    Exit(AddTerms(['sesame oil', 'sesame', 'sesamum', 'sesamin', 'sesamol', 'sesamolin']))
  else if LKey = 'rosemary' then
    Exit(AddTerms(['rosemary', 'rosmarinus', 'salvia rosmarinus', 'rosmarinic acid', 'carnosic acid', 'carnosol']))
  else if LKey = 'clove' then
    Exit(AddTerms(['clove', 'cloves', 'syzygium aromaticum', 'eugenia caryophyllata', 'eugenol']))
  else if LKey = 'egg' then
    Exit(AddTerms(['egg', 'eggs', 'yolk', 'ovalbumin']))
  else if LKey = 'chicken' then
    Exit(AddTerms(['chicken', 'chickens', 'poultry', 'gallus']))
  else if LKey = 'black pepper' then
    Exit(AddTerms(['black pepper', 'piper nigrum', 'piperine']))
  else if LKey = 'mango' then
    Exit(AddTerms(['mango', 'mangoes', 'mangifera', 'mangiferin']))
  else if LKey = 'turkey' then
    Exit(AddTerms(['turkey', 'meleagris']))
  else if LKey = 'trout' then
    Exit(AddTerms(['trout', 'oncorhynchus mykiss', 'salmo trutta']))
  else if LKey = 'sunflower oil' then
    Exit(AddTerms(['sunflower oil', 'sunflower', 'helianthus annuus']))
  else if LKey = 'flaxseed oil' then
    Exit(AddTerms(['flaxseed oil', 'flaxseed', 'linseed', 'linum usitatissimum', 'flax']))
  else if LKey = 'walnut oil' then
    Exit(AddTerms(['walnut oil', 'walnut', 'walnuts', 'juglans']))
  else if LKey = 'soybean oil' then
    Exit(AddTerms(['soybean oil', 'soybean', 'soybeans', 'glycine max', 'soy oil']))
  else if LKey = 'peanut oil' then
    Exit(AddTerms(['peanut oil', 'peanut', 'peanuts', 'arachis hypogaea']))
  else if LKey = 'coconut oil' then
    Exit(AddTerms(['coconut oil', 'coconut', 'cocos nucifera']))
  else if LKey = 'pumpkin seed oil' then
    Exit(AddTerms(['pumpkin seed oil', 'pumpkin seed', 'cucurbita']))
  else if LKey = 'safflower oil' then
    Exit(AddTerms(['safflower oil', 'safflower', 'carthamus tinctorius']))
  else if LKey = 'black tea' then
    Exit(AddTerms(['black tea', 'camellia sinensis', 'theaflavin', 'thearubigin', 'tea']))
  else if LKey = 'green tea' then
    Exit(AddTerms(['green tea', 'camellia sinensis', 'egcg', 'epigallocatechin', 'catechin', 'theanine', 'tea']))
  else if LKey = 'dark chocolate' then
    Exit(AddTerms(['dark chocolate', 'chocolate', 'cocoa', 'cacao', 'theobroma', 'theobromine']))
  else if LKey = 'broccoli' then
    Exit(AddTerms(['broccoli', 'brassica oleracea', 'sulforaphane', 'glucoraphanin']))
  else if LKey = 'blueberry' then
    Exit(AddTerms(['blueberry', 'blueberries', 'vaccinium', 'pterostilbene']))
  else if LKey = 'strawberry' then
    Exit(AddTerms(['strawberry', 'strawberries', 'fragaria']))
  else if LKey = 'raspberry' then
    Exit(AddTerms(['raspberry', 'raspberries', 'rubus']))
  else if LKey = 'blackberry' then
    Exit(AddTerms(['blackberry', 'blackberries', 'rubus']))
  else if LKey = 'cranberry' then
    Exit(AddTerms(['cranberry', 'cranberries', 'vaccinium macrocarpon']))
  else if LKey = 'cherry' then
    Exit(AddTerms(['cherry', 'cherries', 'prunus cerasus', 'prunus avium']))
  else if LKey = 'banana' then
    Exit(AddTerms(['banana', 'bananas', 'musa']))
  else if LKey = 'apple' then
    Exit(AddTerms(['apple', 'apples', 'malus domestica']))
  else if LKey = 'tomato' then
    Exit(AddTerms(['tomato', 'tomatoes', 'solanum lycopersicum', 'lycopene']))
  else if LKey = 'potato' then
    Exit(AddTerms(['potato', 'potatoes', 'solanum tuberosum']))
  else if LKey = 'carrot' then
    Exit(AddTerms(['carrot', 'carrots', 'daucus carota']))
  else if LKey = 'onion' then
    Exit(AddTerms(['onion', 'onions', 'allium cepa']))
  else if LKey = 'kale' then
    Exit(AddTerms(['kale', 'brassica oleracea']))
  else if LKey = 'oats' then
    Exit(AddTerms(['oats', 'oat', 'oatmeal', 'avena sativa', 'avenanthramide']))
  else if LKey = 'barley' then
    Exit(AddTerms(['barley', 'hordeum vulgare']))
  else if LKey = 'brown rice' then
    Exit(AddTerms(['brown rice', 'rice', 'oryza sativa']))
  else if LKey = 'kefir' then
    Exit(AddTerms(['kefir']))
  else if LKey = 'lentils' then
    Exit(AddTerms(['lentil', 'lentils', 'lens culinaris']))
  else if LKey = 'nigella seed' then
    Exit(AddTerms(['nigella', 'black seed', 'black cumin', 'thymoquinone']))
  else if LKey = 'thyme' then
    Exit(AddTerms(['thyme', 'thymus vulgaris', 'thymol', 'carvacrol']))
  else if LKey = 'basil' then
    Exit(AddTerms(['basil', 'ocimum']))
  else if LKey = 'cumin' then
    Exit(AddTerms(['cumin', 'cuminum cyminum', 'cuminaldehyde']))
  else if LKey = 'fennel seed' then
    Exit(AddTerms(['fennel', 'foeniculum vulgare', 'anethole']))
  else if LKey = 'anise seed' then
    Exit(AddTerms(['anise', 'pimpinella anisum', 'anethole']))
  else if LKey = 'celery leaf' then
    Exit(AddTerms(['celery', 'apium graveolens', 'apigenin', 'luteolin', 'butylphthalide']))
  else if LKey = 'celery stalk' then
    Exit(AddTerms(['celery', 'apium graveolens', 'apigenin', 'luteolin', 'butylphthalide']))
  else if LKey = 'cilantro' then
    Exit(AddTerms(['cilantro', 'coriander', 'coriandrum sativum']))
  else if LKey = 'spearmint' then
    Exit(AddTerms(['spearmint', 'mentha spicata', 'carvone']))
  else if LKey = 'lemongrass' then
    Exit(AddTerms(['lemongrass', 'cymbopogon', 'citral']))
  else if LKey = 'chives' then
    Exit(AddTerms(['chive', 'chives', 'allium schoenoprasum']))
  else if LKey = 'watermelon' then
    Exit(AddTerms(['watermelon', 'citrullus lanatus', 'citrulline']))
  else if LKey = 'cantaloupe' then
    Exit(AddTerms(['cantaloupe', 'cucumis melo']))
  else if LKey = 'peach' then
    Exit(AddTerms(['peach', 'peaches', 'prunus persica']))
  else if LKey = 'apricot' then
    Exit(AddTerms(['apricot', 'apricots', 'prunus armeniaca']))
  else if LKey = 'kiwi fruit' then
    Exit(AddTerms(['kiwi', 'kiwifruit', 'actinidia']))
  else if LKey = 'grapefruit' then
    Exit(AddTerms(['grapefruit', 'citrus paradisi', 'naringin', 'naringenin']))
  else if LKey = 'summer savory' then
    Exit(AddTerms(['summer savory', 'savory', 'satureja']))
  else if LKey = 'cardamom' then
    Exit(AddTerms(['cardamom', 'elettaria cardamomum']))
  else if LKey = 'nutmeg' then
    Exit(AddTerms(['nutmeg', 'myristica fragrans', 'myristicin']))
  else if LKey = 'oregano' then
    Exit(AddTerms(['oregano', 'origanum vulgare', 'carvacrol']))
  else if LKey = 'paprika' then
    Exit(AddTerms(['paprika', 'capsicum annuum']))
  else if LKey = 'tarragon' then
    Exit(AddTerms(['tarragon', 'artemisia dracunculus']))
  else if LKey = 'chervil' then
    Exit(AddTerms(['chervil', 'anthriscus cerefolium']))
  else if LKey = 'lovage' then
    Exit(AddTerms(['lovage', 'levisticum officinale']))
  else if LKey = 'marjoram' then
    Exit(AddTerms(['marjoram', 'origanum majorana']))
  else if LKey = 'parsley' then
    Exit(AddTerms(['parsley', 'petroselinum crispum']))
  else if LKey = 'mustard seed' then
    Exit(AddTerms(['mustard', 'sinapis', 'brassica juncea', 'brassica nigra']))
  else if LKey = 'date' then
    Exit(AddTerms(['date', 'dates', 'phoenix dactylifera']))
  else if LKey = 'fig' then
    Exit(AddTerms(['fig', 'figs', 'ficus carica']))
  else if LKey = 'sage' then
    Exit(AddTerms(['sage', 'salvia officinalis', 'salvia']))
  else if LKey = 'orange' then
    Exit(AddTerms(['orange', 'oranges', 'citrus sinensis', 'hesperidin', 'hesperetin']))
  else
    Exit(AddTerms([LKey]));
end;

function CountTermMatches(const AText: String; const ATerms: TArray<String>;
  out AMatchedList, AFirstSnippet: String): Integer;
var
  LLower: String;
  LTerm: String;
  LPos, LTermLen, LStart, LLen: Integer;
  LBeforeOk, LAfterOk: Boolean;
  LMatched: TStringList;
begin
  Result := 0;
  AMatchedList := '';
  AFirstSnippet := '';
  if AText = '' then
  begin
    Exit;
  end;
  LLower := LowerCase(AText);
  LMatched := TStringList.Create;
  try
    LMatched.Sorted := True;
    LMatched.Duplicates := dupIgnore;
    for LTerm in ATerms do
    begin
      if LTerm = '' then
      begin
        Continue;
      end;
      LTermLen := Length(LTerm);
      LPos := PosEx(LTerm, LLower, 1);
      while LPos > 0 do
      begin
        LBeforeOk := (LPos = 1) or (not IsWordChar(LLower[LPos - 1]));
        LAfterOk := (LPos + LTermLen > Length(LLower)) or
          (not IsWordChar(LLower[LPos + LTermLen]));
        if LBeforeOk and LAfterOk then
        begin
          Inc(Result);
          LMatched.Add(LTerm);
          if AFirstSnippet = '' then
          begin
            LStart := LPos - 90;
            if LStart < 1 then
            begin
              LStart := 1;
            end;
            LLen := 220;
            if LStart + LLen - 1 > Length(AText) then
            begin
              LLen := Length(AText) - LStart + 1;
            end;
            AFirstSnippet := StringReplace(Copy(AText, LStart, LLen), #9, ' ', [rfReplaceAll]);
          end;
        end;
        LPos := PosEx(LTerm, LLower, LPos + LTermLen);
      end;
    end;
    for LPos := 0 to LMatched.Count - 1 do
    begin
      if LPos > 0 then
      begin
        AMatchedList := AMatchedList + '|';
      end;
      AMatchedList := AMatchedList + LMatched[LPos];
    end;
  finally
    LMatched.Free;
  end;
end;

function ScreenPmcJatsXml(const AXml, AExpectedPmid, AIngredient: String): TPmcScreenResult;
var
  LExpected, LBodyXml, LTitleAbsText, LBodyText, LMetaBackText: String;
  LFrontXml, LAbsXml, LBackXml: String;
  LNext: Integer;
  LTerms: TArray<String>;
  LMatchedTitleAbs, LMatchedBody, LMatchedMeta: String;
  LSnipTitleAbs, LSnipBody, LSnipMeta: String;
begin
  Result := Default(TPmcScreenResult);
  Result.XmlPmid := ExtractXmlPmid(AXml);
  Result.ArticleTitle := ExtractArticleTitle(AXml);

  LExpected := Trim(AExpectedPmid);
  if StartsText('PMID:', LExpected) then
  begin
    LExpected := Trim(Copy(LExpected, 6, MaxInt));
  end;
  if (LExpected <> '') and (Result.XmlPmid <> '') and (LExpected <> Result.XmlPmid) then
  begin
    Result.Kind := pkPmidMismatch;
    Exit;
  end;

  if IsCollectionXml(AXml, Result.ArticleTitle) then
  begin
    Result.Kind := pkCollectionHold;
    Exit;
  end;

  if not FindTagInner(AXml, 'body', 1, LBodyXml, LNext) then
  begin
    Result.Kind := pkNoBody;
    Exit;
  end;
  LBodyText := StripXmlTags(LBodyXml);
  Result.BodyChars := Length(LBodyText);
  if Result.BodyChars < 400 then
  begin
    Result.Kind := pkNoBody;
    Exit;
  end;

  LTitleAbsText := Result.ArticleTitle;
  if FindTagInner(AXml, 'front', 1, LFrontXml, LNext) then
  begin
    if FindTagInner(LFrontXml, 'abstract', 1, LAbsXml, LNext) then
    begin
      LTitleAbsText := LTitleAbsText + ' ' + StripXmlTags(LAbsXml);
    end;
  end
  else
  begin
    LFrontXml := '';
  end;

  if not FindTagInner(AXml, 'back', 1, LBackXml, LNext) then
  begin
    LBackXml := '';
  end;
  LMetaBackText := StripXmlTags(LFrontXml) + ' ' + StripXmlTags(LBackXml);

  LTerms := IngredientTermsFor(AIngredient);
  Result.TitleAbsHits := CountTermMatches(LTitleAbsText, LTerms, LMatchedTitleAbs, LSnipTitleAbs);
  Result.BodyHits := CountTermMatches(LBodyText, LTerms, LMatchedBody, LSnipBody);
  Result.MetaBackHits := CountTermMatches(LMetaBackText, LTerms, LMatchedMeta, LSnipMeta);

  if (Result.TitleAbsHits = 0) and (Result.BodyHits = 0) then
  begin
    Result.Kind := pkZeroBodyCollision;
    Result.MatchedTerms := LMatchedMeta;
    Result.MetaBackSnippet := LSnipMeta;
  end
  else
  begin
    Result.Kind := pkBodyMatch;
    if LMatchedBody <> '' then
    begin
      Result.MatchedTerms := LMatchedBody;
    end
    else
    begin
      Result.MatchedTerms := LMatchedTitleAbs;
    end;
    if LSnipBody <> '' then
    begin
      Result.BodySnippet := LSnipBody;
    end
    else
    begin
      Result.BodySnippet := LSnipTitleAbs;
    end;
  end;
end;

function ReaderMeta(const AHead, AName: String): String;
var
  LPrefix: String;
  LStart, LEnd: Integer;
begin
  Result := '';
  LPrefix := '<meta name="' + AName + '" content="';
  LStart := Pos(LPrefix, AHead);
  if LStart = 0 then
    Exit;
  Inc(LStart, Length(LPrefix));
  LEnd := PosEx('"', AHead, LStart);
  if LEnd > LStart then
    Result := Copy(AHead, LStart, LEnd - LStart);
end;

function ScreenPmcReaderHtml(const AHtml, AExpectedPmcid, AExpectedPmid,
  AExpectedDoi, AIngredient: String): TPmcScreenResult;
const
  CBodyStart = '<section class="body main-article-body">';
  CArticleUrl = 'https://pmc.ncbi.nlm.nih.gov/articles/';
var
  LHead, LArticle, LTitle, LPmid, LFront, LBack, LScreenInput: String;
  LArticleStart, LNext, LBodyStart, LRefs: Integer;
begin
  Result := Default(TPmcScreenResult);
  LArticleStart := Pos('<article lang="en">', AHtml);
  if LArticleStart = 0 then
    Exit;
  if not FindTagInner(AHtml, 'article', LArticleStart, LArticle, LNext) then
    Exit;
  if Pos('<article', LArticle) > 0 then
  begin
    Result.Kind := pkCollectionHold;
    Exit;
  end;

  LHead := Copy(AHtml, 1, LArticleStart - 1);
  LPmid := ReaderMeta(LHead, 'citation_pmid');
  Result.XmlPmid := LPmid;
  if (AExpectedPmcid = '') or (AExpectedPmid = '') or
     (LPmid <> AExpectedPmid) or not SameText(ReaderMeta(LHead, 'citation_abstract_html_url'),
       CArticleUrl + AExpectedPmcid + '/') or
     ((AExpectedDoi <> '') and not SameText(ReaderMeta(LHead, 'citation_doi'), AExpectedDoi)) then
  begin
    Result.Kind := pkPmidMismatch;
    Exit;
  end;

  LTitle := ReaderMeta(LHead, 'citation_title');
  if LTitle = '' then
    Exit;
  LBodyStart := Pos(CBodyStart, LArticle);
  if LBodyStart = 0 then
    Exit;
  LFront := Copy(LArticle, 1, LBodyStart - 1);
  LArticle := Copy(LArticle, LBodyStart + Length(CBodyStart), MaxInt);
  if Pos('<p', LArticle) = 0 then
    Exit;
  LRefs := Pos('class="ref-list"', LArticle);
  LBack := '';
  if LRefs > 0 then
  begin
    LRefs := RPos('<section', Copy(LArticle, 1, LRefs - 1));
    if LRefs > 0 then
    begin
      LBack := Copy(LArticle, LRefs, MaxInt);
      SetLength(LArticle, LRefs - 1);
    end;
  end;

  { This structure supplies the common term matcher. The saved HTML remains the original. }
  LScreenInput := '<article><front><article-meta><article-id pub-id-type="pmid">' +
    LPmid + '</article-id><article-title>' + LTitle + '</article-title>' +
    '<abstract>' + ReaderMeta(LHead, 'citation_abstract') + '</abstract>' +
    LFront + '</article-meta></front><body>' + LArticle + '</body><back>' +
    LBack + '</back></article>';
  Result := ScreenPmcJatsXml(LScreenInput, AExpectedPmid, AIngredient);
end;

end.
