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
  ToolsAPI,
  radTerminal.Plugin.Wizard,
  radTerminal.Plugin.OptionsPage,
  radTerminal.Settings;

procedure Register;
var
  RegKey: string;
begin
  RegKey := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey;
  TerminalSettings.LoadFromRegistry(RegKey);
  TradTerminalWizard.Register;
  TradTerminalOptionsPage.RegisterOptions;
end;

end.
