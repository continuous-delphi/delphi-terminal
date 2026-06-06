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
