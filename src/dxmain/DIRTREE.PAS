{$O+,F+,G+,S-,I-,X+,V-}
unit DirTree;
{ Overlay 156b: directory tree scanner / size browser }

interface

uses DXGlob;

type
  PFileRec = ^TFileRec;
  TFileRec = record
    Name: string[12];
    Fill: array[13..20] of Byte;
    Attr: Byte;
    Sel: Boolean;
  end;
  TFileList = array[0..16000] of PFileRec;

function ScanDirs(var Path: string; var Size: Longint; var Dirs, Files: Word): Boolean;
function DirSums(Dir: string; var List: TFileList; Count: Integer; var Sel: Integer): Boolean;

implementation

uses Dos, Crt, Buttons, Mouse, Screen, Windows, Status, Dialogs, ScrSave, Lists, Help, Sounds,
  LongName, U1D10;

const
  Full: Boolean = False;
  Stop: Boolean = False;
  Line78 =
    #$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
    #$C4#$C4#$C4;
  Spaces =
    '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

type
  PDirRec = ^TDirRec;
  PEntry = ^TEntry;
  TEntry = record
    Name: string[12];
    Sub: PDirRec;
  end;
  TDirRec = record
    Path: string[80];
    Entries: array[1..255] of PEntry;
    Size: Longint;
    Count: Byte;
  end;
  PDirInfo = ^TDirInfo;
  TDirInfo = record
    Size: Longint;
    Subs: Byte;
    Path: string[79];
  end;
  PDirTab = ^TDirTab;
  TDirTab = array[1..4096] of PDirInfo;
  TSum = record
    Name: string[40];
    Size: Longint;
    Dirs, Files, Index: Word;
  end;
  PSums = ^TSums;
  TSums = array[1..1000] of TSum;

  TTreeList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
  TSumList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

var
  DirCount, GFiles, GDirs: Word;
  DirTab: PDirTab;
  Sums: PSums;
  SumCount: Word;
  G840, G841, G842, G870, G88A: Byte;

procedure AddDir(var D: TDirRec);
var
  S: string[79];
begin
  if Stop then Exit;
  if (MaxAvail < SizeOf(TDirInfo)) or Full or (DirCount >= $1000) then
  begin
    Full := True;
    Exit;
  end;
  Inc(DirCount);
  GetMem(DirTab^[DirCount], SizeOf(TDirInfo));
  S := Copy(D.Path, 1, Length(D.Path) - 4);
  if Length(S) = 2 then S := S + '\';
  DirTab^[DirCount]^.Size := D.Size;
  DirTab^[DirCount]^.Subs := D.Count;
  DirTab^[DirCount]^.Path := S;
end;

procedure ReadDir(var D: TDirRec);
var
  SR: SearchRec;
  S: string[4];
begin
  if Full then Exit;
  FindFirst(D.Path, $37, SR);
  if DosError >= 100 then
  begin
    Str(DosError, S);
    MsgBox('Es ist ein Fehler aufgetreten!', 'Dos-Fehler Nr.: ' + S);
    Full := True;
    Exit;
  end;
  if SR.Name = '.' then FindNext(SR);
  if SR.Name = '..' then FindNext(SR);
  if DosError = 18 then Exit;
  repeat
    if SR.Attr and Directory <> 0 then
    begin
      if D.Count >= 255 then
      begin
        Full := True;
        Exit;
      end;
      Inc(D.Count);
      GetMem(D.Entries[D.Count], SizeOf(TEntry));
      D.Entries[D.Count]^.Name := SR.Name;
      Inc(GDirs);
    end
    else
    begin
      Inc(GFiles);
      D.Size := D.Size + SR.Size;
    end;
    FindNext(SR);
  until (DosError = 18) or (DosError >= 100);
  if DosError >= 100 then
  begin
    Str(DosError, S);
    MsgBox('Es ist ein Fehler aufgetreten!', 'Dos-Fehler Nr.: ' + S);
    Full := True;
  end;
end;

procedure TTreeList.DrawLine(Line: Integer);
var
  S1, S2: string[4];
  W: Byte;
