# Changelog for delphi-terminal
Home repo: https://github.com/continuous-delphi/delphi-terminal

---

## v0.9.38.0
- Saved commands with Ctrl+P command palette, variable expansion, and JSON bundle import
- Commands toolbar button as discoverable entry point for the palette
- Enter previews command in input field for editing, Ctrl+Enter runs immediately
- Palette filters commands by active shell tab
- Working Dir validation prevents file variables (${ProjectFile}, ${FilePath}, ${FileName})
- Variable reference legend on Add/Edit Command dialog
- Ctrl-Double Click on the commands lie auto-runs the command (like CTRL+ENTER)
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

## v0.9.29.0
- Fix multi-byte UTF-8 characters splitting across pipe reads, causing replacement characters in non-ASCII output
[#24](https://github.com/continuous-delphi/delphi-terminal/issues/24)
- Add Homepage hyperlink to Tools > Options page
- Minor cleanup (naming, update screenshots, single finalization)

## v0.9.24.0

- Some optimizations
PlainText now uses TStringBuilder, segments are accumulated in TList<TAnsiSegment> and converted once with ToArray, and CSI params are copied once instead of appended char-by-char.

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