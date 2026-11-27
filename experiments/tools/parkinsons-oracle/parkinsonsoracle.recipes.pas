{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.recipes;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, fpjson, {$IFDEF PAS2JS}JS,{$ENDIF} wfc;

const
  CRecipesSchema = 'parkinsons-oracle-recipes-1';
  CDefaultRecipeCollapseCount = 10;

type
  TRecipeStrings = array of String;

  TRecipeCategory = (rcAll, rcBreakfast, rcLunch, rcDinner, rcSmoothies, rcJuices);
  TRecipeConcreteCategory = rcBreakfast..rcJuices;
  TRecipeCategoryCounts = array[TRecipeCategory] of Integer;

  TRecipeEffort = (reLow, reMedium, reHigh);

  TRecipeIngredientDetail = record
    IngredientKey: String;
    Amount: Double;
    AmountText: String;
    UnitName: String;
    Item: String;
    PrepNote: String;
  end;
  TRecipeIngredientDetails = array of TRecipeIngredientDetail;

  TRecipeIngredientCandidate = record
    Name: String;
    MatchCount: Integer;
    CatalogCount: Integer;
  end;
  TRecipeIngredientCandidates = array of TRecipeIngredientCandidate;

  TRecipe = class(TObject)
  private
    FId: String;
    FTitle: String;
    FCoreIngredient: String;
    FCategory: TRecipeCategory;
    FEffort: TRecipeEffort;
    FPrepMinutes: Integer;
    FCookMinutes: Integer;
    FServings: Integer;
    FSummary: String;
    FIngredients: TRecipeStrings;
    FIngredientDetails: TRecipeIngredientDetails;
    FEquipment: TRecipeStrings;
    FSteps: TRecipeStrings;
    FTips: TRecipeStrings;
    FTags: TRecipeStrings;
  public
    property Id: String read FId write FId;
    property Title: String read FTitle write FTitle;
    property CoreIngredient: String read FCoreIngredient write FCoreIngredient;
    property Category: TRecipeCategory read FCategory write FCategory;
    property Effort: TRecipeEffort read FEffort write FEffort;
    property PrepMinutes: Integer read FPrepMinutes write FPrepMinutes;
    property CookMinutes: Integer read FCookMinutes write FCookMinutes;
    property Servings: Integer read FServings write FServings;
    property Summary: String read FSummary write FSummary;
    property Ingredients: TRecipeStrings read FIngredients write FIngredients;
    property IngredientDetails: TRecipeIngredientDetails read FIngredientDetails write FIngredientDetails;
    property Equipment: TRecipeStrings read FEquipment write FEquipment;
    property Steps: TRecipeStrings read FSteps write FSteps;
    property Tips: TRecipeStrings read FTips write FTips;
    property Tags: TRecipeStrings read FTags write FTags;

    function TotalMinutes: Integer;
    function HasCoreIngredient(const AIngredient: String): Boolean;
    function HasIngredient(const AIngredient: String): Boolean;
    function MatchesAllIngredients(const AIngredients: TRecipeStrings): Boolean;
    function MatchesCategory(ACategory: TRecipeCategory): Boolean;
    function Clone: TRecipe;
    function ToJSON: TJSONObject;
    class function FromJSON(AObject: TJSONObject): TRecipe;
  end;

  TRecipeArray = array of TRecipe;

  TRecipeCatalog = class(TObject)
  private
    FSchema: String;
    FRecipes: array of TRecipe;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TRecipe;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(ARecipe: TRecipe);
    function FindById(const AId: String): TRecipe;
    function QueryByCoreIngredient(const ACoreIngredient: String): TRecipeArray;
    function Query(const ACoreIngredient: String; const AExtraIngredients: TRecipeStrings;
      ACategory: TRecipeCategory = rcAll): TRecipeArray;
    function CategoryCounts(const ACoreIngredient: String;
      const AExtraIngredients: TRecipeStrings): TRecipeCategoryCounts;
    function AvailableExtraIngredients(const ACoreIngredient: String;
      AMaxSuggestions: Integer = 12): TRecipeStrings;
    function SuggestExtraIngredients(const ACoreIngredient: String;
      const ACurrentExtras: TRecipeStrings; ACategory: TRecipeCategory;
      const AQuery: String; AMaxResults: Integer = 8): TRecipeIngredientCandidates;
    function CoreIngredients: TRecipeStrings;
    function ToJSON: TJSONObject;
    function ToJSONString(AFormatted: Boolean = False): String;
    procedure LoadFromJSON(AData: TJSONObject; AAppend: Boolean = False);
    procedure LoadFromJSONString(const AText: String; AAppend: Boolean = False);
    {$IFDEF PAS2JS}
    procedure LoadFromJSObject(AData: TJSObject; AAppend: Boolean = False);
    {$ELSE}
    procedure LoadFromFile(const AFilePath: String; AAppend: Boolean = False);
    procedure LoadFromDirectory(const ADirectory: String);
    procedure SaveToFile(const AFilePath: String; AFormatted: Boolean = True);
    {$ENDIF}
    property Schema: String read FSchema;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TRecipe read GetItem; default;
  end;

  TRecipeWfcQuery = record
    CoreIngredient: String;
    ExtraIngredients: TRecipeStrings;
    Category: TRecipeCategory;
    MaxCount: Integer;
    Seed: TGraphSeed;
  end;

  TRecipeWfcResult = record
    Solved: Boolean;
    Seed: TGraphSeed;
    SlotCount: Integer;
    TotalCandidates: Integer;
    Decisions: Integer;
    Propagations: Integer;
    Backtracks: Integer;
    CategoryCounts: TRecipeCategoryCounts;
    Recipes: TRecipeArray;
  end;

function NormalizeRecipeIngredient(const AValue: String): String;
function RecipeCategoryKey(ACategory: TRecipeCategory): String;
function RecipeCategoryLabel(ACategory: TRecipeCategory): String;
function TryParseRecipeCategory(const AText: String; out ACategory: TRecipeCategory): Boolean;
function RecipeEffortKey(AEffort: TRecipeEffort): String;
function RecipeEffortLabel(AEffort: TRecipeEffort): String;
function TryParseRecipeEffort(const AText: String; out AEffort: TRecipeEffort): Boolean;
function ParseIngredientList(const AText: String): TRecipeStrings;
function FormatRecipeAmount(AAmount: Double): String;
function FormatIngredientUnit(const AUnit: String; AAmount: Double): String;
function FormatIngredientMeasure(const ADetail: TRecipeIngredientDetail;
  AScale: Double = 1.0): String;
function FormatIngredientLine(const ADetail: TRecipeIngredientDetail;
  AScale: Double = 1.0): String;
function FormatScaledServings(ABaseServings: Integer; AScale: Double): String;
function FormatMinutesLabel(AMinutes: Integer): String;
function CollapseRecipesWithWfc(ACatalog: TRecipeCatalog;
  const AQuery: TRecipeWfcQuery): TRecipeWfcResult;

implementation

uses
  StrUtils, Math, {$IFDEF PAS2JS}fpjsonjs{$ELSE}jsonparser{$ENDIF};

const
  CCategoryKeys: array[TRecipeCategory] of String = (
    'all', 'breakfast', 'lunch', 'dinner', 'smoothies', 'juices');
  CCategoryLabels: array[TRecipeCategory] of String = (
    'All', 'Breakfast', 'Lunch', 'Dinner', 'Smoothies', 'Juices');
  CEffortKeys: array[TRecipeEffort] of String = ('low', 'medium', 'high');
  CEffortLabels: array[TRecipeEffort] of String = ('Low effort', 'Medium effort', 'Higher effort');

function CollapseSpaces(const AText: String): String;
var
  LIndex: Integer;
  LChar: Char;
  LPrevSpace: Boolean;
begin
  Result := '';
  LPrevSpace := True;
  for LIndex := 1 to Length(AText) do
  begin
    LChar := AText[LIndex];
    if (LChar <= ' ') then
    begin
      if not LPrevSpace then
      begin
        Result := Result + ' ';
        LPrevSpace := True;
      end;
    end
    else
    begin
      Result := Result + LChar;
      LPrevSpace := False;
    end;
  end;
  Result := Trim(Result);
end;

function NormalizeRecipeIngredient(const AValue: String): String;
var
  LLen: Integer;
begin
  Result := LowerCase(CollapseSpaces(AValue));
  if Result = '' then
    Exit;

  // Canonical experiment vocabulary and common culinary aliases.
  if (Result = 'almonds') or (Result = 'raw almond') or (Result = 'raw almonds') or
    (Result = 'sliced almond') or (Result = 'sliced almonds') or (Result = 'slivered almond') or
    (Result = 'slivered almonds') or (Result = 'toasted almond') or (Result = 'toasted almonds') or
    (Result = 'chopped almonds') or (Result = 'blanched almonds') then
    Exit('almond');
  if (Result = 'sweet almond oil') or (Result = 'cold-pressed almond oil') or
    (Result = 'cold pressed almond oil') or (Result = 'toasted almond oil') or
    (Result = 'unrefined almond oil') then
    Exit('almond oil');
  if (Result = 'anise') or (Result = 'anise seeds') or (Result = 'ground anise') or
    (Result = 'ground anise seed') then
    Exit('anise seed');
  if (Result = 'annatto seed') or (Result = 'annatto seeds') or (Result = 'ground annatto') or
    (Result = 'annatto powder') or (Result = 'achiote') or (Result = 'achiote seed') or
    (Result = 'achiote seeds') then
    Exit('annatto');
  if (Result = 'apricots') or (Result = 'raw apricot') or (Result = 'fresh apricot') or
    (Result = 'fresh apricots') or (Result = 'dried apricot') or (Result = 'dried apricots') then
    Exit('apricot');
  if (Result = 'artichokes') or (Result = 'artichoke heart') or (Result = 'artichoke hearts') or
    (Result = 'globe artichoke') or (Result = 'globe artichokes') or
    (Result = 'marinated artichoke hearts') or (Result = 'canned artichoke hearts') or
    (Result = 'frozen artichoke hearts') then
    Exit('artichoke');
  if (Result = 'baby arugula') or (Result = 'wild arugula') or (Result = 'fresh arugula') or
    (Result = 'rocket') or (Result = 'rocket leaves') then
    Exit('arugula');
  if (Result = 'asparagus spear') or (Result = 'asparagus spears') or
    (Result = 'green asparagus') or (Result = 'fresh asparagus') or
    (Result = 'roasted asparagus') then
    Exit('asparagus');
  if (Result = 'bananas') or (Result = 'raw banana') or (Result = 'ripe banana') then
    Exit('banana');
  if (Result = 'pearl barley') or (Result = 'hulled barley') or (Result = 'boiled barley') or
    (Result = 'cooked barley') then
    Exit('barley');
  if (Result = 'fresh basil') or (Result = 'sweet basil') or (Result = 'basil leaf') or
    (Result = 'basil leaves') then
    Exit('basil');
  if (Result = 'bay leaves') or (Result = 'dried bay leaf') or (Result = 'dried bay leaves') or
    (Result = 'fresh bay leaf') or (Result = 'fresh bay leaves') or (Result = 'laurel leaf') or
    (Result = 'laurel leaves') then
    Exit('bay leaf');
  if (Result = 'lean beef') or (Result = 'ground beef') or (Result = 'lean ground beef') or
    (Result = 'beef sirloin') or (Result = 'beef tenderloin') or (Result = 'beef strip') or
    (Result = 'beef strips') or (Result = 'flank steak') or (Result = 'chuck roast') or
    (Result = 'braised beef') or (Result = 'shredded beef') then
    Exit('beef');
  if (Result = 'beet') or (Result = 'beets') or (Result = 'beetroots') or
    (Result = 'red beet') or (Result = 'red beets') or (Result = 'golden beet') or
    (Result = 'golden beets') or (Result = 'roasted beet') or (Result = 'roasted beets') or
    (Result = 'raw beetroot') or (Result = 'cooked beetroot') or (Result = 'cooked beets') then
    Exit('beetroot');
  if (Result = 'blackberries') or (Result = 'fresh blackberry') or
    (Result = 'fresh blackberries') or (Result = 'frozen blackberry') or
    (Result = 'frozen blackberries') or (Result = 'raw blackberry') then
    Exit('blackberry');
  if (Result = 'brazil nuts') or (Result = 'raw brazil nut') or (Result = 'raw brazil nuts') or
    (Result = 'chopped brazil nuts') then
    Exit('brazil nut');
  if (Result = 'broccoli floret') or (Result = 'broccoli florets') or
    (Result = 'fresh broccoli') or (Result = 'steamed broccoli') or (Result = 'raw broccoli') or
    (Result = 'broccoli crown') or (Result = 'broccoli crowns') then
    Exit('broccoli');
  if (Result = 'cooked brown rice') or (Result = 'steamed brown rice') or
    (Result = 'short-grain brown rice') or (Result = 'long-grain brown rice') or
    (Result = 'brown basmati rice') or (Result = 'brown jasmine rice') then
    Exit('brown rice');
  if (Result = 'brussels sprouts') or (Result = 'brussels sprout') or
    (Result = 'brussel sprout') or (Result = 'brussel sprouts') or
    (Result = 'shaved brussels sprouts') or (Result = 'roasted brussels sprouts') then
    Exit('brussels sprouts');
  if (Result = 'buckwheat groats') or (Result = 'buckwheat groat') or (Result = 'buckwheat') or
    (Result = 'toasted buckwheat') or (Result = 'toasted buckwheat groats') or
    (Result = 'raw buckwheat groats') or (Result = 'cooked buckwheat groats') or
    (Result = 'kasha') then
    Exit('buckwheat groats');
  if (Result = 'roasted butternut squash') or (Result = 'cubed butternut squash') or
    (Result = 'butternut squash puree') or (Result = 'butternut') then
    Exit('butternut squash');
  if (Result = 'button mushrooms') or (Result = 'white button mushroom') or
    (Result = 'white button mushrooms') or (Result = 'white mushroom') or
    (Result = 'white mushrooms') or (Result = 'sliced button mushrooms') then
    Exit('button mushroom');
  if (Result = 'caraway seed') or (Result = 'caraway seeds') or (Result = 'toasted caraway') or
    (Result = 'toasted caraway seed') or (Result = 'toasted caraway seeds') or
    (Result = 'ground caraway') then
    Exit('caraway');
  if (Result = 'carrots') or (Result = 'raw carrot') or (Result = 'baby carrot') or
    (Result = 'baby carrots') or (Result = 'shredded carrot') or (Result = 'shredded carrots') or
    (Result = 'grated carrot') or (Result = 'grated carrots') or (Result = 'roasted carrots') then
    Exit('carrot');
  if (Result = 'cashews') or (Result = 'raw cashew') or (Result = 'raw cashews') or
    (Result = 'roasted cashew') or (Result = 'roasted cashews') or
    (Result = 'unsalted cashews') or (Result = 'soaked cashews') or
    (Result = 'cashew pieces') then
    Exit('cashew');
  if (Result = 'celery leaves') or (Result = 'fresh celery leaf') or
    (Result = 'fresh celery leaves') or (Result = 'chopped celery leaves') then
    Exit('celery leaf');
  if (Result = 'celery seeds') or (Result = 'ground celery seed') or
    (Result = 'whole celery seed') or (Result = 'whole celery seeds') then
    Exit('celery seed');
  if (Result = 'celery') or (Result = 'celery rib') or (Result = 'celery ribs') or
    (Result = 'celery stalks') or (Result = 'raw celery') or (Result = 'raw celery stalk') then
    Exit('celery stalk');
  if (Result = 'chamomile tea') or (Result = 'brewed chamomile') or
    (Result = 'chamomile flower') or (Result = 'chamomile flowers') or
    (Result = 'dried chamomile') or (Result = 'dried chamomile flowers') or
    (Result = 'chamomile tea bag') or (Result = 'german chamomile') then
    Exit('chamomile');
  if (Result = 'chia') or (Result = 'chia seeds') or (Result = 'black chia seed') or
    (Result = 'black chia seeds') or (Result = 'white chia seed') or
    (Result = 'white chia seeds') or (Result = 'soaked chia seed') or
    (Result = 'soaked chia seeds') or (Result = 'chia gel') then
    Exit('chia seed');
  if (Result = 'clams') or (Result = 'clam') or (Result = 'steamed clams') or
    (Result = 'littleneck clams') or (Result = 'manila clams') or (Result = 'chopped clams') or
    (Result = 'canned clams') or (Result = 'cooked clams') then
    Exit('clams');
  if (Result = 'black peppercorn') or (Result = 'black peppercorns') or
    (Result = 'cracked black pepper') or (Result = 'ground black pepper') or
    (Result = 'pepper') or (Result = 'black peppers') then
    Exit('black pepper');
  if (Result = 'brewed black tea') or (Result = 'black tea bag') or (Result = 'black tea leaves') then
    Exit('black tea');
  if (Result = 'blueberries') or (Result = 'raw blueberry') or (Result = 'fresh blueberries') or
    (Result = 'frozen blueberries') then
    Exit('blueberry');
  if (Result = 'cantaloupes') or (Result = 'raw cantaloupe') then
    Exit('cantaloupe');
  if (Result = 'cayenne') or (Result = 'ground cayenne') or (Result = 'ground cayenne pepper') then
    Exit('cayenne pepper');
  if (Result = 'cherries') or (Result = 'dried cherry') or (Result = 'dried cherries') or
    (Result = 'tart cherry') or (Result = 'tart cherries') or (Result = 'sweet cherry') or
    (Result = 'sweet cherries') then
    Exit('cherry');
  if (Result = 'poached chicken') or (Result = 'chicken breast') or (Result = 'chicken thigh') or
    (Result = 'chicken thighs') or (Result = 'shredded chicken') then
    Exit('chicken');
  if (Result = 'fresh cilantro') or (Result = 'dried cilantro') or (Result = 'coriander leaf') or
    (Result = 'coriander leaves') then
    Exit('cilantro');
  if (Result = 'coriander seeds') or (Result = 'ground coriander') or
    (Result = 'ground coriander seed') or (Result = 'toasted coriander seed') or
    (Result = 'toasted coriander seeds') or (Result = 'whole coriander seed') or
    (Result = 'whole coriander seeds') or (Result = 'coriander') then
    Exit('coriander seed');
  if (Result = 'cranberries') or (Result = 'fresh cranberry') or
    (Result = 'fresh cranberries') or (Result = 'frozen cranberry') or
    (Result = 'frozen cranberries') or (Result = 'dried cranberry') or
    (Result = 'dried cranberries') or (Result = 'unsweetened dried cranberries') or
    (Result = 'unsweetened cranberry juice') then
    Exit('cranberry');
  if (Result = 'cucumbers') or (Result = 'english cucumber') or (Result = 'english cucumbers') or
    (Result = 'persian cucumber') or (Result = 'persian cucumbers') or
    (Result = 'raw cucumber') or (Result = 'sliced cucumber') then
    Exit('cucumber');
  if (Result = 'lavender') or (Result = 'lavender bud') or (Result = 'lavender buds') or
    (Result = 'dried lavender') or (Result = 'dried culinary lavender') or
    (Result = 'lavender flower') or (Result = 'lavender flowers') or
    (Result = 'english lavender') then
    Exit('culinary lavender');
  if (Result = 'curry leaves') or (Result = 'fresh curry leaf') or
    (Result = 'fresh curry leaves') or (Result = 'dried curry leaf') or
    (Result = 'dried curry leaves') then
    Exit('curry leaf');
  if (Result = 'dates') or (Result = 'medjool date') or (Result = 'medjool dates') or
    (Result = 'pitted date') or (Result = 'pitted dates') or (Result = 'deglet noor date') or
    (Result = 'deglet noor dates') or (Result = 'dried date') or (Result = 'dried dates') then
    Exit('date');
  if (Result = 'dill seeds') or (Result = 'toasted dill seed') or
    (Result = 'toasted dill seeds') or (Result = 'crushed dill seed') or
    (Result = 'whole dill seed') or (Result = 'whole dill seeds') then
    Exit('dill seed');
  if (Result = 'ground cinnamon') or (Result = 'ceylon cinnamon') or (Result = 'cinnamon stick') then
    Exit('cinnamon');
  if (Result = 'cloves') or (Result = 'ground clove') or (Result = 'ground cloves') or
    (Result = 'whole clove') or (Result = 'whole cloves') then
    Exit('clove');
  if (Result = 'brewed coffee') or (Result = 'cold brew') or (Result = 'cold-brew coffee') or
    (Result = 'espresso') then
    Exit('coffee');
  if (Result = 'ground cumin') or (Result = 'cumin seed') or (Result = 'cumin seeds') then
    Exit('cumin');
  if (Result = 'plain dark chocolate') or (Result = 'dark chocolate chips') or
    (Result = '70% dark chocolate') or (Result = 'bittersweet chocolate') then
    Exit('dark chocolate');
  if (Result = 'fennel seeds') or (Result = 'toasted fennel seed') or
    (Result = 'toasted fennel seeds') then
    Exit('fennel seed');
  if (Result = 'cold-pressed flaxseed oil') or (Result = 'flax oil') or
    (Result = 'cold pressed flaxseed oil') then
    Exit('flaxseed oil');
  if (Result = 'ginger root') or (Result = 'fresh ginger') or (Result = 'grated ginger') then
    Exit('ginger');
  if (Result = 'grapes') or (Result = 'red grape') or (Result = 'red grapes') or
    (Result = 'green grape') or (Result = 'green grapes') or (Result = 'frozen grape') or
    (Result = 'frozen grapes') then
    Exit('grape');
  if (Result = 'brewed lemon balm') or (Result = 'lemon balm tea') or (Result = 'lemon balm leaf') or
    (Result = 'lemon balm leaves') or (Result = 'fresh lemon balm') then
    Exit('lemon balm');
  if (Result = 'nigella seeds') or (Result = 'ground nigella seed') or
    (Result = 'toasted nigella seed') or (Result = 'black seed') or (Result = 'kalonji') then
    Exit('nigella seed');
  if (Result = 'extra virgin olive oil') or (Result = 'extra-virgin olive oil') or
    (Result = 'cold-pressed olive oil') or (Result = 'evoo') then
    Exit('olive oil');
  if (Result = 'oranges') or (Result = 'orange juice') or (Result = 'navel orange') or
    (Result = 'raw orange') then
    Exit('orange');
  if (Result = 'cold-pressed pumpkin seed oil') or (Result = 'toasted pumpkin seed oil') then
    Exit('pumpkin seed oil');
  if (Result = 'raspberries') or (Result = 'frozen raspberry') or (Result = 'frozen raspberries') or
    (Result = 'fresh raspberries') then
    Exit('raspberry');
  if (Result = 'refined rice bran oil') then
    Exit('rice bran oil');
  if (Result = 'fresh rosemary') or (Result = 'dried rosemary') or (Result = 'rosemary sprig') then
    Exit('rosemary');
  if (Result = 'saffron threads') or (Result = 'dried saffron') or (Result = 'ground saffron') then
    Exit('saffron');
  if (Result = 'fresh sage') or (Result = 'dried sage') or (Result = 'sage leaf') or
    (Result = 'sage leaves') then
    Exit('sage');
  if (Result = 'poached salmon') or (Result = 'salmon fillet') or (Result = 'salmon fillets') then
    Exit('salmon');
  if (Result = 'toasted sesame oil') or (Result = 'cold-pressed sesame oil') then
    Exit('sesame oil');
  if (Result = 'shiso leaf') or (Result = 'shiso leaves') or (Result = 'fresh shiso') or
    (Result = 'dried shiso') or (Result = 'perilla leaf') or (Result = 'perilla leaves') then
    Exit('shiso');
  if (Result = 'sichuan peppercorn') or (Result = 'sichuan peppercorns') or
    (Result = 'szechuan pepper') or (Result = 'szechuan peppercorn') or
    (Result = 'szechuan peppercorns') or (Result = 'ground sichuan pepper') or
    (Result = 'toasted sichuan pepper') then
    Exit('sichuan pepper');
  if (Result = 'dried spearmint') or (Result = 'fresh spearmint') or (Result = 'spearmint leaf') or
    (Result = 'spearmint leaves') then
    Exit('spearmint');
  if (Result = 'ground sumac') then
    Exit('sumac');
  if (Result = 'fresh summer savory') or (Result = 'dried summer savory') or (Result = 'savory') then
    Exit('summer savory');
  if (Result = 'refined sunflower oil') then
    Exit('sunflower oil');
  if (Result = 'fresh tarragon') or (Result = 'dried tarragon') or (Result = 'tarragon leaves') then
    Exit('tarragon');
  if (Result = 'fresh thyme') or (Result = 'dried thyme') or (Result = 'thyme leaves') then
    Exit('thyme');
  if (Result = 'ground turmeric') or (Result = 'fresh turmeric') or (Result = 'grated turmeric') or
    (Result = 'turmeric root') then
    Exit('turmeric');
  if (Result = 'cold-pressed walnut oil') or (Result = 'toasted walnut oil') then
    Exit('walnut oil');
  if (Result = 'onions') or (Result = 'yellow onion') or (Result = 'yellow onions') or
    (Result = 'sweet onion') or (Result = 'sweet onions') or (Result = 'red onion') or
    (Result = 'red onions') or (Result = 'white onion') or (Result = 'white onions') then
    Exit('onion');
  if (Result = 'garlic clove') or (Result = 'garlic cloves') then
    Exit('garlic');
  if (Result = 'bell peppers') or (Result = 'sweet pepper') or (Result = 'sweet peppers') or
    (Result = 'red bell pepper') or (Result = 'red bell peppers') or
    (Result = 'yellow bell pepper') or (Result = 'yellow bell peppers') or
    (Result = 'orange bell pepper') or (Result = 'orange bell peppers') or
    (Result = 'green bell pepper') or (Result = 'green bell peppers') then
    Exit('bell pepper');
  if (Result = 'lemon juice') or (Result = 'lemons') then
    Exit('lemon');
  if (Result = 'lime juice') or (Result = 'limes') then
    Exit('lime');
  if (Result = 'green apple') or (Result = 'green apples') or (Result = 'red apple') or
    (Result = 'red apples') or (Result = 'raw apple') or (Result = 'tart apple') or
    (Result = 'sweet apple') or (Result = 'honeycrisp apple') or
    (Result = 'granny smith apple') or (Result = 'apples') then
    Exit('apple');
  if (Result = 'chickpeas') or (Result = 'chickpea') or (Result = 'garbanzo') or
    (Result = 'garbanzo bean') or (Result = 'garbanzo beans') or
    (Result = 'cooked chickpeas') or (Result = 'canned chickpeas') then
    Exit('chickpeas');
  if (Result = 'lentils') or (Result = 'red lentil') or (Result = 'red lentils') then
    Exit('lentil');
  if (Result = 'white beans') or (Result = 'cannellini bean') or (Result = 'cannellini beans') then
    Exit('white bean');
  if (Result = 'sweet potatoes') or (Result = 'roasted sweet potato') or
    (Result = 'roasted sweet potatoes') or (Result = 'baked sweet potato') or
    (Result = 'steamed sweet potato') or (Result = 'mashed sweet potato') or
    (Result = 'sweet potato puree') then
    Exit('sweet potato');
  if (Result = 'potatoes') then
    Exit('potato');
  if (Result = 'tomatoes') or (Result = 'raw tomato') or (Result = 'cooked tomato') or
    (Result = 'roasted tomato') or (Result = 'roasted tomatoes') or
    (Result = 'cherry tomato') or (Result = 'cherry tomatoes') or
    (Result = 'grape tomato') or (Result = 'grape tomatoes') or
    (Result = 'roma tomato') or (Result = 'roma tomatoes') or
    (Result = 'diced tomatoes') or (Result = 'tomato paste') then
    Exit('tomato');
  if (Result = 'oats') or (Result = 'rolled oats') or (Result = 'oat') then
    Exit('oats');
  if (Result = 'pecans') or (Result = 'raw pecan') or (Result = 'raw pecans') or
    (Result = 'roasted pecan') or (Result = 'roasted pecans') or
    (Result = 'toasted pecans') or (Result = 'chopped pecans') or
    (Result = 'pecan halves') then
    Exit('pecan');
  if (Result = 'fresh peppermint') or (Result = 'dried peppermint') or
    (Result = 'brewed peppermint') or (Result = 'peppermint leaf') or
    (Result = 'peppermint leaves') or (Result = 'peppermint tea') then
    Exit('peppermint');
  if (Result = 'pistachios') or (Result = 'raw pistachio') or (Result = 'raw pistachios') or
    (Result = 'roasted pistachio') or (Result = 'roasted pistachios') or
    (Result = 'shelled pistachios') or (Result = 'unsalted pistachios') or
    (Result = 'chopped pistachios') then
    Exit('pistachio');
  if (Result = 'plums') or (Result = 'raw plum') or (Result = 'poached plum') or
    (Result = 'poached plums') or (Result = 'fresh plum') or (Result = 'fresh plums') or
    (Result = 'prune') or (Result = 'prunes') or (Result = 'dried plum') or
    (Result = 'dried plums') then
    Exit('plum');
  if (Result = 'pomegranate arils') or (Result = 'pomegranate aril') or
    (Result = 'pomegranate') or (Result = 'pomegranates') or
    (Result = 'pomegranate seed') or (Result = 'pomegranate seeds') or
    (Result = 'raw pomegranate arils') or (Result = 'fresh pomegranate arils') then
    Exit('pomegranate arils');
  if (Result = 'pumpkin seeds') or (Result = 'raw pumpkin seed') or
    (Result = 'raw pumpkin seeds') or (Result = 'roasted pumpkin seed') or
    (Result = 'roasted pumpkin seeds') or (Result = 'pepita') or (Result = 'pepitas') or
    (Result = 'toasted pepitas') then
    Exit('pumpkin seed');
  if (Result = 'romaine') or (Result = 'raw romaine') or (Result = 'raw romaine lettuce') or
    (Result = 'romaine leaf') or (Result = 'romaine leaves') or
    (Result = 'romaine heart') or (Result = 'romaine hearts') or (Result = 'cos lettuce') then
    Exit('romaine lettuce');
  if (Result = 'rooibos') or (Result = 'brewed rooibos') or (Result = 'rooibos tea') or
    (Result = 'red rooibos') or (Result = 'green rooibos') or (Result = 'red bush tea') or
    (Result = 'redbush tea') then
    Exit('rooibos');
  if (Result = 'toasted rye bread') or (Result = 'whole-grain rye bread') or
    (Result = 'whole grain rye bread') or (Result = 'sourdough rye bread') or
    (Result = 'dark rye bread') or (Result = 'nordic rye bread') or (Result = 'rye toast') then
    Exit('rye bread');
  if (Result = 'cold-pressed safflower oil') or (Result = 'cold pressed safflower oil') or
    (Result = 'high-oleic safflower oil') or (Result = 'high oleic safflower oil') or
    (Result = 'unrefined safflower oil') then
    Exit('safflower oil');
  if (Result = 'sesame seeds') or (Result = 'toasted sesame seed') or
    (Result = 'toasted sesame seeds') or (Result = 'ground sesame seed') or
    (Result = 'ground sesame seeds') or (Result = 'white sesame seeds') or
    (Result = 'black sesame seeds') or (Result = 'tahini') then
    Exit('sesame seed');
  if (Result = 'shiitake') or (Result = 'shiitakes') or (Result = 'shiitake mushrooms') or
    (Result = 'cooked shiitake') or (Result = 'cooked shiitake mushroom') or
    (Result = 'cooked shiitake mushrooms') or (Result = 'dried shiitake') or
    (Result = 'dried shiitake mushrooms') or (Result = 'fresh shiitake') or
    (Result = 'fresh shiitake mushrooms') then
    Exit('shiitake mushroom');
  if (Result = 'strawberries') or (Result = 'raw strawberry') or
    (Result = 'raw strawberries') or (Result = 'fresh strawberry') or
    (Result = 'fresh strawberries') or (Result = 'frozen strawberry') or
    (Result = 'frozen strawberries') or (Result = 'sliced strawberries') then
    Exit('strawberry');
  if (Result = 'canned tuna') or (Result = 'cooked tuna') or (Result = 'skipjack tuna') or
    (Result = 'light tuna') or (Result = 'canned light tuna') or
    (Result = 'chunk light tuna') or (Result = 'albacore tuna') or
    (Result = 'tuna fillet') or (Result = 'seared tuna') then
    Exit('tuna');
  if (Result = 'vanilla bean') or (Result = 'vanilla beans') or (Result = 'vanilla pod') or
    (Result = 'vanilla pods') or (Result = 'vanilla extract') or
    (Result = 'pure vanilla extract') or (Result = 'vanilla bean paste') or
    (Result = 'vanilla paste') or (Result = 'ground vanilla') or
    (Result = 'vanilla powder') then
    Exit('vanilla');
  if (Result = 'walnuts') or (Result = 'raw walnut') or (Result = 'raw walnuts') or
    (Result = 'roasted walnut') or (Result = 'roasted walnuts') or
    (Result = 'toasted walnuts') or (Result = 'chopped walnuts') or
    (Result = 'walnut halves') then
    Exit('walnut');
  if (Result = 'yoghurt') or (Result = 'plain yogurt') or (Result = 'plain yoghurt') or
    (Result = 'unsweetened yogurt') or (Result = 'unsweetened plain yogurt') or
    (Result = 'greek yogurt') or (Result = 'plain greek yogurt') or
    (Result = 'live-culture yogurt') then
    Exit('yogurt');

  // General singularization fallback for arbitrary user-typed ingredients.
  LLen := Length(Result);
  if (LLen > 4) and EndsStr('ies', Result) then
    Result := Copy(Result, 1, LLen - 3) + 'y'
  else if (LLen > 4) and EndsStr('oes', Result) then
    Result := Copy(Result, 1, LLen - 2)
  else if (LLen > 3) and EndsStr('s', Result) and not EndsStr('ss', Result) and
    not EndsStr('us', Result) and not EndsStr('is', Result) and
    (Result <> 'oats') and (Result <> 'hummus') and (Result <> 'couscous') then
    Result := Copy(Result, 1, LLen - 1);
end;

function RecipeCategoryKey(ACategory: TRecipeCategory): String;
begin
  Result := CCategoryKeys[ACategory];
end;

function RecipeCategoryLabel(ACategory: TRecipeCategory): String;
begin
  Result := CCategoryLabels[ACategory];
end;

function TryParseRecipeCategory(const AText: String; out ACategory: TRecipeCategory): Boolean;
var
  LNormalized: String;
  LItem: TRecipeCategory;
begin
  LNormalized := LowerCase(Trim(AText));
  if LNormalized = 'smoothie' then
    LNormalized := 'smoothies'
  else if LNormalized = 'juice' then
    LNormalized := 'juices';
  for LItem := Low(TRecipeCategory) to High(TRecipeCategory) do
  begin
    if CCategoryKeys[LItem] = LNormalized then
    begin
      ACategory := LItem;
      Exit(True);
    end;
  end;
  ACategory := rcAll;
  Result := False;
end;

function RecipeEffortKey(AEffort: TRecipeEffort): String;
begin
  Result := CEffortKeys[AEffort];
end;

function RecipeEffortLabel(AEffort: TRecipeEffort): String;
begin
  Result := CEffortLabels[AEffort];
end;

function TryParseRecipeEffort(const AText: String; out AEffort: TRecipeEffort): Boolean;
var
  LNormalized: String;
  LItem: TRecipeEffort;
begin
  LNormalized := LowerCase(Trim(AText));
  for LItem := Low(TRecipeEffort) to High(TRecipeEffort) do
  begin
    if CEffortKeys[LItem] = LNormalized then
    begin
      AEffort := LItem;
      Exit(True);
    end;
  end;
  AEffort := reLow;
  Result := False;
end;

function CopyStrings(const AValues: TRecipeStrings): TRecipeStrings;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(AValues) do
    Result[LIndex] := AValues[LIndex];
end;

function ContainsTextItem(const AValues: TRecipeStrings; const AValue: String): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AValues) do
    if AValues[LIndex] = AValue then
      Exit(True);
  Result := False;
