{$O+,F+,G+,S-,I-,X+,V-}
unit ArcDir;

interface

uses DXGlob;

type
  Str79 = string[79];
  TArcInfo = record
    Path: string[79];
    Size: Longint;
    PackedSize: Longint;
    Flags: Byte;
    Extra: Longint;
  end;
  PArcInfo = ^TArcInfo;
  TArcInfoList = array[0..$400] of PArcInfo;
  PArcInfoList = ^TArcInfoList;

procedure ReadLzh(Name: Str79; Files: PFileList; var Count: Word);
procedure ReadZip(Name: Str79; Files: PFileList; var Count: Word);
procedure ReadArj(Name: Str79; Files: PFileList; var Count: Word);

implementation

uses Dos, Screen, Dialogs;

const
  ZipLocal: array[0..3] of Char = 'PK'#3#4;
  ZipCentral: array[0..3] of Char = 'PK'#1#2;
  ZipMulti: array[0..3] of Char = 'PK'#7#8;
  ArjMagic1: Word = $EA60;
  ArjMagic2: Word = $EA60;

type
  TLzhHdr = record
    Size: Byte;
    Sum: Byte;
    Method: array[2..6] of Char;
    CSize: Longint;
    USize: Longint;
    Time: Longint;
    Attr: Byte;
    Level: Byte;
    NameLen: Byte;
    Name: string;
    Crc: Word;
    OsId: Char;
    ExtSize: Word;
  end;
  TZipHdr = record
    Sig: array[0..3] of Char;
    VerMade, VerNeed, Flags, Method: Word;
    Time: Longint;
    Crc: Longint;
    CSize, USize: Longint;
    NameLen, ExtraLen, CommentLen, Disk, IntAttr: Word;
    case Byte of
      0: (ExtAttr: Longint; LocalOfs: Longint; Name: string);
      1: (AttrB: Byte);
  end;
  TZipLocal = record
    Ver, Flags, Method, Time, Date: Word;
    Crc: Longint;
    CSize, USize: Longint;
    NameLen, ExtraLen: Word;
  end;
  TArjHdr = record
    FirstSize, Version, MinVersion, HostOs: Byte;
    Flags, Method, FileType, Reserved: Byte;
    Time: Longint;
    CSize, USize, Crc: Longint;
    EntryPos: Word;
    Mode: Byte;
    ModeHi: Byte;
    HostData: Word;
    Name: array[0..255] of Byte;
  end;
  PArjHdr = ^TArjHdr;
  TArjBlock = record
    Sig: Word;
    Size: Word;
  end;
  TArjTail = record
    Crc: Longint;
    ExtSize: Word;
  end;
  TArjInfo = record
    Time: Longint;
    Pad: Byte;
    Mode: Byte;
    Crc: Longint;
    CSize: Longint;
    USize: Longint;
    Name: string;
  end;

procedure InitList(Name: string; Files: PFileList; var Count: Word);
var
  DT: DateTime;
  Time: Longint;
  I: Integer;
  T: Text;
begin
  if ArcLoaded then
  begin
    for I := 2 to Count do
      FreeMem(PArcInfoList(ArcInfo)^[I], SizeOf(TArcInfo));
    FreeMem(ArcInfo, SizeOf(TArcInfoList));
    ArcLoaded := False;
  end;
  Time := 0;
  for I := 1 to Count do
    FreeMem(Files^[I], SizeOf(TFileEntry));
  GetMem(Files^[1], SizeOf(TFileEntry));
  Files^[1]^.Size := 0;
  Files^[1]^.Name := '..          ';
  Assign(T, Name);
  Reset(T);
  InOutRes := 0;
  GetFTime(T, Time);
  InOutRes := 0;
  Close(T);
  InOutRes := 0;
  UnpackTime(Time, DT);
  Files^[1]^.Time := Time;
  Files^[1]^.Marked := False;
  Files^[1]^.Flag17 := False;
  Files^[1]^.Attr := $10;
  Count := 1;
end;

