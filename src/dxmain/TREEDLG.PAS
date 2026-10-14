{$O+,F+,G+,S-,I-,X+,V-}
unit TreeDlg;
{ Directory tree dialog: reads/creates the tree file dx?tree.dat, shows the tree, search, drive change }

interface

type
  Str128 = string[128];

function DirTreeDialog(Path: Str128; var Flag: Byte; Quick: Boolean): string;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, Lists, Sounds, Fonts, DirTree;

const
  Sp255 = '                                                                                                    ' +
    '                                                                                                    ' +
    '                                                       ';
  Abort: Boolean = False;

type
  Str12 = string[12];
  Str80 = string[80];
  Str9 = string[9];
  TNode = record
    Line: string[100];
    Level: Byte;
    Size: Longint;
  end;
  PNode = ^TNode;
  TNodes = array[1..4096] of PNode;
  TTreeRec = record
    Count, Depth: Byte;
    Name: string[12];
    Size: Longint;
  end;
  PDirScan = ^TDirScan;
  PSubDir = ^TSubDir;
  TSubDir = record
    Name: string[12];
    Child: PDirScan;
  end;
  TDirScan = record
    Path: string[128];
    Subs: array[1..255] of PSubDir;
    Count: Byte;
  end;

  TTreeList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
    procedure ShowCur(Line: Integer); virtual;
  end;

  TPathList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

var
  DirCount: Integer;
  Tree: ^TNodes;
  TreeF: file of TTreeRec;
  CurPath: string[128];
  CurIdx: Integer;
  TreeName: string[12];

function NodeName(N: Integer; var P: Byte): Str12;
var
  I: Byte;
  S: string[100];
