{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclerecipepage;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses
  SysUtils, JS, Web, nyx.model, nyx.types, nyx.render.browser,
  oraclestatic, oraclevocab, parkinsonsoracle.recipes;

type
  TRecipeFilterLoader = reference to procedure(AReply: TOracleReply);

  TOracleRecipePage = class
  private
    FRenderer: TNyxBrowserRenderer;
    FDoc: TNyxDocument;
    FCatalog: TRecipeCatalog;
    FResearchPool: TOracleResearchPool;
    FRecipe: TRecipe;
    FRecipeId: String;
    FLoading: Boolean;
    FError: String;
    FScale: Double;
    FCookMode: Boolean;
    FLargeText: Boolean;
    FWakeLockActive: Boolean;
    FWakeLockSentinel: JSValue;
    FCheckedIngredients: array of Boolean;
    FDoneSteps: array of Boolean;
    FVisibilityHandler: TJSEventHandler;
    function LookupPool(const AIngredient: String): TResearchIngredientInfo;
    procedure Render;
    procedure RenderStateCard(const ATitle, AMessage: String);
    procedure RenderRecipe;
    procedure SetScale(AScale: Double);
    procedure ToggleIngredient(AIndex: Integer);
    procedure ClearIngredientChecks;
    procedure ToggleStep(AIndex: Integer);
    procedure ClearStepChecks;
    procedure ToggleCookMode;
    procedure ToggleLargeText;
    procedure RequestWakeLock;
    procedure ReleaseWakeLock;
    function OnVisibilityChange(AEvent: TEventListenerEvent): Boolean;
    function BuildClipboardIngredientsText: String;
    procedure CopyTextWithFeedback(const AText, AButtonId, ADefaultLabel, AConfirmLabel: String);
    procedure ApplyViewAttributes;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Mount(const ARecipeId: String; AFilterLoader: TRecipeFilterLoader = nil);
  end;

function ReadRequestedRecipeId: String;

implementation

uses
  StrUtils, Math;

const
  CScaleFactors: array[0..3] of Double = (0.5, 1.0, 2.0, 3.0);
  CScaleLabels: array[0..3] of String = ('½×', '1×', '2×', '3×');

function DecodeURIComponentSafe(const AText: String): String;
begin
  try
    asm
      return decodeURIComponent(AText.replace(/\+/g, ' '));
    end;
  except
    Result := AText;
  end;
end;

function ExtractRecipeParam(const AQuery: String): String;
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
        if LKey = 'recipe' then
          Exit(Trim(DecodeURIComponentSafe(Copy(LPair, LEq + 1, MaxInt))));
      end;
      LStart := LIndex + 1;
    end;
  end;
end;

function ReadRequestedRecipeId: String;
begin
  Result := ExtractRecipeParam(window.location.search);
  if Result = '' then
    Result := ExtractRecipeParam(window.location.hash);
end;

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
  if AElement <> nil then
    AElement.addEventListener(AEventName, AHandler);
end;

type
  TRecipeCopyDone = reference to procedure;

procedure CopyStringToClipboard(const AText: String; AOnDone: TRecipeCopyDone);
begin
  asm
    var done = function() { if (AOnDone) { AOnDone(); } };
    var fallback = function() {
      try {
        var ta = document.createElement('textarea');
        ta.value = AText;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
      } catch (e) {}
      done();
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(AText).then(done, fallback);
    } else {
      fallback();
    }
  end;
end;

function AnyTrue(const AValues: array of Boolean): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AValues) do
    if AValues[LIndex] then
      Exit(True);
  Result := False;
end;

function CountTrue(const AValues: array of Boolean): Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to High(AValues) do
    if AValues[LIndex] then
      Inc(Result);
end;

{ TOracleRecipePage }

constructor TOracleRecipePage.Create;
begin
  inherited Create;
  FRenderer := TNyxBrowserRenderer.Create;
  FScale := 1.0;
  FVisibilityHandler := @OnVisibilityChange;
  document.addEventListener('visibilitychange', FVisibilityHandler);
end;

destructor TOracleRecipePage.Destroy;
begin
  ReleaseWakeLock;
  if Assigned(FVisibilityHandler) then
    document.removeEventListener('visibilitychange', FVisibilityHandler);
  if FRenderer <> nil then
  begin
    FRenderer.Unmount;
    FRenderer.Free;
  end;
  FDoc.Free;
  FCatalog.Free;
  FResearchPool.Free;
  inherited Destroy;
