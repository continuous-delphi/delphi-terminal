(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Form.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  radTerminal.Frame.CmdShell;

type

  // Mainly for initial dev and ongoing debug purposes
  TfrmMain = class(TForm)
    PageControl1: TPageControl;
    tabCmdShell: TTabSheet;
    tabPwsh: TTabSheet;
    tabPowerShell: TTabSheet;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FFrameCmdShell: TframeCmdShell;
    FFramePwsh: TframeCmdShell;
    FFramePowerShell: TframeCmdShell;
    procedure HandleRequestDir(Sender: TObject; var APath: string);
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Vcl.FileCtrl;

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ExeDir: string;
begin
  ReportMemoryLeaksOnShutdown := True;

  ExeDir := ExtractFilePath(Application.ExeName);

  FFrameCmdShell := TframeCmdShell.Create(Self);
  FFrameCmdShell.Name := 'CMDFrame';
  FFrameCmdShell.Parent := tabCmdShell;
  FFrameCmdShell.Align := alClient;
  FFrameCmdShell.OnRequestProjectDir := HandleRequestDir;
  FFrameCmdShell.OnRequestFileDir := HandleRequestDir;
  FFrameCmdShell.StartShell('cmd.exe', ExeDir);

  FFramePwsh := TframeCmdShell.Create(Self);
  FFramePwsh.Name := 'PWSHFrame';
  FFramePwsh.Parent := tabPwsh;
  FFramePwsh.Align := alClient;
  FFramePwsh.OnRequestProjectDir := HandleRequestDir;
  FFramePwsh.OnRequestFileDir := HandleRequestDir;
  FFramePwsh.StartShell('pwsh.exe', ExeDir);

  FFramePowerShell := TframeCmdShell.Create(Self);
  FFramePowerShell.Name := 'PowerShellFrame';
  FFramePowerShell.Parent := tabPowerShell;
  FFramePowerShell.Align := alClient;
  FFramePowerShell.OnRequestProjectDir := HandleRequestDir;
  FFramePowerShell.OnRequestFileDir := HandleRequestDir;
  FFramePowerShell.StartShell('powershell.exe', ExeDir);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FFramePowerShell.StopShell;
  FFramePwsh.StopShell;
  FFrameCmdShell.StopShell;
end;

procedure TfrmMain.HandleRequestDir(Sender: TObject; var APath: string);
var
  Dir: string;
begin
  Dir := '';
  if SelectDirectory('Select Directory', '', Dir) then
    APath := Dir;
end;

end.
