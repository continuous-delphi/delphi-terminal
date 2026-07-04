(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Form.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.Frame.CmdShell,
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.VTParser,
  Delphi.Terminal.TerminalView,
  Profile.Commands;

const
  {$IFDEF PROFILE_COMMANDS}
  CProfileBatch = True;   // built for an unattended batch run: auto-run all commands, write CSV, exit
  {$ELSE}
  CProfileBatch = False;
  {$ENDIF}

type
  TProfState = (psIdle, psRunning, psBetween);

  // Mainly for initial dev and ongoing debug purposes
  TfrmMain = class(TForm)
    PageControl1: TPageControl;
    tabCmdShell: TTabSheet;
    tabPwsh: TTabSheet;
    tabPowerShell: TTabSheet;
    tabWSL: TTabSheet;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FFrameCmdShell: TframeCmdShell;
    FFramePwsh: TframeCmdShell;
    FFramePowerShell: TframeCmdShell;
    FFrameWSL:TframeCmdShell;
    // Sneak peek (#67): a TTerminalView rendering canned VT content, so the new
    // cursor-addressed renderer can be eyeballed before the full frame wiring (#68).
    FTermViewTab: TTabSheet;
    FTermView: TTerminalView;
    FTermBuffer: TScreenBuffer;
    FTermParser: TVTParser;
    procedure StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
    procedure HandleRequestDir(Sender: TObject; var APath: string);
    procedure SetupTerminalViewDemo;
    procedure HandleTermViewClear(Sender: TObject);
    procedure HandleTermViewPaste(Sender: TObject);
    procedure HandleTermViewStop(Sender: TObject);
  private
    // --- Perf profiling harness (#81) ---
    FProfCombo: TComboBox;
    FProfRunBtn: TButton;
    FProfStopBtn: TButton;
    FProfMemo: TMemo;
    FProfTimer: TTimer;
    FProfState: TProfState;
    FProfiling: Boolean;
    FProfActiveFrame: TframeCmdShell;
    FProfCmd: TProfiledCommand;
    FProfRepeat: Integer;
    FProfBatchIndex: Integer;   // -1 = interactive single run
    FProfBatchStarted: Boolean;
    FProfChars, FProfChunks, FProfPasses: Int64;
    FProfMemStart, FProfMemPeak, FProfMemEnd: NativeUInt;
    FProfStartQPC, FProfFreq: Int64;
    FProfCsvPath: string;
    FProfExitCode: Integer;
    procedure BuildProfilerTab;
    procedure WireProfilingEvents;
    function FrameForShell(AShell: TCmdShellType): TframeCmdShell;
    function TabForShell(AShell: TCmdShellType): TTabSheet;
    procedure StartProfileRun(const ACmd: TProfiledCommand; ARepeat: Integer);
    procedure FinishProfileRun(const AReason: string);
    procedure AdvanceBatchOrIdle(ASkipCommand: Boolean);
    procedure StartNextBatchRun;
    procedure FinishBatch;
    procedure StartBatch;
    procedure ProfLog(const ALine: string);
    procedure WriteCsvRow(const AReason: string; AElapsedMs, ACharsPerSec: Double);
    procedure HandleProfRun(Sender: TObject);
    procedure HandleProfStop(Sender: TObject);
    procedure HandleProfTimer(Sender: TObject);
    procedure HandleProfOutput(Sender: TObject; ACharCount: Integer);
    procedure HandleProfPass(Sender: TObject);
    procedure HandleProfExit(Sender: TObject);
    procedure HandleFormShow(Sender: TObject);
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.PsAPI,
  Vcl.FileCtrl,
  Vcl.Clipbrd,
  Delphi.Terminal.Settings;

{$R *.dfm}

const
  PROF_SAFETY_CAP_MS = 120000;   // bounded commands that hang are terminated after this
  PROF_BETWEEN_MS = 1500;        // settle between batch runs (shell teardown/restart; WSL VM needs headroom)
  PROF_STARTUP_MS = 1500;        // settle after launch before the first batch run

function CurrentWorkingSetKB: NativeUInt;
var
  LCounters: TProcessMemoryCounters;
begin
  FillChar(LCounters, SizeOf(LCounters), 0);
  LCounters.cb := SizeOf(LCounters);
  if GetProcessMemoryInfo(GetCurrentProcess, @LCounters, SizeOf(LCounters)) then
    Result := LCounters.WorkingSetSize div 1024
  else
    Result := 0;
end;

function AppVersionStr: string;
var
  LSize, LHandle: DWORD;
  LBuf: TBytes;
  LInfo: PVSFixedFileInfo;
  LLen: UINT;
begin
  Result := '0.0.0.0';
  LSize := GetFileVersionInfoSize(PChar(ParamStr(0)), LHandle);
  if LSize = 0 then
    Exit;
  SetLength(LBuf, LSize);
  if GetFileVersionInfo(PChar(ParamStr(0)), LHandle, LSize, LBuf) then
    if VerQueryValue(LBuf, '\', Pointer(LInfo), LLen) then
      Result := Format('%d.%d.%d.%d',
        [HiWord(LInfo.dwFileVersionMS), LoWord(LInfo.dwFileVersionMS),
         HiWord(LInfo.dwFileVersionLS), LoWord(LInfo.dwFileVersionLS)]);
end;

function ShellName(AShell: TCmdShellType): string;
begin
  case AShell of
    TCmdShellType.CMD:        Result := 'cmd';
    TCmdShellType.pwsh:       Result := 'pwsh';
    TCmdShellType.PowerShell: Result := 'powershell';
    TCmdShellType.wsl:        Result := 'wsl';
  else
    Result := 'unknown';
  end;
end;

function BackendName(AKind: TTerminalBackendKind): string;
begin
  if AKind = tbConPty then
    Result := 'ConPTY'
  else
    Result := 'Legacy';
end;

procedure TfrmMain.StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
begin
  {$IFDEF DEBUG}
  AFrame.BackendKind := tbConPty;
  {$ENDIF}
  try
    AFrame.StartShell(ACmdShellInfo, AWorkDir);
  except
    on E: Exception do
      AFrame.ShowStartupError(ACmdShellInfo, E.Message);
  end;
end;

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
  StartTerminalShell(FFrameCmdShell, TCmdUtils.CreateCmdShellInfo(TCmdShellType.CMD), ExeDir);

  FFramePwsh := TframeCmdShell.Create(Self);
  FFramePwsh.Name := 'PWSHFrame';
  FFramePwsh.Parent := tabPwsh;
  FFramePwsh.Align := alClient;
  FFramePwsh.OnRequestProjectDir := HandleRequestDir;
  FFramePwsh.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFramePwsh, TCmdUtils.CreateCmdShellInfo(TCmdShellType.pwsh), ExeDir);

  FFramePowerShell := TframeCmdShell.Create(Self);
  FFramePowerShell.Name := 'PowerShellFrame';
  FFramePowerShell.Parent := tabPowerShell;
  FFramePowerShell.Align := alClient;
  FFramePowerShell.OnRequestProjectDir := HandleRequestDir;
  FFramePowerShell.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFramePowerShell, TCmdUtils.CreateCmdShellInfo(TCmdShellType.PowerShell), ExeDir);

  FFrameWSL := TframeCmdShell.Create(Self);
  FFrameWSL.Name := 'WSLFrame';
  FFrameWSL.Parent := tabWSL;
  FFrameWSL.Align := alClient;
  FFrameWSL.OnRequestProjectDir := HandleRequestDir;
  FFrameWSL.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFrameWSL, TCmdUtils.CreateCmdShellInfo(TCmdShellType.wsl), ExeDir);

  SetupTerminalViewDemo;

  WireProfilingEvents;
  BuildProfilerTab;
  FProfBatchIndex := -1;
  OnShow := HandleFormShow;
