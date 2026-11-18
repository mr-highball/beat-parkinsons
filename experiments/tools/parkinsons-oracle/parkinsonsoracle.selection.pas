{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.selection;

{$mode delphi}{$H+}

interface

type
  TStringValues = array of String;
  TClaimIdentity = record
    Round: Integer;
    Id: String;
  end;
  TClaimIdentities = array of TClaimIdentity;
  TClaimIndices = array of Integer;

function HasSelection(const AValues: TStringValues; const AValue: String): Boolean;
function AddSelection(const AValues: TStringValues; const AValue: String): TStringValues;
function RemoveSelection(const AValues: TStringValues; const AValue: String): TStringValues;
function OrderedUniqueClaims(const AClaims: TClaimIdentities): TClaimIndices;

implementation

uses SysUtils;

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
  LIndex: Integer;
  LCount: Integer;

  function Compare(ALeft, ARight: Integer): Integer;
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

  procedure Sort(ALeft, ARight: Integer);
  var
    LLeft: Integer;
    LRight: Integer;
    LPivot: Integer;
    LSwap: Integer;
  begin
    LLeft := ALeft;
    LRight := ARight;
    LPivot := LOrder[(ALeft + ARight) div 2];
    repeat
      while Compare(LOrder[LLeft], LPivot) < 0 do
      begin
        Inc(LLeft);
      end;
      while Compare(LOrder[LRight], LPivot) > 0 do
      begin
        Dec(LRight);
      end;
      if LLeft <= LRight then
      begin
        LSwap := LOrder[LLeft];
        LOrder[LLeft] := LOrder[LRight];
        LOrder[LRight] := LSwap;
        Inc(LLeft);
        Dec(LRight);
      end;
    until LLeft > LRight;
    if ALeft < LRight then
    begin
      Sort(ALeft, LRight);
    end;
    if LLeft < ARight then
    begin
      Sort(LLeft, ARight);
    end;
  end;

begin
  Result := nil;
  SetLength(LOrder, Length(AClaims));
  for LIndex := 0 to High(AClaims) do
  begin
    LOrder[LIndex] := LIndex;
  end;
  if Length(LOrder) > 1 then
  begin
    Sort(0, High(LOrder));
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
end;

end.
