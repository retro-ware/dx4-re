{$F+,G+,S-}
unit U1D10;
{ PLACEHOLDER for resident segment 1d10 (not yet decompiled): number/string conversions.
  Only the interface used by overlay units so far; bodies are stubs. }

interface

function HexLong(L: Longint): string;          { 1d10:0088 }
function HexVal(S: string): Longint;           { 1d10:00be }
function BinWord(W: Word): string;             { 1d10:0353 }

implementation

function HexLong(L: Longint): string;
begin
  HexLong := '';
end;

function HexVal(S: string): Longint;
begin
  HexVal := 0;
end;

function BinWord(W: Word): string;
begin
  BinWord := '';
end;

end.
