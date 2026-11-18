{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegraphmodel;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, JS;

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
    function Eligible(AEdge: TJSObject; const ANode: String): Boolean;
  public
    constructor Create(AModel: TJSObject);
    function Node(const AKey: String): TJSObject;
    function Neighbors(const AKey: String): TJSArray;
    function Revision: String;
    property NodeCount: Integer read FNodeCount;
    property EdgeCount: Integer read FEdgeCount;
  end;

function GraphText(AObject: TJSObject; const AKey: String): String;
function GraphRows(AObject: TJSObject; const AKey: String): TJSArray;
function GraphKey(const AKind, AValue: String): String;
function ReferenceFile(const APath: String): String;

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
        LSource := GraphKey('source', LPath);
        AddNode(LSource, 'source', ExtractFileName(LPath), LPath);
        AddEdge(LEdgeKey + '/source', LStudy, LSource, 'reference',
          'Read saved source', '', LClaim, LAssessment);
      end;
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

function TOracleGraphModel.Eligible(AEdge: TJSObject; const ANode: String): Boolean;
var
  LKind: String;
begin
  LKind := GraphText(Node(ANode), 'kind');
  if LKind = 'source' then
  begin
    Exit(GraphText(AEdge, 'kind') = 'reference');
  end;
  Result := GraphText(AEdge, 'from') = ANode;
end;

function EdgeRank(AEdge: TJSObject): Integer;
begin
  if GraphText(AEdge, 'trend') <> '' then
  begin
    Exit(0);
  end;
  if (GraphText(AEdge, 'kind') = 'claim') and
    (GraphText(TJSObject(AEdge['claim']), 'evidence_scope') = 'frozen') then
  begin
    Exit(2);
  end;
  Result := 1;
end;

function TOracleGraphModel.Neighbors(const AKey: String): TJSArray;
var
  LRows: TJSArray;
  LIndex: Integer;
  LEdge: TJSObject;
  LCompare: TJSArrayCompareCallBack;
begin
  Result := TJSArray.new;
  if Node(AKey) = nil then
  begin
    Exit;
  end;
  LRows := TJSArray(FAdjacent[AKey]);
  for LIndex := 0 to LRows.Length - 1 do
  begin
    LEdge := TJSObject(LRows[LIndex]);
    if Eligible(LEdge, AKey) then
    begin
      Result.push(LEdge);
    end;
  end;
  LCompare :=
    function(ALeft, ARight: JSValue): NativeInt
    begin
      Result := EdgeRank(TJSObject(ALeft)) - EdgeRank(TJSObject(ARight));
      if Result = 0 then
      begin
        Result := CompareStr(GraphText(TJSObject(ALeft), 'key'), GraphText(TJSObject(ARight), 'key'));
      end;
    end;
  Result.sort(LCompare);
end;

function TOracleGraphModel.Revision: String;
begin
  Result := GraphText(FModel, 'revision');
end;

end.
