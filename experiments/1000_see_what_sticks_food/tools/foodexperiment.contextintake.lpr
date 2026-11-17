{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.contextintake;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata;

const
  CReviewHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9 +
    'local_reference'#9'rationale';
  CQueuePrefix = 'priority'#9'reason'#9'id'#9'source_key'#9;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function PairIndex: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupError;
  Result.CaseSensitive := True;
end;

function CanonicalBasis(const ABasis: String): String;
begin
  if ABasis = 'title' then
  begin
    Result := 'title_and_index'
  end
  else
  begin
    Result := ABasis;
  end;
end;

function Depth(const ABasis: String): Integer;
begin
  Result := IndexStr(CanonicalBasis(ABasis),
    ['access_only', 'title_and_index', 'abstract', 'full_text']);
end;

function ReviewLine(const AFields: TFields): String;
begin
  Result := AFields[0] + #9 + AFields[1] + #9 + AFields[2] + #9 + AFields[3] +
    #9 + AFields[4] + #9 + AFields[5];
end;

function SourceAvailable(const AReference: String): Boolean;
var
  LPath: String;
begin
  LPath := SplitFields(AReference, '#')[0];
  Result := StartsStr('https://', AReference) or
    (StartsStr('research/', LPath) and not ContainsStr(LPath, '..') and FileExists(LPath));
end;

procedure Reconcile(const AQueue, ACurrent, AProposals, APacket, AStaged: String);
var
  LQueue, LCurrent, LProposals, LOpen, LSelected, LResidue, LExisting: TStringList;
  LFields, LPrior: TFields;
  LKey, LLocator, LReplacement: String;
  LIndex, LPosition, LQueuedRow, LPriorRow, LDepth, LPriorDepth,
    LNew, LUpgraded, LRetained: Integer;
begin
  LQueue := TStringList.Create;
  LCurrent := TStringList.Create;
  LProposals := TStringList.Create;
  LOpen := PairIndex;
  LSelected := TStringList.Create;
  LResidue := TStringList.Create;
  LExisting := PairIndex;
  try
    LQueue.LoadFromFile(AQueue, TEncoding.UTF8);
    LCurrent.LoadFromFile(ACurrent, TEncoding.UTF8);
    LProposals.LoadFromFile(AProposals, TEncoding.UTF8);
    Require((LQueue.Count > 0) and StartsStr(CQueuePrefix, LQueue[0]), 'Invalid queue header');
    Require((LCurrent.Count > 0) and (LCurrent[0] = CReviewHeader), 'Invalid current review header');
    Require((LProposals.Count > 1) and (LProposals[0] = CReviewHeader), 'Invalid proposal header');
    for LIndex := 1 to LQueue.Count - 1 do
    begin
      LFields := SplitFields(LQueue[LIndex], #9);
      Require(Length(LFields) >= 4, 'Malformed queue line ' + IntToStr(LIndex + 1));
      LOpen.AddObject(LFields[2] + #9 + LFields[3], TObject(PtrInt(LIndex)));
    end;
    for LIndex := 1 to LCurrent.Count - 1 do
    begin
      LFields := SplitFields(LCurrent[LIndex], #9);
      Require(Length(LFields) = 6, 'Malformed current review line ' + IntToStr(LIndex + 1));
      LExisting.AddObject(LFields[0] + #9 + LFields[1], TObject(PtrInt(LIndex)));
    end;

    LSelected.Add(LQueue[0]);
    LResidue.Add(LQueue[0]);
    LNew := 0;
    LUpgraded := 0;
    LRetained := 0;
    for LIndex := 1 to LProposals.Count - 1 do
    begin
      LFields := SplitFields(LProposals[LIndex], #9);
      Require(Length(LFields) = 6, 'Malformed proposal line ' + IntToStr(LIndex + 1));
      LKey := LFields[0] + #9 + LFields[1];
      Require(LOpen.Find(LKey, LPosition), 'Missing or duplicate queued pair ' + LKey);
      LQueuedRow := PtrInt(LOpen.Objects[LPosition]);
      LOpen.Delete(LPosition);
      LSelected.Add(LQueue[LQueuedRow]);

      LDepth := Depth(LFields[3]);
      Require((LDepth >= 0) and (LFields[5] <> '') and SourceAvailable(LFields[4]),
        'Missing evidence depth, locator or rationale for ' + LKey);
      Require(IndexStr(LFields[2], ['related', 'excluded', 'pending']) >= 0,
        'Unsupported review disposition for ' + LKey);
      Require((LFields[3] <> 'access_only') or (LFields[2] = 'pending'),
        'An access-only receipt requires pending role for ' + LKey);
      LFields[3] := CanonicalBasis(LFields[3]);
      // Normalize the emitted copy, never the caller's original proposal file.
      LProposals[LIndex] := ReviewLine(LFields);
      if (LFields[2] = 'pending') or (LDepth < Depth('abstract')) then
      begin
        LResidue.Add(LQueue[LQueuedRow]);
      end;

      LLocator := APacket + '/dispositions.tsv#L' + IntToStr(LIndex + 1);
      LReplacement := LKey + #9 + LFields[2] + #9 + LFields[3] + #9 + LLocator + #9 + LFields[5];
      if not LExisting.Find(LKey, LPosition) then
      begin
        LCurrent.Add(LReplacement);
        Inc(LNew);
        Continue;
      end;

      LPriorRow := PtrInt(LExisting.Objects[LPosition]);
      LPrior := SplitFields(LCurrent[LPriorRow], #9);
      LPriorDepth := Depth(LPrior[3]);
      Require((LPriorDepth >= 0) and
        (((LPrior[2] = 'pending') and (LDepth >= LPriorDepth)) or
        ((IndexStr(LPrior[2], ['related', 'excluded']) >= 0) and
        (LPriorDepth = Depth('title_and_index')) and (LDepth >= Depth('abstract')))),
        'Intake does not replace settled or deeper reviews for ' + LKey);
      if (LDepth > LPriorDepth) or (LFields[2] <> LPrior[2]) then
      begin
        LCurrent[LPriorRow] := LReplacement;
        Inc(LUpgraded);
      end
      else
      begin
        if LPrior[3] <> CanonicalBasis(LPrior[3]) then
        begin
          LPrior[3] := CanonicalBasis(LPrior[3]);
          LCurrent[LPriorRow] := ReviewLine(LPrior);
        end;
        Inc(LRetained);
      end;
    end;

    LCurrent.LineBreak := #10;
    LProposals.LineBreak := #10;
    LSelected.LineBreak := #10;
    LResidue.LineBreak := #10;
    LProposals.SaveToFile(APacket + '/dispositions.tsv', TEncoding.UTF8);
    LSelected.SaveToFile(APacket + '/pinned-scope.tsv', TEncoding.UTF8);
    LResidue.SaveToFile(APacket + '/open-cluster-pairs.tsv', TEncoding.UTF8);
    LCurrent.SaveToFile(AStaged, TEncoding.UTF8);
    WriteLn(LSelected.Count - 1, ' checked; ', LResidue.Count - 1, ' still queued.');
    WriteLn(LNew, ' new; ', LUpgraded, ' upgraded; ', LRetained,
      ' prior ledger rows retained. Total ', LCurrent.Count - 1, '.');
  finally
    LExisting.Free;
    LResidue.Free;
    LSelected.Free;
    LOpen.Free;
    LProposals.Free;
    LCurrent.Free;
    LQueue.Free;
  end;
end;

begin
  try
    SetMultiByteConversionCodePage(CP_UTF8);
    Require(ParamCount = 5, 'Pass queue, current ledger, proposals, packet and staged ledger paths.');
    Require(not SameFileName(ExpandFileName(ParamStr(2)), ExpandFileName(ParamStr(5))),
      'Choose a staged ledger path distinct from the current ledger.');
    Require((ExtractFileDrive(ParamStr(4)) = '') and not StartsStr('/', ParamStr(4)) and
      not StartsStr('\', ParamStr(4)) and not ContainsStr(ParamStr(4), '..') and
      DirectoryExists(ParamStr(4)), 'Pass a repo-relative packet directory.');
    Reconcile(ParamStr(1), ParamStr(2), ParamStr(3),
      StringReplace(ExcludeTrailingPathDelimiter(ParamStr(4)), '\', '/', [rfReplaceAll]), ParamStr(5));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
