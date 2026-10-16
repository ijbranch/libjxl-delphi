(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Delphi import of the libjxl default colour management system, <c>jxl/cms.h</c>, exported by
///   <c>JXL_CMS_LIBRARY</c> (<c>jxl_cms.dll</c>) in upstream's shared build, or by <c>jxl.dll</c> itself when it is a
///   single self-contained build (<c>JxlCheckLibrary</c> detects which).
/// </summary>
/// <remarks>
///   Pass <c>JxlGetDefaultCms^</c> to <c>JxlDecoderSetCms</c> or <c>JxlEncoderSetCms</c> when a colour conversion
///   needs a CMS, e.g. decoding to an ICC output profile. The routine is <c>cdecl</c> and delay-loaded: call
///   <c>JxlCheckLibrary</c> before the first call.
/// </remarks>
unit Jxl.Api.Cms;

{$ALIGN 8}
{$MINENUMSIZE 4}

interface

uses
  Jxl.Api.Types;

// `delayed` is marked platform-specific (W1002). The binding is Windows-only by design, and delay loading is
// what lets JxlCheckLibrary report a missing DLL instead of the process failing to start, so the warning is
// silenced for the import declarations only.
{$WARN SYMBOL_PLATFORM OFF}

/// <summary>Returns the library's built-in colour management system.</summary>
/// <returns>The CMS interface; owned by the library, never freed.</returns>
function JxlGetDefaultCms: PJxlCmsInterface; cdecl; external JXL_CMS_LIBRARY delayed;

{$WARN SYMBOL_PLATFORM DEFAULT}

const
  /// <summary>
  ///   Every function this unit imports from <see cref="JXL_CMS_LIBRARY" />; <c>JxlCheckLibrary</c> verifies that the
  ///   DLL exports each one before any of them is called. Keep it in step with the declarations above.
  /// </summary>
  JXL_CMS_EXPORTS: array[ 0..0 ] of string = ( NameOf( JxlGetDefaultCms ) );

implementation

end.
