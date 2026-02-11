{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/cache.h + cache.cc
// Resource cache: LRU eviction backed by heap allocator.
unit u_cache;

interface

uses
  u_heap;

const
  CACHE_ENTRY_MARKED_FOR_EVICTION = $01;
  CACHE_ENTRIES_INITIAL_CAPACITY = 100;
  CACHE_ENTRIES_GROW_CAPACITY = 50;

  CACHE_LIST_REQUEST_TYPE_ALL_ITEMS     = 0;
  CACHE_LIST_REQUEST_TYPE_LOCKED_ITEMS  = 1;
  CACHE_LIST_REQUEST_TYPE_UNLOCKED_ITEMS = 2;

type
  PPInteger = ^PInteger;

  TCacheSizeProc = function(key: Integer; sizePtr: PInteger): Integer; cdecl;
  TCacheReadProc = function(key: Integer; sizePtr: PInteger; buffer: PByte): Integer; cdecl;
  TCacheFreeProc = procedure(ptr: Pointer); cdecl;

  PCacheEntry = ^TCacheEntry;
  PPCacheEntry = ^PCacheEntry;
  TCacheEntry = record
    key: Integer;
    size: Integer;
    data: PByte;
    referenceCount: LongWord;
    hits: LongWord;
    flags: LongWord;
    mru: LongWord;
    heapHandleIndex: Integer;
  end;

  PCache = ^TCache;
  TCache = record
    size: Integer;
    maxSize: Integer;
    entriesLength: Integer;
    entriesCapacity: Integer;
    hits: LongWord;
    entries: PPCacheEntry;
    sizeProc: TCacheSizeProc;
    readProc: TCacheReadProc;
    freeProc: TCacheFreeProc;
    heap: THeap;
  end;

function cache_init(cache: PCache; sizeProc: TCacheSizeProc; readProc: TCacheReadProc; freeProc: TCacheFreeProc; maxSize: Integer): Boolean;
function cache_exit(cache: PCache): Boolean;
function cache_query(cache: PCache; key: Integer): Integer;
function cache_lock(cache: PCache; key: Integer; data: PPointer; cacheEntryPtr: PPCacheEntry): Boolean;
function cache_unlock(cache: PCache; cacheEntry: PCacheEntry): Boolean;
function cache_discard(cache: PCache; key: Integer): Integer;
function cache_flush(cache: PCache): Boolean;
function cache_size(cache: PCache; sizePtr: PInteger): Integer;
function cache_stats(cache: PCache; dest: PAnsiChar; size: SizeUInt): Boolean;
function cache_create_list(cache: PCache; a2: LongWord; tagsPtr: PPInteger; tagsLengthPtr: PInteger): Integer;
function cache_destroy_list(tagsPtr: PPInteger): Integer;

implementation

uses
  SysUtils, u_memory, u_debug;

type
  TQSortCompareFunc = function(a1, a2: Pointer): Integer; cdecl;

procedure libc_qsort(base: Pointer; num: SizeUInt; sz: SizeUInt; compare: TQSortCompareFunc); cdecl; external 'c' name 'qsort';

var
  lock_sound_ticker: Integer = 0;

// ---------------------------------------------------------------------------
// Internal forward declarations
// ---------------------------------------------------------------------------
function cache_add(cache: PCache; key: Integer; indexPtr: PInteger): Boolean; forward;
function cache_insert(cache: PCache; cacheEntry: PCacheEntry; index: Integer): Boolean; forward;
function cache_find(cache: PCache; key: Integer; indexPtr: PInteger): Integer; forward;
function cache_create_item(cacheEntryPtr: PPCacheEntry): Integer; forward;
function cache_init_item(cacheEntry: PCacheEntry): Boolean; forward;
function cache_destroy_item(cache: PCache; cacheEntry: PCacheEntry): Boolean; forward;
function cache_unlock_all(cache: PCache): Boolean; forward;
function cache_reset_counter(cache: PCache): Boolean; forward;
function cache_make_room(cache: PCache; size: Integer): Boolean; forward;
function cache_purge(cache: PCache): Boolean; forward;
function cache_resize_array(cache: PCache; newCapacity: Integer): Boolean; forward;

// ---------------------------------------------------------------------------
// qsort comparators
// ---------------------------------------------------------------------------
function cache_compare_make_room(a1, a2: Pointer): Integer; cdecl;
var
  v1, v2: PCacheEntry;
begin
  v1 := PPCacheEntry(a1)^;
  v2 := PPCacheEntry(a2)^;

  if (v1^.referenceCount <> 0) and (v2^.referenceCount = 0) then
    Exit(1);
  if (v2^.referenceCount <> 0) and (v1^.referenceCount = 0) then
    Exit(-1);

  if v1^.hits < v2^.hits then Exit(-1)
  else if v1^.hits > v2^.hits then Exit(1);

  if v1^.mru < v2^.mru then Exit(-1)
  else if v1^.mru > v2^.mru then Exit(1);

  Result := 0;
end;

function cache_compare_reset_counter(a1, a2: Pointer): Integer; cdecl;
var
  v1, v2: PCacheEntry;
begin
  v1 := PPCacheEntry(a1)^;
  v2 := PPCacheEntry(a2)^;

  if v1^.mru < v2^.mru then Exit(1)
  else if v1^.mru > v2^.mru then Exit(-1);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function cache_init(cache: PCache; sizeProc: TCacheSizeProc; readProc: TCacheReadProc; freeProc: TCacheFreeProc; maxSize: Integer): Boolean;
begin
  if not heap_init(@cache^.heap, maxSize) then
    Exit(False);

  cache^.size := 0;
  cache^.maxSize := maxSize;
  cache^.entriesLength := 0;
  cache^.entriesCapacity := CACHE_ENTRIES_INITIAL_CAPACITY;
  cache^.hits := 0;
  cache^.entries := PPCacheEntry(mem_malloc(SizeOf(PCacheEntry) * cache^.entriesCapacity));
  cache^.sizeProc := sizeProc;
  cache^.readProc := readProc;
  cache^.freeProc := freeProc;

  if cache^.entries = nil then
    Exit(False);

  FillChar(cache^.entries^, SizeOf(PCacheEntry) * cache^.entriesCapacity, 0);
  Result := True;
end;

function cache_exit(cache: PCache): Boolean;
begin
  if cache = nil then
    Exit(False);

  cache_unlock_all(cache);
  cache_flush(cache);
  heap_exit(@cache^.heap);

  cache^.size := 0;
  cache^.maxSize := 0;
  cache^.entriesLength := 0;
  cache^.entriesCapacity := 0;
  cache^.hits := 0;

  if cache^.entries <> nil then
  begin
    mem_free(cache^.entries);
    cache^.entries := nil;
  end;

  cache^.sizeProc := nil;
  cache^.readProc := nil;
  cache^.freeProc := nil;

  Result := True;
end;

function cache_query(cache: PCache; key: Integer): Integer;
var
  index: Integer;
begin
  if cache = nil then
    Exit(0);

  if cache_find(cache, key, @index) <> 2 then
    Exit(0);

  Result := 1;
end;

var
  debugKey: Integer = 0;

function cache_lock(cache: PCache; key: Integer; data: PPointer; cacheEntryPtr: PPCacheEntry): Boolean;
var
  index: Integer;
  rc: Integer;
  cacheEntry: PCacheEntry;
  debugThis: Boolean;
begin
  debugThis := (key = $0100000B) and (debugKey < 3);
  if debugThis then
  begin
    Inc(debugKey);
    WriteLn(StdErr, '[CACHE] cache_lock called with key=$', IntToHex(key, 8));
  end;

  if (cache = nil) or (data = nil) or (cacheEntryPtr = nil) then
  begin
    if debugThis then WriteLn(StdErr, '[CACHE] ERROR: nil parameters');
    Exit(False);
  end;

  cacheEntryPtr^ := nil;

  rc := cache_find(cache, key, @index);
  if debugThis then WriteLn(StdErr, '[CACHE] cache_find returned rc=', rc, ' index=', index);

  if rc = 2 then
  begin
    cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
    Inc(cacheEntry^.hits);
  end
  else if rc = 3 then
  begin
    if cache^.entriesLength >= High(Integer) then
    begin
      if debugThis then WriteLn(StdErr, '[CACHE] ERROR: entriesLength overflow');
      Exit(False);
    end;

    if debugThis then WriteLn(StdErr, '[CACHE] calling cache_add...');
    if not cache_add(cache, key, @index) then
    begin
      if debugThis then WriteLn(StdErr, '[CACHE] ERROR: cache_add failed');
      Exit(False);
    end;
    if debugThis then WriteLn(StdErr, '[CACHE] cache_add succeeded');

    lock_sound_ticker := lock_sound_ticker mod 4;
    // soundUpdate() call omitted - will be added when int/sound unit is converted
  end
  else
  begin
    if debugThis then WriteLn(StdErr, '[CACHE] ERROR: cache_find returned unexpected rc=', rc);
    Exit(False);
  end;

  cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
  if cacheEntry^.referenceCount = 0 then
  begin
    if not heap_lock(@cache^.heap, cacheEntry^.heapHandleIndex, @cacheEntry^.data) then
    begin
      if debugThis then WriteLn(StdErr, '[CACHE] ERROR: heap_lock failed');
      Exit(False);
    end;
  end;

  Inc(cacheEntry^.referenceCount);
  Inc(cache^.hits);
  cacheEntry^.mru := cache^.hits;

  if cache^.hits = $FFFFFFFF then
    cache_reset_counter(cache);

  data^ := cacheEntry^.data;
  cacheEntryPtr^ := cacheEntry;

  Result := True;
end;

function cache_unlock(cache: PCache; cacheEntry: PCacheEntry): Boolean;
begin
  if (cache = nil) or (cacheEntry = nil) then
    Exit(False);

  if cacheEntry^.referenceCount = 0 then
    Exit(False);

  Dec(cacheEntry^.referenceCount);

  if cacheEntry^.referenceCount = 0 then
    heap_unlock(@cache^.heap, cacheEntry^.heapHandleIndex);

  Result := True;
end;

function cache_discard(cache: PCache; key: Integer): Integer;
var
  index: Integer;
  cacheEntry: PCacheEntry;
begin
  if cache = nil then
    Exit(0);

  if cache_find(cache, key, @index) <> 2 then
    Exit(0);

  cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
  if cacheEntry^.referenceCount <> 0 then
    Exit(0);

  cacheEntry^.flags := cacheEntry^.flags or CACHE_ENTRY_MARKED_FOR_EVICTION;
  cache_purge(cache);
  Result := 1;
end;

function cache_flush(cache: PCache): Boolean;
var
  index: Integer;
  cacheEntry: PCacheEntry;
  optimalCapacity: Integer;
begin
  if cache = nil then
    Exit(False);

  for index := 0 to cache^.entriesLength - 1 do
  begin
    cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
    if cacheEntry^.referenceCount = 0 then
      cacheEntry^.flags := cacheEntry^.flags or CACHE_ENTRY_MARKED_FOR_EVICTION;
  end;

  cache_purge(cache);

  optimalCapacity := cache^.entriesLength + CACHE_ENTRIES_GROW_CAPACITY;
  if optimalCapacity < cache^.entriesCapacity then
    cache_resize_array(cache, optimalCapacity);

  Result := True;
end;

function cache_size(cache: PCache; sizePtr: PInteger): Integer;
begin
  if cache = nil then Exit(0);
  if sizePtr = nil then Exit(0);
  sizePtr^ := cache^.size;
  Result := 1;
end;

function cache_stats(cache: PCache; dest: PAnsiChar; size: SizeUInt): Boolean;
begin
  if (cache = nil) or (dest = nil) then
    Exit(False);

  // Match original: stats are disabled
  if size > 26 then
  begin
    Move(PAnsiChar('Cache stats are disabled.'#10)^, dest^, 26);
    dest[26] := #0;
  end;

  Result := True;
end;

function cache_create_list(cache: PCache; a2: LongWord; tagsPtr: PPInteger; tagsLengthPtr: PInteger): Integer;
var
  cacheItemIndex, tagIndex: Integer;
  entry: PCacheEntry;
begin
  if cache = nil then Exit(0);
  if tagsPtr = nil then Exit(0);
  if tagsLengthPtr = nil then Exit(0);

  tagsLengthPtr^ := 0;

  case a2 of
    CACHE_LIST_REQUEST_TYPE_ALL_ITEMS:
    begin
      tagsPtr^ := PInteger(mem_malloc(SizeOf(Integer) * cache^.entriesLength));
      if tagsPtr^ = nil then Exit(0);

      for cacheItemIndex := 0 to cache^.entriesLength - 1 do
      begin
        entry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(cacheItemIndex) * SizeOf(PCacheEntry))^;
        PInteger(PByte(tagsPtr^) + SizeUInt(cacheItemIndex) * SizeOf(Integer))^ := entry^.key;
      end;
      tagsLengthPtr^ := cache^.entriesLength;
    end;

    CACHE_LIST_REQUEST_TYPE_LOCKED_ITEMS:
    begin
      for cacheItemIndex := 0 to cache^.entriesLength - 1 do
      begin
        entry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(cacheItemIndex) * SizeOf(PCacheEntry))^;
        if entry^.referenceCount <> 0 then
          Inc(tagsLengthPtr^);
      end;

      tagsPtr^ := PInteger(mem_malloc(SizeOf(Integer) * tagsLengthPtr^));
      if tagsPtr^ = nil then Exit(0);

      tagIndex := 0;
      for cacheItemIndex := 0 to cache^.entriesLength - 1 do
      begin
        entry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(cacheItemIndex) * SizeOf(PCacheEntry))^;
        if entry^.referenceCount <> 0 then
        begin
          if tagIndex < tagsLengthPtr^ then
          begin
            PInteger(PByte(tagsPtr^) + SizeUInt(tagIndex) * SizeOf(Integer))^ := entry^.key;
            Inc(tagIndex);
          end;
        end;
      end;
    end;

    CACHE_LIST_REQUEST_TYPE_UNLOCKED_ITEMS:
    begin
      for cacheItemIndex := 0 to cache^.entriesLength - 1 do
      begin
        entry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(cacheItemIndex) * SizeOf(PCacheEntry))^;
        if entry^.referenceCount = 0 then
          Inc(tagsLengthPtr^);
      end;

      tagsPtr^ := PInteger(mem_malloc(SizeOf(Integer) * tagsLengthPtr^));
      if tagsPtr^ = nil then Exit(0);

      tagIndex := 0;
      for cacheItemIndex := 0 to cache^.entriesLength - 1 do
      begin
        entry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(cacheItemIndex) * SizeOf(PCacheEntry))^;
        if entry^.referenceCount = 0 then
        begin
          if tagIndex < tagsLengthPtr^ then
          begin
            PInteger(PByte(tagsPtr^) + SizeUInt(tagIndex) * SizeOf(Integer))^ := entry^.key;
            Inc(tagIndex);
          end;
        end;
      end;
    end;
  end;

  Result := 1;
