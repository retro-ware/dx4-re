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

implementation

procedure T13B0.Init(AX, AY, A, B, C: Byte; S: string);
begin
end;

function T13B0.Clicked: Boolean;
begin
  Clicked := False;
end;

end.
