unit Test.Delphi.Terminal.TerminalColors;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTerminalColorsTests = class
  public
    // --- 16-colour palette ---
    [Test] procedure Palette_Index0_IsBlack;
    [Test] procedure Palette_Index1_IsMaroon;
    [Test] procedure Palette_Index15_IsWhite;
    // --- 6x6x6 colour cube ---
    [Test] procedure Palette_Cube_First_IsBlack;
    [Test] procedure Palette_Cube_Last_IsWhite;
    [Test] procedure Palette_Cube_Component_Ramp;
    // --- grayscale ramp ---
    [Test] procedure Palette_Grayscale_First;
    [Test] procedure Palette_Grayscale_Last;
    // --- cell colour resolution ---
    [Test] procedure CellColor_Default_UsesFallback;
    [Test] procedure CellColor_Indexed_UsesPalette;
    [Test] procedure CellColor_RGB_SwapsToBGR;
  end;

implementation

uses
  System.UITypes,
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.TerminalColors;

{ TTerminalColorsTests }

procedure TTerminalColorsTests.Palette_Index0_IsBlack;
begin
  Assert.IsTrue(XTermPaletteColor(0) = TColor($000000), 'index 0');
end;

procedure TTerminalColorsTests.Palette_Index1_IsMaroon;
begin
  // $800000 (R=$80) -> TColor $00BBGGRR = $000080.
  Assert.IsTrue(XTermPaletteColor(1) = TColor($000080), 'index 1');
end;

procedure TTerminalColorsTests.Palette_Index15_IsWhite;
begin
  Assert.IsTrue(XTermPaletteColor(15) = TColor($FFFFFF), 'index 15');
end;

procedure TTerminalColorsTests.Palette_Cube_First_IsBlack;
begin
  // Index 16 is the first cube entry: all components 0.
  Assert.IsTrue(XTermPaletteColor(16) = TColor($000000), 'index 16');
end;

procedure TTerminalColorsTests.Palette_Cube_Last_IsWhite;
begin
  // Index 231 is the last cube entry: all components 255.
  Assert.IsTrue(XTermPaletteColor(231) = TColor($FFFFFF), 'index 231');
end;

procedure TTerminalColorsTests.Palette_Cube_Component_Ramp;
begin
  // Index 21 = 16 + 5 -> R6=0, G6=0, B6=5 -> blue component 55+5*40 = 255.
  Assert.IsTrue(XTermPaletteColor(21) = MakeColor(0, 0, 255), 'index 21 pure blue');
end;

procedure TTerminalColorsTests.Palette_Grayscale_First;
begin
  // Index 232 -> level 8.
  Assert.IsTrue(XTermPaletteColor(232) = MakeColor(8, 8, 8), 'index 232');
end;

procedure TTerminalColorsTests.Palette_Grayscale_Last;
begin
  // Index 255 -> level 8 + 23*10 = 238.
  Assert.IsTrue(XTermPaletteColor(255) = MakeColor(238, 238, 238), 'index 255');
end;

procedure TTerminalColorsTests.CellColor_Default_UsesFallback;
begin
  Assert.IsTrue(CellColorToTColor(DefaultColor, TColor($123456)) = TColor($123456), 'default falls back');
end;

procedure TTerminalColorsTests.CellColor_Indexed_UsesPalette;
begin
  Assert.IsTrue(CellColorToTColor(IndexedColor(15), TColor($000000)) = XTermPaletteColor(15), 'indexed uses palette');
end;

procedure TTerminalColorsTests.CellColor_RGB_SwapsToBGR;
begin
  // $RRGGBB = $112233 -> TColor $00BBGGRR = $332211.
  Assert.IsTrue(CellColorToTColor(RGBColor($112233), TColor($000000)) = TColor($332211), 'rgb -> bgr');
end;

initialization
  TDUnitX.RegisterTestFixture(TTerminalColorsTests);

end.
