(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Frame.CmdShell;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.RichEdit,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.CommandHistory,
  Delphi.Terminal.AnsiParser,
  Delphi.Terminal.Settings;

type
  TRequestPathEvent = procedure(Sender: TObject; var APath: string) of object;

  TframeCmdShell = class(TFrame)
  private
    FPanelToolbar: TPanel;
    FBtnProjectDir: TSpeedButton;
    FBtnFileDir: TSpeedButton;
    FBtnCommands: TSpeedButton;
    FBtnClear: TSpeedButton;
    FBtnStop: TSpeedButton;
    FRichOutput: TRichEdit;
    FPanelInput: TPanel;
    FCmdLabel: TEdit;
    FEditInput: TEdit;
    FCmdShellProcess: TCmdShellProcess;
    FHistory: TCommandHistory;
    FAnsiParser: TAnsiParser;
    FOutputBuffer: TStringBuilder;
    FOutputRenderPending: Boolean;
    FCmdShellInfo: TCmdShellInfo;
    FWorkDir: string;
    FShellUnavailable: Boolean;
    FOnRequestProjectDir: TRequestPathEvent;
    FOnRequestFileDir: TRequestPathEvent;
    FOnCommandPaletteRequested: TNotifyEvent;

    procedure HandleOutput(Sender: TObject; const AText: string);
    procedure HandleProcessExit(Sender: TObject);
    procedure HandleInputKeyPress(Sender: TObject; var Key: Char);
    procedure HandleInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleProjectDirClick(Sender: TObject);
    procedure HandleFileDirClick(Sender: TObject);
    procedure HandleCommandsClick(Sender: TObject);
    procedure HandleClearClick(Sender: TObject);
    procedure HandleStopClick(Sender: TObject);
    procedure FlushOutputBuffer;
    procedure ApplySegmentFormat(const AAttr: TAnsiAttributes);
    procedure TrimOutput;
    procedure BuildControls;
    function GetShellType:TCmdShellType;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure StartShell(const ACmdShellInfo: TCmdShellInfo;const AWorkDir: string = '');
    procedure StopShell;
    procedure ShowStartupError(const ACmdShellInfo: TCmdShellInfo; const AMessage: string);

    procedure SetWorkingDirectory(const APath: string);
    procedure ClearOutput;
    procedure FocusInput;
    procedure SendUserCommand(const AText: string);
    procedure InsertCommandText(const AText: string);
    procedure ShowMessage(const AText: string);

    property ShellType:TCmdShellType read GetShellType;
    property OnRequestProjectDir: TRequestPathEvent read FOnRequestProjectDir write FOnRequestProjectDir;
    property OnRequestFileDir: TRequestPathEvent read FOnRequestFileDir write FOnRequestFileDir;
    property OnCommandPaletteRequested: TNotifyEvent read FOnCommandPaletteRequested write FOnCommandPaletteRequested;
  end;

implementation

{$R *.dfm}

const
  WM_RENDER_OUTPUT = WM_APP + 101;
  MAX_RENDER_CHARS_PER_PASS = 65536;

constructor TframeCmdShell.Create(AOwner: TComponent);
begin
  inherited;
  BuildControls;

  FHistory := TCommandHistory.Create;
  FAnsiParser := TAnsiParser.Create;
  FOutputBuffer := TStringBuilder.Create;
  FCmdShellProcess := TCmdShellProcess.Create;
  FCmdShellProcess.OnOutput := HandleOutput;
  FCmdShellProcess.OnProcessExit := HandleProcessExit;
end;

destructor TframeCmdShell.Destroy;
begin
  FCmdShellProcess.Free;
  FOutputBuffer.Free;
  FAnsiParser.Free;
  FHistory.Free;
  inherited;
end;

procedure TframeCmdShell.BuildControls;
const
  TerminalBg = $0C0C0C; // Campbell background #0C0C0C
  TerminalFg = $CCCCCC; // Campbell foreground #CCCCCC
var
  TerminalFont: string;
  TerminalFontSize: Integer;
begin
  TerminalFont := TerminalSettings.FontName;
  TerminalFontSize := TerminalSettings.FontSize;

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

  FBtnCommands := TSpeedButton.Create(Self);
  FBtnCommands.Parent := FPanelToolbar;
  FBtnCommands.Align := alLeft;
  FBtnCommands.Width := 80;
  FBtnCommands.Caption := 'Commands';
  FBtnCommands.Flat := True;
  FBtnCommands.OnClick := HandleCommandsClick;

  FBtnClear := TSpeedButton.Create(Self);
  FBtnClear.Parent := FPanelToolbar;
  FBtnClear.Align := alLeft;
  FBtnClear.Width := 45;
  FBtnClear.Caption := 'Clear';
  FBtnClear.Flat := True;
  FBtnClear.OnClick := HandleClearClick;

  FBtnStop := TSpeedButton.Create(Self);
  FBtnStop.Parent := FPanelToolbar;
  FBtnStop.Align := alLeft;
  FBtnStop.Width := 45;
  FBtnStop.Caption := 'Stop';
  FBtnStop.Flat := True;
  FBtnStop.OnClick := HandleStopClick;

  FPanelInput := TPanel.Create(Self);
  FPanelInput.Parent := Self;
  FPanelInput.Align := alBottom;
  FPanelInput.Height := 30;
  FPanelInput.Padding.Top := 5;
  FPanelInput.BevelOuter := bvNone;
  FPanelInput.Caption := '';
  FPanelInput.Color := TerminalBg;
  FPanelInput.ParentBackground := False;
  FPanelInput.ParentColor := False;
  FPanelInput.StyleElements := [];

  FCmdLabel := TEdit.Create(Self);
  FCmdLabel.Parent := FPanelInput;
  FCmdLabel.Align := alLeft;
  FCmdLabel.Text := 'command: ';
  FCmdLabel.Font.Name := TerminalFont;
  FCmdLabel.Font.Size := TerminalFontSize;
  FCmdLabel.Font.Color := TerminalFg;
  FCmdLabel.Color := TerminalBg;
  FCmdLabel.ReadOnly := True;
  FCmdLabel.BorderStyle := bsNone;
  FCmdLabel.TabStop := False;
  FCmdLabel.Width := 80;
  FCmdLabel.StyleElements := [];

  FEditInput := TEdit.Create(Self);
  FEditInput.Parent := FPanelInput;
  FEditInput.Align := alClient;
  FEditInput.Font.Name := TerminalFont;
  FEditInput.Font.Size := TerminalFontSize;
  FEditInput.Font.Color := TerminalFg;
  FEditInput.Color := TerminalBg;
  FEditInput.OnKeyPress := HandleInputKeyPress;
  FEditInput.OnKeyDown := HandleInputKeyDown;
  FEditInput.BorderStyle := bsNone;
  FEditInput.StyleElements := [];

  FRichOutput := TRichEdit.Create(Self);
  FRichOutput.Parent := Self;
  FRichOutput.Align := alClient;
  FRichOutput.Font.Name := TerminalFont;
  FRichOutput.Font.Size := TerminalFontSize;
  FRichOutput.Font.Color := TerminalFg;
  FRichOutput.Font.Quality := fqAntialiased;
  FRichOutput.Color := TerminalBg;
  FRichOutput.ParentColor := False;
  FRichOutput.StyleElements := [];
  FRichOutput.ReadOnly := True;
  FRichOutput.ScrollBars := ssBoth;
  FRichOutput.WordWrap := False;
  FRichOutput.WantReturns := False;
  FRichOutput.PlainText := False;
end;

procedure TframeCmdShell.HandleOutput(Sender: TObject; const AText: string);
begin
  if AText = '' then
    Exit;
  FOutputBuffer.Append(AText);
  if not FOutputRenderPending then
  begin
    FOutputRenderPending := True;
    PostMessage(Handle, WM_RENDER_OUTPUT, 0, 0);
  end;
end;

procedure TframeCmdShell.FlushOutputBuffer;
var
  Count: Integer;
  Text: string;
  Segments: TArray<TAnsiSegment>;
  Seg: TAnsiSegment;
begin
  FOutputRenderPending := False;
  if FOutputBuffer.Length = 0 then
    Exit;

  Count := FOutputBuffer.Length;
  if Count > MAX_RENDER_CHARS_PER_PASS then
    Count := MAX_RENDER_CHARS_PER_PASS;

  Text := FOutputBuffer.ToString(0, Count);
  FOutputBuffer.Remove(0, Count);
  Segments := FAnsiParser.Parse(Text);
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

  SendMessage(FRichOutput.Handle, WM_VSCROLL, SB_BOTTOM, 0);

  if FOutputBuffer.Length > 0 then
  begin
    FOutputRenderPending := True;
    PostMessage(Handle, WM_RENDER_OUTPUT, 0, 0);
  end;
end;

procedure TframeCmdShell.ApplySegmentFormat(const AAttr: TAnsiAttributes);
const
  // Windows Terminal "Campbell" palette (default)
  AnsiColorMap: array [TAnsiColor] of TColor = (
    $CCCCCC, // acDefault -- Campbell foreground #CCCCCC
    $000000, // acBlack
    $1F0FC5, // acRed         #C50F1F
    $0EA113, // acGreen       #13A10E
    $009CC1, // acYellow      #C19C00
    $DA3700, // acBlue        #0037DA
    $981788, // acMagenta     #881798
    $DD963A, // acCyan        #3A96DD
    $CCCCCC, // acWhite       #CCCCCC
    $767676, // acBrightBlack #767676
    $5648E7, // acBrightRed   #E74856
    $0CC616, // acBrightGreen #16C60C
    $A5F1F9, // acBrightYellow #F9F1A5
    $FF783B, // acBrightBlue  #3B78FF
    $9E00B4, // acBrightMagenta #B4009E
    $D6D661, // acBrightCyan  #61D6D6
    $F2F2F2      // acBrightWhite #F2F2F2
  );
var
  CF: TCharFormat2;
begin
  if AAttr.UseExtForeColor then
    FRichOutput.SelAttributes.Color := TColor(AAttr.ExtForeColor)
  else
    FRichOutput.SelAttributes.Color := AnsiColorMap[AAttr.ForeColor];
  if asBold in AAttr.Style then
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style + [fsBold]
  else
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style - [fsBold];
  if asUnderline in AAttr.Style then
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style + [fsUnderline]
  else
    FRichOutput.SelAttributes.Style := FRichOutput.SelAttributes.Style - [fsUnderline];

  FillChar(CF, SizeOf(CF), 0);
  CF.cbSize := SizeOf(CF);
  CF.dwMask := CFM_BACKCOLOR;
  if AAttr.UseExtBackColor then
    CF.crBackColor := COLORREF(AAttr.ExtBackColor)
  else if AAttr.BackColor <> acDefault then
    CF.crBackColor := COLORREF(AnsiColorMap[AAttr.BackColor])
  else
    CF.dwEffects := CFE_AUTOBACKCOLOR;
  SendMessage(FRichOutput.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@CF));
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
    if not FCmdShellProcess.Running then
    begin
      if FShellUnavailable then
        Exit;
      FEditInput.ReadOnly := False;
      FEditInput.TextHint := '';
      FRichOutput.Clear;
      FAnsiParser.Reset;
      StartShell(FCmdShellInfo, FWorkDir);
      Exit;
    end;
    SendUserCommand(FEditInput.Text);
  end;
