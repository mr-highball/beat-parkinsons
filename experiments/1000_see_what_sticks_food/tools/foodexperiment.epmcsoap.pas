{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.epmcsoap;

{$mode delphi}
{$H+}

interface

function SoapSearchRequest(const AQuery, ACursor: UTF8String; APageSize: Integer;
  const ASort: UTF8String): UTF8String;
function SoapSearchResult(const ABody: UTF8String; const AContentType: UnicodeString): UTF8String;

implementation

uses Classes, SysUtils, StrUtils, DOM, XMLRead, fpjson;

function XmlText(const AValue: UTF8String): UTF8String;
var
  LText: UnicodeString;
begin
  LText := StringReplace(UTF8Decode(AValue), UnicodeString('&'), UnicodeString('&amp;'), [rfReplaceAll]);
  LText := StringReplace(LText, UnicodeString('<'), UnicodeString('&lt;'), [rfReplaceAll]);
  LText := StringReplace(LText, UnicodeString('>'), UnicodeString('&gt;'), [rfReplaceAll]);
  Result := UTF8Encode(LText);
end;

function SoapSearchRequest(const AQuery, ACursor: UTF8String; APageSize: Integer;
  const ASort: UTF8String): UTF8String;
begin
  if (APageSize < 1) or (APageSize > 1000) or (ACursor = '') then
  begin
    raise EArgumentException.Create('Invalid Europe PMC page size or empty cursor');
  end;
  Result := '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ' +
    'xmlns:e="http://webservice.cdb.ebi.ac.uk/"><s:Body><e:searchPublications>' +
    '<queryString>' + XmlText(AQuery) + '</queryString><resultType>core</resultType>' +
    '<cursorMark>' + XmlText(ACursor) + '</cursorMark><pageSize>' +
    IntToStr(APageSize) + '</pageSize>';
  if ASort <> '' then
  begin
    Result := Result + '<sort>' + XmlText(ASort) + '</sort>';
  end;
  Result := Result + '</e:searchPublications></s:Body></s:Envelope>';
end;

function FirstSoapPart(const ABody: UTF8String; const AContentType: UnicodeString): UTF8String;
var
  LBoundaryStart: SizeInt;
  LBoundaryEnd: SizeInt;
  LHeadersEnd: SizeInt;
  LPartEnd: SizeInt;
  LBoundary: UTF8String;
begin
  if not StartsText('multipart/related', UTF8Encode(AContentType)) then
  begin
    Exit(ABody);
  end;
  // Europe PMC sends the XML as the first MIME part, even without attachments.
  LBoundaryStart := 1;
  if Copy(ABody, 1, 2) = #13#10 then
  begin
    LBoundaryStart := 3;
  end;
  LBoundaryEnd := Pos(#13#10, ABody, LBoundaryStart);
  LBoundary := Copy(ABody, LBoundaryStart, LBoundaryEnd - LBoundaryStart);
  if (Length(LBoundary) <= 2) or (Copy(LBoundary, 1, 2) <> '--') then
  begin
    raise EConvertError.Create('Europe PMC SOAP response has no initial MIME boundary');
  end;
  LHeadersEnd := Pos(#13#10#13#10, ABody, LBoundaryEnd);
  if LHeadersEnd = 0 then
  begin
    raise EConvertError.Create('Europe PMC SOAP response has no MIME part headers');
  end;
  Inc(LHeadersEnd, 4);
  LPartEnd := Pos(#13#10 + LBoundary, ABody, LHeadersEnd);
  while (LPartEnd <> 0) and
    (Copy(ABody, LPartEnd + Length(LBoundary) + 2, 2) <> #13#10) and
    (Copy(ABody, LPartEnd + Length(LBoundary) + 2, 2) <> '--') do
  begin
    LPartEnd := Pos(#13#10 + LBoundary, ABody, LPartEnd + 2);
  end;
  if LPartEnd = 0 then
  begin
    raise EConvertError.Create('Europe PMC SOAP response has no closing MIME boundary');
  end;
  Result := Copy(ABody, LHeadersEnd, LPartEnd - LHeadersEnd);
end;

function ElementName(ANode: TDOMNode): DOMString;
begin
  Result := ANode.NodeName;
  Delete(Result, 1, Pos(':', Result));
end;

function Child(ANode: TDOMNode; const AName: DOMString): TDOMNode;
begin
  Result := nil;
  if ANode = nil then
  begin
    Exit;
  end;
  Result := ANode.FirstChild;
  while Assigned(Result) and (ElementName(Result) <> AName) do
  begin
    Result := Result.NextSibling;
  end;
end;

function ChildValue(ANode: TDOMNode; const AName: DOMString): UTF8String;
var
  LChild: TDOMNode;
begin
  Result := '';
  LChild := Child(ANode, AName);
  if Assigned(LChild) then
  begin
    Result := UTF8Encode(LChild.TextContent);
  end;
end;

procedure AddRecord(AResults: TJSONArray; ARecord: TDOMNode);
const
  CFields: array[0..8] of String = ('id', 'source', 'pmid', 'pmcid', 'doi', 'title',
    'firstPublicationDate', 'pubYear', 'abstractText');
var
  LRow: TJSONObject;
  LTypes: TJSONArray;
  LType: TDOMNode;
  LField: String;
  LJournal: UTF8String;
begin
  LRow := TJSONObject.Create;
  AResults.Add(LRow);
  for LField in CFields do
  begin
    LRow.Add(LField, ChildValue(ARecord, UnicodeString(LField)));
  end;
  LJournal := ChildValue(Child(Child(ARecord, 'journalInfo'), 'journal'), 'title');
  if LJournal = '' then
  begin
    LJournal := ChildValue(ARecord, 'journalTitle');
  end;
  LRow.Add('journalTitle', LJournal);
  LRow.Add('pubType', ChildValue(ARecord, 'pubType'));
  LTypes := TJSONArray.Create;
  LRow.Add('pubTypeList', TJSONObject.Create(['pubType', LTypes]));
  LType := Child(Child(ARecord, 'pubTypeList'), 'pubType');
  while Assigned(LType) do
  begin
    if ElementName(LType) = 'pubType' then
    begin
      LTypes.Add(UTF8Encode(LType.TextContent));
    end;
    LType := LType.NextSibling;
  end;
end;

function SoapSearchResult(const ABody: UTF8String; const AContentType: UnicodeString): UTF8String;
var
  LXml: UTF8String;
  LInput: TMemoryStream;
  LDocument: TXMLDocument;
  LReturn: TDOMNode;
  LRecord: TDOMNode;
  LHitCount: Int64;
  LRequest: TDOMNode;
  LResults: TJSONArray;
  LJson: TJSONObject;
begin
  LXml := FirstSoapPart(ABody, AContentType);
  if Pos('<!DOCTYPE', LXml) > 0 then
  begin
    raise EConvertError.Create('Unexpected document type in Europe PMC SOAP response');
  end;
  LDocument := nil;
  LInput := TMemoryStream.Create;
  try
    if LXml <> '' then
    begin
      LInput.WriteBuffer(LXml[1], Length(LXml));
      LInput.Position := 0;
    end;
    ReadXMLFile(LDocument, LInput);
    LReturn := Child(Child(Child(LDocument.DocumentElement, 'Body'),
      'searchPublicationsResponse'), 'return');
    if not TryStrToInt64(ChildValue(LReturn, 'hitCount'), LHitCount) or (LHitCount < 0) then
    begin
      raise EConvertError.Create('Unexpected Europe PMC SOAP search result');
    end;
    LRequest := Child(LReturn, 'request');
    LJson := TJSONObject.Create;
    try
      LJson.Add('hitCount', LHitCount);
      LJson.Add('nextCursorMark', ChildValue(LReturn, 'nextCursorMark'));
      LJson.Add('request', TJSONObject.Create(['queryString', ChildValue(LRequest, 'queryString')]));
      LResults := TJSONArray.Create;
      LJson.Add('resultList', TJSONObject.Create(['result', LResults]));
      LRecord := Child(Child(LReturn, 'resultList'), 'result');
      while Assigned(LRecord) do
      begin
        if ElementName(LRecord) = 'result' then
        begin
          AddRecord(LResults, LRecord);
        end;
        LRecord := LRecord.NextSibling;
      end;
      Result := LJson.AsJSON;
    finally
      LJson.Free;
    end;
  finally
    LDocument.Free;
    LInput.Free;
  end;
end;

end.
