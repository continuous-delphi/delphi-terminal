object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'radIDETerminal Demo'
  ClientHeight = 600
  ClientWidth = 800
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
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
  end
end
