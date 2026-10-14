{$O+,F+,G+,S-,I-,X+,V-}
unit ExtColor;
{ Overlay 0340: "Farbeinstellung fÅr Dateitypen" - text/background colour per file extension
  (16 rows: bat com dll exe hlp ini sys pcx gif bmp ttf pif txt UPDIR DIREC SONST), stored in the
  32-byte colour block of dx.ini }

interface

procedure FileColors;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, ScrSave, Help;

type
  TColorPair = record
    Fg, Bg: Byte;
  end;
  TColorTab = array[3..18] of TColorPair;

procedure SaveColors;
var
  F: file of TConfig;
  Cfg: TConfig;
  Err: Boolean;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  Read(F, Cfg);
  Close(F);
  Err := (IOResult <> 0) or (Cfg.Id <> IniId);
  if not Err then
  begin
    Cfg.Colors[2] := CfgColors[2];
    Cfg.Blk562 := TBlk32(CfgBlkA9C);
    Rewrite(F);
    Write(F, Cfg);
    Close(F);
    Err := IOResult <> 0;
  end;
  if Err then
    MsgBox('Fehler beim Erstellen von ' + IniName + '!', 'Einstellungen konnten nicht gespeichert werden.');
end;

procedure FileColors;
var
  I: Word;
  J: Word;
  B: TButton4;
  Take, Save, Prev, Cancel: Boolean;
  Key: Word;
  Line: string[80];
  Fg, Bg: Byte;
  Colors: TColorTab;
  SaveTab: TColorTab;
  Row: Byte;
  LastX, LastY: Byte;

