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

- `recipes/celery-stalk.json`: 25 low-to-medium effort recipes (5 each across Breakfast, Lunch, Dinner, Smoothies, and Juices) with full measured ingredients, cook times, equipment lists, and kitchen tips.
