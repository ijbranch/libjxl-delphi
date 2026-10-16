(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of the high-level VCL unit <c>Jxl.Graphic</c>: decoding against reference PNGs, lossless and lossy encoding,
///   lossless JPEG recompression and reconstruction, <c>TPicture</c> integration and error reporting.
/// </summary>
unit TestJxl.Graphic;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of <c>Jxl.Graphic</c> against libjxl's own test images.</summary>
  [ TestFixture ]
  TTestJxlGraphic = class
  public
    /// <summary>
    ///   Proves decoding <c>splines.jxl</c> yields its true size and pixels: every sample within 1 of the reference
    ///   <c>splines.png</c>, in RGB order (a swapped channel order or a wrong row stride would differ by far more).
    /// </summary>
    [ Test ]
    procedure Test_DecodePixels_Splines_MatchesReferencePng;
    /// <summary>
    ///   Proves lossless encoding is lossless through the binding: <c>flower.png</c> (RGB, 2268 x 1512) encoded with
    ///   <c>Lossless</c> decodes byte-identical, and the file starts with a JPEG XL signature.
    /// </summary>
    [ Test ]
    procedure Test_EncodePixels_LosslessRgb_RoundTripsByteIdentical;
    /// <summary>
    ///   Proves alpha survives a lossless round trip: <c>flower_alpha.png</c> (RGBA, straight alpha) decodes as four
    ///   channels, byte-identical.
    /// </summary>
    [ Test ]
    procedure Test_EncodePixels_LosslessRgba_RoundTripsByteIdentical;
    /// <summary>
    ///   Proves the lossy settings reach the encoder: at the same effort, distance 2.0 is smaller than lossless and
    ///   decodes to pixels that are close to, but not identical with, the source; and the distance itself is passed
    ///   on, because distance 0.5 gives a larger file with a smaller mean error than distance 4.0.
    /// </summary>
    [ Test ]
    procedure Test_EncodePixels_Lossy_SmallerThanLosslessAndClose;
    /// <summary>
    ///   Proves the encoder settings are checked: distance 0 and below encode losslessly (byte-identical), while a NaN
    ///   or infinite distance, one above 25, and an effort of 0 or 11 raise <c>EArgumentException</c> before libjxl is
    ///   called; with <c>Lossless</c> the distance is ignored.
    /// </summary>
    [ Test ]
    procedure Test_EncodeOptions_DistanceZeroLossless_InvalidRejected;
    /// <summary>
    ///   Proves a decode into a <c>nil</c> bitmap is refused with <c>EArgumentException</c> before any decoding or file
    ///   reading: invalid data and a missing file would otherwise raise <c>EJxlError</c> or a file error first.
    /// </summary>
    [ Test ]
    procedure Test_DecodeToBitmap_NilBitmap_RaisesBeforeDecoding;
    /// <summary>
    ///   Proves an ICC profile is stored when encoding: <c>flower.png</c> labelled Rec. 2020 and encoded losslessly
    ///   decodes in its own profile to the same samples with that profile, but to different samples in sRGB (a
    ///   colour conversion happened); labelled sRGB instead, as before the fix, it would decode unchanged.
    /// </summary>
    [ Test ]
    procedure Test_EncodePixels_IccProfile_RoundTripKeepsProfile;
    /// <summary>
    ///   Proves greyscale handling: an 8-bit grey PNG encoded losslessly decodes with <c>jcoImageProfile</c> as 1 channel
    ///   with a grey ICC profile, which encodes again with that profile and decodes identically; with <c>jcoSrgb</c> it is
    ///   3 channels with no profile attached (libjxl's is grey), and those pixels encode again too.
    /// </summary>
    [ Test ]
    procedure Test_GreyImage_ImageProfileStaysGreyAndReencodes;
    /// <summary>
    ///   Proves the rest of <c>TJxlImage</c>: <c>Assign</c> copies the encoder settings and limits, <c>SaveToFile</c> /
    ///   <c>LoadFromFile</c> round-trip, <c>LoadFromStream</c> reads from a non-zero position, an image with alpha loads as
    ///   <c>afDefined</c>, corrupt data raises <c>EJxlError</c>, and saving an empty image raises
    ///   <c>EArgumentException</c>.
    /// </summary>
    [ Test ]
    procedure Test_TJxlImage_AssignFilesStreamsAndErrors;
    /// <summary>
    ///   Proves lossless JPEG recompression end to end: four different JPEG flavours (4:2:0, 4:4:4, progressive,
    ///   greyscale) each recompress smaller and reconstruct byte-identical to the original file.
    /// </summary>
    [ Test ]
    procedure Test_TranscodeJpeg_Reconstruct_ByteIdentical;
    /// <summary>
    ///   Proves reconstruction refuses a JPEG XL file that was not made from a JPEG, with <c>EJxlError</c>, instead of
    ///   returning an empty or bogus JPEG.
    /// </summary>
    [ Test ]
    procedure Test_ReconstructJpeg_NotFromJpeg_RaisesEJxlError;
    /// <summary>
    ///   Proves <c>TJxlImage</c> is registered for <c>.jxl</c>: <c>TPicture.LoadFromFile</c> creates a
    ///   <c>TJxlImage</c> holding the decoded 2048 x 2048 image.
    /// </summary>
    [ Test ]
    procedure Test_PictureLoadFromFile_Jxl_CreatesTJxlImage;
    /// <summary>
    ///   Proves stream detection both ways: a JPEG XL stream loads as <c>TJxlImage</c>, and a BMP stream still loads
    ///   as a plain <c>TBitmap</c> (TJxlImage descends from TBitmap and must not claim BMP data).
    /// </summary>
    [ Test ]
    procedure Test_PictureLoadFromStream_DetectsJxlAndLeavesBmp;
    /// <summary>
    ///   Proves <c>TJxlImage</c> saves and loads through streams losslessly: an opaque bitmap round-trips with
    ///   identical pixels and stays <c>afIgnored</c>.
    /// </summary>
    [ Test ]
    procedure Test_TJxlImage_SaveLoadLossless_PixelsIdentical;
    /// <summary>
    ///   Proves bitmap alpha handling: a VCL bitmap with alpha (premultiplied in memory) round-trips through JPEG XL
    ///   with <c>AlphaFormat = afDefined</c> and every sample within 1 (premultiply rounding).
    /// </summary>
    [ Test ]
    procedure Test_BitmapWithAlpha_RoundTrip_KeepsAlpha;
    /// <summary>
    ///   Proves corrupt input is reported as <c>EJxlError</c>: random bytes after a valid signature, a truncated file
    ///   and empty input all raise it, rather than crashing or returning an image.
    /// </summary>
    [ Test ]
    procedure Test_DecodePixels_CorruptInput_RaisesEJxlError;
    /// <summary>Proves an inconsistent pixel record is rejected before libjxl sees it.</summary>
    [ Test ]
    procedure Test_EncodePixels_InconsistentRecord_RaisesEArgumentException;
    /// <summary>Proves the DLL-free signature test agrees with the codestream and container signatures.</summary>
    [ Test ]
    procedure Test_HasSignature_RecognisesJxlOnly;
    /// <summary>
    ///   Proves the bitmap a <c>.jxl</c> decodes into holds the right colours in VCL's BGRA order: every sample of
    ///   <c>splines.jxl</c> decoded to a bitmap is within 1 of <c>splines.png</c>, and alpha is opaque. Round-trip
    ///   tests cannot see a channel swap, which cancels out on the way back.
    /// </summary>
    [ Test ]
    procedure Test_DecodeToBitmap_Splines_MatchesReferencePngInBgra;
    /// <summary>
    ///   Proves <c>JxlBitmapToPixels</c> reads VCL's BGRA back into RGB: pixels written to a bitmap and read back are
    ///   byte-identical to the reference PNG's.
    /// </summary>
    [ Test ]
    procedure Test_BitmapToPixels_Opaque_ReturnsRgbOfReference;
    /// <summary>
    ///   Proves the exact path: <c>flower_alpha.png</c> copied with <c>JxlTryPngToPixels</c> gives the PNG's own
    ///   straight RGBA samples (checked against an independent PNG reader), and a lossless encode of them through
    ///   <c>JxlEncodePixelsToFile</c> decodes back to exactly those samples.
    /// </summary>
    [ Test ]
    procedure Test_TryPngToPixels_FlowerAlpha_LosslessRoundTripIsSampleExact;
    /// <summary>
    ///   Proves why the exact path exists: the same <c>flower_alpha.png</c> samples saved losslessly through a VCL
    ///   bitmap (which premultiplies alpha) do NOT decode back to the original samples, and every difference lies in a
    ///   partly or fully transparent pixel's colour.
    /// </summary>
    [ Test ]
    procedure Test_BitmapPath_FlowerAlpha_LosslessIsNotSampleExact;
    /// <summary>
    ///   Proves which PNG layouts the exact path accepts: 8-bit grey (1 channel) and grey + alpha (2 channels) copy
    ///   sample for sample, while a palette PNG and a 16-bit PNG are refused with <c>False</c> so the caller falls back.
    /// </summary>
    [ Test ]
    procedure Test_TryPngToPixels_Layouts_GreyCopiedPaletteAnd16BitRefused;
  end;

implementation

uses
  System.Math, System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Graphics, Vcl.Imaging.pngimage,
  Jxl.Graphic,
  TestJxl.Common;

const
  /// <summary>Effort used by the encoding tests: fast enough for a 3.4 megapixel image, still a real encode.</summary>
  TEST_EFFORT = 3;

/// <summary>Returns lossless options at the test effort.</summary>
/// <returns>The options.</returns>
function LosslessOptions: TJxlEncodeOptions;
begin

  Result          := TJxlEncodeOptions.Default;
  Result.Lossless := True;
  Result.Effort   := TEST_EFFORT;

end;

/// <summary>Returns the RGBA bytes of a 32-bit bitmap exactly as held in memory (BGRA rows, top to bottom).</summary>
/// <param name="ABitmap">A 32-bit bitmap.</param>
/// <returns>Width * Height * 4 bytes.</returns>
function BitmapBytes( ABitmap: TBitmap ): TBytes;
begin

  SetLength( Result, ABitmap.Width * ABitmap.Height * 4 );

  for var iY := 0 to ABitmap.Height - 1 do
    Move( ABitmap.ScanLine[ iY ]^, Result[ iY * ABitmap.Width * 4 ], ABitmap.Width * 4 );

end;

{ TTestJxlGraphic }

procedure TTestJxlGraphic.Test_DecodePixels_Splines_MatchesReferencePng;
begin

  var rDecoded   := JxlDecodePixels( TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) ) );
  var rReference := LoadPngPixels( TestDataFile( 'splines.png' ) );

  Assert.AreEqual( 2048, Integer( rDecoded.Width ), 'Width' );
  Assert.AreEqual( 2048, Integer( rDecoded.Height ), 'Height' );
  Assert.AreEqual( 3, Integer( rDecoded.NumChannels ), 'NumChannels' );

  var iDifference := MaxSampleDifference( rDecoded.Data, rReference.Data );

  Assert.IsTrue( iDifference <= 1, Format( 'largest sample difference from splines.png is %d', [ iDifference ] ) );

