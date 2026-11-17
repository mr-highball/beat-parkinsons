{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentCtis;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, fpjson, jsonparser, foodexperiment.https, foodexperiment.externaldata;

const
  Host = 'euclinicaltrials.eu';
  SearchPath = '/ctis-public-api/search';
  DetailPath = '/ctis-public-api/retrieve/';
  PublicPath = 'https://' + Host + '/ctis-public/view/';
  PageSize = 25;
  Terms: array[0..4] of String = ('Parkinson', 'Parkinsonism', 'Parkinsonian',
    'paralysis agitans', 'shaking palsy');

type
  TCtisScan = class
  private
    FClient: TEuropePmc;
    FTrials: TStringList;
    FOutput: String;
    FQueries: Text;
    FInventory: Text;
    FMissingDetail: Integer;
    procedure Search(const ATerm: String);
    procedure TrialDetails;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const AOutput: String);
  end;

function Cell(AData: TJSONData; const APath: String): UTF8String;
var
  LValue: TJSONData;
begin
  Result := '';
  LValue := AData.FindPath(APath);
  if Assigned(LValue) and (LValue.JSONType in [jtString, jtNumber, jtBoolean]) then
  begin
    Result := CleanField(LValue.AsString);
  end;
end;

procedure SaveBody(const AFile: String; const ABody: UTF8String);
var
  LFile: TFileStream;
begin
  if ABody = '' then
  begin
    raise EConvertError.CreateFmt('CTIS returned an empty response for %s', [AFile]);
  end;
  LFile := TFileStream.Create(AFile, fmCreate);
  try
    LFile.WriteBuffer(ABody[1], Length(ABody));
  finally
    LFile.Free;
  end;
end;

constructor TCtisScan.Create;
begin
  inherited Create;
  FClient := TEuropePmc.Create(Host);
  FTrials := TStringList.Create;
  FTrials.OwnsObjects := True;
  FTrials.Sorted := True;
end;

destructor TCtisScan.Destroy;
begin
  FTrials.Free;
  FClient.Free;
  inherited Destroy;
end;

procedure TCtisScan.Search(const ATerm: String);
var
  LSeen: TStringList;
  LRequest: UTF8String;
  LResponse: TSearchResponse;
  LPage: TJSONData;
  LRows: TJSONData;
  LReported: Integer;
  LTotalPages: Integer;
  LPageNumber: Integer;
  LAttempt: Integer;
  LIndex: Integer;
  LTrialId: String;
  LStart: String;
  LArtifact: String;
  LHasNext: Boolean;
