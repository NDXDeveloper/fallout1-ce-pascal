{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/heap.h + heap.cc
// Heap memory manager: block-based allocator with compaction.
unit u_heap;

interface

type
  PHeapHandle = ^THeapHandle;
  THeapHandle = record
    state: LongWord;
    data: PByte;
  end;

  PHeap = ^THeap;
  THeap = record
    size: Integer;
    freeBlocks: Integer;
    moveableBlocks: Integer;
    lockedBlocks: Integer;
    systemBlocks: Integer;
    handlesLength: Integer;
    freeSize: Integer;
    moveableSize: Integer;
    lockedSize: Integer;
    systemSize: Integer;
    handles: PHeapHandle;
    data: PByte;
  end;

function heap_init(heap: PHeap; a2: Integer): Boolean;
function heap_exit(heap: PHeap): Boolean;
function heap_allocate(heap: PHeap; handleIndexPtr: PInteger; size: Integer; a4: Integer): Boolean;
function heap_deallocate(heap: PHeap; handleIndexPtr: PInteger): Boolean;
function heap_lock(heap: PHeap; handleIndex: Integer; bufferPtr: PPByte): Boolean;
function heap_unlock(heap: PHeap; handleIndex: Integer): Boolean;
function heap_stats(heap: PHeap; dest: PAnsiChar; size: SizeUInt): Boolean;
function heap_validate(heap: PHeap): Boolean;

implementation

uses
  SysUtils, u_memory, u_debug;

const
  HEAP_BLOCK_HEADER_GUARD = LongInt($DEADC0DE);
  HEAP_BLOCK_FOOTER_GUARD = LongInt($ACDCACDC);

  HEAP_HANDLES_INITIAL_LENGTH = 64;
  HEAP_FREE_BLOCKS_INITIAL_LENGTH = 128;
  HEAP_MOVEABLE_EXTENTS_INITIAL_LENGTH = 64;
  HEAP_MOVEABLE_BLOCKS_INITIAL_LENGTH = 64;
  HEAP_RESERVED_FREE_BLOCK_INDEXES_INITIAL_LENGTH = 64;

  HEAP_HANDLE_STATE_INVALID = LongWord($FFFFFFFF);
  HEAP_BLOCK_STATE_FREE    = $00;
  HEAP_BLOCK_STATE_MOVABLE = $01;
  HEAP_BLOCK_STATE_LOCKED  = $02;
  HEAP_BLOCK_STATE_SYSTEM  = $04;

type
  PHeapBlockHeader = ^THeapBlockHeader;
  THeapBlockHeader = record
    guard: LongInt;
    size: LongInt;
    state: LongWord;
    handle_index: LongInt;
  end;

  PHeapBlockFooter = ^THeapBlockFooter;
  THeapBlockFooter = record
    guard: LongInt;
  end;

  PHeapMoveableExtent = ^THeapMoveableExtent;
  THeapMoveableExtent = record
    data: PByte;
    blocksLength: Integer;
    moveableBlocksLength: Integer;
    size: Integer;
  end;

const
  HEAP_BLOCK_HEADER_SIZE = SizeOf(THeapBlockHeader);
  HEAP_BLOCK_FOOTER_SIZE = SizeOf(THeapBlockFooter);
  HEAP_BLOCK_OVERHEAD_SIZE = HEAP_BLOCK_HEADER_SIZE + HEAP_BLOCK_FOOTER_SIZE;
  HEAP_BLOCK_MIN_SIZE = 128 + HEAP_BLOCK_OVERHEAD_SIZE;

var
  heap_free_list: PPByte = nil;
  heap_moveable_list: PHeapMoveableExtent = nil;
  heap_subblock_list: PPByte = nil;
  heap_fake_move_list: PInteger = nil;
  heap_free_list_size: Integer = 0;
  heap_moveable_list_size: Integer = 0;
  heap_subblock_list_size: Integer = 0;
  heap_fake_move_list_size: SizeUInt = 0;
  heap_count: Integer = 0;

// Forward declarations
function heap_create_lists: Boolean; forward;
procedure heap_destroy_lists; forward;
function heap_init_handles(heap: PHeap): Boolean; forward;
function heap_exit_handles(heap: PHeap): Boolean; forward;
function heap_acquire_handle(heap: PHeap; handleIndexPtr: PInteger): Boolean; forward;
function heap_release_handle(heap: PHeap; handleIndex: Integer): Boolean; forward;
function heap_clear_handles(heap: PHeap; handles: PHeapHandle; count: LongWord): Boolean; forward;
function heap_find_free_block(heap: PHeap; size: Integer; blockPtr: PPointer; a4: Integer): Boolean; forward;
function heap_build_free_list(heap: PHeap): Boolean; forward;
function heap_sort_free_list(heap: PHeap): Boolean; forward;
function heap_build_moveable_list(heap: PHeap; moveableExtentsLengthPtr: PInteger; maxBlocksLengthPtr: PInteger): Boolean; forward;
function heap_sort_moveable_list(heap: PHeap; count: SizeUInt): Boolean; forward;
function heap_build_subblock_list(extentIndex: Integer): Boolean; forward;
function heap_sort_subblock_list(count: SizeUInt): Boolean; forward;
function heap_build_fake_move_list(count: SizeUInt): Boolean; forward;

// ---------------------------------------------------------------------------
// libc qsort import
// ---------------------------------------------------------------------------
type
  TQSortCompareFunc = function(a1, a2: Pointer): Integer; cdecl;

procedure libc_qsort(base: Pointer; num: SizeUInt; size: SizeUInt; compare: TQSortCompareFunc); cdecl; external 'c' name 'qsort';

// ---------------------------------------------------------------------------
// qsort comparators
// ---------------------------------------------------------------------------
function heap_qsort_compare_free(a1, a2: Pointer): Integer; cdecl;
var
  h1, h2: PHeapBlockHeader;
begin
  h1 := PHeapBlockHeader(PPByte(a1)^);
  h2 := PHeapBlockHeader(PPByte(a2)^);
  Result := h1^.size - h2^.size;
end;

function heap_qsort_compare_moveable(a1, a2: Pointer): Integer; cdecl;
var
  v1, v2: PHeapMoveableExtent;
begin
  v1 := PHeapMoveableExtent(a1);
  v2 := PHeapMoveableExtent(a2);
  Result := v1^.size - v2^.size;
end;

function heap_qsort_compare_subblock(a1, a2: Pointer): Integer; cdecl;
var
  h1, h2: PHeapBlockHeader;
begin
  h1 := PHeapBlockHeader(PPByte(a1)^);
  h2 := PHeapBlockHeader(PPByte(a2)^);
  Result := h1^.size - h2^.size;
end;

function heap_qsort_compare_reset_counter(a1, a2: Pointer): Integer; cdecl;
begin
  // Not used in heap, but defined here for completeness
  Result := 0;
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function heap_init(heap: PHeap; a2: Integer): Boolean;
var
  sz: Integer;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
begin
  if heap = nil then
    Exit(False);

  if heap_count = 0 then
  begin
    if not heap_create_lists then
      Exit(False);
  end;

  FillChar(heap^, SizeOf(THeap), 0);

  if heap_init_handles(heap) then
  begin
    sz := (a2 shr 10) + a2;
    heap^.data := PByte(mem_malloc(sz));
    if heap^.data <> nil then
    begin
      heap^.size := sz;
      heap^.freeBlocks := 1;
      heap^.freeSize := heap^.size - Integer(HEAP_BLOCK_OVERHEAD_SIZE);

      blockHeader := PHeapBlockHeader(heap^.data);
      blockHeader^.guard := HEAP_BLOCK_HEADER_GUARD;
      blockHeader^.size := heap^.freeSize;
      blockHeader^.state := 0;
      blockHeader^.handle_index := -1;

      blockFooter := PHeapBlockFooter(heap^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
      blockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;

      Inc(heap_count);
      Exit(True);
    end;
  end;

  if heap_count = 0 then
    heap_destroy_lists;

  Result := False;
end;

function heap_exit(heap: PHeap): Boolean;
var
  index: Integer;
  handle: PHeapHandle;
begin
  if heap = nil then
    Exit(False);

  for index := 0 to heap^.handlesLength - 1 do
  begin
    handle := @heap^.handles[index];
    if (handle^.state = HEAP_BLOCK_STATE_SYSTEM) and (handle^.data <> nil) then
      mem_free(handle^.data);
  end;

  heap_exit_handles(heap);

  if heap^.data <> nil then
    mem_free(heap^.data);

  FillChar(heap^, SizeOf(THeap), 0);

  Dec(heap_count);
  if heap_count = 0 then
    heap_destroy_lists;

  Result := True;
end;

function heap_allocate(heap: PHeap; handleIndexPtr: PInteger; size: Integer; a4: Integer): Boolean;
var
  block: Pointer;
  blockHeader: PHeapBlockHeader;
  state: Integer;
  handleIndex: Integer;
  blockSize: Integer;
  handle: PHeapHandle;
  remainingSize: Integer;
  blockFooter: PHeapBlockFooter;
  nextBlock: PByte;
  nextBlockHeader: PHeapBlockHeader;
  nextBlockFooter: PHeapBlockFooter;
begin
  // Align size to sizeof(int) boundary
  size := size + (SizeOf(Integer) - size mod SizeOf(Integer));

  if (heap = nil) or (handleIndexPtr = nil) or (size = 0) then
  begin
    debug_printf('Heap Warning: Could not allocate block of %d bytes.'#10, [size]);
    Exit(False);
  end;

  if (a4 <> 0) and (a4 <> 1) then
    a4 := 0;

  if not heap_find_free_block(heap, size, @block, a4) then
  begin
    debug_printf('Heap Warning: Could not allocate block of %d bytes.'#10, [size]);
    Exit(False);
  end;

  blockHeader := PHeapBlockHeader(block);
  state := blockHeader^.state;

  if not heap_acquire_handle(heap, @handleIndex) then
  begin
    debug_printf('Heap Error: Could not acquire handle for new block.'#10, []);
    if state = HEAP_BLOCK_STATE_SYSTEM then
      mem_free(block);
    debug_printf('Heap Warning: Could not allocate block of %d bytes.'#10, [size]);
    Exit(False);
  end;

  blockSize := blockHeader^.size;
  handle := @heap^.handles[handleIndex];

  if state = HEAP_BLOCK_STATE_SYSTEM then
  begin
    blockHeader^.handle_index := handleIndex;
    handle^.state := HEAP_BLOCK_STATE_SYSTEM;
    handle^.data := PByte(block);
    Inc(heap^.systemBlocks);
    Inc(heap^.systemSize, size);
    handleIndexPtr^ := handleIndex;
    Exit(True);
  end;

  if state = HEAP_BLOCK_STATE_FREE then
  begin
    remainingSize := blockSize - size;
    if remainingSize > Integer(HEAP_BLOCK_MIN_SIZE) then
    begin
      blockHeader^.size := size;
      blockSize := size;

      blockFooter := PHeapBlockFooter(PByte(block) + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
      blockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;

      nextBlock := PByte(block) + blockHeader^.size + HEAP_BLOCK_OVERHEAD_SIZE;
      nextBlockHeader := PHeapBlockHeader(nextBlock);
      nextBlockHeader^.guard := HEAP_BLOCK_HEADER_GUARD;
      nextBlockHeader^.size := remainingSize - Integer(HEAP_BLOCK_OVERHEAD_SIZE);
      nextBlockHeader^.state := HEAP_BLOCK_STATE_FREE;
      nextBlockHeader^.handle_index := -1;

      nextBlockFooter := PHeapBlockFooter(nextBlock + nextBlockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
      nextBlockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;

      Inc(heap^.freeBlocks);
      Dec(heap^.freeSize, Integer(HEAP_BLOCK_OVERHEAD_SIZE));
    end;

    blockHeader^.state := HEAP_BLOCK_STATE_MOVABLE;
    blockHeader^.handle_index := handleIndex;

    handle^.state := HEAP_BLOCK_STATE_MOVABLE;
    handle^.data := PByte(block);

    Dec(heap^.freeBlocks);
    Inc(heap^.moveableBlocks);
    Dec(heap^.freeSize, blockSize);
    Inc(heap^.moveableSize, blockSize);

    handleIndexPtr^ := handleIndex;
    Exit(True);
  end;

  heap_release_handle(heap, handleIndex);
  debug_printf('Heap Error: Unknown block state during allocation.'#10, []);
  debug_printf('Heap Warning: Could not allocate block of %d bytes.'#10, [size]);
  Result := False;
end;

function heap_deallocate(heap: PHeap; handleIndexPtr: PInteger): Boolean;
var
  handleIndex: Integer;
  handle: PHeapHandle;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
  sz: Integer;
begin
  if (heap = nil) or (handleIndexPtr = nil) then
  begin
    debug_printf('Heap Error: Could not deallocate block.'#10, []);
    Exit(False);
  end;

  handleIndex := handleIndexPtr^;
  handle := @heap^.handles[handleIndex];

  blockHeader := PHeapBlockHeader(handle^.data);
  if blockHeader^.guard <> HEAP_BLOCK_HEADER_GUARD then
    debug_printf('Heap Error: Bad guard begin detected during deallocate.'#10, []);

  blockFooter := PHeapBlockFooter(handle^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
  if blockFooter^.guard <> HEAP_BLOCK_FOOTER_GUARD then
    debug_printf('Heap Error: Bad guard end detected during deallocate.'#10, []);

  if handle^.state <> blockHeader^.state then
    debug_printf('Heap Error: Mismatched block states detected during deallocate.'#10, []);

  if (handle^.state and HEAP_BLOCK_STATE_LOCKED) <> 0 then
  begin
    debug_printf('Heap Error: Attempt to deallocate locked block.'#10, []);
    Exit(False);
  end;

  sz := blockHeader^.size;

  if handle^.state = HEAP_BLOCK_STATE_MOVABLE then
  begin
    blockHeader^.handle_index := -1;
    blockHeader^.state := HEAP_BLOCK_STATE_FREE;
    Inc(heap^.freeBlocks);
    Dec(heap^.moveableBlocks);
    Inc(heap^.freeSize, sz);
    Dec(heap^.moveableSize, sz);
    heap_release_handle(heap, handleIndex);
    Exit(True);
  end;

  if handle^.state = HEAP_BLOCK_STATE_SYSTEM then
  begin
    mem_free(handle^.data);
    Dec(heap^.systemBlocks);
    Dec(heap^.systemSize, sz);
    heap_release_handle(heap, handleIndex);
    Exit(True);
  end;

  debug_printf('Heap Error: Unknown block state during deallocation.'#10, []);
  Result := False;
end;

function heap_lock(heap: PHeap; handleIndex: Integer; bufferPtr: PPByte): Boolean;
var
  handle: PHeapHandle;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
  sz: Integer;
begin
  if heap = nil then
  begin
    debug_printf('Heap Error: Could not lock block'#10, []);
    Exit(False);
  end;

  handle := @heap^.handles[handleIndex];

  blockHeader := PHeapBlockHeader(handle^.data);
  if blockHeader^.guard <> HEAP_BLOCK_HEADER_GUARD then
  begin
    debug_printf('Heap Error: Bad guard begin detected during lock.'#10, []);
    Exit(False);
  end;

  blockFooter := PHeapBlockFooter(handle^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
  if blockFooter^.guard <> HEAP_BLOCK_FOOTER_GUARD then
  begin
    debug_printf('Heap Error: Bad guard end detected during lock.'#10, []);
    Exit(False);
  end;

  if handle^.state <> blockHeader^.state then
  begin
    debug_printf('Heap Error: Mismatched block states detected during lock.'#10, []);
    Exit(False);
  end;

  if (handle^.state and HEAP_BLOCK_STATE_LOCKED) <> 0 then
  begin
    debug_printf('Heap Error: Attempt to lock a previously locked block.'#10, []);
    Exit(False);
  end;

  if handle^.state = HEAP_BLOCK_STATE_MOVABLE then
  begin
    blockHeader^.state := HEAP_BLOCK_STATE_LOCKED;
    handle^.state := HEAP_BLOCK_STATE_LOCKED;
    Dec(heap^.moveableBlocks);
    Inc(heap^.lockedBlocks);
    sz := blockHeader^.size;
    Dec(heap^.moveableSize, sz);
    Inc(heap^.lockedSize, sz);
    bufferPtr^ := handle^.data + HEAP_BLOCK_HEADER_SIZE;
    Exit(True);
  end;

  if handle^.state = HEAP_BLOCK_STATE_SYSTEM then
  begin
    blockHeader^.state := blockHeader^.state or HEAP_BLOCK_STATE_LOCKED;
    handle^.state := handle^.state or HEAP_BLOCK_STATE_LOCKED;
    bufferPtr^ := handle^.data + HEAP_BLOCK_HEADER_SIZE;
    Exit(True);
  end;

  debug_printf('Heap Error: Unknown block state during lock.'#10, []);
  Result := False;
end;

function heap_unlock(heap: PHeap; handleIndex: Integer): Boolean;
var
  handle: PHeapHandle;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
  sz: Integer;
begin
  if heap = nil then
  begin
    debug_printf('Heap Error: Could not unlock block.'#10, []);
    Exit(False);
  end;

  handle := @heap^.handles[handleIndex];

  blockHeader := PHeapBlockHeader(handle^.data);
  if blockHeader^.guard <> HEAP_BLOCK_HEADER_GUARD then
    debug_printf('Heap Error: Bad guard begin detected during unlock.'#10, []);

  blockFooter := PHeapBlockFooter(handle^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
  if blockFooter^.guard <> HEAP_BLOCK_FOOTER_GUARD then
    debug_printf('Heap Error: Bad guard end detected during unlock.'#10, []);

  if handle^.state <> blockHeader^.state then
    debug_printf('Heap Error: Mismatched block states detected during unlock.'#10, []);

  if (handle^.state and HEAP_BLOCK_STATE_LOCKED) = 0 then
  begin
    debug_printf('Heap Error: Attempt to unlock a previously unlocked block.'#10, []);
    debug_printf('Heap Error: Could not unlock block.'#10, []);
    Exit(False);
  end;

  if (handle^.state and HEAP_BLOCK_STATE_SYSTEM) <> 0 then
  begin
    blockHeader^.state := HEAP_BLOCK_STATE_SYSTEM;
    handle^.state := HEAP_BLOCK_STATE_SYSTEM;
    Exit(True);
  end;

  blockHeader^.state := HEAP_BLOCK_STATE_MOVABLE;
  handle^.state := HEAP_BLOCK_STATE_MOVABLE;

  Inc(heap^.moveableBlocks);
  Dec(heap^.lockedBlocks);

  sz := blockHeader^.size;
  Inc(heap^.moveableSize, sz);
  Dec(heap^.lockedSize, sz);

  Result := True;
end;

function heap_validate(heap: PHeap): Boolean;
var
  blocksCount: Integer;
  ptr: PByte;
  freeBlk, freeSz, moveBlk, moveSz, lockBlk, lockSz: Integer;
  index: Integer;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
  sysBlk, sysSz: Integer;
  handle: PHeapHandle;
begin
  debug_printf('Validating heap...'#10, []);

  blocksCount := heap^.freeBlocks + heap^.moveableBlocks + heap^.lockedBlocks;
  ptr := heap^.data;

  freeBlk := 0; freeSz := 0;
  moveBlk := 0; moveSz := 0;
  lockBlk := 0; lockSz := 0;

  for index := 0 to blocksCount - 1 do
  begin
    blockHeader := PHeapBlockHeader(ptr);
    if blockHeader^.guard <> HEAP_BLOCK_HEADER_GUARD then
    begin
      debug_printf('Bad guard begin detected during validate.'#10, []);
      Exit(False);
    end;

    blockFooter := PHeapBlockFooter(ptr + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
    if blockFooter^.guard <> HEAP_BLOCK_FOOTER_GUARD then
    begin
      debug_printf('Bad guard end detected during validate.'#10, []);
      Exit(False);
    end;

    if blockHeader^.state = HEAP_BLOCK_STATE_FREE then
    begin
      Inc(freeBlk);
      Inc(freeSz, blockHeader^.size);
    end
    else if blockHeader^.state = HEAP_BLOCK_STATE_MOVABLE then
    begin
      Inc(moveBlk);
      Inc(moveSz, blockHeader^.size);
    end
    else if blockHeader^.state = HEAP_BLOCK_STATE_LOCKED then
    begin
      Inc(lockBlk);
      Inc(lockSz, blockHeader^.size);
    end;

    if index <> blocksCount - 1 then
    begin
      ptr := ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE;
      if ptr > (heap^.data + LongWord(heap^.size)) then
      begin
        debug_printf('Ran off end of heap during validate!'#10, []);
        Exit(False);
      end;
    end;
  end;

  if freeBlk <> heap^.freeBlocks then begin debug_printf('Invalid number of free blocks.'#10, []); Exit(False); end;
  if freeSz <> heap^.freeSize then begin debug_printf('Invalid size of free blocks.'#10, []); Exit(False); end;
  if moveBlk <> heap^.moveableBlocks then begin debug_printf('Invalid number of moveable blocks.'#10, []); Exit(False); end;
  if moveSz <> heap^.moveableSize then begin debug_printf('Invalid size of moveable blocks.'#10, []); Exit(False); end;
  if lockBlk <> heap^.lockedBlocks then begin debug_printf('Invalid number of locked blocks.'#10, []); Exit(False); end;
  if lockSz <> heap^.lockedSize then begin debug_printf('Invalid size of locked blocks.'#10, []); Exit(False); end;

  debug_printf('Heap is O.K.'#10, []);

  sysBlk := 0;
  sysSz := 0;
  for index := 0 to heap^.handlesLength - 1 do
  begin
    handle := @heap^.handles[index];
    if (handle^.state <> HEAP_HANDLE_STATE_INVALID) and ((handle^.state and HEAP_BLOCK_STATE_SYSTEM) <> 0) then
    begin
      blockHeader := PHeapBlockHeader(handle^.data);
      if blockHeader^.guard <> HEAP_BLOCK_HEADER_GUARD then
      begin
        debug_printf('Bad guard begin detected in system block during validate.'#10, []);
        Exit(False);
      end;
      blockFooter := PHeapBlockFooter(handle^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
      if blockFooter^.guard <> HEAP_BLOCK_FOOTER_GUARD then
      begin
        debug_printf('Bad guard end detected in system block during validate.'#10, []);
        Exit(False);
      end;
      Inc(sysBlk);
      Inc(sysSz, blockHeader^.size);
    end;
  end;

  if sysBlk <> heap^.systemBlocks then begin debug_printf('Invalid number of system blocks.'#10, []); Exit(False); end;
  if sysSz <> heap^.systemSize then begin debug_printf('Invalid size of system blocks.'#10, []); Exit(False); end;

  Result := True;
end;

function heap_stats(heap: PHeap; dest: PAnsiChar; size: SizeUInt): Boolean;
var
  buf: AnsiString;
begin
  if (heap = nil) or (dest = nil) then
    Exit(False);

  buf := Format(
    '[Heap]'#10 +
    'Total free blocks: %d'#10 +
    'Total free size: %d'#10 +
    'Total moveable blocks: %d'#10 +
    'Total moveable size: %d'#10 +
    'Total locked blocks: %d'#10 +
    'Total locked size: %d'#10 +
    'Total system blocks: %d'#10 +
    'Total system size: %d'#10 +
    'Total handles: %d'#10 +
    'Total heaps: %d',
    [heap^.freeBlocks, heap^.freeSize,
     heap^.moveableBlocks, heap^.moveableSize,
     heap^.lockedBlocks, heap^.lockedSize,
     heap^.systemBlocks, heap^.systemSize,
     heap^.handlesLength, heap_count]);

  if SizeUInt(Length(buf)) >= size then
    SetLength(buf, size - 1);

  Move(buf[1], dest^, Length(buf));
  dest[Length(buf)] := #0;

  Result := True;
end;

// ---------------------------------------------------------------------------
// Internal: list management
// ---------------------------------------------------------------------------

function heap_create_lists: Boolean;
begin
  repeat
    heap_free_list := PPByte(mem_malloc(SizeOf(PByte) * HEAP_FREE_BLOCKS_INITIAL_LENGTH));
    if heap_free_list = nil then Break;
    heap_free_list_size := HEAP_FREE_BLOCKS_INITIAL_LENGTH;

    heap_moveable_list := PHeapMoveableExtent(mem_malloc(SizeOf(THeapMoveableExtent) * HEAP_MOVEABLE_EXTENTS_INITIAL_LENGTH));
    if heap_moveable_list = nil then Break;
    heap_moveable_list_size := HEAP_MOVEABLE_EXTENTS_INITIAL_LENGTH;

    heap_subblock_list := PPByte(mem_malloc(SizeOf(PByte) * HEAP_MOVEABLE_BLOCKS_INITIAL_LENGTH));
    if heap_subblock_list = nil then Break;
    heap_subblock_list_size := HEAP_MOVEABLE_BLOCKS_INITIAL_LENGTH;

    heap_fake_move_list := PInteger(mem_malloc(SizeOf(Integer) * HEAP_RESERVED_FREE_BLOCK_INDEXES_INITIAL_LENGTH));
    if heap_fake_move_list = nil then Break;
    heap_fake_move_list_size := HEAP_RESERVED_FREE_BLOCK_INDEXES_INITIAL_LENGTH;

    Exit(True);
  until True;

  heap_destroy_lists;
  Result := False;
end;

procedure heap_destroy_lists;
begin
  if heap_fake_move_list <> nil then begin mem_free(heap_fake_move_list); heap_fake_move_list := nil; end;
  heap_fake_move_list_size := 0;

  if heap_subblock_list <> nil then begin mem_free(heap_subblock_list); heap_subblock_list := nil; end;
  heap_subblock_list_size := 0;

  if heap_moveable_list <> nil then begin mem_free(heap_moveable_list); heap_moveable_list := nil; end;
  heap_moveable_list_size := 0;

  if heap_free_list <> nil then begin mem_free(heap_free_list); heap_free_list := nil; end;
  heap_free_list_size := 0;
end;

// ---------------------------------------------------------------------------
// Internal: handle management
// ---------------------------------------------------------------------------

function heap_init_handles(heap: PHeap): Boolean;
begin
  heap^.handles := PHeapHandle(mem_malloc(SizeOf(THeapHandle) * HEAP_HANDLES_INITIAL_LENGTH));
  if heap^.handles <> nil then
  begin
    if heap_clear_handles(heap, heap^.handles, HEAP_HANDLES_INITIAL_LENGTH) then
    begin
      heap^.handlesLength := HEAP_HANDLES_INITIAL_LENGTH;
      Exit(True);
    end;
    debug_printf('Heap Error: Could not allocate handles.'#10, []);
    Exit(False);
  end;
  debug_printf('Heap Error : Could not initialize handles.'#10, []);
  Result := False;
end;

function heap_exit_handles(heap: PHeap): Boolean;
begin
  if heap^.handles = nil then
    Exit(False);
  mem_free(heap^.handles);
  heap^.handles := nil;
  heap^.handlesLength := 0;
  Result := True;
end;

function heap_acquire_handle(heap: PHeap; handleIndexPtr: PInteger): Boolean;
var
  index: Integer;
  handles: PHeapHandle;
begin
  for index := 0 to heap^.handlesLength - 1 do
  begin
    if heap^.handles[index].state = HEAP_HANDLE_STATE_INVALID then
    begin
      handleIndexPtr^ := index;
      Exit(True);
    end;
  end;

  handles := PHeapHandle(mem_realloc(heap^.handles, SizeOf(THeapHandle) * (heap^.handlesLength + HEAP_HANDLES_INITIAL_LENGTH)));
  if handles = nil then
    Exit(False);

  heap^.handles := handles;
  heap_clear_handles(heap, @heap^.handles[heap^.handlesLength], HEAP_HANDLES_INITIAL_LENGTH);
  handleIndexPtr^ := heap^.handlesLength;
  Inc(heap^.handlesLength, HEAP_HANDLES_INITIAL_LENGTH);

  Result := True;
end;

function heap_release_handle(heap: PHeap; handleIndex: Integer): Boolean;
begin
  heap^.handles[handleIndex].state := HEAP_HANDLE_STATE_INVALID;
  heap^.handles[handleIndex].data := nil;
  Result := True;
end;

function heap_clear_handles(heap: PHeap; handles: PHeapHandle; count: LongWord): Boolean;
var
  index: LongWord;
begin
  for index := 0 to count - 1 do
  begin
    handles[index].state := HEAP_HANDLE_STATE_INVALID;
    handles[index].data := nil;
  end;
  Result := True;
end;

// ---------------------------------------------------------------------------
// Internal: free block search with compaction
// ---------------------------------------------------------------------------

function heap_find_free_block(heap: PHeap; size: Integer; blockPtr: PPointer; a4: Integer): Boolean;
label
  _system;
var
  biggestFreeBlock: PByte;
  biggestFreeBlockHeader: PHeapBlockHeader;
  biggestFreeBlockSize: Integer;
  index: Integer;
  moveableExtentsCount, maxBlocksCount: Integer;
  extentIndex: Integer;
  extent: PHeapMoveableExtent;
  extentSize: Integer;
  reservedBlocksLength: Integer;
  moveableBlockIndex, freeBlockIndex: Integer;
  moveableBlock, freeBlock: PByte;
  moveableBlockHeader, freeBlockHeader: PHeapBlockHeader;
  moveableBlockSize, freeBlockSize: Integer;
  freeBlocksIndexesIndex: Integer;
  reservedFreeBlockIndex: Integer;
  remainingSize: Integer;
  freeBlockFooter: PHeapBlockFooter;
  nextFreeBlock: PByte;
  nextFreeBlockHeader: PHeapBlockHeader;
  blockHeader: PHeapBlockHeader;
  blockFooter: PHeapBlockFooter;
  block: PByte;
  stats: array[0..511] of AnsiChar;
begin
  if not heap_build_free_list(heap) then
    goto _system;

  if size > heap^.freeSize then
    goto _system;

  heap_sort_free_list(heap);

  biggestFreeBlock := PPByte(PByte(heap_free_list) + SizeUInt(heap^.freeBlocks - 1) * SizeOf(PByte))^;
  biggestFreeBlockHeader := PHeapBlockHeader(biggestFreeBlock);
  biggestFreeBlockSize := biggestFreeBlockHeader^.size;

  if biggestFreeBlockSize >= size then
  begin
    for index := 0 to heap^.freeBlocks - 1 do
    begin
      block := PPByte(PByte(heap_free_list) + SizeUInt(index) * SizeOf(PByte))^;
      blockHeader := PHeapBlockHeader(block);
      if blockHeader^.size >= size then
        Break;
    end;
    blockPtr^ := PPByte(PByte(heap_free_list) + SizeUInt(index) * SizeOf(PByte))^;
    Exit(True);
  end;

  if not heap_build_moveable_list(heap, @moveableExtentsCount, @maxBlocksCount) then
    goto _system;

  if not heap_build_fake_move_list(maxBlocksCount) then
    goto _system;

  heap_sort_moveable_list(heap, moveableExtentsCount);

  if moveableExtentsCount = 0 then
    goto _system;

  extentIndex := 0;
  while extentIndex < moveableExtentsCount do
  begin
    extent := PHeapMoveableExtent(PByte(heap_moveable_list) + SizeUInt(extentIndex) * SizeOf(THeapMoveableExtent));
    extentSize := extent^.size + Integer(HEAP_BLOCK_OVERHEAD_SIZE) * extent^.blocksLength - Integer(HEAP_BLOCK_OVERHEAD_SIZE);

    if extentSize < size then
    begin
      Inc(extentIndex);
      Continue;
    end;

    if not heap_build_subblock_list(extentIndex) then
    begin
      Inc(extentIndex);
      Continue;
    end;

    heap_sort_subblock_list(extent^.moveableBlocksLength);

    reservedBlocksLength := 0;

    for moveableBlockIndex := 0 to extent^.moveableBlocksLength - 1 do
    begin
      moveableBlock := PPByte(PByte(heap_subblock_list) + SizeUInt(moveableBlockIndex) * SizeOf(PByte))^;
      moveableBlockHeader := PHeapBlockHeader(moveableBlock);

      if biggestFreeBlockSize < moveableBlockHeader^.size then
        Continue;

      freeBlockIndex := 0;
      while freeBlockIndex < heap^.freeBlocks do
      begin
        freeBlock := PPByte(PByte(heap_free_list) + SizeUInt(freeBlockIndex) * SizeOf(PByte))^;
        freeBlockHeader := PHeapBlockHeader(freeBlock);

        if freeBlockHeader^.size < moveableBlockHeader^.size then
        begin
          Inc(freeBlockIndex);
          Continue;
        end;

        if (PtrUInt(freeBlock) >= PtrUInt(extent^.data)) and
           (PtrUInt(freeBlock) < PtrUInt(extent^.data) + PtrUInt(extentSize) + HEAP_BLOCK_OVERHEAD_SIZE) then
        begin
          Inc(freeBlockIndex);
          Continue;
        end;

        freeBlocksIndexesIndex := 0;
        while freeBlocksIndexesIndex < reservedBlocksLength do
        begin
          if freeBlockIndex = PInteger(PByte(heap_fake_move_list) + SizeUInt(freeBlocksIndexesIndex) * SizeOf(Integer))^ then
            Break;
          Inc(freeBlocksIndexesIndex);
        end;

        if freeBlocksIndexesIndex = reservedBlocksLength then
          Break;

        Inc(freeBlockIndex);
      end;

      if freeBlockIndex = heap^.freeBlocks then
        Break;

      PInteger(PByte(heap_fake_move_list) + SizeUInt(reservedBlocksLength) * SizeOf(Integer))^ := freeBlockIndex;
      Inc(reservedBlocksLength);
    end;

    if reservedBlocksLength = extent^.moveableBlocksLength then
      Break;

    Inc(extentIndex);
  end;

  if extentIndex = moveableExtentsCount then
    goto _system;

  extent := PHeapMoveableExtent(PByte(heap_moveable_list) + SizeUInt(extentIndex) * SizeOf(THeapMoveableExtent));
  reservedFreeBlockIndex := 0;

  for moveableBlockIndex := 0 to extent^.moveableBlocksLength - 1 do
  begin
    moveableBlock := PPByte(PByte(heap_subblock_list) + SizeUInt(moveableBlockIndex) * SizeOf(PByte))^;
    moveableBlockHeader := PHeapBlockHeader(moveableBlock);
    moveableBlockSize := moveableBlockHeader^.size;

    if biggestFreeBlockSize < moveableBlockSize then
      Continue;

    freeBlock := PPByte(PByte(heap_free_list) +
      SizeUInt(PInteger(PByte(heap_fake_move_list) + SizeUInt(reservedFreeBlockIndex) * SizeOf(Integer))^) * SizeOf(PByte))^;
    Inc(reservedFreeBlockIndex);
    freeBlockHeader := PHeapBlockHeader(freeBlock);
    freeBlockSize := freeBlockHeader^.size;

    Move(moveableBlock^, freeBlock^, moveableBlockSize + Integer(HEAP_BLOCK_OVERHEAD_SIZE));
    heap^.handles[freeBlockHeader^.handle_index].data := freeBlock;

    remainingSize := freeBlockSize - moveableBlockSize;
    if remainingSize <> 0 then
    begin
      if remainingSize < Integer(HEAP_BLOCK_MIN_SIZE) then
      begin
        Inc(freeBlockHeader^.size, remainingSize);
        freeBlockFooter := PHeapBlockFooter(freeBlock + freeBlockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
        freeBlockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;
        Dec(heap^.freeSize, remainingSize);
        Inc(heap^.moveableSize, remainingSize);
      end
      else
      begin
        nextFreeBlock := freeBlock + freeBlockHeader^.size + HEAP_BLOCK_OVERHEAD_SIZE;
        nextFreeBlockHeader := PHeapBlockHeader(nextFreeBlock);
        nextFreeBlockHeader^.state := HEAP_BLOCK_STATE_FREE;
        nextFreeBlockHeader^.handle_index := -1;
        nextFreeBlockHeader^.size := remainingSize - Integer(HEAP_BLOCK_OVERHEAD_SIZE);
        nextFreeBlockHeader^.guard := HEAP_BLOCK_HEADER_GUARD;
        Inc(heap^.freeBlocks);
        Dec(heap^.freeSize, Integer(HEAP_BLOCK_OVERHEAD_SIZE));
      end;
    end;
  end;

  Dec(heap^.freeBlocks, extent^.blocksLength - 1);
  Inc(heap^.freeSize, (extent^.blocksLength - 1) * Integer(HEAP_BLOCK_OVERHEAD_SIZE));

  blockHeader := PHeapBlockHeader(extent^.data);
  blockHeader^.guard := HEAP_BLOCK_HEADER_GUARD;
  blockHeader^.size := extent^.size + (extent^.blocksLength - 1) * Integer(HEAP_BLOCK_OVERHEAD_SIZE);
  blockHeader^.state := HEAP_BLOCK_STATE_FREE;
  blockHeader^.handle_index := -1;

  blockFooter := PHeapBlockFooter(extent^.data + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
  blockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;

  blockPtr^ := extent^.data;
  Exit(True);

_system:
  if heap_stats(heap, @stats[0], SizeOf(stats)) then
    debug_printf(#10'%s'#10, [PAnsiChar(@stats[0])]);

  if a4 = 0 then
  begin
    debug_printf('Allocating block from system memory...'#10, []);
    block := PByte(mem_malloc(size + Integer(HEAP_BLOCK_OVERHEAD_SIZE)));
    if block = nil then
    begin
      debug_printf('fatal error: internal_malloc() failed in heap_find_free_block()!'#10, []);
      Exit(False);
    end;

    blockHeader := PHeapBlockHeader(block);
    blockHeader^.guard := HEAP_BLOCK_HEADER_GUARD;
    blockHeader^.size := size;
    blockHeader^.state := HEAP_BLOCK_STATE_SYSTEM;
    blockHeader^.handle_index := -1;

    blockFooter := PHeapBlockFooter(block + blockHeader^.size + HEAP_BLOCK_HEADER_SIZE);
    blockFooter^.guard := HEAP_BLOCK_FOOTER_GUARD;

    blockPtr^ := block;
    Exit(True);
  end;

  Result := False;
end;

function heap_build_free_list(heap: PHeap): Boolean;
var
  freeBlocks: PPByte;
  blocksLength: Integer;
  ptr: PByte;
  freeBlockIndex: Integer;
  blockHeader, nextBlockHeader: PHeapBlockHeader;
begin
  if heap^.freeBlocks = 0 then
    Exit(False);

  if heap^.freeBlocks > heap_free_list_size then
  begin
    freeBlocks := PPByte(mem_realloc(heap_free_list, SizeOf(PByte) * heap^.freeBlocks));
    if freeBlocks = nil then
      Exit(False);
    heap_free_list := freeBlocks;
    heap_free_list_size := heap^.freeBlocks;
  end;

  blocksLength := heap^.moveableBlocks + heap^.freeBlocks + heap^.lockedBlocks;
  ptr := heap^.data;
  freeBlockIndex := 0;

  while blocksLength <> 0 do
  begin
    if freeBlockIndex >= heap^.freeBlocks then
      Break;

    blockHeader := PHeapBlockHeader(ptr);
    if blockHeader^.state = HEAP_BLOCK_STATE_FREE then
    begin
      while blocksLength > 1 do
      begin
        nextBlockHeader := PHeapBlockHeader(ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE);
        if nextBlockHeader^.state <> HEAP_BLOCK_STATE_FREE then
          Break;
        Inc(blockHeader^.size, nextBlockHeader^.size + Integer(HEAP_BLOCK_OVERHEAD_SIZE));
        Dec(heap^.freeBlocks);
        Inc(heap^.freeSize, Integer(HEAP_BLOCK_OVERHEAD_SIZE));
        Dec(blocksLength);
      end;
      PPByte(PByte(heap_free_list) + SizeUInt(freeBlockIndex) * SizeOf(PByte))^ := ptr;
      Inc(freeBlockIndex);
    end;

    ptr := ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE;
    Dec(blocksLength);
  end;

  Result := True;
end;

function heap_sort_free_list(heap: PHeap): Boolean;
begin
  if heap^.freeBlocks > 1 then
    libc_qsort(heap_free_list, heap^.freeBlocks, SizeOf(PByte), @heap_qsort_compare_free);
  Result := True;
end;

function heap_build_moveable_list(heap: PHeap; moveableExtentsLengthPtr: PInteger; maxBlocksLengthPtr: PInteger): Boolean;
var
  maxExtentsCount: Integer;
  moveableExtents: PHeapMoveableExtent;
  ptr: PByte;
  blocksLength, maxBlocksLength, extentIndex: Integer;
  blockHeader, nextBlockHeader: PHeapBlockHeader;
  extent: PHeapMoveableExtent;
begin
  maxExtentsCount := heap^.moveableBlocks + heap^.freeBlocks;
  if maxExtentsCount <= 2 then
  begin
    debug_printf('<[couldn''t build moveable list]>'#10, []);
    Exit(False);
  end;

  if maxExtentsCount > heap_moveable_list_size then
  begin
    moveableExtents := PHeapMoveableExtent(mem_realloc(heap_moveable_list, SizeOf(THeapMoveableExtent) * maxExtentsCount));
    if moveableExtents = nil then
      Exit(False);
    heap_moveable_list := moveableExtents;
    heap_moveable_list_size := maxExtentsCount;
  end;

  ptr := heap^.data;
  blocksLength := heap^.moveableBlocks + heap^.freeBlocks + heap^.lockedBlocks;
  maxBlocksLength := 0;
  extentIndex := 0;

  while blocksLength <> 0 do
  begin
    if extentIndex >= maxExtentsCount then
      Break;

    blockHeader := PHeapBlockHeader(ptr);
    if (blockHeader^.state = HEAP_BLOCK_STATE_FREE) or (blockHeader^.state = HEAP_BLOCK_STATE_MOVABLE) then
    begin
      extent := PHeapMoveableExtent(PByte(heap_moveable_list) + SizeUInt(extentIndex) * SizeOf(THeapMoveableExtent));
      Inc(extentIndex);
      extent^.data := ptr;
      extent^.blocksLength := 1;
      extent^.moveableBlocksLength := 0;
      extent^.size := blockHeader^.size;

      if blockHeader^.state = HEAP_BLOCK_STATE_MOVABLE then
        extent^.moveableBlocksLength := 1;

      while blocksLength > 1 do
      begin
        blockHeader := PHeapBlockHeader(ptr);
        nextBlockHeader := PHeapBlockHeader(ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE);
        if (nextBlockHeader^.state <> HEAP_BLOCK_STATE_FREE) and (nextBlockHeader^.state <> HEAP_BLOCK_STATE_MOVABLE) then
          Break;

        Inc(extent^.blocksLength);
        Inc(extent^.size, nextBlockHeader^.size);

        if nextBlockHeader^.state = HEAP_BLOCK_STATE_MOVABLE then
          Inc(extent^.moveableBlocksLength);

        ptr := ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE;
        Dec(blocksLength);
      end;

      if extent^.blocksLength > maxBlocksLength then
        maxBlocksLength := extent^.blocksLength;
    end;

    blockHeader := PHeapBlockHeader(ptr);
    ptr := ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE;
    Dec(blocksLength);
  end;

  moveableExtentsLengthPtr^ := extentIndex;
  maxBlocksLengthPtr^ := maxBlocksLength;
  Result := True;
end;

function heap_sort_moveable_list(heap: PHeap; count: SizeUInt): Boolean;
begin
  libc_qsort(heap_moveable_list, count, SizeOf(THeapMoveableExtent), @heap_qsort_compare_moveable);
  Result := True;
end;

function heap_build_subblock_list(extentIndex: Integer): Boolean;
var
  extent: PHeapMoveableExtent;
  moveableBlocks: PPByte;
  ptr: PByte;
  moveableBlockIndex, index: Integer;
  blockHeader: PHeapBlockHeader;
begin
  extent := PHeapMoveableExtent(PByte(heap_moveable_list) + SizeUInt(extentIndex) * SizeOf(THeapMoveableExtent));
  if extent^.moveableBlocksLength > heap_subblock_list_size then
  begin
    moveableBlocks := PPByte(mem_realloc(heap_subblock_list, SizeOf(PByte) * extent^.moveableBlocksLength));
    if moveableBlocks = nil then
      Exit(False);
    heap_subblock_list := moveableBlocks;
    heap_subblock_list_size := extent^.moveableBlocksLength;
  end;

  ptr := extent^.data;
  moveableBlockIndex := 0;
  for index := 0 to extent^.blocksLength - 1 do
  begin
    blockHeader := PHeapBlockHeader(ptr);
    if blockHeader^.state = HEAP_BLOCK_STATE_MOVABLE then
    begin
      PPByte(PByte(heap_subblock_list) + SizeUInt(moveableBlockIndex) * SizeOf(PByte))^ := ptr;
      Inc(moveableBlockIndex);
    end;
    ptr := ptr + LongWord(blockHeader^.size) + HEAP_BLOCK_OVERHEAD_SIZE;
  end;

  Result := (moveableBlockIndex = extent^.moveableBlocksLength);
end;

function heap_sort_subblock_list(count: SizeUInt): Boolean;
begin
  libc_qsort(heap_subblock_list, count, SizeOf(PByte), @heap_qsort_compare_subblock);
  Result := True;
end;

function heap_build_fake_move_list(count: SizeUInt): Boolean;
var
  indexes: PInteger;
begin
  if count > heap_fake_move_list_size then
  begin
    indexes := PInteger(mem_realloc(heap_fake_move_list, SizeOf(Integer) * count));
    if indexes = nil then
      Exit(False);
    heap_fake_move_list_size := count;
    heap_fake_move_list := indexes;
  end;
  Result := True;
end;

end.
