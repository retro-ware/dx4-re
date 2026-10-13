{$O+,F+,G+,S-,I-,V-}
unit DXMenu;

interface

function MainMenu(var Prog: string; var Pos: Word; var Mode: Byte): Boolean;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status, Help, UserMenu, AddProg;

type
  TBtn = object
    X, Y, FocFg, FocBg, Len, Fg, Bg, FocShadow: Byte;
    Pressed, Focused, OldPressed, OldFocused: Boolean;
    Text: string;
    Armed: Boolean;
    procedure Init(AFocus: Boolean; AX, AY, AFocFg, AFocBg, AFg, ABg, AFocShadow: Byte; S: string);
    procedure SetFocus(F: Boolean);
    procedure Draw;
    function Clicked: Boolean;
  end;
  TConfig = record
    Id: string[41];
    Fill: array[1..$6E0 - 42] of Byte;
    MenuPos: Word;
    Rest: array[1..$712 - $6E2] of Byte;
  end;

procedure TBtn.Init(AFocus: Boolean; AX, AY, AFocFg, AFocBg, AFg, ABg, AFocShadow: Byte; S: string);
begin
  Pressed := False;
  OldPressed := True;
  Focused := AFocus;
  OldFocused := not AFocus;
  X := AX;
  Y := AY;
  Bg := ABg;
  Fg := AFg;
  FocFg := AFocFg;
  FocBg := AFocBg;
  FocShadow := AFocShadow;
  Text := ' ' + S + ' ';
  Len := Length(Text);
  Armed := False;
  Draw;
end;

procedure TBtn.SetFocus(F: Boolean);
begin
  Focused := F;
  Armed := False;
  Draw;
end;

procedure TBtn.Draw;
var
  A, C2, C3, C4, U5, C6, C7, U8: Byte;
  I: Integer;
  L, R: string[1];
