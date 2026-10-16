(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of the binding against a selection of libjxl's official conformance cases (<c>libjxl/conformance</c>),
///   one per capability: VarDCT photo, progressive, greyscale, alpha (premultiplied and straight), CMYK with layers,
///   animation, JPEG reconstruction and 32-bit float HDR. The suite is optional: without it every test is ignored.
/// </summary>
unit TestJxl.Conformance;

{$POINTERMATH ON}

interface

uses
  DUnitX.TestFramework,
  Jxl.Graphic;

type
  /// <summary>Conformance-suite tests; ignored when the conformance suite is not present (<c>JXL_CONFORMANCE</c>).</summary>
  [ TestFixture ]
  TTestJxlConformance = class
  private
    /// <summary>Returns a case folder, or ignores the running test when the conformance suite is absent.</summary>
    /// <param name="ACaseName">Name of the test case.</param>
    /// <returns>The case folder.</returns>
    function CaseFolder( const ACaseName: string ): string;
    /// <summary>
    ///   Decodes a case's <c>input.jxl</c> with <c>JxlDecodePixels</c> and asserts its size, channel count and every
    ///   8-bit sample against <c>ref.png</c>, within the case's <c>peak_error</c> from <c>test.json</c> plus one step
    ///   of 8-bit rounding.
    /// </summary>
    /// <param name="ACaseName">Name of the test case.</param>
    /// <param name="AExpectedChannels">Channel count the decoder must return (3 opaque, 4 with alpha).</param>
    /// <param name="AColourOutput">
    ///   Colour profile to decode to: the one <c>ref.png</c> is in (its own ICC, or sRGB when it has an sRGB chunk).
    /// </param>
    procedure AssertMatchesReference( const ACaseName: string; AExpectedChannels: Cardinal; AColourOutput: TJxlColourOutput );
    /// <summary>Reconstructs a case's JPEG and asserts its SHA-256 equals the one in <c>test.json</c>.</summary>
    /// <param name="ACaseName">Name of a test case with a <c>reconstructed_jpeg</c> entry.</param>
    procedure AssertReconstructedJpegMatches( const ACaseName: string );
  public
    /// <summary>
    ///   Proves a large lossy VarDCT photograph (bike, 2048 x 2560) decodes to the reference pixels in its own ICC
    ///   profile, and that <c>jcoImageProfile</c> really leaves the colours in that profile.
    /// </summary>
    [ Test ]
    procedure Test_Bike_VarDctPhoto_MatchesReference;
    /// <summary>
    ///   Proves progressive decoding through the raw API on an 11-megapixel progressive image: at least one
    ///   <c>JXL_DEC_FRAME_PROGRESSION</c> event fires before the full image, <c>JxlDecoderFlushImage</c> succeeds at
    ///   each, and the full image then completes. The final pixels must equal a plain (non-progressive) decode of the
    ///   same file exactly, and stay close to <c>ref.png</c> on average. (Its <c>ref.png</c> is not an exact oracle:
    ///   libjxl's own djxl output differs from it by up to 62 steps; the true reference is the suite's <c>.npy</c>.)
    /// </summary>
    [ Test ]
    procedure Test_Progressive_FlushesProgressionStepsThenCompletes;
    /// <summary>
    ///   Proves sRGB output: this greyscale image is coded in a non-sRGB grey profile (decoded in its own profile it
    ///   is up to 74 steps off), and with <c>jcoSrgb</c> it matches the sRGB reference, expanded to RGB.
    /// </summary>
    [ Test ]
    procedure Test_Grayscale_ExpandedToRgb_MatchesReference;
    /// <summary>
    ///   Proves a premultiplied-alpha image (12-bit colour, 16-bit alpha) comes back as straight RGBA matching the
    ///   reference, i.e. the binding's un-premultiply request reaches the decoder.
    /// </summary>
    [ Test ]
    procedure Test_AlphaPremultiplied_ReturnsStraightRgba;
    /// <summary>Proves a straight-alpha modular image (12-bit) decodes as RGBA matching the reference.</summary>
    [ Test ]
    procedure Test_AlphaNonPremultiplied_MatchesReference;
    /// <summary>
    ///   Proves an image with extra channels beyond alpha (CMYK black plus alpha, layered) decodes to an RGBA frame
    ///   matching its <c>ref.png</c> in sRGB, i.e. the CMYK to sRGB conversion uses the black channel.
    /// </summary>
    [ Test ]
    procedure Test_CmykLayers_DecodesToRgbaFrame;
    /// <summary>
    ///   Proves orientation is applied when decoding: <c>bench_oriented_brg</c>, stored transposed, decodes to the
    ///   pixels of its <c>ref.png</c> in display orientation (in the image's own profile, whose primaries are permuted:
    ///   the reference is not sRGB).
    /// </summary>
    [ Test ]
    procedure Test_OrientedBrg_DecodedInDisplayOrientation;
    /// <summary>
    ///   Proves the raw frame API: the animation reports all 36 frames with <c>JXL_DEC_FRAME</c>, the first frame's
    ///   duration converts to the 0.05 s in <c>test.json</c>, and only the last frame is flagged <c>is_last</c>.
    /// </summary>
    [ Test ]
    procedure Test_NewtonsCradle_FramesCountedAndTimed;
    /// <summary>Proves JPEG reconstruction of a photographic JPEG matches the conformance SHA-256 exactly.</summary>
    [ Test ]
    procedure Test_Cafe_ReconstructedJpeg_MatchesSha256;
    /// <summary>Proves JPEG reconstruction of a greyscale JPEG matches the conformance SHA-256 exactly.</summary>
    [ Test ]
    procedure Test_GrayscaleJpeg_ReconstructedJpeg_MatchesSha256;
    /// <summary>
    ///   Proves 32-bit float output through the raw API: the lossless float image decodes as <c>JXL_TYPE_FLOAT</c>
    ///   samples equal to <c>ref.pfm</c>, with no NaN on either side (a NaN compares false and would otherwise pass).
    /// </summary>
    [ Test ]
    procedure Test_LosslessPfm_FloatDecode_MatchesReferencePfm;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Hash, System.Math, System.Generics.Collections,
  Jxl.Api.Types, Jxl.Api.Decode,
  TestJxl.Common;

/// <summary>Parses a case's <c>test.json</c>.</summary>
/// <param name="AFolder">The case folder.</param>
/// <returns>The JSON object; the caller frees it.</returns>
function LoadTestJson( const AFolder: string ): TJSONObject;
begin

  Result := TJSONObject.ParseJSONValue( TFile.ReadAllText( TPath.Combine( AFolder, 'test.json' ) ) ) as TJSONObject;

end;

{ TTestJxlConformance }

function TTestJxlConformance.CaseFolder( const ACaseName: string ): string;
begin

  Result := ConformanceCaseFolder( ACaseName );

  if ( Result = '' ) then Assert.Ignore( Format( 'conformance case %s not present: %s', [ ACaseName, CONFORMANCE_HINT ] ) );

end;

procedure TTestJxlConformance.AssertMatchesReference( const ACaseName: string; AExpectedChannels: Cardinal;
  AColourOutput: TJxlColourOutput );
var
  oJson: TJSONObject;
begin

  var sFolder   := CaseFolder( ACaseName );
  var rDecoded  := JxlDecodePixels( TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) ), AColourOutput );
  var rExpected := LoadPngPixels( TPath.Combine( sFolder, 'ref.png' ) );
  oJson := LoadTestJson( sFolder );

  try
    var fPeak := ( oJson.GetValue( 'frames' ) as TJSONArray ).Items[ 0 ].GetValue<Double>( 'peak_error' );
    var iTolerance := Ceil( fPeak * 255 ) + 1;
    Assert.AreEqual( Integer( rExpected.Width ), Integer( rDecoded.Width ), 'Width' );
    Assert.AreEqual( Integer( rExpected.Height ), Integer( rDecoded.Height ), 'Height' );
    Assert.AreEqual( Integer( AExpectedChannels ), Integer( rDecoded.NumChannels ), 'NumChannels' );
    Assert.AreEqual( Integer( AExpectedChannels ), Integer( rExpected.NumChannels ), 'reference NumChannels' );
    // A grey image expanded to sRGB RGB carries no profile (libjxl's would be grey); every other case carries one.
    if ( ACaseName = 'grayscale' ) and ( AColourOutput = jcoSrgb ) then
      Assert.AreEqual( 0, Length( rDecoded.IccProfile ), 'a grey image expanded to RGB carries no grey profile' )
    else
      Assert.IsTrue( Length( rDecoded.IccProfile ) > 0, 'the decoded pixels come with their ICC profile' );

    var iDifference := MaxSampleDifference( rExpected.Data, rDecoded.Data );
    Assert.IsTrue( iDifference <= iTolerance, Format( 'largest sample difference %d exceeds %d', [ iDifference, iTolerance ] ) );
  finally
    oJson.Free;
  end;

