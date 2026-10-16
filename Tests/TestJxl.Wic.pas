(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Cross-checks the binding against an independent JPEG XL decoder: the Windows Imaging Component (WIC) codec of
///   Microsoft's JPEG XL Image Extension. The same file is decoded both ways to 32-bit BGRA and compared.
/// </summary>
/// <remarks>
///   The WIC codec is optional (a Microsoft Store extension); where Windows has no JPEG XL decoder these tests are
///   reported as ignored, not failed.
/// </remarks>
unit TestJxl.Wic;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests that decode the same JPEG XL files through the binding and through WIC and compare the pixels.</summary>
  [ TestFixture ]
  TTestJxlWic = class
  public
    /// <summary>
    ///   Proves the binding's lossless encoder writes a standard file that another decoder reads exactly: <c>flower.png</c>
    ///   (RGB) encoded losslessly by the binding decodes through WIC byte-identical to the binding's own decode and to the
    ///   PNG's pixels. A wrong colour encoding, channel order or row layout in either the encoder or the decoder would
    ///   break the equality with the independent decoder.
    /// </summary>
    [ Test ]
    procedure Test_LosslessRgb_WicAndBinding_PixelsIdentical;
    /// <summary>
    ///   Proves alpha is written in a form other decoders read: <c>flower_alpha.png</c> (RGBA, straight alpha) encoded
    ///   losslessly by the binding decodes through WIC with alpha and colour byte-identical to the PNG's pixels.
    /// </summary>
    [ Test ]
    procedure Test_LosslessRgba_WicAndBinding_PixelsIdentical;
    /// <summary>
    ///   Proves the binding's decoding of a lossy (VarDCT, XYB) file agrees with an independent decoder: the conformance
    ///   <c>bike</c> image decoded by the binding and by WIC differs by at most 1 step per sample with a mean below 0.5
    ///   (measured 2026-10-16: max 1, mean 0.32, which is rounding). A channel swap differs by tens of steps.
    /// </summary>
    /// <remarks>
    ///   WIC returns the image in its own colour encoding (for <c>bike</c>, sRGB primaries with the BT.709 transfer
    ///   curve) and does not convert it, so the binding decodes with <c>jcoImageProfile</c> here; against the binding's
    ///   default sRGB output the difference is max 17, mean 6.4, which is the transfer-curve conversion.
    /// </remarks>
    [ Test ]
    procedure Test_LossyBike_WicAndBinding_WithinTolerance;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Win.ComObj,
  Winapi.Windows, Winapi.ActiveX, Winapi.Wincodec,
  Jxl.Graphic,
  TestJxl.Common;

const
  /// <summary>Effort used for the lossless encodes: fast, and still a real modular encode.</summary>
  TEST_EFFORT = 3;
  /// <summary>Largest per-sample difference accepted between the two decodes of the lossy <c>bike</c> image.</summary>
  LOSSY_MAX_DIFFERENCE = 1;
  /// <summary>Mean per-sample difference the two decodes of the lossy <c>bike</c> image must stay below.</summary>
  LOSSY_MEAN_DIFFERENCE = 0.5;

type
  /// <summary>A decoded image as 32-bit BGRA with straight alpha, rows top to bottom with no padding.</summary>
  TBgraImage = record
    /// <summary>Width in pixels.</summary>
    Width: Cardinal;
    /// <summary>Height in pixels.</summary>
    Height: Cardinal;
    /// <summary><c>Width * Height * 4</c> bytes in B, G, R, A order.</summary>
    Data: TBytes;
  end;

/// <summary>Converts binding pixels (RGB or RGBA, straight alpha) to BGRA; opaque pixels get alpha 255.</summary>
/// <param name="APixels">The pixels, 3 or 4 channels.</param>
/// <returns>The image in BGRA order.</returns>
function PixelsToBgra( const APixels: TJxlPixels ): TBgraImage;
begin

  if ( APixels.NumChannels < 3 ) then
    raise EArgumentException.CreateFmt( 'PixelsToBgra needs 3 or 4 channels, not %d.', [ APixels.NumChannels ] );

  Result.Width  := APixels.Width;
  Result.Height := APixels.Height;
  SetLength( Result.Data, NativeInt( APixels.Width ) * NativeInt( APixels.Height ) * 4 );

  var pSource   := PByte( APixels.Data );
  var pTarget   := PByte( Result.Data );
  var iChannels := APixels.NumChannels;

  for var iI := 0 to NativeInt( APixels.Width ) * NativeInt( APixels.Height ) - 1 do
  begin
    pTarget[ 0 ] := pSource[ 2 ];
    pTarget[ 1 ] := pSource[ 1 ];
    pTarget[ 2 ] := pSource[ 0 ];
    pTarget[ 3 ] := if ( iChannels = 4 ) then pSource[ 3 ] else 255;
    Inc( pSource, iChannels );
    Inc( pTarget, 4 );
  end;

end;

/// <summary>
///   Decodes the first frame of an image file through WIC, converted to 32-bit BGRA with straight alpha. Calls
///   <c>Assert.Ignore</c> when WIC has no decoder for the file's format.
/// </summary>
/// <param name="AFileName">Path of the image file.</param>
/// <returns>The image.</returns>
/// <exception cref="EOleSysError">A WIC call other than finding a decoder fails.</exception>
function WicDecodeBgra( const AFileName: string ): TBgraImage;
var
  intfFactory: IWICImagingFactory;
  intfDecoder: IWICBitmapDecoder;
  intfFrame: IWICBitmapFrameDecode;
  intfConverted: IWICBitmapSource;
begin

  Result     := Default( TBgraImage );
  var hrInit := CoInitializeEx( nil, COINIT_APARTMENTTHREADED );

  try
    OleCheck( CoCreateInstance( CLSID_WICImagingFactory, nil, CLSCTX_INPROC_SERVER, IWICImagingFactory, intfFactory ) );

    var hrDecoder := intfFactory.CreateDecoderFromFilename( PChar( AFileName ), GUID_NULL, GENERIC_READ,
      WICDecodeMetadataCacheOnDemand, intfDecoder );

    if ( hrDecoder = HRESULT( WINCODEC_ERR_COMPONENTNOTFOUND ) ) then
      Assert.Ignore( 'Windows has no WIC decoder for JPEG XL (install Microsoft''s JPEG XL Image Extension to run this test).' );

    OleCheck( hrDecoder );
    OleCheck( intfDecoder.GetFrame( 0, intfFrame ) );
    OleCheck( WICConvertBitmapSource( GUID_WICPixelFormat32bppBGRA, intfFrame, intfConverted ) );

    var iWidth: UINT  := 0;
    var iHeight: UINT := 0;
    OleCheck( intfConverted.GetSize( iWidth, iHeight ) );
    Result.Width  := iWidth;
    Result.Height := iHeight;
    SetLength( Result.Data, NativeInt( iWidth ) * NativeInt( iHeight ) * 4 );
    OleCheck( intfConverted.CopyPixels( nil, iWidth * 4, Length( Result.Data ), PByte( Result.Data ) ) );
  finally
    intfConverted := nil;
    intfFrame     := nil;
    intfDecoder   := nil;
    intfFactory   := nil;

    if Succeeded( hrInit ) then CoUninitialize;
  end;

end;

/// <summary>Measures the colour difference between two equally sized BGRA images; alpha is compared separately.</summary>
/// <param name="AFirst">First image.</param>
/// <param name="ASecond">Second image.</param>
/// <param name="AMaxColour">Receives the largest difference of any B, G or R sample.</param>
/// <param name="AMeanColour">Receives the mean absolute difference over all B, G and R samples.</param>
/// <param name="AMaxAlpha">Receives the largest difference of any alpha sample.</param>
procedure CompareBgra( const AFirst: TBgraImage; const ASecond: TBgraImage; out AMaxColour: Integer; out AMeanColour: Double;
  out AMaxAlpha: Integer );
begin

  Assert.AreEqual( AFirst.Width, ASecond.Width, 'Width' );
  Assert.AreEqual( AFirst.Height, ASecond.Height, 'Height' );
  Assert.AreEqual( Length( AFirst.Data ), Length( ASecond.Data ), 'data length' );

  AMaxColour := 0;
  AMaxAlpha  := 0;

  var iSum: Int64 := 0;

  for var iI := 0 to High( AFirst.Data ) do
  begin
    var iDifference := Abs( Integer( AFirst.Data[ iI ] ) - Integer( ASecond.Data[ iI ] ) );

    if ( iI and 3 = 3 ) then
    begin
      if ( iDifference > AMaxAlpha ) then AMaxAlpha := iDifference;
    end
    else
    begin
      Inc( iSum, iDifference );

      if ( iDifference > AMaxColour ) then AMaxColour := iDifference;
    end;

  end;

  AMeanColour := iSum / ( Length( AFirst.Data ) div 4 * 3 );

end;

/// <summary>
///   Encodes a PNG losslessly with the binding, decodes the result through the binding and through WIC, and asserts
///   that both decodes and the PNG's own pixels are byte-identical.
/// </summary>
/// <param name="APngName">Path of the PNG below <c>testdata/jxl</c>.</param>
/// <param name="AChannels">Channels the binding is expected to decode: 3 for RGB, 4 for RGBA.</param>
procedure AssertLosslessAgrees( const APngName: string; AChannels: Cardinal );
begin

  var rSource  := LoadPngPixels( TestDataFile( APngName ) );
  var rOptions := TJxlEncodeOptions.Default;
  rOptions.Lossless := True;
  rOptions.Effort   := TEST_EFFORT;

  var naJxl     := JxlEncodePixels( rSource, rOptions );
  var sFileName := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-' + TGUID.NewGuid.ToString + '.jxl' );
  TFile.WriteAllBytes( sFileName, naJxl );

  try
    var rWic     := WicDecodeBgra( sFileName );
    var rDecoded := JxlDecodePixels( naJxl );
    Assert.AreEqual( AChannels, rDecoded.NumChannels, 'binding NumChannels' );

    var rBinding := PixelsToBgra( rDecoded );
    var rPng     := PixelsToBgra( rSource );
    Assert.AreEqual( rPng.Width, rWic.Width, 'WIC width' );
    Assert.AreEqual( rPng.Height, rWic.Height, 'WIC height' );
    Assert.AreEqual( -1, FirstDifference( rBinding.Data, rWic.Data ), 'first byte where the binding and WIC differ' );
    Assert.AreEqual( -1, FirstDifference( rPng.Data, rWic.Data ), 'first byte where the PNG and WIC differ' );
  finally
    TFile.Delete( sFileName );
  end;

end;

{ TTestJxlWic }

procedure TTestJxlWic.Test_LosslessRgb_WicAndBinding_PixelsIdentical;
begin

  AssertLosslessAgrees( 'flower\flower.png', 3 );

end;

procedure TTestJxlWic.Test_LosslessRgba_WicAndBinding_PixelsIdentical;
begin

  AssertLosslessAgrees( 'flower\flower_alpha.png', 4 );

end;

procedure TTestJxlWic.Test_LossyBike_WicAndBinding_WithinTolerance;
var
  iMaxColour: Integer;
  fMeanColour: Double;
  iMaxAlpha: Integer;
begin

  var sFolder := ConformanceCaseFolder( 'bike' );

  if ( sFolder = '' ) then Assert.Ignore( 'libjxl conformance suite not found: ' + CONFORMANCE_HINT );

  var sFileName := TPath.Combine( sFolder, 'input.jxl' );
  var rWic      := WicDecodeBgra( sFileName );
  var rBinding  := PixelsToBgra( JxlDecodePixels( TFile.ReadAllBytes( sFileName ), jcoImageProfile ) );
  CompareBgra( rBinding, rWic, iMaxColour, fMeanColour, iMaxAlpha );
  Assert.AreEqual( 0, iMaxAlpha, 'alpha differs (the image is opaque)' );
  Assert.IsTrue( iMaxColour <= LOSSY_MAX_DIFFERENCE, Format( 'largest colour difference %d exceeds %d (mean %.4f)',
    [ iMaxColour, LOSSY_MAX_DIFFERENCE, fMeanColour ] ) );
  Assert.IsTrue( fMeanColour < LOSSY_MEAN_DIFFERENCE, Format( 'mean colour difference %.4f is not below %.2f (max %d)',
    [ fMeanColour, LOSSY_MEAN_DIFFERENCE, iMaxColour ] ) );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlWic );

end.
