(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  Shared text-decoding helpers used by the pipe readers (legacy pipe backend
  and the ConPTY backend). Kept dependency-free so both can use it.

*)
unit Delphi.Terminal.TextDecode;

interface

uses
  System.SysUtils;

///<summary>
///  Returns the length of the largest prefix of ABytes[0..ALen-1] that ends on a
///  complete UTF-8 sequence. If the buffer ends mid-sequence (a multi-byte
///  character split across a read boundary), the returned length excludes the
///  trailing partial bytes so the caller can hold them over and prepend them to
///  the next read.
///</summary>
function CompleteUTF8Length(const ABytes: TBytes; ALen: Integer): Integer;

implementation

function CompleteUTF8Length(const ABytes: TBytes; ALen: Integer): Integer;
var
  I, ExpectedLen: Integer;
  B: Byte;
begin
  Result := ALen;
  if ALen = 0 then
    Exit;
  for I := 1 to 3 do
  begin
    if I > ALen then
      Break;
    B := ABytes[ALen - I];
    if B and $80 = 0 then
      Exit(ALen)
    else if B and $C0 <> $80 then
    begin
      if B and $E0 = $C0 then ExpectedLen := 2
      else if B and $F0 = $E0 then ExpectedLen := 3
      else if B and $F8 = $F0 then ExpectedLen := 4
      else Exit(ALen);
      if I < ExpectedLen then
        Exit(ALen - I)
      else
        Exit(ALen);
    end;
  end;
end;

end.
