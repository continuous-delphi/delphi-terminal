(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit Delphi.Terminal.VariableExpander;

interface

type
  TTerminalVariables = record
    ProjectDir: string;
    ProjectFile: string;
    FileDir: string;
    FilePath: string;
    FileName: string;
    PluginDir: string;
  end;

function ExpandTerminalVariables(const AText: string; const AVars: TTerminalVariables): string;
function HasUnresolvedVariables(const AText: string): Boolean;
function FindUnresolvedVariable(const AText: string): string;

implementation

uses
  System.SysUtils;

type
  TVarMapping = record
    Token: string;
    Value: string;
  end;

function BuildMappings(const AVars: TTerminalVariables): TArray<TVarMapping>;
begin
  SetLength(Result, 6);
  Result[0].Token := '${ProjectDir}';   Result[0].Value := AVars.ProjectDir;
  Result[1].Token := '${ProjectFile}';  Result[1].Value := AVars.ProjectFile;
  Result[2].Token := '${FileDir}';      Result[2].Value := AVars.FileDir;
  Result[3].Token := '${FilePath}';     Result[3].Value := AVars.FilePath;
  Result[4].Token := '${FileName}';     Result[4].Value := AVars.FileName;
  Result[5].Token := '${PluginDir}'; Result[5].Value := AVars.PluginDir;
end;

function ExpandTerminalVariables(const AText: string; const AVars: TTerminalVariables): string;
var
  Mappings: TArray<TVarMapping>;
  I: Integer;
begin
  Result := AText;
  Mappings := BuildMappings(AVars);
  for I := Low(Mappings) to High(Mappings) do
  begin
    if Mappings[I].Value <> '' then
      Result := StringReplace(Result, Mappings[I].Token, Mappings[I].Value, [rfReplaceAll, rfIgnoreCase]);
  end;
end;

function HasUnresolvedVariables(const AText: string): Boolean;
begin
  Result := FindUnresolvedVariable(AText) <> '';
end;

function FindUnresolvedVariable(const AText: string): string;
var
  StartPos, EndPos: Integer;
begin
  Result := '';
  StartPos := Pos('${', AText);
  if StartPos = 0 then
    Exit;
  EndPos := Pos('}', AText, StartPos + 2);
  if EndPos = 0 then
    Exit;
  Result := Copy(AText, StartPos, EndPos - StartPos + 1);
end;

end.
