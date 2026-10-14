{$O+,F+,G+,S-,I-,X+,V-}
unit PalEdit;
{ Overlay 0331: VGA colour palette editor }

interface

procedure PaletteEditor;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Status, Dialogs, ScrSave, Lists, Palette,
  AskDlgs;

type
  Str8 = string[8];
  TPalArr = array[0..15] of TRGB;
  TPalFile = record
    Id: string[7];
    RGB: array[0..15] of TRGB;
  end;
  TPalNames = array[1..99] of string[12];
  PPalNames = ^TPalNames;
  TPalList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
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

var
  PalNames: PPalNames;

procedure TPalList.DrawLine(Line: Integer);
begin
  Text := PalNames^[Line + Top];
  TList.DrawLine(Line);
end;

procedure PaletteEditor;
var
  I, Col, OldCol: Byte;
  Key: Word;
  Unk6: array[1..6] of Byte;
  B4: TButton4;
  Cancel, OK, Save, Mono: Boolean;
  W446, W448: Word;
  Bar: string[64];
  RGB, OldRGB: TRGB;
  W: TWinState;

  function StatusBtn(Lbl: Str8; X, X1, X2: Byte): Boolean;
  begin
    StatusBtn := False;
    MouseHide;
    WriteXYFB(X, ScreenRows, 0, 3, ' ' + Lbl);
    MouseShow;
    repeat
    until (MouseButton = 0) or (ScreenRows <> MouseY) or (X1 > MouseX) or (X2 < MouseX);
    if (ScreenRows = MouseY) and (X1 <= MouseX) and (X2 >= MouseX) then StatusBtn := True;
    MouseHide;
    WriteXYFB(X, ScreenRows, 14, 3, Lbl + ' ');
    MouseShow;
  end;

  procedure ShowHelp;
  var
    Key: Word;
  begin
    OpenDialog;
    Frame(1, ScreenRows - 3, 78, 1, 11, 3, 0, 0);
    Write(' Hilfe: Bet'#$84'tigen Sie die Statuszeile mit der Maus oder den Funktionstasten:');
    MouseShow;
    repeat
      GetKey(Key);
      if MouseButton = 1 then
        if ScreenRows = MouseY then
        begin
          SaveWin(W);
          case MouseX of
            2..7: if StatusBtn('Hilfe', 3, 2, 7) then Key := $423;
            9..13: if StatusBtn('Rot'#$F1, 10, 9, 14) then Key := $424;
            17..22: if StatusBtn('Gr'#$81'n'#$F1, 18, 17, 23) then Key := $425;
            25..30: if StatusBtn('Blau'#$F1, 26, 25, 31) then Key := $426;
            33..38: if StatusBtn('PSave', 34, 33, 39) then Key := $427;
            41..46: if StatusBtn('Pload', 42, 41, 47) then Key := $428;
            49..55: if StatusBtn('Vorher', 50, 49, 56) then Key := $429;
            57..63: if StatusBtn('CReset', 58, 57, 64) then Key := $42A;
            65..71: if StatusBtn('PReset', 66, 65, 72) then Key := $42B;
            73..78: if StatusBtn('Ende', 75, 73, 79) then Key := $42C;
          end;
          RestoreWin(W);
        end;
      case Key of
        $423, $424, $425, $426, $427, $428, $429, $42A, $42B, $42C: ClrScr;
      end;
      case Key of
        $423: Write(' Diese Hilfe!');
        $424: Write(' Linke Maustaste oder F2: Rot-Wert+    Rechte Maustaste oder AltF2: Rot-Wert-');
        $425: Write(' Linke Maustaste oder F3: Gr'#$81'n-Wert+  Rechte Maustaste oder AltF3: Gr'#$81'n-Wert-');
        $426: Write(' Linke Maustaste oder F4: Blau-Wert+  Rechte Maustaste oder AltF4: Blau-Wert-');
        $427: Write(' Diese Farbpalette im DX-Verzeichnis abspeichern (*.pal)');
        $428: Write(' Eine Farbpalette aus dem DX-Verzeichnis laden (*.pal)');
        $429: Write(' Setzt die Palette auf die Werte vor Aufruf dieser Funktion zur'#$81'ck');
        $42A: Write(' Farb-Reset setzt die aktuelle Farbe auf den Default-Wert');
        $42B: Write(' Paletten-Reset setzt die ganze Palette auf die Default-Werte');
      end;
    until IsCancel(Key);
    CloseDialog;
  end;

  procedure SaveColors;
  var
    F: file of TConfig;
    Rec: TConfig;
    Err: Boolean;
  begin
    Err := True;
    Assign(F, HomeDir + IniName);
    Reset(F);
    Read(F, Rec);
    Close(F);
    if (IOResult = 0) and (Rec.Id = IniId) then
    begin
      Rec.Blk595 := TBlk48(CfgBlkAFE);
      Rewrite(F);
      Write(F, Rec);
      Close(F);
      if IOResult = 0 then Err := False;
    end;
    if Err then
      MsgBox('Farben k'#$94'nnen nicht gespeichert werden!', IniName + ' ist fehlerhaft oder nicht vorhanden!');
  end;

  procedure SavePal;
  var
    F: file of TPalFile;
    Name: string;
    I: Byte;
    Pal: TPalFile;
    B2: TButton2;
    H1, H2: Boolean;
  begin
    OpenDialog;
    Name := '';
    Frame(15, 9, 49, 9, 15, 5, 0, 1);
    WriteCenterXY(1, 1, 49, 'Palette speichern');
    for I := 1 to 17 do Name := Name + #$DD;
    WriteCenterXY(1, 2, 49, Name);
    WriteCenterXYF(1, 3, 49, 4, 'Im Verzeichnis ' + Shorten(HomeDir, 30));
    WriteXY(12, 5, 'Dateiname: ');
    Name := '';
    Window(1, 1, 80, ScreenRows);
    WriteXYFB(49, 13, 0, 5, #$D8#$D8#$D8#$D8);
    WriteXYFB(49, 14, 0, 2, '.pal');
    InitButton2(True, 17, 16, 41, 16, 14, 0, 15, 5, '     Speichern     ', '      Abbruch      ', B2);
    MouseShow;
    Key := $430;
    repeat
      if (Key = $430) or (Key = 9) or (Key = $408) or (LoCaseW(Key) = 'd') or MouseOn(14, 39, 52) then
        InputLine(39, 14, 38, 48, Name, 8, 8, #$D8, False);
      HandleButton2(H1, H2, Key, B2);
      if IsCancel(Key) or MouseOutside(15, 65, 9, 19) then H2 := True;
      if LoCaseW(Key) = 's' then H1 := True;
      if LoCaseW(Key) = 'a' then H2 := True;
    until H1 or H2;
    CloseDialog;
    if (Length(Name) = 0) or H2 then Exit;
    Name := HomeDir + Name + '.pal';
    if FSearch(Name, '') <> '' then
      if not AskReplace(Name) then Exit;
    Assign(F, Name);
    Rewrite(F);
    if IOResult <> 0 then
    begin
      MsgBox('Fehler beim Schreiben der Palette', Name);
      Exit;
    end;
    Pal.Id := 'HHPal16';
    for I := 0 to 15 do GetRGB(I, Pal.RGB[I]);
    Write(F, Pal);
    Close(F);
    ErrorBox('Palette wurde gespeichert', Name);
  end;

  procedure LoadPal;
  var
    F: file of TPalFile;
    Name: string;
    I: Byte;
    Pal: TPalFile;
    SR: SearchRec;
    List: TPalList;
    Key: Word;
    B2: TButton2;
    Ok, Cancel: Boolean;
    Sel: Integer;
    Rows, Count: Byte;
  begin
    Rows := 15;
    I := 0;
    GetMem(PalNames, SizeOf(TPalNames));
    FindFirst(HomeDir + '*.pal', $3F, SR);
    if DosError = 0 then
    repeat
      Inc(I);
      PalNames^[I] := LowerStr(SR.Name);
      FindNext(SR);
    until (DosError <> 0) or (I >= 99);
    if I = 99 then ErrorBox('Maximum von 99 Paletten erreicht!', HomeDir);
    Count := I;
    if I = 0 then
    begin
      ErrorBox('Es gibt keine Paletten im Verzeichnis', HomeDir);
      FreeMem(PalNames, SizeOf(TPalNames));
      Exit;
    end;
    OpenDialog;
    Frame(41, 8, Rows, 1, 15, 5, 0, 1);
    Write(' Palette laden');
    Frame(41, 11, Rows, 12, 15, 5, 0, 1);
    List.Init(0, 5, 0, 2, 42, 12, 12, Count, Rows, False);
    MouseShow;
    repeat
      GetKey(Key);
      Sel := List.Handle(Key);
      Ok := Key = 13;
      Cancel := IsCancel(Key) or MouseOutside(41, Rows + 41 + 1, 8, 24);
    until Ok or Cancel;
    CloseDialog;
    Name := HomeDir + PalNames^[Sel];
    FreeMem(PalNames, SizeOf(TPalNames));
    if Cancel then Exit;
    Assign(F, Name);
    Reset(F);
    Read(F, Pal);
    Close(F);
    if (IOResult <> 0) or (Pal.Id <> 'HHPal16') then
    begin
      Close(F);
      if IOResult <> 0 then ;
      MsgBox('Fehler beim Laden der Palette', Name);
      Exit;
    end
    else
      for I := 0 to 15 do SetRGB(I, Pal.RGB[I]);
  end;

begin
  Bar := #$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC +
    #$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC +
    #$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC#$DC;
  OpenDialog;
  OK := False;
  Cancel := False;
  Save := False;
  Mono := False;
  W446 := 0;
  Window(1, 1, 80, ScreenRows);
  SetColor(14, 3);
  WriteXY(1, ScreenRows, ' ');
  WriteXY(3, ScreenRows, 'Hilfe ');
  WriteXY(10, ScreenRows, 'Rot'#$F1'   ');
  WriteXY(18, ScreenRows, 'Gr'#$81'n'#$F1'  ');
  WriteXY(26, ScreenRows, 'Blau'#$F1'  ');
  WriteXY(34, ScreenRows, 'Psave  ');
  WriteXY(42, ScreenRows, 'PLoad  ');
  WriteXY(50, ScreenRows, 'Vorher ');
  WriteXY(58, ScreenRows, 'CReset ');
  WriteXY(66, ScreenRows, 'PReset ');
  WriteXY(75, ScreenRows, 'Ende ');
  Frame(4, 7, 71, 13, 11, 3, 0, 1);
  Frame(7, 12, 65, 3, 11, 3, 0, 0);
  Window(4, 8, 80, ScreenRows);
  WriteXY(3, 6, 'R');
  WriteXY(3, 7, 'G');
  WriteXY(3, 8, 'B');
  GotoXY(5, 1);
  for I := 0 to 15 do WriteF(I, #$DB#$DB#$DB#$DB);
  GotoXY(5, 2);
  for I := 0 to 15 do WriteF(I, #$DB#$DB#$DB#$DB);
  GotoXY(5, 3);
  for I := 0 to 15 do WriteF(I, #$DB#$DB#$DB#$DB);
  GotoXY(5, 4);
  for I := 0 to 15 do WriteF(I, #$DB#$DB#$DB#$DB);
  WriteXY(5, 10, 'Farbnummer:     RGB-Palettennummer: ');
  WriteXY(45, 10, 'Rot:    Gr'#$81'n:    Blau: ');
  for I := 0 to 15 do GetRGB(I, TPalArr(CfgBlkAFE)[I]);
  Col := 7;
  RGB := TPalArr(CfgBlkAFE)[Col];
  Key := 0;
  OldCol := 0;
  OldRGB := TPalArr(CfgBlkAFE)[0];
  InitButton4(True, 3, 11, 21, 11, 40, 11, 55, 11, 14, 0, 11, 3, '  Monochrom  ', '  Speichern  ', '    OK    ',
    '   Abbruch   ', B4);
  MouseShow;
  repeat
    if (MouseButton = 1) and (Lo(MouseY) in [8..11]) and (Lo(MouseX) in [8..71]) then
    begin
      if Lo(MouseX) in [8..11] then Col := 0;
      if Lo(MouseX) in [12..15] then Col := 1;
      if Lo(MouseX) in [16..19] then Col := 2;
      if Lo(MouseX) in [20..23] then Col := 3;
      if Lo(MouseX) in [24..27] then Col := 4;
      if Lo(MouseX) in [28..31] then Col := 5;
      if Lo(MouseX) in [32..35] then Col := 6;
      if Lo(MouseX) in [36..39] then Col := 7;
      if Lo(MouseX) in [40..43] then Col := 8;
      if Lo(MouseX) in [44..47] then Col := 9;
      if Lo(MouseX) in [48..51] then Col := 10;
      if Lo(MouseX) in [52..55] then Col := 11;
      if Lo(MouseX) in [56..59] then Col := 12;
      if Lo(MouseX) in [60..63] then Col := 13;
      if Lo(MouseX) in [64..67] then Col := 14;
      if Lo(MouseX) in [68..71] then Col := 15;
      GetRGB(Col, RGB);
    end;
    if (MouseButton = 1) and (Lo(MouseX) in [9..74]) and (Lo(MouseY) in [13..15]) then
      case MouseY of
        13: RGB.R := MouseX - 9;
        14: RGB.G := MouseX - 9;
        15: RGB.B := MouseX - 9;
      end;
    case Key of
      $423: ShowHelp;
      $424: Inc(RGB.R);
      $425: Inc(RGB.G);
      $426: Inc(RGB.B);
      $451: Dec(RGB.R);
      $452: Dec(RGB.G);
      $453: Dec(RGB.B);
      9:
        begin
          Inc(Col);
          if Col > 15 then Col := 0;
          GetRGB(Col, RGB);
        end;
      $3F7:
        begin
          Dec(Col);
          if Col = $FF then Col := 15;
          GetRGB(Col, RGB);
        end;
      $42A:
        begin
          RGB := TPalArr(DefPal)[Col];
          SetRGB(Col, RGB);
        end;
      $429:
        begin
          for I := 0 to 15 do SetRGB(I, TPalArr(CfgBlkAFE)[I]);
          RGB := TPalArr(CfgBlkAFE)[Col];
        end;
      $42B:
        begin
          for I := 0 to 15 do SetRGB(I, TPalArr(DefPal)[I]);
          RGB := TPalArr(DefPal)[Col];
        end;
      $427: SavePal;
      $428:
        begin
          LoadPal;
          GetRGB(Col, RGB);
        end;
    end;
    if RGB.R = $FF then RGB.R := 0;
    if RGB.G = $FF then RGB.G := 0;
    if RGB.B = $FF then RGB.B := 0;
    if RGB.R > $3F then RGB.R := $3F;
    if RGB.G > $3F then RGB.G := $3F;
    if RGB.B > $3F then RGB.B := $3F;
    SetRGB(Col, RGB);
    TextColor(14);
    if Col <> OldCol then
    begin
      MouseHide;
      WriteXYF(OldCol * 4 + 2 + 4, 4, OldCol, #$DB#$DB);
      WriteXYF(OldCol * 4 + 2 + 4, 5, 11, #$C4#$C4);
      WriteXYF(Col * 4 + 2 + 4, 4, 0, #$DB#$DB);
      WriteXYF(Col * 4 + 2 + 4, 5, 11, #$C1#$C1);
      GotoXY(17, 10);
      Write(Col: 2, ' ');
      GotoXY(41, 10);
      Write(PalIdx[Col]: 2, ' ');
      OldCol := Col;
      MouseShow;
    end;
    if (RGB.R <> OldRGB.R) or (RGB.G <> OldRGB.G) or (RGB.B <> OldRGB.B) then
    begin
      MouseHide;
      WriteXYF(6, 6, 14, Copy(Bar, 1, RGB.R));
      WriteF(0, Copy(Bar, 1, 63 - RGB.R));
      WriteXYF(6, 7, 14, Copy(Bar, 1, RGB.G));
      WriteF(0, Copy(Bar, 1, 63 - RGB.G));
      WriteXYF(6, 8, 14, Copy(Bar, 1, RGB.B));
      WriteF(0, Copy(Bar, 1, 63 - RGB.B));
      GotoXY(50, 10);
      Write(RGB.R: 2);
      GotoXY(59, 10);
      Write(RGB.G: 2);
      GotoXY(68, 10);
      Write(RGB.B: 2);
      OldRGB := RGB;
      MouseShow;
    end;
    repeat
      HandleButton4(Mono, Save, OK, Cancel, Key, B4);
      if MouseButton = 1 then
        if ScreenRows = MouseY then
        begin
          SaveWin(W);
          case MouseX of
            2..7: if StatusBtn('Hilfe', 3, 2, 7) then Key := $423;
            9..13: if StatusBtn('Rot'#$F1, 10, 9, 14) then Key := $424;
            17..22: if StatusBtn('Gr'#$81'n'#$F1, 18, 17, 23) then Key := $425;
            25..30: if StatusBtn('Blau'#$F1, 26, 25, 31) then Key := $426;
            33..38: if StatusBtn('PSave', 34, 33, 39) then Key := $427;
            41..46: if StatusBtn('Pload', 42, 41, 47) then Key := $428;
            49..55: if StatusBtn('Vorher', 50, 49, 56) then Key := $429;
            57..63: if StatusBtn('CReset', 58, 57, 64) then Key := $42A;
            65..71: if StatusBtn('PReset', 66, 65, 72) then Key := $42B;
            73..78: if StatusBtn('Ende', 75, 73, 79) then Key := $42C;
          end;
          RestoreWin(W);
        end;
      if MouseButton = 2 then
        if ScreenRows = MouseY then
        begin
          SaveWin(W);
          case MouseX of
            9..13: if StatusBtn('Rot'#$F1, 10, 9, 14) then Key := $451;
            17..22: if StatusBtn('Gr'#$81'n'#$F1, 18, 17, 23) then Key := $452;
            25..30: if StatusBtn('Blau'#$F1, 26, 25, 31) then Key := $453;
          end;
          RestoreWin(W);
        end;
      if LoCaseW(Key) = 'o' then OK := True;
      if LoCaseW(Key) = 's' then Save := True;
      if LoCaseW(Key) = 'a' then Cancel := True;
      if LoCaseW(Key) = 'm' then Mono := True;
      if IsCancel(Key) then Cancel := True;
      if Mono then
      begin
        Key := $6D;
      RGB.R := 0;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(0, RGB);
      RGB.R := 12;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(1, RGB);
      RGB.R := 63;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(2, RGB);
      RGB.R := 30;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(3, RGB);
      RGB.R := 43;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(4, RGB);
      RGB.R := 25;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(5, RGB);
      RGB.R := 26;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(6, RGB);
      RGB.R := 40;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(7, RGB);
      RGB.R := 21;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(8, RGB);
      RGB.R := 26;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(9, RGB);
      RGB.R := 46;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(10, RGB);
      RGB.R := 43;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(11, RGB);
      RGB.R := 34;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(12, RGB);
      RGB.R := 38;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(13, RGB);
      RGB.R := 63;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(14, RGB);
      RGB.R := 63;
      RGB.G := RGB.R;
      RGB.B := RGB.R;
      SetRGB(15, RGB);
        GetRGB(Col, RGB);
      end;
    until (Key <> 0) or (MouseButton <> 0) or OK or Save or Cancel;
  until OK or Cancel or Save;
  PopScreen(DlgStack);
  if Cancel then
    for I := 0 to 15 do SetRGB(I, TPalArr(CfgBlkAFE)[I])
  else
    for I := 0 to 15 do GetRGB(I, TPalArr(CfgBlkAFE)[I]);
  if Save then SaveColors;
  WaitRelease;
end;

end.
