{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TestExcludedRoleAudit;

{$mode delphi}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Process;

const
  CHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9'local_reference'#9'rationale';

var
  GExecutable: String;
  GFreeze: String;
  GDirectory: String;
  GCurrent: UTF8String;
  GProofs: UTF8String;
  GLegacy: UTF8String;
  GFirst: UTF8String;
  GPassed: Integer;

function Row(AId: Integer; const ARole, ARationale: UTF8String): UTF8String;
begin
  Result := UTF8String(Format('%.4d', [AId])) + #9'PMID:21340000'#9 + ARole +
    #9'full_text'#9'https://pmc.ncbi.nlm.nih.gov/articles/PMC3039966/'#9 + ARationale;
end;

procedure Put(const APath: String; const AText: UTF8String);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    if AText <> '' then
    begin
      LStream.WriteBuffer(AText[1], Length(AText));
    end;
  finally
    LStream.Free;
  end;
end;

procedure Check(const AName: String; const ALedger, AProofs: UTF8String;
  AShouldPass: Boolean; AReviewed, AAdopted, ARemaining: Integer);
var
  LDirectory: String;
  LProcess: TProcess;
  LOutput: TStringStream;
  LBytes: String;
  LBuffer: array[0..1023] of Byte;
  LRead: Integer;
  LStatus: Integer;
begin
  LDirectory := GDirectory + PathDelim + AName;
  ForceDirectories(LDirectory);
  Put(LDirectory + '/ledger.tsv', ALedger);
  Put(LDirectory + '/proofs.tsv', AProofs);
  LOutput := TStringStream.Create('');
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := GExecutable;
    LProcess.Parameters.Add(GFreeze);
    LProcess.Parameters.Add(LDirectory + '/ledger.tsv');
    LProcess.Parameters.Add(LDirectory);
    if AProofs <> '' then
    begin
      LProcess.Parameters.Add(LDirectory + '/proofs.tsv');
    end;
    LProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    LStatus := LProcess.ExitStatus;
    repeat
      LRead := LProcess.Output.Read(LBuffer, SizeOf(LBuffer));
      if LRead > 0 then
      begin
        LOutput.WriteBuffer(LBuffer, LRead);
      end;
    until LRead = 0;
    LBytes := LOutput.DataString;
    if (LStatus = 0) <> AShouldPass then
    begin
      raise Exception.Create(AName + ': unexpected result: ' + LBytes);
    end;
    if AShouldPass then
    begin
      if (Pos('independently_rechecked=' + IntToStr(AReviewed), LBytes) = 0) or
        (Pos('already_adopted_related=' + IntToStr(AAdopted), LBytes) = 0) or
        (Pos('remaining_all_excluded=' + IntToStr(ARemaining), LBytes) = 0) then
      begin
        raise Exception.Create(AName + ': unexpected counts: ' + LBytes);
      end;
      LOutput.LoadFromFile(LDirectory + '/all-unreviewed-excluded.tsv');
      // Both the flagged meal lead and the unflagged collision stay in scope.
      if (Pos('0016'#9, LOutput.DataString) = 0) or
        (Pos('0017'#9, LOutput.DataString) = 0) then
      begin
        raise Exception.Create(AName + ': lost unreviewed key');
      end;
    end
    else if FileExists(LDirectory + '/all-excluded-inventory.tsv') then
    begin
      raise Exception.Create(AName + ': invalid proof wrote an inventory');
    end;
    Inc(GPassed);
    WriteLn(AName, #9, 'PASS', #9, LStatus);
  finally
    LProcess.Free;
    LOutput.Free;
  end;
end;

var
  LId: Integer;
  LRow: UTF8String;
begin
  DefaultSystemCodePage := CP_UTF8;
  if ParamCount <> 3 then
  begin
    WriteLn(StdErr, 'Pass audit executable, frozen claims and fresh build fixture directory.');
    Halt(2);
  end;
  GExecutable := ExpandFileName(ParamStr(1));
  GFreeze := ExpandFileName(ParamStr(2));
  GDirectory := ExpandFileName(ParamStr(3));
  GCurrent := CHeader;
  GProofs := CHeader;
  GLegacy := CHeader;
  for LId := 1 to 15 do
  begin
    if LId <= 13 then
    begin
      LRow := Row(LId, 'related', 'Verified material café 日本語; no clinical direction.');
    end
    else
    begin
      LRow := Row(LId, 'excluded', 'Different botanical; retained exclusion.');
    end;
    if LId = 1 then
    begin
      GFirst := LRow;
    end;
    GCurrent := GCurrent + #10 + LRow;
    GProofs := GProofs + #10 + LRow;
    GLegacy := GLegacy + #10 + Row(LId, 'excluded',
      'Different botanical; retained exclusion.');
  end;
  LRow := #10 + Row(16, 'excluded', 'An oral mixed meal study needs review.') +
    #10 + Row(17, 'excluded', 'Calendar label only; original recheck unperformed.');
  GCurrent := GCurrent + LRow;
  GLegacy := GLegacy + LRow;
  GPassed := 0;
  Check('complete_15_proofs', GCurrent, GProofs, True, 2, 13, 2);
  Check('legacy_unapplied_proofs', GLegacy, GProofs, True, 15, 0, 2);
  Check('no_proof_input', GCurrent, '', True, 0, 0, 4);
  Check('changed_related_rationale', GCurrent,
    StringReplace(GProofs, 'Verified material', 'Different material', []), False, 0, 0, 0);
  Check('changed_related_role', GCurrent,
    StringReplace(GProofs, #9'related'#9, #9'excluded'#9, []), False, 0, 0, 0);
  Check('changed_related_basis', GCurrent,
    StringReplace(GProofs, #9'full_text'#9, #9'abstract'#9, []), False, 0, 0, 0);
  Check('changed_related_locator', GCurrent,
    StringReplace(GProofs, 'PMC3039966/', 'PMC3039966/changed', []), False, 0, 0, 0);
  Check('changed_retained_exclusion', GCurrent,
    StringReplace(GProofs, 'Different botanical', 'Revised botanical', []), False, 0, 0, 0);
  Check('absent_proof_key', GCurrent,
    GProofs + #10 + Row(18, 'excluded', 'Unproven absent key.'), False, 0, 0, 0);
  Check('duplicate_proof', GCurrent, GProofs + #10 + GFirst, False, 0, 0, 0);
  Check('pending_review_key', StringReplace(GCurrent, #9'related'#9, #9'pending'#9, []),
    GProofs, False, 0, 0, 0);
  WriteLn('passed=', GPassed, ' total=11');
end.
