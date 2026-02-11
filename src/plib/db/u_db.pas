{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/plib/db/db.h + db.cc
// DAT archive system: file I/O with LZSS compression, hash tables, big-endian I/O.
unit u_db;

interface

const
  DB_DATABASE_LIST_CAPACITY = 10;
  DB_DATABASE_FILE_LIST_CAPACITY = 32;
  DB_HASH_TABLE_SIZE = 4095;

type
  PDB_FILE = ^TDB_FILE;
  PDB_DATABASE = ^TDB_DATABASE;

  PDirEntry = ^TDirEntry;
  TDirEntry = record
    Flags: Integer;
    Offset: Integer;
    Length_: Integer;
    FieldC: Integer;
  end;

  TDbReadCallback = procedure; cdecl;
  TDbMallocFunc = function(Size: SizeUInt): Pointer; cdecl;
  TDbStrdupFunc = function(const S: PAnsiChar): PAnsiChar; cdecl;
  TDbFreeFunc = procedure(Ptr: Pointer); cdecl;

  // Internal: DB_FILE record
  TDB_FILE = record
    Database: PDB_DATABASE;
    Flags: LongWord;
    Field8: Integer;
    FieldC: Integer; // union: Integer or FILE* (for uncompressed)
    Field10: Integer;
    Field14: Integer;
    Field18: Integer;
    Field1C: PByte;
    Field20: PByte;
  end;

  // Internal: DB_DATABASE record (forward-declared above)
  TDB_DATABASE = record
    DataFile: PAnsiChar;
    Stream: Pointer; // FILE*
    DataFilePath: PAnsiChar;
    PatchesPath: PAnsiChar;
    ShouldFreePatchesPath: Byte;
    Root: Pointer; // PAssocArray - stored as opaque to avoid circular deps
    Entries: Pointer; // array of assoc_array
    FilesLength: Integer;
    Files: array[0..DB_DATABASE_FILE_LIST_CAPACITY - 1] of TDB_FILE;
    HashTable: PByte;
  end;

function INVALID_DATABASE_HANDLE: PDB_DATABASE; inline;

function db_init(const datafile, datafile_path, patches_path: PAnsiChar; show_cursor: Integer): PDB_DATABASE;
function db_select(db_handle: PDB_DATABASE): Integer;
function db_current: PDB_DATABASE;
function db_total: Integer;
function db_close(db_handle: PDB_DATABASE): Integer;
procedure db_exit;
function db_dir_entry(const name: PAnsiChar; de: PDirEntry): Integer;
function db_read_to_buf(const filename: PAnsiChar; buf: PByte): Integer;
function db_fopen(const filename, mode: PAnsiChar): PDB_FILE;
function db_fclose(stream: PDB_FILE): Integer;
function db_fread(buf: Pointer; size, count: SizeUInt; stream: PDB_FILE): SizeUInt;
function db_fgetc(stream: PDB_FILE): Integer;
function db_ungetc(ch: Integer; stream: PDB_FILE): Integer;
function db_fgets(str: PAnsiChar; size: SizeUInt; stream: PDB_FILE): PAnsiChar;
function db_fwrite(const buf: Pointer; size, count: SizeUInt; stream: PDB_FILE): SizeUInt;
function db_fputc(ch: Integer; stream: PDB_FILE): Integer;
function db_fputs(const s: PAnsiChar; stream: PDB_FILE): Integer;
function db_fseek(stream: PDB_FILE; offset: LongInt; origin: Integer): Integer;
function db_ftell(stream: PDB_FILE): LongInt;
procedure db_rewind(stream: PDB_FILE);
function db_freadByte(stream: PDB_FILE; c: PByte): Integer;
function db_freadShort(stream: PDB_FILE; s: PWord): Integer;
function db_freadInt(stream: PDB_FILE; i: PInteger): Integer;
function db_freadLong(stream: PDB_FILE; l: PLongWord): Integer;
function db_freadFloat(stream: PDB_FILE; q: PSingle): Integer;
function db_fwriteByte(stream: PDB_FILE; c: Byte): Integer;
function db_fwriteShort(stream: PDB_FILE; s: Word): Integer;
function db_fwriteInt(stream: PDB_FILE; i: Integer): Integer;
function db_fwriteLong(stream: PDB_FILE; l: LongWord): Integer;
function db_fwriteFloat(stream: PDB_FILE; q: Single): Integer;
function db_freadByteCount(stream: PDB_FILE; c: PByte; count: Integer): Integer;
function db_freadShortCount(stream: PDB_FILE; s: PWord; count: Integer): Integer;
function db_freadIntCount(stream: PDB_FILE; i: PInteger; count: Integer): Integer;
function db_freadLongCount(stream: PDB_FILE; l: PLongWord; count: Integer): Integer;
function db_freadFloatCount(stream: PDB_FILE; q: PSingle; count: Integer): Integer;
function db_fwriteByteCount(stream: PDB_FILE; c: PByte; count: Integer): Integer;
function db_fwriteShortCount(stream: PDB_FILE; s: PWord; count: Integer): Integer;
function db_fwriteIntCount(stream: PDB_FILE; i: PInteger; count: Integer): Integer;
function db_fwriteLongCount(stream: PDB_FILE; l: PLongWord; count: Integer): Integer;
function db_fwriteFloatCount(stream: PDB_FILE; q: PSingle; count: Integer): Integer;
function db_feof(stream: PDB_FILE): Integer;
function db_filelength(stream: PDB_FILE): LongInt;
procedure db_register_mem(malloc_func: TDbMallocFunc; strdup_func: TDbStrdupFunc; free_func: TDbFreeFunc);
procedure db_register_callback(callback: TDbReadCallback; threshold: SizeUInt);
procedure db_enable_hash_table;
function db_reset_hash_tables: Integer;
function db_add_hash_entry(const path: PAnsiChar; sep: Integer): Integer;
function db_get_file_list(const filespec: PAnsiChar; filelist: PPPAnsiChar; desclist: PPPAnsiChar; desclen: Integer): Integer;
procedure db_free_file_list(file_list: PPPAnsiChar; desclist: PPPAnsiChar);

// Typed read/write helpers
function db_freadUInt8(stream: PDB_FILE; valuePtr: PByte): Integer;
function db_freadInt8(stream: PDB_FILE; valuePtr: PShortInt): Integer;
function db_freadUInt16(stream: PDB_FILE; valuePtr: PWord): Integer;
function db_freadInt16(stream: PDB_FILE; valuePtr: PSmallInt): Integer;
function db_freadUInt32(stream: PDB_FILE; valuePtr: PLongWord): Integer;
function db_freadInt32(stream: PDB_FILE; valuePtr: PInteger): Integer;
function db_freadUInt8List(stream: PDB_FILE; arr: PByte; count: Integer): Integer;
function db_freadInt8List(stream: PDB_FILE; arr: PShortInt; count: Integer): Integer;
function db_freadInt16List(stream: PDB_FILE; arr: PSmallInt; count: Integer): Integer;
function db_freadInt32List(stream: PDB_FILE; arr: PInteger; count: Integer): Integer;
function db_freadBool(stream: PDB_FILE; valuePtr: PBoolean): Integer;

function db_fwriteUInt8(stream: PDB_FILE; value: Byte): Integer;
function db_fwriteInt8(stream: PDB_FILE; value: ShortInt): Integer;
function db_fwriteUInt16(stream: PDB_FILE; value: Word): Integer;
function db_fwriteInt16(stream: PDB_FILE; value: SmallInt): Integer;
function db_fwriteUInt32(stream: PDB_FILE; value: LongWord): Integer;
function db_fwriteInt32(stream: PDB_FILE; value: Integer): Integer;
function db_fwriteUInt8List(stream: PDB_FILE; arr: PByte; count: Integer): Integer;
function db_fwriteInt8List(stream: PDB_FILE; arr: PShortInt; count: Integer): Integer;
function db_fwriteInt16List(stream: PDB_FILE; arr: PSmallInt; count: Integer): Integer;
function db_fwriteInt32List(stream: PDB_FILE; arr: PInteger; count: Integer): Integer;
function db_fwriteBool(stream: PDB_FILE; value: Boolean): Integer;

implementation

uses
  SysUtils, u_lzss, u_platform_compat, u_assoc;

type
  clong = LongInt;

// libc imports
function libc_fread(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fread';
function libc_fwrite(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fwrite';
function libc_fgetc(stream: Pointer): Integer; cdecl; external 'c' name 'fgetc';
function libc_fputc(c: Integer; stream: Pointer): Integer; cdecl; external 'c' name 'fputc';
function libc_fputs(s: PAnsiChar; stream: Pointer): Integer; cdecl; external 'c' name 'fputs';
function libc_fgets(s: PAnsiChar; n: Integer; stream: Pointer): PAnsiChar; cdecl; external 'c' name 'fgets';
function libc_ungetc(c: Integer; stream: Pointer): Integer; cdecl; external 'c' name 'ungetc';
function libc_fseek(stream: Pointer; offset: clong; whence: Integer): Integer; cdecl; external 'c' name 'fseek';
function libc_ftell(stream: Pointer): clong; cdecl; external 'c' name 'ftell';
function libc_fclose(stream: Pointer): Integer; cdecl; external 'c' name 'fclose';
function libc_feof(stream: Pointer): Integer; cdecl; external 'c' name 'feof';
procedure libc_rewind(stream: Pointer); cdecl; external 'c' name 'rewind';
function libc_vfprintf(stream: Pointer; format: PAnsiChar; args: Pointer): Integer; cdecl; external 'c' name 'vfprintf';

const
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;
  PATH_SEP = '/';

var
  current_database: PDB_DATABASE = nil;
  db_used_malloc: Boolean = False;
  hash_is_on: Boolean = False;
  read_count: SizeUInt = 0;
  read_threshold: SizeUInt = 16384;
  read_callback: TDbReadCallback = nil;
  database_list: array[0..DB_DATABASE_LIST_CAPACITY - 1] of PDB_DATABASE;

// Internal memory function pointers
function db_default_malloc(Size: SizeUInt): Pointer; cdecl; forward;
function db_default_strdup(const S: PAnsiChar): PAnsiChar; cdecl; forward;
procedure db_default_free(Ptr: Pointer); cdecl; forward;

var
  db_malloc: TDbMallocFunc = @db_default_malloc;
  db_strdup: TDbStrdupFunc = @db_default_strdup;
  db_free: TDbFreeFunc = @db_default_free;

function internal_malloc(size: SizeUInt): Pointer;
begin
  db_used_malloc := True;
  Result := db_malloc(size);
end;

function internal_strdup(const s: PAnsiChar): PAnsiChar;
begin
  db_used_malloc := True;
  Result := db_strdup(s);
end;

procedure internal_free(ptr: Pointer);
begin
  db_free(ptr);
end;

function db_default_malloc(Size: SizeUInt): Pointer; cdecl;
begin
  Result := GetMem(Size);
end;

function db_default_strdup(const S: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := compat_strdup(S);
end;

procedure db_default_free(Ptr: Pointer); cdecl;
begin
  FreeMem(Ptr);
end;

function INVALID_DATABASE_HANDLE: PDB_DATABASE; inline;
begin
  Result := PDB_DATABASE(PtrInt(-1));
end;

// Helper to get FILE* from DB_FILE's union field
function GetFileStream(f: PDB_FILE): Pointer; inline;
begin
  Result := Pointer(PtrUInt(f^.FieldC));
end;

procedure SetFileStream(f: PDB_FILE; stream: Pointer); inline;
begin
  f^.FieldC := Integer(PtrUInt(stream));
end;

// Big-endian read/write helpers for raw FILE*
function fread_short(stream: Pointer; s: PWord): Integer;
var
  high_, low_: Integer;
begin
  high_ := libc_fgetc(stream);
  if high_ = -1 then Exit(-1);
  low_ := libc_fgetc(stream);
  if low_ = -1 then Exit(-1);
  s^ := Word((low_ and $FF) or (high_ shl 8));
  Result := 0;
end;

function db_find_empty_position(position_ptr: PInteger): Integer;
var
  index: Integer;
begin
  if position_ptr = nil then Exit(-1);
  if current_database^.FilesLength >= DB_DATABASE_FILE_LIST_CAPACITY then Exit(-1);

  for index := 0 to DB_DATABASE_FILE_LIST_CAPACITY - 1 do
  begin
    if current_database^.Files[index].Field8 = 0 then
    begin
      position_ptr^ := index;
      Exit(0);
    end;
  end;
  Result := -1;
end;

function db_add_fp_rec(stream: Pointer; a2: PByte; a3, flags: Integer): PDB_FILE;
var
  pos: Integer;
begin
  Result := nil;
  if current_database^.FilesLength < DB_DATABASE_FILE_LIST_CAPACITY then
  begin
    if db_find_empty_position(@pos) = 0 then
    begin
      FillByte(current_database^.Files[pos], SizeOf(TDB_FILE), 0);
      current_database^.Files[pos].Database := current_database;

      if (flags and $4) <> 0 then
      begin
        SetFileStream(@current_database^.Files[pos], stream);
        Result := @current_database^.Files[pos];
      end
      else
      begin
        current_database^.Files[pos].FieldC := a3;
        current_database^.Files[pos].Field10 := a3;

        case flags and $F0 of
          16:
          begin
            current_database^.Files[pos].Field1C := a2;
            current_database^.Files[pos].Field20 := a2;
            Result := @current_database^.Files[pos];
          end;
          32:
          begin
            current_database^.Files[pos].Field14 := Integer(libc_ftell(stream));
            current_database^.Files[pos].Field18 := Integer(libc_ftell(stream));
            Result := @current_database^.Files[pos];
          end;
          64:
          begin
            current_database^.Files[pos].Field14 := Integer(libc_ftell(stream));
            current_database^.Files[pos].Field18 := Integer(libc_ftell(stream));
            current_database^.Files[pos].Field1C := a2;
            current_database^.Files[pos].Field20 := a2 + $4000;
            Result := @current_database^.Files[pos];
          end;
        end;
      end;
    end;
  end;

  if Result <> nil then
  begin
    current_database^.Files[pos].Flags := LongWord(flags);
    current_database^.Files[pos].Field8 := 1;
    Inc(current_database^.FilesLength);
  end;
end;

function db_delete_fp_rec(stream: PDB_FILE): Integer;
begin
  if stream = nil then Exit(-1);

  if (stream^.Flags and $4) <> 0 then
    libc_fclose(GetFileStream(stream))
  else
  begin
    case stream^.Flags and $F0 of
      16:
        if stream^.Field1C <> nil then
          internal_free(stream^.Field1C);
      32: ; // nothing
      64:
        if stream^.Field1C <> nil then
          internal_free(stream^.Field1C);
    end;
  end;

  Dec(stream^.Database^.FilesLength);
  FillByte(stream^, SizeOf(TDB_FILE), 0);
  Result := 0;
end;

procedure db_preload_buffer(stream: PDB_FILE);
var
  v1: Word;
begin
  if (stream^.Flags and $8) <> 0 then
  if (stream^.Flags and $F0) = 64 then
  if stream^.Field10 <> 0 then
  if stream^.Field20 >= stream^.Field1C + $4000 then
  begin
    if libc_fseek(stream^.Database^.Stream, stream^.Field18, SEEK_SET) = 0 then
    begin
      if fread_short(stream^.Database^.Stream, @v1) = 0 then
      begin
        if (v1 and $8000) <> 0 then
        begin
          v1 := v1 and (not $8000);
          libc_fread(stream^.Field1C, 1, v1, stream^.Database^.Stream);
        end
        else
          lzss_decode_to_buf(stream^.Database^.Stream, stream^.Field1C, v1);

        stream^.Field20 := stream^.Field1C;
        stream^.Field18 := Integer(libc_ftell(stream^.Database^.Stream));
      end;
    end;
  end;
end;

// ---- DAT file parsing via assoc_array ----

function db_read_long(stream: Pointer; value_ptr: PInteger): Integer;
var
  c, value: Integer;
begin
  c := libc_fgetc(stream); if c = -1 then Exit(-1); value := c;
  c := libc_fgetc(stream); if c = -1 then Exit(-1); value := (value shl 8) or c;
  c := libc_fgetc(stream); if c = -1 then Exit(-1); value := (value shl 8) or c;
  c := libc_fgetc(stream); if c = -1 then Exit(-1); value := (value shl 8) or c;
  value_ptr^ := value;
  Result := 0;
end;

function db_assoc_load_dir_entry(stream: Pointer; buffer: Pointer; size: SizeUInt; flags: Integer): Integer; cdecl;
var
  de: PDirEntry;
begin
  if size <> SizeOf(TDirEntry) then Exit(-1);
  de := PDirEntry(buffer);
  if db_read_long(stream, @de^.Flags) <> 0 then Exit(-1);
  if db_read_long(stream, @de^.Offset) <> 0 then Exit(-1);
  if db_read_long(stream, @de^.Length_) <> 0 then Exit(-1);
  if db_read_long(stream, @de^.FieldC) <> 0 then Exit(-1);
  Result := 0;
end;

procedure db_init_database_cleanup(database: PDB_DATABASE);
begin
  if database^.Stream <> nil then
  begin
    libc_fclose(database^.Stream);
    database^.Stream := nil;
  end;
  if database^.DataFile <> nil then
  begin
    internal_free(database^.DataFile);
    database^.DataFile := nil;
  end;
end;

function db_init_database(database: PDB_DATABASE; const datafile, datafile_path: PAnsiChar): Integer;
var
  funcs: TAssocFuncList;
  index: Integer;
  loadFailed: Boolean;
  v1: PAnsiChar;
  v2: SizeUInt;
  root: PAssocArray;
  entries: PAssocArray;
begin
  if database = nil then Exit(-1);
  if datafile = nil then Exit(0);

  database^.DataFile := internal_strdup(datafile);
  if database^.DataFile = nil then Exit(-1);

  database^.Stream := compat_fopen(database^.DataFile, 'rb');
  if database^.Stream = nil then
  begin
    internal_free(database^.DataFile);
    database^.DataFile := nil;
    Exit(-1);
  end;

  // Allocate and initialize root assoc_array
  root := PAssocArray(internal_malloc(SizeOf(TAssocArray)));
  if root = nil then
  begin
    db_init_database_cleanup(database);
    Exit(-1);
  end;
  database^.Root := root;

  if assoc_init(root, 0, SizeOf(TDirEntry), nil) <> 0 then
  begin
    internal_free(root);
    database^.Root := nil;
    db_init_database_cleanup(database);
    Exit(-1);
  end;

  // Load root directory tree from DAT file
  if assoc_load(database^.Stream, root, 0) <> 0 then
  begin
    assoc_free(root);
    internal_free(root);
    database^.Root := nil;
    db_init_database_cleanup(database);
    Exit(-1);
  end;
  WriteLn(StdErr, '[DB] Root loaded: Size=', root^.Size, ' DataSize=', root^.DataSize);

  // Allocate entries array - one assoc_array per directory
  entries := PAssocArray(internal_malloc(SizeOf(TAssocArray) * SizeUInt(root^.Size)));
  if entries = nil then
  begin
    assoc_free(root);
    internal_free(root);
    database^.Root := nil;
    db_init_database_cleanup(database);
    Exit(-1);
  end;
  database^.Entries := entries;

  // Set up callbacks for loading dir_entry structures
  FillByte(funcs, SizeOf(funcs), 0);
  funcs.LoadFunc := @db_assoc_load_dir_entry;

  // Load each directory's file entries
  loadFailed := False;
  for index := 0 to root^.Size - 1 do
  begin
    if assoc_init(PAssocArray(PByte(entries) + SizeOf(TAssocArray) * index), 0, SizeOf(TDirEntry), @funcs) <> 0 then
    begin
      loadFailed := True;
      Break;
    end;
    if assoc_load(database^.Stream, PAssocArray(PByte(entries) + SizeOf(TAssocArray) * index), 0) <> 0 then
    begin
      loadFailed := True;
      Break;
    end;
  end;

  if loadFailed then
  begin
    while index > 0 do
    begin
      Dec(index);
      assoc_free(PAssocArray(PByte(entries) + SizeOf(TAssocArray) * index));
    end;
    internal_free(entries);
    database^.Entries := nil;
    assoc_free(root);
    internal_free(root);
    database^.Root := nil;
    db_init_database_cleanup(database);
    Exit(-1);
  end;

  // Set up datafile_path
  if (datafile_path <> nil) and (StrLen(datafile_path) > 0) then
  begin
    v1 := datafile_path;
    if v1[0] = '\' then
      Inc(v1);
  end
  else
    v1 := '.\';

  v2 := StrLen(v1);
  database^.DataFilePath := PAnsiChar(internal_malloc(v2 + 2));
  if database^.DataFilePath = nil then
  begin
    for index := 0 to root^.Size - 1 do
      assoc_free(PAssocArray(PByte(entries) + SizeOf(TAssocArray) * index));
    internal_free(entries);
    database^.Entries := nil;
    assoc_free(root);
    internal_free(root);
    database^.Root := nil;
    db_init_database_cleanup(database);
    Exit(-1);
  end;

  StrCopy(database^.DataFilePath, v1);
  if database^.DataFilePath[v2 - 1] <> '\' then
  begin
    database^.DataFilePath[v2] := '\';
    database^.DataFilePath[v2 + 1] := #0;
  end;

  Result := 0;
end;

function db_init_patches(database: PDB_DATABASE; const patches_path: PAnsiChar): Integer;
var
  len: SizeUInt;
begin
  if database = nil then Exit(-1);
  if patches_path = nil then Exit(0);
  if StrLen(patches_path) = 0 then Exit(0);

  len := StrLen(patches_path);
  database^.PatchesPath := PAnsiChar(internal_malloc(len + 2));
  if database^.PatchesPath = nil then Exit(-1);

  StrCopy(database^.PatchesPath, patches_path);
  database^.ShouldFreePatchesPath := 1;

  if database^.PatchesPath[len - 1] <> PATH_SEP then
  begin
    database^.PatchesPath[len] := PATH_SEP;
    database^.PatchesPath[len + 1] := #0;
  end;

  Result := 0;
end;

function db_find_dir_entry(path: PAnsiChar; de: PDirEntry): Integer;
var
  normalized_path: PAnsiChar;
  pos, dir_index, entry_index: Integer;
  root: PAssocArray;
  entries: PAssocArray;
  entryArr: PAssocArray;
  pair: PAssocPair;
begin
  root := PAssocArray(current_database^.Root);
  entries := PAssocArray(current_database^.Entries);

  if current_database^.DataFile = nil then Exit(-1);
  if path = nil then Exit(-1);
  if de = nil then Exit(-1);
  if root = nil then Exit(-1);

  normalized_path := path;

  // Remove leading .\ or .
  if normalized_path[0] = '.' then
  begin
    Inc(normalized_path);
    if normalized_path[0] = '\' then
      Inc(normalized_path);
  end;

  // Find the last backslash to separate directory from filename
  pos := StrLen(normalized_path) - 1;
  while pos >= 0 do
  begin
    if normalized_path[pos] = '\' then
      Break;
    Dec(pos);
  end;

  // Search root for the directory
  if pos >= 0 then
  begin
    normalized_path[pos] := #0;
    dir_index := assoc_search(root, normalized_path);
  end
  else
    dir_index := 0; // Root directory

  if dir_index = -1 then
  begin
    if pos >= 0 then
      normalized_path[pos] := '\';
    Exit(-1);
  end;

  // Search the directory for the file entry
  entryArr := PAssocArray(PByte(entries) + SizeOf(TAssocArray) * dir_index);
  entry_index := assoc_search(entryArr, normalized_path + pos + 1);

  if pos >= 0 then
    normalized_path[pos] := '\';

  if entry_index = -1 then
    Exit(-1);

  // Copy the directory entry
  pair := PAssocPair(PByte(entryArr^.List) + SizeOf(TAssocPair) * entry_index);
  de^ := PDirEntry(pair^.Data)^;

  Result := 0;
end;

function db_get_hash_value(database: PDB_DATABASE; const path: PAnsiChar; sep: Integer; hash_value: PInteger): Integer;
begin
  // Simplified: always allow access
  if hash_value <> nil then
    hash_value^ := 1;
  Result := 0;
end;

function db_add_hash_entry_to_database(database: PDB_DATABASE; const path: PAnsiChar; sep: AnsiChar): Integer;
begin
  Result := 0;
end;

function db_init(const datafile, datafile_path, patches_path: PAnsiChar; show_cursor: Integer): PDB_DATABASE;
var
  index: Integer;
  database: PDB_DATABASE;
begin
  // Find empty slot
  database := nil;
  for index := 0 to DB_DATABASE_LIST_CAPACITY - 1 do
  begin
    if database_list[index] = nil then
    begin
      database := PDB_DATABASE(internal_malloc(SizeOf(TDB_DATABASE)));
      if database = nil then
        Exit(INVALID_DATABASE_HANDLE);

      FillByte(database^, SizeOf(TDB_DATABASE), 0);
      database_list[index] := database;
      Break;
    end;
  end;

  if database = nil then
    Exit(INVALID_DATABASE_HANDLE);

  if db_init_database(database, datafile, datafile_path) <> 0 then
  begin
    db_close(database);
    Exit(INVALID_DATABASE_HANDLE);
  end;

  if db_init_patches(database, patches_path) <> 0 then
  begin
    db_close(database);
    Exit(INVALID_DATABASE_HANDLE);
  end;

  if current_database = nil then
    current_database := database;

  Result := database;
end;

function db_select(db_handle: PDB_DATABASE): Integer;
var
  index: Integer;
begin
  if db_handle = INVALID_DATABASE_HANDLE then Exit(-1);

  for index := 0 to DB_DATABASE_LIST_CAPACITY - 1 do
  begin
    if database_list[index] = db_handle then
    begin
      current_database := database_list[index];
      Exit(0);
    end;
  end;
  Result := -1;
end;

function db_current: PDB_DATABASE;
begin
  if current_database <> nil then
    Result := current_database
  else
    Result := INVALID_DATABASE_HANDLE;
end;

function db_total: Integer;
var
  index, count: Integer;
begin
  count := 0;
  for index := 0 to DB_DATABASE_LIST_CAPACITY - 1 do
    if database_list[index] <> nil then
      Inc(count);
  Result := count;
end;

function db_close(db_handle: PDB_DATABASE): Integer;
var
  index, j: Integer;
begin
  if (db_handle = nil) or (db_handle = INVALID_DATABASE_HANDLE) then
    Exit(-1);

  for index := 0 to DB_DATABASE_LIST_CAPACITY - 1 do
  begin
    if database_list[index] = db_handle then
    begin
      if database_list[index] = current_database then
        current_database := nil;

      // Free assoc arrays
      if (db_handle^.Root <> nil) and (db_handle^.Entries <> nil) then
      begin
        for j := 0 to PAssocArray(db_handle^.Root)^.Size - 1 do
          assoc_free(PAssocArray(PByte(db_handle^.Entries) + SizeOf(TAssocArray) * j));
        internal_free(db_handle^.Entries);
        assoc_free(PAssocArray(db_handle^.Root));
        internal_free(db_handle^.Root);
      end;

      if db_handle^.Stream <> nil then
        libc_fclose(db_handle^.Stream);
      if db_handle^.DataFile <> nil then
        internal_free(db_handle^.DataFile);
      if db_handle^.DataFilePath <> nil then
        internal_free(db_handle^.DataFilePath);
      if (db_handle^.PatchesPath <> nil) and (db_handle^.ShouldFreePatchesPath <> 0) then
        internal_free(db_handle^.PatchesPath);
      if db_handle^.HashTable <> nil then
        internal_free(db_handle^.HashTable);

      internal_free(db_handle);
      database_list[index] := nil;
      Exit(0);
    end;
  end;
  Result := -1;
end;

procedure db_exit;
var
  index: Integer;
begin
  for index := 0 to DB_DATABASE_LIST_CAPACITY - 1 do
    if database_list[index] <> nil then
      db_close(database_list[index]);
end;

function db_dir_entry(const name: PAnsiChar; de: PDirEntry): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: Pointer;
begin
  if current_database = nil then Exit(-1);
  if name = nil then Exit(-1);
  if de = nil then Exit(-1);

  // Try patches path first
  if current_database^.PatchesPath <> nil then
  begin
    {$IFDEF FPC}
    StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [current_database^.PatchesPath, name]);
    {$ENDIF}
    compat_windows_path_to_native(@path[0]);

    stream := compat_fopen(@path[0], 'rb');
    if stream <> nil then
    begin
      de^.Flags := 4;
      de^.Offset := 0;
      de^.Length_ := getFileSize(stream);
      de^.FieldC := 0;
      libc_fclose(stream);
      Exit(0);
    end;
  end;

  // Search in DAT file
  if current_database^.DataFile <> nil then
  begin
    StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [PAnsiChar(current_database^.DataFilePath), name]);
    compat_strupr(@path[0]);
    if db_find_dir_entry(@path[0], de) = 0 then
      Exit(0);
  end;

  Result := -1;
end;

function db_read_to_buf(const filename: PAnsiChar; buf: PByte): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: Pointer;
  size: Integer;
  de: TDirEntry;
begin
  if current_database = nil then Exit(-1);
  if filename = nil then Exit(-1);
  if buf = nil then Exit(-1);

  if current_database^.PatchesPath <> nil then
  begin
    StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [current_database^.PatchesPath, filename]);
    compat_windows_path_to_native(@path[0]);

    stream := compat_fopen(@path[0], 'rb');
    if stream <> nil then
    begin
      size := getFileSize(stream);
      libc_fread(buf, 1, SizeUInt(size), stream);
      libc_fclose(stream);
      Exit(0);
    end;
  end;

  // Read from DAT file
  if current_database^.DataFile <> nil then
  begin
    StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [PAnsiChar(current_database^.DataFilePath), filename]);
    compat_strupr(@path[0]);

    if db_find_dir_entry(@path[0], @de) = 0 then
    begin
      if current_database^.Stream <> nil then
      begin
        if libc_fseek(current_database^.Stream, de.Offset, SEEK_SET) = 0 then
        begin
          if de.Flags = 0 then
            de.Flags := 16;

          case de.Flags and $F0 of
            16:
              lzss_decode_to_buf(current_database^.Stream, buf, de.FieldC);
            32:
              libc_fread(buf, 1, SizeUInt(de.Length_), current_database^.Stream);
          end;
          Exit(0);
        end;
      end;
    end;
  end;

  Result := -1;