end;

procedure TTestJxlGraphic.Test_EncodePixels_LosslessRgb_RoundTripsByteIdentical;
begin

  var rSource  := LoadPngPixels( TestDataFile( 'flower\flower.png' ) );
  var naJxl    := JxlEncodePixels( rSource, LosslessOptions );

  Assert.IsTrue( JxlHasSignature( naJxl ), 'the output is JPEG XL' );

  var rDecoded := JxlDecodePixels( naJxl );

  Assert.AreEqual( Integer( rSource.Width ), Integer( rDecoded.Width ), 'Width' );
  Assert.AreEqual( Integer( rSource.Height ), Integer( rDecoded.Height ), 'Height' );
  Assert.AreEqual( 3, Integer( rDecoded.NumChannels ), 'NumChannels' );
  Assert.AreEqual( -1, FirstDifference( rSource.Data, rDecoded.Data ), 'first differing byte' );

end;

procedure TTestJxlGraphic.Test_EncodePixels_LosslessRgba_RoundTripsByteIdentical;
begin

  var rSource := LoadPngPixels( TestDataFile( 'flower\flower_alpha.png' ) );

  Assert.AreEqual( 4, Integer( rSource.NumChannels ), 'the reference PNG has alpha' );

  var rDecoded := JxlDecodePixels( JxlEncodePixels( rSource, LosslessOptions ) );

  Assert.AreEqual( 4, Integer( rDecoded.NumChannels ), 'NumChannels' );
  Assert.AreEqual( -1, FirstDifference( rSource.Data, rDecoded.Data ), 'first differing byte' );

