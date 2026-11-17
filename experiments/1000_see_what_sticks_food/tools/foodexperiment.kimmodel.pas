{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.kimmodel;

{$mode delphi}
{$H+}

interface

type
  TObservation = record
    Subject: Integer;
    Predictor: Double;
    Outcome: Double;
  end;

  TModelFit = record
    Estimate: Double;
    StandardError: Double;
    VarianceRatio: Double;
    WaldP: Double;
  end;

function FitRandomIntercept(const AData: array of TObservation): TModelFit;
procedure AdjustFalseDiscoveryRate(const AP: array of Double; var AQ: array of Double);

implementation

uses
  Math, SysUtils, spe;

type
  TGroupSums = record
    Count: Integer;
    Predictor: Double;
    Outcome: Double;
  end;

function FitRandomIntercept(const AData: array of TObservation): TModelFit;
var
  LGroups: array of TGroupSums;
  LObservation: TObservation;
  LTotal: TGroupSums;
  LXX, LXY, LYY: Double;
  LLeft, LRight, LMid, LObjective, LAtZero: Double;

  function Profile(ARatio: Double; out AFit: TModelFit): Double;
  var
    LGroup: TGroupSums;
    LWeight, LDet, LOne, LX, LY, LWX2, LWXY, LWY2: Double;
    LSxx, LSxy, LSyy, LResidual, LSigma2: Double;
    LDegrees: Integer;
  begin
    LOne := LTotal.Count;
    LX := LTotal.Predictor;
    LY := LTotal.Outcome;
    LWX2 := LXX;
    LWXY := LXY;
    LWY2 := LYY;
    LDet := 0;
    // The covariance block is I + ratio * 11'. Its inverse subtracts a rank-one term.
    for LGroup in LGroups do
    begin
      LWeight := ARatio / (1 + LGroup.Count * ARatio);
      LDet := LDet + Ln(1 + LGroup.Count * ARatio);
      LOne := LOne - LWeight * Sqr(LGroup.Count);
      LX := LX - LWeight * LGroup.Count * LGroup.Predictor;
      LY := LY - LWeight * LGroup.Count * LGroup.Outcome;
      LWX2 := LWX2 - LWeight * Sqr(LGroup.Predictor);
      LWXY := LWXY - LWeight * LGroup.Predictor * LGroup.Outcome;
      LWY2 := LWY2 - LWeight * Sqr(LGroup.Outcome);
    end;
    LSxx := LWX2 - Sqr(LX) / LOne;
    LSxy := LWXY - LX * LY / LOne;
    LSyy := LWY2 - Sqr(LY) / LOne;
    if LSxx <= 0 then
    begin
      raise EMathError.Create('Predictor has no variance');
    end;
    LResidual := LSyy - Sqr(LSxy) / LSxx;
    LDegrees := LTotal.Count - 2;
    LSigma2 := LResidual / LDegrees;
    if LSigma2 <= 0 then
    begin
      raise EMathError.Create('Residual has no variance');
    end;
    AFit.Estimate := LSxy / LSxx;
    AFit.StandardError := Sqrt(LSigma2 / LSxx);
    AFit.VarianceRatio := ARatio;
    AFit.WaldP := 2 * NormalDist(-Abs(AFit.Estimate / AFit.StandardError));
    Result := LDegrees * Ln(LSigma2) + LDet + Ln(LOne * LSxx);
  end;

  function Objective(ARatio: Double): Double;
  var
    LFit: TModelFit;
  begin
    Result := Profile(ARatio, LFit);
  end;

begin
  if Length(AData) < 3 then
  begin
    raise EMathError.Create('Fewer than three complete observations');
  end;
  LTotal := Default(TGroupSums);
  LXX := 0;
  LXY := 0;
  LYY := 0;
  LGroups := nil;
  for LObservation in AData do
  begin
    if LObservation.Subject < 0 then
    begin
      raise EArgumentException.Create('Negative subject index');
    end;
    if LObservation.Subject >= Length(LGroups) then
    begin
      SetLength(LGroups, LObservation.Subject + 1);
    end;
    Inc(LGroups[LObservation.Subject].Count);
    LGroups[LObservation.Subject].Predictor :=
      LGroups[LObservation.Subject].Predictor + LObservation.Predictor;
    LGroups[LObservation.Subject].Outcome :=
      LGroups[LObservation.Subject].Outcome + LObservation.Outcome;
    Inc(LTotal.Count);
    LTotal.Predictor := LTotal.Predictor + LObservation.Predictor;
    LTotal.Outcome := LTotal.Outcome + LObservation.Outcome;
    LXX := LXX + Sqr(LObservation.Predictor);
    LXY := LXY + LObservation.Predictor * LObservation.Outcome;
    LYY := LYY + Sqr(LObservation.Outcome);
  end;
  LAtZero := Objective(0);
  LLeft := 0;
  LRight := 1;
  while Objective(LRight * 2) < Objective(LRight) do
  begin
    LRight := LRight * 2;
    if LRight > 1E8 then
    begin
      raise EMathError.Create('Could not bracket the variance ratio');
    end;
  end;
  LRight := LRight * 2;
  while LRight - LLeft > 1E-8 * Max(1, LRight) do
  begin
    LMid := (LRight - LLeft) / 3;
    if Objective(LLeft + LMid) < Objective(LRight - LMid) then
    begin
      LRight := LRight - LMid;
    end
    else
    begin
      LLeft := LLeft + LMid;
    end;
  end;
  LObjective := Profile((LLeft + LRight) / 2, Result);
  if LAtZero <= LObjective then
  begin
    Profile(0, Result);
  end;
end;

procedure AdjustFalseDiscoveryRate(const AP: array of Double; var AQ: array of Double);
var
  LOrder: array of Integer;
  LNext, LBest: Double;
  I, J: Integer;
begin
  if Length(AP) <> Length(AQ) then
  begin
    raise EArgumentException.Create('Mismatched p-value and q-value arrays');
  end;
  SetLength(LOrder, Length(AP));
  for I := 0 to High(AP) do
  begin
    J := I;
    while (J > 0) and (AP[LOrder[J - 1]] > AP[I]) do
    begin
      LOrder[J] := LOrder[J - 1];
      Dec(J);
    end;
    LOrder[J] := I;
  end;
  LBest := 1;
  for I := High(AP) downto 0 do
  begin
    LNext := AP[LOrder[I]] * Length(AP) / (I + 1);
    LBest := Min(LBest, LNext);
    AQ[LOrder[I]] := LBest;
  end;
end;

end.
