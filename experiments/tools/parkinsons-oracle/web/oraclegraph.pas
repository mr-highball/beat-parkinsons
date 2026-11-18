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

  TGraphLinkBadge = record
    Position: TNyxCanvasPoint;
    Text: String;
    Tone: String;
  end;

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
    FLanes: array[0..3] of TJSSet;
    FSelected: String;
    FHistory: TStringValues;
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
    procedure AddConnection(AEdge: TJSObject);
    procedure ResetBranch;
    procedure Expand(AAmount: Integer);
    procedure Select(const AKey: String);
    procedure NavigateBack;
    procedure FocusBranch;
    procedure Render;
    procedure BindNeighbor(const AId, AKey: String);
    procedure BindEvidence(const AId: String; AEdge: TJSObject; ASource: Boolean);
    function LevelFor(const AKey: String): Integer;
    function ExpandedCount: Integer;
    function NodeAt(ATarget: TJSNode): String;
    function PositionOf(const AKey: String): TNyxCanvasPoint;
    function SelectedCenter: TNyxCanvasPoint;
    function OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasTouch(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasHomeKey(AEvent: TEventListenerEvent): Boolean;
    function OnCanvasHome(AEvent: TEventListenerEvent): Boolean;
  public
    constructor Create(AModel: TOracleGraphModel; const ASymptoms: TStringValues;
      const AIngredient: String; AOpenSource: TGraphOpenSource; AOpenClaim: TGraphOpenClaim;
      const AStartNode: String = '');
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
  CColumnStep = 340;
  CRowStep = 145;
  CCompactWidth = 550;
  CCompactNodeStep = 258;
  CCompactLevelStep = 128;
  CDrawingMargin = 84;
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

function IsTouchClick(AEvent: TEventListenerEvent): Boolean;
begin
  asm
    return AEvent.pointerType === 'touch' ||
      AEvent.sourceCapabilities?.firesTouchEvents === true;
  end;
end;

function LinkColor(const ATone: String; AFocused: Boolean): TNyxRGBColor;
begin
  if ATone = 'eases' then
  begin
    Exit(NyxRGB(20, 112, 78));
  end;
  if ATone = 'worsens' then
  begin
    Exit(NyxRGB(176, 49, 49));
  end;
  if ATone = 'challenged' then
    Exit(NyxRGB(137, 86, 20));
  if ATone = 'mixed' then
    Exit(NyxRGB(97, 69, 135));
  if AFocused then
    Exit(NyxRGB(142, 159, 151));
  Result := NyxRGB(185, 199, 191);
end;

function LinkBadge(const ATone: String): String;
begin
  if ATone = 'eases' then
    Exit('↓ May ease');
  if ATone = 'worsens' then
    Exit('↑ May worsen');
  if ATone = 'mixed' then
    Exit('Multiple evidence signals');
  Result := '? Claim challenged';
end;

function LinkBadgeFill(const ATone: String): TNyxDrawingPaint;
begin
  if ATone = 'eases' then
    Exit(NyxDrawingPaint(NyxRGB(231, 247, 237)));
  if ATone = 'worsens' then
    Exit(NyxDrawingPaint(NyxRGB(255, 237, 233)));
  if ATone = 'mixed' then
    Exit(NyxDrawingPaint(NyxRGB(244, 237, 252)));
  Result := NyxDrawingPaint(NyxRGB(255, 245, 221));
end;

constructor TOracleGraphExplorer.Create(AModel: TOracleGraphModel; const ASymptoms: TStringValues;
  const AIngredient: String; AOpenSource: TGraphOpenSource; AOpenClaim: TGraphOpenClaim;
  const AStartNode: String);
var
  LSymptom: String;
  LKey: String;
  LStart: String;
  LNeighbors: TJSArray;
  LIndex: Integer;
  LEdge: TJSObject;
begin
  FModel := AModel;
  ResetBranch;
  FOpenSource := AOpenSource;
  FOpenClaim := AOpenClaim;
  FCamera := NyxCanvasCamera(800, 520, NyxCanvasPoint(300, 180));
  FRecenter := True;
  if AStartNode <> '' then
  begin
    if FModel.Node(AStartNode) <> nil then
    begin
      AddVisible(AStartNode, LevelFor(AStartNode));
      FSelected := AStartNode;
      Expand(CExpandPage);
    end;
    Exit;
  end;
  for LSymptom in ASymptoms do
  begin
    LKey := GraphKey('symptom', LSymptom);
    if FModel.Node(LKey) <> nil then
      AddVisible(LKey, 0);
  end;
  LStart := '';
  if FVisible.Length > 0 then
    LStart := String(FVisible[0]);
  if AIngredient <> '' then
  begin
    LKey := GraphKey('ingredient', AIngredient);
    if FModel.Node(LKey) <> nil then
    begin
      AddVisible(LKey, 1);
      LNeighbors := FModel.Neighbors(LKey);
      for LIndex := 0 to LNeighbors.Length - 1 do
      begin
        LEdge := TJSObject(LNeighbors[LIndex]);
        if isDefined(FPositions[FModel.Other(LEdge, LKey)]) then
          AddConnection(LEdge);
      end;
      LStart := LKey;
    end;
  end;
  for LSymptom in ASymptoms do
  begin
    LKey := GraphKey('symptom', LSymptom);
    if FModel.Node(LKey) <> nil then
    begin
      FSelected := LKey;
      Expand(CExpandPage);
    end;
  end;
  FSelected := LStart;
  if (FSelected <> '') and (ExpandedCount = 0) then
    Expand(CExpandPage);
end;

destructor TOracleGraphExplorer.Destroy;
begin
  Detach;
  inherited Destroy;
end;

function TOracleGraphExplorer.LevelFor(const AKey: String): Integer;
begin
  Result := GraphKindIndex(GraphText(FModel.Node(AKey), 'kind'));
end;

procedure TOracleGraphExplorer.AddVisible(const AKey: String; ALevel: Integer);
var
  LPosition: TJSObject;
  LLane: Integer;
begin
  if isDefined(FPositions[AKey]) then
  begin
    Exit;
  end;
  LPosition := TJSObject.new;
  LPosition['level'] := ALevel;
  LLane := 0;
  if (FSelected <> '') and isDefined(FPositions[FSelected]) then
    LLane := Integer(TJSObject(FPositions[FSelected])['row']);
  while FLanes[ALevel].has(LLane) do
    Inc(LLane);
  FLanes[ALevel].add(LLane);
  LPosition['row'] := LLane;
  FPositions[AKey] := LPosition;
  FVisible.push(AKey);
end;

procedure TOracleGraphExplorer.AddConnection(AEdge: TJSObject);
var
  LKey: String;
begin
  LKey := GraphText(AEdge, 'key');
  if not FEdgeKeys.has(LKey) then
  begin
    FEdgeKeys.add(LKey);
    FEdges.push(AEdge);
  end;
end;

function TOracleGraphExplorer.ExpandedCount: Integer;
begin
  Result := StrToIntDef(GraphText(FExpanded, FSelected), 0);
end;

procedure TOracleGraphExplorer.Expand(AAmount: Integer);
var
  LNeighbors: TJSArray;
  LLinks: TJSArray;
  LNeighbor: TJSObject;
  LIndex: Integer;
  LLink: Integer;
  LEnd: Integer;
  LKey: String;
begin
  LNeighbors := FModel.Connections(FSelected);
  LEnd := Min(ExpandedCount + AAmount, LNeighbors.Length);
  for LIndex := ExpandedCount to LEnd - 1 do
  begin
    LNeighbor := TJSObject(LNeighbors[LIndex]);
    LKey := GraphText(LNeighbor, 'node');
    AddVisible(LKey, LevelFor(LKey));
    LLinks := GraphRows(LNeighbor, 'edges');
    for LLink := 0 to LLinks.Length - 1 do
      AddConnection(TJSObject(LLinks[LLink]));
  end;
  FExpanded[FSelected] := LEnd;
end;

procedure TOracleGraphExplorer.Select(const AKey: String);
begin
  if FSelected = AKey then
    Exit;
  SetLength(FHistory, Length(FHistory) + 1);
  FHistory[High(FHistory)] := FSelected;
  FSelected := AKey;
  if ExpandedCount = 0 then
  begin
    Expand(CExpandPage);
  end;
  FRecenter := True;
  Render;
end;

procedure TOracleGraphExplorer.NavigateBack;
begin
  FSelected := FHistory[High(FHistory)];
  SetLength(FHistory, Length(FHistory) - 1);
  AddVisible(FSelected, LevelFor(FSelected));
  if ExpandedCount = 0 then
    Expand(CExpandPage);
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

procedure TOracleGraphExplorer.ResetBranch;
var
  LIndex: Integer;
begin
  FVisible := TJSArray.new;
  FPositions := TJSObject.new;
  FEdges := TJSArray.new;
  FEdgeKeys := TJSSet.new;
  FExpanded := TJSObject.new;
  for LIndex := Low(FLanes) to High(FLanes) do
  begin
    FLanes[LIndex] := TJSSet.new;
  end;
end;

procedure TOracleGraphExplorer.FocusBranch;
begin
  ResetBranch;
  AddVisible(FSelected, LevelFor(FSelected));
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
  LOffset: Double;
  LLevel: Integer;
begin
  if FSelected = '' then
  begin
    Exit(NyxCanvasPoint(0, 0));
  end;
  LPoint := PositionOf(FSelected);
  LLevel := LevelFor(FSelected);
  LOffset := 0;
  if LLevel = Low(GraphKinds) then
    LOffset := 0.5
  else if LLevel = High(GraphKinds) then
    LOffset := -0.5;
  if FCompact then
  begin
    Exit(NyxCanvasPoint(LPoint.X + CNodeWidth / 2,
      LPoint.Y + CNodeHeight / 2 + LOffset * CCompactLevelStep));
  end;
  Result := NyxCanvasPoint(LPoint.X + CNodeWidth / 2 + LOffset * CColumnStep,
    LPoint.Y + CNodeHeight / 2);
end;

function TOracleGraphExplorer.OnCanvasClick(AEvent: TEventListenerEvent): Boolean;
var
  LKey: String;
begin
  { Pointer-up already handles taps. The subsequent compatibility click can
    hit a different node at the same screen coordinates after the redraw. }
  if IsTouchClick(AEvent) then
  begin
    AEvent.stopImmediatePropagation;
    AEvent.preventDefault;
    Exit(True);
  end;
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
  LLegend: TNyxNode;
  LGroups: array[0..3] of TNyxNode;
  LGroupMembers: array[0..3] of Integer;
  LGroupShown: array[0..3] of Integer;
  LGroupIndex: Integer;
  LNeighbor: TJSObject;
  LLinks: TJSArray;
  LVisibleLinks: TJSArray;
  LLink: Integer;
  LTag: String;
  LPart: TNyxNode;
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
  LGutter: Double;
  LStroke: Double;
  LDirection: Integer;
  LArrow: TNyxDrawingPath;
  LLabelPoint: TNyxCanvasPoint;
  LRoutesByPair: TJSObject;
  LRoutes: TJSArray;
  LRoute: TJSObject;
  LRouteTone: String;
  LBadges: array of TGraphLinkBadge;
  LBadgeCount: Integer;
  LBadgeWidth: Integer;
  LBadgeKey: String;
  LPath: TNyxDrawingPath;
  LPaint: TNyxDrawingPaint;
  LFocused: Boolean;
  LFrom: String;
  LTo: String;
  LTone: String;
  LClick: TJSEventHandler;
  LName: String;
  LCompact: Boolean;
  LVariant: TNyxVariant;
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
    'Tap a node to follow its connections. Drag to move or pinch to zoom.'));
  LLegend := Control(nkRow, 'graph-legend', '');
  LLegend.Add(Control(nkBadge, 'effect-relief-graph-key', 'May ease'));
  LLegend.Add(Control(nkBadge, 'effect-worse-graph-key', 'May worsen'));
  LLegend.Add(Control(nkBadge, 'effect-challenged-graph-key', 'Claim challenged'));
  LLegend.Add(Control(nkBadge, 'grade-unclear-graph-key', 'Open or related'));
  LLegend.Add(Control(nkBadge, 'graph-mixed-key', 'Multiple signals'));
  LPage.Add(LLegend);
  if FSelected = '' then
  begin
    LPage.Add(Control(nkLabel, 'graph-empty',
      'This source is in the catalog. The graph has no recorded claim or study connection for it yet.'));
    FRenderer.Render(FDocument, LPage, FHost);
    Exit;
  end;
  if Length(FHistory) > 0 then
    LPage.Add(Control(nkButton, 'graph-back-node', '‹ ' +
      GraphText(FModel.Node(FHistory[High(FHistory)]), 'label')));
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
  LNeighbors := FModel.Connections(FSelected);
  LInspector.Add(Control(nkLabel, 'graph-connection-count', IntToStr(ExpandedCount) + ' of ' +
    IntToStr(LNeighbors.Length) + ' connected items shown'));
  if ExpandedCount < LNeighbors.Length then
    LInspector.Add(Control(nkButton, 'graph-expand', 'Show next connections'));
  for LIndex := 0 to LNeighbors.Length - 1 do
  begin
    LOther := GraphText(TJSObject(LNeighbors[LIndex]), 'node');
    LGroupIndex := LevelFor(LOther);
    Inc(LGroupMembers[LGroupIndex]);
    if LIndex < ExpandedCount then
      Inc(LGroupShown[LGroupIndex]);
  end;
  for LGroupIndex := Low(LGroups) to High(LGroups) do
  begin
    if LGroupShown[LGroupIndex] = 0 then
      Continue;
    LGroups[LGroupIndex] := Control(nkColumn, 'graph-group-' + GraphKinds[LGroupIndex], '');
    LGroups[LGroupIndex].Add(Control(nkHeading, 'graph-group-heading-' + GraphKinds[LGroupIndex],
      GraphGroupNames[LGroupIndex] + ' · ' + IntToStr(LGroupShown[LGroupIndex]) + ' of ' +
      IntToStr(LGroupMembers[LGroupIndex])));
    LInspector.Add(LGroups[LGroupIndex]);
  end;
  LVisibleLinks := TJSArray.new;
  for LIndex := 0 to ExpandedCount - 1 do
  begin
    LNeighbor := TJSObject(LNeighbors[LIndex]);
    LOther := GraphText(LNeighbor, 'node');
    LLinks := GraphRows(LNeighbor, 'edges');
    LCard := Control(nkCard, 'graph-connection-' + IntToStr(LIndex), '');
    LCard.Add(Control(nkButton, 'graph-neighbor-' + IntToStr(LIndex),
      GraphText(FModel.Node(LOther), 'label')));
    if LLinks.Length > 1 then
      LCard.Add(Control(nkLabel, 'graph-link-count-' + IntToStr(LIndex),
        IntToStr(LLinks.Length) + ' recorded relationships'));
    for LLink := 0 to LLinks.Length - 1 do
    begin
      LEdge := TJSObject(LLinks[LLink]);
      LTag := IntToStr(LVisibleLinks.Length);
      LVisibleLinks.push(LEdge);
      LClaim := TJSObject(LEdge['claim']);
      LAssessment := TJSObject(LEdge['assessment']);
      LPart := Control(nkColumn, 'graph-relationship-' + LTag, '');
      LPart.Add(Control(nkBadge, 'graph-relation-' + LTag, GraphText(LEdge, 'label')));
      LPart.Add(Control(nkLabel, 'graph-context-' + LTag,
        FriendlySymptom(GraphText(LClaim, 'symptom')) + ' · ' + GraphText(LClaim, 'preparation') +
        ' ' + GraphText(LClaim, 'ingredient')));
      if LAssessment <> nil then
      begin
        LPart.Add(Control(nkLabel, 'graph-fit-' + LTag, GraphText(LAssessment, 'fit')));
        LPart.Add(Control(nkLabel, 'graph-analysis-' + LTag, GraphText(LAssessment, 'assessment')));
        if GraphText(LAssessment, 'local_reference') <> '' then
          LPart.Add(Control(nkButton, 'graph-read-' + LTag, 'Read source'));
      end;
      LPart.Add(Control(nkButton, 'graph-claim-' + LTag, 'Open claim and evidence'));
      LCard.Add(LPart);
    end;
    LGroups[LevelFor(LOther)].Add(LCard);
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
  LDrawing := NewNyxDrawingPlan(NyxCanvasBounds(-CDrawingMargin, -CDrawingMargin,
    LWidth + 2 * CDrawingMargin, LHeight + 2 * CDrawingMargin));
  { Several assessments can share endpoints. Draw one route so a neutral line
    cannot cover a directional one, and keep every assessment in the inspector. }
  LRoutesByPair := TJSObject.new;
  LRoutes := TJSArray.new;
  for LIndex := 0 to FEdges.Length - 1 do
  begin
    LEdge := TJSObject(FEdges[LIndex]);
    LBadgeKey := GraphText(LEdge, 'from') + '|' + GraphText(LEdge, 'to');
    LTone := GraphEdgeTone(LEdge);
    if not isDefined(LRoutesByPair[LBadgeKey]) then
    begin
      LRoute := TJSObject.new;
      LRoute['edge'] := LEdge;
      LRoute['tone'] := LTone;
      LRoutesByPair[LBadgeKey] := LRoute;
      LRoutes.push(LRoute);
      Continue;
    end;
    LRoute := TJSObject(LRoutesByPair[LBadgeKey]);
    LRouteTone := GraphText(LRoute, 'tone');
    if (LTone <> '') and (LRouteTone = '') then
    begin
      LRoute['edge'] := LEdge;
      LRoute['tone'] := LTone;
    end
    else if (LTone <> '') and (LTone <> LRouteTone) then
      LRoute['tone'] := 'mixed';
  end;
  SetLength(LBadges, LRoutes.Length);
  LBadgeCount := 0;
  for LIndex := 0 to LRoutes.Length - 1 do
  begin
    LRoute := TJSObject(LRoutes[LIndex]);
    LEdge := TJSObject(LRoute['edge']);
    LTone := GraphText(LRoute, 'tone');
    LFrom := GraphText(LEdge, 'from');
    LTo := GraphText(LEdge, 'to');
    LStart := PositionOf(LFrom);
    LEnd := PositionOf(LTo);
    LFocused := (LFrom = FSelected) or (LTo = FSelected);
    if FCompact and (LStart.X = LEnd.X) and
      (Abs(LStart.Y - LEnd.Y) > CCompactLevelStep) then
    begin
      { Route past the side of any intervening card in this lane. A line
        through the card would make it appear to be part of the relationship. }
      LX1 := LStart.X + CNodeWidth;
      LX2 := LX1;
      LY1 := LStart.Y + CNodeHeight / 2;
      LY2 := LEnd.Y + CNodeHeight / 2;
      LDirection := Sign(LY2 - LY1);
      LGutter := LX1 + 20;
      LPath := NyxDrawingPath(NyxCanvasPoint(LX1, LY1))
        .CurveTo(NyxCanvasPoint(LX1 + 12, LY1), NyxCanvasPoint(LGutter, LY1 + 12 * LDirection),
          NyxCanvasPoint(LGutter, LY1 + 24 * LDirection))
        .LineTo(NyxCanvasPoint(LGutter, LY2 - 24 * LDirection))
        .CurveTo(NyxCanvasPoint(LGutter, LY2 - 12 * LDirection), NyxCanvasPoint(LX2 + 12, LY2),
          NyxCanvasPoint(LX2, LY2));
      LArrow := NyxDrawingPath(NyxCanvasPoint(LX2 + 8, LY2 - 5))
        .LineTo(NyxCanvasPoint(LX2, LY2)).LineTo(NyxCanvasPoint(LX2 + 8, LY2 + 5));
      LLabelPoint := NyxCanvasPoint(LGutter, (LY1 + LY2) / 2);
    end
    else if (not FCompact) and (LStart.Y = LEnd.Y) and
      (Abs(LStart.X - LEnd.X) > CColumnStep) then
    begin
      LX1 := LStart.X + CNodeWidth / 2;
      LX2 := LEnd.X + CNodeWidth / 2;
      LY1 := LStart.Y + CNodeHeight;
      LY2 := LY1;
      LDirection := Sign(LX2 - LX1);
      LGutter := LY1 + 20;
      LPath := NyxDrawingPath(NyxCanvasPoint(LX1, LY1))
        .CurveTo(NyxCanvasPoint(LX1, LY1 + 12), NyxCanvasPoint(LX1 + 12 * LDirection, LGutter),
          NyxCanvasPoint(LX1 + 24 * LDirection, LGutter))
        .LineTo(NyxCanvasPoint(LX2 - 24 * LDirection, LGutter))
        .CurveTo(NyxCanvasPoint(LX2 - 12 * LDirection, LGutter), NyxCanvasPoint(LX2, LY2 + 12),
          NyxCanvasPoint(LX2, LY2));
      LArrow := NyxDrawingPath(NyxCanvasPoint(LX2 - 5, LY2 + 8))
        .LineTo(NyxCanvasPoint(LX2, LY2)).LineTo(NyxCanvasPoint(LX2 + 5, LY2 + 8));
      LLabelPoint := NyxCanvasPoint((LX1 + LX2) / 2, LGutter);
    end
    else if FCompact then
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
      if LTo = FSelected then
        LLabelPoint := NyxCanvasPoint(LX1, LY1 + LDirection * 23)
      else
        LLabelPoint := NyxCanvasPoint(LX2, LY2 - LDirection * 23);
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
      if LTo = FSelected then
        LLabelPoint := NyxCanvasPoint(0.65 * LX1 + 0.35 * LX2, LY1)
      else
        LLabelPoint := NyxCanvasPoint(0.35 * LX1 + 0.65 * LX2, LY2);
    end;
    LPaint := NyxDrawingPaint(LinkColor(LTone, LFocused));
    LStroke := 1.25;
    if LTone <> '' then
      LStroke := 3;
    LDrawing.Path(LPath, NyxDrawingStyle.Stroke(LPaint, LStroke));
    if LTone <> '' then
      LDrawing.Path(LArrow, NyxDrawingStyle.Stroke(LPaint, LStroke));
    if LFocused and (LTone <> '') then
    begin
      LBadges[LBadgeCount].Position := LLabelPoint;
      LBadges[LBadgeCount].Tone := LTone;
      LBadges[LBadgeCount].Text := LinkBadge(LTone);
      if (GraphText(LEdge, 'kind') <> 'claim') and
        ((LTone = 'eases') or (LTone = 'worsens')) then
        LBadges[LBadgeCount].Text := GraphText(LEdge, 'label');
      Inc(LBadgeCount);
    end;
  end;
  for LIndex := 0 to LBadgeCount - 1 do
  begin
    LLabelPoint := LBadges[LIndex].Position;
    LTone := LBadges[LIndex].Tone;
    LBadgeWidth := 16 + 7 * Length(LBadges[LIndex].Text);
    LPaint := NyxDrawingPaint(LinkColor(LTone, True));
    LDrawing.Path(NyxDrawingRectangle(NyxCanvasBounds(LLabelPoint.X - LBadgeWidth / 2,
      LLabelPoint.Y - 11, LBadgeWidth, 24)),
      NyxDrawingStyle.Fill(LinkBadgeFill(LTone)).Stroke(LPaint, 1));
    LDrawing.Text(LBadges[LIndex].Text, NyxCanvasPoint(LLabelPoint.X, LLabelPoint.Y - 8),
      LPaint, 13, ndtaCenter, True);
  end;
  LScene.AddControl(NyxCanvasItem('Connections'),
    NyxCanvasPlacement(NyxCanvasLayer('Links'),
      NyxCanvasBounds(-CDrawingMargin, -CDrawingMargin,
        LWidth + 2 * CDrawingMargin, LHeight + 2 * CDrawingMargin)).Pickable(False),
    NewNyxDrawing('graph-links').WithPlan(LDrawing.Build));
  for LIndex := 0 to FVisible.Length - 1 do
  begin
    LKey := String(FVisible[LIndex]);
    LNode := FModel.Node(LKey);
    LPosition := PositionOf(LKey);
    LLeft := LPosition.X;
    LTop := LPosition.Y;
    LNodeControl := NewNyxButton('graph-node-' + IntToStr(LIndex));
    LVariant := nvSecondary;
    if LKey = FSelected then
      LVariant := nvPrimary;
    LNodeControl.Configure.Text(Capitalized(GraphText(LNode, 'kind')) + #10 +
      GraphText(LNode, 'label')).AccessibleName(GraphText(LNode, 'kind') + ': ' +
      GraphText(LNode, 'label') + '. Explore connections.').Variant(LVariant).Done;
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
  if Length(FHistory) > 0 then
  begin
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        NavigateBack;
        Result := True;
      end;
    FRenderer.ElementFor('graph-back-node').addEventListener('click', LClick);
  end;
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
    BindNeighbor('graph-neighbor-' + IntToStr(LIndex),
      GraphText(TJSObject(LNeighbors[LIndex]), 'node'));
  for LIndex := 0 to LVisibleLinks.Length - 1 do
  begin
    LEdge := TJSObject(LVisibleLinks[LIndex]);
    LTag := IntToStr(LIndex);
    FRenderer.ElementFor('graph-relationship-' + LTag).setAttribute('data-trend',
      GraphEdgeTone(LEdge));
    BindEvidence('graph-claim-' + LTag, LEdge, False);
    if GraphText(TJSObject(LEdge['assessment']), 'local_reference') <> '' then
      BindEvidence('graph-read-' + LTag, LEdge, True);
  end;
end;

function TOracleGraphExplorer.Revision: String;
begin
  Result := FModel.Revision;
end;

end.
