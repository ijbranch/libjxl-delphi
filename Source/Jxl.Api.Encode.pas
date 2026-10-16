(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Delphi import of the libjxl encoding C API, <c>jxl/encode.h</c>, exported by <c>jxl.dll</c>.
/// </summary>
/// <remarks>
///   Typical use: <see cref="JxlEncoderCreate" />, <see cref="JxlEncoderSetBasicInfo" />, a colour encoding, a frame
///   settings object from <see cref="JxlEncoderFrameSettingsCreate" />, <see cref="JxlEncoderAddImageFrame" /> (or
///   <see cref="JxlEncoderAddJPEGFrame" /> for lossless JPEG recompression), <see cref="JxlEncoderCloseInput" />, then
///   <see cref="JxlEncoderProcessOutput" /> until it stops returning <c>JXL_ENC_NEED_MORE_OUTPUT</c>. Names mirror
///   the C header exactly. Every routine is <c>cdecl</c> and delay-loaded: call <c>JxlCheckLibrary</c> before the first
///   call. It loads the DLL from a safe folder and verifies every import; without it, a missing DLL or export ends a
///   Win64 process at the first call, with no exception to catch.
/// </remarks>
unit Jxl.Api.Encode;

{$ALIGN 8}
{$MINENUMSIZE 4}

interface

uses
  Jxl.Api.Types;

type
  /// <summary>Opaque JPEG XL encoder (C <c>JxlEncoder</c>); use through <see cref="PJxlEncoder" />.</summary>
  JxlEncoder = record
  end;
  /// <summary>Handle of an encoder created with <see cref="JxlEncoderCreate" />.</summary>
  PJxlEncoder = ^JxlEncoder;

  /// <summary>
  ///   Opaque per-frame settings and metadata (C <c>JxlEncoderFrameSettings</c>); use through
  ///   <see cref="PJxlEncoderFrameSettings" />.
  /// </summary>
  JxlEncoderFrameSettings = record
  end;
  /// <summary>Handle of frame settings created with <see cref="JxlEncoderFrameSettingsCreate" />; freed with the encoder.</summary>
  PJxlEncoderFrameSettings = ^JxlEncoderFrameSettings;

  /// <summary>Return value of the encoder functions.</summary>
  /// <remarks>
  ///   <c>JXL_ENC_SUCCESS</c>: done; <c>JXL_ENC_ERROR</c>: failed, see <see cref="JxlEncoderGetError" />;
  ///   <c>JXL_ENC_NEED_MORE_OUTPUT</c>: more output buffer is needed.
  /// </remarks>
  JxlEncoderStatus = (
    JXL_ENC_SUCCESS = 0,
    JXL_ENC_ERROR = 1,
    JXL_ENC_NEED_MORE_OUTPUT = 2
  );

  /// <summary>Error conditions; API usage errors have bit $80 set.</summary>
  /// <remarks>
  ///   <c>JXL_ENC_ERR_OK</c>: none; <c>JXL_ENC_ERR_GENERIC</c>: unspecified; <c>JXL_ENC_ERR_OOM</c>: out of memory;
  ///   <c>JXL_ENC_ERR_JBRD</c>: JPEG reconstruction data cannot be represented; <c>JXL_ENC_ERR_BAD_INPUT</c>: invalid
  ///   input such as a corrupt JPEG or ICC profile; <c>JXL_ENC_ERR_NOT_SUPPORTED</c>: not supported;
  ///   <c>JXL_ENC_ERR_API_USAGE</c>: the API was used incorrectly.
  /// </remarks>
  JxlEncoderError = (
    JXL_ENC_ERR_OK = 0,
    JXL_ENC_ERR_GENERIC = 1,
    JXL_ENC_ERR_OOM = 2,
    JXL_ENC_ERR_JBRD = 3,
    JXL_ENC_ERR_BAD_INPUT = 4,
    JXL_ENC_ERR_NOT_SUPPORTED = $80,
    JXL_ENC_ERR_API_USAGE = $81
  );

  /// <summary>Id of a per-frame encoder option, set with <see cref="JxlEncoderFrameSettingsSetOption" />.</summary>
  /// <remarks>
  ///   The most used: <c>JXL_ENC_FRAME_SETTING_EFFORT</c> (1 lightning .. 10 glacier, default 7),
  ///   <c>JXL_ENC_FRAME_SETTING_DECODING_SPEED</c> (0-4), <c>JXL_ENC_FRAME_SETTING_MODULAR</c>,
  ///   <c>JXL_ENC_FRAME_SETTING_BROTLI_EFFORT</c>, <c>JXL_ENC_FRAME_SETTING_BUFFERING</c> and the
  ///   <c>JXL_ENC_FRAME_SETTING_JPEG_*</c> options for JPEG recompression. The meaning and range of every id is
  ///   documented at the matching enumerator in <c>jxl/encode.h</c>. <c>JXL_ENC_FRAME_SETTING_FILL_ENUM</c> is not an
  ///   option. The ids are those of libjxl 0.12.0; the ids libjxl's development branch has added since
  ///   (<c>JXL_ENC_FRAME_SETTING_STRIP_ALPHA</c> = 41, <c>JXL_ENC_FRAME_SETTING_JPEG_RECON_LFS</c> = 42) will be added
  ///   when a libjxl release includes them.
  /// </remarks>
  JxlEncoderFrameSettingId = (
    JXL_ENC_FRAME_SETTING_EFFORT = 0,
    JXL_ENC_FRAME_SETTING_DECODING_SPEED = 1,
    JXL_ENC_FRAME_SETTING_RESAMPLING = 2,
    JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING = 3,
    JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED = 4,
    JXL_ENC_FRAME_SETTING_PHOTON_NOISE = 5,
    JXL_ENC_FRAME_SETTING_NOISE = 6,
    JXL_ENC_FRAME_SETTING_DOTS = 7,
    JXL_ENC_FRAME_SETTING_PATCHES = 8,
    JXL_ENC_FRAME_SETTING_EPF = 9,
    JXL_ENC_FRAME_SETTING_GABORISH = 10,
    JXL_ENC_FRAME_SETTING_MODULAR = 11,
    JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE = 12,
    JXL_ENC_FRAME_SETTING_GROUP_ORDER = 13,
    JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X = 14,
    JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y = 15,
    JXL_ENC_FRAME_SETTING_RESPONSIVE = 16,
    JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC = 17,
    JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC = 18,
    JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC = 19,
    JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT = 20,
    JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT = 21,
    JXL_ENC_FRAME_SETTING_PALETTE_COLORS = 22,
    JXL_ENC_FRAME_SETTING_LOSSY_PALETTE = 23,
    JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM = 24,
    JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE = 25,
    JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE = 26,
    JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR = 27,
    JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT = 28,
    JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS = 29,
    JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL = 30,
    JXL_ENC_FRAME_INDEX_BOX = 31,
    JXL_ENC_FRAME_SETTING_BROTLI_EFFORT = 32,
    JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES = 33,
    JXL_ENC_FRAME_SETTING_BUFFERING = 34,
    JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF = 35,
    JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP = 36,
    JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF = 37,
    JXL_ENC_FRAME_SETTING_USE_FULL_IMAGE_HEURISTICS = 38,
    JXL_ENC_FRAME_SETTING_DISABLE_PERCEPTUAL_HEURISTICS = 39,
    JXL_ENC_FRAME_SETTING_OUTPUT_MODE = 40,
    JXL_ENC_FRAME_SETTING_FILL_ENUM = 65535
  );

  /// <summary>Output processor callback: acquires an output buffer.</summary>
  /// <param name="opaque">The processor's <c>opaque</c> pointer.</param>
  /// <param name="size">In: the requested minimum size; out: the size of the buffer returned.</param>
  /// <returns>The buffer, or <c>nil</c> to stop encoding.</returns>
  JxlEncoderOutputGetBufferFunc = function( opaque: Pointer; size: PNativeUInt ): Pointer; cdecl;

  /// <summary>Output processor callback: releases the buffer after the encoder wrote to it.</summary>
  /// <param name="opaque">The processor's <c>opaque</c> pointer.</param>
  /// <param name="written_bytes">Number of bytes written to the buffer.</param>
  JxlEncoderOutputReleaseBufferFunc = procedure( opaque: Pointer; written_bytes: NativeUInt ); cdecl;

  /// <summary>Output processor callback: seeks to a position in the output.</summary>
  /// <param name="opaque">The processor's <c>opaque</c> pointer.</param>
  /// <param name="position">The position to seek to.</param>
  JxlEncoderOutputSeekFunc = procedure( opaque: Pointer; position: UInt64 ); cdecl;

  /// <summary>Output processor callback: bytes before this position are final and will not be revisited.</summary>
  /// <param name="opaque">The processor's <c>opaque</c> pointer.</param>
  /// <param name="finalized_position">The finalised position.</param>
  JxlEncoderOutputSetFinalizedPositionFunc = procedure( opaque: Pointer; finalized_position: UInt64 ); cdecl;

  /// <summary>Interface for the encoder's output processing, passed by value to <see cref="JxlEncoderSetOutputProcessor" />.</summary>
  JxlEncoderOutputProcessor = record
    /// <summary>Required. User data passed to every callback.</summary>
    opaque: Pointer;
    /// <summary>Required. Acquires an output buffer.</summary>
    get_buffer: JxlEncoderOutputGetBufferFunc;
    /// <summary>Required. Releases the current output buffer.</summary>
    release_buffer: JxlEncoderOutputReleaseBufferFunc;
    /// <summary>Optional (<c>nil</c> allowed). Seeks to a position in the output.</summary>
    seek: JxlEncoderOutputSeekFunc;
    /// <summary>Required. Reports the position before which output is final.</summary>
    set_finalized_position: JxlEncoderOutputSetFinalizedPositionFunc;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlEncoderOutputProcessor" />.</summary>
  TJxlEncoderOutputProcessor = JxlEncoderOutputProcessor;

  /// <summary>Chunked input callback: reports the pixel format of the colour channel data.</summary>
  /// <param name="opaque">The source's <c>opaque</c> pointer.</param>
  /// <param name="pixel_format">Receives the pixel format.</param>
  JxlChunkedGetColorChannelsPixelFormatFunc = procedure( opaque: Pointer; pixel_format: PJxlPixelFormat ); cdecl;

  /// <summary>Chunked input callback: returns a rectangle of colour channel data.</summary>
  /// <param name="opaque">The source's <c>opaque</c> pointer.</param>
  /// <param name="xpos">Left of the rectangle.</param>
  /// <param name="ypos">Top of the rectangle.</param>
  /// <param name="xsize">Width of the rectangle.</param>
  /// <param name="ysize">Height of the rectangle.</param>
  /// <param name="row_offset">Receives the distance in bytes between rows of the returned data.</param>
  /// <returns>Pointer to the pixel data, valid until released.</returns>
  JxlChunkedGetColorChannelDataAtFunc = function( opaque: Pointer; xpos: NativeUInt; ypos: NativeUInt; xsize: NativeUInt;
    ysize: NativeUInt; row_offset: PNativeUInt ): Pointer; cdecl;

  /// <summary>Chunked input callback: reports the pixel format of an extra channel.</summary>
  /// <param name="opaque">The source's <c>opaque</c> pointer.</param>
  /// <param name="ec_index">Index of the extra channel.</param>
  /// <param name="pixel_format">Receives the pixel format.</param>
  JxlChunkedGetExtraChannelPixelFormatFunc = procedure( opaque: Pointer; ec_index: NativeUInt;
    pixel_format: PJxlPixelFormat ); cdecl;

  /// <summary>Chunked input callback: returns a rectangle of extra channel data.</summary>
  /// <param name="opaque">The source's <c>opaque</c> pointer.</param>
  /// <param name="ec_index">Index of the extra channel.</param>
  /// <param name="xpos">Left of the rectangle.</param>
  /// <param name="ypos">Top of the rectangle.</param>
  /// <param name="xsize">Width of the rectangle.</param>
  /// <param name="ysize">Height of the rectangle.</param>
  /// <param name="row_offset">Receives the distance in bytes between rows of the returned data.</param>
  /// <returns>Pointer to the pixel data, valid until released.</returns>
  JxlChunkedGetExtraChannelDataAtFunc = function( opaque: Pointer; ec_index: NativeUInt; xpos: NativeUInt; ypos: NativeUInt;
    xsize: NativeUInt; ysize: NativeUInt; row_offset: PNativeUInt ): Pointer; cdecl;

  /// <summary>Chunked input callback: releases a buffer returned by one of the data callbacks.</summary>
  /// <param name="opaque">The source's <c>opaque</c> pointer.</param>
  /// <param name="buf">The buffer to release.</param>
  JxlChunkedReleaseBufferFunc = procedure( opaque: Pointer; buf: Pointer ); cdecl;

  /// <summary>
  ///   Streaming pixel source for <see cref="JxlEncoderAddChunkedFrame" />, passed by value; avoids holding a whole
  ///   frame in memory.
  /// </summary>
  JxlChunkedFrameInputSource = record
    /// <summary>User data passed to every callback.</summary>
    opaque: Pointer;
    /// <summary>Reports the pixel format of the colour channel data.</summary>
    get_color_channels_pixel_format: JxlChunkedGetColorChannelsPixelFormatFunc;
    /// <summary>Returns a rectangle of colour channel data.</summary>
    get_color_channel_data_at: JxlChunkedGetColorChannelDataAtFunc;
    /// <summary>Reports the pixel format of an extra channel.</summary>
    get_extra_channel_pixel_format: JxlChunkedGetExtraChannelPixelFormatFunc;
    /// <summary>Returns a rectangle of extra channel data.</summary>
    get_extra_channel_data_at: JxlChunkedGetExtraChannelDataAtFunc;
    /// <summary>Releases a buffer returned by the data callbacks.</summary>
    release_buffer: JxlChunkedReleaseBufferFunc;
  end;
  /// <summary>Pascal-style alias of <see cref="JxlChunkedFrameInputSource" />.</summary>
  TJxlChunkedFrameInputSource = JxlChunkedFrameInputSource;

  /// <summary>Debug image callback for <see cref="JxlEncoderSetDebugImageCallback" />.</summary>
  /// <param name="opaque">The user pointer given to the setter.</param>
  /// <param name="label_">Name of the debug image (C parameter <c>label</c>).</param>
  /// <param name="xsize">Width of the image.</param>
  /// <param name="ysize">Height of the image.</param>
  /// <param name="color">Colour encoding of the image.</param>
  /// <param name="pixels">Interleaved 16-bit RGB samples.</param>
  JxlDebugImageCallback = procedure( opaque: Pointer; label_: PAnsiChar; xsize: NativeUInt; ysize: NativeUInt;
    color: PJxlColorEncoding; pixels: PWord ); cdecl;

// `delayed` is marked platform-specific (W1002). The binding is Windows-only by design, and delay loading is
// what lets JxlCheckLibrary report a missing DLL instead of the process failing to start, so the warning is
// silenced for the import declarations only.
{$WARN SYMBOL_PLATFORM OFF}

/// <summary>Encoder library version.</summary>
/// <returns>MAJOR * 1000000 + MINOR * 1000 + PATCH, e.g. 1002003 for 1.2.3.</returns>
function JxlEncoderVersion: UInt32; cdecl; external JXL_LIBRARY delayed;

/// <summary>Creates and initialises an encoder.</summary>
/// <param name="memory_manager">Custom allocator, copied internally, or <c>nil</c> for the default.</param>
/// <returns>The encoder, or <c>nil</c> if it cannot be allocated; free it with <see cref="JxlEncoderDestroy" />.</returns>
function JxlEncoderCreate( memory_manager: PJxlMemoryManager ): PJxlEncoder; cdecl; external JXL_LIBRARY delayed;

/// <summary>Re-initialises an encoder for another image; frame settings created for it become invalid.</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderReset( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Deinitialises and frees an encoder and every frame settings object created for it.</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderDestroy( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the colour management system used for colour conversion during encoding.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="cms">The CMS interface, passed by value as in C (see <c>JxlGetDefaultCms</c>).</param>
procedure JxlEncoderSetCms( enc: PJxlEncoder; cms: JxlCmsInterface ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the parallel runner for multithreading; only before encoding starts.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="parallel_runner">The runner, or <c>nil</c> for the single-threaded default.</param>
/// <param name="parallel_runner_opaque">The runner's state.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> if set, <c>JXL_ENC_ERROR</c> otherwise.</returns>
function JxlEncoderSetParallelRunner( enc: PJxlEncoder; parallel_runner: JxlParallelRunner;
  parallel_runner_opaque: Pointer ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the last error code after a function returned <c>JXL_ENC_ERROR</c>.</summary>
/// <param name="enc">The encoder.</param>
/// <returns>The error code.</returns>
function JxlEncoderGetError( enc: PJxlEncoder ): JxlEncoderError; cdecl; external JXL_LIBRARY delayed;

/// <summary>Encodes into the output buffer, advancing the pointer and decreasing the available size.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="next_out">In/out: where the next byte is written.</param>
/// <param name="avail_out">In/out: bytes available at <paramref name="next_out" />.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> when finished, <c>JXL_ENC_NEED_MORE_OUTPUT</c>, or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderProcessOutput( enc: PJxlEncoder; next_out: PPByte; avail_out: PNativeUInt ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the frame header (duration, name length, layer information) for the next frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="frame_header">The frame header.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetFrameHeader( frame_settings: PJxlEncoderFrameSettings; frame_header: PJxlFrameHeader ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the blend information of an extra channel for the next frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="blend_info">The blend information.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetExtraChannelBlendInfo( frame_settings: PJxlEncoderFrameSettings; index: NativeUInt;
  blend_info: PJxlBlendInfo ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the name of the next animation frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="frame_name">Null-terminated UTF-8 name.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetFrameName( frame_settings: PJxlEncoderFrameSettings; frame_name: PAnsiChar ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the bit depth of the input buffer.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="bit_depth">The bit depth setting.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetFrameBitDepth( frame_settings: PJxlEncoderFrameSettings; bit_depth: PJxlBitDepth ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Adds a JPEG file as the next frame, recompressing it losslessly.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="buffer">The JPEG file bytes; copied by the call.</param>
/// <param name="size">Size of the JPEG file in bytes.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderAddJPEGFrame( frame_settings: PJxlEncoderFrameSettings; buffer: PByte; size: NativeUInt ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Adds the pixels of the next frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="pixel_format">Pixel format of the buffer.</param>
/// <param name="buffer">The pixels; copied by the call.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderAddImageFrame( frame_settings: PJxlEncoderFrameSettings; pixel_format: PJxlPixelFormat; buffer: Pointer;
  size: NativeUInt ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets an output processor, used instead of <see cref="JxlEncoderProcessOutput" />.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="output_processor">The output processor, passed by value as in C.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetOutputProcessor( enc: PJxlEncoder; output_processor: JxlEncoderOutputProcessor ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Flushes buffered input to the output processor.</summary>
/// <param name="enc">The encoder.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderFlushInput( enc: PJxlEncoder ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Adds a frame whose pixels are pulled from a chunked input source.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="is_last_frame"><see cref="JXL_TRUE" /> if this is the last frame.</param>
/// <param name="chunked_frame_input">The input source, passed by value as in C.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderAddChunkedFrame( frame_settings: PJxlEncoderFrameSettings; is_last_frame: JXL_BOOL;
  chunked_frame_input: JxlChunkedFrameInputSource ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the pixels of one extra channel of the next frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="pixel_format">Pixel format of the buffer; <c>num_channels</c> is ignored (always 1).</param>
/// <param name="buffer">The pixels; copied by the call.</param>
/// <param name="size">Size of the buffer in bytes.</param>
/// <param name="index">Index of the extra channel.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetExtraChannelBuffer( frame_settings: PJxlEncoderFrameSettings; pixel_format: PJxlPixelFormat;
  buffer: Pointer; size: NativeUInt; index: UInt32 ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Adds a metadata box (e.g. <c>Exif</c>, <c>xml </c>, <c>jumb</c>); needs <see cref="JxlEncoderUseBoxes" />.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="type_">The 4-character box type (C parameter <c>type</c>).</param>
/// <param name="contents">The box contents.</param>
/// <param name="size">Size of the contents in bytes.</param>
/// <param name="compress_box"><see cref="JXL_TRUE" /> to Brotli-compress the box into a <c>brob</c> box.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderAddBox( enc: PJxlEncoder; const [ ref ] type_: JxlBoxType; contents: PByte; size: NativeUInt;
  compress_box: JXL_BOOL ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Declares that metadata boxes will be added.</summary>
/// <param name="enc">The encoder.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderUseBoxes( enc: PJxlEncoder ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Declares that no further boxes will be added.</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderCloseBoxes( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Declares that no further frames will be added.</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderCloseFrames( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Closes all input: equivalent to closing frames and, where used, boxes.</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderCloseInput( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the original colour encoding of the image as structured data.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="color">The colour encoding.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetColorEncoding( enc: PJxlEncoder; color: PJxlColorEncoding ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the original colour encoding of the image as an ICC profile.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="icc_profile">The ICC profile.</param>
/// <param name="size">Size of the profile in bytes.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetICCProfile( enc: PJxlEncoder; icc_profile: PByte; size: NativeUInt ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Initialises a basic info record to default values; call it before filling the fields in.</summary>
/// <param name="info">The record to initialise.</param>
procedure JxlEncoderInitBasicInfo( info: PJxlBasicInfo ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Initialises a frame header record to default values.</summary>
/// <param name="frame_header">The record to initialise.</param>
procedure JxlEncoderInitFrameHeader( frame_header: PJxlFrameHeader ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Initialises a blend info record to default values.</summary>
/// <param name="blend_info">The record to initialise.</param>
procedure JxlEncoderInitBlendInfo( blend_info: PJxlBlendInfo ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the global metadata of the image.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="info">The basic info; initialise it with <see cref="JxlEncoderInitBasicInfo" />.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetBasicInfo( enc: PJxlEncoder; info: PJxlBasicInfo ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the upsampling method the decoder uses for resampled frames.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="factor">Upsampling factor: 1 (no effect), 2, 4 or 8.</param>
/// <param name="mode">-1 default (photographic), 0 nearest neighbour (pixel art), 1 pixel dots.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetUpsamplingMode( enc: PJxlEncoder; factor: Int64; mode: Int64 ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Initialises an extra channel info record to default values for a channel type.</summary>
/// <param name="type_">The extra channel type (C parameter <c>type</c>).</param>
/// <param name="info">The record to initialise.</param>
procedure JxlEncoderInitExtraChannelInfo( type_: JxlExtraChannelType; info: PJxlExtraChannelInfo ); cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets information for the extra channel at an index.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="info">The extra channel information.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetExtraChannelInfo( enc: PJxlEncoder; index: NativeUInt; info: PJxlExtraChannelInfo ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets the UTF-8 name of the extra channel at an index.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="name">The name.</param>
/// <param name="size">Length of the name in bytes, excluding any null.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetExtraChannelName( enc: PJxlEncoder; index: NativeUInt; name: PAnsiChar; size: NativeUInt ): JxlEncoderStatus;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets an integer frame option.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="option">The option id.</param>
/// <param name="value">The value; -1 restores the default for most options.</param>
/// <returns><c>JXL_ENC_SUCCESS</c>, or <c>JXL_ENC_ERROR</c> for an invalid option or value.</returns>
function JxlEncoderFrameSettingsSetOption( frame_settings: PJxlEncoderFrameSettings; option: JxlEncoderFrameSettingId;
  value: Int64 ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets a floating-point frame option.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="option">The option id.</param>
/// <param name="value">The value.</param>
/// <returns><c>JXL_ENC_SUCCESS</c>, or <c>JXL_ENC_ERROR</c> for an invalid option or value.</returns>
function JxlEncoderFrameSettingsSetFloatOption( frame_settings: PJxlEncoderFrameSettings; option: JxlEncoderFrameSettingId;
  value: Single ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Forces the box-based container format even when it is not needed.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="use_container"><see cref="JXL_TRUE" /> to force the container.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderUseContainer( enc: PJxlEncoder; use_container: JXL_BOOL ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Stores JPEG reconstruction metadata, so a recompressed JPEG can be restored byte for byte.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="store_jpeg_metadata"><see cref="JXL_TRUE" /> to store the metadata.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderStoreJPEGMetadata( enc: PJxlEncoder; store_jpeg_metadata: JXL_BOOL ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the feature level of the codestream: 5 or 10, or -1 to choose from the basic info.</summary>
/// <param name="enc">The encoder.</param>
/// <param name="level">-1, 5 or 10.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetCodestreamLevel( enc: PJxlEncoder; level: Integer ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Returns the codestream level required by the current settings and basic info.</summary>
/// <param name="enc">The encoder.</param>
/// <returns>-1 if no level supports them, otherwise 5 or 10.</returns>
function JxlEncoderGetRequiredCodestreamLevel( enc: PJxlEncoder ): Integer; cdecl; external JXL_LIBRARY delayed;

/// <summary>Enables lossless encoding of the frame.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="lossless"><see cref="JXL_TRUE" /> for lossless.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetFrameLossless( frame_settings: PJxlEncoderFrameSettings; lossless: JXL_BOOL ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the lossy distance: target maximum Butteraugli distance; lower is higher quality.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="distance">0.0 mathematically lossless, 1.0 visually lossless (default), recommended 0.5-3.0, max 25.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetFrameDistance( frame_settings: PJxlEncoderFrameSettings; distance: Single ): JxlEncoderStatus; cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets the lossy distance of one extra channel.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="index">Index of the extra channel.</param>
/// <param name="distance">The distance, or -1 to use the frame distance.</param>
/// <returns><c>JXL_ENC_SUCCESS</c> or <c>JXL_ENC_ERROR</c>.</returns>
function JxlEncoderSetExtraChannelDistance( frame_settings: PJxlEncoderFrameSettings; index: NativeUInt;
  distance: Single ): JxlEncoderStatus; cdecl; external JXL_LIBRARY delayed;

/// <summary>Maps a JPEG-style quality factor (0-100) to a distance.</summary>
/// <param name="quality">The quality; 100 maps to 0.0 (lossless).</param>
/// <returns>The distance.</returns>
function JxlEncoderDistanceFromQuality( quality: Single ): Single; cdecl; external JXL_LIBRARY delayed;

/// <summary>Creates frame settings, copied from <paramref name="source" /> or defaulted when it is <c>nil</c>.</summary>
/// <param name="enc">The encoder that owns the settings and frees them on destruction.</param>
/// <param name="source">Settings to copy, or <c>nil</c>.</param>
/// <returns>The new frame settings.</returns>
function JxlEncoderFrameSettingsCreate( enc: PJxlEncoder; source: PJxlEncoderFrameSettings ): PJxlEncoderFrameSettings;
  cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets a colour encoding to sRGB.</summary>
/// <param name="color_encoding">The colour encoding to set.</param>
/// <param name="is_gray"><see cref="JXL_TRUE" /> for greyscale.</param>
procedure JxlColorEncodingSetToSRGB( color_encoding: PJxlColorEncoding; is_gray: JXL_BOOL ); cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Sets a colour encoding to linear sRGB.</summary>
/// <param name="color_encoding">The colour encoding to set.</param>
/// <param name="is_gray"><see cref="JXL_TRUE" /> for greyscale.</param>
procedure JxlColorEncodingSetToLinearSRGB( color_encoding: PJxlColorEncoding; is_gray: JXL_BOOL ); cdecl;
  external JXL_LIBRARY delayed;

/// <summary>Enables expert options; currently only effort 11 (best pixel-lossless compression, very slow).</summary>
/// <param name="enc">The encoder.</param>
procedure JxlEncoderAllowExpertOptions( enc: PJxlEncoder ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets a callback that receives the encoder's internal debug images.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="callback">The callback.</param>
/// <param name="opaque">User pointer passed to the callback.</param>
procedure JxlEncoderSetDebugImageCallback( frame_settings: PJxlEncoderFrameSettings; callback: JxlDebugImageCallback;
  opaque: Pointer ); cdecl; external JXL_LIBRARY delayed;

/// <summary>Sets a statistics object to gather encoding statistics into.</summary>
/// <param name="frame_settings">The frame settings.</param>
/// <param name="stats">Object created with <c>JxlEncoderStatsCreate</c>.</param>
procedure JxlEncoderCollectStats( frame_settings: PJxlEncoderFrameSettings; stats: PJxlEncoderStats ); cdecl;
  external JXL_LIBRARY delayed;

{$WARN SYMBOL_PLATFORM DEFAULT}

const
  /// <summary>
  ///   Every function this unit imports from <see cref="JXL_LIBRARY" />; <c>JxlCheckLibrary</c> verifies that the
  ///   DLL exports each one before any of them is called. Keep it in step with the declarations above.
  /// </summary>
  JXL_ENCODE_EXPORTS: array[ 0..48 ] of string = (
    NameOf( JxlEncoderVersion ),
    NameOf( JxlEncoderCreate ),
    NameOf( JxlEncoderReset ),
    NameOf( JxlEncoderDestroy ),
    NameOf( JxlEncoderSetCms ),
    NameOf( JxlEncoderSetParallelRunner ),
    NameOf( JxlEncoderGetError ),
    NameOf( JxlEncoderProcessOutput ),
    NameOf( JxlEncoderSetFrameHeader ),
    NameOf( JxlEncoderSetExtraChannelBlendInfo ),
    NameOf( JxlEncoderSetFrameName ),
    NameOf( JxlEncoderSetFrameBitDepth ),
    NameOf( JxlEncoderAddJPEGFrame ),
    NameOf( JxlEncoderAddImageFrame ),
    NameOf( JxlEncoderSetOutputProcessor ),
    NameOf( JxlEncoderFlushInput ),
    NameOf( JxlEncoderAddChunkedFrame ),
    NameOf( JxlEncoderSetExtraChannelBuffer ),
    NameOf( JxlEncoderAddBox ),
    NameOf( JxlEncoderUseBoxes ),
    NameOf( JxlEncoderCloseBoxes ),
    NameOf( JxlEncoderCloseFrames ),
    NameOf( JxlEncoderCloseInput ),
    NameOf( JxlEncoderSetColorEncoding ),
    NameOf( JxlEncoderSetICCProfile ),
    NameOf( JxlEncoderInitBasicInfo ),
    NameOf( JxlEncoderInitFrameHeader ),
    NameOf( JxlEncoderInitBlendInfo ),
    NameOf( JxlEncoderSetBasicInfo ),
    NameOf( JxlEncoderSetUpsamplingMode ),
    NameOf( JxlEncoderInitExtraChannelInfo ),
    NameOf( JxlEncoderSetExtraChannelInfo ),
    NameOf( JxlEncoderSetExtraChannelName ),
    NameOf( JxlEncoderFrameSettingsSetOption ),
    NameOf( JxlEncoderFrameSettingsSetFloatOption ),
    NameOf( JxlEncoderUseContainer ),
    NameOf( JxlEncoderStoreJPEGMetadata ),
    NameOf( JxlEncoderSetCodestreamLevel ),
    NameOf( JxlEncoderGetRequiredCodestreamLevel ),
    NameOf( JxlEncoderSetFrameLossless ),
    NameOf( JxlEncoderSetFrameDistance ),
    NameOf( JxlEncoderSetExtraChannelDistance ),
    NameOf( JxlEncoderDistanceFromQuality ),
    NameOf( JxlEncoderFrameSettingsCreate ),
    NameOf( JxlColorEncodingSetToSRGB ),
    NameOf( JxlColorEncodingSetToLinearSRGB ),
    NameOf( JxlEncoderAllowExpertOptions ),
    NameOf( JxlEncoderSetDebugImageCallback ),
    NameOf( JxlEncoderCollectStats )
  );

implementation

end.
