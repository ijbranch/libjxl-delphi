(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   High-level VCL support for JPEG XL on top of the libjxl C API: a <see cref="TJxlImage" /> graphic class that
///   <c>TPicture</c> / <c>TImage</c> load and save as <c>.jxl</c>, and one-call routines to decode, encode, losslessly
///   recompress a JPEG and reconstruct it.
/// </summary>
/// <remarks>
///   Every routine first makes libjxl safe to call (<c>JxlCheckLibrary</c>: the DLL is loaded from a safe folder and
///   every import verified), decodes and encodes on libjxl's resizable thread pool, masks floating-point exceptions
///   (x87 and SSE) for the duration of the libjxl calls, enforces the resource limits of <see cref="TJxlLimits" />, and
///   raises <see cref="EJxlError" /> on any failure. Pixels are 8 bits per sample, in sRGB unless asked otherwise;
///   images with more bits are reduced to 8 on decoding. The long routines take an optional
///   <see cref="TJxlCancellation" /> as their last parameter, which stops them from another thread with
///   <see cref="EJxlCancelled" />.
///   <para>
///     Alpha and exactness: a VCL bitmap holds alpha premultiplied, so encoding from a <c>TBitmap</c> (including
///     <c>TJxlImage</c>) stores premultiplied samples, and a lossless save is not sample-exact for partly transparent
///     pixels. For a sample-exact lossless save of straight alpha, encode the original pixels instead: a
///     <see cref="TJxlPixels" /> from <see cref="JxlDecodePixels" /> or <see cref="JxlTryPngToPixels" />, with
///     <see cref="JxlEncodePixels" /> or <see cref="JxlEncodePixelsToFile" />.
///   </para>
/// </remarks>
/// <example>
///   <code>
///     JxlDecodeFileToBitmap( 'photo.jxl', Image1.Picture.Bitmap );
///     JxlEncodeBitmapToFile( Image1.Picture.Bitmap, 'copy.jxl', TJxlEncodeOptions.Default );
///     Image1.Picture.LoadFromFile( 'photo.jxl' );   // TJxlImage is registered for .jxl
///   </code>
/// </example>
unit Jxl.Graphic;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Imaging.pngimage,
  Jxl.Api.Types;

type
  /// <summary>Re-export of <c>Jxl.Api.Types.EJxlError</c>, so users of this unit need not name the import unit.</summary>
  EJxlError = Jxl.Api.Types.EJxlError;

  /// <summary>
  ///   Raised, instead of any other <see cref="EJxlError" />, when a routine stops because the
  ///   <see cref="TJxlCancellation" /> it was given has been cancelled.
  /// </summary>
  /// <remarks>
  ///   A binding check: <c>IsBindingCheck</c> is <c>True</c>, <c>ApiName</c> names the public routine and the message
  ///   ends in <c>the operation was cancelled</c>. Catch it before <see cref="EJxlError" /> to tell a cancellation from a
  ///   failure. A libjxl call that fails for another reason after the token was cancelled is reported as cancelled too.
  /// </remarks>
  EJxlCancelled = class( EJxlError );

  /// <summary>
  ///   A thread-safe cancellation token for the long routines of this unit (decoding, encoding, JPEG recompression and
  ///   reconstruction, validation, and <see cref="TJxlImage" /> loading and saving): call <see cref="Cancel" /> from any
  ///   thread and the routine using it stops with <see cref="EJxlCancelled" />.
  /// </summary>
  /// <remarks>
  ///   <para>
  ///     A libjxl call cannot be interrupted, but its heavy work runs as tasks through the parallel runner the binding
  ///     gives it. With a token, that runner (<see cref="JxlCancellableParallelRunner" />) checks it before every batch of
  ///     tasks and before every task, skips the remaining tasks once it is cancelled and reports failure, so libjxl
  ///     abandons the call with an error status; the binding also checks it between its own steps (before starting, in
  ///     the decoder's event loop and while collecting output). A cancellation therefore takes effect within about one
  ///     task, or one stretch of libjxl's work outside the runner, not at once. Measured on 1 to 16 megapixels: lossy
  ///     encoding (effort 7 to 10) stops within about 50 ms, lossless encoding at effort 7 within about 0.4 s, and
  ///     decoding and validation well before half their run; but lossless encoding at effort 9 spends most of its time
  ///     in one stretch outside the runner and stops only after about 60% of its run, and at effort 10 hardly before it
  ///     ends.
  ///   </para>
  ///   <para>
  ///     The decoder or encoder, the thread pool and every buffer are released as on any other failure. Nothing is
  ///     returned, and a routine that writes a file writes nothing (the file is written only once the data is complete);
  ///     a bitmap being decoded into may be left partly written.
  ///   </para>
  ///   <para>
  ///     The caller owns the token, which must outlive every call it is passed to. It stays cancelled until
  ///     <see cref="Reset" />; a routine given a cancelled token raises at once. Passing <c>nil</c>, or a token that is never
  ///     cancelled, changes nothing: the output is identical.
  ///   </para>
  /// </remarks>
  /// <example>
  ///   <code>
  ///     // Worker thread:
  ///     try
  ///       naJxl := JxlEncodePixels( rPixels, rOptions, JxlGetDefaultLimits, FCancellation );
  ///     except
  ///       on EJxlCancelled do ReportCancelled;
  ///     end;
  ///     // UI thread, Cancel button:
  ///     FCancellation.Cancel;
  ///   </code>
  /// </example>
  TJxlCancellation = class
  private
    /// <summary>1 once cancelled, 0 otherwise; read and written atomically.</summary>
    FCancelled: Integer;
  public
    /// <summary>Asks every routine using this token to stop; thread-safe, and harmless when repeated.</summary>
    procedure Cancel;
    /// <summary>Clears the request, so the token can be used again; call it only while no routine is using it.</summary>
    procedure Reset;
    /// <summary>Reports whether <see cref="Cancel" /> has been called since the token was created or reset; thread-safe.</summary>
    /// <returns><c>True</c> once cancelled.</returns>
    function IsCancelled: Boolean;
  end;

  /// <summary>
  ///   State of <see cref="JxlCancellableParallelRunner" />: libjxl's resizable thread pool that does the work, and the
  ///   token that can stop it. For code that drives the <c>Jxl.Api.*</c> imports directly; the routines of this unit
  ///   use it themselves.
  /// </summary>
  /// <remarks>
  ///   Keep it in a variable that outlives the decoder or encoder, and pass its address as the runner's opaque pointer.
  ///   The caller creates and destroys <see cref="Runner" />.
  /// </remarks>
  /// <example>
  ///   <code>
  ///     var rRunner: TJxlCancellableRunner;
  ///     rRunner.Runner       := JxlResizableParallelRunnerCreate( nil );
  ///     rRunner.Cancellation := oCancellation;
  ///     JxlEncoderSetParallelRunner( pEncoder, JxlCancellableParallelRunner, @rRunner );
  ///     // ... encode; destroy the encoder, then JxlResizableParallelRunnerDestroy( rRunner.Runner )
  ///   </code>
  /// </example>
  TJxlCancellableRunner = record
    /// <summary>The state of libjxl's resizable runner, from <c>JxlResizableParallelRunnerCreate</c>.</summary>
    Runner: Pointer;
    /// <summary>The token to check; <c>nil</c> forwards every call to the resizable runner unchanged.</summary>
    Cancellation: TJxlCancellation;
  end;
  /// <summary>Pointer to a <see cref="TJxlCancellableRunner" />.</summary>
  PJxlCancellableRunner = ^TJxlCancellableRunner;

  /// <summary>
  ///   Colour space of a JPEG XL image's original colour encoding, as <see cref="JxlReadInfo" /> reports it in
  ///   <see cref="TJxlInfo.ColourSpace" />.
  /// </summary>
  /// <remarks>
  ///   <c>jcsUnknown</c>: an encoded profile whose colour space is unknown, or an ICC profile that is neither RGB nor grey
  ///   (CMYK, for one). <c>jcsRgb</c>: RGB. <c>jcsGrey</c>: greyscale. <c>jcsXyb</c>: libjxl's XYB, declared as the
  ///   original colour space (rare; an image merely coded in XYB reports the space it was encoded from, with
  ///   <see cref="TJxlInfo.XybEncoded" />).
  /// </remarks>
  TJxlColourSpace = ( jcsUnknown, jcsRgb, jcsGrey, jcsXyb );

  /// <summary>Colour profile <see cref="JxlDecodePixels" /> returns the pixels in.</summary>
  /// <remarks>
  ///   <para>
  ///     <c>jcoSrgb</c> (default): converted to sRGB with libjxl's colour management, which is what VCL displays;
  ///     <see cref="TJxlPixels.IccProfile" /> is libjxl's sRGB profile. A greyscale image is expanded to RGB, and its
  ///     <see cref="TJxlPixels.IccProfile" /> is left empty (libjxl reports a grey profile, which does not describe
  ///     3-channel samples): the samples are plain sRGB, which is what encoding them declares.
  ///   </para>
  ///   <para>
  ///     <c>jcoImageProfile</c>: libjxl's own default, the image's original profile where the file stores one (the
  ///     form libjxl's conformance references use); <see cref="TJxlPixels.IccProfile" /> then describes the samples. A
  ///     greyscale image comes back as 1 channel (2 with alpha) with its grey profile, so that the pixels and the
  ///     profile can be encoded again together. A CMYK image comes back as its three colour channels without the
  ///     black channel, with its CMYK profile: these samples are not displayable and cannot be encoded with that
  ///     profile (<see cref="JxlEncodePixels" /> raises <see cref="EJxlError" />); decode CMYK with <c>jcoSrgb</c>.
  ///   </para>
  /// </remarks>
  TJxlColourOutput = ( jcoSrgb, jcoImageProfile );

  /// <summary>
  ///   An 8-bit image in memory: interleaved samples, rows top to bottom with no padding; sRGB unless decoded with
  ///   <c>jcoImageProfile</c> or given an <see cref="IccProfile" />.
  /// </summary>
  TJxlPixels = record
    /// <summary>Width in pixels.</summary>
    Width: Cardinal;
    /// <summary>Height in pixels.</summary>
    Height: Cardinal;
    /// <summary>Samples per pixel: 1 grey, 2 grey + alpha, 3 RGB, 4 RGBA.</summary>
    NumChannels: Cardinal;
    /// <summary>Whether the colour samples are premultiplied by alpha; decoded pixels never are.</summary>
    AlphaPremultiplied: Boolean;
    /// <summary>The samples: <c>Width * Height * NumChannels</c> bytes.</summary>
    Data: TBytes;
    /// <summary>
    ///   ICC profile of the colour samples. Decoding fills it as libjxl reports it (empty when libjxl cannot express
    ///   one, and for a grey image expanded to sRGB RGB). Encoding stores it when it is not empty, and declares sRGB when it is; its colour space must match
    ///   <see cref="NumChannels" /> (a grey profile for 1 or 2 channels, an RGB one for 3 or 4).
    /// </summary>
    IccProfile: TBytes;
  end;

  /// <summary>Encoder settings used by <see cref="JxlEncodePixels" /> and the bitmap encoders.</summary>
  TJxlEncodeOptions = record
    /// <summary>Encode losslessly (pixels decode byte-identical); <see cref="Distance" /> is then ignored.</summary>
    Lossless: Boolean;
    /// <summary>
    ///   Lossy quality as a Butteraugli distance: 1.0 visually lossless, 0.5-3.0 recommended, lower is better and
    ///   larger; at most 25. 0 or less means lossless. A NaN or a value above 25 raises <c>EArgumentException</c>.
    /// </summary>
    Distance: Single;
    /// <summary>Encoder effort, 1 (fastest) to 10 (slowest, smallest); 7 is libjxl's default. Others raise <c>EArgumentException</c>.</summary>
    Effort: Integer;
    /// <summary>Returns lossy encoding at distance 1.0 and effort 7, libjxl's defaults.</summary>
    /// <returns>The default options.</returns>
    class function Default: TJxlEncodeOptions; static;
  end;

  /// <summary>
  ///   Resource limits the routines of this unit enforce on untrusted input, so that a hostile or damaged file is
  ///   refused with <see cref="EJxlError" /> instead of exhausting memory or the address space.
  /// </summary>
  /// <remarks>
  ///   <para>
  ///     Every decoding routine checks <see cref="MaxPixels" /> and <see cref="MaxExtraChannels" /> against the
  ///     image's header before any pixel is decoded, and refuses input larger than <see cref="MaxInputBytes" /> before
  ///     reading a stream or file into memory. libjxl's own allocations go through a counting memory manager capped at
  ///     <see cref="MaxMemoryBytes" />, and output buffers stop growing at <see cref="MaxOutputBytes" />. A JPEG is
  ///     pre-checked before libjxl sees it: its marker structure must be sound, its dimensions within
  ///     <see cref="MaxPixels" />, its DCT coefficient buffers within <see cref="MaxMemoryBytes" />, and its scan count
  ///     within <see cref="MaxJpegScans" />. A limit refusal is a binding check
  ///     (<see cref="EJxlError.IsBindingCheck" />) naming the limit.
  ///   </para>
  ///   <para>
  ///     <see cref="Default" /> depends on the architecture. Measured through this memory manager, libjxl's working
  ///     memory while decoding is 8 to 34 bytes per pixel on large images (lossy VarDCT at the low end, lossless with
  ///     alpha at the high end), plus about 10 MB whatever the size, on top of the decoded pixels and the bitmap
  ///     (4 bytes per pixel each). A Win32 process has 2 GiB of address space, so Win32 allows 32 megapixels
  ///     (8192 x 4096) and 1 GiB of libjxl memory: at most about 1.3 GiB in all, and an image near the pixel limit in
  ///     a costly coding mode is refused by the memory limit rather than exhausting the process. Win64 allows 256
  ///     megapixels (16384 x 16384) and 8 GiB: generous, but finite. Input and output are capped at 256 MiB on Win32
  ///     and 1 GiB on Win64. Change the process-wide defaults with <see cref="JxlSetDefaultLimits" />, or pass a record
  ///     to an overload that takes one. Every field must be positive.
  ///   </para>
  /// </remarks>
  TJxlLimits = record
    /// <summary>Most pixels (width x height) an image or JPEG may have; checked before decoding.</summary>
    MaxPixels: UInt64;
    /// <summary>Most extra channels (alpha, black, spot colours, ...) an image may declare.</summary>
    MaxExtraChannels: Cardinal;
    /// <summary>Most bytes of input a routine reads into memory or accepts.</summary>
    MaxInputBytes: Int64;
    /// <summary>Most bytes an encoded file or reconstructed JPEG may grow to.</summary>
    MaxOutputBytes: Int64;
    /// <summary>Most bytes libjxl may hold at once through its memory manager, per decoder or encoder.</summary>
    MaxMemoryBytes: Int64;
    /// <summary>Most scans a JPEG to be recompressed may have; standard progressive JPEGs use about 10.</summary>
    MaxJpegScans: Cardinal;
    /// <summary>Returns the built-in limits for the architecture the program was compiled for.</summary>
    /// <returns>The built-in limits.</returns>
    class function Default: TJxlLimits; static;
  end;

  /// <summary>
  ///   What the headers of a JPEG XL file say about it, read by <see cref="JxlReadInfo" /> without decoding pixels.
  /// </summary>
  TJxlInfo = record
    /// <summary>Image width in pixels as stored, before <see cref="Orientation" /> is applied.</summary>
    Width: Cardinal;
    /// <summary>Image height in pixels as stored, before <see cref="Orientation" /> is applied.</summary>
    Height: Cardinal;
    /// <summary>Original bits per colour sample (e.g. 8, 12, 16, 32).</summary>
    BitsPerSample: Cardinal;
    /// <summary>Exponent bits per colour sample for floating-point samples, 0 for integers.</summary>
    ExponentBitsPerSample: Cardinal;
    /// <summary>Colour channels: 1 for grey, 3 for colour; excludes alpha and other extra channels.</summary>
    ColourChannels: Cardinal;
    /// <summary>Extra channels, including the main alpha channel.</summary>
    ExtraChannels: Cardinal;
    /// <summary>Bits per sample of the main alpha channel, 0 when the image has none.</summary>
    AlphaBits: Cardinal;
    /// <summary>Whether the colour samples are stored premultiplied by alpha.</summary>
    AlphaPremultiplied: Boolean;
    /// <summary>
    ///   Whether the image is coded in libjxl's internal XYB colour space (lossy VarDCT/modular) rather than in its
    ///   original colour space (lossless, and recompressed JPEGs).
    /// </summary>
    XybEncoded: Boolean;
    /// <summary>
    ///   EXIF-style orientation stored in the file, 1 (none) to 8, naming the transform from the stored to the
    ///   displayed image; 5 to 8 swap width and height (see <see cref="DisplayWidth" />). The decoding routines apply
    ///   it, so their pixels are already in display orientation.
    /// </summary>
    Orientation: Integer;
    /// <summary>Whether the codestream is wrapped in the ISOBMFF-style container.</summary>
    HasContainer: Boolean;
    /// <summary>Whether a preview image is stored.</summary>
    HasPreview: Boolean;
    /// <summary>Whether the image is an animation.</summary>
    IsAnimated: Boolean;
    /// <summary>Number of displayed frames: 1 for a still image.</summary>
    FrameCount: Integer;
    /// <summary>Numerator of the animation's ticks per second; 0 when not animated.</summary>
    TicksPerSecondNumerator: Cardinal;
    /// <summary>Denominator of the animation's ticks per second; 0 when not animated.</summary>
    TicksPerSecondDenominator: Cardinal;
    /// <summary>Times the animation plays; 0 means forever.</summary>
    AnimationLoops: Cardinal;
    /// <summary>Total duration of all frames, in animation ticks.</summary>
    DurationTicks: UInt64;
    /// <summary>Whether the file holds JPEG reconstruction data (a <c>jbrd</c> box), so the original JPEG can be rebuilt.</summary>
    HasJpegReconstruction: Boolean;
    /// <summary>
    ///   Colour space of the image's original colour encoding: from the encoded profile, or from the ICC profile's header
    ///   when <see cref="HasIccProfile" />.
    /// </summary>
    ColourSpace: TJxlColourSpace;
    /// <summary>
    ///   Whether the original colour encoding is sRGB: an encoded profile (not an ICC profile) with libjxl's built-in sRGB
    ///   primaries (for RGB; grey has none), D65 white point and sRGB transfer function, with any rendering intent. Then
    ///   decoding to 8-bit sRGB (<c>jcoSrgb</c>, a bitmap) involves no colour conversion. <c>False</c> for anything else,
    ///   including the sRGB primaries with another transfer function (BT.709, linear, a gamma), custom primaries or white
    ///   point even when numerically equal to sRGB's, and every ICC profile, sRGB ones included.
    /// </summary>
    IsSrgb: Boolean;
    /// <summary>
    ///   Whether the file describes its colour with an ICC profile instead of an encoded profile;
    ///   <see cref="ColourEncoding" /> is then all zero and <see cref="IccProfileSize" /> gives the profile's size.
    /// </summary>
    HasIccProfile: Boolean;
    /// <summary>Size in bytes of the image's ICC profile when <see cref="HasIccProfile" />; otherwise 0.</summary>
    IccProfileSize: UInt64;
    /// <summary>
    ///   The original colour encoding as libjxl's structured (encoded) profile: colour space, white point, primaries,
    ///   transfer function and rendering intent. All zero when <see cref="HasIccProfile" />.
    /// </summary>
    ColourEncoding: JxlColorEncoding;
    /// <summary>
    ///   Frames decoded in full: equal to <see cref="FrameCount" /> after <see cref="JxlValidate" />, 0 after
    ///   <see cref="JxlReadInfo" />.
    /// </summary>
    DecodedFrameCount: Integer;
    /// <summary>Returns the animation's total duration in seconds.</summary>
    /// <returns>The duration, or 0 for a still image.</returns>
    function DurationSeconds: Double;
    /// <summary>Returns the width of the image as displayed, after <see cref="Orientation" /> is applied.</summary>
    /// <returns><see cref="Height" /> for orientations 5 to 8, otherwise <see cref="Width" />.</returns>
    function DisplayWidth: Cardinal;
    /// <summary>Returns the height of the image as displayed, after <see cref="Orientation" /> is applied.</summary>
    /// <returns><see cref="Width" /> for orientations 5 to 8, otherwise <see cref="Height" />.</returns>
    function DisplayHeight: Cardinal;
  end;

  /// <summary>
  ///   A <c>TBitmap</c> that loads and saves JPEG XL. Registered with <c>TPicture</c> for the <c>.jxl</c> extension, so
  ///   <c>TImage.Picture.LoadFromFile</c> and <c>TPicture.LoadFromStream</c> read JPEG XL directly.
  /// </summary>
  /// <remarks>
  ///   The decoded image is a 32-bit bitmap in display orientation; an image with alpha gets
  ///   <c>AlphaFormat = afDefined</c>, an opaque one <c>afIgnored</c>. Saving encodes with <see cref="Lossless" />,
  ///   <see cref="Distance" /> and <see cref="Effort" />. Loading and saving enforce <see cref="Limits" />. Form (DFM)
  ///   streaming is inherited from <c>TBitmap</c> and stays BMP.
  /// </remarks>
  TJxlImage = class( TBitmap )
  private
    /// <summary>Backing field of <see cref="Lossless" />.</summary>
    FLossless: Boolean;
    /// <summary>Backing field of <see cref="Distance" />.</summary>
    FDistance: Single;
    /// <summary>Backing field of <see cref="Effort" />.</summary>
    FEffort: Integer;
    /// <summary>Backing field of <see cref="Limits" />.</summary>
    FLimits: TJxlLimits;
    /// <summary>Backing field of <see cref="Cancellation" />; not owned.</summary>
    FCancellation: TJxlCancellation;
    /// <summary>Returns the encoder settings held by the properties.</summary>
    /// <returns>The settings as a <see cref="TJxlEncodeOptions" />.</returns>
    function GetEncodeOptions: TJxlEncodeOptions;
    /// <summary>Sets <see cref="Limits" /> after checking every field is positive.</summary>
    /// <param name="AValue">The new limits.</param>
    /// <exception cref="EArgumentException">A field is zero or negative.</exception>
    procedure SetLimits( const AValue: TJxlLimits );
  public
    /// <summary>Creates an empty image with libjxl's default encoder settings and the process-wide default limits.</summary>
    constructor Create; overload; override;
    /// <summary>Reports whether a stream starts with a JPEG XL signature; the position is restored.</summary>
    /// <param name="Stream">The stream to inspect.</param>
    /// <returns><c>True</c> for a JPEG XL codestream or container.</returns>
    class function CanLoadFromStream( Stream: TStream ): Boolean; override;
    /// <summary>Copies an image; from another <see cref="TJxlImage" /> the encoder settings and limits are copied too.</summary>
    /// <param name="Source">The object to copy.</param>
    procedure Assign( Source: TPersistent ); override;
    /// <summary>Decodes JPEG XL data from the current position to the end of the stream.</summary>
    /// <param name="Stream">The stream to read.</param>
    /// <exception cref="EJxlCancelled"><see cref="Cancellation" /> was cancelled.</exception>
    /// <exception cref="EJxlError">
    ///   The data is not valid JPEG XL, exceeds <see cref="Limits" />, or libjxl cannot be loaded.
    /// </exception>
    procedure LoadFromStream( Stream: TStream ); override;
    /// <summary>Encodes the image as JPEG XL into the stream; nothing is written if encoding fails or is cancelled.</summary>
    /// <param name="Stream">The stream to write.</param>
    /// <exception cref="EArgumentException">The image is empty, or the encoder settings are out of range.</exception>
    /// <exception cref="EJxlCancelled"><see cref="Cancellation" /> was cancelled.</exception>
    /// <exception cref="EJxlError">Encoding fails, exceeds <see cref="Limits" />, or libjxl cannot be loaded.</exception>
    procedure SaveToStream( Stream: TStream ); override;
    /// <summary>The encoder settings held by the properties, as one record.</summary>
    property EncodeOptions: TJxlEncodeOptions read GetEncodeOptions;
    /// <summary>Encode losslessly when saving.</summary>
    property Lossless: Boolean read FLossless write FLossless;
    /// <summary>Lossy Butteraugli distance used when saving; 1.0 is visually lossless, 0 or less lossless.</summary>
    property Distance: Single read FDistance write FDistance;
    /// <summary>Encoder effort used when saving, 1 to 10.</summary>
    property Effort: Integer read FEffort write FEffort;
    /// <summary>
    ///   Resource limits for loading and saving; <see cref="JxlGetDefaultLimits" /> when the image is created. A
    ///   record property: read it, change the copy, and assign it back.
    /// </summary>
    property Limits: TJxlLimits read FLimits write SetLimits;
    /// <summary>
    ///   Token that stops a load or save in progress (with <see cref="EJxlCancelled" />), or <c>nil</c> (the default).
    ///   Not owned, and not copied by <see cref="Assign" />: the caller keeps it alive while the image uses it.
    /// </summary>
    property Cancellation: TJxlCancellation read FCancellation write FCancellation;
  end;

/// <summary>Returns the process-wide default limits used by every routine not given a <see cref="TJxlLimits" />.</summary>
/// <returns>A copy of the defaults; <see cref="TJxlLimits.Default" /> until changed.</returns>
function JxlGetDefaultLimits: TJxlLimits;

/// <summary>Replaces the process-wide default limits; thread-safe, and affects calls that start afterwards.</summary>
/// <param name="ALimits">The new defaults.</param>
/// <exception cref="EArgumentException">A field is zero or negative.</exception>
procedure JxlSetDefaultLimits( const ALimits: TJxlLimits );

/// <summary>Reports whether data starts with a JPEG XL codestream or container signature; needs no DLL.</summary>
/// <param name="AData">The data, or at least its first 12 bytes.</param>
/// <returns><c>True</c> when the signature is present.</returns>
function JxlHasSignature( const AData: TBytes ): Boolean;

/// <summary>
///   Decodes a JPEG XL image (the first frame of an animation) to 8-bit pixels in display orientation, sRGB by
///   default, within the default limits.
/// </summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="AColourOutput">Colour profile of the returned samples.</param>
/// <returns>
///   The pixels: 3 channels (RGB) for an opaque image, 4 (RGBA, straight alpha) for one with alpha; a greyscale image
///   is expanded to RGB with <c>jcoSrgb</c>, and stays 1 or 2 channels with <c>jcoImageProfile</c>.
/// </returns>
/// <exception cref="EJxlError">
///   The data is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.
/// </exception>
function JxlDecodePixels( const AData: TBytes; AColourOutput: TJxlColourOutput = jcoSrgb ): TJxlPixels; overload;

/// <summary>
///   Decodes a JPEG XL image to 8-bit pixels within the given limits, optionally cancellable; see the two-parameter
///   overload.
/// </summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="AColourOutput">Colour profile of the returned samples.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <param name="ACancellation">Token that stops the decode, or <c>nil</c>.</param>
/// <returns>The pixels.</returns>
/// <exception cref="EArgumentException">A limit is zero or negative.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">
///   The data is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.
/// </exception>
function JxlDecodePixels( const AData: TBytes; AColourOutput: TJxlColourOutput; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation = nil ): TJxlPixels; overload;

/// <summary>
///   Encodes 8-bit pixels as a JPEG XL file, declaring <see cref="TJxlPixels.IccProfile" /> when it is set and sRGB
///   otherwise.
/// </summary>
/// <param name="APixels">The pixels to encode.</param>
/// <param name="AOptions">Lossless, distance and effort settings.</param>
/// <returns>The JPEG XL file.</returns>
/// <exception cref="EArgumentException">The pixel record is inconsistent (size, channel count) or the settings are out of range.</exception>
/// <exception cref="EJxlError">libjxl rejects the data or profile or fails, the output exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlEncodePixels( const APixels: TJxlPixels; const AOptions: TJxlEncodeOptions ): TBytes; overload;

/// <summary>
///   Encodes 8-bit pixels as a JPEG XL file within the given limits, optionally cancellable; see the two-parameter
///   overload.
/// </summary>
/// <param name="APixels">The pixels to encode.</param>
/// <param name="AOptions">Lossless, distance and effort settings.</param>
/// <param name="ALimits">The resource limits to enforce (memory and output size).</param>
/// <param name="ACancellation">Token that stops the encode, or <c>nil</c>.</param>
/// <returns>The JPEG XL file.</returns>
/// <exception cref="EArgumentException">The pixel record, the settings or a limit is invalid.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">libjxl rejects the data or profile or fails, the output exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlEncodePixels( const APixels: TJxlPixels; const AOptions: TJxlEncodeOptions; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation = nil ): TBytes; overload;

/// <summary>Copies pixels into a 32-bit bitmap, setting <c>AlphaFormat</c> to <c>afDefined</c> when they have alpha.</summary>
/// <param name="APixels">The pixels to copy.</param>
/// <param name="ABitmap">The bitmap to fill; resized as needed.</param>
/// <exception cref="EArgumentException">The pixel record is inconsistent or the bitmap is <c>nil</c>.</exception>
procedure JxlPixelsToBitmap( const APixels: TJxlPixels; ABitmap: TBitmap );

/// <summary>Copies a bitmap into pixels: RGBA (premultiplied, as VCL holds it) when it has alpha, otherwise RGB.</summary>
/// <param name="ABitmap">The bitmap; any pixel format. Alpha is used only from a 32-bit bitmap whose <c>AlphaFormat</c> is not <c>afIgnored</c>.</param>
/// <returns>The pixels.</returns>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> or empty.</exception>
/// <exception cref="EJxlError">The bitmap is too large for one pixel buffer in this process.</exception>
function JxlBitmapToPixels( ABitmap: TBitmap ): TJxlPixels;

/// <summary>
///   Decodes JPEG XL data straight into a bitmap (32-bit, display orientation, sRGB) within the default limits,
///   without an intermediate pixel buffer.
/// </summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="ABitmap">The bitmap to fill; becomes 32-bit. Left partly written if decoding fails.</param>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> (checked before any decoding).</exception>
/// <exception cref="EJxlError">The data is invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlDecodeToBitmap( const AData: TBytes; ABitmap: TBitmap ); overload;

/// <summary>
///   Decodes JPEG XL data into a bitmap within the given limits, optionally cancellable; see the two-parameter overload.
/// </summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="ABitmap">The bitmap to fill; becomes 32-bit. Left partly written if decoding fails or is cancelled.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <param name="ACancellation">Token that stops the decode, or <c>nil</c>.</param>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> or a limit is invalid (checked before any decoding).</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The data is invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlDecodeToBitmap( const AData: TBytes; ABitmap: TBitmap; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation = nil ); overload;

/// <summary>Encodes a bitmap as a JPEG XL file in memory, within the default limits.</summary>
/// <param name="ABitmap">The bitmap to encode.</param>
/// <param name="AOptions">Lossless, distance and effort settings.</param>
/// <param name="ACancellation">Token that stops the encode, or <c>nil</c>.</param>
/// <returns>The JPEG XL file.</returns>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> or empty, or the settings are out of range.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">Encoding fails or exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlEncodeBitmap( ABitmap: TBitmap; const AOptions: TJxlEncodeOptions; ACancellation: TJxlCancellation = nil ): TBytes;

/// <summary>Decodes a JPEG XL file into a bitmap within the default limits.</summary>
/// <param name="AFileName">Path of the <c>.jxl</c> file.</param>
/// <param name="ABitmap">The bitmap to fill; becomes 32-bit.</param>
/// <param name="ACancellation">Token that stops the decode, or <c>nil</c>.</param>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> (checked before the file is read).</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The file is not valid JPEG XL, exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlDecodeFileToBitmap( const AFileName: string; ABitmap: TBitmap; ACancellation: TJxlCancellation = nil );

/// <summary>Encodes a bitmap to a JPEG XL file; the file is written only once encoding has succeeded.</summary>
/// <param name="ABitmap">The bitmap to encode.</param>
/// <param name="AFileName">Path of the <c>.jxl</c> file to write; overwritten.</param>
/// <param name="AOptions">Lossless, distance and effort settings.</param>
/// <param name="ACancellation">Token that stops the encode, or <c>nil</c>; a cancelled encode writes nothing.</param>
/// <exception cref="EArgumentException">The bitmap is <c>nil</c> or empty, or the settings are out of range.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">Encoding fails or exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlEncodeBitmapToFile( ABitmap: TBitmap; const AFileName: string; const AOptions: TJxlEncodeOptions;
  ACancellation: TJxlCancellation = nil );

