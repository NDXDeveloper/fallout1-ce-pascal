{$MODE OBJFPC}{$H+}
// Converted from: src/platform/platform_compat.h + platform_compat.cc
// Cross-platform compatibility layer.
unit u_platform_compat;

interface

uses
  SysUtils;

const
  COMPAT_MAX_PATH  = 260;
  COMPAT_MAX_DRIVE = 3;
  COMPAT_MAX_DIR   = 256;
  COMPAT_MAX_FNAME = 256;
  COMPAT_MAX_EXT   = 256;

function compat_stricmp(const S1, S2: PAnsiChar): Integer;
function compat_strnicmp(const S1, S2: PAnsiChar; Size: SizeUInt): Integer;
function compat_strupr(S: PAnsiChar): PAnsiChar;
function compat_strlwr(S: PAnsiChar): PAnsiChar;
function compat_itoa(Value: Integer; Buffer: PAnsiChar; Radix: Integer): PAnsiChar;
procedure compat_splitpath(const Path: PAnsiChar; Drive, Dir, FName, Ext: PAnsiChar);
procedure compat_makepath(Path: PAnsiChar; const Drive, Dir, FName, Ext: PAnsiChar);
function compat_read(FileHandle: Integer; Buf: Pointer; Size: Cardinal): Integer;
function compat_write(FileHandle: Integer; const Buf: Pointer; Size: Cardinal): Integer;
function compat_lseek(FileHandle: Integer; Offset: LongInt; Origin: Integer): LongInt;
function compat_tell(FileHandle: Integer): LongInt;
function compat_filelength(FD: Integer): LongInt;
function compat_mkdir(const Path: PAnsiChar): Integer;
function compat_timeGetTime: Cardinal;
function compat_fopen(const Path, Mode: PAnsiChar): Pointer;
function compat_remove(const Path: PAnsiChar): Integer;
function compat_rename(const OldFileName, NewFileName: PAnsiChar): Integer;
procedure compat_windows_path_to_native(Path: PAnsiChar);
procedure compat_resolve_path(Path: PAnsiChar);
function compat_strdup(const AString: PAnsiChar): PAnsiChar;
function getFileSize(Stream: Pointer): LongInt;

implementation

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  CTypes, u_sdl2;

// libc imports for exact C compatibility
function libc_fopen(Path, Mode: PAnsiChar): Pointer; cdecl; external 'c' name 'fopen';
function libc_fclose(Stream: Pointer): cint; cdecl; external 'c' name 'fclose';
function libc_fseek(Stream: Pointer; Offset: clong; Whence: cint): cint; cdecl; external 'c' name 'fseek';
function libc_ftell(Stream: Pointer): clong; cdecl; external 'c' name 'ftell';
function libc_read(FD: cint; Buf: Pointer; Count: csize_t): clong; cdecl; external 'c' name 'read';
function libc_write(FD: cint; Buf: Pointer; Count: csize_t): clong; cdecl; external 'c' name 'write';
function libc_lseek(FD: cint; Offset: coff_t; Whence: cint): coff_t; cdecl; external 'c' name 'lseek';
function libc_remove(Path: PAnsiChar): cint; cdecl; external 'c' name 'remove';
function libc_rename(OldName, NewName: PAnsiChar): cint; cdecl; external 'c' name 'rename';

const
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;

// Case-insensitive string comparison.
function compat_stricmp(const S1, S2: PAnsiChar): Integer;
var
  P1, P2: PAnsiChar;
  C1, C2: AnsiChar;
begin
  P1 := S1;
  P2 := S2;
  repeat
    C1 := UpCase(P1^);
    C2 := UpCase(P2^);
    if C1 < C2 then
      Exit(-1)
    else if C1 > C2 then
      Exit(1);
    if C1 = #0 then
      Exit(0);
    Inc(P1);
    Inc(P2);
  until False;
  Result := 0;
end;

