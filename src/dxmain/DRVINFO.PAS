{$O+,F+,G+,S-,I+,X+,V-}
unit DrvInfo;
{ Drive overview: total/free space of all selected drives, drive selection bar }

interface

procedure DriveInfo;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status,
  Help, CDAudio, U1F7B, U129A, U0365;

procedure DriveInfo;
var
  S: string;
  R: Real;
  N: Word;
  Attr: Word;
  X, Y: Word;
  Count: Word;
  J: Integer;
  I: Longint;
  Dummy: Longint;
  Size, Free: Longint;
  TotSize, TotFree: Real;
  Key: Word;
  SX, SY: Byte;
  Regs: Registers;
  Path: string[79];
  SR: SearchRec;
  Valid: array[1..26] of Boolean;
  Bg, Fg, BarFg: Byte;
  Drives: array[1..26] of Boolean;
  C: Char;
  CDDrv: Byte;
  Quit, Changed, HasCD: Boolean;
  Left, Right: Char;
  ChgL, ChgR: Boolean;
  B1, B2: TButton;
  W: TWinState;
label
  L2, L3;

{$I-}
function ReadDrives: Boolean;
var
  F: file of TConfig;
  P: ^TConfig;
begin
  Assign(F, HomeDir + IniName);
  GetMem(P, SizeOf(TConfig));
  ReadDrives := True;
  Reset(F);
  Read(F, P^);
  Close(F);
  if (IOResult = 0) and (P^.Id = IniId) then
    Move(P^.Drives, Drives, 26)
  else
    ReadDrives := False;
  FreeMem(P, SizeOf(TConfig));
end;

procedure WriteDrives;
var
  F: file of TConfig;
  P: ^TConfig;
  Err: Boolean;
begin
  Assign(F, HomeDir + IniName);
  GetMem(P, SizeOf(TConfig));
  Err := False;
  Reset(F);
  Read(F, P^);
  Close(F);
  if (IOResult = 0) and (P^.Id = IniId) then
  begin
    Move(Drives, P^.Drives, 26);
    Rewrite(F);
    Write(F, P^);
    Close(F);
    if IOResult <> 0 then Err := True;
  end
  else
    Err := True;
  if Err then
    MsgBox('Ver'#$84'nderungen k'#$94'nnen nicht gespeichert werden!',
      IniName + ' ist fehlerhaft oder nicht vorhanden!');
  FreeMem(P, SizeOf(TConfig));
  WaitRelease;
end;
{$I+}

procedure Bar(X, Y: Byte; Ch: Char);
var
  I: Integer;
  SX, SY: Word;
  A: Word;
begin
  A := TextAttr;
  TextColor(BarFg);
  SX := WhereX;
  SY := WhereY;
  GotoXY(X, Y);
  for I := 1 to N do Write(Ch);
  GotoXY(SX, SY);
  TextAttr := A;
end;

procedure PctBar(Pct: Word; X, Y: Byte; Ch: Char);
var
  I: Integer;
  SX, SY: Word;
  A: Word;
begin
  A := TextAttr;
  SX := WhereX;
  SY := WhereY;
  TextColor(14);
  GotoXY(X, Y);
  Pct := Integer(N * Pct) div 100;
  for I := 1 to Pct do Write(Ch);
  GotoXY(SX, SY);
  TextAttr := A;
end;

procedure DrawDrives;
var
  W: TWinState;
  I: Byte;
begin
  SaveWin(W);
  MouseHide;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 3);
  for I := 1 to 26 do
    if Drives[I] then
      WriteXYFB(I * 3 - 1, 1, 14, 4, ' ' + Chr(I + 64) + ' ')
    else
      WriteXY(I * 3 - 1, 1, ' ' + Chr(I + 64) + ' ');
  RestoreWin(W);
  MouseShow;
end;

function ClickDrive: Boolean;
var
  W: TWinState;
  I: Byte;
