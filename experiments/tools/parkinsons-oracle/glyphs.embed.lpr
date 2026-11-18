{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleGlyphsEmbed;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, FPImage, FPReadPNG, FPWritePNG, ZStream, Base64;

const
  CGlyphs: array[0..13] of String = ('all', 'study', 'culture', 'symptoms',
    'sources', 'eases', 'worsens', 'unclear', 'search', 'filters', 'guide',
    'reference', 'ingredient', 'preparation');

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure Run;
var
  LInput: TFPMemoryImage;
  LMask: TFPMemoryImage;
  LVerify: TFPMemoryImage;
  LReader: TFPReaderPNG;
  LWriter: TFPWriterPNG;
  LBuffer: TMemoryStream;
  LFile: TFileStream;
  LCss: TStringList;
  LName: String;
  LPath: String;
  LEncoded: String;
  LBytes: RawByteString;
  LColor: TFPColor;
  LX: Integer;
  LY: Integer;
  LTransparent: Boolean;
  LOpaque: Boolean;
  LInputBytes: Int64;
  LMaskBytes: Int64;
  LCheckedPixels: Int64;
begin
  Require(ParamCount = 2, 'Usage: glyphs.embed INPUT_GLYPH_DIRECTORY OUTPUT_CSS');
  LInputBytes := 0;
  LMaskBytes := 0;
  LCheckedPixels := 0;
  LCss := TStringList.Create;
  try
    LCss.Add('/* Generated from imagegen masters; alpha preserved pixel for pixel. */');
    LCss.Add(':root {');
    for LName in CGlyphs do
    begin
      LPath := IncludeTrailingPathDelimiter(ParamStr(1)) + LName + '.png';
      LInput := TFPMemoryImage.Create(0, 0);
      LMask := TFPMemoryImage.Create(0, 0);
      LVerify := TFPMemoryImage.Create(0, 0);
      LReader := TFPReaderPNG.Create;
      LWriter := TFPWriterPNG.Create;
      LBuffer := TMemoryStream.Create;
      try
        LFile := TFileStream.Create(LPath, fmOpenRead or fmShareDenyWrite);
        try
          Inc(LInputBytes, LFile.Size);
          LInput.LoadFromStream(LFile, LReader);
        finally
          LFile.Free;
        end;
        LMask.SetSize(LInput.Width, LInput.Height);
        LTransparent := False;
        LOpaque := False;
        for LY := 0 to LInput.Height - 1 do
        begin
          for LX := 0 to LInput.Width - 1 do
          begin
            LColor := LInput.Colors[LX, LY];
            Require((LColor.Alpha mod 257) = 0, 'Expected lossless 8-bit alpha: ' + LName);
            LTransparent := LTransparent or (LColor.Alpha = 0);
            LOpaque := LOpaque or (LColor.Alpha = 65535);
            LColor.Red := 0;
            LColor.Green := 0;
            LColor.Blue := 0;
            LMask.Colors[LX, LY] := LColor;
          end;
        end;
        Require(LTransparent and LOpaque, 'Glyph requires transparent and opaque pixels: ' + LName);
        LWriter.GrayScale := True;
        LWriter.UseAlpha := True;
        LWriter.WordSized := False;
        LWriter.CompressionLevel := clMax;
        LMask.SaveToStream(LBuffer, LWriter);
        Inc(LMaskBytes, LBuffer.Size);
        LBuffer.Position := 0;
        LVerify.LoadFromStream(LBuffer, LReader);
        Require((LVerify.Width = LInput.Width) and (LVerify.Height = LInput.Height),
          'Glyph dimensions changed: ' + LName);
        for LY := 0 to LInput.Height - 1 do
        begin
          for LX := 0 to LInput.Width - 1 do
          begin
            Require(LVerify.Colors[LX, LY].Alpha = LInput.Colors[LX, LY].Alpha,
              'Generated glyph alpha changed: ' + LName);
            Inc(LCheckedPixels);
          end;
        end;
        LBuffer.Position := 0;
        SetLength(LBytes, LBuffer.Size);
        LBuffer.ReadBuffer(LBytes[1], Length(LBytes));
        LEncoded := EncodeStringBase64(LBytes);
        LEncoded := StringReplace(LEncoded, #13, '', [rfReplaceAll]);
        LEncoded := StringReplace(LEncoded, #10, '', [rfReplaceAll]);
        LCss.Add('  --glyph-' + LName + ': url("data:image/png;base64,' + LEncoded + '");');
      finally
        LBuffer.Free;
        LWriter.Free;
        LReader.Free;
        LVerify.Free;
        LMask.Free;
        LInput.Free;
      end;
    end;
    LCss.Add('}');
    ForceDirectories(ExtractFileDir(ExpandFileName(ParamStr(2))));
    LCss.LineBreak := #10;
    LCss.WriteBOM := False;
    LCss.SaveToFile(ParamStr(2), TEncoding.UTF8);
    WriteLn('glyphs=', Length(CGlyphs), ' source_bytes=', LInputBytes,
      ' mask_bytes=', LMaskBytes, ' alpha_pixels_verified=', LCheckedPixels);
  finally
    LCss.Free;
  end;
end;

begin
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