// Case-insensitive string comparison with length limit.
function compat_strnicmp(const S1, S2: PAnsiChar; Size: SizeUInt): Integer;
var
  P1, P2: PAnsiChar;
  C1, C2: AnsiChar;
  I: SizeUInt;
begin
  P1 := S1;
  P2 := S2;
  for I := 1 to Size do
  begin
    C1 := UpCase(P1^);
    C2 := UpCase(P2^);
    if C1 < C2 then
      Exit(-1)
    else if C1 > C2 then
      Exit(1);
    if C1 = #0 then
      Exit(0);
    Inc(P1);
    Inc(P2);
  end;
  Result := 0;
end;

// Convert string to upper case in place.
function compat_strupr(S: PAnsiChar): PAnsiChar;
var
  P: PAnsiChar;
begin
  Result := S;
  if S = nil then
    Exit;
  P := S;
  while P^ <> #0 do
  begin
    if (P^ >= 'a') and (P^ <= 'z') then
      P^ := AnsiChar(Ord(P^) - Ord('a') + Ord('A'));
    Inc(P);
  end;
end;

// Convert string to lower case in place.
function compat_strlwr(S: PAnsiChar): PAnsiChar;
var
  P: PAnsiChar;
begin
  Result := S;
  if S = nil then
    Exit;
  P := S;
  while P^ <> #0 do
  begin
    if (P^ >= 'A') and (P^ <= 'Z') then
      P^ := AnsiChar(Ord(P^) - Ord('A') + Ord('a'));
    Inc(P);
  end;
end;

// Convert integer to string with given radix.
function compat_itoa(Value: Integer; Buffer: PAnsiChar; Radix: Integer): PAnsiChar;
const
  Digits: array[0..35] of AnsiChar = '0123456789abcdefghijklmnopqrstuvwxyz';
var
  Tmp: array[0..65] of AnsiChar;
  I: Integer;
  Negative: Boolean;
  UVal: Cardinal;
begin
  Result := Buffer;
  if (Radix < 2) or (Radix > 36) then
  begin
    Buffer^ := #0;
    Exit;
  end;

  Negative := False;
  if (Value < 0) and (Radix = 10) then
  begin
    Negative := True;
    UVal := Cardinal(-Value);
  end
  else
    UVal := Cardinal(Value);

  I := 0;
  repeat
    Tmp[I] := Digits[UVal mod Cardinal(Radix)];
    UVal := UVal div Cardinal(Radix);
    Inc(I);
  until UVal = 0;

  if Negative then
  begin
    Tmp[I] := '-';
    Inc(I);
  end;

  // Reverse into buffer
  Dec(I);
  while I >= 0 do
  begin
    Buffer^ := Tmp[I];
    Inc(Buffer);
    Dec(I);
  end;
  Buffer^ := #0;
end;

// Split a file path into its components.
procedure compat_splitpath(const Path: PAnsiChar; Drive, Dir, FName, Ext: PAnsiChar);
var
  S: AnsiString;
  DriveStr, DirStr, NameStr, ExtStr: AnsiString;
  P, LastSep, DotPos: Integer;
