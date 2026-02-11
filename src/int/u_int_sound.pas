{$MODE OBJFPC}{$H+}
// Converted from: src/int/sound.cc/h
// Sound system for the script interpreter.
unit u_int_sound;

interface

const
  VOLUME_MIN = 0;
  VOLUME_MAX = $7FFF;

  // SoundError
  SOUND_NO_ERROR                = 0;
  SOUND_SOS_DRIVER_NOT_LOADED   = 1;
  SOUND_SOS_INVALID_POINTER     = 2;
  SOUND_SOS_DETECT_INITIALIZED  = 3;
  SOUND_SOS_FAIL_ON_FILE_OPEN   = 4;
  SOUND_SOS_MEMORY_FAIL         = 5;
  SOUND_SOS_INVALID_DRIVER_ID   = 6;
  SOUND_SOS_NO_DRIVER_FOUND     = 7;
  SOUND_SOS_DETECTION_FAILURE   = 8;
  SOUND_SOS_DRIVER_LOADED       = 9;
  SOUND_SOS_INVALID_HANDLE      = 10;
  SOUND_SOS_NO_HANDLES          = 11;
  SOUND_SOS_PAUSED              = 12;
  SOUND_SOS_NO_PAUSED           = 13;
  SOUND_SOS_INVALID_DATA        = 14;
  SOUND_SOS_DRV_FILE_FAIL       = 15;
  SOUND_SOS_INVALID_PORT        = 16;
  SOUND_SOS_INVALID_IRQ         = 17;
  SOUND_SOS_INVALID_DMA         = 18;
  SOUND_SOS_INVALID_DMA_IRQ     = 19;
  SOUND_NO_DEVICE               = 20;
  SOUND_NOT_INITIALIZED         = 21;
  SOUND_NO_SOUND                = 22;
  SOUND_FUNCTION_NOT_SUPPORTED  = 23;
  SOUND_NO_BUFFERS_AVAILABLE    = 24;
  SOUND_FILE_NOT_FOUND          = 25;
  SOUND_ALREADY_PLAYING         = 26;
  SOUND_NOT_PLAYING             = 27;
  SOUND_ALREADY_PAUSED          = 28;
  SOUND_NOT_PAUSED              = 29;
  SOUND_INVALID_HANDLE          = 30;
  SOUND_NO_MEMORY_AVAILABLE     = 31;
  SOUND_UNKNOWN_ERROR           = 32;
  SOUND_ERR_COUNT               = 33;

  // SoundType
  SOUND_TYPE_MEMORY            = $01;
  SOUND_TYPE_STREAMING         = $02;
  SOUND_TYPE_FIRE_AND_FORGET   = $04;
  SOUND_TYPE_INFINITE          = $10;
  SOUND_TYPE_0x20              = $20;

  // SoundFlags
  SOUND_FLAG_0x02              = $02;
  SOUND_FLAG_0x04              = $04;
  SOUND_16BIT                  = $08;
  SOUND_8BIT                   = $10;
  SOUND_LOOPING                = $20;
  SOUND_FLAG_0x80              = $80;
  SOUND_FLAG_0x100             = $100;
  SOUND_FLAG_0x200             = $200;

