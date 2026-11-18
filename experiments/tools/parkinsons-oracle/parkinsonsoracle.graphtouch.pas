{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.graphtouch;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses nyx.canvas.geometry;

type
  { The position and baseline of a contact in canvas viewport pixels. }
  TGraphContact = record
    Id: NativeInt;
    Start: TNyxCanvasPoint;
    Current: TNyxCanvasPoint;
  end;

  { Interprets two canvas-local contacts. A second finger permanently cancels
    tap eligibility, and lifting one finger rebases the remaining drag. }
  TGraphTouch = record
  private
    FContacts: array[0..1] of TGraphContact;
    FCount: Integer;
    FCanTap: Boolean;
    FStart: TNyxCanvasCamera;
    function Find(AId: NativeInt): Integer;
    procedure Rebase(const ACamera: TNyxCanvasCamera);
  public
    function BeginContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
      const ACamera: TNyxCanvasCamera): Boolean;
    function MoveContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
      out ACamera: TNyxCanvasCamera): Boolean;
    function EndContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
      const ACamera: TNyxCanvasCamera; ACancelled: Boolean): Boolean;
    procedure Reset;
    property Count: Integer read FCount;
  end;

implementation

const
  CTapRadius = 8;

function ClosePoints(const AFirst, ASecond: TNyxCanvasPoint; ARadius: Double): Boolean;
begin
  Result := Sqr(AFirst.X - ASecond.X) + Sqr(AFirst.Y - ASecond.Y) <= Sqr(ARadius);
end;

function TGraphTouch.Find(AId: NativeInt): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to FCount - 1 do
  begin
    if FContacts[LIndex].Id = AId then
    begin
      Exit(LIndex);
    end;
  end;
  Result := -1;
end;

procedure TGraphTouch.Rebase(const ACamera: TNyxCanvasCamera);
var
  LIndex: Integer;
begin
  FStart := ACamera;
  for LIndex := 0 to FCount - 1 do
  begin
    FContacts[LIndex].Start := FContacts[LIndex].Current;
  end;
end;

function TGraphTouch.BeginContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
  const ACamera: TNyxCanvasCamera): Boolean;
begin
  Result := (FCount < Length(FContacts)) and (Find(AId) = -1);
  if not Result then
  begin
    Exit;
  end;
  FCanTap := FCount = 0;
  FContacts[FCount].Id := AId;
  FContacts[FCount].Current := APoint;
  Inc(FCount);
  Rebase(ACamera);
end;

function TGraphTouch.MoveContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
  out ACamera: TNyxCanvasCamera): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  LIndex := Find(AId);
  if LIndex < 0 then
  begin
    Exit;
  end;
  FContacts[LIndex].Current := APoint;
  if FCanTap and ClosePoints(FContacts[LIndex].Start, APoint, CTapRadius) then
  begin
    Exit;
  end;
  FCanTap := False;
  if FCount = 1 then
  begin
    ACamera := FStart.PanBy(APoint.X - FContacts[0].Start.X, APoint.Y - FContacts[0].Start.Y);
  end
  else
  begin
    if ClosePoints(FContacts[0].Start, FContacts[1].Start, 0) or
      ClosePoints(FContacts[0].Current, FContacts[1].Current, 0) then
    begin
      Exit;
    end;
    ACamera := FStart.Pinch(FContacts[0].Start, FContacts[1].Start,
      FContacts[0].Current, FContacts[1].Current);
  end;
  Result := True;
end;

function TGraphTouch.EndContact(AId: NativeInt; const APoint: TNyxCanvasPoint;
  const ACamera: TNyxCanvasCamera; ACancelled: Boolean): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  LIndex := Find(AId);
  if LIndex < 0 then
  begin
    Exit;
  end;
  if FCanTap and (ACancelled = False) then
  begin
    Result := ClosePoints(FContacts[LIndex].Start, APoint, CTapRadius);
  end;
  FCanTap := False;
  Dec(FCount);
  if LIndex < FCount then
  begin
    FContacts[LIndex] := FContacts[FCount];
  end;
  Rebase(ACamera);
end;

procedure TGraphTouch.Reset;
begin
  FCount := 0;
  FCanTap := False;
end;

end.
