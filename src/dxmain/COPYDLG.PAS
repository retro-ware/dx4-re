{$O+,F+,G+,S-,I-,X+,V-}
unit CopyDlg;

interface

function CopyDialog(Name, Dir: string; var Target: string; Marked: Boolean; Count: Integer; Attr: Word; Auto: Boolean;
  var Compare, DoCopy, DoMove, Attrib: Boolean; Path: string; L1, L2: Longint): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, Toggle, U12D5, U1146, U1D10;

function CopyDialog(Name, Dir: string; var Target: string; Marked: Boolean; Count: Integer; Attr: Word; Auto: Boolean;
  var Compare, DoCopy, DoMove, Attrib: Boolean; Path: string; L1, L2: Longint): Boolean;
var
  S: string;
  B: TButton4;
  Focus, Cancel, TargetHit, Dummy: Boolean;
  Key: Word;
  Flag: Byte;
  Tg: TToggle;
  W: TWinState;
  I, J: Byte;
  R: Registers;

procedure DrawFlags;
begin
  MouseHide;
  if Compare then WriteXY(36, 12, 'X') else WriteXY(36, 12, ' ');
  if Attrib then WriteXY(36, 13, 'X') else WriteXY(36, 13, ' ');
  MouseShow;
  if MouseOn(12, 35, 58) or MouseOn(13, 35, 61) then WaitRelease;
end;

procedure ShowSizes;
var
  Free: Longint;
  Dummy: Word;
begin
  ArrowCursor;
  CopySize := 0;
  CopyCount := 0;
  P12D5_BCB;
  Frame(13, 19, 55, 2, 11, 3, 0, 1);
  WriteXY(5, 1, 'Bitte warten, ermittle Dateigr'#$94#$E1'en...');
  Free := DiskFree(Ord(UpCaseC(Dir[1])) - 64);
  P12D5_9E4(Path, L1, L2, Count);
  P12D5_BCB;
  MouseHide;
  Frame(13, 19, 55, 2, 11, 3, 0, 1);
  WriteF(14, '    ' + SizeStr(Free));
  Write(' Bytes sind frei auf Laufwerk ', Dir[1], ':');
  GotoXY(1, 2);
  WriteF(14, '    ' + SizeStr(CopySize));
  Write(' Bytes in ');
  WriteF(14, LongStrW(CopyCount, 0));
  Write(' Dateien zu kopieren');
  MouseShow;
  RestoreWin(W);
end;

begin
  OpenDialog;
  Frame(13, 7, 55, 10, 11, 3, 0, 1);
  WriteXY(3, 1, 'Kopieren oder Bewegen von ');
  if (Count = 0) and (Attr and $10 = 0) then
  begin
    WriteF(14, Name);
    WriteLn(' nach:');
    if G562 or Marked then Target := JoinPath(Target, Name);
  end
  else if (Attr and $10 <> 0) and (Count = 0) then
  begin
    WriteF(14, Name);
    WriteLn(' nach:');
    Target := JoinPath(Target, Name);
  end
  else
  begin
    Str(Count, S);
    WriteF(14, S);
    WriteLn(' Dateien nach:');
    if G562 or Marked then Target := JoinPath(Target, '*.*');
  end;
  if G9F5 then WriteXYF(17, 7, 10, 'Rechte Maustaste kopiert!');
  InputLine(16, 10, 0, 0, Target, 49, 0, #216, False);
  WriteXY(35, 12, '[ ] Vergleichen der Dateien');
  WriteXYF(39, 12, 14, 'V');
  WriteXY(35, 13, '[ ] Attribute auch kopieren');
  WriteXYF(40, 13, 14, 't');
  InitButton4(True, 15, 15, 30, 15, 44, 15, 55, 15, 14, 0, 11, 3, ' Kopieren ', ' Bewegen ', ' Ziel ', ' Abbruch ', B);
  Tg.Init(GA19, 15, 12, 14, 0, 11, 3, 'Ein', 'Aus');
  WriteXY(22, 12, 'Anzeige');
  WriteXYF(22, 13, 14, 'r');
  Write('estlicher');
  WriteXY(22, 14, 'Bytes');
  MouseShow;
  Focus := True;
  Attrib := True;
  Compare := False;
  R.AX := $1500;
  R.BX := 0;
  Intr($2F, R);
  if R.BX <> 0 then
    if UpCaseC(Path[1]) = Chr(R.CL + 65) then Attrib := False;
  DrawFlags;
  SaveWin(W);
  if GA19 then ShowSizes;
  repeat
    HandleButton4(DoCopy, DoMove, TargetHit, Cancel, Key, B);
    if Key = $423 then ShowHelp(78);
    if LoCaseW(Key) = 'k' then DoCopy := True;
    if LoCaseW(Key) = 'b' then DoMove := True;
    if LoCaseW(Key) = 'z' then TargetHit := True;
    if LoCaseW(Key) = 'a' then Cancel := True;
    if TargetHit then
    begin
      S := P1146_236D(Dir, Flag, 0);
      if S <> '' then
      begin
        DelBackslash(S);
        Target := S + '\*.*';
        InputLine(16, 10, 0, 0, Target, 49, 0, #216, False);
      end;
      SetMouseMap;
    end;
    if (Key = $40D) or (Key = 9) or (Key = $3F7) or (Key = $430) or MouseOn(10, 16, 65) then
    begin
      Focus := False;
      DrawFlags;
      ResetButton4(B);
      InputLine(16, 10, 15, 67, Target, 49, 128, #216, False);
      if (Target[Length(Target)] = '\') or (Target[Length(Target)] = ':') then
      begin
        Target := Target + '*.*';
        InputLine(16, 10, 15, 67, Target, 49, 0, #216, False);
      end;
      RestoreButton4(B);
      Focus := True;
      DrawFlags;
    end;
    if (LoCaseW(Key) = 'v') or (Key = 32) or MouseOn(12, 35, 58) then
    begin
      Compare := not Compare;
      DrawFlags;
    end;
    if (LoCaseW(Key) = 't') or MouseOn(13, 35, 61) then
    begin
      Attrib := not Attrib;
      DrawFlags;
    end;
    if Tg.Clicked or (LoCaseW(Key) = 'r') then
    begin
      if LoCaseW(Key) = 'r' then Tg.Toggle;
      GA19 := Tg.Checked;
      if GA19 then
        ShowSizes
      else
      begin
        MouseHide;
        RestoreLine(19, DlgStack.Top);
        RestoreLine(20, DlgStack.Top);
        RestoreLine(21, DlgStack.Top);
        RestoreLine(22, DlgStack.Top);
        RestoreLine(23, DlgStack.Top);
        RestoreLine(ScreenRows, DlgStack.Top);
        J := 15;
        repeat
          Mem[VidSeg:J * 2 + $B40 - 1] := 7;
          Inc(J);
        until J >= 72;
        MouseShow;
        RestoreWin(W);
      end;
    end;
    if Target = '' then
    begin
      DoCopy := False;
      DoMove := False;
      Key := 27;
    end;
    if G9F5 then
    begin
      if MouseButton = 2 then DoCopy := True;
    end
    else if MouseButton = 2 then Cancel := True;
    I := 18;
    if GA19 then I := 20;
    if (Key = 27) or (Key = $42C) or MouseOutside(13, 69, 7, I) then Cancel := True;
    if Auto and not GA08 then DoCopy := True;
  until DoCopy or DoMove or Cancel;
  Target := Trim(Target);
  if Target[2] <> ':' then Target := FExpand(Target);
  CopyDialog := not Cancel;
  PopScreen(DlgStack);
  if GA19 then P12D5_BCB;
end;

end.
