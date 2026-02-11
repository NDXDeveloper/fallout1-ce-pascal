unit u_gdebug;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

procedure fatal_error(const format_: PAnsiChar; const message_: PAnsiChar; const file_: PAnsiChar; line: Integer);

implementation

uses
  SysUtils,
  u_gnw;

// External declarations
procedure debug_printf_raw(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

procedure fatal_error(const format_: PAnsiChar; const message_: PAnsiChar; const file_: PAnsiChar; line: Integer);
var
  stringBuffer: array[0..259] of AnsiChar;
begin
  debug_printf_raw(PAnsiChar(#10));
  debug_printf_raw(format_, message_, file_, line);

  win_exit();

  WriteLn;
  WriteLn;
  WriteLn;
  WriteLn;
  Write('   ');
  StrLFmt(stringBuffer, SizeOf(stringBuffer) - 1, '%s (%s line %d)', [message_, file_, line]);
  WriteLn(stringBuffer);
  WriteLn;
  WriteLn;
  WriteLn;
  WriteLn;

  GNWSystemError(stringBuffer);

  Halt(1);
end;

end.
