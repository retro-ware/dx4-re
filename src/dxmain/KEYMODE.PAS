{$O+,F+,G+,S-,I-,X+,V-}
unit KeyMode;

interface

procedure SelectKeyMode;

implementation

uses Dos, Crt, DXGlob, Buttons, Mouse, Screen, Windows, ScrSave, Dialogs, Status;

procedure SelectKeyMode;
var
  Key: Word;
  Mode: Byte;
  W: TWinState;

  procedure NextMode;
  begin
    Inc(Mode);
    if Mode = 4 then Mode := 0;
    MouseHide;
    case Mode of
      0: begin
           AltDown := False; CtrlDown := False; ShiftDown := False;
           WriteCenterXYFB(2, 1, 76, 14, 3, 'Normale Funktionen');
         end;
      1: begin
           AltDown := False; CtrlDown := True; ShiftDown := False;
           WriteCenterXYFB(2, 1, 76, 14, 3, 'Strg - Funktionen');
         end;
      2: begin
           AltDown := True; CtrlDown := False; ShiftDown := False;
           WriteCenterXYFB(2, 1, 76, 14, 3, 'Alt - Funktionen');
         end;
      3: begin
           AltDown := False; CtrlDown := False; ShiftDown := True;
           WriteCenterXYFB(2, 1, 76, 14, 3, 'Shift - Funktionen');
         end;
    end;
    MouseShow;
  end;

begin
  OpenDialog;
  SaveWin(W);
  Frame(1, ScreenRows - 3, 78, 1, 11, 3, 0, 0);
  WriteCenterXYFB(2, 1, 76, 14, 3, 'Strg - Funktionen');
  MouseShow;
  CtrlDown := True;
  Mode := 1;
  DrawKeyBar(True);
  WaitRelease;
  repeat
    GetKey(Key);
    if CtrlDown or AltDown or ShiftDown then Key := 1;
    if MouseButton = 2 then
    begin
      NextMode;
      DrawKeyBar(True);
      WaitRelease;
    end;
  until (ScreenRows - 3 > MouseY) or (MouseButton = 1) or (Key <> 0);
  PopScreen(DlgStack);
  if (ScreenRows = MouseY) and (MouseX > 1) and (MouseButton = 1) then
    case Mode of
      0: begin AltDown := False; CtrlDown := False; ShiftDown := False; end;
      1: begin AltDown := False; CtrlDown := True; ShiftDown := False; end;
      2: begin AltDown := True; CtrlDown := False; ShiftDown := False; end;
      3: begin AltDown := False; CtrlDown := False; ShiftDown := True; end;
    end
  else
    WaitRelease;
  RestoreWin(W);
  DrawKeyBar(True);
end;

end.