end;

function TOracleRecipePage.LookupPool(const AIngredient: String): TResearchIngredientInfo;
begin
  if FResearchPool <> nil then
    Result := FResearchPool.Lookup(AIngredient)
  else
    Result := Default(TResearchIngredientInfo);
end;

procedure TOracleRecipePage.Mount(const ARecipeId: String; AFilterLoader: TRecipeFilterLoader);
var
  LHost: TJSHTMLElement;
begin
  FRecipeId := Trim(ARecipeId);
  FLoading := True;
  FError := '';
  FRecipe := nil;
  FScale := 1.0;
  FCookMode := False;
  FLargeText := False;

  LHost := TJSHTMLElement(document.getElementById('oracle'));
  if LHost <> nil then
    LHost.setAttribute('data-oracle-recipe-page', 'true');
  document.body.setAttribute('data-oracle-recipe-page', 'true');

  Render;

  if Assigned(AFilterLoader) then
    AFilterLoader(
      procedure(AData: TJSObject; const AError: String)
      begin
        if (AError = '') and (AData <> nil) then
        begin
          if FResearchPool = nil then
            FResearchPool := TOracleResearchPool.Create;
          FResearchPool.LoadFromFilterIngredients(VocabularyItems(AData, 'ingredients'));
          if FRecipe <> nil then
            Render;
        end;
      end);

  GetOracleAsset('./recipes.json',
    procedure(AData: TJSObject; const AError: String)
    var
      LLoaded: TRecipeCatalog;
      LDetailCount: Integer;
    begin
      FLoading := False;
      if AError <> '' then
      begin
        FError := 'Unable to load this recipe right now. Please try refreshing the page.';
      end
      else
      begin
        LLoaded := TRecipeCatalog.Create;
        try
          LLoaded.LoadFromJSObject(AData, False);
          FCatalog.Free;
          FCatalog := LLoaded;
          LLoaded := nil;
          FRecipe := FCatalog.FindById(FRecipeId);
          if FRecipe <> nil then
          begin
            document.title := FRecipe.Title + ' · Recipes · The Parkinson’s Cookbook';
            LDetailCount := Length(FRecipe.IngredientDetails);
            if LDetailCount = 0 then
              LDetailCount := Length(FRecipe.Ingredients);
            SetLength(FCheckedIngredients, LDetailCount);
            SetLength(FDoneSteps, Length(FRecipe.Steps));
          end
          else
            document.title := 'Recipe not found · The Parkinson’s Cookbook';
        except
          on E: Exception do
          begin
            LLoaded.Free;
            FError := 'Unable to load this recipe right now. Please try refreshing the page.';
          end;
        end;
      end;
      Render;
    end);
end;

procedure TOracleRecipePage.ApplyViewAttributes;
var
  LHost: TJSHTMLElement;
begin
  LHost := TJSHTMLElement(document.getElementById('oracle'));
  if LHost = nil then
    Exit;
  if FCookMode then
    LHost.setAttribute('data-cook-mode', 'true')
  else
    LHost.removeAttribute('data-cook-mode');
  if FLargeText then
    LHost.setAttribute('data-large-text', 'true')
  else
    LHost.removeAttribute('data-large-text');
end;

procedure TOracleRecipePage.RequestWakeLock;
var
  LSelf: TOracleRecipePage;
begin
  LSelf := Self;
  asm
    if (navigator.wakeLock && navigator.wakeLock.request) {
      navigator.wakeLock.request('screen').then(function(sentinel) {
        if (!LSelf.FCookMode) {
          try { sentinel.release(); } catch (e) {}
          return;
        }
        LSelf.FWakeLockSentinel = sentinel;
        LSelf.FWakeLockActive = true;
        sentinel.addEventListener('release', function() {
          LSelf.FWakeLockActive = false;
        });
      }).catch(function() {
        LSelf.FWakeLockActive = false;
      });
    }
  end;
end;

procedure TOracleRecipePage.ReleaseWakeLock;
var
  LSentinel: JSValue;
begin
  LSentinel := FWakeLockSentinel;
  FWakeLockSentinel := nil;
  FWakeLockActive := False;
  asm
    if (LSentinel && typeof LSentinel.release === 'function') {
      try { LSentinel.release(); } catch (e) {}
    }
  end;
