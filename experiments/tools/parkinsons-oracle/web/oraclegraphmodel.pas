{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegraphmodel;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, JS;

const
  GraphKinds: array[0..3] of String = ('symptom', 'ingredient', 'study', 'source');
  GraphGroupNames: array[0..3] of String = ('Symptoms', 'Ingredients', 'Studies', 'Saved sources');

{ An indexed, read-only projection of the committed oracle model. References
  retain the original claim and assessment objects; no text inference creates edges. }
type
  TOracleGraphModel = class
  private
    FModel: TJSObject;
    FNodes: TJSObject;
    FAdjacent: TJSObject;
    FNodeCount: Integer;
    FEdgeCount: Integer;
    procedure AddNode(const AKey, AKind, ALabel, AValue: String);
    procedure AddEdge(const AKey, AFrom, ATo, AKind, ALabel, ATrend: String;
      AClaim, AAssessment: TJSObject);
  public
    constructor Create(AModel: TJSObject);
    function Node(const AKey: String): TJSObject;
    function Other(AEdge: TJSObject; const ANode: String): String;
    function Neighbors(const AKey: String): TJSArray;
    function Connections(const AKey: String): TJSArray;
    function Revision: String;
    property NodeCount: Integer read FNodeCount;
    property EdgeCount: Integer read FEdgeCount;
  end;

function GraphText(AObject: TJSObject; const AKey: String): String;
function GraphRows(AObject: TJSObject; const AKey: String): TJSArray;
function GraphKey(const AKind, AValue: String): String;
function ReferenceFile(const APath: String): String;
function SavedSourceTitle(const APath: String): String;
function GraphKindIndex(const AKind: String): Integer;
function GraphEdgeTone(AEdge: TJSObject): String;

implementation

uses oraclevocab, parkinsonsoracle.graph, parkinsonsoracle.trend;

function ValueText(AValue: JSValue): String; external name 'String';

function GraphText(AObject: TJSObject; const AKey: String): String;
begin
  Result := '';
  if (AObject <> nil) and isDefined(AObject[AKey]) and not isNull(AObject[AKey]) then
  begin
    Result := ValueText(AObject[AKey]);
  end;
end;

function GraphRows(AObject: TJSObject; const AKey: String): TJSArray;
begin
  Result := TJSArray.new;
  if (AObject <> nil) and TJSArray.isArray(AObject[AKey]) then
  begin
    Result := TJSArray(AObject[AKey]);
  end;
end;

function GraphKey(const AKind, AValue: String): String;
begin
  Result := AKind + ':' + AValue;
end;

function GraphKindIndex(const AKind: String): Integer;
var
  LIndex: Integer;
begin
  for LIndex := Low(GraphKinds) to High(GraphKinds) do
  begin
    if GraphKinds[LIndex] = AKind then
    begin
      Exit(LIndex);
    end;
  end;
  raise Exception.Create('Unrecognized graph node kind: ' + AKind);
end;

function GraphEdgeTone(AEdge: TJSObject): String;
var
  LKind: String;
  LVerdict: String;
begin
  Result := GraphText(AEdge, 'trend');
  if Result <> '' then
  begin
    Exit;
  end;
  LKind := GraphText(AEdge, 'kind');
  if LKind = 'claim' then
  begin
    LVerdict := GraphText(TJSObject(AEdge['claim']), 'verdict');
    if (LVerdict = 'False') or (LVerdict = 'Maybe False') then
    begin
      Result := 'challenged';
    end;
  end
  else if ((LKind = 'assessment') or (LKind = 'outcome')) and
    (GraphText(TJSObject(AEdge['assessment']), 'role') = 'opposes') then
  begin
    Result := 'challenged';
  end;
end;

function ReferenceFile(const APath: String): String;
var
  LHash: Integer;
begin
  LHash := Pos('#', APath);
  Result := APath;
  if LHash > 0 then
  begin
    Result := Copy(APath, 1, LHash - 1);
  end;
end;

function SavedSourceTitle(const APath: String): String;
var
  LFile: String;
begin
  LFile := ReferenceFile(APath);
  Result := ChangeFileExt(ExtractFileName(LFile), '');
  if SameText(Result, 'README') then
    Result := ExtractFileName(ExtractFileDir(LFile)) + ' overview';
  Result := StringReplace(Result, '-', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '_', ' ', [rfReplaceAll]);
end;

procedure TOracleGraphModel.AddNode(const AKey, AKind, ALabel, AValue: String);
var
  LNode: TJSObject;
begin
  if isDefined(FNodes[AKey]) then
  begin
    Exit;
  end;
  LNode := TJSObject.new;
  LNode['key'] := AKey;
  LNode['kind'] := AKind;
  LNode['label'] := ALabel;
  LNode['value'] := AValue;
  FNodes[AKey] := LNode;
  FAdjacent[AKey] := TJSArray.new;
  Inc(FNodeCount);
end;

procedure TOracleGraphModel.AddEdge(const AKey, AFrom, ATo, AKind, ALabel, ATrend: String;
  AClaim, AAssessment: TJSObject);
var
  LEdge: TJSObject;
begin
  if (Node(AFrom) = nil) or (Node(ATo) = nil) then
  begin
    raise Exception.Create('A graph link has a missing endpoint.');
  end;
  LEdge := TJSObject.new;
  LEdge['key'] := AKey;
  LEdge['from'] := AFrom;
  LEdge['to'] := ATo;
  LEdge['kind'] := AKind;
  LEdge['label'] := ALabel;
  LEdge['trend'] := ATrend;
  LEdge['claim'] := AClaim;
  LEdge['assessment'] := AAssessment;
  TJSArray(FAdjacent[AFrom]).push(LEdge);
  TJSArray(FAdjacent[ATo]).push(LEdge);
  Inc(FEdgeCount);
end;

constructor TOracleGraphModel.Create(AModel: TJSObject);
var
  LClaims: TJSArray;
  LAssessments: TJSArray;
  LClaim: TJSObject;
  LAssessment: TJSObject;
  LReferences: TJSArray;
  LCitedPaths: TJSSet;
  LIndex: Integer;
  LAssessmentIndex: Integer;
  LSymptom: String;
  LIngredient: String;
  LStudy: String;
  LSource: String;
  LPath: String;
  LClaimKey: String;
  LEdgeKey: String;
  LRole: String;
  LDirection: String;
begin
  FModel := AModel;
  FNodes := TJSObject.new;
  FAdjacent := TJSObject.new;
  LClaims := GraphRows(FModel, 'claims');
  for LIndex := 0 to LClaims.Length - 1 do
  begin
    LClaim := TJSObject(LClaims[LIndex]);
    LSymptom := GraphKey('symptom', GraphText(LClaim, 'symptom'));
    LIngredient := GraphKey('ingredient', GraphText(LClaim, 'ingredient'));
    AddNode(LSymptom, 'symptom', FriendlySymptom(GraphText(LClaim, 'symptom')),
      GraphText(LClaim, 'symptom'));
    AddNode(LIngredient, 'ingredient', Capitalized(GraphText(LClaim, 'ingredient')),
      GraphText(LClaim, 'ingredient'));
    LClaimKey := GraphText(LClaim, 'round') + '/' + GraphText(LClaim, 'claim_id');
    LDirection := GraphText(LClaim, 'hypothesis_direction');
    AddEdge('claim:' + LClaimKey, LSymptom, LIngredient, 'claim',
      GraphClaimLabel(GraphText(LClaim, 'verdict'), LDirection),
      ClaimTrend(GraphText(LClaim, 'verdict'), LDirection), LClaim, nil);
    LCitedPaths := TJSSet.new;
    LAssessments := GraphRows(LClaim, 'assessments');
    for LAssessmentIndex := 0 to LAssessments.Length - 1 do
    begin
      LAssessment := TJSObject(LAssessments[LAssessmentIndex]);
      if GraphText(LAssessment, 'study') = '' then
      begin
        Continue;
      end;
      LStudy := GraphKey('study', GraphText(LAssessment, 'study'));
      AddNode(LStudy, 'study', GraphText(LAssessment, 'study'), GraphText(LAssessment, 'study'));
      LEdgeKey := LClaimKey + '/assessment:' + IntToStr(LAssessmentIndex);
      LRole := GraphText(LAssessment, 'role');
      AddEdge(LEdgeKey + '/ingredient', LIngredient, LStudy, 'assessment',
        GraphAssessmentLabel(LRole, LDirection), GraphAssessmentTrend(LRole, LDirection),
        LClaim, LAssessment);
      AddEdge(LEdgeKey + '/symptom', LStudy, LSymptom, 'outcome',
        GraphAssessmentLabel(LRole, LDirection), GraphAssessmentTrend(LRole, LDirection),
        LClaim, LAssessment);
      LPath := ReferenceFile(GraphText(LAssessment, 'local_reference'));
      if LPath <> '' then
      begin
        LCitedPaths.add(LPath);
        LSource := GraphKey('source', LPath);
        AddNode(LSource, 'source', SavedSourceTitle(LPath), LPath);
        AddEdge(LEdgeKey + '/source', LStudy, LSource, 'reference',
          'Read saved source', '', LClaim, LAssessment);
      end;
    end;
    LReferences := GraphRows(LClaim, 'local_references');
    for LAssessmentIndex := 0 to LReferences.Length - 1 do
    begin
      LPath := ReferenceFile(String(LReferences[LAssessmentIndex]));
      if (Copy(LPath, 1, 9) <> 'research/') or LCitedPaths.has(LPath) then
        Continue;
      LCitedPaths.add(LPath);
      LSource := GraphKey('source', LPath);
      AddNode(LSource, 'source', SavedSourceTitle(LPath), LPath);
      LEdgeKey := LClaimKey + '/citation:' + IntToStr(LAssessmentIndex);
      AddEdge(LEdgeKey + '/ingredient', LIngredient, LSource, 'citation',
        'Cited in claim', '', LClaim, nil);
      AddEdge(LEdgeKey + '/symptom', LSymptom, LSource, 'citation',
        'Cited in claim', '', LClaim, nil);
    end;
  end;
end;

function TOracleGraphModel.Node(const AKey: String): TJSObject;
begin
  Result := nil;
  if isDefined(FNodes[AKey]) then
  begin
    Result := TJSObject(FNodes[AKey]);
  end;
end;

function TOracleGraphModel.Other(AEdge: TJSObject; const ANode: String): String;
begin
  Result := GraphText(AEdge, 'to');
  if Result = ANode then
  begin
    Result := GraphText(AEdge, 'from');
  end;
end;

function EdgeRank(AEdge: TJSObject): Integer;
begin
  if GraphText(AEdge, 'trend') <> '' then
  begin
    Exit(0);
  end;
  if GraphEdgeTone(AEdge) = 'challenged' then
  begin
    Exit(1);
  end;
  if (GraphText(AEdge, 'kind') = 'claim') and
    (GraphText(TJSObject(AEdge['claim']), 'evidence_scope') = 'frozen') then
  begin
    Exit(3);
  end;
  Result := 2;
end;

function TOracleGraphModel.Neighbors(const AKey: String): TJSArray;
var
  LRows: TJSArray;
  LGroups: array[0..3] of TJSArray;
  LGroup: TJSArray;
  LIndex: Integer;
  LGroupIndex: Integer;
  LLongest: Integer;
  LEdge: TJSObject;
  LCompare: TJSArrayCompareCallBack;
begin
  Result := TJSArray.new;
  if Node(AKey) = nil then
  begin
    Exit;
  end;
  LRows := TJSArray(FAdjacent[AKey]);
  LCompare :=
    function(ALeft, ARight: JSValue): NativeInt
    begin
      Result := EdgeRank(TJSObject(ALeft)) - EdgeRank(TJSObject(ARight));
      if Result = 0 then
      begin
        Result := CompareStr(GraphText(TJSObject(ALeft), 'key'), GraphText(TJSObject(ARight), 'key'));
      end;
    end;
  for LGroupIndex := Low(LGroups) to High(LGroups) do
  begin
    LGroups[LGroupIndex] := TJSArray.new;
  end;
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LEdge := TJSObject(LRows[LIndex]);
    LGroupIndex := GraphKindIndex(GraphText(Node(Other(LEdge, AKey)), 'kind'));
    LGroups[LGroupIndex].push(LEdge);
  end;
  LLongest := 0;
  for LGroup in LGroups do
  begin
    LGroup.sort(LCompare);
    if LGroup.Length > LLongest then
    begin
      LLongest := LGroup.Length;
    end;
  end;
  { Give each connected entity type space in the first expansion, even when
    one type has hundreds of hypotheses. Each group stays ranked by evidence. }
  for LIndex := 0 to LLongest - 1 do
  begin
    for LGroup in LGroups do
    begin
      if LIndex < LGroup.Length then
      begin
        Result.push(LGroup[LIndex]);
      end;
    end;
  end;
end;

function TOracleGraphModel.Connections(const AKey: String): TJSArray;
var
  LRows: TJSArray;
  LGroups: array[0..3] of TJSArray;
  LGroup: TJSArray;
  LByNode: TJSObject;
  LConnection: TJSObject;
  LEdge: TJSObject;
  LOther: String;
  LIndex: Integer;
  LLongest: Integer;
begin
  LRows := Neighbors(AKey);
  LByNode := TJSObject.new;
  for LIndex := Low(LGroups) to High(LGroups) do
    LGroups[LIndex] := TJSArray.new;
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LEdge := TJSObject(LRows[LIndex]);
    LOther := Other(LEdge, AKey);
    if not isDefined(LByNode[LOther]) then
    begin
      LConnection := TJSObject.new;
      LConnection['node'] := LOther;
      LConnection['edges'] := TJSArray.new;
      LByNode[LOther] := LConnection;
      LGroups[GraphKindIndex(GraphText(Node(LOther), 'kind'))].push(LConnection);
    end;
    TJSArray(TJSObject(LByNode[LOther])['edges']).push(LEdge);
  end;
  LLongest := 0;
  for LGroup in LGroups do
    if LGroup.Length > LLongest then
      LLongest := LGroup.Length;
  Result := TJSArray.new;
  for LIndex := 0 to LLongest - 1 do
    for LGroup in LGroups do
      if LIndex < LGroup.Length then
        Result.push(LGroup[LIndex]);
end;

function TOracleGraphModel.Revision: String;
begin
  Result := GraphText(FModel, 'revision');
end;

end.
