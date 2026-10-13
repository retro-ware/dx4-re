{$F+,G+,S-}
unit Times;

interface

function TimeToStr(H, M, S: Word): string;
function TimeCount: LongInt;

implementation

uses Dos;

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
