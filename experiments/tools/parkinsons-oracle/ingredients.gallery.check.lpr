{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program IngredientGalleryCheck;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, Types, StrUtils, Math, Generics.Collections, FPImage, FPReadJPEG, FPWriteJPEG,
  foodexperiment.externaldata, parkinsonsoracle.ingredientguides;

procedure Require(ATest: Boolean; const AMessage: String);
begin
  if not ATest then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

procedure ValidateFrame(const AFrame: TGalleryFrame; const AAssetRoot: String;
  ASizes: TDictionary<String, TPoint>);
var
  LImage: TFPMemoryImage;
  LSize: TPoint;
  LIndex: Integer;
begin
  Require((Length(AFrame.Asset) > 4) and EndsStr('.jpg', AFrame.Asset),
    'Gallery frames require a local JPEG.');
  for LIndex := 1 to Length(AFrame.Asset) - 4 do
  begin
    Require(CharInSet(AFrame.Asset[LIndex], ['a'..'z', '0'..'9', '-']),
      'Invalid gallery asset ' + AFrame.Asset);
  end;
  Require((AFrame.Caption <> '') and (AFrame.Description <> '') and (AFrame.Credit <> ''),
    'Missing preparation, accessible description or provenance for ' + AFrame.Asset);
  if AFrame.CreditURL <> '' then
  begin
    Require(StartsStr('https://', AFrame.CreditURL), 'Invalid photo credit URL');
  end
  else
  begin
    Require(AFrame.Credit = 'ImageGen illustration', 'Missing source for a photograph');
  end;
  if not ASizes.TryGetValue(AFrame.Asset, LSize) then
  begin
    LImage := TFPMemoryImage.Create(0, 0);
    try
      LImage.LoadFromFile(IncludeTrailingPathDelimiter(AAssetRoot) + AFrame.Asset);
      LSize := Point(LImage.Width, LImage.Height);
      ASizes.Add(AFrame.Asset, LSize);
    finally
      LImage.Free;
    end;
  end;
  if AFrame.Column < 0 then
  begin
    Require((AFrame.Column = -1) and (AFrame.GridColumns = 0) and (AFrame.GridRows = 0),
      'Invalid single photograph coordinates');
    Exit;
  end;
  Require((AFrame.GridColumns >= 2) and (AFrame.GridRows >= 2),
    'A gallery atlas requires at least two rows and columns');
  Require((AFrame.Column < AFrame.GridColumns) and (AFrame.Row >= 0) and
    (AFrame.Row < AFrame.GridRows), 'Gallery tile lies outside ' + AFrame.Asset);
  Require((LSize.X mod AFrame.GridColumns = 0) and (LSize.Y mod AFrame.GridRows = 0) and
    (LSize.X div AFrame.GridColumns = LSize.Y div AFrame.GridRows),
    'Gallery atlas does not contain equal square cells: ' + AFrame.Asset);
end;

procedure BuildThumbnails(const AAssetRoot, AOutput: String);
const
  CSize = 128;
var
  LSource: TFPMemoryImage;
  LPreview: TFPMemoryImage;
  LWriter: TFPWriterJPEG;
  LFrame: TGalleryFrame;
  LAsset: String;
  LWidth: Integer;
  LLeft: Integer;
  LTop: Integer;
  LIndex: Integer;
  X, Y, SX, SY: Integer;
  LX0, LX1, LY0, LY1: Integer;
  LCount, LRed, LGreen, LBlue: QWord;
  LColor: TFPColor;
begin
  Require(ForceDirectories(AOutput), 'Cannot create the ingredient thumbnail directory');
  LSource := TFPMemoryImage.Create(0, 0);
  LPreview := TFPMemoryImage.Create(CSize, CSize);
  LWriter := TFPWriterJPEG.Create;
  try
    LWriter.CompressionQuality := 83;
    LAsset := '';
    for LIndex := Low(CIngredientGuides) to High(CIngredientGuides) do
    begin
      LFrame := CIngredientGuides[LIndex].Frames[0];
      if LAsset <> LFrame.Asset then
      begin
        LAsset := LFrame.Asset;
        LSource.LoadFromFile(IncludeTrailingPathDelimiter(AAssetRoot) + LAsset);
      end;
      if LFrame.Column >= 0 then
      begin
        LWidth := LSource.Width div LFrame.GridColumns;
        LLeft := LWidth * LFrame.Column;
        LTop := LWidth * LFrame.Row;
      end
      else
      begin
        LWidth := Min(LSource.Width, LSource.Height);
        LLeft := (LSource.Width - LWidth) div 2;
        LTop := (LSource.Height - LWidth) div 2;
      end;
      for Y := 0 to CSize - 1 do
      begin
        LY0 := LTop + Y * LWidth div CSize;
        LY1 := Max(LY0 + 1, LTop + (Y + 1) * LWidth div CSize);
        for X := 0 to CSize - 1 do
        begin
          LX0 := LLeft + X * LWidth div CSize;
          LX1 := Max(LX0 + 1, LLeft + (X + 1) * LWidth div CSize);
          LCount := (LX1 - LX0) * (LY1 - LY0);
          LRed := 0;
          LGreen := 0;
          LBlue := 0;
          for SY := LY0 to LY1 - 1 do
          begin
            for SX := LX0 to LX1 - 1 do
            begin
              LColor := LSource.Colors[SX, SY];
              Inc(LRed, LColor.Red);
              Inc(LGreen, LColor.Green);
              Inc(LBlue, LColor.Blue);
            end;
          end;
          LColor.Red := LRed div LCount;
          LColor.Green := LGreen div LCount;
          LColor.Blue := LBlue div LCount;
          LColor.Alpha := AlphaOpaque;
          LPreview.Colors[X, Y] := LColor;
        end;
      end;
      LPreview.SaveToFile(IncludeTrailingPathDelimiter(AOutput) +
        IngredientThumbnailName(LIndex), LWriter);
    end;
    WriteLn(Length(CIngredientGuides), ' ingredient thumbnails at ', CSize, ' px.');
  finally
    LWriter.Free;
    LPreview.Free;
    LSource.Free;
  end;
end;

procedure Run(const AVocabulary, AAssetRoot: String);
var
  LVocabulary: TStringList;
  LNames: TStringList;
  LCovered: TStringList;
  LFrames: TStringList;
  LSizes: TDictionary<String, TPoint>;
  LFields: TFields;
  LIndex: Integer;
  LGuide: TIngredientGuide;
  LFrame: TGalleryFrame;
begin
  LVocabulary := TStringList.Create;
  LNames := TStringList.Create;
  LCovered := TStringList.Create;
  LFrames := TStringList.Create;
  LSizes := TDictionary<String, TPoint>.Create;
  try
    LNames.CaseSensitive := True;
    LCovered.CaseSensitive := True;
    LFrames.Sorted := True;
    LFrames.Duplicates := dupError;
    LNames.Sorted := True;
    LNames.Duplicates := dupError;
    LCovered.Sorted := True;
    LCovered.Duplicates := dupError;
    LVocabulary.LoadFromFile(AVocabulary, TEncoding.UTF8);
    for LIndex := 1 to LVocabulary.Count - 1 do
    begin
      LFields := SplitFields(LVocabulary[LIndex], #9);
      Require((Length(LFields) >= 3) and (Length(LFields) <= 4), 'Malformed ingredient vocabulary');
      LNames.Add(LFields[1]);
    end;
    for LGuide in CIngredientGuides do
    begin
      Require(LNames.IndexOf(LGuide.Ingredient) >= 0, 'Unknown ingredient: ' + LGuide.Ingredient);
      LCovered.Add(LGuide.Ingredient);
      Require((LGuide.Tip <> '') and (LGuide.TipSource <> '') and
        StartsStr('https://', LGuide.TipURL), 'Missing vetted tip for ' + LGuide.Ingredient);
      Require((LGuide.Frames[0].Caption <> LGuide.Frames[1].Caption) and
        (LGuide.Frames[0].Description <> LGuide.Frames[1].Description),
        'Gallery repeats a preparation for ' + LGuide.Ingredient);
      for LFrame in LGuide.Frames do
      begin
        ValidateFrame(LFrame, AAssetRoot, LSizes);
        LFrames.Add(Format('%s/%d/%d', [LFrame.Asset, LFrame.Column, LFrame.Row]));
      end;
    end;
    WriteLn(LCovered.Count, '/', LNames.Count, ' ingredient galleries, ', LCovered.Count * 2,
      ' preparation frames, ', LSizes.Count, ' verified image assets.');
    for LIndex := 0 to LNames.Count - 1 do
    begin
      if LCovered.IndexOf(LNames[LIndex]) < 0 then
      begin
        WriteLn('Missing gallery: ', LNames[LIndex]);
      end;
    end;
    Require(LCovered.Count = LNames.Count, 'Gallery vocabulary coverage is incomplete');
  finally
    LSizes.Free;
    LFrames.Free;
    LCovered.Free;
    LNames.Free;
    LVocabulary.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    Require(ParamCount in [2, 3], 'Provide ingredient vocabulary, gallery assets and optional thumbnail output.');
    Run(ParamStr(1), ParamStr(2));
    if ParamCount = 3 then
    begin
      BuildThumbnails(ParamStr(2), ParamStr(3));
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
