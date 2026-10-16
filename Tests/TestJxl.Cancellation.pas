(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of cancellation: <c>TJxlCancellation</c> passed to the long routines of <c>Jxl.Graphic</c>, and
///   <c>JxlCancellableParallelRunner</c> driven through the C API.
/// </summary>
unit TestJxl.Cancellation;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of <c>TJxlCancellation</c>, <c>EJxlCancelled</c> and <c>JxlCancellableParallelRunner</c>.</summary>
  [ TestFixture ]
  TTestJxlCancellation = class
  public
    /// <summary>
    ///   Proves a token cancelled before the call stops every long routine with <c>EJxlCancelled</c> (a binding check
    ///   naming the routine), at once (a 16-megapixel encode raises within 20 ms, before libjxl copies the samples),
    ///   that the routines writing files leave no file and <c>TJxlImage.SaveToStream</c> writes nothing, and that after
    ///   <c>Reset</c> the same token lets the call run.
    /// </summary>
    [ Test ]
    procedure Test_CancelledBeforeStart_EveryRoutineRaisesAtOnce;
    /// <summary>
    ///   Proves a token that is never cancelled changes nothing: encoding (lossless and lossy), decoding, JPEG
    ///   recompression and reconstruction with it give output byte-identical to the calls without one.
    /// </summary>
    [ Test ]
    procedure Test_UncancelledToken_OutputIdenticalToNoToken;
    /// <summary>
    ///   Proves cancelling from another thread stops a long encode (lossy, effort 9, of a large noise image) with
    ///   <c>EJxlCancelled</c> in a fraction of the time the whole encode takes, and that the encode had really started.
    /// </summary>
    [ Test ]
    procedure Test_EncodeCancelledFromAnotherThread_StopsEarly;
    /// <summary>
    ///   Proves cancelling from another thread stops a long decode, and a long validation, with <c>EJxlCancelled</c> in
    ///   a fraction of the time the whole decode takes.
    /// </summary>
    [ Test ]
    procedure Test_DecodeCancelledFromAnotherThread_StopsEarly;
    /// <summary>
    ///   Proves the runner itself, through the C API: an encoder given <c>JxlCancellableParallelRunner</c> fails with
    ///   <c>JXL_ENC_ERROR</c> when its token is cancelled mid-way, after it had allocated through its memory budget,
    ///   and once destroyed has released every byte (the budget balances to 0). The same set-up without a cancel
    ///   encodes successfully.
    /// </summary>
    [ Test ]
    procedure Test_CancellableRunner_CancelledEncoderReleasesAllMemory;
    /// <summary>
    ///   Proves the runner's contract with libjxl directly, on a range of 100,000 tasks: without a token, and with one
    ///   never cancelled, it runs init once and every task once and succeeds; with a token cancelled before the call it
    ///   fails without calling init or any task; and when the token is cancelled by the first task to run, it skips the
    ///   remaining tasks and fails, so libjxl never takes an incomplete batch for a complete one.
    /// </summary>
    [ Test ]
    procedure Test_CancellableRunner_ContractWithLibjxl;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics,
  Vcl.Graphics,
  Jxl.Api.Types, Jxl.Api.Encode, Jxl.Api.Threads,
  Jxl.Graphic,
  TestJxl.Common;

/// <summary>Returns a square of pseudo-random RGB noise, the same every time; noise is slow to compress losslessly.</summary>
/// <param name="ASide">Width and height in pixels.</param>
/// <returns>The pixels.</returns>
function NoisePixels( ASide: Cardinal ): TJxlPixels;
begin

  Result             := Default( TJxlPixels );
  Result.Width       := ASide;
  Result.Height      := ASide;
  Result.NumChannels := 3;
  SetLength( Result.Data, Int64( ASide ) * ASide * 3 );

  var iState: Cardinal := 2463534242;

  for var iI := 0 to High( Result.Data ) do
  begin
    iState := iState xor ( iState shl 13 );
    iState := iState xor ( iState shr 17 );
    iState := iState xor ( iState shl 5 );
    Result.Data[ iI ] := Byte( iState );
  end;

end;

/// <summary>Returns lossless encoder settings at an effort.</summary>
/// <param name="AEffort">The effort.</param>
/// <returns>The settings.</returns>
function Lossless( AEffort: Integer ): TJxlEncodeOptions;
begin

  Result          := TJxlEncodeOptions.Default;
  Result.Lossless := True;
  Result.Effort   := AEffort;

end;

/// <summary>Starts a thread that cancels a token after a delay; the caller waits for it and frees it.</summary>
/// <param name="AToken">The token.</param>
/// <param name="ADelayMs">Milliseconds to wait before cancelling.</param>
/// <returns>The running thread.</returns>
function CancelAfter( AToken: TJxlCancellation; ADelayMs: Integer ): TThread;
begin

  Result := TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep( ADelayMs );
      AToken.Cancel;
    end );
  Result.FreeOnTerminate := False;
  Result.Start;

