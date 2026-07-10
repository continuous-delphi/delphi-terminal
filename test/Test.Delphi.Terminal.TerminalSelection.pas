unit Test.Delphi.Terminal.TerminalSelection;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTerminalSelectionTests = class
  public
    [Test] procedure Normalize_LeavesForwardSelection;
    [Test] procedure Normalize_SwapsReversedSelection;
    [Test] procedure IsCellSelected_SingleLine_Inclusive;
    [Test] procedure IsCellSelected_OutsideLine_False;
    [Test] procedure IsCellSelected_MiddleLine_FullySelected;
    [Test] procedure Inactive_Selection_SelectsNothing;
    [Test] procedure SelectedText_SingleLine_TrimsTrailingSpaces;
    [Test] procedure SelectedText_MultiLine_JoinsWithCRLF;
    [Test] procedure LineCell_ReadsScreenRow;
    [Test] procedure LineCell_ReadsScrollback;
    [Test] procedure SelectedText_SpansScrollbackAndScreen;
  end;

implementation

uses
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.TerminalSelection;

function BuildSelection(ASL, ASC, AEL, AEC: Integer): TTerminalSelection;
begin
  Result.Active := True;
  Result.StartLine := ASL;
  Result.StartCol := ASC;
  Result.EndLine := AEL;
  Result.EndCol := AEC;
end;

// Creates a 10x2 buffer with 'HELLO' scrolled into history and 'WORLD' on the top screen row.
function BuildScrollbackBuffer: TScreenBuffer;
begin
  Result := TScreenBuffer.Create(10, 2);
  Result.SetCursor(0, 0);
  Result.WriteText('HELLO');
  Result.SetCursor(0, 1);
  Result.WriteText('WORLD');
  Result.SetCursor(0, 1);
  Result.LineFeed;   // cursor at bottom margin -> scrolls 'HELLO' into scrollback
end;

{ TTerminalSelectionTests }

procedure TTerminalSelectionTests.Normalize_LeavesForwardSelection;
var
  N: TTerminalSelection;
begin
  N := NormalizeSelection(BuildSelection(1, 2, 3, 4));
  Assert.IsTrue((N.StartLine = 1) and (N.StartCol = 2) and (N.EndLine = 3) and (N.EndCol = 4), 'forward unchanged');
end;

procedure TTerminalSelectionTests.Normalize_SwapsReversedSelection;
var
  N: TTerminalSelection;
begin
  N := NormalizeSelection(BuildSelection(3, 4, 1, 2));
  Assert.IsTrue((N.StartLine = 1) and (N.StartCol = 2) and (N.EndLine = 3) and (N.EndCol = 4), 'reversed swapped');
end;

procedure TTerminalSelectionTests.IsCellSelected_SingleLine_Inclusive;
var
  S: TTerminalSelection;
begin
  S := BuildSelection(0, 2, 0, 5);
  Assert.IsFalse(IsCellSelected(S, 0, 1), 'before start');
  Assert.IsTrue(IsCellSelected(S, 0, 2), 'start inclusive');
  Assert.IsTrue(IsCellSelected(S, 0, 5), 'end inclusive');
  Assert.IsFalse(IsCellSelected(S, 0, 6), 'after end');
end;

procedure TTerminalSelectionTests.IsCellSelected_OutsideLine_False;
var
  S: TTerminalSelection;
begin
  S := BuildSelection(1, 0, 1, 9);
  Assert.IsFalse(IsCellSelected(S, 0, 5), 'line above');
  Assert.IsFalse(IsCellSelected(S, 2, 5), 'line below');
end;

procedure TTerminalSelectionTests.IsCellSelected_MiddleLine_FullySelected;
var
  S: TTerminalSelection;
begin
  S := BuildSelection(0, 5, 2, 3);
  // Any column on the fully-enclosed middle line is selected.
  Assert.IsTrue(IsCellSelected(S, 1, 0), 'middle col 0');
  Assert.IsTrue(IsCellSelected(S, 1, 99), 'middle col far');
end;

procedure TTerminalSelectionTests.Inactive_Selection_SelectsNothing;
var
  S: TTerminalSelection;
begin
  S := BuildSelection(0, 0, 0, 9);
  S.Active := False;
  Assert.IsFalse(IsCellSelected(S, 0, 5), 'inactive');
end;

procedure TTerminalSelectionTests.SelectedText_SingleLine_TrimsTrailingSpaces;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.SetCursor(0, 0);
    LBuf.WriteText('HI');
    // Select the whole first row; trailing blanks must be trimmed.
    Assert.AreEqual('HI', SelectedText(LBuf, BuildSelection(0, 0, 0, 9)));
  finally
    LBuf.Free;
  end;
end;

procedure TTerminalSelectionTests.SelectedText_MultiLine_JoinsWithCRLF;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.SetCursor(0, 0);
    LBuf.WriteText('AB');
    LBuf.SetCursor(0, 1);
    LBuf.WriteText('CD');
    Assert.AreEqual('AB'#13#10'CD', SelectedText(LBuf, BuildSelection(0, 0, 1, 9)));
  finally
    LBuf.Free;
  end;
end;

procedure TTerminalSelectionTests.LineCell_ReadsScreenRow;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.SetCursor(0, 0);
    LBuf.WriteText('HI');
    Assert.IsTrue(LineCell(LBuf, 0, 0).Ch = 'H', 'screen row 0 col 0');
  finally
    LBuf.Free;
  end;
end;

procedure TTerminalSelectionTests.LineCell_ReadsScrollback;
var
  LBuf: TScreenBuffer;
begin
  LBuf := BuildScrollbackBuffer;
  try
    Assert.AreEqual(NativeInt(1), NativeInt(LBuf.ScrollbackCount), 'one scrollback line');
    Assert.AreEqual(NativeInt(3), NativeInt(TotalLineCount(LBuf)), 'total = scrollback + rows');
    Assert.IsTrue(LineCell(LBuf, 0, 0).Ch = 'H', 'scrollback line 0');
    Assert.IsTrue(LineCell(LBuf, 1, 0).Ch = 'W', 'screen top row is WORLD');
  finally
    LBuf.Free;
  end;
end;

procedure TTerminalSelectionTests.SelectedText_SpansScrollbackAndScreen;
var
  LBuf: TScreenBuffer;
begin
  LBuf := BuildScrollbackBuffer;
  try
    Assert.AreEqual('HELLO'#13#10'WORLD', SelectedText(LBuf, BuildSelection(0, 0, 1, 4)));
  finally
    LBuf.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTerminalSelectionTests);

end.