end;

function db_fopen(const filename, mode: PAnsiChar): PDB_FILE;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: Pointer;
  flags, mode_value, k: Integer;
  mode_is_text: Boolean;
  de: TDirEntry;
  buf: PByte;
begin
  Result := nil;
  if current_database = nil then Exit;
  if filename = nil then Exit;
  if mode = nil then Exit;
  if current_database^.FilesLength >= DB_DATABASE_FILE_LIST_CAPACITY then Exit;

  mode_value := -1;
  mode_is_text := True;
  k := 0;
  while mode[k] <> #0 do
  begin
    case mode[k] of
      'b': mode_is_text := False;
      '+', 'a', 'w': mode_value := 0;
      'r': mode_value := 1;
    end;
    Inc(k);
  end;

  if mode_value = -1 then Exit;

  flags := 1;
  if mode_is_text then flags := 2;

  if current_database^.PatchesPath <> nil then
  begin
    StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [current_database^.PatchesPath, filename]);
    compat_windows_path_to_native(@path[0]);

    stream := compat_fopen(@path[0], mode);
    if stream <> nil then
    begin
      WriteLn(StdErr, '[DB] db_fopen PATCH: "', PAnsiChar(@path[0]), '" mode=', mode);
      Result := db_add_fp_rec(stream, nil, 0, flags or $4);
      Exit;
    end;
  end;

  // Read-only access from DAT file
  if mode_value <> 1 then Exit;
  if current_database^.DataFile = nil then Exit;

  StrLFmt(@path[0], COMPAT_MAX_PATH - 1, '%s%s', [PAnsiChar(current_database^.DataFilePath), filename]);
  compat_strupr(@path[0]);

  if db_find_dir_entry(@path[0], @de) = -1 then Exit;
  if current_database^.Stream = nil then Exit;
  WriteLn(StdErr, '[DB] db_fopen DAT: "', PAnsiChar(@path[0]), '" flags=', de.Flags, ' offset=', de.Offset, ' len=', de.Length_, ' fieldC=', de.FieldC);
  if libc_fseek(current_database^.Stream, de.Offset, SEEK_SET) <> 0 then Exit;

  if de.Flags = 0 then
    de.Flags := 16;

  case de.Flags and $F0 of
    16:
    begin
      buf := PByte(internal_malloc(de.Length_));
      if buf <> nil then
      begin
        lzss_decode_to_buf(current_database^.Stream, buf, de.FieldC);
        Result := db_add_fp_rec(nil, buf, de.Length_, flags or $10 or $8);
      end;
    end;
    32:
      Result := db_add_fp_rec(current_database^.Stream, nil, de.Length_, flags or $20 or $8);
    64:
    begin
      buf := PByte(internal_malloc($4000));
      if buf <> nil then
        Result := db_add_fp_rec(current_database^.Stream, buf, de.Length_, flags or $40 or $8);
    end;
  end;
