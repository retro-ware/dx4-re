{$O+,F+,G+,S-,I-}
unit Help;

interface

uses Lists;

type
  THelpPage = record
    N: Byte;
    Title: string[76];
    Lines: array[1..3, 1..28] of string[76];
    Start: Byte;
  end;
  PHelpPage = ^THelpPage;
  THelpLines = array[1..84] of string[76];
  PHelpLines = ^THelpLines;
  THelpList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
    procedure ShowCur(Line: Integer); virtual;
  end;

var
  TextPage: Boolean;
  HelpLines: PHelpLines;

procedure ShowHelp(Start: Byte);

implementation

uses Crt, DXGlob, Mouse, Screen, Windows, ScrSave, Buttons, Dialogs, Status;

const
  Blanks = '                                                                ' +
    '                                                                ' +
    '                                                                ' +
    '                                                               ';

procedure THelpList.DrawLine(Line: Integer);
var
  SaveAttr: Byte;
begin
  SaveAttr := TextAttr;
  if TextPage then TextColor(14);
  Text := ' ' + HelpLines^[Line + Top];
  TList.DrawLine(Line);
  TextAttr := SaveAttr;
end;

procedure THelpList.ShowCur(Line: Integer);
var
  SaveAttr: Byte;
begin
  SaveAttr := TextAttr;
  if TextPage then
    SetColor(2, 1)
  else
    SetColor(SelFg, SelBg);
  DrawLine(Line);
  TextAttr := SaveAttr;
end;

