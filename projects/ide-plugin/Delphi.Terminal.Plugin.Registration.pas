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
  System.SysUtils,
  Delphi.Terminal.Plugin.Lifecycle,
  Delphi.Terminal.Plugin.Wizard,
  Delphi.Terminal.Plugin.OptionsPage,
  Delphi.Terminal.Settings;

procedure Register;
var
  RegKey: string;
  Services: IOTAServices;
begin
  if Supports(BorlandIDEServices, IOTAServices, Services) then
  begin
    RegKey := Services.GetBaseRegistryKey;
    TerminalSettings.LoadFromRegistry(RegKey);
  end
  else
  begin
    TerminalSettings.SetDefaults;
  end;
  TDelphiTerminalWizard.Register;
  TDelphiTerminalOptionsPage.RegisterOptions;
end;

end.
