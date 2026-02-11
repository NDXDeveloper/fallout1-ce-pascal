{$MODE OBJFPC}{$H+}
// Converted from: src/int/audio.cc/h
// Audio file I/O through the database layer (db_fopen etc.) with ACM decompression.
unit u_int_audio;

interface

type
  TAudioQueryCompressedFunc = function(filePath: PAnsiChar): Boolean; cdecl;

function audioOpen(const fname: PAnsiChar; flags: Integer): Integer;
function audioCloseFile(fileHandle: Integer): Integer;
function audioRead(fileHandle: Integer; buffer: Pointer; size: LongWord): Integer;
function audioSeek(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt;
function audioFileSize(fileHandle: Integer): LongInt;
function audioTell(fileHandle: Integer): LongInt;
function audioWrite(handle: Integer; const buf: Pointer; size: LongWord): Integer;
function initAudio(isCompressedProc: TAudioQueryCompressedFunc): Integer;
procedure audioClose;

function audioOpen_cdecl(const fname: PAnsiChar; flags: Integer): Integer; cdecl;
function audioCloseFile_cdecl(fileHandle: Integer): Integer; cdecl;
function audioRead_cdecl(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
function audioSeek_cdecl(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
function audioFileSize_cdecl(fileHandle: Integer): LongInt; cdecl;

implementation

uses
  SysUtils, u_memdbg, u_int_sound, u_db, u_debug, u_adecode;

const
  AUDIO_FILE_IN_USE    = $01;
  AUDIO_FILE_COMPRESSED = $02;

type
  TAudio = record
    flags: Integer;
    stream: PDB_FILE;
    audioDecoder: PAudioDecoder;
    fileSize: Integer;
    sampleRate: Integer;
    channels: Integer;
    position: Integer;
  end;
  PAudio = ^TAudio;

function defaultCompressionFunc(filePath: PAnsiChar): Boolean; cdecl; forward;
function decodeRead(stream: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl; forward;

var
  queryCompressedFunc: TAudioQueryCompressedFunc = @defaultCompressionFunc;
  numAudio: Integer = 0;
  audio: PAudio = nil;

function defaultCompressionFunc(filePath: PAnsiChar): Boolean; cdecl;
var
  pch: PAnsiChar;
begin
  pch := StrRScan(filePath, '.');
  if pch <> nil then
    StrCopy(pch + 1, 'raw');
  Result := False;
end;

function decodeRead(stream: Pointer; buf: Pointer; size: LongWord): LongWord; cdecl;
begin
  Result := db_fread(buf, 1, size, PDB_FILE(stream));
end;

function audioOpen(const fname: PAnsiChar; flags: Integer): Integer;
var
  path: array[0..79] of AnsiChar;
  compression: Integer;
  mode: array[0..3] of AnsiChar;
  pm: Integer;
  stream: PDB_FILE;
  index: Integer;
  audioFile: PAudio;
begin
  StrLCopy(@path[0], fname, 79);

  if queryCompressedFunc(@path[0]) then
    compression := 2
  else
    compression := 0;

  FillChar(mode, SizeOf(mode), 0);
  pm := 0;

  if (flags and 1) <> 0 then
  begin
    mode[pm] := 'w'; Inc(pm);
  end
  else if (flags and 2) <> 0 then
  begin
    mode[pm] := 'w'; Inc(pm);
    mode[pm] := '+'; Inc(pm);
  end
  else
  begin
    mode[pm] := 'r'; Inc(pm);
  end;

  if (flags and $100) <> 0 then
  begin
    mode[pm] := 't'; Inc(pm);
  end
  else if (flags and $200) <> 0 then
  begin
    mode[pm] := 'b'; Inc(pm);
  end;

  stream := db_fopen(@path[0], @mode[0]);
  if stream = nil then
  begin
    debug_printf('AudioOpen: Couldn''t open %s for read'#10, [PAnsiChar(@path[0])]);
    Exit(-1);
  end;

  index := 0;
  while index < numAudio do
  begin
    if (PAudio(PByte(audio) + SizeOf(TAudio) * index)^.flags and AUDIO_FILE_IN_USE) = 0 then
      Break;
    Inc(index);
  end;

  if index = numAudio then
  begin
    if audio <> nil then
      audio := PAudio(myrealloc(audio, SizeOf(TAudio) * (numAudio + 1), 'audio.c', 216))
    else
      audio := PAudio(mymalloc(SizeOf(TAudio), 'audio.c', 218));
    Inc(numAudio);
  end;

  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * index);
  audioFile^.flags := AUDIO_FILE_IN_USE;
  audioFile^.stream := stream;

  if compression = 2 then
  begin
    audioFile^.flags := audioFile^.flags or AUDIO_FILE_COMPRESSED;
    audioFile^.audioDecoder := Create_AudioDecoder(@decodeRead, audioFile^.stream,
      @audioFile^.channels, @audioFile^.sampleRate, @audioFile^.fileSize);
    audioFile^.fileSize := audioFile^.fileSize * 2;
  end
  else
  begin
    audioFile^.fileSize := db_filelength(stream);
  end;

  audioFile^.position := 0;

  Result := index + 1;
end;

function audioCloseFile(fileHandle: Integer): Integer;
var
  audioFile: PAudio;
begin
  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * (fileHandle - 1));
  db_fclose(audioFile^.stream);

  if (audioFile^.flags and AUDIO_FILE_COMPRESSED) <> 0 then
    AudioDecoder_Close(audioFile^.audioDecoder);

  FillChar(audioFile^, SizeOf(TAudio), 0);
  Result := 0;
end;

function audioRead(fileHandle: Integer; buffer: Pointer; size: LongWord): Integer;
var
  audioFile: PAudio;
  bytesRead: Integer;
begin
  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * (fileHandle - 1));

  if (audioFile^.flags and AUDIO_FILE_COMPRESSED) <> 0 then
    bytesRead := AudioDecoder_Read(audioFile^.audioDecoder, buffer, size)
  else
    bytesRead := db_fread(buffer, 1, size, audioFile^.stream);

  audioFile^.position := audioFile^.position + bytesRead;
  Result := bytesRead;
end;

function audioSeek(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt;
var
  pos: Integer;
  buf: PByte;
  audioFile: PAudio;
begin
  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * (fileHandle - 1));

  case origin of
    0: pos := offset; // SEEK_SET
    1: pos := offset + audioFile^.position; // SEEK_CUR
    2: pos := offset + audioFile^.fileSize; // SEEK_END
  else
    pos := 0;
  end;

  if (audioFile^.flags and AUDIO_FILE_COMPRESSED) <> 0 then
  begin
    if pos < audioFile^.position then
    begin
      AudioDecoder_Close(audioFile^.audioDecoder);
      db_fseek(audioFile^.stream, 0, 0);
      audioFile^.audioDecoder := Create_AudioDecoder(@decodeRead, audioFile^.stream,
        @audioFile^.channels, @audioFile^.sampleRate, @audioFile^.fileSize);
      audioFile^.position := 0;
      audioFile^.fileSize := audioFile^.fileSize * 2;

      if pos <> 0 then
      begin
        buf := PByte(mymalloc(4096, 'audio.c', 361));
        while pos > 4096 do
        begin
          pos := pos - 4096;
          audioRead(fileHandle, buf, 4096);
        end;
        if pos <> 0 then
          audioRead(fileHandle, buf, pos);
        myfree(buf, 'audio.c', 367);
      end;
    end
    else
    begin
      buf := PByte(mymalloc(1024, 'audio.c', 321));
      pos := audioFile^.position - pos;
      while pos > 1024 do
      begin
        pos := pos - 1024;
        audioRead(fileHandle, buf, 1024);
      end;
      if pos <> 0 then
        audioRead(fileHandle, buf, pos);
      // NOTE: original code leaks buf here
      myfree(buf, 'audio.c', 0);
    end;

    Result := audioFile^.position;
  end
  else
  begin
    Result := db_fseek(audioFile^.stream, offset, origin);
  end;
end;

function audioFileSize(fileHandle: Integer): LongInt;
var
  audioFile: PAudio;
begin
  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * (fileHandle - 1));
  Result := audioFile^.fileSize;
end;

function audioTell(fileHandle: Integer): LongInt;
var
  audioFile: PAudio;
begin
  audioFile := PAudio(PByte(audio) + SizeOf(TAudio) * (fileHandle - 1));
  Result := audioFile^.position;
end;

function audioWrite(handle: Integer; const buf: Pointer; size: LongWord): Integer;
begin
  debug_printf('AudioWrite shouldn''t be ever called'#10, []);
  Result := 0;
end;

function audioOpen_cdecl(const fname: PAnsiChar; flags: Integer): Integer; cdecl;
begin Result := audioOpen(fname, flags); end;
function audioCloseFile_cdecl(fileHandle: Integer): Integer; cdecl;
begin Result := audioCloseFile(fileHandle); end;
function audioRead_cdecl(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
begin Result := audioRead(fileHandle, buf, size); end;
function audioWrite_cdecl(fileHandle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
begin Result := audioWrite(fileHandle, buf, size); end;
function audioSeek_cdecl(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
begin Result := audioSeek(fileHandle, offset, origin); end;
function audioTell_cdecl(fileHandle: Integer): LongInt; cdecl;
begin Result := audioTell(fileHandle); end;
function audioFileSize_cdecl(fileHandle: Integer): LongInt; cdecl;
begin Result := audioFileSize(fileHandle); end;

function initAudio(isCompressedProc: TAudioQueryCompressedFunc): Integer;
begin
  queryCompressedFunc := isCompressedProc;
  audio := nil;
  numAudio := 0;

  Result := soundSetDefaultFileIO(
    @audioOpen_cdecl, @audioCloseFile_cdecl,
    @audioRead_cdecl, @audioWrite_cdecl,
    @audioSeek_cdecl, @audioTell_cdecl,
    @audioFileSize_cdecl);
end;

procedure audioClose;
begin
  if audio <> nil then
    myfree(audio, 'audio.c', 406);
  numAudio := 0;
  audio := nil;
end;

end.
