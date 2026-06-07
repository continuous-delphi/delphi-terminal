(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.Registration;

interface

procedure Register;

implementation

uses
  ToolsAPI,
  Delphi.Terminal.Plugin.Wizard,
  Delphi.Terminal.Plugin.OptionsPage,
  Delphi.Terminal.Settings;

procedure Register;
var
  RegKey: string;
begin
  RegKey := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey;
  TerminalSettings.LoadFromRegistry(RegKey);
  TDelphiTerminalWizard.Register;
  TDelphiTerminalOptionsPage.RegisterOptions;
end;

end.
