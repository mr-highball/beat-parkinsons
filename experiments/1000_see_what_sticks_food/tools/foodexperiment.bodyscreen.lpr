{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.bodyscreen;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata, foodexperiment.matching;

const
  CExpectedHeader = 'pmcid'#9'pmid'#9'doi';
  CCaptureHeader = 'pmcid'#9'pmid'#9'doi'#9'title'#9'bytes'#9'sha256'#9'sections';
  CScreenHeader = 'pmcid'#9'identity'#9'extracted_body'#9'paragraphs'#9'table_rows'#9 +
    'body_topics'#9'reference_topics'#9'captured_article_sha256';

function IsPmcid(const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (Length(AValue) <= 3) or not StartsStr('PMC', AValue) then
  begin
    Exit;
  end;
  for LIndex := 4 to Length(AValue) do
  begin
    if not (AValue[LIndex] in ['0'..'9']) then
    begin
      Exit;
    end;
  end;
  Result := True;
end;

function BodyHeading(const AHeading: String): Boolean;
var
  LStart: Integer;
  LTitle: String;
begin
  LStart := 1;
  while (LStart <= Length(AHeading)) and (AHeading[LStart] in ['0'..'9', '.', ' ']) do
  begin
    Inc(LStart);
  end;
  LTitle := Copy(AHeading, LStart, MaxInt);
  Result := StartsText('Introduction', LTitle) or StartsText('Methods', LTitle) or
    StartsText('Materials', LTitle) or StartsText('Results', LTitle) or
    StartsText('Discussion', LTitle) or StartsText('Conclusion', LTitle);
end;

function SameIdentity(const AExpected, ACapture: TFields): Boolean;
begin
  Result := (Length(ACapture) = 7) and (ACapture[3] <> '') and (ACapture[5] <> '') and
    ((AExpected[1] = '') or (AExpected[1] = ACapture[1])) and
    ((AExpected[2] = '') or SameText(AExpected[2], ACapture[2]));
end;

function ScreenText(const AFileName: String; AMatcher: TMatcher; ATopics: TStrings): String;
var
  LRows: TStringList;
  LBodyMatches: TMatchFlags;
  LReferenceMatches: TMatchFlags;
  LRecord: String;
  LTag: String;
  LValue: String;
  LSeparator: Integer;
  LParagraphs: Integer;
  LTableRows: Integer;
  LReferences: Boolean;
  LHasHeading: Boolean;
  LPdfOnly: Boolean;
  LState: String;
begin
  if not FileExists(AFileName) then
  begin
    Exit('missing'#9'0'#9'0'#9#9);
  end;
  LRows := TStringList.Create;
  try
    LRows.LoadFromFile(AFileName, TEncoding.UTF8);
    SetLength(LBodyMatches, ATopics.Count);
    SetLength(LReferenceMatches, ATopics.Count);
    LReferences := False;
    LHasHeading := False;
    LPdfOnly := False;
    LParagraphs := 0;
    LTableRows := 0;
    for LRecord in LRows do
    begin
      LSeparator := Pos(#9, LRecord);
      if LSeparator = 0 then
      begin
        Continue;
      end;
      LTag := Copy(LRecord, 1, LSeparator - 1);
      LValue := Copy(LRecord, LSeparator + 1, MaxInt);
      if (LTag = 'h2') or (LTag = 'h3') then
      begin
        if SameText(LValue, 'References') or SameText(LValue, 'Selected References') or
          SameText(LValue, 'Bibliography') then
        begin
          LReferences := True;
          Continue;
        end;
        // Structured abstracts may have h3 methods and results without an article body.
        LHasHeading := LHasHeading or ((LTag = 'h2') and BodyHeading(LValue));
      end;
      if LReferences then
      begin
        AMatcher.Match(LValue, LReferenceMatches);
        Continue;
      end;
      LPdfOnly := LPdfOnly or ContainsText(LValue, 'Full Text of this article is available as a PDF');
      Inc(LParagraphs, Ord((LTag = 'p') and (Length(LValue) >= 80)));
      Inc(LTableRows, Ord(LTag = 'tr'));
      AMatcher.Match(LValue, LBodyMatches);
    end;
    LState := 'inspect_structure';
    if (not LPdfOnly) and LHasHeading and (LParagraphs > 0) then
    begin
      LState := 'structured';
    end
    else if LPdfOnly then
    begin
      LState := 'pdf_only';
    end;
    Result := LState + #9 + IntToStr(LParagraphs) + #9 + IntToStr(LTableRows) + #9 +
      JoinMatches(ATopics, LBodyMatches, 0) + #9 + JoinMatches(ATopics, LReferenceMatches, 0);
  finally
    LRows.Free;
  end;
end;

procedure Run(const AExpected, AInventory, ABodyDir, ATerms, AOutput: String);
var
  LExpected: TStringList;
  LCaptures: TStringList;
  LIndex: TStringList;
  LTopics: TStringList;
  LOutput: TStringList;
  LMatcher: TMatcher;
  LSeen: TStringList;
  LWant: TFields;
  LCapture: TFields;
  LRow: Integer;
  LPosition: Integer;
  LId: String;
  LStatus: String;
begin
  LExpected := TStringList.Create;
  LCaptures := TStringList.Create;
  LIndex := TStringList.Create;
  LTopics := TStringList.Create;
  LOutput := TStringList.Create;
  LMatcher := TMatcher.Create;
  LSeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupError;
    LIndex.Sorted := True;
    LIndex.Duplicates := dupError;
    LIndex.CaseSensitive := True;
    LExpected.LoadFromFile(AExpected, TEncoding.UTF8);
    LCaptures.LoadFromFile(AInventory, TEncoding.UTF8);
    if (LExpected.Count < 2) or (LExpected[0] <> CExpectedHeader) or
      (LCaptures.Count < 1) or (LCaptures[0] <> CCaptureHeader) then
    begin
      raise EConvertError.Create('Unexpected original-source identity headers');
    end;
    for LRow := 1 to LCaptures.Count - 1 do
    begin
      LCapture := SplitFields(LCaptures[LRow], #9);
      if (Length(LCapture) <> 7) or not IsPmcid(LCapture[0]) then
      begin
        raise EConvertError.CreateFmt('Invalid captured identity at row %d', [LRow + 1]);
      end;
      LIndex.AddObject(LCapture[0], TObject(PtrInt(LRow)));
    end;
    LoadTermGroups(ATerms, LMatcher, LTopics);
    LOutput.Add(CScreenHeader);
    for LRow := 1 to LExpected.Count - 1 do
    begin
      LWant := SplitFields(LExpected[LRow], #9);
      if (Length(LWant) <> 3) or not IsPmcid(LWant[0]) or
        ((LWant[1] = '') and (LWant[2] = '')) then
      begin
        raise EConvertError.CreateFmt('Invalid expected identity at row %d', [LRow + 1]);
      end;
      LId := LWant[0];
      LSeen.Add(LId);
      LCapture := nil;
      if LIndex.Find(LId, LPosition) then
      begin
        LCapture := SplitFields(LCaptures[PtrInt(LIndex.Objects[LPosition])], #9);
      end;
      if SameIdentity(LWant, LCapture) then
      begin
        LStatus := ScreenText(IncludeTrailingPathDelimiter(ABodyDir) + LId + '.screen.txt',
          LMatcher, LTopics);
        LOutput.Add(LId + #9'match'#9 + LStatus + #9 + LCapture[5]);
      end
      else
      begin
        LOutput.Add(LId + #9'unverified'#9'withheld'#9'0'#9'0'#9#9#9'-');
      end;
    end;
    LOutput.LineBreak := #10;
    LOutput.SaveToFile(AOutput, TEncoding.UTF8);
    WriteLn('Screened ', LExpected.Count - 1, ' expected article identities.');
  finally
    LSeen.Free;
    LMatcher.Free;
    LOutput.Free;
    LTopics.Free;
    LIndex.Free;
    LCaptures.Free;
    LExpected.Free;
  end;
end;

begin
  if ParamCount <> 5 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.bodyscreen expected.tsv capture.tsv body-dir ' +
      'topics.tsv screening.tsv');
    Halt(1);
  end;
  try
    Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
