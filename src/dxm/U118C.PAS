{$F+,G+,S-}
unit U118C;

interface

type
  TEntry = record
    W: Word;
    Alt, Shift, Ctrl: Boolean;
    Scan: Byte;
  end;

var
  Entries: array[1..100] of TEntry;
  EntryIdx: Byte;

implementation

begin
  for EntryIdx := 1 to 100 do
    with Entries[EntryIdx] do
    begin
      W := 0;
      Alt := False;
      Shift := False;
      Ctrl := False;
      Scan := 0;
    end;
end.
