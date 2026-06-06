program radTerminalDemo;

uses
  Vcl.Forms,
  Form.Main in 'Form.Main.pas' {frmMain},
  radTerminal.Frame.CmdShell in '..\..\source\radTerminal.Frame.CmdShell.pas' {frameCmdShell: TFrame},
  radTerminal.CmdShell in '..\..\source\radTerminal.CmdShell.pas',
  radTerminal.Info in '..\..\source\radTerminal.Info.pas',
  radTerminal.AnsiParser in '..\..\source\radTerminal.AnsiParser.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
