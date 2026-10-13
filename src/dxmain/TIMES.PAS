{$F+,G+,S-}
unit Times;

interface

procedure CancelWait;
procedure SetWait(Time: LongInt);
procedure Wait(Time: LongInt);
function TimeToStr(H, M, S: Word): string;
function TimeCount: LongInt;

implementation

uses Dos, Crt;

var
  WaitFlag: Byte;

procedure CancelWait;
var
  R: Registers;
  Flag: Byte;
begin
  R.AH := $83;
  R.AL := 1;
  R.ES := Seg(Flag);
  R.BX := Ofs(Flag);
  R.CX := 0;
  R.DX := 0;
  Intr($15, R);
  WaitFlag := 0;
end;

procedure SetWait(Time: LongInt);
var
  R: Registers;
begin
  CancelWait;
  R.AH := $83;
  R.AL := 0;
  R.ES := Seg(WaitFlag);
  R.BX := Ofs(WaitFlag);
  R.CX := Time div $10000;
  R.DX := Time mod $10000;
  Intr($15, R);
end;

procedure Wait(Time: LongInt);
var
  R: Registers;
begin
  SetWait(Time);
  repeat
  until (WaitFlag <> 0) or KeyPressed;
  WaitFlag := 0;
end;

function TimeToStr(H, M, S: Word): string;
var
  R, T: string;
  X: Word;
begin
  Str(H, T);
  R := T;
  if H < 10 then R := '0' + R;
  Str(M, T);
  if M < 10 then
    R := R + '.0' + T
  else
    R := R + '.' + T;
  Str(S, T);
  R := R + '.' + T;
  TimeToStr := R;
end;

function TimeCount: LongInt;
var
  H, M, S, S100: Word;
  L: LongInt;
begin
  GetTime(H, M, S, S100);
  L := LongInt(H) * 2600;
  L := L + M * 60 + S;
  L := L * 100 + S100;
  TimeCount := L;
end;

end.
