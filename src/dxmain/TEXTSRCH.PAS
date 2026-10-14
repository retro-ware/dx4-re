{$O+,F+,G+,S-,I-,X+,V-}
unit TextSrch;

interface

type
  TFileRec = record
    Name: string[12];
    Fill: array[1..8] of Byte;
    Attr: Byte;
    Marked: Boolean;
  end;
  PFileRec = ^TFileRec;
  TFileList = array[0..1023] of PFileRec;
  PFileList = ^TFileList;

function SearchFile(Name, Text: string; Flags: Byte; var Status: Byte): Boolean;
function SearchMarked(Last, First: Word; Files: PFileList; var NMarked: Word): Boolean;

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, AskDlgs;

function SearchFile(Name, Text: string; Flags: Byte; var Status: Byte): Boolean;
var
  F: file;
  BufSize, Size, Pos: Longint;
  Buf: Pointer;
  N: Word;
  Err: Word;
  Key: Word;
  AtEof: Boolean;
  Found: Boolean;

function FindText(Buf: Pointer; Len: Word; S: string; CaseSens: Boolean): Boolean;
var
  L, BufSeg, BufOfs, SOfs, EndOfs, NotFound, FoundAt, X, Y: Word;
  CaseS: Boolean;
begin
  CaseS := CaseSens;
  if not CaseSens then S := LowerStr(S);
  BufSeg := Seg(Buf^);
  BufOfs := Ofs(Buf^);
  L := Length(S);
  EndOfs := Len - L + 1 + BufOfs;
  SOfs := Ofs(S);
  asm
    cld
    push ds
    mov ax,ss
    mov es,ax
    mov bx,BufOfs
    mov ax,BufSeg
    mov ds,ax
  @next:
    mov si,bx
    mov di,SOfs
    mov cx,L
  @cmp:
    mov al,[si]
    inc si
    inc di
    cmp byte ptr es:CaseS,1
    je @ok
    cmp al,9Ah
    jne @1
    mov al,81h
    jmp @ok
  @1:
    cmp al,8Eh
    jne @2
    mov al,84h
    jmp @ok
  @2:
    cmp al,99h
    jne @3
    mov al,94h
    jmp @ok
  @3:
    cmp al,'A'
    jb @ok
    cmp al,'Z'
    ja @ok
    add al,20h
  @ok:
    cmp byte ptr es:[di],al
    loope @cmp
    je @found
    inc bx
    cmp bx,EndOfs
    jae @notfound
    jmp @next
  @found:
    pop ds
    mov NotFound,0
    jmp @done
  @notfound:
    pop ds
    mov NotFound,1
  @done:
    sub bx,BufOfs
    mov FoundAt,bx
  end;
  FindText := NotFound = 0;
end;

begin
  Assign(F, Name);
  Status := 0;
  Err := 0;
  SearchFile := False;
  Found := False;
  Reset(F, 1);
  if IOResult <> 0 then
  begin
    ErrorBox('Datei konnte nicht ge'#$94'ffnet werden:', Name);
    Exit;
  end;
  Size := FileSize(F);
  BufSize := Size;
  if Length(Text) > Size then
  begin
    Close(F);
    InOutRes := 0;
    Exit;
  end;
  if BufSize >= 20481 then BufSize := 20481;
  if MaxAvail < BufSize then
  begin
    Close(F);
    InOutRes := 0;
    Status := 2;
    Exit;
  end;
  GetMem(Buf, BufSize);
  if Buf = nil then
  begin
    Close(F);
    InOutRes := 0;
    Status := 2;
    Exit;
  end;
  repeat
    BlockRead(F, Buf^, BufSize, N);
    Err := IOResult;
    if Err = 0 then Found := FindText(Buf, N, Text, False);
    AtEof := Eof(F);
    Err := Err + IOResult;
    if (Err = 0) and (Size > BufSize) and not AtEof then
    begin
      Pos := FilePos(F);
      Err := IOResult;
      Seek(F, Pos - 260);
      Err := Err + IOResult;
    end;
    GetKey(Key);
    if Key = 27 then Status := 3;
    if Err <> 0 then Status := 4;
  until AtEof or (Status > 0) or Found;
  FreeMem(Buf, BufSize);
  Close(F);
  InOutRes := 0;
  SearchFile := Found;
end;

function SearchMarked(Last, First: Word; Files: PFileList; var NMarked: Word): Boolean;
var
  Name: Str12;
  I, Key: Word;
  Text: string[128];
  Status: Byte;
  Found: Boolean;
  Aborted: Boolean;
  Single: Boolean;
  NFound: Word;
begin
  Found := False;
  Aborted := False;
  Status := 0;
  SearchMarked := False;
  Name := Files^[First]^.Name;
  Name[9] := '.';
  Name := CompressName(Name);
  Single := (Files^[First]^.Attr and $10 <> 0) and (NMarked = 0);
  Text := Name;
  AskSearchText(Text, NMarked, '');
  if Text = '' then Exit;
  SearchMarked := True;
  OpenDialog;
  Frame(20, 10, 40, 5, 11, 3, 0, 1);
  WriteXY(4, 2, 'Durchsuche die Datei: ');
  WriteXY(4, 4, 'Anzahl gefundener Dateien: 0');
  NFound := 0;
  MouseShow;
  if NMarked = 0 then
  begin
    Files^[First]^.Marked := True;
    NMarked := 1;
  end;
  I := 0;
  ArrowCursor;
  repeat
    Inc(I);
    Name := Files^[I]^.Name;
    Name[9] := '.';
    Name := CompressName(Name);
    if Files^[I]^.Marked and (Files^[I]^.Attr and $10 = 0) then
    begin
      MouseHide;
      WriteXY(26, 2, Name + Spaces(12 - Length(Name)));
      MouseShow;
      if not SearchFile(Name, Text, 0, Status) then
      begin
        Files^[I]^.Marked := False;
        Dec(NMarked);
      end
      else
      begin
        Inc(NFound);
        Found := True;
        MouseHide;
        GotoXY(31, 4);
        Write(NFound);
        MouseShow;
      end;
    end;
    GetKey(Key);
    if MouseButton = 2 then Key := 27;
  until (I = Last) or (Key = 27) or (Status <> 0);
  NormalCursor;
  CloseDialog;
  if (Status <> 0) or (Key = 27) then
    ErrorBox('Textsuche: Fehler oder Abbruch durch Anwender.', 'Der Vorgang wurde abgebrochen.')
  else
  begin
    if (I = Last) and Found then
      ErrorBox('Gefundene Dateien werden nun markiert!', CutStr(Text, 50));
    if not Found then
      ErrorBox('Der Text wurde nicht gefunden:', CutStr(Text, 50));
  end;
end;

end.