begin
  S := Tree^[N]^.Line;
  I := 0;
  repeat
    Inc(I);
  until (I = 100) or ((S[I] > ' ') and (S[I] < #$A0));
  NodeName := Copy(S, I, Length(S) - I + 1);
  P := I + 1;
end;

function FullPath(N: Integer): string;
var
  I, Lev: Integer;
  S, T: string;
  P: Byte;
begin
  S := NodeName(N, P);
  Lev := Tree^[N]^.Level;
  for I := N downto 1 do
    if Tree^[I]^.Level < Lev then
    begin
      T := NodeName(I, P);
      if I <> 1 then T := T + '\';
      Insert(T, S, 1);
      Lev := Tree^[I]^.Level;
    end;
  FullPath := S;
end;

procedure TTreeList.DrawLine(Line: Integer);
var
  B1, B2, B3, B4, B5: Byte;
  SizeS: string[12];
  P: Byte;
begin
  MouseHide;
  LastRow := $FF;
  if Line + Top <= Count then
  begin
    SizeS := SizeStr(Tree^[Line + Top]^.Size);
    WriteXY(1, Line, ' ' + SizeS + Copy(Tree^[Line + Top]^.Line + Sp255, 1, 63));
    if not CustomFont then WriteF(0, #$CE);
    if (Line + Top = CurIdx) and (Cur <> Line) then
    begin
      SizeS := NodeName(Line + Top, P);
      if P + Length(SizeS) + 12 < 72 then WriteXYFB(P + 12, Line, 14, 3, SizeS);
    end;
  end
  else
  begin
    WriteXY(1, Line, ' ' + Copy(Sp255, 1, 75));
    if not CustomFont then WriteF(0, #$CE);
  end;
  MouseShow;
end;

procedure TTreeList.ShowCur(Line: Integer);
var
  Fill: array[1..14] of Byte;
  X1: Byte;
  A: Byte;
  Key: Word;
  W: TWinState;
begin
  A := TextAttr;
  SetColor(SelFg, SelBg);
  TTreeList.DrawLine(Line);
  TextAttr := A;
  CurPath := FullPath(Line + Top);
  MouseHide;
  SaveWin(W);
  if Line + Top <> CurIdx then
    WriteCenterXY(2, 2, 78, CurPath)
  else
    WriteCenterXYFB(2, 2, 78, 14, Bg, CurPath);
  RestoreWin(W);
  MouseShow;
  GetKey(Key);
end;

procedure TPathList.DrawLine(Line: Integer);
begin
  if Line + Top <= Count then
    Text := ' ' + Shorten(FullPath(Line + Top), Width - 1)
  else
    Text := '';
  TList.DrawLine(Line);
end;

function CountSlash(S: string): Byte;
var
  I, N: Byte;
begin
  N := 0;
  for I := 1 to Length(S) do
    if S[I] = '\' then Inc(N);
  CountSlash := N;
end;

function LastDir(S: string): Str12;
var
  I: Byte;
  R: string[12];
begin
  R := '';
  I := Length(S);
  if I <= 3 then
    LastDir := S
  else
  begin
    repeat
      Dec(I);
    until (S[I] = '\') or (I = 0);
    repeat
      Dec(I);
    until (S[I] = '\') or (I = 0);
    repeat
      Inc(I);
      R := R + S[I];
    until (S[I + 1] = '\') or (I = 255);
    LastDir := R;
  end;
end;

procedure ReadDir(Path: string; var D: TDirScan);
var
  SR: SearchRec;
  Rec: TTreeRec;
  Total: Longint;
begin
  if Abort then Exit;
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
          Abort := True;
          Exit;
        end;
        Inc(D.Count);
        GetMem(D.Subs[D.Count], SizeOf(TSubDir));
        D.Subs[D.Count]^.Name := SR.Name;
      end
      else
        Total := Total + SR.Size;
      FindNext(SR);
      if DosError <> 18 then
        if (SR.Attr = $28) or (SR.Attr = 8) then FindNext(SR);
    until DosError = 18;
  end;
  Inc(DirCount);
  Rec.Name := LastDir(D.Path);
  Rec.Count := D.Count;
  Rec.Depth := CountSlash(D.Path);
  Rec.Size := Total;
  Write(TreeF, Rec);
  if IOResult <> 0 then Abort := True;
  MouseHide;
  WriteCenterXY(1, 4, 54, Rec.Name);
  MouseShow;
end;

function DirTreeDialog(Path: Str128; var Flag: Byte; Quick: Boolean): string;
var
  Fill1: string[43];
  Root: PDirScan;
  Dir: string;
  Fill2: string[7];
  Fill3: Byte;
  Attr: Word;
  I: Integer;
  CurName: string[12];
  Found: Boolean;

  function LoadTree(Name: Str12): Boolean; forward;
  function CreateTree(Dir: string): Boolean; forward;

  procedure ScanDir(var D: PDirScan; Path: string);
  var
    I: Integer;
    Key: Word;
  begin
    if (MaxAvail <= SizeOf(TDirScan)) or Abort then
    begin
      Abort := True;
      Exit;
    end;
    GetKey(Key);
    if Key = 27 then
    begin
      Abort := True;
      Exit;
    end;
    GetMem(D, SizeOf(TDirScan));
    ReadDir(Path + '\*.*', D^);
    for I := 1 to D^.Count do
      ScanDir(D^.Subs[I]^.Child, Path + '\' + D^.Subs[I]^.Name);
    for I := 1 to D^.Count do
      FreeMem(D^.Subs[I], SizeOf(TSubDir));
    FreeMem(D, SizeOf(TDirScan));
  end;

  function TreeBrowser: string;
  var
    I: Integer;
    Key: Word;
    List: TTreeList;
    X929: Byte;
    SearchS: string[12];
    Drive: Char;
    S: string;
    SR: SearchRec;
    W: TWinState;
    OldBorder: Byte;
    SaveMap: TMouseMap;
    Total: Longint;
    Dirs, Files: Word;

    function FindEntry(Next: Boolean; Name: Str12): Boolean;
    var
      I, J: Integer;
      P: Byte;
      N: string[12];
      Found: Boolean;
    begin
      FindEntry := False;
      if Next then
      begin
        I := List.Cur + List.Top;
        if I >= DirCount then Exit;
      end
      else
        I := 0;
      repeat
        Inc(I);
        N := NodeName(I, P);
        Found := Copy(N, 1, Length(Name)) = Name;
      until (I >= DirCount) or Found;
      if Found then
      begin
        J := 0;
        while (I > 12) and (List.Rows + J < DirCount) do
        begin
          Inc(J);
          Dec(I);
        end;
        List.SetData(DirCount, ScreenRows - 6, I, J);
      end
      else if Next then
        ErrorBox('Verzeichnis nicht mehr gefunden!', Name);
      FindEntry := Found;
    end;

    procedure ShowSearch;
    var
      W: TWinState;
    begin
      MouseHide;
      SaveWin(W);
      WriteXYFB(13, ScreenRows, 0, 2, Copy(SearchS + Sp255, 1, 12));
      RestoreWin(W);
      MouseShow;
    end;

    procedure SearchKey;
    var
      L: Byte;
      W: TWinState;
    begin
      L := Length(SearchS);
      if (L = 12) and (Key <> 8) then Exit;
      if (Key = 8) and (L > 0) then Delete(SearchS, Length(SearchS), 1);
      if Key <> 8 then SearchS := SearchS + Chr(UpCaseW(Key));
      if FindEntry(False, SearchS) then
        ShowSearch
      else
        Delete(SearchS, Length(SearchS), 1);
    end;

    function HotButton(S: Str9; X1, X2: Byte): Boolean;
    begin
      HotButton := False;
      MouseHide;
      WriteXYFB(X1, ScreenRows, 14, 3, ' ' + S);
      MouseShow;
      repeat until (MouseButton = 0) or (ScreenRows <> MouseY) or (X1 > MouseX) or (X2 < MouseX);
      if (ScreenRows = MouseY) and (X1 <= MouseX) and (X2 >= MouseX) then HotButton := True;
      MouseHide;
      WriteXYFB(X1, ScreenRows, 0, 3, S + ' ');
      MouseShow;
    end;

    function PathDialog: Str128;
    var
      L: TPathList;
      Key: Word;
      S: string;
      Y: Byte;
    begin
      OpenDialog;
      PathDialog := '';
      Y := ScreenRows - 8;
      OpenFrame(2, 5, 75, Y, 0, 3);
      L.Init(0, 5, 0, 2, 3, 6, Y, DirCount, 74, True);
      L.SetPos(List.Cur + List.Top, 9);
      MouseShow;
      WaitRelease;
      repeat
        GetKey(Key);
        L.Handle(Key);
      until IsCancel(Key) or (Key = 13) or MouseOutside(3, 78, 5, Y + 6);
      PopScreen(DlgStack);
      if Key = 13 then
      begin
        Delete(L.Text, 1, 1);
        PathDialog := L.Text;
      end;
      L.Done;
      WaitRelease;
    end;

  begin
    MouseHide;
    TreeBrowser := '';
    X929 := 0;
    SearchS := '';
    CurIdx := 0;
    OldBorder := BorderColor;
    BorderColor := 3;
    RestoreBorder;
    ClockOff;
    if Length(Dir) = 2 then Dir := Dir + '\';
    Frame(1, 1, 78, 1, 11, 3, 0, 0);
    Frame(1, 4, 78, ScreenRows - 6, 11, 3, 0, 0);
    Window(1, 1, 80, ScreenRows);
    GotoXY(1, ScreenRows);
    ClrEol;
    WriteXY(5, ScreenRows, 'Suche: ');
    InputLine(12, ScreenRows, 0, 0, SearchS, 12, 0, #$C6, False);
    WriteXY(30, ScreenRows, 'F5 N'#$84'chstes F6 Aktuelles F7 Neu Alt-F1 Laufwerk');
    WriteXYF(30, ScreenRows, 4, 'F5');
    WriteXYF(42, ScreenRows, 4, 'F6');
    WriteXYF(55, ScreenRows, 4, 'F7');
    WriteXYF(62, ScreenRows, 4, 'Alt-F1');
    DrawDownArrow(26, ScreenRows);
    List.Init(0, 3, 0, 2, 2, 5, ScreenRows - 6, DirCount, 77, True);
    MouseShow;
    SaveMap := MouseMap;
    SearchS := CurName;
    Found := FindEntry(False, SearchS);
    while Found and (CurPath <> Path) do Found := FindEntry(True, SearchS);
    if Found then CurIdx := List.Cur + List.Top;
    SearchS := '';
    List.ShowCur(List.Cur);
    WaitRelease;
    repeat
      List.Handle(Key);
      ShowCursor;
      SaveWin(W);
      GotoXY(Length(SearchS) + 13, ScreenRows);
      repeat
        GetKey(Key);
      until (Key <> 0) or (MouseButton <> 0);
      RestoreWin(W);
      HideCursor;
      if MouseOn(ScreenRows, 27, 27) or ((Key = $438) and ShiftDown) then
      begin
        S := PathDialog;
        if Length(S) <> 0 then
        begin
          CurPath := S;
          Key := 13;
        end
        else
          Key := 0;
      end;
      List.Handle(Key);
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
        $423: ShowHelp($1B);
        13: TreeBrowser := CurPath;
        10:
          begin
            Attr := TextAttr;
            Total := 0;
            SetColor(14, 4);
            MouseHide;
            GotoXY(2, List.Cur);
            {$I+} WriteLn('  warten...  '); {$I-}
            MouseShow;
            ArrowCursor;
            ScanDirs(CurPath, Total, Dirs, Files);
            NormalCursor;
            MouseHide;
            GotoXY(2, List.Cur);
            {$I+} WriteLn(SizeStr(Total), ' '); {$I-}
            TextAttr := Attr;
            MouseShow;
          end;
        14, $427: FindEntry(True, SearchS);
        1, $428:
          begin
            SearchS := CurName;
            Found := FindEntry(False, SearchS);
            while Found and (CurPath <> Path) do Found := FindEntry(True, SearchS);
            SearchS := '';
          end;
        12, $429:
          begin
            for I := 1 to DirCount do FreeMem(Tree^[I], SizeOf(TNode));
            CreateTree(Dir);
            LoadTree(TreeName);
            CurIdx := 0;
            List.SetData(DirCount, ScreenRows - 6, 1, 0);
            SearchS := CurName;
            Found := FindEntry(False, SearchS);
            while Found and (CurPath <> Path) do Found := FindEntry(True, SearchS);
            if Found then CurIdx := List.Cur + List.Top;
            SearchS := '';
            ShowSearch;
          end;
        $450:
          begin
            Drive := SelectDrive(20, 10, Dir[1]);
            MouseMap := SaveMap;
            MouseTextCursor;
            if Drive <> ' ' then
            begin
              GetDir(0, S);
              Drive := UpCaseC(Drive);
              if Length(S) > 3 then DelBackslash(S);
              ChDir(Drive + ':');
              FindFirst('*.*', $3F, SR);
              if (IOResult <> 0) or (DosError <> 0) and (DosError <> 18) then
              begin
                if SoundOn then PlaySound(4);
                ChDir(S);
                if IOResult <> 0 then ;
              end
              else
              begin
                for I := 1 to DirCount do FreeMem(Tree^[I], SizeOf(TNode));
                Dir := Drive + ':\';
                GetDir(0, Path);
                if Length(Path) <> 3 then CurName := LastDir(Path + '\d') else CurName := Path;
                ChDir(S);
                if IOResult <> 0 then ;
                TreeName := 'dx' + Dir[1] + 'tree.dat';
                if not LoadTree(TreeName) then
                begin
                  CreateTree(Dir);
                  LoadTree(TreeName);
                end;
                CurIdx := 0;
                List.SetData(DirCount, ScreenRows - 6, 1, 0);
                SearchS := CurName;
                Found := FindEntry(False, SearchS);
                while Found and (CurPath <> Path) do Found := FindEntry(True, SearchS);
                if Found then CurIdx := List.Cur + List.Top;
                SearchS := '';
                ShowSearch;
              end;
            end;
          end;
        $21..$9A, 8: SearchKey;
      else
        if Length(SearchS) <> 0 then
        begin
          SearchS := '';
          ShowSearch;
        end;
      end;
    until (Key = 27) or (MouseButton = 2) or (Key = 13) or (Key = $42C);
    BorderColor := OldBorder;
    RestoreBorder;
    ClockOn;
  end;

  procedure BuildTree(Last: Boolean; Prefix: string);
  var
    I, N: Integer;
    LastF: Boolean;
    Branch: string[3];
    Rec: TTreeRec;
  begin
    LastF := False;
    if MemAvail < $4000 then Exit;
    {$I+}
    if not Eof(TreeF) then {$I-}
    begin
      Read(TreeF, Rec);
      if IOResult <> 0 then Exit;
      if Last then Branch := #$C0#$C4 else Branch := #$C3#$C4;
      Inc(DirCount);
      GetMem(Tree^[DirCount], SizeOf(TNode));
      Tree^[DirCount]^.Line := Copy(Prefix, 1, Length(Prefix) - 1) + Branch + Rec.Name;
      Tree^[DirCount]^.Level := Rec.Depth;
      Tree^[DirCount]^.Size := Rec.Size;
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
        LastF := True;
        Branch := '   ';
      end
      else
        Branch := '  '#$B3;
      BuildTree(LastF, Prefix + Branch);
    end;
  end;

  function LoadTree(Name: Str12): Boolean;
  var
    Rec: TTreeRec;
    LastF: Boolean;
    I: Integer;
    Branch: string[3];
  begin
    LoadTree := False;
    Assign(TreeF, HomeDir + Name);
    Reset(TreeF);
    if IOResult <> 0 then Exit;
    Read(TreeF, Rec);
    if IOResult <> 0 then
    begin
      Close(TreeF);
      InOutRes := 0;
      Exit;
    end;
    if (Rec.Count <> $FF) or (Rec.Depth <> $FF) or (Rec.Name <> 'DX4') or (Rec.Size <> 255) then
    begin
      Close(TreeF);
      InOutRes := 0;
      Exit;
    end;
    Read(TreeF, Rec);
    if IOResult <> 0 then
    begin
      Close(TreeF);
      InOutRes := 0;
      Exit;
    end;
    GetMem(Tree^[1], SizeOf(TNode));
    LastF := False;
    Tree^[1]^.Line := ' ' + Rec.Name + '\';
    Tree^[1]^.Level := Rec.Depth;
    Tree^[1]^.Size := Rec.Size;
    DirCount := 1;
    for I := 1 to Rec.Count do
    begin
      if Rec.Count = I then
      begin
        LastF := True;
        Branch := '   ';
      end
      else
        Branch := '  '#$B3;
      BuildTree(LastF, Branch);
    end;
    Close(TreeF);
    InOutRes := 0;
    LoadTree := True;
  end;

  function CreateTree(Dir: string): Boolean;
  var
    Rec: TTreeRec;
  begin
    OpenDialog;
    Flag := 1;
    CreateTree := True;
    TreeName := 'dx' + Dir[1] + 'tree.dat';
    Assign(TreeF, HomeDir + TreeName);
    Rec.Count := $FF;
    Rec.Depth := $FF;
    Rec.Name := 'DX4';
    Rec.Size := 255;
    Rewrite(TreeF);
    Write(TreeF, Rec);
    if IOResult <> 0 then
    begin
      PopScreen(DlgStack);
      CreateTree := False;
      Exit;
    end;
    Abort := False;
    Dir := Copy(Dir, 1, 2);
    Frame(13, 7, 54, 5, 15, 5, 0, 1);
    WriteCenterXY(1, 2, 54, 'Lese das Inhaltsverzeichnis!');
    MouseShow;
    ArrowCursor;
    ScanDir(Root, Dir);
    Close(TreeF);
    if IOResult <> 0 then ;
    PopScreen(DlgStack);
    NormalCursor;
    if Abort then
      MsgBox('Zu wenig Speicher oder zu viele Dateien und', 'Verzeichnisse oder Abbruch durch Esc!');
  end;

  procedure QuickFind(Name: Str80);
  var
    I: Integer;
    S: string[12];
    P: Byte;
    Found: Boolean;
  begin
    DirTreeDialog := '';
    Flag := 0;
    Name := UpperStr(Name);
    GetDir(0, Dir);
    TreeName := 'dx' + Dir[1] + 'tree.dat';
    if MaxAvail < $5388 then
    begin
      MsgBox('Zu wenig Speicher!', '');
      PopScreen(DlgStack);
      Exit;
    end;
    GetMem(Tree, SizeOf(TNodes));
    DirCount := 0;
    if not LoadTree(TreeName) then
    begin
      if not CreateTree(Dir) then
      begin
        MsgBox('Konnte die Datei nicht erzeugen!', HomeDir + TreeName);
        FreeMem(Tree, SizeOf(TNodes));
        PopScreen(DlgStack);
        Exit;
      end;
      LoadTree(TreeName);
    end;
    I := 0;
    repeat
      Inc(I);
      S := NodeName(I, P);
      Found := Copy(S, 1, Length(Name)) = Name;
    until (I >= DirCount) or Found;
    if Found then DirTreeDialog := FullPath(I) else DirTreeDialog := '';
    for I := 1 to DirCount do FreeMem(Tree^[I], SizeOf(TNode));
    FreeMem(Tree, SizeOf(TNodes));
  end;

begin
  if Quick then
    QuickFind(Path)
  else
  begin
    OpenDialog;
    MouseShow;
    ArrowCursor;
    DirTreeDialog := '';
    Flag := 0;
    if Length(Path) <> 3 then CurName := LastDir(Path + '\d') else CurName := Path;
    TreeName := 'dx' + Path[1] + 'tree.dat';
    if MaxAvail < $5388 then
    begin
      MsgBox('Zu wenig Speicher!', '');
      PopScreen(DlgStack);
      Exit;
    end;
    GetMem(Tree, SizeOf(TNodes));
    DirCount := 0;
    Dir := Path;
    if Length(Dir) = 0 then GetDir(0, Dir);
    if not LoadTree(TreeName) then
    begin
      if not CreateTree(Dir) then
      begin
        MsgBox('Konnte die Datei nicht erzeugen!', HomeDir + TreeName);
        FreeMem(Tree, SizeOf(TNodes));
        PopScreen(DlgStack);
        Exit;
      end;
      LoadTree(TreeName);
    end;
    NormalCursor;
    DirTreeDialog := TreeBrowser;
    PopScreen(DlgStack);
    for I := 1 to DirCount do FreeMem(Tree^[I], SizeOf(TNode));
    FreeMem(Tree, SizeOf(TNodes));
    WaitRelease;
  end;
end;

end.
