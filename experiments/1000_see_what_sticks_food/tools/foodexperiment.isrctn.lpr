{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentIsrctn;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, Math, DOM, XMLRead, foodexperiment.https, foodexperiment.externaldata,
  foodexperiment.matching;

const
  RegistryHost = 'www.isrctn.com';
  QueryPath = '/api/query/format/default?q=';
  ParkinsonQuery = '(Parkinson OR Parkinsonism OR Parkinsonian OR "paralysis agitans"' +
    ' OR "shaking palsy")';
  { This limits the response size. Larger sets are partitioned and reconciled. }
  PartitionLimit = 50;
  NutritionTerms = 'diet|diets|dietary|nutritional|nutrition|food|foods|feeding|drink|beverage|' +
    'fibre|fiber|ketogenic|ketosis|caffeine|prebiotic|probiotic|synbiotic|supplement|' +
    'supplements|botanical|herb|herbs|herbal|spice|spices|traditional medicine|meal|meals|' +
    'plant based|fermented|vitamin|mineral|oil|oils|lipid|protein redistribution|amino acid|' +
    'starch|psyllium|ispaghula|flavonoid|antioxidant|mucuna|fava|curcumin|turmeric|saffron|' +
    'ginger|cinnamon|peppermint|polyphenol|olive|coffee|tea|coconut|phytotherapy';

type
  TIsrctnScan = class
  private
    FClient: TEuropePmc;
    FIds: TStringList;
    FLabels: TStringList;
    FMatcher: TMatcher;
    FMatches: TMatchFlags;
    FOutput: String;
    FRequests: Integer;
    FLedger: Text;
    FInventory: Text;
    FDetails: Text;
    procedure LoadTerms(const ARoot: String);
    function Retrieve(const AQuery, AKind: String; ALimit: Integer;
      out AReported: Integer): TXMLDocument;
    function CollectPartition(ALower, AUpper: TDateTime): Integer;
    procedure ReadTrial(ATrial: TDOMElement);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, AOutput: String);
  end;

function Element(AParent: TDOMNode; const AName: DOMString): TDOMElement;
begin
  Result := nil;
  if Assigned(AParent) then
  begin
    Result := AParent.FindNode(AName) as TDOMElement;
  end;
end;

function Cell(ANode: TDOMNode): UTF8String;
var
  LChild: TDOMNode;
begin
  Result := '';
  if not Assigned(ANode) then
  begin
    Exit;
  end;
  if ANode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE] then
  begin
    Exit(CleanField(UTF8Encode(ANode.NodeValue)));
  end;
  LChild := ANode.FirstChild;
  while Assigned(LChild) do
  begin
    if Result <> '' then
    begin
      Result := Result + ' ';
    end;
    Result := Result + Cell(LChild);
    LChild := LChild.NextSibling;
  end;
  Result := Trim(Result);
end;

function SearchDate(AValue: TDateTime): String;
begin
  Result := FormatDateTime('yyyy-mm-dd"T00:00:00"', AValue);
end;

constructor TIsrctnScan.Create;
begin
  inherited Create;
  FClient := TEuropePmc.Create(RegistryHost);
  FIds := TStringList.Create;
  FIds.Sorted := True;
  FIds.Duplicates := dupError;
  FLabels := TStringList.Create;
  FMatcher := TMatcher.Create;
end;

destructor TIsrctnScan.Destroy;
begin
  FMatcher.Free;
  FLabels.Free;
  FIds.Free;
  FClient.Free;
  inherited Destroy;
end;

procedure TIsrctnScan.LoadTerms(const ARoot: String);
var
  LRows: TStringList;
  LParts: TFields;
  LTerm: String;
  LRow: Integer;
  LIndex: Integer;