end;

procedure TTestJxlGraphic.Test_EncodePixels_Lossy_SmallerThanLosslessAndClose;
begin

  var rSource    := LoadPngPixels( TestDataFile( 'flower\flower.png' ) );
  var naLossless := JxlEncodePixels( rSource, LosslessOptions );
  var rLossy     := LosslessOptions;

  rLossy.Lossless := False;
  rLossy.Distance := 2.0;

  var naLossy := JxlEncodePixels( rSource, rLossy );

  Assert.IsTrue( Length( naLossy ) < Length( naLossless ) div 2,
    Format( 'lossy %d bytes is not under half of lossless %d bytes', [ Length( naLossy ), Length( naLossless ) ] ) );

  var rDecoded := JxlDecodePixels( naLossy );

  Assert.AreNotEqual( -1, FirstDifference( rSource.Data, rDecoded.Data ), 'lossy output must not be pixel-identical' );

  var iDifference := MaxSampleDifference( rSource.Data, rDecoded.Data );

  Assert.IsTrue( iDifference < 128, Format( 'largest sample difference %d is not a plausible lossy result', [ iDifference ] ) );

  rLossy.Distance := 0.5;

  var naFine := JxlEncodePixels( rSource, rLossy );

  rLossy.Distance := 4.0;

  var naCoarse := JxlEncodePixels( rSource, rLossy );

  Assert.IsTrue( Length( naFine ) > Length( naCoarse ), Format( 'distance 0.5 gave %d bytes, distance 4.0 %d',
    [ Length( naFine ), Length( naCoarse ) ] ) );

  var fFineError   := MeanSampleDifference( rSource.Data, JxlDecodePixels( naFine ).Data );
  var fCoarseError := MeanSampleDifference( rSource.Data, JxlDecodePixels( naCoarse ).Data );

  Assert.IsTrue( fFineError < fCoarseError, Format( 'distance 0.5 mean error %.3f is not below distance 4.0''s %.3f',
    [ fFineError, fCoarseError ] ) );

end;

procedure TTestJxlGraphic.Test_EncodeOptions_DistanceZeroLossless_InvalidRejected;
begin

  var rSource  := LoadPngPixels( TestDataFile( 'splines.png' ) );
  var rOptions := TJxlEncodeOptions.Default;

  rOptions.Effort := 1;

  for var fDistance in TArray<Single>.Create( 0.0, -1.0 ) do
  begin
    var naEncoded: TBytes := nil;

    rOptions.Distance := fDistance;
    Assert.WillNotRaiseAny( procedure begin naEncoded := JxlEncodePixels( rSource, rOptions ); end,
      Format( 'distance %g is accepted', [ fDistance ] ) );
    Assert.AreEqual( -1, FirstDifference( rSource.Data, JxlDecodePixels( naEncoded ).Data ),
      Format( 'distance %g encodes losslessly', [ fDistance ] ) );
  end;

  for var fDistance in TArray<Single>.Create( NaN, Infinity, 25.01 ) do
  begin
    rOptions.Distance := fDistance;
    Assert.WillRaise( procedure begin JxlEncodePixels( rSource, rOptions ); end, EArgumentException,
      Format( 'distance %g', [ fDistance ] ) );
  end;

  rOptions.Distance := 25.0;
  Assert.WillNotRaiseAny( procedure begin JxlEncodePixels( rSource, rOptions ); end, 'distance 25 is the largest allowed' );

  rOptions.Distance := 1.0;

  for var iEffort in [ 0, 11 ] do
  begin
    rOptions.Effort := iEffort;
    Assert.WillRaise( procedure begin JxlEncodePixels( rSource, rOptions ); end, EArgumentException, Format( 'effort %d', [ iEffort ] ) );
  end;

  var naJpeg := TFile.ReadAllBytes( TestDataFile( 'flower\flower.png.im_q85_420.jpg' ) );

  Assert.WillRaise( procedure begin JxlTranscodeJpegToJxl( naJpeg, 0 ); end, EArgumentException, 'transcode effort 0' );

  rOptions          := LosslessOptions;
  rOptions.Distance := NaN;
  Assert.WillNotRaiseAny( procedure begin JxlEncodePixels( rSource, rOptions ); end, 'Lossless ignores the distance' );

