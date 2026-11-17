{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentRegistry;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, foodexperiment.https,
  foodexperiment.externaldata, foodexperiment.matching;

const
  RegistryPageSize = '10';
  RegistryPath = '/api/v2/studies?query.cond=Parkinson%20Disease&countTotal=true&pageSize=' +
    RegistryPageSize;
  ExpressionPath = '/api/v2/studies?countTotal=true&pageSize=' + RegistryPageSize + '&query.term=';
  RegistryEndpoint = 'https://clinicaltrials.gov';

type
  TRegistryScan = class
  private
    FNames: TStringList;
    FIds: TStringList;
    FMatcher: TMatcher;
    FClient: TEuropePmc;
    FQueryPath: UTF8String;
    FPrimary: TMatchFlags;
    FContext: TMatchFlags;
    FInventory: Text;
    FCandidates: Text;
    FDetails: TFileStream;
    FInventoryBuffer: array[0..65535] of Byte;
    FCandidateBuffer: array[0..65535] of Byte;
    FCandidateCount: Integer;
    procedure AddTerms(const ATerms: String; AIndex: Integer);
    procedure LoadVocabulary(const ARoot: String);
    function FetchPage(const AToken: UTF8String): TJSONData;
    procedure WriteDetailRow(const ARow: UTF8String);
    procedure ReadStudy(AStudy: TJSONData);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const ARoot, AOutput: String; const AExpression: UTF8String;
      AIncludeDetails: Boolean);
  end;

function Field(AData: TJSONData; const APath: String): UTF8String;
var
  LField: TJSONData;
begin
  Result := '';
  LField := AData.FindPath(APath);
  if Assigned(LField) and (LField.JSONType in [jtString, jtBoolean, jtNumber]) then
  begin
    Result := CleanField(LField.AsString);
  end;
end;

function ListField(AData: TJSONData; const APath, AField: String): UTF8String;
var
  LList: TJSONData;
  LItem: TJSONData;
  LIndex: Integer;
  LValue: UTF8String;
begin
  Result := '';
  LList := AData.FindPath(APath);
  if not Assigned(LList) or (LList.JSONType <> jtArray) then
  begin
    Exit;
  end;
  for LIndex := 0 to LList.Count - 1 do
  begin
    LItem := LList.Items[LIndex];
    if AField = '' then
    begin
      LValue := CleanField(LItem.AsString);
    end
    else
    begin
      LValue := Field(LItem, AField);
    end;
    if LValue = '' then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + '; ';
    end;
    Result := Result + LValue;
  end;
end;

constructor TRegistryScan.Create;
begin
  inherited Create;
  FNames := TStringList.Create;
  FIds := TStringList.Create;
  FIds.Sorted := True;
  FIds.Duplicates := dupError;
  FMatcher := TMatcher.Create;
  FClient := TEuropePmc.Create('clinicaltrials.gov');
end;

destructor TRegistryScan.Destroy;
begin
  FDetails.Free;
  FClient.Free;
  FMatcher.Free;
  FIds.Free;
  FNames.Free;
  inherited Destroy;
end;

procedure TRegistryScan.AddTerms(const ATerms: String; AIndex: Integer);
var
  LTerm: UTF8String;
begin
  for LTerm in SplitFields(ATerms, '|') do
  begin
    if not (SameText(LTerm, 'date') or SameText(LTerm, 'fig') or SameText(LTerm, 'sage')
      or SameText(LTerm, 'melissa')) then
    begin
      FMatcher.Add(Trim(LTerm), AIndex);
    end;
  end;
end;

