{$F+,G+,S-}
unit Fonts;

interface

const
  CustomFont: Boolean = False;

procedure InitFont;
procedure InitPlainFont;

implementation

uses Dos, DXGlob, Mouse, Palette, Screen;

type
  TGlyph = array[1..16] of Byte;

const
  G16_1: TGlyph = ($FF, $81, $FF, $7E, $7E, $3C, $3C, $18, $18, $3C, $3C, $7E, $7E, $FF, $81, $FF);
  G16_2: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $63, $63, $00, $00, $00, $00, $00, $00, $00);
  G16_3: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $FF);
  G16_4: TGlyph = ($01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01);
  G16_5: TGlyph = ($C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0);
  G16_6: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $01);
  G16_7: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0);
  G16_8: TGlyph = ($01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00);
  G16_9: TGlyph = ($C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $00, $00, $00, $00, $00, $00, $00, $00);
  G16_10: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF);
  G16_11: TGlyph = ($FF, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);
  G16_12: TGlyph = ($00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00);
  G14_1: TGlyph = ($FF, $81, $FF, $7E, $7E, $3C, $18, $18, $3C, $7E, $7E, $FF, $81, $FF, $00, $00);
  G14_2: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $63, $63, $00, $00, $00, $00, $00, $00, $00);
  G14_3: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $FF, $00, $00, $00, $00, $00, $FF, $00, $00);
  G14_4: TGlyph = ($01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01);
  G14_5: TGlyph = ($C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0);
  G14_6: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $01);
  G14_7: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0);
  G14_8: TGlyph = ($01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00);
  G14_9: TGlyph = ($C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $00, $00, $00, $00, $00, $00, $00, $00);
  G14_10: TGlyph = ($00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $FF, $00, $00);
  G14_11: TGlyph = ($FF, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);
  G14_12: TGlyph = ($00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $00);

procedure InitFont;
var
  I: Word;
  P: PFontData;
  Kind, H: Byte;
  L1, L2, L3, L4, L5, L6, L7, L8, L9, L10, L11, L12: TGlyph;
begin
  if BigCursor then
  begin
    Kind := 2;
    ScreenRows := 28;
  end
  else
  begin
    Kind := 6;
    ScreenRows := 25;
  end;
  MenuRows := ScreenRows - 7;
  if G507 then MenuRows := ScreenRows - 8;
  ListRows := MenuRows - 2;
  if ThinButtons then
    InitPlainFont
  else
  begin
    CustomFont := True;
    ShowCursor;
    if BigCursor then
    begin
      L1 := G14_1;
      L2 := G14_2;
      L3 := G14_3;
      L10 := G14_4;
      L11 := G14_5;
      L4 := G14_6;
      L5 := G14_7;
      L6 := G14_8;
      L7 := G14_9;
      L8 := G14_10;
      L12 := G14_12;
      L9 := G14_11;
      ScreenRows := 28;
    end
    else
    begin
      L1 := G16_1;
      L2 := G16_2;
      L3 := G16_3;
      L10 := G16_4;
      L11 := G16_5;
      L4 := G16_6;
      L5 := G16_7;
      L6 := G16_8;
      L7 := G16_9;
      L8 := G16_10;
      L12 := G16_12;
      L9 := G16_11;
      ScreenRows := 25;
    end;
    H := 16;
    if BigCursor then H := 14;
    GetMem(P, $1000);
    GetFont(P, Kind);
    for I := 1 to H do
    begin
    P^[H shl 1 + I] := L1[I];
    P^[H * $AD + I] := L2[I];
    P^[H * $C6 + I] := L3[I];
    P^[H * $D2 + I] := L4[I];
    P^[H * $D3 + I] := L5[I];
    P^[H * $D4 + I] := L6[I];
    P^[H * $D5 + I] := L7[I];
    P^[H * $D8 + I] := L8[I];
    P^[H * $DD + I] := L9[I];
    P^[H * $CE + I] := L10[I];
    P^[H * $D0 + I] := L11[I];
    P^[H * $DC + I] := L12[I];
    end;
    SetFont(P, Kind);
    FreeMem(P, $1000);
    HideCursor;
    SetBorder(BorderColor);
    MouseYRange(0, ScreenRows - 1);
  end;
end;

procedure InitPlainFont;
var
  R: Registers;
begin
  if BigCursor then
    ScreenRows := 28
  else
    ScreenRows := 25;
  MenuRows := ScreenRows - 7;
  if G507 then MenuRows := ScreenRows - 8;
  ListRows := MenuRows - 2;
  CustomFont := False;
  ShowCursor;
  R.AH := $11;
  R.AL := $14;
  if BigCursor then R.AL := $11;
  R.BL := 0;
  Intr($10, R);
  HideCursor;
  SetBorder(BorderColor);
  MouseYRange(0, ScreenRows - 1);
end;

end.
