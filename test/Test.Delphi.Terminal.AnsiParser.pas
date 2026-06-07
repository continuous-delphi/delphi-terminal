unit Test.Delphi.Terminal.AnsiParser;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Delphi.Terminal.AnsiParser;

type

  [TestFixture]
  TTestAnsiParser = class
  private
    FParser: TAnsiParser;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure PlainTextReturnsOneSegment;
    [Test] procedure EmptyInputReturnsNoSegments;
    [Test] procedure ForegroundRedSetsColor;
    [Test] procedure ResetClearsAttributes;
    [Test] procedure CombinedBoldAndGreen;
    [Test] procedure NonSGRSequencesAreStripped;
    [Test] procedure PartialSequenceAcrossTwoCalls;
    [Test] procedure PartialEscAtEndOfBuffer;
    [Test] procedure PartialOscBelSequenceAcrossTwoCalls;
    [Test] procedure PartialOscStSequenceAcrossTwoCalls;
    [Test] procedure MultipleSGRCodesInSequence;
    [Test] procedure BrightColorsSupported;
    [Test] procedure BackgroundColorSets;
    [Test] procedure UnderlineAndClear;
    [Test] procedure ConsecutiveTextCoalesces;
    [Test] procedure QuestionMarkParamHandled;
    [Test] procedure ExtColor256Foreground;
    [Test] procedure ExtColor256Background;
    [Test] procedure ExtColorRGBForeground;
    [Test] procedure ExtColorRGBBackground;
    [Test] procedure ExtColor256GrayscaleRamp;
    [Test] procedure ExtColor256ColorCube;
    [Test] procedure ExtColorResetClearsExtended;
    [Test] procedure ExtColorStandardAfterExtended;
  end;

implementation

procedure TTestAnsiParser.Setup;
begin
  FParser := TAnsiParser.Create;
end;

procedure TTestAnsiParser.TearDown;
begin
  FParser.Free;
end;

procedure TTestAnsiParser.PlainTextReturnsOneSegment;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse('Hello World');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Hello World', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acDefault);
end;

procedure TTestAnsiParser.EmptyInputReturnsNoSegments;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse('');
  Assert.AreEqual(NativeInt(0), Length(Segments));
end;

procedure TTestAnsiParser.ForegroundRedSetsColor;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[31mRed text');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Red text', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acRed);
end;

