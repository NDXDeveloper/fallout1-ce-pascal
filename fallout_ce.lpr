program fallout_ce;

{$MODE OBJFPC}{$H+}

// Entry point for Fallout Community Edition (Pascal port).
// Converted from: src/plib/gnw/winmain.cc

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  u_sdl2,
  u_winmain,
  u_main;

// SDL_ShowCursor is not in our minimal u_sdl2 bindings
function SDL_ShowCursor(toggle: Integer): Integer; cdecl; external SDL2_LIB;

const
  SDL_DISABLE = 0;

var
  argc: Integer;
  argvPtrs: array of PAnsiChar;
  argvStrs: array of AnsiString;
  i: Integer;
  rc: Integer;
begin
  argc := ParamCount + 1;
  SetLength(argvStrs, argc);
  SetLength(argvPtrs, argc + 1);
  for i := 0 to argc - 1 do
  begin
    argvStrs[i] := ParamStr(i);
    argvPtrs[i] := PAnsiChar(argvStrs[i]);
  end;
  argvPtrs[argc] := nil;

  SDL_ShowCursor(SDL_DISABLE);

  GNW95_isActive := True;
  rc := gnw_main(argc, @argvPtrs[0]);

  Halt(rc);
end.
