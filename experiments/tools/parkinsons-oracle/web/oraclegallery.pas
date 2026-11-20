{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit oraclegallery;

{$mode delphi}{$H+}{$codepage utf8}

interface

uses nyx.model, nyx.render.browser;

function HasIngredientGallery(const AIngredient: String): Boolean;
procedure AddIngredientGallery(AParent: TNyxNode; const AIngredient: String);
procedure BindIngredientGallery(ARenderer: TNyxBrowserRenderer; const AIngredient: String);

implementation

uses SysUtils, Math, Web, nyx.types, parkinsonsoracle.ingredientguides;

function HasIngredientGallery(const AIngredient: String): Boolean;
begin
  Result := IngredientGuideIndex(AIngredient) >= 0;
end;

procedure AddIngredientGallery(AParent: TNyxNode; const AIngredient: String);
var
  LIndex: Integer;
  LPanel: TNyxNode;
  LNav: TNyxNode;
begin
  LIndex := IngredientGuideIndex(AIngredient);
  if LIndex < 0 then
  begin
    Exit;
  end;
  LPanel := TNyxNode.Create(nkCard, 'ingredient-gallery');
  LPanel.Add(TNyxNode.Create(nkHeading, 'ingredient-gallery-title')
    .Configure.Text('Ingredient photos and tips').Done);
  LPanel.Add(TNyxNode.Create(nkPanel, 'ingredient-gallery-photo')
    .Configure.TouchBehavior(ntbPanY).Done);
  LPanel.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-caption'));
  LNav := TNyxNode.Create(nkRow, 'ingredient-gallery-nav');
  LNav.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-prev')
    .Configure.Text('‹ Previous photo').Variant(nvSecondary).Done);
  LNav.Add(TNyxNode.Create(nkButton, 'ingredient-gallery-next')
    .Configure.Text('Next photo ›').Variant(nvSecondary).Done);
  LPanel.Add(LNav);
  LPanel.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-credit'));
  LPanel.Add(TNyxNode.Create(nkLink, 'ingredient-gallery-photo-source')
    .Configure.Text('Photo credit').LinkTo(CIngredientGuides[LIndex].TipURL).Done);
  LPanel.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-tip-title')
    .Configure.Text('Shopping tip').Done);
  LPanel.Add(TNyxNode.Create(nkLabel, 'ingredient-gallery-tip')
    .Configure.Text(CIngredientGuides[LIndex].Tip).Done);
  LPanel.Add(TNyxNode.Create(nkLink, 'ingredient-gallery-tip-source')
    .Configure.Text(CIngredientGuides[LIndex].TipSource)
    .LinkTo(CIngredientGuides[LIndex].TipURL).Done);
  AParent.Add(LPanel);
end;

procedure BindIngredientGallery(ARenderer: TNyxBrowserRenderer; const AIngredient: String);
var
  LIndex: Integer;
  LFrame: Integer;
  LPhoto: TJSHTMLElement;
  LCredit: TJSHTMLElement;
  LSource: TJSHTMLAnchorElement;
  LCaption: TJSHTMLElement;
  LPointer: Integer;
  LStartX: Double;
  LStartY: Double;
  LHandler: TJSEventHandler;

  procedure ShowFrame(AFrame: Integer);
  var
    LItem: TGalleryFrame;
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
    LPhoto.setAttribute('aria-label', LItem.Description);
    LCaption.textContent := LItem.Caption + ' · ' + IntToStr(LFrame + 1) + ' of ' +
      IntToStr(Length(CIngredientGuides[LIndex].Frames));
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
  LPhoto := ARenderer.ElementFor('ingredient-gallery-photo');
  LCredit := ARenderer.ElementFor('ingredient-gallery-credit');
  LCaption := ARenderer.ElementFor('ingredient-gallery-caption');
  LSource := TJSHTMLAnchorElement(ARenderer.ElementFor('ingredient-gallery-photo-source'));
  LSource.setAttribute('target', '_blank');
  LSource.setAttribute('rel', 'noopener');
  ARenderer.ElementFor('ingredient-gallery-tip-source').setAttribute('target', '_blank');
  ARenderer.ElementFor('ingredient-gallery-tip-source').setAttribute('rel', 'noopener');
  LPhoto.setAttribute('role', 'img');
  LPhoto.setAttribute('tabindex', '0');
  LCaption.setAttribute('aria-live', 'polite');
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ShowFrame(LFrame - 1);
      Result := True;
    end;
  ARenderer.ElementFor('ingredient-gallery-prev').addEventListener('click', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      ShowFrame(LFrame + 1);
      Result := True;
    end;
  ARenderer.ElementFor('ingredient-gallery-next').addEventListener('click', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    begin
      case TJSKeyboardEvent(AEvent).key of
        'ArrowLeft': ShowFrame(LFrame - 1);
        'ArrowRight': ShowFrame(LFrame + 1);
      else
        Exit(True);
      end;
      AEvent.preventDefault;
      Result := False;
    end;
  LPhoto.addEventListener('keydown', LHandler);
  LHandler :=
    function(AEvent: TEventListenerEvent): Boolean
    var
      LEvent: TJSPointerEvent;
    begin
      Result := True;
      LEvent := TJSPointerEvent(AEvent);
      if (LEvent.pointerType <> 'touch') or (LPointer >= 0) then
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
        if (Abs(LDelta) > 40) and (Abs(LDelta) > 1.2 * Abs(LEvent.clientY - LStartY)) then
        begin
          LPointer := -1;
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
