unit Test.Delphi.Terminal.VariableExpander;

interface

uses
  DUnitX.TestFramework,
  Delphi.Terminal.VariableExpander;

type

  [TestFixture]
  TTestVariableExpander = class
  private
    function MakeVars(const AProjDir: string = ''; const AProjFile: string = ''; const AFileDir: string = ''; const AFilePath: string = ''; const AFileName: string = ''; const ARadDir: string = ''): TTerminalVariables;
  public
    [Test] procedure NoTokensShouldReturnUnchanged;
    [Test] procedure ProjectDirShouldExpand;
    [Test] procedure ProjectFileShouldExpand;
    [Test] procedure FileDirShouldExpand;
    [Test] procedure FilePathShouldExpand;
    [Test] procedure FileNameShouldExpand;
    [Test] procedure RadTerminalDirShouldExpand;
    [Test] procedure MultipleVariablesShouldAllExpand;
    [Test] procedure CaseInsensitiveShouldWork;
    [Test] procedure EmptyValueShouldLeaveToken;
    [Test] procedure UnknownTokenShouldRemain;
    [Test] procedure HasUnresolvedShouldDetectTokens;
    [Test] procedure HasUnresolvedShouldReturnFalseWhenClean;
    [Test] procedure FindUnresolvedShouldReturnFirstToken;
    [Test] procedure FindUnresolvedShouldReturnEmptyWhenClean;
    [Test] procedure CmdQuotingShouldWrapInDoubleQuotes;
    [Test] procedure CmdQuotingShouldStripTrailingBackslash;
    [Test] procedure PwshQuotingShouldWrapInSingleQuotes;
    [Test] procedure PwshQuotingShouldDoubleInternalSingleQuotes;
  end;

implementation

function TTestVariableExpander.MakeVars(const AProjDir, AProjFile, AFileDir, AFilePath, AFileName, ARadDir: string): TTerminalVariables;
begin
  Result := Default(TTerminalVariables);
  Result.ProjectDir := AProjDir;
  Result.ProjectFile := AProjFile;
  Result.FileDir := AFileDir;
  Result.FilePath := AFilePath;
  Result.FileName := AFileName;
  Result.RadTerminalDir := ARadDir;
end;

procedure TTestVariableExpander.NoTokensShouldReturnUnchanged;
begin
  Assert.AreEqual('echo hello', ExpandTerminalVariables('echo hello', MakeVars, sqCmd));
end;

procedure TTestVariableExpander.ProjectDirShouldExpand;
begin
  Assert.AreEqual('cd "C:\myproj"', ExpandTerminalVariables('cd ${ProjectDir}', MakeVars('C:\myproj'), sqCmd));
end;

procedure TTestVariableExpander.ProjectFileShouldExpand;
begin
  Assert.AreEqual('msbuild "C:\myproj\test.dproj"', ExpandTerminalVariables('msbuild ${ProjectFile}', MakeVars('', 'C:\myproj\test.dproj'), sqCmd));
end;

procedure TTestVariableExpander.FileDirShouldExpand;
begin
  Assert.AreEqual('ls "C:\src"', ExpandTerminalVariables('ls ${FileDir}', MakeVars('', '', 'C:\src'), sqCmd));
end;

procedure TTestVariableExpander.FilePathShouldExpand;
begin
  Assert.AreEqual('edit "C:\src\main.pas"', ExpandTerminalVariables('edit ${FilePath}', MakeVars('', '', '', 'C:\src\main.pas'), sqCmd));
end;

procedure TTestVariableExpander.FileNameShouldExpand;
begin
  Assert.AreEqual('echo "main.pas"', ExpandTerminalVariables('echo ${FileName}', MakeVars('', '', '', '', 'main.pas'), sqCmd));
end;

procedure TTestVariableExpander.RadTerminalDirShouldExpand;
begin
  Assert.AreEqual('run "C:\plugin"', ExpandTerminalVariables('run ${radTerminalDir}', MakeVars('', '', '', '', '', 'C:\plugin'), sqCmd));
end;

procedure TTestVariableExpander.MultipleVariablesShouldAllExpand;
var
  V: TTerminalVariables;
begin
  V := MakeVars('C:\proj', 'C:\proj\app.dproj', 'C:\src');
  Assert.AreEqual('"C:\proj" and "C:\src"', ExpandTerminalVariables('${ProjectDir} and ${FileDir}', V, sqCmd));
end;

procedure TTestVariableExpander.CaseInsensitiveShouldWork;
begin
  Assert.AreEqual('cd "C:\proj"', ExpandTerminalVariables('cd ${projectdir}', MakeVars('C:\proj'), sqCmd));
end;

procedure TTestVariableExpander.EmptyValueShouldLeaveToken;
begin
  Assert.AreEqual('cd ${ProjectDir}', ExpandTerminalVariables('cd ${ProjectDir}', MakeVars, sqCmd));
end;

procedure TTestVariableExpander.UnknownTokenShouldRemain;
begin
  Assert.AreEqual('echo ${Unknown}', ExpandTerminalVariables('echo ${Unknown}', MakeVars('C:\proj'), sqCmd));
end;

procedure TTestVariableExpander.CmdQuotingShouldWrapInDoubleQuotes;
begin
  Assert.AreEqual('"C:\My Projects\Foo"', QuoteForShell('C:\My Projects\Foo', sqCmd));
end;

procedure TTestVariableExpander.CmdQuotingShouldStripTrailingBackslash;
begin
  // Trailing \ would make \" which cmd interprets as escaped quote
  Assert.AreEqual('"C:\proj"', QuoteForShell('C:\proj\', sqCmd));
  Assert.AreEqual('"C:\proj"', QuoteForShell('C:\proj\\', sqCmd));
end;

procedure TTestVariableExpander.PwshQuotingShouldWrapInSingleQuotes;
begin
  Assert.AreEqual('''C:\My Projects\Foo''', QuoteForShell('C:\My Projects\Foo', sqPowerShell));
end;

procedure TTestVariableExpander.PwshQuotingShouldDoubleInternalSingleQuotes;
begin
  Assert.AreEqual('''C:\O''''Brien''', QuoteForShell('C:\O''Brien', sqPowerShell));
end;

procedure TTestVariableExpander.HasUnresolvedShouldDetectTokens;
begin
  Assert.IsTrue(HasUnresolvedVariables('cd ${ProjectDir}'));
end;

procedure TTestVariableExpander.HasUnresolvedShouldReturnFalseWhenClean;
begin
  Assert.IsFalse(HasUnresolvedVariables('cd C:\proj'));
end;

procedure TTestVariableExpander.FindUnresolvedShouldReturnFirstToken;
begin
  Assert.AreEqual('${ProjectDir}', FindUnresolvedVariable('cd ${ProjectDir} and ${FileDir}'));
end;

procedure TTestVariableExpander.FindUnresolvedShouldReturnEmptyWhenClean;
begin
  Assert.AreEqual('', FindUnresolvedVariable('no tokens here'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestVariableExpander);

end.