end;

/// <summary>
///   Runs work with a token that another thread cancels after a delay, and reports whether it ended in
///   <c>EJxlCancelled</c> and how long it took. Any other <c>EJxlError</c> fails the test.
/// </summary>
/// <param name="AWork">The work; it uses the token.</param>
/// <param name="AToken">The token, not yet cancelled.</param>
/// <param name="ADelayMs">Milliseconds before the cancel.</param>
/// <param name="AElapsedMs">Receives how long the work ran.</param>
/// <returns><c>True</c> when the work raised <c>EJxlCancelled</c>.</returns>
function RunCancelledAfter( const AWork: TProc; AToken: TJxlCancellation; ADelayMs: Integer; out AElapsedMs: Int64 ): Boolean;
var
  oThread: TThread;
begin

  Result  := False;
  oThread := CancelAfter( AToken, ADelayMs );

  try
    var rTimer := TStopwatch.StartNew;

    try
      AWork;
    except
      on EJxlCancelled do Result := True;
      on E: EJxlError do Assert.Fail( Format( '%s instead of EJxlCancelled: %s', [ E.ClassName, E.Message ] ) );
    end;

    AElapsedMs := rTimer.ElapsedMilliseconds;
  finally
    oThread.WaitFor;
    oThread.Free;
  end;

end;

/// <summary>
///   Asserts that a routine raises <c>EJxlCancelled</c>: a binding check naming the routine, saying it was cancelled.
///   Any other outcome fails the test.
/// </summary>
/// <param name="AProc">The routine.</param>
/// <param name="AApiName">Expected <c>ApiName</c>.</param>
/// <param name="AWhat">What is being checked, for the messages.</param>
procedure AssertCancelled( const AProc: TProc; const AApiName: string; const AWhat: string );
begin

  try
    AProc;
  except
    on E: EJxlCancelled do
    begin
      Assert.AreEqual( AApiName, E.ApiName, AWhat + ': ApiName' );
      Assert.IsTrue( E.IsBindingCheck, AWhat + ': IsBindingCheck' );
      Assert.IsTrue( Pos( 'the operation was cancelled', E.Message ) > 0, Format( '%s: message "%s"', [ AWhat, E.Message ] ) );
      Exit;
    end;
    on E: EJxlError do Assert.Fail( Format( '%s: %s instead of EJxlCancelled: %s', [ AWhat, E.ClassName, E.Message ] ) );
  end;

  Assert.Fail( AWhat + ': no EJxlCancelled was raised' );

end;

{ TTestJxlCancellation }

procedure TTestJxlCancellation.Test_CancelledBeforeStart_EveryRoutineRaisesAtOnce;
var
  oToken: TJxlCancellation;
  oBitmap: TBitmap;
  oImage: TJxlImage;
  oStream: TMemoryStream;
