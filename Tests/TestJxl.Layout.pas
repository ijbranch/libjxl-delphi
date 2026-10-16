(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests of the two DLL layouts the binding accepts: a single self-contained <c>jxl.dll</c>, and upstream's shared
///   build (<c>jxl.dll</c>, <c>jxl_threads.dll</c>, <c>jxl_cms.dll</c> and their dependencies). Each layout is
///   verified with <c>JxlCheckLibraryFolder</c> in a temporary folder, so both are tested in one run whichever layout
///   sits next to the executable.
/// </summary>
/// <remarks>
///   A layout is looked for, in this order, in the folders named by <c>LIBJXL_BIN_WIN64</c> / <c>LIBJXL_BIN_WIN32</c>
///   and <c>LIBJXL_BIN</c> (each also with a <c>Win64</c> / <c>Win32</c> subfolder, and the <c>x64-windows\bin</c> /
///   <c>x86-windows\bin</c> folder of an official release archive or a vcpkg tree), the executable's folder, and the
///   <c>build*</c> folders of every folder above the executable (a per-platform subfolder, the folder itself, or a
///   CMake build tree's <c>lib\Release</c> with <c>third_party\brotli\Release</c>). Only DLLs built for the test's own
///   architecture count. A layout that is not found is reported as ignored.
/// </remarks>
unit TestJxl.Layout;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Tests of the single-DLL and split-DLL layouts and of the run-time layout detection.</summary>
  [ TestFixture ]
  TTestJxlLayout = class
  public
    /// <summary>
    ///   Proves the detection matches what is deployed next to the executable: the split layout exactly when
    ///   <c>jxl_threads.dll</c> was copied there with <c>jxl.dll</c>, the single layout otherwise; and that a thread
    ///   runner and the default CMS, bound by <c>JxlCheckLibrary</c> to the module it verified, can be called (on Win64
    ///   an import left unresolved would end the process instead).
    /// </summary>
    [ Test ]
    procedure Test_LibraryLayout_MatchesDeployedDlls;
    /// <summary>
    ///   Proves a self-contained <c>jxl.dll</c> alone in a folder is accepted as <c>jllSingleDll</c>: the thread
    ///   runners and the CMS are taken from it although no <c>jxl_threads.dll</c> or <c>jxl_cms.dll</c> exists.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_SingleDll;
    /// <summary>
    ///   Proves upstream's shared build is accepted as <c>jllSplitDlls</c>, its <c>jxl.dll</c> (which exports neither
    ///   the thread runners nor the CMS) verified with its two companion DLLs and at version 0.12.0 or later.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_SplitDlls;
    /// <summary>
    ///   Proves a split build missing <c>jxl_threads.dll</c> is refused with <c>EJxlError</c> from <c>LoadLibraryEx</c>
    ///   (status 126) explaining that <c>jxl.dll</c> does not export the thread runner functions itself and naming the
    ///   missing DLL, rather than accepted and left to fail at the first thread-runner call.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_SplitWithoutThreadsDll_Raises;
    /// <summary>
    ///   Proves a folder without <c>jxl.dll</c> is refused with <c>EJxlError</c> (<c>LoadLibraryEx</c>, status 126,
    ///   naming the path), and an empty folder name with <c>EArgumentException</c>.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_NoLibrary_Raises;
    /// <summary>
    ///   Proves a companion DLL is verified, not merely found: a split build whose <c>jxl_threads.dll</c> is really
    ///   <c>jxl_cms.dll</c> is refused with <c>EJxlError</c> from <c>GetProcAddress</c> naming the 9 missing
    ///   thread-runner functions.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_WrongThreadsDll_Raises;
    /// <summary>
    ///   Proves DLLs named with a <c>lib</c> prefix, as MinGW / MSYS2 builds name them, are found when no file of the
    ///   plain name exists: a single <c>libjxl.dll</c> is <c>jllSingleDll</c>, and a split build with
    ///   <c>libjxl.dll</c> and <c>libjxl_threads.dll</c> is <c>jllSplitDlls</c> (its <c>jxl_cms.dll</c> keeps its
    ///   name, since the split <c>jxl.dll</c> imports it by that name). Each part is ignored when its layout is absent.
    /// </summary>
    [ Test ]
    procedure Test_CheckLibraryFolder_LibPrefixedNames;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes,
  Jxl.Api.Types, Jxl.Api.Threads, Jxl.Api.Cms,
  TestJxl.Common;

const
  /// <summary>PE machine type of the DLLs this test executable can load.</summary>
  OWN_MACHINE = {$IFDEF WIN64} $8664 {$ELSE} $014C {$ENDIF};
  /// <summary>Delphi platform name of this test executable.</summary>
  OWN_PLATFORM = {$IFDEF WIN64} 'Win64' {$ELSE} 'Win32' {$ENDIF};
  /// <summary>Folder of the DLLs in libjxl's release archives and vcpkg trees for this architecture.</summary>
  OWN_RELEASE_BIN = {$IFDEF WIN64} 'x64-windows\bin' {$ELSE} 'x86-windows\bin' {$ENDIF};
  /// <summary>Message for a layout that was not found.</summary>
  LAYOUT_HINT = 'set LIBJXL_BIN to a folder holding it (or LIBJXL_BIN_%s)';

/// <summary>Returns the PE machine type of a DLL, or 0 when the file is not a readable PE image.</summary>
/// <param name="AFileName">The DLL.</param>
/// <returns>The machine type, e.g. <c>$8664</c> for x64.</returns>
function DllMachine( const AFileName: string ): Word;
begin

  Result := 0;

  try
    var oStream := TFileStream.Create( AFileName, fmOpenRead or fmShareDenyNone );

    try
      var iOffset: Cardinal := 0;

      oStream.Position := $3C;
      oStream.ReadBuffer( iOffset, SizeOf( iOffset ) );
      oStream.Position := Int64( iOffset ) + 4;
      oStream.ReadBuffer( Result, SizeOf( Result ) );
    finally
      oStream.Free;
    end;

  except
    on EStreamError do Result := 0;
    on EFOpenError do Result := 0;
  end;

end;

/// <summary>Returns the folders a layout is looked for in, in order (see the unit's remarks); some may not exist.</summary>
/// <returns>The folders.</returns>
function CandidateFolders: TArray<string>;
begin

  Result := nil;

  for var sVariable in [ 'LIBJXL_BIN_' + UpperCase( OWN_PLATFORM ), 'LIBJXL_BIN' ] do
  begin
    var sValue := GetEnvironmentVariable( sVariable );

    if ( sValue <> '' ) then
      Result := Result + [ sValue, TPath.Combine( sValue, OWN_PLATFORM ), TPath.Combine( sValue, OWN_RELEASE_BIN ) ];
  end;

  Result := Result + [ ExtractFileDir( ParamStr( 0 ) ) ];

  var sFolder := ExtractFileDir( ExtractFileDir( ParamStr( 0 ) ) );

  while ( sFolder <> '' ) do
  begin
    if TDirectory.Exists( sFolder ) then
      for var sBuild in TDirectory.GetDirectories( sFolder, 'build*' ) do
        Result := Result + [ TPath.Combine( sBuild, OWN_PLATFORM ), sBuild, TPath.Combine( sBuild, 'lib\Release' ) ];

    var sParent := ExtractFileDir( sFolder );

    if SameText( sParent, sFolder ) then Break;

    sFolder := sParent;
  end;

end;

/// <summary>
///   Finds the DLLs of one layout for this architecture: for the single layout a <c>jxl.dll</c> with no
///   <c>jxl_threads.dll</c> beside it; for the split layout every DLL of the folder holding <c>jxl.dll</c> and
///   <c>jxl_threads.dll</c>, plus a CMake build tree's Brotli DLLs.
/// </summary>
/// <param name="ASplit">Whether the split layout is wanted.</param>
/// <param name="AFiles">Receives the DLL files to copy.</param>
/// <returns><c>True</c> when the layout was found.</returns>
function FindLayout( ASplit: Boolean; out AFiles: TArray<string> ): Boolean;
begin

  AFiles := nil;

  for var sFolder in CandidateFolders do
  begin
    var sMain := TPath.Combine( sFolder, JXL_LIBRARY );

    if ( not TFile.Exists( sMain ) ) or ( DllMachine( sMain ) <> OWN_MACHINE ) then Continue;

    if ( TFile.Exists( TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) ) <> ASplit ) then Continue;

    if ( not ASplit ) then
    begin
      AFiles := [ sMain ];
      Exit( True );
    end;

    AFiles := TDirectory.GetFiles( sFolder, '*.dll' );

    var sBrotli := TPath.Combine( ExtractFileDir( ExtractFileDir( sFolder ) ), 'third_party\brotli\Release' );

    if SameText( ExtractFileName( sFolder ), 'Release' ) and TDirectory.Exists( sBrotli ) then
      AFiles := AFiles + TDirectory.GetFiles( sBrotli, '*.dll' );

    Exit( True );
  end;

  Result := False;

