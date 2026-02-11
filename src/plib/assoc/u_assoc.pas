unit u_assoc;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from assoc.h + assoc.cc
// A sorted key-value dictionary with string keys.
// Keys are always strings; values are copied by size (DataSize).
// Internally pairs are kept sorted by key (case-insensitive).

interface

uses
  SysUtils;

type
  TAssocMallocFunc = function(Size: SizeUInt): Pointer; cdecl;
  TAssocReallocFunc = function(Ptr: Pointer; NewSize: SizeUInt): Pointer; cdecl;
  TAssocFreeFunc = procedure(Ptr: Pointer); cdecl;
  TAssocLoadFunc = function(Stream: Pointer; Buffer: Pointer; Size: SizeUInt; Flags: Integer): Integer; cdecl;
  TAssocSaveFunc = function(Stream: Pointer; Buffer: Pointer; Size: SizeUInt; Flags: Integer): Integer; cdecl;
  // DB_FILE variant - same signature since DB_FILE* is just a pointer
  TAssocLoadFuncDB = function(Stream: Pointer; Buffer: Pointer; Size: SizeUInt; Flags: Integer): Integer; cdecl;
  TAssocSaveFuncDB = function(Stream: Pointer; Buffer: Pointer; Size: SizeUInt; Flags: Integer): Integer; cdecl;

  PAssocFuncList = ^TAssocFuncList;
  TAssocFuncList = record
    LoadFunc: TAssocLoadFunc;
    SaveFunc: TAssocSaveFunc;
    LoadFuncDB: TAssocLoadFuncDB;
    SaveFuncDB: TAssocSaveFuncDB;
    NewLoadFunc: TAssocLoadFunc;
  end;

  PAssocPair = ^TAssocPair;
  TAssocPair = record
    Name: PAnsiChar;
    Data: Pointer;
  end;

  PAssocArray = ^TAssocArray;
  TAssocArray = record
    InitFlag: Integer;
    Size: Integer;
    Max: Integer;
    DataSize: SizeUInt;
    LoadSaveFuncs: TAssocFuncList;
    List: PAssocPair;
  end;

function assoc_init(A: PAssocArray; N: Integer; DataSize: SizeUInt; AssocFuncs: PAssocFuncList): Integer;
function assoc_resize(A: PAssocArray; N: Integer): Integer;
function assoc_free(A: PAssocArray): Integer;
function assoc_search(A: PAssocArray; const Name: PAnsiChar): Integer;
function assoc_insert(A: PAssocArray; const Name: PAnsiChar; const Data: Pointer): Integer;
function assoc_delete(A: PAssocArray; const Name: PAnsiChar): Integer;
function assoc_copy(Dst, Src: PAssocArray): Integer;
function assoc_load(FP: Pointer; A: PAssocArray; Flags: Integer): Integer;
function assoc_save(FP: Pointer; A: PAssocArray; Flags: Integer): Integer;
procedure assoc_register_mem(MallocFunc: TAssocMallocFunc; ReallocFunc: TAssocReallocFunc; FreeFunc: TAssocFreeFunc);

implementation

const
  DICTIONARY_MARKER = $FEBAFEBA;

// ---------------------------------------------------------------------------
// libc FILE* functions imported from C library for assoc_load / assoc_save
// ---------------------------------------------------------------------------
function fgetc(Stream: Pointer): Integer; cdecl; external 'c';
function fgets(S: PAnsiChar; N: Integer; Stream: Pointer): PAnsiChar; cdecl; external 'c';
function fread(Buffer: Pointer; Size: SizeUInt; Count: SizeUInt; Stream: Pointer): SizeUInt; cdecl; external 'c';
function fwrite(Buffer: Pointer; Size: SizeUInt; Count: SizeUInt; Stream: Pointer): SizeUInt; cdecl; external 'c';
function fputc(C: Integer; Stream: Pointer): Integer; cdecl; external 'c';
function fputs(S: PAnsiChar; Stream: Pointer): Integer; cdecl; external 'c';

