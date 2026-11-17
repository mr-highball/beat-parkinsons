{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.catalog;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  fpjson, sqlite3dyn;

type
  TResearchCatalog = class
  private
    FDatabase: PSQLite3;
    FRepoRoot: UnicodeString;
    FResearchRoot: UnicodeString;
    FSQLiteLoaded: Boolean;
    FLastRefreshError: String;
    function ReadStatus(AIncludeDiagnostics: Boolean): TJSONObject;
  public
    constructor Create(const ARepoRoot, ADatabasePath: String);
    destructor Destroy; override;
    procedure Refresh;
    procedure ExportSearch(const AOutputDirectory: String);
    function Search(const ATerms, APeriod: String; AOffset, ALimit: Integer): TJSONObject;
    function Status(AIncludeDiagnostics: Boolean = True): TJSONObject;
  end;

implementation

uses
  BufStream, Classes, Generics.Collections, SysUtils, Windows;

const
  CatalogApplicationId = $504F5243;
  CatalogSchemaVersion = 1;
  MaximumPageSize = 100;
  MaximumTermsBytes = 512;
  ErrorExampleLimit = 10;
  OpenReparsePoint = $00200000;
  MatchFrom = ' FROM document_fts JOIN documents ON documents.id=document_fts.rowid' +
    ' WHERE document_fts MATCH ?1 AND (?2='''' OR documents.period=?2)';

type
  ECatalogReadError = class(Exception);

  // The system winsqlite3 DLL uses stdcall on Win32. The FPC SQLite unit
  // loads its exports, whose addresses require the Windows ABI at call sites.
  TWinSqliteVersion = function: Integer; stdcall;
  TWinSqliteOpen = function(AName: PAnsiChar; ADatabase: Pointer; AFlags: Integer;
    AVfs: PAnsiChar): Integer; stdcall;
  TWinSqliteDbCode = function(ADatabase: PSQLite3): Integer; stdcall;
  TWinSqliteBusy = function(ADatabase: PSQLite3; ABusyMs: Integer): Integer; stdcall;
  TWinSqliteError = function(ADatabase: PSQLite3): PAnsiChar; stdcall;
  TWinSqliteExec = function(ADatabase: PSQLite3; ASql: PAnsiChar;
    ACallback, AContext, AError: Pointer): Integer; stdcall;
  TWinSqlitePrepare = function(ADatabase: PSQLite3; ASql: PAnsiChar; ABytes: Integer;
    AStatement, ATail: Pointer): Integer; stdcall;
  TWinSqliteStmtCode = function(AStatement: PSQLite3_Stmt): Integer; stdcall;
  TWinSqliteBindText = function(AStatement: PSQLite3_Stmt; AIndex: Integer; AText: PAnsiChar;
    ABytes: Integer; ADestructor: Pointer): Integer; stdcall;
  TWinSqliteBindInt64 = function(AStatement: PSQLite3_Stmt; AIndex: Integer;
    AValue: Int64): Integer; stdcall;
  TWinSqliteColInt = function(AStatement: PSQLite3_Stmt; AIndex: Integer): Integer; stdcall;
  TWinSqliteColInt64 = function(AStatement: PSQLite3_Stmt; AIndex: Integer): Int64; stdcall;
  TWinSqliteColText = function(AStatement: PSQLite3_Stmt; AIndex: Integer): PAnsiChar; stdcall;

  TSqlStatement = class
  private
    FDatabase: PSQLite3;
    FStatement: PSQLite3_Stmt;
  public
    constructor Create(ADatabase: PSQLite3; const ASql: AnsiString);
    destructor Destroy; override;
    procedure Reset;
    procedure BindText(AIndex: Integer; const AText: UTF8String);
    procedure BindNumber(AIndex: Integer; AValue: Int64);
    function Next: Boolean;
    procedure Execute;
    function Text(AIndex: Integer): UTF8String;
    function Number(AIndex: Integer): Int64;
  end;

procedure CheckSqlite(ADatabase: PSQLite3; AResult: Integer);
begin
  if AResult <> SQLITE_OK then
  begin
    if ADatabase = nil then
    begin
      raise Exception.CreateFmt('SQLite error %d', [AResult]);
    end;
    raise Exception.CreateFmt('SQLite error %d: %s',
      [AResult, String(UTF8String(TWinSqliteError(Pointer(@sqlite3_errmsg))(ADatabase)))]);
  end;
end;

procedure ExecuteSql(ADatabase: PSQLite3; const ASql: AnsiString);
begin
  CheckSqlite(ADatabase, TWinSqliteExec(Pointer(@sqlite3_exec))(ADatabase, PAnsiChar(ASql), nil, nil, nil));
end;

constructor TSqlStatement.Create(ADatabase: PSQLite3; const ASql: AnsiString);
begin
  inherited Create;
  FDatabase := ADatabase;
  CheckSqlite(FDatabase,
    TWinSqlitePrepare(Pointer(@sqlite3_prepare_v2))(FDatabase, PAnsiChar(ASql), Length(ASql), @FStatement, nil));
end;

destructor TSqlStatement.Destroy;
begin
  if FStatement <> nil then
  begin
    TWinSqliteStmtCode(Pointer(@sqlite3_finalize))(FStatement);
  end;
  inherited Destroy;
end;

procedure TSqlStatement.Reset;
begin
  CheckSqlite(FDatabase, TWinSqliteStmtCode(Pointer(@sqlite3_reset))(FStatement));
  CheckSqlite(FDatabase, TWinSqliteStmtCode(Pointer(@sqlite3_clear_bindings))(FStatement));
end;

procedure TSqlStatement.BindText(AIndex: Integer; const AText: UTF8String);
const
  CEmpty: AnsiChar = #0;
var
  LText: PAnsiChar;
begin
  LText := PAnsiChar(AText);
  if AText = '' then
  begin
    LText := @CEmpty;
  end;
  CheckSqlite(FDatabase, TWinSqliteBindText(Pointer(@sqlite3_bind_text))(FStatement, AIndex, LText,
    Length(AText), SQLITE_TRANSIENT));
end;

procedure TSqlStatement.BindNumber(AIndex: Integer; AValue: Int64);
begin
  CheckSqlite(FDatabase, TWinSqliteBindInt64(Pointer(@sqlite3_bind_int64))(FStatement, AIndex, AValue));
end;

function TSqlStatement.Next: Boolean;
var
  LCode: Integer;
begin
  LCode := TWinSqliteStmtCode(Pointer(@sqlite3_step))(FStatement);
  case LCode of
    SQLITE_ROW:
      Result := True;
    SQLITE_DONE:
      Result := False;
  else
    CheckSqlite(FDatabase, LCode);
    Result := False;
  end;
end;

procedure TSqlStatement.Execute;
begin
  if Next then
  begin
    raise Exception.Create('Unexpected SQLite result row');
  end;
end;

function TSqlStatement.Text(AIndex: Integer): UTF8String;
var
  LText: PAnsiChar;
begin
  LText := TWinSqliteColText(Pointer(@sqlite3_column_text))(FStatement, AIndex);
  SetString(Result, LText, TWinSqliteColInt(Pointer(@sqlite3_column_bytes))(FStatement, AIndex));
end;

function TSqlStatement.Number(AIndex: Integer): Int64;
begin
  Result := TWinSqliteColInt64(Pointer(@sqlite3_column_int64))(FStatement, AIndex);
end;

function Scalar(ADatabase: PSQLite3; const ASql: AnsiString): Int64;
var
  LStatement: TSqlStatement;
begin
  LStatement := TSqlStatement.Create(ADatabase, ASql);
  try
    if not LStatement.Next then
    begin
      raise Exception.Create('Missing SQLite scalar');
    end;
    Result := LStatement.Number(0);
  finally
    LStatement.Free;
  end;
end;

function FileSystemPath(const APath: UnicodeString): UnicodeString;
begin
  if Copy(APath, 1, 4) = '\\?\' then
  begin
    Exit(APath);
  end;
  if Copy(APath, 1, 2) = '\\' then
  begin
    Exit('\\?\UNC\' + Copy(APath, 3, Length(APath)));
  end;
  Result := '\\?\' + APath;
end;

function FileStamp(const ATime: TFileTime): Int64;
begin
  Result := Int64(ATime.dwHighDateTime) shl 32 or ATime.dwLowDateTime;
end;

function FileBytes(AHigh, ALow: DWORD): Int64;
begin
  Result := Int64(AHigh) shl 32 or ALow;
end;

function SystemSqlite: UnicodeString;
var
  LBuffer: array[0..MAX_PATH] of WideChar;
  LLength: UINT;
begin
  LLength := GetSystemDirectoryW(@LBuffer[0], Length(LBuffer));
  if (LLength = 0) or (LLength >= Length(LBuffer)) then
  begin
    raise Exception.Create('Cannot resolve the Windows SQLite library path');
  end;
  SetString(Result, PWideChar(@LBuffer[0]), LLength);
  Result := IncludeTrailingPathDelimiter(Result) + 'winsqlite3.dll';
end;

constructor TResearchCatalog.Create(const ARepoRoot, ADatabasePath: String);
var
  LDatabasePath: UnicodeString;
  LDatabaseUtf8: UTF8String;
  LRootRow: TSqlStatement;
  LRootUtf8: UTF8String;
  LSchemaVersion: Int64;
  LApplicationId: Int64;
begin
  inherited Create;
  if (ARepoRoot = '') or (ADatabasePath = '') then
  begin
    raise Exception.Create('The catalog requires an explicit repository root and database path');
  end;
  FRepoRoot := IncludeTrailingPathDelimiter(ExpandFileName(UnicodeString(ARepoRoot)));
  FResearchRoot := FRepoRoot + 'research';
  LDatabasePath := ExpandFileName(UnicodeString(ADatabasePath));
  if UnicodeSameText(Copy(LDatabasePath, 1, Length(FResearchRoot) + 1),
    FResearchRoot + '\') then
  begin
    raise Exception.Create('Store the catalog database outside research');
  end;
  if not DirectoryExists(FResearchRoot) then
  begin
    raise Exception.Create('The configured repository has no research directory');
  end;
  InitializeSQLite(SystemSqlite);
  FSQLiteLoaded := True;
  if TWinSqliteVersion(Pointer(@sqlite3_libversion_number))() < 3043000 then
  begin
    raise Exception.Create('Catalog indexing requires SQLite 3.43+ with FTS5');
  end;
  LDatabaseUtf8 := UTF8Encode(LDatabasePath);
  CheckSqlite(FDatabase, TWinSqliteOpen(Pointer(@sqlite3_open_v2))(PAnsiChar(LDatabaseUtf8), @FDatabase,
    SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE, nil));
  CheckSqlite(FDatabase, TWinSqliteBusy(Pointer(@sqlite3_busy_timeout))(FDatabase, 10000));

  // Existing catalogs only need a read lock while checking their identity.
  if Scalar(FDatabase, 'PRAGMA application_id') = 0 then
    ExecuteSql(FDatabase, 'BEGIN IMMEDIATE')
  else
    ExecuteSql(FDatabase, 'BEGIN');
  try
    LSchemaVersion := Scalar(FDatabase, 'PRAGMA user_version');
    LApplicationId := Scalar(FDatabase, 'PRAGMA application_id');
    if (LSchemaVersion = 0) and (LApplicationId = 0) and
      (Scalar(FDatabase, 'SELECT count(*) FROM sqlite_schema WHERE name NOT LIKE ''sqlite_%''') = 0)
    then
    begin
      ExecuteSql(FDatabase, 'CREATE TABLE catalog_state (repo_root TEXT NOT NULL,' +
        ' revision INTEGER NOT NULL, refreshed_at TEXT NOT NULL,' +
        ' skipped_reparse_points INTEGER NOT NULL)');
      ExecuteSql(FDatabase, 'CREATE TABLE documents (id INTEGER PRIMARY KEY,' +
        ' path TEXT NOT NULL UNIQUE, period TEXT NOT NULL, bytes INTEGER NOT NULL,' +
        ' mtime INTEGER NOT NULL, read_error TEXT NOT NULL)');
      ExecuteSql(FDatabase, 'CREATE VIRTUAL TABLE document_fts USING fts5(' +
        ' body, content='''', contentless_delete=1, tokenize=''unicode61 remove_diacritics 2'')');
      LRootRow := TSqlStatement.Create(FDatabase,
        'INSERT INTO catalog_state VALUES (?1,0,'''',0)');
      try
        LRootRow.BindText(1, UTF8Encode(FRepoRoot));
        LRootRow.Execute;
      finally
        LRootRow.Free;
      end;
      ExecuteSql(FDatabase, 'PRAGMA application_id=' + IntToStr(CatalogApplicationId));
      ExecuteSql(FDatabase, 'PRAGMA user_version=' + IntToStr(CatalogSchemaVersion));
    end
    else if (LApplicationId <> CatalogApplicationId) or
      (LSchemaVersion <> CatalogSchemaVersion) then
    begin
      raise Exception.Create('Database is not a supported Parkinsons Oracle catalog');
    end;

    LRootRow := TSqlStatement.Create(FDatabase, 'SELECT repo_root FROM catalog_state');
    try
      if not LRootRow.Next then
      begin
        raise Exception.Create('Missing repository identity in the catalog');
      end;
      LRootUtf8 := LRootRow.Text(0);
      if not UnicodeSameText(UTF8Decode(LRootUtf8), FRepoRoot) or LRootRow.Next then
      begin
        raise Exception.Create('Catalog is bound to a different repository or has invalid state');
      end;
    finally
      LRootRow.Free;
    end;
    ExecuteSql(FDatabase, 'COMMIT');
  except
    TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
    raise;
  end;
