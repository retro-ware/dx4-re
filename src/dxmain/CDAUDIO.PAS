{$O+,F+,G+,S-,I-,X+,V-}
unit CDAudio;
{ Audio CD control through MSCDEX (int 2Fh, AX=15xxh device driver requests) }

interface

type
  Str5 = string[5];

const
  CDStatus: Word = 0;           { status word of the last device request }
  CDDrives: Byte = 0;
  CDFound: Boolean = False;
  CDOk: Boolean = False;
  TocOk: Boolean = False;

var
  CDDrive: Byte;
  CDLength: Longint;
  LoTrack, HiTrack, CurTrack: Byte;
  TrackStart: array[0..99] of Longint;

procedure CDInit;
function MSF(Min, Sec, Frm: Longint): Longint;
procedure CDTrackTime(L: Longint; var Min, Sec, Frm: Longint);
procedure CDDiskInfo(var Lo, Hi: Byte; var LeadOut: Longint);
procedure CDPlay(Start, Len: Longint);
function CDHeadPos(Mode: Byte): Longint;
function CDDevStatus: Longint;
procedure CDGetInfo(var Track, Min, Sec, Frm, Zero, AMin, ASec, AFrm: Byte);
function CDPosition: Longint;
procedure CDVersion(var Major, Minor: Byte);
procedure CDUpdate;
function CDReadTOC: Boolean;
procedure CDPlayTrack(T: Byte);
procedure CDNextTrack;
procedure CDPrevTrack;
procedure CDStop;
procedure CDPause;
procedure CDResume;
function CDDiscIn: Boolean;
function CDBusy: Boolean;
function CDIsPaused: Boolean;
function MinSecStr(Min, Sec: Longint): Str5;

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, Dialogs, Status;

type
  TRedBook = record
    F, S, M, X: Byte;
  end;
  TIOReq = record
    Len, SubUnit, Cmd: Byte;
    Status: Word;
    Reserved: array[1..8] of Byte;
    Media: Byte;
    Buf: Pointer;
    Count: Word;
    Start: Word;
    Vol: Longint;
  end;
  TShortReq = record
    Len, SubUnit, Cmd: Byte;
    Status: Word;
    Reserved: array[1..8] of Byte;
  end;
  TPlayReq = record
    Len, SubUnit, Cmd: Byte;
    Status: Word;
    Reserved: array[1..8] of Byte;
    Mode: Byte;
    Start, Count: Longint;
  end;

function MinSecStr(Min, Sec: Longint): Str5;
var
  S, T: string[5];
begin
  Str(Min, S);
  if Min < 10 then S := '0' + S;
  T := S;
  Str(Sec, S);
  if Sec < 10 then S := '0' + S;
  MinSecStr := T + ':' + S;
end;

function MSF(Min, Sec, Frm: Longint): Longint;
begin
  MSF := Min * 4500 + Sec * 75 + Frm;
end;

procedure CDTrackTime(L: Longint; var Min, Sec, Frm: Longint);
begin
  Frm := L mod 75;
  L := L div 75;
  Sec := L mod 60;
  Min := L div 60;
end;

procedure IOCtlIn(Buf: Pointer; Len: Word);
var
  PSeg, POfs: Word;
  Req: TIOReq;
begin
  FillChar(Req, $1A, 0);
  Req.Len := $1A;
  Req.Cmd := 3;
  Req.Buf := Buf;
  Req.Count := Len;
  Req.Start := 0;
  Req.Vol := 0;
  POfs := Ofs(Req);
  PSeg := Seg(Req);
  asm
    xor ch, ch
    mov cl, CDDrive
    mov ax, PSeg
    mov es, ax
    mov bx, POfs
    mov ax, $1510
    int $2F
  end;
  CDStatus := Req.Status;
end;

procedure CDDiskInfo(var Lo, Hi: Byte; var LeadOut: Longint);
var
  R: record
    Code, Lo, Hi: Byte;
    Lead: Longint;
  end;
begin
  R.Code := 10;
  IOCtlIn(@R, 7);
  Lo := R.Lo;
  Hi := R.Hi;
  LeadOut := R.Lead;
end;

procedure TrackInfo(T: Byte; var Start: Longint; var Ctrl: Byte);
var
  R: record
    Code, Track: Byte;
    Start: Longint;
    Ctrl: Byte;
  end;
begin
  R.Code := 11;
  R.Track := T;
  IOCtlIn(@R, 7);
  Start := R.Start;
  Ctrl := R.Ctrl;
end;

function MediaChanged: Byte;
var
  R: record
    Code, Val: Byte;
  end;
begin
  R.Code := 9;
  IOCtlIn(@R, 2);
  MediaChanged := R.Val;
end;

procedure AudioStatus(var Flags: Word; var Start, Stop: Longint);
var
  R: record
    Code: Byte;
    Flags: Word;
    Start, Stop: Longint;
  end;
