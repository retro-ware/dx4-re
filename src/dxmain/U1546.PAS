{$O+,F+,G+,S-,I-}
unit U1546;
{ PLACEHOLDER for overlay unit 1546 (CD audio via MSCDEX, 22 entries); only the entries referenced so far
  are declared (names guessed from their use in CDPlay), with stub bodies }

interface

var
  CDLength: Longint;                                   { 5b42 }
  G5B46: Word;
  CurTrack: Byte;                                      { 5b48 }
  G5B49: Byte;
  TrackStart: array[0..99] of Longint;                 { 5b4a }

procedure CDInit;                                      { 1546:0b32 }
procedure CDTrackTime(L: Longint; var Min, Sec, Frm: Longint);  { 1546:011f }
procedure CDPlay(Start, Len: Longint);                 { 1546:0300 }
function CDTrackStart(N: Word): Longint;               { 1546:035e }
procedure CDGetInfo(var W: Word; var B1, B2, B3, B4, B5, B6, B7: Byte);  { 1546:03b4 }
function CDPosition: Longint;                          { 1546:0436 }
procedure CDUpdate;                                    { 1546:068e }
function CDReady: Boolean;                             { 1546:0704 }
procedure CDPrevTrack(B: Boolean);                     { 1546:096a }
procedure CDRewind;                                    { 1546:08f8 }
procedure CDForward;                                   { 1546:0931 }
procedure CDNextTrack;                                 { 1546:0a09 }
procedure CDResume;                                    { 1546:0a3c }
procedure CDPause;                                     { 1546:0a6a }
function CDDoorOpen: Boolean;                          { 1546:0ac1 }
function CDPaused: Boolean;                            { 1546:0ae1 }
function CDPlaying: Boolean;                           { 1546:0b01 }
function MinSecStr(Min, Sec: Longint): string;         { 1546:0004 }

implementation

procedure CDInit; begin end;
procedure CDTrackTime(L: Longint; var Min, Sec, Frm: Longint); begin end;
procedure CDPlay(Start, Len: Longint); begin end;
function CDTrackStart(N: Word): Longint; begin CDTrackStart := 0; end;
procedure CDGetInfo(var W: Word; var B1, B2, B3, B4, B5, B6, B7: Byte); begin end;
function CDPosition: Longint; begin CDPosition := 0; end;
procedure CDUpdate; begin end;
function CDReady: Boolean; begin CDReady := False; end;
procedure CDPrevTrack(B: Boolean); begin end;
procedure CDRewind; begin end;
procedure CDForward; begin end;
procedure CDNextTrack; begin end;
procedure CDResume; begin end;
procedure CDPause; begin end;
function CDDoorOpen: Boolean; begin CDDoorOpen := False; end;
function CDPaused: Boolean; begin CDPaused := False; end;
function CDPlaying: Boolean; begin CDPlaying := False; end;
function MinSecStr(Min, Sec: Longint): string; begin MinSecStr := ''; end;

end.
