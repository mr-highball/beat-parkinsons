{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program GraphModelTests;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, JS, oraclegraphmodel, oraclegraphdata;

var
  GChecks: Integer;

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

procedure Run;
var
  LData: TJSObject;
  LModel: TOracleGraphModel;
  LRows: TJSArray;
  LEdge: TJSObject;
  LIndex: Integer;
  LRest: Boolean;
  LFatigue: Boolean;
  LReference: Boolean;
begin
  Check(HostDigest(EmbeddedGraphJSON) = EmbeddedGraphDigest,
    'Every embedded UTF-8 byte matches the native model before parsing.');
  LData := EmbeddedGraphModel;
  Check(GraphRows(LData, 'claims').Length = 6930, 'All frozen pairs survive embedding.');
  LModel := TOracleGraphModel.Create(LData);
  try
    Check(LModel.Revision = GraphText(LData, 'revision'), 'Graph revision matches model.');
    LRows := LModel.Neighbors('symptom:rest tremor severity');
    Check(LRows.Length = 210, 'All tremor hypotheses are available without a hidden cap.');
    LEdge := FindEdge(LRows, 'claim:1/0904');
    Check((LEdge <> nil) and (GraphText(LEdge, 'to') = 'ingredient:black tea'),
      'Rest tremor connects to actual black tea claim.');
    Check((GraphText(LEdge, 'label') = 'May ease') and (GraphText(LEdge, 'trend') = 'eases'),
      'Recorded weak relief has a green, qualified label.');
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
    Check(LModel.Neighbors('symptom:rest tremor severity').Length = 210,
      'Sorting a detached neighbor view cannot mutate the graph.');
    Check(LModel.Node('symptom:invented condition') = nil, 'No inferred condition is fabricated.');
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
