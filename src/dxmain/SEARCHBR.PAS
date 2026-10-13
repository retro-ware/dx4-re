{$O+,F+,G+,S-,I-,X+,V-}
unit SearchBr;

interface

procedure DrawSearchBar(X, Width, Pos: Byte);
procedure SearchKey(var Key: Word; X, Pos: Byte; var Len: Integer; var S: string);

implementation

uses Crt, DXGlob, Mouse, Screen, Windows, Status, Dialogs, ScrSave, Lists;

type
  TDriveList = object(TList)
    procedure DrawLine(Line: Integer); virtual;
  end;

procedure TDriveList.DrawLine(Line: Integer);
begin
  Text := ' ' + Chr(Line + Top + $40) + ' ';
  TList.DrawLine(Line);
end;

function SelectDrive(X, Y, Rows, Bg, Dummy: Byte): Char;
var
  List: TDriveList;
  Key: Word;
begin
  OpenDialog;
  SelectDrive := #0;
  Frame(X - 4, Y - 2, 10, Rows + 2, 11, Bg, 0, 1);
  OpenFrame(X - 1, Y - 1, 4, Rows, 0, Bg);
  List.Init(2, 3, 2, 0, X, Y, Rows, 26, 3, True);
  MouseShow;
  WaitRelease;
  repeat
    GetKey(Key);
    List.Handle(Key);
  until IsCancel(Key) or (Key = 13) or MouseOutside(X, X + 3, Y - 1, Y + Rows);
  PopScreen(DlgStack);
  if Key = 13 then
  begin
    Delete(List.Text, 1, 1);
    SelectDrive := Chr(List.Cur + List.Top + $40);
  end;
  List.Done;
end;

procedure DrawSearchBar(X, Width, Pos: Byte);
begin
  OpenDialog;
  InitMouse;
  Frame(X, ScreenRows - 3, 38, 1, 15, 5, 1, 0);
  Write('  Suche nach: ');
  if SingleFrame then WriteFB(0, 2, ' ') else WriteFB(0, 2, #$D0);
  WriteFB(0, 2, '             ');
  WriteF(4, '   ^N');
  Write('ext');
  DrawDownArrow(29, 1);
  Window(1, 1, 80, ScreenRows);
  if not SingleFrame then
    WriteXYFB(X + Width - 2, ScreenRows - 3, 0, 5, #$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6#$C6);
  ShowCursor;
  MouseShow;
  GotoXY(X + Width + Pos - 1, ScreenRows - 2);
  WaitRelease;
end;

procedure SearchKey(var Key: Word; X, Pos: Byte; var Len: Integer; var S: string);
var
  D: Char;
begin
  repeat
    if MouseOn(ScreenRows - 2, X + 32, X + 36) then
    begin
      MouseHide;
      WriteXYF(X + 32, ScreenRows - 2, 4, ' ^N');
      WriteF(14, 'ext');
      MouseShow;
      GotoXY(X + Pos + Len - 1, ScreenRows - 2);
      WaitRelease;
      MouseHide;
      WriteXYF(X + 32, ScreenRows - 2, 4, '^N');
      Write('ext ');
      MouseShow;
      Key := 14;
    end
    else if MouseOn(ScreenRows - 2, X + 30, X + 30) then
    begin
      HideCursor;
      D := SelectDrive(X + 29, ScreenRows - 15, 13, 11, 0);
      if D <> #0 then
      begin
        S := '';
        MouseHide;
        WriteXYFB(X + Pos - 1, ScreenRows - 2, 0, 2, '            ');
        MouseShow;
        Len := 0;
        Key := Ord(D);
      end
      else
        Key := 0;
      ShowCursor;
    end
    else
      GetKey(Key);
  until (Key <> 0) or (MouseButton = 2) or MouseOutside(X, X + 39, ScreenRows - 3, ScreenRows - 1);
end;

end.
