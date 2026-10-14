{$F+,G+,S-,V-}
unit Screen;

interface

uses Dos, Crt;

const
  AltDown: Boolean = False;
  ShiftDown: Boolean = False;
  CtrlDown: Boolean = False;
  ScanCode: Byte = 0;
  BarLen: Integer = 0;

type
  Str12 = string[12];

procedure DelBackslash(var S: string);
procedure AddBackslash(var S: string);
function MakeDir(Path: PathStr): Boolean;
function LeadZero(N: Integer): string;
function HasWildcards(S: string): Boolean;
function FormatNum(N: Longint): Str12;
function DriveValid(Drive: Char): Boolean;
function Spaces(N: Integer): string;
function FillStr(C: Char; N: Byte): string;
procedure ClearBar(X, Y: Byte);
procedure ShowBar(Color: Byte; Pct: Integer; X, Y: Byte);
function GetKey(var Key: Word): Boolean;
function PeekKey(var Key: Word): Boolean;
procedure SetColor(Fg, Bg: Byte);
procedure WriteXY(X, Y: Byte; S: string);
procedure WriteFB(Fg, Bg: Byte; S: string);
procedure WriteXYF(X, Y, Fg: Byte; S: string);
procedure WriteF(Fg: Byte; S: string);
procedure WriteB(Bg: Byte; S: string);
procedure WriteXYB(X, Y, Bg: Byte; S: string);
procedure WriteXYFB(X, Y, Fg, Bg: Byte; S: string);
function Center(S: string; W: Byte): string;
procedure WriteCenter(W: Byte; S: string);
procedure WriteCenterXY(X, Y, W: Byte; S: string);
procedure WriteCenterXYF(X, Y, W, Fg: Byte; S: string);
procedure WriteCenterXYFB(X, Y, W, Fg, Bg: Byte; S: string);
procedure SetBorder(Color: Byte);
function PadRight(S: string; N: Byte): string;
function StripSpaces(S: string): string;
function Trim(S: string): string;
function LowerStr(S: string): string;
function UpperStr(S: string): string;
function UpCaseC(C: Char): Char;
function LoCaseW(W: Word): Char;
function LoCase(C: Char): Char;
function UpCaseW(W: Word): Word;
function DirExists(S: string): Boolean;

implementation

const
  Blank = '                                                                ' +
          '                                                                ' +
          '                                                                ' +
          '                                                               ';

procedure DelBackslash(var S: string);
var
  L: Byte;
begin
  L := Length(S);
  if S[L] = '\' then Delete(S, L, 1);
end;

procedure AddBackslash(var S: string);
begin
  if S[Length(S)] <> '\' then S := S + '\';
end;

{$I-}
function MakeDir(Path: PathStr): Boolean;
var
  S, T: PathStr;
  I: Byte;
  Dummy: Boolean;
