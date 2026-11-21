{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.homograph;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

type
  THomographVerdict = (
    hvUnsupported,
    hvFoodMention,
    hvAmbiguous,
    hvZeroOccurrences,
    hvPureCollision
  );

  THomographResult = record
    Verdict: THomographVerdict;
    TotalHits: Integer;
    CollisionHits: Integer;
    FoodTrigger: String;
    UnexplainedSample: String;
    CollisionSummary: String;
  end;

function IsSupportedHomograph(const AIngredient: String): Boolean;
function ScreenHomographText(const AIngredient, AText: String): THomographResult;

implementation

uses
  SysUtils, StrUtils;

const
  CDateFoodTerms: array[0..26] of String = (
    'phoenix dactylifera', 'dactylifera', 'date palm', 'date palms', 'date fruit', 'date fruits',
    'dried date', 'dried dates', 'fresh date', 'fresh dates', 'palm date', 'palm dates',
    'ajwa', 'medjool', 'deglet', 'mazafati', 'date syrup', 'date seed', 'date seeds',
    'date pit', 'date pits', 'date extract', 'date vinegar', 'date kernel',
    'jujube', 'ziziphus', 'khorma'
  );
  CFigFoodTerms: array[0..21] of String = (
    'ficus', 'f. carica', 'ficin', 'fig fruit', 'fig fruits', 'dried fig', 'dried figs',
    'fresh fig', 'fresh figs', 'raw fig', 'raw figs', 'fig leaf', 'fig leaves', 'fig tree',
    'fig trees', 'fig latex', 'fig paste', 'fig extract', 'fig syrup', 'fig puree',
    'anjir', 'syconium'
  );
  CSageFoodTerms: array[0..18] of String = (
    'salvia', 's. officinalis', 's. miltiorrhiza', 'common sage', 'culinary sage', 'garden sage',
    'sage leaf', 'sage leaves', 'sage tea', 'sage extract', 'sage oil', 'dried sage',
    'fresh sage', 'sage herb', 'sage spice', 'clary sage', 'red sage', 'danshen', 'tanshinone'
  );
  COrangeFoodTerms: array[0..35] of String = (
    'citrus', 'citrus sinensis', 'citrus aurantium', 'citrus reticulata', 'c. sinensis',
    'c. aurantium', 'c. reticulata', 'sweet orange', 'bitter orange', 'blood orange',
    'navel orange', 'mandarin', 'tangerine', 'marmalade', 'hesperidin', 'naringenin',
    'orange juice', 'orange peel', 'orange rind', 'orange pulp', 'orange extract',
    'orange fruit', 'orange fruits', 'orange oil', 'orange flavor', 'orange flavour',
    'orange aroma', 'orange odor', 'orange odour', 'orange scent', 'orange blossom',
    'raw orange', 'fresh orange', 'eating orange', 'orange drink', 'oranges'
  );

  CDatePrefixWords: array[0..112] of String = (
    'to', 'birth', 'start', 'end', 'entry', 'exit', 'index', 'study', 'visit',
    'follow-up', 'followup', 'onset', 'diagnosis', 'diagnostic', 'death', 'censoring',
    'censor', 'cutoff', 'cut-off', 'collection', 'publication', 'published', 'search',
    'approval', 'registration', 'registered', 'release', 'expiry', 'expiration', 'due',
    'target', 'baseline', 'discharge', 'admission', 'surgery', 'surgical', 'transplant',
    'sample', 'sampling', 'scan', 'assessment', 'interview', 'enrollment', 'enrolment',
    'randomization', 'randomisation', 'screening', 'testing', 'test', 'calendar',
    'exact', 'specific', 'earliest', 'latest', 'first', 'last', 'same', 'prior',
    'later', 'earlier', 'given', 'fixed', 'reference', 'matching', 'matched', 'event',
    'access', 'accessed', 'retrieval', 'retrieved', 'submission', 'submitted',
    'acceptance', 'accepted', 'revision', 'revised', 'creation', 'modification',
    'delivery', 'procedure', 'operation', 'questionnaire', 'survey', 'report',
    'reporting', 'prescription', 'dispensing', 'treatment', 'therapy', 'medication',
    'initiation', 'discontinuation', 'recruitment', 'consent', 'missing', 'unknown',
    'current', 'present', 'recent', 'future', 'past', 'subsequent', 'corresponding',
    'respective', 'nearest', 'closest', 'recorded', 'documented', 'reported',
    'confirmed', 'estimated', 'approximate', 'scheduled'
  );
  CDatePrefixWords2: array[0..38] of String = (
    'planned', 'actual', 'observed', 'clinic', 'clinical', 'hospital', 'registry',
    'database', 'record', 'review', 'audit', 'export', 'extraction', 'update',
    'version', 'issue', 'online', 'print', 'copyright', 'license', 'effective',
    'closing', 'opening', 'completion', 'withdrawal', 'dropout', 'relapse',
    'progression', 'conversion', 'hospitalization', 'fracture', 'stroke',
    'vaccination', 'infection', 'exposure', 'outbreak', 'census', 'radiocarbon', 'by'
  );
  CDateExactPhrases: array[0..25] of String = (
    'to date', 'up to date', 'up-to-date', 'out of date', 'out-of-date',
    'date of', 'dates of', 'date back', 'dates back', 'date range', 'date format',
    'date stamp', 'date and time', 'time and date', 'date/time', 'time/date',
    'date-time', 'dates from', 'dates to', 'dates between', 'dates were', 'dates are',
    'from that date', 'at that date', 'on that date', 'as of that date'
  );
  CDateExactPhrases2: array[0..15] of String = (
    'at the date', 'on the date', 'from the date', 'until the date', 'before the date',
    'after the date', 'since the date', 'between the date', 'by the date', 'for the date',
    'of the date', 'blind date', 'date at', 'date when', 'date on which', 'publication date'
  );

  COrangeColorContexts: array[0..54] of String = (
    'agent orange', 'orange book', 'orange county', 'acridine orange', 'methyl orange',
    'xylenol orange', 'sypro orange', 'thiazole orange', 'orange g', 'orange-red',
    'red-orange', 'yellow-orange', 'orange-yellow', 'orange-brown', 'brown-orange',
    'orange color', 'orange colour', 'orange bar', 'orange bars', 'orange line',
    'orange lines', 'orange dot', 'orange dots', 'orange circle', 'orange circles',
    'orange square', 'orange squares', 'orange triangle', 'orange arrow', 'orange arrows',
    'orange box', 'orange boxes', 'orange curve', 'orange curves', 'orange trace',
    'orange shaded', 'orange shading', 'orange region', 'orange area', 'orange zone',
    'orange band', 'orange panel', 'orange marker', 'orange symbol', 'orange column',
    'orange node', 'orange nodes', 'orange edge', 'orange edges', 'orange cluster',
    'orange highlight', 'in orange', 'colored orange', 'coloured orange', 'shaded orange'
  );
  COrangeColorContexts2: array[0..19] of String = (
    'shown in orange', 'indicated in orange', 'marked in orange', 'plotted in orange',
    'represented in orange', 'depicted in orange', 'labeled in orange', 'labelled in orange',
    'highlighted in orange', 'bright orange', 'dark orange', 'light orange', 'pale orange',
    'orange stain', 'orange staining', 'orange fluorescence', 'orange fluorescent',
    'orange dye', 'orange urine', 'orange discoloration'
  );

  CSageNonFoodContexts: array[0..25] of String = (
    'sagepub', 'sage publications', 'sage publishing', 'sage journals', 'sage open',
    'sage therapeutics', 'sage-217', 'sage-718', 'sage-324', 'sage-547', 'sage-689',
    'who sage', 'who-sage', 'sage study', 'sage cohort', 'sage wave', 'sage data',
    'sage survey', 'sage test', 'sage score', 'sage screening', 'sage grouse',
    'sage-grouse', 'sage advice', 'sagebrush', 'sage-brush'
  );

function IsAlphaNum(AChar: Char): Boolean; inline;
begin
  Result := AChar in ['a'..'z', 'A'..'Z', '0'..'9'];
end;

function IsWordBoundary(const AText: String; AStart, ALength: Integer): Boolean;
begin
  Result := ((AStart <= 1) or not IsAlphaNum(AText[AStart - 1])) and
    ((AStart + ALength > Length(AText)) or not IsAlphaNum(AText[AStart + ALength]));
end;

function ContainsWholePhrase(const ALowerText, APhrase: String): Boolean;
var
  LPos: Integer;
begin
  LPos := PosEx(APhrase, ALowerText, 1);
  while LPos > 0 do
  begin
    if IsWordBoundary(ALowerText, LPos, Length(APhrase)) then
    begin
      Exit(True);
    end;
    LPos := PosEx(APhrase, ALowerText, LPos + 1);
  end;
  Result := False;
end;

function FindFoodTerm(const ALowerText: String; const ATerms: array of String): String;
var
  LTerm: String;
begin
  for LTerm in ATerms do
  begin
    if ContainsWholePhrase(ALowerText, LTerm) then
    begin
      Exit(LTerm);
    end;
  end;
  Result := '';
end;

function WindowOf(const AText: String; APos, ALen, ARadius: Integer): String;
var
  LStart: Integer;
  LStop: Integer;
begin
  LStart := APos - ARadius;
  if LStart < 1 then
  begin
    LStart := 1;
  end;
  LStop := APos + ALen - 1 + ARadius;
  if LStop > Length(AText) then
  begin
    LStop := Length(AText);
  end;
  Result := StringReplace(StringReplace(Copy(AText, LStart, LStop - LStart + 1),
    #10, ' ', [rfReplaceAll]), #13, ' ', [rfReplaceAll]);
end;

function PrevWord(const ALowerText: String; APos: Integer): String;
var
  LEnd: Integer;
  LStart: Integer;
begin
  LEnd := APos - 1;
  while (LEnd >= 1) and (ALowerText[LEnd] in [' ', #9, #10, #13, ',', ';', '(', '[']) do
  begin
    Dec(LEnd);
  end;
  LStart := LEnd;
  while (LStart >= 1) and (ALowerText[LStart] in ['a'..'z', '0'..'9', '-']) do
  begin
    Dec(LStart);
  end;
  Result := Copy(ALowerText, LStart + 1, LEnd - LStart);
end;

function NextCharNonSpace(const AText: String; AAfter: Integer): Char;
var
  LIndex: Integer;
begin
  LIndex := AAfter;
  while (LIndex <= Length(AText)) and (AText[LIndex] in [' ', #9, #10, #13]) do
  begin
    Inc(LIndex);
  end;
  if LIndex <= Length(AText) then
  begin
    Result := AText[LIndex];
  end
  else
  begin
    Result := #0;
  end;
end;

function IsWordIn(const AWord: String; const AList: array of String): Boolean;
var
  LItem: String;
begin
  for LItem in AList do
  begin
    if AWord = LItem then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function HasAnyPhrase(const AWindow: String; const AList: array of String): Boolean;
var
  LItem: String;
begin
  for LItem in AList do
  begin
    if Pos(LItem, AWindow) > 0 then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function IsDateCollision(const ALowerText: String; APos, ALen: Integer): Boolean;
var
  LPrev: String;
  LWindow: String;
  LAfterPos: Integer;
begin
  LAfterPos := APos + ALen;
  if (LAfterPos <= Length(ALowerText)) and (ALowerText[LAfterPos] in [':', '/', ')']) then
  begin
    Exit(True);
  end;
  if (APos > 1) and (ALowerText[APos - 1] in ['/', '(']) then
  begin
    Exit(True);
  end;
  LPrev := PrevWord(ALowerText, APos);
  if IsWordIn(LPrev, CDatePrefixWords) or IsWordIn(LPrev, CDatePrefixWords2) then
  begin
    Exit(True);
  end;
  LWindow := WindowOf(ALowerText, APos, ALen, 24);
  Result := HasAnyPhrase(LWindow, CDateExactPhrases) or
    HasAnyPhrase(LWindow, CDateExactPhrases2);
end;

function IsFigCollision(const AOrigText, ALowerText: String; APos, ALen: Integer): Boolean;
var
  LAfterPos: Integer;
  LNext: Char;
  LNext2: Char;
  LPrev: String;
  LWindow: String;
begin
  LAfterPos := APos + ALen;
  // Direct period abbreviation ("Fig.", "Figs.") is a figure reference.
  if (LAfterPos <= Length(ALowerText)) and (ALowerText[LAfterPos] = '.') then
  begin
    Exit(True);
  end;
  // Immediate digit or supplementary label ("Fig 1", "Fig S2", "Fig 1A", "Figs 2-4").
  LNext := NextCharNonSpace(ALowerText, LAfterPos);
  if LNext in ['0'..'9'] then
  begin
    Exit(True);
  end;
  if (LNext = 's') or (LNext = 'e') then
  begin
    while (LAfterPos <= Length(ALowerText)) and (ALowerText[LAfterPos] in [' ', #9]) do
    begin
      Inc(LAfterPos);
    end;
    if (LAfterPos + 1 <= Length(ALowerText)) and (ALowerText[LAfterPos + 1] in ['0'..'9']) then
    begin
      Exit(True);
    end;
  end;
  // Parenthesized or uppercase-led "Fig" preceded by "supplementary"/"extended"/"see".
  LPrev := PrevWord(ALowerText, APos);
  if (LPrev = 'supplementary') or (LPrev = 'supplemental') or (LPrev = 'extended') or
    (LPrev = 'additional') then
  begin
    Exit(True);
  end;
  if (APos > 1) and (AOrigText[APos - 1] in ['(', '[']) and (AOrigText[APos] = 'F') then
  begin
    LNext2 := NextCharNonSpace(ALowerText, APos + ALen);
    if LNext2 in ['0'..'9', '.', 's', 'a'..'f'] then
    begin
      Exit(True);
    end;
  end;
  LWindow := WindowOf(ALowerText, APos, ALen, 18);
  Result := (Pos('extended data fig', LWindow) > 0) or (Pos('source data fig', LWindow) > 0);
end;

function IsSageCollision(const AOrigText, ALowerText: String; APos, ALen: Integer): Boolean;
var
  LWindow: String;
begin
  // All-caps SAGE in biomedical literature denotes SAGE Publications, WHO SAGE,
  // Serial Analysis of Gene Expression, SAGE Therapeutics or cognitive SAGE tests.
  if Copy(AOrigText, APos, ALen) = 'SAGE' then
  begin
    Exit(True);
  end;
  LWindow := WindowOf(ALowerText, APos, ALen, 28);
  Result := HasAnyPhrase(LWindow, CSageNonFoodContexts);
end;

function IsOrangeCollision(const ALowerText: String; APos, ALen: Integer): Boolean;
var
  LWindow: String;
begin
  LWindow := WindowOf(ALowerText, APos, ALen, 32);
  Result := HasAnyPhrase(LWindow, COrangeColorContexts) or
    HasAnyPhrase(LWindow, COrangeColorContexts2);
end;

function IsSupportedHomograph(const AIngredient: String): Boolean;
begin
  Result := MatchText(Trim(AIngredient), ['date', 'fig', 'sage', 'orange']);
end;

function ScreenHomographText(const AIngredient, AText: String): THomographResult;
var
  LIng: String;
  LLower: String;
  LTokens: array of String;
  LToken: String;
  LPos: Integer;
  LCollision: Boolean;
  LKindLabel: String;
begin
  Result := Default(THomographResult);
  LIng := LowerCase(Trim(AIngredient));
  if not IsSupportedHomograph(LIng) then
  begin
    Result.Verdict := hvUnsupported;
    Exit;
  end;
  LLower := LowerCase(AText);

  if LIng = 'date' then
  begin
    Result.FoodTrigger := FindFoodTerm(LLower, CDateFoodTerms);
    SetLength(LTokens, 2);
    LTokens[0] := 'date';
    LTokens[1] := 'dates';
    LKindLabel := 'calendar/temporal date terms';
  end
  else if LIng = 'fig' then
  begin
    Result.FoodTrigger := FindFoodTerm(LLower, CFigFoodTerms);
    SetLength(LTokens, 2);
    LTokens[0] := 'fig';
    LTokens[1] := 'figs';
    LKindLabel := 'figure-citation abbreviations';
  end
  else if LIng = 'sage' then
  begin
    Result.FoodTrigger := FindFoodTerm(LLower, CSageFoodTerms);
    SetLength(LTokens, 1);
    LTokens[0] := 'sage';
    LKindLabel := 'SAGE publisher/acronym/assay terms';
  end
  else
  begin
    Result.FoodTrigger := FindFoodTerm(LLower, COrangeFoodTerms);
    SetLength(LTokens, 1);
    LTokens[0] := 'orange';
    LKindLabel := 'color/stain/Agent Orange non-food terms';
  end;

  if Result.FoodTrigger <> '' then
  begin
    Result.Verdict := hvFoodMention;
    Exit;
  end;

  for LToken in LTokens do
  begin
    LPos := PosEx(LToken, LLower, 1);
    while LPos > 0 do
    begin
      if IsWordBoundary(LLower, LPos, Length(LToken)) then
      begin
        Inc(Result.TotalHits);
        if LIng = 'date' then
          LCollision := IsDateCollision(LLower, LPos, Length(LToken))
        else if LIng = 'fig' then
          LCollision := IsFigCollision(AText, LLower, LPos, Length(LToken))
        else if LIng = 'sage' then
          LCollision := IsSageCollision(AText, LLower, LPos, Length(LToken))
        else
          LCollision := IsOrangeCollision(LLower, LPos, Length(LToken));
        if LCollision then
        begin
          Inc(Result.CollisionHits);
        end
        else if Result.UnexplainedSample = '' then
        begin
          Result.UnexplainedSample := WindowOf(AText, LPos, Length(LToken), 35);
        end;
      end;
      LPos := PosEx(LToken, LLower, LPos + 1);
    end;
  end;

  if Result.TotalHits = 0 then
  begin
    Result.Verdict := hvZeroOccurrences;
    Result.CollisionSummary := 'Complete archived full text contains zero whole-word ' +
      LIng + ' or botanical/culinary synonym occurrences.';
  end
  else if Result.CollisionHits = Result.TotalHits then
  begin
    Result.Verdict := hvPureCollision;
    Result.CollisionSummary := Format('Complete archived full text has %d/%d %s occurrence(s) ' +
      'strictly in verified %s and zero botanical/culinary terms.',
      [Result.CollisionHits, Result.TotalHits, LIng, LKindLabel]);
  end
  else
  begin
    Result.Verdict := hvAmbiguous;
  end;
end;

end.
