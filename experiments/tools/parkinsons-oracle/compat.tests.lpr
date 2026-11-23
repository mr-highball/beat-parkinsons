{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program CompatTests;

{$mode delphi}
{$H+}
{$codepage utf8}

uses
  SysUtils, parkinsonsoracle.compat;

var
  GChecks: Integer;

procedure Check(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
  Inc(GChecks);
end;

procedure ExpectInvalidUtf8(const ABytes: RawByteString; const ALabel: String);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    RequireValidUtf8(ABytes);
  except
    on EConvertError do
      LRaised := True;
  end;
  Check(LRaised, 'Expected invalid UTF-8 rejection: ' + ALabel);
end;

begin
  Check(ComputeSha256Hex('') =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'SHA-256 empty string vector.');
  Check(ComputeSha256Hex('abc') =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'SHA-256 abc vector.');
  Check(ComputeSha256Hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq') =
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    'SHA-256 56-byte boundary vector.');
  Check(ComputeSha256Hex(
    'abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu') =
    'cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
    'SHA-256 112-byte multi-block vector.');

  RequireValidUtf8('');
  RequireValidUtf8('Hello Parkinson'#226#128#153's Oracle '#240#159#167#160);
  Inc(GChecks, 2);

  ExpectInvalidUtf8(#$80, 'bare continuation byte');
  ExpectInvalidUtf8(#$C0#$AF, 'overlong 2-byte slash');
  ExpectInvalidUtf8(#$E0#$80#$AF, 'overlong 3-byte');
  ExpectInvalidUtf8(#$ED#$A0#$80, 'UTF-16 high surrogate');
  ExpectInvalidUtf8(#$F0#$80#$80#$AF, 'overlong 4-byte');
  ExpectInvalidUtf8(#$F4#$90#$80#$80, 'above U+10FFFF');
  ExpectInvalidUtf8(#$E2#$82, 'truncated 3-byte sequence');

  WriteLn(GChecks, ' portability SHA-256 and UTF-8 checks passed.');
end.
