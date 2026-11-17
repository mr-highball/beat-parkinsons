{ Copyright (c) 2026 beat-parkinsons contributors. All rights reserved. }
unit foodexperiment.winocr;

{$mode delphi}
{$H+}

interface

uses
  Windows;

type
  TWindowsOcr = class
  private
    FInitialized: Boolean;
    FDecoder: IUnknown;
    FEngine: IUnknown;
    FMaxDimension: Cardinal;
    function RecognizeBitmap(const ABitmap: IUnknown; AComposite: Boolean): UTF8String;
    function RecognizeFrame(const AFrame: IUnknown): UTF8String;
  public
    constructor Create(const ALanguage: UnicodeString);
    destructor Destroy; override;
    function Recognize(const AImagePath: UnicodeString): UTF8String;
  end;

implementation

uses
  Math, SysUtils;

type
  THString = Pointer;

  TBitmapBounds = record
    X: Cardinal;
    Y: Cardinal;
    Width: Cardinal;
    Height: Cardinal;
  end;

  TBitmapPlaneDescription = record
    StartIndex: Integer;
    Width: Integer;
    Height: Integer;
    Stride: Integer;
  end;

  PBgraPixel = ^TBgraPixel;
  TBgraPixel = packed record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Alpha: Byte;
  end;

  { WinRT interface prefixes for the calls below. IAsyncOperation<T> has the
    same ABI here for each T because all three results are interface pointers. }
  IInspectable = interface(IUnknown)
    ['{AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90}']
    function GetIids(out ACount: Cardinal; out AIids: Pointer): HResult; stdcall;
    function GetRuntimeClassName(out AName: THString): HResult; stdcall;
    function GetTrustLevel(out ALevel: Integer): HResult; stdcall;
  end;

  IAsyncInfo = interface(IInspectable)
    ['{00000036-0000-0000-C000-000000000046}']
    function GetId(out AId: Cardinal): HResult; stdcall;
    function GetStatus(out AStatus: Integer): HResult; stdcall;
  end;

  IObjectOperation = interface(IInspectable)
    function SetCompleted(const AHandler: IUnknown): HResult; stdcall;
    function GetCompleted(out AHandler: IUnknown): HResult; stdcall;
    function GetResults(out AResult: IUnknown): HResult; stdcall;
  end;

  ILanguageFactory = interface(IInspectable)
    ['{9B0252AC-0C27-44F8-B792-9793FB66C63E}']
    function CreateLanguage(ATag: THString; out ALanguage: IUnknown): HResult; stdcall;
  end;

  IBitmapDecoderStatics = interface(IInspectable)
    ['{438CCB26-BCEF-4E95-BAD6-23A822E58D01}']
    function BmpDecoderId(out AId: TGUID): HResult; stdcall;
    function JpegDecoderId(out AId: TGUID): HResult; stdcall;
    function PngDecoderId(out AId: TGUID): HResult; stdcall;
    function TiffDecoderId(out AId: TGUID): HResult; stdcall;
    function GifDecoderId(out AId: TGUID): HResult; stdcall;
    function JpegXRDecoderId(out AId: TGUID): HResult; stdcall;
    function IcoDecoderId(out AId: TGUID): HResult; stdcall;
    function GetDecoderInformationEnumerator(out AResult: IUnknown): HResult; stdcall;
    function CreateAsync(const AStream: IUnknown;
      out AOperation: IObjectOperation): HResult; stdcall;
  end;

  IBitmapDecoder = interface(IInspectable)
    ['{ACEF22BA-1D74-4C91-9DFC-9620745233E6}']
    function GetBitmapContainerProperties(out AProperties: IUnknown): HResult; stdcall;
    function GetDecoderInformation(out AInformation: IUnknown): HResult; stdcall;
    function GetFrameCount(out ACount: Cardinal): HResult; stdcall;
    function GetPreviewAsync(out AOperation: IObjectOperation): HResult; stdcall;
    function GetFrameAsync(AIndex: Cardinal; out AOperation: IObjectOperation): HResult; stdcall;
  end;

  IBitmapFrame = interface(IInspectable)
    ['{72A49A1C-8081-438D-91BC-94ECFC8185C6}']
    function GetThumbnailAsync(out AOperation: IObjectOperation): HResult; stdcall;
    function GetBitmapProperties(out AProperties: IUnknown): HResult; stdcall;
    function GetBitmapPixelFormat(out AFormat: Integer): HResult; stdcall;
    function GetBitmapAlphaMode(out AMode: Integer): HResult; stdcall;
    function GetDpiX(out AValue: Double): HResult; stdcall;
    function GetDpiY(out AValue: Double): HResult; stdcall;
    function GetPixelWidth(out AValue: Cardinal): HResult; stdcall;
    function GetPixelHeight(out AValue: Cardinal): HResult; stdcall;
  end;

  IBitmapTransform = interface(IInspectable)
    ['{AE755344-E268-4D35-ADCF-E995D31A8D34}']
    function GetScaledWidth(out AValue: Cardinal): HResult; stdcall;
    function SetScaledWidth(AValue: Cardinal): HResult; stdcall;
    function GetScaledHeight(out AValue: Cardinal): HResult; stdcall;
    function SetScaledHeight(AValue: Cardinal): HResult; stdcall;
    function GetInterpolationMode(out AValue: Integer): HResult; stdcall;
    function SetInterpolationMode(AValue: Integer): HResult; stdcall;
    function GetFlip(out AValue: Integer): HResult; stdcall;
    function SetFlip(AValue: Integer): HResult; stdcall;
    function GetRotation(out AValue: Integer): HResult; stdcall;
    function SetRotation(AValue: Integer): HResult; stdcall;
    function GetBounds(out AValue: TBitmapBounds): HResult; stdcall;
    function SetBounds(AValue: TBitmapBounds): HResult; stdcall;
  end;

  IBitmapFrameWithSoftwareBitmap = interface(IInspectable)
    ['{FE287C9A-420C-4963-87AD-691436E08383}']
    function GetSoftwareBitmapAsync(out AOperation: IObjectOperation): HResult; stdcall;
    function GetSoftwareBitmapConvertedAsync(APixelFormat, AAlphaMode: Integer;
      out AOperation: IObjectOperation): HResult; stdcall;
    function GetSoftwareBitmapTransformedAsync(APixelFormat, AAlphaMode: Integer;
      const ATransform: IBitmapTransform; AOrientationMode, AColorMode: Integer;
      out AOperation: IObjectOperation): HResult; stdcall;
  end;

  IBitmapBuffer = interface(IInspectable)
    ['{A53E04C4-399C-438C-B28F-A63A6B83D1A1}']
    function GetPlaneCount(out ACount: Integer): HResult; stdcall;
    function GetPlaneDescription(AIndex: Integer;
      out ADescription: TBitmapPlaneDescription): HResult; stdcall;
  end;

  IMemoryBuffer = interface(IInspectable)
    ['{FBC4DD2A-245B-11E4-AF98-689423260CF8}']
    function CreateReference(out AReference: IUnknown): HResult; stdcall;
  end;

  IMemoryBufferByteAccess = interface(IUnknown)
    ['{5B0D3235-4DBA-4D44-865E-8F1D0E4FD04D}']
    function GetBuffer(out AData: PByte; out ACapacity: Cardinal): HResult; stdcall;
  end;

  ISoftwareBitmap = interface(IInspectable)
    ['{689E0708-7EEF-483F-963F-DA938818E073}']
    function GetBitmapPixelFormat(out AFormat: Integer): HResult; stdcall;
    function GetBitmapAlphaMode(out AMode: Integer): HResult; stdcall;
    function GetPixelWidth(out AValue: Integer): HResult; stdcall;
    function GetPixelHeight(out AValue: Integer): HResult; stdcall;
    function GetIsReadOnly(out AValue: Boolean): HResult; stdcall;
    function SetDpiX(AValue: Double): HResult; stdcall;
    function GetDpiX(out AValue: Double): HResult; stdcall;
    function SetDpiY(AValue: Double): HResult; stdcall;
    function GetDpiY(out AValue: Double): HResult; stdcall;
    function LockBuffer(AMode: Integer; out ABuffer: IBitmapBuffer): HResult; stdcall;
  end;

  IOcrEngine = interface(IInspectable)
    ['{5A14BC41-5B76-3140-B680-8825562683AC}']
    function RecognizeAsync(const ABitmap: IUnknown;
      out AOperation: IObjectOperation): HResult; stdcall;
  end;

  IOcrEngineStatics = interface(IInspectable)
    ['{5BFFA85A-3384-3540-9940-699120D428A8}']
    function GetMaxImageDimension(out AValue: Cardinal): HResult; stdcall;
    function GetAvailableRecognizerLanguages(out ALanguages: IUnknown): HResult; stdcall;
    function IsLanguageSupported(const ALanguage: IUnknown;
      out AValue: Boolean): HResult; stdcall;
    function TryCreateFromLanguage(const ALanguage: IUnknown;
      out AEngine: IOcrEngine): HResult; stdcall;
  end;

  IOcrResult = interface(IInspectable)
    ['{9BD235B2-175B-3D6A-92E2-388C206E2F63}']
    function GetLines(out ALines: IUnknown): HResult; stdcall;
    function GetTextAngle(out AAngle: IUnknown): HResult; stdcall;
    function GetText(out AText: THString): HResult; stdcall;
  end;

