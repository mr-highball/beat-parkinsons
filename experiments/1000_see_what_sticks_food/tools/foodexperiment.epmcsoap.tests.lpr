{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentEpmcSoapTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses SysUtils, fpjson, jsonparser, foodexperiment.epmcsoap;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
end;

const
  CBreak = #13#10;
  CContentType = 'multipart/related; boundary="example"';
  COpening = '<s:Envelope xmlns:s="urn:example"><s:Body>' +
    '<e:searchPublicationsResponse xmlns:e="urn:ebi"><return>';
  CClosing = '</return></e:searchPublicationsResponse></s:Body></s:Envelope>';
  CQuery = '花生油 & <';
  CAbstract = 'First line' + CBreak + '--example-like' + CBreak + 'Last line';
var
  LXml: UTF8String;
  LMime: UTF8String;
  LRequest: UTF8String;
  LJson: TJSONData;
  LRow: TJSONData;
begin
  LRequest := SoapSearchRequest(CQuery, 'mark+1&', 1, 'P_PDATE_D desc');
  Check(Pos(UTF8String('<queryString>花生油 &amp; &lt;</queryString>'), LRequest) > 0, 'Query encoding');
  Check(Pos('<cursorMark>mark+1&amp;</cursorMark>', LRequest) > 0, 'Cursor encoding');

  LXml := COpening + '<hitCount>2</hitCount><nextCursorMark>mark+2</nextCursorMark>' +
    '<request><queryString>花生油 &amp; &lt;</queryString></request><resultList><result>' +
    '<id>123</id><source>MED</source><pmid>123</pmid><pmcid>PMC456</pmcid><doi>10.1/test</doi>' +
    '<title>Example</title><firstPublicationDate>2026-01-01</firstPublicationDate>' +
    '<journalInfo><journal><title>Test journal</title></journal></journalInfo>' +
    '<pubTypeList><pubType>Journal Article</pubType></pubTypeList>' +
    '<abstractText>' + CAbstract + '</abstractText></result></resultList>' + CClosing;
  LMime := CBreak + '--example' + CBreak + 'Content-Type: application/xop+xml' +
    CBreak + CBreak + LXml + CBreak + '--example--' + CBreak;
  LJson := GetJSON(SoapSearchResult(LMime, CContentType), True);
  try
    Check(LJson.FindPath('hitCount').AsInteger = 2, 'Hit count');
    Check(LJson.FindPath('nextCursorMark').AsString = 'mark+2', 'Next cursor');
    Check(LJson.FindPath('request.queryString').AsString = UTF8String(CQuery), 'Echoed query');
    LRow := LJson.FindPath('resultList.result[0]');
    Check(LRow.FindPath('pmcid').AsString = 'PMC456', 'Source identifiers');
    Check(LRow.FindPath('journalTitle').AsString = 'Test journal', 'Journal title');
    Check(LRow.FindPath('pubTypeList.pubType[0]').AsString = 'Journal Article', 'Source types');
    Check(Pos('Last line', LRow.FindPath('abstractText').AsString) > 0, 'MIME boundary');
  finally
    LJson.Free;
  end;

  LJson := GetJSON(SoapSearchResult(COpening + '<hitCount>0</hitCount>' + CClosing,
    'text/xml'), True);
  try
    Check(LJson.FindPath('hitCount').AsInteger = 0, 'Empty hit count');
    Check(LJson.FindPath('resultList.result').Count = 0, 'Empty results');
  finally
    LJson.Free;
  end;
  WriteLn('Europe PMC SOAP request and response tests passed.');
end.