/// <summary>
///   Recompresses a JPEG file losslessly as JPEG XL (typically about 20% smaller), keeping the data needed to
///   reconstruct the original JPEG byte for byte with <see cref="JxlReconstructJpeg" />.
/// </summary>
/// <remarks>
///   The JPEG is pre-checked before libjxl sees it (marker structure, dimensions, coefficient memory, scan count; see
///   <see cref="TJxlLimits" />), within the default limits.
/// </remarks>
/// <param name="AJpegData">The complete JPEG file.</param>
/// <param name="AEffort">Encoder effort, 1 to 10.</param>
/// <returns>The JPEG XL file.</returns>
/// <exception cref="EArgumentException">The effort is outside 1 to 10.</exception>
/// <exception cref="EJxlError">
///   The JPEG is empty, malformed, exceeds the limits or cannot be represented, or libjxl cannot be loaded.
/// </exception>
function JxlTranscodeJpegToJxl( const AJpegData: TBytes; AEffort: Integer = 7 ): TBytes; overload;

/// <summary>
///   Recompresses a JPEG losslessly within the given limits, optionally cancellable; see the two-parameter overload.
/// </summary>
/// <param name="AJpegData">The complete JPEG file.</param>
/// <param name="AEffort">Encoder effort, 1 to 10.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <param name="ACancellation">Token that stops the recompression, or <c>nil</c>.</param>
/// <returns>The JPEG XL file.</returns>
/// <exception cref="EArgumentException">The effort is outside 1 to 10, or a limit is invalid.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">
///   The JPEG is empty, malformed, exceeds the limits or cannot be represented, or libjxl cannot be loaded.
/// </exception>
function JxlTranscodeJpegToJxl( const AJpegData: TBytes; AEffort: Integer; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation = nil ): TBytes; overload;

/// <summary>Reconstructs the original JPEG file from a JPEG XL file made by lossless JPEG recompression.</summary>
/// <param name="AJxlData">The complete JPEG XL file.</param>
/// <returns>The JPEG file, byte-identical to the one that was recompressed.</returns>
/// <exception cref="EJxlError">
///   The file holds no JPEG reconstruction data, is invalid, exceeds the default limits, or libjxl cannot be loaded.
/// </exception>
function JxlReconstructJpeg( const AJxlData: TBytes ): TBytes; overload;