begin
  MakeDir := False;
  if Path = '' then Exit;
  Path := Trim(Path);
  Dummy := False;
  if Pos('\', Path) = 0 then
  begin
    MkDir(Path);
    MakeDir := IOResult = 0;
  end
  else
  begin
    AddBackslash(Path);
    I := 0;
    S := '';
    if Path[2] = ':' then
    begin
      S := Copy(Path, 1, 3);
      I := 3;
    end;
    repeat
      repeat
        Inc(I);
        S := S + Path[I];
      until (Path[I] = '\') or (I >= Length(Path));
      if I < Length(Path) then
      begin
        T := Copy(S, 1, Length(S) - 1);
        MkDir(Copy(S, 1, Length(S) - 1));
        InOutRes := 0;
      end;
    until I >= Length(Path);
    DelBackslash(Path);
    MkDir(Path);
    MakeDir := IOResult = 0;
  end;
end;

{$I+}
function LeadZero(N: Integer): string;
var
  S: string;
begin
  Str(N, S);
  if N < 10 then S := '0' + S;
  LeadZero := S;
end;

function HasWildcards(S: string): Boolean;
begin
  HasWildcards := (Pos('*', S) > 0) or (Pos('?', S) > 0);
end;

function FormatNum(N: Longint): Str12;
var
  I: Byte;
  S, T: Str12;
  Dummy: Word;
begin
  if N = 0 then
    FormatNum := '           0'
  else
  begin
    Str(N:12, S);
    T := S;
    if N > 999 then T := Copy(S, 2, 8) + '.' + Copy(S, 10, 3);
    if N > 999999 then T := Copy(T, 2, 4) + '.' + Copy(T, 6, 7);
    FormatNum := T;
  end;
end;

function DriveValid(Drive: Char): Boolean; assembler;
asm
        mov     ah,19h
        int     21h
        mov     bl,al
        mov     dl,Drive
        sub     dl,'A'
        mov     ah,0Eh
        int     21h
        mov     ah,19h
        int     21h
        mov     cx,0
        cmp     al,dl
        jne     @1
        mov     cx,1
        mov     dl,bl
        mov     ah,0Eh
        int     21h
@1:     xchg    ax,cx
end;

function Spaces(N: Integer): string;
begin
  Spaces := Copy(Blank, 1, N);
end;

function FillStr(C: Char; N: Byte): string;
var
  S: string;
begin
  FillChar(S[1], N, C);
  S[0] := Chr(N);
  FillStr := S;
end;

procedure ClearBar(X, Y: Byte);
var
  I, OX, OY: Integer;
begin
  OX := WhereX;
  OY := WhereY;
  GotoXY(X, Y);
  for I := 1 to BarLen do Write(#$B0);
  GotoXY(OX, OY);
end;

procedure ShowBar(Color: Byte; Pct: Integer; X, Y: Byte);
var
  I, OX, OY: Integer;
  A: Byte;
begin
  OX := WhereX;
  OY := WhereY;
  A := TextAttr;
  GotoXY(X, Y);
  Pct := BarLen * Pct div 100;
  if Pct > BarLen then Pct := BarLen;
  TextColor(Color);
  for I := 1 to Pct do Write(#$DB);
  GotoXY(OX, OY);
  TextAttr := A;
end;

function GetKey(var Key: Word): Boolean;
var
  R: Registers;
  Ready: Boolean;
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
  if KbdFlags and 8 = 8 then AltDown := True else AltDown := False;
  if KbdFlags and 3 <> 0 then ShiftDown := True else ShiftDown := False;
  if KbdFlags and 4 = 4 then CtrlDown := True else CtrlDown := False;
end;

function PeekKey(var Key: Word): Boolean;
var
  R: Registers;
  Ready: Boolean;
  KbdFlags: Byte absolute $40:$17;
begin
  Key := 0;
  R.AH := 1;
  Intr($16, R);
  Ready := R.Flags and FZero > 0;
  if not Ready then
  begin
    if R.AL = 0 then Key := R.AH + 1000 else Key := R.AL;
    ScanCode := R.AH;
  end;
  PeekKey := Key <> 0;
  if KbdFlags and 8 = 8 then AltDown := True else AltDown := False;
end;

procedure SetColor(Fg, Bg: Byte);
begin
  TextColor(Fg);
  TextBackground(Bg);
end;

procedure WriteXY(X, Y: Byte; S: string);
begin
  GotoXY(X, Y);
  Write(S);
end;

procedure WriteFB(Fg, Bg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextColor(Fg);
  TextBackground(Bg);
  Write(S);
  TextAttr := A;
end;

procedure WriteXYF(X, Y, Fg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextColor(Fg);
  GotoXY(X, Y);
  Write(S);
  TextAttr := A;
end;

procedure WriteF(Fg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextColor(Fg);
  Write(S);
  TextAttr := A;
end;

procedure WriteB(Bg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextBackground(Bg);
  Write(S);
  TextAttr := A;
end;

procedure WriteXYB(X, Y, Bg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextBackground(Bg);
  GotoXY(X, Y);
  Write(S);
  TextAttr := A;
end;

procedure WriteXYFB(X, Y, Fg, Bg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextBackground(Bg);
  TextColor(Fg);
  GotoXY(X, Y);
  Write(S);
  TextAttr := A;
end;

function Center(S: string; W: Byte): string;
var
  A, B, L: Integer;
begin
  L := Length(S);
  A := (W - L) div 2;
  B := (W - L) mod 2 + A;
  Center := Copy(Blank, 1, A) + S +
    Copy(Blank, 1, B);
end;

procedure WriteCenter(W: Byte; S: string);
var
  A, B, L: Integer;
begin
  L := Length(S);
  A := (W - L) div 2;
  B := (W - L) mod 2 + A;
  Write(Copy(Blank, 1, A), S,
    Copy(Blank, 1, B));
end;

procedure WriteCenterXY(X, Y, W: Byte; S: string);
var
  A, B, L: Integer;
begin
  L := Length(S);
  A := (W - L) div 2;
  B := (W - L) mod 2 + A;
  GotoXY(X, Y);
  Write(Copy(Blank, 1, A), S,
    Copy(Blank, 1, B));
end;

procedure WriteCenterXYF(X, Y, W, Fg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextColor(Fg);
  WriteCenterXY(X, Y, W, S);
  TextAttr := A;
end;

procedure WriteCenterXYFB(X, Y, W, Fg, Bg: Byte; S: string);
var
  A: Byte;
begin
  A := TextAttr;
  TextColor(Fg);
  TextBackground(Bg);
  WriteCenterXY(X, Y, W, S);
  TextAttr := A;
end;

procedure SetBorder(Color: Byte);
var
  R: Registers;
begin
  R.AH := $10;
  R.AL := 1;
  R.BH := Color;
  Intr($10, R);
end;

function PadRight(S: string; N: Byte): string;
begin
  PadRight := Copy(S + Blank, 1, N);
end;

function StripSpaces(S: string): string;
var
  I: Byte;
begin
  StripSpaces := '';
  I := 1;
  if S = '' then Exit;
  repeat
    if S[I] = ' ' then Delete(S, I, 1) else Inc(I);
  until I > Length(S);
  StripSpaces := S;
end;

function Trim(S: string): string;
var
  I: Byte;
begin
  Trim := '';
  I := 1;
  if S = '' then Exit;
  repeat
    if S[I] = ' ' then Delete(S, I, 1) else Inc(I);
  until (I > Length(S)) or (S[I] <> ' ');
  I := Length(S);
  repeat
    if S[I] = ' ' then Delete(S, I, 1);
    Dec(I);
  until (I = 0) or (S[I] <> ' ');
  Trim := S;
end;

function LowerStr(S: string): string;
var
  I: Byte;
begin
  for I := 1 to Length(S) do S[I] := LoCaseW(Ord(S[I]));
  LowerStr := S;
end;

function UpperStr(S: string): string;
var
  I: Byte;
begin
  for I := 1 to Length(S) do S[I] := Chr(UpCaseW(Ord(S[I])));
  UpperStr := S;
end;

function UpCaseC(C: Char): Char;
begin
  UpCaseC := Chr(UpCaseW(Ord(C)));
end;

function LoCaseW(W: Word): Char;
begin
  LoCaseW := #0;
  if W > 255 then Exit;
  W := Lo(W);
  case W of
    $41..$5A: W := W + $20;
  end;
  case W of
    $9A: W := $81;
    $8E: W := $84;
    $99: W := $94;
  end;
  LoCaseW := Chr(W);
end;

function LoCase(C: Char): Char;
begin
  case C of
    'A'..'Z': C := Chr(Ord(C) + $20);
  end;
  case C of
    #$9A: C := #$81;
    #$8E: C := #$84;
    #$99: C := #$94;
  end;
  LoCase := C;
end;

function UpCaseW(W: Word): Word;
begin
  case W of
    $61..$7A: W := W - $20;
  end;
  case W of
    $81: W := $9A;
    $84: W := $8E;
    $94: W := $99;
  end;
  UpCaseW := W;
end;

function DirExists(S: string): Boolean;
var
  SR: SearchRec;
begin
  DirExists := False;
  if S[Length(S)] = '\' then Delete(S, Length(S), 1);
  if Copy(S, Length(S) - 2, 3) = '*.*' then Exit;
  FindFirst(S, Directory, SR);
  if (DosError = 0) and (SR.Attr and Directory <> 0) then DirExists := True;
end;

end.
