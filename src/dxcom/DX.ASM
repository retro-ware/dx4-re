; DX.COM - DOS-Expander 4.0 loader stub (C) 1994-1996 Hombergs
; Runs DXMAIN.EXE and, while it asks for it, COMSPEC /c <command>.
code    segment
        assume  cs:code, ds:code, es:code, ss:code
        org     100h
entry:  jmp     start

SaveSP  dw      0
XmsEntry dd     0
XmsHandle dw    0
ProgName db     80 dup (0)
        db      0Ah,0Dh,'$'
ComSpec db      80 dup (0)
        db      0Ah,0Dh,'$'
MsgErr  db      'DX: Befehl oder Datei konnte nicht ausgef',81h,'hrt werden.',0Ah,0Dh,'$'
MainTail db     19
SegStr  db      'sssss '
OfsStr  db      'ooooo '
HdlStr  db      'hhhhh '
Mode    db      '1',0Dh
MainPB  dw      0
        dw      offset MainTail
MainPBSeg dw    0
        dd      -1
        dd      -1
CmdTail db      0,'/c'
CmdLen  db      0
        db      160 dup (0Dh)
CmdPB   dw      0
        dw      offset CmdTail
CmdPBSeg dw     0
        dd      -1
        dd      -1

RunMain:
        mov     bx,offset MainPB
        mov     dx,offset ProgName
        mov     SaveSP,sp
        mov     ax,4B00h
        int     21h
        cli
        mov     sp,SaveSP
        mov     ax,cs
        mov     ss,ax
        mov     es,ax
        mov     ds,ax
        sti
        jnc     MainOk
        mov     ah,9
        mov     dx,offset MsgErr
        int     21h
        mov     ah,9
        mov     dx,offset ProgName
        int     21h
        jmp     Quit
MainOk: mov     ah,4Dh
        int     21h
        cmp     al,0
        jz      Quit
        mov     Mode,'0'
        mov     al,CmdLen
        add     al,3
        mov     CmdTail,al
        mov     CmdLen,' '
        mov     bx,offset CmdTail
        mov     ah,0
        inc     ax
        add     bx,ax
        mov     al,0Dh
        mov     [bx],al
        mov     bx,offset CmdPB
        mov     dx,offset ComSpec
        mov     ax,4B00h
        mov     SaveSP,sp
        int     21h
        cli
        mov     sp,SaveSP
        mov     ax,cs
        mov     ss,ax
        mov     es,ax
        mov     ds,ax
        sti
        jnc     RunMain
        mov     ah,9
        mov     dx,offset MsgErr
        int     21h
        mov     ah,9
        mov     dx,offset ComSpec
        int     21h
        jmp     RunMain
Quit:   mov     ax,4C00h
        int     21h

MainName db     'MAIN.EXE',0
MsgVga  db      'Der DX l',84h,'uft nur mit Farb-VGA-Karten!',0Ah,0Dh,'$'
MsgCopy db      'Dos-Expander 4.0 (C) Copyright 1994-1996 Hombergs.',0Ah,0Dh,'$'
EnvName db      'COMSPEC='
MsgDxa  db      'DX: Dxa.ini wird geladen!',0Ah,0Dh,'$'
EnvEnd  dw      0
MsgNoCs db      'Umgebungsvariable COMSPEC= nicht gefunden!',0Ah,0Dh,'$'

start:  mov     ah,9
        mov     dx,offset MsgCopy
        int     21h
        mov     MainPBSeg,cs
        mov     CmdPBSeg,cs
        cld
        mov     ax,1A00h
        int     10h
        cmp     al,1Ah
        je      IsVga
        mov     ah,9
        mov     dx,offset MsgVga
        int     21h
        jmp     Quit
IsVga:  cmp     byte ptr ds:[80h],0
        je      NoArgs
        mov     di,81h
        mov     al,'a'
        mov     ch,0
        mov     cl,ds:[80h]
        repne   scasb
        jne     NoArgs
        mov     ah,9
        mov     dx,offset MsgDxa
        int     21h
        mov     Mode,'2'
NoArgs: mov     ax,4300h
        int     2Fh
        cmp     al,80h
        jne     NoXms
        mov     ax,4310h
        int     2Fh
        mov     word ptr XmsEntry,bx
        mov     word ptr XmsEntry+2,es
        mov     ah,9
        mov     dx,32
        call    XmsEntry
        cmp     ax,1
        jne     NoXms
        mov     XmsHandle,dx
NoXms:  mov     ax,cs
        mov     si,0
        call    PutNum
        mov     ax,offset CmdLen
        mov     si,6
        call    PutNum
        mov     ax,XmsHandle
        mov     si,12
        call    PutNum
        mov     es,word ptr ds:[2Ch]
        cld
        mov     di,0
SkipVar: mov    al,0
        mov     cx,7FFFh
        repne   scasb
        cmp     byte ptr es:[di],0
        jne     SkipVar
        mov     EnvEnd,di
        inc     di
        inc     di
        inc     di
        mov     bx,offset ProgName
CopyPath: mov   al,es:[di]
        mov     [bx],al
        inc     di
        inc     bx
        cmp     al,0
        jne     CopyPath
        sub     bx,5
        mov     si,offset MainName
        mov     ax,cs
        mov     es,ax
        mov     di,bx
        mov     cx,4
        rep     movsw
        mov     si,offset EnvName
        mov     es,word ptr ds:[2Ch]
        mov     di,0
        cld
        mov     bx,0
FindCs: mov     si,offset EnvName
        mov     di,bx
        mov     cx,4
        repe    cmpsw
        je      GotCs
        inc     bx
        cmp     bx,EnvEnd
        jne     FindCs
        mov     ah,9
        mov     dx,offset MsgNoCs
        int     21h
        jmp     Shrink
GotCs:  mov     bx,offset ComSpec
CopyCs: mov     al,es:[di]
        mov     [bx],al
        inc     di
        inc     bx
        cmp     al,0
        jne     CopyCs
Shrink: mov     ax,cs
        mov     es,ax
        mov     ah,4Ah
        mov     bx,offset MsgDxa+18
        mov     cl,4
        shr     bx,cl
        inc     bx
        int     21h
        mov     sp,offset MsgDxa+18
        mov     ax,cs
        mov     es,ax
        mov     ss,ax
        mov     ds,ax
        jmp     RunMain

; AX -> 5 decimal digits at SegStr+SI
PutNum: mov     cx,5
        mov     di,10
Digit:  mov     dx,0
        div     di
        add     dx,'0'
        mov     bx,offset MainTail
        add     bx,cx
        add     bx,si
        mov     [bx],dl
        loop    Digit
        ret
code    ends
        end     entry
