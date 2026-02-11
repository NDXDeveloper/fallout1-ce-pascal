{$MODE OBJFPC}{$H+}
// Converted from: src/game/sfxcache.h + sfxcache.cc
// Sound effects cache: caching, decoding and file I/O for sound effects.
unit u_sfxcache;

interface

const
  SOUND_EFFECTS_MAX_COUNT = 4;

function sfxc_init(cache_size: Integer; const effectsPath: PAnsiChar): Integer;
procedure sfxc_exit;
function sfxc_is_initialized: Integer;
procedure sfxc_flush;
function sfxc_cached_open(const fname: PAnsiChar; mode: Integer): Integer; cdecl;
function sfxc_cached_close(handle: Integer): Integer; cdecl;
function sfxc_cached_read(handle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
function sfxc_cached_write(handle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
function sfxc_cached_seek(handle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
function sfxc_cached_tell(handle: Integer): LongInt; cdecl;
function sfxc_cached_file_size(handle: Integer): LongInt; cdecl;

implementation

uses
  SysUtils, u_adecode, u_cache, u_gconfig, u_config, u_sfxlist, u_db, u_memory;

const
  SOUND_EFFECTS_CACHE_MIN_SIZE = $40000;

type
  PCacheEntry = Pointer; // forward ref to cache entry handle

  PSoundEffect = ^TSoundEffect;
  TSoundEffect = record
    used: Boolean;
    cacheHandle: PCacheEntry;
    tag: Integer;
    dataSize: Integer;
    fileSize: Integer;
    position: Integer;
    dataPosition: Integer;
    data: PByte;
  end;

function sfxc_effect_size(tag: Integer; sizePtr: PInteger): Integer; cdecl; forward;
function sfxc_effect_load(tag: Integer; sizePtr: PInteger; data: PByte): Integer; cdecl; forward;
procedure sfxc_effect_free(ptr: Pointer); cdecl; forward;
function sfxc_handle_list_create: Integer; forward;
procedure sfxc_handle_list_destroy; forward;
function sfxc_handle_create(handlePtr: PInteger; id: Integer; data: Pointer; cacheHandle: PCacheEntry): Integer; forward;
procedure sfxc_handle_destroy(handle: Integer); forward;
function sfxc_handle_is_legal(a1: Integer): Boolean; forward;
function sfxc_mode_is_legal(mode: Integer): Boolean; forward;
function sfxc_decode(handle: Integer; buf: Pointer; size: LongWord): Integer; forward;
function sfxc_ad_reader(stream_: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl; forward;

var
  sfxc_dlevel: Integer = MaxInt;
  sfxc_effect_path: PAnsiChar = nil;
  sfxc_handle_list: PSoundEffect = nil;
  sfxc_files_open: Integer = 0;
  sfxc_pcache: PCache = nil;
  sfxc_initialized: Boolean = False;
  sfxc_cmpr: Integer = 1;

function sfxc_init(cache_size: Integer; const effectsPath: PAnsiChar): Integer;
var
  ep: PAnsiChar;
begin
  if not config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_DEBUG_SFXC_KEY, @sfxc_dlevel) then
    sfxc_dlevel := 1;

  if cache_size <= SOUND_EFFECTS_CACHE_MIN_SIZE then
    Exit(-1);

  ep := effectsPath;
  if ep = nil then
    ep := '';

  sfxc_effect_path := mem_strdup(ep);
  if sfxc_effect_path = nil then
    Exit(-1);

  if sfxl_init(sfxc_effect_path, sfxc_cmpr, sfxc_dlevel) <> SFXL_OK then
  begin
    mem_free(sfxc_effect_path);
    Exit(-1);
  end;

  if sfxc_handle_list_create <> 0 then
  begin
    sfxl_exit;
    mem_free(sfxc_effect_path);
    Exit(-1);
  end;

  sfxc_pcache := PCache(mem_malloc(SizeOf(TCache)));
  if sfxc_pcache = nil then
  begin
    sfxc_handle_list_destroy;
    sfxl_exit;
    mem_free(sfxc_effect_path);
    Exit(-1);
  end;

  if not cache_init(sfxc_pcache, @sfxc_effect_size, @sfxc_effect_load, @sfxc_effect_free, cache_size) then
  begin
    mem_free(sfxc_pcache);
    sfxc_handle_list_destroy;
    sfxl_exit;
    mem_free(sfxc_effect_path);
    Exit(-1);
  end;

  sfxc_initialized := True;
  Result := 0;
end;

procedure sfxc_exit;
begin
  if sfxc_initialized then
  begin
    cache_exit(sfxc_pcache);
    mem_free(sfxc_pcache);
    sfxc_pcache := nil;

    sfxc_handle_list_destroy;

    sfxl_exit;

    mem_free(sfxc_effect_path);

    sfxc_initialized := False;
  end;
end;

function sfxc_is_initialized: Integer;
begin
  Result := Ord(sfxc_initialized);
end;

procedure sfxc_flush;
begin
  if sfxc_initialized then
    cache_flush(sfxc_pcache);
end;

function sfxc_cached_open(const fname: PAnsiChar; mode: Integer): Integer; cdecl;
var
  copy: PAnsiChar;
  tag: Integer;
  err: Integer;
  data: Pointer;
  cacheHandle: PCacheEntry;
  handle: Integer;
begin
  if sfxc_files_open >= SOUND_EFFECTS_MAX_COUNT then
    Exit(-1);

  copy := mem_strdup(fname);
  if copy = nil then
    Exit(-1);

  err := sfxl_name_to_tag(copy, @tag);

  mem_free(copy);

  if err <> SFXL_OK then
    Exit(-1);

  data := nil;
  cacheHandle := nil;
  if not cache_lock(sfxc_pcache, tag, @data, @cacheHandle) then
    Exit(-1);

  if sfxc_handle_create(@handle, tag, data, cacheHandle) <> 0 then
  begin
    cache_unlock(sfxc_pcache, cacheHandle);
    Exit(-1);
  end;

  Result := handle;
end;

function sfxc_cached_close(handle: Integer): Integer; cdecl;
var
  soundEffect: PSoundEffect;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(-1);

  soundEffect := sfxc_handle_list + handle;
  if not cache_unlock(sfxc_pcache, soundEffect^.cacheHandle) then
    Exit(-1);

  sfxc_handle_destroy(handle);
  Result := 0;
end;

function sfxc_cached_read(handle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
var
  soundEffect: PSoundEffect;
  bytesToRead: Integer;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(-1);

  if size = 0 then
    Exit(0);

  soundEffect := sfxc_handle_list + handle;
  if soundEffect^.dataSize - soundEffect^.position <= 0 then
    Exit(0);

  if Integer(size) < (soundEffect^.dataSize - soundEffect^.position) then
    bytesToRead := Integer(size)
  else
    bytesToRead := soundEffect^.dataSize - soundEffect^.position;

  case sfxc_cmpr of
    0:
      Move((soundEffect^.data + soundEffect^.position)^, buf^, bytesToRead);
    1:
    begin
      if sfxc_decode(handle, buf, bytesToRead) <> 0 then
        Exit(-1);
    end;
  else
    Exit(-1);
  end;

  soundEffect^.position := soundEffect^.position + bytesToRead;
  Result := bytesToRead;
end;

function sfxc_cached_write(handle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
begin
  Result := -1;
end;

function sfxc_cached_seek(handle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
var
  soundEffect: PSoundEffect;
  position: Integer;
  normalizedOffset: LongInt;
  remainingSize: LongInt;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(-1);

  soundEffect := sfxc_handle_list + handle;

  case origin of
    0: // SEEK_SET
      position := 0;
    1: // SEEK_CUR
      position := soundEffect^.position;
    2: // SEEK_END
      position := soundEffect^.dataSize;
  else
    position := 0;
  end;

  normalizedOffset := Abs(offset);

  if offset >= 0 then
  begin
    remainingSize := soundEffect^.dataSize - soundEffect^.position;
    if normalizedOffset > remainingSize then
      normalizedOffset := remainingSize;
    offset := position + normalizedOffset;
  end
  else
  begin
    if normalizedOffset > position then
      Exit(-1);
    offset := position - normalizedOffset;
  end;

  soundEffect^.position := offset;
  Result := offset;
end;

function sfxc_cached_tell(handle: Integer): LongInt; cdecl;
var
  soundEffect: PSoundEffect;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(-1);

  soundEffect := sfxc_handle_list + handle;
  Result := soundEffect^.position;
end;

function sfxc_cached_file_size(handle: Integer): LongInt; cdecl;
var
  soundEffect: PSoundEffect;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(0);

  soundEffect := sfxc_handle_list + handle;
  Result := soundEffect^.dataSize;
end;

function sfxc_effect_size(tag: Integer; sizePtr: PInteger): Integer; cdecl;
var
  size: Integer;
begin
  if sfxl_size_cached(tag, @size) = -1 then
    Exit(-1);

  sizePtr^ := size;
  Result := 0;
end;

function sfxc_effect_load(tag: Integer; sizePtr: PInteger; data: PByte): Integer; cdecl;
var
  size: Integer;
  name: PAnsiChar;
begin
  if not sfxl_tag_is_legal(tag) then
    Exit(-1);

  sfxl_size_cached(tag, @size);

  name := nil;
  sfxl_name(tag, @name);

  if db_read_to_buf(name, data) <> 0 then
  begin
    mem_free(name);
    Exit(-1);
  end;

  mem_free(name);
  sizePtr^ := size;
  Result := 0;
end;

procedure sfxc_effect_free(ptr: Pointer); cdecl;
begin
  mem_free(ptr);
end;

function sfxc_handle_list_create: Integer;
var
  index: Integer;
  soundEffect: PSoundEffect;
begin
  sfxc_handle_list := PSoundEffect(mem_malloc(SizeOf(TSoundEffect) * SOUND_EFFECTS_MAX_COUNT));
  if sfxc_handle_list = nil then
    Exit(-1);

  for index := 0 to SOUND_EFFECTS_MAX_COUNT - 1 do
  begin
    soundEffect := sfxc_handle_list + index;
    soundEffect^.used := False;
  end;

  sfxc_files_open := 0;
  Result := 0;
end;

procedure sfxc_handle_list_destroy;
var
  index: Integer;
  soundEffect: PSoundEffect;
begin
  if sfxc_files_open <> 0 then
  begin
    for index := 0 to SOUND_EFFECTS_MAX_COUNT - 1 do
    begin
      soundEffect := sfxc_handle_list + index;
      if not soundEffect^.used then
        sfxc_cached_close(index);
    end;
  end;

  mem_free(sfxc_handle_list);
end;

function sfxc_handle_create(handlePtr: PInteger; id: Integer; data: Pointer; cacheHandle: PCacheEntry): Integer;
var
  soundEffect: PSoundEffect;
  index: Integer;
begin
  if sfxc_files_open >= SOUND_EFFECTS_MAX_COUNT then
    Exit(-1);

  index := 0;
  while index < SOUND_EFFECTS_MAX_COUNT do
  begin
    soundEffect := sfxc_handle_list + index;
    if not soundEffect^.used then
      Break;
    Inc(index);
  end;

  if index = SOUND_EFFECTS_MAX_COUNT then
    Exit(-1);

  soundEffect^.used := True;
  soundEffect^.cacheHandle := cacheHandle;
  soundEffect^.tag := id;

  sfxl_size_full(id, @soundEffect^.dataSize);
  sfxl_size_cached(id, @soundEffect^.fileSize);

  soundEffect^.position := 0;
  soundEffect^.dataPosition := 0;

  soundEffect^.data := PByte(data);

  handlePtr^ := index;
  Result := 0;
end;

procedure sfxc_handle_destroy(handle: Integer);
begin
  if handle <= SOUND_EFFECTS_MAX_COUNT then
    (sfxc_handle_list + handle)^.used := False;
end;

function sfxc_handle_is_legal(a1: Integer): Boolean;
var
  soundEffect: PSoundEffect;
begin
  if a1 >= SOUND_EFFECTS_MAX_COUNT then
    Exit(False);

  soundEffect := sfxc_handle_list + a1;

  if not soundEffect^.used then
    Exit(False);

  if soundEffect^.dataSize < soundEffect^.position then
    Exit(False);

  Result := sfxl_tag_is_legal(soundEffect^.tag);
end;

function sfxc_mode_is_legal(mode: Integer): Boolean;
begin
  if (mode and $01) <> 0 then Exit(False);
  if (mode and $02) <> 0 then Exit(False);
  if (mode and $10) <> 0 then Exit(False);
  Result := True;
end;

function sfxc_decode(handle: Integer; buf: Pointer; size: LongWord): Integer;
var
  soundEffect: PSoundEffect;
  channels, sampleRate, sampleCount: Integer;
  ad: PAudioDecoder;
  temp: Pointer;
  bytesRead: Integer;
begin
  if not sfxc_handle_is_legal(handle) then
    Exit(-1);

  soundEffect := sfxc_handle_list + handle;
  soundEffect^.dataPosition := 0;

  ad := Create_AudioDecoder(@sfxc_ad_reader, @handle, @channels, @sampleRate, @sampleCount);

  if soundEffect^.position <> 0 then
  begin
    temp := mem_malloc(soundEffect^.position);
    if temp = nil then
    begin
      AudioDecoder_Close(ad);
      Exit(-1);
    end;

    bytesRead := AudioDecoder_Read(ad, temp, soundEffect^.position);
    mem_free(temp);

    if bytesRead <> soundEffect^.position then
    begin
      AudioDecoder_Close(ad);
      Exit(-1);
    end;
  end;

  bytesRead := AudioDecoder_Read(ad, buf, Integer(size));
  AudioDecoder_Close(ad);

  if LongWord(bytesRead) <> size then
    Exit(-1);

  Result := 0;
end;

function sfxc_ad_reader(stream_: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl;
var
  handle: Integer;
  soundEffect: PSoundEffect;
  bytesToRead: LongWord;
begin
  if size = 0 then
    Exit(0);

  handle := PInteger(stream_)^;
  soundEffect := sfxc_handle_list + handle;

  bytesToRead := LongWord(soundEffect^.fileSize - soundEffect^.dataPosition);
  if size <= bytesToRead then
    bytesToRead := size;

  Move((soundEffect^.data + soundEffect^.dataPosition)^, buf^, bytesToRead);

  soundEffect^.dataPosition := soundEffect^.dataPosition + Integer(bytesToRead);

  Result := bytesToRead;
end;

end.
