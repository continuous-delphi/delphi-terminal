unit Form.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  radIDETerminal.Frame.CmdShell;

type
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
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ExeDir: string;
begin
  ExeDir := ExtractFilePath(Application.ExeName);

  FFrameCmdShell := TframeCmdShell.Create(Self);
  FFrameCmdShell.Name := 'CMDFrame';
  FFrameCmdShell.Parent := tabCmdShell;
  FFrameCmdShell.Align := alClient;
  FFrameCmdShell.StartShell('cmd.exe', ExeDir);

  FFramePwsh := TframeCmdShell.Create(Self);
  FFramePwsh.Name := 'PWSHFrame';
  FFramePwsh.Parent := tabPwsh;
  FFramePwsh.Align := alClient;
  FFramePwsh.StartShell('pwsh.exe', ExeDir);

  FFramePowerShell := TframeCmdShell.Create(Self);
  FFramePowerShell.Name := 'PowerShellFrame';
  FFramePowerShell.Parent := tabPowerShell;
  FFramePowerShell.Align := alClient;
  FFramePowerShell.StartShell('powershell.exe', ExeDir);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FFramePowerShell.StopShell;
  FFramePwsh.StopShell;
  FFrameCmdShell.StopShell;
end;

end.
