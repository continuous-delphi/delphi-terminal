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
    procedure CreateTerminalTab(const ACaption, AShellExe: string; var AFrame: TframeCmdShell);
    procedure HandleRequestProjectDir(Sender: TObject; var APath: string);
    procedure HandleRequestFileDir(Sender: TObject; var APath: string);
    function GetActiveProjectDir: string;
    function GetCurrentFileDir: string;
    function GetInitialWorkDir: string;
    procedure HandleFormClose(Sender: TObject; var Action: TCloseAction);
    procedure FocusActiveFrame;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class procedure ShowInstance;
    class procedure CleanUp;
  end;

implementation

uses
  Winapi.Windows, ToolsAPI;

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

  WorkDir := GetInitialWorkDir;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;

  CreateTerminalTab('CMD', 'cmd.exe', FFrameCmd);
  CreateTerminalTab('pwsh', 'pwsh.exe', FFramePwsh);
  CreateTerminalTab('PowerShell', 'powershell.exe', FFramePowerShell);

  FFrameCmd.StartShell('cmd.exe', WorkDir);
  FFramePwsh.StartShell('pwsh.exe', WorkDir);
  FFramePowerShell.StartShell('powershell.exe', WorkDir);
end;

destructor TfrmradTerminalDock.Destroy;
begin
  if FInstance = Self then
    FInstance := nil;
  FFramePowerShell.StopShell;
  FFramePwsh.StopShell;
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
  Frame: TframeCmdShell;
begin
  Frame := nil;
  if FPageControl.ActivePage = FPageControl.Pages[0] then
    Frame := FFrameCmd
  else if FPageControl.ActivePage = FPageControl.Pages[1] then
    Frame := FFramePwsh
  else if FPageControl.ActivePage = FPageControl.Pages[2] then
    Frame := FFramePowerShell;
  if Frame <> nil then
    Frame.FocusInput;
end;

procedure TfrmradTerminalDock.HandleFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caHide;
end;

initialization

finalization
  TfrmradTerminalDock.CleanUp;

end.
