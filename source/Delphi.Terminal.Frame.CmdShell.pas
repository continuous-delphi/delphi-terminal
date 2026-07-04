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
  Delphi.Terminal.Pty,
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.VTParser,
  Delphi.Terminal.TerminalView,
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
    FRichOutput: TRichEdit;               // legacy pipe backend renderer
    FTermView: TTerminalView;             // ConPTY backend renderer
    FScreen: TScreenBuffer;               // ConPTY screen model (nil until ConPTY starts)
    FVTParser: TVTParser;                 // ConPTY VT parser driving FScreen
    FPtySize: TTerminalSize;              // last size pushed to the pseudoconsole
    FPanelInput: TPanel;
    FCmdLabel: TEdit;
    FEditInput: TEdit;
    FProcess: ITerminalProcess;
    FProcessObj: TObject;
    FBackendKind: TTerminalBackendKind;
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
    procedure HandleTermViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleTermViewKeyPress(Sender: TObject; var Key: Char);
    function FindPageControl: TPageControl;
    procedure SwitchToTab(AIndex: Integer);
    procedure CycleTab(AForward: Boolean);
    procedure HandleProjectDirClick(Sender: TObject);
    procedure HandleFileDirClick(Sender: TObject);
    procedure HandleCommandsClick(Sender: TObject);
    procedure HandleClearClick(Sender: TObject);
    procedure HandleStopClick(Sender: TObject);
    procedure FlushOutputBuffer;
    procedure ApplySegmentFormat(const AAttr: TAnsiAttributes);
    procedure TrimOutput;
    procedure BuildControls;
    procedure RecreateBackend;
    function GetShellType:TCmdShellType;
    // ConPTY renderer plumbing (#69)
    function CurrentTerminalSize: TTerminalSize;
    procedure EnsureConPtyModel;
    procedure SyncTerminalSize;
    procedure HandleTermViewResize(Sender: TObject);
    procedure HandleTermViewPaste(Sender: TObject);
    procedure PasteToShell;
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

    property BackendKind: TTerminalBackendKind read FBackendKind write FBackendKind;
    property ShellType:TCmdShellType read GetShellType;
    property OnRequestProjectDir: TRequestPathEvent read FOnRequestProjectDir write FOnRequestProjectDir;
    property OnRequestFileDir: TRequestPathEvent read FOnRequestFileDir write FOnRequestFileDir;
    property OnCommandPaletteRequested: TNotifyEvent read FOnCommandPaletteRequested write FOnCommandPaletteRequested;
  end;

implementation

uses
  Vcl.Clipbrd,
  Delphi.Terminal.KeyInput,
  Delphi.Terminal.ConPtyShell;

{$R *.dfm}

const
  WM_RENDER_OUTPUT = WM_APP + 101;
  WM_SYNC_TERM_SIZE = WM_APP + 102;
  MAX_RENDER_CHARS_PER_PASS = 65536;

{$DEFINE PTY_CAPTURE}  // Diagnostic: raw ConPTY stream capture to <exe dir>\pty-capture.log. Enable (remove the dot) and rebuild to capture.

{$IFDEF PTY_CAPTURE}
var
  GPtyCaptureStarted: Boolean = False;

// Appends one line to <exe dir>\pty-capture.log with control bytes made readable
// (\e = ESC, \r \n \t \b \a, others as \xNN). Truncates on the first call per run.
procedure PtyCapture(const APrefix, AText: string);
var
  LSB: TStringBuilder;
  LPath: string;
  LFile: TextFile;
  C: Char;
