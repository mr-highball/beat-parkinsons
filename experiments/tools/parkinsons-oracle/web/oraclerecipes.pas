{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclerecipes;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses
  SysUtils, JS, Web, nyx.model, nyx.types, nyx.collections, nyx.modal,
  nyx.modal.browser, nyx.render.browser, parkinsonsoracle.recipes, wfc;

type
  TOracleRecipesModal = class
  private
    FModalHost: INyxBrowserModalHost;
    FShellDoc: TNyxDocument;
    FShellRenderer: TNyxBrowserRenderer;
    FTabsDoc: TNyxDocument;
    FTabsRenderer: TNyxBrowserRenderer;
    FChipsDoc: TNyxDocument;
    FChipsRenderer: TNyxBrowserRenderer;
    FCardsDoc: TNyxDocument;
    FCardsRenderer: TNyxBrowserRenderer;
    FCollectionKey: TNyxCollectionRef;
    FSchema: TNyxCollectionSchema;
    FIdField: TNyxTextFieldRef;
    FTitleField: TNyxTextFieldRef;
    FCoreField: TNyxTextFieldRef;
    FCategoryField: TNyxTextFieldRef;
    FEffortField: TNyxTextFieldRef;
    FPrepField: TNyxIntegerFieldRef;
    FServingsField: TNyxIntegerFieldRef;
    FSummaryField: TNyxTextFieldRef;
    FIngredientsField: TNyxTextFieldRef;
    FStepsField: TNyxTextFieldRef;
    FTagsField: TNyxTextFieldRef;
    FCollection: INyxCollection;
    FSubscription: INyxCollectionSubscription;
    FCatalog: TRecipeCatalog;
    FCatalogLoading: Boolean;
    FCatalogError: String;
    FMainIngredient: String;
    FMainDisplay: String;
    FExtraIngredients: TRecipeStrings;
    FCategory: TRecipeCategory;
    FMaxCount: Integer;
    FSeed: TGraphSeed;
    FLastResult: TRecipeWfcResult;
    FInvoker: TJSHTMLElement;
    FBackdropClick: TJSEventHandler;
    FRenderedInCollapse: Boolean;
    procedure InitCollection;
    procedure EnsureCatalogLoaded;
    procedure OnCollectionChanged(const ACollection: INyxCollection;
      const AChanges: INyxCollectionChanges);
    function OnBackdropClick(AEvent: TEventListenerEvent): Boolean;
    procedure MountShell;
    procedure RenderTabs;
    procedure RenderSidebarChips;
    procedure RenderCards(const ASnapshot: INyxCollectionSnapshot);
    procedure AddIngredientsFromText(const AText: String);
    procedure ToggleExtraIngredient(const AIngredient: String);
    procedure RemoveExtraIngredient(const AIngredient: String);
    procedure ClearExtraIngredients;
    procedure RunCollapse;
    procedure CleanupSubViews;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open(const AIngredient: String; AInvoker: TJSHTMLElement = nil);
    procedure Close;
    function IsOpen: Boolean;
  end;

implementation

uses
  StrUtils, Math, nyx.hostspace, oraclestatic, oraclevocab, parkinsonsoracle.presentation;

const
  CCollapseLimits: array[0..3] of Integer = (5, 10, 15, 25);

function EncodeURIComponent(const AText: String): String; external name 'encodeURIComponent';

function MakeNode(AKind: TNyxKind; const AId: String; const AText: String = ''): TNyxNode;
begin
  Result := TNyxNode.Create(AKind, AId);
  if AText <> '' then
    Result.Configure.Text(AText).Done;
end;

function MakeButton(const AId, AText: String; AVariant: TNyxVariant = nvSecondary): TNyxNode;
begin
  Result := TNyxNode.Create(nkButton, AId).Configure.Text(AText).Variant(AVariant).Done;
end;

procedure BindHandler(AElement: TJSHTMLElement; const AEventName: String;
  AHandler: TJSEventHandler);
begin
  AElement.addEventListener(AEventName, AHandler);
end;

function JoinPacked(const AValues: TRecipeStrings; const ASeparator: String): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to High(AValues) do
  begin
    if LIndex > 0 then
      Result := Result + ASeparator;
    Result := Result + AValues[LIndex];
  end;
end;

function SplitPacked(const AText: String; ASeparator: Char): TRecipeStrings;
var
  LStart: Integer;
  LIndex: Integer;
  LPart: String;
  LLen: Integer;
begin
  Result := nil;
  if AText = '' then
    Exit;
  LStart := 1;
  for LIndex := 1 to Length(AText) + 1 do
  begin
    if (LIndex > Length(AText)) or (AText[LIndex] = ASeparator) then
    begin
      LPart := Copy(AText, LStart, LIndex - LStart);
      if LPart <> '' then
      begin
        LLen := Length(Result);
        SetLength(Result, LLen + 1);
        Result[LLen] := LPart;
      end;
      LStart := LIndex + 1;
    end;
  end;
end;

function HasExtra(const AValues: TRecipeStrings; const AIngredient: String): Boolean;
var
  LIndex: Integer;
  LNormalized: String;
begin
  LNormalized := NormalizeRecipeIngredient(AIngredient);
  for LIndex := 0 to High(AValues) do
    if AValues[LIndex] = LNormalized then
      Exit(True);
  Result := False;
end;

{ TOracleRecipesModal }

constructor TOracleRecipesModal.Create;
begin
  inherited Create;
  FCategory := rcAll;
  FMaxCount := CDefaultRecipeCollapseCount;
  FSeed := 1;
  InitCollection;
  FShellRenderer := TNyxBrowserRenderer.Create;
  FTabsRenderer := TNyxBrowserRenderer.Create;
  FChipsRenderer := TNyxBrowserRenderer.Create;
  FCardsRenderer := TNyxBrowserRenderer.Create;
end;

destructor TOracleRecipesModal.Destroy;
begin
  Close;
  if FSubscription <> nil then
  begin
    FSubscription.Disconnect;
    FSubscription := nil;
  end;
  CleanupSubViews;
  if FModalHost <> nil then
  begin
    if Assigned(FBackdropClick) then
      FModalHost.Element.removeEventListener('click', FBackdropClick);
    FModalHost.OnDismiss := nil;
    FModalHost := nil;
  end;
  FCardsRenderer.Free;
  FChipsRenderer.Free;
  FTabsRenderer.Free;
  FShellRenderer.Free;
  FCatalog.Free;
  FCollection := nil;
  inherited Destroy;
end;

procedure TOracleRecipesModal.InitCollection;
begin
  FCollectionKey := NyxCollection('oracle-recipes');
  FIdField := NyxTextField('id');
  FTitleField := NyxTextField('title');
  FCoreField := NyxTextField('core_ingredient');
  FCategoryField := NyxTextField('category');
  FEffortField := NyxTextField('effort');
  FPrepField := NyxIntegerField('prep_minutes');
  FServingsField := NyxIntegerField('servings');
  FSummaryField := NyxTextField('summary');
  FIngredientsField := NyxTextField('ingredients');
  FStepsField := NyxTextField('steps');
  FTagsField := NyxTextField('tags');

  FSchema := NyxCollectionSchema
    .Text(FIdField, '')
    .Text(FTitleField, '')
    .Text(FCoreField, '')
    .Text(FCategoryField, 'breakfast')
    .Text(FEffortField, 'low')
    .Integer(FPrepField, 10)
    .Integer(FServingsField, 1)
    .Text(FSummaryField, '')
    .Text(FIngredientsField, '')
    .Text(FStepsField, '')
    .Text(FTagsField, '');

  FCollection := NewNyxCollection(FCollectionKey, FSchema);
  FSubscription := FCollection.Subscribe(@OnCollectionChanged);
end;

procedure TOracleRecipesModal.CleanupSubViews;
begin
  if FCardsRenderer <> nil then
    FCardsRenderer.Unmount;
  FreeAndNil(FCardsDoc);
  if FChipsRenderer <> nil then
    FChipsRenderer.Unmount;
  FreeAndNil(FChipsDoc);
  if FTabsRenderer <> nil then
    FTabsRenderer.Unmount;
  FreeAndNil(FTabsDoc);
  if FShellRenderer <> nil then
    FShellRenderer.Unmount;
  FreeAndNil(FShellDoc);
end;

function TOracleRecipesModal.IsOpen: Boolean;
begin
  Result := (FModalHost <> nil) and FModalHost.IsOpen;
end;

function TOracleRecipesModal.OnBackdropClick(AEvent: TEventListenerEvent): Boolean;
begin
  if (FModalHost <> nil) and (AEvent.target = FModalHost.Element) then
    Close;
  Result := True;
end;

procedure TOracleRecipesModal.OnCollectionChanged(const ACollection: INyxCollection;
  const AChanges: INyxCollectionChanges);
begin
  if IsOpen and (AChanges <> nil) then
  begin
    FRenderedInCollapse := True;
    RenderCards(AChanges.After);
  end;
end;

procedure TOracleRecipesModal.EnsureCatalogLoaded;
begin
  if (FCatalog <> nil) or FCatalogLoading then
    Exit;
  FCatalogLoading := True;
  FCatalogError := '';
  GetOracleAsset('./recipes.json',
    procedure(AData: TJSObject; const AError: String)
    var
      LLoaded: TRecipeCatalog;
    begin
      FCatalogLoading := False;
      if AError <> '' then
      begin
        FCatalogError := 'Unable to load recipes right now. Please try again in a moment.';
      end
      else
      begin
        LLoaded := TRecipeCatalog.Create;
        try
          LLoaded.LoadFromJSObject(AData, False);
          FCatalog.Free;
          FCatalog := LLoaded;
          LLoaded := nil;
        except
          on E: Exception do
          begin
            LLoaded.Free;
            FCatalogError := 'Unable to load recipes right now. Please try again in a moment.';
          end;
        end;
      end;
      if IsOpen then
        RunCollapse;
    end);
end;

procedure TOracleRecipesModal.Open(const AIngredient: String; AInvoker: TJSHTMLElement);
var
  LNormalized: String;
  LCloseButton: TJSHTMLElement;
begin
  LNormalized := NormalizeRecipeIngredient(AIngredient);
  FMainIngredient := LNormalized;
  FExtraIngredients := nil;
  FCategory := rcAll;
  FMaxCount := CDefaultRecipeCollapseCount;
  FSeed := 1;
  if Trim(AIngredient) <> '' then
    FMainDisplay := Capitalized(Trim(AIngredient))
  else
    FMainDisplay := Capitalized(FMainIngredient);

  if AInvoker <> nil then
    FInvoker := AInvoker
  else
    FInvoker := TJSHTMLElement(document.activeElement);

  if FModalHost = nil then
  begin
    FModalHost := NewNyxBrowserModalHost;
    FModalHost.OnDismiss := Close;
    FModalHost.Element.setAttribute('data-oracle-recipes-modal', 'true');
    FBackdropClick := @OnBackdropClick;
    FModalHost.Element.addEventListener('click', FBackdropClick);
  end;

  MountShell;
  FModalHost.Show(NyxModal('Recipes for ' + FMainDisplay)
    .Viewport(92)
    .MaximumWidth(1140)
    .MaximumHeight(820)
    .Sizing(nhfAvailableHeight));

  EnsureCatalogLoaded;
  RunCollapse;

  LCloseButton := FShellRenderer.FocusFor('recipes-close');
  if LCloseButton <> nil then
    NyxFocusWithoutScroll(LCloseButton);
end;

procedure TOracleRecipesModal.Close;
var
  LInvoker: TJSHTMLElement;
begin
  LInvoker := FInvoker;
  FInvoker := nil;
  if FModalHost <> nil then
    FModalHost.Hide;
  if (LInvoker <> nil) and document.body.contains(LInvoker) then
    NyxFocusWithoutScroll(LInvoker);
end;

procedure TOracleRecipesModal.MountShell;
var
  LDoc: TNyxDocument;
  LPage: TNyxNode;
  LHeader: TNyxNode;
  LHeaderText: TNyxNode;
  LBody: TNyxNode;
  LSidebar: TNyxNode;
  LAddSection: TNyxNode;
  LAddRow: TNyxNode;
  LControls: TNyxNode;
  LCardsPane: TNyxNode;
  LInput: TJSHTMLInputElement;
  LSelect: TJSHTMLSelectElement;
  LIndex: Integer;
begin
  CleanupSubViews;
  LDoc := TNyxDocument.Create;
  LPage := MakeNode(nkPage, 'recipes-modal-page');
  LDoc.AddPage(LPage);

  LHeader := MakeNode(nkRow, 'recipes-modal-header');
  LHeaderText := MakeNode(nkColumn, 'recipes-modal-heading-group');
  LHeaderText.Add(MakeNode(nkHeading, 'recipes-modal-title', 'Recipes · ' + FMainDisplay));
  LHeaderText.Add(MakeNode(nkLabel, 'recipes-modal-subtitle',
    'Browse simple recipe ideas by meal type, or add ingredients you already have on hand.'));
  LHeader.Add(LHeaderText);
  LHeader.Add(MakeButton('recipes-close', '× Close', nvSecondary)
    .Configure.AccessibleName('Close recipes').Done);
  LPage.Add(LHeader);

  LPage.Add(MakeNode(nkPanel, 'recipes-tabs-host'));

  LBody := MakeNode(nkGrid, 'recipes-modal-body');

  LSidebar := MakeNode(nkColumn, 'recipes-sidebar');
  LSidebar.Add(MakeNode(nkHeading, 'recipes-sidebar-heading', 'Ingredients'));
  LSidebar.Add(MakeNode(nkColumn, 'recipes-main-section')
    .Add(MakeNode(nkLabel, 'recipes-main-label', 'Main ingredient'))
    .Add(MakeNode(nkBadge, 'recipes-main-chip', FMainDisplay)));

  LAddSection := MakeNode(nkColumn, 'recipes-add-section');
  LAddSection.Add(MakeNode(nkLabel, 'recipes-add-label', 'Include other ingredients'));
  LAddRow := MakeNode(nkRow, 'recipes-add-row');
  LAddRow.Add(MakeNode(nkInput, 'recipes-add-input')
    .Configure.AccessibleName('Include other ingredients')
    .Placeholder('e.g. black pepper, onions').Done);
  LAddRow.Add(MakeButton('recipes-add-btn', 'Add', nvPrimary));
  LAddSection.Add(LAddRow);
  LSidebar.Add(LAddSection);

  LSidebar.Add(MakeNode(nkColumn, 'recipes-sidebar-chips'));

  LControls := MakeNode(nkColumn, 'recipes-wfc-controls');
  LControls.Add(MakeNode(nkSelect, 'recipes-limit')
    .Configure.Text('Recipes shown')
    .AccessibleName('Number of recipes shown')
    .Items('5 recipes'#10'10 recipes'#10'15 recipes'#10'25 recipes')
    .Value('10 recipes').Done);
  LControls.Add(MakeButton('recipes-shuffle', 'Show different ideas', nvSecondary));
  LSidebar.Add(LControls);

  LBody.Add(LSidebar);

  LCardsPane := MakeNode(nkColumn, 'recipes-cards-pane');
  LCardsPane.Add(MakeNode(nkLabel, 'recipes-status-bar', 'Loading recipes…'));
  LCardsPane.Add(MakeNode(nkColumn, 'recipes-cards-host'));
  LBody.Add(LCardsPane);

  LPage.Add(LBody);

  FShellRenderer.Render(LDoc, LPage, FModalHost.Element);
  FShellDoc := LDoc;

  BindHandler(FShellRenderer.ElementFor('recipes-close'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Close;
      Result := True;
    end);

  LInput := TJSHTMLInputElement(FShellRenderer.InputFor('recipes-add-input'));
  BindHandler(FShellRenderer.ElementFor('recipes-add-btn'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      AddIngredientsFromText(LInput.value);
      LInput.value := '';
      NyxFocusWithoutScroll(LInput);
      Result := True;
    end);
  BindHandler(LInput, 'keydown',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TJSKeyboardEvent(AEvent).key = 'Enter' then
      begin
        AEvent.preventDefault;
        AddIngredientsFromText(LInput.value);
        LInput.value := '';
      end;
      Result := True;
    end);

  LSelect := TJSHTMLSelectElement(FShellRenderer.InputFor('recipes-limit'));
  for LIndex := Low(CCollapseLimits) to High(CCollapseLimits) do
    if CCollapseLimits[LIndex] = FMaxCount then
      LSelect.selectedIndex := LIndex;
  BindHandler(LSelect, 'change',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if (LSelect.selectedIndex >= Low(CCollapseLimits)) and
        (LSelect.selectedIndex <= High(CCollapseLimits)) then
      begin
        FMaxCount := CCollapseLimits[LSelect.selectedIndex];
        RunCollapse;
      end;
      Result := True;
    end);

  BindHandler(FShellRenderer.ElementFor('recipes-shuffle'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Inc(FSeed);
      RunCollapse;
      Result := True;
    end);
end;

procedure TOracleRecipesModal.AddIngredientsFromText(const AText: String);
var
  LParsed: TRecipeStrings;
  LItem: String;
  LChanged: Boolean;
  LLen: Integer;
begin
  LParsed := ParseIngredientList(AText);
  LChanged := False;
  for LItem in LParsed do
  begin
    if (LItem = '') or (LItem = FMainIngredient) or HasExtra(FExtraIngredients, LItem) then
      Continue;
    LLen := Length(FExtraIngredients);
    SetLength(FExtraIngredients, LLen + 1);
    FExtraIngredients[LLen] := LItem;
    LChanged := True;
  end;
  if LChanged then
    RunCollapse;
end;

procedure TOracleRecipesModal.ToggleExtraIngredient(const AIngredient: String);
begin
  if HasExtra(FExtraIngredients, AIngredient) then
    RemoveExtraIngredient(AIngredient)
  else
    AddIngredientsFromText(AIngredient);
end;

procedure TOracleRecipesModal.RemoveExtraIngredient(const AIngredient: String);
var
  LNormalized: String;
  LNext: TRecipeStrings;
  LIndex: Integer;
  LLen: Integer;
begin
  LNormalized := NormalizeRecipeIngredient(AIngredient);
  LNext := nil;
  for LIndex := 0 to High(FExtraIngredients) do
  begin
    if FExtraIngredients[LIndex] <> LNormalized then
    begin
      LLen := Length(LNext);
      SetLength(LNext, LLen + 1);
      LNext[LLen] := FExtraIngredients[LIndex];
    end;
  end;
  FExtraIngredients := LNext;
  RunCollapse;
end;

procedure TOracleRecipesModal.ClearExtraIngredients;
begin
  if Length(FExtraIngredients) = 0 then
    Exit;
  FExtraIngredients := nil;
  RunCollapse;
end;

procedure TOracleRecipesModal.RenderTabs;
var
  LDoc: TNyxDocument;
  LRow: TNyxNode;
  LCat: TRecipeCategory;
  LTabId: String;
  LLabel: String;
  LButton: TJSHTMLElement;

  procedure BindTab(const AId: String; ATarget: TRecipeCategory);
  begin
    LButton := FTabsRenderer.ElementFor(AId);
    LButton.setAttribute('role', 'tab');
    LButton.setAttribute('aria-selected', LowerCase(BoolToStr(FCategory = ATarget, True)));
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(FCategory = ATarget, True)));
    BindHandler(LButton, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        if FCategory <> ATarget then
        begin
          FCategory := ATarget;
          RunCollapse;
        end;
        Result := True;
      end);
  end;

begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  LDoc := TNyxDocument.Create;
  LRow := MakeNode(nkRow, 'recipes-category-tabs');
  LDoc.AddPage(LRow);
  for LCat := Low(TRecipeCategory) to High(TRecipeCategory) do
  begin
    LTabId := 'recipes-tab-' + RecipeCategoryKey(LCat);
    LLabel := RecipeCategoryLabel(LCat);
    if FCatalog <> nil then
      LLabel := LLabel + ' (' + IntToStr(FLastResult.CategoryCounts[LCat]) + ')';
    LRow.Add(MakeButton(LTabId, LLabel, nvSecondary)
      .Configure.Pressed(FCategory = LCat).Done);
  end;

  FTabsRenderer.Render(LDoc, LRow, FShellRenderer.ElementFor('recipes-tabs-host'));
  FTabsDoc.Free;
  FTabsDoc := LDoc;
  FTabsRenderer.ElementFor('recipes-category-tabs').setAttribute('role', 'tablist');
  FTabsRenderer.ElementFor('recipes-category-tabs').setAttribute('aria-label', 'Recipe categories');
  for LCat := Low(TRecipeCategory) to High(TRecipeCategory) do
    BindTab('recipes-tab-' + RecipeCategoryKey(LCat), LCat);
end;

procedure TOracleRecipesModal.RenderSidebarChips;
var
  LDoc: TNyxDocument;
  LRoot: TNyxNode;
  LExtrasRow: TNyxNode;
  LSuggestRow: TNyxNode;
  LSuggestions: TRecipeStrings;
  LIndex: Integer;
  LName: String;
  LButton: TJSHTMLElement;

  procedure BindRemove(const AId, AIngredient: String);
  begin
    BindHandler(FChipsRenderer.ElementFor(AId), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        RemoveExtraIngredient(AIngredient);
        Result := True;
      end);
  end;

  procedure BindSuggest(const AId, AIngredient: String; AActive: Boolean);
  begin
    LButton := FChipsRenderer.ElementFor(AId);
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(AActive, True)));
    BindHandler(LButton, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ToggleExtraIngredient(AIngredient);
        Result := True;
      end);
  end;

begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  LDoc := TNyxDocument.Create;
  LRoot := MakeNode(nkColumn, 'recipes-chips-inner');
  LDoc.AddPage(LRoot);

  if Length(FExtraIngredients) > 0 then
  begin
    LRoot.Add(MakeNode(nkLabel, 'recipes-extras-label', 'Also includes'));
    LExtrasRow := MakeNode(nkRow, 'recipes-extras-list');
    for LIndex := 0 to High(FExtraIngredients) do
    begin
      LName := FExtraIngredients[LIndex];
      LExtrasRow.Add(MakeButton('recipes-extra-' + IntToStr(LIndex),
        Capitalized(LName) + ' ×', nvSecondary)
        .Configure.AccessibleName('Remove ingredient ' + LName).Done);
    end;
    LRoot.Add(LExtrasRow);
    LRoot.Add(MakeButton('recipes-clear-extras', 'Clear added ingredients', nvSecondary));
  end
  else
  begin
    LRoot.Add(MakeNode(nkLabel, 'recipes-extras-hint',
      'Add ingredients like black pepper or onions to narrow your recipe ideas.'));
  end;

  LSuggestions := nil;
  if FCatalog <> nil then
    LSuggestions := FCatalog.AvailableExtraIngredients(FMainIngredient, 8);
  if Length(LSuggestions) > 0 then
  begin
    LRoot.Add(MakeNode(nkLabel, 'recipes-suggest-label', 'Common pairings'));
    LSuggestRow := MakeNode(nkRow, 'recipes-suggest-list');
    for LIndex := 0 to High(LSuggestions) do
    begin
      LName := LSuggestions[LIndex];
      LSuggestRow.Add(MakeButton('recipes-suggest-' + IntToStr(LIndex),
        Capitalized(LName), nvSecondary)
        .Configure.Pressed(HasExtra(FExtraIngredients, LName)).Done);
    end;
    LRoot.Add(LSuggestRow);
  end;

  FChipsRenderer.Render(LDoc, LRoot, FShellRenderer.ElementFor('recipes-sidebar-chips'));
  FChipsDoc.Free;
  FChipsDoc := LDoc;

  for LIndex := 0 to High(FExtraIngredients) do
    BindRemove('recipes-extra-' + IntToStr(LIndex), FExtraIngredients[LIndex]);
  if Length(FExtraIngredients) > 0 then
    BindHandler(FChipsRenderer.ElementFor('recipes-clear-extras'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ClearExtraIngredients;
        Result := True;
      end);
  for LIndex := 0 to High(LSuggestions) do
    BindSuggest('recipes-suggest-' + IntToStr(LIndex), LSuggestions[LIndex],
      HasExtra(FExtraIngredients, LSuggestions[LIndex]));
end;

procedure TOracleRecipesModal.RenderCards(const ASnapshot: INyxCollectionSnapshot);
var
  LDoc: TNyxDocument;
  LDeck: TNyxNode;
  LCard: TNyxNode;
  LMeta: TNyxNode;
  LIngRow: TNyxNode;
  LActionsRow: TNyxNode;
  LStepsPanel: TNyxNode;
  LItem: TNyxCollectionItem;
  LIndex: Integer;
  LSubIndex: Integer;
  LTag: String;
  LIngredients: TRecipeStrings;
  LSteps: TRecipeStrings;
  LCat: TRecipeCategory;
  LEffort: TRecipeEffort;
  LBadge: TJSHTMLElement;
  LLinkEl: TJSHTMLElement;
  LToggle: TJSHTMLElement;
  LPanel: TJSHTMLElement;
  LHasCoreRecipes: Boolean;
  LStatusText: String;
  LServings: Integer;
  LServingLabel: String;
  LRecipeId: String;
  LRecipeTitle: String;
  LRecipeURL: String;

  procedure BindStepsToggle(const AToggleId, APanelId: String);
  begin
    LToggle := FCardsRenderer.ElementFor(AToggleId);
    LPanel := FCardsRenderer.ElementFor(APanelId);
    LPanel.id := APanelId;
    LPanel.hidden := True;
    LToggle.setAttribute('aria-controls', APanelId);
    LToggle.setAttribute('aria-expanded', 'false');
    BindHandler(LToggle, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      var
        LButton: TJSHTMLElement;
        LDetail: TJSHTMLElement;
      begin
        LButton := FCardsRenderer.ElementFor(AToggleId);
        LDetail := FCardsRenderer.ElementFor(APanelId);
        LDetail.hidden := not LDetail.hidden;
        LButton.setAttribute('aria-expanded', LowerCase(BoolToStr(not LDetail.hidden, True)));
        if LDetail.hidden then
          LButton.textContent := 'Show quick steps'
        else
          LButton.textContent := 'Hide quick steps';
        Result := True;
      end);
  end;

begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;

  LHasCoreRecipes := (FCatalog <> nil) and
    (Length(FCatalog.QueryByCoreIngredient(FMainIngredient)) > 0);

  if FCatalogLoading then
    LStatusText := 'Loading recipes…'
  else if FCatalogError <> '' then
    LStatusText := FCatalogError
  else if (ASnapshot = nil) or (ASnapshot.Count = 0) then
  begin
    if not LHasCoreRecipes then
      LStatusText := 'No recipes for ' + FMainDisplay + ' yet'
    else if (Length(FExtraIngredients) = 0) and (FCategory <> rcAll) then
      LStatusText := 'No ' + LowerCase(RecipeCategoryLabel(FCategory)) + ' for ' + FMainDisplay
    else
      LStatusText := 'No matching recipes for these ingredients';
  end
  else if ASnapshot.Count = FLastResult.TotalCandidates then
  begin
    if ASnapshot.Count = 1 then
      LStatusText := 'Showing 1 recipe'
    else
      LStatusText := 'Showing all ' + IntToStr(ASnapshot.Count) + ' recipes';
    if FCategory <> rcAll then
      LStatusText := LStatusText + ' in ' + RecipeCategoryLabel(FCategory);
  end
  else
  begin
    LStatusText := 'Showing ' + IntToStr(ASnapshot.Count) + ' of ' +
      IntToStr(FLastResult.TotalCandidates) + ' recipes';
    if FCategory <> rcAll then
      LStatusText := LStatusText + ' in ' + RecipeCategoryLabel(FCategory);
  end;
  FShellRenderer.ElementFor('recipes-status-bar').textContent := LStatusText;

  LDoc := TNyxDocument.Create;
  LDeck := MakeNode(nkGrid, 'recipes-card-deck');
  LDoc.AddPage(LDeck);

  if FCatalogLoading then
  begin
    LDeck.Add(MakeNode(nkCard, 'recipes-empty-card')
      .Add(MakeNode(nkHeading, 'recipes-empty-title', 'Loading recipes…'))
      .Add(MakeNode(nkLabel, 'recipes-empty-message',
        'Finding recipe ideas for you…')));
  end
  else if FCatalogError <> '' then
  begin
    LDeck.Add(MakeNode(nkCard, 'recipes-empty-card')
      .Add(MakeNode(nkHeading, 'recipes-empty-title', 'Recipes unavailable'))
      .Add(MakeNode(nkLabel, 'recipes-empty-message', FCatalogError)));
  end
  else if (ASnapshot = nil) or (ASnapshot.Count = 0) then
  begin
    LCard := MakeNode(nkCard, 'recipes-empty-card');
    if not LHasCoreRecipes then
    begin
      LCard.Add(MakeNode(nkHeading, 'recipes-empty-title',
        'No recipes for ' + FMainDisplay + ' yet'));
      LCard.Add(MakeNode(nkLabel, 'recipes-empty-message',
        'Recipes are currently available for ingredients with promising symptom-relief signals, and more ingredients are on the way.'));
    end
    else
    begin
      if (Length(FExtraIngredients) = 0) and (FCategory <> rcAll) and
        (FLastResult.CategoryCounts[rcAll] > 0) then
      begin
        LCard.Add(MakeNode(nkHeading, 'recipes-empty-title',
          'No ' + LowerCase(RecipeCategoryLabel(FCategory)) + ' for ' + FMainDisplay));
        LCard.Add(MakeNode(nkLabel, 'recipes-empty-message',
          'Browse ' + IntToStr(FLastResult.CategoryCounts[rcAll]) + ' ' + FMainDisplay +
          ' recipes in other categories.'));
        LCard.Add(MakeButton('recipes-empty-all', 'Show All categories', nvPrimary));
      end
      else
      begin
        LCard.Add(MakeNode(nkHeading, 'recipes-empty-title', 'No recipes match those ingredients'));
        if (FCategory <> rcAll) and (FLastResult.CategoryCounts[rcAll] > 0) then
        begin
          if FLastResult.CategoryCounts[rcAll] = 1 then
            LCard.Add(MakeNode(nkLabel, 'recipes-empty-message',
              '1 recipe matches your ingredients in another category.'))
          else
            LCard.Add(MakeNode(nkLabel, 'recipes-empty-message',
              IntToStr(FLastResult.CategoryCounts[rcAll]) +
              ' recipes match your ingredients in other categories.'));
          LCard.Add(MakeButton('recipes-empty-all', 'Show All categories', nvPrimary));
        end
        else
        begin
          LCard.Add(MakeNode(nkLabel, 'recipes-empty-message',
            'Try removing an added ingredient to see more recipe ideas.'));
        end;
        if Length(FExtraIngredients) > 0 then
          LCard.Add(MakeButton('recipes-empty-clear', 'Clear added ingredients', nvSecondary));
      end;
    end;
    LDeck.Add(LCard);
  end
  else
  begin
    for LIndex := 0 to ASnapshot.Count - 1 do
    begin
      LItem := ASnapshot.ItemAt(LIndex);
      LTag := IntToStr(LIndex);
      TryParseRecipeCategory(LItem.GetValue(FCategoryField), LCat);
      TryParseRecipeEffort(LItem.GetValue(FEffortField), LEffort);

      LCard := MakeNode(nkCard, 'recipe-card-' + LTag);
      LMeta := MakeNode(nkRow, 'recipe-meta-' + LTag);
      LMeta.Add(MakeNode(nkBadge, 'recipe-cat-' + LTag, RecipeCategoryLabel(LCat)));
      LMeta.Add(MakeNode(nkBadge, 'recipe-effort-' + LTag, RecipeEffortLabel(LEffort)));
      LServings := LItem.GetValue(FServingsField);
      if LServings = 1 then
        LServingLabel := '1 serving'
      else
        LServingLabel := IntToStr(LServings) + ' servings';
      LMeta.Add(MakeNode(nkLabel, 'recipe-time-' + LTag,
        IntToStr(LItem.GetValue(FPrepField)) + ' min · ' + LServingLabel));
      LCard.Add(LMeta);

      LCard.Add(MakeNode(nkHeading, 'recipe-title-' + LTag, LItem.GetValue(FTitleField)));
      LCard.Add(MakeNode(nkLabel, 'recipe-summary-' + LTag, LItem.GetValue(FSummaryField)));

      LIngredients := SplitPacked(LItem.GetValue(FIngredientsField), '|');
      LIngRow := MakeNode(nkRow, 'recipe-ingredients-' + LTag);
      for LSubIndex := 0 to High(LIngredients) do
        LIngRow.Add(MakeNode(nkBadge, 'recipe-ing-' + LTag + '-' + IntToStr(LSubIndex),
          Capitalized(LIngredients[LSubIndex])));
      LCard.Add(LIngRow);

      LSteps := SplitPacked(LItem.GetValue(FStepsField), #10);
      LRecipeId := LItem.GetValue(FIdField);
      LRecipeTitle := LItem.GetValue(FTitleField);
      LRecipeURL := './?recipe=' + EncodeURIComponent(LRecipeId);
      LActionsRow := MakeNode(nkRow, 'recipe-actions-' + LTag);
      if Length(LSteps) > 0 then
        LActionsRow.Add(MakeButton('recipe-steps-toggle-' + LTag, 'Show quick steps', nvSecondary));
      LActionsRow.Add(MakeNode(nkLink, 'recipe-open-full-' + LTag)
        .Configure.LinkTo(LRecipeURL)
        .AccessibleName('Open full recipe for ' + LRecipeTitle + ' in a new tab').Done);
      LCard.Add(LActionsRow);

      if Length(LSteps) > 0 then
      begin
        LStepsPanel := MakeNode(nkColumn, 'recipe-steps-' + LTag);
        for LSubIndex := 0 to High(LSteps) do
          LStepsPanel.Add(MakeNode(nkLabel, 'recipe-step-' + LTag + '-' + IntToStr(LSubIndex),
            IntToStr(LSubIndex + 1) + '. ' + LSteps[LSubIndex]));
        LCard.Add(LStepsPanel);
      end;

      LDeck.Add(LCard);
    end;
  end;

  FCardsRenderer.Render(LDoc, LDeck, FShellRenderer.ElementFor('recipes-cards-host'));
  FCardsDoc.Free;
  FCardsDoc := LDoc;

  if (ASnapshot <> nil) and (ASnapshot.Count > 0) then
  begin
    for LIndex := 0 to ASnapshot.Count - 1 do
    begin
      LItem := ASnapshot.ItemAt(LIndex);
      LTag := IntToStr(LIndex);
      FCardsRenderer.ElementFor('recipe-effort-' + LTag).setAttribute('data-effort',
        LItem.GetValue(FEffortField));
      FCardsRenderer.ElementFor('recipe-cat-' + LTag).setAttribute('data-category',
        LItem.GetValue(FCategoryField));
      LIngredients := SplitPacked(LItem.GetValue(FIngredientsField), '|');
      for LSubIndex := 0 to High(LIngredients) do
      begin
        LBadge := FCardsRenderer.ElementFor('recipe-ing-' + LTag + '-' + IntToStr(LSubIndex));
        if LIngredients[LSubIndex] = FMainIngredient then
          LBadge.setAttribute('data-match', 'main')
        else if HasExtra(FExtraIngredients, LIngredients[LSubIndex]) then
          LBadge.setAttribute('data-match', 'extra');
      end;
      LLinkEl := FCardsRenderer.ElementFor('recipe-open-full-' + LTag);
      LLinkEl.setAttribute('target', '_blank');
      LLinkEl.setAttribute('rel', 'noopener noreferrer');
      LLinkEl.setAttribute('title', 'Open full recipe in new tab');
      LSteps := SplitPacked(LItem.GetValue(FStepsField), #10);
      if Length(LSteps) > 0 then
        BindStepsToggle('recipe-steps-toggle-' + LTag, 'recipe-steps-' + LTag);
    end;
  end
  else if not FCatalogLoading and (FCatalogError = '') then
  begin
    if FCardsRenderer.Root.Find('recipes-empty-all') <> nil then
      BindHandler(FCardsRenderer.ElementFor('recipes-empty-all'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          FCategory := rcAll;
          RunCollapse;
          Result := True;
        end);
    if FCardsRenderer.Root.Find('recipes-empty-clear') <> nil then
      BindHandler(FCardsRenderer.ElementFor('recipes-empty-clear'), 'click',
        function(AEvent: TEventListenerEvent): Boolean
        begin
          ClearExtraIngredients;
          Result := True;
        end);
  end;
end;

procedure TOracleRecipesModal.RunCollapse;
var
  LQuery: TRecipeWfcQuery;
  LItems: array of TNyxCollectionItem;
  LIndex: Integer;
  LRecipe: TRecipe;
  LNext: INyxCollection;
  LSnapshot: INyxCollectionSnapshot;
begin
  if FCatalog <> nil then
  begin
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := FMainIngredient;
    LQuery.ExtraIngredients := FExtraIngredients;
    LQuery.Category := FCategory;
    LQuery.MaxCount := FMaxCount;
    LQuery.Seed := FSeed;
    FLastResult := CollapseRecipesWithWfc(FCatalog, LQuery);
  end
  else
    FLastResult := Default(TRecipeWfcResult);

  RenderTabs;
  RenderSidebarChips;

  SetLength(LItems, Length(FLastResult.Recipes));
  for LIndex := 0 to High(FLastResult.Recipes) do
  begin
    LRecipe := FLastResult.Recipes[LIndex];
    LItems[LIndex] := NyxCollectionItem(NyxItem(FCollectionKey, LRecipe.Id))
      .WithValue(FIdField, LRecipe.Id)
      .WithValue(FTitleField, LRecipe.Title)
      .WithValue(FCoreField, LRecipe.CoreIngredient)
      .WithValue(FCategoryField, RecipeCategoryKey(LRecipe.Category))
      .WithValue(FEffortField, RecipeEffortKey(LRecipe.Effort))
      .WithValue(FPrepField, LRecipe.TotalMinutes)
      .WithValue(FServingsField, LRecipe.Servings)
      .WithValue(FSummaryField, LRecipe.Summary)
      .WithValue(FIngredientsField, JoinPacked(LRecipe.Ingredients, '|'))
      .WithValue(FStepsField, JoinPacked(LRecipe.Steps, #10))
      .WithValue(FTagsField, JoinPacked(LRecipe.Tags, '|'));
  end;

  LNext := NewNyxCollection(FCollectionKey, FSchema, LItems);
  FRenderedInCollapse := False;
  FCollection.Assign(LNext.Snapshot);
  LSnapshot := FCollection.Snapshot;
  // Ensure cards render even when Assign is a structural no-op (e.g. reopened or 0 -> 0 state transition).
  if not FRenderedInCollapse then
    RenderCards(LSnapshot);
end;

end.
