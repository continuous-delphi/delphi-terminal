(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  TConPty owns a single ConPTY session. It hides all of the Win32 mechanics
  (pipe creation, CreatePseudoConsole, the process-thread attribute list, and
  the extended-startupinfo spawn) behind Start / Resize / Close, and manages
  the lifetime of the handles it creates.

  It does NOT own a reader thread or raise output/exit events -- those belong to
  the ConPTY backend layered above this class (mirroring TCmdShellProcess for
  the legacy pipe path). Callers read child output from OutputRead and write
  child input to InputWrite.

*)
unit Delphi.Terminal.Pty;

interface
uses
  WinAPI.Windows,
  WinAPI.ConPty;

type

  TTerminalSize = record
    Cols: SmallInt;
    Rows: SmallInt;
  end;


  ///<summary>Minimal contract for a reader that consumes TConPty.OutputRead. Registered with TConPty so Close can join it at the correct point during teardown.</summary>
  IPtyReader = interface
    ['{5A5E2E7C-0E8E-4E2E-9E1B-2B6E9C7A1F3D}']
    ///<summary>Blocks until the reader has stopped (after draining OutputRead to EOF).</summary>
    procedure Join;
  end;


  TConPty = class
  private
    FConPtyAPI: TConPtyAPI;
    FIsAvailable: Boolean;
    FhPC: HPCON;
    FInputWrite: THandle;
    FOutputRead: THandle;
    FProcessInfo: TProcessInformation;
    FIsRunning: Boolean;
    FSize: TCoord;
    FReader: IPtyReader;
    FJob: THandle;
    function GetProcessHandle: THandle;
    function BuildStartupInfo(out ASI: TStartupInfoExW): Boolean;
    procedure FreeStartupInfo(var ASI: TStartupInfoExW);
  public
    constructor Create;
    destructor Destroy; override;

    ///<summary>Starts a shell/command inside a new pseudoconsole. Creates the pipes, pseudoconsole and child process internally.</summary>
    function Start(const ACommandLine, AWorkDir: string): Boolean; overload;
    function Start(const ACommandLine, AWorkDir: string; const ASize: TTerminalSize): Boolean; overload;

    ///<summary>Resizes the pseudoconsole buffers.</summary>
    function Resize(const ASize: TTerminalSize): Boolean;

    ///<summary>Registers the reader that consumes OutputRead so Close can join it before closing that handle. Non-owning: the caller retains ownership and frees the reader after Close returns.</summary>
    procedure RegisterReader(const AReader: IPtyReader);

    ///<summary>Tears down the session and releases all owned handles. Joins the registered reader (if any) between closing the pseudoconsole and closing the output handle.</summary>
    procedure Close;

    ///<summary>Write child input (stdin) to this handle.</summary>
    property InputWrite: THandle read FInputWrite;

    ///<summary>Read child output (stdout/stderr) from this handle.</summary>
    property OutputRead: THandle read FOutputRead;

    property IsAvailable: Boolean read FIsAvailable;
    property ProcessHandle: THandle read GetProcessHandle;
    property IsRunning: Boolean read FIsRunning;
    ///<summary>Job Object the child (and its descendants) are assigned to; closed by Close to terminate the tree.</summary>
    property JobHandle: THandle read FJob;
  end;


const
  DefaultTerminalSize: TTerminalSize = (Cols: 80; Rows: 24);

implementation
uses
  System.SysUtils;


constructor TConPty.Create;
begin
  inherited Create;
  FInputWrite := INVALID_HANDLE_VALUE;
  FOutputRead := INVALID_HANDLE_VALUE;
  FIsAvailable := FConPtyAPI.Initialize;
end;


destructor TConPty.Destroy;
begin
  Close;
  inherited;
end;


function TConPty.GetProcessHandle: THandle;
begin
  Result := FProcessInfo.hProcess;
end;


function TConPty.BuildStartupInfo(out ASI: TStartupInfoExW): Boolean;
var
  LSize: SIZE_T;
