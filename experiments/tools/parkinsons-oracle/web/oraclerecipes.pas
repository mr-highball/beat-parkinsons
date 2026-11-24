{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclerecipes;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses
  SysUtils, JS, Web, nyx.model, nyx.types, nyx.collections, nyx.modal,
  nyx.modal.browser, nyx.render.browser, oraclevocab, parkinsonsoracle.recipes, wfc;

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
    FAddSuggestDoc: TNyxDocument;
    FAddSuggestRenderer: TNyxBrowserRenderer;
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
    FResearchPool: TOracleResearchPool;
    FMainIngredient: String;
    FMainDisplay: String;
    FExtraIngredients: TRecipeStrings;
    FCategory: TRecipeCategory;
    FMaxCount: Integer;
    FSeed: TGraphSeed;
    FLastResult: TRecipeWfcResult;
    FInvoker: TJSHTMLElement;
    FBackdropClick: TJSEventHandler;
    FViewportResize: TJSEventHandler;
    FRenderedInCollapse: Boolean;
    FAddCandidates: TRecipeIngredientCandidates;
    FAddHighlight: Integer;
    FAddSuggestOpen: Boolean;
    FAddFocused: Boolean;
    FBlurTimer: Integer;
    procedure InitCollection;
    procedure EnsureCatalogLoaded;
    function LookupPool(const AIngredient: String): TResearchIngredientInfo;
    procedure UpdateMainChipTheme;
    procedure KeepAddInputVisible;
    procedure SetAddInputFocused(AFocused: Boolean);
    procedure BindVisualViewport;
    procedure UnbindVisualViewport;
    procedure UpdateAddSuggestions(const AQuery: String);
    procedure HideAddSuggestions;
    procedure UpdateAddHighlightDOM;
    procedure PickAddSuggestion(const AName: String);
    procedure CommitAddInput;
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
    procedure SetResearchPool(APool: TOracleResearchPool);
    procedure Open(const AIngredient: String; AInvoker: TJSHTMLElement = nil);
    procedure Close;
    function IsOpen: Boolean;
  end;

implementation

uses
  StrUtils, Math, nyx.hostspace, oraclestatic, parkinsonsoracle.presentation;

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
  FAddSuggestRenderer := TNyxBrowserRenderer.Create;
  FCardsRenderer := TNyxBrowserRenderer.Create;
  FAddHighlight := -1;
end;

destructor TOracleRecipesModal.Destroy;
begin
  Close;
  UnbindVisualViewport;
  if FBlurTimer <> 0 then
  begin
    window.clearTimeout(FBlurTimer);
    FBlurTimer := 0;
  end;
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
  FAddSuggestRenderer.Free;
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
  if FAddSuggestRenderer <> nil then
    FAddSuggestRenderer.Unmount;
  FreeAndNil(FAddSuggestDoc);
  FAddCandidates := nil;
  FAddHighlight := -1;
  FAddSuggestOpen := False;
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

function TOracleRecipesModal.LookupPool(const AIngredient: String): TResearchIngredientInfo;
begin
  if FResearchPool <> nil then
    Result := FResearchPool.Lookup(AIngredient)
  else
    Result := Default(TResearchIngredientInfo);
end;

procedure TOracleRecipesModal.UpdateMainChipTheme;
var
  LChip: TJSHTMLElement;
  LInfo: TResearchIngredientInfo;
  LTrendText: String;
begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) or
    (FShellRenderer.Root.Find('recipes-main-chip') = nil) then
    Exit;
  LChip := FShellRenderer.ElementFor('recipes-main-chip');
  LInfo := LookupPool(FMainIngredient);
  LChip.setAttribute('data-match', 'main');
  if LInfo.InPool then
  begin
    LChip.setAttribute('data-in-pool', 'true');
    if LInfo.Trend <> '' then
      LChip.setAttribute('data-trend', LInfo.Trend)
    else
      LChip.removeAttribute('data-trend');
    LTrendText := ResearchIngredientTrendText(LInfo.Trend);
    if LTrendText <> '' then
      LChip.setAttribute('title', FMainDisplay + ' · Primary ingredient · ' + LTrendText)
    else
      LChip.setAttribute('title', FMainDisplay + ' · Primary ingredient');
  end
  else
  begin
    LChip.removeAttribute('data-in-pool');
    LChip.removeAttribute('data-trend');
    LChip.setAttribute('title', FMainDisplay + ' · Primary ingredient');
  end;
