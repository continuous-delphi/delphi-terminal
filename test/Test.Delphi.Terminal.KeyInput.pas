unit Test.Delphi.Terminal.KeyInput;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKeyInputTests = class
  public
    [Test] procedure Enter_SendsCR;
    [Test] procedure Backspace_SendsDEL;
    [Test] procedure Tab_SendsHT;
    [Test] procedure ShiftTab_SendsCBT;
    [Test] procedure Escape_SendsESC;
    [Test] procedure Arrows_SendCSILetters;
    [Test] procedure HomeEnd_SendCSI;
    [Test] procedure InsertDelete_SendVT220;
    [Test] procedure PageUpDown_SendVT220;
    [Test] procedure CtrlC_SendsETX;
    [Test] procedure CtrlD_SendsEOT;
    [Test] procedure CtrlL_SendsFF;
    [Test] procedure PlainLetter_ReturnsEmpty;
    [Test] procedure AltGrLetter_ReturnsEmpty;
    // --- paste ---
    [Test] procedure Paste_Plain_PassesThrough;
    [Test] procedure Paste_Bracketed_WrapsWithMarkers;
    [Test] procedure Paste_NormalizesCRLFToCR;
    [Test] procedure Paste_NormalizesLoneLFToCR;
  end;

implementation

uses
  Winapi.Windows,
  System.Classes,
  Delphi.Terminal.KeyInput;

const
  ESC = #27;

{ TKeyInputTests }

procedure TKeyInputTests.Enter_SendsCR;
begin
  Assert.AreEqual(#13, KeyToVT(VK_RETURN, []));
end;

procedure TKeyInputTests.Backspace_SendsDEL;
begin
  Assert.AreEqual(#127, KeyToVT(VK_BACK, []));
end;

procedure TKeyInputTests.Tab_SendsHT;
begin
  Assert.AreEqual(#9, KeyToVT(VK_TAB, []));
end;

procedure TKeyInputTests.ShiftTab_SendsCBT;
begin
  Assert.AreEqual(ESC + '[Z', KeyToVT(VK_TAB, [ssShift]));
end;

procedure TKeyInputTests.Escape_SendsESC;
begin
  Assert.AreEqual(ESC, KeyToVT(VK_ESCAPE, []));
end;

procedure TKeyInputTests.Arrows_SendCSILetters;
begin
  Assert.AreEqual(ESC + '[A', KeyToVT(VK_UP, []), 'up');
  Assert.AreEqual(ESC + '[B', KeyToVT(VK_DOWN, []), 'down');
  Assert.AreEqual(ESC + '[C', KeyToVT(VK_RIGHT, []), 'right');
  Assert.AreEqual(ESC + '[D', KeyToVT(VK_LEFT, []), 'left');
end;

procedure TKeyInputTests.HomeEnd_SendCSI;
begin
  Assert.AreEqual(ESC + '[H', KeyToVT(VK_HOME, []), 'home');
  Assert.AreEqual(ESC + '[F', KeyToVT(VK_END, []), 'end');
end;

procedure TKeyInputTests.InsertDelete_SendVT220;
begin
  Assert.AreEqual(ESC + '[2~', KeyToVT(VK_INSERT, []), 'insert');
  Assert.AreEqual(ESC + '[3~', KeyToVT(VK_DELETE, []), 'delete');
end;

procedure TKeyInputTests.PageUpDown_SendVT220;
begin
  Assert.AreEqual(ESC + '[5~', KeyToVT(VK_PRIOR, []), 'pgup');
  Assert.AreEqual(ESC + '[6~', KeyToVT(VK_NEXT, []), 'pgdn');
end;

procedure TKeyInputTests.CtrlC_SendsETX;
begin
  Assert.AreEqual(#3, KeyToVT(Ord('C'), [ssCtrl]));
end;

procedure TKeyInputTests.CtrlD_SendsEOT;
begin
  Assert.AreEqual(#4, KeyToVT(Ord('D'), [ssCtrl]));
end;

procedure TKeyInputTests.CtrlL_SendsFF;
begin
  Assert.AreEqual(#12, KeyToVT(Ord('L'), [ssCtrl]));
end;

procedure TKeyInputTests.PlainLetter_ReturnsEmpty;
begin
  // Plain printables are left for KeyPress (WM_CHAR).
  Assert.AreEqual('', KeyToVT(Ord('A'), []));
end;

procedure TKeyInputTests.AltGrLetter_ReturnsEmpty;
begin
  // Ctrl+Alt (AltGr) must not become a control code -- it may produce a printable.
  Assert.AreEqual('', KeyToVT(Ord('A'), [ssCtrl, ssAlt]));
end;

procedure TKeyInputTests.Paste_Plain_PassesThrough;
begin
  Assert.AreEqual('hello', BuildPasteSequence('hello', False));
end;

procedure TKeyInputTests.Paste_Bracketed_WrapsWithMarkers;
begin
  Assert.AreEqual(ESC + '[200~hello' + ESC + '[201~', BuildPasteSequence('hello', True));
end;

procedure TKeyInputTests.Paste_NormalizesCRLFToCR;
begin
  Assert.AreEqual('a'#13'b', BuildPasteSequence('a'#13#10'b', False));
end;

procedure TKeyInputTests.Paste_NormalizesLoneLFToCR;
begin
  Assert.AreEqual('a'#13'b', BuildPasteSequence('a'#10'b', False));
end;

initialization
  TDUnitX.RegisterTestFixture(TKeyInputTests);

end.
