{$O+,F+,G+,S-,I-}
unit Saver;

interface

type
  TStar = record
    Kind: Byte;
    X, Y: Byte;
    Ch: Char;
    Visible: Boolean;
  end;
  TStars = array[1..60] of TStar;
  PStars = ^TStars;

var
  Stars: PStars;
  StarCount: Word;

procedure ScreenSaver;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Palette, Buttons, Times, Passwd, Fonts,
  Dialogs, Execute;

function CheckPassword: Boolean;
var
  P: string[12];
  Key: Word;
begin
  CheckPassword := False;
  Screen.GetKey(Key);
  if not PasswordOn then
  begin
    CheckPassword := True;
    Exit;
  end;
  OpenDialog;
  P := '';
  Frame(20, 8, 40, 7, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 40, 'Programm aktivieren:');
  WriteCenterXY(1, 4, 40, 'Bitte geben Sie das Pa'#$E1'wort ein:');
  WriteXYB(15, 6, 2, '            ');
  MouseShow;
  P := ReadPassword(15, 6);
  PopScreen(DlgStack);
  repeat
  until Mouse.MouseButton = 0;
  if P = Password then
    CheckPassword := True
  else
    WriteXYFB(20, 10, 7, 0, 'Falsches Pa'#$E1'wort angegeben!');
end;

procedure Twinkle(var S: TStar); forward;

procedure WaitStars(T: LongInt);
var
  I: Integer;
  KP: Boolean;
  Start, Now: LongInt;
begin
  Start := TimeCount;
  T := T div 10000;
  I := 0;
  repeat
    Inc(I);
    if I = 61 then I := 1;
    if (Mouse.MouseButton = 1) and (Stars^[I].X = MouseX) and (Stars^[I].Y = MouseY) and
      Stars^[I].Visible then
    begin
      Inc(StarCount);
      Twinkle(Stars^[I]);
    end;
    KP := KeyPressed;
    Now := TimeCount;
  until (Abs(Now - Start) > T) or KP or (Mouse.MouseButton = 2) or
    not MouseSaver and (MouseMoved = 0);
end;

procedure Wait(T: LongInt);
var
  I: Integer;
  KP: Boolean;
  Start, Now: LongInt;
begin
  Start := TimeCount;
  T := T div 10000;
  repeat
    KP := KeyPressed;
    Now := TimeCount;
  until (Abs(Now - Start) > T) or KP or (Mouse.MouseButton = 2);
end;

procedure ShortWait;
var
  KP: Boolean;
  Start, Now: LongInt;
begin
  Start := TimeCount;
  repeat
    KP := KeyPressed;
    Now := TimeCount;
  until (Abs(Now - Start) > 5) or KP or (Mouse.MouseButton = 2);
end;

procedure Twinkle(var S: TStar);
begin
  if not S.Visible then Exit;
  S.Visible := False;
  MouseHide;
  WriteXY(S.X, S.Y, #$F9);
  Wait(30000);
  WriteXY(S.X, S.Y, #4);
  Wait(30000);
  TextColor(2);
  WriteXY(S.X, S.Y, '*');
  Wait(30000);
  WriteXY(S.X, S.Y, #15);
  Wait(60000);
  WriteXY(S.X, S.Y, ' ');
  TextColor(11);
  MouseShow;
end;

procedure Burst(var S: TStar);
begin
  if not S.Visible then Exit;
  S.Visible := False;
  if S.Kind > 6 then
  begin
    TextColor(2);
    MouseHide;
    WriteXY(S.X, S.Y, #$F9#8);
    MouseShow;
    WaitStars(20000);
  end
  else
  begin
    MouseHide;
    WriteXY(S.X, S.Y, #$F9);
    MouseShow;
    WaitStars(30000);
    MouseHide;
    WriteXY(S.X, S.Y, #4);
    MouseShow;
    WaitStars(30000);
    TextColor(2);
    MouseHide;
    WriteXY(S.X, S.Y, '*');
    MouseShow;
    WaitStars(30000);
    MouseHide;
    WriteXY(S.X, S.Y, #15);
    MouseShow;
    WaitStars(60000);
  end;
  MouseHide;
  WriteXY(S.X, S.Y, ' ');
  MouseShow;
  TextColor(11);
end;

procedure PlaceStar(X, Y: Byte; var S: TStar);
begin
  if S.Visible then Exit;
  S.X := X;
  S.Y := Y;
  MouseHide;
  WriteXY(S.X, S.Y, S.Ch);
  MouseShow;
  S.Visible := True;
end;

procedure InitStar(N: Byte; var S: TStar);
begin
  S.Kind := N;
  if Odd(S.Kind) then
    S.Ch := #$FA
  else
    S.Ch := #$F9;
  S.Visible := False;
end;

procedure Curtain; forward;
procedure FadeScreen; forward;
procedure ExternalSaver; forward;
procedure BlankScreen; forward;

procedure ScreenSaver;
var
  I: Integer;
  Key: Word;
  S1, S2: string;
  T1, T2: LongInt;
  Rate: Real;
  Btn: TButton;
  BtnHit, X1, HadCursor: Boolean;
  SavedMap: array[1..28, 1..80] of Byte;
  SaveThin: Boolean;
  Ok: Boolean;
  Dummy: array[1..8] of Byte;
  H, M, S, Hund: Word;
begin
  MouseMoved := 0;
  if not SaverExt and not SaverStars and not SaverDot then
    BlankScreen
  else if SaverExt then
    ExternalSaver
  else
  begin
    OpenDialog;
    Window(1, 1, 80, ScreenRows);
    SetColor(11, 0);
    StarCount := 0;
    Move(MouseMap, SavedMap, SizeOf(SavedMap));
    InitMouse;
    Ok := False;
    if CursorOn then
    begin
      HideCursor;
      HadCursor := True;
    end
    else
      HadCursor := False;
    if FadeOn then FadeScreen else Curtain;
    SetBorder(0);
    if SaverDot then
    begin
      ClrScr;
      repeat
      until Mouse.MouseButton = 0;
      Delay(400);
      MouseMoved := 1;
      TextColor(10);
      repeat
        ShortWait;
        ShortWait;
        ShortWait;
        ShortWait;
        ShortWait;
        ShortWait;
        ShortWait;
        ShortWait;
        WriteXY(80, ScreenRows - 1, #$FA);
        ShortWait;
        WriteXY(80, ScreenRows - 1, #$F9);
        ShortWait;
        WriteXY(80, ScreenRows - 1, #4);
        ShortWait;
        WriteXY(80, ScreenRows - 1, '*');
        ShortWait;
        WriteXY(80, ScreenRows - 1, #15);
        ShortWait;
        WriteXY(80, ScreenRows - 1, '*');
        ShortWait;
        WriteXY(80, ScreenRows - 1, #4);
        ShortWait;
        WriteXY(80, ScreenRows - 1, #$F9);
        ShortWait;
        WriteXY(80, ScreenRows - 1, #$FA);
        ShortWait;
        WriteXY(80, ScreenRows - 1, ' ');
        if Screen.GetKey(Key) or (Mouse.MouseButton <> 0) or (MouseMoved = 0) then
        begin
          MouseShow;
          Ok := CheckPassword;
          MouseHide;
        end;
      until Ok;
      MouseShow;
    end
    else
    begin
      GetMem(Stars, SizeOf(TStars));
      Randomize;
      GetTime(H, M, S, Hund);
      T1 := H;
      T1 := (T1 * 60 + M) * 60 + S;
      if not MouseSaver then
        Delay(400)
      else
      begin
        ScreenMask := $7000;
        CursorMask := $07E8;
        MouseDefCursor;
        MouseShow;
      end;
      repeat
      until Mouse.MouseButton = 0;
      MouseMoved := 1;
      for I := 1 to 60 do
      begin
        InitStar(I, Stars^[I]);
        PlaceStar(Random(79) + 1, Random(ScreenRows) + 1, Stars^[I]);
        WaitStars(30000);
      end;
      repeat
        Randomize;
        PlaceStar(Random(79) + 1, Random(ScreenRows) + 1, Stars^[Random(60) + 1]);
        WaitStars(20000);
        Burst(Stars^[Random(60) + 1]);
        if Screen.GetKey(Key) or (Mouse.MouseButton = 2) or not MouseSaver and (MouseMoved = 0) then
        begin
          if not MouseSaver then MouseShow;
          Ok := CheckPassword;
          MouseMoved := 1;
          if not MouseSaver then MouseHide;
        end;
      until Ok;
      if not MouseSaver then
        MouseShow
      else
      begin
        ScreenMask := $40FF;
        CursorMask := $4C00;
        MouseDefCursor;
      end;
      GetTime(H, M, S, Hund);
      T2 := H;
      T2 := (T2 * 60 + M) * 60 + S;
      if T2 >= T1 then
        T1 := T2 - T1
      else
        T1 := T2 + 86400 - T1;
      repeat
      until Mouse.MouseButton = 0;
      FreeMem(Stars, SizeOf(TStars));
      if MouseSaver then
      begin
        SaveThin := ThinButtons;
        if not G96 and not SaveThin then ThinButtons := True;
        MouseHide;
        Frame(30, 14, 16, 3, 11, 3, 0, 1);
        ClrScr;
        Window(19, 7, 80, ScreenRows);
        InitButton(False, 16, 9, 14, 14, 11, 3, '  OK  ', Btn);
        Str(StarCount, S1);
        SetColor(14, 0);
        WriteCenterXY(2, 2, 38, 'Sie haben ' + S1 + ' Sternchen geschafft!');
        T2 := T1 div 60;
        Str(T2, S1);
        S1 := S1 + ':';
        T2 := T1 mod 60;
        Str(T2, S2);
        if Length(S2) = 1 then S2 := '0' + S2;
        S1 := S1 + S2;
        WriteCenterXY(2, 4, 38, 'Ihre Zeit: ' + S1 + ' Min.');
        if T1 <> 0 then
          Rate := StarCount * 60 / T1
        else
          Rate := 0;
        Str(Rate:1:2, S1);
        WriteCenterXY(2, 6, 38, 'Das sind ' + S1 + ' Sternchen/Min.');
        MouseShow;
        TextBackground(7);
        repeat
          BtnHit := Buttons.MouseButton(Btn);
          Screen.GetKey(Key);
        until (Key <> 0) or BtnHit or (Mouse.MouseButton = 2);
        repeat
        until Mouse.MouseButton = 0;
        ThinButtons := SaveThin;
      end;
    end;
    PopScreen(DlgStack);
    SetBorder(BorderColor);
    if HadCursor then ShowCursor;
    Move(SavedMap, MouseMap, SizeOf(MouseMap));
  end;
end;

procedure Curtain;
var
  X, X2: Byte;
  D, Hund: Word;
  W, H, Y, C: Integer;
begin
  GetTime(D, D, D, Hund);
  if Odd(Hund) then
  begin
    for X := 40 to 79 do
    begin
      X2 := 80 - X;
      for Y := 1 to ScreenRows do
      begin
        GotoXY(X2, Y);
        Write(#$B3' ');
        GotoXY(X, Y);
        Write(' '#$B3);
      end;
    end;
    ClrScr;
  end
  else
  begin
    W := 1;
    C := 40;
    SetBorder(BorderColor);
    repeat
      H := ScreenRows * W div 80;
      Y := (ScreenRows - H) div 2 + 1;
      Window(C, Y, C + W, Y + H);
      ClrScr;
      Delay(5);
      C := C - 1;
      W := W + 2;
    until C < 0;
    Window(1, 1, 80, ScreenRows);
    SetBorder(0);
  end;
end;

procedure FadeScreen;
var
  Save: array[0..15] of TRGB;
  I: Byte;
begin
  Move(Pal2, Save, SizeOf(Save));
  FadeOut;
  Window(1, 1, 80, ScreenRows);
  SetColor(11, 0);
  ClrScr;
  SetBorder(0);
  Move(Save, Pal2, SizeOf(Pal2));
  for I := 0 to 15 do
    SetRGB(I, Pal2[I]);
end;

procedure ExternalSaver;
var
  Key: Word;
  SavedMap: array[1..28, 1..80] of Byte;
  SaveThin, HadCursor: Boolean;
begin
  MouseMoved := 0;
  Mouse.MouseButton := 0;
  Move(MouseMap, SavedMap, SizeOf(SavedMap));
  HadCursor := CursorOn;
  if MaxAvail < $F000 then
  begin
    ErrorBox('Es ist zuwenig Hauptspeicher frei!', 'Der Bildschirmschoner kann nicht gestartet werden.');
    Exit;
  end;
  OpenDialog;
  if FadeOn then FadeScreen;
  ResetMouse;
  TextColor(0);
  ShowCursor;
  Window(1, 1, 80, ScreenRows);
  SaveThin := ThinButtons;
  ThinButtons := True;
  SetBorder(0);
  repeat
    RunProg(HomeDir + SaverProg, '');
  until CheckPassword;
  ThinButtons := SaveThin;
  Screen.GetKey(Key);
  MouseMoved := 1;
  HideCursor;
  if BigCursor then
    TextMode(CO80 + Font8x8)
  else
    TextMode(CO80);
  SetPalRegs(TPalRegs(PalRegs));
  SetPal2;
  if not ThinButtons then
    InitFont
  else
  begin
    ThinButtons := False;
    InitPlainFont;
    ThinButtons := True;
  end;
  Move(SavedMap, MouseMap, SizeOf(MouseMap));
  ResetMouse;
  InstallHandler;
  MouseShow;
  MouseYRange(0, ScreenRows - 1);
  PopScreen(DlgStack);
  MouseMoved := 0;
  Mouse.MouseButton := 0;
  MouseTextCursor;
  if HadCursor then ShowCursor;
end;

procedure BlankScreen;
var
  SavedMap: array[1..28, 1..80] of Byte;
  Key: Word;
  R: Registers;
begin
  OpenDialog;
  Move(MouseMap, SavedMap, SizeOf(SavedMap));
  if FadeOn then
    FadeScreen
  else
  begin
    Window(1, 1, 80, ScreenRows);
    TextBackground(0);
    ClrScr;
  end;
  repeat
    Port[$3D4] := $17;
    Port[$3D5] := Port[$3D5] and $7F;
    repeat
    until Screen.GetKey(Key);
    Sound(2000);
    Delay(100);
    NoSound;
    ClrScr;
    Port[$3D5] := Port[$3D5] or $80;
    R.AH := 0;
    R.AL := 3;
    Intr($10, R);
    SetPal2;
    if not ThinButtons then
      InitFont
    else
    begin
      ThinButtons := False;
      InitPlainFont;
      ThinButtons := True;
    end;
  until CheckPassword;
  ResetMouse;
  InstallHandler;
  Move(SavedMap, MouseMap, SizeOf(MouseMap));
  MouseDefCursor;
  MouseShow;
  MouseYRange(0, ScreenRows - 1);
  PopScreen(DlgStack);
  MouseMoved := 0;
  Mouse.MouseButton := 0;
end;

end.
