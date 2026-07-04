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
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Delphi.Terminal.Pty,
  Delphi.Terminal.ConPtyReader;

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

initialization
  TDUnitX.RegisterTestFixture(TConPtyTests);

end.