end;

procedure TframeCmdShell.WndProc(var Message: TMessage);
var
  Key: Word;
  Shift: TShiftState;
begin
  if Message.Msg = WM_RENDER_OUTPUT then
  begin
    Message.Result := 0;
    FlushOutputBuffer;
    Exit;
  end;

  if (Message.Msg = CM_DIALOGKEY) and FEditInput.Focused then
  begin
    Key := TWMKey(Message).CharCode;
    Shift := KeyDataToShiftState(TWMKey(Message).KeyData);
    if (Key = VK_TAB) and (ssCtrl in Shift) then
    begin
      HandleInputKeyDown(FEditInput, Key, Shift);
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited WndProc(Message);
end;

procedure TframeCmdShell.HandleInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

  function FindPageControl: TPageControl;
  var
    P: TWinControl;
  begin
    Result := nil;
    P := Self.Parent;
    while P <> nil do
    begin
      if P is TPageControl then
        Exit(TPageControl(P));
      if P is TTabSheet then
      begin
        if TTabSheet(P).PageControl <> nil then
          Exit(TTabSheet(P).PageControl);
      end;
      P := P.Parent;
    end;
  end;

  procedure SwitchToTab(AIndex: Integer);
  var
    PC: TPageControl;
    Frame: TframeCmdShell;
    I: Integer;
  begin
    PC := FindPageControl;
    if (PC = nil) or (AIndex < 0) or (AIndex >= PC.PageCount) then
      Exit;
    PC.ActivePageIndex := AIndex;
    for I := 0 to PC.ActivePage.ControlCount - 1 do
      if PC.ActivePage.Controls[I] is TframeCmdShell then
      begin
        Frame := TframeCmdShell(PC.ActivePage.Controls[I]);
        Frame.FocusInput;
        Break;
      end;
    Key := 0;
  end;

  procedure CycleTab(AForward: Boolean);
  var
    PC: TPageControl;
    Idx: Integer;
  begin
    PC := FindPageControl;
    if (PC = nil) or (PC.PageCount < 2) then
      Exit;
    Idx := PC.ActivePageIndex;
    if AForward then
      Idx := (Idx + 1) mod PC.PageCount
    else
      Idx := (Idx - 1 + PC.PageCount) mod PC.PageCount;
    SwitchToTab(Idx);
  end;

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
  end
  else if (Key = VK_TAB) and (ssCtrl in Shift) then
    CycleTab(not (ssShift in Shift))
  else if (ssCtrl in Shift) and (Key in [Ord('1') .. Ord('9')]) then
    SwitchToTab(Key - Ord('1'))
  else if (Key = Ord('L')) and (ssCtrl in Shift) then
  begin
    ClearOutput;
    Key := 0;
  end
  else if (Key = Ord('C')) and (ssCtrl in Shift) and (FEditInput.SelLength = 0) then
  begin
    FCmdShellProcess.SendCtrlC;
    Key := 0;
  end
  else if (Key = Ord('P')) and (ssCtrl in Shift) then
  begin
    if Assigned(FOnCommandPaletteRequested) then
      FOnCommandPaletteRequested(Self);
    Key := 0;
  end;
