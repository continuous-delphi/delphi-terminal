unit radTerminal.Plugin.Wizard;

interface

uses
  ToolsAPI;

type
  TradTerminalWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  public
    class procedure Register;
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    { IOTAMenuWizard }
    function GetMenuText: string;
  end;

implementation

uses
  radTerminal.Plugin.DockForm;

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

function TradTerminalWizard.GetMenuText: string;
begin
  Result := 'radTerminal';
end;

procedure TradTerminalWizard.Execute;
begin
  TfrmradTerminalDock.ShowInstance;
end;

end.
