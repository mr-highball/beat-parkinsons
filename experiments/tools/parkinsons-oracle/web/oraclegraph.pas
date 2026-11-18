{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegraph;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, Math, JS, Web, nyx.model, nyx.types, nyx.render.browser,
  nyx.canvas.geometry, nyx.canvas.types, nyx.canvas.scene, nyx.canvas.workspace,
  nyx.canvas.browser, oraclegraphmodel, parkinsonsoracle.selection,
  parkinsonsoracle.graphtouch;

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
    FTouchHandler: TJSEventHandler;
    FTouch: TGraphTouch;
    FTapKey: String;
    FCamera: TNyxCanvasCamera;
    FCompact: Boolean;
    FRecenter: Boolean;
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
    function NodeAt(ATarget: TJSNode): String;
    function PositionOf(const AKey: String): TNyxCanvasPoint;
    function SelectedCenter: TNyxCanvasPoint;
    function OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasTouch(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasHomeKey(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasHome(AEvent: TEventListenerEvent): Boolean;
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
  CCompactWidth = 550;
  CCompactNodeStep = 258;
  CCompactLevelStep = 160;
  CTouchEvents: array[0..4] of String = ('pointerdown', 'pointermove', 'pointerup',
    'pointercancel', 'lostpointercapture');

function Control(AKind: TNyxKind; const AId, AText: String): TNyxNode;
begin
  Result := TNyxNode.Create(AKind, AId).Configure.Text(AText).Done;
end;

{ pas2js's EventTarget declaration omits the capture argument on removal. }
procedure RemoveCapture(AElement: TJSHTMLElement; const AName: String; AHandler: TJSEventHandler);
begin
  asm
    AElement.removeEventListener(AName, AHandler, true);
  end;
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
  FRecenter := True;
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
  LPosition['level'] := ALevel;
  LPosition['row'] := FRows[ALevel];
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
begin
  FSelected := AKey;
  if ExpandedCount = 0 then
  begin
    Expand(CExpandPage);
  end;
  FRecenter := True;
  Render;
end;

procedure TOracleGraphExplorer.Detach;
var
  LName: String;
begin
  if FView <> nil then
  begin
    FCamera := FView.Camera;
    RemoveCapture(FView.Surface, 'click', FCanvasClick);
    RemoveCapture(FView.Surface, 'keydown', @OnCanvasHomeKey);
    for LName in CTouchEvents do
    begin
      RemoveCapture(FView.Surface, LName, FTouchHandler);
    end;
    FCanvasClick := nil;
    FTouchHandler := nil;
    FTouch.Reset;
    FTapKey := '';
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
  FRecenter := True;
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

function TOracleGraphExplorer.NodeAt(ATarget: TJSNode): String;
var
  LTarget: TJSElement;
  LIndex: Integer;
begin
  Result := '';
  if (ATarget = nil) or (ATarget.nodeType <> 1) then
  begin
    Exit;
  end;
  LTarget := TJSElement(ATarget).closest('[data-node^="graph-node-"]');
  if LTarget = nil then
  begin
    Exit;
  end;
  LIndex := StrToIntDef(Copy(LTarget.getAttribute('data-node'), 12, MaxInt), -1);
  if (LIndex >= 0) and (LIndex < FVisible.Length) then
  begin
    Result := String(FVisible[LIndex]);
  end;
end;

function TOracleGraphExplorer.PositionOf(const AKey: String): TNyxCanvasPoint;
var
  LPosition: TJSObject;
  LLevel: Double;
  LRow: Double;
begin
  LPosition := TJSObject(FPositions[AKey]);
  LLevel := Double(LPosition['level']);
  LRow := Double(LPosition['row']);
  if FCompact then
  begin
    Exit(NyxCanvasPoint(LRow * CCompactNodeStep, LLevel * CCompactLevelStep));
  end;
  Result := NyxCanvasPoint(LLevel * CColumnStep, LRow * CRowStep);
end;

function TOracleGraphExplorer.SelectedCenter: TNyxCanvasPoint;
var
  LPoint: TNyxCanvasPoint;
begin
  if FSelected = '' then
  begin
    Exit(NyxCanvasPoint(0, 0));
  end;
  LPoint := PositionOf(FSelected);
  if FCompact then
  begin
    Exit(NyxCanvasPoint(LPoint.X + CNodeWidth / 2, LPoint.Y + CCompactLevelStep / 2 +
      CNodeHeight / 2));
  end;
  Result := NyxCanvasPoint(LPoint.X + 300, LPoint.Y + 100);
end;

function TOracleGraphExplorer.OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
var
  LKey: String;
begin
  LKey := NodeAt(TJSNode(AEvent.target));
  if LKey <> '' then
  begin
    AEvent.stopImmediatePropagation;
    AEvent.preventDefault;
    Select(LKey);
  end;
  Result := True;
end;

function TOracleGraphExplorer.OnCanvasHome(AEvent: TEventListenerEvent): Boolean;
begin
  AEvent.stopImmediatePropagation;
  AEvent.preventDefault;
  FView.SetCamera(FView.Camera.AtCenter(SelectedCenter, 1));
  Result := True;
end;

function TOracleGraphExplorer.OnCanvasHomeKey(AEvent: TEventListenerEvent): Boolean;
var
  LKey: TJSKeyboardEvent;
begin
  LKey := TJSKeyboardEvent(AEvent);
  if (LKey.key = 'Home') and (AEvent.target = FView.Surface) and
    not (LKey.altKey or LKey.ctrlKey or LKey.metaKey or LKey.shiftKey) then
  begin
    Exit(OnCanvasHome(AEvent));
  end;
  Result := True;
end;

function TOracleGraphExplorer.OnCanvasTouch(AEvent: TEventListenerEvent): Boolean;
var
  LPointer: TJSPointerEvent;
  LBounds: TJSDOMRect;
  LSurface: TJSHTMLElement;
  LPoint: TNyxCanvasPoint;
  LCamera: TNyxCanvasCamera;
  LWasEmpty: Boolean;
  LKey: String;
begin
  Result := True;
  LPointer := TJSPointerEvent(AEvent);
  if (LPointer.pointerType <> 'touch') or (FView = nil) then
  begin
    Exit;
  end;
  LSurface := FView.Surface;
  LBounds := LSurface.getBoundingClientRect;
  if (LBounds.width <= 0) or (LBounds.height <= 0) then
  begin
    FTouch.Reset;
    FTapKey := '';
    Exit;
  end;

  { Nyx normally starts gestures only on its background, to preserve native
    input in embedded controls. This workspace contains buttons and drawings,
    so a finger can start on either and a stationary tap still opens the node. }
  AEvent.stopImmediatePropagation;
  AEvent.preventDefault;
  LPoint := NyxCanvasPoint((LPointer.clientX - LBounds.left) * LSurface.clientWidth /
    LBounds.width, (LPointer.clientY - LBounds.top) * LSurface.clientHeight / LBounds.height);
  case LPointer._type of
    'pointerdown':
      begin
        LWasEmpty := FTouch.Count = 0;
        if FTouch.BeginContact(LPointer.pointerId, LPoint, FView.Camera) then
        begin
          if LWasEmpty then
          begin
            FTapKey := NodeAt(TJSNode(AEvent.target));
          end;
          if LPointer.isTrusted then
          begin
            LSurface.setPointerCapture(LPointer.pointerId);
          end;
        end;
      end;
    'pointermove':
      begin
        if FTouch.MoveContact(LPointer.pointerId, LPoint, LCamera) then
        begin
          FView.SetCamera(LCamera);
        end;
      end;
    else
      begin
        LKey := FTapKey;
        FTapKey := '';
        if FTouch.EndContact(LPointer.pointerId, LPoint, FView.Camera,
          LPointer._type <> 'pointerup') and (LKey <> '') then
        begin
          Select(LKey);
        end;
      end;
  end;
end;

procedure TOracleGraphExplorer.Render;
var
  LHost: TJSHTMLElement;
  LCanvasHost: TJSHTMLElement;
  LHome: TJSHTMLElement;
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
  LPosition: TNyxCanvasPoint;
  LStart: TNyxCanvasPoint;
  LEnd: TNyxCanvasPoint;
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
  LDirection: Integer;
  LArrow: TNyxDrawingPath;
  LLabelPoint: TNyxCanvasPoint;
  LPath: TNyxDrawingPath;
  LPaint: TNyxDrawingPaint;
  LClick: TJSEventHandler;
  LName: String;
  LCompact: Boolean;
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
    'Tap a node to explore. Drag to move and pinch inside the graph to zoom. Fit content shows the whole branch.'));
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
  LCanvasHost := FRenderer.ElementFor('graph-canvas');
  LCompact := (LCanvasHost.clientWidth > 0) and (LCanvasHost.clientWidth < CCompactWidth);
  if FRecenter or (FCompact <> LCompact) then
  begin
    FCompact := LCompact;
    FCamera := FCamera.AtCenter(SelectedCenter, 1);
    FRecenter := False;
  end;
  LScene := NewNyxCanvasScene;
  LScene.AddLayer(NyxCanvasLayer('Links'));
  LScene.AddLayer(NyxCanvasLayer('Nodes'));
  LWidth := CNodeWidth;
  LHeight := CNodeHeight;
  for LIndex := 0 to FVisible.Length - 1 do
  begin
    LPosition := PositionOf(String(FVisible[LIndex]));
    LWidth := Max(LWidth, LPosition.X + CNodeWidth);
    LHeight := Max(LHeight, LPosition.Y + CNodeHeight);
  end;
  LDrawing := NewNyxDrawingPlan(NyxCanvasBounds(-20, -20, LWidth + 40, LHeight + 40));
  for LIndex := 0 to FEdges.Length - 1 do
  begin
    LEdge := TJSObject(FEdges[LIndex]);
    LStart := PositionOf(GraphText(LEdge, 'from'));
    LEnd := PositionOf(GraphText(LEdge, 'to'));
    if FCompact then
    begin
      LDirection := 1;
      if LEnd.Y < LStart.Y then
      begin
        LDirection := -1;
      end;
      LX1 := LStart.X + CNodeWidth / 2;
      LY1 := LStart.Y + (1 + LDirection) * CNodeHeight / 2;
      LX2 := LEnd.X + CNodeWidth / 2;
      LY2 := LEnd.Y + (1 - LDirection) * CNodeHeight / 2;
      LMiddle := (LY1 + LY2) / 2;
      LPath := NyxDrawingPath(NyxCanvasPoint(LX1, LY1))
        .CurveTo(NyxCanvasPoint(LX1, LMiddle), NyxCanvasPoint(LX2, LMiddle),
          NyxCanvasPoint(LX2, LY2));
      LArrow := NyxDrawingPath(NyxCanvasPoint(LX2 - 5, LY2 - LDirection * 8))
        .LineTo(NyxCanvasPoint(LX2, LY2)).LineTo(NyxCanvasPoint(LX2 + 5, LY2 - LDirection * 8));
      LLabelPoint := NyxCanvasPoint((LX1 + LX2) / 2 + 12, LMiddle - 5);
    end
    else
    begin
      LDirection := 1;
      if LEnd.X < LStart.X then
      begin
        LDirection := -1;
      end;
      LX1 := LStart.X + (1 + LDirection) * CNodeWidth / 2;
      LY1 := LStart.Y + CNodeHeight / 2;
      LX2 := LEnd.X + (1 - LDirection) * CNodeWidth / 2;
      LY2 := LEnd.Y + CNodeHeight / 2;
      LMiddle := (LX1 + LX2) / 2;
      LPath := NyxDrawingPath(NyxCanvasPoint(LX1, LY1))
        .CurveTo(NyxCanvasPoint(LMiddle, LY1), NyxCanvasPoint(LMiddle, LY2),
          NyxCanvasPoint(LX2, LY2));
      LArrow := NyxDrawingPath(NyxCanvasPoint(LX2 - LDirection * 8, LY2 - 5))
        .LineTo(NyxCanvasPoint(LX2, LY2)).LineTo(NyxCanvasPoint(LX2 - LDirection * 8, LY2 + 5));
      LLabelPoint := NyxCanvasPoint(LMiddle, (LY1 + LY2) / 2 - 8);
    end;
    LPaint := NyxDrawingPaint(LinkColor(GraphText(LEdge, 'trend')));
    LDrawing.Path(LPath, NyxDrawingStyle.Stroke(LPaint, 2.5));
    LDrawing.Path(LArrow, NyxDrawingStyle.Stroke(LPaint, 2.5));
    LDrawing.Text(GraphText(LEdge, 'label'), LLabelPoint, LPaint, 13, ndtaCenter, True);
  end;
  LScene.AddControl(NyxCanvasItem('Connections'),
    NyxCanvasPlacement(NyxCanvasLayer('Links'),
      NyxCanvasBounds(-20, -20, LWidth + 40, LHeight + 40)).Pickable(False),
    NewNyxDrawing('graph-links').WithPlan(LDrawing.Build));
  for LIndex := 0 to FVisible.Length - 1 do
  begin
    LKey := String(FVisible[LIndex]);
    LNode := FModel.Node(LKey);
    LPosition := PositionOf(LKey);
    LLeft := LPosition.X;
    LTop := LPosition.Y;
    LNodeControl := NewNyxButton('graph-node-' + IntToStr(LIndex));
    LNodeControl.Configure.Text(Capitalized(GraphText(LNode, 'kind')) + #10 +
      GraphText(LNode, 'label')).AccessibleName(GraphText(LNode, 'kind') + ': ' +
      GraphText(LNode, 'label') + '. Explore connections.').Variant(nvSecondary).Done;
    LScene.AddControl(NyxCanvasItem('Node ' + IntToStr(LIndex)),
      NyxCanvasPlacement(NyxCanvasLayer('Nodes'),
        NyxCanvasBounds(LLeft, LTop, CNodeWidth, CNodeHeight)), LNodeControl);
  end;
  LWorkspace := NewNyxCanvasWorkspace('research-web', LScene).WithCamera(FCamera)
    .WithGrid(NyxCanvasGrid(20, ncgsNone)).WithScaling(nccsUniform);
  FView := MountNyxBrowserCanvasWorkspace(LWorkspace, FDocument, LCanvasHost);
  FView.Surface.setAttribute('data-oracle-graph-surface', '');
  FView.Surface.style.setProperty('touch-action', 'none');
  FCanvasClick := @OnCanvasClick;
  FView.Surface.addEventListener('click', FCanvasClick, True);
  LClick := @OnCanvasHomeKey;
  FView.Surface.addEventListener('keydown', LClick, True);
  LHome := TJSHTMLElement(LCanvasHost.querySelector('[data-node="' +
    NyxCanvasWorkspacePart('research-web', ncwpHome).ID + '"]'));
  if LHome <> nil then
  begin
    LClick := @OnCanvasHome;
    LHome.addEventListener('click', LClick, True);
  end;
  FTouchHandler := @OnCanvasTouch;
  for LName in CTouchEvents do
  begin
    FView.Surface.addEventListener(LName, FTouchHandler, True);
  end;
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
