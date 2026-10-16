(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Shared helpers for the libjxl Delphi binding tests: locating <c>testdata/jxl</c>, loading PNG reference images as
///   <c>TJxlPixels</c> and comparing pixel buffers.
/// </summary>
unit TestJxl.Common;

interface

uses
  System.SysUtils,
  Jxl.Graphic;

/// <summary>
///   Returns the binding's <c>delphi\Source</c> folder, found by walking up from the test executable, so that a test can
///   read the import units' declarations.
/// </summary>
/// <returns>The folder's full path.</returns>
/// <exception cref="EFileNotFoundException">The folder cannot be found.</exception>
function BindingSourceFolder: string;

/// <summary>
///   Asserts that a routine raises <c>EJxlError</c> of the expected form: <c>ApiName</c>, whether it is a binding check,
///   and a text its message must contain (case-sensitively). Any other outcome fails the test.
/// </summary>
/// <param name="AProc">The routine.</param>
/// <param name="AApiName">Expected <c>ApiName</c>.</param>
/// <param name="ABindingCheck">Expected <c>IsBindingCheck</c>.</param>
/// <param name="AText">Text the message must contain.</param>
/// <param name="AWhat">What is being checked, for the failure message.</param>
procedure AssertJxlError( const AProc: TProc; const AApiName: string; ABindingCheck: Boolean; const AText: string;
  const AWhat: string );

const
  /// <summary>How to provide libjxl's test data, for the message of a test that needs it and finds none.</summary>
  TESTDATA_HINT = 'set LIBJXL_TESTDATA to the testdata folder of a libjxl checkout (git submodule update --init testdata)';
  /// <summary>How to provide the conformance suite, for the message of a test that needs it and finds none.</summary>
  CONFORMANCE_HINT = 'set JXL_CONFORMANCE to the testcases folder of a clone of https://github.com/libjxl/conformance';

/// <summary>
///   Returns the full path of a file under libjxl's <c>testdata/jxl</c> folder. The folder is taken from the
///   <c>LIBJXL_TESTDATA</c> environment variable when it is set (a libjxl checkout's <c>testdata</c> folder, or its
///   <c>jxl</c> subfolder), otherwise found by walking up from the test executable to a <c>testdata\jxl</c> folder.
///   When neither gives the folder, the calling test is reported as ignored, naming the variable.
/// </summary>
/// <param name="ARelativePath">Path below <c>testdata/jxl</c>, e.g. <c>flower\flower.png</c>.</param>
/// <returns>The full path.</returns>
/// <exception cref="EFileNotFoundException">The folder exists but the file does not.</exception>
function TestDataFile( const ARelativePath: string ): string;

/// <summary>
///   Loads a grey, RGB or RGBA PNG as straight-alpha 8-bit pixels in RGB(A) order; grey is expanded to RGB and 16-bit
///   samples keep their high byte (as <c>TPngImage</c> stores them).
/// </summary>
/// <param name="AFileName">Path of the PNG file.</param>
/// <returns>The pixels: 3 channels, or 4 when the PNG has an alpha channel.</returns>
/// <exception cref="EArgumentException">The PNG is not 8 or 16-bit grey, RGB or RGBA.</exception>
function LoadPngPixels( const AFileName: string ): TJxlPixels;

/// <summary>
///   Returns the folder of one case of libjxl's conformance suite (<c>libjxl/conformance</c>), or an empty string when
///   the suite is not present. The suite's <c>testcases</c> folder is named by the <c>JXL_CONFORMANCE</c> environment
///   variable (the folder holding <c>testcases</c> is accepted too), otherwise found by walking up from the test
///   executable to a <c>test-images\conformance\testcases</c> folder.
/// </summary>
/// <param name="ACaseName">Name of the test case, e.g. <c>bike</c>.</param>
/// <returns>The case folder, or <c>''</c>.</returns>
function ConformanceCaseFolder( const ACaseName: string ): string;

/// <summary>Returns the largest absolute difference between two equally sized sample buffers.</summary>
/// <param name="AFirst">First buffer.</param>
/// <param name="ASecond">Second buffer; must be the same length.</param>
/// <returns>The largest per-sample difference, 0 when identical.</returns>
/// <exception cref="EArgumentException">The buffers differ in length.</exception>
function MaxSampleDifference( const AFirst: TBytes; const ASecond: TBytes ): Integer;

/// <summary>Returns the mean absolute difference between two equally sized sample buffers.</summary>
/// <param name="AFirst">First buffer.</param>
/// <param name="ASecond">Second buffer; must be the same length.</param>
/// <returns>The mean per-sample difference, 0 when identical or empty.</returns>
/// <exception cref="EArgumentException">The buffers differ in length.</exception>
function MeanSampleDifference( const AFirst: TBytes; const ASecond: TBytes ): Double;

/// <summary>Returns the index of the first byte where two buffers differ, or -1 when they are identical.</summary>
/// <param name="AFirst">First buffer.</param>
/// <param name="ASecond">Second buffer.</param>
/// <returns>The first differing index, the shorter length when one is a prefix of the other, or -1.</returns>
function FirstDifference( const AFirst: TBytes; const ASecond: TBytes ): Integer;

implementation

uses
  System.IOUtils,
  Vcl.Imaging.pngimage,
  DUnitX.TestFramework;

function BindingSourceFolder: string;
begin

  var sFolder := ExtractFileDir( ParamStr( 0 ) );

  while ( sFolder <> '' ) do
  begin
    var sCandidate := TPath.Combine( sFolder, 'Source' );

    if TFile.Exists( TPath.Combine( sCandidate, 'Jxl.Api.Types.pas' ) ) then Exit( sCandidate );

    var sParent := ExtractFileDir( sFolder );

    if SameText( sParent, sFolder ) then Break;

    sFolder := sParent;
  end;

  raise EFileNotFoundException.Create( 'The binding''s Source folder was not found above the test executable.' );

end;

procedure AssertJxlError( const AProc: TProc; const AApiName: string; ABindingCheck: Boolean; const AText: string;
  const AWhat: string );
begin

  try
    AProc;
  except
    on E: EJxlError do
    begin
      Assert.AreEqual( AApiName, E.ApiName, False, Format( '%s: ApiName (message "%s")', [ AWhat, E.Message ] ) );
      Assert.AreEqual( ABindingCheck, E.IsBindingCheck, Format( '%s: IsBindingCheck (message "%s")', [ AWhat, E.Message ] ) );
      Assert.IsTrue( Pos( AText, E.Message ) > 0, Format( '%s: message "%s" lacks "%s"', [ AWhat, E.Message, AText ] ) );
      Exit;
    end;
  end;

  Assert.Fail( Format( '%s: no EJxlError was raised', [ AWhat ] ) );

end;

/// <summary>Finds the <c>testdata/jxl</c> folder, or reports the calling test as ignored.</summary>
/// <returns>Its full path.</returns>
function TestDataRoot: string;
begin

  var sVariable := ExcludeTrailingPathDelimiter( GetEnvironmentVariable( 'LIBJXL_TESTDATA' ) );

  if ( sVariable <> '' ) then
  begin
    if TDirectory.Exists( TPath.Combine( sVariable, 'jxl' ) ) then Exit( TPath.Combine( sVariable, 'jxl' ) );

    if TDirectory.Exists( sVariable ) and SameText( ExtractFileName( sVariable ), 'jxl' ) then Exit( sVariable );

    Assert.Ignore( Format( 'LIBJXL_TESTDATA (%s) holds no jxl folder: %s', [ sVariable, TESTDATA_HINT ] ) );
  end;

  var sFolder := ExtractFileDir( ParamStr( 0 ) );

  while ( sFolder <> '' ) do
  begin
    var sCandidate := TPath.Combine( sFolder, 'testdata\jxl' );

    if TDirectory.Exists( sCandidate ) then Exit( sCandidate );

    var sParent := ExtractFileDir( sFolder );

    if SameText( sParent, sFolder ) then Break;

    sFolder := sParent;
  end;

  Assert.Ignore( 'libjxl test data not found: ' + TESTDATA_HINT );

end;

function TestDataFile( const ARelativePath: string ): string;
begin

  Result := TPath.Combine( TestDataRoot, ARelativePath );

  if ( not TFile.Exists( Result ) ) then
    raise EFileNotFoundException.CreateFmt( 'Test data file not found: %s', [ Result ] );

end;

function LoadPngPixels( const AFileName: string ): TJxlPixels;
var
  oPng: TPngImage;
begin

  oPng := TPngImage.Create;

  try
    oPng.LoadFromFile( AFileName );

    if ( ( oPng.Header.BitDepth <> 8 ) and ( oPng.Header.BitDepth <> 16 ) )
      or ( ( oPng.Header.ColorType <> COLOR_RGB ) and ( oPng.Header.ColorType <> COLOR_RGBALPHA )
      and ( oPng.Header.ColorType <> COLOR_GRAYSCALE ) ) then
      raise EArgumentException.CreateFmt( '%s is not an 8 or 16-bit grey, RGB or RGBA PNG.', [ AFileName ] );

    var bAlpha := ( oPng.Header.ColorType = COLOR_RGBALPHA );
    var bGrey  := ( oPng.Header.ColorType = COLOR_GRAYSCALE );
    Result := Default( TJxlPixels );
    Result.Width              := oPng.Width;
    Result.Height             := oPng.Height;
    Result.NumChannels        := if bAlpha then 4 else 3;
    Result.AlphaPremultiplied := False;
    SetLength( Result.Data, NativeInt( Result.Width ) * NativeInt( Result.Height ) * NativeInt( Result.NumChannels ) );

    var pTarget := PByte( Result.Data );

    for var iY := 0 to oPng.Height - 1 do
    begin
      var pSource := PByte( oPng.Scanline[ iY ] );
      var pAlpha  := PByte( nil );

      if bAlpha then pAlpha := PByte( oPng.AlphaScanline[ iY ] );

      for var iX := 0 to oPng.Width - 1 do
      begin
        if bGrey then
        begin
          pTarget[ 0 ] := pSource[ 0 ];
          pTarget[ 1 ] := pSource[ 0 ];
          pTarget[ 2 ] := pSource[ 0 ];
          Inc( pSource, 1 );
        end
        else
        begin
          pTarget[ 0 ] := pSource[ 2 ];
          pTarget[ 1 ] := pSource[ 1 ];
          pTarget[ 2 ] := pSource[ 0 ];
          Inc( pSource, 3 );
        end;

        if bAlpha then pTarget[ 3 ] := pAlpha[ iX ];

        Inc( pTarget, Result.NumChannels );
      end;

    end;

  finally
    oPng.Free;
  end;

end;

function ConformanceCaseFolder( const ACaseName: string ): string;
begin

  Result    := '';
  var sRoot := ExcludeTrailingPathDelimiter( GetEnvironmentVariable( 'JXL_CONFORMANCE' ) );

  if ( sRoot <> '' ) and TDirectory.Exists( TPath.Combine( sRoot, 'testcases' ) ) then sRoot := TPath.Combine( sRoot, 'testcases' );

  if ( sRoot = '' ) then
  begin
    var sFolder := ExtractFileDir( ParamStr( 0 ) );

    while ( sFolder <> '' ) and ( sRoot = '' ) do
    begin
      if TDirectory.Exists( TPath.Combine( sFolder, 'test-images\conformance\testcases' ) ) then
        sRoot := TPath.Combine( sFolder, 'test-images\conformance\testcases' );

      var sParent := ExtractFileDir( sFolder );

      if SameText( sParent, sFolder ) then Break;

      sFolder := sParent;
    end;

  end;

  if ( sRoot <> '' ) and TDirectory.Exists( TPath.Combine( sRoot, ACaseName ) ) then Result := TPath.Combine( sRoot, ACaseName );

end;

function MaxSampleDifference( const AFirst: TBytes; const ASecond: TBytes ): Integer;
begin

  if ( Length( AFirst ) <> Length( ASecond ) ) then
    raise EArgumentException.CreateFmt( 'Buffers differ in length: %d and %d.', [ Length( AFirst ), Length( ASecond ) ] );

  Result := 0;

  for var iI := 0 to High( AFirst ) do
  begin
    var iDifference := Abs( Integer( AFirst[ iI ] ) - Integer( ASecond[ iI ] ) );

    if ( iDifference > Result ) then Result := iDifference;
  end;

end;

function MeanSampleDifference( const AFirst: TBytes; const ASecond: TBytes ): Double;
begin

  if ( Length( AFirst ) <> Length( ASecond ) ) then
    raise EArgumentException.CreateFmt( 'Buffers differ in length: %d and %d.', [ Length( AFirst ), Length( ASecond ) ] );

  Result := 0;

  if ( Length( AFirst ) = 0 ) then Exit;

  var iTotal: Int64 := 0;

  for var iI := 0 to High( AFirst ) do Inc( iTotal, Abs( Integer( AFirst[ iI ] ) - Integer( ASecond[ iI ] ) ) );

  Result := iTotal / Length( AFirst );

end;

function FirstDifference( const AFirst: TBytes; const ASecond: TBytes ): Integer;
begin

  var iCommon := Length( AFirst );

  if ( Length( ASecond ) < iCommon ) then iCommon := Length( ASecond );

  for var iI := 0 to iCommon - 1 do
    if ( AFirst[ iI ] <> ASecond[ iI ] ) then Exit( iI );

  Result := if ( Length( AFirst ) = Length( ASecond ) ) then -1 else iCommon;

end;

end.