end;

procedure TframeCmdShell.HandleCommandsClick(Sender: TObject);
begin
  if Assigned(FOnCommandPaletteRequested) then
    FOnCommandPaletteRequested(Self);
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
  if not FCmdShellProcess.Running then
    Exit;
  Cmd := TCmdUtils.ChangeDirectoryCommand(FCmdShellInfo.ShellType, APath);
  FCmdShellProcess.SendCommand(Cmd);
  //  FRichOutput.SelStart := FRichOutput.GetTextLen;
  //  SendMessage(FRichOutput.Handle, EM_SCROLLCARET, 0, 0);
  SendMessage(FRichOutput.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TframeCmdShell.HandleClearClick(Sender: TObject);
begin
  ClearOutput;
end;

procedure TframeCmdShell.HandleStopClick(Sender: TObject);
begin
  FCmdShellProcess.DiscardQueuedOutput;
  FOutputBuffer.Clear;
  FOutputRenderPending := False;
  FAnsiParser.Reset;
  FCmdShellProcess.SendCtrlC;
end;

procedure TframeCmdShell.ClearOutput;
begin
  FOutputBuffer.Clear;
  FOutputRenderPending := False;
  FRichOutput.Clear;
  FAnsiParser.Reset;
end;

procedure TframeCmdShell.FocusInput;
begin
  if FEditInput.CanFocus then
    FEditInput.SetFocus;
end;

procedure TframeCmdShell.SendUserCommand(const AText: string);
begin
  if not FCmdShellProcess.Running then
    Exit;
  FHistory.Add(AText);
  FHistory.ResetPosition;
  FCmdShellProcess.SendCommand(AText);
  FEditInput.Clear;
end;

procedure TframeCmdShell.InsertCommandText(const AText: string);
begin
  FEditInput.Text := AText;
  FEditInput.SelStart := Length(AText);
  FocusInput;
end;

procedure TframeCmdShell.ShowMessage(const AText: string);
begin
  HandleOutput(Self, AText + #13#10);
end;

procedure TframeCmdShell.StartShell(const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
begin
  FCmdShellInfo := ACmdShellInfo;
  FWorkDir := AWorkDir;
  FShellUnavailable := False;
  FCmdShellProcess.Start(ACmdShellInfo, AWorkDir);
end;

procedure TframeCmdShell.ShowStartupError(const ACmdShellInfo: TCmdShellInfo; const AMessage: string);
begin
  FCmdShellInfo := ACmdShellInfo;
  FShellUnavailable := True;
  FEditInput.ReadOnly := True;
  FEditInput.Text := '';
  FEditInput.TextHint := 'Shell unavailable';
  ClearOutput;
  HandleOutput(Self, Format('[%s not found]'#13#10'%s'#13#10, [ACmdShellInfo.Exe, AMessage]));
end;

procedure TframeCmdShell.StopShell;
begin
  FCmdShellProcess.Terminate;
end;

function TframeCmdShell.GetShellType:TCmdShellType;
begin
  Result := FCmdShellInfo.ShellType;
end;

end.