// ---------------------------------------------------------------------------
// Internal memory function pointers
// ---------------------------------------------------------------------------
var
  internal_malloc: TAssocMallocFunc = nil;
  internal_realloc: TAssocReallocFunc = nil;
  internal_free: TAssocFreeFunc = nil;

// ---------------------------------------------------------------------------
// Default memory functions (wrappers around FreePascal heap)
// ---------------------------------------------------------------------------
function default_malloc(Size: SizeUInt): Pointer; cdecl;
begin
  Result := GetMem(Size);
end;

function default_realloc(Ptr: Pointer; NewSize: SizeUInt): Pointer; cdecl;
begin
  Result := ReallocMem(Ptr, NewSize);
end;

procedure default_free(Ptr: Pointer); cdecl;
begin
  FreeMem(Ptr);
end;

// ---------------------------------------------------------------------------
// Helper: access the I-th element of the PAssocPair array via pointer
// arithmetic, since PAssocPair is not a true Pascal dynamic array.
// ---------------------------------------------------------------------------
function GetPair(List: PAssocPair; I: Integer): PAssocPair; inline;
begin
  Result := PAssocPair(PByte(List) + I * SizeOf(TAssocPair));
end;

// ---------------------------------------------------------------------------
// Case-insensitive string comparison (matching compat_stricmp)
// ---------------------------------------------------------------------------
function compat_stricmp(const A, B: PAnsiChar): Integer;
begin
  // SysUtils.CompareText performs case-insensitive comparison and returns
  // <0, 0, or >0 just like stricmp.
  Result := SysUtils.CompareText(AnsiString(A), AnsiString(B));
end;

// ---------------------------------------------------------------------------
// assoc_find -- binary search for a key
//
// Returns 0 if key is found (Position = index of found entry).
// Returns -1 if not found (Position = insertion point).
// ---------------------------------------------------------------------------
function assoc_find(A: PAssocArray; const Name: PAnsiChar; out Position: Integer): Integer;
var
  L, R, Mid, Cmp: Integer;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if A^.Size = 0 then
  begin
    Position := 0;
    Result := -1;
    Exit;
  end;

  L := 0;
  R := A^.Size - 1;
  Mid := 0;
  Cmp := 0;

  while R >= L do
  begin
    Mid := (L + R) div 2;
    Cmp := compat_stricmp(Name, GetPair(A^.List, Mid)^.Name);
    if Cmp = 0 then
      Break;

    if Cmp > 0 then
      L := L + 1
    else
      R := R - 1;
  end;

  if Cmp = 0 then
  begin
    Position := Mid;
    Result := 0;
    Exit;
  end;

  if Cmp < 0 then
    Position := Mid
  else
    Position := Mid + 1;

  Result := -1;
end;

// ---------------------------------------------------------------------------
// assoc_read_long -- reads a big-endian 32-bit value from a FILE*
// ---------------------------------------------------------------------------
function assoc_read_long(FP: Pointer; out TheLong: LongInt): Integer;
var
  C, Temp: Integer;
begin
  C := fgetc(FP);
  if C = -1 then begin Result := -1; Exit; end;
  Temp := C and $FF;

  C := fgetc(FP);
  if C = -1 then begin Result := -1; Exit; end;
  Temp := (Temp shl 8) or (C and $FF);

  C := fgetc(FP);
  if C = -1 then begin Result := -1; Exit; end;
  Temp := (Temp shl 8) or (C and $FF);

  C := fgetc(FP);
  if C = -1 then begin Result := -1; Exit; end;
  Temp := (Temp shl 8) or (C and $FF);

  TheLong := Temp;
  Result := 0;
end;

// ---------------------------------------------------------------------------
// assoc_read_assoc_array -- reads array header fields from a FILE*
// ---------------------------------------------------------------------------
function assoc_read_assoc_array(FP: Pointer; A: PAssocArray): Integer;
var
  Temp: LongInt;
