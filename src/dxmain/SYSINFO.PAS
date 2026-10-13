{$O+,F+,G+,S-,I-,X+,V-}
unit SysInfo;

interface

uses Lists;

type
  TIntList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
  TXmsList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
  TXmsInfo = record
    Handle: Word;
    Locks: Byte;
    Size: Word;
    Addr: Longint;
  end;
  TXmsInfoList = array[0..255] of TXmsInfo;
  PXmsInfoList = ^TXmsInfoList;

procedure RunMem(Opt: Char);
procedure ShowInterrupts;
procedure MemoryInfo;
procedure KeyTest;
procedure PortInfo;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Palette, Screen, Windows, ScrSave, Dialogs, Status, Help, U1D10, U0DA0,
  U109E, U12C7, Ports, LongName;

const
  Blank = '                                                            ' +
    '                                                            ' +
    '                                                            ' +
    '                                                            ' +
    '               ';

var
  XmsList: PXmsInfoList;
  KbFlag1: Byte absolute $40:$17;
  KbFlag2: Byte absolute $40:$18;

procedure TIntList.DrawLine(Line: Integer);
var
  N, Sg, Ofs: Word;
begin
  N := Line + Top - 1;
  Sg := MemW[0:N * 4 + 2];
  Ofs := MemW[0:N * 4];
  MouseHide;
  WriteXY(1, Line, ' INT ' + HexByte(N) + ':  ' + HexWord(Sg) + ':' + HexWord(Ofs) + ' = ' + HexLong(Longint(Sg) * 16 + Ofs));
  WriteF(0, #$CE);
  MouseShow;
  LastRow := $FF;
end;

procedure TXmsList.DrawLine(Line: Integer);
var
  N: Word;
  Dummy: Longint;
begin
  N := Line + Top - 1;
  MouseHide;
  WriteXY(1, Line, ' ');
  if Line + Top <= Count then
  begin
    Write(N: 3, XmsList^[N].Handle: 9, XmsList^[N].Locks: 6, XmsList^[N].Size: 9, ' KB   ',
      HexLong(Longint(XmsList^[N].Size) * 1024), '  ', HexLong(XmsList^[N].Addr));
    if not SingleFrame then WriteF(0, #$CE);
    if N > 0 then WriteXY(22, Line, '+');
    if XmsList^[N].Handle = DxXmsHandle then WriteXY(6, Line, 'DX');
  end
  else
  begin
    Write(Copy(Blank, 1, Width - 2));
    if not SingleFrame then WriteF(0, #$CE);
  end;
  MouseShow;
  LastRow := $FF;
end;

procedure RunMem(Opt: Char);
var
  SaveTop: Pointer;
  F: file;
  TmpName: string[9];
begin
  if FSearch('mem.exe', GetEnv('PATH')) = '' then
    MsgBox('Das Programm mem.exe wurde nicht gefunden!', 'Es mu'#$E1' im Pfad vorhanden sein!')
  else
  begin
    OpenDialog;
    TmpName := 'dxmem.tmp';
    MouseShow;
    ArrowCursor;
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    Exec(GetEnv('COMSPEC'), '/c mem /' + Opt + '>' + TempDir + TmpName);
    SwapVectors;
    SetMemTop(SaveTop);
    NormalCursor;
    P12C7_2832(TempDir + TmpName, '');
    Assign(F, TempDir + TmpName);
    Erase(F);
    if IOResult <> 0 then;
    PopScreen(DlgStack);
  end;
end;

procedure ShowInterrupts;
var
  List: TIntList;
  Key: Word;
begin
  MouseHide;
  PushScreen(DlgStack);
  Frame(24, 6, 32, 15, 2, 5, 0, 1);
  List.Init(2, 5, 2, 0, 25, 7, 15, 256, 31, True);
  MouseShow;
  repeat
    List.Handle(Key);
    GetKey(Key);
  until IsCancel(Key) or MouseOutside(24, 57, 6, 22);
  List.Done;
  PopScreen(DlgStack);
  repeat until MouseButton = 0;
end;

procedure MemoryInfo;
var
  List: TXmsList;
  I: Word;
  Size: Word;
  XmsFree: Word;
  Total: Word;
  XmsLargest: Word;
  Locks: Byte;
  FreeHandles: Byte;
  Handles: Byte;
  N: Byte;
  B2: TButton2;
  B: TButton;
  XmsHit, Cancel, Hit: Boolean;
  S: string[80];
  EmsFree: Longint;
  EmsTotal: Longint;
  EmsAvail: Boolean;
  XmsAvail: Boolean;
begin
  N := 0;
  Total := 0;
  OpenDialog;
  Frame(16, 7, 48, 8, 11, 3, 0, 1);
  XmsAvail := GetXms(XmsFree, XmsLargest);
  Str(XmsFree, S);
  if XmsAvail then S := S + ' KB' else S := 'nicht vorhanden';
  EmsAvail := GetEms(EmsFree, EmsTotal);
  WriteXY(3, 2, 'Freier Extended-Memory (XMS): ' + S);
  if XmsAvail then
  begin
    Str(XmsLargest, S);
    S := S + ' KB';
    WriteXY(3, 3, 'Davon der gr'#$94#$E1'te Block (XMS): ' + S);
  end;
  Str(EmsFree, S);
  if EmsAvail then S := S + ' KB' else S := 'nicht vorhanden';
  WriteXY(3, 4, 'Freier Expanded-Memory (EMS): ' + S);
  InitButton2(True, 3, 6, 26, 6, 14, 0, 11, 3, '   XMS-Details   ', '     Abbruch     ', B2);
  MouseShow;
  repeat
    HandleButton2(XmsHit, Cancel, I, B2);
    if I = $423 then ShowHelp(12);
    if LoCaseW(I) = 'x' then XmsHit := True;
    if LoCaseW(I) = 'a' then Cancel := True;
    if IsCancel(I) or MouseOutside(16, 65, 7, 16) then Cancel := True;
  until XmsHit or Cancel;
  CloseDialog;
  if not XmsPresent then Exit;
  if Cancel then Exit;
  OpenDialog;
  Frame(24, 6, 31, 7, 11, 3, 0, 1);
  WriteCenterXY(1, 2, 31, 'Extended Memory wird');
  WriteCenterXY(1, 4, 31, 'untersucht');
  WriteCenterXY(1, 6, 31, 'Moment noch ...');
  MouseShow;
  ArrowCursor;
  GetMem(XmsList, SizeOf(TXmsInfoList));
  for I := 0 to 65535 do
    if XmsInfo(I, Locks, FreeHandles, Size) then
    begin
      XmsList^[N].Handle := I;
      XmsList^[N].Locks := Locks;
      XmsList^[N].Size := Size;
      Total := Total + Size;
      Handles := FreeHandles;
      if XmsLock(I, XmsList^[N].Addr) then XmsUnlock(I);
      Inc(N);
    end;
  MouseHide;
  NormalCursor;
  Frame(13, 6, 54, 15, 11, 6, 0, 1);
  WriteXYF(3, 1, 14, 'Nr.   Handle  Lo' +
      'cks    Gr'#$94#$E1'e  = ' +
      '  Hex     Adress' +
      'e');
  WriteXYF(1, 2, 0, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4);
  List.Init(11, 6, 11, 0, 14, 9, 7, N, 53, True);
  WriteXYF(1, 8, 0, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4);
  WriteXYF(16, 9, 0, 'Summe =');
  {$I+}
  Write(Total: 6, ' KB');
  {$I-}
  WriteXYF(36, 9, 0, #$B3);
  WriteXYF(36, 10, 0, #$B3);
  WriteXYF(36, 12, 0, #$B3);
  WriteXYF(36, 13, 0, #$B3);
  WriteXYF(36, 14, 0, #$C1);
  WriteXYF(2, 10, 0, 'Freier XMS-Speicher +');
  {$I+}
  Write(XmsFree: 6, ' KB');
  {$I-}
  WriteXYF(1, 11, 0, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$B4);
  WriteXYF(2, 12, 0, 'Gesamt XMS-Speicher =');
  {$I+}
  Write(XmsFree + Total: 6, ' KB');
  {$I-}
  WriteXYF(2, 13, 0, 'Noch freie Handles  =');
  {$I+}
  Write(Handles: 6);
  {$I-}
  InitButton(True, 40, 10, 14, 0, 11, 6, '   OK   ', B);
  MouseShow;
  repeat
    List.Handle(I);
    Hit := Buttons.MouseButton(B);
    GetKey(I);
    if I = $423 then ShowHelp(12);
  until IsCancel(I) or MouseOutside(13, 68, 6, 22) or Hit or (I = 13);
  List.Done;
  FreeMem(XmsList, SizeOf(TXmsInfoList));
  CloseDialog;
end;

procedure KeyTest;
var
  Scan, Ascii: Byte;
  S: string;
  Old17, Old18: Byte;
  I: Byte;
  W: TWinState;

function ReadKey(var Scan, Ascii: Byte; var S: string): Boolean;
var
  R: Registers;
  Avail: Boolean;
  Got: Boolean;
begin
  S := 'nein';
  Got := False;
  Ascii := 0;
  R.AH := 1;
  Intr($16, R);
  Avail := R.Flags and $40 <= 0;
  if Avail then
  begin
    Got := True;
    R.AH := 0;
    Intr($16, R);
    Ascii := R.AL;
    Scan := R.AH;
    if Ascii = 0 then S := 'ja ';
  end;
  ReadKey := Got;
end;

procedure ShowFlags;
begin
  SaveWin(W);
  MouseHide;
  WriteXYF(50, 17, 0, 'Statusflag 0040h:0017h');
  WriteXY(58, 18, BinByte(KbFlag1));
  WriteXYF(50, 19, 0, 'Statusflag 0040h:0018h');
  WriteXY(58, 20, BinByte(KbFlag2));
  if KbFlag1 and $80 <> 0 then WriteXYF(51, 10, 10, #$DF#$DF#$DF) else WriteXYF(51, 10, 0, #$DF#$DF#$DF);
  if KbFlag1 and $40 <> 0 then WriteXYF(57, 10, 10, #$DF#$DF#$DF) else WriteXYF(57, 10, 0, #$DF#$DF#$DF);
  if KbFlag1 and $20 <> 0 then WriteXYF(63, 10, 10, #$DF#$DF#$DF) else WriteXYF(63, 10, 0, #$DF#$DF#$DF);
  if KbFlag1 and $10 <> 0 then WriteXYF(69, 10, 10, #$DF#$DF#$DF) else WriteXYF(69, 10, 0, #$DF#$DF#$DF);
  if KbFlag1 and 2 <> 0 then WriteXYF(51, 13, 10, #$DF#$DF) else WriteXYF(51, 13, 0, #$DF#$DF);
  if KbFlag1 and 1 <> 0 then WriteXYF(69, 13, 10, #$DF#$DF) else WriteXYF(69, 13, 0, #$DF#$DF);
  if KbFlag1 and 4 <> 0 then
  begin
    if KbFlag2 and 1 <> 0 then WriteXYF(51, 14, 10, #$DF#$DF) else WriteXYF(69, 14, 10, #$DF#$DF);
  end
  else
  begin
    WriteXYF(51, 14, 0, #$DF#$DF);
    WriteXYF(69, 14, 0, #$DF#$DF);
  end;
  if KbFlag1 and 8 <> 0 then
  begin
    if KbFlag2 and 2 <> 0 then WriteXYF(55, 14, 10, #$DF#$DF) else WriteXYF(65, 14, 10, #$DF#$DF);
  end
  else
  begin
    WriteXYF(55, 14, 0, #$DF#$DF);
    WriteXYF(65, 14, 0, #$DF#$DF);
  end;
  MouseShow;
  RestoreWin(W);
end;

begin
  MouseHide;
  PushScreen(DlgStack);
  Frame(6, 6, 67, 14, 11, 6, 0, 1);
  OpenFrame(7, 10, 39, 8, 11, 6);
  Window(7, 7, 80, 25);
  WriteXYF(2, 1, 14, 'Tastentest: Bitte Tasten bet'#$84'tigen ...');
  WriteXY(1, 2, #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C2#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4);
  WriteXY(1, 3, ' Scancode  Ascii' +
      'code  Erweitert ' +
      ' Zeichen '#$B3);
  WriteXY(42, 4, #$B3);
  for I := 5 to 14 do
    WriteXY(42, I, #$B3);
  WriteXYF(2, 14, 14, 'Ende mit Escape oder rechter Maustaste.');
  WriteXY(42, 15, #$C1);
  WriteXY(42, 5, #$C3#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
  WriteXYF(44, 3, 14, 'Einfg  Caps  Num  Scroll');
  WriteXY(44, 6, 'L-Shift         R-Shift');
  WriteXY(44, 9, 'Strg Alt     AltGr Strg');
  WriteXY(42, 10, #$C3#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4 +
      #$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4#$C4);
  WriteXYF(52, 8, 2, #$DF#$DF#$DF#$DF#$DF#$DF);
  Window(8, 11, 46, 18);
  TextBackground(3);
  ClrScr;
  Window(7, 7, 80, 25);
  SetColor(11, 6);
  MouseShow;
  ShowFlags;
  Old17 := KbFlag1;
  repeat
    if ReadKey(Scan, Ascii, S) then
    begin
      MouseHide;
      ScrollUp(7, 10, 45, 17, 3);
      GotoXY(1, 11);
      Idle;
      GotoXY(2, 12);
      SetColor(11, 3);
      {$I+}
      Write(Scan: 5, Ascii: 11, S: 11, Chr(Ascii): 9);
      {$I-}
      MouseShow;
      SetColor(11, 6);
    end;
    if (KbFlag1 <> Old17) or (KbFlag2 <> Old18) or (Ascii = 32) then
    begin
      ShowFlags;
      Old17 := KbFlag1;
      Old18 := KbFlag2;
    end;
  until (Ascii = 27) or (MouseButton = 2) or MouseOutside(6, 74, 6, 21);
  CloseDialog;
end;

procedure PortInfo;
var
  Key: Word;
  B2: TButton2;
  Ok, Swap: Boolean;
  W: Word;
begin
  OpenDialog;
  Frame(10, 6, 60, 14, 11, 6, 0, 1);
  WriteXY(3, 2, 'Serielle Schnitt' +
      'stellen:      Pa' +
      'rallele Schnitts' +
      'tellen:');
  WriteXY(3, 11, 'Adresse Baudrate' +
      ',Parit'#$84't,Datenbi' +
      'ts,Stopbits');
  WriteXY(3, 12, 'Parit'#$84't: N = Keine');
  WriteXY(3, 13, '         E = Gerade');
  WriteXY(3, 14, '         O = Ungerade');
  OpenFrame(12, 9, 27, 6, 11, 6);
  OpenFrame(42, 9, 26, 6, 11, 6);
  TextColor(11);
  Window(15, 11, 80, 25);
  ShowComPorts;
  Window(45, 11, 80, 25);
  ShowLptPorts;
  Window(1, 1, 80, 25);
  InitButton2(True, 38, 18, 47, 18, 14, 0, 11, 6, ' OK ', 'Drucker vertauschen', B2);
  MouseShow;
  repeat
    HandleButton2(Ok, Swap, Key, B2);
    if LoCaseW(Key) = 'o' then Ok := True;
    if LoCaseW(Key) = 'd' then Swap := True;
    if Swap then
      if WinRunning then
        ErrorBox('Drucker vertauschen:', 'Nicht m'#$94'glich w'#$84'hrend Windows l'#$84'uft!')
      else
      begin
        W := MemW[$40:8];
        MemW[$40:8] := MemW[$40:$A];
        MemW[$40:$A] := W;
        Window(45, 11, 80, 25);
        ShowLptPorts;
        Window(1, 1, 80, 25);
      end;
  until IsCancel(Key) or MouseOutside(10, 71, 6, 21) or Ok;
  CloseDialog;
end;

end.