end;

procedure TOracleRecipesModal.SetResearchPool(APool: TOracleResearchPool);
begin
  FResearchPool := APool;
  if IsOpen then
  begin
    UpdateMainChipTheme;
    RenderSidebarChips;
    if FAddSuggestOpen and (FShellRenderer <> nil) and (FShellRenderer.Root <> nil) then
      UpdateAddSuggestions(TJSHTMLInputElement(FShellRenderer.InputFor('recipes-add-input')).value);
    if FCollection <> nil then
      RenderCards(FCollection.Snapshot);
  end;
end;

procedure TOracleRecipesModal.KeepAddInputVisible;
var
  LSection: TJSHTMLElement;
  LPage: TJSHTMLElement;
begin
  if (not IsOpen) or (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  if FShellRenderer.Root.Find('recipes-add-section') = nil then
    Exit;
  LSection := FShellRenderer.ElementFor('recipes-add-section');
  LPage := FShellRenderer.ElementFor('recipes-modal-page');
  if (window.innerWidth <= 780) or (window.innerHeight <= 540) then
  begin
    if LPage <> nil then
      LPage.scrollTop := 0;
    asm
      try { LSection.scrollIntoView({ block: 'nearest', behavior: 'auto' }); } catch (e) {}
    end;
  end;
end;

procedure TOracleRecipesModal.SetAddInputFocused(AFocused: Boolean);
begin
  FAddFocused := AFocused;
  if FModalHost = nil then
    Exit;
  if AFocused then
  begin
    FModalHost.Element.setAttribute('data-input-focused', 'true');
    KeepAddInputVisible;
    window.setTimeout(
      procedure
      begin
        if FAddFocused then
          KeepAddInputVisible;
      end, 160);
    window.setTimeout(
      procedure
      begin
        if FAddFocused then
          KeepAddInputVisible;
      end, 340);
  end
  else
    FModalHost.Element.removeAttribute('data-input-focused');
end;

procedure TOracleRecipesModal.BindVisualViewport;
var
  LSelf: TOracleRecipesModal;
begin
  if Assigned(FViewportResize) then
    Exit;
  LSelf := Self;
  FViewportResize :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if LSelf.FAddFocused then
        LSelf.KeepAddInputVisible;
      Result := True;
    end;
  asm
    if (window.visualViewport && typeof window.visualViewport.addEventListener === 'function') {
      window.visualViewport.addEventListener('resize', LSelf.FViewportResize);
    }
  end;
end;

procedure TOracleRecipesModal.UnbindVisualViewport;
var
  LHandler: TJSEventHandler;
begin
  if not Assigned(FViewportResize) then
    Exit;
  LHandler := FViewportResize;
  FViewportResize := nil;
  asm
    if (window.visualViewport && typeof window.visualViewport.removeEventListener === 'function') {
      window.visualViewport.removeEventListener('resize', LHandler);
    }
  end;
end;

procedure TOracleRecipesModal.HideAddSuggestions;
var
  LHost: TJSHTMLElement;
  LInput: TJSHTMLElement;
begin
  FAddSuggestOpen := False;
  FAddHighlight := -1;
  FAddCandidates := nil;
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  if FShellRenderer.Root.Find('recipes-add-suggestions') <> nil then
  begin
    LHost := FShellRenderer.ElementFor('recipes-add-suggestions');
    LHost.hidden := True;
  end;
  LInput := FShellRenderer.InputFor('recipes-add-input');
  if LInput <> nil then
  begin
    LInput.setAttribute('aria-expanded', 'false');
    LInput.removeAttribute('aria-activedescendant');
  end;
end;

procedure TOracleRecipesModal.UpdateAddHighlightDOM;
var
  LIndex: Integer;
  LBtn: TJSHTMLElement;
  LInput: TJSHTMLElement;
  LActiveId: String;
begin
  if (FAddSuggestRenderer = nil) or (FAddSuggestRenderer.Root = nil) then
    Exit;
  LActiveId := '';
  for LIndex := 0 to High(FAddCandidates) do
  begin
    LBtn := FAddSuggestRenderer.ElementFor('recipes-add-opt-' + IntToStr(LIndex));
    if LBtn = nil then
      Continue;
    if LIndex = FAddHighlight then
    begin
      LBtn.setAttribute('aria-selected', 'true');
      LActiveId := LBtn.id;
      asm
        try { LBtn.scrollIntoView({ block: 'nearest' }); } catch (e) {}
      end;
    end
    else
      LBtn.setAttribute('aria-selected', 'false');
  end;
  if (FShellRenderer <> nil) and (FShellRenderer.Root <> nil) then
  begin
    LInput := FShellRenderer.InputFor('recipes-add-input');
    if LInput <> nil then
    begin
      if LActiveId <> '' then
        LInput.setAttribute('aria-activedescendant', LActiveId)
      else
        LInput.removeAttribute('aria-activedescendant');
    end;
  end;
end;

procedure TOracleRecipesModal.UpdateAddSuggestions(const AQuery: String);
var
  LHost: TJSHTMLElement;
  LInput: TJSHTMLElement;
  LDoc: TNyxDocument;
  LList: TNyxNode;
  LIndex: Integer;
  LCandidate: TRecipeIngredientCandidate;
  LBtnId: String;
  LBtn: TJSHTMLElement;
  LNameSpan: TJSHTMLElement;
  LCountSpan: TJSHTMLElement;
  LCountText: String;
  LInfo: TResearchIngredientInfo;

  procedure BindOption(const AId, AName: String);
  begin
    LBtn := FAddSuggestRenderer.ElementFor(AId);
    LBtn.id := AId;
    LBtn.setAttribute('role', 'option');
    LBtn.setAttribute('aria-selected', 'false');
    BindHandler(LBtn, 'mousedown',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        AEvent.preventDefault;
        Result := False;
      end);
    BindHandler(LBtn, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        PickAddSuggestion(AName);
        Result := True;
      end);
  end;

begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) or
    (FShellRenderer.Root.Find('recipes-add-suggestions') = nil) then
    Exit;
  if FCatalog = nil then
  begin
    HideAddSuggestions;
    Exit;
  end;
  FAddCandidates := FCatalog.SuggestExtraIngredients(FMainIngredient, FExtraIngredients,
    FCategory, AQuery, 8);
  FAddHighlight := -1;
  LHost := FShellRenderer.ElementFor('recipes-add-suggestions');
  LInput := FShellRenderer.InputFor('recipes-add-input');
  if Length(FAddCandidates) = 0 then
  begin
    HideAddSuggestions;
    Exit;
  end;

  LDoc := TNyxDocument.Create;
  LList := MakeNode(nkColumn, 'recipes-add-suggestions-list');
  LDoc.AddPage(LList);
  for LIndex := 0 to High(FAddCandidates) do
  begin
    LCandidate := FAddCandidates[LIndex];
    LBtnId := 'recipes-add-opt-' + IntToStr(LIndex);
    if LCandidate.MatchCount = 1 then
      LCountText := '1 recipe'
    else if LCandidate.MatchCount > 1 then
      LCountText := IntToStr(LCandidate.MatchCount) + ' recipes'
    else
      LCountText := 'Other recipes';
    LList.Add(MakeButton(LBtnId, Capitalized(LCandidate.Name), nvSecondary)
      .Configure.AccessibleName(Capitalized(LCandidate.Name) + ' (' + LCountText + ')').Done);
  end;

  FAddSuggestRenderer.Render(LDoc, LList, LHost);
  FAddSuggestDoc.Free;
  FAddSuggestDoc := LDoc;

  for LIndex := 0 to High(FAddCandidates) do
  begin
    LCandidate := FAddCandidates[LIndex];
    LBtnId := 'recipes-add-opt-' + IntToStr(LIndex);
    BindOption(LBtnId, LCandidate.Name);
    LBtn := FAddSuggestRenderer.ElementFor(LBtnId);
    LInfo := LookupPool(LCandidate.Name);
    if LInfo.InPool and (LInfo.Trend <> '') then
      LBtn.setAttribute('data-trend', LInfo.Trend);
    if LCandidate.MatchCount = 0 then
      LBtn.setAttribute('data-other-catalog', 'true');
    LBtn.textContent := '';
    LNameSpan := TJSHTMLElement(document.createElement('span'));
    LNameSpan.className := 'recipes-add-opt-name';
    LNameSpan.textContent := Capitalized(LCandidate.Name);
    LBtn.appendChild(LNameSpan);
    LCountSpan := TJSHTMLElement(document.createElement('span'));
    LCountSpan.className := 'recipes-add-opt-count';
    if LCandidate.MatchCount = 1 then
      LCountSpan.textContent := '1 recipe'
    else if LCandidate.MatchCount > 1 then
      LCountSpan.textContent := IntToStr(LCandidate.MatchCount) + ' recipes'
    else
      LCountSpan.textContent := 'Other recipes';
    LBtn.appendChild(LCountSpan);
  end;

  FAddSuggestOpen := True;
  LHost.hidden := False;
  if LInput <> nil then
    LInput.setAttribute('aria-expanded', 'true');
  KeepAddInputVisible;
