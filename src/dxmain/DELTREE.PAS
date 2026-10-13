{$O+,F+,G+,S-,I-,X+,V-}
unit DelTree;

interface

function DelDirectory(Path: string; var Ask: Boolean; var Cancel: Boolean): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, LongName;

type
  PDirList = ^TDirList;
  PSub = ^TSub;
  TSub = record
    Name: string[12];
    Sub: PDirList;
  end;
  TDirList = record
    Path: string[128];
    Subs: array[1..512] of PSub;
    Count: Byte;
  end;

var
  Aborted: Boolean;

procedure ScanDir(Path: string; var D: TDirList);
var
  S: SearchRec;
begin
  if Aborted then Exit;
  D.Path := Path;
  D.Count := 0;
  FindFirst(D.Path, $37, S);
  if S.Name = '.' then FindNext(S);
  if S.Name = '..' then FindNext(S);
  if DosError <> 18 then
    repeat
      if S.Attr and $10 <> 0 then
      begin
        Inc(D.Count);
        GetMem(D.Subs[D.Count], 17);
        D.Subs[D.Count]^.Name := S.Name;
      end;
      FindNext(S);
    until DosError = 18;
end;

procedure DeleteFiles(var D: TDirList);
var
  S: SearchRec;
  F: file;
  Full: string;
  E: Integer;
  Key: Word;
begin
  FindFirst(D.Path, $37, S);
  while DosError = 0 do
  begin
    GetKey(Key);
    MouseMoved := 0;
    if Key = 27 then
    begin
      Aborted := True;
      MsgBox('L'#$94'schen wurde abgebrochen!', '');
    end;
    if Aborted then Exit;
    Full := Copy(D.Path, 1, Length(D.Path) - 3) + S.Name;
    if S.Name[1] <> '.' then
    begin
      MouseHide;
      WriteCenterXYF(1, 4, 54, 14, Shorten(Full, 50));
      MouseShow;
      if S.Attr and $10 <> 0 then
      begin
        RmDir(Full);
        InOutRes := 0;
      end
      else
      begin
        Assign(F, Full);
        SetFAttr(F, $20);
        E := DosError;
        if E = 0 then
        begin
          {$I+}
          Erase(F);
          {$I-}
        end;
      end;
    end;
    E := IOResult + DosError;
    if E <> 0 then
    begin
      if E = 150 then
        MsgBox('Fehler beim L'#$94'schen!', 'Diskette ist schreibgesch'#$81'tzt!')
      else
        MsgBox('Fehler beim L'#$94'schen von', Full);
      Aborted := True;
      Exit;
    end;
    FindNext(S);
  end;
end;

procedure DelSubTree(var D: PDirList; Path: string);
var
  I: Integer;
begin
  if Path = '' then Exit;
  if (Length(Path) = 2) and (Path[2] = ':') then Exit;
  if Aborted then Exit;
  GetMem(D, SizeOf(TDirList));
  ScanDir(Path + '\*.*', D^);
  for I := 1 to D^.Count do
    DelSubTree(D^.Subs[I]^.Sub, Path + '\' + D^.Subs[I]^.Name);
  DeleteFiles(D^);
  for I := 1 to D^.Count do
    FreeMem(D^.Subs[I], 17);
  FreeMem(D, SizeOf(TDirList));
end;

function DelDirectory(Path: string; var Ask: Boolean; var Cancel: Boolean): Boolean;
var
  P: PDirList;
  B: TButton4;
  Yes, All, No: Boolean;
  Key: Word;
  Disp: string;
begin
  DelDirectory := False;
  Aborted := False;
  DelBackslash(Path);
  if Path = '' then Exit;
  if (Length(Path) = 2) and (Path[2] = ':') then Exit;
  OpenDialog;
  MouseShow;
  Yes := True;
  Disp := Path;
  if not ConfirmDel then
  begin
    Ask := False;
    Cancel := False;
  end;
  if Ask then
  begin
    MouseHide;
    Frame(13, 6, 54, 12, 15, 4, 0, 1);
    WriteCenterXYF(1, 2, 54, 15, 'Wollen Sie das Verzeichnis');
    if LongNames then
    begin
      MouseShow;
      ArrowCursor;
      GetLongName(Disp, Disp, True);
    end;
    WriteCenterXYF(1, 5, 54, 14, Shorten(Disp, 50));
    WriteCenterXYF(1, 8, 54, 15, 'inclusive aller Unterverzeichnisse l'#$94'schen?');
    InitButton4(True, 3, 10, 16, 10, 29, 10, 40, 10, 14, 0, 15, 4,
      '   Ja   ', '  Alle  ', ' Nein ', ' Abbruch ', B);
    MouseShow;
    repeat
      NormalCursor;
      HandleButton4(Yes, All, No, Cancel, Key, B);
      if IsCancel(Key) then Cancel := True;
    until Yes or All or Cancel or No;
    if All then
    begin
      Yes := True;
      Ask := False;
    end;
    if No then
    begin
      DelDirectory := True;
      Yes := False;
    end;
  end;
  if Yes then
  begin
    MouseHide;
    Frame(13, 6, 56, 12, 11, 3, 0, 1);
    WriteCenterXY(1, 2, 56, 'L'#$94'schen der Datei oder des Verzeichnisses');
    MouseShow;
    ArrowCursor;
    DelSubTree(P, Path);
    NormalCursor;
    RmDir(Path);
    if IOResult <> 0 then;
    DelDirectory := True;
    if Aborted then DelDirectory := False;
  end;
  PopScreen(DlgStack);
end;

end.
