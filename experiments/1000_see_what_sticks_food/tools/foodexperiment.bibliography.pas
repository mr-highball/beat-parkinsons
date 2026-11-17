{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.bibliography;

{$mode delphi}
{$H+}

interface

uses fpjson;

const
  BibliographyHeader = 'query_id'#9'category'#9'ingredient'#9'rank'#9'source_key'#9'source'#9 +
    'source_id'#9'pmid'#9'doi'#9'pmcid'#9'title'#9'journal'#9'publication_date'#9 +
    'publication_types'#9'abstract';

function JsonText(AObject: TJSONData; const APath: String): UTF8String;
function BibliographyRow(const AQueryId, ACategory, AIngredient: UTF8String;
  ARecord: TJSONData; const ASource, ASourceId: UTF8String; ARank: Int64): UTF8String;

implementation

uses SysUtils, foodexperiment.externaldata;

function JsonText(AObject: TJSONData; const APath: String): UTF8String;
var
  LData: TJSONData;
begin
  Result := '';
  LData := AObject.FindPath(APath);
  if Assigned(LData) and (LData.JSONType in [jtString, jtNumber]) then
  begin
    Result := CleanField(LData.AsString);
  end;
end;

function PublicationTypes(ARecord: TJSONData): UTF8String;
var
  LTypes: TJSONData;
  I: Integer;
begin
  Result := JsonText(ARecord, 'pubType');
  if Result <> '' then
  begin
    Exit;
  end;
  LTypes := ARecord.FindPath('pubTypeList.pubType');
  if Assigned(LTypes) and (LTypes.JSONType = jtArray) then
  begin
    for I := 0 to LTypes.Count - 1 do
    begin
      if I > 0 then
      begin
        Result := Result + '|';
      end;
      Result := Result + CleanField(LTypes.Items[I].AsString);
    end;
  end;
end;

function BibliographyRow(const AQueryId, ACategory, AIngredient: UTF8String;
  ARecord: TJSONData; const ASource, ASourceId: UTF8String; ARank: Int64): UTF8String;
const
  Tab = #9;
var
  LPmid: UTF8String;
  LDoi: UTF8String;
  LPmcid: UTF8String;
  LKey: UTF8String;
  LJournal: UTF8String;
  LDate: UTF8String;
begin
  LPmid := JsonText(ARecord, 'pmid');
  LDoi := LowerCase(JsonText(ARecord, 'doi'));
  LPmcid := JsonText(ARecord, 'pmcid');
  LKey := ASource + ':' + ASourceId;
  if LPmid <> '' then
  begin
    LKey := 'PMID:' + LPmid;
  end
  else if LDoi <> '' then
  begin
    LKey := 'DOI:' + LDoi;
  end
  else if LPmcid <> '' then
  begin
    LKey := 'PMCID:' + LPmcid;
  end;
  LJournal := JsonText(ARecord, 'journalInfo.journal.title');
  if LJournal = '' then
  begin
    LJournal := JsonText(ARecord, 'journalTitle');
  end;
  LDate := JsonText(ARecord, 'firstPublicationDate');
  if LDate = '' then
  begin
    LDate := JsonText(ARecord, 'pubYear');
  end;
  Result := AQueryId + Tab + ACategory + Tab + AIngredient + Tab +
    IntToStr(ARank) + Tab + LKey + Tab + ASource + Tab + ASourceId + Tab + LPmid +
    Tab + LDoi + Tab + LPmcid + Tab + JsonText(ARecord, 'title') + Tab + LJournal +
    Tab + LDate + Tab + PublicationTypes(ARecord) + Tab + JsonText(ARecord, 'abstractText');
end;

end.
