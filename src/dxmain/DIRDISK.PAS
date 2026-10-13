{$O+,F+,G+,S-,I-,X+,V-}
unit DirDisk;
{ Overlay 10f2: copy/move a directory tree (also across several floppies) }

interface

function CopyDirTree(Src, Dst: string; Mode: Byte; Move: Boolean; var Canceled: Boolean;
  Verify, Silent: Boolean; var Never, All: Boolean): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, ScrSave, LongName, FileAsk,
  U10F9, U12D5, DirTree;

type
  PDirList = ^TDirList;
  PDirEntry = ^TDirEntry;
  TDirEntry = record
    Name: string[12];
    Sub: PDirList;
  end;
  TDirList = record
    Path: string;
    Entries: array[1..512] of PDirEntry;
    Count: Byte;
  end;
  PNode = ^TNode;
  TNode = record
    Path: string;
    Next, Prev: PNode;
  end;

var
  Abort: Boolean;
  MoveMode: Boolean;
  GMove: Boolean;
  GMode: Byte;
  UserAbort: Boolean;
  Head, Tail: PNode;
  Dirs, Files, FileNo: Word;
  GVerify, GSilent: Boolean;
  GAll, GNever: Boolean;

function CopyError(Name: string): Byte;
var
  B3: TButton3;
  Retry, Ignore, Cancel: Boolean;
  Key: Word;
begin
  OpenDialog;
  Frame(13, 6, 55, 12, 2, 5, 0, 1);
  WriteCenterXYF(1, 3, 55, 4, 'Fehler beim Kopieren der Datei oder Abbruch!');
  WriteCenterXYF(1, 6, 55, 14, Name);
  InitButton3(True, 3, 10, 21, 10, 39, 10, 14, 0, 2, 5, ' Wiederholen ', ' Ignorieren ', ' Abbrechen ', B3);
  MouseShow;
  NormalCursor;
  repeat
    HandleButton3(Retry, Ignore, Cancel, Key, B3);
    if LoCaseW(Key) = 'w' then Retry := True;
    if LoCaseW(Key) = 'a' then Cancel := True;
    if LoCaseW(Key) = 'i' then Ignore := True;
  until Cancel or Retry or Ignore or IsCancel(Key);
  PopScreen(DlgStack);
  if Cancel then CopyError := 0;
  if Ignore then CopyError := 2;
  if Retry then CopyError := 1;
  if Ignore then CopyError := 2;
end;

procedure ReadDirs(Path: string; var L: TDirList);
var
  SR: SearchRec;
begin
  if Abort then Exit;
  L.Path := Path;
  L.Count := 0;
  FindFirst(L.Path, $37, SR);
  if SR.Name = '.' then FindNext(SR);
  if SR.Name = '..' then FindNext(SR);
  if DosError <> 18 then
  repeat
    if SR.Attr and Directory <> 0 then
    begin
      Inc(L.Count);
      GetMem(L.Entries[L.Count], SizeOf(TDirEntry));
      L.Entries[L.Count]^.Name := SR.Name;
    end;
    FindNext(SR);
  until DosError <> 0;
end;

procedure CopyFiles(Src, Dst: string; var L: TDirList);
label
  Skipped;
var
  SR: SearchRec;
  Dummy: string[127];
  Full: string;
  Key, W: Word;
  Ok: Boolean;
  Node: PNode;
  H1, H2: Boolean;
  B2: TButton2;
  Fail, R: Byte;
  Bin, Done, Over, Skip, Res: Boolean;
