{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclevocab;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, JS, Web, nyx.model, nyx.types, nyx.render.browser;

type
  TPickerAction = reference to procedure;
  TPickerOption = record
    Value: String;
    LabelText: String;
    Rank: Integer;
  end;
  TPickerOptions = array of TPickerOption;

  TOraclePicker = class
  private
    FId: String;
    FChosen: String;
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
    function Matches(const AText: String): TPickerOptions;
    function LabelFor(const AValue: String): String;
    procedure UpdateSuggestions;
    procedure BindSuggestion(const ANodeId: String; const AOption: TPickerOption);
  public
    constructor Create(ARenderer: TNyxBrowserRenderer; const AId: String;
      AOnChange, AOnSubmit: TPickerAction);
    procedure SetChoices(AChoices: TJSArray);
    procedure BindBrowse(AButton: TJSHTMLElement);
    procedure HideSuggestions;
    procedure Pick(const AValue: String);
    procedure Clear;
    function ReadValue(out AValue: String): Boolean;
    property Chosen: String read FChosen;
    property Input: TJSHTMLInputElement read FInput;
  end;

function CreatePickerField(const AId, AName, APlaceholder: String): TNyxNode;
function FriendlySymptom(const AValue: String): String;
function Capitalized(const AText: String): String;
function VocabularyText(AObject: TJSObject; const AKey: String): String;
function VocabularyItems(AObject: TJSObject; const AKey: String): TJSArray;
function IngredientPreparations(AOptions: TJSObject; const AIngredient: String): TJSArray;

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

function CreatePickerField(const AId, AName, APlaceholder: String): TNyxNode;
begin
  Result := TNyxNode.Create(nkColumn, AId + '-field');
  Result.Add(TNyxNode.Create(nkInput, AId).Configure.Text(AName)
    .AccessibleName(AName).Placeholder(APlaceholder).Done);
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
  if FChosen = '' then
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

procedure TOraclePicker.Clear;
begin
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
      Pick(AOption.Value);
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
    LPage.Add(TNyxNode.Create(nkButton, 'option-' + IntToStr(LIndex)).Configure
      .Text(LOptions[LIndex].LabelText).Variant(nvSecondary).Done);
  if LLimit < Length(LOptions) then
    LPage.Add(TNyxNode.Create(nkLabel, 'picker-message').Configure
      .Text('Type more letters to narrow the suggestions.').Done);
  LPrior := FDocument;
  FRenderer.Render(LDocument, LPage, FHost);
  FDocument := LDocument;
  LPrior.Free;
  FFirst := nil;
  if LLimit > 0 then
    FFirst := FRenderer.ElementFor('option-0');
  for LIndex := 0 to LLimit - 1 do
    BindSuggestion('option-' + IntToStr(LIndex), LOptions[LIndex]);
  FHost.removeAttribute('hidden');
  if FBrowseButton <> nil then
    FBrowseButton.setAttribute('aria-expanded', 'true');
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
  AOnChange, AOnSubmit: TPickerAction);
var
  LType: TJSEventHandler;
  LKey: TJSEventHandler;
  LClear: TJSEventHandler;
begin
  inherited Create;
  FId := AId;
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
  FInput.setAttribute('autocomplete', 'off');
  FInput.setAttribute('aria-controls', FHost.id);
  FSelected.setAttribute('hidden', '');
  HideSuggestions;

  LType :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      FChosen := '';
      FSelected.setAttribute('hidden', '');
      FInput.removeAttribute('aria-invalid');
      FBrowsing := False;
      if Assigned(FOnChange) then
        FOnChange();
      UpdateSuggestions;
      Result := True;
    end;
  FInput.addEventListener('input', LType);
  LClear :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Clear;
      FInput.focus;
      Result := True;
    end;
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
    begin
      if TJSKeyboardEvent(AEvent).key = 'Escape' then
      begin
        HideSuggestions;
        FInput.focus;
      end;
      Result := True;
    end;
  FHost.addEventListener('keydown', LKey);
end;

end.