const
  RandomAccessStreamId: TGUID = '{905A0FE1-BC53-11DF-8C49-001E4FC686DA}';
  RoMultithreaded = 1;
  StreamDefault = 0;
  AsyncStarted = 0;
  PixelFormatBgra8 = 87;
  BitmapAlphaStraight = 1;
  BitmapAlphaIgnore = 2;
  BitmapBufferReadWrite = 1;
  IgnoreExifOrientation = 0;
  DoNotColorManage = 0;
  TileOverlap = 128;

function RoInitialize(AKind: Integer): HResult; stdcall; external 'combase.dll';
procedure RoUninitialize; stdcall; external 'combase.dll';
function RoGetActivationFactory(AClass: THString; constref AIid: TGUID;
  out AFactory): HResult; stdcall; external 'combase.dll';
function RoActivateInstance(AClass: THString;
  out AInstance: IInspectable): HResult; stdcall; external 'combase.dll';
function WindowsCreateString(ASource: PWideChar; ALength: Cardinal;
  out AValue: THString): HResult; stdcall; external 'combase.dll';
function WindowsDeleteString(AValue: THString): HResult; stdcall; external 'combase.dll';
function WindowsGetStringRawBuffer(AValue: THString;
  out ALength: Cardinal): PWideChar; stdcall; external 'combase.dll';
