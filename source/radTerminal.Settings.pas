(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit radTerminal.Settings;

interface

uses
  System.SysUtils, System.Classes;

type
  TradTerminalSettings = class
  private
    FShowCmdTab: Boolean;
    FShowPwshTab: Boolean;
    FShowPowerShellTab: Boolean;
    FDefaultShell: string;
    FFontName: string;
    FFontSize: Integer;
    FAutoCdMode: Integer;  // 0 = active tab only, 1 = all tabs
  public
    constructor Create;
    procedure LoadFromRegistry(const ARegKeyBase: string);
    procedure SaveToRegistry(const ARegKeyBase: string);
    procedure SetDefaults;
    property ShowCmdTab: Boolean read FShowCmdTab write FShowCmdTab;
    property ShowPwshTab: Boolean read FShowPwshTab write FShowPwshTab;
    property ShowPowerShellTab: Boolean read FShowPowerShellTab write FShowPowerShellTab;
    property DefaultShell: string read FDefaultShell write FDefaultShell;
    property FontName: string read FFontName write FFontName;
    property FontSize: Integer read FFontSize write FFontSize;
    property AutoCdMode: Integer read FAutoCdMode write FAutoCdMode;
  end;

function TerminalSettings: TradTerminalSettings;

implementation

uses
  System.Win.Registry, Winapi.Windows;

var
  GSettings: TradTerminalSettings = nil;

function TerminalSettings: TradTerminalSettings;
begin
  if GSettings = nil then
  begin
    GSettings := TradTerminalSettings.Create;
    GSettings.SetDefaults;
  end;
  Result := GSettings;
end;

{ TradTerminalSettings }

constructor TradTerminalSettings.Create;
begin
  inherited Create;
  SetDefaults;
end;

procedure TradTerminalSettings.SetDefaults;
begin
  FShowCmdTab := True;
  FShowPwshTab := True;
  FShowPowerShellTab := True;
  FDefaultShell := 'pwsh.exe';
  FFontName := 'Cascadia Mono';
  FFontSize := 12;
  FAutoCdMode := 0;
end;

procedure TradTerminalSettings.LoadFromRegistry(const ARegKeyBase: string);
var
  Reg: TRegistry;
  Key: string;
begin
  Key := ARegKeyBase + '\radTerminal';
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKeyReadOnly(Key) then
      Exit;
    if Reg.ValueExists('ShowCmdTab') then
      FShowCmdTab := Reg.ReadBool('ShowCmdTab');
    if Reg.ValueExists('ShowPwshTab') then
      FShowPwshTab := Reg.ReadBool('ShowPwshTab');
    if Reg.ValueExists('ShowPowerShellTab') then
      FShowPowerShellTab := Reg.ReadBool('ShowPowerShellTab');
    if Reg.ValueExists('DefaultShell') then
      FDefaultShell := Reg.ReadString('DefaultShell');
    if Reg.ValueExists('FontName') then
      FFontName := Reg.ReadString('FontName');
    if Reg.ValueExists('FontSize') then
      FFontSize := Reg.ReadInteger('FontSize');
    if Reg.ValueExists('AutoCdMode') then
      FAutoCdMode := Reg.ReadInteger('AutoCdMode');
    Reg.CloseKey;
  finally
    Reg.Free;
  end;
end;

procedure TradTerminalSettings.SaveToRegistry(const ARegKeyBase: string);
var
  Reg: TRegistry;
  Key: string;
begin
  Key := ARegKeyBase + '\radTerminal';
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(Key, True) then
      Exit;
    Reg.WriteBool('ShowCmdTab', FShowCmdTab);
    Reg.WriteBool('ShowPwshTab', FShowPwshTab);
    Reg.WriteBool('ShowPowerShellTab', FShowPowerShellTab);
    Reg.WriteString('DefaultShell', FDefaultShell);
    Reg.WriteString('FontName', FFontName);
    Reg.WriteInteger('FontSize', FFontSize);
    Reg.WriteInteger('AutoCdMode', FAutoCdMode);
    Reg.CloseKey;
  finally
    Reg.Free;
  end;
end;

initialization

finalization
  FreeAndNil(GSettings);

end.