begin

  var rPixels := NoisePixels( 64 );
  var naJxl   := JxlEncodePixels( rPixels, Lossless( 1 ) );
  var sJpeg   := TestDataFile( 'flower\flower.png.im_q85_420.jpg' );
  var naJpeg  := TFile.ReadAllBytes( sJpeg );
  var naJbrd  := JxlTranscodeJpegToJxl( naJpeg, 1 );
  var sFolder := TPath.Combine( TPath.GetTempPath, 'LibJxlCancelTest' + IntToStr( TThread.CurrentThread.ThreadID ) );
  var sJxlIn  := TPath.Combine( sFolder, 'in.jxl' );
  var sOut    := TPath.Combine( sFolder, 'out.bin' );
  var rLimits := JxlGetDefaultLimits;

  TDirectory.CreateDirectory( sFolder );
  TFile.WriteAllBytes( sJxlIn, naJbrd );
  oToken  := TJxlCancellation.Create;
  oBitmap := TBitmap.Create;
  oImage  := TJxlImage.Create;
  oStream := TMemoryStream.Create;

  try
    oToken.Cancel;
    Assert.IsTrue( oToken.IsCancelled, 'IsCancelled after Cancel' );
    oBitmap.SetSize( 8, 8 );
    oImage.SetSize( 8, 8 );
    oImage.Cancellation := oToken;

    AssertCancelled( procedure begin JxlDecodePixels( naJxl, jcoSrgb, rLimits, oToken ); end, 'JxlDecodePixels', 'decode' );
    AssertCancelled( procedure begin JxlDecodeToBitmap( naJxl, oBitmap, rLimits, oToken ); end, 'JxlDecodeToBitmap', 'to bitmap' );
    AssertCancelled( procedure begin JxlDecodeFileToBitmap( sJxlIn, oBitmap, oToken ); end, 'JxlDecodeToBitmap', 'file to bitmap' );
    AssertCancelled( procedure begin JxlEncodePixels( rPixels, Lossless( 1 ), rLimits, oToken ); end, 'JxlEncodePixels', 'encode' );
    AssertCancelled( procedure begin JxlEncodeBitmap( oBitmap, Lossless( 1 ), oToken ); end, 'JxlEncodePixels', 'encode bitmap' );
    AssertCancelled( procedure begin JxlTranscodeJpegToJxl( naJpeg, 1, rLimits, oToken ); end, 'JxlTranscodeJpegToJxl', 'transcode' );
    AssertCancelled( procedure begin JxlReconstructJpeg( naJbrd, rLimits, oToken ); end, 'JxlReconstructJpeg', 'reconstruct' );
    AssertCancelled( procedure begin JxlValidate( naJbrd, rLimits, oToken ); end, 'JxlValidate', 'validate bytes' );
    AssertCancelled( procedure begin JxlValidate( sJxlIn, oToken ); end, 'JxlValidate', 'validate file' );
    AssertCancelled( procedure begin oImage.SaveToStream( oStream ); end, 'JxlEncodePixels', 'TJxlImage.SaveToStream' );
    Assert.AreEqual( Int64( 0 ), oStream.Size, 'a cancelled SaveToStream writes nothing' );

    oStream.Clear;
    oStream.WriteBuffer( naJxl, Length( naJxl ) );
    oStream.Position := 0;
    AssertCancelled( procedure begin JxlValidate( oStream, oToken ); end, 'JxlValidate', 'validate stream' );
    oStream.Position := 0;
    AssertCancelled( procedure begin oImage.LoadFromStream( oStream ); end, 'JxlDecodeToBitmap', 'TJxlImage.LoadFromStream' );

    // The routines that write files write nothing when cancelled.
    AssertCancelled( procedure begin JxlEncodePixelsToFile( rPixels, sOut, Lossless( 1 ), oToken ); end, 'JxlEncodePixels',
      'encode to file' );
    Assert.IsFalse( TFile.Exists( sOut ), 'JxlEncodePixelsToFile left a file' );
    AssertCancelled( procedure begin JxlEncodeBitmapToFile( oBitmap, sOut, Lossless( 1 ), oToken ); end, 'JxlEncodePixels',
      'bitmap to file' );
    Assert.IsFalse( TFile.Exists( sOut ), 'JxlEncodeBitmapToFile left a file' );
    AssertCancelled( procedure begin JxlTranscodeJpegFileToJxl( sJpeg, sOut, 1, oToken ); end, 'JxlTranscodeJpegToJxl',
      'transcode file' );
    Assert.IsFalse( TFile.Exists( sOut ), 'JxlTranscodeJpegFileToJxl left a file' );
    AssertCancelled( procedure begin JxlReconstructJpegFile( sJxlIn, sOut, oToken ); end, 'JxlReconstructJpeg', 'reconstruct file' );
    Assert.IsFalse( TFile.Exists( sOut ), 'JxlReconstructJpegFile left a file' );

    // At once means before libjxl is given anything: encoding 16 megapixels would first copy and convert 48 MB of samples.
    var rLarge := NoisePixels( 4096 );
    var rTimer := TStopwatch.StartNew;

    AssertCancelled( procedure begin JxlEncodePixels( rLarge, Lossless( 1 ), rLimits, oToken ); end, 'JxlEncodePixels',
      'encode 16 megapixels' );
    Assert.IsTrue( rTimer.ElapsedMilliseconds < 20, Format( 'a cancelled encode of 16 megapixels took %d ms to raise',
      [ rTimer.ElapsedMilliseconds ] ) );

    // Reset makes the token usable again.
    oToken.Reset;
    Assert.IsFalse( oToken.IsCancelled, 'IsCancelled after Reset' );
    Assert.AreEqual( -1, FirstDifference( rPixels.Data, JxlDecodePixels( naJxl, jcoSrgb, rLimits, oToken ).Data ),
      'after Reset the decode runs' );
  finally
    oStream.Free;
    oImage.Free;
    oBitmap.Free;
    oToken.Free;
    TDirectory.Delete( sFolder, True );
  end;

