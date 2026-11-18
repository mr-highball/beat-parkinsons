{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleWeb;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, StrUtils, JS, Web, nyx.model, nyx.types, nyx.render.browser, oraclevocab,
  oraclestatic, parkinsonsoracle.trend, parkinsonsoracle.presentation;

type
  TOracleView = (ovClaims, ovCatalog);
  TSourceOffsets = array of Integer;

const
  CPageSize = 8;
  CTextInputs: array[0..1] of String = ('terms', 'period');
  CQuickSymptoms: array[0..4] of String = ('rest tremor severity', 'constipation severity',
    'fatigue severity', 'insomnia severity', 'pain severity');

var
  GDocument: TNyxDocument;
  GRenderer: TNyxBrowserRenderer;
  GResultsDocument: TNyxDocument;
  GResultsRenderer: TNyxBrowserRenderer;
  GView: TOracleView;
  GSequence: Integer;
  GResults: TJSObject;
  GArguments: TJSObject;
  GRelatedSources: TJSObject;
  GRelatedTerms: String;
  GRelatedError: String;
  GResearchKind: Integer;
  GRelatedOffsets: TSourceOffsets;
  GRelatedPage: Integer;
  GRelatedNext: Integer;
  GRelatedBusy: Boolean;
  GTrend: String;
  GFilterOptions: TJSObject;
  GStaticOracle: TStaticOracle;
  GSymptom: TOraclePicker;
  GIngredient: TOraclePicker;
  GPreparation: TOraclePicker;

function JSValueText(AValue: JSValue): String; external name 'String';

function TextOf(AObject: TJSObject; const AKey: String): String;
var
  LValue: JSValue;
begin
  Result := '';
  if AObject = nil then
    Exit;
  LValue := AObject[AKey];
  if isDefined(LValue) and not isNull(LValue) then
    Result := JSValueText(LValue);
end;

function CountOf(AObject: TJSObject; const AKey: String): Integer;
begin
  Result := StrToIntDef(TextOf(AObject, AKey), 0);
end;

function ItemsOf(AObject: TJSObject; const AKey: String): TJSArray;
begin
  if (AObject <> nil) and TJSArray.isArray(AObject[AKey]) then
    Result := TJSArray(AObject[AKey])
  else
    Result := TJSArray.new;
end;

function Section(AKind: TNyxKind; const AId: String): TNyxNode;
begin
  Result := TNyxNode.Create(AKind, AId);
end;

function Caption(AKind: TNyxKind; const AId, AValue: String): TNyxNode;
begin
  Result := Section(AKind, AId).Configure.Text(AValue).Done;
end;

function SourceLink(const AId, APath: String): TNyxNode;
var
  LURL: String;
begin
  if GStaticOracle <> nil then
  begin
    LURL := GStaticOracle.ReferenceURL(APath);
    if LURL <> '' then
      Exit(Section(nkLink, AId).Configure.Text(APath).LinkTo(LURL).Done);
  end;
  Result := Caption(nkCode, AId, APath);
end;

function Button(const AId, AValue: String; AVariant: TNyxVariant): TNyxNode;
begin
  Result := Section(nkButton, AId).Configure.Text(AValue).Variant(AVariant).Done;
end;

function Field(const AId, ALabel, APlaceholder: String): TNyxNode;
begin
  Result := Section(nkColumn, AId + '-field');
  Result.Add(Section(nkInput, AId).Configure.Text(ALabel)
    .AccessibleName(ALabel).Placeholder(APlaceholder).Done);
end;

function SelectField(const AId, ALabel, AItems: String): TNyxNode;
begin
  Result := Section(nkColumn, AId + '-field');
  Result.Add(Section(nkSelect, AId).Configure.Text(ALabel).AccessibleName(ALabel)
    .Items(AItems).Value(Copy(AItems, 1, Pos(#10, AItems) - 1)).Done);
end;

function InputValue(const AId: String): String;
begin
  Result := Trim(TJSHTMLInputElement(GRenderer.InputFor(AId)).value);
end;

function SelectedIndex(const AId: String): Integer;
begin
  Result := TJSHTMLSelectElement(GRenderer.InputFor(AId)).selectedIndex;
end;

procedure BindEvent(AElement: TJSHTMLElement; const AEventName: String; AHandler: TJSEventHandler);
begin
  AElement.addEventListener(AEventName, AHandler);
end;

procedure RequestLocal(const ABody: String; AReply: TOracleReply; ACanRetry: Boolean);
var
  LRequest: TJSXMLHttpRequest;
  LCompleted: Boolean;

  procedure Fail(const AError: String; ATransient: Boolean);
  begin
    if LCompleted then
      Exit;
    LCompleted := True;
    if ATransient and ACanRetry then
    begin
      window.setTimeout(
        procedure
        begin
          RequestLocal(ABody, AReply, False);
        end, 500);
    end
    else
      AReply(nil, AError);
  end;

  function ConnectionFailed(AEvent: TJSProgressEvent): Boolean;
  begin
    Fail('The connection was interrupted. Please try again.', True);
    Result := False;
  end;

begin
  LCompleted := False;
  LRequest := TJSXMLHttpRequest.new;
  LRequest.onerror := @ConnectionFailed;
  LRequest.onabort := @ConnectionFailed;
  LRequest.ontimeout :=
    function(AEvent: TJSProgressEvent): Boolean
    begin
      Fail('The request took too long. Please try again.', True);
      Result := False;
    end;
  LRequest.onload :=
    function(AEvent: TJSProgressEvent): Boolean
    var
      LValue: JSValue;
      LError: String;
    begin
      Result := False;
      if LCompleted then
        Exit;
      if (LRequest.Status = 0) or (LRequest.Status = 502) or
        (LRequest.Status = 503) or (LRequest.Status = 504) then
      begin
        Fail('The connection was interrupted. Please try again.', True);
        Exit;
      end;
      LCompleted := True;
      try
        LValue := TJSJSON.parse(LRequest.responseText);
      except
        AReply(nil, 'The oracle returned an unreadable response.');
        Exit;
      end;
      if isNull(LValue) or (jsTypeOf(LValue) <> 'object') or TJSArray.isArray(LValue) then
      begin
        AReply(nil, 'The oracle returned an unreadable response.');
        Exit;
      end;
      LError := TextOf(TJSObject(LValue), 'error');
      if (LError = '') and (LRequest.Status >= 400) then
        LError := 'The oracle reported HTTP ' + IntToStr(LRequest.Status) + '.';
      AReply(TJSObject(LValue), LError);
    end;
  try
    LRequest.open('POST', '/api/oracle', True);
    LRequest.setRequestHeader('Content-Type', 'application/json');
    LRequest.timeout := 25000;
    LRequest.send(ABody);
  except
    Fail('The request could not start. Please try again.', False);
  end;
end;

procedure Request(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
var
  LBody: TJSObject;
begin
  if GStaticOracle <> nil then
  begin
    GStaticOracle.Call(ATool, AArguments, AReply);
    Exit;
  end;
  LBody := TJSObject.new;
  LBody['name'] := ATool;
  LBody['arguments'] := AArguments;
  RequestLocal(TJSJSON.stringify(LBody), AReply, True);
end;

procedure PublishResults(ADocument: TNyxDocument; APage: TNyxNode);
var
  LPrior: TNyxDocument;
begin
  LPrior := GResultsDocument;
  GResultsRenderer.Render(ADocument, APage, GRenderer.ElementFor('results-frame'));
  GResultsDocument := ADocument;
  LPrior.Free;
end;

procedure MessageView(const ATitle, AMessage: String);
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
begin
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LPage.Add(Caption(nkHeading, 'result-heading', ATitle));
  LPage.Add(Caption(nkLabel, 'result-message', AMessage));
  PublishResults(LDocument, LPage);
end;

procedure ShowList(AResults: TJSObject; AFocus: Boolean = True); forward;
procedure Query(ANewQuery: Boolean; AOffset: Integer); forward;
procedure SwitchView(AView: TOracleView); forward;

function RelatedCatalogTerms: String;
begin
  Result := RelatedSourceTerms(TextOf(GArguments, 'ingredient'),
    TextOf(GArguments, 'symptom'), GResearchKind);
end;

procedure LoadRelatedSources(AOffset: Integer; AReply: TOracleReply);
var
  LMatches: TJSArray;
  LSequence: Integer;
  LKind: Integer;
  LRevision: String;
  LTerms: String;

  procedure ReadBatch(ABatchOffset: Integer);
  var
    LArguments: TJSObject;
  begin
    LArguments := TJSObject.new;
    LArguments['terms'] := LTerms;
    LArguments['limit'] := 100;
    LArguments['offset'] := ABatchOffset;
    Request('oracle_search_catalog', LArguments,
      procedure(AData: TJSObject; const AError: String)
      var
        LRows: TJSArray;
        LPaths: array of String;
        LSelection: TSourceSelection;
        LIndex: Integer;
        LCursor: Integer;
        LTotal: Integer;
        LResult: TJSObject;
      begin
        if LSequence <> GSequence then
          Exit;
        if AError <> '' then
        begin
          AReply(nil, AError);
          Exit;
        end;
        if (LRevision <> '') and (LRevision <> TextOf(AData, 'revision')) then
        begin
          AReply(nil, 'The catalog changed while loading. Please try again.');
          Exit;
        end;
        LRevision := TextOf(AData, 'revision');
        LRows := ItemsOf(AData, 'matches');
        SetLength(LPaths, LRows.Length);
        for LIndex := 0 to LRows.Length - 1 do
          LPaths[LIndex] := TextOf(TJSObject(LRows[LIndex]), 'path');
        LSelection := SelectSourcePage(LPaths, LKind, CPageSize - LMatches.Length);
        for LIndex := 0 to Length(LSelection.Indices) - 1 do
          LMatches.push(LRows[LSelection.Indices[LIndex]]);
        LCursor := ABatchOffset + LSelection.Examined;
        LTotal := CountOf(AData, 'total');
        if (LMatches.Length = CPageSize) or (LCursor >= LTotal) then
        begin
          LResult := TJSObject.new;
          LResult['matches'] := LMatches;
          LResult['total'] := LTotal;
          LResult['revision'] := LRevision;
          if LCursor < LTotal then
            LResult['next_offset'] := LCursor
          else
            LResult['next_offset'] := 0;
          AReply(LResult, '');
        end
        else if LSelection.Examined = 0 then
          AReply(nil, 'Some source results could not be loaded. Please try again.')
        else
          ReadBatch(LCursor);
      end);
  end;

begin
  LMatches := TJSArray.new;
  LSequence := GSequence;
  LKind := GResearchKind;
  LTerms := GRelatedTerms;
  LRevision := '';
  ReadBatch(AOffset);
end;

procedure RefreshRelated(AOffset: Integer);
begin
  Inc(GSequence);
  GRelatedBusy := True;
  GRelatedTerms := RelatedCatalogTerms;
  LoadRelatedSources(AOffset,
    procedure(AData: TJSObject; const AError: String)
    var
      LHeading: TJSHTMLElement;
    begin
      GRelatedBusy := False;
      GRelatedSources := AData;
      GRelatedError := AError;
      GRelatedNext := CountOf(AData, 'next_offset');
      ShowList(GResults, False);
      LHeading := GResultsRenderer.ElementFor('related-heading');
      if LHeading <> nil then
      begin
        LHeading.setAttribute('tabindex', '-1');
        LHeading.focus;
      end;
    end);
end;

procedure ChangeResearchKind(AKind: Integer);
begin
  GResearchKind := AKind;
  SetLength(GRelatedOffsets, 1);
  GRelatedOffsets[0] := 0;
  GRelatedPage := 0;
  RefreshRelated(0);
end;

function EvidenceLabel(const AVerdict: String): String;
begin
  case IndexStr(AVerdict, ['True', 'False', 'Maybe True', 'Maybe False', 'Unknown']) of
    0: Result := 'Evidence supports this claim';
    1: Result := 'Evidence weighs against this claim';
    2: Result := 'Limited evidence in favor';
    3: Result := 'Limited evidence against this claim';
    4: Result := 'Still unclear';
  else
    Result := 'Awaiting review';
  end;
end;

function ClaimIndicators(AClaim: TJSObject; const AId: String): TNyxNode;
var
  LVerdict: String;
  LEffect: String;
  LEffectId: String;
  LEvidence: String;
begin
  LVerdict := TextOf(AClaim, 'verdict');
  LEvidence := EvidenceLabel(LVerdict);
  LEffect := '';
  case IndexStr(ClaimTrend(LVerdict, TextOf(AClaim, 'hypothesis_direction')),
    ['eases', 'worsens']) of
    0:
      begin
        LEffect := '↓ May ease';
        LEffectId := 'effect-relief-';
      end;
    1:
      begin
        LEffect := '↑ May worsen';
        LEffectId := 'effect-worse-';
      end;
  end;

  Result := Section(nkRow, 'claim-indicators-' + AId);
  if LEffect <> '' then
  begin
    Result.Add(Caption(nkBadge, LEffectId + AId, LEffect));
    if LVerdict = 'Maybe True' then
      LEvidence := 'Limited evidence';
  end;
  Result.Add(Caption(nkBadge, 'grade-' + AId, LEvidence));
end;

function ResearchQuestion(AClaim: TJSObject): String;
var
  LExposure: String;
  LEffect: String;
  LSymptom: String;
begin
  LExposure := Trim(TextOf(AClaim, 'preparation') + ' ' + TextOf(AClaim, 'ingredient'));
  LSymptom := LowerCase(FriendlySymptom(TextOf(AClaim, 'symptom')));
  if TextOf(AClaim, 'hypothesis_direction') = 'reduces' then
    LEffect := ' reduce '
  else
    LEffect := ' worsen ';
  Result := 'Could ' + LExposure + LEffect + LSymptom + '?';
end;

procedure FocusResults;
var
  LHeading: TJSHTMLElement;
begin
  LHeading := GResultsRenderer.ElementFor('result-heading');
  LHeading.setAttribute('tabindex', '-1');
  LHeading.focus;
  LHeading.scrollIntoView(True);
end;

procedure TogglePanel(const AButton, APanel, AClosed, AOpen: String);
var
  LButton: TJSHTMLElement;
  LPanel: TJSHTMLElement;
begin
  LButton := GRenderer.ElementFor(AButton);
  LPanel := GRenderer.ElementFor(APanel);
  if LPanel.hasAttribute('hidden') then
  begin
    LPanel.removeAttribute('hidden');
    LButton.setAttribute('aria-expanded', 'true');
    LButton.textContent := AOpen;
  end
  else
  begin
    LPanel.setAttribute('hidden', '');
    LButton.setAttribute('aria-expanded', 'false');
    LButton.textContent := AClosed;
  end;
end;

procedure HideSuggestions;
begin
  GSymptom.HideSuggestions;
  GIngredient.HideSuggestions;
  GPreparation.HideSuggestions;
end;

procedure UpdateFilterCount;
var
  LCount: Integer;
  LButton: TJSHTMLElement;
  LLabel: String;
begin
  LCount := Ord((GIngredient.Chosen <> '') or (Trim(GIngredient.Input.value) <> '')) +
    Ord((GPreparation.Chosen <> '') or (Trim(GPreparation.Input.value) <> '')) +
    Ord(SelectedIndex('scope') <> 2) + Ord(SelectedIndex('direction') > 0);
  LButton := GRenderer.ElementFor('show-filters');
  if LButton.getAttribute('aria-expanded') = 'true' then
    LLabel := 'Fewer filters'
  else
    LLabel := 'More filters';
  if LCount > 0 then
    LLabel := LLabel + ' · ' + IntToStr(LCount) + ' active';
  GRenderer.Root.Find('show-filters').Configure.Text(LLabel);
  LButton.textContent := LLabel;
end;

procedure IngredientChanged;
var
  LForms: TJSArray;
  LIndex: Integer;
  LStillValid: Boolean;
begin
  if GFilterOptions <> nil then
  begin
    LForms := IngredientPreparations(GFilterOptions, GIngredient.Chosen);
    GPreparation.SetChoices(LForms);
    if GPreparation.Chosen <> '' then
    begin
      LStillValid := False;
      for LIndex := 0 to LForms.Length - 1 do
        if TextOf(TJSObject(LForms[LIndex]), 'value') = GPreparation.Chosen then
          LStillValid := True;
      if not LStillValid then
        GPreparation.Clear;
    end;
  end;
  UpdateFilterCount;
end;

procedure SetPressed(const AId: String; APressed: Boolean);
begin
  GRenderer.Root.Find(AId).Configure.Pressed(APressed);
  GRenderer.ElementFor(AId).setAttribute('aria-pressed', LowerCase(BoolToStr(APressed, True)));
end;

procedure SymptomChanged;
var
  LIndex: Integer;
begin
  for LIndex := Low(CQuickSymptoms) to High(CQuickSymptoms) do
    SetPressed('quick-' + IntToStr(LIndex), GSymptom.Chosen = CQuickSymptoms[LIndex]);
end;

procedure BindQuickSymptom(const ANodeId, AValue: String);
begin
  BindEvent(GRenderer.ElementFor(ANodeId), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      GSymptom.Pick(AValue);
      Result := True;
    end);
end;

procedure SelectTrend(const ATrend: String);
begin
  GTrend := ATrend;
  SetPressed('trend-any', GTrend = '');
  SetPressed('trend-eases', GTrend = 'eases');
  SetPressed('trend-worsens', GTrend = 'worsens');
end;

procedure BindTrend(const ANodeId, ATrend: String);
begin
  BindEvent(GRenderer.ElementFor(ANodeId), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      SelectTrend(ATrend);
      Result := True;
    end);
end;

procedure SubmitLookup;
begin
  Query(True, 0);
end;

procedure LoadFilterOptions;
begin
  Request('oracle_filter_options', TJSObject.new,
    procedure(AData: TJSObject; const AError: String)
    begin
      if AError <> '' then
      begin
        GRenderer.ElementFor('guidance').textContent :=
          'Choose a quick option or type the full name of a symptom.';
        Exit;
      end;
      GFilterOptions := AData;
      GSymptom.SetChoices(ItemsOf(AData, 'symptoms'));
      GIngredient.SetChoices(ItemsOf(AData, 'ingredients'));
      IngredientChanged;
    end);
end;

function Inspect(ARound: Integer; const AId: String): Boolean;
var
  LArgs: TJSObject;
  LSequence: Integer;
begin
  Inc(GSequence);
  LSequence := GSequence;
  LArgs := TJSObject.new;
  LArgs['round'] := ARound;
  LArgs['id'] := AId;
  MessageView('Loading evidence', 'Reading the published assessment ledger.');
  Request('oracle_claim', LArgs,
    procedure(AData: TJSObject; const AError: String)
    var
      LDocument: TNyxDocument;
      LPage: TNyxNode;
      LCard: TNyxNode;
      LItems: TJSArray;
      LRow: TJSObject;
      LIndex: Integer;
      LTag: String;
    begin
      if LSequence <> GSequence then
        Exit;
      if AError <> '' then
      begin
        MessageView('Evidence unavailable', AError);
        Exit;
      end;
      if TextOf(AData, 'found') <> 'true' then
      begin
        MessageView('Claim unavailable', 'The published round does not contain this claim.');
        Exit;
      end;

      LDocument := TNyxDocument.Create;
      LPage := Section(nkPage, 'result-page');
      LDocument.AddPage(LPage);
      LPage.Add(Button('back-results', '‹ Back to results', nvSecondary));
      LPage.Add(Caption(nkHeading, 'result-heading', Capitalized(TextOf(AData, 'ingredient'))));
      LPage.Add(ClaimIndicators(AData, 'detail'));
      LPage.Add(Caption(nkLabel, 'claim-question', ResearchQuestion(AData)));
      if TextOf(AData, 'confidence') <> '' then
        LPage.Add(Caption(nkLabel, 'claim-confidence',
          'Reviewer judgment ' + TextOf(AData, 'confidence') + '/100'));
      LPage.Add(Caption(nkLabel, 'claim-number',
        'Round ' + IntToStr(ARound) + ' · Claim ' + AId));
      LPage.Add(Caption(nkLabel, 'claim-statement-heading', 'Original claim under review'));
      LPage.Add(Caption(nkLabel, 'claim-statement', TextOf(AData, 'statement')));
      if TextOf(AData, 'rationale') <> '' then
        LPage.Add(Caption(nkLabel, 'claim-rationale', TextOf(AData, 'rationale')));
      if TextOf(AData, 'queued_original_pairs') <> '' then
        LPage.Add(Caption(nkLabel, 'claim-coverage',
          TextOf(AData, 'queued_original_pairs') + ' original Europe PMC pairs still queued'));

      LItems := ItemsOf(AData, 'assessments');
      LPage.Add(Caption(nkHeading, 'evidence-heading', 'What the studies looked at'));
      if LItems.Length = 0 then
        LPage.Add(Caption(nkLabel, 'result-message', 'This claim is awaiting study review.'));
      for LIndex := 0 to LItems.Length - 1 do
      begin
        LRow := TJSObject(LItems[LIndex]);
        LTag := IntToStr(LIndex);
        LCard := Section(nkCard, 'evidence-' + LTag);
        LCard.Add(Caption(nkBadge, 'role-' + LTag, TextOf(LRow, 'role')));
        LCard.Add(Caption(nkLabel, 'study-' + LTag, TextOf(LRow, 'study')));
        LCard.Add(Caption(nkLabel, 'fit-' + LTag, TextOf(LRow, 'fit')));
        LCard.Add(Caption(nkLabel, 'analysis-' + LTag, TextOf(LRow, 'assessment')));
        LCard.Add(SourceLink('ref-' + LTag, TextOf(LRow, 'local_reference')));
        LPage.Add(LCard);
      end;
      LItems := ItemsOf(AData, 'local_references');
      if LItems.Length > 0 then
      begin
        LPage.Add(Caption(nkHeading, 'citations-heading', 'Source references'));
        for LIndex := 0 to LItems.Length - 1 do
          LPage.Add(SourceLink('citation-' + IntToStr(LIndex), JSValueText(LItems[LIndex])));
      end;

      PublishResults(LDocument, LPage);
      FocusResults;
      BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          ShowList(GResults);
          Result := True;
        end);
    end);
  Result := True;
end;

procedure BindDetail(const ATag: String; ARound: Integer; const AId: String);
begin
  BindEvent(GResultsRenderer.ElementFor('inspect-' + ATag), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := Inspect(ARound, AId);
    end);
end;

procedure OpenSource(const APath, ATag: String; const AOffsets: TSourceOffsets);
var
  LArgs: TJSObject;
  LSequence: Integer;
  LOffset: Integer;
begin
  Inc(GSequence);
  LSequence := GSequence;
  LOffset := AOffsets[High(AOffsets)];
  LArgs := TJSObject.new;
  LArgs['path'] := APath;
  LArgs['offset'] := LOffset;
  MessageView('Opening source', 'Reading the indexed research file.');
  Request('oracle_read_source', LArgs,
    procedure(AData: TJSObject; const AError: String)
    var
      LDocument: TNyxDocument;
      LPage: TNyxNode;
      LPaging: TNyxNode;
      LNext: Integer;
      LText: String;
      LHasPrevious: Boolean;
      LHasNext: Boolean;
    begin
      if LSequence <> GSequence then
        Exit;
      LDocument := TNyxDocument.Create;
      LPage := Section(nkPage, 'result-page');
      LDocument.AddPage(LPage);
      LPage.Add(Button('back-results', '‹ Back to results', nvSecondary));
      LPage.Add(Caption(nkHeading, 'result-heading', ExtractFileName(APath)));
      LPage.Add(Caption(nkCode, 'source-path', APath));
      if IsCulturalSource(APath) then
        LPage.Add(Caption(nkBadge, 'reader-kind-culture',
          'Culture and lived experience · Reported account'))
      else
        LPage.Add(Caption(nkBadge, 'reader-kind-study', 'Research source'));
      LNext := CountOf(AData, 'next_offset');
      LHasPrevious := (AError = '') and (Length(AOffsets) > 1);
      LHasNext := (AError = '') and (LNext > LOffset);
      if AError <> '' then
        LPage.Add(Caption(nkLabel, 'result-message', AError))
      else
      begin
        if LHasPrevious or LHasNext then
          LPage.Add(Caption(nkLabel, 'source-part', 'Part ' + IntToStr(Length(AOffsets))));
        LText := TextOf(AData, 'text');
        if LText <> '' then
          LPage.Add(Caption(nkCode, 'source-body', LText))
        else
          LPage.Add(Caption(nkLabel, 'result-message', 'This file has no text.'));
      end;
      if LHasPrevious or LHasNext then
      begin
        LPaging := Section(nkRow, 'result-pagination');
        if LHasPrevious then
          LPaging.Add(Button('previous-page', 'Previous part', nvSecondary));
        if LHasNext then
          LPaging.Add(Button('next-page', 'Next part', nvSecondary));
        LPage.Add(LPaging);
      end;
      PublishResults(LDocument, LPage);
      FocusResults;
      BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          ShowList(GResults);
          GResultsRenderer.ElementFor('open-source-' + ATag).focus;
          Result := True;
        end);
      if LHasPrevious then
        BindEvent(GResultsRenderer.ElementFor('previous-page'), 'click',
          function(AEvent: TEventListenerEvent): Boolean
          begin
            OpenSource(APath, ATag, Copy(AOffsets, 0, Length(AOffsets) - 1));
            Result := True;
          end);
      if LHasNext then
        BindEvent(GResultsRenderer.ElementFor('next-page'), 'click',
          function(AEvent: TEventListenerEvent): Boolean
          var
            LOffsets: TSourceOffsets;
          begin
            LOffsets := Copy(AOffsets, 0, Length(AOffsets));
            SetLength(LOffsets, Length(LOffsets) + 1);
            LOffsets[High(LOffsets)] := LNext;
            OpenSource(APath, ATag, LOffsets);
            Result := True;
          end);
    end);
end;

procedure BindSource(const ATag, APath: String);
begin
  BindEvent(GResultsRenderer.ElementFor('open-source-' + ATag), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LOffsets: TSourceOffsets;
    begin
      SetLength(LOffsets, 1);
      LOffsets[0] := 0;
      OpenSource(APath, ATag, LOffsets);
      Result := True;
    end);
end;

procedure ShowList(AResults: TJSObject; AFocus: Boolean);
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
  LRow: TJSObject;
  LCard: TNyxNode;
  LPaging: TNyxNode;
  LRecords: TJSArray;
  LRelatedRecords: TJSArray;
  LIndex: Integer;
  LTotal: Integer;
  LOffset: Integer;
  LNext: Integer;
  LTag: String;
  LPath: String;
  LTrend: String;
  LMessage: String;
  LCanShowReviewed: Boolean;
  LCanShowAnyTrend: Boolean;
  LKindTabs: TNyxNode;
begin
  LRelatedRecords := TJSArray.new;
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LTrend := TextOf(GArguments, 'trend');
  LCanShowAnyTrend := (GView = ovClaims) and (LTrend <> '') and
    (CountOf(AResults, 'total_matches') = 0);
  LCanShowReviewed := (GView = ovClaims) and
    (LTrend = '') and
    (TextOf(GArguments, 'scope') = '') and
    (TextOf(AResults, 'no_match_reason') = 'evidence_filters') and
    (CountOf(AResults, 'total_matches') = 0);
  LOffset := CountOf(AResults, 'offset');
  LNext := CountOf(AResults, 'next_offset');
  if GView = ovClaims then
  begin
    LRecords := ItemsOf(AResults, 'options');
    LTotal := CountOf(AResults, 'total_matches');
    LMessage := 'Research results';
    if TextOf(AResults, 'symptom') <> '' then
      LMessage := 'Research on ' + LowerCase(FriendlySymptom(TextOf(AResults, 'symptom')));
    LPage.Add(Caption(nkHeading, 'result-heading', LMessage));
    LKindTabs := Section(nkRow, 'research-kind-tabs');
    LKindTabs.Add(Button('research-kind-all', 'All research', nvSecondary));
    LKindTabs.Add(Button('research-kind-studies', 'Studies & analyses', nvSecondary));
    LKindTabs.Add(Button('research-kind-culture', 'Culture & experience', nvSecondary));
    LPage.Add(LKindTabs);
    if GResearchKind = SourceKindCulture then
    begin
      LRecords := TJSArray.new;
      LPage.Add(Caption(nkLabel, 'culture-introduction',
        'Traditional use, ceremonies and lived experience are active research leads. Explore the original accounts, their context and what is still untested.'));
    end;
  end
  else
  begin
    LRecords := ItemsOf(AResults, 'matches');
    LTotal := CountOf(AResults, 'total');
    LPage.Add(Caption(nkHeading, 'result-heading', 'Catalog results'));
  end;
  if (GView = ovClaims) and (GResearchKind = SourceKindCulture) then
    LPage.Add(Caption(nkLabel, 'result-count', 'Cultural and experiential source collection'))
  else if LRecords.Length > 0 then
    LPage.Add(Caption(nkLabel, 'result-count',
      IntToStr(LOffset + 1) + '–' + IntToStr(LOffset + LRecords.Length) +
      ' of ' + IntToStr(LTotal)))
  else
  begin
    if LCanShowAnyTrend then
    begin
      if LTrend = 'eases' then
        LMessage := 'No matching claims point toward easing this symptom.'
      else
        LMessage := 'No matching claims point toward worsening this symptom.';
    end
    else if LCanShowReviewed then
      LMessage := 'No clear direction in the reviewed evidence for this search. You can explore what the studies looked at.'
    else if GView = ovClaims then
      LMessage := 'No matches for these filters. Try a different symptom or clear a filter.'
    else
      LMessage := 'No indexed document contains all of these search terms.';
    LPage.Add(Caption(nkLabel, 'result-message', LMessage));
    if LCanShowAnyTrend then
      LPage.Add(Button('show-any-trend', 'Show any trend', nvSecondary))
    else if LCanShowReviewed then
      LPage.Add(Button('show-reviewed', 'Show reviewed claims', nvSecondary));
  end;

  for LIndex := 0 to LRecords.Length - 1 do
  begin
    LTag := IntToStr(LIndex);
    LRow := TJSObject(LRecords[LIndex]);
    LCard := Section(nkCard, 'match-' + LTag);
    if GView = ovClaims then
    begin
      LCard.Add(ClaimIndicators(LRow, LTag));
      LCard.Add(Caption(nkHeading, 'ingredient-' + LTag, Capitalized(TextOf(LRow, 'ingredient'))));
      LCard.Add(Caption(nkLabel, 'hypothesis-' + LTag, ResearchQuestion(LRow)));
      if TextOf(LRow, 'rationale') <> '' then
        LCard.Add(Caption(nkLabel, 'rationale-' + LTag, TextOf(LRow, 'rationale')))
      else
        LCard.Add(Caption(nkLabel, 'rationale-' + LTag,
          'An open hypothesis awaiting evidence review. Its assigned direction is not a finding.'));
      LCard.Add(Button('inspect-' + LTag, 'See studies and references', nvSecondary));
    end
    else
    begin
      LCard.Add(Caption(nkLabel, 'period-' + LTag, TextOf(LRow, 'period')));
      LPath := TextOf(LRow, 'path');
      if GStaticOracle = nil then
        LCard.Add(Button('open-source-' + LTag, 'Open source' + #10 + LPath, nvSecondary)
          .Configure.AccessibleName('Open source ' + ExtractFileName(LPath)).Done)
      else
        LCard.Add(SourceLink('path-' + LTag, LPath));
    end;
    LPage.Add(LCard);
  end;

  if ((LOffset > 0) or (LNext > LOffset)) and
    ((GView <> ovClaims) or (GResearchKind <> SourceKindCulture)) then
  begin
    LPaging := Section(nkRow, 'result-pagination');
    if LOffset > 0 then
      LPaging.Add(Button('previous-page', 'Previous', nvSecondary));
    if LNext > LOffset then
      LPaging.Add(Button('next-page', 'Next', nvSecondary));
    LPage.Add(LPaging);
  end;

  if (GView = ovClaims) and (GRelatedTerms <> '') then
  begin
    LPage.Add(Caption(nkHeading, 'related-heading', 'Source documents and reported experiences'));
    LPage.Add(Caption(nkLabel, 'related-guidance',
      'Catalog leads include studies, traditional practices and personal reports outside the experiment. Effect filters apply to claim cards; these source leads retain all reported directions.'));
    if TextOf(GArguments, 'symptom') = 'rest tremor severity' then
      LPage.Add(Caption(nkLabel, 'related-tremor-scope',
        'These sources may discuss other tremor types. Check the source for the symptom, diagnosis and what was actually reported.'));
    if GRelatedError <> '' then
      LPage.Add(Caption(nkLabel, 'related-error',
        'Source lookup unavailable: ' + GRelatedError))
    else
    begin
      LRelatedRecords := ItemsOf(GRelatedSources, 'matches');
      if GResearchKind = SourceKindAll then
        LMessage := IntToStr(LRelatedRecords.Length) + ' of ' +
          IntToStr(CountOf(GRelatedSources, 'total')) + ' matching source documents'
      else
        LMessage := IntToStr(LRelatedRecords.Length) + ' source documents on this page';
      LPage.Add(Caption(nkLabel, 'related-count', LMessage));
      if (LRelatedRecords.Length = 0) and (GResearchKind = SourceKindCulture) then
        LPage.Add(Caption(nkLabel, 'culture-empty',
          'No matching cultural account is cataloged here yet. This remains an open collection gap.'));
      for LIndex := 0 to LRelatedRecords.Length - 1 do
      begin
        LTag := 'related-' + IntToStr(LIndex);
        LRow := TJSObject(LRelatedRecords[LIndex]);
        LPath := TextOf(LRow, 'path');
        if IsCulturalSource(LPath) then
        begin
          LCard := Section(nkCard, 'source-cultural-' + LTag);
          LMessage := 'Traditional or experiential account'
        end
        else
        begin
          LCard := Section(nkCard, 'source-study-' + LTag);
          LMessage := 'Catalog source';
        end;
        LCard.Add(Caption(nkBadge, 'source-kind-' + LTag, LMessage));
        LCard.Add(Caption(nkLabel, 'source-period-' + LTag, TextOf(LRow, 'period')));
        if GStaticOracle = nil then
          LCard.Add(Button('open-source-' + LTag, 'Open source' + #10 + LPath, nvSecondary))
        else
          LCard.Add(SourceLink('path-' + LTag, LPath));
        LPage.Add(LCard);
      end;
      LPaging := Section(nkRow, 'source-pagination');
      if GRelatedPage > 0 then
        LPaging.Add(Button('previous-sources', 'Previous sources', nvSecondary));
      if GRelatedNext > 0 then
        LPaging.Add(Button('next-sources', 'Next sources', nvSecondary));
      LPage.Add(LPaging);
      if GResearchKind = SourceKindAll then
        LPage.Add(Button('browse-related-sources', 'Browse all matching source documents', nvSecondary));
    end;
  end;

  PublishResults(LDocument, LPage);
  if AFocus then
    FocusResults;
  if GView = ovClaims then
  begin
    GResultsRenderer.ElementFor('research-kind-all').setAttribute('aria-pressed',
      LowerCase(BoolToStr(GResearchKind = SourceKindAll, True)));
    GResultsRenderer.ElementFor('research-kind-studies').setAttribute('aria-pressed',
      LowerCase(BoolToStr(GResearchKind = SourceKindStudies, True)));
    GResultsRenderer.ElementFor('research-kind-culture').setAttribute('aria-pressed',
      LowerCase(BoolToStr(GResearchKind = SourceKindCulture, True)));
    BindEvent(GResultsRenderer.ElementFor('research-kind-all'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ChangeResearchKind(SourceKindAll);
        Result := True;
      end);
    BindEvent(GResultsRenderer.ElementFor('research-kind-studies'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ChangeResearchKind(SourceKindStudies);
        Result := True;
      end);
    BindEvent(GResultsRenderer.ElementFor('research-kind-culture'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ChangeResearchKind(SourceKindCulture);
        Result := True;
      end);
  end;
  if (GView = ovClaims) and (GRelatedTerms <> '') and (GRelatedError = '') then
  begin
    if GResearchKind = SourceKindAll then
      BindEvent(GResultsRenderer.ElementFor('browse-related-sources'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        TJSHTMLInputElement(GRenderer.InputFor('terms')).value := GRelatedTerms;
        SwitchView(ovCatalog);
        Query(True, 0);
        Result := True;
      end);
    if GRelatedPage > 0 then
      BindEvent(GResultsRenderer.ElementFor('previous-sources'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          if GRelatedBusy then
            Exit(False);
          Dec(GRelatedPage);
          RefreshRelated(GRelatedOffsets[GRelatedPage]);
          Result := True;
        end);
    if GRelatedNext > 0 then
      BindEvent(GResultsRenderer.ElementFor('next-sources'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          if GRelatedBusy then
            Exit(False);
          Inc(GRelatedPage);
          SetLength(GRelatedOffsets, GRelatedPage + 1);
          GRelatedOffsets[GRelatedPage] := GRelatedNext;
          RefreshRelated(GRelatedNext);
          Result := True;
        end);
    if GStaticOracle = nil then
      for LIndex := 0 to LRelatedRecords.Length - 1 do
        BindSource('related-' + IntToStr(LIndex),
          TextOf(TJSObject(LRelatedRecords[LIndex]), 'path'));
  end;
  if LCanShowAnyTrend then
    BindEvent(GResultsRenderer.ElementFor('show-any-trend'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        SelectTrend('');
        Query(True, 0);
        Result := True;
      end);
  if LCanShowReviewed then
    BindEvent(GResultsRenderer.ElementFor('show-reviewed'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        GArguments['scope'] := 'assessed';
        TJSHTMLSelectElement(GRenderer.InputFor('scope')).selectedIndex := 1;
        UpdateFilterCount;
        Query(False, 0);
        Result := True;
      end);
  for LIndex := 0 to LRecords.Length - 1 do
  begin
    LRow := TJSObject(LRecords[LIndex]);
    if GView = ovClaims then
      BindDetail(IntToStr(LIndex), CountOf(LRow, 'round'), TextOf(LRow, 'claim_id'));
    if (GView = ovCatalog) and (GStaticOracle = nil) then
      BindSource(IntToStr(LIndex), TextOf(LRow, 'path'));
  end;
  if (LOffset > 0) and
    ((GView <> ovClaims) or (GResearchKind <> SourceKindCulture)) then
    BindEvent(GResultsRenderer.ElementFor('previous-page'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Query(False, LOffset - CPageSize);
        Result := True;
      end);
  if (LNext > LOffset) and
    ((GView <> ovClaims) or (GResearchKind <> SourceKindCulture)) then
    BindEvent(GResultsRenderer.ElementFor('next-page'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Query(False, LNext);
        Result := True;
      end);
end;

procedure MaybeSet(AObject: TJSObject; const AKey, AText: String);
begin
  if AText <> '' then
    AObject[AKey] := AText;
end;

procedure Query(ANewQuery: Boolean; AOffset: Integer);
var
  LTool: String;
  LSequence: Integer;
  LValue: String;
begin
  Inc(GSequence);
  LSequence := GSequence;
  if ANewQuery then
  begin
    GArguments := TJSObject.new;
    if GView = ovClaims then
    begin
      if not GSymptom.ReadValue(LValue) then
        Exit;
      MaybeSet(GArguments, 'symptom', LValue);
      if not GIngredient.ReadValue(LValue) then
        Exit;
      MaybeSet(GArguments, 'ingredient', LValue);
      if not GPreparation.ReadValue(LValue) then
        Exit;
      MaybeSet(GArguments, 'preparation', LValue);
      if (TextOf(GArguments, 'symptom') = '') and (TextOf(GArguments, 'ingredient') = '') and
        (TextOf(GArguments, 'preparation') = '') then
      begin
        MessageView('Choose where to start', 'Choose a symptom or an ingredient to look up.');
        GSymptom.Input.focus;
        Exit;
      end;
      case SelectedIndex('scope') of
        1: GArguments['scope'] := 'assessed';
        2: GArguments['scope'] := 'frozen';
      end;
      case SelectedIndex('direction') of
        1: GArguments['direction'] := 'reduces';
        2: GArguments['direction'] := 'worsens';
      end;
      MaybeSet(GArguments, 'trend', GTrend);
    end
    else
    begin
      if InputValue('terms') = '' then
      begin
        MessageView('Catalog search', 'Enter at least one search word.');
        GRenderer.InputFor('terms').focus;
        Exit;
      end;
      GArguments['terms'] := InputValue('terms');
      MaybeSet(GArguments, 'period', InputValue('period'));
    end;
  end;
  HideSuggestions;
  GArguments['offset'] := AOffset;
  GArguments['limit'] := CPageSize;
  if GView = ovClaims then
    LTool := 'oracle_query'
  else
    LTool := 'oracle_search_catalog';
  MessageView('Searching…', 'Checking the research catalog.');
  Request(LTool, GArguments,
    procedure(AData: TJSObject; const AError: String)
    begin
      if LSequence <> GSequence then
        Exit;
      if AError <> '' then
      begin
        MessageView('Search unavailable', AError);
        Exit;
      end;
      GResults := AData;
      GRelatedSources := nil;
      GRelatedTerms := '';
      GRelatedError := '';
      GRelatedNext := 0;
      SetLength(GRelatedOffsets, 1);
      GRelatedOffsets[0] := 0;
      GRelatedPage := 0;
      if GView = ovClaims then
      begin
        GRelatedTerms := RelatedCatalogTerms;
        if GRelatedTerms <> '' then
        begin
          GRelatedBusy := True;
          LoadRelatedSources(0,
            procedure(ASources: TJSObject; const ASourceError: String)
            begin
              if LSequence <> GSequence then
                Exit;
              GRelatedBusy := False;
              GRelatedSources := ASources;
              GRelatedError := ASourceError;
              GRelatedNext := CountOf(ASources, 'next_offset');
              ShowList(GResults);
            end);
          Exit;
        end;
      end;
      ShowList(GResults);
    end);
end;

procedure SwitchView(AView: TOracleView);
begin
  Inc(GSequence);
  GView := AView;
  HideSuggestions;
  SetPressed('claims-tab', AView = ovClaims);
  SetPressed('catalog-tab', AView = ovCatalog);
  if AView = ovClaims then
  begin
    GRenderer.ElementFor('catalog-form').setAttribute('hidden', '');
    GRenderer.ElementFor('claim-form').removeAttribute('hidden');
    MessageView('Start with a symptom', 'Try Tremors, Constipation, or another symptom to see what researchers have found.');
  end
  else
  begin
    GRenderer.ElementFor('claim-form').setAttribute('hidden', '');
    GRenderer.ElementFor('catalog-form').removeAttribute('hidden');
    MessageView('Catalog results', 'Enter terms to find relevant documents in the research catalog.');
  end;
end;

function SubmitOnEnter(AEvent: TEventListenerEvent): Boolean;
begin
  if TJSKeyboardEvent(AEvent).key = 'Enter' then
  begin
    AEvent.preventDefault;
    Query(True, 0);
  end;
  Result := True;
end;

procedure LoadStatus;
begin
  Request('oracle_status', TJSObject.new,
    procedure(AData: TJSObject; const AError: String)
    var
      LClaims: TJSObject;
      LCatalog: TJSObject;
      LStatus: String;
    begin
      if AError <> '' then
        LStatus := 'Catalog status unavailable'
      else
      begin
        LClaims := TJSObject(AData['claims']);
        LCatalog := TJSObject(AData['catalog']);
        LStatus := TextOf(LClaims, 'frozen_claims') + ' research questions';
        if TextOf(LCatalog, 'ready') = 'true' then
          LStatus := LStatus + ' · ' + TextOf(LCatalog, 'indexed') + ' indexed files'
        else if TextOf(LCatalog, 'error') <> '' then
          LStatus := LStatus + ' · Catalog status unavailable'
        else
          LStatus := LStatus + ' · Catalog awaiting refresh';
        if CountOf(LCatalog, 'read_errors') > 0 then
          LStatus := LStatus + ' · ' + TextOf(LCatalog, 'read_errors') + ' unreadable files';
      end;
      GRenderer.Root.Find('index-status').Configure.Text(LStatus);
      GRenderer.ElementFor('index-status').textContent := LStatus;
    end);
end;

procedure Mount;
var
  LPage: TNyxNode;
  LHeader: TNyxNode;
  LWorkspace: TNyxNode;
  LControls: TNyxNode;
  LTabs: TNyxNode;
  LClaims: TNyxNode;
  LCatalog: TNyxNode;
  LQuick: TNyxNode;
  LTrendOptions: TNyxNode;
  LFilters: TNyxNode;
  LHelp: TNyxNode;
  LIndex: Integer;
  LInputId: String;
begin
  GDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'oracle-page');
  GDocument.AddPage(LPage);

  LHeader := Section(nkRow, 'masthead');
  LHeader.Add(Caption(nkHeading, 'brand', 'Parkinson’s Oracle'));
  LHeader.Add(Caption(nkLabel, 'index-status', 'Loading the research catalog…'));
  LPage.Add(LHeader);

  LWorkspace := Section(nkGrid, 'workspace');
  LControls := Section(nkPanel, 'reader-controls');
  LControls.Add(Caption(nkHeading, 'filters-heading', 'Find Parkinson’s research'));
  LTabs := Section(nkRow, 'lookup-tabs');
  LTabs.Add(Button('claims-tab', 'By symptom', nvSecondary));
  LTabs.Add(Button('catalog-tab', 'Search sources', nvSecondary));
  LControls.Add(LTabs);

  LClaims := Section(nkColumn, 'claim-form');
  LClaims.Add(Caption(nkLabel, 'guidance',
    'Pick a symptom. Results include findings, unresolved evidence and questions awaiting review.'));
  LClaims.Add(CreatePickerField('symptom', 'Symptom', 'Try typing trem'));
  LQuick := Section(nkRow, 'quick-symptoms');
  for LIndex := Low(CQuickSymptoms) to High(CQuickSymptoms) do
    LQuick.Add(Button('quick-' + IntToStr(LIndex), FriendlySymptom(CQuickSymptoms[LIndex]),
      nvSecondary));
  LClaims.Add(LQuick);
  LClaims.Add(Button('browse-symptoms', 'Browse all symptoms', nvSecondary));
  LClaims.Add(Caption(nkLabel, 'trend-label', 'Symptom effect'));
  LTrendOptions := Section(nkRow, 'trend-options').Configure
    .AccessibleName('Symptom effect').Done;
  LTrendOptions.Add(Button('trend-any', 'Any trend', nvSecondary));
  LTrendOptions.Add(Button('trend-eases', '↓ May ease', nvSecondary));
  LTrendOptions.Add(Button('trend-worsens', '↑ May worsen', nvSecondary));
  LClaims.Add(LTrendOptions);
  LClaims.Add(Button('show-filters', 'More filters', nvSecondary));
  LFilters := Section(nkColumn, 'extra-filters');
  LFilters.Add(CreatePickerField('ingredient', 'Food or ingredient', 'Any ingredient'));
  LFilters.Add(CreatePickerField('preparation', 'Preparation', 'Any preparation'));
  LFilters.Add(SelectField('scope', 'Which claims to show',
    'Directional findings only'#10'All reviewed claims'#10'All findings and open questions'));
  LFilters.Add(SelectField('direction', 'Claim being tested', 'Any direction'#10'Could reduce'#10'Could worsen'));
  LClaims.Add(LFilters);
  LClaims.Add(Button('search-claims', 'Find research', nvPrimary));
  LControls.Add(LClaims);

  LCatalog := Section(nkColumn, 'catalog-form');
  LCatalog.Add(Field('terms', 'Search terms', 'e.g. black tea tremor'));
  LCatalog.Add(Field('period', 'Period', 'Any period (e.g. 2010-2014)'));
  LCatalog.Add(Button('search-catalog', 'Search catalog', nvPrimary));
  LControls.Add(LCatalog);
  LControls.Add(Button('show-evidence-guide', 'How to read the results', nvSecondary));
  LHelp := Section(nkColumn, 'evidence-guide');
  LHelp.Add(Caption(nkLabel, 'guide-question',
    'Each result starts with a question the research team is investigating.'));
  LHelp.Add(Caption(nkLabel, 'guide-direction',
    'A down arrow means the evidence points toward easing the symptom. An up arrow points toward worsening it.'));
  LHelp.Add(Caption(nkLabel, 'guide-limited',
    'Limited evidence means the findings lean one way. The studies may have tested a different preparation, symptom, or group of people.'));
  LHelp.Add(Caption(nkLabel, 'guide-unclear',
    'Still unclear means the available findings leave the question open. See the studies for what was measured and what still needs review.'));
  LHelp.Add(Caption(nkLabel, 'guide-traditional',
    'Traditional practices and personal reports are collected separately and carry lower evidential weight for treatment effects than controlled studies. A documented account is not proof of benefit.'));
  LHelp.Add(Caption(nkLabel, 'guide-shared',
    'Use the studies to prepare questions for your care team.'));
  LControls.Add(LHelp);
  LWorkspace.Add(LControls);
  LWorkspace.Add(Section(nkPanel, 'results-frame'));
  LPage.Add(LWorkspace);

  GRenderer := TNyxBrowserRenderer.Create;
  GResultsRenderer := TNyxBrowserRenderer.Create;
  GRenderer.Render(GDocument, LPage, TJSHTMLElement(document.getElementById('oracle')));
  GRenderer.ElementFor('brand').setAttribute('aria-level', '1');
  GRenderer.ElementFor('results-frame').setAttribute('aria-live', 'polite');
  GSymptom := TOraclePicker.Create(GRenderer, 'symptom', @SymptomChanged, @SubmitLookup);
  GIngredient := TOraclePicker.Create(GRenderer, 'ingredient', @IngredientChanged, @SubmitLookup);
  GPreparation := TOraclePicker.Create(GRenderer, 'preparation', @UpdateFilterCount, @SubmitLookup);
  GSymptom.BindBrowse(GRenderer.ElementFor('browse-symptoms'));
  for LIndex := Low(CQuickSymptoms) to High(CQuickSymptoms) do
    BindQuickSymptom('quick-' + IntToStr(LIndex), CQuickSymptoms[LIndex]);
  SymptomChanged;
  GRenderer.ElementFor('trend-options').setAttribute('role', 'group');
  BindTrend('trend-any', '');
  BindTrend('trend-eases', 'eases');
  BindTrend('trend-worsens', 'worsens');
  SelectTrend('');
  TJSHTMLSelectElement(GRenderer.InputFor('scope')).selectedIndex := 2;
  GRenderer.ElementFor('extra-filters').id := 'extra-filters';
  GRenderer.ElementFor('extra-filters').setAttribute('hidden', '');
  GRenderer.ElementFor('show-filters').setAttribute('aria-controls', 'extra-filters');
  GRenderer.ElementFor('show-filters').setAttribute('aria-expanded', 'false');
  GRenderer.ElementFor('evidence-guide').id := 'evidence-guide';
  GRenderer.ElementFor('evidence-guide').setAttribute('hidden', '');
  GRenderer.ElementFor('show-evidence-guide').setAttribute('aria-controls', 'evidence-guide');
  GRenderer.ElementFor('show-evidence-guide').setAttribute('aria-expanded', 'false');
  BindEvent(GRenderer.ElementFor('show-filters'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      TogglePanel('show-filters', 'extra-filters', 'More filters', 'Fewer filters');
      UpdateFilterCount;
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('show-evidence-guide'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      TogglePanel('show-evidence-guide', 'evidence-guide', 'How to read the results', 'Hide result guide');
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('extra-filters'), 'change',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      UpdateFilterCount;
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('claims-tab'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      SwitchView(ovClaims);
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('catalog-tab'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      SwitchView(ovCatalog);
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('search-claims'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Query(True, 0);
      Result := True;
    end);
  BindEvent(GRenderer.ElementFor('search-catalog'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Query(True, 0);
      Result := True;
    end);
  for LInputId in CTextInputs do
    BindEvent(GRenderer.InputFor(LInputId), 'keydown', @SubmitOnEnter);
  SwitchView(ovClaims);
  LoadFilterOptions;
  LoadStatus;
end;

procedure Start;
var
  LModel: TJSElement;
begin
  LModel := document.querySelector('meta[name="oracle-revision"]');
  if LModel <> nil then
    GStaticOracle := TStaticOracle.Create(LModel.getAttribute('content'));
  Mount;
end;

begin
  Start;
end.
