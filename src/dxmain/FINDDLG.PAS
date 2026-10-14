{$O+,F+,G+,S-,I+,X+,V-}
unit FindDlg;

interface

uses Dos;

type
  Str2 = string[2];
  TDriveSet = array[1..26] of Boolean;
  TFilterEntry = record
    Name: NameStr;
    Ext: ExtStr;
    NameLen, ExtLen: Byte;
  end;
  TFilterList = array[1..20] of TFilterEntry;

function FindDialog(var Mask, Text: string; var Attr: Word; var MaxSize, MinSize, MinTime, MaxTime: Longint;
  var Exclude, ToFile, FromCurrent, AllDrives: Boolean; var Filters: TFilterList; var NFilters: Byte;
  Drive: Char; var Selected, Valid: TDriveSet; var DriveStr: Str2): Boolean;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, Help, Lists, Toggle, Pickers, Filters,
  U1439;

const
  Blank = '                                                                '
    + '                                                                '
    + '                                                                '
    + '                                                               ';

const
  DateTo: Str12 = '';
  DateFrom: Str12 = '';
  MinSizeStr: Str12 = '';
  MaxSizeStr: Str12 = '';
  Archive: Boolean = False;
  ReadOnly: Boolean = False;
  SysAttr: Boolean = False;
  Hidden: Boolean = False;

function FindDialog(var Mask, Text: string; var Attr: Word; var MaxSize, MinSize, MinTime, MaxTime: Longint;
  var Exclude, ToFile, FromCurrent, AllDrives: Boolean; var Filters: TFilterList; var NFilters: Byte;
  Drive: Char; var Selected, Valid: TDriveSet; var DriveStr: Str2): Boolean;
label
  Vom, Bis, Groesser, Kleiner, Dateien, PickVom, PickBis, PickGroesser, PickKleiner;
var
  I: Word;
  Key: Word;
  B: TButton5;
  Search, Exclude1, Cancel, Load, Save: Boolean;
  Code: Integer;
  Unused: array[1..3] of Word;
  SaveS: string[128];
  Tog1, Tog2, Tog3: TToggle;
  Opts: TFilterOpts;
  DayS, MonS, YearS: string[5];
  DT: DateTime;

procedure Title;
var
  W: TWinState;
begin
  SaveWin(W);
  MouseHide;
  PlainFrame(1, 1, 78, 1, 11, 3, 0);
  WriteXY(6, 1, 'Erweiterte Suche nach Dateien ');
  MouseShow;
  RestoreWin(W);
end;

procedure ChangeDrive;
var
  Dir: string[79];
  C: Char;
  W: TWinState;
  I: Byte;
  Map: TMouseMap;
begin
  SaveWin(W);
  Map := MouseMap;
  GetDir(0, Dir);
  C := SelectDrive(20, 8, Dir[1]);
  if C <> ' ' then
  begin
    {$I-}
    ChDir(C + ':');
    if IOResult = 0 then
    begin
      DriveStr := C + ':';
      AllDrives := False;
      if UpCase(C) <> UpCase(Dir[1]) then FromCurrent := False;
      for I := 1 to 26 do Selected[I] := False;
      Selected[Ord(DriveStr[1]) - 64] := True;
      Title;
    end;
  end;
  {$I+}
  ChDir(Dir);
  RestoreWin(W);
  MouseMap := Map;
end;

procedure TitleBar;
var
  W: TWinState;
begin
  SaveWin(W);
  MouseHide;
  PlainFrame(1, 1, 78, 1, 11, 3, 1);
  WriteXYFB(6, 1, 14, 3, ' Erweiterte Suche nach Dateien');
  MouseShow;
  repeat
    Idle;
  until (MouseButton = 0) or (MouseY <> 2) or (MouseX < 2) or (MouseX > 79);
  Title;
  if (MouseY = 2) and (MouseX > 1) and (MouseX < 79) then ChangeDrive;
  RestoreWin(W);
