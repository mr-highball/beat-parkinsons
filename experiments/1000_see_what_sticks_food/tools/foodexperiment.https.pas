{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.https;

{$mode delphi}
{$H+}

interface

uses
  Classes, Windows, WinHttp;

type
  TSearchResponse = record
    Status: DWORD;
    RetryAfterSeconds: DWORD;
    RedirectLocation: UnicodeString;
    ContentType: UnicodeString;
    Body: UTF8String;
  end;

  TEuropePmc = class
  private
    FSession: HINTERNET;
    FConnection: HINTERNET;
    function Request(const APath, ABody: UTF8String; const AContentType: UnicodeString;
      AOutput: TStream = nil; const AExtraHeaders: UnicodeString = ''): TSearchResponse;
  public
    constructor Create(const AHost: UnicodeString = 'www.ebi.ac.uk';
      AReceiveTimeoutMs: Integer = 20000);
    destructor Destroy; override;
    function Search(const AQuery: UTF8String): TSearchResponse;
    function SearchPage(const AQuery, ACursor: UTF8String; APageSize: Integer;
      const ASort: UTF8String = ''): TSearchResponse;
    function SearchPageSoap(const AQuery, ACursor: UTF8String; APageSize: Integer;
      const ASort: UTF8String = ''): TSearchResponse;
    function GetPath(const APath: UTF8String; AOutput: TStream = nil): TSearchResponse;
    function PostJson(const APath, ABody: UTF8String): TSearchResponse;
    function PostForm(const APath, ABody: UTF8String; AOutput: TStream = nil): TSearchResponse;
  end;

function UtcTimestamp: UTF8String;
function UrlEncode(const AValue: UTF8String): UTF8String;

implementation

uses
  SysUtils, foodexperiment.epmcsoap;

const
  MaximumResponseBytes = 8 * 1024 * 1024;
  SearchPath = '/europepmc/webservices/rest/search?format=json&resultType=core';
  SoapSearchPath = '/europepmc/webservices/soap';

function UtcTimestamp: UTF8String;
var
  LSystemTime: TSystemTime;
begin
  GetSystemTime(LSystemTime);
  Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2dZ', [
    LSystemTime.wYear, LSystemTime.wMonth, LSystemTime.wDay,
    LSystemTime.wHour, LSystemTime.wMinute, LSystemTime.wSecond
  ]);
end;

function UrlEncode(const AValue: UTF8String): UTF8String;
const
  CHex = '0123456789ABCDEF';
var
  LByte: Byte;
  LLength: Integer;
  I: Integer;
begin
  SetLength(Result, Length(AValue) * 3);
  LLength := 0;
  for I := 1 to Length(AValue) do
  begin
    LByte := Ord(AValue[I]);
    if Char(LByte) in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~'] then
    begin
      Inc(LLength);
      Result[LLength] := Char(LByte);
    end
    else
    begin
      Result[LLength + 1] := '%';
      Result[LLength + 2] := CHex[(LByte shr 4) + 1];
      Result[LLength + 3] := CHex[(LByte and 15) + 1];
      Inc(LLength, 3);
    end;
  end;
  SetLength(Result, LLength);
end;

procedure CheckRequest(ASucceeded: Boolean; const AOperation: String);
var
  LCode: DWORD;
begin
  if not ASucceeded then
  begin
    LCode := GetLastError;
    raise EOSError.CreateFmt('%s failed (%d): %s', [
      AOperation, LCode, SysErrorMessage(LCode)
    ]);
  end;
end;

constructor TEuropePmc.Create(const AHost: UnicodeString; AReceiveTimeoutMs: Integer);
begin
  inherited Create;
  FSession := WinHttpOpen('FoodThoughtExperiment/1.0', WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
    nil, nil, 0);
  CheckRequest(FSession <> nil, 'WinHttpOpen');
  CheckRequest(WinHttpSetTimeouts(FSession, 10000, 10000, 10000, AReceiveTimeoutMs),
    'WinHttpSetTimeouts');
  FConnection := WinHttpConnect(FSession, PWideChar(AHost), INTERNET_DEFAULT_HTTPS_PORT, 0);
  CheckRequest(FConnection <> nil, 'WinHttpConnect');
end;

destructor TEuropePmc.Destroy;
begin
  if FConnection <> nil then
  begin
    WinHttpCloseHandle(FConnection);
  end;
  if FSession <> nil then
  begin
    WinHttpCloseHandle(FSession);
  end;
  inherited Destroy;
end;

function TEuropePmc.Search(const AQuery: UTF8String): TSearchResponse;
begin
  Result := GetPath(SearchPath + '&pageSize=20&query=' + UrlEncode(AQuery));
end;

function TEuropePmc.SearchPage(const AQuery, ACursor: UTF8String;
  APageSize: Integer; const ASort: UTF8String): TSearchResponse;
var
  LPath: UTF8String;
begin
  if (APageSize < 1) or (APageSize > 1000) or (ACursor = '') then
  begin
    raise EArgumentException.Create('Invalid Europe PMC page size or empty cursor');
  end;
  LPath := SearchPath + '&pageSize=' + IntToStr(APageSize) +
    '&cursorMark=' + UrlEncode(ACursor) + '&query=' + UrlEncode(AQuery);
  if ASort <> '' then
  begin
    LPath := LPath + '&sort=' + UrlEncode(ASort);
  end;
  Result := GetPath(LPath);
