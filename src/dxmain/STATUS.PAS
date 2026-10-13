{$F+,G+,S-}
unit Status;

interface

const
  LastSec: Word = 0;
  Blink: Boolean = True;
  CurSec: Word = 0;
  ClockHidden: Boolean = False;
  DateHidden: Boolean = False;
  G36C: Word = 1;
  LastDate: string[25] = 'x';
  LastTime: string[6] = 'x';

type
  Str14 = string[14];

function ShortDate: Str14;
procedure ClockOff;
procedure ClockOn;
procedure DateOff;
procedure DateOn;
function TimeStr: string;
function DateStr: string;
procedure UpdateClock;
procedure Idle;
function GetKey(var Key: Word): Boolean;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Times, U118C, Saver;

function ShortDate: Str14;
var
  Y, M, D, DoW: Word;
begin
  GetDate(Y, M, D, DoW);
  ShortDate := TimeToStr(D, M, Y);
end;

procedure ClockOff;
var
  W: TWinState;
  S: string;
begin
  SaveWin(W);
  ClockHidden := True;
  WriteXYB(StatX, StatY, StatBg, '      ');
  RestoreWin(W);
end;

procedure ClockOn;
var
  W: TWinState;
  S: string;
  T: string[5];
begin
  SaveWin(W);
  ClockHidden := False;
  LastTime := '';
  WriteXYFB(StatX, StatY, StatFg, StatBg, TimeStr);
  RestoreWin(W);
end;

procedure DateOff;
var
  W: TWinState;
  S: string;
  X: Word;
begin
  SaveWin(W);
  DateHidden := True;
  WriteXYB(StatX - 17, StatY, StatBg, Spaces(17));
  RestoreWin(W);
end;

procedure DateOn;
var
  W: TWinState;
  S: string;
  X: Word;
begin
  DateHidden := False;
  LastDate := '';
  Idle;
end;

function TimeStr: string;
var
  H, M, Sec, S100: Word;
  B, A: string;
  Pad: array[1..20] of Byte;
begin
  GetTime(H, M, Sec, S100);
  Str(H, B);
  A := B;
  if Length(A) = 1 then A := ' ' + A;
  Str(M, B);
  if Length(B) = 1 then B := '0' + B;
  B := B + ' ';
  if LastSec <> Sec then Blink := not Blink;
  if Blink then
    TimeStr := A + ':' + B
  else
    TimeStr := A + ' ' + B;
  if LastSec <> Sec then Inc(MouseMoved);
  if (Word(MouseMoved) >= SaverDelay) and SaverOn then ScreenSaver;
  LastSec := Sec;
  CurSec := Sec;
end;

function DateStr: string;
var
  D, M, Y, W: Word;
  S: string;
begin
  GetDate(Y, M, D, W);
  case W of
    0: S := 'So';
    1: S := 'Mo';
    2: S := 'Di';
    3: S := 'Mi';
    4: S := 'Do';
    5: S := 'Fr';
    6: S := 'Sa';
  end;
  DateStr := S + ' ' + TimeToStr(D, M, Y);
end;

procedure UpdateClock;
var
  W: TWinState;
  S: string;
begin
  GetWin(W);
  SetColor(StatFg, StatBg);
  S := DateStr;
  if (LastDate <> S) and not ClockHidden and not DateHidden then
  begin
    MouseHide;
    Window(1, 1, 80, ScreenRows);
    WriteXY(StatX - Length(S) - 1, StatY, S + ' ');
    MouseShow;
    SetWin(W);
  end;
  LastDate := S;
  S := TimeStr;
  if (LastTime <> S) and not ClockHidden then
  begin
    MouseHide;
    Window(1, 1, 80, ScreenRows);
    WriteXY(StatX, StatY, S);
    MouseShow;
    SetWin(W);
  end;
  LastTime := S;
  TextAttr := W.Attr;
end;

procedure Idle;
begin
  UpdateClock;
  if (MouseX = 80) and (MouseY = 1) and (MouseButton = 1) and SaverOn then ScreenSaver;
end;

function GetKey(var Key: Word): Boolean;
var
  R: Registers;
  Ready: Boolean;
  I, K: Word;
  KbdFlags: Byte absolute $40:$17;
begin
  Key := 0;
  R.AH := 1;
  Intr($16, R);
  Ready := R.Flags and FZero > 0;
  if not Ready then
  begin
    R.AH := 0;
    Intr($16, R);
    Key := R.AL;
    ScanCode := R.AH;
    if Key = 0 then Key := R.AH + 1000;
  end;
  GetKey := Key <> 0;
  if Key <> 0 then MouseMoved := 0 else Idle;
  AltDown := KbdFlags and 8 = 8;
  ShiftDown := KbdFlags and 3 <> 0;
  CtrlDown := KbdFlags and 4 = 4;
  if Replay then
  begin
    I := 1;
    repeat
      K := Entries[I].W;
      Inc(I);
    until (I = 101) or (K <> 0);
    if K <> 0 then
    begin
      GetKey := True;
      Key := K;
      AltDown := Entries[I - 1].Alt;
      ShiftDown := Entries[I - 1].Shift;
      CtrlDown := Entries[I - 1].Ctrl;
      ScanCode := Entries[I - 1].Scan;
      Entries[I - 1].W := 0;
      Entries[I - 1].Alt := False;
      Entries[I - 1].Shift := False;
      Entries[I - 1].Ctrl := False;
      Entries[I - 1].Scan := 0;
    end
    else
      Replay := False;
  end;
end;

end.