end;

procedure TfrmMain.SetupTerminalViewDemo;
const
  ESC = #27;
var
  S: string;
  I: Integer;
begin
  FTermViewTab := TTabSheet.Create(PageControl1);
  FTermViewTab.PageControl := PageControl1;
  FTermViewTab.Caption := 'TTerminalView';

  FTermBuffer := TScreenBuffer.Create(80, 24);
  FTermParser := TVTParser.Create(FTermBuffer);

  FTermView := TTerminalView.Create(Self);
  FTermView.Parent := FTermViewTab;
  FTermView.Align := alClient;
  FTermView.Buffer := FTermBuffer;
  FTermView.OnClearRequested := HandleTermViewClear;
  FTermView.OnPasteRequested := HandleTermViewPaste;
  FTermView.OnInterruptRequested := HandleTermViewStop;

  // Canned VT content exercising SGR styles, the 16-colour palette, the 256-colour
  // cube, and 24-bit truecolour -- driven through the real parser + screen model.
  S := ESC + '[1;36mdelphi-terminal  -  TTerminalView sneak peek (#67)' + ESC + '[0m' + #13#10 + #13#10;

  S := S + 'SGR styles:  ' + ESC + '[1mBold' + ESC + '[0m  ' + ESC + '[3mItalic' + ESC + '[0m  ' +
       ESC + '[4mUnderline' + ESC + '[0m  ' + ESC + '[7mInverse' + ESC + '[0m' + #13#10 + #13#10;

  S := S + '16 colours:  ';
  for I := 0 to 7 do
    S := S + ESC + '[4' + IntToStr(I) + 'm  ';
  S := S + ESC + '[0m' + #13#10 + '             ';
  for I := 0 to 7 do
    S := S + ESC + '[10' + IntToStr(I) + 'm  ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  S := S + '256-cube:    ';
  for I := 16 to 51 do
    S := S + ESC + '[48;5;' + IntToStr(I) + 'm ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  S := S + 'Truecolor:   ';
  for I := 0 to 35 do
    S := S + ESC + '[48;2;' + IntToStr(I * 7) + ';0;' + IntToStr(255 - I * 7) + 'm ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  // Emit more than one screen of lines so the earlier content scrolls into history;
  // use the mouse wheel over the view to scroll it back (#68).
  for I := 1 to 30 do
    S := S + Format('history line %.2d  -- wheel up to scroll back, drag to select, right-click to copy' + #13#10, [I]);

  S := S + ESC + '[32mCursor-addressed prompt (block cursor shown):' + ESC + '[0m' + #13#10;
  S := S + '  ' + ESC + '[33m$' + ESC + '[0m ready ';

  FTermParser.Parse(S);
  FTermView.RefreshAll;
end;

procedure TfrmMain.HandleTermViewClear(Sender: TObject);
begin
  FTermBuffer.ClearAll;
  FTermView.RefreshAll;
end;

procedure TfrmMain.HandleTermViewPaste(Sender: TObject);
begin
  // Display-only demo: echo the clipboard text into the buffer so the Paste menu is visibly wired.
  if Clipboard.AsText <> '' then
  begin
    FTermParser.Parse(Clipboard.AsText + #13#10);
    FTermView.UpdateView;
  end;
end;

procedure TfrmMain.HandleTermViewStop(Sender: TObject);
begin
  FTermParser.Parse(#13#10 + '^C' + #13#10);
  FTermView.UpdateView;
end;

// ---------------------------------------------------------------------------
//  Perf profiling harness (#81)
// ---------------------------------------------------------------------------

function TfrmMain.FrameForShell(AShell: TCmdShellType): TframeCmdShell;
begin
  case AShell of
    TCmdShellType.CMD:        Result := FFrameCmdShell;
    TCmdShellType.pwsh:       Result := FFramePwsh;
    TCmdShellType.PowerShell: Result := FFramePowerShell;
    TCmdShellType.wsl:        Result := FFrameWSL;
  else
    Result := nil;
  end;
end;

function TfrmMain.TabForShell(AShell: TCmdShellType): TTabSheet;
begin
  case AShell of
    TCmdShellType.CMD:        Result := tabCmdShell;
    TCmdShellType.pwsh:       Result := tabPwsh;
    TCmdShellType.PowerShell: Result := tabPowerShell;
    TCmdShellType.wsl:        Result := tabWSL;
  else
    Result := nil;
  end;
end;

procedure TfrmMain.WireProfilingEvents;

  procedure WireOne(AFrame: TframeCmdShell);
  begin
    if AFrame = nil then
      Exit;
    AFrame.OnOutputReceived := HandleProfOutput;
    AFrame.OnRenderPass := HandleProfPass;
    AFrame.OnShellExited := HandleProfExit;
  end;

begin
  WireOne(FFrameCmdShell);
  WireOne(FFramePwsh);
  WireOne(FFramePowerShell);
  WireOne(FFrameWSL);
end;

procedure TfrmMain.BuildProfilerTab;
var
  LTab: TTabSheet;
  LPanel: TPanel;
  LLabel: TLabel;
  I: Integer;
begin
  LTab := TTabSheet.Create(PageControl1);
  LTab.PageControl := PageControl1;
  LTab.Caption := 'Profiler';

  LPanel := TPanel.Create(Self);
  LPanel.Parent := LTab;
  LPanel.Align := alTop;
  LPanel.Height := 34;
  LPanel.BevelOuter := bvNone;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LPanel;
  LLabel.Left := 8;
  LLabel.Top := 10;
  LLabel.Caption := 'Command:';

  FProfCombo := TComboBox.Create(Self);
  FProfCombo.Parent := LPanel;
  FProfCombo.Left := 64;
  FProfCombo.Top := 6;
  FProfCombo.Width := 360;
  FProfCombo.Style := csDropDownList;
  for I := 0 to High(CProfiledCommands) do
    FProfCombo.Items.Add(CProfiledCommands[I].Description);
  if FProfCombo.Items.Count > 0 then
    FProfCombo.ItemIndex := 0;

  FProfRunBtn := TButton.Create(Self);
  FProfRunBtn.Parent := LPanel;
  FProfRunBtn.Left := 432;
  FProfRunBtn.Top := 5;
  FProfRunBtn.Width := 70;
  FProfRunBtn.Caption := 'Run';
  FProfRunBtn.OnClick := HandleProfRun;

  FProfStopBtn := TButton.Create(Self);
  FProfStopBtn.Parent := LPanel;
  FProfStopBtn.Left := 508;
  FProfStopBtn.Top := 5;
  FProfStopBtn.Width := 70;
  FProfStopBtn.Caption := 'Stop';
  FProfStopBtn.Enabled := False;
  FProfStopBtn.OnClick := HandleProfStop;

  FProfMemo := TMemo.Create(Self);
  FProfMemo.Parent := LTab;
  FProfMemo.Align := alClient;
  FProfMemo.ReadOnly := True;
  FProfMemo.ScrollBars := ssBoth;
  FProfMemo.WordWrap := False;
  FProfMemo.Font.Name := 'Consolas';

  FProfTimer := TTimer.Create(Self);
  FProfTimer.Enabled := False;
  FProfTimer.OnTimer := HandleProfTimer;

  ProfLog('delphi-terminal perf profiler -- version ' + AppVersionStr);
  ProfLog('Pick a command and Run; results append to ProfileResults.csv. Build with PROFILE_COMMANDS for an auto batch.');
  if CProfileBatch then
    ProfLog('PROFILE_COMMANDS build: the full command set will run automatically, then the app exits.');
end;

procedure TfrmMain.ProfLog(const ALine: string);
begin
  if FProfMemo = nil then
    Exit;
  FProfMemo.Lines.Add(ALine);
  FProfMemo.SelStart := Length(FProfMemo.Text);
  FProfMemo.Perform(EM_SCROLLCARET, 0, 0);
end;

procedure TfrmMain.WriteCsvRow(const AReason: string; AElapsedMs, ACharsPerSec: Double);
var
  LFS: TFormatSettings;
  LFile: TextFile;
  LNew: Boolean;
  LBackend: string;
begin
  LFS := TFormatSettings.Create;
  LFS.DecimalSeparator := '.';
  LFS.ThousandSeparator := #0;

  if FProfActiveFrame <> nil then
    LBackend := BackendName(FProfActiveFrame.BackendKind)
  else
    LBackend := 'n/a';

  LNew := not FileExists(FProfCsvPath);
  AssignFile(LFile, FProfCsvPath);
  if LNew then Rewrite(LFile) else Append(LFile);
  try
    if LNew then
      Writeln(LFile, 'version,timestamp,uniqueID,shell,backend,reason,repeat,cols,rows,chars,elapsedMs,charsPerSec,chunks,passes,memStartKB,memPeakKB,memEndKB');
    Writeln(LFile, Format('%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%.1f,%.0f,%d,%d,%u,%u,%u',
      [AppVersionStr, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), FProfCmd.UniqueID,
       ShellName(FProfCmd.Shell), LBackend, AReason, FProfRepeat, FProfCmd.Cols, FProfCmd.Rows,
       FProfChars, AElapsedMs, ACharsPerSec, FProfChunks, FProfPasses,
       FProfMemStart, FProfMemPeak, FProfMemEnd], LFS));
  finally
    CloseFile(LFile);
  end;

  ProfLog(Format('%-18s %-4s/%-6s r%d: %d chars, %.0f ms, %.0f c/s | chunks %d passes %d | mem %u/%u/%u KB (%s)',
    [FProfCmd.UniqueID, ShellName(FProfCmd.Shell), LBackend, FProfRepeat + 1, FProfChars,
     AElapsedMs, ACharsPerSec, FProfChunks, FProfPasses,
     FProfMemStart, FProfMemPeak, FProfMemEnd, AReason], LFS));
end;

procedure TfrmMain.StartProfileRun(const ACmd: TProfiledCommand; ARepeat: Integer);
var
  LFrame: TframeCmdShell;
begin
  LFrame := FrameForShell(ACmd.Shell);
  FProfCmd := ACmd;
  FProfRepeat := ARepeat;
  FProfActiveFrame := LFrame;

  if (LFrame = nil) or (not LFrame.ShellAvailable) then
  begin
    WriteCsvRow('unavailable', 0, 0);
    if FProfExitCode = 0 then
      FProfExitCode := 2;
    AdvanceBatchOrIdle(True);   // skip the rest of this command's repeats
    Exit;
  end;

  PageControl1.ActivePage := TabForShell(ACmd.Shell);

  // The profiler measures the ConPTY pipeline (#77 target), independent of the
  // demo's DEBUG-gated default; the frame falls back to legacy at runtime if
  // ConPTY is unavailable.
  LFrame.BackendKind := tbConPty;

  // Fresh, isolated shell pinned to a known size for reproducibility.
  LFrame.SetFixedTerminalSize(ACmd.Cols, ACmd.Rows);
  LFrame.RestartShell;

  FProfChars := 0;
  FProfChunks := 0;
  FProfPasses := 0;
  FProfMemStart := CurrentWorkingSetKB;
  FProfMemPeak := FProfMemStart;
  FProfMemEnd := FProfMemStart;
  QueryPerformanceFrequency(FProfFreq);
  QueryPerformanceCounter(FProfStartQPC);

  FProfiling := True;
  FProfState := psRunning;
  FProfRunBtn.Enabled := False;
  FProfStopBtn.Enabled := True;

  if ACmd.EndAfterSeconds > 0 then
    FProfTimer.Interval := ACmd.EndAfterSeconds * 1000
  else
    FProfTimer.Interval := PROF_SAFETY_CAP_MS;
  FProfTimer.Enabled := True;

  ProfLog(Format('RUN %s [%s] rep %d/%d ...', [ACmd.UniqueID, ShellName(ACmd.Shell), ARepeat + 1, ACmd.Repeats]));
  LFrame.RunCommandLine(ACmd.Command);
  if ACmd.EndAfterSeconds = 0 then
    LFrame.RunCommandLine('exit');   // bounded: exit signals "done"
end;

procedure TfrmMain.FinishProfileRun(const AReason: string);
var
  LEndQPC: Int64;
  LElapsedMs, LCharsPerSec: Double;
begin
  if not FProfiling then
    Exit;
  FProfiling := False;
  FProfTimer.Enabled := False;

  QueryPerformanceCounter(LEndQPC);
  if FProfFreq > 0 then
    LElapsedMs := (LEndQPC - FProfStartQPC) * 1000 / FProfFreq
  else
    LElapsedMs := 0;
  if FProfCmd.CaptureMemory then
    FProfMemEnd := CurrentWorkingSetKB;
  if LElapsedMs > 0 then
    LCharsPerSec := FProfChars * 1000 / LElapsedMs
  else
    LCharsPerSec := 0;

  if FProfActiveFrame <> nil then
    FProfActiveFrame.ClearFixedTerminalSize;

  WriteCsvRow(AReason, LElapsedMs, LCharsPerSec);
  FProfStopBtn.Enabled := False;
  AdvanceBatchOrIdle(False);
end;

procedure TfrmMain.AdvanceBatchOrIdle(ASkipCommand: Boolean);
begin
  if FProfBatchIndex < 0 then
  begin
    // interactive single run
    FProfState := psIdle;
    FProfRunBtn.Enabled := True;
    Exit;
  end;

  if ASkipCommand then
    FProfRepeat := FProfCmd.Repeats - 1;   // force move to the next command

  Inc(FProfRepeat);
  if FProfRepeat >= FProfCmd.Repeats then
  begin
    FProfRepeat := 0;
    Inc(FProfBatchIndex);
  end;

  if FProfBatchIndex >= Length(CProfiledCommands) then
  begin
    FinishBatch;
    Exit;
  end;

  // Settle (previous shell teardown / restart) before the next run.
  FProfState := psBetween;
  FProfTimer.Interval := PROF_BETWEEN_MS;
  FProfTimer.Enabled := True;
end;

procedure TfrmMain.StartNextBatchRun;
begin
  StartProfileRun(CProfiledCommands[FProfBatchIndex], FProfRepeat);
end;

procedure TfrmMain.StartBatch;
begin
  FProfBatchStarted := True;
  FProfExitCode := 0;
  FProfBatchIndex := 0;
  FProfRepeat := 0;
  FProfCsvPath := ExtractFilePath(Application.ExeName) + 'ProfileResults' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.csv';
  ProfLog('BATCH START -> ' + FProfCsvPath);
  FProfState := psBetween;
  FProfTimer.Interval := PROF_STARTUP_MS;
  FProfTimer.Enabled := True;
end;

procedure TfrmMain.FinishBatch;
begin
  ProfLog(Format('BATCH COMPLETE (%d commands) -> %s', [Length(CProfiledCommands), FProfCsvPath]));
  FProfState := psIdle;
  ExitCode := FProfExitCode;
  if CProfileBatch then
    Application.Terminate;
end;

procedure TfrmMain.HandleFormShow(Sender: TObject);
begin
  if CProfileBatch and (not FProfBatchStarted) then
    StartBatch;
end;

procedure TfrmMain.HandleProfRun(Sender: TObject);
begin
  if FProfiling or (FProfCombo.ItemIndex < 0) then
    Exit;
  FProfBatchIndex := -1;   // interactive
  FProfCsvPath := ExtractFilePath(Application.ExeName) + 'ProfileResults.csv';
  StartProfileRun(CProfiledCommands[FProfCombo.ItemIndex], 0);
end;

procedure TfrmMain.HandleProfStop(Sender: TObject);
begin
  if not FProfiling then
    Exit;
  if FProfActiveFrame <> nil then
    FProfActiveFrame.StopShell;
  FinishProfileRun('manual');
end;

procedure TfrmMain.HandleProfTimer(Sender: TObject);
begin
  case FProfState of
    psRunning:
      begin
        // measurement window (timed) or safety cap (bounded) elapsed -> terminate + report
        if FProfActiveFrame <> nil then
          FProfActiveFrame.StopShell;
        if FProfCmd.EndAfterSeconds > 0 then
          FinishProfileRun('timed')
        else
          FinishProfileRun('capped');
      end;
    psBetween:
      begin
        FProfTimer.Enabled := False;
        StartNextBatchRun;
      end;
  end;
end;

procedure TfrmMain.HandleProfOutput(Sender: TObject; ACharCount: Integer);
begin
  if (not FProfiling) or (Sender <> FProfActiveFrame) then
    Exit;
  Inc(FProfChars, ACharCount);
  Inc(FProfChunks);
  if FProfCmd.CaptureMemory then
  begin
    FProfMemEnd := CurrentWorkingSetKB;
    if FProfMemEnd > FProfMemPeak then
      FProfMemPeak := FProfMemEnd;
  end;
end;

procedure TfrmMain.HandleProfPass(Sender: TObject);
begin
  if FProfiling and (Sender = FProfActiveFrame) then
    Inc(FProfPasses);
end;

procedure TfrmMain.HandleProfExit(Sender: TObject);
begin
  if FProfiling and (Sender = FProfActiveFrame) then
    FinishProfileRun('exit');   // bounded command's `exit` reached -> done
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FFramePowerShell.StopShell;
  FFramePwsh.StopShell;
  FFrameCmdShell.StopShell;
  FFrameWSL.StopShell;
  FTermParser.Free;
  FTermBuffer.Free;
end;

procedure TfrmMain.HandleRequestDir(Sender: TObject; var APath: string);
var
  Dir: string;
begin
  Dir := '';
  if SelectDirectory('Select Directory', '', Dir) then
    APath := Dir;
end;

initialization
finalization
ReleaseTerminalSettings;

end.
