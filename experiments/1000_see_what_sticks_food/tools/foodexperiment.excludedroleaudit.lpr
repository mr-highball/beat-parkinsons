{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program AuditExcluded;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, StrUtils, foodexperiment.externaldata;

type
  TGroup = class
    Key: String;
    Total: Integer;
    Flagged: Integer;
    Reviewed: Integer;
  end;

function NewIndex: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.CaseSensitive := True;
  Result.Duplicates := dupError;
end;

procedure Require(ACondition: Boolean; const AMessage: String);
begin
  if not ACondition then
  begin
    raise EConvertError.Create(AMessage);
  end;
end;

function AnyText(const AText: String; const ATerms: array of String): Boolean;
var
  LTerm: String;
begin
  Result := False;
  for LTerm in ATerms do
  begin
    if ContainsText(AText, LTerm) then
    begin
      Exit(True);
    end;
  end;
end;

procedure AppendFlag(var AFlags: String; const AFlag: String);
begin
  if AFlags <> '' then
  begin
    AFlags := AFlags + ';';
  end;
  AFlags := AFlags + AFlag;
end;

procedure AddGroup(const AGroups: TStringList; const AKey: String;
  AFlagged, AReviewed: Boolean);
var
  LPosition: Integer;
  LGroup: TGroup;
begin
  if AGroups.Find(AKey, LPosition) then
  begin
    LGroup := TGroup(AGroups.Objects[LPosition]);
  end
  else
  begin
    LGroup := TGroup.Create;
    LGroup.Key := AKey;
    AGroups.AddObject(AKey, LGroup);
  end;
  Inc(LGroup.Total);
  if AFlagged then
  begin
    Inc(LGroup.Flagged);
  end;
  if AReviewed then
  begin
    Inc(LGroup.Reviewed);
  end;
end;

procedure SaveGroups(const AGroups: TStringList; const APath: String;
  const AHeader: String);
var
  LOutput: TStringList;
  LOrder: TStringList;
  LGroup: TGroup;
  LIndex: Integer;
  LFields: TFields;
begin
  LOutput := TStringList.Create;
  LOrder := NewIndex;
  try
    LOutput.Add(AHeader + #9'excluded_pairs'#9'flagged_pairs'#9'reviewed_pairs');
    for LIndex := 0 to AGroups.Count - 1 do
    begin
      LGroup := TGroup(AGroups.Objects[LIndex]);
      LOrder.Add(Format('%.9d', [100000000 - LGroup.Flagged]) + #9 +
        LGroup.Key + #9 + IntToStr(LIndex));
    end;
    for LIndex := 0 to LOrder.Count - 1 do
    begin
      LFields := SplitFields(LOrder[LIndex], #9);
      LGroup := TGroup(AGroups.Objects[StrToInt(LFields[High(LFields)])]);
      LOutput.Add(LGroup.Key + #9 + IntToStr(LGroup.Total) + #9 +
        IntToStr(LGroup.Flagged) + #9 + IntToStr(LGroup.Reviewed));
    end;
    LOutput.LineBreak := #10;
    LOutput.SaveToFile(APath, TEncoding.UTF8);
  finally
    LOutput.Free;
    LOrder.Free;
  end;
end;

procedure Run;
var
  LFreeze: TStringList;
  LLedger: TStringList;
  LReviews: TStringList;
  LClaims: TStringList;
  LKeys: TStringList;
  LReviewed: TStringList;
  LGroups: TStringList;
  LSources: TStringList;
  LSorted: TStringList;
  LInventory: TStringList;
  LResume: TStringList;
  LCandidates: TStringList;
  LFields: TFields;
  LClaim: TFields;
  LProof: TFields;
  LKey: String;
  LFlags: String;
  LState: String;
  LLine: String;
  LOutputDirectory: String;
  LIndex: Integer;
  LPosition: Integer;
  LReviewPosition: Integer;
  LPriority: Integer;
  LExcluded: Integer;
  LRelated: Integer;
  LPending: Integer;
  LFlagged: Integer;
  LReviewedExcluded: Integer;
  LAlreadyAdopted: Integer;
  LFood: Boolean;
  LDerived: Boolean;
  LSensory: Boolean;
  LVehicle: Boolean;
  LCollision: Boolean;
  LWasReviewed: Boolean;
begin
  Require(ParamCount in [3, 4], 'Pass freeze, ledger, output directory, [reviewed six-column rows].');
  LOutputDirectory := ExcludeTrailingPathDelimiter(ParamStr(3));
  Require(DirectoryExists(LOutputDirectory), 'Output directory does not exist');
  LFreeze := TStringList.Create;
  LLedger := TStringList.Create;
  LReviews := TStringList.Create;
  LClaims := NewIndex;
  LKeys := NewIndex;
  LReviewed := NewIndex;
  LGroups := NewIndex;
  LSources := NewIndex;
  LSorted := NewIndex;
  LInventory := TStringList.Create;
  LResume := TStringList.Create;
  LCandidates := TStringList.Create;
  try
    LFreeze.LoadFromFile(ParamStr(1), TEncoding.UTF8);
    LLedger.LoadFromFile(ParamStr(2), TEncoding.UTF8);
    Require((LFreeze.Count = 1001) and StartsStr('id'#9'category'#9, LFreeze[0]),
      'Invalid 1000-claim freeze');
    Require((LLedger.Count > 1) and (LLedger[0] =
      'id'#9'source_key'#9'result_role'#9'review_basis'#9'local_reference'#9'rationale'),
      'Invalid exact review header');
    for LIndex := 1 to LFreeze.Count - 1 do
    begin
      LFields := SplitFields(LFreeze[LIndex], #9);
      Require((Length(LFields) = 7) and (Length(LFields[0]) = 4), 'Malformed frozen row');
      LClaims.AddObject(LFields[0], TObject(PtrInt(LIndex)));
    end;
    if ParamCount = 4 then
    begin
      LReviews.LoadFromFile(ParamStr(4), TEncoding.UTF8);
      Require((LReviews.Count > 0) and (LReviews[0] = LLedger[0]), 'Invalid reviewed header');
      for LIndex := 1 to LReviews.Count - 1 do
      begin
        LFields := SplitFields(LReviews[LIndex], #9);
        Require((Length(LFields) = 6) and (LClaims.IndexOf(LFields[0]) >= 0),
          'Malformed reviewed row');
        Require((IndexStr(LFields[2], ['related', 'excluded']) >= 0) and
          (LFields[4] <> '') and (LFields[5] <> ''), 'Unverified review shape');
        LReviewed.AddObject(LFields[0] + #9 + LFields[1], TObject(PtrInt(LIndex)));
      end;
    end;
    LExcluded := 0;
    LRelated := 0;
    LPending := 0;
    LFlagged := 0;
    LReviewedExcluded := 0;
    LAlreadyAdopted := 0;
    for LIndex := 1 to LLedger.Count - 1 do
    begin
      LFields := SplitFields(LLedger[LIndex], #9);
      Require((Length(LFields) = 6) and LClaims.Find(LFields[0], LPosition),
        'Malformed or unknown-claim exact row ' + IntToStr(LIndex + 1));
      LKey := LFields[0] + #9 + LFields[1];
      LKeys.Add(LKey);
      LWasReviewed := LReviewed.Find(LKey, LReviewPosition);
      if LWasReviewed then
      begin
        LProof := SplitFields(LReviews[PtrInt(LReviewed.Objects[LReviewPosition])], #9);
        if LFields[2] = 'related' then
        begin
          Require((LProof[2] = 'related') and
            (LLedger[LIndex] = LReviews[PtrInt(LReviewed.Objects[LReviewPosition])]),
            'Adopted related row differs from reviewed proof');
          Inc(LAlreadyAdopted);
        end
        else
        begin
          Require((LFields[2] = 'excluded') and (LProof[3] = LFields[3]),
            'Reviewed key is pending or its evidence basis changed');
          // Unapplied related proposals remain valid for an older excluded snapshot.
          if LProof[2] = 'excluded' then
          begin
            Require(LLedger[LIndex] = LReviews[PtrInt(LReviewed.Objects[LReviewPosition])],
              'Retained exclusion differs from reviewed proof');
          end;
          Inc(LReviewedExcluded);
        end;
      end;
      if LFields[2] = 'related' then
      begin
        Inc(LRelated);
        Continue;
      end;
      if LFields[2] = 'pending' then
      begin
        Inc(LPending);
        Continue;
      end;
      Require(LFields[2] = 'excluded', 'Unsupported original role');
      Inc(LExcluded);
      LClaim := SplitFields(LFreeze[PtrInt(LClaims.Objects[LPosition])], #9);
      LFood := AnyText(LFields[5], ['mixed meal', 'meal', 'dietary', ' fed ', 'feeding',
        'oral ', 'orally', 'ingest', 'consum', 'supplement', 'food intake']);
      LDerived := AnyText(LFields[5], ['extract', 'constituent', 'essential oil',
        'compound', 'polyphenol', 'hydroxytyrosol', 'apigenin', 'anethole', 'curcumin',
        'caffeine', 'capsaicin', 'flavonoid', 'lectin']);
      LSensory := AnyText(LFields[5], ['odor', 'odour', 'aroma', 'flavor', 'flavour',
        'taste', 'scent']);
      LVehicle := AnyText(LFields[5], ['vehicle', 'carrier']);
      LCollision := AnyText(LFields[5], ['author', 'surname', 'calendar', 'publisher',
        'brand', 'staining', 'fluorescen', 'reporter', 'image color', 'image colour',
        'figure', 'software', 'technical label', 'place name', 'reagent']);
      LFlags := '';
      if LFood then
      begin
        AppendFlag(LFlags, 'food_or_oral_language');
      end;
      if LDerived then
      begin
        AppendFlag(LFlags, 'derived_or_constituent_language');
      end;
      if LSensory then
      begin
        AppendFlag(LFlags, 'sensory_language');
      end;
      if LVehicle then
      begin
        AppendFlag(LFlags, 'vehicle_or_carrier_language');
      end;
      if LFlags <> '' then
      begin
        Inc(LFlagged);
      end;
      LPriority := 5;
      if LFlags <> '' then
      begin
        LPriority := 3;
        if not LCollision then
        begin
          LPriority := 2;
          if LFood or LSensory then
          begin
            LPriority := 1;
          end;
        end;
      end;
      if LWasReviewed then
      begin
        LState := 'independently_rechecked';
      end
      else
      begin
        LState := 'unreviewed_role_consistency';
      end;
      AddGroup(LGroups, LFields[1] + #9 + LClaim[2], LFlags <> '', LWasReviewed);
      AddGroup(LSources, LFields[1], LFlags <> '', LWasReviewed);
      LLine := LLedger[LIndex] + #9 + LClaim[2] + #9 + LClaim[3] + #9 +
        LClaim[4] + #9 + LFlags + #9 + BoolToStr(LCollision, True) + #9 + LState +
        #9 + IntToStr(LPriority);
      LSorted.AddObject(IntToStr(LPriority) + #9 + LFields[1] + #9 + LClaim[2] +
        #9 + LFields[0], TObject(PtrInt(LInventory.Count + 1)));
      LInventory.Add(LLine);
    end;
    for LIndex := 0 to LReviewed.Count - 1 do
    begin
      Require(LKeys.IndexOf(LReviewed[LIndex]) >= 0, 'Reviewed key is absent from baseline');
    end;
    Require(LReviewedExcluded + LAlreadyAdopted = LReviewed.Count,
      'Reviewed proof counts do not reconcile');
    Require(LExcluded + LRelated + LPending = LLedger.Count - 1,
      'Role counts do not reconcile');
    LLine := LLedger[0] + #9'ingredient'#9'preparation'#9'symptom'#9'screen_flags'#9 +
      'collision_hint'#9'audit_state'#9'screen_priority';
    LResume.Add(LLine);
    LCandidates.Add(LLine);
    LReviews.Clear;
    LReviews.Add(LLine);
    for LIndex := 0 to LSorted.Count - 1 do
    begin
      LLine := LInventory[PtrInt(LSorted.Objects[LIndex]) - 1];
      LReviews.Add(LLine);
      if ContainsText(LLine, #9'unreviewed_role_consistency'#9) then
      begin
        LResume.Add(LLine);
        LFields := SplitFields(LLine, #9);
        if LFields[9] <> '' then
        begin
          LCandidates.Add(LLine);
        end;
      end;
    end;
    Require(LReviews.Count - LResume.Count = LReviewedExcluded,
      'Reviewed excluded inventory does not reconcile');
    LReviews.LineBreak := #10;
    LResume.LineBreak := #10;
    LCandidates.LineBreak := #10;
    LReviews.SaveToFile(LOutputDirectory + '/all-excluded-inventory.tsv', TEncoding.UTF8);
    LResume.SaveToFile(LOutputDirectory + '/all-unreviewed-excluded.tsv', TEncoding.UTF8);
    LCandidates.SaveToFile(LOutputDirectory + '/flagged-unreviewed-candidates.tsv', TEncoding.UTF8);
    SaveGroups(LGroups, LOutputDirectory + '/source-ingredient-groups.tsv',
      'source_key'#9'ingredient');
    SaveGroups(LSources, LOutputDirectory + '/source-groups.tsv', 'source_key');
    WriteLn('ledger_rows=', LLedger.Count - 1);
    WriteLn('excluded=', LExcluded, ' related=', LRelated, ' pending=', LPending);
    WriteLn('excluded_sources=', LSources.Count, ' source_ingredient_groups=', LGroups.Count);
    WriteLn('flagged_excluded=', LFlagged, ' unflagged_excluded=', LExcluded - LFlagged);
    WriteLn('independently_rechecked=', LReviews.Count - LResume.Count);
    WriteLn('already_adopted_related=', LAlreadyAdopted,
      ' reviewed_proofs=', LReviewed.Count);
    WriteLn('remaining_all_excluded=', LResume.Count - 1,
      ' remaining_flagged=', LCandidates.Count - 1);
  finally
    for LIndex := 0 to LGroups.Count - 1 do
    begin
      LGroups.Objects[LIndex].Free;
    end;
    for LIndex := 0 to LSources.Count - 1 do
    begin
      LSources.Objects[LIndex].Free;
    end;
    LFreeze.Free;
    LLedger.Free;
    LReviews.Free;
    LClaims.Free;
    LKeys.Free;
    LReviewed.Free;
    LGroups.Free;
    LSources.Free;
    LSorted.Free;
    LInventory.Free;
    LResume.Free;
    LCandidates.Free;
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