end;

function db_fclose(stream: PDB_FILE): Integer;
begin
  Result := db_delete_fp_rec(stream);
end;

function db_fread(buf: Pointer; size, count: SizeUInt; stream: PDB_FILE): SizeUInt;
var
  p: PByte;
  elements_read: SizeUInt;
  remaining_size, v1: Integer;
begin
  elements_read := 0;
  p := PByte(buf);

  if stream <> nil then
  begin
    if (stream^.Flags and $4) <> 0 then
      elements_read := libc_fread(p, size, count, GetFileStream(stream))
    else if buf <> nil then
    begin
      case stream^.Flags and $F0 of
        16:
        begin
          if stream^.Field10 <> 0 then
          begin
            elements_read := SizeUInt(stream^.Field10) div size;
            if elements_read > count then
              elements_read := count;
            if elements_read <> 0 then
            begin
              remaining_size := Integer(elements_read * size);
              Move(stream^.Field20^, p^, remaining_size);
              Inc(stream^.Field20, remaining_size);
              Dec(stream^.Field10, remaining_size);
            end;
          end;
        end;
        32:
        begin
          if stream^.Field10 <> 0 then
          begin
            elements_read := SizeUInt(stream^.Field10) div size;
            if elements_read > count then
              elements_read := count;
            if elements_read <> 0 then
            begin
              if libc_fseek(stream^.Database^.Stream, stream^.Field18, SEEK_SET) = 0 then
              begin
                elements_read := libc_fread(p, size, elements_read, stream^.Database^.Stream);
                stream^.Field18 := Integer(libc_ftell(stream^.Database^.Stream));
                Dec(stream^.Field10, Integer(elements_read * size));
              end;
            end;
          end;
        end;
        64:
        begin
          if stream^.Field10 <> 0 then
          begin
            elements_read := SizeUInt(stream^.Field10) div size;
            if elements_read > count then
              elements_read := count;
            if elements_read <> 0 then
            begin
              remaining_size := Integer(elements_read * size);
              while remaining_size <> 0 do
              begin
                db_preload_buffer(stream);
                v1 := Integer(PtrUInt(stream^.Field1C) - PtrUInt(stream^.Field20 - $4000));
                if v1 > remaining_size then
                  v1 := remaining_size;
                Move(stream^.Field20^, p^, v1);
                Inc(p, v1);
                Dec(remaining_size, v1);
                Inc(stream^.Field20, v1);
                Dec(stream^.Field10, v1);
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  Result := elements_read;
end;

