unit Test.Delphi.Terminal.SavedCommands;

interface

uses
  DUnitX.TestFramework,
  Delphi.Terminal.SavedCommands;

type

  [TestFixture]
  TTestSavedCommandList = class
  private
    FList: TSavedCommandList;
    function MakeCmd(const AName, ACommand: string; AShell: TSavedCommandShellType = scActive; const AWorkDir: string = ''): TSavedCommand;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure ShouldStartEmpty;
    [Test] procedure AddShouldIncrementCount;
    [Test] procedure DeleteShouldRemoveItem;
    [Test] procedure MoveShouldReorderItems;
    [Test] procedure MoveOutOfRangeShouldDoNothing;
    [Test] procedure ClearShouldEmptyList;
    [Test] procedure AssignShouldCopyItems;
    [Test] procedure ToJSONAndFromJSONShouldRoundTrip;
    [Test] procedure FromJSONEmptyStringShouldClear;
    [Test] procedure FromJSONMalformedShouldClear;
    [Test] procedure WorkingDirShouldSerialize;
    [Test] procedure WorkingDirAbsentShouldDeserializeEmpty;
    [Test] procedure ShellTypeRoundTrip;

    [Test] procedure ImportBundleShouldAddCommands;
    [Test] procedure ImportBundleShouldReplacePrefixMatches;
    [Test] procedure ImportBundleShouldNotTouchOtherCommands;
    [Test] procedure DeleteByPrefixShouldRemoveOnlyMatching;
    [Test] procedure ParseBundlePrefixShouldExtractPrefix;
    [Test] procedure ParseBundleDescriptionShouldExtractDescription;
    [Test] procedure ImportBundleMalformedShouldDoNothing;
    [Test] procedure ImportBundleNoPrefixShouldAppend;
    [Test] procedure ImportBundleShouldSkipExactDuplicates;

    [Test] procedure ToBundleJSONShouldProduceValidBundle;
    [Test] procedure ToBundleJSONShouldOnlyIncludePrefixMatches;
    [Test] procedure ToBundleJSONShouldRoundTripViaImport;
    [Test] procedure ToBundleJSONShouldOmitEmptyWorkDir;
    [Test] procedure ToBundleJSONEmptyPrefixShouldExportAll;

    [Test] procedure LoadBundleFileShouldLoadWithPrefix;
    [Test] procedure LoadBundleFileMissingFileShouldReturnEmpty;
    [Test] procedure LoadBundleFileMalformedShouldReturnEmpty;
    [Test] procedure LoadBundleFileEmptyPrefixShouldLoadUnprefixed;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils;

function TTestSavedCommandList.MakeCmd(const AName, ACommand: string; AShell: TSavedCommandShellType; const AWorkDir: string): TSavedCommand;
begin
  Result := Default(TSavedCommand);
  Result.Name := AName;
  Result.Command := ACommand;
  Result.ShellType := AShell;
  Result.WorkingDir := AWorkDir;
end;

procedure TTestSavedCommandList.Setup;
begin
  FList := TSavedCommandList.Create;
end;

procedure TTestSavedCommandList.TearDown;
begin
  FList.Free;
end;

procedure TTestSavedCommandList.ShouldStartEmpty;
begin
  Assert.AreEqual(NativeInt(0), NativeInt(FList.Count));
end;

procedure TTestSavedCommandList.AddShouldIncrementCount;
begin
  FList.Add(MakeCmd('test', 'echo hello'));
  Assert.AreEqual(NativeInt(1), NativeInt(FList.Count));
  Assert.AreEqual('test', FList[0].Name);
end;

procedure TTestSavedCommandList.DeleteShouldRemoveItem;
begin
  FList.Add(MakeCmd('a', 'cmd a'));
  FList.Add(MakeCmd('b', 'cmd b'));
  FList.Delete(0);
  Assert.AreEqual(NativeInt(1), NativeInt(FList.Count));
  Assert.AreEqual('b', FList[0].Name);
end;

procedure TTestSavedCommandList.MoveShouldReorderItems;
begin
  FList.Add(MakeCmd('a', '1'));
  FList.Add(MakeCmd('b', '2'));
  FList.Add(MakeCmd('c', '3'));
  FList.Move(2, 0);
  Assert.AreEqual('c', FList[0].Name);
  Assert.AreEqual('a', FList[1].Name);
  Assert.AreEqual('b', FList[2].Name);
