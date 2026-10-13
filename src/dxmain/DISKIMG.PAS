{$O+,F+,G+,S-,I-,X+,V-}
unit DiskImg;

interface

procedure MakeImage;
function RestoreImage(Name: string): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, AskDlgs, U1F7B;

type
  TTrackBuf = array[0..9215] of Byte;
  TBoot = record
    Fill1: array[0..$14] of Byte;
    Media: Byte;
    Fill2: array[0..1] of Byte;
    Spt: Word;
    Fill3: array[$1A..$1FF] of Byte;
  end;

procedure MakeImage;
label
  Again, Done;
var
  TrackBuf: TTrackBuf;
  P: Pointer;
  Boot: TBoot;
  Track, Side: Byte;
  Dummy1: Word;
  F: file;
  DrvChar: Char;
  Drv: Byte;
  B3: TButton3;
  B4: TButton4;
  B2: TButton2;
  Hit3a, Hit3b, A, Bb, Vol, Err, Ok2, Cancel, CloseErr: Boolean;
  Key: Word;
  N: Word;
  W: TWinState;
  Spt: Byte;
  Name: string[128];
  Total: Longint;
  SR: SearchRec;
  S1, S2: string[2];
begin
  GetDir(0, Name);
  AddBackslash(Name);
  Name := Name + 'disk.img';
  repeat
    OpenDialog;
    Err := False;
    Cancel := False;
    Frame(10, 7, 60, 10, 11, 3, 0, 1);
    WriteCenterXY(1, 1, 60, 'Disketten-Image-Datei erstellen');
    if not ThinButtons then
      WriteCenterXY(1, 2, 60, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD +
      #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD)
    else
      WriteCenterXY(1, 2, 60, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
    WriteCenterXY(1, 6, 60, 'Bitte die Diskette einlegen, Disk wird gelesen.');
    WriteXYF(4, 4, 14, 'D');
    Write('ateiname:');
    InputLine(25, 11, 16, 68, Name, 41, 0, #216, False);
    InitButton4(True, 12, 15, 27, 15, 42, 15, 57, 15, 14, 0, 11, 3,
      'Laufwerk A', 'Laufwerk B', ' Vol-Name ', ' Abbruch ', B4);
    MouseShow;
Again:
    repeat
      HandleButton4(A, Bb, Vol, Cancel, Key, B4);
      if Vol then
      begin
        OpenDialog;
        Frame(13, 9, 53, 6, 15, 5, 0, 1);
        WriteCenterXY(1, 1, 53, 'Volume-Namen (Label) der Diskette erfragen');
        WriteCenterXY(1, 2, 53, 'und als Dateinamen eintragen:');
        InitButton3(True, 3, 4, 20, 4, 37, 4, 14, 0, 15, 5, ' Laufwerk A ', ' Laufwerk B ', '  Abbruch  ', B3);
        MouseShow;
        repeat
          HandleButton3(Hit3a, Hit3b, Cancel, Key, B3);
        until Hit3a or Hit3b or Cancel or IsCancel(Key);
        if Hit3a then
          DrvChar := 'A'
        else if Hit3b then
          DrvChar := 'B';
        if Hit3a or Hit3b then
        begin
          ArrowCursor;
          FindFirst(DrvChar + ':\*.*', VolumeID, SR);
          if (DosError = 0) and (SR.Name <> '') then
          begin
            GetDir(0, Name);
            AddBackslash(Name);
            Name := Name + LowerStr(SR.Name);
          end
          else
            ErrorBox('Kein Label vorhanden oder', 'Fehler beim Lesen des Labels!');
          NormalCursor;
        end;
        CloseDialog;
        SaveWin(W);
        InputLine(25, 11, 16, 68, Name, 41, 0, #216, False);
        RestoreWin(W);
        Hit3a := False;
        Hit3b := Hit3a;
        Cancel := Hit3b;
      end;
      if (Key = $430) or (Key = $408) or (LoCaseW(Key) = 'd') or MouseOn(11, 25, 67) then
        InputLine(25, 11, 24, 68, Name, 41, 128, #216, False);
      if (Name = '') and (A or Bb) then ErrorBox('Bitte einen Dateinamen eingeben!', '');
      Cancel := Cancel or IsCancel(Key) or MouseOutside(10, 71, 7, 18);
    until ((A or Bb) and (Name <> '')) or Cancel;
    if Cancel then
    begin
      CloseDialog;
      Exit;
    end;
    if A then Drv := 0 else Drv := 1;
    ArrowCursor;
    Err := P1F7B_120(Drv, 0, 0, 1, 1, Boot) = False;
    NormalCursor;
    if Err or (Boot.Media > $F9) or (Boot.Spt < 9) or (Boot.Spt > 18) then
    begin
      OpenDialog;
      Frame(13, 9, 54, 6, 2, 5, 0, 1);
      WriteCenterXY(1, 2, 54, 'Bitte die Quelldiskette einlegen!');
      InitButton2(True, 3, 4, 28, 4, 14, 0, 15, 5, '         OK         ', '       Abbruch       ', B2);
      MouseShow;
      repeat
        repeat
          HandleButton2(Ok2, Cancel, Key, B2);
          if IsCancel(Key) then Cancel := True;
        until Ok2 or Cancel;
        if not Cancel then
        begin
          ArrowCursor;
          Err := P1F7B_120(Drv, 0, 0, 1, 1, Boot) = False;
          if not Err then
            if (Boot.Media > $F9) or (Boot.Spt < 9) or (Boot.Spt > 18) then
            begin
              MsgBox('Die Diskette wird hier nicht unterst'#$81'tzt!', 'Nur 5 1/4" HD und 3 1/2" DD + HD Disketten');
              Err := True;
            end;
          NormalCursor;
        end;
      until not Err or Cancel;
      PopScreen(DlgStack);
      if Cancel then goto Again;
    end;
    if FSearch(Name, '') <> '' then
      if not AskReplace(Name) then goto Again;
    MouseHide;
    Frame(10, 7, 60, 13, 11, 3, 0, 1);
    WriteCenterXY(1, 1, 60, 'Diskette auf die Festplatte kopieren');
    if not ThinButtons then
      WriteCenterXY(1, 2, 60, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD +
      #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD)
    else
      WriteCenterXY(1, 2, 60, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
    InputFrame(3, 11, 56, 11, 3);
    GB44 := 56;
    MouseShow;
    ArrowCursor;
    Assign(F, Name);
    P := @TrackBuf;
    Rewrite(F, 1);
    if IOResult <> 0 then
    begin
      MsgBox('Fehler beim Erstellen der Datei', Name);
      CloseDialog;
      Exit;
    end;
    Spt := Boot.Spt;
    Total := 0;
    MouseHide;
    WriteCenterXY(1, 3, 60, 'Schreibe Imagedatei:');
    WriteCenterXYF(1, 5, 60, 14, Shorten(Name, 58));
    Str(Spt, S1);
    WriteCenterXY(1, 7, 60, 'Lese 80 Spuren mit ' + S1 + ' Sektoren/Spur');
    MouseShow;
    for Track := 0 to 79 do
      for Side := 0 to 1 do
      begin
        GotoXY(19, 9);
        MouseHide;
        {$I+}
        Write('Lese Spur: ', Track: 2, '  Seite: ', Side: 2);
        {$I-}
        MouseShow;
        Err := P1F7B_9E(Drv, Side, Track, Spt, P) = False;
        if Err then
        begin
          Str(Track, S1);
          Str(Side, S2);
          MsgBox('Fehler beim Lesen von der Diskette!', 'Spur: ' + S1 + ' Seite: ' + S2);
          goto Done;
        end;
        MouseHide;
        MouseMoved := 0;
        ShowBar(14, Track * 100 div 79, 3, 11);
        Total := Total + Spt * 512;
        GotoXY(21, 13);
        {$I+}
        Write(Total: 10, ' Bytes');
        {$I-}
        MouseShow;
        GetKey(Key);
        Cancel := Key = 27;
        if Cancel then goto Done;
        BlockWrite(F, TrackBuf, Spt * 512, N);
        Err := (IOResult <> 0) or (Longint(N) <> Spt * 512);
        if Err then
        begin
          MsgBox('Fehler beim Schreiben der Datei', Name);
          goto Done;
        end;
      end;
Done:
    NormalCursor;
    Close(F);
    CloseErr := IOResult <> 0;
    Err := Err or CloseErr;
    if CloseErr then MsgBox('Fehler beim Schreiben der Datei', Name);
    if Err or Cancel then Erase(F);
    InOutRes := 0;
    if Cancel then
      MsgBox('Der Vorgang wurde abgebrochen!', Name)
    else if not Err then
      ErrorBox('Die Imagedatei wurde erzeugt:', Name);
    CloseDialog;
  until False;
end;

function RestoreImage(Name: string): Boolean;
label
  Finish;
var
  TrackBuf: TTrackBuf;
  P: Pointer;
  Track, Side: Byte;
  Res: Byte;
  F: file;
  Drv: Byte;
  B3: TButton3;
  Key: Word;
  D1: Longint;
  D2, D3: Word;
  Size: Longint;
  Spt: Byte;
  DstSpt: Byte;
  Fg, HotFg: Byte;
  SName: string[12];
  SSpt: string[12];
  N: Word;
  NewVec: Pointer;
  OldVec: Pointer;
  A, Bb: Boolean;
  D4: Boolean;
  Err: Boolean;
  Cancel: Boolean;
  D5: Boolean;
  Can144, Can720, Can12: Boolean;
  DrvA, DrvB, DrvType: Byte;
begin
  Assign(F, Name);
  Can144 := True;
  Can720 := Can144;
  Can12 := Can720;
  Key := 0;
  RestoreImage := True;
  GetFAttr(F, Key);
  if Key and $10 <> 0 then
  begin
    ErrorBox('Restaurieren von Verzeichnissen', 'ist nicht m'#$94'glich!');
    Exit;
  end;
  Reset(F, 1);
  if IOResult <> 0 then
  begin
    MsgBox('Fehler beim '#$99'ffnen der Datei', Name);
    Exit;
  end;
  {$I+}
  Size := FileSize(F);
  {$I-}
  P := @TrackBuf;
  if Size = 1228800 then
  begin
    Spt := 15;
    Key := 50;
    SName := '1.2 MB';
    SSpt := '15';
    Can720 := False;
  end
  else if Size = 737280 then
  begin
    Spt := 9;
    Key := 55;
    SName := '720 KB';
    SSpt := '9';
  end
  else if Size = 1474560 then
  begin
    Spt := 18;
    Key := 52;
    SName := '1.44 MB';
    SSpt := '18';
    Can720 := False;
    Can12 := False;
  end
  else
  begin
    Close(F);
    InOutRes := 0;
    MsgBox('Imagedatei hat die falsche Gr'#$94#$E1'e!', 'G'#$81'ltig: 737280 oder 1228800 oder 1474560 Bytes.');
    Exit;
  end;
  OpenDialog;
  Err := False;
  Frame(6, 7, 67, 14, 11, 3, 0, 1);
  WriteCenterXY(1, 1, 67, 'Disketten-Image-Datei restaurieren');
  if not ThinButtons then
    WriteCenterXY(1, 2, 67, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD +
      #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD)
  else
    WriteCenterXY(1, 2, 67, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
  WriteCenterXYF(1, 3, 67, 14, Shorten(Name, 64));
  WriteCenterXY(1, 5, 67, 'Erzeuge ' + SName + ' Diskette mit 80 Spuren und ' + SSpt + ' Sektoren/Spur.');
  WriteXY(21, 7, '               [ ] 1.44 MB');
  WriteXYF(42, 7, 14, '4');
  Fg := 0;
  HotFg := 14;
  if Spt > 9 then
  begin
    Fg := 7;
    HotFg := 7;
  end;
  WriteXY(21, 8, 'Zieldiskette:  ');
  WriteF(Fg, '[ ]  720 KB');
  WriteXYF(41, 8, HotFg, '7');
  Fg := 0;
  HotFg := 14;
  if Spt > 15 then
  begin
    Fg := 7;
    HotFg := 7;
  end;
  WriteXYF(21, 9, Fg, '               [ ]  1.2 MB');
  WriteXYF(43, 9, HotFg, '2');
  WriteCenterXYF(1, 11, 67, 4, 'Eingelegte Diskette wird komplett '#$81'berschrieben!');
  InitButton3(True, 3, 12, 24, 12, 45, 12, 14, 0, 11, 3, '   Laufwerk A   ', '   Laufwerk B   ', '     Abbruch     ', B3);
  MouseShow;
  DrvA := P1F7B_0(0);
  DrvB := P1F7B_0(1);
  repeat
    if Can144 and (MouseOn(14, 42, 52) or (Key = 52)) then
    begin
      MouseHide;
      WriteXY(37, 7, 'X');
      WriteXY(37, 8, ' ');
      WriteXY(37, 9, ' ');
      MouseShow;
      WaitRelease;
      DstSpt := 18;
    end;
    if Can720 and (MouseOn(15, 42, 52) or (Key = 55)) then
    begin
      MouseHide;
      WriteXY(37, 7, ' ');
      WriteXY(37, 8, 'X');
      WriteXY(37, 9, ' ');
      MouseShow;
      WaitRelease;
      DstSpt := 9;
    end;
    if Can12 and (MouseOn(16, 42, 52) or (Key = 50)) then
    begin
      MouseHide;
      WriteXY(37, 7, ' ');
      WriteXY(37, 8, ' ');
      WriteXY(37, 9, 'X');
      MouseShow;
      WaitRelease;
      DstSpt := 15;
    end;
    HandleButton3(A, Bb, Cancel, Key, B3);
    if IsCancel(Key) or MouseOutside(6, 74, 7, 22) then Cancel := True;
    if A then DrvType := DrvA;
    if Bb then DrvType := DrvB;
    if A or Bb then
      case DrvType of
        2: if DstSpt <> 15 then Err := True;
        4: if DstSpt = 15 then Err := True;
      end;
    if Err then
    begin
      Err := False;
      A := False;
      Bb := False;
      ErrorBox('Diese Kombination ist nicht m'#$94'glich!', 'W'#$84'hlen Sie eine andere Kombination aus.');
    end;
  until A or Bb or Cancel;
  if Cancel then
  begin
    RestoreImage := False;
    CloseDialog;
    Exit;
  end;
  MouseHide;
  Frame(6, 7, 67, 14, 11, 3, 0, 1);
  WriteCenterXY(1, 1, 67, 'Disketten-Image-Datei restaurieren');
  if not ThinButtons then
    WriteCenterXY(1, 2, 67, #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD +
      #$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD#$DD)
  else
    WriteCenterXY(1, 2, 67, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
  InputFrame(3, 12, 63, 11, 3);
  GB44 := 63;
  MouseShow;
  ArrowCursor;
  if A then Drv := 0 else Drv := 1;
  Err := P1F7B_2CD(Drv, 79, DstSpt, NewVec) = False;
  GetIntVec($1E, OldVec);
  SetIntVec($1E, NewVec);
  Res := P1F7B_320(Drv, 0, 0, DstSpt);
  if Res = 3 then goto Finish;
  Err := Res <> 0;
  if Err then Err := P1F7B_320(Drv, 0, 0, DstSpt) <> 0;
  if Err then Err := P1F7B_320(Drv, 0, 0, DstSpt) <> 0;
  if not Err then Err := P1F7B_26E(Drv, 0, 0, 1, DstSpt, NewVec) = False;
  SetIntVec($1E, OldVec);
  if Err then
  begin
    MsgBox('Fehler beim Schreiben!', 'Seite: 0  Spur: 0');
    goto Finish;
  end;
  MouseHide;
  WriteCenterXY(1, 3, 67, 'Lese Imagedatei');
  WriteCenterXYF(1, 5, 67, 14, Shorten(Name, 63));
  WriteCenterXY(1, 7, 67, 'Geschrieben wird mit Bios-Verify=On');
  GotoXY(20, 14);
  {$I+}
  Write(0: 14, ' Bytes');
  {$I-}
  MouseShow;
  Size := 0;
  for Track := 0 to 79 do
    for Side := 0 to 1 do
    begin
      BlockRead(F, TrackBuf, Spt * 512, N);
      Err := (IOResult <> 0) or (Spt * 512 <> N);
      if Err then
      begin
        NormalCursor;
        MsgBox('Fehler beim Lesen der Datei', Name);
        goto Finish;
      end;
      MouseHide;
      MouseMoved := 0;
      GotoXY(21, 10);
      {$I+}
      Write('Schreibe Spur: ', Track: 2, '  Seite: ', Side);
      {$I-}
      MouseShow;
      Err := P1F7B_1A4(Drv, Side, Track, 1, Spt, P, 1) = False;
      MouseHide;
      if Err then
      begin
        Str(Side, SName);
        Str(Track, SSpt);
        NormalCursor;
        MsgBox('Fehler beim Schreiben!', 'Seite: ' + SName + '  Spur: ' + SSpt);
      end;
      ShowBar(14, Track * 100 div 79, 3, 12);
      Size := Size + Spt * 512;
      GotoXY(20, 14);
      {$I+}
      Write(Size: 14, ' Bytes');
      {$I-}
      MouseShow;
      GetKey(Key);
      if Key = 27 then
      begin
        Err := True;
        RestoreImage := False;
      end;
      MouseMoved := 0;
      if Err then goto Finish;
    end;
Finish:
  Close(F);
  InOutRes := 0;
  NormalCursor;
  if Res = 3 then
    ErrorBox('Die Diskette ist schreibgesch'#$81'tzt!', 'Bitte den Schreibschutz entfernen.')
  else if Err then
  begin
    MsgBox('Der Vorgang wurde abgebrochen!', 'Die Diskette ist nicht brauchbar!!');
    RestoreImage := False;
  end
  else
    ErrorBox('Die Restaurierung der Diskette war', 'erfolgreich!');
  CloseDialog;
end;

end.
