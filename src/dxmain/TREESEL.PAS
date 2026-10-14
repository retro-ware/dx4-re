{$O+,F+,G+,S-,I-,X+,V-}
unit TreeSel;
{ Overlay 1146: directory tree browser (dx?tree.dat): select a directory from the tree, incremental
  search, F5/F6/F7 buttons, Alt-F1 drive change, Ctrl-Return directory sizes }

interface

uses Dialogs;

function SelectTree(Path: Str128; var Found: Boolean; Rebuild: Boolean): string;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Status, ScrSave, Lists, Help, Sounds, DirTree;

const
  Stop: Boolean = False;

type
  PTreeEntry = ^TTreeEntry;
  TTreeEntry = record
    Name: string[100];
    Level: Byte;
    Size: Longint;
  end;
  PTreeTab = ^TTreeTab;
  TTreeTab = array[1..4096] of PTreeEntry;
  TTreeRec = record
    Count, Level: Byte;
    Name: Str12;
    Size: Longint;
  end;
  PScan = ^TScan;
  PSub = ^TSub;
  TSub = record
    Name: Str12;
    Sub: PScan;
  end;
  TScan = record
    Path: string[128];
    Subs: array[1..255] of PSub;
    Count: Byte;
  end;
  Str9 = string[9];
  Str80 = string[80];

  TTreeLst = object(TList)
    procedure DrawLine(Line: Integer); virtual;
    procedure ShowCur(Line: Integer); virtual;
  end;
  TPathLst = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

const
  Blank =
    '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';

var
  Count: Integer;
  Tree: PTreeTab;
  F: file of TTreeRec;
  CurPath: string[128];
  CurIndex: Integer;
  FName: Str12;

function TreeName(N: Integer; var Len: Byte): Str12;
var
  I: Byte;
  S: string[100];