end;

procedure AddFilter(N: Byte; S: Str12);
var
  Dir: string;
  I: Byte;
begin
  S := UpperStr(S);
  FSplit(S, Dir, Filters[N].Name, Filters[N].Ext);
  Filters[N].Name := Filters[N].Name + Blank;
  Filters[N].Ext := Filters[N].Ext + Blank;
  Filters[N].NameLen := Length(Filters[N].Name);
  Filters[N].ExtLen := Length(Filters[N].Ext);
  for I := 1 to 8 do
    if Filters[N].Name[I] = '*' then Filters[N].NameLen := I - 1;
  for I := 1 to 4 do
    if Filters[N].Ext[I] = '*' then Filters[N].ExtLen := I - 1;
  if Filters[N].ExtLen = 1 then Filters[N].ExtLen := 0;
end;

procedure ParseFilters(S: Str80);
var
  P: Byte;
  Part: Str12;
begin
  NFilters := 0;
  S := StripSpaces(S);
  if S[Length(S)] <> ';' then S := S + ';';
  P := Pos(';', S);
  while P > 0 do
  begin
    Part := Copy(S, 1, P - 1);
    if (Part <> '') and (NFilters = 20) then
      ErrorBox('Sie haben mehr als 20 Filter angegeben!', 'Es werden nur die ersten 20 Filter verarbeitet.');
    if (Part <> '') and (NFilters < 20) then
    begin
      Inc(NFilters);
      AddFilter(NFilters, Part);
    end;
    Delete(S, 1, P);
    P := Pos(';', S);
  end;
end;

procedure ShowAttrs;
begin
  MouseHide;
  if ReadOnly then WriteXY(50, 6, 'X') else WriteXY(50, 6, ' ');
  if Hidden then WriteXY(50, 7, 'X') else WriteXY(50, 7, ' ');
  if Archive then WriteXY(50, 8, 'X') else WriteXY(50, 8, ' ');
  if SysAttr then WriteXY(50, 9, 'X') else WriteXY(50, 9, ' ');
  MouseShow;
  WaitRelease;
end;

procedure DrawDrives;
var
  W: TWinState;
  I: Byte;
  Count: Byte;
  Dummy: Byte;
begin
  SaveWin(W);
  MouseHide;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 3);
  Write(' ');
  AllDrives := True;
  Count := 0;
  for I := 1 to 26 do
  begin
    if Selected[I] then
    begin
      Inc(Count);
      WriteXYFB(I * 3 - 1, 1, 14, 4, ' ' + Chr(I + 64) + ' ');
    end
    else
      WriteXY(I * 3 - 1, 1, ' ' + Chr(I + 64) + ' ');
    if (I > 2) and (Selected[I] <> Valid[I]) then AllDrives := False;
  end;
  RestoreWin(W);
  MouseShow;
  Tog2.Checked := AllDrives;
  if AllDrives or (Count > 1) then FromCurrent := False;
  Tog3.Checked := FromCurrent;
  Tog2.Draw;
  Tog3.Draw;
end;

procedure SetDrives(All: Boolean);
var
  I: Byte;
begin
  if AllDrives then
  begin
    Selected := Valid;
    Selected[1] := False;
    Selected[2] := False;
  end
  else if All then
  begin
    for I := 1 to 26 do Selected[I] := False;
    Selected[Ord(DriveStr[1]) - 64] := True;
  end;
  DrawDrives;
end;

procedure ClickDrive;
var
  W: TWinState;
  I: Byte;
begin
  SaveWin(W);
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
    Selected[I] := not Selected[I];
  RestoreWin(W);
  DrawDrives;
  WaitRelease;
end;

