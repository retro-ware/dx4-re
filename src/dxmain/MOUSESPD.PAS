{$O+,F+,G+,S-,I+,X+,V-}
unit MouseSpd;

interface

procedure MouseSpeedDialog;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, Help;

type
  TIniRec = record
    Id: string[41];
    Fill: array[1..$711 - 42] of Byte;
    MouseSpeed: Byte;
  end;

procedure MouseSpeedDialog;
var
  R: Registers;
  Key: Word;
  OldPos, Pos, I: Integer;
  B1, B2, Rep: Boolean;
  Count: Longint;
  Btns: array[1..3] of TButton;
  SaveHit, ActHit, QuitHit: Boolean;

{$I-}
  procedure SaveSpeed;
  var
    F: file of TIniRec;
    P: ^TIniRec;
    Err: Boolean;
  begin
    Assign(F, HomeDir + IniName);
    GetMem(P, SizeOf(TIniRec));
    Err := False;
    Reset(F);
    Read(F, P^);
    Close(F);
    if (IOResult = 0) and (P^.Id = IniId) then
    begin
      P^.MouseSpeed := MouseSpeed;
      Rewrite(F);
      Write(F, P^);
      Close(F);
      if IOResult <> 0 then Err := True;
    end
    else
      Err := True;
    if Err then
      MsgBox('Ver'#$84'nderungen k'#$94'nnen nicht gespeichert werden!', IniName + ' ist fehlerhaft oder nicht vorhanden!');
    FreeMem(P, SizeOf(TIniRec));
    WaitRelease;
  end;
{$I+}

  procedure HandleButtons;
  var
    I: Integer;
    F: Boolean;
  begin
    ActHit := Buttons.MouseButton(Btns[1]);
    if Btns[1].Focused then
    begin
      Btns[2].Focused := False;
      Btns[3].Focused := False;
    end;
    SaveHit := Buttons.MouseButton(Btns[2]);
    if Btns[2].Focused then
    begin
      Btns[3].Focused := False;
      Btns[1].Focused := False;
    end;
    QuitHit := Buttons.MouseButton(Btns[3]);
    if Btns[3].Focused then
    begin
      Btns[1].Focused := False;
      Btns[2].Focused := False;
    end;
    GetKey(Key);
    if Key = 9 then
    begin
      F := Btns[3].Focused;
      for I := 2 downto 1 do
        Btns[I + 1].Focused := Btns[I].Focused;
      Btns[1].Focused := F;
    end;
    if Key = 13 then
    begin
      if Btns[1].Focused then
      begin
        ActHit := True;
        Btns[1].Pressed := True;
      end;
      if Btns[2].Focused then
      begin
        SaveHit := True;
        Btns[2].Pressed := True;
      end;
      if Btns[3].Focused then
      begin
        QuitHit := True;
        Btns[3].Pressed := True;
      end;
    end;
    DrawButton(Btns[1]);
    DrawButton(Btns[2]);
    DrawButton(Btns[3]);
    if Key = 13 then
    begin
      Delay(100);
      Btns[1].Pressed := False;
      Btns[2].Pressed := False;
      Btns[3].Pressed := False;
      DrawButton(Btns[1]);
      DrawButton(Btns[2]);
      DrawButton(Btns[3]);
    end;
  end;

  procedure ShowPos;
  var
    Unused: Longint;
    A: Byte;
  begin
    if OldPos = Pos then Exit;
    A := TextAttr;
    MouseHide;
    GotoXY(28, 10);
    Write(Pos * 2 + 2: 3);
    SetColor(11, 3);
    if OldPos <> 32000 then
      WriteXY(OldPos + 6, 11, #$B1#8);
    WriteXYFB(Pos + 6, 11, 0, 4, #$1D#8);
    TextAttr := A;
    MouseShow;
    OldPos := Pos;
  end;

begin
  OpenDialog;
  Frame(10, 7, 60, 10, 15, 5, 0, 1);
  WriteCenterXY(1, 1, 60, 'Mausgeschwindigkeit');
  Frame(12, 10, 56, 3, 15, 5, 1, 0);
  Window(11, 2, 80, 25);
  R.AX := $1B;
  Intr($33, R);
  Pos := R.BX shr 1 - 1;
  if Pos > 100 then Pos := 100;
  if Pos < 2 then Pos := 2;
  OldPos := 32000;
  GotoXY(5, 11);
  SetColor(11, 3);
  Write(#$11);
  for I := 1 to 50 do Write(#$B1);
  Write(#$10);
  InitButton(True, 2, 14, 14, 0, 15, 5, '  Aktivieren  ', Btns[1]);
  InitButton(False, 22, 14, 14, 0, 15, 5, '   Speichern   ', Btns[2]);
  InitButton(False, 43, 14, 14, 0, 15, 5, '   Beenden   ', Btns[3]);
  SetColor(14, 5);
  ShowPos;
  Count := 0;
  Key := 0;
  MouseShow;
  repeat
    Rep := False;
    if (Mouse.MouseButton = 1) and (MouseY = 12) then
    begin
      case MouseX of
        15: Key := $433;
        $42: Key := $435;
      end;
      if (MouseX = 15) or (MouseX = $42) then
      begin
        Inc(Count);
        Rep := True;
      end;
    end
    else
      Count := 0;
    if (Mouse.MouseButton = 1) and (MouseY = 12) and (MouseX > 15) and (MouseX < $42) then
    begin
      Key := 9999;
      Pos := MouseX - 16;
    end;
    if Key <> 0 then
    begin
      if Key = $435 then Inc(Pos);
      if Key = $433 then Dec(Pos);
      if Pos > 49 then Pos := 49;
      if Pos < 0 then Pos := 0;
      ShowPos;
      if Rep then
      begin
        if Count = 1 then Delay(400) else Delay(30);
      end
      else
        Count := 0;
    end;
    HandleButtons;
    if Key = $423 then ShowHelp($44);
    if LoCaseW(Key) = 'a' then ActHit := True;
    if LoCaseW(Key) = 's' then SaveHit := True;
    if LoCaseW(Key) = 'b' then QuitHit := True;
    if IsCancel(Key) or MouseOutside(10, 71, 7, 18) then QuitHit := True;
    if ActHit or SaveHit then
    begin
      MouseSpeed := Pos * 2 + 2;
      MouseSensitivity(Pos * 2 + 2);
    end;
  until SaveHit or QuitHit;
  if SaveHit then SaveSpeed;
  CloseDialog;
end;

end.
