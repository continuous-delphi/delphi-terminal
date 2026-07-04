(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Self-contained declarations for the Windows Pseudo Console (ConPTY) API and
  the process-thread attribute-list functions it depends on.

  These are declared here rather than taken from WinAPI.Windows on purpose:

    - The ConPTY functions (CreatePseudoConsole / ResizePseudoConsole /
      ClosePseudoConsole) are not declared by WinAPI.Windows in any supported
      version, and only exist at runtime on Windows 10 1809+.

    - The attribute-list functions (Initialize/Update/DeleteProcThreadAttributeList)
      DO exist at runtime back to Windows Vista, but the WinAPI.Windows
      *declarations* for them differ across compiler versions (absent in XE6,
      record-by-value in 10.2-11, pointer overloads in 12+). Binding our own
      function-pointer types to the kernel32 exports gives one stable signature
      that compiles identically on XE6 through the latest release.

  Only the volatile declarations live here. Stable primitives (THandle, DWORD,
  HRESULT, BOOL, TCoord, TStartupInfoW, SIZE_T, PSIZE_T, DWORD_PTR) are reused
  from WinAPI.Windows, which declares them consistently on every target.

  The actual dynamic loading and call wrappers live in Delphi.Terminal.Pty.

*)
unit WinAPI.ConPty;

interface

uses
  WinAPI.Windows;

const
  ///<summary>Attribute value used with UpdateProcThreadAttribute to associate a pseudoconsole with a child process.</summary>
  ///<remarks>Not declared by WinAPI.Windows in any supported version.</remarks>
  PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = $00020016;

  ///<summary>dwFlags value for CreatePseudoConsole: inherit the cursor position of the calling console.</summary>
  PSEUDOCONSOLE_INHERIT_CURSOR = $00000001;

{$IF not Declared(EXTENDED_STARTUPINFO_PRESENT)}
  // Present in WinAPI.Windows on 12+, absent prior
  EXTENDED_STARTUPINFO_PRESENT = $00080000;
{$IFEND}

