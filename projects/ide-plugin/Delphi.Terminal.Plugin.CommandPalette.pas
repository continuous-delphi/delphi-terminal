(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.Plugin.CommandPalette;

interface

uses
  System.SysUtils, System.Classes, System.Types,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Delphi.Terminal.SavedCommands;

type
  TCommandPaletteAction = (paCancel, paEdit, paRun);

  TCommandPaletteResult = record
    Action: TCommandPaletteAction;
    Command: TSavedCommand;
  end;

  TfrmCommandPalette = class(TForm)
  private
    FEdtFilter: TEdit;
    FListBox: TListBox;
    FCommands: TSavedCommandList;
    FFilteredIndices: TArray<Integer>;
    FResult: TCommandPaletteResult;
    procedure BuildControls;
    procedure HandleFilterChange(Sender: TObject);
    procedure HandleFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleListBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleListBoxDblClick(Sender: TObject);
    procedure ApplyFilter;
    procedure AcceptSelected(AAction: TCommandPaletteAction);
  protected
    procedure DoShow; override;
    procedure Deactivate; override;
  public
    constructor CreateForCommands(AOwner: TComponent; ACommands: TSavedCommandList);
    property PaletteResult: TCommandPaletteResult read FResult;
  end;

function ShowCommandPalette(AOwner: TComponent; ACommands: TSavedCommandList; AScreenPos: TPoint): TCommandPaletteResult;

implementation

uses
  Winapi.Windows;

function ShowCommandPalette(AOwner: TComponent; ACommands: TSavedCommandList; AScreenPos: TPoint): TCommandPaletteResult;
var
  Dlg: TfrmCommandPalette;
begin
  Result := Default(TCommandPaletteResult);
  if ACommands.Count = 0 then
    Exit;
  Dlg := TfrmCommandPalette.CreateForCommands(AOwner, ACommands);
  try
    Dlg.Left := AScreenPos.X;
    Dlg.Top := AScreenPos.Y - Dlg.Height;
    if Dlg.Top < 0 then
      Dlg.Top := AScreenPos.Y;
    Dlg.ShowModal;
    Result := Dlg.PaletteResult;
  finally
    Dlg.Free;
  end;
end;

{ TfrmCommandPalette }

constructor TfrmCommandPalette.CreateForCommands(AOwner: TComponent; ACommands: TSavedCommandList);
begin
  inherited CreateNew(AOwner);
  FCommands := ACommands;
  FResult := Default(TCommandPaletteResult);
  BuildControls;
  ApplyFilter;
end;

procedure TfrmCommandPalette.BuildControls;
begin
  Width := 450;
  Height := 300;
  BorderStyle := bsToolWindow;
  Caption := 'Run Saved Command';

  FEdtFilter := TEdit.Create(Self);
  FEdtFilter.Parent := Self;
  FEdtFilter.Align := alTop;
  FEdtFilter.TextHint := 'Type to filter...';
  FEdtFilter.OnChange := HandleFilterChange;
  FEdtFilter.OnKeyDown := HandleFilterKeyDown;

  FListBox := TListBox.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.OnKeyDown := HandleListBoxKeyDown;
  FListBox.OnDblClick := HandleListBoxDblClick;
end;

procedure TfrmCommandPalette.DoShow;
begin
  inherited;
  if FEdtFilter.CanFocus then
    FEdtFilter.SetFocus;
end;

procedure TfrmCommandPalette.Deactivate;
begin
  inherited;
  if Visible then
    ModalResult := mrCancel;
end;

procedure TfrmCommandPalette.ApplyFilter;
var
  Filter: string;
  I, Idx: Integer;
  Cmd: TSavedCommand;
begin
  Filter := LowerCase(Trim(FEdtFilter.Text));
  FListBox.Items.BeginUpdate;
  try
    FListBox.Items.Clear;
    SetLength(FFilteredIndices, 0);
    for I := 0 to FCommands.Count - 1 do
    begin
      Cmd := FCommands[I];
      if (Filter = '') or LowerCase(Cmd.Name).Contains(Filter) or LowerCase(Cmd.Command).Contains(Filter) then
      begin
        Idx := Length(FFilteredIndices);
        SetLength(FFilteredIndices, Idx + 1);
        FFilteredIndices[Idx] := I;
        FListBox.Items.Add(Cmd.Name + '  --  ' + Cmd.Command);
      end;
    end;
  finally
    FListBox.Items.EndUpdate;
  end;
  if FListBox.Items.Count > 0 then
    FListBox.ItemIndex := 0;
end;

procedure TfrmCommandPalette.HandleFilterChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TfrmCommandPalette.HandleFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_DOWN:
    begin
      if (FListBox.ItemIndex < FListBox.Items.Count - 1) then
        FListBox.ItemIndex := FListBox.ItemIndex + 1;
      Key := 0;
    end;
    VK_UP:
    begin
      if FListBox.ItemIndex > 0 then
        FListBox.ItemIndex := FListBox.ItemIndex - 1;
      Key := 0;
    end;
    VK_RETURN:
    begin
      if ssCtrl in Shift then
        AcceptSelected(paRun)
      else
        AcceptSelected(paEdit);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      ModalResult := mrCancel;
      Key := 0;
    end;
  end;
end;

procedure TfrmCommandPalette.HandleListBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
    begin
      if ssCtrl in Shift then
        AcceptSelected(paRun)
      else
        AcceptSelected(paEdit);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      ModalResult := mrCancel;
      Key := 0;
    end;
  end;
end;

procedure TfrmCommandPalette.HandleListBoxDblClick(Sender: TObject);
begin
  AcceptSelected(paEdit);
end;

procedure TfrmCommandPalette.AcceptSelected(AAction: TCommandPaletteAction);
var
  SelIdx: Integer;
begin
  if FListBox.ItemIndex < 0 then
    Exit;
  SelIdx := FFilteredIndices[FListBox.ItemIndex];
  FResult.Action := AAction;
  FResult.Command := FCommands[SelIdx];
  ModalResult := mrOk;
end;

end.
