# Common Recipe Store (`1000_see_what_sticks_food_all_recipes`)

Shared recipe collection for the `1000_see_what_sticks_food` experiment family and Parkinson's Oracle web interface.

## Layout

- `recipes/<ingredient-slug>.json` — Per-core-ingredient recipe files using the common `parkinsons-oracle-recipes-1` JSON schema.
- Build pipelines (`experiments/tools/parkinsons-oracle/recipes.embed.lpr`) load every `recipes/*.json` file through the Pascal model (`TRecipeCatalog` in `parkinsonsoracle.recipes.pas`), validate schema/uniqueness/categories/effort levels, and emit the combined `recipes.json` web asset.

## Common JSON Schema (`parkinsons-oracle-recipes-1`)

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
      "servings": 2,
      "summary": "One-sentence description for recipe cards.",
      "ingredients": ["celery stalk", "onion", "black pepper"],
      "steps": ["Short step 1.", "Short step 2."],
      "tags": ["quick", "savory"]
    }
  ]
}
```

### Field rules

- `core_ingredient`: Canonical lowercase ingredient name matching the experiment vocabulary (`ingredients.tsv`), directly queryable in code via `TRecipe.CoreIngredient` and `TRecipeCatalog.QueryByCoreIngredient`.
- `category`: One of `breakfast`, `lunch`, `dinner`, `smoothies`, or `juices`.
- `effort`: One of `low`, `medium`, or `high`.
- `ingredients`: Canonical lowercase ingredient list used by the WFC recipe constraint solver when combining the main ingredient with user-selected extra ingredients.

## Proof-of-Concept Coverage

- `recipes/celery-stalk.json`: 25 low-to-medium effort recipes for `celery stalk` (5 each across Breakfast, Lunch, Dinner, Smoothies, and Juices).
