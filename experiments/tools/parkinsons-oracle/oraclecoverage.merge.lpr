{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program OracleCoverageMerge;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, StrUtils;

type
  TFields = array of UTF8String;
  TCounts = class
    Values: array[0..3] of Int64;
  end;

const
  CLookupHeader = 'date'#9'batch'#9'workstream'#9'question'#9'lookup_kind'#9'exposure'#9 +
    'symptom'#9'claim_revision'#9'catalog_revision'#9'outcome'#9'local_queries'#9 +
    'evidence_locator'#9'gap'#9'next_action';
  CBatchHeader = 'date'#9'batch'#9'workstream'#9'lookup_kind'#9'hits'#9'partials'#9 +
    'misses'#9'unavailable'#9'denominator'#9'strict_hit_rate'#9'lead_rate'#9'trend'#9'priority';

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function Fields(const ALine: UTF8String): TFields;
var
  LStart: Integer;
  LIndex: Integer;
  LCount: Integer;
begin
  Result := nil;
  LStart := 1;
  LCount := 0;
  for LIndex := 1 to Length(ALine) + 1 do
  begin
    if (LIndex > Length(ALine)) or (ALine[LIndex] = #9) then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := Copy(ALine, LStart, LIndex - LStart);
      Inc(LCount);
      LStart := LIndex + 1;
    end;
  end;
end;

function NewIndex: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.Duplicates := dupError;
end;

procedure LoadTable(const APath, AHeader: String; AWidth: Integer; ATable: TStrings);
var
  LIndex: Integer;
begin
  ATable.LoadFromFile(APath, TEncoding.UTF8);
  Require((ATable.Count > 0) and (ATable[0] = AHeader), 'Invalid header: ' + APath);
  for LIndex := 1 to ATable.Count - 1 do
  begin
    Require(Length(Fields(UTF8String(ATable[LIndex]))) = AWidth,
      'Invalid field width at row ' + IntToStr(LIndex + 1) + ': ' + APath);
  end;
end;

procedure CountLookups(ATable: TStrings; AQuestions, AGroups: TStringList);
var
  LIndex: Integer;
  LPosition: Integer;
  LOutcome: Integer;
  LFields: TFields;
  LKey: String;
  LCounts: TCounts;
begin
  for LIndex := 1 to ATable.Count - 1 do
  begin
    LFields := Fields(UTF8String(ATable[LIndex]));
    Require((Trim(LFields[0]) <> '') and (Trim(LFields[1]) <> '') and
      (Trim(LFields[2]) <> '') and (Trim(LFields[3]) <> ''), 'Empty question identity');
    Require(IndexStr(LFields[4], ['claim_evidence', 'source_verification']) >= 0,
      'Invalid lookup_kind');
    LOutcome := IndexStr(LFields[9], ['hit', 'partial', 'miss', 'unavailable']);
    Require(LOutcome >= 0, 'Invalid lookup outcome');
    AQuestions.Add(LFields[1] + #9 + LFields[3]);
    LKey := LFields[1] + #9 + LFields[2] + #9 + LFields[4];
    if AGroups.Find(LKey, LPosition) then
    begin
      LCounts := TCounts(AGroups.Objects[LPosition]);
    end
    else
    begin
      LCounts := TCounts.Create;
      AGroups.AddObject(LKey, LCounts);
    end;
    Inc(LCounts.Values[LOutcome]);
  end;
end;

procedure CheckBatches(ATable: TStrings; AGroups, AKeys: TStringList;
  AReconcile: Boolean);
var
  LFields: TFields;
  LIndex: Integer;
  LPosition: Integer;
  LOutcome: Integer;
  LValue: Int64;
  LDenominator: Int64;
  LCounts: TCounts;
  LKey: String;
begin
  for LIndex := 1 to ATable.Count - 1 do
  begin
    LFields := Fields(UTF8String(ATable[LIndex]));
    Require((Trim(LFields[0]) <> '') and (Trim(LFields[1]) <> '') and
      (Trim(LFields[2]) <> '') and
      (IndexStr(LFields[3], ['claim_evidence', 'source_verification']) >= 0),
      'Invalid batch identity or lookup_kind');
    LKey := LFields[1] + #9 + LFields[2] + #9 + LFields[3];
    AKeys.Add(LKey);
    Require(AGroups.Find(LKey, LPosition), 'Batch has no corresponding questions: ' + LKey);
    LCounts := TCounts(AGroups.Objects[LPosition]);
    LDenominator := 0;
    for LOutcome := 0 to 3 do
    begin
      Require(TryStrToInt64(LFields[4 + LOutcome], LValue) and (LValue >= 0),
        'Invalid batch count');
      if AReconcile then
      begin
        Require(LValue = LCounts.Values[LOutcome], 'Batch/question count mismatch: ' + LKey);
      end;
      if LOutcome < 3 then
      begin
        Inc(LDenominator, LValue);
      end;
    end;
    Require(TryStrToInt64(LFields[8], LValue) and (LValue = LDenominator),
      'Batch denominator must exclude unavailable questions: ' + LKey);
    Require(LFields[9] = LFields[4] + '/' + IntToStr(LDenominator),
      'Invalid strict_hit_rate: ' + LKey);
    Require(LFields[10] = IntToStr(StrToInt64(LFields[4]) + StrToInt64(LFields[5])) +
      '/' + IntToStr(LDenominator), 'Invalid lead_rate: ' + LKey);
  end;
end;

procedure CheckOrphans(AGroups, AKeys: TStringList);
var
  LIndex: Integer;
begin
  for LIndex := 0 to AGroups.Count - 1 do
  begin
    Require(AKeys.IndexOf(AGroups[LIndex]) >= 0,
      'Question group lacks its own batch aggregate: ' + AGroups[LIndex]);
  end;
end;

function ReadBytes(const APath: String): UTF8String;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
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

procedure AppendTable(const AOldPath, ANewPath, AOutputPath: String);
var
  LOld: UTF8String;
  LNew: UTF8String;
  LCombined: UTF8String;
  LBreak: Integer;
  LStream: TFileStream;
begin
  LOld := ReadBytes(AOldPath);
  LNew := ReadBytes(ANewPath);
  LBreak := Pos(#10, LNew);
  Require(LBreak > 0, 'New table has no data rows');
  LCombined := LOld;
  if (LCombined <> '') and (LCombined[Length(LCombined)] <> #10) then
  begin
    LCombined := LCombined + #10;
  end;
  LCombined := LCombined + Copy(LNew, LBreak + 1, Length(LNew));
  LStream := TFileStream.Create(AOutputPath, fmCreate);
  try
    LStream.WriteBuffer(LCombined[1], Length(LCombined));
  finally
    LStream.Free;
  end;
  Require(ReadBytes(AOutputPath) = LCombined, 'Output byte verification failed');
  Require(Copy(LCombined, 1, Length(LOld)) = LOld, 'Old table bytes were changed');
end;

procedure Run;
var
  LOldLookups: TStringList;
  LOldBatches: TStringList;
  LNewLookups: TStringList;
  LNewBatches: TStringList;
  LQuestions: TStringList;
  LBatchKeys: TStringList;
  LOldGroups: TStringList;
  LNewGroups: TStringList;
  LOldBatchKeys: TStringList;
  LNewBatchKeys: TStringList;
  LIndex: Integer;
  LOther: Integer;
  LCounts: TCounts;
  LTotals: array[0..3] of Int64;
begin
  Require(ParamCount = 6, 'Pass old lookups, old batches, new lookups, new batches, staged lookups, staged batches.');
  for LIndex := 5 to 6 do
  begin
    Require(ContainsText(ExpandFileName(ParamStr(LIndex)), PathDelim + 'build' + PathDelim),
      'Output must be under a build directory');
    for LOther := 1 to 4 do
    begin
      Require(not SameFileName(ExpandFileName(ParamStr(LIndex)),
        ExpandFileName(ParamStr(LOther))), 'Output must not overwrite an input');
    end;
  end;
  Require(not SameFileName(ExpandFileName(ParamStr(5)), ExpandFileName(ParamStr(6))),
    'Use distinct output paths');
  LOldLookups := TStringList.Create;
  LOldBatches := TStringList.Create;
  LNewLookups := TStringList.Create;
  LNewBatches := TStringList.Create;
  LQuestions := NewIndex;
  LBatchKeys := NewIndex;
  LOldGroups := NewIndex;
  LNewGroups := NewIndex;
  LOldBatchKeys := NewIndex;
  LNewBatchKeys := NewIndex;
  try
    LoadTable(ParamStr(1), CLookupHeader, 14, LOldLookups);
    LoadTable(ParamStr(2), CBatchHeader, 13, LOldBatches);
    LoadTable(ParamStr(3), CLookupHeader, 14, LNewLookups);
    LoadTable(ParamStr(4), CBatchHeader, 13, LNewBatches);
    Require((LNewLookups.Count > 1) and (LNewBatches.Count > 1), 'Empty append');
    CountLookups(LOldLookups, LQuestions, LOldGroups);
    CountLookups(LNewLookups, LQuestions, LNewGroups);
    CheckBatches(LOldBatches, LOldGroups, LOldBatchKeys, True);
    CheckBatches(LNewBatches, LNewGroups, LNewBatchKeys, True);
    for LIndex := 0 to LOldBatchKeys.Count - 1 do
    begin
      LBatchKeys.Add(LOldBatchKeys[LIndex]);
    end;
    // Validate each side separately; new questions cannot silently extend old aggregates.
    for LIndex := 0 to LNewBatchKeys.Count - 1 do
    begin
      LBatchKeys.Add(LNewBatchKeys[LIndex]);
    end;
    CheckOrphans(LOldGroups, LOldBatchKeys);
    CheckOrphans(LNewGroups, LNewBatchKeys);
    FillChar(LTotals, SizeOf(LTotals), 0);
    for LIndex := 0 to LNewGroups.Count - 1 do
    begin
      LCounts := TCounts(LNewGroups.Objects[LIndex]);
      for LOther := 0 to 3 do
      begin
        Inc(LTotals[LOther], LCounts.Values[LOther]);
      end;
    end;
    AppendTable(ParamStr(1), ParamStr(3), ParamStr(5));
    AppendTable(ParamStr(2), ParamStr(4), ParamStr(6));
    WriteLn('old_questions=', LOldLookups.Count - 1, ' new_questions=', LNewLookups.Count - 1,
      ' combined_questions=', LQuestions.Count);
    WriteLn('old_batches=', LOldBatches.Count - 1, ' new_batches=', LNewBatches.Count - 1,
      ' combined_batches=', LBatchKeys.Count);
    WriteLn('new_hit=', LTotals[0], ' partial=', LTotals[1], ' miss=', LTotals[2],
      ' unavailable=', LTotals[3]);
    WriteLn('all_question_keys_batch_keys_counts_denominators_rates_reconciled=true');
    WriteLn('old_file_bytes_order_preserved=true');
  finally
    for LIndex := 0 to LOldGroups.Count - 1 do
    begin
      LOldGroups.Objects[LIndex].Free;
    end;
    for LIndex := 0 to LNewGroups.Count - 1 do
    begin
      LNewGroups.Objects[LIndex].Free;
    end;
    LOldLookups.Free;
    LOldBatches.Free;
    LNewLookups.Free;
    LNewBatches.Free;
    LQuestions.Free;
    LBatchKeys.Free;
    LOldGroups.Free;
    LNewGroups.Free;
    LOldBatchKeys.Free;
    LNewBatchKeys.Free;
  end;
end;

begin
  DefaultSystemCodePage := CP_UTF8;
  try
    Run;
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
