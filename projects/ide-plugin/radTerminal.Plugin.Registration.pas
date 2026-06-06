(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit radTerminal.Plugin.Registration;

interface

procedure Register;

implementation

uses
  radTerminal.Plugin.Wizard;

procedure Register;
begin
  TradTerminalWizard.Register;
end;

end.
