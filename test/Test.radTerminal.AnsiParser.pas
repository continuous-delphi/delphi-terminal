unit Test.radTerminal.AnsiParser;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  radTerminal.AnsiParser;

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
    [Test] procedure MultipleSGRCodesInSequence;
    [Test] procedure BrightColorsSupported;
    [Test] procedure BackgroundColorSets;
    [Test] procedure UnderlineAndClear;
    [Test] procedure ConsecutiveTextCoalesces;
    [Test] procedure QuestionMarkParamHandled;
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

initialization
  TDUnitX.RegisterTestFixture(TTestAnsiParser);

end.
