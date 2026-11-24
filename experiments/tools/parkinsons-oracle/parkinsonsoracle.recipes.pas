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
  if (Result = 'celery') or (Result = 'celery rib') or (Result = 'celery ribs') or
    (Result = 'celery stalks') or (Result = 'raw celery') or (Result = 'raw celery stalk') then
    Exit('celery stalk');
  if (Result = 'black peppercorn') or (Result = 'black peppercorns') or
    (Result = 'cracked black pepper') or (Result = 'ground black pepper') or
    (Result = 'pepper') or (Result = 'black peppers') then
    Exit('black pepper');
  if (Result = 'onions') or (Result = 'yellow onion') or (Result = 'yellow onions') or
    (Result = 'sweet onion') or (Result = 'sweet onions') or (Result = 'red onion') or
    (Result = 'red onions') or (Result = 'white onion') or (Result = 'white onions') then
    Exit('onion');
  if (Result = 'garlic clove') or (Result = 'garlic cloves') then
    Exit('garlic');
  if (Result = 'bell peppers') or (Result = 'sweet pepper') or (Result = 'sweet peppers') then
    Exit('bell pepper');
  if (Result = 'ginger root') or (Result = 'fresh ginger') then
    Exit('ginger');
  if (Result = 'lemon juice') or (Result = 'lemons') then
    Exit('lemon');
  if (Result = 'lime juice') or (Result = 'limes') then
    Exit('lime');
  if (Result = 'green apple') or (Result = 'green apples') or (Result = 'apples') then
    Exit('apple');
  if (Result = 'chickpeas') or (Result = 'garbanzo bean') or (Result = 'garbanzo beans') then
    Exit('chickpea');
  if (Result = 'lentils') or (Result = 'red lentil') or (Result = 'red lentils') then
    Exit('lentil');
  if (Result = 'white beans') or (Result = 'cannellini bean') or (Result = 'cannellini beans') then
    Exit('white bean');
  if (Result = 'sweet potatoes') then
    Exit('sweet potato');
  if (Result = 'potatoes') then
    Exit('potato');
  if (Result = 'tomatoes') then
    Exit('tomato');
  if (Result = 'blueberries') then
    Exit('blueberry');
  if (Result = 'oats') or (Result = 'rolled oats') or (Result = 'oat') then
    Exit('oats');
  if (Result = 'extra virgin olive oil') or (Result = 'evoo') then
    Exit('olive oil');

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
procedure TRecipeCatalog.LoadFromJSObject(AData: TJSObject; AAppend: Boolean);
var
  LData: TJSONData;
begin
  LData := JSValueToJSONData(AData);
  try
    if (LData = nil) or (LData.JSONType <> jtObject) then
      raise EConvertError.Create('Recipe catalog JSON root must be an object.');
    LoadFromJSON(TJSONObject(LData), AAppend);
  finally
    LData.Free;
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
