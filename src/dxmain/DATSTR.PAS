{$F+,G+,S-}
unit DatStr;

interface

uses Dos;

type
  Str2 = string[2];
  Str6 = string[6];
  Str8 = string[8];

function Zero2(W: Word): Str2;
function Num2(W: Word): Str2;
function Year2(W: Word): Str2;
function TimeStr(DT: DateTime): Str6;
function DateStr(DT: DateTime): Str8;

implementation

function Zero2(W: Word): Str2;
var
  S: Str2;
begin
  Str(W, S);
  if Length(S) = 1 then S := '0' + S;
  Zero2 := S;
end;

function Num2(W: Word): Str2;
var
  S: Str2;
begin
  Str(W:2, S);
  Num2 := S;
end;

function Year2(W: Word): Str2;
var
  S: string[4];
begin
  Str(W, S);
  S := Copy(S, 3, 2);
  Year2 := S;
end;

function TimeStr(DT: DateTime): Str6;
begin
  TimeStr := ' ' + Num2(DT.Hour) + ':' + Zero2(DT.Min);
end;

function DateStr(DT: DateTime): Str8;
begin
  DateStr := Num2(DT.Day) + '.' + Zero2(DT.Month) + '.' + Year2(DT.Year);
end;

end.
