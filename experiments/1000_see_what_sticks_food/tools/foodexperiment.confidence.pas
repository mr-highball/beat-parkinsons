{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.confidence;

{$mode delphi}
{$H+}

interface

function ReadReviewConfidence(const AText, AVerdict, AClaimId: String): Currency;
function ReviewConfidenceText(AValue: Currency): String;

implementation

uses SysUtils;

function ConfidenceFormat: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
  Result.ThousandSeparator := #0;
end;

function ReadReviewConfidence(const AText, AVerdict, AClaimId: String): Currency;
var
  LPoint: Integer;
  LIndex: Integer;
begin
  LPoint := Pos('.', AText);
  if (AText = '') or ((LPoint > 0) and
    ((LPoint = 1) or not (Length(AText) - LPoint in [1..4]))) then
    raise EConvertError.Create('Invalid confidence decimal for ' + AClaimId);
  for LIndex := 1 to Length(AText) do
  begin
    if (LIndex <> LPoint) and not (AText[LIndex] in ['0'..'9']) then
      raise EConvertError.Create('Invalid confidence decimal for ' + AClaimId);
  end;
  if not TryStrToCurr(AText, Result, ConfidenceFormat) or
    (Result < 50) or (Result > 100) then
    raise EConvertError.Create('Confidence must be between 50 and 100: ' + AClaimId);

  if AVerdict = 'Unknown' then
  begin
    if Result <> 50 then
      raise EConvertError.Create('Unknown requires 50 confidence: ' + AClaimId);
  end
  else if (AVerdict = 'Maybe True') or (AVerdict = 'Maybe False') then
  begin
    if (Result <= 50) or (Result >= 60) then
      raise EConvertError.Create('Maybe verdict requires confidence above 50 and below 60: ' + AClaimId);
  end
  else if (AVerdict = 'True') or (AVerdict = 'False') then
  begin
    if Result < 60 then
      raise EConvertError.Create('Definitive verdict requires at least 60: ' + AClaimId);
  end
  else
    raise EConvertError.Create('Invalid verdict for ' + AClaimId);
end;

function ReviewConfidenceText(AValue: Currency): String;
begin
  Result := CurrToStr(AValue, ConfidenceFormat);
end;

end.
