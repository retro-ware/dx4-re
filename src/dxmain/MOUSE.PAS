{$F+,G+,S-}
unit Mouse;

interface

uses Dos;

const
  MouseButton: Integer = 0;
  MouseX: Integer = 41;
  MouseY: Integer = 13;
  CursorOn: Boolean = True;
  MouseMoved: Integer = 0;
  ScreenMask: Word = $40FF;
  CursorMask: Word = $4E00;
  NoMouseReset: Boolean = True;

type
  TMouseMap = array[1..28, 1..80] of Byte;

var
  Regs: Registers;
  CurStart, CurEnd: Byte;
  MouseMap: TMouseMap;

procedure MouseYRange(Min, Max: Byte);
function MouseOn(Y, X1, X2: Byte): Boolean;
function MouseOutside(X1, X2, Y1, Y2: Byte): Boolean;
procedure InitMouse;
procedure SaveCursor;
procedure HideCursor;
procedure ShowCursor;
procedure MouseCall;
procedure ResetMouse;
procedure MouseShow;
procedure MouseHide;
procedure MouseGoto(X, Y: Byte);
procedure MouseHandler;
procedure MouseTextCursor;
procedure InstallHandler;
procedure MouseReleases(var N: Word);
procedure MousePresses(var N: Word);
procedure MouseDefCursor;
procedure MouseSetCursor(Screen, Cursor: Word);
function DoubleClick(X, Y: Integer): Boolean;
procedure MouseSensitivity(S: Byte);

implementation

uses Crt;

procedure MouseYRange(Min, Max: Byte);
var
  R: Registers;
begin
  R.AX := 8;
  R.CX := Min shl 3;
  R.DX := Max shl 3;
  Intr($33, R);
end;

function MouseOn(Y, X1, X2: Byte): Boolean;
begin
  if (MouseButton = 1) and (Y = MouseY) and (X1 <= MouseX) and (X2 >= MouseX) then
    MouseOn := True
  else
    MouseOn := False;
end;

function MouseOutside(X1, X2, Y1, Y2: Byte): Boolean;
begin
  MouseOutside := False;
  if (MouseButton = 1) and ((Y2 < MouseY) or (Y1 > MouseY) or (X2 < MouseX) or (X1 > MouseX)) then
    MouseOutside := True;
end;

procedure InitMouse;
begin
  FillChar(MouseMap, SizeOf(MouseMap), 0);
  MouseTextCursor;
end;

procedure SaveCursor;
begin
  Regs.AH := 15;
  Intr($10, Regs);
  Regs.AH := 3;
  Intr($10, Regs);
  CurStart := Regs.CH;
  CurEnd := Regs.CL;
end;

procedure HideCursor;
begin
  if CursorOn then
  begin
    SaveCursor;
    Regs.AH := 1;
    Regs.CH := $FF;
    Regs.CL := $FF;
    Intr($10, Regs);
    CursorOn := False;
  end;
end;

procedure ShowCursor;
begin
  if not CursorOn then
  begin
    Regs.AH := 1;
    Regs.CH := CurStart;
    Regs.CL := CurEnd;
    Intr($10, Regs);
    CursorOn := True;
  end;
end;

procedure MouseCall;
begin
  Intr($33, Regs);
end;

procedure ResetMouse;
begin
  if NoMouseReset then
    Regs.AX := 0
  else
    Regs.AX := $21;
  MouseCall;
end;

procedure MouseShow;
begin
  Regs.AX := 1;
  MouseCall;
end;

procedure MouseHide;
begin
  Regs.AX := 2;
  MouseCall;
end;

procedure MouseGoto(X, Y: Byte);
begin
  Regs.AX := 4;
  Regs.CX := (X - 1) shl 3;
  Regs.DX := (Y - 1) shl 3;
  MouseCall;
end;

procedure MouseHandler; assembler;
asm
        jmp     @Start
@Busy:  db      0
@Cols:  db      80
@SaveAX: dw     0
@SaveBX: dw     0
@SaveCX: dw     0
@SaveDX: dw     0
@SaveES: dw     0
@SaveDI: dw     0
@SaveSI: dw     0
@SaveDS: dw     0
@SaveSS: dw     0
@SaveSP: dw     0
@SaveBP: dw     0
@Start:
        cmp     byte ptr cs:@Busy,0
        je      @Go
        jmp     @Exit