function CreateRandomAccessStreamOnFile(APath: PWideChar; AOptions: Integer;
  constref AIid: TGUID; out AStream: IUnknown): HResult; stdcall; external 'shcore.dll';

procedure Check(AResult: HResult; const AOperation: String);
begin
  if AResult < 0 then
  begin
    raise EOSError.CreateFmt('%s failed (0x%.8x)', [AOperation, LongWord(AResult)]);
  end;
end;

procedure CompositeOnWhite(const ABitmap: ISoftwareBitmap);
var
  LBuffer: IBitmapBuffer;
  LMemory: IMemoryBuffer;
  LReference: IUnknown;
  LAccess: IMemoryBufferByteAccess;
  LPlane: TBitmapPlaneDescription;
  LData: PByte;
  LCapacity: Cardinal;
  LRow: Integer;
  LColumn: Integer;
  LPixel: PBgraPixel;
  LAlpha: Integer;
  LWhite: Integer;
begin
  Check(ABitmap.LockBuffer(BitmapBufferReadWrite, LBuffer), 'Lock transparent bitmap');
  Check(LBuffer.GetPlaneDescription(0, LPlane), 'Read bitmap plane description');
  LMemory := LBuffer as IMemoryBuffer;
  Check(LMemory.CreateReference(LReference), 'Reference bitmap memory');
  LAccess := LReference as IMemoryBufferByteAccess;
  Check(LAccess.GetBuffer(LData, LCapacity), 'Access bitmap pixels');
  if (LData = nil) or (LPlane.StartIndex < 0) or (LPlane.Width <= 0) or
    (LPlane.Height <= 0) or (LPlane.Stride < Int64(LPlane.Width) * SizeOf(TBgraPixel)) then
  begin
    raise EOSError.Create('Invalid bitmap plane layout');
  end;
  if QWord(LPlane.StartIndex) + QWord(LPlane.Height - 1) * QWord(LPlane.Stride) +
    QWord(LPlane.Width) * SizeOf(TBgraPixel) > LCapacity then
  begin
    raise EOSError.Create('Bitmap plane exceeds its buffer');
  end;
  for LRow := 0 to LPlane.Height - 1 do
  begin
    LPixel := PBgraPixel(PtrUInt(LData) + PtrUInt(LPlane.StartIndex) +
      PtrUInt(LRow) * PtrUInt(LPlane.Stride));
    for LColumn := 0 to LPlane.Width - 1 do
    begin
      LAlpha := LPixel^.Alpha;
      if LAlpha <> 255 then
      begin
        LWhite := 255 * (255 - LAlpha) + 127;
        LPixel^.Blue := (LPixel^.Blue * LAlpha + LWhite) div 255;
        LPixel^.Green := (LPixel^.Green * LAlpha + LWhite) div 255;
        LPixel^.Red := (LPixel^.Red * LAlpha + LWhite) div 255;
        LPixel^.Alpha := 255;
      end;
      Inc(LPixel);
    end;
  end;