end;

procedure TTestJxlConformance.AssertReconstructedJpegMatches( const ACaseName: string );
var
  oJson: TJSONObject;
begin

  var sFolder := CaseFolder( ACaseName );
  oJson := LoadTestJson( sFolder );

  try
    var sJpegName := oJson.GetValue<string>( 'reconstructed_jpeg' );
    var sExpected := ( ( oJson.GetValue( 'sha256sums' ) as TJSONObject ).Get( sJpegName ).JsonValue as TJSONString ).Value;
    var naJpeg    := JxlReconstructJpeg( TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) ) );
    var oHash := THashSHA2.Create( SHA256 );
    oHash.Update( naJpeg );
    Assert.AreEqual( sExpected.ToLower, oHash.HashAsString.ToLower, False, 'SHA-256' );
  finally
    oJson.Free;
  end;

end;

procedure TTestJxlConformance.Test_Bike_VarDctPhoto_MatchesReference;
begin

  AssertMatchesReference( 'bike', 3, jcoImageProfile );

end;

procedure TTestJxlConformance.Test_Progressive_FlushesProgressionStepsThenCompletes;
var
  pDecoder: PJxlDecoder;
begin

  var sFolder := CaseFolder( 'progressive' );
  var naData  := TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) );
  JxlCheckLibrary;
  pDecoder := JxlDecoderCreate( nil );

  try
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO )
      or Ord( JXL_DEC_FRAME_PROGRESSION ) or Ord( JXL_DEC_FULL_IMAGE ) ) ), 'SubscribeEvents' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetProgressiveDetail( pDecoder, kDC ) ), 'SetProgressiveDetail' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetInput( pDecoder, PByte( naData ), Length( naData ) ) ), 'SetInput' );
    JxlDecoderCloseInput( pDecoder );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_UINT8;

    var rInfo        := Default( JxlBasicInfo );
    var naPixels     := TBytes( nil );
    var iProgression := 0;
    var eStatus      := JxlDecoderProcessInput( pDecoder );

    while ( eStatus <> JXL_DEC_FULL_IMAGE ) do
    begin
      if ( eStatus = JXL_DEC_BASIC_INFO ) then
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderGetBasicInfo( pDecoder, @rInfo ) ), 'GetBasicInfo' )
      else if ( eStatus = JXL_DEC_NEED_IMAGE_OUT_BUFFER ) then
      begin
        SetLength( naPixels, rInfo.xsize * rInfo.ysize * 3 );
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetImageOutBuffer( pDecoder, @rFormat, PByte( naPixels ),
          Length( naPixels ) ) ), 'SetImageOutBuffer' );
      end
      else if ( eStatus = JXL_DEC_FRAME_PROGRESSION ) then
      begin
        Inc( iProgression );
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderFlushImage( pDecoder ) ), 'FlushImage' );
      end
      else
        Assert.Fail( Format( 'unexpected decoder status %d', [ Ord( eStatus ) ] ) );

      eStatus := JxlDecoderProcessInput( pDecoder );
    end;

    Assert.AreEqual( 4064, Integer( rInfo.xsize ), 'xsize' );
    Assert.AreEqual( 2704, Integer( rInfo.ysize ), 'ysize' );
    Assert.IsTrue( iProgression >= 1, 'no JXL_DEC_FRAME_PROGRESSION event fired' );

    var rPlain := JxlDecodePixels( naData, jcoImageProfile );
    Assert.AreEqual( -1, FirstDifference( rPlain.Data, naPixels ), 'the final progressive image equals a plain decode' );

    // ref.png is offset from libjxl's output (measured: at most 62 steps, 34.06 on average); a wrong or partial image
    // would be far further off.
    var rReference := LoadPngPixels( TPath.Combine( sFolder, 'ref.png' ) );
    var fMean      := MeanSampleDifference( rReference.Data, naPixels );
    Assert.IsTrue( fMean < 36.0, Format( 'mean difference from ref.png is %.3f', [ fMean ] ) );
    Assert.IsTrue( MaxSampleDifference( rReference.Data, naPixels ) <= 64, 'largest difference from ref.png' );
  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

