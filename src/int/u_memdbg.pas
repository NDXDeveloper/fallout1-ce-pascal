{$MODE OBJFPC}{$H+}
// Converted from: src/int/memdbg.cc/h
// Debug memory allocation wrappers for the script interpreter.
unit u_memdbg;

interface

type
  TMemDbgMallocFunc = function(size: SizeUInt): Pointer; cdecl;
  TMemDbgReallocFunc = function(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
  TMemDbgFreeFunc = procedure(ptr: Pointer); cdecl;
  TMemDbgDebugFunc = procedure(const str: PAnsiChar); cdecl;

  PMemDbgMallocFunc = ^TMemDbgMallocFunc;
  PMemDbgReallocFunc = ^TMemDbgReallocFunc;
  PMemDbgFreeFunc = ^TMemDbgFreeFunc;
  PMemDbgDebugFunc = ^TMemDbgDebugFunc;

procedure memoryRegisterDebug(func: TMemDbgDebugFunc);
procedure memoryRegisterAlloc(mallocFunc: TMemDbgMallocFunc;
  reallocFunc: TMemDbgReallocFunc; freeFunc: TMemDbgFreeFunc);
function my_check_all: Integer;
function mymalloc(size: SizeUInt; const file_: PAnsiChar; line: Integer): Pointer;
function myrealloc(ptr: Pointer; size: SizeUInt; const file_: PAnsiChar; line: Integer): Pointer;
procedure myfree(ptr: Pointer; const file_: PAnsiChar; line: Integer);
function mycalloc(count, size: Integer; const file_: PAnsiChar; line: Integer): Pointer;
function mystrdup(const str: PAnsiChar; const file_: PAnsiChar; line: Integer): PAnsiChar;

implementation

uses
  SysUtils;

var
  debug_printf_buf: array[0..255] of AnsiChar;

function defaultMalloc(size: SizeUInt): Pointer; cdecl; forward;
function defaultRealloc(ptr: Pointer; size: SizeUInt): Pointer; cdecl; forward;
procedure defaultFree(ptr: Pointer); cdecl; forward;
procedure defaultOutput(const str: PAnsiChar); cdecl; forward;

var
  outputFunc: TMemDbgDebugFunc = @defaultOutput;
  mallocPtr: TMemDbgMallocFunc = @defaultMalloc;
  reallocPtr: TMemDbgReallocFunc = @defaultRealloc;
  freePtr: TMemDbgFreeFunc = @defaultFree;

procedure defaultOutput(const str: PAnsiChar); cdecl;
begin
  Write(str);
end;

procedure memoryRegisterDebug(func: TMemDbgDebugFunc);
begin
  outputFunc := func;
end;

function debug_printf_(const fmt: PAnsiChar; const args: array of const): Integer;
var
  s: AnsiString;
begin
  Result := 0;
  if outputFunc <> nil then
  begin
    try
      s := Format(fmt, args);
    except
      s := fmt;
    end;
    if Length(s) > 255 then
      SetLength(s, 255);
    Move(s[1], debug_printf_buf[0], Length(s));
    debug_printf_buf[Length(s)] := #0;
    outputFunc(@debug_printf_buf[0]);
    Result := Length(s);
  end;
end;

procedure error_(const func_: PAnsiChar; size: SizeUInt; const file_: PAnsiChar; line: Integer);
begin
  debug_printf_('%s: Error allocating block of size %d (%x), %s %d'#10,
    [func_, Integer(size), Integer(size), file_, line]);
  Halt(1);
end;

function defaultMalloc(size: SizeUInt): Pointer; cdecl;
begin
  Result := GetMem(size);
end;

function defaultRealloc(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
begin
  Result := ReAllocMem(ptr, size);
end;

procedure defaultFree(ptr: Pointer); cdecl;
begin
  FreeMem(ptr);
end;

procedure memoryRegisterAlloc(mallocFunc: TMemDbgMallocFunc;
  reallocFunc: TMemDbgReallocFunc; freeFunc: TMemDbgFreeFunc);
begin
  mallocPtr := mallocFunc;
  reallocPtr := reallocFunc;
  freePtr := freeFunc;
end;

function my_check_all: Integer;
begin
  Result := 0;
end;

function mymalloc(size: SizeUInt; const file_: PAnsiChar; line: Integer): Pointer;
begin
  Result := mallocPtr(size);
  if Result = nil then
    error_('malloc', size, file_, line);
end;

function myrealloc(ptr: Pointer; size: SizeUInt; const file_: PAnsiChar; line: Integer): Pointer;
begin
  Result := reallocPtr(ptr, size);
  if Result = nil then
    error_('realloc', size, file_, line);
end;

procedure myfree(ptr: Pointer; const file_: PAnsiChar; line: Integer);
begin
  if ptr = nil then
  begin
    debug_printf_('free: free of a null ptr, %s %d'#10, [file_, line]);
    Halt(1);
  end;
  freePtr(ptr);
end;

function mycalloc(count, size: Integer; const file_: PAnsiChar; line: Integer): Pointer;
var
  totalSize: SizeUInt;
begin
  totalSize := SizeUInt(count) * SizeUInt(size);
  Result := mallocPtr(totalSize);
  if Result = nil then
    error_('calloc', totalSize, file_, line);
  FillChar(Result^, totalSize, 0);
end;

function mystrdup(const str: PAnsiChar; const file_: PAnsiChar; line: Integer): PAnsiChar;
var
  size: SizeUInt;
  copy: PAnsiChar;
begin
  size := StrLen(str) + 1;
  copy := PAnsiChar(mallocPtr(size));
  if copy = nil then
    error_('strdup', size, file_, line);
  Move(str^, copy^, size);
  Result := copy;
end;

end.
