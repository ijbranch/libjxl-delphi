(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Delphi import of the libjxl decoding C API, <c>jxl/decode.h</c>, exported by <c>jxl.dll</c>.
/// </summary>
/// <remarks>
///   The decoder is event driven: subscribe with <see cref="JxlDecoderSubscribeEvents" />, set input with
///   <see cref="JxlDecoderSetInput" />, then loop on <see cref="JxlDecoderProcessInput" /> until it returns
///   <c>JXL_DEC_SUCCESS</c>, answering each event. Names mirror the C header exactly. Every routine is <c>cdecl</c>
///   and delay-loaded: call <c>JxlCheckLibrary</c> before the first call. It loads the DLL from a safe folder and
///   verifies every import; without it, a missing DLL or export ends a Win64 process at the first call, with no
///   exception to catch.
/// </remarks>
unit Jxl.Api.Decode;

{$ALIGN 8}
{$MINENUMSIZE 4}

interface

uses
  Jxl.Api.Types;

type
  /// <summary>Result of <see cref="JxlSignatureCheck" />.</summary>
  /// <remarks>
  ///   <c>JXL_SIG_NOT_ENOUGH_BYTES</c>: too few bytes to decide; <c>JXL_SIG_INVALID</c>: not JPEG XL;
  ///   <c>JXL_SIG_CODESTREAM</c>: a bare JPEG XL codestream; <c>JXL_SIG_CONTAINER</c>: JPEG XL in the box container.
  /// </remarks>
  JxlSignature = (
    JXL_SIG_NOT_ENOUGH_BYTES = 0,
    JXL_SIG_INVALID = 1,
    JXL_SIG_CODESTREAM = 2,
    JXL_SIG_CONTAINER = 3
  );

  /// <summary>Opaque JPEG XL decoder (C <c>JxlDecoder</c>); use through <see cref="PJxlDecoder" />.</summary>
  JxlDecoder = record
  end;
  /// <summary>Handle of a decoder created with <see cref="JxlDecoderCreate" />.</summary>
  PJxlDecoder = ^JxlDecoder;

  /// <summary>Return value of <see cref="JxlDecoderProcessInput" /> and status of most decoder functions.</summary>
  /// <remarks>
  ///   <c>JXL_DEC_SUCCESS</c>: finished, or all subscribed events handled; <c>JXL_DEC_ERROR</c>: invalid input or out
  ///   of memory; <c>JXL_DEC_NEED_MORE_INPUT</c>: release and set more input; <c>JXL_DEC_NEED_PREVIEW_OUT_BUFFER</c>,
  ///   <c>JXL_DEC_NEED_IMAGE_OUT_BUFFER</c>: set an output buffer; <c>JXL_DEC_JPEG_NEED_MORE_OUTPUT</c>,
  ///   <c>JXL_DEC_BOX_NEED_MORE_OUTPUT</c>: the JPEG / box buffer is full. From <c>JXL_DEC_BASIC_INFO</c> on, the values
  ///   are informative events that are returned only when subscribed to, and are OR-ed together (as <c>Ord</c>
  ///   values) for <see cref="JxlDecoderSubscribeEvents" />.
  /// </remarks>
  JxlDecoderStatus = (
    JXL_DEC_SUCCESS = 0,
    JXL_DEC_ERROR = 1,
    JXL_DEC_NEED_MORE_INPUT = 2,
    JXL_DEC_NEED_PREVIEW_OUT_BUFFER = 3,
    JXL_DEC_NEED_IMAGE_OUT_BUFFER = 5,
    JXL_DEC_JPEG_NEED_MORE_OUTPUT = 6,
    JXL_DEC_BOX_NEED_MORE_OUTPUT = 7,
    JXL_DEC_BASIC_INFO = $40,
    JXL_DEC_COLOR_ENCODING = $100,
    JXL_DEC_PREVIEW_IMAGE = $200,
    JXL_DEC_FRAME = $400,
    JXL_DEC_FULL_IMAGE = $1000,
    JXL_DEC_JPEG_RECONSTRUCTION = $2000,
    JXL_DEC_BOX = $4000,
    JXL_DEC_FRAME_PROGRESSION = $8000,
    JXL_DEC_BOX_COMPLETE = $10000
  );

  /// <summary>
  ///   Progressive detail at which <c>JXL_DEC_FRAME_PROGRESSION</c> fires; each level implies every smaller one.
  /// </summary>
  /// <remarks>
  ///   <c>kFrames</c>: after completed frames; <c>kDC</c>: after the 1:8 DC; <c>kLastPasses</c>: after the last AC pass
  ///   of each resolution; <c>kPasses</c>: after every AC pass; <c>kDCProgressive</c>, <c>kDCGroups</c>,
  ///   <c>kGroups</c>: finer steps.
  /// </remarks>
  JxlProgressiveDetail = (
    kFrames = 0,
    kDC = 1,
    kLastPasses = 2,
    kPasses = 3,
    kDCProgressive = 4,
    kDCGroups = 5,
    kGroups = 6
  );

  /// <summary>
  ///   Which colour profile to get: the original image's (<c>JXL_COLOR_PROFILE_TARGET_ORIGINAL</c>) or that of the
  ///   pixel data the decoder outputs (<c>JXL_COLOR_PROFILE_TARGET_DATA</c>).
  /// </summary>
  JxlColorProfileTarget = (
    JXL_COLOR_PROFILE_TARGET_ORIGINAL = 0,
    JXL_COLOR_PROFILE_TARGET_DATA = 1
  );

  /// <summary>Pixel output callback for <see cref="JxlDecoderSetImageOutCallback" />.</summary>
  /// <param name="opaque">The user pointer given to <see cref="JxlDecoderSetImageOutCallback" />.</param>
  /// <param name="x">Horizontal position of the first pixel.</param>
  /// <param name="y">Vertical position of the pixels.</param>
  /// <param name="num_pixels">Number of pixels in the run.</param>
  /// <param name="pixels">The pixels, in the requested format; valid only during the call.</param>
  JxlImageOutCallback = procedure( opaque: Pointer; x: NativeUInt; y: NativeUInt; num_pixels: NativeUInt;
    pixels: Pointer ); cdecl;

  /// <summary>Initialisation callback for <see cref="JxlDecoderSetMultithreadedImageOutCallback" />.</summary>
  /// <param name="init_opaque">The user pointer given to the setter.</param>
  /// <param name="num_threads">Maximum number of threads that will call the run callback.</param>
  /// <param name="num_pixels_per_thread">Maximum number of pixels per run callback.</param>
  /// <returns>Data passed to the run and destroy callbacks as <c>run_opaque</c>.</returns>
  JxlImageOutInitCallback = function( init_opaque: Pointer; num_threads: NativeUInt;
    num_pixels_per_thread: NativeUInt ): Pointer; cdecl;

  /// <summary>Worker callback for <see cref="JxlDecoderSetMultithreadedImageOutCallback" />.</summary>
  /// <param name="run_opaque">Data returned by the init callback.</param>
  /// <param name="thread_id">Index of the calling thread.</param>
  /// <param name="x">Horizontal position of the first pixel.</param>
  /// <param name="y">Vertical position of the pixels.</param>
  /// <param name="num_pixels">Number of pixels in the run.</param>
  /// <param name="pixels">The pixels; valid only during the call.</param>
  JxlImageOutRunCallback = procedure( run_opaque: Pointer; thread_id: NativeUInt; x: NativeUInt; y: NativeUInt;
    num_pixels: NativeUInt; pixels: Pointer ); cdecl;

  /// <summary>Destruction callback for <see cref="JxlDecoderSetMultithreadedImageOutCallback" />.</summary>
  /// <param name="run_opaque">Data returned by the init callback.</param>
  JxlImageOutDestroyCallback = procedure( run_opaque: Pointer ); cdecl;

// `delayed` is marked platform-specific (W1002). The binding is Windows-only by design, and delay loading is
// what lets JxlCheckLibrary report a missing DLL instead of the process failing to start, so the warning is
// silenced for the import declarations only.
{$WARN SYMBOL_PLATFORM OFF}

/// <summary>Decoder library version.</summary>
/// <returns>MAJOR * 1000000 + MINOR * 1000 + PATCH, e.g. 1002003 for 1.2.3.</returns>
function JxlDecoderVersion: UInt32; cdecl; external JXL_LIBRARY delayed;

/// <summary>Checks whether a buffer starts with a JPEG XL signature; the buffer need only be the start of a file.</summary>
/// <param name="buf">The bytes to check.</param>
/// <param name="len">Number of bytes in <paramref name="buf" />.</param>
/// <returns>Whether, and which kind of, JPEG XL signature was found.</returns>
function JxlSignatureCheck( buf: PByte; len: NativeUInt ): JxlSignature; cdecl; external JXL_LIBRARY delayed;

/// <summary>Creates and initialises a decoder.</summary>
/// <param name="memory_manager">Custom allocator, copied internally, or <c>nil</c> for the default.</param>
/// <returns>The decoder, or <c>nil</c> if it cannot be allocated; free it with <see cref="JxlDecoderDestroy" />.</returns>
function JxlDecoderCreate( memory_manager: PJxlMemoryManager ): PJxlDecoder; cdecl; external JXL_LIBRARY delayed;

/// <summary>Re-initialises a decoder for another image; the memory manager is kept.</summary>
/// <remarks>
///   Release a buffer set with <see cref="JxlDecoderSetJPEGBuffer" /> first: up to libjxl 0.12.0 a reset keeps it,
///   so a later JPEG reconstruction on this decoder writes into it after you may have freed it (fixed upstream
///   in #5029).
/// </remarks>
/// <param name="dec">The decoder.</param>
procedure JxlDecoderReset( dec: PJxlDecoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Deinitialises and frees a decoder.</summary>
/// <param name="dec">The decoder.</param>
procedure JxlDecoderDestroy( dec: PJxlDecoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>
///   Rewinds the decoder to the beginning; the same input must be given again. Settings and subscriptions are kept.
/// </summary>
/// <remarks>
///   Release a buffer set with <see cref="JxlDecoderSetJPEGBuffer" /> first: up to libjxl 0.12.0 a rewind keeps it,
///   with the same use-after-free risk as <see cref="JxlDecoderReset" /> (fixed upstream in #5029).
/// </remarks>
/// <param name="dec">The decoder.</param>
procedure JxlDecoderRewind( dec: PJxlDecoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Makes the decoder skip the next frames; calls accumulate.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="amount">Number of frames to skip.</param>
procedure JxlDecoderSkipFrames( dec: PJxlDecoder; amount: NativeUInt ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Skips processing the current frame, between its NEED_IMAGE_OUT_BUFFER and FULL_IMAGE events.</summary>
/// <param name="dec">The decoder.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if there is a frame to skip, <c>JXL_DEC_ERROR</c> if not called during a frame.</returns>
function JxlDecoderSkipCurrentFrame( dec: PJxlDecoder ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the parallel runner for multithreading; only before decoding starts.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="parallel_runner">The runner, or <c>nil</c> for the single-threaded default.</param>
/// <param name="parallel_runner_opaque">The runner's state.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if set, <c>JXL_DEC_ERROR</c> otherwise.</returns>
function JxlDecoderSetParallelRunner( dec: PJxlDecoder; parallel_runner: JxlParallelRunner;
  parallel_runner_opaque: Pointer ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Hints how many more input bytes are needed before the basic info is available.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>The suggested byte count, or 0 when the basic info is already available.</returns>
function JxlDecoderSizeHintBasicInfo( dec: PJxlDecoder ): NativeUInt; cdecl; external JXL_LIBRARY delayed;

/// <summary>Selects the informative events the decoder returns for; only before decoding starts.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="events_wanted">Bitfield of <c>Ord</c> values of the wanted <see cref="JxlDecoderStatus" /> events.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSubscribeEvents( dec: PJxlDecoder; events_wanted: Integer ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Enables or disables keeping the as-in-bitstream orientation instead of applying the Orientation tag.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="skip_reorientation"><see cref="JXL_TRUE" /> to keep the bitstream orientation.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetKeepOrientation( dec: PJxlDecoder; skip_reorientation: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Enables or disables un-premultiplying associated alpha in the returned colours.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="unpremul_alpha"><see cref="JXL_TRUE" /> to return unpremultiplied colours.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetUnpremultiplyAlpha( dec: PJxlDecoder; unpremul_alpha: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Enables (default) or disables rendering spot colours into the colour channels.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="render_spotcolors"><see cref="JXL_TRUE" /> to render spot colours.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetRenderSpotcolors( dec: PJxlDecoder; render_spotcolors: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Enables (default) or disables coalescing of zero-duration frames into full displayed frames.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="coalescing"><see cref="JXL_TRUE" /> to coalesce.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetCoalescing( dec: PJxlDecoder; coalescing: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Decodes using the available input bytes until an event, a need for input or output, or the end.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>
///   <c>JXL_DEC_SUCCESS</c> when finished, <c>JXL_DEC_ERROR</c> on failure, <c>JXL_DEC_NEED_MORE_INPUT</c>, an output
///   request, or a subscribed informative event.
/// </returns>
function JxlDecoderProcessInput( dec: PJxlDecoder ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets input data; the caller owns it and keeps it alive until it is released or the decoder is reset.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="data">The next bytes to read.</param>
/// <param name="size">Number of bytes available at <paramref name="data" />.</param>
/// <returns><c>JXL_DEC_ERROR</c> if input is already set or closed, otherwise <c>JXL_DEC_SUCCESS</c>.</returns>
function JxlDecoderSetInput( dec: PJxlDecoder; data: PByte; size: NativeUInt ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Releases the input set with <see cref="JxlDecoderSetInput" />.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>Number of bytes not yet processed; the next input must start with them.</returns>
function JxlDecoderReleaseInput( dec: PJxlDecoder ): NativeUInt; cdecl; external JXL_LIBRARY delayed;

/// <summary>Marks the input as finished; no more input will be set.</summary>
/// <param name="dec">The decoder.</param>
procedure JxlDecoderCloseInput( dec: PJxlDecoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the basic image information, if available.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="info">Receives the information, or <c>nil</c> to check availability only.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetBasicInfo( dec: PJxlDecoder; info: PJxlBasicInfo ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Outputs information for the extra channel at an index below <c>num_extra_channels</c>.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="info">Receives the information, or <c>nil</c> to check availability only.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetExtraChannelInfo( dec: PJxlDecoder; index: NativeUInt; info: PJxlExtraChannelInfo ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the UTF-8 name of an extra channel; the buffer needs <c>name_length + 1</c> bytes.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="name">Buffer receiving the null-terminated name.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetExtraChannelName( dec: PJxlDecoder; index: NativeUInt; name: PAnsiChar; size: NativeUInt ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the colour profile as structured JPEG XL encoded data, if the image has one.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="target">Original profile or the profile of the decoded pixels.</param>
/// <param name="color_encoding">Receives the encoding, or <c>nil</c> to check availability only.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c>, or <c>JXL_DEC_ERROR</c> when there is none.</returns>
function JxlDecoderGetColorAsEncodedProfile( dec: PJxlDecoder; target: JxlColorProfileTarget;
  color_encoding: PJxlColorEncoding ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the size of the ICC profile returned by <see cref="JxlDecoderGetColorAsICCProfile" />.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="target">Original profile or the profile of the decoded pixels.</param>
/// <param name="size">Receives the size in bytes, or <c>nil</c> to check availability only.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c>, or <c>JXL_DEC_ERROR</c> when unavailable.</returns>
function JxlDecoderGetICCProfileSize( dec: PJxlDecoder; target: JxlColorProfileTarget; size: PNativeUInt ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the ICC profile, if available.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="target">Original profile or the profile of the decoded pixels.</param>
/// <param name="icc_profile">Buffer receiving the profile.</param>
/// <param name="size">Size of the buffer; must equal <see cref="JxlDecoderGetICCProfileSize" />.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetColorAsICCProfile( dec: PJxlDecoder; target: JxlColorProfileTarget; icc_profile: PByte;
  size: NativeUInt ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the preferred output colour profile from a structured colour encoding.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="color_encoding">The preferred colour encoding.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if the preference was set, otherwise <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetPreferredColorProfile( dec: PJxlDecoder; color_encoding: PJxlColorEncoding ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Requests tone mapping to a peak display luminance, if appropriate.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="desired_intensity_target">Peak display luminance in nits.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if the preference was set, otherwise <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetDesiredIntensityTarget( dec: PJxlDecoder; desired_intensity_target: Single ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the output colour profile from a colour encoding or an ICC profile (one of the two).</summary>
/// <param name="dec">The decoder.</param>
/// <param name="color_encoding">The output colour encoding, or <c>nil</c>.</param>
/// <param name="icc_data">The output ICC profile, or <c>nil</c>; needs a CMS set with <see cref="JxlDecoderSetCms" />.</param>
/// <param name="icc_size">Size of the ICC profile in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if set, otherwise <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetOutputColorProfile( dec: PJxlDecoder; color_encoding: PJxlColorEncoding; icc_data: PByte;
  icc_size: NativeUInt ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the colour management system used for colour conversion during decoding.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="cms">The CMS interface, passed by value as in C (see <c>JxlGetDefaultCms</c>).</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetCms( dec: PJxlDecoder; cms: JxlCmsInterface ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the minimum size of the preview output buffer for a pixel format.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer.</param>
/// <param name="size">Receives the size in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. when the information is not available yet.</returns>
function JxlDecoderPreviewOutBufferSize( dec: PJxlDecoder; format: PJxlPixelFormat; size: PNativeUInt ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the buffer the low-resolution preview image is written to.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer.</param>
/// <param name="buffer">The buffer; owned by the caller.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. when the buffer is too small.</returns>
function JxlDecoderSetPreviewOutBuffer( dec: PJxlDecoder; format: PJxlPixelFormat; buffer: Pointer;
  size: NativeUInt ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the header of the current frame (duration, name length, layer information).</summary>
/// <param name="dec">The decoder.</param>
/// <param name="header">Receives the header, or <c>nil</c> to check availability only.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetFrameHeader( dec: PJxlDecoder; header: PJxlFrameHeader ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Outputs the UTF-8 name of the current frame; the buffer needs <c>name_length + 1</c> bytes.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="name">Buffer receiving the null-terminated name.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, <c>JXL_DEC_NEED_MORE_INPUT</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetFrameName( dec: PJxlDecoder; name: PAnsiChar; size: NativeUInt ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Outputs the blend information of one extra channel for the current frame.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="blend_info">Receives the blend information.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderGetExtraChannelBlendInfo( dec: PJxlDecoder; index: NativeUInt; blend_info: PJxlBlendInfo ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the minimum size of the full-resolution image output buffer for a pixel format.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer.</param>
/// <param name="size">Receives the size in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. when the information is not available yet.</returns>
function JxlDecoderImageOutBufferSize( dec: PJxlDecoder; format: PJxlPixelFormat; size: PNativeUInt ): JxlDecoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the buffer the full-resolution image is written to.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer.</param>
/// <param name="buffer">The buffer; owned by the caller.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. when the buffer is too small.</returns>
function JxlDecoderSetImageOutBuffer( dec: PJxlDecoder; format: PJxlPixelFormat; buffer: Pointer;
  size: NativeUInt ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets a callback that receives the image pixels instead of an output buffer.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the pixels passed to the callback.</param>
/// <param name="callback">The callback; may be called from several threads.</param>
/// <param name="opaque">User pointer passed to the callback.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetImageOutCallback( dec: PJxlDecoder; format: PJxlPixelFormat; callback: JxlImageOutCallback;
  opaque: Pointer ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Like <see cref="JxlDecoderSetImageOutCallback" />, with an initialisation phase and per-thread data.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the pixels passed to the callback.</param>
/// <param name="init_callback">Initialisation callback.</param>
/// <param name="run_callback">Worker callback.</param>
/// <param name="destroy_callback">Clean-up callback.</param>
/// <param name="init_opaque">User pointer passed to the init callback.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> or <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderSetMultithreadedImageOutCallback( dec: PJxlDecoder; format: PJxlPixelFormat;
  init_callback: JxlImageOutInitCallback; run_callback: JxlImageOutRunCallback;
  destroy_callback: JxlImageOutDestroyCallback; init_opaque: Pointer ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the minimum size of an extra channel buffer for a pixel format.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer; <c>num_channels</c> is ignored (always 1).</param>
/// <param name="size">Receives the size in bytes.</param>
/// <param name="index">Index of the extra channel.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. for an invalid index.</returns>
function JxlDecoderExtraChannelBufferSize( dec: PJxlDecoder; format: PJxlPixelFormat; size: PNativeUInt;
  index: UInt32 ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the buffer one extra channel is written to.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="format">Pixel format of the buffer.</param>
/// <param name="buffer">The buffer; owned by the caller.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <param name="index">Index of the extra channel.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. when the buffer is too small.</returns>
function JxlDecoderSetExtraChannelBuffer( dec: PJxlDecoder; format: PJxlPixelFormat; buffer: Pointer; size: NativeUInt;
  index: UInt32 ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the output buffer for the reconstructed JPEG codestream.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="data">The buffer; owned by the caller.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_ERROR</c> if a buffer is already set and not released, otherwise <c>JXL_DEC_SUCCESS</c>.</returns>
function JxlDecoderSetJPEGBuffer( dec: PJxlDecoder; data: PByte; size: NativeUInt ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Releases the buffer set with <see cref="JxlDecoderSetJPEGBuffer" />.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>Number of bytes of that buffer not yet written.</returns>
function JxlDecoderReleaseJPEGBuffer( dec: PJxlDecoder ): NativeUInt; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the output buffer for the contents of the current box.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="data">The buffer; owned by the caller.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_DEC_ERROR</c> if a buffer is already set and not released, otherwise <c>JXL_DEC_SUCCESS</c>.</returns>
function JxlDecoderSetBoxBuffer( dec: PJxlDecoder; data: PByte; size: NativeUInt ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Releases the buffer set with <see cref="JxlDecoderSetBoxBuffer" />.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>Number of bytes of that buffer not yet written.</returns>
function JxlDecoderReleaseBoxBuffer( dec: PJxlDecoder ): NativeUInt; cdecl; external JXL_LIBRARY delayed;

/// <summary>Configures whether boxes are output raw or Brotli-decompressed (for <c>brob</c> boxes).</summary>
/// <param name="dec">The decoder.</param>
/// <param name="decompress"><see cref="JXL_TRUE" /> to decompress.</param>
/// <returns><c>JXL_DEC_ERROR</c> if decompression is requested without Brotli, otherwise <c>JXL_DEC_SUCCESS</c>.</returns>
function JxlDecoderSetDecompressBoxes( dec: PJxlDecoder; decompress: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Outputs the 4-character type of the current box, after a <c>JXL_DEC_BOX</c> event.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="type_">Receives the box type (C parameter <c>type</c>).</param>
/// <param name="decompressed"><see cref="JXL_TRUE" /> for the decompressed type of a <c>brob</c> box.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> when not available.</returns>
function JxlDecoderGetBoxType( dec: PJxlDecoder; var type_: JxlBoxType; decompressed: JXL_BOOL ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Returns the size of the current box as it appears in the container file.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="size">Receives the size in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> when no size is available.</returns>
function JxlDecoderGetBoxSizeRaw( dec: PJxlDecoder; size: PUInt64 ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the size of the contents of the current box.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="size">Receives the size in bytes.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> when no size is available.</returns>
function JxlDecoderGetBoxSizeContents( dec: PJxlDecoder; size: PUInt64 ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Configures the progressive steps at which <c>JXL_DEC_FRAME_PROGRESSION</c> fires.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="detail">The progressive detail.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> for an invalid value.</returns>
function JxlDecoderSetProgressiveDetail( dec: PJxlDecoder; detail: JxlProgressiveDetail ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Returns the intended downsampling ratio of the image flushed after the latest progression event.</summary>
/// <param name="dec">The decoder.</param>
/// <returns>1, 2, 4 or 8.</returns>
function JxlDecoderGetIntendedDownsamplingRatio( dec: PJxlDecoder ): NativeUInt; cdecl; external JXL_LIBRARY delayed;

/// <summary>Outputs the image decoded so far into the output buffer when only part of the input has arrived.</summary>
/// <param name="dec">The decoder.</param>
/// <returns><c>JXL_DEC_SUCCESS</c> if data was flushed, otherwise <c>JXL_DEC_ERROR</c>.</returns>
function JxlDecoderFlushImage( dec: PJxlDecoder ): JxlDecoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the bit depth of the output buffer or callback.</summary>
/// <param name="dec">The decoder.</param>
/// <param name="bit_depth">The bit depth setting.</param>
/// <returns><c>JXL_DEC_SUCCESS</c>, or <c>JXL_DEC_ERROR</c> e.g. for a custom depth incompatible with the data type.</returns>
function JxlDecoderSetImageOutBitDepth( dec: PJxlDecoder; bit_depth: PJxlBitDepth ): JxlDecoderStatus; cdecl;
  external JXL_LIBRARY delayed;

{$WARN SYMBOL_PLATFORM DEFAULT}

const
  /// <summary>
  ///   Every function this unit imports from <see cref="JXL_LIBRARY" />; <c>JxlCheckLibrary</c> verifies that the
  ///   DLL exports each one before any of them is called. Keep it in step with the declarations above.
  /// </summary>
  JXL_DECODE_EXPORTS: array[ 0..51 ] of string = (
    NameOf( JxlDecoderVersion ),
    NameOf( JxlSignatureCheck ),
    NameOf( JxlDecoderCreate ),
    NameOf( JxlDecoderReset ),
    NameOf( JxlDecoderDestroy ),
    NameOf( JxlDecoderRewind ),
    NameOf( JxlDecoderSkipFrames ),
    NameOf( JxlDecoderSkipCurrentFrame ),
    NameOf( JxlDecoderSetParallelRunner ),
    NameOf( JxlDecoderSizeHintBasicInfo ),
    NameOf( JxlDecoderSubscribeEvents ),
    NameOf( JxlDecoderSetKeepOrientation ),
    NameOf( JxlDecoderSetUnpremultiplyAlpha ),
    NameOf( JxlDecoderSetRenderSpotcolors ),
    NameOf( JxlDecoderSetCoalescing ),
    NameOf( JxlDecoderProcessInput ),
    NameOf( JxlDecoderSetInput ),
    NameOf( JxlDecoderReleaseInput ),
    NameOf( JxlDecoderCloseInput ),
    NameOf( JxlDecoderGetBasicInfo ),
    NameOf( JxlDecoderGetExtraChannelInfo ),
    NameOf( JxlDecoderGetExtraChannelName ),
    NameOf( JxlDecoderGetColorAsEncodedProfile ),
    NameOf( JxlDecoderGetICCProfileSize ),
    NameOf( JxlDecoderGetColorAsICCProfile ),
    NameOf( JxlDecoderSetPreferredColorProfile ),
    NameOf( JxlDecoderSetDesiredIntensityTarget ),
    NameOf( JxlDecoderSetOutputColorProfile ),
    NameOf( JxlDecoderSetCms ),
    NameOf( JxlDecoderPreviewOutBufferSize ),
    NameOf( JxlDecoderSetPreviewOutBuffer ),
    NameOf( JxlDecoderGetFrameHeader ),
    NameOf( JxlDecoderGetFrameName ),
    NameOf( JxlDecoderGetExtraChannelBlendInfo ),
    NameOf( JxlDecoderImageOutBufferSize ),
    NameOf( JxlDecoderSetImageOutBuffer ),
    NameOf( JxlDecoderSetImageOutCallback ),
    NameOf( JxlDecoderSetMultithreadedImageOutCallback ),
    NameOf( JxlDecoderExtraChannelBufferSize ),
    NameOf( JxlDecoderSetExtraChannelBuffer ),
    NameOf( JxlDecoderSetJPEGBuffer ),
    NameOf( JxlDecoderReleaseJPEGBuffer ),
    NameOf( JxlDecoderSetBoxBuffer ),
    NameOf( JxlDecoderReleaseBoxBuffer ),
    NameOf( JxlDecoderSetDecompressBoxes ),
    NameOf( JxlDecoderGetBoxType ),
    NameOf( JxlDecoderGetBoxSizeRaw ),
    NameOf( JxlDecoderGetBoxSizeContents ),
    NameOf( JxlDecoderSetProgressiveDetail ),
    NameOf( JxlDecoderGetIntendedDownsamplingRatio ),
    NameOf( JxlDecoderFlushImage ),
    NameOf( JxlDecoderSetImageOutBitDepth )
  );

implementation

end.
