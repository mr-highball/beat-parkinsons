{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TestRevisions;

{$mode delphi}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Process;

const
  CHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9'local_reference'#9'rationale';
  CLocator = 'research/2010-2014/Source-Text/PMC3039966.txt#L465';
  CBom: array[0..2] of Byte = ($EF, $BB, $BF);

procedure Put(const APath: String; const AText: UTF8String; ABom: Boolean = False);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if ABom then
    begin
      LStream.WriteBuffer(CBom, SizeOf(CBom));
    end;
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

function Get(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(Result, LStream.Size);
    if Result <> '' then
    begin
      LStream.ReadBuffer(Result[1], Length(Result));
    end;
  finally
    LStream.Free;
  end;
end;

var
  GDirectory: String;
  GExecutable: String;
  GBase: UTF8String;
  GBefore: UTF8String;
  GAfter: UTF8String;
  GOther: UTF8String;
  GPassed: Integer;

procedure Check(const AName: String; const ABase, APin, ACorrections: UTF8String;
  AShouldPass: Boolean; const AExpected: UTF8String = '');
var
  LProcess: TProcess;
  LStatus: Integer;
  LOriginal: UTF8String;
  LActual: UTF8String;
begin
  Put(GDirectory + '/base.tsv', ABase, True);
  Put(GDirectory + '/pin.tsv', APin);
  Put(GDirectory + '/corrections.tsv', ACorrections);
  LOriginal := Get(GDirectory + '/base.tsv');
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := GExecutable;
    LProcess.Parameters.Add(GDirectory + '/base.tsv');
    LProcess.Parameters.Add(GDirectory + '/pin.tsv');
    LProcess.Parameters.Add(GDirectory + '/corrections.tsv');
    LProcess.Parameters.Add(GDirectory + '/output.tsv');
    LProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    LStatus := LProcess.ExitStatus;
  finally
    LProcess.Free;
  end;
  if (LStatus = 0) <> AShouldPass then
  begin
    raise Exception.Create('Unexpected acceptance/rejection: ' + AName);
  end;
  if LOriginal <> Get(GDirectory + '/base.tsv') then
  begin
    raise Exception.Create('Baseline mutated');
  end;
  if AShouldPass then
  begin
    LActual := Get(GDirectory + '/output.tsv');
    if (Copy(LActual, 1, 3) <> Copy(LOriginal, 1, 3)) or
      (Copy(LActual, 4, Length(LActual)) <> AExpected) then
    begin
      raise Exception.Create('Output bytes/order/encoding differ: ' + AName);
    end;
  end;
  Inc(GPassed);
  WriteLn(AName, #9, 'PASS', #9, LStatus);
end;

begin
  DefaultSystemCodePage := CP_UTF8;
  if ParamCount <> 2 then
  begin
    Halt(2);
  end;
  GExecutable := ExpandFileName(ParamStr(1));
  GDirectory := ExpandFileName(ParamStr(2));
  ForceDirectories(GDirectory);
  GBefore := '0001'#9'PMID:21340000'#9'excluded'#9'full_text'#9 + CLocator +
    #9'Old incomplete scope.';
  GAfter := '0001'#9'PMID:21340000'#9'related'#9'full_text'#9 + CLocator +
    #9'Verified original food-derived constituent; no clinical direction.';
  GOther := '0002'#9'PMID:11111111'#9'excluded'#9'full_text'#9 + CLocator +
    #9'café 日本語 unchanged bytes';
  GBase := CHeader + #13#10 + GOther + #10 + GBefore;
  GPassed := 0;
  Check('mixed_endings_bom_unicode_no_final_newline', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + GAfter, True, CHeader + #13#10 + GOther + #10 + GAfter);
  Check('unrelated_append_rebase', GBase + #10 +
    StringReplace(GOther, '0002', '0003', []), CHeader + #10 + GBefore,
    CHeader + #10 + GAfter, True, CHeader + #13#10 + GOther + #10 + GAfter + #10 +
    StringReplace(GOther, '0002', '0003', []));
  Check('duplicate_correction', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + GAfter + #10 + GAfter, False);
  Check('no_op_role', GBase, CHeader + #10 + GBefore, CHeader + #10 + GBefore, False);
  Check('changed_basis', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + StringReplace(GAfter, 'full_text', 'abstract', []), False);
  Check('unproven_existing_key', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + StringReplace(GOther, 'excluded', 'related', []), False);
  Check('missing_baseline_key', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + StringReplace(GAfter, '0001', '0999', []), False);
  Check('stale_selected_pin', GBase, CHeader + #10 +
    StringReplace(GBefore, 'Old incomplete scope.', 'Changed pin.', []),
    CHeader + #10 + GAfter, False);
  Check('missing_source_locator', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + StringReplace(GAfter, CLocator, 'research/not-present-source.txt', []), False);
  Check('empty_rationale', GBase, CHeader + #10 + GBefore,
    CHeader + #10 + Copy(GAfter, 1, Pos('Verified original', GAfter) - 1), False);
  WriteLn('passed=', GPassed, ' total=10');
end.
