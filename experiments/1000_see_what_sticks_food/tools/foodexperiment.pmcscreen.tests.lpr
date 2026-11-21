{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPmcScreenTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, StrUtils, foodexperiment.pmcxml;

var
  GPassed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    WriteLn(StdErr, 'FAIL: ', AMessage);
    Halt(1);
  end;
end;

function MakePad(ALen: Integer): String;
begin
  Result := StringOfChar('x', ALen);
end;

function SampleXml(const APmid, ATitle, AAbs, AAuthor, ABody, ABack: String): String;
begin
  Result := '<article><front><article-meta>' +
    '<article-id pub-id-type="pmid">' + APmid + '</article-id>' +
    '<title-group><article-title>' + ATitle + '</article-title></title-group>' +
    '<contrib-group><contrib><name><surname>' + AAuthor + '</surname></name></contrib></contrib-group>' +
    '<abstract><p>' + AAbs + '</p></abstract>' +
    '</article-meta></front><body><p>' + ABody + ' ' + MakePad(450) + '</p></body>' +
    '<back><ref-list><ref>' + ABack + '</ref></ref-list></back></article>';
end;

procedure RunTests;
var
  LRes: TPmcScreenResult;
  LXml: String;
begin
  { 1. Author-only collision -> zero_body_collision }
  LXml := SampleXml('12345678', 'Parkinson gait study', 'Patients walked on a treadmill.',
    'Salmon', 'Movement metrics improved after physical therapy without dietary changes.', 'Smith 2020');
  LRes := ScreenPmcJatsXml(LXml, '12345678', 'salmon');
  Check((LRes.Kind = pkZeroBodyCollision) and (LRes.BodyHits = 0) and (LRes.MetaBackHits = 1),
    'Test 1: expected zero_body_collision on author-only salmon');
  Inc(GPassed);

  { 2. Reference-list-only collision -> zero_body_collision }
  LXml := SampleXml('22345678', 'DBS stimulation study', 'Electrode placement analysis.',
    'Jones', 'Deep brain stimulation outcomes were stable over one year.', 'Broccoli V et al. 2003');
  LRes := ScreenPmcJatsXml(LXml, '22345678', 'broccoli');
  Check((LRes.Kind = pkZeroBodyCollision) and (LRes.BodyHits = 0) and (LRes.MetaBackHits = 1),
    'Test 2: expected zero_body_collision on reference-only broccoli');
  Inc(GPassed);

  { 3. Botanical/constituent alias in body MUST protect paper -> body_match }
  LXml := SampleXml('32345678', 'Oral curcumin in older adults', 'Double-blind randomized trial.',
    'Cox', 'Participants receiving 400 mg oral curcumin improved sustained attention scores.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '32345678', 'turmeric');
  Check((LRes.Kind = pkBodyMatch) and (LRes.BodyHits >= 1) and ContainsStr(LRes.MatchedTerms, 'curcumin'),
    'Test 3: curcumin alias must trigger body_match for turmeric');
  Inc(GPassed);

  { 4. Botanical alias in abstract only MUST protect paper -> body_match }
  LXml := SampleXml('42345678', 'Sulforaphane RCT', 'Oral sulforaphane from sprouts tested.',
    'Nouchi', 'Cognitive processing speed outcomes were analyzed across arms.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '42345678', 'broccoli');
  Check((LRes.Kind = pkBodyMatch) and (LRes.TitleAbsHits >= 1),
    'Test 4: abstract sulforaphane alias must trigger body_match for broccoli');
  Inc(GPassed);

  { 5. Strict word boundary: 'egg' must NOT match 'Beggs' or 'Legg' }
  LXml := SampleXml('52345678', 'Motor study', 'Gait analysis.',
    'Beggs', 'Author Legg and Beggs analyzed step variability in Parkinson patients.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '52345678', 'egg');
  Check((LRes.Kind = pkZeroBodyCollision) and (LRes.BodyHits = 0),
    'Test 5: egg must respect word boundaries against Beggs/Legg');
  Inc(GPassed);

  { 6. PMID mismatch MUST be held -> pmid_mismatch }
  LXml := SampleXml('99999999', 'Different paper', 'Abstract text.',
    'Salmon', 'Body text without fish.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '12345678', 'salmon');
  Check((LRes.Kind = pkPmidMismatch) and (LRes.XmlPmid = '99999999'),
    'Test 6: mismatched PMID must trigger pmid_mismatch');
  Inc(GPassed);

  { 7. Congress poster collection title -> collection_hold }
  LXml := SampleXml('62345678', 'Posters', 'Conference supplement.',
    'Editor', 'Many unrelated abstracts without the term.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '62345678', 'olive oil');
  Check(LRes.Kind = pkCollectionHold,
    'Test 7: Posters title must trigger collection_hold');
  Inc(GPassed);

  { 8. Multiple sub-articles -> collection_hold }
  LXml := SampleXml('72345678', 'Annual Meeting', 'Meeting intro.',
    'Editor', 'Short intro body.', 'Ref 1') + '<sub-article>A</sub-article><sub-article>B</sub-article>';
  LRes := ScreenPmcJatsXml(LXml, '72345678', 'cinnamon');
  Check(LRes.Kind = pkCollectionHold,
    'Test 8: multiple sub-articles must trigger collection_hold');
  Inc(GPassed);

  { 9. Missing or short body -> no_body }
  LXml := '<article><front><article-meta><article-id pub-id-type="pmid">82345678</article-id>' +
    '<title-group><article-title>Short stub</article-title></title-group></article-meta></front>' +
    '<body><p>Too short.</p></body></article>';
  LRes := ScreenPmcJatsXml(LXml, '82345678', 'ginger');
  Check(LRes.Kind = pkNoBody,
    'Test 9: short/stub body must trigger no_body');
  Inc(GPassed);

  { 10. Direct ingredient in body with HTML/XML tags stripped -> body_match }
  LXml := SampleXml('92345678', 'Dietary trial', 'Nutrition study.',
    'Smith', 'Patients consumed <i>Crocus sativus</i> stigma capsules daily for 12 weeks.', 'Ref 1');
  LRes := ScreenPmcJatsXml(LXml, '92345678', 'saffron');
  Check((LRes.Kind = pkBodyMatch) and ContainsStr(LRes.MatchedTerms, 'crocus sativus') and
    ContainsStr(LRes.BodySnippet, 'Crocus sativus'),
    'Test 10: Crocus sativus in XML tags must trigger body_match for saffron');
  Inc(GPassed);
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  RunTests;
  WriteLn('PmcScreenTests passed (', GPassed, '/10).');
end.
