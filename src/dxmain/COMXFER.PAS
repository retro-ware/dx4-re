{$O+,F+,G+,S-,I-,X+,V-}
unit ComXfer;
{ Overlay 032b: send/receive files over a serial (COM) link }

interface

uses DXGlob;

type
  PPanel = ^TPanel;

procedure SendFiles(P: PPanel);
procedure ReceiveFiles;

implementation

uses Dos, Crt, Buttons, Mouse, Screen, Windows, Status, Dialogs, ScrSave, Ports, U0365;

type
  PFileRec = ^TFileRec;
  TFileRec = record
    Name: string[12];
    Fill: array[13..20] of Byte;
    Attr: Byte;
    Sel: Boolean;
  end;
  TPanelFiles = array[0..$400] of PFileRec;
  PDirRec = ^TDirRec;
  TDirRec = record
    Path: string[80];
    Names: PNameArr;
    Count: Byte;
    Subs: array[1..255] of PDirRec;
  end;
  THeader = record
    Size: Longint;
    Attr: Word;
    Time: Longint;
    Name: string[80];
  end;
  Str80 = string[80];
  Str79 = string[79];

var
  Err: Byte;
  ComBase: Word;
  Abort: Boolean;

function SendFile(Name: Str80): Boolean; forward;

procedure InitDirRec(Path: string; var D: TDirRec);
begin
  if MaxAvail < $207B then
    Err := Err or 1
  else
  begin
    D.Path := Path;
    GetMem(D.Names, SizeOf(TNameArr));
    D.Count := 0;
  end;
end;

procedure AddFile(Name: Str80; var D: TDirRec);
begin
  if Err <> 0 then Exit;
  if not SendFile(Name) then Err := Err or 4;
end;

procedure ScanFiles(var D: TDirRec);
var
  SR: SearchRec;
begin
  SR.Name := '*.*';
  FindFirst(D.Path, $37, SR);
  if SR.Name = '.' then FindNext(SR);
  if SR.Name = '..' then FindNext(SR);
  if DosError = 18 then Exit;
  if DosError <> 0 then
  begin
    Err := Err or 8;
    Exit;
  end;
  repeat
    if SR.Attr and Directory <> 0 then
    begin
      Inc(D.Count);
      if D.Count >= 255 then
      begin
        Err := Err or 2;
        Exit;
      end;
      D.Names^[D.Count] := SR.Name;
    end;
    AddFile(Copy(D.Path, 1, Length(D.Path) - 3) + SR.Name, D);
    FindNext(SR);
  until DosError <> 0;
end;

procedure FreeNames(var D: TDirRec);
begin
  FreeMem(D.Names, SizeOf(TNameArr));
end;

procedure SendTree(var P: PDirRec; Path: string);
var
  I: Integer;
  Key: Word;