@Go:    mov     byte ptr cs:@Busy,1
        mov     word ptr cs:@SaveAX,ax
        mov     word ptr cs:@SaveBX,bx
        mov     word ptr cs:@SaveCX,cx
        mov     word ptr cs:@SaveDX,dx
        mov     word ptr cs:@SaveDI,di
        mov     word ptr cs:@SaveSI,si
        mov     word ptr cs:@SaveES,es
        mov     word ptr cs:@SaveDS,ds
        mov     word ptr cs:@SaveSS,ss
        mov     word ptr cs:@SaveSP,sp
        mov     word ptr cs:@SaveBP,bp
        mov     ax,seg @Data
        mov     ds,ax
        shr     cx,3
        shr     dx,3
        inc     cx
        inc     dx
        mov     MouseButton,bx
        mov     MouseMoved,0
        cmp     MouseX,cx
        jne     @Moved
        cmp     MouseY,dx
        je      @Restore
@Moved: mov     MouseX,cx
        mov     MouseY,dx
        mov     cx,ScreenMask
        mov     dx,CursorMask
        cmp     cl,0
        je      @SetCur
        mov     ax,MouseY
        dec     ax
        mul     byte ptr cs:@Cols
        add     ax,MouseX
        dec     ax
        add     ax,offset MouseMap
        mov     bx,ax
        mov     dl,[bx]
        cmp     dl,0
        je      @SetCur
        mov     cl,0
@SetCur: mov    ax,0Ah
        mov     bx,0
        int     33h
@Restore:
        cli
        mov     ax,word ptr cs:@SaveAX
        mov     bx,word ptr cs:@SaveBX
        mov     cx,word ptr cs:@SaveCX
        mov     dx,word ptr cs:@SaveDX
        mov     di,word ptr cs:@SaveDI
        mov     si,word ptr cs:@SaveSI
        mov     es,word ptr cs:@SaveES
        mov     ds,word ptr cs:@SaveDS
        mov     ss,word ptr cs:@SaveSS
        mov     sp,word ptr cs:@SaveSP
        mov     bp,word ptr cs:@SaveBP
        mov     byte ptr cs:@Busy,0
        sti
@Exit:
end;

procedure MouseTextCursor;
begin
  Regs.CX := ScreenMask;
  Regs.DX := CursorMask;
  Regs.DL := MouseMap[MouseY, MouseX];
  if Regs.DL <> 0 then Regs.CL := 0;
  Regs.AX := $0A;
  Regs.BX := 0;
  MouseCall;
  MouseDefCursor;
end;

procedure InstallHandler;
begin
  Regs.AX := $0C;
  Regs.CX := $1F;
  Regs.DX := Ofs(MouseHandler);
  Regs.ES := Seg(MouseHandler);
  MouseCall;
end;

procedure MouseReleases(var N: Word);
begin
  Regs.AX := 6;
  Regs.BX := 0;
  MouseCall;
  N := Regs.BX;
end;

procedure MousePresses(var N: Word);
begin
  Regs.AX := 5;
  Regs.BX := 0;
  MouseCall;
  N := Regs.BX;
end;

procedure MouseDefCursor;
begin
  Regs.AX := $0A;
  Regs.BX := 0;
  Regs.CX := ScreenMask;
  Regs.DX := CursorMask;
  MouseCall;
end;

procedure MouseSetCursor(Screen, Cursor: Word);
begin
  Regs.AX := $0A;
  Regs.BX := 0;
  Regs.CX := Screen;
  Regs.DX := Cursor;
  MouseCall;
end;

function DoubleClick(X, Y: Integer): Boolean;
var
  Done: Boolean;
  Released, Pressed, N, Dummy: Word;
  Count: LongInt;
begin
  Done := False;
  DoubleClick := False;
  if not ((MouseX = X) and (MouseY = Y) and (MouseButton = 1)) then Exit;
    Released := 0;
    Pressed := 0;
    MouseReleases(N);
    MousePresses(N);
    Count := 500000;
    MouseSetCursor(0, $0E3F);
    repeat
      if Pressed <> 2 then Count := Count - 1;
      MouseReleases(N);
      if N <> 0 then Released := Released + N;
      MousePresses(N);
      if N <> 0 then Pressed := Pressed + N;
      if Pressed = 1 then
      begin
        Pressed := 2;
        MouseSetCursor(0, $0EFB);
      end;
      if (Released = 2) and (MouseX = X) and (MouseY = Y) then Done := True;
    until (MouseX <> X) or (MouseY <> Y) or Done or (Count <= 0) or KeyPressed or (MouseButton = 2);
    DoubleClick := Done;
    MouseDefCursor;
end;


procedure MouseSensitivity(S: Byte);
begin
  Regs.AX := $1A;
  Regs.BX := S;
  Regs.CX := S;
  Regs.DX := 5000;
  Intr($33, Regs);
end;

end.
