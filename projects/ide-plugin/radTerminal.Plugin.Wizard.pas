(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit radTerminal.Plugin.Wizard;

interface

uses
  ToolsAPI;

type
  TradTerminalWizard = class(TNotifierObject, IOTAWizard)
  public
    class procedure Register;
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

implementation

class procedure TradTerminalWizard.Register;
begin
  RegisterPackageWizard(TradTerminalWizard.Create);
end;

function TradTerminalWizard.GetIDString: string;
begin
  Result := 'radProgrammer.radTerminal';
end;

function TradTerminalWizard.GetName: string;
begin
  Result := 'radTerminal';
end;

function TradTerminalWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TradTerminalWizard.Execute;
begin
  // Menu click is handled by radTerminal.Plugin.Menu
end;

end.
