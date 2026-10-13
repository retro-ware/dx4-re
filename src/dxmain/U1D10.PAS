{$F+,G+,S-}
unit U1D10;
{ Resident segment 1d10: hex/binary/decimal number-string conversions }

interface

type
  Str2 = string[2];

function HexByte(B: Byte): string;
function HexWord(W: Word): string;
function HexLong(L: Longint): string;
function HexVal(S: string): Longint;
function HexReal(R: Real): string;
function IntStr(I: Integer): string;
function BinByte(B: Byte): string;
function BinWord(W: Word): string;
function HexDigit(C: Char): Byte;
function HexByteVal(S: Str2): Byte;
function HexToStr(S: string): string;
function LongStrW(L: Longint; W: Byte): string;

implementation

uses Screen;

type
  TLong = record
    Lo, Hi: Word;
  end;

const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';

function HexByte(B: Byte): string;
begin
  HexByte := HexChars[B shr 4] + HexChars[B mod 16];
end;

function HexWord(W: Word): string;
begin
  HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
end;

function HexLong(L: Longint): string;
begin
  HexLong := HexWord(TLong(L).Hi) + HexWord(TLong(L).Lo);
end;

function HexVal(S: string): Longint;
var
  L: Longint;
  I: Byte;
begin
  if Length(S) > 8 then
    HexVal := 0
  else
  begin
    S := StripSpaces(S);
    if Length(S) < 8 then
      repeat
        Insert('0', S, 1);
      until Length(S) = 8;
    L := HexDigit(S[1]);
    for I := 2 to 8 do
      L := HexDigit(S[I]) + L * 16;
    HexVal := L;
  end;
end;

function HexReal(R: Real): string;
var
  Lo, Hi: Word;
  Max: Real;
begin
  Max := 4294967295.0;
  if R < 0 then R := Max + R + 1;
  if R > Max then
    HexReal := 'OVERFLOW'
  else
  begin
    Hi := Trunc(Int(R / 65536.0));
    Lo := Trunc(Int(R - Hi * 65536.0));
    HexReal := HexWord(Hi) + HexWord(Lo);
  end;
end;

function IntStr(I: Integer): string;
var
  S: string;
begin
  Str(I, S);
  IntStr := S;
end;

function BinByte(B: Byte): string;
var
  I: Integer;
  S: string;
  Dummy: Word;
begin
  S := '';
  for I := 1 to 8 do
  begin
    S := IntStr(B mod 2) + S;
    B := B shr 1;
  end;
  BinByte := S;
end;

function BinWord(W: Word): string;
var
  Dummy: Word;
begin
  BinWord := BinByte(Hi(W)) + BinByte(Lo(W));
end;

function HexDigit(C: Char): Byte;
var
  D: Byte;
begin
  case C of
    '0'..'9': D := Ord(C) - 48;
    'a'..'f': D := Ord(C) - 87;
    'A'..'F': D := Ord(C) - 55;
  else
    D := 0;
  end;
  HexDigit := D;
end;

function HexByteVal(S: Str2): Byte;
var
  D: Byte;
begin
  D := HexDigit(S[1]) shl 4 + HexDigit(S[2]);
  HexByteVal := D;
end;

function HexToStr(S: string): string;
var
  R: string;
  I: Byte;
begin
  HexToStr := '';
  if S = '' then Exit;
  S := StripSpaces(S);
  if Odd(Length(S)) then Insert('0', S, Length(S));
  R := '';
  I := 1;
  repeat
    R := R + Chr(HexByteVal(Copy(S, I, 2)));
    Inc(I, 2);
  until I >= Length(S);
  HexToStr := R;
end;

function LongStrW(L: Longint; W: Byte): string;
var
  S: string;
  Dummy: Word;
begin
  LongStrW := '';
  Str(L: W, S);
  LongStrW := S;
end;

end.
