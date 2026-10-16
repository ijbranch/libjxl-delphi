(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of the C API import units (<c>Jxl.Api.*</c>): record layouts against the C headers, calling convention and
///   linkage against the real DLLs, and the library-availability checks.
/// </summary>
unit TestJxl.Api;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of the C API imports and the library checks.</summary>
  [ TestFixture ]
  TTestJxlApi = class
  private
    /// <summary>Mismatches collected by <see cref="Expect" />, one per line.</summary>
    FMismatches: string;
    /// <summary>Records a mismatch when a measured size or offset differs from the C value for this platform.</summary>
    /// <param name="AName">What was measured, e.g. <c>SizeOf(JxlBasicInfo)</c>.</param>
    /// <param name="AActual">The Delphi value.</param>
    /// <param name="AExpected32">The C value on x86 (MSVC / clang-cl).</param>
    /// <param name="AExpected64">The C value on x64 (MSVC / clang-cl).</param>
    procedure Expect( const AName: string; AActual: NativeInt; AExpected32: NativeInt; AExpected64: NativeInt );
    /// <summary>Records a mismatch when an enumerator or constant does not have its C value.</summary>
    /// <param name="AName">The C name.</param>
    /// <param name="AActual">The Delphi value.</param>
    /// <param name="AExpected">The value in the C header.</param>
    procedure ExpectValue( const AName: string; AActual: Int64; AExpected: Int64 );
    /// <summary>Fails the test listing every mismatch collected since it started.</summary>
    procedure AssertNoMismatches;
  public
    /// <summary>Clears the mismatch list.</summary>
    [ Setup ]
    procedure Setup;
    /// <summary>
    ///   Proves the <c>types.h</c> records and every C enum have the C size: a 4-byte enum and natural alignment are
    ///   what make <c>JxlPixelFormat</c> (whose <c>size_t</c> moves with the platform) match MSVC on Win32 and Win64.
    /// </summary>
    [ Test ]
    procedure Test_Layout_TypesH_MatchesCProbe;
    /// <summary>
    ///   Proves the <c>codestream_header.h</c> records match the C sizes and field offsets measured by a C probe, so
    ///   <c>JxlBasicInfo</c> and <c>JxlFrameHeader</c> filled in by the DLL land in the right fields.
    /// </summary>
    [ Test ]
    procedure Test_Layout_CodestreamHeader_MatchesCProbe;
    /// <summary>
    ///   Proves <c>JxlColorEncoding</c> matches the C layout, including the 8-byte alignment of its <c>double</c>
    ///   fields on Win32, which a packed or 4-aligned record would get wrong.
    /// </summary>
    [ Test ]
    procedure Test_Layout_ColorEncoding_MatchesCProbe;
    /// <summary>
    ///   Proves the pointer-bearing records (memory manager, CMS interface, colour profile, gain map bundle, encoder
    ///   output processor, chunked input source) match C on both pointer widths.
    /// </summary>
    [ Test ]
    procedure Test_Layout_PointerRecords_MatchesCProbe;
    /// <summary>
    ///   Proves the DLL can be loaded and reports a release at least as new as the headers the binding mirrors (0.12.0,
    ///   hand-typed), with the decoder and encoder agreeing, so an older libjxl is caught before its records are
    ///   trusted.
    /// </summary>
    [ Test ]
    procedure Test_Version_DecoderAndEncoder_AtLeastBindingHeaders;
    /// <summary>
    ///   Proves <c>JxlSignatureCheck</c> is called correctly (cdecl, pointer plus size_t): it recognises a bare
    ///   codestream and a container, rejects a PNG, and asks for more bytes for a single byte.
    /// </summary>
    [ Test ]
    procedure Test_SignatureCheck_JxlPngAndShortInput_Classified;
    /// <summary>
    ///   Proves the raw decoder event loop works through the binding and that <c>JxlBasicInfo</c> comes back with the
    ///   real image dimensions of <c>splines.jxl</c> (2048 x 2048, RGB, no alpha).
    /// </summary>
    [ Test ]
    procedure Test_DecoderBasicInfo_Splines_ReportsDimensions;
    /// <summary>
    ///   Proves the DLL writes <c>JxlBasicInfo</c> defaults at the offsets the Delphi record expects, including the
    ///   animation header near the end, and does not write into the trailing padding.
    /// </summary>
    [ Test ]
    procedure Test_EncoderInitBasicInfo_FillsDefaultsAtCOffsets;
    /// <summary>
    ///   Proves <c>JxlColorEncodingSetToSRGB</c> writes the sRGB enums and the D65 white point double where the Delphi
    ///   record reads them.
    /// </summary>
    [ Test ]
    procedure Test_ColorEncodingSetToSRGB_FillsSrgbFields;
    /// <summary>
    ///   Proves both thread runners really run a parallel job through the binding's callback types: the init callback
    ///   is called once with a positive thread count, the run callback exactly once for every value of the range
    ///   [10, 5010) and for no other, with a thread id below that count, and a failing init makes the runner fail.
    ///   A wrong calling convention or parameter order would corrupt the values or crash.
    /// </summary>
    [ Test ]
    procedure Test_ThreadRunners_RunParallelJob_EveryValueOnce;
    /// <summary>
    ///   Proves the default CMS works, not merely that it is bound: a lossless image tagged linear sRGB can be decoded
    ///   to sRGB only with <c>JxlGetDefaultCms</c> set (without it libjxl refuses the output profile), and the CMS turns
    ///   the linear sample 128 into the sRGB value 188 (hand-computed: 255 * (1.055 * (128/255)^(1/2.4) - 0.055)).
    /// </summary>
    [ Test ]
    procedure Test_DefaultCms_ConvertsLinearToSrgb;
    /// <summary>
    ///   Proves the availability checks report the real DLLs as present, and that the checks they are built on report
    ///   the absent cases: a module without the exports (kernel32) and a version below the minimum.
    /// </summary>
    [ Test ]
    procedure Test_LibraryAvailable_RealDllsTrue_SeamsReportFaults;
    /// <summary>
    ///   Proves a missing DLL is reported, not crashed on: <c>JxlModuleAvailable</c> is False and
    ///   <c>JxlCheckModule</c> raises <c>EJxlError</c> naming <c>LoadLibraryEx</c> with ERROR_MOD_NOT_FOUND (126),
    ///   the DLL and the rule that only the safe folders are searched.
    /// </summary>
    [ Test ]
    procedure Test_CheckModule_MissingDll_RaisesEJxlError;
    /// <summary>
    ///   Proves the export tables that <c>JxlCheckLibrary</c> verifies are the single source of truth: each unit's table
    ///   holds exactly the functions its source declares <c>external ... delayed</c> (parsed from the source files), from
    ///   the right library constant, 115 in all. A new import missing from its table fails here.
    /// </summary>
    [ Test ]
    procedure Test_ExportTables_MatchImportDeclarations;
    /// <summary>
    ///   Proves the export check finds exactly the missing names: the real DLL lacks none of the tables' functions, a
    ///   list with one invented name reports only that name, and kernel32 lacks every libjxl function.
    /// </summary>
    [ Test ]
    procedure Test_FindMissingExports_ReportsOnlyMissingNames;
    /// <summary>
    ///   Proves the version check: 0.12.999 (one below the minimum) raises <c>EJxlError</c> naming
    ///   <c>JxlDecoderVersion</c>, the version found, the minimum and the DLL path; 0.12.0 and later pass.
    /// </summary>
    [ Test ]
    procedure Test_CheckVersion_RejectsOlderThanMinimum;
    /// <summary>
    ///   Proves DLLs are not loaded from the current directory: a copy of the DLL placed only in the current directory
    ///   is not found by name, though the same file loads by full path; and the executable's folder is searched.
    /// </summary>
    [ Test ]
    procedure Test_ModuleLoading_IgnoresCurrentDirectory;
    /// <summary>
    ///   Proves the memory budget: it hands out blocks within its limit, refuses (returns <c>nil</c>) one that would
    ///   exceed it, tracks the peak, and balances to 0 on free; libjxl decoding <c>splines.jxl</c> under a 1 MB budget
    ///   fails cleanly with refusals counted, under a large one succeeds, and both leave nothing allocated.
    /// </summary>
    [ Test ]
    procedure Test_MemoryBudget_RefusesOverLimitAndBalances;
    /// <summary>
    ///   Proves every enumerator and constant of <c>Jxl.Api.Types</c> has the value of its C header (types.h,
    ///   codestream_header.h, color_encoding.h, stats.h, parallel_runner.h). The expected values were generated from
    ///   the C headers, not from the Pascal unit, so a mistyped enumerator fails here although no behavioural test
    ///   would notice it.
    /// </summary>
    [ Test ]
    procedure Test_EnumValues_Types_MatchCHeaders;
    /// <summary>Proves every <c>decode.h</c> enumerator has its C value (statuses, signatures, progressive detail).</summary>
    [ Test ]
    procedure Test_EnumValues_Decode_MatchCHeaders;
    /// <summary>
    ///   Proves every <c>encode.h</c> enumerator has its C value: a wrong frame-setting id would silently set a
    ///   different option.
    /// </summary>
    [ Test ]
    procedure Test_EnumValues_Encode_MatchCHeaders;
    /// <summary>Proves <c>JxlVersionToString</c> splits MAJOR*1000000 + MINOR*1000 + PATCH correctly.</summary>
    [ Test ]
    procedure Test_VersionToString_SplitsFields;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Math, System.RegularExpressions, System.Generics.Collections,
  Jxl.Api.Types, Jxl.Api.Decode, Jxl.Api.Encode, Jxl.Api.Threads, Jxl.Api.Cms,
  TestJxl.Common;

const
  /// <summary>A DLL name that cannot exist, for the missing-library tests.</summary>
  MISSING_DLL = 'jxl_binding_test_missing_8d1f.dll';
  /// <summary>First value of the range the parallel-runner test runs.</summary>
  RUN_START = 10;
  /// <summary>End (exclusive) of the range the parallel-runner test runs.</summary>
  RUN_END = 5010;

type
  /// <summary>What the parallel-runner test's callbacks record.</summary>
  TRunnerProbe = record
    /// <summary>Times the init callback ran.</summary>
    InitCalls: Integer;
    /// <summary>Thread count the init callback received.</summary>
    Threads: NativeUInt;
    /// <summary>Per value: 0 if never run, else value * 3 + 1, or -1 for a thread id out of range.</summary>
    Values: TArray<Integer>;
    /// <summary>Runs of a value that had already run.</summary>
    Repeats: Integer;
  end;
  /// <summary>Pointer to a <see cref="TRunnerProbe" />.</summary>
  PRunnerProbe = ^TRunnerProbe;

/// <summary>Init callback of the parallel-runner test.</summary>
/// <param name="jpegxl_opaque">The probe.</param>
/// <param name="num_threads">Threads the runner will use.</param>
/// <returns>Success.</returns>
function ProbeInit( jpegxl_opaque: Pointer; num_threads: NativeUInt ): JxlParallelRetCode; cdecl;
begin

  Inc( PRunnerProbe( jpegxl_opaque ).InitCalls );
  PRunnerProbe( jpegxl_opaque ).Threads := num_threads;
  Result := JXL_PARALLEL_RET_SUCCESS;

end;

/// <summary>Init callback that fails, for the parallel-runner test.</summary>
/// <param name="jpegxl_opaque">Unused.</param>
/// <param name="num_threads">Unused.</param>
/// <returns>A non-zero code.</returns>
function FailingInit( jpegxl_opaque: Pointer; num_threads: NativeUInt ): JxlParallelRetCode; cdecl;
begin

  Result := -7;

end;

/// <summary>Run callback of the parallel-runner test: records value * 3 + 1 at the value's index.</summary>
/// <param name="jpegxl_opaque">The probe.</param>
/// <param name="value">The value.</param>
/// <param name="thread_id">The calling thread's index.</param>
procedure ProbeRun( jpegxl_opaque: Pointer; value: UInt32; thread_id: NativeUInt ); cdecl;
begin

  var pProbe := PRunnerProbe( jpegxl_opaque );

  if ( value >= UInt32( Length( pProbe.Values ) ) ) then Exit;

  if ( pProbe.Values[ value ] <> 0 ) then AtomicIncrement( pProbe.Repeats );

  pProbe.Values[ value ] := if ( thread_id < pProbe.Threads ) then Integer( value ) * 3 + 1 else -1;

end;

/// <summary>Checks a probe after a run: init once, every value of the range once, nothing outside it.</summary>
/// <param name="AProbe">The probe.</param>
/// <param name="AResult">What the runner returned.</param>
/// <param name="AWhat">Which runner, for the messages.</param>
procedure AssertProbe( const AProbe: TRunnerProbe; AResult: JxlParallelRetCode; const AWhat: string );
begin

  Assert.AreEqual( JXL_PARALLEL_RET_SUCCESS, AResult, AWhat + ': result' );
  Assert.AreEqual( 1, AProbe.InitCalls, AWhat + ': init calls' );
  Assert.IsTrue( AProbe.Threads >= 1, AWhat + ': thread count' );
  Assert.AreEqual( 0, AProbe.Repeats, AWhat + ': values run twice' );

  for var iI := 0 to High( AProbe.Values ) do
  begin
    var iExpected := if ( iI >= RUN_START ) and ( iI < RUN_END ) then iI * 3 + 1 else 0;

    if ( AProbe.Values[ iI ] <> iExpected ) then
      Assert.Fail( Format( '%s: value %d holds %d, expected %d', [ AWhat, iI, AProbe.Values[ iI ], iExpected ] ) );
  end;

end;

/// <summary>Returns a 2 x 2 image of linear sample 128, encoded losslessly and tagged linear sRGB.</summary>
/// <returns>The JPEG XL file.</returns>
function EncodeLinearGrey128: TBytes;
begin

  var pEncoder := JxlEncoderCreate( nil );

  try
    var rInfo := Default( JxlBasicInfo );
    JxlEncoderInitBasicInfo( @rInfo );
    rInfo.xsize                 := 2;
    rInfo.ysize                 := 2;
    rInfo.bits_per_sample       := 8;
    rInfo.num_color_channels    := 3;
    rInfo.uses_original_profile := JXL_TRUE;
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetBasicInfo( pEncoder, @rInfo ) ), 'SetBasicInfo' );

    var rColour := Default( JxlColorEncoding );
    JxlColorEncodingSetToLinearSRGB( @rColour, JXL_FALSE );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetColorEncoding( pEncoder, @rColour ) ), 'SetColorEncoding' );

    var pSettings := JxlEncoderFrameSettingsCreate( pEncoder, nil );
    Assert.AreEqual( Ord( JXL_ENC_SUCCESS ), Ord( JxlEncoderSetFrameLossless( pSettings, JXL_TRUE ) ), 'SetFrameLossless' );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_UINT8;

    var naPixels: TBytes;
    SetLength( naPixels, 2 * 2 * 3 );
    FillChar( naPixels[ 0 ], Length( naPixels ), 128 );
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