begin
  Result := False;
  ZeroMemory(@ASI, SizeOf(ASI));
  ASI.StartupInfo.cb := SizeOf(TStartupInfoExW);

  // First call returns the required buffer size in LSize.
  LSize := 0;
  FConPtyAPI.InitializeProcThreadAttributeList(nil, 1, 0, @LSize);
  if LSize = 0 then
    Exit;

  ASI.lpAttributeList := AllocMem(LSize);
  if not Assigned(ASI.lpAttributeList) then
    Exit;

  if not FConPtyAPI.InitializeProcThreadAttributeList(ASI.lpAttributeList, 1, 0, @LSize) then
  begin
    FreeMem(ASI.lpAttributeList);
    ASI.lpAttributeList := nil;
    Exit;
  end;

  // Associate the pseudoconsole with the child process. lpValue is the HPCON
  // value itself, cbSize is its size.
  if not FConPtyAPI.UpdateProcThreadAttribute(ASI.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, Pointer(FhPC), SizeOf(FhPC), nil, nil) then
  begin
    FConPtyAPI.DeleteProcThreadAttributeList(ASI.lpAttributeList);
    FreeMem(ASI.lpAttributeList);
    ASI.lpAttributeList := nil;
    Exit;
  end;

  Result := True;
end;


procedure TConPty.FreeStartupInfo(var ASI: TStartupInfoExW);
begin
  if Assigned(ASI.lpAttributeList) then
  begin
    FConPtyAPI.DeleteProcThreadAttributeList(ASI.lpAttributeList);
    FreeMem(ASI.lpAttributeList);
    ASI.lpAttributeList := nil;
  end;
end;


function TConPty.Start(const ACommandLine, AWorkDir: string): Boolean;
begin
  Result := Start(ACommandLine, AWorkDir, DefaultTerminalSize);
end;

function TConPty.Start(const ACommandLine, AWorkDir: string; const ASize: TTerminalSize): Boolean;
var
  LPtyInputRead, LPtyOutputWrite: THandle;
  LSI: TStartupInfoExW;
  LCmd: string;
  LWorkDir: PChar;
  LResult: HRESULT;
  LJobInfo: TJobObjectExtendedLimitInformation;
begin
  Result := False;
  if IsRunning or (not IsAvailable) then
    Exit;

  FSize.X := ASize.Cols;
  FSize.Y := ASize.Rows;

  LPtyInputRead := INVALID_HANDLE_VALUE;
  LPtyOutputWrite := INVALID_HANDLE_VALUE;
  FInputWrite := INVALID_HANDLE_VALUE;
  FOutputRead := INVALID_HANDLE_VALUE;

  // Two pipes. The PTY-side ends (input-read, output-write) are handed to the
  // pseudoconsole; we keep only our input-write and output-read ends.
  if not CreatePipe(LPtyInputRead, FInputWrite, nil, 0) then
    Exit;
  if not CreatePipe(FOutputRead, LPtyOutputWrite, nil, 0) then
  begin
    CloseHandle(LPtyInputRead);
    CloseHandle(FInputWrite);
    FInputWrite := INVALID_HANDLE_VALUE;
    Exit;
  end;

  LResult := FConPtyAPI.CreatePseudoConsole(FSize, LPtyInputRead, LPtyOutputWrite, 0, FhPC);

  // The PTY-side handles are duplicated into the console host; close our copies
  // now so the output pipe reports EOF once the console host is gone.
  CloseHandle(LPtyInputRead);
  CloseHandle(LPtyOutputWrite);

  if Failed(LResult) then
  begin
    CloseHandle(FInputWrite);
    CloseHandle(FOutputRead);
    FInputWrite := INVALID_HANDLE_VALUE;
    FOutputRead := INVALID_HANDLE_VALUE;
    FhPC := 0;
    Exit;
  end;

  if not BuildStartupInfo(LSI) then
  begin
    Close;
    Exit;
  end;

  // CreateProcess may modify the command-line buffer, so pass a unique copy.
  LCmd := ACommandLine;
  UniqueString(LCmd);
  if AWorkDir <> '' then
    LWorkDir := PChar(AWorkDir)
  else
    LWorkDir := nil;

  // Create a kill-on-close Job Object so tearing it down terminates the entire
  // child tree (shell + descendants, e.g. node.exe spawned by Claude Code).
  FJob := CreateJobObject(nil, nil);
  if FJob <> 0 then
  begin
    ZeroMemory(@LJobInfo, SizeOf(LJobInfo));
    LJobInfo.BasicLimitInformation.LimitFlags := JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(FJob, JobObjectExtendedLimitInformation, @LJobInfo, SizeOf(LJobInfo));
  end;

  // bInheritHandles = False: the pseudoconsole attribute delivers the handles, so
  // we avoid leaking every inheritable handle of the host (IDE) into the child.
  // CREATE_SUSPENDED so the child is assigned to the job before it can spawn.
  Result := CreateProcess(nil, PChar(LCmd), nil, nil, False, EXTENDED_STARTUPINFO_PRESENT or CREATE_SUSPENDED, nil, LWorkDir, LSI.StartupInfo, FProcessInfo);

  FreeStartupInfo(LSI);

  if Result then
  begin
    if FJob <> 0 then
      AssignProcessToJobObject(FJob, FProcessInfo.hProcess);
    ResumeThread(FProcessInfo.hThread);
    FIsRunning := True;
  end
  else
    Close;
