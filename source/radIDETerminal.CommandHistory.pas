unit radIDETerminal.CommandHistory;

interface

uses
  System.Classes;

type
  TCommandHistory = class
  private
    FItems: TStringList;
    FIndex: Integer;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ACommand: string);
    function NavigateUp: string;
    function NavigateDown: string;
    procedure ResetPosition;
    property Count: Integer read GetCount;
  end;

implementation

constructor TCommandHistory.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
  FIndex := 0;
end;

destructor TCommandHistory.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TCommandHistory.GetCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TCommandHistory.Add(const ACommand: string);
begin
  if ACommand = '' then
    Exit;
  if (FItems.Count > 0) and (FItems[FItems.Count - 1] = ACommand) then
    Exit;
  FItems.Add(ACommand);
  FIndex := FItems.Count;
end;

function TCommandHistory.NavigateUp: string;
begin
  if FItems.Count = 0 then
    Exit('');
  if FIndex > 0 then
    Dec(FIndex);
  Result := FItems[FIndex];
end;

function TCommandHistory.NavigateDown: string;
begin
  if FItems.Count = 0 then
    Exit('');
  if FIndex < FItems.Count - 1 then
  begin
    Inc(FIndex);
    Result := FItems[FIndex];
  end
  else
  begin
    FIndex := FItems.Count;
    Result := '';
  end;
end;

procedure TCommandHistory.ResetPosition;
begin
  FIndex := FItems.Count;
end;

end.
