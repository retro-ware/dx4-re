{$F+,G+,S-,I-}
unit U109E;
{ PLACEHOLDER for resident unit 109e (XMS/EMS driver interface); only entries referenced so far }

interface

function XmsPresent: Boolean;
function GetXms(var Free, Largest: Word): Boolean;
function GetEms(var Free, Total: Longint): Boolean;
function XmsInfo(Handle: Word; var Locks, FreeHandles: Byte; var Size: Word): Boolean;
function XmsLock(Handle: Word; var Addr: Longint): Boolean;
procedure XmsUnlock(Handle: Word);

implementation

function XmsPresent: Boolean;
begin
end;

function GetXms(var Free, Largest: Word): Boolean;
begin
end;

function GetEms(var Free, Total: Longint): Boolean;
begin
end;

function XmsInfo(Handle: Word; var Locks, FreeHandles: Byte; var Size: Word): Boolean;
begin
end;

function XmsLock(Handle: Word; var Addr: Longint): Boolean;
begin
end;

procedure XmsUnlock(Handle: Word);
begin
end;

end.
