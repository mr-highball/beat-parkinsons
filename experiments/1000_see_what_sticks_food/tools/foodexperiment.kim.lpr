{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program FoodExperimentKim;

{$mode delphi}
{$H+}

uses
  Classes, SysUtils, StrUtils, Math, bufstream, csvdocument, md5, foodexperiment.kimmodel;

const
  Predictors: array[0..14] of String = (
    'Acetic.Acid.mmol.per.kg', 'Propionic.Acid.mmol.per.kg', 'Isobutyric.Acid.mmol.per.kg',
    'Butyric.Acid.mmol.per.kg', 'Isovaleric.Acid.mmol.per.kg', 'Valeric.Acid.mmol.per.kg',
    'Hexanoic.Acid.mmol.per.kg', 'Isocaproic.acid.mmol.per.kg', 'Heptanoic.Acid.mmol.per.kg',
    'Total.SCFAs.mmol.per.kg', 'mds2.total', 'mds4.total', 'hIL1b', 'hIL8', 'Weight_Kg');
  Diets: array[0..1] of String = ('KETO', 'MCT');
  ExcludedSamples: array[0..10] of String = (
    'K008_V2_FF', 'K009_V2_FF', 'K011_V2_FF', 'K015_V2_FF', 'K024_V2_FF',
    'K025_V2_FF', 'K026_V2_FF', 'K031_V4_FF', 'K033_V2_FF', 'K034_V2_FF', 'K059_V1_FF');

type
  TSample = record
    Subject: String;
    ClinicalRow: Integer;
    Diet: Integer;
    Abundance: Double;
  end;

  TSamples = array of TSample;

function Column(AFile: TCSVDocument; const AName: String): Integer;
var
  I: Integer;
begin
  for I := 0 to AFile.ColCount[0] - 1 do
  begin
    if AFile.Cells[I, 0] = AName then
    begin
      Exit(I);
    end;
  end;
  raise EConvertError.Create('Missing column ' + AName);
end;

function ReadTable(const APath, AMD5: String; ADelimiter: Char = ','): TCSVDocument;
var
  LStream: TBufferedFileStream;
  I: Integer;
begin
  if MD5Print(MD5File(APath)) <> AMD5 then
  begin
    raise EInOutError.Create('Original release checksum mismatch: ' + APath);
  end;
  Result := TCSVDocument.Create;
  try
    Result.DetectBOM := True;
    Result.Delimiter := ADelimiter;
    LStream := TBufferedFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    try
      Result.LoadFromStream(LStream);
    finally
      LStream.Free;
    end;
    if Result.RowCount < 2 then
    begin
      raise EConvertError.Create('Empty release table: ' + APath);
    end;
    for I := 1 to Result.RowCount - 1 do
    begin
      if Result.ColCount[I] <> Result.ColCount[0] then
      begin
        raise EConvertError.CreateFmt('Inconsistent row width at %s row %d', [APath, I + 1]);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure LoadCountColumns(ACounts: TCSVDocument; AColumns: TStringList;
  out ATotal, ATarget: TArray<Int64>);
var
  LTaxonomy, LId, LTargetRows: Integer;
  LCount: Int64;
  LIsTarget: Boolean;
  I, J: Integer;
begin
  LTaxonomy := Column(ACounts, 'Consensus Lineage');
  LId := Column(ACounts, '#OTU ID');
  LTargetRows := 0;
  SetLength(ATotal, ACounts.ColCount[0]);
  SetLength(ATarget, Length(ATotal));
  for J := 0 to High(ATotal) do
  begin
    if (J <> LTaxonomy) and (J <> LId) then
    begin
      AColumns.AddObject(ACounts.Cells[J, 0], TObject(PtrInt(J)));
    end;
  end;
  for I := 1 to ACounts.RowCount - 1 do
  begin
    LIsTarget := Pos('g__Roseburia; s__hominis', ACounts.Cells[LTaxonomy, I]) > 0;
    if LIsTarget then
    begin
      Inc(LTargetRows);
    end;
    for J := 0 to High(ATotal) do
    begin
      if (J = LTaxonomy) or (J = LId) then
      begin
        Continue;
      end;
      LCount := StrToInt64(ACounts.Cells[J, I]);
      if LCount < 0 then
      begin
        raise EConvertError.Create('Negative taxonomic count');
      end;
      ATotal[J] := ATotal[J] + LCount;
      if LIsTarget then
      begin
        ATarget[J] := ATarget[J] + LCount;
      end;
    end;
  end;
  if LTargetRows <> 1 then
  begin
    raise EConvertError.CreateFmt('Expected one Roseburia hominis feature, found %d', [LTargetRows]);
  end;
end;

function ClinicalKey(const ASubject, AVisit, AAge, ASex: String): String;
begin
  Result := ASubject + '_V' + AVisit + '|' + AAge + '|' + ASex;
end;

function CollectSamples(AClinical, AMetadata, ANormalized, ACounts: TCSVDocument): TSamples;
var
  LCountColumns, LClinicalRows, LNormalizedIds: TStringList;
  LTotal, LTarget: TArray<Int64>;
  LId, LVisit, LAge, LSex, LSample, LSampleKey, LGroup, LFeature: Integer;
  LColumnIndex, LClinicalIndex, LCountsColumn, LKept: Integer;
  LKey, LSubjectVisit, LSampleId, LDiet: String;
  LExcluded: Boolean;
  I, J: Integer;
begin
  Result := nil;
  LCountColumns := TStringList.Create;
  LClinicalRows := TStringList.Create;
  LNormalizedIds := TStringList.Create;
  try
    LCountColumns.Sorted := True;
    LCountColumns.Duplicates := dupError;
    LClinicalRows.Sorted := True;
    LClinicalRows.Duplicates := dupError;
    LNormalizedIds.Sorted := True;
    LNormalizedIds.Duplicates := dupError;
    LoadCountColumns(ACounts, LCountColumns, LTotal, LTarget);
    LFeature := Column(ANormalized, 'feature');
    for I := 1 to ANormalized.RowCount - 1 do
    begin
      LNormalizedIds.Add(ANormalized.Cells[LFeature, I]);
    end;

    LId := Column(AClinical, 'record_id');
    LVisit := Column(AClinical, 'Visit_Num');
    LAge := Column(AClinical, 'Age');
    LSex := Column(AClinical, 'Sex');
    for I := 1 to AClinical.RowCount - 1 do
    begin
      LKey := ClinicalKey(AClinical.Cells[LId, I], AClinical.Cells[LVisit, I],
        AClinical.Cells[LAge, I], AClinical.Cells[LSex, I]);
      LClinicalRows.AddObject(LKey, TObject(PtrInt(I)));
    end;

    LSample := Column(AMetadata, 'MBI_Sample_ID');
    LSampleKey := Column(AMetadata, 'sample_ID');
    LGroup := Column(AMetadata, 'Group');
    LAge := Column(AMetadata, 'Age');
    LSex := Column(AMetadata, 'Sex');
    LKept := 0;
    SetLength(Result, AMetadata.RowCount - 1);
    for I := 1 to AMetadata.RowCount - 1 do
    begin
      LSampleId := AMetadata.Cells[LSampleKey, I];
      LExcluded := False;
      for J := Low(ExcludedSamples) to High(ExcludedSamples) do
      begin
        if LSampleId = ExcludedSamples[J] then
        begin
          LExcluded := True;
          Break;
        end;
      end;
      if LExcluded then
      begin
        Continue;
      end;
      LColumnIndex := LCountColumns.IndexOf(AMetadata.Cells[LSample, I]);
      if (LColumnIndex < 0) or (LNormalizedIds.IndexOf(LSampleId) < 0) then
      begin
        raise EConvertError.CreateFmt('Unmatched sequencing key at metadata row %d', [I + 1]);
      end;
      LCountsColumn := PtrInt(LCountColumns.Objects[LColumnIndex]);
      if LTotal[LCountsColumn] <= 0 then
      begin
        raise EConvertError.CreateFmt('No reads for metadata row %d', [I + 1]);
      end;
      LSubjectVisit := Copy(LSampleId, 1, LastDelimiter('_', LSampleId) - 1);
      LKey := LSubjectVisit + '|' + AMetadata.Cells[LAge, I] + '|' + AMetadata.Cells[LSex, I];
      LClinicalIndex := LClinicalRows.IndexOf(LKey);
      if LClinicalIndex < 0 then
      begin
        raise EConvertError.CreateFmt('Unmatched clinical key at metadata row %d', [I + 1]);
      end;
      LDiet := Copy(AMetadata.Cells[LGroup, I], 1, Pos('_', AMetadata.Cells[LGroup, I]) - 1);
      J := IndexStr(LDiet, Diets);
      if J < 0 then
      begin
        raise EConvertError.CreateFmt('Unrecognized diet at metadata row %d', [I + 1]);
      end;
      Result[LKept].Subject := Copy(LSubjectVisit, 1, Pos('_', LSubjectVisit) - 1);
      Result[LKept].ClinicalRow := PtrInt(LClinicalRows.Objects[LClinicalIndex]);
      Result[LKept].Diet := J;
      Result[LKept].Abundance := LTarget[LCountsColumn] / LTotal[LCountsColumn];
      Inc(LKept);
    end;
    SetLength(Result, LKept);
  finally
    LNormalizedIds.Free;
    LClinicalRows.Free;
    LCountColumns.Free;
  end;
end;

procedure PrintModels(AClinical: TCSVDocument; const ASamples: TSamples);
var
  LSubjects: TStringList;
  LData: array of TObservation;
  LFits: array[Low(Predictors)..High(Predictors)] of TModelFit;
  LP, LQ: array[Low(Predictors)..High(Predictors)] of Double;
  LRows, LSubjectCounts: array[Low(Predictors)..High(Predictors)] of Integer;
  LFormat: TFormatSettings;
  LSample: TSample;
  LMean, LDeviation, LNumber: Double;
  LValue: String;
  LColumn, LUsed, LSubject, LDiet, I: Integer;
begin
  if Length(ASamples) < 2 then
  begin
    raise EConvertError.Create('Fewer than two matched sequencing samples');
  end;
  LFormat := DefaultFormatSettings;
  LFormat.DecimalSeparator := '.';
  LMean := 0;
  LDeviation := 0;
  for LSample in ASamples do
  begin
    LMean := LMean + LSample.Abundance;
  end;
  LMean := LMean / Length(ASamples);
  for LSample in ASamples do
  begin
    LDeviation := LDeviation + Sqr(LSample.Abundance - LMean);
  end;
  LDeviation := Sqrt(LDeviation / (Length(ASamples) - 1));
  if LDeviation = 0 then
  begin
    raise EConvertError.Create('Roseburia hominis abundance has no variance');
  end;
  WriteLn('diet'#9'predictor'#9'observations'#9'participants'#9'estimate'#9'standard_error'#9,
    'random_to_residual_variance'#9'normal_wald_p'#9'bh_q_for_15_predictors');
  LSubjects := TStringList.Create;
  try
    for LDiet := Low(Diets) to High(Diets) do
    begin
      for I := Low(Predictors) to High(Predictors) do
      begin
        LSubjects.Clear;
        SetLength(LData, Length(ASamples));
        LUsed := 0;
        LColumn := Column(AClinical, Predictors[I]);
        for LSample in ASamples do
        begin
          if LSample.Diet <> LDiet then
          begin
            Continue;
          end;
          LValue := AClinical.Cells[LColumn, LSample.ClinicalRow];
          if (LValue = '') or (LValue = 'NA') then
          begin
            Continue;
          end;
          LNumber := StrToFloat(LValue, LFormat);
          LSubject := LSubjects.IndexOf(LSample.Subject);
          if LSubject < 0 then
          begin
            LSubject := LSubjects.Add(LSample.Subject);
          end;
          LData[LUsed].Subject := LSubject;
          LData[LUsed].Predictor := LNumber;
          LData[LUsed].Outcome := (LSample.Abundance - LMean) / LDeviation;
          Inc(LUsed);
        end;
        SetLength(LData, LUsed);
        LFits[I] := FitRandomIntercept(LData);
        LRows[I] := LUsed;
        LSubjectCounts[I] := LSubjects.Count;
        LP[I] := LFits[I].WaldP;
      end;
      AdjustFalseDiscoveryRate(LP, LQ);
      for I := Low(Predictors) to High(Predictors) do
      begin
        WriteLn(Format('%s'#9'%s'#9'%d'#9'%d'#9'%.9g'#9'%.9g'#9'%.9g'#9'%.9g'#9'%.9g',
          [Diets[LDiet], Predictors[I], LRows[I], LSubjectCounts[I], LFits[I].Estimate,
            LFits[I].StandardError, LFits[I].VarianceRatio, LP[I], LQ[I]], LFormat));
      end;
    end;
  finally
    LSubjects.Free;
  end;
end;

procedure Run(const ADirectory: String);
var
  LDirectory: String;
  LClinical, LMetadata, LNormalized, LCounts: TCSVDocument;
  LSamples: TSamples;
begin
  LDirectory := IncludeTrailingPathDelimiter(ADirectory);
  LClinical := nil;
  LMetadata := nil;
  LNormalized := nil;
  LCounts := nil;
  try
    LClinical := ReadTable(LDirectory + 'KIM_clinical-original.csv',
      'a19fab80df7c727d1ab99a15ec4fb575');
    LMetadata := ReadTable(LDirectory + 'KIM_metadata-original.csv',
      'b298eacedd67b06f96aeb9d2f5e949a0');
    LNormalized := ReadTable(LDirectory + 'KIM_normalized_abundance-original.tsv',
      '09e4638d51238f4c9a388c3bc2e7eda9', #9);
    LCounts := ReadTable(LDirectory + 'KIM_taxonomic_counts-original.csv',
      '523f1df89155a8f9166a2c01988a55f7');
    LSamples := CollectSamples(LClinical, LMetadata, LNormalized, LCounts);
    WriteLn(StdErr, Length(LSamples), ' sequencing samples in both diet strata');
    PrintModels(LClinical, LSamples);
  finally
    LCounts.Free;
    LNormalized.Free;
    LMetadata.Free;
    LClinical.Free;
  end;
end;

begin
  try
    if ParamCount <> 1 then
    begin
      raise EArgumentException.Create('Usage: foodexperiment.kim DATASET_DIRECTORY');
    end;
    Run(ParamStr(1));
  except
    on LException: Exception do
    begin
      WriteLn(StdErr, LException.Message);
      Halt(1);
    end;
  end;
end.