/// <summary>
///   Reconstructs the original JPEG file within the given limits, optionally cancellable; see the one-parameter overload.
/// </summary>
/// <param name="AJxlData">The complete JPEG XL file.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <param name="ACancellation">Token that stops the reconstruction, or <c>nil</c>.</param>
/// <returns>The JPEG file.</returns>
/// <exception cref="EArgumentException">A limit is zero or negative.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">
///   The file holds no JPEG reconstruction data, is invalid, exceeds the limits, or libjxl cannot be loaded.
/// </exception>
function JxlReconstructJpeg( const AJxlData: TBytes; const ALimits: TJxlLimits; ACancellation: TJxlCancellation = nil ): TBytes;
  overload;

/// <summary>
///   Recompresses a JPEG file losslessly to a JPEG XL file, within the default limits; the file is written only once
///   recompression has succeeded.
/// </summary>
/// <param name="AJpegFileName">Path of the JPEG file.</param>
/// <param name="AJxlFileName">Path of the <c>.jxl</c> file to write; overwritten.</param>
/// <param name="AEffort">Encoder effort, 1 to 10.</param>
/// <param name="ACancellation">Token that stops the recompression, or <c>nil</c>; a cancelled one writes nothing.</param>
/// <exception cref="EArgumentException">The effort is outside 1 to 10.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The JPEG cannot be recompressed, exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlTranscodeJpegFileToJxl( const AJpegFileName: string; const AJxlFileName: string; AEffort: Integer = 7;
  ACancellation: TJxlCancellation = nil );

/// <summary>
///   Reconstructs the original JPEG file from a losslessly recompressed JPEG XL file, within the default limits; the file
///   is written only once reconstruction has succeeded.
/// </summary>
/// <param name="AJxlFileName">Path of the <c>.jxl</c> file.</param>
/// <param name="AJpegFileName">Path of the JPEG file to write; overwritten.</param>
/// <param name="ACancellation">Token that stops the reconstruction, or <c>nil</c>; a cancelled one writes nothing.</param>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">
///   The file holds no JPEG reconstruction data, exceeds the limits, or libjxl cannot be loaded.
/// </exception>
procedure JxlReconstructJpegFile( const AJxlFileName: string; const AJpegFileName: string; ACancellation: TJxlCancellation = nil );

/// <summary>
///   Reads a JPEG XL file's headers: basic information, original colour encoding, frame count and animation timing, and
///   whether it holds JPEG reconstruction data. No pixels are decoded.
/// </summary>
/// <remarks>
///   Cheap: the pixel data is skipped, not decoded, and so is not cancellable. For a file in the container format every box's declared size is
///   checked against the data, so a container cut short anywhere raises <see cref="EJxlError" />. A bare codestream
///   has no such sizes: one cut inside its last frame's pixel data can still read successfully (damage to the
///   headers, or a missing frame header, is still caught). Use <see cref="JxlValidate" /> to check a file whole.
///   Width, height and orientation are as stored (see <see cref="TJxlInfo.Orientation" />). The default limits apply.
/// </remarks>
/// <param name="AData">The complete JPEG XL file.</param>
/// <returns>The information.</returns>
/// <exception cref="EJxlError">The data is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlReadInfo( const AData: TBytes ): TJxlInfo; overload;

/// <summary>Reads a JPEG XL file's headers within the given limits; see the bytes overload.</summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <returns>The information.</returns>
/// <exception cref="EArgumentException">A limit is zero or negative.</exception>
/// <exception cref="EJxlError">The data is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlReadInfo( const AData: TBytes; const ALimits: TJxlLimits ): TJxlInfo; overload;

/// <summary>Reads a JPEG XL file's headers from a stream, from the current position to the end; no pixels are decoded.</summary>
/// <param name="AStream">The stream holding the file.</param>
/// <returns>The information.</returns>
/// <exception cref="EJxlError">The data is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlReadInfo( AStream: TStream ): TJxlInfo; overload;

/// <summary>Reads the headers of a JPEG XL file on disk; no pixels are decoded.</summary>
/// <param name="AFileName">Path of the <c>.jxl</c> file.</param>
/// <returns>The information.</returns>
/// <exception cref="EJxlError">The file is empty, truncated or invalid, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlReadInfo( const AFileName: string ): TJxlInfo; overload;

/// <summary>
///   Checks a JPEG XL file completely: decodes every frame in full (the pixels go to a callback that discards them, so
///   no image buffer is allocated) and walks every box to the end of the file. Returns the same information as
///   <see cref="JxlReadInfo" />.
/// </summary>
/// <remarks>
///   Opt-in and about as costly as decoding the image (it runs on libjxl's thread pool); <see cref="JxlReadInfo" />
///   stays header-only. Catches what a header read cannot: a bare codestream cut inside its pixel data, and corrupt
///   pixel data. The default limits apply.
/// </remarks>
/// <param name="AData">The complete JPEG XL file.</param>
/// <returns>The information, when the file is valid.</returns>
/// <exception cref="EJxlError">
///   The file is empty, truncated or invalid anywhere (headers, pixel data or boxes), exceeds the limits, or libjxl
///   cannot be loaded; <c>ApiName</c> and <c>Status</c> name the failing call or check.
/// </exception>
function JxlValidate( const AData: TBytes ): TJxlInfo; overload;

/// <summary>Checks a JPEG XL file completely within the given limits, optionally cancellable; see the bytes overload.</summary>
/// <param name="AData">The complete JPEG XL file.</param>
/// <param name="ALimits">The resource limits to enforce.</param>
/// <param name="ACancellation">Token that stops the check, or <c>nil</c>.</param>
/// <returns>The information, when the file is valid.</returns>
/// <exception cref="EArgumentException">A limit is zero or negative.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The file is invalid anywhere, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlValidate( const AData: TBytes; const ALimits: TJxlLimits; ACancellation: TJxlCancellation = nil ): TJxlInfo; overload;

/// <summary>Checks a JPEG XL file completely, from a stream's current position to its end; see the bytes overload.</summary>
/// <param name="AStream">The stream holding the file.</param>
/// <param name="ACancellation">Token that stops the check, or <c>nil</c>.</param>
/// <returns>The information, when the file is valid.</returns>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The file is empty, truncated or invalid anywhere, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlValidate( AStream: TStream; ACancellation: TJxlCancellation = nil ): TJxlInfo; overload;

/// <summary>Checks a JPEG XL file on disk completely; see the bytes overload.</summary>
/// <param name="AFileName">Path of the <c>.jxl</c> file.</param>
/// <param name="ACancellation">Token that stops the check, or <c>nil</c>.</param>
/// <returns>The information, when the file is valid.</returns>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">The file is empty, truncated or invalid anywhere, exceeds the limits, or libjxl cannot be loaded.</exception>
function JxlValidate( const AFileName: string; ACancellation: TJxlCancellation = nil ): TJxlInfo; overload;

/// <summary>
///   Copies a PNG's samples into pixels exactly, with straight (not premultiplied) alpha, for a sample-exact lossless
///   encode. <c>TPngImage</c> keeps colour and alpha separately and unpremultiplied, unlike a VCL bitmap.
/// </summary>
/// <remarks>
///   Handles 8-bit greyscale (1 channel), greyscale + alpha (2), RGB (3) and RGBA (4). Returns <c>False</c>, leaving
///   the caller to fall back on a bitmap, for palette PNGs, bit depths other than 8 (which <c>TPngImage</c> does not
///   keep exactly) and a single transparent colour (<c>tRNS</c>). The PNG's own colour profile, if any, is not carried
///   over: <see cref="TJxlPixels.IccProfile" /> stays empty, so encoding declares sRGB.
/// </remarks>
/// <param name="APng">The PNG.</param>
/// <param name="APixels">Receives the pixels when the result is <c>True</c>.</param>
/// <returns><c>True</c> when the PNG's samples could be copied exactly.</returns>
/// <exception cref="EArgumentException">The PNG is <c>nil</c> or empty.</exception>
/// <exception cref="EJxlError">The PNG is too large for one pixel buffer in this process.</exception>
function JxlTryPngToPixels( APng: TPngImage; out APixels: TJxlPixels ): Boolean;

/// <summary>
///   Encodes 8-bit pixels to a JPEG XL file, within the default limits; lossless encoding reproduces every sample
///   exactly. The file is written only once encoding has succeeded.
/// </summary>
/// <param name="APixels">The pixels to encode.</param>
/// <param name="AFileName">Path of the <c>.jxl</c> file to write; overwritten.</param>
/// <param name="AOptions">Lossless, distance and effort settings.</param>
/// <param name="ACancellation">Token that stops the encode, or <c>nil</c>; a cancelled encode writes nothing.</param>
/// <exception cref="EArgumentException">The pixel record is inconsistent (size, channel count) or the settings are out of range.</exception>
/// <exception cref="EJxlCancelled"><paramref name="ACancellation" /> was cancelled.</exception>
/// <exception cref="EJxlError">libjxl rejects the data or fails, the output exceeds the limits, or libjxl cannot be loaded.</exception>
procedure JxlEncodePixelsToFile( const APixels: TJxlPixels; const AFileName: string; const AOptions: TJxlEncodeOptions;
  ACancellation: TJxlCancellation = nil );

/// <summary>
///   A <c>JxlParallelRunner</c> that makes libjxl's work cancellable: it runs the tasks on libjxl's resizable thread pool,
///   but checks the token of its <see cref="TJxlCancellableRunner" /> before each batch and before each task, skips the
///   remaining tasks once the token is cancelled, and then returns <c>JXL_PARALLEL_RET_RUNNER_ERROR</c>, so the libjxl
///   call fails with an error status instead of finishing. Never raises.
/// </summary>
/// <remarks>
///   Without a token (<see cref="TJxlCancellableRunner.Cancellation" /> <c>nil</c>) it is <c>JxlResizableParallelRunner</c>.
///   Pass it with the address of a <see cref="TJxlCancellableRunner" /> to <c>JxlDecoderSetParallelRunner</c> or
///   <c>JxlEncoderSetParallelRunner</c>, after <c>JxlCheckLibrary</c>.
/// </remarks>
/// <param name="runner_opaque">The <see cref="TJxlCancellableRunner" />.</param>
/// <param name="jpegxl_opaque">libjxl's handle, passed on to <paramref name="init" /> and <paramref name="func" />.</param>
/// <param name="init">libjxl's initialisation callback.</param>
/// <param name="func">libjxl's task callback.</param>
/// <param name="start_range">First task value (inclusive).</param>
/// <param name="end_range">Last task value (exclusive).</param>
/// <returns>0 on success; <c>JXL_PARALLEL_RET_RUNNER_ERROR</c> when cancelled; otherwise what the resizable runner returned.</returns>
function JxlCancellableParallelRunner( runner_opaque: Pointer; jpegxl_opaque: Pointer; init: JxlParallelRunInit;
  func: JxlParallelRunFunction; start_range: UInt32; end_range: UInt32 ): JxlParallelRetCode; cdecl;

implementation

uses
  System.Math, System.IOUtils, System.SyncObjs,
  Jxl.Api.Decode, Jxl.Api.Encode, Jxl.Api.Threads, Jxl.Api.Cms;

resourcestring
  SJxlImageDescription = 'JPEG XL Image';

const
  /// <summary>Signature of a bare JPEG XL codestream.</summary>
  JXL_CODESTREAM_SIGNATURE: array[ 0..1 ] of Byte = ( $FF, $0A );
  /// <summary>Signature box that starts a JPEG XL container.</summary>
  JXL_CONTAINER_SIGNATURE: array[ 0..11 ] of Byte = ( $00, $00, $00, $0C, $4A, $58, $4C, $20, $0D, $0A, $87, $0A );
  /// <summary>
  ///   Output buffer size the encoders and the JPEG reconstruction start with, doubled as libjxl asks for more. Kept
  ///   small so that the growth path runs for every real image, and so is exercised by the tests.
  /// </summary>
  INITIAL_OUTPUT_BUFFER = 64 * 1024;
  /// <summary>Largest buffer one dynamic array can hold in this process.</summary>
  MAX_BUFFER_BYTES = Int64( High( NativeInt ) );
  /// <summary>Type of the box that holds JPEG reconstruction data.</summary>
  JPEG_RECONSTRUCTION_BOX: JxlBoxType = ( 'j', 'b', 'r', 'd' );
  /// <summary>Largest Butteraugli distance libjxl accepts.</summary>
  MAX_DISTANCE = 25.0;
  /// <summary>Lowest encoder effort.</summary>
  MIN_EFFORT = 1;
  /// <summary>Highest encoder effort without libjxl's expert options.</summary>
  MAX_EFFORT = 10;
  /// <summary>The six exception-mask bits of the SSE control register (MXCSR).</summary>
  MXCSR_EXCEPTION_MASKS = $1F80;
  /// <summary>Default <see cref="TJxlLimits.MaxJpegScans" />: far above the about 10 scans of standard progressions.</summary>
  DEFAULT_MAX_JPEG_SCANS = 64;
  /// <summary>Default <see cref="TJxlLimits.MaxExtraChannels" />: alpha, black and a few spot colours or masks.</summary>
  DEFAULT_MAX_EXTRA_CHANNELS = 16;
{$IFDEF CPU64BITS}
  /// <summary>Win64 default <see cref="TJxlLimits.MaxPixels" />: 256 megapixels (16384 x 16384).</summary>
  DEFAULT_MAX_PIXELS = UInt64( 256 ) * 1024 * 1024;
  /// <summary>Win64 default <see cref="TJxlLimits.MaxMemoryBytes" />: 8 GiB.</summary>
  DEFAULT_MAX_MEMORY = Int64( 8 ) * 1024 * 1024 * 1024;
  /// <summary>Win64 default <see cref="TJxlLimits.MaxInputBytes" /> and <see cref="TJxlLimits.MaxOutputBytes" />: 1 GiB.</summary>
  DEFAULT_MAX_IO_BYTES = Int64( 1 ) * 1024 * 1024 * 1024;
{$ELSE}
  /// <summary>Win32 default <see cref="TJxlLimits.MaxPixels" />: 32 megapixels (8192 x 4096).</summary>
  DEFAULT_MAX_PIXELS = UInt64( 32 ) * 1024 * 1024;
  /// <summary>Win32 default <see cref="TJxlLimits.MaxMemoryBytes" />: 1 GiB of a 2 GiB address space.</summary>
  DEFAULT_MAX_MEMORY = Int64( 1 ) * 1024 * 1024 * 1024;
  /// <summary>Win32 default <see cref="TJxlLimits.MaxInputBytes" /> and <see cref="TJxlLimits.MaxOutputBytes" />: 256 MiB.</summary>
  DEFAULT_MAX_IO_BYTES = Int64( 256 ) * 1024 * 1024;
{$ENDIF}

type
  /// <summary>Floating-point exception masks saved by <see cref="MaskFloatingPoint" />.</summary>
  TFloatingPointState = record
    /// <summary>The previous x87 (Win32) or SSE (Win64) mask.</summary>
    Mask: TArithmeticExceptionMask;
{$IFDEF CPUX86}
    /// <summary>The previous SSE control register, which Win32's <c>SetExceptionMask</c> does not touch.</summary>
    Mxcsr: Cardinal;
{$ENDIF}
  end;

  /// <summary>Where the image-out callback of <see cref="JxlDecodeToBitmap" /> writes: the bitmap's pixel memory.</summary>
  TBitmapTarget = record
    /// <summary>The first byte of row 0.</summary>
    First: PByte;
    /// <summary>Bytes from one row to the next; negative for a bottom-up DIB.</summary>
    Stride: NativeInt;
    /// <summary>Width in pixels.</summary>
    Width: NativeUInt;
    /// <summary>Height in pixels.</summary>
    Height: NativeUInt;
  end;
  /// <summary>Pointer to a <see cref="TBitmapTarget" />.</summary>
  PBitmapTarget = ^TBitmapTarget;

var
  /// <summary>Guards <see cref="GDefaultLimits" />.</summary>
  GLimitsLock: TCriticalSection;
  /// <summary>The process-wide default limits.</summary>
  GDefaultLimits: TJxlLimits;

{ Floating point }

{$IFDEF CPUX86}
/// <summary>Reads the SSE control register; <c>System.GetMXCSR</c> is marked platform.</summary>
/// <returns>The MXCSR value.</returns>
function GetMxcsr: Cardinal;
asm
  push  eax
  stmxcsr [ esp ]
  pop   eax
end;

/// <summary>Writes the SSE control register; <c>System.SetMXCSR</c> is marked platform.</summary>
/// <param name="AValue">The new MXCSR value.</param>
procedure SetMxcsr( AValue: Cardinal );
asm
  push  eax
  ldmxcsr [ esp ]
  pop   eax
end;
{$ENDIF}

/// <summary>Masks every floating-point exception, x87 and SSE, for the calling thread.</summary>
/// <returns>The previous state, for <see cref="RestoreFloatingPoint" />.</returns>
function MaskFloatingPoint: TFloatingPointState;
begin

  Result.Mask := SetExceptionMask( exAllArithmeticExceptions );
{$IFDEF CPUX86}
  Result.Mxcsr := GetMxcsr;
  SetMxcsr( Result.Mxcsr or MXCSR_EXCEPTION_MASKS );
{$ENDIF}

