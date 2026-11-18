{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegraphdata;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses JS;

function EmbeddedGraphModel: TJSObject;
function EmbeddedGraphJSON: String;
function EmbeddedGraphDigest: String;

implementation

{$IFNDEF ORACLE_STATIC}
{$I oraclegraph.inc}
{$ENDIF}

function EmbeddedGraphJSON: String;
{$IFNDEF ORACLE_STATIC}
var
  LParts: TJSArray;
  LPart: String;
{$ENDIF}
begin
  {$IFDEF ORACLE_STATIC}
  Result := '';
  {$ELSE}
  LParts := TJSArray.new;
  for LPart in COracleGraphParts do
  begin
    LParts.push(LPart);
  end;
  Result := LParts.join('');
  {$ENDIF}
end;

function EmbeddedGraphModel: TJSObject;
var
  LJSON: String;
begin
  LJSON := EmbeddedGraphJSON;
  Result := nil;
  if LJSON <> '' then
  begin
    Result := TJSObject(TJSJSON.parse(LJSON));
  end;
end;

function EmbeddedGraphDigest: String;
begin
  {$IFDEF ORACLE_STATIC}
  Result := '';
  {$ELSE}
  Result := COracleGraphSHA256;
  {$ENDIF}
end;

end.
