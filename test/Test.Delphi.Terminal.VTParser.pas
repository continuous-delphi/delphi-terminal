unit Test.Delphi.Terminal.VTParser;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TVTParserTests = class
  private
    FLastTitle: string;
    procedure HandleTitle(Sender: TObject; const ATitle: string);
  public
    [Test] procedure Printable_WritesText;
    [Test] procedure CR_ReturnsToColumnZero;
    [Test] procedure LF_MovesDownKeepingColumn;
    [Test] procedure BS_MovesCursorLeft;
    [Test] procedure TAB_AdvancesToNextStop;
    [Test] procedure SGR_BoldAndIndexedForeground;
    [Test] procedure SGR_256Color;
    [Test] procedure SGR_TrueColor;
    [Test] procedure SGR_ResetClearsAttributes;
    [Test] procedure EscapeSplitAcrossChunks_IsHandled;
    [Test] procedure UnknownCSI_ProducesNoGarbage;
    [Test] procedure OSC_IsSwallowed;
    [Test] procedure UnknownEscape_ProducesNoGarbage;
    [Test] procedure CUP_MovesCursor;
    [Test] procedure CursorArrows_Move;
    [Test] procedure ED_ClearsScreen;
    [Test] procedure EL_ClearsToEnd;
    [Test] procedure DECSTBM_ConfinesScroll;
    [Test] procedure SaveRestoreCursor_DECSC_DECRC;
    [Test] procedure Index_And_ReverseIndex;
    [Test] procedure OSC_SetsTitle_BEL;
    [Test] procedure OSC_SetsTitle_ST;
    [Test] procedure OSC_TitleSplitAcrossChunks;
    [Test] procedure OSC_FiresOnTitleChanged;
    [Test] procedure DECMode_CursorVisibility;
    [Test] procedure DECMode_AltScreen;
    [Test] procedure DECMode_BracketedPaste;
    [Test] procedure OSC133_MarkersUpdatePromptState;
    [Test] procedure OSC133_CommandFinishedIgnoresExitCode;
  end;

implementation

uses
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.VTParser;

const
  ESC = #27;
  BEL = #7;

