(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Main form of the JPEG XL viewer demo: opens an image through <c>TPicture</c> (JPEG XL through
///   <c>TJxlImage</c>), shows it with its details, saves it as JPEG XL, and runs lossless JPEG recompression and
///   reconstruction. The long operations run on a worker thread, so the window stays responsive, and can be cancelled
///   (Cancel, Esc, or closing the window) through a <c>TJxlCancellation</c>.
/// </summary>
unit JxlViewer.Main;

interface

uses
  System.SysUtils, System.Classes, System.Actions,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls,
  Vcl.ActnList, Vcl.ExtDlgs,
  Jxl.Graphic;

type
  /// <summary>The viewer's only window.</summary>
  TMainForm = class( TForm )
    /// <summary>Row of command buttons along the top.</summary>
    pnlButtons: TGridPanel;
    /// <summary>Runs <see cref="actOpen" />.</summary>
    btnOpen: TBitBtn;
    /// <summary>Runs <see cref="actSaveJxl" />.</summary>
    btnSaveJxl: TBitBtn;
    /// <summary>Runs <see cref="actJpegToJxl" />.</summary>
    btnJpegToJxl: TBitBtn;
    /// <summary>Runs <see cref="actJxlToJpeg" />.</summary>
    btnJxlToJpeg: TBitBtn;
    /// <summary>Runs <see cref="actValidate" />.</summary>
    btnValidate: TBitBtn;
    /// <summary>Runs <see cref="actValidateFile" />.</summary>
    btnValidateFile: TBitBtn;
    /// <summary>Runs <see cref="actCancel" />.</summary>
    btnCancel: TBitBtn;
    /// <summary>Right-hand column holding the settings, image details and results.</summary>
    pnlSide: TPanel;
    /// <summary>Display settings.</summary>
    grpView: TGroupBox;
    /// <summary>Scales the image to fit the window (keeping its proportions) instead of showing it at full size.</summary>
    chkFit: TCheckBox;
    /// <summary>JPEG XL encoder settings used by Save as JXL and the JPEG recompression.</summary>
    grpEncode: TGroupBox;
    /// <summary>Encode losslessly; disables the distance setting.</summary>
    chkLossless: TCheckBox;
    /// <summary>Caption and value of <see cref="tbDistance" />.</summary>
    lblDistance: TLabel;
    /// <summary>Lossy distance in tenths: 1 (0.1, near-lossless) to 150 (15.0, smallest).</summary>
    tbDistance: TTrackBar;
    /// <summary>Caption and value of <see cref="tbEffort" />.</summary>
    lblEffort: TLabel;
    /// <summary>Encoder effort, 1 (fastest) to 10 (smallest).</summary>
    tbEffort: TTrackBar;
    /// <summary>Frame of <see cref="mmoInfo" />.</summary>
    grpInfo: TGroupBox;
    /// <summary>Details of the open image.</summary>
    mmoInfo: TMemo;
    /// <summary>Frame of <see cref="mmoLog" />.</summary>
    grpLog: TGroupBox;
    /// <summary>Results of the save and conversion commands, newest last.</summary>
    mmoLog: TMemo;
    /// <summary>Scrolls the image when it is shown at full size.</summary>
    sbImage: TScrollBox;
    /// <summary>Shows the image, over a chequerboard where it is transparent.</summary>
    imgView: TImage;
    /// <summary>The form's commands.</summary>
    alMain: TActionList;
    /// <summary>Opens an image file.</summary>
    actOpen: TAction;
    /// <summary>Saves the open image as JPEG XL with the encoder settings.</summary>
    actSaveJxl: TAction;
    /// <summary>Recompresses the open JPEG file losslessly as JPEG XL.</summary>
    actJpegToJxl: TAction;
    /// <summary>Reconstructs the original JPEG file from the open JPEG XL file.</summary>
    actJxlToJpeg: TAction;
    /// <summary>Checks the open JPEG XL file completely with <c>JxlValidate</c>.</summary>
    actValidate: TAction;
    /// <summary>Checks a chosen JPEG XL file completely without opening it, so a file that fails to open can be checked.</summary>
    actValidateFile: TAction;
    /// <summary>Cancels the operation running on the worker thread (Esc).</summary>
    actCancel: TAction;
    /// <summary>Chooses the file <see cref="actValidateFile" /> checks; a plain dialog, so no preview decodes it.</summary>
    dlgValidate: TOpenDialog;
    /// <summary>Chooses the image to open, with a preview.</summary>
    dlgOpen: TOpenPictureDialog;
    /// <summary>Chooses the file a command writes.</summary>
    dlgSave: TSaveDialog;
    /// <summary>Checks for the libjxl DLL(s) and queues the start-up work.</summary>
    /// <param name="Sender">The form.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>
    ///   Cancels a running operation and keeps the window open until it has stopped; the window then closes itself.
    /// </summary>
    /// <param name="Sender">The form.</param>
    /// <param name="CanClose">Set to <c>False</c> while an operation runs.</param>
    procedure FormCloseQuery( Sender: TObject; var CanClose: Boolean );
    /// <summary>
    ///   Cancels and waits for a running operation (only reached when Windows ends the session) and frees the open
    ///   picture.
    /// </summary>
    /// <param name="Sender">The form.</param>
    procedure FormDestroy( Sender: TObject );
    /// <summary>Asks for an image file and opens it.</summary>
    /// <param name="Sender">The action.</param>
    procedure actOpenExecute( Sender: TObject );
    /// <summary>Enabled while no operation runs.</summary>
    /// <param name="Sender">The action.</param>
    procedure actOpenUpdate( Sender: TObject );
    /// <summary>Saves the open image as JPEG XL on the worker thread and reports the size.</summary>
    /// <param name="Sender">The action.</param>
    procedure actSaveJxlExecute( Sender: TObject );
    /// <summary>Enabled when an image is open, libjxl is available and no operation runs.</summary>
    /// <param name="Sender">The action.</param>
    procedure actSaveJxlUpdate( Sender: TObject );
    /// <summary>Recompresses the open JPEG file losslessly on the worker thread and reports the sizes.</summary>
    /// <param name="Sender">The action.</param>
    procedure actJpegToJxlExecute( Sender: TObject );
    /// <summary>Enabled when the open file is a JPEG, libjxl is available and no operation runs.</summary>
    /// <param name="Sender">The action.</param>
    procedure actJpegToJxlUpdate( Sender: TObject );
    /// <summary>
    ///   Reconstructs the JPEG held in the open JPEG XL file on the worker thread and compares it with the original
    ///   when known; a target that would overwrite the open file or the original is refused.
    /// </summary>
    /// <param name="Sender">The action.</param>
    procedure actJxlToJpegExecute( Sender: TObject );
    /// <summary>
    ///   Enabled when the open file is JPEG XL, libjxl is available and no operation runs; shared with
    ///   <see cref="actValidate" />.
    /// </summary>
    /// <param name="Sender">The action.</param>
    procedure actJxlToJpegUpdate( Sender: TObject );
    /// <summary>Validates the open JPEG XL file on the worker thread and reports the result.</summary>
    /// <param name="Sender">The action.</param>
    procedure actValidateExecute( Sender: TObject );
    /// <summary>Asks for a JPEG XL file and validates it without opening or displaying it.</summary>
    /// <param name="Sender">The action.</param>
    procedure actValidateFileExecute( Sender: TObject );
    /// <summary>Enabled when libjxl is available and no operation runs.</summary>
    /// <param name="Sender">The action.</param>
    procedure actValidateFileUpdate( Sender: TObject );
    /// <summary>Asks the running operation to stop; it ends with "Cancelled." in the results.</summary>
    /// <param name="Sender">The action.</param>
    procedure actCancelExecute( Sender: TObject );
    /// <summary>Enabled only while an operation runs and has not yet been asked to stop.</summary>
    /// <param name="Sender">The action.</param>
    procedure actCancelUpdate( Sender: TObject );
    /// <summary>Switches between fit-to-window and full size.</summary>
    /// <param name="Sender">The check box.</param>
    procedure chkFitClick( Sender: TObject );
    /// <summary>Enables the distance setting only for lossy encoding.</summary>
    /// <param name="Sender">The check box.</param>
    procedure chkLosslessClick( Sender: TObject );
    /// <summary>Shows the encoder settings' values in their labels.</summary>
    /// <param name="Sender">The track bar.</param>
    procedure EncodeSettingChange( Sender: TObject );
  private
    /// <summary>The open image as loaded, in its own format; empty when nothing is open.</summary>
    FPicture: TPicture;
    /// <summary>Full path of the open image, or empty.</summary>
    FFileName: string;
    /// <summary>What <c>JxlReadInfo</c> reported for the open JPEG XL file; valid only when <see cref="FHasInfo" /> is set.</summary>
    FInfo: TJxlInfo;
    /// <summary>Whether <see cref="FInfo" /> holds the open file's headers (a JPEG XL file whose headers could be read).</summary>
    FHasInfo: Boolean;
    /// <summary>Whether the libjxl DLL(s) can be loaded.</summary>
    FLibraryAvailable: Boolean;
    /// <summary>Why the libjxl DLL(s) cannot be loaded, or empty.</summary>
    FLibraryError: string;
    /// <summary>Full path of the JPEG most recently recompressed, kept to compare a later reconstruction with.</summary>
    FLastJpegSource: string;
    /// <summary>Full path of the JPEG XL file that recompression wrote.</summary>
    FLastJxlTarget: string;
    /// <summary>The operation running on the worker thread, or <c>nil</c>; owned by the form.</summary>
    FJob: TThread;
    /// <summary>Runs on the UI thread when <see cref="FJob" /> finishes, with whether it succeeded; may be <c>nil</c>.</summary>
    FJobFinish: TProc<Boolean>;
    /// <summary>Whether the user asked to close the window while an operation ran; it closes when the operation ends.</summary>
    FCloseRequested: Boolean;
    /// <summary>Reports libjxl and its limits, or a missing libjxl, and opens the file named on the command line.</summary>
    procedure StartUp;
    /// <summary>Reports whether an operation is running on the worker thread.</summary>
    /// <returns><c>True</c> while one runs; the commands are then disabled.</returns>
    function IsBusy: Boolean;
    /// <summary>
    ///   Starts an operation on the worker thread. The work must touch nothing the form owns: it adds its result lines to
    ///   the list it is given, and they are logged on the UI thread when it ends. It passes the token it is given to
    ///   every libjxl routine it calls, so that Cancel and closing the window can stop it.
    /// </summary>
    /// <param name="ADescription">What is starting, logged at once, e.g. <c>Saving photo.jxl</c>.</param>
    /// <param name="AFailurePrefix">Logged before the message of an exception the work raises.</param>
    /// <param name="AWork">The work; runs on the worker thread, with the job's cancellation token.</param>
    /// <param name="AFinish">Runs on the UI thread after the result lines are logged; may be <c>nil</c>.</param>
    procedure RunJob( const ADescription: string; const AFailurePrefix: string; const AWork: TProc<TStrings, TJxlCancellation>;
      const AFinish: TProc<Boolean> );
    /// <summary>Asks the running operation, if any, to stop; logs that it was asked once.</summary>
    /// <param name="AReason">Logged with the request, e.g. <c>Cancelling</c>.</param>
    procedure CancelJob( const AReason: string );
    /// <summary>Logs a finished operation's results, runs its finish step, and closes the window if that was asked for.</summary>
    /// <param name="Sender">The finished worker thread.</param>
    procedure JobTerminate( Sender: TObject );
    /// <summary>Loads an image file and shows it with its details; a file that fails to load is reported and leaves the open image.</summary>
    /// <param name="AFileName">Path of the image.</param>
    procedure OpenFile( const AFileName: string );
    /// <summary>Draws the open image into <see cref="imgView" />, over a chequerboard when it has transparency.</summary>
    procedure ShowPicture;
    /// <summary>Lays out <see cref="imgView" /> for fit-to-window or full size.</summary>
    procedure ApplyFit;
    /// <summary>
    ///   Reads the JPEG XL headers of the open file into <see cref="FInfo" /> and fills <see cref="mmoInfo" /> with the
    ///   open image's details; headers that cannot be read are reported in place of the JPEG XL details.
    /// </summary>
    /// <param name="ALoadMilliseconds">How long loading took.</param>
    procedure ShowInfo( ALoadMilliseconds: Int64 );
    /// <summary>Returns the encoder settings chosen on the form.</summary>
    /// <returns>The settings.</returns>
    function EncodeOptions: TJxlEncodeOptions;
    /// <summary>
    ///   Prepares the open image's samples for encoding, on the UI thread (VCL graphics are not thread-safe): a PNG's own
    ///   samples, a JPEG XL image's decoded samples (or the file to decode again, for straight alpha), a vector or icon
    ///   graphic drawn onto a bitmap, or any other graphic through a VCL bitmap.
    /// </summary>
    /// <param name="APixels">Receives the pixels, unless <paramref name="AJxlFileName" /> is set.</param>
    /// <param name="AJxlFileName">Receives the JPEG XL file to decode on the worker thread instead, or empty.</param>
    /// <param name="ARoute">Receives the route taken and whether it is exact, for the results.</param>
    /// <exception cref="EJxlError">The image is too large for one pixel buffer.</exception>
    /// <exception cref="EArgumentException">The image is empty.</exception>
    procedure PrepareSaveSource( out APixels: TJxlPixels; out AJxlFileName: string; out ARoute: string );
    /// <summary>Returns the original JPEG to compare a reconstruction of the open file with, if one is known.</summary>
    /// <returns>The JPEG this session recompressed into the open file, else a JPEG beside it, else empty.</returns>
    function OriginalJpeg: string;
    /// <summary>
    ///   Asks where to save a file, asking again while the choice has the wrong extension, names a file the command reads
    ///   or compares with, or cannot be written.
    /// </summary>
    /// <param name="ATitle">Dialog title.</param>
    /// <param name="AFilter">Dialog filter.</param>
    /// <param name="ADefaultExt">Extension added when none is typed, without the dot.</param>
    /// <param name="AFileName">Suggested path.</param>
    /// <param name="AExtensions">Extensions the chosen file must have, with the dot.</param>
    /// <param name="AProtected">Paths the chosen file must not be (empty entries are ignored).</param>
    /// <param name="AChosen">Receives the chosen full path.</param>
    /// <returns><c>True</c> when an acceptable file was chosen.</returns>
    function AskSaveFile( const ATitle: string; const AFilter: string; const ADefaultExt: string; const AFileName: string;
      const AExtensions: array of string; const AProtected: array of string; out AChosen: string ): Boolean;
    /// <summary>Checks a file completely (<c>JxlValidate</c>) on the worker thread and reports the outcome and timing.</summary>
    /// <param name="AFileName">Full path of the file.</param>
    procedure RunValidation( const AFileName: string );
    /// <summary>Adds a line to the results.</summary>
    /// <param name="AText">The line.</param>
    procedure Log( const AText: string );
  end;

var
  /// <summary>The application's main form.</summary>
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  System.Math, System.IOUtils, System.Diagnostics, System.UITypes,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Imaging.GIFImg,
  Jxl.Api.Types, Jxl.Api.Decode;

const
  /// <summary>Side of one chequerboard square, in pixels.</summary>
  CHECKER_SIZE = 16;
  /// <summary>Filter of the JPEG XL save dialog.</summary>
  JXL_FILTER = 'JPEG XL (*.jxl)|*.jxl';
  /// <summary>Filter of the JPEG save dialog.</summary>
  JPEG_FILTER = 'JPEG (*.jpg;*.jpeg;*.jpe;*.jfif)|*.jpg;*.jpeg;*.jpe;*.jfif';
  /// <summary>Extensions of a JPEG file, with the dot.</summary>
  JPEG_EXTENSIONS: array[ 0..3 ] of string = ( '.jpg', '.jpeg', '.jpe', '.jfif' );
  /// <summary>Extension of a JPEG XL file, with the dot.</summary>
  JXL_EXTENSION = '.jxl';

type
  /// <summary>
  ///   One operation run off the UI thread. The form owns it (<c>FreeOnTerminate</c> is <c>False</c>); its result lines
  ///   are read only after it has finished, from its <c>OnTerminate</c> event, so they need no lock.
  /// </summary>
  TJxlJob = class( TThread )
  private
    /// <summary>The work; adds its result lines to the list and passes the token to the libjxl routines.</summary>
    FWork: TProc<TStrings, TJxlCancellation>;
    /// <summary>Logged before the message of an exception the work raises.</summary>
    FFailurePrefix: string;
    /// <summary>The result lines.</summary>
    FResults: TStringList;
    /// <summary>Whether the work returned without raising.</summary>
    FSucceeded: Boolean;
    /// <summary>The job's cancellation token; owned, and freed only after the thread has ended.</summary>
    FCancellation: TJxlCancellation;
  protected
    /// <summary>Runs the work, turning an exception it raises into a result line, and a cancellation into "Cancelled.".</summary>
    procedure Execute; override;
  public
    /// <summary>Creates the job suspended; call <c>Start</c> to run it.</summary>
    /// <param name="AWork">The work.</param>
    /// <param name="AFailurePrefix">Logged before the message of an exception the work raises.</param>
    constructor Create( const AWork: TProc<TStrings, TJxlCancellation>; const AFailurePrefix: string );
    /// <summary>Waits for the work to finish (as <c>TThread</c> does), then frees the result lines and the token.</summary>
    destructor Destroy; override;
    /// <summary>The result lines; read them only once the job has finished.</summary>
    property Results: TStringList read FResults;
    /// <summary>Whether the work returned without raising; read it only once the job has finished.</summary>
    property Succeeded: Boolean read FSucceeded;
    /// <summary>The job's token: <c>Cancel</c> it from any thread to stop the work.</summary>
    property Cancellation: TJxlCancellation read FCancellation;
  end;

/// <summary>Formats a byte count with thousands separators.</summary>
/// <param name="ABytes">The count.</param>
/// <returns>For example <c>388,268 bytes</c>.</returns>
function FormatBytes( ABytes: Int64 ): string;
begin

  Result := Format( '%.0n bytes', [ ABytes * 1.0 ] );

end;

/// <summary>Formats a byte count in whole mebibytes.</summary>
/// <param name="ABytes">The count.</param>
/// <returns>For example <c>1,024 MiB</c>.</returns>
function FormatMiB( ABytes: Int64 ): string;
begin

  Result := Format( '%.0n MiB', [ ABytes / ( 1024 * 1024 ) ] );

end;

/// <summary>Describes a size relative to another, as a percentage, or as a multiple when it is ten times larger or more.</summary>
/// <param name="ASize">The size described.</param>
/// <param name="AReference">The size it is compared with; greater than 0.</param>
/// <returns>For example <c>83.4% of</c> or <c>14,221 times the size of</c>.</returns>
function FormatRatio( ASize: Int64; AReference: Int64 ): string;
begin

  var fRatio := ASize / AReference;

  if ( fRatio >= 10 ) then
    Result := Format( '%.0n times the size of', [ fRatio ] )
  else
    Result := Format( '%.1f%% of', [ 100 * fRatio ] );

end;

/// <summary>Describes an output size relative to the file the open image was loaded from.</summary>
/// <param name="ASize">The output size in bytes.</param>
/// <param name="ASourceSize">Size of the source file, read before the output was written; negative when there is none.</param>
/// <param name="ASourceName">Name of the source file.</param>
/// <returns>For example <c>83.4% of photo.png (1,234 bytes)</c>, or <c>no source file</c>.</returns>
function DescribeComparison( ASize: Int64; ASourceSize: Int64; const ASourceName: string ): string;
begin

  if ( ASourceSize < 0 ) then Exit( 'no source file' );

  if ( ASourceSize = 0 ) then Exit( 'the source file is empty' );

  Result := Format( '%s %s (%s)', [ FormatRatio( ASize, ASourceSize ), ASourceName, FormatBytes( ASourceSize ) ] );

end;

/// <summary>Reports whether a path has one of the given extensions.</summary>
/// <param name="AFileName">The path.</param>
/// <param name="AExtensions">Extensions with the dot, e.g. <c>.jpg</c>.</param>
/// <returns><c>True</c> on a match, ignoring case.</returns>
function HasExtension( const AFileName: string; const AExtensions: array of string ): Boolean;
begin

  var sExtension := ExtractFileExt( AFileName );

  for var sCandidate in AExtensions do
    if SameText( sExtension, sCandidate ) then Exit( True );

  Result := False;

end;

/// <summary>Reports whether two paths name the same file, comparing their expanded forms.</summary>
/// <param name="AFirst">First path; may be empty.</param>
/// <param name="ASecond">Second path; may be empty.</param>
/// <returns><c>True</c> when both are non-empty and name the same file.</returns>
function SamePath( const AFirst: string; const ASecond: string ): Boolean;
begin

  Result := ( AFirst <> '' ) and ( ASecond <> '' ) and SameFileName( ExpandFileName( AFirst ), ExpandFileName( ASecond ) );

end;

/// <summary>Returns where two byte arrays first differ.</summary>
/// <param name="AFirst">First data.</param>
/// <param name="ASecond">Second data.</param>
/// <returns>The first differing offset (the shorter length when one is a prefix of the other), or -1 when identical.</returns>
function FirstDifference( const AFirst: TBytes; const ASecond: TBytes ): Int64;
begin

  var iCommon := Min( Length( AFirst ), Length( ASecond ) );

  for var iI := 0 to iCommon - 1 do
    if ( AFirst[ iI ] <> ASecond[ iI ] ) then Exit( iI );

  if ( Length( AFirst ) <> Length( ASecond ) ) then Exit( iCommon );

  Result := -1;

end;

/// <summary>Describes an exception for the results, saying when the binding refused the input itself.</summary>
/// <param name="E">The exception.</param>
/// <returns>
///   The message (which names the failing call or routine); for a binding check (a resource limit, malformed input)
///   prefixed with a note that the binding refused it; for an exception of an unexpected class prefixed with the class name.
/// </returns>
function DescribeFailure( E: Exception ): string;
begin

  if ( E is EJxlError ) and EJxlError( E ).IsBindingCheck then
    Result := 'refused by the binding''s checks (resource limits, input structure): ' + E.Message
  else if ( E is EJxlError ) or ( E is EFileStreamError ) or ( E is EInOutError ) then
    Result := E.Message
  else if ( E is EArgumentException ) then
    Result := 'invalid input or setting: ' + E.Message
  else
    Result := E.ClassName + ': ' + E.Message;

end;

/// <summary>Reports whether an exception is one that opening, preparing or writing an image is expected to raise.</summary>
/// <param name="E">The exception.</param>
/// <returns><c>True</c> for libjxl, graphic-format, conversion, resource and file errors; <c>False</c> for a program fault.</returns>
function IsExpectedFailure( E: Exception ): Boolean;
begin

  Result := ( E is EJxlError ) or ( E is EArgumentException ) or ( E is EInvalidGraphic ) or ( E is EConvertError )
    or ( E is EOutOfResources ) or ( E is EFileStreamError ) or ( E is EReadError ) or ( E is EInOutError );

end;

/// <summary>Names a JPEG XL / EXIF orientation as the transform from the stored to the displayed image.</summary>
/// <param name="AOrientation">The orientation, 1 to 8.</param>
/// <returns>For example <c>rotated 90 degrees clockwise</c>.</returns>
function OrientationText( AOrientation: Integer ): string;
begin

  case AOrientation of
    1: Result := 'as stored';
    2: Result := 'flipped left to right';
    3: Result := 'rotated 180 degrees';
    4: Result := 'flipped top to bottom';
    5: Result := 'transposed, i.e. flipped about the top-left diagonal';
    6: Result := 'rotated 90 degrees clockwise';
    7: Result := 'transversed, i.e. flipped about the top-right diagonal';
    8: Result := 'rotated 90 degrees anticlockwise';
  else
    Result := 'unknown';
  end;

end;

/// <summary>Describes the bit depth of a JPEG XL image's colour samples.</summary>
/// <param name="AInfo">The image's information.</param>
/// <returns>For example <c>8-bit</c> or <c>32-bit float</c>.</returns>
function FormatBits( const AInfo: TJxlInfo ): string;
begin

  if ( AInfo.ExponentBitsPerSample > 0 ) then
    Result := Format( '%d-bit float', [ AInfo.BitsPerSample ] )
  else
    Result := Format( '%d-bit', [ AInfo.BitsPerSample ] );

end;

/// <summary>Describes a JPEG XL image's original colour encoding.</summary>
/// <param name="AInfo">The image's information.</param>
/// <returns>
///   For example <c>sRGB</c>, <c>RGB: sRGB primaries, D65, BT.709 transfer</c> or <c>ICC profile, grey (3,144 bytes)</c>.
/// </returns>
function ColourText( const AInfo: TJxlInfo ): string;
begin

  var sSpace := '';

  case AInfo.ColourSpace of
    jcsRgb:
      sSpace := 'RGB';
    jcsGrey:
      sSpace := 'grey';
    jcsXyb:
      sSpace := 'XYB';
  else
    sSpace := 'colour space unknown';
  end;

  if AInfo.HasIccProfile then Exit( Format( 'ICC profile, %s (%s)', [ sSpace, FormatBytes( AInfo.IccProfileSize ) ] ) );

  if AInfo.IsSrgb then Exit( if ( AInfo.ColourSpace = jcsGrey ) then 'sRGB (grey)' else 'sRGB' );

  var rEncoding := AInfo.ColourEncoding;
  var sPrimaries := '';

  if ( AInfo.ColourSpace = jcsRgb ) then
    case rEncoding.primaries of
      JXL_PRIMARIES_SRGB:
        sPrimaries := 'sRGB primaries, ';
      JXL_PRIMARIES_2100:
        sPrimaries := 'BT.2100 primaries, ';
      JXL_PRIMARIES_P3:
        sPrimaries := 'P3 primaries, ';
    else
      sPrimaries := 'custom primaries, ';
    end;

  var sWhite := '';

  case rEncoding.white_point of
    JXL_WHITE_POINT_D65:
      sWhite := 'D65';
    JXL_WHITE_POINT_E:
      sWhite := 'white point E';
    JXL_WHITE_POINT_DCI:
      sWhite := 'DCI white point';
  else
    sWhite := 'custom white point';
  end;

  var sTransfer := '';

  case rEncoding.transfer_function of
    JXL_TRANSFER_FUNCTION_709:
      sTransfer := 'BT.709 transfer';
    JXL_TRANSFER_FUNCTION_LINEAR:
      sTransfer := 'linear';
    JXL_TRANSFER_FUNCTION_SRGB:
      sTransfer := 'sRGB transfer';
    JXL_TRANSFER_FUNCTION_PQ:
      sTransfer := 'PQ transfer';
    JXL_TRANSFER_FUNCTION_DCI:
      sTransfer := 'DCI transfer';
    JXL_TRANSFER_FUNCTION_HLG:
      sTransfer := 'HLG transfer';
    JXL_TRANSFER_FUNCTION_GAMMA:
      sTransfer := Format( 'gamma %.3f', [ rEncoding.gamma ] );
  else
    sTransfer := 'unknown transfer';
  end;

  Result := Format( '%s: %s%s, %s', [ sSpace, sPrimaries, sWhite, sTransfer ] );

end;

/// <summary>Formats the result line of a successful validation.</summary>
/// <param name="AName">Name of the file validated.</param>
/// <param name="AInfo">What <c>JxlValidate</c> returned.</param>
/// <param name="AMilliseconds">How long the validation took.</param>
/// <param name="ATimed">What the time covers, e.g. <c>in memory</c>.</param>
/// <returns>The line.</returns>
function FormatValidation( const AName: string; const AInfo: TJxlInfo; AMilliseconds: Int64; const ATimed: string ): string;
begin

  Result := Format( 'Validated %s: %d frame(s) decoded in full in %d ms (%s); %d x %d, %s, %s%s%s%s.', [ AName,
    AInfo.DecodedFrameCount, AMilliseconds, ATimed, AInfo.DisplayWidth, AInfo.DisplayHeight, FormatBits( AInfo ),
    if AInfo.XybEncoded then 'XYB' else 'original colour space', if ( AInfo.AlphaBits > 0 ) then ', alpha' else '',
    if AInfo.HasContainer then ', container' else '', if AInfo.HasJpegReconstruction then ', JPEG reconstruction data' else '' ] );

end;

/// <summary>
///   Validates JPEG XL data already written to a file and adds the outcome to the results; runs on the worker thread.
///   A cancelled validation leaves the file, which was written in full, and says so.
/// </summary>
/// <param name="AName">Name of the file the data was written to.</param>
/// <param name="AData">The complete file.</param>
/// <param name="AResults">Receives the result line.</param>
/// <param name="ACancellation">The job's token.</param>
/// <exception cref="EJxlCancelled">The job was cancelled.</exception>
procedure ValidateData( const AName: string; const AData: TBytes; AResults: TStrings; ACancellation: TJxlCancellation );
begin

  var rTimer := TStopwatch.StartNew;

  try
    var rInfo := JxlValidate( AData, JxlGetDefaultLimits, ACancellation );
    rTimer.Stop;
    AResults.Add( FormatValidation( AName, rInfo, rTimer.ElapsedMilliseconds, 'in memory' ) );
  except
    on EJxlCancelled do
    begin
      AResults.Add( Format( 'Validation of %s cancelled; the file was written in full, but not validated.', [ AName ] ) );
      raise;
    end;
    // A file that does not validate is the outcome being reported, not a failure of the operation that wrote it.
    on E: EJxlError do AResults.Add( Format( 'Validation FAILED for %s: %s', [ AName, DescribeFailure( E ) ] ) );
  end;

end;

/// <summary>
///   Validates a file on disk and adds the outcome to the results; a file without a JPEG XL signature is reported as
///   such without calling libjxl. Runs on the worker thread.
/// </summary>
/// <param name="AFileName">Full path of the file.</param>
/// <param name="AResults">Receives the result line.</param>
/// <param name="ACancellation">The job's token.</param>
/// <exception cref="EFileStreamError">The file cannot be opened.</exception>
/// <exception cref="EJxlCancelled">The job was cancelled.</exception>
procedure ValidateFileOnDisk( const AFileName: string; AResults: TStrings; ACancellation: TJxlCancellation );
var
  oStream: TFileStream;
begin

  var sName := ExtractFileName( AFileName );
  var naHead: TBytes;
  oStream := TFileStream.Create( AFileName, fmOpenRead or fmShareDenyWrite );

  try
    SetLength( naHead, Min( 12, oStream.Size ) );
    oStream.ReadBuffer( naHead, Length( naHead ) );
  finally
    oStream.Free;
  end;

  if ( not JxlHasSignature( naHead ) ) then
  begin
    AResults.Add( Format( '%s is not a JPEG XL file (it does not start with a JPEG XL signature); nothing to validate.', [ sName ] ) );
    Exit;
  end;

  var rTimer := TStopwatch.StartNew;

  try
    var rInfo := JxlValidate( AFileName, ACancellation );
    rTimer.Stop;
    AResults.Add( FormatValidation( sName, rInfo, rTimer.ElapsedMilliseconds, 'including reading the file' ) );
  except
    on EJxlCancelled do raise;
    on E: EJxlError do AResults.Add( Format( 'Validation FAILED for %s: %s', [ sName, DescribeFailure( E ) ] ) );
  end;

end;

/// <summary>Checks that a file can be written, without changing it: an existing file is opened for writing, a new one created and deleted.</summary>
/// <param name="AFileName">Full path of the file.</param>
/// <param name="AReason">Receives why it cannot be written, or empty.</param>
/// <returns><c>True</c> when the file can be written.</returns>
function CanWriteFile( const AFileName: string; out AReason: string ): Boolean;
begin

  AReason := '';

  try
    if TFile.Exists( AFileName ) then
      TFileStream.Create( AFileName, fmOpenReadWrite or fmShareDenyWrite ).Free
    else
    begin
      TFileStream.Create( AFileName, fmCreate ).Free;
      TFile.Delete( AFileName );
    end;
  except
    on E: EFileStreamError do AReason := E.Message;
    on E: EInOutError do AReason := E.Message;
  end;

  Result := ( AReason = '' );

end;

/// <summary>Returns why a chosen save target is unacceptable.</summary>
/// <param name="AFileName">Full path of the target.</param>
/// <param name="AExtensions">Extensions the target must have, with the dot.</param>
/// <param name="AProtected">Paths the target must not be; empty entries are ignored.</param>
/// <returns>The reason, or empty when the target is acceptable.</returns>
function SaveTargetProblem( const AFileName: string; const AExtensions: array of string; const AProtected: array of string ): string;
begin

  if ( not HasExtension( AFileName, AExtensions ) ) then
    Exit( Format( 'The file name must end in %s.', [ string.Join( ' or ', AExtensions ) ] ) );

  for var sProtected in AProtected do
    if SamePath( AFileName, sProtected ) then
      Exit( Format( '%s is a file this command reads or compares with. Choose another name, so that it is not overwritten.',
        [ ExtractFileName( AFileName ) ] ) );

  var sReason: string;

  if ( not CanWriteFile( AFileName, sReason ) ) then Exit( Format( '%s cannot be written: %s', [ ExtractFileName( AFileName ), sReason ] ) );

  Result := '';

end;

/// <summary>Reports whether a graphic can show through to its background.</summary>
/// <param name="AGraphic">The graphic.</param>
/// <returns><c>True</c> for a bitmap with alpha and for any graphic that declares itself transparent.</returns>
function HasTransparency( AGraphic: TGraphic ): Boolean;
begin

  Result := AGraphic.Transparent;

  if ( AGraphic is TBitmap ) then
    Result := Result or ( ( TBitmap( AGraphic ).PixelFormat = pf32bit ) and ( TBitmap( AGraphic ).AlphaFormat <> afIgnored ) );

end;

{ TJxlJob }

constructor TJxlJob.Create( const AWork: TProc<TStrings, TJxlCancellation>; const AFailurePrefix: string );
begin

  inherited Create( True );
  FreeOnTerminate := False;
  FWork           := AWork;
  FFailurePrefix  := AFailurePrefix;
  FResults        := TStringList.Create;
  FCancellation   := TJxlCancellation.Create;

end;

destructor TJxlJob.Destroy;
begin

  // inherited Destroy waits for Execute to end, so the work no longer uses the token when it is freed.
  inherited Destroy;
  FResults.Free;
  FCancellation.Free;

end;

procedure TJxlJob.Execute;
begin

  NameThreadForDebugging( 'JxlViewer job' );

  try
    FWork( FResults, FCancellation );
    FSucceeded := True;
  except
    // The thread boundary: whatever the work raised is reported on the UI thread instead of dying with the thread.
    on EJxlCancelled do FResults.Add( 'Cancelled.' );
    on E: Exception do FResults.Add( FFailurePrefix + ': ' + DescribeFailure( E ) );
  end;

end;

{ TMainForm }

procedure TMainForm.FormCreate( Sender: TObject );
begin

  FPicture := TPicture.Create;

  try
    JxlCheckLibrary;
    FLibraryAvailable := True;
  except
    on E: EJxlError do FLibraryError := E.Message;
  end;

  EncodeSettingChange( nil );
  ApplyFit;
  TThread.ForceQueue( nil, StartUp );

end;

procedure TMainForm.FormCloseQuery( Sender: TObject; var CanClose: Boolean );
begin

  if ( not IsBusy ) then Exit;

  // The operation is cancelled, and the window closes itself once it has stopped (JobTerminate), which is soon: the
  // binding stops libjxl at its next unit of work.
  CanClose := False;

  if FCloseRequested then Exit;

  FCloseRequested := True;
  Caption         := Caption + ' (closing)';
  CancelJob( 'Closing: cancelling the current operation' );

end;

procedure TMainForm.FormDestroy( Sender: TObject );
begin

  // Reached with an operation running only when Windows ends the session (FormCloseQuery refuses otherwise). Detach the
  // event first so that nothing runs against the form being destroyed, and cancel the work; Free then waits for the
  // thread.
  if Assigned( FJob ) then
  begin
    FJob.OnTerminate := nil;
    ( FJob as TJxlJob ).Cancellation.Cancel;
    FreeAndNil( FJob );
  end;

  FPicture.Free;

end;

procedure TMainForm.StartUp;
begin

  if FLibraryAvailable then
  begin
    var rLimits := JxlGetDefaultLimits;
    Log( Format( 'libjxl %s loaded (%s).', [ JxlVersionToString( JxlDecoderVersion ),
      if ( JxlLibraryLayout = jllSplitDlls ) then 'jxl.dll with jxl_threads.dll and jxl_cms.dll' else 'one DLL' ] ) );
    Log( Format( 'Limits: %.0n megapixels, %d extra channels, %s input, %s output, %s libjxl memory, %d JPEG scans.',
      [ rLimits.MaxPixels / 1000000, rLimits.MaxExtraChannels, FormatMiB( rLimits.MaxInputBytes ), FormatMiB( rLimits.MaxOutputBytes ),
      FormatMiB( rLimits.MaxMemoryBytes ), rLimits.MaxJpegScans ] ) );
  end
  else
  begin
    Log( 'libjxl is not available: ' + FLibraryError );
    MessageDlg( 'The libjxl DLL could not be loaded, so JPEG XL files cannot be opened or written.' + sLineBreak
      + sLineBreak + FLibraryError + sLineBreak + sLineBreak + 'Put libjxl''s DLLs (jxl.dll, jxl_threads.dll, jxl_cms.dll '
      + 'and the Brotli DLLs from the official release), built for the same platform, next to '
      + ExtractFileName( ParamStr( 0 ) ) + '.', mtWarning, [ mbOK ], 0 );
  end;

  if ( ParamCount = 0 ) then Exit;

  var sFileName := ExpandFileName( ParamStr( 1 ) );

  if ( ParamCount > 1 ) then Log( Format( 'Ignored %d extra command-line argument(s); only the first is opened.', [ ParamCount - 1 ] ) );

  if TFile.Exists( sFileName ) then
    OpenFile( sFileName )
  else
    Log( 'Not found: ' + sFileName );

end;

function TMainForm.IsBusy: Boolean;
begin

  Result := Assigned( FJob );

end;

procedure TMainForm.RunJob( const ADescription: string; const AFailurePrefix: string;
  const AWork: TProc<TStrings, TJxlCancellation>; const AFinish: TProc<Boolean> );
begin

  Log( ADescription + '...' );
  FJobFinish       := AFinish;
  FJob             := TJxlJob.Create( AWork, AFailurePrefix );
  FJob.OnTerminate := JobTerminate;
  Screen.Cursor    := crAppStart;
  FJob.Start;

end;

procedure TMainForm.CancelJob( const AReason: string );
begin

  if ( not IsBusy ) then Exit;

  var oCancellation := ( FJob as TJxlJob ).Cancellation;

  if oCancellation.IsCancelled then Exit;

  oCancellation.Cancel;
  Log( AReason + '...' );

end;

procedure TMainForm.JobTerminate( Sender: TObject );
begin

  // Runs on the UI thread (TThread synchronises OnTerminate) after the work has returned.
  var oJob    := Sender as TJxlJob;
  var pFinish := FJobFinish;
  FJob          := nil;
  FJobFinish    := nil;
  Screen.Cursor := crDefault;

  for var sLine in oJob.Results do Log( sLine );

  if Assigned( pFinish ) then pFinish( oJob.Succeeded );

  // The thread is still inside this event, so it is freed once the event has returned and the thread has ended.
  TThread.ForceQueue( nil,
    procedure
    begin
      oJob.Free;
    end );

  if FCloseRequested then TThread.ForceQueue( nil, Close );

end;

procedure TMainForm.OpenFile( const AFileName: string );
begin

  // Load into a new picture and swap it in only on success, so a file that fails to open leaves the open image intact.
  var sFileName := ExpandFileName( AFileName );
  var oLoaded   := TPicture.Create;
  var rTimer    := TStopwatch.StartNew;

  try
    oLoaded.LoadFromFile( sFileName );
  except
    on E: Exception do
    begin
      oLoaded.Free;
      if ( not IsExpectedFailure( E ) ) then raise;
      var sMessage := Format( 'Could not open %s: %s', [ ExtractFileName( sFileName ), DescribeFailure( E ) ] );
      Log( sMessage );
      MessageDlg( sMessage, mtError, [ mbOK ], 0 );
      Exit;
    end;
  end;

  rTimer.Stop;
  FPicture.Free;
  FPicture  := oLoaded;
  FFileName := sFileName;
  Caption   := 'JPEG XL Viewer - ' + ExtractFileName( sFileName );
  ShowPicture;
  ShowInfo( rTimer.ElapsedMilliseconds );

end;

procedure TMainForm.ShowPicture;
var
  oDisplay: TBitmap;
  oPattern: TBitmap;
begin

  oDisplay := TBitmap.Create;

  try
    oDisplay.PixelFormat := pf24bit;
    oDisplay.SetSize( FPicture.Width, FPicture.Height );

    // A chequerboard behind transparent images only, filled in one call with a two-by-two-square pattern brush.
    if HasTransparency( FPicture.Graphic ) then
    begin
      oPattern := TBitmap.Create;

      try
        oPattern.PixelFormat        := pf24bit;
        oPattern.SetSize( 2 * CHECKER_SIZE, 2 * CHECKER_SIZE );
        oPattern.Canvas.Brush.Color := clWhite;
        oPattern.Canvas.FillRect( Rect( 0, 0, 2 * CHECKER_SIZE, 2 * CHECKER_SIZE ) );
        oPattern.Canvas.Brush.Color := TColor( $CCCCCC );
        oPattern.Canvas.FillRect( Rect( CHECKER_SIZE, 0, 2 * CHECKER_SIZE, CHECKER_SIZE ) );
        oPattern.Canvas.FillRect( Rect( 0, CHECKER_SIZE, CHECKER_SIZE, 2 * CHECKER_SIZE ) );
        oDisplay.Canvas.Brush.Bitmap := oPattern;
        oDisplay.Canvas.FillRect( Rect( 0, 0, oDisplay.Width, oDisplay.Height ) );
        oDisplay.Canvas.Brush.Bitmap := nil;
      finally
        oPattern.Free;
      end;

    end;

    oDisplay.Canvas.Draw( 0, 0, FPicture.Graphic );
    imgView.Picture.Assign( oDisplay );
  finally
    oDisplay.Free;
  end;

  ApplyFit;

end;

procedure TMainForm.ApplyFit;
begin

  if chkFit.Checked then
  begin
    imgView.AutoSize     := False;
    imgView.Align        := alClient;
    imgView.Stretch      := True;
    imgView.Proportional := True;
    imgView.Center       := True;
  end
  else
  begin
    // Back to the origin first: SetBounds is relative to the scrolled view, so a scrolled box would place the image off it.
    sbImage.HorzScrollBar.Position := 0;
    sbImage.VertScrollBar.Position := 0;
    imgView.Align                  := alNone;
    imgView.Stretch                := False;
    imgView.Proportional           := False;
    imgView.Center                 := False;
    imgView.SetBounds( 0, 0, imgView.Picture.Width, imgView.Picture.Height );
    imgView.AutoSize               := True;
  end;

end;

procedure TMainForm.ShowInfo( ALoadMilliseconds: Int64 );
begin

  var sInfoError := '';
  FHasInfo := False;

  if ( FPicture.Graphic is TJxlImage ) then
  begin
    try
      FInfo    := JxlReadInfo( FFileName );
      FHasInfo := True;
    except
      // The pixels decoded but the headers do not check out (e.g. a container box cut short): show what is known.
      on E: EJxlError do sInfoError := DescribeFailure( E );
    end;
  end;

  var oLines := mmoInfo.Lines;
  oLines.BeginUpdate;

  try
    oLines.Clear;
    oLines.Add( 'File: ' + ExtractFileName( FFileName ) );
    oLines.Add( 'Folder: ' + ExtractFileDir( FFileName ) );
    oLines.Add( 'Size: ' + FormatBytes( TFile.GetSize( FFileName ) ) );
    oLines.Add( 'Graphic class: ' + FPicture.Graphic.ClassName );
    oLines.Add( Format( 'Dimensions: %d x %d (as shown)', [ FPicture.Width, FPicture.Height ] ) );
    oLines.Add( Format( 'Load time: %d ms', [ ALoadMilliseconds ] ) );

    if ( FPicture.Graphic is TJxlImage ) then
    begin
      oLines.Add( '' );
      oLines.Add( 'JPEG XL' );

      if ( not FHasInfo ) then
        oLines.Add( 'JPEG XL details unavailable: ' + sInfoError + ' (try Validate)' )
      else
      begin
        oLines.Add( Format( 'Bits per sample: %s', [ FormatBits( FInfo ) ] ) );
        oLines.Add( 'Colour channels: ' + if ( FInfo.ColourChannels = 1 ) then '1 (grey)' else '3 (RGB)' );

        if ( FInfo.AlphaBits = 0 ) then
          oLines.Add( 'Alpha: none' )
        else
          oLines.Add( Format( 'Alpha: %d-bit%s', [ FInfo.AlphaBits, if FInfo.AlphaPremultiplied then ', premultiplied' else '' ] ) );

        oLines.Add( Format( 'Extra channels: %d', [ FInfo.ExtraChannels ] ) );
        oLines.Add( 'Colour encoding: ' + ColourText( FInfo ) );
        oLines.Add( 'Coded in: ' + if FInfo.XybEncoded then 'XYB (lossy)' else 'the original colour space' );
        oLines.Add( Format( 'Stored size: %d x %d', [ FInfo.Width, FInfo.Height ] ) );
        oLines.Add( Format( 'Orientation: %d (shown %s)', [ FInfo.Orientation, OrientationText( FInfo.Orientation ) ] ) );
        oLines.Add( 'Container: ' + if FInfo.HasContainer then 'yes' else 'no (bare codestream)' );
        oLines.Add( 'Preview: ' + if FInfo.HasPreview then 'yes' else 'no' );
        oLines.Add( 'JPEG reconstruction data: ' + if FInfo.HasJpegReconstruction then 'yes' else 'no' );

        if FInfo.IsAnimated then
        begin
          oLines.Add( Format( 'Animation: %d frames, %.2f s, %s', [ FInfo.FrameCount, FInfo.DurationSeconds,
            if ( FInfo.AnimationLoops = 0 ) then 'loops forever' else Format( '%d loop(s)', [ FInfo.AnimationLoops ] ) ] ) );
          oLines.Add( 'Shown: the first frame' );
        end
        else
          oLines.Add( Format( 'Frames: %d', [ FInfo.FrameCount ] ) );

      end;

    end;

  finally
    oLines.EndUpdate;
  end;

  if ( sInfoError <> '' ) then Log( Format( '%s: JPEG XL details unavailable: %s (try Validate)', [ ExtractFileName( FFileName ), sInfoError ] ) );

end;

function TMainForm.EncodeOptions: TJxlEncodeOptions;
begin

  Result          := TJxlEncodeOptions.Default;
  Result.Lossless := chkLossless.Checked;
  Result.Distance := tbDistance.Position / 10;
  Result.Effort   := tbEffort.Position;

end;

procedure TMainForm.PrepareSaveSource( out APixels: TJxlPixels; out AJxlFileName: string; out ARoute: string );
var
  oBitmap: TBitmap;
begin

  var oGraphic := FPicture.Graphic;
  AJxlFileName := '';

  if ( oGraphic is TPngImage ) and JxlTryPngToPixels( TPngImage( oGraphic ), APixels ) then
  begin
    ARoute := 'exact: the PNG''s own 8-bit samples, straight alpha';
    Exit;
  end;

  if ( oGraphic is TJxlImage ) then
  begin
    var sHow := '';

    // Opaque: the bitmap already holds the decoded samples, so no second decode. With alpha: the bitmap's alpha is
    // premultiplied, so the file is decoded again (on the worker thread) for straight samples.
    if FHasInfo and ( FInfo.AlphaBits = 0 ) then
    begin
      APixels := JxlBitmapToPixels( TJxlImage( oGraphic ) );
      sHow    := 'the decoded samples as shown';
    end
    else
    begin
      AJxlFileName := FFileName;
      sHow         := 'the JPEG XL file decoded again, straight alpha';
    end;

    // Exact only for what decoding to 8-bit sRGB reproduces sample for sample: one frame of 8-bit integer samples whose
    // colour encoding is sRGB itself (TJxlInfo.IsSrgb), with no channels beyond colour and alpha.
    var sLosses := '';

    if ( not FHasInfo ) then
      sLosses := 'exactness unknown: the headers could not be read'
    else
    begin
      var arLosses: TArray<string> := [];
      var iAlphaChannels := if ( FInfo.AlphaBits > 0 ) then 1 else 0;

      if ( FInfo.ExponentBitsPerSample > 0 ) then
        arLosses := arLosses + [ 'float samples reduced to 8-bit' ]
      else if ( FInfo.BitsPerSample > 8 ) or ( FInfo.AlphaBits > 8 ) then
        arLosses := arLosses + [ 'reduced to 8-bit' ]
      else if ( FInfo.BitsPerSample < 8 ) then
        arLosses := arLosses + [ Format( 'widened from %d-bit to 8-bit', [ FInfo.BitsPerSample ] ) ];

      if ( not FInfo.IsSrgb ) then arLosses := arLosses + [ 'converted to sRGB' ];

      if ( Integer( FInfo.ExtraChannels ) > iAlphaChannels ) then arLosses := arLosses + [ 'extra channels dropped' ];

      if ( FInfo.FrameCount > 1 ) then arLosses := arLosses + [ 'first frame only' ];

      sLosses := string.Join( ', ', arLosses );
    end;

    ARoute := if ( sLosses = '' ) then 'exact: ' + sHow else Format( 'not exact (%s): %s', [ sLosses, sHow ] );
    Exit;
  end;

  oBitmap := TBitmap.Create;

  try
    // A metafile or an icon has no pixels to copy (assigning it to a bitmap raises EConvertError): draw it instead.
    if ( oGraphic is TMetafile ) or ( oGraphic is TIcon ) then
    begin
      oBitmap.PixelFormat        := pf24bit;
      oBitmap.SetSize( oGraphic.Width, oGraphic.Height );
      oBitmap.Canvas.Brush.Color := clWhite;
      oBitmap.Canvas.FillRect( Rect( 0, 0, oBitmap.Width, oBitmap.Height ) );
      oBitmap.Canvas.Draw( 0, 0, oGraphic );
      ARoute := Format( 'drawn onto a white %d x %d bitmap (%s; transparency is lost)', [ oBitmap.Width, oBitmap.Height,
        oGraphic.ClassName ] );
    end
    else
    begin
      oBitmap.Assign( oGraphic );

      if ( oGraphic is TJPEGImage ) then
        ARoute := 'the decoded JPEG via a VCL bitmap (JPEG -> JXL keeps the JPEG itself instead)'
      else if ( oGraphic is TGIFImage ) and ( TGIFImage( oGraphic ).Images.Count > 1 ) then
        ARoute := 'via a VCL bitmap, first frame only (any alpha premultiplied)'
      else
        ARoute := 'via a VCL bitmap (any alpha premultiplied)';

    end;

    APixels := JxlBitmapToPixels( oBitmap );
  finally
    oBitmap.Free;
  end;

end;

function TMainForm.OriginalJpeg: string;
begin

  if SamePath( FFileName, FLastJxlTarget ) and TFile.Exists( FLastJpegSource ) then Exit( FLastJpegSource );

  for var sExtension in JPEG_EXTENSIONS do
  begin
    var sCandidate := ChangeFileExt( FFileName, sExtension );

    if TFile.Exists( sCandidate ) then Exit( sCandidate );
  end;

  Result := '';

end;

function TMainForm.AskSaveFile( const ATitle: string; const AFilter: string; const ADefaultExt: string;
  const AFileName: string; const AExtensions: array of string; const AProtected: array of string; out AChosen: string ): Boolean;
begin

  Result             := False;
  AChosen            := '';
  dlgSave.Title      := ATitle;
  dlgSave.Filter     := AFilter;
  dlgSave.DefaultExt := ADefaultExt;
  dlgSave.InitialDir := ExtractFileDir( AFileName );
  dlgSave.FileName   := ExtractFileName( AFileName );

  while dlgSave.Execute do
  begin
    var sChosen  := ExpandFileName( dlgSave.FileName );
    var sProblem := SaveTargetProblem( sChosen, AExtensions, AProtected );

    if ( sProblem = '' ) then
    begin
      AChosen := sChosen;
      Exit( True );
    end;

    Log( 'Refused ' + ExtractFileName( sChosen ) + ': ' + sProblem );
    MessageDlg( sProblem, mtWarning, [ mbOK ], 0 );
    dlgSave.InitialDir := ExtractFileDir( sChosen );
    dlgSave.FileName   := ExtractFileName( sChosen );
  end;

end;

procedure TMainForm.Log( const AText: string );
begin

  mmoLog.Lines.Add( AText );

end;

procedure TMainForm.actOpenExecute( Sender: TObject );
begin

  if dlgOpen.Execute then OpenFile( dlgOpen.FileName );

end;

procedure TMainForm.actOpenUpdate( Sender: TObject );
begin

  actOpen.Enabled := ( not IsBusy );

end;

procedure TMainForm.actSaveJxlExecute( Sender: TObject );
begin

  var sTarget: string;

  if ( not AskSaveFile( 'Save as JPEG XL', JXL_FILTER, 'jxl', ChangeFileExt( FFileName, '.saved.jxl' ), [ JXL_EXTENSION ],
    [ FFileName ], sTarget ) ) then Exit;

  var rPixels: TJxlPixels;
  var sJxlSource, sRoute: string;

  try
    PrepareSaveSource( rPixels, sJxlSource, sRoute );
  except
    on E: Exception do
    begin
      if ( not IsExpectedFailure( E ) ) then raise;
      Log( Format( 'Could not prepare %s for saving: %s', [ ExtractFileName( FFileName ), DescribeFailure( E ) ] ) );
      Exit;
    end;
  end;

  // Everything the worker needs is copied now: it must not read the form, and the source is measured before the target is written.
  var rOptions    := EncodeOptions;
  var sSourceName := ExtractFileName( FFileName );
  var iSourceSize := if TFile.Exists( FFileName ) then TFile.GetSize( FFileName ) else Int64( -1 );
  var sTargetName := ExtractFileName( sTarget );

  RunJob( Format( 'Saving %s (effort %d)', [ sTargetName, rOptions.Effort ] ), 'Saving ' + sTargetName + ' failed',
    procedure( AResults: TStrings; ACancellation: TJxlCancellation )
    begin
      var rSource := rPixels;
      var rLimits := JxlGetDefaultLimits;

      if ( sJxlSource <> '' ) then rSource := JxlDecodePixels( TFile.ReadAllBytes( sJxlSource ), jcoSrgb, rLimits, ACancellation );

      // The file is written only once the encode has succeeded, so a cancelled save leaves nothing behind.
      var rTimer := TStopwatch.StartNew;
      var naData := JxlEncodePixels( rSource, rOptions, rLimits, ACancellation );
      rTimer.Stop;
      TFile.WriteAllBytes( sTarget, naData );
      var iSize     := Int64( Length( naData ) );
      var sSettings := if rOptions.Lossless then 'lossless' else Format( 'distance %.1f', [ rOptions.Distance ] );
      AResults.Add( Format( 'Saved %s (%s, effort %d; %s): encoded in %d ms, %s, %s, %.2f bits per pixel.', [ sTargetName,
        sSettings, rOptions.Effort, sRoute, rTimer.ElapsedMilliseconds, FormatBytes( iSize ),
        DescribeComparison( iSize, iSourceSize, sSourceName ), 8 * iSize / ( Int64( rSource.Width ) * rSource.Height ) ] ) );
      ValidateData( sTargetName, naData, AResults, ACancellation );
    end, nil );

end;

procedure TMainForm.actSaveJxlUpdate( Sender: TObject );
begin

  actSaveJxl.Enabled := FLibraryAvailable and ( FFileName <> '' ) and ( not IsBusy );

end;

procedure TMainForm.actJpegToJxlExecute( Sender: TObject );
begin

  var sTarget: string;

  if ( not AskSaveFile( 'Recompress JPEG losslessly as JPEG XL', JXL_FILTER, 'jxl', ChangeFileExt( FFileName, JXL_EXTENSION ),
    [ JXL_EXTENSION ], [ FFileName ], sTarget ) ) then Exit;

  var sSource     := FFileName;
  var sSourceName := ExtractFileName( sSource );
  var sTargetName := ExtractFileName( sTarget );
  var iEffort     := tbEffort.Position;

  // A JPEG libjxl cannot represent (CMYK, unusual sampling) or one over the limits raises EJxlError: the job logs it.
  RunJob( Format( 'Recompressing %s (effort %d)', [ sSourceName, iEffort ] ), sSourceName + ' could not be recompressed',
    procedure( AResults: TStrings; ACancellation: TJxlCancellation )
    begin
      var naJpeg := TFile.ReadAllBytes( sSource );
      var rTimer := TStopwatch.StartNew;
      var naJxl  := JxlTranscodeJpegToJxl( naJpeg, iEffort, JxlGetDefaultLimits, ACancellation );
      rTimer.Stop;
      TFile.WriteAllBytes( sTarget, naJxl );
      AResults.Add( Format( 'Recompressed %s (%s) to %s (%s, %s the JPEG) in %d ms (in memory), reversibly.', [ sSourceName,
        FormatBytes( Length( naJpeg ) ), sTargetName, FormatBytes( Length( naJxl ) ), FormatRatio( Length( naJxl ), Length( naJpeg ) ),
        rTimer.ElapsedMilliseconds ] ) );
      ValidateData( sTargetName, naJxl, AResults, ACancellation );
    end,
    procedure( ASucceeded: Boolean )
    begin
      if ASucceeded then
      begin
        FLastJpegSource := sSource;
        FLastJxlTarget  := sTarget;
      end;
    end );

end;

procedure TMainForm.actJpegToJxlUpdate( Sender: TObject );
begin

  actJpegToJxl.Enabled := FLibraryAvailable and HasExtension( FFileName, JPEG_EXTENSIONS ) and ( not IsBusy );

end;

procedure TMainForm.actJxlToJpegExecute( Sender: TObject );
begin

  // The original to compare with is decided first, so that it (and the open file) can be refused as the target.
  var sOriginal := OriginalJpeg;
  var sTarget: string;

  if ( not AskSaveFile( 'Reconstruct the original JPEG', JPEG_FILTER, 'jpg', ChangeFileExt( FFileName, '.reconstructed.jpg' ),
    JPEG_EXTENSIONS, [ FFileName, sOriginal, FLastJpegSource ], sTarget ) ) then Exit;

  var sSource     := FFileName;
  var sSourceName := ExtractFileName( sSource );
  var sTargetName := ExtractFileName( sTarget );
  var bNoJpegData := FHasInfo and ( not FInfo.HasJpegReconstruction );

  RunJob( 'Reconstructing ' + sTargetName, 'Reconstruction from ' + sSourceName + ' failed',
    procedure( AResults: TStrings; ACancellation: TJxlCancellation )
    begin
      var naJxl := TFile.ReadAllBytes( sSource );
      var naJpeg: TBytes;

      try
        naJpeg := JxlReconstructJpeg( naJxl, JxlGetDefaultLimits, ACancellation );
      except
        on EJxlCancelled do raise;
        on E: EJxlError do
        begin
          if bNoJpegData then
            AResults.Add( Format( '%s holds no JPEG to reconstruct (it was not made by lossless JPEG recompression): %s',
              [ sSourceName, E.Message ] ) )
          else
            AResults.Add( Format( 'Reconstruction from %s failed: %s', [ sSourceName, DescribeFailure( E ) ] ) );
          Exit;
        end;
      end;

      TFile.WriteAllBytes( sTarget, naJpeg );
      AResults.Add( Format( 'Reconstructed %s (%s) from %s (%s).', [ sTargetName, FormatBytes( Length( naJpeg ) ), sSourceName,
        FormatBytes( Length( naJxl ) ) ] ) );

      if ( sOriginal = '' ) then
      begin
        AResults.Add( 'No original JPEG known to compare with.' );
        Exit;
      end;

      var iDifference := FirstDifference( TFile.ReadAllBytes( sOriginal ), naJpeg );

      if ( iDifference < 0 ) then
        AResults.Add( Format( 'Byte-identical to the original %s.', [ ExtractFileName( sOriginal ) ] ) )
      else
        AResults.Add( Format( 'DIFFERS from the original %s, first at byte %d.', [ ExtractFileName( sOriginal ), iDifference ] ) );

    end, nil );

end;

procedure TMainForm.actJxlToJpegUpdate( Sender: TObject );
begin

  ( Sender as TAction ).Enabled := FLibraryAvailable and HasExtension( FFileName, [ JXL_EXTENSION ] ) and ( not IsBusy );

end;

procedure TMainForm.actValidateExecute( Sender: TObject );
begin

  RunValidation( FFileName );

end;

procedure TMainForm.actValidateFileExecute( Sender: TObject );
begin

  if dlgValidate.Execute then RunValidation( ExpandFileName( dlgValidate.FileName ) );

end;

procedure TMainForm.actValidateFileUpdate( Sender: TObject );
begin

  actValidateFile.Enabled := FLibraryAvailable and ( not IsBusy );

end;

procedure TMainForm.RunValidation( const AFileName: string );
begin

  var sFileName := AFileName;
  var sName     := ExtractFileName( AFileName );

  RunJob( 'Validating ' + sName, 'Validation of ' + sName + ' could not run',
    procedure( AResults: TStrings; ACancellation: TJxlCancellation )
    begin
      ValidateFileOnDisk( sFileName, AResults, ACancellation );
    end, nil );

end;

procedure TMainForm.actCancelExecute( Sender: TObject );
begin

  CancelJob( 'Cancelling' );

end;

procedure TMainForm.actCancelUpdate( Sender: TObject );
begin

  actCancel.Enabled := IsBusy and ( not ( FJob as TJxlJob ).Cancellation.IsCancelled );

end;

procedure TMainForm.chkFitClick( Sender: TObject );
begin

  ApplyFit;

end;

procedure TMainForm.chkLosslessClick( Sender: TObject );
begin

  EncodeSettingChange( Sender );

end;

procedure TMainForm.EncodeSettingChange( Sender: TObject );
begin

  tbDistance.Enabled  := ( not chkLossless.Checked );
  lblDistance.Enabled := tbDistance.Enabled;
  lblDistance.Caption := Format( 'Distance (lossy quality): %.1f', [ tbDistance.Position / 10 ] );
  lblEffort.Caption   := Format( 'Effort: %d', [ tbEffort.Position ] );

end;

end.
