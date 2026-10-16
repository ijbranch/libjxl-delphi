(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of the resource limits of <c>Jxl.Graphic</c> (<c>TJxlLimits</c>): the pixel, extra-channel, input, memory
///   and output limits on every routine they apply to, the JPEG pre-check that runs before libjxl sees a JPEG, and the
///   validation of the limits themselves. The JPEGs here are small synthetic headers built in the test.
/// </summary>
unit TestJxl.Limits;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of <c>TJxlLimits</c> and the JPEG pre-check.</summary>
  [ TestFixture ]
  TTestJxlLimits = class
  public
    /// <summary>Restores the process-wide default limits after every test, so that no test leaks a changed default.</summary>
    [ TearDown ]
    procedure TearDown;
    /// <summary>
    ///   Proves the built-in defaults for this architecture, field by field, against hand-typed values: Win64 256 Mi
    ///   pixels, 8 GiB memory, 1 GiB in and out; Win32 32 Mi pixels, 1 GiB memory, 256 MiB in and out; both 16 extra
    ///   channels and 64 JPEG scans. A newly started process uses them.
    /// </summary>
    [ Test ]
    procedure Test_Default_PerArchitectureValues;
    /// <summary>
    ///   Proves a limits record with any field zero is refused with <c>EArgumentException</c> by every entry point
    ///   that takes one (the per-call overloads, <c>JxlSetDefaultLimits</c>, <c>TJxlImage.Limits</c>), and that a
    ///   refused default leaves the old default in place.
    /// </summary>
    [ Test ]
    procedure Test_InvalidLimits_RaiseEArgumentException;
    /// <summary>
    ///   Proves <c>MaxPixels</c> is enforced from the header by every decoding routine (pixels, bitmap, information,
    ///   validation, JPEG reconstruction, <c>TJxlImage</c>), as a binding check naming the routine and the limit, and
    ///   that an image of exactly <c>MaxPixels</c> is accepted.
    /// </summary>
    [ Test ]
    procedure Test_MaxPixels_EnforcedByEveryDecoder;
    /// <summary>
    ///   Proves <c>MaxExtraChannels</c>: the conformance <c>cmyk_layers</c> image (black, alpha and more) is refused when
    ///   the limit is one below its channel count and read when it equals it.
    /// </summary>
    [ Test ]
    procedure Test_MaxExtraChannels_Enforced;
    /// <summary>
    ///   Proves <c>MaxInputBytes</c> is checked before a stream or file is read: a stream one byte over the limit is
    ///   refused without its position moving, the file and bytes overloads are refused too, and input of exactly the
    ///   limit is accepted.
    /// </summary>
    [ Test ]
    procedure Test_MaxInputBytes_RefusedBeforeReading;
    /// <summary>
    ///   Proves the memory budget surfaces as a clean <c>EJxlError</c>: with <c>MaxMemoryBytes</c> at 1 MiB, decoding,
    ///   validating and encoding a large image each fail naming the routine and the limit (libjxl's allocations were
    ///   refused), and the next call with the default limits works; JPEG reconstruction refuses, from the header, a
    ///   JPEG whose DCT coefficients alone (hand-computed: 20611584 bytes) exceed the limit.
    /// </summary>
    [ Test ]
    procedure Test_MaxMemoryBytes_BudgetRefusalIsCleanError;
    /// <summary>
    ///   Proves output growth stops at <c>MaxOutputBytes</c>: a lossless encode larger than 100000 bytes and a JPEG
    ///   reconstruction one byte over the limit are refused naming the limit, and a reconstruction of exactly the
    ///   JPEG's size succeeds byte-identical.
    /// </summary>
    [ Test ]
    procedure Test_MaxOutputBytes_StopsGrowth;
    /// <summary>
    ///   Proves the JPEG pre-check rejects bad structure before libjxl sees it, each as a binding check naming
    ///   <c>JxlTranscodeJpegToJxl</c>: empty input, a PNG, garbage after the start marker, a cut segment, a missing end
    ///   marker, zero size, five components, a bad sampling factor, a scan before the frame and two frames. A
    ///   structurally sound header without tables gets past the pre-check and is refused by libjxl instead.
    /// </summary>
    [ Test ]
    procedure Test_JpegPrecheck_RejectsBadStructure;
    /// <summary>
    ///   Proves the JPEG pre-check enforces the limits: a 65535 x 65535 frame exceeds <c>MaxPixels</c>, a 2000 x 2000
    ///   colour frame exceeds a 1 MiB <c>MaxMemoryBytes</c> in DCT coefficients, and four scans exceed
    ///   <c>MaxJpegScans</c> = 3 while three do not; a frame of exactly <c>MaxPixels</c> passes and one more column
    ///   does not.
    /// </summary>
    [ Test ]
    procedure Test_JpegPrecheck_EnforcesLimits;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Graphics,
  Jxl.Graphic,
  TestJxl.Common;

const
  /// <summary>Name every JPEG pre-check error carries.</summary>
  TRANSCODE = 'JxlTranscodeJpegToJxl';

/// <summary>
///   Builds a minimal JPEG: start marker, one baseline frame header, a number of one-component scans each followed by
///   one byte of entropy-coded data, and the end marker. It has no quantisation or Huffman tables, so libjxl refuses
///   it, but its marker structure is sound.
/// </summary>
/// <param name="AWidth">Frame width.</param>
/// <param name="AHeight">Frame height.</param>
/// <param name="AComponents">Component count.</param>
/// <param name="AScans">Scan count.</param>
/// <param name="ASampling">Sampling factors byte (H shl 4 or V) of the first component; the others use 1 x 1.</param>
/// <returns>The JPEG bytes.</returns>
function BuildJpeg( AWidth: Integer; AHeight: Integer; AComponents: Integer; AScans: Integer; ASampling: Byte = $11 ): TBytes;
begin

  Result := [ $FF, $D8, $FF, $C0, Byte( ( 8 + 3 * AComponents ) shr 8 ), Byte( 8 + 3 * AComponents ), 8, Byte( AHeight shr 8 ),
    Byte( AHeight ), Byte( AWidth shr 8 ), Byte( AWidth ), Byte( AComponents ) ];

  for var iI := 0 to AComponents - 1 do
    Result := Result + [ Byte( iI + 1 ), if ( iI = 0 ) then ASampling else Byte( $11 ), 0 ];

  for var iI := 1 to AScans do Result := Result + [ $FF, $DA, 0, 8, 1, 1, 0, 0, 63, 0, $00 ];

  Result := Result + [ $FF, $D9 ];

end;

/// <summary>Returns the default limits with one change applied by the caller.</summary>
/// <returns>A copy of <c>TJxlLimits.Default</c>.</returns>
function Limits: TJxlLimits;
begin

  Result := TJxlLimits.Default;

end;

/// <summary>Returns <c>flower.png.im_q85_420.jpg</c> recompressed by the binding.</summary>
/// <param name="AJpeg">Receives the original JPEG.</param>
/// <returns>The JPEG XL file.</returns>
function TranscodedFlower( out AJpeg: TBytes ): TBytes;
begin

  AJpeg  := TFile.ReadAllBytes( TestDataFile( 'flower\flower.png.im_q85_420.jpg' ) );
  Result := JxlTranscodeJpegToJxl( AJpeg, 3 );

end;

{ TTestJxlLimits }

procedure TTestJxlLimits.TearDown;
begin

  JxlSetDefaultLimits( TJxlLimits.Default );

end;

procedure TTestJxlLimits.Test_Default_PerArchitectureValues;
begin

  var rLimits := TJxlLimits.Default;
{$IFDEF CPU64BITS}
  Assert.AreEqual( UInt64( 268435456 ), rLimits.MaxPixels, 'MaxPixels' );
  Assert.AreEqual( Int64( 8589934592 ), rLimits.MaxMemoryBytes, 'MaxMemoryBytes' );
  Assert.AreEqual( Int64( 1073741824 ), rLimits.MaxInputBytes, 'MaxInputBytes' );
  Assert.AreEqual( Int64( 1073741824 ), rLimits.MaxOutputBytes, 'MaxOutputBytes' );
{$ELSE}
  Assert.AreEqual( UInt64( 33554432 ), rLimits.MaxPixels, 'MaxPixels' );
  Assert.AreEqual( Int64( 1073741824 ), rLimits.MaxMemoryBytes, 'MaxMemoryBytes' );
  Assert.AreEqual( Int64( 268435456 ), rLimits.MaxInputBytes, 'MaxInputBytes' );
  Assert.AreEqual( Int64( 268435456 ), rLimits.MaxOutputBytes, 'MaxOutputBytes' );
{$ENDIF}
  Assert.AreEqual( Cardinal( 16 ), rLimits.MaxExtraChannels, 'MaxExtraChannels' );
  Assert.AreEqual( Cardinal( 64 ), rLimits.MaxJpegScans, 'MaxJpegScans' );

  var rCurrent := JxlGetDefaultLimits;
  Assert.AreEqual( rLimits.MaxPixels, rCurrent.MaxPixels, 'the process default starts as TJxlLimits.Default (MaxPixels)' );
  Assert.AreEqual( rLimits.MaxMemoryBytes, rCurrent.MaxMemoryBytes, 'the process default starts as TJxlLimits.Default (MaxMemoryBytes)' );

end;

procedure TTestJxlLimits.Test_InvalidLimits_RaiseEArgumentException;
var
  oImage: TJxlImage;
begin

  var naData := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );

  for var iField := 0 to 5 do
  begin
    var rBad := Limits;

    case iField of
      0: rBad.MaxPixels        := 0;
      1: rBad.MaxExtraChannels := 0;
      2: rBad.MaxInputBytes    := 0;
      3: rBad.MaxOutputBytes   := -1;
      4: rBad.MaxMemoryBytes   := 0;
      5: rBad.MaxJpegScans     := 0;
    end;

    Assert.WillRaise( procedure begin JxlDecodePixels( naData, jcoSrgb, rBad ); end, EArgumentException,
      Format( 'JxlDecodePixels, field %d', [ iField ] ) );
    Assert.WillRaise( procedure begin JxlSetDefaultLimits( rBad ); end, EArgumentException,
      Format( 'JxlSetDefaultLimits, field %d', [ iField ] ) );
  end;

  var rZero := Limits;
  rZero.MaxPixels := 0;
  Assert.WillRaise( procedure begin JxlReadInfo( naData, rZero ); end, EArgumentException, 'JxlReadInfo' );
  Assert.WillRaise( procedure begin JxlValidate( naData, rZero ); end, EArgumentException, 'JxlValidate' );
  Assert.WillRaise( procedure begin JxlReconstructJpeg( naData, rZero ); end, EArgumentException, 'JxlReconstructJpeg' );
  Assert.AreEqual( TJxlLimits.Default.MaxPixels, JxlGetDefaultLimits.MaxPixels, 'a refused default leaves the old one' );

  oImage := TJxlImage.Create;

  try
    Assert.WillRaise( procedure begin oImage.Limits := rZero; end, EArgumentException, 'TJxlImage.Limits' );
    Assert.AreEqual( TJxlLimits.Default.MaxPixels, oImage.Limits.MaxPixels, 'TJxlImage.Limits keeps its value' );
  finally
    oImage.Free;
  end;

