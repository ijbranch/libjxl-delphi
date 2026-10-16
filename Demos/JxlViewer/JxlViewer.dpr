(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   A small VCL viewer demonstrating the libjxl Delphi binding: it opens JPEG XL (and any other format
///   <c>TPicture</c> knows), saves as JPEG XL, and losslessly recompresses JPEG files and reconstructs them. Needs the
///   libjxl DLL(s) next to the executable (the post-build event runs <c>..\..\CopyJxlDlls.ps1</c>). An image file named
///   on the command line is opened at start-up.
/// </summary>
program JxlViewer;

uses
  Vcl.Forms,
  Jxl.Api.Types in '..\..\Source\Jxl.Api.Types.pas',
  Jxl.Api.Decode in '..\..\Source\Jxl.Api.Decode.pas',
  Jxl.Api.Encode in '..\..\Source\Jxl.Api.Encode.pas',
  Jxl.Api.Threads in '..\..\Source\Jxl.Api.Threads.pas',
  Jxl.Api.Cms in '..\..\Source\Jxl.Api.Cms.pas',
  Jxl.Graphic in '..\..\Source\Jxl.Graphic.pas',
  JxlViewer.Main in 'JxlViewer.Main.pas' {MainForm};

{$R *.res}

begin

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title             := 'JPEG XL Viewer';
  Application.CreateForm( TMainForm, MainForm );
  Application.Run;

end.