end;

procedure AppendTextItem(var AValues: TRecipeStrings; const AValue: String);
var
  LLen: Integer;
begin
  LLen := Length(AValues);
  SetLength(AValues, LLen + 1);
  AValues[LLen] := AValue;
end;

function ParseIngredientList(const AText: String): TRecipeStrings;
var
  LStart: Integer;
  LIndex: Integer;
  LPart: String;
begin
  Result := nil;
  LStart := 1;
  for LIndex := 1 to Length(AText) + 1 do
  begin
    if (LIndex > Length(AText)) or (AText[LIndex] = ',') or (AText[LIndex] = ';') or
      (AText[LIndex] = #10) or (AText[LIndex] = #13) then
    begin
      LPart := NormalizeRecipeIngredient(Copy(AText, LStart, LIndex - LStart));
      if (LPart <> '') and not ContainsTextItem(Result, LPart) then
        AppendTextItem(Result, LPart);
      LStart := LIndex + 1;
    end;
  end;
end;

function ReadRequiredString(AObject: TJSONObject; const AField: String): String;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AField);
  if (LData = nil) or (LData.JSONType <> jtString) or (Trim(LData.AsString) = '') then
    raise EConvertError.Create('Recipe JSON requires a nonempty string field: ' + AField);
  Result := Trim(LData.AsString);