end;

procedure TTestSavedCommandList.MoveOutOfRangeShouldDoNothing;
begin
  FList.Add(MakeCmd('a', '1'));
  FList.Move(0, 5);
  Assert.AreEqual(NativeInt(1), NativeInt(FList.Count));
  Assert.AreEqual('a', FList[0].Name);
end;

procedure TTestSavedCommandList.ClearShouldEmptyList;
begin
  FList.Add(MakeCmd('a', '1'));
  FList.Add(MakeCmd('b', '2'));
  FList.Clear;
  Assert.AreEqual(NativeInt(0), NativeInt(FList.Count));
end;

procedure TTestSavedCommandList.AssignShouldCopyItems;
var
  Other: TSavedCommandList;
begin
  Other := TSavedCommandList.Create;
  try
    Other.Add(MakeCmd('x', 'cmd x'));
    Other.Add(MakeCmd('y', 'cmd y'));
    FList.Assign(Other);
    Assert.AreEqual(NativeInt(2), NativeInt(FList.Count));
    Assert.AreEqual('x', FList[0].Name);
    Assert.AreEqual('y', FList[1].Name);
  finally
    Other.Free;
  end;
end;

procedure TTestSavedCommandList.ToJSONAndFromJSONShouldRoundTrip;
var
  JSON: string;
  Restored: TSavedCommandList;
begin
  FList.Add(MakeCmd('build', 'msbuild', scPwsh));
  FList.Add(MakeCmd('clean', 'delphi-clean', scActive));
  JSON := FList.ToJSON;
  Assert.IsTrue(JSON.Contains('"build"'), 'JSON should contain command name');

  Restored := TSavedCommandList.Create;
  try
    Restored.FromJSON(JSON);
    Assert.AreEqual(NativeInt(2), NativeInt(Restored.Count));
    Assert.AreEqual('build', Restored[0].Name);
    Assert.AreEqual('msbuild', Restored[0].Command);
    Assert.IsTrue(Restored[0].ShellType = scPwsh, 'Shell type should be pwsh');
    Assert.AreEqual('clean', Restored[1].Name);
    Assert.IsTrue(Restored[1].ShellType = scActive, 'Shell type should be active');
  finally
    Restored.Free;
  end;
end;

procedure TTestSavedCommandList.FromJSONEmptyStringShouldClear;
begin
  FList.Add(MakeCmd('a', '1'));
  FList.FromJSON('');
  Assert.AreEqual(NativeInt(0), NativeInt(FList.Count));
end;

procedure TTestSavedCommandList.FromJSONMalformedShouldClear;
begin
  FList.Add(MakeCmd('a', '1'));
  FList.FromJSON('not json at all');
  Assert.AreEqual(NativeInt(0), NativeInt(FList.Count));
end;

procedure TTestSavedCommandList.WorkingDirShouldSerialize;
var
  JSON: string;
  Restored: TSavedCommandList;
begin
  FList.Add(MakeCmd('test', 'echo hi', scActive, '${ProjectDir}'));
  JSON := FList.ToJSON;
  Assert.IsTrue(JSON.Contains('workdir'), 'JSON should contain workdir key');

  Restored := TSavedCommandList.Create;
  try
    Restored.FromJSON(JSON);
    Assert.AreEqual('${ProjectDir}', Restored[0].WorkingDir);
  finally
    Restored.Free;
  end;
end;

procedure TTestSavedCommandList.WorkingDirAbsentShouldDeserializeEmpty;
var
  Restored: TSavedCommandList;
begin
  Restored := TSavedCommandList.Create;
  try
    Restored.FromJSON('[{"name":"test","shell":"active","command":"echo hi"}]');
    Assert.AreEqual(NativeInt(1), NativeInt(Restored.Count));
    Assert.AreEqual('', Restored[0].WorkingDir);
  finally
    Restored.Free;
  end;
end;

