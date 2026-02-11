{$MODE OBJFPC}{$H+}
// Converted from: src/int/audiof.cc/h
// Audio file I/O through native file system (fopen etc.) with ACM decompression.
unit u_int_audiof;

interface

type
  TAudioFileQueryCompressedFunc = function(filePath: PAnsiChar): Boolean; cdecl;

function audiofOpen(const fname: PAnsiChar; flags: Integer): Integer;
function audiofCloseFile(fileHandle: Integer): Integer;
function audiofRead(fileHandle: Integer; buffer: Pointer; size: LongWord): Integer;
function audiofSeek(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt;
function audiofFileSize(fileHandle: Integer): LongInt;
function audiofTell(fileHandle: Integer): LongInt;
function audiofWrite(fileHandle: Integer; const buffer: Pointer; size: LongWord): Integer;
function initAudiof(isCompressedProc: TAudioFileQueryCompressedFunc): Integer;
procedure audiofClose;

function audiofOpen_cdecl(const fname: PAnsiChar; flags: Integer): Integer; cdecl;
function audiofCloseFile_cdecl(fileHandle: Integer): Integer; cdecl;
function audiofRead_cdecl(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
function audiofSeek_cdecl(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
function audiofFileSize_cdecl(fileHandle: Integer): LongInt; cdecl;

implementation

uses
  SysUtils, u_memdbg, u_int_sound, u_debug, u_adecode, u_platform_compat;

const
  AUDIOF_FILE_IN_USE    = $01;
  AUDIOF_FILE_COMPRESSED = $02;

type
  TAudioFile = record
    flags: Integer;
    stream: Pointer; // FILE* - native file pointer
    audioDecoder: PAudioDecoder;
    fileSize: Integer;
    sampleRate: Integer;
    channels: Integer;
    position: Integer;
  end;
  PAudioFile = ^TAudioFile;

function defaultCompressionFunc(filePath: PAnsiChar): Boolean; cdecl; forward;
function decodeRead(stream: Pointer; buffer: Pointer; size: LongWord): LongWord; cdecl; forward;

var
  queryCompressedFunc: TAudioFileQueryCompressedFunc = @defaultCompressionFunc;
  audiof: PAudioFile = nil;
  numAudiof: Integer = 0;

function defaultCompressionFunc(filePath: PAnsiChar): Boolean; cdecl;
var
  pch: PAnsiChar;
begin
  pch := StrRScan(filePath, '.');
  if pch <> nil then
    StrCopy(pch + 1, 'raw');
  Result := False;
end;

function libc_fread(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fread';
function libc_fclose(stream: Pointer): Integer; cdecl; external 'c' name 'fclose';
function libc_fseek(stream: Pointer; offset: LongInt; whence: Integer): Integer; cdecl; external 'c' name 'fseek';
function libc_ftell(stream: Pointer): LongInt; cdecl; external 'c' name 'ftell';

function fread_native(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt;
begin
  Result := libc_fread(buf, size, count, stream);
end;

function fclose_native(stream: Pointer): Integer;
begin
  Result := libc_fclose(stream);
end;

function fseek_native(stream: Pointer; offset: LongInt; origin: Integer): Integer;
begin
  Result := libc_fseek(stream, offset, origin);
end;

function decodeRead(stream: Pointer; buffer: Pointer; size: LongWord): LongWord; cdecl;
begin
  Result := libc_fread(buffer, 1, size, stream);
end;

function audiofOpen(const fname: PAnsiChar; flags: Integer): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  compression: Integer;
  mode: array[0..3] of AnsiChar;
  pm: Integer;
  stream: Pointer;
  index: Integer;
  audioFile: PAudioFile;
begin
  StrLCopy(@path[0], fname, COMPAT_MAX_PATH - 1);

  if queryCompressedFunc(@path[0]) then
    compression := 2
  else
    compression := 0;

  FillChar(mode, SizeOf(mode), 0);
  pm := 0;

  if (flags and $01) <> 0 then
  begin
    mode[pm] := 'w'; Inc(pm);
  end
  else if (flags and $02) <> 0 then
  begin
    mode[pm] := 'w'; Inc(pm);
    mode[pm] := '+'; Inc(pm);
  end
  else
  begin
    mode[pm] := 'r'; Inc(pm);
  end;

  if (flags and $0100) <> 0 then
  begin
    mode[pm] := 't'; Inc(pm);
  end
  else if (flags and $0200) <> 0 then
  begin
    mode[pm] := 'b'; Inc(pm);
  end;

  stream := compat_fopen(@path[0], @mode[0]);
  if stream = nil then
    Exit(-1);

  index := 0;
  while index < numAudiof do
  begin
    if (PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * index)^.flags and AUDIOF_FILE_IN_USE) = 0 then
      Break;
    Inc(index);
  end;

  if index = numAudiof then
  begin
    if audiof <> nil then
      audiof := PAudioFile(myrealloc(audiof, SizeOf(TAudioFile) * (numAudiof + 1), 'audiof.c', 206))
    else
      audiof := PAudioFile(mymalloc(SizeOf(TAudioFile), 'audiof.c', 208));
    Inc(numAudiof);
  end;

  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * index);
  audioFile^.flags := AUDIOF_FILE_IN_USE;
  audioFile^.stream := stream;

  if compression = 2 then
  begin
    audioFile^.flags := audioFile^.flags or AUDIOF_FILE_COMPRESSED;
    audioFile^.audioDecoder := Create_AudioDecoder(@decodeRead, audioFile^.stream,
      @audioFile^.channels, @audioFile^.sampleRate, @audioFile^.fileSize);
    audioFile^.fileSize := audioFile^.fileSize * 2;
  end
  else
  begin
    audioFile^.fileSize := getFileSize(stream);
  end;

  audioFile^.position := 0;

  Result := index + 1;
end;

function audiofCloseFile(fileHandle: Integer): Integer;
var
  audioFile: PAudioFile;
begin
  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * (fileHandle - 1));
  fclose_native(audioFile^.stream);

  if (audioFile^.flags and AUDIOF_FILE_COMPRESSED) <> 0 then
    AudioDecoder_Close(audioFile^.audioDecoder);

  FillChar(audioFile^, SizeOf(TAudioFile), 0);
  Result := 0;
end;

function audiofRead(fileHandle: Integer; buffer: Pointer; size: LongWord): Integer;
var
  audioFile: PAudioFile;
  bytesRead: Integer;
begin
  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * (fileHandle - 1));

  if (audioFile^.flags and AUDIOF_FILE_COMPRESSED) <> 0 then
    bytesRead := AudioDecoder_Read(audioFile^.audioDecoder, buffer, size)
  else
    bytesRead := Integer(libc_fread(buffer, 1, size, audioFile^.stream));

  audioFile^.position := audioFile^.position + bytesRead;
  Result := bytesRead;
end;

function audiofSeek(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt;
var
  a4: Integer;
  buf: Pointer;
  remaining: Integer;
  audioFile: PAudioFile;
begin
  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * (fileHandle - 1));

  case origin of
    0: a4 := offset;           // SEEK_SET
    1: a4 := audioFile^.fileSize + offset;  // SEEK_CUR
    2: a4 := audioFile^.position + offset;  // SEEK_END
  else
    a4 := 0;
  end;

  if (audioFile^.flags and AUDIOF_FILE_COMPRESSED) <> 0 then
  begin
    if a4 <= audioFile^.position then
    begin
      AudioDecoder_Close(audioFile^.audioDecoder);
      fseek_native(audioFile^.stream, 0, 0);
      audioFile^.audioDecoder := Create_AudioDecoder(@decodeRead, audioFile^.stream,
        @audioFile^.channels, @audioFile^.sampleRate, @audioFile^.fileSize);
      audioFile^.fileSize := audioFile^.fileSize * 2;
      audioFile^.position := 0;

      if a4 <> 0 then
      begin
        buf := mymalloc(4096, 'audiof.c', 363);
        while a4 > 4096 do
        begin
          audiofRead(fileHandle, buf, 4096);
          a4 := a4 - 4096;
        end;
        if a4 <> 0 then
          audiofRead(fileHandle, buf, a4);
        myfree(buf, 'audiof.c', 369);
      end;
    end
    else
    begin
      buf := mymalloc($400, 'audiof.c', 315);
      remaining := audioFile^.position - a4;
      while remaining > 1024 do
      begin
        audiofRead(fileHandle, buf, 1024);
        remaining := remaining - 1024;
      end;
      if remaining <> 0 then
        audiofRead(fileHandle, buf, remaining);
      // NOTE: Original code leaks buf here
      myfree(buf, 'audiof.c', 0);
    end;
    Result := audioFile^.position;
  end
  else
  begin
    fseek_native(audioFile^.stream, offset, origin);
    Result := offset; // approximate
  end;
end;

function audiofFileSize(fileHandle: Integer): LongInt;
var
  audioFile: PAudioFile;
begin
  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * (fileHandle - 1));
  Result := audioFile^.fileSize;
