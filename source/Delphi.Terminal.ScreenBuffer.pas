(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Terminal screen model: a grid of character cells with per-cell colour and
  style, a cursor, and the current writing attributes. Pure logic (no VCL / no
  WinAPI) so it is fully unit-testable and independent of rendering.

  This unit is the M6 "core": cells, cursor, attributes, write and erase.
  Scroll regions, alternate screen, scrollback and resize are added separately.

*)
unit Delphi.Terminal.ScreenBuffer;

interface

type
  ///<summary>How a cell colour is specified: the terminal default, a palette index (0..255), or 24-bit RGB.</summary>
  TCellColorKind = (cckDefault, cckIndexed, cckRGB);

  TCellColor = record
    Kind: TCellColorKind;
    Index: Byte;       // valid when Kind = cckIndexed
    RGB: Cardinal;     // valid when Kind = cckRGB ($00RRGGBB)
  end;

  TCellStyleFlag = (csfBold, csfItalic, csfUnderline, csfInverse);
  TCellStyle = set of TCellStyleFlag;

  TTerminalCell = record
    Ch: Char;
    Foreground: TCellColor;
    Background: TCellColor;
    Style: TCellStyle;
  end;

  TScreenBuffer = class
  private
    FCols: Integer;
    FRows: Integer;
    FCells: array of TTerminalCell;
    FCursorCol: Integer;
    FCursorRow: Integer;
    FForeground: TCellColor;
    FBackground: TCellColor;
    FStyle: TCellStyle;
    function IndexOf(ACol, ARow: Integer): Integer; inline;
    function BlankCell: TTerminalCell;
    procedure FillAll;
    procedure ClampCursor;
  public
    constructor Create(ACols, ARows: Integer);

    ///<summary>Blanks the whole screen (using the current background) and homes the cursor.</summary>
    procedure ClearAll;

    ///<summary>Positions the cursor, clamped to the screen bounds.</summary>
    procedure SetCursor(ACol, ARow: Integer);
    ///<summary>Writes one character at the cursor with the current attributes, then advances (wrapping to the next line; clamped at the bottom).</summary>
    procedure PutChar(ACh: Char);
    ///<summary>Writes a run of characters via PutChar. Control characters are not interpreted here (that is the parser's job).</summary>
    procedure WriteText(const AText: string);

    ///<summary>Erase in line: 0 = cursor to end, 1 = start to cursor, 2 = whole line.</summary>
    procedure EraseInLine(AMode: Integer);
    ///<summary>Erase in display: 0 = cursor to end, 1 = start to cursor, 2 = whole screen (cursor unchanged).</summary>
    procedure EraseInDisplay(AMode: Integer);

    ///<summary>Sets the attributes used for subsequent writes and erases.</summary>
    procedure SetAttributes(const AForeground, ABackground: TCellColor; const AStyle: TCellStyle);

    ///<summary>Reads a cell (returns a blank cell for out-of-range coordinates).</summary>
    function GetCell(ACol, ARow: Integer): TTerminalCell;

    property Cols: Integer read FCols;
    property Rows: Integer read FRows;
    property CursorCol: Integer read FCursorCol;
    property CursorRow: Integer read FCursorRow;
    property CurrentForeground: TCellColor read FForeground write FForeground;
    property CurrentBackground: TCellColor read FBackground write FBackground;
    property CurrentStyle: TCellStyle read FStyle write FStyle;
  end;

function DefaultColor: TCellColor;
function IndexedColor(AIndex: Byte): TCellColor;
function RGBColor(ARGB: Cardinal): TCellColor;

implementation

function DefaultColor: TCellColor;
begin
  Result.Kind := cckDefault;
  Result.Index := 0;
  Result.RGB := 0;
end;

function IndexedColor(AIndex: Byte): TCellColor;
begin
  Result.Kind := cckIndexed;
  Result.Index := AIndex;
  Result.RGB := 0;
end;

function RGBColor(ARGB: Cardinal): TCellColor;
begin
  Result.Kind := cckRGB;
  Result.Index := 0;
  Result.RGB := ARGB;
end;

{ TScreenBuffer }

constructor TScreenBuffer.Create(ACols, ARows: Integer);
begin
  inherited Create;
  if ACols < 1 then ACols := 1;
  if ARows < 1 then ARows := 1;
  FCols := ACols;
  FRows := ARows;
  SetLength(FCells, FCols * FRows);
  FForeground := DefaultColor;
  FBackground := DefaultColor;
  FStyle := [];
  ClearAll;
