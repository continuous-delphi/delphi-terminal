unit radTerminal.Frame.CmdShell;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons, Vcl.ComCtrls,
  radTerminal.CmdShell, radTerminal.CommandHistory, radTerminal.AnsiParser;

type
  TRequestPathEvent = procedure(Sender: TObject; var APath: string) of object;

  TframeCmdShell = class(TFrame)
  private
    FPanelToolbar: TPanel;
    FBtnProjectDir: TSpeedButton;
    FBtnFileDir: TSpeedButton;
    FRichOutput: TRichEdit;
    FPanelInput: TPanel;
    FEditInput: TEdit;
    FCmdShell: TCmdShellProcess;
    FHistory: TCommandHistory;
    FAnsiParser: TAnsiParser;
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
    procedure ApplySegmentFormat(const AAttr: TAnsiAttributes);
    procedure TrimOutput;
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
  FAnsiParser := TAnsiParser.Create;
  FCmdShell := TCmdShellProcess.Create;
  FCmdShell.OnOutput := HandleOutput;
  FCmdShell.OnProcessExit := HandleProcessExit;
end;

destructor TframeCmdShell.Destroy;
begin
  FCmdShell.Free;
  FAnsiParser.Free;
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
  FEditInput.Font.Size := 12;
  FEditInput.Font.Color := clLime;
  FEditInput.Color := clBlack;
  FEditInput.OnKeyPress := HandleInputKeyPress;
  FEditInput.OnKeyDown := HandleInputKeyDown;
  FEditInput.BorderStyle := bsNone;

  FRichOutput := TRichEdit.Create(Self);
  FRichOutput.Parent := Self;
  FRichOutput.Align := alClient;
  FRichOutput.Font.Name := 'Consolas';
  FRichOutput.Font.Size := 12;
  FRichOutput.Font.Color := clLime;
  FRichOutput.Color := clBlack;
  FRichOutput.ReadOnly := True;
  FRichOutput.ScrollBars := ssBoth;
  FRichOutput.WordWrap := False;
  FRichOutput.WantReturns := False;
  FRichOutput.PlainText := False;
end;

procedure TframeCmdShell.HandleOutput(Sender: TObject; const AText: string);
var
  Segments: TArray<TAnsiSegment>;
  Seg: TAnsiSegment;
begin
  Segments := FAnsiParser.Parse(AText);
  SendMessage(FRichOutput.Handle, WM_SETREDRAW, 0, 0);
  try
    for Seg in Segments do
    begin
      FRichOutput.SelStart := FRichOutput.GetTextLen;
      FRichOutput.SelLength := 0;
      ApplySegmentFormat(Seg.Attr);
      FRichOutput.SelText := Seg.Text;
    end;
  finally
    SendMessage(FRichOutput.Handle, WM_SETREDRAW, 1, 0);
    InvalidateRect(FRichOutput.Handle, nil, True);
  end;
  SendMessage(FRichOutput.Handle, EM_SCROLLCARET, 0, 0);
  TrimOutput;
end;

procedure TframeCmdShell.ApplySegmentFormat(const AAttr: TAnsiAttributes);
const
  AnsiColorMap: array[TAnsiColor] of TColor = (
    clLime,      // acDefault -- terminal green
    clBlack,     // acBlack
    $0000CC,     // acRed
    $00CC00,     // acGreen
    $00CCCC,     // acYellow
    $FF4444,     // acBlue (brightened for readability on black)
    $CC00CC,     // acMagenta
    $CCCC00,     // acCyan
    $C0C0C0,     // acWhite
    $808080,     // acBrightBlack
    $0000FF,     // acBrightRed
    $00FF00,     // acBrightGreen
    $00FFFF,     // acBrightYellow
    $FF7755,     // acBrightBlue
    $FF00FF,     // acBrightMagenta
    $FFFF00,     // acBrightCyan
    clWhite      // acBrightWhite
  );
begin
  FRichOutput.SelAttributes.Color := AnsiColorMap[AAttr.ForeColor];
  if asBold in AAttr.Style then
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style + [fsBold]
  else
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style - [fsBold];
  if asUnderline in AAttr.Style then
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style + [fsUnderline]
  else
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style - [fsUnderline];
end;

procedure TframeCmdShell.TrimOutput;
const
  MaxLen = 500000;
  TrimLen = 125000;
var
  Len: Integer;
begin
  Len := FRichOutput.GetTextLen;
  if Len > MaxLen then
  begin
    FRichOutput.SelStart := 0;
    FRichOutput.SelLength := TrimLen;
    FRichOutput.SelText := '';
  end;
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
      FRichOutput.Clear;
      FAnsiParser.Reset;
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
var
  Lower: string;
begin
  FShellExe := AShellExe;
  FWorkDir := AWorkDir;
  FCmdShell.Start(AShellExe, AWorkDir);
  Lower := LowerCase(ExtractFileName(AShellExe));
  if Lower.Contains('pwsh') then
    FCmdShell.SendCommand('$PSStyle.OutputRendering = ''Ansi''');
end;

procedure TframeCmdShell.StopShell;
begin
  FCmdShell.Terminate;
end;

end.