end;

function NewBitmapTransform: IBitmapTransform;
const
  ClassName: UnicodeString = 'Windows.Graphics.Imaging.BitmapTransform';
var
  LName: THString;
  LInstance: IInspectable;
begin
  Check(WindowsCreateString(PWideChar(ClassName), Length(ClassName), LName),
    'Create bitmap transform class name');
  try
    Check(RoActivateInstance(LName, LInstance), 'Activate bitmap transform');
    Result := LInstance as IBitmapTransform;
  finally
    WindowsDeleteString(LName);
  end;
end;

procedure GetFactory(const AClass: UnicodeString; const AIid: TGUID; out AFactory);
var
  LName: THString;
begin
  Check(WindowsCreateString(PWideChar(AClass), Length(AClass), LName), 'WindowsCreateString');
  try
    Check(RoGetActivationFactory(LName, AIid, AFactory), 'Activate ' + UTF8Encode(AClass));
  finally
    WindowsDeleteString(LName);
  end;
end;

function AwaitObject(const AOperation: IObjectOperation; const AStage: String): IUnknown;
var
  LInfo: IAsyncInfo;
  LStatus: Integer;
begin
  if not Supports(AOperation, IAsyncInfo, LInfo) then
  begin
    raise EOSError.Create(AStage + ' did not return an asynchronous operation');
  end;
  repeat
    Check(LInfo.GetStatus(LStatus), AStage + ' status');
    if LStatus = AsyncStarted then
    begin
      Sleep(8);
    end;
  until LStatus <> AsyncStarted;
  Check(AOperation.GetResults(Result), AStage + ' result');
end;

constructor TWindowsOcr.Create(const ALanguage: UnicodeString);
var
  LDecoder: IBitmapDecoderStatics;
  LLanguageFactory: ILanguageFactory;
  LEngineFactory: IOcrEngineStatics;
  LEngine: IOcrEngine;
  LLanguage: IUnknown;
  LTag: THString;
begin
  inherited Create;
  Check(RoInitialize(RoMultithreaded), 'Initialize Windows Runtime');
  FInitialized := True;
  GetFactory('Windows.Graphics.Imaging.BitmapDecoder', IBitmapDecoderStatics, LDecoder);
  GetFactory('Windows.Globalization.Language', ILanguageFactory, LLanguageFactory);
  GetFactory('Windows.Media.Ocr.OcrEngine', IOcrEngineStatics, LEngineFactory);
  Check(LEngineFactory.GetMaxImageDimension(FMaxDimension), 'Read OCR dimension limit');
  if FMaxDimension <= TileOverlap then
  begin
    raise EOSError.Create('Windows OCR returned an invalid dimension limit');
  end;
  Check(WindowsCreateString(PWideChar(ALanguage), Length(ALanguage), LTag),
    'Create OCR language tag');
  try
    Check(LLanguageFactory.CreateLanguage(LTag, LLanguage), 'Create OCR language');
    Check(LEngineFactory.TryCreateFromLanguage(LLanguage, LEngine), 'Create OCR engine');
  finally
    WindowsDeleteString(LTag);
  end;
  if LEngine = nil then
  begin
    raise EOSError.Create('Windows OCR language unavailable: ' + UTF8Encode(ALanguage));
  end;
  FDecoder := LDecoder;
  FEngine := LEngine;
end;

destructor TWindowsOcr.Destroy;
begin
  FEngine := nil;
  FDecoder := nil;
  if FInitialized then
  begin
    RoUninitialize;
  end;
  inherited Destroy;
end;

function TWindowsOcr.RecognizeBitmap(const ABitmap: IUnknown; AComposite: Boolean): UTF8String;
var
  LOperation: IObjectOperation;
  LOcrResult: IOcrResult;
  LText: THString;
  LLength: Cardinal;
  LBuffer: PWideChar;
  LDecoded: UnicodeString;