function db_fgetc(stream: PDB_FILE): Integer;
var
  ch, next_ch: Integer;
begin
  ch := -1;

  if stream <> nil then
  begin
    if (stream^.Flags and $4) <> 0 then
      ch := libc_fgetc(GetFileStream(stream))
    else
    begin
      case stream^.Flags and $F0 of
        16:
        begin
          if stream^.Field10 <> 0 then
          begin
            ch := stream^.Field20^;
            Inc(stream^.Field20);
            Dec(stream^.Field10);

            if (stream^.Field10 <> 0) and ((stream^.Flags and $2) <> 0) and (ch = 13) then
            begin
              next_ch := stream^.Field20^;
              if next_ch = 10 then
              begin
                Inc(stream^.Field20);
                Dec(stream^.Field10);
                ch := 10;
              end;
            end;
          end;
        end;
        32:
        begin
          if stream^.Field10 <> 0 then
          begin
            if libc_fseek(stream^.Database^.Stream, stream^.Field18, SEEK_SET) = 0 then
            begin
              ch := libc_fgetc(stream^.Database^.Stream);
              Dec(stream^.Field10);

              if (stream^.Field10 <> 0) and ((stream^.Flags and $2) <> 0) and (ch = 13) then
              begin
                next_ch := libc_fgetc(stream^.Database^.Stream);
                if next_ch = 10 then
                begin
                  Dec(stream^.Field10);
                  ch := 10;
                end
                else
                  libc_ungetc(next_ch, stream^.Database^.Stream);
              end;
              stream^.Field18 := Integer(libc_ftell(stream^.Database^.Stream));
            end;
          end;
        end;
        64:
        begin
          db_preload_buffer(stream);
          if stream^.Field10 <> 0 then
          begin
            ch := stream^.Field20^;
            Inc(stream^.Field20);
            Dec(stream^.Field10);

            if (stream^.Field10 <> 0) and ((stream^.Flags and $2) <> 0) and (ch = 13) then
            begin
              next_ch := stream^.Field20^;
              if next_ch = 10 then
              begin
                Inc(stream^.Field20);
                Dec(stream^.Field10);
                ch := 10;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  if read_callback <> nil then
  begin
    Inc(read_count);
    if read_count >= read_threshold then
    begin
      read_callback();
      read_count := 0;
    end;
  end;

  Result := ch;
