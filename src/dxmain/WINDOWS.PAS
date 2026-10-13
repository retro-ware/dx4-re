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
procedure PlainFrame(X, Y, Wd, Ht, Fg, Bg, Bright: Byte);
procedure InputFrame(X, Y, W, Fg, Bg: Byte);
procedure OpenFrame(X, Y, W, Ht, Fg, Bg: Byte);
procedure DoubleBox(X, Y, W, H: Byte);

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
  if SingleFrame then
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

procedure PlainFrame(X, Y, Wd, Ht, Fg, Bg, Bright: Byte);
var
  I, J, C1, C2: Byte;
  TL, TR, BL, BR, V, V2: Char;
begin
  C1 := Fg;
  C2 := C1;
  if Bright <> 0 then C1 := 0 else C2 := 0;
  SetColor(C1, Bg);
  Window(X, Y, X + Wd + 1, Y + Ht + 2);
  if SingleFrame then
  begin
    Write(#$DA);
    for I := 1 to Wd do Write(#$C4);
    TextColor(C2);
    Write(#$BF);
    for J := 2 to Ht + 1 do
    begin
      WriteXYF(1, J, C1, #$B3);
      WriteXYF(Wd + 2, J, C2, #$B3);
    end;
    TextColor(C1);
    Write(#$C0);
    TextColor(C2);
    for I := 1 to Wd do Write(#$C4);
    Write(#$D9);
  end
  else
  begin
    Write(#$D2);
    for I := 1 to Wd do Write(#$C4);
    TextColor(C2);
    Write(#$D3);
    for J := 2 to Ht + 1 do
    begin
      WriteXYF(1, J, C1, #$CE);
      WriteXYF(Wd + 2, J, C2, #$D0);
    end;
    TextColor(C1);
    Write(#$D4);
    TextColor(C2);
    for I := 1 to Wd do Write(#$C4);
    Write(#$D5);
  end;
  Window(X + 1, Y + 1, X + Wd, Y + Ht);
  SetColor(0, Bg);
end;

procedure InputFrame(X, Y, W, Fg, Bg: Byte);
var
  I, A, B: Byte;
begin
  A := 0;
  B := Fg;
  SetColor(A, Bg);
  if not SingleFrame then
  begin
    GotoXY(X - 1, Y - 1);
    Write(' ');
    for I := 1 to W do Write(#$D8);
    TextColor(B);
    Write(' ');
  end;
  if not SingleFrame then WriteXYF(X - 1, Y, A, #$CE);
  GotoXY(X, Y);
  for I := 1 to W do Write(#$B0);
  if not SingleFrame then WriteF(B, #$D0);
  WriteXY(X - 1, Y + 1, ' ');
  TextColor(B);
  if not SingleFrame then
    for I := 1 to W do Write(#$DD);
  Write(' ');
  SetColor(0, Bg);
end;

procedure OpenFrame(X, Y, W, Ht, Fg, Bg: Byte);
var
  I, A, B: Byte;
begin
  A := 0;
  B := Fg;
  SetColor(A, Bg);
  Window(X, Y, 80, ScreenRows);
  Write(' ');
  if not SingleFrame then
    for I := 1 to W do Write(#$D8);
  TextColor(B);
  if not SingleFrame then
    for I := 2 to Ht + 1 do
    begin
      WriteXYF(W + 2, I, B, #$D0);
      WriteXYF(1, I, A, #$CE);
    end;
  Writeln;
  Write(' ');
  if not SingleFrame then
    for I := 1 to W do Write(#$DD);
  SetColor(0, Bg);
end;

procedure DoubleBox(X, Y, W, H: Byte);
var
  I, J, K: Byte;
begin
  WriteXY(X - 1, Y, ' '#$C9);
  for I := 1 to W do Write(#$CD);
  Write(#$BB' ');
  for J := Y + 1 to Y + H do
  begin
    WriteXY(X - 1, J, ' '#$BA);
    WriteXY(X + W + 1, J, #$BA' ');
  end;
  WriteXY(X - 1, Y + H + 1, ' '#$C8);
  for I := 1 to W do Write(#$CD);
  Write(#$BC' ');
  K := X + 1;
  W := W + 3;
  H := H + 2;
  repeat
    Mem[$B800:(Y + H - 1) * 160 + K shl 1 - 1] := 7;
    Inc(K);
  until K >= X + W + 1;
  K := Y + 1;
  repeat
    Mem[$B800:((K - 1) * 80 + (X + W)) shl 1 - 1] := 7;
    Mem[$B800:((K - 1) * 80 + (X + W + 1)) shl 1 - 1] := 7;
    Inc(K);
  until K >= Y + H + 1;
end;

end.
