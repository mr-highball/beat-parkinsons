{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program GraphTouchTests;

{$mode delphi}{$H+}{$codepage utf8}

uses SysUtils, nyx.canvas.geometry, parkinsonsoracle.graphtouch;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise Exception.Create(AMessage);
  end;
  Inc(GChecks);
end;

function Near(const AFirst, ASecond: TNyxCanvasPoint): Boolean;
begin
  Result := (Abs(AFirst.X - ASecond.X) < 0.001) and (Abs(AFirst.Y - ASecond.Y) < 0.001);
end;

procedure Run;
var
  LTouch: TGraphTouch;
  LInitial: TNyxCanvasCamera;
  LCamera: TNyxCanvasCamera;
  LNext: TNyxCanvasCamera;
  LWorldAnchor: TNyxCanvasPoint;
begin
  LTouch := Default(TGraphTouch);
  LInitial := NyxCanvasCamera(350, 352, NyxCanvasPoint(0, 0));
  Check(LTouch.BeginContact(1, NyxCanvasPoint(110, 150), LInitial), 'First finger admitted.');
  Check(not LTouch.BeginContact(1, NyxCanvasPoint(110, 150), LInitial), 'Duplicate rejected.');
  Check(not LTouch.MoveContact(1, NyxCanvasPoint(113, 153), LCamera), 'Tap jitter does not pan.');
  Check(LTouch.EndContact(1, NyxCanvasPoint(113, 153), LInitial, False), 'Stationary touch opens node.');
  Check(LTouch.Count = 0, 'Tap retires its contact.');
  Check(LTouch.BeginContact(2, NyxCanvasPoint(110, 150), LInitial), 'Drag admitted.');
  Check(LTouch.MoveContact(2, NyxCanvasPoint(140, 125), LCamera), 'Drag updates camera.');
  Check(LCamera.SameFrame(LInitial.PanBy(30, -25)), 'Drag follows viewport motion.');
  Check(not LTouch.EndContact(2, NyxCanvasPoint(140, 125), LCamera, False), 'Drag does not open node.');

  Check(LTouch.BeginContact(3, NyxCanvasPoint(110, 150), LInitial), 'Pinch first contact.');
  Check(LTouch.BeginContact(4, NyxCanvasPoint(210, 150), LInitial), 'Pinch second contact.');
  Check(not LTouch.BeginContact(5, NyxCanvasPoint(150, 180), LInitial), 'Third contact ignored.');
  Check(LTouch.MoveContact(4, NyxCanvasPoint(310, 150), LCamera), 'Pinch updates camera.');
  Check(Abs(LCamera.Zoom - 2) < 0.001, 'Finger distance sets zoom.');
  LWorldAnchor := LInitial.ViewportToWorld(NyxCanvasPoint(160, 150));
  Check(Near(LCamera.WorldToViewport(LWorldAnchor), NyxCanvasPoint(210, 150)),
    'The same world point stays under the moving midpoint.');
  Check(not LTouch.EndContact(4, NyxCanvasPoint(310, 150), LCamera, False),
    'Pinch release does not open node.');
  Check(LTouch.MoveContact(3, NyxCanvasPoint(135, 155), LNext), 'Remaining finger drags.');
  Check(LNext.SameFrame(LCamera.PanBy(25, 5)), 'Lifting one finger does not jump camera.');
  Check(not LTouch.EndContact(3, NyxCanvasPoint(135, 155), LNext, False),
    'Remaining finger cannot turn pinch into a tap.');
  Check(LTouch.BeginContact(6, NyxCanvasPoint(80, 80), LInitial), 'New touch after pinch.');
  Check(not LTouch.EndContact(6, NyxCanvasPoint(80, 80), LInitial, True), 'Cancel does not tap.');
  Check(LTouch.BeginContact(7, NyxCanvasPoint(80, 80), LInitial), 'New touch after cancel.');
  LTouch.Reset;
  Check(not LTouch.MoveContact(7, NyxCanvasPoint(120, 80), LCamera), 'Detached canvas ignores contact.');
  WriteLn(GChecks, ' graph touch checks passed.');
end;

begin
  Run;
end.
