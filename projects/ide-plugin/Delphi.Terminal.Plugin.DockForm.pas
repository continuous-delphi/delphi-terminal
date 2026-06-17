(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.DockForm;

{$INCLUDE ..\..\source\DELPHI_COMPILER_VERSIONS.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls,
  DockForm,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.Frame.CmdShell;

const
  SDelphiTerminalDeskName = 'delphi_terminal_dock';

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
    procedure CreateTerminalTab(const ACaption: string; var AFrame: TframeCmdShell);
    procedure StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo:TCmdShellInfo; const AWorkDir: string);
    procedure HandleRequestProjectDir(Sender: TObject; var APath: string);
    procedure HandleRequestFileDir(Sender: TObject; var APath: string);
    function GetActiveProjectDir: string;
    function GetCurrentFileDir: string;
    function GetInitialWorkDir: string;
    procedure HandleFormClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleCommandPaletteRequested(Sender: TObject);
    procedure FocusActiveFrame;
    procedure RegisterIDENotifier;
    procedure UnregisterIDENotifier;
    procedure HandleActiveProjectChanged;
    function GetActiveProjectFile: string;
    function GetCurrentFilePath: string;
    function GetCurrentFileName: string;
    function GetActiveBuildConfig: string;
    function GetActivePlatform: string;
    function ActiveFrame: TframeCmdShell;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function IsInstanceVisible: Boolean;
    class procedure ShowInstance;
    class procedure ToggleInstance;
    class procedure CleanUp;
    class function InstanceAddress: Pointer;
  end;

implementation

uses
  Winapi.Windows,
  ToolsAPI,
  Delphi.Terminal.Settings,
  Delphi.Terminal.SavedCommands,
  Delphi.Terminal.VariableExpander,
  Delphi.Terminal.Plugin.CommandPalette;

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
    {$IFDEF CD_DELPHI_10_4_OR_LATER}  //ofnBeginProjectGroupOpen + ofnEndProjectGroupOpen defined in TOOLSAPI starting in 10.4 Sydney
    ofnBeginProjectGroupOpen:
      FOwner.FGroupOpening := True;
    ofnEndProjectGroupOpen:
      begin
        FOwner.FGroupOpening := False;
        FOwner.HandleActiveProjectChanged;
      end;
   {$ENDIF}
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
  if Assigned(FInstance) and FInstance.HandleAllocated and not IsWindowVisible(FInstance.Handle) then
  begin
    // The IDE tore down the desktop layout (e.g. welcome page) and the
    // form's dock site is gone. The VCL Visible flag may still be True
    // but the Win32 window is not actually visible. Recreate from scratch.
    FreeAndNil(FInstance);
  end;
  if not Assigned(FInstance) then
    FInstance := TfrmDelphiTerminalDock.Create(nil);
  FInstance.Show;
  FInstance.BringToFront;
  FInstance.FocusActiveFrame;
end;

class function TfrmDelphiTerminalDock.IsInstanceVisible: Boolean;
begin
  Result := Assigned(FInstance) and FInstance.HandleAllocated and IsWindowVisible(FInstance.Handle);
end;

class procedure TfrmDelphiTerminalDock.ToggleInstance;
begin
  if IsInstanceVisible then
  begin
    if FInstance.Focused or FInstance.ContainsControl(Screen.ActiveControl) then
      FInstance.Hide
    else
    begin
      FInstance.BringToFront;
      FInstance.FocusActiveFrame;
    end;
  end
  else
    ShowInstance;
end;

class procedure TfrmDelphiTerminalDock.CleanUp;
begin
  FreeAndNil(FInstance);
end;

class function TfrmDelphiTerminalDock.InstanceAddress: Pointer;
begin
  Result := @FInstance;
end;

constructor TfrmDelphiTerminalDock.Create(AOwner: TComponent);
var
  WorkDir: string;
  S: TDelphiTerminalSettings;
  DefaultIdx, I: Integer;
begin
  inherited Create(AOwner);
  FInstance := Self;
  Name := SDelphiTerminalDeskName;
  DeskSection := SDelphiTerminalDeskName;
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
    CreateTerminalTab('CMD', FFrameCmd);
    StartTerminalShell(FFrameCmd, TCmdUtils.CreateCmdShellInfo(TCmdShellType.CMD), WorkDir);
  end;
  if S.ShowPwshTab then
  begin
    CreateTerminalTab('pwsh', FFramePwsh);
    StartTerminalShell(FFramePwsh, TCmdUtils.CreateCmdShellInfo(TCmdShellType.pwsh), WorkDir);
  end;
  if S.ShowPowerShellTab then
  begin
    CreateTerminalTab('PowerShell', FFramePowerShell);
    StartTerminalShell(FFramePowerShell, TCmdUtils.CreateCmdShellInfo(TCmdShellType.PowerShell), WorkDir);
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

procedure TfrmDelphiTerminalDock.CreateTerminalTab(const ACaption: string; var AFrame: TframeCmdShell);
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
  AFrame.OnCommandPaletteRequested := HandleCommandPaletteRequested;
end;

procedure TfrmDelphiTerminalDock.StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo:TCmdShellInfo; const AWorkDir: string);
begin
  try
    AFrame.StartShell(ACmdShellInfo, AWorkDir);
  except
    on E: Exception do
      AFrame.ShowStartupError(ACmdShellInfo, E.Message);
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

