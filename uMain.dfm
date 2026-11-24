object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'NoneBorderShadowStyle Demo (Delphi 11.3)'
  ClientHeight = 400
  ClientWidth = 660
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTitle: TPanel
    Left = 0
    Top = 0
    Width = 660
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    Caption = ''
    Color = clWhite
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentBackground = False
    ParentFont = False
    TabOrder = 0
    OnMouseDown = pnlTitleMouseDown
    OnMouseMove = pnlTitleMouseMove
    OnMouseUp = pnlTitleMouseUp
    object lblTitle: TLabel
      Left = 20
      Top = 15
      Width = 320
      Height = 20
      Caption = 'Borderless rounded window with soft shadow'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clMaroon
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      OnMouseDown = pnlTitleMouseDown
      OnMouseMove = pnlTitleMouseMove
      OnMouseUp = pnlTitleMouseUp
    end
  end
  object pnlContent: TPanel
    Left = 0
    Top = 48
    Width = 660
    Height = 352
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clWhite
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentBackground = False
    ParentFont = False
    TabOrder = 1
    object lblIntro: TLabel
      Left = 30
      Top = 26
      Width = 600
      Height = 62
      AutoSize = False
      Caption = 'This window is subclassed by TNoneBorderShadowStyle.' + #13#10 +
        'WM_NCCALCSIZE removes the native title bar; a layered TShadowForm' + #13#10 +
        'paints the rounded soft shadow around the window.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
    object btnShadow: TButton
      Left = 30
      Top = 120
      Width = 150
      Height = 32
      Caption = 'Disable shadow'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = btnShadowClick
    end
    object chkNoBorder: TCheckBox
      Left = 30
      Top = 170
      Width = 320
      Height = 20
      Caption = 'EnabledNoBorder (toggle borderless mode)'
      Checked = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = chkNoBorderClick
    end
    object lblHint: TLabel
      Left = 30
      Top = 215
      Width = 600
      Height = 40
      AutoSize = False
      Caption = 'The three GDI+ caption buttons show custom hints on hover. Drag the white title bar or resize the window.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
  end
end
