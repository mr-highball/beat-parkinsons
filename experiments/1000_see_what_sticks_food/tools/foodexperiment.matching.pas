{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.matching;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils;

type
  TMatchFlags = array of Boolean;

  TMatcher = class
  private const
    CFirstRussianSymbol = 37;
    CLastRussianSymbol = CFirstRussianSymbol + 31;
  private type
    TNode = record
      Next: array[0..CLastRussianSymbol] of Integer;
      Failure: Integer;
      OutputLink: Integer;
      Outputs: array of Integer;
    end;
  private
    FNodes: array of TNode;
    FCount: Integer;
    FReady: Boolean;
    FRussian: Boolean;
    function NewNode: Integer;
  public
    constructor Create(ARussian: Boolean = False);
    procedure Add(const ATerm: RawByteString; AIndex: Integer);
    procedure Prepare;
    procedure Match(const AText: RawByteString; var AFlags: TMatchFlags);
  end;

function ReadBytes(const APath: String): RawByteString;
function CleanCell(const AValue: String): String;
function JoinMatches(const ALabels: TStrings; const AFlags: TMatchFlags;
  AStart: Integer): String;
procedure LoadTermGroups(const APath: String; AMatcher: TMatcher; ANames: TStrings);

implementation

function ReadBytes(const APath: String): RawByteString;
var
  LFile: TFileStream;
begin
  LFile := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    if LFile.Size > High(Integer) then
    begin
      raise ERangeError.Create('File is too large for this native target');
    end;
    SetLength(Result, LFile.Size);
    if Length(Result) > 0 then
    begin
      LFile.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LFile.Free;
  end;
end;

function CleanCell(const AValue: String): String;
begin
  Result := StringReplace(AValue, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

function JoinMatches(const ALabels: TStrings; const AFlags: TMatchFlags;
  AStart: Integer): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to ALabels.Count - 1 do
  begin
    if not AFlags[AStart + LIndex] then
    begin
      Continue;
    end;
    if Result <> '' then
    begin
      Result := Result + '|';
    end;
    Result := Result + ALabels[LIndex];
  end;
end;

procedure LoadTermGroups(const APath: String; AMatcher: TMatcher; ANames: TStrings);
var
  LRows: TStringList;
  LFields: TStringArray;
  LTerm: String;
  LRow: Integer;
begin
  LRows := TStringList.Create;
  try
    LRows.Text := ReadBytes(APath);
    if (LRows.Count < 2) or (LRows[0] <> 'topic'#9'terms') then
    begin
      raise EConvertError.Create('Missing topic vocabulary or unexpected header');
    end;
    for LRow := 1 to LRows.Count - 1 do
    begin
      LFields := LRows[LRow].Split([#9]);
      if (Length(LFields) <> 2) or (LFields[0] = '') or (LFields[1] = '') or
        (ANames.IndexOf(LFields[0]) >= 0) then
      begin
        raise EConvertError.CreateFmt('Invalid topic vocabulary row %d', [LRow + 1]);
      end;
      for LTerm in LFields[1].Split(['|']) do
      begin
        if Trim(LTerm) = '' then
        begin
          raise EConvertError.CreateFmt('Empty topic term on row %d', [LRow + 1]);
        end;
        AMatcher.Add(Trim(LTerm), ANames.Count);
      end;
      ANames.Add(LFields[0]);
    end;
    AMatcher.Prepare;
  finally
    LRows.Free;
  end;
end;

function NextSymbol(const AText: RawByteString; var APosition, APending: Integer;
  ARussian: Boolean): Integer; inline;
var
  LByte: Byte;
  LNext: Byte;
begin
  if APending <> 0 then
  begin
    Result := APending;
    APending := 0;
    Exit;
  end;
  LByte := Byte(AText[APosition]);
  Inc(APosition);
  case LByte of
    65..90:
      Result := LByte - 64;
    97..122:
      Result := LByte - 96;
    48..57:
      Result := LByte - 21;
  else
    Result := 0;
    { Fold common Latin accents and French ligatures. }
    if (LByte = $C5) and (APosition <= Length(AText)) and
      (Byte(AText[APosition]) in [$92, $93]) then
    begin
      Inc(APosition);
      Result := 15;
      APending := 5;
    end
    else if (LByte = $C3) and (APosition <= Length(AText)) then
    begin
      LNext := Byte(AText[APosition]);
      Inc(APosition);
      case LNext of
        $80..$85, $A0..$A5:
          Result := 1;
        $87, $A7:
          Result := 3;
        $88..$8B, $A8..$AB:
          Result := 5;
        $8C..$8F, $AC..$AF:
          Result := 9;
        $91, $B1:
          Result := 14;
        $92..$96, $98, $B2..$B6, $B8:
          Result := 15;
        $99..$9C, $B9..$BC:
          Result := 21;
        $9D, $BD, $BF:
          Result := 25;
      end;
    end
    else if ARussian and (LByte in [$D0, $D1]) and (APosition <= Length(AText)) then
    begin
      LNext := Byte(AText[APosition]);
      if LNext in [$80..$BF] then
      begin
        Inc(APosition);
      end;
      { Fold the Russian alphabet to lowercase and treat ё and е as equivalent. }
      if LByte = $D0 then
      begin
        case LNext of
          $81: Result := TMatcher.CFirstRussianSymbol + 5;
          $90..$AF: Result := TMatcher.CFirstRussianSymbol + LNext - $90;
          $B0..$BF: Result := TMatcher.CFirstRussianSymbol + LNext - $B0;
        end;
      end
      else
      begin
        case LNext of
          $80..$8F: Result := TMatcher.CFirstRussianSymbol + 16 + LNext - $80;
          $91: Result := TMatcher.CFirstRussianSymbol + 5;
        end;
      end;
    end;
  end;
end;

constructor TMatcher.Create(ARussian: Boolean);
begin
  inherited Create;
  FRussian := ARussian;
  NewNode;
end;

function TMatcher.NewNode: Integer;
begin
  if FCount = Length(FNodes) then
  begin
    SetLength(FNodes, FCount * 2 + 32);
  end;
  Result := FCount;
  Inc(FCount);
end;

procedure TMatcher.Add(const ATerm: RawByteString; AIndex: Integer);
var
  LPosition: Integer;
  LPending: Integer;
  LState: Integer;
  LSymbol: Integer;
  LPrevious: Integer;
  LNode: Integer;
  LCount: Integer;

  procedure AppendSymbol(ASymbol: Integer);
  begin
    LNode := FNodes[LState].Next[ASymbol];
    if LNode = 0 then
    begin
      LNode := NewNode;
      FNodes[LState].Next[ASymbol] := LNode;
    end;
    LState := LNode;
  end;

begin
  if FReady then
  begin
    raise EInvalidOp.Create('Cannot add terms after preparing the matcher');
  end;
  if ATerm = '' then
  begin
    Exit;
  end;
  LPosition := 1;
  LPending := 0;
  LState := 0;
  LPrevious := 0;
  AppendSymbol(0);
  while (LPosition <= Length(ATerm)) or (LPending <> 0) do
  begin
    LSymbol := NextSymbol(ATerm, LPosition, LPending, FRussian);
    if (LSymbol <> 0) or (LPrevious <> 0) then
    begin
      AppendSymbol(LSymbol);
    end;
    LPrevious := LSymbol;
  end;
  if LPrevious <> 0 then
  begin
    AppendSymbol(0);
  end;
  if LState = FNodes[0].Next[0] then
  begin
    Exit;
  end;
  LCount := Length(FNodes[LState].Outputs);
  SetLength(FNodes[LState].Outputs, LCount + 1);
  FNodes[LState].Outputs[LCount] := AIndex;
end;

procedure TMatcher.Prepare;
var
  LQueue: array of Integer;
  LRead: Integer;
  LWrite: Integer;
  LParent: Integer;
  LChild: Integer;
  LFailure: Integer;
  LSymbol: Integer;
  LLastSymbol: Integer;
begin
  if FReady then
  begin
    Exit;
  end;
  SetLength(LQueue, FCount);
  LRead := 0;
  LWrite := 0;
  LLastSymbol := CFirstRussianSymbol - 1;
  if FRussian then
  begin
    LLastSymbol := CLastRussianSymbol;
  end;
  for LSymbol := 0 to LLastSymbol do
  begin
    LChild := FNodes[0].Next[LSymbol];
    if LChild <> 0 then
    begin
      LQueue[LWrite] := LChild;
      Inc(LWrite);
    end;
  end;
  while LRead < LWrite do
  begin
    LParent := LQueue[LRead];
    Inc(LRead);
    for LSymbol := 0 to LLastSymbol do
    begin
      LChild := FNodes[LParent].Next[LSymbol];
      LFailure := FNodes[FNodes[LParent].Failure].Next[LSymbol];
      if LChild = 0 then
      begin
        FNodes[LParent].Next[LSymbol] := LFailure;
        Continue;
      end;
      FNodes[LChild].Failure := LFailure;
      if Length(FNodes[LFailure].Outputs) > 0 then
      begin
        FNodes[LChild].OutputLink := LFailure;
      end
      else
      begin
        FNodes[LChild].OutputLink := FNodes[LFailure].OutputLink;
      end;
      LQueue[LWrite] := LChild;
      Inc(LWrite);
    end;
  end;
  FReady := True;
end;

procedure TMatcher.Match(const AText: RawByteString; var AFlags: TMatchFlags);
var
  LPosition: Integer;
  LPending: Integer;
  LState: Integer;
  LSymbol: Integer;
  LPrevious: Integer;
  LOutput: Integer;
  LIndex: Integer;

  procedure MarkOutput; inline;
  begin
    LOutput := LState;
    while LOutput <> 0 do
    begin
      for LIndex in FNodes[LOutput].Outputs do
      begin
        AFlags[LIndex] := True;
      end;
      LOutput := FNodes[LOutput].OutputLink;
    end;
  end;

begin
  if not FReady then
  begin
    raise EInvalidOp.Create('Prepare the matcher before scanning');
  end;
  LPosition := 1;
  LPending := 0;
  LState := FNodes[0].Next[0];
  LPrevious := 0;
  while (LPosition <= Length(AText)) or (LPending <> 0) do
  begin
    LSymbol := NextSymbol(AText, LPosition, LPending, FRussian);
    if (LSymbol <> 0) or (LPrevious <> 0) then
    begin
      LState := FNodes[LState].Next[LSymbol];
      if LSymbol = 0 then
      begin
        MarkOutput;
      end;
    end;
    LPrevious := LSymbol;
  end;
  if LPrevious <> 0 then
  begin
    LState := FNodes[LState].Next[0];
    MarkOutput;
  end;
end;

end.
