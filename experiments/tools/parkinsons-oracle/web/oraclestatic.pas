{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclestatic;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses SysUtils, JS, Web;

type
  TOracleReply = reference to procedure(AData: TJSObject; const AError: String);
  TPostingIds = array of Integer;
  TPostingReply = reference to procedure(const AIds: TPostingIds; const AError: String);
  TBufferReply = reference to procedure(AData: TJSArrayBuffer; const AError: String);

  TStaticOracle = class
  private
    FModel: TJSObject;
    FManifest: TJSObject;
    FDocuments: TJSArray;
    FAssetPath: String;
    FWaiting: array of TOracleReply;
    procedure GetAsset(const APath: String; AJson: TOracleReply; ABuffer: TBufferReply = nil);
    procedure Loaded(AData: TJSObject; const AError: String);
    procedure WithModel(AReply: TOracleReply);
    function Canonical(const AKind, AValue: String): String;
    function Query(AArguments: TJSObject): TJSObject;
    procedure ReadPostings(const ATerm: String; AReply: TPostingReply);
    procedure Search(AArguments: TJSObject; AReply: TOracleReply);
  public
    constructor Create(const ARevision: String);
    procedure Call(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
    function ReferenceURL(const ALocal: String): String;
  end;

implementation

uses StrUtils, oraclevocab, parkinsonsoracle.trend;

function AsText(AValue: JSValue): String; external name 'String';
function EncodePathSegment(const AText: String): String; external name 'encodeURIComponent';

function SearchTerms(const AText: String): TJSArray;
begin
  // Browser Unicode normalization approximates unicode61 for query terms.
  asm
    return Array.from(new Set(AText.toLowerCase().normalize("NFD")
      .replace(/(\p{Script=Latin})\p{M}+/gu,"$1").normalize("NFC")
      .match(/[\p{L}\p{N}\p{Co}]+/gu) || []));
  end;
end;

function Count(AObject: TJSObject; const AKey: String; ADefault: Integer = 0): Integer;
begin
  Result := StrToIntDef(VocabularyText(AObject, AKey), ADefault);
end;

constructor TStaticOracle.Create(const ARevision: String);
begin
  inherited Create;
  FAssetPath := './model/' + EncodePathSegment(ARevision) + '/';
end;

procedure TStaticOracle.GetAsset(const APath: String; AJson: TOracleReply; ABuffer: TBufferReply);
var
  LRequest: TJSXMLHttpRequest;
begin
  LRequest := TJSXMLHttpRequest.new;
  LRequest.open('GET', FAssetPath + APath, True);
  LRequest.timeout := 25000;
  if Assigned(ABuffer) then
    TJSObject(LRequest)['responseType'] := 'arraybuffer';
  LRequest.onreadystatechange :=
    procedure
    var
      LError: String;
      LData: TJSObject;
    begin
      if LRequest.readyState <> TJSXMLHttpRequest.DONE then
        Exit;
      LError := '';
      if LRequest.Status <> 200 then
        LError := 'Unable to load the published model file ' + APath + '.';
      if Assigned(ABuffer) then
      begin
        ABuffer(TJSArrayBuffer(LRequest.response), LError);
        Exit;
      end;
      LData := nil;
      if LError = '' then
        try
          LData := TJSObject(TJSJSON.parse(LRequest.responseText));
        except
          LError := 'The published model contains invalid JSON.';
        end;
      AJson(LData, LError);
    end;
  LRequest.send;
end;

procedure TStaticOracle.Loaded(AData: TJSObject; const AError: String);
var
  LWaiting: array of TOracleReply;
  LReply: TOracleReply;
begin
  LWaiting := FWaiting;
  FWaiting := nil;
  if AError = '' then
    FModel := AData;
  for LReply in LWaiting do
    LReply(AData, AError);
end;

procedure TStaticOracle.WithModel(AReply: TOracleReply);
var
  LIndex: Integer;
begin
  if FModel <> nil then
  begin
    AReply(FModel, '');
    Exit;
  end;
  LIndex := Length(FWaiting);
  SetLength(FWaiting, LIndex + 1);
  FWaiting[LIndex] := AReply;
  if LIndex = 0 then
    GetAsset('claims.json',
      procedure(AData: TJSObject; const AError: String)
      begin
        if (AError = '') and (VocabularyText(AData, 'schema') <> 'parkinsons-oracle-model-1') then
          Loaded(nil, 'This published model has an unsupported format.')
        else
          Loaded(AData, AError);
      end);
end;

function TStaticOracle.Canonical(const AKind, AValue: String): String;
var
  LOptions: TJSArray;
  LAliases: TJSArray;
  LOption: TJSObject;
  LIndex: Integer;
  LAlias: Integer;
begin
  Result := LowerCase(Trim(AValue));
  if Result = '' then
    Exit;
  LOptions := VocabularyItems(TJSObject(FModel['filter_options']), AKind);
  for LIndex := 0 to LOptions.Length - 1 do
  begin
    LOption := TJSObject(LOptions[LIndex]);
    if VocabularyText(LOption, 'value') = Result then
      Exit;
    LAliases := VocabularyItems(LOption, 'aliases');
    for LAlias := 0 to LAliases.Length - 1 do
      if AsText(LAliases[LAlias]) = Result then
        Exit(VocabularyText(LOption, 'value'));
  end;
end;

function TStaticOracle.Query(AArguments: TJSObject): TJSObject;
var
  LClaims: TJSArray;
  LRows: TJSArray;
  LRow: TJSObject;
  LScope: String;
  LRowScope: String;
  LSymptom: String;
  LIngredient: String;
  LPreparation: String;
  LDirection: String;
  LVerdict: String;
  LTrend: String;
  LRound: Integer;
  LOffset: Integer;
  LLimit: Integer;
  LIndex: Integer;
  LCount: Integer;
  LEvidenceExcluded: Integer;
begin
  LScope := VocabularyText(AArguments, 'scope');
  if LScope = '' then
    LScope := 'directional';
  LSymptom := Canonical('symptoms', VocabularyText(AArguments, 'symptom'));
  LIngredient := Canonical('ingredients', VocabularyText(AArguments, 'ingredient'));
  LPreparation := LowerCase(VocabularyText(AArguments, 'preparation'));
  LDirection := VocabularyText(AArguments, 'direction');
  LVerdict := VocabularyText(AArguments, 'verdict');
  LTrend := VocabularyText(AArguments, 'trend');
  LRound := Count(AArguments, 'round');
  LOffset := Count(AArguments, 'offset');
  LLimit := Count(AArguments, 'limit', 12);
  LClaims := VocabularyItems(FModel, 'claims');
  LRows := TJSArray.new;
  LCount := 0;
  LEvidenceExcluded := 0;
  for LIndex := 0 to LClaims.Length - 1 do
  begin
    LRow := TJSObject(LClaims[LIndex]);
    if ((LSymptom <> '') and (VocabularyText(LRow, 'symptom') <> LSymptom)) or
      ((LIngredient <> '') and (VocabularyText(LRow, 'ingredient') <> LIngredient)) or
      ((LPreparation <> '') and (VocabularyText(LRow, 'preparation') <> LPreparation)) or
      ((LDirection <> '') and (VocabularyText(LRow, 'hypothesis_direction') <> LDirection)) or
      ((LRound <> 0) and (Count(LRow, 'round') <> LRound)) then
      Continue;
    LRowScope := VocabularyText(LRow, 'evidence_scope');
    if ((LScope = 'directional') and (LRowScope <> 'directional')) or
      ((LScope = 'assessed') and (LRowScope = 'frozen')) or
      ((LVerdict <> '') and (VocabularyText(LRow, 'verdict') <> LVerdict)) or
      ((LTrend <> '') and (ClaimTrend(VocabularyText(LRow, 'verdict'),
        VocabularyText(LRow, 'hypothesis_direction')) <> LTrend)) then
    begin
      Inc(LEvidenceExcluded);
      Continue;
    end;
    if (LCount >= LOffset) and (LRows.Length < LLimit) then
      LRows.push(LRow);
    Inc(LCount);
  end;
  Result := TJSObject.new;
  Result['symptom'] := LSymptom;
  Result['ingredient'] := LIngredient;
  Result['total_matches'] := LCount;
  Result['offset'] := LOffset;
  Result['options'] := LRows;
  if LTrend <> '' then
    Result['trend_filter'] := LTrend;
  if LOffset + LLimit < LCount then
    Result['next_offset'] := LOffset + LLimit;
  if LEvidenceExcluded > 0 then
    Result['no_match_reason'] := 'evidence_filters';
end;

function NextNumber(ABytes: TJSUint8Array; var AOffset: Integer): Integer;
var
  LByte: Integer;
  LShift: Integer;
begin
  LShift := 0;
  Result := 0;
  repeat
    if (AOffset >= ABytes.Length) or (LShift > 28) then
      raise EConvertError.Create('Invalid published posting');
    LByte := ABytes[AOffset];
    Inc(AOffset);
    Result := Result or ((LByte and 127) shl LShift);
    Inc(LShift, 7);
  until (LByte and 128) = 0;
end;

function DecodePostings(ABuffer: TJSArrayBuffer; ATerm: TJSUint8Array): TPostingIds;
var
  LBytes: TJSUint8Array;
  LOffset: Integer;
  LTermLength: Integer;
  LDocCount: Integer;
  LId: Integer;
  LIndex: Integer;
  LMatches: Boolean;
begin
  Result := nil;
  LBytes := TJSUint8Array.new(ABuffer);
  if (LBytes.Length < 4) or (LBytes[0] <> Ord('P')) or (LBytes[1] <> Ord('O')) or
    (LBytes[2] <> Ord('C')) or (LBytes[3] <> Ord('1')) then
    raise EConvertError.Create('Unsupported published posting');
  LOffset := 4;
  while LOffset < LBytes.Length do
  begin
    LTermLength := NextNumber(LBytes, LOffset);
    if (LTermLength < 1) or (LTermLength > LBytes.Length - LOffset) then
      raise EConvertError.Create('Invalid published term length');
    LMatches := LTermLength = ATerm.Length;
    if LMatches then
      for LIndex := 0 to LTermLength - 1 do
        if LBytes[LOffset + LIndex] <> ATerm[LIndex] then
        begin
          LMatches := False;
          Break;
        end;
    Inc(LOffset, LTermLength);
    LDocCount := NextNumber(LBytes, LOffset);
    if (LDocCount < 1) or (LDocCount > LBytes.Length - LOffset) then
      raise EConvertError.Create('Invalid published posting count');
    if LMatches then
    begin
      LId := 0;
      SetLength(Result, LDocCount);
      for LIndex := 0 to LDocCount - 1 do
      begin
        Inc(LId, NextNumber(LBytes, LOffset));
        Result[LIndex] := LId;
      end;
      Exit;
    end;
    for LIndex := 1 to LDocCount do
      NextNumber(LBytes, LOffset);
  end;
end;

procedure TStaticOracle.ReadPostings(const ATerm: String; AReply: TPostingReply);
var
  LBytes: TJSUint8Array;
  LShard: String;
  LKnown: TJSArray;
  LHash: Integer;
  LIndex: Integer;
begin
  LBytes := TJSTextEncoder.New.encode(ATerm);
  LHash := 0;
  for LIndex := 0 to LBytes.Length - 1 do
    LHash := (LHash * 31 + LBytes[LIndex]) and 4095;
  LShard := LowerCase(IntToHex(LHash, 3));
  LKnown := VocabularyItems(FManifest, 'shards');
  if LKnown.indexOf(LShard) < 0 then
  begin
    AReply(nil, '');
    Exit;
  end;
  GetAsset('search/postings/' + LShard + '.bin', nil,
    procedure(AData: TJSArrayBuffer; const AError: String)
    var
      LIds: TPostingIds;
    begin
      if AError <> '' then
        AReply(nil, AError)
      else
      begin
        try
          LIds := DecodePostings(AData, LBytes);
        except
          AReply(nil, 'The published catalog segment could not be read.');
          Exit;
        end;
        AReply(LIds, '');
      end;
    end);
end;

function Intersect(const ALeft, ARight: TPostingIds): TPostingIds;
var
  LLeft: Integer;
  LRight: Integer;
  LCount: Integer;
begin
  SetLength(Result, Length(ALeft));
  LLeft := 0;
  LRight := 0;
  LCount := 0;
  while (LLeft < Length(ALeft)) and (LRight < Length(ARight)) do
    if ALeft[LLeft] < ARight[LRight] then
      Inc(LLeft)
    else if ALeft[LLeft] > ARight[LRight] then
      Inc(LRight)
    else
    begin
      Result[LCount] := ALeft[LLeft];
      Inc(LCount);
      Inc(LLeft);
      Inc(LRight);
    end;
  SetLength(Result, LCount);
end;

procedure TStaticOracle.Search(AArguments: TJSObject; AReply: TOracleReply);
var
  LTerms: TJSArray;
  LTerm: Integer;
  LCandidates: TPostingIds;
  LPeriod: String;
  LOffset: Integer;
  LLimit: Integer;

  procedure Finish;
  var
    LId: Integer;
    LCount: Integer;
    LRows: TJSArray;
    LDoc: TJSArray;
    LHit: TJSObject;
    LResult: TJSObject;
  begin
    LRows := TJSArray.new;
    LCount := 0;
    for LId in LCandidates do
    begin
      if (LId < 1) or (LId > FDocuments.Length) then
        Continue;
      LDoc := TJSArray(FDocuments[LId - 1]);
      if (LPeriod <> '') and (AsText(LDoc[1]) <> LPeriod) then
        Continue;
      if (LCount >= LOffset) and (LRows.Length < LLimit) then
      begin
        LHit := TJSObject.new;
        LHit['path'] := LDoc[0];
        LHit['period'] := LDoc[1];
        LRows.push(LHit);
      end;
      Inc(LCount);
    end;
    LResult := TJSObject.new;
    LResult['total'] := LCount;
    LResult['offset'] := LOffset;
    LResult['matches'] := LRows;
    if LOffset + LLimit < LCount then
      LResult['next_offset'] := LOffset + LLimit;
    AReply(LResult, '');
  end;

  procedure ReadNext;
  begin
    if (LTerm >= LTerms.Length) or ((LTerm > 0) and (Length(LCandidates) = 0)) then
    begin
      Finish;
      Exit;
    end;
    ReadPostings(AsText(LTerms[LTerm]),
      procedure(const AIds: TPostingIds; const AError: String)
      begin
        if AError <> '' then
        begin
          AReply(nil, AError);
          Exit;
        end;
        if LTerm = 0 then
          LCandidates := AIds
        else
          LCandidates := Intersect(LCandidates, AIds);
        Inc(LTerm);
        ReadNext;
      end);
  end;

  procedure WithDocuments;
  begin
    if FDocuments <> nil then
      ReadNext
    else
      GetAsset('search/documents.json',
        procedure(AData: TJSObject; const AError: String)
        begin
          if AError <> '' then
            AReply(nil, AError)
          else if not TJSArray.isArray(AData) or
            (TJSArray(AData).Length <> Count(FManifest, 'document_count', -1)) then
            AReply(nil, 'The published document inventory has an unsupported format.')
          else
          begin
            FDocuments := TJSArray(AData);
            ReadNext;
          end;
        end);
  end;

begin
  LTerms := SearchTerms(VocabularyText(AArguments, 'terms'));
  if LTerms.Length = 0 then
  begin
    AReply(nil, 'Enter at least one search word.');
    Exit;
  end;
  LTerm := 0;
  LPeriod := VocabularyText(AArguments, 'period');
  LOffset := Count(AArguments, 'offset');
  LLimit := Count(AArguments, 'limit', 12);
  if FManifest <> nil then
    WithDocuments
  else
    GetAsset('search/manifest.json',
      procedure(AData: TJSObject; const AError: String)
      begin
        if AError <> '' then
          AReply(nil, AError)
        else if (VocabularyText(AData, 'format') <> 'oracle-fts-postings-v1') or
          (Count(AData, 'version') <> 1) then
          AReply(nil, 'The published catalog has an unsupported format.')
        else
        begin
          FManifest := AData;
          WithDocuments;
        end;
      end);
end;

procedure TStaticOracle.Call(const ATool: String; AArguments: TJSObject; AReply: TOracleReply);
begin
  WithModel(
    procedure(AData: TJSObject; const AError: String)
    var
      LResult: TJSObject;
      LClaims: TJSArray;
      LRow: TJSObject;
      LIndex: Integer;
    begin
      if AError <> '' then
      begin
        AReply(nil, AError);
        Exit;
      end;
      case IndexStr(ATool, ['oracle_status', 'oracle_filter_options', 'oracle_query',
        'oracle_claim', 'oracle_search_catalog']) of
        0:
          begin
            LResult := TJSObject.new;
            LResult['claims'] := AData['status'];
            LResult['catalog'] := AData['catalog'];
            AReply(LResult, '');
          end;
        1: AReply(TJSObject(AData['filter_options']), '');
        2: AReply(Query(AArguments), '');
        3:
          begin
            LClaims := VocabularyItems(AData, 'claims');
            for LIndex := 0 to LClaims.Length - 1 do
            begin
              LRow := TJSObject(LClaims[LIndex]);
              if (Count(LRow, 'round') = Count(AArguments, 'round')) and
                (VocabularyText(LRow, 'claim_id') = VocabularyText(AArguments, 'id')) then
              begin
                LRow['found'] := True;
                AReply(LRow, '');
                Exit;
              end;
            end;
            LResult := TJSObject.new;
            LResult['found'] := False;
            AReply(LResult, '');
          end;
        4: Search(AArguments, AReply);
      else
        AReply(nil, 'Unsupported lookup in the published model.');
      end;
    end);
end;

function TStaticOracle.ReferenceURL(const ALocal: String): String;
var
  LPath: String;
  LAnchor: String;
  LSeparator: Integer;
  LPart: String;
  LRepo: String;
begin
  Result := '';
  LRepo := VocabularyText(FModel, 'repository');
  if (LRepo = '') or (Copy(ALocal, 1, 9) <> 'research/') then
    Exit;
  LSeparator := Pos('#', ALocal);
  LPath := ALocal;
  LAnchor := '';
  if LSeparator > 0 then
  begin
    LPath := Copy(ALocal, 1, LSeparator - 1);
    LAnchor := '#' + Copy(ALocal, LSeparator + 1, MaxInt);
  end;
  Result := LRepo + '/blob/' + VocabularyText(FModel, 'revision');
  for LPart in SplitString(LPath, '/') do
    Result := Result + '/' + EncodePathSegment(LPart);
  Result := Result + LAnchor;
end;

end.