end;

function ReadOptionalInt(AObject: TJSONObject; const AField: String; ADefault: Integer): Integer;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AField);
  if LData = nil then
    Exit(ADefault);
  if LData.JSONType <> jtNumber then
    raise EConvertError.Create('Recipe JSON requires an integer field: ' + AField);
  Result := LData.AsInteger;
end;

function ReadStringArray(AObject: TJSONObject; const AField: String;
  ARequired, ANormalizeIngredients: Boolean): TRecipeStrings;
var
  LData: TJSONData;
  LArray: TJSONArray;
  LIndex: Integer;
  LValue: String;
begin
  Result := nil;
  LData := AObject.Find(AField);
  if LData = nil then
  begin
    if ARequired then
      raise EConvertError.Create('Recipe JSON requires array field: ' + AField);
    Exit;
  end;
  if LData.JSONType <> jtArray then
    raise EConvertError.Create('Recipe JSON field must be an array: ' + AField);
  LArray := TJSONArray(LData);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if LArray.Items[LIndex].JSONType <> jtString then
      raise EConvertError.Create('Recipe JSON array must contain strings: ' + AField);
    LValue := Trim(LArray.Items[LIndex].AsString);
    if ANormalizeIngredients then
      LValue := NormalizeRecipeIngredient(LValue);
    if (LValue <> '') and (not ANormalizeIngredients or not ContainsTextItem(Result, LValue)) then
      AppendTextItem(Result, LValue);
  end;
  if ARequired and (Length(Result) = 0) then
    raise EConvertError.Create('Recipe JSON array cannot be empty: ' + AField);