begin
  A := TextAttr;
  if (OldFocused = Focused) and (OldPressed = Pressed) then Exit;
  OldFocused := Focused;
  OldPressed := Pressed;
  C2 := 0;
  C3 := C2;
  if Focused then C4 := FocFg else C4 := FocBg;
  if Focused then C7 := 1 else C7 := Bg;
  if Pressed then
  begin
    C3 := Fg;
    L := ' ';
    R := '';
  end
  else
  begin
    C2 := Fg;
    L := '';
    R := ' ';
  end;
  SetColor(C2, C7);
  if Focused then C6 := FocShadow else C6 := C7;
  MouseHide;
  WriteXY(X - 1, Y, ' ');
  WriteXY(X - 1, Y + 1, ' ');
  WriteXY(X - 1, Y + 2, ' ');
  if ThinButtons then
  begin
    WriteXY(X, Y, L + #218);
    for I := 1 to Len do Write(#196);
    TextColor(C3);
    Write(#191 + R);
    WriteXYF(X, Y + 1, C2, L + #179);
    WriteFB(C4, C6, Text);
    WriteF(C3, #179 + R);
    TextColor(C2);
    WriteXY(X, Y + 2, L + #192);
    TextColor(C3);
    for I := 1 to Length(Text) do Write(#196);
    Write(#217 + R);
  end
  else
  begin
    WriteXY(X, Y, L + #210);
    for I := 1 to Len do Write(#196);
    TextColor(C3);
    Write(#211 + R);
    WriteXYF(X, Y + 1, C2, L + #206);
    WriteFB(C4, C6, Text);
    WriteF(C3, #208 + R);
    TextColor(C2);
    WriteXY(X, Y + 2, L + #212);
    TextColor(C3);
    for I := 1 to Length(Text) do Write(#196);
    Write(#213 + R);
  end;
  MouseShow;
  TextAttr := A;
end;

function TBtn.Clicked: Boolean;
var
  X1, X2, Y1: Byte;
  Dummy: Word;
begin
  Clicked := False;
  X1 := X + Lo(WindMin) + 1;
  X2 := X1 + Len;
  Y1 := Y + Hi(WindMin) + 1;
  if (MouseButton = 1) and (Y1 = MouseY) and (X1 < MouseX) and (X2 > MouseX) then
  begin
    if Armed then
    begin
      Pressed := True;
      Armed := False;
      Draw;
      repeat
      until (MouseButton = 0) or (Y1 <> MouseY) or (X1 >= MouseX) or (X2 < MouseX);
      if (Y1 = MouseY) and (X1 < MouseX) and (X2 + 1 > MouseX) then Clicked := True;
      Pressed := False;
      Draw;
    end
    else Armed := True;
    Focused := True;
  end;
end;

procedure SaveMenu;
var
  F: file of TMenu;
begin
  Assign(F, HomeDir + 'dxmenu.dat');
  Rewrite(F);
  Write(F, Menu^);
  Close(F);
  if IOResult <> 0 then MsgBox('Fehler beim Schreiben der Men'#129'datei', HomeDir + 'dxmenu.dat');
end;

function LoadMenu: Boolean;
var
  F: file of TMenu;
  I, J: Integer;
begin
  Assign(F, HomeDir + 'dxmenu.dat');
  New(Menu);
  for I := 1 to 15 do
  begin
    Menu^.Groups[I].Name := '';
    Menu^.Count := 0;
    for J := 1 to 21 do
    begin
      Menu^.Groups[I].Flag := 0;
      with Menu^.Groups[I].Items[J] do
      begin
        Name := '';
        Prog := '';
      end;
    end;
  end;
  LoadMenu := True;
  Reset(F);
  Read(F, Menu^);
  Close(F);
  if IOResult <> 0 then
  begin
    LoadMenu := False;
    ErrorBox('Fehler beim Lesen der Men'#129'datei', HomeDir + 'dxmenu.dat');
  end;
end;

function AdminMenu: Integer;
const
  Sel: Byte = 1;
type
  TEntry = record
    Text: string[22];
    Hot: Byte;
  end;
var
  Key: Word;
  Items: array[1..11] of TEntry;
  Still: Boolean;
  OldY, OldX: Byte;

procedure DrawMenu;
var
  I: Byte;
begin
  MouseHide;
  for I := 1 to 11 do
    if I = Sel then
    begin
      WriteXYFB(1, I, 0, 2, Items[I].Text);
      if Items[I].Hot > 0 then WriteXYFB(Items[I].Hot, I, 4, 2, Items[I].Text[Items[I].Hot]);
    end
    else
    begin
      WriteXY(1, I, Items[I].Text);
      if Items[I].Hot > 0 then WriteXYF(Items[I].Hot, I, 4, Items[I].Text[Items[I].Hot]);
    end;
  MouseShow;
end;

begin
  Items[1].Text := #205#205' Gruppen '#205#205#205#205;
  Items[1].Hot := 0;
  Items[2].Text := ' Neu           ';
  Items[2].Hot := 2;
  Items[3].Text := ' L'#148'schen       ';
  Items[3].Hot := 2;
  Items[4].Text := ' Sortieren     ';
  Items[4].Hot := 2;
  Items[5].Text := ' Umbenennen    ';
  Items[5].Hot := 2;
  Items[6].Text := #205#205' Eintr'#132'ge '#205#205#205;
  Items[6].Hot := 0;
  Items[7].Text := ' L'#148'schen       ';
  Items[7].Hot := 3;
  Items[8].Text := ' Sortieren     ';
  Items[8].Hot := 3;
  Items[9].Text := ' Bearbeiten    ';
  Items[9].Hot := 3;
  Items[10].Text := #196#196#196#196#196#196#196#196#196#196#196#196#196#196#196;
  Items[10].Hot := 0;
  Items[11].Text := ' Beenden    Esc';
  Items[11].Hot := 2;
  OpenDialog;
  Frame(62, 2, 15, 11, 11, 3, 1, 1);
  Window(63, 3, 80, ScreenRows);
  MouseShow;
  DrawMenu;
  Still := True;
  OldY := MouseY;
  OldX := MouseX;
  WaitRelease;
  repeat
    GetKey(Key);
    if (OldY <> MouseY) or (OldX <> MouseX) then
    begin
      Still := False;
      OldY := MouseY;
      OldX := MouseX;
    end;
    case Key of
      $423: ShowHelp(14);
      $438:
        begin
          Still := True;
          Inc(Sel);
          if Sel > 11 then Sel := 1;
          if (Sel = 5) or (Sel = 12) then Inc(Sel);
          DrawMenu;
        end;
      $430:
        begin
          Still := True;
          Dec(Sel);
          if Sel < 1 then Sel := 11;
          if (Sel = 5) or (Sel = 12) then Dec(Sel);
          DrawMenu;
        end;
    end;
    case LoCaseW(Key) of
      'n': begin Sel := 2; Key := 13; end;
      'l': begin Sel := 3; Key := 13; end;
      's': begin Sel := 4; Key := 13; end;
      'u': begin Sel := 5; Key := 13; end;
      #148: begin Sel := 7; Key := 13; end;
      'o': begin Sel := 8; Key := 13; end;
      'e': begin Sel := 9; Key := 13; end;
      'b': begin Sel := 11; Key := 13; end;
    end;
    if (MouseButton = 1) and (MouseX > 62) and (MouseX < 78) and (MouseY >= 3) and (MouseY < 14) and
      (MouseY <> 3) and (MouseY <> 8) and (MouseY <> 12) then
    begin
      repeat
        Idle;
        if (MouseY >= 3) and (MouseY < 14) and (MouseY <> 3) and (MouseY <> 8) and (MouseY <> 12) and
          (Sel <> MouseY - 3 + 1) then
        begin
          Sel := MouseY - 3 + 1;
          DrawMenu;
        end;
      until MouseButton = 0;
      if (MouseButton = 0) and (MouseX > 62) and (MouseX < 78) and (MouseY >= 3) and (MouseY < 14) and
        (MouseY <> 3) and (MouseY <> 8) and (MouseY <> 12) then Key := 13;
    end;
    if MouseOutside(62, 78, 2, 14) then Key := 27;
    if (MouseX > 62) and (MouseX < 78) and (MouseY >= 3) and (MouseY < 14) and not Still and
      (Sel <> MouseY - 3 + 1) then
    begin
      Sel := MouseY - 3 + 1;
      DrawMenu;
    end;
  until (Key = 13) or (Key = 27) or (Key = $42C) or (Key = $433) or (MouseButton = 2);
  if Key = 13 then AdminMenu := Sel else AdminMenu := 0;
  PopScreen(DlgStack);
end;

{$I+}
function MainMenu(var Prog: string; var Pos: Word; var Mode: Byte): Boolean;
var
  I, J, K: Integer;
  Dummy: Word;
  S: string;
  Btn: array[1..21] of TBtn;
  Hit: array[1..21] of Boolean;
  Click, Any: Boolean;
  Idx, Cur: ShortInt;
  Key: Word;
  XPos, YPos: array[1..21] of Byte;
  OldBorder: Byte;
  Bar: TMenuBar;
  LastGroup: Byte;
  Quit, Run: Boolean;
  Flag: Byte;
  P: Pointer;
  B17AF, MX, MY, NewCur: Byte;
  W: TWinState;
  D: DirStr;
  N: NameStr;

procedure DrawLabel(N: Byte; Hi: Boolean);
var
  I, C: Byte;
begin
  C := 4;
  if Hi then SetColor(0, 2) else SetColor(0, 3);
  MouseHide;
  WriteXY(Bar.Items[N]^.X - 1, 1, ' ');
  GotoXY(Bar.Items[N]^.X, 1);
  I := 0;
  repeat
    Inc(I);
    if Bar.Items[N]^.Text[I] = '~' then
    begin
      Inc(I);
      WriteF(C, Bar.Items[N]^.Text[I]);
    end
    else Write(Bar.Items[N]^.Text[I]);
  until I >= Length(Bar.Items[N]^.Text);
  Write(' ');
  MouseShow;
end;

procedure SwitchLabel(New, Old: Byte);
var
  W: TWinState;
  Dummy: Word;
begin
  SaveWin(W);
  if Old <= Menu^.Count + 1 then DrawLabel(Old, False);
  if New <= Menu^.Count + 1 then DrawLabel(New, True);
  RestoreWin(W);
end;

procedure ShowGroup;
var
  I: Integer;
  P: Byte;
begin
  if CurGroup < 1 then CurGroup := Menu^.Count;
  if Menu^.Count < CurGroup then CurGroup := 1;
  Btn[Cur].Init(True, XPos[Cur], YPos[Cur], 14, 0, 15, 7, 1,
    Center(Menu^.Groups[CurGroup].Items[Cur].Name, 18));
  P := (18 - Length(Menu^.Groups[CurGroup].Items[Cur].Name)) shr 1 + 1;
  WriteXYFB(XPos[Cur] + P, YPos[Cur] + 1, 14, 1, ' ' + Menu^.Groups[CurGroup].Items[Cur].Name + ' ');
  for I := 1 to 21 do
  begin
    Any := False;
    if Cur <> I then
      Btn[I].Init(False, XPos[I], YPos[I], 14, 0, 15, 7, 1, Center(Menu^.Groups[CurGroup].Items[I].Name, 18));
  end;
  SwitchLabel(CurGroup + 1, LastGroup + 1);
end;

procedure DeleteEntry;
var
  Dummy: Byte;
  B: TButton2;
  Yes, No: Boolean;
  Key: Word;
begin
  if Menu^.Groups[CurGroup].Items[Cur].Name <> '' then
  begin
    OpenDialog;
    Frame(25, 10, 29, 4, 11, 6, 0, 1);
    WriteCenterXYF(1, 1, 29, 11, Menu^.Groups[CurGroup].Items[Cur].Name + ' l'#148'schen?');
    InitButton2(True, 3, 2, 16, 2, 14, 0, 11, 6, '   Ja   ', '  Nein  ', B);
    MouseShow;
    repeat
      HandleButton2(Yes, No, Key, B);
      if LoCaseW(Key) = 'j' then Yes := True;
      if LoCaseW(Key) = 'n' then No := True;
      if IsCancel(Key) or MouseOutside(25, 55, 10, 15) then No := True;
    until Yes or No;
    PopScreen(DlgStack);
    if No then WaitRelease
    else
    begin
      Menu^.Groups[CurGroup].Items[Cur].Name := '';
      Menu^.Groups[CurGroup].Items[Cur].Prog := '';
      SaveMenu;
      ShowGroup;
      WaitRelease;
    end;
  end;
end;

function Admin: Word;
var
  W: TWinState;
  Sel: Integer;
begin
  SaveWin(W);
  Admin := 0;
  SwitchLabel(1, CurGroup + 1);
  Sel := AdminMenu;
  SwitchLabel(CurGroup + 1, 1);
  case Sel of
    2: if AddGroup(Bar) then SaveMenu;
    3: if GroupDialog(1, Bar) then SaveMenu;
    4: if SortGroups(Bar) then SaveMenu;
    5: if GroupDialog(2, Bar) then SaveMenu;
    7: DeleteEntry;
    8: begin
         SortItems(CurGroup);
         SaveMenu;
       end;
    9: if EditGroup(CurGroup, Cur) then SaveMenu;
    11: Admin := $42C;
  end;
  RestoreWin(W);
  if Menu^.Count < CurGroup then CurGroup := Menu^.Count;
  ShowGroup;
  WaitRelease;
end;

{$I-}
procedure SaveCfg;
var
  F: file of TConfig;
  Cfg: TConfig;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  InOutRes := 0;
  Read(F, Cfg);
  InOutRes := 0;
  Close(F);
  if (IOResult = 0) and (Cfg.Id = IniId) then
  begin
    Cfg.MenuPos := Pos;
    Rewrite(F);
    InOutRes := 0;
    Write(F, Cfg);
    InOutRes := 0;
    Close(F);
    InOutRes := 0;
  end;
end;

function FrameMenu(X, Y: Byte): Char;
const
  Sel: Byte = 1;
var
  Key: Word;
  Items: array[1..6] of string[16];
  Still: Boolean;
  OldY, OldX: Byte;
  Dummy: array[1..$14F] of Byte;
  Done: Boolean;

procedure DrawSel;
var
  I: Byte;
begin
  MouseHide;
  for I := 1 to 6 do
    if I = Sel then WriteXYFB(1, I, 0, 2, Items[I])
    else WriteXY(1, I, Items[I]);
  MouseShow;
end;

begin
  Items[1] := FillStr(#196, 16);
  Items[2] := FillStr('*', 16);
  Items[3] := FillStr('~', 16);
  Items[4] := FillStr(#219, 16);
  Items[5] := FillStr('.', 16);
  Items[6] := FillStr('-', 16);
  OpenDialog;
  FrameMenu := #0;
  Frame(X - 1, Y - 1, 16, 6, 11, 3, 0, 1);
  Window(X, Y, 80, ScreenRows);
  MouseShow;
  DrawSel;
  Still := True;
  OldY := MouseY;
  OldX := MouseX;
  WaitRelease;
  Done := False;
  repeat
    GetKey(Key);
    if (OldY <> MouseY) or (OldX <> MouseX) then
    begin
      Still := False;
      OldY := MouseY;
      OldX := MouseX;
    end;
    case Key of
      $423: ShowHelp(14);
      $438:
        begin
          Still := True;
          Inc(Sel);
          if Sel > 6 then Sel := 1;
          DrawSel;
        end;
      $430:
        begin
          Still := True;
          Dec(Sel);
          if Sel < 1 then Sel := 6;
          DrawSel;
        end;
    end;
    if Key = 13 then Still := True;
    if (MouseButton = 1) and (X - 1 < MouseX) and (X + 16 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) then
    begin
      repeat
        Idle;
        if (Y <= MouseY) and (Y + 6 > MouseY) and (Sel <> MouseY - Y + 1) then
        begin
          Sel := MouseY - Y + 1;
          DrawSel;
        end;
      until MouseButton = 0;
      if (MouseButton = 0) and (X - 1 < MouseX) and (X + 16 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) then
        Key := 13;
    end;
    if MouseOutside(X - 1, X + 16, Y - 1, Y + 6) then Key := 27;
    if (X - 1 < MouseX) and (X + 16 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) and not Still and
      (Sel <> MouseY - Y + 1) then
    begin
      Sel := MouseY - Y + 1;
      DrawSel;
    end;
    if (Key = 27) or (Key = $42C) or (MouseButton = 2) then Done := True;
  until (Key = 13) or Done;
  CloseDialog;
  if not Done then
    case Sel of
      1: FrameMenu := #196;
      2: FrameMenu := '*';
      3: FrameMenu := '~';
      4: FrameMenu := #219;
      5: FrameMenu := '.';
      6: FrameMenu := '-';
    end;
end;

{$I+}
function ItemMenu(G, It, X, Y: Byte): Boolean;
const
  Sel: Byte = 1;
type
  TEntry = record
    Text: string[16];
    Hot: Byte;
  end;
var
  Key: Word;
  J, K: Integer;
  Target: Word;
  Items: array[1..6] of TEntry;
  Still: Boolean;
  OldY, OldX: Byte;
  S: string;
  D: DirStr;
  Nm: NameStr;
  Cancel, Ok: Boolean;
  Ch: Char;

procedure DrawSel;
var
  I: Byte;
begin
  MouseHide;
  for I := 1 to 6 do
    if I = Sel then
    begin
      WriteXYFB(1, I, 0, 2, Items[I].Text);
      if Items[I].Hot > 0 then WriteXYFB(Items[I].Hot, I, 4, 2, Items[I].Text[Items[I].Hot]);
    end
    else
    begin
      WriteXY(1, I, Items[I].Text);
      if Items[I].Hot > 0 then WriteXYF(Items[I].Hot, I, 4, Items[I].Text[Items[I].Hot]);
    end;
  MouseShow;
end;

begin
  Items[1].Text := ' Neu         ';
  Items[1].Hot := 2;
  Items[2].Text := ' '#142'ndern      ';
  Items[2].Hot := 2;
  Items[3].Text := ' L'#148'schen     ';
  Items[3].Hot := 2;
  Items[4].Text := ' Vertauschen ';
  Items[4].Hot := 2;
  Items[5].Text := ' Trenner     ';
  Items[5].Hot := 2;
  Items[6].Text := ' Beenden     ';
  Items[6].Hot := 2;
  OpenDialog;
  ItemMenu := False;
  case X of
    7..26: X := 10;
    31..50: X := 34;
    55..74: X := 58;
  end;
  case Y of
    19: Y := 12;
    22: Y := 15;
  else
    Inc(Y, 2);
  end;
  Frame(X - 1, Y - 1, 13, 6, 11, 3, 1, 1);
  Window(X, Y, 80, ScreenRows);
  MouseShow;
  DrawSel;
  Still := True;
  OldY := MouseY;
  OldX := MouseX;
  WaitRelease;
  repeat
    GetKey(Key);
    if (OldY <> MouseY) or (OldX <> MouseX) then
    begin
      Still := False;
      OldY := MouseY;
      OldX := MouseX;
    end;
    case Key of
      $423: ShowHelp(14);
      $438:
        begin
          Still := True;
          Inc(Sel);
          if Sel > 6 then Sel := 1;
          DrawSel;
        end;
      $430:
        begin
          Still := True;
          Dec(Sel);
          if Sel < 1 then Sel := 6;
          DrawSel;
        end;
    end;
    case LoCaseW(Key) of
      'n': begin Sel := 1; Key := 13; end;
      #132: begin Sel := 2; Key := 13; end;
      'l': begin Sel := 3; Key := 13; end;
      'v': begin Sel := 4; Key := 13; end;
      't': begin Sel := 5; Key := 13; end;
      'b': begin Sel := 6; Key := 13; end;
    end;
    if Key = $43A then
    begin
      Sel := 1;
      Key := 13;
    end;
    if Key = $43B then
    begin
      Sel := 3;
      Key := 13;
    end;
    if Key = 13 then Still := True;
    if (MouseButton = 1) and (X - 1 < MouseX) and (X + 13 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) then
    begin
      repeat
        Idle;
        if (Y <= MouseY) and (Y + 6 > MouseY) and (Sel <> MouseY - Y + 1) then
        begin
          Sel := MouseY - Y + 1;
          DrawSel;
        end;
      until MouseButton = 0;
      if (MouseButton = 0) and (X - 1 < MouseX) and (X + 13 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) then
        Key := 13;
    end;
    if MouseOutside(X - 1, X + 13, Y - 1, Y + 6) then Key := 27;
    if (X - 1 < MouseX) and (X + 13 > MouseX) and (Y <= MouseY) and (Y + 6 > MouseY) and not Still and
      (Sel <> MouseY - Y + 1) then
    begin
      Sel := MouseY - Y + 1;
      DrawSel;
    end;
  until (Key = 13) or (Key = 27) or (Key = $42C) or (Key = $433) or (MouseButton = 2);
  CloseDialog;
  if Key = 13 then
    case Sel of
      1: begin
           S := SelectProgram;
           if S <> '' then
           begin
             FSplit(S, D, Nm, D);
             Nm[1] := UpCaseC(Nm[1]);
             Menu^.Groups[G].Items[It].Name := Nm;
             Menu^.Groups[G].Items[It].Prog := S;
             Menu^.Groups[G].Items[It].ChDir := True;
             EditItem(G, It);
             SaveMenu;
           end;
         end;
      2: if EditItem(G, It) then SaveMenu;
      3: DeleteEntry;
      6: ItemMenu := True;
      4: begin
           OpenDialog;
           Btn[It].Init(True, XPos[It], YPos[It], 14, 14, 2, 3, 1,
             Center(Menu^.Groups[CurGroup].Items[It].Name, 18));
           Window(1, 1, 80, 25);
           S := Menu^.Groups[G].Items[It].Name;
           GotoXY(1, 1);
           SetColor(14, 3);
           ClrEol;
           Write('    Eintrag ''''' + S + ''''' vertauschen: Klicken Sie auf den Zielschalter');
           MouseShow;
           Cancel := False;
           Ok := False;
           Window(5, 3, 80, ScreenRows);
           Target := It;
           repeat
             GetKey(Key);
             if (Key = $438) and (Target < 21) then
             begin
               Btn[Target].SetFocus(False);
               Inc(Target);
               Btn[Target].SetFocus(True);
             end;
             if (Key = $430) and (Target > 1) then
             begin
               Btn[Target].SetFocus(False);
               Dec(Target);
               Btn[Target].SetFocus(True);
             end;
             if (Key = $435) and (Target < 15) then
             begin
               Btn[Target].SetFocus(False);
               Inc(Target, 7);
               Btn[Target].SetFocus(True);
             end;
             if (Key = $433) and (Target > 7) then
             begin
               Btn[Target].SetFocus(False);
               Dec(Target, 7);
               Btn[Target].SetFocus(True);
             end;
             for J := 1 to 21 do
             begin
               Hit[J] := Btn[J].Clicked;
               if Hit[J] then
               begin
                 Target := J;
                 Ok := True;
               end;
               if Btn[J].Focused then
               begin
                 Target := J;
                 for K := 1 to 21 do
                   if K <> J then Btn[K].SetFocus(False);
               end;
             end;
             if IsCancel(Key) then Cancel := True;
             if Key = 13 then Ok := True;
           until Cancel or Ok;
           if Ok then
             if It <> Target then
             begin
               D := Menu^.Groups[G].Items[Target].Name;
               S := Menu^.Groups[G].Items[Target].Prog;
               Ok := Menu^.Groups[G].Items[Target].ChDir;
               Menu^.Groups[G].Items[Target].Name := Menu^.Groups[G].Items[It].Name;
               Menu^.Groups[G].Items[Target].Prog := Menu^.Groups[G].Items[It].Prog;
               Menu^.Groups[G].Items[Target].ChDir := Menu^.Groups[G].Items[It].ChDir;
               Menu^.Groups[G].Items[It].Name := D;
               Menu^.Groups[G].Items[It].Prog := S;
               Menu^.Groups[G].Items[It].ChDir := Ok;
               Cur := Target;
               SaveMenu;
             end;
           PopScreen(DlgStack);
         end;
      5: begin
           Ch := FrameMenu(X - 1, Y);
           if Ch <> #0 then
           begin
             Menu^.Groups[G].Items[It].Name := FillStr(Ch, 18);
             Menu^.Groups[G].Items[It].Prog := '';
             Menu^.Groups[G].Items[It].ChDir := True;
             SaveMenu;
           end;
         end;
    end;
end;

begin
  CurGroup := Lo(Pos);
  LastGroup := 0;
  ClockHidden := False;
  InitMouse;
  MainMenu := False;
  OpenDialog;
  Click := False;
  DateOff;
  ClockOff;
  OldBorder := BorderColor;
  BorderColor := 3;
  RestoreBorder;
  Window(1, 1, 80, ScreenRows);
  SetColor(4, 7);
  ClrScr;
  MouseShow;
  Flag := 0;
  if not LoadMenu then
  begin
    ErrorBox('Wenn noch keine Datei bzw. Gruppe existiert', 'mu'#225' als erstes eine Gruppe eingef'#129'gt werden!');
    Flag := 99;
  end;
  MouseHide;
  Bar.Init;
  if Flag = 99 then
  begin
    MouseShow;
    if AddGroup(Bar) then SaveMenu
    else
    begin
      Bar.Done;
      PopScreen(DlgStack);
      BorderColor := OldBorder;
      RestoreBorder;
      WaitRelease;
      DateOn;
      ClockOn;
      Exit;
    end;
    MouseHide;
  end;
  ClockHidden := False;
  GotoXY(1, ScreenRows);
  SetColor(0, 3);
  ClrEol;
  WriteXYF(3, ScreenRows, 0, #17#17' '#16#16);
  WriteXY(15, ScreenRows, 'F1..F7');
  WriteXY(36, ScreenRows, 'Alt-F1..F7');
  WriteXY(58, ScreenRows, 'Strg-F1..F7');
  WriteXY(74, ScreenRows, 'F9 '#24#24);
  for I := 2 to 24 do
  begin
    WriteXY(1, I, '  ');
    WriteXY(79, I, '  ');
  end;
  for I := 1 to 7 do
  begin
    GotoXY(1, I * 3 + 1);
    Write('F', I);
  end;
  Frame(4, 2, 72, 21, 15, 7, 1, 0);
  if BigCursor then
  begin
    Frame(1, 25, 78, 1, 11, 3, 0, 0);
    Write('       Taste <Einfg> = Eintr'#132'ge bearbeiten   F9 oder Alt-V = Verwaltung');
  end;
  Window(5, 3, 80, ScreenRows);
  MouseShow;
  for J := 0 to 2 do
    for I := 0 to 6 do
    begin
      Idx := I + 1 + J * 7;
      XPos[Idx] := J * 24 + 2;
      YPos[Idx] := I * 3 + 1;
    end;
  Cur := Hi(Pos);
  if Cur < 1 then Cur := 1;
  if Cur > 21 then Cur := 1;
  ShowGroup;
  B17AF := 0;
  repeat
    GetKey(Key);
    Any := False;
    for I := 1 to 21 do
    begin
      Hit[I] := Btn[I].Clicked;
      Any := Any or Hit[I];
      if Hit[I] then Cur := I;
      if Btn[I].Focused then
      begin
        Cur := I;
        for K := 1 to 21 do
          if K <> I then Btn[K].SetFocus(False);
      end;
    end;
    if MouseButton = 1 then
    begin
      if ((MouseX = 3) or (MouseX = 4)) and (ScreenRows = MouseY) then
      begin
        SaveWin(W);
        MouseHide;
        WriteXYFB(2, ScreenRows, 14, 3, #17#17#196);
        MouseShow;
        repeat
        until (MouseButton = 0) or (ScreenRows <> MouseY) or (MouseX < 2) or (MouseX > 4);
        MouseHide;
        WriteXYFB(2, ScreenRows, 0, 3, ' '#17#17);
        MouseShow;
        if (MouseX > 1) and (MouseX < 5) and (ScreenRows = MouseY) then Key := $431;
        RestoreWin(W);
      end;
      if ((MouseX = 6) or (MouseX = 7)) and (ScreenRows = MouseY) then
      begin
        SaveWin(W);
        MouseHide;
        WriteXYFB(6, ScreenRows, 14, 3, #196#16#16);
        MouseShow;
        repeat
        until (MouseButton = 0) or (ScreenRows <> MouseY) or (MouseX < 6) or (MouseX > 8);
        MouseHide;
        WriteXYFB(6, ScreenRows, 0, 3, #16#16' ');
        MouseShow;
        if (MouseX >= 6) and (MouseX <= 8) and (ScreenRows = MouseY) then Key := $439;
        RestoreWin(W);
      end;
    end;
    for I := 1 to Bar.Count do
      if (Ord(LoCaseW(Key)) = Bar.Items[I]^.Key) and (I > 1) then CurGroup := I - 1;
    if Key = $417 then Key := Admin;
    if Key = $43B then DeleteEntry;
    if (MouseButton = 1) and (MouseY = 1) then
      for I := 1 to Bar.Count do
        if (Bar.Items[I]^.X - 1 <= MouseX) and (Bar.Items[I]^.X + Length(Bar.Items[I]^.Text) > MouseX) and
          (MouseY = 1) and (I - 1 <> CurGroup) and (MouseButton = 1) then
        begin
          if I = 1 then Key := Admin;
          if I > 1 then CurGroup := I - 1;
        end;
    case Key of
      $42F: Cur := 1;
      $437: Cur := 21;
      $435: Cur := Cur + 7;
      $433: Cur := Cur - 7;
      $430: Cur := Cur - 1;
      $438: Cur := Cur + 1;
      $439, 9: Inc(CurGroup);
      $431: Dec(CurGroup);
      $42B: Key := Admin;
      $423: Cur := 1;
      $424: Cur := 2;
      $425: Cur := 3;
      $426: Cur := 4;
      $427: Cur := 5;
      $428: Cur := 6;
      $429: Cur := 7;
      $450: Cur := 8;
      $451: Cur := 9;
      $452: Cur := 10;
      $453: Cur := 11;
      $454: Cur := 12;
      $455: Cur := 13;
      $456: Cur := 14;
      $446: Cur := 15;
      $447: Cur := 16;
      $448: Cur := 17;
      $449: Cur := 18;
      $44A: Cur := 19;
      $44B: Cur := 20;
      $44C: Cur := 21;
      $43A:
        begin
          S := SelectProgram;
          if S <> '' then
          begin
            FSplit(S, D, N, D);
            N[1] := UpCaseC(N[1]);
            Menu^.Groups[CurGroup].Items[Cur].Name := N;
            Menu^.Groups[CurGroup].Items[Cur].Prog := S;
            Menu^.Groups[CurGroup].Items[Cur].ChDir := True;
            EditItem(CurGroup, Cur);
            SaveMenu;
            ShowGroup;
          end;
        end;
    end;
    if Cur > 21 then
    begin
      Cur := Cur - 21;
      Inc(CurGroup);
    end;
    if Cur < 1 then
    begin
      Cur := Cur + 21;
      Dec(CurGroup);
    end;
    if LastGroup <> CurGroup then ShowGroup;
    LastGroup := CurGroup;
    if Key <> 0 then
    begin
      Btn[Cur].SetFocus(True);
      for I := 1 to 21 do
        if Cur <> I then Btn[I].SetFocus(False);
      if Click then WaitRelease;
      Click := False;
    end;
    MX := MouseX;
    MY := MouseY;
    if (Key = 10) or ((MouseButton = 2) and (MY in [4, 7, 10, 13, 16, 19, 22]) and
      (MX in [7..26, 31..50, 55..74])) then
    begin
      NewCur := MY div 3;
      case MX of
        31..50: Inc(NewCur, 7);
        55..74: Inc(NewCur, 14);
      end;
      if Key = 10 then
      begin
        NewCur := Cur;
        MY := (Cur - 1) mod 7 * 3 + 4;
        MX := (Cur - 1) div 7 * 25 + 8;
      end;
      Cur := NewCur;
      ShowGroup;
      if ItemMenu(CurGroup, NewCur, MX, MY) then Key := $42C;
      ShowGroup;
    end;
    Quit := (Key = 27) or (Key = $42C);
    Run := ((Key = 13) or ((Key >= $423) and (Key <= $429)) or ((Key >= $450) and (Key <= $456)) or
      ((Key >= $446) and (Key <= $44C)) or Any) and (Menu^.Groups[CurGroup].Items[Cur].Prog <> '');
  until Quit or Run;
  if Run then
  begin
    Prog := Menu^.Groups[CurGroup].Items[Cur].Prog;
    Mode := 1;
    if Menu^.Groups[CurGroup].Items[Cur].ChDir then Mode := 2;
    MainMenu := True;
  end;
  Bar.Done;
  ClockOn;
  DateOn;
  PopScreen(DlgStack);
  Dispose(Menu);
  BorderColor := OldBorder;
  RestoreBorder;
  Pos := Cur shl 8 + CurGroup;
  SaveCfg;
  WaitRelease;
end;

end.
