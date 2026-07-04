unit Test.Delphi.Terminal.ConPty;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TConPtyTests = class
  public
    ///<summary>Start cmd.exe via TConPty and confirm TConPtyReader delivers the ConPTY VT output stream to the main thread.</summary>
    [Test]
    procedure Session_DeliversConsoleOutput;
    ///<summary>Deliberate teardown of an interactive session must join the reader and close without hanging.</summary>
    [Test]
    procedure DeliberateTeardown_DoesNotHang;
    ///<summary>The child process must be assigned to TConPty's kill-on-close Job Object (so descendants die on Close).</summary>
    [Test]
    procedure ChildIsAssignedToJob;
    ///<summary>The build gate (CONPTY_MIN_BUILD) excludes pre-1903 builds and admits 1903+.</summary>
    [Test]
    procedure BuildGate_ExcludesBelow1903;
  end;

  [TestFixture]
  TConPtyShellTests = class
  public
    ///<summary>The ConPTY backend implements ITerminalProcess.</summary>
    [Test]
    procedure ImplementsITerminalProcess;
    ///<summary>Starting a shell delivers ConPTY output via OnOutput, then closes cleanly.</summary>
    [Test]
    procedure DeliversOutputThenTerminates;
    ///<summary>A child that exits on its own raises OnProcessExit (via the process-exit watcher).</summary>
    [Test]
    procedure DetectsNaturalExit;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  WinAPI.ConPty,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.Pty,
  Delphi.Terminal.ConPtyReader,
  Delphi.Terminal.ConPtyShell;

// IsProcessInJob with its out parameter bound as a 4-byte BOOL. The RTL declares
// it as ByteBool, but the Win32 API writes a full BOOL, so use our own binding.
function IsProcessInJobBOOL(ProcessHandle, JobHandle: THandle; var Result: BOOL): BOOL; stdcall;
  external kernel32 name 'IsProcessInJob';

type
  TOutputCollector = class
  public
    Output: string;
    Exited: Boolean;
    procedure HandleOutput(Sender: TObject; const AText: string);
    procedure HandleExit(Sender: TObject);
  end;

procedure TOutputCollector.HandleOutput(Sender: TObject; const AText: string);
begin
  Output := Output + AText;
end;

procedure TOutputCollector.HandleExit(Sender: TObject);
begin
  Exited := True;
end;

procedure TConPtyTests.Session_DeliversConsoleOutput;
var
  LPty: TConPty;
  LReader: TConPtyReader;
  LCollector: TOutputCollector;
  LDeadline: UInt64;
  LOutput: string;
