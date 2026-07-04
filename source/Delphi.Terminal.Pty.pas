(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Pty;

interface
uses
  WinAPI.ConPty;

type

  TConPty = record
  private
    FCreatePseudoConsole: TCreatePseudoConsoleFunc;
    FResizePseudoConsole: TResizePseudoConsoleFunc;
    FClosePseudoConsole: TClosePseudoConsoleFunc;
    FInitializeProcThreadAttributeList: TInitializeProcThreadAttributeListFunc;
    FUpdateProcThreadAttribute: TUpdateProcThreadAttributeFunc;
    FDeleteProcThreadAttributeList: TDeleteProcThreadAttributeListFunc;
  public
    function Initialize: Boolean;
    function IsAvailable: Boolean;
  end;


implementation
uses
  System.SysUtils,
  WinAPI.Windows;



function TConPty.Initialize: Boolean;
var
  hModule: HINST;
begin
  Self := Default(TConPty);

  if System.SysUtils.Win32MajorVersion >= 10 then
  begin
    hModule:= GetModuleHandle(WinAPI.Windows.Kernel32);

    FCreatePseudoConsole := TCreatePseudoConsoleFunc(GetProcAddress(hModule, 'CreatePseudoConsole'));
    FResizePseudoConsole := TResizePseudoConsoleFunc(GetProcAddress(hModule, 'ResizePseudoConsole'));
    FClosePseudoConsole := TClosePseudoConsoleFunc(GetProcAddress(hModule, 'ClosePseudoConsole'));
    FInitializeProcThreadAttributeList := TInitializeProcThreadAttributeListFunc(GetProcAddress(hModule, 'InitializeProcThreadAttributeList'));
    FUpdateProcThreadAttribute := TUpdateProcThreadAttributeFunc(GetProcAddress(hModule, 'UpdateProcThreadAttribute'));
    FDeleteProcThreadAttributeList := TDeleteProcThreadAttributeListFunc(GetProcAddress(hModule, 'DeleteProcThreadAttributeList'));
  end;

  Result := IsAvailable;
end;


function TConPty.IsAvailable: Boolean;
begin
  Result := Assigned(FCreatePseudoConsole) and
            Assigned(FResizePseudoConsole) and
            Assigned(FClosePseudoConsole) and
            Assigned(FInitializeProcThreadAttributeList) and
            Assigned(FUpdateProcThreadAttribute) and
            Assigned(FDeleteProcThreadAttributeList);
end;


end.