begin
  if assoc_read_long(FP, Temp) <> 0 then begin Result := -1; Exit; end;
  A^.Size := Temp;

  if assoc_read_long(FP, Temp) <> 0 then begin Result := -1; Exit; end;
  A^.Max := Temp;

  if assoc_read_long(FP, Temp) <> 0 then begin Result := -1; Exit; end;
  A^.DataSize := SizeUInt(Temp);

  // NOTE: original code reads `a->list` pointer which is meaningless.
  if assoc_read_long(FP, Temp) <> 0 then begin Result := -1; Exit; end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// assoc_write_long -- writes a big-endian 32-bit value to a FILE*
// ---------------------------------------------------------------------------
function assoc_write_long(FP: Pointer; TheLong: LongInt): Integer;
begin
  if fputc((TheLong shr 24) and $FF, FP) = -1 then begin Result := -1; Exit; end;
  if fputc((TheLong shr 16) and $FF, FP) = -1 then begin Result := -1; Exit; end;
  if fputc((TheLong shr 8) and $FF, FP) = -1 then begin Result := -1; Exit; end;
  if fputc(TheLong and $FF, FP) = -1 then begin Result := -1; Exit; end;
  Result := 0;
end;

// ---------------------------------------------------------------------------
// assoc_write_assoc_array -- writes array header fields to a FILE*
// ---------------------------------------------------------------------------
function assoc_write_assoc_array(FP: Pointer; A: PAssocArray): Integer;
begin
  if assoc_write_long(FP, A^.Size) <> 0 then begin Result := -1; Exit; end;
  if assoc_write_long(FP, A^.Max) <> 0 then begin Result := -1; Exit; end;
  if assoc_write_long(FP, LongInt(A^.DataSize)) <> 0 then begin Result := -1; Exit; end;
  // NOTE: Original code writes `a->list` pointer which is meaningless.
  if assoc_write_long(FP, 0) <> 0 then begin Result := -1; Exit; end;
  Result := 0;
end;

// ===========================================================================
// Public API
// ===========================================================================

function assoc_init(A: PAssocArray; N: Integer; DataSize: SizeUInt; AssocFuncs: PAssocFuncList): Integer;
var
  RC: Integer;
begin
  A^.Max := N;
  A^.DataSize := DataSize;
  A^.Size := 0;

  if AssocFuncs <> nil then
  begin
    A^.LoadSaveFuncs := AssocFuncs^;
  end
  else
  begin
    A^.LoadSaveFuncs.LoadFunc := nil;
    A^.LoadSaveFuncs.SaveFunc := nil;
    A^.LoadSaveFuncs.LoadFuncDB := nil;
    A^.LoadSaveFuncs.SaveFuncDB := nil;
    A^.LoadSaveFuncs.NewLoadFunc := nil;
  end;

  RC := 0;

  if N <> 0 then
  begin
    A^.List := PAssocPair(internal_malloc(SizeUInt(SizeOf(TAssocPair)) * SizeUInt(N)));
    if A^.List = nil then
      RC := -1;
  end
  else
  begin
    A^.List := nil;
  end;

  if RC <> -1 then
    A^.InitFlag := Integer(DICTIONARY_MARKER);

  Result := RC;
end;

function assoc_resize(A: PAssocArray; N: Integer): Integer;
var
  Entries: PAssocPair;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if N < A^.Size then
  begin
    Result := -1;
    Exit;
  end;

  Entries := PAssocPair(internal_realloc(A^.List, SizeUInt(SizeOf(TAssocPair)) * SizeUInt(N)));
  if Entries = nil then
  begin
    Result := -1;
    Exit;
  end;

  A^.Max := N;
  A^.List := Entries;
  Result := 0;
end;

function assoc_free(A: PAssocArray): Integer;
var
  Index: Integer;
  Entry: PAssocPair;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  for Index := 0 to A^.Size - 1 do
  begin
    Entry := GetPair(A^.List, Index);
    if Entry^.Name <> nil then
      internal_free(Entry^.Name);
    if Entry^.Data <> nil then
      internal_free(Entry^.Data);
  end;

  if A^.List <> nil then
    internal_free(A^.List);

  FillChar(A^, SizeOf(TAssocArray), 0);
  Result := 0;
