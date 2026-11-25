{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclereader;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses
  SysUtils, JS, Web, nyx.model, nyx.types, nyx.modal, nyx.modal.browser,
  nyx.render.browser, oraclestatic;

type
  TReaderChunkReply = reference to procedure(const AText: String; ANextOffset: Integer;
    const AError: String);
  TReaderFetchChunk = reference to procedure(const APath: String; AOffset: Integer;
    AReply: TReaderChunkReply);
  TReaderConnectionsAction = reference to procedure(const APath: String);

  TOracleReaderModal = class
  private
    FStaticOracle: TStaticOracle;
    FFetchLocalChunk: TReaderFetchChunk;
    FOnConnections: TReaderConnectionsAction;
    FModalHost: INyxBrowserModalHost;
    FShellDoc: TNyxDocument;
    FShellRenderer: TNyxBrowserRenderer;
    FInvoker: TJSHTMLElement;
    FBackdropClick: TJSEventHandler;
    FCurrentPath: String;
    FTargetAnchor: String;
    FHistory: array of String;
    FLoadGeneration: Integer;
    FActiveRequest: TJSXMLHttpRequest;
    FCache: TJSObject;
    FLoadedText: String;
    FNextOffset: Integer;
    FLoading: Boolean;
    FLoadingMore: Boolean;
    FErrorText: String;
    procedure CancelActiveRequest;
    function OnBackdropClick(AEvent: TEventListenerEvent): Boolean;
    procedure MountShell;
    procedure UpdateHeader;
    procedure RenderBody;
    procedure LoadDocument(const APath, AAnchor: String; APushHistory: Boolean);
    procedure LoadViaRawGitHub(const APath: String; AGen: Integer);
    procedure LoadViaLocalChunks(const APath: String; AOffset, AChunksLeft, AGen: Integer);
    procedure LoadMoreLocal;
    procedure NavigateBack;
    procedure ScrollToAnchor(const AAnchor: String);
    function HasCachedText(const APath: String; out AText: String): Boolean;
    procedure PutCachedText(const APath, AText: String);
    procedure CleanupShell;
  public
    constructor Create(AStaticOracle: TStaticOracle; AFetchLocalChunk: TReaderFetchChunk;
      AOnConnections: TReaderConnectionsAction);
    destructor Destroy; override;
    procedure Open(const APath: String; AInvoker: TJSHTMLElement = nil);
    procedure Close;
    function IsOpen: Boolean;
  end;

implementation

uses
  StrUtils, Types, nyx.hostspace, oraclevocab, oraclegraphmodel, parkinsonsoracle.presentation;

const
  CMaxInitialLocalChunks = 8;
  CUrlCharPattern = 'https?://[^\s<>\[\]{}"''`]+';

type
  TReaderLocalLinkAction = reference to procedure(const APath, AAnchor: String);
  TReaderAnchorAction = reference to procedure(const AAnchor: String);

function MakeNode(AKind: TNyxKind; const AId: String; const AText: String = ''): TNyxNode;
begin
  Result := TNyxNode.Create(AKind, AId);
  if AText <> '' then
    Result.Configure.Text(AText).Done;
end;

function MakeButton(const AId, AText: String; AVariant: TNyxVariant = nvSecondary): TNyxNode;
begin
  Result := TNyxNode.Create(nkButton, AId).Configure.Text(AText).Variant(AVariant).Done;
end;

procedure BindHandler(AElement: TJSHTMLElement; const AEventName: String;
  AHandler: TJSEventHandler);
begin
  if AElement <> nil then
    AElement.addEventListener(AEventName, AHandler);
end;

function NormalizeNewlines(const AText: String): String;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function SafeExternalURL(const AValue: String): String;
var
  LURL: TJSURL;
begin
  Result := '';
  if not StartsText('https://', AValue) and not StartsText('http://', AValue) then
    Exit;
  try
    LURL := TJSURL.new(AValue);
    if (LURL.hostname <> '') and (LURL.username = '') and (LURL.password = '') then
      Result := LURL.href;
  except
    Exit;
  end;
end;

function TrimTrailingUrlPunctuation(const AToken: String): String;
var
  LChar: Char;
  LParens: Integer;
  LLength: Integer;
begin
  LParens := 0;
  for LChar in AToken do
    case LChar of
      '(': Inc(LParens);
      ')': Dec(LParens);
    end;
  LLength := Length(AToken);
  while LLength > 0 do
    case AToken[LLength] of
      '.', ',', ';', ':', '!', '?': Dec(LLength);
      ')':
        if LParens < 0 then
        begin
          Inc(LParens);
          Dec(LLength);
        end
        else
          Break;
    else
      Break;
    end;
  Result := Copy(AToken, 1, LLength);
end;

function SplitPathAnchor(const AInput: String; out AAnchor: String): String;
var
  LHash: Integer;
begin
  LHash := Pos('#', AInput);
  if LHash > 0 then
  begin
    Result := Trim(Copy(AInput, 1, LHash - 1));
    AAnchor := Trim(Copy(AInput, LHash + 1, MaxInt));
  end
  else
  begin
    Result := Trim(AInput);
    AAnchor := '';
  end;
end;

function ResolveRelativeResearchLink(const ACurrentPath, ATarget: String;
  out AAnchor: String): String;
var
  LClean: String;
  LQuery: Integer;
  LParts: TStringDynArray;
  LStack: array of String;
  LStackLen: Integer;
  LPart: String;
  LBaseDir: String;
  LSlash: Integer;
  LIndex: Integer;
  LLower: String;
begin
  Result := '';
  AAnchor := '';
  LClean := SplitPathAnchor(StringReplace(ATarget, '\', '/', [rfReplaceAll]), AAnchor);
  LQuery := Pos('?', LClean);
  if LQuery > 0 then
    LClean := Copy(LClean, 1, LQuery - 1);
  if (LClean = '') or StartsText('http://', LClean) or StartsText('https://', LClean) or
    StartsText('mailto:', LClean) or StartsText('javascript:', LClean) or
    (LClean[1] = '/') then
    Exit;
  if StartsStr('research/', LClean) then
    LBaseDir := ''
  else
  begin
    LBaseDir := StringReplace(ACurrentPath, '\', '/', [rfReplaceAll]);
    LSlash := LastDelimiter('/', LBaseDir);
    if LSlash > 0 then
      LBaseDir := Copy(LBaseDir, 1, LSlash)
    else
      LBaseDir := '';
  end;
  LParts := SplitString(LBaseDir + LClean, '/');
  SetLength(LStack, Length(LParts));
  LStackLen := 0;
  for LPart in LParts do
  begin
    if (LPart = '') or (LPart = '.') then
      Continue;
    if LPart = '..' then
    begin
      if LStackLen = 0 then
        Exit;
      Dec(LStackLen);
      Continue;
    end;
    LStack[LStackLen] := LPart;
    Inc(LStackLen);
  end;
  if LStackLen = 0 then
    Exit;
  LClean := '';
  for LIndex := 0 to LStackLen - 1 do
  begin
    if LClean <> '' then
      LClean := LClean + '/';
    LClean := LClean + LStack[LIndex];
  end;
  LLower := LowerCase(LClean);
  if StartsStr('research/', LLower) and
    (EndsStr('.md', LLower) or EndsStr('.txt', LLower) or EndsStr('.tsv', LLower)) then
    Result := LClean;
end;

function ExtractOriginalSourceURL(const AText: String): String;
var
  LLine: String;
  LMatch: TStringDynArray;
begin
  Result := '';
  for LLine in SplitString(NormalizeNewlines(AText), #10) do
  begin
    if Trim(LLine) = '' then
      Exit;
    if StartsText('Source:', LLine) then
    begin
      LMatch := TJSRegexp.new(CUrlCharPattern, 'i')
        .exec(Trim(Copy(LLine, Length('Source:') + 1, MaxInt)));
      if LMatch <> nil then
        Result := SafeExternalURL(TrimTrailingUrlPunctuation(LMatch[0]));
      Exit;
    end;
  end;
end;

function HeadingSlug(const AText: String): String;
var
  LIndex: Integer;
  LCh: Char;
  LDashPending: Boolean;
begin
  Result := '';
  LDashPending := False;
  for LIndex := 1 to Length(AText) do
  begin
    LCh := LowerCase(AText[LIndex])[1];
    if ((LCh >= 'a') and (LCh <= 'z')) or ((LCh >= '0') and (LCh <= '9')) then
    begin
      if LDashPending and (Result <> '') then
        Result := Result + '-';
      LDashPending := False;
      Result := Result + LCh;
    end
    else if (LCh = ' ') or (LCh = '-') or (LCh = '_') or (LCh = '/') then
      LDashPending := True;
  end;
end;

function IsDigitChar(ACh: Char): Boolean;
begin
  Result := (ACh >= '0') and (ACh <= '9');
end;

function IsWordChar(ACh: Char): Boolean;
begin
  Result := ((ACh >= 'a') and (ACh <= 'z')) or ((ACh >= 'A') and (ACh <= 'Z')) or
    ((ACh >= '0') and (ACh <= '9')) or (ACh = '_') or (ACh = '-');
end;

function IsPathChar(ACh: Char): Boolean;
begin
  Result := ((ACh >= 'a') and (ACh <= 'z')) or ((ACh >= 'A') and (ACh <= 'Z')) or
    ((ACh >= '0') and (ACh <= '9')) or (ACh = '/') or (ACh = '.') or
    (ACh = '_') or (ACh = '-') or (ACh = '#');
end;

function IsMetadataLine(const ALine: String; out AKey, AValue: String): Boolean;
var
  LColon: Integer;
  LIndex: Integer;
  LCh: Char;
begin
  Result := False;
  AKey := '';
  AValue := '';
  if (ALine = '') or (ALine[1] = ' ') or (ALine[1] = #9) or (ALine[1] = '#') or
    (ALine[1] = '-') or (ALine[1] = '*') or (ALine[1] = '>') or (ALine[1] = '|') then
    Exit;
  LColon := Pos(':', ALine);
  if (LColon < 2) or (LColon > 34) then
    Exit;
  AKey := Copy(ALine, 1, LColon - 1);
  if (AKey <> Trim(AKey)) or StartsText('http', AKey) then
    Exit;
  for LIndex := 1 to Length(AKey) do
  begin
    LCh := AKey[LIndex];
    if not (((LCh >= 'A') and (LCh <= 'Z')) or ((LCh >= 'a') and (LCh <= 'z')) or
      ((LCh >= '0') and (LCh <= '9')) or (LCh = ' ') or (LCh = '-') or (LCh = '/') or
      (LCh = '&')) then
      Exit;
  end;
  if (LColon < Length(ALine)) and (ALine[LColon + 1] <> ' ') then
    Exit;
  AValue := Trim(Copy(ALine, LColon + 1, MaxInt));
  Result := True;
end;

function AppendExternalLink(AParent: TJSNode; const ALabel, AURL: String): TJSHTMLAnchorElement;
begin
  Result := TJSHTMLAnchorElement(document.createElement('a'));
  Result.href := AURL;
  Result.textContent := ALabel;
  Result.target := '_blank';
  Result.rel := 'noopener noreferrer';
  Result.className := 'oracle-md-link';
  AParent.appendChild(Result);
end;

procedure AppendLocalLinkButton(AParent: TJSNode; const ALabel, APath, AAnchor: String;
  AOnLocal: TReaderLocalLinkAction);
var
  LBtn: TJSHTMLElement;
  LHandler: TJSEventHandler;
begin
  LBtn := TJSHTMLElement(document.createElement('button'));
  LBtn.setAttribute('type', 'button');
  LBtn.className := 'oracle-md-local-link';
  LBtn.textContent := ALabel;
  LBtn.setAttribute('title', 'Open ' + APath);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if Assigned(AOnLocal) then
        AOnLocal(APath, AAnchor);
      Result := True;
    end;
  LBtn.addEventListener('click', LHandler);
  AParent.appendChild(LBtn);
end;

procedure AppendAnchorButton(AParent: TJSNode; const ALabel, AAnchor: String;
  AOnAnchor: TReaderAnchorAction);
var
  LBtn: TJSHTMLElement;
  LHandler: TJSEventHandler;
begin
  LBtn := TJSHTMLElement(document.createElement('button'));
  LBtn.setAttribute('type', 'button');
  LBtn.className := 'oracle-md-local-link';
  LBtn.textContent := ALabel;
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if Assigned(AOnAnchor) then
        AOnAnchor(AAnchor);
      Result := True;
    end;
  LBtn.addEventListener('click', LHandler);
  AParent.appendChild(LBtn);
end;

function FindClosingParen(const AText: String; AOpenIndex: Integer): Integer;
var
  LIndex: Integer;
  LDepth: Integer;
begin
  Result := 0;
  LDepth := 0;
  for LIndex := AOpenIndex to Length(AText) do
  begin
    if AText[LIndex] = '(' then
      Inc(LDepth)
    else if AText[LIndex] = ')' then
    begin
      Dec(LDepth);
      if LDepth = 0 then
        Exit(LIndex);
    end
    else if (AText[LIndex] = #10) or (AText[LIndex] = #13) then
      Exit(0);
  end;
end;

function FindClosingDelimiter(const AText, ADelim: String; AStart: Integer): Integer;
var
  LPos: Integer;
  LSearch: Integer;
  LLen: Integer;
begin
  Result := 0;
  LLen := Length(ADelim);
  LSearch := AStart;
  while LSearch <= Length(AText) - LLen + 1 do
  begin
    LPos := PosEx(ADelim, AText, LSearch);
    if LPos = 0 then
      Exit(0);
    if (LPos > 1) and (AText[LPos - 1] = '\') then
    begin
      LSearch := LPos + LLen;
      Continue;
    end;
    if (LPos > AStart) and (AText[LPos - 1] <> ' ') then
      Exit(LPos);
    LSearch := LPos + 1;
  end;
end;

procedure RenderInlineMarkdown(AParent: TJSNode; const AText, ACurrentPath: String;
  AOnLocal: TReaderLocalLinkAction; AOnAnchor: TReaderAnchorAction;
  AStaticOracle: TStaticOracle; ADepth: Integer = 0);
var
  LI: Integer;
  LLen: Integer;
  LBuf: String;
  LClose: Integer;
  LParenClose: Integer;
  LLabel: String;
  LTarget: String;
  LURL: String;
  LLocalPath: String;
  LAnchor: String;
  LEnd: Integer;
  LToken: String;
  LCodeEl: TJSHTMLElement;
  LEl: TJSHTMLElement;
  LInner: String;

  procedure FlushBuf;
  begin
    if LBuf <> '' then
    begin
      AParent.appendChild(document.createTextNode(LBuf));
      LBuf := '';
    end;
  end;

begin
  LLen := Length(AText);
  LI := 1;
  LBuf := '';
  while LI <= LLen do
  begin
    // Backslash escape for punctuation
    if (AText[LI] = '\') and (LI < LLen) and
      (Pos(AText[LI + 1], '\`*_{}[]()#+-.!|') > 0) then
    begin
      LBuf := LBuf + AText[LI + 1];
      Inc(LI, 2);
      Continue;
    end;

    // Inline code span: `...`
    if AText[LI] = '`' then
    begin
      LClose := PosEx('`', AText, LI + 1);
      if LClose > LI + 1 then
      begin
        FlushBuf;
        LCodeEl := TJSHTMLElement(document.createElement('code'));
        LCodeEl.textContent := Copy(AText, LI + 1, LClose - LI - 1);
        AParent.appendChild(LCodeEl);
        LI := LClose + 1;
        Continue;
      end;
    end;

    // Markdown link: [label](target)
    if AText[LI] = '[' then
    begin
      LClose := PosEx(']', AText, LI + 1);
      if (LClose > LI + 1) and (LClose < LLen) and (AText[LClose + 1] = '(') then
      begin
        LParenClose := FindClosingParen(AText, LClose + 1);
        if LParenClose > LClose + 2 then
        begin
          LLabel := Copy(AText, LI + 1, LClose - LI - 1);
          LTarget := Trim(Copy(AText, LClose + 2, LParenClose - LClose - 2));
          if (Length(LTarget) >= 2) and (LTarget[1] = '<') and
            (LTarget[Length(LTarget)] = '>') then
            LTarget := Copy(LTarget, 2, Length(LTarget) - 2);

          if StartsStr('#', LTarget) and (Length(LTarget) > 1) then
          begin
            FlushBuf;
            AppendAnchorButton(AParent, LLabel, Copy(LTarget, 2, MaxInt), AOnAnchor);
            LI := LParenClose + 1;
            Continue;
          end;

          LURL := SafeExternalURL(LTarget);
          if LURL <> '' then
          begin
            FlushBuf;
            AppendExternalLink(AParent, LLabel, LURL);
            LI := LParenClose + 1;
            Continue;
          end;

          LLocalPath := ResolveRelativeResearchLink(ACurrentPath, LTarget, LAnchor);
          if LLocalPath <> '' then
          begin
            FlushBuf;
            AppendLocalLinkButton(AParent, LLabel, LLocalPath, LAnchor, AOnLocal);
            LI := LParenClose + 1;
            Continue;
          end;

          if (AStaticOracle <> nil) and StartsStr('research/', LTarget) then
          begin
            LURL := AStaticOracle.ReferenceURL(LTarget);
            if LURL <> '' then
            begin
              FlushBuf;
              AppendExternalLink(AParent, LLabel, LURL);
              LI := LParenClose + 1;
              Continue;
            end;
          end;
        end;
      end;
    end;

    // Bare external URL: https://... or http://...
    if (StartsText('https://', Copy(AText, LI, 8)) or
      StartsText('http://', Copy(AText, LI, 7))) and
      ((LI = 1) or not IsWordChar(AText[LI - 1])) then
    begin
      LEnd := LI;
      while (LEnd <= LLen) and (Ord(AText[LEnd]) > 32) and
        (Pos(AText[LEnd], '<>[]{}''"`') = 0) do
        Inc(LEnd);
      LToken := TrimTrailingUrlPunctuation(Copy(AText, LI, LEnd - LI));
      LURL := SafeExternalURL(LToken);
      if LURL <> '' then
      begin
        FlushBuf;
        AppendExternalLink(AParent, LToken, LURL);
        Inc(LI, Length(LToken));
        Continue;
      end;
    end;

    // Bare archive path: research/.../file.(md|txt|tsv)
    if StartsStr('research/', Copy(AText, LI, 9)) and
      ((LI = 1) or not IsWordChar(AText[LI - 1])) then
    begin
      LEnd := LI;
      while (LEnd <= LLen) and IsPathChar(AText[LEnd]) do
        Inc(LEnd);
      LToken := TrimTrailingUrlPunctuation(Copy(AText, LI, LEnd - LI));
      LLocalPath := ResolveRelativeResearchLink(ACurrentPath, LToken, LAnchor);
      if LLocalPath <> '' then
      begin
        FlushBuf;
        AppendLocalLinkButton(AParent, LToken, LLocalPath, LAnchor, AOnLocal);
        Inc(LI, Length(LToken));
        Continue;
      end;
    end;

    // Bare PMID12345678 / PMC1234567 citations
    if (StartsStr('PMID', Copy(AText, LI, 4)) and (LI + 4 <= LLen) and IsDigitChar(AText[LI + 4])) and
      ((LI = 1) or not IsWordChar(AText[LI - 1])) then
    begin
      LEnd := LI + 4;
      while (LEnd <= LLen) and IsDigitChar(AText[LEnd]) do
        Inc(LEnd);
      if LEnd - (LI + 4) >= 5 then
      begin
        LToken := Copy(AText, LI, LEnd - LI);
        FlushBuf;
        AppendExternalLink(AParent, LToken,
          'https://pubmed.ncbi.nlm.nih.gov/' + Copy(LToken, 5, MaxInt) + '/');
        LI := LEnd;
        Continue;
      end;
    end;
    if (StartsStr('PMC', Copy(AText, LI, 3)) and (LI + 3 <= LLen) and IsDigitChar(AText[LI + 3])) and
      ((LI = 1) or not IsWordChar(AText[LI - 1])) then
    begin
      LEnd := LI + 3;
      while (LEnd <= LLen) and IsDigitChar(AText[LEnd]) do
        Inc(LEnd);
      if LEnd - (LI + 3) >= 5 then
      begin
        LToken := Copy(AText, LI, LEnd - LI);
        FlushBuf;
        AppendExternalLink(AParent, LToken,
          'https://pmc.ncbi.nlm.nih.gov/articles/' + LToken + '/');
        LI := LEnd;
        Continue;
      end;
    end;

    // Bold + italic ***...***, bold **...**, italic *...*
    if (ADepth < 4) and (AText[LI] = '*') then
    begin
      if (LI + 2 <= LLen) and (AText[LI + 1] = '*') and (AText[LI + 2] = '*') and
        (LI + 3 <= LLen) and (AText[LI + 3] <> ' ') then
      begin
        LClose := FindClosingDelimiter(AText, '***', LI + 3);
        if LClose > LI + 3 then
        begin
          FlushBuf;
          LEl := TJSHTMLElement(document.createElement('strong'));
          LCodeEl := TJSHTMLElement(document.createElement('em'));
          LInner := Copy(AText, LI + 3, LClose - LI - 3);
          RenderInlineMarkdown(LCodeEl, LInner, ACurrentPath, AOnLocal, AOnAnchor,
            AStaticOracle, ADepth + 1);
          LEl.appendChild(LCodeEl);
          AParent.appendChild(LEl);
          LI := LClose + 3;
          Continue;
        end;
      end
      else if (LI + 1 <= LLen) and (AText[LI + 1] = '*') and
        (LI + 2 <= LLen) and (AText[LI + 2] <> ' ') then
      begin
        LClose := FindClosingDelimiter(AText, '**', LI + 2);
        if LClose > LI + 2 then
        begin
          FlushBuf;
          LEl := TJSHTMLElement(document.createElement('strong'));
          LInner := Copy(AText, LI + 2, LClose - LI - 2);
          RenderInlineMarkdown(LEl, LInner, ACurrentPath, AOnLocal, AOnAnchor,
            AStaticOracle, ADepth + 1);
          AParent.appendChild(LEl);
          LI := LClose + 2;
          Continue;
        end;
      end
      else if (LI + 1 <= LLen) and (AText[LI + 1] <> ' ') and (AText[LI + 1] <> '*') and
        ((LI = 1) or not IsWordChar(AText[LI - 1])) then
      begin
        LClose := FindClosingDelimiter(AText, '*', LI + 1);
        if (LClose > LI + 1) and ((LClose = LLen) or not IsWordChar(AText[LClose + 1])) then
        begin
          FlushBuf;
          LEl := TJSHTMLElement(document.createElement('em'));
          LInner := Copy(AText, LI + 1, LClose - LI - 1);
          RenderInlineMarkdown(LEl, LInner, ACurrentPath, AOnLocal, AOnAnchor,
            AStaticOracle, ADepth + 1);
          AParent.appendChild(LEl);
          LI := LClose + 1;
          Continue;
        end;
      end;
    end;

    LBuf := LBuf + AText[LI];
    Inc(LI);
  end;
  FlushBuf;
end;

function IsHorizontalRuleLine(const ATrimmed: String): Boolean;
var
  LCh: Char;
  LCount: Integer;
  LIndex: Integer;
begin
  Result := False;
  if Length(ATrimmed) < 3 then
    Exit;
  LCh := ATrimmed[1];
  if not ((LCh = '-') or (LCh = '*') or (LCh = '_')) then
    Exit;
  LCount := 0;
  for LIndex := 1 to Length(ATrimmed) do
  begin
    if ATrimmed[LIndex] = LCh then
      Inc(LCount)
    else if ATrimmed[LIndex] <> ' ' then
      Exit(False);
  end;
  Result := LCount >= 3;
end;

function ParseHeadingLine(const ALine: String; out ALevel: Integer; out ATitle: String): Boolean;
var
  LI: Integer;
begin
  Result := False;
  ALevel := 0;
  ATitle := '';
  LI := 1;
  while (LI <= Length(ALine)) and (LI <= 6) and (ALine[LI] = '#') do
    Inc(LI);
  ALevel := LI - 1;
  if (ALevel < 1) or (ALevel > 6) or (LI > Length(ALine)) or (ALine[LI] <> ' ') then
    Exit;
  ATitle := Trim(Copy(ALine, LI + 1, MaxInt));
  while (Length(ATitle) > 0) and (ATitle[Length(ATitle)] = '#') do
    Delete(ATitle, Length(ATitle), 1);
  ATitle := Trim(ATitle);
  Result := ATitle <> '';
end;

function IsUnorderedListLine(const ALine: String; out AItemText: String): Boolean;
var
  LTrim: String;
begin
  Result := False;
  AItemText := '';
  LTrim := TrimLeft(ALine);
  if (Length(LTrim) >= 2) and
    ((LTrim[1] = '-') or (LTrim[1] = '*') or (LTrim[1] = '+')) and
    (LTrim[2] = ' ') then
  begin
    AItemText := Trim(Copy(LTrim, 3, MaxInt));
    Result := True;
  end;
end;

function IsOrderedListLine(const ALine: String; out AItemText: String): Boolean;
var
  LTrim: String;
  LI: Integer;
begin
  Result := False;
  AItemText := '';
  LTrim := TrimLeft(ALine);
  LI := 1;
  while (LI <= Length(LTrim)) and IsDigitChar(LTrim[LI]) do
    Inc(LI);
  if (LI > 1) and (LI + 1 <= Length(LTrim)) and
    ((LTrim[LI] = '.') or (LTrim[LI] = ')')) and (LTrim[LI + 1] = ' ') then
  begin
    AItemText := Trim(Copy(LTrim, LI + 2, MaxInt));
    Result := True;
  end;
end;

function SplitTableCells(const ALine: String): TStringDynArray;
var
  LTrim: String;
  LParts: TStringDynArray;
  LIndex: Integer;
begin
  LTrim := Trim(ALine);
  if StartsStr('|', LTrim) then
    Delete(LTrim, 1, 1);
  if EndsStr('|', LTrim) then
    Delete(LTrim, Length(LTrim), 1);
  LParts := SplitString(LTrim, '|');
  for LIndex := 0 to High(LParts) do
    LParts[LIndex] := Trim(LParts[LIndex]);
  Result := LParts;
end;

function IsTableSeparatorLine(const ALine: String): Boolean;
var
  LCells: TStringDynArray;
  LCell: String;
  LI: Integer;
  LDashes: Integer;
begin
  Result := False;
  if Pos('|', ALine) = 0 then
    Exit;
  LCells := SplitTableCells(ALine);
  if Length(LCells) = 0 then
    Exit;
  for LCell in LCells do
  begin
    if LCell = '' then
      Exit(False);
    LDashes := 0;
    for LI := 1 to Length(LCell) do
      if LCell[LI] = '-' then
        Inc(LDashes)
      else if LCell[LI] <> ':' then
        Exit(False);
    if LDashes < 1 then
      Exit(False);
  end;
  Result := True;
end;

function IsFenceLine(const ATrimmed: String; out AFenceChar: Char): Boolean;
begin
  Result := False;
  AFenceChar := #0;
  if StartsStr('```', ATrimmed) then
  begin
    AFenceChar := '`';
    Result := True;
  end
  else if StartsStr('~~~', ATrimmed) then
  begin
    AFenceChar := '~';
    Result := True;
  end;
end;

procedure RenderMetadataValue(AParent: TJSNode; const AKey, AValue, ACurrentPath: String;
  AOnLocal: TReaderLocalLinkAction; AOnAnchor: TReaderAnchorAction;
  AStaticOracle: TStaticOracle);
var
  LLowerKey: String;
  LTrimVal: String;
  LI: Integer;
  LAllDigits: Boolean;
begin
  LLowerKey := LowerCase(Trim(AKey));
  LTrimVal := Trim(AValue);
  if (LLowerKey = 'pmid') and (LTrimVal <> '') then
  begin
    LAllDigits := True;
    for LI := 1 to Length(LTrimVal) do
      if not IsDigitChar(LTrimVal[LI]) then
      begin
        LAllDigits := False;
        Break;
      end;
    if LAllDigits then
    begin
      AppendExternalLink(AParent, LTrimVal, 'https://pubmed.ncbi.nlm.nih.gov/' + LTrimVal + '/');
      Exit;
    end;
  end;
  if (LLowerKey = 'doi') and StartsStr('10.', LTrimVal) and (Pos(' ', LTrimVal) = 0) then
  begin
    AppendExternalLink(AParent, LTrimVal, 'https://doi.org/' + LTrimVal);
    Exit;
  end;
  if (LLowerKey = 'pmcid') and StartsText('PMC', LTrimVal) and (Pos(' ', LTrimVal) = 0) then
  begin
    AppendExternalLink(AParent, LTrimVal, 'https://pmc.ncbi.nlm.nih.gov/articles/' + LTrimVal + '/');
    Exit;
  end;
  RenderInlineMarkdown(AParent, AValue, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
end;

procedure RenderTsvDocument(AContainer: TJSHTMLElement; const AText, ACurrentPath: String;
  AOnLocal: TReaderLocalLinkAction; AOnAnchor: TReaderAnchorAction;
  AStaticOracle: TStaticOracle);
var
  LLines: TStringDynArray;
  LWrap: TJSHTMLElement;
  LTable: TJSHTMLElement;
  LHead: TJSHTMLElement;
  LBody: TJSHTMLElement;
  LRowEl: TJSHTMLElement;
  LCellEl: TJSHTMLElement;
  LCells: TStringDynArray;
  LRowIdx: Integer;
  LColIdx: Integer;
begin
  LLines := SplitString(NormalizeNewlines(AText), #10);
  LWrap := TJSHTMLElement(document.createElement('div'));
  LWrap.className := 'oracle-md-table-wrap';
  LTable := TJSHTMLElement(document.createElement('table'));
  LTable.className := 'oracle-md-table';
  LHead := TJSHTMLElement(document.createElement('thead'));
  LBody := TJSHTMLElement(document.createElement('tbody'));
  for LRowIdx := 0 to High(LLines) do
  begin
    if Trim(LLines[LRowIdx]) = '' then
      Continue;
    LCells := SplitString(LLines[LRowIdx], #9);
    LRowEl := TJSHTMLElement(document.createElement('tr'));
    for LColIdx := 0 to High(LCells) do
    begin
      if LRowIdx = 0 then
        LCellEl := TJSHTMLElement(document.createElement('th'))
      else
        LCellEl := TJSHTMLElement(document.createElement('td'));
      RenderInlineMarkdown(LCellEl, LCells[LColIdx], ACurrentPath, AOnLocal, AOnAnchor,
        AStaticOracle);
      LRowEl.appendChild(LCellEl);
    end;
    if LRowIdx = 0 then
      LHead.appendChild(LRowEl)
    else
      LBody.appendChild(LRowEl);
  end;
  LTable.appendChild(LHead);
  LTable.appendChild(LBody);
  LWrap.appendChild(LTable);
  AContainer.appendChild(LWrap);
end;

procedure RenderMarkdownDocument(AContainer: TJSHTMLElement; const AText, ACurrentPath: String;
  AOnLocal: TReaderLocalLinkAction; AOnAnchor: TReaderAnchorAction;
  AStaticOracle: TStaticOracle);
var
  LLines: TStringDynArray;
  LCount: Integer;
  LI: Integer;
  LIsTxt: Boolean;
  LTrim: String;
  LKey: String;
  LVal: String;
  LMetaEnd: Integer;
  LMetaCount: Integer;
  LDl: TJSHTMLElement;
  LDt: TJSHTMLElement;
  LDd: TJSHTMLElement;
  LFenceChar: Char;
  LPre: TJSHTMLElement;
  LCode: TJSHTMLElement;
  LCodeLines: String;
  LLevel: Integer;
  LTitle: String;
  LH: TJSHTMLElement;
  LSlug: String;
  LQuote: TJSHTMLElement;
  LP: TJSHTMLElement;
  LQuoteBuf: String;
  LItemText: String;
  LListEl: TJSHTMLElement;
  LLi: TJSHTMLElement;
  LWrap: TJSHTMLElement;
  LTable: TJSHTMLElement;
  LThead: TJSHTMLElement;
  LTbody: TJSHTMLElement;
  LTr: TJSHTMLElement;
  LCell: TJSHTMLElement;
  LCells: TStringDynArray;
  LC: Integer;
  LPara: String;
  LLeadKey: String;
  LLeadVal: String;
  LStrong: TJSHTMLElement;
begin
  if EndsText('.tsv', ACurrentPath) then
  begin
    RenderTsvDocument(AContainer, AText, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
    Exit;
  end;

  LIsTxt := EndsText('.txt', ACurrentPath);
  LLines := SplitString(NormalizeNewlines(AText), #10);
  LCount := Length(LLines);
  LI := 0;

  // Render structured Key: Value metadata header card on archive .txt records
  if LIsTxt then
  begin
    LMetaEnd := 0;
    LMetaCount := 0;
    while (LMetaEnd < LCount) and (Trim(LLines[LMetaEnd]) <> '') do
    begin
      if IsMetadataLine(LLines[LMetaEnd], LKey, LVal) then
        Inc(LMetaCount)
      else
      begin
        LMetaCount := 0;
        Break;
      end;
      Inc(LMetaEnd);
    end;
    if LMetaCount >= 2 then
    begin
      LDl := TJSHTMLElement(document.createElement('dl'));
      LDl.className := 'oracle-md-meta';
      for LC := 0 to LMetaEnd - 1 do
      begin
        if IsMetadataLine(LLines[LC], LKey, LVal) then
        begin
          LDt := TJSHTMLElement(document.createElement('dt'));
          LDt.textContent := LKey;
          LDd := TJSHTMLElement(document.createElement('dd'));
          RenderMetadataValue(LDd, LKey, LVal, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
          LDl.appendChild(LDt);
          LDl.appendChild(LDd);
        end;
      end;
      AContainer.appendChild(LDl);
      LI := LMetaEnd;
    end;
  end;

  while LI < LCount do
  begin
    LTrim := Trim(LLines[LI]);
    if LTrim = '' then
    begin
      Inc(LI);
      Continue;
    end;

    // Fenced code block
    if IsFenceLine(LTrim, LFenceChar) then
    begin
      Inc(LI);
      LCodeLines := '';
      while LI < LCount do
      begin
        if StartsStr(StringOfChar(LFenceChar, 3), Trim(LLines[LI])) then
        begin
          Inc(LI);
          Break;
        end;
        if LCodeLines <> '' then
          LCodeLines := LCodeLines + #10;
        LCodeLines := LCodeLines + LLines[LI];
        Inc(LI);
      end;
      LPre := TJSHTMLElement(document.createElement('pre'));
      LPre.className := 'oracle-md-code';
      LCode := TJSHTMLElement(document.createElement('code'));
      LCode.textContent := LCodeLines;
      LPre.appendChild(LCode);
      AContainer.appendChild(LPre);
      Continue;
    end;

    // Heading
    if ParseHeadingLine(LTrim, LLevel, LTitle) then
    begin
      LH := TJSHTMLElement(document.createElement('h' + IntToStr(LLevel)));
      LH.className := 'oracle-md-h' + IntToStr(LLevel);
      LSlug := HeadingSlug(LTitle);
      if LSlug <> '' then
        LH.setAttribute('data-md-anchor', LSlug);
      RenderInlineMarkdown(LH, LTitle, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
      AContainer.appendChild(LH);
      Inc(LI);
      Continue;
    end;

    // Horizontal rule
    if IsHorizontalRuleLine(LTrim) then
    begin
      AContainer.appendChild(document.createElement('hr'));
      Inc(LI);
      Continue;
    end;

    // Pipe table
    if (LI + 1 < LCount) and (Pos('|', LLines[LI]) > 0) and
      IsTableSeparatorLine(LLines[LI + 1]) then
    begin
      LWrap := TJSHTMLElement(document.createElement('div'));
      LWrap.className := 'oracle-md-table-wrap';
      LTable := TJSHTMLElement(document.createElement('table'));
      LTable.className := 'oracle-md-table';
      LThead := TJSHTMLElement(document.createElement('thead'));
      LTr := TJSHTMLElement(document.createElement('tr'));
      LCells := SplitTableCells(LLines[LI]);
      for LC := 0 to High(LCells) do
      begin
        LCell := TJSHTMLElement(document.createElement('th'));
        RenderInlineMarkdown(LCell, LCells[LC], ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
        LTr.appendChild(LCell);
      end;
      LThead.appendChild(LTr);
      LTable.appendChild(LThead);
      LTbody := TJSHTMLElement(document.createElement('tbody'));
      Inc(LI, 2);
      while (LI < LCount) and (Trim(LLines[LI]) <> '') and (Pos('|', LLines[LI]) > 0) do
      begin
        LTr := TJSHTMLElement(document.createElement('tr'));
        LCells := SplitTableCells(LLines[LI]);
        for LC := 0 to High(LCells) do
        begin
          LCell := TJSHTMLElement(document.createElement('td'));
          RenderInlineMarkdown(LCell, LCells[LC], ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
          LTr.appendChild(LCell);
        end;
        LTbody.appendChild(LTr);
        Inc(LI);
      end;
      LTable.appendChild(LTbody);
      LWrap.appendChild(LTable);
      AContainer.appendChild(LWrap);
      Continue;
    end;

    // Blockquote
    if StartsStr('>', LTrim) then
    begin
      LQuote := TJSHTMLElement(document.createElement('blockquote'));
      LQuote.className := 'oracle-md-quote';
      LQuoteBuf := '';
      while (LI < LCount) and StartsStr('>', Trim(LLines[LI])) do
      begin
        LVal := Trim(Copy(Trim(LLines[LI]), 2, MaxInt));
        if LVal = '' then
        begin
          if LQuoteBuf <> '' then
          begin
            LP := TJSHTMLElement(document.createElement('p'));
            RenderInlineMarkdown(LP, LQuoteBuf, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
            LQuote.appendChild(LP);
            LQuoteBuf := '';
          end;
        end
        else
        begin
          if LQuoteBuf <> '' then
            LQuoteBuf := LQuoteBuf + ' ';
          LQuoteBuf := LQuoteBuf + LVal;
        end;
        Inc(LI);
      end;
      if LQuoteBuf <> '' then
      begin
        LP := TJSHTMLElement(document.createElement('p'));
        RenderInlineMarkdown(LP, LQuoteBuf, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
        LQuote.appendChild(LP);
      end;
      AContainer.appendChild(LQuote);
      Continue;
    end;

    // Unordered list
    if IsUnorderedListLine(LLines[LI], LItemText) then
    begin
      LListEl := TJSHTMLElement(document.createElement('ul'));
      LListEl.className := 'oracle-md-list';
      while (LI < LCount) and IsUnorderedListLine(LLines[LI], LItemText) do
      begin
        LLi := TJSHTMLElement(document.createElement('li'));
        RenderInlineMarkdown(LLi, LItemText, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
        LListEl.appendChild(LLi);
        Inc(LI);
      end;
      AContainer.appendChild(LListEl);
      Continue;
    end;

    // Ordered list
    if IsOrderedListLine(LLines[LI], LItemText) then
    begin
      LListEl := TJSHTMLElement(document.createElement('ol'));
      LListEl.className := 'oracle-md-list';
      while (LI < LCount) and IsOrderedListLine(LLines[LI], LItemText) do
      begin
        LLi := TJSHTMLElement(document.createElement('li'));
        RenderInlineMarkdown(LLi, LItemText, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
        LListEl.appendChild(LLi);
        Inc(LI);
      end;
      AContainer.appendChild(LListEl);
      Continue;
    end;

    // Structured key-value paragraph line inside archive .txt files
    if LIsTxt and IsMetadataLine(LLines[LI], LLeadKey, LLeadVal) then
    begin
      LP := TJSHTMLElement(document.createElement('p'));
      LP.className := 'oracle-md-field-para';
      LStrong := TJSHTMLElement(document.createElement('strong'));
      LStrong.textContent := LLeadKey + ': ';
      LP.appendChild(LStrong);
      RenderMetadataValue(LP, LLeadKey, LLeadVal, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
      AContainer.appendChild(LP);
      Inc(LI);
      Continue;
    end;

    // Paragraph (join wrapped consecutive prose lines until blank line or block start)
    LPara := LTrim;
    Inc(LI);
    while LI < LCount do
    begin
      LTrim := Trim(LLines[LI]);
      if (LTrim = '') or IsFenceLine(LTrim, LFenceChar) or
        ParseHeadingLine(LTrim, LLevel, LTitle) or IsHorizontalRuleLine(LTrim) or
        StartsStr('>', LTrim) or IsUnorderedListLine(LLines[LI], LItemText) or
        IsOrderedListLine(LLines[LI], LItemText) or
        (LIsTxt and IsMetadataLine(LLines[LI], LLeadKey, LLeadVal)) or
        ((LI + 1 < LCount) and (Pos('|', LLines[LI]) > 0) and
          IsTableSeparatorLine(LLines[LI + 1])) then
        Break;
      LPara := LPara + ' ' + LTrim;
      Inc(LI);
    end;
    LP := TJSHTMLElement(document.createElement('p'));
    RenderInlineMarkdown(LP, LPara, ACurrentPath, AOnLocal, AOnAnchor, AStaticOracle);
    AContainer.appendChild(LP);
  end;
end;

constructor TOracleReaderModal.Create(AStaticOracle: TStaticOracle;
  AFetchLocalChunk: TReaderFetchChunk; AOnConnections: TReaderConnectionsAction);
begin
  inherited Create;
  FStaticOracle := AStaticOracle;
  FFetchLocalChunk := AFetchLocalChunk;
  FOnConnections := AOnConnections;
  FShellRenderer := TNyxBrowserRenderer.Create;
  FCache := TJSObject.new;
end;

destructor TOracleReaderModal.Destroy;
begin
  Close;
  CleanupShell;
  FShellRenderer.Free;
  inherited Destroy;
end;

procedure TOracleReaderModal.CancelActiveRequest;
var
  LPrior: TJSXMLHttpRequest;
begin
  if FActiveRequest <> nil then
  begin
    LPrior := FActiveRequest;
    FActiveRequest := nil;
    try
      LPrior.onload := nil;
      LPrior.onerror := nil;
      LPrior.ontimeout := nil;
      LPrior.onabort := nil;
      LPrior.abort;
    except
    end;
  end;
end;

procedure TOracleReaderModal.CleanupShell;
begin
  if FShellRenderer <> nil then
    FShellRenderer.Unmount;
  FreeAndNil(FShellDoc);
end;

function TOracleReaderModal.IsOpen: Boolean;
begin
  Result := (FModalHost <> nil) and FModalHost.IsOpen;
end;

function TOracleReaderModal.OnBackdropClick(AEvent: TEventListenerEvent): Boolean;
begin
  if (FModalHost <> nil) and (AEvent.target = FModalHost.Element) then
    Close;
  Result := True;
end;

function TOracleReaderModal.HasCachedText(const APath: String; out AText: String): Boolean;
var
  LVal: JSValue;
begin
  Result := False;
  AText := '';
  if FCache = nil then
    Exit;
  LVal := FCache[APath];
  if isDefined(LVal) and not isNull(LVal) then
  begin
    AText := String(LVal);
    Result := True;
  end;
end;

procedure TOracleReaderModal.PutCachedText(const APath, AText: String);
begin
  if FCache = nil then
    FCache := TJSObject.new;
  FCache[APath] := AText;
end;

procedure TOracleReaderModal.MountShell;
var
  LPage: TNyxNode;
  LHeader: TNyxNode;
  LHeadMain: TNyxNode;
  LHeadTop: TNyxNode;
  LToolbar: TNyxNode;
  LBodyHost: TNyxNode;
begin
  CleanupShell;
  FShellDoc := TNyxDocument.Create;
  LPage := MakeNode(nkPage, 'reader-modal-page');
  FShellDoc.AddPage(LPage);

  LHeader := MakeNode(nkRow, 'reader-modal-header');
  LHeadMain := MakeNode(nkColumn, 'reader-modal-head-main');
  LHeadTop := MakeNode(nkRow, 'reader-modal-head-top');
  LHeadTop.Add(MakeButton('reader-back', '‹ Back', nvSecondary));
  LHeadTop.Add(MakeNode(nkBadge, 'reader-kind-badge', 'Research source'));
  LHeadMain.Add(LHeadTop);
  LHeadMain.Add(MakeNode(nkHeading, 'reader-modal-title', SavedSourceTitle(FCurrentPath)));
  LHeadMain.Add(MakeNode(nkCode, 'reader-modal-path', FCurrentPath));
  LHeader.Add(LHeadMain);
  LHeader.Add(MakeButton('reader-close', '× Close', nvSecondary)
    .Configure.AccessibleName('Close document reader').Done);
  LPage.Add(LHeader);

  LToolbar := MakeNode(nkRow, 'reader-modal-toolbar');
  LToolbar.Add(MakeNode(nkLink, 'reader-original-link', 'Open original source').Configure.LinkTo('#').Done);
  LToolbar.Add(MakeNode(nkLink, 'reader-github-link', 'Read on GitHub').Configure.LinkTo('#').Done);
  LToolbar.Add(MakeButton('reader-connections-btn', 'See connections', nvSecondary));
  LPage.Add(LToolbar);

  LBodyHost := MakeNode(nkColumn, 'reader-modal-body');
  LPage.Add(LBodyHost);

  FShellRenderer.Render(FShellDoc, LPage, FModalHost.Element);

  BindHandler(FShellRenderer.ElementFor('reader-close'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      Close;
      Result := True;
    end);
  BindHandler(FShellRenderer.ElementFor('reader-back'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    begin
      NavigateBack;
      Result := True;
    end);
  BindHandler(FShellRenderer.ElementFor('reader-connections-btn'), 'click',
    function(AEvent: TEventListenerEvent): Boolean
    var
      LPath: String;
    begin
      LPath := FCurrentPath;
      Close;
      if Assigned(FOnConnections) and (LPath <> '') then
        FOnConnections(LPath);
      Result := True;
    end);
end;

procedure TOracleReaderModal.UpdateHeader;
var
  LTitle: String;
  LBackBtn: TJSHTMLElement;
  LKindEl: TJSHTMLElement;
  LTitleEl: TJSHTMLElement;
  LPathEl: TJSHTMLElement;
  LOrigEl: TJSHTMLElement;
  LGitHubEl: TJSHTMLElement;
  LConnBtn: TJSHTMLElement;
  LToolbarEl: TJSHTMLElement;
  LOrigURL: String;
  LGitHubURL: String;
  LKindLabel: String;
  LKindAttr: String;
  LAnyToolbar: Boolean;
begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  LTitle := SavedSourceTitle(FCurrentPath);
  LBackBtn := FShellRenderer.ElementFor('reader-back');
  LBackBtn.hidden := Length(FHistory) = 0;

  if IsConversationSource(FCurrentPath) then
  begin
    LKindLabel := ConversationSourceLabel;
    LKindAttr := 'conversation';
  end
  else if IsCulturalSource(FCurrentPath) then
  begin
    LKindLabel := 'Culture & experience';
    LKindAttr := 'cultural';
  end
  else
  begin
    LKindLabel := 'Research source';
    LKindAttr := 'study';
  end;

  LKindEl := FShellRenderer.ElementFor('reader-kind-badge');
  FShellRenderer.Root.Find('reader-kind-badge').Configure.Text(LKindLabel);
  LKindEl.textContent := LKindLabel;
  LKindEl.setAttribute('data-source-kind', LKindAttr);

  LTitleEl := FShellRenderer.ElementFor('reader-modal-title');
  FShellRenderer.Root.Find('reader-modal-title').Configure.Text(LTitle);
  LTitleEl.textContent := LTitle;

  LPathEl := FShellRenderer.ElementFor('reader-modal-path');
  FShellRenderer.Root.Find('reader-modal-path').Configure.Text(FCurrentPath);
  LPathEl.textContent := FCurrentPath;

  LOrigURL := '';
  if not FLoading and (FErrorText = '') and (FLoadedText <> '') then
    LOrigURL := ExtractOriginalSourceURL(FLoadedText);
  LOrigEl := FShellRenderer.ElementFor('reader-original-link');
  if LOrigURL <> '' then
  begin
    LOrigEl.hidden := False;
    LOrigEl.setAttribute('href', LOrigURL);
    LOrigEl.setAttribute('target', '_blank');
    LOrigEl.setAttribute('rel', 'noopener noreferrer');
    if IsConversationSource(FCurrentPath) then
      LOrigEl.textContent := 'Open original discussion'
    else
      LOrigEl.textContent := 'Open original source';
  end
  else
    LOrigEl.hidden := True;

  LGitHubURL := '';
  if FStaticOracle <> nil then
    LGitHubURL := FStaticOracle.ReferenceURL(FCurrentPath);
  LGitHubEl := FShellRenderer.ElementFor('reader-github-link');
  if LGitHubURL <> '' then
  begin
    LGitHubEl.hidden := False;
    LGitHubEl.setAttribute('href', LGitHubURL);
    LGitHubEl.setAttribute('target', '_blank');
    LGitHubEl.setAttribute('rel', 'noopener noreferrer');
  end
  else
    LGitHubEl.hidden := True;

  LConnBtn := FShellRenderer.ElementFor('reader-connections-btn');
  LConnBtn.hidden := not Assigned(FOnConnections);

  LAnyToolbar := (LOrigURL <> '') or (LGitHubURL <> '') or Assigned(FOnConnections);
  LToolbarEl := FShellRenderer.ElementFor('reader-modal-toolbar');
  LToolbarEl.hidden := not LAnyToolbar;
end;

procedure TOracleReaderModal.ScrollToAnchor(const AAnchor: String);
var
  LSlug: String;
  LBody: TJSHTMLElement;
  LTarget: TJSElement;
begin
  LSlug := HeadingSlug(AAnchor);
  if (LSlug = '') or (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  LBody := FShellRenderer.ElementFor('reader-modal-body');
  if LBody = nil then
    Exit;
  LTarget := LBody.querySelector('[data-md-anchor="' + LSlug + '"]');
  if LTarget <> nil then
  begin
    asm
      try { LTarget.scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) {}
    end;
  end;
end;

procedure TOracleReaderModal.RenderBody;
var
  LBody: TJSHTMLElement;
  LNote: TJSHTMLElement;
  LStatusBox: TJSHTMLElement;
  LMsg: TJSHTMLElement;
  LActions: TJSHTMLElement;
  LRetryBtn: TJSHTMLElement;
  LMoreBtn: TJSHTMLElement;
  LGitHubURL: String;
  LClick: TJSEventHandler;
  LArticle: TJSHTMLElement;
begin
  if (FShellRenderer = nil) or (FShellRenderer.Root = nil) then
    Exit;
  LBody := FShellRenderer.ElementFor('reader-modal-body');
  if LBody = nil then
    Exit;
  while LBody.firstChild <> nil do
    LBody.removeChild(LBody.firstChild);

  if FLoading then
  begin
    LStatusBox := TJSHTMLElement(document.createElement('div'));
    LStatusBox.className := 'oracle-reader-status';
    LMsg := TJSHTMLElement(document.createElement('p'));
    LMsg.textContent := 'Loading document…';
    LStatusBox.appendChild(LMsg);
    LBody.appendChild(LStatusBox);
    Exit;
  end;

  if FErrorText <> '' then
  begin
    LStatusBox := TJSHTMLElement(document.createElement('div'));
    LStatusBox.className := 'oracle-reader-status oracle-reader-error';
    LMsg := TJSHTMLElement(document.createElement('p'));
    LMsg.textContent := FErrorText;
    LStatusBox.appendChild(LMsg);
    LActions := TJSHTMLElement(document.createElement('div'));
    LActions.className := 'oracle-reader-status-actions';
    LRetryBtn := TJSHTMLElement(document.createElement('button'));
    LRetryBtn.setAttribute('type', 'button');
    LRetryBtn.className := 'oracle-reader-retry-btn';
    LRetryBtn.textContent := 'Try again';
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        LoadDocument(FCurrentPath, FTargetAnchor, False);
        Result := True;
      end;
    LRetryBtn.addEventListener('click', LClick);
    LActions.appendChild(LRetryBtn);
    if FStaticOracle <> nil then
    begin
      LGitHubURL := FStaticOracle.ReferenceURL(FCurrentPath);
      if LGitHubURL <> '' then
        AppendExternalLink(LActions, 'Read on GitHub', LGitHubURL);
    end;
    LStatusBox.appendChild(LActions);
    LBody.appendChild(LStatusBox);
    Exit;
  end;

  if IsConversationSource(FCurrentPath) then
  begin
    LNote := TJSHTMLElement(document.createElement('div'));
    LNote.className := 'oracle-reader-callout oracle-reader-callout-conversation';
    LNote.textContent :=
      'This summary describes experiences shared in a public discussion. Personal reports carry lower evidential weight than controlled clinical studies.';
    LBody.appendChild(LNote);
  end
  else if IsCulturalSource(FCurrentPath) then
  begin
    LNote := TJSHTMLElement(document.createElement('div'));
    LNote.className := 'oracle-reader-callout oracle-reader-callout-cultural';
    LNote.textContent :=
      'Cultural and experiential accounts document traditional or lived perspectives and do not establish clinical efficacy.';
    LBody.appendChild(LNote);
  end;

  if Trim(FLoadedText) = '' then
  begin
    LStatusBox := TJSHTMLElement(document.createElement('div'));
    LStatusBox.className := 'oracle-reader-status';
    LMsg := TJSHTMLElement(document.createElement('p'));
    LMsg.textContent := 'This file has no text.';
    LStatusBox.appendChild(LMsg);
    LBody.appendChild(LStatusBox);
    Exit;
  end;

  LArticle := TJSHTMLElement(document.createElement('article'));
  LArticle.className := 'oracle-md-article';
  RenderMarkdownDocument(LArticle, FLoadedText, FCurrentPath,
    procedure(const ALinkedPath, ALinkedAnchor: String)
    begin
      LoadDocument(ALinkedPath, ALinkedAnchor, True);
    end,
    procedure(const ATarget: String)
    begin
      ScrollToAnchor(ATarget);
    end,
    FStaticOracle);
  LBody.appendChild(LArticle);

  if FNextOffset > 0 then
  begin
    LActions := TJSHTMLElement(document.createElement('div'));
    LActions.className := 'oracle-reader-more';
    LMoreBtn := TJSHTMLElement(document.createElement('button'));
    LMoreBtn.setAttribute('type', 'button');
    LMoreBtn.className := 'oracle-reader-more-btn';
    if FLoadingMore then
    begin
      LMoreBtn.textContent := 'Loading more…';
      LMoreBtn.setAttribute('disabled', '');
    end
    else
      LMoreBtn.textContent := 'Load more text';
    LClick :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        LoadMoreLocal;
        Result := True;
      end;
    LMoreBtn.addEventListener('click', LClick);
    LActions.appendChild(LMoreBtn);
    LBody.appendChild(LActions);
  end;

  if FTargetAnchor <> '' then
    ScrollToAnchor(FTargetAnchor);
end;

procedure TOracleReaderModal.LoadViaRawGitHub(const APath: String; AGen: Integer);
var
  LRawURL: String;
  LReq: TJSXMLHttpRequest;
begin
  LRawURL := '';
  if FStaticOracle <> nil then
    LRawURL := FStaticOracle.RawReferenceURL(APath);
  if LRawURL = '' then
  begin
    FLoading := False;
    FErrorText := 'This document cannot be fetched directly here. Use Read on GitHub to view it.';
    UpdateHeader;
    RenderBody;
    Exit;
  end;

  LReq := TJSXMLHttpRequest.new;
  FActiveRequest := LReq;
  LReq.open('GET', LRawURL, True);
  LReq.timeout := 20000;
  LReq.onload :=
    function(AEvent: TJSProgressEvent): Boolean
    begin
      Result := False;
      if FActiveRequest = LReq then
        FActiveRequest := nil;
      if (AGen <> FLoadGeneration) or not IsOpen then
        Exit;
      FLoading := False;
      if (LReq.status >= 200) and (LReq.status < 300) then
      begin
        FLoadedText := LReq.responseText;
        FNextOffset := 0;
        FErrorText := '';
        PutCachedText(APath, FLoadedText);
      end
      else
        FErrorText := 'Could not load this file right now (HTTP ' + IntToStr(LReq.status) +
          '). You can still open it on GitHub.';
      UpdateHeader;
      RenderBody;
    end;
  LReq.onerror :=
    function(AEvent: TJSProgressEvent): Boolean
    begin
      Result := False;
      if FActiveRequest = LReq then
        FActiveRequest := nil;
      if (AGen <> FLoadGeneration) or not IsOpen then
        Exit;
      FLoading := False;
      FErrorText := 'Network error while loading the document text. Try again or open it on GitHub.';
      UpdateHeader;
      RenderBody;
    end;
  LReq.ontimeout :=
    function(AEvent: TJSProgressEvent): Boolean
    begin
      Result := False;
      if FActiveRequest = LReq then
        FActiveRequest := nil;
      if (AGen <> FLoadGeneration) or not IsOpen then
        Exit;
      FLoading := False;
      FErrorText := 'Loading the document timed out. Try again or open it on GitHub.';
      UpdateHeader;
      RenderBody;
    end;
  try
    LReq.send;
  except
    if FActiveRequest = LReq then
      FActiveRequest := nil;
    FLoading := False;
    FErrorText := 'Could not start loading this document. Try opening it on GitHub.';
    UpdateHeader;
    RenderBody;
  end;
end;

procedure TOracleReaderModal.LoadViaLocalChunks(const APath: String;
  AOffset, AChunksLeft, AGen: Integer);
begin
  if not Assigned(FFetchLocalChunk) then
  begin
    FLoading := False;
    FLoadingMore := False;
    FErrorText := 'Document reader is unavailable in this mode.';
    UpdateHeader;
    RenderBody;
    Exit;
  end;
  FFetchLocalChunk(APath, AOffset,
    procedure(const AText: String; ANextOffset: Integer; const AError: String)
    begin
      if (AGen <> FLoadGeneration) or not IsOpen then
        Exit;
      if AError <> '' then
      begin
        FLoading := False;
        FLoadingMore := False;
        if FLoadedText = '' then
          FErrorText := AError;
        UpdateHeader;
        RenderBody;
        Exit;
      end;
      FLoadedText := FLoadedText + AText;
      if ANextOffset > AOffset then
        FNextOffset := ANextOffset
      else
        FNextOffset := 0;
      if (FNextOffset > 0) and (AChunksLeft > 1) then
      begin
        LoadViaLocalChunks(APath, FNextOffset, AChunksLeft - 1, AGen);
        Exit;
      end;
      FLoading := False;
      FLoadingMore := False;
      if FNextOffset = 0 then
        PutCachedText(APath, FLoadedText);
      UpdateHeader;
      RenderBody;
    end);
end;

procedure TOracleReaderModal.LoadMoreLocal;
var
  LGen: Integer;
begin
  if FLoadingMore or (FNextOffset <= 0) then
    Exit;
  FLoadingMore := True;
  LGen := FLoadGeneration;
  RenderBody;
  LoadViaLocalChunks(FCurrentPath, FNextOffset, CMaxInitialLocalChunks, LGen);
end;

procedure TOracleReaderModal.LoadDocument(const APath, AAnchor: String; APushHistory: Boolean);
var
  LCleanPath: String;
  LInlineAnchor: String;
  LCached: String;
  LLen: Integer;
  LBody: TJSHTMLElement;
begin
  LCleanPath := SplitPathAnchor(StringReplace(APath, '\', '/', [rfReplaceAll]), LInlineAnchor);
  if LCleanPath = '' then
    Exit;
  if APushHistory and (FCurrentPath <> '') and (FCurrentPath <> LCleanPath) then
  begin
    LLen := Length(FHistory);
    SetLength(FHistory, LLen + 1);
    FHistory[LLen] := FCurrentPath;
  end;
  FCurrentPath := LCleanPath;
  if AAnchor <> '' then
    FTargetAnchor := AAnchor
  else
    FTargetAnchor := LInlineAnchor;

  Inc(FLoadGeneration);
  CancelActiveRequest;
  FErrorText := '';
  FNextOffset := 0;
  FLoadingMore := False;

  if (FShellRenderer <> nil) and (FShellRenderer.Root <> nil) then
  begin
    LBody := FShellRenderer.ElementFor('reader-modal-body');
    if LBody <> nil then
      LBody.scrollTop := 0;
  end;

  if HasCachedText(FCurrentPath, LCached) then
  begin
    FLoading := False;
    FLoadedText := LCached;
    UpdateHeader;
    RenderBody;
    Exit;
  end;

  FLoading := True;
  FLoadedText := '';
  UpdateHeader;
  RenderBody;

  if FStaticOracle <> nil then
    LoadViaRawGitHub(FCurrentPath, FLoadGeneration)
  else
    LoadViaLocalChunks(FCurrentPath, 0, CMaxInitialLocalChunks, FLoadGeneration);
end;

procedure TOracleReaderModal.NavigateBack;
var
  LPrev: String;
begin
  if Length(FHistory) = 0 then
    Exit;
  LPrev := FHistory[High(FHistory)];
  SetLength(FHistory, Length(FHistory) - 1);
  LoadDocument(LPrev, '', False);
end;

procedure TOracleReaderModal.Open(const APath: String; AInvoker: TJSHTMLElement);
var
  LCleanPath: String;
  LAnchor: String;
  LCloseBtn: TJSHTMLElement;
begin
  LCleanPath := SplitPathAnchor(StringReplace(APath, '\', '/', [rfReplaceAll]), LAnchor);
  if LCleanPath = '' then
    Exit;

  if AInvoker <> nil then
    FInvoker := AInvoker
  else
    FInvoker := TJSHTMLElement(document.activeElement);

  FHistory := nil;
  FCurrentPath := LCleanPath;
  FTargetAnchor := LAnchor;

  if FModalHost = nil then
  begin
    FModalHost := NewNyxBrowserModalHost;
    FModalHost.OnDismiss := Close;
    FModalHost.Element.setAttribute('data-oracle-reader-modal', 'true');
    FBackdropClick := @OnBackdropClick;
    FModalHost.Element.addEventListener('click', FBackdropClick);
  end;

  MountShell;
  FModalHost.Show(NyxModal('Read ' + SavedSourceTitle(LCleanPath))
    .Viewport(92)
    .MaximumWidth(900)
    .MaximumHeight(840)
    .Sizing(nhfAvailableHeight));

  LoadDocument(LCleanPath, LAnchor, False);

  LCloseBtn := FShellRenderer.FocusFor('reader-close');
  if LCloseBtn <> nil then
    NyxFocusWithoutScroll(LCloseBtn);
end;

procedure TOracleReaderModal.Close;
var
  LReturnTo: TJSHTMLElement;
begin
  Inc(FLoadGeneration);
  CancelActiveRequest;
  if (FModalHost <> nil) and FModalHost.IsOpen then
    FModalHost.Hide;
  CleanupShell;
  LReturnTo := FInvoker;
  FInvoker := nil;
  if (LReturnTo <> nil) and document.body.contains(LReturnTo) then
    NyxFocusWithoutScroll(LReturnTo);
end;

end.