end;

function TOracleRecipePage.OnVisibilityChange(AEvent: TEventListenerEvent): Boolean;
begin
  if FCookMode and (document.visibilityState = 'visible') and not FWakeLockActive then
    RequestWakeLock;
  Result := True;
end;

procedure TOracleRecipePage.SetScale(AScale: Double);
begin
  if Abs(FScale - AScale) < 0.001 then
    Exit;
  FScale := AScale;
  Render;
end;

procedure TOracleRecipePage.ToggleIngredient(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FCheckedIngredients)) then
    Exit;
  FCheckedIngredients[AIndex] := not FCheckedIngredients[AIndex];
  Render;
end;

procedure TOracleRecipePage.ClearIngredientChecks;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FCheckedIngredients) do
    FCheckedIngredients[LIndex] := False;
  Render;
end;

procedure TOracleRecipePage.ToggleStep(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex > High(FDoneSteps)) then
    Exit;
  FDoneSteps[AIndex] := not FDoneSteps[AIndex];
  Render;
end;

procedure TOracleRecipePage.ClearStepChecks;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FDoneSteps) do
    FDoneSteps[LIndex] := False;
  Render;
end;

procedure TOracleRecipePage.ToggleCookMode;
begin
  FCookMode := not FCookMode;
  if FCookMode then
    RequestWakeLock
  else
    ReleaseWakeLock;
  Render;
end;

procedure TOracleRecipePage.ToggleLargeText;
begin
  FLargeText := not FLargeText;
  Render;
end;

function TOracleRecipePage.BuildClipboardIngredientsText: String;
var
  LIndex: Integer;
begin
  if FRecipe = nil then
    Exit('');
  Result := FRecipe.Title + ' (' + FormatScaledServings(FRecipe.Servings, FScale) + ')' + #10 +
    'Ingredients:' + #10;
  if Length(FRecipe.IngredientDetails) > 0 then
  begin
    for LIndex := 0 to High(FRecipe.IngredientDetails) do
      Result := Result + '- ' + FormatIngredientLine(FRecipe.IngredientDetails[LIndex], FScale) + #10;
  end
  else
  begin
    for LIndex := 0 to High(FRecipe.Ingredients) do
      Result := Result + '- ' + Capitalized(FRecipe.Ingredients[LIndex]) + #10;
  end;
end;

procedure TOracleRecipePage.CopyTextWithFeedback(const AText, AButtonId,
  ADefaultLabel, AConfirmLabel: String);
var
  LButton: TJSHTMLElement;
begin
  CopyStringToClipboard(AText,
    procedure
    begin
      LButton := FRenderer.ElementFor(AButtonId);
      if LButton <> nil then
      begin
        LButton.textContent := AConfirmLabel;
        window.setTimeout(
          procedure
          var
            LCurrent: TJSHTMLElement;
          begin
            if (FRenderer <> nil) and (FRenderer.Root <> nil) and
              (FRenderer.Root.Find(AButtonId) <> nil) then
            begin
              LCurrent := FRenderer.ElementFor(AButtonId);
              if LCurrent <> nil then
                LCurrent.textContent := ADefaultLabel;
            end;
          end, 2000);
      end;
    end);
end;

procedure TOracleRecipePage.Render;
begin
  ApplyViewAttributes;
  if FLoading then
    RenderStateCard('Loading recipe…', 'Getting your recipe sheet ready.')
  else if FError <> '' then
    RenderStateCard('Recipe unavailable', FError)
  else if FRecipe = nil then
    RenderStateCard('Recipe not found',
      'We could not find a recipe matching this link. Return to The Parkinson’s Cookbook to browse available recipes.')
  else
    RenderRecipe;
end;

procedure TOracleRecipePage.RenderStateCard(const ATitle, AMessage: String);
var
  LDoc: TNyxDocument;
  LPage: TNyxNode;
  LTopbar: TNyxNode;
  LCard: TNyxNode;
  LHost: TJSHTMLElement;
