{$F+,G+,S-}
unit Screen;

interface

uses Dos, Crt;

const
  AltDown: Boolean = False;
  ShiftDown: Boolean = False;
  CtrlDown: Boolean = False;
  ScanCode: Byte = 0;

procedure DelBackslash(var S: string);
function DriveValid(Drive: Char): Boolean;
function Spaces(N: Integer): string;
function FillStr(C: Char; N: Byte): string;
function GetKey(var Key: Word): Boolean;
procedure SetColor(Fg, Bg: Byte);
procedure WriteXY(X, Y: Byte; S: string);
procedure WriteFB(Fg, Bg: Byte; S: string);
procedure WriteXYF(X, Y, Fg: Byte; S: string);
procedure WriteF(Fg: Byte; S: string);
procedure WriteXYB(X, Y, Bg: Byte; S: string);
procedure WriteXYFB(X, Y, Fg, Bg: Byte; S: string);
function Center(S: string; W: Byte): string;
procedure WriteCenter(W: Byte; S: string);
procedure WriteCenterXY(X, Y, W: Byte; S: string);
procedure WriteCenterXYF(X, Y, W, Fg: Byte; S: string);
procedure WriteCenterXYFB(X, Y, W, Fg, Bg: Byte; S: string);
procedure SetBorder(Color: Byte);
function PadRight(S: string; N: Byte): string;
function LowerStr(S: string): string;
function UpperStr(S: string): string;
function UpCaseC(C: Char): Char;
function LoCaseW(W: Word): Char;
function LoCase(C: Char): Char;
function UpCaseW(W: Word): Word;

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

end.