end;

procedure TTestJxlCancellation.Test_UncancelledToken_OutputIdenticalToNoToken;
var
  oToken: TJxlCancellation;
begin

  var rPixels := NoisePixels( 256 );
  var rLossy  := TJxlEncodeOptions.Default;
  var naJpeg  := TFile.ReadAllBytes( TestDataFile( 'flower\flower.png.im_q85_420.jpg' ) );
  var rLimits := JxlGetDefaultLimits;

  oToken := TJxlCancellation.Create;

  try
    var naLossless := JxlEncodePixels( rPixels, Lossless( 7 ), rLimits, oToken );

    Assert.AreEqual( -1, FirstDifference( JxlEncodePixels( rPixels, Lossless( 7 ) ), naLossless ), 'lossless encode' );

    var naLossy := JxlEncodePixels( rPixels, rLossy, rLimits, oToken );

    Assert.AreEqual( -1, FirstDifference( JxlEncodePixels( rPixels, rLossy ), naLossy ), 'lossy encode' );

    Assert.AreEqual( -1, FirstDifference( JxlDecodePixels( naLossy ).Data, JxlDecodePixels( naLossy, jcoSrgb, rLimits, oToken ).Data ),
      'decode' );

    var naJbrd := JxlTranscodeJpegToJxl( naJpeg, 7, rLimits, oToken );

    Assert.AreEqual( -1, FirstDifference( JxlTranscodeJpegToJxl( naJpeg, 7 ), naJbrd ), 'JPEG recompression' );
    Assert.AreEqual( -1, FirstDifference( naJpeg, JxlReconstructJpeg( naJbrd, rLimits, oToken ) ), 'JPEG reconstruction' );
    Assert.AreEqual( 1, JxlValidate( naLossless, rLimits, oToken ).DecodedFrameCount, 'validation' );
    Assert.IsFalse( oToken.IsCancelled, 'the token was never cancelled' );
  finally
    oToken.Free;
  end;

end;

procedure TTestJxlCancellation.Test_EncodeCancelledFromAnotherThread_StopsEarly;
var
  oToken: TJxlCancellation;
begin

  var rPixels  := NoisePixels( 1024 );
  var rOptions := TJxlEncodeOptions.Default;

  rOptions.Effort := 9;

  var rLimits := JxlGetDefaultLimits;

  oToken := TJxlCancellation.Create;

  try
    var rTimer := TStopwatch.StartNew;

    Assert.IsTrue( Length( JxlEncodePixels( rPixels, rOptions, rLimits, oToken ) ) > 0, 'the uncancelled encode completes' );

    var iWhole := rTimer.ElapsedMilliseconds;

    var iDelay := Integer( iWhole div 10 );
    var iElapsed: Int64;
    var bCancelled := RunCancelledAfter(
      procedure
      begin
        JxlEncodePixels( rPixels, rOptions, rLimits, oToken );
      end, oToken, iDelay, iElapsed );

    Assert.IsTrue( bCancelled, Format( 'the encode was not cancelled (whole encode %d ms, cancel at %d ms)', [ iWhole, iDelay ] ) );
    Assert.IsTrue( iElapsed >= iDelay, Format( 'it stopped at %d ms, before the cancel at %d ms', [ iElapsed, iDelay ] ) );
    Assert.IsTrue( iElapsed < iWhole div 2, Format( 'cancelled at %d ms it ran %d ms of the whole encode''s %d ms', [ iDelay, iElapsed,
      iWhole ] ) );
  finally
    oToken.Free;
  end;