/// <summary>Decodes a file asking for sRGB output, with or without the default CMS.</summary>
/// <param name="AData">The file.</param>
/// <param name="AUseCms">Set <c>JxlGetDefaultCms</c> on the decoder.</param>
/// <param name="AFirstSample">Receives the first decoded sample when decoding succeeds.</param>
/// <returns>What <c>JxlDecoderSetOutputColorProfile</c> returned.</returns>
function DecodeAsSrgb( const AData: TBytes; AUseCms: Boolean; out AFirstSample: Byte ): JxlDecoderStatus;
begin

  AFirstSample := 0;
  Result       := JXL_DEC_ERROR;

  var pDecoder := JxlDecoderCreate( nil );

  try
    if AUseCms then
      Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetCms( pDecoder, JxlGetDefaultCms^ ) ), 'SetCms' );

    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_COLOR_ENCODING )
      or Ord( JXL_DEC_FULL_IMAGE ) ) ), 'SubscribeEvents' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetInput( pDecoder, PByte( AData ), Length( AData ) ) ), 'SetInput' );
    JxlDecoderCloseInput( pDecoder );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_UINT8;

    var naPixels: TBytes;
    SetLength( naPixels, 2 * 2 * 3 );

    var eStatus := JxlDecoderProcessInput( pDecoder );

    while ( eStatus <> JXL_DEC_FULL_IMAGE ) do
    begin
      if ( eStatus = JXL_DEC_COLOR_ENCODING ) then
      begin
        var rSrgb := Default( JxlColorEncoding );
        JxlColorEncodingSetToSRGB( @rSrgb, JXL_FALSE );
        Result := JxlDecoderSetOutputColorProfile( pDecoder, @rSrgb, nil, 0 );

        if ( Result <> JXL_DEC_SUCCESS ) then Exit;
      end
      else if ( eStatus = JXL_DEC_NEED_IMAGE_OUT_BUFFER ) then
        Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetImageOutBuffer( pDecoder, @rFormat, PByte( naPixels ),
          Length( naPixels ) ) ), 'SetImageOutBuffer' )
      else
        Assert.Fail( Format( 'unexpected decoder status %d', [ Ord( eStatus ) ] ) );

      eStatus := JxlDecoderProcessInput( pDecoder );
    end;

    AFirstSample := naPixels[ 0 ];
  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

/// <summary>Decodes a file in full through a given memory manager.</summary>
/// <param name="AData">The file.</param>
/// <param name="AManager">The memory manager for the decoder.</param>
/// <returns>
///   <c>JXL_DEC_FULL_IMAGE</c> when the image decoded, otherwise the failing status (<c>JXL_DEC_ERROR</c> also when the
///   decoder could not even be created).
/// </returns>
function DecodeThroughManager( const AData: TBytes; const AManager: JxlMemoryManager ): JxlDecoderStatus;
begin

  var rManager := AManager;
  var pDecoder := JxlDecoderCreate( @rManager );

  if ( not Assigned( pDecoder ) ) then Exit( JXL_DEC_ERROR );

  try
    JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_FULL_IMAGE ) );
    JxlDecoderSetInput( pDecoder, PByte( AData ), Length( AData ) );
    JxlDecoderCloseInput( pDecoder );

    var rFormat := Default( JxlPixelFormat );
    rFormat.num_channels := 3;
    rFormat.data_type    := JXL_TYPE_UINT8;

    var rInfo  := Default( JxlBasicInfo );
    var naOut  := TBytes( nil );
    Result     := JxlDecoderProcessInput( pDecoder );

    while ( Result = JXL_DEC_BASIC_INFO ) or ( Result = JXL_DEC_NEED_IMAGE_OUT_BUFFER ) do
    begin
      if ( Result = JXL_DEC_BASIC_INFO ) then
        JxlDecoderGetBasicInfo( pDecoder, @rInfo )
      else
      begin
        SetLength( naOut, rInfo.xsize * rInfo.ysize * 3 );
        JxlDecoderSetImageOutBuffer( pDecoder, @rFormat, PByte( naOut ), Length( naOut ) );
      end;

      Result := JxlDecoderProcessInput( pDecoder );
    end;

  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

