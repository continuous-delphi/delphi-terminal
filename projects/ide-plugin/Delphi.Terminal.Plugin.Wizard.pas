(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.Wizard;

interface

uses
  ToolsAPI;

type
  TDelphiTerminalWizard = class(TNotifierObject, IOTAWizard)
  public
    class procedure Register;
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

implementation

class procedure TDelphiTerminalWizard.Register;
begin
  RegisterPackageWizard(TDelphiTerminalWizard.Create);
end;

function TDelphiTerminalWizard.GetIDString: string;
begin
  Result := 'continuousdelphi.DelphiTerminal';
end;

function TDelphiTerminalWizard.GetName: string;
begin
  Result := 'DelphiTerminal';
end;

function TDelphiTerminalWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDelphiTerminalWizard.Execute;
begin
  // Menu click is handled by Delphi.Terminal.Plugin.Menu
end;

end.