procedure ShowHelp(Start: Byte);
var
  I: Integer;
  Dummy: Word;
  Idx, Vor, Zur, Abbr: Boolean;
  Key: Word;
  P: PHelpPage;
  NLines: Byte;
  F: file of THelpPage;
  L: THelpList;
  B4: TButton4;
  B: TButton;
  Go: Boolean;
  SaveBorder, SaveBg, SaveFg, CurPage, SaveX, SaveY: Byte;

  function NextPage: Boolean;
  var
    I: Integer;
    Pos: LongInt;
    J: Integer;
  begin
    Pos := FilePos(F);
    NextPage := True;
    if (FileSize(F) = Pos) or Eof(F) then
    begin
      ErrorBox('Dies war die letzte Seite!', 'Es geht nicht weiter vorw'#$84'rts.');
      NextPage := False;
    end
    else
    begin
      Read(F, P^);
      InOutRes := 0;
      Window(5, 3, 80, 3);
      WriteF(14, Copy(P^.Title + Blanks, 1, 75));
      Window(2, 5, 80, ScreenRows);
      NLines := P^.N;
      for I := 1 to NLines do
        for J := 1 to 28 do
          HelpLines^[(I - 1) * 28 + J] := P^.Lines[I, J];
      if Pos > 0 then TextPage := False;
      L.SetData(P^.Start, ScreenRows - 8, 1, 0);
    end;
  end;

  procedure PrevPage;
  var
    Pos: LongInt;
  begin
    Pos := FilePos(F);
    if Pos = 1 then
      ErrorBox('Dies ist die erste Seite!', 'Es geht nicht weiter zur'#$81'ck.')
    else
    begin
      Seek(F, Pos - 2);
      InOutRes := 0;
      if Pos = 2 then TextPage := True;
      NextPage;
    end;
  end;

  procedure GotoPage(N: Byte);
  begin
{$I+}
    Seek(F, 0);
{$I-}
    TextPage := True;
    NextPage;
    TextPage := True;
    Vor := False;
    Zur := False;
    Idx := False;
    L.SetPos(N, 6);
  end;

  procedure InitGoButton;
  begin
    InitButton(True, 3, ScreenRows - 2, 14, 0, 11, 3,
      '                               Gehe nach                                ', B);
  end;

  procedure InitButtons;
  begin
    InitButton4(True, 3, ScreenRows - 2, 23, ScreenRows - 2, 42, ScreenRows - 2, 60, ScreenRows - 2,
      14, 0, 11, 3, '      Vor      ', '    Zur'#$81'ck    ', '    Index    ', '    Abbruch    ', B4);
  end;

begin
  if MaxAvail < 20000 then Exit;
  Assign(F, HomeDir + 'dxhelp.hlp');
  Reset(F);
  CurPage := 1;
  if IOResult <> 0 then
  begin
    MsgBox('Hilfe-Datei nicht gefunden!', HomeDir + 'dxhelp.hlp');
    Exit;
  end;
  GetMem(HelpLines, SizeOf(THelpLines));
  if HelpLines = nil then Exit;
  GetMem(P, SizeOf(THelpPage));
  if P = nil then
  begin
    FreeMem(HelpLines, SizeOf(THelpLines));
    Exit;
  end;
  OpenDialog;
  SetColor(0, 3);
  SaveX := StatX;
  SaveY := StatY;
  StatX := 75;
  StatY := 1;
  Window(1, 1, 80, ScreenRows);
  ClrScr;
  SaveBorder := BorderColor;
  BorderColor := 3;
  RestoreBorder;
  SaveBg := StatBg;
  SaveFg := StatFg;
  StatFg := 0;
  StatBg := 3;
  LastDate := '';
  LastTime := '';
  NLines := 0;
  TextPage := False;
  WriteXY(2, 1, 'DOS-Expander (C) Copyright 1994-1996 H.Hombergs');
  Frame(1, 2, 78, ScreenRows - 6, 11, 3, 0, 0);
  WriteLn;
  for Key := 1 to 78 do
    Write(#$C4);
  Window(1, 1, 80, ScreenRows);
  if Start = 0 then InitGoButton else InitButtons;
  for I := 1 to 84 do
    HelpLines^[I] := '';
  L.Init(0, 3, 0, 2, 2, 5, ScreenRows - 8, 84, 77, True);
  if Start <> 0 then
  begin
    Seek(F, Start);
    NextPage;
    CurPage := Start;
  end
  else
    GotoPage(1);
  MouseShow;
  Abbr := False;
  repeat
    Idx := False;
    Window(1, 1, 80, ScreenRows);
    if TextPage then
    begin
      Go := Buttons.MouseButton(B);
      Status.GetKey(Key);
      if LoCaseW(Key) = 'g' then Go := True;
    end
    else
    begin
      HandleButton4(Vor, Zur, Idx, Abbr, Key, B4);
      if LoCaseW(Key) = 'v' then Vor := True;
      if LoCaseW(Key) = 'z' then Zur := True;
      if LoCaseW(Key) = 'i' then Idx := True;
      if LoCaseW(Key) = 'a' then Abbr := True;
    end;
    Window(2, 5, 80, ScreenRows);
    Start := L.Handle(Key);
    if TextPage and ((Key = 13) or Go) then
    begin
      Seek(F, Start);
      if NextPage then
      begin
        CurPage := Start;
        Window(1, 1, 80, ScreenRows);
        GotoXY(1, ScreenRows - 2);
        ClrEol;
        GotoXY(1, ScreenRows - 1);
        ClrEol;
        GotoXY(1, ScreenRows);
        ClrEol;
        InitButtons;
        Window(2, 5, 80, ScreenRows);
      end;
    end
    else if not TextPage then
    begin
      if Idx then
      begin
        Window(1, 1, 80, ScreenRows);
        InitGoButton;
        Window(2, 5, 80, ScreenRows);
        GotoPage(CurPage);
      end;
      if Vor then
        if NextPage then Inc(CurPage);
      if Zur then
      begin
        PrevPage;
        Dec(CurPage);
        if TextPage then
        begin
          Window(1, 1, 80, ScreenRows);
          InitGoButton;
          Window(2, 5, 80, ScreenRows);
        end;
      end;
    end;
  until IsCancel(Key) or Abbr;
  Close(F);
  InOutRes := 0;
  PopScreen(DlgStack);
  L.Done;
  BorderColor := SaveBorder;
  RestoreBorder;
  FreeMem(HelpLines, SizeOf(THelpLines));
  FreeMem(P, SizeOf(THelpPage));
  StatBg := SaveBg;
  StatFg := SaveFg;
  repeat
  until Mouse.MouseButton = 0;
  LastTime := '';
  StatX := SaveX;
  StatY := SaveY;
end;

end.