procedure TTestJxlConformance.Test_Grayscale_ExpandedToRgb_MatchesReference;
begin

  AssertMatchesReference( 'grayscale', 3, jcoSrgb );

end;

procedure TTestJxlConformance.Test_AlphaPremultiplied_ReturnsStraightRgba;
begin

  AssertMatchesReference( 'alpha_premultiplied', 4, jcoImageProfile );

end;

procedure TTestJxlConformance.Test_AlphaNonPremultiplied_MatchesReference;
begin

  AssertMatchesReference( 'alpha_nonpremultiplied', 4, jcoSrgb );

end;

procedure TTestJxlConformance.Test_CmykLayers_DecodesToRgbaFrame;
begin

  AssertMatchesReference( 'cmyk_layers', 4, jcoSrgb );

end;

procedure TTestJxlConformance.Test_OrientedBrg_DecodedInDisplayOrientation;
begin

  AssertMatchesReference( 'bench_oriented_brg', 3, jcoImageProfile );

end;

procedure TTestJxlConformance.Test_NewtonsCradle_FramesCountedAndTimed;
var
  pDecoder: PJxlDecoder;
begin

  var sFolder := CaseFolder( 'animation_newtons_cradle' );
  var naData  := TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) );
  JxlCheckLibrary;
  pDecoder := JxlDecoderCreate( nil );

  try
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_FRAME ) ) ),
      'SubscribeEvents' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetInput( pDecoder, PByte( naData ), Length( naData ) ) ), 'SetInput' );
    JxlDecoderCloseInput( pDecoder );

    var rInfo        := Default( JxlBasicInfo );
    var iFrames      := 0;
    var iLastFlagged := -1;
    var fFirstSecs   := 0.0;
    var eStatus      := JxlDecoderProcessInput( pDecoder );

    while ( eStatus <> JXL_DEC_SUCCESS ) do
    begin
      if ( eStatus = JXL_DEC_BASIC_INFO ) then
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderGetBasicInfo( pDecoder, @rInfo ) ), 'GetBasicInfo' )
      else if ( eStatus = JXL_DEC_FRAME ) then
      begin
        var rHeader := Default( JxlFrameHeader );
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderGetFrameHeader( pDecoder, @rHeader ) ), 'GetFrameHeader' );

        if ( iFrames = 0 ) then
          fFirstSecs := rHeader.duration * rInfo.animation.tps_denominator / rInfo.animation.tps_numerator;

        if ( rHeader.is_last <> JXL_FALSE ) then iLastFlagged := iFrames;

        Inc( iFrames );
      end
      else
        Assert.Fail( Format( 'unexpected decoder status %d', [ Ord( eStatus ) ] ) );

      eStatus := JxlDecoderProcessInput( pDecoder );
    end;

    Assert.AreEqual( JXL_TRUE, rInfo.have_animation, 'have_animation' );
    Assert.AreEqual( 36, iFrames, 'frames' );
    Assert.AreEqual( 35, iLastFlagged, 'index of the frame flagged is_last' );
    Assert.AreEqual( 0.05, fFirstSecs, 0.000001, 'first frame duration in seconds' );
  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

