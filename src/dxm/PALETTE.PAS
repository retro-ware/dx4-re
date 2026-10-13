{$F+,G+,S-}
unit Palette;

interface

uses Dos;

type
  TRGB = record
    R, G, B: Byte;
  end;
  TPalRegs = array[0..16] of Byte;
  TFontData = array[1..$1000] of Byte;
  PFontData = ^TFontData;

const
  PalMap: array[0..15] of Byte = (0, 1, 2, 3, 4, 5, $14, 7, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F);

procedure GetRGB(C: Byte; var RGB: TRGB);
procedure SetPalRegs(P: TPalRegs);
procedure SetRGB(C: Byte; RGB: TRGB);
procedure GetFont(var P: PFontData; Kind: Byte);
procedure SetFont(P: PFontData; Kind: Byte);
procedure ScrollDown(X1, Y1, X2, Y2, Color: Byte);
procedure ScrollUp(X1, Y1, X2, Y2, Color: Byte);
procedure WaitRetrace;
procedure FadeOut;

implementation

procedure GetRGB(C: Byte; var RGB: TRGB);
begin
  Port[$3C7] := PalMap[C];
  RGB.R := Port[$3C9];
  RGB.G := Port[$3C9];
  RGB.B := Port[$3C9];
end;

procedure SetPalRegs(P: TPalRegs);
var
  R: Registers;
begin
  R.AH := $10;
  R.AL := 2;
  R.ES := Seg(P);
  R.DX := Ofs(P);
  Intr($10, R);
end;

procedure SetRGB(C: Byte; RGB: TRGB);
begin
  Port[$3C8] := PalMap[C];
  Port[$3C9] := RGB.R;
  Port[$3C9] := RGB.G;
  Port[$3C9] := RGB.B;
end;

procedure GetFont(var P: PFontData; Kind: Byte);
var
  R: Registers;
  Q: Pointer;
begin
  R.AH := $11;
  R.AL := $30;
  R.BH := 6;
  if Kind = 2 then R.BH := 2;
  Intr($10, R);
  Q := Ptr(R.ES, R.BP);
  Move(Q^, P^, $1000);
end;

procedure SetFont(P: PFontData; Kind: Byte);
var
  R: Registers;
begin
  R.AH := $11;
  R.AL := $10;
  R.BH := 16;
  if Kind = 2 then R.BH := 14;
  R.BL := 0;
  R.CX := $100;
  R.DX := 0;
  R.ES := Seg(P^);
  R.BP := Ofs(P^);
  Intr($10, R);
end;

procedure ScrollDown(X1, Y1, X2, Y2, Color: Byte);
var
  R: Registers;
begin
  R.AH := 7;
  R.AL := 1;
  R.CH := Y1;
  R.CL := X1;
  R.DH := Y2;
  R.DL := X2;
  R.BH := Color shl 4;
  Intr($10, R);
end;

procedure ScrollUp(X1, Y1, X2, Y2, Color: Byte);
var
  R: Registers;
begin
  R.AH := 6;
  R.AL := 1;
  R.CH := Y1;
  R.CL := X1;
  R.DH := Y2;
  R.DL := X2;
  R.BH := Color shl 4;
  Intr($10, R);
end;

procedure WaitRetrace;
var
  Dummy: Word;
begin
  asm
        mov     dx,3DAh
@1:     in      al,dx
        test    al,8
        jnz     @1
@2:     in      al,dx
        test    al,8
        jz      @2
  end;
end;

procedure FadeOut;
var
  Step, I, J: Byte;
  Pal: array[0..15] of TRGB;
begin
  for I := 0 to 15 do GetRGB(I, Pal[I]);
  for Step := 63 downto 0 do
  begin
    for I := 0 to 15 do
    begin
      if Pal[I].R > 0 then Dec(Pal[I].R);
      if Pal[I].G > 0 then Dec(Pal[I].G);
      if Pal[I].B > 0 then Dec(Pal[I].B);
    end;
    WaitRetrace;
    for I := 0 to 15 do SetRGB(I, Pal[I]);
  end;
end;

end.