procedure ReadLzh(Name: Str79; Files: PFileList; var Count: Word);
var
  F: file;
  Attr: Word;
  Hdr: TLzhHdr;
  I: Word;
  J: Integer;
  Tmp: Str12;
  Buf: string;
  N: Word;
  D: Str79;
  Nm: NameStr;
  E: ExtStr;
  Skip: Longint;
  B3: array[0..2] of Byte;

function ReadHdr(var H: TLzhHdr): Boolean;
var
  N: Word;
  Bad: Boolean;
  Dummy: string;
begin
  BlockRead(F, H.Size, 1, N);
  Bad := (H.Size = 0) or (N = 0);
  if not Bad then
  begin
    BlockRead(F, H.Sum, $15, N);
    BlockRead(F, H.Name[1], H.NameLen, N);
    H.Name[0] := Chr(H.NameLen);
    BlockRead(F, H.Crc, 2, N);
    if H.Level <> 0 then BlockRead(F, H.OsId, 3, N);
  end;
  ReadHdr := not Bad;
  if (H.Level <> 0) and (H.OsId <> 'M') then ReadHdr := False;
end;

begin
  InitList(Name, Files, Count);
  I := 1;
  GetMem(ArcInfo, SizeOf(TArcInfoList));
  ArcLoaded := True;
  Assign(F, Name);
  GetFAttr(F, Attr);
  SetFAttr(F, 0);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  while not Eof(F) do
  begin
    if not ReadHdr(Hdr) then Break;
    Inc(I);
    Inc(Count);
    GetMem(Files^[I], SizeOf(TFileEntry));
    GetMem(PArcInfoList(ArcInfo)^[I], SizeOf(TArcInfo));
    Files^[I]^.Marked := False;
    Files^[I]^.Flag17 := False;
    FSplit(Hdr.Name, D, Nm, E);
    Files^[I]^.Name := LowerStr(Nm + E);
    FormatName(Files^[I]^.Name);
    Files^[I]^.Size := Hdr.USize;
    Files^[I]^.Time := Hdr.Time;
    PArcInfoList(ArcInfo)^[I]^.Path := Hdr.Name;
    PArcInfoList(ArcInfo)^[I]^.Size := Hdr.USize;
    PArcInfoList(ArcInfo)^[I]^.PackedSize := Hdr.CSize;
    PArcInfoList(ArcInfo)^[I]^.Extra := Hdr.Crc;
    Skip := Hdr.CSize;
    if (Hdr.Level <> 0) and (Hdr.ExtSize <> 0) then
    begin
      PArcInfoList(ArcInfo)^[I]^.PackedSize := Hdr.CSize - Hdr.ExtSize - 5;
      BlockRead(F, Buf, Hdr.ExtSize, N);
      if Buf[0] = #2 then
      begin
        Buf[0] := Chr(Hdr.ExtSize - 3);
        for J := 1 to Length(Buf) do
          if Buf[J] = #$FF then Buf[J] := '\';
        PArcInfoList(ArcInfo)^[I]^.Path := Buf + Hdr.Name;
        BlockRead(F, B3, 3, N);
        if B3[0] = $40 then Hdr.Attr := B3[1];
        Skip := Hdr.CSize - (Hdr.ExtSize + 3);
      end
      else if Buf[0] = #$40 then
      begin
        Hdr.Attr := Ord(Buf[1]);
        Skip := Hdr.CSize - Hdr.ExtSize;
      end;
    end;
    Files^[I]^.Attr := Hdr.Attr;
    PArcInfoList(ArcInfo)^[I]^.Flags := Hdr.Attr;
    if Hdr.Attr and 2 <> 0 then
    begin
      Files^[I]^.Name[9] := #$B0;
      Files^[I]^.Name[1] := UpCaseC(Files^[I]^.Name[1]);
    end;
    if Hdr.Attr and 1 <> 0 then Files^[I]^.Name[9] := #$F8;
    Seek(F, FilePos(F) + Skip);
  end;
  Close(F);
  SetFAttr(F, Attr);
  InOutRes := 0;