end;

/// <summary>Restores the floating-point exception masks saved by <see cref="MaskFloatingPoint" />.</summary>
/// <param name="AState">The saved state.</param>
procedure RestoreFloatingPoint( const AState: TFloatingPointState );
begin

{$IFDEF CPUX86}
  SetMxcsr( AState.Mxcsr );
{$ENDIF}
  SetExceptionMask( AState.Mask );

end;

/// <summary>
///   Runs a call into libjxl safely: masks floating-point exceptions, makes sure the library is loaded and verified
///   (so no delay-loaded import can fail), and turns an exception escaping from the DLL into <see cref="EJxlError" />.
/// </summary>
/// <param name="ARoutine">Name of the public routine, for errors.</param>
/// <param name="ACall">The work; it creates and destroys its own decoder or encoder, so one that an exception escaped
/// from is destroyed during unwinding and never reused.</param>
procedure RunLibjxl( const ARoutine: string; const ACall: TProc );
begin

  var rState := MaskFloatingPoint;

  try
    JxlCheckLibrary;

    try
      ACall;
    except
      on E: EExternalException do
        raise EJxlError.CreateCheck( ARoutine, Format( 'an exception escaped from libjxl (%s); the decoder or encoder was ' +
          'destroyed', [ E.Message ] ) );
    end;

  finally
    RestoreFloatingPoint( rState );
  end;

end;

{ Checks }

/// <summary>Raises <see cref="EJxlError" /> unless a decoder call returned <c>JXL_DEC_SUCCESS</c>.</summary>
/// <param name="AStatus">The status the call returned.</param>
/// <param name="AApiName">Name of the C function called.</param>
procedure CheckDecoder( AStatus: JxlDecoderStatus; const AApiName: string );
begin

  if ( AStatus <> JXL_DEC_SUCCESS ) then raise EJxlError.CreateStatus( AApiName, Ord( AStatus ) );

end;

/// <summary>Describes a <c>JxlEncoderError</c> in words.</summary>
/// <param name="AError">The error code.</param>
/// <returns>A short description.</returns>
function EncoderErrorText( AError: JxlEncoderError ): string;
begin

  case AError of
    JXL_ENC_ERR_OK:
      Result := 'no error recorded';
    JXL_ENC_ERR_OOM:
      Result := 'out of memory';
    JXL_ENC_ERR_JBRD:
      Result := 'the JPEG reconstruction data cannot be represented';
    JXL_ENC_ERR_BAD_INPUT:
      Result := 'invalid input';
    JXL_ENC_ERR_NOT_SUPPORTED:
      Result := 'not supported';
    JXL_ENC_ERR_API_USAGE:
      Result := 'invalid API usage or setting';
  else
    Result := 'generic encoder error';
  end;

end;

/// <summary>Raises <see cref="EJxlError" /> with the encoder's error code unless a call returned <c>JXL_ENC_SUCCESS</c>.</summary>
/// <param name="AStatus">The status the call returned.</param>
/// <param name="AApiName">Name of the C function called.</param>
/// <param name="AEncoder">The encoder, queried for its error code.</param>
procedure CheckEncoder( AStatus: JxlEncoderStatus; const AApiName: string; AEncoder: PJxlEncoder );
begin

  if ( AStatus <> JXL_ENC_SUCCESS ) then
  begin
    var eError := JxlEncoderGetError( AEncoder );

    raise EJxlError.CreateStatus( AApiName, Ord( eError ), EncoderErrorText( eError ) );
  end;

end;

/// <summary>Creates the exception for a decoder or encoder whose memory budget refused an allocation.</summary>
/// <param name="ABudget">The budget.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The exception, for the caller to raise.</returns>
function BudgetError( const ABudget: TJxlMemoryBudget; const ARoutine: string ): EJxlError;
begin

  Result := EJxlError.CreateCheck( ARoutine, Format( 'libjxl needed more memory than TJxlLimits.MaxMemoryBytes allows ' +
    '(%d bytes; %d allocation(s) refused)', [ ABudget.Limit, ABudget.Refusals ] ) );

end;

/// <summary>Creates a resizable thread-pool runner.</summary>
/// <returns>The runner handle; free it with <c>JxlResizableParallelRunnerDestroy</c>.</returns>
function CreateRunner: Pointer;
begin

  Result := JxlResizableParallelRunnerCreate( nil );

  if ( not Assigned( Result ) ) then
    raise EJxlError.CreateStatus( 'JxlResizableParallelRunnerCreate', JXL_PARALLEL_RET_RUNNER_ERROR,
      'the thread pool could not be created' );

end;

{ Cancellation }

type
  /// <summary>
  ///   One call of <see cref="JxlCancellableParallelRunner" />: libjxl's handle and callbacks, which the wrapping
  ///   callbacks forward to, and the token they check. Lives on that call's stack frame.
  /// </summary>
  TCancellableCall = record
    /// <summary>libjxl's <c>jpegxl_opaque</c> handle.</summary>
    Opaque: Pointer;
    /// <summary>libjxl's initialisation callback.</summary>
    Init: JxlParallelRunInit;
    /// <summary>libjxl's task callback.</summary>
    Func: JxlParallelRunFunction;
    /// <summary>The token; never <c>nil</c>.</summary>
    Cancellation: TJxlCancellation;
  end;
  /// <summary>Pointer to a <see cref="TCancellableCall" />.</summary>
  PCancellableCall = ^TCancellableCall;

/// <summary>Reports whether a token, which may be <c>nil</c>, has been cancelled.</summary>
/// <param name="ACancellation">The token, or <c>nil</c>.</param>
/// <returns><c>True</c> when it is assigned and cancelled.</returns>
function TokenCancelled( ACancellation: TJxlCancellation ): Boolean;
begin

  Result := Assigned( ACancellation ) and ACancellation.IsCancelled;

end;

/// <summary>Creates the exception for a routine stopped by its token.</summary>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The exception, for the caller to raise.</returns>
function CancelledError( const ARoutine: string ): EJxlCancelled;
begin

  Result := EJxlCancelled.CreateCheck( ARoutine, 'the operation was cancelled' );

end;

/// <summary>Raises <see cref="EJxlCancelled" /> when a token, which may be <c>nil</c>, has been cancelled.</summary>
/// <param name="ACancellation">The token, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckCancellation( ACancellation: TJxlCancellation; const ARoutine: string );
begin

  if TokenCancelled( ACancellation ) then raise CancelledError( ARoutine );

end;

/// <summary>
///   Initialisation callback of <see cref="JxlCancellableParallelRunner" />: forwards to libjxl's. Called on the runner's
///   calling thread; never raises.
/// </summary>
/// <param name="jpegxl_opaque">The <see cref="TCancellableCall" />.</param>
/// <param name="num_threads">Most threads the runner will use.</param>
/// <returns>What libjxl's callback returned.</returns>
function CancellableInit( jpegxl_opaque: Pointer; num_threads: NativeUInt ): JxlParallelRetCode; cdecl;
begin

  var pCall := PCancellableCall( jpegxl_opaque );

  Result := pCall.Init( pCall.Opaque, num_threads );

end;

/// <summary>
///   Task callback of <see cref="JxlCancellableParallelRunner" />: runs libjxl's task unless the token has been cancelled,
///   in which case the task is skipped (the runner then reports failure). Called on libjxl's worker threads; never raises.
/// </summary>
/// <param name="jpegxl_opaque">The <see cref="TCancellableCall" />.</param>
/// <param name="value">The task's value.</param>
/// <param name="thread_id">The calling thread's number.</param>
procedure CancellableFunc( jpegxl_opaque: Pointer; value: UInt32; thread_id: NativeUInt ); cdecl;
begin

  var pCall := PCancellableCall( jpegxl_opaque );

  if ( not pCall.Cancellation.IsCancelled ) then pCall.Func( pCall.Opaque, value, thread_id );

end;

function JxlCancellableParallelRunner( runner_opaque: Pointer; jpegxl_opaque: Pointer; init: JxlParallelRunInit;
  func: JxlParallelRunFunction; start_range: UInt32; end_range: UInt32 ): JxlParallelRetCode;
begin

  var pRunner := PJxlCancellableRunner( runner_opaque );

  if ( not Assigned( pRunner.Cancellation ) ) then
    Exit( JxlResizableParallelRunner( pRunner.Runner, jpegxl_opaque, init, func, start_range, end_range ) );

  if pRunner.Cancellation.IsCancelled then Exit( JXL_PARALLEL_RET_RUNNER_ERROR );

  var rCall: TCancellableCall;

  rCall.Opaque       := jpegxl_opaque;
  rCall.Init         := init;
  rCall.Func         := func;
  rCall.Cancellation := pRunner.Cancellation;
  Result             := JxlResizableParallelRunner( pRunner.Runner, @rCall, CancellableInit, CancellableFunc, start_range, end_range );

  // Some tasks may have been skipped: the batch is incomplete, so libjxl must not use its results.
  if ( Result = JXL_PARALLEL_RET_SUCCESS ) and pRunner.Cancellation.IsCancelled then Result := JXL_PARALLEL_RET_RUNNER_ERROR;

end;

/// <summary>Raises <c>EArgumentException</c> unless every field of a limits record is positive.</summary>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine, for the message.</param>
procedure CheckLimits( const ALimits: TJxlLimits; const ARoutine: string );
begin

  if ( ALimits.MaxPixels = 0 ) or ( ALimits.MaxExtraChannels = 0 ) or ( ALimits.MaxInputBytes <= 0 )
    or ( ALimits.MaxOutputBytes <= 0 ) or ( ALimits.MaxMemoryBytes <= 0 ) or ( ALimits.MaxJpegScans = 0 ) then
    raise EArgumentException.CreateFmt( '%s: every field of TJxlLimits must be positive.', [ ARoutine ] );

end;

/// <summary>Raises <see cref="EJxlError" /> for empty input, or input larger than the limits allow.</summary>
/// <param name="AData">The input.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckInputBytes( const AData: TBytes; const ALimits: TJxlLimits; const ARoutine: string );
begin

  if ( Length( AData ) = 0 ) then raise EJxlError.CreateCheck( ARoutine, 'the input is empty' );

  if ( Length( AData ) > ALimits.MaxInputBytes ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the input is %d bytes, more than TJxlLimits.MaxInputBytes (%d)',
      [ Int64( Length( AData ) ), ALimits.MaxInputBytes ] ) );

end;

/// <summary>Reads a stream from its position to its end, refusing more than the limits allow before reading.</summary>
/// <param name="AStream">The stream.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The bytes read.</returns>
function ReadStreamBytes( AStream: TStream; const ALimits: TJxlLimits; const ARoutine: string ): TBytes;
begin

  var iSize := Max( AStream.Size - AStream.Position, Int64( 0 ) );

  if ( iSize > ALimits.MaxInputBytes ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the input is %d bytes, more than TJxlLimits.MaxInputBytes (%d)',
      [ iSize, ALimits.MaxInputBytes ] ) );

  if ( iSize > MAX_BUFFER_BYTES ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the input is %d bytes, more than one buffer can hold in this process',
      [ iSize ] ) );

  SetLength( Result, NativeInt( iSize ) );

  if ( iSize > 0 ) then AStream.ReadBuffer( Result, NativeInt( iSize ) );

end;

/// <summary>Reads a whole file, refusing more than the limits allow before reading.</summary>
/// <param name="AFileName">Path of the file.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The file's bytes.</returns>
function ReadFileBytes( const AFileName: string; const ALimits: TJxlLimits; const ARoutine: string ): TBytes;
var
  oStream: TFileStream;
begin

  oStream := TFileStream.Create( AFileName, fmOpenRead or fmShareDenyWrite );

  try
    Result := ReadStreamBytes( oStream, ALimits, ARoutine );
  finally
    oStream.Free;
  end;

end;

/// <summary>Raises <see cref="EJxlError" /> when an image's header exceeds the pixel or extra-channel limits.</summary>
/// <param name="AInfo">The basic information libjxl reported.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckBasicInfo( const AInfo: JxlBasicInfo; const ALimits: TJxlLimits; const ARoutine: string );
begin

  var iPixels := UInt64( AInfo.xsize ) * AInfo.ysize;

  if ( iPixels > ALimits.MaxPixels ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the image is %d x %d pixels, more than TJxlLimits.MaxPixels (%d)',
      [ AInfo.xsize, AInfo.ysize, ALimits.MaxPixels ] ) );

  if ( AInfo.num_extra_channels > ALimits.MaxExtraChannels ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the image has %d extra channels, more than TJxlLimits.MaxExtraChannels (%d)',
      [ AInfo.num_extra_channels, ALimits.MaxExtraChannels ] ) );

end;

/// <summary>Raises <c>EArgumentException</c> for an effort outside 1 to 10.</summary>
/// <param name="AEffort">The effort.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckEffort( AEffort: Integer; const ARoutine: string );
begin

  if ( AEffort < MIN_EFFORT ) or ( AEffort > MAX_EFFORT ) then
    raise EArgumentException.CreateFmt( '%s: effort %d is outside %d to %d.', [ ARoutine, AEffort, MIN_EFFORT, MAX_EFFORT ] );

end;

/// <summary>Raises <c>EArgumentException</c> for encoder settings libjxl would reject or misread.</summary>
/// <param name="AOptions">The settings.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckEncodeOptions( const AOptions: TJxlEncodeOptions; const ARoutine: string );
begin

  CheckEffort( AOptions.Effort, ARoutine );

  if ( not AOptions.Lossless ) and ( IsNan( AOptions.Distance ) or ( AOptions.Distance > MAX_DISTANCE ) ) then
    raise EArgumentException.CreateFmt( '%s: distance %g is not a number up to %g (0 or less means lossless).',
      [ ARoutine, AOptions.Distance, MAX_DISTANCE ] );

end;

/// <summary>Returns the size of an 8-bit pixel buffer, computed without overflow.</summary>
/// <param name="AWidth">Width in pixels.</param>
/// <param name="AHeight">Height in pixels.</param>
/// <param name="AChannels">Samples per pixel.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The size in bytes.</returns>
function PixelBufferSize( AWidth: Cardinal; AHeight: Cardinal; AChannels: Cardinal; const ARoutine: string ): NativeInt;
begin

  var iSize := UInt64( AWidth ) * AHeight * AChannels;

  if ( iSize > UInt64( MAX_BUFFER_BYTES ) ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'an image of %d x %d pixels with %d channels needs %d bytes, more than one ' +
      'buffer can hold in this process', [ AWidth, AHeight, AChannels, iSize ] ) );

  Result := NativeInt( iSize );

end;

/// <summary>Raises <c>EArgumentException</c> when a pixel record is inconsistent.</summary>
/// <param name="APixels">The pixels to check.</param>
procedure ValidatePixels( const APixels: TJxlPixels );
begin

  if ( APixels.Width = 0 ) or ( APixels.Height = 0 ) then
    raise EArgumentException.Create( 'The JPEG XL pixel record has no width or height.' );

  if ( APixels.NumChannels < 1 ) or ( APixels.NumChannels > 4 ) then
    raise EArgumentException.CreateFmt( 'The JPEG XL pixel record has %d channels; 1 to 4 are supported.',
      [ APixels.NumChannels ] );

  var iExpected := UInt64( APixels.Width ) * APixels.Height * APixels.NumChannels;

  if ( UInt64( Length( APixels.Data ) ) <> iExpected ) then
    raise EArgumentException.CreateFmt( 'The JPEG XL pixel record holds %d bytes; %d x %d x %d needs %d.',
      [ Length( APixels.Data ), APixels.Width, APixels.Height, APixels.NumChannels, iExpected ] );

end;

{ Output buffers }

/// <summary>Returns the size an output buffer starts at: small, and never above the output limit.</summary>
/// <param name="ALimits">The limits.</param>
/// <returns>The size in bytes.</returns>
function InitialOutputSize( const ALimits: TJxlLimits ): NativeInt;
begin

  Result := NativeInt( Min( Int64( INITIAL_OUTPUT_BUFFER ), Min( ALimits.MaxOutputBytes, MAX_BUFFER_BYTES ) ) );

end;

