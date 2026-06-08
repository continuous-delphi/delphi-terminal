(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.SavedCommandsEditor;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  Delphi.Terminal.SavedCommands;

type
  TfrmSavedCommandsEditor = class(TForm)
  private
    FListView: TListView;
    FBtnAdd: TButton;
    FBtnEdit: TButton;
    FBtnDelete: TButton;
    FBtnMoveUp: TButton;
    FBtnMoveDown: TButton;
    FBtnImport: TButton;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    FCommands: TSavedCommandList;
    procedure BuildControls;
    procedure RefreshListView;
    procedure HandleAdd(Sender: TObject);
    procedure HandleEdit(Sender: TObject);
    procedure HandleDelete(Sender: TObject);
    procedure HandleMoveUp(Sender: TObject);
    procedure HandleMoveDown(Sender: TObject);
    procedure HandleImport(Sender: TObject);
    procedure HandleListViewDblClick(Sender: TObject);
    function EditCommand(var ACmd: TSavedCommand; AIsNew: Boolean): Boolean;
    function PrefixMatchCount(const APrefix: string): Integer;
  public
    constructor CreateForCommands(AOwner: TComponent; ACommands: TSavedCommandList);
    destructor Destroy; override;
    property Commands: TSavedCommandList read FCommands;
  end;

function EditSavedCommands(AOwner: TComponent; ACommands: TSavedCommandList): Boolean;

implementation

uses
  System.UITypes;

function EditSavedCommands(AOwner: TComponent; ACommands: TSavedCommandList): Boolean;
var
  Dlg: TfrmSavedCommandsEditor;
begin
  Dlg := TfrmSavedCommandsEditor.CreateForCommands(AOwner, ACommands);
  try
    Result := Dlg.ShowModal = mrOk;
    if Result then
      ACommands.Assign(Dlg.Commands);
  finally
    Dlg.Free;
  end;
end;

{ TfrmSavedCommandsEditor }

constructor TfrmSavedCommandsEditor.CreateForCommands(AOwner: TComponent; ACommands: TSavedCommandList);
begin
  inherited CreateNew(AOwner);
  FCommands := TSavedCommandList.Create;
  FCommands.Assign(ACommands);
  BuildControls;
  RefreshListView;
end;

destructor TfrmSavedCommandsEditor.Destroy;
begin
  FCommands.Free;
  inherited;
end;

procedure TfrmSavedCommandsEditor.BuildControls;
var
  PanelButtons, PanelBottom: TPanel;
  Col: TListColumn;
begin
  Caption := 'Saved Commands';
  Width := 750;
  Height := 450;
  Position := poOwnerFormCenter;
  BorderStyle := bsDialog;

  PanelBottom := TPanel.Create(Self);
  PanelBottom.Parent := Self;
  PanelBottom.Align := alBottom;
  PanelBottom.Height := 40;
  PanelBottom.BevelOuter := bvNone;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := PanelBottom;
  FBtnOK.Caption := 'OK';
  FBtnOK.Width := 80;
  FBtnOK.Top := 8;
  FBtnOK.Left := PanelBottom.Width - 180;
  FBtnOK.Anchors := [akTop, akRight];
  FBtnOK.ModalResult := mrOk;
  FBtnOK.Default := True;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := PanelBottom;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Width := 80;
  FBtnCancel.Top := 8;
  FBtnCancel.Left := PanelBottom.Width - 90;
  FBtnCancel.Anchors := [akTop, akRight];
  FBtnCancel.ModalResult := mrCancel;
  FBtnCancel.Cancel := True;

  PanelButtons := TPanel.Create(Self);
  PanelButtons.Parent := Self;
  PanelButtons.Align := alRight;
  PanelButtons.Width := 100;
  PanelButtons.BevelOuter := bvNone;

  FBtnAdd := TButton.Create(Self);
  FBtnAdd.Parent := PanelButtons;
  FBtnAdd.Caption := 'Add';
  FBtnAdd.Left := 10;
  FBtnAdd.Top := 8;
  FBtnAdd.Width := 80;
  FBtnAdd.OnClick := HandleAdd;

  FBtnEdit := TButton.Create(Self);
  FBtnEdit.Parent := PanelButtons;
  FBtnEdit.Caption := 'Edit';
  FBtnEdit.Left := 10;
  FBtnEdit.Top := 40;
  FBtnEdit.Width := 80;
  FBtnEdit.OnClick := HandleEdit;

  FBtnDelete := TButton.Create(Self);
  FBtnDelete.Parent := PanelButtons;
  FBtnDelete.Caption := 'Delete';
  FBtnDelete.Left := 10;
  FBtnDelete.Top := 72;
  FBtnDelete.Width := 80;
  FBtnDelete.OnClick := HandleDelete;

  FBtnMoveUp := TButton.Create(Self);
  FBtnMoveUp.Parent := PanelButtons;
  FBtnMoveUp.Caption := 'Move Up';
  FBtnMoveUp.Left := 10;
  FBtnMoveUp.Top := 112;
  FBtnMoveUp.Width := 80;
  FBtnMoveUp.OnClick := HandleMoveUp;

  FBtnMoveDown := TButton.Create(Self);
  FBtnMoveDown.Parent := PanelButtons;
  FBtnMoveDown.Caption := 'Move Down';
  FBtnMoveDown.Left := 10;
  FBtnMoveDown.Top := 144;
  FBtnMoveDown.Width := 80;
  FBtnMoveDown.OnClick := HandleMoveDown;

  FBtnImport := TButton.Create(Self);
  FBtnImport.Parent := PanelButtons;
  FBtnImport.Caption := 'Import...';
  FBtnImport.Left := 10;
  FBtnImport.Top := 184;
  FBtnImport.Width := 80;
  FBtnImport.OnClick := HandleImport;

  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.RowSelect := True;
  FListView.ReadOnly := True;
  FListView.HideSelection := False;
  FListView.OnDblClick := HandleListViewDblClick;

  Col := FListView.Columns.Add;
  Col.Caption := 'Name';
  Col.Width := 140;

  Col := FListView.Columns.Add;
  Col.Caption := 'Shell';
  Col.Width := 80;

  Col := FListView.Columns.Add;
  Col.Caption := 'Command';
  Col.Width := 280;

  Col := FListView.Columns.Add;
  Col.Caption := 'Working Dir';
  Col.Width := 200;
end;

procedure TfrmSavedCommandsEditor.RefreshListView;
var
  I, SelIdx: Integer;
  Item: TListItem;
  Cmd: TSavedCommand;
begin
  SelIdx := -1;
  if (FListView.Selected <> nil) then
    SelIdx := FListView.Selected.Index;
  FListView.Items.BeginUpdate;
  try
    FListView.Items.Clear;
    for I := 0 to FCommands.Count - 1 do
    begin
      Cmd := FCommands[I];
      Item := FListView.Items.Add;
      Item.Caption := Cmd.Name;
      Item.SubItems.Add(TSavedCommandList.ShellTypeToString(Cmd.ShellType));
      Item.SubItems.Add(Cmd.Command);
      Item.SubItems.Add(Cmd.WorkingDir);
    end;
  finally
    FListView.Items.EndUpdate;
  end;
  if (SelIdx >= 0) and (SelIdx < FListView.Items.Count) then
  begin
    FListView.Items[SelIdx].Selected := True;
    FListView.Items[SelIdx].Focused := True;
  end;
end;

function ContainsFileVariable(const AText: string): Boolean;
var
  Lower: string;
begin
  Lower := LowerCase(AText);
  Result := Lower.Contains('${projectfile}') or Lower.Contains('${filepath}') or Lower.Contains('${filename}');
end;

type
  TfrmEditCommand = class(TForm)
  public
    EdtWorkDir: TEdit;
    function CloseQuery: Boolean; override;
  end;

function TfrmEditCommand.CloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
  if not Result then
    Exit;
  if (ModalResult = mrOk) and ContainsFileVariable(EdtWorkDir.Text) then
  begin
    Result := False;
    MessageDlg('Working Dir contains a file variable (${ProjectFile}, ${FilePath}, or ${FileName}).' + sLineBreak +
      'Use a directory variable such as ${ProjectDir} or ${FileDir} instead.', mtWarning, [mbOK], 0);
    if EdtWorkDir.CanFocus then
      EdtWorkDir.SetFocus;
  end;
end;

function TfrmSavedCommandsEditor.EditCommand(var ACmd: TSavedCommand; AIsNew: Boolean): Boolean;
var
  Dlg: TfrmEditCommand;
  EdtName, EdtCommand: TEdit;
  CboShell: TComboBox;
  BtnOK, BtnCancel: TButton;
  LblVars: TLabel;
  Y: Integer;

  procedure AddLabel(AParent: TWinControl; ATop: Integer; const ACaption: string);
  var
    Lbl: TLabel;
  begin
    Lbl := TLabel.Create(Dlg);
    Lbl.Parent := AParent;
    Lbl.Left := 12;
    Lbl.Top := ATop;
    Lbl.Caption := ACaption;
  end;

begin
  Result := False;
  Dlg := TfrmEditCommand.CreateNew(Self);
  try
    if AIsNew then
      Dlg.Caption := 'Add Command'
    else
      Dlg.Caption := 'Edit Command';
    Dlg.Width := 500;
    Dlg.Height := 310;
    Dlg.Position := poOwnerFormCenter;
    Dlg.BorderStyle := bsDialog;

    Y := 12;

    AddLabel(Dlg, Y, 'Name:');
    EdtName := TEdit.Create(Dlg);
    EdtName.Parent := Dlg;
    EdtName.Left := 120;
    EdtName.Top := Y;
    EdtName.Width := 350;
    EdtName.Text := ACmd.Name;
    Inc(Y, 32);

    AddLabel(Dlg, Y + 3, 'Shell:');
    CboShell := TComboBox.Create(Dlg);
    CboShell.Parent := Dlg;
    CboShell.Left := 120;
    CboShell.Top := Y;
    CboShell.Width := 150;
    CboShell.Style := csDropDownList;
    CboShell.Items.Add('Active tab');
    CboShell.Items.Add('cmd');
    CboShell.Items.Add('pwsh');
    CboShell.Items.Add('powershell');
    CboShell.ItemIndex := Ord(ACmd.ShellType);
    Inc(Y, 32);

    AddLabel(Dlg, Y, 'Command:');
    EdtCommand := TEdit.Create(Dlg);
    EdtCommand.Parent := Dlg;
    EdtCommand.Left := 120;
    EdtCommand.Top := Y;
    EdtCommand.Width := 350;
    EdtCommand.Text := ACmd.Command;
    Inc(Y, 32);

    AddLabel(Dlg, Y, 'Working Dir:');
    Dlg.EdtWorkDir := TEdit.Create(Dlg);
    Dlg.EdtWorkDir.Parent := Dlg;
    Dlg.EdtWorkDir.Left := 120;
    Dlg.EdtWorkDir.Top := Y;
    Dlg.EdtWorkDir.Width := 350;
    Dlg.EdtWorkDir.Text := ACmd.WorkingDir;
    Dlg.EdtWorkDir.TextHint := 'Optional - ${ProjectDir}, static path, etc.';
    Inc(Y, 40);

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := Dlg;
    BtnOK.Caption := 'OK';
    BtnOK.Left := 300;
    BtnOK.Top := Y;
    BtnOK.Width := 80;
    BtnOK.ModalResult := mrOk;
    BtnOK.Default := True;

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := Dlg;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.Left := 390;
    BtnCancel.Top := Y;
    BtnCancel.Width := 80;
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;
    Inc(Y, 40);

    LblVars := TLabel.Create(Dlg);
    LblVars.Parent := Dlg;
    LblVars.Left := 12;
    LblVars.Top := Y;
    LblVars.Caption :=
      'Variables:  ${ProjectDir}  ${ProjectFile}  ${FileDir}  ${FilePath}  ${FileName}  ${radTerminalDir}';
    LblVars.Font.Size := LblVars.Font.Size - 1;
    LblVars.Font.Color := TColorRec.Gray;

    if Dlg.ShowModal = mrOk then
    begin
      ACmd.Name := Trim(EdtName.Text);
      if CboShell.ItemIndex >= 0 then
        ACmd.ShellType := TSavedCommandShellType(CboShell.ItemIndex);
      ACmd.Command := EdtCommand.Text;
      ACmd.WorkingDir := Trim(Dlg.EdtWorkDir.Text);
      Result := True;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSavedCommandsEditor.HandleAdd(Sender: TObject);
var
  Cmd: TSavedCommand;
begin
  Cmd := Default(TSavedCommand);
  if EditCommand(Cmd, True) then
  begin
    FCommands.Add(Cmd);
    RefreshListView;
    FListView.Items[FListView.Items.Count - 1].Selected := True;
  end;
end;

procedure TfrmSavedCommandsEditor.HandleEdit(Sender: TObject);
var
  Idx: Integer;
  Cmd: TSavedCommand;
begin
  if FListView.Selected = nil then
    Exit;
  Idx := FListView.Selected.Index;
  Cmd := FCommands[Idx];
  if EditCommand(Cmd, False) then
  begin
    FCommands[Idx] := Cmd;
    RefreshListView;
  end;
end;

procedure TfrmSavedCommandsEditor.HandleDelete(Sender: TObject);
var
  Idx: Integer;
begin
  if FListView.Selected = nil then
    Exit;
  Idx := FListView.Selected.Index;
  if MessageDlg(Format('Delete "%s"?', [FCommands[Idx].Name]), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FCommands.Delete(Idx);
    RefreshListView;
  end;
end;

procedure TfrmSavedCommandsEditor.HandleMoveUp(Sender: TObject);
var
  Idx: Integer;
begin
  if FListView.Selected = nil then
    Exit;
  Idx := FListView.Selected.Index;
  if Idx > 0 then
  begin
    FCommands.Move(Idx, Idx - 1);
    RefreshListView;
    FListView.Items[Idx - 1].Selected := True;
    FListView.Items[Idx - 1].Focused := True;
  end;
end;

procedure TfrmSavedCommandsEditor.HandleMoveDown(Sender: TObject);
var
  Idx: Integer;
begin
  if FListView.Selected = nil then
    Exit;
  Idx := FListView.Selected.Index;
  if Idx < FCommands.Count - 1 then
  begin
    FCommands.Move(Idx, Idx + 1);
    RefreshListView;
    FListView.Items[Idx + 1].Selected := True;
    FListView.Items[Idx + 1].Focused := True;
  end;
end;

function TfrmSavedCommandsEditor.PrefixMatchCount(const APrefix: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FCommands.Count - 1 do
    if FCommands[I].Name.StartsWith(APrefix, True) then
      Inc(Result);
end;

procedure TfrmSavedCommandsEditor.HandleImport(Sender: TObject);
var
  Dlg: TOpenDialog;
  JSON, Prefix, Desc, Msg: string;
  Stream: TStringList;
  Existing: Integer;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Import Command Bundle';
    Dlg.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
    Dlg.DefaultExt := 'json';
    if not Dlg.Execute then
      Exit;
    Stream := TStringList.Create;
    try
      Stream.LoadFromFile(Dlg.FileName);
      JSON := Stream.Text;
    finally
      Stream.Free;
    end;
  finally
    Dlg.Free;
  end;

  Prefix := TSavedCommandList.ParseBundlePrefix(JSON);
  if Prefix = '' then
  begin
    MessageDlg('Invalid bundle file: no "prefix" field found.', mtError, [mbOK], 0);
    Exit;
  end;

  Desc := TSavedCommandList.ParseBundleDescription(JSON);
  Existing := PrefixMatchCount(Prefix);

  if Existing > 0 then
    Msg := Format('Import bundle "%s"'#13#10'%s'#13#10#13#10'This will replace %d existing %s* command(s).', [Prefix, Desc, Existing, Prefix])
  else
    Msg := Format('Import bundle "%s"'#13#10'%s', [Prefix, Desc]);

  if MessageDlg(Msg, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  FCommands.ImportBundle(JSON);
  RefreshListView;
end;

procedure TfrmSavedCommandsEditor.HandleListViewDblClick(Sender: TObject);
begin
  HandleEdit(Sender);
end;

end.