end;

/// <summary>Copies files into a new temporary folder.</summary>
/// <param name="AFiles">The files.</param>
/// <param name="AExclude">File name not to copy; may be empty.</param>
/// <param name="ALibPrefixed">File names to copy with a <c>lib</c> prefix, as MinGW / MSYS2 builds name them.</param>
/// <returns>The folder; the caller deletes it with <see cref="DeleteFolder" />.</returns>
function CopyToTempFolder( const AFiles: TArray<string>; const AExclude: string = '';
  const ALibPrefixed: TArray<string> = nil ): string;
begin

  Result := TPath.Combine( TPath.GetTempPath, 'LibJxlTests-layout-' + TGUID.NewGuid.ToString );
  TDirectory.CreateDirectory( Result );

  for var sFile in AFiles do
  begin
    var sName := ExtractFileName( sFile );

    if SameText( sName, AExclude ) then Continue;

    for var sPrefixed in ALibPrefixed do
      if SameText( sName, sPrefixed ) then sName := 'lib' + sName;

    TFile.Copy( sFile, TPath.Combine( Result, sName ) );
  end;

end;

/// <summary>Deletes a temporary folder; a DLL still loaded in the process may keep it, which is harmless.</summary>
/// <param name="AFolder">The folder.</param>
procedure DeleteFolder( const AFolder: string );
begin

  try
    TDirectory.Delete( AFolder, True );
  except
    on EInOutError do ;
    on EOSError do ;
  end;

