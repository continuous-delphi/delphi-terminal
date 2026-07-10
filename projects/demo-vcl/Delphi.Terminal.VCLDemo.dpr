program Delphi.Terminal.VCLDemo;

uses
  Vcl.Forms,
  Form.Main in 'Form.Main.pas' {frmMain},
  Profile.Commands in 'Profile.Commands.pas',
  Delphi.Terminal.Frame.CmdShell in '..\..\source\Delphi.Terminal.Frame.CmdShell.pas' {frameCmdShell: TFrame},
  Delphi.Terminal.Settings in '..\..\source\Delphi.Terminal.Settings.pas',
  Delphi.Terminal.AnsiParser in '..\..\source\Delphi.Terminal.AnsiParser.pas',
  Delphi.Terminal.CmdShell in '..\..\source\Delphi.Terminal.CmdShell.pas',
  Delphi.Terminal.CommandHistory in '..\..\source\Delphi.Terminal.CommandHistory.pas';

{$R *.res}
// Embed the shared delphi-terminal version resource so the profiler CSV is
// keyed by the real (auto-bumped) version instead of 0.0.0.0.
{$R '..\ide-plugin\Delphi.Terminal.Version.res'}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