end;

function CopyDetails(const AValues: TRecipeIngredientDetails): TRecipeIngredientDetails;
var
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(AValues) do
    Result[LIndex] := AValues[LIndex];
end;

function FormatRecipeAmount(AAmount: Double): String;
const
  CFracValues: array[0..7] of Double = (
    0.125, 0.25, 1.0 / 3.0, 0.375, 0.5, 2.0 / 3.0, 0.75, 0.875);
  CFracLabels: array[0..7] of String = (
    '1/8', '1/4', '1/3', '3/8', '1/2', '2/3', '3/4', '7/8');
var
  LWhole: Integer;
  LFrac: Double;
  LIndex: Integer;
  LTenths: Integer;
begin
  if AAmount <= 0 then
    Exit('');
  LWhole := Trunc(AAmount);
  LFrac := AAmount - LWhole;
  if LFrac < 0.04 then
  begin
    if LWhole <= 0 then
      Exit('1/8');
    Exit(IntToStr(LWhole));
  end;
  if LFrac > 0.96 then
    Exit(IntToStr(LWhole + 1));
  for LIndex := Low(CFracValues) to High(CFracValues) do
  begin
    if Abs(LFrac - CFracValues[LIndex]) <= 0.045 then
    begin
      if LWhole > 0 then
        Exit(IntToStr(LWhole) + ' ' + CFracLabels[LIndex]);
      Exit(CFracLabels[LIndex]);
    end;
  end;
  LTenths := Round(AAmount * 10);
  if (LTenths mod 10) = 0 then
    Result := IntToStr(LTenths div 10)
  else
    Result := IntToStr(LTenths div 10) + '.' + IntToStr(LTenths mod 10);
end;

function FormatIngredientUnit(const AUnit: String; AAmount: Double): String;
var
  LTrimmed: String;
  LLower: String;
  LPlural: Boolean;
