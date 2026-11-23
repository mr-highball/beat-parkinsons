{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegallery;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses nyx.model, nyx.render.browser;

function HasIngredientGallery(const AIngredient: String): Boolean;
function IngredientThumbnailURL(const AIngredient: String): String;
procedure AddIngredientGallery(AParent: TNyxNode; const AIngredient: String;
  const AKey: String = '');
procedure BindIngredientGallery(ARenderer: TNyxBrowserRenderer; const AIngredient: String;
  const AKey: String = ''; AInitiallyEnlarged: Boolean = False);

implementation

uses SysUtils, Math, Web, nyx.types, parkinsonsoracle.ingredientguides;

function HasIngredientGallery(const AIngredient: String): Boolean;
begin
  Result := IngredientGuideIndex(AIngredient) >= 0;
end;

function IngredientThumbnailURL(const AIngredient: String): String;
var
  LIndex: Integer;
begin
  LIndex := IngredientGuideIndex(AIngredient);
  if LIndex < 0 then
  begin
    Exit('');
  end;
  Result := 'ingredients/' + IngredientThumbnailName(LIndex);
end;

procedure AddIngredientGallery(AParent: TNyxNode; const AIngredient: String; const AKey: String);
var
  LIndex: Integer;
  LPanel: TNyxNode;
  LTip: TNyxNode;
  LNav: TNyxNode;
begin
  LIndex := IngredientGuideIndex(AIngredient);
  if LIndex < 0 then
  begin
    Exit;
  end;
  LPanel := TNyxNode.Create(nkCard, 'ingredient-gallery' + AKey);
  LPanel.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-tip-toggle' + AKey)
    .Configure.Text('Shopping tip').Variant(nvSecondary).Done);
  LTip := TNyxNode.Create(nkColumn, 'ingredient-gallery-tip-detail' + AKey);
  LTip.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-tip' + AKey)
    .Configure.Text(CIngredientGuides[LIndex].Tip).Done);
  LTip.Add(TNyxNode.Create(nkLink, 'ingredient-gallery-tip-source' + AKey)
    .Configure.Text(CIngredientGuides[LIndex].TipSource)
    .LinkTo(CIngredientGuides[LIndex].TipURL).Done);
  LPanel.Add(LTip);
  LPanel.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-photo' + AKey)
    .Configure.AccessibleName('Enlarge ingredient photo').TouchBehavior(ntbPanY).Done);
  LNav := TNyxNode.Create(nkRow, 'ingredient-gallery-nav' + AKey);
  LNav.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-prev' + AKey)
    .Configure.Text('‹').AccessibleName('Previous photo').Variant(nvSecondary).Done);
  LNav.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-caption' + AKey));
  LNav.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-next' + AKey)
    .Configure.Text('›').AccessibleName('Next photo').Variant(nvSecondary).Done);
  LPanel.Add(LNav);
  LPanel.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-credit' + AKey));
  LPanel.Add(TNyxNode.Create(nkLink, 'ingredient-gallery-photo-source' + AKey)
    .Configure.Text('Photo credit').LinkTo(CIngredientGuides[LIndex].Frames[0].CreditURL).Done);
  AParent.Add(LPanel);
end;

procedure BindIngredientGallery(ARenderer: TNyxBrowserRenderer; const AIngredient: String;
  const AKey: String; AInitiallyEnlarged: Boolean);
var
  LIndex: Integer;
  LFrame: Integer;
  LPanel: TJSHTMLElement;
  LTipToggle: TJSHTMLElement;
  LTipDetail: TJSHTMLElement;
  LPhoto: TJSHTMLElement;
  LCredit: TJSHTMLElement;
  LSource: TJSHTMLAnchorElement;
  LCaption: TJSHTMLElement;
  LCaptionNode: TNyxNode;
  LCreditNode: TNyxNode;
  LSourceNode: TNyxNode;
  LPointer: Integer;
  LStartX: Double;
  LStartY: Double;
  LWasSwiped: Boolean;
  LEnlarged: Boolean;
  LHandler: TJSEventHandler;

  procedure UpdatePhotoLabel;
  var
    LAction: String;
  begin
    if LEnlarged then
      LAction := 'Reduce photo size'
    else
      LAction := 'Enlarge photo';
    LPhoto.setAttribute('aria-label', LAction + ' · ' +
      CIngredientGuides[LIndex].Frames[LFrame].Description);
    LPhoto.setAttribute('aria-expanded', LowerCase(BoolToStr(LEnlarged, True)));
    LPhoto.setAttribute('title', LAction);
  end;

  procedure ShowFrame(AFrame: Integer);
  var
    LItem: TGalleryFrame;
    LCaptionText: String;
  begin
    LFrame := (AFrame + Length(CIngredientGuides[LIndex].Frames)) mod
      Length(CIngredientGuides[LIndex].Frames);
    LItem := CIngredientGuides[LIndex].Frames[LFrame];
    LPhoto.style.setProperty('background-image', 'url("ingredients/' + LItem.Asset + '")');
    if LItem.Column >= 0 then
    begin
      LPhoto.style.setProperty('background-size',
        IntToStr(LItem.GridColumns * 100) + '% ' + IntToStr(LItem.GridRows * 100) + '%');
      LPhoto.style.setProperty('background-position',
        'calc(' + IntToStr(LItem.Column * 100) + '% / ' + IntToStr(LItem.GridColumns - 1) + ') ' +
        'calc(' + IntToStr(LItem.Row * 100) + '% / ' + IntToStr(LItem.GridRows - 1) + ')');
    end
    else
    begin
      LPhoto.style.setProperty('background-size', 'contain');
      LPhoto.style.setProperty('background-position', 'center');
    end;
    UpdatePhotoLabel;
    LCaptionText := LItem.Caption + ' · ' + IntToStr(LFrame + 1) + ' of ' +
      IntToStr(Length(CIngredientGuides[LIndex].Frames));
    LCaptionNode.Configure.Text(LCaptionText);
    LCreditNode.Configure.Text(LItem.Credit);
    LSourceNode.Configure.LinkTo(LItem.CreditURL);
    LCaption.textContent := LCaptionText;
    LCredit.textContent := LItem.Credit;
    LSource.hidden := LItem.CreditURL = '';
    LSource.href := LItem.CreditURL;
  end;

