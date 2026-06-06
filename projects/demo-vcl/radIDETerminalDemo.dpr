program radIDETerminalDemo;

uses
  Vcl.Forms,
  Form.Main in 'Form.Main.pas' {frmMain},
  radIDETerminal.Frame.CmdShell in '..\..\source\radIDETerminal.Frame.CmdShell.pas' {frameCmdShell: TFrame},
  radIDETerminal.CmdShell in '..\..\source\radIDETerminal.CmdShell.pas',
  radIDETerminal.Info in '..\..\source\radIDETerminal.Info.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