begin
  LTrimmed := Trim(AUnit);
  if LTrimmed = '' then
    Exit('');
  LLower := LowerCase(LTrimmed);
  LPlural := AAmount > 1.04;
  if (LLower = 'stalk') or (LLower = 'stalks') then
    Exit(IfThen(LPlural, 'stalks', 'stalk'));
  if (LLower = 'rib') or (LLower = 'ribs') then
    Exit(IfThen(LPlural, 'ribs', 'rib'));
  if (LLower = 'cup') or (LLower = 'cups') then
    Exit(IfThen(LPlural, 'cups', 'cup'));
  if (LLower = 'clove') or (LLower = 'cloves') then
    Exit(IfThen(LPlural, 'cloves', 'clove'));
  if (LLower = 'slice') or (LLower = 'slices') then
    Exit(IfThen(LPlural, 'slices', 'slice'));
  if (LLower = 'fillet') or (LLower = 'fillets') then
    Exit(IfThen(LPlural, 'fillets', 'fillet'));
  if (LLower = 'leaf') or (LLower = 'leaves') then
    Exit(IfThen(LPlural, 'leaves', 'leaf'));
  if (LLower = 'sprig') or (LLower = 'sprigs') then
    Exit(IfThen(LPlural, 'sprigs', 'sprig'));
  if (LLower = 'can') or (LLower = 'cans') then
    Exit(IfThen(LPlural, 'cans', 'can'));
  if (LLower = 'pinch') or (LLower = 'pinches') then
    Exit(IfThen(LPlural, 'pinches', 'pinch'));
  if (LLower = 'inch') or (LLower = 'inches') then
    Exit(IfThen(LPlural, 'inches', 'inch'));
  if (LLower = 'strip') or (LLower = 'strips') then
    Exit(IfThen(LPlural, 'strips', 'strip'));
  Result := LTrimmed;
end;

function FormatIngredientMeasure(const ADetail: TRecipeIngredientDetail; AScale: Double): String;
var
  LScaled: Double;
  LAmountStr: String;
  LUnitStr: String;
begin
  if AScale <= 0 then
    AScale := 1.0;
  if ADetail.Amount > 0 then
  begin
    LScaled := ADetail.Amount * AScale;
    LAmountStr := FormatRecipeAmount(LScaled);
    LUnitStr := FormatIngredientUnit(ADetail.UnitName, LScaled);
    if LUnitStr <> '' then
      Result := LAmountStr + ' ' + LUnitStr
    else
      Result := LAmountStr;
  end
  else
  begin
    Result := Trim(ADetail.AmountText);
    if (Result <> '') and (Trim(ADetail.UnitName) <> '') then
      Result := Result + ' ' + Trim(ADetail.UnitName);
  end;
end;

function FormatIngredientLine(const ADetail: TRecipeIngredientDetail; AScale: Double): String;
var
  LMeasure: String;
  LItem: String;
begin
  LMeasure := FormatIngredientMeasure(ADetail, AScale);
  LItem := Trim(ADetail.Item);
  if LItem = '' then
    LItem := ADetail.IngredientKey;
  if LMeasure <> '' then
    Result := LMeasure + ' ' + LItem
  else
    Result := LItem;
  if Trim(ADetail.PrepNote) <> '' then
    Result := Result + ', ' + Trim(ADetail.PrepNote);
end;

function FormatScaledServings(ABaseServings: Integer; AScale: Double): String;
var
  LScaled: Double;
  LText: String;
begin
  if ABaseServings < 1 then
    ABaseServings := 1;
  if AScale <= 0 then
    AScale := 1.0;
  LScaled := ABaseServings * AScale;
  LText := FormatRecipeAmount(LScaled);
  if Abs(LScaled - 1.0) <= 0.04 then
    Result := '1 serving'
  else
    Result := LText + ' servings';
end;

function FormatMinutesLabel(AMinutes: Integer): String;
var
  LHours: Integer;
  LRem: Integer;
begin
  if AMinutes <= 0 then
    Exit('No cook');
  if AMinutes < 60 then
    Exit(IntToStr(AMinutes) + ' min');
  LHours := AMinutes div 60;
  LRem := AMinutes mod 60;
  if LRem = 0 then
    Result := IntToStr(LHours) + ' hr'
  else
    Result := IntToStr(LHours) + ' hr ' + IntToStr(LRem) + ' min';
end;

function ReadOptionalString(AObject: TJSONObject; const AField: String): String;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AField);
  if LData = nil then
    Exit('');
  if LData.JSONType <> jtString then
    raise EConvertError.Create('Recipe JSON requires a string field: ' + AField);
  Result := Trim(LData.AsString);
end;

function ReadOptionalFloat(AObject: TJSONObject; const AField: String; ADefault: Double): Double;
var
  LData: TJSONData;
begin
  LData := AObject.Find(AField);
  if LData = nil then
    Exit(ADefault);
  if LData.JSONType <> jtNumber then
    raise EConvertError.Create('Recipe JSON requires a numeric field: ' + AField);
  Result := LData.AsFloat;
end;

function ReadIngredientDetails(AObject: TJSONObject; const AField: String): TRecipeIngredientDetails;
var
  LData: TJSONData;
  LArray: TJSONArray;
  LIndex: Integer;
  LEntry: TJSONObject;
  LDetail: TRecipeIngredientDetail;
begin
  Result := nil;
  LData := AObject.Find(AField);
  if LData = nil then
    Exit;
  if LData.JSONType <> jtArray then
    raise EConvertError.Create('Recipe JSON field must be an array: ' + AField);
  LArray := TJSONArray(LData);
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if (LArray.Items[LIndex] = nil) or (LArray.Items[LIndex].JSONType <> jtObject) then
      raise EConvertError.Create('Each ingredient detail must be a JSON object: ' + AField);
    LEntry := TJSONObject(LArray.Items[LIndex]);
    LDetail := Default(TRecipeIngredientDetail);
    LDetail.Item := ReadRequiredString(LEntry, 'item');
    LDetail.IngredientKey := NormalizeRecipeIngredient(ReadOptionalString(LEntry, 'key'));
    if LDetail.IngredientKey = '' then
      LDetail.IngredientKey := NormalizeRecipeIngredient(LDetail.Item);
    LDetail.Amount := ReadOptionalFloat(LEntry, 'amount', 0);
    LDetail.AmountText := ReadOptionalString(LEntry, 'amount_text');
    LDetail.UnitName := ReadOptionalString(LEntry, 'unit');
    LDetail.PrepNote := ReadOptionalString(LEntry, 'note');
    Result[LIndex] := LDetail;
  end;
end;

function DetailsToJSONArray(const AValues: TRecipeIngredientDetails): TJSONArray;
var
  LIndex: Integer;
  LEntry: TJSONObject;
begin
  Result := TJSONArray.Create;
  for LIndex := 0 to High(AValues) do
  begin
    LEntry := TJSONObject.Create;
    if AValues[LIndex].IngredientKey <> '' then
      LEntry.Add('key', AValues[LIndex].IngredientKey);
    if AValues[LIndex].Amount > 0 then
      LEntry.Add('amount', AValues[LIndex].Amount);
    if AValues[LIndex].AmountText <> '' then
      LEntry.Add('amount_text', AValues[LIndex].AmountText);
    if AValues[LIndex].UnitName <> '' then
      LEntry.Add('unit', AValues[LIndex].UnitName);
    LEntry.Add('item', AValues[LIndex].Item);
    if AValues[LIndex].PrepNote <> '' then
      LEntry.Add('note', AValues[LIndex].PrepNote);
    Result.Add(LEntry);
  end;
end;

function StringsToJSONArray(const AValues: TRecipeStrings): TJSONArray;
var
  LIndex: Integer;
begin
  Result := TJSONArray.Create;
  for LIndex := 0 to High(AValues) do
    Result.Add(AValues[LIndex]);
end;

{ TRecipe }

function TRecipe.TotalMinutes: Integer;
begin
  Result := FPrepMinutes + FCookMinutes;
end;

function TRecipe.HasCoreIngredient(const AIngredient: String): Boolean;
var
  LQuery: String;
begin
  LQuery := NormalizeRecipeIngredient(AIngredient);
  if LQuery = '' then
    Exit(True);
  Result := NormalizeRecipeIngredient(FCoreIngredient) = LQuery;
end;

function TRecipe.HasIngredient(const AIngredient: String): Boolean;
var
  LQuery: String;
  LIndex: Integer;
begin
  LQuery := NormalizeRecipeIngredient(AIngredient);
  if LQuery = '' then
    Exit(True);
  if NormalizeRecipeIngredient(FCoreIngredient) = LQuery then
    Exit(True);
  for LIndex := 0 to High(FIngredients) do
  begin
    if NormalizeRecipeIngredient(FIngredients[LIndex]) = LQuery then
      Exit(True);
  end;
  Result := False;
end;

function TRecipe.MatchesAllIngredients(const AIngredients: TRecipeStrings): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AIngredients) do
  begin
    if not HasIngredient(AIngredients[LIndex]) then
      Exit(False);
  end;
  Result := True;
end;

function TRecipe.MatchesCategory(ACategory: TRecipeCategory): Boolean;
begin
  Result := (ACategory = rcAll) or (FCategory = ACategory);
end;

function TRecipe.Clone: TRecipe;
begin
  Result := TRecipe.Create;
  Result.FId := FId;
  Result.FTitle := FTitle;
  Result.FCoreIngredient := FCoreIngredient;
  Result.FCategory := FCategory;
  Result.FEffort := FEffort;
  Result.FPrepMinutes := FPrepMinutes;
  Result.FCookMinutes := FCookMinutes;
  Result.FServings := FServings;
  Result.FSummary := FSummary;
  Result.FIngredients := CopyStrings(FIngredients);
  Result.FIngredientDetails := CopyDetails(FIngredientDetails);
  Result.FEquipment := CopyStrings(FEquipment);
  Result.FSteps := CopyStrings(FSteps);
  Result.FTips := CopyStrings(FTips);
  Result.FTags := CopyStrings(FTags);
end;

function TRecipe.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('id', FId);
    Result.Add('title', FTitle);
    Result.Add('core_ingredient', FCoreIngredient);
    Result.Add('category', RecipeCategoryKey(FCategory));
    Result.Add('effort', RecipeEffortKey(FEffort));
    Result.Add('prep_minutes', FPrepMinutes);
    if FCookMinutes > 0 then
      Result.Add('cook_minutes', FCookMinutes);
    Result.Add('servings', FServings);
    Result.Add('summary', FSummary);
    Result.Add('ingredients', StringsToJSONArray(FIngredients));
    if Length(FIngredientDetails) > 0 then
      Result.Add('ingredient_details', DetailsToJSONArray(FIngredientDetails));
    if Length(FEquipment) > 0 then
      Result.Add('equipment', StringsToJSONArray(FEquipment));
    Result.Add('steps', StringsToJSONArray(FSteps));
    if Length(FTips) > 0 then
      Result.Add('tips', StringsToJSONArray(FTips));
    Result.Add('tags', StringsToJSONArray(FTags));
  except
    Result.Free;
    raise;
  end;