begin
  LRows := TStringList.Create;
  try
    for LTerm in SplitFields(NutritionTerms, '|') do
    begin
      FMatcher.Add(LTerm, FLabels.Add(LTerm));
    end;
    LRows.Text := ReadBytes(ARoot + 'ingredients.tsv');
    for LRow := 1 to LRows.Count - 1 do
    begin
      LParts := SplitFields(LRows[LRow], #9);
      if Length(LParts) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [LRow + 1]);
      end;
      LIndex := FLabels.IndexOf(LParts[1]);
      if LIndex < 0 then
      begin
        LIndex := FLabels.Add(LParts[1]);
      end;
      for LTerm in SplitFields(LParts[1] + '|' + LParts[3], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
    LRows.Text := ReadBytes(ARoot + 'exposure-expansions.tsv');
    for LRow := 1 to LRows.Count - 1 do
    begin
      LParts := SplitFields(LRows[LRow], #9);
      if Length(LParts) <> 3 then
      begin
        raise EConvertError.CreateFmt('Invalid expansion row %d', [LRow + 1]);
      end;
      LIndex := FLabels.IndexOf(LParts[0]);
      if LIndex < 0 then
      begin
        raise EConvertError.CreateFmt('Unknown ingredient at expansion row %d', [LRow + 1]);
      end;
      for LTerm in SplitFields(LParts[2], '|') do
      begin
        FMatcher.Add(Trim(LTerm), LIndex);
      end;
    end;
  finally
    LRows.Free;
  end;
  SetLength(FMatches, FLabels.Count);
  FMatcher.Prepare;
end;

function TIsrctnScan.Retrieve(const AQuery, AKind: String; ALimit: Integer;
  out AReported: Integer): TXMLDocument;
var
  LPath: UTF8String;
  LResponse: TSearchResponse;
  LAttempt: Integer;
  LXml: TMemoryStream;
  LChild: TDOMNode;
  LReturned: Integer;
  LStarted: String;
  LArtifact: String;
begin
  LPath := QueryPath + UrlEncode(AQuery) + '&limit=' + IntToStr(ALimit);
  LStarted := UtcTimestamp;
  Inc(FRequests);
  for LAttempt := 0 to 2 do
  begin
    LResponse := FClient.GetPath(LPath);
    if (LResponse.Status <> 429) and (LResponse.Status < 500) then
    begin
      Break;
    end;
    if LAttempt < 2 then
    begin
      if LResponse.RetryAfterSeconds > 0 then
      begin
        Sleep(LResponse.RetryAfterSeconds * 1000);
      end
      else
      begin
        Sleep(1000 shl LAttempt);
      end;
    end;
  end;
  if LResponse.Status <> 200 then
  begin
    Write(FLedger, LStarted, #9, AKind, #9, AQuery, #9, 'https://', RegistryHost, LPath,
      #9, #9, #9, LResponse.Status, #9, #9, 'HTTP failure', #10);
    raise EInOutError.CreateFmt('ISRCTN returned HTTP %d for %s', [LResponse.Status, AQuery]);
  end;
  LArtifact := Format('isrctn-response-%.3d.xml', [FRequests]);
  LXml := TMemoryStream.Create;
  try
    if LResponse.Body = '' then
    begin
      raise EConvertError.Create('ISRCTN returned an empty response');
    end;
    LXml.WriteBuffer(LResponse.Body[1], Length(LResponse.Body));
    LXml.SaveToFile(FOutput + LArtifact);
    LXml.Position := 0;
    ReadXMLFile(Result, LXml);
  finally
    LXml.Free;
  end;
  try
    if Result.DocumentElement.NodeName <> 'allTrials' then
    begin
      raise EConvertError.Create('Expected ISRCTN allTrials document');
    end;
    AReported := StrToInt(UTF8Encode(Result.DocumentElement.GetAttribute('totalCount')));
    LReturned := 0;
    LChild := Result.DocumentElement.FirstChild;
    while Assigned(LChild) do
    begin
      if LChild.NodeName = 'fullTrial' then
      begin
        Inc(LReturned);
      end;
      LChild := LChild.NextSibling;
    end;
    Write(FLedger, LStarted, #9, AKind, #9, AQuery, #9, 'https://', RegistryHost, LPath,
      #9, AReported, #9, LReturned, #9, LResponse.Status, #9, LArtifact, #9,
      'received', #10);
    Flush(FLedger);
    if LReturned <> Min(ALimit, AReported) then
    begin
      raise EConvertError.CreateFmt('ISRCTN count mismatch for %s: %d reported, %d returned',
        [AQuery, AReported, LReturned]);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TIsrctnScan.CollectPartition(ALower, AUpper: TDateTime): Integer;
var
  LQuery: String;
  LReported: Integer;
  LDocument: TXMLDocument;
  LTrial: TDOMNode;
  LMid: TDateTime;
begin
  LQuery := ParkinsonQuery + ' AND dateApplied GE ' + SearchDate(ALower) +
    ' AND dateApplied LT ' + SearchDate(AUpper);
  LDocument := Retrieve(LQuery, 'date partition', PartitionLimit, LReported);
  try
    if LReported <= PartitionLimit then
    begin
      LTrial := LDocument.DocumentElement.FirstChild;
      while Assigned(LTrial) do
      begin
        if LTrial.NodeName = 'fullTrial' then
        begin
          ReadTrial(Element(LTrial, 'trial'));
        end;
        LTrial := LTrial.NextSibling;
      end;
      Exit(LReported);
    end;
  finally
    LDocument.Free;
  end;
  LMid := ALower + Trunc((AUpper - ALower) / 2);
  if LMid <= ALower then
  begin
    raise EConvertError.CreateFmt('ISRCTN date partition cannot be split further: %s', [LQuery]);
  end;
  Result := CollectPartition(ALower, LMid) + CollectPartition(LMid, AUpper);
  if Result <> LReported then
  begin
    raise EConvertError.CreateFmt('ISRCTN split count mismatch for %s', [LQuery]);
  end;
end;

procedure TIsrctnScan.ReadTrial(ATrial: TDOMElement);
var
  LDescription: TDOMElement;
  LId: UTF8String;
  LDate: UTF8String;
  LTitle: UTF8String;
  LScientificTitle: UTF8String;
  LCondition: UTF8String;
  LType: UTF8String;
  LCrossIds: UTF8String;
  LMatches: UTF8String;
  LIntervention: UTF8String;
  LSummary: UTF8String;
  LInclusion: UTF8String;
  LOutcomes: UTF8String;
  LResults: UTF8String;
  LOutputs: UTF8String;
begin
  if not Assigned(ATrial) then
  begin
    raise EConvertError.Create('ISRCTN response lacks a trial element');
  end;
  LId := UTF8Encode(ATrial.GetAttribute('publicIdentifierCanonical'));
  LDate := Copy(UTF8Encode(ATrial.GetAttribute('publicIdentifierDateAssigned')), 1, 10);
  LDescription := Element(ATrial, 'trialDescription');
  LTitle := Cell(Element(LDescription, 'title'));
  if (Copy(LId, 1, 6) <> 'ISRCTN') or (Length(LId) <> 14) or (LTitle = '') then
  begin
    raise EConvertError.CreateFmt('Invalid ISRCTN record: %s %s', [LId, LTitle]);
  end;
  FIds.Add(LId);
  LScientificTitle := Cell(Element(LDescription, 'scientificTitle'));
  LCondition := Cell(Element(Element(Element(ATrial, 'conditions'), 'condition'), 'description'));
  LType := Cell(Element(Element(ATrial, 'trialDesign'), 'primaryStudyDesign'));
  LCrossIds := Trim(Cell(Element(Element(ATrial, 'externalRefs'), 'clinicalTrialsGovNumber')) +
    ' ' + Cell(Element(Element(ATrial, 'externalRefs'), 'secondaryNumbers')));
  LIntervention := Cell(Element(ATrial, 'interventions'));
  LSummary := Cell(Element(LDescription, 'plainEnglishSummary'));
  LInclusion := Cell(Element(Element(ATrial, 'participants'), 'inclusion'));
  LOutcomes := Trim(Cell(Element(LDescription, 'primaryOutcomes')) + ' ' +
    Cell(Element(LDescription, 'primaryOutcome')) + ' ' +
    Cell(Element(LDescription, 'secondaryOutcomes')) + ' ' +
    Cell(Element(LDescription, 'secondaryOutcome')));
  LResults := Cell(Element(ATrial, 'results'));
  LOutputs := Cell(Element(ATrial, 'outputs'));
  FillChar(FMatches[0], Length(FMatches) * SizeOf(Boolean), 0);
  FMatcher.Match(LTitle + ' ' + LScientificTitle + ' ' + LCondition + ' ' + LIntervention +
    ' ' + LSummary + ' ' + LOutcomes, FMatches);
  LMatches := JoinMatches(FLabels, FMatches, 0);
  Write(FInventory, LId, #9, LDate, #9, LType, #9, LTitle, #9, LCondition, #9,
    LMatches, #9, 'https://', RegistryHost, '/', LId, #10);
  Write(FDetails, LId, #9, LTitle, #9, LScientificTitle, #9, LCondition, #9, LMatches,
    #9, LInclusion, #9, LIntervention, #9, LSummary, #9, LOutcomes, #9, LResults,
    #9, LOutputs, #9, LCrossIds, #10);
end;

procedure TIsrctnScan.Run(const ARoot, AOutput: String);
var
  LStarted: String;
  LDocument: TXMLDocument;
  LTotal: Integer;
begin
  LoadTerms(IncludeTrailingPathDelimiter(ARoot));
  FOutput := IncludeTrailingPathDelimiter(AOutput);
  if not ForceDirectories(FOutput) then
  begin
    raise EInOutError.Create('Cannot create ISRCTN output directory');
  end;
  LStarted := UtcTimestamp;
  AssignFile(FLedger, FOutput + 'isrctn-query.tsv');
  Rewrite(FLedger);
  try
    Write(FLedger, 'searched_utc'#9'kind'#9'query'#9'url'#9'reported'#9'returned'#9'http'#9,
      'build_artifact'#9'status'#10);
    LDocument := Retrieve(ParkinsonQuery, 'unrestricted count probe', 1, LTotal);
    LDocument.Free;
    AssignFile(FInventory, FOutput + 'isrctn-inventory.tsv');
    Rewrite(FInventory);
    SetTextCodePage(FInventory, CP_UTF8);
    try
      AssignFile(FDetails, FOutput + 'isrctn-detail.tsv');
      Rewrite(FDetails);
      SetTextCodePage(FDetails, CP_UTF8);
      try
        Write(FInventory, 'isrctn_id'#9'identifier_assigned'#9'study_type'#9'title'#9'condition'#9,
          'term_flags'#9'registry_url'#10);
        Write(FDetails, 'isrctn_id'#9'title'#9'scientific_title'#9'condition'#9'term_flags'#9,
          'inclusion'#9'intervention'#9'summary'#9'outcomes'#9'results'#9'outputs'#9'cross_ids'#10);
        CollectPartition(EncodeDate(1900, 1, 1), EncodeDate(2200, 1, 1));
      finally
        CloseFile(FDetails);
      end;
    finally
      CloseFile(FInventory);
    end;
    if FIds.Count <> LTotal then
    begin
      raise EConvertError.CreateFmt('ISRCTN unrestricted count mismatch: %d reported, %d unique',
        [LTotal, FIds.Count]);
    end;
    Write(FLedger, LStarted, #9, 'reconciliation', #9, ParkinsonQuery, #9, #9,
      LTotal, #9, FIds.Count, #9, #9, #9, 'completed', #10);
    WriteLn(FIds.Count, ' unique ISRCTN records reconciled across ', FRequests, ' requests');
  finally
    CloseFile(FLedger);
  end;
end;

var
  Scan: TIsrctnScan;
begin
  if ParamCount <> 2 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.isrctn <experiment-root> <output-directory>');
    Halt(2);
  end;
  try
    Scan := TIsrctnScan.Create;
    try
      Scan.Run(ParamStr(1), ParamStr(2));
    finally
      Scan.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
