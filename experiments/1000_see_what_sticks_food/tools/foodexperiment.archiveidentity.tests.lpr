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

  LPath := GetTempFileName;
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
