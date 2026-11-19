{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TestCatalogSourceKinds;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, fpjson, parkinsonsoracle.catalog;

const
  CCulture = 'research/2020-2024/Cultural-and-Experiential/';
  CForum = CCulture + 'Conversations/a.txt';
  CSecondForum = CCulture + 'Conversations/b.txt';
  COlderForum = 'research/2015-2019/Cultural-and-Experiential/Conversations/c.txt';
  CHistorical = 'research/1595-1599/Cultural-and-Experiential/Traditional-Practices/d.txt';
  CCeremony = CCulture + 'Ceremonial-Accounts/e.txt';
  CPersonal = CCulture + 'Personal-Reports/f.txt';
  CLocal = CCulture + 'Local-Knowledge/g.txt';
  CArchive = 'research/2020-2024/Source-Text/article.txt';
  CText = 'coffee tremor conversation cultural experiential';
  CForumText = 'Title: Discussion citing a paper'#10 +
    'Source: https://example.org/pmc.ncbi.nlm.nih.gov/articles/PMC85000001/'#10 +
    'PMID: 85000001'#10'PMCID: PMC85000001'#10#10 + CText;

var
  GRoot: String;
  GChecks: Integer;

procedure Put(const ARelative: String; const AText: UTF8String = CText);
var
  LPath: String;
  LStream: TFileStream;
begin
  LPath := GRoot + ARelative;
  if not ForceDirectories(ExtractFileDir(LPath)) then
  begin
    raise EInOutError.Create('Cannot create the source fixture directory.');
  end;
  LStream := TFileStream.Create(LPath, fmCreate);
  try
    LStream.WriteBuffer(AText[1], Length(AText));
  finally
    LStream.Free;
  end;
end;

procedure CheckPage(ACatalog: TResearchCatalog; const AKind, APeriod: String;
  AOffset, ALimit, ATotal, ANext: Integer; const APaths: array of String);
var
  LPage: TJSONObject;
  LMatches: TJSONArray;
  LIndex: Integer;
  LNext: TJSONData;
begin
  LPage := ACatalog.Search('coffee tremor', APeriod, AOffset, ALimit, AKind);
  try
    LMatches := LPage.Arrays['matches'];
    LNext := LPage.Find('next_offset');
    if (LPage.Integers['total'] <> ATotal) or (LMatches.Count <> Length(APaths)) or
      ((ANext < 0) and not LNext.IsNull) or ((ANext >= 0) and (LNext.AsInteger <> ANext)) then
    begin
      raise Exception.Create('Incorrect catalog scope or page for ' + AKind);
    end;
    for LIndex := 0 to LMatches.Count - 1 do
    begin
      if LMatches.Objects[LIndex].Strings['path'] <> APaths[LIndex] then
      begin
        raise Exception.Create('Unexpected source path for ' + AKind);
      end;
    end;
    Inc(GChecks);
  finally
    LPage.Free;
  end;
end;

procedure CheckIdentifier(ACatalog: TResearchCatalog; const AIdentifier, APath: String);
var
  LIds: TJSONArray;
  LResult: TJSONObject;
  LMatches: TJSONArray;
begin
  LIds := TJSONArray.Create([AIdentifier]);
  try
    LResult := ACatalog.FindSources(LIds);
    try
      LMatches := LResult.Arrays['results'].Objects[0].Arrays['matches'];
      if APath = '' then
      begin
        if LMatches.Count <> 0 then
        begin
          raise Exception.Create('Unexpected exact source for ' + AIdentifier);
        end;
      end
      else if (LMatches.Count <> 1) or (LMatches.Objects[0].Strings['path'] <> APath) then
      begin
        raise Exception.Create('Missing exact source for ' + AIdentifier);
      end;
      Inc(GChecks);
    finally
      LResult.Free;
    end;
  finally
    LIds.Free;
  end;
end;

procedure Run;
var
  LCatalog: TResearchCatalog;
begin
  if (ParamCount <> 1) or (ParamStr(1) = '') or DirectoryExists(ParamStr(1)) or
    FileExists(ParamStr(1)) then
  begin
    raise EArgumentException.Create('Pass a fresh fixture directory under the build output.');
  end;
  GRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  Put(CForum, CForumText);
  Put(COlderForum);
  Put(CHistorical);
  Put(CCeremony);
  Put(CPersonal);
  Put(CLocal, 'Title: Published food use in local knowledge'#10 +
    'Source: https://pmc.ncbi.nlm.nih.gov/articles/PMC85000001/'#10 +
    'PMID: 85000001'#10'PMCID: PMC85000001'#10'DOI: 10.1234/food-use'#10#10 + CText);
  Put(CArchive);
  Put(CCulture + 'README.md');
  Put('research/Cultural-and-Experiential.md');
  Put('research/2020-2024/Observations/Cultural-and-Experiential/Conversations/note.txt');

  LCatalog := TResearchCatalog.Create(GRoot, GRoot + 'catalog.sqlite3');
  try
    LCatalog.Refresh;
    CheckPage(LCatalog, 'all', '', 0, 1, 10, 1, [CHistorical]);
    CheckPage(LCatalog, 'conversations', '', 0, 1, 2, 1, [COlderForum]);
    CheckPage(LCatalog, 'cultural', '', 0, 2, 6, 2, [CHistorical, COlderForum]);
    CheckPage(LCatalog, 'conversations', '', 1, 1, 2, -1, [CForum]);
    CheckPage(LCatalog, 'conversations', '2020-2024', 0, 2, 1, -1, [CForum]);
    CheckPage(LCatalog, 'conversations', '1595-1599', 0, 2, 0, -1, []);
    CheckPage(LCatalog, 'traditional_practices', '1595-1599', 0, 2, 1, -1, [CHistorical]);
    CheckPage(LCatalog, 'ceremonial_accounts', '', 0, 2, 1, -1, [CCeremony]);
    CheckPage(LCatalog, 'personal_reports', '', 0, 2, 1, -1, [CPersonal]);
    CheckPage(LCatalog, 'local_knowledge', '', 0, 2, 1, -1, [CLocal]);
    CheckPage(LCatalog, 'source_text', '2020-2024', 0, 2, 1, -1, [CArchive]);
    CheckIdentifier(LCatalog, 'PMID:85000001', CLocal);
    CheckIdentifier(LCatalog, 'PMCID:PMC85000001', CLocal);
    CheckIdentifier(LCatalog, 'DOI:10.1234/food-use', CLocal);

    CheckPage(LCatalog, 'conversations', '2020-2024', 0, 2, 1, -1, [CForum]);
    Put(CSecondForum, CForumText);
    Put(CLocal, 'Title: Revised published source'#10 +
      'Source: https://pubmed.ncbi.nlm.nih.gov/85000002/'#10'PMID: 85000002'#10#10 + CText);
    LCatalog.Refresh;
    CheckPage(LCatalog, 'conversations', '2020-2024', 0, 2, 2, -1, [CForum, CSecondForum]);
    CheckIdentifier(LCatalog, 'PMID:85000002', CLocal);
    CheckIdentifier(LCatalog, 'PMID:85000001', '');
    CheckIdentifier(LCatalog, 'PMCID:PMC85000001', '');
    CheckIdentifier(LCatalog, 'DOI:10.1234/food-use', '');
  finally
    LCatalog.Free;
  end;
  WriteLn(GChecks, ' catalog category, identity, cache, period and paging checks passed.');
end;

begin
  Run;
end.
