@echo off
setlocal EnableDelayedExpansion
REM Check for interactive flag
set INTERACTIVE=0
if /i "%~1"=="--interactive" set INTERACTIVE=1
if /i "%~1"=="-i" set INTERACTIVE=1
if /i "%~1"=="/i" set INTERACTIVE=1
pushd "%~dp0"

REM
REM Invoke-DelphiClean found bundled in: https://github.com/continuous-delphi/delphi-powershell-ci
REM or stand-alone in: https://github.com/continuous-delphi/delphi-clean
REM

pwsh -NoProfile -NoLogo -Command ^
  "$ErrorActionPreference = 'Stop'; Invoke-DelphiClean -CleanLevel deep -CleanIncludeFilePattern '*.res'" 

if %ERRORLEVEL% NEQ 0 (
  echo.
  echo Invoke-DelphiClean failed with exit code %ERRORLEVEL%
  if %INTERACTIVE%==1 pause
  exit /b %ERRORLEVEL%
)
popd
echo Success!
if %INTERACTIVE%==1 pause
