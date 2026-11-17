{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.catalog;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  fpjson, sqlite3dyn, SysUtils;

type
  ESourceReadError = class(EConvertError);

  TResearchCatalog = class
  strict private type
    TSearchDocument = record
      Path: UTF8String;
      Period: UTF8String;
    end;

    TSearchWindow = record
      Revision: Int64;
      Expression: UTF8String;
      Period: UTF8String;
      Total: Int64;
      Offset: Integer;
      Rows: array of TSearchDocument;
    end;

  private
    FDatabase: PSQLite3;
    FRepoRoot: UnicodeString;
    FResearchRoot: UnicodeString;
    FSQLiteLoaded: Boolean;
    FLastRefreshError: String;
    FSearchWindows: array[0..3] of TSearchWindow;
    function ReadStatus(AIncludeDiagnostics: Boolean): TJSONObject;
  public
    constructor Create(const ARepoRoot, ADatabasePath: String);
    destructor Destroy; override;
    procedure Refresh;
    procedure ExportSearch(const AOutputDirectory: String);
    function Search(const ATerms, APeriod: String; AOffset, ALimit: Integer): TJSONObject;
    function FindSources(AIdentifiers: TJSONArray): TJSONObject;
    function ReadSource(const APath: String; AOffset: Int64): TJSONObject;
    function Status(AIncludeDiagnostics: Boolean = True): TJSONObject;
  end;

implementation

uses
  BufStream, Classes, Generics.Collections, JwaNative, JwaWinternl, Math, Windows,
  foodexperiment.archiveidentity;

const
  CatalogApplicationId = $504F5243;
  CatalogSchemaVersion = 1;
  MaximumPageSize = 100;
  MaximumTermsBytes = 512;
  MaximumIdentifiers = 100;
  ErrorExampleLimit = 10;
  SourcePageBytes = 16384;
  ResearchPathPrefix = 'research/';
  OpenReparsePoint = $00200000;
  MatchCondition = ' WHERE document_fts MATCH ?1';
  MatchFrom = ' FROM document_fts JOIN documents ON documents.id=document_fts.rowid' +
    MatchCondition;

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

function AddSearchSnapshot(ADatabase: PSQLite3; AResult: TJSONObject;
  const ALastRefreshError: String): Int64;
var
  LState: TSqlStatement;
begin
  LState := TSqlStatement.Create(ADatabase, 'SELECT revision,refreshed_at,' +
    ' skipped_reparse_points,(SELECT count(*) FROM documents WHERE read_error<>'''')' +
    ' FROM catalog_state');
  try
    if not LState.Next or (LState.Number(0) = 0) then
    begin
      raise Exception.Create('Catalog has not completed a refresh');
    end;
    Result := LState.Number(0);
    AResult.Add('revision', Result);
    AResult.Add('refreshed_at_utc', LState.Text(1));
    AResult.Add('skipped_reparse_points', LState.Number(2));
    AResult.Add('read_errors', LState.Number(3));
    AResult.Add('last_refresh_error', UTF8String(ALastRefreshError));
  finally
    LState.Free;
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

function CatalogStampMatches(const AInfo: TByHandleFileInformation;
  ABytes, AMTime: Int64): Boolean;
begin
  Result := (FileBytes(AInfo.nFileSizeHigh, AInfo.nFileSizeLow) = ABytes) and
    (FileStamp(AInfo.ftLastWriteTime) = AMTime);
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

function CheckedBody(const APath: UnicodeString; ABytes, AMTime: Int64;
  APrefixBytes: Integer = 0): UTF8String;
var
  LHandle: THandle;
  LInfo: TByHandleFileInformation;
  LReadBytes: Integer;
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
    if not CatalogStampMatches(LInfo, ABytes, AMTime) then
    begin
      raise ECatalogReadError.Create('File changed before read');
    end;
    LStream := THandleStream.Create(LHandle);
    try
      LReadBytes := ABytes;
      if APrefixBytes > 0 then
      begin
        LReadBytes := Math.Min(LReadBytes, APrefixBytes);
      end;
      SetLength(Result, LReadBytes);
      if LReadBytes > 0 then
      begin
        LStream.ReadBuffer(Result[1], LReadBytes);
      end;
    finally
      LStream.Free;
    end;
    if not GetFileInformationByHandle(LHandle, LInfo) then
    begin
      RaiseLastOSError;
    end;
    if not CatalogStampMatches(LInfo, ABytes, AMTime) then
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
  // An unchanged body was already validated. Its prefix can end mid-character.
  if (APrefixBytes = 0) and (Result <> '') then
  begin
    Utf8ToUnicode(nil, 0, PAnsiChar(Result), Length(Result), False);
  end;
end;

function ResolveWindowsHandlePath(AHandle: THandle; APath: PWideChar;
  ACapacity, AFlags: DWORD): DWORD; stdcall; external 'kernel32.dll'
  name 'GetFinalPathNameByHandleW';

function SourcePathIsExact(const APath: UTF8String): Boolean;
var
  LChar: AnsiChar;
  LStart: Integer;
  LIndex: Integer;
  LExtension: String;
begin
  Result := False;
  if Copy(APath, 1, Length(ResearchPathPrefix)) <> ResearchPathPrefix then
  begin
    Exit;
  end;
  LStart := Length(ResearchPathPrefix) + 1;
  for LIndex := LStart to Length(APath) do
  begin
    LChar := APath[LIndex];
    if (Ord(LChar) < 32) or (LChar in ['\', ':', '<', '>', '"', '|', '?', '*']) then
    begin
      Exit;
    end;
    if LChar = '/' then
    begin
      if (LIndex = LStart) or (APath[LIndex - 1] in ['.', ' ']) then
      begin
        Exit;
      end;
      LStart := LIndex + 1;
    end;
  end;
  if (LStart > Length(APath)) or (APath[Length(APath)] in ['.', ' ']) then
  begin
    Exit;
  end;
  LExtension := LowerCase(ExtractFileExt(String(APath)));
  Result := (LExtension = '.md') or (LExtension = '.txt') or (LExtension = '.tsv');
end;

function FinalSourceHandlePath(AHandle: THandle): UnicodeString;
var
  LLength: DWORD;
begin
  SetLength(Result, 256);
  LLength := ResolveWindowsHandlePath(AHandle, PWideChar(Result), Length(Result), 0);
  if LLength >= DWORD(Length(Result)) then
  begin
    SetLength(Result, LLength);
    LLength := ResolveWindowsHandlePath(AHandle, PWideChar(Result), Length(Result), 0);
  end;
  if (LLength = 0) or (LLength >= DWORD(Length(Result))) then
  begin
    raise ESourceReadError.Create('Cannot verify the indexed source path.');
  end;
  SetLength(Result, LLength);
end;

procedure SourceHandleInfo(AHandle: THandle; ADirectory: Boolean;
  out AInfo: TByHandleFileInformation);
begin
  if (GetFileType(AHandle) <> FILE_TYPE_DISK) or
    not GetFileInformationByHandle(AHandle, AInfo) then
  begin
    raise ESourceReadError.Create('Cannot verify the indexed source.');
  end;
  if ((AInfo.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) or
    (((AInfo.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) <> ADirectory) or
    ((not ADirectory) and (AInfo.nNumberOfLinks <> 1)) then
  begin
    raise ESourceReadError.Create('The indexed source uses an unsupported filesystem link.');
  end;
end;

function OpenSourceChild(AParent: THandle; const AName: UnicodeString;
  ADirectory: Boolean): THandle;
const
  DontReparse = $00001000;
var
  LName: JwaWinternl.TUnicodeString;
  LAttributes: JwaWinternl.TObjectAttributes;
  LStatus: JwaWinternl.TIoStatusBlock;
  LOptions: DWORD;
  LAccess: DWORD;
begin
  if (Length(AName) = 0) or (Length(AName) > High(Word) div SizeOf(WideChar)) then
  begin
    raise ESourceReadError.Create('Cannot verify the indexed source path.');
  end;
  LName.Length := Length(AName) * SizeOf(WideChar);
  LName.MaximumLength := LName.Length;
  LName.Buffer := PWideChar(AName);
  LAttributes := Default(JwaWinternl.TObjectAttributes);
  LAttributes.Length := SizeOf(LAttributes);
  LAttributes.RootDirectory := AParent;
  LAttributes.ObjectName := @LName;
  LAttributes.Attributes := DontReparse;
  LOptions := JwaNative.FILE_OPEN_REPARSE_POINT or JwaNative.FILE_SYNCHRONOUS_IO_NONALERT;
  if ADirectory then
  begin
    LAccess := FILE_LIST_DIRECTORY or FILE_TRAVERSE or FILE_READ_ATTRIBUTES or SYNCHRONIZE;
    LOptions := LOptions or JwaNative.FILE_DIRECTORY_FILE;
  end
  else
  begin
    LAccess := GENERIC_READ or SYNCHRONIZE;
    LOptions := LOptions or JwaNative.FILE_NON_DIRECTORY_FILE;
  end;
  if JwaWinternl.NtOpenFile(@Result, LAccess, @LAttributes, @LStatus, FILE_SHARE_READ,
    LOptions) <> 0 then
  begin
    raise ESourceReadError.Create('The indexed source is missing, linked, or unavailable.');
  end;
end;

function OpenVerifiedSource(const ARoot, ASuffix: UnicodeString): THandle;
var
  LParents: TList<THandle>;
  LParent: THandle;
  LChild: THandle;
  LHandle: THandle;
  LInfo: TByHandleFileInformation;
  LExpectedPath: UnicodeString;
  LSegment: UnicodeString;
  LStart: Integer;
  LSeparator: Integer;
begin
  LParents := TList<THandle>.Create;
  try
    LParent := CreateFileW(PWideChar(FileSystemPath(ARoot)),
      FILE_LIST_DIRECTORY or FILE_TRAVERSE or FILE_READ_ATTRIBUTES or SYNCHRONIZE,
      FILE_SHARE_READ, nil, OPEN_EXISTING, OpenReparsePoint or FILE_FLAG_BACKUP_SEMANTICS, 0);
    if LParent = INVALID_HANDLE_VALUE then
    begin
      raise ESourceReadError.Create('The research directory is unavailable.');
    end;
    LParents.Add(LParent);
    SourceHandleInfo(LParent, True, LInfo);
    LExpectedPath := FinalSourceHandlePath(LParent);
    if not UnicodeSameText(LExpectedPath, FileSystemPath(ARoot)) then
    begin
      raise ESourceReadError.Create('Cannot verify the research directory.');
    end;

    // Resolve each single name against the actual parent handle. An intermediate
    // directory replacement cannot redirect a later open through an ambient path.
    LStart := 1;
    repeat
      LSeparator := Pos('/', ASuffix, LStart);
      if LSeparator = 0 then
      begin
        LSegment := Copy(ASuffix, LStart, MaxInt);
      end
      else
      begin
        LSegment := Copy(ASuffix, LStart, LSeparator - LStart);
      end;
      LChild := OpenSourceChild(LParent, LSegment, LSeparator <> 0);
      try
        SourceHandleInfo(LChild, LSeparator <> 0, LInfo);
        LExpectedPath := LExpectedPath + '\' + LSegment;
        if FinalSourceHandlePath(LChild) <> LExpectedPath then
        begin
          raise ESourceReadError.Create('The indexed source path no longer matches.');
        end;
        if LSeparator = 0 then
        begin
          Result := LChild;
          LChild := INVALID_HANDLE_VALUE;
          Exit;
        end;
        LParents.Add(LChild);
        LParent := LChild;
        LChild := INVALID_HANDLE_VALUE;
        LStart := LSeparator + 1;
      finally
        if LChild <> INVALID_HANDLE_VALUE then
        begin
          CloseHandle(LChild);
        end;
      end;
    until False;
  finally
    for LHandle in LParents do
    begin
      CloseHandle(LHandle);
    end;
    LParents.Free;
  end;
end;

function Utf8Continuation(AByte: AnsiChar): Boolean;
begin
  Result := (Ord(AByte) and $C0) = $80;
end;

function ReadSourcePage(AHandle: THandle; AOffset, ABytes, AMTime: Int64): UTF8String;
var
  LInfo: TByHandleFileInformation;
  LStream: THandleStream;
  LReadBytes: Integer;
  LPageBytes: Integer;
begin
  Result := '';
  SourceHandleInfo(AHandle, False, LInfo);
  if not CatalogStampMatches(LInfo, ABytes, AMTime) then
  begin
    raise ESourceReadError.Create('The source changed since its index refresh.');
  end;
  if ABytes = AOffset then
  begin
    Exit;
  end;

  LReadBytes := SourcePageBytes + 1;
  if ABytes - AOffset < LReadBytes then
  begin
    LReadBytes := ABytes - AOffset;
  end;
  LStream := THandleStream.Create(AHandle);
  try
    LStream.Position := AOffset;
    SetLength(Result, LReadBytes);
    LStream.ReadBuffer(Result[1], LReadBytes);
  finally
    LStream.Free;
  end;
  SourceHandleInfo(AHandle, False, LInfo);
  if not CatalogStampMatches(LInfo, ABytes, AMTime) then
  begin
    raise ESourceReadError.Create('The source changed while it was being read.');
  end;
  if Utf8Continuation(Result[1]) then
  begin
    raise ESourceReadError.Create('The source offset must be a UTF-8 character boundary.');
  end;
  if LReadBytes > SourcePageBytes then
  begin
    LPageBytes := SourcePageBytes;
    while (LPageBytes > 0) and Utf8Continuation(Result[LPageBytes + 1]) do
    begin
      Dec(LPageBytes);
    end;
    if LPageBytes = 0 then
    begin
      raise ESourceReadError.Create('The indexed source contains invalid UTF-8.');
    end;
    SetLength(Result, LPageBytes);
  end;
  if Pos(#0, Result) <> 0 then
  begin
    raise ESourceReadError.Create('The indexed source is not readable UTF-8 text.');
  end;
  try
    Utf8ToUnicode(nil, 0, PAnsiChar(Result), Length(Result), False);
  except
    on EConvertError do
    begin
      raise ESourceReadError.Create('The indexed source is not readable UTF-8 text.');
    end;
  end;
end;

function TResearchCatalog.ReadSource(const APath: String; AOffset: Int64): TJSONObject;
var
  LPath: UTF8String;
  LPeriod: UTF8String;
  LText: UTF8String;
  LBytes: Int64;
  LMTime: Int64;
  LSource: TSqlStatement;
  LHandle: THandle;
begin
  LPath := UTF8String(APath);
  if not SourcePathIsExact(LPath) then
  begin
    raise ESourceReadError.Create('Use an exact indexed research text path.');
  end;
  LSource := TSqlStatement.Create(FDatabase,
    'SELECT period,bytes,mtime FROM documents WHERE path=?1 COLLATE BINARY AND read_error=''''');
  try
    LSource.BindText(1, LPath);
    if not LSource.Next then
    begin
      raise ESourceReadError.Create('The source is unavailable in the current index.');
    end;
    LPeriod := LSource.Text(0);
    LBytes := LSource.Number(1);
    LMTime := LSource.Number(2);
  finally
    LSource.Free;
  end;
  if (AOffset < 0) or (AOffset > LBytes) then
  begin
    raise ESourceReadError.Create('The source offset is outside this document.');
  end;

  LHandle := OpenVerifiedSource(FResearchRoot,
    Copy(UTF8Decode(LPath), Length(ResearchPathPrefix) + 1, MaxInt));
  try
    LText := ReadSourcePage(LHandle, AOffset, LBytes, LMTime);
  finally
    CloseHandle(LHandle);
  end;
  Result := TJSONObject.Create(['path', LPath, 'period', LPeriod, 'text', LText,
    'offset', AOffset]);
  if AOffset + Length(LText) < LBytes then
  begin
    Result.Add('next_offset', AOffset + Length(LText));
  end;
end;

procedure TResearchCatalog.Refresh;
var
  LSeen: TSqlStatement;
  LFind: TSqlStatement;
  LDelete: TSqlStatement;
  LStore: TSqlStatement;
  LIndex: TSqlStatement;
  LDeleteIdentifiers: TSqlStatement;
  LStoreIdentifier: TSqlStatement;
  LFinish: TSqlStatement;
  LRebuildIdentifiers: Boolean;
  LRefreshRegistries: Boolean;
  LRefreshTctr: Boolean;
  LChanged: Boolean;
  LReparseCount: Int64;
  LRootAttributes: DWORD;

  procedure StoreIdentifier(ADocumentId: Int64; const AIdentifier: String);
  begin
    LStoreIdentifier.Reset;
    LStoreIdentifier.BindNumber(1, ADocumentId);
    LStoreIdentifier.BindText(2, UTF8String(AIdentifier));
    LStoreIdentifier.Execute;
  end;

  procedure IndexSourceIdentifiers(ADocumentId: Int64; const ABody: UTF8String);
  var
    LIdentity: TArchiveIdentity;
  begin
    LIdentity := ParseArchiveIdentity(ABody);
    if LIdentity.Pmid <> '' then
    begin
      StoreIdentifier(ADocumentId, 'PMID:' + LIdentity.Pmid);
    end;
    if LIdentity.Pmcid <> '' then
    begin
      StoreIdentifier(ADocumentId, 'PMCID:' + LIdentity.Pmcid);
    end;
    if LIdentity.Doi <> '' then
    begin
      StoreIdentifier(ADocumentId, 'DOI:' + LIdentity.Doi);
    end;
  end;

  procedure IndexRegistryIdentifier(ADocumentId: Int64; const ARegistryId: String;
    const ABody: UTF8String);
  begin
    if ARegistryId = '' then
    begin
      Exit;
    end;
    if Copy(ARegistryId, 1, 3) = 'NCT' then
    begin
      if ParseTrialArchiveIdentifier(ABody, ARegistryId) = ARegistryId then
      begin
        StoreIdentifier(ADocumentId, ARegistryId);
      end;
    end
    else if OtherRegistryHeaderMatches(ABody, ARegistryId) then
    begin
      StoreIdentifier(ADocumentId, ARegistryId);
    end;
  end;

  procedure InventoryFile(const APath: UnicodeString; const ARelative, APeriod: UTF8String;
    ABytes, AMTime: Int64);
  var
    LId: Int64;
    LHadBody: Boolean;
    LArchivedSource: Boolean;
    LSameMetadata: Boolean;
    LOldError: UTF8String;
    LError: UTF8String;
    LBody: UTF8String;
    LPrefixBytes: Integer;
    LRegistryId: String;
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
    LArchivedSource := (APeriod <> '') and
      (Pos('/Source-Text/', ARelative) = Length(ResearchPathPrefix) + Length(APeriod) + 1) and
      (ExtractFileExt(LowerCase(String(ARelative))) = '.txt');
    LRegistryId := '';
    if LArchivedSource and (LRefreshRegistries or LRefreshTctr or
      not (LHadBody and LSameMetadata)) then
    begin
      LRegistryId := RegistryArchiveFileIdentifier(ExtractFileName(String(ARelative)));
    end;
    if LHadBody and LSameMetadata and not ((LArchivedSource and LRebuildIdentifiers) or
      ((LRegistryId <> '') and (LRefreshRegistries or
      (LRefreshTctr and (Copy(LRegistryId, 1, 4) = 'TCTR'))))) then
    begin
      Exit;
    end;

    LError := '';
    LPrefixBytes := 0;
    if LHadBody and LSameMetadata then
    begin
      LPrefixBytes := ArchiveHeaderBytes;
    end;
    try
      LBody := CheckedBody(APath, ABytes, AMTime, LPrefixBytes);
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
      if LArchivedSource and LRebuildIdentifiers and (LError = '') then
      begin
        IndexSourceIdentifiers(LId, LBody);
      end;
      if LError = '' then
      begin
        IndexRegistryIdentifier(LId, LRegistryId, LBody);
      end;
      Exit;
    end;
    LChanged := True;
    if LHadBody then
    begin
      LDelete.Reset;
      LDelete.BindNumber(1, LId);
      LDelete.Execute;
      if LArchivedSource then
      begin
        LDeleteIdentifiers.Reset;
        LDeleteIdentifiers.BindNumber(1, LId);
        LDeleteIdentifiers.Execute;
      end;
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
      if LArchivedSource then
      begin
        IndexSourceIdentifiers(LId, LBody);
      end;
      IndexRegistryIdentifier(LId, LRegistryId, LBody);
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
  LDeleteIdentifiers := nil;
  LStoreIdentifier := nil;
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
      ExecuteSql(FDatabase, 'CREATE INDEX IF NOT EXISTS documents_read_errors' +
        ' ON documents(path) WHERE read_error<>''''');
      ExecuteSql(FDatabase, 'CREATE TABLE IF NOT EXISTS source_identifiers (' +
        ' identifier TEXT NOT NULL, document_id INTEGER NOT NULL,' +
        ' PRIMARY KEY(identifier, document_id)) WITHOUT ROWID');
      ExecuteSql(FDatabase, 'CREATE INDEX IF NOT EXISTS source_identifiers_document' +
        ' ON source_identifiers(document_id)');
      ExecuteSql(FDatabase, 'CREATE TABLE IF NOT EXISTS source_identifier_state (' +
        ' id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL)');
      ExecuteSql(FDatabase, 'INSERT OR IGNORE INTO source_identifier_state VALUES (1,-1)');
      LRebuildIdentifiers := Scalar(FDatabase, 'SELECT source_identifier_state.revision' +
        ' <> catalog_state.revision FROM source_identifier_state, catalog_state') <> 0;
      ExecuteSql(FDatabase, 'CREATE TABLE IF NOT EXISTS source_registry_v4_state (' +
        ' id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL)');
      ExecuteSql(FDatabase, 'INSERT OR IGNORE INTO source_registry_v4_state VALUES (1,-1)');
      LRefreshRegistries := LRebuildIdentifiers or
        (Scalar(FDatabase, 'SELECT source_registry_v4_state.revision <> catalog_state.revision' +
          ' FROM source_registry_v4_state, catalog_state') <> 0);
      ExecuteSql(FDatabase, 'CREATE TABLE IF NOT EXISTS source_tctr_state (' +
        ' id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL)');
      ExecuteSql(FDatabase, 'INSERT OR IGNORE INTO source_tctr_state VALUES (1,-1)');
      LRefreshTctr := LRebuildIdentifiers or
        (Scalar(FDatabase, 'SELECT source_tctr_state.revision <> catalog_state.revision' +
          ' FROM source_tctr_state, catalog_state') <> 0);
      // An identifier backfill changes the results even when document bytes match.
      LChanged := LChanged or LRefreshRegistries or LRefreshTctr;
      if LRebuildIdentifiers then
      begin
        // Also recover when an older executable has refreshed the text catalog.
        ExecuteSql(FDatabase, 'DELETE FROM source_identifiers');
      end
      else if LRefreshRegistries then
      begin
        ExecuteSql(FDatabase, 'DELETE FROM source_identifiers WHERE identifier GLOB ''NCT[0-9]*''');
      end;
      if LRefreshTctr and not LRebuildIdentifiers then
      begin
        ExecuteSql(FDatabase, 'DELETE FROM source_identifiers WHERE identifier GLOB ''TCTR[0-9]*''');
      end;
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
      LDeleteIdentifiers := TSqlStatement.Create(FDatabase,
        'DELETE FROM source_identifiers WHERE document_id=?1');
      LStoreIdentifier := TSqlStatement.Create(FDatabase,
        'INSERT OR IGNORE INTO source_identifiers(identifier,document_id) VALUES (?2,?1)');

      Walk(FResearchRoot, 'research', '');
      ExecuteSql(FDatabase, 'DELETE FROM document_fts WHERE rowid IN (' +
        ' SELECT id FROM documents WHERE read_error='''' AND path NOT IN (SELECT path FROM seen))');
      ExecuteSql(FDatabase, 'DELETE FROM source_identifiers WHERE document_id IN (' +
        ' SELECT id FROM documents WHERE path NOT IN (SELECT path FROM seen))');
      ExecuteSql(FDatabase, 'DELETE FROM documents WHERE path NOT IN (SELECT path FROM seen)');
      LChanged := LChanged or (TWinSqliteDbCode(Pointer(@sqlite3_changes))(FDatabase) > 0);

      LFinish := TSqlStatement.Create(FDatabase,
        'UPDATE catalog_state SET revision=revision+CASE' +
        ' WHEN revision=0 OR ?1<>0 OR skipped_reparse_points<>?2 THEN 1 ELSE 0 END,' +
        ' refreshed_at=strftime(''%Y-%m-%dT%H:%M:%fZ'',''now''), skipped_reparse_points=?2');
      LFinish.BindNumber(1, Ord(LChanged));
      LFinish.BindNumber(2, LReparseCount);
      LFinish.Execute;
      ExecuteSql(FDatabase, 'UPDATE source_identifier_state' +
        ' SET revision=(SELECT revision FROM catalog_state) WHERE id=1');
      ExecuteSql(FDatabase, 'UPDATE source_registry_v4_state' +
        ' SET revision=(SELECT revision FROM catalog_state) WHERE id=1');
      // A running reader from before the backfill can use the same updated keys.
      if Scalar(FDatabase, 'SELECT count(*) FROM sqlite_schema' +
        ' WHERE type=''table'' AND name=''source_registry_v3_state''') <> 0 then
      begin
        ExecuteSql(FDatabase, 'UPDATE source_registry_v3_state' +
          ' SET revision=(SELECT revision FROM catalog_state) WHERE id=1');
      end;
      ExecuteSql(FDatabase, 'UPDATE source_tctr_state' +
        ' SET revision=(SELECT revision FROM catalog_state) WHERE id=1');
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
    LStoreIdentifier.Free;
    LDeleteIdentifiers.Free;
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
  LCountFrom: AnsiString;
  LPageFrom: AnsiString;
  LCount: TSqlStatement;
  LMatches: TSqlStatement;
  LRows: TJSONArray;
  LRow: TJSONObject;
  LResult: TJSONObject;
  LRevision: Int64;
  LCachedIndex: Integer;
  LWindowIndex: Integer;
  LWindow: TSearchWindow;
  LTotal: Int64;
  LPageSize: Integer;
  LRowIndex: Integer;
  LStart: Integer;
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
  LPageFrom := MatchFrom;
  if LPeriod = '' then
  begin
    // Refresh keeps FTS rows and document IDs in the same transaction.
    LCountFrom := ' FROM document_fts' + MatchCondition;
  end
  else
  begin
    LPageFrom := LPageFrom + ' AND documents.period=?2';
    LCountFrom := LPageFrom;
  end;
  LCount := nil;
  LMatches := nil;
  LResult := TJSONObject.Create;
  try
    ExecuteSql(FDatabase, 'BEGIN');
    try
      LRevision := AddSearchSnapshot(FDatabase, LResult, FLastRefreshError);

      // The same read transaction pins the revision, totals and ranks.
      LCachedIndex := -1;
      LWindow := Default(TSearchWindow);
      for LWindowIndex := Low(FSearchWindows) to High(FSearchWindows) do
      begin
        if (FSearchWindows[LWindowIndex].Revision = LRevision) and
          (FSearchWindows[LWindowIndex].Expression = LMatch) and
          (FSearchWindows[LWindowIndex].Period = LPeriod) then
        begin
          LCachedIndex := LWindowIndex;
          LWindow := FSearchWindows[LCachedIndex];
          Break;
        end;
      end;
      if LCachedIndex < 0 then
      begin
        LCount := TSqlStatement.Create(FDatabase, 'SELECT count(*)' + LCountFrom);
        LCount.BindText(1, LMatch);
        if LPeriod <> '' then
        begin
          LCount.BindText(2, LPeriod);
        end;
        if not LCount.Next then
        begin
          raise Exception.Create('Catalog search yielded no count');
        end;
        LWindow.Revision := LRevision;
        LWindow.Expression := LMatch;
        LWindow.Period := LPeriod;
        LWindow.Total := LCount.Number(0);
        LCount.Reset;
        LCachedIndex := High(FSearchWindows);
      end;
      LTotal := LWindow.Total;

      LRows := TJSONArray.Create;
      LResult.Add('matches', LRows);
      if AOffset < LTotal then
      begin
        LPageSize := Math.Min(Int64(ALimit), LTotal - AOffset);
        if (AOffset < LWindow.Offset) or
          (Int64(AOffset) + LPageSize > Int64(LWindow.Offset) + Length(LWindow.Rows)) then
        begin
          LWindow.Offset := AOffset;
          LWindow.Rows := nil;
          SetLength(LWindow.Rows, Math.Min(Int64(MaximumPageSize), LTotal - AOffset));
          LMatches := TSqlStatement.Create(FDatabase, 'SELECT documents.path,documents.period' +
            LPageFrom + ' ORDER BY bm25(document_fts),documents.path COLLATE BINARY' +
            ' LIMIT ?3 OFFSET ?4');
          LMatches.BindText(1, LMatch);
          if LPeriod <> '' then
          begin
            LMatches.BindText(2, LPeriod);
          end;
          LMatches.BindNumber(3, Length(LWindow.Rows));
          LMatches.BindNumber(4, AOffset);
          for LRowIndex := 0 to High(LWindow.Rows) do
          begin
            if not LMatches.Next then
            begin
              raise Exception.Create('Catalog search yielded fewer results than counted');
            end;
            LWindow.Rows[LRowIndex].Path := LMatches.Text(0);
            LWindow.Rows[LRowIndex].Period := LMatches.Text(1);
          end;
          LMatches.Reset;
        end;
        LStart := AOffset - LWindow.Offset;
        for LRowIndex := LStart to LStart + LPageSize - 1 do
        begin
          LRow := TJSONObject.Create;
          LRows.Add(LRow);
          LRow.Add('path', LWindow.Rows[LRowIndex].Path);
          LRow.Add('period', LWindow.Rows[LRowIndex].Period);
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
      // Keep a few recently used searches so citation checks do not evict the current page.
      for LWindowIndex := LCachedIndex downto 1 do
      begin
        FSearchWindows[LWindowIndex] := FSearchWindows[LWindowIndex - 1];
      end;
      FSearchWindows[0] := LWindow;
    except
      TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
      raise;
    end;
    Result := LResult;
    LResult := nil;
  finally
    LMatches.Free;
    LCount.Free;
    LResult.Free;
  end;
end;

function TResearchCatalog.FindSources(AIdentifiers: TJSONArray): TJSONObject;
var
  LIdentifiers: array of String;
  LIndex: Integer;
  LInput: TJSONData;
  LRevision: Int64;
  LNeedsRegistries: Boolean;
  LNeedsTctr: Boolean;
  LQuery: TSqlStatement;
  LResults: TJSONArray;
  LMatches: TJSONArray;
  LResult: TJSONObject;
begin
  if (AIdentifiers.Count < 1) or (AIdentifiers.Count > MaximumIdentifiers) then
  begin
    raise EConvertError.CreateFmt('Provide from 1 to %d source identifiers.', [MaximumIdentifiers]);
  end;
  SetLength(LIdentifiers, AIdentifiers.Count);
  LNeedsRegistries := False;
  LNeedsTctr := False;
  for LIndex := 0 to High(LIdentifiers) do
  begin
    LInput := AIdentifiers.Items[LIndex];
    if (LInput.JSONType <> jtString) or (Length(LInput.AsString) > MaximumTermsBytes) or
      (Pos(#0, LInput.AsString) <> 0) then
    begin
      raise EConvertError.CreateFmt('Invalid source identifier at position %d.', [LIndex + 1]);
    end;
    LIdentifiers[LIndex] := NormalizeArchiveIdentifier(LInput.AsString);
    if LIdentifiers[LIndex] = '' then
    begin
      raise EConvertError.CreateFmt('Expected a PMID, PMCID, DOI or supported registry ID at position %d.',
        [LIndex + 1]);
    end;
    LNeedsRegistries := LNeedsRegistries or
      (Copy(LIdentifiers[LIndex], 1, 3) = 'NCT') or
      (OtherRegistryIdentifier(LIdentifiers[LIndex]) <> '');
    LNeedsTctr := LNeedsTctr or (Copy(LIdentifiers[LIndex], 1, 4) = 'TCTR');
  end;

  LQuery := nil;
  LResult := TJSONObject.Create;
  try
    ExecuteSql(FDatabase, 'BEGIN');
    try
      LRevision := AddSearchSnapshot(FDatabase, LResult, FLastRefreshError);
      if (Scalar(FDatabase, 'SELECT count(*) FROM sqlite_schema' +
        ' WHERE type=''table'' AND name=''source_identifier_state''') = 0) or
        (Scalar(FDatabase, 'SELECT revision FROM source_identifier_state WHERE id=1') <>
          LRevision) then
      begin
        raise Exception.Create('Source identifiers need a catalog refresh');
      end;
      if LNeedsRegistries and
        ((Scalar(FDatabase, 'SELECT count(*) FROM sqlite_schema' +
          ' WHERE type=''table'' AND name=''source_registry_v4_state''') = 0) or
        (Scalar(FDatabase, 'SELECT revision FROM source_registry_v4_state WHERE id=1') <> LRevision)) then
      begin
        raise Exception.Create('Source registry identifiers need a catalog refresh');
      end;
      if LNeedsTctr and
        ((Scalar(FDatabase, 'SELECT count(*) FROM sqlite_schema' +
          ' WHERE type=''table'' AND name=''source_tctr_state''') = 0) or
          (Scalar(FDatabase, 'SELECT revision FROM source_tctr_state WHERE id=1') <> LRevision)) then
      begin
        raise Exception.Create('Thai trial identifiers need a catalog refresh');
      end;
      LResults := TJSONArray.Create;
      LResult.Add('results', LResults);
      LQuery := TSqlStatement.Create(FDatabase, 'SELECT documents.path,documents.period' +
        ' FROM source_identifiers JOIN documents ON documents.id=source_identifiers.document_id' +
        ' WHERE source_identifiers.identifier=?1 ORDER BY documents.path COLLATE BINARY');
      for LIndex := 0 to High(LIdentifiers) do
      begin
        LMatches := TJSONArray.Create;
        LResults.Add(TJSONObject.Create(['identifier', LIdentifiers[LIndex], 'matches', LMatches]));
        LQuery.BindText(1, UTF8String(LIdentifiers[LIndex]));
        while LQuery.Next do
        begin
          LMatches.Add(TJSONObject.Create(['path', LQuery.Text(0), 'period', LQuery.Text(1)]));
        end;
        LQuery.Reset;
      end;
      ExecuteSql(FDatabase, 'COMMIT');
    except
      TWinSqliteExec(Pointer(@sqlite3_exec))(FDatabase, 'ROLLBACK', nil, nil, nil);
      raise;
    end;
    Result := LResult;
    LResult := nil;
  finally
    LQuery.Free;
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