end;

procedure ReadZip(Name: Str79; Files: PFileList; var Count: Word);
var
  F: file;
  Attr: Word;
  Hdr: TZipHdr;
  I, J: Word;
  D: Str79;
  Nm: NameStr;
  E: ExtStr;
  Done: Boolean;

function FindCentral: Boolean;
var
  N: Word;
  L: TZipLocal;
  Sig: array[0..3] of Char;
begin
  FindCentral := True;
  repeat
    BlockRead(F, Sig, 4, N);
    if Sig = ZipMulti then
    begin
      NormalCursor;
      ErrorBox('Dies ist ein Multi-Volume Zip-File!', 'Kann hier nicht angezeigt werden!');
    end;
    if Sig = ZipLocal then
    begin
      BlockRead(F, L, SizeOf(L), N);
      Seek(F, FilePos(F) + L.CSize + L.ExtraLen + L.NameLen);
    end;
  until (Sig <> ZipLocal) or (N = 0);
  if Eof(F) or (N = 0) or (Sig <> ZipCentral) then FindCentral := False;
end;

procedure ReadCentral(var H: TZipHdr; var Done: Boolean);
var
  N: Word;
  Dummy: Byte;
begin
  BlockRead(F, H.VerMade, $2A, N);
  BlockRead(F, H.Name[1], H.NameLen, N);
  H.Name[0] := Chr(H.NameLen);
  Seek(F, FilePos(F) + H.CommentLen + H.ExtraLen);
  BlockRead(F, H.Sig, 4, N);
  Done := (H.Sig <> ZipCentral) or (N <> 4);
end;

procedure FixSlashes(var S: string);
var
  I: Byte;
begin
  for I := 1 to Length(S) do
    if S[I] = '/' then S[I] := '\';
end;

begin
  InitList(Name, Files, Count);
  I := 1;
  GetMem(ArcInfo, SizeOf(TArcInfoList));
  ArcLoaded := True;
  Assign(F, Name);
  GetFAttr(F, Attr);
  SetFAttr(F, 0);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  if FindCentral then
    repeat
      ReadCentral(Hdr, Done);
      FixSlashes(Hdr.Name);
      FSplit(Hdr.Name, D, Nm, E);
      if Nm <> '' then
      begin
        Inc(I);
        Inc(Count);
        GetMem(Files^[I], SizeOf(TFileEntry));
        GetMem(PArcInfoList(ArcInfo)^[I], SizeOf(TArcInfo));
        Files^[I]^.Marked := False;
        Files^[I]^.Flag17 := False;
        Files^[I]^.Name := LowerStr(Nm + E);
        FormatName(Files^[I]^.Name);
        PArcInfoList(ArcInfo)^[I]^.Path := Hdr.Name;
        Files^[I]^.Attr := Hdr.AttrB;
        PArcInfoList(ArcInfo)^[I]^.Flags := Hdr.AttrB;
        if Hdr.AttrB and 2 <> 0 then
        begin
          Files^[I]^.Name[9] := #$B0;
          Files^[I]^.Name[1] := UpCaseC(Files^[I]^.Name[1]);
        end;
        if Hdr.ExtAttr and 1 <> 0 then Files^[I]^.Name[9] := #$F8;
        Files^[I]^.Size := Hdr.USize;
        PArcInfoList(ArcInfo)^[I]^.Size := Hdr.USize;
        Files^[I]^.Time := Hdr.Time;
        PArcInfoList(ArcInfo)^[I]^.PackedSize := Hdr.CSize;
        PArcInfoList(ArcInfo)^[I]^.Extra := Hdr.Crc;
      end;
    until Done;
  Close(F);
  SetFAttr(F, Attr);
  InOutRes := 0;
end;

procedure ReadArj(Name: Str79; Files: PFileList; var Count: Word);
var
  F: file;
  Attr: Word;
  I: Word;
  Tmp: Str12;
  R: TArjInfo;
  D: string[67];
  Nm: NameStr;
  E: ExtStr;