function TfrmDelphiTerminalDock.GetActiveProjectFile: string;
var
  ModuleServices: IOTAModuleServices;
  Project: IOTAProject;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
  begin
    Project := ModuleServices.GetActiveProject;
    if Assigned(Project) then
      Result := Project.FileName;
  end;
end;

function TfrmDelphiTerminalDock.GetCurrentFilePath: string;
var
  EditorServices: IOTAEditorServices;
  EditBuffer: IOTAEditBuffer;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAEditorServices, EditorServices) then
  begin
    EditBuffer := EditorServices.TopBuffer;
    if Assigned(EditBuffer) then
      Result := EditBuffer.FileName;
  end;
end;

function TfrmDelphiTerminalDock.GetCurrentFileName: string;
begin
  Result := ExtractFileName(GetCurrentFilePath);
end;

function TfrmDelphiTerminalDock.GetActiveBuildConfig: string;
var
  ModuleServices: IOTAModuleServices;
  Project: IOTAProject;
  Configs: IOTAProjectOptionsConfigurations;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
  begin
    Project := ModuleServices.GetActiveProject;
    if Assigned(Project) and Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, Configs) then
      Result := Configs.ActiveConfiguration.Name;
  end;
end;

function TfrmDelphiTerminalDock.GetActivePlatform: string;
var
  ModuleServices: IOTAModuleServices;
  Project: IOTAProject;
  Configs: IOTAProjectOptionsConfigurations;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
  begin
    Project := ModuleServices.GetActiveProject;
    if Assigned(Project) and Supports(Project.ProjectOptions, IOTAProjectOptionsConfigurations, Configs) then
      Result := Configs.ActiveConfiguration.Platform;
  end;
end;

function TfrmDelphiTerminalDock.ActiveFrame: TframeCmdShell;
begin
  Result := nil;
  if (FPageControl <> nil) and (FPageControl.ActivePage <> nil) and (FPageControl.ActivePage.ControlCount > 0) then
    if FPageControl.ActivePage.Controls[0] is TframeCmdShell then
      Result := TframeCmdShell(FPageControl.ActivePage.Controls[0]);
end;

function CommandUsesProjectVariable(const ACmd: TSavedCommand): Boolean;
begin
  Result := ContainsProjectVariable(ACmd.Command) or ContainsProjectVariable(ACmd.WorkingDir);
end;

function CommandUsesFileVariable(const ACmd: TSavedCommand): Boolean;
begin
  Result := ContainsFileVariable(ACmd.Command) or ContainsFileVariable(ACmd.WorkingDir);
end;

procedure TfrmDelphiTerminalDock.HandleCommandPaletteRequested(Sender: TObject);
var
  AllCommands, Filtered, ProjectCommands: TSavedCommandList;
  ActiveShell: TSavedCommandShellType;
  ScreenPt: TPoint;
  PaletteResult: TCommandPaletteResult;
  Vars: TTerminalVariables;
  ExpandedCmd, ExpandedDir, CompoundCmd, Unresolved: string;
  ProjectFile, ActiveFilePath, BundlePath, ProjectPrefix: string;
  TargetFrame: TframeCmdShell;
  HasProject, HasFile: Boolean;
  I: Integer;
