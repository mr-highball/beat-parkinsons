{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit parkinsonsoracle.compat;

{$mode delphi}
{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function ComputeSha256Hex(const AData: RawByteString): String;
procedure RequireValidUtf8(const AData: RawByteString);

implementation

const
  CSha256K: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

{$PUSH}
{$Q-}
{$R-}
function Ror32(AValue: LongWord; ABits: Byte): LongWord; inline;
begin
  Result := (AValue shr ABits) or (AValue shl (32 - ABits));
end;

function ComputeSha256Hex(const AData: RawByteString): String;
type
  TSha256Block = array[0..63] of Byte;
  TSha256State = array[0..7] of LongWord;
var
  LState: TSha256State;
  LBlock: TSha256Block;
  LLen: QWord;
  LOffset: SizeInt;
  LRemaining: SizeInt;
  LBitLen: QWord;
  LIndex: Integer;

  procedure Transform(const ABlock: TSha256Block);
  var
    LW: array[0..63] of LongWord;
    LA, LB, LC, LD, LE, LF, LG, LH: LongWord;
    LS0, LS1, LCh, LMaj, LTemp1, LTemp2: LongWord;
    LI: Integer;
  begin
    for LI := 0 to 15 do
      LW[LI] := (LongWord(ABlock[LI * 4]) shl 24) or
        (LongWord(ABlock[LI * 4 + 1]) shl 16) or
        (LongWord(ABlock[LI * 4 + 2]) shl 8) or
        LongWord(ABlock[LI * 4 + 3]);
    for LI := 16 to 63 do
    begin
      LS0 := Ror32(LW[LI - 15], 7) xor Ror32(LW[LI - 15], 18) xor (LW[LI - 15] shr 3);
      LS1 := Ror32(LW[LI - 2], 17) xor Ror32(LW[LI - 2], 19) xor (LW[LI - 2] shr 10);
      LW[LI] := LW[LI - 16] + LS0 + LW[LI - 7] + LS1;
    end;

    LA := LState[0];
    LB := LState[1];
    LC := LState[2];
    LD := LState[3];
    LE := LState[4];
    LF := LState[5];
    LG := LState[6];
    LH := LState[7];

    for LI := 0 to 63 do
    begin
      LS1 := Ror32(LE, 6) xor Ror32(LE, 11) xor Ror32(LE, 25);
      LCh := (LE and LF) xor ((not LE) and LG);
      LTemp1 := LH + LS1 + LCh + CSha256K[LI] + LW[LI];
      LS0 := Ror32(LA, 2) xor Ror32(LA, 13) xor Ror32(LA, 22);
      LMaj := (LA and LB) xor (LA and LC) xor (LB and LC);
      LTemp2 := LS0 + LMaj;

      LH := LG;
      LG := LF;
      LF := LE;
      LE := LD + LTemp1;
      LD := LC;
      LC := LB;
      LB := LA;
      LA := LTemp1 + LTemp2;
    end;

    LState[0] := LState[0] + LA;
    LState[1] := LState[1] + LB;
    LState[2] := LState[2] + LC;
    LState[3] := LState[3] + LD;
    LState[4] := LState[4] + LE;
    LState[5] := LState[5] + LF;
    LState[6] := LState[6] + LG;
    LState[7] := LState[7] + LH;
  end;

begin
  LState[0] := $6a09e667;
  LState[1] := $bb67ae85;
  LState[2] := $3c6ef372;
  LState[3] := $a54ff53a;
  LState[4] := $510e527f;
  LState[5] := $9b05688c;
  LState[6] := $1f83d9ab;
  LState[7] := $5be0cd19;

  LLen := QWord(Length(AData));
  LOffset := 1;
  LRemaining := Length(AData);
  while LRemaining >= 64 do
  begin
    Move(AData[LOffset], LBlock[0], 64);
    Transform(LBlock);
    Inc(LOffset, 64);
    Dec(LRemaining, 64);
  end;

  FillChar(LBlock, SizeOf(LBlock), 0);
  if LRemaining > 0 then
    Move(AData[LOffset], LBlock[0], LRemaining);
  LBlock[LRemaining] := $80;

  if LRemaining >= 56 then
  begin
    Transform(LBlock);
    FillChar(LBlock, SizeOf(LBlock), 0);
  end;

  LBitLen := LLen * 8;
  for LIndex := 0 to 7 do
    LBlock[63 - LIndex] := Byte((LBitLen shr (LIndex * 8)) and $FF);
  Transform(LBlock);

  Result := '';
  for LIndex := 0 to 7 do
    Result := Result + LowerCase(IntToHex(LState[LIndex], 8));
end;
{$POP}

procedure RequireValidUtf8(const AData: RawByteString);
var
  LIndex: SizeInt;
  LLen: SizeInt;
  LB0, LB1, LB2, LB3: Byte;
begin
  LLen := Length(AData);
  LIndex := 1;
  while LIndex <= LLen do
  begin
    LB0 := Byte(AData[LIndex]);
    if LB0 <= $7F then
    begin
      Inc(LIndex);
    end
    else if (LB0 >= $C2) and (LB0 <= $DF) then
    begin
      if LIndex + 1 > LLen then
        raise EConvertError.Create('Truncated 2-byte UTF-8 sequence.');
      LB1 := Byte(AData[LIndex + 1]);
      if (LB1 < $80) or (LB1 > $BF) then
        raise EConvertError.Create('Invalid 2-byte UTF-8 continuation.');
      Inc(LIndex, 2);
    end
    else if (LB0 >= $E0) and (LB0 <= $EF) then
    begin
      if LIndex + 2 > LLen then
        raise EConvertError.Create('Truncated 3-byte UTF-8 sequence.');
      LB1 := Byte(AData[LIndex + 1]);
      LB2 := Byte(AData[LIndex + 2]);
      if (LB1 < $80) or (LB1 > $BF) or (LB2 < $80) or (LB2 > $BF) then
        raise EConvertError.Create('Invalid 3-byte UTF-8 continuation.');
      if (LB0 = $E0) and (LB1 < $A0) then
        raise EConvertError.Create('Overlong 3-byte UTF-8 sequence.');
      if (LB0 = $ED) and (LB1 >= $A0) then
        raise EConvertError.Create('UTF-16 surrogate in UTF-8 stream.');
      Inc(LIndex, 3);
    end
    else if (LB0 >= $F0) and (LB0 <= $F4) then
    begin
      if LIndex + 3 > LLen then
        raise EConvertError.Create('Truncated 4-byte UTF-8 sequence.');
      LB1 := Byte(AData[LIndex + 1]);
      LB2 := Byte(AData[LIndex + 2]);
      LB3 := Byte(AData[LIndex + 3]);
      if (LB1 < $80) or (LB1 > $BF) or (LB2 < $80) or (LB2 > $BF) or
        (LB3 < $80) or (LB3 > $BF) then
        raise EConvertError.Create('Invalid 4-byte UTF-8 continuation.');
      if (LB0 = $F0) and (LB1 < $90) then
        raise EConvertError.Create('Overlong 4-byte UTF-8 sequence.');
      if (LB0 = $F4) and (LB1 > $8F) then
        raise EConvertError.Create('Codepoint exceeds Unicode maximum.');
      Inc(LIndex, 4);
    end
    else
      raise EConvertError.Create('Invalid UTF-8 leading byte.');
  end;
end;

end.
