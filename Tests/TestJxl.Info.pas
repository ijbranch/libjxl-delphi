(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of <c>JxlReadInfo</c>: the header and frame information it reports for still, alpha, animated and
///   recompressed-JPEG files, its three overloads, and its refusal of invalid input.
/// </summary>
unit TestJxl.Info;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of <c>Jxl.Graphic.JxlReadInfo</c>.</summary>
  [ TestFixture ]
  TTestJxlInfo = class
  public
    /// <summary>
    ///   Proves the basic information of a lossy still image: the conformance <c>bike</c> reads as 2048 x 2560, 8-bit
    ///   RGB, XYB-coded, no alpha, a bare codestream, one frame, not animated and with no JPEG reconstruction data.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_Bike_LossyStillImage;
    /// <summary>
    ///   Proves straight alpha is reported as such: <c>alpha_nonpremultiplied</c> reads as 12-bit colour with a 12-bit
    ///   alpha channel that is not premultiplied, coded in its original colour space, in a bare codestream.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_AlphaNonPremultiplied_ReportsStraightAlpha;
    /// <summary>
    ///   Proves premultiplied alpha and the container are reported: <c>alpha_premultiplied</c> reads as premultiplied,
    ///   XYB-coded and wrapped in the container; with the previous test this pins both values of each flag.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_AlphaPremultiplied_ReportsPremultipliedAndContainer;
    /// <summary>
    ///   Proves frames are counted and timed without decoding pixels: <c>animation_newtons_cradle</c> reads as an
    ///   animation of 36 frames lasting 0.82 s in total (the sum of the durations in its <c>test.json</c>), looping
    ///   forever.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_NewtonsCradle_CountsFramesAndDuration;
    /// <summary>
    ///   Proves JPEG reconstruction data is detected: a JPEG recompressed by the binding reports a <c>jbrd</c> box, a
    ///   container, its original colour space and the JPEG's size, while a lossless encode of the same image reports
    ///   none.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_TranscodedJpeg_ReportsReconstructionData;
    /// <summary>
    ///   Proves the stream overload reads from the current position and the file overload reads the file: both agree
    ///   with the bytes overload on <c>splines.jxl</c> (2048 x 2048), with leading junk in the stream.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_Overloads_AgreeOnSplines;
    /// <summary>
    ///   Proves invalid input raises <c>EJxlError</c> of the right form rather than returning zeroed information: random
    ///   bytes after a signature, a file truncated inside its headers and a PNG are libjxl failures naming
    ///   <c>JxlDecoderProcessInput</c> and its status, while empty input is a binding check naming <c>JxlReadInfo</c>
    ///   (no C function failed).
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_InvalidInput_RaisesEJxlError;
    /// <summary>
    ///   Proves the container walk's edge cases: a file cut inside a box header, a box declaring fewer bytes than its
    ///   own header, and a large-size box whose 16-byte header is cut are each refused naming the fault, while a last
    ///   box of size 0 (meaning "to the end of the file") reads and validates.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_ContainerWalkEdges_ReportedOrAccepted;
    /// <summary>
    ///   Proves the stream overload of <c>JxlValidate</c> reads from the current position: with leading junk it agrees
    ///   with the bytes overload and decodes the frame, and a cut file in a stream is rejected.
    /// </summary>
    [ Test ]
    procedure Test_Validate_StreamOverload_ReadsFromPosition;
    /// <summary>
    ///   Proves orientation is reported as stored: <c>bench_oriented_brg</c> is stored 500 x 606 with orientation 5
    ///   (transpose), so it displays 606 x 500, the size of its <c>ref.png</c> (read independently); decoding applies the
    ///   orientation. Before the fix libjxl reported orientation 1 and the displayed size.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_Oriented_ReportsStoredOrientationAndSize;
    /// <summary>
    ///   Proves <c>DisplayWidth</c> / <c>DisplayHeight</c> for every orientation 1 to 8 against a hand-typed table:
    ///   1 to 4 keep the stored size, 5 to 8 swap it.
    /// </summary>
    [ Test ]
    procedure Test_DisplaySize_EveryOrientation_MatchesTable;
    /// <summary>
    ///   Proves <c>JxlValidate</c> accepts valid files of every kind and decodes all their frames: bike (lossy),
    ///   alpha_nonpremultiplied (12-bit with alpha), animation_newtons_cradle (all 36 frames decoded) and a JPEG
    ///   recompressed by the binding (container with <c>jbrd</c>), returning the same information as <c>JxlReadInfo</c>.
    /// </summary>
    [ Test ]
    procedure Test_Validate_ValidFiles_DecodeEveryFrame;
    /// <summary>
    ///   Proves what the full check adds: <c>splines.jxl</c>, a bare codestream, cut in half inside its pixel data is
    ///   accepted by the header-only <c>JxlReadInfo</c> but rejected by <c>JxlValidate</c> with <c>EJxlError</c>.
    /// </summary>
    [ Test ]
    procedure Test_Validate_BareCodestreamCutInPixels_RaisesWhereReadInfoDoesNot;
    /// <summary>
    ///   Proves corrupt pixel data is caught: bike with 256 bytes inverted well after its headers still reads with
    ///   <c>JxlReadInfo</c>, and <c>JxlValidate</c> rejects it with <c>EJxlError</c>.
    /// </summary>
    [ Test ]
    procedure Test_Validate_CorruptPixelData_RaisesEJxlError;
    /// <summary>
    ///   Proves the container box check in <c>JxlReadInfo</c> (and so in <c>JxlValidate</c>): a recompressed JPEG
    ///   reads whole, but cut inside its <c>jbrd</c> box or inside its codestream box it raises <c>EJxlError</c> naming
    ///   the box, its declared size and the bytes available.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_ContainerCutInsideBox_RaisesNamingTheBox;
    /// <summary>
    ///   Proves a container cut inside the pixel data of its last codestream box (a recompressed JPEG, 100 bytes short)
    ///   is reported as a truncated box by <c>JxlReadInfo</c>. libjxl alone also rejects it, but only as a bare
    ///   "status 1"; the box check names the box and the sizes (mutation-tested: without it this test fails).
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_ContainerCutInLastBox_ReportsTruncatedBox;
    /// <summary>
    ///   Proves the 64-bit large-size box form is understood: the codestream box of a recompressed JPEG rewritten in
    ///   that form reads and validates whole, and cut short it raises naming the 64-bit declared size.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_LargeSizeBox_ReadAndCheckedCorrectly;
    /// <summary>
    ///   Proves the colour encoding is read, header-only, as the file states it: the conformance <c>bike</c> has an
    ///   encoded profile with sRGB primaries, D65 and the BT.709 transfer curve (its <c>ref.png</c> profile is
    ///   <c>RGB_D65_SRG_Per_709</c>), so it is RGB but NOT sRGB; a demo that called it sRGB would claim an exact save
    ///   that converts its samples.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_Bike_SrgbPrimariesWithBt709TransferIsNotSrgb;
    /// <summary>
    ///   Proves <c>IsSrgb</c> against every part of its definition, on files encoded through the C API with a chosen
    ///   encoded profile: sRGB (any rendering intent) and grey sRGB are sRGB; linear sRGB, Display P3 primaries, a
    ///   non-D65 white point, BT.709 transfer and linear grey are not. Each also reports its colour space, no ICC
    ///   profile, and the profile it was given.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_EncodedProfiles_IsSrgbOnlyForSrgb;
    /// <summary>
    ///   Proves the binding's own output is reported as sRGB: pixels it encodes without a profile (lossless RGB, lossy
    ///   and so XYB-coded RGB, and lossless grey) read back as sRGB with no ICC profile, and <c>JxlValidate</c> reports
    ///   the same colour fields as <c>JxlReadInfo</c>.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_BindingOutput_IsSrgb;
    /// <summary>
    ///   Proves an ICC profile is reported as one, with its exact size and the colour space from its header: Rec. 2020
    ///   and sRGB ICC profiles (RGB) and an sGrey profile (grey) stored by the binding, none of them reported as sRGB,
    ///   and the structured encoding left zero.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_IccProfiles_ReportedWithSizeAndSpace;
    /// <summary>
    ///   Proves the colour encoding of three conformance files, each described by an ICC profile: <c>grayscale</c>
    ///   carries a grey one (a 1-channel image, so the profile's header says <c>GRAY</c>) and is not reported as sRGB
    ///   even though its <c>ref.png</c> is tagged sRGB, <c>spot</c> carries the 940-byte ProPhoto (ROMM) RGB profile
    ///   its <c>ref.png</c> embeds, and <c>cmyk_layers</c> a CMYK one (JPEG XL has no encoded CMYK), whose colour space
    ///   is unknown.
    /// </summary>
    [ Test ]
    procedure Test_ReadInfo_ConformanceColour_GreySpotAndCmyk;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Imaging.pngimage,
  Jxl.Api.Types, Jxl.Api.Encode,
  Jxl.Graphic,
  TestJxl.Common;

/// <summary>
///   Encodes a 2 x 2 image losslessly through the C API with a structured colour encoding: grey (1 channel) when the
///   encoding's colour space is grey, otherwise RGB.
/// </summary>
/// <param name="AEncoding">The encoded profile to declare.</param>
/// <returns>The JPEG XL file.</returns>
function EncodeWithColourEncoding( const AEncoding: JxlColorEncoding ): TBytes;
begin

  JxlCheckLibrary;

  var iChannels := if ( AEncoding.color_space = JXL_COLOR_SPACE_GRAY ) then 1 else 3;
  var pEncoder  := JxlEncoderCreate( nil );

  try
    var rInfo := Default( JxlBasicInfo );
    JxlEncoderInitBasicInfo( @rInfo );
    rInfo.xsize                 := 2;
    rInfo.ysize                 := 2;
    rInfo.bits_per_sample       := 8;
    rInfo.num_color_channels    := iChannels;
    rInfo.uses_original_profile := JXL_TRUE;
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetBasicInfo( pEncoder, @rInfo ) ), 'SetBasicInfo' );

    var rColour := AEncoding;
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetColorEncoding( pEncoder, @rColour ) ), 'SetColorEncoding' );

    var pSettings := JxlEncoderFrameSettingsCreate( pEncoder, nil );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetFrameLossless( pSettings, JXL_TRUE ) ), 'SetFrameLossless' );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := iChannels;
    rFormat.data_type    := JXL_TYPE_UINT8;

    var naPixels: TBytes;
    SetLength( naPixels, 2 * 2 * iChannels );
    FillChar( naPixels[ 0 ], Length( naPixels ), 100 );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderAddImageFrame( pSettings, @rFormat, PByte( naPixels ),
      Length( naPixels ) ) ), 'AddImageFrame' );
    JxlEncoderCloseInput( pEncoder );
    SetLength( Result, 64 * 1024 );

    var pNext: PByte           := PByte( Result );
    var iAvailable: NativeUInt := Length( Result );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderProcessOutput( pEncoder, @pNext, @iAvailable ) ), 'ProcessOutput' );
    SetLength( Result, pNext - PByte( Result ) );
  finally
    JxlEncoderDestroy( pEncoder );
  end;

