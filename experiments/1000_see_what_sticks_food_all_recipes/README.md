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

All **129 positive-lean ("May ease") ingredients** across all seven rounds (Rounds 1–7, 6,930 frozen claims) of `1000_see_what_sticks_food` are covered with **50 low-to-medium effort recipes each** (**6,450 recipes total**), every entry including measured `ingredient_details`, `cook_minutes`, `equipment`, `steps`, and `tips`. Recipe collections emphasize culinary combinations overlapping multiple easing-lean ingredients (averaging 5+ additional easing-lean ingredients per recipe, such as blueberry + banana + cinnamon + flaxseed oil, beetroot + carrot + ginger + olive oil, or turmeric + black pepper + olive oil + coriander seed) while excluding worsening-only ingredients (`cod`, `cow's milk`, `egg`, `grapefruit`, `herring`, `lemongrass`, `nutmeg`, `persimmon`, `pork`, `sardines`, `shrimp`, `trout`, `turkey`):

- **Fruits (21 files, 1,050 recipes — 10 each across Breakfast, Lunch, Dinner, Smoothies, Juices):** `apple.json`, `apricot.json`, `banana.json`, `blackberry.json`, `blueberry.json`, `cantaloupe.json`, `cherry.json`, `cranberry.json`, `date.json`, `fig.json`, `grape.json`, `kiwi-fruit.json`, `lemon.json`, `mango.json`, `orange.json`, `papaya.json`, `plum.json`, `pomegranate-arils.json`, `raspberry.json`, `strawberry.json`, `tomato.json`
- **Vegetables & Mushrooms (23 files, 1,150 recipes):**
  - **5-category (12 files, 600 recipes — 10 per category):** `arugula.json`, `beetroot.json`, `bell-pepper.json`, `broccoli.json`, `butternut-squash.json`, `carrot.json`, `celery-leaf.json`, `celery-stalk.json`, `cucumber.json`, `kale.json`, `romaine-lettuce.json`, `sweet-potato.json`
  - **Savory meal-only (11 files, 550 recipes — 16 Breakfast, 16 Lunch, 18 Dinner; smoothies and juices intentionally omitted):** `artichoke.json`, `asparagus.json`, `brussels-sprouts.json`, `button-mushroom.json`, `eggplant.json`, `garlic.json`, `leek.json`, `okra.json`, `onion.json`, `oyster-mushroom.json`, `shiitake-mushroom.json`
- **Nuts, Seeds, Whole Grains & Breads (19 files, 950 recipes):**
  - **5-category (18 files, 900 recipes — 10 per category):** `almond.json`, `barley.json`, `brazil-nut.json`, `brown-rice.json`, `buckwheat-groats.json`, `cashew.json`, `chia-seed.json`, `flaxseed.json`, `hemp-hearts.json`, `macadamia-nut.json`, `millet.json`, `oats.json`, `peanut.json`, `pecan.json`, `pistachio.json`, `pumpkin-seed.json`, `sesame-seed.json`, `walnut.json`
  - **Savory meal-only (1 file, 50 recipes — 16 Breakfast, 16 Lunch, 18 Dinner):** `rye-bread.json`
- **Brews, Fermented Dairy & Dark Chocolate (8 files, 400 recipes — 10 per category):** `black-tea.json`, `chamomile.json`, `coffee.json`, `dark-chocolate.json`, `green-tea.json`, `kefir.json`, `rooibos.json`, `yogurt.json`
- **Culinary Oils (10 files, 500 recipes — 10 per category):** `almond-oil.json`, `flaxseed-oil.json`, `hempseed-oil.json`, `olive-oil.json`, `pumpkin-seed-oil.json`, `rice-bran-oil.json`, `safflower-oil.json`, `sesame-oil.json`, `sunflower-oil.json`, `walnut-oil.json`
- **Proteins & Legumes (12 files, 600 recipes — 16 Breakfast, 16 Lunch, 18 Dinner; smoothies and juices intentionally omitted):** `beef.json`, `chicken.json`, `chickpeas.json`, `clams.json`, `edamame.json`, `fava-beans.json`, `lamb.json`, `mackerel.json`, `mussels.json`, `oysters.json`, `salmon.json`, `tuna.json`
- **Herbs (16 files, 800 recipes — 10 per category):** `basil.json`, `bay-leaf.json`, `cilantro.json`, `culinary-lavender.json`, `curry-leaf.json`, `dill-weed.json`, `lemon-balm.json`, `marjoram.json`, `peppermint.json`, `rosemary.json`, `sage.json`, `shiso.json`, `spearmint.json`, `summer-savory.json`, `tarragon.json`, `thyme.json`
- **Spices & Culinary Seeds (20 files, 1,000 recipes — 10 per category):** `anise-seed.json`, `annatto.json`, `black-pepper.json`, `caraway.json`, `cayenne-pepper.json`, `celery-seed.json`, `cinnamon.json`, `clove.json`, `coriander-seed.json`, `cumin.json`, `dill-seed.json`, `fennel-seed.json`, `fenugreek-seed.json`, `ginger.json`, `nigella-seed.json`, `saffron.json`, `sichuan-pepper.json`, `sumac.json`, `turmeric.json`, `vanilla.json`