type
  TSoundMallocFunc = function(size: SizeUInt): Pointer; cdecl;
  TSoundReallocFunc = function(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
  TSoundFreeFunc = procedure(ptr: Pointer); cdecl;
  TSoundFileNameMangler = function(name: PAnsiChar): PAnsiChar; cdecl;

  TSoundOpenProc = function(const filePath: PAnsiChar; flags: Integer): Integer; cdecl;
  TSoundCloseProc = function(fileHandle: Integer): Integer; cdecl;
  TSoundReadProc = function(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
  TSoundWriteProc = function(fileHandle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
  TSoundSeekProc = function(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
  TSoundTellProc = function(fileHandle: Integer): LongInt; cdecl;
  TSoundFileLengthProc = function(fileHandle: Integer): LongInt; cdecl;

  TSoundFileIO = record
    open: TSoundOpenProc;
    close: TSoundCloseProc;
    read: TSoundReadProc;
    write: TSoundWriteProc;
    seek: TSoundSeekProc;
    tell: TSoundTellProc;
    filelength_: TSoundFileLengthProc;
    fd: Integer;
  end;
  PSoundFileIO = ^TSoundFileIO;

  TSoundCallback = procedure(userData: Pointer; a2: Integer); cdecl;
  TSoundDeleteCallback = procedure(userData: Pointer); cdecl;

  PSound = ^TSound;
  TSound = record
    io: TSoundFileIO;
    data: PByte;
    soundBuffer: Integer;
    bitsPerSample: Integer;
    channels: Integer;
    rate: Integer;
    soundFlags_: Integer;
    statusFlags: Integer;
    type_: Integer;
    pausePos: Integer;
    volume: Integer;
    loops: Integer;
    field_54: Integer;
    field_58: Integer;
    minReadBuffer: Integer;
    fileSize: Integer;
    numBytesRead: Integer;
    field_68: Integer;
    readLimit: Integer;
    dataSize: Integer;
    lastUpdate: LongWord;
    lastPosition: Integer;
    numBuffers: Integer;
    callback: TSoundCallback;
    callbackUserData: Pointer;
    deleteCallback: TSoundDeleteCallback;
    deleteUserData: Pointer;
    next: PSound;
    prev: PSound;
  end;

function soundNew: PSound;
function soundDelete(sound: PSound): Integer;
function soundPlay(sound: PSound): Integer;
function soundStop(sound: PSound): Integer;
function soundDone(sound: PSound): Boolean;
function soundFading(sound: PSound): Boolean;
function soundPaused(sound: PSound): Boolean;
function soundFlags(sound: PSound; a2: Integer): Integer;
function soundType(sound: PSound; a2: Integer): Integer;
function soundLength(sound: PSound): Integer;
function soundLoop(sound: PSound; a2: Integer): Integer;
function soundVolumeHMItoDirectSound(a1: Integer): Integer;
function soundVolume(sound: PSound; volume: Integer): Integer;
function soundGetVolume(sound: PSound): Integer;
function soundSetCallback(sound: PSound; callback: TSoundCallback; userData: Pointer): Integer;
function soundSetChannel(sound: PSound; channels: Integer): Integer;
function soundSetReadLimit(sound: PSound; readLimit: Integer): Integer;
function soundPause(sound: PSound): Integer;
function soundUnpause(sound: PSound): Integer;
function soundSetFileIO(sound: PSound;
  openProc: TSoundOpenProc; closeProc: TSoundCloseProc;
  readProc: TSoundReadProc; writeProc: TSoundWriteProc;
  seekProc: TSoundSeekProc; tellProc: TSoundTellProc;
  fileLengthProc: TSoundFileLengthProc): Integer;
procedure soundMgrDelete(sound: PSound);
function soundSetMasterVolume(value: Integer): Integer;
function soundGetPosition(sound: PSound): Integer;
function soundSetPosition(sound: PSound; a2: Integer): Integer;
function soundFade(sound: PSound; duration, targetVolume: Integer): Integer;
procedure soundFlushAllSounds;
procedure soundUpdate;
function soundSetDefaultFileIO(
  openProc: TSoundOpenProc; closeProc: TSoundCloseProc;
  readProc: TSoundReadProc; writeProc: TSoundWriteProc;
  seekProc: TSoundSeekProc; tellProc: TSoundTellProc;
  fileLengthProc: TSoundFileLengthProc): Integer;
procedure soundRegisterAlloc(mallocProc: TSoundMallocFunc; reallocProc: TSoundReallocFunc;
  freeProc: TSoundFreeFunc);
function soundError(err: Integer): PAnsiChar;
function soundInit(a1, a2, a3, a4, rate: Integer): Integer;
procedure soundClose;
function soundAllocate(a1, a2: Integer): PSound;
function soundLoad(sound: PSound; filePath: PAnsiChar): Integer;
function soundPlaying(sound: PSound): Boolean;
procedure soundExit;

implementation

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  u_debug, u_sdl2, u_audio_engine;

const
  SOUND_STATUS_DONE       = $01;
  SOUND_STATUS_IS_PLAYING = $02;
  SOUND_STATUS_IS_FADING  = $04;
  SOUND_STATUS_IS_PAUSED  = $08;

type
  PFadeSound = ^TFadeSound;
  TFadeSound = record
    sound: PSound;
    deltaVolume: Integer;
    targetVolume: Integer;
    initialVolume: Integer;
    currentVolume: Integer;
    field_14: Integer;
    prev: PFadeSound;
    next: PFadeSound;
  end;

// Forward declarations
function soundContinue(sound: PSound): Integer; forward;
function soundRewind(sound: PSound): Integer; forward;
function soundSetData(sound: PSound; buf: PByte; size: Integer): Integer; forward;
procedure refreshSoundBuffers(sound: PSound); forward;
function preloadBuffers(sound: PSound): Integer; forward;
function addSoundData(sound: PSound; buf: PByte; size: Integer): Integer; forward;
function doTimerEvent(interval: LongWord; param: Pointer): LongWord; cdecl; forward;
procedure removeTimedEvent(var timerId: TSDL_TimerID); forward;
procedure removeFadeSound(fadeSound: PFadeSound); forward;
procedure fadeSounds; forward;
function internalSoundFade(sound: PSound; duration, targetVolume, a4: Integer): Integer; forward;

// Default callbacks
function defaultMalloc(size: SizeUInt): Pointer; cdecl; forward;
function defaultRealloc(ptr: Pointer; size: SizeUInt): Pointer; cdecl; forward;
procedure defaultFree(ptr: Pointer); cdecl; forward;
function soundOpenData(const filePath: PAnsiChar; flags: Integer): Integer; cdecl; forward;
function soundCloseData(fileHandle: Integer): Integer; cdecl; forward;
function soundReadData(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl; forward;
function soundWriteData(fileHandle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl; forward;
function soundSeekData(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl; forward;
function soundTellData(fileHandle: Integer): LongInt; cdecl; forward;
function soundFileSize(fileHandle: Integer): LongInt; cdecl; forward;
function defaultMangler(fname: PAnsiChar): PAnsiChar; cdecl; forward;

var
  // 0x507E04
  fadeHead: PFadeSound = nil;
  // 0x507E08
  fadeFreeList: PFadeSound = nil;

  // 0x507E14
  mallocPtr: TSoundMallocFunc = @defaultMalloc;
  // 0x507E18
  reallocPtr: TSoundReallocFunc = @defaultRealloc;
  // 0x507E1C
  freePtr_: TSoundFreeFunc = @defaultFree;

  // 0x507E20
  defaultStream: TSoundFileIO;

  // 0x507E40
  nameMangler: TSoundFileNameMangler = @defaultMangler;

  soundErrorMessages: array[0..SOUND_ERR_COUNT - 1] of PAnsiChar = (
    'sound.c: No error',
    'sound.c: SOS driver not loaded',
    'sound.c: SOS invalid pointer',
    'sound.c: SOS detect initialized',
    'sound.c: SOS fail on file open',
    'sound.c: SOS memory fail',
    'sound.c: SOS invalid driver ID',
    'sound.c: SOS no driver found',
    'sound.c: SOS detection failure',
    'sound.c: SOS driver loaded',
    'sound.c: SOS invalid handle',
    'sound.c: SOS no handles',
    'sound.c: SOS paused',
    'sound.c: SOS not paused',
    'sound.c: SOS invalid data',
    'sound.c: SOS drv file fail',
    'sound.c: SOS invalid port',
    'sound.c: SOS invalid IRQ',
    'sound.c: SOS invalid DMA',
    'sound.c: SOS invalid DMA IRQ',
    'sound.c: no device',
    'sound.c: not initialized',
    'sound.c: no sound',
    'sound.c: function not supported',
    'sound.c: no buffers available',
    'sound.c: file not found',
    'sound.c: already playing',
    'sound.c: not playing',
    'sound.c: already paused',
    'sound.c: not paused',
    'sound.c: invalid handle',
    'sound.c: no memory available',
    'sound.c: unknown error'
  );

  // 0x6651A0
  soundErrorno: Integer = 0;
  // 0x6651A4
  masterVol: Integer = VOLUME_MAX;
  // 0x6651AC
  sampleRate: Integer = 0;
  // 0x6651B0
  numSounds: Integer = 0;
  // 0x6651B4
  deviceInit: Integer = 0;
  // 0x6651B8
  dataSize_: Integer = 0;
  // 0x6651BC
  numBuffers_: Integer = 0;
  // 0x6651C0
  driverInit: Boolean = False;
  // 0x6651C4
  soundMgrList: PSound = nil;

  gFadeSoundsTimerId: TSDL_TimerID = 0;

  defaultStreamInitialized: Boolean = False;

// --- Default callbacks ---

function defaultMalloc(size: SizeUInt): Pointer; cdecl;
begin
  Result := GetMem(size);
end;

function defaultRealloc(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
begin
  Result := ReAllocMem(ptr, size);
end;

procedure defaultFree(ptr: Pointer); cdecl;
begin
  FreeMem(ptr);
end;

function soundFileSize(fileHandle: Integer): LongInt; cdecl;
var
  pos, sz: LongInt;
begin
  {$IFDEF UNIX}
  pos := FpLSeek(fileHandle, 0, SEEK_CUR);
  sz := FpLSeek(fileHandle, 0, SEEK_END);
  FpLSeek(fileHandle, pos, SEEK_SET);
  Result := sz;
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function soundTellData(fileHandle: Integer): LongInt; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpLSeek(fileHandle, 0, SEEK_CUR);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function soundWriteData(fileHandle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpWrite(fileHandle, buf^, size);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function soundReadData(fileHandle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpRead(fileHandle, buf^, size);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function soundOpenData(const filePath: PAnsiChar; flags: Integer): Integer; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpOpen(filePath, flags);
  {$ELSE}
  Result := -1;
  {$ENDIF}
end;

function soundSeekData(fileHandle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpLSeek(fileHandle, offset, origin);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function soundCloseData(fileHandle: Integer): Integer; cdecl;
begin
  {$IFDEF UNIX}
  Result := FpClose(fileHandle);
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

function defaultMangler(fname: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := fname;
end;

procedure initDefaultStream;
begin
  if not defaultStreamInitialized then
  begin
    defaultStream.open := @soundOpenData;
    defaultStream.close := @soundCloseData;
    defaultStream.read := @soundReadData;
    defaultStream.write := @soundWriteData;
    defaultStream.seek := @soundSeekData;
    defaultStream.tell := @soundTellData;
    defaultStream.filelength_ := @soundFileSize;
    defaultStream.fd := -1;
    defaultStreamInitialized := True;
  end;
end;

// --- Core implementation ---

// 0x499C98
procedure soundRegisterAlloc(mallocProc: TSoundMallocFunc; reallocProc: TSoundReallocFunc;
  freeProc: TSoundFreeFunc);
begin
  mallocPtr := mallocProc;
  reallocPtr := reallocProc;
  freePtr_ := freeProc;
end;

// 0x499D20
function soundError(err: Integer): PAnsiChar;
begin
  if err = -1 then
    err := soundErrorno;
  if (err < 0) or (err > SOUND_UNKNOWN_ERROR) then
    err := SOUND_UNKNOWN_ERROR;
  Result := soundErrorMessages[err];
end;

// 0x499D40
procedure refreshSoundBuffers(sound: PSound);
var
  readPos, writePos: LongWord;
  hr: Boolean;
  v3, v6, v53: Integer;
  audioPtr1, audioPtr2: Pointer;
  audioBytes1, audioBytes2: LongWord;
  audioPtr: PByte;
  audioBytes: Integer;
  bytesRead, bytesToRead, pos, v20: Integer;
begin
  if (sound^.soundFlags_ and $80) <> 0 then
    Exit;

  hr := audioEngineSoundBufferGetCurrentPosition(sound^.soundBuffer, @readPos, @writePos);
  if not hr then
    Exit;

  if readPos < LongWord(sound^.lastPosition) then
    sound^.numBytesRead := sound^.numBytesRead + Integer(readPos) + sound^.numBuffers * dataSize_ - sound^.lastPosition
  else
    sound^.numBytesRead := sound^.numBytesRead + Integer(readPos) - sound^.lastPosition;

  if (sound^.soundFlags_ and $0100) <> 0 then
  begin
    if (sound^.type_ and $20) <> 0 then
    begin
      if (sound^.soundFlags_ and $0200) <> 0 then
        sound^.soundFlags_ := sound^.soundFlags_ or $80;
    end
    else
    begin
      if sound^.fileSize <= sound^.numBytesRead then
        sound^.soundFlags_ := sound^.soundFlags_ or $0280;
    end;
  end;
  sound^.lastPosition := Integer(readPos);

  if sound^.fileSize < sound^.numBytesRead then
  begin
    repeat
      v3 := sound^.numBytesRead - sound^.fileSize;
      sound^.numBytesRead := v3;
    until v3 <= sound^.fileSize;
  end;

  v6 := Integer(readPos) div dataSize_;
  if sound^.lastUpdate = LongWord(v6) then
    Exit;

  if sound^.lastUpdate > LongWord(v6) then
    v53 := v6 + sound^.numBuffers - Integer(sound^.lastUpdate)
  else
    v53 := v6 - Integer(sound^.lastUpdate);

  if dataSize_ * v53 >= sound^.readLimit then
    v53 := (sound^.readLimit + dataSize_ - 1) div dataSize_;

  if v53 < sound^.minReadBuffer then
    Exit;

  hr := audioEngineSoundBufferLock(sound^.soundBuffer,
    dataSize_ * Integer(sound^.lastUpdate), dataSize_ * v53,
    @audioPtr1, @audioBytes1, @audioPtr2, @audioBytes2, 0);
  if not hr then
    Exit;

  if Integer(audioBytes1 + audioBytes2) <> dataSize_ * v53 then
  begin
    v53 := Integer(audioBytes1 + audioBytes2) div dataSize_;
    if v53 < sound^.minReadBuffer then
      Exit;
  end;

  audioPtr := PByte(audioPtr1);
  audioBytes := Integer(audioBytes1);

  Dec(v53);
  while v53 >= 0 do
  begin
    if (sound^.soundFlags_ and $0200) <> 0 then
    begin
      bytesRead := dataSize_;
      FillChar(sound^.data^, bytesRead, 0);
    end
    else
    begin
      bytesToRead := dataSize_;
      if sound^.field_58 <> -1 then
      begin
        pos := sound^.io.tell(sound^.io.fd);
        if bytesToRead + pos > sound^.field_58 then
          bytesToRead := sound^.field_58 - pos;
      end;

      bytesRead := sound^.io.read(sound^.io.fd, sound^.data, bytesToRead);
      if bytesRead < dataSize_ then
      begin
        if ((sound^.soundFlags_ and $20) = 0) or ((sound^.soundFlags_ and $0100) <> 0) then
        begin
          FillChar((sound^.data + bytesRead)^, dataSize_ - bytesRead, 0);
          sound^.soundFlags_ := sound^.soundFlags_ or $0200;
          bytesRead := dataSize_;
        end
        else
        begin
          while bytesRead < dataSize_ do
          begin
            if sound^.loops = -1 then
            begin
              sound^.io.seek(sound^.io.fd, sound^.field_54, SEEK_SET);
              if sound^.callback <> nil then
                sound^.callback(sound^.callbackUserData, $0400);
            end
            else
            begin
              if sound^.loops <= 0 then
              begin
                sound^.field_58 := -1;
                sound^.field_54 := 0;
                sound^.loops := 0;
                sound^.soundFlags_ := sound^.soundFlags_ and (not $20);
                bytesRead := bytesRead + sound^.io.read(sound^.io.fd, sound^.data + bytesRead, dataSize_ - bytesRead);
                Break;
              end;

              Dec(sound^.loops);
              sound^.io.seek(sound^.io.fd, sound^.field_54, SEEK_SET);

              if sound^.callback <> nil then
                sound^.callback(sound^.callbackUserData, $400);
            end;

            if sound^.field_58 = -1 then
              bytesToRead := dataSize_ - bytesRead
            else
            begin
              pos := sound^.io.tell(sound^.io.fd);
              if dataSize_ + bytesRead + pos <= sound^.field_58 then
                bytesToRead := dataSize_ - bytesRead
              else
                bytesToRead := sound^.field_58 - bytesRead - pos;
            end;

            v20 := sound^.io.read(sound^.io.fd, sound^.data + bytesRead, bytesToRead);
            bytesRead := bytesRead + v20;
            if v20 < bytesToRead then
              Break;
          end;
        end;
      end;
    end;

    if bytesRead > audioBytes then
    begin
      if audioBytes <> 0 then
        Move(sound^.data^, audioPtr^, audioBytes);

      if audioPtr2 <> nil then
      begin
        Move((sound^.data + audioBytes)^, PByte(audioPtr2)^, bytesRead - audioBytes);
        audioPtr := PByte(audioPtr2) + bytesRead - audioBytes;
        audioBytes := Integer(audioBytes2) - bytesRead;
      end;
    end
    else
    begin
      Move(sound^.data^, audioPtr^, bytesRead);
      audioPtr := audioPtr + bytesRead;
      audioBytes := audioBytes - bytesRead;
    end;

    Dec(v53);
  end;

  audioEngineSoundBufferUnlock(sound^.soundBuffer, audioPtr1, audioBytes1, audioPtr2, audioBytes2);

  sound^.lastUpdate := LongWord(v6);
end;

// 0x49A1E4
function soundInit(a1, a2, a3, a4, rate: Integer): Integer;
begin
  initDefaultStream;

  if not audioEngineInit then
  begin
    debug_printf('soundInit: Unable to init audio engine');
    soundErrorno := SOUND_SOS_DETECTION_FAILURE;
    Result := soundErrorno;
    Exit;
  end;

  sampleRate := rate;
  dataSize_ := a4;
  numBuffers_ := a2;
  driverInit := True;
  deviceInit := 1;

  soundSetMasterVolume(VOLUME_MAX);

  soundErrorno := SOUND_NO_ERROR;
  Result := 0;
end;

// 0x49A5D8
procedure soundClose;
var
  next: PSound;
begin
  while soundMgrList <> nil do
  begin
    next := soundMgrList^.next;
    soundDelete(soundMgrList);
    soundMgrList := next;
  end;

  if gFadeSoundsTimerId <> 0 then
    removeTimedEvent(gFadeSoundsTimerId);

  while fadeFreeList <> nil do
  begin
    next := PSound(fadeFreeList^.next);
    freePtr_(fadeFreeList);
    fadeFreeList := PFadeSound(next);
  end;

  audioEngineExit;

  soundErrorno := SOUND_NO_ERROR;
  driverInit := False;
end;

// 0x49A688
function soundAllocate(a1, a2: Integer): PSound;
var
  sound: PSound;
begin
  initDefaultStream;

  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := nil;
    Exit;
  end;

  sound := PSound(mallocPtr(SizeOf(TSound)));
  FillChar(sound^, SizeOf(TSound), 0);

  Move(defaultStream, sound^.io, SizeOf(TSoundFileIO));

  if (a2 and SOUND_FLAG_0x02) = 0 then
    a2 := a2 or SOUND_FLAG_0x02;

  if (a2 and SOUND_16BIT) <> 0 then
    sound^.bitsPerSample := 16
  else
    sound^.bitsPerSample := 8;
  sound^.channels := 1;
  sound^.rate := sampleRate;

  sound^.soundFlags_ := a2;
  sound^.type_ := a1;
  sound^.soundBuffer := -1;
  sound^.statusFlags := 0;
  sound^.numBuffers := numBuffers_;
  sound^.dataSize := dataSize_;
  sound^.numBytesRead := 0;
  sound^.readLimit := sound^.dataSize * numBuffers_;

  if (a1 and SOUND_TYPE_INFINITE) <> 0 then
  begin
    sound^.loops := -1;
    sound^.soundFlags_ := sound^.soundFlags_ or SOUND_LOOPING;
  end;

  sound^.field_58 := -1;
  sound^.minReadBuffer := 1;
  sound^.volume := VOLUME_MAX;
  sound^.prev := nil;
  sound^.field_54 := 0;
  sound^.next := soundMgrList;

  if soundMgrList <> nil then
    soundMgrList^.prev := sound;

  soundMgrList := sound;

  Result := sound;
end;

// soundNew - simplified constructor (kept for interface compatibility)
function soundNew: PSound;
begin
  initDefaultStream;
  Result := PSound(mallocPtr(SizeOf(TSound)));
  if Result = nil then Exit;
  FillChar(Result^, SizeOf(TSound), 0);
  Move(defaultStream, Result^.io, SizeOf(TSoundFileIO));
  Result^.volume := VOLUME_MAX;
  Result^.statusFlags := 0;
  Result^.soundBuffer := -1;
end;

// 0x49A88C
function preloadBuffers(sound: PSound): Integer;
var
  buf: PByte;
  bytesRead: Integer;
  size: Integer;
  v14: PByte;
  v15: Integer;
begin
  size := sound^.io.filelength_(sound^.io.fd);
  sound^.fileSize := size;

  if (sound^.type_ and SOUND_TYPE_STREAMING) <> 0 then
  begin
    if (sound^.soundFlags_ and SOUND_LOOPING) = 0 then
      sound^.soundFlags_ := sound^.soundFlags_ or (SOUND_FLAG_0x100 or SOUND_LOOPING);

    if sound^.numBuffers * sound^.dataSize >= size then
    begin
      if (size div sound^.dataSize) * sound^.dataSize <> size then
        size := (size div sound^.dataSize + 1) * sound^.dataSize;
    end
    else
      size := sound^.numBuffers * sound^.dataSize;
  end
  else
  begin
    sound^.type_ := sound^.type_ and (not (SOUND_TYPE_MEMORY or SOUND_TYPE_STREAMING));
    sound^.type_ := sound^.type_ or SOUND_TYPE_MEMORY;
  end;

  buf := PByte(mallocPtr(size));
  bytesRead := sound^.io.read(sound^.io.fd, buf, size);
  if bytesRead <> size then
  begin
    if ((sound^.soundFlags_ and SOUND_LOOPING) = 0) or
       ((sound^.soundFlags_ and SOUND_FLAG_0x100) <> 0) then
    begin
      FillChar((buf + bytesRead)^, size - bytesRead, 0);
    end
    else
    begin
      v14 := buf + bytesRead;
      v15 := bytesRead;
      while size - v15 > bytesRead do
      begin
        Move(buf^, v14^, bytesRead);
        v15 := v15 + bytesRead;
        v14 := v14 + bytesRead;
      end;
      if v15 < size then
        Move(buf^, v14^, size - v15);
    end;
  end;

  Result := soundSetData(sound, buf, size);
  freePtr_(buf);

  if (sound^.type_ and SOUND_TYPE_MEMORY) <> 0 then
  begin
    sound^.io.close(sound^.io.fd);
    sound^.io.fd := -1;
  end
  else
  begin
    if sound^.data = nil then
      sound^.data := PByte(mallocPtr(sound^.dataSize));
  end;
end;

// 0x49AA1C
function soundLoad(sound: PSound; filePath: PAnsiChar): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  sound^.io.fd := sound^.io.open(nameMangler(filePath), $0200);
  if sound^.io.fd = -1 then
  begin
    soundErrorno := SOUND_FILE_NOT_FOUND;
    Result := soundErrorno;
    Exit;
  end;

  Result := preloadBuffers(sound);
end;

// 0x49AA88
function soundRewind(sound: PSound): Integer;
var
  hr: Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.type_ and SOUND_TYPE_STREAMING) <> 0 then
  begin
    sound^.io.seek(sound^.io.fd, 0, SEEK_SET);
    sound^.lastUpdate := 0;
    sound^.lastPosition := 0;
    sound^.numBytesRead := 0;
    sound^.soundFlags_ := sound^.soundFlags_ and $FD7F;
    hr := audioEngineSoundBufferSetCurrentPosition(sound^.soundBuffer, 0);
    preloadBuffers(sound);
  end
  else
    hr := audioEngineSoundBufferSetCurrentPosition(sound^.soundBuffer, 0);

  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  sound^.statusFlags := sound^.statusFlags and (not SOUND_STATUS_DONE);

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49AB4C
function addSoundData(sound: PSound; buf: PByte; size: Integer): Integer;
var
  hr: Boolean;
  audioPtr1, audioPtr2: Pointer;
  audioBytes1, audioBytes2: LongWord;
begin
  hr := audioEngineSoundBufferLock(sound^.soundBuffer, 0, size,
    @audioPtr1, @audioBytes1, @audioPtr2, @audioBytes2,
    AUDIO_ENGINE_SOUND_BUFFER_LOCK_FROM_WRITE_POS);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  Move(buf^, audioPtr1^, audioBytes1);

  if audioPtr2 <> nil then
    Move((buf + audioBytes1)^, audioPtr2^, audioBytes2);

  hr := audioEngineSoundBufferUnlock(sound^.soundBuffer, audioPtr1, audioBytes1, audioPtr2, audioBytes2);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49AC44
function soundSetData(sound: PSound; buf: PByte; size: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if sound^.soundBuffer = -1 then
  begin
    sound^.soundBuffer := audioEngineCreateSoundBuffer(size,
      sound^.bitsPerSample, sound^.channels, sound^.rate);
    if sound^.soundBuffer = -1 then
    begin
      soundErrorno := SOUND_UNKNOWN_ERROR;
      Result := soundErrorno;
      Exit;
    end;
  end;

  Result := addSoundData(sound, buf, size);
end;

// 0x49ACC0
function soundPlay(sound: PSound): Integer;
var
  hr: Boolean;
  readPos, writePos: LongWord;
  playFlags: LongWord;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_DONE) <> 0 then
    soundRewind(sound);

  soundVolume(sound, sound^.volume);

  if (sound^.soundFlags_ and SOUND_LOOPING) <> 0 then
    playFlags := AUDIO_ENGINE_SOUND_BUFFER_PLAY_LOOPING
  else
    playFlags := 0;

  hr := audioEngineSoundBufferPlay(sound^.soundBuffer, playFlags);

  audioEngineSoundBufferGetCurrentPosition(sound^.soundBuffer, @readPos, @writePos);
  sound^.lastUpdate := readPos div LongWord(sound^.dataSize);

  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  sound^.statusFlags := sound^.statusFlags or SOUND_STATUS_IS_PLAYING;

  Inc(numSounds);

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49ADAC
function soundStop(sound: PSound): Integer;
var
  hr: Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) = 0 then
  begin
    soundErrorno := SOUND_NOT_PLAYING;
    Result := soundErrorno;
    Exit;
  end;

  hr := audioEngineSoundBufferStop(sound^.soundBuffer);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  sound^.statusFlags := sound^.statusFlags and (not SOUND_STATUS_IS_PLAYING);
  Dec(numSounds);

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49AE60
function soundDelete(sound: PSound): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if sound^.io.fd <> -1 then
  begin
    sound^.io.close(sound^.io.fd);
    sound^.io.fd := -1;
  end;

  soundMgrDelete(sound);

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49AECC
function soundContinue(sound: PSound): Integer;
var
  hr: Boolean;
  status: LongWord;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if sound^.soundBuffer = -1 then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) = 0 then
  begin
    soundErrorno := SOUND_NOT_PLAYING;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PAUSED) <> 0 then
  begin
    soundErrorno := SOUND_NOT_PLAYING;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_DONE) <> 0 then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  status := 0;
  hr := audioEngineSoundBufferGetStatus(sound^.soundBuffer, @status);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  if ((sound^.soundFlags_ and SOUND_FLAG_0x80) = 0) and
     ((status and (AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING or AUDIO_ENGINE_SOUND_BUFFER_STATUS_LOOPING)) <> 0) then
  begin
    if ((sound^.statusFlags and SOUND_STATUS_IS_PAUSED) = 0) and
       ((sound^.type_ and SOUND_TYPE_STREAMING) <> 0) then
      refreshSoundBuffers(sound);
  end
  else if (sound^.statusFlags and SOUND_STATUS_IS_PAUSED) = 0 then
  begin
    if sound^.callback <> nil then
    begin
      sound^.callback(sound^.callbackUserData, 1);
      sound^.callback := nil;
    end;

    if (sound^.type_ and $04) <> 0 then
    begin
      sound^.callback := nil;
      soundDelete(sound);
    end
    else
    begin
      sound^.statusFlags := sound^.statusFlags or SOUND_STATUS_DONE;

      if (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) <> 0 then
        Dec(numSounds);

      soundStop(sound);

      sound^.statusFlags := sound^.statusFlags and (not (SOUND_STATUS_DONE or SOUND_STATUS_IS_PLAYING));
    end;
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B008
function soundPlaying(sound: PSound): Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := False;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := False;
    Exit;
  end;

  Result := (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) <> 0;
end;

// 0x49B048
function soundDone(sound: PSound): Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := False;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := False;
    Exit;
  end;

  Result := (sound^.statusFlags and SOUND_STATUS_DONE) <> 0;
end;

// 0x49B088
function soundFading(sound: PSound): Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := False;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := False;
    Exit;
  end;

  Result := (sound^.statusFlags and SOUND_STATUS_IS_FADING) <> 0;
end;

// 0x49B0C8
function soundPaused(sound: PSound): Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := False;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := False;
    Exit;
  end;

  Result := (sound^.statusFlags and SOUND_STATUS_IS_PAUSED) <> 0;
end;

// 0x49B108
function soundFlags(sound: PSound; a2: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := 0;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := 0;
    Exit;
  end;

  Result := sound^.soundFlags_ and a2;
end;

// 0x49B148
function soundType(sound: PSound; a2: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := 0;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := 0;
    Exit;
  end;

  Result := sound^.type_ and a2;
end;

// 0x49B188
function soundLength(sound: PSound): Integer;
var
  bytesPerSec, v3, v4: Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  bytesPerSec := (sound^.bitsPerSample div 8) * sound^.rate;
  v3 := sound^.fileSize;
  v4 := v3 mod bytesPerSec;
  Result := v3 div bytesPerSec;
  if v4 <> 0 then
    Inc(Result);
end;

// 0x49B284
function soundLoop(sound: PSound; a2: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if a2 <> 0 then
  begin
    sound^.soundFlags_ := sound^.soundFlags_ or SOUND_LOOPING;
    sound^.loops := a2;
  end
  else
  begin
    sound^.loops := 0;
    sound^.field_58 := -1;
    sound^.field_54 := 0;
    sound^.soundFlags_ := sound^.soundFlags_ and (not SOUND_LOOPING);
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B2EC
function soundVolumeHMItoDirectSound(a1: Integer): Integer;
var
  normalizedVolume: Double;
begin
  if a1 > VOLUME_MAX then
    a1 := VOLUME_MAX;

  // Normalize volume to SDL (0-128).
  normalizedVolume := (a1 - VOLUME_MIN) / (VOLUME_MAX - VOLUME_MIN) * 128;
  Result := Trunc(normalizedVolume);
end;

// 0x49B38C
function soundVolume(sound: PSound; volume: Integer): Integer;
var
  normalizedVolume: Integer;
  hr: Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  sound^.volume := volume;

  if sound^.soundBuffer = -1 then
  begin
    soundErrorno := SOUND_NO_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  normalizedVolume := soundVolumeHMItoDirectSound(masterVol * volume div VOLUME_MAX);

  hr := audioEngineSoundBufferSetVolume(sound^.soundBuffer, normalizedVolume);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B400
function soundGetVolume(sound: PSound): Integer;
begin
  if deviceInit = 0 then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  Result := sound^.volume;
end;

// 0x49B570
function soundSetCallback(sound: PSound; callback: TSoundCallback; userData: Pointer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  sound^.callback := callback;
  sound^.callbackUserData := userData;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B5AC
function soundSetChannel(sound: PSound; channels: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if channels = 3 then
    sound^.channels := 2;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B630
function soundSetReadLimit(sound: PSound; readLimit: Integer): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_DEVICE;
    Result := soundErrorno;
    Exit;
  end;

  sound^.readLimit := readLimit;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B664
function soundPause(sound: PSound): Integer;
var
  hr: Boolean;
  readPos, writePos: LongWord;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if sound^.soundBuffer = -1 then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) = 0 then
  begin
    soundErrorno := SOUND_NOT_PLAYING;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PAUSED) <> 0 then
  begin
    soundErrorno := SOUND_ALREADY_PAUSED;
    Result := soundErrorno;
    Exit;
  end;

  hr := audioEngineSoundBufferGetCurrentPosition(sound^.soundBuffer, @readPos, @writePos);
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  sound^.pausePos := Integer(readPos);
  sound^.statusFlags := sound^.statusFlags or SOUND_STATUS_IS_PAUSED;

  Result := soundStop(sound);
end;

// 0x49B770
function soundUnpause(sound: PSound): Integer;
var
  hr: Boolean;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound = nil) or (sound^.soundBuffer = -1) then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) <> 0 then
  begin
    soundErrorno := SOUND_NOT_PAUSED;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.statusFlags and SOUND_STATUS_IS_PAUSED) = 0 then
  begin
    soundErrorno := SOUND_NOT_PAUSED;
    Result := soundErrorno;
    Exit;
  end;

  hr := audioEngineSoundBufferSetCurrentPosition(sound^.soundBuffer, LongWord(sound^.pausePos));
  if not hr then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  sound^.statusFlags := sound^.statusFlags and (not SOUND_STATUS_IS_PAUSED);
  sound^.pausePos := 0;

  Result := soundPlay(sound);
end;

// 0x49B87C
function soundSetFileIO(sound: PSound;
  openProc: TSoundOpenProc; closeProc: TSoundCloseProc;
  readProc: TSoundReadProc; writeProc: TSoundWriteProc;
  seekProc: TSoundSeekProc; tellProc: TSoundTellProc;
  fileLengthProc: TSoundFileLengthProc): Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if openProc <> nil then sound^.io.open := openProc;
  if closeProc <> nil then sound^.io.close := closeProc;
  if readProc <> nil then sound^.io.read := readProc;
  if writeProc <> nil then sound^.io.write := writeProc;
  if seekProc <> nil then sound^.io.seek := seekProc;
  if tellProc <> nil then sound^.io.tell := tellProc;
  if fileLengthProc <> nil then sound^.io.filelength_ := fileLengthProc;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49B8F8
procedure soundMgrDelete(sound: PSound);
var
  next, prev: PSound;
  curr: PFadeSound;
begin
  if (sound^.statusFlags and SOUND_STATUS_IS_FADING) <> 0 then
  begin
    curr := fadeHead;
    while curr <> nil do
    begin
      if sound = curr^.sound then
        Break;
      curr := curr^.next;
    end;
    removeFadeSound(curr);
  end;

  if sound^.soundBuffer <> -1 then
  begin
    if soundPlaying(sound) then
      soundStop(sound);

    if sound^.callback <> nil then
      sound^.callback(sound^.callbackUserData, 1);

    audioEngineSoundBufferRelease(sound^.soundBuffer);
    sound^.soundBuffer := -1;
  end;

  if sound^.deleteCallback <> nil then
    sound^.deleteCallback(sound^.deleteUserData);

  if sound^.data <> nil then
  begin
    freePtr_(sound^.data);
    sound^.data := nil;
  end;

  next := sound^.next;
  if next <> nil then
    next^.prev := sound^.prev;

  prev := sound^.prev;
  if prev <> nil then
    prev^.next := sound^.next
  else
    soundMgrList := sound^.next;

  freePtr_(sound);
end;

// 0x49BAF8
function soundSetMasterVolume(value: Integer): Integer;
var
  curr: PSound;
begin
  if (value < VOLUME_MIN) or (value > VOLUME_MAX) then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  masterVol := value;

  curr := soundMgrList;
  while curr <> nil do
  begin
    soundVolume(curr, curr^.volume);
    curr := curr^.next;
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49BB48
function doTimerEvent(interval: LongWord; param: Pointer): LongWord; cdecl;
type
  TVoidProc = procedure;
var
  fn: TVoidProc;
begin
  if param <> nil then
  begin
    fn := TVoidProc(param);
    fn();
  end;
  Result := 40;
end;

// 0x49BB94
procedure removeTimedEvent(var timerId: TSDL_TimerID);
begin
  if timerId <> 0 then
  begin
    SDL_RemoveTimer(timerId);
    timerId := 0;
  end;
end;

// 0x49BBB4
function soundGetPosition(sound: PSound): Integer;
var
  readPos, writePos: LongWord;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  audioEngineSoundBufferGetCurrentPosition(sound^.soundBuffer, @readPos, @writePos);

  if (sound^.type_ and SOUND_TYPE_STREAMING) <> 0 then
  begin
    if readPos < LongWord(sound^.lastPosition) then
      readPos := readPos + LongWord(sound^.numBytesRead) + LongWord(sound^.numBuffers) * LongWord(sound^.dataSize) - LongWord(sound^.lastPosition)
    else
      readPos := readPos - LongWord(sound^.lastPosition) + LongWord(sound^.numBytesRead);
  end;

  Result := Integer(readPos);
end;

// 0x49BC48
function soundSetPosition(sound: PSound; a2: Integer): Integer;
var
  section, bytesRead, bytesToRead, nextSection: Integer;
begin
  if not driverInit then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if sound^.soundBuffer = -1 then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  if (sound^.type_ and SOUND_TYPE_STREAMING) <> 0 then
  begin
    section := (a2 div sound^.dataSize) mod sound^.numBuffers;

    audioEngineSoundBufferSetCurrentPosition(sound^.soundBuffer,
      LongWord(section * sound^.dataSize + a2 mod sound^.dataSize));

    sound^.io.seek(sound^.io.fd, section * sound^.dataSize, SEEK_SET);
    bytesRead := sound^.io.read(sound^.io.fd, sound^.data, sound^.dataSize);
    if bytesRead < sound^.dataSize then
    begin
      if (sound^.type_ and $02) <> 0 then
      begin
        sound^.io.seek(sound^.io.fd, 0, SEEK_SET);
        sound^.io.read(sound^.io.fd, sound^.data + bytesRead, sound^.dataSize - bytesRead);
      end
      else
        FillChar((sound^.data + bytesRead)^, sound^.dataSize - bytesRead, 0);
    end;

    nextSection := section + 1;
    sound^.numBytesRead := a2;

    if nextSection < sound^.numBuffers then
      sound^.lastUpdate := LongWord(nextSection)
    else
      sound^.lastUpdate := 0;

    soundContinue(sound);
  end
  else
    audioEngineSoundBufferSetCurrentPosition(sound^.soundBuffer, LongWord(a2));

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49BDAC
procedure removeFadeSound(fadeSound: PFadeSound);
var
  prev, next: PFadeSound;
  tmp: PFadeSound;
begin
  if fadeSound = nil then Exit;
  if fadeSound^.sound = nil then Exit;
  if (fadeSound^.sound^.statusFlags and SOUND_STATUS_IS_FADING) = 0 then Exit;

  prev := fadeSound^.prev;
  if prev <> nil then
    prev^.next := fadeSound^.next
  else
    fadeHead := fadeSound^.next;

  next := fadeSound^.next;
  if next <> nil then
    next^.prev := fadeSound^.prev;

  fadeSound^.sound^.statusFlags := fadeSound^.sound^.statusFlags and (not SOUND_STATUS_IS_FADING);
  fadeSound^.sound := nil;

  tmp := fadeFreeList;
  fadeFreeList := fadeSound;
  fadeSound^.next := tmp;
end;

// 0x49BE2C
procedure fadeSounds;
var
  ptr: PFadeSound;
begin
  ptr := fadeHead;
  while ptr <> nil do
  begin
    if ((ptr^.currentVolume > ptr^.targetVolume) or
        (ptr^.currentVolume + ptr^.deltaVolume < ptr^.targetVolume)) and
       ((ptr^.currentVolume < ptr^.targetVolume) or
        (ptr^.currentVolume + ptr^.deltaVolume > ptr^.targetVolume)) then
    begin
      ptr^.currentVolume := ptr^.currentVolume + ptr^.deltaVolume;
      soundVolume(ptr^.sound, ptr^.currentVolume);
    end
    else
    begin
      if ptr^.targetVolume = 0 then
      begin
        if ptr^.field_14 <> 0 then
        begin
          soundPause(ptr^.sound);
          soundVolume(ptr^.sound, ptr^.initialVolume);
        end
        else
        begin
          if (ptr^.sound^.type_ and $04) <> 0 then
            soundDelete(ptr^.sound)
          else
          begin
            soundStop(ptr^.sound);
            ptr^.initialVolume := ptr^.targetVolume;
            ptr^.currentVolume := ptr^.targetVolume;
            ptr^.deltaVolume := 0;
            soundVolume(ptr^.sound, ptr^.targetVolume);
          end;
        end;
      end;

      removeFadeSound(ptr);
    end;

    ptr := ptr^.next;
  end;

  if fadeHead = nil then
    removeTimedEvent(gFadeSoundsTimerId);
end;

// 0x49BF04
function internalSoundFade(sound: PSound; duration, targetVolume, a4: Integer): Integer;
var
  ptr: PFadeSound;
  shouldPlay: Boolean;
begin
  if deviceInit = 0 then
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    Result := soundErrorno;
    Exit;
  end;

  if sound = nil then
  begin
    soundErrorno := SOUND_NO_SOUND;
    Result := soundErrorno;
    Exit;
  end;

  ptr := nil;
  if (sound^.statusFlags and SOUND_STATUS_IS_FADING) <> 0 then
  begin
    ptr := fadeHead;
    while ptr <> nil do
    begin
      if ptr^.sound = sound then
        Break;
      ptr := ptr^.next;
    end;
  end;

  if ptr = nil then
  begin
    if fadeFreeList <> nil then
    begin
      ptr := fadeFreeList;
      fadeFreeList := fadeFreeList^.next;
    end
    else
      ptr := PFadeSound(mallocPtr(SizeOf(TFadeSound)));

    if ptr <> nil then
    begin
      if fadeHead <> nil then
        fadeHead^.prev := ptr;

      ptr^.sound := sound;
      ptr^.prev := nil;
      ptr^.next := fadeHead;
      fadeHead := ptr;
    end;
  end;

  if ptr = nil then
  begin
    soundErrorno := SOUND_NO_MEMORY_AVAILABLE;
    Result := soundErrorno;
    Exit;
  end;

  ptr^.targetVolume := targetVolume;
  ptr^.initialVolume := soundGetVolume(sound);
  ptr^.currentVolume := ptr^.initialVolume;
  ptr^.field_14 := a4;
  ptr^.deltaVolume := 8 * (125 * (targetVolume - ptr^.initialVolume)) div (40 * duration);

  sound^.statusFlags := sound^.statusFlags or SOUND_STATUS_IS_FADING;

  if driverInit then
  begin
    if sound^.soundBuffer <> -1 then
      shouldPlay := (sound^.statusFlags and SOUND_STATUS_IS_PLAYING) = 0
    else
    begin
      soundErrorno := SOUND_NO_SOUND;
      shouldPlay := True;
    end;
  end
  else
  begin
    soundErrorno := SOUND_NOT_INITIALIZED;
    shouldPlay := True;
  end;

  if shouldPlay then
    soundPlay(sound);

  if gFadeSoundsTimerId <> 0 then
  begin
    soundErrorno := SOUND_NO_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  gFadeSoundsTimerId := SDL_AddTimer(40, @doTimerEvent, @fadeSounds);
  if gFadeSoundsTimerId = 0 then
  begin
    soundErrorno := SOUND_UNKNOWN_ERROR;
    Result := soundErrorno;
    Exit;
  end;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

// 0x49C088
function soundFade(sound: PSound; duration, targetVolume: Integer): Integer;
begin
  Result := internalSoundFade(sound, duration, targetVolume, 0);
end;

// 0x49C0D0
procedure soundFlushAllSounds;
begin
  while soundMgrList <> nil do
    soundDelete(soundMgrList);
end;

// 0x49C15C
procedure soundUpdate;
var
  curr, next: PSound;
begin
  curr := soundMgrList;
  while curr <> nil do
  begin
    // Sound can be deallocated in soundContinue
    next := curr^.next;
    soundContinue(curr);
    curr := next;
  end;
end;

// 0x49C17C
function soundSetDefaultFileIO(
  openProc: TSoundOpenProc; closeProc: TSoundCloseProc;
  readProc: TSoundReadProc; writeProc: TSoundWriteProc;
  seekProc: TSoundSeekProc; tellProc: TSoundTellProc;
  fileLengthProc: TSoundFileLengthProc): Integer;
begin
  initDefaultStream;

  if openProc <> nil then defaultStream.open := openProc;
  if closeProc <> nil then defaultStream.close := closeProc;
  if readProc <> nil then defaultStream.read := readProc;
  if writeProc <> nil then defaultStream.write := writeProc;
  if seekProc <> nil then defaultStream.seek := seekProc;
  if tellProc <> nil then defaultStream.tell := tellProc;
  if fileLengthProc <> nil then defaultStream.filelength_ := fileLengthProc;

  soundErrorno := SOUND_NO_ERROR;
  Result := soundErrorno;
end;

procedure soundExit;
begin
  soundFlushAllSounds;
end;

end.
