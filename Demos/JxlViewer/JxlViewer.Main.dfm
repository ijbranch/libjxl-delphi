object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'JPEG XL Viewer'
  ClientHeight = 780
  ClientWidth = 1240
  Color = clBtnFace
  Constraints.MinHeight = 600
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  ShowHint = True
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlButtons: TGridPanel
    Left = 0
    Top = 0
    Width = 1240
    Height = 42
    Align = alTop
    BevelOuter = bvNone
    ColumnCollection = <
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end
      item
        Value = 14.285714285714290000
      end>
    ControlCollection = <
      item
        Column = 0
        Control = btnOpen
        Row = 0
      end
      item
        Column = 1
        Control = btnSaveJxl
        Row = 0
      end
      item
        Column = 2
        Control = btnJpegToJxl
        Row = 0
      end
      item
        Column = 3
        Control = btnJxlToJpeg
        Row = 0
      end
      item
        Column = 4
        Control = btnValidate
        Row = 0
      end
      item
        Column = 5
        Control = btnValidateFile
        Row = 0
      end
      item
        Column = 6
        Control = btnCancel
        Row = 0
      end>
    RowCollection = <
      item
        Value = 100.000000000000000000
      end>
    TabOrder = 0
    object btnOpen: TBitBtn
      AlignWithMargins = True
      Left = 5
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actOpen
      Align = alClient
      TabOrder = 0
    end
    object btnSaveJxl: TBitBtn
      AlignWithMargins = True
      Left = 182
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actSaveJxl
      Align = alClient
      TabOrder = 1
    end
    object btnJpegToJxl: TBitBtn
      AlignWithMargins = True
      Left = 359
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actJpegToJxl
      Align = alClient
      TabOrder = 2
    end
    object btnJxlToJpeg: TBitBtn
      AlignWithMargins = True
      Left = 536
      Top = 5
      Width = 168
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actJxlToJpeg
      Align = alClient
      TabOrder = 3
    end
    object btnValidate: TBitBtn
      AlignWithMargins = True
      Left = 714
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actValidate
      Align = alClient
      TabOrder = 4
    end
    object btnValidateFile: TBitBtn
      AlignWithMargins = True
      Left = 891
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actValidateFile
      Align = alClient
      TabOrder = 5
    end
    object btnCancel: TBitBtn
      AlignWithMargins = True
      Left = 1068
      Top = 5
      Width = 167
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Action = actCancel
      Align = alClient
      TabOrder = 6
    end
  end
  object pnlSide: TPanel
    Left = 920
    Top = 42
    Width = 320
    Height = 738
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 2
    object grpView: TGroupBox
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 314
      Height = 50
      Align = alTop
      Caption = 'View'
      TabOrder = 0
      object chkFit: TCheckBox
        Left = 12
        Top = 22
        Width = 290
        Height = 17
        Caption = 'Fit to window (keep proportions)'
        Checked = True
        State = cbChecked
        TabOrder = 0
        OnClick = chkFitClick
      end
    end
    object grpEncode: TGroupBox
      AlignWithMargins = True
      Left = 3
      Top = 59
      Width = 314
      Height = 170
      Align = alTop
      Caption = 'JPEG XL encoding'
      TabOrder = 1
      object lblDistance: TLabel
        Left = 12
        Top = 50
        Width = 150
        Height = 15
        Caption = 'Distance (lossy quality): 1.0'
      end
      object lblEffort: TLabel
        Left = 12
        Top = 108
        Width = 47
        Height = 15
        Caption = 'Effort: 7'
      end
      object chkLossless: TCheckBox
        Left = 12
        Top = 24
        Width = 290
        Height = 17
        Caption = 'Lossless'
        TabOrder = 0
        OnClick = chkLosslessClick
      end
      object tbDistance: TTrackBar
        Left = 6
        Top = 68
        Width = 300
        Height = 32
        Max = 150
        Min = 1
        Frequency = 10
        Position = 10
        TabOrder = 1
        OnChange = EncodeSettingChange
      end
      object tbEffort: TTrackBar
        Left = 6
        Top = 126
        Width = 300
        Height = 32
        Max = 10
        Min = 1
        Position = 7
        TabOrder = 2
        OnChange = EncodeSettingChange
      end
    end
    object grpInfo: TGroupBox
      AlignWithMargins = True
      Left = 3
      Top = 235
      Width = 314
      Height = 344
      Align = alClient
      Caption = 'Image'
      TabOrder = 2
      object mmoInfo: TMemo
        AlignWithMargins = True
        Left = 5
        Top = 20
        Width = 304
        Height = 319
        Align = alClient
        BorderStyle = bsNone
        Color = clBtnFace
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object grpLog: TGroupBox
      AlignWithMargins = True
      Left = 3
      Top = 585
      Width = 314
      Height = 150
      Align = alBottom
      Caption = 'Results'
      TabOrder = 3
      object mmoLog: TMemo
        AlignWithMargins = True
        Left = 5
        Top = 20
        Width = 304
        Height = 125
        Align = alClient
        BorderStyle = bsNone
        Color = clBtnFace
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
  end
  object sbImage: TScrollBox
    Left = 0
    Top = 42
    Width = 920
    Height = 738
    Align = alClient
    Color = clAppWorkSpace
    ParentColor = False
    TabOrder = 1
    object imgView: TImage
      Left = 0
      Top = 0
      Width = 916
      Height = 734
      Align = alClient
      Center = True
      Proportional = True
      Stretch = True
    end
  end
  object alMain: TActionList
    Left = 48
    Top = 96
    object actOpen: TAction
      Caption = '&Open...'
      Hint = 'Open an image file: JPEG XL, PNG, JPEG, BMP, GIF, icon or metafile'
      ShortCut = 16463
      OnExecute = actOpenExecute
      OnUpdate = actOpenUpdate
    end
    object actSaveJxl: TAction
      Caption = '&Save as JXL...'
      Hint = 'Save the image as JPEG XL with the Lossless, Distance and Effort settings'
      ShortCut = 16467
      OnExecute = actSaveJxlExecute
      OnUpdate = actSaveJxlUpdate
    end
    object actJpegToJxl: TAction
      Caption = '&JPEG '#8594' JXL...'
      Hint = 'Recompress the JPEG losslessly to JPEG XL (byte-exact reconstruction possible)'
      OnExecute = actJpegToJxlExecute
      OnUpdate = actJpegToJxlUpdate
    end
    object actJxlToJpeg: TAction
      Caption = 'JXL '#8594' JPEG (&R)...'
      Hint = 'Reconstruct the original JPEG, byte for byte, from a JPEG XL file made by lossless recompression'
      OnExecute = actJxlToJpegExecute
      OnUpdate = actJxlToJpegUpdate
    end
    object actValidate: TAction
      Caption = '&Validate'
      Hint = 'Validate the open JPEG XL file: decode every frame completely to check it'
      OnExecute = actValidateExecute
      OnUpdate = actJxlToJpegUpdate
    end
    object actValidateFile: TAction
      Caption = 'Validate &file...'
      Hint = 'Check any JPEG XL file completely without opening it (works on files that fail to open)'
      OnExecute = actValidateFileExecute
      OnUpdate = actValidateFileUpdate
    end
    object actCancel: TAction
      Caption = '&Cancel'
      Hint = 'Cancel the running operation (Esc)'
      ShortCut = 27
      OnExecute = actCancelExecute
      OnUpdate = actCancelUpdate
    end
  end
  object dlgOpen: TOpenPictureDialog
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Title = 'Open an image'
    Left = 128
    Top = 96
  end
  object dlgValidate: TOpenDialog
    Filter = 'JPEG XL (*.jxl)|*.jxl|All files (*.*)|*.*'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Title = 'Validate a JPEG XL file'
    Left = 288
    Top = 96
  end
  object dlgSave: TSaveDialog
    Options = [ofOverwritePrompt, ofHideReadOnly, ofNoReadOnlyReturn, ofPathMustExist, ofEnableSizing]
    Left = 208
    Top = 96
  end
end