begin
  SaveWin(W);
  ClickDrive := False;
  I := (MouseX - 2) div 3 + 1;
  MouseHide;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 3);
  WriteXYFB(I * 3 - 1, 1, 14, 3, '  ' + Chr(I + 64));
  MouseShow;
  repeat
    Idle;
  until (I * 3 - 1 > MouseX) or (I * 3 + 1 < MouseX) or (ScreenRows <> MouseY) or (MouseButton = 0);
  if (I * 3 - 1 <= MouseX) and (I * 3 + 1 >= MouseX) and (ScreenRows = MouseY) and Valid[I] then
  begin
    Drives[I] := not Drives[I];
    ClickDrive := True;
  end;
  RestoreWin(W);
  DrawDrives;
  WaitRelease;
end;

begin
  Bg := 1;
  Left := Panels[1].Path[1];
  Right := Panels[2].Path[1];
  ChgL := False;
  ChgR := False;
  Fg := 11;
  BarFg := 0;
  InitMouse;
  LastTime := '';
  LastDate := '';
  N := 40;
  Changed := False;
  HasCD := False;
  CDDrv := 0;
  X := WhereX;
  Y := WhereY;
  SX := StatX;
  SY := StatY;
  StatY := 2;
  StatX := 74;
  Attr := TextAttr;
  SetColor(Fg, Bg);
  if not ReadDrives then
  begin
    Move(Valid, Drives, 26);
    Drives[1] := False;
    Drives[2] := False;
  end;
  Regs.AX := $1500;
  Regs.BX := 0;
  Intr($2F, Regs);
  if Regs.BX <> 0 then
  begin
    CDDrv := Regs.CL + 1;
    Valid[Regs.CL + 1] := True;
  end;
  for C := 'A' to 'Z' do
    if DriveValid(C) then
      Valid[Ord(C) - 64] := True
    else
    begin
      Valid[Ord(C) - 64] := False;
      Drives[Ord(C) - 64] := False;
    end;
  OpenDialog;
  Window(1, 1, 80, ScreenRows);
  TextBackground(3);
  ClrEol;
  GotoXY(1, 2);
  ClrEol;
  GotoXY(1, 3);
  ClrEol;
  InitButton(True, 1, 1, 14, 0, 11, 3, Left + ':', B1);
  InitButton(True, 31, 1, 14, 0, 11, 3, Right + ':', B2);
  Frame(38, 1, 41, 1, 11, 3, 0, 0);
  WriteF(0, ' Alt-F2 = Rechts');
  Frame(8, 1, 20, 1, 11, 3, 0, 0);
  WriteF(0, ' Alt-F1 = Links');
  SetColor(0, 3);
  Idle;
  Window(1, ScreenRows, 80, ScreenRows);
  ClrScr;
  Frame(1, 4, 78, ScreenRows - 6, 11, 1, 0, 0);
  Window(2, 5, 78, ScreenRows - 3);
  MouseShow;
  DrawDrives;
  repeat
    TotSize := 0;
    TotFree := 0;
    MouseHide;
    Window(2, 5, 78, ScreenRows - 3);
    ClrScr;
    WriteLn;
    MouseShow;
    ArrowCursor;
    SetColor(Fg, Bg);
    Count := 0;
    Regs.AX := $1500;
    Regs.BX := 0;
    Intr($2F, Regs);
    if Regs.BX <> 0 then
    begin
      CDDrv := Regs.CL + 1;
      FindFirst(Chr(CDDrv + 64) + ':\*.*', $37, SR);
      HasCD := True;
    end;
    I := 1;
    goto L2;
    repeat
    Inc(I);
