unit Form.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  radIDETerminal.Frame.CmdShell;

type
  TfrmMain = class(TForm)
    PageControl1: TPageControl;
    tabCmdShell: TTabSheet;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FFrameCmdShell: TframeCmdShell;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FFrameCmdShell := TframeCmdShell.Create(Self);
  FFrameCmdShell.Parent := tabCmdShell;
  FFrameCmdShell.Align := alClient;
  FFrameCmdShell.StartShell(ExtractFilePath(Application.ExeName));
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FFrameCmdShell.StopShell;
end;

end.
