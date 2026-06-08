program Delphi.Terminal.Tests;

//--- Begin ConsoleProject template changes
(*
  The "CI" define should be passed to msbuild when building outside the IDE
  /p:DCC_Define="$(DCC_Define);CI"

  This ensures TestInsight runner is not activated in headless environments but
  is maintained for manually running in the IDE without having to add and
  maintain a dedicated Build Config just for CI usage - or externally patching
  the .proj when running CI
*)

{$IFDEF CI}
  {$UNDEF TESTINSIGHT}
{$ENDIF}
//--- End ConsoleProject template changes

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  DUnitX.Loggers.Xml.NUnit,
  {$IFNDEF TESTINSIGHT}
  DUnitX.Loggers.Console,
  {$ENDIF }
  DUnitX.TestFramework,
  Test.Delphi.Terminal.Smoke in 'Test.Delphi.Terminal.Smoke.pas',
  Test.Delphi.Terminal.CmdShell in 'Test.Delphi.Terminal.CmdShell.pas',
  Test.Delphi.Terminal.CommandHistory in 'Test.Delphi.Terminal.CommandHistory.pas',
  Test.Delphi.Terminal.AnsiParser in 'Test.Delphi.Terminal.AnsiParser.pas',
  Delphi.Terminal.CmdShell in '..\source\Delphi.Terminal.CmdShell.pas',
  Delphi.Terminal.CommandHistory in '..\source\Delphi.Terminal.CommandHistory.pas',
  Delphi.Terminal.AnsiParser in '..\source\Delphi.Terminal.AnsiParser.pas',
  Delphi.Terminal.Settings in '..\source\Delphi.Terminal.Settings.pas',
  Delphi.Terminal.SavedCommands in '..\source\Delphi.Terminal.SavedCommands.pas',
  Delphi.Terminal.VariableExpander in '..\source\Delphi.Terminal.VariableExpander.pas',
  Test.Delphi.Terminal.SavedCommands in 'Test.Delphi.Terminal.SavedCommands.pas',
  Test.Delphi.Terminal.VariableExpander in 'Test.Delphi.Terminal.VariableExpander.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.