{ TTestJxlApi }

procedure TTestJxlApi.Setup;
begin

  FMismatches := '';

end;

procedure TTestJxlApi.Expect( const AName: string; AActual: NativeInt; AExpected32: NativeInt; AExpected64: NativeInt );
begin

  var iExpected := if ( SizeOf( Pointer ) = 8 ) then AExpected64 else AExpected32;

  if ( AActual <> iExpected ) then
    FMismatches := FMismatches + Format( '%s = %d, C has %d%s', [ AName, AActual, iExpected, sLineBreak ] );

end;

procedure TTestJxlApi.AssertNoMismatches;
begin

  Assert.IsTrue( FMismatches = '', sLineBreak + FMismatches );

end;

procedure TTestJxlApi.Test_Layout_TypesH_MatchesCProbe;
begin

  var rFormat := Default( JxlPixelFormat );
  Expect( 'SizeOf(JxlPixelFormat)', SizeOf( JxlPixelFormat ), 16, 24 );
  Expect( 'JxlPixelFormat.align', PByte( @rFormat.align ) - PByte( @rFormat ), 12, 16 );
  Expect( 'SizeOf(JxlBitDepth)', SizeOf( JxlBitDepth ), 12, 12 );
  Expect( 'SizeOf(JxlBoxType)', SizeOf( JxlBoxType ), 4, 4 );
  Expect( 'SizeOf(JXL_BOOL)', SizeOf( JXL_BOOL ), 4, 4 );
  Expect( 'SizeOf(JxlDataType)', SizeOf( JxlDataType ), 4, 4 );
  Expect( 'SizeOf(JxlEndianness)', SizeOf( JxlEndianness ), 4, 4 );
  Expect( 'SizeOf(JxlBitDepthType)', SizeOf( JxlBitDepthType ), 4, 4 );
  Expect( 'SizeOf(JxlOrientation)', SizeOf( JxlOrientation ), 4, 4 );
  Expect( 'SizeOf(JxlExtraChannelType)', SizeOf( JxlExtraChannelType ), 4, 4 );
  Expect( 'SizeOf(JxlBlendMode)', SizeOf( JxlBlendMode ), 4, 4 );
  Expect( 'SizeOf(JxlColorSpace)', SizeOf( JxlColorSpace ), 4, 4 );
  Expect( 'SizeOf(JxlWhitePoint)', SizeOf( JxlWhitePoint ), 4, 4 );
  Expect( 'SizeOf(JxlPrimaries)', SizeOf( JxlPrimaries ), 4, 4 );
  Expect( 'SizeOf(JxlTransferFunction)', SizeOf( JxlTransferFunction ), 4, 4 );
  Expect( 'SizeOf(JxlRenderingIntent)', SizeOf( JxlRenderingIntent ), 4, 4 );
  Expect( 'SizeOf(JxlEncoderStatsKey)', SizeOf( JxlEncoderStatsKey ), 4, 4 );
  Expect( 'SizeOf(JxlSignature)', SizeOf( JxlSignature ), 4, 4 );
  Expect( 'SizeOf(JxlDecoderStatus)', SizeOf( JxlDecoderStatus ), 4, 4 );
  Expect( 'SizeOf(JxlProgressiveDetail)', SizeOf( JxlProgressiveDetail ), 4, 4 );
  Expect( 'SizeOf(JxlColorProfileTarget)', SizeOf( JxlColorProfileTarget ), 4, 4 );
  Expect( 'SizeOf(JxlEncoderStatus)', SizeOf( JxlEncoderStatus ), 4, 4 );
  Expect( 'SizeOf(JxlEncoderError)', SizeOf( JxlEncoderError ), 4, 4 );
  Expect( 'SizeOf(JxlEncoderFrameSettingId)', SizeOf( JxlEncoderFrameSettingId ), 4, 4 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_Layout_CodestreamHeader_MatchesCProbe;
begin

  var rInfo    := Default( JxlBasicInfo );
  var rChannel := Default( JxlExtraChannelInfo );
  var rLayer   := Default( JxlLayerInfo );
  var rFrame   := Default( JxlFrameHeader );
  Expect( 'SizeOf(JxlPreviewHeader)', SizeOf( JxlPreviewHeader ), 8, 8 );
  Expect( 'SizeOf(JxlAnimationHeader)', SizeOf( JxlAnimationHeader ), 16, 16 );
  Expect( 'SizeOf(JxlBasicInfo)', SizeOf( JxlBasicInfo ), 204, 204 );
  Expect( 'JxlBasicInfo.intensity_target', PByte( @rInfo.intensity_target ) - PByte( @rInfo ), 20, 20 );
  Expect( 'JxlBasicInfo.orientation', PByte( @rInfo.orientation ) - PByte( @rInfo ), 48, 48 );
  Expect( 'JxlBasicInfo.preview', PByte( @rInfo.preview ) - PByte( @rInfo ), 72, 72 );
  Expect( 'JxlBasicInfo.animation', PByte( @rInfo.animation ) - PByte( @rInfo ), 80, 80 );
  Expect( 'JxlBasicInfo.intrinsic_xsize', PByte( @rInfo.intrinsic_xsize ) - PByte( @rInfo ), 96, 96 );
  Expect( 'JxlBasicInfo.padding', PByte( @rInfo.padding ) - PByte( @rInfo ), 104, 104 );
  Expect( 'SizeOf(JxlExtraChannelInfo)', SizeOf( JxlExtraChannelInfo ), 44, 44 );
  Expect( 'JxlExtraChannelInfo.spot_color', PByte( @rChannel.spot_color ) - PByte( @rChannel ), 24, 24 );
  Expect( 'JxlExtraChannelInfo.cfa_channel', PByte( @rChannel.cfa_channel ) - PByte( @rChannel ), 40, 40 );
  Expect( 'SizeOf(JxlHeaderExtensions)', SizeOf( JxlHeaderExtensions ), 8, 8 );
  Expect( 'SizeOf(JxlBlendInfo)', SizeOf( JxlBlendInfo ), 16, 16 );
  Expect( 'SizeOf(JxlLayerInfo)', SizeOf( JxlLayerInfo ), 40, 40 );
  Expect( 'JxlLayerInfo.blend_info', PByte( @rLayer.blend_info ) - PByte( @rLayer ), 20, 20 );
  Expect( 'JxlLayerInfo.save_as_reference', PByte( @rLayer.save_as_reference ) - PByte( @rLayer ), 36, 36 );
  Expect( 'SizeOf(JxlFrameHeader)', SizeOf( JxlFrameHeader ), 56, 56 );
  Expect( 'JxlFrameHeader.layer_info', PByte( @rFrame.layer_info ) - PByte( @rFrame ), 16, 16 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_Layout_ColorEncoding_MatchesCProbe;
begin

  var rColour := Default( JxlColorEncoding );
  Expect( 'SizeOf(JxlColorEncoding)', SizeOf( JxlColorEncoding ), 104, 104 );
  Expect( 'JxlColorEncoding.white_point_xy', PByte( @rColour.white_point_xy ) - PByte( @rColour ), 8, 8 );
  Expect( 'JxlColorEncoding.primaries', PByte( @rColour.primaries ) - PByte( @rColour ), 24, 24 );
  Expect( 'JxlColorEncoding.primaries_red_xy', PByte( @rColour.primaries_red_xy ) - PByte( @rColour ), 32, 32 );
  Expect( 'JxlColorEncoding.transfer_function', PByte( @rColour.transfer_function ) - PByte( @rColour ), 80, 80 );
  Expect( 'JxlColorEncoding.gamma', PByte( @rColour.gamma ) - PByte( @rColour ), 88, 88 );
  Expect( 'JxlColorEncoding.rendering_intent', PByte( @rColour.rendering_intent ) - PByte( @rColour ), 96, 96 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_Layout_PointerRecords_MatchesCProbe;
begin

  var rProfile := Default( JxlColorProfile );
  var rBundle  := Default( JxlGainMapBundle );
  Expect( 'SizeOf(JxlMemoryManager)', SizeOf( JxlMemoryManager ), 12, 24 );
  Expect( 'SizeOf(JxlCmsInterface)', SizeOf( JxlCmsInterface ), 32, 64 );
  Expect( 'SizeOf(JxlColorProfile)', SizeOf( JxlColorProfile ), 120, 128 );
  Expect( 'JxlColorProfile.color_encoding', PByte( @rProfile.color_encoding ) - PByte( @rProfile ), 8, 16 );
  Expect( 'JxlColorProfile.num_channels', PByte( @rProfile.num_channels ) - PByte( @rProfile ), 112, 120 );
  Expect( 'SizeOf(JxlGainMapBundle)', SizeOf( JxlGainMapBundle ), 136, 160 );
  Expect( 'JxlGainMapBundle.gain_map_metadata_size', PByte( @rBundle.gain_map_metadata_size ) - PByte( @rBundle ), 2, 2 );
  Expect( 'JxlGainMapBundle.gain_map_metadata', PByte( @rBundle.gain_map_metadata ) - PByte( @rBundle ), 4, 8 );
  Expect( 'JxlGainMapBundle.has_color_encoding', PByte( @rBundle.has_color_encoding ) - PByte( @rBundle ), 8, 16 );
  Expect( 'JxlGainMapBundle.color_encoding', PByte( @rBundle.color_encoding ) - PByte( @rBundle ), 16, 24 );
  Expect( 'JxlGainMapBundle.alt_icc_size', PByte( @rBundle.alt_icc_size ) - PByte( @rBundle ), 120, 128 );
  Expect( 'JxlGainMapBundle.alt_icc', PByte( @rBundle.alt_icc ) - PByte( @rBundle ), 124, 136 );
  Expect( 'JxlGainMapBundle.gain_map_size', PByte( @rBundle.gain_map_size ) - PByte( @rBundle ), 128, 144 );
  Expect( 'JxlGainMapBundle.gain_map', PByte( @rBundle.gain_map ) - PByte( @rBundle ), 132, 152 );
  Expect( 'SizeOf(JxlEncoderOutputProcessor)', SizeOf( JxlEncoderOutputProcessor ), 20, 40 );
  Expect( 'SizeOf(JxlChunkedFrameInputSource)', SizeOf( JxlChunkedFrameInputSource ), 24, 48 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_Version_DecoderAndEncoder_AtLeastBindingHeaders;
begin

  JxlCheckLibrary;

  Assert.AreEqual( 12000, Integer( JPEGXL_MAJOR_VERSION * 1000000 + JPEGXL_MINOR_VERSION * 1000 + JPEGXL_PATCH_VERSION ),
    'the binding mirrors the libjxl 0.12.0 headers' );
  Assert.IsTrue( JxlDecoderVersion >= 12000, Format( 'JxlDecoderVersion %s is 0.12.0 or later',
    [ JxlVersionToString( JxlDecoderVersion ) ] ) );
  Assert.AreEqual( Int64( JxlDecoderVersion ), Int64( JxlEncoderVersion ), 'the decoder and encoder report the same version' );

end;

procedure TTestJxlApi.Test_SignatureCheck_JxlPngAndShortInput_Classified;
begin

  JxlCheckLibrary;

  var naCodestream := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var naContainer  := TFile.ReadAllBytes( TestDataFile( 'jpeg_reconstruction\1x1_exif_xmp.jxl' ) );
  var naPng        := TFile.ReadAllBytes( TestDataFile( 'splines.png' ) );
  var naShort: TBytes := [ $FF ];

  Assert.AreEqual( Ord( JXL_SIG_CODESTREAM ), Ord( JxlSignatureCheck( PByte( naCodestream ), Length( naCodestream ) ) ), 'splines.jxl' );
  Assert.AreEqual( Ord( JXL_SIG_CONTAINER ), Ord( JxlSignatureCheck( PByte( naContainer ), Length( naContainer ) ) ), '1x1_exif_xmp.jxl' );
  Assert.AreEqual( Ord( JXL_SIG_INVALID ), Ord( JxlSignatureCheck( PByte( naPng ), Length( naPng ) ) ), 'splines.png' );
  Assert.AreEqual( Ord( JXL_SIG_NOT_ENOUGH_BYTES ), Ord( JxlSignatureCheck( PByte( naShort ), Length( naShort ) ) ), 'one byte' );

end;

procedure TTestJxlApi.Test_DecoderBasicInfo_Splines_ReportsDimensions;
begin

  JxlCheckLibrary;

  var naData   := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var pDecoder := JxlDecoderCreate( nil );
  Assert.IsTrue( Assigned( pDecoder ), 'JxlDecoderCreate' );

  try
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) ) ), 'SubscribeEvents' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderSetInput( pDecoder, PByte( naData ), Length( naData ) ) ), 'SetInput' );
    JxlDecoderCloseInput( pDecoder );
    Assert.AreEqual( Ord( JXL_DEC_BASIC_INFO ), Ord( JxlDecoderProcessInput( pDecoder ) ), 'ProcessInput' );

    var rInfo := Default( JxlBasicInfo );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( JxlDecoderGetBasicInfo( pDecoder, @rInfo ) ), 'GetBasicInfo' );
    Assert.AreEqual( 2048, Integer( rInfo.xsize ), 'xsize' );
    Assert.AreEqual( 2048, Integer( rInfo.ysize ), 'ysize' );
    Assert.AreEqual( 3, Integer( rInfo.num_color_channels ), 'num_color_channels' );
    Assert.AreEqual( 0, Integer( rInfo.alpha_bits ), 'alpha_bits' );
    Assert.AreEqual( JXL_FALSE, rInfo.have_container, 'have_container' );
    Assert.AreEqual( Ord( JXL_ORIENT_IDENTITY ), Ord( rInfo.orientation ), 'orientation' );
  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

