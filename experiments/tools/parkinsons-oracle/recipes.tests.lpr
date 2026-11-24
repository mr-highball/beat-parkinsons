{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program RecipesTests;

{$mode delphi}{$H+}{$codepage utf8}

uses
  SysUtils, parkinsonsoracle.recipes;

var
  GChecks: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create('FAIL: ' + AMessage);
  Inc(GChecks);
end;

procedure AssertUniqueRecipes(const ARecipes: TRecipeArray; const AContext: String);
var
  I, J: Integer;
begin
  for I := 0 to High(ARecipes) do
  begin
    Check(ARecipes[I] <> nil, AContext + ': non-nil recipe at slot ' + IntToStr(I));
    for J := I + 1 to High(ARecipes) do
      Check(ARecipes[I].Id <> ARecipes[J].Id,
        AContext + ': duplicate recipe ' + ARecipes[I].Id);
  end;
end;

procedure Run;
var
  LRepo: String;
  LDir: String;
  LCatalog: TRecipeCatalog;
  LRoundTrip: TRecipeCatalog;
  LSerialized: String;
  LCelery: TRecipeArray;
  LCeleryAlias: TRecipeArray;
  LCounts: TRecipeCategoryCounts;
  LCat: TRecipeConcreteCategory;
  LQuery: TRecipeWfcQuery;
  LRes1: TRecipeWfcResult;
  LRes2: TRecipeWfcResult;
  LRes3: TRecipeWfcResult;
  LSeenCat: array[TRecipeConcreteCategory] of Boolean;
  I: Integer;
  LDiffers: Boolean;
  LSuggestions: TRecipeStrings;
begin
  LRepo := '.';
  if ParamCount >= 1 then
    LRepo := ParamStr(1);
  LDir := IncludeTrailingPathDelimiter(ExpandFileName(LRepo)) +
    'experiments' + PathDelim + '1000_see_what_sticks_food_all_recipes' + PathDelim + 'recipes';

  LCatalog := TRecipeCatalog.Create;
  try
    LCatalog.LoadFromDirectory(LDir);
    Check(LCatalog.Count >= 25, 'Catalog loads at least 25 celery recipes.');

    // Verify core ingredient queryability (canonical + alias).
    LCelery := LCatalog.QueryByCoreIngredient('celery stalk');
    LCeleryAlias := LCatalog.QueryByCoreIngredient('celery');
    Check(Length(LCelery) >= 25, 'QueryByCoreIngredient(celery stalk) returns >= 25 recipes.');
    Check(Length(LCeleryAlias) = Length(LCelery), 'Alias "celery" queries same recipes.');
    Check(Length(LCatalog.QueryByCoreIngredient('black tea')) = 0,
      'Unpopulated core ingredient returns 0 recipes.');

    // Verify at least 5 low -> medium effort recipes in every category for celery.
    LCounts := LCatalog.CategoryCounts('celery stalk', nil);
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      Check(LCounts[LCat] >= 5, 'Category ' + RecipeCategoryKey(LCat) + ' has >= 5 recipes.');
    for I := 0 to High(LCelery) do
      Check(LCelery[I].Effort in [reLow, reMedium],
        'Celery recipe ' + LCelery[I].Id + ' is low or medium effort.');

    // Verify JSON serialization/deserialization round-trip.
    LSerialized := LCatalog.ToJSONString(False);
    LRoundTrip := TRecipeCatalog.Create;
    try
      LRoundTrip.LoadFromJSONString(LSerialized);
      Check(LRoundTrip.Count = LCatalog.Count, 'Round-trip preserves recipe count.');
      Check(LRoundTrip.Items[0].Id = LCatalog.Items[0].Id, 'Round-trip preserves first id.');
      Check(LRoundTrip.Items[0].CoreIngredient = 'celery stalk',
        'Round-trip preserves queryable CoreIngredient.');
      Check(LRoundTrip.Items[0].Title = LCatalog.Items[0].Title, 'Round-trip preserves title.');
      Check(Length(LRoundTrip.Items[0].Ingredients) = Length(LCatalog.Items[0].Ingredients),
        'Round-trip preserves ingredients.');
      Check(Length(LRoundTrip.Items[0].Steps) = Length(LCatalog.Items[0].Steps),
        'Round-trip preserves steps.');
    finally
      LRoundTrip.Free;
    end;

    // Verify WFC collapse on ALL category produces 10 non-repeating recipes spanning all 5 categories.
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'celery stalk';
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 101;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved, 'WFC ALL collapse solves cleanly.');
    Check(Length(LRes1.Recipes) = 10, 'WFC ALL collapse returns requested 10 recipes.');
    Check(LRes1.TotalCandidates >= 25, 'WFC ALL reports full candidate count.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC ALL');
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      LSeenCat[LCat] := False;
    for I := 0 to High(LRes1.Recipes) do
      LSeenCat[LRes1.Recipes[I].Category] := True;
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      Check(LSeenCat[LCat], 'WFC ALL collapse includes category ' + RecipeCategoryKey(LCat));

    // Verify deterministic replay with same seed, and variety across seeds.
    LRes2 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes2.Solved and (Length(LRes2.Recipes) = Length(LRes1.Recipes)),
      'WFC same-seed replay succeeds.');
    for I := 0 to High(LRes1.Recipes) do
      Check(LRes1.Recipes[I].Id = LRes2.Recipes[I].Id, 'Same seed produces identical collapse.');

    LQuery.Seed := 202;
    LRes3 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes3.Solved and (Length(LRes3.Recipes) = 10), 'Alternate seed collapses cleanly.');
    AssertUniqueRecipes(LRes3.Recipes, 'WFC alternate seed');
    LDiffers := False;
    for I := 0 to High(LRes1.Recipes) do
      if LRes1.Recipes[I].Id <> LRes3.Recipes[I].Id then
        LDiffers := True;
    Check(LDiffers, 'Different WFC seed produces a fresh selection.');

    // Verify single-category collapse (e.g. juices).
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'celery stalk';
    LQuery.Category := rcJuices;
    LQuery.MaxCount := 10;
    LQuery.Seed := 7;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) = 5), 'Juices collapse returns all 5 unique juices.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC juices');
    for I := 0 to High(LRes1.Recipes) do
      Check(LRes1.Recipes[I].Category = rcJuices, 'All collapsed juice cards have juices category.');

    // Verify arbitrary multi-ingredient constraints (e.g. "black pepper" + "onions").
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'celery stalk';
    LQuery.ExtraIngredients := ParseIngredientList('black pepper, onions');
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 11;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved, 'Multi-ingredient WFC collapse solves.');
    Check(Length(LRes1.Recipes) >= 5, 'Celery + black pepper + onions yields multiple recipes.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC multi-ingredient');
    for I := 0 to High(LRes1.Recipes) do
    begin
      Check(LRes1.Recipes[I].HasCoreIngredient('celery stalk'), 'Matches core ingredient.');
      Check(LRes1.Recipes[I].HasIngredient('black pepper'), 'Matches black pepper constraint.');
      Check(LRes1.Recipes[I].HasIngredient('onions'), 'Matches onions constraint.');
    end;

    // Verify unmatched arbitrary ingredient returns empty cleanly.
    LQuery.ExtraIngredients := ParseIngredientList('saffron');
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) = 0) and (LRes1.TotalCandidates = 0),
      'Unmatched extra ingredient returns empty cleanly without error.');

    // Verify sidebar suggestions list complementary ingredients excluding core ingredient.
    LSuggestions := LCatalog.AvailableExtraIngredients('celery stalk', 8);
    Check(Length(LSuggestions) = 8, 'Provides 8 complementary ingredient suggestions.');
    for I := 0 to High(LSuggestions) do
      Check(LSuggestions[I] <> 'celery stalk', 'Suggestions exclude core ingredient.');

    WriteLn(GChecks, ' recipe model and WFC checks passed.');
  finally
    LCatalog.Free;
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
