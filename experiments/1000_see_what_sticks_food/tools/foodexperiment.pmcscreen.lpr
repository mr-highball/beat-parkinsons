{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPmcScreen;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata, foodexperiment.pmcxml;

const
  CProposalHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9 +
    'local_reference'#9'rationale';
  CReportHeader = 'id'#9'source_key'#9'pmcid'#9'ingredient'#9'symptom'#9'status'#9 +
    'xml_pmid'#9'body_chars'#9'title_abs_hits'#9'body_hits'#9'meta_back_hits'#9 +
    'matched_terms'#9'snippet';

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function ReadUtf8(const APath: String): String;
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(LBytes, Integer(LStream.Size));
    if LBytes <> '' then
    begin
      LStream.ReadBuffer(LBytes[1], Length(LBytes));
    end;
    Result := String(LBytes);
  finally
    LStream.Free;
  end;
end;

procedure WriteUtf8(const APath: String; const AText: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function ColIdx(const AHeader: TFields; const AName: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AHeader) do
  begin
    if AHeader[I] = AName then
    begin
      Exit(I);
    end;
  end;
  raise EConvertError.Create('Missing TSV column: ' + AName);
end;

function SanitizeCell(const AText: String): String;
begin
  Result := StringReplace(AText, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

procedure RunScreen(const AQueuePath, AXmlDir, AOutProposalsPath, AOutReportPath,
  AReaderDir: String);
var
  LFile: TextFile;
  LBuf: array[0..65535] of Byte;
  LLine: UTF8String;
  LHeader, LFields: TFields;
  CId, CSource, CIng, CSym, CPmid, CPmcid, CDoi: Integer;
  LId, LSource, LIng, LSym, LPmid, LPmcid, LInputPath, LContent, LRationale: String;
  LRes: TPmcScreenResult;
  LProposals, LReport: TStringBuilder;
  LReader: Boolean;
  LTotalXml, LTotalReader, LZeroBody, LBodyMatch, LNoBody, LMismatch, LCollection: Integer;
begin
  Require(FileExists(AQueuePath), 'Missing context queue: ' + AQueuePath);
  Require(DirectoryExists(AXmlDir), 'Missing XML directory: ' + AXmlDir);
  Require((AReaderDir = '') or DirectoryExists(AReaderDir),
    'Missing reader directory: ' + AReaderDir);

  LProposals := TStringBuilder.Create;
  LReport := TStringBuilder.Create;
  AssignFile(LFile, AQueuePath);
  SetTextBuf(LFile, LBuf);
  Reset(LFile);
  try
    Require(not Eof(LFile), 'Empty context queue: ' + AQueuePath);
    ReadLn(LFile, LLine);
    LHeader := SplitFields(String(LLine), #9);
    CId := ColIdx(LHeader, 'id');
    CSource := ColIdx(LHeader, 'source_key');
    CIng := ColIdx(LHeader, 'ingredient');
    CSym := ColIdx(LHeader, 'symptom');
    CPmid := ColIdx(LHeader, 'pmid');
    CPmcid := ColIdx(LHeader, 'pmcid');
    if AReaderDir <> '' then
      CDoi := ColIdx(LHeader, 'doi')
    else
      CDoi := -1;

    LProposals.Append(CProposalHeader).Append(#10);
    LReport.Append(CReportHeader).Append(#10);

    LTotalXml := 0;
    LTotalReader := 0;
    LZeroBody := 0;
    LBodyMatch := 0;
    LNoBody := 0;
    LMismatch := 0;
    LCollection := 0;

    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      if LLine = '' then
      begin
        Continue;
      end;
      LFields := SplitFields(String(LLine), #9);
      if Length(LFields) <= CPmcid then
      begin
        Continue;
      end;
      LPmcid := Trim(LFields[CPmcid]);
      if LPmcid = '' then
      begin
        Continue;
      end;
      LInputPath := IncludeTrailingPathDelimiter(AXmlDir) + LPmcid + '.xml';
      LReader := False;
      if not FileExists(LInputPath) then
      begin
        if (AReaderDir = '') or (Length(LFields) <= CDoi) then
          Continue;
        LInputPath := IncludeTrailingPathDelimiter(AReaderDir) + LPmcid + '.html';
        if not FileExists(LInputPath) then
          Continue;
        LReader := True;
      end;

      LId := Trim(LFields[CId]);
      LSource := Trim(LFields[CSource]);
      LIng := Trim(LFields[CIng]);
      LSym := Trim(LFields[CSym]);
      LPmid := Trim(LFields[CPmid]);
      if (LPmid = '') and StartsText('PMID:', LSource) then
      begin
        LPmid := Copy(LSource, 6, MaxInt);
      end;

      LContent := ReadUtf8(LInputPath);
      if LReader then
      begin
        Inc(LTotalReader);
        LRes := ScreenPmcReaderHtml(LContent, LPmcid, LPmid, Trim(LFields[CDoi]), LIng);
      end
      else
      begin
        Inc(LTotalXml);
        LRes := ScreenPmcJatsXml(LContent, LPmid, LIng);
      end;

      case LRes.Kind of
        pkNoBody: Inc(LNoBody);
        pkPmidMismatch: Inc(LMismatch);
        pkCollectionHold: Inc(LCollection);
        pkZeroBodyCollision:
        begin
          Inc(LZeroBody);
          { Reader output is a triage report. Human review establishes full source scope. }
          if not LReader then
          begin
            if LRes.MetaBackHits > 0 then
            begin
              LRationale := 'Verified full-text NCBI PMC JATS XML (' + LPmcid +
                ') contains zero mentions of ' + LIng +
                ' or its botanical/constituent aliases in title, abstract, or body (' +
                IntToStr(LRes.BodyChars) + ' body chars); lexical hit (' +
                LRes.MatchedTerms + ') occurs strictly in front metadata or back references.';
            end
            else
            begin
              LRationale := 'Verified full-text NCBI PMC JATS XML (' + LPmcid +
              ') contains zero mentions of ' + LIng +
              ' or its botanical/constituent aliases across title, abstract, or body (' +
              IntToStr(LRes.BodyChars) + ' body chars).';
            end;
            LProposals.Append(LId).Append(#9)
              .Append(LSource).Append(#9)
              .Append('excluded').Append(#9)
              .Append('full_text').Append(#9)
              .Append('https://pmc.ncbi.nlm.nih.gov/articles/').Append(LPmcid).Append('/').Append(#9)
              .Append(SanitizeCell(LRationale)).Append(#10);
          end;
        end;
        pkBodyMatch: Inc(LBodyMatch);
      end;

      LReport.Append(LId).Append(#9)
        .Append(LSource).Append(#9)
        .Append(LPmcid).Append(#9)
        .Append(LIng).Append(#9)
        .Append(LSym).Append(#9)
        .Append(PmcScreenKindName(LRes.Kind)).Append(#9)
        .Append(LRes.XmlPmid).Append(#9)
        .Append(IntToStr(LRes.BodyChars)).Append(#9)
        .Append(IntToStr(LRes.TitleAbsHits)).Append(#9)
        .Append(IntToStr(LRes.BodyHits)).Append(#9)
        .Append(IntToStr(LRes.MetaBackHits)).Append(#9)
        .Append(SanitizeCell(LRes.MatchedTerms)).Append(#9);
      if LRes.Kind = pkBodyMatch then
      begin
        LReport.Append(SanitizeCell(LRes.BodySnippet)).Append(#10);
      end
      else
      begin
        LReport.Append(SanitizeCell(LRes.MetaBackSnippet)).Append(#10);
      end;
    end;

    WriteUtf8(AOutProposalsPath, UTF8String(LProposals.ToString));
    WriteUtf8(AOutReportPath, UTF8String(LReport.ToString));
    WriteLn('PMC_SCREEN pairs_with_xml=', LTotalXml,
      ' zero_body_collision=', LZeroBody,
      ' body_match=', LBodyMatch,
      ' collection_hold=', LCollection,
      ' pmid_mismatch=', LMismatch,
      ' no_body=', LNoBody,
      ' reader_pairs=', LTotalReader);
  finally
    CloseFile(LFile);
    LReport.Free;
    LProposals.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    if not (ParamCount in [4, 5]) then
    begin
      WriteLn(StdErr,
        'Usage: foodexperiment.pmcscreen <context-queue.tsv> <xml-dir> <out-proposals.tsv> <out-report.tsv> [reader-html-dir]');
      Halt(1);
    end;
    RunScreen(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4), ParamStr(5));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