end;

/// <summary>Returns a profile from libjxl's <c>testdata/external/Compact-ICC-Profiles/profiles</c> folder.</summary>
/// <param name="AName">File name of the profile, e.g. <c>sRGB-v4.icc</c>.</param>
/// <returns>The profile's bytes.</returns>
function CompactIccProfile( const AName: string ): TBytes;
begin

  Result := TFile.ReadAllBytes( TPath.Combine( ExtractFileDir( ExtractFileDir( TestDataFile( 'splines.jxl' ) ) ),
    'external\Compact-ICC-Profiles\profiles\' + AName ) );

end;

/// <summary>Asserts the colour fields of an image described by an ICC profile.</summary>
/// <param name="AInfo">The information read.</param>
/// <param name="ASpace">Expected colour space.</param>
/// <param name="ASize">Expected profile size in bytes.</param>
/// <param name="AWhat">What the file is, for the messages.</param>
procedure AssertIccColour( const AInfo: TJxlInfo; ASpace: TJxlColourSpace; ASize: UInt64; const AWhat: string );
begin

  Assert.IsTrue( AInfo.HasIccProfile, AWhat + ': HasIccProfile' );
  Assert.AreEqual( ASize, AInfo.IccProfileSize, AWhat + ': IccProfileSize' );
  Assert.AreEqual( Ord( ASpace ), Ord( AInfo.ColourSpace ), AWhat + ': ColourSpace' );
  Assert.IsFalse( AInfo.IsSrgb, AWhat + ': IsSrgb (an ICC profile never is)' );
  Assert.AreEqual( 0, Integer( AInfo.ColourEncoding.transfer_function ), AWhat + ': ColourEncoding is left zero' );
  Assert.AreEqual( 0, Integer( AInfo.ColourEncoding.white_point ), AWhat + ': ColourEncoding white point is left zero' );

end;

/// <summary>Returns the <c>input.jxl</c> of a conformance case, or ignores the test when the suite is absent.</summary>
/// <param name="ACaseName">Name of the case.</param>
/// <returns>The file's path.</returns>
function ConformanceInput( const ACaseName: string ): string;
begin

  var sFolder := ConformanceCaseFolder( ACaseName );

  if ( sFolder = '' ) then Assert.Ignore( 'libjxl conformance suite not found: ' + CONFORMANCE_HINT );

  Result := TPath.Combine( sFolder, 'input.jxl' );

end;

/// <summary>
///   Reads a file's information that must be valid, asserting that no <c>EJxlError</c> is raised, so a regression fails
///   an assertion naming the file instead of erroring.
/// </summary>
/// <param name="AData">The JPEG XL file.</param>
/// <param name="AWhat">What the file is, for the failure message.</param>
/// <returns>The information.</returns>
function ReadInfoOk( const AData: TBytes; const AWhat: string ): TJxlInfo; overload;
var
  rInfo: TJxlInfo;
begin

  rInfo := Default( TJxlInfo );
  Assert.WillNotRaise( procedure begin rInfo := JxlReadInfo( AData ); end, EJxlError, 'JxlReadInfo rejected ' + AWhat );
  Result := rInfo;

end;

/// <summary>Reads the information of a file on disk that must be valid; see the bytes overload.</summary>
/// <param name="AFileName">Path of the file.</param>
/// <param name="AWhat">What the file is, for the failure message.</param>
/// <returns>The information.</returns>
function ReadInfoOk( const AFileName: string; const AWhat: string ): TJxlInfo; overload;
var
  rInfo: TJxlInfo;
begin

  rInfo := Default( TJxlInfo );
  Assert.WillNotRaise( procedure begin rInfo := JxlReadInfo( AFileName ); end, EJxlError, 'JxlReadInfo rejected ' + AWhat );
  Result := rInfo;

end;

/// <summary>Reads the information of a file in a stream that must be valid; see the bytes overload.</summary>
/// <param name="AStream">The stream, positioned at the file.</param>
/// <param name="AWhat">What the file is, for the failure message.</param>
/// <returns>The information.</returns>
function ReadInfoOk( AStream: TStream; const AWhat: string ): TJxlInfo; overload;
var
  rInfo: TJxlInfo;
begin

  rInfo := Default( TJxlInfo );
  Assert.WillNotRaise( procedure begin rInfo := JxlReadInfo( AStream ); end, EJxlError, 'JxlReadInfo rejected ' + AWhat );
  Result := rInfo;

end;

/// <summary>
///   Validates a file that must be valid, asserting that no <c>EJxlError</c> is raised and that every announced frame
///   was decoded in full.
/// </summary>
/// <param name="AData">The JPEG XL file.</param>
/// <param name="AWhat">What the file is, for the failure message.</param>
/// <returns>The information.</returns>
function ValidateOk( const AData: TBytes; const AWhat: string ): TJxlInfo; overload;
var
  rInfo: TJxlInfo;
begin

  rInfo := Default( TJxlInfo );
  Assert.WillNotRaise( procedure begin rInfo := JxlValidate( AData ); end, EJxlError, 'JxlValidate rejected ' + AWhat );
  Assert.IsTrue( rInfo.DecodedFrameCount > 0, AWhat + ': no frame was decoded in full' );
  Assert.AreEqual( rInfo.FrameCount, rInfo.DecodedFrameCount, AWhat + ': frames decoded in full' );
  Result := rInfo;

end;

/// <summary>Validates a file on disk that must be valid; see the bytes overload.</summary>
/// <param name="AFileName">Path of the file.</param>
/// <param name="AWhat">What the file is, for the failure message.</param>
/// <returns>The information.</returns>
function ValidateOk( const AFileName: string; const AWhat: string ): TJxlInfo; overload;
var
  rInfo: TJxlInfo;
begin

  rInfo := Default( TJxlInfo );
  Assert.WillNotRaise( procedure begin rInfo := JxlValidate( AFileName ); end, EJxlError, 'JxlValidate rejected ' + AWhat );
  Assert.IsTrue( rInfo.DecodedFrameCount > 0, AWhat + ': no frame was decoded in full' );
  Assert.AreEqual( rInfo.FrameCount, rInfo.DecodedFrameCount, AWhat + ': frames decoded in full' );
  Result := rInfo;

end;

/// <summary>Returns <c>flower.png.im_q85_420.jpg</c> recompressed by the binding: a container with a <c>jbrd</c> box.</summary>
/// <returns>The JPEG XL file.</returns>
function TranscodedFlower: TBytes;
begin

  Result := JxlTranscodeJpegToJxl( TFile.ReadAllBytes( TestDataFile( 'flower\flower.png.im_q85_420.jpg' ) ), 3 );

end;

/// <summary>Finds the first top-level box of a type in a container, reading only 32-bit box sizes.</summary>
/// <param name="AData">The container file.</param>
/// <param name="AType">Box type, e.g. <c>jbrd</c>.</param>
/// <param name="AOffset">Receives the box's offset.</param>
/// <param name="ASize">Receives the box's size, header included.</param>
/// <returns><c>True</c> when the box was found.</returns>
function FindBox( const AData: TBytes; const AType: string; out AOffset: Integer; out ASize: Integer ): Boolean;
begin

  AOffset := 0;
  ASize   := 0;

  while ( AOffset + 8 <= Length( AData ) ) do
  begin
    ASize := ( AData[ AOffset ] shl 24 ) or ( AData[ AOffset + 1 ] shl 16 ) or ( AData[ AOffset + 2 ] shl 8 ) or AData[ AOffset + 3 ];

    if ( TEncoding.ANSI.GetString( AData, AOffset + 4, 4 ) = AType ) then Exit( True );

    if ( ASize < 8 ) then Break;

    Inc( AOffset, ASize );
  end;

  Result := False;

end;

/// <summary>Asserts that a routine raises <c>EJxlError</c> whose message contains a text.</summary>
/// <param name="AProc">The routine.</param>
/// <param name="AExpected">Text the message must contain, case-sensitively.</param>
/// <param name="AWhat">What is being checked, for the failure message.</param>
procedure AssertJxlErrorContains( const AProc: TProc; const AExpected: string; const AWhat: string );
begin

  try
    AProc;
  except
    on E: EJxlError do
    begin
      Assert.IsTrue( Pos( AExpected, E.Message ) > 0, Format( '%s: message "%s" lacks "%s"', [ AWhat, E.Message, AExpected ] ) );
      Exit;
    end;
  end;

  Assert.Fail( AWhat + ': no EJxlError was raised' );

end;

{ TTestJxlInfo }

procedure TTestJxlInfo.Test_ReadInfo_Bike_LossyStillImage;
begin

  var rInfo := ReadInfoOk( ConformanceInput( 'bike' ), 'bike' );
  Assert.AreEqual( Cardinal( 2048 ), rInfo.Width, 'Width' );
  Assert.AreEqual( Cardinal( 2560 ), rInfo.Height, 'Height' );
  Assert.AreEqual( Cardinal( 8 ), rInfo.BitsPerSample, 'BitsPerSample' );
  Assert.AreEqual( Cardinal( 0 ), rInfo.ExponentBitsPerSample, 'ExponentBitsPerSample' );
  Assert.AreEqual( Cardinal( 3 ), rInfo.ColourChannels, 'ColourChannels' );
  Assert.AreEqual( Cardinal( 0 ), rInfo.AlphaBits, 'AlphaBits' );
  Assert.AreEqual( Cardinal( 0 ), rInfo.ExtraChannels, 'ExtraChannels' );
  Assert.IsTrue( rInfo.XybEncoded, 'XybEncoded' );
  Assert.IsFalse( rInfo.HasContainer, 'HasContainer' );
  Assert.IsFalse( rInfo.HasPreview, 'HasPreview' );
  Assert.IsFalse( rInfo.IsAnimated, 'IsAnimated' );
  Assert.AreEqual( 1, rInfo.FrameCount, 'FrameCount' );
  Assert.AreEqual( 1, rInfo.Orientation, 'Orientation' );
  Assert.IsFalse( rInfo.HasJpegReconstruction, 'HasJpegReconstruction' );
  Assert.AreEqual( 0.0, rInfo.DurationSeconds, 0.0, 'DurationSeconds' );

end;

procedure TTestJxlInfo.Test_ReadInfo_AlphaNonPremultiplied_ReportsStraightAlpha;
begin

  var rInfo := ReadInfoOk( ConformanceInput( 'alpha_nonpremultiplied' ), 'alpha_nonpremultiplied' );
  Assert.AreEqual( Cardinal( 1024 ), rInfo.Width, 'Width' );
  Assert.AreEqual( Cardinal( 12 ), rInfo.BitsPerSample, 'BitsPerSample' );
  Assert.AreEqual( Cardinal( 12 ), rInfo.AlphaBits, 'AlphaBits' );
  Assert.AreEqual( Cardinal( 1 ), rInfo.ExtraChannels, 'ExtraChannels' );
  Assert.IsFalse( rInfo.AlphaPremultiplied, 'AlphaPremultiplied' );
  Assert.IsFalse( rInfo.XybEncoded, 'XybEncoded' );
  Assert.IsFalse( rInfo.HasContainer, 'HasContainer' );

end;

procedure TTestJxlInfo.Test_ReadInfo_AlphaPremultiplied_ReportsPremultipliedAndContainer;
begin

  var rInfo := ReadInfoOk( ConformanceInput( 'alpha_premultiplied' ), 'alpha_premultiplied' );
  Assert.AreEqual( Cardinal( 12 ), rInfo.BitsPerSample, 'BitsPerSample' );
  Assert.AreEqual( Cardinal( 16 ), rInfo.AlphaBits, 'AlphaBits (jxlinfo: 16)' );
  Assert.IsTrue( rInfo.AlphaPremultiplied, 'AlphaPremultiplied' );
  Assert.IsTrue( rInfo.XybEncoded, 'XybEncoded' );
  Assert.IsTrue( rInfo.HasContainer, 'HasContainer' );

end;

procedure TTestJxlInfo.Test_ReadInfo_NewtonsCradle_CountsFramesAndDuration;
begin

  var rInfo := ReadInfoOk( ConformanceInput( 'animation_newtons_cradle' ), 'animation_newtons_cradle' );
  Assert.AreEqual( Cardinal( 480 ), rInfo.Width, 'Width' );
  Assert.AreEqual( Cardinal( 360 ), rInfo.Height, 'Height' );
  Assert.IsTrue( rInfo.IsAnimated, 'IsAnimated' );
  Assert.AreEqual( 36, rInfo.FrameCount, 'FrameCount' );
  Assert.AreEqual( Cardinal( 0 ), rInfo.AnimationLoops, 'AnimationLoops (0 = forever)' );
  Assert.IsTrue( rInfo.TicksPerSecondNumerator > 0, 'TicksPerSecondNumerator' );
  Assert.AreEqual( 0.82, rInfo.DurationSeconds, 0.000001, 'DurationSeconds' );
  Assert.AreEqual( Cardinal( 8 ), rInfo.AlphaBits, 'AlphaBits' );

end;

procedure TTestJxlInfo.Test_ReadInfo_TranscodedJpeg_ReportsReconstructionData;
begin

  var naJxl := JxlTranscodeJpegToJxl( TFile.ReadAllBytes( TestDataFile( 'flower\flower.png.im_q85_420.jpg' ) ), 3 );
  var rInfo := ReadInfoOk( naJxl, 'the recompressed JPEG' );
  Assert.IsTrue( rInfo.HasJpegReconstruction, 'HasJpegReconstruction' );
  Assert.IsTrue( rInfo.HasContainer, 'HasContainer' );
  Assert.IsFalse( rInfo.XybEncoded, 'XybEncoded' );
  Assert.AreEqual( Cardinal( 2268 ), rInfo.Width, 'Width' );
  Assert.AreEqual( Cardinal( 1512 ), rInfo.Height, 'Height' );
  Assert.AreEqual( 1, rInfo.FrameCount, 'FrameCount' );

  var rOptions := TJxlEncodeOptions.Default;
  rOptions.Lossless := True;
  rOptions.Effort   := 1;

  var rLossless := ReadInfoOk( JxlEncodePixels( JxlDecodePixels( naJxl ), rOptions ), 'the lossless encode' );
  Assert.IsFalse( rLossless.HasJpegReconstruction, 'a lossless encode holds no JPEG reconstruction data' );

end;

procedure TTestJxlInfo.Test_ReadInfo_Overloads_AgreeOnSplines;
var
  oStream: TBytesStream;
begin

  var sFileName := TestDataFile( 'splines.jxl' );
  var naData    := TFile.ReadAllBytes( sFileName );
  var rBytes    := ReadInfoOk( naData, 'splines.jxl bytes' );
  var rFile     := ReadInfoOk( sFileName, 'splines.jxl file' );
  oStream := TBytesStream.Create;

  try
    var naJunk: TBytes := [ 1, 2, 3 ];
    oStream.WriteBuffer( naJunk, Length( naJunk ) );
    oStream.WriteBuffer( naData, Length( naData ) );
    oStream.Position := 3;

    var rStream := ReadInfoOk( oStream, 'splines.jxl stream' );
    Assert.AreEqual( Cardinal( 2048 ), rBytes.Width, 'bytes Width' );
    Assert.AreEqual( Cardinal( 2048 ), rBytes.Height, 'bytes Height' );
    Assert.AreEqual( 1, rBytes.FrameCount, 'bytes FrameCount' );
    Assert.AreEqual( rBytes.Width, rFile.Width, 'file Width' );
    Assert.AreEqual( rBytes.Height, rFile.Height, 'file Height' );
    Assert.AreEqual( rBytes.Width, rStream.Width, 'stream Width' );
    Assert.AreEqual( rBytes.Height, rStream.Height, 'stream Height' );
    Assert.AreEqual( rBytes.FrameCount, rStream.FrameCount, 'stream FrameCount' );
  finally
    oStream.Free;
  end;

end;

procedure TTestJxlInfo.Test_ReadInfo_InvalidInput_RaisesEJxlError;
begin

  var naValid := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var naGarbage: TBytes;
  SetLength( naGarbage, 4096 );
  naGarbage[ 0 ] := $FF;
  naGarbage[ 1 ] := $0A;

  for var iI := 2 to High( naGarbage ) do naGarbage[ iI ] := Byte( iI * 37 + 11 );

  var naTruncated := Copy( naValid, 0, 10 );
  var naPng       := TFile.ReadAllBytes( TestDataFile( 'splines.png' ) );
  AssertJxlError( procedure begin JxlReadInfo( naGarbage ); end, 'JxlDecoderProcessInput', False,
    'JxlDecoderProcessInput failed with status 1.', 'random bytes after a signature' );
  AssertJxlError( procedure begin JxlReadInfo( naTruncated ); end, 'JxlDecoderProcessInput', False,
    'JxlDecoderProcessInput failed with status 1.', 'file truncated inside its headers' );
  AssertJxlError( procedure begin JxlReadInfo( naPng ); end, 'JxlDecoderProcessInput', False,
    'JxlDecoderProcessInput failed with status 1.', 'a PNG' );
  AssertJxlError( procedure begin JxlReadInfo( TBytes( nil ) ); end, 'JxlReadInfo', True, 'JxlReadInfo: the input is empty',
    'empty input' );

end;

procedure TTestJxlInfo.Test_ReadInfo_ContainerWalkEdges_ReportedOrAccepted;
var
  iOffset: Integer;
  iSize: Integer;
begin

  var naData := TranscodedFlower;
  Assert.IsTrue( FindBox( naData, 'jbrd', iOffset, iSize ), 'jbrd box' );

  // Cut 5 bytes into the jbrd box's header.
  AssertJxlError( procedure begin JxlReadInfo( Copy( naData, 0, iOffset + 5 ) ); end, 'JxlReadInfo', True,
    'truncated: a box header needs 8 bytes, 5 available', 'cut inside a box header' );

  // A box declaring 4 bytes: less than its own 8-byte header.
  var naSmall := Copy( naData );
  naSmall[ iOffset ]     := 0;
  naSmall[ iOffset + 1 ] := 0;
  naSmall[ iOffset + 2 ] := 0;
  naSmall[ iOffset + 3 ] := 4;
  AssertJxlError( procedure begin JxlReadInfo( naSmall ); end, 'JxlReadInfo', True,
    'invalid: box jbrd declares 4 bytes, less than its own header', 'box smaller than its header' );

  // The last box (a codestream part) with size 0: it runs to the end of the file, which is valid.
  var sCodestream := '';
  iOffset := 0;

  while ( iOffset + 8 <= Length( naData ) ) do
  begin
    iSize := ( naData[ iOffset ] shl 24 ) or ( naData[ iOffset + 1 ] shl 16 ) or ( naData[ iOffset + 2 ] shl 8 ) or naData[ iOffset + 3 ];
    Assert.IsTrue( iSize >= 8, Format( 'box at %d has a 32-bit size', [ iOffset ] ) );

    if ( iOffset + iSize = Length( naData ) ) then
    begin
      sCodestream := TEncoding.ANSI.GetString( naData, iOffset + 4, 4 );
      Break;
    end;

    Inc( iOffset, iSize );
  end;

  Assert.IsTrue( ( sCodestream = 'jxlc' ) or ( sCodestream = 'jxlp' ), Format( 'the last box is %s', [ sCodestream ] ) );

  var naOpenEnded := Copy( naData );
  naOpenEnded[ iOffset ]     := 0;
  naOpenEnded[ iOffset + 1 ] := 0;
  naOpenEnded[ iOffset + 2 ] := 0;
  naOpenEnded[ iOffset + 3 ] := 0;
  Assert.IsTrue( ReadInfoOk( naOpenEnded, 'a last box of size 0' ).HasJpegReconstruction, 'the size-0 last box reads' );
  Assert.AreEqual( 1, ValidateOk( naOpenEnded, 'a last box of size 0' ).DecodedFrameCount, 'the size-0 last box validates' );

  // The codestream box switched to the large-size form (size field 1) and cut 12 bytes into its 16-byte header.
  var naCutLarge := Copy( naData, 0, iOffset + 12 );
  naCutLarge[ iOffset ]     := 0;
  naCutLarge[ iOffset + 1 ] := 0;
  naCutLarge[ iOffset + 2 ] := 0;
  naCutLarge[ iOffset + 3 ] := 1;
  AssertJxlError( procedure begin JxlReadInfo( naCutLarge ); end, 'JxlReadInfo', True,
    Format( 'truncated: box %s needs a 16-byte header, 12 available', [ sCodestream ] ), 'cut 16-byte header' );
  AssertJxlError( procedure begin JxlValidate( naCutLarge ); end, 'JxlValidate', True,
    Format( 'truncated: box %s needs a 16-byte header, 12 available', [ sCodestream ] ), 'JxlValidate, cut 16-byte header' );

end;

procedure TTestJxlInfo.Test_Validate_StreamOverload_ReadsFromPosition;
var
  oStream: TBytesStream;
  rStream: TJxlInfo;
begin

  var naData  := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var rBytes  := ValidateOk( naData, 'splines.jxl bytes' );
  oStream := TBytesStream.Create;

  try
    var naJunk: TBytes := [ 7, 8, 9, 10 ];
    oStream.WriteBuffer( naJunk, Length( naJunk ) );
    oStream.WriteBuffer( naData, Length( naData ) );
    oStream.Position := Length( naJunk );
    rStream := Default( TJxlInfo );
    Assert.WillNotRaise( procedure begin rStream := JxlValidate( oStream ); end, EJxlError, 'JxlValidate rejected the stream' );
    Assert.AreEqual( rBytes.Width, rStream.Width, 'Width' );
    Assert.AreEqual( rBytes.Height, rStream.Height, 'Height' );
    Assert.AreEqual( 1, rStream.DecodedFrameCount, 'the frame was decoded' );
    Assert.AreEqual( Int64( Length( naJunk ) + Length( naData ) ), oStream.Position, 'the stream was read to its end' );

    oStream.Size     := Length( naJunk ) + Length( naData ) div 2;
    oStream.Position := Length( naJunk );
    Assert.WillRaise( procedure begin JxlValidate( oStream ); end, EJxlError, 'a cut file in a stream' );
  finally
    oStream.Free;
  end;

end;

procedure TTestJxlInfo.Test_ReadInfo_Oriented_ReportsStoredOrientationAndSize;
var
  oPng: TPngImage;
begin

  var sFileName := ConformanceInput( 'bench_oriented_brg' );
  var rInfo     := ReadInfoOk( sFileName, 'bench_oriented_brg' );
  Assert.AreEqual( 5, rInfo.Orientation, 'Orientation (transpose)' );
  Assert.AreEqual( Cardinal( 500 ), rInfo.Width, 'stored Width' );
  Assert.AreEqual( Cardinal( 606 ), rInfo.Height, 'stored Height' );
  Assert.AreEqual( Cardinal( 606 ), rInfo.DisplayWidth, 'DisplayWidth' );
  Assert.AreEqual( Cardinal( 500 ), rInfo.DisplayHeight, 'DisplayHeight' );

  oPng := TPngImage.Create;

  try
    oPng.LoadFromFile( TPath.Combine( ExtractFileDir( sFileName ), 'ref.png' ) );
    Assert.AreEqual( Integer( rInfo.DisplayWidth ), oPng.Width, 'ref.png width is the displayed width' );
    Assert.AreEqual( Integer( rInfo.DisplayHeight ), oPng.Height, 'ref.png height is the displayed height' );
  finally
    oPng.Free;
  end;

  var rPixels := JxlDecodePixels( TFile.ReadAllBytes( sFileName ) );
  Assert.AreEqual( Cardinal( 606 ), rPixels.Width, 'decoded pixels are in display orientation (width)' );
  Assert.AreEqual( Cardinal( 500 ), rPixels.Height, 'decoded pixels are in display orientation (height)' );

  var rSplines := ReadInfoOk( TestDataFile( 'splines.jxl' ), 'splines.jxl' );
  Assert.AreEqual( 1, rSplines.Orientation, 'an unoriented file reports 1' );

end;

procedure TTestJxlInfo.Test_DisplaySize_EveryOrientation_MatchesTable;
const
  // Orientation, expected display width, expected display height, for a stored 30 x 20 image.
  EXPECTED: array[ 0..7, 0..2 ] of Cardinal = ( ( 1, 30, 20 ), ( 2, 30, 20 ), ( 3, 30, 20 ), ( 4, 30, 20 ), ( 5, 20, 30 ),
    ( 6, 20, 30 ), ( 7, 20, 30 ), ( 8, 20, 30 ) );
begin

  for var iI := 0 to High( EXPECTED ) do
  begin
    var rInfo := Default( TJxlInfo );
    rInfo.Width       := 30;
    rInfo.Height      := 20;
    rInfo.Orientation := EXPECTED[ iI, 0 ];
    Assert.AreEqual( EXPECTED[ iI, 1 ], rInfo.DisplayWidth, Format( 'orientation %d DisplayWidth', [ rInfo.Orientation ] ) );
    Assert.AreEqual( EXPECTED[ iI, 2 ], rInfo.DisplayHeight, Format( 'orientation %d DisplayHeight', [ rInfo.Orientation ] ) );
  end;

end;

procedure TTestJxlInfo.Test_Validate_ValidFiles_DecodeEveryFrame;
begin

  for var sCase in TArray<string>.Create( 'bike', 'alpha_nonpremultiplied', 'animation_newtons_cradle' ) do
  begin
    var sFileName := ConformanceInput( sCase );
    var rHeaders  := ReadInfoOk( sFileName, sCase );
    var rFull     := ValidateOk( sFileName, sCase );
    Assert.AreEqual( rHeaders.FrameCount, rFull.FrameCount, sCase + ' FrameCount' );
    Assert.AreEqual( rFull.FrameCount, rFull.DecodedFrameCount, sCase + ' every frame decoded' );
    Assert.AreEqual( 0, rHeaders.DecodedFrameCount, sCase + ' JxlReadInfo decodes nothing' );
    Assert.AreEqual( rHeaders.Width, rFull.Width, sCase + ' Width' );
  end;

  var rCradle := ValidateOk( ConformanceInput( 'animation_newtons_cradle' ), 'animation_newtons_cradle' );
  Assert.AreEqual( 36, rCradle.DecodedFrameCount, 'newtons_cradle frames decoded' );

  var rJpeg := ValidateOk( TranscodedFlower, 'the recompressed JPEG' );
  Assert.IsTrue( rJpeg.HasJpegReconstruction, 'recompressed JPEG HasJpegReconstruction' );
  Assert.AreEqual( 1, rJpeg.DecodedFrameCount, 'recompressed JPEG frames decoded' );

end;

procedure TTestJxlInfo.Test_Validate_BareCodestreamCutInPixels_RaisesWhereReadInfoDoesNot;
begin

  var naValid := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var naCut   := Copy( naValid, 0, Length( naValid ) div 2 );
  Assert.IsTrue( JxlHasSignature( naCut ), 'the cut file still starts with a signature' );
  Assert.AreEqual( 1, ValidateOk( naValid, 'the whole splines.jxl' ).DecodedFrameCount, 'the whole file validates' );
  Assert.WillNotRaiseAny( procedure begin JxlReadInfo( naCut ); end, 'JxlReadInfo cannot see a cut in the pixel data' );
  AssertJxlErrorContains( procedure begin JxlValidate( naCut ); end, ' failed with status ', 'JxlValidate must reject the cut file' );

end;

procedure TTestJxlInfo.Test_Validate_CorruptPixelData_RaisesEJxlError;
begin

  var naData := TFile.ReadAllBytes( ConformanceInput( 'bike' ) );

  for var iI := 200000 to 200255 do naData[ iI ] := not naData[ iI ];

  Assert.WillNotRaiseAny( procedure begin JxlReadInfo( naData ); end, 'the headers are intact' );
  AssertJxlErrorContains( procedure begin JxlValidate( naData ); end, ' failed with status ', 'corrupt pixel data' );

end;

procedure TTestJxlInfo.Test_ReadInfo_ContainerCutInsideBox_RaisesNamingTheBox;
var
  iOffset: Integer;
  iSize: Integer;
begin

  var naData := TranscodedFlower;
  Assert.IsTrue( ReadInfoOk( naData, 'the whole container' ).HasContainer, 'the whole container reads' );
  Assert.IsTrue( FindBox( naData, 'jbrd', iOffset, iSize ), 'jbrd box' );

  var naCutJbrd := Copy( naData, 0, iOffset + iSize div 2 );
  var sJbrd     := Format( 'box jbrd declares %d bytes, %d available', [ iSize, Length( naCutJbrd ) - iOffset ] );
  AssertJxlErrorContains( procedure begin JxlReadInfo( naCutJbrd ); end, sJbrd, 'cut inside jbrd' );

  var sCodestream := 'jxlc';

  if ( not FindBox( naData, sCodestream, iOffset, iSize ) ) then
  begin
    sCodestream := 'jxlp';
    Assert.IsTrue( FindBox( naData, sCodestream, iOffset, iSize ), 'codestream box' );
  end;

  var naCutCode := Copy( naData, 0, iOffset + iSize div 2 );
  var sCode     := Format( 'box %s declares %d bytes, %d available', [ sCodestream, iSize, Length( naCutCode ) - iOffset ] );
  AssertJxlErrorContains( procedure begin JxlReadInfo( naCutCode ); end, sCode, 'cut inside the codestream box' );
  AssertJxlErrorContains( procedure begin JxlValidate( naCutCode ); end, sCode, 'JxlValidate, cut inside the codestream box' );

end;

procedure TTestJxlInfo.Test_ReadInfo_ContainerCutInLastBox_ReportsTruncatedBox;
begin

  // Cut 100 bytes short: inside the last box's pixel data, which a header-only read skips.
  var naData   := TranscodedFlower;
  var naCutEnd := Copy( naData, 0, Length( naData ) - 100 );
  AssertJxlErrorContains( procedure begin JxlReadInfo( naCutEnd ); end, 'truncated: box ', 'cut 100 bytes short of the end' );

end;

procedure TTestJxlInfo.Test_ReadInfo_LargeSizeBox_ReadAndCheckedCorrectly;
var
  iOffset: Integer;
  iSize: Integer;
begin

  var naData      := TranscodedFlower;
  var sCodestream := 'jxlc';

  if ( not FindBox( naData, sCodestream, iOffset, iSize ) ) then
  begin
    sCodestream := 'jxlp';
    Assert.IsTrue( FindBox( naData, sCodestream, iOffset, iSize ), 'codestream box' );
  end;

  // Rewrite the box with size field 1 and the real size (8 bytes larger, for the longer header) as 64 bits.
  var iLarge: UInt64 := iSize + 8;
  var naLarge: TBytes;
  SetLength( naLarge, Length( naData ) + 8 );
  Move( naData[ 0 ], naLarge[ 0 ], iOffset );
  naLarge[ iOffset ]     := 0;
  naLarge[ iOffset + 1 ] := 0;
  naLarge[ iOffset + 2 ] := 0;
  naLarge[ iOffset + 3 ] := 1;
  Move( naData[ iOffset + 4 ], naLarge[ iOffset + 4 ], 4 );

  for var iI := 0 to 7 do naLarge[ iOffset + 8 + iI ] := Byte( iLarge shr ( 8 * ( 7 - iI ) ) );

  Move( naData[ iOffset + 8 ], naLarge[ iOffset + 16 ], Length( naData ) - iOffset - 8 );

  var rInfo := ValidateOk( naLarge, 'the container with a large-size box' );
  Assert.IsTrue( rInfo.HasJpegReconstruction, 'the rewritten file reads whole' );
  Assert.AreEqual( 1, rInfo.DecodedFrameCount, 'the rewritten file validates' );

  // Cut inside the rewritten box itself: past its 16-byte header, half-way through its payload.
  var naCut := Copy( naLarge, 0, iOffset + 16 + ( iSize - 8 ) div 2 );
  var sCut  := Format( 'box %s declares %d bytes, %d available', [ sCodestream, iLarge, Length( naCut ) - iOffset ] );
  AssertJxlErrorContains( procedure begin JxlReadInfo( naCut ); end, sCut, 'large-size box cut short' );

end;

/// <summary>Returns a 16 x 16 gradient with 1 (grey) or 3 (RGB) channels and no profile.</summary>
/// <param name="AChannels">1 or 3.</param>
/// <returns>The pixels.</returns>
function GradientPixels( AChannels: Cardinal ): TJxlPixels;
begin

  Result             := Default( TJxlPixels );
  Result.Width       := 16;
  Result.Height      := 16;
  Result.NumChannels := AChannels;
  SetLength( Result.Data, 16 * 16 * AChannels );

  for var iI := 0 to High( Result.Data ) do Result.Data[ iI ] := Byte( iI * 7 );

end;

/// <summary>Returns lossless encoder settings at effort 3.</summary>
/// <returns>The settings.</returns>
function LosslessFast: TJxlEncodeOptions;
begin

  Result          := TJxlEncodeOptions.Default;
  Result.Lossless := True;
  Result.Effort   := 3;

end;

procedure TTestJxlInfo.Test_ReadInfo_Bike_SrgbPrimariesWithBt709TransferIsNotSrgb;
begin

  var rInfo := ReadInfoOk( ConformanceInput( 'bike' ), 'bike' );
  Assert.IsFalse( rInfo.HasIccProfile, 'HasIccProfile' );
  Assert.AreEqual( UInt64( 0 ), rInfo.IccProfileSize, 'IccProfileSize' );
  Assert.AreEqual( Ord( jcsRgb ), Ord( rInfo.ColourSpace ), 'ColourSpace' );
  Assert.AreEqual( Ord( JXL_PRIMARIES_SRGB ), Ord( rInfo.ColourEncoding.primaries ), 'primaries' );
  Assert.AreEqual( Ord( JXL_WHITE_POINT_D65 ), Ord( rInfo.ColourEncoding.white_point ), 'white point' );
  Assert.AreEqual( Ord( JXL_TRANSFER_FUNCTION_709 ), Ord( rInfo.ColourEncoding.transfer_function ), 'transfer function' );
  Assert.IsFalse( rInfo.IsSrgb, 'IsSrgb: the BT.709 transfer curve is not sRGB''s' );

end;

type
  /// <summary>One case of <c>Test_ReadInfo_EncodedProfiles_IsSrgbOnlyForSrgb</c>.</summary>
  TColourCase = record
    /// <summary>What the case is, for the messages.</summary>
    Name: string;
    /// <summary>The encoded profile the file declares.</summary>
    Encoding: JxlColorEncoding;
    /// <summary>The colour space expected.</summary>
    Space: TJxlColourSpace;
    /// <summary>The <c>IsSrgb</c> expected.</summary>
    Srgb: Boolean;
  end;

/// <summary>Returns one case of <c>Test_ReadInfo_EncodedProfiles_IsSrgbOnlyForSrgb</c>.</summary>
/// <param name="AName">What the case is.</param>
/// <param name="AEncoding">The encoded profile.</param>
/// <param name="ASpace">The colour space expected.</param>
/// <param name="ASrgb">The <c>IsSrgb</c> expected.</param>
/// <returns>The case.</returns>
function ColourCase( const AName: string; const AEncoding: JxlColorEncoding; ASpace: TJxlColourSpace; ASrgb: Boolean ): TColourCase;
begin

  Result.Name     := AName;
  Result.Encoding := AEncoding;
  Result.Space    := ASpace;
  Result.Srgb     := ASrgb;

end;

procedure TTestJxlInfo.Test_ReadInfo_EncodedProfiles_IsSrgbOnlyForSrgb;
begin

  var rSrgb := Default( JxlColorEncoding );
  JxlColorEncodingSetToSRGB( @rSrgb, JXL_FALSE );
  var rGrey := Default( JxlColorEncoding );
  JxlColorEncodingSetToSRGB( @rGrey, JXL_TRUE );
  var rLinear := Default( JxlColorEncoding );
  JxlColorEncodingSetToLinearSRGB( @rLinear, JXL_FALSE );
  var rLinearGrey := Default( JxlColorEncoding );
  JxlColorEncodingSetToLinearSRGB( @rLinearGrey, JXL_TRUE );

  var rAbsolute := rSrgb;
  rAbsolute.rendering_intent := JXL_RENDERING_INTENT_ABSOLUTE;
  var rP3 := rSrgb;
  rP3.primaries := JXL_PRIMARIES_P3;
  var rWhiteE := rSrgb;
  rWhiteE.white_point := JXL_WHITE_POINT_E;
  var rBt709 := rSrgb;
  rBt709.transfer_function := JXL_TRANSFER_FUNCTION_709;

  var arCases: TArray<TColourCase> := [ ColourCase( 'sRGB', rSrgb, jcsRgb, True ),
    ColourCase( 'sRGB, absolute intent', rAbsolute, jcsRgb, True ), ColourCase( 'grey sRGB', rGrey, jcsGrey, True ),
    ColourCase( 'linear sRGB', rLinear, jcsRgb, False ), ColourCase( 'Display P3', rP3, jcsRgb, False ),
    ColourCase( 'sRGB, white point E', rWhiteE, jcsRgb, False ), ColourCase( 'sRGB primaries, BT.709', rBt709, jcsRgb, False ),
    ColourCase( 'linear grey', rLinearGrey, jcsGrey, False ) ];

  for var rEach in arCases do
  begin
    var rInfo := ReadInfoOk( EncodeWithColourEncoding( rEach.Encoding ), rEach.Name );
    Assert.AreEqual( rEach.Srgb, rInfo.IsSrgb, rEach.Name + ': IsSrgb' );
    Assert.AreEqual( Ord( rEach.Space ), Ord( rInfo.ColourSpace ), rEach.Name + ': ColourSpace' );
    Assert.IsFalse( rInfo.HasIccProfile, rEach.Name + ': HasIccProfile' );
    Assert.AreEqual( UInt64( 0 ), rInfo.IccProfileSize, rEach.Name + ': IccProfileSize' );
    Assert.AreEqual( Ord( rEach.Encoding.white_point ), Ord( rInfo.ColourEncoding.white_point ), rEach.Name + ': white point' );
    Assert.AreEqual( Ord( rEach.Encoding.transfer_function ), Ord( rInfo.ColourEncoding.transfer_function ),
      rEach.Name + ': transfer function' );
    Assert.AreEqual( Ord( rEach.Encoding.rendering_intent ), Ord( rInfo.ColourEncoding.rendering_intent ),
      rEach.Name + ': rendering intent' );

    if ( rEach.Space = jcsRgb ) then
      Assert.AreEqual( Ord( rEach.Encoding.primaries ), Ord( rInfo.ColourEncoding.primaries ), rEach.Name + ': primaries' );

  end;

end;

procedure TTestJxlInfo.Test_ReadInfo_BindingOutput_IsSrgb;
begin

  var rLossy := TJxlEncodeOptions.Default;
  rLossy.Effort := 3;

  var naRgb      := JxlEncodePixels( GradientPixels( 3 ), LosslessFast );
  var naLossy    := JxlEncodePixels( GradientPixels( 3 ), rLossy );
  var naGrey     := JxlEncodePixels( GradientPixels( 1 ), LosslessFast );
  var rRgb       := ReadInfoOk( naRgb, 'lossless RGB' );
  var rLossyInfo := ReadInfoOk( naLossy, 'lossy RGB' );
  var rGrey      := ReadInfoOk( naGrey, 'lossless grey' );

  Assert.IsTrue( rRgb.IsSrgb, 'lossless RGB: IsSrgb' );
  Assert.AreEqual( Ord( jcsRgb ), Ord( rRgb.ColourSpace ), 'lossless RGB: ColourSpace' );
  Assert.IsFalse( rRgb.HasIccProfile, 'lossless RGB: HasIccProfile' );
  Assert.IsTrue( rLossyInfo.XybEncoded, 'lossy RGB is XYB-coded' );
  Assert.IsTrue( rLossyInfo.IsSrgb, 'lossy RGB: IsSrgb (the original space, not the coding space)' );
  Assert.AreEqual( Ord( jcsRgb ), Ord( rLossyInfo.ColourSpace ), 'lossy RGB: ColourSpace' );
  Assert.IsTrue( rGrey.IsSrgb, 'lossless grey: IsSrgb' );
  Assert.AreEqual( Ord( jcsGrey ), Ord( rGrey.ColourSpace ), 'lossless grey: ColourSpace' );

  var rValidated := ValidateOk( naRgb, 'lossless RGB' );
  Assert.IsTrue( rValidated.IsSrgb, 'JxlValidate: IsSrgb' );
  Assert.AreEqual( Ord( jcsRgb ), Ord( rValidated.ColourSpace ), 'JxlValidate: ColourSpace' );

end;

procedure TTestJxlInfo.Test_ReadInfo_IccProfiles_ReportedWithSizeAndSpace;
begin

  for var sName in [ 'Rec2020-v4.icc', 'sRGB-v4.icc', 'sGrey-v4.icc' ] do
  begin
    var naProfile := CompactIccProfile( sName );
    var bGrey     := ( sName = 'sGrey-v4.icc' );
    var rPixels   := GradientPixels( if bGrey then 1 else 3 );
    rPixels.IccProfile := naProfile;

    var naJxl := JxlEncodePixels( rPixels, LosslessFast );
    AssertIccColour( ReadInfoOk( naJxl, sName ), if bGrey then jcsGrey else jcsRgb, Length( naProfile ), sName );
    AssertIccColour( ValidateOk( naJxl, sName ), if bGrey then jcsGrey else jcsRgb, Length( naProfile ), sName + ' validated' );
  end;

end;

procedure TTestJxlInfo.Test_ReadInfo_ConformanceColour_GreySpotAndCmyk;
begin

  var rGrey := ReadInfoOk( ConformanceInput( 'grayscale' ), 'grayscale' );
  Assert.AreEqual( Cardinal( 1 ), rGrey.ColourChannels, 'grayscale: ColourChannels' );
  Assert.IsTrue( rGrey.IccProfileSize > 128, 'grayscale: a whole ICC profile' );
  AssertIccColour( rGrey, jcsGrey, rGrey.IccProfileSize, 'grayscale' );

  AssertIccColour( ReadInfoOk( ConformanceInput( 'spot' ), 'spot' ), jcsRgb, 940, 'spot' );

  var rCmyk := ReadInfoOk( ConformanceInput( 'cmyk_layers' ), 'cmyk_layers' );
  Assert.IsTrue( rCmyk.HasIccProfile, 'cmyk_layers: HasIccProfile' );
  Assert.IsTrue( rCmyk.IccProfileSize > 128, 'cmyk_layers: a whole ICC profile' );
  Assert.AreEqual( Ord( jcsUnknown ), Ord( rCmyk.ColourSpace ), 'cmyk_layers: a CMYK profile''s colour space is unknown' );
  Assert.IsFalse( rCmyk.IsSrgb, 'cmyk_layers: IsSrgb' );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlInfo );

end.
