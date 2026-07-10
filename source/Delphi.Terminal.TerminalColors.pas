(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Terminal colour mapping: TCellColor (screen-model colour) -> TColor (VCL). Kept
  free of Vcl.Controls / Vcl.Graphics (only System.UITypes for TColor) so it is
  fully unit-testable without pulling the VCL control/window machinery into a
  console test host.

*)
unit Delphi.Terminal.TerminalColors;

interface

uses
  System.UITypes,
  Delphi.Terminal.ScreenBuffer;

///<summary>Builds a TColor ($00BBGGRR) from 8-bit red/green/blue components.</summary>
function MakeColor(AR, AG, AB: Byte): TColor;
///<summary>Maps a 256-colour palette index to a TColor (16 standard + 6x6x6 cube + grayscale ramp).</summary>
function XTermPaletteColor(AIndex: Byte): TColor;
///<summary>Resolves a cell colour to a concrete TColor, using ADefault for the terminal-default kind.</summary>
function CellColorToTColor(const AColor: TCellColor; ADefault: TColor): TColor;

implementation

const
  // Standard 16-colour palette (indices 0..15), as $00RRGGBB.
  CStd16: array[0..15] of Cardinal = (
    $000000, $800000, $008000, $808000, $000080, $800080, $008080, $C0C0C0,
    $808080, $FF0000, $00FF00, $FFFF00, $0000FF, $FF00FF, $00FFFF, $FFFFFF);

function MakeColor(AR, AG, AB: Byte): TColor;
begin
  Result := TColor(AR or (AG shl 8) or (AB shl 16));
end;

function HexToTColor(AValue: Cardinal): TColor; inline;
begin
  Result := MakeColor((AValue shr 16) and $FF, (AValue shr 8) and $FF, AValue and $FF);
end;

function XTermPaletteColor(AIndex: Byte): TColor;
var
  N, R6, G6, B6, Level: Integer;

  function CubeComponent(AC: Integer): Byte;
  begin
    if AC = 0 then Result := 0 else Result := 55 + AC * 40;
  end;

begin
  if AIndex < 16 then
    Result := HexToTColor(CStd16[AIndex])
  else if AIndex < 232 then
  begin
    // 6x6x6 colour cube: indices 16..231.
    N := AIndex - 16;
    R6 := N div 36;
    G6 := (N div 6) mod 6;
    B6 := N mod 6;
    Result := MakeColor(CubeComponent(R6), CubeComponent(G6), CubeComponent(B6));
  end
  else
  begin
    // Grayscale ramp: indices 232..255 -> 8, 18, ... 238.
    Level := 8 + (AIndex - 232) * 10;
    Result := MakeColor(Level, Level, Level);
  end;
end;

function CellColorToTColor(const AColor: TCellColor; ADefault: TColor): TColor;
begin
  case AColor.Kind of
    cckIndexed: Result := XTermPaletteColor(AColor.Index);
    cckRGB:     Result := HexToTColor(AColor.RGB);
  else
    Result := ADefault;   // cckDefault
  end;
end;

end.
