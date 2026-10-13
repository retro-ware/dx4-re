{$F+,G+,S-,I-}
unit Windows;

interface

type
  TWinState = record
    X1, Y1, X2, Y2, Attr, CurX, CurY: Byte;
  end;

procedure SaveWin(var W: TWinState);
procedure RestoreWin(var W: TWinState);
procedure GetWin(var W: TWinState);
procedure SetWin(var W: TWinState);
procedure Frame(X, Y, Wd, Ht, Fg, Bg, Bright, Shadow: Byte);

implementation

uses Crt, DXGlob, Screen;

procedure SaveWin(var W: TWinState);
begin
  W.X1 := Lo(WindMin) + 1;
  W.Y1 := Hi(WindMin) + 1;
  W.X2 := Lo(WindMax) + 1;
  W.Y2 := Hi(WindMax) + 1;
  W.Attr := TextAttr;
  W.CurX := WhereX;
  W.CurY := WhereY;
  Window(1, 1, 80, ScreenRows);
end;

procedure RestoreWin(var W: TWinState);
begin
  Window(W.X1, W.Y1, W.X2, W.Y2);
  TextAttr := W.Attr;
  GotoXY(W.CurX, W.CurY);
end;

procedure GetWin(var W: TWinState);
begin
  W.X1 := Lo(WindMin) + 1;
  W.Y1 := Hi(WindMin) + 1;
  W.X2 := Lo(WindMax) + 1;
  W.Y2 := Hi(WindMax) + 1;
  W.CurX := WhereX;
  W.CurY := WhereY;
  W.Attr := TextAttr;
end;

procedure SetWin(var W: TWinState);
begin
  Window(W.X1, W.Y1, W.X2, W.Y2);
  GotoXY(W.CurX, W.CurY);
end;

procedure Frame(X, Y, Wd, Ht, Fg, Bg, Bright, Shadow: Byte);
var
  C1, C2: Byte;
  TL, TR, BL, BR, V, V2: Char;
  I: Integer;
  A, C, K, B: Byte;
begin
  C1 := Fg;
  C2 := C1;
  if Bright <> 0 then C1 := 0 else C2 := 0;
  if Bg >= $80 then
  begin
    C1 := C1 + $80;
    C2 := C2 + $80;
  end;
  SetColor(C1, Bg);
  if Explode then
  begin
    K := 1;
    A := X + Wd shr 1;
    repeat
      B := Ht * K div Wd;
      C := (Ht - B) shr 1 + 1 + Y;
      Window(A, C, A + K, C + B);
      ClrScr;
      Delay(3);
      A := A - 1;
      K := K + 2;
    until A <= X;
  end;
  Window(X, Y, 80, ScreenRows);
  if ThinButtons then
  begin
    TL := #$DA;
    TR := #$BF;
    BL := #$C0;
    BR := #$D9;
    V := #$B3;
    V2 := V;
  end
  else
  begin
    TL := #$D2;
    TR := #$D3;
    BL := #$D4;
    BR := #$D5;
    V := #$CE;
    V2 := #$D0;
  end;
  Write(TL);
  for I := 1 to Wd do Write(#$C4);
  WriteF(C2, TR);
  for I := 2 to Ht + 1 do
  begin
    WriteXY(1, I, V);
    WriteXYF(Wd + 2, I, C2, V2);
  end;
  WriteXY(1, Ht + 2, BL);
  TextColor(C2);
  for I := 1 to Wd do Write(#$C4);
  if (Wd + 2 = 80) and (Y + Ht + 1 = ScreenRows) then
    MemW[$B800:ScreenRows * 160 - 2] := (Bg shl 4 + C2) shl 8 + Ord(BR)
  else
    WriteXY(Wd + 2, Ht + 2, BR);
  Window(X + 1, Y + 1, X + Wd, Y + Ht);
  ClrScr;
  if Shadow <> 0 then
  begin
    I := X + 2;
    repeat
      Mem[$B800:(Y + Ht + 1) * 160 + I shl 1 - 1] := 7;
      Inc(I);
    until X + Wd + 4 <= I;
    I := Y;
    repeat
      Mem[$B800:(I * 80 + X + Wd + 2) shl 1 - 1] := 7;
      Mem[$B800:(I * 80 + X + Wd + 3) shl 1 - 1] := 7;
      Inc(I);
    until Y + Ht + 2 <= I;
  end;
  SetColor(0, Bg);
end;

end.