end;

procedure TTestJxlCancellation.Test_DecodeCancelledFromAnotherThread_StopsEarly;
var
  oToken: TJxlCancellation;
begin

  var naJxl   := JxlEncodePixels( NoisePixels( 4096 ), Lossless( 1 ) );
  var rLimits := JxlGetDefaultLimits;

  oToken := TJxlCancellation.Create;

  try
    var rTimer := TStopwatch.StartNew;

    Assert.AreEqual( Cardinal( 4096 ), JxlDecodePixels( naJxl, jcoSrgb, rLimits, oToken ).Width, 'the uncancelled decode completes' );

    var iWhole := rTimer.ElapsedMilliseconds;

    var iDelay := Integer( iWhole div 10 );
    var iElapsed: Int64;
    var bCancelled := RunCancelledAfter(
      procedure
      begin
        JxlDecodePixels( naJxl, jcoSrgb, rLimits, oToken );
      end, oToken, iDelay, iElapsed );

    Assert.IsTrue( bCancelled, Format( 'the decode was not cancelled (whole decode %d ms, cancel at %d ms)', [ iWhole, iDelay ] ) );
    Assert.IsTrue( iElapsed < iWhole div 2, Format( 'cancelled at %d ms the decode ran %d ms of %d ms', [ iDelay, iElapsed, iWhole ] ) );

    oToken.Reset;
    bCancelled := RunCancelledAfter(
      procedure
      begin
        JxlValidate( naJxl, rLimits, oToken );
      end, oToken, iDelay, iElapsed );

    Assert.IsTrue( bCancelled, Format( 'the validation was not cancelled (cancel at %d ms)', [ iDelay ] ) );
    Assert.IsTrue( iElapsed < iWhole div 2, Format( 'cancelled at %d ms the validation ran %d ms (a decode takes %d ms)', [ iDelay,
      iElapsed, iWhole ] ) );
  finally
    oToken.Free;
  end;

end;

/// <summary>
///   Encodes pixels lossily (distance 1.0) through the C API, with a memory budget and <c>JxlCancellableParallelRunner</c>, and
///   returns the status of <c>JxlEncoderProcessOutput</c>; the encoder and runner are destroyed before returning.
/// </summary>
/// <param name="APixels">The pixels (RGB).</param>
/// <param name="AEffort">Encoder effort.</param>
/// <param name="AToken">The runner's token, or <c>nil</c>.</param>
/// <param name="ABudget">The budget, initialised by the caller; its counters are read after the call.</param>
/// <returns>The final status.</returns>
function EncodeThroughRunner( const APixels: TJxlPixels; AEffort: Integer; AToken: TJxlCancellation;
  var ABudget: TJxlMemoryBudget ): JxlEncoderStatus;
var
  rRunner: TJxlCancellableRunner;
begin

  JxlCheckLibrary;

  var rManager := ABudget.Manager;
  var pEncoder := JxlEncoderCreate( @rManager );

  Assert.IsTrue( Assigned( pEncoder ), 'JxlEncoderCreate' );
  rRunner.Runner       := JxlResizableParallelRunnerCreate( nil );
  rRunner.Cancellation := AToken;

  try
    JxlResizableParallelRunnerSetThreads( rRunner.Runner, JxlResizableParallelRunnerSuggestThreads( APixels.Width, APixels.Height ) );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetParallelRunner( pEncoder, JxlCancellableParallelRunner, @rRunner ) ),
      'SetParallelRunner' );

    var rInfo := Default( JxlBasicInfo );

    JxlEncoderInitBasicInfo( @rInfo );
    rInfo.xsize                 := APixels.Width;
    rInfo.ysize                 := APixels.Height;
    rInfo.bits_per_sample       := 8;
    rInfo.num_color_channels    := 3;
    rInfo.uses_original_profile := JXL_FALSE;
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetBasicInfo( pEncoder, @rInfo ) ), 'SetBasicInfo' );

    var rColour := Default( JxlColorEncoding );

    JxlColorEncodingSetToSRGB( @rColour, JXL_FALSE );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetColorEncoding( pEncoder, @rColour ) ), 'SetColorEncoding' );

    var pSettings := JxlEncoderFrameSettingsCreate( pEncoder, nil );

    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetFrameDistance( pSettings, 1.0 ) ), 'SetFrameDistance' );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderFrameSettingsSetOption( pSettings, JXL_ENC_FRAME_SETTING_EFFORT,
      AEffort ) ), 'effort' );

    var rFormat := Default( JxlPixelFormat );

    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_UINT8;
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderAddImageFrame( pSettings, @rFormat, PByte( APixels.Data ),
      Length( APixels.Data ) ) ), 'AddImageFrame' );
    JxlEncoderCloseInput( pEncoder );

    var naOut: TBytes;

    SetLength( naOut, Length( APixels.Data ) * 2 );

    var pNext: PByte           := PByte( naOut );
    var iAvailable: NativeUInt := Length( naOut );

    Result := JxlEncoderProcessOutput( pEncoder, @pNext, @iAvailable );
  finally
    JxlEncoderDestroy( pEncoder );
    JxlResizableParallelRunnerDestroy( rRunner.Runner );
  end;

