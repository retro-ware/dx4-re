{$F+,G+,S-,I-}
unit Buttons;

interface

type
  TButton = record
    X, Y: Byte;
    HotFg, Fg: Byte;
    Len: Byte;
    Light, Bg: Byte;
    Pressed, Focused: Boolean;
    OldPressed, OldFocused: Boolean;
    Caption: string;
    Clicked: Boolean;
    SaveFocus: Boolean;
  end;
  TButton2 = array[1..2] of TButton;
  TPushButton = record
    X, Y: Byte;
    Fg: Byte;
    Len: Byte;
    Light, Bg: Byte;
    Pressed, OldPressed: Boolean;
    Spare: Byte;
    Caption: string;
  end;
  TButton3 = array[1..3] of TButton;
  TButton4 = array[1..4] of TButton;
  TButton5 = array[1..5] of TButton;
  TButton6 = array[1..6] of TButton;

procedure InitPush(X, Y, Fg, Light, Bg: Byte; Caption: string; var B: TPushButton);
procedure DrawPush(var B: TPushButton);
procedure FlashPush(var B: TPushButton);
function PushClicked(var B: TPushButton): Boolean;
procedure InitButton(Focus: Boolean; X, Y, HotFg, Fg, Light, Bg: Byte;
  Caption: string; var B: TButton);
procedure FocusButton(Focus: Boolean; var B: TButton);
procedure DrawButton(var B: TButton);
function MouseButton(var B: TButton): Boolean;
procedure InitButton2(Focus: Boolean; X1, Y1, X2, Y2, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2: string; var B: TButton2);
procedure DrawButton2(var B: TButton2);
procedure RestoreButton2(var B: TButton2);
procedure ResetButton2(var B: TButton2);
procedure HandleButton2(var Hit1, Hit2: Boolean; var Key: Word; var B: TButton2);
procedure InitButton3(First: Boolean; X1, Y1, X2, Y2, X3, Y3, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3: string; var B: TButton3);
procedure SetButton3(N: Byte; var B: TButton3);
procedure DrawButton3(var B: TButton3);
procedure RestoreButton3(var B: TButton3);
procedure ResetButton3(var B: TButton3);
procedure HandleButton3(var Hit1, Hit2, Hit3: Boolean; var Key: Word; var B: TButton3);
procedure InitButton4(First: Boolean; X1, Y1, X2, Y2, X3, Y3, X4, Y4, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4: string; var B: TButton4);
procedure DrawButton4(var B: TButton4);
procedure SetButton4(N: Byte; var B: TButton4);
procedure RestoreButton4(var B: TButton4);
procedure ResetButton4(var B: TButton4);
procedure HandleButton4(var Hit1, Hit2, Hit3, Hit4: Boolean; var Key: Word; var B: TButton4);
procedure InitButton5(N: Byte; X1, Y1, X2, Y2, X3, Y3, X4, Y4, X5, Y5, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4, Cap5: string; var B: TButton5);
procedure DrawButton5(var B: TButton5);
procedure HandleButton5(var Hit1, Hit2, Hit3, Hit4, Hit5: Boolean; var Key: Word; var B: TButton5);
procedure RestoreButton5(var B: TButton5);
procedure ResetButton5(var B: TButton5);
procedure InitButton6(First: Boolean; X1, Y1, X2, Y2, X3, Y3, X4, Y4, X5, Y5, X6, Y6, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4, Cap5, Cap6: string; var B: TButton6);
procedure DrawButton6(var B: TButton6);
procedure HandleButton6(var Hit1, Hit2, Hit3, Hit4, Hit5, Hit6: Boolean; var Key: Word; var B: TButton6);

implementation

uses Crt, DXGlob, Mouse, Screen, Status;

