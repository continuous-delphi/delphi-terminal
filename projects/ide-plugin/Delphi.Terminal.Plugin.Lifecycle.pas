(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.Lifecycle;

interface

procedure ShutdownDelphiTerminalPlugin;

implementation

uses
  DeskUtil,
  Delphi.Terminal.Plugin.OptionsPage,
  Delphi.Terminal.Plugin.KeyBinding,
  Delphi.Terminal.Plugin.Menu,
  Delphi.Terminal.Plugin.DockForm,
  Delphi.Terminal.Settings;

var
  GShutdownDone: Boolean = False;

procedure ShutdownDelphiTerminalPlugin;
begin
  if GShutdownDone then
    Exit;
  GShutdownDone := True;

  UnregisterKeyBinding;
  TDelphiTerminalOptionsPage.UnregisterOptions;
  CleanUpTerminalMenu;
  if Assigned(UnregisterFieldAddress) then
    UnregisterFieldAddress(TfrmDelphiTerminalDock.InstanceAddress);
  TfrmDelphiTerminalDock.CleanUp;
  ReleaseTerminalSettings;
end;

initialization

finalization
  //centralized shut-down
  ShutdownDelphiTerminalPlugin;

end.
