{$F+,G+,S-,V-}
{$M 24000,0,655360}
program DXM;

uses Crt, Dos, U129A, Screen, Palette, U118C, Mouse, ScrSave, Times, Windows, DXGlob, Dialogs,
  Fonts, DXMenu;

type
  TColors = array[0..$40] of Byte;
  PColors = ^TColors;
  TConfig = record
    Id: string[41];
    F1: array[$2A..$FF] of Byte;
    Col1: TColors;
    Col2: TColors;
    F2: array[$182..$283] of Byte;
    SaverDelay: Word;
    F3: array[$286..$5C4] of Byte;
    Password: string[12];
    F4: array[$5D2..$6DF] of Byte;
    MenuPos: Word;
    F5: array[$6E2..$6FB] of Byte;
    SaverProg: string[12];
    F6: array[$709..$711] of Byte;
  end;

var
  Prog: string;
  Pos: Word;
  Dummy: Word;
  Ok: Boolean;
  OldY: Byte;
  Mode: Byte;

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

procedure LoadCfg;
var
  F: file of TConfig;
  Cfg: TConfig;
  I: Byte;
begin
  Assign(F, HomeDir + IniName);
  Reset(F);
  InOutRes := 0;
  Read(F, Cfg);
  InOutRes := 0;
  Close(F);
  if (IOResult = 0) and (Cfg.Id = IniId) then
  begin
    Pos := Cfg.MenuPos;
    SaverDelay := Cfg.SaverDelay;
    PColors(@Opt4DE)^ := Cfg.Col1;
    PColors(@Opt520)^ := Cfg.Col2;
    SaverProg := Cfg.SaverProg;
    Password := Cfg.Password;
    for I := 1 to Length(Password) do
      Dec(Password[I], 13);
  end
  else
    Pos := $101;
end;

procedure WriteStart(S: string);
var
  T: Text;
  Dir: DirStr;
  Name: NameStr;
  Ext: ExtStr;
begin
  Assign(T, HomeDir + 'dxstart.bat');
  Rewrite(T);
  if IOResult <> 0 then Exit;
  FSplit(S, Dir, Name, Ext);
  Writeln(T, '@echo off');
  Writeln(T, 'rem Start-Batch wurde von dxm.exe erzeugt.');
  Writeln(T, Copy(Dir, 1, 2));
  if Length(Dir) > 3 then DelBackslash(Dir);
  Writeln(T, 'cd ' + Dir);
  Writeln(T, S);
  Dir := HomeDir;
  Writeln(T, Copy(Dir, 1, 2));
  if Length(Dir) > 3 then DelBackslash(Dir);
  Writeln(T, 'cd ' + Dir);
  Close(T);
end;

procedure Quit(Code: Word);
begin
  SetPal1;
  InitPlainFont;
  ShowCursor;
  MouseSoftReset;
  ClearStack(DlgStack);
  GotoXY(1, OldY + 1);
  Halt(Code);
end;

begin
  if ParamStr(1) <> 'batch' then
  begin
    Writeln('Das Programm mu'#225' '#129'ber die Batch-Datei menu.bat gestartet werden!');
    Halt(8);
  end;
  if (ParamStr(2) = '/m') or (ParamStr(2) = '/M') then
    MouseReset
  else
    MouseSoftReset;
  BorderColor := 0;
  MouseMoved := 0;
  InitStack(DlgStack);
  PushScreen(DlgStack);
  OldY := WhereY;
  ClrScr;
  InitMouse;
  Pos := $101;
  LoadCfg;
  if (Lo(Pos) < 0) or (Lo(Pos) > 15) then Pos := $101;
  BigCursor := False;
  ScreenRows := 25;
  MouseYRange(0, ScreenRows - 1);
  InitFont;
  HideCursor;
  SetColor(11, 3);
  Window(1, 1, 80, ScreenRows);
  ClrScr;
  HomeDir := Copy(ParamStr(0), 1, Length(ParamStr(0)) - 7);
  InstallHandler;
  MouseShow;
  SetPal2;
  Ok := MainMenu(Prog, Pos, Mode);
  SaveCfg;
  PopScreen(DlgStack);
  if Ok then
  begin
    WriteStart(Prog);
    Quit(1);
  end
  else
    Quit(8);
end.
