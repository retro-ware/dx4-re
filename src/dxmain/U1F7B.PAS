{$F+,G+,S-}
unit U1F7B;
{ PLACEHOLDER for resident segment 1f7b; only the entries referenced so far are declared, with stub bodies }

interface

function FindCDDrive(var Drive: Byte): Boolean;          { 1f7b:0027 }

implementation

function FindCDDrive(var Drive: Byte): Boolean;
begin
  FindCDDrive := False;
end;

end.
