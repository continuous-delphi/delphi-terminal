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

  TVTTitleEvent = procedure(Sender: TObject; const ATitle: string) of object;

  TVTParser = class
  private
    FScreen: TScreenBuffer;   // not owned
    FState: TVTParserState;
    FParams: string;          // accumulated CSI parameter/intermediate bytes (excludes the final byte)
    FSavedCol: Integer;
    FSavedRow: Integer;
    FSavedFg: TCellColor;
    FSavedBg: TCellColor;
    FSavedStyle: TCellStyle;
    FTitle: string;
    FOSCBuffer: string;
    FOnTitleChanged: TVTTitleEvent;
    procedure ProcessChar(ACh: Char);
    procedure HandleC0(ACh: Char);
    procedure DispatchCSI(AFinal: Char);
    procedure ApplySGR(const AParams: string);
    procedure SaveCursor;
    procedure RestoreCursor;
    function ParseParams(const AParams: string): TArray<Integer>;
    function Param(const ACodes: TArray<Integer>; AIndex, ADefault: Integer): Integer;
    procedure DispatchOSC(const AData: string);
    procedure DispatchPrivateMode(AFinal: Char);
    procedure SetTitle(const ATitle: string);
  public
    constructor Create(AScreen: TScreenBuffer);
    ///<summary>Feeds a decoded chunk through the state machine, mutating the screen.</summary>
    procedure Parse(const AChunk: string);
    ///<summary>Resets the parser state (e.g. when the session restarts).</summary>
    procedure Reset;
    property Title: string read FTitle;
    property OnTitleChanged: TVTTitleEvent read FOnTitleChanged write FOnTitleChanged;
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
  FSavedCol := 0;
  FSavedRow := 0;
  FSavedFg := DefaultColor;
  FSavedBg := DefaultColor;
  FSavedStyle := [];
  FTitle := '';
  FOSCBuffer := '';
end;

procedure TVTParser.Reset;
begin
  FState := vpsNormal;
  FParams := '';
  FOSCBuffer := '';
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
          begin
            FOSCBuffer := '';
            FState := vpsOSC;
          end;
        '(', ')', '*', '+':
          FState := vpsCharset;
        'D':   // IND -- index (line feed)
          begin FScreen.LineFeed; FState := vpsNormal; end;
        'M':   // RI -- reverse index
          begin FScreen.ReverseLineFeed; FState := vpsNormal; end;
        'E':   // NEL -- next line (CR + LF)
          begin FScreen.LineFeed; FScreen.SetCursor(0, FScreen.CursorRow); FState := vpsNormal; end;
        '7':   // DECSC -- save cursor
          begin SaveCursor; FState := vpsNormal; end;
        '8':   // DECRC -- restore cursor
          begin RestoreCursor; FState := vpsNormal; end;
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
      begin
        DispatchOSC(FOSCBuffer);
        FState := vpsNormal;
      end
      else if ACh = ESC then
        FState := vpsOSCEsc            // possible ST (ESC \) terminator
      else
        FOSCBuffer := FOSCBuffer + ACh;

    vpsOSCEsc:
      begin
        DispatchOSC(FOSCBuffer);
        FState := vpsNormal;
        if ACh <> '\' then
          ProcessChar(ACh);           // not an ST terminator: reprocess the byte
      end;

    vpsCharset:
      FState := vpsNormal;           // consume the single charset-designator byte
  end;
end;

procedure TVTParser.SaveCursor;
begin
  FSavedCol := FScreen.CursorCol;
  FSavedRow := FScreen.CursorRow;
  FSavedFg := FScreen.CurrentForeground;
  FSavedBg := FScreen.CurrentBackground;
  FSavedStyle := FScreen.CurrentStyle;
end;

procedure TVTParser.RestoreCursor;
begin
  FScreen.SetCursor(FSavedCol, FSavedRow);
  FScreen.SetAttributes(FSavedFg, FSavedBg, FSavedStyle);
end;

function TVTParser.ParseParams(const AParams: string): TArray<Integer>;
var
  LParts: TArray<string>;
  I: Integer;
begin
  if AParams = '' then
    Exit(nil);
  LParts := AParams.Split([';']);
  SetLength(Result, Length(LParts));
  for I := 0 to High(LParts) do
    Result[I] := StrToIntDef(LParts[I], 0);
end;

function TVTParser.Param(const ACodes: TArray<Integer>; AIndex, ADefault: Integer): Integer;
begin
  if (AIndex >= 0) and (AIndex <= High(ACodes)) then
    Result := ACodes[AIndex]
  else
    Result := ADefault;
end;

procedure TVTParser.SetTitle(const ATitle: string);
begin
  FTitle := ATitle;
  if Assigned(FOnTitleChanged) then
    FOnTitleChanged(Self, FTitle);
end;

procedure TVTParser.DispatchOSC(const AData: string);
var
  LSep: Integer;
  LPs: string;
  LArg: string;
