(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.Menu;

// Adds a "Delphi-Terminal" item to the IDE View menu and wires it to the
// dockable terminal form. Lifecycle is handled in unit initialization /
// finalization -- installing the package adds the menu, uninstalling
// removes it.

interface

implementation

uses
  System.SysUtils, System.Classes,
  Vcl.Menus,
  ToolsAPI,
  Delphi.Terminal.Plugin.DockForm;

const
  CMenuItemName = 'DelphiTerminalShowItem';
  CMenuItemCaption = 'Delphi-&Terminal';
  CViewMenuNames: array[0..1] of string = ('ViewsMenu', 'ViewMenu');
  CToolsMenuNames: array[0..1] of string = ('ToolsMenu', 'ToolsTools');

type
  TDelphiTerminalMenu = class
  private
    FMenuItem: TMenuItem;
    procedure HandleClick(Sender: TObject);
    function StripAmpersands(const AText: string): string;
    function FindTopLevelByNames(const AMainMenu: TMainMenu; const ANames: array of string): TMenuItem;
    function FindTopLevelByCaption(const AMainMenu: TMainMenu; const ACaption: string): TMenuItem;
    function FindItemByName(const AMainMenu: TMainMenu; const AName: string): TMenuItem;
    function ResolveParent(const AMainMenu: TMainMenu): TMenuItem;
    procedure Install;
    procedure Uninstall;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  GMenu: TDelphiTerminalMenu = nil;

{ TDelphiTerminalMenu }

constructor TDelphiTerminalMenu.Create;
begin
  inherited Create;
  Install;
end;

destructor TDelphiTerminalMenu.Destroy;
begin
  Uninstall;
  inherited Destroy;
end;

function TDelphiTerminalMenu.StripAmpersands(const AText: string): string;
begin
  Result := StringReplace(AText, '&', '', [rfReplaceAll]);
end;

function TDelphiTerminalMenu.FindItemByName(const AMainMenu: TMainMenu; const AName: string): TMenuItem;

  function Recurse(const AParent: TMenuItem): TMenuItem;
  var
    I: Integer;
  begin
    Result := nil;
    for I := 0 to AParent.Count - 1 do
    begin
      if SameText(AParent.Items[I].Name, AName) then
        Exit(AParent.Items[I]);
      Result := Recurse(AParent.Items[I]);
      if Result <> nil then
        Exit;
    end;
  end;

begin
  Result := Recurse(AMainMenu.Items);
end;

function TDelphiTerminalMenu.FindTopLevelByNames(const AMainMenu: TMainMenu; const ANames: array of string): TMenuItem;
var
  I, J: Integer;
begin
  Result := nil;
  for I := 0 to AMainMenu.Items.Count - 1 do
    for J := Low(ANames) to High(ANames) do
      if SameText(AMainMenu.Items[I].Name, ANames[J]) then
        Exit(AMainMenu.Items[I]);
end;

function TDelphiTerminalMenu.FindTopLevelByCaption(const AMainMenu: TMainMenu; const ACaption: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AMainMenu.Items.Count - 1 do
    if SameText(Trim(StripAmpersands(AMainMenu.Items[I].Caption)), ACaption) then
      Exit(AMainMenu.Items[I]);
end;

function TDelphiTerminalMenu.ResolveParent(const AMainMenu: TMainMenu): TMenuItem;
begin
  Result := FindTopLevelByNames(AMainMenu, CViewMenuNames);
  if Result = nil then
    Result := FindTopLevelByCaption(AMainMenu, 'View');
  if Result = nil then
    Result := FindTopLevelByNames(AMainMenu, CToolsMenuNames);
  if Result = nil then
    Result := FindTopLevelByCaption(AMainMenu, 'Tools');
  if Result = nil then
    Result := AMainMenu.Items;
end;

procedure TDelphiTerminalMenu.Install;
var
  Services: INTAServices;
  MainMenu: TMainMenu;
  Parent: TMenuItem;
  Existing: TMenuItem;
begin
  if not Supports(BorlandIDEServices, INTAServices, Services) then
    Exit;

  MainMenu := Services.MainMenu;
  if MainMenu = nil then
    Exit;

  Existing := FindItemByName(MainMenu, CMenuItemName);
  if Existing <> nil then
    Existing.Free;

  Parent := ResolveParent(MainMenu);
  if Parent = nil then
    Exit;

  FMenuItem := TMenuItem.Create(nil);
  FMenuItem.Name := CMenuItemName;
  FMenuItem.Caption := CMenuItemCaption;
  FMenuItem.OnClick := HandleClick;
  Parent.Add(FMenuItem);
end;

procedure TDelphiTerminalMenu.Uninstall;
begin
  FreeAndNil(FMenuItem);
end;

procedure TDelphiTerminalMenu.HandleClick(Sender: TObject);
begin
  TfrmDelphiTerminalDock.ShowInstance;
end;

initialization
  GMenu := TDelphiTerminalMenu.Create;

finalization
  FreeAndNil(GMenu);

end.
