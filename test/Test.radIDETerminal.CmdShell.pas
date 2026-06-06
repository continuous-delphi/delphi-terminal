unit Test.radIDETerminal.CmdShell;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes,
  radIDETerminal.CmdShell;

type

  [TestFixture]
  TTestCmdShellProcess = class
  private
    FShell: TCmdShellProcess;
    FOutput: string;
    procedure HandleOutput(Sender: TObject; const AText: string);
    procedure DrainQueue(ATimeoutMs: Integer);
    procedure DrainQueueUntil(const AMarker: string; ATimeoutMs: Integer = 5000);
  public

    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure CmdShouldStartAndReportRunning;
    [Test] procedure CmdShouldProduceOutputFromEcho;
    [Test] procedure CmdShouldPersistSessionState;
    [Test] procedure CmdShouldTerminateCleanly;

    [Test] procedure PwshShouldStartAndReportRunning;
    [Test] procedure PwshShouldProduceOutputFromEcho;
    [Test] procedure PwshShouldPersistSessionState;
    [Test] procedure PwshShouldTerminateCleanly;
    [Test] procedure PwshOutputShouldBeAnsiFreeDueToNoColor;

    [Test] procedure LegacyPSShouldStartAndReportRunning;
    [Test] procedure LegacyPSShouldProduceOutput;
    [Test] procedure LegacyPSShouldTerminateCleanly;
  end;

implementation

uses
  Winapi.Windows;

procedure TTestCmdShellProcess.Setup;
begin
  FOutput := '';
  FShell := TCmdShellProcess.Create;
  FShell.OnOutput := HandleOutput;
end;

procedure TTestCmdShellProcess.TearDown;
begin
  FShell.Free;
end;

procedure TTestCmdShellProcess.HandleOutput(Sender: TObject; const AText: string);
begin
  FOutput := FOutput + AText;
end;

procedure TTestCmdShellProcess.DrainQueue(ATimeoutMs: Integer);
var
  Start: Cardinal;
begin
  Start := GetTickCount;
  while GetTickCount - Start < Cardinal(ATimeoutMs) do
  begin
    CheckSynchronize(10);
    Sleep(10);
  end;
end;

procedure TTestCmdShellProcess.DrainQueueUntil(const AMarker: string; ATimeoutMs: Integer);
var
  Start: Cardinal;
begin
  Start := GetTickCount;
  while not FOutput.Contains(AMarker) and (GetTickCount - Start < Cardinal(ATimeoutMs)) do
  begin
    CheckSynchronize(10);
    Sleep(10);
  end;
end;

{ CMD tests }

procedure TTestCmdShellProcess.CmdShouldStartAndReportRunning;
begin
  FShell.Start('cmd.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'Shell should be running after Start');
end;

procedure TTestCmdShellProcess.CmdShouldProduceOutputFromEcho;
begin
  FShell.Start('cmd.exe', GetEnvironmentVariable('TEMP'));
  FOutput := '';
  FShell.SendCommand('echo TESTMARKER_CMD');
  DrainQueueUntil('TESTMARKER_CMD');
  Assert.IsTrue(FOutput.Contains('TESTMARKER_CMD'), 'Output should contain echoed text');
end;

procedure TTestCmdShellProcess.CmdShouldPersistSessionState;
begin
  FShell.Start('cmd.exe', GetEnvironmentVariable('TEMP'));
  FShell.SendCommand('set _RADIDE_TEST_VAR_=persist_ok');
  DrainQueue(500);
  FOutput := '';
  FShell.SendCommand('echo MARKER:%_RADIDE_TEST_VAR_%');
  DrainQueueUntil('MARKER:persist_ok');
  Assert.IsTrue(FOutput.Contains('MARKER:persist_ok'), 'Environment variable should persist across commands');
end;

procedure TTestCmdShellProcess.CmdShouldTerminateCleanly;
begin
  FShell.Start('cmd.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'Should be running before Terminate');
  FShell.Terminate;
  Assert.IsFalse(FShell.Running, 'Should not be running after Terminate');
end;

{ PowerShell tests }

procedure TTestCmdShellProcess.PwshShouldStartAndReportRunning;
begin
  FShell.Start('pwsh.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'PowerShell should be running after Start');
end;

procedure TTestCmdShellProcess.PwshShouldProduceOutputFromEcho;
begin
  FShell.Start('pwsh.exe', GetEnvironmentVariable('TEMP'));
  FOutput := '';
  FShell.SendCommand('Write-Output "TESTMARKER_PWSH"');
  DrainQueueUntil('TESTMARKER_PWSH');
  Assert.IsTrue(FOutput.Contains('TESTMARKER_PWSH'), 'Output should contain Write-Output text');
end;

procedure TTestCmdShellProcess.PwshShouldPersistSessionState;
begin
  FShell.Start('pwsh.exe', GetEnvironmentVariable('TEMP'));
  FShell.SendCommand('$_RADIDE_TEST_ = "persist_ok"');
  DrainQueue(500);
  FOutput := '';
  FShell.SendCommand('Write-Output "MARKER:$_RADIDE_TEST_"');
  DrainQueueUntil('MARKER:persist_ok');
  Assert.IsTrue(FOutput.Contains('MARKER:persist_ok'), 'Variable should persist across commands');
end;

procedure TTestCmdShellProcess.PwshShouldTerminateCleanly;
begin
  FShell.Start('pwsh.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'Should be running before Terminate');
  FShell.Terminate;
  Assert.IsFalse(FShell.Running, 'Should not be running after Terminate');
end;

procedure TTestCmdShellProcess.PwshOutputShouldBeAnsiFreeDueToNoColor;
begin
  FShell.Start('pwsh.exe', GetEnvironmentVariable('TEMP'));
  FOutput := '';
  FShell.SendCommand('Write-Output "NOCOLOR_CHECK"');
  DrainQueueUntil('NOCOLOR_CHECK');
  Assert.IsFalse(FOutput.Contains(#27'['), 'Output should not contain ANSI escape sequences (ESC[)');
end;

{ Legacy PowerShell (powershell.exe) tests }

procedure TTestCmdShellProcess.LegacyPSShouldStartAndReportRunning;
begin
  FShell.Start('powershell.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'Legacy PowerShell should be running after Start');
end;

procedure TTestCmdShellProcess.LegacyPSShouldProduceOutput;
begin
  FShell.Start('powershell.exe', GetEnvironmentVariable('TEMP'));
  FOutput := '';
  FShell.SendCommand('Write-Output "TESTMARKER_LEGACYPS"');
  DrainQueueUntil('TESTMARKER_LEGACYPS');
  Assert.IsTrue(FOutput.Contains('TESTMARKER_LEGACYPS'), 'Output should contain Write-Output text');
end;

procedure TTestCmdShellProcess.LegacyPSShouldTerminateCleanly;
begin
  FShell.Start('powershell.exe', GetEnvironmentVariable('TEMP'));
  Assert.IsTrue(FShell.Running, 'Should be running before Terminate');
  FShell.Terminate;
  Assert.IsFalse(FShell.Running, 'Should not be running after Terminate');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCmdShellProcess);

end.
