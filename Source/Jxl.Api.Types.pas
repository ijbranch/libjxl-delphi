(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Delphi import of the libjxl common C API: <c>jxl/types.h</c>, <c>codestream_header.h</c>, <c>color_encoding.h</c>,
///   <c>memory_manager.h</c>, <c>parallel_runner.h</c>, <c>cms_interface.h</c>, <c>stats.h</c>, <c>gain_map.h</c> and
///   <c>compressed_icc.h</c>, plus the library-availability checks and <see cref="EJxlError" /> shared by every unit
///   of the binding.
/// </summary>
/// <remarks>
///   Names mirror the C headers exactly so that an upstream header change maps line for line. Every record has C
///   natural alignment and every enum is 4 bytes, matching MSVC / clang-cl on Win32 and Win64; the DUnitX suite
///   asserts each size against numbers measured from the C headers. Functions are <c>cdecl</c> and delay-loaded, so
///   the program starts without the DLL, but a missing DLL or export is fatal at the first call: on Win64 the delay
///   loader then ends the process with no exception to catch. Call <see cref="JxlCheckLibrary" /> before the first
///   call: it loads the DLL from a safe folder only (never the current directory or <c>PATH</c>), verifies that it
///   exports every imported function and is recent enough, and raises <see cref="EJxlError" /> otherwise. The
///   high-level routines of <c>Jxl.Graphic</c> call it themselves.
/// </remarks>
unit Jxl.Api.Types;

{$ALIGN 8}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils;

const
  /// <summary>
  ///   File name of the DLL exporting the encoder, decoder and statistics functions. The three library names follow
  ///   upstream's shared Windows build (<c>jxl.dll</c>, <c>jxl_threads.dll</c>, <c>jxl_cms.dll</c>); a single
  ///   self-contained <c>jxl.dll</c> that also exports the thread runners and the CMS is detected at run time by
  ///   <c>JxlCheckLibrary</c>, so either layout works without recompiling.
  /// </summary>
  JXL_LIBRARY = 'jxl.dll';
  /// <summary>
  ///   File name of the DLL exporting the thread runners (<c>jxl/thread_parallel_runner.h</c>,
  ///   <c>resizable_parallel_runner.h</c>) in upstream's shared build; not needed when <see cref="JXL_LIBRARY" />
  ///   exports them itself.
  /// </summary>
  JXL_THREADS_LIBRARY = 'jxl_threads.dll';
  /// <summary>
  ///   File name of the DLL exporting <c>JxlGetDefaultCms</c> in upstream's shared build; not needed when
  ///   <see cref="JXL_LIBRARY" /> exports it itself.
  /// </summary>
  JXL_CMS_LIBRARY = 'jxl_cms.dll';

  /// <summary>Major version of the libjxl headers this binding was written against (<c>JPEGXL_MAJOR_VERSION</c>).</summary>
  JPEGXL_MAJOR_VERSION = 0;
  /// <summary>Minor version of the libjxl headers this binding was written against (<c>JPEGXL_MINOR_VERSION</c>).</summary>
  JPEGXL_MINOR_VERSION = 12;
  /// <summary>Patch version of the libjxl headers this binding was written against (<c>JPEGXL_PATCH_VERSION</c>).</summary>
  JPEGXL_PATCH_VERSION = 0;
  /// <summary>
  ///   Oldest libjxl version (as <c>JxlDecoderVersion</c> reports it: MAJOR * 1000000 + MINOR * 1000 + PATCH) the
  ///   binding accepts: 0.12.0, the release whose headers it mirrors and whose DLLs export every function it imports.
  /// </summary>
  JXL_MIN_VERSION = 12000;

  /// <summary>Portable <c>true</c> value of <see cref="JXL_BOOL" />.</summary>
  JXL_TRUE = 1;
  /// <summary>Portable <c>false</c> value of <see cref="JXL_BOOL" />.</summary>
  JXL_FALSE = 0;

  /// <summary>Code returned by a <see cref="JxlParallelRunInit" /> callback to indicate success.</summary>
  JXL_PARALLEL_RET_SUCCESS = 0;
  /// <summary>Code returned by a <see cref="JxlParallelRunInit" /> callback or a runner to indicate a general error.</summary>
  JXL_PARALLEL_RET_RUNNER_ERROR = -1;

type
  /// <summary>
  ///   Raised by the binding's checked routines when a libjxl call does not succeed, a libjxl DLL cannot be loaded or
  ///   verified, or a check the binding makes itself (input size, resource limits, data structure) fails.
  /// </summary>
  /// <remarks>
  ///   Two forms. A failed C call (<see cref="IsBindingCheck" /> is <c>False</c>): <see cref="ApiName" /> names the
  ///   C or Windows function that failed and <see cref="Status" /> holds what it returned (a <c>JxlDecoderStatus</c>,
  ///   <c>JxlEncoderStatus</c> or <c>JxlEncoderError</c> value, or a Windows error code for <c>LoadLibraryEx</c> and
  ///   <c>GetProcAddress</c>). A binding check (<see cref="IsBindingCheck" /> is <c>True</c>): <see cref="ApiName" />
  ///   names the Pascal routine that found the fault, no C function failed, and <see cref="Status" /> is 0 unless that
  ///   routine documents a code.
  /// </remarks>
  EJxlError = class( Exception )
  private
    /// <summary>Name of the C function that failed, or of the binding routine that made the failed check.</summary>
    FApiName: string;
    /// <summary>Status code the C function returned; for a binding check 0 unless the routine documents a code.</summary>
    FStatus: Integer;
    /// <summary>Whether the binding itself found the fault rather than a C function reporting it.</summary>
    FBindingCheck: Boolean;
  public
    /// <summary>Creates the exception for a failed C call.</summary>
    /// <param name="AApiName">Name of the failing C function, e.g. <c>JxlDecoderProcessInput</c>.</param>
    /// <param name="AStatus">Status code the function returned.</param>
    /// <param name="ADetail">Optional explanation appended to the message.</param>
    constructor CreateStatus( const AApiName: string; AStatus: Integer; const ADetail: string = '' );
    /// <summary>Creates the exception for a check the binding made itself; no C function failed.</summary>
    /// <param name="ARoutineName">Name of the Pascal routine that made the check, e.g. <c>JxlReadInfo</c>.</param>
    /// <param name="ADetail">What was wrong.</param>
    /// <param name="AStatus">Optional code the routine documents; 0 by default.</param>
    constructor CreateCheck( const ARoutineName: string; const ADetail: string; AStatus: Integer = 0 );
    /// <summary>Name of the C function that failed, or, for a binding check, of the Pascal routine that made it.</summary>
    property ApiName: string read FApiName;
    /// <summary>Status code the C function returned; for a binding check 0 unless the routine documents a code.</summary>
    property Status: Integer read FStatus;
    /// <summary>
    ///   <c>True</c> when the binding found the fault itself (a resource limit, empty or malformed input, an exception
    ///   escaping from libjxl), so <see cref="ApiName" /> is a Pascal routine and not a failed C function.
    /// </summary>
    property IsBindingCheck: Boolean read FBindingCheck;
  end;

  /// <summary>
  ///   C <c>JXL_BOOL</c>: a C <c>int</c> whose only values are <see cref="JXL_TRUE" /> and <see cref="JXL_FALSE" />.
  /// </summary>
  JXL_BOOL = Integer;
  /// <summary>Pointer to a <see cref="JXL_BOOL" />.</summary>
  PJXL_BOOL = ^JXL_BOOL;
  /// <summary>Pointer to a byte pointer, the C <c>uint8_t**</c> used for output buffers.</summary>
  PPByte = ^PByte;

  { types.h }

  /// <summary>Data type for the sample values per channel per pixel.</summary>
  /// <remarks>
  ///   <c>JXL_TYPE_FLOAT</c>: 32-bit float, nominal range 0.0-1.0 (recommended for HDR and wide gamut);
  ///   <c>JXL_TYPE_UINT8</c>: <c>uint8_t</c>; <c>JXL_TYPE_UINT16</c>: <c>uint16_t</c>; <c>JXL_TYPE_FLOAT16</c>: IEEE 754
  ///   half-precision float. The integer types may clip wide-gamut data.
  /// </remarks>
  JxlDataType = (
    JXL_TYPE_FLOAT = 0,
    JXL_TYPE_UINT8 = 2,
    JXL_TYPE_UINT16 = 3,
    JXL_TYPE_FLOAT16 = 5
  );

  /// <summary>Ordering of multi-byte data.</summary>
  /// <remarks>
  ///   <c>JXL_NATIVE_ENDIAN</c>: the system's endianness; <c>JXL_LITTLE_ENDIAN</c> / <c>JXL_BIG_ENDIAN</c>: forced.
  /// </remarks>
  JxlEndianness = (
    JXL_NATIVE_ENDIAN = 0,
    JXL_LITTLE_ENDIAN = 1,
    JXL_BIG_ENDIAN = 2
  );

  /// <summary>
  ///   Layout of an interleaved pixel buffer passed to or from the library: rows top to bottom, pixels left to right.
  /// </summary>
  JxlPixelFormat = record
    /// <summary>Channels per pixel: 1 grey, 2 grey + alpha, 3 RGB, 4 RGB + alpha.</summary>
    num_channels: UInt32;
    /// <summary>Data type of each channel.</summary>
    data_type: JxlDataType;
    /// <summary>Byte order of multi-byte data types.</summary>
    endianness: JxlEndianness;
    /// <summary>Align each scanline to a multiple of this many bytes; 0 or 1 means no alignment.</summary>
    align: NativeUInt;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlPixelFormat" />.</summary>
  TJxlPixelFormat = JxlPixelFormat;
  /// <summary>Pointer to a <see cref="JxlPixelFormat" />.</summary>
  PJxlPixelFormat = ^JxlPixelFormat;

  /// <summary>Interpretation of the range of UINT input and output buffers (FLOAT buffers are unaffected).</summary>
  /// <remarks>
  ///   <c>JXL_BIT_DEPTH_FROM_PIXEL_FORMAT</c> (default): the full range of the data type;
  ///   <c>JXL_BIT_DEPTH_FROM_CODESTREAM</c>: the range of <c>bits_per_sample</c> in the basic info;
  ///   <c>JXL_BIT_DEPTH_CUSTOM</c>: a custom range, decoder only.
  /// </remarks>
  JxlBitDepthType = (
    JXL_BIT_DEPTH_FROM_PIXEL_FORMAT = 0,
    JXL_BIT_DEPTH_FROM_CODESTREAM = 1,
    JXL_BIT_DEPTH_CUSTOM = 2
  );

  /// <summary>Range of allowed input and output pixel values.</summary>
  JxlBitDepth = record
    /// <summary>Bit depth setting.</summary>
    type_: JxlBitDepthType;
    /// <summary>Custom bits per sample.</summary>
    bits_per_sample: UInt32;
    /// <summary>Custom exponent bits per sample.</summary>
    exponent_bits_per_sample: UInt32;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlBitDepth" />.</summary>
  TJxlBitDepth = JxlBitDepth;
  /// <summary>Pointer to a <see cref="JxlBitDepth" />.</summary>
  PJxlBitDepth = ^JxlBitDepth;

  /// <summary>The 4-character type name of an ISOBMFF box, without a terminating null.</summary>
  JxlBoxType = array[ 0..3 ] of AnsiChar;

  { memory_manager.h }

  /// <summary>Allocating function for a memory region of a given size.</summary>
  /// <param name="opaque">Custom memory manager handle provided by the caller.</param>
  /// <param name="size">Size in bytes of the requested region.</param>
  /// <returns>The memory, or <c>nil</c> if it cannot be allocated.</returns>
  jpegxl_alloc_func = function( opaque: Pointer; size: NativeUInt ): Pointer; cdecl;

  /// <summary>Deallocating function; must do nothing when <paramref name="address" /> is <c>nil</c>.</summary>
  /// <param name="opaque">Custom memory manager handle provided by the caller.</param>
  /// <param name="address">Region returned by the matching <see cref="jpegxl_alloc_func" />, or <c>nil</c>.</param>
  jpegxl_free_func = procedure( opaque: Pointer; address: Pointer ); cdecl;

  /// <summary>Caller-provided memory allocation functions; <c>nil</c> functions mean the C runtime's malloc/free.</summary>
  JxlMemoryManager = record
    /// <summary>Opaque pointer passed as the first parameter to both functions.</summary>
    opaque: Pointer;
    /// <summary>Allocation function; may be <c>nil</c> only if <c>free</c> is also <c>nil</c>.</summary>
    alloc: jpegxl_alloc_func;
    /// <summary>Free function matching <c>alloc</c>.</summary>
    free: jpegxl_free_func;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlMemoryManager" />.</summary>
  TJxlMemoryManager = JxlMemoryManager;
  /// <summary>Pointer to a <see cref="JxlMemoryManager" />.</summary>
  PJxlMemoryManager = ^JxlMemoryManager;

  /// <summary>
  ///   A memory budget for one libjxl decoder or encoder (Pascal only): <see cref="Manager" /> returns a
  ///   <see cref="JxlMemoryManager" /> whose allocations come from the Windows process heap and are counted, and which
  ///   refuses (returns <c>nil</c>) any allocation that would take the total above <see cref="Limit" />, so that libjxl
  ///   fails with an error status instead of exhausting the process.
  /// </summary>
  /// <remarks>
  ///   The record must neither move nor go out of scope while the decoder or encoder exists: keep it in a local
  ///   variable of the routine that creates and destroys the instance, and pass <c>@rManager</c> (a local copy of
  ///   <see cref="Manager" />) to <c>JxlDecoderCreate</c> / <c>JxlEncoderCreate</c>, which copy it. Only allocations
  ///   libjxl routes through its memory manager (its image planes and large buffers) are counted; small C++ objects
  ///   use the C runtime directly. The callbacks are thread-safe (libjxl calls them from its worker threads) and never
  ///   raise.
  /// </remarks>
  /// <example>
  ///   <code>
  ///     var rBudget: TJxlMemoryBudget;
  ///     rBudget.Init( 512 * 1024 * 1024 );
  ///     var rManager := rBudget.Manager;
  ///     var pDecoder := JxlDecoderCreate( @rManager );
  ///     // ... a JXL_DEC_ERROR with rBudget.Refusals &gt; 0 means the budget was reached
  ///   </code>
  /// </example>
  TJxlMemoryBudget = record
    /// <summary>Most bytes libjxl may hold at once through this budget.</summary>
    Limit: Int64;
    /// <summary>Bytes currently allocated through the budget; 0 again once the instance is destroyed.</summary>
    Used: Int64;
    /// <summary>Largest value <see cref="Used" /> has reached.</summary>
    Peak: Int64;
    /// <summary>Number of allocations refused, because of the limit or because the heap was exhausted.</summary>
    Refusals: Integer;
    /// <summary>Resets the counters and sets the limit.</summary>
    /// <param name="ALimit">Most bytes libjxl may hold at once.</param>
    procedure Init( ALimit: Int64 );
    /// <summary>Returns the memory manager to pass to <c>JxlDecoderCreate</c> or <c>JxlEncoderCreate</c>.</summary>
    /// <returns>A manager whose <c>opaque</c> points at this record.</returns>
    function Manager: JxlMemoryManager;
  end;
  /// <summary>Pointer to a <see cref="TJxlMemoryBudget" />.</summary>
  PJxlMemoryBudget = ^TJxlMemoryBudget;

  { parallel_runner.h }

  /// <summary>Return code of the parallel-runner functions: 0 is success, anything else an error.</summary>
  JxlParallelRetCode = Integer;

  /// <summary>
  ///   Parallel run initialisation callback; the runner calls it once, on its calling thread, before any parallel work.
  /// </summary>
  /// <param name="jpegxl_opaque">The <c>jpegxl_opaque</c> handle the runner received.</param>
  /// <param name="num_threads">Maximum number of threads the runner will use; positive.</param>
  /// <returns>0 on success, otherwise an error code the runner must return.</returns>
  JxlParallelRunInit = function( jpegxl_opaque: Pointer; num_threads: NativeUInt ): JxlParallelRetCode; cdecl;

  /// <summary>Parallel run data-processing callback; called once for every value in the runner's range.</summary>
  /// <param name="jpegxl_opaque">The <c>jpegxl_opaque</c> handle the runner received.</param>
  /// <param name="value">The value in [start_range, end_range) for this call.</param>
  /// <param name="thread_id">Calling thread number, below the <c>num_threads</c> passed to the init callback.</param>
  JxlParallelRunFunction = procedure( jpegxl_opaque: Pointer; value: UInt32; thread_id: NativeUInt ); cdecl;

  /// <summary>
  ///   A parallel runner: calls <paramref name="init" /> on the calling thread, then <paramref name="func" /> once
  ///   for every value in [<paramref name="start_range" />, <paramref name="end_range" />), possibly in parallel.
  /// </summary>
  /// <param name="runner_opaque">The runner's own state.</param>
  /// <param name="jpegxl_opaque">Library handle to pass to <paramref name="init" /> and <paramref name="func" />.</param>
  /// <param name="init">Initialisation callback.</param>
  /// <param name="func">Data-processing callback.</param>
  /// <param name="start_range">First value (inclusive).</param>
  /// <param name="end_range">Last value (exclusive).</param>
  /// <returns>0 on success, <see cref="JXL_PARALLEL_RET_RUNNER_ERROR" />, or the non-zero result of init.</returns>
  JxlParallelRunner = function( runner_opaque: Pointer; jpegxl_opaque: Pointer; init: JxlParallelRunInit;
    func: JxlParallelRunFunction; start_range: UInt32; end_range: UInt32 ): JxlParallelRetCode; cdecl;

  { codestream_header.h }

  /// <summary>Image orientation metadata; values 1..8 match EXIF and name the operation from encoded to displayed image.</summary>
  JxlOrientation = (
    JXL_ORIENT_IDENTITY = 1,
    JXL_ORIENT_FLIP_HORIZONTAL = 2,
    JXL_ORIENT_ROTATE_180 = 3,
    JXL_ORIENT_FLIP_VERTICAL = 4,
    JXL_ORIENT_TRANSPOSE = 5,
    JXL_ORIENT_ROTATE_90_CW = 6,
    JXL_ORIENT_ANTI_TRANSPOSE = 7,
    JXL_ORIENT_ROTATE_90_CCW = 8
  );

  /// <summary>Given type of an extra channel (alpha, depth, spot colour, selection mask, black, CFA, thermal, ...).</summary>
  JxlExtraChannelType = (
    JXL_CHANNEL_ALPHA = 0,
    JXL_CHANNEL_DEPTH = 1,
    JXL_CHANNEL_SPOT_COLOR = 2,
    JXL_CHANNEL_SELECTION_MASK = 3,
    JXL_CHANNEL_BLACK = 4,
    JXL_CHANNEL_CFA = 5,
    JXL_CHANNEL_THERMAL = 6,
    JXL_CHANNEL_RESERVED0 = 7,
    JXL_CHANNEL_RESERVED1 = 8,
    JXL_CHANNEL_RESERVED2 = 9,
    JXL_CHANNEL_RESERVED3 = 10,
    JXL_CHANNEL_RESERVED4 = 11,
    JXL_CHANNEL_RESERVED5 = 12,
    JXL_CHANNEL_RESERVED6 = 13,
    JXL_CHANNEL_RESERVED7 = 14,
    JXL_CHANNEL_UNKNOWN = 15,
    JXL_CHANNEL_OPTIONAL = 16
  );

  /// <summary>The codestream preview header.</summary>
  JxlPreviewHeader = record
    /// <summary>Preview width in pixels.</summary>
    xsize: UInt32;
    /// <summary>Preview height in pixels.</summary>
    ysize: UInt32;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlPreviewHeader" />.</summary>
  TJxlPreviewHeader = JxlPreviewHeader;

  /// <summary>The codestream animation header, applying to all animation frames.</summary>
  JxlAnimationHeader = record
    /// <summary>Numerator of ticks per second of one animation time unit.</summary>
    tps_numerator: UInt32;
    /// <summary>Denominator of ticks per second of one animation time unit.</summary>
    tps_denominator: UInt32;
    /// <summary>Number of animation loops, or 0 to repeat forever.</summary>
    num_loops: UInt32;
    /// <summary>Whether animation time codes are present at animation frames.</summary>
    have_timecodes: JXL_BOOL;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlAnimationHeader" />.</summary>
  TJxlAnimationHeader = JxlAnimationHeader;

  /// <summary>Basic image information, available from the signature and the first part of the codestream header.</summary>
  JxlBasicInfo = record
    /// <summary>Whether the codestream is embedded in the container format.</summary>
    have_container: JXL_BOOL;
    /// <summary>Image width in pixels, before orientation is applied.</summary>
    xsize: UInt32;
    /// <summary>Image height in pixels, before orientation is applied.</summary>
    ysize: UInt32;
    /// <summary>Original colour channel bit depth.</summary>
    bits_per_sample: UInt32;
    /// <summary>Original floating-point exponent bits, or 0 for unsigned integer samples.</summary>
    exponent_bits_per_sample: UInt32;
    /// <summary>Upper bound on the intensity level in nits; 0 lets libjxl choose from the colour encoding.</summary>
    intensity_target: Single;
    /// <summary>Lower bound on the intensity level present in the image.</summary>
    min_nits: Single;
    /// <summary>Whether <c>linear_below</c> is a ratio of the display maximum rather than absolute nits.</summary>
    relative_to_max_display: JXL_BOOL;
    /// <summary>Tone mapping leaves pixels darker than this unchanged.</summary>
    linear_below: Single;
    /// <summary>Whether the data is encoded in the original colour profile rather than an internal absolute space.</summary>
    uses_original_profile: JXL_BOOL;
    /// <summary>Whether a preview image exists near the beginning of the codestream.</summary>
    have_preview: JXL_BOOL;
    /// <summary>Whether animation frames exist in the codestream.</summary>
    have_animation: JXL_BOOL;
    /// <summary>Image orientation, 1-8 as in EXIF.</summary>
    orientation: JxlOrientation;
    /// <summary>Number of colour channels: 1 for greyscale, 3 for colour; excludes alpha and extra channels.</summary>
    num_color_channels: UInt32;
    /// <summary>Number of additional channels, including the main alpha channel.</summary>
    num_extra_channels: UInt32;
    /// <summary>Bit depth of the main alpha channel, or 0 if there is none.</summary>
    alpha_bits: UInt32;
    /// <summary>Alpha floating-point exponent bits, or 0 if unsigned.</summary>
    alpha_exponent_bits: UInt32;
    /// <summary>Whether the main alpha channel is premultiplied.</summary>
    alpha_premultiplied: JXL_BOOL;
    /// <summary>Dimensions of the preview image; used only when <c>have_preview</c> is set.</summary>
    preview: JxlPreviewHeader;
    /// <summary>Global animation properties; used only when <c>have_animation</c> is set.</summary>
    animation: JxlAnimationHeader;
    /// <summary>Intrinsic (recommended display) width of the image.</summary>
    intrinsic_xsize: UInt32;
    /// <summary>Intrinsic (recommended display) height of the image.</summary>
    intrinsic_ysize: UInt32;
    /// <summary>Padding for forward compatibility with fields a later library version may expose.</summary>
    padding: array[ 0..99 ] of UInt8;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlBasicInfo" />.</summary>
  TJxlBasicInfo = JxlBasicInfo;
  /// <summary>Pointer to a <see cref="JxlBasicInfo" />.</summary>
  PJxlBasicInfo = ^JxlBasicInfo;

  /// <summary>Information for a single extra channel.</summary>
  JxlExtraChannelInfo = record
    /// <summary>Type of the extra channel.</summary>
    type_: JxlExtraChannelType;
    /// <summary>Total bits per sample for this channel.</summary>
    bits_per_sample: UInt32;
    /// <summary>Floating-point exponent bits, or 0 if unsigned integer.</summary>
    exponent_bits_per_sample: UInt32;
    /// <summary>Exponent the channel is downsampled by on each axis.</summary>
    dim_shift: UInt32;
    /// <summary>Length of the channel name in bytes excluding the null, or 0 if unnamed.</summary>
    name_length: UInt32;
    /// <summary>Whether an alpha channel is premultiplied; only for <c>JXL_CHANNEL_ALPHA</c>.</summary>
    alpha_premultiplied: JXL_BOOL;
    /// <summary>Spot colour in linear RGBA; only for <c>JXL_CHANNEL_SPOT_COLOR</c>.</summary>
    spot_color: array[ 0..3 ] of Single;
    /// <summary>CFA channel index; only for <c>JXL_CHANNEL_CFA</c>.</summary>
    cfa_channel: UInt32;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlExtraChannelInfo" />.</summary>
  TJxlExtraChannelInfo = JxlExtraChannelInfo;
  /// <summary>Pointer to a <see cref="JxlExtraChannelInfo" />.</summary>
  PJxlExtraChannelInfo = ^JxlExtraChannelInfo;

  /// <summary>Extensions in the codestream header.</summary>
  JxlHeaderExtensions = record
    /// <summary>Extension bits.</summary>
    extensions: UInt64;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlHeaderExtensions" />.</summary>
  TJxlHeaderExtensions = JxlHeaderExtensions;

  /// <summary>Frame blend modes; ignorable when decoding with coalescing enabled (the default).</summary>
  JxlBlendMode = (
    JXL_BLEND_REPLACE = 0,
    JXL_BLEND_ADD = 1,
    JXL_BLEND_BLEND = 2,
    JXL_BLEND_MULADD = 3,
    JXL_BLEND_MUL = 4
  );

  /// <summary>How the colour channels or one extra channel are blended.</summary>
  JxlBlendInfo = record
    /// <summary>Blend mode.</summary>
    blendmode: JxlBlendMode;
    /// <summary>Reference frame ID (0-3) used as the bottom layer.</summary>
    source: UInt32;
    /// <summary>Extra channel used as alpha for <c>JXL_BLEND_BLEND</c> and <c>JXL_BLEND_MULADD</c>.</summary>
    alpha: UInt32;
    /// <summary>Whether values are clamped to [0, 1] for blending.</summary>
    clamp: JXL_BOOL;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlBlendInfo" />.</summary>
  TJxlBlendInfo = JxlBlendInfo;
  /// <summary>Pointer to a <see cref="JxlBlendInfo" />.</summary>
  PJxlBlendInfo = ^JxlBlendInfo;

  /// <summary>Layer information of a frame; ignorable when decoding with coalescing enabled (the default).</summary>
  JxlLayerInfo = record
    /// <summary>Whether cropping is applied for this frame.</summary>
    have_crop: JXL_BOOL;
    /// <summary>Horizontal offset of the frame; can be negative.</summary>
    crop_x0: Int32;
    /// <summary>Vertical offset of the frame; can be negative.</summary>
    crop_y0: Int32;
    /// <summary>Frame width in columns.</summary>
    xsize: UInt32;
    /// <summary>Frame height in rows.</summary>
    ysize: UInt32;
    /// <summary>Blending of the colour channels.</summary>
    blend_info: JxlBlendInfo;
    /// <summary>Reference frame ID (0-3) this frame is saved as after blending.</summary>
    save_as_reference: UInt32;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlLayerInfo" />.</summary>
  TJxlLayerInfo = JxlLayerInfo;

  /// <summary>Header of one displayed frame or non-coalesced layer.</summary>
  JxlFrameHeader = record
    /// <summary>How long to wait after rendering, in ticks of the animation header.</summary>
    duration: UInt32;
    /// <summary>SMPTE timecode as 0xHHMMSSFF, or 0.</summary>
    timecode: UInt32;
    /// <summary>Length of the frame name in bytes excluding the null; set by the decoder.</summary>
    name_length: UInt32;
    /// <summary>Whether this is the last animation frame; set by the decoder.</summary>
    is_last: JXL_BOOL;
    /// <summary>Layer information, relevant when coalescing is disabled.</summary>
    layer_info: JxlLayerInfo;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlFrameHeader" />.</summary>
  TJxlFrameHeader = JxlFrameHeader;
  /// <summary>Pointer to a <see cref="JxlFrameHeader" />.</summary>
  PJxlFrameHeader = ^JxlFrameHeader;

  { color_encoding.h }

  /// <summary>Colour space of the image data: RGB, grey, XYB or unknown.</summary>
  JxlColorSpace = (
    JXL_COLOR_SPACE_RGB = 0,
    JXL_COLOR_SPACE_GRAY = 1,
    JXL_COLOR_SPACE_XYB = 2,
    JXL_COLOR_SPACE_UNKNOWN = 3
  );

  /// <summary>Built-in white points (D65, custom, E, DCI); a subset of CICP values.</summary>
  JxlWhitePoint = (
    JXL_WHITE_POINT_D65 = 1,
    JXL_WHITE_POINT_CUSTOM = 2,
    JXL_WHITE_POINT_E = 10,
    JXL_WHITE_POINT_DCI = 11
  );

  /// <summary>Built-in primaries (sRGB, custom, BT.2100, P3); a subset of CICP values.</summary>
  JxlPrimaries = (
    JXL_PRIMARIES_SRGB = 1,
    JXL_PRIMARIES_CUSTOM = 2,
    JXL_PRIMARIES_2100 = 9,
    JXL_PRIMARIES_P3 = 11
  );

  /// <summary>Built-in transfer functions; CICP values except <c>JXL_TRANSFER_FUNCTION_GAMMA</c>.</summary>
  JxlTransferFunction = (
    JXL_TRANSFER_FUNCTION_709 = 1,
    JXL_TRANSFER_FUNCTION_UNKNOWN = 2,
    JXL_TRANSFER_FUNCTION_LINEAR = 8,
    JXL_TRANSFER_FUNCTION_SRGB = 13,
    JXL_TRANSFER_FUNCTION_PQ = 16,
    JXL_TRANSFER_FUNCTION_DCI = 17,
    JXL_TRANSFER_FUNCTION_HLG = 18,
    JXL_TRANSFER_FUNCTION_GAMMA = 65535
  );

  /// <summary>Rendering intent, as specified in ISO 15076-1:2010.</summary>
  JxlRenderingIntent = (
    JXL_RENDERING_INTENT_PERCEPTUAL = 0,
    JXL_RENDERING_INTENT_RELATIVE = 1,
    JXL_RENDERING_INTENT_SATURATION = 2,
    JXL_RENDERING_INTENT_ABSOLUTE = 3
  );

  /// <summary>Colour encoding of the image as structured information (CIE 1931 2-degree observer).</summary>
  JxlColorEncoding = record
    /// <summary>Colour space of the image data.</summary>
    color_space: JxlColorSpace;
    /// <summary>Built-in white point; <c>JXL_WHITE_POINT_CUSTOM</c> means use <c>white_point_xy</c>.</summary>
    white_point: JxlWhitePoint;
    /// <summary>Numerical white point in CIE xy.</summary>
    white_point_xy: array[ 0..1 ] of Double;
    /// <summary>Built-in RGB primaries; <c>JXL_PRIMARIES_CUSTOM</c> means use the numerical values.</summary>
    primaries: JxlPrimaries;
    /// <summary>Numerical red primary in CIE xy.</summary>
    primaries_red_xy: array[ 0..1 ] of Double;
    /// <summary>Numerical green primary in CIE xy.</summary>
    primaries_green_xy: array[ 0..1 ] of Double;
    /// <summary>Numerical blue primary in CIE xy.</summary>
    primaries_blue_xy: array[ 0..1 ] of Double;
    /// <summary>Transfer function.</summary>
    transfer_function: JxlTransferFunction;
    /// <summary>Gamma used when <c>transfer_function</c> is <c>JXL_TRANSFER_FUNCTION_GAMMA</c>.</summary>
    gamma: Double;
    /// <summary>Rendering intent of the profile.</summary>
    rendering_intent: JxlRenderingIntent;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlColorEncoding" />.</summary>
  TJxlColorEncoding = JxlColorEncoding;
  /// <summary>Pointer to a <see cref="JxlColorEncoding" />.</summary>
  PJxlColorEncoding = ^JxlColorEncoding;

  { cms_interface.h }

  /// <summary>Serialised ICC profile part of a <see cref="JxlColorProfile" /> (the C anonymous struct <c>icc</c>).</summary>
  JxlColorProfileIcc = record
    /// <summary>The serialised ICC profile.</summary>
    data: PByte;
    /// <summary>Size of the profile in bytes.</summary>
    size: NativeUInt;
  end;

  /// <summary>An input or output colour space of a colour transform.</summary>
  JxlColorProfile = record
    /// <summary>The serialised ICC profile; always present and valid.</summary>
    icc: JxlColorProfileIcc;
    /// <summary>Structured representation of the colour space, where applicable.</summary>
    color_encoding: JxlColorEncoding;
    /// <summary>Number of components per pixel.</summary>
    num_channels: NativeUInt;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlColorProfile" />.</summary>
  TJxlColorProfile = JxlColorProfile;
  /// <summary>Pointer to a <see cref="JxlColorProfile" />.</summary>
  PJxlColorProfile = ^JxlColorProfile;

  /// <summary>Parses an ICC profile and fills in a colour encoding.</summary>
  /// <param name="user_data">The interface's <c>set_fields_data</c>, passed as is.</param>
  /// <param name="icc_data">ICC data to parse.</param>
  /// <param name="icc_size">Number of valid bytes in <paramref name="icc_data" />.</param>
  /// <param name="c">Colour encoding to fill in where applicable.</param>
  /// <param name="cmyk">Set to whether the colour space is CMYK.</param>
  /// <returns>Whether the relevant fields of <paramref name="c" /> were filled in.</returns>
  jpegxl_cms_set_fields_from_icc_func = function( user_data: Pointer; icc_data: PByte; icc_size: NativeUInt;
    c: PJxlColorEncoding; cmyk: PJXL_BOOL ): JXL_BOOL; cdecl;

  /// <summary>Allocates the data for parallel transforms from one colour space to another.</summary>
  /// <param name="init_data">The interface's <c>init_data</c>, passed as is.</param>
  /// <param name="num_threads">Maximum number of threads that will call <c>run</c>.</param>
  /// <param name="pixels_per_thread">Maximum number of pixels per <c>run</c> call.</param>
  /// <param name="input_profile">Input colour space.</param>
  /// <param name="output_profile">Output colour space.</param>
  /// <param name="intensity_target">Luminance at which (1, 1, 1) is displayed, for relative colour spaces.</param>
  /// <returns>The transform data passed to the other functions as <c>user_data</c>, or <c>nil</c> on failure.</returns>
  jpegxl_cms_init_func = function( init_data: Pointer; num_threads: NativeUInt; pixels_per_thread: NativeUInt;
    input_profile: PJxlColorProfile; output_profile: PJxlColorProfile; intensity_target: Single ): Pointer; cdecl;

  /// <summary>Returns a buffer usable as the input or output of <c>run</c> for one thread.</summary>
  /// <param name="user_data">Data returned by <c>init</c>.</param>
  /// <param name="thread">Index of the thread the buffer is for.</param>
  /// <returns>The buffer.</returns>
  jpegxl_cms_get_buffer_func = function( user_data: Pointer; thread: NativeUInt ): PSingle; cdecl;

  /// <summary>Executes one transform of interleaved 0..1 float samples.</summary>
  /// <param name="user_data">Data returned by <c>init</c>.</param>
  /// <param name="thread">Index of the calling thread.</param>
  /// <param name="input_buffer">Pixels to transform.</param>
  /// <param name="output_buffer">Receives the transformed pixels.</param>
  /// <param name="num_pixels">Number of pixels to transform.</param>
  /// <returns><see cref="JXL_TRUE" /> on success, <see cref="JXL_FALSE" /> on failure.</returns>
  jpegxl_cms_run_func = function( user_data: Pointer; thread: NativeUInt; input_buffer: PSingle; output_buffer: PSingle;
    num_pixels: NativeUInt ): JXL_BOOL; cdecl;

  /// <summary>Cleans up and frees the transform data.</summary>
  /// <param name="user_data">Data returned by <c>init</c>.</param>
  jpegxl_cms_destroy_func = procedure( user_data: Pointer ); cdecl;

  /// <summary>Interface for performing colour-space transforms (a CMS); passed by value to the encoder and decoder.</summary>
  JxlCmsInterface = record
    /// <summary>CMS-specific data passed to <c>set_fields_from_icc</c>.</summary>
    set_fields_data: Pointer;
    /// <summary>Fills in a colour encoding from an ICC profile.</summary>
    set_fields_from_icc: jpegxl_cms_set_fields_from_icc_func;
    /// <summary>CMS-specific data passed to <c>init</c>.</summary>
    init_data: Pointer;
    /// <summary>Prepares a colour-space transform.</summary>
    init: jpegxl_cms_init_func;
    /// <summary>Returns a buffer usable as input to <c>run</c>.</summary>
    get_src_buf: jpegxl_cms_get_buffer_func;
    /// <summary>Returns a buffer usable as output from <c>run</c>.</summary>
    get_dst_buf: jpegxl_cms_get_buffer_func;
    /// <summary>Executes the transform on a batch of pixels.</summary>
    run: jpegxl_cms_run_func;
    /// <summary>Cleans up the transform.</summary>
    destroy: jpegxl_cms_destroy_func;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlCmsInterface" />.</summary>
  TJxlCmsInterface = JxlCmsInterface;
  /// <summary>Pointer to a <see cref="JxlCmsInterface" />.</summary>
  PJxlCmsInterface = ^JxlCmsInterface;

  { stats.h }

  /// <summary>Opaque encoder statistics object (C <c>JxlEncoderStats</c>); use through <see cref="PJxlEncoderStats" />.</summary>
  JxlEncoderStats = record
  end;
  /// <summary>Handle of an encoder statistics object.</summary>
  PJxlEncoderStats = ^JxlEncoderStats;

  /// <summary>Key for querying a <see cref="JxlEncoderStats" /> object (bit counts and block counts).</summary>
  JxlEncoderStatsKey = (
    JXL_ENC_STAT_HEADER_BITS = 0,
    JXL_ENC_STAT_TOC_BITS = 1,
    JXL_ENC_STAT_DICTIONARY_BITS = 2,
    JXL_ENC_STAT_SPLINES_BITS = 3,
    JXL_ENC_STAT_NOISE_BITS = 4,
    JXL_ENC_STAT_QUANT_BITS = 5,
    JXL_ENC_STAT_MODULAR_TREE_BITS = 6,
    JXL_ENC_STAT_MODULAR_GLOBAL_BITS = 7,
    JXL_ENC_STAT_DC_BITS = 8,
    JXL_ENC_STAT_MODULAR_DC_GROUP_BITS = 9,
    JXL_ENC_STAT_CONTROL_FIELDS_BITS = 10,
    JXL_ENC_STAT_COEF_ORDER_BITS = 11,
    JXL_ENC_STAT_AC_HISTOGRAM_BITS = 12,
    JXL_ENC_STAT_AC_BITS = 13,
    JXL_ENC_STAT_MODULAR_AC_GROUP_BITS = 14,
    JXL_ENC_STAT_NUM_SMALL_BLOCKS = 15,
    JXL_ENC_STAT_NUM_DCT4X8_BLOCKS = 16,
    JXL_ENC_STAT_NUM_AFV_BLOCKS = 17,
    JXL_ENC_STAT_NUM_DCT8_BLOCKS = 18,
    JXL_ENC_STAT_NUM_DCT8X32_BLOCKS = 19,
    JXL_ENC_STAT_NUM_DCT16_BLOCKS = 20,
    JXL_ENC_STAT_NUM_DCT16X32_BLOCKS = 21,
    JXL_ENC_STAT_NUM_DCT32_BLOCKS = 22,
    JXL_ENC_STAT_NUM_DCT32X64_BLOCKS = 23,
    JXL_ENC_STAT_NUM_DCT64_BLOCKS = 24,
    JXL_ENC_STAT_NUM_BUTTERAUGLI_ITERS = 25,
    JXL_ENC_NUM_STATS = 26
  );

  { gain_map.h }

  /// <summary>
  ///   Gain map bundle: a view into a caller-owned buffer holding <c>jhgm</c> box data; it owns none of the memory.
  /// </summary>
  JxlGainMapBundle = record
    /// <summary>Version number of the gain map bundle.</summary>
    jhgm_version: UInt8;
    /// <summary>Size of the gain map metadata in bytes.</summary>
    gain_map_metadata_size: UInt16;
    /// <summary>Gain map metadata (ISO 21496-1), inside the input buffer.</summary>
    gain_map_metadata: PByte;
    /// <summary>Whether a colour encoding is present.</summary>
    has_color_encoding: JXL_BOOL;
    /// <summary>The uncompressed colour encoding, when <c>has_color_encoding</c> is set.</summary>
    color_encoding: JxlColorEncoding;
    /// <summary>Compressed size of the alternative ICC profile in bytes.</summary>
    alt_icc_size: UInt32;
    /// <summary>The compressed alternative ICC profile, inside the input buffer.</summary>
    alt_icc: PByte;
    /// <summary>Size of the gain map in bytes.</summary>
    gain_map_size: UInt32;
    /// <summary>The gain map, a naked JPEG XL codestream inside the input buffer.</summary>
    gain_map: PByte;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlGainMapBundle" />.</summary>
  TJxlGainMapBundle = JxlGainMapBundle;
  /// <summary>Pointer to a <see cref="JxlGainMapBundle" />.</summary>
  PJxlGainMapBundle = ^JxlGainMapBundle;

// `delayed` is marked platform-specific (W1002). The binding is Windows-only by design, and delay loading is
// what lets JxlCheckLibrary report a missing DLL instead of the process failing to start, so the warning is
// silenced for the import declarations only.
{$WARN SYMBOL_PLATFORM OFF}

{ stats.h }

/// <summary>Creates and initialises an encoder statistics object.</summary>
/// <returns>The new statistics object; free it with <see cref="JxlEncoderStatsDestroy" />.</returns>
function JxlEncoderStatsCreate: PJxlEncoderStats; cdecl; external JXL_LIBRARY delayed;

/// <summary>Frees an encoder statistics object; does nothing for <c>nil</c>.</summary>
/// <param name="stats">The object to free.</param>
procedure JxlEncoderStatsDestroy( stats: PJxlEncoderStats ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the value of one statistic.</summary>
/// <param name="stats">Object that was passed to the encoder with <c>JxlEncoderCollectStats</c>.</param>
/// <param name="key">The statistic to query.</param>
/// <returns>The value of the statistic.</returns>
function JxlEncoderStatsGet( stats: PJxlEncoderStats; key: JxlEncoderStatsKey ): NativeUInt; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Merges the values of another statistics object into this one.</summary>
/// <param name="stats">Object whose values are updated.</param>
/// <param name="other">Object whose values are merged in.</param>
procedure JxlEncoderStatsMerge( stats: PJxlEncoderStats; other: PJxlEncoderStats ); cdecl; external JXL_LIBRARY delayed;

{ gain_map.h, compressed_icc.h: JxlGainMapGetBundleSize, JxlGainMapWriteBundle, JxlGainMapReadBundle,
  JxlICCProfileEncode and JxlICCProfileDecode are deliberately not imported. The headers mark them JXL_EXPORT,
  but their sources are built into the static jxl_extras library, not into jxl.dll, so the shared library does
  not export them and a delay-loaded import would fail at its first call. }

{$WARN SYMBOL_PLATFORM DEFAULT}

const
  /// <summary>
  ///   Every function this unit imports from <see cref="JXL_LIBRARY" />; <c>JxlCheckLibrary</c> verifies that the
  ///   DLL exports each one before any of them is called. Keep it in step with the declarations above.
  /// </summary>
  JXL_STATS_EXPORTS: array[ 0..3 ] of string = (
    NameOf( JxlEncoderStatsCreate ),
    NameOf( JxlEncoderStatsDestroy ),
    NameOf( JxlEncoderStatsGet ),
    NameOf( JxlEncoderStatsMerge )
  );

{ Library availability (Pascal only) }

type
  /// <summary>How the libjxl functions the binding imports are spread over DLLs.</summary>
  TJxlLibraryLayout = (
    /// <summary>
    ///   One self-contained <see cref="JXL_LIBRARY" /> exports every function, the thread runners and the CMS included.
    /// </summary>
    jllSingleDll,
    /// <summary>
    ///   Upstream's shared build: the thread runners come from <see cref="JXL_THREADS_LIBRARY" /> or the CMS from
    ///   <see cref="JXL_CMS_LIBRARY" /> (normally both), because <see cref="JXL_LIBRARY" /> does not export them.
    /// </summary>
    jllSplitDlls
  );

/// <summary>
///   Returns the folders the binding loads libjxl's DLLs from, in the order searched: the folder of the module that
///   contains the binding (the executable, or the package or DLL it is linked into), then the executable's folder
///   when that differs. The current directory and <c>PATH</c> are never searched.
/// </summary>
/// <returns>The folders, each with a trailing path delimiter.</returns>
function JxlLibraryDirectories: TArray<string>;

/// <summary>
///   Reports whether a DLL, and every DLL it depends on, can be loaded from the binding's safe folders
///   (<see cref="JxlLibraryDirectories" />); a DLL already loaded in the process counts as available.
/// </summary>
/// <param name="AFileName">File name of the DLL (searched for in the safe folders), or a full path.</param>
/// <returns><c>True</c> when the DLL loads.</returns>
function JxlModuleAvailable( const AFileName: string ): Boolean;

/// <summary>Raises <see cref="EJxlError" /> when a DLL, or a DLL it depends on, cannot be loaded from the safe folders.</summary>
/// <param name="AFileName">File name of the DLL (searched for in <see cref="JxlLibraryDirectories" />), or a full path.</param>
/// <exception cref="EJxlError">
///   The DLL cannot be loaded; <c>ApiName</c> is <c>LoadLibraryEx</c> and <c>Status</c> the Windows error code
///   (126, <c>ERROR_MOD_NOT_FOUND</c>, when it is in none of the folders).
/// </exception>
procedure JxlCheckModule( const AFileName: string );

/// <summary>
///   Returns the names in a list that a loaded module does not export. The export check of
///   <see cref="JxlCheckLibrary" />, exposed so that it can be tested against any module.
/// </summary>
/// <param name="AModule">Handle (<c>HMODULE</c>) of a loaded module.</param>
/// <param name="ANames">Function names to look up.</param>
/// <returns>The names <c>GetProcAddress</c> does not find, in list order; empty when all are exported.</returns>
function JxlFindMissingExports( AModule: THandle; const ANames: array of string ): TArray<string>;

/// <summary>
///   Raises <see cref="EJxlError" /> when a libjxl version is older than <see cref="JXL_MIN_VERSION" />. The version
///   check of <see cref="JxlCheckLibrary" />, exposed so that it can be tested with any number.
/// </summary>
/// <param name="AVersion">Version as <c>JxlDecoderVersion</c> reports it.</param>
/// <param name="ALibraryPath">Where the DLL was loaded from, for the message; may be empty.</param>
/// <exception cref="EJxlError">
///   The version is too old; <c>ApiName</c> is <c>JxlDecoderVersion</c> and <c>Status</c> the version found.
/// </exception>
procedure JxlCheckVersion( AVersion: UInt32; const ALibraryPath: string = '' );

/// <summary>
///   Reports whether <see cref="JxlCheckLibrary" /> succeeds: the libjxl DLL(s) load from the safe folders and
///   export every imported function, at version <see cref="JXL_MIN_VERSION" /> or later.
/// </summary>
/// <returns><c>True</c> when the binding's routines can run.</returns>
function JxlLibraryAvailable: Boolean;

/// <summary>
///   Makes the libjxl DLL(s) safe to call, in either layout (<see cref="TJxlLibraryLayout" />), or raises a clear
///   <see cref="EJxlError" />.
/// </summary>
/// <remarks>
///   <para>
///     Loads <see cref="JXL_LIBRARY" /> from the binding's safe folders only (<see cref="JxlLibraryDirectories" />,
///     with <c>LoadLibraryEx</c> searching the DLL's own folder and System32 for its dependencies; never the current
///     directory or <c>PATH</c>), or uses the one already loaded in the process; verifies with
///     <c>GetProcAddress</c> that it exports every function of <c>JXL_DECODE_EXPORTS</c>, <c>JXL_ENCODE_EXPORTS</c>
///     and <see cref="JXL_STATS_EXPORTS" />; and checks the version with <see cref="JxlCheckVersion" />. When it also
///     exports every function of <c>JXL_THREADS_EXPORTS</c> (or <c>JXL_CMS_EXPORTS</c>), those come from it (a single
///     self-contained DLL); otherwise <see cref="JXL_THREADS_LIBRARY" /> (or <see cref="JXL_CMS_LIBRARY" />) is
///     loaded and verified the same way (upstream's shared build). Each DLL is also accepted with a <c>lib</c>
///     prefix (<c>libjxl.dll</c>, <c>libjxl_threads.dll</c>, <c>libjxl_cms.dll</c>, as MinGW / MSYS2 builds name
///     them) when no file of the plain name exists.
///   </para>
///   <para>
///     Every verified module is then pinned in the process, and a delay-load notification hook (chained to any
///     hook installed before it, and removed when the unit is finalised) hands the delay loader the module verified
///     for each DLL name, so no import is resolved by a plain <c>LoadLibrary</c> search and, in a single-DLL layout,
///     the thread-runner and CMS imports bind to <see cref="JXL_LIBRARY" />.
///   </para>
///   <para>
///     Call it before the first direct call into a <c>Jxl.Api.*</c> unit: the imports are delay-loaded, and an import
///     that cannot be resolved ends a Win64 process with no exception to catch. The routines of <c>Jxl.Graphic</c>
///     call it themselves. Success is cached for the life of the process (thread-safe); a failure is not, so a DLL
///     deployed later is found by the next call.
///   </para>
/// </remarks>
/// <exception cref="EJxlError">
///   A DLL cannot be found or loaded (<c>ApiName</c> <c>LoadLibraryEx</c>), lacks an export (<c>GetProcAddress</c>,
///   naming the missing functions) or is older than <see cref="JXL_MIN_VERSION" /> (<c>JxlDecoderVersion</c>).
/// </exception>
procedure JxlCheckLibrary;

/// <summary>Returns the layout of the libjxl DLL(s) the binding is bound to, verifying them first.</summary>
/// <returns>The layout <see cref="JxlCheckLibrary" /> found.</returns>
/// <exception cref="EJxlError">Raised as by <see cref="JxlCheckLibrary" />.</exception>
function JxlLibraryLayout: TJxlLibraryLayout;

/// <summary>
///   Verifies the libjxl DLL(s) in one folder exactly as <see cref="JxlCheckLibrary" /> verifies the safe folders,
///   without binding the imports to them or keeping them loaded: for diagnostics and tests.
/// </summary>
/// <param name="AFolder">Folder holding <see cref="JXL_LIBRARY" /> and, for the split layout, the other DLLs.</param>
/// <returns>The layout found in the folder.</returns>
/// <exception cref="EJxlError">Raised as by <see cref="JxlCheckLibrary" />, for the DLLs in the folder.</exception>
/// <exception cref="EArgumentException"><paramref name="AFolder" /> is empty.</exception>
function JxlCheckLibraryFolder( const AFolder: string ): TJxlLibraryLayout;

/// <summary>Formats a libjxl version number (MAJOR * 1000000 + MINOR * 1000 + PATCH) as <c>MAJOR.MINOR.PATCH</c>.</summary>
/// <param name="AVersion">Version as returned by <c>JxlDecoderVersion</c> or <c>JxlEncoderVersion</c>.</param>
/// <returns>The dotted version string.</returns>
function JxlVersionToString( AVersion: UInt32 ): string;

implementation

uses
  Winapi.Windows, System.SyncObjs,
  Jxl.Api.Decode, Jxl.Api.Encode, Jxl.Api.Threads, Jxl.Api.Cms;

type
  /// <summary>Signature of <c>JxlDecoderVersion</c>, called through <c>GetProcAddress</c> by the version check.</summary>
  TJxlVersionFunction = function: UInt32; cdecl;

  /// <summary>The three groups of imports, named after the DLL that exports each in upstream's shared build.</summary>
  TJxlLibraryRole = (
    /// <summary>Decoder, encoder and statistics: <see cref="JXL_LIBRARY" />.</summary>
    jlrMain,
    /// <summary>Thread runners: <see cref="JXL_THREADS_LIBRARY" />, or the main DLL in a single-DLL layout.</summary>
    jlrThreads,
    /// <summary>Default CMS: <see cref="JXL_CMS_LIBRARY" />, or the main DLL in a single-DLL layout.</summary>
    jlrCms
  );

  /// <summary>A module for each group of imports.</summary>
  TJxlLibraryModules = array[ TJxlLibraryRole ] of HMODULE;

  /// <summary>The modules one verification found for each group of imports.</summary>
  TJxlResolvedLibraries = record
    /// <summary>Module verified for each group; the thread runners and the CMS may be the main module.</summary>
    Modules: TJxlLibraryModules;
    /// <summary>Whether the verification loaded the group's module itself, and so owns one reference to it.</summary>
    Owned: array[ TJxlLibraryRole ] of Boolean;
    /// <summary>The layout the modules form.</summary>
    Layout: TJxlLibraryLayout;
    /// <summary>Frees the module references the verification owns.</summary>
    procedure Release;
  end;

const
  /// <summary>File name of the DLL each group of imports is declared against.</summary>
  LIBRARY_FILE_NAMES: array[ TJxlLibraryRole ] of string = ( JXL_LIBRARY, JXL_THREADS_LIBRARY, JXL_CMS_LIBRARY );
  /// <summary>What each group of imports is, for messages.</summary>
  ROLE_DESCRIPTIONS: array[ TJxlLibraryRole ] of string = ( 'decoder and encoder', 'thread runner', 'colour management (CMS)' );
  /// <summary><c>GetModuleHandleEx</c> flag: the module name argument is an address inside the module.</summary>
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = $00000004;
  /// <summary><c>LoadLibraryEx</c> flag: search the folder of the DLL being loaded for its dependencies.</summary>
  LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR = $00000100;
  /// <summary><c>LoadLibraryEx</c> flag: search System32 for the DLL's dependencies.</summary>
  LOAD_LIBRARY_SEARCH_SYSTEM32 = $00000800;
  /// <summary><c>GetModuleHandleEx</c> flag: keep the module loaded until the process ends.</summary>
  GET_MODULE_HANDLE_EX_FLAG_PIN = $00000001;
  /// <summary>
  ///   <c>LoadLibraryEx</c> search for a DLL loaded by full path: its dependencies come from its own folder and
  ///   System32 only, never the current directory or <c>PATH</c>.
  /// </summary>
  SAFE_LOAD_FLAGS = LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR or LOAD_LIBRARY_SEARCH_SYSTEM32;

/// <summary>Kernel32 <c>GetModuleHandleExW</c>, which <c>Winapi.Windows</c> does not declare.</summary>
/// <param name="dwFlags">Flags, e.g. <see cref="GET_MODULE_HANDLE_EX_FLAG_PIN" />.</param>
/// <param name="lpModuleName">Name or path of a loaded module.</param>
/// <param name="phModule">Receives the module handle.</param>
/// <returns>Non-zero on success.</returns>
function GetModuleHandleExW( dwFlags: DWORD; lpModuleName: PWideChar; out phModule: HMODULE ): BOOL; stdcall; external kernel32;

var
  /// <summary>Serialises <see cref="JxlCheckLibrary" />.</summary>
  GLibraryLock: TCriticalSection;
  /// <summary>Set once <see cref="JxlCheckLibrary" /> has verified and pinned every libjxl DLL.</summary>
  GLibraryVerified: Boolean;
  /// <summary>The layout <see cref="JxlCheckLibrary" /> verified; valid once <see cref="GLibraryVerified" /> is set.</summary>
  GLibraryLayout: TJxlLibraryLayout;
  /// <summary>The verified module for each group of imports, which <c>BindingNotifyHook</c> hands the delay loader.</summary>
  GBindModules: TJxlLibraryModules;
  /// <summary>The delay-load notification hook that was installed before <c>BindingNotifyHook</c>, to chain to.</summary>
  GPreviousNotifyHook: TDelayedLoadHook;

{ EJxlError }

constructor EJxlError.CreateStatus( const AApiName: string; AStatus: Integer; const ADetail: string );
begin

  if ( ADetail = '' ) then
    inherited CreateFmt( '%s failed with status %d.', [ AApiName, AStatus ] )
  else
    inherited CreateFmt( '%s failed with status %d: %s', [ AApiName, AStatus, ADetail ] );

  FApiName := AApiName;
  FStatus  := AStatus;

end;

constructor EJxlError.CreateCheck( const ARoutineName: string; const ADetail: string; AStatus: Integer );
begin

  inherited CreateFmt( '%s: %s', [ ARoutineName, ADetail ] );
  FApiName      := ARoutineName;
  FStatus       := AStatus;
  FBindingCheck := True;

end;

{ TJxlMemoryBudget }

const
  /// <summary>
  ///   Bytes in front of every budgeted block, holding its size: 16 keeps the heap's 16-byte alignment on Win64 (8 on
  ///   Win32). libjxl aligns its large buffers itself, so it needs no more.
  /// </summary>
  BUDGET_BLOCK_HEADER = 16;

/// <summary>Allocation callback of <see cref="TJxlMemoryBudget" />; never raises.</summary>
/// <param name="opaque">The budget.</param>
/// <param name="size">Bytes requested.</param>
/// <returns>The block, or <c>nil</c> when the budget or the heap cannot supply it.</returns>
function BudgetAlloc( opaque: Pointer; size: NativeUInt ): Pointer; cdecl;
begin

  Result      := nil;
  var pBudget := PJxlMemoryBudget( opaque );

  if ( size > NativeUInt( High( NativeInt ) ) - BUDGET_BLOCK_HEADER ) then
  begin
    TInterlocked.Increment( pBudget.Refusals );
    Exit;
  end;

  var iSize := Int64( size );
  var iUsed := TInterlocked.Add( pBudget.Used, iSize );

  if ( iUsed > pBudget.Limit ) then
  begin
    TInterlocked.Add( pBudget.Used, -iSize );
    TInterlocked.Increment( pBudget.Refusals );
    Exit;
  end;

  var pBlock := HeapAlloc( GetProcessHeap, 0, size + BUDGET_BLOCK_HEADER );

  if ( not Assigned( pBlock ) ) then
  begin
    TInterlocked.Add( pBudget.Used, -iSize );
    TInterlocked.Increment( pBudget.Refusals );
    Exit;
  end;

  var iPeak := TInterlocked.Read( pBudget.Peak );

  while ( iUsed > iPeak ) and ( TInterlocked.CompareExchange( pBudget.Peak, iUsed, iPeak ) <> iPeak ) do
    iPeak := TInterlocked.Read( pBudget.Peak );

  PNativeUInt( pBlock )^ := size;
  Result := PByte( pBlock ) + BUDGET_BLOCK_HEADER;

end;

/// <summary>Free callback of <see cref="TJxlMemoryBudget" />; does nothing for <c>nil</c>, never raises.</summary>
/// <param name="opaque">The budget.</param>
/// <param name="address">A block from <see cref="BudgetAlloc" />, or <c>nil</c>.</param>
procedure BudgetFree( opaque: Pointer; address: Pointer ); cdecl;
begin

  if ( not Assigned( address ) ) then Exit;

  var pBlock := PByte( address ) - BUDGET_BLOCK_HEADER;
  TInterlocked.Add( PJxlMemoryBudget( opaque ).Used, -Int64( PNativeUInt( pBlock )^ ) );
  HeapFree( GetProcessHeap, 0, pBlock );

end;

procedure TJxlMemoryBudget.Init( ALimit: Int64 );
begin

  Limit    := ALimit;
  Used     := 0;
  Peak     := 0;
  Refusals := 0;

end;

function TJxlMemoryBudget.Manager: JxlMemoryManager;
begin

  Result.opaque := @Self;
  Result.alloc  := BudgetAlloc;
  Result.free   := BudgetFree;

end;

{ Library availability }

function JxlLibraryDirectories: TArray<string>;
begin

  var sOwn := ExtractFilePath( GetModuleName( HInstance ) );
  var sExe := ExtractFilePath( GetModuleName( 0 ) );
  Result := [ sOwn ];

  if ( not SameText( sOwn, sExe ) ) then Result := Result + [ sExe ];

end;

/// <summary>
///   Finds a DLL already loaded in the process, or loads it from the safe folders with critical-error dialogs
///   suppressed.
/// </summary>
/// <param name="AFileName">File name of the DLL (searched for in <see cref="JxlLibraryDirectories" />), or a full path.</param>
/// <param name="AModule">Receives the module handle when the result is <c>True</c>.</param>
/// <param name="ALoaded">Receives whether this call loaded the module, so that the caller owns one reference to it.</param>
/// <param name="APath">Receives the path of the module, or of the last file that failed to load; empty when none was found.</param>
/// <param name="AError">Receives the Windows error code when the result is <c>False</c>.</param>
/// <returns><c>True</c> when the module is loaded.</returns>
function TryLoadModule( const AFileName: string; out AModule: HMODULE; out ALoaded: Boolean; out APath: string;
  out AError: Cardinal ): Boolean;
var
  iOldMode: DWORD;
begin

  AModule := 0;
  ALoaded := False;
  APath   := '';
  AError  := ERROR_MOD_NOT_FOUND;

  var bHasPath := ( ExtractFilePath( AFileName ) <> '' );

  if ( not bHasPath ) then
  begin
    // A DLL of this name already in the process is the one the delay loader binds the imports to.
    AModule := GetModuleHandle( PChar( AFileName ) );

    if ( AModule <> 0 ) then
    begin
      APath := GetModuleName( AModule );
      Exit( True );
    end;

  end;

  var asCandidates: TArray<string> := [ AFileName ];

  if ( not bHasPath ) then
  begin
    asCandidates := nil;

    for var sFolder in JxlLibraryDirectories do asCandidates := asCandidates + [ sFolder + AFileName ];
  end;

  iOldMode := 0;
  SetThreadErrorMode( SEM_FAILCRITICALERRORS or SEM_NOOPENFILEERRORBOX, iOldMode );

  try
    for var sCandidate in asCandidates do
    begin
      if ( not FileExists( sCandidate ) ) then Continue;

      APath   := sCandidate;
      AModule := LoadLibraryEx( PChar( sCandidate ), 0, SAFE_LOAD_FLAGS );

      if ( AModule <> 0 ) then
      begin
        ALoaded := True;
        Exit( True );
      end;

      AError := GetLastError;
    end;

  finally
    SetThreadErrorMode( iOldMode, iOldMode );
  end;

  Result := False;

end;

/// <summary>Creates the exception for a DLL <see cref="TryLoadModule" /> could not load.</summary>
/// <param name="AFileName">The name or path that was asked for.</param>
/// <param name="APath">The file that failed to load, or empty when none was found.</param>
/// <param name="AError">The Windows error code.</param>
/// <param name="AContext">Text put in front of the explanation, e.g. why this DLL was needed; may be empty.</param>
/// <returns>The exception, for the caller to raise.</returns>
function LoadFailure( const AFileName: string; const APath: string; AError: Cardinal; const AContext: string = '' ): EJxlError;
begin

  if ( APath <> '' ) then
    Result := EJxlError.CreateStatus( 'LoadLibraryEx', Integer( AError ), Format( '%s%s, or a DLL it depends on, could not be ' +
      'loaded: %s', [ AContext, APath, SysErrorMessage( AError ) ] ) )
  else if ( ExtractFilePath( AFileName ) <> '' ) then
    Result := EJxlError.CreateStatus( 'LoadLibraryEx', Integer( AError ), Format( '%s%s was not found.', [ AContext, AFileName ] ) )
  else
    Result := EJxlError.CreateStatus( 'LoadLibraryEx', Integer( AError ), Format( '%s%s was not found in %s. The binding loads ' +
      'libjxl only from these folders, never from the current directory or PATH.',
      [ AContext, AFileName, string.Join( ', ', JxlLibraryDirectories ) ] ) );

end;

function JxlModuleAvailable( const AFileName: string ): Boolean;
var
  hLibrary: HMODULE;
  bLoaded: Boolean;
  sPath: string;
  iError: Cardinal;
begin

  Result := TryLoadModule( AFileName, hLibrary, bLoaded, sPath, iError );

  if Result and bLoaded then FreeLibrary( hLibrary );

end;

procedure JxlCheckModule( const AFileName: string );
var
  hLibrary: HMODULE;
  bLoaded: Boolean;
  sPath: string;
  iError: Cardinal;
begin

  if ( not TryLoadModule( AFileName, hLibrary, bLoaded, sPath, iError ) ) then raise LoadFailure( AFileName, sPath, iError );

  if bLoaded then FreeLibrary( hLibrary );

end;

function JxlFindMissingExports( AModule: THandle; const ANames: array of string ): TArray<string>;
begin

  Result := nil;

  for var sName in ANames do
    if ( GetProcAddress( HMODULE( AModule ), PChar( sName ) ) = nil ) then Result := Result + [ sName ];

end;

procedure JxlCheckVersion( AVersion: UInt32; const ALibraryPath: string );
begin

  if ( AVersion < JXL_MIN_VERSION ) then
    raise EJxlError.CreateStatus( 'JxlDecoderVersion', Integer( AVersion ), Format( '%s is libjxl %s; the binding needs %s or later',
      [ if ( ALibraryPath = '' ) then 'the DLL' else ALibraryPath, JxlVersionToString( AVersion ),
      JxlVersionToString( JXL_MIN_VERSION ) ] ) );

end;

/// <summary>Appends names to a list.</summary>
/// <param name="AList">The list to extend.</param>
/// <param name="ANames">The names to append.</param>
procedure AppendNames( var AList: TArray<string>; const ANames: array of string );
begin

  for var sName in ANames do AList := AList + [ sName ];

end;

/// <summary>Returns every function the import units take from one group of the library, from their export tables.</summary>
/// <param name="ARole">The group.</param>
/// <returns>The function names.</returns>
function RoleExports( ARole: TJxlLibraryRole ): TArray<string>;
begin

  Result := nil;

  case ARole of
    jlrMain:
      begin
        AppendNames( Result, JXL_DECODE_EXPORTS );
        AppendNames( Result, JXL_ENCODE_EXPORTS );
        AppendNames( Result, JXL_STATS_EXPORTS );
      end;
    jlrThreads: AppendNames( Result, JXL_THREADS_EXPORTS );
    jlrCms: AppendNames( Result, JXL_CMS_EXPORTS );
  end;

end;

/// <summary>Returns the name to load a library by: its bare file name for the safe folders, or its path in a folder.</summary>
/// <param name="AFolder">The folder, or empty for the safe folders.</param>
/// <param name="AFileName">The library's file name.</param>
/// <returns>The name or path.</returns>
function LibraryFileName( const AFolder: string; const AFileName: string ): string;
begin

  if ( AFolder = '' ) then
    Result := AFileName
  else
    Result := IncludeTrailingPathDelimiter( AFolder ) + AFileName;

end;

/// <summary>Raises <see cref="EJxlError" /> when a loaded module lacks one of a group's functions.</summary>
/// <param name="AModule">The module.</param>
/// <param name="ARole">The group whose functions it must export.</param>
/// <param name="APath">Where the module was loaded from, for the message.</param>
/// <exception cref="EJxlError">A function is missing; <c>ApiName</c> is <c>GetProcAddress</c>.</exception>
procedure VerifyRoleExports( AModule: HMODULE; ARole: TJxlLibraryRole; const APath: string );
begin

  var asMissing := JxlFindMissingExports( AModule, RoleExports( ARole ) );

  if ( Length( asMissing ) > 0 ) then
    raise EJxlError.CreateStatus( 'GetProcAddress', ERROR_PROC_NOT_FOUND, Format( '%s does not export %d of the functions ' +
      'the binding imports (%s), so it is not libjxl %s or later', [ APath, Length( asMissing ), string.Join( ', ', asMissing ),
      JxlVersionToString( JXL_MIN_VERSION ) ] ) );

end;

procedure TJxlResolvedLibraries.Release;
begin

  for var eRole := Low( TJxlLibraryRole ) to High( TJxlLibraryRole ) do
  begin
    if Owned[ eRole ] then FreeLibrary( Modules[ eRole ] );

    Owned[ eRole ] := False;
  end;

end;

/// <summary>
///   Loads the DLL of one group of imports by its declared name, or, when no file of that name exists, by the same
///   name with a <c>lib</c> prefix (as MinGW / MSYS2 builds name them, e.g. <c>libjxl.dll</c>).
/// </summary>
/// <param name="AFolder">The folder to load from, or empty for the safe folders.</param>
/// <param name="ARole">The group.</param>
/// <param name="AResolved">Receives the module and whether this call owns a reference to it.</param>
/// <param name="APath">Receives the path the module was loaded from.</param>
/// <param name="AContext">Text put in front of the failure's explanation; may be empty.</param>
/// <exception cref="EJxlError">Neither name loads; <c>ApiName</c> is <c>LoadLibraryEx</c>.</exception>
procedure LoadRoleModule( const AFolder: string; ARole: TJxlLibraryRole; var AResolved: TJxlResolvedLibraries;
  out APath: string; const AContext: string = '' );
var
  iError: Cardinal;
begin

  var sName := LIBRARY_FILE_NAMES[ ARole ];

  if TryLoadModule( LibraryFileName( AFolder, sName ), AResolved.Modules[ ARole ], AResolved.Owned[ ARole ], APath, iError ) then
    Exit;

  // A file of the declared name that does not load is the fault to report; only an absent one leads to the other name.
  if ( APath = '' ) and TryLoadModule( LibraryFileName( AFolder, 'lib' + sName ), AResolved.Modules[ ARole ],
    AResolved.Owned[ ARole ], APath, iError ) then
    Exit;

  if ( APath <> '' ) then raise LoadFailure( '', APath, iError, AContext );

  raise LoadFailure( Format( '%s (or lib%s)', [ LibraryFileName( AFolder, sName ), sName ] ), '', iError, AContext );

end;

/// <summary>
///   Loads and verifies the libjxl DLL(s), from the safe folders or from one folder, and finds their layout: the main
///   DLL's exports, version and, for each of the thread runners and the CMS, whether the main DLL exports them itself
///   or their own DLL is needed (and then its exports).
/// </summary>
/// <param name="AFolder">The folder to load from, or empty for the safe folders (<see cref="JxlLibraryDirectories" />).</param>
/// <returns>The verified modules; the caller releases them with <see cref="TJxlResolvedLibraries.Release" />.</returns>
/// <exception cref="EJxlError">A DLL cannot be loaded, lacks an export or is too old; nothing stays loaded.</exception>
function ResolveLibraries( const AFolder: string ): TJxlResolvedLibraries;
var
  sMainPath: string;
  sPath: string;
begin

  Result := Default( TJxlResolvedLibraries );

  try
    LoadRoleModule( AFolder, jlrMain, Result, sMainPath );
    VerifyRoleExports( Result.Modules[ jlrMain ], jlrMain, sMainPath );
    JxlCheckVersion( TJxlVersionFunction( GetProcAddress( Result.Modules[ jlrMain ], 'JxlDecoderVersion' ) )( ), sMainPath );
    Result.Layout := jllSingleDll;

    for var eRole := jlrThreads to jlrCms do
    begin
      // A self-contained jxl.dll exports the group itself; upstream's shared build leaves it to its own DLL.
      if ( Length( JxlFindMissingExports( Result.Modules[ jlrMain ], RoleExports( eRole ) ) ) = 0 ) then
      begin
        Result.Modules[ eRole ] := Result.Modules[ jlrMain ];
        Continue;
      end;

      Result.Layout := jllSplitDlls;
      LoadRoleModule( AFolder, eRole, Result, sPath, Format( '%s does not export the %s functions itself, and ',
        [ sMainPath, ROLE_DESCRIPTIONS[ eRole ] ] ) );
      VerifyRoleExports( Result.Modules[ eRole ], eRole, sPath );
    end;

  except
    Result.Release;

    raise;
  end;

end;

/// <summary>
///   Delay-load notification hook installed by <see cref="BindImports" /> once the DLLs are verified: answers the
///   delay loader's <c>dliNotePreLoadLibrary</c> for each libjxl DLL name with the module verified for it, so that no
///   import is resolved by a <c>LoadLibrary</c> search, and the thread-runner and CMS imports of a single-DLL layout
///   bind to <see cref="JXL_LIBRARY" />. Every other notification goes to the hook that was installed before.
/// </summary>
/// <param name="dliNotify">The notification.</param>
/// <param name="pdli">The delay loader's state, naming the DLL.</param>
/// <returns>The module to use, or what the previous hook returns (<c>nil</c> for the default behaviour).</returns>
function BindingNotifyHook( dliNotify: dliNotification; pdli: PDelayLoadInfo ): Pointer; stdcall;
begin

  if ( dliNotify = dliNotePreLoadLibrary ) and Assigned( pdli ) and Assigned( pdli.szDll ) then
  begin
    var sDll := string( pdli.szDll );

    for var eRole := Low( TJxlLibraryRole ) to High( TJxlLibraryRole ) do
      if ( GBindModules[ eRole ] <> 0 ) and SameText( sDll, LIBRARY_FILE_NAMES[ eRole ] ) then
        Exit( Pointer( GBindModules[ eRole ] ) );

  end;

  Result := nil;

  if Assigned( GPreviousNotifyHook ) then Result := GPreviousNotifyHook( dliNotify, pdli );

end;

/// <summary>
///   Pins the verified modules in the process and installs <see cref="BindingNotifyHook" />, so that the delay loader
///   binds every import of the binding to the module verified for it when the import is first called.
/// </summary>
/// <param name="AResolved">The verified modules.</param>
procedure BindImports( const AResolved: TJxlResolvedLibraries );
begin

  for var eRole := Low( TJxlLibraryRole ) to High( TJxlLibraryRole ) do
  begin
    var hPinned: HMODULE := 0;
    GetModuleHandleExW( GET_MODULE_HANDLE_EX_FLAG_PIN or GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
      PWideChar( Pointer( AResolved.Modules[ eRole ] ) ), hPinned );
  end;

  // The modules are set before the hook is installed, so the hook never hands out a module that was not verified.
  GBindModules := AResolved.Modules;

  if ( @DliNotifyHook2( ) <> @BindingNotifyHook ) then
  begin
    GPreviousNotifyHook := DliNotifyHook2( );
    SetDliNotifyHook2( BindingNotifyHook );
  end;

end;

function JxlLibraryAvailable: Boolean;
begin

  try
    JxlCheckLibrary;
    Result := True;
  except
    on EJxlError do Result := False;
  end;

end;

procedure JxlCheckLibrary;
begin

  if GLibraryVerified then Exit;

  GLibraryLock.Enter;

  try
    if GLibraryVerified then Exit;

    var rResolved := ResolveLibraries( '' );
    BindImports( rResolved );
    GLibraryLayout   := rResolved.Layout;
    GLibraryVerified := True;
  finally
    GLibraryLock.Leave;
  end;

end;

function JxlLibraryLayout: TJxlLibraryLayout;
begin

  JxlCheckLibrary;
  Result := GLibraryLayout;

end;

function JxlCheckLibraryFolder( const AFolder: string ): TJxlLibraryLayout;
begin

  if ( Trim( AFolder ) = '' ) then raise EArgumentException.Create( 'JxlCheckLibraryFolder needs a folder.' );

  var rResolved := ResolveLibraries( ExcludeTrailingPathDelimiter( AFolder ) );
  Result        := rResolved.Layout;
  rResolved.Release;

end;

function JxlVersionToString( AVersion: UInt32 ): string;
begin

  Result := Format( '%d.%d.%d', [ AVersion div 1000000, ( AVersion div 1000 ) mod 1000, AVersion mod 1000 ] );

end;

initialization
  GLibraryLock := TCriticalSection.Create;

finalization
  if ( @DliNotifyHook2( ) = @BindingNotifyHook ) then SetDliNotifyHook2( GPreviousNotifyHook );

  GLibraryLock.Free;

end.