procedure ShowFields;
begin
  InputLine(22, 7, 0, 0, DateFrom, 10, 0, #216, False);
  InputLine(22, 9, 0, 0, DateTo, 10, 0, #216, False);
  InputLine(22, 11, 0, 0, MinSizeStr, 10, 0, #216, False);
  InputLine(22, 13, 0, 0, MaxSizeStr, 10, 0, #216, False);
  InputLine(14, 17, 0, 0, Mask, 26, 0, #216, False);
  InputLine(11, 19, 0, 0, Text, 29, 0, #216, False);
end;

begin
  FindDialog := True;
  Val(MaxSizeStr, MaxSize, Code);
  Val(MinSizeStr, MinSize, Code);
  DT.Hour := 23;
  DT.Min := 59;
  DT.Sec := 59;
  if DateTo <> '' then
  begin
    ParseDate(DateTo, DT.Year, DT.Month, DT.Day);
    PackTime(DT, MaxTime);
  end
  else
    MaxTime := $7FFFFFFF;
  DT.Hour := 0;
  DT.Min := 0;
  DT.Sec := 0;
  if DateFrom <> '' then
  begin
    ParseDate(DateFrom, DT.Year, DT.Month, DT.Day);
    PackTime(DT, MinTime);
  end
  else
    MinTime := $80000000;
  MouseHide;
  Window(1, ScreenRows, 80, ScreenRows);
  SetColor(0, 3);
  ClrScr;
  Frame(1, 1, 78, 1, 11, 3, 0, 0);
  Frame(1, 4, 78, ScreenRows - 6, 11, 6, 0, 0);
  TextColor(11);
  Frame(45, 5, 19, 4, 11, 6, 0, 0);
  Frame(6, 5, 31, 9, 11, 6, 0, 0);
  Window(2, 5, 80, ScreenRows);
  if CfgColors[32] <> 0 then
    WriteCenterXY(1, 17, 78, 'Die Tastenk'#$81'rzel gelten hier nur zusammen mit der Alt-Taste.');
  if CfgColors[32] <> 0 then
    WriteCenterXY(1, 18, 78, 'Direkte Buchstabentasten w'#$84'hlen die Laufwerke auf denen gesucht wird.');
  if CfgColors[32] <> 0 then
    WriteCenterXY(1, 19, 78, 'Es sind maximal 20 durch Semikolon getrennte Filter im Dateinamen erlaubt.');
  WriteXY(48, 2, '[ ] Nur-Lesen');
  WriteXYF(56, 2, 14, 'L');
  WriteXY(48, 3, '[ ] Versteckt');
  WriteXYF(53, 3, 14, 'e');
  WriteXY(48, 4, '[ ] Archiv');
  WriteXYF(52, 4, 14, 'A');
  WriteXY(48, 5, '[ ] System');
  WriteXYF(52, 5, 14, 'S');
  WriteXY(66, 2, 'Die Dateien');
  WriteXY(66, 3, 'sollen diese');
  WriteXY(66, 4, 'Attribute');
  WriteXY(66, 5, 'besitzen.');
  WriteXY(8, 3, '        Vom:');
  WriteXYF(16, 3, 14, 'V');
  WriteXY(38, 3, 'max.');
  WriteXY(38, 4, 'bis');
  WriteXY(8, 5, '    Bis zum:');
  WriteXYF(12, 5, 14, 'B');
  WriteXY(38, 5, '2043');
  WriteXY(8, 7, ' Gr'#$94#$e1'er als:');
  WriteXYF(9, 7, 14, 'G');
  WriteXY(8, 9, 'Kleiner als:');
  WriteXYF(8, 9, 14, 'K');
  DrawDownArrow(33, 3);
  DrawDownArrow(33, 5);
  DrawDownArrow(33, 7);
  DrawDownArrow(33, 9);
  WriteXYF(4, 13, 14, 'D');
  Write('ateien:');
  WriteXYF(4, 15, 14, 'T');
  Write('ext:');
  TextColor(0);
  ShowFields;
  InitButton5(1, 3, ScreenRows - 4, 28, ScreenRows - 4, 44, ScreenRows - 4, 54, ScreenRows - 4, 68, ScreenRows - 4,
    14, 0, 11, 6, 'Diese Dateien suchen', 'Diese nicht', 'Laden', 'Speichern', 'Abbruch', B);
  Tog1.Init(ToFile, 45, 12, 14, 0, 11, 6, 'Ein', 'Aus');
  WriteXY(53, 13, 'Ausgabe in Datei');
  WriteXYF(61, 13, 14, 'i');
  Tog2.Init(AllDrives, 45, 15, 14, 0, 11, 6, 'Ein', 'Aus');
  WriteXY(53, 16, 'Alle Laufwerke ab C:');
  WriteXYF(62, 16, 14, 'w');
  Tog3.Init(False, 45, 18, 14, 0, 11, 6, 'Ein', 'Aus');
  WriteXY(53, 19, 'Ab aktuellem Verzeichnis');
  WriteXYF(69, 19, 14, 'z');
  MouseShow;
  ShowAttrs;
  DrawDrives;
  Title;
  Key := $408;
  repeat
    if Key = $417 then
    begin
Vom:
      SaveS := DateFrom;
      Key := InputLine(22, 7, 0, 0, DateFrom, 10, 10, #216, False);
      if Key = $C08 then
      begin
PickVom:
        GetDate(DT.Year, DT.Month, DT.Day, Key);
        if PickDate(23, 7, 9, 6, DT.Year, DT.Month, DT.Day, DateFrom) then Key := 13;
      end;
      if (Key in [9, 13]) or (Key = $3F7) then
      begin
        DT.Hour := 0;
        DT.Min := 0;
        DT.Sec := 0;
        if DateFrom <> '' then
          if not ParseDate(DateFrom, DT.Year, DT.Month, DT.Day) or (DT.Year < 1916) or (DT.Year > 2043) then
          begin
            DateFrom := SaveS;
            goto Vom;
          end;
        if DateFrom <> '' then PackTime(DT, MinTime) else MinTime := $80000000;
        InputLine(22, 7, 0, 0, DateFrom, 10, 0, #216, False);
      end;
      if Key = 9 then Key := $418;
    end;
    if Key = $418 then
    begin
Bis:
      SaveS := DateTo;
      Key := InputLine(22, 9, 0, 0, DateTo, 10, 10, #216, False);
      if Key = $C08 then
      begin
PickBis:
        GetDate(DT.Year, DT.Month, DT.Day, Key);
        if PickDate(23, 9, 9, 6, DT.Year, DT.Month, DT.Day, DateTo) then Key := 13;
      end;
      if (Key in [9, 13]) or (Key = $3F7) then
      begin
        DT.Hour := 23;
        DT.Min := 59;
        DT.Sec := 59;
        if DateTo <> '' then
          if not ParseDate(DateTo, DT.Year, DT.Month, DT.Day) or (DT.Year > 2043) or (DT.Year < 1916) then
          begin
            DateTo := SaveS;
            goto Bis;
          end;
        if DateTo <> '' then PackTime(DT, MaxTime) else MaxTime := $7FFFFFFF;
        InputLine(22, 9, 0, 0, DateTo, 10, 0, #216, False);
      end;
      if Key = 9 then Key := $40A;
      if Key = $3F7 then goto Vom;
    end;
    if Key = $40A then
    begin
Groesser:
      DigOnly := True;
      Key := InputLine(22, 11, 0, 0, MinSizeStr, 9, 9, #216, False);
      DigOnly := False;
      if (Key in [9, 13]) or (Key = $3F7) then Val(MinSizeStr, MinSize, Code);
      if Key = 9 then Key := $40D;
      if Key = $3F7 then goto Bis;
      if Key = $C08 then
      begin
PickGroesser:
        PickSize(27, 11, 11, 6, MinSizeStr);
        InputLine(22, 11, 0, 0, MinSizeStr, 9, 0, #216, False);
        Val(MinSizeStr, MinSize, Code);
      end;
    end;
    if Key = $40D then
    begin
Kleiner:
      DigOnly := True;
      Key := InputLine(22, 13, 0, 0, MaxSizeStr, 9, 9, #216, False);
      DigOnly := False;
      if (Key in [9, 13]) or (Key = $3F7) then Val(MaxSizeStr, MaxSize, Code);
      if Key = 9 then Key := $408;
      if Key = $3F7 then goto Groesser;
      if Key = $C08 then
      begin
PickKleiner:
        PickSize(27, 13, 9, 6, MaxSizeStr);
        InputLine(22, 13, 0, 0, MaxSizeStr, 9, 0, #216, False);
        Val(MaxSizeStr, MaxSize, Code);
      end;
    end;
    if Key = $408 then
    begin
Dateien:
      Key := InputLine(14, 17, 13, 42, Mask, 26, 80, #216, False);
      ParseFilters(Mask);
      if NFilters = 0 then Mask := '';
      if Key = $3F7 then goto Kleiner;
      if Key = 9 then Key := $3FC;
    end;
    if Key = $3FC then
    begin
      Key := InputLine(11, 19, 10, 42, Text, 29, 80, #216, False);
      if Key = $3F7 then goto Dateien;
    end;
    RestoreButton5(B);
    repeat
      HandleButton5(Search, Exclude1, Load, Save, Cancel, Key, B);
      if Load then
      begin
        ResetButton5(B);
        if LoadFilter(Mask, Opts) then
        begin
          MinSize := Opts.MinSize;
          MaxSize := Opts.MaxSize;
          MinTime := Opts.MinTime;
          MaxTime := Opts.MaxTime;
          Str(MinSize, MinSizeStr);
          Str(MaxSize, MaxSizeStr);
          UnpackTime(Opts.MinTime, DT);
          Str(DT.Day, DayS);
          Str(DT.Month, MonS);
          Str(DT.Year, YearS);
          DateFrom := DayS + '.' + MonS + '.' + YearS;
          ParseDate(DateFrom, DT.Year, DT.Month, DT.Day);
          if Opts.MinTime = $80000000 then DateFrom := '';
          UnpackTime(Opts.MaxTime, DT);
          Str(DT.Day, DayS);
          Str(DT.Month, MonS);
          Str(DT.Year, YearS);
          DateTo := DayS + '.' + MonS + '.' + YearS;
          ParseDate(DateTo, DT.Year, DT.Month, DT.Day);
          if Opts.MaxTime = $7FFFFFFF then DateTo := '';
          MouseHide;
          ShowFields;
          MouseShow;
          ParseFilters(Mask);
          if NFilters = 0 then Mask := '';
          ReadOnly := Opts.Attr and 1 <> 0;
          Hidden := Opts.Attr and 2 <> 0;
          Archive := Opts.Attr and $20 <> 0;
          SysAttr := Opts.Attr and 4 <> 0;
          ShowAttrs;
        end;
        RestoreButton5(B);
      end;
      if Save then
      begin
        ResetButton5(B);
        Opts.MinTime := MinTime;
        Opts.MaxTime := MaxTime;
        Opts.MaxSize := MaxSize;
        Opts.MinSize := MinSize;
        Opts.Attr := 0;
        if Hidden then Opts.Attr := Opts.Attr + 2;
        if ReadOnly then Opts.Attr := Opts.Attr + 1;
        if SysAttr then Opts.Attr := Opts.Attr + 4;
        if Archive then Opts.Attr := Opts.Attr + $20;
        SaveFilter(Mask, Opts);
        RestoreButton5(B);
      end;
      if Key = $423 then ShowHelp(24);
      if Key = $450 then
      begin
        ChangeDrive;
        DrawDrives;
      end;
      if Tog1.Clicked then ToFile := Tog1.Checked;
      if Tog2.Clicked or (Key = $3F9) then
      begin
        if Key = $3F9 then Tog2.Toggle;
        AllDrives := Tog2.Checked;
        if AllDrives then FromCurrent := False;
        SetDrives(True);
      end;
      if Tog3.Clicked or (Key = $414) then
      begin
        if Key = $414 then Tog3.Toggle;
        FromCurrent := Tog3.Checked;
        if FromCurrent then
        begin
          AllDrives := False;
          DriveStr := Drive + ':';
        end;
        SetDrives(FromCurrent);
      end;
      if (LoCaseW(Key) in ['a'..'z']) and Valid[Ord(LoCaseW(Key)) - 96] then
      begin
        Key := Ord(LoCaseW(Key));
        Selected[Key - 96] := not Selected[Key - 96];
        DrawDrives;
      end;
      if MouseOn(2, 2, 79) then
      begin
        TitleBar;
        SetDrives(True);
      end;
      if MouseOn(7, 35, 35) then goto PickVom;
      if MouseOn(9, 35, 35) then goto PickBis;
      if MouseOn(11, 35, 35) then goto PickGroesser;
      if MouseOn(13, 35, 35) then goto PickKleiner;
      if MouseOn(6, 49, 61) then Key := $40E;
      if MouseOn(7, 49, 61) then Key := $3FA;
      if MouseOn(8, 49, 61) then Key := $406;
      if MouseOn(9, 49, 61) then Key := $407;
      if MouseOn(7, 22, 33) then Key := $417;
      if MouseOn(9, 22, 33) then Key := $418;
      if MouseOn(11, 22, 33) then Key := $40A;
      if MouseOn(13, 22, 33) then Key := $40D;
      if MouseOn(17, 14, 41) then Key := $408;
      if MouseOn(19, 12, 41) then Key := $3FC;
      if MouseOn(ScreenRows, 2, 79) then ClickDrive;
      case Key of
        $406:
          begin
            Archive := not Archive;
            ShowAttrs;
          end;
        $40E:
          begin
            ReadOnly := not ReadOnly;
            ShowAttrs;
          end;
        $3FA:
          begin
            Hidden := not Hidden;
            ShowAttrs;
          end;
        $407:
          begin
            SysAttr := not SysAttr;
            ShowAttrs;
          end;
        $3FF:
          begin
            ToFile := not ToFile;
            Tog1.Toggle;
          end;
      end;
      if (Key = 27) or (Key = $42C) or (MouseButton = 2) then Cancel := True;
      if (Key = 9) or (Key = $438) then Key := $417;
      if (Key = $3F7) or (Key = $430) then Key := $3FC;
      if (Mask = '') and (Search or Exclude1) then
      begin
        ErrorBox('Sie m'#$81'ssen mindestens einen Dateinamen angeben!',
          'DOS-Ersatzzeichen (Wildcards: *?) sind erlaubt.');
        Search := False;
        Exclude1 := False;
        Key := $408;
      end;
    until Search or Exclude1 or Cancel or (Key = $418) or (Key = $417) or (Key = $40A) or (Key = $40D)
      or (Key = $408) or (Key = $3FC);
    ResetButton5(B);
  until Search or Exclude1 or Cancel;
  if Cancel then
  begin
    FindDialog := False;
    WaitRelease;
  end
  else
  begin
    if Exclude1 then Exclude := True;
    Attr := 0;
    if Hidden then Attr := Attr + 2;
    if ReadOnly then Attr := Attr + 1;
    if SysAttr then Attr := Attr + 4;
    if Archive then Attr := Attr + $20;
    for I := 1 to 26 do
      if Selected[I] then Inc(Key);
    if Key = 1 then
      for I := 1 to 26 do
        if Selected[I] then DriveStr := Chr(I + 64) + ':';
  end;
end;

end.