end;

function TEuropePmc.SearchPageSoap(const AQuery, ACursor: UTF8String;
  APageSize: Integer; const ASort: UTF8String): TSearchResponse;
begin
  Result := Request(SoapSearchPath, SoapSearchRequest(AQuery, ACursor, APageSize, ASort),
    'text/xml; charset=UTF-8', nil, 'SOAPAction: ""'#13#10);
  if Result.Status = 200 then
  begin
    Result.Body := SoapSearchResult(Result.Body, Result.ContentType);
  end;
end;

function TEuropePmc.GetPath(const APath: UTF8String; AOutput: TStream): TSearchResponse;
begin
  Result := Request(APath, '', '', AOutput);
end;

function TEuropePmc.PostJson(const APath, ABody: UTF8String): TSearchResponse;
begin
  if ABody = '' then
  begin
    raise EArgumentException.Create('Expected a JSON request body');
  end;
  Result := Request(APath, ABody, 'application/json');
end;

function TEuropePmc.PostForm(const APath, ABody: UTF8String; AOutput: TStream): TSearchResponse;
begin
  if ABody = '' then
  begin
    raise EArgumentException.Create('Expected a form request body');
  end;
  Result := Request(APath, ABody, 'application/x-www-form-urlencoded', AOutput);
end;

function TEuropePmc.Request(const APath, ABody: UTF8String;
  const AContentType: UnicodeString; AOutput: TStream;
  const AExtraHeaders: UnicodeString): TSearchResponse;
var
  LPath: UnicodeString;
  LMethod: UnicodeString;
  LHeaders: UnicodeString;
  LBodyPointer: Pointer;
  LBodyBytes: DWORD;
  LRequest: HINTERNET;
  LHeaderBytes: DWORD;
  LLocation: array[0..4095] of WideChar;
  LType: array[0..511] of WideChar;
  LReadCount: DWORD;
  LBuffer: array[0..8191] of Byte;
  LBody: TMemoryStream;
  LDestination: TStream;
begin
  Result := Default(TSearchResponse);
  if (APath = '') or (APath[1] <> '/') then
  begin
    raise EArgumentException.Create('Expected a host-relative HTTPS path');
  end;
  LPath := UTF8Decode(APath);
  LBodyBytes := Length(ABody);
  LBodyPointer := nil;
  LHeaders := '';
  LMethod := 'GET';
  if LBodyBytes > 0 then
  begin
    LMethod := 'POST';
    LHeaders := 'Content-Type: ' + AContentType + #13#10 + AExtraHeaders;
    LBodyPointer := @ABody[1];
  end;
  LRequest := WinHttpOpenRequest(FConnection, PWideChar(LMethod), PWideChar(LPath),
    nil, nil, nil, WINHTTP_FLAG_SECURE);
  CheckRequest(LRequest <> nil, 'WinHttpOpenRequest');
  try
    CheckRequest(WinHttpSendRequest(LRequest, PWideChar(LHeaders), Length(LHeaders),
      LBodyPointer, LBodyBytes, LBodyBytes, 0), 'WinHttpSendRequest');
    CheckRequest(WinHttpReceiveResponse(LRequest, nil), 'WinHttpReceiveResponse');
    LHeaderBytes := SizeOf(Result.Status);
    CheckRequest(WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_STATUS_CODE or
      WINHTTP_QUERY_FLAG_NUMBER, nil, @Result.Status, @LHeaderBytes, nil), 'WinHttpQueryHeaders');

    if Result.Status <> 200 then
    begin
      if (Result.Status >= 300) and (Result.Status < 400) then
      begin
        LHeaderBytes := SizeOf(LLocation);
        if WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_LOCATION, nil, @LLocation[0],
          @LHeaderBytes, nil) then
        begin
          Result.RedirectLocation := PWideChar(@LLocation[0]);
        end;
      end;
      LHeaderBytes := SizeOf(Result.RetryAfterSeconds);
      WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_RETRY_AFTER or WINHTTP_QUERY_FLAG_NUMBER,
        nil, @Result.RetryAfterSeconds, @LHeaderBytes, nil);
      Exit;
    end;

    LHeaderBytes := SizeOf(LType);
    if WinHttpQueryHeaders(LRequest, WINHTTP_QUERY_CONTENT_TYPE, nil, @LType[0],
      @LHeaderBytes, nil) then
    begin
      Result.ContentType := PWideChar(@LType[0]);
    end;
    LBody := nil;
    LDestination := AOutput;
    if LDestination = nil then
    begin
      LBody := TMemoryStream.Create;
      LDestination := LBody;
    end;
    try
      repeat
        CheckRequest(WinHttpReadData(LRequest, @LBuffer[0], SizeOf(LBuffer), @LReadCount),
          'WinHttpReadData');
        if (LBody <> nil) and (LBody.Size + LReadCount > MaximumResponseBytes) then
        begin
          raise EStreamError.Create('Europe PMC response exceeds the byte limit');
        end;
        LDestination.WriteBuffer(LBuffer, LReadCount);
      until LReadCount = 0;
      if (LBody <> nil) and (LBody.Size > 0) then
      begin
        SetLength(Result.Body, LBody.Size);
        Move(LBody.Memory^, Result.Body[1], LBody.Size);
      end;
    finally
      LBody.Free;
    end;
  finally
    WinHttpCloseHandle(LRequest);
  end;
end;

end.