end;

class function TRecipe.FromJSON(AObject: TJSONObject): TRecipe;
var
  LCategoryText: String;
  LEffortText: String;
  LCategory: TRecipeCategory;
  LEffort: TRecipeEffort;
begin
  if AObject = nil then
    raise EConvertError.Create('Recipe JSON object cannot be nil.');
  LCategoryText := ReadRequiredString(AObject, 'category');
  if not TryParseRecipeCategory(LCategoryText, LCategory) or (LCategory = rcAll) then
    raise EConvertError.Create('Invalid recipe category: ' + LCategoryText);
  LEffortText := ReadRequiredString(AObject, 'effort');
  if not TryParseRecipeEffort(LEffortText, LEffort) then
    raise EConvertError.Create('Invalid recipe effort: ' + LEffortText);

  Result := TRecipe.Create;
  try
    Result.FId := ReadRequiredString(AObject, 'id');
    Result.FTitle := ReadRequiredString(AObject, 'title');
    Result.FCoreIngredient := NormalizeRecipeIngredient(
      ReadRequiredString(AObject, 'core_ingredient'));
    Result.FCategory := LCategory;
    Result.FEffort := LEffort;
    Result.FPrepMinutes := Max(1, ReadOptionalInt(AObject, 'prep_minutes', 10));
    Result.FCookMinutes := Max(0, ReadOptionalInt(AObject, 'cook_minutes', 0));
    Result.FServings := Max(1, ReadOptionalInt(AObject, 'servings', 1));
    Result.FSummary := ReadRequiredString(AObject, 'summary');
    Result.FIngredients := ReadStringArray(AObject, 'ingredients', True, True);
    if not ContainsTextItem(Result.FIngredients, Result.FCoreIngredient) then
      AppendTextItem(Result.FIngredients, Result.FCoreIngredient);
    Result.FIngredientDetails := ReadIngredientDetails(AObject, 'ingredient_details');
    Result.FEquipment := ReadStringArray(AObject, 'equipment', False, False);
    Result.FSteps := ReadStringArray(AObject, 'steps', False, False);
    Result.FTips := ReadStringArray(AObject, 'tips', False, False);
    Result.FTags := ReadStringArray(AObject, 'tags', False, False);
  except
    Result.Free;
    raise;
  end;
end;

{ TRecipeCatalog }

constructor TRecipeCatalog.Create;
begin
  inherited Create;
  FSchema := CRecipesSchema;
end;

destructor TRecipeCatalog.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TRecipeCatalog.Clear;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FRecipes) do
    FRecipes[LIndex].Free;
  FRecipes := nil;
end;

function TRecipeCatalog.GetCount: Integer;
begin
  Result := Length(FRecipes);
end;

function TRecipeCatalog.GetItem(AIndex: Integer): TRecipe;
begin
  Result := FRecipes[AIndex];
end;

procedure TRecipeCatalog.Add(ARecipe: TRecipe);
var
  LLen: Integer;
begin
  if ARecipe = nil then
    raise EArgumentException.Create('Cannot add a nil recipe.');
  if Trim(ARecipe.Id) = '' then
    raise EConvertError.Create('Recipe must have a nonempty id.');
  if FindById(ARecipe.Id) <> nil then
    raise EConvertError.Create('Duplicate recipe id: ' + ARecipe.Id);
  LLen := Length(FRecipes);
  SetLength(FRecipes, LLen + 1);
  FRecipes[LLen] := ARecipe;
end;

function TRecipeCatalog.FindById(const AId: String): TRecipe;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FRecipes) do
    if FRecipes[LIndex].Id = AId then
      Exit(FRecipes[LIndex]);
  Result := nil;
end;

function TRecipeCatalog.QueryByCoreIngredient(const ACoreIngredient: String): TRecipeArray;
var
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  for LIndex := 0 to High(FRecipes) do
  begin
    if FRecipes[LIndex].HasCoreIngredient(ACoreIngredient) then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := FRecipes[LIndex];
      Inc(LCount);
    end;
  end;
end;

function TRecipeCatalog.Query(const ACoreIngredient: String;
  const AExtraIngredients: TRecipeStrings; ACategory: TRecipeCategory): TRecipeArray;
var
  LIndex: Integer;
  LCount: Integer;
  LRecipe: TRecipe;
begin
  Result := nil;
  LCount := 0;
  for LIndex := 0 to High(FRecipes) do
  begin
    LRecipe := FRecipes[LIndex];
    if LRecipe.HasCoreIngredient(ACoreIngredient) and
      LRecipe.MatchesCategory(ACategory) and
      LRecipe.MatchesAllIngredients(AExtraIngredients) then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := LRecipe;
      Inc(LCount);
    end;
  end;
end;

function TRecipeCatalog.CategoryCounts(const ACoreIngredient: String;
  const AExtraIngredients: TRecipeStrings): TRecipeCategoryCounts;
var
  LCat: TRecipeCategory;
  LIndex: Integer;
  LRecipe: TRecipe;
begin
  for LCat := Low(TRecipeCategory) to High(TRecipeCategory) do
    Result[LCat] := 0;
  for LIndex := 0 to High(FRecipes) do
  begin
    LRecipe := FRecipes[LIndex];
    if LRecipe.HasCoreIngredient(ACoreIngredient) and
      LRecipe.MatchesAllIngredients(AExtraIngredients) then
    begin
      Inc(Result[rcAll]);
      Inc(Result[LRecipe.Category]);
    end;
  end;
end;

function TRecipeCatalog.AvailableExtraIngredients(const ACoreIngredient: String;
  AMaxSuggestions: Integer): TRecipeStrings;
var
  LCore: String;
  LNames: TRecipeStrings;
  LCounts: array of Integer;
  LIndex: Integer;
  LIngIndex: Integer;
  LSlot: Integer;
  LName: String;
  LRecipe: TRecipe;
  LBest: Integer;
  LBestCount: Integer;
  LTempName: String;
  LTempCount: Integer;
  LLimit: Integer;
begin
  Result := nil;
  LNames := nil;
  LCounts := nil;
  LCore := NormalizeRecipeIngredient(ACoreIngredient);
  for LIndex := 0 to High(FRecipes) do
  begin
    LRecipe := FRecipes[LIndex];
    if not LRecipe.HasCoreIngredient(LCore) then
      Continue;
    for LIngIndex := 0 to High(LRecipe.Ingredients) do
    begin
      LName := NormalizeRecipeIngredient(LRecipe.Ingredients[LIngIndex]);
      if (LName = '') or (LName = LCore) or (LName = 'water') then
        Continue;
      LSlot := -1;
      for LBest := 0 to High(LNames) do
      begin
        if LNames[LBest] = LName then
        begin
          LSlot := LBest;
          Break;
        end;
      end;
      if LSlot < 0 then
      begin
        LSlot := Length(LNames);
        SetLength(LNames, LSlot + 1);
        SetLength(LCounts, LSlot + 1);
        LNames[LSlot] := LName;
        LCounts[LSlot] := 1;
      end
      else
        Inc(LCounts[LSlot]);
    end;
  end;

  // Sort by frequency descending, then alphabetically for deterministic suggestions.
  for LIndex := 0 to High(LNames) - 1 do
  begin
    LBest := LIndex;
    LBestCount := LCounts[LIndex];
    for LSlot := LIndex + 1 to High(LNames) do
    begin
      if (LCounts[LSlot] > LBestCount) or
        ((LCounts[LSlot] = LBestCount) and (LNames[LSlot] < LNames[LBest])) then
      begin
        LBest := LSlot;
        LBestCount := LCounts[LSlot];
      end;
    end;
    if LBest <> LIndex then
    begin
      LTempName := LNames[LIndex];
      LNames[LIndex] := LNames[LBest];
      LNames[LBest] := LTempName;
      LTempCount := LCounts[LIndex];
      LCounts[LIndex] := LCounts[LBest];
      LCounts[LBest] := LTempCount;
    end;
  end;

  LLimit := Length(LNames);
  if (AMaxSuggestions > 0) and (LLimit > AMaxSuggestions) then
    LLimit := AMaxSuggestions;
  SetLength(Result, LLimit);
  for LIndex := 0 to LLimit - 1 do
    Result[LIndex] := LNames[LIndex];
end;

function ExtractActiveQueryToken(const AQuery: String; out APrefixItems: TRecipeStrings): String;
var
  LIndex: Integer;
  LLastSep: Integer;