/// <summary>
///   Doubles an output buffer, without overflow and never beyond <see cref="TJxlLimits.MaxOutputBytes" />; raises
///   <see cref="EJxlError" /> when it is already that large.
/// </summary>
/// <param name="ABuffer">The buffer; its contents are kept.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure GrowOutput( var ABuffer: TBytes; const ALimits: TJxlLimits; const ARoutine: string );
begin

  var iCap: Int64     := Min( ALimits.MaxOutputBytes, MAX_BUFFER_BYTES );
  var iCurrent: Int64 := Length( ABuffer );

  if ( iCurrent >= iCap ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the output would exceed %d bytes (TJxlLimits.MaxOutputBytes)', [ iCap ] ) );

  var iNew := if ( iCurrent > iCap div 2 ) then iCap else iCurrent * 2;

  SetLength( ABuffer, NativeInt( iNew ) );

end;

/// <summary>
///   Returns the exception that should replace a decoder or encoder failure: <see cref="EJxlCancelled" /> when the token
///   was cancelled (libjxl then failed because the runner stopped it), the budget error when the memory budget refused an
///   allocation, otherwise <c>nil</c> (re-raise the original).
/// </summary>
/// <param name="ABudget">The decoder's or encoder's memory budget.</param>
/// <param name="ACancellation">The token, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The replacement exception, for the caller to raise, or <c>nil</c>.</returns>
function ReplacementError( const ABudget: TJxlMemoryBudget; ACancellation: TJxlCancellation; const ARoutine: string ): EJxlError;
begin

  if TokenCancelled( ACancellation ) then Exit( CancelledError( ARoutine ) );

  if ( ABudget.Refusals > 0 ) then Exit( BudgetError( ABudget, ARoutine ) );

  Result := nil;

end;

/// <summary>Runs <c>JxlEncoderProcessOutput</c> to completion, growing the output buffer within the limits.</summary>
/// <param name="AEncoder">The encoder, with its input closed.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token checked before each further piece of output, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The encoded file.</returns>
function DrainEncoder( AEncoder: PJxlEncoder; const ALimits: TJxlLimits; ACancellation: TJxlCancellation;
  const ARoutine: string ): TBytes;
begin

  SetLength( Result, InitialOutputSize( ALimits ) );

  var pNext: PByte           := PByte( Result );
  var iAvailable: NativeUInt := Length( Result );
  var eStatus                := JxlEncoderProcessOutput( AEncoder, @pNext, @iAvailable );

  while ( eStatus = JXL_ENC_NEED_MORE_OUTPUT ) do
  begin
    CheckCancellation( ACancellation, ARoutine );

    var iUsed := pNext - PByte( Result );

    GrowOutput( Result, ALimits, ARoutine );
    pNext      := PByte( Result ) + iUsed;
    iAvailable := NativeUInt( Length( Result ) - iUsed );
    eStatus    := JxlEncoderProcessOutput( AEncoder, @pNext, @iAvailable );
  end;

  CheckEncoder( eStatus, 'JxlEncoderProcessOutput', AEncoder );
  SetLength( Result, pNext - PByte( Result ) );

end;

{ Decoding }

/// <summary>
///   Image-out callback of <see cref="JxlDecodeToBitmap" />: writes a run of RGBA pixels into the bitmap as BGRA.
///   Called by libjxl's worker threads for disjoint runs; it touches only the bitmap's memory and never raises.
/// </summary>
/// <param name="opaque">The <see cref="TBitmapTarget" />.</param>
/// <param name="x">Column of the first pixel.</param>
/// <param name="y">Row of the pixels.</param>
/// <param name="num_pixels">Pixels in the run.</param>
/// <param name="pixels">The run, 4 bytes per pixel in RGBA order.</param>
procedure WriteBitmapPixels( opaque: Pointer; x: NativeUInt; y: NativeUInt; num_pixels: NativeUInt; pixels: Pointer ); cdecl;
begin

  var pTarget := PBitmapTarget( opaque );

  if ( y >= pTarget.Height ) or ( x > pTarget.Width ) or ( num_pixels > pTarget.Width - x ) then Exit;

  var pDest   := pTarget.First + NativeInt( y ) * pTarget.Stride + NativeInt( x ) * 4;
  var pSource := PByte( pixels );
  var iCount  := num_pixels;

  while ( iCount > 0 ) do
  begin
    pDest[ 0 ] := pSource[ 2 ];
    pDest[ 1 ] := pSource[ 1 ];
    pDest[ 2 ] := pSource[ 0 ];
    pDest[ 3 ] := pSource[ 3 ];
    Inc( pDest, 4 );
    Inc( pSource, 4 );
    Dec( iCount );
  end;

end;

/// <summary>
///   Sizes a bitmap as a 32-bit image for <see cref="WriteBitmapPixels" /> and returns where its rows are.
/// </summary>
/// <param name="ABitmap">The bitmap.</param>
/// <param name="AWidth">Width in pixels.</param>
/// <param name="AHeight">Height in pixels.</param>
/// <returns>The first row and the stride, computed once instead of calling <c>ScanLine</c> per row.</returns>
function PrepareBitmap( ABitmap: TBitmap; AWidth: Cardinal; AHeight: Cardinal ): TBitmapTarget;
begin

  ABitmap.AlphaFormat := afIgnored;
  ABitmap.PixelFormat := pf32bit;
  ABitmap.SetSize( Integer( AWidth ), Integer( AHeight ) );
  Result.First  := PByte( ABitmap.ScanLine[ 0 ] );
  Result.Stride := 0;
  Result.Width  := AWidth;
  Result.Height := AHeight;

  if ( AHeight > 1 ) then Result.Stride := PByte( ABitmap.ScanLine[ 1 ] ) - Result.First;

end;

/// <summary>
///   Decodes the first frame of a JPEG XL file, in display orientation, either into pixels or, given a bitmap, straight
///   into the bitmap's memory; the caller runs it through <see cref="RunLibjxl" />.
/// </summary>
/// <param name="AData">The complete file.</param>
/// <param name="AColourOutput">Colour profile of the returned samples; a bitmap is always sRGB.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ABitmap">The bitmap to decode into, or <c>nil</c> to return the pixels.</param>
/// <param name="ACancellation">Token that stops the decode, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The pixels; with a bitmap, only the size and channel count (no data).</returns>
function DoDecodePixels( const AData: TBytes; AColourOutput: TJxlColourOutput; const ALimits: TJxlLimits; ABitmap: TBitmap;
  ACancellation: TJxlCancellation; const ARoutine: string ): TJxlPixels;
var
  pDecoder: PJxlDecoder;
  pRunner: Pointer;
  rBudget: TJxlMemoryBudget;
  rTarget: TBitmapTarget;
  rRunner: TJxlCancellableRunner;
begin

  Result := Default( TJxlPixels );
  rTarget := Default( TBitmapTarget );
  rBudget.Init( ALimits.MaxMemoryBytes );

  var rManager := rBudget.Manager;

  pDecoder := JxlDecoderCreate( @rManager );

  if ( not Assigned( pDecoder ) ) then
    raise EJxlError.CreateStatus( 'JxlDecoderCreate', Ord( JXL_DEC_ERROR ), 'the decoder could not be created' );

  try
    pRunner := CreateRunner;

    try
      try
        var bToBitmap := Assigned( ABitmap );

        rRunner.Runner       := pRunner;
        rRunner.Cancellation := ACancellation;
        CheckDecoder( JxlDecoderSetParallelRunner( pDecoder, JxlCancellableParallelRunner, @rRunner ), 'JxlDecoderSetParallelRunner' );
        CheckDecoder( JxlDecoderSetCms( pDecoder, JxlGetDefaultCms^ ), 'JxlDecoderSetCms' );
        CheckDecoder( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_COLOR_ENCODING )
          or Ord( JXL_DEC_FULL_IMAGE ) ), 'JxlDecoderSubscribeEvents' );
        CheckDecoder( JxlDecoderSetUnpremultiplyAlpha( pDecoder, JXL_TRUE ), 'JxlDecoderSetUnpremultiplyAlpha' );
        CheckDecoder( JxlDecoderSetInput( pDecoder, PByte( AData ), Length( AData ) ), 'JxlDecoderSetInput' );
        JxlDecoderCloseInput( pDecoder );

        var rFormat := Default( JxlPixelFormat );

        rFormat.data_type  := JXL_TYPE_UINT8;
        rFormat.endianness := JXL_NATIVE_ENDIAN;

        var bAlpha        := False;
        var bGreyToColour := False;
        var bDone         := False;
        var bImage        := False;

        while ( not bDone ) do
        begin
          CheckCancellation( ACancellation, ARoutine );

          var eStatus := JxlDecoderProcessInput( pDecoder );

          case eStatus of
            JXL_DEC_BASIC_INFO:
              begin
                var rInfo := Default( JxlBasicInfo );

                CheckDecoder( JxlDecoderGetBasicInfo( pDecoder, @rInfo ), 'JxlDecoderGetBasicInfo' );
                CheckBasicInfo( rInfo, ALimits, ARoutine );

                // Only the image's own profile keeps a grey image grey: sRGB output, and a bitmap, are RGB.
                var bGreyOut := ( rInfo.num_color_channels = 1 ) and ( AColourOutput = jcoImageProfile ) and ( not bToBitmap );

                bGreyToColour        := ( rInfo.num_color_channels = 1 ) and ( not bGreyOut );
                bAlpha               := ( rInfo.alpha_bits > 0 );
                Result.Width         := rInfo.xsize;
                Result.Height        := rInfo.ysize;
                Result.NumChannels   := ( if bGreyOut then 1 else 3 ) + ( if bAlpha then 1 else 0 );
                rFormat.num_channels := if bToBitmap then 4 else Result.NumChannels;
                JxlResizableParallelRunnerSetThreads( pRunner, JxlResizableParallelRunnerSuggestThreads( rInfo.xsize, rInfo.ysize ) );

                if bToBitmap then rTarget := PrepareBitmap( ABitmap, rInfo.xsize, rInfo.ysize );
              end;
            JXL_DEC_COLOR_ENCODING:
              begin
                // For sRGB, ask for it whatever the image's own profile: VCL displays bitmaps as sRGB, and an image coded
                // in its original (e.g. wide-gamut or other-gamma) profile would otherwise come out in that profile.
                if ( AColourOutput = jcoSrgb ) or bToBitmap then
                begin
                  var rSrgb := Default( JxlColorEncoding );

                  JxlColorEncodingSetToSRGB( @rSrgb, JXL_FALSE );
                  CheckDecoder( JxlDecoderSetOutputColorProfile( pDecoder, @rSrgb, nil, 0 ), 'JxlDecoderSetOutputColorProfile' );
                end;

                // JXL_DEC_ERROR here only means libjxl cannot express the output profile as ICC: IccProfile stays empty.
                // A grey image expanded to RGB is reported with a grey profile, which would not describe 3-channel
                // samples (and could not be encoded with them): its samples are plain sRGB, so IccProfile stays empty.
                var iIccSize: NativeUInt := 0;

                if ( not bToBitmap ) and ( not bGreyToColour )
                  and ( JxlDecoderGetICCProfileSize( pDecoder, JXL_COLOR_PROFILE_TARGET_DATA, @iIccSize ) = JXL_DEC_SUCCESS )
                  and ( iIccSize > 0 ) then
                begin
                  SetLength( Result.IccProfile, iIccSize );
                  CheckDecoder( JxlDecoderGetColorAsICCProfile( pDecoder, JXL_COLOR_PROFILE_TARGET_DATA, PByte( Result.IccProfile ),
                    iIccSize ), 'JxlDecoderGetColorAsICCProfile' );
                end;

              end;
            JXL_DEC_NEED_IMAGE_OUT_BUFFER:
              begin
                if bToBitmap then
                  CheckDecoder( JxlDecoderSetImageOutCallback( pDecoder, @rFormat, WriteBitmapPixels, @rTarget ),
                    'JxlDecoderSetImageOutCallback' )
                else
                begin
                  var iSize: NativeUInt := 0;

                  CheckDecoder( JxlDecoderImageOutBufferSize( pDecoder, @rFormat, @iSize ), 'JxlDecoderImageOutBufferSize' );

                  var iExpected := PixelBufferSize( Result.Width, Result.Height, Result.NumChannels, ARoutine );

                  if ( UInt64( iSize ) <> UInt64( iExpected ) ) then
                    raise EJxlError.CreateCheck( ARoutine, Format( 'libjxl asked for a %d-byte output buffer, not %d',
                      [ UInt64( iSize ), Int64( iExpected ) ] ) );

                  SetLength( Result.Data, iExpected );
                  CheckDecoder( JxlDecoderSetImageOutBuffer( pDecoder, @rFormat, PByte( Result.Data ), iSize ),
                    'JxlDecoderSetImageOutBuffer' );
                end;

              end;
            JXL_DEC_FULL_IMAGE:
              begin
                bImage := True;
                bDone  := True;
              end;
            JXL_DEC_SUCCESS:
              begin
                if ( not bImage ) then raise EJxlError.CreateCheck( ARoutine, 'the file holds no image' );

                bDone := True;
              end;
            JXL_DEC_NEED_MORE_INPUT:
              raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ), 'the file is truncated' );
          else
            raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ) );
          end;

        end;

        if bToBitmap then
        begin
          // Straight samples were written into a bitmap marked afIgnored; marking it afDefined premultiplies them.
          if bAlpha then ABitmap.AlphaFormat := afDefined;

          ABitmap.Modified := True;
        end;

      except
        on EJxlError do
        begin
          var eReplacement := ReplacementError( rBudget, ACancellation, ARoutine );

          if Assigned( eReplacement ) then raise eReplacement else raise;
        end;
      end;

    finally
      JxlResizableParallelRunnerDestroy( pRunner );
    end;

  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

{ Encoding }

/// <summary>Encodes pixels; the caller has validated them and runs it through <see cref="RunLibjxl" />.</summary>
/// <param name="APixels">The pixels.</param>
/// <param name="AOptions">The encoder settings, already checked.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token that stops the encode, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The JPEG XL file.</returns>
function DoEncodePixels( const APixels: TJxlPixels; const AOptions: TJxlEncodeOptions; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation; const ARoutine: string ): TBytes;
var
  pEncoder: PJxlEncoder;
  pRunner: Pointer;
  rBudget: TJxlMemoryBudget;
  rRunner: TJxlCancellableRunner;
begin

  rBudget.Init( ALimits.MaxMemoryBytes );

  var rManager := rBudget.Manager;

  pEncoder := JxlEncoderCreate( @rManager );

  if ( not Assigned( pEncoder ) ) then
    raise EJxlError.CreateStatus( 'JxlEncoderCreate', Ord( JXL_ENC_ERROR ), 'the encoder could not be created' );

  try
    pRunner := CreateRunner;

    try
      try
        JxlResizableParallelRunnerSetThreads( pRunner, JxlResizableParallelRunnerSuggestThreads( APixels.Width, APixels.Height ) );
        rRunner.Runner       := pRunner;
        rRunner.Cancellation := ACancellation;
        CheckEncoder( JxlEncoderSetParallelRunner( pEncoder, JxlCancellableParallelRunner, @rRunner ), 'JxlEncoderSetParallelRunner',
          pEncoder );

        // A distance of 0 or less asks for no loss at all: encode losslessly.
        var bLossless := AOptions.Lossless or ( AOptions.Distance <= 0 );
        var bAlpha    := ( APixels.NumChannels = 2 ) or ( APixels.NumChannels = 4 );
        var bGrey     := ( APixels.NumChannels <= 2 );
        var rInfo     := Default( JxlBasicInfo );

        JxlEncoderInitBasicInfo( @rInfo );
        rInfo.xsize                    := APixels.Width;
        rInfo.ysize                    := APixels.Height;
        rInfo.bits_per_sample          := 8;
        rInfo.exponent_bits_per_sample := 0;
        rInfo.num_color_channels       := if bGrey then 1 else 3;
        rInfo.uses_original_profile    := if bLossless then JXL_TRUE else JXL_FALSE;

        if bAlpha then
        begin
          rInfo.num_extra_channels  := 1;
          rInfo.alpha_bits          := 8;
          rInfo.alpha_premultiplied := if APixels.AlphaPremultiplied then JXL_TRUE else JXL_FALSE;
        end;

        CheckEncoder( JxlEncoderSetBasicInfo( pEncoder, @rInfo ), 'JxlEncoderSetBasicInfo', pEncoder );

        if ( Length( APixels.IccProfile ) > 0 ) then
          CheckEncoder( JxlEncoderSetICCProfile( pEncoder, PByte( APixels.IccProfile ), Length( APixels.IccProfile ) ),
            'JxlEncoderSetICCProfile', pEncoder )
        else
        begin
          var rColour := Default( JxlColorEncoding );

          JxlColorEncodingSetToSRGB( @rColour, if bGrey then JXL_TRUE else JXL_FALSE );
          CheckEncoder( JxlEncoderSetColorEncoding( pEncoder, @rColour ), 'JxlEncoderSetColorEncoding', pEncoder );
        end;

        var pSettings := JxlEncoderFrameSettingsCreate( pEncoder, nil );

        if ( not Assigned( pSettings ) ) then
          raise EJxlError.CreateStatus( 'JxlEncoderFrameSettingsCreate', Ord( JXL_ENC_ERROR ), 'no frame settings' );

        CheckEncoder( JxlEncoderFrameSettingsSetOption( pSettings, JXL_ENC_FRAME_SETTING_EFFORT, AOptions.Effort ),
          'JxlEncoderFrameSettingsSetOption', pEncoder );

        if bLossless then
          CheckEncoder( JxlEncoderSetFrameLossless( pSettings, JXL_TRUE ), 'JxlEncoderSetFrameLossless', pEncoder )
        else
          CheckEncoder( JxlEncoderSetFrameDistance( pSettings, AOptions.Distance ), 'JxlEncoderSetFrameDistance', pEncoder );

        var rFormat := Default( JxlPixelFormat );

        rFormat.num_channels := APixels.NumChannels;
        rFormat.data_type    := JXL_TYPE_UINT8;
        rFormat.endianness   := JXL_NATIVE_ENDIAN;
        CheckEncoder( JxlEncoderAddImageFrame( pSettings, @rFormat, PByte( APixels.Data ), Length( APixels.Data ) ),
          'JxlEncoderAddImageFrame', pEncoder );
        JxlEncoderCloseInput( pEncoder );
        Result := DrainEncoder( pEncoder, ALimits, ACancellation, ARoutine );
      except
        on EJxlError do
        begin
          var eReplacement := ReplacementError( rBudget, ACancellation, ARoutine );

          if Assigned( eReplacement ) then raise eReplacement else raise;
        end;
      end;

    finally
      JxlResizableParallelRunnerDestroy( pRunner );
    end;

  finally
    JxlEncoderDestroy( pEncoder );
  end;

