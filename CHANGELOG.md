# Changelog for delphi-terminal
Home repo: https://github.com/continuous-delphi/delphi-terminal

---

## v0.8.18.0
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