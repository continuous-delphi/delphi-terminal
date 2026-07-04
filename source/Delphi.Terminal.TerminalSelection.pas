(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Terminal selection model and document addressing. Kept free of the VCL so the
  selection maths and text extraction are unit-testable without a control.

  Coordinates are absolute "document lines": line 0..ScrollbackCount-1 index the
  scrollback history (oldest first), then the ScrollbackCount..+Rows-1 lines are
  the live screen rows. This lets a selection span history and the visible screen
  uniformly, and lets the view scroll by choosing which document line is at top.

*)
unit Delphi.Terminal.TerminalSelection;

interface

uses
  Delphi.Terminal.ScreenBuffer;

type
  ///<summary>An inclusive selection in absolute document-line coordinates.</summary>
  TTerminalSelection = record
    Active: Boolean;
    StartLine: Integer;
    StartCol: Integer;
    EndLine: Integer;
    EndCol: Integer;
  end;

///<summary>An inactive (empty) selection.</summary>
function EmptySelection: TTerminalSelection;
///<summary>Returns the selection with start &lt;= end in reading order.</summary>
function NormalizeSelection(const ASel: TTerminalSelection): TTerminalSelection;
///<summary>Whether the cell at (ALine, ACol) falls within the selection (inclusive of both ends).</summary>
function IsCellSelected(const ASel: TTerminalSelection; ALine, ACol: Integer): Boolean;

///<summary>Total number of addressable document lines (scrollback + screen).</summary>
function TotalLineCount(ABuffer: TScreenBuffer): Integer;
///<summary>Reads a cell by absolute document line: scrollback first, then the live screen. Blank when out of range.</summary>
function LineCell(ABuffer: TScreenBuffer; ALine, ACol: Integer): TTerminalCell;
///<summary>Extracts the selected text, one document line per row, with trailing spaces trimmed and CRLF between rows.</summary>
function SelectedText(ABuffer: TScreenBuffer; const ASel: TTerminalSelection): string;

implementation

function EmptySelection: TTerminalSelection;
begin
  Result.Active := False;
  Result.StartLine := 0;
  Result.StartCol := 0;
  Result.EndLine := 0;
  Result.EndCol := 0;
end;

function PointBeforeOrEqual(ALine1, ACol1, ALine2, ACol2: Integer): Boolean; inline;
begin
  Result := (ALine1 < ALine2) or ((ALine1 = ALine2) and (ACol1 <= ACol2));
end;

function NormalizeSelection(const ASel: TTerminalSelection): TTerminalSelection;
begin
  Result := ASel;
  if not PointBeforeOrEqual(ASel.StartLine, ASel.StartCol, ASel.EndLine, ASel.EndCol) then
  begin
    Result.StartLine := ASel.EndLine;
    Result.StartCol := ASel.EndCol;
    Result.EndLine := ASel.StartLine;
    Result.EndCol := ASel.StartCol;
  end;
end;

function IsCellSelected(const ASel: TTerminalSelection; ALine, ACol: Integer): Boolean;
var
  LNorm: TTerminalSelection;
begin
  if not ASel.Active then Exit(False);
  LNorm := NormalizeSelection(ASel);
  Result := PointBeforeOrEqual(LNorm.StartLine, LNorm.StartCol, ALine, ACol) and
            PointBeforeOrEqual(ALine, ACol, LNorm.EndLine, LNorm.EndCol);
end;

function TotalLineCount(ABuffer: TScreenBuffer): Integer;
begin
  Result := ABuffer.ScrollbackCount + ABuffer.Rows;
end;

function LineCell(ABuffer: TScreenBuffer; ALine, ACol: Integer): TTerminalCell;
var
  LSbCount: Integer;
  LLine: TArray<TTerminalCell>;
begin
  LSbCount := ABuffer.ScrollbackCount;
  if (ALine >= 0) and (ALine < LSbCount) then
  begin
    LLine := ABuffer.GetScrollbackLine(ALine);
    if (ACol >= 0) and (ACol < Length(LLine)) then
      Result := LLine[ACol]
    else
      Result := ABuffer.GetCell(-1, -1);   // out-of-range -> blank cell
  end
  else
    Result := ABuffer.GetCell(ACol, ALine - LSbCount);
end;

function TrimTrailingSpaces(const AText: string): string;
var
  L: Integer;
begin
  L := Length(AText);
  while (L > 0) and (AText[L] = ' ') do
    Dec(L);
  Result := Copy(AText, 1, L);
end;

function SelectedText(ABuffer: TScreenBuffer; const ASel: TTerminalSelection): string;
var
  LNorm: TTerminalSelection;
  LLine, LColStart, LColEnd, C: Integer;
  LRow: string;
begin
  Result := '';
  if not ASel.Active then Exit;
  LNorm := NormalizeSelection(ASel);

  for LLine := LNorm.StartLine to LNorm.EndLine do
  begin
    if LLine = LNorm.StartLine then LColStart := LNorm.StartCol else LColStart := 0;
    if LLine = LNorm.EndLine then LColEnd := LNorm.EndCol else LColEnd := ABuffer.Cols - 1;

    LRow := '';
    for C := LColStart to LColEnd do
      LRow := LRow + LineCell(ABuffer, LLine, C).Ch;
    LRow := TrimTrailingSpaces(LRow);

    Result := Result + LRow;
    if LLine < LNorm.EndLine then
      Result := Result + #13#10;
  end;
end;

end.
