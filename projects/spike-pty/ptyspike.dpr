program ptyspike;

uses
  Vcl.Forms,
  pty.MainForm in 'pty.MainForm.pas' {Form8},
  WinAPI.ConPty in '..\..\source\WinAPI.ConPty.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm8, Form8);
  Application.Run;
end.
