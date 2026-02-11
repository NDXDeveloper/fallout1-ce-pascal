{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/memory.h + memory.cc
// Memory management wrapper with guard blocks for debugging.
unit u_memory;

interface

type
  TMallocFunc = function(Size: SizeUInt): Pointer; cdecl;
  TReallocFunc = function(Ptr: Pointer; NewSize: SizeUInt): Pointer; cdecl;
  TFreeFunc = procedure(Ptr: Pointer); cdecl;

function mem_strdup(const AString: PAnsiChar): PAnsiChar;
function mem_malloc(Size: SizeUInt): Pointer;
function mem_realloc(Ptr: Pointer; Size: SizeUInt): Pointer;
procedure mem_free(Ptr: Pointer);
procedure mem_check;
procedure mem_register_func(AMallocFunc: TMallocFunc; AReallocFunc: TReallocFunc; AFreeFunc: TFreeFunc);

implementation

uses
  SysUtils,
  u_debug;

const
  // A special value that denotes a beginning of a memory block data.
  // 0xFEEDFACE
  MEMORY_BLOCK_HEADER_GUARD = Integer($FEEDFACE);

  // A special value that denotes an ending of a memory block data.
  // 0xBEEFCAFE
  MEMORY_BLOCK_FOOTER_GUARD = Integer($BEEFCAFE);

type
  // A header of a memory block.
  TMemoryBlockHeader = record
    // Size of the memory block including header and footer.
    Size: SizeUInt;
    // See MEMORY_BLOCK_HEADER_GUARD.
    Guard: Integer;
  end;
  PMemoryBlockHeader = ^TMemoryBlockHeader;

  // A footer of a memory block.
  TMemoryBlockFooter = record
    // See MEMORY_BLOCK_FOOTER_GUARD.
    Guard: Integer;
  end;
  PMemoryBlockFooter = ^TMemoryBlockFooter;

// TODO: GNW_win_init_flag should come from the u_gnw unit once it is implemented.
// For now we use a local placeholder variable.
var
  GNW_win_init_flag: Boolean = False;

// Forward declarations for static functions
function my_malloc(Size: SizeUInt): Pointer; cdecl; forward;
function my_realloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl; forward;
procedure my_free(Ptr: Pointer); cdecl; forward;
function mem_prep_block(Block: Pointer; Size: SizeUInt): Pointer; forward;
procedure mem_check_block(Block: Pointer); forward;

var
  // 0x539D18
  p_malloc: TMallocFunc = @my_malloc;

  // 0x539D1C
  p_realloc: TReallocFunc = @my_realloc;

  // 0x539D20
  p_free: TFreeFunc = @my_free;

  // 0x539D24
  num_blocks: Integer = 0;

  // 0x539D28
  max_blocks: Integer = 0;

  // 0x539D2C
  mem_allocated: SizeUInt = 0;

  // 0x539D30
  max_allocated: SizeUInt = 0;

// 0x4AEBE0
function mem_strdup(const AString: PAnsiChar): PAnsiChar;
var
  Copy: PAnsiChar;
  Len: SizeUInt;
begin
  Copy := nil;
  if AString <> nil then
  begin
    Len := StrLen(AString);
    Copy := PAnsiChar(p_malloc(Len + 1));
    if Copy <> nil then
      StrCopy(Copy, AString);
  end;
  Result := Copy;
end;

// 0x4AEC30
function mem_malloc(Size: SizeUInt): Pointer;
begin
  Result := p_malloc(Size);
end;

// 0x4AEC38
function my_malloc(Size: SizeUInt): Pointer; cdecl;
var
  Block: PByte;
begin
  Result := nil;

  if Size <> 0 then
  begin
    Size := Size + SizeOf(TMemoryBlockHeader) + SizeOf(TMemoryBlockFooter);
    // Align to SizeOf(Integer) boundary
    Size := Size + (SizeOf(Integer) - Size mod SizeOf(Integer));

    Block := GetMem(Size);
    if Block <> nil then
    begin
      // NOTE: Uninline.
      Result := mem_prep_block(Block, Size);

      Inc(num_blocks);
      if num_blocks > max_blocks then
        max_blocks := num_blocks;

      mem_allocated := mem_allocated + Size;
      if mem_allocated > max_allocated then
        max_allocated := mem_allocated;
    end;
  end;
end;

// 0x4AECB0
function mem_realloc(Ptr: Pointer; Size: SizeUInt): Pointer;
begin
  Result := p_realloc(Ptr, Size);
end;

// 0x4AECB8
function my_realloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl;
var
  Block: PByte;
  Header: PMemoryBlockHeader;
  OldSize: SizeUInt;
  NewBlock: PByte;
begin
  if Ptr <> nil then
  begin
    Block := PByte(Ptr) - SizeOf(TMemoryBlockHeader);

    Header := PMemoryBlockHeader(Block);
    OldSize := Header^.Size;

    mem_allocated := mem_allocated - OldSize;

    mem_check_block(Block);

    if Size <> 0 then
    begin
      Size := Size + SizeOf(TMemoryBlockHeader) + SizeOf(TMemoryBlockFooter);
      // Align to SizeOf(Integer) boundary
      Size := Size + (SizeOf(Integer) - Size mod SizeOf(Integer));
    end;

    NewBlock := ReallocMem(Block, Size);
    if NewBlock <> nil then
    begin
      mem_allocated := mem_allocated + Size;
      if mem_allocated > max_allocated then
        max_allocated := mem_allocated;

      // NOTE: Uninline.
      Result := mem_prep_block(NewBlock, Size);
    end
    else
    begin
      if Size <> 0 then
      begin
        mem_allocated := mem_allocated + OldSize;

        debug_printf('%s,%u: ', ['u_memory.pas', 155]);
        debug_printf('Realloc failure.'#10);
      end
      else
      begin
        Dec(num_blocks);
      end;
      Result := nil;
    end;
  end
  else
  begin
    Result := p_malloc(Size);
  end;
end;

// 0x4AED84
procedure mem_free(Ptr: Pointer);
begin
  p_free(Ptr);
end;

// 0x4AED8C
procedure my_free(Ptr: Pointer); cdecl;
var
  Block: PByte;
  Header: PMemoryBlockHeader;
begin
  if Ptr <> nil then
  begin
    Block := PByte(Ptr) - SizeOf(TMemoryBlockHeader);
    Header := PMemoryBlockHeader(Block);

    mem_check_block(Block);

    mem_allocated := mem_allocated - Header^.Size;
    Dec(num_blocks);

    FreeMem(Block);
  end;
end;

// 0x4AEDBC
procedure mem_check;
begin
  if p_malloc = @my_malloc then
  begin
    debug_printf('Current memory allocated: %6d blocks, %9u bytes total'#10, [num_blocks, mem_allocated]);
    debug_printf('Max memory allocated:     %6d blocks, %9u bytes total'#10, [max_blocks, max_allocated]);
  end;
end;

// 0x4AEE08
procedure mem_register_func(AMallocFunc: TMallocFunc; AReallocFunc: TReallocFunc; AFreeFunc: TFreeFunc);
begin
  if not GNW_win_init_flag then
  begin
    p_malloc := AMallocFunc;
    p_realloc := AReallocFunc;
    p_free := AFreeFunc;
  end;
end;

// 0x4AEE24
function mem_prep_block(Block: Pointer; Size: SizeUInt): Pointer;
var
  Header: PMemoryBlockHeader;
  Footer: PMemoryBlockFooter;
begin
  Header := PMemoryBlockHeader(Block);
  Header^.Guard := MEMORY_BLOCK_HEADER_GUARD;
  Header^.Size := Size;

  Footer := PMemoryBlockFooter(PByte(Block) + Size - SizeOf(TMemoryBlockFooter));
  Footer^.Guard := MEMORY_BLOCK_FOOTER_GUARD;

  Result := PByte(Block) + SizeOf(TMemoryBlockHeader);
end;

// 0x4AEE44
procedure mem_check_block(Block: Pointer);
var
  Header: PMemoryBlockHeader;
  Footer: PMemoryBlockFooter;
begin
  Header := PMemoryBlockHeader(Block);
  if Header^.Guard <> MEMORY_BLOCK_HEADER_GUARD then
    debug_printf('Memory header stomped.'#10);

  Footer := PMemoryBlockFooter(PByte(Block) + Header^.Size - SizeOf(TMemoryBlockFooter));
  if Footer^.Guard <> MEMORY_BLOCK_FOOTER_GUARD then
    debug_printf('Memory footer stomped.'#10);
end;

end.