end;

procedure TTestJxlGraphic.Test_DecodeToBitmap_NilBitmap_RaisesBeforeDecoding;
begin

  var naGarbage: TBytes := [ $FF, $0A, 1, 2, 3, 4, 5, 6 ];
  var sMissing := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-missing-' + TGUID.NewGuid.ToString + '.jxl' );

  Assert.WillRaise( procedure begin JxlDecodeToBitmap( naGarbage, nil ); end, EArgumentException, 'invalid data, nil bitmap' );
  Assert.WillRaise( procedure begin JxlDecodeToBitmap( nil, nil ); end, EArgumentException, 'empty data, nil bitmap' );
  Assert.WillRaise( procedure begin JxlDecodeFileToBitmap( sMissing, nil ); end, EArgumentException, 'missing file, nil bitmap' );

end;

procedure TTestJxlGraphic.Test_EncodePixels_IccProfile_RoundTripKeepsProfile;
begin

  var rSource := LoadPngPixels( TestDataFile( 'flower\flower.png' ) );

  rSource.IccProfile := TFile.ReadAllBytes( TPath.Combine( ExtractFileDir( ExtractFileDir( TestDataFile( 'splines.jxl' ) ) ),
    'external\Compact-ICC-Profiles\profiles\Rec2020-v4.icc' ) );

  var naJxl := JxlEncodePixels( rSource, LosslessOptions );
  var rOwn  := JxlDecodePixels( naJxl, jcoImageProfile );

  Assert.AreEqual( -1, FirstDifference( rSource.Data, rOwn.Data ), 'decoded in its own profile the samples are unchanged' );
  Assert.AreEqual( -1, FirstDifference( rSource.IccProfile, rOwn.IccProfile ), 'the decoded profile is the one encoded' );

  var rSrgb := JxlDecodePixels( naJxl, jcoSrgb );
  var iDifference := MaxSampleDifference( rSource.Data, rSrgb.Data );

  Assert.IsTrue( iDifference > 8, Format( 'converted to sRGB the samples moved by at most %d: the profile was not stored',
    [ iDifference ] ) );

end;

procedure TTestJxlGraphic.Test_GreyImage_ImageProfileStaysGreyAndReencodes;
var
  oPng: TPngImage;
  rGrey: TJxlPixels;
begin

  oPng := TPngImage.CreateBlank( COLOR_GRAYSCALE, 8, 16, 8 );

  try
    for var iY := 0 to 7 do
      for var iX := 0 to 15 do PByte( oPng.Scanline[ iY ] )[ iX ] := Byte( iY * 30 + iX * 2 );

    Assert.IsTrue( JxlTryPngToPixels( oPng, rGrey ), 'grey PNG' );
  finally
    oPng.Free;
  end;

  var naJxl := JxlEncodePixels( rGrey, LosslessOptions );
  var rOwn  := JxlDecodePixels( naJxl, jcoImageProfile );

  Assert.AreEqual( 1, Integer( rOwn.NumChannels ), 'jcoImageProfile keeps grey as 1 channel' );
  Assert.AreEqual( -1, FirstDifference( rGrey.Data, rOwn.Data ), 'grey samples' );
  Assert.IsTrue( Length( rOwn.IccProfile ) > 20, 'a profile was returned' );
  Assert.AreEqual( 'GRAY', TEncoding.ANSI.GetString( rOwn.IccProfile, 16, 4 ), False, 'the ICC colour space is grey' );

  var rAgain := JxlDecodePixels( JxlEncodePixels( rOwn, LosslessOptions ), jcoImageProfile );

  Assert.AreEqual( -1, FirstDifference( rGrey.Data, rAgain.Data ), 'grey pixels re-encoded with their grey profile' );

  // With jcoSrgb the grey samples become 3-channel sRGB; libjxl's profile is grey, so none is returned, and the
  // pixels encode again (as sRGB) and decode to the same grey values.
  var rSrgb := JxlDecodePixels( naJxl, jcoSrgb );

  Assert.AreEqual( 3, Integer( rSrgb.NumChannels ), 'jcoSrgb expands grey to RGB' );
  Assert.AreEqual( 0, Length( rSrgb.IccProfile ), 'no grey profile is attached to RGB samples' );
  Assert.AreEqual( -1, FirstDifference( rSrgb.Data, JxlDecodePixels( JxlEncodePixels( rSrgb, LosslessOptions ) ).Data ),
    'the expanded pixels re-encode' );

