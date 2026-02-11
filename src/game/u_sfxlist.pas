{$MODE OBJFPC}{$H+}
// Converted from: src/game/sfxlist.h + sfxlist.cc
// Sound effects file list management: loading, sorting, and lookup by tag.
unit u_sfxlist;

interface

const
  SFXL_OK              = 0;
  SFXL_ERR             = 1;
  SFXL_ERR_TAG_INVALID = 2;

function sfxl_tag_is_legal(tag: Integer): Boolean;
function sfxl_init(const soundEffectsPath: PAnsiChar; compression, debugLevel: Integer): Integer;
procedure sfxl_exit;
function sfxl_name_to_tag(name: PAnsiChar; tagPtr: PInteger): Integer;
function sfxl_name(tag: Integer; pathPtr: PPAnsiChar): Integer;
function sfxl_size_full(tag: Integer; sizePtr: PInteger): Integer;
function sfxl_size_cached(tag: Integer; sizePtr: PInteger): Integer;

implementation

uses
  SysUtils, u_adecode, u_platform_compat, u_db, u_debug, u_memory;

type
  PSoundEffectsListEntry = ^TSoundEffectsListEntry;
  TSoundEffectsListEntry = record
    name: PAnsiChar;
    dataSize: Integer;
    fileSize: Integer;
  end;