begin
  LSB := TStringBuilder.Create;
  try
    for C in AText do
      case C of
        #27: LSB.Append('\e');
        #13: LSB.Append('\r');
        #10: LSB.Append('\n');
        #9:  LSB.Append('\t');
        #8:  LSB.Append('\b');
        #7:  LSB.Append('\a');
      else
        if (C < ' ') or (C = #127) then
          LSB.Append('\x').Append(IntToHex(Ord(C), 2))
        else
          LSB.Append(C);
      end;
    LPath := ExtractFilePath(ParamStr(0)) + 'pty-capture.log';
    AssignFile(LFile, LPath);
    if GPtyCaptureStarted and FileExists(LPath) then
      Append(LFile)
    else
    begin
      Rewrite(LFile);
      GPtyCaptureStarted := True;
    end;
    try
      Writeln(LFile, APrefix, '|', LSB.ToString);
    finally
      CloseFile(LFile);
    end;
  finally
    LSB.Free;
  end;
end;
{$ENDIF}

constructor TframeCmdShell.Create(AOwner: TComponent);
begin
  inherited;
  BuildControls;

  FHistory := TCommandHistory.Create;
  FAnsiParser := TAnsiParser.Create;
  FOutputBuffer := TStringBuilder.Create;
  // The backend (legacy pipe or ConPTY) is created on demand in StartShell,
  // chosen by BackendKind (default: legacy pipe).
end;

destructor TframeCmdShell.Destroy;
begin
  FProcess := nil;
  FreeAndNil(FProcessObj);
  FVTParser.Free;
  FScreen.Free;
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
  FCmdLabel.Width := 85;
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

  // ConPTY renderer. Both output controls are alClient; only the one matching the
  // active backend is visible (toggled in RecreateBackend). Legacy = RichEdit.
  FTermView := TTerminalView.Create(Self);
  FTermView.Parent := Self;
  FTermView.Align := alClient;
  FTermView.Font.Name := TerminalFont;
  FTermView.Font.Size := TerminalFontSize;
  FTermView.DefaultBackground := TerminalBg;
  FTermView.DefaultForeground := TerminalFg;
  FTermView.Visible := False;
  FTermView.OnResize := HandleTermViewResize;
  FTermView.OnClearRequested := HandleClearClick;
  FTermView.OnInterruptRequested := HandleStopClick;
  FTermView.OnPasteRequested := HandleTermViewPaste;
  FTermView.OnKeyDown := HandleTermViewKeyDown;
  FTermView.OnKeyPress := HandleTermViewKeyPress;
end;

procedure TframeCmdShell.HandleOutput(Sender: TObject; const AText: string);
begin
  if AText = '' then
    Exit;
  {$IFDEF PTY_CAPTURE}
  if FBackendKind = tbConPty then
    PtyCapture('OUT ' + Name, AText);
  {$ENDIF}
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

  if FBackendKind = tbConPty then
  begin
    // ConPTY: drive the screen model through the VT parser and repaint incrementally.
    if Assigned(FVTParser) then
      FVTParser.Parse(Text);
    if Assigned(FTermView) then
      FTermView.UpdateView;
    if FOutputBuffer.Length > 0 then
    begin
      FOutputRenderPending := True;
      PostMessage(Handle, WM_RENDER_OUTPUT, 0, 0);
    end;
    Exit;
  end;

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
    if not (Assigned(FProcess) and FProcess.Running) then
    begin
      if FShellUnavailable then
        Exit;
      FEditInput.ReadOnly := False;
      FEditInput.TextHint := '';
      ClearOutput;
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

  if Message.Msg = WM_SYNC_TERM_SIZE then
  begin
    Message.Result := 0;
    SyncTerminalSize;
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

function TframeCmdShell.FindPageControl: TPageControl;
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

procedure TframeCmdShell.SwitchToTab(AIndex: Integer);
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
end;

procedure TframeCmdShell.CycleTab(AForward: Boolean);
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
  end
  else if (Key = VK_TAB) and (ssCtrl in Shift) then
  begin
    CycleTab(not (ssShift in Shift));
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key in [Ord('1') .. Ord('9')]) then
  begin
    SwitchToTab(Key - Ord('1'));
    Key := 0;
  end
  else if (Key = Ord('L')) and (ssCtrl in Shift) then
  begin
    ClearOutput;
    Key := 0;
  end
  else if (Key = Ord('C')) and (ssCtrl in Shift) and (FEditInput.SelLength = 0) then
  begin
    if Assigned(FProcess) then
      FProcess.SendInterrupt;
    Key := 0;
  end
  else if (Key = Ord('P')) and (ssCtrl in Shift) then
  begin
    if Assigned(FOnCommandPaletteRequested) then
      FOnCommandPaletteRequested(Self);
    Key := 0;
  end;
end;