end;

procedure TTestJxlGraphic.Test_TJxlImage_AssignFilesStreamsAndErrors;
var
  oSource: TJxlImage;
  oCopy: TJxlImage;
  oStream: TMemoryStream;
begin

  oSource := TJxlImage.Create;
  oCopy   := TJxlImage.Create;
  oStream := TMemoryStream.Create;

  try
    JxlDecodeFileToBitmap( TestDataFile( 'splines.jxl' ), oSource );
    oSource.Lossless := True;
    oSource.Distance := 2.5;
    oSource.Effort   := 2;

    var rLimits := oSource.Limits;

    rLimits.MaxJpegScans := 9;
    oSource.Limits       := rLimits;
    oCopy.Assign( oSource );
    Assert.IsTrue( oCopy.Lossless, 'Assign copies Lossless' );
    Assert.AreEqual( 2.5, Double( oCopy.Distance ), 0.0, 'Assign copies Distance' );
    Assert.AreEqual( 2, oCopy.Effort, 'Assign copies Effort' );
    Assert.AreEqual( Cardinal( 9 ), oCopy.Limits.MaxJpegScans, 'Assign copies Limits' );
    Assert.AreEqual( -1, FirstDifference( BitmapBytes( oSource ), BitmapBytes( oCopy ) ), 'Assign copies the pixels' );

    var sFileName := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-' + TGUID.NewGuid.ToString + '.jxl' );

    try
      oSource.SaveToFile( sFileName );
      Assert.IsTrue( JxlHasSignature( TFile.ReadAllBytes( sFileName ) ), 'SaveToFile writes JPEG XL' );
      oCopy.LoadFromFile( sFileName );
      Assert.AreEqual( -1, FirstDifference( BitmapBytes( oSource ), BitmapBytes( oCopy ) ), 'LoadFromFile after SaveToFile' );

      // LoadFromStream reads from the current position.
      var naJunk: TBytes := [ 1, 2, 3, 4, 5 ];

      oStream.WriteBuffer( naJunk, Length( naJunk ) );

      var naFile := TFile.ReadAllBytes( sFileName );

      oStream.WriteBuffer( naFile, Length( naFile ) );
      oStream.Position := Length( naJunk );
      oCopy.LoadFromStream( oStream );
      Assert.AreEqual( 2048, oCopy.Width, 'LoadFromStream at position 5' );
    finally
      TFile.Delete( sFileName );
    end;

    // An image with alpha.
    JxlPixelsToBitmap( LoadPngPixels( TestDataFile( 'flower\flower_alpha.png' ) ), oSource );
    oStream.Clear;
    oSource.SaveToStream( oStream );
    oStream.Position := 0;
    oCopy.LoadFromStream( oStream );
    Assert.IsTrue( oCopy.AlphaFormat = afDefined, 'an image with alpha loads as afDefined' );

    // Corrupt data.
    var naCorrupt: TBytes := [ $FF, $0A, $FA, $11, $22, $33, $44, $55, $66, $77 ];

    oStream.Clear;
    oStream.WriteBuffer( naCorrupt, Length( naCorrupt ) );
    oStream.Position := 0;
    Assert.WillRaise( procedure begin oCopy.LoadFromStream( oStream ); end, EJxlError, 'corrupt data' );

    // An empty image cannot be saved.
    var oEmpty := TJxlImage.Create;

    try
      oStream.Clear;
      Assert.WillRaise( procedure begin oEmpty.SaveToStream( oStream ); end, EArgumentException, 'an empty image' );
    finally
      oEmpty.Free;
    end;

  finally
    oStream.Free;
    oCopy.Free;
    oSource.Free;
  end;

end;

procedure TTestJxlGraphic.Test_TranscodeJpeg_Reconstruct_ByteIdentical;
begin

  for var sName in [ 'flower\flower.png.im_q85_420.jpg', 'flower\flower.png.im_q85_444.jpg', 'flower\flower.png.im_q85_420_progr.jpg',
    'flower\flower.png.im_q85_gray.jpg' ] do
  begin
    var naJpeg := TFile.ReadAllBytes( TestDataFile( sName ) );
    var naJxl  := JxlTranscodeJpegToJxl( naJpeg, TEST_EFFORT );

    Assert.IsTrue( JxlHasSignature( naJxl ), sName + ': the output is JPEG XL' );
    Assert.IsTrue( Length( naJxl ) < Length( naJpeg ), Format( '%s: %d bytes recompressed to %d', [ sName, Length( naJpeg ),
      Length( naJxl ) ] ) );

    var naRebuilt := JxlReconstructJpeg( naJxl );

    Assert.AreEqual( Length( naJpeg ), Length( naRebuilt ), sName + ': reconstructed length' );
    Assert.AreEqual( -1, FirstDifference( naJpeg, naRebuilt ), sName + ': first differing byte' );
  end;

end;

procedure TTestJxlGraphic.Test_ReconstructJpeg_NotFromJpeg_RaisesEJxlError;
begin

  var naJxl := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );

  Assert.WillRaise( procedure begin JxlReconstructJpeg( naJxl ); end, EJxlError );

end;

