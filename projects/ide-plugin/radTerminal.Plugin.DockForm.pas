(*

  radTerminal
  https://github.com/radprogrammer/radTerminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit radTerminal.Plugin.DockForm;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  DockForm,
  radTerminal.Frame.CmdShell;

type
  TfrmradTerminalDock = class(TDockableForm)
  private
    FPageControl: TPageControl;
    FFrameCmd: TframeCmdShell;
    FFramePwsh: TframeCmdShell;
    FFramePowerShell: TframeCmdShell;
    FNotifierIndex: Integer;
    FGroupOpening: Boolean;
    FLastProjectDir: string;
    procedure CreateTerminalTab(const ACaption, AShellExe: string; var AFrame: TframeCmdShell);
    procedure HandleRequestProjectDir(Sender: TObject; var APath: string);
    procedure HandleRequestFileDir(Sender: TObject; var APath: string);
    function GetActiveProjectDir: string;
    function GetCurrentFileDir: string;
    function GetInitialWorkDir: string;
    procedure HandleFormClose(Sender: TObject; var Action: TCloseAction);
    procedure FocusActiveFrame;
    procedure RegisterIDENotifier;
    procedure UnregisterIDENotifier;
    procedure HandleActiveProjectChanged;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class procedure ShowInstance;
    class procedure CleanUp;
  end;

implementation

uses
  Winapi.Windows, ToolsAPI, radTerminal.Settings;

type
  TradTerminalIDENotifier = class(TNotifierObject, IOTAIDENotifier)
  private
    FOwner: TfrmradTerminalDock;
  public
    constructor Create(AOwner: TfrmradTerminalDock);
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
  end;

{ TradTerminalIDENotifier }

constructor TradTerminalIDENotifier.Create(AOwner: TfrmradTerminalDock);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TradTerminalIDENotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
begin
  case NotifyCode of
    ofnBeginProjectGroupOpen:
      FOwner.FGroupOpening := True;
    ofnEndProjectGroupOpen:
    begin
      FOwner.FGroupOpening := False;
      FOwner.HandleActiveProjectChanged;
    end;
    ofnActiveProjectChanged:
      if not FOwner.FGroupOpening then
        FOwner.HandleActiveProjectChanged;
  end;
end;

procedure TradTerminalIDENotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
  // Not used
end;

procedure TradTerminalIDENotifier.AfterCompile(Succeeded: Boolean);
begin
  // Not used
end;

var
  FInstance: TfrmradTerminalDock;

class procedure TfrmradTerminalDock.ShowInstance;
begin
  if not Assigned(FInstance) then
    FInstance := TfrmradTerminalDock.Create(nil);
  FInstance.Show;
  FInstance.BringToFront;
  FInstance.FocusActiveFrame;
end;

class procedure TfrmradTerminalDock.CleanUp;
begin
  FreeAndNil(FInstance);
end;

constructor TfrmradTerminalDock.Create(AOwner: TComponent);
var
  WorkDir: string;
  S: TradTerminalSettings;
  DefaultIdx, I: Integer;
begin
  inherited Create(AOwner);
  DeskSection := 'radTerminal';
  AutoSave := True;
  SaveStateNecessary := True;
  Caption := 'radTerminal';
  ClientWidth := 800;
  ClientHeight := 400;
  Position := poScreenCenter;
  OnClose := HandleFormClose;

  S := TerminalSettings;
  if not S.ShowCmdTab and not S.ShowPwshTab and not S.ShowPowerShellTab then
    S.ShowCmdTab := True;
  WorkDir := GetInitialWorkDir;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;

  if S.ShowCmdTab then
  begin
    CreateTerminalTab('CMD', 'cmd.exe', FFrameCmd);
    FFrameCmd.StartShell('cmd.exe', WorkDir);
  end;
  if S.ShowPwshTab then
  begin
    CreateTerminalTab('pwsh', 'pwsh.exe', FFramePwsh);
    FFramePwsh.StartShell('pwsh.exe', WorkDir);
  end;
  if S.ShowPowerShellTab then
  begin
    CreateTerminalTab('PowerShell', 'powershell.exe', FFramePowerShell);
    FFramePowerShell.StartShell('powershell.exe', WorkDir);
  end;

  // Activate the default shell tab
  DefaultIdx := -1;
  for I := 0 to FPageControl.PageCount - 1 do
  begin
    if SameText(FPageControl.Pages[I].Caption, 'CMD') and SameText(S.DefaultShell, 'cmd.exe') then
      DefaultIdx := I
    else if SameText(FPageControl.Pages[I].Caption, 'pwsh') and SameText(S.DefaultShell, 'pwsh.exe') then
      DefaultIdx := I
    else if SameText(FPageControl.Pages[I].Caption, 'PowerShell') and SameText(S.DefaultShell, 'powershell.exe') then
      DefaultIdx := I;
  end;
  if (DefaultIdx >= 0) and (DefaultIdx < FPageControl.PageCount) then
    FPageControl.ActivePageIndex := DefaultIdx;

  FLastProjectDir := WorkDir;
  RegisterIDENotifier;
end;

destructor TfrmradTerminalDock.Destroy;
begin
  UnregisterIDENotifier;
  if FInstance = Self then
    FInstance := nil;
  if FFramePowerShell <> nil then
    FFramePowerShell.StopShell;
  if FFramePwsh <> nil then
    FFramePwsh.StopShell;
  if FFrameCmd <> nil then
    FFrameCmd.StopShell;
  inherited;
end;

procedure TfrmradTerminalDock.CreateTerminalTab(const ACaption, AShellExe: string; var AFrame: TframeCmdShell);
var
  Tab: TTabSheet;
begin
  Tab := TTabSheet.Create(FPageControl);
  Tab.PageControl := FPageControl;
  Tab.Caption := ACaption;

  AFrame := TframeCmdShell.Create(Tab);
  AFrame.Parent := Tab;
  AFrame.Align := alClient;
  AFrame.OnRequestProjectDir := HandleRequestProjectDir;
  AFrame.OnRequestFileDir := HandleRequestFileDir;
end;

procedure TfrmradTerminalDock.HandleRequestProjectDir(Sender: TObject; var APath: string);
begin
  APath := GetActiveProjectDir;
end;

procedure TfrmradTerminalDock.HandleRequestFileDir(Sender: TObject; var APath: string);
begin
  APath := GetCurrentFileDir;
end;

function TfrmradTerminalDock.GetActiveProjectDir: string;
var
  ModuleServices: IOTAModuleServices;
  Project: IOTAProject;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
  begin
    Project := ModuleServices.GetActiveProject;
    if Assigned(Project) then
      Result := ExtractFilePath(Project.FileName);
  end;
end;

function TfrmradTerminalDock.GetCurrentFileDir: string;
var
  EditorServices: IOTAEditorServices;
  EditBuffer: IOTAEditBuffer;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAEditorServices, EditorServices) then
  begin
    EditBuffer := EditorServices.TopBuffer;
    if Assigned(EditBuffer) then
      Result := ExtractFilePath(EditBuffer.FileName);
  end;