end;


function TConPty.Resize(const ASize: TTerminalSize): Boolean;
var
  LSize: TCoord;
begin
  Result := False;
  if (FhPC = 0) or (not Assigned(FConPtyAPI.ResizePseudoConsole)) then
    Exit;
  LSize.X := ASize.Cols;
  LSize.Y := ASize.Rows;
  Result := Succeeded(FConPtyAPI.ResizePseudoConsole(FhPC, LSize));
  if Result then
    FSize := LSize;
end;


procedure TConPty.RegisterReader(const AReader: IPtyReader);
begin
  FReader := AReader;
end;


procedure TConPty.Close;
begin
  FIsRunning := False;

  // 1. Close our input-write end so the child sees stdin close.
  if FInputWrite <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FInputWrite);
    FInputWrite := INVALID_HANDLE_VALUE;
  end;

  // 2. Close the pseudoconsole. The console host drains its remaining output
  //    into the still-running registered reader, then closes its end of the
  //    output pipe, letting the reader on OutputRead see EOF.
  if FhPC <> 0 then
  begin
    if Assigned(FConPtyAPI.ClosePseudoConsole) then
      FConPtyAPI.ClosePseudoConsole(FhPC);
    FhPC := 0;
  end;

  // 3. Join the registered reader (if any) so it is finished with OutputRead
  //    before we close that handle. Non-owning: the caller frees it afterwards.
  if Assigned(FReader) then
  begin
    FReader.Join;
    FReader := nil;
  end;

  // 4. Close our output-read end (safe now: no reader is touching it).
  if FOutputRead <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FOutputRead);
    FOutputRead := INVALID_HANDLE_VALUE;
  end;

  // 5. Terminate the whole child tree: closing the job handle triggers
  //    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, killing the shell and all descendants.
  if FJob <> 0 then
  begin
    CloseHandle(FJob);
    FJob := 0;
  end;

  // 6. Reclaim the child process; terminate it if it lingers past the grace
  //    period (e.g. job assignment failed), then release the process/thread handles.
  if FProcessInfo.hProcess <> 0 then
  begin
    if WaitForSingleObject(FProcessInfo.hProcess, 5000) <> WAIT_OBJECT_0 then
      TerminateProcess(FProcessInfo.hProcess, 0);
    CloseHandle(FProcessInfo.hProcess);
    FProcessInfo.hProcess := 0;
  end;
  if FProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FProcessInfo.hThread);
    FProcessInfo.hThread := 0;
  end;
end;


end.
