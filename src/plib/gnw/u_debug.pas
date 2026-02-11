{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/debug.h + debug.cc
// Debug output system for GNW library.
unit u_debug;

interface

type
  TDebugFunc = function(AString: PAnsiChar): Integer; cdecl;

procedure GNW_debug_init;
procedure debug_register_mono;
procedure debug_register_log(const FileName: PAnsiChar; const Mode: PAnsiChar);
procedure debug_register_screen;
procedure debug_register_env;
procedure debug_register_func(AFunc: TDebugFunc);
function debug_printf(const Format: PAnsiChar): Integer;
function debug_printf(const Format: string; const Args: array of const): Integer;
function debug_puts(AString: PAnsiChar): Integer;
procedure debug_clear;

implementation

uses
  SysUtils;

// Forward declarations for static debug output functions
function debug_mono(AString: PAnsiChar): Integer; cdecl; forward;
function debug_log(AString: PAnsiChar): Integer; cdecl; forward;
function debug_screen(AString: PAnsiChar): Integer; cdecl; forward;
procedure debug_putc(ch: Integer); forward;
procedure debug_scroll; forward;
procedure debug_exit; forward;

var
  // 0x539D5C
  fd: Text;
  fd_open: Boolean = False;

  // 0x539D60
  curx: Integer = 0;

  // 0x539D64
  cury: Integer = 0;

  // 0x539D68
  debug_func: TDebugFunc = nil;

// 0x4B2D90
procedure GNW_debug_init;
begin
  // In C this called atexit(debug_exit). In Pascal we use a finalization section.
end;

// 0x4B2D9C
procedure debug_register_mono;
begin
  if debug_func <> TDebugFunc(@debug_mono) then
  begin
    if fd_open then
    begin
      Close(fd);
      fd_open := False;
    end;

    debug_func := TDebugFunc(@debug_mono);
    debug_clear;
  end;
end;

// 0x4B2DD8
procedure debug_register_log(const FileName: PAnsiChar; const Mode: PAnsiChar);
begin
  // NOTE: Original C code has a likely bug in the condition:
  //   if ((mode[0] == 'w' && mode[1] == 'a') && mode[1] == 't')
  // mode[1] cannot be both 'a' and 't' simultaneously, so this condition
  // can never be true. Preserving the original logic faithfully.
  // The intended condition was probably:
  //   (mode[0] == 'w' || mode[0] == 'a') && mode[1] == 't'
  if ((Mode[0] = 'w') and (Mode[1] = 'a')) and (Mode[1] = 't') then
  begin
    if fd_open then
      Close(fd);

    AssignFile(fd, FileName);
    {$I-}
    if Mode[0] = 'a' then
      Append(fd)
    else
      Rewrite(fd);
    {$I+}

    if IOResult = 0 then
    begin
      fd_open := True;
      debug_func := TDebugFunc(@debug_log);
    end
    else
      fd_open := False;
  end;
end;

// 0x4B2E1C
procedure debug_register_screen;
begin
  if debug_func <> TDebugFunc(@debug_screen) then
  begin
    if fd_open then
    begin
      Close(fd);
      fd_open := False;
    end;

    debug_func := TDebugFunc(@debug_screen);
  end;
end;

// 0x4B2E50
procedure debug_register_env;
var
  EnvType: string;
  Copy: string;
begin
  EnvType := GetEnvironmentVariable('DEBUGACTIVE');
  if EnvType = '' then
    Exit;

  Copy := LowerCase(EnvType);

  if Copy = 'mono' then
  begin
    // NOTE: Uninline.
    debug_register_mono;
  end
  else if Copy = 'log' then
  begin
    debug_register_log('debug.log', 'wt');
  end
  else if Copy = 'screen' then
  begin
    // NOTE: Uninline.
    debug_register_screen;
  end
  else if Copy = 'gnw' then
  begin
    // TODO: References win_debug from intrface unit, which does not exist yet.
    // When u_intrface is implemented, add:
    //   if debug_func <> @win_debug then
    //   begin
    //     if fd_open then
    //     begin
    //       Close(fd);
    //       fd_open := False;
    //     end;
    //     debug_func := @win_debug;
    //   end;
  end;
end;

// 0x4B2FD8
procedure debug_register_func(AFunc: TDebugFunc);
begin
  if debug_func <> AFunc then
  begin
    if fd_open then
    begin
      Close(fd);
      fd_open := False;
    end;

    debug_func := AFunc;
  end;
end;

// 0x4B3008
// Overload: no args, format string is the message itself
function debug_printf(const Format: PAnsiChar): Integer;
var
  Str: array[0..259] of AnsiChar;
  Len: Integer;
begin
  if debug_func <> nil then
  begin
    Len := Length(Format);
    if Len > 259 then
      Len := 259;
    Move(Format^, Str[0], Len);
    Str[Len] := #0;
    Result := debug_func(@Str[0]);
  end
  else
  begin
    {$IFDEF DEBUG}
    Write(Format);
    {$ENDIF}
    Result := -1;
  end;
end;

// 0x4B3008
// Overload: with formatting args
function debug_printf(const Format: string; const Args: array of const): Integer;
var
  Str: array[0..259] of AnsiChar;
  Formatted: string;
  Len: Integer;
begin
  if debug_func <> nil then
  begin
    Formatted := SysUtils.Format(Format, Args);
    Len := Length(Formatted);
    if Len > 259 then
      Len := 259;
    Move(Formatted[1], Str[0], Len);
    Str[Len] := #0;
    Result := debug_func(@Str[0]);
  end
  else
  begin
    {$IFDEF DEBUG}
    Write(SysUtils.Format(Format, Args));
    {$ENDIF}
    Result := -1;
  end;
end;

// C-compatible debug_printf symbol for cdecl varargs callers.
// Extra varargs are ignored (caller cleans stack in cdecl).
function debug_printf_c(const fmt: PAnsiChar): Integer; cdecl; public name 'debug_printf';
begin
  Result := debug_printf(fmt);
end;

// 0x4B3054
function debug_puts(AString: PAnsiChar): Integer;
begin
  if debug_func <> nil then
    Result := debug_func(AString)
  else
    Result := -1;
end;

// 0x4B306C
// NOTE: The original code writes directly to memory-mapped VGA text buffers
// at 0xB0000 (mono) and 0xB8000 (screen). This is DOS legacy and is a no-op
// on modern systems. We simply reset the cursor position.
procedure debug_clear;
begin
  if (debug_func = TDebugFunc(@debug_mono)) or (debug_func = TDebugFunc(@debug_screen)) then
  begin
    // On DOS this would clear the text-mode video buffer.
    // On modern systems this is a no-op for the buffer write.
    cury := 0;
    curx := 0;
  end;
end;

// 0x4B30C4
// NOTE: Original writes to 0xB0000 mono buffer; no-op on modern systems,
// we write to stdout instead.
function debug_mono(AString: PAnsiChar): Integer; cdecl;
begin
  if debug_func = TDebugFunc(@debug_mono) then
  begin
    while AString^ <> #0 do
    begin
      debug_putc(Ord(AString^));
      Inc(AString);
    end;
  end;
  Result := 0;
end;

// 0x4B30E8
function debug_log(AString: PAnsiChar): Integer; cdecl;
begin
  Result := 0;
  if debug_func = TDebugFunc(@debug_log) then
  begin
    if not fd_open then
    begin
      Result := -1;
      Exit;
    end;

    {$I-}
    Write(fd, AString);
    if IOResult <> 0 then
    begin
      Result := -1;
      Exit;
    end;

    Flush(fd);
    if IOResult <> 0 then
    begin
      Result := -1;
      Exit;
    end;
    {$I+}
  end;
end;

// 0x4B3128
function debug_screen(AString: PAnsiChar): Integer; cdecl;
begin
  if debug_func = TDebugFunc(@debug_screen) then
    Write(AString);

  Result := 0;
end;

// 0x4B315C
// NOTE: Original writes to memory-mapped mono display at 0xB0000.
// On modern systems we redirect to stdout as a best-effort equivalent.
procedure debug_putc(ch: Integer);
begin
  case ch of
    7: // Bell
      Write(#7);
    8: // Backspace
      begin
        if curx > 0 then
        begin
          Dec(curx);
          // Original: write space+attribute to video buffer. No-op here.
          Write(#8, ' ', #8);
        end;
      end;
    9: // Tab
      begin
        repeat
          debug_putc(Ord(' '));
        until (curx - 1) mod 4 = 0;
      end;
    13: // Carriage return
      begin
        curx := 0;
        Write(#13);
      end;
    10: // Line feed
      begin
        curx := 0;
        Inc(cury);
        if cury > 24 then
        begin
          cury := 24;
          debug_scroll;
        end;
        WriteLn;
      end;
  else
    // Default character output
    Write(Chr(ch));
    Inc(curx);
    if curx >= 80 then
    begin
      curx := 0;
      Inc(cury);
      if cury > 24 then
      begin
        cury := 24;
        debug_scroll;
      end;
      WriteLn;
    end;
  end;
end;

// 0x4B326C
// NOTE: Original scrolls the memory-mapped mono text buffer. No-op on modern systems.
procedure debug_scroll;
begin
  // On DOS this would scroll the text-mode video buffer up by one line.
  // On modern systems using stdout, scrolling is handled by the terminal.
end;

// 0x4B32A8
procedure debug_exit;
begin
  if fd_open then
  begin
    {$I-}
    Close(fd);
    {$I+}
    fd_open := False;
  end;
end;

finalization
  debug_exit;

end.