end;

destructor TResearchCatalog.Destroy;
begin
  if FDatabase <> nil then
  begin
    TWinSqliteDbCode(Pointer(@sqlite3_close))(FDatabase);
  end;
  if FSQLiteLoaded then
  begin
    ReleaseSQLite;
  end;
  inherited Destroy;
end;

function CheckedBody(const APath: UnicodeString; ABytes, AMTime: Int64): UTF8String;
var
  LHandle: THandle;
  LInfo: TByHandleFileInformation;
  LStream: THandleStream;
begin
  if (ABytes < 0) or (ABytes > High(Integer) - 1) then
  begin
    raise ECatalogReadError.Create('File exceeds the supported single-document byte size');
  end;
  LHandle := CreateFileW(PWideChar(FileSystemPath(APath)), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    OpenReparsePoint or FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if LHandle = INVALID_HANDLE_VALUE then
  begin
    RaiseLastOSError;
  end;
  try
    if not GetFileInformationByHandle(LHandle, LInfo) then
    begin
      RaiseLastOSError;
    end;
    if (LInfo.dwFileAttributes and (FILE_ATTRIBUTE_REPARSE_POINT or
      FILE_ATTRIBUTE_DIRECTORY)) <> 0 then
    begin
      raise ECatalogReadError.Create('Path ceased to name a regular file during refresh');
    end;
    if (FileBytes(LInfo.nFileSizeHigh, LInfo.nFileSizeLow) <> ABytes) or
      (FileStamp(LInfo.ftLastWriteTime) <> AMTime) then
    begin
      raise ECatalogReadError.Create('File changed before read');
    end;
    LStream := THandleStream.Create(LHandle);
    try
      SetLength(Result, SizeInt(ABytes));
      if ABytes > 0 then
      begin
        LStream.ReadBuffer(Result[1], SizeInt(ABytes));
      end;
    finally
      LStream.Free;
    end;
    if not GetFileInformationByHandle(LHandle, LInfo) then
    begin
      RaiseLastOSError;
    end;
    if (FileBytes(LInfo.nFileSizeHigh, LInfo.nFileSizeLow) <> ABytes) or
      (FileStamp(LInfo.ftLastWriteTime) <> AMTime) then
    begin
      raise ECatalogReadError.Create('File changed during read');
    end;
  finally
    CloseHandle(LHandle);
  end;
  if Pos(#0, Result) <> 0 then
  begin
    raise ECatalogReadError.Create('Embedded NUL in a research text file');
  end;
  if Result <> '' then
  begin
    Utf8ToUnicode(nil, 0, PAnsiChar(Result), Length(Result), False);
  end;
end;

procedure TResearchCatalog.Refresh;
var
  LSeen: TSqlStatement;
  LFind: TSqlStatement;
  LDelete: TSqlStatement;
  LStore: TSqlStatement;
  LIndex: TSqlStatement;
  LFinish: TSqlStatement;
  LChanged: Boolean;
  LReparseCount: Int64;
  LRootAttributes: DWORD;

  procedure InventoryFile(const APath: UnicodeString; const ARelative, APeriod: UTF8String;
    ABytes, AMTime: Int64);
  var
    LId: Int64;
    LHadBody: Boolean;
    LSameMetadata: Boolean;
    LOldError: UTF8String;
    LError: UTF8String;
    LBody: UTF8String;
  begin
    LSeen.Reset;
    LSeen.BindText(1, ARelative);
    LSeen.Execute;

    LFind.Reset;
    LFind.BindText(1, ARelative);
    LId := 0;
    LOldError := '';
    LSameMetadata := False;
    if LFind.Next then
    begin
      LId := LFind.Number(0);
      LSameMetadata := (ABytes = LFind.Number(1)) and (AMTime = LFind.Number(2));
      LOldError := LFind.Text(3);
    end;
    LFind.Reset;
    LHadBody := (LId <> 0) and (LOldError = '');
    if LHadBody and LSameMetadata then
    begin
      Exit;
    end;

    LError := '';
    try
      LBody := CheckedBody(APath, ABytes, AMTime);
    except
      on LFailure: EOSError do
      begin
        LError := UTF8String(LFailure.Message);
      end;
      on LFailure: EReadError do
      begin
        LError := UTF8String(LFailure.Message);
      end;
      on LFailure: ECatalogReadError do
      begin
        LError := UTF8String(LFailure.Message);
      end;
      on LFailure: EConvertError do
      begin
        LError := 'Malformed UTF-8';
      end;
    end;
    if (LId <> 0) and LSameMetadata and (LError = LOldError) then
    begin
      Exit;
    end;
    LChanged := True;
    if LHadBody then
    begin
      LDelete.Reset;
      LDelete.BindNumber(1, LId);
      LDelete.Execute;
    end;
    LStore.Reset;
    LStore.BindText(1, ARelative);
    LStore.BindText(2, APeriod);
    LStore.BindNumber(3, ABytes);
    LStore.BindNumber(4, AMTime);
    LStore.BindText(5, LError);
    if not LStore.Next then
    begin
      raise Exception.Create('Catalog document write yielded no identity');
    end;
    LId := LStore.Number(0);
    LStore.Execute;
    if LError = '' then
    begin
      LIndex.Reset;
      LIndex.BindNumber(1, LId);
      LIndex.BindText(2, LBody);
      LIndex.Execute;
      LIndex.Reset;
    end;
  end;

  procedure Walk(const ADirectory: UnicodeString; const ARelative, APeriod: UTF8String);
  var
    LData: TWin32FindDataW;
    LHandle: THandle;
    LCode: DWORD;
    LName: UnicodeString;
    LPath: UnicodeString;
    LRelative: UTF8String;
    LPeriod: UTF8String;
    LExtension: UnicodeString;
  begin
    LHandle := FindFirstFileW(PWideChar(FileSystemPath(ADirectory + '\*')), LData);
    if LHandle = INVALID_HANDLE_VALUE then
    begin
      LCode := GetLastError;
      if LCode = ERROR_FILE_NOT_FOUND then
      begin
        Exit;
      end;
      raise Exception.CreateFmt('Cannot inventory %s (Windows error %d)', [ARelative, LCode]);
    end;
    try
      repeat
        LName := PWideChar(@LData.cFileName[0]);
        if (LName <> '.') and (LName <> '..') then
        begin
          LPath := ADirectory + '\' + LName;
          LRelative := ARelative + '/' + UTF8Encode(LName);
          LExtension := LowerCase(ExtractFileExt(LName));
          if (LData.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
          begin
            if ((LData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) or
              (LExtension = '.md') or (LExtension = '.txt') or (LExtension = '.tsv') then
            begin
              Inc(LReparseCount);
            end;
          end
          else if (LData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          begin
            LPeriod := APeriod;
            if ARelative = 'research' then
            begin
              LPeriod := UTF8Encode(LName);
            end;
            Walk(LPath, LRelative, LPeriod);
          end
          else if (LExtension = '.md') or (LExtension = '.txt') or (LExtension = '.tsv') then
          begin
            InventoryFile(LPath, LRelative, APeriod,
              FileBytes(LData.nFileSizeHigh, LData.nFileSizeLow),
              FileStamp(LData.ftLastWriteTime));
          end;
        end;
        if not FindNextFileW(LHandle, LData) then
        begin
          LCode := GetLastError;
          if LCode <> ERROR_NO_MORE_FILES then
          begin
            raise Exception.CreateFmt('Cannot finish inventory of %s (Windows error %d)',
              [ARelative, LCode]);
          end;
          Break;
        end;
      until False;
    finally
      Windows.FindClose(LHandle);
    end;
  end;

begin
  LSeen := nil;
  LFind := nil;
  LDelete := nil;
  LStore := nil;
  LIndex := nil;
  LFinish := nil;
  LChanged := False;
  LReparseCount := 0;
  try
    try
      LRootAttributes := GetFileAttributesW(PWideChar(FileSystemPath(FResearchRoot)));
      if (LRootAttributes = INVALID_FILE_ATTRIBUTES) or
        ((LRootAttributes and (FILE_ATTRIBUTE_DIRECTORY or FILE_ATTRIBUTE_REPARSE_POINT)) <>
          FILE_ATTRIBUTE_DIRECTORY) then
      begin
        raise Exception.Create('Cannot inventory a missing, inaccessible or linked research root');
      end;
      ExecuteSql(FDatabase, 'BEGIN IMMEDIATE');
      ExecuteSql(FDatabase, 'CREATE TEMP TABLE IF NOT EXISTS seen (' +
        ' path TEXT PRIMARY KEY) WITHOUT ROWID');
      ExecuteSql(FDatabase, 'DELETE FROM seen');

      LSeen := TSqlStatement.Create(FDatabase, 'INSERT INTO seen VALUES (?1)');
      LFind := TSqlStatement.Create(FDatabase,
        'SELECT id,bytes,mtime,read_error FROM documents WHERE path=?1');
      LDelete := TSqlStatement.Create(FDatabase, 'DELETE FROM document_fts WHERE rowid=?1');
      LStore := TSqlStatement.Create(FDatabase,
        'INSERT INTO documents(path,period,bytes,mtime,read_error) VALUES (?1,?2,?3,?4,?5)' +
        ' ON CONFLICT(path) DO UPDATE SET period=excluded.period,bytes=excluded.bytes,' +
        ' mtime=excluded.mtime,read_error=excluded.read_error RETURNING id');
      LIndex := TSqlStatement.Create(FDatabase,
        'INSERT INTO document_fts(rowid,body) VALUES (?1,?2)');

      Walk(FResearchRoot, 'research', '');
      ExecuteSql(FDatabase, 'DELETE FROM document_fts WHERE rowid IN (' +
        ' SELECT id FROM documents WHERE read_error='''' AND path NOT IN (SELECT path FROM seen))');
      ExecuteSql(FDatabase, 'DELETE FROM documents WHERE path NOT IN (SELECT path FROM seen)');
      LChanged := LChanged or (TWinSqliteDbCode(Pointer(@sqlite3_changes))(FDatabase) > 0);

      LFinish := TSqlStatement.Create(FDatabase,
        'UPDATE catalog_state SET revision=revision+CASE' +
        ' WHEN revision=0 OR ?1<>0 OR skipped_reparse_points<>?2 THEN 1 ELSE 0 END,' +
        ' refreshed_at=strftime(''%Y-%m-%dT%H:%M:%fZ'',''now''), skipped_reparse_points=?2');
      LFinish.BindNumber(1, Ord(LChanged));
      LFinish.BindNumber(2, LReparseCount);
      LFinish.Execute;
      ExecuteSql(FDatabase, 'COMMIT');
      FLastRefreshError := '';
    except
      on LException: Exception do
      begin
        TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
        FLastRefreshError := LException.Message;
        raise;
      end;
    end;
  finally
    LFinish.Free;
    LIndex.Free;
    LStore.Free;
    LDelete.Free;
    LFind.Free;
    LSeen.Free;
  end;
end;

function LiteralMatch(const ATerms: UTF8String): UTF8String;
var
  LStart: Integer;
  LIndex: Integer;
begin
  if (Length(ATerms) > MaximumTermsBytes) or (Pos(#0, ATerms) <> 0) then
  begin
    raise Exception.Create('Invalid catalog search terms');
  end;
  Result := '';
  LStart := 1;
  for LIndex := 1 to Length(ATerms) + 1 do
  begin
    if (LIndex > Length(ATerms)) or (ATerms[LIndex] <= ' ') then
    begin
      if LIndex > LStart then
      begin
        if Result <> '' then
        begin
          Result := Result + ' AND ';
        end;
        Result := Result + '"' + StringReplace(Copy(ATerms, LStart, LIndex - LStart),
          '"', '""', [rfReplaceAll]) + '"';
      end;
      LStart := LIndex + 1;
    end;
  end;
  if Result = '' then
  begin
    raise Exception.Create('Catalog search requires at least one term');
  end;
end;

function TResearchCatalog.Search(const ATerms, APeriod: String;
  AOffset, ALimit: Integer): TJSONObject;
var
  LMatch: UTF8String;
  LPeriod: UTF8String;
  LState: TSqlStatement;
  LCount: TSqlStatement;
  LMatches: TSqlStatement;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LResult: TJSONObject;
  LTotal: Int64;
  LNextOffset: Int64;
begin
  if (AOffset < 0) or (ALimit < 1) or (ALimit > MaximumPageSize) then
  begin
    raise Exception.CreateFmt('Expected offset >= 0 and limit from 1 to %d', [MaximumPageSize]);
  end;
  LMatch := LiteralMatch(UTF8String(ATerms));
  LPeriod := UTF8String(Trim(APeriod));
  if (Length(LPeriod) > 128) or (Pos(#0, LPeriod) <> 0) or
    (Pos('/', LPeriod) <> 0) or (Pos('\', LPeriod) <> 0) then
  begin
    raise Exception.Create('Expected an exact catalog period name or an empty period');
  end;
  LState := nil;
  LCount := nil;
  LMatches := nil;
  LResult := TJSONObject.Create;
  try
    ExecuteSql(FDatabase, 'BEGIN');
    try
      LState := TSqlStatement.Create(FDatabase, 'SELECT revision,refreshed_at,' +
        ' skipped_reparse_points,(SELECT count(*) FROM documents WHERE read_error<>'''')' +
        ' FROM catalog_state');
      if not LState.Next or (LState.Number(0) = 0) then
      begin
        raise Exception.Create('Catalog has not completed a refresh');
      end;
      LResult.Add('revision', LState.Number(0));
      LResult.Add('refreshed_at_utc', LState.Text(1));
      LResult.Add('skipped_reparse_points', LState.Number(2));
      LResult.Add('read_errors', LState.Number(3));
      LResult.Add('last_refresh_error', UTF8String(FLastRefreshError));
      LState.Reset;

      LCount := TSqlStatement.Create(FDatabase, 'SELECT count(*)' + MatchFrom);
      LCount.BindText(1, LMatch);
      LCount.BindText(2, LPeriod);
      if not LCount.Next then
      begin
        raise Exception.Create('Catalog search yielded no count');
      end;
      LTotal := LCount.Number(0);
      LCount.Reset;

      LRows := TJSONArray.Create;
      LResult.Add('matches', LRows);
      if AOffset < LTotal then
      begin
        LMatches := TSqlStatement.Create(FDatabase, 'SELECT documents.path,documents.period' +
          MatchFrom + ' ORDER BY bm25(document_fts),documents.path COLLATE BINARY LIMIT ?3 OFFSET ?4');
        LMatches.BindText(1, LMatch);
        LMatches.BindText(2, LPeriod);
        LMatches.BindNumber(3, ALimit);
        LMatches.BindNumber(4, AOffset);
        while LMatches.Next do
        begin
          LRow := TJSONObject.Create;
          LRows.Add(LRow);
          LRow.Add('path', LMatches.Text(0));
          LRow.Add('period', LMatches.Text(1));
        end;
      end;
      LResult.Add('terms', UTF8String(ATerms));
      LResult.Add('period', LPeriod);
      LResult.Add('offset', AOffset);
      LResult.Add('limit', ALimit);
      LResult.Add('total', LTotal);
      LNextOffset := Int64(AOffset) + LRows.Count;
      if LNextOffset < LTotal then
      begin
        LResult.Add('next_offset', LNextOffset);
      end
      else
      begin
        LResult.Add('next_offset', TJSONNull.Create);
      end;
      ExecuteSql(FDatabase, 'COMMIT');
    except
      TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
      raise;
    end;
    Result := LResult;
    LResult := nil;
  finally
    LMatches.Free;
    LCount.Free;
    LState.Free;
    LResult.Free;
  end;
end;

function TResearchCatalog.ReadStatus(AIncludeDiagnostics: Boolean): TJSONObject;
var
  LState: TSqlStatement;
  LErrors: TSqlStatement;
  LExamples: TJSONArray;
  LItem: TJSONObject;
begin
  LState := nil;
  LErrors := nil;
  Result := TJSONObject.Create;
  try
    try
      LState := TSqlStatement.Create(FDatabase, 'SELECT revision,refreshed_at,' +
        ' skipped_reparse_points,(SELECT count(*) FROM documents),' +
        ' (SELECT count(*) FROM documents WHERE read_error<>''''),' +
        ' (SELECT coalesce(sum(bytes),0) FROM documents WHERE read_error='''') FROM catalog_state');
      if not LState.Next then
      begin
        raise Exception.Create('Missing catalog state');
      end;
      Result.Add('ready', LState.Number(0) > 0);
      Result.Add('revision', LState.Number(0));
      Result.Add('refreshed_at_utc', LState.Text(1));
      Result.Add('skipped_reparse_points', LState.Number(2));
      Result.Add('inventoried', LState.Number(3));
      Result.Add('indexed', LState.Number(3) - LState.Number(4));
      Result.Add('read_errors', LState.Number(4));
      Result.Add('indexed_source_bytes', LState.Number(5));
      Result.Add('scope', 'Regular UTF-8 .md, .txt, and .tsv files under research');
      LState.Reset;

      if not AIncludeDiagnostics then
      begin
        Exit;
      end;
      Result.Add('last_refresh_error', UTF8String(FLastRefreshError));
      LExamples := TJSONArray.Create;
      Result.Add('read_error_examples', LExamples);
      Result.Add('read_error_example_limit', ErrorExampleLimit);
      LErrors := TSqlStatement.Create(FDatabase, 'SELECT path,read_error FROM documents' +
        ' WHERE read_error<>'''' ORDER BY path COLLATE BINARY LIMIT ?1');
      LErrors.BindNumber(1, ErrorExampleLimit);
      while LErrors.Next do
      begin
        LItem := TJSONObject.Create;
        LExamples.Add(LItem);
        LItem.Add('path', LErrors.Text(0));
        LItem.Add('error', LErrors.Text(1));
      end;
    finally
      LErrors.Free;
      LState.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TResearchCatalog.Status(AIncludeDiagnostics: Boolean): TJSONObject;
begin
  ExecuteSql(FDatabase, 'BEGIN');
  try
    Result := ReadStatus(AIncludeDiagnostics);
    try
      ExecuteSql(FDatabase, 'COMMIT');
    except
      Result.Free;
      raise;
    end;
  except
    TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
    raise;
  end;
end;

const
  ExportShardCount = 4096;
  ExportPostingMagic: AnsiString = 'POC1';

function ShardNumber(const ATerm: UTF8String): Integer;
var
  LByte: AnsiChar;
begin
  Result := 0;
  for LByte in ATerm do
  begin
    Result := (Result * 31 + Ord(LByte)) and (ExportShardCount - 1);
  end;
end;

function ShardKey(AShard: Integer): String;
begin
  Result := LowerCase(IntToHex(AShard, 3));
end;

procedure WriteUnsigned(AStream: TStream; AValue: QWord);
var
  LBytes: array[0..9] of Byte;
  LCount: Integer;
begin
  LCount := 0;
  repeat
    LBytes[LCount] := Byte(AValue and $7F);
    AValue := AValue shr 7;
    if AValue <> 0 then
    begin
      LBytes[LCount] := LBytes[LCount] or $80;
    end;
    Inc(LCount);
  until AValue = 0;
  AStream.WriteBuffer(LBytes[0], LCount);
end;

procedure WriteJsonFile(const APath: String; AValue: TJSONData);
var
  LFile: TFileStream;
  LText: UTF8String;
begin
  LText := AValue.AsJSON + #10;
  LFile := TFileStream.Create(APath, fmCreate);
  try
    LFile.WriteBuffer(LText[1], Length(LText));
  finally
    LFile.Free;
  end;
end;

procedure TResearchCatalog.ExportSearch(const AOutputDirectory: String);
var
  LDirectory: String;
  LPostingsDirectory: String;
  LSnapshot: TJSONObject;
  LManifest: TJSONObject;
  LDocuments: TJSONArray;
  LShardKeys: TJSONArray;
  LDocumentsById: TDictionary<Int64, Integer>;
  LDocumentIds: TList<Integer>;
  LDocumentRows: TSqlStatement;
  LTermRows: TSqlStatement;
  LStreams: array[0..ExportShardCount - 1] of TBufferedFileStream;
  LBuffer: TMemoryStream;
  LPreviousTerm: UTF8String;
  LTerm: UTF8String;
  LPreviousRowId: Int64;
  LRowId: Int64;
  LDocumentId: Integer;
  LShard: Integer;
  LTermCount: Int64;
  LMembershipCount: Int64;
  LPostingsBytes: Int64;

  procedure WriteTerm;
  var
    LShardIndex: Integer;
    LId: Integer;
    LPreviousId: Integer;
    LMemberCount: Integer;
    LStream: TBufferedFileStream;
  begin
    if LDocumentIds.Count = 0 then
    begin
      Exit;
    end;
    LDocumentIds.Sort;
    LPreviousId := 0;
    LMemberCount := 0;
    LBuffer.Position := 0;
    for LId in LDocumentIds do
    begin
      if LId > LPreviousId then
      begin
        WriteUnsigned(LBuffer, QWord(LId - LPreviousId));
        LPreviousId := LId;
        Inc(LMemberCount);
      end;
    end;

    LShardIndex := ShardNumber(LPreviousTerm);
    LStream := LStreams[LShardIndex];
    if LStream = nil then
    begin
      LStream := TBufferedFileStream.Create(LPostingsDirectory + ShardKey(LShardIndex) + '.bin',
        fmCreate);
      LStreams[LShardIndex] := LStream;
      LStream.InitializeCache(4096, 1);
      LStream.WriteBuffer(ExportPostingMagic[1], Length(ExportPostingMagic));
    end;
    WriteUnsigned(LStream, QWord(Length(LPreviousTerm)));
    LStream.WriteBuffer(LPreviousTerm[1], Length(LPreviousTerm));
    WriteUnsigned(LStream, QWord(LMemberCount));
    LStream.WriteBuffer(LBuffer.Memory^, LBuffer.Position);
    Inc(LTermCount);
    Inc(LMembershipCount, LMemberCount);
  end;

begin
  if AOutputDirectory = '' then
  begin
    raise EArgumentException.Create('An explicit export directory is required.');
  end;
  LDirectory := IncludeTrailingPathDelimiter(ExpandFileName(AOutputDirectory));
  if UnicodeSameText(Copy(UnicodeString(LDirectory), 1, Length(FResearchRoot) + 1),
    FResearchRoot + '\') then
  begin
    raise EArgumentException.Create('Store the catalog export outside research.');
  end;
  if DirectoryExists(LDirectory) or FileExists(ExcludeTrailingPathDelimiter(LDirectory)) then
  begin
    raise EInOutError.Create('The catalog export requires a new output directory.');
  end;
  LPostingsDirectory := LDirectory + 'postings' + PathDelim;

  LSnapshot := nil;
  LManifest := nil;
  LDocuments := nil;
  LDocumentsById := nil;
  LDocumentIds := nil;
  LDocumentRows := nil;
  LTermRows := nil;
  LBuffer := nil;
  FillChar(LStreams, SizeOf(LStreams), 0);
  LTermCount := 0;
  LMembershipCount := 0;
  LPostingsBytes := 0;
  try
    LDocuments := TJSONArray.Create;
    LDocumentsById := TDictionary<Int64, Integer>.Create;
    LDocumentIds := TList<Integer>.Create;
    LBuffer := TMemoryStream.Create;
    ExecuteSql(FDatabase, 'BEGIN');
    try
      LSnapshot := ReadStatus(False);
      if not LSnapshot.Booleans['ready'] or (FLastRefreshError <> '') then
      begin
        raise EInOutError.Create('Refresh the catalog successfully before exporting search.');
      end;
      if not ForceDirectories(LPostingsDirectory) then
      begin
        raise EInOutError.Create('Cannot create the catalog export directory.');
      end;
      LDocumentRows := TSqlStatement.Create(FDatabase, 'SELECT id,path,period FROM documents' +
        ' WHERE read_error='''' ORDER BY path COLLATE BINARY');
      while LDocumentRows.Next do
      begin
        LDocuments.Add(TJSONArray.Create([LDocumentRows.Text(1), LDocumentRows.Text(2)]));
        LDocumentsById.Add(LDocumentRows.Number(0), LDocuments.Count);
      end;
      FreeAndNil(LDocumentRows);

      // The fts5vocab cursor supplies term order without a positional sort.
      // A posting ID is independent of the SQLite row IDs assigned at refresh.
      ExecuteSql(FDatabase, 'CREATE VIRTUAL TABLE temp.oracle_posting_vocab USING' +
        ' fts5vocab(main, document_fts, instance)');
      LTermRows := TSqlStatement.Create(FDatabase,
        'SELECT term,doc FROM temp.oracle_posting_vocab ORDER BY term');
      LPreviousTerm := '';
      LPreviousRowId := 0;
      while LTermRows.Next do
      begin
        LTerm := LTermRows.Text(0);
        LRowId := LTermRows.Number(1);
        if LTerm <> LPreviousTerm then
        begin
          WriteTerm;
          LDocumentIds.Clear;
          LPreviousTerm := LTerm;
          LPreviousRowId := 0;
        end;
        if LRowId <> LPreviousRowId then
        begin
          if not LDocumentsById.TryGetValue(LRowId, LDocumentId) then
          begin
            raise EInOutError.CreateFmt('FTS posting has no indexed document for row %d.', [LRowId]);
          end;
          LDocumentIds.Add(LDocumentId);
          LPreviousRowId := LRowId;
        end;
      end;
      WriteTerm;
      FreeAndNil(LTermRows);
      ExecuteSql(FDatabase, 'DROP TABLE temp.oracle_posting_vocab');
      ExecuteSql(FDatabase, 'COMMIT');
    except
      FreeAndNil(LTermRows);
      FreeAndNil(LDocumentRows);
      TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
      raise;
    end;

    LManifest := TJSONObject.Create([
      'version', 1,
      'format', 'oracle-fts-postings-v1',
      'documents', 'documents.json',
      'postings', 'postings',
      'tokenizer', 'unicode61 remove_diacritics 2',
      'shard_hash', 'utf8-poly31-4096',
      'document_id_base', 1,
      'document_count', LDocuments.Count,
      'term_count', LTermCount,
      'membership_count', LMembershipCount]);
    LManifest.Add('catalog', LSnapshot);
    LSnapshot := nil;
    LShardKeys := TJSONArray.Create;
    LManifest.Add('shards', LShardKeys);
    for LShard := Low(LStreams) to High(LStreams) do
    begin
      if LStreams[LShard] <> nil then
      begin
        LStreams[LShard].Flush;
        Inc(LPostingsBytes, LStreams[LShard].Size);
        FreeAndNil(LStreams[LShard]);
        LShardKeys.Add(ShardKey(LShard));
      end;
    end;
    LManifest.Add('postings_bytes', LPostingsBytes);
    WriteJsonFile(LDirectory + 'documents.json', LDocuments);
    // The manifest only exists for a completed, flushed export.
    WriteJsonFile(LDirectory + 'manifest.json.part', LManifest);
    if not RenameFile(LDirectory + 'manifest.json.part', LDirectory + 'manifest.json') then
    begin
      raise EInOutError.Create('Cannot publish the completed catalog export manifest.');
    end;
  finally
    for LShard := Low(LStreams) to High(LStreams) do
    begin
      LStreams[LShard].Free;
    end;
    LBuffer.Free;
    LTermRows.Free;
    LDocumentRows.Free;
    LDocumentIds.Free;
    LDocumentsById.Free;
    LDocuments.Free;
    LManifest.Free;
    LSnapshot.Free;
  end;
end;

end.
