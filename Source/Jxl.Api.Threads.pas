(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Delphi import of the libjxl thread-pool runners, <c>jxl/thread_parallel_runner.h</c> and
///   <c>jxl/resizable_parallel_runner.h</c>, exported by <c>JXL_THREADS_LIBRARY</c> (<c>jxl_threads.dll</c>) in
///   upstream's shared build, or by <c>jxl.dll</c> itself when it is a single self-contained build
///   (<c>JxlCheckLibrary</c> detects which).
/// </summary>
/// <remarks>
///   Pass <see cref="JxlThreadParallelRunner" /> or <see cref="JxlResizableParallelRunner" /> as the
///   <c>parallel_runner</c> argument of <c>JxlDecoderSetParallelRunner</c> / <c>JxlEncoderSetParallelRunner</c>, with
///   the handle from the matching <c>Create</c> function as the opaque argument. Only one call per runner instance may
///   run at a time. Every routine is <c>cdecl</c> and delay-loaded: call <c>JxlCheckLibrary</c> before the first call.
/// </remarks>
unit Jxl.Api.Threads;

{$ALIGN 8}
{$MINENUMSIZE 4}

interface

uses
  Jxl.Api.Types;

// `delayed` is marked platform-specific (W1002). The binding is Windows-only by design, and delay loading is
// what lets JxlCheckLibrary report a missing DLL instead of the process failing to start, so the warning is
// silenced for the import declarations only.
{$WARN SYMBOL_PLATFORM OFF}

{ thread_parallel_runner.h }

/// <summary>Parallel runner with a fixed number of worker threads; use as a <c>JxlParallelRunner</c>.</summary>
/// <param name="runner_opaque">Handle from <see cref="JxlThreadParallelRunnerCreate" />.</param>
/// <param name="jpegxl_opaque">Library handle passed to the callbacks.</param>
/// <param name="init">Initialisation callback.</param>
/// <param name="func">Data-processing callback.</param>
/// <param name="start_range">First value (inclusive).</param>
/// <param name="end_range">Last value (exclusive).</param>
/// <returns>0 on success, otherwise an error code.</returns>
function JxlThreadParallelRunner( runner_opaque: Pointer; jpegxl_opaque: Pointer; init: JxlParallelRunInit;
  func: JxlParallelRunFunction; start_range: UInt32; end_range: UInt32 ): JxlParallelRetCode; cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>Creates the runner state for <see cref="JxlThreadParallelRunner" />.</summary>
/// <param name="memory_manager">Custom allocator, or <c>nil</c> for the default.</param>
/// <param name="num_worker_threads">Number of worker threads; see <see cref="JxlThreadParallelRunnerDefaultNumWorkerThreads" />.</param>
/// <returns>The runner handle; free it with <see cref="JxlThreadParallelRunnerDestroy" />.</returns>
function JxlThreadParallelRunnerCreate( memory_manager: PJxlMemoryManager; num_worker_threads: NativeUInt ): Pointer; cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>Destroys a runner created by <see cref="JxlThreadParallelRunnerCreate" />.</summary>
/// <param name="runner_opaque">The runner handle.</param>
procedure JxlThreadParallelRunnerDestroy( runner_opaque: Pointer ); cdecl; external JXL_THREADS_LIBRARY delayed;

/// <summary>Returns a default number of worker threads for <see cref="JxlThreadParallelRunnerCreate" />.</summary>
/// <returns>The default worker thread count.</returns>
function JxlThreadParallelRunnerDefaultNumWorkerThreads: NativeUInt; cdecl; external JXL_THREADS_LIBRARY delayed;

{ resizable_parallel_runner.h }

/// <summary>Parallel runner whose thread count can change after creation; use as a <c>JxlParallelRunner</c>.</summary>
/// <param name="runner_opaque">Handle from <see cref="JxlResizableParallelRunnerCreate" />.</param>
/// <param name="jpegxl_opaque">Library handle passed to the callbacks.</param>
/// <param name="init">Initialisation callback.</param>
/// <param name="func">Data-processing callback.</param>
/// <param name="start_range">First value (inclusive).</param>
/// <param name="end_range">Last value (exclusive).</param>
/// <returns>0 on success, otherwise an error code.</returns>
function JxlResizableParallelRunner( runner_opaque: Pointer; jpegxl_opaque: Pointer; init: JxlParallelRunInit;
  func: JxlParallelRunFunction; start_range: UInt32; end_range: UInt32 ): JxlParallelRetCode; cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>
///   Creates the runner state for <see cref="JxlResizableParallelRunner" />; it runs on the calling thread until
///   <see cref="JxlResizableParallelRunnerSetThreads" /> is called.
/// </summary>
/// <param name="memory_manager">Custom allocator, or <c>nil</c> for the default.</param>
/// <returns>The runner handle; free it with <see cref="JxlResizableParallelRunnerDestroy" />.</returns>
function JxlResizableParallelRunnerCreate( memory_manager: PJxlMemoryManager ): Pointer; cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>Changes the number of threads of a resizable runner.</summary>
/// <param name="runner_opaque">The runner handle.</param>
/// <param name="num_threads">The new number of threads.</param>
procedure JxlResizableParallelRunnerSetThreads( runner_opaque: Pointer; num_threads: NativeUInt ); cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>Suggests a number of threads for an image of a given size.</summary>
/// <param name="xsize">Image width in pixels.</param>
/// <param name="ysize">Image height in pixels.</param>
/// <returns>The suggested thread count.</returns>
function JxlResizableParallelRunnerSuggestThreads( xsize: UInt64; ysize: UInt64 ): UInt32; cdecl;
  external JXL_THREADS_LIBRARY delayed;

/// <summary>Destroys a runner created by <see cref="JxlResizableParallelRunnerCreate" />.</summary>
/// <param name="runner_opaque">The runner handle.</param>
procedure JxlResizableParallelRunnerDestroy( runner_opaque: Pointer ); cdecl; external JXL_THREADS_LIBRARY delayed;

{$WARN SYMBOL_PLATFORM DEFAULT}

const
  /// <summary>
  ///   Every function this unit imports from <see cref="JXL_THREADS_LIBRARY" />; <c>JxlCheckLibrary</c> verifies that the
  ///   DLL exports each one before any of them is called. Keep it in step with the declarations above.
  /// </summary>
  JXL_THREADS_EXPORTS: array[ 0..8 ] of string = (
    NameOf( JxlThreadParallelRunner ),
    NameOf( JxlThreadParallelRunnerCreate ),
    NameOf( JxlThreadParallelRunnerDestroy ),
    NameOf( JxlThreadParallelRunnerDefaultNumWorkerThreads ),
    NameOf( JxlResizableParallelRunner ),
    NameOf( JxlResizableParallelRunnerCreate ),
    NameOf( JxlResizableParallelRunnerSetThreads ),
    NameOf( JxlResizableParallelRunnerSuggestThreads ),
    NameOf( JxlResizableParallelRunnerDestroy )
  );

implementation

end.
