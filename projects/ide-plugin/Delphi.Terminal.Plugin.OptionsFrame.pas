(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.OptionsFrame;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Delphi.Terminal.Settings;

type
  TframeDelphiTerminalOptions = class(TFrame)
  private
    FChkCmd: TCheckBox;
    FChkPwsh: TCheckBox;
    FChkPowerShell: TCheckBox;
    FChkWSL:TCheckBox;
    FCboDefaultShell: TComboBox;
    FEdtFontName: TEdit;
    FEdtFontSize: TEdit;
    FCboAutoCd: TComboBox;
    FBtnSavedCommands: TButton;
    FLblHomepage: TLabel;
    FLblVersion: TLabel;
    procedure BuildControls;
    function CreateLabel(AParent: TWinControl; ATop: Integer; const ACaption: string): TLabel;
    procedure HomepageClick(Sender: TObject);
    procedure HandleSavedCommandsClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadSettings;
    procedure SaveSettings;
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows, Winapi.ShellAPI, System.UITypes,
  Delphi.Terminal.Plugin.SavedCommandsEditor;

function GetPluginVersion: string;
var
  Stream: TResourceStream;
  Block: TMemoryStream;
  Info: PVSFixedFileInfo;
  Len: UINT;
begin
  Result := '';
  try
    Block := TMemoryStream.Create;
    try
      Stream := TResourceStream.CreateFromID(HInstance, VS_VERSION_INFO, RT_VERSION);
      try
        Block.CopyFrom(Stream, Stream.Size);
      finally
        Stream.Free;
      end;
      Block.Position := 0;
      if VerQueryValue(Block.Memory, '\', Pointer(Info), Len) then
        Result := Format('%d.%d.%d.%d', [Info.dwFileVersionMS shr 16, Info.dwFileVersionMS and $FFFF, Info.dwFileVersionLS shr 16, Info.dwFileVersionLS and $FFFF]);
    finally
      Block.Free;
    end;
  except
    Result := '';
  end;
end;

{ TframeDelphiTerminalOptions }

constructor TframeDelphiTerminalOptions.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BuildControls;
end;

function TframeDelphiTerminalOptions.CreateLabel(AParent: TWinControl; ATop: Integer; const ACaption: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Left := 16;
  Result.Top := ATop;
  Result.Caption := ACaption;
end;

procedure TframeDelphiTerminalOptions.BuildControls;
const
  Col2 = 160;
var
  Y: Integer;
  Lbl: TLabel;
begin
  Width := 500;
  Height := 420;

  Y := 10;

  // --- Visible Tabs section ---
  Lbl := CreateLabel(Self, Y, 'Visible Tabs (on next restart)');
  Lbl.Font.Style := [TFontStyle.fsBold];
  Inc(Y, 24);

  FChkCmd := TCheckBox.Create(Self);
  FChkCmd.Parent := Self;
  FChkCmd.Left := 32;
  FChkCmd.Top := Y;
  FChkCmd.Caption := 'CMD';
  FChkCmd.Width := 120;
  Inc(Y, 24);

  FChkPwsh := TCheckBox.Create(Self);
  FChkPwsh.Parent := Self;
  FChkPwsh.Left := 32;
  FChkPwsh.Top := Y;
  FChkPwsh.Caption := 'pwsh (PowerShell 7+)';
  FChkPwsh.Width := 200;
  Inc(Y, 24);

  FChkPowerShell := TCheckBox.Create(Self);
  FChkPowerShell.Parent := Self;
  FChkPowerShell.Left := 32;
  FChkPowerShell.Top := Y;
  FChkPowerShell.Caption := 'PowerShell (legacy)';
  FChkPowerShell.Width := 200;
  Inc(Y, 24);

  FChkWSL := TCheckBox.Create(Self);
  FChkWSL.Parent := Self;
  FChkWSL.Left := 32;
  FChkWSL.Top := Y;
  FChkWSL.Caption := 'Windows Subsystem for Linux (WSL)';
  FChkWSL.Width := 220;
  Inc(Y, 32);

  // --- Default Shell ---
  CreateLabel(Self, Y + 3, 'Default shell:');
  FCboDefaultShell := TComboBox.Create(Self);
  FCboDefaultShell.Parent := Self;
  FCboDefaultShell.Left := Col2;
  FCboDefaultShell.Top := Y;
  FCboDefaultShell.Width := 180;
  FCboDefaultShell.Style := csDropDownList;
  FCboDefaultShell.Items.Add('cmd.exe');
  FCboDefaultShell.Items.Add('pwsh.exe');
  FCboDefaultShell.Items.Add('powershell.exe');
  FCboDefaultShell.Items.Add('wsl.exe');
  Inc(Y, 36);

  // --- Font ---
  Lbl := CreateLabel(Self, Y, 'Font');
  Lbl.Font.Style := [TFontStyle.fsBold];
  Inc(Y, 24);

  CreateLabel(Self, Y + 3, 'Font name:');
  FEdtFontName := TEdit.Create(Self);
  FEdtFontName.Parent := Self;
  FEdtFontName.Left := Col2;
  FEdtFontName.Top := Y;
  FEdtFontName.Width := 180;
  Inc(Y, 32);

  CreateLabel(Self, Y + 3, 'Font size:');
  FEdtFontSize := TEdit.Create(Self);
  FEdtFontSize.Parent := Self;
  FEdtFontSize.Left := Col2;
  FEdtFontSize.Top := Y;
  FEdtFontSize.Width := 60;
  Inc(Y, 36);

  // --- Auto-cd ---
  Lbl := CreateLabel(Self, Y, 'Behavior');
  Lbl.Font.Style := [TFontStyle.fsBold];
  Inc(Y, 24);

  CreateLabel(Self, Y + 3, 'Auto-cd on project switch:');
  FCboAutoCd := TComboBox.Create(Self);
  FCboAutoCd.Parent := Self;
  FCboAutoCd.Left := Col2;
  FCboAutoCd.Top := Y;
  FCboAutoCd.Width := 180;
  FCboAutoCd.Style := csDropDownList;
  FCboAutoCd.Items.Add('Active tab only');
  FCboAutoCd.Items.Add('All tabs');
  Inc(Y, 36);

  // --- Saved Commands ---
  Lbl := CreateLabel(Self, Y, 'Saved Commands');
  Lbl.Font.Style := [TFontStyle.fsBold];
  Inc(Y, 24);

  FBtnSavedCommands := TButton.Create(Self);
  FBtnSavedCommands.Parent := Self;
  FBtnSavedCommands.Left := 32;
  FBtnSavedCommands.Top := Y;
  FBtnSavedCommands.Width := 140;
  FBtnSavedCommands.Caption := 'Saved Commands...';
  FBtnSavedCommands.OnClick := HandleSavedCommandsClick;
  Inc(Y, 36);

  // --- Homepage link ---
  CreateLabel(Self, Y + 3, 'Homepage:');
  FLblHomepage := TLabel.Create(Self);
  FLblHomepage.Parent := Self;
  FLblHomepage.Left := Col2;
  FLblHomepage.Top := Y + 3;
  FLblHomepage.Caption := 'github.com/continuous-delphi/delphi-terminal';
  FLblHomepage.Font.Color := clBlue;
  FLblHomepage.Font.Style := [TFontStyle.fsUnderline];
  FLblHomepage.Cursor := crHandPoint;
  FLblHomepage.OnClick := HomepageClick;
  Inc(Y, 24);

  FLblVersion := TLabel.Create(Self);
  FLblVersion.Parent := Self;
  FLblVersion.Left := 16;
  FLblVersion.Top := Y;
  FLblVersion.Caption := 'Version: ' + GetPluginVersion;
  FLblVersion.Font.Color := TColorRec.Gray;
end;

procedure TframeDelphiTerminalOptions.HandleSavedCommandsClick(Sender: TObject);
begin
  EditSavedCommands(Self, TerminalSettings.SavedCommands);
end;

procedure TframeDelphiTerminalOptions.HomepageClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://github.com/continuous-delphi/delphi-terminal', nil, nil, SW_SHOWNORMAL);
end;

procedure TframeDelphiTerminalOptions.LoadSettings;
var
  S: TDelphiTerminalSettings;
  Idx: Integer;
begin
  S := TerminalSettings;
  FChkCmd.Checked := S.ShowCmdTab;
  FChkPwsh.Checked := S.ShowPwshTab;
  FChkPowerShell.Checked := S.ShowPowerShellTab;
  FChkWSL.Checked := S.ShowWSLTab;
  Idx := FCboDefaultShell.Items.IndexOf(S.DefaultShell);
  if Idx >= 0 then
    FCboDefaultShell.ItemIndex := Idx
  else
    FCboDefaultShell.ItemIndex := 1;
  FEdtFontName.Text := S.FontName;
  FEdtFontSize.Text := IntToStr(S.FontSize);
  FCboAutoCd.ItemIndex := S.AutoCdMode;
end;

procedure TframeDelphiTerminalOptions.SaveSettings;
var
  S: TDelphiTerminalSettings;
begin
  S := TerminalSettings;
  S.ShowCmdTab := FChkCmd.Checked;
  S.ShowPwshTab := FChkPwsh.Checked;
  S.ShowPowerShellTab := FChkPowerShell.Checked;
  S.ShowWSLTab := FChkWSL.Checked;
  if FCboDefaultShell.ItemIndex >= 0 then
    S.DefaultShell := FCboDefaultShell.Items[FCboDefaultShell.ItemIndex];
  S.FontName := FEdtFontName.Text;
  S.FontSize := StrToIntDef(FEdtFontSize.Text, 12);
  S.AutoCdMode := FCboAutoCd.ItemIndex;
end;

end.