end;

function db_ungetc(ch: Integer; stream: PDB_FILE): Integer;
begin
  if stream <> nil then
  begin
    if (stream^.Flags and $4) <> 0 then
      Exit(libc_ungetc(ch, GetFileStream(stream)))
    else
    begin
      case stream^.Flags and $F0 of
        16:
          if stream^.Field20 <> stream^.Field1C then
          begin
            Dec(stream^.Field20);
            Inc(stream^.Field10);
          end;
        32:
          if stream^.Field18 <> stream^.Field14 then
          begin
            if libc_fseek(stream^.Database^.Stream, stream^.Field18, SEEK_SET) = 0 then
              if libc_fseek(stream^.Database^.Stream, -1, SEEK_CUR) = 0 then
              begin
                stream^.Field18 := Integer(libc_ftell(stream^.Database^.Stream));
                Inc(stream^.Field10);
              end;
          end;
        64:
          if stream^.Field20 <> stream^.Field1C then
          begin
            Dec(stream^.Field20);
            Inc(stream^.Field10);
          end;
      end;
    end;
  end;
  Result := ch;
end;

function db_fgets(str: PAnsiChar; size: SizeUInt; stream: PDB_FILE): PAnsiChar;
var
  index: SizeUInt;
  ch: Integer;
begin
  Result := nil;
  if stream = nil then Exit;

  if (stream^.Flags and $4) <> 0 then
    Result := libc_fgets(str, Integer(size), GetFileStream(stream))
  else
  begin
    if str = nil then Exit;
    index := 0;
    while index < size - 1 do
    begin
      ch := db_fgetc(stream);
      if ch = -1 then Break;
      str[index] := AnsiChar(ch);
      if ch = 10 then
      begin
        Inc(index);
        Break;
      end;
      Inc(index);
    end;
    str[index] := #0;
    if index <> 0 then
      Result := str;
  end;
