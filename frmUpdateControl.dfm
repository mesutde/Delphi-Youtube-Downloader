object frmUpdate: TfrmUpdate
  Left = 0
  Top = 0
  Caption = 'G'#252'ncelleme Ekran'#305
  ClientHeight = 353
  ClientWidth = 497
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 497
    Height = 353
    Align = alClient
    TabOrder = 0
    object pnlUpdateButton: TPanel
      Left = 1
      Top = 296
      Width = 495
      Height = 56
      Align = alBottom
      TabOrder = 0
      object btnUpdateControl: TButton
        Left = 1
        Top = 1
        Width = 224
        Height = 54
        Align = alLeft
        Caption = 'Update Conteol'
        TabOrder = 0
        OnClick = btnUpdateControlClick
      end
      object btnUpdate: TButton
        Left = 231
        Top = 1
        Width = 263
        Height = 54
        Align = alRight
        Caption = 'Last Version Update'
        TabOrder = 1
        OnClick = btnUpdateClick
      end
    end
    object grpUpdate: TGroupBox
      Left = 16
      Top = 16
      Width = 465
      Height = 257
      Caption = ' YTDLP.exe G'#252'ncelleme'
      TabOrder = 1
      object lblLocalYtdlp: TLabel
        Left = 24
        Top = 40
        Width = 32
        Height = 28
        Caption = '----'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -20
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblUpdateYtdlp: TLabel
        Left = 24
        Top = 83
        Width = 32
        Height = 28
        Caption = '----'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -20
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lnkYTDLPCurrentDownloadUrl: TLinkLabel
        Left = 3
        Top = 222
        Width = 19
        Height = 19
        Caption = '---'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
      end
    end
  end
end