function sfxl_index(tag: Integer; indexPtr: PInteger): Integer; forward;
function sfxl_index_to_tag(index: Integer; tagPtr: PInteger): Integer; forward;
procedure sfxl_destroy; forward;
function sfxl_get_names: Integer; forward;
function sfxl_copy_names(fileNameList: PPAnsiChar): Integer; forward;
function sfxl_get_sizes: Integer; forward;
function sfxl_sort_by_name: Integer; forward;
function sfxl_compare_by_name(a1, a2: Pointer): Integer; cdecl; forward;
function sfxl_ad_reader(stream_: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl; forward;

var
  sfxl_initialized: Boolean = False;
  sfxl_dlevel: Integer = MaxInt;
  sfxl_effect_path: PAnsiChar = nil;
  sfxl_effect_path_len: Integer = 0;
  sfxl_list: PSoundEffectsListEntry = nil;
  sfxl_files_total: Integer = 0;
  sfxl_compression: Integer;

// libc qsort
procedure libc_qsort(base: Pointer; num: SizeUInt; size: SizeUInt; compar: Pointer); cdecl; external 'c' name 'qsort';
// libc bsearch
function libc_bsearch(key: Pointer; base: Pointer; num: SizeUInt; size: SizeUInt; compar: Pointer): Pointer; cdecl; external 'c' name 'bsearch';

function sfxl_tag_is_legal(tag: Integer): Boolean;
begin
  Result := sfxl_index(tag, nil) = SFXL_OK;
end;

function sfxl_init(const soundEffectsPath: PAnsiChar; compression, debugLevel: Integer): Integer;
var
  err: Integer;
begin
  sfxl_dlevel := debugLevel;
  sfxl_compression := compression;
  sfxl_files_total := 0;

  sfxl_effect_path := mem_strdup(soundEffectsPath);
  if sfxl_effect_path = nil then
    Exit(SFXL_ERR);

  sfxl_effect_path_len := StrLen(sfxl_effect_path);

  err := sfxl_get_names;
  if err <> SFXL_OK then
  begin
    mem_free(sfxl_effect_path);
    Exit(err);
  end;

  err := sfxl_get_sizes;
  if err <> SFXL_OK then
  begin
    sfxl_destroy;
    mem_free(sfxl_effect_path);
    Exit(err);
  end;

  err := sfxl_sort_by_name;
  if err <> SFXL_OK then
  begin
    sfxl_destroy;
    mem_free(sfxl_effect_path);
    Exit(err);
  end;

  sfxl_initialized := True;
  Result := SFXL_OK;
end;

procedure sfxl_exit;
begin
  if sfxl_initialized then
  begin
    sfxl_destroy;
    mem_free(sfxl_effect_path);
    sfxl_initialized := False;
  end;
end;

function sfxl_name_to_tag(name: PAnsiChar; tagPtr: PInteger): Integer;
var
  dummy: TSoundEffectsListEntry;
  entry: PSoundEffectsListEntry;
  tag: Integer;
begin
  if compat_strnicmp(sfxl_effect_path, name, sfxl_effect_path_len) <> 0 then
    Exit(SFXL_ERR);

  dummy.name := name + sfxl_effect_path_len;

  entry := PSoundEffectsListEntry(libc_bsearch(@dummy, sfxl_list,
    sfxl_files_total, SizeOf(TSoundEffectsListEntry), @sfxl_compare_by_name));
  if entry = nil then
    Exit(SFXL_ERR);

  if sfxl_index_to_tag((PtrUInt(entry) - PtrUInt(sfxl_list)) div SizeOf(TSoundEffectsListEntry), @tag) <> SFXL_OK then
    Exit(SFXL_ERR);

  tagPtr^ := tag;
  Result := SFXL_OK;
end;

function sfxl_name(tag: Integer; pathPtr: PPAnsiChar): Integer;
var
  index: Integer;
  err: Integer;
  name: PAnsiChar;
  path: PAnsiChar;
begin
  err := sfxl_index(tag, @index);
  if err <> SFXL_OK then
    Exit(err);

  name := (sfxl_list + index)^.name;

  path := PAnsiChar(mem_malloc(StrLen(sfxl_effect_path) + StrLen(name) + 1));
  if path = nil then
    Exit(SFXL_ERR);

  StrCopy(path, sfxl_effect_path);
  StrCat(path, name);

  pathPtr^ := path;
  Result := SFXL_OK;
end;

function sfxl_size_full(tag: Integer; sizePtr: PInteger): Integer;
var
  index: Integer;
  rc: Integer;
  entry: PSoundEffectsListEntry;
begin
  rc := sfxl_index(tag, @index);
  if rc <> SFXL_OK then
    Exit(rc);

  entry := sfxl_list + index;
  sizePtr^ := entry^.dataSize;
  Result := SFXL_OK;
end;

function sfxl_size_cached(tag: Integer; sizePtr: PInteger): Integer;
var
  index: Integer;
  err: Integer;
  entry: PSoundEffectsListEntry;
begin
  err := sfxl_index(tag, @index);
  if err <> SFXL_OK then
    Exit(err);

  entry := sfxl_list + index;
  sizePtr^ := entry^.fileSize;
  Result := SFXL_OK;
end;

function sfxl_index(tag: Integer; indexPtr: PInteger): Integer;
var
  index: Integer;
begin
  if tag <= 0 then
    Exit(SFXL_ERR_TAG_INVALID);

  if (tag and 1) <> 0 then
    Exit(SFXL_ERR_TAG_INVALID);

  index := (tag div 2) - 1;
  if index >= sfxl_files_total then
    Exit(SFXL_ERR_TAG_INVALID);

  if indexPtr <> nil then
    indexPtr^ := index;

  Result := SFXL_OK;
end;

function sfxl_index_to_tag(index: Integer; tagPtr: PInteger): Integer;
begin
  if index >= sfxl_files_total then
    Exit(SFXL_ERR);

  if index < 0 then
    Exit(SFXL_ERR);

  tagPtr^ := 2 * (index + 1);
  Result := SFXL_OK;
end;

procedure sfxl_destroy;
var
  index: Integer;
  entry: PSoundEffectsListEntry;
begin
  if sfxl_files_total < 0 then
    Exit;

  if sfxl_list = nil then
    Exit;

  for index := 0 to sfxl_files_total - 1 do
  begin
    entry := sfxl_list + index;
    if entry^.name <> nil then
      mem_free(entry^.name);
  end;

  mem_free(sfxl_list);
  sfxl_list := nil;

  sfxl_files_total := 0;
end;

function sfxl_get_names: Integer;
var
  extension: PAnsiChar;
  pattern: PAnsiChar;
  fileNameList: PPAnsiChar;
  err: Integer;
begin
  case sfxl_compression of
    0: extension := '*.SND';
    1: extension := '*.ACM';
  else
    Exit(SFXL_ERR);
  end;

  pattern := PAnsiChar(mem_malloc(StrLen(sfxl_effect_path) + StrLen(extension) + 1));
  if pattern = nil then
    Exit(SFXL_ERR);

  StrCopy(pattern, sfxl_effect_path);
  StrCat(pattern, extension);

  fileNameList := nil;
  sfxl_files_total := db_get_file_list(pattern, @fileNameList, nil, 0);
  mem_free(pattern);

  if sfxl_files_total > 10000 then
  begin
    db_free_file_list(@fileNameList, nil);
    Exit(SFXL_ERR);
  end;

  if sfxl_files_total <= 0 then
    Exit(SFXL_ERR);

  sfxl_list := PSoundEffectsListEntry(mem_malloc(SizeOf(TSoundEffectsListEntry) * sfxl_files_total));
  if sfxl_list = nil then
  begin
    db_free_file_list(@fileNameList, nil);
    Exit(SFXL_ERR);
  end;

  FillChar(sfxl_list^, SizeOf(TSoundEffectsListEntry) * sfxl_files_total, 0);

  err := sfxl_copy_names(fileNameList);

  db_free_file_list(@fileNameList, nil);

  if err <> SFXL_OK then
  begin
    sfxl_destroy;
    Exit(err);
  end;

  Result := SFXL_OK;
end;

function sfxl_copy_names(fileNameList: PPAnsiChar): Integer;
var
  index: Integer;
  entry: PSoundEffectsListEntry;
  p: PPAnsiChar;
begin
  p := fileNameList;
  for index := 0 to sfxl_files_total - 1 do
  begin
    entry := sfxl_list + index;
    entry^.name := mem_strdup(p^);
    Inc(p);
    if entry^.name = nil then
    begin
      sfxl_destroy;
      Exit(SFXL_ERR);
    end;
  end;

  Result := SFXL_OK;
end;

function sfxl_get_sizes: Integer;
var
  de: TDirEntry;
  path: PAnsiChar;
  fileName: PAnsiChar;
  index: Integer;
  entry: PSoundEffectsListEntry;
  stream_: PDB_FILE;
  channels, sampleRate, sampleCount: Integer;
  ad: PAudioDecoder;
begin
  path := PAnsiChar(mem_malloc(sfxl_effect_path_len + 13));
  if path = nil then
    Exit(SFXL_ERR);

  StrCopy(path, sfxl_effect_path);

  fileName := path + sfxl_effect_path_len;

  for index := 0 to sfxl_files_total - 1 do
  begin
    entry := sfxl_list + index;
    StrCopy(fileName, entry^.name);

    if db_dir_entry(path, @de) <> 0 then
    begin
      mem_free(path);
      Exit(SFXL_ERR);
    end;

    if de.Length_ <= 0 then
    begin
      mem_free(path);
      Exit(SFXL_ERR);
    end;

    entry^.fileSize := de.Length_;

    case sfxl_compression of
      0:
        entry^.dataSize := de.Length_;
      1:
      begin
        stream_ := db_fopen(path, 'rb');
        if stream_ = nil then
        begin
          mem_free(path);
          Exit(1);
        end;

        ad := Create_AudioDecoder(@sfxl_ad_reader, stream_, @channels, @sampleRate, @sampleCount);
        entry^.dataSize := 2 * sampleCount;
        AudioDecoder_Close(ad);
        db_fclose(stream_);
      end;
    else
      begin
        mem_free(path);
        Exit(SFXL_ERR);
      end;
    end;
  end;

  mem_free(path);
  Result := SFXL_OK;
end;

function sfxl_sort_by_name: Integer;
begin
  if sfxl_files_total <> 1 then
    libc_qsort(sfxl_list, sfxl_files_total, SizeOf(TSoundEffectsListEntry), @sfxl_compare_by_name);
  Result := SFXL_OK;
end;

function sfxl_compare_by_name(a1, a2: Pointer): Integer; cdecl;
var
  v1, v2: PSoundEffectsListEntry;
begin
  v1 := PSoundEffectsListEntry(a1);
  v2 := PSoundEffectsListEntry(a2);
  Result := compat_stricmp(v1^.name, v2^.name);
end;

function sfxl_ad_reader(stream_: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl;
begin
  Result := db_fread(buf, 1, size, PDB_FILE(stream_));
end;

end.