begin
  if Abort then Exit;
  if GetKey(Key) and (Key = 27) then
  begin
    Abort := True;
    Exit;
  end;
  if (MaxAvail < $17DA) or (Err <> 0) then
  begin
    Err := Err or 1;
    Exit;
  end;
  GetMem(P, SizeOf(TDirRec));
  InitDirRec(Path + '\*.*', P^);
  if Err <> 0 then Exit;
  ScanFiles(P^);
  for I := 1 to P^.Count do
    SendTree(P^.Subs[I], Path + '\' + P^.Names^[I]);
  FreeNames(P^);
  FreeMem(P, SizeOf(TDirRec));
end;

function SendByte(var B: Byte): Boolean;
var
  K: Word;
  R: Byte;
begin
  Port[ComBase] := B;
  K := 0;
  while (Port[ComBase + 5] and 1 = 0) and (K <> 27) do GetKey(K);
  R := Port[ComBase];
  SendByte := R = B;
  B := R;
end;

procedure ShowPorts;
begin
  MouseHide;
  WriteXY(16, 3, ' [ ] COM1 ');
  WriteXY(16, 4, ' [ ] COM2 ');
  WriteXY(16, 5, ' [ ] COM3 ');
  WriteXY(16, 6, ' [ ] COM4 ');
  case RunMode of
    1: WriteXYFB(16, 3, 0, 2, ' [X] COM1 ');
    2: WriteXYFB(16, 4, 0, 2, ' [X] COM2 ');
    3: WriteXYFB(16, 5, 0, 2, ' [X] COM3 ');
    4: WriteXYFB(16, 6, 0, 2, ' [X] COM4 ');
  end;
  MouseShow;
  WaitRelease;
end;

function SendFile(Name: Str80): Boolean;
var
  Stop, I, Cnt, Attr: Word;
  F: File;
  S: string;
  B1, Y: Byte;
  U, Sent: Longint;
  Hdr: THeader;
  HB: array[1..91] of Byte absolute Hdr;
  Buf: array[1..$1000] of Byte;

  function Sync: Byte;
  var
    K: Word;

    function WaitByte(C: Byte): Boolean;
    var
      X: Byte;
    begin
      Port[ComBase] := C;
      while (Port[ComBase + 5] and 1 = 0) and (K <> 27) do
      begin
        GetKey(K);
        if IsCancel(K) or MouseOutside(10, 72, 6, 17) then K := 27;
      end;
      X := Port[ComBase];
      WaitByte := X = C;
      if K = 27 then WaitByte := True;
    end;

  begin
    K := Port[ComBase];
    while Port[ComBase + 5] and 1 <> 0 do K := Port[ComBase];
    K := 0;
    Sync := 0;
    WaitByte($41);
    if (K <> 27) and (K <> 1) then
      if not WaitByte($44) then K := 1;
    if (K <> 27) and (K <> 1) then
      if not WaitByte($58) then K := 1;
    if (K <> 27) and (K <> 1) then
      if not WaitByte($34) then K := 1;
    if (K <> 27) and (K <> 1) then
      if not WaitByte($30) then K := 1;
    if K = 27 then Sync := 2
    else if K = 1 then Sync := 1;
  end;

begin
  Assign(F, Name);
  SendFile := False;
  Attr := 0;
  GetFAttr(F, Attr);
  if Attr and $10 = 0 then Reset(F, 1);
  if (DosError <> 0) or (IOResult <> 0) then
  begin
    GB90 := 0;
    ErrorBox('Konnte die Datei nicht '#$94'ffnen!', Name);
    Exit;
  end;
  Hdr.Name := Name;
  Hdr.Size := 0;
  if Attr and $10 = 0 then
  begin
    Hdr.Size := FileSize(F);
    GB90 := 0;
  end;
  GetFTime(F, Hdr.Time);
  Hdr.Attr := Attr;
  MouseHide;
  ClrScr;
  {$I+}
  Write('  Senden der Datei: ');
  TextColor(14);
  Writeln(Hdr.Name);
  TextColor(0);
  Write('             Gr'#$94#$E1'e: ');
  TextColor(14);
  Write(Hdr.Size);
  TextColor(0);
  Writeln(' Bytes');
  Write('             Dauer: ca. ');
  TextColor(14);
  if Hdr.Size div 9600 = 0 then Write('1')
  else Write(Hdr.Size div 9600);
  TextColor(0);
  Writeln(' Sek.');
  Writeln;
  {$I-}
  WriteCenterXY(1, 5, 61, 'Warte auf den Empf'#$84'nger...');
  MouseShow;
  I := Sync;
  if I = 1 then
  begin
    ErrorBox('Synchronisation gescheitert!', 'Versuchen Sie es erneut.');
    Close(F);
    GB90 := 0;
    Exit;
  end;
  if I = 2 then
  begin
    SendFile := False;
    Close(F);
    GB90 := 0;
    Exit;
  end;
  I := 0;
  repeat
    Inc(I);
    if not SendByte(HB[I]) then
    begin
      ErrorBox('Synchronisation gescheitert! ', 'Starten Sie zuerst den Empf'#$84'nger.');
      Exit;
    end;
  until I >= $5B;
  Y := $AA;
  if not SendByte(Y) then
  begin
    MouseHide;
    WriteCenterXY(1, 5, 61, ' Datei ist vorhanden! Es wird nach '#$9A'berschreiben gefragt...');
    MouseShow;
  end;
  if Attr and $10 <> 0 then
  begin
    SendFile := True;
    Exit;
  end;
  Sent := 0;
  Stop := 0;
  MouseHide;
  InputFrame(3, 9, 57, 11, 6);
  GB44 := 57;
  MouseShow;
  ArrowCursor;
  repeat
    BlockRead(F, Buf, $1000, Cnt);
    I := 1;
    repeat
      if Odd(Sent) then
      begin
        while (Stop = 0) and (Port[ComBase + 6] and $10 <> 0) do
        begin
          if Port[$60] = 1 then Stop := 27;
          if Port[ComBase + 6] and $20 <> 0 then Stop := 1;
        end;
      end
      else
      begin
        while (Stop = 0) and (Port[ComBase + 6] and $10 = 0) do
        begin
          if Port[$60] = 1 then Stop := 27;
          if Port[ComBase + 6] and $20 <> 0 then Stop := 1;
        end;
      end;
      Port[ComBase] := Buf[I];
      Inc(Sent);
      Inc(I);
      while Port[ComBase + 5] and $60 = 0 do ;
    until (I > Cnt) or (Stop <> 0);
    MouseHide;
    GotoXY(26, 7);
    Write(Sent, ' Bytes');
    if Hdr.Size > 0 then ShowBar(14, Round(Sent / Hdr.Size * 100), 3, 9);
    MouseShow;
  until Eof(F) or (Stop <> 0);
  Close(F);
  GB90 := 0;
  NormalCursor;
  SendFile := True;
  if Stop <> 0 then
  begin
    if Stop = 1 then ErrorBox('Abbruch durch den Empf'#$84'nger!', '');
    Port[ComBase + 4] := Port[ComBase + 4] or 2;
    SendFile := False;
  end;
end;

procedure SendFiles(P: PPanel);
var
  Key: Word;
  Hit1, Hit2: Boolean;
  B2: TButton2;
  I: Word;
  Name: string;
  PortNo: Byte;
  Unk: array[1..$5A] of Byte;
  S2: string[2];
  D: PDirRec;
  Marked: Boolean;
begin
  if (RunMode < 1) or (RunMode > 4) then RunMode := 2;
  Name := P0365_91(P^);
  Marked := False;
  if (P^.W1252 = 0) and (Name = '..') then
  begin
    for I := 2 to P^.W1007 do
    begin
      Inc(P^.W1252);
      TPanelFiles(P^.Data)[I]^.Sel := True;
      Marked := True;
    end;
    P0365_41FB(P^);
  end;
  OpenDialog;
  Frame(20, 6, 40, 10, 11, 6, 0, 1);
  Frame(30, 8, 20, 4, 11, 6, 0, 0);
  Window(21, 7, 80, 25);
  if (P^.W1252 = 0) and (Name = '..') then
    for I := 1 to P^.W1007 do
    begin
      Inc(P^.W1252);
      TPanelFiles(P^.Data)[I]^.Sel := True;
    end;
  if Integer(P^.W1252) > 0 then
  begin
    Str(Integer(P^.W1252), Name);
    Name := Name + ' Dateien';
  end;
  WriteCenterXY(1, 1, 40, 'Senden von ' + Name + ' nach:');
  ShowPorts;
  InitButton2(True, 3, 8, 22, 8, 14, 0, 11, 6, '   Senden    ', '   Abbruch   ', B2);
  MouseShow;
  repeat
    HandleButton2(Hit1, Hit2, Key, B2);
    if MouseOn(9, 36, 45) then
    begin
      RunMode := 1;
      ShowPorts;
    end;
    if MouseOn(10, 36, 45) then
    begin
      RunMode := 2;
      ShowPorts;
    end;
    if MouseOn(11, 36, 45) then
    begin
      RunMode := 3;
      ShowPorts;
    end;
    if MouseOn(12, 36, 45) then
    begin
      RunMode := 4;
      ShowPorts;
    end;
    if Key = $438 then
    begin
      Inc(RunMode);
      if RunMode > 4 then RunMode := 1;
      ShowPorts;
    end;
    if Key = $430 then
    begin
      Dec(RunMode);
      if RunMode < 1 then RunMode := 4;
      ShowPorts;
    end;
    if IsCancel(Key) or MouseOutside(20, 61, 6, 17) then Hit2 := True;
    if Hit1 and not ComPresent(RunMode) then
    begin
      Str(RunMode, S2);
      ErrorBox('Konnte die Schnittstelle nicht finden!', 'COM' + S2 + ':');
      Hit1 := False;
    end;
  until Hit1 or Hit2;
  if Hit2 then
  begin
    CloseDialog;
    if Marked then
    begin
      for I := 2 to P^.W1007 do TPanelFiles(P^.Data)[I]^.Sel := False;
      P^.W1252 := 0;
    end;
  end
  else
  begin
    MouseHide;
    Frame(10, 6, 61, 10, 11, 6, 0, 1);
    MouseShow;
    case RunMode of
      1: PortNo := 0;
      2: PortNo := 2;
      3: PortNo := 4;
      4: PortNo := 6;
    end;
    SetComPort(PortNo, 115200, 'n', 8, 1);
    ComBase := MemW[$40:PortNo];
    Port[ComBase + 3] := Port[ComBase + 3] and $7F;
    I := Port[ComBase + 6];
    Port[ComBase + 4] := Port[ComBase + 4] and $FC;
    Abort := False;
    Err := 0;
    if (P^.W1252 = 0) and not P0365_BF(P^) then
      SendFile(P0365_91(P^))
    else if (P^.W1252 = 0) and P0365_BF(P^) then
    begin
      if SendFile(P0365_91(P^)) then SendTree(D, P0365_91(P^));
    end
    else
      for I := 1 to P^.W1007 do
        if TPanelFiles(P^.Data)[I]^.Sel then
        begin
          if not SendFile(P0365_3C(I, P^)) then Break;
          TPanelFiles(P^.Data)[I]^.Sel := False;
          Dec(P^.W1252);
          if TPanelFiles(P^.Data)[I]^.Attr and $10 <> 0 then SendTree(D, P0365_3C(I, P^));
        end;
    CloseDialog;
    repeat
    until not Status.GetKey(Key);
  end;
end;

procedure ReceiveFiles;
label
  NextFile, Done;
var
  H1, H2: Boolean;
  B2: TButton2;
  S: string;
  Key, N, Cnt: Word;
  B323, RC, PortNo: Byte;
  F: File;
  Hdr: THeader;
  HB: array[1..91] of Byte absolute Hdr;
  Recvd, Written: Longint;
  Buf: array[1..$1000] of Byte;
  SyncS: string[4];

  function AskOverwrite(S1, S2: Str79): Boolean;
  var
    B2: TButton2;
    H1, H2: Boolean;
    Key: Word;
  begin
    OpenDialog;
    Frame(13, 7, 55, 8, 15, 5, 0, 1);
    WriteCenterXYF(1, 1, 55, 0, S1);
    WriteCenterXYF(1, 3, 55, 14, S2);
    InitButton2(True, 3, 6, 31, 6, 14, 0, 15, 5, '    '#$9A'berschreiben    ', '     Abbrechen     ', B2);
    MouseShow;
    repeat
      HandleButton2(H1, H2, Key, B2);
      if IsCancel(Key) then H2 := True;
      if Port[ComBase + 6] and $10 <> 0 then H2 := True;
    until H1 or H2;
    CloseDialog;
    if Port[ComBase + 6] and $10 <> 0 then ErrorBox('Der Sender hat abgebrochen!', '');
    AskOverwrite := H1;
  end;

  procedure ShowStatus(S: Str80);
  begin
    MouseHide;
    GotoXY(1, 10);
    ClrEol;
    {$I+}
    Write(' Status: ' + S);
    {$I-}
    MouseShow;
  end;

begin
  if (RunMode < 1) or (RunMode > 4) then RunMode := 2;
  OpenDialog;
  Frame(20, 6, 40, 10, 11, 6, 0, 1);
  Frame(30, 8, 20, 4, 11, 6, 0, 0);
  Window(21, 7, 80, 25);
  ShowPorts;
  WriteXYF(11, 1, 14, 'Empfange Dateien von:');
  InitButton2(True, 3, 8, 22, 8, 14, 0, 11, 6, '  Empfangen  ', '   Abbruch   ', B2);
  MouseShow;
  repeat
    HandleButton2(H1, H2, Key, B2);
    if LoCaseW(Key) = 'e' then H1 := True;
    if LoCaseW(Key) = 'a' then H2 := True;
    if MouseOn(9, 36, 45) then
    begin
      RunMode := 1;
      ShowPorts;
    end;
    if MouseOn(10, 36, 45) then
    begin
      RunMode := 2;
      ShowPorts;
    end;
    if MouseOn(11, 36, 45) then
    begin
      RunMode := 3;
      ShowPorts;
    end;
    if MouseOn(12, 36, 45) then
    begin
      RunMode := 4;
      ShowPorts;
    end;
    if Key = $438 then
    begin
      Inc(RunMode);
      if RunMode > 4 then RunMode := 1;
      ShowPorts;
    end;
    if Key = $430 then
    begin
      Dec(RunMode);
      if RunMode < 1 then RunMode := 4;
      ShowPorts;
    end;
    if IsCancel(Key) or MouseOutside(20, 61, 6, 17) then H2 := True;
    if H1 and not ComPresent(RunMode) then
    begin
      Str(RunMode, S);
      ErrorBox('Konnte die Schnittstelle nicht finden!', 'COM' + S + ':');
      H1 := False;
    end;
  until H1 or H2;
  if H2 then
  begin
    CloseDialog;
    Exit;
  end;
  MouseHide;
  Frame(10, 6, 61, 10, 11, 6, 0, 1);
  WriteXY(1, 9, FillStr(#$C4, 61));
  MouseShow;
  case RunMode of
    1: PortNo := 0;
    2: PortNo := 2;
    3: PortNo := 4;
    4: PortNo := 6;
  end;
  ComBase := MemW[$40:PortNo];
  SetComPort(PortNo, 115200, 'n', 8, 1);
  Port[ComBase + 3] := Port[ComBase + 3] and $7F;
NextFile:
  Port[ComBase + 4] := Port[ComBase + 4] and $FC;
  N := Port[ComBase + 6];
  SyncS := '';
  MouseHide;
  WriteXY(3, 2, '  Name : ');
  ClrEol;
  {$I+}
  Writeln;
  {$I-}
  WriteXY(3, 3, '  Gr'#$94#$E1'e: ');
  ClrEol;
  InputFrame(3, 7, 57, 11, 6);
  GB44 := 57;
  WriteCenterXY(1, 5, 61, 'Warte auf Datei...');
  MouseShow;
  repeat
    if Port[ComBase + 5] and 1 <> 0 then
    begin
      RC := Port[ComBase];
      Insert(Chr(RC), SyncS, 1);
      Port[ComBase] := RC;
    end;
    GetKey(Key);
    if IsCancel(Key) or MouseOutside(10, 72, 6, 17) then Key := 27;
  until (SyncS = '04XD') or (Key = 27);
  if Key = 27 then
  begin
    CloseDialog;
    Exit;
  end;
  ShowStatus('Synchronisiert');
  N := 0;
  repeat
    if Port[ComBase + 5] and 1 <> 0 then
    begin
      Inc(N);
      RC := Port[ComBase];
      Port[ComBase] := RC;
      HB[N] := RC;
    end;
    GetKey(Key);
  until (Key = 27) or (N >= $5B);
  if Key = 27 then
  begin
    Port[ComBase] := $AA;
    CloseDialog;
    Exit;
  end;
  MouseHide;
  WriteXY(3, 2, '  Name : ');
  WriteF(14, Hdr.Name);
  {$I+}
  Writeln;
  {$I-}
  WriteXY(3, 3, '  Gr'#$94#$E1'e: ');
  TextColor(14);
  {$I+}
  Write(Hdr.Size);
  {$I-}
  TextColor(0);
  {$I+}
  Writeln(' Bytes');
  {$I-}
  MouseShow;
  ShowStatus('Header wurde empfangen');
  repeat
  until Port[ComBase + 5] and 1 <> 0;
  N := Port[ComBase];
  if FSearch(Hdr.Name, '') <> '' then
  begin
    ShowStatus('Datei war vorhanden');
    Port[ComBase] := 1;
    if not AskOverwrite('Die Datei ist bereits vorhanden!', Hdr.Name) then
    begin
      Port[ComBase + 4] := Port[ComBase + 4] or 1;
      Delay(300);
      goto NextFile;
    end;
    Assign(F, Hdr.Name);
    SetFAttr(F, 0);
    Erase(F);
    GB90 := 0;
  end
  else
    Port[ComBase] := $AA;
  if Hdr.Attr and $10 <> 0 then
  begin
    ShowStatus('Verzeichnis erzeugt');
    MkDir(Hdr.Name);
    GB90 := 0;
    goto NextFile;
  end;
  N := 0;
  Recvd := 0;
  Written := 0;
  MouseHide;
  InputFrame(3, 7, 57, 11, 6);
  GB44 := 57;
  GotoXY(20, 5);
  {$I+}
  Write('   ', Written: 9, ' Bytes   ');
  {$I-}
  MouseShow;
  Assign(F, Hdr.Name);
  Rewrite(F, 1);
  if IOResult <> 0 then ;
  Port[ComBase + 4] := Port[ComBase + 4] or 2;
  ArrowCursor;
  ShowStatus('Datei wird empfangen...');
  repeat
  asm
        CLI
@@1:    MOV     DX,ComBase
        ADD     DX,5
        IN      AL,DX
        TEST    AL,1
        JNZ     @@3
        MOV     DX,ComBase
        ADD     DX,6
        IN      AL,DX
        TEST    AL,10H
        JZ      @@2
        STI
        MOV     Key,1
        JMP     Done
@@2:    MOV     DX,60H
        IN      AL,DX
        CMP     AL,1
        JNE     @@1
        STI
        MOV     Key,27
        JMP     Done
@@3:    MOV     DX,ComBase
        IN      AL,DX
        MOV     RC,AL
        MOV     AL,BYTE PTR Recvd
        TEST    AL,1
        JZ      @@4
        MOV     DX,ComBase
        ADD     DX,4
        IN      AL,DX
        OR      AL,2
        OUT     DX,AL
        JMP     @@5
@@4:    MOV     DX,ComBase
        ADD     DX,4
        IN      AL,DX
        AND     AL,0FDH
        OUT     DX,AL
@@5:    STI
  end;
  Inc(N);
  Inc(Recvd);
  if Port[ComBase + 5] and $1E <> 0 then
  begin
    ShowStatus('Empfangsfehler!');
    ErrorBox('Es ist ein Empfangsfehler aufgetreten!', Hdr.Name);
  end;
  Buf[N] := RC;
  if N = $1000 then
  begin
    {$I+}
    BlockWrite(F, Buf, $1000, Cnt);
    {$I-}
    Inc(Written, Cnt);
    MouseHide;
    GotoXY(23, 5);
    {$I+}
    Write(Written: 9, ' Bytes');
    {$I-}
    if Hdr.Size > 0 then ShowBar(14, Round(Written / Hdr.Size * 100), 3, 7);
    MouseShow;
    N := 0;
    if Cnt <> $1000 then
    begin
      Port[ComBase + 4] := Port[ComBase + 4] or 1;
      ErrorBox('Nicht gen'#$81'gend Platz f'#$81'r diese Datei!', '');
      Key := 27;
      goto Done;
    end;
  end;
  until Recvd >= Hdr.Size;
  {$I+}
  BlockWrite(F, Buf, Hdr.Size - Written, Cnt);
  {$I-}
  if Cnt <> Hdr.Size - Written then
  begin
    Port[ComBase + 4] := Port[ComBase + 4] or 1;
    ErrorBox('Nicht gen'#$81'gend Platz f'#$81'r diese Datei!', '');
    Key := 27;
    goto Done;
  end;
  Written := Written + Cnt;
Done:
  NormalCursor;
  if Key = 1 then
    ShowStatus('Abbruch durch den Sender!')
  else if Key = 27 then
  begin
    Port[ComBase + 4] := Port[ComBase + 4] or 1;
    Delay(300);
  end
  else
    ShowStatus('Datei wurde '#$81'bertragen!');
  SetFTime(F, Hdr.Time);
  Close(F);
  SetFAttr(F, Hdr.Attr);
  if (Key = 1) or (Key = 27) then
  begin
    SetFAttr(F, 0);
    Erase(F);
  end;
  GB90 := 0;
  if Key <> 27 then goto NextFile;
  CloseDialog;
end;

end.
