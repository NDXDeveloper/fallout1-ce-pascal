unit u_version;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

uses
  SysUtils;

const
  VERSION_MAX = 32;
  VERSION_MAJOR = 1;
  VERSION_MINOR = 1;
  VERSION_RELEASE = 'R';
  VERSION_BUILD_TIME = 'Nov 11 1997 14:59:39';

function getverstr(dest: PAnsiChar; size: Integer): PAnsiChar;

implementation

function getverstr(dest: PAnsiChar; size: Integer): PAnsiChar;
begin
  StrLFmt(dest, size - 1, 'FALLOUT %d.%d', [VERSION_MAJOR, VERSION_MINOR]);
  Result := dest;
end;

end.
