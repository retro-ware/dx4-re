{$O+,F+,G+,S-,I-,X+,V-}
unit Pickers;

interface

type
  Str12 = string[12];

function PickDate(X, Y, Ht, Bg: Byte; Year, Month, Day: Word; var S: Str12): Boolean;
function PickTime(X, Y, Ht, Bg: Byte; Minute: Word; var S: Str12): Boolean;
procedure PickSize(X, Y, Ht, Bg: Byte; var S: Str12);

implementation

uses Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Lists, U1439;

type
  TDateList = object(TList)
    Year: Integer;
    procedure DrawLine(Line: Integer); virtual;
  end;

  TTimeList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

  TSizeList = object(TList)
    Value: string[12];
    procedure DrawLine(Line: Integer); virtual;
  end;

procedure TDateList.DrawLine(Line: Integer);
var
  Dummy: string[7];
  B: Byte;
  S: string[4];
  M, D: Word;
begin
  DayNoToDate(Line + Top, Year, M, D);
  Str(Year, S);
  Text := ' ' + LeadZero(D) + '.' + LeadZero(M) + '.' + S;
  TList.DrawLine(Line);
end;

function PickDate(X, Y, Ht, Bg: Byte; Year, Month, Day: Word; var S: Str12): Boolean;
var
  List: TDateList;
  Key: Word;
  A: string[9];
  DayNo: Word;
  B: string[13];
begin
  MouseHide;
  PushScreen(DlgStack);
  PickDate := False;
  OpenFrame(X - 1, Y - 1, 13, Ht, 0, Bg);
  List.Year := Year;
  List.Init(0, 3, 0, 2, X, Y, Ht, DaysInYear(Year), 12, True);
  DateToDayNo(Year, Month, Day, A, DayNo, B);
  List.SetPos(DayNo, 3);
  MouseShow;
  repeat Idle until MouseButton = 0;
  repeat
    GetKey(Key);
    List.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(X, X + 12, Y - 1, Y + Ht);
  PopScreen(DlgStack);
  if Key = 13 then
  begin
    Delete(List.Text, 1, 1);
    S := List.Text;
    PickDate := True;
  end;
  List.Done;
end;

procedure TTimeList.DrawLine(Line: Integer);
var
  S: string[13];
  H, M: Word;
begin
  H := (Line + Top - 1) div 60;
  M := (Line + Top - 1) mod 60;
  Text := ' ' + LeadZero(H) + ':' + LeadZero(M) + ':00';
  TList.DrawLine(Line);
end;

function PickTime(X, Y, Ht, Bg: Byte; Minute: Word; var S: Str12): Boolean;
var
  List: TTimeList;
  Key: Word;
begin
  MouseHide;
  PushScreen(DlgStack);
  PickTime := False;
  OpenFrame(X - 1, Y - 1, 11, Ht, 0, Bg);
  List.Init(0, 3, 0, 2, X, Y, Ht, 1440, 10, True);
  List.SetPos(Minute + 1, 3);
  MouseShow;
  repeat Idle until MouseButton = 0;
  repeat
    GetKey(Key);
    List.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(X, X + 10, Y - 1, Y + Ht);
  PopScreen(DlgStack);
  if Key = 13 then
  begin
    Delete(List.Text, 1, 1);
    S := List.Text;
    PickTime := True;
  end;
  List.Done;
end;

procedure TSizeList.DrawLine(Line: Integer);
begin
  case Line + Top of
    1: Text := '      1';
    2: Text := '     10';
    3: Text := '     20';
    4: Text := '     50';
    5: Text := '    128';
    6: Text := '    512';
    7: Text := '   1 KB';
    8: Text := '   2 KB';
    9: Text := '   5 KB';
    10: Text := '  10 KB';
    11: Text := '  20 KB';
    12: Text := '  50 KB';
    13: Text := ' 100 KB';
    14: Text := ' 200 KB';
    15: Text := ' 500 KB';
    16: Text := '   1 MB';
    17: Text := '   2 MB';
    18: Text := '   5 MB';
    19: Text := '  10 MB';
    20: Text := '  20 MB';
    21: Text := '  30 MB';
    22: Text := '  40 MB';
    23: Text := '  50 MB';
    24: Text := ' 100 MB';
  end;
  if Cur = Line then
    case Line + Top of
      1: Value := '1';
      2: Value := '10';
      3: Value := '20';
      4: Value := '50';
      5: Value := '128';
      6: Value := '512';
      7: Value := '1024';
      8: Value := '2048';
      9: Value := '5120';
      10: Value := '10240';
      11: Value := '20480';
      12: Value := '51200';
      13: Value := '102400';
      14: Value := '204800';
      15: Value := '512000';
      16: Value := '1048576';
      17: Value := '2097152';
      18: Value := '5242880';
      19: Value := '10485760';
      20: Value := '20971520';
      21: Value := '31457280';
      22: Value := '41943040';
      23: Value := '52428800';
      24: Value := '104857600';
    end;
  TList.DrawLine(Line);
end;

procedure PickSize(X, Y, Ht, Bg: Byte; var S: Str12);
var
  List: TSizeList;
  Key: Word;
begin
  OpenDialog;
  OpenFrame(X - 1, Y - 1, 9, Ht, 0, Bg);
  List.Init(2, 3, 2, 0, X, Y, Ht, 24, 8, True);
  MouseShow;
  WaitRelease;
  repeat
    GetKey(Key);
    List.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(X, X + 8, Y - 1, Y + Ht);
  PopScreen(DlgStack);
  if Key = 13 then
  begin
    Delete(List.Text, 1, 1);
    S := List.Value;
  end;
  List.Done;
end;

end.
