(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   DUnitX console runner for the libjxl Delphi binding. Needs the libjxl DLLs next to the executable (the post-build
///   event runs <c>CopyJxlDlls.ps1</c>) and libjxl's <c>testdata</c> folder (named by the <c>LIBJXL_TESTDATA</c>
///   environment variable, or found by walking up from the executable); tests whose data is absent are ignored.
/// </summary>
program LibJxlTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

{$R *.res}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Jxl.Api.Types in '..\Source\Jxl.Api.Types.pas',
  Jxl.Api.Decode in '..\Source\Jxl.Api.Decode.pas',
  Jxl.Api.Encode in '..\Source\Jxl.Api.Encode.pas',
  Jxl.Api.Threads in '..\Source\Jxl.Api.Threads.pas',
  Jxl.Api.Cms in '..\Source\Jxl.Api.Cms.pas',
  Jxl.Graphic in '..\Source\Jxl.Graphic.pas',
  TestJxl.Common in 'TestJxl.Common.pas',
  TestJxl.Api in 'TestJxl.Api.pas',
  TestJxl.Graphic in 'TestJxl.Graphic.pas',
  TestJxl.Conformance in 'TestJxl.Conformance.pas',
  TestJxl.Wic in 'TestJxl.Wic.pas',
  TestJxl.Info in 'TestJxl.Info.pas',
  TestJxl.Limits in 'TestJxl.Limits.pas',
  TestJxl.Cancellation in 'TestJxl.Cancellation.pas',
  TestJxl.Layout in 'TestJxl.Layout.pas';

var
  intfRunner: ITestRunner;
  intfResults: IRunResults;
  sXmlFile: string;

begin

  try
    TDUnitX.CheckCommandLine;
    intfRunner         := TDUnitX.CreateRunner;
    intfRunner.UseRTTI := True;
    // A test that asserts nothing fails, and string comparisons are case-sensitive unless a test asks otherwise.
    intfRunner.FailsOnNoAsserts := True;
    Assert.IgnoreCaseDefault    := False;
    intfRunner.AddLogger( TDUnitXConsoleLogger.Create( True ) );

    // Results go to <exe name>-results.xml unless --xmloutput names another file.
    sXmlFile := TDUnitX.Options.XMLOutputFile;

    if ( sXmlFile = '' ) or SameText( ExtractFileName( sXmlFile ), 'dunitx-results.xml' ) then
      sXmlFile := ChangeFileExt( ParamStr( 0 ), '' ) + '-results.xml';

    intfRunner.AddLogger( TDUnitXXMLNUnitFileLogger.Create( sXmlFile ) );
    intfResults := intfRunner.Execute;

    if ( TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause ) then
    begin
      Write( 'Done, press Enter to continue.' );
      Readln;
    end;

    if ( not intfResults.AllPassed ) then ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      Writeln( E.ClassName, ': ', E.Message );
      ExitCode := EXIT_ERRORS;
    end;
  end;

end.