end;

function TScreenBuffer.IndexOf(ACol, ARow: Integer): Integer;
begin
  Result := ARow * FCols + ACol;
end;

function TScreenBuffer.BlankCell: TTerminalCell;
begin
  Result.Ch := ' ';
  Result.Foreground := DefaultColor;
  Result.Background := FBackground;   // erased cells take the current background
  Result.Style := [];
end;

procedure TScreenBuffer.FillAll;
var
  I: Integer;
  LBlank: TTerminalCell;
begin
  LBlank := BlankCell;
  for I := 0 to High(FCells) do
    FCells[I] := LBlank;
end;

procedure TScreenBuffer.ClampCursor;
begin
  if FCursorCol < 0 then FCursorCol := 0;
  if FCursorCol > FCols - 1 then FCursorCol := FCols - 1;
  if FCursorRow < 0 then FCursorRow := 0;
  if FCursorRow > FRows - 1 then FCursorRow := FRows - 1;
end;

procedure TScreenBuffer.ClearAll;
begin
  FillAll;
  FCursorCol := 0;
  FCursorRow := 0;
end;

procedure TScreenBuffer.SetCursor(ACol, ARow: Integer);
begin
  FCursorCol := ACol;
  FCursorRow := ARow;
  ClampCursor;
end;

procedure TScreenBuffer.PutChar(ACh: Char);
var
  Idx: Integer;
begin
  if (FCursorCol >= 0) and (FCursorCol < FCols) and (FCursorRow >= 0) and (FCursorRow < FRows) then
  begin
    Idx := IndexOf(FCursorCol, FCursorRow);
    FCells[Idx].Ch := ACh;
    FCells[Idx].Foreground := FForeground;
    FCells[Idx].Background := FBackground;
    FCells[Idx].Style := FStyle;
  end;

  Inc(FCursorCol);
  if FCursorCol >= FCols then
  begin
    FCursorCol := 0;
    Inc(FCursorRow);
    if FCursorRow >= FRows then
      FCursorRow := FRows - 1;   // clamp at the bottom (scrolling is added separately)
  end;
end;

procedure TScreenBuffer.WriteText(const AText: string);
var
  I: Integer;
begin
  for I := Low(AText) to High(AText) do
    PutChar(AText[I]);
end;

procedure TScreenBuffer.EraseInLine(AMode: Integer);
var
  Col, First, Last: Integer;
  LBlank: TTerminalCell;
begin
  case AMode of
    0: begin First := FCursorCol; Last := FCols - 1; end;   // cursor to end
    1: begin First := 0;          Last := FCursorCol; end;  // start to cursor
    2: begin First := 0;          Last := FCols - 1; end;   // whole line
  else
    Exit;
  end;
  LBlank := BlankCell;
  for Col := First to Last do
    FCells[IndexOf(Col, FCursorRow)] := LBlank;
end;

procedure TScreenBuffer.EraseInDisplay(AMode: Integer);
var
  Row, Col: Integer;
  LBlank: TTerminalCell;
begin
  LBlank := BlankCell;
  case AMode of
    0: // cursor to end of screen
      begin
        EraseInLine(0);
        for Row := FCursorRow + 1 to FRows - 1 do
          for Col := 0 to FCols - 1 do
            FCells[IndexOf(Col, Row)] := LBlank;
      end;
    1: // start of screen to cursor
      begin
        for Row := 0 to FCursorRow - 1 do
          for Col := 0 to FCols - 1 do
            FCells[IndexOf(Col, Row)] := LBlank;
        EraseInLine(1);
      end;
    2: // whole screen; cursor unchanged (unlike ClearAll)
      FillAll;
  end;
end;

procedure TScreenBuffer.SetAttributes(const AForeground, ABackground: TCellColor; const AStyle: TCellStyle);
begin
  FForeground := AForeground;
  FBackground := ABackground;
  FStyle := AStyle;
end;

function TScreenBuffer.GetCell(ACol, ARow: Integer): TTerminalCell;
begin
  if (ACol >= 0) and (ACol < FCols) and (ARow >= 0) and (ARow < FRows) then
    Result := FCells[IndexOf(ACol, ARow)]
  else
    Result := BlankCell;
end;

end.
