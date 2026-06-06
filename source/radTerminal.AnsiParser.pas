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
    UseExtForeColor: Boolean;
    UseExtBackColor: Boolean;
    ExtForeColor: Integer;  // BGR color value when UseExtForeColor is True
    ExtBackColor: Integer;  // BGR color value when UseExtBackColor is True
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
  "`e[1m  Bold`e[0m  `e[4mUnderline`e[0m  `e[1;4mBold+Underline`e[0m"; @(40..47 + 100..107)

  *)
  TAnsiParser = class
  private
    FCurrentAttr: TAnsiAttributes;
    FPartialSeq: string;
    class function Color256ToBGR(AIndex: Integer): Integer; static;
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
  UseExtForeColor := False;
  UseExtBackColor := False;
  ExtForeColor := 0;
  ExtBackColor := 0;
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

class function TAnsiParser.Color256ToBGR(AIndex: Integer): Integer;
const
  // Standard 16 colors (indices 0-15) in BGR
  Base16: array[0..15] of Integer = (
    $000000, $0000AA, $00AA00, $00AAAA, $AA0000, $AA00AA, $AA5500, $AAAAAA,
    $555555, $5555FF, $55FF55, $55FFFF, $FF5555, $FF55FF, $55FFFF, $FFFFFF
  );
var
  R, G, B, Gray: Integer;
begin
  if AIndex < 16 then
    Result := Base16[AIndex]
  else if AIndex < 232 then
  begin
    // 6x6x6 color cube (indices 16-231)
    AIndex := AIndex - 16;
    B := (AIndex mod 6) * 51;
    G := ((AIndex div 6) mod 6) * 51;
    R := (AIndex div 36) * 51;
    Result := B shl 16 or G shl 8 or R;
  end
  else
  begin
    // Grayscale ramp (indices 232-255): 8, 18, 28, ..., 238
    Gray := (AIndex - 232) * 10 + 8;
    Result := Gray shl 16 or Gray shl 8 or Gray;
  end;
end;