procedure TTestJxlGraphic.Test_PictureLoadFromFile_Jxl_CreatesTJxlImage;
begin

  var oPicture := TPicture.Create;

  try
    oPicture.LoadFromFile( TestDataFile( 'splines.jxl' ) );
    Assert.IsTrue( oPicture.Graphic is TJxlImage, 'Graphic is ' + oPicture.Graphic.ClassName );
    Assert.AreEqual( 2048, oPicture.Width, 'Width' );
    Assert.AreEqual( 2048, oPicture.Height, 'Height' );
  finally
    oPicture.Free;
  end;

end;

procedure TTestJxlGraphic.Test_PictureLoadFromStream_DetectsJxlAndLeavesBmp;
var
  oPicture: TPicture;
  oStream: TMemoryStream;
  oBitmap: TBitmap;
begin

  oPicture := TPicture.Create;
  oStream  := TMemoryStream.Create;
  oBitmap  := TBitmap.Create;

  try
    oStream.LoadFromFile( TestDataFile( 'splines.jxl' ) );
    oPicture.LoadFromStream( oStream );
    Assert.IsTrue( oPicture.Graphic is TJxlImage, 'JPEG XL stream gave ' + oPicture.Graphic.ClassName );
    Assert.AreEqual( 2048, oPicture.Width, 'Width' );

    oBitmap.PixelFormat := pf24bit;
    oBitmap.SetSize( 4, 3 );
    oStream.Clear;
    oBitmap.SaveToStream( oStream );
    oStream.Position := 0;
    oPicture.LoadFromStream( oStream );
    Assert.IsTrue( oPicture.Graphic.ClassType = TBitmap, 'BMP stream gave ' + oPicture.Graphic.ClassName );
    Assert.AreEqual( 4, oPicture.Width, 'BMP width' );
  finally
    oBitmap.Free;
    oStream.Free;
    oPicture.Free;
  end;

end;

procedure TTestJxlGraphic.Test_TJxlImage_SaveLoadLossless_PixelsIdentical;
var
  oSource: TJxlImage;
  oLoaded: TJxlImage;
  oStream: TMemoryStream;
begin

  oSource := TJxlImage.Create;
  oLoaded := TJxlImage.Create;
  oStream := TMemoryStream.Create;

  try
    JxlDecodeFileToBitmap( TestDataFile( 'splines.jxl' ), oSource );
    Assert.IsTrue( oSource.AlphaFormat = afIgnored, 'an opaque image decodes as afIgnored' );
    oSource.Lossless := True;
    oSource.Effort   := TEST_EFFORT;
    oSource.SaveToStream( oStream );
    oStream.Position := 0;
    oLoaded.LoadFromStream( oStream );
    Assert.AreEqual( oSource.Width, oLoaded.Width, 'Width' );
    Assert.AreEqual( oSource.Height, oLoaded.Height, 'Height' );
    Assert.IsTrue( oLoaded.AlphaFormat = afIgnored, 'AlphaFormat' );
    Assert.AreEqual( -1, FirstDifference( BitmapBytes( oSource ), BitmapBytes( oLoaded ) ), 'first differing byte' );
  finally
    oStream.Free;
    oLoaded.Free;
    oSource.Free;
  end;

end;

procedure TTestJxlGraphic.Test_BitmapWithAlpha_RoundTrip_KeepsAlpha;
var
  oSource: TBitmap;
  oLoaded: TBitmap;
begin

  oSource := TBitmap.Create;
  oLoaded := TBitmap.Create;

  try
    JxlPixelsToBitmap( LoadPngPixels( TestDataFile( 'flower\flower_alpha.png' ) ), oSource );
    Assert.IsTrue( oSource.AlphaFormat = afDefined, 'source AlphaFormat' );
    JxlDecodeToBitmap( JxlEncodeBitmap( oSource, LosslessOptions ), oLoaded );
    Assert.IsTrue( oLoaded.AlphaFormat = afDefined, 'loaded AlphaFormat' );
    Assert.AreEqual( oSource.Width, oLoaded.Width, 'Width' );

    var iDifference := MaxSampleDifference( BitmapBytes( oSource ), BitmapBytes( oLoaded ) );

    Assert.IsTrue( iDifference <= 1, Format( 'largest sample difference is %d', [ iDifference ] ) );

    // Independent oracle: the PNG reader's straight samples, premultiplied here and laid out as BGRA.
    var rReference := LoadPngPixels( TestDataFile( 'flower\flower_alpha.png' ) );
    var naExpected: TBytes;

    SetLength( naExpected, Length( rReference.Data ) );

    for var iI := 0 to Length( rReference.Data ) div 4 - 1 do
    begin
      var iAlpha := Integer( rReference.Data[ iI * 4 + 3 ] );

      naExpected[ iI * 4 ]     := Byte( ( rReference.Data[ iI * 4 + 2 ] * iAlpha + 127 ) div 255 );
      naExpected[ iI * 4 + 1 ] := Byte( ( rReference.Data[ iI * 4 + 1 ] * iAlpha + 127 ) div 255 );
      naExpected[ iI * 4 + 2 ] := Byte( ( rReference.Data[ iI * 4 ] * iAlpha + 127 ) div 255 );
      naExpected[ iI * 4 + 3 ] := Byte( iAlpha );
    end;

    iDifference := MaxSampleDifference( naExpected, BitmapBytes( oLoaded ) );
    Assert.IsTrue( iDifference <= 2, Format( 'largest difference from the premultiplied PNG samples is %d', [ iDifference ] ) );
  finally
    oLoaded.Free;
    oSource.Free;
  end;

