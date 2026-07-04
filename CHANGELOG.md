# Changelog for delphi-terminal
Home repo: https://github.com/continuous-delphi/delphi-terminal

---
## v1.3.99.0
- Interrupt / restart semantics: Stop (or Ctrl+C) interrupts the foreground app; a second Stop within a short window -- or Stop/Enter after the shell has exited -- restarts the session, clearing the output queue, parser, and screen. Teardown already stops all terminals before releasing settings on IDE close / package unload.
[#72](https://github.com/continuous-delphi/delphi-terminal/issues/72)

## v1.3.97.0
- ConPTY paste: Ctrl+V / Shift+Insert / context-menu Paste send the clipboard to the shell (newlines normalized to CR), wrapped in bracketed-paste markers (ESC[200~/ESC[201~) when the running app has enabled bracketed-paste mode.
[#71](https://github.com/continuous-delphi/delphi-terminal/issues/71)

## v1.3.96.0
- VT parser now implements the in-place line-editing CSIs -- ECH (erase chars), ICH (insert chars), DCH (delete chars), IL (insert lines), DL (delete lines) -- so editing a wrapped line (e.g. a pwsh prediction) no longer leaves stale glyphs on the continuation line, and full-screen TUIs redraw correctly. Also retained an opt-in raw ConPTY stream capture diagnostic (disabled by default).
[#79](https://github.com/continuous-delphi/delphi-terminal/issues/79)

## v1.3.95.0
- Fixed ConPTY display corruption when editing lines that reach the right margin (e.g. backspacing over a pwsh prediction): the screen model now uses deferred (pending) line wrap like a real terminal, and the pseudoconsole size reliably tracks the view's actual width so the shell wraps at the right column.
[#78](https://github.com/continuous-delphi/delphi-terminal/issues/78)

## v1.3.94.0
- ConPTY mode is now interactive: TTerminalView takes keyboard focus and keystrokes are translated to VT sequences and sent to the shell (printables, Enter, Backspace, Tab/Shift+Tab, Esc, arrows, Home/End, Insert/Delete, PgUp/PgDn, Ctrl+letter incl. Ctrl+C/L/D). The line-entry TEdit is hidden in ConPTY mode; command history remains legacy line-mode only.
[#70](https://github.com/continuous-delphi/delphi-terminal/issues/70)

## v1.3.93.0
- ConPTY mode now renders through TTerminalView (VT parser -> screen model -> view) instead of the RichEdit; the legacy pipe backend keeps using the RichEdit. Resizing the terminal (or its font metrics) reflows the shell via ResizePseudoConsole, and the view's Copy/Paste/Clear/Stop menu is wired to the live process.
[#69](https://github.com/continuous-delphi/delphi-terminal/issues/69)

## v1.3.92.0
- TTerminalView gained vertical scrollback (mouse wheel over history), mouse selection with clipboard copy, and a Copy / Paste / Clear / Stop context menu (Copy handled internally; Paste/Clear/Stop surfaced as events for the host). Selection maths / document addressing factored into a VCL-free unit.
[#68](https://github.com/continuous-delphi/delphi-terminal/issues/68)

## v1.3.91.0
- Added the terminal renderer (TTerminalView): a TCustomControl that paints a TScreenBuffer as a monospace cell grid with per-cell colours (16 / 256 / truecolor), bold/italic/underline/inverse, and a block cursor; incremental dirty-row repainting and double buffering. The VCL demo gains a canned-content 'TTerminalView' tab as an early visual smoke.
[#67](https://github.com/continuous-delphi/delphi-terminal/issues/67)

## v1.3.90.0
- Renderer build-vs-reuse spike: surveyed permissively-licensed Delphi VT controls (SCShell, andrewd207/TerminalEmulator, pasterm, doublecmd) and decided to build TTerminalView from scratch. See docs/conpty-renderer-decision.md
[#66](https://github.com/continuous-delphi/delphi-terminal/issues/66)

## v1.3.89.0
- VT parser now captures OSC window titles (BEL/ST terminated, reassembled across chunks, with an OnTitleChanged event) and handles DEC private modes: cursor show/hide (?25), alternate screen (?1049), and bracketed paste (?2004)
[#65](https://github.com/continuous-delphi/delphi-terminal/issues/65)

## v1.3.88.0
- VT parser now handles cursor movement (CUU/CUD/CUF/CUB, CUP/HVP, CHA/VPA), save/restore (DECSC/DECRC, SCP/RCP), erase (ED/EL), and scrolling (DECSTBM scroll region, SU/SD, IND/RI/NEL)
[#64](https://github.com/continuous-delphi/delphi-terminal/issues/64)

## v1.3.87.0
- Added the VT parser core (TVTParser): a stateful state machine driving TScreenBuffer with C0 controls and SGR (16 / 256 / 24-bit truecolor), handling escape sequences split across chunks and swallowing unknown/OSC sequences harmlessly
[#63](https://github.com/continuous-delphi/delphi-terminal/issues/63)

## v1.3.86.0
- Extended the screen model with scroll regions, alternate screen, scrollback, resize (content-preserving, cursor-clamping), and dirty-row tracking
[#62](https://github.com/continuous-delphi/delphi-terminal/issues/62)

## v1.3.85.0
- Added the terminal screen model (TScreenBuffer): a pure cell grid with per-cell colour/style, cursor, current attributes, write, and erase-in-line/display
[#61](https://github.com/continuous-delphi/delphi-terminal/issues/61)

## v1.3.83.0
- Added a terminal backend setting (Automatic / ConPTY / Legacy pipes) on the Tools > Options page, persisted to the registry; the dock form resolves it and applies it to each terminal tab
[#60](https://github.com/continuous-delphi/delphi-terminal/issues/60)

## v1.3.82.0
- Added pure backend-selection logic (ResolveTerminalBackend): honors forced Legacy/ConPTY, falls back to legacy when ConPTY is unavailable, and keeps Auto on legacy for now
[#59](https://github.com/continuous-delphi/delphi-terminal/issues/59)

## v1.3.81.0
- TframeCmdShell now drives the terminal through the ITerminalProcess abstraction and creates its backend on demand (BackendKind); the demo can force ConPTY via the DELPHI_TERMINAL_BACKEND env var. Legacy path unchanged.
[#58](https://github.com/continuous-delphi/delphi-terminal/issues/58)

## v1.3.80.0
- Added the ConPTY backend (TConPtyShell) implementing ITerminalProcess: owns the pseudoconsole session and reader, maps shells to a command line, handles input/interrupt/resize, and detects natural child exit via a process-handle watcher
[#57](https://github.com/continuous-delphi/delphi-terminal/issues/57)

## v1.3.79.0
- Introduced the ITerminalProcess backend abstraction; the legacy pipe process now implements it (WriteInput/SendInterrupt/Resize), so the frame can drive either backend
[#56](https://github.com/continuous-delphi/delphi-terminal/issues/56)

## v1.3.78.0
- ConPTY availability is gated to Windows 10 1903+ (build 18362), detected via RtlGetVersion so a missing app manifest cannot falsely disable it
[#55](https://github.com/continuous-delphi/delphi-terminal/issues/55)

## v1.3.77.0
- ConPTY sessions assign the child to a kill-on-close Job Object so the whole process tree (shell + descendants) is terminated on teardown
[#54](https://github.com/continuous-delphi/delphi-terminal/issues/54)

## v1.3.76.0
- ConPTY foundation wired into the plugin package and test project, with a TConPty/TConPtyReader round-trip smoke test; DUnitX suite unblocked and repaired
[#52](https://github.com/continuous-delphi/delphi-terminal/issues/52) [#53](https://github.com/continuous-delphi/delphi-terminal/issues/53)

## v1.3.65.0
- VCL demo app should not crash on startup when optional shells (pwsh, WSL) are not installed
[#49](https://github.com/continuous-delphi/delphi-terminal/issues/49)

## v1.3.63.0
- Added Windows Subsystem for Linux (WSL) terminal option
[#39](https://github.com/continuous-delphi/delphi-terminal/issues/39)

## v1.2.62.0
- Minor code review enhancements
- CMD terminal should use "COMSPEC" environment variable instead of hardcoding cmd.exe
[#47](https://github.com/continuous-delphi/delphi-terminal/issues/47)

- power shell terminals should start without the banner
[#46](https://github.com/continuous-delphi/delphi-terminal/issues/46)

## v1.2.61.0

- Support older versions by wrapping LIBSUFFIX 'AUTO' in $IFDEF for Ticket #44
Also support older versions by using .ToString instead of .ToJSON for XE6
for ticket #45

- Verified that the package was built and installed using `Delphi XE6`
(Supporting older versions would require at least changing Sytem.Json usage)

## v1.1.57.0

- Support older versions by only referencing `TJSONAncestor.Format` in 10.3 or later
[#43](https://github.com/continuous-delphi/delphi-terminal/issues/43)

## v1.1.55.0

- Support older versions by only referencing `ofnBeginProjectGroupOpen` and `ofnEndProjectGroupOpen`
in 10.4 or later.  Added DELPHI_COMPILER_VERSIONS.inc to project and added Source to search path
[#38](https://github.com/continuous-delphi/delphi-terminal/issues/38)

## v1.1.54.0

- Support older versions by defining `AttachConsole` as needed
[#37](https://github.com/continuous-delphi/delphi-terminal/issues/37)

## v1.1.46.0
- Add "Export..." button to Saved Commands editor for exporting commands as reusable JSON bundles
- Prefix is now optional for both export and import -- omit to export/import all commands
- Import skips exact duplicates instead of adding them again
[#40](https://github.com/continuous-delphi/delphi-terminal/issues/40)
- Display plugin version on the Tools > Options config screen, read from BPL VERSIONINFO resource
[#36](https://github.com/continuous-delphi/delphi-terminal/issues/36)
- Per-project saved commands via `.delphi-terminal.json` next to the `.dproj`, auto-prefixed with 
`project:<name>.`
[#33](https://github.com/continuous-delphi/delphi-terminal/issues/33)
- New `${BuildConfig}` and `${Platform}` variables for active build configuration and target platform; 
commands using them are hidden when no project is open
[#41](https://github.com/continuous-delphi/delphi-terminal/issues/41)
- Commands with file-variables (`${FileDir}`, `${FilePath}`, `${FileName}`) are hidden from the palette when 
no editor file is open
[#42](https://github.com/continuous-delphi/delphi-terminal/issues/42)

## v1.0.38.0
- Saved commands with Ctrl+P command palette, variable expansion, and JSON bundle import
- Plus matching `Commands` toolbar button as entry point for the palette
- <Enter> previews command in input field for editing, <Ctrl><Enter> runs immediately
- Command list is filtered by active shell tab (some commands are formatted differently on different shells)
- User responsible for quirky quoting behavior based on whatever command is associated
- Working Dir validation prevents file variables (${ProjectFile}, ${FilePath}, ${FileName})
- Variable reference legend on Add/Edit Command dialog
- <Ctrl><DoubleClick> on the command line auto-runs the command (like <Ctrl><Enter>)
[#17](https://github.com/continuous-delphi/delphi-terminal/issues/17)

## v0.9.33.0
- Fix dockable form not restoring on IDE restart by registering with the desktop layout manager
[#35](https://github.com/continuous-delphi/delphi-terminal/issues/35)

## v0.9.32.0
- Fix close-all when the delphi-terminal window is docked. It remained hidden
until IDE restart.

## v0.9.31.0
- Ctrl+Alt+N keyboard shortcut to toggle the terminal panel (show/focus/hide)
[#11](https://github.com/continuous-delphi/delphi-terminal/issues/11)

## v1.1.57.0
## v0.9.29.0
- Fix multi-byte UTF-8 characters splitting across pipe reads, causing replacement characters in non-ASCII 
output
//github.com/continuous-delphi/delphi-terminal/issues/24)
- Add Homepage hyperlink to Tools > Options page
- Minor cleanup (naming, update screenshots, single finalization)

## v0.9.24.0

- Some optimizations
PlainText now uses TStringBuilder, segments are accumulated in TList<TAnsiSegment> and converted once with 
ToArray, and CSI params are copied once instead of appended char-by-char.

## v0.8.23.0
- OSC sequences now keep buffering in FPartialSeq until the parser sees
either BEL or ESC \, so split PowerShell title sequences are stripped
correctly instead of garbled
[#29](https://github.com/continuous-delphi/delphi-terminal/issues/29)

## v0.8.22.0

- Prevent pwsh crash issues if not installed
[#25](https://github.com/continuous-delphi/delphi-terminal/issues/25)

## v0.8.21.0
- Ctrl+C support: interrupt running commands via Stop button or Ctrl+C in input
[#28](https://github.com/continuous-delphi/delphi-terminal/issues/28)

## v0.8.17.0
- Check WriteFile return value in SendCommand; close stdin handle on broken pipe
[#23](https://github.com/continuous-delphi/delphi-terminal/issues/23)

## v0.8.16.0
- Fix use-after-free risk in queued thread notifications during shutdown
[#22](https://github.com/continuous-delphi/delphi-terminal/issues/22)

## v0.8.14.0

- Support ANSI background colors

- Renamed from radTerminal to Delphi-Terminal
  and moved from RAD Programmer to Continuous-Delphi
[#21](https://github.com/continuous-delphi/delphi-terminal/issues/21)

## v0.7.9.0
- .RC version info added to BPL project
[#19](https://github.com/continuous-delphi/delphi-terminal/issues/19)

## v0.7.8.0
- Auto-cd on active project switch with configurable scope (active tab / all tabs)
[#14](https://github.com/continuous-delphi/delphi-terminal/issues/14)

- Tools > Options > Third Party > delphi-terminal configuration screen with registry persistence
[#15](https://github.com/continuous-delphi/delphi-terminal/issues/15)

## v0.6.8.0
- ANSI 256-color and 24-bit RGB color support for foreground and background
[#16](https://github.com/continuous-delphi/delphi-terminal/issues/16)

## v0.5.8.0
- Tab switching with Ctrl+Tab/Ctrl+Shift+Tab and Ctrl+1/2/3
[#12](https://github.com/continuous-delphi/delphi-terminal/issues/12)
- Clear terminal output with Ctrl+L and Clear toolbar button
[#13](https://github.com/continuous-delphi/delphi-terminal/issues/13)

## v0.4.8.0
- IDE plugin skeleton: dockable form with CMD/pwsh/PowerShell tabs, ToolsAPI path resolution
[#8](https://github.com/continuous-delphi/delphi-terminal/issues/8)
- Move menu item from Help Wizards to View menu via INTAServices.MainMenu
[#10](https://github.com/continuous-delphi/delphi-terminal/issues/10)

## v0.3.8.0
- ANSI escape code rendering: replace TMemo with TRichEdit, parse SGR sequences for colored terminal output
[#4](https://github.com/continuous-delphi/delphi-terminal/issues/4)

## v0.3.7.0
- Working directory shortcuts: toolbar with Project Dir / File Dir buttons and directory label
[#9](https://github.com/continuous-delphi/delphi-terminal/issues/9)

## v0.2.6.0
- Detect shell process exit gracefully; show restart prompt on Enter
[#7](https://github.com/continuous-delphi/delphi-terminal/issues/7)

## v0.2.5.0
- Command history with up/down arrow keys in the terminal input
[#6](https://github.com/continuous-delphi/delphi-terminal/issues/6)

## v0.2.4.0
- Suppress ANSI escape codes via NO_COLOR=1 in process environment block (workaround until #4)
[#5](https://github.com/continuous-delphi/delphi-terminal/issues/5)

## v0.1.2.0
- Demo VCL app with tabbed CMD shell: process pipe management, shared frame, and DUnitX tests
[#1](https://github.com/continuous-delphi/delphi-terminal/issues/1)
- Add pwsh (PowerShell 7+) and PowerShell (legacy) tabs with configurable shell executable and encoding
[#2](https://github.com/continuous-delphi/delphi-terminal/issues/2)
[#3](https://github.com/continuous-delphi/delphi-terminal/issues/3)