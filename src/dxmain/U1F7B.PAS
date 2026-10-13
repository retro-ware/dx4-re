{$F+,G+,S-}
unit U1F7B;
{ PLACEHOLDER for resident segment 1f7b; only the entries referenced so far are declared, with stub bodies }

interface

function FindCDDrive(var Drive: Byte): Boolean;          { 1f7b:0027 }
function P1F7B_0(N: Byte): Byte;                        { 1f7b:0000 }
function P1F7B_9E(Drv, Side, Track, Spt: Byte; P: Pointer): Boolean;   { 1f7b:009e }
function P1F7B_120(Drv, Side, Track, Sector, Count: Byte; var Buf): Boolean;   { 1f7b:0120 }
function P1F7B_1A4(Drv, Side, Track, Sector, Spt: Byte; P: Pointer; Verify: Byte): Boolean;   { 1f7b:01a4 }
function P1F7B_26E(Drv, Side, Track, Sector, Spt: Byte; P: Pointer): Boolean;   { 1f7b:026e }
function P1F7B_2CD(Drv, Tracks, Spt: Byte; var P: Pointer): Boolean;   { 1f7b:02cd }
function P1F7B_320(Drv, Side, Track, Spt: Byte): Byte;    { 1f7b:0320 }
function ReadSector(Drive, Head, Track, Sector: Byte; var Buf): Boolean;   { 1f7b:009e }
function WriteSectors(Drive, Head, Track, Sector, Count: Byte; var Buf; Verify: Byte): Byte;   { 1f7b:01a4 }

implementation

function FindCDDrive(var Drive: Byte): Boolean;
begin
  FindCDDrive := False;
end;

function ReadSector(Drive, Head, Track, Sector: Byte; var Buf): Boolean;
begin
end;

function WriteSectors(Drive, Head, Track, Sector, Count: Byte; var Buf; Verify: Byte): Byte;
begin
end;

function P1F7B_0(N: Byte): Byte;
begin
end;

function P1F7B_9E(Drv, Side, Track, Spt: Byte; P: Pointer): Boolean;
begin
end;

function P1F7B_120(Drv, Side, Track, Sector, Count: Byte; var Buf): Boolean;
begin
end;

function P1F7B_1A4(Drv, Side, Track, Sector, Spt: Byte; P: Pointer; Verify: Byte): Boolean;
begin
end;

function P1F7B_26E(Drv, Side, Track, Sector, Spt: Byte; P: Pointer): Boolean;
begin
end;

function P1F7B_2CD(Drv, Tracks, Spt: Byte; var P: Pointer): Boolean;
begin
end;

function P1F7B_320(Drv, Side, Track, Spt: Byte): Byte;
begin
end;

end.