begin
  LSeen := TStringList.Create;
  LSeen.Sorted := True;
  LSeen.Duplicates := dupError;
  LPageNumber := 1;
  LReported := -1;
  try
    repeat
      LRequest := Format('{"pagination":{"page":%d,"size":%d},' +
        '"searchCriteria":{"containAll":"%s"},' +
        '"sort":{"property":"decisionDate","direction":"DESC"}}',
        [LPageNumber, PageSize, ATerm]);
      LStart := UtcTimestamp;
      for LAttempt := 0 to 2 do
      begin
        LResponse := FClient.PostJson(SearchPath, LRequest);
        if (LResponse.Status <> 429) and (LResponse.Status < 500) then
        begin
          Break;
        end;
        if LAttempt < 2 then
        begin
          Sleep(1000 shl LAttempt);
        end;
      end;
      if LResponse.Status <> 200 then
      begin
        Write(FQueries, LStart, #9, 'search', #9, ATerm, #9, LRequest, #9, #9,
          #9, LResponse.Status, #9, 'search unavailable', #10);
        raise EInOutError.CreateFmt('CTIS search returned HTTP %d for %s',
          [LResponse.Status, ATerm]);
      end;
      LArtifact := StringReplace(ATerm, ' ', '-', [rfReplaceAll]) +
        Format('-%.3d.json', [LPageNumber]);
      SaveBody(FOutput + LArtifact, LResponse.Body);
      LPage := GetJSON(LResponse.Body, True);
      try
        if LPageNumber = 1 then
        begin
          LReported := StrToInt(Cell(LPage, 'pagination.totalRecords'));
        end;
        if (LReported <> StrToInt(Cell(LPage, 'pagination.totalRecords'))) or
          (LPageNumber <> StrToInt(Cell(LPage, 'pagination.currentPage'))) then
        begin
          raise EConvertError.CreateFmt('CTIS search pagination changed for %s', [ATerm]);
        end;
        LTotalPages := StrToInt(Cell(LPage, 'pagination.totalPages'));
        LHasNext := SameText(Cell(LPage, 'pagination.nextPage'), 'true');
        if LHasNext <> (LPageNumber < LTotalPages) then
        begin
          raise EConvertError.CreateFmt('CTIS next-page flag disagrees with total for %s',
            [ATerm]);
        end;
        LRows := LPage.FindPath('data');
        if not Assigned(LRows) or (LRows.JSONType <> jtArray) then
        begin
          raise EConvertError.Create('CTIS response lacks the data array');
        end;
        for LIndex := 0 to LRows.Count - 1 do
        begin
          LTrialId := Cell(LRows.Items[LIndex], 'ctNumber');
          if (Length(LTrialId) <> 17) or (Cell(LRows.Items[LIndex], 'ctTitle') = '') then
          begin
            raise EConvertError.CreateFmt('Invalid CTIS trial in search %s', [ATerm]);
          end;
          LSeen.Add(LTrialId);
          if FTrials.IndexOf(LTrialId) < 0 then
          begin
            FTrials.AddObject(LTrialId, LRows.Items[LIndex].Clone);
          end;
        end;
        Write(FQueries, LStart, #9, 'search', #9, ATerm, #9, LRequest, #9, LReported,
          #9, LRows.Count, #9, LResponse.Status, #9, LArtifact, #10);
        Flush(FQueries);
      finally
        LPage.Free;
      end;
      Inc(LPageNumber);
    until not LHasNext;
    if LSeen.Count <> LReported then
    begin
      raise EConvertError.CreateFmt('CTIS %s count mismatch: %d reported, %d unique',
        [ATerm, LReported, LSeen.Count]);
    end;
    Write(FQueries, UtcTimestamp, #9, 'reconciliation', #9, ATerm, #9, #9, LReported,
      #9, LSeen.Count, #9, #9, 'completed', #10);
    WriteLn(ATerm, ': ', LSeen.Count, ' unique trials across ', LPageNumber - 1, ' pages');
  finally
    LSeen.Free;
  end;
end;

procedure TCtisScan.TrialDetails;
var
  LIndex: Integer;
  LTrialId: String;
  LResponse: TSearchResponse;
  LDetail: TJSONData;
  LRow: TJSONData;
  LPublishDate: String;
  LDetailState: String;
begin
  for LIndex := 0 to FTrials.Count - 1 do
  begin
    LTrialId := FTrials[LIndex];
    LRow := FTrials.Objects[LIndex] as TJSONData;
    LPublishDate := '';
    LResponse := FClient.GetPath(DetailPath + LTrialId);
    if LResponse.Status = 200 then
    begin
      SaveBody(FOutput + LTrialId + '.json', LResponse.Body);
      LDetail := GetJSON(LResponse.Body, True);
      try
        if Cell(LDetail, 'ctNumber') <> LTrialId then
        begin
          raise EConvertError.CreateFmt('CTIS detail has wrong trial ID for %s', [LTrialId]);
        end;
        LPublishDate := Copy(Cell(LDetail, 'publishDate'), 1, 10);
        LDetailState := 'received';
      finally
        LDetail.Free;
      end;
    end
    else
    begin
      Inc(FMissingDetail);
      LDetailState := 'HTTP ' + IntToStr(LResponse.Status);
    end;
    Write(FInventory, LTrialId, #9, LPublishDate, #9, Cell(LRow, 'ctTitle'), #9,
      Cell(LRow, 'conditions'), #9, Cell(LRow, 'product'), #9, Cell(LRow, 'primaryEndPoint'),
      #9, Cell(LRow, 'resultsFirstReceived'), #9, LDetailState, #9, PublicPath, LTrialId, #10);
  end;
end;

procedure TCtisScan.Run(const AOutput: String);
var
  LTerm: String;
begin
  FOutput := IncludeTrailingPathDelimiter(AOutput);
  if not ForceDirectories(FOutput) then
  begin
    raise EInOutError.Create('Cannot create CTIS output directory');
  end;
  AssignFile(FQueries, FOutput + 'ctis-query.tsv');
  Rewrite(FQueries);
  try
    Write(FQueries, 'searched_utc'#9'kind'#9'term'#9'request_body'#9'reported'#9'returned'#9,
      'http'#9'detail'#10);
    for LTerm in Terms do
    begin
      Search(LTerm);
    end;
    AssignFile(FInventory, FOutput + 'ctis-inventory.tsv');
    Rewrite(FInventory);
    SetTextCodePage(FInventory, CP_UTF8);
    try
      Write(FInventory, 'euct_id'#9'published_date'#9'title'#9'condition'#9'products'#9,
        'primary_endpoint'#9'results_received'#9'detail_status'#9'registry_url'#10);
      TrialDetails;
    finally
      CloseFile(FInventory);
    end;
    Write(FQueries, UtcTimestamp, #9, 'all queries deduplicated', #9, #9, #9, #9,
      FTrials.Count, #9, #9, IntToStr(FMissingDetail), ' missing trial details', #10);
    WriteLn(FTrials.Count, ' CTIS trials, ', FMissingDetail, ' inaccessible detail records');
  finally
    CloseFile(FQueries);
  end;
end;

var
  Scan: TCtisScan;
begin
  if ParamCount <> 1 then
  begin
    WriteLn(StdErr, 'Usage: foodexperiment.ctis <output-directory>');
    Halt(2);
  end;
  try
    Scan := TCtisScan.Create;
    try
      Scan.Run(ParamStr(1));
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