procedure TTestJxlApi.Test_EncoderInitBasicInfo_FillsDefaultsAtCOffsets;
begin

  JxlCheckLibrary;

  var rInfo: JxlBasicInfo;
  FillChar( rInfo, SizeOf( rInfo ), $AA );
  JxlEncoderInitBasicInfo( @rInfo );
  Assert.AreEqual( 8, Integer( rInfo.bits_per_sample ), 'bits_per_sample' );
  Assert.AreEqual( Ord( JXL_ORIENT_IDENTITY ), Ord( rInfo.orientation ), 'orientation' );
  Assert.AreEqual( 3, Integer( rInfo.num_color_channels ), 'num_color_channels' );
  Assert.AreEqual( 0, Integer( rInfo.intrinsic_ysize ), 'intrinsic_ysize' );
  Assert.AreEqual( 10, Integer( rInfo.animation.tps_numerator ), 'animation.tps_numerator' );
  Assert.AreEqual( 1, Integer( rInfo.animation.tps_denominator ), 'animation.tps_denominator' );
  Assert.AreEqual( JXL_FALSE, rInfo.animation.have_timecodes, 'animation.have_timecodes' );
  Assert.AreEqual( $AA, Integer( rInfo.padding[ 0 ] ), 'padding[0] must be untouched' );
  Assert.AreEqual( $AA, Integer( rInfo.padding[ 99 ] ), 'padding[99] must be untouched' );

end;

procedure TTestJxlApi.Test_ColorEncodingSetToSRGB_FillsSrgbFields;
begin

  JxlCheckLibrary;

  var rColour: JxlColorEncoding;
  FillChar( rColour, SizeOf( rColour ), $55 );
  JxlColorEncodingSetToSRGB( @rColour, JXL_FALSE );
  Assert.AreEqual( Ord( JXL_COLOR_SPACE_RGB ), Ord( rColour.color_space ), 'color_space' );
  Assert.AreEqual( Ord( JXL_WHITE_POINT_D65 ), Ord( rColour.white_point ), 'white_point' );
  Assert.AreEqual( 0.3127, rColour.white_point_xy[ 0 ], 0.0001, 'white_point_xy[0]' );
  Assert.AreEqual( 0.3290, rColour.white_point_xy[ 1 ], 0.0001, 'white_point_xy[1]' );
  Assert.AreEqual( Ord( JXL_PRIMARIES_SRGB ), Ord( rColour.primaries ), 'primaries' );
  Assert.AreEqual( Ord( JXL_TRANSFER_FUNCTION_SRGB ), Ord( rColour.transfer_function ), 'transfer_function' );
  Assert.AreEqual( Ord( JXL_RENDERING_INTENT_RELATIVE ), Ord( rColour.rendering_intent ), 'rendering_intent' );

end;

procedure TTestJxlApi.Test_ThreadRunners_RunParallelJob_EveryValueOnce;
var
  rProbe: TRunnerProbe;
begin

  JxlCheckLibrary;

  var iSuggested := JxlResizableParallelRunnerSuggestThreads( 2048, 2048 );
  Assert.IsTrue( iSuggested >= 1, Format( 'SuggestThreads returned %d', [ iSuggested ] ) );

  var pResizable := JxlResizableParallelRunnerCreate( nil );
  Assert.IsTrue( Assigned( pResizable ), 'JxlResizableParallelRunnerCreate' );

  try
    JxlResizableParallelRunnerSetThreads( pResizable, 4 );
    rProbe := Default( TRunnerProbe );
    SetLength( rProbe.Values, RUN_END + 10 );
    AssertProbe( rProbe, JxlResizableParallelRunner( pResizable, @rProbe, ProbeInit, ProbeRun, RUN_START, RUN_END ),
      'resizable runner' );
    Assert.AreNotEqual( JXL_PARALLEL_RET_SUCCESS, JxlResizableParallelRunner( pResizable, @rProbe, FailingInit, ProbeRun,
      RUN_START, RUN_END ), 'resizable runner with a failing init' );
  finally
    JxlResizableParallelRunnerDestroy( pResizable );
  end;

  var iWorkers := JxlThreadParallelRunnerDefaultNumWorkerThreads;
  Assert.IsTrue( iWorkers >= 1, Format( 'DefaultNumWorkerThreads returned %d', [ iWorkers ] ) );

  var pFixed := JxlThreadParallelRunnerCreate( nil, 4 );
  Assert.IsTrue( Assigned( pFixed ), 'JxlThreadParallelRunnerCreate' );

  try
    rProbe := Default( TRunnerProbe );
    SetLength( rProbe.Values, RUN_END + 10 );
    AssertProbe( rProbe, JxlThreadParallelRunner( pFixed, @rProbe, ProbeInit, ProbeRun, RUN_START, RUN_END ), 'thread runner' );
    Assert.AreNotEqual( JXL_PARALLEL_RET_SUCCESS, JxlThreadParallelRunner( pFixed, @rProbe, FailingInit, ProbeRun, RUN_START,
      RUN_END ), 'thread runner with a failing init' );
  finally
    JxlThreadParallelRunnerDestroy( pFixed );
  end;