end;

function audiofTell(fileHandle: Integer): LongInt;
var
  audioFile: PAudioFile;
begin
  audioFile := PAudioFile(PByte(audiof) + SizeOf(TAudioFile) * (fileHandle - 1));
  Result := audioFile^.position;
end;

function audiofWrite(fileHandle: Integer; const buffer: Pointer; size: LongWord): Integer;
begin
  debug_printf('AudiofWrite shouldn''t be ever called'#10, []);
  Result := 0;
end;

function audiofOpen_cdecl(const fname: PAnsiChar; flags: Integer): Integer; cdecl;
begin Result := audiofOpen(fname, flags); end;
function audiofCloseFile_cdecl(fileHandle: Integer): Integer; cdecl;
begin Result := audiofCloseFile(fileHandle); end;
function audiofRead_cdecl(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
begin Result := audiofRead(fileHandle, buf, size); end;
function audiofWrite_cdecl(fileHandle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
begin Result := audiofWrite(fileHandle, buf, size); end;
function audiofSeek_cdecl(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
begin Result := audiofSeek(fileHandle, offset, origin); end;
function audiofTell_cdecl(fileHandle: Integer): LongInt; cdecl;
begin Result := audiofTell(fileHandle); end;
function audiofFileSize_cdecl(fileHandle: Integer): LongInt; cdecl;
begin Result := audiofFileSize(fileHandle); end;

function initAudiof(isCompressedProc: TAudioFileQueryCompressedFunc): Integer;
begin
  queryCompressedFunc := isCompressedProc;
  audiof := nil;
  numAudiof := 0;

  Result := soundSetDefaultFileIO(
    @audiofOpen_cdecl, @audiofCloseFile_cdecl,
    @audiofRead_cdecl, @audiofWrite_cdecl,
    @audiofSeek_cdecl, @audiofTell_cdecl,
    @audiofFileSize_cdecl);
end;

procedure audiofClose;
begin
  if audiof <> nil then
    myfree(audiof, 'audiof.c', 404);
  numAudiof := 0;
  audiof := nil;
end;

end.