begin
  LIndex := IngredientGuideIndex(AIngredient);
  if LIndex < 0 then
  begin
    Exit;
  end;
  LPointer := -1;
  LWasSwiped := False;
  LEnlarged := AInitiallyEnlarged;
  LPanel := ARenderer.ElementFor('ingredient-gallery' + AKey);
  LPanel.classList.add('oracle-ingredient-gallery');
  LPanel.setAttribute('role', 'region');
  LPanel.setAttribute('aria-label', AIngredient + ' photos');
  LPanel.setAttribute('data-enlarged', LowerCase(BoolToStr(LEnlarged, True)));
  LTipToggle := ARenderer.ElementFor('ingredient-gallery-tip-toggle' + AKey);
  LTipDetail := ARenderer.ElementFor('ingredient-gallery-tip-detail' + AKey);
  LTipDetail.hidden := True;
  LTipDetail.id := 'ingredient-gallery-tip-detail' + AKey;
  LTipToggle.setAttribute('aria-controls', LTipDetail.id);
  LTipToggle.setAttribute('aria-expanded', 'false');
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      LTipDetail.hidden := not LTipDetail.hidden;
      LTipToggle.setAttribute('aria-expanded', LowerCase(BoolToStr(not LTipDetail.hidden, True)));
      Result := True;
    end;
  LTipToggle.addEventListener('click', LHandler);

  LPhoto := ARenderer.ElementFor('ingredient-gallery-photo' + AKey);
  LPhoto.classList.add('oracle-gallery-photo');
  LCredit := ARenderer.ElementFor('ingredient-gallery-credit' + AKey);
  LCaption := ARenderer.ElementFor('ingredient-gallery-caption' + AKey);
  LCaptionNode := ARenderer.Root.Find('ingredient-gallery-caption' + AKey);
  LCreditNode := ARenderer.Root.Find('ingredient-gallery-credit' + AKey);
  LSourceNode := ARenderer.Root.Find('ingredient-gallery-photo-source' + AKey);
  LSource := TJSHTMLAnchorElement(ARenderer.ElementFor('ingredient-gallery-photo-source' + AKey));
  LSource.setAttribute('target', '_blank');
  LSource.setAttribute('rel', 'noopener');
  ARenderer.ElementFor('ingredient-gallery-tip-source' + AKey).setAttribute('target', '_blank');
  ARenderer.ElementFor('ingredient-gallery-tip-source' + AKey).setAttribute('rel', 'noopener');
  LCaption.setAttribute('aria-live', 'polite');
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      if LWasSwiped then
      begin
        LWasSwiped := False;
        Exit(True);
      end;
      LEnlarged := not LEnlarged;
      LPanel.setAttribute('data-enlarged', LowerCase(BoolToStr(LEnlarged, True)));
      UpdatePhotoLabel;
      Result := True;
    end;
  LPhoto.addEventListener('click', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ShowFrame(LFrame - 1);
      Result := True;
    end;
  ARenderer.ElementFor('ingredient-gallery-prev' + AKey).addEventListener('click', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ShowFrame(LFrame + 1);
      Result := True;
    end;
  ARenderer.ElementFor('ingredient-gallery-next' + AKey).addEventListener('click', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      LWasSwiped := False;
      case TJSKeyboardEvent(AEvent).key of
        'ArrowLeft': ShowFrame(LFrame - 1);
        'ArrowRight': ShowFrame(LFrame + 1);
      else
        Exit(True);
      end;
      AEvent.preventDefault;
      Result := False;
    end;
  LPanel.addEventListener('keydown', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LEvent: TJSPointerEvent;
    begin
      Result := True;
      LEvent := TJSPointerEvent(AEvent);
      if LPointer >= 0 then
      begin
        Exit;
      end;
      LWasSwiped := False;
      if LEvent.pointerType <> 'touch' then
      begin
        Exit;
      end;
      LPointer := LEvent.pointerId;
      LStartX := LEvent.clientX;
      LStartY := LEvent.clientY;
      if LEvent.isTrusted then
      begin
        LPhoto.setPointerCapture(LPointer);
      end;
    end;
  LPhoto.addEventListener('pointerdown', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LEvent: TJSPointerEvent;
      LDelta: Double;
    begin
      LEvent := TJSPointerEvent(AEvent);
      if LPointer = LEvent.pointerId then
      begin
        LDelta := LEvent.clientX - LStartX;
        if (Abs(LDelta) > 32) and (Abs(LDelta) > 1.2 * Abs(LEvent.clientY - LStartY)) then
        begin
          LPointer := -1;
          LWasSwiped := True;
          ShowFrame(LFrame - Sign(LDelta));
        end;
      end;
      Result := True;
    end;
  LPhoto.addEventListener('pointermove', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      LPointer := -1;
      Result := True;
    end;
  LPhoto.addEventListener('pointerup', LHandler);
  LPhoto.addEventListener('pointercancel', LHandler);
  ShowFrame(0);
end;

end.