procedure TAnsiParser.ApplySGR(const AParams: string);
var
  Parts: TArray<string>;
  I, Code, Sub, N, R, G, B: Integer;
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
      30: begin FCurrentAttr.ForeColor := acBlack; FCurrentAttr.UseExtForeColor := False; end;
      31: begin FCurrentAttr.ForeColor := acRed; FCurrentAttr.UseExtForeColor := False; end;
      32: begin FCurrentAttr.ForeColor := acGreen; FCurrentAttr.UseExtForeColor := False; end;
      33: begin FCurrentAttr.ForeColor := acYellow; FCurrentAttr.UseExtForeColor := False; end;
      34: begin FCurrentAttr.ForeColor := acBlue; FCurrentAttr.UseExtForeColor := False; end;
      35: begin FCurrentAttr.ForeColor := acMagenta; FCurrentAttr.UseExtForeColor := False; end;
      36: begin FCurrentAttr.ForeColor := acCyan; FCurrentAttr.UseExtForeColor := False; end;
      37: begin FCurrentAttr.ForeColor := acWhite; FCurrentAttr.UseExtForeColor := False; end;
      39: begin FCurrentAttr.ForeColor := acDefault; FCurrentAttr.UseExtForeColor := False; end;
      40: begin FCurrentAttr.BackColor := acBlack; FCurrentAttr.UseExtBackColor := False; end;
      41: begin FCurrentAttr.BackColor := acRed; FCurrentAttr.UseExtBackColor := False; end;
      42: begin FCurrentAttr.BackColor := acGreen; FCurrentAttr.UseExtBackColor := False; end;
      43: begin FCurrentAttr.BackColor := acYellow; FCurrentAttr.UseExtBackColor := False; end;
      44: begin FCurrentAttr.BackColor := acBlue; FCurrentAttr.UseExtBackColor := False; end;
      45: begin FCurrentAttr.BackColor := acMagenta; FCurrentAttr.UseExtBackColor := False; end;
      46: begin FCurrentAttr.BackColor := acCyan; FCurrentAttr.UseExtBackColor := False; end;
      47: begin FCurrentAttr.BackColor := acWhite; FCurrentAttr.UseExtBackColor := False; end;
      49: begin FCurrentAttr.BackColor := acDefault; FCurrentAttr.UseExtBackColor := False; end;
      38, 48:
      begin
        // Extended color: 38;5;N (256-color) or 38;2;R;G;B (RGB)
        if I + 1 < Length(Parts) then
        begin
          Sub := StrToIntDef(Parts[I + 1], 0);
          if (Sub = 5) and (I + 2 < Length(Parts)) then
          begin
            N := StrToIntDef(Parts[I + 2], 0);
            if Code = 38 then
            begin
              FCurrentAttr.UseExtForeColor := True;
              FCurrentAttr.ExtForeColor := Color256ToBGR(N);
            end
            else
            begin
              FCurrentAttr.UseExtBackColor := True;
              FCurrentAttr.ExtBackColor := Color256ToBGR(N);
            end;
            Inc(I, 2);
          end
          else if (Sub = 2) and (I + 4 < Length(Parts)) then
          begin
            R := StrToIntDef(Parts[I + 2], 0);
            G := StrToIntDef(Parts[I + 3], 0);
            B := StrToIntDef(Parts[I + 4], 0);
            if Code = 38 then
            begin
              FCurrentAttr.UseExtForeColor := True;
              FCurrentAttr.ExtForeColor := B shl 16 or G shl 8 or R;
            end
            else
            begin
              FCurrentAttr.UseExtBackColor := True;
              FCurrentAttr.ExtBackColor := B shl 16 or G shl 8 or R;
            end;
            Inc(I, 4);
          end;
        end;
      end;
      90: begin FCurrentAttr.ForeColor := acBrightBlack; FCurrentAttr.UseExtForeColor := False; end;
      91: begin FCurrentAttr.ForeColor := acBrightRed; FCurrentAttr.UseExtForeColor := False; end;
      92: begin FCurrentAttr.ForeColor := acBrightGreen; FCurrentAttr.UseExtForeColor := False; end;
      93: begin FCurrentAttr.ForeColor := acBrightYellow; FCurrentAttr.UseExtForeColor := False; end;
      94: begin FCurrentAttr.ForeColor := acBrightBlue; FCurrentAttr.UseExtForeColor := False; end;
      95: begin FCurrentAttr.ForeColor := acBrightMagenta; FCurrentAttr.UseExtForeColor := False; end;
      96: begin FCurrentAttr.ForeColor := acBrightCyan; FCurrentAttr.UseExtForeColor := False; end;
      97: begin FCurrentAttr.ForeColor := acBrightWhite; FCurrentAttr.UseExtForeColor := False; end;
      100: begin FCurrentAttr.BackColor := acBrightBlack; FCurrentAttr.UseExtBackColor := False; end;
      101: begin FCurrentAttr.BackColor := acBrightRed; FCurrentAttr.UseExtBackColor := False; end;
      102: begin FCurrentAttr.BackColor := acBrightGreen; FCurrentAttr.UseExtBackColor := False; end;
      103: begin FCurrentAttr.BackColor := acBrightYellow; FCurrentAttr.UseExtBackColor := False; end;
      104: begin FCurrentAttr.BackColor := acBrightBlue; FCurrentAttr.UseExtBackColor := False; end;
      105: begin FCurrentAttr.BackColor := acBrightMagenta; FCurrentAttr.UseExtBackColor := False; end;
      106: begin FCurrentAttr.BackColor := acBrightCyan; FCurrentAttr.UseExtBackColor := False; end;
      107: begin FCurrentAttr.BackColor := acBrightWhite; FCurrentAttr.UseExtBackColor := False; end;
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