begin
  if CDOk then
  begin
    R.Code := 15;
    IOCtlIn(@R, 11);
    Flags := R.Flags;
    Start := R.Start;
    Stop := R.Stop;
  end;
end;

procedure StopAudio;
var
  Req: TShortReq;
  PSeg, POfs: Word;
begin
  if CDOk then
  begin
    Req.Len := 13;
    Req.Cmd := $85;
    POfs := Ofs(Req);
  PSeg := Seg(Req);
    asm
      xor ch, ch
      mov cl, CDDrive
      mov ax, PSeg
      mov es, ax
      mov bx, POfs
      mov ax, $1510
      int $2F
    end;
    CDStatus := Req.Status;
  end;
end;

procedure CDPlay(Start, Len: Longint);
var
  Req: TPlayReq;
  PSeg, POfs: Word;
begin
  FillChar(Req, $16, 0);
  Req.Len := $16;
  Req.Cmd := $84;
  Req.Mode := 0;
  Req.Start := Start;
  Req.Count := Len;
  POfs := Ofs(Req);
  PSeg := Seg(Req);
  asm
    xor ch, ch
    mov cl, CDDrive
    mov ax, PSeg
    mov es, ax
    mov bx, POfs
    mov ax, $1510
    int $2F
  end;
  CDStatus := Req.Status;
end;

function CDHeadPos(Mode: Byte): Longint;
var
  R: record
    Code, Mode: Byte;
    Loc: Longint;
  end;
begin
  R.Code := 1;
  R.Mode := Mode;
  IOCtlIn(@R, 6);
  CDHeadPos := R.Loc;
end;

function CDDevStatus: Longint;
var
  R: record
    Code: Byte;
    St: Longint;
  end;
begin
  R.Code := 6;
  IOCtlIn(@R, 5);
  CDDevStatus := R.St;
end;

procedure CDGetInfo(var Track, Min, Sec, Frm, Zero, AMin, ASec, AFrm: Byte);
var
  R: record
    Code, Adr, Track, Index, Min, Sec, Frm, Zero, AMin, ASec, AFrm: Byte;
  end;
  T: Byte;
begin
  R.Code := 12;
  R.Adr := 1;
  R.Index := 0;
  IOCtlIn(@R, 11);
  T := (R.Track and $0F) + ((R.Track and $F0) shr 4) * 10;
  Track := T;
  Min := R.Min;
  Sec := R.Sec;
  Frm := R.Frm;
  Zero := R.Zero;
  AMin := R.AMin;
  ASec := R.ASec;
  AFrm := R.AFrm;
end;

procedure TrackRange(T: Byte; var Start, Len, Rest: Longint); forward;

function CDPosition: Longint;
var
  A, B, C: Longint;
  T, B2, B3, B4, B5, B6, B7, B8: Byte;
begin
  if not TocOk then CDReadTOC;
  if TocOk and CDDiscIn and CDOk then
  begin
    CDGetInfo(T, B2, B3, B4, B5, B6, B7, B8);
    if T < 1 then
    begin
      CDPosition := TrackStart[2] - TrackStart[1];
      CurTrack := 1;
      Exit;
    end;
    if T > HiTrack then
    begin
      CDPosition := TrackStart[HiTrack + 1] - TrackStart[HiTrack];
      CurTrack := HiTrack;
      Exit;
    end;
    TrackRange(T, A, B, C);
    CDPosition := B - MSF(B2, B3, B4);
    CurTrack := T;
  end
  else
    CDPosition := 0;
end;

procedure CDVersion(var Major, Minor: Byte);
var
  Hi, Lo: Byte;
begin
  asm
    mov ax, $150C
    int $2F
    mov Hi, bh
    mov Lo, bl
  end;
  Major := Hi;
  Minor := Lo;
end;

function CDCount(var Letter: Byte): Byte;
var
  N, L: Byte;
begin
  asm
    mov ax, $1500
    xor bx, bx
    xor cx, cx
    int $2F
    mov N, bl
    mov L, cl
  end;
  CDCount := N;
  Letter := L;
end;

procedure TrackRange(T: Byte; var Start, Len, Rest: Longint);
var
  S, L: Longint;
begin
  S := 0;
  Len := 0;
  Rest := 0;
  if TocOk and CDDiscIn and CDOk then
  begin
    S := TrackStart[T] - 150;
    if T < HiTrack then
      L := TrackStart[T + 1] - S - 150
    else
      L := CDLength - S - 150;
    Rest := CDLength - S - 150;
  end;
  Start := S;
  Len := L;
end;

procedure CDUpdate;
var
  W: Word;
begin
  W := CDDevStatus;
  CDOk := True;
end;

function CDReadTOC: Boolean;
var
  Changed, Lo, Hi, I, Ctrl: Byte;
  Start, Lead: Longint;
  W1, K, W2: Word;
