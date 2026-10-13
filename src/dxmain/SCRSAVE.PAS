{$F+,G+,S-,I-}
unit ScrSave;

interface

type
  TScrBuf = array[0..2399] of Word;
  PScrSave = ^TScrSave;
  TScrSave = record
    Buf: ^TScrBuf;
    Prev: PScrSave;
    X1, Y1, X2, Y2, CurX, CurY, Attr: Byte;
  end;
  TScrStack = record
    Top: PScrSave;
    Tmp: PScrSave;
    Count: Byte;
  end;

procedure InitStack(var S: TScrStack);
procedure SaveScreen(var P: PScrSave);
procedure PushScreen(var S: TScrStack);
procedure DropScreen(var S: TScrStack);
procedure PopScreen(var S: TScrStack);
procedure RestoreScreen(var P: PScrSave);
procedure ClearStack(var S: TScrStack);
procedure RestoreLine(Y: Byte; var P: PScrSave);
procedure RestoreColumn(X: Byte; var P: PScrSave);
procedure RestoreChar(X, Y: Byte; var P: PScrSave);

implementation

uses Crt, Mouse;

procedure InitStack(var S: TScrStack);
begin
  S.Tmp := nil;
  S.Top := S.Tmp;
  S.Count := 0;
end;

procedure SaveScreen(var P: PScrSave);
begin
  Move(Ptr($B800, 0)^, P^.Buf^, $12C0);
  P^.X1 := Lo(WindMin) + 1;
  P^.Y1 := Hi(WindMin) + 1;
  P^.X2 := Lo(WindMax) + 1;
  P^.Y2 := Hi(WindMax) + 1;
  P^.CurX := WhereX;
  P^.CurY := WhereY;
  P^.Attr := TextAttr;
end;

procedure PushScreen(var S: TScrStack);
begin
  Inc(S.Count);
  New(S.Top);
  GetMem(S.Top^.Buf, $12C0);
  S.Top^.Prev := S.Tmp;
  S.Tmp := S.Top;
  SaveScreen(S.Top);
end;

procedure DropScreen(var S: TScrStack);
begin
  Dec(S.Count);
  S.Tmp := S.Top^.Prev;
  FreeMem(S.Top^.Buf, $12C0);
  Dispose(S.Top);
  S.Top := S.Tmp;
end;

procedure PopScreen(var S: TScrStack);
begin
  RestoreScreen(S.Top);
  DropScreen(S);
end;

procedure RestoreScreen(var P: PScrSave);
begin
  if P = nil then
  begin
    Window(1, 1, 80, 25);
    NormVideo;
    TextColor(12);
    WriteLn(#10#13' Interner Fehler 12! ');
    Halt(12);
  end;
  Window(P^.X1, P^.Y1, P^.X2, P^.Y2);
  GotoXY(P^.CurX, P^.CurY);
  TextAttr := P^.Attr;
  MouseHide;
  Move(P^.Buf^, Ptr($B800, 0)^, $12C0);
  MouseShow;
end;

procedure ClearStack(var S: TScrStack);
begin
  while S.Tmp <> nil do
  begin
    S.Tmp := S.Top^.Prev;
    FreeMem(S.Top^.Buf, $12C0);
    Dispose(S.Top);
    S.Top := S.Tmp;
  end;
end;


var
  Scr: TScrBuf absolute $B800:0;

procedure RestoreLine(Y: Byte; var P: PScrSave);
var
  O: Word;
begin
  O := Pred(Y) * 80;
  Move(P^.Buf^[O], Scr[O], 160);
end;

procedure RestoreColumn(X: Byte; var P: PScrSave);
var
  I: Integer;
  O: Word;
begin
  Dec(X);
  for I := 0 to 27 do
  begin
    O := I * 80 + X;
    Scr[O] := P^.Buf^[O];
  end;
end;

procedure RestoreChar(X, Y: Byte; var P: PScrSave);
var
  O: Word;
begin
  Dec(X);
  Dec(Y);
  O := Y * 80 + X;
  Scr[O] := P^.Buf^[O];
end;

end.
