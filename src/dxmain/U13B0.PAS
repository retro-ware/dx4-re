{$F+,G+,S-}
unit U13B0;
{ PLACEHOLDER for resident segment 13b0 (a small push-button object, $106 bytes); only the entries
  referenced so far are declared, with stub bodies }

interface

type
  T13B0 = object
    Data: array[0..$105] of Byte;
    procedure Init(AX, AY, A, B, C: Byte; S: string);       { 13b0:0002 }
    function Clicked: Boolean;                                { 13b0:01db }
  end;
  T13B0Btn2 = array[0..$211] of Byte;   { two $109-byte buttons }

procedure P13B0_60D(Focus: Boolean; X1, Y1, X2, Y2, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2: string; var B: T13B0Btn2);                      { 13b0:060d }
procedure P13B0_6C0(var Hit1, Hit2: Boolean; var Key: Word; var B: T13B0Btn2);   { 13b0:06c0 }

implementation

procedure T13B0.Init(AX, AY, A, B, C: Byte; S: string);
begin
end;

function T13B0.Clicked: Boolean;
begin
  Clicked := False;
end;

procedure P13B0_60D(Focus: Boolean; X1, Y1, X2, Y2, HotFg, Fg, Light, Bg: Byte;
  Cap1, Cap2: string; var B: T13B0Btn2);
begin
end;

procedure P13B0_6C0(var Hit1, Hit2: Boolean; var Key: Word; var B: T13B0Btn2);
begin
end;

end.
