(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Key -> VT input translation for the ConPTY backend (#70). Maps a virtual-key +
  shift state to the byte sequence a terminal sends to the shell. ConPTY converts
  these standard xterm/VT sequences back into console input records for the child.

  Printable characters are NOT handled here -- they arrive via the control's
  KeyPress (WM_CHAR) and are written through as-is. This function covers the
  non-printable and control keys: Enter, Backspace, Tab / Shift+Tab, Esc, the
  arrows, Home/End, Insert/Delete, PgUp/PgDn, and Ctrl+letter control codes.

  Kept free of the VCL (only Winapi.Windows for VK_* and System.Classes for
  TShiftState) so it is unit-testable without a control.

*)
unit Delphi.Terminal.KeyInput;

interface

uses
  Winapi.Windows,
  System.Classes;

///<summary>
///  Translates a key press to the VT byte sequence to send to the shell, or ''
///  when the key is a plain printable (left for KeyPress) or is unmapped.
///</summary>
function KeyToVT(AKey: Word; AShift: TShiftState): string;

implementation

const
  ESC = #27;

function KeyToVT(AKey: Word; AShift: TShiftState): string;
begin
  Result := '';

  // Ctrl+A..Ctrl+Z -> control codes #1..#26 (Ctrl+C=#3, Ctrl+D=#4, Ctrl+L=#12, ...).
  // AltGr (Ctrl+Alt) is excluded so it can still produce printable characters.
  if (ssCtrl in AShift) and not (ssAlt in AShift) and (AKey >= Ord('A')) and (AKey <= Ord('Z')) then
    Exit(Chr(AKey - Ord('A') + 1));

  case AKey of
    VK_RETURN: Result := #13;
    VK_BACK:   Result := #127;                                   // DEL, the terminal-standard Backspace
    VK_TAB:    if ssShift in AShift then Result := ESC + '[Z'    // CBT (back-tab)
               else Result := #9;
    VK_ESCAPE: Result := ESC;
    VK_UP:     Result := ESC + '[A';
    VK_DOWN:   Result := ESC + '[B';
    VK_RIGHT:  Result := ESC + '[C';
    VK_LEFT:   Result := ESC + '[D';
    VK_HOME:   Result := ESC + '[H';
    VK_END:    Result := ESC + '[F';
    VK_INSERT: Result := ESC + '[2~';
    VK_DELETE: Result := ESC + '[3~';
    VK_PRIOR:  Result := ESC + '[5~';                            // Page Up
    VK_NEXT:   Result := ESC + '[6~';                            // Page Down
  end;
end;

end.
