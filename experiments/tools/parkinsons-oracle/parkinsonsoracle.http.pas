{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.http;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  fpjson;

type
  TOracleInvoke = function(const AName: String; AArguments: TJSONObject): TJSONObject of object;

procedure ServeOracleWeb(const AWebRoot: String; APort: Word; AInvoke: TOracleInvoke;
  const ALanBinding: String = '');

implementation

uses
  Classes, SysUtils, StrUtils, Types, Sockets, fphttpserver, jsonparser, jsonscanner;

const
  LoopbackAddress = '127.0.0.1';
  MaximumBodyBytes = 16384;
  MaximumTransportBodyBytes = 65536;
  MaximumJsonDepth = 16;

type
  TOracleHttpServer = class(TFPHTTPServer)
  public
    property MaxBodySize;
  end;

  TOracleWeb = class
  private
    FWebRoot: String;
    FBindAddress: String;
    FHost: String;
    FPeerNetwork: LongWord;
    FPeerMask: LongWord;
    FInvoke: TOracleInvoke;
    procedure ConfigureBinding(const ALanBinding: String);
    procedure ServeAsset(AResponse: TFPHTTPConnectionResponse; const AFileName, AMedia: String);
    procedure CallOracle(ARequest: TFPHTTPConnectionRequest;
      AResponse: TFPHTTPConnectionResponse);
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  public
    constructor Create(const AWebRoot: String; APort: Word; AInvoke: TOracleInvoke;
      const ALanBinding: String);
    procedure Run(APort: Word);
  end;

procedure WriteJson(AResponse: TFPHTTPConnectionResponse; AStatus: Integer;
  const AData: TJSONObject);
begin
  AResponse.Code := AStatus;
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.FreeContentStream := True;
  AResponse.ContentStream := TStringStream.Create(UTF8String(AData.AsJSON));
end;

procedure WriteError(AResponse: TFPHTTPConnectionResponse; AStatus: Integer;
  const AMessage: String);
var
  LData: TJSONObject;
begin
  LData := TJSONObject.Create(['error', AMessage]);
  try
    WriteJson(AResponse, AStatus, LData);
  finally
    LData.Free;
  end;
end;

function JsonMedia(const AContentType: String): Boolean;
var
  LSemicolon: Integer;
  LParameter: String;
begin
  LSemicolon := Pos(';', AContentType);
  if LSemicolon = 0 then
  begin
    Exit(SameText(Trim(AContentType), 'application/json'));
  end;
  LParameter := LowerCase(Trim(Copy(AContentType, LSemicolon + 1, MaxInt)));
  Result := SameText(Trim(Copy(AContentType, 1, LSemicolon - 1)), 'application/json') and
    ((LParameter = 'charset=utf-8') or (LParameter = 'charset="utf-8"'));
end;

procedure CheckJsonDepth(const AText: UTF8String);
var
  LChar: AnsiChar;
  LDepth: Integer;
  LQuoted: Boolean;
  LEscape: Boolean;
begin
  LDepth := 0;
  LQuoted := False;
  LEscape := False;
  for LChar in AText do
  begin
    if LQuoted then
    begin
      if LEscape then
      begin
        LEscape := False;
      end
      else
        case LChar of
          '"': LQuoted := False;
          '\': LEscape := True;
        end;
    end
    else
      case LChar of
        '"': LQuoted := True;
        '[', '{':
          begin
            Inc(LDepth);
            if LDepth > MaximumJsonDepth then
            begin
              raise EConvertError.Create('JSON nesting exceeds the request limit.');
            end;
          end;
        ']', '}':
          begin
            Dec(LDepth);
            if LDepth < 0 then
            begin
              raise EConvertError.Create('Invalid JSON body.');
            end;
          end;
      end;
  end;
end;

function ParseBody(const ABytes: TBytes): TJSONData;
var
  LBody: UTF8String;
  LParser: TJSONParser;
begin
  SetString(LBody, PAnsiChar(@ABytes[0]), Length(ABytes));
  if Pos(#0, LBody) > 0 then
  begin
    raise EConvertError.Create('Invalid JSON body.');
  end;
  Utf8ToUnicode(nil, 0, PAnsiChar(LBody), Length(LBody), False);
  CheckJsonDepth(LBody);
  LParser := TJSONParser.Create(LBody, [joUTF8, joStrict]);
  try
    Result := LParser.Parse;
  finally
    LParser.Free;
  end;
end;

function TryIPv4(const AText: String; out AAddress: LongWord): Boolean;
var
  LParts: TStringDynArray;
  LPart: String;
  LOctet: Integer;
begin
  LParts := SplitString(AText, '.');
  AAddress := 0;
  if Length(LParts) <> 4 then
    Exit(False);
  for LPart in LParts do
  begin
    if not TryStrToInt(LPart, LOctet) or (LOctet < 0) or (LOctet > 255) or
      (LPart <> IntToStr(LOctet)) then
      Exit(False);
    AAddress := (AAddress shl 8) or LongWord(LOctet);
  end;
  Result := True;
end;

procedure TOracleWeb.ConfigureBinding(const ALanBinding: String);
var
  LParts: TStringDynArray;
  LAddress: LongWord;
  LPrefix: Integer;
  LPrivatePrefix: Integer;
begin
  if ALanBinding = '' then
  begin
    FBindAddress := LoopbackAddress;
    TryIPv4(FBindAddress, FPeerNetwork);
    FPeerMask := High(LongWord);
    Exit;
  end;
  LParts := SplitString(ALanBinding, '/');
  if (Length(LParts) <> 2) or not TryIPv4(LParts[0], LAddress) or
    not TryStrToInt(LParts[1], LPrefix) or (LPrefix < 1) or (LPrefix > 32) then
    raise EArgumentException.Create('Use a private IPv4 interface in address/prefix format.');

  LPrivatePrefix := 33;
  if LAddress shr 24 = 10 then
    LPrivatePrefix := 8
  else if LAddress shr 20 = $AC1 then
    LPrivatePrefix := 12
  else if LAddress shr 16 = $C0A8 then
    LPrivatePrefix := 16;
  if LPrefix < LPrivatePrefix then
    raise EArgumentException.Create('The LAN binding and its subnet must be private IPv4.');

  FBindAddress := LParts[0];
  FPeerMask := High(LongWord) shl (32 - LPrefix);
  FPeerNetwork := LAddress and FPeerMask;
end;

constructor TOracleWeb.Create(const AWebRoot: String; APort: Word; AInvoke: TOracleInvoke;
  const ALanBinding: String);
begin
  inherited Create;
  if (AWebRoot = '') or (APort = 0) or not Assigned(AInvoke) then
  begin
    raise EArgumentException.Create('A web directory, nonzero port and oracle callback are required.');
  end;
  FWebRoot := IncludeTrailingPathDelimiter(ExpandFileName(AWebRoot));
  if not FileExists(FWebRoot + 'index.html') or not FileExists(FWebRoot + 'app.js') or
    not FileExists(FWebRoot + 'rtl.js') then
  begin
    raise EInOutError.Create('Build the oracle web assets before starting the server.');
  end;
  ConfigureBinding(ALanBinding);
  FHost := FBindAddress;
  if APort <> 80 then
  begin
    FHost := FHost + ':' + IntToStr(APort);
  end;
  FInvoke := AInvoke;
end;

procedure TOracleWeb.ServeAsset(AResponse: TFPHTTPConnectionResponse;
  const AFileName, AMedia: String);
var
  LFile: TFileStream;
begin
  try
    LFile := TFileStream.Create(FWebRoot + AFileName, fmOpenRead or fmShareDenyNone);
  except
    on EFOpenError do
    begin
      WriteError(AResponse, 404, 'Web asset unavailable.');
      Exit;
    end;
  end;
  try
    AResponse.Code := 200;
    AResponse.ContentType := AMedia;
    AResponse.FreeContentStream := True;
    AResponse.ContentStream := LFile;
    LFile := nil;
  finally
    LFile.Free;
  end;
end;

procedure TOracleWeb.CallOracle(ARequest: TFPHTTPConnectionRequest;
  AResponse: TFPHTTPConnectionResponse);
var
  LBytes: TBytes;
  LBody: TJSONData;
  LObject: TJSONObject;
  LName: TJSONData;
  LArguments: TJSONData;
  LResult: TJSONObject;
begin
  if not JsonMedia(ARequest.ContentType) or
    (ARequest.GetFieldByName('Content-Encoding') <> '') then
  begin
    WriteError(AResponse, 415, 'Send an uncompressed UTF-8 application/json body.');
    Exit;
  end;
  LBytes := ARequest.ContentBytes;
  if (Length(LBytes) = 0) or (ARequest.GetFieldByName('Transfer-Encoding') <> '') then
  begin
    WriteError(AResponse, 400, 'A nonempty JSON body with Content-Length is required.');
    Exit;
  end;
  if Length(LBytes) > MaximumBodyBytes then
  begin
    WriteError(AResponse, 413, 'JSON body is too large.');
    Exit;
  end;
  LBody := nil;
  try
    try
      LBody := ParseBody(LBytes);
    except
      on EParserError do
      begin
        WriteError(AResponse, 400, 'Invalid JSON body.');
        Exit;
      end;
      on EJSON do
      begin
        WriteError(AResponse, 400, 'Invalid JSON body.');
        Exit;
      end;
      on EConvertError do
      begin
        WriteError(AResponse, 400, 'Invalid or overly nested UTF-8 JSON body.');
        Exit;
      end;
    end;
    if not (LBody is TJSONObject) then
    begin
      WriteError(AResponse, 400, 'Expected a JSON object with name and arguments.');
      Exit;
    end;
    LObject := TJSONObject(LBody);
    LName := LObject.Find('name');
    LArguments := LObject.Find('arguments');
    if (LObject.Count <> 2) or (LName = nil) or (LName.JSONType <> jtString) or
      (LName.AsString = '') or not (LArguments is TJSONObject) then
    begin
      WriteError(AResponse, 400, 'Expected a nonempty name and an arguments object.');
      Exit;
    end;
    LResult := nil;
    try
      try
        LResult := FInvoke(LName.AsString, TJSONObject(LArguments));
        if LResult = nil then
        begin
          raise EInvalidOp.Create('Oracle returned no result.');
        end;
        WriteJson(AResponse, 200, LResult);
      except
        on LException: EConvertError do
        begin
          WriteError(AResponse, 400, LException.Message);
        end;
        on LException: Exception do
        begin
          WriteError(AResponse, 500, LException.Message);
        end;
      end;
    finally
      LResult.Free;
    end;
  finally
    LBody.Free;
  end;
end;

procedure TOracleWeb.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
const
  Paths: array[0..4] of String = ('/', '/index.html', '/app.js', '/rtl.js', '/oracle.css');
  Files: array[0..4] of String = ('index.html', 'index.html', 'app.js', 'rtl.js', 'oracle.css');
  Types: array[0..4] of String = ('text/html; charset=utf-8', 'text/html; charset=utf-8',
    'application/javascript; charset=utf-8', 'application/javascript; charset=utf-8',
    'text/css; charset=utf-8');
var
  LOrigin: String;
  LPeerAddress: TSockAddr;
  LIndex: Integer;
  LData: TJSONObject;
begin
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  AResponse.SetCustomHeader('X-Content-Type-Options', 'nosniff');
  // Read the accepted socket's IPv4 address in network byte order.
  LPeerAddress := ARequest.Connection.Socket.RemoteAddress;
  if (LPeerAddress.sin_family <> AF_INET) or
    ((ntohl(LPeerAddress.sin_addr.s_addr) and FPeerMask) <> FPeerNetwork) then
  begin
    WriteError(AResponse, 403, 'Use a device on the oracle subnet.');
    Exit;
  end;
  LOrigin := ARequest.GetFieldByName('Origin');
  if (ARequest.Host <> FHost) or
    ((LOrigin <> '') and (LOrigin <> 'http://' + FHost)) then
  begin
    WriteError(AResponse, 403, 'Use the local oracle origin.');
    Exit;
  end;
  if ARequest.URI = '/api/oracle' then
  begin
    if ARequest.Method = 'POST' then
    begin
      CallOracle(ARequest, AResponse);
    end
    else
    begin
      AResponse.SetCustomHeader('Allow', 'POST');
      WriteError(AResponse, 405, 'Use POST for the oracle API.');
    end;
    Exit;
  end;
  LIndex := IndexStr(ARequest.URI, Paths);
  if (LIndex < 0) and (ARequest.URI <> '/health') then
  begin
    WriteError(AResponse, 404, 'Route not found.');
    Exit;
  end;
  if ARequest.Method <> 'GET' then
  begin
    AResponse.SetCustomHeader('Allow', 'GET');
    WriteError(AResponse, 405, 'Use GET for this route.');
    Exit;
  end;
  if LIndex >= 0 then
  begin
    ServeAsset(AResponse, Files[LIndex], Types[LIndex]);
  end
  else
  begin
    LData := TJSONObject.Create(['status', 'ok']);
    try
      WriteJson(AResponse, 200, LData);
    finally
      LData.Free;
    end;
  end;
end;

procedure TOracleWeb.Run(APort: Word);
var
  LServer: TOracleHttpServer;
begin
  LServer := TOracleHttpServer.Create(nil);
  try
    LServer.Address := FBindAddress;
    LServer.Port := APort;
    LServer.ThreadMode := tmNone;
    LServer.KeepConnections := False;
    LServer.RequestReadTimeout := 5000;
    LServer.MaxLineLength := 8192;
    LServer.MaxHeaderCount := 64;
    // Dispatch modest oversize bodies for a JSON 413. Bound transport reads separately.
    LServer.MaxBodySize := MaximumTransportBodyBytes;
    LServer.OnRequest := HandleRequest;
    WriteLn('Parkinson''s oracle web URL: http://', FHost, '/');
    Flush(Output);
    LServer.Active := True;
  finally
    LServer.Free;
  end;
end;

procedure ServeOracleWeb(const AWebRoot: String; APort: Word; AInvoke: TOracleInvoke;
  const ALanBinding: String);
var
  LWeb: TOracleWeb;
begin
  LWeb := TOracleWeb.Create(AWebRoot, APort, AInvoke, ALanBinding);
  try
    LWeb.Run(APort);
  finally
    LWeb.Free;
  end;
end;

end.
