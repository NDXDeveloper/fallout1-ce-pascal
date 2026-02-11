unit u_wordwrap;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  WORD_WRAP_MAX_COUNT = 64;

function word_wrap(str: PAnsiChar; width: Integer; breakpoints: PSmallInt; breakpointsLengthPtr: PSmallInt): Integer;

implementation

uses
  u_text;

function isspace_c(ch: Integer): Boolean;
begin
  Result := (ch = 32) or ((ch >= 9) and (ch <= 13));
end;

function word_wrap(str: PAnsiChar; width: Integer; breakpoints: PSmallInt; breakpointsLengthPtr: PSmallInt): Integer;
var
  index: Integer;
  gap: Integer;
  accum: Integer;
  prevSpaceOrHyphen: PAnsiChar;
  pch: PAnsiChar;
begin
  breakpoints[0] := 0;
  breakpointsLengthPtr^ := 1;

  for index := 1 to WORD_WRAP_MAX_COUNT - 1 do
    breakpoints[index] := -1;

  if text_max() > width then
  begin
    Result := -1;
    Exit;
  end;

  if text_width(str) < width then
  begin
    breakpoints[breakpointsLengthPtr^] := SmallInt(StrLen(str));
    breakpointsLengthPtr^ := breakpointsLengthPtr^ + 1;
    Result := 0;
    Exit;
  end;

  gap := text_spacing();

  accum := 0;
  prevSpaceOrHyphen := nil;
  pch := str;
  while pch^ <> #0 do
  begin
    accum := accum + gap + text_char_width(AnsiChar(Ord(pch^) and $FF));
    if accum <= width then
    begin
      if isspace_c(Ord(pch^) and $FF) or (pch^ = '-') then
        prevSpaceOrHyphen := pch;
    end
    else
    begin
      if breakpointsLengthPtr^ = WORD_WRAP_MAX_COUNT then
      begin
        Result := -1;
        Exit;
      end;

      if prevSpaceOrHyphen <> nil then
      begin
        breakpoints[breakpointsLengthPtr^] := SmallInt(prevSpaceOrHyphen - str + 1);
        breakpointsLengthPtr^ := breakpointsLengthPtr^ + 1;
        pch := prevSpaceOrHyphen;
      end
      else
      begin
        breakpoints[breakpointsLengthPtr^] := SmallInt(pch - str);
        breakpointsLengthPtr^ := breakpointsLengthPtr^ + 1;
        Dec(pch);
      end;

      prevSpaceOrHyphen := nil;
      accum := 0;
    end;
    Inc(pch);
  end;

  if breakpointsLengthPtr^ = WORD_WRAP_MAX_COUNT then
  begin
    Result := -1;
    Exit;
  end;

  breakpoints[breakpointsLengthPtr^] := SmallInt(pch - str + 1);
  breakpointsLengthPtr^ := breakpointsLengthPtr^ + 1;

  Result := 0;
end;

end.