procedure TTestAnsiParser.ResetClearsAttributes;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[31mRed'#27'[0m Normal');
  Assert.AreEqual(NativeInt(2), Length(Segments));
  Assert.AreEqual('Red', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acRed);
  Assert.AreEqual(' Normal', Segments[1].Text);
  Assert.IsTrue(Segments[1].Attr.ForeColor = acDefault);
end;

procedure TTestAnsiParser.CombinedBoldAndGreen;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[1;32mBoldGreen');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('BoldGreen', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acGreen);
  Assert.IsTrue(asBold in Segments[0].Attr.Style);
end;

procedure TTestAnsiParser.NonSGRSequencesAreStripped;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[2J (clear screen) and ESC[H (cursor home) should be stripped
  Segments := FParser.Parse('Before'#27'[2J'#27'[HAfter');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('BeforeAfter', Segments[0].Text);
end;

procedure TTestAnsiParser.PartialSequenceAcrossTwoCalls;
var
  Segments: TArray<TAnsiSegment>;
begin
  // First call ends mid-sequence
  Segments := FParser.Parse('Hello'#27'[3');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Hello', Segments[0].Text);

  // Second call completes the sequence
  Segments := FParser.Parse('2mGreen');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Green', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acGreen);
end;

procedure TTestAnsiParser.PartialEscAtEndOfBuffer;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC at end with no following char
  Segments := FParser.Parse('Text'#27);
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Text', Segments[0].Text);

  // Complete the sequence in next call
  Segments := FParser.Parse('[31mRed');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Red', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acRed);
end;

procedure TTestAnsiParser.PartialOscBelSequenceAcrossTwoCalls;
var
  Segments: TArray<TAnsiSegment>;
begin
  // OSC title sequence split before BEL should be buffered and stripped.
  Segments := FParser.Parse('Before'#27']0;Window Title');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Before', Segments[0].Text);

  Segments := FParser.Parse(#7'After');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('After', Segments[0].Text);
end;

procedure TTestAnsiParser.PartialOscStSequenceAcrossTwoCalls;
var
  Segments: TArray<TAnsiSegment>;
begin
  // OSC title sequence split between ESC and '\' should keep both bytes buffered.
  Segments := FParser.Parse('Before'#27']0;Window Title'#27);
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Before', Segments[0].Text);

  Segments := FParser.Parse('\After');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('After', Segments[0].Text);
end;

procedure TTestAnsiParser.MultipleSGRCodesInSequence;
var
  Segments: TArray<TAnsiSegment>;
begin
  // Two separate SGR sequences
  Segments := FParser.Parse(#27'[1m'#27'[34mBoldBlue');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('BoldBlue', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.ForeColor = acBlue);
  Assert.IsTrue(asBold in Segments[0].Attr.Style);
end;

procedure TTestAnsiParser.BrightColorsSupported;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[91mBrightRed');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.ForeColor = acBrightRed);
end;

procedure TTestAnsiParser.BackgroundColorSets;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[44mBlueBack');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.BackColor = acBlue);
end;

procedure TTestAnsiParser.UnderlineAndClear;
var
  Segments: TArray<TAnsiSegment>;
begin
  Segments := FParser.Parse(#27'[4mUnder'#27'[24mNormal');
  Assert.AreEqual(NativeInt(2), Length(Segments));
  Assert.IsTrue(asUnderline in Segments[0].Attr.Style);
  Assert.IsFalse(asUnderline in Segments[1].Attr.Style);
end;

procedure TTestAnsiParser.ConsecutiveTextCoalesces;
var
  Segments: TArray<TAnsiSegment>;
begin
  // Text with no attribute change between should coalesce
  Segments := FParser.Parse('AB'#27'[2JCD');
  // ESC[2J is stripped, so text is "ABCD" with same attrs -- one segment
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('ABCD', Segments[0].Text);
end;

procedure TTestAnsiParser.QuestionMarkParamHandled;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[?25h (show cursor) should be stripped without error
  Segments := FParser.Parse('A'#27'[?25hB');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('AB', Segments[0].Text);
end;

procedure TTestAnsiParser.ExtColor256Foreground;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[38;5;196m = 256-color red (index 196)
  Segments := FParser.Parse(#27'[38;5;196mColorText');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('ColorText', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
end;

procedure TTestAnsiParser.ExtColor256Background;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[48;5;21m = 256-color background (index 21)
  Segments := FParser.Parse(#27'[48;5;21mBgText');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.UseExtBackColor);
end;

procedure TTestAnsiParser.ExtColorRGBForeground;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[38;2;255;128;0m = RGB orange
  Segments := FParser.Parse(#27'[38;2;255;128;0mOrange');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.AreEqual('Orange', Segments[0].Text);
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  // BGR: B=0, G=128, R=255 -> $00008000 or $80FF -> 0 shl 16 or 128 shl 8 or 255
  Assert.AreEqual(128 shl 8 or 255, Segments[0].Attr.ExtForeColor);
end;

procedure TTestAnsiParser.ExtColorRGBBackground;
var
  Segments: TArray<TAnsiSegment>;
begin
  // ESC[48;2;0;255;0m = RGB green background
  Segments := FParser.Parse(#27'[48;2;0;255;0mGreenBg');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.UseExtBackColor);
  // BGR: B=0, G=255, R=0 -> $00FF00
  Assert.AreEqual($00FF00, Segments[0].Attr.ExtBackColor);
end;

procedure TTestAnsiParser.ExtColor256GrayscaleRamp;
var
  Segments: TArray<TAnsiSegment>;
  Expected: Integer;
begin
  // Index 232 = first grayscale: gray level 8 -> BGR $080808
  Segments := FParser.Parse(#27'[38;5;232mGray');
  Assert.AreEqual(NativeInt(1), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  Expected := 8 shl 16 or 8 shl 8 or 8;
  Assert.AreEqual(Expected, Segments[0].Attr.ExtForeColor);
end;

procedure TTestAnsiParser.ExtColor256ColorCube;
var
  Segments: TArray<TAnsiSegment>;
begin
  // Index 16 = first cube entry: R=0, G=0, B=0 -> $000000
  Segments := FParser.Parse(#27'[38;5;16mBlack');
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  Assert.AreEqual(0, Segments[0].Attr.ExtForeColor);

  // Index 21 = R=0, G=0, B=255 -> BGR $FF0000
  Segments := FParser.Parse(#27'[38;5;21mBlue');
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  Assert.AreEqual(255 shl 16, Segments[0].Attr.ExtForeColor);
end;

procedure TTestAnsiParser.ExtColorResetClearsExtended;
var
  Segments: TArray<TAnsiSegment>;
begin
  // Set extended color, then reset
  Segments := FParser.Parse(#27'[38;5;196mRed'#27'[0mNormal');
  Assert.AreEqual(NativeInt(2), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  Assert.IsFalse(Segments[1].Attr.UseExtForeColor);
  Assert.IsTrue(Segments[1].Attr.ForeColor = acDefault);
end;

procedure TTestAnsiParser.ExtColorStandardAfterExtended;
var
  Segments: TArray<TAnsiSegment>;
begin
  // Set extended color, then standard color should clear extended
  Segments := FParser.Parse(#27'[38;5;196mExt'#27'[32mStd');
  Assert.AreEqual(NativeInt(2), Length(Segments));
  Assert.IsTrue(Segments[0].Attr.UseExtForeColor);
  Assert.IsFalse(Segments[1].Attr.UseExtForeColor);
  Assert.IsTrue(Segments[1].Attr.ForeColor = acGreen);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAnsiParser);

end.