begin
  Changed := MediaChanged;
  CDReadTOC := True;
  OpenDialog;
  if not CDDiscIn then
  begin
    Frame(13, 7, 55, 8, 11, 3, 0, 1);
    WriteCenterXYFB(1, 2, 55, 14, 3, 'Lese CD-Inhaltsverzeichnis!');
    WriteCenterXYFB(1, 4, 55, 0, 3, 'Bitte CD einlegen und warten...');
    WriteCenterXYFB(1, 6, 55, 4, 3, 'Abbruch mit Esc oder rechter Maustaste!');
  end;
  MouseShow;
  ArrowCursor;
  while not CDDiscIn do
  begin
    GetKey(K);
    if (K = 27) or (MouseButton = 2) then
    begin
      CDReadTOC := False;
      CloseDialog;
      NormalCursor;
      Exit;
    end;
  end;
  CDUpdate;
  for K := 0 to 49 do TrackStart[K] := 0;
  if (CDStatus and $8000 = 0) and CDOk then
  begin
    CDDiskInfo(Lo, Hi, Lead);
    if CDStatus and $8000 = 0 then
    begin
      CDLength := MSF(TRedBook(Lead).M, TRedBook(Lead).S, TRedBook(Lead).F);
      LoTrack := Lo;
      HiTrack := Hi;
      TocOk := True;
      for I := Lo to Hi do
      begin
        TrackInfo(I, Start, Ctrl);
        TrackStart[I] := MSF(TRedBook(Start).M, TRedBook(Start).S, TRedBook(Start).F);
      end;
    end
    else
      CDReadTOC := False;
  end
  else
    CDReadTOC := False;
  TrackStart[HiTrack + 1] := CDLength;
  CloseDialog;
  NormalCursor;
end;

procedure CDNextTrack;
begin
  if TocOk and (MediaChanged = 1) and CDOk then
    if HiTrack > CurTrack then
      CDPlayTrack(CurTrack + 1)
    else
      CDPlayTrack(LoTrack);
end;

procedure CDPrevTrack;
begin
  if TocOk and (MediaChanged = 1) and CDOk then
    if LoTrack < CurTrack then
      CDPlayTrack(CurTrack - 1)
    else
      CDPlayTrack(HiTrack);
end;

procedure CDPlayTrack(T: Byte);
var
  S, A, B, C: Longint;
begin
  S := CDDevStatus;
  if S and $800 = 0 then
  begin
    if not TocOk or not CDDiscIn then CDReadTOC;
    if (T >= LoTrack) and (T <= HiTrack) and CDOk then
    begin
      S := CDDevStatus;
      if CDStatus and $200 = $200 then CDPause;
      TrackRange(T, A, B, C);
      if CDStatus and $8000 = 0 then
      begin
        CDPlay(A, C);
        CurTrack := T;
      end;
    end;
  end;
end;

procedure CDStop;
var
  Flags: Word;
  S1, S2: Longint;
begin
  if CDOk then
  begin
    StopAudio;
    AudioStatus(Flags, S1, S2);
    if Flags and 1 = 1 then StopAudio;
  end;
end;

procedure CDPause;
var
  Flags: Word;
  S1, S2: Longint;
begin
  if CDOk then
  begin
    AudioStatus(Flags, S1, S2);
    if Flags and 1 = 0 then StopAudio;
  end;
end;

procedure CDResume;
var
  Req: TShortReq;
  Flags: Word;
  PSeg, POfs: Word;
  S1, S2: Longint;
begin
  if CDOk then
  begin
    AudioStatus(Flags, S1, S2);
    if Flags and 1 = 1 then
    begin
      Req.Len := 13;
      Req.Cmd := $88;
      POfs := Ofs(Req);
  PSeg := Seg(Req);
      asm
        xor ch, ch
        mov cl, CDDrive
        mov ax, PSeg
        mov es, ax
        mov bx, POfs
        mov ax, $1510
        int $2F
      end;
      CDStatus := Req.Status;
    end;
  end;
end;

function CDDiscIn: Boolean;
var
  W: Word;
begin
  W := CDDevStatus;
  CDDiscIn := W and $800 = 0;
end;

function CDBusy: Boolean;
var
  W: Word;
begin
  W := CDDevStatus;
  CDBusy := CDStatus and $200 <> 0;
end;

function CDIsPaused: Boolean;
var
  Flags: Word;
  S1, S2: Longint;
begin
  AudioStatus(Flags, S1, S2);
  if Flags and 1 = 1 then CDIsPaused := True else CDIsPaused := False;
end;

procedure CDInit;
begin
  LoTrack := 1;
  HiTrack := 1;
  CDLength := 1;
  CurTrack := 1;
  CDDrives := CDCount(CDDrive);
  if CDDrives > 0 then CDFound := True;
end;

end.