end;

/// <summary>Finds a layout or reports the test as ignored.</summary>
/// <param name="ASplit">Whether the split layout is wanted.</param>
/// <returns>The DLL files of the layout.</returns>
function RequireLayout( ASplit: Boolean ): TArray<string>;
begin

  if ( not FindLayout( ASplit, Result ) ) then
    Assert.Ignore( Format( '%s libjxl build for %s not found: ' + LAYOUT_HINT, [ if ASplit then 'A split (shared)' else
      'A single-DLL', OWN_PLATFORM, UpperCase( OWN_PLATFORM ) ] ) );

end;

procedure TTestJxlLayout.Test_LibraryLayout_MatchesDeployedDlls;
begin

  var sExeFolder := ExtractFileDir( ParamStr( 0 ) );
  var eExpected  := if TFile.Exists( TPath.Combine( sExeFolder, JXL_THREADS_LIBRARY ) ) then jllSplitDlls else jllSingleDll;

  JxlCheckLibrary;
  Assert.AreEqual( Ord( eExpected ), Ord( JxlLibraryLayout ), 'layout detected for the DLLs next to the executable' );
  Assert.IsTrue( JxlThreadParallelRunnerDefaultNumWorkerThreads >= 1, 'a thread-runner import resolves and runs' );
  Assert.IsTrue( JxlGetDefaultCms( ) <> nil, 'the CMS import resolves and runs' );

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_SingleDll;
begin

  var sFolder := CopyToTempFolder( RequireLayout( False ) );

  try
    Assert.IsFalse( TFile.Exists( TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) ), 'no thread-runner DLL in the folder' );
    Assert.AreEqual( Ord( jllSingleDll ), Ord( JxlCheckLibraryFolder( sFolder ) ), 'layout' );
  finally
    DeleteFolder( sFolder );
  end;

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_SplitDlls;
begin

  var sFolder := CopyToTempFolder( RequireLayout( True ) );

  try
    Assert.AreEqual( Ord( jllSplitDlls ), Ord( JxlCheckLibraryFolder( sFolder ) ), 'layout' );
  finally
    DeleteFolder( sFolder );
  end;

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_SplitWithoutThreadsDll_Raises;
begin

  var sFolder := CopyToTempFolder( RequireLayout( True ), JXL_THREADS_LIBRARY );

  try
    AssertJxlError( procedure begin JxlCheckLibraryFolder( sFolder ); end, 'LoadLibraryEx', False,
      'does not export the thread runner functions itself', 'split build without jxl_threads.dll' );
    AssertJxlError( procedure begin JxlCheckLibraryFolder( sFolder ); end, 'LoadLibraryEx', False,
      TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) + ' (or libjxl_threads.dll) was not found', 'the missing DLL is named' );
  finally
    DeleteFolder( sFolder );
  end;

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_NoLibrary_Raises;
var
  iStatus: Integer;
