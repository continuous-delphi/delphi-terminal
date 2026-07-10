(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Background reader for a ConPTY session. Reads TConPty.OutputRead until EOF,
  decodes the UTF-8 byte stream (holding back any multi-byte sequence split
  across a read boundary), and marshals decoded text to the main thread via a
  single coalesced TThread.Queue. Raises OnProcessExit on natural EOF unless it
  was terminated deliberately.

  Implements IPtyReader with non-reference-counted lifetime: TConPty registers a
  reference purely to Join it during shutdown; ownership stays with the creator,
  which must Free it after TConPty.Close returns.

  Escape-sequence (VT) reassembly is intentionally NOT done here -- that belongs
  to the parser downstream. This reader only guarantees UTF-8-complete chunks.

*)
unit Delphi.Terminal.ConPtyReader;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Delphi.Terminal.Pty;

type
  TPtyOutputEvent = procedure(Sender: TObject; const AText: string) of object;

  TConPtyReader = class(TThread, IInterface, IPtyReader)
  private
    FOutputRead: THandle;
    FOnOutput: TPtyOutputEvent;
    FOnProcessExit: TNotifyEvent;
    FLock: TObject;
    FQueued: TStringBuilder;
    FNotifyPending: Boolean;
    procedure QueueText(const AText: string);
    procedure FlushQueued;
    procedure DoProcessExit;
  protected
    procedure Execute; override;
    // Non-reference-counted IInterface: TConPty holds a non-owning reference.
    function QueryInterface(const IID: TGUID; out Obj): HRESULT; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create(AOutputRead: THandle; const AOnOutput: TPtyOutputEvent; const AOnProcessExit: TNotifyEvent);
    destructor Destroy; override;
    procedure Join;   // IPtyReader
  end;

implementation

uses
  Delphi.Terminal.TextDecode;

const
  READ_BUFFER_SIZE = 4096;

constructor TConPtyReader.Create(AOutputRead: THandle; const AOnOutput: TPtyOutputEvent; const AOnProcessExit: TNotifyEvent);
begin
  FOutputRead := AOutputRead;
  FOnOutput := AOnOutput;
  FOnProcessExit := AOnProcessExit;
  FLock := TObject.Create;
  FQueued := TStringBuilder.Create;
  FreeOnTerminate := False;
  inherited Create(False);
end;

destructor TConPtyReader.Destroy;
begin
  // Ensure the thread has stopped, then drop any not-yet-run queued callbacks
  // before freeing the buffer they reference. (Freed on the main thread, so
  // this is serialized with the queue.)
  Terminate;
  WaitFor;
  TThread.RemoveQueuedEvents(Self);
  FQueued.Free;
  FLock.Free;
  inherited;
end;

function TConPtyReader.QueryInterface(const IID: TGUID; out Obj): HRESULT;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TConPtyReader._AddRef: Integer;
begin
  Result := -1;
end;

function TConPtyReader._Release: Integer;
begin
  Result := -1;
end;

procedure TConPtyReader.Join;
begin
  WaitFor;
end;

procedure TConPtyReader.QueueText(const AText: string);
var
  ShouldQueue: Boolean;
begin
  if AText = '' then
    Exit;
  ShouldQueue := False;
  TMonitor.Enter(FLock);
  try
    FQueued.Append(AText);
    if not FNotifyPending then
    begin
      FNotifyPending := True;
      ShouldQueue := True;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  if ShouldQueue then
    TThread.Queue(Self, FlushQueued);
end;

procedure TConPtyReader.FlushQueued;
var
  LText: string;
begin
  TMonitor.Enter(FLock);
  try
    LText := FQueued.ToString;
    FQueued.Clear;
    FNotifyPending := False;
  finally
    TMonitor.Exit(FLock);
  end;
  if (LText <> '') and Assigned(FOnOutput) then
    FOnOutput(Self, LText);
end;

procedure TConPtyReader.DoProcessExit;
begin
  if Assigned(FOnProcessExit) then
    FOnProcessExit(Self);
end;

procedure TConPtyReader.Execute;
var
  Buffer: array [0 .. READ_BUFFER_SIZE - 1] of Byte;
  BytesRead: DWORD;
  Combined, Leftover: TBytes;
  CombinedLen, CompleteLen, LeftoverLen: Integer;
begin
  SetLength(Leftover, 0);
  while not Terminated do
  begin
    if not ReadFile(FOutputRead, Buffer[0], SizeOf(Buffer), BytesRead, nil) then
      Break;
    if BytesRead = 0 then
      Break;

    LeftoverLen := Length(Leftover);
    if LeftoverLen > 0 then
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

    CompleteLen := CompleteUTF8Length(Combined, CombinedLen);
    if CompleteLen < CombinedLen then
    begin
      SetLength(Leftover, CombinedLen - CompleteLen);
      Move(Combined[CompleteLen], Leftover[0], CombinedLen - CompleteLen);
      SetLength(Combined, CompleteLen);
    end;

    if Length(Combined) > 0 then
      QueueText(TEncoding.UTF8.GetString(Combined));
  end;

  // Emit any trailing bytes (best effort on a truncated stream).
  if Length(Leftover) > 0 then
    QueueText(TEncoding.UTF8.GetString(Leftover));

  // Natural exit only -- a deliberate teardown sets Terminated first.
  if not Terminated then
    TThread.Queue(Self, DoProcessExit);
end;

end.
