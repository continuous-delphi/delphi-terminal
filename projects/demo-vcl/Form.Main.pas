(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Form.Main;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls,
  Delphi.Terminal.CmdShell,
  Delphi.Terminal.Frame.CmdShell,
  Delphi.Terminal.ScreenBuffer,
  Delphi.Terminal.VTParser,
  Delphi.Terminal.TerminalView;

type

  // Mainly for initial dev and ongoing debug purposes
  TfrmMain = class(TForm)
    PageControl1: TPageControl;
    tabCmdShell: TTabSheet;
    tabPwsh: TTabSheet;
    tabPowerShell: TTabSheet;
    tabWSL: TTabSheet;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FFrameCmdShell: TframeCmdShell;
    FFramePwsh: TframeCmdShell;
    FFramePowerShell: TframeCmdShell;
    FFrameWSL:TframeCmdShell;
    // Sneak peek (#67): a TTerminalView rendering canned VT content, so the new
    // cursor-addressed renderer can be eyeballed before the full frame wiring (#68).
    FTermViewTab: TTabSheet;
    FTermView: TTerminalView;
    FTermBuffer: TScreenBuffer;
    FTermParser: TVTParser;
    procedure StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
    procedure HandleRequestDir(Sender: TObject; var APath: string);
    procedure SetupTerminalViewDemo;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Vcl.FileCtrl,
  Delphi.Terminal.Settings;

{$R *.dfm}

procedure TfrmMain.StartTerminalShell(AFrame: TframeCmdShell; const ACmdShellInfo: TCmdShellInfo; const AWorkDir: string);
begin
  {$IFDEF DEBUG}
  AFrame.BackendKind := tbConPty;
  {$ENDIF}
  try
    AFrame.StartShell(ACmdShellInfo, AWorkDir);
  except
    on E: Exception do
      AFrame.ShowStartupError(ACmdShellInfo, E.Message);
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ExeDir: string;
begin
  ReportMemoryLeaksOnShutdown := True;

  ExeDir := ExtractFilePath(Application.ExeName);

  FFrameCmdShell := TframeCmdShell.Create(Self);
  FFrameCmdShell.Name := 'CMDFrame';
  FFrameCmdShell.Parent := tabCmdShell;
  FFrameCmdShell.Align := alClient;
  FFrameCmdShell.OnRequestProjectDir := HandleRequestDir;
  FFrameCmdShell.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFrameCmdShell, TCmdUtils.CreateCmdShellInfo(TCmdShellType.CMD), ExeDir);

  FFramePwsh := TframeCmdShell.Create(Self);
  FFramePwsh.Name := 'PWSHFrame';
  FFramePwsh.Parent := tabPwsh;
  FFramePwsh.Align := alClient;
  FFramePwsh.OnRequestProjectDir := HandleRequestDir;
  FFramePwsh.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFramePwsh, TCmdUtils.CreateCmdShellInfo(TCmdShellType.pwsh), ExeDir);

  FFramePowerShell := TframeCmdShell.Create(Self);
  FFramePowerShell.Name := 'PowerShellFrame';
  FFramePowerShell.Parent := tabPowerShell;
  FFramePowerShell.Align := alClient;
  FFramePowerShell.OnRequestProjectDir := HandleRequestDir;
  FFramePowerShell.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFramePowerShell, TCmdUtils.CreateCmdShellInfo(TCmdShellType.PowerShell), ExeDir);

  FFrameWSL := TframeCmdShell.Create(Self);
  FFrameWSL.Name := 'WSLFrame';
  FFrameWSL.Parent := tabWSL;
  FFrameWSL.Align := alClient;
  FFrameWSL.OnRequestProjectDir := HandleRequestDir;
  FFrameWSL.OnRequestFileDir := HandleRequestDir;
  StartTerminalShell(FFrameWSL, TCmdUtils.CreateCmdShellInfo(TCmdShellType.wsl), ExeDir);

  SetupTerminalViewDemo;
end;

procedure TfrmMain.SetupTerminalViewDemo;
const
  ESC = #27;
var
  S: string;
  I: Integer;
begin
  FTermViewTab := TTabSheet.Create(PageControl1);
  FTermViewTab.PageControl := PageControl1;
  FTermViewTab.Caption := 'TTerminalView';

  FTermBuffer := TScreenBuffer.Create(80, 24);
  FTermParser := TVTParser.Create(FTermBuffer);

  FTermView := TTerminalView.Create(Self);
  FTermView.Parent := FTermViewTab;
  FTermView.Align := alClient;
  FTermView.Buffer := FTermBuffer;

  // Canned VT content exercising SGR styles, the 16-colour palette, the 256-colour
  // cube, and 24-bit truecolour -- driven through the real parser + screen model.
  S := ESC + '[1;36mdelphi-terminal  -  TTerminalView sneak peek (#67)' + ESC + '[0m' + #13#10 + #13#10;

  S := S + 'SGR styles:  ' + ESC + '[1mBold' + ESC + '[0m  ' + ESC + '[3mItalic' + ESC + '[0m  ' +
       ESC + '[4mUnderline' + ESC + '[0m  ' + ESC + '[7mInverse' + ESC + '[0m' + #13#10 + #13#10;

  S := S + '16 colours:  ';
  for I := 0 to 7 do
    S := S + ESC + '[4' + IntToStr(I) + 'm  ';
  S := S + ESC + '[0m' + #13#10 + '             ';
  for I := 0 to 7 do
    S := S + ESC + '[10' + IntToStr(I) + 'm  ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  S := S + '256-cube:    ';
  for I := 16 to 51 do
    S := S + ESC + '[48;5;' + IntToStr(I) + 'm ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  S := S + 'Truecolor:   ';
  for I := 0 to 35 do
    S := S + ESC + '[48;2;' + IntToStr(I * 7) + ';0;' + IntToStr(255 - I * 7) + 'm ';
  S := S + ESC + '[0m' + #13#10 + #13#10;

  S := S + ESC + '[32mCursor-addressed prompt (block cursor shown):' + ESC + '[0m' + #13#10;
  S := S + '  ' + ESC + '[33m$' + ESC + '[0m ready ';

  FTermParser.Parse(S);
  FTermView.UpdateView;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FFramePowerShell.StopShell;
  FFramePwsh.StopShell;
  FFrameCmdShell.StopShell;
  FFrameWSL.StopShell;
  FTermParser.Free;
  FTermBuffer.Free;
end;

procedure TfrmMain.HandleRequestDir(Sender: TObject; var APath: string);
var
  Dir: string;
begin
  Dir := '';
  if SelectDirectory('Select Directory', '', Dir) then
    APath := Dir;
end;

initialization
finalization
ReleaseTerminalSettings;

end.