begin
  // OSC form is "Ps ; Pt". Ps 0 (icon + title) and 2 (title) set the window title.
  LSep := Pos(';', AData);
  if LSep = 0 then
    Exit;
  LPs := Copy(AData, 1, LSep - 1);
  if (LPs = '0') or (LPs = '2') then
  begin
    SetTitle(Copy(AData, LSep + 1, MaxInt));
    Exit;
  end;
  if LPs = '133' then
  begin
    // OSC 133 ; <A|B|C|D> [; ...] -- FinalTerm/iTerm2 semantic prompt markers used
    // for shell integration: A prompt start, B command-input start, C command
    // executed, D command finished. Drives the screen model's prompt state (the
    // "safe to inject" idle gate); any trailing params (e.g. D's exit code) are ignored.
    LArg := Copy(AData, LSep + 1, MaxInt);
    if LArg <> '' then
      case LArg[Low(LArg)] of
        'A': FScreen.PromptState := spsPromptStart;
        'B': FScreen.PromptState := spsCommandInput;
        'C': FScreen.PromptState := spsExecuting;
        'D': FScreen.PromptState := spsCommandFinished;
      end;
  end;
end;

procedure TVTParser.DispatchPrivateMode(AFinal: Char);
var
  LSet: Boolean;
  LCodes: TArray<Integer>;
  I: Integer;
begin
  if (AFinal <> 'h') and (AFinal <> 'l') then
    Exit;   // only set (h) and reset (l) are handled
  LSet := (AFinal = 'h');
  LCodes := ParseParams(Copy(FParams, 2, MaxInt));   // strip the leading '?'
  for I := 0 to High(LCodes) do
    case LCodes[I] of
      25:
        FScreen.CursorVisible := LSet;
      2004:
        FScreen.BracketedPaste := LSet;
      47, 1047, 1049:
        if LSet then
          FScreen.EnterAltScreen
        else
          FScreen.ExitAltScreen;
    end;
end;

procedure TVTParser.DispatchCSI(AFinal: Char);
var
  LCodes: TArray<Integer>;
  LCount, LRow, LCol, LTop, LBottom: Integer;
begin
  // CSI ? ... are DEC private-mode sequences.
  if FParams.StartsWith('?') then
  begin
    DispatchPrivateMode(AFinal);
    Exit;
  end;

  LCodes := ParseParams(FParams);
  case AFinal of
    'm':
      ApplySGR(FParams);
    'A':   // CUU -- cursor up
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.SetCursor(FScreen.CursorCol, FScreen.CursorRow - LCount);
      end;
    'B':   // CUD -- cursor down
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.SetCursor(FScreen.CursorCol, FScreen.CursorRow + LCount);
      end;
    'C':   // CUF -- cursor forward
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.SetCursor(FScreen.CursorCol + LCount, FScreen.CursorRow);
      end;
    'D':   // CUB -- cursor back
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.SetCursor(FScreen.CursorCol - LCount, FScreen.CursorRow);
      end;
    'G':   // CHA -- cursor horizontal absolute (1-based column)
      begin
        LCol := Param(LCodes, 0, 1); if LCol < 1 then LCol := 1;
        FScreen.SetCursor(LCol - 1, FScreen.CursorRow);
      end;
    'd':   // VPA -- vertical position absolute (1-based row)
      begin
        LRow := Param(LCodes, 0, 1); if LRow < 1 then LRow := 1;
        FScreen.SetCursor(FScreen.CursorCol, LRow - 1);
      end;
    'H', 'f':   // CUP / HVP -- cursor position (1-based row;col)
      begin
        LRow := Param(LCodes, 0, 1); if LRow < 1 then LRow := 1;
        LCol := Param(LCodes, 1, 1); if LCol < 1 then LCol := 1;
        FScreen.SetCursor(LCol - 1, LRow - 1);
      end;
    'J':   // ED -- erase in display
      FScreen.EraseInDisplay(Param(LCodes, 0, 0));
    'K':   // EL -- erase in line
      FScreen.EraseInLine(Param(LCodes, 0, 0));
    'S':   // SU -- scroll up
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.ScrollUp(LCount);
      end;
    'T':   // SD -- scroll down
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.ScrollDown(LCount);
      end;
    'r':   // DECSTBM -- set top/bottom scroll margins (1-based); homes the cursor
      begin
        if Length(LCodes) = 0 then
          FScreen.SetScrollRegion(0, FScreen.Rows - 1)
        else
        begin
          LTop := Param(LCodes, 0, 1); if LTop < 1 then LTop := 1;
          LBottom := Param(LCodes, 1, FScreen.Rows); if LBottom < 1 then LBottom := FScreen.Rows;
          FScreen.SetScrollRegion(LTop - 1, LBottom - 1);
        end;
        FScreen.SetCursor(0, 0);
      end;
    's':   // SCP -- save cursor position
      SaveCursor;
    'u':   // RCP -- restore cursor position
      RestoreCursor;
    'X':   // ECH -- erase characters in place
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.EraseChars(LCount);
      end;
    '@':   // ICH -- insert blank characters
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.InsertChars(LCount);
      end;
    'P':   // DCH -- delete characters
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.DeleteChars(LCount);
      end;
    'L':   // IL -- insert lines
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.InsertLines(LCount);
      end;
    'M':   // DL -- delete lines
      begin
        LCount := Param(LCodes, 0, 1); if LCount < 1 then LCount := 1;
        FScreen.DeleteLines(LCount);
      end;
  else
    // unknown final byte: consume harmlessly
  end;
end;

procedure TVTParser.ApplySGR(const AParams: string);
var
  LCodes: TArray<Integer>;
  I, Code: Integer;
  LFg, LBg: TCellColor;
  LStyle: TCellStyle;
begin
  LCodes := ParseParams(AParams);
  if Length(LCodes) = 0 then
  begin
    SetLength(LCodes, 1);
    LCodes[0] := 0;   // SGR with no parameters means reset
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
