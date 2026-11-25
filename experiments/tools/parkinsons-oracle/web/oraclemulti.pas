{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclemulti;

{$mode delphi}{$H+}

interface

uses SysUtils, JS, oraclestatic, parkinsonsoracle.selection;

type
  TOracleTransport = reference to procedure(const ATool: String;
    AArguments: TJSObject; AReply: TOracleReply);
  TOracleCurrent = reference to function: Boolean;
  TSourceStream = record
    Terms: String;
    Rows: TJSArray;
    Position: Integer;
    NextOffset: Integer;
    Started: Boolean;
    Done: Boolean;
    Total: Integer;
  end;
  TOracleSourceUnion = class
  private
    FTransport: TOracleTransport;
    FStreams: array of TSourceStream;
    FRows: TJSArray;
    FSeen: TJSSet;
    FNextStream: Integer;
    FKind: Integer;
    FGeneration: Integer;
    FRevision: String;
    function HasMore: Boolean;
    function MakePage(AOffset, ALimit: Integer): TJSObject;
  public
    constructor Create(ATransport: TOracleTransport);
    procedure Reset(const ATerms: TStringValues; AKind: Integer);
    procedure Page(AOffset, ALimit: Integer; ACurrent: TOracleCurrent; AReply: TOracleReply);
  end;

function ArgumentSymptoms(AArguments: TJSObject): TStringValues;
procedure LoadClaimUnion(ATransport: TOracleTransport; AArguments: TJSObject;
  ACurrent: TOracleCurrent; AReply: TOracleReply);
function ClaimUnionPage(AUnion: TJSObject; AOffset, ALimit: Integer): TJSObject;

implementation

uses parkinsonsoracle.presentation;

const
  CResponseFields: array[0..4] of String =
    ('revision', 'symptoms', 'symptom', 'scope', 'no_match_reason');
  CClaimFilters: array[0..8] of String =
    ('ingredient', 'preparation', 'scope', 'direction', 'verdict', 'trend', 'round',
      'research_status', 'scorecard_status');

function ValueText(AValue: JSValue): String; external name 'String';

function TextOf(AObject: TJSObject; const AKey: String): String;
begin
  Result := '';
  if (AObject <> nil) and isDefined(AObject[AKey]) and not isNull(AObject[AKey]) then
  begin
    Result := ValueText(AObject[AKey]);
  end;
end;

function NumberOf(AObject: TJSObject; const AKey: String): Integer;
begin
  Result := StrToIntDef(TextOf(AObject, AKey), 0);
end;

function ConfidenceOf(AObject: TJSObject): Double;
var
  LVal: JSValue;
begin
  Result := -1;
  if (AObject <> nil) and isDefined(AObject['confidence']) and not isNull(AObject['confidence']) then
  begin
    LVal := AObject['confidence'];
    if jsTypeOf(LVal) = 'number' then
      Result := Double(LVal)
    else
      Result := StrToFloatDef(ValueText(LVal), -1);
  end;
end;

function RowsOf(AObject: TJSObject; const AKey: String): TJSArray;
begin
  if (AObject <> nil) and TJSArray.isArray(AObject[AKey]) then
  begin
    Result := TJSArray(AObject[AKey]);
  end
  else
  begin
    Result := TJSArray.new;
  end;
end;

function ArgumentSymptoms(AArguments: TJSObject): TStringValues;
var
  LRows: TJSArray;
  LIndex: Integer;
begin
  Result := nil;
  LRows := RowsOf(AArguments, 'symptoms');
  for LIndex := 0 to LRows.Length - 1 do
  begin
    Result := AddSelection(Result, ValueText(LRows[LIndex]));
  end;
  if Length(Result) = 0 then
  begin
    Result := AddSelection(Result, TextOf(AArguments, 'symptom'));
  end;
end;

function ClaimUnionPage(AUnion: TJSObject; AOffset, ALimit: Integer): TJSObject;
var
  LKey: String;
  LRows: TJSArray;
begin
  Result := TJSObject.new;
  for LKey in CResponseFields do
  begin
    if isDefined(AUnion[LKey]) then
    begin
      Result[LKey] := AUnion[LKey];
    end;
  end;
  LRows := RowsOf(AUnion, 'options');
  Result['options'] := LRows.slice(AOffset, AOffset + ALimit);
  Result['offset'] := AOffset;
  Result['total_matches'] := LRows.Length;
  if AOffset + ALimit < LRows.Length then
  begin
    Result['next_offset'] := AOffset + ALimit;
  end;
end;

procedure LoadClaimUnion(ATransport: TOracleTransport; AArguments: TJSObject;
  ACurrent: TOracleCurrent; AReply: TOracleReply);
var
  LSymptoms: TStringValues;
  LCanonical: TStringValues;
  LRows: TJSArray;
  LGroup: Integer;
  LRevision: String;
  LFiltered: Boolean;

  procedure ReadGroup(AOffset: Integer);
  var
    LArguments: TJSObject;
    LKey: String;
  begin
    if not ACurrent() then
    begin
      Exit;
    end;
    LArguments := TJSObject.new;
    for LKey in CClaimFilters do
    begin
      if isDefined(AArguments[LKey]) then
      begin
        LArguments[LKey] := AArguments[LKey];
      end;
    end;
    LArguments['symptom'] := LSymptoms[LGroup];
    LArguments['offset'] := AOffset;
    LArguments['limit'] := 100;
    ATransport('oracle_query', LArguments,
      procedure(AData: TJSObject; const AError: String)
      var
        LBatch: TJSArray;
        LIndex: Integer;
        LNext: Integer;
        LIdentities: TClaimIdentities;
        LOrder: TClaimIndices;
        LResult: TJSObject;
        LOrdered: TJSArray;
        LNames: TJSArray;
        LName: String;
      begin
        if not ACurrent() then
        begin
          Exit;
        end;
        if AError <> '' then
        begin
          AReply(nil, AError);
          Exit;
        end;
        if (LRevision <> '') and (TextOf(AData, 'revision') <> LRevision) then
        begin
          AReply(nil, 'Research changed while combining symptoms. Please search again.');
          Exit;
        end;
        LRevision := TextOf(AData, 'revision');
        LCanonical := AddSelection(LCanonical, TextOf(AData, 'symptom'));
        LFiltered := LFiltered or (TextOf(AData, 'no_match_reason') = 'evidence_filters');
        LBatch := RowsOf(AData, 'options');
        for LIndex := 0 to LBatch.Length - 1 do
        begin
          LRows.push(LBatch[LIndex]);
        end;
        LNext := NumberOf(AData, 'next_offset');
        if (LNext > AOffset) and (LBatch.Length = 0) then
        begin
          AReply(nil, 'A symptom page was empty before its reported end. Please search again.');
          Exit;
        end;
        if (LNext <= AOffset) and
          (AOffset + LBatch.Length < NumberOf(AData, 'total_matches')) then
        begin
          AReply(nil, 'A symptom search ended before its reported total. Please search again.');
          Exit;
        end;
        if LNext > AOffset then
        begin
          ReadGroup(LNext);
          Exit;
        end;
        Inc(LGroup);
        if LGroup < Length(LSymptoms) then
        begin
          ReadGroup(0);
          Exit;
        end;
        SetLength(LIdentities, LRows.Length);
        for LIndex := 0 to LRows.Length - 1 do
        begin
          LIdentities[LIndex].Round := NumberOf(TJSObject(LRows[LIndex]), 'round');
          LIdentities[LIndex].Id := TextOf(TJSObject(LRows[LIndex]), 'claim_id');
          LIdentities[LIndex].Verdict := TextOf(TJSObject(LRows[LIndex]), 'verdict');
          LIdentities[LIndex].Direction := TextOf(TJSObject(LRows[LIndex]), 'hypothesis_direction');
          LIdentities[LIndex].ResearchStatus := TextOf(TJSObject(LRows[LIndex]), 'research_status');
          LIdentities[LIndex].Confidence := ConfidenceOf(TJSObject(LRows[LIndex]));
        end;
        LOrder := OrderedUniqueClaims(LIdentities);
        LOrdered := TJSArray.new;
        for LIndex in LOrder do
        begin
          LOrdered.push(LRows[LIndex]);
        end;
        LNames := TJSArray.new;
        for LName in LCanonical do
        begin
          LNames.push(LName);
        end;
        LResult := TJSObject.new;
        LResult['revision'] := LRevision;
        LResult['symptoms'] := LNames;
        LResult['scope'] := AArguments['scope'];
        LResult['options'] := LOrdered;
        LResult['total_matches'] := LOrdered.Length;
        if Length(LCanonical) = 1 then
        begin
          LResult['symptom'] := LCanonical[0];
        end;
        if LFiltered and (LOrdered.Length = 0) then
        begin
          LResult['no_match_reason'] := 'evidence_filters';
        end;
        AReply(LResult, '');
      end);
  end;

begin
  LSymptoms := ArgumentSymptoms(AArguments);
  LCanonical := nil;
  LRows := TJSArray.new;
  LGroup := 0;
  LRevision := '';
  LFiltered := False;
  if Length(LSymptoms) = 0 then
  begin
    AReply(nil, 'Choose at least one symptom.');
    Exit;
  end;
  ReadGroup(0);
end;

constructor TOracleSourceUnion.Create(ATransport: TOracleTransport);
begin
  inherited Create;
  FTransport := ATransport;
end;

procedure TOracleSourceUnion.Reset(const ATerms: TStringValues; AKind: Integer);
var
  LIndex: Integer;
begin
  Inc(FGeneration);
  SetLength(FStreams, 0);
  SetLength(FStreams, Length(ATerms));
  for LIndex := 0 to High(ATerms) do
  begin
    FStreams[LIndex].Terms := ATerms[LIndex];
    FStreams[LIndex].Rows := TJSArray.new;
    FStreams[LIndex].Position := 0;
    FStreams[LIndex].NextOffset := 0;
    FStreams[LIndex].Started := False;
    FStreams[LIndex].Done := False;
    FStreams[LIndex].Total := 0;
  end;
  FRows := TJSArray.new;
  FSeen := TJSSet.new;
  FNextStream := 0;
  FKind := AKind;
  FRevision := '';
end;

function TOracleSourceUnion.HasMore: Boolean;
var
  LStream: TSourceStream;
begin
  for LStream in FStreams do
  begin
    if (LStream.Position < LStream.Rows.Length) or not LStream.Done then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function TOracleSourceUnion.MakePage(AOffset, ALimit: Integer): TJSObject;
begin
  Result := TJSObject.new;
  Result['matches'] := FRows.slice(AOffset, AOffset + ALimit);
  Result['revision'] := FRevision;
  Result['total_is_exact'] := (Length(FStreams) = 1) and (FKind = SourceKindAll);
  if (Length(FStreams) = 1) and (FKind = SourceKindAll) then
  begin
    Result['total'] := FStreams[0].Total;
  end;
  if FRows.Length > AOffset + ALimit then
  begin
    Result['next_offset'] := AOffset + ALimit;
  end;
end;

procedure TOracleSourceUnion.Page(AOffset, ALimit: Integer; ACurrent: TOracleCurrent;
  AReply: TOracleReply);
var
  LGeneration: Integer;

  procedure Advance;
  var
    LStream: Integer;
    LRow: TJSObject;
    LPath: String;
    LArguments: TJSObject;
    LOffset: Integer;
  begin
    if (LGeneration <> FGeneration) or not ACurrent() then
    begin
      Exit;
    end;
    while (FRows.Length <= AOffset + ALimit) and HasMore do
    begin
      LStream := FNextStream;
      FNextStream := (FNextStream + 1) mod Length(FStreams);
      if FStreams[LStream].Position < FStreams[LStream].Rows.Length then
      begin
        LRow := TJSObject(FStreams[LStream].Rows[FStreams[LStream].Position]);
        Inc(FStreams[LStream].Position);
        LPath := TextOf(LRow, 'path');
        if MatchesSourceKind(LPath, FKind) and not FSeen.has(LPath) then
        begin
          FSeen.add(LPath);
          FRows.push(LRow);
        end;
      end
      else if not FStreams[LStream].Done then
      begin
        LArguments := TJSObject.new;
        LOffset := FStreams[LStream].NextOffset;
        LArguments['terms'] := FStreams[LStream].Terms;
        LArguments['offset'] := LOffset;
        LArguments['limit'] := 100;
        FNextStream := LStream;
        FTransport('oracle_search_catalog', LArguments,
          procedure(AData: TJSObject; const AError: String)
          var
            LNext: Integer;
          begin
            if (LGeneration <> FGeneration) or not ACurrent() then
            begin
              Exit;
            end;
            if AError <> '' then
            begin
              AReply(nil, AError);
              Exit;
            end;
            if (FRevision <> '') and (TextOf(AData, 'revision') <> FRevision) then
            begin
              AReply(nil, 'The catalog changed while combining symptoms. Please search again.');
              Exit;
            end;
            FRevision := TextOf(AData, 'revision');
            FStreams[LStream].Rows := RowsOf(AData, 'matches');
            FStreams[LStream].Position := 0;
            FStreams[LStream].Started := True;
            FStreams[LStream].Total := NumberOf(AData, 'total');
            LNext := NumberOf(AData, 'next_offset');
            FStreams[LStream].Done := LNext <= LOffset;
            FStreams[LStream].NextOffset := LNext;
            if (FStreams[LStream].Rows.Length = 0) and not FStreams[LStream].Done then
            begin
              AReply(nil, 'A catalog page was empty before its reported end. Please try again.');
              Exit;
            end;
            if FStreams[LStream].Done and
              (LOffset + FStreams[LStream].Rows.Length < FStreams[LStream].Total) then
            begin
              AReply(nil, 'A catalog search ended before its reported total. Please try again.');
              Exit;
            end;
            Advance;
          end);
        Exit;
      end;
    end;
    AReply(MakePage(AOffset, ALimit), '');
  end;

begin
  LGeneration := FGeneration;
  Advance;
end;

end.