procedure TTestSavedCommandList.ShellTypeRoundTrip;
begin
  Assert.AreEqual('active', TSavedCommandList.ShellTypeToString(scActive));
  Assert.AreEqual('cmd', TSavedCommandList.ShellTypeToString(scCmd));
  Assert.AreEqual('pwsh', TSavedCommandList.ShellTypeToString(scPwsh));
  Assert.AreEqual('powershell', TSavedCommandList.ShellTypeToString(scPowerShell));
  Assert.IsTrue(TSavedCommandList.StringToShellType('active') = scActive);
  Assert.IsTrue(TSavedCommandList.StringToShellType('cmd') = scCmd);
  Assert.IsTrue(TSavedCommandList.StringToShellType('pwsh') = scPwsh);
  Assert.IsTrue(TSavedCommandList.StringToShellType('powershell') = scPowerShell);
  Assert.IsTrue(TSavedCommandList.StringToShellType('ps') = scPowerShell);
  Assert.IsTrue(TSavedCommandList.StringToShellType('unknown') = scActive);
end;

{ Bundle tests }

const
  CBundleJSON =
    '{"prefix":"cd.","description":"Continuous-Delphi toolchain",' +
    '"commands":[' +
    '{"name":"cd.clean","shell":"pwsh","command":"delphi-clean","workdir":"${ProjectDir}"},' +
    '{"name":"cd.build","shell":"pwsh","command":"Invoke-DelphiBuild"}' +
    ']}';

procedure TTestSavedCommandList.ImportBundleShouldAddCommands;
begin
  FList.ImportBundle(CBundleJSON);
  Assert.AreEqual(NativeInt(2), NativeInt(FList.Count));
  Assert.AreEqual('cd.clean', FList[0].Name);
  Assert.AreEqual('cd.build', FList[1].Name);
end;

procedure TTestSavedCommandList.ImportBundleShouldReplacePrefixMatches;
begin
  FList.Add(MakeCmd('cd.old', 'old command', scPwsh));
  FList.ImportBundle(CBundleJSON);
  // cd.old should be gone, replaced by bundle commands
  Assert.AreEqual(NativeInt(2), NativeInt(FList.Count));
  Assert.AreEqual('cd.clean', FList[0].Name);
  Assert.AreEqual('cd.build', FList[1].Name);
end;

procedure TTestSavedCommandList.ImportBundleShouldNotTouchOtherCommands;
begin
  FList.Add(MakeCmd('my.custom', 'custom cmd'));
  FList.Add(MakeCmd('cd.old', 'old command'));
  FList.ImportBundle(CBundleJSON);
  Assert.AreEqual(NativeInt(3), NativeInt(FList.Count));
  Assert.AreEqual('my.custom', FList[0].Name);
  Assert.AreEqual('cd.clean', FList[1].Name);
  Assert.AreEqual('cd.build', FList[2].Name);
end;

procedure TTestSavedCommandList.DeleteByPrefixShouldRemoveOnlyMatching;
begin
  FList.Add(MakeCmd('cd.a', '1'));
  FList.Add(MakeCmd('other', '2'));
  FList.Add(MakeCmd('cd.b', '3'));
  FList.DeleteByPrefix('cd.');
  Assert.AreEqual(NativeInt(1), NativeInt(FList.Count));
  Assert.AreEqual('other', FList[0].Name);
end;

procedure TTestSavedCommandList.ParseBundlePrefixShouldExtractPrefix;
begin
  Assert.AreEqual('cd.', TSavedCommandList.ParseBundlePrefix(CBundleJSON));
end;

procedure TTestSavedCommandList.ParseBundleDescriptionShouldExtractDescription;
begin
  Assert.AreEqual('Continuous-Delphi toolchain', TSavedCommandList.ParseBundleDescription(CBundleJSON));
end;

procedure TTestSavedCommandList.ImportBundleMalformedShouldDoNothing;
begin
  FList.Add(MakeCmd('keep', 'this'));
  FList.ImportBundle('garbage');
  Assert.AreEqual(NativeInt(1), NativeInt(FList.Count));
  Assert.AreEqual('keep', FList[0].Name);
end;

procedure TTestSavedCommandList.ImportBundleNoPrefixShouldAppend;
begin
  FList.Add(MakeCmd('keep', 'this'));
  FList.ImportBundle('{"commands":[{"name":"x","shell":"active","command":"y"}]}');
  Assert.AreEqual(NativeInt(2), NativeInt(FList.Count));
  Assert.AreEqual('keep', FList[0].Name);
  Assert.AreEqual('x', FList[1].Name);
end;

