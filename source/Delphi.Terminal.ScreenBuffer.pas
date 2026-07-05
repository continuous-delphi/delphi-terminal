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

  Covers the M6 model: cells, cursor, attributes, write and erase (#61), plus
  scroll region, alternate screen, scrollback and resize with dirty-row
  tracking (#62).

*)
unit Delphi.Terminal.ScreenBuffer;

interface

uses
  System.Generics.Collections;

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

  ///<summary>Shell prompt state as reported by OSC 133 shell-integration markers
  /// (A prompt start, B command-input start, C command executed, D command finished).
  /// spsUnknown means the shell has emitted no markers this session.</summary>
  TShellPromptState = (spsUnknown, spsPromptStart, spsCommandInput, spsExecuting, spsCommandFinished);

  TScreenBuffer = class
  private
    FCols: Integer;
    FRows: Integer;
    FCells: TArray<TTerminalCell>;
    FCursorCol: Integer;
    FCursorRow: Integer;
    FForeground: TCellColor;
    FBackground: TCellColor;
    FStyle: TCellStyle;
    FScrollTop: Integer;
    FScrollBottom: Integer;
    FAltActive: Boolean;
    FMainCells: TArray<TTerminalCell>;
    FSavedCursorCol: Integer;
    FSavedCursorRow: Integer;
    FScrollback: TList<TArray<TTerminalCell>>;
    FScrollbackLimit: Integer;
    FCursorVisible: Boolean;
    FBracketedPaste: Boolean;
    FPromptState: TShellPromptState;   // OSC 133 shell-integration prompt state
    FWrapPending: Boolean;   // DECAWM: cursor sits past the last column awaiting the next char
    FDirty: TArray<Boolean>;
    function IndexOf(ACol, ARow: Integer): Integer; inline;
    function BlankCell: TTerminalCell;
    procedure FillAll;
    procedure ClampCursor;
    procedure PushScrollback(const ALine: TArray<TTerminalCell>);
  public
    constructor Create(ACols, ARows: Integer);
    destructor Destroy; override;

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

    // --- In-place line editing (ECH / ICH / DCH / IL / DL) ---
    ///<summary>ECH: blanks ACount cells from the cursor without moving it (clamped to the line end).</summary>
    procedure EraseChars(ACount: Integer);
    ///<summary>ICH: inserts ACount blanks at the cursor, shifting the rest of the line right (cursor unchanged).</summary>
    procedure InsertChars(ACount: Integer);
    ///<summary>DCH: deletes ACount cells at the cursor, shifting the rest of the line left and blanking the tail.</summary>
    procedure DeleteChars(ACount: Integer);
    ///<summary>IL: inserts ACount blank lines at the cursor row within the scroll region, shifting lines down.</summary>
    procedure InsertLines(ACount: Integer);
    ///<summary>DL: deletes ACount lines at the cursor row within the scroll region, shifting lines up.</summary>
    procedure DeleteLines(ACount: Integer);

    ///<summary>Sets the attributes used for subsequent writes and erases.</summary>
    procedure SetAttributes(const AForeground, ABackground: TCellColor; const AStyle: TCellStyle);

    // --- Scroll region ---
    ///<summary>Sets the top/bottom scroll margins (inclusive). Invalid ranges reset to the full screen.</summary>
    procedure SetScrollRegion(ATop, ABottom: Integer);
    ///<summary>Scrolls the region up by ACount lines; on the main screen with a top-anchored region, departing lines go to scrollback.</summary>
    procedure ScrollUp(ACount: Integer);
    ///<summary>Scrolls the region down by ACount lines (no scrollback).</summary>
    procedure ScrollDown(ACount: Integer);
    ///<summary>Index: moves the cursor down one line, scrolling the region up when at the bottom margin.</summary>
    procedure LineFeed;
    ///<summary>Reverse index: moves the cursor up one line, scrolling the region down when at the top margin.</summary>
    procedure ReverseLineFeed;

    // --- Alternate screen ---
    ///<summary>Switches to a blank alternate screen, saving the main screen and cursor.</summary>
    procedure EnterAltScreen;
    ///<summary>Restores the main screen and cursor.</summary>
    procedure ExitAltScreen;

    // --- Resize ---
    ///<summary>Resizes the grid, preserving the top-left content, clamping the cursor, and resetting the scroll region.</summary>
    procedure Resize(ACols, ARows: Integer);

    // --- Dirty-row tracking (for incremental rendering) ---
    procedure MarkRowDirty(ARow: Integer);
    procedure MarkAllDirty;
    procedure ResetDirty;
    function IsRowDirty(ARow: Integer): Boolean;

    // --- Scrollback access ---
    function ScrollbackCount: Integer;
    function GetScrollbackLine(AIndex: Integer): TArray<TTerminalCell>;

    ///<summary>Reads a cell (returns a blank cell for out-of-range coordinates).</summary>
    function GetCell(ACol, ARow: Integer): TTerminalCell;

    ///<summary>Whether the shell is safe to inject into: not on the alternate screen, and
    /// -- per OSC 133 markers when present -- at/awaiting a prompt rather than running a
    /// command. With no markers, falls back to AForegroundChild (a live child in the Job
    /// Object means a foreground command is running).</summary>
    function IsIdleAtPrompt(AForegroundChild: Boolean): Boolean;

    property Cols: Integer read FCols;
    property Rows: Integer read FRows;
    property CursorCol: Integer read FCursorCol;
    property CursorRow: Integer read FCursorRow;
    property ScrollTop: Integer read FScrollTop;
    property ScrollBottom: Integer read FScrollBottom;
    property AltActive: Boolean read FAltActive;
    property ScrollbackLimit: Integer read FScrollbackLimit write FScrollbackLimit;
    ///<summary>Whether the cursor should be drawn (DEC mode ?25).</summary>
    property CursorVisible: Boolean read FCursorVisible write FCursorVisible;
    ///<summary>Whether bracketed paste mode is active (DEC mode ?2004); read by the input path.</summary>
    property BracketedPaste: Boolean read FBracketedPaste write FBracketedPaste;
    ///<summary>Shell prompt state from OSC 133 markers; set by the VT parser, read by the idle gate.</summary>
    property PromptState: TShellPromptState read FPromptState write FPromptState;
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
  SetLength(FDirty, FRows);
  FForeground := DefaultColor;
  FBackground := DefaultColor;
  FStyle := [];
  FScrollTop := 0;
  FScrollBottom := FRows - 1;
  FAltActive := False;
  FScrollbackLimit := 1000;
  FCursorVisible := True;
  FBracketedPaste := False;
  FPromptState := spsUnknown;
  FScrollback := TList<TArray<TTerminalCell>>.Create;
  ClearAll;
end;

destructor TScreenBuffer.Destroy;
begin
  FScrollback.Free;
  inherited;
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
  MarkAllDirty;
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
  FWrapPending := False;
end;

procedure TScreenBuffer.SetCursor(ACol, ARow: Integer);
begin
  FWrapPending := False;       // any explicit cursor move cancels a pending wrap
  MarkRowDirty(FCursorRow);   // repaint the row the cursor leaves
  FCursorCol := ACol;
  FCursorRow := ARow;
  ClampCursor;
  MarkRowDirty(FCursorRow);   // and the row it enters
end;

procedure TScreenBuffer.PutChar(ACh: Char);
var
  Idx: Integer;
begin
  // Deferred wrap (DECAWM): a char written to the last column leaves the cursor
  // parked there; the wrap is performed here, only when the next char arrives.
  if FWrapPending then
  begin
    FWrapPending := False;
    FCursorCol := 0;
    if FCursorRow = FScrollBottom then
      ScrollUp(1)
    else if FCursorRow < FRows - 1 then
      Inc(FCursorRow);
  end;

  if (FCursorCol >= 0) and (FCursorCol < FCols) and (FCursorRow >= 0) and (FCursorRow < FRows) then
  begin
    Idx := IndexOf(FCursorCol, FCursorRow);
    FCells[Idx].Ch := ACh;
    FCells[Idx].Foreground := FForeground;
    FCells[Idx].Background := FBackground;
    FCells[Idx].Style := FStyle;
    MarkRowDirty(FCursorRow);
  end;

  if FCursorCol >= FCols - 1 then
    FWrapPending := True         // reached the last column: defer the wrap
  else
    Inc(FCursorCol);
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
  MarkRowDirty(FCursorRow);
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
        begin
          for Col := 0 to FCols - 1 do
            FCells[IndexOf(Col, Row)] := LBlank;
          MarkRowDirty(Row);
        end;
      end;
    1: // start of screen to cursor
      begin
        for Row := 0 to FCursorRow - 1 do
        begin
          for Col := 0 to FCols - 1 do
            FCells[IndexOf(Col, Row)] := LBlank;
          MarkRowDirty(Row);
        end;
        EraseInLine(1);
      end;
    2: // whole screen; cursor unchanged (unlike ClearAll)
      FillAll;
  end;
end;

procedure TScreenBuffer.EraseChars(ACount: Integer);
var
  Col, Last: Integer;
  LBlank: TTerminalCell;
begin
  if ACount < 1 then ACount := 1;
  LBlank := BlankCell;
  Last := FCursorCol + ACount - 1;
  if Last > FCols - 1 then Last := FCols - 1;
  for Col := FCursorCol to Last do
    FCells[IndexOf(Col, FCursorRow)] := LBlank;
  MarkRowDirty(FCursorRow);
end;

procedure TScreenBuffer.InsertChars(ACount: Integer);
var
  Col: Integer;
  LBlank: TTerminalCell;
begin
  if ACount < 1 then ACount := 1;
  if ACount > FCols - FCursorCol then ACount := FCols - FCursorCol;
  // Shift the tail right, dropping cells pushed past the line end.
  for Col := FCols - 1 downto FCursorCol + ACount do
    FCells[IndexOf(Col, FCursorRow)] := FCells[IndexOf(Col - ACount, FCursorRow)];
  // Blank the inserted gap.
  LBlank := BlankCell;
  for Col := FCursorCol to FCursorCol + ACount - 1 do
    FCells[IndexOf(Col, FCursorRow)] := LBlank;
  MarkRowDirty(FCursorRow);
end;

procedure TScreenBuffer.DeleteChars(ACount: Integer);
var
  Col: Integer;
  LBlank: TTerminalCell;
begin
  if ACount < 1 then ACount := 1;
  if ACount > FCols - FCursorCol then ACount := FCols - FCursorCol;
  // Shift the tail left.
  for Col := FCursorCol to FCols - 1 - ACount do
    FCells[IndexOf(Col, FCursorRow)] := FCells[IndexOf(Col + ACount, FCursorRow)];
  // Blank the vacated cells at the end of the line.
  LBlank := BlankCell;
  for Col := FCols - ACount to FCols - 1 do
    FCells[IndexOf(Col, FCursorRow)] := LBlank;
  MarkRowDirty(FCursorRow);
end;

procedure TScreenBuffer.InsertLines(ACount: Integer);
var
  R, C, MaxLines: Integer;
  LBlank: TTerminalCell;
begin
  if (FCursorRow < FScrollTop) or (FCursorRow > FScrollBottom) then Exit;
  if ACount < 1 then ACount := 1;
  MaxLines := FScrollBottom - FCursorRow + 1;
  if ACount > MaxLines then ACount := MaxLines;

  // Shift lines down within [cursor row .. scroll bottom].
  for R := FScrollBottom downto FCursorRow + ACount do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := FCells[IndexOf(C, R - ACount)];

  // Blank the inserted lines.
  LBlank := BlankCell;
  for R := FCursorRow to FCursorRow + ACount - 1 do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := LBlank;

  for R := FCursorRow to FScrollBottom do
    MarkRowDirty(R);
end;

procedure TScreenBuffer.DeleteLines(ACount: Integer);
var
  R, C, MaxLines: Integer;
  LBlank: TTerminalCell;
begin
  if (FCursorRow < FScrollTop) or (FCursorRow > FScrollBottom) then Exit;
  if ACount < 1 then ACount := 1;
  MaxLines := FScrollBottom - FCursorRow + 1;
  if ACount > MaxLines then ACount := MaxLines;

  // Shift lines up within [cursor row .. scroll bottom].
  for R := FCursorRow to FScrollBottom - ACount do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := FCells[IndexOf(C, R + ACount)];

  // Blank the vacated lines at the bottom of the region.
  LBlank := BlankCell;
  for R := FScrollBottom - ACount + 1 to FScrollBottom do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := LBlank;

  for R := FCursorRow to FScrollBottom do
    MarkRowDirty(R);
end;

procedure TScreenBuffer.SetAttributes(const AForeground, ABackground: TCellColor; const AStyle: TCellStyle);
begin
  FForeground := AForeground;
  FBackground := ABackground;
  FStyle := AStyle;
end;

procedure TScreenBuffer.SetScrollRegion(ATop, ABottom: Integer);
begin
  if (ATop < 0) or (ABottom > FRows - 1) or (ATop >= ABottom) then
  begin
    FScrollTop := 0;
    FScrollBottom := FRows - 1;
  end
  else
  begin
    FScrollTop := ATop;
    FScrollBottom := ABottom;
  end;
end;

procedure TScreenBuffer.PushScrollback(const ALine: TArray<TTerminalCell>);
begin
  FScrollback.Add(ALine);
  while (FScrollbackLimit > 0) and (FScrollback.Count > FScrollbackLimit) do
    FScrollback.Delete(0);
end;

procedure TScreenBuffer.ScrollUp(ACount: Integer);
var
  RegionHeight, R, C, SrcRow: Integer;
  LLine: TArray<TTerminalCell>;
  LBlank: TTerminalCell;
begin
  RegionHeight := FScrollBottom - FScrollTop + 1;
  if ACount < 1 then Exit;
  if ACount > RegionHeight then ACount := RegionHeight;

  // Capture scrolled-off lines into scrollback (main screen, top-anchored region only).
  if (not FAltActive) and (FScrollTop = 0) then
    for R := 0 to ACount - 1 do
    begin
      SetLength(LLine, FCols);
      for C := 0 to FCols - 1 do
        LLine[C] := FCells[IndexOf(C, FScrollTop + R)];
      PushScrollback(LLine);
    end;

  // Shift rows up within the region.
  for R := FScrollTop to FScrollBottom - ACount do
  begin
    SrcRow := R + ACount;
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := FCells[IndexOf(C, SrcRow)];
  end;

  // Blank the vacated bottom rows.
  LBlank := BlankCell;
  for R := FScrollBottom - ACount + 1 to FScrollBottom do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := LBlank;

  for R := FScrollTop to FScrollBottom do
    MarkRowDirty(R);
end;

procedure TScreenBuffer.ScrollDown(ACount: Integer);
var
  RegionHeight, R, C, SrcRow: Integer;
  LBlank: TTerminalCell;
begin
  RegionHeight := FScrollBottom - FScrollTop + 1;
  if ACount < 1 then Exit;
  if ACount > RegionHeight then ACount := RegionHeight;

  // Shift rows down within the region (bottom lines are discarded, no scrollback).
  for R := FScrollBottom downto FScrollTop + ACount do
  begin
    SrcRow := R - ACount;
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := FCells[IndexOf(C, SrcRow)];
  end;

  // Blank the vacated top rows.
  LBlank := BlankCell;
  for R := FScrollTop to FScrollTop + ACount - 1 do
    for C := 0 to FCols - 1 do
      FCells[IndexOf(C, R)] := LBlank;

  for R := FScrollTop to FScrollBottom do
    MarkRowDirty(R);
end;

procedure TScreenBuffer.LineFeed;
begin
  FWrapPending := False;
  if FCursorRow = FScrollBottom then
    ScrollUp(1)
  else if FCursorRow < FRows - 1 then
  begin
    MarkRowDirty(FCursorRow);
    Inc(FCursorRow);
    MarkRowDirty(FCursorRow);
  end;
end;

procedure TScreenBuffer.ReverseLineFeed;
begin
  FWrapPending := False;
  if FCursorRow = FScrollTop then
    ScrollDown(1)
  else if FCursorRow > 0 then
  begin
    MarkRowDirty(FCursorRow);
    Dec(FCursorRow);
    MarkRowDirty(FCursorRow);
  end;
end;

procedure TScreenBuffer.EnterAltScreen;
begin
  if FAltActive then Exit;
  FMainCells := Copy(FCells, 0, Length(FCells));
  FSavedCursorCol := FCursorCol;
  FSavedCursorRow := FCursorRow;
  FAltActive := True;
  FillAll;                 // alt screen starts blank
  FCursorCol := 0;
  FCursorRow := 0;
  FWrapPending := False;
end;

procedure TScreenBuffer.ExitAltScreen;
begin
  if not FAltActive then Exit;
  FCells := Copy(FMainCells, 0, Length(FMainCells));
  SetLength(FMainCells, 0);
  FCursorCol := FSavedCursorCol;
  FCursorRow := FSavedCursorRow;
  FAltActive := False;
  FWrapPending := False;
  ClampCursor;
  MarkAllDirty;
end;

procedure TScreenBuffer.Resize(ACols, ARows: Integer);
var
  LNew: TArray<TTerminalCell>;
  LBlank: TTerminalCell;
  R, C, CopyCols, CopyRows: Integer;
begin
  if ACols < 1 then ACols := 1;
  if ARows < 1 then ARows := 1;

  SetLength(LNew, ACols * ARows);
  LBlank := BlankCell;
  for R := 0 to High(LNew) do
    LNew[R] := LBlank;

  // Preserve the overlapping top-left region.
  CopyCols := FCols; if ACols < CopyCols then CopyCols := ACols;
  CopyRows := FRows; if ARows < CopyRows then CopyRows := ARows;
  for R := 0 to CopyRows - 1 do
    for C := 0 to CopyCols - 1 do
      LNew[R * ACols + C] := FCells[IndexOf(C, R)];

  FCells := LNew;
  FCols := ACols;
  FRows := ARows;
  FScrollTop := 0;
  FScrollBottom := FRows - 1;
  SetLength(FDirty, FRows);
  FWrapPending := False;
  ClampCursor;
  MarkAllDirty;
end;

procedure TScreenBuffer.MarkRowDirty(ARow: Integer);
begin
  if (ARow >= 0) and (ARow < FRows) then
    FDirty[ARow] := True;
end;

procedure TScreenBuffer.MarkAllDirty;
var
  R: Integer;
begin
  for R := 0 to FRows - 1 do
    FDirty[R] := True;
end;

procedure TScreenBuffer.ResetDirty;
var
  R: Integer;
begin
  for R := 0 to FRows - 1 do
    FDirty[R] := False;
end;

function TScreenBuffer.IsRowDirty(ARow: Integer): Boolean;
begin
  Result := (ARow >= 0) and (ARow < FRows) and FDirty[ARow];
end;

function TScreenBuffer.ScrollbackCount: Integer;
begin
  Result := FScrollback.Count;
end;

function TScreenBuffer.GetScrollbackLine(AIndex: Integer): TArray<TTerminalCell>;
begin
  if (AIndex >= 0) and (AIndex < FScrollback.Count) then
    Result := FScrollback[AIndex]
  else
    Result := nil;
end;

function TScreenBuffer.GetCell(ACol, ARow: Integer): TTerminalCell;
begin
  if (ACol >= 0) and (ACol < FCols) and (ARow >= 0) and (ARow < FRows) then
    Result := FCells[IndexOf(ACol, ARow)]
  else
    Result := BlankCell;
end;

function TScreenBuffer.IsIdleAtPrompt(AForegroundChild: Boolean): Boolean;
begin
  // A full-screen app (alternate screen: vim/less/htop/TUI) is never a safe target.
  if FAltActive then
    Exit(False);
  // Prefer OSC 133 semantic markers when the shell emits them: safe only when at or
  // awaiting a prompt (A/B) or just after a command finished (D) -- never while a
  // command is executing (C).
  if FPromptState <> spsUnknown then
    Exit(FPromptState in [spsPromptStart, spsCommandInput, spsCommandFinished]);
  // Fallback for shells without shell-integration markers: a live child in the Job
  // Object (shell + something) means a foreground command is running.
  Result := not AForegroundChild;
end;

end.
