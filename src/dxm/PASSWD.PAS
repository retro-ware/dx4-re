{$F+,G+,S-,I-}
unit Passwd;

interface

type
  Str12 = string[12];

function ReadPassword(X, Y: Byte): Str12;

implementation

uses Crt, DXGlob, Mouse, Screen;

function ReadPassword(X, Y: Byte): Str12;
var
  N, A: Byte;
  Key: Word;
  S: Str12;
begin
  GotoXY(X, Y);
  ShowCursor;
  A := TextAttr;
  LastDate := '';
  N := 0;
  SetColor(0, 2);
  S := '';
  Key := 0;
  repeat until MouseButton = 0;
  repeat
    if (Key <> 8) and (N < 12) and (Key <> 0) then
    begin
      S := S + LoCaseW(Key);
      Inc(N);
      MouseHide;
      Write('*');
      MouseShow;
    end;
    if (Key = 8) and (N > 0) then
    begin
      GotoXY(WhereX - 1, WhereY);
      MouseHide;
      Write(' ');
      MouseShow;
      GotoXY(WhereX - 1, WhereY);
      Dec(N);
      Delete(S, Length(S), 1);
    end;
    repeat
      GetKey(Key);
      if MouseOutside(X - 15, X + 26, Y - 6, Y + 2) then Key := 27;
      if (Key = 1068) or (MouseButton = 2) then Key := 27;
    until (Lo(Key) in [8, 13, 27, 33..165]) and (Key < 256);
  until (Key = 13) or (Key = 27);
  if Key = 27 then S := '';
  TextAttr := A;
  ReadPassword := S;
  HideCursor;
end;

end.
