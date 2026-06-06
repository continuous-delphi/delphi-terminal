unit radTerminal.AnsiParser;

interface

uses
  System.SysUtils, System.Classes;

type
  TAnsiColor = (
    acDefault,
    acBlack, acRed, acGreen, acYellow, acBlue, acMagenta, acCyan, acWhite,
    acBrightBlack, acBrightRed, acBrightGreen, acBrightYellow, acBrightBlue, acBrightMagenta, acBrightCyan, acBrightWhite
  );

  TAnsiStyleFlag = (asBold, asUnderline);
  TAnsiStyle = set of TAnsiStyleFlag;

  TAnsiAttributes = record
    ForeColor: TAnsiColor;
    BackColor: TAnsiColor;
    Style: TAnsiStyle;
    procedure Reset;
  end;

  TAnsiSegment = record
    Text: string;
    Attr: TAnsiAttributes;
  end;

  (*
  The things that do use ANSI codes (and will render in color):
  - Error messages (red)
  - Warning messages (yellow)
  - Verbose/debug messages
  - Progress-related formatting
  - Any tool that writes ANSI directly (e.g., git log --color=always)

  Commands like: `Write-Host -ForegroundColor Red` is different:  uses the .NET Console.ForegroundColor API which talks
  to the console subsystem directly, not through ANSI escape codes. Since we're using pipe redirection (no real
  console), that color information is lost. Same with `Get-ChildItem` output (directories vs files)


  pwsh command to view each color:

   @(30..37 + 90..97) | ForEach-Object { Write-Output "`e[$($_)m  Code $_ : The quick brown fox `e[0m" }; Write-Output
  "`e[1m  Bold`e[0m  `e[4mUnderline`e[0m  `e[1;4mBold+Underline`e[0m"; @(40..47 + 100..107) | ForEach-Object {
  Write-Output "`e[$($_)m  BG Code $_ `e[0m" }

  *)
  TAnsiParser = class
  private
    FCurrentAttr: TAnsiAttributes;
    FPartialSeq: string;
    procedure ApplySGR(const AParams: string);
  public
    constructor Create;
    procedure Reset;
    function Parse(const AInput: string): TArray<TAnsiSegment>;
    property CurrentAttr: TAnsiAttributes read FCurrentAttr;
  end;

implementation

{ TAnsiAttributes }

procedure TAnsiAttributes.Reset;
begin
  ForeColor := acDefault;
  BackColor := acDefault;
  Style := [];
end;

{ TAnsiParser }

constructor TAnsiParser.Create;
begin
  inherited Create;
  FCurrentAttr.Reset;
  FPartialSeq := '';
end;

procedure TAnsiParser.Reset;
begin
  FCurrentAttr.Reset;
  FPartialSeq := '';
end;

procedure TAnsiParser.ApplySGR(const AParams: string);
var
  Parts: TArray<string>;
  I, Code: Integer;