begin
  Str(Line + Top: 3, S1);
  Str(DirTab^[Line + Top]^.Subs: 4, S2);
  if (Line + Top <= Count) and (Line + Top > 0) then
    Text := ' ' + S1 + ' '#$B3 + SizeStr(DirTab^[Line + Top]^.Size) + ' '#$B3 + S2 + ' '#$B3' ' +
      Shorten(DirTab^[Line + Top]^.Path, 49)
  else
    Text := '     '#$B3'             '#$B3'     '#$B3;
  W := Width;
  if Scroll then Dec(W);
  MouseHide;
  if Line <= 0 then Line := 1;
  WriteXY(1, Line, Copy(Text + Spaces, 1, W));
  if Scroll then
    if not SingleFrame then WriteF(0, #$CE)
    else WriteF(0, ' ');
  MouseShow;
  LastRow := $FF;
end;

function ScanDirs(var Path: string; var Size: Longint; var Dirs, Files: Word): Boolean;
label
  Again;
var
  SR: SearchRec;
  D: PDirRec;
  Total, SubTotal: Longint;
  PPath: string[79];
  Unk: array[1..8] of Byte;
  I: Integer;
  B93, B94, B95, B96, B97, B98, B99, B9A: Byte;

  procedure ScanTree(var D: PDirRec; Path: string; var Total: Longint);
  var
    I: Word;
  begin
    GetKey(I);
    Idle;
    if I = 27 then Full := True;
    if (MaxAvail <= SizeOf(TDirRec)) or Full then
    begin
      Full := True;
      Exit;
    end;
    GetMem(D, SizeOf(TDirRec));
    D^.Path := Path + '\*.*';
    D^.Size := 0;
    D^.Count := 0;
    ReadDir(D^);
    AddDir(D^);
    Total := Total + D^.Size;
    for I := 1 to D^.Count do
      ScanTree(D^.Entries[I]^.Sub, Path + '\' + D^.Entries[I]^.Name, Total);
    for I := 1 to D^.Count do
      FreeMem(D^.Entries[I], SizeOf(TEntry));
    FreeMem(D, SizeOf(TDirRec));
  end;

  procedure SumTree(var D: PDirRec; Path: string; var Total: Longint);
  var
    I: Word;
  begin
    GetKey(I);
    if I = 27 then Full := True;
    if (MaxAvail <= SizeOf(TDirRec)) or Full then
    begin
      Full := True;
      Exit;
    end;
    GetMem(D, SizeOf(TDirRec));
    if Path[Length(Path)] <> '\' then Path := Path + '\';
    D^.Path := Path + '*.*';
    D^.Size := 0;
    D^.Count := 0;
    ReadDir(D^);
    Total := Total + D^.Size;
    for I := 1 to D^.Count do
      SumTree(D^.Entries[I]^.Sub, Path + D^.Entries[I]^.Name, Total);
    for I := 1 to D^.Count do
      FreeMem(D^.Entries[I], SizeOf(TEntry));
    FreeMem(D, SizeOf(TDirRec));
  end;

  procedure Header1;
  begin
    Frame(1, 1, 78, 1, 11, 3, 0, 0);
    SetColor(14, 3);
    WriteXY(4, 1, 'Nr.');
    WriteXY(13, 1, 'Bytes');
    WriteXY(23, 1, 'Subs');
    WriteXY(30, 1, '^Return = incl. Subs   Alt-F1=Laufwerk');
    Window(2, 5, 80, ScreenRows);
  end;

  procedure Header2;
  begin
    Frame(1, 1, 78, 1, 11, 3, 0, 0);
    SetColor(0, 3);
    WriteXY(3, 1, 'Nr.');
    WriteXY(12, 1, 'Bytes');
    WriteXY(22, 1, 'Subs');
    WriteXY(29, 1, '^Return = incl. Subs   Alt-F1=Laufwerk');
    Window(2, 5, 80, ScreenRows);
  end;

  procedure ShowTotals;
  begin
    Header2;
    Frame(1, 4, 78, ScreenRows - 6, 11, 1, 0, 0);
    TextColor(11);
    Window(1, 1, 80, ScreenRows);
    WriteXY(2, 4, Line78);
    GotoXY(1, ScreenRows);
    SetColor(0, 3);
    ClrEol;
    if Length(PPath) = 2 then PPath := PPath + '\';
    Write(' ', SizeStr(Total), ' Bytes in ', GDirs + 1, ' Verz. und ', GFiles, ' Dateien in ',
      Shorten(PPath, 28), '.');
    Window(2, 5, 80, ScreenRows);
  end;

  function Browse: Boolean;
  var
    A2, A3, U: Byte;
    Key: Word;
    List: TTreeList;

    function ChangeDrive(Mouse: Boolean): Boolean;
    var
      Cur: string[79];
      Drv: Char;
      W: TWinState;
      Y, X: Integer;
    begin
      SaveWin(W);
      ChangeDrive := False;
      if Mouse then
      begin
        MouseHide;
        Header1;
        MouseShow;
        G88A := 0;
        G842 := 14;
        WaitRelease;
        G842 := 0;
        MouseHide;
        Header2;
        MouseShow;
        G88A := 0;
        Idle;
      end;
      GetDir(0, Cur);
      Y := 7;
      if Mouse then Y := 2;
      X := 10;
      if Mouse then X := MouseX - 9;
      if X > 55 then X := 55;
      if X < 2 then X := 2;
      Drv := SelectDrive(X, Y, Cur[1]);
      if Drv <> ' ' then
      begin
        ChDir(Drv + ':');
        if IOResult = 0 then
        begin
          PPath := Drv + ':';
          ChangeDrive := True;
        end
        else if CfgColors[42] <> 0 then PlaySound(4);
      end;
      ChDir(Cur);
      RestoreWin(W);
      G88A := 0;
      Idle;
    end;

  begin
    MouseHide;
    A2 := TextAttr;
    B94 := G841;
    B93 := G840;
    G840 := $4A;
    G841 := 2;
    ShowTotals;
    G88A := 0;
    Browse := False;
    List.Init(11, 1, 0, 3, 2, 5, ScreenRows - 6, DirCount, 77, True);
    FillChar(MouseMap[1], 80, $17);
    FillChar(MouseMap[ScreenRows], 80, $17);
    FillChar(MouseMap[2, 2], 78, $11);
    MouseShow;
    repeat
      GetKey(Key);
      if MouseOn(1, 1, 80) then Key := $42F;
      if MouseOn(ScreenRows, 1, 80) then Key := $437;
      List.Handle(Key);
      if Key <> 0 then MouseMoved := 0;
      case Key of
        $423: ShowHelp(31);
        10:
          begin
            A3 := TextAttr;
            SubTotal := 0;
            TextColor(14);
            TextBackground(4);
            MouseHide;
            GotoXY(7, List.Cur);
            Writeln('  warten...  ');
            MouseShow;
            ArrowCursor;
            SumTree(D, DirTab^[List.Cur + List.Top]^.Path, SubTotal);
            NormalCursor;
            MouseHide;
            GotoXY(7, List.Cur);
            Writeln(SizeStr(SubTotal), ' ');
            TextAttr := A3;
            MouseShow;
          end;
        13:
          begin
            Path := DirTab^[List.Cur + List.Top]^.Path;
            Key := $42C;
          end;
        $450:
          if ChangeDrive(False) then
          begin
            Browse := True;
            Key := $42C;
          end;
      end;
      if MouseOn(2, 2, 78) then
        if ChangeDrive(True) then
        begin
          Browse := True;
          Key := $42C;
        end;
    until IsCancel(Key);
    TextAttr := A2;
    G841 := B94;
    G840 := B93;
    WaitRelease;
    List.Done;
  end;

begin
  Dirs := 0;
  Files := 0;
  ScanDirs := True;
  Stop := False;
  B95 := 11;
  B96 := 1;
  B98 := 0;
  B9A := 3;
  B99 := 0;
  GDirs := 0;
  GFiles := 0;
  Full := False;
  Total := 0;
  DirCount := 0;
  if Length(Path) = 0 then
    GetDir(0, PPath)
  else
  begin
    Stop := True;
    PPath := Path;
  end;
  DelBackslash(PPath);
  if MaxAvail < $4000 then Full := True;
  if not Stop then
  begin
    GetMem(DirTab, $4000);
    OpenDialog;
    MouseShow;
  Again:
    MouseHide;
    GDirs := 0;
    GFiles := 0;
    Full := False;
    Total := 0;
    DirCount := 0;
    Dirs := 0;
    Files := 0;
    Window(1, 1, 80, ScreenRows);
    SetColor(0, 1);
    ClrScr;
    G88A := 0;
    G870 := 0;
    GotoXY(1, 1);
    TextBackground(3);
    ClrEol;
    GotoXY(1, ScreenRows);
    ClrEol;
    Frame(13, 7, 54, 5, 11, 3, 0, 1);
    WriteCenterXY(1, 2, 54, 'Lese das Inhaltsverzeichnis!');
    WriteCenterXY(1, 4, 54, 'Bitte warten ...');
    MouseShow;
    Idle;
    ArrowCursor;
    ScanTree(D, PPath, Total);
    Path := '';
    NormalCursor;
    if Full then
      MsgBox(' Fehler: Zu wenig Speicher oder zu viele Verzeichnisse!', 'Max.: 4096 Verzeichnisse');
    if Browse then
    begin
      for I := 1 to DirCount do FreeMem(DirTab^[I], SizeOf(TDirInfo));
      goto Again;
    end;
    PopScreen(DlgStack);
    for I := 1 to DirCount do FreeMem(DirTab^[I], SizeOf(TDirInfo));
    FreeMem(DirTab, $4000);
  end
  else
  begin
    ArrowCursor;
    Size := 0;
    SumTree(D, Path, Size);
    NormalCursor;
    Path := '';
  end;
  Dirs := GDirs;
  Files := GFiles;
  ScanDirs := Full;
end;

procedure TSumList.DrawLine(Line: Integer);
var
  Dummy: string[11];
  N: Integer;
begin
  Text := '';
  if Line + Top <= SumCount then
  begin
    N := Line + Top;
    Text := ' ' + Sums^[N].Name + SizeStr(Sums^[N].Size) + LongStrW(Sums^[N].Dirs, 6) +
      LongStrW(Sums^[N].Files, 7);
  end;
  TList.DrawLine(Line);
end;

function DirSums(Dir: string; var List: TFileList; Count: Integer; var Sel: Integer): Boolean;
var
  I, Unk: Integer;
  Name, Tmp, Long: string;
  Size: Longint;
  Dirs, Files: Word;
  Key: Word;
  B3: TButton3;
  H2, H1, H3: Boolean;
  L: TSumList;
  Win: TWinState;
begin
  DirSums := False;
  GetMem(Sums, $CC00);
  if Sums = nil then
  begin
    ErrorBox('Zu wenig Hauptspeicher!', '');
    Exit;
  end;
  OpenDialog;
  Frame(5, 4, 70, ScreenRows - 7, 11, 6, 0, 1);
  WriteXYF(4, 1, 11, 'Verzeichnisse in diesem Fenster           Bytes Sub-Dirs Dateien');
  SumCount := 0;
  OpenFrame(7, 6, 66, ScreenRows - 13, 11, 6);
  L.Init(0, 3, 11, 1, 8, 7, ScreenRows - 13, SumCount, 65, True);
  InitButton3(False, 1, ScreenRows - 11, 24, ScreenRows - 11, 47, ScreenRows - 11, 14, 0, 11, 6,
    '    Gehe nach    ', '     Details     ', '     Abbruch    ', B3);
  SaveWin(Win);
  Frame(20, 9, 40, 3, 15, 5, 0, 1);
  WriteCenterXY(1, 2, 40, 'Moment noch...');
  RestoreWin(Win);
  MouseShow;
  for I := 1 to Count do
    if List[I]^.Attr and $10 <> 0 then
      if List[I]^.Name[1] <> '.' then
      begin
        Name := List[I]^.Name;
        Name[9] := '.';
        Name := CompressName(Name);
        Name := JoinPath(Dir, Name);
        Tmp := Name;
        ScanDirs(Tmp, Size, Dirs, Files);
        Long := Name;
        if CfgColors[56] <> 0 then GetLongName(Name, Long, True);
        Inc(SumCount);
        Sums^[SumCount].Name := PadRight(Shorten(Long, 36), 36);
        Sums^[SumCount].Size := Size;
        Sums^[SumCount].Dirs := Dirs;
        Sums^[SumCount].Files := Files;
        Sums^[SumCount].Index := I;
      end;
  L.SetData(SumCount, ScreenRows - 13, 1, 0);
  SaveWin(Win);
  Str(SumCount, Name);
  MouseHide;
  if SumCount = 0 then
  else if SumCount > 1 then
      WriteXYFB(9, 5, 11, 6, Name + ' Verzeichnisse in diesem Fenster')
    else
      WriteXYFB(9, 5, 11, 6, Name + ' Verzeichnis in diesem Fenster');
  MouseShow;
  RestoreWin(Win);
  repeat
    HandleButton3(H1, H2, H3, Key, B3);
    if Key = $423 then ShowHelp(31);
    Sel := L.Handle(Key);
    if IsCancel(Key) or MouseOutside(5, 76, 4, ScreenRows - 7 + 4 + 1) then H3 := True;
  until H1 or H2 or H3;
  CloseDialog;
  L.Done;
  Sel := Sums^[Sel].Index;
  FreeMem(Sums, $CC00);
  if H3 then
  begin
    Sel := 0;
    DirSums := True;
  end;
  if H2 then Sel := 0;
end;

end.
