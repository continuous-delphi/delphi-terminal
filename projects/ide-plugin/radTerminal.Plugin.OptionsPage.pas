(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit radTerminal.Plugin.OptionsPage;

interface

uses
  Vcl.Forms, ToolsAPI;

type
  TradTerminalOptionsPage = class(TInterfacedObject, INTAAddInOptions)
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
  radTerminal.Plugin.OptionsFrame,
  radTerminal.Settings;

var
  GOptionsPage: INTAAddInOptions = nil;

{ TradTerminalOptionsPage }

function TradTerminalOptionsPage.GetArea: string;
begin
  Result := '';  // Third Party section
end;

function TradTerminalOptionsPage.GetCaption: string;
begin
  Result := 'radTerminal';
end;

function TradTerminalOptionsPage.GetFrameClass: TCustomFrameClass;
begin
  Result := TframeradTerminalOptions;
end;

procedure TradTerminalOptionsPage.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := AFrame;
  if FFrame is TframeradTerminalOptions then
    TframeradTerminalOptions(FFrame).LoadSettings;
end;

procedure TradTerminalOptionsPage.DialogClosed(Accepted: Boolean);
var
  RegKey: string;
begin
  if Accepted and (FFrame is TframeradTerminalOptions) then
  begin
    TframeradTerminalOptions(FFrame).SaveSettings;
    RegKey := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey;
    TerminalSettings.SaveToRegistry(RegKey);
  end;
  FFrame := nil;
end;

function TradTerminalOptionsPage.ValidateContents: Boolean;
begin
  Result := True;
  if FFrame is TframeradTerminalOptions then
  begin
    with TframeradTerminalOptions(FFrame) do
    begin
      // Ensure at least one tab is checked -- handled by settings consumer
    end;
  end;
end;

function TradTerminalOptionsPage.GetHelpContext: Integer;
begin
  Result := 0;
end;

function TradTerminalOptionsPage.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

class procedure TradTerminalOptionsPage.RegisterOptions;
var
  Svc: INTAEnvironmentOptionsServices;
begin
  if not Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, Svc) then
    Exit;
  GOptionsPage := TradTerminalOptionsPage.Create;
  Svc.RegisterAddInOptions(GOptionsPage);
end;

class procedure TradTerminalOptionsPage.UnregisterOptions;
var
  Svc: INTAEnvironmentOptionsServices;
begin
  if GOptionsPage = nil then
    Exit;
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, Svc) then
    Svc.UnregisterAddInOptions(GOptionsPage);
  GOptionsPage := nil;
end;

initialization

finalization
  TradTerminalOptionsPage.UnregisterOptions;

end.
