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

  HPCON = THandle;

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


  /// <summary>Creates a new pseudoconsole object for the calling process.</summary>
  /// <see>https://learn.microsoft.com/en-us/windows/console/createpseudoconsole</see>
  /// <c>
  ///   HRESULT WINAPI CreatePseudoConsole(
  ///     _In_ COORD size,
  ///     _In_ HANDLE hInput,
  ///     _In_ HANDLE hOutput,
  ///     _In_ DWORD dwFlags,
  ///     _Out_ HPCON* phPC
  ///   );
  /// </c>
  TCreatePseudoConsoleFunc = function(size: TCoord;
                                      hInput: THandle;
                                      hOutput: THandle;
                                      dwFlags: DWORD;
                                      out phPC: HPCON): HRESULT; stdcall;

  /// <summary>Resizes the internal buffers for a pseudoconsole to the given size.</summary>
  /// <see>https://learn.microsoft.com/en-us/windows/console/resizepseudoconsole</see>
  /// <c>
  ///   HRESULT WINAPI ResizePseudoConsole(
  ///       _In_ HPCON hPC ,
  ///       _In_ COORD size
  ///   );
  /// </c>
  TResizePseudoConsoleFunc = function(hPC: HPCON; size: TCoord): HRESULT; stdcall;


  /// <summary>Shuts down and releases resources associated with the given pseudoconsole.</summary>
  /// <see>https://learn.microsoft.com/en-us/windows/console/closepseudoconsole</see>
  /// <c>
  ///   void WINAPI ClosePseudoConsole(
  ///       _In_ HPCON hPC
  ///   );
  /// </c>
  TClosePseudoConsoleFunc = procedure(hPC: HPCON); stdcall;


  TConPty = record
  private
    FCreatePseudoConsole: TCreatePseudoConsoleFunc;
    FResizePseudoConsole: TResizePseudoConsoleFunc;
    FClosePseudoConsole: TClosePseudoConsoleFunc;

    procedure DoInitialization;
    procedure DoFinalization;
  public
    function IsAvailable: Boolean;
  end;

var
  gConPty:TConPty;

implementation
uses
  System.SysUtils;


procedure TConPty.DoInitialization;
var
  hModule: HINST;
begin
  Self := Default(TConPty);

  if System.SysUtils.Win32MajorVersion >= 10 then
  begin
    hModule:= GetModuleHandle(WinAPI.Windows.Kernel32);

    FCreatePseudoConsole := TCreatePseudoConsoleFunc(GetProcAddress(hModule, 'CreatePseudoConsole'));
    FResizePseudoConsole := TResizePseudoConsoleFunc(GetProcAddress(hModule, 'ResizePseudoConsole'));
    FClosePseudoConsole := TClosePseudoConsoleFunc(GetProcAddress(hModule, 'ClosePseudoConsole'));
  end;
end;

function TConPty.IsAvailable: Boolean;
begin
  Result := Assigned(FCreatePseudoConsole) and Assigned(FResizePseudoConsole) and Assigned(FClosePseudoConsole);
end;


procedure TConPty.DoFinalization;
begin

end;

initialization
  gConPty.DoInitialization;

finalization
  gConPty.DoFinalization;

end.