end;

procedure TOracleRecipesModal.PickAddSuggestion(const AName: String);
var
  LInput: TJSHTMLInputElement;
  LValue: String;
  LLastSep: Integer;
  LIndex: Integer;
  LCombined: String;
begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  if FBlurTimer <> 0 then
  begin
    window.clearTimeout(FBlurTimer);
    FBlurTimer := 0;
  end;
  LInput := TJSHTMLInputElement(FShellRenderer.InputFor('recipes-add-input'));
  LValue := LInput.value;
  LLastSep := 0;
  for LIndex := Length(LValue) downto 1 do
  begin
    if (LValue[LIndex] = ',') or (LValue[LIndex] = ';') or
      (LValue[LIndex] = #10) or (LValue[LIndex] = #13) then
    begin
      LLastSep := LIndex;
      Break;
    end;
  end;
  if LLastSep > 0 then
    LCombined := Copy(LValue, 1, LLastSep) + ' ' + AName
  else
    LCombined := AName;
  LInput.value := '';
  AddIngredientsFromText(LCombined);
  HideAddSuggestions;
  if (window.innerWidth <= 780) or (window.innerHeight <= 540) then
  begin
    LInput.blur;
    SetAddInputFocused(False);
  end
  else
    NyxFocusWithoutScroll(LInput);
end;

procedure TOracleRecipesModal.CommitAddInput;
var
  LInput: TJSHTMLInputElement;
  LRaw: String;
begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  if FBlurTimer <> 0 then
  begin
    window.clearTimeout(FBlurTimer);
    FBlurTimer := 0;
  end;
  LInput := TJSHTMLInputElement(FShellRenderer.InputFor('recipes-add-input'));
  LRaw := Trim(LInput.value);
  if LRaw <> '' then
    AddIngredientsFromText(LRaw);
  LInput.value := '';
  HideAddSuggestions;
  if (window.innerWidth <= 780) or (window.innerHeight <= 540) then
  begin
    LInput.blur;
    SetAddInputFocused(False);
  end
  else if LRaw <> '' then
    NyxFocusWithoutScroll(LInput);
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
  BindVisualViewport;

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
  if FBlurTimer <> 0 then
  begin
    window.clearTimeout(FBlurTimer);
    FBlurTimer := 0;
  end;
  SetAddInputFocused(False);
  HideAddSuggestions;
  UnbindVisualViewport;
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
    .Placeholder('Type an ingredient, e.g. olive oil, lemon').Done);
  LAddRow.Add(MakeButton('recipes-add-btn', 'Add', nvPrimary));
  LAddSection.Add(LAddRow);
  LAddSection.Add(MakeNode(nkColumn, 'recipes-add-suggestions'));
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
  UpdateMainChipTheme;

  BindHandler(FShellRenderer.ElementFor('recipes-close'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Close;
      Result := True;
    end);

  LInput := TJSHTMLInputElement(FShellRenderer.InputFor('recipes-add-input'));
  LInput.setAttribute('role', 'combobox');
  LInput.setAttribute('aria-autocomplete', 'list');
  LInput.setAttribute('aria-expanded', 'false');
  LInput.setAttribute('aria-controls', 'recipes-add-suggestions');
  LInput.setAttribute('autocomplete', 'off');
  LInput.setAttribute('autocorrect', 'off');
  LInput.setAttribute('autocapitalize', 'none');
  LInput.setAttribute('spellcheck', 'false');
  LInput.setAttribute('enterkeyhint', 'done');
  FShellRenderer.ElementFor('recipes-add-suggestions').id := 'recipes-add-suggestions';
  FShellRenderer.ElementFor('recipes-add-suggestions').setAttribute('role', 'listbox');
  FShellRenderer.ElementFor('recipes-add-suggestions').setAttribute('aria-label', 'Matching recipe ingredients');
  FShellRenderer.ElementFor('recipes-add-suggestions').hidden := True;

  BindHandler(FShellRenderer.ElementFor('recipes-add-btn'), 'mousedown',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      AEvent.preventDefault;
      Result := False;
    end);
  BindHandler(FShellRenderer.ElementFor('recipes-add-btn'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      CommitAddInput;
      Result := True;
    end);
  BindHandler(LInput, 'focus',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if FBlurTimer <> 0 then
      begin
        window.clearTimeout(FBlurTimer);
        FBlurTimer := 0;
      end;
      SetAddInputFocused(True);
      UpdateAddSuggestions(LInput.value);
      Result := True;
    end);
  BindHandler(LInput, 'input',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      UpdateAddSuggestions(LInput.value);
      Result := True;
    end);
  BindHandler(LInput, 'blur',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if FBlurTimer <> 0 then
        window.clearTimeout(FBlurTimer);
      FBlurTimer := window.setTimeout(
        procedure
        begin
          FBlurTimer := 0;
          if document.activeElement <> LInput then
          begin
            HideAddSuggestions;
            SetAddInputFocused(False);
          end;
        end, 180);
      Result := True;
    end);
  BindHandler(LInput, 'keydown',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LKey: String;
    begin
      LKey := TJSKeyboardEvent(AEvent).key;
      if LKey = 'ArrowDown' then
      begin
        if not FAddSuggestOpen then
          UpdateAddSuggestions(LInput.value);
        if Length(FAddCandidates) > 0 then
        begin
          AEvent.preventDefault;
          if FAddHighlight < High(FAddCandidates) then
            Inc(FAddHighlight)
          else
            FAddHighlight := 0;
          UpdateAddHighlightDOM;
        end;
      end
      else if LKey = 'ArrowUp' then
      begin
        if FAddSuggestOpen and (Length(FAddCandidates) > 0) then
        begin
          AEvent.preventDefault;
          if FAddHighlight > 0 then
            Dec(FAddHighlight)
          else
            FAddHighlight := High(FAddCandidates);
          UpdateAddHighlightDOM;
        end;
      end
      else if LKey = 'Escape' then
      begin
        if FAddSuggestOpen then
        begin
          AEvent.preventDefault;
          AEvent.stopPropagation;
          HideAddSuggestions;
        end;
      end
      else if LKey = 'Enter' then
      begin
        AEvent.preventDefault;
        if FAddSuggestOpen and (FAddHighlight >= 0) and
          (FAddHighlight <= High(FAddCandidates)) then
          PickAddSuggestion(FAddCandidates[FAddHighlight].Name)
        else
          CommitAddInput;
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
  var
    LInfo: TResearchIngredientInfo;
  begin
    LButton := FChipsRenderer.ElementFor(AId);
    LButton.setAttribute('aria-pressed', LowerCase(BoolToStr(AActive, True)));
    LInfo := LookupPool(AIngredient);
    if LInfo.InPool and (LInfo.Trend <> '') then
    begin
      LButton.setAttribute('data-trend', LInfo.Trend);
      LButton.setAttribute('title', Capitalized(AIngredient) + ' · ' +
        ResearchIngredientTrendText(LInfo.Trend));
    end;
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
  LIngName: String;
  LIngId: String;
  LIngInfo: TResearchIngredientInfo;
  LIsMain: Boolean;
  LIsExtra: Boolean;
  LTrendText: String;
  LAccessible: String;

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
      begin
        LIngName := LIngredients[LSubIndex];
        LIngId := 'recipe-ing-' + LTag + '-' + IntToStr(LSubIndex);
        LIngInfo := LookupPool(LIngName);
        LIsMain := (LIngName = FMainIngredient) or
          (LIngInfo.InPool and (LowerCase(LIngInfo.Canonical) = LowerCase(FMainIngredient)));
        if LIngInfo.InPool and (not LIsMain) then
        begin
          LTrendText := ResearchIngredientTrendText(LIngInfo.Trend);
          LAccessible := Capitalized(LIngName);
          if LTrendText <> '' then
            LAccessible := LAccessible + ' (' + LTrendText + ')';
          LAccessible := LAccessible + ' — open research details in a new tab';
          LIngRow.Add(MakeNode(nkLink, LIngId, Capitalized(LIngName))
            .Configure.LinkTo(ResearchIngredientURL(LIngInfo))
            .AccessibleName(LAccessible).Done);
        end
        else
          LIngRow.Add(MakeNode(nkBadge, LIngId, Capitalized(LIngName)));
      end;
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
        LIngName := LIngredients[LSubIndex];
        LBadge := FCardsRenderer.ElementFor('recipe-ing-' + LTag + '-' + IntToStr(LSubIndex));
        LIngInfo := LookupPool(LIngName);
        LIsMain := (LIngName = FMainIngredient) or
          (LIngInfo.InPool and (LowerCase(LIngInfo.Canonical) = LowerCase(FMainIngredient)));
        LIsExtra := (not LIsMain) and HasExtra(FExtraIngredients, LIngName);
        LTrendText := ResearchIngredientTrendText(LIngInfo.Trend);
        if LIngInfo.InPool then
        begin
          LBadge.setAttribute('data-in-pool', 'true');
          if LIngInfo.Trend <> '' then
            LBadge.setAttribute('data-trend', LIngInfo.Trend);
        end;
        if LIsMain then
        begin
          LBadge.setAttribute('data-match', 'main');
          if LTrendText <> '' then
            LBadge.setAttribute('title', Capitalized(LIngName) + ' · Primary ingredient · ' + LTrendText)
          else
            LBadge.setAttribute('title', Capitalized(LIngName) + ' · Primary ingredient');
        end
        else if LIngInfo.InPool then
        begin
          LBadge.setAttribute('target', '_blank');
          LBadge.setAttribute('rel', 'noopener noreferrer');
          if LIsExtra then
            LBadge.setAttribute('data-match', 'extra');
          if LTrendText <> '' then
            LBadge.setAttribute('title', Capitalized(LIngName) + ' · ' + LTrendText +
              ' — open research details in new tab')
          else
            LBadge.setAttribute('title', Capitalized(LIngName) +
              ' · In research pool — open research details in new tab');
        end
        else if LIsExtra then
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
