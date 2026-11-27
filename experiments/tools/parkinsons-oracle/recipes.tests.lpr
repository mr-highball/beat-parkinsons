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
const
  CPositiveLeanIngredients: array[0..128] of String = (
    'almond', 'almond oil', 'anise seed', 'annatto', 'apple', 'apricot',
    'artichoke', 'arugula', 'asparagus', 'banana', 'barley', 'basil',
    'bay leaf', 'beef', 'beetroot', 'bell pepper', 'black pepper',
    'black tea', 'blackberry', 'blueberry', 'brazil nut', 'broccoli',
    'brown rice', 'brussels sprouts', 'buckwheat groats', 'butternut squash',
    'button mushroom', 'cantaloupe', 'caraway', 'carrot', 'cashew',
    'cayenne pepper', 'celery leaf', 'celery seed', 'celery stalk',
    'chamomile', 'cherry', 'chia seed', 'chicken', 'chickpeas', 'cilantro',
    'cinnamon', 'clams', 'clove', 'coffee', 'coriander seed', 'cranberry',
    'cucumber', 'culinary lavender', 'cumin', 'curry leaf', 'dark chocolate',
    'date', 'dill seed', 'dill weed', 'edamame', 'eggplant', 'fava beans',
    'fennel seed', 'fenugreek seed', 'fig', 'flaxseed', 'flaxseed oil',
    'garlic', 'ginger', 'grape', 'green tea', 'hemp hearts', 'hempseed oil',
    'kale', 'kefir', 'kiwi fruit', 'lamb', 'leek', 'lemon', 'lemon balm',
    'macadamia nut', 'mackerel', 'mango', 'marjoram', 'millet', 'mussels',
    'nigella seed', 'oats', 'okra', 'olive oil', 'onion', 'orange',
    'oyster mushroom', 'oysters', 'papaya', 'peanut', 'pecan', 'peppermint',
    'pistachio', 'plum', 'pomegranate arils', 'pumpkin seed',
    'pumpkin seed oil', 'raspberry', 'rice bran oil', 'romaine lettuce',
    'rooibos', 'rosemary', 'rye bread', 'safflower oil', 'saffron', 'sage',
    'salmon', 'sesame oil', 'sesame seed', 'shiitake mushroom', 'shiso',
    'sichuan pepper', 'spearmint', 'strawberry', 'sumac', 'summer savory',
    'sunflower oil', 'sweet potato', 'tarragon', 'thyme', 'tomato', 'tuna',
    'turmeric', 'vanilla', 'walnut', 'walnut oil', 'yogurt'
  );
var
  LRepo: String;
  LDir: String;
  LCatalog: TRecipeCatalog;
  LRoundTrip: TRecipeCatalog;
  LSerialized: String;
  LCelery: TRecipeArray;
  LCeleryAlias: TRecipeArray;
  LGroup: TRecipeArray;
  LCounts: TRecipeCategoryCounts;
  LCat: TRecipeConcreteCategory;
  LQuery: TRecipeWfcQuery;
  LRes1: TRecipeWfcResult;
  LRes2: TRecipeWfcResult;
  LRes3: TRecipeWfcResult;
  LSeenCat: array[TRecipeConcreteCategory] of Boolean;
  I, J: Integer;
  LDiffers: Boolean;
  LSuggestions: TRecipeStrings;
  LDetail: TRecipeIngredientDetail;
  LCore: String;
  LRoundCelery: TRecipe;
  LCandidates: TRecipeIngredientCandidates;
