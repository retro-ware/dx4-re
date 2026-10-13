{$F+,G+,S-}
unit U0DA0;

interface

procedure SetMemTop(P: Pointer);

implementation

procedure SetMemTop(P: Pointer);
begin
  asm
    mov bx,word ptr P
    add bx,15
    mov cl,4
    shr bx,cl
    add bx,word ptr P+2
    mov ax,PrefixSeg
    sub bx,ax
    mov es,ax
    mov ah,4Ah
    int 21h
  end;
end;

end.