end;

procedure TTestJxlApi.Test_DefaultCms_ConvertsLinearToSrgb;
var
  iSample: Byte;
begin

  JxlCheckLibrary;

  var eOldMask := SetExceptionMask( exAllArithmeticExceptions );

  try
    var naJxl := EncodeLinearGrey128;
    Assert.AreEqual( Ord( JXL_DEC_ERROR ), Ord( DecodeAsSrgb( naJxl, False, iSample ) ),
      'without a CMS libjxl must refuse the sRGB output profile' );
    Assert.AreEqual( Ord( JXL_DEC_SUCCESS ), Ord( DecodeAsSrgb( naJxl, True, iSample ) ),
      'with the default CMS the sRGB output profile is accepted' );
    Assert.IsTrue( ( iSample >= 187 ) and ( iSample <= 189 ), Format( 'linear 128 became %d in sRGB, expected 188', [ iSample ] ) );
  finally
    SetExceptionMask( eOldMask );
  end;

end;

procedure TTestJxlApi.Test_LibraryAvailable_RealDllsTrue_SeamsReportFaults;
begin

  Assert.IsTrue( JxlLibraryAvailable, 'JxlLibraryAvailable' );
  Assert.IsTrue( JxlModuleAvailable( JXL_LIBRARY ), JXL_LIBRARY );
  Assert.WillNotRaiseAny( procedure begin JxlCheckLibrary; end, 'JxlCheckLibrary' );

  // The cases JxlLibraryAvailable reports as False, through the checks it is built on.
  Assert.AreEqual( Length( JXL_DECODE_EXPORTS ), Length( JxlFindMissingExports( GetModuleHandle( kernel32 ), JXL_DECODE_EXPORTS ) ),
    'a module that is not libjxl lacks every export' );
  Assert.WillRaise( procedure begin JxlCheckVersion( JXL_MIN_VERSION - 1 ); end, EJxlError, 'a version below the minimum' );

end;

procedure TTestJxlApi.Test_CheckModule_MissingDll_RaisesEJxlError;
var
  sApiName: string;
  iStatus: Integer;
  sMessage: string;
begin

  Assert.IsFalse( JxlModuleAvailable( MISSING_DLL ), 'JxlModuleAvailable' );

  sApiName := '';
  iStatus  := 0;
  sMessage := '';

  try
    JxlCheckModule( MISSING_DLL );
    Assert.Fail( 'JxlCheckModule did not raise for a missing DLL' );
  except
    on E: EJxlError do
    begin
      sApiName := E.ApiName;
      iStatus  := E.Status;
      sMessage := E.Message;
    end;
  end;

  Assert.AreEqual( 'LoadLibraryEx', sApiName, False, 'ApiName' );
  Assert.AreEqual( 126, iStatus, 'Status (ERROR_MOD_NOT_FOUND)' );
  Assert.IsTrue( Pos( MISSING_DLL, sMessage ) > 0, 'the message names the DLL' );
  Assert.IsTrue( Pos( 'never from the current directory or PATH', sMessage ) > 0, 'the message states the search rule' );

end;

procedure TTestJxlApi.Test_ExportTables_MatchImportDeclarations;
begin

  var oDeclaration := TRegEx.Create( '\b(?:function|procedure)\s+(\w+)(?:(?!\b(?:function|procedure)\b).)*?external\s+(\w+)\s+delayed',
    [ roSingleLine ] );
  var iTotal := 0;

  for var rCase in TArray<TArray<string>>.Create(
    TArray<string>.Create( 'Jxl.Api.Types.pas', 'JXL_LIBRARY', string.Join( ',', JXL_STATS_EXPORTS ) ),
    TArray<string>.Create( 'Jxl.Api.Decode.pas', 'JXL_LIBRARY', string.Join( ',', JXL_DECODE_EXPORTS ) ),
    TArray<string>.Create( 'Jxl.Api.Encode.pas', 'JXL_LIBRARY', string.Join( ',', JXL_ENCODE_EXPORTS ) ),
    TArray<string>.Create( 'Jxl.Api.Threads.pas', 'JXL_THREADS_LIBRARY', string.Join( ',', JXL_THREADS_EXPORTS ) ),
    TArray<string>.Create( 'Jxl.Api.Cms.pas', 'JXL_CMS_LIBRARY', string.Join( ',', JXL_CMS_EXPORTS ) ) ) do
  begin
    var sSource   := TRegEx.Replace( TFile.ReadAllText( TPath.Combine( BindingSourceFolder, rCase[ 0 ] ) ), '//[^\r\n]*', '' );
    var asTable   := rCase[ 2 ].Split( [ ',' ] );
    var oDeclared := TList<string>.Create;

    try
      for var oMatch in oDeclaration.Matches( sSource ) do
      begin
        Assert.AreEqual( rCase[ 1 ], oMatch.Groups[ 2 ].Value, False, Format( '%s: library of %s', [ rCase[ 0 ],
          oMatch.Groups[ 1 ].Value ] ) );
        oDeclared.Add( oMatch.Groups[ 1 ].Value );
      end;

      Assert.AreEqual( oDeclared.Count, Length( asTable ), Format( '%s: imports declared vs listed in its table', [ rCase[ 0 ] ] ) );

      for var sName in oDeclared do
        Assert.IsTrue( TArray.IndexOf<string>( asTable, sName ) >= 0, Format( '%s: %s is imported but not in the export table',
          [ rCase[ 0 ], sName ] ) );

      Inc( iTotal, oDeclared.Count );
    finally
      oDeclared.Free;
    end;

  end;

  Assert.AreEqual( 115, iTotal, 'functions bound in all (README: 52 + 49 + 4 + 9 + 1)' );

end;

procedure TTestJxlApi.Test_FindMissingExports_ReportsOnlyMissingNames;
begin

  JxlCheckLibrary;

  var hJxl := GetModuleHandle( JXL_LIBRARY );
  Assert.IsTrue( hJxl <> 0, 'the verified DLL is loaded' );
  Assert.AreEqual( 0, Length( JxlFindMissingExports( hJxl, JXL_DECODE_EXPORTS ) ), 'decode exports' );
  Assert.AreEqual( 0, Length( JxlFindMissingExports( hJxl, JXL_ENCODE_EXPORTS ) ), 'encode exports' );
  Assert.AreEqual( 0, Length( JxlFindMissingExports( hJxl, JXL_STATS_EXPORTS ) ), 'stats exports' );
  // A single self-contained DLL exports the thread runners and the CMS itself; the split build has a DLL for each.
  var bSingle  := ( JxlLibraryLayout = jllSingleDll );
  var hThreads := if bSingle then hJxl else GetModuleHandle( JXL_THREADS_LIBRARY );
  var hCms     := if bSingle then hJxl else GetModuleHandle( JXL_CMS_LIBRARY );
  Assert.IsTrue( ( hThreads <> 0 ) and ( hCms <> 0 ), 'the verified thread-runner and CMS modules are loaded' );
  Assert.AreEqual( 0, Length( JxlFindMissingExports( hThreads, JXL_THREADS_EXPORTS ) ), 'thread exports' );
  Assert.AreEqual( 0, Length( JxlFindMissingExports( hCms, JXL_CMS_EXPORTS ) ), 'CMS exports' );

  var asMissing := JxlFindMissingExports( hJxl, [ 'JxlDecoderVersion', 'JxlBindingTestNoSuchExport', 'JxlEncoderVersion' ] );
  Assert.AreEqual( 1, Length( asMissing ), 'one invented name' );
  Assert.AreEqual( 'JxlBindingTestNoSuchExport', asMissing[ 0 ], False, 'the invented name is the one reported' );
  Assert.AreEqual( Length( JXL_DECODE_EXPORTS ), Length( JxlFindMissingExports( GetModuleHandle( kernel32 ), JXL_DECODE_EXPORTS ) ),
    'kernel32 exports none of them' );

end;

procedure TTestJxlApi.Test_CheckVersion_RejectsOlderThanMinimum;
var
  iStatus: Integer;