procedure TTestJxlConformance.Test_Cafe_ReconstructedJpeg_MatchesSha256;
begin

  AssertReconstructedJpegMatches( 'cafe' );

end;

procedure TTestJxlConformance.Test_GrayscaleJpeg_ReconstructedJpeg_MatchesSha256;
begin

  AssertReconstructedJpegMatches( 'grayscale_jpeg' );

end;

procedure TTestJxlConformance.Test_LosslessPfm_FloatDecode_MatchesReferencePfm;
var
  pDecoder: PJxlDecoder;
begin

  var sFolder := CaseFolder( 'lossless_pfm' );
  var naData  := TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) );
  var naPfm   := TFile.ReadAllBytes( TPath.Combine( sFolder, 'ref.pfm' ) );
  JxlCheckLibrary;
  pDecoder := JxlDecoderCreate( nil );

  try
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_FULL_IMAGE ) ) ),
      'SubscribeEvents' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetInput( pDecoder, PByte( naData ), Length( naData ) ) ), 'SetInput' );
    JxlDecoderCloseInput( pDecoder );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_FLOAT;
    rFormat.endianness   := JXL_LITTLE_ENDIAN;

    var rInfo     := Default( JxlBasicInfo );
    var naSamples := TArray<Single>( nil );
    var eStatus   := JxlDecoderProcessInput( pDecoder );

    while ( eStatus <> JXL_DEC_FULL_IMAGE ) do
    begin
      if ( eStatus = JXL_DEC_BASIC_INFO ) then
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderGetBasicInfo( pDecoder, @rInfo ) ), 'GetBasicInfo' )
      else if ( eStatus = JXL_DEC_NEED_IMAGE_OUT_BUFFER ) then
      begin
        SetLength( naSamples, rInfo.xsize * rInfo.ysize * 3 );
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetImageOutBuffer( pDecoder, @rFormat, PSingle( naSamples ),
          Length( naSamples ) * SizeOf( Single ) ) ), 'SetImageOutBuffer' );
      end
      else
        Assert.Fail( Format( 'unexpected decoder status %d', [ Ord( eStatus ) ] ) );

      eStatus := JxlDecoderProcessInput( pDecoder );
    end;

    Assert.AreEqual( 32, Integer( rInfo.bits_per_sample ), 'bits_per_sample' );
    Assert.AreEqual( 8, Integer( rInfo.exponent_bits_per_sample ), 'exponent_bits_per_sample' );

    // PFM: three text lines ("PF", "width height", scale; negative = little endian), then rows bottom to top.
    var iOffset := 0;

    for var iLine := 1 to 3 do
    begin
      while ( naPfm[ iOffset ] <> 10 ) do Inc( iOffset );

      Inc( iOffset );
    end;

    var iWidth  := Integer( rInfo.xsize );
    var iHeight := Integer( rInfo.ysize );
    Assert.AreEqual( iOffset + iWidth * iHeight * 3 * SizeOf( Single ), Length( naPfm ), 'ref.pfm size' );

    var fWorst := 0.0;
    var iNaNs  := 0;

    for var iY := 0 to iHeight - 1 do
    begin
      var pReference := PSingle( @naPfm[ iOffset + ( iHeight - 1 - iY ) * iWidth * 3 * SizeOf( Single ) ] );

      for var iX := 0 to iWidth * 3 - 1 do
      begin
        if IsNan( naSamples[ iY * iWidth * 3 + iX ] ) or IsNan( pReference[ iX ] ) then Inc( iNaNs );

        var fDifference := Abs( naSamples[ iY * iWidth * 3 + iX ] - pReference[ iX ] );

        if ( fDifference > fWorst ) then fWorst := fDifference;
      end;

    end;

    Assert.AreEqual( 0, iNaNs, 'NaN samples in the decode or the reference' );
    Assert.IsTrue( fWorst <= 1E-6, Format( 'largest float difference from ref.pfm is %g', [ fWorst ] ) );
  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlConformance );

end.
