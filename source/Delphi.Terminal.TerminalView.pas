(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  TTerminalView: a VCL control that paints a TScreenBuffer as a cursor-addressed
  monospace cell grid. The screen model (TScreenBuffer, #61/#62) and the VT parser
  (TVTParser, #63-#65) remain independent and drive the buffer; the view reflects
  it.

  #67: metrics, dirty-row painting, per-cell colour/style, block cursor.
  #68: vertical scrollback (mouse wheel over history), mouse selection with
  clipboard copy, and a Copy / Paste / Clear / Stop context menu. Copy is handled
  internally; Paste / Clear / Stop are surfaced as events for the host (the frame,
  #69) to wire to the live process.

  Rendering is incremental: UpdateView invalidates only the buffer's dirty rows
  when pinned to the bottom (a full repaint while scrolled), and double buffering
  removes flicker. Colour mapping and selection maths live in VCL-free units
  (TerminalColors / TerminalSelection) so they are unit-testable.

*)
unit Delphi.Terminal.TerminalView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.Types, System.Math,
  Vcl.Controls, Vcl.Graphics, Vcl.Menus, Vcl.Clipbrd,
  Delphi.Terminal.ScreenBuffer, Delphi.Terminal.TerminalColors, Delphi.Terminal.TerminalSelection;

type
  ///<summary>
  ///  A view control that paints a TScreenBuffer. The buffer is not owned; the
  ///  host mutates it (via the VT parser) and then calls UpdateView.
  ///</summary>
  TTerminalView = class(TCustomControl)
  private
    FBuffer: TScreenBuffer;
    FDefaultForeground: TColor;
    FDefaultBackground: TColor;
    FCellWidth: Integer;
    FCellHeight: Integer;
    FMetricsValid: Boolean;
    FScrollOffset: Integer;          // lines scrolled up into history; 0 = pinned to the bottom
    FLastScrollbackCount: Integer;
    FSelection: TTerminalSelection;
    FSelecting: Boolean;
    FPopup: TPopupMenu;
    FMenuCopy: TMenuItem;
    FOnPasteRequested: TNotifyEvent;
    FOnClearRequested: TNotifyEvent;
    FOnInterruptRequested: TNotifyEvent;
    procedure SetBuffer(AValue: TScreenBuffer);
    procedure SetDefaultForeground(AValue: TColor);
    procedure SetDefaultBackground(AValue: TColor);
    procedure RecalcMetrics;
    function VisibleTopLine: Integer;
    function MaxScrollOffset: Integer;
    procedure PointToDoc(AX, AY: Integer; out ALine, ACol: Integer);
    procedure PaintLine(AVisibleRow, AAbsLine: Integer);
    procedure PaintCursorAt(AVisibleRow, ACol: Integer);
    procedure ResolveCellColors(const ACell: TTerminalCell; out AFg, ABg: TColor);
    function CellRect(ACol, ARow: Integer): TRect;
    procedure BuildPopupMenu;
    procedure PopupOnPopup(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;

    ///<summary>The screen model to render. Not owned by the view.</summary>
    property Buffer: TScreenBuffer read FBuffer write SetBuffer;

    ///<summary>Invalidates the buffer's dirty rows (or the whole view while scrolled), then clears the dirty flags.</summary>
    procedure UpdateView;
    ///<summary>Forces a full repaint of the whole grid.</summary>
    procedure RefreshAll;

    ///<summary>Scrolls the history view by ALines (positive = back into history), clamped.</summary>
    procedure ScrollLines(ALines: Integer);
    ///<summary>Pins the view to the newest output.</summary>
    procedure ScrollToBottom;

    ///<summary>Whether a non-empty selection is active.</summary>
    function HasSelection: Boolean;
    ///<summary>The currently selected text (trailing spaces trimmed, CRLF between rows).</summary>
    function SelectionText: string;
    ///<summary>Copies the selection to the clipboard (no-op when empty).</summary>
    procedure CopyToClipboard;
    ///<summary>Clears the active selection.</summary>
    procedure ClearSelection;

    function CellWidth: Integer;
    function CellHeight: Integer;
    ///<summary>Columns that fit the current client width at the current font.</summary>
    function VisibleCols: Integer;
    ///<summary>Rows that fit the current client height at the current font.</summary>
    function VisibleRows: Integer;
  published
    property DefaultForeground: TColor read FDefaultForeground write SetDefaultForeground default clSilver;
    property DefaultBackground: TColor read FDefaultBackground write SetDefaultBackground default clBlack;
    ///<summary>Fired when the user chooses Paste; the host reads the clipboard and writes to the process.</summary>
    property OnPasteRequested: TNotifyEvent read FOnPasteRequested write FOnPasteRequested;
    ///<summary>Fired when the user chooses Clear; the host decides what to reset.</summary>
    property OnClearRequested: TNotifyEvent read FOnClearRequested write FOnClearRequested;
    ///<summary>Fired when the user chooses Stop; the host sends the interrupt to the process.</summary>
    property OnInterruptRequested: TNotifyEvent read FOnInterruptRequested write FOnInterruptRequested;
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
    property OnResize;
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
  TabStop := True;   // the view takes keyboard focus so keystrokes reach the shell (#70)
  FDefaultForeground := clSilver;
  FDefaultBackground := clBlack;
  FMetricsValid := False;
  FScrollOffset := 0;
  FLastScrollbackCount := 0;
  FSelection := EmptySelection;
  FSelecting := False;
  Font.Name := 'Consolas';
  Font.Size := 10;
  Font.Color := FDefaultForeground;
  Width := 320;
  Height := 200;
  BuildPopupMenu;
end;

procedure TTerminalView.BuildPopupMenu;

  function AddItem(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(FPopup);
    Result.Caption := ACaption;
    Result.OnClick := AOnClick;
    FPopup.Items.Add(Result);
  end;

  function AddSeparator: TMenuItem;
  begin
    Result := TMenuItem.Create(FPopup);
    Result.Caption := '-';
    FPopup.Items.Add(Result);
  end;

begin
  FPopup := TPopupMenu.Create(Self);
  FPopup.OnPopup := PopupOnPopup;
  FMenuCopy := AddItem('Copy', CopyClick);
  AddItem('Paste', PasteClick);
  AddSeparator;
  AddItem('Clear', ClearClick);
  AddItem('Stop', StopClick);
  PopupMenu := FPopup;
end;

procedure TTerminalView.PopupOnPopup(Sender: TObject);
begin
  FMenuCopy.Enabled := HasSelection;
end;

procedure TTerminalView.CopyClick(Sender: TObject);
begin
  CopyToClipboard;
end;

procedure TTerminalView.PasteClick(Sender: TObject);
begin
  if Assigned(FOnPasteRequested) then
    FOnPasteRequested(Self);
end;

procedure TTerminalView.ClearClick(Sender: TObject);
begin
  if Assigned(FOnClearRequested) then
    FOnClearRequested(Self);
end;

procedure TTerminalView.StopClick(Sender: TObject);
begin
  if Assigned(FOnInterruptRequested) then
    FOnInterruptRequested(Self);
end;

procedure TTerminalView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  FMetricsValid := False;
  RefreshAll;
end;

procedure TTerminalView.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  // Deliver every key (arrows, Tab, Return, Esc, chars) to this control rather than
  // letting the dialog manager consume them, so they can be forwarded to the shell.
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_WANTTAB or DLGC_WANTALLKEYS;
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
  FScrollOffset := 0;
  FSelection := EmptySelection;
  if FBuffer <> nil then
    FLastScrollbackCount := FBuffer.ScrollbackCount
  else
    FLastScrollbackCount := 0;
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

function TTerminalView.MaxScrollOffset: Integer;
begin
  if FBuffer <> nil then
    Result := FBuffer.ScrollbackCount
  else
    Result := 0;
end;

function TTerminalView.VisibleTopLine: Integer;
begin
  // Row 0 of the view maps to this absolute document line.
  if FBuffer <> nil then
    Result := FBuffer.ScrollbackCount - FScrollOffset
  else
    Result := 0;
end;

procedure TTerminalView.ScrollLines(ALines: Integer);
var
  LNew: Integer;
begin
  LNew := EnsureRange(FScrollOffset + ALines, 0, MaxScrollOffset);
  if LNew <> FScrollOffset then
  begin
    FScrollOffset := LNew;
    Invalidate;
  end;
end;

procedure TTerminalView.ScrollToBottom;
begin
  if FScrollOffset <> 0 then
  begin
    FScrollOffset := 0;
    Invalidate;
  end;
end;

function TTerminalView.HasSelection: Boolean;
begin
  Result := FSelection.Active;
end;

function TTerminalView.SelectionText: string;
begin
  if (FBuffer <> nil) and FSelection.Active then
    Result := SelectedText(FBuffer, FSelection)
  else
    Result := '';
end;

procedure TTerminalView.CopyToClipboard;
var
  LText: string;
begin
  LText := SelectionText;
  if LText <> '' then
    Clipboard.AsText := LText;
end;

procedure TTerminalView.ClearSelection;
begin
  if FSelection.Active then
  begin
    FSelection := EmptySelection;
    Invalidate;
  end;
end;

function TTerminalView.CellRect(ACol, ARow: Integer): TRect;
begin
  Result := Rect(ACol * FCellWidth, ARow * FCellHeight, (ACol + 1) * FCellWidth, (ARow + 1) * FCellHeight);
end;

procedure TTerminalView.PointToDoc(AX, AY: Integer; out ALine, ACol: Integer);
var
  LRow: Integer;
begin
  if not FMetricsValid then RecalcMetrics;
  LRow := AY div FCellHeight;
  ACol := AX div FCellWidth;
  if LRow < 0 then LRow := 0;
  if (FBuffer <> nil) and (ACol > FBuffer.Cols - 1) then ACol := FBuffer.Cols - 1;
  if ACol < 0 then ACol := 0;
  ALine := VisibleTopLine + LRow;
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

procedure TTerminalView.PaintLine(AVisibleRow, AAbsLine: Integer);
var
  LRowTop, LCol, LRunEnd, C: Integer;
  LFirst: TTerminalCell;
  LSelected: Boolean;
  LFg, LBg, LTmp: TColor;
  LText: string;
  LRect: TRect;
begin
  LRowTop := AVisibleRow * FCellHeight;
  LCol := 0;
  while LCol < FBuffer.Cols do
  begin
    // Extend a run of cells sharing colours, style, and selection state; paint it in one pass.
    LFirst := LineCell(FBuffer, AAbsLine, LCol);
    LSelected := IsCellSelected(FSelection, AAbsLine, LCol);
    LRunEnd := LCol + 1;
    while (LRunEnd < FBuffer.Cols)
      and SameAttributes(LineCell(FBuffer, AAbsLine, LRunEnd), LFirst)
      and (IsCellSelected(FSelection, AAbsLine, LRunEnd) = LSelected) do
      Inc(LRunEnd);

    LText := '';
    for C := LCol to LRunEnd - 1 do
      LText := LText + LineCell(FBuffer, AAbsLine, C).Ch;

    ResolveCellColors(LFirst, LFg, LBg);
    if LSelected then
    begin
      LTmp := LFg;
      LFg := LBg;
      LBg := LTmp;
    end;

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

  // Draw the cursor only on the live screen's cursor line (never over scrollback).
  if FBuffer.CursorVisible and (AAbsLine = FBuffer.ScrollbackCount + FBuffer.CursorRow) then
    PaintCursorAt(AVisibleRow, FBuffer.CursorCol);
end;

procedure TTerminalView.PaintCursorAt(AVisibleRow, ACol: Integer);
var
  LCol: Integer;
  LCell: TTerminalCell;
  LFg, LBg: TColor;
  LRect: TRect;
begin
  LCol := ACol;
  if LCol >= FBuffer.Cols then LCol := FBuffer.Cols - 1;
  if LCol < 0 then LCol := 0;

  LCell := FBuffer.GetCell(LCol, FBuffer.CursorRow);
  ResolveCellColors(LCell, LFg, LBg);
  LRect := CellRect(LCol, AVisibleRow);

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
  LTopLine, LRow, LRowTop: Integer;
begin
  if not FMetricsValid then RecalcMetrics;

  // Paint the default background across the invalid region first; this also covers
  // any area to the right of / below the grid.
  LClip := Canvas.ClipRect;
  Canvas.Brush.Color := FDefaultBackground;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(LClip);

  if FBuffer = nil then Exit;

  LTopLine := VisibleTopLine;
  for LRow := 0 to FBuffer.Rows - 1 do
  begin
    LRowTop := LRow * FCellHeight;
    if (LRowTop >= LClip.Bottom) or (LRowTop + FCellHeight <= LClip.Top) then
      Continue;   // row outside the invalid region
    PaintLine(LRow, LTopLine + LRow);
  end;
end;

procedure TTerminalView.UpdateView;
var
  LRow, LDelta, LNewSb: Integer;
  LRect: TRect;
begin
  if (FBuffer = nil) or not HandleAllocated then Exit;
  if not FMetricsValid then RecalcMetrics;

  LNewSb := FBuffer.ScrollbackCount;
  LDelta := LNewSb - FLastScrollbackCount;
  if LDelta > 0 then
  begin
    // New history arrived: hold the on-screen position if scrolled up; output invalidates
    // the absolute-coordinate selection.
    if FScrollOffset > 0 then
      FScrollOffset := EnsureRange(FScrollOffset + LDelta, 0, LNewSb);
    FSelection := EmptySelection;
  end;
  FLastScrollbackCount := LNewSb;

  if FScrollOffset = 0 then
  begin
    // Pinned to the bottom: visible row == screen row, so dirty rows map directly.
    for LRow := 0 to FBuffer.Rows - 1 do
      if FBuffer.IsRowDirty(LRow) then
      begin
        LRect := Rect(0, LRow * FCellHeight, ClientWidth, (LRow + 1) * FCellHeight);
        InvalidateRect(Handle, @LRect, False);
      end;
  end
  else
    Invalidate;   // scrolled: on-screen rows are shifted, repaint everything

  FBuffer.ResetDirty;
end;

procedure TTerminalView.RefreshAll;
begin
  if HandleAllocated then
    Invalidate;
end;

procedure TTerminalView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LLine, LCol: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus and not Focused then
    SetFocus;
  if Button = mbLeft then
  begin
    PointToDoc(X, Y, LLine, LCol);
    FSelection.Active := True;
    FSelection.StartLine := LLine;
    FSelection.StartCol := LCol;
    FSelection.EndLine := LLine;
    FSelection.EndCol := LCol;
    FSelecting := True;
    Invalidate;
  end;
end;

procedure TTerminalView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  LLine, LCol: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FSelecting then
  begin
    PointToDoc(X, Y, LLine, LCol);
    FSelection.EndLine := LLine;
    FSelection.EndCol := LCol;
    Invalidate;
  end;
end;

procedure TTerminalView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button = mbLeft) and FSelecting then
  begin
    FSelecting := False;
    // A click with no drag clears the selection.
    if (FSelection.StartLine = FSelection.EndLine) and (FSelection.StartCol = FSelection.EndCol) then
      FSelection.Active := False;
    Invalidate;
  end;
end;

function TTerminalView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  // One notch (120) scrolls three lines; positive delta (wheel up) goes back into history.
  ScrollLines((WheelDelta div WHEEL_DELTA) * 3);
  Result := True;
end;

end.