procedure TRegistryScan.LoadVocabulary(const ARoot: String);
var
  LLines: TStringList;
  LParts: TFields;
  LRow: Integer;
  LIndex: Integer;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := ReadBytes(ARoot + 'ingredients.tsv');
    for LRow := 1 to LLines.Count - 1 do
    begin
      LParts := SplitFields(LLines[LRow], #9);
      if Length(LParts) <> 4 then
      begin
        raise EConvertError.CreateFmt('Invalid ingredient row %d', [LRow + 1]);
      end;
      LIndex := FNames.Add(LParts[1]);
      AddTerms(LParts[1] + '|' + LParts[3], LIndex * 2);
    end;
    LLines.Text := ReadBytes(ARoot + 'exposure-expansions.tsv');
    for LRow := 1 to LLines.Count - 1 do
    begin
      LParts := SplitFields(LLines[LRow], #9);
      if Length(LParts) <> 3 then
      begin
        raise EConvertError.CreateFmt('Invalid expansion row %d', [LRow + 1]);
      end;
      LIndex := FNames.IndexOf(LParts[0]);
      if (LIndex < 0) or ((LParts[1] <> 'name') and (LParts[1] <> 'related')) then
      begin
        raise EConvertError.CreateFmt('Unknown expansion at row %d', [LRow + 1]);
      end;
      AddTerms(LParts[2], LIndex * 2 + Ord(LParts[1] = 'related'));
    end;
  finally
    LLines.Free;
  end;
  SetLength(FPrimary, FNames.Count * 2);
  SetLength(FContext, Length(FPrimary));
  FMatcher.Prepare;
end;

function TRegistryScan.FetchPage(const AToken: UTF8String): TJSONData;
var
  LPath: UTF8String;
  LResponse: TSearchResponse;
  LAttempt: Integer;
begin
  LPath := FQueryPath;
  if AToken <> '' then
  begin
    LPath := LPath + '&pageToken=' + UrlEncode(AToken);
  end;
  for LAttempt := 0 to 2 do
  begin
    LResponse := FClient.GetPath(LPath);
    if LResponse.Status = 200 then
    begin
      Exit(GetJSON(LResponse.Body, True));
    end;
    if not ((LResponse.Status = 429) or (LResponse.Status >= 500)) then
    begin
      Break;
    end;
    if LResponse.RetryAfterSeconds > 0 then
    begin
      Sleep(LResponse.RetryAfterSeconds * 1000);
    end
    else
    begin
      Sleep(1000 shl LAttempt);
    end;
  end;
  raise EInOutError.CreateFmt('ClinicalTrials.gov returned HTTP %d', [LResponse.Status]);
end;

procedure TRegistryScan.WriteDetailRow(const ARow: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := ARow + #10;
  FDetails.WriteBuffer(LLine[1], Length(LLine));
end;

procedure TRegistryScan.ReadStudy(AStudy: TJSONData);
const
  Protocol = 'protocolSection.';
  Identification = Protocol + 'identificationModule.';
  Status = Protocol + 'statusModule.';
  Interventions = Protocol + 'armsInterventionsModule.interventions';
  Arms = Protocol + 'armsInterventionsModule.armGroups';
  Outcomes = Protocol + 'outcomesModule.';
  Description = Protocol + 'descriptionModule.';
var
  LId: String;
  LTitle: UTF8String;
  LFirstPosted: String;
  LLastPosted: String;
  LStatus: String;
  LHasResults: String;
  LType: String;
  LNames: UTF8String;
  LInterventionDescriptions: UTF8String;
  LArmLabels: UTF8String;
  LArmDescriptions: UTF8String;
  LConditions: UTF8String;
  LMeasures: UTF8String;
  LMatch: String;
  LRelation: String;
  LIndex: Integer;
begin
  LId := Field(AStudy, Identification + 'nctId');
  LTitle := Field(AStudy, Identification + 'briefTitle');
  if not LId.StartsWith('NCT') or (Length(LId) <> 11) or (LTitle = '') then
  begin
    raise EConvertError.Create('Invalid ClinicalTrials.gov study identifier or title');
  end;
  FIds.Add(LId);
  LFirstPosted := Field(AStudy, Status + 'studyFirstPostDateStruct.date');
  LLastPosted := Field(AStudy, Status + 'lastUpdatePostDateStruct.date');
  LStatus := Field(AStudy, Status + 'overallStatus');
  LHasResults := Field(AStudy, 'hasResults');
  LType := Field(AStudy, Protocol + 'designModule.studyType');
  LConditions := ListField(AStudy, Protocol + 'conditionsModule.conditions', '');
  LNames := ListField(AStudy, Interventions, 'name');
  LInterventionDescriptions := ListField(AStudy, Interventions, 'description');
  LArmLabels := ListField(AStudy, Arms, 'label');
  LArmDescriptions := ListField(AStudy, Arms, 'description');
  LMeasures := ListField(AStudy, Outcomes + 'primaryOutcomes', 'measure') + '; ' +
    ListField(AStudy, Outcomes + 'secondaryOutcomes', 'measure');
  Write(FInventory, LId, #9, LFirstPosted, #9, LLastPosted, #9, LStatus, #9,
    LHasResults, #9, LType, #9, LTitle, #9, LConditions, #10);
  if Assigned(FDetails) then
  begin
    WriteDetailRow(LId + #9 + LNames + #9 + LInterventionDescriptions +
      #9 + LArmLabels + #9 + LArmDescriptions +
      #9 + ListField(AStudy, Outcomes + 'primaryOutcomes', 'measure') +
      #9 + ListField(AStudy, Outcomes + 'primaryOutcomes', 'description') +
      #9 + ListField(AStudy, Outcomes + 'secondaryOutcomes', 'measure') +
      #9 + ListField(AStudy, Outcomes + 'secondaryOutcomes', 'description') +
      #9 + ListField(AStudy, Outcomes + 'otherOutcomes', 'measure') +
      #9 + ListField(AStudy, Outcomes + 'otherOutcomes', 'description') +
      #9 + Field(AStudy, Description + 'briefSummary') +
      #9 + Field(AStudy, Description + 'detailedDescription'));
  end;

  FillChar(FPrimary[0], Length(FPrimary) * SizeOf(Boolean), 0);
  FillChar(FContext[0], Length(FContext) * SizeOf(Boolean), 0);
  FMatcher.Match(LNames + ' ' + LInterventionDescriptions, FPrimary);
  // A generic intervention label can leave the exposure only in a comparator arm.
  FMatcher.Match(LArmLabels + ' ' + LArmDescriptions, FPrimary);
  FMatcher.Match(LTitle + ' ' + Field(AStudy, Protocol + 'descriptionModule.briefSummary') +
    ' ' + Field(AStudy, Protocol + 'descriptionModule.detailedDescription'), FContext);
  for LIndex := 0 to High(FPrimary) do
  begin
    if not FPrimary[LIndex] and not FContext[LIndex] then
    begin
      Continue;
    end;
    if FPrimary[LIndex] then
    begin
      LMatch := 'intervention';
    end
    else
    begin
      LMatch := 'title or description';
    end;
    if Odd(LIndex) then
    begin
      LRelation := 'related';
    end
    else
    begin
      LRelation := 'name';
    end;
    Inc(FCandidateCount);
    Write(FCandidates, LId, #9, LFirstPosted, #9, FNames[LIndex div 2], #9,
      LRelation, #9, LMatch, #9, LStatus, #9, LHasResults, #9, LType, #9,
      LTitle, #9, LNames, #9, LMeasures, #10);
  end;
end;

procedure TRegistryScan.Run(const ARoot, AOutput: String; const AExpression: UTF8String;
  AIncludeDetails: Boolean);
var
  LOutput: String;
  LReceipt: String;
  LDetailPath: String;
  LToken: UTF8String;
  LPrevious: UTF8String;
  LPage: TJSONData;
  LStudies: TJSONData;
  LTotal: Integer;
  LPages: Integer;
  LIndex: Integer;
  LLedger: Text;
  LStarted: String;
begin
  LoadVocabulary(IncludeTrailingPathDelimiter(ARoot));
  if AExpression = '' then
  begin
    FQueryPath := RegistryPath;
  end
  else
  begin
    FQueryPath := ExpressionPath + UrlEncode(AExpression);
  end;
  LOutput := IncludeTrailingPathDelimiter(AOutput);
  if not ForceDirectories(AOutput) then
  begin
    raise EInOutError.Create('Cannot create registry output directory');
  end;
  LReceipt := LOutput + 'registry-query.tsv';
  if FileExists(LReceipt) and not DeleteFile(LReceipt) then
  begin
    raise EInOutError.Create('Cannot remove previous registry receipt: ' + LReceipt);
  end;
  LDetailPath := LOutput + 'registry-study-details.tsv';
  if FileExists(LDetailPath) and not DeleteFile(LDetailPath) then
  begin
    raise EInOutError.Create('Cannot remove previous registry details: ' + LDetailPath);
  end;
  LStarted := UtcTimestamp;
  LPages := 0;
  LTotal := -1;
  LToken := '';
  if AIncludeDetails then
  begin
    FDetails := TFileStream.Create(LDetailPath, fmCreate);
    WriteDetailRow('nct_id'#9'interventions'#9'intervention_descriptions'#9'arms'#9 +
      'arm_descriptions'#9'primary_measures'#9'primary_descriptions'#9'secondary_measures'#9 +
      'secondary_descriptions'#9'other_measures'#9'other_descriptions'#9'brief_summary'#9 +
      'detailed_description');
  end;
  AssignFile(FInventory, LOutput + 'registry-inventory.tsv');
  SetTextBuf(FInventory, FInventoryBuffer);
  Rewrite(FInventory);
  SetTextCodePage(FInventory, CP_UTF8);
  try
    AssignFile(FCandidates, LOutput + 'registry-exposure-candidates.tsv');
    SetTextBuf(FCandidates, FCandidateBuffer);
    Rewrite(FCandidates);
    SetTextCodePage(FCandidates, CP_UTF8);
    try
      Write(FInventory, 'nct_id'#9'first_posted'#9'last_posted'#9'status'#9'has_results'#9,
        'study_type'#9'title'#9'conditions'#10);
      Write(FCandidates, 'nct_id'#9'first_posted'#9'ingredient'#9'relation'#9'match_field'#9,
        'status'#9'has_results'#9'study_type'#9'title'#9'interventions'#9'outcomes'#10);
      repeat
        LPrevious := LToken;
        LPage := FetchPage(LToken);
        try
          if LPages = 0 then
          begin
            LTotal := StrToInt(Field(LPage, 'totalCount'));
          end;
          Inc(LPages);
          LStudies := LPage.FindPath('studies');
          if not Assigned(LStudies) or (LStudies.JSONType <> jtArray) then
          begin
            raise EConvertError.Create('Missing study array from registry');
          end;
          for LIndex := 0 to LStudies.Count - 1 do
          begin
            ReadStudy(LStudies.Items[LIndex]);
          end;
          LToken := Field(LPage, 'nextPageToken');
          if (LToken <> '') and (LToken = LPrevious) then
          begin
            raise EConvertError.Create('Registry pagination token repeated');
          end;
        finally
          LPage.Free;
        end;
        if LPages mod 10 = 0 then
        begin
          WriteLn(FIds.Count, ' registry records retrieved');
        end;
      until LToken = '';
    finally
      CloseFile(FCandidates);
    end;
  finally
    CloseFile(FInventory);
  end;
  FreeAndNil(FDetails);
  if FIds.Count <> LTotal then
  begin
    raise EConvertError.CreateFmt('Registry count mismatch: %d reported, %d retrieved',
      [LTotal, FIds.Count]);
  end;
  AssignFile(LLedger, LReceipt);
  Rewrite(LLedger);
  try
    Write(LLedger, 'searched_utc'#9'query'#9'reported'#9'retrieved'#9'pages'#9'candidate_rows'#9,
      'status'#10, LStarted, #9, RegistryEndpoint, FQueryPath, #9, LTotal, #9,
      FIds.Count, #9, LPages, #9, FCandidateCount, #9, 'Completed', #10);
  finally
    CloseFile(LLedger);
  end;
  WriteLn(FIds.Count, ' registry records, ', FCandidateCount, ' candidate matches');
end;

var
  GScan: TRegistryScan;
  GExpressionFile: TStringList;
  GExpression: UTF8String;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    if not (ParamCount in [2, 3, 4]) or ((ParamCount = 4) and (ParamStr(4) <> 'details')) then
    begin
      raise EArgumentException.Create(
        'Usage: foodexperiment.registry <experiment> <output> [expression-file [details]]');
    end;
    GExpression := '';
    if ParamCount >= 3 then
    begin
      GExpressionFile := TStringList.Create;
      try
        GExpressionFile.LoadFromFile(ParamStr(3), TEncoding.UTF8);
        if GExpressionFile.Count <> 1 then
        begin
          raise EConvertError.Create('Expected one ClinicalTrials.gov expression');
        end;
        GExpression := Trim(GExpressionFile[0]);
        if GExpression = '' then
        begin
          raise EConvertError.Create('ClinicalTrials.gov expression is empty');
        end;
      finally
        GExpressionFile.Free;
      end;
    end;
    GScan := TRegistryScan.Create;
    try
      GScan.Run(ParamStr(1), ParamStr(2), GExpression, ParamStr(4) = 'details');
    finally
      GScan.Free;
    end;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