end;

{ JPEG }

/// <summary>
///   Pre-checks a JPEG before libjxl parses it: walks its marker segments with bounds checks and raises
///   <see cref="EJxlError" /> when the structure is truncated or garbled, the frame exceeds the pixel limit or would
///   need more DCT coefficient memory than <see cref="TJxlLimits.MaxMemoryBytes" />, or there are more scans than
///   <see cref="TJxlLimits.MaxJpegScans" />.
/// </summary>
/// <param name="AData">The JPEG file.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckJpegStructure( const AData: TBytes; const ALimits: TJxlLimits; const ARoutine: string );
var
  iLength: NativeInt;

  /// <summary>Raises the binding-check error for a JPEG fault.</summary>
  /// <param name="ADetail">What is wrong, following "the JPEG".</param>
  procedure Fail( const ADetail: string );
  begin

    raise EJxlError.CreateCheck( ARoutine, Format( 'the JPEG %s', [ ADetail ] ) );

  end;

  /// <summary>Reads a big-endian 16-bit value; the caller has checked both bytes are present.</summary>
  /// <param name="AOffset">Offset of the first byte.</param>
  /// <returns>The value.</returns>
  function ReadWord( AOffset: NativeInt ): Integer;
  begin

    Result := ( AData[ AOffset ] shl 8 ) or AData[ AOffset + 1 ];

  end;

  /// <summary>Checks a frame header (SOFn) payload: components, sampling factors, size and coefficient memory.</summary>
  /// <param name="AOffset">Offset of the payload, after the length field.</param>
  /// <param name="ALength">Length of the payload.</param>
  procedure CheckFrame( AOffset: NativeInt; ALength: Integer );
  begin

    if ( ALength < 6 ) then Fail( 'has a frame header too short to hold its size' );

    var iHeight     := ReadWord( AOffset + 1 );
    var iWidth      := ReadWord( AOffset + 3 );
    var iComponents := Integer( AData[ AOffset + 5 ] );

    if ( iComponents < 1 ) or ( iComponents > 4 ) then
      Fail( Format( 'has %d components; 1 to 4 are supported', [ iComponents ] ) );

    if ( ALength <> 6 + 3 * iComponents ) then Fail( 'has a frame header whose length does not match its component count' );

    if ( iWidth = 0 ) or ( iHeight = 0 ) then Fail( 'declares a zero width or height' );

    if ( UInt64( iWidth ) * UInt64( iHeight ) > ALimits.MaxPixels ) then
      Fail( Format( 'is %d x %d pixels, more than TJxlLimits.MaxPixels (%d)', [ iWidth, iHeight, ALimits.MaxPixels ] ) );

    var iMaxH := 1;
    var iMaxV := 1;

    for var iI := 0 to iComponents - 1 do
    begin
      var iSampling := AData[ AOffset + 7 + 3 * iI ];
      var iH        := iSampling shr 4;
      var iV        := iSampling and $0F;

      if ( iH < 1 ) or ( iH > 4 ) or ( iV < 1 ) or ( iV > 4 ) then Fail( 'has an invalid sampling factor' );

      iMaxH := Max( iMaxH, iH );
      iMaxV := Max( iMaxV, iV );
    end;

    // Every component is stored as whole MCUs of 8 x 8 blocks of 16-bit coefficients.
    var iMcuColumns := UInt64( ( iWidth + 8 * iMaxH - 1 ) div ( 8 * iMaxH ) );
    var iMcuRows    := UInt64( ( iHeight + 8 * iMaxV - 1 ) div ( 8 * iMaxV ) );
    var iBytes      := UInt64( 0 );

    for var iI := 0 to iComponents - 1 do
    begin
      var iSampling := AData[ AOffset + 7 + 3 * iI ];

      iBytes := iBytes + iMcuColumns * ( iSampling shr 4 ) * iMcuRows * ( iSampling and $0F ) * 64 * SizeOf( SmallInt );
    end;

    if ( iBytes > UInt64( ALimits.MaxMemoryBytes ) ) or ( iBytes > UInt64( MAX_BUFFER_BYTES ) ) then
      Fail( Format( 'would need %d bytes of DCT coefficients, more than TJxlLimits.MaxMemoryBytes (%d) or this process allows',
        [ iBytes, ALimits.MaxMemoryBytes ] ) );

  end;

  /// <summary>Skips entropy-coded data after a scan header, to the next marker that is not a restart marker.</summary>
  /// <param name="AOffset">Offset of the first byte of entropy-coded data.</param>
  /// <returns>Offset of the 0xFF that starts the next marker.</returns>
  function SkipEntropyData( AOffset: NativeInt ): NativeInt;
  begin

    Result := AOffset;

    while ( Result + 1 < iLength ) do
    begin
      if ( AData[ Result ] = $FF ) and ( AData[ Result + 1 ] <> 0 ) and ( AData[ Result + 1 ] not in [ $D0..$D7 ] ) then Exit;

      Inc( Result );
    end;

    Fail( 'is truncated inside its entropy-coded data' );

  end;

begin

  iLength := Length( AData );

  if ( iLength < 4 ) or ( AData[ 0 ] <> $FF ) or ( AData[ 1 ] <> $D8 ) then Fail( 'does not start with a start-of-image marker' );

  var iPos: NativeInt     := 2;
  var bFrame              := False;
  var iScans: Cardinal    := 0;

  while True do
  begin
    if ( iPos >= iLength ) then Fail( 'is truncated: it ends before its end-of-image marker' );

    if ( AData[ iPos ] <> $FF ) then Fail( Format( 'is garbled: no marker at offset %d', [ Int64( iPos ) ] ) );

    while ( iPos < iLength ) and ( AData[ iPos ] = $FF ) do Inc( iPos );

    if ( iPos >= iLength ) then Fail( 'is truncated inside a marker' );

    var iMarker := AData[ iPos ];

    Inc( iPos );

    if ( iMarker = $D9 ) then Break;

    if ( iMarker = $01 ) or ( iMarker in [ $D0..$D7 ] ) then Continue;

    if ( iMarker = $00 ) or ( iMarker = $D8 ) then
      Fail( Format( 'is garbled: unexpected marker $%.2x at offset %d', [ iMarker, Int64( iPos - 1 ) ] ) );

    if ( iPos + 2 > iLength ) then Fail( 'is truncated inside a segment length' );

    var iSegment := ReadWord( iPos );

    if ( iSegment < 2 ) then Fail( Format( 'is garbled: a segment at offset %d declares %d bytes', [ Int64( iPos ), iSegment ] ) );

    if ( iPos + iSegment > iLength ) then
      Fail( Format( 'is truncated: a segment at offset %d declares %d bytes, %d remain', [ Int64( iPos ), iSegment,
        Int64( iLength - iPos ) ] ) );

    if ( iMarker in [ $C0..$C3, $C5..$C7, $C9..$CB, $CD..$CF ] ) then
    begin
      if bFrame then Fail( 'has more than one frame header' );

      CheckFrame( iPos + 2, iSegment - 2 );
      bFrame := True;
    end
    else if ( iMarker = $DA ) then
    begin
      if ( not bFrame ) then Fail( 'has a scan before its frame header' );

      Inc( iScans );

      if ( iScans > ALimits.MaxJpegScans ) then
        Fail( Format( 'has more than %d scans (TJxlLimits.MaxJpegScans)', [ ALimits.MaxJpegScans ] ) );
    end;

    Inc( iPos, iSegment );

    if ( iMarker = $DA ) then iPos := SkipEntropyData( iPos );
  end;

  if ( not bFrame ) or ( iScans = 0 ) then Fail( 'has no frame header or no scan' );

end;

/// <summary>Recompresses a JPEG; the caller has pre-checked it and runs it through <see cref="RunLibjxl" />.</summary>
/// <param name="AJpegData">The JPEG file.</param>
/// <param name="AEffort">Encoder effort.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token that stops the recompression, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The JPEG XL file.</returns>
function DoTranscodeJpeg( const AJpegData: TBytes; AEffort: Integer; const ALimits: TJxlLimits; ACancellation: TJxlCancellation;
  const ARoutine: string ): TBytes;
var
  pEncoder: PJxlEncoder;
  pRunner: Pointer;
  rBudget: TJxlMemoryBudget;
  rRunner: TJxlCancellableRunner;
begin

  rBudget.Init( ALimits.MaxMemoryBytes );

  var rManager := rBudget.Manager;

  pEncoder := JxlEncoderCreate( @rManager );

  if ( not Assigned( pEncoder ) ) then
    raise EJxlError.CreateStatus( 'JxlEncoderCreate', Ord( JXL_ENC_ERROR ), 'the encoder could not be created' );

  try
    pRunner := CreateRunner;

    try
      try
        JxlResizableParallelRunnerSetThreads( pRunner, CPUCount );
        rRunner.Runner       := pRunner;
        rRunner.Cancellation := ACancellation;
        CheckEncoder( JxlEncoderSetParallelRunner( pEncoder, JxlCancellableParallelRunner, @rRunner ), 'JxlEncoderSetParallelRunner',
          pEncoder );
        CheckEncoder( JxlEncoderUseContainer( pEncoder, JXL_TRUE ), 'JxlEncoderUseContainer', pEncoder );
        CheckEncoder( JxlEncoderStoreJPEGMetadata( pEncoder, JXL_TRUE ), 'JxlEncoderStoreJPEGMetadata', pEncoder );

        var pSettings := JxlEncoderFrameSettingsCreate( pEncoder, nil );

        if ( not Assigned( pSettings ) ) then
          raise EJxlError.CreateStatus( 'JxlEncoderFrameSettingsCreate', Ord( JXL_ENC_ERROR ), 'no frame settings' );

        CheckEncoder( JxlEncoderFrameSettingsSetOption( pSettings, JXL_ENC_FRAME_SETTING_EFFORT, AEffort ),
          'JxlEncoderFrameSettingsSetOption', pEncoder );
        CheckEncoder( JxlEncoderAddJPEGFrame( pSettings, PByte( AJpegData ), Length( AJpegData ) ), 'JxlEncoderAddJPEGFrame',
          pEncoder );
        JxlEncoderCloseInput( pEncoder );
        Result := DrainEncoder( pEncoder, ALimits, ACancellation, ARoutine );
      except
        on EJxlError do
        begin
          var eReplacement := ReplacementError( rBudget, ACancellation, ARoutine );

          if Assigned( eReplacement ) then raise eReplacement else raise;
        end;
      end;

    finally
      JxlResizableParallelRunnerDestroy( pRunner );
    end;

  finally
    JxlEncoderDestroy( pEncoder );
  end;

end;

/// <summary>
///   Raises <see cref="EJxlError" /> when the DCT coefficients of a JPEG to be reconstructed from an image of this size
///   would need more memory than the limit allows or this process can address.
/// </summary>
/// <param name="AInfo">The basic information libjxl reported.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckReconstructionMemory( const AInfo: JxlBasicInfo; const ALimits: TJxlLimits; const ARoutine: string );
begin

  // An upper bound: every colour component at full resolution, 8 x 8 blocks of 16-bit coefficients.
  var iBlocks := ( ( UInt64( AInfo.xsize ) + 7 ) div 8 ) * ( ( UInt64( AInfo.ysize ) + 7 ) div 8 );
  var iBytes  := iBlocks * 64 * SizeOf( SmallInt ) * Max( AInfo.num_color_channels, Cardinal( 1 ) );

  if ( iBytes > UInt64( ALimits.MaxMemoryBytes ) ) or ( iBytes > UInt64( MAX_BUFFER_BYTES ) ) then
    raise EJxlError.CreateCheck( ARoutine, Format( 'the JPEG would need %d bytes of DCT coefficients, more than ' +
      'TJxlLimits.MaxMemoryBytes (%d) or this process allows', [ iBytes, ALimits.MaxMemoryBytes ] ) );

end;

/// <summary>Reconstructs a recompressed JPEG; the caller runs it through <see cref="RunLibjxl" />.</summary>
/// <param name="AJxlData">The JPEG XL file.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token that stops the reconstruction, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The JPEG file.</returns>
function DoReconstructJpeg( const AJxlData: TBytes; const ALimits: TJxlLimits; ACancellation: TJxlCancellation;
  const ARoutine: string ): TBytes;
var
  pDecoder: PJxlDecoder;
  pRunner: Pointer;
  rBudget: TJxlMemoryBudget;
  rRunner: TJxlCancellableRunner;
begin

  rBudget.Init( ALimits.MaxMemoryBytes );

  var rManager := rBudget.Manager;

  pDecoder := JxlDecoderCreate( @rManager );

  if ( not Assigned( pDecoder ) ) then
    raise EJxlError.CreateStatus( 'JxlDecoderCreate', Ord( JXL_DEC_ERROR ), 'the decoder could not be created' );

  try
    pRunner := CreateRunner;

    try
      try
        JxlResizableParallelRunnerSetThreads( pRunner, CPUCount );
        rRunner.Runner       := pRunner;
        rRunner.Cancellation := ACancellation;
        CheckDecoder( JxlDecoderSetParallelRunner( pDecoder, JxlCancellableParallelRunner, @rRunner ), 'JxlDecoderSetParallelRunner' );
        CheckDecoder( JxlDecoderSubscribeEvents( pDecoder, Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_JPEG_RECONSTRUCTION )
          or Ord( JXL_DEC_FULL_IMAGE ) ), 'JxlDecoderSubscribeEvents' );
        CheckDecoder( JxlDecoderSetInput( pDecoder, PByte( AJxlData ), Length( AJxlData ) ), 'JxlDecoderSetInput' );
        JxlDecoderCloseInput( pDecoder );
        SetLength( Result, InitialOutputSize( ALimits ) );

        var bHaveJpeg := False;
        var bDone     := False;

        while ( not bDone ) do
        begin
          CheckCancellation( ACancellation, ARoutine );

          var eStatus := JxlDecoderProcessInput( pDecoder );

          case eStatus of
            JXL_DEC_BASIC_INFO:
              begin
                var rInfo := Default( JxlBasicInfo );

                CheckDecoder( JxlDecoderGetBasicInfo( pDecoder, @rInfo ), 'JxlDecoderGetBasicInfo' );
                CheckBasicInfo( rInfo, ALimits, ARoutine );
                CheckReconstructionMemory( rInfo, ALimits, ARoutine );
              end;
            JXL_DEC_JPEG_RECONSTRUCTION:
              begin
                bHaveJpeg := True;
                CheckDecoder( JxlDecoderSetJPEGBuffer( pDecoder, PByte( Result ), Length( Result ) ), 'JxlDecoderSetJPEGBuffer' );
              end;
            JXL_DEC_JPEG_NEED_MORE_OUTPUT:
              begin
                var iUsed := NativeInt( NativeUInt( Length( Result ) ) - JxlDecoderReleaseJPEGBuffer( pDecoder ) );

                GrowOutput( Result, ALimits, ARoutine );
                CheckDecoder( JxlDecoderSetJPEGBuffer( pDecoder, PByte( Result ) + iUsed, NativeUInt( Length( Result ) - iUsed ) ),
                  'JxlDecoderSetJPEGBuffer' );
              end;
            JXL_DEC_FULL_IMAGE, JXL_DEC_SUCCESS:
              begin
                if ( not bHaveJpeg ) then raise EJxlError.CreateCheck( ARoutine, 'the file holds no JPEG reconstruction data' );

                SetLength( Result, NativeUInt( Length( Result ) ) - JxlDecoderReleaseJPEGBuffer( pDecoder ) );
                bDone := True;
              end;
            JXL_DEC_NEED_IMAGE_OUT_BUFFER:
              raise EJxlError.CreateCheck( ARoutine, 'the file holds no JPEG reconstruction data' );
            JXL_DEC_NEED_MORE_INPUT:
              raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ), 'the file is truncated' );
          else
            raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ) );
          end;

        end;

      except
        on EJxlError do
        begin
          var eReplacement := ReplacementError( rBudget, ACancellation, ARoutine );

          if Assigned( eReplacement ) then raise eReplacement else raise;
        end;
      end;

    finally
      JxlResizableParallelRunnerDestroy( pRunner );
    end;

  finally
    JxlDecoderDestroy( pDecoder );
  end;

end;

{ Information }

/// <summary>Reads a big-endian unsigned integer from data.</summary>
/// <param name="AData">The data.</param>
/// <param name="AOffset">Offset of the first byte.</param>
/// <param name="ACount">Number of bytes, 4 or 8.</param>
/// <returns>The value.</returns>
function ReadBigEndian( const AData: TBytes; AOffset: Int64; ACount: Integer ): UInt64;
begin

  Result := 0;

  for var iI := 0 to ACount - 1 do Result := ( Result shl 8 ) or AData[ AOffset + iI ];

end;

