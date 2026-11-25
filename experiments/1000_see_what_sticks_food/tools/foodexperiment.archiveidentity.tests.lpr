{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentArchiveIdentityTests;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, foodexperiment.archiveidentity;

var
  LExpected, LArchive: TArchiveIdentity;
  LPath: String;
  LHeader: TStringList;

begin
  LExpected := Default(TArchiveIdentity);
  LExpected.Pmcid := 'PMC7103256';
  LExpected.Pmid := '20532731';
  LExpected.Doi := 'https://doi.org/10.1007/s11739-010-0412-7';
  LExpected.Title := 'A subtle case of iron-deficiency anemia';

  LPath := GetTempFileName(ExtractFilePath(ParamStr(0)), 'arc');
  LHeader := TStringList.Create;
  try
    LHeader.Add('Title: Posters');
    LHeader.Add('PMCID: PMC7103256');
    LHeader.Add('PMID: ');
    LHeader.Add('DOI: 10.1007/s11739-011-0736-y');
    LHeader.Add('');
    LHeader.Add('PMID: 20532731');
    LHeader.SaveToFile(LPath);
    LArchive := ReadArchiveIdentity(LPath);
    Assert(LArchive.Pmcid = 'PMC7103256', 'Missing explicit archive PMCID');
    Assert(LArchive.Pmid = '', 'A body line was interpreted as provenance');
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = 'doi',
      'A conference file with a matching PMCID and conflicting DOI must be flagged');
    Assert(not SameTitledArchive(LExpected, LArchive), 'A different article was corroborated');
    Assert(PmcAliasHasDoiConflict(LExpected, LArchive),
      'A proceedings DOI must not retire the linked individual article');
    LArchive.Doi := '';
    Assert(not PmcAliasHasDoiConflict(LExpected, LArchive),
      'Missing DOI metadata is not a confirmed alias conflict');
    LArchive := LExpected;
    LArchive.Doi := '10.1007/s11739-011-0736-y';
    Assert(not PmcAliasHasDoiConflict(LExpected, LArchive),
      'Matching title and both accessions retain legitimate DOI advisories');

    LArchive := LExpected;
    LArchive.Title := 'A subtle case of iron deficiency anemia.';
    LArchive.Doi := '10.1007/s11739-010-0412-7';
    Assert(SameTitledArchive(LExpected, LArchive), 'Title formatting is not an identity conflict');
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = '', 'DOI URL and bare DOI should agree');

    LArchive.Pmid := '22349181';
    LArchive.Pmcid := 'PMC7100643';
    LArchive.Doi := '10.1007/s00210-012-0736-0';
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = 'pmcid,pmid,doi',
      'Independent contradictory identifiers were not reported');
    Assert(not SameTitledArchive(LExpected, LArchive), 'A title match alone corroborated another PMID');

    LArchive := Default(TArchiveIdentity);
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = '',
      'Absent provenance must remain distinct from an explicit conflict');
    Assert(not SameTitledArchive(LExpected, LArchive), 'Absent provenance was treated as corroboration');

    LExpected.Pmcid := 'PMC3026677';
    LExpected.Pmid := '20821054';
    LExpected.Doi := '10.1007/s10545-010-9178-3';
    LExpected.Title := 'Determination of cystathionine beta-synthase activity in human plasma ' +
      'by LC-MS/MS: potential use in diagnosis of CBS deficiency';
    LArchive := LExpected;
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = '',
      'The correctly identified article must remain joinable');
    LArchive.Title := 'Annual Symposium of the Society for the Study of Inborn Errors of Metabolism';
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = 'collection_title',
      'A proceedings collection with copied article identifiers must be held');
    LExpected.Title := LArchive.Title;
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = '',
      'An indexed collection can join its own archive body');

    Assert(ParseTrialArchiveIdentifier('Archived trial' + LineEnding + LineEnding +
      'Source: https://clinicaltrials.gov/study/NCT04986982' + LineEnding +
      'Source credit: ClinicalTrials.gov' + LineEnding +
      'NCT ID: NCT04986982' + LineEnding, 'NCT04986982') = 'NCT04986982',
      'The registry provenance identifies the record');
    Assert(ParseTrialArchiveIdentifier('Title: Archived results' + LineEnding +
      'Source: https://clinicaltrials.gov/study/NCT04986982?tab=results' + LineEnding +
      'NCT ID: NCT04986982' + LineEnding, 'NCT04986982') = 'NCT04986982',
      'A separate official results file can match the same registration');
    Assert(ParseTrialArchiveIdentifier('Archived trial' + LineEnding + LineEnding +
      'Source: https://clinicaltrials.gov/study/NCT04986982' + LineEnding +
      'NCT ID: NCT05719142' + LineEnding, 'NCT04986982') = '',
      'Conflicting registry provenance cannot identify a source');
    Assert(RegistryArchiveFileIdentifier('2026-NCT07655219-Registry-Extract.txt') = 'NCT07655219');
    Assert(RegistryArchiveFileIdentifier('2014-02-20-NCT02067572-Sage-Mouth-Rinse.txt') = 'NCT02067572');
    Assert(RegistryArchiveFileIdentifier('memo-NCT07655219.txt') = '');
    Assert(RegistryArchiveFileIdentifier('NCT076552190-results.txt') = '');
    Assert(ParseTrialArchiveIdentifier('Registration: NCT07655219' + LineEnding +
      'Source: https://clinicaltrials.gov/study/NCT07655219', 'NCT07655219') = 'NCT07655219',
      'The official source and the registration field can appear in either order');
    Assert(ParseTrialArchiveIdentifier('https://clinicaltrials.gov/api/v2/studies/NCT07655219' +
      LineEnding, 'NCT07655219') = 'NCT07655219');
    Assert(ParseTrialArchiveIdentifier('Title: Archived registry fields' + LineEnding +
      'Source: ClinicalTrials.gov' + LineEnding +
      'URL: https://clinicaltrials.gov/study/NCT05602688' + LineEnding +
      'Official API: https://clinicaltrials.gov/api/v2/studies/NCT05602688' + LineEnding +
      'Registry ID: NCT05602688' + LineEnding, 'NCT05602688') = 'NCT05602688',
      'Named official URLs identify the matching registry source');
    Assert(ParseTrialArchiveIdentifier('Registry ID: NCT05602688' + LineEnding +
      'Official API: https://clinicaltrials.gov/api/v2/studies/NCT05602688' + LineEnding,
      'NCT05602688') = 'NCT05602688', 'An official API URL is sufficient provenance');
    Assert(ParseTrialArchiveIdentifier('Registry ID: NCT05602688' + LineEnding +
      'URL: https://clinicaltrials.gov.example/study/NCT05602688' + LineEnding,
      'NCT05602688') = '', 'An unrelated domain does not identify the source');
    Assert(ParseTrialArchiveIdentifier(
      'URL: https://clinicaltrials.gov/study/NCT05602688' + LineEnding +
      'Official API: https://clinicaltrials.gov/api/v2/studies/NCT07655219' + LineEnding,
      'NCT05602688') = '', 'Conflicting URL and API identities are rejected');
    Assert(ParseTrialArchiveIdentifier('Registration: NCT07655219' + LineEnding +
      'See https://clinicaltrials.gov/study/NCT07655219' + LineEnding, 'NCT07655219') = '',
      'A citation in prose does not supply registry provenance');
    Assert(ParseTrialArchiveIdentifier(
      'Primary source: https://clinicaltrials.gov/study/NCT02463435' + LineEnding +
      'Registration: NCT02463435' + LineEnding, 'NCT02463435') = 'NCT02463435',
      'A legacy primary-source field can authenticate an official trial URL');
    Assert(ParseTrialArchiveIdentifier(
      'Primary source: https://clinicaltrials.gov/study/NCT05602688' + LineEnding +
      'Registration: NCT02463435' + LineEnding, 'NCT02463435') = '',
      'A legacy primary-source field for the wrong trial is rejected');
    Assert(ParseTrialArchiveIdentifier('Source: https://clinicaltrials.gov/study/NCT07655219' +
      LineEnding + 'Registry ID: NCT05719142' + LineEnding, 'NCT07655219') = '');
    Assert(ParseTrialArchiveIdentifier('Source: https://clinicaltrials.gov/study/NCT07655219' +
      LineEnding + 'Source: https://clinicaltrials.gov/study/NCT05719142' + LineEnding,
      'NCT07655219') = '');
    Assert(ParseTrialArchiveIdentifier('Source: https://clinicaltrials.gov.example/study/NCT07655219' +
      LineEnding, 'NCT07655219') = '');
    Assert(NormalizeArchiveIdentifier('Pmid: 20532731') = 'PMID:20532731');
    Assert(NormalizeArchiveIdentifier('pmcid: pmc7103256') = 'PMCID:PMC7103256');
    Assert(NormalizeArchiveIdentifier('https://doi.org/10.1007/BF00301247') =
      'DOI:10.1007/bf00301247');
    Assert(NormalizeArchiveIdentifier('nct04986982') = 'NCT04986982');
    Assert(NormalizeArchiveIdentifier('PMID:PMC7103256') = '');
    Assert(NormalizeArchiveIdentifier('NCT0498698') = '');
    Assert(NormalizeArchiveIdentifier('10.bad/') = '');
    Assert(NormalizeArchiveIdentifier('Parkinson tremor') = '');
    Assert(OtherRegistryHeaderMatches('Record: ACTRN12625000047493' + LineEnding +
      'Source: https://anzctr.org.au/ACTRN12625000047493.aspx' + LineEnding,
      'ACTRN12625000047493'), 'The exact ANZCTR short link authenticates the matching ID');
    Assert(OtherRegistryHeaderMatches('Registry ID: ACTRN12626001145392' + LineEnding +
      'URL: https://www.anzctr.org.au/ACTRN12626001145392.aspx' + LineEnding,
      'ACTRN12626001145392'), 'The official www host is also supported');
    Assert(OtherRegistryHeaderMatches(
      'Official ANZCTR registration ACTRN12621001760864. First posted in 2021.' + LineEnding +
      'Primary source: https://anzctr.org.au/Trial/Registration/TrialReview.aspx?id=382647' +
      LineEnding, 'ACTRN12621001760864'), 'A legacy heading identifies the trial');
    Assert(not OtherRegistryHeaderMatches(
      'Official ANZCTR registration ACTRN12626001145392.' + LineEnding +
      'https://anzctr.org.au/Trial/Registration/TrialReview.aspx?id=382647' +
      LineEnding, 'ACTRN12621001760864'), 'A conflicting legacy trial heading is rejected');
    Assert(not OtherRegistryHeaderMatches(
      'Official ANZCTR registration ACTRN12621001760864.' + LineEnding +
      'https://anzctr.org.au.example/Trial/Registration/TrialReview.aspx?id=382647' +
      LineEnding, 'ACTRN12621001760864'), 'The heading still requires an official host');
    Assert(not OtherRegistryHeaderMatches('Registry ID: ACTRN12626001145392' + LineEnding +
      'URL: https://anzctr.org.au/ACTRN12625000047493.aspx' + LineEnding,
      'ACTRN12626001145392'), 'A short link for a different trial must not match');
    Assert(not OtherRegistryHeaderMatches('Registry ID: ACTRN12626001145392' + LineEnding +
      'URL: https://anzctr.org.au.example/ACTRN12626001145392.aspx' + LineEnding,
      'ACTRN12626001145392'), 'A lookalike host must not authenticate a trial');
    Assert(OtherRegistryHeaderMatches('Record: ACTRN12617001269325' + LineEnding +
      'Source: https://www.anzctr.org.au/Trial/Registration/TrialReview.aspx?ACTRN=12617001269325' +
      LineEnding, 'ACTRN12617001269325'), 'The official ACTRN query authenticates a matching trial');
    Assert(not OtherRegistryHeaderMatches('Record: ACTRN12617001269325' + LineEnding +
      'Source: https://www.anzctr.org.au/Trial/Registration/TrialReview.aspx?ACTRN=12626001145392' +
      LineEnding, 'ACTRN12617001269325'), 'An ACTRN query for another trial does not authenticate');
    Assert(not OtherRegistryHeaderMatches('Record: ACTRN12617001269325' + LineEnding +
      'Source: https://www.anzctr.org.au.example/Trial/Registration/TrialReview.aspx?ACTRN=12617001269325' +
      LineEnding, 'ACTRN12617001269325'), 'A lookalike ACTRN query does not authenticate');
    Assert(NormalizeArchiveIdentifier('drks00012459') = 'DRKS00012459');
    Assert(NormalizeArchiveIdentifier('umin000055134') = 'UMIN000055134');
    Assert(NormalizeArchiveIdentifier('UMIN00005513') = '');
    Assert(NormalizeArchiveIdentifier('UMIN0000551340') = '');
    Assert(NormalizeArchiveIdentifier('UMIN00005513X') = '');
    Assert(RegistryArchiveFileIdentifier('UMIN000050721-results.txt') = 'UMIN000050721');
    Assert(RegistryArchiveFileIdentifier('note-UMIN000050721.txt') = '');
    Assert(OtherRegistryHeaderMatches('Registry ID: UMIN000055134' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/icdr_e/ctr_view.cgi?recptno=R000062988' +
      LineEnding, 'UMIN000055134'));
    Assert(OtherRegistryHeaderMatches('Brewed lemon balm registration' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/icdr_e/ctr_view.cgi?recptno=R000062988' +
      LineEnding + LineEnding + 'Official study UMIN000055134, first public 2024-08-02.',
      'UMIN000055134'), 'The specific legacy provenance sentence can follow a blank line');
    Assert(OtherRegistryHeaderMatches('Swallowing results' + LineEnding + LineEnding +
      'Source: UMIN Clinical Trials Registry, UMIN000050721, receipt R000057788' + LineEnding +
      'Official record: https://center6.umin.ac.jp/cgi-open-bin/icdr_e/ctr_view.cgi?recptno=R000057788' +
      LineEnding, 'UMIN000050721'));
    Assert(OtherRegistryHeaderMatches('UMIN Clinical Trials Registry, selected public fields' +
      LineEnding + 'Registration: UMIN000032451' + LineEnding +
      'Official source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000037005' +
      LineEnding + 'Japanese source: https://center6.umin.ac.jp/cgi-open-bin/ctr/ctr_view.cgi?recptno=R000037005',
      'UMIN000032451'));
    Assert(OtherRegistryHeaderMatches('UMIN000055115: Selected results' + LineEnding +
      'Record: R000062960' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062960',
      'UMIN000055115'), 'The receipt is separate from the UMIN trial identity');
    Assert(not OtherRegistryHeaderMatches('Registry ID: UMIN000055134' + LineEnding +
      'Registration: UMIN000055115' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062988',
      'UMIN000055134'), 'Conflicting explicit trial identities are rejected');
    Assert(not OtherRegistryHeaderMatches('Registry ID: UMIN000055134' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062988' +
      LineEnding + 'Japanese source: https://center6.umin.ac.jp/cgi-open-bin/ctr/ctr_view.cgi?recptno=R000062960',
      'UMIN000055134'), 'Conflicting receipt numbers are rejected');
    Assert(not OtherRegistryHeaderMatches('Registry ID: UMIN000055134' + LineEnding +
      'Source: https://center6.umin.ac.jp.example/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062988',
      'UMIN000055134'), 'Lookalike hosts cannot authenticate a registry source');
    Assert(not OtherRegistryHeaderMatches('Registry ID: UMIN000055134' + LineEnding +
      'Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R00006298',
      'UMIN000055134'), 'Malformed receipt IDs are rejected');
    Assert(not OtherRegistryHeaderMatches('Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062988' +
      LineEnding + 'The discussion cites UMIN000055134 as a separate study.',
      'UMIN000055134'), 'An ordinary narrative mention cannot identify the archive');
    Assert(not OtherRegistryHeaderMatches('Source: https://center6.umin.ac.jp/cgi-open-bin/ctr_e/ctr_view.cgi?recptno=R000062988' +
      LineEnding, 'UMIN000055134'), 'The filename and receipt alone cannot identify the trial');
    Assert(NormalizeArchiveIdentifier('DRKS0001245') = '');
    Assert(RegistryArchiveFileIdentifier('2018-DRKS00012459-update.txt') = 'DRKS00012459');
    Assert(OtherRegistryHeaderMatches(
      'Source: https://drks.de/search/en/trial/DRKS00012459' + LineEnding, 'DRKS00012459'),
      'The official DRKS path authenticates an older extract without a separate ID field');
    Assert(OtherRegistryHeaderMatches(
      'Registry identifier: DRKS00012459' + LineEnding +
      'Source: https://drks.de/search/de/trial/DRKS00012459/details' + LineEnding, 'DRKS00012459'));
    Assert(not OtherRegistryHeaderMatches(
      'Registry identifier: DRKS00012459' + LineEnding +
      'Source: https://drks.de/search/en/trial/DRKS00013219' + LineEnding, 'DRKS00012459'),
      'DRKS provenance must identify the same trial as the filename');
    Assert(not OtherRegistryHeaderMatches(
      'Source: https://drks.de/search/en/trial/DRKS00012459-copy' + LineEnding, 'DRKS00012459'),
      'A lookalike path is not the official record');
    Assert(not OtherRegistryHeaderMatches(
      'Source: https://drks.de/search/en/trial/DRKS00012459' + LineEnding +
      'Registry identifier: DRKS00013219' + LineEnding, 'DRKS00012459'),
      'Conflicting registry metadata invalidates a DRKS match');

    Assert(NormalizeArchiveIdentifier('tctr20241101001') = 'TCTR20241101001');
    Assert(NormalizeArchiveIdentifier('TCTR2024110100') = '');
    Assert(NormalizeArchiveIdentifier('TCTR202411010010') = '');
    Assert(NormalizeArchiveIdentifier('TCTR2024110100O') = '');
    Assert(RegistryArchiveFileIdentifier('TCTR20241101001.txt') = 'TCTR20241101001');
    Assert(RegistryArchiveFileIdentifier('memo-TCTR20241101001.txt') = '');
    Assert(OtherRegistryHeaderMatches('Title: Archived trial' + LineEnding +
      'Registry: TCTR20241101001' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding +
      'Official XML: https://www.thaiclinicaltrials.org/export/xml/TCTR20241101001' + LineEnding,
      'TCTR20241101001'), 'A matching show and XML record identifies the archived trial');
    Assert(OtherRegistryHeaderMatches('Trial ID: TCTR20241101001' + LineEnding +
      'Source: https://www.thaiclinicaltrials.org/export/xml/TCTR20241101001',
      'TCTR20241101001'), 'An official XML source line can end at EOF');
    Assert(OtherRegistryHeaderMatches('Registry: Thai Clinical Trials Registry' + LineEnding +
      'Identifier: TCTR20241101001' + LineEnding +
      'Official record: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding,
      'TCTR20241101001'), 'Recognize the registry name and separately labeled identifier');
    Assert(not OtherRegistryHeaderMatches('Registry: TCTR20241101001' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101002' + LineEnding,
      'TCTR20241101001'), 'The official URL must identify the same trial');
    Assert(not OtherRegistryHeaderMatches('Registry: TCTR20241101001' + LineEnding +
      'Trial ID: TCTR20241101002' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding,
      'TCTR20241101001'), 'A matching official URL cannot override a conflicting metadata ID');
    Assert(not OtherRegistryHeaderMatches(
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding +
      'Official XML: https://www.thaiclinicaltrials.org/export/xml/TCTR20241101002' + LineEnding,
      'TCTR20241101001'), 'Conflicting official paths invalidate the provenance');
    Assert(not OtherRegistryHeaderMatches('Registry: TCTR20241101001' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org.example/show/TCTR20241101001' +
      LineEnding, 'TCTR20241101001'), 'A lookalike host is never the official registry');
    Assert(not OtherRegistryHeaderMatches('Registry: TCTR20241101001' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001-copy' +
      LineEnding, 'TCTR20241101001'), 'A lookalike path is never an exact source');
    Assert(not OtherRegistryHeaderMatches('Title: A paper citing the protocol' + LineEnding +
      LineEnding + 'Registry: TCTR20241101001' + LineEnding +
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding,
      'TCTR20241101001'), 'A body citation cannot authenticate the document');
    Assert(not OtherRegistryHeaderMatches('Registry: TCTR20241101001' + LineEnding +
      'See https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding,
      'TCTR20241101001'), 'A prose URL cannot authenticate the document');

    Assert(not OtherRegistryHeaderMatches(
      'Official source: https://www.thaiclinicaltrials.org/show/TCTR20241101001' + LineEnding +
      'Title: ' + StringOfChar('a', 1100) + LineEnding + 'Registry: TCTR20241101002',
      'TCTR20241101001'), 'A long leading header cannot hide conflicting metadata');

    LExpected.Pmcid := 'PMC7100645';
    LExpected.Pmid := '8183379';
    LExpected.Doi := '';
    LExpected.Title := 'German Society for Experimental and Clinical Pharmacology and Toxicology, ' +
      '35th spring meeting. Mainz, Germany, 15-17 March 1994. Abstracts.';
    LArchive := LExpected;
    LArchive.Title := 'Abstracts';
    LArchive.Doi := '10.1007/BF00301247';
    Assert(ArchiveIdentityConflicts(LExpected, LArchive) = '',
      'An expanded indexed meeting title must retain the shorter original collection');
  finally
    LHeader.Free;
    DeleteFile(LPath);
  end;
  WriteLn('Archive identity regression checks passed');
end.