procedure TVTParserTests.Printable_WritesText;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('Hi');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'H', 'H at 0,0');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = 'i', 'i at 1,0');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.CR_ReturnsToColumnZero;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('AB'#13'C');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'C', 'CR returned to col 0, C overwrote A');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = 'B', 'B untouched');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.LF_MovesDownKeepingColumn;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('A'#10'B');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'A', 'A at 0,0');
    Assert.IsTrue(LScr.GetCell(1, 1).Ch = 'B', 'LF kept column 1, moved to row 1');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.BS_MovesCursorLeft;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('AB'#8'C');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = 'C', 'BS moved back over B, C overwrote it');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.TAB_AdvancesToNextStop;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(20, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(#9'X');
    Assert.IsTrue(LScr.GetCell(8, 0).Ch = 'X', 'TAB advanced to column 8');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.SGR_BoldAndIndexedForeground;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
  LCell: TTerminalCell;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[1;31mA');
    LCell := LScr.GetCell(0, 0);
    Assert.IsTrue(LCell.Ch = 'A', 'char written after SGR');
    Assert.IsTrue(csfBold in LCell.Style, 'bold applied');
    Assert.IsTrue(LCell.Foreground.Kind = cckIndexed, 'foreground indexed');
    Assert.IsTrue(LCell.Foreground.Index = 1, 'foreground index 1 (red)');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.SGR_256Color;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
  LCell: TTerminalCell;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[38;5;196mA');
    LCell := LScr.GetCell(0, 0);
    Assert.IsTrue(LCell.Foreground.Kind = cckIndexed, '256-color is indexed');
    Assert.IsTrue(LCell.Foreground.Index = 196, 'index 196');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.SGR_TrueColor;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
  LCell: TTerminalCell;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[38;2;255;0;0mA');
    LCell := LScr.GetCell(0, 0);
    Assert.IsTrue(LCell.Foreground.Kind = cckRGB, 'truecolor is RGB');
    Assert.IsTrue(LCell.Foreground.RGB = $FF0000, 'RGB value FF0000');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.SGR_ResetClearsAttributes;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
  LCell: TTerminalCell;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[1;31mA' + ESC + '[0mB');
    LCell := LScr.GetCell(1, 0);
    Assert.IsTrue(LCell.Ch = 'B', 'B written');
    Assert.IsFalse(csfBold in LCell.Style, 'reset cleared bold');
    Assert.IsTrue(LCell.Foreground.Kind = cckDefault, 'reset cleared foreground');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.EscapeSplitAcrossChunks_IsHandled;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
  LCell: TTerminalCell;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[3');   // split mid-parameter
    LP.Parse('1mZ');
    LCell := LScr.GetCell(0, 0);
    Assert.IsTrue(LCell.Ch = 'Z', 'Z written after reassembled sequence');
    Assert.IsTrue((LCell.Foreground.Kind = cckIndexed) and (LCell.Foreground.Index = 1), 'red applied across the chunk boundary');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.UnknownCSI_ProducesNoGarbage;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    // CSI 2 J (erase) is not handled in #63; it must be consumed, not printed.
    LP.Parse(ESC + '[2JA');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'A', 'A printed; the CSI produced no visible characters');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = ' ', 'no leaked sequence characters');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC_IsSwallowed;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(20, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + ']0;My Window Title' + BEL + 'A');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'A', 'A printed; OSC title swallowed');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.UnknownEscape_ProducesNoGarbage;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '=A');   // ESC = (application keypad) -- consume, then print A
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'A', 'A printed; ESC = consumed');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.CUP_MovesCursor;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 5);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[2;3H');   // row 2, col 3 (1-based) -> (col 2, row 1)
    LP.Parse('X');
    Assert.IsTrue(LScr.GetCell(2, 1).Ch = 'X', 'CUP positioned the cursor at row 1, col 2');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.CursorArrows_Move;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(3, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[3;3H');   // (col 2, row 2)
    LP.Parse(ESC + '[1A');     // up   -> (2,1)
    LP.Parse(ESC + '[2D');     // left -> (0,1)
    LP.Parse('Z');             // cell(0,1); cursor -> (1,1)
    LP.Parse(ESC + '[1B');     // down  -> (1,2)
    LP.Parse(ESC + '[1C');     // right -> (2,2)
    LP.Parse('Q');             // cell(2,2)
    Assert.IsTrue(LScr.GetCell(0, 1).Ch = 'Z', 'up + left landed at (0,1)');
    Assert.IsTrue(LScr.GetCell(2, 2).Ch = 'Q', 'down + right landed at (2,2)');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.ED_ClearsScreen;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('ABC');
    LP.Parse(ESC + '[2J');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = ' ', 'ED(2) cleared the screen');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.EL_ClearsToEnd;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('ABC');
    LP.Parse(ESC + '[1;2H');   // cursor to col 2 (0-based col 1)
    LP.Parse(ESC + '[0K');     // erase to end of line
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'A', 'before cursor kept');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = ' ', 'cursor cell cleared');
    Assert.IsTrue(LScr.GetCell(2, 0).Ch = ' ', 'after cursor cleared');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.DECSTBM_ConfinesScroll;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(3, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[1;1H'); LP.Parse('AAA');
    LP.Parse(ESC + '[2;1H'); LP.Parse('BBB');
    LP.Parse(ESC + '[3;1H'); LP.Parse('CCC');
    LP.Parse(ESC + '[1;2r');   // scroll region rows 1..2 (0-based 0..1); homes cursor
    LP.Parse(ESC + '[2;1H');   // (col 0, row 1) -- bottom of the region
    LP.Parse(#10);             // LF at the bottom margin scrolls the region up
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'B', 'region top now holds old region bottom');
    Assert.IsTrue(LScr.GetCell(0, 1).Ch = ' ', 'region bottom blanked');
    Assert.IsTrue(LScr.GetCell(0, 2).Ch = 'C', 'row outside the region untouched');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.SaveRestoreCursor_DECSC_DECRC;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 5);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + '[1;1H');
    LP.Parse('A');             // cursor -> (1,0)
    LP.Parse(ESC + '7');       // DECSC save at (1,0)
    LP.Parse(ESC + '[3;3H');   // move to (2,2)
    LP.Parse(ESC + '8');       // DECRC restore to (1,0)
    LP.Parse('B');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = 'B', 'cursor restored to the saved position');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.Index_And_ReverseIndex;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + 'D');       // IND: row 0 -> row 1
    LP.Parse('A');             // cell(0,1); cursor -> (1,1)
    LP.Parse(ESC + 'M');       // RI: row 1 -> row 0
    LP.Parse('B');             // cell(1,0)
    Assert.IsTrue(LScr.GetCell(0, 1).Ch = 'A', 'index moved down a line');
    Assert.IsTrue(LScr.GetCell(1, 0).Ch = 'B', 'reverse index moved up a line');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.HandleTitle(Sender: TObject; const ATitle: string);
