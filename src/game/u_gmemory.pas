{$MODE OBJFPC}{$H+}
// Converted from: src/game/gmemory.h + gmemory.cc
// Simple memory wrapper that delegates to u_memory functions.
unit u_gmemory;

interface

function gmemory_init: Integer;
function gmalloc(Size: SizeUInt): Pointer; cdecl;
function grealloc(Ptr: Pointer; NewSize: SizeUInt): Pointer; cdecl;
procedure gfree(Ptr: Pointer); cdecl;

implementation

uses
  u_memory, u_assoc, u_db, u_memdbg;

function gstrdup(const S: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := mem_strdup(S);
end;

// 0x44B0B0
function gmemory_init: Integer;
begin
  assoc_register_mem(@gmalloc, @grealloc, @gfree);
  db_register_mem(@gmalloc, @gstrdup, @gfree);
  memoryRegisterAlloc(@gmalloc, @grealloc, @gfree);
  Result := 0;
end;

// 0x44B0D0
function gmalloc(Size: SizeUInt): Pointer; cdecl;
begin
  Result := mem_malloc(Size);
end;

// 0x44B0E0
function grealloc(Ptr: Pointer; NewSize: SizeUInt): Pointer; cdecl;
begin
  Result := mem_realloc(Ptr, NewSize);
end;

// 0x44B0F0
procedure gfree(Ptr: Pointer); cdecl;
begin
  mem_free(Ptr);
end;

end.