procedure TTestSavedCommandList.ImportBundleShouldSkipExactDuplicates;
begin
  FList.Add(MakeCmd('build', 'msbuild MyProj.dproj', scPwsh, '${ProjectDir}'));
  FList.Add(MakeCmd('clean', 'delphi-clean', scPwsh));
  FList.ImportBundle(
    '{"commands":[' +
    '{"name":"build","shell":"pwsh","command":"msbuild MyProj.dproj","workdir":"${ProjectDir}"},' +
    '{"name":"clean","shell":"pwsh","command":"delphi-clean"},' +
    '{"name":"test","shell":"cmd","command":"run-tests"}' +
    ']}');
  Assert.AreEqual(NativeInt(3), NativeInt(FList.Count), 'Duplicates should not be added');
  Assert.AreEqual('build', FList[0].Name);
  Assert.AreEqual('clean', FList[1].Name);
  Assert.AreEqual('test', FList[2].Name);
end;

{ ToBundleJSON tests }

procedure TTestSavedCommandList.ToBundleJSONShouldProduceValidBundle;
var
  JSON, Prefix, Desc: string;
begin
  FList.Add(MakeCmd('cd.clean', 'delphi-clean', scPwsh, '${ProjectDir}'));
  FList.Add(MakeCmd('cd.build', 'Invoke-DelphiBuild', scPwsh));
  JSON := FList.ToBundleJSON('cd.', 'Test bundle');
  Prefix := TSavedCommandList.ParseBundlePrefix(JSON);
  Desc := TSavedCommandList.ParseBundleDescription(JSON);
  Assert.AreEqual('cd.', Prefix);
  Assert.AreEqual('Test bundle', Desc);
  Assert.IsTrue(JSON.Contains('"cd.clean"'), 'Should contain cd.clean');
  Assert.IsTrue(JSON.Contains('"cd.build"'), 'Should contain cd.build');
end;

procedure TTestSavedCommandList.ToBundleJSONShouldOnlyIncludePrefixMatches;
var
  JSON: string;
  Restored: TSavedCommandList;
begin
  FList.Add(MakeCmd('cd.clean', 'delphi-clean', scPwsh));
  FList.Add(MakeCmd('my.other', 'other cmd', scCmd));
  FList.Add(MakeCmd('cd.build', 'build cmd', scPwsh));
  JSON := FList.ToBundleJSON('cd.', 'Only cd');
  Restored := TSavedCommandList.Create;
  try
    Restored.ImportBundle(JSON);
    Assert.AreEqual(NativeInt(2), NativeInt(Restored.Count));
    Assert.AreEqual('cd.clean', Restored[0].Name);
    Assert.AreEqual('cd.build', Restored[1].Name);
  finally
    Restored.Free;
  end;
end;

procedure TTestSavedCommandList.ToBundleJSONShouldRoundTripViaImport;
var
  JSON: string;
  Restored: TSavedCommandList;
begin
  FList.Add(MakeCmd('t.alpha', 'echo alpha', scCmd, '${ProjectDir}'));
  FList.Add(MakeCmd('t.beta', 'echo beta', scPwsh));
  JSON := FList.ToBundleJSON('t.', 'Round trip test');
  Restored := TSavedCommandList.Create;
  try
    Restored.ImportBundle(JSON);
    Assert.AreEqual(NativeInt(2), NativeInt(Restored.Count));
    Assert.AreEqual('t.alpha', Restored[0].Name);
    Assert.AreEqual('echo alpha', Restored[0].Command);
    Assert.IsTrue(Restored[0].ShellType = scCmd, 'Shell type should be cmd');
    Assert.AreEqual('${ProjectDir}', Restored[0].WorkingDir);
    Assert.AreEqual('t.beta', Restored[1].Name);
    Assert.AreEqual('echo beta', Restored[1].Command);
    Assert.IsTrue(Restored[1].ShellType = scPwsh, 'Shell type should be pwsh');
    Assert.AreEqual('', Restored[1].WorkingDir);
  finally
    Restored.Free;
  end;
end;

procedure TTestSavedCommandList.ToBundleJSONShouldOmitEmptyWorkDir;
var
  JSON: string;
begin
  FList.Add(MakeCmd('p.test', 'echo test', scActive));
  JSON := FList.ToBundleJSON('p.', 'Test bundle');
  Assert.IsFalse(JSON.Contains('"workdir"'), 'Should not contain workdir key');
