(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  ConPTY-backed ITerminalProcess. Owns a TConPty session and a TConPtyReader,
  translates the ITerminalProcess contract onto them, and detects natural child
  exit via a process-handle watcher (reader EOF does not fire until the
  pseudoconsole is closed -- see #57).

*)
unit Delphi.Terminal.ConPtyShell;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.Pty,
  Delphi.Terminal.ConPtyReader;

type
  TConPtyShell = class(TObject, ITerminalProcess)
  private
    FPty: TConPty;
    FReader: TConPtyReader;
    FWatcher: TThread;
    FTerminating: Boolean;
    FExited: Boolean;
    FOnOutput: TOutputEvent;
    FOnProcessExit: TNotifyEvent;
    procedure HandleReaderOutput(Sender: TObject; const AText: string);
    procedure HandleReaderExit(Sender: TObject);
    procedure HandleChildExit;   // TThreadMethod queued by the exit watcher
    procedure DoChildExit;
  protected
    { non-reference-counted IInterface: lifetime stays with the explicit owner }
    function QueryInterface(const IID: TGUID; out Obj): HRESULT; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    { ITerminalProcess accessors }
    function GetRunning: Boolean;
    function GetOnOutput: TOutputEvent;
    procedure SetOnOutput(const AValue: TOutputEvent);
    function GetOnProcessExit: TNotifyEvent;
    procedure SetOnProcessExit(const AValue: TNotifyEvent);
  public
    constructor Create;
    destructor Destroy; override;
    ///<summary>True when ConPTY is available on this system (Windows 10 1903+).</summary>
    class function IsSupported: Boolean;
    procedure Start(const AShellInfo: TCmdShellInfo; const AWorkDir: string; const ASize: TTerminalSize);
    procedure WriteInput(const AText: string);
    procedure SendInterrupt;
    procedure Resize(const ASize: TTerminalSize);
    procedure DiscardQueuedOutput;
    function HasForegroundChild: Boolean;
    procedure Terminate;
    property Running: Boolean read GetRunning;
    property OnOutput: TOutputEvent read FOnOutput write FOnOutput;
    property OnProcessExit: TNotifyEvent read FOnProcessExit write FOnProcessExit;
  end;

implementation

type
  { Watches the child process handle and fires a callback (marshaled to the main
    thread) when it exits -- the reliable way to detect a shell that exits on its
    own under ConPTY, where the output pipe does not reach EOF until teardown. }
  TProcessExitWatcher = class(TThread)
  private
    FProcessHandle: THandle;
    FOnExit: TThreadMethod;
  protected
    procedure Execute; override;
  public
    constructor Create(AProcessHandle: THandle; const AOnExit: TThreadMethod);
  end;

constructor TProcessExitWatcher.Create(AProcessHandle: THandle; const AOnExit: TThreadMethod);
begin
  FProcessHandle := AProcessHandle;
  FOnExit := AOnExit;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TProcessExitWatcher.Execute;
begin
  while not Terminated do
  begin
    if WaitForSingleObject(FProcessHandle, 100) = WAIT_OBJECT_0 then
    begin
      if not Terminated then
        Queue(FOnExit);
      Break;
    end;
  end;
end;

{ TConPtyShell }

class function TConPtyShell.IsSupported: Boolean;
var
  LPty: TConPty;
begin
  LPty := TConPty.Create;
  try
    Result := LPty.IsAvailable;
  finally
    LPty.Free;
  end;
end;

constructor TConPtyShell.Create;
begin
  inherited Create;
  FPty := TConPty.Create;
end;

destructor TConPtyShell.Destroy;
begin
  Terminate;
  FPty.Free;
  inherited;
end;

procedure TConPtyShell.Start(const AShellInfo: TCmdShellInfo; const AWorkDir: string; const ASize: TTerminalSize);
var
  LCmdLine: string;
begin
  if FPty.IsRunning then
    Exit;
  FTerminating := False;
  FExited := False;

  // The caller supplies a TCmdShellInfo produced by TCmdUtils.CreateCmdShellInfo
  // (exe + parameters already resolved for CMD/pwsh/PowerShell/WSL); compose the
  // command line the pseudoconsole launches.
  LCmdLine := (AShellInfo.Exe + ' ' + AShellInfo.Parameters).Trim;
  if not FPty.Start(LCmdLine, AWorkDir, ASize) then
    raise Exception.CreateFmt('ConPTY session failed to start: %s', [AShellInfo.Exe]);

  FReader := TConPtyReader.Create(FPty.OutputRead, HandleReaderOutput, HandleReaderExit);
  FPty.RegisterReader(FReader);

  // Natural child exit does not produce reader EOF under ConPTY, so watch the
  // process handle to detect it (see the #57 insight note).
  FWatcher := TProcessExitWatcher.Create(FPty.ProcessHandle, HandleChildExit);
end;

procedure TConPtyShell.WriteInput(const AText: string);
var
  LBytes: TBytes;
  LWritten: DWORD;
begin
  if not FPty.IsRunning then
    Exit;
  LBytes := TEncoding.UTF8.GetBytes(AText);
  if Length(LBytes) = 0 then
    Exit;
  WriteFile(FPty.InputWrite, LBytes[0], Length(LBytes), LWritten, nil);
end;

procedure TConPtyShell.SendInterrupt;
begin
  WriteInput(#3);   // Ctrl+C (ETX) delivered as ConPTY input
end;

procedure TConPtyShell.Resize(const ASize: TTerminalSize);
begin
  FPty.Resize(ASize);
end;

procedure TConPtyShell.DiscardQueuedOutput;
begin
  // No-op: ConPTY output is delivered promptly by the reader and is not
  // separately buffered here. Screen-state clearing belongs to the renderer.
end;

function TConPtyShell.HasForegroundChild: Boolean;
begin
  // The Job Object holds the shell plus any descendants. More than one live process
  // means the shell has a foreground command running (its own count is 1 at an idle
  // prompt). A failed/unavailable query (-1) reports False so the gate does not block.
  Result := FPty.IsRunning and (FPty.ActiveProcessCount > 1);
end;

procedure TConPtyShell.Terminate;
begin
  FTerminating := True;

  // Stop the exit watcher before Close releases the process handle it waits on,
  // and drop any exit callback it may have already queued.
  if Assigned(FWatcher) then
  begin
    FWatcher.Terminate;
    FWatcher.WaitFor;
    TThread.RemoveQueuedEvents(FWatcher);
    FreeAndNil(FWatcher);
  end;

  if Assigned(FReader) then
    FReader.Terminate;   // suppress the reader's natural-exit callback

  FPty.Close;            // joins the reader, closes handles, kills the job tree
  FreeAndNil(FReader);
end;

procedure TConPtyShell.HandleReaderOutput(Sender: TObject; const AText: string);
begin
  if Assigned(FOnOutput) then
    FOnOutput(Self, AText);
end;

procedure TConPtyShell.HandleReaderExit(Sender: TObject);
begin
  DoChildExit;
end;

procedure TConPtyShell.HandleChildExit;
begin
  DoChildExit;
end;

procedure TConPtyShell.DoChildExit;
begin
  if FExited or FTerminating then
    Exit;
  FExited := True;
  if Assigned(FOnProcessExit) then
    FOnProcessExit(Self);
end;

function TConPtyShell.GetRunning: Boolean;
begin
  Result := FPty.IsRunning and not FExited;
end;

function TConPtyShell.GetOnOutput: TOutputEvent;
begin
  Result := FOnOutput;
end;

procedure TConPtyShell.SetOnOutput(const AValue: TOutputEvent);
begin
  FOnOutput := AValue;
end;

function TConPtyShell.GetOnProcessExit: TNotifyEvent;
begin
  Result := FOnProcessExit;
end;

procedure TConPtyShell.SetOnProcessExit(const AValue: TNotifyEvent);
begin
  FOnProcessExit := AValue;
end;

function TConPtyShell.QueryInterface(const IID: TGUID; out Obj): HRESULT;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TConPtyShell._AddRef: Integer;
begin
  Result := -1;
end;

function TConPtyShell._Release: Integer;
begin
  Result := -1;
end;

end.
