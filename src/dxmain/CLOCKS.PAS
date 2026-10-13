{$O+,F+,G+,S-,I-,X+,V-}
unit Clocks;
{ Overlay 033a: two stopwatches ("Uhren") }

interface

procedure Stopwatch;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Status, Dialogs, ScrSave;

type
  Str2 = string[2];
  TBtn = record
    X, Y: Byte;
    HotFg, Fg: Byte;
    Len: Byte;
    Light, Bg: Byte;
    Pressed, Focused: Boolean;
    OldPressed, OldFocused: Boolean;
    Caption: string;
    SaveFocus: Boolean;
  end;
  TBtn3 = array[1..3] of TBtn;

procedure DrawBtn(var B: TBtn); forward;

procedure InitBtn(Focus: Boolean; X, Y, HotFg, Fg, Light, Bg: Byte; Caption: string; var B: TBtn);
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
  B.SaveFocus := B.Focused;
  DrawBtn(B);
end;

procedure DrawBtn(var B: TBtn);
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

function MouseBtn(var B: TBtn): Boolean;
var
  X1, X2, Y: Byte;
begin
  MouseBtn := False;
  X1 := B.X + Lo(WindMin) + 1;
  X2 := X1 + B.Len;
  Y := B.Y + Hi(WindMin) + 1;
  if (MouseButton = 1) and (Y = MouseY) and (X1 < MouseX) and (X2 > MouseX) then
  begin
    B.Pressed := True;
    B.Focused := True;
    MouseBtn := True;
  end;
  B.SaveFocus := B.Focused;
end;

procedure DrawBtn3(var B: TBtn3); forward;

procedure InitBtn3(First: Boolean; X1, Y1, X2, Y2, X3, Y3, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2, Cap3: string; var B: TBtn3);
var
  F1, F2, F3: Boolean;
begin
  F1 := False;
  F2 := False;
  F3 := False;
  if First then F1 := True else F2 := True;
  InitBtn(F1, X1, Y1, HotFg, Fg, Light, Bg, Cap1, B[1]);
  InitBtn(F2, X2, Y2, HotFg, Fg, Light, Bg, Cap2, B[2]);
  InitBtn(F3, X3, Y3, HotFg, Fg, Light, Bg, Cap3, B[3]);
  DrawBtn3(B);
end;

procedure DrawBtn3(var B: TBtn3);
begin
  DrawBtn(B[1]);
  DrawBtn(B[2]);
  DrawBtn(B[3]);
end;

procedure RestoreBtn3(var B: TBtn3);
begin
  B[1].Focused := B[1].SaveFocus;
  B[2].Focused := B[2].SaveFocus;
  B[3].Focused := B[3].SaveFocus;
  B[1].OldFocused := not B[1].Focused;
  B[2].OldFocused := not B[2].Focused;
  B[3].OldFocused := not B[3].Focused;
  DrawBtn3(B);
end;

procedure ResetBtn3(var B: TBtn3);
begin
  B[1].OldFocused := True;
  B[2].OldFocused := True;
  B[3].OldFocused := True;
  B[1].Focused := False;
  B[2].Focused := False;
  B[3].Focused := False;
  DrawBtn3(B);
end;

procedure HandleBtn3(var Hit1, Hit2, Hit3: Boolean; var Key: Word; var B: TBtn3);
var
  I: Integer;
  T: Boolean;
begin
  B[1].OldFocused := B[1].Focused;
  B[1].OldPressed := B[1].Pressed;
  B[2].OldFocused := B[2].Focused;
  B[2].OldPressed := B[2].Pressed;
  B[3].OldFocused := B[3].Focused;
  B[3].OldPressed := B[3].Pressed;
  Hit1 := MouseBtn(B[1]);
  if B[1].Focused then
  begin
    B[2].Focused := False;
    B[3].Focused := False;
  end;
  Hit2 := MouseBtn(B[2]);
  if B[2].Focused then
  begin
    B[1].Focused := False;
    B[3].Focused := False;
  end;
  Hit3 := MouseBtn(B[3]);
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
  DrawBtn3(B);
end;

type
  TColors = array[0..64] of Byte;
  TBlk26 = array[0..25] of Byte;
  TBlk32 = array[0..31] of Byte;
  TBlk48 = array[0..47] of Byte;
  TProg = record
    W: Word;
    S: string[20];
  end;
  TConfig = record
    Id: string;
    Colors: TColors;
    Colors2: TColors;
    S182, S203: string[128];
    W284: Word;
    S286, S2D6: string[79];
    S326: string[12];
    B333: Byte;
    W334: Word;
    Drives: array[1..26] of Boolean;
    Progs: array[1..9] of TProg;
    B41F: Byte;
    S420, S470: string[79];
    S4C0, S511: string[80];
    Blk562: TBlk32;
    B582, B583: Byte;
    L584, L588, L58C, L590: Longint;
    B594: Byte;
    Blk595: TBlk48;
    Pw: string[11];
    S1, S2, S3: string[77];
    Prn1, Prn2: string[12];
    B6D5, B6D6, B6D7, B6D8, B6D9, B6DA, B6DB, B6DC, B6DD, B6DE, B6DF: Byte;
    W6E0: Word;
    Blk6E2: TBlk26;
    S6FC: string[12];
    B709, B70A, B70B: Byte;
    B70C, B70D, B70E, B70F, B710, B711: Byte;
  end;

