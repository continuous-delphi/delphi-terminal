unit Test.radTerminal.CommandHistory;

interface

uses
  DUnitX.TestFramework,
  radTerminal.CommandHistory;

type

  [TestFixture]
  TTestCommandHistory = class
  private
    FHistory: TCommandHistory;
  public

    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure ShouldStartEmpty;
    [Test] procedure ShouldAddCommand;
    [Test] procedure ShouldNotAddEmptyCommand;
    [Test] procedure ShouldNotAddConsecutiveDuplicate;
    [Test] procedure ShouldAllowNonConsecutiveDuplicate;
    [Test] procedure NavigateUpShouldRecallLastCommand;
    [Test] procedure NavigateUpMultipleShouldWalkBackward;
    [Test] procedure NavigateUpShouldStopAtOldest;
    [Test] procedure NavigateDownShouldWalkForward;
    [Test] procedure NavigateDownPastEndShouldReturnEmpty;
    [Test] procedure ResetPositionShouldRestartFromEnd;
  end;

implementation

procedure TTestCommandHistory.Setup;
begin
  FHistory := TCommandHistory.Create;
end;

procedure TTestCommandHistory.TearDown;
begin
  FHistory.Free;
end;

procedure TTestCommandHistory.ShouldStartEmpty;
begin
  Assert.AreEqual(0, FHistory.Count);
end;

procedure TTestCommandHistory.ShouldAddCommand;
begin
  FHistory.Add('dir');
  Assert.AreEqual(1, FHistory.Count);
end;

procedure TTestCommandHistory.ShouldNotAddEmptyCommand;
begin
  FHistory.Add('');
  Assert.AreEqual(0, FHistory.Count);
end;

procedure TTestCommandHistory.ShouldNotAddConsecutiveDuplicate;
begin
  FHistory.Add('dir');
  FHistory.Add('dir');
  Assert.AreEqual(1, FHistory.Count);
end;

procedure TTestCommandHistory.ShouldAllowNonConsecutiveDuplicate;
begin
  FHistory.Add('dir');
  FHistory.Add('cls');
  FHistory.Add('dir');
  Assert.AreEqual(3, FHistory.Count);
end;

procedure TTestCommandHistory.NavigateUpShouldRecallLastCommand;
begin
  FHistory.Add('alpha');
  FHistory.Add('beta');
  Assert.AreEqual('beta', FHistory.NavigateUp);
end;

procedure TTestCommandHistory.NavigateUpMultipleShouldWalkBackward;
begin
  FHistory.Add('alpha');
  FHistory.Add('beta');
  FHistory.Add('gamma');
  Assert.AreEqual('gamma', FHistory.NavigateUp);
  Assert.AreEqual('beta', FHistory.NavigateUp);
  Assert.AreEqual('alpha', FHistory.NavigateUp);
end;

procedure TTestCommandHistory.NavigateUpShouldStopAtOldest;
begin
  FHistory.Add('only');
  FHistory.NavigateUp;
  Assert.AreEqual('only', FHistory.NavigateUp, 'Should stay at oldest');
end;

procedure TTestCommandHistory.NavigateDownShouldWalkForward;
begin
  FHistory.Add('alpha');
  FHistory.Add('beta');
  FHistory.NavigateUp;
  FHistory.NavigateUp;
  Assert.AreEqual('beta', FHistory.NavigateDown);
end;

procedure TTestCommandHistory.NavigateDownPastEndShouldReturnEmpty;
begin
  FHistory.Add('alpha');
  FHistory.NavigateUp;
  Assert.AreEqual('', FHistory.NavigateDown, 'Past end should be empty');
end;

procedure TTestCommandHistory.ResetPositionShouldRestartFromEnd;
begin
  FHistory.Add('alpha');
  FHistory.Add('beta');
  FHistory.NavigateUp;
  FHistory.NavigateUp;
  FHistory.ResetPosition;
  Assert.AreEqual('beta', FHistory.NavigateUp, 'After reset, Up should recall last');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCommandHistory);

end.
