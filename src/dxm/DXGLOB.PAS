{$F+,G+,S-}
unit DXGlob;

interface

type
  THistory = array[0..25] of string[128];
  PHistory = ^THistory;

const
  IniId: string[41] = 'DOS-Expander 4.0 (C) 1994-1996 Hombergs';
  IniName: string[12] = 'dx.ini';
  X026D: Byte = $00;
  X026E: array[1..136] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, $32, $17, $48, 9, 3, 2, 0);
  SaverProg: string[12] = 'balken.bss';
  X0303: Byte = $00;
  ScrollDelay: Word = 20;
  X0306: Byte = $01;
  BorderColor: Byte = 1;
  ScreenRows: Byte = 25;
  MenuRows: Byte = 18;
  ListRows: Byte = 16;
  HexOnly: Boolean = False;
  DigOnly: Boolean = False;
  BinOnly: Boolean = False;
  MinusOk: Boolean = False;
  X030F: Byte = $00;
  X0310: array[1..30] of Byte = (0, 0, 7, $6C, $68, $61, $2E, $65, $78, $65, 0, 0, 0, 0, 0, 0, 3, $2A, $2E, $2A,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  Password: string[12] = 'dx';
  HistCount: Byte = 0;
  SaverDelay: Word = 300;
  StatX: Byte = 75;
  StatY: Byte = 1;
  StatFg: Byte = 0;
  StatBg: Byte = 3;
  X0342: array[1..40] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  ClockHidden: Boolean = False;
  DateHidden: Boolean = False;
  G36C: Word = 1;
  LastDate: string[25] = 'x';
  LastTime: string[6] = 'x';
  X038F: Byte = $00;
  HomeDir: string[79] = '';
  X03E0: array[1..240] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    4, $45, $44, $49, $54, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  InsMode: Boolean = True;
  X04D1: Byte = $0E;
  Replay: Boolean = False;
  X04D3: Byte = $00;
  X04D4: array[1..8] of Byte = (0, 0, 0, 0, 0, 0, 0, 0);
  DblClickSelect: Boolean = False;
  X04DD: Byte = $00;
  Opt4DE: Byte = 1;
  X04DF: Byte = $00;
  X04E0: array[1..4] of Byte = (0, 0, 0, 0);
  X04E4: Byte = $00;
  SortAsc: Boolean = True;
  X04E6: array[1..6] of Byte = (0, 1, 0, 0, 1, 0);
  SaverOn: Boolean = True;
  MouseSaver: Boolean = False;
  SaverExt: Boolean = False;
  SaverStars: Boolean = True;
  SaverDot: Boolean = False;
  ThinButtons: Boolean = False;
  X04F2: array[1..2] of Byte = (0, 0);
  X04F4: Byte = $00;
  ShowLabels: Boolean = True;
  X04F6: array[1..2] of Byte = (0, 1);
  X04F8: Byte = $01;
  FadeOn: Boolean = True;
  X04FA: Byte = $01;
  PasswordOn: Boolean = False;
  X04FC: array[1..2] of Byte = (0, 1);
  BigCursor: Boolean = False;
  Explode: Boolean = False;
  X0500: array[1..6] of Byte = (0, 0, 1, 1, 1, 1);
  X0506: Byte = $01;
  G507: Boolean = True;
  SoundOn: Boolean = True;
  X0509: Byte = $00;
  X050A: array[1..14] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
  NoMouseReset: Boolean = False;
  X0519: Byte = $01;
  X051A: array[1..6] of Byte = (0, 0, 0, 0, 0, 0);
  Opt520: Byte = 1;
  X0521: Byte = $00;
  X0522: array[1..64] of Byte = (0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0);
  History: PHistory = nil;
  DriveFlag: array[1..26] of Boolean = (
    False, False, True, True, True, True, True, True,
    True, True, True, True, True, True, True, True,
    True, True, True, True, True, True, True, True,
    True, True);
  X0580: array[1..76] of Byte = (1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 3, 1, 7, 1, 2, 1, $0A, 1, $0E, 1, 5, 1, 9, 1,
    9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, $0B, 1, $0B, 1, $0B, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

implementation

end.
