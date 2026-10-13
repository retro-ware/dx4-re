{$O+,F+,G+,S-,I-,X+,V-}
unit CDDlg;
{ CD player dialog (MSCDEX) and CD tray open/close }

interface

procedure CDEject(Eject: Boolean);
procedure CDPlayer;
procedure CDTray;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Toggle, U1546, U1F7B;

type
  TCDRequest = record
    Len, SubUnit, Cmd: Byte;
    Status: Word;
    Reserved: array[1..8] of Byte;
    Media: Byte;
    Buf: Pointer;
    Count: Word;
    Start: Longint;
    Vol: Longint;
    Fill: array[1..5] of Byte;
  end;

procedure CDEject(Eject: Boolean);
var
  R: Registers;
  CB: Byte;
  Req: TCDRequest;
begin
  R.AX := $1500;
  R.BX := 0;
  R.CX := 0;
  Intr($2F, R);
  if R.BX = 0 then Exit;
  if Eject then CB := 0 else CB := 5;
  FillChar(Req, $1C, 0);
  Req.Len := $1C;
  Req.Cmd := 12;
  Req.Buf := @CB;
  Req.Count := 1;
  Req.Start := 0;
  Req.Vol := 0;
  OpenDialog;
  Frame(30, 13, 20, 3, 11, 6, 0, 1);
  ArrowCursor;
  WriteXYF(4, 2, 14, 'Moment noch ...');
  MouseShow;
  R.CH := 0;
  R.ES := Seg(Req);
  R.BX := Ofs(Req);
  R.AX := $1510;
  Intr($2F, R);
  PopScreen(DlgStack);
  NormalCursor;
end;

