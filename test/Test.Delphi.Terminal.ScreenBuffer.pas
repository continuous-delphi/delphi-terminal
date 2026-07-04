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
    [Test] procedure DeferredWrap_HoldsCursorAtLastColumn;
    [Test] procedure DeferredWrap_NextCharPerformsWrap;
    [Test] procedure DeferredWrap_CursorMoveCancelsPending;
    [Test] procedure EraseChars_BlanksInPlace;
    [Test] procedure InsertChars_ShiftsRight;
    [Test] procedure DeleteChars_ShiftsLeft;
    [Test] procedure InsertLines_ShiftsDown;
    [Test] procedure DeleteLines_ShiftsUp;
    [Test] procedure ClearAll_BlanksAndHomes;
    [Test] procedure EraseInDisplay_ToEnd_Clears;
    [Test] procedure EraseInDisplay_Whole_KeepsCursor;
    [Test] procedure SetCursor_ClampsToBounds;
    [Test] procedure ScrollUp_ShiftsAndBlanks;
    [Test] procedure ScrollUp_PushesToScrollback;
    [Test] procedure ScrollRegion_ConfinesScroll;
    [Test] procedure LineFeed_AtBottomScrolls;
    [Test] procedure AltScreen_SwapsAndRestores;
    [Test] procedure Resize_PreservesContentAndClampsCursor;
    [Test] procedure Dirty_MarksAndResets;
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

procedure TScreenBufferTests.DeferredWrap_HoldsCursorAtLastColumn;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.WriteText('ABC');   // fills row 0 exactly; the wrap must be deferred
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = 'C', 'C at row 0 col 2');
    Assert.IsTrue((LBuf.CursorCol = 2) and (LBuf.CursorRow = 0), 'cursor parked at last column, not wrapped');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = ' ', 'row 1 still blank');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.DeferredWrap_NextCharPerformsWrap;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.WriteText('ABC');   // pending wrap
    LBuf.WriteText('D');     // now the wrap happens
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'D', 'D wrapped to row 1 col 0');
    Assert.IsTrue((LBuf.CursorCol = 1) and (LBuf.CursorRow = 1), 'cursor advanced on row 1');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.DeferredWrap_CursorMoveCancelsPending;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.WriteText('ABC');   // pending wrap
    LBuf.SetCursor(0, 0);    // an explicit move must cancel the pending wrap
    LBuf.WriteText('X');     // overwrites A on row 0, no wrap to row 1
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'X', 'X overwrote A on row 0');
    Assert.IsTrue((LBuf.CursorCol = 1) and (LBuf.CursorRow = 0), 'cursor stayed on row 0');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = ' ', 'row 1 untouched');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.EraseChars_BlanksInPlace;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.WriteText('ABCDE');
    LBuf.SetCursor(1, 0);
    LBuf.EraseChars(2);   // blank cols 1..2, cursor unchanged
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'A kept');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = ' ', 'B erased');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = ' ', 'C erased');
    Assert.IsTrue(LBuf.GetCell(3, 0).Ch = 'D', 'D kept');
    Assert.IsTrue((LBuf.CursorCol = 1) and (LBuf.CursorRow = 0), 'cursor unchanged');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.InsertChars_ShiftsRight;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.WriteText('ABCDE');
    LBuf.SetCursor(1, 0);
    LBuf.InsertChars(2);   // insert 2 blanks at col 1, shifting BCDE right
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'A kept');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = ' ', 'blank inserted');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = ' ', 'blank inserted');
    Assert.IsTrue(LBuf.GetCell(3, 0).Ch = 'B', 'B shifted right');
    Assert.IsTrue(LBuf.GetCell(6, 0).Ch = 'E', 'E shifted right');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.DeleteChars_ShiftsLeft;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(10, 2);
  try
    LBuf.WriteText('ABCDE');
    LBuf.SetCursor(1, 0);
    LBuf.DeleteChars(2);   // delete B,C -- D,E shift left
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'A kept');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = 'D', 'D shifted left');
    Assert.IsTrue(LBuf.GetCell(2, 0).Ch = 'E', 'E shifted left');
    Assert.IsTrue(LBuf.GetCell(3, 0).Ch = ' ', 'tail blanked');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.InsertLines_ShiftsDown;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 4);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('AAAA');
    LBuf.SetCursor(0, 1); LBuf.WriteText('BBBB');
    LBuf.SetCursor(0, 2); LBuf.WriteText('CCCC');
    LBuf.SetCursor(0, 1);
    LBuf.InsertLines(1);   // blank line at row 1; B,C move down
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'row 0 kept');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = ' ', 'row 1 blank');
    Assert.IsTrue(LBuf.GetCell(0, 2).Ch = 'B', 'B moved to row 2');
    Assert.IsTrue(LBuf.GetCell(0, 3).Ch = 'C', 'C moved to row 3');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.DeleteLines_ShiftsUp;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 4);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('AAAA');
    LBuf.SetCursor(0, 1); LBuf.WriteText('BBBB');
    LBuf.SetCursor(0, 2); LBuf.WriteText('CCCC');
    LBuf.SetCursor(0, 3); LBuf.WriteText('DDDD');
    LBuf.SetCursor(0, 1);
    LBuf.DeleteLines(1);   // remove row 1; C,D move up
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'row 0 kept');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'C', 'C moved to row 1');
    Assert.IsTrue(LBuf.GetCell(0, 2).Ch = 'D', 'D moved to row 2');
    Assert.IsTrue(LBuf.GetCell(0, 3).Ch = ' ', 'bottom blanked');
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

