{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleGraphExport;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, Classes, fpjson, parkinsonsoracle.compat, parkinsonsoracle.claims;

procedure Run;
var
  LIndex: TClaimIndex;
  LModel: TJSONObject;
  LStream: TStringStream;
  LJson: UTF8String;
  LHash: String;
begin
  if ParamCount <> 2 then
  begin
    raise EArgumentException.Create('Usage: graph.embed REPOSITORY OUTPUT_JSON');
  end;
  LIndex := TClaimIndex.Create(ExpandFileName(ParamStr(1)));
  try
    LModel := LIndex.StaticModel('');
    try
      LJson := UTF8String(LModel.AsJSON);
      LHash := ComputeSha256Hex(RawByteString(LJson));
      LStream := TStringStream.Create(LJson);
      try
        LStream.SaveToFile(ParamStr(2));
        WriteLn('graph_revision=', LModel.Strings['revision'],
          ' claims=', LModel.Arrays['claims'].Count, ' model_bytes=', LStream.Size,
          ' model_sha256=', LHash);
      finally
        LStream.Free;
      end;
    finally
      LModel.Free;
    end;
  finally
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
