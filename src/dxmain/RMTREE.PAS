{$O+,F+,G+,S-,I-,X+}
unit RmTree;

interface

function RemoveTree(Path: string): Boolean;

implementation

uses Dos, DXGlob, Windows, Screen, Status, Dialogs, Mouse, ScrSave;

type
  PDirList = ^TDirList;
  PDirEntry = ^TDirEntry;
  TDirEntry = record
    Name: string[12];
    Sub: PDirList;
  end;
  TDirList = record
    Path: string[128];
    Entries: array[1..512] of PDirEntry;
    Count: Byte;
  end;

procedure ReadDirs(Path: string; var L: TDirList);
var
  SR: SearchRec;
begin
  if DelAbort then Exit;
  L.Path := Path;
  L.Count := 0;
  FindFirst(L.Path, $37, SR);
  if DosError <> 18 then
  repeat
    if (SR.Attr and Directory <> 0) and (SR.Name[1] <> '.') then
    begin
      Inc(L.Count);
      GetMem(L.Entries[L.Count], SizeOf(TDirEntry));
      L.Entries[L.Count]^.Name := SR.Name;
    end;
    FindNext(SR);
  until DosError = 18;
end;

procedure DelFiles(var L: TDirList);
var
  SR: SearchRec;
  Dummy: string[127];
  Name: string;
  Err: Word;
  Key: Word;
begin
  FindFirst(L.Path, $37, SR);
  while DosError = 0 do
  begin
    GetKey(Key);
    MouseMoved := 0;
    if Key = 27 then DelAbort := True;
    if DelAbort then Exit;
    Name := Copy(L.Path, 1, Length(L.Path) - 3) + SR.Name;
    if SR.Name[1] <> '.' then
    begin
      MouseHide;
      WriteCenterXYF(1, 4, 54, 14, Shorten(Name, 50));
      MouseShow;
      if SR.Attr and Directory <> 0 then RmDir(Name);
      if IOResult <> 0 then
      begin
        if Err = 150 then
          ErrorBox('Verzeichnisse entfernen:', 'Diskette ist schreibgesch'#$81'tzt!')
        else
          ErrorBox('Verzeichnis entfernen nicht m'#$94'glich!', Name);
        DelAbort := True;
        Exit;
      end;
    end;
    FindNext(SR);
  end;
end;

procedure DelDir(var L: PDirList; Path: string);
var
  I: Integer;
begin
  if Length(Path) = 0 then Exit;
  if (Length(Path) = 2) and (Path[2] = ':') then Exit;
  if DelAbort then Exit;
  GetMem(L, SizeOf(TDirList));
  ReadDirs(Path + '\*.*', L^);
  for I := 1 to L^.Count do
    DelDir(L^.Entries[I]^.Sub, Path + '\' + L^.Entries[I]^.Name);
  DelFiles(L^);
  for I := 1 to L^.Count do
    FreeMem(L^.Entries[I], SizeOf(TDirEntry));
  FreeMem(L, SizeOf(TDirList));
end;

function RemoveTree(Path: string): Boolean;
var
  L: PDirList;
begin
  RemoveTree := False;
  DelAbort := False;
  DelBackslash(Path);
  if Length(Path) = 0 then Exit;
  if (Length(Path) = 2) and (Path[2] = ':') then Exit;
  OpenDialog;
  Frame(13, 6, 56, 12, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 56, 'L'#$94'schen der Datei oder des Verzeichnisses');
  MouseShow;
  ArrowCursor;
  DelDir(L, Path);
  NormalCursor;
  RmDir(Path);
  if IOResult <> 0 then DelAbort := True;
  RemoveTree := True;
  if DelAbort then RemoveTree := False;
  PopScreen(DlgStack);
end;

end.