begin

  AssertJxlError( procedure begin JxlCheckVersion( 11999, 'C:\old\jxl.dll' ); end, 'JxlDecoderVersion', False,
    'C:\old\jxl.dll is libjxl 0.11.999; the binding needs 0.12.0 or later', 'version 0.11.999' );

  iStatus := 0;

  try
    JxlCheckVersion( 11999 );
  except
    on E: EJxlError do iStatus := E.Status;
  end;

  Assert.AreEqual( 11999, iStatus, 'Status holds the version found' );
  Assert.AreEqual( 12000, Integer( JXL_MIN_VERSION ), 'the minimum is 0.12.0' );
  Assert.WillNotRaiseAny( procedure begin JxlCheckVersion( 12000 ); end, '0.12.0' );
  Assert.WillNotRaiseAny( procedure begin JxlCheckVersion( 12001 ); end, '0.12.1' );
  Assert.WillNotRaiseAny( procedure begin JxlCheckVersion( 13000 ); end, '0.13.0' );
  Assert.WillNotRaiseAny( procedure begin JxlCheckVersion( 1000000 ); end, '1.0.0' );

end;

procedure TTestJxlApi.Test_ModuleLoading_IgnoresCurrentDirectory;
begin

  var sExeFolder := ExtractFilePath( ParamStr( 0 ) );
  var asFolders  := JxlLibraryDirectories;
  Assert.IsTrue( Length( asFolders ) >= 1, 'at least one folder' );
  Assert.AreEqual( sExeFolder, asFolders[ 0 ], True, 'the binding is linked into the executable, so its folder comes first' );

  var sTemp := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-cwd-' + TGUID.NewGuid.ToString );
  var sCopy := TPath.Combine( sTemp, 'jxl_cwd_probe.dll' );
  TDirectory.CreateDirectory( sTemp );
  TFile.Copy( TPath.Combine( sExeFolder, JXL_LIBRARY ), sCopy );

  var sOldFolder := GetCurrentDir;
  SetCurrentDir( sTemp );

  try
    for var sFolder in JxlLibraryDirectories do
      Assert.AreNotEqual( IncludeTrailingPathDelimiter( sTemp ), sFolder, True, 'the current directory is not a search folder' );

    Assert.IsFalse( JxlModuleAvailable( 'jxl_cwd_probe.dll' ), 'a DLL only in the current directory must not be loaded' );
    Assert.IsTrue( JxlModuleAvailable( sCopy ), 'the same DLL loads by full path' );
  finally
    SetCurrentDir( sOldFolder );
    TDirectory.Delete( sTemp, True );
  end;

end;

procedure TTestJxlApi.Test_MemoryBudget_RefusesOverLimitAndBalances;
var
  rBudget: TJxlMemoryBudget;
begin

  rBudget.Init( 1000 );

  var rManager := rBudget.Manager;
  var pFirst   := rManager.alloc( rManager.opaque, 600 );
  Assert.IsTrue( Assigned( pFirst ), 'a block within the limit' );
  Assert.AreEqual( Int64( 600 ), rBudget.Used, 'Used after the first block' );
  FillChar( pFirst^, 600, $5A );
  Assert.IsFalse( Assigned( rManager.alloc( rManager.opaque, 401 ) ), 'a block taking the total over the limit is refused' );
  Assert.AreEqual( 1, rBudget.Refusals, 'Refusals' );
  Assert.AreEqual( Int64( 600 ), rBudget.Used, 'a refusal leaves Used unchanged' );

  var pSecond := rManager.alloc( rManager.opaque, 400 );
  Assert.IsTrue( Assigned( pSecond ), 'a block reaching the limit exactly' );
  Assert.AreEqual( Int64( 1000 ), rBudget.Peak, 'Peak' );
  rManager.free( rManager.opaque, pFirst );
  rManager.free( rManager.opaque, pSecond );
  rManager.free( rManager.opaque, nil );
  Assert.AreEqual( Int64( 0 ), rBudget.Used, 'Used after freeing everything' );
  Assert.AreEqual( Int64( 1000 ), rBudget.Peak, 'Peak survives the frees' );
  Assert.IsFalse( Assigned( rManager.alloc( rManager.opaque, High( NativeUInt ) ) ), 'an impossible size is refused' );
  Assert.AreEqual( 2, rBudget.Refusals, 'Refusals after the impossible size' );

  JxlCheckLibrary;

  var naData   := TFile.ReadAllBytes( TestDataFile( 'splines.jxl' ) );
  var eOldMask := SetExceptionMask( exAllArithmeticExceptions );

  try
    rBudget.Init( 1024 * 1024 );
    Assert.AreNotEqual( Ord( JXL_DEC_FULL_IMAGE ), Ord( DecodeThroughManager( naData, rBudget.Manager ) ),
      'a 1 MB budget cannot decode a 2048 x 2048 image' );
    Assert.IsTrue( rBudget.Refusals > 0, 'the budget refused allocations' );
    Assert.AreEqual( Int64( 0 ), rBudget.Used, 'nothing is left allocated after the failed decode' );

    rBudget.Init( Int64( 1 ) shl 30 );
    Assert.AreEqual( Ord( JXL_DEC_FULL_IMAGE ), Ord( DecodeThroughManager( naData, rBudget.Manager ) ), 'a 1 GiB budget decodes it' );
    Assert.AreEqual( 0, rBudget.Refusals, 'no refusals under 1 GiB' );
    Assert.IsTrue( rBudget.Peak > 1024 * 1024, Format( 'libjxl allocated through the budget (peak %d)', [ rBudget.Peak ] ) );
    Assert.AreEqual( Int64( 0 ), rBudget.Used, 'nothing is left allocated after the decode' );
  finally
    SetExceptionMask( eOldMask );
  end;

end;

procedure TTestJxlApi.ExpectValue( const AName: string; AActual: Int64; AExpected: Int64 );
begin

  if ( AActual <> AExpected ) then
    FMismatches := FMismatches + Format( '%s = %d, C has %d%s', [ AName, AActual, AExpected, sLineBreak ] );

end;

