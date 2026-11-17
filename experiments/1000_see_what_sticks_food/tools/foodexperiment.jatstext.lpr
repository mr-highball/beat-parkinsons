{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentJatsText;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  Classes, DOM, SysUtils, XMLRead;

function FindDoi(AMetadata: TDOMNode): String;
var
  LNode: TDOMNode;
begin
  LNode := AMetadata.FirstChild;
  while Assigned(LNode) do
  begin
    if (LNode.NodeName = 'article-id') and
      (TDOMElement(LNode).GetAttribute('pub-id-type') = 'doi') then
    begin
      Exit(Trim(UTF8Encode(LNode.TextContent)));
    end;
    LNode := LNode.NextSibling;
  end;
  raise EConvertError.Create('Missing article DOI');
end;

procedure AppendText(ANode: TDOMNode; AOutput: TStream);
var
  LChild: TDOMNode;
  LText: UTF8String;
begin
  if ANode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE] then
  begin
    LText := UTF8Encode(ANode.NodeValue);
    if LText <> '' then
    begin
      AOutput.WriteBuffer(LText[1], Length(LText));
    end;
    Exit;
  end;
  LChild := ANode.FirstChild;
  while Assigned(LChild) do
  begin
    AppendText(LChild, AOutput);
    LChild := LChild.NextSibling;
  end;
  if (ANode.NodeName = 'td') or (ANode.NodeName = 'th') then
  begin
    AOutput.WriteByte(9);
  end
  else if (ANode.NodeName = 'title') or (ANode.NodeName = 'p') or
    (ANode.NodeName = 'tr') or (ANode.NodeName = 'ref') or
    (ANode.NodeName = 'break') or (ANode.NodeName = 'article-title') or
    (ANode.NodeName = 'contrib') or (ANode.NodeName = 'aff') or
    (ANode.NodeName = 'journal-meta') or (ANode.NodeName = 'article-id') or
    (ANode.NodeName = 'pub-date') or (ANode.NodeName = 'history') then
  begin
    AOutput.WriteByte(10);
  end;
end;

procedure Archive(const AInput, ADoi, ASource, AOutput: String);
const
  CSections: array[0..2] of String = ('front', 'body', 'back');
var
  LDocument: TXMLDocument;
  LParser: TDOMParser;
  LSourceStream: TFileStream;
  LInput: TXMLInputSource;
  LRoot: TDOMElement;
  LFront: TDOMNode;
  LMetadata: TDOMNode;
  LPermissions: TDOMNode;
  LLicense: TDOMNode;
  LSection: TDOMNode;
  LBuffer: TMemoryStream;
  LFile: TFileStream;
  LHeader: UTF8String;
  LSectionName: String;
  LSectionIndex: Integer;
  LLicenseUrl: String;
begin
  if FileExists(AOutput) then
  begin
    raise EInOutError.Create('Use a new output file');
  end;
  LDocument := nil;
  LParser := TDOMParser.Create;
  try
    LParser.Options.DisallowDoctype := True;
    LParser.Options.IgnoreComments := True;
    LSourceStream := TFileStream.Create(AInput, fmOpenRead or fmShareDenyWrite);
    try
      LInput := TXMLInputSource.Create(LSourceStream);
      try
        LParser.Parse(LInput, LDocument);
      finally
        LInput.Free;
      end;
    finally
      LSourceStream.Free;
    end;
    LRoot := LDocument.DocumentElement;
    if not Assigned(LRoot) or (LRoot.NodeName <> 'article') then
    begin
      raise EConvertError.Create('Expected one JATS article');
    end;
    LFront := LRoot.FindNode('front');
    if not Assigned(LFront) then
    begin
      raise EConvertError.Create('Missing JATS front matter');
    end;
    LMetadata := LFront.FindNode('article-meta');
    if not Assigned(LMetadata) or (FindDoi(LMetadata) <> ADoi) then
    begin
      raise EConvertError.Create('Article DOI mismatch');
    end;
    LPermissions := LMetadata.FindNode('permissions');
    if not Assigned(LPermissions) then
    begin
      raise EConvertError.Create('Missing permissions');
    end;
    LLicense := LPermissions.FindNode('license');
    if not Assigned(LLicense) then
    begin
      raise EConvertError.Create('Missing article license');
    end;
    LLicenseUrl := UTF8Encode(TDOMElement(LLicense).GetAttribute('xlink:href'));
    if (LLicenseUrl <> 'http://creativecommons.org/licenses/by/4.0/') and
      (LLicenseUrl <> 'https://creativecommons.org/licenses/by/4.0/') then
    begin
      raise EConvertError.Create('Expected a verified CC BY 4.0 license');
    end;
    LBuffer := TMemoryStream.Create;
    try
      LHeader := 'Source: ' + ASource + #10 + 'DOI: ' + ADoi + #10 +
        'License: CC BY 4.0 (publisher JATS permissions)' + #10 +
        'Text coverage: publisher article front, body and back matter; images omitted' + #10 +
        'Format: native JATS text extraction; table cells are tab separated' + #10#10;
      LBuffer.WriteBuffer(LHeader[1], Length(LHeader));
      for LSectionIndex := Low(CSections) to High(CSections) do
      begin
        LSectionName := CSections[LSectionIndex];
        LSection := LRoot.FindNode(UTF8Decode(LSectionName));
        if not Assigned(LSection) then
        begin
          raise EConvertError.Create('Missing article ' + LSectionName);
        end;
        LHeader := UpperCase(LSectionName) + #10;
        LBuffer.WriteBuffer(LHeader[1], Length(LHeader));
        AppendText(LSection, LBuffer);
        LBuffer.WriteByte(10);
      end;
      LBuffer.Position := 0;
      LFile := TFileStream.Create(AOutput, fmCreate);
      try
        LFile.CopyFrom(LBuffer, 0);
      finally
        LFile.Free;
      end;
    finally
      LBuffer.Free;
    end;
  finally
    LDocument.Free;
    LParser.Free;
  end;
end;

begin
  if ParamCount <> 4 then
  begin
    raise EArgumentException.Create('Usage: foodexperiment.jatstext XML DOI SOURCE-URL OUTPUT');
  end;
  Archive(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
end.
