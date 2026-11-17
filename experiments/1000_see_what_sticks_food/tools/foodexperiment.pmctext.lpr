{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentPmcText;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, SysUtils, fpjson, jsonparser, MD5, foodexperiment.https;

const
  CloudHost = 'pmc-oa-opendata.s3.amazonaws.com';
  NewLine = #10;

function GetObject(AClient: TEuropePmc; const APath: UTF8String): UTF8String;
var
  LResponse: TSearchResponse;
begin
  LResponse := AClient.GetPath(APath);
  if LResponse.Status <> 200 then
  begin
    raise EInOutError.CreateFmt('PMC Cloud HTTP %d for %s', [LResponse.Status, APath]);
  end;
  Result := LResponse.Body;
end;

function Digest(const AValue: UTF8String): String;
begin
  Result := MD5Print(MD5String(AValue));
end;

procedure Publish(const APath: String; const AValue: UTF8String);
var
  LPath: String;
  LTemporary: String;
  LTemporaryId: TGUID;
  LStream: TFileStream;
begin
  LPath := ExpandFileName(APath);
  if FileExists(LPath) then
  begin
    if MD5Print(MD5File(LPath)) <> Digest(AValue) then
    begin
      raise EInOutError.CreateFmt('Existing text differs at %s', [LPath]);
    end;
    Exit;
  end;
  if CreateGUID(LTemporaryId) <> 0 then
  begin
    raise EInOutError.Create('Could not allocate a temporary article filename');
  end;
  LTemporary := ExtractFilePath(LPath) + 'pmc-' + GUIDToString(LTemporaryId) + '.tmp';
  try
    LStream := TFileStream.Create(LTemporary, fmCreate);
    try
      LStream.WriteBuffer(AValue[1], Length(AValue));
    finally
      LStream.Free;
    end;
    if not RenameFile(LTemporary, LPath) and
      (not FileExists(LPath) or (MD5Print(MD5File(LPath)) <> Digest(AValue))) then
    begin
      raise EInOutError.CreateFmt('Could not publish verified text to %s', [LPath]);
    end;
  finally
    if FileExists(LTemporary) then
    begin
      DeleteFile(LTemporary);
    end;
  end;
end;

procedure Archive(AClient: TEuropePmc; const APmcId: UTF8String; AVersion: Integer;
  const AOutput: String);
var
  LVersionKey: UTF8String;
  LAssetPath: UTF8String;
  LAssetPrefix: UTF8String;
  LAssetUrl: UTF8String;
  LLicense: UTF8String;
  LBody: UTF8String;
  LHeader: UTF8String;
  LJson: TJSONData;
  LMeta: TJSONObject;
begin
  LVersionKey := APmcId + '.' + IntToStr(AVersion);
  LJson := GetJSON(GetObject(AClient, '/metadata/' + LVersionKey + '.json'), True);
  try
    if LJson.JSONType <> jtObject then
    begin
      raise EConvertError.Create('Unexpected PMC Cloud metadata shape');
    end;
    LMeta := TJSONObject(LJson);
    if (LMeta.Get('pmcid', '') <> APmcId) or (LMeta.Get('version', 0) <> AVersion) then
    begin
      raise EConvertError.Create('PMC Cloud article version does not match the request');
    end;
    LLicense := LMeta.Get('license_code', '');
    if (LLicense <> 'CC0') and (LLicense <> 'CC BY') and (LLicense <> 'CC BY-SA') then
    begin
      raise EConvertError.Create('Article license is outside the research archive scope');
    end;

    LAssetPath := '/' + LVersionKey + '/' + LVersionKey + '.txt';
    LAssetPrefix := 's3://pmc-oa-opendata' + LAssetPath + '?md5=';
    LAssetUrl := LMeta.Get('text_url', '');
    if (Copy(LAssetUrl, 1, Length(LAssetPrefix)) <> LAssetPrefix) or
      (Length(LAssetUrl) <> Length(LAssetPrefix) + 32) then
    begin
      raise EConvertError.Create('PMC Cloud text URL does not match the article version');
    end;
    LBody := GetObject(AClient, LAssetPath);
    if (LBody = '') or (Digest(LBody) <> Copy(LAssetUrl, Length(LAssetPrefix) + 1, 32)) then
    begin
      raise EInOutError.Create('PMC Cloud text checksum does not match the provider metadata');
    end;

    LHeader :=
      'Title: ' + LMeta.Get('title', '') + NewLine +
      'Source: https://pmc.ncbi.nlm.nih.gov/articles/' + APmcId + '/' + NewLine +
      'Text object: https://' + CloudHost + LAssetPath + NewLine +
      'Text object MD5: ' + Copy(LAssetUrl, Length(LAssetPrefix) + 1, 32) + NewLine +
      'Data source: U.S. National Library of Medicine, PMC Cloud Service' + NewLine +
      'PMCID: ' + APmcId + NewLine +
      'PMID: ' + IntToStr(LMeta.Get('pmid', 0)) + NewLine +
      'DOI: ' + LMeta.Get('doi', '') + NewLine +
      'Citation: ' + LMeta.Get('citation', '') + NewLine +
      'License: ' + LLicense + ' (article license statement below)' + NewLine +
      'Version: ' + IntToStr(AVersion) + NewLine +
      'Retracted in PMC metadata: ' +
        BoolToStr(LMeta.Get('is_retracted', False), 'yes', 'no') + NewLine +
      'Text coverage: article text' + NewLine +
      'Format: NLM plain-text extraction. This provenance header was added.' + NewLine + NewLine;
    Publish(AOutput, LHeader + LBody);
    WriteLn('Verified ', LVersionKey, ' ', LLicense, ' ', Length(LBody), ' source bytes');
  finally
    LJson.Free;
  end;
end;

procedure Run;
var
  LPmcId: String;
  LVersion: Integer;
  LClient: TEuropePmc;
  I: Integer;
begin
  if ParamCount <> 3 then
  begin
    raise EArgumentException.Create('Usage: foodexperiment.pmctext PMCID VERSION OUTPUT_FILE');
  end;
  LPmcId := ParamStr(1);
  if (Copy(LPmcId, 1, 3) <> 'PMC') or (Length(LPmcId) < 4) or
    not TryStrToInt(ParamStr(2), LVersion) or (LVersion < 1) then
  begin
    raise EArgumentException.Create('Expected a PMC article ID and positive version');
  end;
  for I := 4 to Length(LPmcId) do
  begin
    if not (LPmcId[I] in ['0'..'9']) then
    begin
      raise EArgumentException.Create('Expected decimal digits after PMC');
    end;
  end;
  LClient := TEuropePmc.Create(CloudHost);
  try
    Archive(LClient, LPmcId, LVersion, ParamStr(3));
  finally
    LClient.Free;
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