begin

  var sFolder := CopyToTempFolder( nil );

  try
    AssertJxlError( procedure begin JxlCheckLibraryFolder( sFolder ); end, 'LoadLibraryEx', False,
      TPath.Combine( sFolder, JXL_LIBRARY ) + ' (or libjxl.dll) was not found', 'empty folder' );

    iStatus := 0;

    try
      JxlCheckLibraryFolder( sFolder );
    except
      on E: EJxlError do iStatus := E.Status;
    end;

    Assert.AreEqual( 126, iStatus, 'Status (ERROR_MOD_NOT_FOUND)' );
  finally
    DeleteFolder( sFolder );
  end;

  var procEmptyName: TProc := procedure begin JxlCheckLibraryFolder( '' ); end;

  Assert.WillRaise( procEmptyName, EArgumentException, 'empty folder name' );

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_WrongThreadsDll_Raises;
begin

  var sFolder := CopyToTempFolder( RequireLayout( True ), JXL_THREADS_LIBRARY );

  try
    TFile.Copy( TPath.Combine( sFolder, JXL_CMS_LIBRARY ), TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) );
    AssertJxlError( procedure begin JxlCheckLibraryFolder( sFolder ); end, 'GetProcAddress', False,
      TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) + ' does not export 9 of the functions the binding imports',
      'a jxl_threads.dll without the thread-runner exports' );
  finally
    DeleteFolder( sFolder );
  end;

end;

procedure TTestJxlLayout.Test_CheckLibraryFolder_LibPrefixedNames;
var
  asFiles: TArray<string>;
begin

  var bChecked := False;

  if FindLayout( False, asFiles ) then
  begin
    var sFolder := CopyToTempFolder( asFiles, '', [ JXL_LIBRARY ] );

    try
      Assert.IsTrue( TFile.Exists( TPath.Combine( sFolder, 'libjxl.dll' ) ), 'renamed single DLL' );
      Assert.AreEqual( Ord( jllSingleDll ), Ord( JxlCheckLibraryFolder( sFolder ) ), 'single libjxl.dll' );
      bChecked := True;
    finally
      DeleteFolder( sFolder );
    end;

  end;

  if FindLayout( True, asFiles ) then
  begin
    var sFolder := CopyToTempFolder( asFiles, '', [ JXL_LIBRARY, JXL_THREADS_LIBRARY ] );

    try
      Assert.IsFalse( TFile.Exists( TPath.Combine( sFolder, JXL_THREADS_LIBRARY ) ), 'no plain-named thread-runner DLL' );
      Assert.AreEqual( Ord( jllSplitDlls ), Ord( JxlCheckLibraryFolder( sFolder ) ), 'split libjxl.dll + libjxl_threads.dll' );
      bChecked := True;
    finally
      DeleteFolder( sFolder );
    end;

  end;

  if ( not bChecked ) then
    Assert.Ignore( Format( 'No libjxl build for %s found: ' + LAYOUT_HINT, [ OWN_PLATFORM, UpperCase( OWN_PLATFORM ) ] ) );

end;

initialization
  TDUnitX.RegisterTestFixture( TTestJxlLayout );

end.
