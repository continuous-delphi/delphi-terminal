(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.CmdShell;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows;

type
  TOutputEvent = procedure(Sender: TObject; const AText: string) of object;

  TCmdShellProcess = class
  private
    FStdInWrite: THandle;
    FStdOutRead: THandle;
    FProcessInfo: TProcessInformation;
    FReaderThread: TThread;
    FRunning: Boolean;
    FTerminating: Boolean;
    FOnOutput: TOutputEvent;
    FOnProcessExit: TNotifyEvent;
    FEncoding: TEncoding;
    procedure HandleNaturalExit;
  public
    constructor Create;
    destructor Destroy; override;
    class function EncodingForShell(const AShellExe: string): TEncoding;
    class function BuildEnvironmentBlock: TBytes;
    class function ChangeDirectoryCommand(const AShellExe, APath: string): string;
    procedure Start(const AShellExe: string; const AWorkDir: string = '');
    procedure SendCommand(const ACommand: string);
    procedure SendCtrlC;
    procedure Terminate;
    property Running: Boolean read FRunning;
    property OnOutput: TOutputEvent read FOnOutput write FOnOutput;
    property OnProcessExit: TNotifyEvent read FOnProcessExit write FOnProcessExit;
  end;

implementation

type
  TPipeReaderThread = class(TThread)
  private
    FPipeHandle: THandle;
    FOwner: TCmdShellProcess;
    FEncoding: TEncoding;
    procedure NotifyOutput(const AText: string);
    procedure NotifyExit;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCmdShellProcess; APipeHandle: THandle; AEncoding: TEncoding);
  end;

{ TPipeReaderThread }

constructor TPipeReaderThread.Create(AOwner: TCmdShellProcess; APipeHandle: THandle; AEncoding: TEncoding);
begin
  FOwner := AOwner;
  FPipeHandle := APipeHandle;
  FEncoding := AEncoding;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TPipeReaderThread.NotifyOutput(const AText: string);
var
  LText: string;
  LOwner: TCmdShellProcess;
begin
  LText := AText;
  LOwner := FOwner;
  TThread.Queue(Self,
    procedure
    begin
      if Assigned(LOwner.FOnOutput) then
        LOwner.FOnOutput(LOwner, LText);
    end);
end;

procedure TPipeReaderThread.NotifyExit;
var
  LOwner: TCmdShellProcess;
begin
  LOwner := FOwner;
  TThread.Queue(Self,
    procedure
    begin
      LOwner.HandleNaturalExit;
    end);
end;

procedure TPipeReaderThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
  Bytes: TBytes;
begin
  while not Terminated do
  begin
    if not ReadFile(FPipeHandle, Buffer[0], SizeOf(Buffer), BytesRead, nil) then
      Break;
    if BytesRead > 0 then
    begin
      SetLength(Bytes, BytesRead);
      Move(Buffer[0], Bytes[0], BytesRead);
      NotifyOutput(FEncoding.GetString(Bytes));
    end;
  end;
  if not FOwner.FTerminating then
    NotifyExit;
end;

{ TCmdShellProcess }

constructor TCmdShellProcess.Create;
begin
  inherited Create;
  FStdInWrite := INVALID_HANDLE_VALUE;
  FStdOutRead := INVALID_HANDLE_VALUE;
  FProcessInfo.hProcess := 0;
  FProcessInfo.hThread := 0;
end;

destructor TCmdShellProcess.Destroy;
begin
  Terminate;
  FEncoding.Free;
  inherited;
end;

class function TCmdShellProcess.EncodingForShell(const AShellExe: string): TEncoding;
var
  Lower: string;
begin
  Lower := LowerCase(ExtractFileName(AShellExe));
  if Lower.Contains('pwsh') or Lower.Contains('powershell') then
    Result := TEncoding.GetEncoding(65001)
  else
    Result := TEncoding.GetEncoding(GetOEMCP);
end;

class function TCmdShellProcess.BuildEnvironmentBlock: TBytes;
var
  EnvStrings: PChar;
  P: PChar;
  Block: string;
begin
  EnvStrings := GetEnvironmentStrings;
  try
    Block := '';
    P := EnvStrings;
    while P^ <> #0 do
    begin
      Block := Block + P + #0;
      Inc(P, StrLen(P) + 1);
    end;
    {$IFDEF ENV_NO_COLOR}
    Block := Block + 'NO_COLOR=1' + #0;
    {$ENDIF}
    Block := Block + #0;
    Result := TEncoding.Unicode.GetBytes(Block);
  finally
    FreeEnvironmentStrings(EnvStrings);
  end;
end;

class function TCmdShellProcess.ChangeDirectoryCommand(const AShellExe, APath: string): string;
var
  Lower: string;
begin
  Lower := LowerCase(ExtractFileName(AShellExe));
  if Lower.Contains('pwsh') or Lower.Contains('powershell') then
    Result := 'Set-Location "' + APath + '"'
  else
    Result := 'cd /d "' + APath + '"';
end;