end;

procedure TTestJxlGraphic.Test_DecodePixels_CorruptInput_RaisesEJxlError;
begin

  var naValid := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var naGarbage: TBytes;

  SetLength( naGarbage, 4096 );
  RandSeed := 20261016;

  for var iI := 0 to High( naGarbage ) do naGarbage[ iI ] := Random( 256 );

  naGarbage[ 0 ] := $FF;
  naGarbage[ 1 ] := $0A;

  var naTruncated := Copy( naValid, 0, Length( naValid ) div 2 );

  Assert.WillRaise( procedure begin JxlDecodePixels( naGarbage ); end, EJxlError, 'random bytes after a signature' );
  Assert.WillRaise( procedure begin JxlDecodePixels( naTruncated ); end, EJxlError, 'truncated file' );
  Assert.WillRaise( procedure begin JxlDecodePixels( nil ); end, EJxlError, 'empty input' );

end;

procedure TTestJxlGraphic.Test_EncodePixels_InconsistentRecord_RaisesEArgumentException;
begin

  var rPixels := Default( TJxlPixels );

  rPixels.Width       := 4;
  rPixels.Height      := 4;
  rPixels.NumChannels := 3;
  SetLength( rPixels.Data, 4 * 4 * 3 - 1 );
  Assert.WillRaise( procedure begin JxlEncodePixels( rPixels, TJxlEncodeOptions.Default ); end, EArgumentException,
    'one byte short' );

  rPixels.NumChannels := 5;
  SetLength( rPixels.Data, 4 * 4 * 5 );
  Assert.WillRaise( procedure begin JxlEncodePixels( rPixels, TJxlEncodeOptions.Default ); end, EArgumentException,
    'five channels' );

  rPixels.NumChannels := 0;
  SetLength( rPixels.Data, 0 );
  Assert.WillRaise( procedure begin JxlEncodePixels( rPixels, TJxlEncodeOptions.Default ); end, EArgumentException,
    'zero channels' );

  rPixels.NumChannels := 3;
  rPixels.Width       := 0;
  Assert.WillRaise( procedure begin JxlEncodePixels( rPixels, TJxlEncodeOptions.Default ); end, EArgumentException, 'zero width' );

  rPixels.Width  := 4;
  rPixels.Height := 0;
  Assert.WillRaise( procedure begin JxlEncodePixels( rPixels, TJxlEncodeOptions.Default ); end, EArgumentException, 'zero height' );

end;

procedure TTestJxlGraphic.Test_HasSignature_RecognisesJxlOnly;
begin

  Assert.IsTrue( JxlHasSignature( TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) ) ), 'codestream' );
  Assert.IsTrue( JxlHasSignature( TFile.ReadAllBytes( TestDataFile( 'jpeg_reconstruction\1x1_exif_xmp.jxl' ) ) ), 'container' );
  Assert.IsFalse( JxlHasSignature( TFile.ReadAllBytes( TestDataFile( 'splines.png' ) ) ), 'PNG' );
  Assert.IsFalse( JxlHasSignature( [ $FF ] ), 'one byte' );

end;

procedure TTestJxlGraphic.Test_DecodeToBitmap_Splines_MatchesReferencePngInBgra;
var
  oBitmap: TBitmap;
begin

  oBitmap := TBitmap.Create;

  try
    JxlDecodeFileToBitmap( TestDataFile( 'splines.jxl' ), oBitmap );
    Assert.IsTrue( oBitmap.PixelFormat = pf32bit, 'PixelFormat' );

    var rReference := LoadPngPixels( TestDataFile( 'splines.png' ) );
    var naExpected: TBytes;

    SetLength( naExpected, Length( rReference.Data ) div 3 * 4 );

    for var iI := 0 to Length( rReference.Data ) div 3 - 1 do
    begin
      naExpected[ iI * 4 ]     := rReference.Data[ iI * 3 + 2 ];
      naExpected[ iI * 4 + 1 ] := rReference.Data[ iI * 3 + 1 ];
      naExpected[ iI * 4 + 2 ] := rReference.Data[ iI * 3 ];
      naExpected[ iI * 4 + 3 ] := 255;
    end;

    var iDifference := MaxSampleDifference( naExpected, BitmapBytes( oBitmap ) );

    Assert.IsTrue( iDifference <= 1, Format( 'largest sample difference from splines.png is %d', [ iDifference ] ) );
  finally
    oBitmap.Free;
  end;

end;

procedure TTestJxlGraphic.Test_BitmapToPixels_Opaque_ReturnsRgbOfReference;
var
  oBitmap: TBitmap;
begin

  oBitmap := TBitmap.Create;

  try
    var rReference := LoadPngPixels( TestDataFile( 'splines.png' ) );

    JxlPixelsToBitmap( rReference, oBitmap );

    var rPixels := JxlBitmapToPixels( oBitmap );

    Assert.AreEqual( 3, Integer( rPixels.NumChannels ), 'NumChannels' );
    Assert.IsFalse( rPixels.AlphaPremultiplied, 'AlphaPremultiplied' );
    Assert.AreEqual( -1, FirstDifference( rReference.Data, rPixels.Data ), 'first differing byte' );
  finally
    oBitmap.Free;
  end;

end;

procedure TTestJxlGraphic.Test_TryPngToPixels_FlowerAlpha_LosslessRoundTripIsSampleExact;
var
  oPng: TPngImage;
