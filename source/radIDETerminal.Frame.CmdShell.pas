unit radIDETerminal.Frame.CmdShell;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls,
  radIDETerminal.CmdShell, radIDETerminal.CommandHistory;

type
  TframeCmdShell = class(TFrame)
  private
    FMemoOutput: TMemo;
    FPanelInput: TPanel;
    FEditInput: TEdit;
    FCmdShell: TCmdShellProcess;
    FHistory: TCommandHistory;
    procedure HandleOutput(Sender: TObject; const AText: string);
    procedure HandleInputKeyPress(Sender: TObject; var Key: Char);
    procedure HandleInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure BuildControls;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartShell(const AShellExe: string; const AWorkDir: string = '');
    procedure StopShell;
  end;

implementation

{$R *.dfm}

constructor TframeCmdShell.Create(AOwner: TComponent);
begin
  inherited;
  BuildControls;
  FHistory := TCommandHistory.Create;
  FCmdShell := TCmdShellProcess.Create;
  FCmdShell.OnOutput := HandleOutput;
end;

destructor TframeCmdShell.Destroy;
begin
  FCmdShell.Free;
  FHistory.Free;
  inherited;
end;

procedure TframeCmdShell.BuildControls;
begin
  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := Self;
  FPanelInput.Align := alBottom;
  FPanelInput.Height := 30;
  FPanelInput.Padding.top := 5;  //nudge the command down a little
  FPanelInput.BevelOuter := bvNone;
  FPanelInput.Caption := '';
  FPanelInput.Color := clBlack;
  FPanelInput.ParentBackground := False;

  FEditInput := TEdit.Create(Self);
  FEditInput.Parent := FPanelInput;
  FEditInput.Align := alClient;
  FEditInput.Font.Name := 'Consolas';
  FEditInput.Font.Size := 11;
  FEditInput.Font.Color := clLime;
  FEditInput.Color := clBlack;
  FEditInput.OnKeyPress := HandleInputKeyPress;
  FEditInput.OnKeyDown := HandleInputKeyDown;
  FEditInput.BorderStyle := bsNone;

  FMemoOutput := TMemo.Create(Self);
  FMemoOutput.Parent := Self;
  FMemoOutput.Align := alClient;
  FMemoOutput.Font.Name := 'Consolas';
  FMemoOutput.Font.Size := 10;
  FMemoOutput.Font.Color := clLime;
  FMemoOutput.Color := clBlack;
  FMemoOutput.ReadOnly := True;
  FMemoOutput.ScrollBars := ssBoth;
  FMemoOutput.WordWrap := False;
  FMemoOutput.WantReturns := False;
end;

procedure TframeCmdShell.HandleOutput(Sender: TObject; const AText: string);
begin
  FMemoOutput.Perform(EM_SETSEL, WPARAM(-1), LPARAM(-1));
  FMemoOutput.Perform(EM_REPLACESEL, 0, LPARAM(PChar(AText)));
  FMemoOutput.Perform(EM_SCROLLCARET, 0, 0);
end;

procedure TframeCmdShell.HandleInputKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    FHistory.Add(FEditInput.Text);
    FHistory.ResetPosition;
    FCmdShell.SendCommand(FEditInput.Text);
    FEditInput.Clear;
  end;
end;

procedure TframeCmdShell.HandleInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_UP then
  begin
    FEditInput.Text := FHistory.NavigateUp;
    FEditInput.SelStart := Length(FEditInput.Text);
    Key := 0;
  end
  else if Key = VK_DOWN then
  begin
    FEditInput.Text := FHistory.NavigateDown;
    FEditInput.SelStart := Length(FEditInput.Text);
    Key := 0;
  end;
end;

procedure TframeCmdShell.StartShell(const AShellExe: string; const AWorkDir: string);
begin
  FCmdShell.Start(AShellExe, AWorkDir);
end;

procedure TframeCmdShell.StopShell;
begin
  FCmdShell.Terminate;
end;

end.