begin
  if Abort then Exit;
  Skip := False;
  Done := False;
  Res := False;
  Over := False;
  FindFirst(L.Path, $37, SR);
  AddBackslash(Src);
  AddBackslash(Dst);
  while DosError = 0 do
  begin
    if Abort then Exit;
    Full := SR.Name;
    if CfgColors[56] <> 0 then GetLongName(Src + SR.Name, Full, False);
    Full := Dst + Full;
    if SR.Name[1] <> '.' then
    begin
      if SR.Attr and Directory <> 0 then
      begin
        MouseHide;
        Frame(13, 6, 55, 12, 11, 3, 0, 1);
        WriteCenterXY(1, 2, 55, 'Erzeuge das Verzeichnis:');
        WriteCenterXYF(1, 4, 55, 14, Shorten(Full, 53));
        MouseShow;
        Fail := 0;
        if CfgColors[56] <> 0 then
        begin
          if not LfnMkDir(Full) then Fail := 1;
        end
        else
        begin
          MkDir(Full);
          Fail := IOResult;
        end;
        if (Fail <> 0) and not GSilent then
        begin
          MsgBox('Konnte das Verzeichnis nicht erstellen', Shorten(Full, 50));
          Abort := True;
        end;
        GetMem(Tail^.Next, SizeOf(TNode));
        Tail^.Next^.Prev := Tail;
        Tail := Tail^.Next;
        Tail^.Path := Full;
        Tail^.Next := nil;
      end
      else if MoveMode then
      begin
        Frame(13, 6, 55, 12, 11, 3, 0, 1);
        WriteCenterXY(1, 2, 55, 'Bewegen der Datei');
        WriteCenterXYF(1, 4, 55, 14, Shorten(Src + SR.Name, 53));
        WriteCenterXY(1, 6, 55, ' nach:');
        WriteCenterXYF(1, 8, 55, 14, Shorten(Full, 53));
        if not P10F9_84(Src + SR.Name, Full, GNever, GAll) then Abort := True;
      end
      else
      begin
        Inc(FileNo);
        if (Dst[1] = 'A') or (Dst[1] = 'B') then Bin := False else Bin := True;
        Done := True;
        repeat
          if GSilent and not GAll and (CfgColors[36] <> 0) and
             (((CfgColors[56] = 0) and (FSearch(Full, '') <> '')) or
              ((CfgColors[56] <> 0) and LfnFileExists(Full))) then
          begin
            if GNever then goto Skipped;
            Res := AskOverwrite(Full, Over, Skip, GAll, GNever);
            if Res then
            begin
              Abort := True;
              UserAbort := True;
              Exit;
            end;
            if Skip or GNever then goto Skipped;
          end;
          Abort := not P12D5_95(Src + SR.Name, Full, GMode, Ok, FileNo, Files, Bin, GVerify, GMove);
        Skipped:
          if Abort and not Ok then
          begin
            R := CopyError(Src + SR.Name);
            if R = 0 then Done := True;
            if R = 1 then Done := False;
            if R = 2 then
            begin
              Done := True;
              Abort := False;
            end;
          end;
        until Ok or Done or not Abort;
      end;
      if Abort and ((Dst[1] = 'A') or (Dst[1] = 'B')) and Ok and not MoveMode then
      repeat
        MouseHide;
        Frame(13, 6, 55, 12, 11, 3, 0, 1);
        WriteCenterXYF(1, 3, 55, 14, 'Bitte die Diskette wechseln!');
        WriteCenterXY(1, 5, 55, 'Auf der neuen Diskette wird zun'#$84'chst der');
        WriteCenterXY(1, 7, 55, 'korrekte Verzeichnisbaum angelegt!');
        InitButton2(True, 3, 10, 28, 10, 14, 0, 11, 3, '       Weiter       ', '       Abbruch       ', B2);
        MouseShow;
        NormalCursor;
        repeat
          HandleButton2(H1, H2, Key, B2);
        until (Key = 27) or (Key = $42C) or (MouseButton = 2) or H1 or H2;
        if (Key = 27) or (Key = $42C) or (MouseButton = 2) or H2 then
        begin
          Key := 27;
          H2 := True;
          Abort := True;
        end;
        if not H2 then
        begin
          Node := Head;
          Abort := False;
          ArrowCursor;
          Fail := 0;
          if CfgColors[56] <> 0 then
          begin
            if not LfnMkDir(Node^.Path) then Fail := 1;
          end
          else
          begin
            MkDir(Node^.Path);
            Fail := IOResult;
          end;
          if Fail <> 0 then
            if CfgColors[56] <> 0 then LfnMkDirTree(Node^.Path)
            else MakeDir(Node^.Path);
          while (Node^.Next <> nil) and not Abort do
          begin
            Node := Node^.Next;
            MouseHide;
            Frame(13, 6, 55, 12, 11, 3, 0, 1);
            WriteCenterXY(1, 4, 55, 'Erzeuge das Verzeichnis:');
            WriteCenterXYF(1, 6, 55, 14, Shorten(Node^.Path, 53));
            MouseShow;
            if CfgColors[56] <> 0 then LfnMkDir(Node^.Path)
            else MkDir(Node^.Path);
            GB90 := 0;
          end;
          Abort := not P12D5_95(Src + SR.Name, Dst + SR.Name, GMode, Ok, FileNo, Files, True, GVerify, GMove);
        end;
      until not Ok or H2;
      if Key = 27 then
      begin
        Abort := True;
        UserAbort := True;
      end;
    end;
    GetKey(Key);
    if Key = 27 then
    begin
      Abort := True;
      UserAbort := True;
    end;
    FindNext(SR);
  end;
end;

procedure CopyTree(var L: PDirList; Src, Dst: string);
var
  I: Integer;
  Name: string;
begin
  if Abort then Exit;
  GetMem(L, SizeOf(TDirList));
  ReadDirs(Src + '\*.*', L^);
  CopyFiles(Src, Dst, L^);
  for I := 1 to L^.Count do
  begin
    Name := Dst + '\' + L^.Entries[I]^.Name;
    if CfgColors[56] <> 0 then
    begin
      GetLongName(Src + '\' + L^.Entries[I]^.Name, Name, False);
      Name := Dst + '\' + Name;
    end;
    CopyTree(L^.Entries[I]^.Sub, Src + '\' + L^.Entries[I]^.Name, Name);
  end;
  for I := 1 to L^.Count do
    FreeMem(L^.Entries[I], SizeOf(TDirEntry));
  FreeMem(L, SizeOf(TDirList));
end;

function CopyDirTree(Src, Dst: string; Mode: Byte; Move: Boolean; var Canceled: Boolean;
  Verify, Silent: Boolean; var Never, All: Boolean): Boolean;
var
  L: PDirList;
  Size: Longint;
  N: Byte;
  S: string[12];
  B2: TButton2;
  H1, H2: Boolean;
  Key: Word;
  Err: Word;
  Tmp: string;
begin
  Canceled := False;
  FileNo := 0;
  Files := 0;
  GVerify := Verify;
  GSilent := Silent;
  GMode := Mode;
  GNever := Never;
  GAll := All;
  MoveMode := Move and (UpCaseC(Src[1]) = UpCaseC(Dst[1]));
  GMove := Move;
  Abort := False;
  DelBackslash(Src);
  GetMem(Tail, SizeOf(TNode));
  Tail^.Path := Dst;
  Tail^.Next := nil;
  Tail^.Prev := nil;
  Head := Tail;
  if (UpCaseC(Dst[1]) = 'A') or (UpCaseC(Dst[1]) = 'B') then
  begin
    Tmp := Src;
    if ScanDirs(Tmp, Size, Dirs, Files) then
    begin
      MsgBox('Fehler beim Auslesen der Verzeichnisstruktur!', '');
      Abort := True;
    end
    else
    begin
      OpenDialog;
      Frame(10, 4, 60, 18, 11, 3, 0, 1);
      if Move then WriteCenterXY(1, 1, 60, 'Bewegen des Verzeichnisses')
      else WriteCenterXY(1, 1, 60, 'Kopieren des Verzeichnisses');
      WriteCenterXYF(1, 3, 60, 14, Shorten(Src, 58));
      WriteCenterXY(1, 5, 60, '  auf eine (oder mehrere) Diskette(n)');
      Str(Files: 12, S);
      WriteXYF(14, 7, 14, S);
      {$I+}
      Write(' Datei(en)');
      {$I-}
      Str(Dirs + 1: 12, S);
      WriteXYF(14, 8, 14, S);
      {$I+}
      Write(' Verzeichnis(se)');
      {$I-}
      S := FormatNum(Size);
      WriteXYF(14, 9, 14, S);
      {$I+}
      Write(' Bytes in den Dateien');
      {$I-}
      WriteCenterXY(1, 11, 60, 'Gesch'#$84'tzte Diskettenanzahl:');
      N := ((Longint(Dirs) + 1) * 512 + (Size div 512 + 1) * 512) div 1457664 + 1;
      TextColor(14);
      WriteXYF(21, 12, 11, '3 1/2" 1.44 MB: ');
      {$I+}
      Write(N: 2);
      {$I-}
      N := ((Longint(Dirs) + 1) * 1024 + (Size div 1024 + 1) * 1024) div 730112 + 1;
      WriteXYF(21, 13, 11, '3 1/2"  720 KB: ');
      {$I+}
      Write(N: 2);
      {$I-}
      N := ((Longint(Dirs) + 1) * 512 + (Size div 512 + 1) * 512) div 1213952 + 1;
      WriteXYF(21, 14, 11, '5 1/4"  1.2 MB: ');
      {$I+}
      Write(N: 2);
      {$I-}
      N := ((Longint(Dirs) + 1) * 1024 + (Size div 1024 + 1) * 1024) div 362496 + 1;
      WriteXYF(21, 15, 11, '5 1/4"  360 KB: ');
      {$I+}
      Write(N: 2);
      {$I-}
      InitButton2(True, 3, 16, 32, 16, 14, 0, 11, 3, '        Weiter        ', '        Abbruch        ', B2);
      MouseShow;
      repeat
        HandleButton2(H1, H2, Key, B2);
      until (Key = 27) or (Key = $42C) or (MouseButton = 2) or H1 or H2;
      PopScreen(DlgStack);
      if (Key = 27) or (Key = $42C) or H2 or (MouseButton = 2) then
      begin
        H2 := True;
        Abort := True;
      end;
    end;
  end;
  if not Abort then
  begin
    ArrowCursor;
    Err := 0;
    if CfgColors[56] <> 0 then
    begin
      if not LfnMkDir(Dst) then Err := 1;
    end
    else
    begin
      MkDir(Dst);
      Err := IOResult;
    end;
    if (Err <> 0) and not GSilent then
    begin
      Abort := True;
      ErrorBox('Konnte das Verzeichnis nicht erstellen:', Dst);
    end
    else
      CopyTree(L, Src, Dst);
  end;
  CopyDirTree := not Abort;
  NormalCursor;
  Never := GNever;
  All := GAll;
  Canceled := UserAbort or H2;
  while Tail^.Prev <> nil do
  begin
    Tail := Tail^.Prev;
    FreeMem(Tail^.Next, SizeOf(TNode));
  end;
  FreeMem(Tail, SizeOf(TNode));
  NormalCursor;
end;

end.