begin
  LRepo := '.';
  if ParamCount >= 1 then
    LRepo := ParamStr(1);
  LDir := IncludeTrailingPathDelimiter(ExpandFileName(LRepo)) +
    'experiments' + PathDelim + '1000_see_what_sticks_food_all_recipes' + PathDelim + 'recipes';

  LCatalog := TRecipeCatalog.Create;
  try
    LCatalog.LoadFromDirectory(LDir);
    Check(LCatalog.Count = 6450, 'Catalog loads all 6,450 positive-lean recipes (129 x 50).');
    Check(Length(LCatalog.CoreIngredients) = 129, 'Catalog covers all 129 positive-lean core ingredients.');

    // Verify every positive-lean ingredient has 50 low-to-medium effort recipes with valid category splits and rich details.
    for I := Low(CPositiveLeanIngredients) to High(CPositiveLeanIngredients) do
    begin
      LCore := CPositiveLeanIngredients[I];
      LGroup := LCatalog.QueryByCoreIngredient(LCore);
      Check(Length(LGroup) = 50, 'Core ingredient "' + LCore + '" has exactly 50 recipes.');
      LCounts := LCatalog.CategoryCounts(LCore, nil);
      if (LCore = 'artichoke') or (LCore = 'asparagus') or (LCore = 'beef') or
        (LCore = 'brussels sprouts') or (LCore = 'button mushroom') or
        (LCore = 'chicken') or (LCore = 'chickpeas') or (LCore = 'clams') or
        (LCore = 'edamame') or (LCore = 'eggplant') or (LCore = 'fava beans') or
        (LCore = 'garlic') or (LCore = 'lamb') or (LCore = 'leek') or
        (LCore = 'mackerel') or (LCore = 'mussels') or (LCore = 'okra') or
        (LCore = 'onion') or (LCore = 'oyster mushroom') or (LCore = 'oysters') or
        (LCore = 'rye bread') or (LCore = 'salmon') or
        (LCore = 'shiitake mushroom') or (LCore = 'tuna') then
      begin
        Check(LCounts[rcBreakfast] = 16, LCore + ' has 16 breakfast recipes.');
        Check(LCounts[rcLunch] = 16, LCore + ' has 16 lunch recipes.');
        Check(LCounts[rcDinner] = 18, LCore + ' has 18 dinner recipes.');
        Check(LCounts[rcSmoothies] = 0, LCore + ' omits smoothies.');
        Check(LCounts[rcJuices] = 0, LCore + ' omits juices.');
      end
      else
      begin
        for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
          Check(LCounts[LCat] = 10,
            LCore + ' category ' + RecipeCategoryKey(LCat) + ' has exactly 10 recipes.');
      end;
      for J := 0 to High(LGroup) do
      begin
        Check(LGroup[J].Effort in [reLow, reMedium],
          'Recipe ' + LGroup[J].Id + ' is low or medium effort.');
        Check(Length(LGroup[J].IngredientDetails) >= 3,
          'Recipe ' + LGroup[J].Id + ' has measured ingredient details.');
        Check(Length(LGroup[J].Equipment) >= 2,
          'Recipe ' + LGroup[J].Id + ' lists equipment.');
        Check(Length(LGroup[J].Steps) >= 3,
          'Recipe ' + LGroup[J].Id + ' lists preparation steps.');
        Check(Length(LGroup[J].Tips) >= 2,
          'Recipe ' + LGroup[J].Id + ' provides kitchen tips.');
        Check(LGroup[J].TotalMinutes = LGroup[J].PrepMinutes + LGroup[J].CookMinutes,
          'TotalMinutes equals PrepMinutes + CookMinutes for ' + LGroup[J].Id);
      end;
    end;

    // Verify core ingredient queryability (canonical + aliases + unpopulated ingredient).
    LCelery := LCatalog.QueryByCoreIngredient('celery stalk');
    LCeleryAlias := LCatalog.QueryByCoreIngredient('celery');
    Check(Length(LCelery) = 50, 'QueryByCoreIngredient(celery stalk) returns 50 recipes.');
    Check(Length(LCeleryAlias) = Length(LCelery), 'Alias "celery" queries same recipes.');
    Check(Length(LCatalog.QueryByCoreIngredient('blueberries')) = 50, 'Alias "blueberries" matches blueberry.');
    Check(Length(LCatalog.QueryByCoreIngredient('extra virgin olive oil')) = 50, 'Alias "extra virgin olive oil" matches olive oil.');
    Check(Length(LCatalog.QueryByCoreIngredient('turmeric root')) = 50, 'Alias "turmeric root" matches turmeric.');
    Check(Length(LCatalog.QueryByCoreIngredient('kalonji')) = 50, 'Alias "kalonji" matches nigella seed.');
    Check(Length(LCatalog.QueryByCoreIngredient('sichuan peppercorn')) = 50, 'Alias "sichuan peppercorn" matches sichuan pepper.');
    Check(Length(LCatalog.QueryByCoreIngredient('poached salmon')) = 50, 'Alias "poached salmon" matches salmon.');
    Check(Length(LCatalog.QueryByCoreIngredient('beets')) = 50, 'Alias "beets" matches beetroot.');
    Check(Length(LCatalog.QueryByCoreIngredient('kasha')) = 50, 'Alias "kasha" matches buckwheat groats.');
    Check(Length(LCatalog.QueryByCoreIngredient('garbanzo beans')) = 50, 'Alias "garbanzo beans" matches chickpeas.');
    Check(Length(LCatalog.QueryByCoreIngredient('brussel sprout')) = 50, 'Alias "brussel sprout" matches brussels sprouts.');
    Check(Length(LCatalog.QueryByCoreIngredient('clam')) = 50, 'Alias "clam" matches clams.');
    Check(Length(LCatalog.QueryByCoreIngredient('achiote')) = 50, 'Alias "achiote" matches annatto.');
    Check(Length(LCatalog.QueryByCoreIngredient('lavender')) = 50, 'Alias "lavender" matches culinary lavender.');
    Check(Length(LCatalog.QueryByCoreIngredient('ground coriander')) = 50, 'Alias "ground coriander" matches coriander seed.');
    Check(Length(LCatalog.QueryByCoreIngredient('pomegranate')) = 50, 'Alias "pomegranate" matches pomegranate arils.');
    Check(Length(LCatalog.QueryByCoreIngredient('rooibos tea')) = 50, 'Alias "rooibos tea" matches rooibos.');
    Check(Length(LCatalog.QueryByCoreIngredient('pepitas')) = 50, 'Alias "pepitas" matches pumpkin seed.');
    Check(Length(LCatalog.QueryByCoreIngredient('tahini')) = 50, 'Alias "tahini" matches sesame seed.');
    Check(Length(LCatalog.QueryByCoreIngredient('shiitakes')) = 50, 'Alias "shiitakes" matches shiitake mushroom.');
    Check(Length(LCatalog.QueryByCoreIngredient('walnuts')) = 50, 'Alias "walnuts" matches walnut.');
    Check(Length(LCatalog.QueryByCoreIngredient('plain greek yogurt')) = 50, 'Alias "plain greek yogurt" matches yogurt.');
    Check(Length(LCatalog.QueryByCoreIngredient('broad beans')) = 50, 'Alias "broad beans" matches fava beans.');
    Check(Length(LCatalog.QueryByCoreIngredient('hemp seeds')) = 50, 'Alias "hemp seeds" matches hemp hearts.');
    Check(Length(LCatalog.QueryByCoreIngredient('mussel')) = 50, 'Alias "mussel" matches mussels.');
    Check(Length(LCatalog.QueryByCoreIngredient('oyster')) = 50, 'Alias "oyster" matches oysters.');
    Check(Length(LCatalog.QueryByCoreIngredient('king oyster mushroom')) = 50, 'Alias "king oyster mushroom" matches oyster mushroom.');
    Check(Length(LCatalog.QueryByCoreIngredient('kiwifruit')) = 50, 'Alias "kiwifruit" matches kiwi fruit.');
    Check(Length(LCatalog.QueryByCoreIngredient('matcha')) = 50, 'Alias "matcha" matches green tea.');
    Check(Length(LCatalog.QueryByCoreIngredient('fresh dill')) = 50, 'Alias "fresh dill" matches dill weed.');
    Check(Length(LCatalog.QueryByCoreIngredient('peanut butter')) = 50, 'Alias "peanut butter" matches peanut.');
    Check(Length(LCatalog.QueryByCoreIngredient('rolled oats')) = 50, 'Alias "rolled oats" matches oats.');
    Check(Length(LCatalog.QueryByCoreIngredient('grapefruit')) = 0,
      'Unpopulated core ingredient returns 0 recipes.');

    // Verify kitchen scaling & unit formatting helpers.
    Check(FormatRecipeAmount(0.25) = '1/4', 'FormatRecipeAmount(0.25) -> 1/4');
    Check(FormatRecipeAmount(0.333) = '1/3', 'FormatRecipeAmount(0.333) -> 1/3');
    Check(FormatRecipeAmount(0.5) = '1/2', 'FormatRecipeAmount(0.5) -> 1/2');
    Check(FormatRecipeAmount(1.5) = '1 1/2', 'FormatRecipeAmount(1.5) -> 1 1/2');
    Check(FormatRecipeAmount(2.0) = '2', 'FormatRecipeAmount(2.0) -> 2');
    Check(FormatIngredientUnit('stalks', 1.0) = 'stalk', 'Singularizes stalk at 1');
    Check(FormatIngredientUnit('stalk', 2.0) = 'stalks', 'Pluralizes stalks at 2');
    Check(FormatIngredientUnit('strips', 1.0) = 'strip', 'Singularizes strip at 1');
    Check(FormatIngredientUnit('strip', 2.0) = 'strips', 'Pluralizes strips at 2');
    Check(FormatScaledServings(2, 0.5) = '1 serving', 'Scales 2 servings * 0.5 -> 1 serving');
    Check(FormatScaledServings(2, 2.0) = '4 servings', 'Scales 2 servings * 2 -> 4 servings');
    Check(FormatScaledServings(3, 0.5) = '1 1/2 servings', 'Scales 3 servings * 0.5 -> 1 1/2 servings');
    Check(FormatMinutesLabel(0) = 'No cook', 'FormatMinutesLabel(0) -> No cook');
    Check(FormatMinutesLabel(65) = '1 hr 5 min', 'FormatMinutesLabel(65) -> 1 hr 5 min');
    LDetail := LCelery[0].IngredientDetails[0];
    Check(FormatIngredientLine(LDetail, 0.5) = '1 stalk celery stalk, finely diced',
      'Half-scales measured ingredient line with singularized unit.');
    Check(FormatIngredientLine(LDetail, 2.0) = '4 stalks celery stalk, finely diced',
      'Double-scales measured ingredient line cleanly.');

    // Verify JSON serialization/deserialization round-trip across all 6,450 recipes.
    LSerialized := LCatalog.ToJSONString(False);
    LRoundTrip := TRecipeCatalog.Create;
    try
      LRoundTrip.LoadFromJSONString(LSerialized);
      Check(LRoundTrip.Count = LCatalog.Count, 'Round-trip preserves full 6,450 recipe count.');
      Check(LRoundTrip.Items[0].Id = LCatalog.Items[0].Id, 'Round-trip preserves first id.');
      Check(LRoundTrip.Items[0].CoreIngredient = LCatalog.Items[0].CoreIngredient,
        'Round-trip preserves first queryable CoreIngredient.');
      LRoundCelery := LRoundTrip.FindById(LCelery[0].Id);
      Check(LRoundCelery <> nil, 'Round-trip FindById locates celery recipe.');
      Check(LRoundCelery.CoreIngredient = 'celery stalk',
        'Round-trip preserves celery CoreIngredient.');
      Check(LRoundCelery.Title = LCelery[0].Title, 'Round-trip preserves title.');
      Check(LRoundCelery.CookMinutes = LCelery[0].CookMinutes,
        'Round-trip preserves cook_minutes.');
      Check(Length(LRoundCelery.Ingredients) = Length(LCelery[0].Ingredients),
        'Round-trip preserves ingredients.');
      Check(Length(LRoundCelery.IngredientDetails) = Length(LCelery[0].IngredientDetails),
        'Round-trip preserves ingredient_details.');
      Check(LRoundCelery.IngredientDetails[0].PrepNote =
        LCelery[0].IngredientDetails[0].PrepNote,
        'Round-trip preserves ingredient prep note.');
      Check(Length(LRoundCelery.Equipment) = Length(LCelery[0].Equipment),
        'Round-trip preserves equipment.');
      Check(Length(LRoundCelery.Steps) = Length(LCelery[0].Steps),
        'Round-trip preserves steps.');
      Check(Length(LRoundCelery.Tips) = Length(LCelery[0].Tips),
        'Round-trip preserves tips.');
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
    Check(LRes1.TotalCandidates = 50, 'WFC ALL reports full 50 candidate count.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC ALL');
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      LSeenCat[LCat] := False;
    for I := 0 to High(LRes1.Recipes) do
      LSeenCat[LRes1.Recipes[I].Category] := True;
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      Check(LSeenCat[LCat], 'WFC ALL collapse includes category ' + RecipeCategoryKey(LCat));

    // Verify WFC collapse on newly populated positive-lean ingredients (5-category fruit + 3-category protein).
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'blueberry';
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 42;
    LRes2 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes2.Solved and (Length(LRes2.Recipes) = 10), 'Blueberry WFC ALL collapses 10 recipes.');
    AssertUniqueRecipes(LRes2.Recipes, 'WFC blueberry');
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      LSeenCat[LCat] := False;
    for I := 0 to High(LRes2.Recipes) do
      LSeenCat[LRes2.Recipes[I].Category] := True;
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      Check(LSeenCat[LCat], 'Blueberry WFC ALL includes category ' + RecipeCategoryKey(LCat));

    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'salmon';
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 42;
    LRes2 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes2.Solved and (Length(LRes2.Recipes) = 10), 'Salmon WFC ALL collapses 10 recipes.');
    AssertUniqueRecipes(LRes2.Recipes, 'WFC salmon');
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
      LSeenCat[LCat] := False;
    for I := 0 to High(LRes2.Recipes) do
      LSeenCat[LRes2.Recipes[I].Category] := True;
    Check(LSeenCat[rcBreakfast] and LSeenCat[rcLunch] and LSeenCat[rcDinner],
      'Salmon WFC ALL spans breakfast, lunch, and dinner.');
    Check((not LSeenCat[rcSmoothies]) and (not LSeenCat[rcJuices]),
      'Salmon WFC ALL has no smoothies or juices.');

    // Verify deterministic replay with same seed, and variety across seeds.
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'celery stalk';
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 101;
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
    Check(LRes1.Solved and (Length(LRes1.Recipes) = 10), 'Juices collapse returns all 10 unique juices.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC juices');
    for I := 0 to High(LRes1.Recipes) do
      Check(LRes1.Recipes[I].Category = rcJuices, 'All collapsed juice cards have juices category.');

    // Verify overlapping positive-lean easing ingredient synergies (e.g. blueberry + banana, turmeric + black pepper + olive oil).
    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'blueberry';
    LQuery.ExtraIngredients := ParseIngredientList('banana');
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 17;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) >= 5),
      'Overlapping easing synergy blueberry + banana yields at least 5 recipes.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC blueberry + banana');
    for I := 0 to High(LRes1.Recipes) do
    begin
      Check(LRes1.Recipes[I].HasCoreIngredient('blueberry'), 'Synergy matches core blueberry.');
      Check(LRes1.Recipes[I].HasIngredient('banana'), 'Synergy matches companion banana.');
    end;

    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'turmeric';
    LQuery.ExtraIngredients := ParseIngredientList('black pepper, olive oil');
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 23;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) >= 5),
      'Overlapping easing synergy turmeric + black pepper + olive oil yields at least 5 recipes.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC turmeric + black pepper + olive oil');

    LQuery := Default(TRecipeWfcQuery);
    LQuery.CoreIngredient := 'salmon';
    LQuery.ExtraIngredients := ParseIngredientList('olive oil, black pepper');
    LQuery.Category := rcAll;
    LQuery.MaxCount := 10;
    LQuery.Seed := 31;
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) >= 5),
      'Overlapping easing synergy salmon + olive oil + black pepper yields at least 5 recipes.');
    AssertUniqueRecipes(LRes1.Recipes, 'WFC salmon + olive oil + black pepper');

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
    LQuery.ExtraIngredients := ParseIngredientList('durian');
    LRes1 := CollapseRecipesWithWfc(LCatalog, LQuery);
    Check(LRes1.Solved and (Length(LRes1.Recipes) = 0) and (LRes1.TotalCandidates = 0),
      'Unmatched extra ingredient returns empty cleanly without error.');

    // Verify sidebar suggestions list complementary ingredients excluding core ingredient.
    LSuggestions := LCatalog.AvailableExtraIngredients('celery stalk', 8);
    Check(Length(LSuggestions) = 8, 'Provides 8 complementary ingredient suggestions.');
    for I := 0 to High(LSuggestions) do
      Check(LSuggestions[I] <> 'celery stalk', 'Suggestions exclude core ingredient.');

    // Verify look-ahead ingredient autocomplete ranks matching real catalog ingredients first.
    LCandidates := LCatalog.SuggestExtraIngredients('anise seed', nil, rcAll, 'o', 8);
    Check(Length(LCandidates) >= 3, 'Look-ahead for "o" on anise seed returns multiple real ingredients.');
    Check(LCandidates[0].MatchCount > 0, 'Top look-ahead match has > 0 anise seed recipes.');
    Check(Pos('o', LCandidates[0].Name) = 1, 'Top look-ahead match starts with "o".');
    for I := 0 to High(LCandidates) do
      Check(LCandidates[I].Name <> 'anise seed', 'Look-ahead excludes main ingredient.');

    // Verify comma-separated look-ahead matches active token and excludes earlier tokens.
    LCandidates := LCatalog.SuggestExtraIngredients('anise seed', nil, rcAll, 'lemon, o', 8);
    Check(Length(LCandidates) >= 2, 'Comma-separated look-ahead "lemon, o" returns candidates.');
    for I := 0 to High(LCandidates) do
      Check(LCandidates[I].Name <> 'lemon', 'Comma-separated look-ahead excludes already-entered token.');

    // Verify catalog-wide look-ahead still finds real catalog ingredients even with 0 matches for current core.
    LCandidates := LCatalog.SuggestExtraIngredients('anise seed', nil, rcAll, 'salm', 5);
    Check((Length(LCandidates) >= 1) and (LCandidates[0].Name = 'salmon') and
      (LCandidates[0].CatalogCount > 0), 'Catalog-wide look-ahead finds real ingredient "salmon".');

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