L2:
    if not Drives[I] then goto L3;
    if DiskSize(I) = -1 then goto L3;
    if (I = 1) and (P1F7B_0(0) = 0) then goto L3;
    if (I = 2) and (P1F7B_0(1) = 0) then goto L3;
    Inc(Count);
    Size := DiskSize(I);
    Free := DiskFree(I);
    Regs.AX := $1500;
    Regs.BX := 0;
    Intr($2F, Regs);
    if HasCD and (CDDrv = I) then
    begin
      CDInit;
      CDDevStatus;
      if CDDiscIn then
      begin
        CDReadTOC;
        Size := CDLength * 2048;
      end
      else
        Size := 0;
    end;
    if Size = 0 then Free := 0;
    if Size = 0 then R := 100 else R := Free / Size * 100;
    TotSize := TotSize + Size;
    TotFree := TotFree + Free;
    S := VolumeLabel(Chr(Ord('A') + I - 1));
    while Length(S) < 12 do S := S + ' ';
    S := '               ' + Chr(Ord('A') + I - 1) + ': ' + S;
    MouseHide;
    Write(S, SizeStr(Size), ' Byte gesamt, ');
    WriteF(10, SizeStr(Free) + ' frei.'#10#13);
    N := 12;
    Bar(3, WhereY - 1, #220);
    J := 0;
    if R <> 0 then
      while J <= R do Inc(J);
    J := 100 - J;
    PctBar(J, 3, WhereY - 1, #220);
    if ScreenRows - 12 = Count then
    begin
      Write('  Weiter mit Tastendruck ...'#13);
      repeat
        Idle;
      until GetKey(Key);
    end;
    MouseShow;
L3:
    until I = 26;
    if Count <> 0 then
    begin
      if TotSize = 0 then TotFree := 0;
      if TotSize = 0 then R := 100 else R := TotFree / TotSize * 100;
      MouseHide;
      WriteLn;
      WriteLn;
      WriteLn;
      N := 74;
      Bar(3, WhereY - 2, #219);
      J := 0;
      while J <= R do Inc(J);
      J := 100 - J;
      if TotFree = 0 then J := 100;
      PctBar(J, 3, WhereY - 2, #219);
      Str(TotSize:12:0, S);
      I := Length(S) - 3;
      while (I > 1) and (S[I] <> ' ') do
      begin
        Insert('.', S, I + 1);
        Dec(I, 3);
      end;
      Write('  Alle: ');
      WriteF(13, S + ' gesamt,');
      Str((TotSize - TotFree):12:0, S);
      I := Length(S) - 3;
      while (I > 1) and (S[I] <> ' ') do
      begin
        Insert('.', S, I + 1);
        Dec(I, 3);
      end;
      WriteF(14, S + ' belegt,');
      Str(TotFree:12:0, S);
      I := Length(S) - 3;
      while (I > 1) and (S[I] <> ' ') do
      begin
        Insert('.', S, I + 1);
        Dec(I, 3);
      end;
      WriteF(10, S + ' frei.');
      MouseShow;
    end;
    Quit := False;
    NormalCursor;
    WaitRelease;
    repeat
      GetKey(Key);
      SaveWin(W);
      if Buttons.MouseButton(B1) then Key := $450;
      if Buttons.MouseButton(B2) then Key := $451;
      RestoreWin(W);
      if Key = $450 then
      begin
        Left := SelectDrive(1, 4, Left);
        if Left <> ' ' then
        begin
          ChgL := True;
          SaveWin(W);
          B1.Caption := ' ' + Left + ': ';
          FocusButton(True, B1);
          RestoreWin(W);
        end;
      end;
      if Key = $451 then
      begin
        Right := SelectDrive(32, 4, Right);
        if Right <> ' ' then
        begin
          ChgR := True;
          SaveWin(W);
          B2.Caption := ' ' + Right + ': ';
          FocusButton(True, B2);
          RestoreWin(W);
        end;
      end;
      if Key = $423 then ShowHelp(32);
      if (LoCaseW(Key) in ['a'..'z']) and Valid[Ord(LoCaseW(Key)) - 96] then
      begin
        Drives[Ord(LoCaseW(Key)) - 96] := not Drives[Ord(LoCaseW(Key)) - 96];
        Quit := True;
        Changed := True;
        DrawDrives;
      end;
      if (Key = 27) or (Key = $42C) or (MouseButton = 2) then Quit := True;
      if MouseOn(ScreenRows, 2, 79) and ClickDrive then
      begin
        Quit := True;
        Changed := True;
      end;
    until Quit;
  until IsCancel(Key);
  if Changed then WriteDrives;
  PopScreen(DlgStack);
  StatY := SY;
  StatX := SX;
  SetMouseMap;
  WaitRelease;
  if ChgL then
  begin
    P0365_C3B(Left + ':\', Panels[1]);
    P0365_C41E(1, 0, Panels[1]);
  end;
  if ChgR then
  begin
    P0365_C3B(Right + ':\', Panels[2]);
    P0365_C41E(1, 0, Panels[2]);
  end;
end;

end.
