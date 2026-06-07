(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.DockForm;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  DockForm,
  Delphi.Terminal.Frame.CmdShell;

type
  TfrmDelphiTerminalDock = class(TDockableForm)
  private
    FPageControl: TPageControl;
    FFrameCmd: TframeCmdShell;
    FFramePwsh: TframeCmdShell;
    FFramePowerShell: TframeCmdShell;
    FNotifierIndex: Integer;
    FGroupOpening: Boolean;
    FLastProjectDir: string;
    procedure CreateTerminalTab(const ACaption, AShellExe: string; var AFrame: TframeCmdShell);
    procedure StartTerminalShell(AFrame: TframeCmdShell; const AShellExe, AWorkDir: string);
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
  Winapi.Windows, ToolsAPI, Delphi.Terminal.Settings;

type
  TDelphiTerminalIDENotifier = class(TNotifierObject, IOTAIDENotifier)
  private
    FOwner: TfrmDelphiTerminalDock;
  public
    constructor Create(AOwner: TfrmDelphiTerminalDock);
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
  end;

{ TDelphiTerminalIDENotifier }

constructor TDelphiTerminalIDENotifier.Create(AOwner: TfrmDelphiTerminalDock);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TDelphiTerminalIDENotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
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

procedure TDelphiTerminalIDENotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
  // Not used
end;

procedure TDelphiTerminalIDENotifier.AfterCompile(Succeeded: Boolean);
begin
  // Not used
end;

var
  FInstance: TfrmDelphiTerminalDock;

class procedure TfrmDelphiTerminalDock.ShowInstance;
begin
  if not Assigned(FInstance) then
    FInstance := TfrmDelphiTerminalDock.Create(nil);
  FInstance.Show;
  FInstance.BringToFront;
  FInstance.FocusActiveFrame;
end;

class procedure TfrmDelphiTerminalDock.CleanUp;
begin
  FreeAndNil(FInstance);
end;

constructor TfrmDelphiTerminalDock.Create(AOwner: TComponent);
var
  WorkDir: string;
  S: TDelphiTerminalSettings;
  DefaultIdx, I: Integer;
begin
  inherited Create(AOwner);
  DeskSection := 'continuous_delphi_delphi_terminal';  //unique identifier for the Delphi IDE's desktop layout manager. INI section name, but lets be safe and use _
  AutoSave := True;
  SaveStateNecessary := True;
  Caption := 'delphi-terminal';
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
    StartTerminalShell(FFrameCmd, 'cmd.exe', WorkDir);
  end;
  if S.ShowPwshTab then
  begin
    CreateTerminalTab('pwsh', 'pwsh.exe', FFramePwsh);
    StartTerminalShell(FFramePwsh, 'pwsh.exe', WorkDir);
  end;
  if S.ShowPowerShellTab then
  begin
    CreateTerminalTab('PowerShell', 'powershell.exe', FFramePowerShell);
    StartTerminalShell(FFramePowerShell, 'powershell.exe', WorkDir);
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

destructor TfrmDelphiTerminalDock.Destroy;
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

procedure TfrmDelphiTerminalDock.CreateTerminalTab(const ACaption, AShellExe: string; var AFrame: TframeCmdShell);
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

procedure TfrmDelphiTerminalDock.StartTerminalShell(AFrame: TframeCmdShell; const AShellExe, AWorkDir: string);
begin
  try
    AFrame.StartShell(AShellExe, AWorkDir);
  except
    on E: Exception do
      AFrame.ShowStartupError(AShellExe, E.Message);
  end;
end;

procedure TfrmDelphiTerminalDock.HandleRequestProjectDir(Sender: TObject; var APath: string);
begin
  APath := GetActiveProjectDir;
end;

procedure TfrmDelphiTerminalDock.HandleRequestFileDir(Sender: TObject; var APath: string);
begin
  APath := GetCurrentFileDir;
end;

function TfrmDelphiTerminalDock.GetActiveProjectDir: string;
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

function TfrmDelphiTerminalDock.GetCurrentFileDir: string;
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

function TfrmDelphiTerminalDock.GetInitialWorkDir: string;
begin
  Result := GetActiveProjectDir;
  if Result = '' then
    Result := GetEnvironmentVariable('USERPROFILE');
end;

procedure TfrmDelphiTerminalDock.FocusActiveFrame;
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

procedure TfrmDelphiTerminalDock.RegisterIDENotifier;
var
  Services: IOTAServices;
begin
  FNotifierIndex := -1;
  if Supports(BorlandIDEServices, IOTAServices, Services) then
    FNotifierIndex := Services.AddNotifier(TDelphiTerminalIDENotifier.Create(Self));
end;

procedure TfrmDelphiTerminalDock.UnregisterIDENotifier;
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

procedure TfrmDelphiTerminalDock.HandleActiveProjectChanged;
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

procedure TfrmDelphiTerminalDock.HandleFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
end;

end.
