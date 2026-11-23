{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleWeb;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, StrUtils, Types, JS, Web, nyx.model, nyx.types, nyx.render.browser, oraclevocab,
  oraclestatic, parkinsonsoracle.trend, parkinsonsoracle.presentation,
  parkinsonsoracle.selection, parkinsonsoracle.graph, oraclemulti, oraclegraph,
  oraclegraphmodel, oraclegallery;

type
  TOracleView = (ovClaims, ovCatalog);
  TSourceOffsets = array of Integer;
  TLocalSourceAction = reference to procedure(const APath: String);

const
  CPageSize = 8;
  CSourceURLPattern = 'https?://[^\s<>\[\]{}"''\x60]+';
  CSourceLinkPattern = '\[([^\]\r\n]+)\]\(([^)\s\r\n]+)\)|(https?://[^\s<>\[\]{}"''\x60]+)';
  CCatalogKindValues: array[0..7] of String = ('', 'source_text', 'cultural', 'conversations',
    'traditional_practices', 'ceremonial_accounts', 'personal_reports', 'local_knowledge');
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
  GClaimUnion: TJSObject;
  GSourceUnion: TOracleSourceUnion;
  GRelatedRenderer: TNyxBrowserRenderer;
  GRelatedDocument: TNyxDocument;
  GRelatedHost: TJSHTMLElement;
  GRelatedSequence: Integer;
  GRelatedGroups: TStringValues;
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
  GGraph: TOracleGraphExplorer;
  GGraphModel: TOracleGraphModel;
  GGraphStack: array of TOracleGraphExplorer;
  GMainRequest: TJSXMLHttpRequest;
  GRelatedRequest: TJSXMLHttpRequest;
  GMainGeneration: Integer;
  GRelatedGeneration: Integer;
  GStatusLoaded: Boolean;
  GStatusLoading: Boolean;

function JSValueText(AValue: JSValue): String; external name 'String';
function OpenWindow(const AURL, ATarget, AFeatures: String): TJSWindow; external name 'window.open';

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

function SourceLink(const AId, APath: String; const ALabel: String = ''): TNyxNode;
var
  LURL: String;
  LLabel: String;
begin
  LLabel := ALabel;
  if LLabel = '' then
    LLabel := 'Read source' + #10 + APath;
  if GStaticOracle <> nil then
  begin
    LURL := GStaticOracle.ReferenceURL(APath);
    if LURL <> '' then
      Exit(Section(nkLink, AId).Configure.Text(LLabel).LinkTo(LURL).Done);
    Exit(Caption(nkCode, AId, APath));
  end;
  Result := Section(nkButton, AId).Configure.Text(LLabel)
    .AccessibleName('Open source ' + APath).Variant(nvSecondary).Done;
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

procedure SetExternalLink(const ANodeId: String);
var
  LLink: TJSHTMLElement;
begin
  LLink := TJSHTMLElement(GRenderer.ElementFor('results-frame').querySelector(
    'a[data-node="' + ANodeId + '"]'));
  if LLink <> nil then
  begin
    LLink.setAttribute('target', '_blank');
    LLink.setAttribute('rel', 'noopener');
  end;
end;

procedure LoadStatus; forward;

procedure CancelRequest(var ARequest: TJSXMLHttpRequest);
var
  LPrior: TJSXMLHttpRequest;
begin
  if ARequest <> nil then
  begin
    LPrior := ARequest;
    ARequest := nil;
    try
      LPrior.onabort := nil;
      LPrior.onerror := nil;
      LPrior.ontimeout := nil;
      LPrior.onload := nil;
      LPrior.abort;
    except
    end;
  end;
end;

procedure CancelMainRequest;
begin
  Inc(GMainGeneration);
  CancelRequest(GMainRequest);
end;

procedure CancelRelatedRequest;
begin
  Inc(GRelatedGeneration);
  CancelRequest(GRelatedRequest);
end;

procedure RequestLocal(const ABody: String; AReply: TOracleReply; ACanRetry,
  AFastTimeout: Boolean; AChannel: Integer = 0);
var
  LRequest: TJSXMLHttpRequest;
  LCompleted: Boolean;
  LGeneration: Integer;

  procedure ReleaseSlot;
  begin
    if (AChannel = 1) and (GMainRequest = LRequest) then
      GMainRequest := nil
    else if (AChannel = 2) and (GRelatedRequest = LRequest) then
      GRelatedRequest := nil;
  end;

  function ChannelActive: Boolean;
  begin
    if AChannel = 1 then
      Result := LGeneration = GMainGeneration
    else if AChannel = 2 then
      Result := LGeneration = GRelatedGeneration
    else
      Result := True;
  end;

  procedure Fail(const AError: String; ATransient: Boolean);
  begin
    if LCompleted then
      Exit;
    LCompleted := True;
    ReleaseSlot;
    if ATransient and ACanRetry and ChannelActive then
    begin
      window.setTimeout(
        procedure
        begin
          if ChannelActive then
            RequestLocal(ABody, AReply, False, AFastTimeout, AChannel);
        end, 500);
    end
    else if ChannelActive then
      AReply(nil, AError);
  end;

  function ConnectionFailed(AEvent: TJSProgressEvent): Boolean;
  begin
    Fail('The connection was interrupted. Please try again.', True);
    Result := False;
  end;

begin
  LCompleted := False;
  LGeneration := 0;
  if AChannel = 1 then
  begin
    CancelMainRequest;
    LGeneration := GMainGeneration;
  end
  else if AChannel = 2 then
  begin
    CancelRelatedRequest;
    LGeneration := GRelatedGeneration;
  end;
  LRequest := TJSXMLHttpRequest.new;
  if AChannel = 1 then
    GMainRequest := LRequest
  else if AChannel = 2 then
    GRelatedRequest := LRequest;
  LRequest.onerror := @ConnectionFailed;
  LRequest.onabort := @ConnectionFailed;
  LRequest.ontimeout :=
    function(AEvent: TJSProgressEvent): Boolean
    begin
      Fail('The request took too long. Please try again.', False);
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
      ReleaseSlot;
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
      if (LError = '') and not GStatusLoaded and not GStatusLoading then
        LoadStatus;
      AReply(TJSObject(LValue), LError);
    end;
  try
    LRequest.open('POST', '/api/oracle', True);
    LRequest.setRequestHeader('Content-Type', 'application/json');
    if AFastTimeout then
      LRequest.timeout := 10000
    else
      LRequest.timeout := 20000;
    LRequest.send(ABody);
  except
    Fail('The request could not start. Please try again.', False);
  end;
end;

procedure RequestChannel(const ATool: String; AArguments: TJSObject; AReply: TOracleReply;
  AChannel: Integer);
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
  RequestLocal(TJSJSON.stringify(LBody), AReply, True,
    (ATool = 'oracle_query') or (ATool = 'oracle_read_source') or (ATool = 'oracle_claim'),
    AChannel);
end;

procedure Request(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
var
  LChannel: Integer;
begin
  LChannel := 0;
  if (ATool = 'oracle_claim') or (ATool = 'oracle_read_source') or
    (ATool = 'oracle_ingredient_effects') then
    LChannel := 1;
  RequestChannel(ATool, AArguments, AReply, LChannel);
end;

procedure RequestMain(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
begin
  RequestChannel(ATool, AArguments, AReply, 1);
end;

procedure RequestRelated(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
begin
  RequestChannel(ATool, AArguments, AReply, 2);
end;

procedure PublishResults(ADocument: TNyxDocument; APage: TNyxNode);
var
  LPrior: TNyxDocument;
begin
  if GGraph <> nil then
  begin
    GGraph.Detach;
    GGraph := nil;
  end;
  if GRelatedHost <> nil then
  begin
    GRelatedRenderer.Unmount;
    FreeAndNil(GRelatedDocument);
    GRelatedHost := nil;
  end;
  LPrior := GResultsDocument;
  GResultsRenderer.Render(ADocument, APage, GRenderer.ElementFor('results-frame'));
  GResultsDocument := ADocument;
  LPrior.Free;
end;

procedure MessageView(const ATitle, AMessage: String; ABack: TPickerAction = nil;
  const AActionLabel: String = '‹ Back');
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
begin
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LPage.Add(Caption(nkHeading, 'result-heading', ATitle));
  LPage.Add(Caption(nkLabel, 'result-message', AMessage));
  if Assigned(ABack) then
    LPage.Add(Button('back-results', AActionLabel, nvSecondary));
  PublishResults(LDocument, LPage);
  if Assigned(ABack) then
    BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        Inc(GSequence);
        CancelMainRequest;
        ABack();
        Result := True;
      end);
end;

procedure ShowList(AResults: TJSObject; AFocus: Boolean = True); forward;
procedure Query(ANewQuery: Boolean; AOffset: Integer); forward;
procedure RenderRelated(AFocus: Boolean = False); forward;
procedure SwitchView(AView: TOracleView); forward;
procedure OpenReference(const APath: String; AReturn: TPickerAction); forward;
procedure BindReference(const ANodeId, APath: String; AReturn: TPickerAction); forward;
procedure ShowGraph(AGraph: TOracleGraphExplorer; AReturn: TPickerAction;
  const ASymptoms: TStringValues); forward;
procedure StartGraph(const ASymptoms: TStringValues; const AIngredient: String;
  const AStartNode: String = ''; AReturn: TPickerAction = nil); forward;

procedure ResetRelatedSources;
var
  LSymptoms: TStringValues;
  LSymptom: String;
  LTerms: String;
begin
  LSymptoms := ArgumentSymptoms(GArguments);
  GRelatedGroups := nil;
  for LSymptom in LSymptoms do
    GRelatedGroups := AddSelection(GRelatedGroups,
      RelatedSourceTerms(TextOf(GArguments, 'ingredient'), LSymptom, GResearchKind));
  if Length(LSymptoms) = 0 then
    GRelatedGroups := AddSelection(GRelatedGroups,
      RelatedSourceTerms(TextOf(GArguments, 'ingredient'), '', GResearchKind));
  GRelatedTerms := '';
  for LTerms in GRelatedGroups do
  begin
    if GRelatedTerms <> '' then
      GRelatedTerms := GRelatedTerms + ' or ';
    GRelatedTerms := GRelatedTerms + LTerms;
  end;
  GSourceUnion.Reset(GRelatedGroups, GResearchKind);
end;

procedure RefreshRelated(AOffset: Integer; AFocus: Boolean);
var
  LSequence: Integer;
begin
  Inc(GRelatedSequence);
  LSequence := GRelatedSequence;
  GRelatedBusy := True;
  GSourceUnion.Page(AOffset, CPageSize,
    function: Boolean
    begin
      Result := LSequence = GRelatedSequence;
    end,
    procedure(AData: TJSObject; const AError: String)
    begin
      GRelatedBusy := False;
      GRelatedSources := AData;
      GRelatedError := AError;
      GRelatedNext := CountOf(AData, 'next_offset');
      RenderRelated(AFocus);
    end);
end;
procedure ChangeResearchKind(AKind: Integer);
begin
  GResearchKind := AKind;
  ResetRelatedSources;
  SetLength(GRelatedOffsets, 1);
  GRelatedOffsets[0] := 0;
  GRelatedPage := 0;
  GRelatedSources := nil;
  GRelatedError := '';
  GRelatedNext := 0;
  GRelatedBusy := True;
  ShowList(GResults, False);
  RefreshRelated(0, False);
end;

function EvidenceLabel(const AVerdict: String; const AResearchStatus: String = ''): String;
begin
  case IndexStr(AVerdict, ['True', 'False', 'Maybe True', 'Maybe False', 'Unknown']) of
    0: Result := 'Evidence supports this claim';
    1: Result := 'Evidence weighs against this claim';
    2: Result := 'Limited evidence in favor';
    3: Result := 'Limited evidence against this claim';
    4:
      if AResearchStatus = 'researched' then
        Result := 'Unknown (Researched)'
      else
        Result := 'Still unclear';
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
  LEvidence := EvidenceLabel(LVerdict, TextOf(AClaim, 'research_status'));
  LEffect := '';
  case IndexStr(ClaimTrend(LVerdict, TextOf(AClaim, 'hypothesis_direction')),
    ['eases', 'worsens']) of
    0:
      begin
        LEffect := 'May ease';
        LEffectId := 'effect-relief-';
      end;
    1:
      begin
        LEffect := 'May worsen';
        LEffectId := 'effect-worse-';
      end;
  end;

  Result := Section(nkRow, 'claim-indicators-' + AId);
  if LEffect <> '' then
  begin
    Result.Add(Caption(nkBadge, LEffectId + AId, LEffect));
    if (LVerdict = 'Maybe True') or (LVerdict = 'Maybe False') then
      LEvidence := 'Limited evidence';
  end
  else if LVerdict = 'False' then
  begin
    if TextOf(AClaim, 'hypothesis_direction') = 'worsens' then
      LEffect := 'Worsening challenged'
    else
      LEffect := 'Easing challenged';
    Result.Add(Caption(nkBadge, 'effect-challenged-' + AId, LEffect));
    LEvidence := 'Evidence against the claim';
  end;
  if LEffect = '' then
    Result.Add(Caption(nkBadge, 'grade-unclear-' + AId, LEvidence))
  else
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
  if (GResultsRenderer = nil) or (GResultsRenderer.Root = nil) or
    (GResultsRenderer.Root.Find('result-heading') = nil) then
    Exit;
  LHeading := GResultsRenderer.ElementFor('result-heading');
  LHeading.setAttribute('tabindex', '-1');
  LHeading.focus;
  LHeading.scrollIntoView(True);
end;

procedure TryFocusElement(ARenderer: TNyxBrowserRenderer; const AId: String);
begin
  if (ARenderer <> nil) and (ARenderer.Root <> nil) and (ARenderer.Root.Find(AId) <> nil) then
    ARenderer.ElementFor(AId).focus
  else
    FocusResults;
end;

function TierSummaryLabel(const AVerdict, AConfidence, AResearchStatus: String): String;
var
  LValue: Double;
begin
  if (AVerdict = '') or (AVerdict = 'Unreviewed') then
    Exit('Awaiting review');
  if AVerdict = 'Unknown' then
  begin
    if AResearchStatus = 'researched' then
      Exit('Open evidence (researched)');
    Exit('Open evidence');
  end;
  LValue := StrToFloatDef(AConfidence, 0);
  if LValue >= 75 then
    Exit('Strong clinical consensus');
  if LValue >= 60 then
    Exit('Moderate clinical evidence');
  if LValue >= 55 then
    Exit('Direct clinical signal');
  if LValue >= 51 then
    Exit('Limited clinical link');
  if LValue > 50 then
    Exit('Minimal signal');
  Result := 'Reviewed evidence';
end;

function YesNoLabel(const AValue: String): String;
begin
  if AValue = 'true' then
    Result := 'Yes'
  else
    Result := 'No';
end;

function ScorecardStatusLabel(const AStatus: String): String;
begin
  if AStatus = 'recorded' then
    Result := 'Recorded'
  else if AStatus = 'historical_scorecard' then
    Result := 'Historical scorecard'
  else if AStatus = 'verdict_mismatch' then
    Result := 'Needs scorecard review'
  else if AStatus <> '' then
    Result := Capitalized(AStatus)
  else
    Result := 'Not yet scored';
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

procedure SetMobileFiltersOpen(AOpen: Boolean);
var
  LButton: TJSHTMLElement;
  LBody: TJSHTMLElement;
begin
  if (GRenderer = nil) or (GRenderer.Root = nil) or
    (GRenderer.Root.Find('controls-body') = nil) then
    Exit;
  LButton := GRenderer.ElementFor('mobile-filters-toggle');
  LBody := GRenderer.ElementFor('controls-body');
  if AOpen then
  begin
    LBody.removeAttribute('data-mobile-collapsed');
    LButton.setAttribute('aria-expanded', 'true');
    LButton.textContent := 'Hide search & filters';
  end
  else
  begin
    LBody.setAttribute('data-mobile-collapsed', 'true');
    LButton.setAttribute('aria-expanded', 'false');
    LButton.textContent := 'Edit search & filters';
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
  LCount := Ord((GPreparation.Chosen <> '') or (Trim(GPreparation.Input.value) <> '')) +
    Ord(SelectedIndex('scope') <> 3) + Ord(SelectedIndex('direction') > 0);
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
    SetPressed('quick-' + IntToStr(LIndex), GSymptom.Contains(CQuickSymptoms[LIndex]));
end;

procedure BindQuickSymptom(const ANodeId, AValue: String);
begin
  BindEvent(GRenderer.ElementFor(ANodeId), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      GSymptom.Toggle(AValue);
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

function AssessmentTone(const ARole, ADirection: String): String;
begin
  if ARole = 'opposes' then
    Result := 'challenged'
  else
    Result := GraphAssessmentTrend(ARole, ADirection);
end;

function EvidenceGroup(const ARole: String): Integer;
begin
  if ARole = 'related' then
    Exit(1);
  if ARole = 'pending' then
    Exit(2);
  Result := 0;
end;

function Inspect(ARound: Integer; const AId: String; AReturn: TPickerAction): Boolean;
const
  CEvidenceGroups: array[0..2] of String = ('Evaluated the claim', 'Related studies',
    'Awaiting evidence');
var
  LArgs: TJSObject;
  LSequence: Integer;
  LBack: TPickerAction;
  LRestore: TPickerAction;

  procedure BindStudyConnections(const ATag, AStudy: String);
  begin
    BindEvent(GResultsRenderer.ElementFor('study-connections-' + ATag), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        StartGraph(nil, '', GraphKey('study', AStudy), LRestore);
        Result := True;
      end);
  end;

begin
  Inc(GSequence);
  LSequence := GSequence;
  LBack := AReturn;
  if not Assigned(LBack) then
    LBack := procedure
      begin
        ShowList(GResults);
      end;
  LRestore := procedure
    begin
      Inspect(ARound, AId, LBack);
    end;
  LArgs := TJSObject.new;
  LArgs['round'] := ARound;
  LArgs['id'] := AId;
  MessageView('Loading evidence', 'Reading the published assessment ledger.', LBack, '‹ Cancel');
  Request('oracle_claim', LArgs,
    procedure(AData: TJSObject; const AError: String)
    var
      LDocument: TNyxDocument;
      LPage: TNyxNode;
      LCard: TNyxNode;
      LActions: TNyxNode;
      LGroups: array[0..2] of TNyxNode;
      LCounts: array[0..2] of Integer;
      LGroup: Integer;
      LItems: TJSArray;
      LRow: TJSObject;
      LIndex: Integer;
      LTag: String;
      LRole: String;
      LDirection: String;
      LAuditPanel: TNyxNode;
      LAudit: TJSObject;
      LConfidence: String;
      LResearchStatus: String;
      LScorecardLine: String;
      LQueued: String;
      LOrigPairs: String;
      LSeenRefs: TJSSet;
      LExtraRefs: TJSArray;
      LRefPath: String;
    begin
      if LSequence <> GSequence then
        Exit;
      if AError <> '' then
      begin
        MessageView('Evidence unavailable', AError, LBack);
        Exit;
      end;
      if TextOf(AData, 'found') <> 'true' then
      begin
        MessageView('Claim unavailable', 'The published round does not contain this claim.', LBack);
        Exit;
      end;

      LDocument := TNyxDocument.Create;
      LPage := Section(nkPage, 'result-page');
      LDocument.AddPage(LPage);
      LActions := Section(nkRow, 'detail-actions');
      LActions.Add(Button('back-results', '‹ Back', nvSecondary));
      LActions.Add(Button('open-graph', 'Explore ingredient connections', nvSecondary));
      LPage.Add(LActions);
      LPage.Add(Caption(nkHeading, 'result-heading', Capitalized(TextOf(AData, 'ingredient'))));
      LPage.Add(Caption(nkLabel, 'claim-symptom', FriendlySymptom(TextOf(AData, 'symptom'))));
      LPage.Add(ClaimIndicators(AData, 'detail'));
      AddIngredientGallery(LPage, TextOf(AData, 'ingredient'));
      LPage.Add(Caption(nkLabel, 'claim-question', ResearchQuestion(AData)));
      LConfidence := TextOf(AData, 'confidence');
      LResearchStatus := TextOf(AData, 'research_status');
      LPage.Add(Caption(nkLabel, 'claim-confidence',
        'Evidence tier: ' + TierSummaryLabel(TextOf(AData, 'verdict'), LConfidence, LResearchStatus)));
      LPage.Add(Caption(nkLabel, 'claim-number',
        'Round ' + IntToStr(ARound) + ' · Claim ' + AId));
      LPage.Add(Caption(nkLabel, 'claim-statement-heading', 'Original claim under review'));
      LPage.Add(Caption(nkLabel, 'claim-statement', TextOf(AData, 'statement')));
      if TextOf(AData, 'rationale') <> '' then
        LPage.Add(Caption(nkLabel, 'claim-rationale', TextOf(AData, 'rationale')));

      LPage.Add(Button('claim-audit-toggle', 'Research & audit details', nvSecondary));
      LAuditPanel := Section(nkColumn, 'claim-audit-panel');
      LScorecardLine := 'Scorecard: ' + ScorecardStatusLabel(TextOf(AData, 'scorecard_status'));
      if LConfidence <> '' then
        LScorecardLine := LScorecardLine + ' · Anchor ' + LConfidence + '/100';
      LAuditPanel.Add(Caption(nkLabel, 'audit-scorecard', LScorecardLine));
      if LResearchStatus <> '' then
        LAuditPanel.Add(Caption(nkLabel, 'audit-research-status',
          'Research status: ' + Capitalized(LResearchStatus)));
      if isDefined(AData['research_audit']) and not isNull(AData['research_audit']) then
      begin
        LAudit := TJSObject(AData['research_audit']);
        LAuditPanel.Add(Caption(nkLabel, 'audit-checks',
          'Checks — Lab/clinical: ' + YesNoLabel(TextOf(LAudit, 'lab_clinical_checked')) +
          ' · Cultural/experiential: ' + YesNoLabel(TextOf(LAudit, 'cultural_checked')) +
          ' · Scorecard: ' + YesNoLabel(TextOf(LAudit, 'scorecard_checked'))));
        if TextOf(LAudit, 'last_checked_utc') <> '' then
          LAuditPanel.Add(Caption(nkLabel, 'audit-checked-at',
            'Last verified (UTC): ' + TextOf(LAudit, 'last_checked_utc')));
        if TextOf(LAudit, 'search_basis') <> '' then
          LAuditPanel.Add(Caption(nkLabel, 'audit-search-basis',
            'Search basis: ' + TextOf(LAudit, 'search_basis')));
        if TextOf(LAudit, 'open_gaps') <> '' then
          LAuditPanel.Add(Caption(nkLabel, 'audit-open-gaps',
            'Open gaps: ' + TextOf(LAudit, 'open_gaps')));
      end;
      LQueued := TextOf(AData, 'queued_original_pairs');
      if LQueued <> '' then
      begin
        LOrigPairs := TextOf(AData, 'original_europe_pmc_pairs');
        if LOrigPairs <> '' then
          LAuditPanel.Add(Caption(nkLabel, 'claim-coverage',
            'Europe PMC screening: ' + LOrigPairs + ' original pairs · ' + LQueued + ' still queued'))
        else
          LAuditPanel.Add(Caption(nkLabel, 'claim-coverage',
            LQueued + ' original Europe PMC pairs still queued'));
      end;
      LPage.Add(LAuditPanel);

      LItems := ItemsOf(AData, 'assessments');
      LDirection := TextOf(AData, 'hypothesis_direction');
      LPage.Add(Caption(nkHeading, 'evidence-heading', 'What the studies looked at'));
      if LItems.Length = 0 then
      begin
        if LResearchStatus = 'researched' then
          LPage.Add(Caption(nkLabel, 'result-message',
            'Exhaustive literature and cultural screening found no qualifying study directly evaluating this exact preparation and symptom yet.'))
        else
          LPage.Add(Caption(nkLabel, 'result-message', 'This claim is awaiting study review.'));
      end;
      for LIndex := 0 to LItems.Length - 1 do
      begin
        LGroup := EvidenceGroup(TextOf(TJSObject(LItems[LIndex]), 'role'));
        Inc(LCounts[LGroup]);
      end;
      for LGroup := Low(LGroups) to High(LGroups) do
      begin
        if LCounts[LGroup] = 0 then
          Continue;
        LTag := IntToStr(LGroup);
        LGroups[LGroup] := Section(nkColumn, 'evidence-group-' + LTag);
        LGroups[LGroup].Add(Caption(nkHeading, 'evidence-group-heading-' + LTag,
          CEvidenceGroups[LGroup] + ' · ' + IntToStr(LCounts[LGroup])));
        LPage.Add(LGroups[LGroup]);
      end;
      LSeenRefs := TJSSet.new;
      for LIndex := 0 to LItems.Length - 1 do
      begin
        LRow := TJSObject(LItems[LIndex]);
        LRole := TextOf(LRow, 'role');
        LTag := IntToStr(LIndex);
        LCard := Section(nkCard, 'evidence-' + LTag);
        LCard.Add(Caption(nkBadge, 'role-' + LTag, GraphAssessmentLabel(LRole, LDirection)));
        if TextOf(LRow, 'local_reference') <> '' then
        begin
          LSeenRefs.add(ReferenceFile(TextOf(LRow, 'local_reference')));
          LCard.Add(SourceLink('study-' + LTag, TextOf(LRow, 'local_reference'),
            'Read study reference · ' + TextOf(LRow, 'study')));
        end
        else
          LCard.Add(Caption(nkHeading, 'study-key-' + LTag, TextOf(LRow, 'study')));
        LCard.Add(Caption(nkLabel, 'fit-' + LTag, TextOf(LRow, 'fit')));
        LCard.Add(Caption(nkLabel, 'analysis-' + LTag, TextOf(LRow, 'assessment')));
        LActions := Section(nkRow, 'study-actions-' + LTag);
        if TextOf(LRow, 'study') <> '' then
          LActions.Add(Button('study-connections-' + LTag, 'See study connections', nvSecondary));
        if TextOf(LRow, 'study') <> '' then
          LCard.Add(LActions);
        LGroups[EvidenceGroup(LRole)].Add(LCard);
      end;
      LItems := ItemsOf(AData, 'local_references');
      LExtraRefs := TJSArray.new;
      for LIndex := 0 to LItems.Length - 1 do
      begin
        LRefPath := JSValueText(LItems[LIndex]);
        if not LSeenRefs.has(ReferenceFile(LRefPath)) then
        begin
          LSeenRefs.add(ReferenceFile(LRefPath));
          LExtraRefs.push(LRefPath);
        end;
      end;
      if LExtraRefs.Length > 0 then
      begin
        LPage.Add(Caption(nkHeading, 'citations-heading', 'Additional source references'));
        for LIndex := 0 to LExtraRefs.Length - 1 do
          LPage.Add(SourceLink('citation-' + IntToStr(LIndex), JSValueText(LExtraRefs[LIndex])));
      end;

      PublishResults(LDocument, LPage);
      BindIngredientGallery(GResultsRenderer, TextOf(AData, 'ingredient'));
      GResultsRenderer.ElementFor('claim-audit-panel').id := 'claim-audit-panel';
      GResultsRenderer.ElementFor('claim-audit-panel').setAttribute('hidden', '');
      GResultsRenderer.ElementFor('claim-audit-toggle').setAttribute('aria-controls', 'claim-audit-panel');
      GResultsRenderer.ElementFor('claim-audit-toggle').setAttribute('aria-expanded', 'false');
      BindEvent(GResultsRenderer.ElementFor('claim-audit-toggle'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        var
          LBtn: TJSHTMLElement;
          LPanel: TJSHTMLElement;
        begin
          LBtn := GResultsRenderer.ElementFor('claim-audit-toggle');
          LPanel := GResultsRenderer.ElementFor('claim-audit-panel');
          if LPanel.hasAttribute('hidden') then
          begin
            LPanel.removeAttribute('hidden');
            LBtn.setAttribute('aria-expanded', 'true');
            LBtn.textContent := 'Hide research & audit details';
          end
          else
          begin
            LPanel.setAttribute('hidden', '');
            LBtn.setAttribute('aria-expanded', 'false');
            LBtn.textContent := 'Research & audit details';
          end;
          Result := True;
        end);
      FocusResults;
      BindEvent(GResultsRenderer.ElementFor('open-graph'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        var
          LSymptoms: TStringValues;
        begin
          LSymptoms := nil;
          LSymptoms := AddSelection(LSymptoms, TextOf(AData, 'symptom'));
          StartGraph(LSymptoms, TextOf(AData, 'ingredient'), '', LRestore);
          Result := True;
        end);
      LItems := ItemsOf(AData, 'assessments');
      for LIndex := 0 to LItems.Length - 1 do
      begin
        LRow := TJSObject(LItems[LIndex]);
        if TextOf(LRow, 'study') <> '' then
          BindStudyConnections(IntToStr(LIndex), TextOf(LRow, 'study'));
        if TextOf(LRow, 'local_reference') <> '' then
          if GStaticOracle = nil then
            BindReference('study-' + IntToStr(LIndex), TextOf(LRow, 'local_reference'), LRestore)
          else
            SetExternalLink('study-' + IntToStr(LIndex));
        GResultsRenderer.ElementFor('role-' + IntToStr(LIndex)).setAttribute('data-trend',
          AssessmentTone(TextOf(LRow, 'role'), LDirection));
      end;
      for LIndex := 0 to LExtraRefs.Length - 1 do
        if GStaticOracle = nil then
          BindReference('citation-' + IntToStr(LIndex), JSValueText(LExtraRefs[LIndex]), LRestore)
        else
          SetExternalLink('citation-' + IntToStr(LIndex));
      BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          LBack();
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
      Result := Inspect(ARound, AId,
        procedure
        begin
          ShowList(GResults, False);
          TryFocusElement(GResultsRenderer, 'inspect-' + ATag);
        end);
    end);
end;

function ExternalSourceURL(const AValue: String): String;
var
  LURL: TJSURL;
begin
  Result := '';
  if not StartsText('https://', AValue) and not StartsText('http://', AValue) then
    Exit;
  try
    LURL := TJSURL.new(AValue);
    if (LURL.hostname <> '') and (LURL.username = '') and (LURL.password = '') then
      Result := LURL.href;
  except
    Exit;
  end;
end;

function SourceURLText(const AToken: String): String;
var
  LChar: Char;
  LParens: Integer;
  LLength: Integer;
begin
  LParens := 0;
  for LChar in AToken do
    case LChar of
      '(': Inc(LParens);
      ')': Dec(LParens);
    end;
  LLength := Length(AToken);
  while LLength > 0 do
    case AToken[LLength] of
      '.', ',', ';', ':', '!', '?': Dec(LLength);
      ')':
        if LParens < 0 then
        begin
          Inc(LParens);
          Dec(LLength);
        end
        else
          Break;
    else
      Break;
    end;
  Result := Copy(AToken, 1, LLength);
end;

function OriginalSourceURL(const AText: String): String;
var
  LLine: String;
  LMatch: TStringDynArray;
begin
  Result := '';
  for LLine in SplitString(AText, #10) do
  begin
    if Trim(LLine) = '' then
      Exit;
    if StartsText('Source:', LLine) then
    begin
      LMatch := TJSRegexp.new(CSourceURLPattern, 'i')
        .exec(Trim(Copy(LLine, Length('Source:') + 1, MaxInt)));
      if LMatch <> nil then
        Result := ExternalSourceURL(SourceURLText(LMatch[0]));
      Exit;
    end;
  end;
end;

function ResolveRelativeResearchPath(const ACurrentPath, ATarget: String): String;
var
  LClean: String;
  LHash: Integer;
  LQuery: Integer;
  LParts: TStringDynArray;
  LStack: array of String;
  LStackLen: Integer;
  LPart: String;
  LBaseDir: String;
  LSlash: Integer;
  LIndex: Integer;
  LLower: String;
begin
  Result := '';
  LClean := Trim(StringReplace(ATarget, '\', '/', [rfReplaceAll]));
  LHash := Pos('#', LClean);
  if LHash > 0 then
    LClean := Copy(LClean, 1, LHash - 1);
  LQuery := Pos('?', LClean);
  if LQuery > 0 then
    LClean := Copy(LClean, 1, LQuery - 1);
  if (LClean = '') or StartsText('http://', LClean) or StartsText('https://', LClean) or
    StartsText('mailto:', LClean) or StartsText('javascript:', LClean) or
    (LClean[1] = '/') then
    Exit;
  if StartsStr('research/', LClean) then
    LBaseDir := ''
  else
  begin
    LBaseDir := StringReplace(ACurrentPath, '\', '/', [rfReplaceAll]);
    LSlash := LastDelimiter('/', LBaseDir);
    if LSlash > 0 then
      LBaseDir := Copy(LBaseDir, 1, LSlash)
    else
      LBaseDir := '';
  end;
  LParts := SplitString(LBaseDir + LClean, '/');
  SetLength(LStack, Length(LParts));
  LStackLen := 0;
  for LPart in LParts do
  begin
    if (LPart = '') or (LPart = '.') then
      Continue;
    if LPart = '..' then
    begin
      if LStackLen = 0 then
        Exit;
      Dec(LStackLen);
      Continue;
    end;
    LStack[LStackLen] := LPart;
    Inc(LStackLen);
  end;
  if LStackLen = 0 then
    Exit;
  LClean := '';
  for LIndex := 0 to LStackLen - 1 do
  begin
    if LClean <> '' then
      LClean := LClean + '/';
    LClean := LClean + LStack[LIndex];
  end;
  LLower := LowerCase(LClean);
  if StartsStr('research/', LLower) and
    (EndsStr('.md', LLower) or EndsStr('.txt', LLower) or EndsStr('.tsv', LLower)) then
    Result := LClean;
end;

procedure PopulateSourceLinks(AHost: TJSHTMLElement; const AText, ACurrentPath: String;
  AHasNext: Boolean; AOnOpenLocal: TLocalSourceAction);
var
  LPattern: TJSRegexp;
  LMatch: TStringDynArray;
  LBody: TJSHTMLElement;
  LLink: TJSHTMLAnchorElement;
  LBtn: TJSHTMLElement;
  LStart: Integer;
  LCursor: Integer;
  LMatched: String;
  LLabel: String;
  LTarget: String;
  LURL: String;
  LLocalPath: String;

  procedure AppendLocalButton(const AButtonText, ALocal: String);
  var
    LClick: TJSEventHandler;
  begin
    LBtn := TJSHTMLElement(document.createElement('button'));
    LBtn.setAttribute('type', 'button');
    LBtn.className := 'oracle-inline-source-link';
    LBtn.textContent := AButtonText;
    LBtn.setAttribute('title', 'Open ' + ALocal);
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        AOnOpenLocal(ALocal);
        Result := True;
      end;
    LBtn.addEventListener('click', LClick);
    LBody.appendChild(LBtn);
  end;

begin
  LBody := TJSHTMLElement(document.createElement('pre'));
  LPattern := TJSRegexp.new(CSourceLinkPattern, 'gi');
  LCursor := 1;
  LMatch := LPattern.exec(AText);
  while LMatch <> nil do
  begin
    if AHasNext and (LPattern.lastIndex = Length(AText)) then
      Break;
    LMatched := LMatch[0];
    LStart := LPattern.lastIndex - Length(LMatched) + 1;
    if (Length(LMatch) >= 3) and isDefined(LMatch[1]) and (LMatch[1] <> '') then
    begin
      LLabel := LMatch[1];
      LTarget := LMatch[2];
      LURL := ExternalSourceURL(SourceURLText(LTarget));
      if LURL <> '' then
      begin
        LBody.appendChild(document.createTextNode(Copy(AText, LCursor, LStart - LCursor)));
        LLink := TJSHTMLAnchorElement(document.createElement('a'));
        LLink.href := LURL;
        LLink.textContent := LLabel;
        LLink.target := '_blank';
        LLink.rel := 'noopener noreferrer';
        LBody.appendChild(LLink);
        LCursor := LStart + Length(LMatched);
      end
      else if Assigned(AOnOpenLocal) then
      begin
        LLocalPath := ResolveRelativeResearchPath(ACurrentPath, LTarget);
        if LLocalPath <> '' then
        begin
          LBody.appendChild(document.createTextNode(Copy(AText, LCursor, LStart - LCursor)));
          AppendLocalButton(LLabel, LLocalPath);
          LCursor := LStart + Length(LMatched);
        end;
      end;
    end
    else
    begin
      LLabel := SourceURLText(LMatched);
      LURL := ExternalSourceURL(LLabel);
      if LURL <> '' then
      begin
        LBody.appendChild(document.createTextNode(Copy(AText, LCursor, LStart - LCursor)));
        LLink := TJSHTMLAnchorElement(document.createElement('a'));
        LLink.href := LURL;
        LLink.textContent := LLabel;
        LLink.target := '_blank';
        LLink.rel := 'noopener noreferrer';
        LBody.appendChild(LLink);
        LCursor := LStart + Length(LLabel);
      end;
    end;
    LMatch := LPattern.exec(AText);
  end;
  LBody.appendChild(document.createTextNode(Copy(AText, LCursor, MaxInt)));
  AHost.appendChild(LBody);
end;

procedure OpenSource(const APath: String; const AOffsets: TSourceOffsets; AReturn: TPickerAction;
  const AOriginalURL: String = '');
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
  MessageView('Opening source', 'Reading the indexed research file.', AReturn, '‹ Cancel');
  Request('oracle_read_source', LArgs,
    procedure(AData: TJSObject; const AError: String)
    var
      LDocument: TNyxDocument;
      LPage: TNyxNode;
      LPaging: TNyxNode;
      LNext: Integer;
      LText: String;
      LOriginalURL: String;
      LOriginalCaption: String;
      LHasPrevious: Boolean;
      LHasNext: Boolean;
      LCanExplore: Boolean;
      LRestoreSource: TPickerAction;
    begin
      if LSequence <> GSequence then
        Exit;
      LDocument := TNyxDocument.Create;
      LPage := Section(nkPage, 'result-page');
      LDocument.AddPage(LPage);
      LPage.Add(Button('back-results', '‹ Back', nvSecondary));
      LPage.Add(Caption(nkHeading, 'result-heading', SavedSourceTitle(APath)));
      LPage.Add(Caption(nkCode, 'source-path', APath));
      if IsConversationSource(APath) then
      begin
        LPage.Add(Caption(nkBadge, 'conversation-badge-reader', ConversationSourceLabel));
        LPage.Add(Caption(nkLabel, 'conversation-reader-context',
          'This summary describes experiences shared in a public discussion.'));
      end
      else if IsCulturalSource(APath) then
        LPage.Add(Caption(nkBadge, 'reader-kind-culture',
          'Culture and lived experience · Source document'))
      else
        LPage.Add(Caption(nkBadge, 'reader-kind-study', 'Research source'));
      LNext := CountOf(AData, 'next_offset');
      LHasPrevious := (AError = '') and (Length(AOffsets) > 1);
      LHasNext := (AError = '') and (LNext > LOffset);
      LText := TextOf(AData, 'text');
      LOriginalURL := AOriginalURL;
      if (AError = '') and (LOffset = 0) then
        LOriginalURL := OriginalSourceURL(LText);
      if (AError = '') and (LOriginalURL <> '') then
      begin
        if IsConversationSource(APath) then
          LOriginalCaption := 'Open original discussion'
        else
          LOriginalCaption := 'Open original source';
        LPage.Add(Section(nkLink, 'original-source').Configure
          .Text(LOriginalCaption).LinkTo(LOriginalURL).Done);
      end;
      LCanExplore := (AError = '') and (LText <> '');
      if AError <> '' then
        LPage.Add(Caption(nkLabel, 'result-message', AError))
      else
      begin
        if LHasPrevious or LHasNext then
          LPage.Add(Caption(nkLabel, 'source-part', 'Part ' + IntToStr(Length(AOffsets))));
        if LCanExplore then
          LPage.Add(Button('source-connections', 'Explore source connections', nvSecondary));
        if LText <> '' then
          LPage.Add(Section(nkColumn, 'source-body'))
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
      LRestoreSource := procedure
        begin
          OpenSource(APath, AOffsets, AReturn, LOriginalURL);
        end;
      if LOriginalURL <> '' then
        SetExternalLink('original-source');
      if LCanExplore then
      begin
        PopulateSourceLinks(GResultsRenderer.ElementFor('source-body'), LText, APath, LHasNext,
          procedure(const ALinkedPath: String)
          begin
            OpenReference(ALinkedPath, LRestoreSource);
          end);
        BindEvent(GResultsRenderer.ElementFor('source-connections'), 'click',
          function(AEvent: TEventListenerEvent): Boolean
          begin
            StartGraph(nil, '', GraphKey('source', APath), LRestoreSource);
            Result := True;
          end);
      end;
      BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          AReturn();
          Result := True;
        end);
      if LHasPrevious then
        BindEvent(GResultsRenderer.ElementFor('previous-page'), 'click',
          function(AEvent: TEventListenerEvent): Boolean
          begin
            OpenSource(APath, Copy(AOffsets, 0, Length(AOffsets) - 1), AReturn, LOriginalURL);
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
            OpenSource(APath, LOffsets, AReturn, LOriginalURL);
            Result := True;
          end);
    end);
end;

procedure OpenReference(const APath: String; AReturn: TPickerAction);
var
  LPath: String;
  LURL: String;
  LOffsets: TSourceOffsets;
begin
  if GStaticOracle <> nil then
  begin
    LURL := GStaticOracle.ReferenceURL(APath);
    if LURL = '' then
    begin
      Inc(GSequence);
      MessageView('Source address unavailable', 'This snapshot needs a repository URL to open the source.', AReturn);
    end
    else
      OpenWindow(LURL, '_blank', 'noopener');
    Exit;
  end;
  LPath := ReferenceFile(APath);
  SetLength(LOffsets, 1);
  LOffsets[0] := 0;
  OpenSource(LPath, LOffsets, AReturn);
end;

procedure BindReference(const ANodeId, APath: String; AReturn: TPickerAction);
begin
  BindEvent(GResultsRenderer.ElementFor(ANodeId), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      OpenReference(APath, AReturn);
      Result := True;
    end);
end;

procedure BindSource(ARenderer: TNyxBrowserRenderer; const ATag, APath: String);
begin
  BindEvent(ARenderer.ElementFor('open-source-' + ATag), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      OpenReference(APath,
        procedure
        begin
          ShowList(GResults, False);
          TryFocusElement(ARenderer, 'open-source-' + ATag);
        end);
      Result := True;
    end);
end;

function IngredientSymptomLabels(const ASymptoms: TStringValues): String;
var
  LSymptom: String;
begin
  Result := '';
  for LSymptom in ASymptoms do
  begin
    if Result <> '' then
    begin
      Result := Result + ' · ';
    end;
    Result := Result + FriendlySymptom(LSymptom);
  end;
end;

procedure ShowIngredientEffects(AProfile: TJSObject; ABack: TPickerAction;
  AFocus: Boolean = True); forward;

procedure BindIngredientGalleryAction(const AButton: String; AProfile: TJSObject;
  ABack: TPickerAction);
var
  LButton: TJSHTMLElement;
begin
  LButton := GResultsRenderer.ElementFor(AButton);
  LButton.setAttribute('aria-expanded', LowerCase(BoolToStr(
    TextOf(AProfile, 'expanded_gallery') = AButton, True)));
  BindEvent(LButton, 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TextOf(AProfile, 'expanded_gallery') = AButton then
        AProfile['expanded_gallery'] := ''
      else
        AProfile['expanded_gallery'] := AButton;
      ShowIngredientEffects(AProfile, ABack, False);
      TryFocusElement(GResultsRenderer, AButton);
      Result := True;
    end);
end;

procedure BindIngredientFinding(const AButton, ADescription: String; AFinding,
  AProfile: TJSObject; ABack: TPickerAction);
var
  LButton: TJSHTMLElement;
begin
  LButton := GResultsRenderer.ElementFor(AButton);
  LButton.setAttribute('aria-label', 'See evidence for ' + ADescription);
  BindEvent(LButton, 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Result := Inspect(CountOf(AFinding, 'round'), TextOf(AFinding, 'claim_id'),
        procedure
        begin
          ShowIngredientEffects(AProfile, ABack, False);
          TryFocusElement(GResultsRenderer, AButton);
        end);
    end);
end;

procedure BindIngredientJump(const AKey: String);
begin
  BindEvent(GResultsRenderer.ElementFor('ingredient-jump-' + AKey), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LHeading: TJSHTMLElement;
    begin
      LHeading := GResultsRenderer.ElementFor('ingredient-heading-' + AKey);
      LHeading.setAttribute('tabindex', '-1');
      LHeading.focus;
      LHeading.scrollIntoView;
      Result := True;
    end);
end;

procedure BindOpenIngredientFilter(AProfile: TJSObject; ANames: TJSArray);
var
  LInput: TJSHTMLInputElement;
  LStatus: TJSHTMLElement;
  LHandler: TJSEventHandler;
begin
  LInput := TJSHTMLInputElement(GResultsRenderer.InputFor('ingredient-open-filter'));
  LStatus := GResultsRenderer.ElementFor('ingredient-open-count');
  LStatus.setAttribute('aria-live', 'polite');
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LIndex: Integer;
      LMatches: Integer;
      LNeedle: String;
      LMatchesName: Boolean;
    begin
      LMatches := 0;
      AProfile['open_filter'] := LInput.value;
      LNeedle := LowerCase(Trim(LInput.value));
      for LIndex := 0 to ANames.Length - 1 do
      begin
        LMatchesName := (LNeedle = '') or (Pos(LNeedle, LowerCase(JSValueText(ANames[LIndex]))) > 0);
        GResultsRenderer.ElementFor('ingredient-open-entry-' + IntToStr(LIndex)).hidden :=
          not LMatchesName;
        if LMatchesName then
        begin
          Inc(LMatches);
        end;
      end;
      LStatus.textContent := IntToStr(LMatches) + ' matching ingredients';
      Result := True;
    end;
  LInput.value := TextOf(AProfile, 'open_filter');
  if LInput.value <> '' then
  begin
    LHandler(nil);
  end;
  LInput.addEventListener('input', LHandler);
end;

procedure ShowIngredientEffects(AProfile: TJSObject; ABack: TPickerAction; AFocus: Boolean);
const
  CKeys: array[0..3] of String = ('may_ease', 'may_worsen', 'mixed', 'unresolved');
  CTitles: array[0..3] of String = ('May ease', 'May worsen', 'Mixed effects',
    'No clear direction');
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
  LNav: TNyxNode;
  LSection: TNyxNode;
  LOpenList: TNyxNode;
  LCard: TNyxNode;
  LSignal: TNyxNode;
  LBadges: TNyxNode;
  LGroup: TJSArray;
  LGroupRow: TJSObject;
  LFindings: TJSArray;
  LFinding: TJSObject;
  LButtons: TJSArray;
  LButton: TJSObject;
  LKey: String;
  LTag: String;
  LName: String;
  LSymptom: String;
  LEffect: String;
  LEffectId: String;
  LGrade: String;
  LUnresolved: String;
  LType: Integer;
  LIndex: Integer;
  LSignalIndex: Integer;
  LExpandedIngredient: String;

  procedure AddComparisonGallery(AParent: TNyxNode; const AButton, AName, ACaption: String);
  begin
    AParent.Add(Button(AButton, ACaption, nvSecondary));
    if TextOf(AProfile, 'expanded_gallery') = AButton then
    begin
      LExpandedIngredient := AName;
      AddIngredientGallery(AParent, AName, '-comparison');
    end;
    LButton := TJSObject.new;
    LButton['id'] := AButton;
    LButton['gallery'] := True;
    LButtons.push(LButton);
  end;

  function UnresolvedLabel(AItem: TJSObject): String;
  var
    LSelection: TJSObject;
  begin
    LSelection := TJSObject.new;
    LSelection['symptoms'] := AItem['unresolved_symptoms'];
    Result := IngredientSymptomLabels(ArgumentSymptoms(LSelection));
  end;

begin
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LPage.Add(Button('back-results', '‹ Back', nvSecondary));
  LPage.Add(Caption(nkHeading, 'result-heading', 'Compare ingredients'));
  LPage.Add(Caption(nkLabel, 'ingredient-comparison-symptoms',
    IngredientSymptomLabels(ArgumentSymptoms(AProfile))));
  LPage.Add(Caption(nkLabel, 'ingredient-comparison-intro',
    'Across all ingredients for the selected symptoms.'));
  LButtons := TJSArray.new;
  LNav := Section(nkRow, 'ingredient-comparison-nav');
  for LType := Low(CKeys) to High(CKeys) do
  begin
    LKey := CKeys[LType];
    LGroup := ItemsOf(AProfile, LKey);
    if LGroup.Length > 0 then
    begin
      LNav.Add(Button('ingredient-jump-' + LKey,
        CTitles[LType] + ' (' + IntToStr(LGroup.Length) + ')', nvSecondary));
    end;
  end;
  LPage.Add(LNav);
  LUnresolved := UnresolvedLabel(AProfile);
  if LUnresolved <> '' then
  begin
    LPage.Add(Caption(nkLabel, 'ingredient-comparison-unresolved',
      'No clear direction yet for ' + LowerCase(LUnresolved) + '.'));
  end;
  for LType := Low(CKeys) to High(CKeys) do
  begin
    LKey := CKeys[LType];
    LGroup := ItemsOf(AProfile, LKey);
    if LGroup.Length = 0 then
    begin
      Continue;
    end;
    LSection := Section(nkColumn, 'ingredient-group-' + LKey);
    LSection.Add(Caption(nkHeading, 'ingredient-heading-' + LKey, CTitles[LType]));
    if LKey = 'unresolved' then
    begin
      LSection.Add(Caption(nkLabel, 'ingredient-open-explanation',
        'For these ingredients, the selected symptoms are currently Unknown (Researched) or awaiting review.'));
      LSection.Add(Field('ingredient-open-filter', 'Find an ingredient', 'Type its name'));
      LSection.Add(Caption(nkLabel, 'ingredient-open-count',
        IntToStr(LGroup.Length) + ' ingredients'));
      LOpenList := Section(nkColumn, 'ingredient-open-list');
      for LIndex := 0 to LGroup.Length - 1 do
      begin
        LName := JSValueText(LGroup[LIndex]);
        LTag := IntToStr(LIndex);
        LCard := Section(nkColumn, 'ingredient-open-entry-' + LTag);
        if HasIngredientGallery(LName) then
        begin
          AddComparisonGallery(LCard, 'ingredient-photos-unresolved-' + LTag,
            LName, Capitalized(LName));
        end
        else
        begin
          LCard.Add(Caption(nkLabel, 'ingredient-open-name-' + LTag, Capitalized(LName)));
        end;
        LOpenList.Add(LCard);
      end;
      LSection.Add(LOpenList);
      LPage.Add(LSection);
      Continue;
    end;
    if LKey = 'mixed' then
    begin
      LSection.Add(Caption(nkLabel, 'ingredient-mixed-explanation',
        'These ingredients have both easing and worsening findings across the selected symptoms.'));
    end;
    for LIndex := 0 to LGroup.Length - 1 do
    begin
      LGroupRow := TJSObject(LGroup[LIndex]);
      LTag := LKey + '-' + IntToStr(LIndex);
      LName := Capitalized(TextOf(LGroupRow, 'ingredient'));
      LCard := Section(nkCard, 'ingredient-card-' + LTag);
      LCard.Add(Caption(nkHeading, 'ingredient-name-' + LTag, LName));
      if HasIngredientGallery(TextOf(LGroupRow, 'ingredient')) then
      begin
        AddComparisonGallery(LCard, 'ingredient-photos-' + LTag,
          TextOf(LGroupRow, 'ingredient'), 'Photos & tips');
      end;
      LFindings := ItemsOf(LGroupRow, 'findings');
      for LSignalIndex := 0 to LFindings.Length - 1 do
      begin
        LFinding := TJSObject(LFindings[LSignalIndex]);
        LTag := LKey + '-' + IntToStr(LIndex) + '-' + IntToStr(LSignalIndex);
        LSignal := Section(nkColumn, 'ingredient-finding-' + LTag);
        LSymptom := FriendlySymptom(TextOf(LFinding, 'symptom'));
        LSignal.Add(Caption(nkLabel, 'ingredient-preparation-' + LTag,
          LSymptom + ' · ' + Capitalized(TextOf(LFinding, 'preparation'))));
        LEffect := 'May ease';
        LEffectId := 'effect-relief-';
        if TextOf(LFinding, 'trend') = 'worsens' then
        begin
          LEffect := 'May worsen';
          LEffectId := 'effect-worse-';
        end;
        LGrade := 'Evidence supports this direction';
        if StartsStr('Maybe ', TextOf(LFinding, 'verdict')) then
        begin
          LGrade := 'Limited evidence';
        end;
        LBadges := Section(nkRow, 'claim-indicators-ingredient-' + LTag);
        LBadges.Add(Caption(nkBadge, LEffectId + LTag, LEffect));
        LBadges.Add(Caption(nkBadge, 'grade-' + LTag, LGrade));
        LSignal.Add(LBadges);
        LSignal.Add(Button('ingredient-evidence-' + LTag, 'See evidence', nvSecondary));
        LCard.Add(LSignal);
        LButton := TJSObject.new;
        LButton['id'] := 'ingredient-evidence-' + LTag;
        LButton['description'] := LName + ' and ' + LowerCase(LSymptom);
        LButton['finding'] := LFinding;
        LButtons.push(LButton);
      end;
      LUnresolved := UnresolvedLabel(LGroupRow);
      if LUnresolved <> '' then
      begin
        LCard.Add(Caption(nkLabel, 'ingredient-unresolved-' + LTag,
          'No clear direction for ' + LowerCase(LUnresolved) + '.'));
      end;
      LSection.Add(LCard);
    end;
    LPage.Add(LSection);
  end;
  LPage.Add(Button('back-to-top', '↑ Back to top', nvSecondary));
  PublishResults(LDocument, LPage);
  if LExpandedIngredient <> '' then
    BindIngredientGallery(GResultsRenderer, LExpandedIngredient, '-comparison');
  BindEvent(GResultsRenderer.ElementFor('back-to-top'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      FocusResults;
      Result := True;
    end);
  BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Inc(GSequence);
      ABack();
      Result := True;
    end);
  for LKey in CKeys do
  begin
    if ItemsOf(AProfile, LKey).Length > 0 then
    begin
      BindIngredientJump(LKey);
    end;
  end;
  for LIndex := 0 to LButtons.Length - 1 do
  begin
    LButton := TJSObject(LButtons[LIndex]);
    if TextOf(LButton, 'gallery') = 'true' then
    begin
      BindIngredientGalleryAction(TextOf(LButton, 'id'), AProfile, ABack);
    end
    else
    begin
      BindIngredientFinding(TextOf(LButton, 'id'), TextOf(LButton, 'description'),
        TJSObject(LButton['finding']), AProfile, ABack);
    end;
  end;
  if ItemsOf(AProfile, 'unresolved').Length > 0 then
  begin
    BindOpenIngredientFilter(AProfile, ItemsOf(AProfile, 'unresolved'));
  end;
  if AFocus then
  begin
    FocusResults;
  end;
end;

procedure CompareIngredients(const ASymptoms: TStringValues; ABack: TPickerAction);
var
  LArgs: TJSObject;
  LSelected: TJSArray;
  LSymptom: String;
  LSequence: Integer;
begin
  Inc(GSequence);
  LSequence := GSequence;
  LArgs := TJSObject.new;
  LSelected := TJSArray.new;
  for LSymptom in ASymptoms do
  begin
    LSelected.push(LSymptom);
  end;
  LArgs['symptoms'] := LSelected;
  MessageView('Comparing ingredients', 'Checking the reviewed claims.', ABack);
  Request('oracle_ingredient_effects', LArgs,
    procedure(AData: TJSObject; const AError: String)
    begin
      if LSequence <> GSequence then
      begin
        Exit;
      end;
      if AError <> '' then
      begin
        MessageView('Ingredient comparison unavailable', AError, ABack);
      end
      else
      begin
        ShowIngredientEffects(AData, ABack);
      end;
    end);
end;

procedure ShowGraph(AGraph: TOracleGraphExplorer; AReturn: TPickerAction;
  const ASymptoms: TStringValues);
var
  LSequence: Integer;
  LDocument: TNyxDocument;
  LPage: TNyxNode;
begin
  Inc(GSequence);
  LSequence := GSequence;
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LPage.Add(Button('back-results', '‹ Back', nvSecondary));
  LPage.Add(Caption(nkHeading, 'result-heading', 'Research connections'));
  if Length(ASymptoms) > 0 then
  begin
    LPage.Add(Button('compare-ingredients', 'Compare ingredients', nvSecondary));
  end;
  LPage.Add(Caption(nkLabel, 'graph-scope',
    'Follow recorded links between symptoms, ingredients, studies and sources. Open questions appear alongside findings.'));
  LPage.Add(Caption(nkLabel, 'graph-freshness', 'Checking the model snapshot…'));
  LPage.Add(Section(nkPanel, 'graph-host'));
  PublishResults(LDocument, LPage);
  BindEvent(GResultsRenderer.ElementFor('back-results'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      AReturn();
      Result := True;
    end);
  if Length(ASymptoms) > 0 then
  begin
    BindEvent(GResultsRenderer.ElementFor('compare-ingredients'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        CompareIngredients(ASymptoms,
          procedure
          begin
            ShowGraph(AGraph, AReturn, ASymptoms);
          end);
        Result := True;
      end);
  end;
  GGraph := AGraph;
  GGraph.Attach(GResultsRenderer.ElementFor('graph-host'));
  FocusResults;
  Request('oracle_status', TJSObject.new,
    procedure(AData: TJSObject; const AError: String)
    var
      LMessage: String;
      LRevision: String;
    begin
      if (LSequence <> GSequence) or (GGraph <> AGraph) then
        Exit;
      LRevision := TextOf(AData, 'revision');
      if (LRevision = '') and (AData <> nil) and isDefined(AData['claims']) then
        LRevision := TextOf(TJSObject(AData['claims']), 'revision');
      if AError <> '' then
        LMessage := 'Graph snapshot available; the live revision check is unavailable.'
      else if LRevision = AGraph.Revision then
        LMessage := 'Graph matches the current oracle snapshot.'
      else
        LMessage := 'Newer research is available. Rebuild the graph to include it.';
      GResultsRenderer.ElementFor('graph-freshness').textContent := LMessage;
    end);
end;

procedure ClearGraphHistory;
var
  LGraph: TOracleGraphExplorer;
begin
  GGraph := nil;
  for LGraph in GGraphStack do
    LGraph.Free;
  GGraphStack := nil;
end;

procedure StartGraph(const ASymptoms: TStringValues; const AIngredient: String;
  const AStartNode: String; AReturn: TPickerAction);
var
  LSequence: Integer;
  LGraph: TOracleGraphExplorer;
  LBack: TPickerAction;
  LResume: TPickerAction;

  procedure ReceiveModel(AData: TJSObject; const AError: String);
  begin
    if LSequence <> GSequence then
      Exit;
    if AError <> '' then
    begin
      MessageView('Graph unavailable', AError, LBack);
      Exit;
    end;
    if GGraphModel = nil then
    begin
      if (TextOf(AData, 'schema') <> 'parkinsons-oracle-model-1') or
        not TJSArray.isArray(AData['claims']) then
      begin
        MessageView('Graph unavailable', 'The saved graph has an unsupported format.', LBack);
        Exit;
      end;
      GGraphModel := TOracleGraphModel.Create(AData);
    end;
    LGraph := TOracleGraphExplorer.Create(GGraphModel, ASymptoms, AIngredient,
      procedure(const APath: String)
      begin
        OpenReference(APath, LResume);
      end,
      procedure(ARound: Integer; const AId: String)
      begin
        Inspect(ARound, AId, LResume);
      end, AStartNode);
    SetLength(GGraphStack, Length(GGraphStack) + 1);
    GGraphStack[High(GGraphStack)] := LGraph;
    LResume();
  end;

begin
  Inc(GSequence);
  LSequence := GSequence;
  LBack := procedure
    begin
      Inc(GSequence);
      if LGraph <> nil then
      begin
        GGraph := nil;
        SetLength(GGraphStack, Length(GGraphStack) - 1);
        FreeAndNil(LGraph);
      end;
      if Assigned(AReturn) then
        AReturn()
      else
        ShowList(GResults);
    end;
  LResume := procedure
    begin
      ShowGraph(LGraph, LBack, ASymptoms);
    end;
  MessageView('Opening graph', 'Reading the saved relationships.', LBack);
  if GGraphModel <> nil then
    ReceiveModel(nil, '')
  else if GStaticOracle <> nil then
    GStaticOracle.GraphModel(@ReceiveModel)
  else
    GetOracleAsset('./graph.json', @ReceiveModel);
end;

procedure BindClaimGraph(const ATag, ASymptom, AIngredient: String);
begin
  BindEvent(GResultsRenderer.ElementFor('claim-graph-' + ATag), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LSymptoms: TStringValues;
    begin
      LSymptoms := nil;
      StartGraph(AddSelection(LSymptoms, ASymptom), AIngredient, '',
        procedure
        begin
          ShowList(GResults, False);
          TryFocusElement(GResultsRenderer, 'claim-graph-' + ATag);
        end);
      Result := True;
    end);
end;

function CatalogPreview(const ATag, APath, APeriod: String): TNyxNode;
var
  LURL: String;
  LActions: TNyxNode;
begin
  if IsConversationSource(APath) then
  begin
    Result := Section(nkCard, 'source-conversation-' + ATag);
    Result.Add(Caption(nkBadge, 'conversation-badge-' + ATag, ConversationSourceLabel));
  end
  else if IsCulturalSource(APath) then
  begin
    Result := Section(nkCard, 'source-cultural-' + ATag);
    Result.Add(Caption(nkBadge, 'source-kind-' + ATag, 'Culture & experience'));
  end
  else
  begin
    Result := Section(nkCard, 'source-study-' + ATag);
    Result.Add(Caption(nkBadge, 'source-kind-' + ATag, 'Research source'));
  end;
  Result.Add(Caption(nkHeading, 'source-title-' + ATag, SavedSourceTitle(APath)));
  Result.Add(Caption(nkLabel, 'source-period-' + ATag, APeriod));
  LActions := Section(nkRow, 'source-actions-' + ATag);
  if GStaticOracle = nil then
    LActions.Add(Button('open-source-' + ATag, 'Read source', nvSecondary)
      .Configure.AccessibleName('Read source ' + ExtractFileName(APath)).Done)
  else
  begin
    LURL := GStaticOracle.ReferenceURL(APath);
    if LURL <> '' then
      LActions.Add(Section(nkLink, 'open-source-' + ATag).Configure.Text('Read on GitHub')
        .AccessibleName('Read source ' + ExtractFileName(APath) + ' on GitHub').LinkTo(LURL).Done);
  end;
  LActions.Add(Button('catalog-graph-' + ATag, 'See connections', nvSecondary)
    .Configure.AccessibleName('See connections for ' + ExtractFileName(APath)).Done);
  Result.Add(LActions);
end;

procedure BindCatalogCard(ARenderer: TNyxBrowserRenderer; const ATag, APath: String);
begin
  if GStaticOracle = nil then
    BindSource(ARenderer, ATag, APath)
  else
    SetExternalLink('open-source-' + ATag);
  BindEvent(ARenderer.ElementFor('catalog-graph-' + ATag), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      StartGraph(nil, '', GraphKey('source', ReferenceFile(APath)),
        procedure
        begin
          ShowList(GResults, False);
          TryFocusElement(ARenderer, 'catalog-graph-' + ATag);
        end);
      Result := True;
    end);
end;

function HasClaimSearchTerms(AArguments: TJSObject): Boolean;
begin
  Result := (Length(ArgumentSymptoms(AArguments)) > 0) or
    (TextOf(AArguments, 'ingredient') <> '') or (TextOf(AArguments, 'preparation') <> '');
end;

procedure BindSearchGallery(const ATag, AIngredient: String);
var
  LURL: String;
  LThumb: TJSHTMLElement;
  LPanel: TJSHTMLElement;
  LKey: String;
  LBound: Boolean;
begin
  LURL := IngredientThumbnailURL(AIngredient);
  if LURL = '' then
  begin
    Exit;
  end;
  LKey := '-search-' + ATag;
  LThumb := GResultsRenderer.ElementFor('claim-photo-' + ATag);
  LPanel := GResultsRenderer.ElementFor('ingredient-gallery' + LKey);
  LPanel.hidden := True;
  LPanel.id := 'ingredient-gallery' + LKey;
  LThumb.style.setProperty('background-image', 'url("' + LURL + '")');
  LThumb.setAttribute('aria-controls', LPanel.id);
  LThumb.setAttribute('aria-expanded', 'false');
  LBound := False;
  BindEvent(LThumb, 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      LPanel.hidden := not LPanel.hidden;
      if not LPanel.hidden and not LBound then
      begin
        BindIngredientGallery(GResultsRenderer, AIngredient, LKey, True);
        LBound := True;
      end;
      LThumb.setAttribute('aria-expanded', LowerCase(BoolToStr(not LPanel.hidden, True)));
      Result := True;
    end);
end;

procedure RenderRelated(AFocus: Boolean);
var
  LDocument: TNyxDocument;
  LPrior: TNyxDocument;
  LPage: TNyxNode;
  LPaging: TNyxNode;
  LRelatedRecords: TJSArray;
  LHeading: TJSHTMLElement;
  LRow: TJSObject;
  LMessage: String;
  LTrend: String;
  LIndex: Integer;
  LTag: String;
  LPath: String;
begin
  if GRelatedHost = nil then
    Exit;
  LDocument := TNyxDocument.Create;
  LPage := Section(nkColumn, 'related-content');
  LDocument.AddPage(LPage);
  LRelatedRecords := TJSArray.new;
  LTrend := TextOf(GArguments, 'trend');
  case GResearchKind of
    SourceKindStudies: LMessage := 'Studies and research sources';
    SourceKindCulture: LMessage := 'Cultural accounts and conversations';
  else
    LMessage := 'Related sources';
  end;
  LPage.Add(Caption(nkHeading, 'related-heading', LMessage));
  if LTrend <> '' then
    LPage.Add(Caption(nkLabel, 'related-guidance',
      'The symptom effect filter applies to claims. Related sources can describe any effect.'));
  if HasSelection(ArgumentSymptoms(GArguments), 'rest tremor severity') then
    LPage.Add(Caption(nkLabel, 'related-tremor-scope',
      'These sources may discuss other tremor types. Check the source for the symptom, diagnosis and what was actually reported.'));
  if GRelatedBusy then
    LPage.Add(Caption(nkLabel, 'related-count', 'Looking for related sources…'))
  else if GRelatedError <> '' then
    LPage.Add(Caption(nkLabel, 'related-error',
      'Source lookup unavailable: ' + GRelatedError))
  else
  begin
    LRelatedRecords := ItemsOf(GRelatedSources, 'matches');
    if (GResearchKind = SourceKindAll) and
      (TextOf(GRelatedSources, 'total_is_exact') = 'true') then
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
      LPage.Add(CatalogPreview(LTag, LPath, TextOf(LRow, 'period')));
    end;
    LPaging := Section(nkRow, 'source-pagination');
    if GRelatedPage > 0 then
      LPaging.Add(Button('previous-sources', 'Previous sources', nvSecondary));
    if GRelatedNext > 0 then
      LPaging.Add(Button('next-sources', 'Next sources', nvSecondary));
    LPage.Add(LPaging);
    if (GResearchKind = SourceKindAll) and (Length(GRelatedGroups) = 1) then
      LPage.Add(Button('browse-related-sources', 'Browse all matching source documents', nvSecondary));
  end;
  LPrior := GRelatedDocument;
  GRelatedRenderer.Render(LDocument, LPage, GRelatedHost);
  GRelatedDocument := LDocument;
  LPrior.Free;
  LHeading := GRelatedRenderer.ElementFor('related-heading');
  LHeading.setAttribute('tabindex', '-1');
  if AFocus then
    LHeading.focus;
  if not GRelatedBusy and (GRelatedError = '') then
  begin
    if (GResearchKind = SourceKindAll) and (Length(GRelatedGroups) = 1) then
      BindEvent(GRelatedRenderer.ElementFor('browse-related-sources'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        TJSHTMLInputElement(GRenderer.InputFor('terms')).value := GRelatedTerms;
        TJSHTMLSelectElement(GRenderer.InputFor('catalog-kind')).selectedIndex := 0;
        SwitchView(ovCatalog);
        Query(True, 0);
        Result := True;
      end);
    if GRelatedPage > 0 then
      BindEvent(GRelatedRenderer.ElementFor('previous-sources'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          if GRelatedBusy then
            Exit(False);
          Dec(GRelatedPage);
          RefreshRelated(GRelatedOffsets[GRelatedPage], True);
          Result := True;
        end);
    if GRelatedNext > 0 then
      BindEvent(GRelatedRenderer.ElementFor('next-sources'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          if GRelatedBusy then
            Exit(False);
          Inc(GRelatedPage);
          SetLength(GRelatedOffsets, GRelatedPage + 1);
          GRelatedOffsets[GRelatedPage] := GRelatedNext;
          RefreshRelated(GRelatedNext, True);
          Result := True;
        end);
    for LIndex := 0 to LRelatedRecords.Length - 1 do
      BindCatalogCard(GRelatedRenderer, 'related-' + IntToStr(LIndex),
        TextOf(TJSObject(LRelatedRecords[LIndex]), 'path'));
  end;
end;

procedure ShowList(AResults: TJSObject; AFocus: Boolean);
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
  LRow: TJSObject;
  LCard: TNyxNode;
  LCardActions: TNyxNode;
  LIdentity: TNyxNode;
  LIdentityText: TNyxNode;
  LResultActions: TNyxNode;
  LPaging: TNyxNode;
  LRecords: TJSArray;
  LIndex: Integer;
  LTotal: Integer;
  LOffset: Integer;
  LNext: Integer;
  LTag: String;
  LIngredient: String;
  LPath: String;
  LTrend: String;
  LMessage: String;
  LCanShowReviewed: Boolean;
  LCanShowAnyTrend: Boolean;
  LTrendOnly: Boolean;
  LNoTrendMatches: Boolean;
  LKindTabs: TNyxNode;
  LSymptoms: TStringValues;
begin
  LDocument := TNyxDocument.Create;
  LPage := Section(nkPage, 'result-page');
  LDocument.AddPage(LPage);
  LTrend := TextOf(GArguments, 'trend');
  LTrendOnly := (GView = ovClaims) and (LTrend <> '') and not HasClaimSearchTerms(GArguments);
  LNoTrendMatches := (GView = ovClaims) and (LTrend <> '') and
    (CountOf(AResults, 'total_matches') = 0);
  LCanShowAnyTrend := LNoTrendMatches and not LTrendOnly;
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
    LSymptoms := ArgumentSymptoms(AResults);
    if Length(LSymptoms) = 2 then
      LMessage := 'Research on ' + LowerCase(FriendlySymptom(LSymptoms[0])) + ' or ' +
        LowerCase(FriendlySymptom(LSymptoms[1]))
    else if Length(LSymptoms) > 2 then
      LMessage := 'Research across ' + IntToStr(Length(LSymptoms)) + ' symptoms'
    else if TextOf(AResults, 'symptom') <> '' then
      LMessage := 'Research on ' + LowerCase(FriendlySymptom(TextOf(AResults, 'symptom')))
    else if LTrendOnly then
    begin
      if LTrend = 'eases' then
        LMessage := 'What may ease symptoms'
      else
        LMessage := 'What may worsen symptoms';
    end;
    LPage.Add(Caption(nkHeading, 'result-heading', LMessage));
    if not LTrendOnly then
    begin
      LResultActions := Section(nkRow, 'result-actions');
      if Length(LSymptoms) > 0 then
      begin
        LResultActions.Add(Button('compare-ingredients', 'Compare ingredients', nvSecondary));
      end;
      LResultActions.Add(Button('open-graph', 'Graph view', nvSecondary));
      if (GRelatedTerms <> '') and (GResearchKind <> SourceKindCulture) then
        LResultActions.Add(Button('jump-to-sources', 'Jump to sources', nvSecondary));
      LPage.Add(LResultActions);
      LKindTabs := Section(nkRow, 'research-kind-tabs');
      LKindTabs.Add(Button('research-kind-all', 'All research', nvSecondary)
        .Configure.Pressed(GResearchKind = SourceKindAll).Done);
      LKindTabs.Add(Button('research-kind-studies', 'Studies & analyses', nvSecondary)
        .Configure.Pressed(GResearchKind = SourceKindStudies).Done);
      LKindTabs.Add(Button('research-kind-culture', 'Culture & experience', nvSecondary)
        .Configure.Pressed(GResearchKind = SourceKindCulture).Done);
      LPage.Add(LKindTabs);
    end
    else
    begin
      if LRecords.Length > 0 then
      begin
        LResultActions := Section(nkRow, 'result-actions');
        LResultActions.Add(Button('open-graph', 'Graph view', nvSecondary));
        LPage.Add(LResultActions);
      end;
      LPage.Add(Caption(nkLabel, 'trend-results-guidance',
        'Showing directional findings across all symptoms. Open any card to inspect studies or connections.'));
    end;
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
  if LRecords.Length > 0 then
  begin
    LPage.Add(Caption(nkLabel, 'result-count',
      IntToStr(LOffset + 1) + '–' + IntToStr(LOffset + LRecords.Length) +
      ' of ' + IntToStr(LTotal)));
  end
  else if (GView <> ovClaims) or (GResearchKind <> SourceKindCulture) then
  begin
    if LNoTrendMatches then
    begin
      if LTrend = 'eases' then
        LMessage := 'No matching claims point toward symptom relief.'
      else
        LMessage := 'No matching claims point toward worsening symptoms.';
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
    if GView = ovClaims then
    begin
      LCard := Section(nkCard, 'match-' + LTag);
      LCard.Add(ClaimIndicators(LRow, LTag));
      LIngredient := TextOf(LRow, 'ingredient');
      LIdentity := Section(nkRow, 'claim-identity-' + LTag);
      LIdentityText := Section(nkColumn, 'claim-identity-text-' + LTag);
      LIdentityText.Add(Caption(nkHeading, 'ingredient-' + LTag, Capitalized(LIngredient)));
      if Length(LSymptoms) <> 1 then
        LIdentityText.Add(Caption(nkLabel, 'claim-symptom-' + LTag,
          FriendlySymptom(TextOf(LRow, 'symptom'))));
      LIdentity.Add(LIdentityText);
      if HasIngredientGallery(LIngredient) then
        LIdentity.Add(Button('claim-photo-' + LTag, '', nvSecondary)
          .Configure.AccessibleName('View photos of ' + LIngredient).Done);
      LCard.Add(LIdentity);
      AddIngredientGallery(LCard, LIngredient, '-search-' + LTag);
      LCard.Add(Caption(nkLabel, 'hypothesis-' + LTag, ResearchQuestion(LRow)));
      if TextOf(LRow, 'rationale') <> '' then
        LCard.Add(Caption(nkLabel, 'rationale-' + LTag, TextOf(LRow, 'rationale')));

      LCardActions := Section(nkRow, 'claim-actions-' + LTag);
      LCardActions.Add(Button('inspect-' + LTag, 'Studies & sources', nvSecondary));
      LCardActions.Add(Button('claim-graph-' + LTag, 'Connections', nvSecondary));
      LCard.Add(LCardActions);
    end
    else
    begin
      LPath := TextOf(LRow, 'path');
      LCard := CatalogPreview(LTag, LPath, TextOf(LRow, 'period'));
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
    LPage.Add(Section(nkColumn, 'related-host'));
  if LRecords.Length >= 5 then
    LPage.Add(Button('back-to-top', '↑ Back to top', nvSecondary));
  PublishResults(LDocument, LPage);
  if LRecords.Length >= 5 then
    BindEvent(GResultsRenderer.ElementFor('back-to-top'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        FocusResults;
        Result := True;
      end);
  if (GView = ovClaims) and (GRelatedTerms <> '') then
  begin
    GRelatedHost := GResultsRenderer.ElementFor('related-host');
    RenderRelated;
  end;
  if GView = ovClaims then
    for LIndex := 0 to LRecords.Length - 1 do
      BindSearchGallery(IntToStr(LIndex), TextOf(TJSObject(LRecords[LIndex]), 'ingredient'));
  if (GView = ovClaims) and not LTrendOnly then
  begin
    BindEvent(GResultsRenderer.ElementFor('open-graph'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        StartGraph(ArgumentSymptoms(GResults), TextOf(GArguments, 'ingredient'));
        Result := True;
      end);
    if Length(LSymptoms) > 0 then
    begin
      BindEvent(GResultsRenderer.ElementFor('compare-ingredients'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          CompareIngredients(ArgumentSymptoms(GResults),
            procedure
            begin
              ShowList(GResults, False);
              TryFocusElement(GResultsRenderer, 'compare-ingredients');
            end);
          Result := True;
        end);
    end;
    if (GRelatedTerms <> '') and (GResearchKind <> SourceKindCulture) then
      BindEvent(GResultsRenderer.ElementFor('jump-to-sources'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        var
          LHeading: TJSHTMLElement;
        begin
          LHeading := GRelatedRenderer.ElementFor('related-heading');
          LHeading.focus;
          LHeading.scrollIntoView;
          Result := True;
        end);
  end
  else if (GView = ovClaims) and LTrendOnly and (LRecords.Length > 0) then
  begin
    BindEvent(GResultsRenderer.ElementFor('open-graph'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      var
        LFirst: TJSObject;
        LGraphSymptoms: TStringValues;
      begin
        LFirst := TJSObject(LRecords[0]);
        LGraphSymptoms := nil;
        StartGraph(AddSelection(LGraphSymptoms, TextOf(LFirst, 'symptom')),
          TextOf(LFirst, 'ingredient'));
        Result := True;
      end);
  end;
  if AFocus then
    FocusResults;
  if (GView = ovClaims) and not LTrendOnly then
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
        GClaimUnion := nil;
        TJSHTMLSelectElement(GRenderer.InputFor('scope')).selectedIndex := 1;
        UpdateFilterCount;
        Query(False, 0);
        Result := True;
      end);
  for LIndex := 0 to LRecords.Length - 1 do
  begin
    LRow := TJSObject(LRecords[LIndex]);
    if GView = ovClaims then
    begin
      BindDetail(IntToStr(LIndex), CountOf(LRow, 'round'), TextOf(LRow, 'claim_id'));
      BindClaimGraph(IntToStr(LIndex), TextOf(LRow, 'symptom'), TextOf(LRow, 'ingredient'));
    end;
    if GView = ovCatalog then
      BindCatalogCard(GResultsRenderer, IntToStr(LIndex), TextOf(LRow, 'path'));
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
  LValues: TStringValues;
  LSymptomArray: TJSArray;
  LReceive: TOracleReply;
  LCurrent: TOracleCurrent;
begin
  Inc(GSequence);
  LSequence := GSequence;
  CancelMainRequest;
  if ANewQuery then
  begin
    Inc(GRelatedSequence);
    CancelRelatedRequest;
    GArguments := TJSObject.new;
    GClaimUnion := nil;
    if GView = ovClaims then
    begin
      GResearchKind := SourceKindAll;
      if not GSymptom.ReadValues(LValues) then
        Exit;
      if Length(LValues) = 1 then
        GArguments['symptom'] := LValues[0]
      else if Length(LValues) > 1 then
      begin
        LSymptomArray := TJSArray.new;
        for LValue in LValues do
          LSymptomArray.push(LValue);
        GArguments['symptoms'] := LSymptomArray;
      end;
      if not GIngredient.ReadValue(LValue) then
        Exit;
      MaybeSet(GArguments, 'ingredient', LValue);
      if not GPreparation.ReadValue(LValue) then
        Exit;
      MaybeSet(GArguments, 'preparation', LValue);
      if not HasClaimSearchTerms(GArguments) then
      begin
        if GTrend = '' then
        begin
          MessageView('Choose where to start',
            'Choose a symptom or ingredient, or select May ease or May worsen to search across all symptoms.');
          GSymptom.Input.focus;
          Exit;
        end;
        GResearchKind := SourceKindAll;
      end;
      case SelectedIndex('scope') of
        1: GArguments['scope'] := 'assessed';
        2:
          begin
            GArguments['scope'] := 'assessed';
            GArguments['verdict'] := 'Unknown (Researched)';
          end;
        3: GArguments['scope'] := 'frozen';
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
      if (SelectedIndex('catalog-kind') > 0) and
        (SelectedIndex('catalog-kind') <= High(CCatalogKindValues)) then
        MaybeSet(GArguments, 'source_kind', CCatalogKindValues[SelectedIndex('catalog-kind')]);
    end;
    if window.innerWidth <= 740 then
      SetMobileFiltersOpen(False);
  end;
  HideSuggestions;
  GArguments['offset'] := AOffset;
  GArguments['limit'] := CPageSize;
  if GView = ovClaims then
    LTool := 'oracle_query'
  else
    LTool := 'oracle_search_catalog';
  ClearGraphHistory;
  if GView = ovClaims then
  begin
    if GResults <> nil then
      MessageView('Searching…', 'Looking up ingredient and symptom claims.',
        procedure
        begin
          ShowList(GResults, False);
        end, '‹ Cancel')
    else
      MessageView('Searching…', 'Looking up ingredient and symptom claims.');
  end
  else
  begin
    if GResults <> nil then
      MessageView('Searching…', 'Checking the research catalog.',
        procedure
        begin
          ShowList(GResults, False);
        end, '‹ Cancel')
    else
      MessageView('Searching…', 'Checking the research catalog.');
  end;
  LReceive :=
    procedure(AData: TJSObject; const AError: String)
    begin
      if LSequence <> GSequence then
        Exit;
      if AError <> '' then
      begin
        MessageView('Search unavailable', AError,
          procedure
          begin
            Query(ANewQuery, AOffset);
          end, 'Retry search');
        Exit;
      end;
      GResults := AData;
      if not ANewQuery and (GView = ovClaims) then
      begin
        ShowList(GResults);
        Exit;
      end;
      GRelatedSources := nil;
      GRelatedTerms := '';
      GRelatedError := '';
      GRelatedNext := 0;
      SetLength(GRelatedOffsets, 1);
      GRelatedOffsets[0] := 0;
      GRelatedPage := 0;
      GRelatedBusy := False;
      if GView = ovClaims then
      begin
        ResetRelatedSources;
        GRelatedBusy := GRelatedTerms <> '';
      end;
      ShowList(GResults);
      if GRelatedBusy then
        RefreshRelated(0, False);
    end;
  LCurrent := function: Boolean
    begin
      Result := LSequence = GSequence;
    end;
  if (GView = ovClaims) and (Length(ArgumentSymptoms(GArguments)) > 1) then
  begin
    if GClaimUnion <> nil then
      LReceive(ClaimUnionPage(GClaimUnion, AOffset, CPageSize), '')
    else
      LoadClaimUnion(@RequestMain, GArguments, LCurrent,
        procedure(AData: TJSObject; const AError: String)
        begin
          if not LCurrent() then
            Exit;
          if AError <> '' then
            LReceive(nil, AError)
          else
          begin
            GClaimUnion := AData;
            LReceive(ClaimUnionPage(AData, AOffset, CPageSize), '');
          end;
        end);
  end
  else
    RequestChannel(LTool, GArguments, LReceive, 1);
end;

procedure SwitchView(AView: TOracleView);
begin
  Inc(GSequence);
  Inc(GRelatedSequence);
  CancelMainRequest;
  CancelRelatedRequest;
  GView := AView;
  ClearGraphHistory;
  HideSuggestions;
  SetPressed('claims-tab', AView = ovClaims);
  SetPressed('catalog-tab', AView = ovCatalog);
  if AView = ovClaims then
  begin
    GRenderer.ElementFor('catalog-form').setAttribute('hidden', '');
    GRenderer.ElementFor('claim-form').removeAttribute('hidden');
    MessageView('Explore Parkinson’s research',
      'Choose a symptom, an ingredient, or a symptom effect to explore the research.');
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
  if GStatusLoading then
    Exit;
  GStatusLoading := True;
  Request('oracle_status', TJSObject.new,
    procedure(AData: TJSObject; const AError: String)
    var
      LClaims: TJSObject;
      LCatalog: TJSObject;
      LStatus: String;
    begin
      GStatusLoading := False;
      if AError <> '' then
      begin
        LStatus := 'Catalog status unavailable';
        if not GStatusLoaded then
          window.setTimeout(
            procedure
            begin
              if not GStatusLoaded then
                LoadStatus;
            end, 2500);
      end
      else
      begin
        GStatusLoaded := True;
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
  LControlsBody: TNyxNode;
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
  LControls.Add(Button('mobile-filters-toggle', 'Hide search & filters', nvSecondary));
  LControlsBody := Section(nkColumn, 'controls-body');
  LTabs := Section(nkRow, 'lookup-tabs');
  LTabs.Add(Button('claims-tab', 'Symptoms & foods', nvSecondary));
  LTabs.Add(Button('catalog-tab', 'Search sources', nvSecondary));
  LControlsBody.Add(LTabs);

  LClaims := Section(nkColumn, 'claim-form');
  LClaims.Add(Caption(nkLabel, 'guidance',
    'Choose an ingredient or one or more symptoms. Results can match any selected symptom.'));
  LClaims.Add(CreatePickerField('symptom', 'Symptoms', 'Add a symptom, e.g. trem', True));
  LQuick := Section(nkRow, 'quick-symptoms');
  for LIndex := Low(CQuickSymptoms) to High(CQuickSymptoms) do
    LQuick.Add(Button('quick-' + IntToStr(LIndex), FriendlySymptom(CQuickSymptoms[LIndex]),
      nvSecondary));
  LClaims.Add(LQuick);
  LClaims.Add(Button('browse-symptoms', 'Browse all symptoms', nvSecondary));
  LClaims.Add(CreatePickerField('ingredient', 'Food or ingredient', 'Any ingredient'));
  LClaims.Add(Caption(nkLabel, 'trend-label', 'Symptom effect'));
  LTrendOptions := Section(nkRow, 'trend-options').Configure
    .AccessibleName('Symptom effect').Done;
  LTrendOptions.Add(Button('trend-any', 'Any trend', nvSecondary));
  LTrendOptions.Add(Button('trend-eases', 'May ease', nvSecondary));
  LTrendOptions.Add(Button('trend-worsens', 'May worsen', nvSecondary));
  LClaims.Add(LTrendOptions);
  LClaims.Add(Caption(nkLabel, 'trend-guidance',
    'Leave Symptoms blank and choose May ease or May worsen to search across all symptoms.'));
  LClaims.Add(Button('show-filters', 'More filters', nvSecondary));
  LFilters := Section(nkColumn, 'extra-filters');
  LFilters.Add(CreatePickerField('preparation', 'Preparation', 'Any preparation'));
  LFilters.Add(SelectField('scope', 'Which claims to show',
    'Directional findings only'#10'All reviewed claims'#10'Unknown (Researched) only'#10'All findings and open questions'));
  LFilters.Add(SelectField('direction', 'Claim being tested', 'Any direction'#10'Could reduce'#10'Could worsen'));
  LClaims.Add(LFilters);
  LClaims.Add(Button('search-claims', 'Find research', nvPrimary));
  LControlsBody.Add(LClaims);

  LCatalog := Section(nkColumn, 'catalog-form');
  LCatalog.Add(Field('terms', 'Search terms', 'e.g. black tea tremor'));
  LCatalog.Add(Field('period', 'Period', 'Any period (e.g. 2010-2014)'));
  LCatalog.Add(SelectField('catalog-kind', 'Source type',
    'All catalog sources'#10'Studies & source texts'#10'All culture & experience'#10 +
    'Conversations & forums'#10'Traditional practices'#10'Ceremonial accounts'#10 +
    'Personal reports'#10'Local knowledge'));
  LCatalog.Add(Button('search-catalog', 'Search catalog', nvPrimary));
  LControlsBody.Add(LCatalog);
  LControlsBody.Add(Button('show-evidence-guide', 'How to read the results', nvSecondary));
  LHelp := Section(nkColumn, 'evidence-guide');
  LHelp.Add(Caption(nkLabel, 'guide-question',
    'Each result starts with a question the research team is investigating.'));
  LHelp.Add(Caption(nkLabel, 'guide-direction',
    'A down arrow means the evidence points toward easing the symptom. An up arrow points toward worsening it.'));
  LHelp.Add(Caption(nkLabel, 'guide-challenged',
    'The amber question mark means evidence challenges the effect proposed in the claim. The opposite effect remains uncertain.'));
  LHelp.Add(Caption(nkLabel, 'guide-limited',
    'Limited evidence means the findings lean one way. The studies may have tested a different preparation, symptom, or group of people.'));
  LHelp.Add(Caption(nkLabel, 'guide-unclear',
    'Unknown (Researched) means our team completed lab, clinical, and cultural searches and verified the scorecard, and the evidence still leaves the direction open.'));
  LHelp.Add(Caption(nkLabel, 'guide-awaiting',
    'Awaiting review means the claim is queued in a later round and has not yet been researched.'));
  LHelp.Add(Caption(nkLabel, 'guide-traditional',
    'Traditional practices and personal reports are collected separately and carry lower evidential weight for treatment effects than controlled studies. A documented account is not proof of benefit.'));
  LHelp.Add(Caption(nkLabel, 'guide-shared',
    'Use the studies to prepare questions for your care team.'));
  LControlsBody.Add(LHelp);
  LControls.Add(LControlsBody);
  LWorkspace.Add(LControls);
  LWorkspace.Add(Section(nkPanel, 'results-frame'));
  LPage.Add(LWorkspace);

  GRenderer := TNyxBrowserRenderer.Create;
  GResultsRenderer := TNyxBrowserRenderer.Create;
  GRelatedRenderer := TNyxBrowserRenderer.Create;
  GRenderer.Render(GDocument, LPage, TJSHTMLElement(document.getElementById('oracle')));
  GRenderer.ElementFor('brand').setAttribute('aria-level', '1');
  GRenderer.ElementFor('results-frame').setAttribute('aria-live', 'polite');
  GSourceUnion := TOracleSourceUnion.Create(@RequestRelated);
  GSymptom := TOraclePicker.Create(GRenderer, 'symptom', @SymptomChanged, @SubmitLookup, True);
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
  TJSHTMLSelectElement(GRenderer.InputFor('scope')).selectedIndex := 3;
  GRenderer.ElementFor('controls-body').id := 'controls-body';
  GRenderer.ElementFor('mobile-filters-toggle').setAttribute('aria-controls', 'controls-body');
  GRenderer.ElementFor('mobile-filters-toggle').setAttribute('aria-expanded', 'true');
  BindEvent(GRenderer.ElementFor('mobile-filters-toggle'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      SetMobileFiltersOpen(GRenderer.ElementFor('controls-body').hasAttribute('data-mobile-collapsed'));
      Result := True;
    end);
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