procedure DrawNumber(X, Y, Fg, Bg, N: Byte);
var
  S: string[7];

  procedure DigitOne(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, '    '#$DA#$C4#$BF);
    WriteXY(X, Y + 1, '  '#$DA#$C4#$D9' '#$B3);
    WriteXY(X, Y + 2, '  '#$C0#$C4#$BF' '#$B3);
    WriteXY(X, Y + 3, '    '#$B3' '#$B3);
    WriteXY(X, Y + 4, '    '#$B3' '#$B3);
    WriteXY(X, Y + 5, '    '#$C0#$C4#$D9);
  end;

  procedure DigitTwo(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, #$DA#$C4#$C4#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, #$B3' '#$DA#$C4#$C4#$C4#$D9);
    WriteXY(X, Y + 4, #$B3' '#$C0#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitThree(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, ' '#$DA#$C4#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, ' '#$C0#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, #$DA#$C4#$C4#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitFour(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$BF' '#$DA#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$B3' '#$B3' '#$B3);
    WriteXY(X, Y + 2, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, '    '#$B3' '#$B3);
    WriteXY(X, Y + 5, '    '#$C0#$C4#$D9);
  end;

  procedure DigitFive(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$DA#$C4#$C4#$C4#$D9);
    WriteXY(X, Y + 2, #$B3' '#$C0#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 3, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, #$DA#$C4#$C4#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitSix(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$DA#$C4#$C4#$C4#$D9);
    WriteXY(X, Y + 2, #$B3' '#$C0#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 3, #$B3' '#$DA#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitSeven(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, '  '#$DA#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, '  '#$B3' '#$DA#$C4#$D9);
    WriteXY(X, Y + 4, '  '#$B3' '#$B3'  ');
    WriteXY(X, Y + 5, '  '#$C0#$C4#$D9'  ');
  end;

  procedure DigitEight(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$DA#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, #$B3' '#$DA#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitNine(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$DA#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 3, #$C0#$C4#$C4#$C4#$BF' '#$B3);
    WriteXY(X, Y + 4, #$DA#$C4#$C4#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DigitZero(X, Y: Byte);
  begin
    WriteXY(X, Y + 0, #$DA#$C4#$C4#$C4#$C4#$C4#$BF);
    WriteXY(X, Y + 1, #$B3' '#$DA#$C4#$BF' '#$B3);
    WriteXY(X, Y + 2, #$B3' '#$B3' '#$B3' '#$B3);
    WriteXY(X, Y + 3, #$B3' '#$B3' '#$B3' '#$B3);
    WriteXY(X, Y + 4, #$B3' '#$C0#$C4#$D9' '#$B3);
    WriteXY(X, Y + 5, #$C0#$C4#$C4#$C4#$C4#$C4#$D9);
  end;

  procedure DrawDigit(X, Y, D: Byte);
  begin
    case D of
      0: DigitZero(X, Y);
      1: DigitOne(X, Y);
      2: DigitTwo(X, Y);
      3: DigitThree(X, Y);
      4: DigitFour(X, Y);
      5: DigitFive(X, Y);
      6: DigitSix(X, Y);
      7: DigitSeven(X, Y);
      8: DigitEight(X, Y);
      9: DigitNine(X, Y);
    end;
  end;

begin
  SetColor(Fg, Bg);
  DrawDigit(X, Y, N div 10);
  DrawDigit(X + 8, Y, N mod 10);
end;

procedure CDPlayer;
var
  V1, V2, V3, V4, V5, V6, Done: Boolean;
  Pos, Start: Longint;
  B: TButton6;
  Tog: TToggle;
  Key: Word;
  Drive: Byte;
  Mode: Boolean;
  W8: Word;
  C1, C2, C3, C4, C5, C6, C7: Byte;
  I: Byte;
  M1, M2, M3: Longint;
  Len: Longint;
  TimeStr: string[5];
  W: TWinState;
begin
  CDInit;
  Mode := False;
  ArrowCursor;
  if FindCDDrive(Drive) then
  begin
    if not CDReady then
    begin
      NormalCursor;
      Exit;
    end;
  end
  else
  begin
    ErrorBox('Es wurde kein CD-Laufwerk gefunden!', '');
    Exit;
  end;
  Pos := CDPosition;
  OpenDialog;
  Window(1, 1, 80, 25);
  if Mode then Frame(31, 8, 17, 6, 11, 6, 0, 1);
  Frame(13, 17, 55, 3, 11, 6, 0, 1);
  InitButton6(True, 3, 1, 11, 1, 19, 1, 33, 1, 41, 1, 48, 1, 14, 0, 11, 6,
    ' '#30' ', ' '#16' ', ' '#254' ', #222#222' ', #17'|', '|'#16, B);
  Tog.Init(False, 27, 1, 15, 15, 11, 6, '+', '+');
  MouseShow;
  Done := False;
  ArrowCursor;
  CDUpdate;
  NormalCursor;
  repeat
    if MouseOutside(13, 69, 17, 21) and MouseOutside(31, 49, 8, 15) and Mode and MouseOutside(33, 47, 16, 16) then
      Done := True;
    if MouseOutside(13, 69, 17, 21) and not Mode then Done := True;
    Pos := CDPosition;
    HandleButton6(V5, V1, V2, V6, V4, V3, Key, B);
    if Tog.Clicked or (Key = $2B) then
    begin
      if Key = $2B then Tog.Toggle;
      MouseHide;
      if Tog.Checked then
      begin
        SaveWin(W);
        Frame(30, 8, 19, 6, 11, 6, 0, 1);
        RestoreWin(W);
        TimeStr := '';
      end
      else
        for I := 8 to 16 do RestoreLine(I, DlgStack.Top);
      MouseShow;
    end;
    Mode := Tog.Checked;
    if V6 then
      if CDPlaying then
      begin
        CDPause;
        if not CDPaused then
        begin
          Start := CDTrackStart(0);
          CDPlay(Start, CDLength - Start - 150);
        end;
      end
      else
        CDResume;
    if V5 then
      if CDDoorOpen then
        CDEject(True)
      else
      begin
        CDEject(False);
        CDReady;
      end;
    if V1 then
      if CDReady then CDPrevTrack(True);
    if V2 then CDNextTrack;
    if V3 then
    begin
      CDRewind;
      Delay(500);
    end;
    if V4 then
    begin
      CDForward;
      Delay(500);
    end;
    Len := TrackStart[CurTrack + 1] - TrackStart[CurTrack];
    if Mode then CDGetInfo(W8, C1, C2, C3, C4, C5, C6, C7);
    CDTrackTime(Len, M1, M2, M3);
    if (MinSecStr(C1, C2) <> TimeStr) and Mode then
    begin
      MouseHide;
      TimeStr := MinSecStr(C1, C2);
      SaveWin(W);
      WriteXYFB(33, 16, 11, 6, ' ' + TimeStr + ' / ' + MinSecStr(Byte(M1), Byte(M2)) + ' ');
      DrawNumber(33, 9, 0, 6, CurTrack);
      RestoreWin(W);
      MouseShow;
    end;
    if IsCancel(Key) then Done := True;
  until Done;
  CloseDialog;
end;

procedure CDTray;
var
  Key: Word;
  B: TButton2;
  Ok, Cancel: Boolean;
begin
  OpenDialog;
  Window(1, 1, 80, 25);
  Frame(22, 13, 35, 4, 11, 6, 0, 1);
  WriteCenterXY(1, 1, 35, 'CD-ROM-Schublade:');
  InitButton2(True, 3, 2, 19, 2, 14, 0, 11, 6, ' Schlie'#$E1'en ', '  Abbruch  ', B);
  CDEject(True);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    if IsCancel(Key) or MouseOutside(22, 58, 13, 18) then Cancel := True;
  until Ok or Cancel;
  if Ok then CDEject(False);
  CloseDialog;
end;

end.