/// <summary>
///   For a file in the container format, raises <see cref="EJxlError" /> when a box header is cut short or a box
///   declares more bytes than the data holds, or fewer than its own header. A bare codestream is left alone: it has no
///   box sizes to check.
/// </summary>
/// <param name="AData">The complete file.</param>
/// <param name="ARoutine">Name of the public routine.</param>
procedure CheckContainerBoxes( const AData: TBytes; const ARoutine: string );
begin

  if ( Length( AData ) < Length( JXL_CONTAINER_SIGNATURE ) )
    or ( not CompareMem( PByte( AData ), @JXL_CONTAINER_SIGNATURE, Length( JXL_CONTAINER_SIGNATURE ) ) ) then Exit;

  var iLength: Int64 := Length( AData );
  var iOffset: Int64 := 0;

  while ( iOffset < iLength ) do
  begin
    var iAvailable := iLength - iOffset;

    if ( iAvailable < 8 ) then
      raise EJxlError.CreateCheck( ARoutine, Format( 'truncated: a box header needs 8 bytes, %d available', [ iAvailable ] ) );

    var sType := TEncoding.ANSI.GetString( AData, iOffset + 4, 4 );
    var iSize := ReadBigEndian( AData, iOffset, 4 );
    var iHeader: Int64 := 8;

    if ( iSize = 1 ) then
    begin
      // Large-size form: the real size follows the type as a 64-bit value.
      if ( iAvailable < 16 ) then
        raise EJxlError.CreateCheck( ARoutine, Format( 'truncated: box %s needs a 16-byte header, %d available',
          [ sType, iAvailable ] ) );

      iSize   := ReadBigEndian( AData, iOffset + 8, 8 );
      iHeader := 16;
    end
    else if ( iSize = 0 ) then
      Exit;   // the last box, running to the end of the file

    if ( iSize < UInt64( iHeader ) ) then
      raise EJxlError.CreateCheck( ARoutine, Format( 'invalid: box %s declares %d bytes, less than its own header',
        [ sType, iSize ] ) );

    if ( iSize > UInt64( iAvailable ) ) then
      raise EJxlError.CreateCheck( ARoutine, Format( 'truncated: box %s declares %d bytes, %d available',
        [ sType, iSize, iAvailable ] ) );

    Inc( iOffset, Int64( iSize ) );
  end;

end;

/// <summary>Image-out callback of <see cref="JxlValidate" />: the decoded pixels are discarded.</summary>
/// <param name="opaque">Unused.</param>
/// <param name="x">Unused.</param>
/// <param name="y">Unused.</param>
/// <param name="num_pixels">Unused.</param>
/// <param name="pixels">Unused.</param>
procedure DiscardPixels( opaque: Pointer; x: NativeUInt; y: NativeUInt; num_pixels: NativeUInt; pixels: Pointer ); cdecl;
begin

  // Nothing to do: JxlValidate only needs the decoder to produce the pixels.

end;

/// <summary>
///   Reads the image's original colour encoding into the information, at <c>JXL_DEC_COLOR_ENCODING</c>: the encoded
///   profile when there is one, otherwise the ICC profile's size and, from its header, its colour space.
/// </summary>
/// <param name="ADecoder">The decoder, at the colour-encoding event.</param>
/// <param name="AInfo">The information to complete.</param>
procedure ReadColourEncoding( ADecoder: PJxlDecoder; var AInfo: TJxlInfo );
const
  /// <summary>Offset of the data colour space signature in an ICC profile header.</summary>
  ICC_COLOUR_SPACE_OFFSET = 16;
begin

  var rEncoding := Default( JxlColorEncoding );

  // JXL_DEC_ERROR here means the file has no encoded profile: it describes its colour with an ICC profile instead.
  if ( JxlDecoderGetColorAsEncodedProfile( ADecoder, JXL_COLOR_PROFILE_TARGET_ORIGINAL, @rEncoding ) = JXL_DEC_SUCCESS ) then
  begin
    AInfo.ColourEncoding := rEncoding;

    case rEncoding.color_space of
      JXL_COLOR_SPACE_RGB:
        AInfo.ColourSpace := jcsRgb;
      JXL_COLOR_SPACE_GRAY:
        AInfo.ColourSpace := jcsGrey;
      JXL_COLOR_SPACE_XYB:
        AInfo.ColourSpace := jcsXyb;
    else
      AInfo.ColourSpace := jcsUnknown;
    end;

    AInfo.IsSrgb := ( rEncoding.white_point = JXL_WHITE_POINT_D65 ) and ( rEncoding.transfer_function = JXL_TRANSFER_FUNCTION_SRGB )
      and ( ( AInfo.ColourSpace = jcsGrey ) or ( ( AInfo.ColourSpace = jcsRgb ) and ( rEncoding.primaries = JXL_PRIMARIES_SRGB ) ) );
    Exit;
  end;

  var iSize: NativeUInt := 0;

  CheckDecoder( JxlDecoderGetICCProfileSize( ADecoder, JXL_COLOR_PROFILE_TARGET_ORIGINAL, @iSize ), 'JxlDecoderGetICCProfileSize' );
  AInfo.HasIccProfile  := True;
  AInfo.IccProfileSize := iSize;

  if ( iSize < ICC_COLOUR_SPACE_OFFSET + 4 ) then Exit;

  var naProfile: TBytes;

  SetLength( naProfile, iSize );
  CheckDecoder( JxlDecoderGetColorAsICCProfile( ADecoder, JXL_COLOR_PROFILE_TARGET_ORIGINAL, PByte( naProfile ), iSize ),
    'JxlDecoderGetColorAsICCProfile' );

  var sSignature := TEncoding.ANSI.GetString( naProfile, ICC_COLOUR_SPACE_OFFSET, 4 );

  if ( sSignature = 'RGB ' ) then
    AInfo.ColourSpace := jcsRgb
  else if ( sSignature = 'GRAY' ) then
    AInfo.ColourSpace := jcsGrey;

end;

/// <summary>
///   Reads the headers and frame list of a JPEG XL file, and with <c>AFull</c> also decodes every frame to a discarding
///   callback; the caller runs it through <see cref="RunLibjxl" />.
/// </summary>
/// <param name="AData">The complete file.</param>
/// <param name="AFull">Decode the pixel data too (<see cref="JxlValidate" />), not only the headers.</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token that stops a full decode, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The information.</returns>
function DoReadInfo( const AData: TBytes; AFull: Boolean; const ALimits: TJxlLimits; ACancellation: TJxlCancellation;
  const ARoutine: string ): TJxlInfo;
var
  pDecoder: PJxlDecoder;
  pRunner: Pointer;
  rBudget: TJxlMemoryBudget;
  rRunner: TJxlCancellableRunner;
begin

  Result := Default( TJxlInfo );
  CheckContainerBoxes( AData, ARoutine );
  rBudget.Init( ALimits.MaxMemoryBytes );

  var rManager := rBudget.Manager;

  pDecoder := JxlDecoderCreate( @rManager );

  if ( not Assigned( pDecoder ) ) then
    raise EJxlError.CreateStatus( 'JxlDecoderCreate', Ord( JXL_DEC_ERROR ), 'the decoder could not be created' );

  pRunner := nil;

  try
    try
      // Without JXL_DEC_FULL_IMAGE the decoder skips the pixel data and reports only the frame headers.
      var iEvents := Ord( JXL_DEC_BASIC_INFO ) or Ord( JXL_DEC_COLOR_ENCODING ) or Ord( JXL_DEC_FRAME ) or Ord( JXL_DEC_BOX );

      if AFull then
      begin
        iEvents              := iEvents or Ord( JXL_DEC_FULL_IMAGE );
        pRunner              := CreateRunner;
        rRunner.Runner       := pRunner;
        rRunner.Cancellation := ACancellation;
        CheckDecoder( JxlDecoderSetParallelRunner( pDecoder, JxlCancellableParallelRunner, @rRunner ), 'JxlDecoderSetParallelRunner' );
      end;

      // Report the orientation and size as stored; by default libjxl reports them as displayed, with orientation 1.
      CheckDecoder( JxlDecoderSetKeepOrientation( pDecoder, JXL_TRUE ), 'JxlDecoderSetKeepOrientation' );
      CheckDecoder( JxlDecoderSubscribeEvents( pDecoder, iEvents ), 'JxlDecoderSubscribeEvents' );
      CheckDecoder( JxlDecoderSetInput( pDecoder, PByte( AData ), Length( AData ) ), 'JxlDecoderSetInput' );
      JxlDecoderCloseInput( pDecoder );

      var rFormat := Default( JxlPixelFormat );

      rFormat.num_channels := 4;
      rFormat.data_type    := JXL_TYPE_UINT8;
      rFormat.endianness   := JXL_NATIVE_ENDIAN;

      var bHaveInfo := False;
      var eStatus   := JxlDecoderProcessInput( pDecoder );

      while ( eStatus <> JXL_DEC_SUCCESS ) do
      begin
        case eStatus of
          JXL_DEC_BASIC_INFO:
            begin
              var rBasic := Default( JxlBasicInfo );

              CheckDecoder( JxlDecoderGetBasicInfo( pDecoder, @rBasic ), 'JxlDecoderGetBasicInfo' );
              CheckBasicInfo( rBasic, ALimits, ARoutine );
              bHaveInfo                    := True;
              Result.Width                 := rBasic.xsize;
              Result.Height                := rBasic.ysize;
              Result.BitsPerSample         := rBasic.bits_per_sample;
              Result.ExponentBitsPerSample := rBasic.exponent_bits_per_sample;
              Result.ColourChannels        := rBasic.num_color_channels;
              Result.ExtraChannels         := rBasic.num_extra_channels;
              Result.AlphaBits             := rBasic.alpha_bits;
              Result.AlphaPremultiplied    := ( rBasic.alpha_premultiplied <> JXL_FALSE );
              Result.XybEncoded            := ( rBasic.uses_original_profile = JXL_FALSE );
              Result.Orientation           := Ord( rBasic.orientation );
              Result.HasContainer          := ( rBasic.have_container <> JXL_FALSE );
              Result.HasPreview            := ( rBasic.have_preview <> JXL_FALSE );
              Result.IsAnimated            := ( rBasic.have_animation <> JXL_FALSE );

              if Result.IsAnimated then
              begin
                Result.TicksPerSecondNumerator   := rBasic.animation.tps_numerator;
                Result.TicksPerSecondDenominator := rBasic.animation.tps_denominator;
                Result.AnimationLoops            := rBasic.animation.num_loops;
              end;

              if Assigned( pRunner ) then
                JxlResizableParallelRunnerSetThreads( pRunner, JxlResizableParallelRunnerSuggestThreads( rBasic.xsize, rBasic.ysize ) );
            end;
          JXL_DEC_COLOR_ENCODING:
            ReadColourEncoding( pDecoder, Result );
          JXL_DEC_NEED_IMAGE_OUT_BUFFER:
            CheckDecoder( JxlDecoderSetImageOutCallback( pDecoder, @rFormat, DiscardPixels, nil ), 'JxlDecoderSetImageOutCallback' );
          JXL_DEC_FULL_IMAGE:
            Inc( Result.DecodedFrameCount );
          JXL_DEC_FRAME:
            begin
              var rHeader := Default( JxlFrameHeader );

              CheckDecoder( JxlDecoderGetFrameHeader( pDecoder, @rHeader ), 'JxlDecoderGetFrameHeader' );
              Inc( Result.FrameCount );
              Inc( Result.DurationTicks, rHeader.duration );
            end;
          JXL_DEC_BOX:
            begin
              var cBoxType: JxlBoxType;

              CheckDecoder( JxlDecoderGetBoxType( pDecoder, cBoxType, JXL_TRUE ), 'JxlDecoderGetBoxType' );

              if CompareMem( @cBoxType, @JPEG_RECONSTRUCTION_BOX, SizeOf( JxlBoxType ) ) then
                Result.HasJpegReconstruction := True;
            end;
          JXL_DEC_NEED_MORE_INPUT:
            raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ), 'the file is truncated' );
        else
          raise EJxlError.CreateStatus( 'JxlDecoderProcessInput', Ord( eStatus ) );
        end;

        CheckCancellation( ACancellation, ARoutine );
        eStatus := JxlDecoderProcessInput( pDecoder );
      end;

      if ( not bHaveInfo ) or ( Result.FrameCount = 0 ) then raise EJxlError.CreateCheck( ARoutine, 'the file holds no image' );

      if AFull and ( Result.DecodedFrameCount <> Result.FrameCount ) then
        raise EJxlError.CreateCheck( ARoutine, Format( '%d of %d frames were decoded', [ Result.DecodedFrameCount,
          Result.FrameCount ] ) );

    except
      on EJxlError do
      begin
        var eReplacement := ReplacementError( rBudget, ACancellation, ARoutine );

        if Assigned( eReplacement ) then raise eReplacement else raise;
      end;
    end;

  finally
    if Assigned( pRunner ) then JxlResizableParallelRunnerDestroy( pRunner );

    JxlDecoderDestroy( pDecoder );
  end;

end;

{ TJxlEncodeOptions }

class function TJxlEncodeOptions.Default: TJxlEncodeOptions;
begin

  Result.Lossless := False;
  Result.Distance := 1.0;
  Result.Effort   := 7;

end;

{ TJxlLimits }

class function TJxlLimits.Default: TJxlLimits;
begin

  Result.MaxPixels        := DEFAULT_MAX_PIXELS;
  Result.MaxExtraChannels := DEFAULT_MAX_EXTRA_CHANNELS;
  Result.MaxInputBytes    := DEFAULT_MAX_IO_BYTES;
  Result.MaxOutputBytes   := DEFAULT_MAX_IO_BYTES;
  Result.MaxMemoryBytes   := DEFAULT_MAX_MEMORY;
  Result.MaxJpegScans     := DEFAULT_MAX_JPEG_SCANS;

end;

{ TJxlInfo }

function TJxlInfo.DurationSeconds: Double;
begin

  Result := 0;

  if IsAnimated and ( TicksPerSecondNumerator > 0 ) then
    Result := DurationTicks * TicksPerSecondDenominator / TicksPerSecondNumerator;

end;

function TJxlInfo.DisplayWidth: Cardinal;
begin

  Result := if ( Orientation >= Ord( JXL_ORIENT_TRANSPOSE ) ) then Height else Width;

end;

function TJxlInfo.DisplayHeight: Cardinal;
begin

  Result := if ( Orientation >= Ord( JXL_ORIENT_TRANSPOSE ) ) then Width else Height;

end;

{ TJxlCancellation }

procedure TJxlCancellation.Cancel;
begin

  TInterlocked.Exchange( FCancelled, 1 );

end;

procedure TJxlCancellation.Reset;
begin

  TInterlocked.Exchange( FCancelled, 0 );

end;

function TJxlCancellation.IsCancelled: Boolean;
begin

  Result := ( TInterlocked.CompareExchange( FCancelled, 0, 0 ) <> 0 );

end;

{ Public routines }

function JxlGetDefaultLimits: TJxlLimits;
begin

  GLimitsLock.Enter;

  try
    Result := GDefaultLimits;
  finally
    GLimitsLock.Leave;
  end;

end;

procedure JxlSetDefaultLimits( const ALimits: TJxlLimits );
begin

  CheckLimits( ALimits, NameOf( JxlSetDefaultLimits ) );
  GLimitsLock.Enter;

  try
    GDefaultLimits := ALimits;
  finally
    GLimitsLock.Leave;
  end;

end;

function JxlHasSignature( const AData: TBytes ): Boolean;
begin

  Result := ( ( Length( AData ) >= Length( JXL_CODESTREAM_SIGNATURE ) )
    and CompareMem( PByte( AData ), @JXL_CODESTREAM_SIGNATURE, Length( JXL_CODESTREAM_SIGNATURE ) ) )
    or ( ( Length( AData ) >= Length( JXL_CONTAINER_SIGNATURE ) )
    and CompareMem( PByte( AData ), @JXL_CONTAINER_SIGNATURE, Length( JXL_CONTAINER_SIGNATURE ) ) );

end;

function JxlDecodePixels( const AData: TBytes; AColourOutput: TJxlColourOutput ): TJxlPixels;
begin

  Result := JxlDecodePixels( AData, AColourOutput, JxlGetDefaultLimits );

end;

function JxlDecodePixels( const AData: TBytes; AColourOutput: TJxlColourOutput; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation ): TJxlPixels;
var
  rPixels: TJxlPixels;
begin

  var sRoutine := NameOf( JxlDecodePixels );
  var rLimits  := ALimits;
  var naData   := AData;

  CheckLimits( rLimits, sRoutine );
  CheckInputBytes( naData, rLimits, sRoutine );
  CheckCancellation( ACancellation, sRoutine );
  RunLibjxl( sRoutine,
    procedure
    begin
      rPixels := DoDecodePixels( naData, AColourOutput, rLimits, nil, ACancellation, sRoutine );
    end );
  Result := rPixels;

end;

function JxlEncodePixels( const APixels: TJxlPixels; const AOptions: TJxlEncodeOptions ): TBytes;
begin

  Result := JxlEncodePixels( APixels, AOptions, JxlGetDefaultLimits );

end;

function JxlEncodePixels( const APixels: TJxlPixels; const AOptions: TJxlEncodeOptions; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation ): TBytes;
var
  naResult: TBytes;
begin

  var sRoutine := NameOf( JxlEncodePixels );
  var rPixels  := APixels;
  var rOptions := AOptions;
  var rLimits  := ALimits;

  ValidatePixels( rPixels );
  CheckEncodeOptions( rOptions, sRoutine );
  CheckLimits( rLimits, sRoutine );
  CheckCancellation( ACancellation, sRoutine );
  RunLibjxl( sRoutine,
    procedure
    begin
      naResult := DoEncodePixels( rPixels, rOptions, rLimits, ACancellation, sRoutine );
    end );
  Result := naResult;

end;

