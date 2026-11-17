{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TestOracleCoverageMerge;

{$mode delphi}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, Process;

const
  CLookupHeader = 'date'#9'batch'#9'workstream'#9'question'#9'lookup_kind'#9'exposure'#9 +
    'symptom'#9'claim_revision'#9'catalog_revision'#9'outcome'#9'local_queries'#9 +
    'evidence_locator'#9'gap'#9'next_action';
  CBatchHeader = 'date'#9'batch'#9'workstream'#9'lookup_kind'#9'hits'#9'partials'#9 +
    'misses'#9'unavailable'#9'denominator'#9'strict_hit_rate'#9'lead_rate'#9'trend'#9'priority';

var
  GExecutable: String;
  GRoot: String;
  GOldLookups: UTF8String;
  GOldBatches: UTF8String;
  GNewLookups: UTF8String;
  GNewBatches: UTF8String;
  GPassed: Integer;

function Lookup(const ABatch, AQuestion, AKind, AOutcome: UTF8String): UTF8String;
begin
  Result := '2026-11-17'#9 + ABatch + #9'fixture'#9 + AQuestion + #9 + AKind +
    #9'ingredient café 日本語'#9'symptom'#9'revision'#9'66'#9 + AOutcome +
    #9'exact query'#9'research/period/source.txt'#9'gap'#9'continue review';
end;

function Batch(const ABatch, AKind: UTF8String; AH, AP, AM, AU: Integer): UTF8String;
var
  LDenominator: Integer;
begin
  LDenominator := AH + AP + AM;
  Result := '2026-11-17'#9 + ABatch + #9'fixture'#9 + AKind + #9 +
    UTF8String(IntToStr(AH)) + #9 + UTF8String(IntToStr(AP)) + #9 +
    UTF8String(IntToStr(AM)) + #9 + UTF8String(IntToStr(AU)) + #9 +
    UTF8String(IntToStr(LDenominator)) + #9 + UTF8String(IntToStr(AH)) + '/' +
    UTF8String(IntToStr(LDenominator)) + #9 + UTF8String(IntToStr(AH + AP)) + '/' +
    UTF8String(IntToStr(LDenominator)) + #9'fixture'#9'continue';
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

procedure Check(const AName: String; const ANewLookups, ANewBatches: UTF8String;
  APass: Boolean; AOverwriteInput: Boolean = False);
var
  LDirectory: String;
  LProcess: TProcess;
  LStatus: Integer;
  LOutputLookup: String;
  LActual: UTF8String;
begin
  LDirectory := GRoot + PathDelim + AName;
  ForceDirectories(LDirectory);
  Put(LDirectory + '/old-lookups.tsv', GOldLookups);
  Put(LDirectory + '/old-batches.tsv', GOldBatches);
  Put(LDirectory + '/new-lookups.tsv', ANewLookups);
  Put(LDirectory + '/new-batches.tsv', ANewBatches);
  LOutputLookup := LDirectory + '/merged-lookups.tsv';
  if AOverwriteInput then
  begin
    LOutputLookup := LDirectory + '/old-lookups.tsv';
  end;
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := GExecutable;
    LProcess.Parameters.Add(LDirectory + '/old-lookups.tsv');
    LProcess.Parameters.Add(LDirectory + '/old-batches.tsv');
    LProcess.Parameters.Add(LDirectory + '/new-lookups.tsv');
    LProcess.Parameters.Add(LDirectory + '/new-batches.tsv');
    LProcess.Parameters.Add(LOutputLookup);
    LProcess.Parameters.Add(LDirectory + '/merged-batches.tsv');
    LProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    LStatus := LProcess.ExitStatus;
  finally
    LProcess.Free;
  end;
  if (LStatus = 0) <> APass then
  begin
    raise Exception.Create('Unexpected acceptance/rejection: ' + AName);
  end;
  if (Get(LDirectory + '/old-lookups.tsv') <> GOldLookups) or
    (Get(LDirectory + '/old-batches.tsv') <> GOldBatches) or
    (Get(LDirectory + '/new-lookups.tsv') <> ANewLookups) or
    (Get(LDirectory + '/new-batches.tsv') <> ANewBatches) then
  begin
    raise Exception.Create('Input mutated: ' + AName);
  end;
  if APass then
  begin
    LActual := Get(LOutputLookup);
    if LActual <> GOldLookups + #10 + Copy(ANewLookups,
      Pos(#10, ANewLookups) + 1, Length(ANewLookups)) then
    begin
      raise Exception.Create('Lookup output bytes/order differ: ' + AName);
    end;
    LActual := Get(LDirectory + '/merged-batches.tsv');
    if LActual <> GOldBatches + #10 + Copy(ANewBatches,
      Pos(#10, ANewBatches) + 1, Length(ANewBatches)) then
    begin
      raise Exception.Create('Batch output bytes/order differ: ' + AName);
    end;
  end
  else if FileExists(LDirectory + '/merged-lookups.tsv') or
    FileExists(LDirectory + '/merged-batches.tsv') then
  begin
    raise Exception.Create('Validation failure wrote outputs: ' + AName);
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
  GRoot := ExpandFileName(ParamStr(2));
  GOldLookups := CLookupHeader + #13#10 + Lookup('old', 'Q0', 'source_verification', 'hit');
  GOldBatches := CBatchHeader + #13#10 + Batch('old', 'source_verification', 1, 0, 0, 0);
  GNewLookups := CLookupHeader + #10 + Lookup('new', 'Q1', 'source_verification', 'partial') +
    #10 + Lookup('new', 'Q2', 'source_verification', 'miss') +
    #10 + Lookup('new', 'Q3', 'source_verification', 'unavailable');
  GNewBatches := CBatchHeader + #10 + Batch('new', 'source_verification', 0, 1, 1, 1);
  GPassed := 0;
  Check('valid_unicode_mixed_newlines_unavailable', GNewLookups, GNewBatches, True);
  Check('all_unavailable_zero_denominator', CLookupHeader + #10 +
    Lookup('new', 'Q1', 'source_verification', 'unavailable'),
    CBatchHeader + #10 + Batch('new', 'source_verification', 0, 0, 0, 1), True);
  Check('same_batch_two_question_types', CLookupHeader + #10 +
    Lookup('new', 'Qc', 'claim_evidence', 'partial') + #10 +
    Lookup('new', 'Qs', 'source_verification', 'hit'), CBatchHeader + #10 +
    Batch('new', 'claim_evidence', 0, 1, 0, 0) + #10 +
    Batch('new', 'source_verification', 1, 0, 0, 0), True);
  Check('wrong_counts', GNewLookups, CBatchHeader + #10 +
    Batch('new', 'source_verification', 0, 2, 1, 1), False);
  Check('wrong_rate', GNewLookups, StringReplace(GNewBatches, '0/2', '1/2', []), False);
  Check('duplicate_new_question', GNewLookups + #10 +
    Lookup('new', 'Q1', 'source_verification', 'partial'), GNewBatches, False);
  Check('duplicate_old_new_question', CLookupHeader + #10 +
    Lookup('old', 'Q0', 'source_verification', 'hit'), CBatchHeader + #10 +
    Batch('old', 'source_verification', 1, 0, 0, 0), False);
  Check('missing_batch', GNewLookups + #10 +
    Lookup('orphan', 'Q4', 'source_verification', 'miss'), GNewBatches, False);
  Check('duplicate_batch_key', CLookupHeader + #10 +
    Lookup('old', 'Q1', 'source_verification', 'miss'), CBatchHeader + #10 +
    Batch('old', 'source_verification', 0, 0, 1, 0), False);
  Check('invalid_outcome_related', StringReplace(GNewLookups, #9'partial'#9,
    #9'related'#9, []), GNewBatches, False);
  Check('invalid_lookup_kind', StringReplace(GNewLookups, 'source_verification',
    'unrecognized_kind', []), GNewBatches, False);
  Check('malformed_field_width', GNewLookups + #9'extra', GNewBatches, False);
  Check('overwrite_input', GNewLookups, GNewBatches, False, True);
  Check('duplicate_new_aggregate', GNewLookups, GNewBatches + #10 +
    Batch('new', 'source_verification', 0, 1, 1, 1), False);
  Check('malformed_header', StringReplace(GNewLookups, 'date', 'wrong_header', []),
    GNewBatches, False);
  WriteLn('passed=', GPassed, ' total=15');
end.
