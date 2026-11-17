{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPubMedQueryTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, foodexperiment.pubmedquery;

const
  CanonicalEpmc = '(TITLE_ABS:parkinson* OR TITLE_ABS:"shaking palsy" OR ' +
    'TITLE_ABS:"paralysis agitans")';
  CanonicalPubMed = '("Parkinson Disease"[mh] OR "Parkinsonian Disorders"[mh:noexp] OR ' +
    '"Parkinson Disease, Secondary"[mh:noexp] OR parkinson*[tiab] OR ' +
    '"shaking palsy"[tiab] OR "paralysis agitans"[tiab])';

procedure Check(const AQueryId, AExpression, AMesh, AExpected: UTF8String);
var
  LActual: UTF8String;
begin
  LActual := MakePubMedQuery(AExpression, AQueryId, AMesh);
  Assert(LActual = AExpected, AQueryId + LineEnding + 'Expected: ' + AExpected +
    LineEnding + 'Actual:   ' + LActual);
end;

procedure CheckInvalid(const AExpression: UTF8String);
begin
  try
    MakePubMedQuery(AExpression, 'E001', '');
  except
    on EConvertError do
    begin
      Exit;
    end;
  end;
  raise EConvertError.Create('Invalid query was accepted: ' + AExpression);
end;

begin
  Check('E081', CanonicalEpmc + ' AND (TITLE_ABS:coffee OR TITLE_ABS:"café")', 'Coffee',
    CanonicalPubMed + ' AND (coffee[tiab] OR "café"[tiab] OR "Coffee"[mh:noexp])');
  Check('E001', CanonicalEpmc + ' AND (TITLE_ABS:"apple pectin")', '',
    CanonicalPubMed + ' AND ("apple pectin"[tiab])');
  Check('R532', '(TITLE_ABS:"peanut oil" OR TITLE_ABS:"huile d''arachide") AND ' +
    '(TITLE_ABS:dysarthria OR TITLE_ABS:hypophonia)', '',
    '("peanut oil"[tiab] OR "huile d''arachide"[tiab]) AND ' +
    '(dysarthria[tiab] OR hypophonia[tiab])');
  Check('E102', '(TITLE_ABS:parkinson* OR TITLE_ABS:"Lewy body") AND ' +
    '((TITLE_ABS:chive OR "Chive"[MeSH Terms]) AND (TITLE_ABS:dystoni*))', 'Chive',
    '(parkinson*[tiab] OR "Lewy body"[tiab]) AND ' +
    '((chive[tiab] OR "Chive"[MeSH Terms]) AND (dystoni*[tiab]))');
  Check('E081', CanonicalEpmc + ' AND ((TITLE_ABS:coffee) AND (TITLE_ABS:dystoni*))',
    'Coffee', CanonicalPubMed + ' AND ((coffee[tiab]) AND (dystoni*[tiab]))');
  Check('E081', CanonicalEpmc + ' AND (TITLE_ABS:coffee TITLE_ABS:dystoni*)',
    'Coffee', CanonicalPubMed + ' AND (coffee[tiab] dystoni*[tiab])');
  Check('R801', '(TITLE_ABS:"oil ) AND ( sample" OR TITLE_ABS:"a \"quoted\" term")' +
    ' AND (TITLE_ABS:"wearing off") NOT (TITLE_ABS:animals)', '',
    '("oil ) AND ( sample"[tiab] OR "a \"quoted\" term"[tiab])' +
    ' AND ("wearing off"[tiab]) NOT (animals[tiab])');
  Check('R802', '(TITLE_ABS:"花生油" OR TITLE_ABS:"арахисовое масло") AND ' +
    '(TITLE_ABS:levodopa)', '',
    '("花生油"[tiab] OR "арахисовое масло"[tiab]) AND (levodopa[tiab])');
  Check('R803', '(TITLE_ABS:peanut AND (TITLE_ABS:oil OR TITLE_ABS:lipid)) AND ' +
    '(TITLE_ABS:fatigue)', '',
    '(peanut[tiab] AND (oil[tiab] OR lipid[tiab])) AND (fatigue[tiab])');
  CheckInvalid('');
  CheckInvalid('(TITLE_ABS:)');
  CheckInvalid('(TITLE_ABS:"missing quote)');
  CheckInvalid('(TITLE_ABS:peanut');
  Assert(PubMedTranslationError(
    '(グレープフルーツ[tiab] OR ジュース[tiab]) AND (歩幅[tiab] OR 歩行[tiab])',
    '"OR"[Title/Abstract] AND "OR"[Title/Abstract]') <> '');
  Assert(PubMedTranslationError(
    '(grapefruit[tiab] OR グレープフルーツ[tiab]) AND Parkinson[tiab]',
    '"grapefruit"[Title/Abstract] AND "OR"[Title/Abstract] AND "Parkinson"[Title/Abstract]') <> '');
  Assert(PubMedTranslationError('"グレープフルーツ"[tiab]', '"     "[tiab]') <> '');
  Assert(PubMedTranslationError('floor[tiab] OR 歩幅[tiab]',
    '"floor"[Title/Abstract] AND "OR"[Title/Abstract]') <> '');
  Assert(PubMedTranslationError('coffee[tiab] AND "OR"[tiab]',
    '"coffee"[Title/Abstract] AND "OR"[Title/Abstract]') = '');
  Assert(PubMedTranslationError('(OR[tiab] AND gait[tiab])',
    '"OR"[Title/Abstract] AND "gait"[Title/Abstract]') = '');
  Assert(PubMedTranslationError('("café"[tiab] OR coffee[tiab]) AND Parkinson[tiab]',
    '("café"[Title/Abstract] OR "coffee"[Title/Abstract]) AND "Parkinson"[Title/Abstract]') = '');
  Assert(PubMedTranslationError('rarephrase[tiab]', '') = '');
  WriteLn('PubMed query regression cases passed.');
end.
