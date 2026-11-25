{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.selection;

{$mode delphi}{$H+}

interface

type
  TStringValues = array of String;
  TClaimIdentity = record
    Round: Integer;
    Id: String;
    Verdict: String;
    Direction: String;
    ResearchStatus: String;
    Confidence: Double;
  end;
  TClaimIdentities = array of TClaimIdentity;
  TClaimIndices = array of Integer;

function HasSelection(const AValues: TStringValues; const AValue: String): Boolean;
function AddSelection(const AValues: TStringValues; const AValue: String): TStringValues;
function RemoveSelection(const AValues: TStringValues; const AValue: String): TStringValues;
function OrderedUniqueClaims(const AClaims: TClaimIdentities): TClaimIndices;

implementation

uses SysUtils, parkinsonsoracle.trend;

function HasSelection(const AValues: TStringValues; const AValue: String): Boolean;
var
  LValue: String;
begin
  for LValue in AValues do
  begin
    if LValue = AValue then
    begin
      Exit(True);
    end;
  end;
  Result := False;
end;

function AddSelection(const AValues: TStringValues; const AValue: String): TStringValues;
var
  LIndex: Integer;
begin
  SetLength(Result, Length(AValues));
  for LIndex := 0 to High(AValues) do
  begin
    Result[LIndex] := AValues[LIndex];
  end;
  if (Trim(AValue) <> '') and not HasSelection(AValues, AValue) then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := AValue;
  end;
end;

function RemoveSelection(const AValues: TStringValues; const AValue: String): TStringValues;
var
  LValue: String;
  LCount: Integer;
begin
  SetLength(Result, Length(AValues));
  LCount := 0;
  for LValue in AValues do
  begin
    if LValue <> AValue then
    begin
      Result[LCount] := LValue;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function OrderedUniqueClaims(const AClaims: TClaimIdentities): TClaimIndices;
var
  LOrder: TClaimIndices;
  LRanks: array of Integer;
  LIndex: Integer;
  LCount: Integer;

  function CompareIdentity(ALeft, ARight: Integer): Integer;
  begin
    if AClaims[ALeft].Round < AClaims[ARight].Round then
    begin
      Exit(-1);
    end;
    if AClaims[ALeft].Round > AClaims[ARight].Round then
    begin
      Exit(1);
    end;
    Result := CompareStr(AClaims[ALeft].Id, AClaims[ARight].Id);
    if Result = 0 then
    begin
      Result := ALeft - ARight;
    end;
  end;

  function CompareUsefulness(ALeft, ARight: Integer): Integer;
  begin
    Result := CompareClaimUsefulness(
      LRanks[ALeft], AClaims[ALeft].Confidence, AClaims[ALeft].Round, AClaims[ALeft].Id,
      LRanks[ARight], AClaims[ARight].Confidence, AClaims[ARight].Round, AClaims[ARight].Id);
    if Result = 0 then
    begin
      Result := ALeft - ARight;
    end;
  end;

  procedure SortByIdentity(var AItems: TClaimIndices; ALeft, ARight: Integer);
  var
    LLeft: Integer;
    LRight: Integer;
    LPivot: Integer;
    LSwap: Integer;
  begin
    LLeft := ALeft;
    LRight := ARight;
    LPivot := AItems[(ALeft + ARight) div 2];
    repeat
      while CompareIdentity(AItems[LLeft], LPivot) < 0 do
      begin
        Inc(LLeft);
      end;
      while CompareIdentity(AItems[LRight], LPivot) > 0 do
      begin
        Dec(LRight);
      end;
      if LLeft <= LRight then
      begin
        LSwap := AItems[LLeft];
        AItems[LLeft] := AItems[LRight];
        AItems[LRight] := LSwap;
        Inc(LLeft);
        Dec(LRight);
      end;
    until LLeft > LRight;
    if ALeft < LRight then
    begin
      SortByIdentity(AItems, ALeft, LRight);
    end;
    if LLeft < ARight then
    begin
      SortByIdentity(AItems, LLeft, ARight);
    end;
  end;

  procedure SortByUsefulness(var AItems: TClaimIndices; ALeft, ARight: Integer);
  var
    LLeft: Integer;
    LRight: Integer;
    LPivot: Integer;
    LSwap: Integer;
  begin
    LLeft := ALeft;
    LRight := ARight;
    LPivot := AItems[(ALeft + ARight) div 2];
    repeat
      while CompareUsefulness(AItems[LLeft], LPivot) < 0 do
      begin
        Inc(LLeft);
      end;
      while CompareUsefulness(AItems[LRight], LPivot) > 0 do
      begin
        Dec(LRight);
      end;
      if LLeft <= LRight then
      begin
        LSwap := AItems[LLeft];
        AItems[LLeft] := AItems[LRight];
        AItems[LRight] := LSwap;
        Inc(LLeft);
        Dec(LRight);
      end;
    until LLeft > LRight;
    if ALeft < LRight then
    begin
      SortByUsefulness(AItems, ALeft, LRight);
    end;
    if LLeft < ARight then
    begin
      SortByUsefulness(AItems, LLeft, ARight);
    end;
  end;

begin
  Result := nil;
  SetLength(LOrder, Length(AClaims));
  SetLength(LRanks, Length(AClaims));
  for LIndex := 0 to High(AClaims) do
  begin
    LOrder[LIndex] := LIndex;
    LRanks[LIndex] := ClaimUsefulnessRank(AClaims[LIndex].Verdict,
      AClaims[LIndex].Direction, AClaims[LIndex].ResearchStatus);
  end;
  if Length(LOrder) > 1 then
  begin
    SortByIdentity(LOrder, 0, High(LOrder));
  end;
  SetLength(Result, Length(LOrder));
  LCount := 0;
  for LIndex in LOrder do
  begin
    if (LCount = 0) or
      (AClaims[Result[LCount - 1]].Round <> AClaims[LIndex].Round) or
      (AClaims[Result[LCount - 1]].Id <> AClaims[LIndex].Id) then
    begin
      Result[LCount] := LIndex;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
  if Length(Result) > 1 then
  begin
    SortByUsefulness(Result, 0, High(Result));
  end;
end;

end.