type

  ///<summary>Handle to a pseudoconsole.</summary>
  HPCON = THandle;
  PHPCON = ^HPCON;

  ///<summary>Opaque pointer to a process-thread attribute list.</summary>
  ///<remarks>Declared locally as an untyped pointer so the signatures below are independent of the WinAPI.Windows version, which does not declare this type on XE6.</remarks>
  ///https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-initializeprocthreadattributelist
  LPPROC_THREAD_ATTRIBUTE_LIST = type Pointer;

  (*
    https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-startupinfoexw

    typedef struct _STARTUPINFOEXW {
      STARTUPINFOW                 StartupInfo;
      LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
    } STARTUPINFOEXW, *LPSTARTUPINFOEXW;
  *)
  TStartupInfoExW = record
    StartupInfo: TStartupInfoW;                    // https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow
    lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  end;
  PStartupInfoExW = ^TStartupInfoExW;


  ///<summary>Creates a new pseudoconsole object for the calling process.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/console/createpseudoconsole</see>
  ///<c>
  ///  HRESULT WINAPI CreatePseudoConsole(    If this method succeeds, it returns S_OK. Otherwise, it returns an HRESULT error code.
  ///    _In_ COORD size,                     The dimensions of the window/buffer in count of characters that will be used on initial creation of the pseudoconsole. This can be adjusted later with ResizePseudoConsole.
  ///    _In_ HANDLE hInput,                  An open handle to a stream of data that represents user input to the device. This is currently restricted to synchronous I/O.
  ///    _In_ HANDLE hOutput,                 An open handle to a stream of data that represents application output from the device. This is currently restricted to synchronous I/O.
  ///    _In_ DWORD dwFlags,                  The value can be one of the following: 0	Perform a standard pseudoconsole creation.   PSEUDOCONSOLE_INHERIT_CURSOR (DWORD)	The created pseudoconsole session will attempt to inherit the cursor position of the parent console.
  ///    _Out_ HPCON* phPC                    Pointer to a location that will receive a handle to the new pseudoconsole device.
  ///  );
  ///</c>
  TCreatePseudoConsoleFunc = function(size: TCoord;
                                      hInput: THandle;
                                      hOutput: THandle;
                                      dwFlags: DWORD;
                                      out phPC: HPCON): HRESULT; stdcall;

  ///<summary>Resizes the internal buffers for a pseudoconsole to the given size.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/console/resizepseudoconsole</see>
  ///<c>
  ///  HRESULT WINAPI ResizePseudoConsole(
  ///      _In_ HPCON hPC ,
  ///      _In_ COORD size
  ///  );
  ///</c>
  TResizePseudoConsoleFunc = function(hPC: HPCON; size: TCoord): HRESULT; stdcall;


  ///<summary>Shuts down and releases resources associated with the given pseudoconsole.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/console/closepseudoconsole</see>
  ///<c>
  ///  void WINAPI ClosePseudoConsole(
  ///      _In_ HPCON hPC
  ///  );
  ///</c>
  TClosePseudoConsoleFunc = procedure(hPC: HPCON); stdcall;


  ///<summary>Allocates and initializes a list of attributes for process and thread creation.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-initializeprocthreadattributelist</see>
  ///<remarks>Call once with lpAttributeList = nil to obtain the required size in lpSize, then again with an allocated buffer.</remarks>
  ///<c>
  ///  BOOL InitializeProcThreadAttributeList(
  ///    _Out_opt_ LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList,
  ///    _In_ DWORD dwAttributeCount,
  ///    _Reserved_ DWORD dwFlags,
  ///    _Inout_ PSIZE_T lpSize
  ///  );
  ///</c>
  TInitializeProcThreadAttributeListFunc = function(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
                                                    dwAttributeCount: DWORD;
                                                    dwFlags: DWORD;
                                                    lpSize: PSIZE_T): BOOL; stdcall;

  ///<summary>Updates the specified attribute in a list of attributes for process and thread creation.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute</see>
  ///<remarks>lpReturnSize may be nil.</remarks>
  ///<c>
  ///  BOOL UpdateProcThreadAttribute(
  ///    _Inout_ LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList,
  ///    _In_ DWORD dwFlags,
  ///    _In_ DWORD_PTR Attribute,
  ///    _In_ PVOID lpValue,
  ///    _In_ SIZE_T cbSize,
  ///    _Out_opt_ PVOID lpPreviousValue,
  ///    _In_opt_ PSIZE_T lpReturnSize
  ///  );
  ///</c>
  TUpdateProcThreadAttributeFunc = function(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
                                            dwFlags: DWORD;
                                            Attribute: DWORD_PTR;
                                            lpValue: Pointer;
                                            cbSize: SIZE_T;
                                            lpPreviousValue: Pointer;
                                            lpReturnSize: PSIZE_T): BOOL; stdcall;

  ///<summary>Deletes the specified list of attributes for process and thread creation.</summary>
  ///<see>https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-deleteprocthreadattributelist</see>
  ///<c>
  ///  void DeleteProcThreadAttributeList(
  ///    _Inout_ LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList
  ///  );
  ///</c>
  TDeleteProcThreadAttributeListFunc = procedure(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST); stdcall;


  TConPtyAPI = record
  public
    CreatePseudoConsole: TCreatePseudoConsoleFunc;
    ResizePseudoConsole: TResizePseudoConsoleFunc;
    ClosePseudoConsole: TClosePseudoConsoleFunc;
    InitializeProcThreadAttributeList: TInitializeProcThreadAttributeListFunc;
    UpdateProcThreadAttribute: TUpdateProcThreadAttributeFunc;
    DeleteProcThreadAttributeList: TDeleteProcThreadAttributeListFunc;

    function Initialize: Boolean;
    function IsAvailable: Boolean;
  end;


implementation
uses
  System.SysUtils;


function TConPtyAPI.Initialize: Boolean;
var
  hModule: HINST;
begin
  Self := Default(TConPtyAPI);

  if System.SysUtils.Win32MajorVersion >= 10 then
  begin
    hModule:= GetModuleHandle(WinAPI.Windows.Kernel32);

    CreatePseudoConsole := TCreatePseudoConsoleFunc(GetProcAddress(hModule, 'CreatePseudoConsole'));
    ResizePseudoConsole := TResizePseudoConsoleFunc(GetProcAddress(hModule, 'ResizePseudoConsole'));
    ClosePseudoConsole := TClosePseudoConsoleFunc(GetProcAddress(hModule, 'ClosePseudoConsole'));
    InitializeProcThreadAttributeList := TInitializeProcThreadAttributeListFunc(GetProcAddress(hModule, 'InitializeProcThreadAttributeList'));
    UpdateProcThreadAttribute := TUpdateProcThreadAttributeFunc(GetProcAddress(hModule, 'UpdateProcThreadAttribute'));
    DeleteProcThreadAttributeList := TDeleteProcThreadAttributeListFunc(GetProcAddress(hModule, 'DeleteProcThreadAttributeList'));
  end;

  Result := IsAvailable;
end;


function TConPtyAPI.IsAvailable: Boolean;
begin
  Result := Assigned(CreatePseudoConsole) and
            Assigned(ResizePseudoConsole) and
            Assigned(ClosePseudoConsole) and
            Assigned(InitializeProcThreadAttributeList) and
            Assigned(UpdateProcThreadAttribute) and
            Assigned(DeleteProcThreadAttributeList);
end;

end.
