{$O+,F+,G+,S-,I-,V-}
unit UserMenu;

interface

uses Lists;

type
  Str18 = string[18];
  Str30 = string[30];
  TMenuItem = record
    Name: string[18];
    Prog: string[78];
    ChDir: Boolean;
  end;
  TGroup = record
    Name: string[30];
    Flag: Byte;
    Items: array[1..21] of TMenuItem;
  end;
  TMenu = record
    Count: Byte;
    Groups: array[1..15] of TGroup;
  end;
  PMenu = ^TMenu;
  TGroupList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
  TItemList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;
  PLabel = ^TLabel;
  TLabel = object
    Text: Str18;
    X: Byte;
    Key: Word;
    Num: Byte;
    procedure Init(ANum: Byte; AText: Str18; AX: Byte; AKey: Word);
    procedure Draw(Hi: Boolean);
  end;
  TMenuBar = object
    Count: Byte;
    Items: array[1..16] of PLabel;
    procedure Init;
    procedure Redraw;
    procedure Done;
  end;

var
  Menu: PMenu;
  CurGroup: Integer;

function GroupDialog(Mode: Byte; var Bar: TMenuBar): Boolean;
function SortGroups(var Bar: TMenuBar): Boolean;
function AddGroup(var Bar: TMenuBar): Boolean;
function EditItem(G, I: Byte): Boolean;
function EditGroup(G, Start: ShortInt): Boolean;
procedure SortItems(G: Byte);

implementation

uses Dos, Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Buttons, Dialogs, Status, Help, Browser;

const
  Blanks = '                                                                ' +
           '                                                                ' +
           '                                                                ' +
           '                                                               ';

var
  Br: ^TBrowser;

procedure TGroupList.DrawLine(Line: Integer);
begin
  Text := '';
  if Line + Top <= Menu^.Count then Text := ' ' + Menu^.Groups[Line + Top].Name;
  TList.DrawLine(Line);
end;

procedure TItemList.DrawLine(Line: Integer);
var
  N: string[3];
begin
  if Line > 0 then
  begin
    Str(Line + Top:2, N);
    N := N + '.';
    Text := N;
    if Line + Top <= Count then
      Text := Copy(' ' + N + Menu^.Groups[CurGroup].Items[Line + Top].Name + Blanks, 1, 23) +
        Shorten(Menu^.Groups[CurGroup].Items[Line + Top].Prog, 42);
    TList.DrawLine(Line);
  end;
end;

procedure TLabel.Init(ANum: Byte; AText: Str18; AX: Byte; AKey: Word);
begin
  Text := AText;
  X := AX;
  Key := AKey;
  Num := ANum;
  Draw(False);
end;

procedure TLabel.Draw(Hi: Boolean);
var
  I, C: Byte;
begin
  C := 4;
  if Hi then SetColor(0, 2) else SetColor(0, 3);
  MouseHide;
  WriteXY(X - 1, 1, ' ');
  GotoXY(X, 1);
  I := 0;
  repeat
    Inc(I);
    if Text[I] = '~' then
    begin
      Inc(I);
      WriteF(C, Text[I]);
    end
    else Write(Text[I]);
  until I >= Length(Text);
  Write(' ');
  MouseShow;
end;

function GroupDialog(Mode: Byte; var Bar: TMenuBar): Boolean;
var
  List: TGroupList;
  Key: Word;
  Dummy: Word;
  Dummy2: TButton2;
  Res: Integer;
  W: Byte;

procedure DeleteGroup(N: Byte);
var
  I: Integer;
  Yes, No: Boolean;
  B: TButton2;
