{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleGraphEmbed;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, Classes, fpjson, FPSHA256, parkinsonsoracle.claims;

procedure Run;
var
  LIndex: TClaimIndex;
  LModel: TJSONObject;
  LParts: TStringList;
  LOutput: TStringList;
  LJSON: String;
  LPart: String;
  LPosition: Integer;
  LCount: Integer;
  LNumber: Integer;
  LStream: TStringStream;
  LHash: String;
begin
  if ParamCount <> 2 then
  begin
    raise EArgumentException.Create('Usage: graph.embed REPOSITORY OUTPUT_INCLUDE');
  end;
  LIndex := TClaimIndex.Create(ExpandFileName(ParamStr(1)));
  LParts := TStringList.Create;
  LOutput := TStringList.Create;
  try
    LModel := LIndex.StaticModel('');
    try
      LJSON := LModel.AsJSON;
      LStream := TStringStream.Create(LJSON);
      try
        TSHA256.StreamHexa(LStream, LHash);
      finally
        LStream.Free;
      end;
      LHash := LowerCase(LHash);
      LPosition := 1;
      while LPosition <= Length(LJSON) do
      begin
        LCount := Length(LJSON) - LPosition + 1;
        if LCount > 2048 then
        begin
          LCount := 2048;
          { Each Pascal literal must end at a UTF-8 scalar boundary. }
          while (Ord(LJSON[LPosition + LCount]) and $C0) = $80 do
          begin
            Dec(LCount);
          end;
        end;
        LPart := Copy(LJSON, LPosition, LCount);
        LParts.Add('''' + StringReplace(LPart, '''', '''''', [rfReplaceAll]) + '''');
        Inc(LPosition, LCount);
      end;
      LOutput.Add('const COracleGraphSHA256 = ''' + LHash + ''';');
      LOutput.Add('const COracleGraphParts: array[0..' + IntToStr(LParts.Count - 1) +
        '] of String = (');
      for LNumber := 0 to LParts.Count - 1 do
      begin
        LPart := LParts[LNumber];
        if LNumber < LParts.Count - 1 then
        begin
          LPart := LPart + ',';
        end;
        LOutput.Add(LPart);
      end;
      LOutput.Add(');');
      ForceDirectories(ExtractFileDir(ExpandFileName(ParamStr(2))));
      LOutput.LineBreak := #10;
      LOutput.WriteBOM := False;
      LOutput.SaveToFile(ParamStr(2), TEncoding.UTF8);
      WriteLn('graph_revision=', LModel.Strings['revision'],
        ' claims=', LModel.Arrays['claims'].Count, ' model_bytes=', Length(LJSON),
        ' model_sha256=', LHash);
    finally
      LModel.Free;
    end;
  finally
    LOutput.Free;
    LParts.Free;
    LIndex.Free;
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
