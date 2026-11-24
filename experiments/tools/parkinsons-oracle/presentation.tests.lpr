{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program PresentationTests;

{$mode delphi}
{$H+}

uses
  SysUtils, parkinsonsoracle.presentation;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AName: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AName);
  end;
  Inc(GChecks);
end;

procedure Run;
var
  LPaths: array of String;
  LSelection: TSourceSelection;
  LIndex: Integer;
  LRejected: Boolean;
begin
  Check(IsCulturalSource('research/2010-2014/Cultural-and-Experiential/Traditional-Practices/a.txt'),
    'Cultural source is recognized.');
  Check(IsCulturalSource('RESEARCH\2020-2024\Cultural-and-Experiential\Personal-Reports\b.txt'),
    'Case and Windows path separators agree.');
  Check(not IsCulturalSource('research/Cultural-and-Experiential.md'),
    'Collection policy is not an individual cultural source.');
  Check(not IsCulturalSource('research/2020-2024/Source-Text/a.txt'),
    'Formal archive remains separate.');
  Check(IsConversationSource('RESEARCH\2025-2029\Cultural-and-Experiential\Conversations\c.txt'),
    'Conversation records use the same portable path rules.');
  Check(not IsConversationSource(
    'research/2025-2029/Cultural-and-Experiential/Personal-Reports/Conversations/c.txt'),
    'Only the conversational collection receives the badge.');
  Check(MatchesSourceKind('research/2025-2029/Cultural-and-Experiential/Conversations/c.txt',
    SourceKindCulture) and not MatchesSourceKind(
    'research/2025-2029/Cultural-and-Experiential/Conversations/c.txt', SourceKindStudies),
    'Conversations belong to the cultural results scope.');
  Check(RelatedSourceTerms('', 'rest tremor severity', SourceKindAll) = 'tremor',
    'Broader tremor sources remain discoverable.');
  Check(RelatedSourceTerms('mucuna', 'rest tremor severity', SourceKindCulture) =
    'mucuna tremor cultural experiential', 'Cultural lookup includes collection metadata.');
  Check(RelatedSourceTerms('', '', SourceKindCulture) = '', 'Do not issue an empty lookup.');
  Check(FormatCulturalBadgeCount(-3) = '0', 'Negative counts clamp to 0.');
  Check(FormatCulturalBadgeCount(0) = '0', 'Zero cultural sources formats as 0.');
  Check(FormatCulturalBadgeCount(7) = '7', 'Small cultural count renders exact number.');
  Check(FormatCulturalBadgeCount(99) = '99', 'Ninety-nine cultural sources stays exact.');
  Check(FormatCulturalBadgeCount(100) = '99+', 'One hundred cultural sources caps at 99+.');
  Check(FormatCulturalBadgeCount(312) = '99+', 'Large cultural counts cap at 99+.');
  Check(GitHubRawURL('https://github.com/example-org/sample-repo', 'abc1234',
    'research/2000-2004/Cultural-and-Experiential/Traditional-Practices/2002-Sage.txt') =
    'https://raw.githubusercontent.com/example-org/sample-repo/abc1234/research/2000-2004/Cultural-and-Experiential/Traditional-Practices/2002-Sage.txt',
    'GitHubRawURL maps research paths to raw.githubusercontent.com.');
  Check(GitHubRawURL('https://github.com/example-org/sample-repo.git/', 'main',
    'research/2020-2024/Notes With Spaces.md#section-1') =
    'https://raw.githubusercontent.com/example-org/sample-repo/main/research/2020-2024/Notes%20With%20Spaces.md',
    'GitHubRawURL strips .git, anchors and encodes spaces.');
  Check(GitHubRawURL('https://github.com/example-org/sample-repo', 'abc1234',
    'research/../README.md') = '',
    'GitHubRawURL rejects parent-directory traversal.');
  Check(GitHubRawURL('https://example.com/example-org/sample-repo', 'abc1234',
    'research/2020-2024/a.txt') = '',
    'GitHubRawURL rejects non-GitHub hosts.');
  Check(GitHubRawURL('https://github.com/example-org/sample-repo', 'abc1234',
    'experiments/file.md') = '',
    'GitHubRawURL keeps raw fetches scoped to research/.');
  SetLength(LPaths, 13);
  for LIndex := 0 to 12 do
  begin
    if LIndex < 5 then
    begin
      LPaths[LIndex] := 'research/2020-2024/Cultural-and-Experiential/Personal-Reports/a.txt';
    end
    else
    begin
      LPaths[LIndex] := 'research/2020-2024/Source-Text/a.txt';
    end;
  end;
  LSelection := SelectSourcePage(LPaths, SourceKindAll, 8);
  Check((Length(LSelection.Indices) = 8) and (LSelection.Examined = 8),
    'All-source cursor stops at the last displayed row.');
  LSelection := SelectSourcePage(LPaths, SourceKindStudies, 8);
  Check((Length(LSelection.Indices) = 8) and (LSelection.Examined = 13) and
    (LSelection.Indices[0] = 5) and (LSelection.Indices[7] = 12),
    'Study filtering does not skip candidates across source kinds.');
  LSelection := SelectSourcePage(LPaths, SourceKindCulture, 3);
  Check((Length(LSelection.Indices) = 3) and (LSelection.Examined = 3),
    'A partially consumed batch has an exact next cursor.');
  SetLength(LPaths, 100);
  for LIndex := 0 to 99 do
  begin
    LPaths[LIndex] := 'research/2020-2024/Source-Text/a.txt';
  end;
  LSelection := SelectSourcePage(LPaths, SourceKindCulture, 8);
  Check((Length(LSelection.Indices) = 0) and (LSelection.Examined = 100),
    'A page with no matching kind is fully consumed, not an end-of-search decision.');
  SetLength(LPaths, 0);
  LSelection := SelectSourcePage(LPaths, SourceKindAll, 8);
  Check((Length(LSelection.Indices) = 0) and (LSelection.Examined = 0),
    'Empty end page is explicit.');
  LRejected := False;
  try
    LSelection := SelectSourcePage(LPaths, SourceKindAll, 0);
  except
    on EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Reject a full accumulator before another request.');
  LRejected := False;
  try
    LSelection := SelectSourcePage(LPaths, 9, 8);
  except
    on EArgumentException do
    begin
      LRejected := True;
    end;
  end;
  Check(LRejected, 'Reject an unknown source kind.');
  WriteLn(GChecks, ' source-kind, query and pagination checks passed.');
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(LException.Message);
      raise;
    end;
  end;
end.
