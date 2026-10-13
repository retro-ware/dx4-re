{$F+,G+,S-}
unit Sounds;

interface

procedure Sound1;
procedure Sound2;
procedure Sound3;
procedure Sound4;
procedure Sound5;
procedure Sound6;
procedure Sound7;
procedure PlaySound(N: Integer);

implementation

uses Crt;

procedure Sound1;
var
  F, I: Integer;
begin
  for I := 1 to 5 do
    for F := 50 to 9000 do Sound(F);
  NoSound;
end;

procedure Sound2;
var
  F, I: Integer;
begin
  for I := 1 to 5 do
  begin
    for F := 5000 to 9000 do Sound(F);
    for F := 9000 downto 5000 do Sound(F);
  end;
  NoSound;
end;

procedure Sound3;
var
  F, I: Integer;
begin
  for I := 1 to 5 do
  begin
    for F := 3000 to 9000 do Sound(F);
    for F := 9000 downto 3000 do Sound(F);
  end;
  NoSound;
end;

procedure Sound4;
var
  F, I: Integer;
begin
  for I := 1 to 20 do
  begin
    for F := 3000 to 4000 do Sound(F);
    for F := 4000 downto 3000 do Sound(F);
  end;
  NoSound;
end;

procedure Sound5;
var
  F, I: Integer;
begin
  for I := 1 to 40 do
  begin
    for F := 2000 to 2500 do Sound(F);
    for F := 2500 downto 2000 do Sound(F);
  end;
  NoSound;
end;

procedure Sound6;
var
  F, I: Integer;
begin
  for I := 1 to 10 do
  begin
    for F := 4000 to 5300 do Sound(F);
    for F := 7300 downto 4000 do Sound(F);
  end;
  NoSound;
end;

procedure Sound7;
var
  F, I: Integer;
begin
  for I := 1 to 8 do
  begin
    for F := 2000 to 7300 do Sound(F);
    for F := 8300 downto 5000 do Sound(F);
  end;
  NoSound;
end;

procedure PlaySound(N: Integer);
var
  Dummy: Integer;
begin
  case N of
    1: Sound1;
    2: Sound2;
    3: Sound3;
    4: Sound4;
    5: Sound5;
    6: Sound6;
    7: Sound7;
  end;
end;

end.
