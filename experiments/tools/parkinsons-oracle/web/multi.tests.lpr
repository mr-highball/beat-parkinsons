{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program MultiTests;

{$mode delphi}{$H+}

uses SysUtils, JS, oraclestatic, oraclemulti, parkinsonsoracle.selection,
  parkinsonsoracle.presentation;

var
  GChecks: Integer;
  GCalls: Integer;
  GMode: String;
  GCurrent: Boolean;
  GReply: TJSObject;
  GError: String;
  GDelayed: TOracleReply;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
  Inc(GChecks);
end;

function S(AObject: TJSObject; const AKey: String): String;
begin
  if isDefined(AObject[AKey]) then
    Result := String(AObject[AKey])
  else
    Result := '';
end;

function N(AObject: TJSObject; const AKey: String): Integer;
begin
  Result := StrToIntDef(S(AObject, AKey), 0);
end;

function Current: Boolean;
begin
  Result := GCurrent;
end;

procedure Receive(AData: TJSObject; const AError: String);
begin
  GReply := AData;
  GError := AError;
end;

procedure Transport(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
var
  LRows: TJSArray;
  LData: TJSObject;
  LRow: TJSObject;
  LOffset: Integer;
  LIndex: Integer;
  LEnd: Integer;
  LId: Integer;
  LPrefix: String;
begin
  Inc(GCalls);
  if GMode = 'delay' then
  begin
    GDelayed := AReply;
    Exit;
  end;
  LData := TJSObject.new;
  LData['revision'] := 'fixed';
  if (GMode = 'revision') and (GCalls > 1) then
    LData['revision'] := 'changed';
  LRows := TJSArray.new;
  LOffset := N(AArguments, 'offset');
  if ATool = 'oracle_query' then
  begin
    if GMode = 'usefulness' then
    begin
      LData['symptom'] := AArguments['symptom'];
      if S(AArguments, 'symptom') = 'rest tremor severity' then
      begin
        LRow := TJSObject.new;
        LRow['round'] := 1;
        LRow['claim_id'] := '0001';
        LRow['verdict'] := 'Unknown';
        LRow['hypothesis_direction'] := 'reduces';
        LRow['research_status'] := 'researched';
        LRow['confidence'] := 50;
        LRows.push(LRow);

        LRow := TJSObject.new;
        LRow['round'] := 1;
        LRow['claim_id'] := '0002';
        LRow['verdict'] := 'Maybe True';
        LRow['hypothesis_direction'] := 'worsens';
        LRow['research_status'] := 'researched';
        LRow['confidence'] := 51;
        LRows.push(LRow);

        LRow := TJSObject.new;
        LRow['round'] := 2;
        LRow['claim_id'] := '0003';
        LRow['verdict'] := 'Unreviewed';
        LRow['hypothesis_direction'] := 'reduces';
        LRow['research_status'] := 'unreviewed';
        LRows.push(LRow);
      end
      else
      begin
        LRow := TJSObject.new;
        LRow['round'] := 1;
        LRow['claim_id'] := '0004';
        LRow['verdict'] := 'Maybe True';
        LRow['hypothesis_direction'] := 'reduces';
        LRow['research_status'] := 'researched';
        LRow['confidence'] := 50.5;
        LRows.push(LRow);

        LRow := TJSObject.new;
        LRow['round'] := 1;
        LRow['claim_id'] := '0005';
        LRow['verdict'] := 'Maybe False';
        LRow['hypothesis_direction'] := 'worsens';
        LRow['research_status'] := 'researched';
        LRow['confidence'] := 55;
        LRows.push(LRow);
      end;
      LData['options'] := LRows;
      LData['total_matches'] := LRows.Length;
      AReply(LData, '');
      Exit;
    end;
    Check((S(AArguments, 'scope') = 'frozen') and (S(AArguments, 'trend') = 'eases') and
      (S(AArguments, 'ingredient') = 'black tea'), 'Preserve common filters per symptom.');
    LData['symptom'] := AArguments['symptom'];
    LEnd := LOffset + 100;
    if LEnd > 105 then
      LEnd := 105;
    if GMode = 'empty' then
      LEnd := LOffset;
    for LIndex := LOffset to LEnd - 1 do
    begin
      LId := LIndex + 1;
      if S(AArguments, 'symptom') = 'pain severity' then
        Inc(LId, 49);
      LRow := TJSObject.new;
      LRow['round'] := 1;
      LRow['claim_id'] := Format('%.4d', [LId]);
      LRows.push(LRow);
    end;
    LData['options'] := LRows;
    if GMode <> 'empty' then
      LData['total_matches'] := 105;
    if (LEnd < 105) and (GMode <> 'empty') then
      LData['next_offset'] := LEnd;
    if GMode = 'empty' then
      LData['no_match_reason'] := 'evidence_filters';
    if GMode = 'empty-before-end' then
    begin
      LData['options'] := TJSArray.new;
      LData['next_offset'] := 100;
    end;
    if GMode = 'premature-end' then
      LData['next_offset'] := Null;
  end
  else
  begin
    if GMode = 'years' then
    begin
      if S(AArguments, 'terms') = 'tremor' then
      begin
        LRow := TJSObject.new;
        LRow['path'] := 'research/2025-2029/Source-Text/2025-Tremor.txt';
        LRow['period'] := '2025-2029';
        LRows.push(LRow);

        LRow := TJSObject.new;
        LRow['path'] := 'research/1595-1599/Cultural-and-Experiential/Traditional-Practices/1597-Langham.txt';
        LRow['period'] := '1595-1599';
        LRows.push(LRow);
      end
      else
      begin
        LRow := TJSObject.new;
        LRow['path'] := 'research/2025-2029/Source-Text/2026-Pain.txt';
        LRow['period'] := '2025-2029';
        LRows.push(LRow);

        LRow := TJSObject.new;
        LRow['path'] := 'research/2020-2024/Source-Text/2024-Pain.txt';
        LRow['period'] := '2020-2024';
        LRows.push(LRow);
      end;
      LData['matches'] := LRows;
      LData['total'] := LRows.Length;
      AReply(LData, '');
      Exit;
    end;
    LEnd := LOffset + 100;
    if LEnd > 150 then
      LEnd := 150;
    for LIndex := LOffset to LEnd - 1 do
    begin
      LId := LIndex;
      if S(AArguments, 'terms') = 'pain' then
        Inc(LId, 100);
      LPrefix := 'research/2020-2024/Source-Text/';
      if (GMode = 'culture') and (LId >= 100) and (LId < 106) then
        LPrefix := 'research/2020-2024/Cultural-and-Experiential/Personal-Reports/';
      LRow := TJSObject.new;
      LRow['path'] := LPrefix + IntToStr(LId) + '.txt';
      LRows.push(LRow);
    end;
    LData['matches'] := LRows;
    LData['total'] := 150;
    if LEnd < 150 then
      LData['next_offset'] := LEnd;
    if GMode = 'empty-before-end' then
    begin
      LData['matches'] := TJSArray.new;
      LData['next_offset'] := 100;
    end;
    if GMode = 'premature-end' then
      LData['next_offset'] := Null;
  end;
  AReply(LData, '');
end;

procedure Reset(const AMode: String);
begin
  GMode := AMode;
  GCalls := 0;
  GCurrent := True;
  GReply := nil;
  GError := '';
end;

procedure Run;
var
  LArguments: TJSObject;
  LSymptoms: TJSArray;
  LRows: TJSArray;
  LPage: TJSObject;
  LUnion: TOracleSourceUnion;
  LTerms: TStringValues;
  LPaths: TJSSet;
  LOffset: Integer;
  LIndex: Integer;
  LCalls: Integer;
  LOld: TOracleReply;
  LOldData: TJSObject;
begin
  LArguments := TJSObject.new;
  LSymptoms := TJSArray.new;
  LSymptoms.push('rest tremor severity', 'pain severity');
  LArguments['symptoms'] := LSymptoms;
  LArguments['scope'] := 'frozen';
  LArguments['trend'] := 'eases';
  LArguments['ingredient'] := 'black tea';
  Reset('claims');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check((GError = '') and (GCalls = 4), 'Fetch all per-symptom claim pages beyond 100.');
  LRows := TJSArray(GReply['options']);
  Check(LRows.Length = 154, 'Claim union is OR and removes overlap.');
  Check((S(TJSObject(LRows[0]), 'claim_id') = '0001') and
    (S(TJSObject(LRows[153]), 'claim_id') = '0154'), 'Combined claim order is stable.');
  LPage := ClaimUnionPage(GReply, 144, 8);
  Check((N(LPage, 'total_matches') = 154) and (N(LPage, 'next_offset') = 152),
    'Page only after union, retaining the exact total.');
  LPage := ClaimUnionPage(GReply, 152, 8);
  Check((TJSArray(LPage['options']).Length = 2) and (N(LPage, 'next_offset') = 0),
    'Final union page is not padded.');
  Reset('revision');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject mixed claim revisions.');
  Reset('empty');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check((TJSArray(GReply['options']).Length = 0) and
    (S(GReply, 'no_match_reason') = 'evidence_filters'), 'Preserve evidence-filter empty state.');
  Reset('claims');
  GCurrent := False;
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check(GCalls = 0, 'Cancel a superseded query before another request.');
  Reset('empty-before-end');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject an empty claim page before the reported end.');
  Reset('premature-end');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject premature claim pagination completion.');
  Reset('usefulness');
  LoadClaimUnion(@Transport, LArguments, @Current, @Receive);
  Check(GError = '', 'Usefulness union succeeds without error.');
  LRows := TJSArray(GReply['options']);
  Check(LRows.Length = 5, 'Usefulness union preserves all distinct claims across symptoms.');
  Check((S(TJSObject(LRows[0]), 'claim_id') = '0005') and
    (S(TJSObject(LRows[1]), 'claim_id') = '0004') and
    (S(TJSObject(LRows[2]), 'claim_id') = '0002') and
    (S(TJSObject(LRows[3]), 'claim_id') = '0001') and
    (S(TJSObject(LRows[4]), 'claim_id') = '0003'),
    'Combined claims sort descending by usefulness: eases, worsens, unknown (researched), unreviewed.');

  LUnion := TOracleSourceUnion.Create(@Transport);
  LTerms := nil;
  LTerms := AddSelection(LTerms, 'tremor');
  LTerms := AddSelection(LTerms, 'pain');
  Reset('sources');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  LRows := TJSArray(GReply['matches']);
  Check((S(TJSObject(LRows[0]), 'path') = 'research/2020-2024/Source-Text/0.txt') and
    (S(TJSObject(LRows[1]), 'path') = 'research/2020-2024/Source-Text/100.txt'),
    'Interleave selected symptoms instead of burying the second.');
  Check(S(GReply, 'total_is_exact') = 'false', 'Do not invent a deduplicated catalog total.');
  LPaths := TJSSet.new;
  LOffset := 0;
  repeat
    LUnion.Page(LOffset, 8, @Current, @Receive);
    Check(GError = '', 'Source page is available.');
    LRows := TJSArray(GReply['matches']);
    for LIndex := 0 to LRows.Length - 1 do
    begin
      Check(not LPaths.has(S(TJSObject(LRows[LIndex]), 'path')), 'No duplicate across source pages.');
      LPaths.add(S(TJSObject(LRows[LIndex]), 'path'));
    end;
    LOffset := N(GReply, 'next_offset');
  until LOffset = 0;
  Check(LPaths.size = 250, 'Exact OR union covers all source pages beyond first batches.');
  LCalls := GCalls;
  LUnion.Page(0, 8, @Current, @Receive);
  Check((GCalls = LCalls) and (TJSArray(GReply['matches']).Length = 8),
    'Previous source page reuses its cache.');
  Reset('culture');
  LUnion.Reset(LTerms, SourceKindCulture);
  LUnion.Page(0, 8, @Current, @Receive);
  Check((GError = '') and (TJSArray(GReply['matches']).Length = 6) and (GCalls = 4),
    'Source-kind selection exhausts later batches without an arbitrary cap.');
  Check(N(GReply, 'next_offset') = 0, 'No false next page after duplicate-only remainder.');
  Reset('revision');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject mixed catalog revisions.');
  Reset('delay');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  LOld := GDelayed;
  LUnion.Reset(LTerms, SourceKindCulture);
  LOldData := TJSObject.new;
  LOld(LoldData, '');
  Check(GReply = nil, 'Reset discards an old source callback.');
  Reset('empty-before-end');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject an empty source page before the reported end.');
  Reset('premature-end');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  Check((GReply = nil) and (GError <> ''), 'Reject premature source pagination completion.');
  Reset('years');
  LUnion.Reset(LTerms, SourceKindAll);
  LUnion.Page(0, 8, @Current, @Receive);
  Check(GError = '', 'Year-ordered source union succeeds.');
  LRows := TJSArray(GReply['matches']);
  Check(LRows.Length = 4, 'Year-ordered source union returns all distinct sources.');
  Check((S(TJSObject(LRows[0]), 'path') = 'research/2025-2029/Source-Text/2026-Pain.txt') and
    (S(TJSObject(LRows[1]), 'path') = 'research/2025-2029/Source-Text/2025-Tremor.txt') and
    (S(TJSObject(LRows[2]), 'path') = 'research/2020-2024/Source-Text/2024-Pain.txt') and
    (S(TJSObject(LRows[3]), 'path') = 'research/1595-1599/Cultural-and-Experiential/Traditional-Practices/1597-Langham.txt'),
    'Combined related sources sort strictly descending by year across symptoms.');
  WriteLn(GChecks, ' OR transport, paging, deduplication and freshness checks passed.');
end;

begin
  Run;
end.