procedure SaveClocks;
var
  F: file of TConfig;
  Rec: TConfig;
  Err: Boolean;
begin
  Err := False;
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Rec);
  Close(F);
  if (IOResult = 0) and (Rec.Id = IniId) then
  begin
    Rec.B582 := CfgBABC;
    Rec.B583 := CfgBABD;
    Rec.L584 := CfgLABE;
    Rec.L588 := CfgLAC2;
    Rec.L58C := CfgLAC6;
    Rec.L590 := CfgLACA;
    Rewrite(F);
    Write(F, Rec);
    Close(F);
    if IOResult <> 0 then Err := True;
  end
  else
    Err := True;
  if Err then
    MsgBox('Uhren k'#$94'nnen nicht gespeichert werden!', IniName + ' ist fehlerhaft oder nicht vorhanden!');
end;

function Two(N: Word): Str2;
var
  S: Str2;
begin
  Str(N, S);
  if N < 10 then S := '0' + S;
  Two := S;
end;

procedure Beep;
begin
  Sound(2500);
  Delay(60);
  NoSound;
end;

procedure Stopwatch;
var
  H, H1, H2, M, M1, M2, S, S1, S2, C, C1, C2: Word;
  Key: Word;
  BA, BB: TBtn3;
  A1, A2, A3, B1, B2, B3: Boolean;
  Done: Boolean;
  T1H, T1M, T1S, T1C, T2H, T2M, T2S, T2C: Str2;
  Now, Diff: Longint;
  Active: Boolean;
begin
  OpenDialog;
  B2 := False;
  B1 := False;
  B3 := False;
  T1H := '00';
  T1M := '00';
  T1S := '00';
  T1C := '00';
  Frame(10, 7, 59, 13, 11, 3, 0, 1);
  Frame(21, 9, 13, 4, 11, 3, 1, 0);
  Frame(46, 9, 13, 4, 11, 3, 1, 0);
  Window(11, 8, 80, 25);
  WriteXY(16, 1, 'Uhr 1');
  WriteXY(41, 1, 'Uhr 2');
  WriteXY(28, 3, 'Anfang');
  WriteXYF(13, 3, 1, '00:00:00:00');
  WriteXYF(38, 3, 1, '00:00:00:00');
  WriteXY(29, 4, 'Ende');
  WriteXYF(13, 4, 1, '00:00:00:00');
  WriteXYF(38, 4, 1, '00:00:00:00');
  WriteXY(29, 5, 'Zeit');
  WriteXYF(13, 5, 11, '00:00:00:00');
  WriteXYF(38, 5, 11, '00:00:00:00');
  WriteXY(29, 6, 'Zwi.');
  WriteXYF(13, 6, 11, '00:00:00:00');
  WriteXYF(38, 6, 11, '00:00:00:00');
  InitBtn3(True, 3, 8, 21, 8, 42, 8, 14, 0, 11, 3, '   Start 1   ', ' Zwischenzeit 1 ', '   Stop 1   ', BA);
  InitBtn3(True, 3, 11, 21, 11, 42, 11, 14, 0, 11, 3, '   Start 2   ', ' Zwischenzeit 2 ', '   Stop 2   ', BB);
  WriteXY(2, 9, #$18);
  WriteXY(2, 12, #$19);
  ResetBtn3(BB);
  Active := True;
  if CfgBABC <> 0 then
  begin
    Diff := CfgLABE;
    H := Diff div 360000;
    Diff := Diff mod 360000;
    M := Diff div 6000;
    Diff := Diff mod 6000;
    S := Diff div 100;
    C := Diff mod 100;
    WriteXYF(13, 3, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
    Diff := CfgLAC6;
    H := Diff div 360000;
    Diff := Diff mod 360000;
    M := Diff div 6000;
    Diff := Diff mod 6000;
    S := Diff div 100;
    C := Diff mod 100;
    WriteXYF(13, 6, 11, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
    BA[1].Pressed := True;
  end
  else
    BA[3].Pressed := True;
  if CfgBABD <> 0 then
  begin
    Diff := CfgLAC2;
    H := Diff div 360000;
    Diff := Diff mod 360000;
    M := Diff div 6000;
    Diff := Diff mod 6000;
    S := Diff div 100;
    C := Diff mod 100;
    WriteXYF(38, 3, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
    Diff := CfgLACA;
    H := Diff div 360000;
    Diff := Diff mod 360000;
    M := Diff div 6000;
    Diff := Diff mod 6000;
    S := Diff div 100;
    C := Diff mod 100;
    WriteXYF(38, 6, 11, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
    BB[1].Pressed := True;
  end
  else
    BB[3].Pressed := True;
  MouseShow;
  Done := False;
  DrawBtn3(BA);
  DrawBtn3(BB);
  repeat
    if Active then HandleBtn3(A1, A2, A3, Key, BA)
    else HandleBtn3(B1, B2, B3, Key, BB);
    if ((Key = $438) or MouseOn(19, 14, 66)) and Active then
    begin
      ResetBtn3(BA);
      RestoreBtn3(BB);
      Active := False;
    end;
    if ((Key = $430) or MouseOn(16, 14, 66)) and not Active then
    begin
      RestoreBtn3(BA);
      ResetBtn3(BB);
      Active := True;
    end;
    if IsCancel(Key) or MouseOutside(10, 70, 7, 21) then Done := True;
    GetTime(H, M, S, C);
    if A1 and (CfgBABC = 0) then
    begin
      MouseHide;
      CfgLABE := H;
      CfgLABE := ((CfgLABE * 60 + M) * 60 + S) * 100 + C;
      WriteXYF(13, 3, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
      WriteXYF(13, 4, 1, '00:00:00:00');
      WriteXYF(13, 6, 11, '00:00:00:00');
      CfgBABC := 1;
      BA[3].Pressed := False;
      DrawBtn3(BA);
      MouseShow;
      Beep;
    end;
    if B1 and (CfgBABD = 0) then
    begin
      MouseHide;
      CfgLAC2 := H;
      CfgLAC2 := ((CfgLAC2 * 60 + M) * 60 + S) * 100 + C;
      WriteXYF(38, 3, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
      WriteXYF(38, 4, 1, '00:00:00:00');
      WriteXYF(38, 6, 11, '00:00:00:00');
      CfgBABD := 1;
      BB[3].Pressed := False;
      DrawBtn3(BB);
      MouseShow;
      Beep;
    end;
    Now := H;
    Now := ((Now * 60 + M) * 60 + S) * 100 + C;
    if Now >= CfgLABE then Diff := Now - CfgLABE
    else Diff := Now + 8640000 - CfgLABE;
    H1 := Diff div 360000;
    Diff := Diff mod 360000;
    M1 := Diff div 6000;
    Diff := Diff mod 6000;
    S1 := Diff div 100;
    C1 := Diff mod 100;
    T1H := Two(H1);
    T1M := Two(M1);
    T1C := Two(C1);
    T1S := Two(S1);
    if CfgBABC <> 0 then
      WriteXYF(13, 5, 11, T1H + ':' + T1M + ':' + T1S + ':' + T1C);
    if A2 then
    begin
      if CfgBABC <> 0 then
      begin
        MouseHide;
        WriteXYF(13, 6, 11, T1H + ':' + T1M + ':' + T1S + ':' + T1C);
        MouseShow;
        Beep;
        CfgLAC6 := Diff;
      end;
      repeat
        Idle;
      until MouseButton = 0;
      BA[2].Pressed := False;
      DrawBtn3(BA);
    end;
    if Now >= CfgLAC2 then Diff := Now - CfgLAC2
    else Diff := Now + 8640000 - CfgLAC2;
    H2 := Diff div 360000;
    Diff := Diff mod 360000;
    M2 := Diff div 6000;
    Diff := Diff mod 6000;
    S2 := Diff div 100;
    C2 := Diff mod 100;
    T2H := Two(H2);
    T2M := Two(M2);
    T2C := Two(C2);
    T2S := Two(S2);
    if CfgBABD <> 0 then
      WriteXYF(38, 5, 11, T2H + ':' + T2M + ':' + T2S + ':' + T2C);
    if B2 then
    begin
      if CfgBABD <> 0 then
      begin
        MouseHide;
        WriteXYF(38, 6, 11, T2H + ':' + T2M + ':' + T2S + ':' + T2C);
        CfgLACA := Diff;
        MouseShow;
        Beep;
      end;
      repeat
        Idle;
      until MouseButton = 0;
      BB[2].Pressed := False;
      DrawBtn3(BB);
    end;
    if A3 and (CfgBABC <> 0) then
    begin
      MouseHide;
      CfgBABC := 0;
      WriteXYF(13, 4, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
      BA[1].Pressed := False;
      DrawBtn3(BA);
      MouseShow;
      Beep;
    end;
    if B3 and (CfgBABD <> 0) then
    begin
      MouseHide;
      CfgBABD := 0;
      WriteXYF(38, 4, 1, Two(H) + ':' + Two(M) + ':' + Two(S) + ':' + Two(C));
      BB[1].Pressed := False;
      DrawBtn3(BB);
      MouseShow;
      Beep;
    end;
  until Done;
  SaveClocks;
  PopScreen(DlgStack);
  repeat
    Idle;
  until MouseButton = 0;
end;

end.
