(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  TTerminalView: a VCL control that paints a TScreenBuffer as a cursor-addressed
  monospace cell grid. This is the M8 renderer (#67): it owns nothing but the
  drawing -- the screen model (TScreenBuffer, #61/#62) and the VT parser
  (TVTParser, #63-#65) remain independent and drive the buffer; the view just
  reflects it.

  Rendering is incremental: UpdateView invalidates only the buffer's dirty rows
  (TScreenBuffer.IsRowDirty), so heavy output repaints a few rows rather than the
  whole screen. Paint honours the invalid clip region and repaints only the rows
  it intersects. Double buffering removes flicker.

  Colour mapping (TCellColor -> TColor) is factored into pure functions
  (XTermPaletteColor / CellColorToTColor) so it is fully unit-testable without a
  device context.

*)
unit Delphi.Terminal.TerminalView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.Types, Vcl.Controls, Vcl.Graphics,
  Delphi.Terminal.ScreenBuffer, Delphi.Terminal.TerminalColors;

type
  ///<summary>
  ///  A read-only view control that paints a TScreenBuffer. The buffer is not
  ///  owned; the host mutates it (via the VT parser) and then calls UpdateView.
  ///</summary>
  TTerminalView = class(TCustomControl)
  private
    FBuffer: TScreenBuffer;
    FDefaultForeground: TColor;
    FDefaultBackground: TColor;
    FCellWidth: Integer;
    FCellHeight: Integer;
    FMetricsValid: Boolean;
    procedure SetBuffer(AValue: TScreenBuffer);
    procedure SetDefaultForeground(AValue: TColor);
    procedure SetDefaultBackground(AValue: TColor);
    procedure RecalcMetrics;
    procedure PaintRow(ARow: Integer);
    procedure PaintCursor(ARow: Integer);
    procedure ResolveCellColors(const ACell: TTerminalCell; out AFg, ABg: TColor);
    function CellRect(ACol, ARow: Integer): TRect;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;

    ///<summary>The screen model to render. Not owned by the view.</summary>
    property Buffer: TScreenBuffer read FBuffer write SetBuffer;

    ///<summary>Invalidates only the rows the buffer marked dirty, then clears the dirty flags.</summary>
    procedure UpdateView;
    ///<summary>Forces a full repaint of the whole grid (e.g. after a resize or theme change).</summary>
    procedure RefreshAll;

    function CellWidth: Integer;
    function CellHeight: Integer;
    ///<summary>Columns that fit the current client width at the current font.</summary>
    function VisibleCols: Integer;
    ///<summary>Rows that fit the current client height at the current font.</summary>
    function VisibleRows: Integer;
  published
    property DefaultForeground: TColor read FDefaultForeground write SetDefaultForeground default clSilver;
    property DefaultBackground: TColor read FDefaultBackground write SetDefaultBackground default clBlack;
    property Align;
    property Anchors;
    property Font;
    property ParentFont;
    property PopupMenu;
    property Visible;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

function SameCellColor(const A, B: TCellColor): Boolean; inline;
begin
  Result := (A.Kind = B.Kind) and (A.Index = B.Index) and (A.RGB = B.RGB);
end;

function SameAttributes(const A, B: TTerminalCell): Boolean; inline;
begin
  Result := (A.Style = B.Style) and SameCellColor(A.Foreground, B.Foreground) and SameCellColor(A.Background, B.Background);
end;

function CellStyleToFontStyles(const AStyle: TCellStyle): TFontStyles;
begin
  Result := [];
  if csfBold in AStyle then Include(Result, fsBold);
  if csfItalic in AStyle then Include(Result, fsItalic);
  if csfUnderline in AStyle then Include(Result, fsUnderline);
end;

{ TTerminalView }

constructor TTerminalView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FDefaultForeground := clSilver;
  FDefaultBackground := clBlack;
  FMetricsValid := False;
  Font.Name := 'Consolas';
  Font.Size := 10;
  Font.Color := FDefaultForeground;
  Width := 320;
  Height := 200;
end;

procedure TTerminalView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  FMetricsValid := False;
  RefreshAll;
end;

procedure TTerminalView.RecalcMetrics;
var
  LBmp: TBitmap;
  LMetric: TTextMetric;
begin
  // Use a scratch bitmap so metrics are available even before the window handle exists.
  LBmp := TBitmap.Create;
  try
    LBmp.Canvas.Font.Assign(Font);
    GetTextMetrics(LBmp.Canvas.Handle, LMetric);
    FCellHeight := LMetric.tmHeight + LMetric.tmExternalLeading;
    FCellWidth := LMetric.tmAveCharWidth;
    if FCellWidth <= 0 then FCellWidth := LBmp.Canvas.TextWidth('W');
    if FCellHeight <= 0 then FCellHeight := LBmp.Canvas.TextHeight('Wg');
  finally
    LBmp.Free;
  end;
  if FCellWidth < 1 then FCellWidth := 1;
  if FCellHeight < 1 then FCellHeight := 1;
  FMetricsValid := True;
end;

procedure TTerminalView.SetBuffer(AValue: TScreenBuffer);
begin
  if FBuffer = AValue then Exit;
  FBuffer := AValue;
  RefreshAll;
end;

procedure TTerminalView.SetDefaultForeground(AValue: TColor);
begin
  if FDefaultForeground = AValue then Exit;
  FDefaultForeground := AValue;
  RefreshAll;
end;

procedure TTerminalView.SetDefaultBackground(AValue: TColor);
begin
  if FDefaultBackground = AValue then Exit;
  FDefaultBackground := AValue;
  RefreshAll;
end;

function TTerminalView.CellWidth: Integer;
begin
  if not FMetricsValid then RecalcMetrics;
  Result := FCellWidth;
end;

function TTerminalView.CellHeight: Integer;
begin
  if not FMetricsValid then RecalcMetrics;
  Result := FCellHeight;
end;

function TTerminalView.VisibleCols: Integer;
begin
  Result := ClientWidth div CellWidth;
  if Result < 1 then Result := 1;
end;

function TTerminalView.VisibleRows: Integer;
begin
  Result := ClientHeight div CellHeight;
  if Result < 1 then Result := 1;
end;

function TTerminalView.CellRect(ACol, ARow: Integer): TRect;
begin
  Result := Rect(ACol * FCellWidth, ARow * FCellHeight, (ACol + 1) * FCellWidth, (ARow + 1) * FCellHeight);
end;

procedure TTerminalView.ResolveCellColors(const ACell: TTerminalCell; out AFg, ABg: TColor);
var
  LTmp: TColor;
begin
  AFg := CellColorToTColor(ACell.Foreground, FDefaultForeground);
  ABg := CellColorToTColor(ACell.Background, FDefaultBackground);
  if csfInverse in ACell.Style then
  begin
    LTmp := AFg;
    AFg := ABg;
    ABg := LTmp;
  end;
end;

procedure TTerminalView.PaintRow(ARow: Integer);
var
  LRowTop, LCol, LRunEnd, C: Integer;
  LFirst: TTerminalCell;
  LFg, LBg: TColor;
  LText: string;
  LRect: TRect;
begin
  LRowTop := ARow * FCellHeight;
  LCol := 0;
  while LCol < FBuffer.Cols do
  begin
    // Extend a run of cells sharing the same colours and style; paint it in one pass.
    LFirst := FBuffer.GetCell(LCol, ARow);
    LRunEnd := LCol + 1;
    while (LRunEnd < FBuffer.Cols) and SameAttributes(FBuffer.GetCell(LRunEnd, ARow), LFirst) do
      Inc(LRunEnd);

    LText := '';
    for C := LCol to LRunEnd - 1 do
      LText := LText + FBuffer.GetCell(C, ARow).Ch;

    ResolveCellColors(LFirst, LFg, LBg);
    LRect := Rect(LCol * FCellWidth, LRowTop, LRunEnd * FCellWidth, LRowTop + FCellHeight);

    Canvas.Brush.Color := LBg;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(LRect);

    Canvas.Font.Assign(Font);
    Canvas.Font.Color := LFg;
    Canvas.Font.Style := CellStyleToFontStyles(LFirst.Style);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(LRect.Left, LRect.Top, LText);

    LCol := LRunEnd;
  end;

  if FBuffer.CursorVisible and (ARow = FBuffer.CursorRow) then
    PaintCursor(ARow);
end;

procedure TTerminalView.PaintCursor(ARow: Integer);
var
  LCol: Integer;
  LCell: TTerminalCell;
  LFg, LBg: TColor;
  LRect: TRect;
begin
  LCol := FBuffer.CursorCol;
  if LCol >= FBuffer.Cols then LCol := FBuffer.Cols - 1;
  if LCol < 0 then LCol := 0;

  LCell := FBuffer.GetCell(LCol, ARow);
  ResolveCellColors(LCell, LFg, LBg);
  LRect := CellRect(LCol, ARow);

  // Block cursor: fill with the (resolved) foreground and draw the glyph inverted.
  Canvas.Brush.Color := LFg;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(LRect);

  Canvas.Font.Assign(Font);
  Canvas.Font.Color := LBg;
  Canvas.Font.Style := CellStyleToFontStyles(LCell.Style);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(LRect.Left, LRect.Top, LCell.Ch);
end;

procedure TTerminalView.Paint;
var
  LClip: TRect;
  LStartRow, LEndRow, LRow: Integer;
begin
  if not FMetricsValid then RecalcMetrics;

  // Paint the default background across the invalid region first; this also covers
  // any area to the right of / below the grid.
  LClip := Canvas.ClipRect;
  Canvas.Brush.Color := FDefaultBackground;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(LClip);

  if FBuffer = nil then Exit;

  LStartRow := LClip.Top div FCellHeight;
  LEndRow := (LClip.Bottom - 1) div FCellHeight;
  if LStartRow < 0 then LStartRow := 0;
  if LEndRow > FBuffer.Rows - 1 then LEndRow := FBuffer.Rows - 1;

  for LRow := LStartRow to LEndRow do
    PaintRow(LRow);
end;

procedure TTerminalView.UpdateView;
var
  LRow: Integer;
  LRect: TRect;
begin
  if (FBuffer = nil) or not HandleAllocated then Exit;
  if not FMetricsValid then RecalcMetrics;

  for LRow := 0 to FBuffer.Rows - 1 do
    if FBuffer.IsRowDirty(LRow) then
    begin
      LRect := Rect(0, LRow * FCellHeight, ClientWidth, (LRow + 1) * FCellHeight);
      InvalidateRect(Handle, @LRect, False);
    end;

  FBuffer.ResetDirty;
end;

procedure TTerminalView.RefreshAll;
begin
  if HandleAllocated then
    Invalidate;
end;

end.
