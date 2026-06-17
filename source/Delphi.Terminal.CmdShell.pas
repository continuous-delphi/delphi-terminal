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

  TCmdShellType = (Unknown, CMD, PowerShell, pwsh);

  TCmdShellInfo = record
    ShellType:TCmdShellType;
    Exe:string;
    Parameters:string;
  end;

  TCmdUtils = class
    class function CreateCmdShellInfo(const ACmdShellType:TCmdShellType):TCmdShellInfo;
    class function ChangeDirectoryCommand(const ACmdShellType:TCmdShellType; const APath: string): string;
    class function GetCDAndRunCommand(const ACmdShellType:TCmdShellType; const APath, ACommand: string): string;
    class function EncodingForShell(const ACmdShellType:TCmdShellType): TEncoding;
  end;

  TOutputEvent = procedure(Sender: TObject; const AText: string) of object;

  TCmdShellProcess = class
  private
    FStdInWrite: THandle;
    FStdOutRead: THandle;
    FProcessInfo: TProcessInformation;
    FReaderThread: TThread;
    FOutputLock: TObject;
    FQueuedOutput: TStringBuilder;
    FOutputNotifyPending: Boolean;
    FRunning: Boolean;
    FTerminating: Boolean;
    FOnOutput: TOutputEvent;
    FOnProcessExit: TNotifyEvent;
    FEncoding: TEncoding;
    procedure HandleNaturalExit;
    procedure QueueOutput(const AText: string);
    procedure FlushQueuedOutput;
  public
    constructor Create;
    destructor Destroy; override;
    class function BuildEnvironmentBlock: TBytes;
    procedure Start(const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string = '');
    procedure SendCommand(const ACommand: string);
    procedure SendCtrlC;
    procedure DiscardQueuedOutput;
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
    FIsUTF8: Boolean;
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
  FIsUTF8 := (AEncoding.CodePage = 65001);
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TPipeReaderThread.NotifyOutput(const AText: string);
begin
  FOwner.QueueOutput(AText);
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

function CompleteUTF8Length(const ABytes: TBytes; ALen: Integer): Integer;
var
  I, ExpectedLen: Integer;
  B: Byte;
begin
  Result := ALen;
  if ALen = 0 then
    Exit;
  for I := 1 to 3 do
  begin
    if I > ALen then
      Break;
    B := ABytes[ALen - I];
    if B and $80 = 0 then
      Exit(ALen)
    else if B and $C0 <> $80 then
    begin
      if B and $E0 = $C0 then ExpectedLen := 2
      else if B and $F0 = $E0 then ExpectedLen := 3
      else if B and $F8 = $F0 then ExpectedLen := 4
      else Exit(ALen);
      if I < ExpectedLen then
        Exit(ALen - I)
      else
        Exit(ALen);
    end;
  end;
end;

procedure TPipeReaderThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
  Combined: TBytes;
  Leftover: TBytes;
  CombinedLen, CompleteLen, LeftoverLen: Integer;
begin
  SetLength(Leftover, 0);
  while not Terminated do
  begin
    if not ReadFile(FPipeHandle, Buffer[0], SizeOf(Buffer), BytesRead, nil) then
      Break;
    if BytesRead > 0 then
    begin
      LeftoverLen := Length(Leftover);
      if (LeftoverLen > 0) and FIsUTF8 then
      begin
        CombinedLen := LeftoverLen + Integer(BytesRead);
        SetLength(Combined, CombinedLen);
        Move(Leftover[0], Combined[0], LeftoverLen);
        Move(Buffer[0], Combined[LeftoverLen], BytesRead);
        SetLength(Leftover, 0);
      end
      else
      begin
        CombinedLen := Integer(BytesRead);
        SetLength(Combined, CombinedLen);
        Move(Buffer[0], Combined[0], BytesRead);
      end;

      if FIsUTF8 then
      begin
        CompleteLen := CompleteUTF8Length(Combined, CombinedLen);
        if CompleteLen < CombinedLen then
        begin
          SetLength(Leftover, CombinedLen - CompleteLen);
          Move(Combined[CompleteLen], Leftover[0], CombinedLen - CompleteLen);
          SetLength(Combined, CompleteLen);
        end;
      end;

      if Length(Combined) > 0 then
        NotifyOutput(FEncoding.GetString(Combined));
    end;
  end;
  if Length(Leftover) > 0 then
    NotifyOutput(FEncoding.GetString(Leftover));
  if not FOwner.FTerminating then
    NotifyExit;
end;

{ TCmdShellProcess }

constructor TCmdShellProcess.Create;
begin
  inherited Create;
  FStdInWrite := INVALID_HANDLE_VALUE;
  FStdOutRead := INVALID_HANDLE_VALUE;
  FOutputLock := TObject.Create;
  FQueuedOutput := TStringBuilder.Create;
  FProcessInfo.hProcess := 0;
  FProcessInfo.hThread := 0;
end;

destructor TCmdShellProcess.Destroy;
begin
  Terminate;
  FQueuedOutput.Free;
  FOutputLock.Free;
  FEncoding.Free;
  inherited;
end;

procedure TCmdShellProcess.QueueOutput(const AText: string);
var
  QueueThread: TThread;
  ShouldQueue: Boolean;
