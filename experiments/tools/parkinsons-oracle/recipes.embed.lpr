{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleRecipesExport;

{$mode delphi}{$H+}{$codepage utf8}

uses
  SysUtils, Classes, parkinsonsoracle.compat, parkinsonsoracle.recipes;

procedure Run;
var
  LRepo: String;
  LRecipesDir: String;
  LOutput: String;
  LCatalog: TRecipeCatalog;
  LRoundTrip: TRecipeCatalog;
  LJson: UTF8String;
  LHash: String;
  LStream: TStringStream;
begin
  if ParamCount <> 2 then
    raise EArgumentException.Create('Usage: recipes.embed REPOSITORY OUTPUT_JSON');
  LRepo := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  LRecipesDir := LRepo + 'experiments' + PathDelim +
    '1000_see_what_sticks_food_all_recipes' + PathDelim + 'recipes';
  LOutput := ParamStr(2);

  LCatalog := TRecipeCatalog.Create;
  try
    LCatalog.LoadFromDirectory(LRecipesDir);
    if LCatalog.Count = 0 then
      raise EConvertError.Create('No recipes found in ' + LRecipesDir);
    LJson := UTF8String(LCatalog.ToJSONString(False));

    // Verify serialized output deserializes cleanly back into TRecipeCatalog.
    LRoundTrip := TRecipeCatalog.Create;
    try
      LRoundTrip.LoadFromJSONString(String(LJson));
      if LRoundTrip.Count <> LCatalog.Count then
        raise EConvertError.Create('Recipe catalog round-trip count mismatch.');
    finally
      LRoundTrip.Free;
    end;

    LHash := ComputeSha256Hex(RawByteString(LJson));
    LStream := TStringStream.Create(LJson);
    try
      LStream.SaveToFile(LOutput);
      WriteLn('recipes=', LCatalog.Count, ' core_ingredients=', Length(LCatalog.CoreIngredients),
        ' bytes=', LStream.Size, ' sha256=', LHash);
    finally
      LStream.Free;
    end;
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
