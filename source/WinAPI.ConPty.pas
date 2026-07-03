(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

*)
unit WinAPI.ConPty;

interface

uses
  WinAPI.Windows;

type

  (*
  https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-startupinfoexw

  typedef struct _STARTUPINFOEXW {
    STARTUPINFOW                 StartupInfo;
    LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
  } STARTUPINFOEXW, *LPSTARTUPINFOEXW;

  *)
  TStartupInfoExW = record
    StartupInfo: TStartupInfoW;   //https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow
    lpAttributeList: PPROC_THREAD_ATTRIBUTE_LIST;  //https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-initializeprocthreadattributelist
  end;



  type

  (*
  CreatePseudoConsole function

  Creates a new pseudoconsole object for the calling process.

  https://learn.microsoft.com/en-us/windows/console/createpseudoconsole

  HRESULT WINAPI CreatePseudoConsole(
    _In_ COORD size,
    _In_ HANDLE hInput,
    _In_ HANDLE hOutput,
    _In_ DWORD dwFlags,
    _Out_ HPCON* phPC
  );
  *)
  HPCON = THandle;

  TCreatePseudoConsole = function(size: TCoord;
                                  hInput: THandle;
                                  hOutput: THandle;
                                  dwFlags: DWORD;
                                  out phPC: HPCON): HRESULT; stdcall;

  (*
  ResizePseudoConsole function

  Resizes the internal buffers for a pseudoconsole to the given size.

  https://learn.microsoft.com/en-us/windows/console/resizepseudoconsole

  HRESULT WINAPI ResizePseudoConsole(
      _In_ HPCON hPC ,
      _In_ COORD size
  );
  *)


  TConPty = record
    IsAvailable:Boolean;
  end;

var
  gConPty:TConPty;

implementation
uses
  System.SysUtils;


procedure DoInitialization;
var
  hModule: HINST;
begin
  gConPty.IsAvailable := False;

  if System.SysUtils.Win32MajorVersion >= 10 then
  begin
    hModule:= GetModuleHandle(WinAPI.Windows.Kernel32);

    //CreatePseudoConsole := GetProcAddress(hModule, 'CreatePseudoConsole');
    //gConPty.IsAvailable := Assigned(CreatePseudoConsole);

    if gConPty.IsAvailable then
    begin
    end;
  end;
end;


procedure DoFinalization;
begin

end;

initialization
  DoInitialization;

finalization
  DoFinalization;

end.