end;

procedure TTestJxlCancellation.Test_CancellableRunner_CancelledEncoderReleasesAllMemory;
var
  oToken: TJxlCancellation;
  rBudget: TJxlMemoryBudget;
begin

  var rPixels := NoisePixels( 1024 );

  oToken := TJxlCancellation.Create;

  try
    rBudget.Init( Int64( 1 ) shl 30 );

    var rTimer := TStopwatch.StartNew;

    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( EncodeThroughRunner( rPixels, 9, oToken, rBudget ) ), 'uncancelled, it encodes' );

    var iWhole := rTimer.ElapsedMilliseconds;

    Assert.AreEqual( Int64( 0 ), rBudget.Used, 'the uncancelled encoder released everything' );

    rBudget.Init( Int64( 1 ) shl 30 );

    var eStatus: JxlEncoderStatus;
    var iElapsed: Int64;
    var iDelay   := Integer( iWhole div 10 );
    var oThread  := CancelAfter( oToken, iDelay );

    try
      rTimer  := TStopwatch.StartNew;
      eStatus := EncodeThroughRunner( rPixels, 9, oToken, rBudget );
      iElapsed := rTimer.ElapsedMilliseconds;
    finally
      oThread.WaitFor;
      oThread.Free;
    end;

    Assert.AreEqual( Ord( JXL_ENC_ERROR ), Ord( eStatus ), Format( 'cancelled at %d ms (whole encode %d ms), the encode must fail',
      [ iDelay, iWhole ] ) );
    Assert.IsTrue( iElapsed < iWhole div 2, Format( 'cancelled at %d ms it ran %d ms of %d ms', [ iDelay, iElapsed, iWhole ] ) );
    Assert.IsTrue( rBudget.Peak > 1024 * 1024, Format( 'the encoder had started work (peak %d bytes)', [ rBudget.Peak ] ) );
    Assert.AreEqual( Int64( 0 ), rBudget.Used, 'the cancelled encoder released every byte' );
    Assert.AreEqual( 0, rBudget.Refusals, 'no allocation was refused: the failure was the cancellation' );
  finally
    oToken.Free;
  end;

end;

const
  /// <summary>Tasks in the runner-contract test's range.</summary>
  CONTRACT_TASKS = 100000;

type
  /// <summary>What the runner-contract test's callbacks record.</summary>
  TContractProbe = record
    /// <summary>Times the init callback ran.</summary>
    InitCalls: Integer;
    /// <summary>Tasks run.</summary>
    Runs: Integer;
    /// <summary>Tasks run more than once.</summary>
    Repeats: Integer;
    /// <summary>Per task: 1 once it has run.</summary>
    Done: TArray<Integer>;
    /// <summary>Cancelled by the first task to run, when set.</summary>
    CancelOnFirstTask: TJxlCancellation;
  end;
  /// <summary>Pointer to a <see cref="TContractProbe" />.</summary>
  PContractProbe = ^TContractProbe;

/// <summary>Init callback of the runner-contract test.</summary>
/// <param name="jpegxl_opaque">The probe.</param>
/// <param name="num_threads">Unused.</param>
/// <returns>Success.</returns>
function ContractInit( jpegxl_opaque: Pointer; num_threads: NativeUInt ): JxlParallelRetCode; cdecl;
begin

  AtomicIncrement( PContractProbe( jpegxl_opaque ).InitCalls );
  Result := JXL_PARALLEL_RET_SUCCESS;

