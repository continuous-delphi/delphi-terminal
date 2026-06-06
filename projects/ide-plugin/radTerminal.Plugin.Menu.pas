unit radTerminal.Plugin.Menu;

// Adds a "radTerminal" item to the IDE View menu and wires it to the
// dockable terminal form. Lifecycle is handled in unit initialization /
// finalization -- installing the package adds the menu, uninstalling
// removes it.

interface

implementation

uses
  System.SysUtils, System.Classes,
  Vcl.Menus,
  ToolsAPI,
  radTerminal.Plugin.DockForm;

const
  CMenuItemName = 'radTerminalShowItem';
  CMenuItemCaption = 'rad&Terminal';
  CViewMenuNames: array[0..1] of string = ('ViewsMenu', 'ViewMenu');
  CToolsMenuNames: array[0..1] of string = ('ToolsMenu', 'ToolsTools');

type
  TradTerminalMenu = class
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
  GMenu: TradTerminalMenu = nil;

{ TradTerminalMenu }

constructor TradTerminalMenu.Create;
begin
  inherited Create;
  Install;
end;

destructor TradTerminalMenu.Destroy;
begin
  Uninstall;
  inherited Destroy;
end;

function TradTerminalMenu.StripAmpersands(const AText: string): string;
begin
  Result := StringReplace(AText, '&', '', [rfReplaceAll]);
end;

function TradTerminalMenu.FindItemByName(const AMainMenu: TMainMenu; const AName: string): TMenuItem;

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

function TradTerminalMenu.FindTopLevelByNames(const AMainMenu: TMainMenu; const ANames: array of string): TMenuItem;
var
  I, J: Integer;
begin
  Result := nil;
  for I := 0 to AMainMenu.Items.Count - 1 do
    for J := Low(ANames) to High(ANames) do
      if SameText(AMainMenu.Items[I].Name, ANames[J]) then
        Exit(AMainMenu.Items[I]);
end;

function TradTerminalMenu.FindTopLevelByCaption(const AMainMenu: TMainMenu; const ACaption: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AMainMenu.Items.Count - 1 do
    if SameText(Trim(StripAmpersands(AMainMenu.Items[I].Caption)), ACaption) then
      Exit(AMainMenu.Items[I]);
end;

function TradTerminalMenu.ResolveParent(const AMainMenu: TMainMenu): TMenuItem;
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

procedure TradTerminalMenu.Install;
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

procedure TradTerminalMenu.Uninstall;
begin
  FreeAndNil(FMenuItem);
end;

procedure TradTerminalMenu.HandleClick(Sender: TObject);
begin
  TfrmradTerminalDock.ShowInstance;
end;

initialization
  GMenu := TradTerminalMenu.Create;

finalization
  FreeAndNil(GMenu);

end.