end;

function db_fwrite(const buf: Pointer; size, count: SizeUInt; stream: PDB_FILE): SizeUInt;
begin
  if (stream <> nil) and ((stream^.Flags and $4) <> 0) then
    Result := libc_fwrite(buf, size, count, GetFileStream(stream))
  else
    Result := count - 1;
end;

function db_fputc(ch: Integer; stream: PDB_FILE): Integer;
begin
  if (stream <> nil) and ((stream^.Flags and $4) <> 0) then
    Result := libc_fputc(ch, GetFileStream(stream))
  else
    Result := -1;
end;

function db_fputs(const s: PAnsiChar; stream: PDB_FILE): Integer;
begin
  if (stream <> nil) and ((stream^.Flags and $4) <> 0) then
    Result := libc_fputs(s, GetFileStream(stream))
  else
    Result := -1;
end;

function db_fseek(stream: PDB_FILE; offset: LongInt; origin: Integer): Integer;
var
  current_offset: LongInt;
  v1: PByte;
  chunks: Integer;
begin
  Result := -1;
  if stream = nil then Exit;

  if (stream^.Flags and $4) <> 0 then
    Result := libc_fseek(GetFileStream(stream), offset, origin)
  else
  begin
    current_offset := db_ftell(stream);

    case origin of
      SEEK_SET: ; // offset stays
      SEEK_CUR: offset := offset + current_offset;
      SEEK_END: offset := offset + stream^.FieldC;
    else
      offset := -1;
    end;

    if (offset < 0) or (offset > stream^.FieldC) then Exit(-1);

    case stream^.Flags and $F0 of
      16:
      begin
        stream^.Field20 := stream^.Field1C + offset;
        stream^.Field10 := stream^.FieldC - Integer(offset);
        Result := 0;
      end;
      32:
      begin
        if libc_fseek(stream^.Database^.Stream, stream^.Field14 + Integer(offset), SEEK_SET) = 0 then
        begin
          stream^.Field18 := Integer(libc_ftell(stream^.Database^.Stream));
          stream^.Field10 := stream^.FieldC - Integer(offset);
          Result := 0;
        end;
      end;
      64:
      begin
        v1 := stream^.Field20 + (offset - current_offset);
        if (PtrUInt(v1) >= PtrUInt(stream^.Field1C)) and
           (PtrUInt(v1) < PtrUInt(stream^.Field1C) + $4000) then
        begin
          // Target is within current decompressed buffer
          stream^.Field20 := v1;
          stream^.Field10 := stream^.FieldC - Integer(offset);
          Result := 0;
        end
        else
        begin
          if offset < current_offset then
          begin
            // Seeking backward: must rewind and decompress forward
            db_rewind(stream);
            chunks := offset div $4000;
          end
          else
          begin
            // Seeking forward past current buffer: skip remaining bytes
            stream^.Field10 := stream^.Field10 -
              Integer(PtrUInt(stream^.Field1C) + $4000 - PtrUInt(stream^.Field20));
            stream^.Field20 := stream^.Field1C + $4000;
            db_preload_buffer(stream);
            chunks := (offset - db_ftell(stream)) div $4000;
          end;

          // Skip whole chunks
          while chunks > 0 do
          begin
            stream^.Field10 := stream^.Field10 - $4000;
            stream^.Field20 := stream^.Field1C + $4000;
            db_preload_buffer(stream);
            Dec(chunks);
          end;

          // Handle remaining offset within the final chunk
          if (offset mod $4000) <> 0 then
          begin
            stream^.Field10 := stream^.Field10 - (offset mod $4000);
            stream^.Field20 := stream^.Field20 + (offset mod $4000);
          end;

          // Set final remaining count
          stream^.Field10 := stream^.FieldC - Integer(offset);
        end;
      end;
    end;
  end;
