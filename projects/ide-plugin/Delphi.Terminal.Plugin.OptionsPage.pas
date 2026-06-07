(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.OptionsPage;

interface

uses
  Vcl.Forms, ToolsAPI;

type
  TDelphiTerminalOptionsPage = class(TInterfacedObject, INTAAddInOptions)
  private
    FFrame: TCustomFrame;
  public
    function GetArea: string;
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    procedure DialogClosed(Accepted: Boolean);
    function ValidateContents: Boolean;
    function GetHelpContext: Integer;
    function IncludeInIDEInsight: Boolean;
    class procedure RegisterOptions;
    class procedure UnregisterOptions;
  end;

implementation

uses
  System.SysUtils,
  Delphi.Terminal.Plugin.OptionsFrame,
  Delphi.Terminal.Settings;

var
  GOptionsPage: INTAAddInOptions = nil;

{ TDelphiTerminalOptionsPage }

function TDelphiTerminalOptionsPage.GetArea: string;
begin
  Result := '';  // Third Party section
end;

function TDelphiTerminalOptionsPage.GetCaption: string;
begin
  Result := 'delphi-terminal';
end;

function TDelphiTerminalOptionsPage.GetFrameClass: TCustomFrameClass;
begin
  Result := TframeDelphiTerminalOptions;
end;

procedure TDelphiTerminalOptionsPage.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := AFrame;
  if FFrame is TframeDelphiTerminalOptions then
    TframeDelphiTerminalOptions(FFrame).LoadSettings;
end;

procedure TDelphiTerminalOptionsPage.DialogClosed(Accepted: Boolean);
var
  RegKey: string;
  Services: IOTAServices;
begin
  if Accepted and (FFrame is TframeDelphiTerminalOptions) then
  begin
    TframeDelphiTerminalOptions(FFrame).SaveSettings;

    if Supports(BorlandIDEServices, IOTAServices, Services) then
    begin
      RegKey := Services.GetBaseRegistryKey;
      TerminalSettings.SaveToRegistry(RegKey);
    end
    else
    begin
      //toconsider: Likely odd state already, showmessage?
    end;
  end;
  FFrame := nil;
end;

function TDelphiTerminalOptionsPage.ValidateContents: Boolean;
begin
  Result := True;
  //toconsider: ensure options make sense, don't rely on inferred behavior
end;

function TDelphiTerminalOptionsPage.GetHelpContext: Integer;
begin
  Result := 0;
end;

function TDelphiTerminalOptionsPage.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

class procedure TDelphiTerminalOptionsPage.RegisterOptions;
var
  Svc: INTAEnvironmentOptionsServices;
begin
  if not Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, Svc) then
    Exit;
  GOptionsPage := TDelphiTerminalOptionsPage.Create;
  Svc.RegisterAddInOptions(GOptionsPage);
end;

class procedure TDelphiTerminalOptionsPage.UnregisterOptions;
var
  Svc: INTAEnvironmentOptionsServices;
begin
  if GOptionsPage = nil then
    Exit;
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, Svc) then
    Svc.UnregisterAddInOptions(GOptionsPage);
  GOptionsPage := nil;
end;

end.
