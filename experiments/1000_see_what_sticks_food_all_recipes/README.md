# Shared Food Experiment Recipe Collection

This directory is the common recipe store for `1000_see_what_sticks_food` and Parkinson's Oracle. Each JSON file under `recipes/` follows the `parkinsons-oracle-recipes-1` schema and deserializes directly into `TRecipeCatalog` / `TRecipe` in `experiments/tools/parkinsons-oracle/parkinsonsoracle.recipes.pas`.

## Schema (`parkinsons-oracle-recipes-1`)

```json
{
  "schema": "parkinsons-oracle-recipes-1",
  "recipes": [
    {
      "id": "unique-recipe-slug",
      "title": "Human-readable recipe title",
      "core_ingredient": "celery stalk",
      "category": "breakfast | lunch | dinner | smoothies | juices",
      "effort": "low | medium | high",
      "prep_minutes": 10,
      "cook_minutes": 6,
      "servings": 2,
      "summary": "Short description of the dish.",
      "ingredients": ["celery stalk", "black pepper", "onion"],
      "ingredient_details": [
        {
          "key": "celery stalk",
          "amount": 2,
          "unit": "stalks",
          "item": "celery stalk",
          "note": "finely diced"
        }
      ],
      "equipment": ["Medium skillet", "Cutting board", "Chef's knife"],
      "steps": ["Step 1", "Step 2", "Step 3"],
      "tips": ["Helpful preparation or storage tip."],
      "tags": ["savory", "quick"]
    }
  ]
}
```

### Field Notes

- `core_ingredient` is normalized (`NormalizeRecipeIngredient`) and directly queryable via `TRecipe.HasCoreIngredient` and `TRecipeCatalog.QueryByCoreIngredient`.
- `ingredients` stores normalized ingredient names used by the WFC constraint solver and multi-ingredient filtering.
- `cook_minutes`, `ingredient_details`, `equipment`, and `tips` are optional in JSON for backward compatibility and power the full recipe view (serving scaler, printable sheet, ingredient checklist, cook mode, and kitchen tips).
- Inside `ingredient_details`, numeric `amount` values scale cleanly into kitchen fractions (`1/4`, `1/2`, `1 1/2`, etc.); unmeasured seasonings can omit `amount` and supply `amount_text` (for example `"to taste"` or `"1 pinch"`).

## Current Coverage

All **44 positive-lean ("May ease") ingredients** from `1000_see_what_sticks_food` are covered with **50 low-to-medium effort recipes each** (**2,200 recipes total**), every entry including measured `ingredient_details`, `cook_minutes`, `equipment`, `steps`, and `tips`. The second wave of 1,100 recipes emphasizes culinary combinations overlapping multiple easing-lean ingredients (averaging 4.5+ additional easing-lean ingredients per recipe, such as blueberry + banana + cinnamon + flaxseed oil or turmeric + black pepper + olive oil + ginger) without introducing worsening-lean ingredients:

- **Fruits (7 files, 350 recipes — 10 each across Breakfast, Lunch, Dinner, Smoothies, Juices):** `banana.json`, `blueberry.json`, `cantaloupe.json`, `cherry.json`, `grape.json`, `orange.json`, `raspberry.json`
- **Vegetables (1 file, 50 recipes — 10 per category):** `celery-stalk.json`
- **Grains, Brews & Dark Chocolate (4 files, 200 recipes — 10 per category):** `barley.json`, `black-tea.json`, `coffee.json`, `dark-chocolate.json`
- **Culinary Oils (7 files, 350 recipes — 10 per category):** `flaxseed-oil.json`, `olive-oil.json`, `pumpkin-seed-oil.json`, `rice-bran-oil.json`, `sesame-oil.json`, `sunflower-oil.json`, `walnut-oil.json`
- **Proteins (2 files, 100 recipes — 16 Breakfast, 16 Lunch, 18 Dinner; smoothies and juices intentionally omitted):** `chicken.json`, `salmon.json`
- **Herbs (10 files, 500 recipes — 10 per category):** `basil.json`, `cilantro.json`, `lemon-balm.json`, `rosemary.json`, `sage.json`, `shiso.json`, `spearmint.json`, `summer-savory.json`, `tarragon.json`, `thyme.json`
- **Spices (13 files, 650 recipes — 10 per category):** `anise-seed.json`, `black-pepper.json`, `cayenne-pepper.json`, `cinnamon.json`, `clove.json`, `cumin.json`, `fennel-seed.json`, `ginger.json`, `nigella-seed.json`, `saffron.json`, `sichuan-pepper.json`, `sumac.json`, `turmeric.json`