procedure InitPush(X, Y, Fg, Light, Bg: Byte; Caption: string; var B: TPushButton);
begin
  B.Pressed := False;
  B.OldPressed := True;
  B.X := X;
  B.Y := Y;
  B.Bg := Bg;
  B.Light := Light;
  B.Fg := Fg;
  B.Caption := ' ' + Caption + ' ';
  B.Len := Length(B.Caption);
  DrawPush(B);
end;

procedure DrawPush(var B: TPushButton);
var
  Dark, Lit: Byte;
  I: Integer;
  L, R: string[1];
begin
  if B.OldPressed = B.Pressed then Exit;
  B.OldPressed := B.Pressed;
  Dark := 0;
  Lit := Dark;
  if B.Pressed then
  begin
    Lit := B.Light;
    L := ' ';
    R := '';
  end
  else
  begin
    Dark := B.Light;
    L := '';
    R := ' ';
  end;
  SetColor(Dark, B.Bg);
  MouseHide;
  if SingleFrame then
  begin
    WriteXY(B.X, B.Y, L + #$DA);
    for I := 1 to B.Len do Write(#$C4);
    TextColor(Lit);
    Write(#$BF + R);
    WriteXYF(B.X, B.Y + 1, Dark, L + #$B3);
    WriteF(B.Fg, B.Caption);
    WriteF(Lit, #$B3 + R);
    TextColor(Dark);
    WriteXY(B.X, B.Y + 2, L + #$C0);
    TextColor(Lit);
    for I := 1 to Length(B.Caption) do Write(#$C4);
    Write(#$D9 + R);
  end
  else
  begin
    WriteXY(B.X, B.Y, L + #$D2);
    for I := 1 to B.Len do Write(#$C4);
    TextColor(Lit);
    Write(#$D3 + R);
    WriteXYF(B.X, B.Y + 1, Dark, L + #$CE);
    WriteF(B.Fg, B.Caption);
    WriteF(Lit, #$D0 + R);
    TextColor(Dark);
    WriteXY(B.X, B.Y + 2, L + #$D4);
    TextColor(Lit);
    for I := 1 to Length(B.Caption) do Write(#$C4);
    Write(#$D5 + R);
  end;
  MouseShow;
end;

procedure FlashPush(var B: TPushButton);
begin
  B.Pressed := True;
  B.OldPressed := not B.Pressed;
  DrawPush(B);
  Delay(100);
  B.Pressed := False;
  B.OldPressed := not B.Pressed;
  DrawPush(B);
end;

function PushClicked(var B: TPushButton): Boolean;
var
  X1, X2, Y: Byte;
begin
  PushClicked := False;
  X1 := B.X + Lo(WindMin) + 1;
  X2 := X1 + B.Len;
  Y := B.Y + Hi(WindMin) + 1;
  if (Mouse.MouseButton = 1) and (Y = MouseY) and (X1 < MouseX) and (X2 > MouseX) then
  begin
    B.Pressed := True;
    DrawPush(B);
    repeat
    until (Mouse.MouseButton = 0) or (Y <> MouseY) or (X1 >= MouseX) or (X2 < MouseX);
    PushClicked := True;
    B.Pressed := False;
    DrawPush(B);
  end;
end;

procedure InitButton(Focus: Boolean; X, Y, HotFg, Fg, Light, Bg: Byte;
  Caption: string; var B: TButton);
begin
  B.Pressed := False;
  B.OldPressed := True;
  B.Focused := Focus;
  B.OldFocused := not Focus;
  B.X := X;
  B.Y := Y;
  B.Bg := Bg;
  B.Light := Light;
  B.HotFg := HotFg;
  B.Fg := Fg;
  B.Caption := ' ' + Caption + ' ';
  B.Len := Length(B.Caption);
  B.Clicked := False;
  B.SaveFocus := B.Focused;
  DrawButton(B);
end;

procedure FocusButton(Focus: Boolean; var B: TButton);
begin
  B.Focused := Focus;
  B.OldFocused := not B.Focused;
  B.Clicked := False;
  DrawButton(B);
  B.SaveFocus := B.Focused;
end;

procedure DrawButton(var B: TButton);
var
  Attr, Dark, Lit, Text: Byte;
  Dummy: Word;
  I: Integer;
  L, R: string[1];
begin
  Attr := TextAttr;
  if (B.OldFocused = B.Focused) and (B.OldPressed = B.Pressed) then Exit;
  B.OldFocused := B.Focused;
  B.OldPressed := B.Pressed;
  Dark := 0;
  Lit := Dark;
  if B.Focused then Text := B.HotFg else Text := B.Fg;
  if B.Pressed then
  begin
    Lit := B.Light;
    L := ' ';
    R := '';
  end
  else
  begin
    Dark := B.Light;
    L := '';
    R := ' ';
  end;
  SetColor(Dark, B.Bg);
  MouseHide;
  if SingleFrame then
  begin
    WriteXY(B.X, B.Y, L + #$DA);
    for I := 1 to B.Len do Write(#$C4);
    TextColor(Lit);
    Write(#$BF + R);
    WriteXYF(B.X, B.Y + 1, Dark, L + #$B3);
    WriteF(Text, B.Caption);
    WriteF(Lit, #$B3 + R);
    TextColor(Dark);
    WriteXY(B.X, B.Y + 2, L + #$C0);
    TextColor(Lit);
    for I := 1 to Length(B.Caption) do Write(#$C4);
    Write(#$D9 + R);
  end
  else
  begin
    WriteXY(B.X, B.Y, L + #$D2);
    for I := 1 to B.Len do Write(#$C4);
    TextColor(Lit);
    Write(#$D3 + R);
    WriteXYF(B.X, B.Y + 1, Dark, L + #$CE);
    WriteF(Text, B.Caption);
    WriteF(Lit, #$D0 + R);
    TextColor(Dark);
    WriteXY(B.X, B.Y + 2, L + #$D4);
    TextColor(Lit);
    for I := 1 to Length(B.Caption) do Write(#$C4);
    Write(#$D5 + R);
  end;
  MouseShow;
  TextAttr := Attr;
end;

function MouseButton(var B: TButton): Boolean;
var
  X1, X2, Y: Byte;
  Dummy: Word;
begin
  MouseButton := False;
  X1 := B.X + Lo(WindMin) + 1;
  X2 := X1 + B.Len;
  Y := B.Y + Hi(WindMin) + 1;
  if (Mouse.MouseButton = 1) and (Y = MouseY) and (X1 < MouseX) and (X2 > MouseX) then
  begin
    if B.Clicked then
    begin
      B.Pressed := True;
      B.Clicked := False;
      DrawButton(B);
      repeat
      until (Mouse.MouseButton = 0) or (Y <> MouseY) or (X1 >= MouseX) or (X2 < MouseX);
      if (Y = MouseY) and (X1 < MouseX) and (X2 + 1 > MouseX) then MouseButton := True;
      B.Pressed := False;
      DrawButton(B);
    end
    else
      B.Clicked := True;
    B.Focused := True;
  end;
  B.SaveFocus := B.Focused;
end;

procedure InitButton2(Focus: Boolean; X1, Y1, X2, Y2, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2: string; var B: TButton2);
var
  Dummy: Word;
begin
  InitButton(Focus, X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitButton(not Focus, X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  DrawButton2(B);
end;

procedure DrawButton2(var B: TButton2);
begin
  DrawButton(B[1]);
  DrawButton(B[2]);
end;

procedure RestoreButton2(var B: TButton2);
begin
  B[1].Focused := B[1].SaveFocus;
  B[2].Focused := B[2].SaveFocus;
  B[1].OldFocused := not B[1].Focused;
  B[2].OldFocused := not B[2].Focused;
  DrawButton2(B);
end;

procedure ResetButton2(var B: TButton2);
begin
  B[1].OldFocused := True;
  B[2].OldFocused := True;
  B[1].Focused := False;
  B[2].Focused := False;
  DrawButton2(B);
end;

procedure HandleButton2(var Hit1, Hit2: Boolean; var Key: Word; var B: TButton2);
var
  OldKey: Word;
begin
  OldKey := Key;
  Hit1 := MouseButton(B[1]);
  B[2].Focused := not B[1].Focused;
  Hit2 := MouseButton(B[2]);
  B[1].Focused := not B[2].Focused;
  GetKey(Key);
  if OldKey = 9 then
  begin
    if Key = 9 then
    begin
      B[1].Focused := not B[1].Focused;
      B[2].Focused := not B[2].Focused;
    end;
  end
  else
  begin
    if Key = $435 then
    begin
      B[1].Focused := False;
      B[2].Focused := True;
    end;
    if Key = $433 then
    begin
      B[1].Focused := True;
      B[2].Focused := False;
    end;
  end;
  if Key = 13 then
    if B[1].Focused then
    begin
      Hit1 := True;
      B[1].Pressed := True;
    end
    else
    begin
      Hit2 := True;
      B[2].Pressed := True;
    end;
  DrawButton2(B);
  if Key = 13 then
  begin
    Delay(100);
    B[1].Pressed := False;
    B[2].Pressed := False;
    DrawButton2(B);
  end;
end;

procedure InitButton3(First: Boolean; X1, Y1, X2, Y2, X3, Y3, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3: string; var B: TButton3);
var
  F1, F2, F3: Boolean;
begin
  F1 := False;
  F2 := False;
  F3 := False;
  if First then F1 := True else F2 := True;
  InitButton(F1, X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitButton(F2, X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  InitButton(F3, X3, Y3, HotFg, Fg, Light, Bg, Cap3, B[3]);
  DrawButton3(B);
end;

procedure SetButton3(N: Byte; var B: TButton3);
begin
  B[1].SaveFocus := False;
  B[2].SaveFocus := False;
  B[3].SaveFocus := False;
  B[N].SaveFocus := True;
  RestoreButton3(B);
end;

procedure DrawButton3(var B: TButton3);
begin
  DrawButton(B[1]);
  DrawButton(B[2]);
  DrawButton(B[3]);
end;

procedure RestoreButton3(var B: TButton3);
begin
  B[1].Focused := B[1].SaveFocus;
  B[2].Focused := B[2].SaveFocus;
  B[3].Focused := B[3].SaveFocus;
  B[1].OldFocused := not B[1].Focused;
  B[2].OldFocused := not B[2].Focused;
  B[3].OldFocused := not B[3].Focused;
  DrawButton3(B);
end;

procedure ResetButton3(var B: TButton3);
begin
  B[1].OldFocused := True;
  B[2].OldFocused := True;
  B[3].OldFocused := True;
  B[1].Focused := False;
  B[2].Focused := False;
  B[3].Focused := False;
  DrawButton3(B);
end;

procedure HandleButton3(var Hit1, Hit2, Hit3: Boolean; var Key: Word; var B: TButton3);
var
  I: Integer;
  T: Boolean;
begin
  Hit1 := MouseButton(B[1]);
  if B[1].Focused then
  begin
    B[2].Focused := False;
    B[3].Focused := False;
  end;
  Hit2 := MouseButton(B[2]);
  if B[2].Focused then
  begin
    B[3].Focused := False;
    B[1].Focused := False;
  end;
  Hit3 := MouseButton(B[3]);
  if B[3].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
  end;
  GetKey(Key);
  case Key of
    $435:
      begin
        T := B[3].Focused;
        for I := 2 downto 1 do B[I + 1].Focused := B[I].Focused;
        B[1].Focused := T;
      end;
    $433:
      begin
        T := B[1].Focused;
        for I := 2 to 3 do B[I - 1].Focused := B[I].Focused;
        B[3].Focused := T;
      end;
  end;
  if Key = 13 then
  begin
    if B[1].Focused then
    begin
      Hit1 := True;
      B[1].Pressed := True;
    end;
    if B[2].Focused then
    begin
      Hit2 := True;
      B[2].Pressed := True;
    end;
    if B[3].Focused then
    begin
      Hit3 := True;
      B[3].Pressed := True;
    end;
  end;
  DrawButton3(B);
  if Key = 13 then
  begin
    Delay(100);
    B[1].Pressed := False;
    B[2].Pressed := False;
    B[3].Pressed := False;
    DrawButton3(B);
  end;
end;

procedure InitButton4(First: Boolean; X1, Y1, X2, Y2, X3, Y3, X4, Y4, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4: string; var B: TButton4);
var
  Dummy: Word;
begin
  InitButton(First, X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitButton(not First, X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  InitButton(not First, X3, Y3, HotFg, Fg, Light, Bg, Cap3, B[3]);
  InitButton(not First, X4, Y4, HotFg, Fg, Light, Bg, Cap4, B[4]);
  DrawButton4(B);
end;

procedure DrawButton4(var B: TButton4);
begin
  DrawButton(B[1]);
  DrawButton(B[2]);
  DrawButton(B[3]);
  DrawButton(B[4]);
end;

procedure SetButton4(N: Byte; var B: TButton4);
var
  F1, F2, F3, F4: Boolean;
begin
  F1 := False;
  F2 := False;
  F3 := False;
  F4 := False;
  case N of
    1: F1 := True;
    2: F2 := True;
    3: F3 := True;
    4: F4 := True;
  end;
  FocusButton(F1, B[1]);
  FocusButton(F2, B[2]);
  FocusButton(F3, B[3]);
  FocusButton(F4, B[4]);
end;

procedure RestoreButton4(var B: TButton4);
begin
  B[1].Focused := B[1].SaveFocus;
  B[2].Focused := B[2].SaveFocus;
  B[3].Focused := B[3].SaveFocus;
  B[4].Focused := B[4].SaveFocus;
  B[1].OldFocused := not B[1].Focused;
  B[2].OldFocused := not B[2].Focused;
  B[3].OldFocused := not B[3].Focused;
  B[4].OldFocused := not B[4].Focused;
  DrawButton4(B);
end;

procedure ResetButton4(var B: TButton4);
begin
  B[1].OldFocused := True;
  B[2].OldFocused := True;
  B[3].OldFocused := True;
  B[4].OldFocused := True;
  B[1].Focused := False;
  B[2].Focused := False;
  B[3].Focused := False;
  B[4].Focused := False;
  DrawButton4(B);
end;

procedure HandleButton4(var Hit1, Hit2, Hit3, Hit4: Boolean; var Key: Word; var B: TButton4);
var
  I: Integer;
  T: Boolean;
begin
  Hit1 := MouseButton(B[1]);
  if B[1].Focused then
  begin
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
  end;
  Hit2 := MouseButton(B[2]);
  if B[2].Focused then
  begin
    B[3].Focused := False;
    B[1].Focused := False;
    B[4].Focused := False;
  end;
  Hit3 := MouseButton(B[3]);
  if B[3].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[4].Focused := False;
  end;
  Hit4 := MouseButton(B[4]);
  if B[4].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
  end;
  GetKey(Key);
  case Key of
    $435:
      begin
        T := B[4].Focused;
        for I := 3 downto 1 do B[I + 1].Focused := B[I].Focused;
        B[1].Focused := T;
      end;
    $433:
      begin
        T := B[1].Focused;
        for I := 2 to 4 do B[I - 1].Focused := B[I].Focused;
        B[4].Focused := T;
      end;
  end;
  if Key = 13 then
  begin
    if B[1].Focused then
    begin
      Hit1 := True;
      B[1].Pressed := True;
    end;
    if B[2].Focused then
    begin
      Hit2 := True;
      B[2].Pressed := True;
    end;
    if B[3].Focused then
    begin
      Hit3 := True;
      B[3].Pressed := True;
    end;
    if B[4].Focused then
    begin
      Hit4 := True;
      B[4].Pressed := True;
    end;
  end;
  DrawButton4(B);
  if Key = 13 then
  begin
    Delay(100);
    B[1].Pressed := False;
    B[2].Pressed := False;
    B[3].Pressed := False;
    B[4].Pressed := False;
    DrawButton4(B);
  end;
end;

procedure InitButton5(N: Byte; X1, Y1, X2, Y2, X3, Y3, X4, Y4, X5, Y5, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4, Cap5: string; var B: TButton5);
var
  I: Byte;
  F: array[1..5] of Boolean;
begin
  for I := 1 to 5 do F[I] := False;
  F[N] := True;
  InitButton(F[1], X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitButton(F[2], X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  InitButton(F[3], X3, Y3, HotFg, Fg, Light, Bg, Cap3, B[3]);
  InitButton(F[4], X4, Y4, HotFg, Fg, Light, Bg, Cap4, B[4]);
  InitButton(F[5], X5, Y5, HotFg, Fg, Light, Bg, Cap5, B[5]);
  DrawButton5(B);
end;

procedure DrawButton5(var B: TButton5);
begin
  DrawButton(B[1]);
  DrawButton(B[2]);
  DrawButton(B[3]);
  DrawButton(B[4]);
  DrawButton(B[5]);
end;

procedure HandleButton5(var Hit1, Hit2, Hit3, Hit4, Hit5: Boolean; var Key: Word; var B: TButton5);
var
  I: Integer;
  T: Boolean;
begin
  Hit1 := MouseButton(B[1]);
  if B[1].Focused then
  begin
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
  end;
  Hit2 := MouseButton(B[2]);
  if B[2].Focused then
  begin
    B[1].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
  end;
  Hit3 := MouseButton(B[3]);
  if B[3].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
  end;
  Hit4 := MouseButton(B[4]);
  if B[4].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
    B[5].Focused := False;
  end;
  Hit5 := MouseButton(B[5]);
  if B[5].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
  end;
  GetKey(Key);
  case Key of
    $435:
      begin
        T := B[5].Focused;
        for I := 4 downto 1 do B[I + 1].Focused := B[I].Focused;
        B[1].Focused := T;
      end;
    $433:
      begin
        T := B[1].Focused;
        for I := 2 to 5 do B[I - 1].Focused := B[I].Focused;
        B[5].Focused := T;
      end;
  end;
  if Key = 13 then
  begin
    if B[1].Focused then
    begin
      Hit1 := True;
      B[1].Pressed := True;
    end;
    if B[2].Focused then
    begin
      Hit2 := True;
      B[2].Pressed := True;
    end;
    if B[3].Focused then
    begin
      Hit3 := True;
      B[3].Pressed := True;
    end;
    if B[4].Focused then
    begin
      Hit4 := True;
      B[4].Pressed := True;
    end;
    if B[5].Focused then
    begin
      Hit5 := True;
      B[5].Pressed := True;
    end;
  end;
  DrawButton5(B);
  if Key = 13 then
  begin
    Delay(100);
    for I := 1 to 5 do B[I].Pressed := False;
    DrawButton5(B);
  end;
end;

procedure RestoreButton5(var B: TButton5);
begin
  B[1].Focused := B[1].SaveFocus;
  B[2].Focused := B[2].SaveFocus;
  B[3].Focused := B[3].SaveFocus;
  B[4].Focused := B[4].SaveFocus;
  B[5].Focused := B[5].SaveFocus;
  B[1].OldFocused := not B[1].Focused;
  B[2].OldFocused := not B[2].Focused;
  B[3].OldFocused := not B[3].Focused;
  B[4].OldFocused := not B[4].Focused;
  B[5].OldFocused := not B[5].Focused;
  DrawButton5(B);
end;

procedure ResetButton5(var B: TButton5);
begin
  B[1].OldFocused := True;
  B[2].OldFocused := True;
  B[3].OldFocused := True;
  B[4].OldFocused := True;
  B[5].OldFocused := True;
  B[1].Focused := False;
  B[2].Focused := False;
  B[3].Focused := False;
  B[4].Focused := False;
  B[5].Focused := False;
  DrawButton5(B);
end;

procedure InitButton6(First: Boolean; X1, Y1, X2, Y2, X3, Y3, X4, Y4, X5, Y5, X6, Y6, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3, Cap4, Cap5, Cap6: string; var B: TButton6);
var
  Dummy: Word;
begin
  InitButton(First, X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitButton(not First, X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  InitButton(not First, X3, Y3, HotFg, Fg, Light, Bg, Cap3, B[3]);
  InitButton(not First, X4, Y4, HotFg, Fg, Light, Bg, Cap4, B[4]);
  InitButton(not First, X5, Y5, HotFg, Fg, Light, Bg, Cap5, B[5]);
  InitButton(not First, X6, Y6, HotFg, Fg, Light, Bg, Cap6, B[6]);
  DrawButton6(B);
end;

procedure DrawButton6(var B: TButton6);
begin
  DrawButton(B[1]);
  DrawButton(B[2]);
  DrawButton(B[3]);
  DrawButton(B[4]);
  DrawButton(B[5]);
  DrawButton(B[6]);
end;

procedure HandleButton6(var Hit1, Hit2, Hit3, Hit4, Hit5, Hit6: Boolean; var Key: Word; var B: TButton6);
var
  I: Integer;
  T: Boolean;
begin
  Hit1 := MouseButton(B[1]);
  if B[1].Focused then
  begin
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
    B[6].Focused := False;
  end;
  Hit2 := MouseButton(B[2]);
  if B[2].Focused then
  begin
    B[1].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
    B[6].Focused := False;
  end;
  Hit3 := MouseButton(B[3]);
  if B[3].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
    B[6].Focused := False;
  end;
  Hit4 := MouseButton(B[4]);
  if B[4].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
    B[5].Focused := False;
    B[6].Focused := False;
  end;
  Hit5 := MouseButton(B[5]);
  if B[5].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[6].Focused := False;
  end;
  Hit6 := MouseButton(B[6]);
  if B[6].Focused then
  begin
    B[1].Focused := False;
    B[2].Focused := False;
    B[3].Focused := False;
    B[4].Focused := False;
    B[5].Focused := False;
  end;
  GetKey(Key);
  case Key of
    $435:
      begin
        T := B[6].Focused;
        for I := 5 downto 1 do B[I + 1].Focused := B[I].Focused;
        B[1].Focused := T;
      end;
    $433:
      begin
        T := B[1].Focused;
        for I := 2 to 6 do B[I - 1].Focused := B[I].Focused;
        B[6].Focused := T;
      end;
  end;
  if Key = 13 then
  begin
    if B[1].Focused then
    begin
      Hit1 := True;
      B[1].Pressed := True;
    end;
    if B[2].Focused then
    begin
      Hit2 := True;
      B[2].Pressed := True;
    end;
    if B[3].Focused then
    begin
      Hit3 := True;
      B[3].Pressed := True;
    end;
    if B[4].Focused then
    begin
      Hit4 := True;
      B[4].Pressed := True;
    end;
    if B[5].Focused then
    begin
      Hit5 := True;
      B[5].Pressed := True;
    end;
    if B[6].Focused then
    begin
      Hit6 := True;
      B[6].Pressed := True;
    end;
  end;
  DrawButton6(B);
  if Key = 13 then
  begin
    Delay(100);
    for I := 1 to 6 do B[I].Pressed := False;
    DrawButton6(B);
  end;
end;

end.