end;

procedure TTestSavedCommandList.ToBundleJSONEmptyPrefixShouldExportAll;
var
  JSON: string;
begin
  FList.Add(MakeCmd('cd.clean', 'delphi-clean', scPwsh));
  FList.Add(MakeCmd('my.other', 'other cmd', scCmd));
  FList.Add(MakeCmd('solo', 'solo cmd', scActive));
  JSON := FList.ToBundleJSON('', 'All commands');
  Assert.IsTrue(JSON.Contains('"cd.clean"'), 'Should contain cd.clean');
  Assert.IsTrue(JSON.Contains('"my.other"'), 'Should contain my.other');
  Assert.IsTrue(JSON.Contains('"solo"'), 'Should contain solo');
  Assert.AreEqual('All commands', TSavedCommandList.ParseBundleDescription(JSON));
end;

{ LoadBundleFile tests }

procedure TTestSavedCommandList.LoadBundleFileShouldLoadWithPrefix;
var
  TmpFile: string;
  Loaded: TSavedCommandList;
  Lines: TStringList;
begin
  TmpFile := TPath.GetTempFileName;
  try
    Lines := TStringList.Create;
    try
      Lines.Text := CBundleJSON;
      Lines.SaveToFile(TmpFile, TEncoding.UTF8);
    finally
      Lines.Free;
    end;
    Loaded := TSavedCommandList.LoadBundleFile(TmpFile, 'project:myapp.');
    try
      Assert.AreEqual(NativeInt(2), NativeInt(Loaded.Count));
      Assert.AreEqual('project:myapp.cd.clean', Loaded[0].Name);
      Assert.AreEqual('project:myapp.cd.build', Loaded[1].Name);
      Assert.AreEqual('delphi-clean', Loaded[0].Command);
      Assert.IsTrue(Loaded[0].ShellType = scPwsh, 'Shell type should be pwsh');
      Assert.AreEqual('${ProjectDir}', Loaded[0].WorkingDir);
    finally
      Loaded.Free;
    end;
  finally
    TFile.Delete(TmpFile);
  end;
end;

procedure TTestSavedCommandList.LoadBundleFileMissingFileShouldReturnEmpty;
var
  Loaded: TSavedCommandList;
begin
  Loaded := TSavedCommandList.LoadBundleFile('C:\nonexistent\file.json', 'prefix.');
  try
    Assert.AreEqual(NativeInt(0), NativeInt(Loaded.Count));
  finally
    Loaded.Free;
  end;
end;

procedure TTestSavedCommandList.LoadBundleFileMalformedShouldReturnEmpty;
var
  TmpFile: string;
  Loaded: TSavedCommandList;
  Lines: TStringList;
begin
  TmpFile := TPath.GetTempFileName;
  try
    Lines := TStringList.Create;
    try
      Lines.Text := 'not valid json at all';
      Lines.SaveToFile(TmpFile, TEncoding.UTF8);
    finally
      Lines.Free;
    end;
    Loaded := TSavedCommandList.LoadBundleFile(TmpFile, 'prefix.');
    try
      Assert.AreEqual(NativeInt(0), NativeInt(Loaded.Count));
    finally
      Loaded.Free;
    end;
  finally
    TFile.Delete(TmpFile);
  end;
end;

procedure TTestSavedCommandList.LoadBundleFileEmptyPrefixShouldLoadUnprefixed;
var
  TmpFile: string;
  Loaded: TSavedCommandList;
  Lines: TStringList;
begin
  TmpFile := TPath.GetTempFileName;
  try
    Lines := TStringList.Create;
    try
      Lines.Text := CBundleJSON;
      Lines.SaveToFile(TmpFile, TEncoding.UTF8);
    finally
      Lines.Free;
    end;
    Loaded := TSavedCommandList.LoadBundleFile(TmpFile, '');
    try
      Assert.AreEqual(NativeInt(2), NativeInt(Loaded.Count));
      Assert.AreEqual('cd.clean', Loaded[0].Name);
      Assert.AreEqual('cd.build', Loaded[1].Name);
    finally
      Loaded.Free;
    end;
  finally
    TFile.Delete(TmpFile);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSavedCommandList);

end.