begin
  LHost := TJSHTMLElement(document.getElementById('oracle'));
  if LHost = nil then
    Exit;
  LDoc := TNyxDocument.Create;
  LPage := MakeNode(nkPage, 'recipe-sheet-page');
  LDoc.AddPage(LPage);

  LTopbar := MakeNode(nkRow, 'recipe-sheet-topbar');
  LTopbar.Add(MakeNode(nkLink, 'recipe-sheet-back', '← Back to The Parkinson’s Cookbook')
    .Configure.LinkTo('./').Done);
  LPage.Add(LTopbar);

  LCard := MakeNode(nkCard, 'recipe-sheet-state-card');
  LCard.Add(MakeNode(nkHeading, 'recipe-sheet-state-title', ATitle));
  LCard.Add(MakeNode(nkLabel, 'recipe-sheet-state-message', AMessage));
  LCard.Add(MakeNode(nkLink, 'recipe-sheet-state-home', 'Browse The Parkinson’s Cookbook')
    .Configure.LinkTo('./').Done);
  LPage.Add(LCard);

  FRenderer.Render(LDoc, LPage, LHost);
  FDoc.Free;
  FDoc := LDoc;
end;

procedure TOracleRecipePage.RenderRecipe;
var
  LDoc: TNyxDocument;
  LPage: TNyxNode;
  LTopbar: TNyxNode;
  LTools: TNyxNode;
  LHero: TNyxNode;
  LBadges: TNyxNode;
  LIngPills: TNyxNode;
  LMetaGrid: TNyxNode;
  LBody: TNyxNode;
  LIngCol: TNyxNode;
  LIngCard: TNyxNode;
  LIngHeader: TNyxNode;
  LScaleGroup: TNyxNode;
  LIngList: TNyxNode;
  LIngRow: TNyxNode;
  LEquipCard: TNyxNode;
  LEquipList: TNyxNode;
  LDirCol: TNyxNode;
  LDirCard: TNyxNode;
  LDirHeader: TNyxNode;
  LStepsList: TNyxNode;
  LStepRow: TNyxNode;
  LTipsCard: TNyxNode;
  LTipsList: TNyxNode;
  LHost: TJSHTMLElement;
  LIndex: Integer;
  LTag: String;
  LMeasure: String;
  LLine: String;
  LScaleBtn: TJSHTMLElement;
  LRowEl: TJSHTMLElement;
  LTextWrap: TJSHTMLElement;
  LQtySpan: TJSHTMLElement;
  LNameSpan: TJSHTMLElement;
  LNoteSpan: TJSHTMLElement;
  LDoneCount: Integer;
  LHasDetails: Boolean;
  LDetail: TRecipeIngredientDetail;
  LPillName: String;
  LPillId: String;
  LPillInfo: TResearchIngredientInfo;
  LPillIsMain: Boolean;
  LPillTrendText: String;
  LPillLabel: String;
  LPillEl: TJSHTMLElement;

  procedure AddMetaTile(const AId, ALabel, AValue: String);
  var
    LTile: TNyxNode;
  begin
    LTile := MakeNode(nkColumn, AId);
    LTile.Add(MakeNode(nkLabel, AId + '-label', ALabel));
    LTile.Add(MakeNode(nkLabel, AId + '-value', AValue));
    LMetaGrid.Add(LTile);
  end;

  procedure BindScaleButton(const AId: String; AScaleValue: Double);
  begin
    LScaleBtn := FRenderer.ElementFor(AId);
    LScaleBtn.setAttribute('aria-pressed',
      LowerCase(BoolToStr(Abs(FScale - AScaleValue) < 0.001, True)));
    BindHandler(LScaleBtn, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        SetScale(AScaleValue);
        Result := True;
      end);
  end;

  procedure BindIngredientToggle(const AId: String; AIdx: Integer; AChecked, AIsCore: Boolean);
  begin
    LRowEl := FRenderer.ElementFor(AId);
    LRowEl.setAttribute('aria-pressed', LowerCase(BoolToStr(AChecked, True)));
    if AChecked then
      LRowEl.setAttribute('data-checked', 'true');
    if AIsCore then
      LRowEl.setAttribute('data-core', 'true');
    BindHandler(LRowEl, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ToggleIngredient(AIdx);
        Result := True;
      end);
  end;

  procedure BindStepToggle(const AId: String; AIdx: Integer; ADone: Boolean);
  begin
    LRowEl := FRenderer.ElementFor(AId);
    LRowEl.setAttribute('aria-pressed', LowerCase(BoolToStr(ADone, True)));
    if ADone then
      LRowEl.setAttribute('data-done', 'true');
    BindHandler(LRowEl, 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ToggleStep(AIdx);
        Result := True;
      end);
  end;