begin
  if (N > Menu^.Count) or (Menu^.Count < 1) then Exit;
  if Menu^.Count = 1 then
    MsgBox('Gruppe l'#148'schen:', 'Die letzte Gruppe darf nicht gel'#148'scht werden!')
  else
  begin
    OpenDialog;
    I := List.Cur + 7;
    if I > 16 then I := I - 8;
    Frame(16, I, 28, 4, 15, 5, 0, 1);
    Write('   Diese Gruppe l'#148'schen?');
    InitButton2(False, 3, 2, 15, 2, 14, 0, 15, 5,
    '   Ja   ',
    '  Nein  ', B);
    MouseShow;
    repeat
      HandleButton2(Yes, No, Key, B);
      if LoCaseW(Key) = 'j' then Yes := True;
      if LoCaseW(Key) = 'n' then No := True;
      if IsCancel(Key) then No := True;
    until Yes or No;
    PopScreen(DlgStack);
    if No then Exit;
    GroupDialog := True;
    for I := N to Menu^.Count do
      Menu^.Groups[I] := Menu^.Groups[I + 1];
    Menu^.Groups[Menu^.Count].Name := '';
    if List.Cur + List.Top = Menu^.Count then
      if List.Cur > 1 then Dec(List.Cur) else Dec(List.Top);
    Dec(Menu^.Count);
    List.SetData(Menu^.Count, 15, List.Cur, List.Top);
  end;
end;

procedure RenameGroup(N: Byte);
var
  S: string;
begin
  if (N > Menu^.Count) or (Menu^.Count < 1) then Exit;
  OpenDialog;
  Frame(25, List.Cur + 4, W, 3, 15, 5, 0, 1);
  MouseShow;
  S := Menu^.Groups[N].Name;
  InputLine(28, List.Cur + 6, 27, 53, S, 20, 20, #216, False);
  if S[Length(S)] = '~' then Dec(S[0]);
  if S <> '' then
  begin
    GroupDialog := True;
    Menu^.Groups[N].Name := S;
  end;
  PopScreen(DlgStack);
  List.DrawAll;
end;

begin
  OpenDialog;
  W := 26;
  GroupDialog := False;
  Frame(25, 3, W, 1, 11, 3, 0, 1);
  if Mode = 1 then WriteCenter(W - 1, ' Gruppe l'#148'schen')
  else if Mode = 2 then WriteCenter(W - 1, ' Gruppe umbenennen');
  Frame(25, 6, W, 15, 11, 3, 0, 1);
  List.Init(0, 3, 14, 1, 26, 7, 15, Menu^.Count, W, False);
  MouseShow;
  repeat
    GetKey(Key);
    Res := List.Handle(Key);
    if (List.Cur = MouseY - 7) and DoubleClick(MouseX, MouseY) then Key := 13;
    if Key = 13 then
      if Mode = 1 then DeleteGroup(List.Cur + List.Top)
      else if Mode = 2 then RenameGroup(List.Cur + List.Top);
  until IsCancel(Key) or MouseOutside(25, 55, 3, 22);
  PopScreen(DlgStack);
  InitMouse;
  Bar.Redraw;
end;

function SortGroups(var Bar: TMenuBar): Boolean;
var
  I: Byte;
  Key: Word;
  Cur, Count, Sel: Byte;
  B: TButton;

procedure Swap(A, B: Byte);
var
  T: TGroup;
begin
  T := Menu^.Groups[A];
  Menu^.Groups[A] := Menu^.Groups[B];
  Menu^.Groups[B] := T;
  SortGroups := True;
end;

procedure DrawGroup(N: Byte);
begin
  MouseHide;
  WriteXY(1, N, ' ' + Copy(Menu^.Groups[N].Name + Blanks, 1, 19));
  MouseShow;
end;

procedure HiGroup(N: Byte);
begin
  MouseHide;
  if Sel = 0 then
    WriteXYFB(1, N, 0, 2, ' ' + Copy(Menu^.Groups[N].Name + Blanks, 1, 19))
  else
    WriteXYFB(1, N, 14, 0, ' ' + Copy(Menu^.Groups[N].Name + Blanks, 1, 19));
  MouseShow;
end;

procedure GroupUp;
begin
  if Cur = 1 then Exit;
  if Sel <> 0 then Swap(Cur, Cur - 1);
  DrawGroup(Cur);
  Dec(Cur);
  HiGroup(Cur);
end;

procedure GroupDown;
begin
  if Cur = Count then Exit;
  if Sel <> 0 then Swap(Cur, Cur + 1);
  DrawGroup(Cur);
  Inc(Cur);
  HiGroup(Cur);
end;

procedure GroupClick(N: Byte);
begin
  if (Cur = N) or (N > Count) then Exit;
  if Sel <> 0 then Swap(Cur, N);
  DrawGroup(Cur);
  Cur := N;
  HiGroup(Cur);
end;

begin
  Sel := 0;
  Count := Menu^.Count;
  SortGroups := False;
  if Count = 1 then ErrorBox('Gruppe sortieren:', 'Wie soll ich denn nur eine Gruppe sortieren??');
  if Count > 1 then
  begin
    OpenDialog;
    SetColor(0, 5);
    WriteXYFB(3, ScreenRows, 14, 0, '       <Return> = Auswahl/Setzen  <Cursor> = Verschieben  <Esc> = Ende      ');
    Frame(30, 2, 20, 21, 15, 5, 0, 0);
    WriteXY(1, 1, ' Gruppen sortieren: ');
    WriteXY(1, 2, #196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196);
    Window(31, 5, 80, ScreenRows);
    TextColor(0);
    WriteXY(1, 16, #196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196);
    for I := 2 to Menu^.Count do DrawGroup(I);
    Cur := 1;
    HiGroup(Cur);
    InitButton(True, 2, 17, 14, 14, 15, 5,
    '      OK      ', B);
    MouseShow;
    repeat
      GetKey(Key);
      if (Mouse.MouseButton = 1) and (MouseX > 30) and (MouseX < 51) and (MouseY >= 5) and (MouseY <= 20) and
        (Cur = MouseY - 4) and DoubleClick(MouseX, MouseY) then Key := 13;
      case Key of
        $430: GroupUp;
        $438: GroupDown;
        13: if Sel = 0 then
            begin
              Sel := Cur;
              HiGroup(Cur);
            end
            else
            begin
              Sel := 0;
              HiGroup(Cur);
            end;
      end;
      if (Mouse.MouseButton = 1) and (MouseX > 30) and (MouseX < 51) and (MouseY >= 5) and (MouseY <= 20) then
        GroupClick(MouseY - 4);
      if MouseOutside(30, 51, 3, 24) then Key := $42C;
    until IsCancel(Key) or Buttons.MouseButton(B);
    PopScreen(DlgStack);
    Bar.Redraw;
  end;
  end;

function HotKey(S: Str30): Char;
var
  P: Byte;
begin
  HotKey := #255;
  P := Pos('~', S);
  if P <> 0 then HotKey := LoCaseW(Ord(S[P + 1]));
end;

procedure TMenuBar.Init;
var
  N, I, A, X: Byte;
  S: string;
begin
  A := TextAttr;
  SetColor(0, 3);
  GotoXY(1, 1);
  MouseHide;
  ClrEol;
  MouseShow;
  Count := 1;
  GetMem(Items[1], SizeOf(TLabel));
  Items[1]^.Init(1, '~Verwaltung', 68, $417);
  TextAttr := A;
  for I := 1 to Menu^.Count do
  begin
    Inc(Count);
    if I = 1 then X := 4
    else X := Items[I]^.X + Length(Items[I]^.Text) + 1;
    GetMem(Items[I + 1], SizeOf(TLabel));
    Items[I + 1]^.Init(I + 1, Menu^.Groups[I].Name, X, Ord(HotKey(Menu^.Groups[I].Name)));
  end;
end;

procedure TMenuBar.Redraw;
var
  I, A, X: Byte;
begin
  A := TextAttr;
  SetColor(0, 3);
  GotoXY(1, 1);
  MouseHide;
  ClrEol;
  MouseShow;
  Count := Menu^.Count + 1;
  TextAttr := A;
  for I := 1 to Menu^.Count do
  begin
    if I = 1 then X := 4
    else X := Items[I]^.X + Length(Items[I]^.Text) + 1;
    Items[I + 1]^.Init(I + 1, Menu^.Groups[I].Name, X, Ord(HotKey(Menu^.Groups[I].Name)));
  end;
  Items[1]^.Draw(False);
end;

procedure TMenuBar.Done;
var
  I: Integer;
begin
  for I := 1 to Count do FreeMem(Items[I], SizeOf(TLabel));
end;

function AddGroup(var Bar: TMenuBar): Boolean;
var
  Changed: Boolean;
  S: string[40];
  Ok, Cancel: Boolean;
  Key: Word;
  B: TButton2;
begin
  Changed := False;
  if Bar.Count > 15 then
    ErrorBox('Es sind maximal 15 Gruppen vorgesehen!', 'Mehr Eintr'#132'ge sind nicht m'#148'glich!')
  else if (Bar.Count > 2) and (Bar.Items[Bar.Count]^.X + Length(Bar.Items[Bar.Count]^.Text) > 65) then
    ErrorBox('Es ist kein Platz mehr!', 'Kein weiterer Eintrag mehr m'#148'glich!')
  else
  begin
    OpenDialog;
    Ok := True;
    Frame(13, 6, 53, 10, 11, 3, 0, 1);
    WriteCenterXY(1, 1, 53, 'Hinzuf'#129'gen eines neuen Men'#129'punktes:');
    WriteXY(6, 3, '  Neuer Men'#129'punkt:');
    WriteXYF(8, 3, 14, 'N');
    WriteXY(1, 5, '    Eine Tilde vor einem Buchstaben gleich Hotkey!');
    WriteXY(1, 6, '  Bsp.: Eingabe von "~Test" ergibt im Men'#129' ==> Test');
    WriteXYF(48, 6, 4, 'T');
    Window(1, 1, 80, ScreenRows);
    InitButton2(True, 16, 14, 42, 14, 14, 0, 11, 3,
    '         OK         ',
    '      Abbruch      ', B);
    MouseShow;
    S := '';
    Key := $419;
    repeat
      if (Key = $419) or (LoCaseW(Key) = 'n') or (Key = $430) or (Key = $3F7) or (Key = 9) or
        MouseOn(9, 37, 58) then
        InputLine(38, 9, 32, 66, S, 20, 20, #216, False);
      HandleButton2(Ok, Cancel, Key, B);
      if MouseOutside(13, 67, 6, 17) or IsCancel(Key) then Cancel := True;
    until Ok or Cancel;
    PopScreen(DlgStack);
    if Cancel or (S = '') then
    else
    begin
      if Ok and (Bar.Count > 2) and
        (Bar.Items[Bar.Count]^.X + Length(Bar.Items[Bar.Count]^.Text) + Length(S) > 66) then
      begin
        ErrorBox('Es ist kein Platz mehr!', 'Der Men'#129'eintrag wurde gek'#129'rzt oder gestrichen!');
        S := Copy(S, 1, 66 - Bar.Items[Bar.Count]^.X - Length(Bar.Items[Bar.Count]^.Text));
      end;
      if S[Length(S)] = '~' then Dec(S[0]);
      if S <> '' then
      begin
        Inc(Bar.Count);
        GetMem(Bar.Items[Bar.Count], SizeOf(TLabel));
        Changed := True;
        CurGroup := Bar.Count - 1;
        Inc(Menu^.Count);
        Menu^.Groups[CurGroup].Name := S;
        Menu^.Groups[CurGroup].Flag := 1;
        for Key := 1 to 21 do
        begin
          Menu^.Groups[CurGroup].Items[Key].Name := '';
          Menu^.Groups[CurGroup].Items[Key].Prog := '';
        end;
        Bar.Redraw;
      end;
    end;
  end;
  AddGroup := Changed;
end;

function EditItem(G, I: Byte): Boolean;
label
  NameField;
var
  Name: string[128];
  Prog: string[128];
  Dummy: Pointer;
  Key: Word;
  B: TButton2;
  Ok, Cancel, Flag: Boolean;
begin
  OpenDialog;
  EditItem := False;
  Name := Menu^.Groups[G].Items[I].Name;
  Prog := Menu^.Groups[G].Items[I].Prog;
  Flag := Menu^.Groups[G].Items[I].ChDir;
  Frame(21, 6, 50, 10, 11, 6, 0, 1);
  WriteXYF(4, 3, 14, 'N');
  WriteF(11, 'ame');
  WriteXYF(4, 6, 14, 'D');
  WriteF(11, 'atei');
  InputLine(25, 11, 19, 60, Prog, 42, 0, #216, False);
  WriteXYF(47, 8, 11, '[ ] ');
  WriteF(14, 'V');
  WriteF(11, 'erzeichniswechsel');
  if Flag then WriteXYF(48, 8, 11, 'X')
  else WriteXYF(48, 8, 11, ' ');
  InitButton2(True, 23, 14, 48, 14, 14, 0, 11, 6,
    '         OK         ',
    '      Abbruch      ', B);
  MouseShow;
  Key := $419;
  WaitRelease;
  repeat
    ResetButton2(B);
    if Key = $419 then
    begin
    NameField:
      if InputLine(25, 8, 24, 45, Name, 18, 18, #216, False) = 9 then Key := $408;
    end;
    if Key = $408 then
    begin
      Key := InputLine(25, 11, 24, 69, Prog, 42, 78, #216, False);
      if Key = $3F7 then goto NameField;
    end;
    RestoreButton2(B);
    repeat
      HandleButton2(Ok, Cancel, Key, B);
      if (Key = 9) or (Key = $438) or (LoCaseW(Key) = 'n') or MouseOn(8, 25, 44) then Key := $419;
      if MouseOn(11, 25, 68) or (LoCaseW(Key) = 'd') or (Key = $3F7) or (Key = $430) then Key := $408;
      if LoCaseW(Key) = 'o' then Ok := True;
      if LoCaseW(Key) = 'a' then Cancel := True;
      if (Key = $417) or (LoCaseW(Key) = 'v') or MouseOn(8, 47, 68) then
      begin
        Flag := not Flag;
        MouseHide;
        if Flag then WriteXYF(48, 8, 11, 'X')
        else WriteXYF(48, 8, 11, ' ');
        MouseShow;
        WaitRelease;
      end;
      if IsCancel(Key) or MouseOutside(21, 73, 6, 17) then Cancel := True;
    until Ok or Cancel or (Key = $419) or (Key = $408);
    if (Name = '') and (Prog = '') and Ok then
    begin
      Ok := False;
      Cancel := True;
    end;
  until Ok or Cancel;
  if Cancel then CloseDialog
  else
  begin
    Menu^.Groups[G].Items[I].Name := Name;
    Menu^.Groups[G].Items[I].Prog := Prog;
    Menu^.Groups[G].Items[I].ChDir := Flag;
    PopScreen(DlgStack);
    EditItem := True;
  end;
end;

function EditGroup(G, Start: ShortInt): Boolean;
label
  Buttons4;
var
  I: Integer;
  A1, A2, A3: Word;
  Key: Word;
  Changed: Boolean;
  List: TItemList;
  B: TButton4;
  Ins, Ren, Del, Done: Boolean;
  W: TWinState;
  OldDir: string[79];

procedure AddItems(N: Byte);
var
  FileName: string;
  Name: string;
  Chg: Boolean;
  B2: TButton3;
  B: TButton3;
  P: PButton3;
  Ins, Ent, Cancel: Boolean;
  D: DirStr;
  NS: NameStr;
  E: ExtStr;
  Key: Word;
  Toggle: Boolean;
  I: Integer;
begin
  P := @B;
  Toggle := True;
  OpenDialog;
  Chg := False;
  Window(1, 1, 80, ScreenRows);
  InitButton3(True, 6, 21, 31, 21, 54, 21, 14, 0, 2, 7,
    '      Einf'#129'gen      ',
    '     Laufwerk     ',
    '      Fertig      ', B);
  WriteXY(7, 5, 'Aktuelles Verzeichnis:                 ');
  Frame(6, 6, 25, 13, 11, 1, 0, 0);
  SetColor(11, 1);
  Writeln('       Einf'#129'gen:');
  Writeln('       '#221#221#221#221#221#221#221#221#221);
  Writeln('  Bitte w'#132'hlen Sie die');
  Writeln('  gew'#129'nschte Datei aus');
  Writeln;
  Writeln(' =====================>');
  Writeln;
  Writeln('  Angezeigt wird *.exe,');
  Writeln('  *.com und *.bat!');
  Writeln;
  Writeln('  Laufwerkswechsel auch');
  Writeln('   Alt-F1 oder Alt-F2');
  Name := '';
  Window(1, 1, 80, 25);
  for I := 6 to 20 do WriteXYB(33, I, 1, ' ');
  Frame(34, 6, 40, 13, 11, 1, 0, 0);
  GetMem(Br, SizeOf(TBrowser));
  Br^.Init(11, 1, 0, 3, 35, 5, 13, '.EXE', '.COM', '.BAT', 7);
  MouseShow;
  FileName := Br^.Execute(P);
  while FileName <> '' do
  begin
    ResetButton3(B);
    OpenDialog;
    FSplit(FileName, D, NS, E);
    Name := LowerStr(NS);
    Name[1] := UpCaseC(Name[1]);
    Frame(13, 7, 54, 11, 11, 3, 0, 1);
    WriteCenterXY(1, 1, 54, 'Eintragen oder Einf'#129'gen der Datei');
    WriteCenterXYF(1, 3, 54, 14, FileName);
    Str(N, E);
    WriteCenterXY(1, 5, 54, 'in das Benutzermen'#129' an Stelle ' + E + ' unter dem');
    WriteXYF(3, 7, 14, 'N');
    Write('amen:');
    InputLine(23, 14, 30, 61, Name, 18, 0, #216, False);
    InitButton3(True, 16, 16, 33, 16, 49, 16, 14, 0, 11, 3,
    '  Einf'#129'gen  ',
    ' Eintragen ',
    '  Abbrechen  ', B2);
    WriteXY(44, 14, '[X] ');
    WriteF(14, 'V');
    Write('erzeichniswechsel');
    MouseShow;
    Key := $430;
    repeat
      if (Key = $430) or (Key = $3F7) or (Key = 9) or (Key = $419) or (LoCaseW(Key) = 'n') or
        MouseOn(14, 23, 42) then
        InputLine(23, 14, 7, 30, Name, 18, 18, #216, False);
      HandleButton3(Ins, Ent, Cancel, Key, B2);
      if (Key = $417) or (LoCaseW(Key) = 'v') or MouseOn(14, 44, 65) then
      begin
        Toggle := not Toggle;
        MouseHide;
        if Toggle then WriteXY(45, 14, 'X')
        else WriteXY(45, 14, ' ');
        MouseShow;
        WaitRelease;
      end;
      if IsCancel(Key) or MouseOutside(13, 68, 7, 19) then Cancel := True;
      if Ins and ((Menu^.Groups[G].Items[21].Name <> '') or (Menu^.Groups[G].Items[21].Prog <> '')) then
      begin
        ErrorBox('Einf'#129'gen ist nicht mehr m'#148'glich!', 'Es w'#129'rde der letzte Eintrag gel'#148'scht werden.');
        Ins := False;
      end;
    until Ins or Ent or Cancel;
    CloseDialog;
    RestoreButton3(B);
    if Ent then
    begin
      Menu^.Groups[G].Items[N].Name := Name;
      Menu^.Groups[G].Items[N].Prog := FileName;
      Menu^.Groups[G].Items[N].ChDir := Toggle;
      Chg := True;
    end;
    if Ins then
    begin
      for Key := 21 downto N + 1 do
        Menu^.Groups[G].Items[Key] := Menu^.Groups[G].Items[Key - 1];
      Menu^.Groups[G].Items[N].Name := Name;
      Menu^.Groups[G].Items[N].Prog := FileName;
      Chg := True;
    end;
    FileName := Br^.Execute(P);
  end;
  Br^.Done;
  FreeMem(Br, SizeOf(TBrowser));
  PopScreen(DlgStack);
  if Chg then
  begin
    Changed := True;
    List.SetData(21, 13, List.Cur, List.Top);
  end;
  WaitRelease;
end;

procedure DeleteItem;
var
  Y: Integer;
  B: TButton2;
  Yes, No: Boolean;
  Key: Word;
begin
  OpenDialog;
  Y := List.Cur + 7;
  if Y > 16 then Y := Y - 7;
  Frame(16, Y, 29, 4, 11, 6, 0, 1);
  WriteF(11, '   Diesen Eintrag l'#148'schen?');
  InitButton2(True, 3, 2, 16, 2, 14, 0, 11, 6,
    '   Ja   ',
    '  Nein  ', B);
  MouseShow;
  repeat
    HandleButton2(Yes, No, Key, B);
    if LoCaseW(Key) = 'j' then Yes := True;
    if LoCaseW(Key) = 'n' then No := True;
    if IsCancel(Key) or MouseOutside(16, 46, Y, Y + 5) then No := True;
  until Yes or No;
  PopScreen(DlgStack);
  if No then WaitRelease
  else
  begin
    Changed := True;
    Y := List.Cur + List.Top;
    Menu^.Groups[G].Items[Y].Name := '';
    Menu^.Groups[G].Items[Y].Prog := '';
    List.SetData(21, 13, List.Cur, List.Top);
    WaitRelease;
  end;
end;

begin
  OpenDialog;
  GetDir(0, OldDir);
  A1 := TextAttr;
  Changed := False;
  SetColor(0, 3);
  A2 := TextAttr;
  SetColor(0, 7);
  A3 := TextAttr;
  Frame(4, 2, 72, 21, 15, 7, 0, 0);
  WriteXY(10, 1, 'Benutzermen'#129'verwaltung  Aktuelle Gruppe: ');
  for I := 1 to Length(Menu^.Groups[G].Name) do
    if Menu^.Groups[G].Name[I] <> '~' then WriteF(14, Menu^.Groups[G].Name[I]);
  WriteXY(10, 2, #221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221 +
    #221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221#221);
  for I := 1 to Length(Menu^.Groups[G].Name) do
    if Menu^.Groups[G].Name[I] <> '~' then Write(#221);
  WriteXY(3, 3, 'Benutzereintr'#132'ge:');
  WriteXY(26, 3, 'Programm:');
  Frame(6, 6, 68, 13, 15, 7, 0, 0);
  List.Init(0, 7, 0, 2, 7, 7, 13, 21, 67, True);
  List.SetPos(Start, 7);
  SaveWin(W);
  InitButton4(True, 6, 21, 25, 21, 44, 21, 62, 21, 14, 0, 15, 7,
    '   Einf'#129'gen   ',
    '  Umbenennen  ',
    '   L'#148'schen   ',
    '  Fertig  ', B);
  RestoreWin(W);
  MouseShow;
  repeat
    Key := 0;
    List.Handle(Key);
    if Key = 13 then
    begin
      Ins := False;
      Del := False;
      Ren := False;
      Done := False;
      if B[1].Focused then Key := $65
      else if B[2].Focused then Key := $75
      else if B[3].Focused then Key := $6C
      else goto Buttons4;
    end
    else
    begin
    Buttons4:
      SaveWin(W);
      HandleButton4(Ins, Ren, Del, Done, Key, B);
      RestoreWin(W);
    end;
    if LoCaseW(Key) = 'e' then Ins := True;
    if Key = $43A then Ins := True;
    if LoCaseW(Key) = 'u' then Ren := True;
    if LoCaseW(Key) = 'l' then Del := True;
    if LoCaseW(Key) = 'f' then Done := True;
    if Ins then
    begin
      AddItems(List.Cur + List.Top);
      Key := 0;
    end;
    if Ren then
    begin
      Key := 0;
      if EditItem(G, List.Cur + List.Top) then
      begin
        List.DrawAll;
        Changed := True;
      end;
    end;
    if Del then
    begin
      Key := 0;
      DeleteItem;
    end;
    if Key = $423 then ShowHelp(14);
    if MouseOutside(3, 78, 2, 24) then Done := True;
  until IsCancel(Key) or Done;
  EditGroup := Changed;
  List.Done;
  CloseDialog;
  ChDir(OldDir);
end;

procedure SortItems(G: Byte);
var
  I: Byte;
  Key: Word;
  Cur, Sel: Byte;

procedure Swap(A, B: Byte);
var
  T: TMenuItem;
begin
  T := Menu^.Groups[G].Items[A];
  Menu^.Groups[G].Items[A] := Menu^.Groups[G].Items[B];
  Menu^.Groups[G].Items[B] := T;
end;

procedure DrawItem(N: Byte);
begin
  MouseHide;
  WriteXY(1, N, ' ' + Copy(Menu^.Groups[G].Items[N].Name + Blanks, 1, 19));
  MouseShow;
end;

procedure HiItem(N: Byte);
begin
  MouseHide;
  if Sel = 0 then
    WriteXYFB(1, N, 0, 2, ' ' + Copy(Menu^.Groups[G].Items[N].Name + Blanks, 1, 19))
  else
    WriteXYFB(1, N, 14, 0, ' ' + Copy(Menu^.Groups[G].Items[N].Name + Blanks, 1, 19));
  MouseShow;
end;

procedure ItemUp;
begin
  if Cur = 1 then Exit;
  if Sel <> 0 then Swap(Cur, Cur - 1);
  DrawItem(Cur);
  Dec(Cur);
  HiItem(Cur);
end;

procedure ItemDown;
begin
  if Cur = 21 then Exit;
  if Sel <> 0 then Swap(Cur, Cur + 1);
  DrawItem(Cur);
  Inc(Cur);
  HiItem(Cur);
end;

procedure ItemClick(N: Byte);
begin
  if (Cur = N) or (N > 21) then Exit;
  if Sel <> 0 then Swap(Cur, N);
  DrawItem(Cur);
  Cur := N;
  HiItem(Cur);
end;

begin
  Sel := 0;
  OpenDialog;
  SetColor(14, 0);
  WriteXY(30, 1, '      Sortieren:      ');
  GotoXY(3, ScreenRows);
  Frame(12, 1, 56, 23, 15, 5, 0, 0);
  WriteXY(41, 15, '<Esc>');
  WriteXY(41, 16, 'Ende');
  WriteXY(41, 18, '<Cursor>');
  WriteXY(41, 19, 'Verschieben');
  WriteXY(41, 21, '<Return>');
  WriteXY(41, 22, 'Auswahl/Setzen');
  WriteXY(17, 2, #218);
  for I := 3 to 7 do WriteXY(17, I, #179);
  WriteXY(17, 8, #192);
  WriteXY(10, 5, 'F1..F7 '#180);
  WriteXY(17, 9, #218);
  for I := 10 to 14 do WriteXY(17, I, #179);
  WriteXY(17, 15, #192);
  WriteXY(6, 12, 'Alt-F1..F7 '#180);
  WriteXY(17, 16, #218);
  for I := 17 to 21 do WriteXY(17, I, #179);
  WriteXY(17, 22, #192);
  WriteXY(5, 19, 'Strg-F1..F7 '#180);
  Frame(30, 2, 20, 21, 15, 7, 1, 0);
  Window(31, 3, 80, ScreenRows);
  for I := 1 to 21 do WriteXY(2, I, Menu^.Groups[G].Items[I].Name);
  HiItem(1);
  Cur := 1;
  MouseShow;
  repeat
    GetKey(Key);
    if (Mouse.MouseButton = 1) and (MouseX > 30) and (MouseX < 51) and (MouseY >= 3) and (MouseY <= 23) and
      (Cur = MouseY - 2) and DoubleClick(MouseX, MouseY) then Key := 13;
    case Key of
      $430: ItemUp;
      $438: ItemDown;
      13: if Sel = 0 then
          begin
            Sel := Cur;
            HiItem(Cur);
          end
          else
          begin
            Sel := 0;
            HiItem(Cur);
          end;
    end;
    if (Mouse.MouseButton = 1) and (MouseX > 30) and (MouseX < 51) and (MouseY >= 3) and (MouseY <= 23) then
      ItemClick(MouseY - 2);
  until IsCancel(Key);
  PopScreen(DlgStack);
end;

end.
