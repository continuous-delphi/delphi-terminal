unit Test.Delphi.Terminal.ScreenBuffer;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TScreenBufferTests = class
  public
    [Test] procedure WriteText_PopulatesCells;
    [Test] procedure Cursor_Movement_Overwrites;
    [Test] procedure EraseInLine_ToEnd_Clears;
    [Test] procedure EraseInLine_ToStart_Clears;
    [Test] procedure Attributes_AppliedToWrittenCells;
    [Test] procedure PutChar_WrapsAtEndOfRow;
    [Test] procedure ClearAll_BlanksAndHomes;
    [Test] procedure EraseInDisplay_ToEnd_Clears;
    [Test] procedure EraseInDisplay_Whole_KeepsCursor;
    [Test] procedure SetCursor_ClampsToBounds;
  end;

implementation

uses
  Delphi.Terminal.ScreenBuffer;

procedure TScreenBufferTests.WriteText_PopulatesCells;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 3);
  try
    LBuf.WriteText('AB');
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'cell 0,0 should be A');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = 'B', 'cell 1,0 should be B');
    Assert.IsTrue((LBuf.CursorCol = 2) and (LBuf.CursorRow = 0), 'cursor should advance to 2,0');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.Cursor_Movement_Overwrites;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 3);
  try
    LBuf.WriteText('X');
    LBuf.SetCursor(0, 0);
    LBuf.WriteText('Y');
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'Y', 'cell should be overwritten with Y');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.EraseInLine_ToEnd_Clears;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 3);
  try
    LBuf.WriteText('ABC');
    LBuf.SetCursor(1, 0);
    LBuf.EraseInLine(0);   // cursor (col 1) to end of line
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'before cursor is kept');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = ' ', 'cursor cell cleared');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = ' ', 'after cursor cleared');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.EraseInLine_ToStart_Clears;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 3);
  try
    LBuf.WriteText('ABC');
    LBuf.SetCursor(1, 0);
    LBuf.EraseInLine(1);   // start of line to cursor (col 1) inclusive
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = ' ', 'start cleared');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = ' ', 'cursor cell cleared');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = 'C', 'after cursor is kept');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.Attributes_AppliedToWrittenCells;
var
  LBuf: TScreenBuffer;
  LCell: TTerminalCell;
begin
  LBuf := TScreenBuffer.Create(10, 3);
  try
    LBuf.SetAttributes(RGBColor($FF0000), DefaultColor, [csfBold, csfUnderline]);
    LBuf.PutChar('Z');
    LCell := LBuf.GetCell(0, 0);
    Assert.IsTrue(LCell.Ch = 'Z', 'char written');
    Assert.IsTrue(LCell.Foreground.Kind = cckRGB, 'foreground kind is RGB');
    Assert.IsTrue(LCell.Foreground.RGB = $FF0000, 'foreground RGB value');
    Assert.IsTrue(csfBold in LCell.Style, 'bold applied');
    Assert.IsTrue(csfUnderline in LCell.Style, 'underline applied');
    Assert.IsFalse(csfItalic in LCell.Style, 'italic not applied');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.PutChar_WrapsAtEndOfRow;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.WriteText('ABCD');   // ABC fills row 0; D wraps to row 1 col 0
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'row 0 col 0');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = 'C', 'row 0 col 2');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'D', 'wrapped to row 1 col 0');
    Assert.IsTrue((LBuf.CursorCol = 1) and (LBuf.CursorRow = 1), 'cursor after wrap');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.ClearAll_BlanksAndHomes;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 2);
  try
    LBuf.WriteText('HELLO');
    LBuf.ClearAll;
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = ' ', 'start cleared');
    Assert.IsTrue(LBuf.GetCell(4, 0).Ch = ' ', 'end cleared');
    Assert.IsTrue((LBuf.CursorCol = 0) and (LBuf.CursorRow = 0), 'cursor homed');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.EraseInDisplay_ToEnd_Clears;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.WriteText('ABCDEFGHI');   // fills the whole 3x3
    LBuf.SetCursor(1, 1);
    LBuf.EraseInDisplay(0);        // cursor to end of screen
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'above cursor kept');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'D', 'before cursor on its row kept');
    Assert.IsTrue(LBuf.GetCell(1, 1).Ch = ' ', 'cursor cell cleared');
    Assert.IsTrue(LBuf.GetCell(2, 2).Ch = ' ', 'below cursor cleared');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.EraseInDisplay_Whole_KeepsCursor;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 3);
  try
    LBuf.WriteText('AB');
    LBuf.SetCursor(3, 2);
    LBuf.EraseInDisplay(2);
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = ' ', 'screen cleared');
    Assert.IsTrue((LBuf.CursorCol = 3) and (LBuf.CursorRow = 2), 'cursor unchanged by ED(2)');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.SetCursor_ClampsToBounds;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(4, 2);
  try
    LBuf.SetCursor(100, 100);
    Assert.IsTrue((LBuf.CursorCol = 3) and (LBuf.CursorRow = 1), 'cursor clamped to bottom-right');
    LBuf.SetCursor(-5, -5);
    Assert.IsTrue((LBuf.CursorCol = 0) and (LBuf.CursorRow = 0), 'cursor clamped to origin');
  finally
    LBuf.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TScreenBufferTests);

end.
