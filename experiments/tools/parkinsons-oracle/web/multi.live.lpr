{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program MultiLive;

{$mode delphi}{$H+}

uses SysUtils, JS, Web, oraclestatic, oraclemulti, parkinsonsoracle.selection,
  parkinsonsoracle.presentation, parkinsonsoracle.trend;

var
  GEndpoint: String;
  GCalls: Integer;
  GArguments: TJSObject;
  GSources: TOracleSourceUnion;
  GSeen: TJSSet;

function HostFetch(const AUrl: String; AOptions: TJSObject): TJSPromise;
  external name 'fetch';

function HostArguments: TJSArray;
begin
  asm
    return process.argv;
  end;
end;

function TextOf(AObject: TJSObject; const AKey: String): String;
begin
  if isDefined(AObject[AKey]) and not isNull(AObject[AKey]) then
    Result := String(AObject[AKey])
  else
    Result := '';
end;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function Current: Boolean;
begin
  Result := True;
end;

procedure Transport(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
var
  LOptions: TJSObject;
  LHeaders: TJSObject;
  LBody: TJSObject;
begin
  Inc(GCalls);
  LBody := TJSObject.new;
  LBody['name'] := ATool;
  LBody['arguments'] := AArguments;
  LOptions := TJSObject.new;
  LOptions['method'] := 'POST';
  LOptions['body'] := TJSJSON.stringify(LBody);
  LHeaders := TJSObject.new;
  LHeaders['Content-Type'] := 'application/json';
  LOptions['headers'] := LHeaders;
  HostFetch(GEndpoint, LOptions)._then(
    function(AResponse: JSValue): JSValue
    begin
      Result := TJSResponse(AResponse).json();
    end)._then(
    function(AValue: JSValue): JSValue
    begin
      AReply(TJSObject(AValue), TextOf(TJSObject(AValue), 'error'));
      Result := Undefined;
    end);
end;

procedure CheckSourcePage(AData: TJSObject; const AError: String);
var
  LRows: TJSArray;
  LIndex: Integer;
  LPath: String;
begin
  Require(AError = '', AError);
  LRows := TJSArray(AData['matches']);
  Require(LRows.Length = 8, 'Expected eight live source leads.');
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LPath := TextOf(TJSObject(LRows[LIndex]), 'path');
    Require(not GSeen.has(LPath), 'Duplicate across live source pages.');
    GSeen.add(LPath);
  end;
end;

procedure CheckTrends(AData: TJSObject; const AError: String);
var
  LRows: TJSArray;
  LKeys: TJSSet;
  LIndex: Integer;
  LRow: TJSObject;
  LTerms: TStringValues;
begin
  Require(AError = '', AError);
  LRows := TJSArray(AData['options']);
  LKeys := TJSSet.new;
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    Require(ClaimTrend(TextOf(LRow, 'verdict'), TextOf(LRow, 'hypothesis_direction')) =
      'eases', 'Trend filter lost during live OR query.');
    LKeys.add(TextOf(LRow, 'claim_id'));
  end;
  Require(LKeys.has('0904') and LKeys.has('0065'),
    'Live OR easing results must retain both tremor and pain findings.');
  WriteLn('live_easing_claims=', LRows.Length, ' both_selected_symptoms_retained=true');
  LTerms := nil;
  LTerms := AddSelection(LTerms, 'tremor');
  LTerms := AddSelection(LTerms, 'pain');
  GSources := TOracleSourceUnion.Create(@Transport);
  GSources.Reset(LTerms, SourceKindAll);
  GSeen := TJSSet.new;
  GSources.Page(0, 8, @Current,
    procedure(AFirst: TJSObject; const AFirstError: String)
    begin
      CheckSourcePage(AFirst, AFirstError);
      GSources.Page(8, 8, @Current,
        procedure(ASecond: TJSObject; const ASecondError: String)
        begin
          CheckSourcePage(ASecond, ASecondError);
          WriteLn('live_unique_source_leads=', GSeen.size,
            ' claims_and_sources_use_shared_production_OR_adapter=true calls=', GCalls);
        end);
    end);
end;

procedure CheckFrozen(AData: TJSObject; const AError: String);
var
  LRows: TJSArray;
  LKeys: TJSSet;
  LIndex: Integer;
  LRow: TJSObject;
begin
  Require(AError = '', AError);
  LRows := TJSArray(AData['options']);
  Require(LRows.Length = 420, 'Expected 210 tremor OR 210 pain frozen pairs.');
  LKeys := TJSSet.new;
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LRow := TJSObject(LRows[LIndex]);
    LKeys.add(TextOf(LRow, 'round') + '/' + TextOf(LRow, 'claim_id'));
  end;
  Require(LKeys.size = 420, 'Live frozen union contains duplicate claims.');
  WriteLn('live_frozen_OR_claims=', LRows.Length, ' revision=', TextOf(AData, 'revision'));
  GArguments['scope'] := 'assessed';
  GArguments['round'] := 1;
  GArguments['trend'] := 'eases';
  LoadClaimUnion(@Transport, GArguments, @Current, @CheckTrends);
end;

var
  LSymptoms: TJSArray;
begin
  Require(HostArguments.Length = 3, 'Pass the runtime Oracle API URL.');
  GEndpoint := String(HostArguments[2]);
  GArguments := TJSObject.new;
  LSymptoms := TJSArray.new;
  LSymptoms.push('rest tremor severity', 'pain severity');
  GArguments['symptoms'] := LSymptoms;
  GArguments['scope'] := 'frozen';
  LoadClaimUnion(@Transport, GArguments, @Current, @CheckFrozen);
end.
