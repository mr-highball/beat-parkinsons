{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclevocab;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, JS, Web, nyx.model, nyx.types, nyx.render.browser,
  parkinsonsoracle.selection;

type
  TPickerAction = reference to procedure;
  TPickerOption = record
    Value: String;
    LabelText: String;
    Rank: Integer;
  end;
  TPickerOptions = array of TPickerOption;

  TResearchIngredientInfo = record
    InPool: Boolean;
    Canonical: String;
    Trend: String;
    EasesCount: Integer;
    WorsensCount: Integer;
  end;

  TOracleResearchPool = class
  private
    FMap: TJSObject;
    FLoaded: Boolean;
    function TryGet(const AKey: String; out AInfo: TResearchIngredientInfo): Boolean;
  public
    constructor Create;
    procedure LoadFromFilterIngredients(AIngredients: TJSArray);
    function Lookup(const AIngredient: String): TResearchIngredientInfo;
    property Loaded: Boolean read FLoaded;
  end;

  TOraclePicker = class
  private
    FId: String;
    FChosen: String;
    FMultiple: Boolean;
    FValues: TStringValues;
    FSelectedRenderer: TNyxBrowserRenderer;
    FSelectedDocument: TNyxDocument;
    FChoices: TJSArray;
    FRenderer: TNyxBrowserRenderer;
    FDocument: TNyxDocument;
    FInput: TJSHTMLInputElement;
    FSelected: TJSHTMLElement;
    FFormRenderer: TNyxBrowserRenderer;
    FHost: TJSHTMLElement;
    FBrowseButton: TJSHTMLElement;
    FOnChange: TPickerAction;
    FOnSubmit: TPickerAction;
    FBrowsing: Boolean;
    FFirst: TJSHTMLElement;
    FOptionCount: Integer;
    function Matches(const AText: String): TPickerOptions;
    function LabelFor(const AValue: String): String;
    procedure UpdateSuggestions;
    procedure BindSuggestion(const ANodeId: String; const AOption: TPickerOption);
    procedure RenderSelections;
    procedure BindRemoval(const ANodeId, AValue: String);
  public
    constructor Create(ARenderer: TNyxBrowserRenderer; const AId: String;
      AOnChange, AOnSubmit: TPickerAction; AMultiple: Boolean = False);
    procedure SetChoices(AChoices: TJSArray);
    procedure BindBrowse(AButton: TJSHTMLElement);
    procedure HideSuggestions;
    procedure Pick(const AValue: String);
    procedure Toggle(const AValue: String);
    procedure Remove(const AValue: String);
    function Contains(const AValue: String): Boolean;
    procedure Clear;
    function ReadValue(out AValue: String): Boolean;
    function ReadValues(out AValues: TStringValues): Boolean;
    property Chosen: String read FChosen;
    property Input: TJSHTMLInputElement read FInput;
  end;

function CreatePickerField(const AId, AName, APlaceholder: String;
  AMultiple: Boolean = False): TNyxNode;
function FriendlySymptom(const AValue: String): String;
function Capitalized(const AText: String): String;
function VocabularyText(AObject: TJSObject; const AKey: String): String;
function VocabularyItems(AObject: TJSObject; const AKey: String): TJSArray;
function IngredientPreparations(AOptions: TJSObject; const AIngredient: String): TJSArray;
function ResearchIngredientURL(const AInfo: TResearchIngredientInfo): String;
function ResearchIngredientTrendText(const ATrend: String): String;
function ReadOracleURLParam(const AKey: String): String;

implementation

type
  TSymptomName = record
    Value: String;
    LabelText: String;
  end;

const
  CNames: array[0..32] of TSymptomName = (
    (Value:'rest tremor severity'; LabelText:'Tremors'),
    (Value:'bradykinesia severity'; LabelText:'Slow movement'),
    (Value:'muscle rigidity severity'; LabelText:'Muscle stiffness'),
    (Value:'walking slowness'; LabelText:'Slow walking'),
    (Value:'shortened stride severity'; LabelText:'Short steps'),
    (Value:'freezing of gait frequency'; LabelText:'Freezing while walking'),
    (Value:'postural instability severity'; LabelText:'Trouble with balance'),
    (Value:'fall frequency'; LabelText:'Falls'),
    (Value:'hand dexterity impairment'; LabelText:'Trouble using hands'),
    (Value:'small handwriting severity'; LabelText:'Small handwriting'),
    (Value:'low voice volume severity'; LabelText:'Quiet voice'),
    (Value:'speech intelligibility impairment'; LabelText:'Unclear speech'),
    (Value:'swallowing difficulty severity'; LabelText:'Trouble swallowing'),
    (Value:'dyskinesia severity'; LabelText:'Involuntary movements'),
    (Value:'dystonia severity'; LabelText:'Dystonia'),
    (Value:'daily off time'; LabelText:'Medication wearing off'),
    (Value:'drooling severity'; LabelText:'Drooling'),
    (Value:'constipation severity'; LabelText:'Constipation'),
    (Value:'urinary urgency frequency'; LabelText:'Urgent need to urinate'),
    (Value:'orthostatic lightheadedness severity'; LabelText:'Dizziness when standing'),
    (Value:'daytime sleepiness severity'; LabelText:'Daytime sleepiness'),
    (Value:'insomnia severity'; LabelText:'Trouble sleeping'),
    (Value:'dream enactment frequency'; LabelText:'Acting out dreams'),
    (Value:'fatigue severity'; LabelText:'Fatigue'),
    (Value:'depressive symptom severity'; LabelText:'Depression symptoms'),
    (Value:'anxiety severity'; LabelText:'Anxiety'),
    (Value:'apathy severity'; LabelText:'Low motivation'),
    (Value:'visual hallucination frequency'; LabelText:'Seeing things that aren’t there'),
    (Value:'attention impairment'; LabelText:'Trouble paying attention'),
    (Value:'executive function impairment'; LabelText:'Trouble planning and organizing'),
    (Value:'olfactory impairment severity'; LabelText:'Reduced sense of smell'),
    (Value:'pain severity'; LabelText:'Pain'),
    (Value:'reduced facial expressiveness'; LabelText:'Less facial expression')
  );

function JSValueText(AValue: JSValue): String; external name 'String';
function EncodeURIComponentVocab(const AText: String): String; external name 'encodeURIComponent';

function DecodeURIComponentSafeVocab(const AText: String): String;
begin
  try
    asm
      return decodeURIComponent(AText.replace(/\+/g, ' '));
    end;
  except
    Result := AText;
  end;
end;

function ExtractQueryParam(const AQuery, ATargetKey: String): String;
var
  LClean: String;
  LStart: Integer;
  LIndex: Integer;
  LPair: String;
  LEq: Integer;
  LKey: String;
begin
  Result := '';
  LClean := Trim(AQuery);
  if (LClean <> '') and ((LClean[1] = '?') or (LClean[1] = '#')) then
    Delete(LClean, 1, 1);
  if LClean = '' then
    Exit;
  LStart := 1;
  for LIndex := 1 to Length(LClean) + 1 do
  begin
    if (LIndex > Length(LClean)) or (LClean[LIndex] = '&') then
    begin
      LPair := Copy(LClean, LStart, LIndex - LStart);
      LEq := Pos('=', LPair);
      if LEq > 1 then
      begin
        LKey := LowerCase(Trim(Copy(LPair, 1, LEq - 1)));
        if LKey = ATargetKey then
          Exit(Trim(DecodeURIComponentSafeVocab(Copy(LPair, LEq + 1, MaxInt))));
      end;
      LStart := LIndex + 1;
    end;
  end;
end;

function ReadOracleURLParam(const AKey: String): String;
var
  LTarget: String;
begin
  LTarget := LowerCase(Trim(AKey));
  Result := ExtractQueryParam(window.location.search, LTarget);
  if Result = '' then
    Result := ExtractQueryParam(window.location.hash, LTarget);
end;

function ResearchIngredientURL(const AInfo: TResearchIngredientInfo): String;
begin
  if (not AInfo.InPool) or (AInfo.Canonical = '') then
    Exit('');
  Result := './?ingredient=' + EncodeURIComponentVocab(AInfo.Canonical);
  if (AInfo.Trend = 'eases') or (AInfo.Trend = 'worsens') then
    Result := Result + '&trend=' + EncodeURIComponentVocab(AInfo.Trend)
  else if AInfo.Trend = 'mixed' then
    Result := Result + '&scope=directional';
end;

function ResearchIngredientTrendText(const ATrend: String): String;
begin
  if ATrend = 'eases' then
    Result := 'May ease symptoms'
  else if ATrend = 'worsens' then
    Result := 'May worsen symptoms'
  else if ATrend = 'mixed' then
    Result := 'Mixed symptom signals'
  else
    Result := '';
end;

{ TOracleResearchPool }

constructor TOracleResearchPool.Create;
begin
  inherited Create;
  FMap := TJSObject.new;
  FLoaded := False;
end;

procedure TOracleResearchPool.LoadFromFilterIngredients(AIngredients: TJSArray);
var
  LIndex: Integer;
  LAliasIndex: Integer;
  LItem: TJSObject;
  LValue: String;
  LKey: String;
  LAliases: TJSArray;
  LAliasKey: String;
  LEntry: TJSObject;
begin
  FMap := TJSObject.new;
  FLoaded := False;
  if AIngredients = nil then
    Exit;
  for LIndex := 0 to AIngredients.Length - 1 do
  begin
    LItem := TJSObject(AIngredients[LIndex]);
    LValue := Trim(VocabularyText(LItem, 'value'));
    if LValue = '' then
      Continue;
    LEntry := TJSObject.new;
    LEntry['canonical'] := LValue;
    LEntry['trend'] := LowerCase(Trim(VocabularyText(LItem, 'trend')));
    LEntry['eases'] := StrToIntDef(VocabularyText(LItem, 'eases_count'), 0);
    LEntry['worsens'] := StrToIntDef(VocabularyText(LItem, 'worsens_count'), 0);
    LKey := LowerCase(LValue);
    FMap['k:' + LKey] := LEntry;
    LAliases := VocabularyItems(LItem, 'aliases');
    for LAliasIndex := 0 to LAliases.Length - 1 do
    begin
      LAliasKey := LowerCase(Trim(JSValueText(LAliases[LAliasIndex])));
      if (LAliasKey <> '') and not isDefined(FMap['k:' + LAliasKey]) then
        FMap['k:' + LAliasKey] := LEntry;
    end;
  end;
  FLoaded := AIngredients.Length > 0;
end;

function TOracleResearchPool.TryGet(const AKey: String;
  out AInfo: TResearchIngredientInfo): Boolean;
var
  LRaw: JSValue;
  LEntry: TJSObject;
begin
  AInfo := Default(TResearchIngredientInfo);
  Result := False;
  if (AKey = '') or (FMap = nil) then
    Exit;
  LRaw := FMap['k:' + AKey];
  if (not isDefined(LRaw)) or isNull(LRaw) then
    Exit;
  LEntry := TJSObject(LRaw);
  AInfo.InPool := True;
  AInfo.Canonical := VocabularyText(LEntry, 'canonical');
  AInfo.Trend := VocabularyText(LEntry, 'trend');
  AInfo.EasesCount := StrToIntDef(VocabularyText(LEntry, 'eases'), 0);
  AInfo.WorsensCount := StrToIntDef(VocabularyText(LEntry, 'worsens'), 0);
  Result := AInfo.Canonical <> '';
end;

function TOracleResearchPool.Lookup(const AIngredient: String): TResearchIngredientInfo;
var
  LKey: String;
  LMapped: String;
begin
  Result := Default(TResearchIngredientInfo);
  if not FLoaded then
    Exit;
  LKey := LowerCase(Trim(AIngredient));
  if LKey = '' then
    Exit;
  if TryGet(LKey, Result) then
    Exit;
  // Unambiguous culinary aliases matching canonical research-pool entries.
  LMapped := '';
  if (LKey = 'pea') or (LKey = 'peas') then
    LMapped := 'green peas'
  else if LKey = 'dill' then
    LMapped := 'dill weed'
  else if LKey = 'buckwheat' then
    LMapped := 'buckwheat groats'
  else if LKey = 'pomegranate' then
    LMapped := 'pomegranate arils'
  else if LKey = 'ground chicken' then
    LMapped := 'chicken'
  else if LKey = 'ground turkey' then
    LMapped := 'turkey'
  else if LKey = 'pork tenderloin' then
    LMapped := 'pork'
  else if LKey = 'greek yogurt' then
    LMapped := 'yogurt'
  else if LKey = 'celery' then
    LMapped := 'celery stalk'
  else if LKey = 'cilantro leaf' then
    LMapped := 'cilantro'
  else if LKey = 'rolled oats' then
    LMapped := 'oats'
  else if LKey = 'dark chocolate chips' then
    LMapped := 'dark chocolate';
  if (LMapped <> '') and TryGet(LMapped, Result) then
    Exit;
  // Exact singular/plural variations (e.g. chickpea -> chickpeas, lentil -> lentils).
  if TryGet(LKey + 's', Result) then
    Exit;
  if TryGet(LKey + 'es', Result) then
    Exit;
  if (Length(LKey) > 3) and (LKey[Length(LKey)] = 's') and
    TryGet(Copy(LKey, 1, Length(LKey) - 1), Result) then
    Exit;
  if (Length(LKey) > 4) and (Copy(LKey, Length(LKey) - 2, 3) = 'ies') and
    TryGet(Copy(LKey, 1, Length(LKey) - 3) + 'y', Result) then
    Exit;
end;

function VocabularyText(AObject: TJSObject; const AKey: String): String;
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

function VocabularyItems(AObject: TJSObject; const AKey: String): TJSArray;
begin
  if (AObject <> nil) and TJSArray.isArray(AObject[AKey]) then
    Result := TJSArray(AObject[AKey])
  else
    Result := TJSArray.new;
end;

function IngredientPreparations(AOptions: TJSObject; const AIngredient: String): TJSArray;
var
  LIngredients: TJSArray;
  LValues: TJSArray;
  LIngredient: TJSObject;
  LOption: TJSObject;
  LIndex: Integer;
  LPrep: Integer;
begin
  LIngredients := VocabularyItems(AOptions, 'ingredients');
  if AIngredient <> '' then
    for LIndex := 0 to LIngredients.Length - 1 do
    begin
      LIngredient := TJSObject(LIngredients[LIndex]);
      if VocabularyText(LIngredient, 'value') = AIngredient then
      begin
        Result := TJSArray.new;
        LValues := VocabularyItems(LIngredient, 'preparations');
        for LPrep := 0 to LValues.Length - 1 do
        begin
          LOption := TJSObject.new;
          LOption['value'] := LValues[LPrep];
          Result.push(LOption);
        end;
        Exit;
      end;
    end;
  Result := VocabularyItems(AOptions, 'preparations');
end;

function Capitalized(const AText: String): String;
begin
  Result := UpperCase(Copy(AText, 1, 1)) + Copy(AText, 2, MaxInt);
end;

function FriendlySymptom(const AValue: String): String;
var
  LName: TSymptomName;
begin
  for LName in CNames do
    if AValue = LName.Value then
      Exit(LName.LabelText);
  Result := Capitalized(AValue);
end;

function CreatePickerField(const AId, AName, APlaceholder: String;
  AMultiple: Boolean): TNyxNode;
begin
  Result := TNyxNode.Create(nkColumn, AId + '-field');
  Result.Add(TNyxNode.Create(nkInput, AId).Configure.Text(AName)
    .AccessibleName(AName).Placeholder(APlaceholder).Done);
  if AMultiple then
    Result.Add(TNyxNode.Create(nkRow, AId + '-selected').Configure
      .AccessibleName('Chosen ' + AId + ' tags').Done)
  else
    Result.Add(TNyxNode.Create(nkButton, AId + '-selected').Configure
      .Text('Clear selection').Variant(nvSecondary).Done);
  Result.Add(TNyxNode.Create(nkColumn, AId + '-suggestions').Configure
    .AccessibleName(Capitalized(AId) + ' suggestions').Done);
end;

function MatchRank(const AQuery, AChoice: String): Integer;
begin
  if AQuery = AChoice then
    Exit(0);
  if Pos(AQuery, AChoice) = 1 then
    Exit(1);
  if Pos(AQuery, AChoice) > 0 then
    Exit(2);
  Result := 3;
end;

function TOraclePicker.LabelFor(const AValue: String): String;
begin
  if FId = 'symptom' then
    Result := FriendlySymptom(AValue)
  else
    Result := Capitalized(AValue);
end;

function TOraclePicker.Matches(const AText: String): TPickerOptions;
var
  LQuery: String;
  LItem: TJSObject;
  LAliases: TJSArray;
  LOption: TPickerOption;
  LIndex: Integer;
  LAlias: Integer;
  LRank: Integer;
  LInsert: Integer;
begin
  Result := nil;
  if FChoices = nil then
    Exit;
  LQuery := LowerCase(Trim(AText));
  for LIndex := 0 to FChoices.Length - 1 do
  begin
    LItem := TJSObject(FChoices[LIndex]);
    LOption.Value := VocabularyText(LItem, 'value');
    LOption.LabelText := LabelFor(LOption.Value);
    LOption.Rank := 0;
    if LQuery <> '' then
    begin
      LOption.Rank := MatchRank(LQuery, LowerCase(LOption.LabelText));
      LRank := MatchRank(LQuery, LowerCase(LOption.Value));
      if LRank < LOption.Rank then
        LOption.Rank := LRank;
      LAliases := VocabularyItems(LItem, 'aliases');
      for LAlias := 0 to LAliases.Length - 1 do
      begin
        LRank := MatchRank(LQuery, LowerCase(JSValueText(LAliases[LAlias])));
        if LRank < LOption.Rank then
          LOption.Rank := LRank;
      end;
    end;
    if LOption.Rank > 2 then
      Continue;
    LInsert := Length(Result);
    SetLength(Result, LInsert + 1);
    while (LInsert > 0) and ((Result[LInsert - 1].Rank > LOption.Rank) or
      ((Result[LInsert - 1].Rank = LOption.Rank) and
      (CompareText(Result[LInsert - 1].LabelText, LOption.LabelText) > 0))) do
    begin
      Result[LInsert] := Result[LInsert - 1];
      Dec(LInsert);
    end;
    Result[LInsert] := LOption;
  end;
end;

procedure TOraclePicker.HideSuggestions;
begin
  FHost.setAttribute('hidden', '');
  FFirst := nil;
  FOptionCount := 0;
  FBrowsing := False;
  if FBrowseButton <> nil then
    FBrowseButton.setAttribute('aria-expanded', 'false');
end;

procedure TOraclePicker.Pick(const AValue: String);
var
  LLabel: String;
begin
  FChosen := AValue;
  FInput.value := '';
  FInput.removeAttribute('aria-invalid');
  HideSuggestions;
  if FMultiple then
  begin
    FValues := AddSelection(FValues, AValue);
    RenderSelections;
  end
  else if FChosen = '' then
    FSelected.setAttribute('hidden', '')
  else
  begin
    LLabel := LabelFor(FChosen);
    FFormRenderer.Root.Find(FId + '-selected').Configure
      .Text(LLabel + ' ×').AccessibleName('Remove ' + LLabel);
    FSelected.textContent := LLabel + ' ×';
    FSelected.setAttribute('aria-label', 'Remove ' + LLabel);
    FSelected.removeAttribute('hidden');
  end;
  if Assigned(FOnChange) then
    FOnChange();
end;

function TOraclePicker.Contains(const AValue: String): Boolean;
begin
  if FMultiple then
    Result := HasSelection(FValues, AValue)
  else
    Result := FChosen = AValue;
end;

procedure TOraclePicker.Toggle(const AValue: String);
begin
  if FMultiple and Contains(AValue) then
    Remove(AValue)
  else
    Pick(AValue);
end;

procedure TOraclePicker.Remove(const AValue: String);
begin
  FValues := RemoveSelection(FValues, AValue);
  FChosen := '';
  RenderSelections;
  if Assigned(FOnChange) then
    FOnChange();
end;

procedure TOraclePicker.BindRemoval(const ANodeId, AValue: String);
var
  LClick: TJSEventHandler;
begin
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Remove(AValue);
      FInput.focus;
      Result := True;
    end;
  FSelectedRenderer.ElementFor(ANodeId).addEventListener('click', LClick);
end;

procedure TOraclePicker.RenderSelections;
var
  LDocument: TNyxDocument;
  LPage: TNyxNode;
  LPrior: TNyxDocument;
  LIndex: Integer;
  LId: String;
  LLabel: String;
begin
  LDocument := TNyxDocument.Create;
  LPage := TNyxNode.Create(nkPage, 'selected-pills');
  LDocument.AddPage(LPage);
  for LIndex := 0 to High(FValues) do
  begin
    LId := 'selected-' + IntToStr(LIndex);
    LLabel := LabelFor(FValues[LIndex]);
    LPage.Add(TNyxNode.Create(nkButton, LId).Configure.Text(LLabel + ' ×')
      .AccessibleName('Remove ' + LLabel).Variant(nvSecondary).Done);
  end;
  LPrior := FSelectedDocument;
  FSelectedRenderer.Render(LDocument, LPage, FSelected);
  FSelectedDocument := LDocument;
  LPrior.Free;
  for LIndex := 0 to High(FValues) do
    BindRemoval('selected-' + IntToStr(LIndex), FValues[LIndex]);
  if Length(FValues) = 0 then
    FSelected.setAttribute('hidden', '')
  else
    FSelected.removeAttribute('hidden');
end;

procedure TOraclePicker.Clear;
begin
  if FMultiple then
    FValues := nil;
  Pick('');
end;

procedure TOraclePicker.BindSuggestion(const ANodeId: String; const AOption: TPickerOption);
var
  LButton: TJSHTMLElement;
  LClick: TJSEventHandler;
begin
  LButton := FRenderer.ElementFor(ANodeId);
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Toggle(AOption.Value);
      FInput.focus;
      Result := True;
    end;
  LButton.addEventListener('click', LClick);
end;

procedure TOraclePicker.UpdateSuggestions;
var
  LOptions: TPickerOptions;
  LDocument: TNyxDocument;
  LPage: TNyxNode;
  LPrior: TNyxDocument;
  LIndex: Integer;
  LLimit: Integer;
  LQuery: String;
  LCaption: String;
begin
  LQuery := Trim(FInput.value);
  if (LQuery = '') and not FBrowsing then
  begin
    HideSuggestions;
    Exit;
  end;
  if FBrowsing then
    LQuery := '';
  LOptions := Matches(LQuery);
  LLimit := Length(LOptions);
  if not FBrowsing and (LLimit > 8) then
    LLimit := 8;

  LDocument := TNyxDocument.Create;
  LPage := TNyxNode.Create(nkPage, 'picker-options');
  LDocument.AddPage(LPage);
  if LLimit = 0 then
  begin
    LCaption := 'No matching options. Try a shorter word.';
    if FChoices = nil then
      LCaption := 'Choices are loading. You can also enter a full name.';
    LPage.Add(TNyxNode.Create(nkLabel, 'picker-message').Configure.Text(LCaption).Done);
  end;
  for LIndex := 0 to LLimit - 1 do
  begin
    if FMultiple then
      LPage.Add(TNyxNode.Create(nkButton, 'option-' + IntToStr(LIndex)).Configure
        .Text(LOptions[LIndex].LabelText).Variant(nvSecondary)
        .Pressed(Contains(LOptions[LIndex].Value)).Done)
    else
      LPage.Add(TNyxNode.Create(nkButton, 'option-' + IntToStr(LIndex)).Configure
        .Text(LOptions[LIndex].LabelText).Variant(nvSecondary).Done);
  end;
  if LLimit < Length(LOptions) then
    LPage.Add(TNyxNode.Create(nkLabel, 'picker-message').Configure
      .Text('Type more letters to narrow the suggestions.').Done);
  LPrior := FDocument;
  FRenderer.Render(LDocument, LPage, FHost);
  FDocument := LDocument;
  LPrior.Free;
  FOptionCount := LLimit;
  FFirst := nil;
  if LLimit > 0 then
    FFirst := FRenderer.ElementFor('option-0');
  for LIndex := 0 to LLimit - 1 do
  begin
    BindSuggestion('option-' + IntToStr(LIndex), LOptions[LIndex]);
    if FMultiple then
      FRenderer.ElementFor('option-' + IntToStr(LIndex)).setAttribute('aria-pressed',
        LowerCase(BoolToStr(Contains(LOptions[LIndex].Value), True)));
  end;
  FHost.removeAttribute('hidden');
  if FBrowseButton <> nil then
    FBrowseButton.setAttribute('aria-expanded', 'true');
end;

function TOraclePicker.ReadValues(out AValues: TStringValues): Boolean;
var
  LValue: String;
begin
  Result := ReadValue(LValue);
  if not Result then
    Exit;
  if FMultiple and (Trim(FInput.value) <> '') then
    Pick(LValue);
  if FMultiple then
    AValues := AddSelection(FValues, '')
  else
  begin
    AValues := nil;
    AValues := AddSelection(AValues, LValue);
  end;
end;

function TOraclePicker.ReadValue(out AValue: String): Boolean;
var
  LTyped: String;
  LOptions: TPickerOptions;
begin
  AValue := FChosen;
  LTyped := Trim(FInput.value);
  if LTyped = '' then
    Exit(True);
  if FChoices = nil then
  begin
    AValue := LTyped;
    Exit(True);
  end;

  LOptions := Matches(LTyped);
  if (Length(LOptions) = 1) or ((Length(LOptions) > 1) and
    (LOptions[0].Rank = 0) and (LOptions[1].Rank > 0)) then
  begin
    AValue := LOptions[0].Value;
    Pick(AValue);
    Exit(True);
  end;

  FInput.setAttribute('aria-invalid', 'true');
  UpdateSuggestions;
  FInput.focus;
  Result := False;
end;

procedure TOraclePicker.SetChoices(AChoices: TJSArray);
begin
  FChoices := AChoices;
  if not FHost.hasAttribute('hidden') then
    UpdateSuggestions;
end;

procedure TOraclePicker.BindBrowse(AButton: TJSHTMLElement);
var
  LClick: TJSEventHandler;
begin
  FBrowseButton := AButton;
  FBrowseButton.setAttribute('aria-controls', FHost.id);
  FBrowseButton.setAttribute('aria-expanded', 'false');
  LClick :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if FBrowsing then
        HideSuggestions
      else
      begin
        FBrowsing := True;
        UpdateSuggestions;
      end;
      Result := True;
    end;
  FBrowseButton.addEventListener('click', LClick);
end;

constructor TOraclePicker.Create(ARenderer: TNyxBrowserRenderer; const AId: String;
  AOnChange, AOnSubmit: TPickerAction; AMultiple: Boolean);
var
  LType: TJSEventHandler;
  LFocus: TJSEventHandler;
  LKey: TJSEventHandler;
  LClear: TJSEventHandler;
begin
  inherited Create;
  FId := AId;
  FMultiple := AMultiple;
  FValues := nil;
  if FMultiple then
    FSelectedRenderer := TNyxBrowserRenderer.Create;
  FFormRenderer := ARenderer;
  FRenderer := TNyxBrowserRenderer.Create;
  FInput := TJSHTMLInputElement(ARenderer.InputFor(AId));
  FSelected := ARenderer.ElementFor(AId + '-selected');
  FHost := ARenderer.ElementFor(AId + '-suggestions');
  FOnChange := AOnChange;
  FOnSubmit := AOnSubmit;
  FHost.id := 'suggestions-' + AId;
  FHost.setAttribute('role', 'group');
  FHost.setAttribute('aria-label', Capitalized(AId) + ' suggestions');
  if FMultiple then
    FSelected.setAttribute('role', 'group');
  FInput.setAttribute('autocomplete', 'off');
  FInput.setAttribute('aria-controls', FHost.id);
  FSelected.setAttribute('hidden', '');
  HideSuggestions;

  LType :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if not FMultiple then
      begin
        FChosen := '';
        FSelected.setAttribute('hidden', '');
      end;
      FInput.removeAttribute('aria-invalid');
      FBrowsing := False;
      if Assigned(FOnChange) then
        FOnChange();
      UpdateSuggestions;
      Result := True;
    end;
  FInput.addEventListener('input', LType);
  LFocus :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LTarget: TJSHTMLInputElement;
    begin
      LTarget := FInput;
      if window.innerWidth <= 780 then
        window.setTimeout(
          procedure
          begin
            if document.activeElement = LTarget then
              asm
                try { LTarget.scrollIntoView({ block: 'start', behavior: 'smooth' }); } catch (e) {}
              end;
          end, 160);
      Result := True;
    end;
  FInput.addEventListener('focus', LFocus);
  LClear :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Clear;
      FInput.focus;
      Result := True;
    end;
  if not FMultiple then
    FSelected.addEventListener('click', LClear);
  LKey :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LPressed: String;
    begin
      LPressed := TJSKeyboardEvent(AEvent).key;
      if LPressed = 'ArrowDown' then
      begin
        if FFirst <> nil then
        begin
          AEvent.preventDefault;
          FFirst.focus;
        end;
      end
      else if LPressed = 'Escape' then
        HideSuggestions
      else if LPressed = 'Enter' then
      begin
        AEvent.preventDefault;
        if Assigned(FOnSubmit) then
          FOnSubmit();
      end;
      Result := True;
    end;
  FInput.addEventListener('keydown', LKey);
  LKey :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LPressed: String;
      LTarget: TJSElement;
      LCurrent: Integer;
    begin
      LPressed := TJSKeyboardEvent(AEvent).key;
      if LPressed = 'Escape' then
      begin
        HideSuggestions;
        FInput.focus;
      end
      else if (FOptionCount > 0) and ((LPressed = 'ArrowDown') or (LPressed = 'ArrowUp') or
        (LPressed = 'Home') or (LPressed = 'End')) then
      begin
        LCurrent := -1;
        if (AEvent.target <> nil) and (TJSNode(AEvent.target).nodeType = 1) then
        begin
          LTarget := TJSElement(AEvent.target).closest('[data-node^="option-"]');
          if LTarget <> nil then
            LCurrent := StrToIntDef(Copy(LTarget.getAttribute('data-node'), 8, MaxInt), -1);
        end;
        AEvent.preventDefault;
        if LPressed = 'Home' then
          FRenderer.ElementFor('option-0').focus
        else if LPressed = 'End' then
          FRenderer.ElementFor('option-' + IntToStr(FOptionCount - 1)).focus
        else if LPressed = 'ArrowDown' then
        begin
          if LCurrent < FOptionCount - 1 then
            FRenderer.ElementFor('option-' + IntToStr(LCurrent + 1)).focus
          else
            FRenderer.ElementFor('option-0').focus;
        end
        else if LPressed = 'ArrowUp' then
        begin
          if LCurrent > 0 then
            FRenderer.ElementFor('option-' + IntToStr(LCurrent - 1)).focus
          else
            FInput.focus;
        end;
      end;
      Result := True;
    end;
  FHost.addEventListener('keydown', LKey);
end;

end.