end;

procedure TTestJxlLimits.Test_MaxPixels_EnforcedByEveryDecoder;
var
  oBitmap: TBitmap;
  oImage: TJxlImage;
  oStream: TBytesStream;
  naJpeg: TBytes;
begin

  var naData := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var rLimits := Limits;
  rLimits.MaxPixels := 2048 * 2048 - 1;

  var sText := 'the image is 2048 x 2048 pixels, more than TJxlLimits.MaxPixels (4194303)';
  AssertJxlError( procedure begin JxlDecodePixels( naData, jcoSrgb, rLimits ); end, 'JxlDecodePixels', True, sText, 'JxlDecodePixels' );
  AssertJxlError( procedure begin JxlReadInfo( naData, rLimits ); end, 'JxlReadInfo', True, sText, 'JxlReadInfo' );
  AssertJxlError( procedure begin JxlValidate( naData, rLimits ); end, 'JxlValidate', True, sText, 'JxlValidate' );

  oBitmap := TBitmap.Create;
  oImage  := TJxlImage.Create;
  oStream := TBytesStream.Create( naData );

  try
    AssertJxlError( procedure begin JxlDecodeToBitmap( naData, oBitmap, rLimits ); end, 'JxlDecodeToBitmap', True, sText,
      'JxlDecodeToBitmap' );
    oImage.Limits := rLimits;
    AssertJxlError( procedure begin oImage.LoadFromStream( oStream ); end, 'JxlDecodeToBitmap', True, sText,
      'TJxlImage.LoadFromStream' );

    // Exactly the limit is accepted.
    rLimits.MaxPixels := 2048 * 2048;
    Assert.AreEqual( Cardinal( 2048 ), JxlDecodePixels( naData, jcoSrgb, rLimits ).Width, 'exactly MaxPixels decodes' );
    oImage.Limits    := rLimits;
    oStream.Position := 0;
    oImage.LoadFromStream( oStream );
    Assert.AreEqual( 2048, oImage.Width, 'TJxlImage loads exactly MaxPixels' );
  finally
    oStream.Free;
    oImage.Free;
    oBitmap.Free;
  end;

  var naJxl := TranscodedFlower( naJpeg );
  rLimits.MaxPixels := 2268 * 1512 - 1;
  AssertJxlError( procedure begin JxlReconstructJpeg( naJxl, rLimits ); end, 'JxlReconstructJpeg', True,
    'the image is 2268 x 1512 pixels, more than TJxlLimits.MaxPixels (3429215)', 'JxlReconstructJpeg' );

  // The process-wide default reaches TPicture, which creates its TJxlImage itself.
  var oPicture := TPicture.Create;

  try
    rLimits.MaxPixels := 2048 * 2048 - 1;
    JxlSetDefaultLimits( rLimits );
    AssertJxlError( procedure begin oPicture.LoadFromFile( TestDataFile( 'splines.jxl' ) ); end, 'JxlDecodeToBitmap', True, sText,
      'TPicture.LoadFromFile under the default limits' );
  finally
    oPicture.Free;
  end;

