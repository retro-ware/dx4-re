{$F+,G+,S-}
unit U1439;
{ PLACEHOLDER for resident segment 1439 (date functions, day names); only the entries
  referenced so far are declared, with stub bodies }

interface

function DaysInYear(Year: Word): Integer;                               { 1439:00ed }
procedure DateToDayNo(Year, Month, Day: Word; var A; var DayNo: Word; var B); { 1439:032b }
procedure DayNoToDate(DayNo, Year: Word; var Month, Day: Word);          { 1439:04c3 }

implementation

function DaysInYear(Year: Word): Integer;
begin
  DaysInYear := 365;
end;

procedure DateToDayNo(Year, Month, Day: Word; var A; var DayNo: Word; var B);
begin
end;

procedure DayNoToDate(DayNo, Year: Word; var Month, Day: Word);
begin
end;

end.