end;

function TfrmradTerminalDock.GetInitialWorkDir: string;
begin
  Result := GetActiveProjectDir;
  if Result = '' then
    Result := GetEnvironmentVariable('USERPROFILE');
end;

procedure TfrmradTerminalDock.FocusActiveFrame;
var
  I: Integer;
begin
  if (FPageControl = nil) or (FPageControl.ActivePage = nil) then
    Exit;
  for I := 0 to FPageControl.ActivePage.ControlCount - 1 do
    if FPageControl.ActivePage.Controls[I] is TframeCmdShell then
    begin
      TframeCmdShell(FPageControl.ActivePage.Controls[I]).FocusInput;
      Exit;
    end;
end;

procedure TfrmradTerminalDock.RegisterIDENotifier;
var
  Services: IOTAServices;
begin
  FNotifierIndex := -1;
  if Supports(BorlandIDEServices, IOTAServices, Services) then
    FNotifierIndex := Services.AddNotifier(TradTerminalIDENotifier.Create(Self));
end;

procedure TfrmradTerminalDock.UnregisterIDENotifier;
var
  Services: IOTAServices;
begin
  if FNotifierIndex >= 0 then
  begin
    if Supports(BorlandIDEServices, IOTAServices, Services) then
      Services.RemoveNotifier(FNotifierIndex);
    FNotifierIndex := -1;
  end;
end;

procedure TfrmradTerminalDock.HandleActiveProjectChanged;
var
  ProjectDir: string;
  I: Integer;
begin
  ProjectDir := GetActiveProjectDir;
  if (ProjectDir = '') or SameText(ProjectDir, FLastProjectDir) then
    Exit;
  FLastProjectDir := ProjectDir;

  if TerminalSettings.AutoCdMode = 1 then
  begin
    // All tabs
    for I := 0 to FPageControl.PageCount - 1 do
      if FPageControl.Pages[I].ControlCount > 0 then
        if FPageControl.Pages[I].Controls[0] is TframeCmdShell then
          TframeCmdShell(FPageControl.Pages[I].Controls[0]).SetWorkingDirectory(ProjectDir);
  end
  else
  begin
    // Active tab only
    if (FPageControl.ActivePage <> nil) and (FPageControl.ActivePage.ControlCount > 0) then
      if FPageControl.ActivePage.Controls[0] is TframeCmdShell then
        TframeCmdShell(FPageControl.ActivePage.Controls[0]).SetWorkingDirectory(ProjectDir);
  end;
end;

procedure TfrmradTerminalDock.HandleFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
end;

initialization

finalization
  TfrmradTerminalDock.CleanUp;

end.