begin
  LHost := TJSHTMLElement(document.getElementById('oracle'));
  if (LHost = nil) or (FRecipe = nil) then
    Exit;

  LDoc := TNyxDocument.Create;
  LPage := MakeNode(nkPage, 'recipe-sheet-page');
  LDoc.AddPage(LPage);

  // Sticky top utility toolbar (hidden on print)
  LTopbar := MakeNode(nkRow, 'recipe-sheet-topbar');
  LTopbar.Add(MakeNode(nkLink, 'recipe-sheet-back', '← Back to The Parkinson’s Cookbook')
    .Configure.LinkTo('./').Done);

  LTools := MakeNode(nkRow, 'recipe-sheet-tools');
  LTools.Add(MakeButton('recipe-sheet-print', 'Print recipe', nvPrimary));
  LTools.Add(MakeButton('recipe-sheet-copy-ing', 'Copy ingredients', nvSecondary));
  LTools.Add(MakeButton('recipe-sheet-copy-link', 'Copy link', nvSecondary));
  LTools.Add(MakeButton('recipe-sheet-cook-mode',
    IfThen(FCookMode, 'Cook mode: On', 'Cook mode'), nvSecondary)
    .Configure.Pressed(FCookMode)
    .AccessibleName('Toggle cook mode to keep screen awake and enlarge layout').Done);
  LTools.Add(MakeButton('recipe-sheet-large-text',
    IfThen(FLargeText, 'Text: Large', 'Large text'), nvSecondary)
    .Configure.Pressed(FLargeText)
    .AccessibleName('Toggle larger text for easier reading').Done);
  LTopbar.Add(LTools);
  LPage.Add(LTopbar);

  // Recipe Header & Meta Bar
  LHero := MakeNode(nkCard, 'recipe-sheet-hero');
  LBadges := MakeNode(nkRow, 'recipe-sheet-badges');
  LBadges.Add(MakeNode(nkBadge, 'recipe-sheet-cat', RecipeCategoryLabel(FRecipe.Category)));
  LBadges.Add(MakeNode(nkBadge, 'recipe-sheet-effort', RecipeEffortLabel(FRecipe.Effort)));
  LBadges.Add(MakeNode(nkBadge, 'recipe-sheet-core',
    'Main ingredient: ' + Capitalized(FRecipe.CoreIngredient)));
  LHero.Add(LBadges);

  LHero.Add(MakeNode(nkHeading, 'recipe-sheet-title', FRecipe.Title));
  LHero.Add(MakeNode(nkLabel, 'recipe-sheet-summary', FRecipe.Summary));

  if Length(FRecipe.Ingredients) > 0 then
  begin
    LIngPills := MakeNode(nkRow, 'recipe-sheet-ing-pills');
    for LIndex := 0 to High(FRecipe.Ingredients) do
    begin
      LPillName := FRecipe.Ingredients[LIndex];
      LPillId := 'recipe-sheet-ing-pill-' + IntToStr(LIndex);
      LPillInfo := LookupPool(LPillName);
      if LPillInfo.InPool then
      begin
        LPillTrendText := ResearchIngredientTrendText(LPillInfo.Trend);
        LPillLabel := Capitalized(LPillName);
        if LPillTrendText <> '' then
          LPillLabel := LPillLabel + ' (' + LPillTrendText + ')';
        LPillLabel := LPillLabel + ' — open research details in a new tab';
        LIngPills.Add(MakeNode(nkLink, LPillId, Capitalized(LPillName))
          .Configure.LinkTo(ResearchIngredientURL(LPillInfo))
          .AccessibleName(LPillLabel).Done);
      end
      else
        LIngPills.Add(MakeNode(nkBadge, LPillId, Capitalized(LPillName)));
    end;
    LHero.Add(LIngPills);
  end;

  LMetaGrid := MakeNode(nkGrid, 'recipe-sheet-meta');
  AddMetaTile('recipe-meta-prep', 'Prep time', FormatMinutesLabel(FRecipe.PrepMinutes));
  AddMetaTile('recipe-meta-cook', 'Cook time', FormatMinutesLabel(FRecipe.CookMinutes));
  AddMetaTile('recipe-meta-total', 'Total time', FormatMinutesLabel(FRecipe.TotalMinutes));
  AddMetaTile('recipe-meta-servings', 'Servings',
    FormatScaledServings(FRecipe.Servings, FScale));
  LHero.Add(LMetaGrid);
  LPage.Add(LHero);

  // Main 2-column cooking layout
  LBody := MakeNode(nkGrid, 'recipe-sheet-body');

  // Left Column: Ingredients + Serving Scaler + Equipment
  LIngCol := MakeNode(nkColumn, 'recipe-sheet-ingredients-col');
  LIngCard := MakeNode(nkCard, 'recipe-sheet-ingredients-card');

  LIngHeader := MakeNode(nkRow, 'recipe-sheet-ingredients-header');
  LIngHeader.Add(MakeNode(nkHeading, 'recipe-sheet-ingredients-title', 'Ingredients'));
  LScaleGroup := MakeNode(nkRow, 'recipe-sheet-scale-group');
  for LIndex := Low(CScaleFactors) to High(CScaleFactors) do
    LScaleGroup.Add(MakeButton('recipe-scale-' + IntToStr(LIndex), CScaleLabels[LIndex], nvSecondary)
      .Configure.Pressed(Abs(FScale - CScaleFactors[LIndex]) < 0.001)
      .AccessibleName('Scale recipe to ' + CScaleLabels[LIndex]).Done);
  LIngHeader.Add(LScaleGroup);
  LIngCard.Add(LIngHeader);

  if AnyTrue(FCheckedIngredients) then
    LIngCard.Add(MakeButton('recipe-sheet-clear-ing',
      'Clear checked (' + IntToStr(CountTrue(FCheckedIngredients)) + ')', nvSecondary));

  LIngList := MakeNode(nkColumn, 'recipe-sheet-ingredients-list');
  LHasDetails := Length(FRecipe.IngredientDetails) > 0;
  if LHasDetails then
  begin
    for LIndex := 0 to High(FRecipe.IngredientDetails) do
    begin
      LDetail := FRecipe.IngredientDetails[LIndex];
      LTag := IntToStr(LIndex);
      LLine := FormatIngredientLine(LDetail, FScale);
      LIngRow := MakeButton('recipe-ing-check-' + LTag, LLine, nvSecondary)
        .Configure.Pressed(FCheckedIngredients[LIndex])
        .AccessibleName(IfThen(FCheckedIngredients[LIndex], 'Uncheck ', 'Check off ') + LLine).Done;
      LIngList.Add(LIngRow);
    end;
  end
  else
  begin
    for LIndex := 0 to High(FRecipe.Ingredients) do
    begin
      LTag := IntToStr(LIndex);
      LLine := Capitalized(FRecipe.Ingredients[LIndex]);
      LIngRow := MakeButton('recipe-ing-check-' + LTag, LLine, nvSecondary)
        .Configure.Pressed(FCheckedIngredients[LIndex])
        .AccessibleName(IfThen(FCheckedIngredients[LIndex], 'Uncheck ', 'Check off ') + LLine).Done;
      LIngList.Add(LIngRow);
    end;
  end;
  LIngCard.Add(LIngList);
  LIngCol.Add(LIngCard);

  if Length(FRecipe.Equipment) > 0 then
  begin
    LEquipCard := MakeNode(nkCard, 'recipe-sheet-equipment-card');
    LEquipCard.Add(MakeNode(nkHeading, 'recipe-sheet-equipment-title', 'Equipment'));
    LEquipList := MakeNode(nkRow, 'recipe-sheet-equipment-list');
    for LIndex := 0 to High(FRecipe.Equipment) do
      LEquipList.Add(MakeNode(nkBadge, 'recipe-equip-' + IntToStr(LIndex),
        FRecipe.Equipment[LIndex]));
    LEquipCard.Add(LEquipList);
    LIngCol.Add(LEquipCard);
  end;
  LBody.Add(LIngCol);

  // Right Column: Interactive Directions + Kitchen Tips
  LDirCol := MakeNode(nkColumn, 'recipe-sheet-directions-col');
  LDirCard := MakeNode(nkCard, 'recipe-sheet-directions-card');

  LDirHeader := MakeNode(nkRow, 'recipe-sheet-directions-header');
  LDirHeader.Add(MakeNode(nkHeading, 'recipe-sheet-directions-title', 'Directions'));
  LDoneCount := CountTrue(FDoneSteps);
  if LDoneCount > 0 then
    LDirHeader.Add(MakeButton('recipe-sheet-clear-steps',
      'Reset steps (' + IntToStr(LDoneCount) + '/' + IntToStr(Length(FDoneSteps)) + ')',
      nvSecondary));
  LDirCard.Add(LDirHeader);

  LDirCard.Add(MakeNode(nkLabel, 'recipe-sheet-directions-hint',
    'Tap any step as you cook to check it off.'));

  LStepsList := MakeNode(nkColumn, 'recipe-sheet-steps-list');
  for LIndex := 0 to High(FRecipe.Steps) do
  begin
    LTag := IntToStr(LIndex);
    LStepRow := MakeButton('recipe-step-check-' + LTag, FRecipe.Steps[LIndex], nvSecondary)
      .Configure.Pressed(FDoneSteps[LIndex])
      .AccessibleName('Step ' + IntToStr(LIndex + 1) + ': ' + FRecipe.Steps[LIndex]).Done;
    LStepsList.Add(LStepRow);
  end;
  LDirCard.Add(LStepsList);
  LDirCol.Add(LDirCard);

  if Length(FRecipe.Tips) > 0 then
  begin
    LTipsCard := MakeNode(nkCard, 'recipe-sheet-tips-card');
    LTipsCard.Add(MakeNode(nkHeading, 'recipe-sheet-tips-title', 'Kitchen tips'));
    LTipsList := MakeNode(nkColumn, 'recipe-sheet-tips-list');
    for LIndex := 0 to High(FRecipe.Tips) do
      LTipsList.Add(MakeNode(nkLabel, 'recipe-tip-' + IntToStr(LIndex), FRecipe.Tips[LIndex]));
    LTipsCard.Add(LTipsList);
    LDirCol.Add(LTipsCard);
  end;

  LBody.Add(LDirCol);
  LPage.Add(LBody);

  LPage.Add(MakeNode(nkLabel, 'recipe-sheet-print-footer',
    'The Parkinson’s Cookbook · Recipes · ' + FRecipe.Title + ' · ' +
    FormatScaledServings(FRecipe.Servings, FScale)));

  FRenderer.Render(LDoc, LPage, LHost);
  FDoc.Free;
  FDoc := LDoc;

  // Bind category/effort color attributes & accessibility metadata
  FRenderer.ElementFor('recipe-sheet-cat').setAttribute('data-category',
    RecipeCategoryKey(FRecipe.Category));
  FRenderer.ElementFor('recipe-sheet-effort').setAttribute('data-effort',
    RecipeEffortKey(FRecipe.Effort));
  for LIndex := 0 to High(FRecipe.Ingredients) do
  begin
    LPillName := FRecipe.Ingredients[LIndex];
    LPillEl := FRenderer.ElementFor('recipe-sheet-ing-pill-' + IntToStr(LIndex));
    if LPillEl = nil then
      Continue;
    LPillInfo := LookupPool(LPillName);
    LPillIsMain := (LPillName = FRecipe.CoreIngredient) or
      (LPillInfo.InPool and (LowerCase(LPillInfo.Canonical) = LowerCase(FRecipe.CoreIngredient)));
    LPillTrendText := ResearchIngredientTrendText(LPillInfo.Trend);
    if LPillInfo.InPool then
    begin
      LPillEl.setAttribute('data-in-pool', 'true');
      LPillEl.setAttribute('target', '_blank');
      LPillEl.setAttribute('rel', 'noopener noreferrer');
      if LPillInfo.Trend <> '' then
        LPillEl.setAttribute('data-trend', LPillInfo.Trend);
      if LPillIsMain then
      begin
        if LPillTrendText <> '' then
          LPillEl.setAttribute('title', Capitalized(LPillName) +
            ' · Primary ingredient · ' + LPillTrendText + ' — open research details in new tab')
        else
          LPillEl.setAttribute('title', Capitalized(LPillName) +
            ' · Primary ingredient — open research details in new tab');
      end
      else if LPillTrendText <> '' then
        LPillEl.setAttribute('title', Capitalized(LPillName) + ' · ' + LPillTrendText +
          ' — open research details in new tab')
      else
        LPillEl.setAttribute('title', Capitalized(LPillName) +
          ' · In research pool — open research details in new tab');
    end;
    if LPillIsMain then
      LPillEl.setAttribute('data-match', 'main');
  end;
  FRenderer.ElementFor('recipe-sheet-scale-group').setAttribute('role', 'group');
  FRenderer.ElementFor('recipe-sheet-scale-group').setAttribute('aria-label', 'Scale servings');

  // Bind toolbar actions
  BindHandler(FRenderer.ElementFor('recipe-sheet-print'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      window.print;
      Result := True;
    end);
  BindHandler(FRenderer.ElementFor('recipe-sheet-copy-ing'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      CopyTextWithFeedback(BuildClipboardIngredientsText,
        'recipe-sheet-copy-ing', 'Copy ingredients', 'Copied!');
      Result := True;
    end);
  BindHandler(FRenderer.ElementFor('recipe-sheet-copy-link'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      CopyTextWithFeedback(window.location.href,
        'recipe-sheet-copy-link', 'Copy link', 'Link copied!');
      Result := True;
    end);
  BindHandler(FRenderer.ElementFor('recipe-sheet-cook-mode'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ToggleCookMode;
      Result := True;
    end);
  BindHandler(FRenderer.ElementFor('recipe-sheet-large-text'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ToggleLargeText;
      Result := True;
    end);

  for LIndex := Low(CScaleFactors) to High(CScaleFactors) do
    BindScaleButton('recipe-scale-' + IntToStr(LIndex), CScaleFactors[LIndex]);

  if AnyTrue(FCheckedIngredients) then
    BindHandler(FRenderer.ElementFor('recipe-sheet-clear-ing'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ClearIngredientChecks;
        Result := True;
      end);

  if LHasDetails then
  begin
    for LIndex := 0 to High(FRecipe.IngredientDetails) do
    begin
      LDetail := FRecipe.IngredientDetails[LIndex];
      LRowEl := FRenderer.ElementFor('recipe-ing-check-' + IntToStr(LIndex));
      LRowEl.textContent := '';
      LTextWrap := TJSHTMLElement(document.createElement('span'));
      LTextWrap.className := 'recipe-ing-text';
      LMeasure := FormatIngredientMeasure(LDetail, FScale);
      if LMeasure <> '' then
      begin
        LQtySpan := TJSHTMLElement(document.createElement('span'));
        LQtySpan.className := 'recipe-ing-qty';
        LQtySpan.textContent := LMeasure + ' ';
        LTextWrap.appendChild(LQtySpan);
      end;
      LNameSpan := TJSHTMLElement(document.createElement('span'));
      LNameSpan.className := 'recipe-ing-name';
      LNameSpan.textContent := LDetail.Item;
      LTextWrap.appendChild(LNameSpan);
      if Trim(LDetail.PrepNote) <> '' then
      begin
        LNoteSpan := TJSHTMLElement(document.createElement('span'));
        LNoteSpan.className := 'recipe-ing-note';
        LNoteSpan.textContent := ', ' + Trim(LDetail.PrepNote);
        LTextWrap.appendChild(LNoteSpan);
      end;
      LRowEl.appendChild(LTextWrap);
      BindIngredientToggle('recipe-ing-check-' + IntToStr(LIndex), LIndex,
        FCheckedIngredients[LIndex],
        LDetail.IngredientKey = FRecipe.CoreIngredient);
    end;
  end
  else
  begin
    for LIndex := 0 to High(FRecipe.Ingredients) do
      BindIngredientToggle('recipe-ing-check-' + IntToStr(LIndex), LIndex,
        FCheckedIngredients[LIndex],
        FRecipe.Ingredients[LIndex] = FRecipe.CoreIngredient);
  end;

  if LDoneCount > 0 then
    BindHandler(FRenderer.ElementFor('recipe-sheet-clear-steps'), 'click',
      function(AEvent: TEventListenerEvent): Boolean
      begin
        ClearStepChecks;
        Result := True;
      end);

  for LIndex := 0 to High(FRecipe.Steps) do
  begin
    LRowEl := FRenderer.ElementFor('recipe-step-check-' + IntToStr(LIndex));
    LRowEl.setAttribute('data-step-num', IntToStr(LIndex + 1));
    BindStepToggle('recipe-step-check-' + IntToStr(LIndex), LIndex, FDoneSteps[LIndex]);
  end;
end;

end.
