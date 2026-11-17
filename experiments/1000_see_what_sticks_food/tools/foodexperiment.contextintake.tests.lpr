{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
program TestContextIntake;

{$mode delphi}{$H+}{$codepage utf8}

uses
  Classes, SysUtils, StrUtils, Process, foodexperiment.externaldata;

const
  CHeader = 'id'#9'source_key'#9'result_role'#9'review_basis'#9'local_reference'#9'rationale';
  CQueueHeader = 'priority'#9'reason'#9'id'#9'source_key'#9'fixture_extra';
  CQueueRows = '5'#9'fixture'#9'0001'#9'PMID:1'#10'5'#9'fixture'#9'0002'#9'PMID:2';
  CStable = '0009'#9'PMID:9'#9'excluded'#9'full_text'#9'https://example.org/prior'#9 +
    'Unselected full-text review remains unchanged.';
  CRationale: UTF8String = 'Verified source context café 日本語.';

var
  GExecutable: String;
  GDirectory: String;
  GPassed: Integer;

function Review(const ARole, ABasis: String; AId: Integer = 1): UTF8String;
begin
  Result := UTF8String(Format('%.4d'#9'PMID:%d'#9'%s'#9'%s'#9 +
    'https://example.org/original'#9, [AId, AId, ARole, ABasis])) + CRationale;
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

procedure Check(const AName: String; const APrior, AProposals: UTF8String;
  APass: Boolean; const ABasis: String; AResidue, AUpgraded: Integer;
  const AQueueRows: UTF8String = CQueueRows);
var
  LDirectory: String;
  LPacket: String;
  LCurrent: UTF8String;
  LOriginalProposals: UTF8String;
  LProcess: TProcess;
  LOutput: TStringStream;
  LBuffer: array[0..1023] of Byte;
  LRead: Integer;
  LStatus: Integer;
  LRows: TStringList;
  LFields: TFields;
  LIndex: Integer;
  LFound: Boolean;
begin
  LDirectory := GDirectory + '/' + AName;
  LPacket := LDirectory + '/packet';
  ForceDirectories(LPacket);
  LCurrent := CHeader + #10 + CStable;
  if APrior <> '' then
  begin
    LCurrent := LCurrent + #10 + APrior;
  end;
  LOriginalProposals := CHeader + #10 + AProposals;
  Put(LDirectory + '/queue.tsv', CQueueHeader + #10 + AQueueRows);
  Put(LDirectory + '/current.tsv', LCurrent);
  Put(LDirectory + '/proposals.tsv', LOriginalProposals);
  LOutput := TStringStream.Create('');
  LProcess := TProcess.Create(nil);
  LRows := TStringList.Create;
  try
    LProcess.Executable := GExecutable;
    LProcess.Parameters.Add(LDirectory + '/queue.tsv');
    LProcess.Parameters.Add(LDirectory + '/current.tsv');
    LProcess.Parameters.Add(LDirectory + '/proposals.tsv');
    LProcess.Parameters.Add(LPacket);
    LProcess.Parameters.Add(LDirectory + '/staged.tsv');
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
    if (LStatus = 0) <> APass then
    begin
      raise Exception.Create(AName + ': unexpected result: ' + LOutput.DataString);
    end;
    if (Get(LDirectory + '/current.tsv') <> LCurrent) or
      (Get(LDirectory + '/proposals.tsv') <> LOriginalProposals) then
    begin
      raise Exception.Create(AName + ': input changed');
    end;
    if APass then
    begin
      if (Pos(IntToStr(AResidue) + ' still queued.', LOutput.DataString) = 0) or
        (Pos(IntToStr(AUpgraded) + ' upgraded;', LOutput.DataString) = 0) then
      begin
        raise Exception.Create(AName + ': unexpected residue/upgrade counts');
      end;
      LRows.LoadFromFile(LDirectory + '/staged.tsv', TEncoding.UTF8);
      if LRows[1] <> CStable then
      begin
        raise Exception.Create(AName + ': unselected full-text review changed');
      end;
      LFound := False;
      for LIndex := 1 to LRows.Count - 1 do
      begin
        LFields := SplitFields(LRows[LIndex], #9);
        // Contract from the independent contextqueue.LoadExactReviews consumer.
        if IndexStr(LFields[3], ['access_only', 'title_and_index', 'abstract',
          'assessment_unspecified', 'full_text', 'primary_source']) < 0 then
        begin
          raise Exception.Create(AName + ': consumer-incompatible ledger basis');
        end;
        if LFields[0] = '0001' then
        begin
          LFound := True;
          if LFields[3] <> ABasis then
          begin
            raise Exception.Create(AName + ': unexpected target basis');
          end;
          if UTF8String(LFields[5]) <> CRationale then
          begin
            raise Exception.Create(AName + ': UTF-8 rationale changed');
          end;
        end;
      end;
      if not LFound then
      begin
        raise Exception.Create(AName + ': target missing');
      end;
      LRows.LoadFromFile(LPacket + '/dispositions.tsv', TEncoding.UTF8);
      for LIndex := 1 to LRows.Count - 1 do
      begin
        LFields := SplitFields(LRows[LIndex], #9);
        if IndexStr(LFields[3], ['access_only', 'title_and_index', 'abstract',
          'full_text']) < 0 then
        begin
          raise Exception.Create(AName + ': noncanonical emitted basis');
        end;
      end;
      LRows.LoadFromFile(LPacket + '/open-cluster-pairs.tsv', TEncoding.UTF8);
      if LRows.Count - 1 <> AResidue then
      begin
        raise Exception.Create(AName + ': residue file count differs');
      end;
    end
    else if FileExists(LDirectory + '/staged.tsv') or
      FileExists(LPacket + '/dispositions.tsv') then
    begin
      raise Exception.Create(AName + ': rejected intake wrote output');
    end;
    Inc(GPassed);
    WriteLn(AName, #9, 'PASS', #9, LStatus);
  finally
    LRows.Free;
    LProcess.Free;
    LOutput.Free;
  end;
end;

begin
  DefaultSystemCodePage := CP_UTF8;
  if ParamCount <> 2 then
  begin
    Halt(2);
  end;
  GExecutable := ExpandFileName(ParamStr(1));
  GDirectory := StringReplace(ExcludeTrailingPathDelimiter(ParamStr(2)), '\', '/', [rfReplaceAll]);
  if (ExtractFileDrive(GDirectory) <> '') or AnsiStartsStr('/', GDirectory) then
  begin
    raise Exception.Create('Pass a fresh repo-relative build fixture directory.');
  end;
  if DirectoryExists(GDirectory) then
  begin
    raise Exception.Create('Fixture directory already exists.');
  end;
  GPassed := 0;
  Check('new_title_alias', '', Review('excluded', 'title'), True, 'title_and_index', 1, 0);
  Check('new_canonical_title', '', Review('related', 'title_and_index'), True,
    'title_and_index', 1, 0);
  Check('new_full_basis_unchanged', '', Review('related', 'full_text'), True, 'full_text', 0, 0);
  Check('pending_access_to_abstract', Review('pending', 'access_only'),
    Review('excluded', 'abstract'), True, 'abstract', 0, 1);
  Check('pending_abstract_to_pending_body', Review('pending', 'abstract'),
    Review('pending', 'full_text'), True, 'full_text', 1, 1);
  Check('related_title_to_abstract', Review('related', 'title_and_index'),
    Review('related', 'abstract'), True, 'abstract', 0, 1);
  Check('excluded_title_alias_to_full', Review('excluded', 'title'),
    Review('related', 'full_text'), True, 'full_text', 0, 1);
  Check('title_to_deeper_pending', Review('excluded', 'title_and_index'),
    Review('pending', 'abstract'), True, 'abstract', 1, 1);
  Check('retained_pending_alias_normalized', Review('pending', 'title'),
    Review('pending', 'title'), True, 'title_and_index', 1, 0);
  Check('settled_title_same_depth_rejected', Review('related', 'title_and_index'),
    Review('excluded', 'title'), False, '', 0, 0);
  Check('settled_abstract_to_full_rejected', Review('related', 'abstract'),
    Review('related', 'full_text'), False, '', 0, 0);
  Check('stale_queue_settled_body_rejected', Review('excluded', 'full_text'),
    Review('related', 'full_text'), False, '', 0, 0);
  Check('pending_downgrade_rejected', Review('pending', 'full_text'),
    Review('pending', 'abstract'), False, '', 0, 0);
  Check('out_of_queue_rejected', '', Review('related', 'full_text', 3), False, '', 0, 0);
  Check('duplicate_proposal_rejected', '', Review('related', 'full_text') + #10 +
    Review('related', 'full_text'), False, '', 0, 0);
  Check('duplicate_current_rejected', Review('pending', 'title') + #10 +
    Review('pending', 'title'), Review('related', 'full_text'), False, '', 0, 0);
  Check('duplicate_queue_rejected', '', Review('related', 'full_text'), False, '', 0, 0,
    CQueueRows + #10'5'#9'fixture'#9'0001'#9'PMID:1');
  Check('nonpending_access_only_rejected', '', Review('excluded', 'access_only'), False, '', 0, 0);
  Check('unknown_basis_rejected', '', Review('excluded', 'title only'), False, '', 0, 0);
  Check('mixed_title_body_residue', '', Review('excluded', 'title') + #10 +
    Review('related', 'full_text', 2), True, 'title_and_index', 1, 0);
  WriteLn('passed=', GPassed, ' total=20');
end.
