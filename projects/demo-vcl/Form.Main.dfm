object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'radIDETerminal Demo'
  ClientHeight = 600
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 800
    Height = 600
    ActivePage = tabCmdShell
    Align = alClient
    TabOrder = 0
    object tabCmdShell: TTabSheet
      Caption = 'CMD Shell'
    end
    object tabPwsh: TTabSheet
      Caption = 'pwsh'
      ImageIndex = 1
    end
    object tabPowerShell: TTabSheet
      Caption = 'PowerShell'
      ImageIndex = 2
    end
  end
end