end;

procedure TTestJxlLimits.Test_MaxExtraChannels_Enforced;
begin

  var sFolder := ConformanceCaseFolder( 'cmyk_layers' );

  if ( sFolder = '' ) then Assert.Ignore( 'libjxl conformance suite not found: ' + CONFORMANCE_HINT );

  var naData := TFile.ReadAllBytes( TPath.Combine( sFolder, 'input.jxl' ) );
  var rInfo  := JxlReadInfo( naData );
  Assert.IsTrue( rInfo.ExtraChannels >= 2, Format( 'cmyk_layers has %d extra channels', [ rInfo.ExtraChannels ] ) );

  var rLimits := Limits;
  rLimits.MaxExtraChannels := rInfo.ExtraChannels - 1;
  AssertJxlError( procedure begin JxlReadInfo( naData, rLimits ); end, 'JxlReadInfo', True,
    Format( 'the image has %d extra channels, more than TJxlLimits.MaxExtraChannels (%d)', [ rInfo.ExtraChannels,
    rLimits.MaxExtraChannels ] ), 'one channel over' );
  AssertJxlError( procedure begin JxlDecodePixels( naData, jcoSrgb, rLimits ); end, 'JxlDecodePixels', True,
    'TJxlLimits.MaxExtraChannels', 'JxlDecodePixels, one channel over' );

  rLimits.MaxExtraChannels := rInfo.ExtraChannels;
  Assert.AreEqual( rInfo.Width, JxlReadInfo( naData, rLimits ).Width, 'exactly MaxExtraChannels is read' );