end;

function assoc_search(A: PAssocArray; const Name: PAnsiChar): Integer;
var
  Index: Integer;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if assoc_find(A, Name, Index) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := Index;
end;

function assoc_insert(A: PAssocArray; const Name: PAnsiChar; const Data: Pointer): Integer;
var
  NewElementIndex: Integer;
  KeyCopy: PAnsiChar;
  ValueCopy: Pointer;
  KeyLen: SizeUInt;
  Index: Integer;
  Src, Dest: PAssocPair;
  Entry: PAssocPair;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if assoc_find(A, Name, NewElementIndex) = 0 then
  begin
    // Element for this key already exists.
    Result := -1;
    Exit;
  end;

  if A^.Size = A^.Max then
  begin
    // Assoc array reached its capacity and needs to be enlarged.
    if assoc_resize(A, 2 * (A^.Max + 1)) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  // Make a copy of the key.
  KeyLen := StrLen(Name);
  KeyCopy := PAnsiChar(internal_malloc(KeyLen + 1));
  if KeyCopy = nil then
  begin
    Result := -1;
    Exit;
  end;
  StrCopy(KeyCopy, Name);

  // Make a copy of the value.
  ValueCopy := nil;
  if (Data <> nil) and (A^.DataSize <> 0) then
  begin
    ValueCopy := internal_malloc(A^.DataSize);
    if ValueCopy = nil then
    begin
      internal_free(KeyCopy);
      Result := -1;
      Exit;
    end;
  end;

  if (ValueCopy <> nil) and (A^.DataSize <> 0) then
    Move(Data^, ValueCopy^, A^.DataSize);

  // Starting at the end of entries array, loop backwards and move entries down
  // one by one until we reach the insertion point.
  for Index := A^.Size downto NewElementIndex + 1 do
  begin
    Src := GetPair(A^.List, Index - 1);
    Dest := GetPair(A^.List, Index);
    Move(Src^, Dest^, SizeOf(TAssocPair));
  end;

  Entry := GetPair(A^.List, NewElementIndex);
  Entry^.Name := KeyCopy;
  Entry^.Data := ValueCopy;

  Inc(A^.Size);
  Result := 0;
end;

function assoc_delete(A: PAssocArray; const Name: PAnsiChar): Integer;
var
  IndexToRemove: Integer;
  Entry: PAssocPair;
  Index: Integer;
  Src, Dest: PAssocPair;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if assoc_find(A, Name, IndexToRemove) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Entry := GetPair(A^.List, IndexToRemove);

  // Free key and value (which are copies).
  internal_free(Entry^.Name);
  if Entry^.Data <> nil then
    internal_free(Entry^.Data);

  Dec(A^.Size);

  // Starting from the index of the entry we just removed, loop through the
  // remaining array and move entries up one by one.
  for Index := IndexToRemove to A^.Size - 1 do
  begin
    Src := GetPair(A^.List, Index + 1);
    Dest := GetPair(A^.List, Index);
    Move(Src^, Dest^, SizeOf(TAssocPair));
  end;

  Result := 0;
end;

function assoc_copy(Dst, Src: PAssocArray): Integer;
var
  Index: Integer;
  Entry: PAssocPair;
begin
  if Src^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if assoc_init(Dst, Src^.Max, Src^.DataSize, @Src^.LoadSaveFuncs) <> 0 then
  begin
    // FIXME: Should return -1, as we were unable to initialize dictionary.
    Result := 0;
    Exit;
  end;

  for Index := 0 to Src^.Size - 1 do
  begin
    Entry := GetPair(Src^.List, Index);
    if assoc_insert(Dst, Entry^.Name, Entry^.Data) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

