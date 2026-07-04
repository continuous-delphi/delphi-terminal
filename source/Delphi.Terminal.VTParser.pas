(*

  delphi-terminal
  https://github.com/continuous-delphi/delphi-terminal

  Dockable terminal panel for RAD Studio with CMD, pwsh, and PowerShell tabs,
  ANSI color rendering, and command history

  License: MIT
  Copyright (c) 2026 Darian Miller

  ---------------------------------------------------------------------------

  VT / ANSI parser that consumes decoded string chunks (from the ConPTY reader)
  and drives a TScreenBuffer. It is a stateful state machine: escape sequences
  split across chunk boundaries are handled naturally because the parser state
  persists between Parse calls (this is separate from the reader's UTF-8
  boundary buffering).

  This is the M7 core (#63): C0 controls and SGR (attributes / 16 / 256 /
  truecolor). Cursor movement, erase and scroll (#64) and OSC / DEC private
  modes (#65) are consumed harmlessly here and implemented separately.

*)
unit Delphi.Terminal.VTParser;

interface

uses
  Delphi.Terminal.ScreenBuffer;

type
  TVTParserState = (vpsNormal, vpsEscape, vpsCSI, vpsOSC, vpsOSCEsc, vpsCharset);

  TVTParser = class
  private
    FScreen: TScreenBuffer;   // not owned
    FState: TVTParserState;
    FParams: string;          // accumulated CSI parameter/intermediate bytes (excludes the final byte)
    procedure ProcessChar(ACh: Char);
    procedure HandleC0(ACh: Char);
    procedure DispatchCSI(AFinal: Char);
    procedure ApplySGR(const AParams: string);
  public
    constructor Create(AScreen: TScreenBuffer);
    ///<summary>Feeds a decoded chunk through the state machine, mutating the screen.</summary>
    procedure Parse(const AChunk: string);
    ///<summary>Resets the parser state (e.g. when the session restarts).</summary>
    procedure Reset;
  end;

implementation

uses
  System.SysUtils;

const
  ESC = #27;
  BEL = #7;
  TAB_WIDTH = 8;

constructor TVTParser.Create(AScreen: TScreenBuffer);
begin
  inherited Create;
  FScreen := AScreen;
  FState := vpsNormal;
  FParams := '';
end;

procedure TVTParser.Reset;
begin
  FState := vpsNormal;
  FParams := '';
end;

procedure TVTParser.Parse(const AChunk: string);
var
  I: Integer;
begin
  for I := Low(AChunk) to High(AChunk) do
    ProcessChar(AChunk[I]);
end;

procedure TVTParser.HandleC0(ACh: Char);
var
  LNewCol: Integer;
begin
  case ACh of
    #8:  // BS
      if FScreen.CursorCol > 0 then
        FScreen.SetCursor(FScreen.CursorCol - 1, FScreen.CursorRow);
    #9:  // HT -- advance to the next tab stop (multiple of TAB_WIDTH)
      begin
        LNewCol := ((FScreen.CursorCol div TAB_WIDTH) + 1) * TAB_WIDTH;
        if LNewCol > FScreen.Cols - 1 then
          LNewCol := FScreen.Cols - 1;
        FScreen.SetCursor(LNewCol, FScreen.CursorRow);
      end;
    #10: // LF
      FScreen.LineFeed;
    #13: // CR
      FScreen.SetCursor(0, FScreen.CursorRow);
    BEL:
      ; // ignore (a bell notification can be added later)
  else
    ; // other C0 controls are ignored
  end;
end;

procedure TVTParser.ProcessChar(ACh: Char);
begin
  case FState of
    vpsNormal:
      if ACh = ESC then
        FState := vpsEscape
      else if ACh < #$20 then
        HandleC0(ACh)
      else if ACh = #$7F then
        // DEL -- ignore
      else
        FScreen.PutChar(ACh);

    vpsEscape:
      case ACh of
        '[':
          begin
            FParams := '';
            FState := vpsCSI;
          end;
        ']':
          FState := vpsOSC;
        '(', ')', '*', '+':
          FState := vpsCharset;
      else
        FState := vpsNormal;   // unhandled 2-byte escape: consume harmlessly
      end;

    vpsCSI:
      if (ACh >= #$20) and (ACh <= #$3F) then
        FParams := FParams + ACh
      else if (ACh >= #$40) and (ACh <= #$7E) then
      begin
        DispatchCSI(ACh);
        FState := vpsNormal;
      end
      else
      begin
        // Unexpected byte mid-sequence (e.g. a C0 control or ESC): abort the
        // CSI and reprocess the byte in the normal state.
        FState := vpsNormal;
        ProcessChar(ACh);
      end;

    vpsOSC:
      if ACh = BEL then
        FState := vpsNormal          // BEL terminates the OSC string
      else if ACh = ESC then
        FState := vpsOSCEsc;         // maybe an ST (ESC \) terminator
      // otherwise swallow the OSC content (interpreted in #65)

    vpsOSCEsc:
      FState := vpsNormal;           // ST or any other byte ends the OSC

    vpsCharset:
      FState := vpsNormal;           // consume the single charset-designator byte
  end;
end;

procedure TVTParser.DispatchCSI(AFinal: Char);
begin
  case AFinal of
    'm':
      ApplySGR(FParams);
  else
    // Cursor movement / erase / scroll (#64) and DEC private modes (#65) are
    // added separately. Unknown finals are consumed harmlessly.
  end;
end;

procedure TVTParser.ApplySGR(const AParams: string);
var
  LParts: TArray<string>;
  LCodes: TArray<Integer>;
  I, Code: Integer;
  LFg, LBg: TCellColor;
  LStyle: TCellStyle;
begin
  // SGR with no parameters means reset (code 0).
  if AParams = '' then
  begin
    SetLength(LCodes, 1);
    LCodes[0] := 0;
  end
  else
  begin
    LParts := AParams.Split([';']);
    SetLength(LCodes, Length(LParts));
    for I := 0 to High(LParts) do
      LCodes[I] := StrToIntDef(LParts[I], 0);
  end;

  LFg := FScreen.CurrentForeground;
  LBg := FScreen.CurrentBackground;
  LStyle := FScreen.CurrentStyle;

  I := 0;
  while I <= High(LCodes) do
  begin
    Code := LCodes[I];
    case Code of
      0:  begin LFg := DefaultColor; LBg := DefaultColor; LStyle := []; end;
      1:  Include(LStyle, csfBold);
      3:  Include(LStyle, csfItalic);
      4:  Include(LStyle, csfUnderline);
      7:  Include(LStyle, csfInverse);
      22: Exclude(LStyle, csfBold);
      23: Exclude(LStyle, csfItalic);
      24: Exclude(LStyle, csfUnderline);
      27: Exclude(LStyle, csfInverse);
      30..37:   LFg := IndexedColor(Code - 30);
      39:       LFg := DefaultColor;
      40..47:   LBg := IndexedColor(Code - 40);
      49:       LBg := DefaultColor;
      90..97:   LFg := IndexedColor(Code - 90 + 8);
      100..107: LBg := IndexedColor(Code - 100 + 8);
      38:
        if I + 1 <= High(LCodes) then
        begin
          if LCodes[I + 1] = 5 then
          begin
            if I + 2 <= High(LCodes) then
              LFg := IndexedColor(Byte(LCodes[I + 2]));
            Inc(I, 2);
          end
          else if LCodes[I + 1] = 2 then
          begin
            if I + 4 <= High(LCodes) then
              LFg := RGBColor((Cardinal(Byte(LCodes[I + 2])) shl 16) or (Cardinal(Byte(LCodes[I + 3])) shl 8) or Cardinal(Byte(LCodes[I + 4])));
            Inc(I, 4);
          end;
        end;
      48:
        if I + 1 <= High(LCodes) then
        begin
          if LCodes[I + 1] = 5 then
          begin
            if I + 2 <= High(LCodes) then
              LBg := IndexedColor(Byte(LCodes[I + 2]));
            Inc(I, 2);
          end
          else if LCodes[I + 1] = 2 then
          begin
            if I + 4 <= High(LCodes) then
              LBg := RGBColor((Cardinal(Byte(LCodes[I + 2])) shl 16) or (Cardinal(Byte(LCodes[I + 3])) shl 8) or Cardinal(Byte(LCodes[I + 4])));
            Inc(I, 4);
          end;
        end;
    else
      ; // unsupported SGR code -- ignore
    end;
    Inc(I);
  end;

  FScreen.SetAttributes(LFg, LBg, LStyle);
end;

end.
