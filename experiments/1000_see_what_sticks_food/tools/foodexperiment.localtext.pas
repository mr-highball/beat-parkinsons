{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.localtext;

{$mode delphi}
{$H+}

interface

uses
  Classes, SysUtils, foodexperiment.matching, foodexperiment.archiveidentity;

type
  TLocalArticle = class
  private
    FScanned: Boolean;
    FIdentityRead: Boolean;
    FIdentity: TArchiveIdentity;
  public
    Path: String;
    PmcId: String;
    Title: String;
    Subjects: String;
    Scope: String;
    Exposures: TMatchFlags;
    Outcomes: TMatchFlags;
  end;

  TLocalTextIndex = class
  private
    FRoot: String;
    FArticles: TStringList;
    FExposureMatcher: TMatcher;
    FOutcomeMatcher: TMatcher;
    FExposureCount: Integer;
    FOutcomeCount: Integer;
    procedure IndexBucket(const ABucket: String);
  public
    constructor Create(const ARepo: String; AExposureMatcher, AOutcomeMatcher: TMatcher;
      AExposureCount, AOutcomeCount: Integer);
    destructor Destroy; override;
    function Find(const APmcId: String): TLocalArticle;
    function IdentityOf(AArticle: TLocalArticle): TArchiveIdentity;
    function Count: Integer;
    function ArticleAt(AIndex: Integer): TLocalArticle;
  end;

implementation

uses
  StrUtils;

function HeaderField(const AText, APrefix: RawByteString): String;
var
  LStart: SizeInt;
  LEnd: SizeInt;
  LValue: RawByteString;
begin
  LStart := 1;
  if Copy(AText, 1, Length(APrefix)) <> APrefix then
  begin
    LStart := PosEx(#10 + APrefix, AText);
    if LStart = 0 then
    begin
      Exit('');
    end;
    Inc(LStart);
  end;
  Inc(LStart, Length(APrefix));
  LEnd := PosEx(#10, AText, LStart);
  if LEnd = 0 then
  begin
    LEnd := Length(AText) + 1;
  end;
  LValue := Trim(Copy(AText, LStart, LEnd - LStart));
  SetCodePage(LValue, CP_UTF8, False);
  Result := LValue;
end;

function IsBucket(const AName: String): Boolean;
var
  LFirst: Integer;
  LLast: Integer;
begin
  Result := (Length(AName) = 9) and (AName[5] = '-') and
    TryStrToInt(Copy(AName, 1, 4), LFirst) and TryStrToInt(Copy(AName, 6, 4), LLast)
    and (LLast - LFirst = 4);
end;

function ArticleText(const AText: RawByteString; out AScope: String): RawByteString;
var
  LStart: SizeInt;
  LLine: SizeInt;
  LNext: SizeInt;
  LHeading: RawByteString;
  LBodyStarted: Boolean;
begin
  AScope := 'no recognized body start';
  LStart := 1;
  LLine := 1;
  LBodyStarted := False;
  while LLine <= Length(AText) do
  begin
    LNext := PosEx(#10, AText, LLine);
    if LNext = 0 then
    begin
      LNext := Length(AText) + 1;
    end;
    if LNext - LLine <= 48 then
    begin
      LHeading := LowerCase(Trim(Copy(AText, LLine, LNext - LLine)));
      if not LBodyStarted and ((LHeading = 'abstract') or (LHeading = 'introduction') or
        (LHeading = 'summary') or (LHeading = 'background')) then
      begin
        LBodyStarted := True;
        LStart := LLine;
        AScope := 'body to end';
      end;
      if (LHeading = 'references') or (LHeading = 'bibliography') or
        (LHeading = 'literature cited') or (LHeading = 'works cited') then
      begin
        if LBodyStarted then
        begin
          AScope := 'body before references';
        end
        else
        begin
          AScope := 'text before references';
        end;
        Exit(Copy(AText, LStart, LLine - LStart));
      end;
    end;
    LLine := LNext + 1;
  end;
  Result := Copy(AText, LStart, MaxInt);
end;

constructor TLocalTextIndex.Create(const ARepo: String; AExposureMatcher, AOutcomeMatcher: TMatcher;
  AExposureCount, AOutcomeCount: Integer);
var
  LBucket: TSearchRec;
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(ARepo);
  FExposureMatcher := AExposureMatcher;
  FOutcomeMatcher := AOutcomeMatcher;
  FExposureCount := AExposureCount;
  FOutcomeCount := AOutcomeCount;
  FArticles := TStringList.Create;
  FArticles.OwnsObjects := True;
  FArticles.Sorted := True;
  FArticles.Duplicates := dupError;
  if FindFirst(FRoot + 'research' + PathDelim + '*', faDirectory, LBucket) = 0 then
  begin
    try
      repeat
        if ((LBucket.Attr and faDirectory) <> 0) and IsBucket(LBucket.Name) then
        begin
          IndexBucket(LBucket.Name);
        end;
      until FindNext(LBucket) <> 0;
    finally
      FindClose(LBucket);
    end;
  end;
  if FArticles.Count = 0 then
  begin
    raise EInOutError.Create('No chronological PMC article files found in ' + FRoot);
  end;
end;

destructor TLocalTextIndex.Destroy;
begin
  FArticles.Free;
  inherited Destroy;
end;

procedure TLocalTextIndex.IndexBucket(const ABucket: String);
var
  LArticle: TSearchRec;
  LRelativeDir: String;
  LDocument: TLocalArticle;
  LKey: String;
begin
  LRelativeDir := 'research/' + ABucket + '/Source-Text/';
  if FindFirst(FRoot + LRelativeDir + 'PMC*.txt', faAnyFile, LArticle) <> 0 then
  begin
    Exit;
  end;
  try
    repeat
      if (LArticle.Attr and faDirectory) <> 0 then
      begin
        Continue;
      end;
      LKey := ChangeFileExt(LArticle.Name, '');
      if FArticles.IndexOf(LKey) >= 0 then
      begin
        raise EConvertError.Create('Duplicate chronological text for ' + LKey);
      end;
      LDocument := TLocalArticle.Create;
      LDocument.Path := LRelativeDir + LArticle.Name;
      LDocument.PmcId := LKey;
      FArticles.AddObject(LKey, LDocument);
    until FindNext(LArticle) <> 0;
  finally
    FindClose(LArticle);
  end;
end;

function TLocalTextIndex.Find(const APmcId: String): TLocalArticle;
var
  LIndex: Integer;
begin
  LIndex := FArticles.IndexOf(APmcId);
  if LIndex < 0 then
  begin
    Exit(nil);
  end;
  Result := ArticleAt(LIndex);
end;

function TLocalTextIndex.IdentityOf(AArticle: TLocalArticle): TArchiveIdentity;
begin
  if not AArticle.FIdentityRead then
  begin
    AArticle.FIdentity := ReadArchiveIdentity(FRoot + AArticle.Path);
    AArticle.FIdentityRead := True;
  end;
  Result := AArticle.FIdentity;
end;

function TLocalTextIndex.Count: Integer;
begin
  Result := FArticles.Count;
end;

function TLocalTextIndex.ArticleAt(AIndex: Integer): TLocalArticle;
var
  LText: RawByteString;
  LBody: RawByteString;
begin
  Result := TLocalArticle(FArticles.Objects[AIndex]);
  if Result.FScanned then
  begin
    Exit;
  end;
  LText := ReadBytes(FRoot + Result.Path);
  Result.Title := HeaderField(LText, 'Title:');
  Result.Subjects := HeaderField(LText, 'Subjects:');
  LBody := ArticleText(LText, Result.Scope);
  SetLength(Result.Exposures, FExposureCount);
  SetLength(Result.Outcomes, FOutcomeCount);
  FExposureMatcher.Match(LBody, Result.Exposures);
  FOutcomeMatcher.Match(LBody, Result.Outcomes);
  Result.FScanned := True;
end;

end.