procedure JxlPixelsToBitmap( const APixels: TJxlPixels; ABitmap: TBitmap );
begin

  if ( not Assigned( ABitmap ) ) then raise EArgumentException.Create( 'JxlPixelsToBitmap needs a bitmap.' );

  ValidatePixels( APixels );

  var bAlpha     := ( APixels.NumChannels = 2 ) or ( APixels.NumChannels = 4 );
  var iChannels  := APixels.NumChannels;
  var pSource    := PByte( APixels.Data );
  var rTarget    := PrepareBitmap( ABitmap, APixels.Width, APixels.Height );

  // Premultiplied samples are written into a bitmap already marked as holding them; straight ones are marked
  // afterwards, when VCL premultiplies them in place.
  if bAlpha and APixels.AlphaPremultiplied then ABitmap.AlphaFormat := afDefined;

  for var iY := 0 to Integer( APixels.Height ) - 1 do
  begin
    var pTarget := rTarget.First + iY * rTarget.Stride;

    for var iX := 0 to Integer( APixels.Width ) - 1 do
    begin
      if ( iChannels >= 3 ) then
      begin
        pTarget[ 0 ] := pSource[ 2 ];
        pTarget[ 1 ] := pSource[ 1 ];
        pTarget[ 2 ] := pSource[ 0 ];
      end
      else
      begin
        pTarget[ 0 ] := pSource[ 0 ];
        pTarget[ 1 ] := pSource[ 0 ];
        pTarget[ 2 ] := pSource[ 0 ];
      end;

      pTarget[ 3 ] := if bAlpha then pSource[ iChannels - 1 ] else 255;
      Inc( pTarget, 4 );
      Inc( pSource, iChannels );
    end;

  end;

  if bAlpha and ( not APixels.AlphaPremultiplied ) then ABitmap.AlphaFormat := afDefined;

  ABitmap.Modified := True;

end;

function JxlBitmapToPixels( ABitmap: TBitmap ): TJxlPixels;
var
  oSource: TBitmap;
  oConverted: TBitmap;
begin

  Result := Default( TJxlPixels );

  if ( not Assigned( ABitmap ) ) or ABitmap.Empty then
    raise EArgumentException.Create( 'JxlBitmapToPixels needs a bitmap with a width and height.' );

  oSource    := ABitmap;
  oConverted := nil;

  try
    if ( ABitmap.PixelFormat <> pf32bit ) then
    begin
      oConverted := TBitmap.Create;
      oConverted.Assign( ABitmap );
      oConverted.PixelFormat := pf32bit;
      oConverted.AlphaFormat := afIgnored;
      oSource := oConverted;
    end;

    var bAlpha := ( oSource.AlphaFormat <> afIgnored );

    Result.Width              := oSource.Width;
    Result.Height             := oSource.Height;
    Result.NumChannels        := if bAlpha then 4 else 3;
    Result.AlphaPremultiplied := bAlpha;
    SetLength( Result.Data, PixelBufferSize( Result.Width, Result.Height, Result.NumChannels, NameOf( JxlBitmapToPixels ) ) );

    var pTarget := PByte( Result.Data );
    var pFirst  := PByte( oSource.ScanLine[ 0 ] );
    var iStride := NativeInt( 0 );

    if ( oSource.Height > 1 ) then iStride := PByte( oSource.ScanLine[ 1 ] ) - pFirst;

    for var iY := 0 to oSource.Height - 1 do
    begin
      var pSource := pFirst + iY * iStride;

      for var iX := 0 to oSource.Width - 1 do
      begin
        pTarget[ 0 ] := pSource[ 2 ];
        pTarget[ 1 ] := pSource[ 1 ];
        pTarget[ 2 ] := pSource[ 0 ];

        if bAlpha then pTarget[ 3 ] := pSource[ 3 ];

        Inc( pTarget, Result.NumChannels );
        Inc( pSource, 4 );
      end;

    end;

  finally
    oConverted.Free;
  end;

end;

procedure JxlDecodeToBitmap( const AData: TBytes; ABitmap: TBitmap );
begin

  JxlDecodeToBitmap( AData, ABitmap, JxlGetDefaultLimits );

end;

procedure JxlDecodeToBitmap( const AData: TBytes; ABitmap: TBitmap; const ALimits: TJxlLimits; ACancellation: TJxlCancellation );
begin

  if ( not Assigned( ABitmap ) ) then raise EArgumentException.Create( 'JxlDecodeToBitmap needs a bitmap.' );

  var sRoutine := NameOf( JxlDecodeToBitmap );
  var rLimits  := ALimits;
  var naData   := AData;

  CheckLimits( rLimits, sRoutine );
  CheckInputBytes( naData, rLimits, sRoutine );
  CheckCancellation( ACancellation, sRoutine );
  RunLibjxl( sRoutine,
    procedure
    begin
      DoDecodePixels( naData, jcoSrgb, rLimits, ABitmap, ACancellation, sRoutine );
    end );

end;

function JxlEncodeBitmap( ABitmap: TBitmap; const AOptions: TJxlEncodeOptions; ACancellation: TJxlCancellation ): TBytes;
begin

  Result := JxlEncodePixels( JxlBitmapToPixels( ABitmap ), AOptions, JxlGetDefaultLimits, ACancellation );

end;

procedure JxlDecodeFileToBitmap( const AFileName: string; ABitmap: TBitmap; ACancellation: TJxlCancellation );
begin

  if ( not Assigned( ABitmap ) ) then raise EArgumentException.Create( 'JxlDecodeFileToBitmap needs a bitmap.' );

  var rLimits := JxlGetDefaultLimits;

  JxlDecodeToBitmap( ReadFileBytes( AFileName, rLimits, NameOf( JxlDecodeFileToBitmap ) ), ABitmap, rLimits, ACancellation );

end;

procedure JxlEncodeBitmapToFile( ABitmap: TBitmap; const AFileName: string; const AOptions: TJxlEncodeOptions;
  ACancellation: TJxlCancellation );
begin

  TFile.WriteAllBytes( AFileName, JxlEncodeBitmap( ABitmap, AOptions, ACancellation ) );

end;

function JxlTranscodeJpegToJxl( const AJpegData: TBytes; AEffort: Integer ): TBytes;
begin

  Result := JxlTranscodeJpegToJxl( AJpegData, AEffort, JxlGetDefaultLimits );

end;

function JxlTranscodeJpegToJxl( const AJpegData: TBytes; AEffort: Integer; const ALimits: TJxlLimits;
  ACancellation: TJxlCancellation ): TBytes;
var
  naResult: TBytes;
begin

  var sRoutine := NameOf( JxlTranscodeJpegToJxl );
  var rLimits  := ALimits;
  var naJpeg   := AJpegData;

  CheckEffort( AEffort, sRoutine );
  CheckLimits( rLimits, sRoutine );
  CheckInputBytes( naJpeg, rLimits, sRoutine );
  CheckJpegStructure( naJpeg, rLimits, sRoutine );
  CheckCancellation( ACancellation, sRoutine );
  RunLibjxl( sRoutine,
    procedure
    begin
      naResult := DoTranscodeJpeg( naJpeg, AEffort, rLimits, ACancellation, sRoutine );
    end );
  Result := naResult;

end;

function JxlReconstructJpeg( const AJxlData: TBytes ): TBytes;
begin

  Result := JxlReconstructJpeg( AJxlData, JxlGetDefaultLimits );

end;

function JxlReconstructJpeg( const AJxlData: TBytes; const ALimits: TJxlLimits; ACancellation: TJxlCancellation ): TBytes;
var
  naResult: TBytes;
begin

  var sRoutine := NameOf( JxlReconstructJpeg );
  var rLimits  := ALimits;
  var naJxl    := AJxlData;

  CheckLimits( rLimits, sRoutine );
  CheckInputBytes( naJxl, rLimits, sRoutine );
  CheckCancellation( ACancellation, sRoutine );
  RunLibjxl( sRoutine,
    procedure
    begin
      naResult := DoReconstructJpeg( naJxl, rLimits, ACancellation, sRoutine );
    end );
  Result := naResult;

end;

procedure JxlTranscodeJpegFileToJxl( const AJpegFileName: string; const AJxlFileName: string; AEffort: Integer;
  ACancellation: TJxlCancellation );
begin

  var rLimits := JxlGetDefaultLimits;
  var naJpeg  := ReadFileBytes( AJpegFileName, rLimits, NameOf( JxlTranscodeJpegFileToJxl ) );

  TFile.WriteAllBytes( AJxlFileName, JxlTranscodeJpegToJxl( naJpeg, AEffort, rLimits, ACancellation ) );

end;

procedure JxlReconstructJpegFile( const AJxlFileName: string; const AJpegFileName: string; ACancellation: TJxlCancellation );
begin

  var rLimits := JxlGetDefaultLimits;
  var naJxl   := ReadFileBytes( AJxlFileName, rLimits, NameOf( JxlReconstructJpegFile ) );

  TFile.WriteAllBytes( AJpegFileName, JxlReconstructJpeg( naJxl, rLimits, ACancellation ) );

end;

/// <summary>Shared body of <see cref="JxlReadInfo" /> and <see cref="JxlValidate" /> for bytes.</summary>
/// <param name="AData">The complete file.</param>
/// <param name="AFull">Decode every frame (<see cref="JxlValidate" />).</param>
/// <param name="ALimits">The limits.</param>
/// <param name="ACancellation">Token that stops a full decode, or <c>nil</c>.</param>
/// <param name="ARoutine">Name of the public routine.</param>
/// <returns>The information.</returns>
function ReadInfoChecked( const AData: TBytes; AFull: Boolean; const ALimits: TJxlLimits; ACancellation: TJxlCancellation;
  const ARoutine: string ): TJxlInfo;
var
  rInfo: TJxlInfo;
begin

  var rLimits := ALimits;
  var naData  := AData;

  CheckLimits( rLimits, ARoutine );
  CheckInputBytes( naData, rLimits, ARoutine );
  CheckCancellation( ACancellation, ARoutine );
  RunLibjxl( ARoutine,
    procedure
    begin
      rInfo := DoReadInfo( naData, AFull, rLimits, ACancellation, ARoutine );
    end );
  Result := rInfo;

end;

function JxlReadInfo( const AData: TBytes ): TJxlInfo;
begin

  Result := ReadInfoChecked( AData, False, JxlGetDefaultLimits, nil, NameOf( JxlReadInfo ) );

end;

function JxlReadInfo( const AData: TBytes; const ALimits: TJxlLimits ): TJxlInfo;
begin

  Result := ReadInfoChecked( AData, False, ALimits, nil, NameOf( JxlReadInfo ) );

end;

function JxlReadInfo( AStream: TStream ): TJxlInfo;
begin

  var rLimits := JxlGetDefaultLimits;

  Result := ReadInfoChecked( ReadStreamBytes( AStream, rLimits, NameOf( JxlReadInfo ) ), False, rLimits, nil, NameOf( JxlReadInfo ) );

end;

function JxlReadInfo( const AFileName: string ): TJxlInfo;
begin

  var rLimits := JxlGetDefaultLimits;

  Result := ReadInfoChecked( ReadFileBytes( AFileName, rLimits, NameOf( JxlReadInfo ) ), False, rLimits, nil, NameOf( JxlReadInfo ) );

end;

function JxlValidate( const AData: TBytes ): TJxlInfo;
begin

  Result := ReadInfoChecked( AData, True, JxlGetDefaultLimits, nil, NameOf( JxlValidate ) );

end;

function JxlValidate( const AData: TBytes; const ALimits: TJxlLimits; ACancellation: TJxlCancellation ): TJxlInfo;
begin

  Result := ReadInfoChecked( AData, True, ALimits, ACancellation, NameOf( JxlValidate ) );

end;

function JxlValidate( AStream: TStream; ACancellation: TJxlCancellation ): TJxlInfo;
begin

  var rLimits := JxlGetDefaultLimits;

  Result := ReadInfoChecked( ReadStreamBytes( AStream, rLimits, NameOf( JxlValidate ) ), True, rLimits, ACancellation,
    NameOf( JxlValidate ) );

end;

function JxlValidate( const AFileName: string; ACancellation: TJxlCancellation ): TJxlInfo;
begin

  var rLimits := JxlGetDefaultLimits;

  Result := ReadInfoChecked( ReadFileBytes( AFileName, rLimits, NameOf( JxlValidate ) ), True, rLimits, ACancellation,
    NameOf( JxlValidate ) );

end;

function JxlTryPngToPixels( APng: TPngImage; out APixels: TJxlPixels ): Boolean;
begin

  APixels := Default( TJxlPixels );

  if ( not Assigned( APng ) ) or APng.Empty then
    raise EArgumentException.Create( 'JxlTryPngToPixels needs a PNG with a width and height.' );

  var iColourType := APng.Header.ColorType;

  if ( APng.Header.BitDepth <> 8 ) or ( iColourType not in [ COLOR_GRAYSCALE, COLOR_RGB, COLOR_GRAYSCALEALPHA, COLOR_RGBALPHA ] )
    or ( APng.TransparencyMode = ptmBit ) then Exit( False );

  var bAlpha     := ( iColourType = COLOR_GRAYSCALEALPHA ) or ( iColourType = COLOR_RGBALPHA );
  var bGrey      := ( iColourType = COLOR_GRAYSCALE ) or ( iColourType = COLOR_GRAYSCALEALPHA );
  var iColours   := if bGrey then 1 else 3;
  var iChannels  := iColours + ( if bAlpha then 1 else 0 );

  APixels.Width              := APng.Width;
  APixels.Height             := APng.Height;
  APixels.NumChannels        := iChannels;
  APixels.AlphaPremultiplied := False;
  SetLength( APixels.Data, PixelBufferSize( APixels.Width, APixels.Height, APixels.NumChannels, NameOf( JxlTryPngToPixels ) ) );

  var pTarget := PByte( APixels.Data );

  for var iY := 0 to APng.Height - 1 do
  begin
    // TPngImage holds a colour row as BGR (or grey) and the alpha row separately, both unpremultiplied.
    var pSource := PByte( APng.Scanline[ iY ] );
    var pAlpha  := PByte( nil );

    if bAlpha then pAlpha := PByte( APng.AlphaScanline[ iY ] );

    for var iX := 0 to APng.Width - 1 do
    begin
      if bGrey then
        pTarget[ 0 ] := pSource[ iX ]
      else
      begin
        pTarget[ 0 ] := pSource[ iX * 3 + 2 ];
        pTarget[ 1 ] := pSource[ iX * 3 + 1 ];
        pTarget[ 2 ] := pSource[ iX * 3 ];
      end;

      if bAlpha then pTarget[ iColours ] := pAlpha[ iX ];

      Inc( pTarget, iChannels );
    end;

  end;

  Result := True;

end;

procedure JxlEncodePixelsToFile( const APixels: TJxlPixels; const AFileName: string; const AOptions: TJxlEncodeOptions;
  ACancellation: TJxlCancellation );
begin

  TFile.WriteAllBytes( AFileName, JxlEncodePixels( APixels, AOptions, JxlGetDefaultLimits, ACancellation ) );

end;

{ TJxlImage }

constructor TJxlImage.Create;
begin

  inherited Create;

  var rDefault := TJxlEncodeOptions.Default;

  FLossless := rDefault.Lossless;
  FDistance := rDefault.Distance;
  FEffort   := rDefault.Effort;
  FLimits   := JxlGetDefaultLimits;

end;

function TJxlImage.GetEncodeOptions: TJxlEncodeOptions;
begin

  Result.Lossless := FLossless;
  Result.Distance := FDistance;
  Result.Effort   := FEffort;

end;

procedure TJxlImage.SetLimits( const AValue: TJxlLimits );
begin

  CheckLimits( AValue, Format( '%s.Limits', [ ClassName ] ) );
  FLimits := AValue;

end;

class function TJxlImage.CanLoadFromStream( Stream: TStream ): Boolean;
var
  iPosition: Int64;
begin

  iPosition := Stream.Position;

  try
    var naHeader: TBytes;

    SetLength( naHeader, Length( JXL_CONTAINER_SIGNATURE ) );
    SetLength( naHeader, Stream.Read( naHeader, Length( naHeader ) ) );
    Result := JxlHasSignature( naHeader );
  finally
    Stream.Position := iPosition;
  end;

end;

procedure TJxlImage.Assign( Source: TPersistent );
begin

  inherited Assign( Source );

  if ( Source is TJxlImage ) then
  begin
    var oSource := TJxlImage( Source );

    FLossless := oSource.FLossless;
    FDistance := oSource.FDistance;
    FEffort   := oSource.FEffort;
    FLimits   := oSource.FLimits;
  end;

end;

procedure TJxlImage.LoadFromStream( Stream: TStream );
begin

  JxlDecodeToBitmap( ReadStreamBytes( Stream, FLimits, NameOf( TJxlImage.LoadFromStream ) ), Self, FLimits, FCancellation );

end;

procedure TJxlImage.SaveToStream( Stream: TStream );
begin

  var naData := JxlEncodePixels( JxlBitmapToPixels( Self ), EncodeOptions, FLimits, FCancellation );

  Stream.WriteBuffer( naData, Length( naData ) );

end;

initialization
  GLimitsLock    := TCriticalSection.Create;
  GDefaultLimits := TJxlLimits.Default;
  TPicture.RegisterFileFormat( 'jxl', SJxlImageDescription, TJxlImage );

finalization
  TPicture.UnregisterGraphicClass( TJxlImage );
  GLimitsLock.Free;

end.
