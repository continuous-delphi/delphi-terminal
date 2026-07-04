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

  TConPty = class
  private
    FConPtyAPI:TConPtyAPI;
    FIsAvailable:Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property IsAvailable: Boolean read FIsAvailable;
  end;


implementation
uses
  System.SysUtils,
  WinAPI.Windows;



constructor TConPty.Create;
begin
  inherited;
  FIsAvailable := FConPtyAPI.Initialize;
end;


destructor TConPty.Destroy;
begin
  //
  inherited;
end;


end.
