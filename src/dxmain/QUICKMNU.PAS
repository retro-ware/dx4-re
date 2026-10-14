{$O+,F+,G+,S-,I-,X+,V-}
unit QuickMnu;

interface

type
  Str30 = string[30];
  TQuickEntry = record
    Name: Str30;
    Prog: string[127];
    InWindow: Boolean;
    Params: Boolean;
    FileParam: Boolean;
    InDX: Boolean;
    ChDir: Boolean;
    Mode25: Boolean;
    ClrScr: Boolean;
    Wait: Boolean;
    BlackBorder: Boolean;
  end;
  TQuickList = array[0..60] of TQuickEntry;
  PQuickList = ^TQuickList;

var
  QuickTop: Byte;
  QuickRow: Byte;
  Entries: PQuickList;

function QuickMenu(FileName: string; var Mode: Byte; var InDX: Boolean): string;

implementation

uses Crt, Dos, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Status, Help, Lists, ScrSave,
  Fonts, Execute, AddProg, U0DA0, U13B0;

type
  TQuickLst = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

procedure TQuickLst.DrawLine(Line: Integer);
var
  S: string[5];
begin
  Str(Line + Top - 1, S);
  if Line + Top - 1 < 10 then S := ' 0' + S else S := ' ' + S;
  S := S + ': ';
  Text := S + Entries^[Line + Top - 1].Name;
  TList.DrawLine(Line);
end;

function QuickMenu(FileName: string; var Mode: Byte; var InDX: Boolean): string;
var
  Key: Word;
  Cancel, Change, Run: Boolean;
  CmdStr: string[128];
  P: string[128];
  SaveTop: Pointer;
  SaveDir: string[128];
  Prog: string[128];
  Name: string[30];
  Dir: string[79];
  Nam: NameStr;
  Ext: ExtStr;
  B: TButton3;
  L: TQuickLst;
  Rows: Byte;
  W: TWinState;
  FontSw, FileParam, Params, ChDirF, Mode25, Clr, Wait, Border, InWindow: Boolean;
  Unused1: array[1..5] of Byte;
  Unused2: string;
  C1, C2, C3, C4, C5, C6: T13B0;
  Ck1, Ck2, Ck3, Ck4, Ck5, Ck6: Boolean;

procedure SaveQuick;
var
  F: file of TQuickList;