begin

  var sPngName   := TestDataFile( 'flower\flower_alpha.png' );
  var rReference := LoadPngPixels( sPngName );
  var rPixels    := Default( TJxlPixels );

  oPng := TPngImage.Create;

  try
    oPng.LoadFromFile( sPngName );
    Assert.IsTrue( JxlTryPngToPixels( oPng, rPixels ), 'an 8-bit RGBA PNG is copied exactly' );
  finally
    oPng.Free;
  end;

  Assert.AreEqual( 4, Integer( rPixels.NumChannels ), 'NumChannels' );
  Assert.IsFalse( rPixels.AlphaPremultiplied, 'AlphaPremultiplied' );
  Assert.AreEqual( -1, FirstDifference( rReference.Data, rPixels.Data ), 'first byte differing from the PNG reader' );

  var sFileName := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-' + TGUID.NewGuid.ToString + '.jxl' );

  JxlEncodePixelsToFile( rPixels, sFileName, LosslessOptions );

  try
    var rDecoded := JxlDecodePixels( TFile.ReadAllBytes( sFileName ) );

    Assert.AreEqual( 4, Integer( rDecoded.NumChannels ), 'decoded NumChannels' );
    Assert.AreEqual( -1, FirstDifference( rReference.Data, rDecoded.Data ), 'first byte differing after the round trip' );
  finally
    TFile.Delete( sFileName );
  end;

end;

procedure TTestJxlGraphic.Test_BitmapPath_FlowerAlpha_LosslessIsNotSampleExact;
var
  oBitmap: TBitmap;
begin

  var rReference := LoadPngPixels( TestDataFile( 'flower\flower_alpha.png' ) );
  var naJxl: TBytes;

  oBitmap := TBitmap.Create;

  try
    JxlPixelsToBitmap( rReference, oBitmap );
    naJxl := JxlEncodeBitmap( oBitmap, LosslessOptions );
  finally
    oBitmap.Free;
  end;

  var rDecoded := JxlDecodePixels( naJxl );

  Assert.AreEqual( Length( rReference.Data ), Length( rDecoded.Data ), 'data length' );

  var iDiffering := 0;

  for var iI := 0 to Length( rReference.Data ) div 4 - 1 do
    if ( not CompareMem( @rReference.Data[ iI * 4 ], @rDecoded.Data[ iI * 4 ], 4 ) ) then
    begin
      Inc( iDiffering );
      Assert.AreEqual( Integer( rReference.Data[ iI * 4 + 3 ] ), Integer( rDecoded.Data[ iI * 4 + 3 ] ), Format( 'alpha of pixel %d', [ iI ] ) );
      Assert.IsTrue( rReference.Data[ iI * 4 + 3 ] < 255, Format( 'pixel %d is opaque yet changed', [ iI ] ) );
    end;

  Assert.IsTrue( iDiffering > 0, 'the premultiplied bitmap path reproduced every sample, so it no longer needs the exact path' );

end;

procedure TTestJxlGraphic.Test_TryPngToPixels_Layouts_GreyCopiedPaletteAnd16BitRefused;
var
  oPng: TPngImage;
begin

  var rPixels := Default( TJxlPixels );

  oPng := TPngImage.CreateBlank( COLOR_GRAYSCALE, 8, 3, 2 );

  try
    for var iY := 0 to 1 do
      for var iX := 0 to 2 do PByte( oPng.Scanline[ iY ] )[ iX ] := Byte( 10 + iY * 3 + iX );

    Assert.IsTrue( JxlTryPngToPixels( oPng, rPixels ), 'grey' );
    Assert.AreEqual( 1, Integer( rPixels.NumChannels ), 'grey NumChannels' );
    Assert.AreEqual( -1, FirstDifference( TBytes.Create( 10, 11, 12, 13, 14, 15 ), rPixels.Data ), 'grey samples' );
  finally
    oPng.Free;
  end;

  oPng := TPngImage.CreateBlank( COLOR_GRAYSCALEALPHA, 8, 2, 1 );

  try
    PByte( oPng.Scanline[ 0 ] )[ 0 ]      := 20;
    PByte( oPng.Scanline[ 0 ] )[ 1 ]      := 30;
    PByte( oPng.AlphaScanline[ 0 ] )[ 0 ] := 40;
    PByte( oPng.AlphaScanline[ 0 ] )[ 1 ] := 50;
    Assert.IsTrue( JxlTryPngToPixels( oPng, rPixels ), 'grey + alpha' );
    Assert.AreEqual( 2, Integer( rPixels.NumChannels ), 'grey + alpha NumChannels' );
    Assert.AreEqual( -1, FirstDifference( TBytes.Create( 20, 40, 30, 50 ), rPixels.Data ), 'grey + alpha samples' );
  finally
    oPng.Free;
  end;

  oPng := TPngImage.CreateBlank( COLOR_PALETTE, 8, 2, 2 );

  try
    Assert.IsFalse( JxlTryPngToPixels( oPng, rPixels ), 'palette' );
  finally
    oPng.Free;
  end;

  oPng := TPngImage.CreateBlank( COLOR_RGBALPHA, 16, 2, 2 );

  try
    Assert.IsFalse( JxlTryPngToPixels( oPng, rPixels ), '16-bit RGBA' );
  finally
    oPng.Free;
  end;

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlGraphic );

end.
