(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Data-driven definition of the ConPTY performance-profiling command set (#81,
  prep for #77). Both the interactive dropdown and the PROFILE_COMMANDS batch
  runner in the demo iterate this single const array. Edit here to add/adjust
  commands; keep UniqueID stable so results stay comparable across versions.

*)
unit Profile.Commands;

interface

uses
  Delphi.Terminal.CmdShell;

type
  TProfiledCommand = record
    UniqueID: string;          // stable key for cross-version diffing
    Description: string;       // dropdown label
    Shell: TCmdShellType;      // which shell/tab to run on
    Command: string;           // sent as-is; the harness appends Enter (+ 'exit' when EndAfterSeconds = 0)
    EndAfterSeconds: Integer;  // 0 = run to process exit (bounded); > 0 = timed window then terminate
    CaptureMemory: Boolean;    // sample process working set during the run
    Cols: Integer;             // fixed terminal size for reproducibility
    Rows: Integer;
    Repeats: Integer;          // number of times to run (report each; median offline)
  end;

const
  CProfiledCommands: array[0..5] of TProfiledCommand = (
    (UniqueID: 'pwsh.lines.50k';
     Description: 'pwsh: 50k lines (throughput)';
     Shell: TCmdShellType.pwsh;
     Command: '1..50000 | %{ "line $_ ......................................" }';
     EndAfterSeconds: 0; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3),

    (UniqueID: 'pwsh.hugeline';
     Description: 'pwsh: one 100k-char line (wrap)';
     Shell: TCmdShellType.pwsh;
     Command: '[string]::new(''='',100000)';
     EndAfterSeconds: 0; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3),

    (UniqueID: 'cmd.echo.50k';
     Description: 'cmd: 50k echo loop (throughput)';
     Shell: TCmdShellType.CMD;
     Command: 'for /L %i in (1,1,50000) do @echo line %i';
     EndAfterSeconds: 0; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3),

    (UniqueID: 'wsl.seq.1m';
     Description: 'WSL: seq 1..1,000,000 (throughput)';
     Shell: TCmdShellType.wsl;
     Command: 'seq 1 1000000';
     EndAfterSeconds: 0; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3),

    (UniqueID: 'wsl.top.2s';
     Description: 'WSL: top (2s full-screen redraw)';
     Shell: TCmdShellType.wsl;
     Command: 'top';
     EndAfterSeconds: 2; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3),

    (UniqueID: 'pwsh.crredraw.2s';
     Description: 'pwsh: CR redraw (2s rapid updates)';
     Shell: TCmdShellType.pwsh;
     Command: '1..100000000 | %{ Write-Host -NoNewline ("`r" + $_) }';
     EndAfterSeconds: 2; CaptureMemory: True; Cols: 120; Rows: 30; Repeats: 3)
  );

implementation

end.
