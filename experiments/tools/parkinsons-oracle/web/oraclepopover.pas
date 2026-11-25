{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclepopover;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses Web;

procedure ShowFloatingPopover(AAnchor, AHost: TJSHTMLElement;
  const AKind, ATitle, ABody, ASourceLabel, ASourceURL: String;
  AAutoFadeMs: Integer; AIsHoverMode: Boolean);
procedure HideFloatingPopover(AFocusBack: Boolean = False);
procedure BindShoppingTipPopover(AButton: TJSHTMLElement;
  const AIngredient, ATip, ASourceLabel, ASourceURL: String);
procedure BindQuestionPopover(ABox, AButton: TJSHTMLElement);

implementation

uses SysUtils, Math, JS, oraclevocab;

const
  CQuestionPopupTitle = 'Research question';
  CQuestionPopupBody =
    'This is a question we are testing through published research and lived reports—not a proven medical claim.';
  CFadeDurationMs = 650;
  CQuestionTapFadeMs = 6800;
  CHoverLeaveDelayMs = 220;
  CResumeFadeMs = 3200;

var
  GPopover: TJSHTMLElement = nil;
  GPopoverTitle: TJSHTMLElement = nil;
  GPopoverBody: TJSHTMLElement = nil;
  GPopoverSource: TJSHTMLAnchorElement = nil;
  GPopoverClose: TJSHTMLElement = nil;
  GPopoverArrow: TJSHTMLElement = nil;
  GActiveAnchor: TJSHTMLElement = nil;
  GActiveHost: TJSHTMLElement = nil;
  GPopoverSeq: Integer = 0;
  GFadeTimer: NativeInt = 0;
  GHideTimer: NativeInt = 0;
  GHoverCloseTimer: NativeInt = 0;
  GIsHoverMode: Boolean = False;
  GPinnedByClick: Boolean = False;
  GOpenScrollY: Double = 0;
  GGlobalBound: Boolean = False;

procedure BindElEvent(AElement: TJSEventTarget; const AEventName: String;
  AHandler: TJSEventHandler);
begin
  if AElement <> nil then
    AElement.addEventListener(AEventName, AHandler);
end;

function HasTextSelection: Boolean;
var
  LSelected: String;
begin
  LSelected := '';
  asm
    var s = window.getSelection ? window.getSelection() : null;
    if (s) LSelected = String(s.toString() || '');
  end;
  Result := Trim(LSelected) <> '';
end;

function CurrentScrollY: Double;
var
  LY: Double;
begin
  LY := 0;
  asm
    LY = window.scrollY || window.pageYOffset || 0;
  end;
  Result := LY;
end;

procedure ClearTimers;
begin
  if GFadeTimer <> 0 then
  begin
    window.clearTimeout(GFadeTimer);
    GFadeTimer := 0;
  end;
  if GHideTimer <> 0 then
  begin
    window.clearTimeout(GHideTimer);
    GHideTimer := 0;
  end;
  if GHoverCloseTimer <> 0 then
  begin
    window.clearTimeout(GHoverCloseTimer);
    GHoverCloseTimer := 0;
  end;
end;

procedure ResetAnchorAria;
begin
  if GActiveAnchor <> nil then
    GActiveAnchor.setAttribute('aria-expanded', 'false');
end;

procedure HideFloatingPopover(AFocusBack: Boolean);
var
  LPrevAnchor: TJSHTMLElement;
begin
  Inc(GPopoverSeq);
  ClearTimers;
  LPrevAnchor := GActiveAnchor;
  ResetAnchorAria;
  GActiveAnchor := nil;
  GActiveHost := nil;
  GIsHoverMode := False;
  GPinnedByClick := False;
  if GPopover <> nil then
  begin
    GPopover.setAttribute('data-visible', 'false');
    GPopover.setAttribute('data-fading', 'false');
    GPopover.hidden := True;
  end;
  if AFocusBack and (LPrevAnchor <> nil) then
  begin
    try
      LPrevAnchor.focus;
    except
    end;
  end;
end;

procedure ScheduleAutoFade(ADelayMs: Integer);
var
  LSeq: Integer;
begin
  if ADelayMs <= 0 then
    Exit;
  if GFadeTimer <> 0 then
  begin
    window.clearTimeout(GFadeTimer);
    GFadeTimer := 0;
  end;
  if GHideTimer <> 0 then
  begin
    window.clearTimeout(GHideTimer);
    GHideTimer := 0;
  end;
  LSeq := GPopoverSeq;
  GFadeTimer := window.setTimeout(
    procedure
    begin
      GFadeTimer := 0;
      if (LSeq <> GPopoverSeq) or (GPopover = nil) or GPopover.hidden then
        Exit;
      GPopover.setAttribute('data-fading', 'true');
      GHideTimer := window.setTimeout(
        procedure
        begin
          GHideTimer := 0;
          if LSeq = GPopoverSeq then
            HideFloatingPopover(False);
        end, CFadeDurationMs);
    end, ADelayMs);
end;

procedure ScheduleHoverClose;
var
  LSeq: Integer;
begin
  if (not GIsHoverMode) or GPinnedByClick then
    Exit;
  if GHoverCloseTimer <> 0 then
    window.clearTimeout(GHoverCloseTimer);
  LSeq := GPopoverSeq;
  GHoverCloseTimer := window.setTimeout(
    procedure
    begin
      GHoverCloseTimer := 0;
      if (LSeq = GPopoverSeq) and GIsHoverMode and (not GPinnedByClick) then
        HideFloatingPopover(False);
    end, CHoverLeaveDelayMs);
end;

procedure PauseFade;
begin
  if GFadeTimer <> 0 then
  begin
    window.clearTimeout(GFadeTimer);
    GFadeTimer := 0;
  end;
  if GHideTimer <> 0 then
  begin
    window.clearTimeout(GHideTimer);
    GHideTimer := 0;
  end;
  if GHoverCloseTimer <> 0 then
  begin
    window.clearTimeout(GHoverCloseTimer);
    GHoverCloseTimer := 0;
  end;
  if (GPopover <> nil) and (not GPopover.hidden) then
  begin
    GPopover.setAttribute('data-fading', 'false');
    GPopover.setAttribute('data-visible', 'true');
  end;
end;

procedure PositionPopover(AAnchor, AHost: TJSHTMLElement);
var
  LAnchorRect: TJSDOMRect;
  LVertRect: TJSDOMRect;
  LPopRect: TJSDOMRect;
  LViewportW: Double;
  LViewportH: Double;
  LLeft: Double;
  LTop: Double;
  LArrowX: Double;
  LPlacement: String;
  LMargin: Double;
  LGap: Double;
begin
  if (GPopover = nil) or (AAnchor = nil) then
    Exit;
  LMargin := 12;
  LGap := 10;
  LViewportW := window.innerWidth;
  LViewportH := window.innerHeight;
  LAnchorRect := AAnchor.getBoundingClientRect;
  if AHost <> nil then
    LVertRect := AHost.getBoundingClientRect
  else
    LVertRect := LAnchorRect;
  LPopRect := GPopover.getBoundingClientRect;

  if (LVertRect.bottom + LGap + LPopRect.height <= LViewportH - LMargin) or
    (LVertRect.top - LGap - LPopRect.height < LMargin) then
  begin
    LPlacement := 'bottom';
    LTop := LVertRect.bottom + LGap;
    if LTop + LPopRect.height > LViewportH - LMargin then
      LTop := Max(LMargin, LViewportH - LMargin - LPopRect.height);
  end
  else
  begin
    LPlacement := 'top';
    LTop := LVertRect.top - LGap - LPopRect.height;
    if LTop < LMargin then
      LTop := LMargin;
  end;

  LLeft := (LAnchorRect.left + LAnchorRect.right) / 2 - LPopRect.width / 2;
  if LLeft + LPopRect.width > LViewportW - LMargin then
    LLeft := LViewportW - LMargin - LPopRect.width;
  if LLeft < LMargin then
    LLeft := LMargin;

  LArrowX := (LAnchorRect.left + LAnchorRect.right) / 2 - LLeft;
  if LArrowX < 18 then
    LArrowX := 18;
  if LArrowX > LPopRect.width - 18 then
    LArrowX := LPopRect.width - 18;

  GPopover.setAttribute('data-placement', LPlacement);
  GPopover.style.setProperty('left', IntToStr(Round(LLeft)) + 'px');
  GPopover.style.setProperty('top', IntToStr(Round(LTop)) + 'px');
  if GPopoverArrow <> nil then
    GPopoverArrow.style.setProperty('left', IntToStr(Round(LArrowX)) + 'px');
end;

procedure EnsurePopoverDOM;
var
  LHead: TJSHTMLElement;
  LHandler: TJSEventHandler;
begin
  if GPopover <> nil then
    Exit;

  GPopover := TJSHTMLElement(document.createElement('div'));
  GPopover.id := 'oracle-floating-popover';
  GPopover.className := 'oracle-floating-popover';
  GPopover.setAttribute('role', 'status');
  GPopover.setAttribute('aria-live', 'polite');
  GPopover.setAttribute('data-visible', 'false');
  GPopover.setAttribute('data-fading', 'false');
  GPopover.hidden := True;

  GPopoverArrow := TJSHTMLElement(document.createElement('span'));
  GPopoverArrow.className := 'oracle-floating-popover-arrow';
  GPopoverArrow.setAttribute('aria-hidden', 'true');
  GPopover.appendChild(GPopoverArrow);

  LHead := TJSHTMLElement(document.createElement('div'));
  LHead.className := 'oracle-floating-popover-head';

  GPopoverTitle := TJSHTMLElement(document.createElement('span'));
  GPopoverTitle.className := 'oracle-floating-popover-title';
  LHead.appendChild(GPopoverTitle);

  GPopoverClose := TJSHTMLElement(document.createElement('button'));
  GPopoverClose.setAttribute('type', 'button');
  GPopoverClose.className := 'oracle-floating-popover-close';
  GPopoverClose.setAttribute('aria-label', 'Dismiss popup');
  GPopoverClose.textContent := '×';
  LHead.appendChild(GPopoverClose);
  GPopover.appendChild(LHead);

  GPopoverBody := TJSHTMLElement(document.createElement('p'));
  GPopoverBody.className := 'oracle-floating-popover-body';
  GPopover.appendChild(GPopoverBody);

  GPopoverSource := TJSHTMLAnchorElement(document.createElement('a'));
  GPopoverSource.className := 'oracle-floating-popover-source';
  GPopoverSource.setAttribute('target', '_blank');
  GPopoverSource.setAttribute('rel', 'noopener');
  GPopoverSource.hidden := True;
  GPopover.appendChild(GPopoverSource);

  document.body.appendChild(GPopover);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      AEvent.stopPropagation;
      HideFloatingPopover(True);
      Result := False;
    end;
  BindElEvent(GPopoverClose, 'click', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TJSPointerEvent(AEvent).pointerType = 'mouse' then
        PauseFade;
      Result := True;
    end;
  BindElEvent(GPopover, 'pointerenter', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TJSPointerEvent(AEvent).pointerType = 'mouse' then
      begin
        if GIsHoverMode and (not GPinnedByClick) then
          ScheduleHoverClose
        else
          ScheduleAutoFade(CResumeFadeMs);
      end;
      Result := True;
    end;
  BindElEvent(GPopover, 'pointerleave', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      PauseFade;
      Result := True;
    end;
  BindElEvent(GPopover, 'focusin', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LSeq: Integer;
    begin
      LSeq := GPopoverSeq;
      window.setTimeout(
        procedure
        begin
          if (LSeq <> GPopoverSeq) or (GPopover = nil) or GPopover.hidden then
            Exit;
          if (document.activeElement = nil) or (not GPopover.contains(document.activeElement)) then
          begin
            if GIsHoverMode and (not GPinnedByClick) then
              ScheduleHoverClose
            else
              ScheduleAutoFade(CResumeFadeMs);
          end;
        end, 40);
      Result := True;
    end;
  BindElEvent(GPopover, 'focusout', LHandler);

  if not GGlobalBound then
  begin
    GGlobalBound := True;

    LHandler :=
      function(AEvent: TEventListenerEvent): Boolean
      var
        LTarget: TJSNode;
      begin
        if (GPopover = nil) or GPopover.hidden then
          Exit(True);
        LTarget := TJSNode(AEvent.target);
        if (LTarget <> nil) and
          (GPopover.contains(LTarget) or
           ((GActiveAnchor <> nil) and GActiveAnchor.contains(LTarget)) or
           ((GActiveHost <> nil) and GActiveHost.contains(LTarget))) then
          Exit(True);
        HideFloatingPopover(False);
        Result := True;
      end;
    BindElEvent(document, 'pointerdown', LHandler);

    LHandler :=
      function(AEvent: TEventListenerEvent): Boolean
      var
        LFocusBack: Boolean;
      begin
        if (GPopover <> nil) and (not GPopover.hidden) and
          (TJSKeyboardEvent(AEvent).key = 'Escape') then
        begin
          LFocusBack := (document.activeElement <> nil) and GPopover.contains(document.activeElement);
          HideFloatingPopover(LFocusBack);
          AEvent.preventDefault;
          Exit(False);
        end;
        Result := True;
      end;
    BindElEvent(document, 'keydown', LHandler);

    LHandler :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        if (GPopover <> nil) and (not GPopover.hidden) then
        begin
          if Abs(CurrentScrollY - GOpenScrollY) > 24 then
            HideFloatingPopover(False)
          else if GActiveAnchor <> nil then
            PositionPopover(GActiveAnchor, GActiveHost);
        end;
        Result := True;
      end;
    BindElEvent(window, 'scroll', LHandler);

    LHandler :=
      function(AEvent: TEventListenerEvent): Boolean
      begin
        if (GPopover <> nil) and (not GPopover.hidden) then
          HideFloatingPopover(False);
        Result := True;
      end;
    BindElEvent(window, 'resize', LHandler);
  end;
end;

procedure ShowFloatingPopover(AAnchor, AHost: TJSHTMLElement;
  const AKind, ATitle, ABody, ASourceLabel, ASourceURL: String;
  AAutoFadeMs: Integer; AIsHoverMode: Boolean);
var
  LSeq: Integer;
begin
  if (AAnchor = nil) or (Trim(ABody) = '') then
    Exit;
  EnsurePopoverDOM;
  Inc(GPopoverSeq);
  LSeq := GPopoverSeq;
  ClearTimers;
  ResetAnchorAria;

  GActiveAnchor := AAnchor;
  GActiveHost := AHost;
  GIsHoverMode := AIsHoverMode;
  GPinnedByClick := not AIsHoverMode;
  GOpenScrollY := CurrentScrollY;

  GPopover.setAttribute('data-kind', AKind);
  GPopover.setAttribute('data-fading', 'false');
  GPopover.setAttribute('data-visible', 'false');
  GPopoverTitle.textContent := ATitle;
  GPopoverBody.textContent := ABody;

  if Trim(ASourceURL) <> '' then
  begin
    if Trim(ASourceLabel) <> '' then
      GPopoverSource.textContent := 'Source: ' + ASourceLabel
    else
      GPopoverSource.textContent := 'Source';
    GPopoverSource.href := ASourceURL;
    GPopoverSource.hidden := False;
  end
  else
  begin
    GPopoverSource.textContent := '';
    GPopoverSource.removeAttribute('href');
    GPopoverSource.hidden := True;
  end;

  GPopover.hidden := False;
  PositionPopover(AAnchor, AHost);
  AAnchor.setAttribute('aria-expanded', 'true');

  window.requestAnimationFrame(
    procedure(ATime: Double)
    begin
      if (LSeq = GPopoverSeq) and (GPopover <> nil) and (not GPopover.hidden) then
        GPopover.setAttribute('data-visible', 'true');
    end);

  if AAutoFadeMs > 0 then
    ScheduleAutoFade(AAutoFadeMs);
end;

function ComputeTipReadMs(const ATip: String): Integer;
begin
  Result := 6500 + Length(ATip) * 28;
  if Result < 7500 then
    Result := 7500
  else if Result > 11500 then
    Result := 11500;
end;

procedure BindShoppingTipPopover(AButton: TJSHTMLElement;
  const AIngredient, ATip, ASourceLabel, ASourceURL: String);
var
  LHandler: TJSEventHandler;
  LTitle: String;
  LReadMs: Integer;
begin
  if (AButton = nil) or (Trim(ATip) = '') then
    Exit;
  AButton.setAttribute('aria-haspopup', 'dialog');
  AButton.setAttribute('aria-expanded', 'false');
  LTitle := 'Shopping tip · ' + Capitalized(AIngredient);
  LReadMs := ComputeTipReadMs(ATip);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      AEvent.stopPropagation;
      if (GPopover <> nil) and (not GPopover.hidden) and (GActiveAnchor = AButton) then
        HideFloatingPopover(False)
      else
        ShowFloatingPopover(AButton, AButton, 'tip', LTitle, ATip,
          ASourceLabel, ASourceURL, LReadMs, False);
      Result := True;
    end;
  BindElEvent(AButton, 'click', LHandler);
end;

procedure BindQuestionPopover(ABox, AButton: TJSHTMLElement);
var
  LHandler: TJSEventHandler;
begin
  if (ABox = nil) or (AButton = nil) then
    Exit;
  AButton.setAttribute('aria-haspopup', 'dialog');
  AButton.setAttribute('aria-expanded', 'false');
  ABox.setAttribute('title', '');

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TJSPointerEvent(AEvent).pointerType <> 'mouse' then
        Exit(True);
      if (GPopover <> nil) and (not GPopover.hidden) and (GActiveAnchor = AButton) then
      begin
        PauseFade;
        Exit(True);
      end;
      ShowFloatingPopover(AButton, ABox, 'question', CQuestionPopupTitle,
        CQuestionPopupBody, '', '', 0, True);
      Result := True;
    end;
  BindElEvent(ABox, 'pointerenter', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if TJSPointerEvent(AEvent).pointerType <> 'mouse' then
        Exit(True);
      if (GPopover <> nil) and (not GPopover.hidden) and (GActiveAnchor = AButton) and
        GIsHoverMode and (not GPinnedByClick) then
        ScheduleHoverClose;
      Result := True;
    end;
  BindElEvent(ABox, 'pointerleave', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if HasTextSelection then
        Exit(True);
      AEvent.stopPropagation;
      if (GPopover <> nil) and (not GPopover.hidden) and (GActiveAnchor = AButton) and
        GPinnedByClick then
        HideFloatingPopover(False)
      else
        ShowFloatingPopover(AButton, ABox, 'question', CQuestionPopupTitle,
          CQuestionPopupBody, '', '', CQuestionTapFadeMs, False);
      Result := True;
    end;
  BindElEvent(ABox, 'click', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if (GPopover = nil) or GPopover.hidden or (GActiveAnchor <> AButton) then
        ShowFloatingPopover(AButton, ABox, 'question', CQuestionPopupTitle,
          CQuestionPopupBody, '', '', 0, True);
      Result := True;
    end;
  BindElEvent(AButton, 'focus', LHandler);

  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if (GPopover <> nil) and (not GPopover.hidden) and (GActiveAnchor = AButton) and
        GIsHoverMode and (not GPinnedByClick) then
        ScheduleHoverClose;
      Result := True;
    end;
  BindElEvent(AButton, 'blur', LHandler);
end;

end.
