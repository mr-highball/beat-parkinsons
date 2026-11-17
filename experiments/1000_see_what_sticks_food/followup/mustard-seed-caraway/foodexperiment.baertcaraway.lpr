{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program foodexperiment.baertcaraway;
{$mode delphi}
{$H+}

uses
  Classes, DOM, SysUtils, XMLRead;

function CellValue(ACell: TDOMNode; AStrings: TStrings): String;
var
  LValue: TDOMNode;
begin
  LValue := ACell.FindNode('v');
  if LValue = nil then
  begin
    Exit('');
  end;
  Result := UTF8Encode(LValue.TextContent);
  if TDOMElement(ACell).GetAttribute('t') = 's' then
  begin
    Result := AStrings[StrToInt(Result)];
  end;
end;

procedure CountRecognition(const ADirectory, AStimulus: String);
var
  LDocument: TXMLDocument;
  LItem: TDOMNode;
  LRow: TDOMNode;
  LCell: TDOMNode;
  LData: TDOMNode;
  LStrings: TStringList;
  LGroup: Integer;
  LRowIndex: Integer;
  LCorrect: Integer;
  LTotals: array[0..1] of Integer;
  LRecognized: array[0..1] of Integer;
begin
  FillChar(LTotals, SizeOf(LTotals), 0);
  FillChar(LRecognized, SizeOf(LRecognized), 0);
  LStrings := TStringList.Create;
  try
    ReadXMLFile(LDocument, ADirectory + '/sharedStrings.xml');
    try
      LItem := LDocument.DocumentElement.FirstChild;
      while LItem <> nil do
      begin
        if LItem.NodeName = 'si' then
        begin
          LStrings.Add(UTF8Encode(LItem.TextContent));
        end;
        LItem := LItem.NextSibling;
      end;
    finally
      LDocument.Free;
    end;
    ReadXMLFile(LDocument, ADirectory + '/worksheets/sheet4.xml');
    try
      LData := LDocument.DocumentElement.FindNode('sheetData');
      if LData = nil then
      begin
        raise EConvertError.Create('No sheetData in Kruidengeuren sheet');
      end;
      LRow := LData.FirstChild;
      if LRow = nil then
      begin
        raise EConvertError.Create('Empty Kruidengeuren sheet');
      end;
      LRow := LRow.NextSibling;
      while LRow <> nil do
      begin
        LRowIndex := StrToInt(UTF8Encode(TDOMElement(LRow).GetAttribute('r')));
        LCell := LRow.FirstChild;
        if (LCell = nil) or (CellValue(LCell, LStrings) = '') then
        begin
          LRow := LRow.NextSibling;
          Continue;
        end;
        LCell := LCell.NextSibling;
        if (LCell = nil) or
          (UTF8Encode(TDOMElement(LCell).GetAttribute('r')) <> 'B' + IntToStr(LRowIndex)) then
        begin
          raise EConvertError.CreateFmt('Missing PD status in row %d', [LRowIndex]);
        end;
        LGroup := StrToInt(CellValue(LCell, LStrings));
        Inc(LTotals[LGroup]);
        LCorrect := 0;
        while LCell <> nil do
        begin
          if SameText(Trim(CellValue(LCell, LStrings)), AStimulus) and
            (LCell.NextSibling <> nil) and (CellValue(LCell.NextSibling, LStrings) = '1') then
          begin
            Inc(LCorrect);
          end;
          LCell := LCell.NextSibling;
        end;
        if LCorrect > 1 then
        begin
          raise EConvertError.Create('Multiple correct responses for one stimulus and participant');
        end;
        Inc(LRecognized[LGroup], LCorrect);
        LRow := LRow.NextSibling;
      end;
    finally
      LDocument.Free;
    end;
  finally
    LStrings.Free;
  end;
  WriteLn('Control', #9, LRecognized[0], #9, LTotals[0]);
  WriteLn('Parkinson', #9, LRecognized[1], #9, LTotals[1]);
end;

begin
  case ParamCount of
    1:
      CountRecognition(ParamStr(1), 'Karwij');
    2:
      CountRecognition(ParamStr(1), ParamStr(2));
  else
    raise EArgumentException.Create('Expected extracted xl directory and optional stimulus label');
  end;
end.