end;

procedure TTestJxlLimits.Test_MaxInputBytes_RefusedBeforeReading;
var
  oStream: TBytesStream;
  oBitmap: TBitmap;
begin

  var sFileName := TestDataFile( 'splines.jxl' );
  var naData    := TFile.ReadAllBytes( sFileName );
  var rLimits   := Limits;
  rLimits.MaxInputBytes := Length( naData ) - 1;

  var sText := Format( 'the input is %d bytes, more than TJxlLimits.MaxInputBytes (%d)', [ Length( naData ), Length( naData ) - 1 ] );
  AssertJxlError( procedure begin JxlReadInfo( naData, rLimits ); end, 'JxlReadInfo', True, sText, 'bytes overload' );

  JxlSetDefaultLimits( rLimits );
  oStream := TBytesStream.Create( naData );
  oBitmap := TBitmap.Create;

  try
    oStream.Position := 0;
    AssertJxlError( procedure begin JxlReadInfo( oStream ); end, 'JxlReadInfo', True, sText, 'stream overload' );
    Assert.AreEqual( Int64( 0 ), oStream.Position, 'the stream was not read' );
    AssertJxlError( procedure begin JxlValidate( sFileName ); end, 'JxlValidate', True, sText, 'file overload' );
    AssertJxlError( procedure begin JxlDecodeFileToBitmap( sFileName, oBitmap ); end, 'JxlDecodeFileToBitmap', True, sText,
      'JxlDecodeFileToBitmap' );
  finally
    oBitmap.Free;
    oStream.Free;
  end;

  rLimits.MaxInputBytes := Length( naData );
  JxlSetDefaultLimits( rLimits );
  Assert.AreEqual( Cardinal( 2048 ), JxlReadInfo( sFileName ).Width, 'exactly MaxInputBytes is read' );

