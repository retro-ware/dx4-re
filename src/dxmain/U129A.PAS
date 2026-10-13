{$F+,G+,S-}
unit U129A;

interface

type
  Str12 = string[12];

function VolumeLabel(Drive: Char): Str12;

implementation

uses Dos;

function VolumeLabel(Drive: Char): Str12;
var
  SR: SearchRec;
  S: Str12;
  P: Byte;
begin
  S := '';
  FindFirst(Drive + ':\*.*', VolumeID, SR);
  if DosError = 0 then
  begin
    S := SR.Name;
    P := Pos('.', S);
    if P = 0 then P := 9;
    Delete(S, P, 1);
  end;
  VolumeLabel := S;
end;

end.