begin
  if AParams = '' then
  begin
    FCurrentAttr.Reset;
    Exit;
  end;

  Parts := AParams.Split([';']);
  I := 0;
  while I < Length(Parts) do
  begin
    Code := StrToIntDef(Parts[I], 0);
    case Code of
      0: FCurrentAttr.Reset;
      1: Include(FCurrentAttr.Style, asBold);
      4: Include(FCurrentAttr.Style, asUnderline);
      22: Exclude(FCurrentAttr.Style, asBold);
      24: Exclude(FCurrentAttr.Style, asUnderline);
      30: FCurrentAttr.ForeColor := acBlack;
      31: FCurrentAttr.ForeColor := acRed;
      32: FCurrentAttr.ForeColor := acGreen;
      33: FCurrentAttr.ForeColor := acYellow;
      34: FCurrentAttr.ForeColor := acBlue;
      35: FCurrentAttr.ForeColor := acMagenta;
      36: FCurrentAttr.ForeColor := acCyan;
      37: FCurrentAttr.ForeColor := acWhite;
      39: FCurrentAttr.ForeColor := acDefault;
      40: FCurrentAttr.BackColor := acBlack;
      41: FCurrentAttr.BackColor := acRed;
      42: FCurrentAttr.BackColor := acGreen;
      43: FCurrentAttr.BackColor := acYellow;
      44: FCurrentAttr.BackColor := acBlue;
      45: FCurrentAttr.BackColor := acMagenta;
      46: FCurrentAttr.BackColor := acCyan;
      47: FCurrentAttr.BackColor := acWhite;
      49: FCurrentAttr.BackColor := acDefault;
      90: FCurrentAttr.ForeColor := acBrightBlack;
      91: FCurrentAttr.ForeColor := acBrightRed;
      92: FCurrentAttr.ForeColor := acBrightGreen;
      93: FCurrentAttr.ForeColor := acBrightYellow;
      94: FCurrentAttr.ForeColor := acBrightBlue;
      95: FCurrentAttr.ForeColor := acBrightMagenta;
      96: FCurrentAttr.ForeColor := acBrightCyan;
      97: FCurrentAttr.ForeColor := acBrightWhite;
      100: FCurrentAttr.BackColor := acBrightBlack;
      101: FCurrentAttr.BackColor := acBrightRed;
      102: FCurrentAttr.BackColor := acBrightGreen;
      103: FCurrentAttr.BackColor := acBrightYellow;
      104: FCurrentAttr.BackColor := acBrightBlue;
      105: FCurrentAttr.BackColor := acBrightMagenta;
      106: FCurrentAttr.BackColor := acBrightCyan;
      107: FCurrentAttr.BackColor := acBrightWhite;
    end;
    Inc(I);
  end;
end;

function TAnsiParser.Parse(const AInput: string): TArray<TAnsiSegment>;
var
  Input: string;
  I, Len: Integer;
  PlainText: string;
  SeqParams: string;
  Seg: TAnsiSegment;

  procedure FlushPlainText;
  begin
    if PlainText <> '' then
    begin
      Seg.Text := PlainText;
      Seg.Attr := FCurrentAttr;
      Result := Result + [Seg];
      PlainText := '';
    end;
  end;

begin
  Result := nil;
  Input := FPartialSeq + AInput;
  FPartialSeq := '';
  Len := Length(Input);
  if Len = 0 then
    Exit;

  PlainText := '';
  I := 1;
  while I <= Len do
  begin
    if Input[I] = #27 then
    begin
      // Check if we have at least ESC[
      if I + 1 > Len then
      begin
        // ESC at end of buffer -- partial sequence
        FlushPlainText;
        FPartialSeq := Copy(Input, I, Len - I + 1);
        Exit;
      end;

      if Input[I + 1] = '[' then
      begin
        // CSI sequence: ESC [ params command
        Inc(I, 2); // skip ESC[
        SeqParams := '';
        while (I <= Len) and CharInSet(Input[I], ['0'..'9', ';', '?']) do
        begin
          SeqParams := SeqParams + Input[I];
          Inc(I);
        end;
        if I > Len then
        begin
          // Incomplete sequence -- store for next call
          FlushPlainText;
          FPartialSeq := #27'[' + SeqParams;
          Exit;
        end;
        // I now points to the command character
        if Input[I] = 'm' then
        begin
          FlushPlainText;
          ApplySGR(SeqParams);
        end;
        // All other CSI commands (H, J, K, A, B, C, D, etc.) are silently stripped
        Inc(I);
      end
      else if Input[I + 1] = ']' then
      begin
        // OSC sequence: ESC ] ... ST (or BEL)
        Inc(I, 2);
        while (I <= Len) and (Input[I] <> #7) do
        begin
          if (Input[I] = #27) and (I + 1 <= Len) and (Input[I + 1] = '\') then
          begin
            Inc(I, 2);
            Break;
          end;
          Inc(I);
        end;
        if I <= Len then
          Inc(I); // skip BEL
        // OSC sequences are stripped
      end
      else
      begin
        // Other ESC sequences (ESC followed by single char) -- strip
        Inc(I, 2);
      end;
    end
    else
    begin
      PlainText := PlainText + Input[I];
      Inc(I);
    end;
  end;

  FlushPlainText;
end;

end.