end;

procedure TTestJxlLimits.Test_MaxMemoryBytes_BudgetRefusalIsCleanError;
begin

  var naData := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var rLimits := Limits;
  rLimits.MaxMemoryBytes := 1024 * 1024;

  var sText := 'libjxl needed more memory than TJxlLimits.MaxMemoryBytes allows (1048576 bytes; ';
  AssertJxlError( procedure begin JxlDecodePixels( naData, jcoSrgb, rLimits ); end, 'JxlDecodePixels', True, sText, 'decode' );
  AssertJxlError( procedure begin JxlValidate( naData, rLimits ); end, 'JxlValidate', True, sText, 'validate' );

  var rPixels := LoadPngPixels( TestDataFile( 'flower\flower.png' ) );
  var rOptions := TJxlEncodeOptions.Default;
  rOptions.Effort := 3;
  AssertJxlError( procedure begin JxlEncodePixels( rPixels, rOptions, rLimits ); end, 'JxlEncodePixels', True, sText, 'encode' );

  Assert.AreEqual( Cardinal( 2048 ), JxlDecodePixels( naData ).Width, 'a decode under the default limits still works' );

  // JPEG reconstruction estimates the coefficient memory from the header before decoding: 2268 x 1512 is 284 x 189
  // blocks of 64 two-byte coefficients in 3 components, 20611584 bytes.
  var naJpeg: TBytes;
  var naJxl := TranscodedFlower( naJpeg );
  rLimits.MaxMemoryBytes := 20000000;
  AssertJxlError( procedure begin JxlReconstructJpeg( naJxl, rLimits ); end, 'JxlReconstructJpeg', True,
    'the JPEG would need 20611584 bytes of DCT coefficients, more than TJxlLimits.MaxMemoryBytes (20000000)',
    'reconstruction coefficient estimate' );

end;

procedure TTestJxlLimits.Test_MaxOutputBytes_StopsGrowth;
var
  naJpeg: TBytes;
begin

  var rPixels  := LoadPngPixels( TestDataFile( 'flower\flower.png' ) );
  var rOptions := TJxlEncodeOptions.Default;
  rOptions.Lossless := True;
  rOptions.Effort   := 1;

  var rLimits := Limits;
  rLimits.MaxOutputBytes := 100000;
  AssertJxlError( procedure begin JxlEncodePixels( rPixels, rOptions, rLimits ); end, 'JxlEncodePixels', True,
    'the output would exceed 100000 bytes (TJxlLimits.MaxOutputBytes)', 'lossless encode over 100000 bytes' );

  var naJxl := TranscodedFlower( naJpeg );
  rLimits.MaxOutputBytes := Length( naJpeg ) - 1;
  AssertJxlError( procedure begin JxlReconstructJpeg( naJxl, rLimits ); end, 'JxlReconstructJpeg', True,
    Format( 'the output would exceed %d bytes (TJxlLimits.MaxOutputBytes)', [ Length( naJpeg ) - 1 ] ), 'reconstruction one byte over' );

  rLimits.MaxOutputBytes := Length( naJpeg );
  Assert.AreEqual( -1, FirstDifference( naJpeg, JxlReconstructJpeg( naJxl, rLimits ) ), 'a reconstruction of exactly the limit' );

end;