end;

function cache_destroy_list(tagsPtr: PPInteger): Integer;
begin
  if tagsPtr = nil then Exit(0);
  if tagsPtr^ = nil then Exit(0);
  mem_free(tagsPtr^);
  tagsPtr^ := nil;
  Result := 1;
end;

// ---------------------------------------------------------------------------
// Internal implementation
// ---------------------------------------------------------------------------

function cache_add(cache: PCache; key: Integer; indexPtr: PInteger): Boolean;
var
  cacheEntry: PCacheEntry;
  sz, cacheEntrySize: Integer;
  allocated: Boolean;
  attempt: Integer;
  debugThis: Boolean;
  sizeProcResult: Integer;
begin
  debugThis := (key = $0100000B);

  if cache_create_item(@cacheEntry) <> 1 then
  begin
    if debugThis then WriteLn(StdErr, '[CACHE_ADD] cache_create_item failed');
    Exit(False);
  end;

  repeat
    sizeProcResult := cache^.sizeProc(key, @sz);
    if debugThis then WriteLn(StdErr, '[CACHE_ADD] sizeProc result=', sizeProcResult, ' sz=', sz);
    if sizeProcResult <> 0 then
      Break;

    if not cache_make_room(cache, sz) then
    begin
      if debugThis then WriteLn(StdErr, '[CACHE_ADD] cache_make_room failed for sz=', sz);
      Break;
    end;

    allocated := False;
    cacheEntrySize := sz;
    for attempt := 0 to 9 do
    begin
      if heap_allocate(@cache^.heap, @cacheEntry^.heapHandleIndex, sz, 1) then
      begin
        allocated := True;
        Break;
      end;

      cacheEntrySize := Trunc(Double(cacheEntrySize) + Double(sz) * 0.25);
      if cacheEntrySize > cache^.maxSize then
        Break;

      if not cache_make_room(cache, cacheEntrySize) then
        Break;
    end;

    if not allocated then
    begin
      cache_flush(cache);
      allocated := True;
      if not heap_allocate(@cache^.heap, @cacheEntry^.heapHandleIndex, sz, 1) then
      begin
        if not heap_allocate(@cache^.heap, @cacheEntry^.heapHandleIndex, sz, 0) then
          allocated := False;
      end;
    end;

    if not allocated then
      Break;

    repeat
      if not heap_lock(@cache^.heap, cacheEntry^.heapHandleIndex, @cacheEntry^.data) then
        Break;

      if cache^.readProc(key, @sz, cacheEntry^.data) <> 0 then
        Break;

      heap_unlock(@cache^.heap, cacheEntry^.heapHandleIndex);

      cacheEntry^.size := sz;
      cacheEntry^.key := key;

      // Check if the index is still valid
      if indexPtr^ < cache^.entriesLength then
      begin
        if key < PPCacheEntry(PByte(cache^.entries) + SizeUInt(indexPtr^) * SizeOf(PCacheEntry))^^.key then
        begin
          if (indexPtr^ = 0) or (key > PPCacheEntry(PByte(cache^.entries) + SizeUInt(indexPtr^ - 1) * SizeOf(PCacheEntry))^^.key) then
          begin
            // Index is still valid, skip re-search
            if not cache_insert(cache, cacheEntry, indexPtr^) then
              Break;
            Exit(True);
          end;
        end;
      end;

      if cache_find(cache, key, indexPtr) <> 3 then
        Break;

      if not cache_insert(cache, cacheEntry, indexPtr^) then
        Break;

      Exit(True);
    until True;

    heap_unlock(@cache^.heap, cacheEntry^.heapHandleIndex);
  until True;

  cache_destroy_item(cache, cacheEntry);
  Result := False;
