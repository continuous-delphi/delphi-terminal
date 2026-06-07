program Delphi.Terminal.VCLDemo;

uses
  Vcl.Forms,
  Form.Main in 'Form.Main.pas' {frmMain},
  Delphi.Terminal.Frame.CmdShell in '..\..\source\Delphi.Terminal.Frame.CmdShell.pas' {frameCmdShell: TFrame},
  Delphi.Terminal.Settings in '..\..\source\Delphi.Terminal.Settings.pas',
  Delphi.Terminal.AnsiParser in '..\..\source\Delphi.Terminal.AnsiParser.pas',
  Delphi.Terminal.CmdShell in '..\..\source\Delphi.Terminal.CmdShell.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
