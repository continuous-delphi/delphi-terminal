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
    BuildConfig: string;
    Platform: string;
  end;

function ExpandTerminalVariables(const AText: string; const AVars: TTerminalVariables): string;
function HasUnresolvedVariables(const AText: string): Boolean;
function FindUnresolvedVariable(const AText: string): string;
function ContainsProjectVariable(const AText: string): Boolean;
function ContainsFileVariable(const AText: string): Boolean;

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
  SetLength(Result, 8);
  Result[0].Token := '${ProjectDir}';   Result[0].Value := AVars.ProjectDir;
  Result[1].Token := '${ProjectFile}';  Result[1].Value := AVars.ProjectFile;
  Result[2].Token := '${FileDir}';      Result[2].Value := AVars.FileDir;
  Result[3].Token := '${FilePath}';     Result[3].Value := AVars.FilePath;
  Result[4].Token := '${FileName}';     Result[4].Value := AVars.FileName;
  Result[5].Token := '${PluginDir}';    Result[5].Value := AVars.PluginDir;
  Result[6].Token := '${BuildConfig}';  Result[6].Value := AVars.BuildConfig;
  Result[7].Token := '${Platform}';     Result[7].Value := AVars.Platform;
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

function ContainsProjectVariable(const AText: string): Boolean;
var
  Lower: string;
begin
  Lower := LowerCase(AText);
  Result := Lower.Contains('${buildconfig}') or Lower.Contains('${platform}');
end;

function ContainsFileVariable(const AText: string): Boolean;
var
  Lower: string;
begin
  Lower := LowerCase(AText);
  Result := Lower.Contains('${filedir}') or Lower.Contains('${filepath}') or Lower.Contains('${filename}');
end;

end.