begin
  if AComposite then
  begin
    CompositeOnWhite(ABitmap as ISoftwareBitmap);
  end;
  Check((FEngine as IOcrEngine).RecognizeAsync(ABitmap, LOperation), 'Recognize image');
  LOcrResult := AwaitObject(LOperation, 'Recognize image') as IOcrResult;
  Check(LOcrResult.GetText(LText), 'Read OCR text');
  try
    LBuffer := WindowsGetStringRawBuffer(LText, LLength);
    SetString(LDecoded, LBuffer, LLength);
    Result := UTF8Encode(LDecoded);
  finally
    WindowsDeleteString(LText);
  end;
end;

function TWindowsOcr.RecognizeFrame(const AFrame: IUnknown): UTF8String;
var
  LFrame: IBitmapFrame;
  LSoftware: IBitmapFrameWithSoftwareBitmap;
  LTransform: IBitmapTransform;
  LOperation: IObjectOperation;
  LWidth: Cardinal;
  LHeight: Cardinal;
  LAlphaMode: Integer;
  LBounds: TBitmapBounds;
  LText: UTF8String;
begin
  LFrame := AFrame as IBitmapFrame;
  LSoftware := AFrame as IBitmapFrameWithSoftwareBitmap;
  Check(LFrame.GetPixelWidth(LWidth), 'Read image width');
  Check(LFrame.GetPixelHeight(LHeight), 'Read image height');
  Check(LFrame.GetBitmapAlphaMode(LAlphaMode), 'Read image alpha mode');
  if LAlphaMode <> BitmapAlphaIgnore then
  begin
    LAlphaMode := BitmapAlphaStraight;
  end;
  if (LWidth <= FMaxDimension) and (LHeight <= FMaxDimension) then
  begin
    Check(LSoftware.GetSoftwareBitmapConvertedAsync(PixelFormatBgra8, LAlphaMode,
      LOperation), 'Convert image');
    Result := RecognizeBitmap(AwaitObject(LOperation, 'Convert image'),
      LAlphaMode = BitmapAlphaStraight);
    Exit;
  end;

  { Cover the original pixels and overlap crops so text crossing a boundary
    can still appear together in an OCR pass. }
  LTransform := NewBitmapTransform;
  Result := '';
  LBounds.Y := 0;
  repeat
    LBounds.Height := Min(FMaxDimension, LHeight - LBounds.Y);
    LBounds.X := 0;
    repeat
      LBounds.Width := Min(FMaxDimension, LWidth - LBounds.X);
      Check(LTransform.SetBounds(LBounds), 'Set OCR crop bounds');
      Check(LSoftware.GetSoftwareBitmapTransformedAsync(PixelFormatBgra8, LAlphaMode,
        LTransform, IgnoreExifOrientation, DoNotColorManage, LOperation), 'Convert image crop');
      LText := RecognizeBitmap(AwaitObject(LOperation, 'Convert image crop'),
        LAlphaMode = BitmapAlphaStraight);
      if LText <> '' then
      begin
        Result := Result + LText + #10;
      end;
      if LBounds.X + LBounds.Width = LWidth then
      begin
        Break;
      end;
      Inc(LBounds.X, LBounds.Width - TileOverlap);
    until False;
    if LBounds.Y + LBounds.Height = LHeight then
    begin
      Break;
    end;
    Inc(LBounds.Y, LBounds.Height - TileOverlap);
  until False;
end;

function TWindowsOcr.Recognize(const AImagePath: UnicodeString): UTF8String;
var
  LStream: IUnknown;
  LOperation: IObjectOperation;
  LDecoder: IBitmapDecoder;
  LCount: Cardinal;
  LIndex: Cardinal;
  LText: UTF8String;
begin
  Check(CreateRandomAccessStreamOnFile(PWideChar(AImagePath), StreamDefault,
    RandomAccessStreamId, LStream), 'Open image');
  Check((FDecoder as IBitmapDecoderStatics).CreateAsync(LStream, LOperation), 'Decode image');
  LDecoder := AwaitObject(LOperation, 'Decode image') as IBitmapDecoder;
  Check(LDecoder.GetFrameCount(LCount), 'Read image frame count');
  if LCount = 0 then
  begin
    raise EOSError.Create('The decoder found no image frames');
  end;
  Result := '';
  for LIndex := 0 to LCount - 1 do
  begin
    Check(LDecoder.GetFrameAsync(LIndex, LOperation), 'Decode image frame');
    LText := RecognizeFrame(AwaitObject(LOperation, 'Decode image frame'));
    if (LText <> '') and (Result <> '') then
    begin
      Result := Result + #10;
    end;
    Result := Result + LText;
  end;
end;

end.