begin
  FLastTitle := ATitle;
end;

procedure TVTParserTests.OSC_SetsTitle_BEL;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + ']0;My Title' + BEL);
    Assert.IsTrue(LP.Title = 'My Title', 'BEL-terminated OSC 0 set the title');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC_SetsTitle_ST;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + ']2;Other' + ESC + '\');
    Assert.IsTrue(LP.Title = 'Other', 'ST-terminated OSC 2 set the title');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC_TitleSplitAcrossChunks;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse(ESC + ']0;Hel');
    LP.Parse('lo' + BEL);
    Assert.IsTrue(LP.Title = 'Hello', 'OSC title reassembled across chunks');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC_FiresOnTitleChanged;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    FLastTitle := '';
    LP.OnTitleChanged := HandleTitle;
    LP.Parse(ESC + ']0;Hi' + BEL);
    Assert.IsTrue(FLastTitle = 'Hi', 'OnTitleChanged fired with the new title');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.DECMode_CursorVisibility;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    Assert.IsTrue(LScr.CursorVisible, 'cursor visible by default');
    LP.Parse(ESC + '[?25l');
    Assert.IsFalse(LScr.CursorVisible, '?25l hides the cursor');
    LP.Parse(ESC + '[?25h');
    Assert.IsTrue(LScr.CursorVisible, '?25h shows the cursor');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.DECMode_AltScreen;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    LP.Parse('MAIN');
    LP.Parse(ESC + '[?1049h');
    Assert.IsTrue(LScr.AltActive, '?1049h enters the alt screen');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = ' ', 'alt screen is blank');
    LP.Parse(ESC + '[?1049l');
    Assert.IsFalse(LScr.AltActive, '?1049l exits the alt screen');
    Assert.IsTrue(LScr.GetCell(0, 0).Ch = 'M', 'main content restored');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.DECMode_BracketedPaste;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    Assert.IsFalse(LScr.BracketedPaste, 'bracketed paste off by default');
    LP.Parse(ESC + '[?2004h');
    Assert.IsTrue(LScr.BracketedPaste, '?2004h enables bracketed paste');
    LP.Parse(ESC + '[?2004l');
    Assert.IsFalse(LScr.BracketedPaste, '?2004l disables bracketed paste');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC133_MarkersUpdatePromptState;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    Assert.IsTrue(LScr.PromptState = spsUnknown, 'no markers seen yet');
    LP.Parse(ESC + ']133;A' + BEL);
    Assert.IsTrue(LScr.PromptState = spsPromptStart, '133;A = prompt start');
    LP.Parse(ESC + ']133;B' + BEL);
    Assert.IsTrue(LScr.PromptState = spsCommandInput, '133;B = command-input start');
    LP.Parse(ESC + ']133;C' + BEL);
    Assert.IsTrue(LScr.PromptState = spsExecuting, '133;C = command executing');
    LP.Parse(ESC + ']133;D' + BEL);
    Assert.IsTrue(LScr.PromptState = spsCommandFinished, '133;D = command finished');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

procedure TVTParserTests.OSC133_CommandFinishedIgnoresExitCode;
var
  LScr: TScreenBuffer;
  LP: TVTParser;
begin
  LScr := TScreenBuffer.Create(10, 3);
  LP := TVTParser.Create(LScr);
  try
    // 133;D can carry an exit code (e.g. "133;D;0"); the trailing param is ignored.
    LP.Parse(ESC + ']133;D;0' + BEL);
    Assert.IsTrue(LScr.PromptState = spsCommandFinished, '133;D;0 = command finished, exit code ignored');
  finally
    LP.Free;
    LScr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVTParserTests);

end.