procedure TCmdShellProcess.Start(const AShellExe: string; const AWorkDir: string);
var
  SA: TSecurityAttributes;
  StdOutWrite, StdInRead: THandle;
  StartInfo: TStartupInfo;
  CmdLine: string;
  WorkDir: PChar;
  EnvBlock: TBytes;
begin
  if FRunning then
    Exit;

  FreeAndNil(FEncoding);
  FEncoding := EncodingForShell(AShellExe);

  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  SA.lpSecurityDescriptor := nil;

  if not CreatePipe(FStdOutRead, StdOutWrite, @SA, 0) then
    RaiseLastOSError;
  SetHandleInformation(FStdOutRead, HANDLE_FLAG_INHERIT, 0);

  if not CreatePipe(StdInRead, FStdInWrite, @SA, 0) then
  begin
    CloseHandle(FStdOutRead);
    CloseHandle(StdOutWrite);
    FStdOutRead := INVALID_HANDLE_VALUE;
    RaiseLastOSError;
  end;
  SetHandleInformation(FStdInWrite, HANDLE_FLAG_INHERIT, 0);

  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.hStdOutput := StdOutWrite;
  StartInfo.hStdError := StdOutWrite;
  StartInfo.hStdInput := StdInRead;
  StartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;

  CmdLine := AShellExe;
  UniqueString(CmdLine);
  if AWorkDir <> '' then
    WorkDir := PChar(AWorkDir)
  else
    WorkDir := nil;

  EnvBlock := BuildEnvironmentBlock;

  if not CreateProcess(nil, PChar(CmdLine), nil, nil, True, CREATE_NEW_PROCESS_GROUP or CREATE_UNICODE_ENVIRONMENT, @EnvBlock[0], WorkDir, StartInfo, FProcessInfo) then
  begin
    CloseHandle(FStdOutRead);
    CloseHandle(StdOutWrite);
    CloseHandle(StdInRead);
    CloseHandle(FStdInWrite);
    FStdOutRead := INVALID_HANDLE_VALUE;
    FStdInWrite := INVALID_HANDLE_VALUE;
    RaiseLastOSError;
  end;

  CloseHandle(StdOutWrite);
  CloseHandle(StdInRead);

  FRunning := True;
  FReaderThread := TPipeReaderThread.Create(Self, FStdOutRead, FEncoding);
end;

procedure TCmdShellProcess.SendCommand(const ACommand: string);
var
  Bytes: TBytes;
  Written: DWORD;
begin
  if not FRunning then
    Exit;
  Bytes := FEncoding.GetBytes(ACommand + #13#10);
  if not WriteFile(FStdInWrite, Bytes[0], Length(Bytes), Written, nil) then
  begin
    CloseHandle(FStdInWrite);
    FStdInWrite := INVALID_HANDLE_VALUE;
  end;
end;

var
  GCtrlHandlerInstalled: Boolean = False;

function OwnCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  Result := True;
end;

procedure TCmdShellProcess.SendCtrlC;
begin
  if not FRunning then
    Exit;
  if FProcessInfo.dwProcessId = 0 then
    Exit;
  if not GCtrlHandlerInstalled then
  begin
    SetConsoleCtrlHandler(@OwnCtrlHandler, True);
    GCtrlHandlerInstalled := True;
  end;
  if AttachConsole(FProcessInfo.dwProcessId) then
  begin
    GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0);
    FreeConsole;
  end;
end;

procedure TCmdShellProcess.HandleNaturalExit;
begin
  if FTerminating or not FRunning then
    Exit;
  FRunning := False;

  if FReaderThread <> nil then
  begin
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;

  if FStdInWrite <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FStdInWrite);
    FStdInWrite := INVALID_HANDLE_VALUE;
  end;
  if FStdOutRead <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FStdOutRead);
    FStdOutRead := INVALID_HANDLE_VALUE;
  end;
  if FProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FProcessInfo.hProcess);
    FProcessInfo.hProcess := 0;
  end;
  if FProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FProcessInfo.hThread);
    FProcessInfo.hThread := 0;
  end;

  if Assigned(FOnProcessExit) then
    FOnProcessExit(Self);
end;

procedure TCmdShellProcess.Terminate;
begin
  if not FRunning then
    Exit;
  FTerminating := True;
  FRunning := False;

  if FStdInWrite <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FStdInWrite);
    FStdInWrite := INVALID_HANDLE_VALUE;
  end;

  if FProcessInfo.hProcess <> 0 then
  begin
    TerminateProcess(FProcessInfo.hProcess, 0);
    WaitForSingleObject(FProcessInfo.hProcess, 5000);
    CloseHandle(FProcessInfo.hProcess);
    FProcessInfo.hProcess := 0;
  end;
  if FProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FProcessInfo.hThread);
    FProcessInfo.hThread := 0;
  end;

  if FReaderThread <> nil then
  begin
    FReaderThread.Terminate;
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;

  if FStdOutRead <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FStdOutRead);
    FStdOutRead := INVALID_HANDLE_VALUE;
  end;

  FTerminating := False;
end;

end.