procedure TframeCmdShell.HandleTermViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LSeq: string;
begin
  // UI navigation stays at the frame level even when the view has focus.
  if (Key = VK_TAB) and (ssCtrl in Shift) then
  begin
    CycleTab(not (ssShift in Shift));
    Key := 0;
    Exit;
  end
  else if (ssCtrl in Shift) and (Key in [Ord('1') .. Ord('9')]) then
  begin
    SwitchToTab(Key - Ord('1'));
    Key := 0;
    Exit;
  end
  else if (Key = Ord('P')) and (ssCtrl in Shift) then
  begin
    if Assigned(FOnCommandPaletteRequested) then
      FOnCommandPaletteRequested(Self);
    Key := 0;
    Exit;
  end
  else if ((Key = Ord('V')) and (ssCtrl in Shift) and not (ssAlt in Shift)) or
          ((Key = VK_INSERT) and (ssShift in Shift)) then
  begin
    // Paste (Ctrl+V, matching PSReadLine/Windows convention, or Shift+Insert).
    PasteToShell;
    Key := 0;
    Exit;
  end;

  if not (Assigned(FProcess) and FProcess.Running) then
  begin
    // Process has exited: Enter restarts the session (mirrors the legacy line-mode path).
    if (Key = VK_RETURN) and not FShellUnavailable then
    begin
      ClearOutput;
      StartShell(FCmdShellInfo, FWorkDir);
      Key := 0;
    end;
    Exit;
  end;

  // Everything else is translated to a VT sequence and sent to the shell. Printable
  // characters return '' here and are handled by HandleTermViewKeyPress instead.
  LSeq := KeyToVT(Key, Shift);
  if LSeq <> '' then
  begin
    {$IFDEF PTY_CAPTURE}
    PtyCapture('IN  ' + Name, LSeq);
    {$ENDIF}
    FProcess.WriteInput(LSeq);
    Key := 0;
  end;
end;

