{$O+,F+,G+,S-,I+,X+,V-}
unit Filters;

interface

type
  Str80 = string[80];
  TFilterOpts = record
    Attr: Word;
    MaxSize, MinSize: Longint;
    MinTime, MaxTime: Longint;
  end;

function LoadFilter(var Mask: Str80; var Opts: TFilterOpts): Boolean;
procedure SaveFilter(Mask: Str80; Opts: TFilterOpts);

implementation

uses Crt, DXGlob, Buttons, Mouse, Screen, Windows, Dialogs, Lists, Fonts;

type
  TFilter = record
    Name: string[32];
    Mask: string[80];
    Opts: TFilterOpts;
  end;
  TFilterArr = array[1..20] of TFilter;

  TFilterList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

var
  FilterArr: ^TFilterArr;

procedure TFilterList.DrawLine(Line: Integer);
var
  S: string[5];
begin
  Str(Line + Top: 2, S);
  S := ' ' + S + ': ';
  Text := S + FilterArr^[Line + Top].Name;
  TList.DrawLine(Line);
end;

{$I-}
procedure WriteFilters;
var
  F: file of TFilterArr;
begin
  Assign(F, HomeDir + 'dxfilter.dat');
  Rewrite(F);
  Write(F, FilterArr^);
  Close(F);
  if IOResult <> 0 then
    MsgBox('Fehler beim Schreiben der Filterdatei!', HomeDir + 'dxfilter.dat');
end;

procedure ReadFilters;
var
  F: file of TFilterArr;
  I: Integer;
begin
  Assign(F, HomeDir + 'dxfilter.dat');
  Reset(F);
  Read(F, FilterArr^);
  Close(F);
  if IOResult <> 0 then
  begin
    for I := 1 to 20 do
      with FilterArr^[I] do
      begin
        Name := '';
        Mask := '*.*';
        Opts.MinTime := $80000000;
        Opts.MaxTime := $7FFFFFFF;
        Opts.MaxSize := 999999999;
        Opts.MinSize := 0;
        Opts.Attr := 0;
      end;
    WriteFilters;
  end;
end;
{$I+}

function LoadFilter(var Mask: Str80; var Opts: TFilterOpts): Boolean;
var
  B: TButton2;
  Ok, Cancel: Boolean;
  I, Sel: Integer;
  Key: Word;
  List: TFilterList;
begin
  LoadFilter := False;
  OpenDialog;
  GetMem(FilterArr, SizeOf(TFilterArr));
  ReadFilters;
  Frame(19, 6, 39, 15, 15, 7, 0, 1);
  WriteCenterXY(1, 1, 39, 'Laden einer Filtermaske');
  if not CustomFont then
  begin
    WriteXY(1, 2, #$D8);
    for I := 1 to 38 do Write(#$D8);
    WriteXY(1, 12, #$DD);
    for I := 1 to 38 do Write(#$DD);
  end;
  Window(1, 1, 80, 25);
  List.Init(0, 7, 0, 2, 20, 9, 9, 20, 38, True);
  InitButton2(True, 3, 11, 21, 11, 14, 0, 15, 7, '    Laden    ', '   Abbruch   ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    Sel := List.Handle(Key);
    if Key = 13 then Ok := True;
    if IsCancel(Key) or MouseOutside(19, 59, 6, 22) then Cancel := True;
    if Cancel then Ok := False;
  until Ok or Cancel;
  CloseDialog;
  if Ok then
  begin
    LoadFilter := True;
    Mask := FilterArr^[Sel].Mask;
    Opts := FilterArr^[Sel].Opts;
  end;
  FreeMem(FilterArr, SizeOf(TFilterArr));
end;

procedure SaveFilter(Mask: Str80; Opts: TFilterOpts);
var
  B: TButton2;
  Ok, Cancel: Boolean;
  I, Sel: Integer;
  Key: Word;
  List: TFilterList;
  Name: string[32];
  Save: TMouseMap;
begin
  OpenDialog;
  GetMem(FilterArr, SizeOf(TFilterArr));
  ReadFilters;
  Save := MouseMap;
  Frame(19, 6, 39, 15, 15, 7, 0, 1);
  WriteCenterXY(1, 1, 39, 'Speichern einer Filtermaske');
  if not CustomFont then
  begin
    WriteXY(1, 2, #$D8);
    for I := 1 to 38 do Write(#$D8);
    WriteXY(1, 12, #$DD);
    for I := 1 to 38 do Write(#$DD);
  end;
  Window(1, 1, 80, 25);
  List.Init(0, 7, 0, 2, 20, 9, 9, 20, 38, True);
  InitButton2(True, 3, 11, 21, 11, 14, 0, 15, 7, '  Speichern  ', '   Abbruch   ', B);
  MouseShow;
  repeat
    HandleButton2(Ok, Cancel, Key, B);
    Sel := List.Handle(Key);
    if Key = 13 then Ok := True;
    if IsCancel(Key) or MouseOutside(19, 59, 6, 22) then Cancel := True;
    if Cancel then Ok := False;
  until Ok or Cancel;
  CloseDialog;
  InitMouse;
  if Ok then
  begin
    OpenDialog;
    Frame(10, 11, 62, 6, 15, 7, 0, 1);
    WriteXY(3, 2, 'Name des neuen Filters:');
    Name := FilterArr^[Sel].Name;
    InputLine(37, 13, 0, 0, Name, 32, 0, #$D8, False);
    InitButton2(True, 12, 15, 29, 15, 14, 0, 15, 7, '     OK     ', '   Abbruch   ', B);
    MouseShow;
    Key := $419;
    repeat
      if (Key = $419) or (Key = $430) or (Key = 9) or (Key = $3F7) or (Key = $438) or MouseOn(13, 37, 70) then
      begin
        ResetButton2(B);
        InputLine(37, 13, 0, 0, Name, 32, 32, #$D8, False);
        RestoreButton2(B);
      end;
      HandleButton2(Ok, Cancel, Key, B);
      if IsCancel(Key) or MouseOutside(10, 73, 11, 18) then Cancel := True;
    until Ok or Cancel;
    CloseDialog;
    if Ok then
    begin
      FilterArr^[Sel].Name := Name;
      FilterArr^[Sel].Opts := Opts;
      FilterArr^[Sel].Mask := Mask;
      WriteFilters;
    end;
  end;
  FreeMem(FilterArr, SizeOf(TFilterArr));
  MouseMap := Save;
end;

end.