end;

function db_ftell(stream: PDB_FILE): LongInt;
begin
  if stream = nil then Exit(-1);

  if (stream^.Flags and $4) <> 0 then
    Result := LongInt(libc_ftell(GetFileStream(stream)))
  else
  begin
    case stream^.Flags and $F0 of
      16, 32, 64: Result := stream^.FieldC - stream^.Field10;
    else
      Result := -1;
    end;
  end;
end;

procedure db_rewind(stream: PDB_FILE);
begin
  if stream = nil then Exit;

  if (stream^.Flags and $4) <> 0 then
    libc_rewind(GetFileStream(stream))
  else
  begin
    case stream^.Flags and $F0 of
      16:
      begin
        stream^.Field10 := stream^.FieldC;
        stream^.Field20 := stream^.Field1C;
      end;
      32:
      begin
        stream^.Field18 := stream^.Field14;
        stream^.Field10 := stream^.FieldC;
      end;
      64:
      begin
        stream^.Field10 := stream^.FieldC;
        stream^.Field20 := stream^.Field1C + 16384;
        stream^.Field18 := stream^.Field14;
        db_preload_buffer(stream);
      end;
    end;
  end;
end;

// Big-endian read/write via db_fgetc/db_fputc

function db_freadByte(stream: PDB_FILE; c: PByte): Integer;
var
  value: Integer;
begin
  value := db_fgetc(stream);
  if value = -1 then Exit(-1);
  c^ := Byte(value and $FF);
  Result := 0;
end;

function db_freadShort(stream: PDB_FILE; s: PWord): Integer;
var
  high_, low_: Byte;
begin
  if db_freadByte(stream, @high_) = -1 then Exit(-1);
  if db_freadByte(stream, @low_) = -1 then Exit(-1);
  s^ := Word((high_ shl 8) or low_);
  Result := 0;
end;

function db_freadInt(stream: PDB_FILE; i: PInteger): Integer;
var
  high_, low_: Word;
begin
  if db_freadShort(stream, @high_) = -1 then Exit(-1);
  if db_freadShort(stream, @low_) = -1 then Exit(-1);
  i^ := Integer((LongWord(high_) shl 16) or low_);
  Result := 0;
end;

function db_freadLong(stream: PDB_FILE; l: PLongWord): Integer;
var
  i: Integer;
begin
  if db_freadInt(stream, @i) = -1 then Exit(-1);
  l^ := LongWord(i);
  Result := 0;
end;

function db_freadFloat(stream: PDB_FILE; q: PSingle): Integer;
var
  l: LongWord;
begin
  if db_freadLong(stream, @l) = -1 then Exit(-1);
  Move(l, q^, SizeOf(Single));
  Result := 0;
end;

function db_fwriteByte(stream: PDB_FILE; c: Byte): Integer;
begin
  if db_fputc(Integer(c), stream) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteShort(stream: PDB_FILE; s: Word): Integer;
begin
  if db_fwriteByte(stream, Byte(s shr 8)) = -1 then Exit(-1);
  if db_fwriteByte(stream, Byte(s and $FF)) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteInt(stream: PDB_FILE; i: Integer): Integer;
begin
  if db_fwriteShort(stream, Word(LongWord(i) shr 16)) = -1 then Exit(-1);
  if db_fwriteShort(stream, Word(i and $FFFF)) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteLong(stream: PDB_FILE; l: LongWord): Integer;
begin
  Result := db_fwriteInt(stream, Integer(l));
end;

function db_fwriteFloat(stream: PDB_FILE; q: Single): Integer;
var
  l: LongWord;
begin
  Move(q, l, SizeOf(Single));
  Result := db_fwriteLong(stream, l);
end;

// Count variants
function db_freadByteCount(stream: PDB_FILE; c: PByte; count: Integer): Integer;
var
  index: Integer;
  value: Byte;
begin
  for index := 0 to count - 1 do
  begin
    if db_freadByte(stream, @value) = -1 then Exit(-1);
    c[index] := value;
  end;
  Result := 0;
end;

function db_freadShortCount(stream: PDB_FILE; s: PWord; count: Integer): Integer;
var
  index: Integer;
  value: Word;
begin
  for index := 0 to count - 1 do
  begin
    if db_freadShort(stream, @value) = -1 then Exit(-1);
    PWord(PByte(s) + index * SizeOf(Word))^ := value;
  end;
  Result := 0;
end;

function db_freadIntCount(stream: PDB_FILE; i: PInteger; count: Integer): Integer;
var
  index, value: Integer;
begin
  for index := 0 to count - 1 do
  begin
    if db_freadInt(stream, @value) = -1 then Exit(-1);
    PInteger(PByte(i) + index * SizeOf(Integer))^ := value;
  end;
  Result := 0;
end;

function db_freadLongCount(stream: PDB_FILE; l: PLongWord; count: Integer): Integer;
var
  index: Integer;
  value: LongWord;
begin
  for index := 0 to count - 1 do
  begin
    if db_freadLong(stream, @value) = -1 then Exit(-1);
    PLongWord(PByte(l) + index * SizeOf(LongWord))^ := value;
  end;
  Result := 0;
end;

function db_freadFloatCount(stream: PDB_FILE; q: PSingle; count: Integer): Integer;
var
  index: Integer;
  value: Single;
begin
  for index := 0 to count - 1 do
  begin
    if db_freadFloat(stream, @value) = -1 then Exit(-1);
    PSingle(PByte(q) + index * SizeOf(Single))^ := value;
  end;
  Result := 0;
end;