begin
  S := StrPas(Path);
  DriveStr := '';
  DirStr := '';
  NameStr := '';
  ExtStr := '';

  // Extract drive (e.g., 'C:')
  if (Length(S) >= 2) and (S[2] = ':') then
  begin
    DriveStr := Copy(S, 1, 2);
    Delete(S, 1, 2);
  end;

  // Find last path separator
  LastSep := 0;
  for P := Length(S) downto 1 do
  begin
    if (S[P] = '/') or (S[P] = '\') then
    begin
      LastSep := P;
      Break;
    end;
  end;

  if LastSep > 0 then
  begin
    DirStr := Copy(S, 1, LastSep);
    S := Copy(S, LastSep + 1, Length(S));
  end;

  // Find extension
  DotPos := 0;
  for P := Length(S) downto 1 do
  begin
    if S[P] = '.' then
    begin
      DotPos := P;
      Break;
    end;
  end;

  if DotPos > 0 then
  begin
    ExtStr := Copy(S, DotPos, Length(S));
    NameStr := Copy(S, 1, DotPos - 1);
  end
  else
    NameStr := S;

  if Drive <> nil then
    StrPCopy(Drive, DriveStr);
  if Dir <> nil then
    StrPCopy(Dir, DirStr);
  if FName <> nil then
    StrPCopy(FName, NameStr);
  if Ext <> nil then
    StrPCopy(Ext, ExtStr);
end;

// Construct a file path from its components.
procedure compat_makepath(Path: PAnsiChar; const Drive, Dir, FName, Ext: PAnsiChar);
var
  S: AnsiString;
begin
  S := '';

  if Drive <> nil then
    S := S + StrPas(Drive);
  if Dir <> nil then
  begin
    S := S + StrPas(Dir);
    // Ensure trailing separator if Dir is non-empty and lacks one
    if (Length(S) > 0) and (S[Length(S)] <> '/') and (S[Length(S)] <> '\') then
      S := S + PathDelim;
  end;
  if FName <> nil then
    S := S + StrPas(FName);
  if Ext <> nil then
  begin
    // Add dot if ext doesn't start with one
    if (StrLen(Ext) > 0) and (Ext^ <> '.') then
      S := S + '.';
    S := S + StrPas(Ext);
  end;

  StrPCopy(Path, S);
end;

// POSIX read wrapper.
function compat_read(FileHandle: Integer; Buf: Pointer; Size: Cardinal): Integer;
begin
  Result := Integer(libc_read(cint(FileHandle), Buf, csize_t(Size)));
end;

// POSIX write wrapper.
function compat_write(FileHandle: Integer; const Buf: Pointer; Size: Cardinal): Integer;
begin
  Result := Integer(libc_write(cint(FileHandle), Buf, csize_t(Size)));
end;

// POSIX lseek wrapper.
function compat_lseek(FileHandle: Integer; Offset: LongInt; Origin: Integer): LongInt;
begin
  Result := LongInt(libc_lseek(cint(FileHandle), coff_t(Offset), cint(Origin)));
end;

// Return current file position (equivalent to tell()).
function compat_tell(FileHandle: Integer): LongInt;
begin
  Result := LongInt(libc_lseek(cint(FileHandle), 0, SEEK_CUR));
end;

// Return file length for a given file descriptor.
function compat_filelength(FD: Integer): LongInt;
var
  CurPos, EndPos: LongInt;
begin
  CurPos := compat_lseek(FD, 0, SEEK_CUR);
  EndPos := compat_lseek(FD, 0, SEEK_END);
  compat_lseek(FD, CurPos, SEEK_SET);
  Result := EndPos;
end;

// Create a directory. Returns 0 on success, -1 on failure.
function compat_mkdir(const Path: PAnsiChar): Integer;
var
  nativePath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrLCopy(@nativePath[0], Path, COMPAT_MAX_PATH - 1);
  compat_windows_path_to_native(@nativePath[0]);
  compat_resolve_path(@nativePath[0]);
  {$IFDEF UNIX}
  // rwxr-xr-x
  if fpMkDir(StrPas(@nativePath[0]), &755) = 0 then
    Result := 0
  else
    Result := -1;
  {$ELSE}
  if SysUtils.CreateDir(StrPas(@nativePath[0])) then
    Result := 0
  else
    Result := -1;
  {$ENDIF}
end;

// Return current time in milliseconds.
function compat_timeGetTime: Cardinal;
begin
  Result := SDL_GetTicks;
end;

// Open a file using C stdio semantics, with case-insensitive path resolution.
function compat_fopen(const Path, Mode: PAnsiChar): Pointer;
var
  nativePath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrLCopy(@nativePath[0], Path, COMPAT_MAX_PATH - 1);
  compat_windows_path_to_native(@nativePath[0]);
  compat_resolve_path(@nativePath[0]);
  Result := libc_fopen(@nativePath[0], Mode);
end;

// Remove (delete) a file.
function compat_remove(const Path: PAnsiChar): Integer;
var
  nativePath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrLCopy(@nativePath[0], Path, COMPAT_MAX_PATH - 1);
  compat_windows_path_to_native(@nativePath[0]);
  compat_resolve_path(@nativePath[0]);
  Result := Integer(libc_remove(@nativePath[0]));
end;

// Rename a file.
function compat_rename(const OldFileName, NewFileName: PAnsiChar): Integer;
var
  nativeOld: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  nativeNew: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrLCopy(@nativeOld[0], OldFileName, COMPAT_MAX_PATH - 1);
  compat_windows_path_to_native(@nativeOld[0]);
  compat_resolve_path(@nativeOld[0]);
  StrLCopy(@nativeNew[0], NewFileName, COMPAT_MAX_PATH - 1);
  compat_windows_path_to_native(@nativeNew[0]);
  compat_resolve_path(@nativeNew[0]);
  Result := Integer(libc_rename(@nativeOld[0], @nativeNew[0]));
end;

// Replace Windows-style backslashes with the native path delimiter.
procedure compat_windows_path_to_native(Path: PAnsiChar);
var
  P: PAnsiChar;
begin
  if Path = nil then
    Exit;
  P := Path;
  while P^ <> #0 do
  begin
    if P^ = '\' then
      P^ := PathDelim;
    Inc(P);
  end;
end;

// Resolve path with case-insensitive matching on Unix.
// Walks the filesystem directory-by-directory and finds case-insensitive matches.
procedure compat_resolve_path(Path: PAnsiChar);
{$IFDEF UNIX}
var
  pch, sep: PAnsiChar;
  dir: pDir;
  entry: pDirent;
  length_: SizeUInt;
  found: Boolean;
  savedChar: AnsiChar;
begin
  if Path = nil then
    Exit;
  if Path^ = #0 then
    Exit;

  pch := Path;

  if pch^ = '/' then
  begin
    dir := fpOpenDir(PAnsiChar('/'));
    Inc(pch);
  end
  else
    dir := fpOpenDir(PAnsiChar('.'));

  while dir <> nil do
  begin
    // Find the next path separator
    sep := StrScan(pch, '/');
    if sep <> nil then
      length_ := PtrUInt(sep) - PtrUInt(pch)
    else
      length_ := StrLen(pch);

    found := False;

    entry := fpReadDir(dir^);
    while entry <> nil do
    begin
      if (StrLen(@entry^.d_name[0]) = length_) and
         (compat_strnicmp(pch, @entry^.d_name[0], length_) = 0) then
      begin
        Move(entry^.d_name[0], pch^, length_);
        found := True;
        Break;
      end;
      entry := fpReadDir(dir^);
    end;

    fpCloseDir(dir^);
    dir := nil;

    if not found then
      Break;

    if sep = nil then
      Break;

    // Temporarily terminate the path at the separator to opendir the prefix
    savedChar := sep^;
    sep^ := #0;
    dir := fpOpenDir(PAnsiChar(Path));
    sep^ := savedChar;

    pch := sep + 1;
  end;
end;
{$ELSE}
begin
  // No case resolution needed on Windows
end;
{$ENDIF}

// Duplicate a C string using GetMem.
function compat_strdup(const AString: PAnsiChar): PAnsiChar;
var
  Len: SizeUInt;
begin
  if AString = nil then
    Exit(nil);
  Len := StrLen(AString);
  Result := GetMem(Len + 1);
  if Result <> nil then
    Move(AString^, Result^, Len + 1);
end;

// Return the size of a C FILE* stream.
function getFileSize(Stream: Pointer): LongInt;
var
  CurPos: clong;
begin
  if Stream = nil then
    Exit(-1);
  CurPos := libc_ftell(Stream);
  libc_fseek(Stream, 0, SEEK_END);
  Result := LongInt(libc_ftell(Stream));
  libc_fseek(Stream, CurPos, SEEK_SET);
end;

end.
