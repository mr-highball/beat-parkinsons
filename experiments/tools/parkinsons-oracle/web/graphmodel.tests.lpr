{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program GraphModelTests;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, JS, oraclegraphmodel, oraclegraphdata;

var
  GChecks: Integer;

const
  CConversation = 'research/2025-2029/Cultural-and-Experiential/Conversations/' +
    '2025-Reddit-Levodopa-Caffeine-and-Tremor.txt';
  CUnlinkedCulture = 'research/1995-1999/Cultural-and-Experiential/Ceremonial-Accounts/' +
    '1999-UDV-Hoasca-Research-Setting.txt';

{ Node's built-in crypto hashes the generated UTF-8 text; it supplies no model logic. }
function HostDigest(const AText: String): String;
begin
  asm
    return require('crypto').createHash('sha256').update(AText, 'utf8').digest('hex');
  end;
end;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

function FindEdge(ARows: TJSArray; const AKey: String): TJSObject;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to ARows.Length - 1 do
  begin
    if GraphText(TJSObject(ARows[LIndex]), 'key') = AKey then
    begin
      Exit(TJSObject(ARows[LIndex]));
    end;
  end;
end;

function CountKind(ARows: TJSArray; const AKind: String): Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to ARows.Length - 1 do
  begin
    if GraphText(TJSObject(ARows[LIndex]), 'kind') = AKind then
      Inc(Result);
  end;
end;

procedure Run;
var
  LData: TJSObject;
  LModel: TOracleGraphModel;
  LRows: TJSArray;
  LConnections: TJSArray;
  LConnection: TJSObject;
  LEdge: TJSObject;
  LNodes: TJSSet;
  LIndex: Integer;
  LLinkCount: Integer;
  LClaims: TJSArray;
  LClaim: TJSObject;
  LKey: String;
  LCitation: TJSObject;
  LRest: Boolean;
  LFatigue: Boolean;
  LReference: Boolean;
  LOpposingSaffron: Integer;
begin
  Check(HostDigest(EmbeddedGraphJSON) = EmbeddedGraphDigest,
    'Every embedded UTF-8 byte matches the native model before parsing.');
  LData := EmbeddedGraphModel;
  Check(GraphRows(LData, 'claims').Length = 6930, 'All frozen pairs survive embedding.');
  LModel := TOracleGraphModel.Create(LData);
  try
    Check(LModel.Revision = GraphText(LData, 'revision'), 'Graph revision matches model.');
    Check(GraphRows(LData, 'culture_sources').Length > 0,
      'The published model includes the dedicated cultural collection.');
    Check(GraphText(LModel.Node(GraphKey('source', CUnlinkedCulture)), 'kind') = 'culture',
      'A cultural account with no annotated topic still has a readable graph node.');
    Check(LModel.Connections(GraphKey('source', CUnlinkedCulture)).Length = 0,
      'An unannotated account does not acquire an invented connection.');
    LEdge := FindEdge(LModel.Neighbors(GraphKey('source', CConversation)),
      GraphKey('source', CConversation) + '/topic/' + GraphKey('symptom', 'rest tremor severity'));
    Check((LEdge <> nil) and (GraphText(LEdge, 'trend') = '') and
      (GraphEdgeTone(LEdge) = 'cultural') and (TJSObject(LEdge['claim']) = nil),
      'A conversational topic links to its symptom without a verdict or directional arrow.');
    LRows := LModel.Neighbors('symptom:rest tremor severity');
    Check(CountKind(LRows, 'claim') = 210, 'All tremor hypotheses are available without a hidden cap.');
    Check(CountKind(LRows, 'outcome') > 0, 'A symptom links back to studies that assessed it.');
    LConnections := LModel.Connections('symptom:rest tremor severity');
    LNodes := TJSSet.new;
    LLinkCount := 0;
    for LIndex := 0 to LConnections.Length - 1 do
    begin
      LConnection := TJSObject(LConnections[LIndex]);
      LNodes.add(GraphText(LConnection, 'node'));
      Inc(LLinkCount, GraphRows(LConnection, 'edges').Length);
    end;
    Check((LNodes.size = LConnections.Length) and (LLinkCount = LRows.Length),
      'Each neighbor consumes one slot and its group keeps all recorded edges.');
    Check(GraphText(TJSObject(LConnections[0]), 'node') = 'ingredient:black tea',
      'The grouped projection keeps the qualified evidence visible first.');
    Check(Pos('study:', GraphText(TJSObject(LConnections[1]), 'node')) = 1,
      'Studies appear in the first group rotation.');
    LEdge := FindEdge(LRows, 'claim:1/0904');
    Check((LEdge <> nil) and (GraphText(LEdge, 'to') = 'ingredient:black tea'),
      'Rest tremor connects to actual black tea claim.');
    Check((GraphText(LEdge, 'label') = 'May ease') and (GraphText(LEdge, 'trend') = 'eases'),
      'Recorded weak relief has a green, qualified label.');
    Check((GraphEdgeTone(LEdge) = 'eases') and
      (GraphText(TJSObject(LRows[0]), 'key') = 'claim:1/0904') and
      (GraphText(TJSObject(LRows[1]), 'kind') = 'outcome'),
      'The first expansion interleaves claims and studies without burying the directional claim.');
    Check(FindEdge(LModel.Neighbors('ingredient:black tea'), 'claim:1/0904') = LEdge,
      'The same directional claim is reachable from the ingredient.');
    Check(GraphText(TJSObject(LEdge['claim']), 'preparation') = 'brewed', 'Preparation is retained.');
    Check(GraphText(TJSObject(LEdge['claim']), 'statement') =
      'Consuming brewed black tea reduces rest tremor severity in people with Parkinson''s disease.',
      'Exact frozen wording and apostrophe survive the generated include.');
    LRows := LModel.Neighbors('study:NCT00461942');
    LRest := False;
    LFatigue := False;
    LReference := False;
    for LIndex := 0 to LRows.Length - 1 do
    begin
      LEdge := TJSObject(LRows[LIndex]);
      if GraphText(LEdge, 'kind') = 'outcome' then
      begin
        Check((GraphText(LEdge, 'label') = 'Related context') and (GraphText(LEdge, 'trend') = ''),
          'The green-tea registry has related context, not a colored efficacy edge.');
        LRest := LRest or (GraphText(LEdge, 'to') = 'symptom:rest tremor severity');
        LFatigue := LFatigue or (GraphText(LEdge, 'to') = 'symptom:fatigue severity');
      end;
      if GraphText(LEdge, 'to') = 'source:research/2005-2009/Food-Experiment-Tea-Followup.md' then
      begin
        LReference := True;
      end;
    end;
    Check(LRest and LFatigue, 'Shared registry connects only its recorded symptom assessments.');
    Check(LReference, 'Clickable assessment source has an exact document node.');
    Check(CountKind(LRows, 'assessment') > 0, 'A study connects back to its ingredients.');
    Check(CountKind(LModel.Neighbors('source:research/2005-2009/Food-Experiment-Tea-Followup.md'),
      'reference') > 0, 'A saved source connects back to studies recorded in the ledger.');
    LRows := LModel.Neighbors('study:PMID41439298');
    LOpposingSaffron := 0;
    for LIndex := 0 to LRows.Length - 1 do
    begin
      LEdge := TJSObject(LRows[LIndex]);
      if (GraphText(LEdge, 'kind') = 'outcome') and
        (GraphText(TJSObject(LEdge['assessment']), 'role') = 'opposes') then
      begin
        Check((GraphText(LEdge, 'label') = 'Challenges hypothesis') and
          (GraphText(LEdge, 'trend') = '') and (GraphEdgeTone(LEdge) = 'challenged'),
          'Real opposing assessments get a challenge marker and no inverse effect.');
        Inc(LOpposingSaffron);
      end;
    end;
    Check(LOpposingSaffron >= 2, 'Saffron depression and fatigue opposition is present.');
    Check(CountKind(LModel.Neighbors('symptom:rest tremor severity'), 'claim') = 210,
      'Sorting a detached neighbor view cannot mutate the graph.');
    Check(LModel.Node('symptom:invented condition') = nil, 'No inferred condition is fabricated.');
    LClaims := GraphRows(LData, 'claims');
    LCitation := nil;
    for LIndex := 0 to LClaims.Length - 1 do
    begin
      LClaim := TJSObject(LClaims[LIndex]);
      if GraphRows(LClaim, 'local_references').Length = 0 then
        Continue;
      LKey := GraphKey('ingredient', GraphText(LClaim, 'ingredient'));
      LRows := LModel.Neighbors(LKey);
      LCitation := FindEdge(LRows, GraphText(LClaim, 'round') + '/' +
        GraphText(LClaim, 'claim_id') + '/citation:0/ingredient');
      if LCitation <> nil then
        Break;
    end;
    Check((LCitation <> nil) and (GraphEdgeTone(LCitation) = '') and
      (GraphText(LCitation, 'label') = 'Cited in claim'),
      'A real claim-only citation appears as a neutral saved-source link.');
    LRows := LModel.Neighbors(GraphText(LCitation, 'to'));
    Check(FindEdge(LRows, GraphText(LCitation, 'key')) = LCitation,
      'A claim-only source can be followed back to the actual ingredient.');
    Check(ReferenceFile('research/2010-2014/Food-Experiment-Black-Tea-Motor.md#section') =
      'research/2010-2014/Food-Experiment-Black-Tea-Motor.md', 'Reader paths exclude anchors.');
    WriteLn(GChecks, ' real-model graph checks passed; nodes=', LModel.NodeCount,
      ' edges=', LModel.EdgeCount, ' revision=', LModel.Revision);
  finally
    LModel.Free;
  end;
end;

begin
  Run;
end.
