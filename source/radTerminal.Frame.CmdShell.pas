unit radTerminal.Frame.CmdShell;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons,
  radTerminal.CmdShell, radTerminal.CommandHistory;

type
  TRequestPathEvent = procedure(Sender: TObject; var APath: string) of object;

  TframeCmdShell = class(TFrame)
  private
    FPanelToolbar: TPanel;
    FBtnProjectDir: TSpeedButton;
    FBtnFileDir: TSpeedButton;
    FMemoOutput: TMemo;
    FPanelInput: TPanel;
    FEditInput: TEdit;
    FCmdShell: TCmdShellProcess;
    FHistory: TCommandHistory;
    FShellExe: string;
    FWorkDir: string;
    FOnRequestProjectDir: TRequestPathEvent;
    FOnRequestFileDir: TRequestPathEvent;
    procedure HandleOutput(Sender: TObject; const AText: string);
    procedure HandleProcessExit(Sender: TObject);
    procedure HandleInputKeyPress(Sender: TObject; var Key: Char);
    procedure HandleInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleProjectDirClick(Sender: TObject);
    procedure HandleFileDirClick(Sender: TObject);
    procedure BuildControls;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartShell(const AShellExe: string; const AWorkDir: string = '');
    procedure StopShell;
    procedure SetWorkingDirectory(const APath: string);
    property OnRequestProjectDir: TRequestPathEvent read FOnRequestProjectDir write FOnRequestProjectDir;
    property OnRequestFileDir: TRequestPathEvent read FOnRequestFileDir write FOnRequestFileDir;
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
  FCmdShell.OnProcessExit := HandleProcessExit;
end;

destructor TframeCmdShell.Destroy;
begin
  FCmdShell.Free;
  FHistory.Free;
  inherited;
end;

procedure TframeCmdShell.BuildControls;
begin
  FPanelToolbar := TPanel.Create(Self);
  FPanelToolbar.Parent := Self;
  FPanelToolbar.Align := alTop;
  FPanelToolbar.Height := 26;
  FPanelToolbar.BevelOuter := bvNone;
  FPanelToolbar.Caption := '';

  FBtnProjectDir := TSpeedButton.Create(Self);
  FBtnProjectDir.Parent := FPanelToolbar;
  FBtnProjectDir.Align := alLeft;
  FBtnProjectDir.Width := 80;
  FBtnProjectDir.Caption := 'Project Dir';
  FBtnProjectDir.Flat := True;
  FBtnProjectDir.OnClick := HandleProjectDirClick;

  FBtnFileDir := TSpeedButton.Create(Self);
  FBtnFileDir.Parent := FPanelToolbar;
  FBtnFileDir.Align := alLeft;
  FBtnFileDir.Width := 60;
  FBtnFileDir.Caption := 'File Dir';
  FBtnFileDir.Flat := True;
  FBtnFileDir.OnClick := HandleFileDirClick;

  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := Self;
  FPanelInput.Align := alBottom;
  FPanelInput.Height := 30;
  FPanelInput.Padding.Top := 5;
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

procedure TframeCmdShell.HandleProcessExit(Sender: TObject);
begin
  HandleOutput(Self, #13#10'[Process exited. Press Enter to restart]'#13#10);
  FEditInput.ReadOnly := True;
  FEditInput.Text := '';
  FEditInput.TextHint := 'Press Enter to restart';
end;

procedure TframeCmdShell.HandleInputKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if not FCmdShell.Running then
    begin
      FEditInput.ReadOnly := False;
      FEditInput.TextHint := '';
      FMemoOutput.Text := '';
      StartShell(FShellExe, FWorkDir);
      Exit;
    end;
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

procedure TframeCmdShell.HandleProjectDirClick(Sender: TObject);
var
  Path: string;
begin
  Path := '';
  if Assigned(FOnRequestProjectDir) then
  begin
    FOnRequestProjectDir(Self, Path);
    if Path <> '' then
      SetWorkingDirectory(Path);
  end;
end;

procedure TframeCmdShell.HandleFileDirClick(Sender: TObject);
var
  Path: string;
begin
  Path := '';
  if Assigned(FOnRequestFileDir) then
  begin
    FOnRequestFileDir(Self, Path);
    if Path <> '' then
      SetWorkingDirectory(Path);
  end;
end;

procedure TframeCmdShell.SetWorkingDirectory(const APath: string);
var
  Cmd: string;
begin
  if not FCmdShell.Running then
    Exit;
  Cmd := TCmdShellProcess.ChangeDirectoryCommand(FShellExe, APath);
  FCmdShell.SendCommand(Cmd);
end;

procedure TframeCmdShell.StartShell(const AShellExe: string; const AWorkDir: string);
begin
  FShellExe := AShellExe;
  FWorkDir := AWorkDir;
  FCmdShell.Start(AShellExe, AWorkDir);
end;

procedure TframeCmdShell.StopShell;
begin
  FCmdShell.Terminate;
end;

end.