procedure TframeCmdShell.HandleTermViewKeyPress(Sender: TObject; var Key: Char);
begin
  // Printable characters (control keys were already consumed in KeyDown).
  if (Key >= ' ') and Assigned(FProcess) and FProcess.Running then
  begin
    {$IFDEF PTY_CAPTURE}
    PtyCapture('IN  ' + Name, Key);
    {$ENDIF}
    FProcess.WriteInput(Key);
  end;
  Key := #0;
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
  if not (Assigned(FProcess) and FProcess.Running) then
    Exit;
  Cmd := TCmdUtils.ChangeDirectoryCommand(FCmdShellInfo.ShellType, APath);
  FProcess.WriteInput(Cmd + #13#10);
  if FBackendKind = tbConPty then
    FTermView.ScrollToBottom
  else
    SendMessage(FRichOutput.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TframeCmdShell.HandleClearClick(Sender: TObject);
begin
  ClearOutput;
end;

procedure TframeCmdShell.HandleStopClick(Sender: TObject);
begin
  if Assigned(FProcess) then
    FProcess.DiscardQueuedOutput;
  FOutputBuffer.Clear;
  FOutputRenderPending := False;
  if FBackendKind = tbConPty then
  begin
    if Assigned(FVTParser) then
      FVTParser.Reset;
  end
  else
    FAnsiParser.Reset;
  if Assigned(FProcess) then
    FProcess.SendInterrupt;
end;

procedure TframeCmdShell.ClearOutput;
begin
  FOutputBuffer.Clear;
  FOutputRenderPending := False;
  if FBackendKind = tbConPty then
  begin
    if Assigned(FVTParser) then
      FVTParser.Reset;
    if Assigned(FScreen) then
      FScreen.ClearAll;
    if Assigned(FTermView) then
    begin
      FTermView.ClearSelection;
      FTermView.ScrollToBottom;
      FTermView.RefreshAll;
    end;
  end
  else
  begin
    FRichOutput.Clear;
    FAnsiParser.Reset;
  end;
end;

procedure TframeCmdShell.FocusInput;
begin
  if (FBackendKind = tbConPty) and FTermView.Visible then
  begin
    if FTermView.CanFocus then
      FTermView.SetFocus;
  end
  else if FEditInput.CanFocus then
    FEditInput.SetFocus;
end;

procedure TframeCmdShell.SendUserCommand(const AText: string);
begin
  if not (Assigned(FProcess) and FProcess.Running) then
    Exit;
  FHistory.Add(AText);
  FHistory.ResetPosition;
  FProcess.WriteInput(AText + #13#10);
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

procedure TframeCmdShell.RecreateBackend;
begin
  FProcess := nil;
  FreeAndNil(FProcessObj);
  case FBackendKind of
    tbConPty:
      FProcessObj := TConPtyShell.Create;
  else
    FProcessObj := TCmdShellProcess.Create;
  end;
  Supports(FProcessObj, ITerminalProcess, FProcess);
  FProcess.OnOutput := HandleOutput;
  FProcess.OnProcessExit := HandleProcessExit;

  // Show the renderer for the active backend; hide the other. In ConPTY mode the
  // keystrokes go straight to the view, so the line-entry panel is hidden.
  FRichOutput.Visible := FBackendKind <> tbConPty;
  FTermView.Visible := FBackendKind = tbConPty;
  FPanelInput.Visible := FBackendKind <> tbConPty;
end;

function TframeCmdShell.CurrentTerminalSize: TTerminalSize;
begin
  // Derive cols/rows from the view's font metrics and client area; fall back to a
  // sane default before the view has a handle (e.g. plugin dock not yet shown).
  if (FTermView <> nil) and FTermView.HandleAllocated and (FTermView.VisibleCols > 1) and (FTermView.VisibleRows > 1) then
  begin
    Result.Cols := FTermView.VisibleCols;
    Result.Rows := FTermView.VisibleRows;
  end
  else
    Result := DefaultTerminalSize;
end;

procedure TframeCmdShell.EnsureConPtyModel;
var
  LSize: TTerminalSize;
begin
  LSize := CurrentTerminalSize;
  if FScreen = nil then
    FScreen := TScreenBuffer.Create(LSize.Cols, LSize.Rows)
  else
    FScreen.Resize(LSize.Cols, LSize.Rows);
  FScreen.ClearAll;

  if FVTParser = nil then
    FVTParser := TVTParser.Create(FScreen)
  else
    FVTParser.Reset;

  FTermView.Buffer := FScreen;
  FTermView.ScrollToBottom;
end;

procedure TframeCmdShell.SyncTerminalSize;
var
  LSize: TTerminalSize;
begin
  if (FBackendKind <> tbConPty) or (FScreen = nil) or (FTermView = nil) then
    Exit;
  LSize := CurrentTerminalSize;

  // Resize the model to match the view.
  if (LSize.Cols <> FScreen.Cols) or (LSize.Rows <> FScreen.Rows) then
  begin
    FScreen.Resize(LSize.Cols, LSize.Rows);
    FTermView.RefreshAll;
  end;

  // Push to the pseudoconsole whenever it differs from the last size we sent -- this
  // is tracked independently of the buffer so an initial resize that happened before
  // the process was running (leaving the PTY at the 80x24 fallback) is still corrected.
  if Assigned(FProcess) and FProcess.Running and ((LSize.Cols <> FPtySize.Cols) or (LSize.Rows <> FPtySize.Rows)) then
  begin
    FProcess.Resize(LSize);
    FPtySize := LSize;
  end;
end;

procedure TframeCmdShell.HandleTermViewResize(Sender: TObject);
begin
  SyncTerminalSize;
end;

procedure TframeCmdShell.HandleTermViewPaste(Sender: TObject);
begin
  PasteToShell;
end;

procedure TframeCmdShell.PasteToShell;
var
  LText: string;
  LBracketed: Boolean;
begin
  if not (Assigned(FProcess) and FProcess.Running) then
    Exit;
  LText := Clipboard.AsText;
  if LText = '' then
    Exit;
  // Use bracketed paste only when the running app asked for it (DEC ?2004), so it can
  // treat the paste as literal text instead of interpreting embedded newlines/keys.
  LBracketed := (FBackendKind = tbConPty) and Assigned(FScreen) and FScreen.BracketedPaste;
  FProcess.WriteInput(BuildPasteSequence(LText, LBracketed));
end;

procedure TframeCmdShell.StartShell(const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
var
  LStartSize: TTerminalSize;
begin
  FCmdShellInfo := ACmdShellInfo;
  FWorkDir := AWorkDir;
  FShellUnavailable := False;
  RecreateBackend;
  FPtySize.Cols := 0;   // force the first sync to (re)send the real size
  FPtySize.Rows := 0;
  if FBackendKind = tbConPty then
    EnsureConPtyModel;
  LStartSize := CurrentTerminalSize;
  try
    FProcess.Start(ACmdShellInfo, AWorkDir, LStartSize);
    if FBackendKind = tbConPty then
    begin
      FPtySize := LStartSize;
      // The view may not have its real size yet (e.g. dock/tab not shown); re-sync
      // once layout settles so the pseudoconsole matches the actual view width.
      PostMessage(Handle, WM_SYNC_TERM_SIZE, 0, 0);
    end;
  except
    on E: Exception do
    begin
      // If the ConPTY backend fails to start at runtime (e.g. CreatePseudoConsole
      // or CreateProcess fails), fall back to the legacy pipe backend and retry.
      // Latch to legacy so a later restart does not keep retrying a failing ConPTY.
      if FBackendKind <> tbConPty then
        raise;
      FBackendKind := tbLegacyPipe;
      RecreateBackend;
      HandleOutput(Self, '[ConPTY unavailable, using legacy backend]'#13#10);
      FProcess.Start(ACmdShellInfo, AWorkDir, DefaultTerminalSize);
    end;
  end;
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
  if Assigned(FProcess) then
    FProcess.Terminate;
end;

function TframeCmdShell.GetShellType:TCmdShellType;
begin
  Result := FCmdShellInfo.ShellType;
end;

end.