end;

function cache_insert(cache: PCache; cacheEntry: PCacheEntry; index: Integer): Boolean;
begin
  if cache^.entriesLength = cache^.entriesCapacity - 1 then
  begin
    if not cache_resize_array(cache, cache^.entriesCapacity + CACHE_ENTRIES_GROW_CAPACITY) then
      Exit(False);
  end;

  // Move entries below insertion point
  Move(
    PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^,
    PPCacheEntry(PByte(cache^.entries) + SizeUInt(index + 1) * SizeOf(PCacheEntry))^,
    SizeOf(PCacheEntry) * (cache^.entriesLength - index));

  PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^ := cacheEntry;
  Inc(cache^.entriesLength);
  Inc(cache^.size, cacheEntry^.size);

  Result := True;
end;

function cache_find(cache: PCache; key: Integer; indexPtr: PInteger): Integer;
var
  length_: Integer;
  r, l, mid, cmp: Integer;
begin
  length_ := cache^.entriesLength;
  if length_ = 0 then
  begin
    indexPtr^ := 0;
    Exit(3);
  end;

  r := length_ - 1;
  l := 0;
  cmp := 0;

  repeat
    mid := (l + r) div 2;
    cmp := key - PPCacheEntry(PByte(cache^.entries) + SizeUInt(mid) * SizeOf(PCacheEntry))^^.key;

    if cmp = 0 then
    begin
      indexPtr^ := mid;
      Exit(2);
    end;

    if cmp > 0 then
      l := l + 1
    else
      r := r - 1;
  until r < l;

  if cmp < 0 then
    indexPtr^ := mid
  else
    indexPtr^ := mid + 1;

  Result := 3;