begin
  TargetFrame := ActiveFrame;
  if TargetFrame = nil then
    Exit;

  ActiveShell := GetSavedCommandShellType(TargetFrame.ShellType);
  ProjectFile := GetActiveProjectFile;
  HasProject := ProjectFile <> '';
  ActiveFilePath := GetCurrentFilePath;
  HasFile := ActiveFilePath <> '';

  Filtered := TSavedCommandList.Create;
  try
    AllCommands := TerminalSettings.SavedCommands;
    for I := 0 to AllCommands.Count - 1 do
    begin
      if not ((AllCommands[I].ShellType = scActive) or (AllCommands[I].ShellType = ActiveShell)) then
        Continue;
      if (not HasProject) and CommandUsesProjectVariable(AllCommands[I]) then
        Continue;
      if (not HasFile) and CommandUsesFileVariable(AllCommands[I]) then
        Continue;
      Filtered.Add(AllCommands[I]);
    end;
    if HasProject then
    begin
      BundlePath := ExtractFilePath(ProjectFile) + '.delphi-terminal.json';
      ProjectPrefix := 'project:' + ChangeFileExt(ExtractFileName(ProjectFile), '') + '.';
      ProjectCommands := TSavedCommandList.LoadBundleFile(BundlePath, ProjectPrefix);
      try
        for I := 0 to ProjectCommands.Count - 1 do
        begin
          if not ((ProjectCommands[I].ShellType = scActive) or (ProjectCommands[I].ShellType = ActiveShell)) then
            Continue;
          if (not HasFile) and CommandUsesFileVariable(ProjectCommands[I]) then
            Continue;
          Filtered.Add(ProjectCommands[I]);
        end;
      finally
        ProjectCommands.Free;
      end;
    end;

    if Filtered.Count = 0 then
      Exit;

    if Sender is TframeCmdShell then
      ScreenPt := TframeCmdShell(Sender).ClientToScreen(Point(0, 0))
    else
      ScreenPt := ClientToScreen(Point(0, 0));

    PaletteResult := ShowCommandPalette(Self, Filtered, ScreenPt);
    if PaletteResult.Action = paCancel then
      Exit;
  finally
    Filtered.Free;
  end;

  Vars := Default(TTerminalVariables);
  Vars.ProjectDir := GetActiveProjectDir;
  Vars.ProjectFile := ProjectFile;
  Vars.FileDir := GetCurrentFileDir;
  Vars.FilePath := GetCurrentFilePath;
  Vars.FileName := GetCurrentFileName;
  Vars.BuildConfig := GetActiveBuildConfig;
  Vars.Platform := GetActivePlatform;
  Vars.PluginDir := ExtractFilePath(GetModuleName(HInstance));

  ExpandedCmd := ExpandTerminalVariables(PaletteResult.Command.Command, Vars);
  ExpandedDir := ExpandTerminalVariables(PaletteResult.Command.WorkingDir, Vars);

  if HasUnresolvedVariables(ExpandedCmd) then
  begin
    Unresolved := FindUnresolvedVariable(ExpandedCmd);
    TargetFrame.ShowMessage(Format('[delphi-terminal] Cannot run "%s": %s could not be resolved', [PaletteResult.Command.Name, Unresolved]));
    Exit;
  end;
  if HasUnresolvedVariables(ExpandedDir) then
  begin
    Unresolved := FindUnresolvedVariable(ExpandedDir);
    TargetFrame.ShowMessage(Format('[delphi-terminal] Cannot run "%s": %s could not be resolved', [PaletteResult.Command.Name, Unresolved]));
    Exit;
  end;

  if ExpandedDir <> '' then
    CompoundCmd := TCmdUtils.GetCDAndRunCommand(TargetFrame.ShellType, ExpandedDir, ExpandedCmd)
  else
    CompoundCmd := ExpandedCmd;

  if PaletteResult.Action = paEdit then
    TargetFrame.InsertCommandText(CompoundCmd)
  else
    TargetFrame.SendUserCommand(CompoundCmd);
end;

procedure TfrmDelphiTerminalDock.HandleFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
end;

end.