function db_fwriteByteCount(stream: PDB_FILE; c: PByte; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteByte(stream, c[index]) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteShortCount(stream: PDB_FILE; s: PWord; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteShort(stream, PWord(PByte(s) + index * SizeOf(Word))^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteIntCount(stream: PDB_FILE; i: PInteger; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteInt(stream, PInteger(PByte(i) + index * SizeOf(Integer))^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteLongCount(stream: PDB_FILE; l: PLongWord; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteLong(stream, PLongWord(PByte(l) + index * SizeOf(LongWord))^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteFloatCount(stream: PDB_FILE; q: PSingle; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteFloat(stream, PSingle(PByte(q) + index * SizeOf(Single))^) = -1 then Exit(-1);
  Result := 0;
end;

function db_feof(stream: PDB_FILE): Integer;
begin
  if stream = nil then Exit(-1);
  if (stream^.Flags and $4) <> 0 then
    Result := libc_feof(GetFileStream(stream))
  else
  begin
    case stream^.Flags and $F0 of
      16, 32, 64:
        if stream^.Field10 = 0 then Result := 1
        else Result := 0;
    else
      Result := -1;
    end;
  end;
end;

function db_filelength(stream: PDB_FILE): LongInt;
begin
  if stream = nil then Exit(-1);
  if (stream^.Flags and $4) <> 0 then
    Result := getFileSize(GetFileStream(stream))
  else
    Result := stream^.FieldC;
end;

procedure db_register_mem(malloc_func: TDbMallocFunc; strdup_func: TDbStrdupFunc; free_func: TDbFreeFunc);
begin
  if not db_used_malloc then
  begin
    if (malloc_func <> nil) and (strdup_func <> nil) and (free_func <> nil) then
    begin
      db_malloc := malloc_func;
      db_strdup := strdup_func;
      db_free := free_func;
    end
    else
    begin
      db_malloc := @db_default_malloc;
      db_strdup := @db_default_strdup;
      db_free := @db_default_free;
    end;
  end;
end;

procedure db_register_callback(callback: TDbReadCallback; threshold: SizeUInt);
begin
  if (callback <> nil) and (threshold <> 0) then
  begin
    read_callback := callback;
    read_threshold := threshold;
  end
  else
  begin
    read_callback := nil;
    read_threshold := 0;
  end;
end;

procedure db_enable_hash_table;
begin
  hash_is_on := True;
end;

function db_reset_hash_tables: Integer;
begin
  // TODO: Full implementation
  if not hash_is_on then Exit(-1);
  Result := 0;
end;

function db_add_hash_entry(const path: PAnsiChar; sep: Integer): Integer;
begin
  // TODO: Full implementation
  if not hash_is_on then Exit(-1);
  if current_database = nil then Exit(-1);
  Result := 0;
end;

function db_get_file_list(const filespec: PAnsiChar; filelist: PPPAnsiChar; desclist: PPPAnsiChar; desclen: Integer): Integer;
begin
  // TODO: Full implementation — requires directory enumeration in DAT files
  if filelist <> nil then
    filelist^ := nil;
  if desclist <> nil then
    desclist^ := nil;
  Result := 0;
end;

procedure db_free_file_list(file_list: PPPAnsiChar; desclist: PPPAnsiChar);
var
  list: PPAnsiChar;
  i: Integer;
begin
  if (file_list <> nil) and (file_list^ <> nil) then
  begin
    list := file_list^;
    i := 0;
    while list[i] <> nil do
    begin
      internal_free(list[i]);
      Inc(i);
    end;
    internal_free(list);
    file_list^ := nil;
  end;

  if (desclist <> nil) and (desclist^ <> nil) then
  begin
    internal_free(desclist^);
    desclist^ := nil;
  end;
end;

// Typed read/write helpers

function db_freadUInt8(stream: PDB_FILE; valuePtr: PByte): Integer;
var
  value: Integer;
begin
  value := db_fgetc(stream);
  if value = -1 then Exit(-1);
  valuePtr^ := Byte(value);
  Result := 0;
end;

function db_freadInt8(stream: PDB_FILE; valuePtr: PShortInt): Integer;
var
  value: Byte;
begin
  if db_freadUInt8(stream, @value) = -1 then Exit(-1);
  valuePtr^ := ShortInt(value);
  Result := 0;
end;

function db_freadUInt16(stream: PDB_FILE; valuePtr: PWord): Integer;
begin
  Result := db_freadShort(stream, valuePtr);
end;

function db_freadInt16(stream: PDB_FILE; valuePtr: PSmallInt): Integer;
var
  value: Word;
begin
  if db_freadUInt16(stream, @value) = -1 then Exit(-1);
  valuePtr^ := SmallInt(value);
  Result := 0;
end;

function db_freadUInt32(stream: PDB_FILE; valuePtr: PLongWord): Integer;
var
  value: Integer;
begin
  if db_freadInt(stream, @value) = -1 then Exit(-1);
  valuePtr^ := LongWord(value);
  Result := 0;
end;

function db_freadInt32(stream: PDB_FILE; valuePtr: PInteger): Integer;
var
  value: LongWord;
begin
  if db_freadUInt32(stream, @value) = -1 then Exit(-1);
  valuePtr^ := Integer(value);
  Result := 0;
end;

function db_freadUInt8List(stream: PDB_FILE; arr: PByte; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_freadUInt8(stream, @arr[index]) = -1 then Exit(-1);
  Result := 0;
end;

function db_freadInt8List(stream: PDB_FILE; arr: PShortInt; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_freadInt8(stream, @PShortInt(PByte(arr) + index)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_freadInt16List(stream: PDB_FILE; arr: PSmallInt; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_freadInt16(stream, @PSmallInt(PByte(arr) + index * 2)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_freadInt32List(stream: PDB_FILE; arr: PInteger; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_freadInt32(stream, @PInteger(PByte(arr) + index * 4)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_freadBool(stream: PDB_FILE; valuePtr: PBoolean): Integer;
var
  value: Integer;
begin
  if db_freadInt32(stream, @value) = -1 then Exit(-1);
  valuePtr^ := value <> 0;
  Result := 0;
end;

function db_fwriteUInt8(stream: PDB_FILE; value: Byte): Integer;
begin
  Result := db_fputc(Integer(value), stream);
end;

function db_fwriteInt8(stream: PDB_FILE; value: ShortInt): Integer;
begin
  Result := db_fwriteUInt8(stream, Byte(value));
end;

function db_fwriteUInt16(stream: PDB_FILE; value: Word): Integer;
begin
  Result := db_fwriteShort(stream, value);
end;

function db_fwriteInt16(stream: PDB_FILE; value: SmallInt): Integer;
begin
  Result := db_fwriteUInt16(stream, Word(value));
end;

function db_fwriteUInt32(stream: PDB_FILE; value: LongWord): Integer;
begin
  Result := db_fwriteInt(stream, Integer(value));
end;

function db_fwriteInt32(stream: PDB_FILE; value: Integer): Integer;
begin
  Result := db_fwriteUInt32(stream, LongWord(value));
end;

function db_fwriteUInt8List(stream: PDB_FILE; arr: PByte; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteUInt8(stream, arr[index]) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteInt8List(stream: PDB_FILE; arr: PShortInt; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteInt8(stream, PShortInt(PByte(arr) + index)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteInt16List(stream: PDB_FILE; arr: PSmallInt; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteInt16(stream, PSmallInt(PByte(arr) + index * 2)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteInt32List(stream: PDB_FILE; arr: PInteger; count: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    if db_fwriteInt32(stream, PInteger(PByte(arr) + index * 4)^) = -1 then Exit(-1);
  Result := 0;
end;

function db_fwriteBool(stream: PDB_FILE; value: Boolean): Integer;
begin
  if value then
    Result := db_fwriteInt32(stream, 1)
  else
    Result := db_fwriteInt32(stream, 0);
end;

initialization
  FillByte(database_list, SizeOf(database_list), 0);

end.