function FindMain: Boolean;
var
  N: Word;
  Bad: Boolean;
  H: TArjBlock;
  X: TArjTail;
  L: Word;
begin
  BlockRead(F, H, 4, N);
  Bad := (H.Size = 0) or (H.Sig <> ArjMagic1) or (N = 0);
  if not Bad then
  begin
    Seek(F, FilePos(F) + H.Size);
    BlockRead(F, X, 6, N);
    L := X.ExtSize;
    if L > 0 then
    begin
      L := L + 4;
      Seek(F, FilePos(F) + L);
    end;
  end;
  FindMain := not Bad;
end;

function ReadHdr(var Time, USize, CSize: Longint; var AName: string): Boolean;
var
  N: Word;
  Bad: Boolean;
  P: PArjHdr;
  H: TArjBlock;
  K: Word;
  X: TArjTail;
  L: Word;
begin
  BlockRead(F, H, 4, N);
  Bad := (H.Size = 0) or (H.Sig <> ArjMagic2) or (N = 0) or Eof(F);
  if not Bad then
  begin
    GetMem(P, H.Size);
    BlockRead(F, P^, H.Size, N);
    Time := P^.Time;
    USize := P^.USize;
    CSize := P^.CSize;
    R.Crc := P^.Crc;
    R.Mode := P^.Mode;
    K := 0;
    AName := '';
    if P^.Flags and 8 <> 0 then K := 4;
    repeat
      AName := AName + Chr(P^.Name[K]);
      Inc(K);
    until (P^.Name[K] = 0) or (K = 255);
    FreeMem(P, H.Size);
    BlockRead(F, X, 6, N);
    L := X.ExtSize;
    if L > 0 then
    begin
      L := L + 4;
      Seek(F, FilePos(F) + L);
    end;
  end;
  ReadHdr := not Bad;
end;

procedure FixSlashes(var S: string);
var
  I: Byte;
begin
  for I := 1 to Length(S) do
    if S[I] = '/' then S[I] := '\';
end;

begin
  InitList(Name, Files, Count);
  I := 1;
  GetMem(ArcInfo, SizeOf(TArcInfoList));
  ArcLoaded := True;
  Assign(F, Name);
  GetFAttr(F, Attr);
  SetFAttr(F, 0);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  if FindMain then
    while not Eof(F) do
    begin
      if not ReadHdr(R.Time, R.USize, R.CSize, R.Name) then Break;
      FixSlashes(R.Name);
      FSplit(R.Name, D, Nm, E);
      if Nm <> '' then
      begin
        Inc(I);
        Inc(Count);
        GetMem(Files^[I], SizeOf(TFileEntry));
        GetMem(PArcInfoList(ArcInfo)^[I], SizeOf(TArcInfo));
        Files^[I]^.Marked := False;
        Files^[I]^.Flag17 := False;
        Files^[I]^.Attr := R.Mode;
        Files^[I]^.Name := LowerStr(Nm + E);
        FormatName(Files^[I]^.Name);
        if R.Mode and 2 <> 0 then
        begin
          Files^[I]^.Name[9] := #$B0;
          Files^[I]^.Name[1] := UpCaseC(Files^[I]^.Name[1]);
        end;
        if R.Mode and 1 <> 0 then Files^[I]^.Name[9] := #$F8;
        Files^[I]^.Size := R.USize;
        Files^[I]^.Time := R.Time;
        PArcInfoList(ArcInfo)^[I]^.Path := R.Name;
        PArcInfoList(ArcInfo)^[I]^.Size := R.USize;
        PArcInfoList(ArcInfo)^[I]^.PackedSize := R.CSize;
        PArcInfoList(ArcInfo)^[I]^.Extra := R.Crc;
        PArcInfoList(ArcInfo)^[I]^.Flags := R.Mode;
        Seek(F, FilePos(F) + R.CSize);
      end;
    end;
  Close(F);
  SetFAttr(F, Attr);
  InOutRes := 0;
end;

end.