procedure TTestJxlLimits.Test_JpegPrecheck_RejectsBadStructure;
begin

  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( nil ); end, TRANSCODE, True, 'the input is empty', 'empty input' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( TFile.ReadAllBytes( TestDataFile( 'splines.png' ) ) ); end, TRANSCODE, True,
    'the JPEG does not start with a start-of-image marker', 'a PNG' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( [ $FF, $D8, $00, $11, $22, $33 ] ); end, TRANSCODE, True,
    'the JPEG is garbled: no marker at offset 2', 'garbage after the start marker' );

  var naGood := BuildJpeg( 16, 16, 3, 1 );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( Copy( naGood, 0, 10 ) ); end, TRANSCODE, True,
    'the JPEG is truncated: a segment at offset 4 declares 17 bytes, 6 remain', 'cut inside the frame header' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( Copy( naGood, 0, Length( naGood ) - 2 ) ); end, TRANSCODE, True,
    'the JPEG is truncated inside its entropy-coded data', 'no end marker' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 0, 16, 3, 1 ) ); end, TRANSCODE, True,
    'the JPEG declares a zero width or height', 'zero width' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 16, 16, 5, 1 ) ); end, TRANSCODE, True,
    'the JPEG has 5 components; 1 to 4 are supported', 'five components' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 16, 16, 3, 1, $01 ) ); end, TRANSCODE, True,
    'the JPEG has an invalid sampling factor', 'horizontal sampling factor 0' );

  // A scan before the frame header: the start marker, then a scan, then the frame.
  var naScanFirst: TBytes := [ $FF, $D8, $FF, $DA, 0, 8, 1, 1, 0, 0, 63, 0, $00 ] + Copy( naGood, 2, Length( naGood ) - 2 );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( naScanFirst ); end, TRANSCODE, True,
    'the JPEG has a scan before its frame header', 'scan first' );

  // Two frame headers.
  var naTwoFrames: TBytes := Copy( naGood, 0, 2 + 2 + 17 ) + Copy( naGood, 2, Length( naGood ) - 2 );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( naTwoFrames ); end, TRANSCODE, True,
    'the JPEG has more than one frame header', 'two frames' );

  // Sound structure but no tables: the pre-check passes it, and libjxl refuses it.
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( naGood ); end, 'JxlEncoderAddJPEGFrame', False,
    'JxlEncoderAddJPEGFrame failed with status ', 'a sound header without tables reaches libjxl' );

end;

procedure TTestJxlLimits.Test_JpegPrecheck_EnforcesLimits;
begin

  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 65535, 65535, 3, 1 ) ); end, TRANSCODE, True,
    'the JPEG is 65535 x 65535 pixels, more than TJxlLimits.MaxPixels', '65535 x 65535 under the default limits' );

  var rLimits := Limits;
  rLimits.MaxMemoryBytes := 1024 * 1024;

  // 2000 x 2000, three components at 1 x 1: 250 x 250 blocks each, 64 coefficients of 2 bytes: 24000000 bytes.
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 2000, 2000, 3, 1 ), 7, rLimits ); end, TRANSCODE, True,
    'the JPEG would need 24000000 bytes of DCT coefficients, more than TJxlLimits.MaxMemoryBytes (1048576)',
    'coefficient memory over 1 MiB' );

  rLimits := Limits;
  rLimits.MaxJpegScans := 3;
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 16, 16, 1, 4 ), 7, rLimits ); end, TRANSCODE, True,
    'the JPEG has more than 3 scans (TJxlLimits.MaxJpegScans)', 'four scans' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 16, 16, 1, 3 ), 7, rLimits ); end, 'JxlEncoderAddJPEGFrame',
    False, 'JxlEncoderAddJPEGFrame failed with status ', 'three scans pass the pre-check' );

  rLimits := Limits;
  rLimits.MaxPixels := 16 * 16;
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 17, 16, 1, 1 ), 7, rLimits ); end, TRANSCODE, True,
    'the JPEG is 17 x 16 pixels, more than TJxlLimits.MaxPixels (256)', 'one column over' );
  AssertJxlError( procedure begin JxlTranscodeJpegToJxl( BuildJpeg( 16, 16, 1, 1 ), 7, rLimits ); end, 'JxlEncoderAddJPEGFrame',
    False, 'JxlEncoderAddJPEGFrame failed with status ', 'exactly MaxPixels passes the pre-check' );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlLimits );

end.
