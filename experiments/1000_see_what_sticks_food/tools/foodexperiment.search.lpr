{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.search;

{$mode delphi}
{$H+}

uses
  Windows, Classes, SysUtils, Math, foodexperiment.externaldata, foodexperiment.https;

const
  Tab = #9;
  QueryHeader = 'query_id' + Tab + 'claim_id' + Tab + 'variant' + Tab +
    'searched_utc' + Tab + 'query' + Tab + 'status' + Tab + 'hit_count' + Tab +
    'returned_count' + Tab + 'error';
  ResultHeader = 'query_id' + Tab + 'claim_id' + Tab + 'rank' + Tab + 'pmid' + Tab +
    'doi' + Tab + 'pmcid' + Tab + 'title' + Tab + 'journal' + Tab + 'publication_date' +
    Tab + 'abstract';
  RequestSpacingMs = 150;
  MaximumAttempts = 3;
  DefaultWorkers = 6;
  MaximumWorkers = 8;

type
  TQueryResult = record
    Date: UTF8String;
    Status: UTF8String;
    Error: UTF8String;
    Data: TSearchRows;
  end;

  TSearchRun = class
  private
    FLock: TRTLCriticalSection;
    FQueries: TQueries;
    FIndex: Integer;
    FCompleted: Integer;
    FFailed: Integer;
    FNextRequest: QWord;
    FQueryFile: TFileStream;
    FResultFile: TFileStream;
    FCacheDir: String;
  public
    constructor Create(const AQueries: TQueries; const AOutputDir: String);
    destructor Destroy; override;
    function TakeQuery(out AQuery: TQuery): Boolean;
    procedure WaitForSlot;
    procedure DelayRequests(ADelayMs: DWORD);
    procedure RecordResult(const AQuery: TQuery; const AResult: TQueryResult);
    function LoadCached(const AQuery: TQuery; out AResult: TQueryResult): Boolean;
    procedure SaveCache(const AQuery: TQuery; const AResult: TQueryResult);
    property Failed: Integer read FFailed;
  end;

  TSearchWorker = class(TThread)
  private
    FRun: TSearchRun;
    FClient: TEuropePmc;
    function Fetch(const AQuery: TQuery): TQueryResult;
  protected
    procedure Execute; override;
  public
    constructor Create(ARun: TSearchRun);
  end;

procedure WriteLine(AStream: TStream; const AValue: UTF8String);
var
  LLine: UTF8String;
begin
  LLine := AValue + #10;
  AStream.WriteBuffer(LLine[1], Length(LLine));
end;

function LedgerRow(const AQuery: TQuery; const AResult: TQueryResult): UTF8String;
begin
  Result := AQuery.Id + Tab + AQuery.ClaimId + Tab + AQuery.Variant + Tab +
    AResult.Date + Tab + AQuery.Text + Tab + AResult.Status + Tab;
  if AResult.Status = 'Retrieved' then
  begin
    Result := Result + IntToStr(AResult.Data.HitCount) + Tab +
      IntToStr(Length(AResult.Data.Rows)) + Tab;
  end
  else
  begin
    Result := Result + Tab + Tab + CleanField(AResult.Error);
  end;
end;

constructor TSearchRun.Create(const AQueries: TQueries; const AOutputDir: String);
begin
  inherited Create;
  InitCriticalSection(FLock);
  FQueries := AQueries;
  FCacheDir := IncludeTrailingPathDelimiter(AOutputDir) + 'cache';
  if not ForceDirectories(FCacheDir) then
  begin
    raise EInOutError.CreateFmt('Cannot create output directory "%s"', [FCacheDir]);
  end;
  FCacheDir := IncludeTrailingPathDelimiter(FCacheDir);
  FQueryFile := TFileStream.Create(IncludeTrailingPathDelimiter(AOutputDir) +
    'external_queries.tsv', fmCreate or fmShareDenyWrite);
  FResultFile := TFileStream.Create(IncludeTrailingPathDelimiter(AOutputDir) +
    'external_results.tsv', fmCreate or fmShareDenyWrite);
  WriteLine(FQueryFile, QueryHeader);
  WriteLine(FResultFile, ResultHeader);
end;

destructor TSearchRun.Destroy;
begin
  FResultFile.Free;
  FQueryFile.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TSearchRun.TakeQuery(out AQuery: TQuery): Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FIndex < Length(FQueries);
    if Result then
    begin
      AQuery := FQueries[FIndex];
      Inc(FIndex);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSearchRun.WaitForSlot;
var
  LNow: QWord;
  LWait: DWORD;
begin
  repeat
    EnterCriticalSection(FLock);
    try
      LNow := GetTickCount64;
      if LNow >= FNextRequest then
      begin
        FNextRequest := LNow + RequestSpacingMs;
        Exit;
      end;
      LWait := FNextRequest - LNow;
    finally
      LeaveCriticalSection(FLock);
    end;
    Sleep(LWait);
  until False;
end;

procedure TSearchRun.DelayRequests(ADelayMs: DWORD);
var
  LNext: QWord;
begin
  EnterCriticalSection(FLock);
  try
    LNext := GetTickCount64 + ADelayMs;
    if LNext > FNextRequest then
    begin
      FNextRequest := LNext;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TSearchRun.RecordResult(const AQuery: TQuery; const AResult: TQueryResult);
var
  LRow: UTF8String;
begin
  EnterCriticalSection(FLock);
  try
    for LRow in AResult.Data.Rows do
    begin
      WriteLine(FResultFile, LRow);
    end;
    WriteLine(FQueryFile, LedgerRow(AQuery, AResult));
    Inc(FCompleted);
    if AResult.Status = 'Failed' then
    begin
      Inc(FFailed);
    end;
    if (FCompleted mod 100 = 0) or (FCompleted = Length(FQueries)) then
    begin
      WriteLn(FCompleted, '/', Length(FQueries), ' queries recorded (', FFailed, ' failed)');
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TSearchRun.LoadCached(const AQuery: TQuery; out AResult: TQueryResult): Boolean;
var
  LPath: String;
  LStream: TFileStream;
  LCache: UTF8String;
  LLines: TFields;
  LFields: TFields;
  LCount: Integer;
  I: Integer;
begin
  Result := False;
  LPath := FCacheDir + AQuery.Id + '.tsv';
  if not FileExists(LPath) then
  begin
    Exit;
  end;
  LStream := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
  try
    if (LStream.Size < 1) or (LStream.Size > 8 * 1024 * 1024) then
    begin
      Exit;
    end;
    SetLength(LCache, LStream.Size);
    LStream.ReadBuffer(LCache[1], Length(LCache));
  finally
    LStream.Free;
  end;
  LLines := SplitFields(LCache, #10);
  if (Length(LLines) < 2) or (LLines[High(LLines)] <> '') then
  begin
    Exit;
  end;
  LFields := SplitFields(LLines[0], Tab);
  if (Length(LFields) <> 9) or (LFields[0] <> AQuery.Id) or
    (LFields[1] <> AQuery.ClaimId) or (LFields[2] <> AQuery.Variant) or
    (LFields[3] = '') or (LFields[4] <> AQuery.Text) or (LFields[5] <> 'Retrieved') or
    not TryStrToInt64(LFields[6], AResult.Data.HitCount) or
    not TryStrToInt(LFields[7], LCount) or (LCount < 0) or (LCount > 20) or
    (LCount > AResult.Data.HitCount) or (LCount <> Length(LLines) - 2) then
  begin
    Exit;
  end;
  AResult.Date := LFields[3];
  SetLength(AResult.Data.Rows, LCount);
  for I := 1 to LCount do
  begin
    AResult.Data.Rows[I - 1] := LLines[I];
    LFields := SplitFields(AResult.Data.Rows[I - 1], Tab);
    if (Length(LFields) <> 10) or (LFields[0] <> AQuery.Id) or
      (LFields[1] <> AQuery.ClaimId) or (LFields[2] <> IntToStr(I)) then
    begin
      AResult := Default(TQueryResult);
      Exit;
    end;
  end;
  AResult.Status := 'Retrieved';
  Result := True;
end;

procedure TSearchRun.SaveCache(const AQuery: TQuery; const AResult: TQueryResult);
var
  LPath: String;
  LTempPath: String;
  LStream: TFileStream;
  LRow: UTF8String;
begin
  LPath := FCacheDir + AQuery.Id + '.tsv';
  LTempPath := LPath + '.tmp';
  LStream := TFileStream.Create(LTempPath, fmCreate);
  try
    WriteLine(LStream, LedgerRow(AQuery, AResult));
    for LRow in AResult.Data.Rows do
    begin
      WriteLine(LStream, LRow);
    end;
  finally
    LStream.Free;
  end;
  if not MoveFileEx(PChar(LTempPath), PChar(LPath), MOVEFILE_REPLACE_EXISTING) then
  begin
    RaiseLastOSError;
  end;
end;

constructor TSearchWorker.Create(ARun: TSearchRun);
begin
  inherited Create(True);
  FRun := ARun;
end;

function TSearchWorker.Fetch(const AQuery: TQuery): TQueryResult;
var
  LResponse: TSearchResponse;
  LAttempt: Integer;
begin
  Result := Default(TQueryResult);
  Result.Status := 'Failed';
  for LAttempt := 1 to MaximumAttempts do
  begin
    FRun.WaitForSlot;
    Result.Date := UtcTimestamp;
    try
      if not Assigned(FClient) then
      begin
        FClient := TEuropePmc.Create;
      end;
      LResponse := FClient.Search(AQuery.Text);
      if LResponse.Status = 200 then
      begin
        Result.Data := ParseResults(AQuery, LResponse.Body);
        Result.Status := 'Retrieved';
        Result.Error := '';
        Exit;
      end;
      Result.Error := 'Europe PMC HTTP ' + IntToStr(LResponse.Status);
      if LResponse.Status = 429 then
      begin
        FRun.DelayRequests(Max(2000, Min(60, LResponse.RetryAfterSeconds) * 1000));
      end
      else if (LResponse.Status <> 408) and (LResponse.Status < 500) then
      begin
        Exit;
      end;
    except
      on LException: Exception do
      begin
        Result.Error := LException.Message;
      end;
    end;
    if LAttempt < MaximumAttempts then
    begin
      Sleep(1000 shl (LAttempt - 1));
    end;
  end;
end;

procedure TSearchWorker.Execute;
var
  LQuery: TQuery;
  LResult: TQueryResult;
begin
  try
    while FRun.TakeQuery(LQuery) do
    begin
      if not FRun.LoadCached(LQuery, LResult) then
      begin
        LResult := Fetch(LQuery);
        if LResult.Status = 'Retrieved' then
        begin
          FRun.SaveCache(LQuery, LResult);
        end;
      end;
      FRun.RecordResult(LQuery, LResult);
    end;
  finally
    FClient.Free;
  end;
end;

procedure RunSearch(const AQueries: TQueries; const AOutputDir: String; AWorkerCount: Integer);
var
  LRun: TSearchRun;
  LWorkers: array of TSearchWorker;
  LWorker: TSearchWorker;
  I: Integer;
begin
  LRun := TSearchRun.Create(AQueries, AOutputDir);
  try
    SetLength(LWorkers, AWorkerCount);
    try
      for I := 0 to High(LWorkers) do
      begin
        LWorkers[I] := TSearchWorker.Create(LRun);
        LWorkers[I].Start;
      end;
      for LWorker in LWorkers do
      begin
        LWorker.WaitFor;
        if Assigned(LWorker.FatalException) then
        begin
          raise Exception.Create(Exception(LWorker.FatalException).Message);
        end;
      end;
      if LRun.Failed > 0 then
      begin
        ExitCode := 2;
      end;
    finally
      for LWorker in LWorkers do
      begin
        LWorker.Free;
      end;
    end;
  finally
    LRun.Free;
  end;
end;

procedure WritePlan(const AQueries: TQueries; const AOutputDir: String);
var
  LQuery: TQuery;
  LResult: TQueryResult;
  LStream: TFileStream;
begin
  if not ForceDirectories(AOutputDir) then
  begin
    raise EInOutError.CreateFmt('Cannot create output directory "%s"', [AOutputDir]);
  end;
  LStream := TFileStream.Create(IncludeTrailingPathDelimiter(AOutputDir) +
    'external_query_plan.tsv', fmCreate);
  try
    WriteLine(LStream, QueryHeader);
    LResult := Default(TQueryResult);
    LResult.Status := 'Planned';
    for LQuery in AQueries do
    begin
      WriteLine(LStream, LedgerRow(LQuery, LResult));
    end;
  finally
    LStream.Free;
  end;
  WriteLn(Length(AQueries), ' external queries planned');
end;

procedure Run;
var
  LCommand: String;
  LWorkerCount: Integer;
  LQueries: TQueries;
  LOutputDir: String;
begin
  LCommand := ParamStr(1);
  if ((LCommand = 'search') and (ParamCount in [3, 4])) or
    ((LCommand = 'plan') and (ParamCount = 3)) then
  begin
    LWorkerCount := DefaultWorkers;
    if (ParamCount = 4) and (not TryStrToInt(ParamStr(4), LWorkerCount) or
      (LWorkerCount < 1) or (LWorkerCount > MaximumWorkers)) then
    begin
      raise EConvertError.CreateFmt('Workers must be between 1 and %d', [MaximumWorkers]);
    end;
    LQueries := LoadQueries(ExpandFileName(ParamStr(2)));
    LOutputDir := ExpandFileName(ParamStr(3));
    if LCommand = 'plan' then
    begin
      WritePlan(LQueries, LOutputDir);
    end
    else
    begin
      RunSearch(LQueries, LOutputDir, LWorkerCount);
    end;
    Exit;
  end;
  raise EConvertError.Create('Usage: foodexperiment.search search <experiment-dir> ' +
    '<output-dir> [workers], or plan <experiment-dir> <output-dir>');
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