begin
  APrefixItems := nil;
  LLastSep := 0;
  for LIndex := Length(AQuery) downto 1 do
  begin
    if (AQuery[LIndex] = ',') or (AQuery[LIndex] = ';') or
      (AQuery[LIndex] = #10) or (AQuery[LIndex] = #13) then
    begin
      LLastSep := LIndex;
      Break;
    end;
  end;
  if LLastSep > 0 then
  begin
    APrefixItems := ParseIngredientList(Copy(AQuery, 1, LLastSep - 1));
    Result := CollapseSpaces(LowerCase(Trim(Copy(AQuery, LLastSep + 1, MaxInt))));
  end
  else
    Result := CollapseSpaces(LowerCase(Trim(AQuery)));
end;

function IngredientTextMatchRank(const AToken, ANormToken, AName: String): Integer;
begin
  if AToken = '' then
    Exit(0);
  if (Pos(AToken, AName) = 1) or ((ANormToken <> '') and (Pos(ANormToken, AName) = 1)) then
    Exit(0);
  if (Pos(' ' + AToken, AName) > 0) or
    ((ANormToken <> '') and (Pos(' ' + ANormToken, AName) > 0)) then
    Exit(1);
  if (Pos(AToken, AName) > 0) or ((ANormToken <> '') and (Pos(ANormToken, AName) > 0)) then
    Exit(2);
  Result := 3;
end;

function TRecipeCatalog.SuggestExtraIngredients(const ACoreIngredient: String;
  const ACurrentExtras: TRecipeStrings; ACategory: TRecipeCategory;
  const AQuery: String; AMaxResults: Integer): TRecipeIngredientCandidates;
var
  LCore: String;
  LExcluded: TRecipeStrings;
  LPrefixItems: TRecipeStrings;
  LToken: String;
  LNormToken: String;
  LAll: TRecipeIngredientCandidates;
  LRanks: array of Integer;
  LIndex: Integer;
  LIngIndex: Integer;
  LSlot: Integer;
  LRecipe: TRecipe;
  LRecipeMatches: Boolean;
  LName: String;
  LRank: Integer;
  LBest: Integer;
  LTempItem: TRecipeIngredientCandidate;
  LTempRank: Integer;
  LLimit: Integer;

  function CandidateBetter(ALeft, ARight: Integer): Boolean;
  var
    LLeftHasMatch: Boolean;
    LRightHasMatch: Boolean;
  begin
    LLeftHasMatch := LAll[ALeft].MatchCount > 0;
    LRightHasMatch := LAll[ARight].MatchCount > 0;
    if LLeftHasMatch <> LRightHasMatch then
      Exit(LLeftHasMatch);
    if LRanks[ALeft] <> LRanks[ARight] then
      Exit(LRanks[ALeft] < LRanks[ARight]);
    if LAll[ALeft].MatchCount <> LAll[ARight].MatchCount then
      Exit(LAll[ALeft].MatchCount > LAll[ARight].MatchCount);
    if LAll[ALeft].CatalogCount <> LAll[ARight].CatalogCount then
      Exit(LAll[ALeft].CatalogCount > LAll[ARight].CatalogCount);
    Result := LAll[ALeft].Name < LAll[ARight].Name;
  end;

begin
  Result := nil;
  LAll := nil;
  LRanks := nil;
  LCore := NormalizeRecipeIngredient(ACoreIngredient);
  LToken := ExtractActiveQueryToken(AQuery, LPrefixItems);
  LNormToken := NormalizeRecipeIngredient(LToken);

  LExcluded := nil;
  if LCore <> '' then
    AppendTextItem(LExcluded, LCore);
  AppendTextItem(LExcluded, 'water');
  for LIndex := 0 to High(ACurrentExtras) do
  begin
    LName := NormalizeRecipeIngredient(ACurrentExtras[LIndex]);
    if (LName <> '') and not ContainsTextItem(LExcluded, LName) then
      AppendTextItem(LExcluded, LName);
  end;
  for LIndex := 0 to High(LPrefixItems) do
    if (LPrefixItems[LIndex] <> '') and not ContainsTextItem(LExcluded, LPrefixItems[LIndex]) then
      AppendTextItem(LExcluded, LPrefixItems[LIndex]);

  for LIndex := 0 to High(FRecipes) do
  begin
    LRecipe := FRecipes[LIndex];
    LRecipeMatches := LRecipe.HasCoreIngredient(LCore) and
      ((ACategory = rcAll) or (LRecipe.Category = ACategory));
    if LRecipeMatches then
    begin
      for LSlot := 0 to High(ACurrentExtras) do
        if not LRecipe.HasIngredient(ACurrentExtras[LSlot]) then
        begin
          LRecipeMatches := False;
          Break;
        end;
    end;
    if LRecipeMatches then
    begin
      for LSlot := 0 to High(LPrefixItems) do
        if not LRecipe.HasIngredient(LPrefixItems[LSlot]) then
        begin
          LRecipeMatches := False;
          Break;
        end;
    end;
    for LIngIndex := 0 to High(LRecipe.Ingredients) do
    begin
      LName := NormalizeRecipeIngredient(LRecipe.Ingredients[LIngIndex]);
      if (LName = '') or ContainsTextItem(LExcluded, LName) then
        Continue;
      LRank := IngredientTextMatchRank(LToken, LNormToken, LName);
      if LRank > 2 then
        Continue;
      if (LToken = '') and (not LRecipeMatches) then
        Continue;
      LSlot := -1;
      for LBest := 0 to High(LAll) do
      begin
        if LAll[LBest].Name = LName then
        begin
          LSlot := LBest;
          Break;
        end;
      end;
      if LSlot < 0 then
      begin
        LSlot := Length(LAll);
        SetLength(LAll, LSlot + 1);
        SetLength(LRanks, LSlot + 1);
        LAll[LSlot].Name := LName;
        LAll[LSlot].MatchCount := 0;
        LAll[LSlot].CatalogCount := 0;
        LRanks[LSlot] := LRank;
      end;
      Inc(LAll[LSlot].CatalogCount);
      if LRecipeMatches then
        Inc(LAll[LSlot].MatchCount);
    end;
  end;

  for LIndex := 0 to High(LAll) - 1 do
  begin
    LBest := LIndex;
    for LSlot := LIndex + 1 to High(LAll) do
      if CandidateBetter(LSlot, LBest) then
        LBest := LSlot;
    if LBest <> LIndex then
    begin
      LTempItem := LAll[LIndex];
      LAll[LIndex] := LAll[LBest];
      LAll[LBest] := LTempItem;
      LTempRank := LRanks[LIndex];
      LRanks[LIndex] := LRanks[LBest];
      LRanks[LBest] := LTempRank;
    end;
  end;

  LLimit := Length(LAll);
  if (AMaxResults > 0) and (LLimit > AMaxResults) then
    LLimit := AMaxResults;
  SetLength(Result, LLimit);
  for LIndex := 0 to LLimit - 1 do
    Result[LIndex] := LAll[LIndex];
end;

function TRecipeCatalog.CoreIngredients: TRecipeStrings;
var
  LIndex: Integer;
  LCore: String;
begin
  Result := nil;
  for LIndex := 0 to High(FRecipes) do
  begin
    LCore := FRecipes[LIndex].CoreIngredient;
    if (LCore <> '') and not ContainsTextItem(Result, LCore) then
      AppendTextItem(Result, LCore);
  end;
end;

function TRecipeCatalog.ToJSON: TJSONObject;
var
  LArray: TJSONArray;
  LIndex: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('schema', FSchema);
    LArray := TJSONArray.Create;
    Result.Add('recipes', LArray);
    for LIndex := 0 to High(FRecipes) do
      LArray.Add(FRecipes[LIndex].ToJSON);
  except
    Result.Free;
    raise;
  end;
end;

function TRecipeCatalog.ToJSONString(AFormatted: Boolean): String;
var
  LObject: TJSONObject;
begin
  LObject := ToJSON;
  try
    if AFormatted then
      Result := LObject.FormatJSON([], 2)
    else
      Result := LObject.AsJSON;
  finally
    LObject.Free;
  end;
end;

procedure TRecipeCatalog.LoadFromJSON(AData: TJSONObject; AAppend: Boolean);
var
  LSchemaData: TJSONData;
  LRecipesData: TJSONData;
  LArray: TJSONArray;
  LIndex: Integer;
  LItem: TJSONData;
  LRecipe: TRecipe;
begin
  if AData = nil then
    raise EConvertError.Create('Recipe catalog JSON cannot be nil.');
  LSchemaData := AData.Find('schema');
  if (LSchemaData = nil) or (LSchemaData.JSONType <> jtString) or
    (LSchemaData.AsString <> CRecipesSchema) then
    raise EConvertError.Create('Unsupported recipe catalog schema.');
  LRecipesData := AData.Find('recipes');
  if (LRecipesData = nil) or (LRecipesData.JSONType <> jtArray) then
    raise EConvertError.Create('Recipe catalog requires a recipes array.');
  if not AAppend then
    Clear;
  FSchema := CRecipesSchema;
  LArray := TJSONArray(LRecipesData);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    LItem := LArray.Items[LIndex];
    if (LItem = nil) or (LItem.JSONType <> jtObject) then
      raise EConvertError.Create('Each recipe entry must be a JSON object.');
    LRecipe := TRecipe.FromJSON(TJSONObject(LItem));
    try
      Add(LRecipe);
    except
      LRecipe.Free;
      raise;
    end;
  end;
end;

procedure TRecipeCatalog.LoadFromJSONString(const AText: String; AAppend: Boolean);
var
  LData: TJSONData;
begin
  LData := GetJSON(AText);
  try
    if (LData = nil) or (LData.JSONType <> jtObject) then
      raise EConvertError.Create('Recipe catalog JSON root must be an object.');
    LoadFromJSON(TJSONObject(LData), AAppend);
  finally
    LData.Free;
  end;
end;

{$IFDEF PAS2JS}
function JSReadString(AObj: TJSObject; const AKey: String): String;
var
  LVal: JSValue;
begin
  LVal := AObj[AKey];
  if isString(LVal) then
    Result := Trim(String(LVal))
  else
    Result := '';
end;

function JSReadInt(AObj: TJSObject; const AKey: String; ADefault: Integer): Integer;
var
  LVal: JSValue;
begin
  LVal := AObj[AKey];
  if isNumber(LVal) then
    Result := Trunc(Double(LVal))
  else
    Result := ADefault;
end;

function JSReadFloat(AObj: TJSObject; const AKey: String; ADefault: Double): Double;
var
  LVal: JSValue;
begin
  LVal := AObj[AKey];
  if isNumber(LVal) then
    Result := Double(LVal)
  else
    Result := ADefault;
end;

function JSReadStrings(AObj: TJSObject; const AKey: String;
  ANormalizeIngredients: Boolean): TRecipeStrings;
var
  LVal: JSValue;
  LArr: TJSArray;
  LIndex: Integer;
  LText: String;
begin
  Result := nil;
  LVal := AObj[AKey];
  if not isArray(LVal) then
    Exit;
  LArr := TJSArray(LVal);
  for LIndex := 0 to LArr.Length - 1 do
  begin
    if not isString(LArr[LIndex]) then
      Continue;
    LText := Trim(String(LArr[LIndex]));
    if ANormalizeIngredients then
      LText := NormalizeRecipeIngredient(LText);
    if (LText <> '') and (not ANormalizeIngredients or not ContainsTextItem(Result, LText)) then
      AppendTextItem(Result, LText);
  end;
end;

function JSReadDetails(AObj: TJSObject; const AKey: String): TRecipeIngredientDetails;
var
  LVal: JSValue;
  LArr: TJSArray;
  LIndex: Integer;
  LEntry: TJSObject;
  LDetail: TRecipeIngredientDetail;
begin
  Result := nil;
  LVal := AObj[AKey];
  if not isArray(LVal) then
    Exit;
  LArr := TJSArray(LVal);
  SetLength(Result, LArr.Length);
  for LIndex := 0 to LArr.Length - 1 do
  begin
    LDetail := Default(TRecipeIngredientDetail);
    if isObject(LArr[LIndex]) then
    begin
      LEntry := TJSObject(LArr[LIndex]);
      LDetail.Item := JSReadString(LEntry, 'item');
      LDetail.IngredientKey := NormalizeRecipeIngredient(JSReadString(LEntry, 'key'));
      if LDetail.IngredientKey = '' then
        LDetail.IngredientKey := NormalizeRecipeIngredient(LDetail.Item);
      LDetail.Amount := JSReadFloat(LEntry, 'amount', 0);
      LDetail.AmountText := JSReadString(LEntry, 'amount_text');
      LDetail.UnitName := JSReadString(LEntry, 'unit');
      LDetail.PrepNote := JSReadString(LEntry, 'note');
    end;
    Result[LIndex] := LDetail;
  end;
end;

procedure TRecipeCatalog.LoadFromJSObject(AData: TJSObject; AAppend: Boolean);
var
  LSchema: String;
  LRecipesVal: JSValue;
  LArr: TJSArray;
  LIndex: Integer;
  LEntry: TJSObject;
  LRecipe: TRecipe;
  LCat: TRecipeCategory;
  LEffort: TRecipeEffort;
  LBaseLen: Integer;
begin
  if AData = nil then
    raise EConvertError.Create('Recipe catalog JSON cannot be nil.');
  LSchema := JSReadString(AData, 'schema');
  if LSchema <> CRecipesSchema then
    raise EConvertError.Create('Unsupported recipe catalog schema.');
  LRecipesVal := AData['recipes'];
  if not isArray(LRecipesVal) then
    raise EConvertError.Create('Recipe catalog requires a recipes array.');
  if not AAppend then
    Clear;
  FSchema := CRecipesSchema;
  LArr := TJSArray(LRecipesVal);
  LBaseLen := Length(FRecipes);
  SetLength(FRecipes, LBaseLen + LArr.Length);
  for LIndex := 0 to LArr.Length - 1 do
  begin
    if not isObject(LArr[LIndex]) then
      raise EConvertError.Create('Each recipe entry must be a JSON object.');
    LEntry := TJSObject(LArr[LIndex]);
    if not TryParseRecipeCategory(JSReadString(LEntry, 'category'), LCat) or (LCat = rcAll) then
      raise EConvertError.Create('Invalid recipe category.');
    if not TryParseRecipeEffort(JSReadString(LEntry, 'effort'), LEffort) then
      raise EConvertError.Create('Invalid recipe effort.');
    LRecipe := TRecipe.Create;
    LRecipe.FId := JSReadString(LEntry, 'id');
    LRecipe.FTitle := JSReadString(LEntry, 'title');
    LRecipe.FCoreIngredient := NormalizeRecipeIngredient(JSReadString(LEntry, 'core_ingredient'));
    LRecipe.FCategory := LCat;
    LRecipe.FEffort := LEffort;
    LRecipe.FPrepMinutes := Max(1, JSReadInt(LEntry, 'prep_minutes', 10));
    LRecipe.FCookMinutes := Max(0, JSReadInt(LEntry, 'cook_minutes', 0));
    LRecipe.FServings := Max(1, JSReadInt(LEntry, 'servings', 1));
    LRecipe.FSummary := JSReadString(LEntry, 'summary');
    LRecipe.FIngredients := JSReadStrings(LEntry, 'ingredients', True);
    if not ContainsTextItem(LRecipe.FIngredients, LRecipe.FCoreIngredient) then
      AppendTextItem(LRecipe.FIngredients, LRecipe.FCoreIngredient);
    LRecipe.FIngredientDetails := JSReadDetails(LEntry, 'ingredient_details');
    LRecipe.FEquipment := JSReadStrings(LEntry, 'equipment', False);
    LRecipe.FSteps := JSReadStrings(LEntry, 'steps', False);
    LRecipe.FTips := JSReadStrings(LEntry, 'tips', False);
    LRecipe.FTags := JSReadStrings(LEntry, 'tags', False);
    FRecipes[LBaseLen + LIndex] := LRecipe;
  end;
end;
{$ELSE}
procedure TRecipeCatalog.LoadFromFile(const AFilePath: String; AAppend: Boolean);
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create('');
  try
    LStream.LoadFromFile(AFilePath);
    LoadFromJSONString(LStream.DataString, AAppend);
  finally
    LStream.Free;
  end;
end;

procedure TRecipeCatalog.LoadFromDirectory(const ADirectory: String);
var
  LRoot: String;
  LRec: TSearchRec;
  LFiles: TStringList;
  LIndex: Integer;
begin
  Clear;
  LRoot := IncludeTrailingPathDelimiter(ADirectory);
  if not DirectoryExists(LRoot) then
    raise EInOutError.Create('Recipe directory not found: ' + ADirectory);
  LFiles := TStringList.Create;
  try
    LFiles.Sorted := True;
    if FindFirst(LRoot + '*.json', faAnyFile, LRec) = 0 then
    begin
      try
        repeat
          if (LRec.Attr and faDirectory) = 0 then
            LFiles.Add(LRoot + LRec.Name);
        until FindNext(LRec) <> 0;
      finally
        FindClose(LRec);
      end;
    end;
    for LIndex := 0 to LFiles.Count - 1 do
      LoadFromFile(LFiles[LIndex], True);
  finally
    LFiles.Free;
  end;
end;

procedure TRecipeCatalog.SaveToFile(const AFilePath: String; AFormatted: Boolean);
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(UTF8String(ToJSONString(AFormatted)));
  try
    LStream.SaveToFile(AFilePath);
  finally
    LStream.Free;
  end;
end;
{$ENDIF}

function EffortWeight(AEffort: TRecipeEffort): TGraphWeight;
begin
  case AEffort of
    reLow: Result := 3;
    reMedium: Result := 2;
  else
    Result := 1;
  end;
end;

function CollapseRecipesWithWfc(ACatalog: TRecipeCatalog;
  const AQuery: TRecipeWfcQuery): TRecipeWfcResult;
var
  LCandidates: TRecipeArray;
  LSlotCount: Integer;
  LCatCounts: array[TRecipeConcreteCategory] of Integer;
  LActiveCategories: Integer;
  LCat: TRecipeConcreteCategory;
  LGraph: TGraph;
  LReport: TGraphSolveReport;
  LOptions: TGraphSolveOptions;
  LRecipePass: Integer;
  LIndex: Integer;
  LMinCount: Integer;
  LMaxCount: Integer;
  LRecipe: TRecipe;
  LCatKey: String;
  LSelectedId: String;
begin
  Result := Default(TRecipeWfcResult);
  Result.Seed := AQuery.Seed;
  if ACatalog = nil then
  begin
    Result.Solved := True;
    Exit;
  end;

  Result.CategoryCounts := ACatalog.CategoryCounts(AQuery.CoreIngredient, AQuery.ExtraIngredients);
  LCandidates := ACatalog.Query(AQuery.CoreIngredient, AQuery.ExtraIngredients, AQuery.Category);
  Result.TotalCandidates := Length(LCandidates);
  LSlotCount := Length(LCandidates);
  if (AQuery.MaxCount > 0) and (LSlotCount > AQuery.MaxCount) then
    LSlotCount := AQuery.MaxCount;
  Result.SlotCount := LSlotCount;

  if LSlotCount = 0 then
  begin
    Result.Solved := True;
    Exit;
  end;

  for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
    LCatCounts[LCat] := 0;
  for LIndex := 0 to High(LCandidates) do
    Inc(LCatCounts[LCandidates[LIndex].Category]);
  LActiveCategories := 0;
  for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
    if LCatCounts[LCat] > 0 then
      Inc(LActiveCategories);

  LGraph := TGraph.Create;
  try
    LGraph.Seed := AQuery.Seed;
    LGraph.Reshape(TGraphCoordinate(LSlotCount), 1, 1);
    LGraph.WrapNeighbors := False;

    // Pass 1: Collapse category slots while honoring per-category candidate ceilings
    // and guaranteeing every active category appears when viewing All.
    LGraph.CurrentPass := 'category';
    for LCat := Low(TRecipeConcreteCategory) to High(TRecipeConcreteCategory) do
    begin
      if LCatCounts[LCat] <= 0 then
        Continue;
      LCatKey := RecipeCategoryKey(LCat);
      LGraph.AddValue(LCatKey, LCatCounts[LCat]);
      LMinCount := 0;
      if (AQuery.Category = rcAll) and (LActiveCategories > 1) and
        (LSlotCount >= LActiveCategories) then
        LMinCount := 1;
      LMaxCount := Min(LSlotCount, LCatCounts[LCat]);
      LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('cat_' + LCatKey,
        [LCatKey], LMinCount, LMaxCount));
    end;
    if AQuery.Category <> rcAll then
    begin
      LCatKey := RecipeCategoryKey(AQuery.Category);
      for LIndex := 0 to LSlotCount - 1 do
        LGraph.SetAllowedValues(TGraphCoordinate(LIndex), 0, 0, [LCatKey]);
    end;

    // Pass 2: Collapse unique non-repeating recipes constrained by category + ingredients.
    LGraph.SwitchToPass('recipe', LRecipePass);
    LGraph.DependsOn('category');
    for LIndex := 0 to High(LCandidates) do
    begin
      LRecipe := LCandidates[LIndex];
      LGraph.AddValue(LRecipe.Id, EffortWeight(LRecipe.Effort))
        .RequireFromPass('category', RecipeCategoryKey(LRecipe.Category));
      LGraph.RequireValueQuota(MakeGraphValueQuotaConstraint('unique_' + LRecipe.Id,
        [LRecipe.Id], 0, 1));
    end;

    LOptions := DefaultGraphSolveOptions;
    LOptions.MaxBacktracks := 256;
    Result.Solved := LGraph.TrySolve(LOptions, LReport);
    Result.Seed := LReport.Seed;
    for LIndex := 0 to High(LReport.Passes) do
    begin
      Inc(Result.Decisions, LReport.Passes[LIndex].Decisions);
      Inc(Result.Propagations, LReport.Passes[LIndex].Propagations);
      Inc(Result.Backtracks, LReport.Passes[LIndex].Backtracks);
    end;

    if Result.Solved then
    begin
      SetLength(Result.Recipes, LSlotCount);
      for LIndex := 0 to LSlotCount - 1 do
      begin
        LSelectedId := LGraph.PassGraph[LRecipePass].Entry[TGraphCoordinate(LIndex), 0, 0].Value;
        Result.Recipes[LIndex] := ACatalog.FindById(LSelectedId);
      end;
    end;
  finally
    LGraph.Free;
  end;
end;

end.
