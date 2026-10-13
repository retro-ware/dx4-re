{$O+,F+,G+,S-,I-,X+,V-}
unit ExtProg;

interface

uses Dialogs;

procedure ViewFile(Name: Dialogs.Str12);
procedure EditSysFiles;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Status, Fonts, U0DA0;

procedure ViewFile(Name: Dialogs.Str12);
var
  SaveTop: Pointer;
  F, C, B: Byte;
begin
  if ViewerName = '' then
    ErrorBox('Es wurde noch kein externer Viewer angegeben!', 'Nehmen Sie den Eintrag in der Konfiguration vor.')
  else
  begin
    OpenDialog;
    F := Byte(CustomFont);
    C := Byte(BigCursor);
    B := BorderColor;
    BorderColor := 0;
    Window(1, 1, 80, ScreenRows);
    TextBackground(0);
    ClrScr;
    WriteCenterXYF(1, 7, 80, 14, ViewerName + ' wird geladen!');
    WriteCenterXYF(1, 9, 80, 14, Name);
    ShowCursor;
    CustomFont := False;
    BigCursor := False;
    InitPlainFont;
    ResetMouse;
    SaveTop := HeapEnd;
    SetMemTop(HeapPtr);
    SwapVectors;
    Exec(GetEnv('COMSPEC'), '/c ' + ViewerName + ' ' + Name);
    SwapVectors;
    SetMemTop(SaveTop);
    BorderColor := B;
    CustomFont := Boolean(F);
    BigCursor := Boolean(C);
    HideCursor;
    if not CustomFont then
      InitFont
    else
    begin
      CustomFont := False;
      InitPlainFont;
      CustomFont := True;
    end;
    ResetMouse;
    InstallHandler;
    MouseShow;
    MouseYRange(0, ScreenRows - 1);
    SetPal2;
    PopScreen(DlgStack);
  end;
end;

procedure EditSysFiles;
var
  SaveTop: Pointer;
  R: Registers;
  Err: Word;
  F, B: Byte;
  S, Line: string;
  T: Text;

  procedure PutKey(Scan, Ch: Byte);
  var
    R: Registers;
  begin
    R.AH := 5;
    R.CH := Scan;
    R.CL := Ch;
    Intr($16, R);
  end;

begin
  if FSearch(HomeDir + 'dxe.exe', '') = '' then
  begin
    ErrorBox('Der Editor wurde nicht gefunden:', HomeDir + 'dxe.exe');
    Exit;
  end;
  S := 'c:\autoexec.bat c:\config.sys';
  OpenDialog;
  MouseShow;
  ArrowCursor;
  if FSearch(HomeDir + 'dxsysdat.ini', '') = '' then
    ErrorBox('Initialisierungsdatei nicht gefunden!', HomeDir + 'dxsysdat.ini')
  else
  begin
    Assign(T, HomeDir + 'dxsysdat.ini');
    Reset(T);
    if IOResult = 0 then
    begin
      S := '';
      {$I+} while not Eof(T) do {$I-}
      begin
        ReadLn(T, Line);
        if IOResult = 0 then
          S := S + ' ' + Line;
      end;
      Close(T);
      InOutRes := 0;
    end
    else
      ErrorBox('Fehler beim '#$99'ffnen von', HomeDir + 'dxsysdat.ini');
  end;
  F := Byte(CustomFont);
  B := BorderColor;
  BorderColor := 0;
  CustomFont := False;
  InitPlainFont;
  ShowCursor;
  Window(1, 1, 80, ScreenRows);
  TextBackground(1);
  ClrScr;
  PutKey($21, 0);
  PutKey($30, $62);
  SaveTop := HeapEnd;
  SetMemTop(HeapPtr);
  SwapVectors;
  SetPal1;
  Exec(HomeDir + 'dxe.exe', S);
  Err := DosError;
  SetPal2;
  CustomFont := Boolean(F);
  BorderColor := B;
  SwapVectors;
  SetMemTop(SaveTop);
  HideCursor;
  if not CustomFont then
    InitFont
  else
  begin
    CustomFont := False;
    InitPlainFont;
    CustomFont := True;
  end;
  R.AX := 3;
  Intr($33, R);
  ResetMouse;
  InstallHandler;
  MouseYRange(0, ScreenRows - 1);
  MouseShow;
  PopScreen(DlgStack);
  R.AX := 4;
  Intr($33, R);
  if Err <> 0 then
    ErrorBox('Fehler beim Ausf'#$81'hren von:', HomeDir + 'dxe.exe');
end;

end.
