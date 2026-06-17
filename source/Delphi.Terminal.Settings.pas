(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Settings;

interface

uses
  System.SysUtils, System.Classes,
  Delphi.Terminal.SavedCommands;

type
  TDelphiTerminalSettings = class
  private
    FShowCmdTab: Boolean;
    FShowPwshTab: Boolean;
    FShowPowerShellTab: Boolean;
    FShowWSLTab:Boolean;
    FDefaultShell: string;
    FFontName: string;
    FFontSize: Integer;
    FAutoCdMode: Integer;  // 0 = active tab only, 1 = all tabs
    FSavedCommands: TSavedCommandList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromRegistry(const ARegKeyBase: string);
    procedure SaveToRegistry(const ARegKeyBase: string);
    procedure SetDefaults;
    property ShowCmdTab: Boolean read FShowCmdTab write FShowCmdTab;
    property ShowPwshTab: Boolean read FShowPwshTab write FShowPwshTab;
    property ShowPowerShellTab: Boolean read FShowPowerShellTab write FShowPowerShellTab;
    property ShowWSLTab: Boolean read FShowWSLTab write FShowWSLTab;
    property DefaultShell: string read FDefaultShell write FDefaultShell;
    property FontName: string read FFontName write FFontName;
    property FontSize: Integer read FFontSize write FFontSize;
    property AutoCdMode: Integer read FAutoCdMode write FAutoCdMode;
    property SavedCommands: TSavedCommandList read FSavedCommands;
  end;

function TerminalSettings: TDelphiTerminalSettings;
procedure ReleaseTerminalSettings;

implementation

uses
  System.Win.Registry, Winapi.Windows;

var
  GSettings: TDelphiTerminalSettings = nil;

function TerminalSettings: TDelphiTerminalSettings;
begin
  if GSettings = nil then
  begin
    GSettings := TDelphiTerminalSettings.Create;
    GSettings.SetDefaults;
  end;
  Result := GSettings;
end;

procedure ReleaseTerminalSettings;
begin
  FreeAndNil(GSettings);
end;

{ TDelphiTerminalSettings }

constructor TDelphiTerminalSettings.Create;
begin
  inherited Create;
  FSavedCommands := TSavedCommandList.Create;
  SetDefaults;
end;

destructor TDelphiTerminalSettings.Destroy;
begin
  FSavedCommands.Free;
  inherited;
end;

procedure TDelphiTerminalSettings.SetDefaults;
begin
  FShowCmdTab := True;
  FShowPwshTab := True;
  FShowPowerShellTab := True;
  FShowWSLTab := False;
  FDefaultShell := 'pwsh.exe';
  FFontName := 'Cascadia Mono';
  FFontSize := 12;
  FAutoCdMode := 0;
end;

procedure TDelphiTerminalSettings.LoadFromRegistry(const ARegKeyBase: string);
var
  Reg: TRegistry;
  Key: string;
begin
  Key := ARegKeyBase + '\Continuous-Delphi\delphi-terminal';
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
    if Reg.ValueExists('ShowWSLTab') then
      FShowWSLTab := Reg.ReadBool('ShowWSLTab');
    if Reg.ValueExists('DefaultShell') then
      FDefaultShell := Reg.ReadString('DefaultShell');
    if Reg.ValueExists('FontName') then
      FFontName := Reg.ReadString('FontName');
    if Reg.ValueExists('FontSize') then
      FFontSize := Reg.ReadInteger('FontSize');
    if Reg.ValueExists('AutoCdMode') then
      FAutoCdMode := Reg.ReadInteger('AutoCdMode');
    if Reg.ValueExists('SavedCommands') then
      FSavedCommands.FromJSON(Reg.ReadString('SavedCommands'));
    Reg.CloseKey;
  finally
    Reg.Free;
  end;
end;

procedure TDelphiTerminalSettings.SaveToRegistry(const ARegKeyBase: string);
var
  Reg: TRegistry;
  Key: string;
begin
  Key := ARegKeyBase + '\Continuous-Delphi\delphi-terminal';
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(Key, True) then
      Exit;
    Reg.WriteBool('ShowCmdTab', FShowCmdTab);
    Reg.WriteBool('ShowPwshTab', FShowPwshTab);
    Reg.WriteBool('ShowPowerShellTab', FShowPowerShellTab);
    Reg.WriteBool('ShowWSLTab', FShowWSLTab);
    Reg.WriteString('DefaultShell', FDefaultShell);
    Reg.WriteString('FontName', FFontName);
    Reg.WriteInteger('FontSize', FFontSize);
    Reg.WriteInteger('AutoCdMode', FAutoCdMode);
    Reg.WriteString('SavedCommands', FSavedCommands.ToJSON);
    Reg.CloseKey;
  finally
    Reg.Free;
  end;
end;

end.