end;

/// <summary>Task callback of the runner-contract test: counts the task and, if asked, cancels the token.</summary>
/// <param name="jpegxl_opaque">The probe.</param>
/// <param name="value">The task.</param>
/// <param name="thread_id">Unused.</param>
procedure ContractRun( jpegxl_opaque: Pointer; value: UInt32; thread_id: NativeUInt ); cdecl;
begin

  var pProbe := PContractProbe( jpegxl_opaque );

  AtomicIncrement( pProbe.Runs );

  if ( AtomicExchange( pProbe.Done[ value ], 1 ) <> 0 ) then AtomicIncrement( pProbe.Repeats );

  if Assigned( pProbe.CancelOnFirstTask ) then pProbe.CancelOnFirstTask.Cancel;

end;

/// <summary>Runs the contract range through <c>JxlCancellableParallelRunner</c> on 4 threads.</summary>
/// <param name="AToken">The runner's token, or <c>nil</c>.</param>
/// <param name="ACancelOnFirstTask">Whether the first task to run cancels the token.</param>
/// <param name="AProbe">Receives what the callbacks recorded.</param>
/// <returns>What the runner returned.</returns>
function RunContract( AToken: TJxlCancellation; ACancelOnFirstTask: Boolean; out AProbe: TContractProbe ): JxlParallelRetCode;
var
  rRunner: TJxlCancellableRunner;
begin

  JxlCheckLibrary;
  AProbe := Default( TContractProbe );
  SetLength( AProbe.Done, CONTRACT_TASKS );

  if ACancelOnFirstTask then AProbe.CancelOnFirstTask := AToken;

  rRunner.Runner       := JxlResizableParallelRunnerCreate( nil );
  rRunner.Cancellation := AToken;

  try
    JxlResizableParallelRunnerSetThreads( rRunner.Runner, 4 );
    Result := JxlCancellableParallelRunner( @rRunner, @AProbe, ContractInit, ContractRun, 0, CONTRACT_TASKS );
  finally
    JxlResizableParallelRunnerDestroy( rRunner.Runner );
  end;

end;

procedure TTestJxlCancellation.Test_CancellableRunner_ContractWithLibjxl;
var
  oToken: TJxlCancellation;
  rProbe: TContractProbe;
begin

  var iResult := RunContract( nil, False, rProbe );

  Assert.AreEqual( JXL_PARALLEL_RET_SUCCESS, iResult, 'no token: result' );
  Assert.AreEqual( 1, rProbe.InitCalls, 'no token: init calls' );
  Assert.AreEqual( CONTRACT_TASKS, rProbe.Runs, 'no token: every task runs' );
  Assert.AreEqual( 0, rProbe.Repeats, 'no token: no task runs twice' );

  oToken := TJxlCancellation.Create;

  try
    iResult := RunContract( oToken, False, rProbe );
    Assert.AreEqual( JXL_PARALLEL_RET_SUCCESS, iResult, 'uncancelled token: result' );
    Assert.AreEqual( 1, rProbe.InitCalls, 'uncancelled token: init calls' );
    Assert.AreEqual( CONTRACT_TASKS, rProbe.Runs, 'uncancelled token: every task runs' );
    Assert.AreEqual( 0, rProbe.Repeats, 'uncancelled token: no task runs twice' );

    oToken.Cancel;
    iResult := RunContract( oToken, False, rProbe );
    Assert.AreEqual( JXL_PARALLEL_RET_RUNNER_ERROR, iResult, 'cancelled before the call: result' );
    Assert.AreEqual( 0, rProbe.InitCalls, 'cancelled before the call: init is not called' );
    Assert.AreEqual( 0, rProbe.Runs, 'cancelled before the call: no task runs' );

    oToken.Reset;
    iResult := RunContract( oToken, True, rProbe );
    Assert.AreEqual( JXL_PARALLEL_RET_RUNNER_ERROR, iResult, 'cancelled during the batch: result' );
    Assert.AreEqual( 1, rProbe.InitCalls, 'cancelled during the batch: init calls' );
    Assert.IsTrue( rProbe.Runs < CONTRACT_TASKS div 2, Format( 'cancelled during the batch: %d of %d tasks ran', [ rProbe.Runs,
      CONTRACT_TASKS ] ) );
  finally
    oToken.Free;
  end;

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlCancellation );

end.