procedure TScreenBufferTests.ScrollUp_ShiftsAndBlanks;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('ABC');
    LBuf.SetCursor(0, 1); LBuf.WriteText('DEF');
    LBuf.SetCursor(0, 2); LBuf.WriteText('GHI');
    LBuf.ScrollUp(1);
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'D', 'row 0 should now hold the old row 1');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'G', 'row 1 should now hold the old row 2');
    Assert.IsTrue(LBuf.GetCell(0, 2).Ch = ' ', 'bottom row blanked');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.ScrollUp_PushesToScrollback;
var
  LBuf: TScreenBuffer;
  LLine: TArray<TTerminalCell>;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('ABC');
    LBuf.ScrollUp(1);
    Assert.IsTrue(LBuf.ScrollbackCount = 1, 'one line should be in scrollback');
    LLine := LBuf.GetScrollbackLine(0);
    Assert.IsTrue((LLine[0].Ch = 'A') and (LLine[1].Ch = 'B') and (LLine[2].Ch = 'C'), 'scrollback line content');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.ScrollRegion_ConfinesScroll;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 4);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('AAA');
    LBuf.SetCursor(0, 1); LBuf.WriteText('BBB');
    LBuf.SetCursor(0, 2); LBuf.WriteText('CCC');
    LBuf.SetCursor(0, 3); LBuf.WriteText('DDD');
    LBuf.SetScrollRegion(1, 2);
    LBuf.ScrollUp(1);
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'A', 'row above the region is untouched');
    Assert.IsTrue(LBuf.GetCell(0, 1).Ch = 'C', 'region top now holds the old region bottom');
    Assert.IsTrue(LBuf.GetCell(0, 2).Ch = ' ', 'region bottom blanked');
    Assert.IsTrue(LBuf.GetCell(0, 3).Ch = 'D', 'row below the region is untouched');
    Assert.IsTrue(LBuf.ScrollbackCount = 0, 'non-top-anchored region does not add to scrollback');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.LineFeed_AtBottomScrolls;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(3, 3);
  try
    LBuf.SetCursor(0, 0); LBuf.WriteText('ABC');
    LBuf.SetCursor(0, 1); LBuf.WriteText('DEF');
    LBuf.SetCursor(0, 2); LBuf.WriteText('GHI');
    LBuf.SetCursor(0, 2);   // at the bottom margin
    LBuf.LineFeed;
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'D', 'line feed at bottom scrolls the screen up');
    Assert.IsTrue(LBuf.CursorRow = 2, 'cursor stays at the bottom margin');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.AltScreen_SwapsAndRestores;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 2);
  try
    LBuf.WriteText('MAIN');
    LBuf.SetCursor(2, 1);
    LBuf.EnterAltScreen;
    Assert.IsTrue(LBuf.AltActive, 'alt screen active');
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = ' ', 'alt screen starts blank');
    Assert.IsTrue((LBuf.CursorCol = 0) and (LBuf.CursorRow = 0), 'alt screen homes the cursor');
    LBuf.WriteText('ALT');
    LBuf.ExitAltScreen;
    Assert.IsFalse(LBuf.AltActive, 'back on main screen');
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'M', 'main screen content restored');
    Assert.IsTrue((LBuf.CursorCol = 2) and (LBuf.CursorRow = 1), 'main cursor restored');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.Resize_PreservesContentAndClampsCursor;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(4, 3);
  try
    LBuf.WriteText('WXYZ');
    LBuf.SetCursor(3, 2);
    LBuf.Resize(2, 2);
    Assert.IsTrue((LBuf.Cols = 2) and (LBuf.Rows = 2), 'dimensions updated');
    Assert.IsTrue(LBuf.GetCell(0, 0).Ch = 'W', 'top-left content preserved');
    Assert.IsTrue(LBuf.GetCell(1, 0).Ch = 'X', 'top-left content preserved (col 1)');
    Assert.IsTrue((LBuf.CursorCol = 1) and (LBuf.CursorRow = 1), 'cursor clamped to new bounds');
  finally
    LBuf.Free;
  end;
end;

procedure TScreenBufferTests.Dirty_MarksAndResets;
var
  LBuf: TScreenBuffer;
begin
  LBuf := TScreenBuffer.Create(5, 3);
  try
    LBuf.ResetDirty;
    Assert.IsFalse(LBuf.IsRowDirty(1), 'clean after reset');
    LBuf.SetCursor(0, 1);
    LBuf.PutChar('X');
    Assert.IsTrue(LBuf.IsRowDirty(1), 'written row is dirty');
    Assert.IsFalse(LBuf.IsRowDirty(2), 'untouched row stays clean');
    LBuf.ResetDirty;
    Assert.IsFalse(LBuf.IsRowDirty(1), 'clean again after reset');
  finally
    LBuf.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TScreenBufferTests);

end.
