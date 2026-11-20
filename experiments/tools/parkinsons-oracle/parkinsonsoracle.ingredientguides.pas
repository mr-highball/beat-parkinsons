{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.ingredientguides;

{$mode delphi}{$H+}{$codepage utf8}

interface

type
  TGalleryFrame = record
    Asset: String;
    Caption: String;
    Description: String;
    Credit: String;
    CreditURL: String;
    Column: Integer;
    Row: Integer;
    GridColumns: Integer;
    GridRows: Integer;
  end;

  TIngredientGuide = record
    Ingredient: String;
    Tip: String;
    TipSource: String;
    TipURL: String;
    Frames: array[0..1] of TGalleryFrame;
  end;

{$I web/oraclegallerydata.inc}

function IngredientGuideIndex(const AIngredient: String): Integer;

implementation

uses SysUtils;

function IngredientGuideIndex(const AIngredient: String): Integer;
var
  LIndex: Integer;
begin
  Result := -1;
  for LIndex := Low(CIngredientGuides) to High(CIngredientGuides) do
  begin
    if SameText(CIngredientGuides[LIndex].Ingredient, AIngredient) then
    begin
      Exit(LIndex);
    end;
  end;
end;

end.
