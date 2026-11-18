{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegraph;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, Math, JS, Web, nyx.model, nyx.types, nyx.render.browser,
  nyx.canvas.geometry, nyx.canvas.types, nyx.canvas.scene, nyx.canvas.workspace,
  nyx.canvas.browser, oraclegraphmodel, parkinsonsoracle.selection;

type
  { Navigation callbacks borrow the application, never a retired graph renderer. }
  TGraphOpenSource = reference to procedure(const APath: String);
  TGraphOpenClaim = reference to procedure(ARound: Integer; const AId: String);

  { An application-owned graph workspace. Detach revokes native DOM/canvas
    listeners before the host or document retires; the explored web stays in memory. }
  TOracleGraphExplorer = class
  private
    FModel: TOracleGraphModel;
    FVisible: TJSArray;
    FPositions: TJSObject;
    FEdges: TJSArray;
    FEdgeKeys: TJSSet;
    FExpanded: TJSObject;
    FRows: array[0..3] of Integer;
    FSelected: String;
    FHost: TJSHTMLElement;
    FDocument: TNyxDocument;
    FRenderer: TNyxBrowserRenderer;
    FView: INyxBrowserCanvasWorkspaceView;
    FCanvasClick: TJSEventHandler;
    FCamera: TNyxCanvasCamera;
    FOpenSource: TGraphOpenSource;
    FOpenClaim: TGraphOpenClaim;
    procedure AddVisible(const AKey: String; ALevel: Integer);
    procedure Expand(AAmount: Integer);
    procedure Select(const AKey: String);
    procedure FocusBranch;
    procedure Render;
    procedure BindNeighbor(const AId, AKey: String);
    procedure BindEvidence(const AId: String; AEdge: TJSObject; ASource: Boolean);
    function LevelFor(const AKey: String): Integer;
    function Other(AEdge: TJSObject; const AKey: String): String;
    function ExpandedCount: Integer;
    function OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(AModel: TJSObject; const ASymptoms: TStringValues;
      const AIngredient: String; AOpenSource: TGraphOpenSource; AOpenClaim: TGraphOpenClaim);
    destructor Destroy; override;
    procedure Attach(AHost: TJSHTMLElement);
    procedure Detach;
    function Revision: String;
  end;

implementation

uses nyx.controls, nyx.drawing, nyx.colors, oraclevocab;

const
  CExpandPage = 12;
  CNodeWidth = 220;
  CNodeHeight = 80;
  CColumnStep = 490;
  CRowStep = 145;

function Control(AKind: TNyxKind; const AId, AText: String): TNyxNode;
begin
  Result := TNyxNode.Create(AKind, AId).Configure.Text(AText).Done;
end;

function LinkColor(const ATrend: String): TNyxRGBColor;
begin
  if ATrend = 'eases' then
  begin
    Exit(NyxRGB(20, 112, 78));
  end;
  if ATrend = 'worsens' then
  begin
    Exit(NyxRGB(176, 49, 49));
  end;
  Result := NyxRGB(104, 113, 122);
end;

constructor TOracleGraphExplorer.Create(AModel: TJSObject; const ASymptoms: TStringValues;
  const AIngredient: String; AOpenSource: TGraphOpenSource; AOpenClaim: TGraphOpenClaim);
var
  LSymptom: String;
  LKey: String;
begin
  FModel := TOracleGraphModel.Create(AModel);
  FVisible := TJSArray.new;
  FPositions := TJSObject.new;
  FEdges := TJSArray.new;
  FEdgeKeys := TJSSet.new;
  FExpanded := TJSObject.new;
  FOpenSource := AOpenSource;
  FOpenClaim := AOpenClaim;
  FCamera := NyxCanvasCamera(800, 520, NyxCanvasPoint(300, 180));
  for LSymptom in ASymptoms do
  begin
    LKey := GraphKey('symptom', LSymptom);
    if FModel.Node(LKey) <> nil then
    begin
      AddVisible(LKey, 0);
      FSelected := LKey;
      Expand(CExpandPage);
    end;
  end;
  if (FVisible.Length = 0) and (AIngredient <> '') then
  begin
    LKey := GraphKey('ingredient', AIngredient);
    if FModel.Node(LKey) <> nil then
    begin
      AddVisible(LKey, 0);
      FSelected := LKey;
      Expand(CExpandPage);
    end;
  end;
  if FVisible.Length > 0 then
  begin
    FSelected := String(FVisible[0]);
  end;
end;

destructor TOracleGraphExplorer.Destroy;
begin
  Detach;
  FModel.Free;
  inherited Destroy;
end;

function TOracleGraphExplorer.LevelFor(const AKey: String): Integer;
var
  LKind: String;
begin
  LKind := GraphText(FModel.Node(AKey), 'kind');
  if LKind = 'ingredient' then
  begin
    Exit(1);
  end;
  if LKind = 'study' then
  begin
    Exit(2);
  end;
  Result := 3;
end;

procedure TOracleGraphExplorer.AddVisible(const AKey: String; ALevel: Integer);
var
  LPosition: TJSObject;
begin
  if isDefined(FPositions[AKey]) then
  begin
    Exit;
  end;
  LPosition := TJSObject.new;
  LPosition['x'] := ALevel * CColumnStep;
  LPosition['y'] := FRows[ALevel] * CRowStep;
  LPosition['index'] := FVisible.Length;
  Inc(FRows[ALevel]);
  FPositions[AKey] := LPosition;
  FVisible.push(AKey);
end;

function TOracleGraphExplorer.Other(AEdge: TJSObject; const AKey: String): String;
begin
  Result := GraphText(AEdge, 'to');
  if Result = AKey then
  begin
    Result := GraphText(AEdge, 'from');
  end;
end;

function TOracleGraphExplorer.ExpandedCount: Integer;
begin
  Result := StrToIntDef(GraphText(FExpanded, FSelected), 0);
end;

procedure TOracleGraphExplorer.Expand(AAmount: Integer);
var
  LNeighbors: TJSArray;
  LIndex: Integer;
  LEnd: Integer;
  LEdge: TJSObject;
  LKey: String;
begin
  LNeighbors := FModel.Neighbors(FSelected);
  LEnd := Min(ExpandedCount + AAmount, LNeighbors.Length);
  for LIndex := ExpandedCount to LEnd - 1 do
  begin
    LEdge := TJSObject(LNeighbors[LIndex]);
    LKey := Other(LEdge, FSelected);
    AddVisible(LKey, LevelFor(LKey));
    if not FEdgeKeys.has(GraphText(LEdge, 'key')) then
    begin
      FEdgeKeys.add(GraphText(LEdge, 'key'));
      FEdges.push(LEdge);
    end;
  end;
  FExpanded[FSelected] := LEnd;
end;

procedure TOracleGraphExplorer.Select(const AKey: String);
var
  LPosition: TJSObject;
begin
  FSelected := AKey;
  if ExpandedCount = 0 then
  begin
    Expand(CExpandPage);
  end;
  if FView <> nil then
  begin
    FCamera := FView.Camera;
  end;
  LPosition := TJSObject(FPositions[AKey]);
  FCamera := FCamera.AtCenter(NyxCanvasPoint(Double(LPosition['x']) + 300,
    Double(LPosition['y']) + 100));
  if FView <> nil then
  begin
    FView.SetCamera(FCamera);
  end;
  Render;
end;

procedure TOracleGraphExplorer.Detach;
begin
  if FView <> nil then
  begin
    FCamera := FView.Camera;
    FView.Surface.removeEventListener('click', FCanvasClick);
    FCanvasClick := nil;
    FView.Disconnect;
    FView := nil;
  end;
  FreeAndNil(FRenderer);
  FreeAndNil(FDocument);
  FHost := nil;
end;

procedure TOracleGraphExplorer.FocusBranch;
var
  LIndex: Integer;
  LLevel: Integer;
begin
  FVisible := TJSArray.new;
  FPositions := TJSObject.new;
  FEdges := TJSArray.new;
  FEdgeKeys := TJSSet.new;
  FExpanded := TJSObject.new;
  for LIndex := 0 to High(FRows) do
  begin
    FRows[LIndex] := 0;
  end;
  LLevel := LevelFor(FSelected);
  if GraphText(FModel.Node(FSelected), 'kind') = 'symptom' then
  begin
    LLevel := 0;
  end;
  AddVisible(FSelected, LLevel);
  Expand(CExpandPage);
  if FView <> nil then
  begin
    FCamera := FView.Camera.AtCenter(NyxCanvasPoint(LLevel * CColumnStep + 300, 180), 1);
    FView.SetCamera(FCamera);
  end;
  Render;
end;

procedure TOracleGraphExplorer.Attach(AHost: TJSHTMLElement);
begin
  Detach;
  FHost := AHost;
  Render;
end;

procedure TOracleGraphExplorer.BindNeighbor(const AId, AKey: String);
var
  LClick: TJSEventHandler;
begin
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Select(AKey);
      Result := True;
    end;
  FRenderer.ElementFor(AId).addEventListener('click', LClick);
end;

procedure TOracleGraphExplorer.BindEvidence(const AId: String; AEdge: TJSObject; ASource: Boolean);
var
  LClick: TJSEventHandler;
begin
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LClaim: TJSObject;
    begin
      LClaim := TJSObject(AEdge['claim']);
      if ASource then
      begin
        FOpenSource(GraphText(TJSObject(AEdge['assessment']), 'local_reference'));
      end
      else
      begin
        FOpenClaim(StrToIntDef(GraphText(LClaim, 'round'), 0), GraphText(LClaim, 'claim_id'));
      end;
      Result := True;
    end;
  FRenderer.ElementFor(AId).addEventListener('click', LClick);
end;

function TOracleGraphExplorer.OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
var
  LTarget: TJSElement;
  LIndex: Integer;
begin
  Result := True;
  LTarget := TJSElement(AEvent.target).closest('[data-node^="graph-node-"]');
  if LTarget = nil then
  begin
    Exit;
  end;
  LIndex := StrToIntDef(Copy(LTarget.getAttribute('data-node'), 12, MaxInt), -1);
  if (LIndex >= 0) and (LIndex < FVisible.Length) then
  begin
    Select(String(FVisible[LIndex]));
  end;
end;

procedure TOracleGraphExplorer.Render;
var
  LHost: TJSHTMLElement;
  LPage: TNyxNode;
  LInspector: TNyxNode;
  LCard: TNyxNode;
  LScene: INyxCanvasScene;
  LWorkspace: INyxCanvasWorkspace;
  LDrawing: INyxDrawingBuilder;
  LNodeControl: INyxButton;
  LIndex: Integer;
  LKey: String;
  LOther: String;
  LNode: TJSObject;
  LPosition: TJSObject;
  LStart: TJSObject;
  LEnd: TJSObject;
  LEdge: TJSObject;
  LClaim: TJSObject;
  LAssessment: TJSObject;
  LNeighbors: TJSArray;
  LLeft: Double;
  LTop: Double;
  LWidth: Double;
  LHeight: Double;
  LX1: Double;
  LY1: Double;
  LX2: Double;
  LY2: Double;
  LMiddle: Double;
  LPath: TNyxDrawingPath;
  LPaint: TNyxDrawingPaint;
  LClick: TJSEventHandler;
begin
  if FHost = nil then
  begin
    Exit;
  end;
  LHost := FHost;
  Detach;
  FHost := LHost;
  FDocument := TNyxDocument.Create;
  FRenderer := TNyxBrowserRenderer.Create;
  LPage := Control(nkPage, 'graph-workspace', '');
  FDocument.AddPage(LPage);
  LPage.Add(Control(nkLabel, 'graph-guide',
    'Tap a node or a connection below to explore. Drag the background to pan; use zoom or Fit for an overview.'));
  LPage.Add(Control(nkLabel, 'graph-legend',
    'Green: may ease · Red: may worsen · Gray: open, related or inconclusive. Study support remains hypothesis evidence, not proven treatment.'));
  LPage.Add(Control(nkLabel, 'graph-snapshot', 'Model snapshot ' + Copy(Revision, 1, 12)));
  LPage.Add(Control(nkPanel, 'graph-canvas', 'Research relationships'));
  LInspector := Control(nkColumn, 'graph-inspector', '');
  LPage.Add(LInspector);
  LNode := FModel.Node(FSelected);
  LInspector.Add(Control(nkHeading, 'graph-selection', GraphText(LNode, 'label')));
  LInspector.Add(Control(nkLabel, 'graph-selection-kind', Capitalized(GraphText(LNode, 'kind'))));
  LInspector.Add(Control(nkButton, 'graph-focus-branch', 'Focus this branch'));
  if GraphText(LNode, 'kind') = 'source' then
  begin
    LInspector.Add(Control(nkButton, 'graph-open-selected-source', 'Read saved source'));
  end;
  LNeighbors := FModel.Neighbors(FSelected);
  LInspector.Add(Control(nkLabel, 'graph-connection-count', IntToStr(ExpandedCount) + ' of ' +
    IntToStr(LNeighbors.Length) + ' recorded connections shown. All open hypotheses remain available.'));
  if ExpandedCount < LNeighbors.Length then
  begin
    LInspector.Add(Control(nkButton, 'graph-expand', 'Show next connections'));
  end;
  for LIndex := 0 to ExpandedCount - 1 do
  begin
    LEdge := TJSObject(LNeighbors[LIndex]);
    LOther := Other(LEdge, FSelected);
    LClaim := TJSObject(LEdge['claim']);
    LAssessment := TJSObject(LEdge['assessment']);
    LCard := Control(nkCard, 'graph-connection-' + IntToStr(LIndex), '');
    LCard.Add(Control(nkButton, 'graph-neighbor-' + IntToStr(LIndex),
      GraphText(FModel.Node(LOther), 'label')));
    LCard.Add(Control(nkLabel, 'graph-relation-' + IntToStr(LIndex), GraphText(LEdge, 'label')));
    LCard.Add(Control(nkLabel, 'graph-context-' + IntToStr(LIndex),
      FriendlySymptom(GraphText(LClaim, 'symptom')) + ' · ' + GraphText(LClaim, 'preparation') +
      ' ' + GraphText(LClaim, 'ingredient')));
    if LAssessment <> nil then
    begin
      LCard.Add(Control(nkLabel, 'graph-fit-' + IntToStr(LIndex), GraphText(LAssessment, 'fit')));
      LCard.Add(Control(nkLabel, 'graph-analysis-' + IntToStr(LIndex),
        GraphText(LAssessment, 'assessment')));
      if GraphText(LAssessment, 'local_reference') <> '' then
      begin
        LCard.Add(Control(nkButton, 'graph-read-' + IntToStr(LIndex), 'Read source'));
      end;
    end;
    LCard.Add(Control(nkButton, 'graph-claim-' + IntToStr(LIndex), 'Open claim and evidence'));
    LInspector.Add(LCard);
  end;
  FRenderer.Render(FDocument, LPage, FHost);
  LScene := NewNyxCanvasScene;
  LScene.AddLayer(NyxCanvasLayer('Links'));
  LScene.AddLayer(NyxCanvasLayer('Nodes'));
  LWidth := CNodeWidth;
  LHeight := CNodeHeight;
  for LIndex := 0 to FVisible.Length - 1 do
  begin
    LPosition := TJSObject(FPositions[String(FVisible[LIndex])]);
    LWidth := Max(LWidth, Double(LPosition['x']) + CNodeWidth);
    LHeight := Max(LHeight, Double(LPosition['y']) + CNodeHeight);
  end;
  LDrawing := NewNyxDrawingPlan(NyxCanvasBounds(-20, -20, LWidth + 40, LHeight + 40));
  for LIndex := 0 to FEdges.Length - 1 do
  begin
    LEdge := TJSObject(FEdges[LIndex]);
    LStart := TJSObject(FPositions[GraphText(LEdge, 'from')]);
    LEnd := TJSObject(FPositions[GraphText(LEdge, 'to')]);
    LX1 := Double(LStart['x']) + CNodeWidth;
    LY1 := Double(LStart['y']) + CNodeHeight / 2;
    LX2 := Double(LEnd['x']);
    LY2 := Double(LEnd['y']) + CNodeHeight / 2;
    LMiddle := (LX1 + LX2) / 2;
    LPath := NyxDrawingPath(NyxCanvasPoint(LX1, LY1))
      .CurveTo(NyxCanvasPoint(LMiddle, LY1), NyxCanvasPoint(LMiddle, LY2),
        NyxCanvasPoint(LX2, LY2));
    LPaint := NyxDrawingPaint(LinkColor(GraphText(LEdge, 'trend')));
    LDrawing.Path(LPath, NyxDrawingStyle.Stroke(LPaint, 2.5));
    LDrawing.Path(NyxDrawingPath(NyxCanvasPoint(LX2 - 8, LY2 - 5))
      .LineTo(NyxCanvasPoint(LX2, LY2)).LineTo(NyxCanvasPoint(LX2 - 8, LY2 + 5)),
      NyxDrawingStyle.Stroke(LPaint, 2.5));
    LDrawing.Text(GraphText(LEdge, 'label'),
      NyxCanvasPoint(LMiddle, (LY1 + LY2) / 2 - 8), LPaint, 13, ndtaCenter, True);
  end;
  LScene.AddControl(NyxCanvasItem('Connections'),
    NyxCanvasPlacement(NyxCanvasLayer('Links'),
      NyxCanvasBounds(-20, -20, LWidth + 40, LHeight + 40)).Pickable(False),
    NewNyxDrawing('graph-links').WithPlan(LDrawing.Build));
  for LIndex := 0 to FVisible.Length - 1 do
  begin
    LKey := String(FVisible[LIndex]);
    LNode := FModel.Node(LKey);
    LPosition := TJSObject(FPositions[LKey]);
    LLeft := Double(LPosition['x']);
    LTop := Double(LPosition['y']);
    LNodeControl := NewNyxButton('graph-node-' + IntToStr(LIndex));
    LNodeControl.Configure.Text(Capitalized(GraphText(LNode, 'kind')) + #10 +
      GraphText(LNode, 'label')).AccessibleName(GraphText(LNode, 'kind') + ': ' +
      GraphText(LNode, 'label') + '. Explore connections.').Variant(nvSecondary).Done;
    LScene.AddControl(NyxCanvasItem('Node ' + IntToStr(LIndex)),
      NyxCanvasPlacement(NyxCanvasLayer('Nodes'),
        NyxCanvasBounds(LLeft, LTop, CNodeWidth, CNodeHeight)), LNodeControl);
  end;
  LWorkspace := NewNyxCanvasWorkspace('research-web', LScene).WithCamera(FCamera)
    .WithScaling(nccsUniform);
  FView := MountNyxBrowserCanvasWorkspace(LWorkspace, FDocument,
    FRenderer.ElementFor('graph-canvas'));
  FCanvasClick := @OnCanvasClick;
  FView.Surface.addEventListener('click', FCanvasClick);
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      FocusBranch;
      Result := True;
    end;
  FRenderer.ElementFor('graph-focus-branch').addEventListener('click', LClick);
  if ExpandedCount < LNeighbors.Length then
  begin
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Expand(CExpandPage);
        Render;
        Result := True;
      end;
    FRenderer.ElementFor('graph-expand').addEventListener('click', LClick);
  end;
  if GraphText(FModel.Node(FSelected), 'kind') = 'source' then
  begin
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        FOpenSource(GraphText(FModel.Node(FSelected), 'value'));
        Result := True;
      end;
    FRenderer.ElementFor('graph-open-selected-source').addEventListener('click', LClick);
  end;
  for LIndex := 0 to ExpandedCount - 1 do
  begin
    LEdge := TJSObject(LNeighbors[LIndex]);
    FRenderer.ElementFor('graph-connection-' + IntToStr(LIndex)).setAttribute('data-trend',
      GraphText(LEdge, 'trend'));
    BindNeighbor('graph-neighbor-' + IntToStr(LIndex), Other(LEdge, FSelected));
    BindEvidence('graph-claim-' + IntToStr(LIndex), LEdge, False);
    if (LEdge['assessment'] <> nil) and
      (GraphText(TJSObject(LEdge['assessment']), 'local_reference') <> '') then
    begin
      BindEvidence('graph-read-' + IntToStr(LIndex), LEdge, True);
    end;
  end;
end;

function TOracleGraphExplorer.Revision: String;
begin
  Result := FModel.Revision;
end;

end.