end;

function cache_create_item(cacheEntryPtr: PPCacheEntry): Integer;
begin
  cacheEntryPtr^ := PCacheEntry(mem_malloc(SizeOf(TCacheEntry)));

  // NOTE: Original code has wrong check (cacheEntryPtr != NULL instead of *cacheEntryPtr != NULL)
  if cacheEntryPtr <> nil then
  begin
    if cache_init_item(cacheEntryPtr^) then
      Exit(1);
  end;

  Result := 0;
end;

function cache_init_item(cacheEntry: PCacheEntry): Boolean;
begin
  cacheEntry^.key := 0;
  cacheEntry^.size := 0;
  cacheEntry^.data := nil;
  cacheEntry^.referenceCount := 0;
  cacheEntry^.hits := 0;
  cacheEntry^.flags := 0;
  cacheEntry^.mru := 0;
  Result := True;
end;

function cache_destroy_item(cache: PCache; cacheEntry: PCacheEntry): Boolean;
begin
  if cacheEntry^.data <> nil then
    heap_deallocate(@cache^.heap, @cacheEntry^.heapHandleIndex);

  mem_free(cacheEntry);
  Result := True;
end;

function cache_unlock_all(cache: PCache): Boolean;
var
  hp: PHeap;
  index: Integer;
  cacheEntry: PCacheEntry;