function assoc_load(FP: Pointer; A: PAssocArray; Flags: Integer): Integer;
var
  Index: Integer;
  Entry: PAssocPair;
  KeyLength: Integer;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  // Free existing entries.
  for Index := 0 to A^.Size - 1 do
  begin
    Entry := GetPair(A^.List, Index);
    if Entry^.Name <> nil then
      internal_free(Entry^.Name);
    if Entry^.Data <> nil then
      internal_free(Entry^.Data);
  end;

  if A^.List <> nil then
    internal_free(A^.List);

  if assoc_read_assoc_array(FP, A) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  A^.List := nil;

  if A^.Max <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  A^.List := PAssocPair(internal_malloc(SizeUInt(SizeOf(TAssocPair)) * SizeUInt(A^.Max)));
  if A^.List = nil then
  begin
    Result := -1;
    Exit;
  end;

  // Initialize entries to nil.
  for Index := 0 to A^.Size - 1 do
  begin
    Entry := GetPair(A^.List, Index);
    Entry^.Name := nil;
    Entry^.Data := nil;
  end;

  if A^.Size <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  for Index := 0 to A^.Size - 1 do
  begin
    Entry := GetPair(A^.List, Index);

    KeyLength := fgetc(FP);
    if KeyLength = -1 then
    begin
      Result := -1;
      Exit;
    end;

    Entry^.Name := PAnsiChar(internal_malloc(SizeUInt(KeyLength + 1)));
    if Entry^.Name = nil then
    begin
      Result := -1;
      Exit;
    end;

    if fgets(Entry^.Name, KeyLength + 1, FP) = nil then
    begin
      Result := -1;
      Exit;
    end;

    if A^.DataSize <> 0 then
    begin
      Entry^.Data := internal_malloc(A^.DataSize);
      if Entry^.Data = nil then
      begin
        Result := -1;
        Exit;
      end;

      if A^.LoadSaveFuncs.LoadFunc <> nil then
      begin
        if A^.LoadSaveFuncs.LoadFunc(FP, Entry^.Data, A^.DataSize, Flags) <> 0 then
        begin
          Result := -1;
          Exit;
        end;
      end
      else
      begin
        if fread(Entry^.Data, A^.DataSize, 1, FP) <> 1 then
        begin
          Result := -1;
          Exit;
        end;
      end;
    end;
  end;

  Result := 0;
end;

function assoc_save(FP: Pointer; A: PAssocArray; Flags: Integer): Integer;
var
  Index: Integer;
  Entry: PAssocPair;
  KeyLength: Integer;
begin
  if A^.InitFlag <> Integer(DICTIONARY_MARKER) then
  begin
    Result := -1;
    Exit;
  end;

  if assoc_write_assoc_array(FP, A) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  for Index := 0 to A^.Size - 1 do
  begin
    Entry := GetPair(A^.List, Index);
    KeyLength := StrLen(Entry^.Name);

    if fputc(KeyLength, FP) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if fputs(Entry^.Name, FP) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if A^.LoadSaveFuncs.SaveFunc <> nil then
    begin
      if A^.DataSize <> 0 then
      begin
        if A^.LoadSaveFuncs.SaveFunc(FP, Entry^.Data, A^.DataSize, Flags) <> 0 then
        begin
          Result := -1;
          Exit;
        end;
      end;
    end
    else
    begin
      if A^.DataSize <> 0 then
      begin
        if fwrite(Entry^.Data, A^.DataSize, 1, FP) <> 1 then
        begin
          Result := -1;
          Exit;
        end;
      end;
    end;
  end;

  Result := 0;
end;

procedure assoc_register_mem(MallocFunc: TAssocMallocFunc; ReallocFunc: TAssocReallocFunc; FreeFunc: TAssocFreeFunc);
begin
  if (MallocFunc <> nil) and (ReallocFunc <> nil) and (FreeFunc <> nil) then
  begin
    internal_malloc := MallocFunc;
    internal_realloc := ReallocFunc;
    internal_free := FreeFunc;
  end
  else
  begin
    internal_malloc := @default_malloc;
    internal_realloc := @default_realloc;
    internal_free := @default_free;
  end;
end;

// ===========================================================================
// Unit initialization: set default memory functions
// ===========================================================================
initialization
  internal_malloc := @default_malloc;
  internal_realloc := @default_realloc;
  internal_free := @default_free;

end.
