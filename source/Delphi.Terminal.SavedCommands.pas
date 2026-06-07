(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.SavedCommands;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Menus;

type
  TSavedCommandShellType = (scActive, scCmd, scPwsh, scPowerShell);

  TSavedCommand = record
    Name: string;
    ShellType: TSavedCommandShellType;
    Command: string;
    WorkingDir: string;
  end;

  TSavedCommandList = class
  private
    FItems: TList<TSavedCommand>;
    function GetItem(AIndex: Integer): TSavedCommand;
    procedure SetItem(AIndex: Integer; const AValue: TSavedCommand);
  public
    constructor Create;
    destructor Destroy; override;
    function Count: Integer;
    procedure Add(const ACmd: TSavedCommand);
    procedure Delete(AIndex: Integer);
    procedure Move(AOldIndex, ANewIndex: Integer);
    procedure Clear;
    procedure Assign(ASource: TSavedCommandList);
    function ToJSON: string;
    procedure FromJSON(const AJSON: string);
    procedure ImportBundle(const AJSON: string);
    procedure DeleteByPrefix(const APrefix: string);
    class function ParseBundlePrefix(const AJSON: string): string;
    class function ParseBundleDescription(const AJSON: string): string;
    class function ShellTypeToString(AType: TSavedCommandShellType): string;
    class function StringToShellType(const AValue: string): TSavedCommandShellType;
    property Items[AIndex: Integer]: TSavedCommand read GetItem write SetItem; default;
  end;

implementation

uses
  System.JSON;

{ TSavedCommandList }

constructor TSavedCommandList.Create;
begin
  inherited Create;
  FItems := TList<TSavedCommand>.Create;
end;

destructor TSavedCommandList.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TSavedCommandList.Count: Integer;
begin
  Result := FItems.Count;
end;

function TSavedCommandList.GetItem(AIndex: Integer): TSavedCommand;
begin
  Result := FItems[AIndex];
end;

procedure TSavedCommandList.SetItem(AIndex: Integer; const AValue: TSavedCommand);
begin
  FItems[AIndex] := AValue;
end;

procedure TSavedCommandList.Add(const ACmd: TSavedCommand);
begin
  FItems.Add(ACmd);
end;

procedure TSavedCommandList.Delete(AIndex: Integer);
begin
  FItems.Delete(AIndex);
end;

procedure TSavedCommandList.Move(AOldIndex, ANewIndex: Integer);
var
  Cmd: TSavedCommand;
begin
  if (AOldIndex < 0) or (AOldIndex >= FItems.Count) then
    Exit;
  if (ANewIndex < 0) or (ANewIndex >= FItems.Count) then
    Exit;
  if AOldIndex = ANewIndex then
    Exit;
  Cmd := FItems[AOldIndex];
  FItems.Delete(AOldIndex);
  FItems.Insert(ANewIndex, Cmd);
end;

procedure TSavedCommandList.Clear;
begin
  FItems.Clear;
end;

procedure TSavedCommandList.Assign(ASource: TSavedCommandList);
var
  I: Integer;
begin
  FItems.Clear;
  for I := 0 to ASource.Count - 1 do
    FItems.Add(ASource[I]);
end;

class function TSavedCommandList.ShellTypeToString(AType: TSavedCommandShellType): string;
begin
  case AType of
    scActive: Result := 'active';
    scCmd: Result := 'cmd';
    scPwsh: Result := 'pwsh';
    scPowerShell: Result := 'powershell';
  else
    Result := 'active';
  end;
end;

class function TSavedCommandList.StringToShellType(const AValue: string): TSavedCommandShellType;
var
  Lower: string;
begin
  Lower := LowerCase(AValue);
  if Lower = 'cmd' then
    Result := scCmd
  else if Lower = 'pwsh' then
    Result := scPwsh
  else if (Lower = 'powershell') or (Lower = 'ps') then
    Result := scPowerShell
  else
    Result := scActive;
end;

function TSavedCommandList.ToJSON: string;
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
  Cmd: TSavedCommand;
begin
  Arr := TJSONArray.Create;
  try
    for I := 0 to FItems.Count - 1 do
    begin
      Cmd := FItems[I];
      Obj := TJSONObject.Create;
      Obj.AddPair('name', Cmd.Name);
      Obj.AddPair('shell', ShellTypeToString(Cmd.ShellType));
      Obj.AddPair('command', Cmd.Command);
      if Cmd.WorkingDir <> '' then
        Obj.AddPair('workdir', Cmd.WorkingDir);
      Arr.AddElement(Obj);
    end;
    Result := Arr.ToJSON;
  finally
    Arr.Free;
  end;
end;

procedure TSavedCommandList.FromJSON(const AJSON: string);
var
  Val: TJSONValue;
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
  Cmd: TSavedCommand;
  Pair: TJSONPair;
begin
  FItems.Clear;
  if AJSON = '' then
    Exit;
  try
    Val := TJSONObject.ParseJSONValue(AJSON);
  except
    Exit;
  end;
  if Val = nil then
    Exit;
  try
    if not (Val is TJSONArray) then
      Exit;
    Arr := TJSONArray(Val);
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Obj := TJSONObject(Arr.Items[I]);
      Cmd := Default(TSavedCommand);
      Pair := Obj.Get('name');
      if Pair <> nil then
        Cmd.Name := Pair.JsonValue.Value;
      Pair := Obj.Get('shell');
      if Pair <> nil then
        Cmd.ShellType := StringToShellType(Pair.JsonValue.Value);
      Pair := Obj.Get('command');
      if Pair <> nil then
        Cmd.Command := Pair.JsonValue.Value;
      Pair := Obj.Get('workdir');
      if Pair <> nil then
        Cmd.WorkingDir := Pair.JsonValue.Value;
      FItems.Add(Cmd);
    end;
  finally
    Val.Free;
  end;
end;

procedure TSavedCommandList.DeleteByPrefix(const APrefix: string);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if APrefix.Length > 0 then
      if FItems[I].Name.StartsWith(APrefix, True) then
        FItems.Delete(I);
end;

procedure TSavedCommandList.ImportBundle(const AJSON: string);
var
  Val: TJSONValue;
  Root: TJSONObject;
  Arr: TJSONArray;
  Obj: TJSONObject;
  Prefix: string;
  I: Integer;
  Cmd: TSavedCommand;
  Pair: TJSONPair;
begin
  if AJSON = '' then
    Exit;
  try
    Val := TJSONObject.ParseJSONValue(AJSON);
  except
    Exit;
  end;
  if Val = nil then
    Exit;
  try
    if not (Val is TJSONObject) then
      Exit;
    Root := TJSONObject(Val);
    Pair := Root.Get('prefix');
    if Pair = nil then
      Exit;
    Prefix := Pair.JsonValue.Value;
    if Prefix = '' then
      Exit;
    Pair := Root.Get('commands');
    if (Pair = nil) or not (Pair.JsonValue is TJSONArray) then
      Exit;
    Arr := TJSONArray(Pair.JsonValue);
    DeleteByPrefix(Prefix);
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then
        Continue;
      Obj := TJSONObject(Arr.Items[I]);
      Cmd := Default(TSavedCommand);
      Pair := Obj.Get('name');
      if Pair <> nil then
        Cmd.Name := Pair.JsonValue.Value;
      Pair := Obj.Get('shell');
      if Pair <> nil then
        Cmd.ShellType := StringToShellType(Pair.JsonValue.Value);
      Pair := Obj.Get('command');
      if Pair <> nil then
        Cmd.Command := Pair.JsonValue.Value;
      Pair := Obj.Get('workdir');
      if Pair <> nil then
        Cmd.WorkingDir := Pair.JsonValue.Value;
      FItems.Add(Cmd);
    end;
  finally
    Val.Free;
  end;
end;

class function TSavedCommandList.ParseBundlePrefix(const AJSON: string): string;
var
  Val: TJSONValue;
  Pair: TJSONPair;
begin
  Result := '';
  if AJSON = '' then
    Exit;
  try
    Val := TJSONObject.ParseJSONValue(AJSON);
  except
    Exit;
  end;
  if Val = nil then
    Exit;
  try
    if Val is TJSONObject then
    begin
      Pair := TJSONObject(Val).Get('prefix');
      if Pair <> nil then
        Result := Pair.JsonValue.Value;
    end;
  finally
    Val.Free;
  end;
end;

class function TSavedCommandList.ParseBundleDescription(const AJSON: string): string;
var
  Val: TJSONValue;
  Pair: TJSONPair;
begin
  Result := '';
  if AJSON = '' then
    Exit;
  try
    Val := TJSONObject.ParseJSONValue(AJSON);
  except
    Exit;
  end;
  if Val = nil then
    Exit;
  try
    if Val is TJSONObject then
    begin
      Pair := TJSONObject(Val).Get('description');
      if Pair <> nil then
        Result := Pair.JsonValue.Value;
    end;
  finally
    Val.Free;
  end;
end;

end.
