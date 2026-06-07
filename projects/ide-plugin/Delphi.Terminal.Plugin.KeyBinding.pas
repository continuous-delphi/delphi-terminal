(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.KeyBinding;

interface

procedure RegisterKeyBinding;
procedure UnregisterKeyBinding;

implementation

uses
  System.Classes,
  System.SysUtils,
  Vcl.Menus,
  ToolsAPI,
  Delphi.Terminal.Plugin.DockForm;

type
  TDelphiTerminalKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  public
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
    procedure ToggleTerminalKeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
  end;

var
  FKeyBindingIndex: Integer = -1;

{ TDelphiTerminalKeyBinding }

function TDelphiTerminalKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TDelphiTerminalKeyBinding.GetDisplayName: string;
begin
  Result := 'delphi-terminal';
end;

function TDelphiTerminalKeyBinding.GetName: string;
begin
  Result := 'DelphiTerminal.KeyBinding';
end;

procedure TDelphiTerminalKeyBinding.ToggleTerminalKeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  TfrmDelphiTerminalDock.ToggleInstance;
  BindingResult := krHandled;
end;

procedure TDelphiTerminalKeyBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
var
  Key: TShortCut;
begin
  Key := ShortCut(Ord('N'), [ssCtrl, ssAlt]);
  BindingServices.AddKeyBinding([Key], ToggleTerminalKeyProc, nil);
end;

{ Registration }

procedure RegisterKeyBinding;
var
  KeyboardServices: IOTAKeyboardServices;
begin
  if Supports(BorlandIDEServices, IOTAKeyboardServices, KeyboardServices) then
    FKeyBindingIndex := KeyboardServices.AddKeyboardBinding(TDelphiTerminalKeyBinding.Create);
end;

procedure UnregisterKeyBinding;
var
  KeyboardServices: IOTAKeyboardServices;
begin
  if (FKeyBindingIndex >= 0) and Supports(BorlandIDEServices, IOTAKeyboardServices, KeyboardServices) then
  begin
    KeyboardServices.RemoveKeyboardBinding(FKeyBindingIndex);
    FKeyBindingIndex := -1;
  end;
end;

end.