begin
  hp := @cache^.heap;
  for index := 0 to cache^.entriesLength - 1 do
  begin
    cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
    if cacheEntry^.referenceCount <> 0 then
    begin
      heap_unlock(hp, cacheEntry^.heapHandleIndex);
      cacheEntry^.referenceCount := 0;
    end;
  end;
  Result := True;
end;

function cache_reset_counter(cache: PCache): Boolean;
var
  entries: PPCacheEntry;
  index: Integer;
  cacheEntry: PCacheEntry;
begin
  if cache = nil then
    Exit(False);

  entries := PPCacheEntry(mem_malloc(SizeOf(PCacheEntry) * cache^.entriesLength));
  if entries = nil then
    Exit(False);

  Move(cache^.entries^, entries^, SizeOf(PCacheEntry) * cache^.entriesLength);

  libc_qsort(entries, cache^.entriesLength, SizeOf(PCacheEntry), @cache_compare_reset_counter);

  for index := 0 to cache^.entriesLength - 1 do
  begin
    cacheEntry := PPCacheEntry(PByte(entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
    cacheEntry^.mru := index;
  end;

  cache^.hits := cache^.entriesLength;

  // FIXME: Original code leaks `entries` here
  mem_free(entries);

  Result := True;
end;

function cache_make_room(cache: PCache; size: Integer): Boolean;
var
  entries: PPCacheEntry;
  threshold, accum, index: Integer;
  entry: PCacheEntry;
begin
  if size > cache^.maxSize then
    Exit(False);

  if cache^.maxSize - cache^.size >= size then
    Exit(True);

  entries := PPCacheEntry(mem_malloc(SizeOf(PCacheEntry) * cache^.entriesLength));
  if entries <> nil then
  begin
    Move(cache^.entries^, entries^, SizeOf(PCacheEntry) * cache^.entriesLength);
    libc_qsort(entries, cache^.entriesLength, SizeOf(PCacheEntry), @cache_compare_make_room);

    threshold := size + Trunc(Double(cache^.size) * 0.2);
    accum := 0;

    for index := 0 to cache^.entriesLength - 1 do
    begin
      entry := PPCacheEntry(PByte(entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
      if entry^.referenceCount = 0 then
      begin
        if entry^.size >= threshold then
        begin
          entry^.flags := entry^.flags or CACHE_ENTRY_MARKED_FOR_EVICTION;
          accum := 0;
          Break;
        end
        else
        begin
          Inc(accum, entry^.size);
          if accum >= threshold then
            Break;
        end;
      end;
    end;

    if accum <> 0 then
    begin
      if index = cache^.entriesLength then
        Dec(index);

      while index >= 0 do
      begin
        entry := PPCacheEntry(PByte(entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
        if entry^.referenceCount = 0 then
          entry^.flags := entry^.flags or CACHE_ENTRY_MARKED_FOR_EVICTION;
        Dec(index);
      end;
    end;

    mem_free(entries);
  end;

  cache_purge(cache);

  if cache^.maxSize - cache^.size >= size then
    Exit(True);

  Result := False;
end;

function cache_purge(cache: PCache): Boolean;
var
  index: Integer;
  cacheEntry: PCacheEntry;
  cacheEntrySize: Integer;
begin
  index := 0;
  while index < cache^.entriesLength do
  begin
    cacheEntry := PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^;
    if (cacheEntry^.flags and CACHE_ENTRY_MARKED_FOR_EVICTION) <> 0 then
    begin
      if cacheEntry^.referenceCount <> 0 then
      begin
        cacheEntry^.flags := cacheEntry^.flags and (not CACHE_ENTRY_MARKED_FOR_EVICTION);
      end
      else
      begin
        cacheEntrySize := cacheEntry^.size;
        cache_destroy_item(cache, cacheEntry);

        // Move entries up
        Move(
          PPCacheEntry(PByte(cache^.entries) + SizeUInt(index + 1) * SizeOf(PCacheEntry))^,
          PPCacheEntry(PByte(cache^.entries) + SizeUInt(index) * SizeOf(PCacheEntry))^,
          SizeOf(PCacheEntry) * ((cache^.entriesLength - index) - 1));

        Dec(cache^.entriesLength);
        Dec(cache^.size, cacheEntrySize);
        Dec(index); // compensate for removed entry
      end;
    end;
    Inc(index);
  end;

  Result := True;
end;

function cache_resize_array(cache: PCache; newCapacity: Integer): Boolean;
var
  entries: PPCacheEntry;
begin
  if newCapacity < cache^.entriesLength then
    Exit(False);

  entries := PPCacheEntry(mem_realloc(cache^.entries, SizeOf(PCacheEntry) * newCapacity));
  if entries = nil then
    Exit(False);

  cache^.entries := entries;
  cache^.entriesCapacity := newCapacity;
  Result := True;
end;

end.