begin
  S := Tree^[N]^.Name;
  I := 0;
  repeat
    Inc(I);
  until (I = 100) or ((S[I] > ' ') and (S[I] < #$A0));
  TreeName := Copy(S, I, Length(S) - I + 1);
  Len := I + 1;
end;

function FullPath(N: Integer): string;
var
  I, Lvl: Integer;
  S, T: string;
  Len: Byte;
begin
  S := TreeName(N, Len);
  Lvl := Tree^[N]^.Level;
  for I := N downto 1 do
    if Tree^[I]^.Level < Lvl then
    begin
      T := TreeName(I, Len);
      if I <> 1 then T := T + '\';
      Insert(T, S, 1);
      Lvl := Tree^[I]^.Level;
    end;
  FullPath := S;
end;

procedure TTreeLst.DrawLine(Line: Integer);
var
  L: Longint;
  B: Byte;
  S: Str12;
  Len: Byte;
  D: Byte;
begin
  MouseHide;
  LastRow := $FF;
  if Line + Top <= Count then
  begin
    S := SizeStr(Tree^[Line + Top]^.Size);
    WriteXY(1, Line, ' ' + S + Copy(Tree^[Line + Top]^.Name + Blank, 1, 63));
    if not ThinButtons then WriteF(0, #$CE);
    if (Line + Top = CurIndex) and (Cur <> Line) then
    begin
      S := TreeName(Line + Top, Len);
      if Len + Length(S) + 12 < 72 then WriteXYFB(Len + 12, Line, 14, 3, S);
    end;
  end
  else
  begin
    WriteXY(1, Line, ' ' + Copy(Blank, 1, 75));
    if not ThinButtons then WriteF(0, #$CE);
  end;
  MouseShow;
end;

procedure TTreeLst.ShowCur(Line: Integer);
var
  S: Str12;
  B: Byte;
  A: Byte;
  Key: Word;
  W: TWinState;
begin
  A := TextAttr;
  SetColor(SelFg, SelBg);
  TTreeLst.DrawLine(Line);
  TextAttr := A;
  CurPath := FullPath(Line + Top);
  MouseHide;
  SaveWin(W);
  if Line + Top <> CurIndex then WriteCenterXY(2, 2, 78, CurPath)
  else WriteCenterXYFB(2, 2, 78, 14, Bg, CurPath);
  RestoreWin(W);
  MouseShow;
  GetKey(Key);
end;

procedure TPathLst.DrawLine(Line: Integer);
begin
  if Line + Top <= Count then Text := ' ' + Shorten(FullPath(Line + Top), Width - 1)
  else Text := '';
  TList.DrawLine(Line);
end;

function CountBS(S: string): Byte;
var
  I, N: Byte;
begin
  N := 0;
  for I := 1 to Length(S) do
    if S[I] = '\' then Inc(N);
  CountBS := N;
end;

function LastDir(S: string): Str12;
var
  I: Byte;
  R: Str12;
begin
  R := '';
  I := Length(S);
  if I <= 3 then LastDir := S
  else
  begin
    repeat Dec(I) until (S[I] = '\') or (I = 0);
    repeat Dec(I) until (S[I] = '\') or (I = 0);
    repeat
      Inc(I);
      R := R + S[I];
    until (S[I + 1] = '\') or (I = 255);
    LastDir := R;
  end;
end;

procedure ScanDir(Path: string; var D: TScan);
var
  SR: SearchRec;
  Rec: TTreeRec;
  Total: Longint;
begin
  if Stop then Exit;
  Total := 0;
  D.Path := Path;
  D.Count := 0;
  FindFirst(D.Path, $37, SR);
  if SR.Attr and 8 <> 0 then FindNext(SR);
  if SR.Name = '.' then FindNext(SR);
  if SR.Name = '..' then FindNext(SR);
  if DosError <> 18 then
  begin
    if SR.Attr and 8 <> 0 then FindNext(SR);
    repeat
      if SR.Attr and $10 <> 0 then
      begin
        if D.Count >= 255 then
        begin
          Stop := True;
          Exit;
        end;
        Inc(D.Count);
        GetMem(D.Subs[D.Count], 17);
        D.Subs[D.Count]^.Name := SR.Name;
      end
      else Total := Total + SR.Size;
      FindNext(SR);
      if (DosError <> 18) and ((SR.Attr = $28) or (SR.Attr = 8)) then FindNext(SR);
    until DosError = 18;
  end;
  Inc(Count);
  Rec.Name := LastDir(D.Path);
  Rec.Count := D.Count;
  Rec.Level := CountBS(D.Path);
  Rec.Size := Total;
  Write(F, Rec);
  if IOResult <> 0 then Stop := True;
  MouseHide;
  WriteCenterXY(1, 4, 54, Rec.Name);
  MouseShow;
end;

function SelectTree(Path: Str128; var Found: Boolean; Rebuild: Boolean): string;
var
  SR: SearchRec;
  Root: PScan;
  Path2: string;
  Drive: Char;
  W: TWinState;
  SaveAttr: Word;
  I: Integer;
  Last: Str12;
  Ok: Boolean;

function LoadTree(FName: Str12): Boolean; forward;
function BuildTree(Path: string): Boolean; forward;

procedure Recurse(var P: PScan; Path: string);
var
  I: Integer;
  Key: Word;
begin
  if (MaxAvail < 1150) or Stop then
  begin
    Stop := True;
    Exit;
  end;
  GetKey(Key);
  if Key = 27 then
  begin
    Stop := True;
    Exit;
  end;
  GetMem(P, 1150);
  ScanDir(Path + '\*.*', P^);
  for I := 1 to P^.Count do
    Recurse(P^.Subs[I]^.Sub, Path + '\' + P^.Subs[I]^.Name);
  for I := 1 to P^.Count do FreeMem(P^.Subs[I], 17);
  FreeMem(P, 1150);
end;

function Browse: string;
var
  I: Integer;
  Key: Word;
  L: TTreeLst;
  Dummy: Boolean;
  Search: Str12;
  Drv: Char;
  Dir: string;
  SR: SearchRec;
  W: TWinState;
  SaveB: Byte;
  SaveMap: TMouseMap;
  Size: Longint;
  Dirs, Files: Word;

function Find(Next: Boolean; S: Str12): Boolean;
var
  I, J: Integer;
  Len: Byte;
  T: Str12;
  Hit: Boolean;
begin
  Find := False;
  if Next then
  begin
    I := L.Cur + L.Top;
    if I >= Count then Exit;
  end
  else I := 0;
  repeat
    Inc(I);
    T := TreeName(I, Len);
    Hit := Copy(T, 1, Length(S)) = S;
  until (I >= Count) or Hit;
  if Hit then
  begin
    J := 0;
    while (I > 12) and (L.Rows + J < Count) do
    begin
      Inc(J);
      Dec(I);
    end;
    L.SetData(Count, ScreenRows - 6, I, J);
  end
  else if Next then ErrorBox('Verzeichnis nicht mehr gefunden!', S);
  Find := Hit;
end;

procedure ShowSearch;
var
  W: TWinState;
begin
  MouseHide;
  SaveWin(W);
  WriteXYFB(13, ScreenRows, 0, 2, Copy(Search + Blank, 1, 12));
  RestoreWin(W);
  MouseShow;
end;

procedure KeyChar;
var
  Len: Byte;
  Unused: array[1..6] of Byte;
begin
  Len := Length(Search);
  if (Len = 12) and (Key <> 8) then Exit;
  if (Key = 8) and (Len > 0) then Delete(Search, Length(Search), 1);
  if Key <> 8 then Search := Search + Chr(UpCaseW(Key));
  if Find(False, Search) then ShowSearch
  else Delete(Search, Length(Search), 1);
end;

function HotButton(Cap: Str9; X1, X2: Byte): Boolean;
begin
  HotButton := False;
  MouseHide;
  WriteXYFB(X1, ScreenRows, 14, 3, ' ' + Cap);
  MouseShow;
  repeat
  until (MouseButton = 0) or (ScreenRows <> MouseY) or (X1 > MouseX) or (X2 < MouseX);
  if (ScreenRows = MouseY) and (X1 <= MouseX) and (X2 >= MouseX) then HotButton := True;
  MouseHide;
  WriteXYFB(X1, ScreenRows, 0, 3, Cap + ' ');
  MouseShow;
end;

function PickPath: Str128;
var
  L2: TPathLst;
  Key: Word;
  Dummy: string;
  Rows: Byte;
begin
  OpenDialog;
  PickPath := '';
  Rows := ScreenRows - 8;
  OpenFrame(2, 5, 75, Rows, 0, 3);
  L2.Init(0, 5, 0, 2, 3, 6, Rows, Count, 74, True);
  L2.SetPos(L.Cur + L.Top, 9);
  MouseShow;
  WaitRelease;
  repeat
    GetKey(Key);
    L2.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(3, 78, 5, Rows + 6);
  PopScreen(DlgStack);
  if Key = 13 then
  begin
    Delete(L2.Text, 1, 1);
    PickPath := L2.Text;
  end;
  L2.Done;
  WaitRelease;
end;

begin
  MouseHide;
  Browse := '';
  Dummy := False;
  Search := '';
  CurIndex := 0;
  SaveB := CfgB809;
  CfgB809 := 3;
  RestoreBorder;
  ClockOff;
  if Length(Path2) = 2 then Path2 := Path2 + '\';
  Frame(1, 1, 78, 1, 11, 3, 0, 0);
  Frame(1, 4, 78, ScreenRows - 6, 11, 3, 0, 0);
  Window(1, 1, 80, ScreenRows);
  GotoXY(1, ScreenRows);
  ClrEol;
  WriteXY(5, ScreenRows, 'Suche: ');
  InputLine(12, ScreenRows, 0, 0, Search, 12, 0, #198, False);
  WriteXY(30, ScreenRows, 'F5 N'#$84'chstes F6 Aktuelles F7 Neu Alt-F1 Laufwerk');
  WriteXYF(30, ScreenRows, 4, 'F5');
  WriteXYF(42, ScreenRows, 4, 'F6');
  WriteXYF(55, ScreenRows, 4, 'F7');
  WriteXYF(62, ScreenRows, 4, 'Alt-F1');
  DrawDownArrow(26, ScreenRows);
  L.Init(0, 3, 0, 2, 2, 5, ScreenRows - 6, Count, 77, True);
  MouseShow;
  SaveMap := MouseMap;
  Search := Last;
  Ok := Find(False, Search);
  while Ok and (CurPath <> Path) do Ok := Find(True, Search);
  if Ok then CurIndex := L.Cur + L.Top;
  Search := '';
  L.ShowCur(L.Cur);
  WaitRelease;
  L.Handle(Key);
  repeat
    ShowCursor;
    SaveWin(W);
    GotoXY(Length(Search) + 13, ScreenRows);
    repeat
      GetKey(Key);
    until (Key <> 0) or (MouseButton <> 0);
    RestoreWin(W);
    HideCursor;
    if MouseOn(ScreenRows, 27, 27) or ((Key = $438) and ShiftDown) then
    begin
      Dir := PickPath;
      if Dir <> '' then
      begin
        CurPath := Dir;
        Key := 13;
      end
      else Key := 0;
    end;
    L.Handle(Key);
    if (MouseButton = 1) and (ScreenRows = MouseY) and (MouseX >= 33) and (MouseX <= 77) then
    begin
      SaveWin(W);
      case MouseX of
        33..40: if HotButton('N'#$84'chstes', 33, 41) then Key := $427;
        45..53: if HotButton('Aktuelles', 45, 54) then Key := $428;
        58..60: if HotButton('Neu', 58, 61) then Key := $429;
        69..76: if HotButton('Laufwerk', 69, 77) then Key := $450;
      end;
      RestoreWin(W);
    end;
    case Key of
      0: Idle;
      $423: ShowHelp(27);
      13: Browse := CurPath;
      10:
        begin
          SaveAttr := TextAttr;
          Size := 0;
          SetColor(14, 4);
          MouseHide;
          GotoXY(2, L.Cur);
{$I+}
          Writeln('  warten...  ');
{$I-}
          MouseShow;
          ArrowCursor;
          ScanDirs(CurPath, Size, Dirs, Files);
          NormalCursor;
          MouseHide;
          GotoXY(2, L.Cur);
{$I+}
          Writeln(SizeStr(Size), ' ');
{$I-}
          TextAttr := SaveAttr;
          MouseShow;
        end;
      14, $427: Find(True, Search);
      1, $428:
        begin
          Search := Last;
          Ok := Find(False, Search);
          while Ok and (CurPath <> Path) do Ok := Find(True, Search);
          Search := '';
        end;
      12, $429:
        begin
          for I := 1 to Count do FreeMem(Tree^[I], 106);
          BuildTree(Path2);
          LoadTree(FName);
          CurIndex := 0;
          L.SetData(Count, ScreenRows - 6, 1, 0);
          Search := Last;
          Ok := Find(False, Search);
          while Ok and (CurPath <> Path) do Ok := Find(True, Search);
          if Ok then CurIndex := L.Cur + L.Top;
          Search := '';
          ShowSearch;
        end;
      $450:
        begin
          Drv := SelectDrive(20, 10, Path2[1]);
          MouseMap := SaveMap;
          MouseTextCursor;
          if Drv <> ' ' then
          begin
            GetDir(0, Dir);
            Drv := UpCaseC(Drv);
            if Length(Dir) > 3 then DelBackslash(Dir);
            ChDir(Drv + ':');
            FindFirst('*.*', $3F, SR);
            if (IOResult <> 0) or ((DosError <> 0) and (DosError <> 18)) then
            begin
              if CfgColors[42] <> 0 then PlaySound(4);
              ChDir(Dir);
              if IOResult <> 0 then ;
            end
            else
            begin
              for I := 1 to Count do FreeMem(Tree^[I], 106);
              Path2 := Drv + ':\';
              GetDir(0, Path);
              if Length(Path) <> 3 then Last := LastDir(Path + '\d') else Last := Path;
              ChDir(Dir);
              if IOResult <> 0 then ;
              FName := 'dx' + Path2[1] + 'tree.dat';
              if not LoadTree(FName) then
              begin
                BuildTree(Path2);
                LoadTree(FName);
              end;
              CurIndex := 0;
              L.SetData(Count, ScreenRows - 6, 1, 0);
              Search := Last;
              Ok := Find(False, Search);
              while Ok and (CurPath <> Path) do Ok := Find(True, Search);
              if Ok then CurIndex := L.Cur + L.Top;
              Search := '';
              ShowSearch;
            end;
          end;
        end;
      33..154, 8: KeyChar;
    else
      if Search <> '' then
      begin
        Search := '';
        ShowSearch;
      end;
    end;
  until (Key = 27) or (MouseButton = 2) or (Key = 13) or (Key = $42C);
  CfgB809 := SaveB;
  RestoreBorder;
  ClockOn;
end;

procedure ReadBranch(Last: Boolean; Prefix: string);
var
  I, N: Integer;
  IsLast: Boolean;
  Conn: string[3];
  Rec: TTreeRec;
begin
  IsLast := False;
  if MemAvail < 16384 then Exit;
{$I+}
  if not Eof(F) then
{$I-}
  begin
    Read(F, Rec);
    if IOResult <> 0 then Exit;
    if Last then Conn := #$C0#$C4 else Conn := #$C3#$C4;
    Inc(Count);
    GetMem(Tree^[Count], 106);
    Tree^[Count]^.Name := Copy(Prefix, 1, Length(Prefix) - 1) + Conn + Rec.Name;
    Tree^[Count]^.Level := Rec.Level;
    Tree^[Count]^.Size := Rec.Size;
  end
  else
  begin
    InOutRes := 0;
    Exit;
  end;
  N := Rec.Count;
  for I := 1 to N do
  begin
    if I = N then
    begin
      IsLast := True;
      Conn := '   ';
    end
    else Conn := '  '#$B3;
    ReadBranch(IsLast, Prefix + Conn);
  end;
end;

function LoadTree;
var
  Rec: TTreeRec;
  IsLast: Boolean;
  I: Integer;
  Conn: string[3];
begin
  LoadTree := False;
  Assign(F, HomeDir + FName);
  Reset(F);
  if IOResult <> 0 then Exit;
  Read(F, Rec);
  if IOResult <> 0 then
  begin
    Close(F);
    InOutRes := 0;
    Exit;
  end;
  if not ((Rec.Count = 255) and (Rec.Level = 255) and (Rec.Name = 'DX4') and (Rec.Size = 255)) then
  begin
    Close(F);
    InOutRes := 0;
    Exit;
  end;
  Read(F, Rec);
  if IOResult <> 0 then
  begin
    Close(F);
    InOutRes := 0;
    Exit;
  end;
  GetMem(Tree^[1], 106);
  IsLast := False;
  Tree^[1]^.Name := ' ' + Rec.Name + '\';
  Tree^[1]^.Level := Rec.Level;
  Tree^[1]^.Size := Rec.Size;
  Count := 1;
  for I := 1 to Rec.Count do
  begin
    if Rec.Count = I then
    begin
      IsLast := True;
      Conn := '   ';
    end
    else Conn := '  '#$B3;
    ReadBranch(IsLast, Conn);
  end;
  Close(F);
  InOutRes := 0;
  LoadTree := True;
end;

function BuildTree;
var
  Rec: TTreeRec;
  Dummy: array[1..8] of Byte;
begin
  OpenDialog;
  Found := True;
  BuildTree := True;
  FName := 'dx' + Path[1] + 'tree.dat';
  Assign(F, HomeDir + FName);
  Rec.Count := 255;
  Rec.Level := 255;
  Rec.Name := 'DX4';
  Rec.Size := 255;
  Rewrite(F);
  Write(F, Rec);
  if IOResult <> 0 then
  begin
    PopScreen(DlgStack);
    BuildTree := False;
    Exit;
  end;
  Stop := False;
  Path := Copy(Path, 1, 2);
  Frame(13, 7, 54, 5, 15, 5, 0, 1);
  WriteCenterXY(1, 2, 54, 'Lese das Inhaltsverzeichnis!');
  MouseShow;
  ArrowCursor;
  Recurse(Root, Path);
  Close(F);
  if IOResult <> 0 then ;
  PopScreen(DlgStack);
  NormalCursor;
  if Stop then
    MsgBox('Zu wenig Speicher oder zu viele Dateien und', 'Verzeichnisse oder Abbruch durch Esc!');
end;

procedure RebuildTree(Path: Str80);
var
  I: Integer;
  T: Str12;
  Len: Byte;
  Match: Boolean;
begin
  SelectTree := '';
  Found := False;
  Path := UpperStr(Path);
  GetDir(0, Path2);
  FName := 'dx' + Path2[1] + 'tree.dat';
  if MaxAvail < 21384 then
  begin
    MsgBox('Zu wenig Speicher!', '');
    PopScreen(DlgStack);
    Exit;
  end;
  GetMem(Tree, 16384);
  Count := 0;
  if not LoadTree(FName) then
  begin
    if not BuildTree(Path2) then
    begin
        MsgBox('Konnte die Datei nicht erzeugen!', HomeDir + FName);
        FreeMem(Tree, 16384);
        PopScreen(DlgStack);
        Exit;
    end;
    LoadTree(FName);
  end;
  I := 0;
  repeat
    Inc(I);
    T := TreeName(I, Len);
    Match := Copy(T, 1, Length(Path)) = Path;
  until (I >= Count) or Match;
  if Match then SelectTree := FullPath(I) else SelectTree := '';
  for I := 1 to Count do FreeMem(Tree^[I], 106);
  FreeMem(Tree, 16384);
end;

begin
  if Rebuild then RebuildTree(Path)
  else
  begin
    OpenDialog;
    MouseShow;
    ArrowCursor;
    SelectTree := '';
    Found := False;
    if Length(Path) <> 3 then Last := LastDir(Path + '\d') else Last := Path;
    FName := 'dx' + Path[1] + 'tree.dat';
    if MaxAvail < 21384 then
    begin
      MsgBox('Zu wenig Speicher!', '');
      PopScreen(DlgStack);
      Exit;
    end;
    GetMem(Tree, 16384);
    Count := 0;
    Path2 := Path;
    if Path2 = '' then GetDir(0, Path2);
    if not LoadTree(FName) then
    begin
      if not BuildTree(Path2) then
      begin
          MsgBox('Konnte die Datei nicht erzeugen!', HomeDir + FName);
          FreeMem(Tree, 16384);
          PopScreen(DlgStack);
          Exit;
      end;
      LoadTree(FName);
    end;
    NormalCursor;
    SelectTree := Browse;
    PopScreen(DlgStack);
    for I := 1 to Count do FreeMem(Tree^[I], 106);
    FreeMem(Tree, 16384);
    WaitRelease;
  end;
end;

end.