begin
  LPty := TConPty.Create;
  try
    if not LPty.IsAvailable then
    begin
      Assert.Pass('ConPTY not available on this OS (requires Windows 10 1809+); skipping.');
      Exit;
    end;

    LOutput := '';
    LCollector := TOutputCollector.Create;
    LReader := nil;
    try
      Assert.IsTrue(LPty.Start('cmd.exe', ''), 'TConPty.Start failed');

      LReader := TConPtyReader.Create(LPty.OutputRead, LCollector.HandleOutput, LCollector.HandleExit);
      LPty.RegisterReader(LReader);

      // Drain the reader's queued output until the ConPTY VT stream arrives.
      // This proves the chain Start -> child -> ConPTY -> reader thread ->
      // main-thread delivery. Interpreting rendered frames (echo, cursor moves)
      // is the VT parser's job in a later phase, not this smoke test.
      LDeadline := GetTickCount64 + 5000;
      while (not LCollector.Output.Contains(#27)) and (GetTickCount64 < LDeadline) do
        CheckSynchronize(50);

      LReader.Terminate;   // deliberate teardown: suppress the exit callback
      LPty.Close;          // joins the reader, releases handles
      LOutput := LCollector.Output;
    finally
      LReader.Free;
      LCollector.Free;
    end;

    Assert.IsFalse(LPty.IsRunning, 'Session should not be running after Close');
    Assert.IsTrue(LOutput.Contains(#27), 'Expected ConPTY VT output (ESC) via the reader; got length ' + Length(LOutput).ToString);
  finally
    LPty.Free;
  end;
end;

procedure TConPtyTests.DeliberateTeardown_DoesNotHang;
var
  LPty: TConPty;
  LReader: TConPtyReader;
  LCollector: TOutputCollector;
begin
  LPty := TConPty.Create;
  try
    if not LPty.IsAvailable then
    begin
      Assert.Pass('ConPTY not available on this OS (requires Windows 10 1809+); skipping.');
      Exit;
    end;

    LCollector := TOutputCollector.Create;
    LReader := nil;
    try
      Assert.IsTrue(LPty.Start('cmd.exe', ''), 'TConPty.Start failed');

      LReader := TConPtyReader.Create(LPty.OutputRead, LCollector.HandleOutput, LCollector.HandleExit);
      LPty.RegisterReader(LReader);

      CheckSynchronize(200);   // let the shell spin up

      LReader.Terminate;
      LPty.Close;              // must return without hanging
    finally
      LReader.Free;
      LCollector.Free;
    end;

    Assert.IsFalse(LPty.IsRunning, 'Session should not be running after Close');
  finally
    LPty.Free;
  end;
end;

procedure TConPtyTests.ChildIsAssignedToJob;
var
  LPty: TConPty;
  LReader: TConPtyReader;
  LCollector: TOutputCollector;
  LInJob: BOOL;
  LPid: DWORD;
  LProbe: THandle;
  LExitCode: DWORD;
begin
  LPty := TConPty.Create;
  try
    if not LPty.IsAvailable then
    begin
      Assert.Pass('ConPTY not available on this OS (requires Windows 10 1809+); skipping.');
      Exit;
    end;

    LCollector := TOutputCollector.Create;
    LReader := nil;
    try
      Assert.IsTrue(LPty.Start('cmd.exe', ''), 'TConPty.Start failed');
      LReader := TConPtyReader.Create(LPty.OutputRead, LCollector.HandleOutput, LCollector.HandleExit);
      LPty.RegisterReader(LReader);

      // Job created and the child assigned to it. (Own binding for IsProcessInJob:
      // the RTL declares the out param as ByteBool but the Win32 API writes a
      // 4-byte BOOL, so pass a real BOOL here.)
      Assert.IsTrue(LPty.JobHandle <> 0, 'A Job Object should have been created');
      LInJob := False;
      Assert.IsTrue(IsProcessInJobBOOL(LPty.ProcessHandle, LPty.JobHandle, LInJob), 'IsProcessInJob call failed');
      Assert.IsTrue(LInJob, 'Child process should be assigned to the ConPTY job');

      LPid := GetProcessId(LPty.ProcessHandle);

      LReader.Terminate;
      LPty.Close;
    finally
      LReader.Free;
      LCollector.Free;
    end;

    Assert.IsFalse(LPty.IsRunning, 'Session should not be running after Close');

    // The child must be gone after Close (job kill / teardown).
    LProbe := OpenProcess(PROCESS_QUERY_INFORMATION, False, LPid);
    if LProbe <> 0 then
    begin
      LExitCode := STILL_ACTIVE;
      GetExitCodeProcess(LProbe, LExitCode);
      CloseHandle(LProbe);
      Assert.AreNotEqual(DWORD(STILL_ACTIVE), LExitCode, 'Child process should have terminated after Close');
    end;
  finally
    LPty.Free;
  end;
end;

procedure TConPtyTests.BuildGate_ExcludesBelow1903;
begin
  Assert.IsFalse(ConPtyBuildSupported(17763), 'Windows 1809 (17763) must be excluded');
  Assert.IsFalse(ConPtyBuildSupported(CONPTY_MIN_BUILD - 1), 'A build just below the threshold must be excluded');
  Assert.IsTrue(ConPtyBuildSupported(CONPTY_MIN_BUILD), 'Windows 1903 (18362) must be supported');
  Assert.IsTrue(ConPtyBuildSupported(19045), 'Later Windows 10 builds must be supported');
  Assert.IsTrue(ConPtyBuildSupported(22631), 'Windows 11 builds must be supported');
end;

{ TConPtyShellTests }

procedure TConPtyShellTests.ImplementsITerminalProcess;
var
  LShell: TConPtyShell;
  LIntf: ITerminalProcess;
begin
  LShell := TConPtyShell.Create;
  try
    Assert.IsTrue(Supports(LShell, ITerminalProcess, LIntf), 'TConPtyShell should implement ITerminalProcess');
    Assert.IsTrue(Assigned(LIntf), 'Interface reference should resolve');
  finally
    LShell.Free;
  end;
end;

procedure TConPtyShellTests.DeliversOutputThenTerminates;
var
  LShell: TConPtyShell;
  LCollector: TOutputCollector;
  LInfo: TCmdShellInfo;
  LDeadline: UInt64;
  LGotOutput: Boolean;
begin
  if not TConPtyShell.IsSupported then
  begin
    Assert.Pass('ConPTY not available on this OS; skipping.');
    Exit;
  end;

  LShell := TConPtyShell.Create;
  LCollector := TOutputCollector.Create;
  try
    LShell.OnOutput := LCollector.HandleOutput;
    LInfo := TCmdUtils.CreateCmdShellInfo(TCmdShellType.CMD);
    LShell.Start(LInfo, '', DefaultTerminalSize);

    LDeadline := GetTickCount64 + 5000;
    while (not LCollector.Output.Contains(#27)) and (GetTickCount64 < LDeadline) do
      CheckSynchronize(50);

    LGotOutput := LCollector.Output.Contains(#27);
  finally
    LShell.Terminate;
    LShell.Free;
    LCollector.Free;
  end;

  Assert.IsTrue(LGotOutput, 'Backend should deliver ConPTY VT output via OnOutput');
end;

procedure TConPtyShellTests.DetectsNaturalExit;
var
  LShell: TConPtyShell;
  LCollector: TOutputCollector;
  LInfo: TCmdShellInfo;
  LDeadline: UInt64;
  LExited: Boolean;
begin
  if not TConPtyShell.IsSupported then
  begin
    Assert.Pass('ConPTY not available on this OS; skipping.');
    Exit;
  end;

  LShell := TConPtyShell.Create;
  LCollector := TOutputCollector.Create;
  try
    LShell.OnProcessExit := LCollector.HandleExit;
    LInfo := TCmdUtils.CreateCmdShellInfo(TCmdShellType.CMD);
    LInfo.Parameters := '/c exit';   // exits immediately on its own
    LShell.Start(LInfo, '', DefaultTerminalSize);

    LDeadline := GetTickCount64 + 5000;
    while (not LCollector.Exited) and (GetTickCount64 < LDeadline) do
      CheckSynchronize(50);

    LExited := LCollector.Exited;
  finally
    LShell.Terminate;
    LShell.Free;
    LCollector.Free;
  end;

  Assert.IsTrue(LExited, 'OnProcessExit should fire when the child exits on its own (process-exit watcher)');
end;

initialization
  TDUnitX.RegisterTestFixture(TConPtyTests);
  TDUnitX.RegisterTestFixture(TConPtyShellTests);

end.