procedure TTestJxlApi.Test_EnumValues_Types_MatchCHeaders;
begin

  ExpectValue( 'JXL_TYPE_FLOAT', Ord( JXL_TYPE_FLOAT ), 0 );
  ExpectValue( 'JXL_TYPE_UINT8', Ord( JXL_TYPE_UINT8 ), 2 );
  ExpectValue( 'JXL_TYPE_UINT16', Ord( JXL_TYPE_UINT16 ), 3 );
  ExpectValue( 'JXL_TYPE_FLOAT16', Ord( JXL_TYPE_FLOAT16 ), 5 );
  ExpectValue( 'JXL_NATIVE_ENDIAN', Ord( JXL_NATIVE_ENDIAN ), 0 );
  ExpectValue( 'JXL_LITTLE_ENDIAN', Ord( JXL_LITTLE_ENDIAN ), 1 );
  ExpectValue( 'JXL_BIG_ENDIAN', Ord( JXL_BIG_ENDIAN ), 2 );
  ExpectValue( 'JXL_BIT_DEPTH_FROM_PIXEL_FORMAT', Ord( JXL_BIT_DEPTH_FROM_PIXEL_FORMAT ), 0 );
  ExpectValue( 'JXL_BIT_DEPTH_FROM_CODESTREAM', Ord( JXL_BIT_DEPTH_FROM_CODESTREAM ), 1 );
  ExpectValue( 'JXL_BIT_DEPTH_CUSTOM', Ord( JXL_BIT_DEPTH_CUSTOM ), 2 );
  ExpectValue( 'JXL_ORIENT_IDENTITY', Ord( JXL_ORIENT_IDENTITY ), 1 );
  ExpectValue( 'JXL_ORIENT_FLIP_HORIZONTAL', Ord( JXL_ORIENT_FLIP_HORIZONTAL ), 2 );
  ExpectValue( 'JXL_ORIENT_ROTATE_180', Ord( JXL_ORIENT_ROTATE_180 ), 3 );
  ExpectValue( 'JXL_ORIENT_FLIP_VERTICAL', Ord( JXL_ORIENT_FLIP_VERTICAL ), 4 );
  ExpectValue( 'JXL_ORIENT_TRANSPOSE', Ord( JXL_ORIENT_TRANSPOSE ), 5 );
  ExpectValue( 'JXL_ORIENT_ROTATE_90_CW', Ord( JXL_ORIENT_ROTATE_90_CW ), 6 );
  ExpectValue( 'JXL_ORIENT_ANTI_TRANSPOSE', Ord( JXL_ORIENT_ANTI_TRANSPOSE ), 7 );
  ExpectValue( 'JXL_ORIENT_ROTATE_90_CCW', Ord( JXL_ORIENT_ROTATE_90_CCW ), 8 );
  ExpectValue( 'JXL_CHANNEL_ALPHA', Ord( JXL_CHANNEL_ALPHA ), 0 );
  ExpectValue( 'JXL_CHANNEL_DEPTH', Ord( JXL_CHANNEL_DEPTH ), 1 );
  ExpectValue( 'JXL_CHANNEL_SPOT_COLOR', Ord( JXL_CHANNEL_SPOT_COLOR ), 2 );
  ExpectValue( 'JXL_CHANNEL_SELECTION_MASK', Ord( JXL_CHANNEL_SELECTION_MASK ), 3 );
  ExpectValue( 'JXL_CHANNEL_BLACK', Ord( JXL_CHANNEL_BLACK ), 4 );
  ExpectValue( 'JXL_CHANNEL_CFA', Ord( JXL_CHANNEL_CFA ), 5 );
  ExpectValue( 'JXL_CHANNEL_THERMAL', Ord( JXL_CHANNEL_THERMAL ), 6 );
  ExpectValue( 'JXL_CHANNEL_RESERVED0', Ord( JXL_CHANNEL_RESERVED0 ), 7 );
  ExpectValue( 'JXL_CHANNEL_RESERVED1', Ord( JXL_CHANNEL_RESERVED1 ), 8 );
  ExpectValue( 'JXL_CHANNEL_RESERVED2', Ord( JXL_CHANNEL_RESERVED2 ), 9 );
  ExpectValue( 'JXL_CHANNEL_RESERVED3', Ord( JXL_CHANNEL_RESERVED3 ), 10 );
  ExpectValue( 'JXL_CHANNEL_RESERVED4', Ord( JXL_CHANNEL_RESERVED4 ), 11 );
  ExpectValue( 'JXL_CHANNEL_RESERVED5', Ord( JXL_CHANNEL_RESERVED5 ), 12 );
  ExpectValue( 'JXL_CHANNEL_RESERVED6', Ord( JXL_CHANNEL_RESERVED6 ), 13 );
  ExpectValue( 'JXL_CHANNEL_RESERVED7', Ord( JXL_CHANNEL_RESERVED7 ), 14 );
  ExpectValue( 'JXL_CHANNEL_UNKNOWN', Ord( JXL_CHANNEL_UNKNOWN ), 15 );
  ExpectValue( 'JXL_CHANNEL_OPTIONAL', Ord( JXL_CHANNEL_OPTIONAL ), 16 );
  ExpectValue( 'JXL_BLEND_REPLACE', Ord( JXL_BLEND_REPLACE ), 0 );
  ExpectValue( 'JXL_BLEND_ADD', Ord( JXL_BLEND_ADD ), 1 );
  ExpectValue( 'JXL_BLEND_BLEND', Ord( JXL_BLEND_BLEND ), 2 );
  ExpectValue( 'JXL_BLEND_MULADD', Ord( JXL_BLEND_MULADD ), 3 );
  ExpectValue( 'JXL_BLEND_MUL', Ord( JXL_BLEND_MUL ), 4 );
  ExpectValue( 'JXL_COLOR_SPACE_RGB', Ord( JXL_COLOR_SPACE_RGB ), 0 );
  ExpectValue( 'JXL_COLOR_SPACE_GRAY', Ord( JXL_COLOR_SPACE_GRAY ), 1 );
  ExpectValue( 'JXL_COLOR_SPACE_XYB', Ord( JXL_COLOR_SPACE_XYB ), 2 );
  ExpectValue( 'JXL_COLOR_SPACE_UNKNOWN', Ord( JXL_COLOR_SPACE_UNKNOWN ), 3 );
  ExpectValue( 'JXL_WHITE_POINT_D65', Ord( JXL_WHITE_POINT_D65 ), 1 );
  ExpectValue( 'JXL_WHITE_POINT_CUSTOM', Ord( JXL_WHITE_POINT_CUSTOM ), 2 );
  ExpectValue( 'JXL_WHITE_POINT_E', Ord( JXL_WHITE_POINT_E ), 10 );
  ExpectValue( 'JXL_WHITE_POINT_DCI', Ord( JXL_WHITE_POINT_DCI ), 11 );
  ExpectValue( 'JXL_PRIMARIES_SRGB', Ord( JXL_PRIMARIES_SRGB ), 1 );
  ExpectValue( 'JXL_PRIMARIES_CUSTOM', Ord( JXL_PRIMARIES_CUSTOM ), 2 );
  ExpectValue( 'JXL_PRIMARIES_2100', Ord( JXL_PRIMARIES_2100 ), 9 );
  ExpectValue( 'JXL_PRIMARIES_P3', Ord( JXL_PRIMARIES_P3 ), 11 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_709', Ord( JXL_TRANSFER_FUNCTION_709 ), 1 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_UNKNOWN', Ord( JXL_TRANSFER_FUNCTION_UNKNOWN ), 2 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_LINEAR', Ord( JXL_TRANSFER_FUNCTION_LINEAR ), 8 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_SRGB', Ord( JXL_TRANSFER_FUNCTION_SRGB ), 13 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_PQ', Ord( JXL_TRANSFER_FUNCTION_PQ ), 16 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_DCI', Ord( JXL_TRANSFER_FUNCTION_DCI ), 17 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_HLG', Ord( JXL_TRANSFER_FUNCTION_HLG ), 18 );
  ExpectValue( 'JXL_TRANSFER_FUNCTION_GAMMA', Ord( JXL_TRANSFER_FUNCTION_GAMMA ), 65535 );
  ExpectValue( 'JXL_RENDERING_INTENT_PERCEPTUAL', Ord( JXL_RENDERING_INTENT_PERCEPTUAL ), 0 );
  ExpectValue( 'JXL_RENDERING_INTENT_RELATIVE', Ord( JXL_RENDERING_INTENT_RELATIVE ), 1 );
  ExpectValue( 'JXL_RENDERING_INTENT_SATURATION', Ord( JXL_RENDERING_INTENT_SATURATION ), 2 );
  ExpectValue( 'JXL_RENDERING_INTENT_ABSOLUTE', Ord( JXL_RENDERING_INTENT_ABSOLUTE ), 3 );
  ExpectValue( 'JXL_ENC_STAT_HEADER_BITS', Ord( JXL_ENC_STAT_HEADER_BITS ), 0 );
  ExpectValue( 'JXL_ENC_STAT_TOC_BITS', Ord( JXL_ENC_STAT_TOC_BITS ), 1 );
  ExpectValue( 'JXL_ENC_STAT_DICTIONARY_BITS', Ord( JXL_ENC_STAT_DICTIONARY_BITS ), 2 );
  ExpectValue( 'JXL_ENC_STAT_SPLINES_BITS', Ord( JXL_ENC_STAT_SPLINES_BITS ), 3 );
  ExpectValue( 'JXL_ENC_STAT_NOISE_BITS', Ord( JXL_ENC_STAT_NOISE_BITS ), 4 );
  ExpectValue( 'JXL_ENC_STAT_QUANT_BITS', Ord( JXL_ENC_STAT_QUANT_BITS ), 5 );
  ExpectValue( 'JXL_ENC_STAT_MODULAR_TREE_BITS', Ord( JXL_ENC_STAT_MODULAR_TREE_BITS ), 6 );
  ExpectValue( 'JXL_ENC_STAT_MODULAR_GLOBAL_BITS', Ord( JXL_ENC_STAT_MODULAR_GLOBAL_BITS ), 7 );
  ExpectValue( 'JXL_ENC_STAT_DC_BITS', Ord( JXL_ENC_STAT_DC_BITS ), 8 );
  ExpectValue( 'JXL_ENC_STAT_MODULAR_DC_GROUP_BITS', Ord( JXL_ENC_STAT_MODULAR_DC_GROUP_BITS ), 9 );
  ExpectValue( 'JXL_ENC_STAT_CONTROL_FIELDS_BITS', Ord( JXL_ENC_STAT_CONTROL_FIELDS_BITS ), 10 );
  ExpectValue( 'JXL_ENC_STAT_COEF_ORDER_BITS', Ord( JXL_ENC_STAT_COEF_ORDER_BITS ), 11 );
  ExpectValue( 'JXL_ENC_STAT_AC_HISTOGRAM_BITS', Ord( JXL_ENC_STAT_AC_HISTOGRAM_BITS ), 12 );
  ExpectValue( 'JXL_ENC_STAT_AC_BITS', Ord( JXL_ENC_STAT_AC_BITS ), 13 );
  ExpectValue( 'JXL_ENC_STAT_MODULAR_AC_GROUP_BITS', Ord( JXL_ENC_STAT_MODULAR_AC_GROUP_BITS ), 14 );
  ExpectValue( 'JXL_ENC_STAT_NUM_SMALL_BLOCKS', Ord( JXL_ENC_STAT_NUM_SMALL_BLOCKS ), 15 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT4X8_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT4X8_BLOCKS ), 16 );
  ExpectValue( 'JXL_ENC_STAT_NUM_AFV_BLOCKS', Ord( JXL_ENC_STAT_NUM_AFV_BLOCKS ), 17 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT8_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT8_BLOCKS ), 18 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT8X32_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT8X32_BLOCKS ), 19 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT16_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT16_BLOCKS ), 20 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT16X32_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT16X32_BLOCKS ), 21 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT32_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT32_BLOCKS ), 22 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT32X64_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT32X64_BLOCKS ), 23 );
  ExpectValue( 'JXL_ENC_STAT_NUM_DCT64_BLOCKS', Ord( JXL_ENC_STAT_NUM_DCT64_BLOCKS ), 24 );
  ExpectValue( 'JXL_ENC_STAT_NUM_BUTTERAUGLI_ITERS', Ord( JXL_ENC_STAT_NUM_BUTTERAUGLI_ITERS ), 25 );
  ExpectValue( 'JXL_ENC_NUM_STATS', Ord( JXL_ENC_NUM_STATS ), 26 );
  ExpectValue( 'JXL_TRUE', JXL_TRUE, 1 );
  ExpectValue( 'JXL_FALSE', JXL_FALSE, 0 );
  ExpectValue( 'JXL_PARALLEL_RET_SUCCESS', JXL_PARALLEL_RET_SUCCESS, 0 );
  ExpectValue( 'JXL_PARALLEL_RET_RUNNER_ERROR', JXL_PARALLEL_RET_RUNNER_ERROR, -1 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_EnumValues_Decode_MatchCHeaders;
begin

  ExpectValue( 'JXL_SIG_NOT_ENOUGH_BYTES', Ord( JXL_SIG_NOT_ENOUGH_BYTES ), 0 );
  ExpectValue( 'JXL_SIG_INVALID', Ord( JXL_SIG_INVALID ), 1 );
  ExpectValue( 'JXL_SIG_CODESTREAM', Ord( JXL_SIG_CODESTREAM ), 2 );
  ExpectValue( 'JXL_SIG_CONTAINER', Ord( JXL_SIG_CONTAINER ), 3 );
  ExpectValue( 'JXL_DEC_SUCCESS', Ord( JXL_DEC_SUCCESS ), 0 );
  ExpectValue( 'JXL_DEC_ERROR', Ord( JXL_DEC_ERROR ), 1 );
  ExpectValue( 'JXL_DEC_NEED_MORE_INPUT', Ord( JXL_DEC_NEED_MORE_INPUT ), 2 );
  ExpectValue( 'JXL_DEC_NEED_PREVIEW_OUT_BUFFER', Ord( JXL_DEC_NEED_PREVIEW_OUT_BUFFER ), 3 );
  ExpectValue( 'JXL_DEC_NEED_IMAGE_OUT_BUFFER', Ord( JXL_DEC_NEED_IMAGE_OUT_BUFFER ), 5 );
  ExpectValue( 'JXL_DEC_JPEG_NEED_MORE_OUTPUT', Ord( JXL_DEC_JPEG_NEED_MORE_OUTPUT ), 6 );
  ExpectValue( 'JXL_DEC_BOX_NEED_MORE_OUTPUT', Ord( JXL_DEC_BOX_NEED_MORE_OUTPUT ), 7 );
  ExpectValue( 'JXL_DEC_BASIC_INFO', Ord( JXL_DEC_BASIC_INFO ), 64 );
  ExpectValue( 'JXL_DEC_COLOR_ENCODING', Ord( JXL_DEC_COLOR_ENCODING ), 256 );
  ExpectValue( 'JXL_DEC_PREVIEW_IMAGE', Ord( JXL_DEC_PREVIEW_IMAGE ), 512 );
  ExpectValue( 'JXL_DEC_FRAME', Ord( JXL_DEC_FRAME ), 1024 );
  ExpectValue( 'JXL_DEC_FULL_IMAGE', Ord( JXL_DEC_FULL_IMAGE ), 4096 );
  ExpectValue( 'JXL_DEC_JPEG_RECONSTRUCTION', Ord( JXL_DEC_JPEG_RECONSTRUCTION ), 8192 );
  ExpectValue( 'JXL_DEC_BOX', Ord( JXL_DEC_BOX ), 16384 );
  ExpectValue( 'JXL_DEC_FRAME_PROGRESSION', Ord( JXL_DEC_FRAME_PROGRESSION ), 32768 );
  ExpectValue( 'JXL_DEC_BOX_COMPLETE', Ord( JXL_DEC_BOX_COMPLETE ), 65536 );
  ExpectValue( 'kFrames', Ord( kFrames ), 0 );
  ExpectValue( 'kDC', Ord( kDC ), 1 );
  ExpectValue( 'kLastPasses', Ord( kLastPasses ), 2 );
  ExpectValue( 'kPasses', Ord( kPasses ), 3 );
  ExpectValue( 'kDCProgressive', Ord( kDCProgressive ), 4 );
  ExpectValue( 'kDCGroups', Ord( kDCGroups ), 5 );
  ExpectValue( 'kGroups', Ord( kGroups ), 6 );
  ExpectValue( 'JXL_COLOR_PROFILE_TARGET_ORIGINAL', Ord( JXL_COLOR_PROFILE_TARGET_ORIGINAL ), 0 );
  ExpectValue( 'JXL_COLOR_PROFILE_TARGET_DATA', Ord( JXL_COLOR_PROFILE_TARGET_DATA ), 1 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_EnumValues_Encode_MatchCHeaders;
begin

  ExpectValue( 'JXL_ENC_SUCCESS', Ord( JXL_ENC_SUCCESS ), 0 );
  ExpectValue( 'JXL_ENC_ERROR', Ord( JXL_ENC_ERROR ), 1 );
  ExpectValue( 'JXL_ENC_NEED_MORE_OUTPUT', Ord( JXL_ENC_NEED_MORE_OUTPUT ), 2 );
  ExpectValue( 'JXL_ENC_ERR_OK', Ord( JXL_ENC_ERR_OK ), 0 );
  ExpectValue( 'JXL_ENC_ERR_GENERIC', Ord( JXL_ENC_ERR_GENERIC ), 1 );
  ExpectValue( 'JXL_ENC_ERR_OOM', Ord( JXL_ENC_ERR_OOM ), 2 );
  ExpectValue( 'JXL_ENC_ERR_JBRD', Ord( JXL_ENC_ERR_JBRD ), 3 );
  ExpectValue( 'JXL_ENC_ERR_BAD_INPUT', Ord( JXL_ENC_ERR_BAD_INPUT ), 4 );
  ExpectValue( 'JXL_ENC_ERR_NOT_SUPPORTED', Ord( JXL_ENC_ERR_NOT_SUPPORTED ), 128 );
  ExpectValue( 'JXL_ENC_ERR_API_USAGE', Ord( JXL_ENC_ERR_API_USAGE ), 129 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_EFFORT', Ord( JXL_ENC_FRAME_SETTING_EFFORT ), 0 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_DECODING_SPEED', Ord( JXL_ENC_FRAME_SETTING_DECODING_SPEED ), 1 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_RESAMPLING', Ord( JXL_ENC_FRAME_SETTING_RESAMPLING ), 2 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING', Ord( JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING ), 3 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED', Ord( JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED ), 4 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_PHOTON_NOISE', Ord( JXL_ENC_FRAME_SETTING_PHOTON_NOISE ), 5 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_NOISE', Ord( JXL_ENC_FRAME_SETTING_NOISE ), 6 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_DOTS', Ord( JXL_ENC_FRAME_SETTING_DOTS ), 7 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_PATCHES', Ord( JXL_ENC_FRAME_SETTING_PATCHES ), 8 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_EPF', Ord( JXL_ENC_FRAME_SETTING_EPF ), 9 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_GABORISH', Ord( JXL_ENC_FRAME_SETTING_GABORISH ), 10 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR', Ord( JXL_ENC_FRAME_SETTING_MODULAR ), 11 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE', Ord( JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE ), 12 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_GROUP_ORDER', Ord( JXL_ENC_FRAME_SETTING_GROUP_ORDER ), 13 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X', Ord( JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X ), 14 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y', Ord( JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y ), 15 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_RESPONSIVE', Ord( JXL_ENC_FRAME_SETTING_RESPONSIVE ), 16 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC', Ord( JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC ), 17 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC', Ord( JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC ), 18 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC', Ord( JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC ), 19 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT', Ord( JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT ), 20 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT', Ord( JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT ), 21 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_PALETTE_COLORS', Ord( JXL_ENC_FRAME_SETTING_PALETTE_COLORS ), 22 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_LOSSY_PALETTE', Ord( JXL_ENC_FRAME_SETTING_LOSSY_PALETTE ), 23 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM', Ord( JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM ), 24 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE', Ord( JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE ), 25 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE', Ord( JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE ), 26 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR', Ord( JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR ), 27 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT', Ord( JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT ), 28 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS', Ord( JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS ), 29 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL', Ord( JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL ), 30 );
  ExpectValue( 'JXL_ENC_FRAME_INDEX_BOX', Ord( JXL_ENC_FRAME_INDEX_BOX ), 31 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_BROTLI_EFFORT', Ord( JXL_ENC_FRAME_SETTING_BROTLI_EFFORT ), 32 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES', Ord( JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES ), 33 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_BUFFERING', Ord( JXL_ENC_FRAME_SETTING_BUFFERING ), 34 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF', Ord( JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF ), 35 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP', Ord( JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP ), 36 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF', Ord( JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF ), 37 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_USE_FULL_IMAGE_HEURISTICS', Ord( JXL_ENC_FRAME_SETTING_USE_FULL_IMAGE_HEURISTICS ), 38 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_DISABLE_PERCEPTUAL_HEURISTICS', Ord( JXL_ENC_FRAME_SETTING_DISABLE_PERCEPTUAL_HEURISTICS ), 39 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_OUTPUT_MODE', Ord( JXL_ENC_FRAME_SETTING_OUTPUT_MODE ), 40 );
  ExpectValue( 'JXL_ENC_FRAME_SETTING_FILL_ENUM', Ord( JXL_ENC_FRAME_SETTING_FILL_ENUM ), 65535 );
  AssertNoMismatches;

end;

procedure TTestJxlApi.Test_VersionToString_SplitsFields;
begin

  Assert.AreEqual( '0.13.0', JxlVersionToString( 13000 ), False );
  Assert.AreEqual( '1.2.3', JxlVersionToString( 1002003 ), False );
  Assert.AreEqual( '12.345.678', JxlVersionToString( 12345678 ), False );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlApi );

end.
