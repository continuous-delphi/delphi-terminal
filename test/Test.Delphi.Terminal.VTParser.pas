unit Test.Delphi.Terminal.VTParser;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TVTParserTests = class
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

initialization
  TDUnitX.RegisterTestFixture(TVTParserTests);

end.