begin
  Assign(F, HomeDir + 'dxquick.dat');
  Rewrite(F);
  Write(F, Entries^);
  Close(F);
  if IOResult <> 0 then
    MsgBox('Fehler beim Schreiben von dxquick.dat!', 'Quickmen'#$81' kann nicht gespeichert werden!');
end;

procedure LoadQuick;
var
  F: file of TQuickList;
  I: Word;
begin
  Assign(F, HomeDir + 'dxquick.dat');
  Reset(F);
  Read(F, Entries^);
  Close(F);
  if IOResult <> 0 then
  begin
    WaitRelease;
    ErrorBox('Fehler beim Lesen der Quickmen'#$81'-Eintr'#$84'ge!', 'Es wurde eine neue Datei dxquick.dat angelegt.');
    for I := 0 to 60 do
    begin
      Entries^[I].Name := '';
      Entries^[I].Prog := '';
      Entries^[I].ChDir := False;
      Entries^[I].Params := False;
      Entries^[I].FileParam := False;
      Entries^[I].InDX := False;
      Entries^[I].Mode25 := True;
      Entries^[I].Wait := False;
      Entries^[I].ClrScr := False;
      Entries^[I].BlackBorder := False;
    end;
    SaveQuick;
  end;
end;

procedure EditEntry(N: Byte; FileName: Str128);
var
  Name: string[30];
  Prog: string[128];
  SaveProg: string[128];
  Sel: string[128];
  Key: Word;
  B: TButton3;
  Hit1, Hit2, Hit3: Boolean;
  Params, FileParam, ChDirF, InDX, Mode25, Border, InWindow, Wait, Clr: Boolean;
  Chk1, Chk3, Chk2: T13B0;
  Dir: DirStr;
  Nam: NameStr;
  Ext: ExtStr;
label
  Nm;
begin
  OpenDialog;
  Frame(10, 7, 61, 14, 15, 5, 0, 1);
  GotoXY(20, 1);
  Write('Eintrag Nr. ', N, ' vornehmen:');
  WriteXY(4, 3, 'Name:');
  WriteXY(3, 9, 'Datei:');
  WriteXYF(4, 3, 14, 'N');
  WriteXYF(3, 9, 14, 'D');
  WriteXY(10, 4, 'Der Name im Quickmen'#$81);
  WriteXY(10, 10, 'Das auszuf'#$81'hrende Programm (*.exe, *.com, *.bat)');
  WriteXY(36, 3, '[ ] Im DX ausf'#$81'hren     ');
  WriteXYF(40, 3, 14, 'I');
  WriteXY(36, 4, '[ ] Parameter angeben');
  WriteXYF(40, 4, 14, 'P');
  WriteXY(36, 5, '[ ] Datei als Parameter');
  WriteXYF(42, 5, 14, 't');
  WriteXY(36, 6, '[ ] Verzeichnis wechseln');
  WriteXYF(40, 6, 14, 'V');
  Params := Entries^[N].Params;
  FileParam := Entries^[N].FileParam;
  ChDirF := Entries^[N].ChDir;
  InDX := Entries^[N].InDX;
  Mode25 := Entries^[N].Mode25;
  Wait := Entries^[N].Wait;
  Clr := Entries^[N].ClrScr;
  Border := Entries^[N].BlackBorder;
  InWindow := Entries^[N].InWindow;
  if InDX then WriteXY(37, 3, 'X') else WriteXY(37, 3, ' ');
  if Params then WriteXY(37, 4, 'X') else WriteXY(37, 4, ' ');
  if FileParam then WriteXY(37, 5, 'X') else WriteXY(37, 5, ' ');
  if ChDirF then WriteXY(37, 6, 'X') else WriteXY(37, 6, ' ');
  Name := Entries^[N].Name;
  Prog := Entries^[N].Prog;
  SaveProg := Prog;
  InputLine(20, 10, 16, 65, Name, 22, 0, #216, False);
  InputLine(20, 16, 16, 67, Prog, 48, 0, #216, False);
  InitButton3(True, 12, 19, 32, 19, 52, 19, 14, 0, 15, 5, '   Speichern   ', '     Datei     ',
    '   Abbrechen   ', B);
  Chk1.Init(66, 10, 0, 2, 5, 'dX');
  Chk2.Init(13, 13, 0, 2, 5, 'Eintragen der aktuellen Datei');
  MouseShow;
  repeat
    ResetButton3(B);
    if Key = $419 then
    begin
    Nm:
      if InputLine(20, 10, 19, 44, Name, 22, 29, #216, False) = 9 then Key := $408
      else Key := 0;
    end;
    if Key = $408 then
      if InputLine(20, 16, 19, 70, Prog, 48, 128, #216, False) = $3F7 then goto Nm;
    RestoreButton3(B);
    repeat
      HandleButton3(Hit1, Hit2, Hit3, Key, B);
      Hit3 := Hit3 or IsCancel(Key);
      if LoCaseW(Key) = 's' then Hit1 := True;
      if LoCaseW(Key) = 'a' then Hit3 := True;
      if (LoCaseW(Key) = 'd') or (Key = $3F7) or (Key = $430) or MouseOn(16, 20, 69) then Key := $408;
      if (LoCaseW(Key) = 'n') or (Key = 9) or (Key = $438) or MouseOn(10, 20, 43) then Key := $419;
      if Hit2 then
      begin
        Sel := SelectProgram;
        if Sel <> '' then
        begin
          Prog := Sel;
          FSplit(Prog, Dir, Name, Ext);
          InputLine(20, 16, 19, 70, Prog, 48, 0, #216, False);
          InputLine(20, 10, 19, 44, Name, 22, 0, #216, False);
        end;
      end;
      if (LoCaseW(Key) = 'e') or Chk2.Clicked then
      begin
        Prog := FileName;
        FSplit(FileName, Dir, Name, Ext);
        InputLine(20, 16, 19, 70, Prog, 48, 0, #216, False);
        InputLine(20, 10, 19, 44, Name, 22, 0, #216, False);
      end;
      if (Key = $3FF) or (LoCaseW(Key) = 'i') or MouseOn(10, 46, 64) then
      begin
        InDX := not InDX;
        MouseHide;
        if InDX then WriteXY(47, 10, 'X') else WriteXY(47, 10, ' ');
        MouseShow;
        WaitRelease;
      end;
      if (Key = $401) or (LoCaseW(Key) = 'p') or MouseOn(11, 46, 66) then
      begin
        Params := not Params;
        MouseHide;
        if Params then WriteXY(47, 11, 'X') else WriteXY(47, 11, ' ');
        MouseShow;
        WaitRelease;
      end;
      if (Key = $3FC) or (LoCaseW(Key) = 't') or MouseOn(12, 46, 68) then
      begin
        FileParam := not FileParam;
        MouseHide;
        if FileParam then WriteXY(47, 12, 'X') else WriteXY(47, 12, ' ');
        MouseShow;
        WaitRelease;
      end;
      if (Key = $417) or (LoCaseW(Key) = 'v') or MouseOn(13, 46, 69) then
      begin
        ChDirF := not ChDirF;
        MouseHide;
        if ChDirF then WriteXY(47, 13, 'X') else WriteXY(47, 13, ' ');
        MouseShow;
        WaitRelease;
      end;
      if (Key = $415) or (Key = 32) or (LoCaseW(Key) = 'x') or Chk1.Clicked then
      begin
        OpenDialog;
        Frame(40, 11, 30, 9, 11, 3, 0, 1);
        if not InDX then TextColor(7);
        WriteXY(3, 2, '[ ] 25 Zeilen-Modus');
        WriteXYF(10, 2, 14, 'Z');
        WriteXY(3, 3, '[ ] Bildschirm l'#$94'schen');
        WriteXYF(7, 3, 14, 'B');
        WriteXY(3, 4, '[ ] Nach Ausf'#$81'hrung warten');
        WriteXYF(7, 4, 14, 'N');
        WriteXY(3, 5, '[ ] Rahmenfarbe auf schwarz');
        WriteXYF(7, 5, 14, 'R');
        WriteXY(3, 6, '[ ] Im Fenster ausf'#$81'hren');
        WriteXYF(10, 6, 14, 'F');
        Chk3.Init(3, 8, 0, 2, 3, '       '#$9A'bernehmen       ');
        if Mode25 then WriteXY(4, 2, 'X') else WriteXY(4, 2, ' ');
        if Clr then WriteXY(4, 3, 'X') else WriteXY(4, 3, ' ');
        if Wait then WriteXY(4, 4, 'X') else WriteXY(4, 4, ' ');
        if Border then WriteXY(4, 5, 'X') else WriteXY(4, 5, ' ');
        if InWindow then WriteXY(4, 6, 'X') else WriteXY(4, 6, ' ');
        MouseShow;
        repeat
          GetKey(Key);
          if InDX then
          begin
            if (Key = $414) or (LoCaseW(Key) = 'z') or MouseOn(13, 43, 61) then
            begin
              Mode25 := not Mode25;
              MouseHide;
              if Mode25 then WriteXY(4, 2, 'X') else WriteXY(4, 2, ' ');
              MouseShow;
              WaitRelease;
            end;
            if (Key = $418) or (LoCaseW(Key) = 'b') or MouseOn(14, 43, 64) then
            begin
              Clr := not Clr;
              MouseHide;
              if Clr then WriteXY(4, 3, 'X') else WriteXY(4, 3, ' ');
              MouseShow;
              WaitRelease;
            end;
            if (Key = $419) or (LoCaseW(Key) = 'n') or MouseOn(15, 43, 68) then
            begin
              Wait := not Wait;
              MouseHide;
              if Wait then WriteXY(4, 4, 'X') else WriteXY(4, 4, ' ');
              MouseShow;
              WaitRelease;
            end;
            if (Key = $3FB) or (LoCaseW(Key) = 'r') or MouseOn(16, 43, 69) then
            begin
              Border := not Border;
              MouseHide;
              if Border then WriteXY(4, 5, 'X') else WriteXY(4, 5, ' ');
              MouseShow;
              WaitRelease;
            end;
            if (Key = $409) or (LoCaseW(Key) = 'f') or MouseOn(17, 43, 69) then
            begin
              InWindow := not InWindow;
              MouseHide;
              if InWindow then WriteXY(4, 6, 'X') else WriteXY(4, 6, ' ');
              MouseShow;
              WaitRelease;
            end;
          end;
        until Chk3.Clicked or (Key = 13);
        PopScreen(DlgStack);
        Key := 0;
      end;
      if MouseOutside(10, 72, 7, 22) then Hit3 := True;
    until Hit1 or Hit3 or (Key = $408) or (Key = $419);
  until Hit1 or Hit3;
  if Hit1 then
  begin
    Entries^[N].Prog := Prog;
    Entries^[N].Name := Name;
    Entries^[N].Params := Params;
    Entries^[N].FileParam := FileParam;
    Entries^[N].ChDir := ChDirF;
    Entries^[N].InDX := InDX;
    Entries^[N].Mode25 := Mode25;
    Entries^[N].Wait := Wait;
    Entries^[N].ClrScr := Clr;
    Entries^[N].BlackBorder := Border;
    Entries^[N].InWindow := InWindow;
    SaveQuick;
  end;
  PopScreen(DlgStack);
end;

function ParamInput(Params: Str128; Name: Str30): Str128;
var
  P: string[128];
  B2: TButton2;
  Hit1, Hit2: Boolean;
  Key: Word;
begin
  ParamInput := '';
  P := Params;
  OpenDialog;
  Frame(15, 7, 49, 9, 11, 11, 0, 1);
  WriteXY(9, 1, 'Parametereingabe f'#$81'r das Programm');
  WriteXYF(9, 1, 14, 'P');
  WriteCenterXYF(1, 3, 49, 14, Name);
  Window(1, 1, 80, 25);
  InitButton2(True, 17, 14, 41, 14, 14, 0, 11, 3, '       Start       ', '     Abbrechen     ', B2);
  Key := $401;
  MouseShow;
  repeat
    if (Key = $401) or (Key = $430) or (Key = 9) or MouseOn(12, 18, 62) then
      InputLine(18, 12, 17, 63, P, 43, 128, #216, False);
    HandleButton2(Hit1, Hit2, Key, B2);
    if LoCaseW(Key) = 's' then Hit1 := True;
    if LoCaseW(Key) = 'a' then Hit2 := True;
    if IsCancel(Key) then Hit2 := True;
    if MouseOutside(15, 65, 7, 17) then Hit2 := True;
  until Hit1 or Hit2;
  if Hit2 then ParamInput := #0 else ParamInput := P;
  CloseDialog;
end;

begin
  GetMem(Entries, 10248);
  LoadQuick;
  InDX := False;
  QuickMenu := '';
  Run := False;
  CmdStr := '';
  Mode := 1;
  OpenDialog;
  Rows := 5;
  if ScreenRows = 28 then Rows := 8;
  Frame(2, Rows, 40, 18, 11, 6, 0, 1);
  WriteCenterXY(1, 1, 40, 'Quickmen'#$81);
  WriteXYF(3, 3, 14, '0:');
  WriteXYF(3, 4, 14, '1:');
  WriteXYF(3, 5, 14, '2:');
  WriteXYF(3, 6, 14, '3:');
  WriteXYF(3, 7, 14, '4:');
  WriteXYF(3, 8, 14, '5:');
  WriteXYF(3, 9, 14, '6:');
  WriteXYF(3, 10, 14, '7:');
  WriteXYF(3, 11, 14, '8:');
  WriteXYF(3, 12, 14, '9:');
  Window(1, 1, 80, ScreenRows);
  InitButton3(True, 4, Rows + 16, 18, Rows + 16, 29, Rows + 16, 14, 0, 11, 6, 'Ausf'#$81'hren',
    #$8E'ndern', 'Abbrechen', B);
  C1.Init(6, Rows + 14, 0, 2, 6, '00');
  C2.Init(12, Rows + 14, 0, 2, 6, '10');
  C3.Init(18, Rows + 14, 0, 2, 6, '20');
  C4.Init(24, Rows + 14, 0, 2, 6, '30');
  C5.Init(30, Rows + 14, 0, 2, 6, '40');
  C6.Init(36, Rows + 14, 0, 2, 6, '50');
  WriteXY(4, Rows + 15, 'Alt');
  OpenFrame(6, Rows + 2, 34, 10, 0, 6);
  L.Init(0, 3, 0, 2, 7, Rows + 3, 10, 60, 33, True);
  L.SetPos(QuickTop + 1, QuickRow);
  MouseShow;
  WaitRelease;
  repeat
    SaveWin(W);
    HandleButton3(Run, Change, Cancel, Key, B);
    if Key = $423 then ShowHelp(37);
    Ck1 := C1.Clicked;
    Ck2 := C2.Clicked;
    Ck3 := C3.Clicked;
    Ck4 := C4.Clicked;
    Ck5 := C5.Clicked;
    Ck6 := C6.Clicked;
    RestoreWin(W);
    QuickTop := L.Handle(Key);
    if (Key = 13) and B[1].Focused then Run := True;
    if (Key = 13) and B[2].Focused then Change := True;
    case Key of
      $30: begin QuickTop := L.Top + 1; Run := True; L.SetPos(QuickTop, 1); end;
      $31: begin QuickTop := L.Top + 2; Run := True; L.SetPos(QuickTop, 2); end;
      $32: begin QuickTop := L.Top + 3; Run := True; L.SetPos(QuickTop, 3); end;
      $33: begin QuickTop := L.Top + 4; Run := True; L.SetPos(QuickTop, 4); end;
      $34: begin QuickTop := L.Top + 5; Run := True; L.SetPos(QuickTop, 5); end;
      $35: begin QuickTop := L.Top + 6; Run := True; L.SetPos(QuickTop, 6); end;
      $36: begin QuickTop := L.Top + 7; Run := True; L.SetPos(QuickTop, 7); end;
      $37: begin QuickTop := L.Top + 8; Run := True; L.SetPos(QuickTop, 8); end;
      $38: begin QuickTop := L.Top + 9; Run := True; L.SetPos(QuickTop, 9); end;
      $39: begin QuickTop := L.Top + 10; Run := True; L.SetPos(QuickTop, 10); end;
    end;
    if Ck1 then Key := $469;
    if Ck2 then Key := $460;
    if Ck3 then Key := $461;
    if Ck4 then Key := $462;
    if Ck5 then Key := $463;
    if Ck6 then Key := $464;
    case Key of
      $469: L.SetPos(1, 1);
      $460: L.SetPos(11, 1);
      $461: L.SetPos(21, 1);
      $462: L.SetPos(31, 1);
      $463: L.SetPos(41, 1);
      $464: L.SetPos(51, 1);
    end;
    if Change then
    begin
      Key := 0;
      Run := False;
      SaveWin(W);
      ResetButton3(B);
      EditEntry(QuickTop - 1, FileName);
      RestoreButton3(B);
      WaitRelease;
      RestoreWin(W);
      L.DrawAll;
    end;
    if IsCancel(Key) or MouseOutside(2, 43, Rows, Rows + 19) then Cancel := True;
    if Cancel then Run := False;
    Run := Run and (Entries^[QuickTop - 1].Prog <> '');
  until Run or Cancel;
  Dec(QuickTop);
  QuickRow := L.Cur;
  L.Done;
  CloseDialog;
  CmdStr := Entries^[QuickTop].Prog;
  Prog := CmdStr;
  Run := Run and (CmdStr <> '');
  FileParam := Entries^[QuickTop].FileParam;
  Params := Entries^[QuickTop].Params;
  ChDirF := Entries^[QuickTop].ChDir;
  InDX := Entries^[QuickTop].InDX;
  Mode25 := Entries^[QuickTop].Mode25;
  Clr := Entries^[QuickTop].ClrScr;
  Wait := Entries^[QuickTop].Wait;
  Border := Entries^[QuickTop].BlackBorder;
  Name := Entries^[QuickTop].Name;
  InWindow := Entries^[QuickTop].InWindow;
  FreeMem(Entries, 10248);
  SetMouseMap;
  if Run then
  begin
    if not FileParam then FileName := '';
    if Params then
    begin
      P := ParamInput(FileName, Name);
      CmdStr := CmdStr + ' ' + P;
      if P = #0 then Run := False;
    end
    else if FileParam then CmdStr := CmdStr + ' ' + FileName;
    if CmdStr[Length(CmdStr)] = #0 then CmdStr := '';
    QuickMenu := CmdStr;
    if ChDirF then Mode := 2;
    if InDX and Run then
    begin
      if Mode = 2 then
      begin
        GetDir(0, SaveDir);
        FSplit(Prog, Dir, Nam, Ext);
        if Length(Dir) > 3 then DelBackslash(Dir);
        ChDir(Dir);
        InOutRes := 0;
      end;
      OpenDialog;
      FontSw := False;
      if (CfgColors[32] <> 0) and Mode25 then
      begin
        CfgColors[32] := 0;
        InitFont;
        FontSw := True;
      end;
      Window(1, 1, 80, ScreenRows);
      ShowCursor;
      SetColor(7, 0);
      if Clr then ClrScr;
      if Border then SetBorder(0);
      if InWindow then
      begin
        HideCursor;
        RunWindow(GetEnv('COMSPEC'), ' /c ' + CmdStr, Name);
      end
      else
      begin
        SaveTop := HeapEnd;
        SetMemTop(HeapPtr);
        SwapVectors;
        Exec(GetEnv('COMSPEC'), ' /C ' + CmdStr);
        SwapVectors;
        SetMemTop(SaveTop);
        HideCursor;
      end;
      ResetMouse;
      InstallHandler;
      MouseShow;
      NormalCursor;
      MouseGoto(Byte(MouseX), Byte(MouseY));
      if Wait then
      begin
        MouseHide;
        WriteXYFB(1, ScreenRows, 15, 0, '  Bitte eine Taste dr'#$81'cken um zum DX zur'#$81'ckzukehren.  ');
        MouseShow;
        ClockHidden := False;
        WaitInput;
        WaitRelease;
      end;
      MouseHide;
      RestoreBorder;
      SetPal2;
      if FontSw then
      begin
        CfgColors[32] := 1;
        InitFont;
      end;
      if ScreenRows <> Mem[$40:$84] + 1 then
      begin
        ShowCursor;
        if CfgColors[32] <> 0 then TextMode($103) else TextMode(3);
        HideCursor;
        SetPal2;
        InitFont;
      end;
      MouseShow;
      PopScreen(DlgStack);
      MouseYRange(0, ScreenRows - 1);
      QuickMenu := '';
      if Mode = 2 then
      begin
        ChDir(SaveDir);
        InOutRes := 0;
      end;
    end;
  end
  else QuickMenu := '';
end;

end.