begin
  if AText = '' then
    Exit;

  QueueThread := FReaderThread;
  ShouldQueue := False;
  TMonitor.Enter(FOutputLock);
  try
    FQueuedOutput.Append(AText);
    if not FOutputNotifyPending then
    begin
      FOutputNotifyPending := True;
      ShouldQueue := True;
    end;
  finally
    TMonitor.Exit(FOutputLock);
  end;

  if ShouldQueue and (QueueThread <> nil) then
    TThread.Queue(QueueThread,
      procedure
      begin
        FlushQueuedOutput;
      end);
end;

procedure TCmdShellProcess.FlushQueuedOutput;
var
  Text: string;
begin
  TMonitor.Enter(FOutputLock);
  try
    Text := FQueuedOutput.ToString;
    FQueuedOutput.Clear;
    FOutputNotifyPending := False;
  finally
    TMonitor.Exit(FOutputLock);
  end;

  if (Text <> '') and Assigned(FOnOutput) then
    FOnOutput(Self, Text);
end;

procedure TCmdShellProcess.DiscardQueuedOutput;
begin
  TMonitor.Enter(FOutputLock);
  try
    FQueuedOutput.Clear;
    FOutputNotifyPending := False;
  finally
    TMonitor.Exit(FOutputLock);
  end;
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

procedure TCmdShellProcess.Start(const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
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
  FEncoding := TCmdUtils.EncodingForShell(ACmdShellInfo.ShellType);

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

  CmdLine := (ACmdShellInfo.Exe + ' ' + ACmdShellInfo.Parameters).Trim;

  if AWorkDir <> '' then
    WorkDir := PChar(AWorkDir)
  else
    WorkDir := nil;

  EnvBlock := BuildEnvironmentBlock;

  if not CreateProcess(nil, PChar(CmdLine), nil, nil, True, CREATE_UNICODE_ENVIRONMENT, @EnvBlock[0], WorkDir, StartInfo, FProcessInfo) then
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

function IgnoreCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  Result := (dwCtrlType = CTRL_C_EVENT) or (dwCtrlType = CTRL_BREAK_EVENT);
end;

//Defined in 10.4+   needed for earlier versions
{$IF not Declared(ATTACH_PARENT_PROCESS)}
const
  ATTACH_PARENT_PROCESS = DWORD(-1);
{$IFEND}

{$IF not Declared(AttachConsole)}
function AttachConsole(dwProcessId: DWORD): BOOL; stdcall; external kernel32 name 'AttachConsole';
{$IFEND}

procedure TCmdShellProcess.SendCtrlC;
var
  AttachedToShellConsole: Boolean;
begin
  if not FRunning then
    Exit;
  if FProcessInfo.dwProcessId = 0 then
    Exit;

  AttachedToShellConsole := AttachConsole(FProcessInfo.dwProcessId);
  if not AttachedToShellConsole then
    Exit;

  if not SetConsoleCtrlHandler(@IgnoreCtrlHandler, True) then
  begin
    FreeConsole;
    Exit;
  end;
  try
    // CTRL_C_EVENT cannot be targeted at a process group. Broadcast it only
    // after attaching to the shell console and while this process ignores it.
    GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0);
    Sleep(250);
  finally
    SetConsoleCtrlHandler(@IgnoreCtrlHandler, False);
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


class function TCmdUtils.CreateCmdShellInfo(const ACmdShellType:TCmdShellType):TCmdShellInfo;
begin
  Result := Default(TCmdShellInfo);
  Result.ShellType := ACmdShellType;

  case ACmdShellType of
    TCmdShellType.CMD:
      begin
        Result.Exe := GetEnvironmentVariable('COMSPEC');
        if Result.Exe.Trim.IsEmpty then
        begin
          Result.Exe := 'cmd.exe';
        end;
      end;
    TCmdShellType.PowerShell:
      begin
        Result.Exe := 'PowerShell.exe';
        Result.Parameters := '-NoLogo';
      end;
    TCmdShellType.pwsh:
      begin
        Result.Exe := 'pwsh.exe';
        Result.Parameters := '-NoLogo';
      end;
    else
      raise Exception.CreateFmt('CreateCmdShellRec: Unhandled TCmdShellType %d', [Ord(ACmdShellType)]);
  end;
end;


class function TCmdUtils.GetCDAndRunCommand(const ACmdShellType:TCmdShellType; const APath, ACommand: string): string;
begin
  if ACmdShellType = TCmdShellType.CMD then
  begin
    Result := 'cd /d "' + APath + '" && ' + ACommand;
  end
  else //pwsh or Powershell
  begin
    Result := 'Set-Location ''' + StringReplace(APath, '''', '''''', [rfReplaceAll]) + '''; if ($?) { ' + ACommand + ' }'
  end;
end;


class function TCmdUtils.ChangeDirectoryCommand(const ACmdShellType:TCmdShellType; const APath: string): string;
begin
  if ACmdShellType = TCmdShellType.CMD then
  begin
    Result :=  'cd /d "' + APath + '"';
  end
  else //pwsh or Powershell
  begin
    Result := 'Set-Location "' + APath + '"'
  end;
end;

class function TCmdUtils.EncodingForShell(const ACmdShellType:TCmdShellType): TEncoding;
begin
  if ACmdShellType = TCmdShellType.CMD then
  begin
    Result := TEncoding.GetEncoding(GetOEMCP);
  end
  else //pwsh or Powershell
  begin
    Result := TEncoding.GetEncoding(65001);
  end;
end;


end.