procedure ColorBar;
begin
  WriteF(0, #$DB#$DB#$DB);
  WriteF(1, #$DB#$DB#$DB);
  WriteF(2, #$DB#$DB#$DB);
  WriteF(3, #$DB#$DB#$DB);
  WriteF(4, #$DB#$DB#$DB);
  WriteF(5, #$DB#$DB#$DB);
  WriteF(6, #$DB#$DB#$DB);
  WriteF(7, #$DB#$DB#$DB);
  WriteF(8, #$DB#$DB#$DB);
  WriteF(9, #$DB#$DB#$DB);
  WriteF(10, #$DB#$DB#$DB);
  WriteF(11, #$DB#$DB#$DB);
  WriteF(12, #$DB#$DB#$DB);
  WriteF(13, #$DB#$DB#$DB);
  WriteF(14, #$DB#$DB#$DB);
  WriteF(15, #$DB#$DB#$DB);
  WriteF(0, #$DB#$DB#$DB);
  WriteF(1, #$DB#$DB#$DB);
  WriteF(2, #$DB#$DB#$DB);
  WriteF(3, #$DB#$DB#$DB);
  WriteF(4, #$DB#$DB#$DB);
  WriteF(5, #$DB#$DB#$DB);
  WriteF(6, #$DB#$DB#$DB);
  WriteF(7, #$DB#$DB#$DB);
end;

procedure DrawLabels;
begin
  MouseHide;
  WriteXYFB(1, ScreenRows - 1, Fg, Bg, Line);
  WriteXYFB(1, 3, Colors[3].Fg, Colors[3].Bg, ' bat:');
  WriteXYFB(1, 4, Colors[4].Fg, Colors[4].Bg, ' com:');
  WriteXYFB(1, 5, Colors[5].Fg, Colors[5].Bg, ' dll:');
  WriteXYFB(1, 6, Colors[6].Fg, Colors[6].Bg, ' exe:');
  WriteXYFB(1, 7, Colors[7].Fg, Colors[7].Bg, ' hlp:');
  WriteXYFB(1, 8, Colors[8].Fg, Colors[8].Bg, ' ini:');
  WriteXYFB(1, 9, Colors[9].Fg, Colors[9].Bg, ' sys:');
  WriteXYFB(1, 10, Colors[10].Fg, Colors[10].Bg, ' pcx:');
  WriteXYFB(1, 11, Colors[11].Fg, Colors[11].Bg, ' gif:');
  WriteXYFB(1, 12, Colors[12].Fg, Colors[12].Bg, ' bmp:');
  WriteXYFB(1, 13, Colors[13].Fg, Colors[13].Bg, ' ttf:');
  WriteXYFB(1, 14, Colors[14].Fg, Colors[14].Bg, ' pif:');
  WriteXYFB(1, 15, Colors[15].Fg, Colors[15].Bg, ' txt:');
  WriteXYFB(1, 16, Colors[16].Fg, Colors[16].Bg, 'UPDIR');
  WriteXYFB(1, 17, Colors[17].Fg, Colors[17].Bg, 'DIREC');
  WriteXYFB(1, 18, Colors[18].Fg, Colors[18].Bg, 'SONST');
  MouseShow;
end;

procedure DrawAll;
begin
  MouseHide;
  WriteXYFB(1, 3, Colors[3].Fg, Colors[3].Bg, ' bat:');
  ColorBar;
  WriteXYFB(1, 4, Colors[4].Fg, Colors[4].Bg, ' com:');
  ColorBar;
  WriteXYFB(1, 5, Colors[5].Fg, Colors[5].Bg, ' dll:');
  ColorBar;
  WriteXYFB(1, 6, Colors[6].Fg, Colors[6].Bg, ' exe:');
  ColorBar;
  WriteXYFB(1, 7, Colors[7].Fg, Colors[7].Bg, ' hlp:');
  ColorBar;
  WriteXYFB(1, 8, Colors[8].Fg, Colors[8].Bg, ' ini:');
  ColorBar;
  WriteXYFB(1, 9, Colors[9].Fg, Colors[9].Bg, ' sys:');
  ColorBar;
  WriteXYFB(1, 10, Colors[10].Fg, Colors[10].Bg, ' pcx:');
  ColorBar;
  WriteXYFB(1, 11, Colors[11].Fg, Colors[11].Bg, ' gif:');
  ColorBar;
  WriteXYFB(1, 12, Colors[12].Fg, Colors[12].Bg, ' bmp:');
  ColorBar;
  WriteXYFB(1, 13, Colors[13].Fg, Colors[13].Bg, ' ttf:');
  ColorBar;
  WriteXYFB(1, 14, Colors[14].Fg, Colors[14].Bg, ' pif:');
  ColorBar;
  WriteXYFB(1, 15, Colors[15].Fg, Colors[15].Bg, ' txt:');
  ColorBar;
  WriteXYFB(1, 16, Colors[16].Fg, Colors[16].Bg, 'UPDIR');
  ColorBar;
  WriteXYFB(1, 17, Colors[17].Fg, Colors[17].Bg, 'DIREC');
  ColorBar;
  WriteXYFB(1, 18, Colors[18].Fg, Colors[18].Bg, 'SONST');
  ColorBar;
  WriteXYFB(1, ScreenRows - 1, Fg, Bg, Line);
  MouseShow;
end;

procedure PickColor(Y: Byte; var Fg, Bg: Byte);
var
  MarkFg, MarkBg: Byte;
  Dummy: Word;
begin
  MouseHide;
  MarkFg := 2;
  MarkBg := 0;
  if Byte(MouseX) in [7..54] then
  begin
    if Byte(MouseX) in [7..9] then
    begin
      Fg := 0;
      WriteXYFB(7, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(7, Y, 0, #$DB);
    if Byte(MouseX) in [10..12] then
    begin
      Fg := 1;
      WriteXYFB(10, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(10, Y, 1, #$DB);
    if Byte(MouseX) in [13..15] then
    begin
      Fg := 2;
      WriteXYFB(13, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(13, Y, 2, #$DB);
    if Byte(MouseX) in [16..18] then
    begin
      Fg := 3;
      WriteXYFB(16, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(16, Y, 3, #$DB);
    if Byte(MouseX) in [19..21] then
    begin
      Fg := 4;
      WriteXYFB(19, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(19, Y, 4, #$DB);
    if Byte(MouseX) in [22..24] then
    begin
      Fg := 5;
      WriteXYFB(22, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(22, Y, 5, #$DB);
    if Byte(MouseX) in [25..27] then
    begin
      Fg := 6;
      WriteXYFB(25, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(25, Y, 6, #$DB);
    if Byte(MouseX) in [28..30] then
    begin
      Fg := 7;
      WriteXYFB(28, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(28, Y, 7, #$DB);
    if Byte(MouseX) in [31..33] then
    begin
      Fg := 8;
      WriteXYFB(31, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(31, Y, 8, #$DB);
    if Byte(MouseX) in [34..36] then
    begin
      Fg := 9;
      WriteXYFB(34, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(34, Y, 9, #$DB);
    if Byte(MouseX) in [37..39] then
    begin
      Fg := 10;
      WriteXYFB(37, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(37, Y, 10, #$DB);
    if Byte(MouseX) in [40..42] then
    begin
      Fg := 11;
      WriteXYFB(40, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(40, Y, 11, #$DB);
    if Byte(MouseX) in [43..45] then
    begin
      Fg := 12;
      WriteXYFB(43, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(43, Y, 12, #$DB);
    if Byte(MouseX) in [46..48] then
    begin
      Fg := 13;
      WriteXYFB(46, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(46, Y, 13, #$DB);
    if Byte(MouseX) in [49..51] then
    begin
      Fg := 14;
      WriteXYFB(49, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(49, Y, 14, #$DB);
    if Byte(MouseX) in [52..54] then
    begin
      Fg := 15;
      WriteXYFB(52, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(52, Y, 15, #$DB);
  end
  else if Byte(MouseX) in [55..78] then
  begin
    if Byte(MouseX) in [55..57] then
    begin
      Bg := 0;
      WriteXYFB(55, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(55, Y, 0, #$DB);
    if Byte(MouseX) in [58..60] then
    begin
      Bg := 1;
      WriteXYFB(58, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(58, Y, 1, #$DB);
    if Byte(MouseX) in [61..63] then
    begin
      Bg := 2;
      WriteXYFB(61, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(61, Y, 2, #$DB);
    if Byte(MouseX) in [64..66] then
    begin
      Bg := 3;
      WriteXYFB(64, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(64, Y, 3, #$DB);
    if Byte(MouseX) in [67..69] then
    begin
      Bg := 4;
      WriteXYFB(67, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(67, Y, 4, #$DB);
    if Byte(MouseX) in [70..72] then
    begin
      Bg := 5;
      WriteXYFB(70, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(70, Y, 5, #$DB);
    if Byte(MouseX) in [73..75] then
    begin
      Bg := 6;
      WriteXYFB(73, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(73, Y, 6, #$DB);
    if Byte(MouseX) in [76..78] then
    begin
      Bg := 7;
      WriteXYFB(76, Y, MarkFg, MarkBg, 'X');
    end
    else WriteXYF(76, Y, 7, #$DB);
  end;
  MouseShow;
end;

procedure SetRow(N: Byte);
begin
  if N < 3 then N := 18;
  if N > 18 then N := 3;
  MouseHide;
  WriteXYFB(77, Row, 0, 7, ' ');
  WriteXYFB(6, Row, 2, 0, ' ');
  WriteXYFB(77, N, 0, 7, #$1B);
  WriteXYFB(6, N, 2, 0, #$1A);
  Row := N;
  MouseShow;
  case Row of
    3:
      begin
        Fg := Colors[3].Fg;
        Bg := Colors[3].Bg;
      end;
    4:
      begin
        Fg := Colors[4].Fg;
        Bg := Colors[4].Bg;
      end;
    5:
      begin
        Fg := Colors[5].Fg;
        Bg := Colors[5].Bg;
      end;
    6:
      begin
        Fg := Colors[6].Fg;
        Bg := Colors[6].Bg;
      end;
    7:
      begin
        Fg := Colors[7].Fg;
        Bg := Colors[7].Bg;
      end;
    8:
      begin
        Fg := Colors[8].Fg;
        Bg := Colors[8].Bg;
      end;
    9:
      begin
        Fg := Colors[9].Fg;
        Bg := Colors[9].Bg;
      end;
    10:
      begin
        Fg := Colors[10].Fg;
        Bg := Colors[10].Bg;
      end;
    11:
      begin
        Fg := Colors[11].Fg;
        Bg := Colors[11].Bg;
      end;
    12:
      begin
        Fg := Colors[12].Fg;
        Bg := Colors[12].Bg;
      end;
    13:
      begin
        Fg := Colors[13].Fg;
        Bg := Colors[13].Bg;
      end;
    14:
      begin
        Fg := Colors[14].Fg;
        Bg := Colors[14].Bg;
      end;
    15:
      begin
        Fg := Colors[15].Fg;
        Bg := Colors[15].Bg;
      end;
    16:
      begin
        Fg := Colors[16].Fg;
        Bg := Colors[16].Bg;
      end;
    17:
      begin
        Fg := Colors[17].Fg;
        Bg := Colors[17].Bg;
      end;
    18:
      begin
        Fg := Colors[18].Fg;
        Bg := Colors[18].Bg;
      end;
  end;
end;

procedure DrawMarks;
begin
  MouseHide;
  WriteXYFB(Colors[3].Bg * 3 + 55, 3, 2, 0, 'X');
  WriteXYFB(Colors[4].Bg * 3 + 55, 4, 2, 0, 'X');
  WriteXYFB(Colors[5].Bg * 3 + 55, 5, 2, 0, 'X');
  WriteXYFB(Colors[6].Bg * 3 + 55, 6, 2, 0, 'X');
  WriteXYFB(Colors[7].Bg * 3 + 55, 7, 2, 0, 'X');
  WriteXYFB(Colors[8].Bg * 3 + 55, 8, 2, 0, 'X');
  WriteXYFB(Colors[9].Bg * 3 + 55, 9, 2, 0, 'X');
  WriteXYFB(Colors[10].Bg * 3 + 55, 10, 2, 0, 'X');
  WriteXYFB(Colors[11].Bg * 3 + 55, 11, 2, 0, 'X');
  WriteXYFB(Colors[12].Bg * 3 + 55, 12, 2, 0, 'X');
  WriteXYFB(Colors[13].Bg * 3 + 55, 13, 2, 0, 'X');
  WriteXYFB(Colors[14].Bg * 3 + 55, 14, 2, 0, 'X');
  WriteXYFB(Colors[15].Bg * 3 + 55, 15, 2, 0, 'X');
  WriteXYFB(Colors[16].Bg * 3 + 55, 16, 2, 0, 'X');
  WriteXYFB(Colors[17].Bg * 3 + 55, 17, 2, 0, 'X');
  WriteXYFB(Colors[18].Bg * 3 + 55, 18, 2, 0, 'X');
  WriteXYFB(Colors[3].Fg * 3 + 7, 3, 2, 0, 'X');
  WriteXYFB(Colors[4].Fg * 3 + 7, 4, 2, 0, 'X');
  WriteXYFB(Colors[5].Fg * 3 + 7, 5, 2, 0, 'X');
  WriteXYFB(Colors[6].Fg * 3 + 7, 6, 2, 0, 'X');
  WriteXYFB(Colors[7].Fg * 3 + 7, 7, 2, 0, 'X');
  WriteXYFB(Colors[8].Fg * 3 + 7, 8, 2, 0, 'X');
  WriteXYFB(Colors[9].Fg * 3 + 7, 9, 2, 0, 'X');
  WriteXYFB(Colors[10].Fg * 3 + 7, 10, 2, 0, 'X');
  WriteXYFB(Colors[11].Fg * 3 + 7, 11, 2, 0, 'X');
  WriteXYFB(Colors[12].Fg * 3 + 7, 12, 2, 0, 'X');
  WriteXYFB(Colors[13].Fg * 3 + 7, 13, 2, 0, 'X');
  WriteXYFB(Colors[14].Fg * 3 + 7, 14, 2, 0, 'X');
  WriteXYFB(Colors[15].Fg * 3 + 7, 15, 2, 0, 'X');
  WriteXYFB(Colors[16].Fg * 3 + 7, 16, 2, 0, 'X');
  WriteXYFB(Colors[17].Fg * 3 + 7, 17, 2, 0, 'X');
  WriteXYFB(Colors[18].Fg * 3 + 7, 18, 2, 0, 'X');
  MouseShow;
end;

procedure Restore;
begin
  Colors := SaveTab;
  DrawAll;
  DrawMarks;
end;

begin
  Line := #$B3'TESTVER TST'#$B3#$10'SUB-DIR'#$11#$B3'30.01.96'#$B3' 23:24'#$B3'beispiel ext'#$B3 +
    '   234567'#$B3'11.06.96'#$B3' 13:19'#$B3;
  OpenDialog;
  ClockOff;
  Window(1, 1, 80, ScreenRows);
  SetColor(11, 1);
  GotoXY(1, ScreenRows);
  ClrEol;
  Colors := TColorTab(CfgBlkA9C);
  SaveTab := Colors;
  LastX := 0;
  LastY := 0;
  Frame(1, 1, 78, ScreenRows - 3, 11, 3, 0, 0);
  WriteXY(6, 1, '[  Textfarbe                                   ] [     Hintergrund     ]');
  WriteXYF(20, 1, 14, 'Farbeinstellung f'#$81'r Dateitypen');
  Window(1, 1, 80, ScreenRows);
  if not ThinButtons then
  begin
    for I := 4 to 19 do WriteXYF(79, I, 11, #$D0);
    for I := 2 to 78 do WriteXYF(I, 3, 0, #$D8);
    for I := 2 to 78 do WriteXYF(I, 20, 11, #$DD);
  end;
  Window(2, 2, 80, ScreenRows);
  if CfgColors[2] <> 0 then WriteXY(2, ScreenRows - 4, '[X] An')
  else WriteXY(2, ScreenRows - 4, '[ ] An');
  WriteXY(2, ScreenRows - 3, 'Space');
  Row := 15;
  SetRow(17);
  InitButton4(True, 8, ScreenRows - 5, 27, ScreenRows - 5, 45, ScreenRows - 5, 62, ScreenRows - 5, 14, 0, 11, 3,
    '  '#$9A'bernehmen  ', '  Speichern  ', '   Vorher   ', '  Abbruch  ', B);
  MouseShow;
  DrawAll;
  DrawMarks;
  repeat
    HandleButton4(Take, Save, Prev, Cancel, Key, B);
    if Key = $423 then ShowHelp(64);
    if MouseOn(ScreenRows - 3, 3, 8) or (Key = 32) or (Key = $406) then
    begin
      CfgColors[2] := Ord(CfgColors[2] = 0);
      MouseHide;
      if CfgColors[2] <> 0 then WriteXY(2, ScreenRows - 4, '[X] An')
      else WriteXY(2, ScreenRows - 4, '[ ] An');
      MouseShow;
      repeat until MouseButton = 0;
    end;
    if (LoCaseW(Key) = 'a') or IsCancel(Key) then Cancel := True;
    if LoCaseW(Key) = #$81 then Take := True;
    if LoCaseW(Key) = 'v' then Prev := True;
    if Key = $430 then
    begin
      SetRow(Row - 1);
      DrawLabels;
    end;
    if Key = $438 then
    begin
      SetRow(Row + 1);
      DrawLabels;
    end;
    if ((LastX <> MouseX) or (LastY <> MouseY)) and (MouseButton = 1) and (Byte(MouseY) in [4..19])
      and (Byte(MouseX) in [7..78]) then
    begin
      case MouseY of
        4:
          begin
            PickColor(3, Colors[3].Fg, Colors[3].Bg);
            Fg := Colors[3].Fg;
            Bg := Colors[3].Bg;
            SetRow(3);
          end;
        5:
          begin
            PickColor(4, Colors[4].Fg, Colors[4].Bg);
            Fg := Colors[4].Fg;
            Bg := Colors[4].Bg;
            SetRow(4);
          end;
        6:
          begin
            PickColor(5, Colors[5].Fg, Colors[5].Bg);
            Fg := Colors[5].Fg;
            Bg := Colors[5].Bg;
            SetRow(5);
          end;
        7:
          begin
            PickColor(6, Colors[6].Fg, Colors[6].Bg);
            Fg := Colors[6].Fg;
            Bg := Colors[6].Bg;
            SetRow(6);
          end;
        8:
          begin
            PickColor(7, Colors[7].Fg, Colors[7].Bg);
            Fg := Colors[7].Fg;
            Bg := Colors[7].Bg;
            SetRow(7);
          end;
        9:
          begin
            PickColor(8, Colors[8].Fg, Colors[8].Bg);
            Fg := Colors[8].Fg;
            Bg := Colors[8].Bg;
            SetRow(8);
          end;
        10:
          begin
            PickColor(9, Colors[9].Fg, Colors[9].Bg);
            Fg := Colors[9].Fg;
            Bg := Colors[9].Bg;
            SetRow(9);
          end;
        11:
          begin
            PickColor(10, Colors[10].Fg, Colors[10].Bg);
            Fg := Colors[10].Fg;
            Bg := Colors[10].Bg;
            SetRow(10);
          end;
        12:
          begin
            PickColor(11, Colors[11].Fg, Colors[11].Bg);
            Fg := Colors[11].Fg;
            Bg := Colors[11].Bg;
            SetRow(11);
          end;
        13:
          begin
            PickColor(12, Colors[12].Fg, Colors[12].Bg);
            Fg := Colors[12].Fg;
            Bg := Colors[12].Bg;
            SetRow(12);
          end;
        14:
          begin
            PickColor(13, Colors[13].Fg, Colors[13].Bg);
            Fg := Colors[13].Fg;
            Bg := Colors[13].Bg;
            SetRow(13);
          end;
        15:
          begin
            PickColor(14, Colors[14].Fg, Colors[14].Bg);
            Fg := Colors[14].Fg;
            Bg := Colors[14].Bg;
            SetRow(14);
          end;
        16:
          begin
            PickColor(15, Colors[15].Fg, Colors[15].Bg);
            Fg := Colors[15].Fg;
            Bg := Colors[15].Bg;
            SetRow(15);
          end;
        17:
          begin
            PickColor(16, Colors[16].Fg, Colors[16].Bg);
            Fg := Colors[16].Fg;
            Bg := Colors[16].Bg;
            SetRow(16);
          end;
        18:
          begin
            PickColor(17, Colors[17].Fg, Colors[17].Bg);
            Fg := Colors[17].Fg;
            Bg := Colors[17].Bg;
            SetRow(17);
          end;
        19:
          begin
            PickColor(18, Colors[18].Fg, Colors[18].Bg);
            Fg := Colors[18].Fg;
            Bg := Colors[18].Bg;
            SetRow(18);
          end;
      end;
      DrawLabels;
      LastX := MouseX;
      LastY := MouseY;
    end;
    if Prev then Restore;
  until Take or Save or Cancel;
  if Take or Save then TColorTab(CfgBlkA9C) := Colors;
  PopScreen(DlgStack);
  ClockOn;
  if Save then SaveColors;
end;

end.
