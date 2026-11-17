{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPubMedAbstracts;

{$mode delphi}
{$H+}

uses
  Windows, Classes, SysUtils, Math, DOM, XMLRead, foodexperiment.externaldata, foodexperiment.https;

const
  Tab = #9;
  BatchSize = 60;
  RequestSpacingMs = 400;
  MaximumAttempts = 4;

type
  TAbstractRun = class
  private
    FClient: TEuropePmc;
    FIds: TStringList;
    FRecords: TFileStream;
    FAudit: TFileStream;
    FNextRequest: QWord;
    FContactParameter: UTF8String;
    FIncomplete: Integer;
    procedure LoadIds(const APath: String);
    function Fetch(const AIds: UTF8String): UTF8String;
    procedure FetchBatch(AOffset, ACount, ABatch: Integer);
  public
    constructor Create(const ARecordsPath, AOutputDir: String);
    destructor Destroy; override;
    procedure Run;
  end;

procedure WriteLine(AStream: TStream; const AValue: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := AValue + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

constructor TAbstractRun.Create(const ARecordsPath, AOutputDir: String);
var
  LOutput: String;
  LEmail: UTF8String;
begin
  inherited Create;
  FIds := TStringList.Create;
  FIds.Sorted := True;
  FIds.Duplicates := dupError;
  LoadIds(ARecordsPath);
  LOutput := IncludeTrailingPathDelimiter(AOutputDir);
  if not ForceDirectories(LOutput) then
  begin
    raise EInOutError.Create('Cannot create output directory ' + LOutput);
  end;
  FRecords := TFileStream.Create(LOutput + 'pubmed_novel_abstracts.tsv', fmCreate or fmShareDenyWrite);
  FAudit := TFileStream.Create(LOutput + 'pubmed_abstract_batches.tsv', fmCreate or fmShareDenyWrite);
  WriteLine(FRecords, 'source_key'#9'pmid'#9'status'#9'abstract');
  WriteLine(FAudit, 'batch_id'#9'searched_utc'#9'pmids'#9'requested'#9'retrieved'#9'status'#9'error');
  LEmail := Trim(GetEnvironmentVariable('NCBI_EMAIL'));
  if LEmail <> '' then
  begin
    FContactParameter := '&email=' + UrlEncode(LEmail);
  end;
  FClient := TEuropePmc.Create('eutils.ncbi.nlm.nih.gov');
end;

destructor TAbstractRun.Destroy;
begin
  FClient.Free;
  FAudit.Free;
  FRecords.Free;
  FIds.Free;
  inherited Destroy;
end;

procedure TAbstractRun.LoadIds(const APath: String);
var
  LFile: Text;
  LLine: UTF8String;
  LFields: TFields;
  LCharacter: Char;
begin
  AssignFile(LFile, APath);
  Reset(LFile);
  try
    ReadLn(LFile, LLine);
    if LLine <> 'source_key'#9'pmid'#9'doi'#9'pmcid'#9'title'#9'journal'#9 +
      'publication_date'#9'publication_types'#9'has_abstract'#9'europe_pmc_overlap' then
    begin
      raise EConvertError.Create('Unexpected PubMed ESummary result header');
    end;
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      LFields := SplitFields(LLine, Tab);
      if (Length(LFields) <> 10) or (LFields[1] = '') or (LFields[0] <> 'PMID:' + LFields[1]) then
      begin
        raise EConvertError.Create('Malformed PubMed ESummary result');
      end;
      if LFields[9] <> 'Novel' then Continue;
      for LCharacter in LFields[1] do
      begin
        if not (LCharacter in ['0'..'9']) then
        begin
          raise EConvertError.Create('Invalid PMID in PubMed ESummary results');
        end;
      end;
      FIds.Add(LFields[1]);
    end;
  finally
    CloseFile(LFile);
  end;
end;

function TAbstractRun.Fetch(const AIds: UTF8String): UTF8String;
var
  LNow: QWord;
  LResponse: TSearchResponse;
  LError: String;
  I: Integer;
begin
  LError := '';
  for I := 1 to MaximumAttempts do
  begin
    LNow := GetTickCount64;
    if FNextRequest > LNow then
    begin
      Sleep(FNextRequest - LNow);
    end;
    FNextRequest := GetTickCount64 + RequestSpacingMs;
    try
      LResponse := FClient.GetPath('/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml' +
        '&tool=beat_parkinsons_food_experiment&id=' + AIds + FContactParameter);
      if LResponse.Status = 200 then Exit(LResponse.Body);
      LError := 'NCBI HTTP ' + IntToStr(LResponse.Status);
      if LResponse.Status = 429 then
      begin
        FNextRequest := GetTickCount64 + Max(2000, Min(60, LResponse.RetryAfterSeconds) * 1000);
      end
      else if (LResponse.Status <> 408) and (LResponse.Status < 500) then
      begin
        Break;
      end;
    except
      on LException: Exception do LError := LException.Message;
    end;
    if I < MaximumAttempts then Sleep(1000 shl (I - 1));
  end;
  raise EInOutError.Create(LError);
end;

function Child(ANode: TDOMNode; const AName: DOMString): TDOMNode;
begin
  Result := nil;
  if Assigned(ANode) then Result := ANode.FindNode(AName);
end;

function TextValue(ANode: TDOMNode): UTF8String;
begin
  Result := '';
  if Assigned(ANode) then Result := CleanField(UTF8Encode(ANode.TextContent));
end;

function AbstractValue(ARoot: TDOMNode): UTF8String;
var
  LNode: TDOMNode;
  LText: UTF8String;
  LLabel: UTF8String;
begin
  Result := '';
  if not Assigned(ARoot) then Exit;
  LNode := ARoot.FirstChild;
  while Assigned(LNode) do
  begin
    if LNode.NodeName = 'AbstractText' then
    begin
      LText := TextValue(LNode);
      if LText <> '' then
      begin
        if Result <> '' then Result := Result + ' ';
        LLabel := CleanField(UTF8Encode(TDOMElement(LNode).GetAttribute('Label')));
        if LLabel <> '' then Result := Result + LLabel + ': ';
        Result := Result + LText;
      end;
    end;
    LNode := LNode.NextSibling;
  end;
end;

procedure TAbstractRun.FetchBatch(AOffset, ACount, ABatch: Integer);
var
  LDocument: TXMLDocument;
  LNode: TDOMNode;
  LMetadata: TDOMNode;
  LAbstract: TDOMNode;
  LStream: TStringStream;
  LRequested: TStringList;
  LReturned: TStringList;
  LIds: UTF8String;
  LPmid: UTF8String;
  LText: UTF8String;
  LTimestamp: UTF8String;
  LStatus: UTF8String;
  LError: UTF8String;
  I: Integer;
begin
  LRequested := TStringList.Create;
  LReturned := TStringList.Create;
  try
    LIds := '';
    for I := 0 to ACount - 1 do
    begin
      LPmid := FIds[AOffset + I];
      LRequested.Add(LPmid);
      if LIds <> '' then LIds := LIds + ',';
      LIds := LIds + LPmid;
    end;
    LTimestamp := UtcTimestamp;
    LError := '';
    try
      LStream := TStringStream.Create(Fetch(LIds));
      try
        ReadXMLFile(LDocument, LStream);
        try
          if not Assigned(LDocument.DocumentElement) or
            (LDocument.DocumentElement.NodeName <> 'PubmedArticleSet') then
          begin
            raise EConvertError.Create('Unexpected PubMed EFetch XML root');
          end;
          LNode := LDocument.DocumentElement.FirstChild;
          while Assigned(LNode) do
          begin
            LMetadata := nil;
            LAbstract := nil;
            if LNode.NodeName = 'PubmedArticle' then
            begin
              LMetadata := Child(LNode, 'MedlineCitation');
              LAbstract := Child(Child(LMetadata, 'Article'), 'Abstract');
            end
            else if LNode.NodeName = 'PubmedBookArticle' then
            begin
              LMetadata := Child(LNode, 'BookDocument');
              LAbstract := Child(LMetadata, 'Abstract');
            end;
            if Assigned(LMetadata) then
            begin
              LPmid := TextValue(Child(LMetadata, 'PMID'));
              if (LRequested.IndexOf(LPmid) < 0) or (LReturned.IndexOf(LPmid) >= 0) then
              begin
                raise EConvertError.Create('Unexpected or repeated EFetch PMID ' + LPmid);
              end;
              LText := AbstractValue(LAbstract);
              if LText = '' then LStatus := 'NoAbstract' else LStatus := 'Retrieved';
              WriteLine(FRecords, 'PMID:' + LPmid + Tab + LPmid + Tab + LStatus + Tab + LText);
              LReturned.Add(LPmid);
            end;
            LNode := LNode.NextSibling;
          end;
          for LPmid in LRequested do
          begin
            if LReturned.IndexOf(LPmid) >= 0 then Continue;
            if LError <> '' then LError := LError + ', ';
            LError := LError + LPmid;
          end;
          if LError <> '' then LError := 'Missing EFetch PMID ' + LError;
        finally
          LDocument.Free;
        end;
      finally
        LStream.Free;
      end;
    except
      on LException: Exception do LError := CleanField(LException.Message);
    end;
    if (LReturned.Count = ACount) and (LError = '') then
    begin
      LStatus := 'Retrieved';
    end
    else
    begin
      if LReturned.Count = 0 then LStatus := 'Failed' else LStatus := 'Partial';
      Inc(FIncomplete);
    end;
    WriteLine(FAudit, IntToStr(ABatch) + Tab + LTimestamp + Tab + LIds + Tab +
      IntToStr(ACount) + Tab + IntToStr(LReturned.Count) + Tab + LStatus + Tab + LError);
  finally
    LReturned.Free;
    LRequested.Free;
  end;
end;

procedure TAbstractRun.Run;
var
  LOffset: Integer;
  LCount: Integer;
  LBatch: Integer;
begin
  LOffset := 0;
  LBatch := 0;
  while LOffset < FIds.Count do
  begin
    LCount := Min(BatchSize, FIds.Count - LOffset);
    Inc(LBatch);
    FetchBatch(LOffset, LCount, LBatch);
    Inc(LOffset, LCount);
  end;
  WriteLn(FIds.Count, ' novel PMIDs, ', LBatch, ' EFetch batches, ', FIncomplete, ' incomplete');
  if FIncomplete > 0 then ExitCode := 2;
end;

procedure Run;
var
  LRun: TAbstractRun;
begin
  if ParamCount <> 2 then
  begin
    raise EConvertError.Create('Usage: foodexperiment.pubmedabstracts <record-tsv> <output-dir>');
  end;
  LRun := TAbstractRun.Create(ExpandFileName(ParamStr(1)), ExpandFileName(ParamStr(2)));
  try
    LRun.Run;
  finally
    LRun.Free;
  end;
end;

begin
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      ExitCode := 1;
    end;
  end;
end.
