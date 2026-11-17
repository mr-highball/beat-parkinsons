{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program ReviseExcluded;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata;

type
  TLine = record
    Content: UTF8String;
    Ending: UTF8String;
  end;
  TLines = array of TLine;

const
  CHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9'local_reference'#9'rationale';

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
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

procedure DecodeLines(const ABytes: UTF8String; out ALines: TLines;
  out APrefix: UTF8String);
var
  LStart: Integer;
  LStop: Integer;
  LCount: Integer;
begin
  APrefix := '';
  LStart := 1;
  if (Length(ABytes) >= 3) and (Ord(ABytes[1]) = $EF) and
    (Ord(ABytes[2]) = $BB) and (Ord(ABytes[3]) = $BF) then
  begin
    APrefix := Copy(ABytes, 1, 3);
    LStart := 4;
  end;
  SetLength(ALines, 0);
  LCount := 0;
  while LStart <= Length(ABytes) do
  begin
    LStop := LStart;
    while (LStop <= Length(ABytes)) and (ABytes[LStop] <> #10) do
    begin
      Inc(LStop);
    end;
    SetLength(ALines, LCount + 1);
    ALines[LCount].Content := Copy(ABytes, LStart, LStop - LStart);
    ALines[LCount].Ending := '';
    if LStop <= Length(ABytes) then
    begin
      ALines[LCount].Ending := #10;
      if (ALines[LCount].Content <> '') and
        (ALines[LCount].Content[Length(ALines[LCount].Content)] = #13) then
      begin
        Delete(ALines[LCount].Content, Length(ALines[LCount].Content), 1);
        ALines[LCount].Ending := #13#10;
      end;
    end;
    Inc(LCount);
    LStart := LStop + 1;
  end;
end;

function NewIndex: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.Duplicates := dupError;
end;

procedure IndexLines(const ALines: TLines; const AIndex: TStringList);
var
  LIndex: Integer;
  LFields: TFields;
begin
  Require((Length(ALines) > 0) and (ALines[0].Content = CHeader), 'Invalid header');
  for LIndex := 1 to High(ALines) do
  begin
    LFields := SplitFields(ALines[LIndex].Content, #9);
    Require((Length(LFields) = 6) and (Length(LFields[0]) = 4) and
      (LFields[1] <> ''), 'Malformed row');
    AIndex.AddObject(LFields[0] + #9 + LFields[1], TObject(PtrInt(LIndex)));
  end;
end;

procedure Run;
var
  LBaseline: TLines;
  LExpected: TLines;
  LCorrections: TLines;
  LVerified: TLines;
  LBaselineIndex: TStringList;
  LExpectedIndex: TStringList;
  LCorrectionIndex: TStringList;
  LPrefix: UTF8String;
  LUnused: UTF8String;
  LBytes: UTF8String;
  LOutput: UTF8String;
  LKey: String;
  LPath: String;
  LBefore: TFields;
  LAfter: TFields;
  LRow: Integer;
  LPinnedRow: Integer;
  LPosition: Integer;
  LIndex: Integer;
  LUnchanged: Integer;
  LStream: TFileStream;
begin
  Require(ParamCount = 4, 'Pass baseline, pinned-before, verified corrections, staged output.');
  LPath := ExpandFileName(ParamStr(4));
  Require(ContainsText(LPath, PathDelim + 'build' + PathDelim),
    'Output must be under a build directory');
  for LIndex := 1 to 3 do
  begin
    Require(not SameFileName(LPath, ExpandFileName(ParamStr(LIndex))),
      'Output must not overwrite an input');
  end;
  DecodeLines(ReadBytes(ParamStr(1)), LBaseline, LPrefix);
  DecodeLines(ReadBytes(ParamStr(2)), LExpected, LUnused);
  DecodeLines(ReadBytes(ParamStr(3)), LCorrections, LUnused);
  LBaselineIndex := NewIndex;
  LExpectedIndex := NewIndex;
  LCorrectionIndex := NewIndex;
  try
    IndexLines(LBaseline, LBaselineIndex);
    IndexLines(LExpected, LExpectedIndex);
    IndexLines(LCorrections, LCorrectionIndex);
    Require(Length(LCorrections) > 1, 'Empty correction set');
    for LIndex := 0 to LCorrectionIndex.Count - 1 do
    begin
      LKey := LCorrectionIndex[LIndex];
      Require(LBaselineIndex.Find(LKey, LPosition), 'Key absent from current baseline');
      LRow := PtrInt(LBaselineIndex.Objects[LPosition]);
      Require(LExpectedIndex.Find(LKey, LPosition), 'Key lacks pinned-before proof');
      LPinnedRow := PtrInt(LExpectedIndex.Objects[LPosition]);
      Require(LBaseline[LRow].Content = LExpected[LPinnedRow].Content,
        'Selected baseline row changed since pin');
      LBefore := SplitFields(LBaseline[LRow].Content, #9);
      LAfter := SplitFields(LCorrections[PtrInt(LCorrectionIndex.Objects[LIndex])].Content, #9);
      Require((LBefore[2] = 'excluded') and (LAfter[2] = 'related'),
        'Only independently verified excluded-to-related revisions are accepted');
      Require(LAfter[3] = LBefore[3], 'Evidence basis must remain unchanged');
      Require((LAfter[5] <> '') and (LAfter[5] <> LBefore[5]),
        'Fresh verified rationale is required');
      LPath := SplitFields(LAfter[4], '#')[0];
      Require(StartsStr('https://', LAfter[4]) or
        (StartsStr('research/', LPath) and not ContainsStr(LPath, '..') and FileExists(LPath)),
        'Verified primary source locator required');
    end;
    LUnchanged := 0;
    LStream := TFileStream.Create(ParamStr(4), fmCreate);
    try
      if LPrefix <> '' then
      begin
        LStream.WriteBuffer(LPrefix[1], Length(LPrefix));
      end;
      for LIndex := 0 to High(LBaseline) do
      begin
        if LIndex = 0 then
        begin
          LBytes := LBaseline[LIndex].Content;
        end
        else
        begin
          LBefore := SplitFields(LBaseline[LIndex].Content, #9);
          LKey := LBefore[0] + #9 + LBefore[1];
          if LCorrectionIndex.Find(LKey, LPosition) then
          begin
            LBytes := LCorrections[PtrInt(LCorrectionIndex.Objects[LPosition])].Content;
          end
          else
          begin
            LBytes := LBaseline[LIndex].Content;
            Inc(LUnchanged);
          end;
        end;
        if LBytes <> '' then
        begin
          LStream.WriteBuffer(LBytes[1], Length(LBytes));
        end;
        LBytes := LBaseline[LIndex].Ending;
        if LBytes <> '' then
        begin
          LStream.WriteBuffer(LBytes[1], Length(LBytes));
        end;
      end;
    finally
      LStream.Free;
    end;
    LOutput := ReadBytes(ParamStr(4));
    DecodeLines(LOutput, LVerified, LUnused);
    Require((Length(LVerified) = Length(LBaseline)) and (LUnused = LPrefix),
      'Row count or encoding prefix changed');
    for LIndex := 0 to High(LBaseline) do
    begin
      Require(LVerified[LIndex].Ending = LBaseline[LIndex].Ending, 'Line ending changed');
      if LIndex = 0 then
      begin
        Require(LVerified[LIndex].Content = LBaseline[LIndex].Content, 'Header changed');
        Continue;
      end;
      LBefore := SplitFields(LBaseline[LIndex].Content, #9);
      LAfter := SplitFields(LVerified[LIndex].Content, #9);
      Require((LBefore[0] = LAfter[0]) and (LBefore[1] = LAfter[1]), 'Membership/order changed');
      if LCorrectionIndex.IndexOf(LBefore[0] + #9 + LBefore[1]) < 0 then
      begin
        Require(LBaseline[LIndex].Content = LVerified[LIndex].Content,
          'Nonselected row bytes changed at row ' + IntToStr(LIndex) + ' key ' +
          LBefore[0] + '/' + LBefore[1]);
      end
      else
      begin
        LPosition := LCorrectionIndex.IndexOf(LBefore[0] + #9 + LBefore[1]);
        Require(LVerified[LIndex].Content =
          LCorrections[PtrInt(LCorrectionIndex.Objects[LPosition])].Content,
          'Selected correction bytes differ');
      end;
    end;
    WriteLn('rows=', Length(LBaseline) - 1, ' revised=', LCorrectionIndex.Count,
      ' nonselected_byte_identical=', LUnchanged);
    WriteLn('membership_order_basis_line_endings_preserved=true');
    WriteLn('original_content_verification_is_manual_not_inferred_from_keywords=true');
  finally
    LBaselineIndex.Free;
    LExpectedIndex.Free;
    LCorrectionIndex.Free;
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
