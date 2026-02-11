{$MODE OBJFPC}{$H+}
// Converted from: src/audio_engine.h + audio_engine.cc
// SDL2-based audio engine with sound buffer management.
unit u_audio_engine;

interface

const
  AUDIO_ENGINE_SOUND_BUFFER_LOCK_FROM_WRITE_POS = $00000001;
  AUDIO_ENGINE_SOUND_BUFFER_LOCK_ENTIRE_BUFFER  = $00000002;

  AUDIO_ENGINE_SOUND_BUFFER_PLAY_LOOPING = $00000001;

  AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING = $00000001;
  AUDIO_ENGINE_SOUND_BUFFER_STATUS_LOOPING = $00000004;

function audioEngineInit: Boolean;
procedure audioEngineExit;
procedure audioEnginePause;
procedure audioEngineResume;
function audioEngineCreateSoundBuffer(size: LongWord; bitsPerSample, channels, rate: Integer): Integer;
function audioEngineSoundBufferRelease(soundBufferIndex: Integer): Boolean;
function audioEngineSoundBufferSetVolume(soundBufferIndex, volume: Integer): Boolean;
function audioEngineSoundBufferGetVolume(soundBufferIndex: Integer; volumePtr: PInteger): Boolean;
function audioEngineSoundBufferSetPan(soundBufferIndex, pan: Integer): Boolean;
function audioEngineSoundBufferPlay(soundBufferIndex: Integer; flags: LongWord): Boolean;
function audioEngineSoundBufferStop(soundBufferIndex: Integer): Boolean;
function audioEngineSoundBufferGetCurrentPosition(soundBufferIndex: Integer; readPosPtr, writePosPtr: PLongWord): Boolean;
function audioEngineSoundBufferSetCurrentPosition(soundBufferIndex: Integer; pos: LongWord): Boolean;
function audioEngineSoundBufferLock(soundBufferIndex: Integer; writePos, writeBytes: LongWord;
  audioPtr1: PPointer; audioBytes1: PLongWord; audioPtr2: PPointer; audioBytes2: PLongWord;
  flags: LongWord): Boolean;
function audioEngineSoundBufferUnlock(soundBufferIndex: Integer; audioPtr1: Pointer; audioBytes1: LongWord;
  audioPtr2: Pointer; audioBytes2: LongWord): Boolean;
function audioEngineSoundBufferGetStatus(soundBufferIndex: Integer; statusPtr: PLongWord): Boolean;

implementation

uses
  SysUtils, u_sdl2, u_winmain;

const
  AUDIO_ENGINE_SOUND_BUFFERS = 8;

type
  TAudioEngineSoundBuffer = record
    active: Boolean;
    size: LongWord;
    bitsPerSample: Integer;
    channels: Integer;
    rate: Integer;
    data: Pointer;
    volume: Integer;
    playing: Boolean;
    looping: Boolean;
    pos: LongWord;
    stream: PSDL_AudioStream;
    lock: TRTLCriticalSection;
  end;

var
  gAudioEngineSpec: TSDL_AudioSpec;
  gAudioEngineDeviceId: TSDL_AudioDeviceID = TSDL_AudioDeviceID(-1);
  gAudioEngineSoundBuffers: array[0..AUDIO_ENGINE_SOUND_BUFFERS - 1] of TAudioEngineSoundBuffer;
  gAudioEngineLockInited: Boolean = False;

function audioEngineIsInitialized: Boolean;
begin
  Result := gAudioEngineDeviceId <> TSDL_AudioDeviceID(-1);
end;

function soundBufferIsValid(soundBufferIndex: Integer): Boolean;
begin
  Result := (soundBufferIndex >= 0) and (soundBufferIndex < AUDIO_ENGINE_SOUND_BUFFERS);
end;

procedure audioEngineMixin(userData: Pointer; stream: PByte; length: Integer); cdecl;
var
  index, pos, remaining, srcFrameSize, bytesRead: Integer;
  soundBuffer: ^TAudioEngineSoundBuffer;
  buffer: array[0..1023] of Byte;
begin
  FillChar(stream^, length, gAudioEngineSpec.silence);

  // TODO: check GNW95_isActive

  for index := 0 to AUDIO_ENGINE_SOUND_BUFFERS - 1 do
  begin
    soundBuffer := @gAudioEngineSoundBuffers[index];
    EnterCriticalSection(soundBuffer^.lock);
    try
      if soundBuffer^.active and soundBuffer^.playing then
      begin
        srcFrameSize := (soundBuffer^.bitsPerSample div 8) * soundBuffer^.channels;

        pos := 0;
        while pos < length do
        begin
          remaining := length - pos;
          if remaining > SizeOf(buffer) then
            remaining := SizeOf(buffer);

          SDL_AudioStreamPut(soundBuffer^.stream,
            PByte(soundBuffer^.data) + soundBuffer^.pos, srcFrameSize);
          soundBuffer^.pos := soundBuffer^.pos + LongWord(srcFrameSize);

          bytesRead := SDL_AudioStreamGet(soundBuffer^.stream, @buffer[0], remaining);
          if bytesRead = -1 then
            Break;

          SDL_MixAudioFormat(stream + pos, @buffer[0], gAudioEngineSpec.format,
            LongWord(bytesRead), soundBuffer^.volume);

          if soundBuffer^.pos >= soundBuffer^.size then
          begin
            if soundBuffer^.looping then
              soundBuffer^.pos := soundBuffer^.pos mod soundBuffer^.size
            else
            begin
              soundBuffer^.playing := False;
              Break;
            end;
          end;

          pos := pos + bytesRead;
        end;
      end;
    finally
      LeaveCriticalSection(soundBuffer^.lock);
    end;
  end;
end;

function audioEngineInit: Boolean;
var
  desiredSpec: TSDL_AudioSpec;
  i: Integer;
begin
  if SDL_InitSubSystem(SDL_INIT_AUDIO) = -1 then
    Exit(False);

  FillChar(desiredSpec, SizeOf(desiredSpec), 0);
  desiredSpec.freq := 22050;
  desiredSpec.format := AUDIO_S16;
  desiredSpec.channels := 2;
  desiredSpec.samples := 1024;
  desiredSpec.callback := @audioEngineMixin;

  gAudioEngineDeviceId := SDL_OpenAudioDevice(nil, 0, @desiredSpec, @gAudioEngineSpec, SDL_AUDIO_ALLOW_ANY_CHANGE);
  if gAudioEngineDeviceId = TSDL_AudioDeviceID(-1) then
    Exit(False);

  if not gAudioEngineLockInited then
  begin
    for i := 0 to AUDIO_ENGINE_SOUND_BUFFERS - 1 do
      InitCriticalSection(gAudioEngineSoundBuffers[i].lock);
    gAudioEngineLockInited := True;
  end;

  SDL_PauseAudioDevice(gAudioEngineDeviceId, 0);

  Result := True;
end;

procedure audioEngineExit;
var
  i: Integer;
begin
  if audioEngineIsInitialized then
  begin
    SDL_CloseAudioDevice(gAudioEngineDeviceId);
    gAudioEngineDeviceId := TSDL_AudioDeviceID(-1);
  end;

  if SDL_WasInit(SDL_INIT_AUDIO) <> 0 then
    SDL_QuitSubSystem(SDL_INIT_AUDIO);

  if gAudioEngineLockInited then
  begin
    for i := 0 to AUDIO_ENGINE_SOUND_BUFFERS - 1 do
      DoneCriticalSection(gAudioEngineSoundBuffers[i].lock);
    gAudioEngineLockInited := False;
  end;
end;

procedure audioEnginePause;
begin
  if audioEngineIsInitialized then
    SDL_PauseAudioDevice(gAudioEngineDeviceId, 1);
end;

procedure audioEngineResume;
begin
  if audioEngineIsInitialized then
    SDL_PauseAudioDevice(gAudioEngineDeviceId, 0);
end;

function audioEngineCreateSoundBuffer(size: LongWord; bitsPerSample, channels, rate: Integer): Integer;
var
  index: Integer;
  soundBuffer: ^TAudioEngineSoundBuffer;
  fmt: TSDL_AudioFormat;
begin
  if not audioEngineIsInitialized then
    Exit(-1);

  for index := 0 to AUDIO_ENGINE_SOUND_BUFFERS - 1 do
  begin
    soundBuffer := @gAudioEngineSoundBuffers[index];
    EnterCriticalSection(soundBuffer^.lock);
    try
      if not soundBuffer^.active then
      begin
        soundBuffer^.active := True;
        soundBuffer^.size := size;
        soundBuffer^.bitsPerSample := bitsPerSample;
        soundBuffer^.channels := channels;
        soundBuffer^.rate := rate;
        soundBuffer^.volume := SDL_MIX_MAXVOLUME;
        soundBuffer^.playing := False;
        soundBuffer^.looping := False;
        soundBuffer^.pos := 0;
        soundBuffer^.data := GetMem(size);
        if bitsPerSample = 16 then
          fmt := AUDIO_S16
        else
          fmt := AUDIO_S8;
        soundBuffer^.stream := SDL_NewAudioStream(fmt, channels, rate,
          gAudioEngineSpec.format, gAudioEngineSpec.channels, gAudioEngineSpec.freq);
        Exit(index);
      end;
    finally
      LeaveCriticalSection(soundBuffer^.lock);
    end;
  end;

  Result := -1;
end;

function audioEngineSoundBufferRelease(soundBufferIndex: Integer): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);

    soundBuffer^.active := False;

    FreeMem(soundBuffer^.data);
    soundBuffer^.data := nil;

    SDL_FreeAudioStream(soundBuffer^.stream);
    soundBuffer^.stream := nil;

    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferSetVolume(soundBufferIndex, volume: Integer): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    soundBuffer^.volume := volume;
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferGetVolume(soundBufferIndex: Integer; volumePtr: PInteger): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    volumePtr^ := soundBuffer^.volume;
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferSetPan(soundBufferIndex, pan: Integer): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    // NOTE: Panning not supported, silently ignored.
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferPlay(soundBufferIndex: Integer; flags: LongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);

    soundBuffer^.playing := True;

    if (flags and AUDIO_ENGINE_SOUND_BUFFER_PLAY_LOOPING) <> 0 then
      soundBuffer^.looping := True;

    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferStop(soundBufferIndex: Integer): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    soundBuffer^.playing := False;
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferGetCurrentPosition(soundBufferIndex: Integer; readPosPtr, writePosPtr: PLongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);

    if readPosPtr <> nil then
      readPosPtr^ := soundBuffer^.pos;

    if writePosPtr <> nil then
    begin
      writePosPtr^ := soundBuffer^.pos;

      if soundBuffer^.playing then
      begin
        // 15 ms lead
        writePosPtr^ := writePosPtr^ + LongWord(soundBuffer^.rate div 150);
        writePosPtr^ := writePosPtr^ mod soundBuffer^.size;
      end;
    end;

    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferSetCurrentPosition(soundBufferIndex: Integer; pos: LongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    soundBuffer^.pos := pos mod soundBuffer^.size;
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferLock(soundBufferIndex: Integer; writePos, writeBytes: LongWord;
  audioPtr1: PPointer; audioBytes1: PLongWord; audioPtr2: PPointer; audioBytes2: PLongWord;
  flags: LongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
  remainder: LongWord;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);

    if audioBytes1 = nil then Exit(False);

    if (flags and AUDIO_ENGINE_SOUND_BUFFER_LOCK_FROM_WRITE_POS) <> 0 then
    begin
      if not audioEngineSoundBufferGetCurrentPosition(soundBufferIndex, nil, @writePos) then
        Exit(False);
    end;

    if (flags and AUDIO_ENGINE_SOUND_BUFFER_LOCK_ENTIRE_BUFFER) <> 0 then
      writeBytes := soundBuffer^.size;

    if writePos + writeBytes <= soundBuffer^.size then
    begin
      PPointer(audioPtr1)^ := PByte(soundBuffer^.data) + writePos;
      audioBytes1^ := writeBytes;

      if audioPtr2 <> nil then
        audioPtr2^ := nil;

      if audioBytes2 <> nil then
        audioBytes2^ := 0;
    end
    else
    begin
      remainder := writePos + writeBytes - soundBuffer^.size;
      PPointer(audioPtr1)^ := PByte(soundBuffer^.data) + writePos;
      audioBytes1^ := soundBuffer^.size - writePos;

      if audioPtr2 <> nil then
        PPointer(audioPtr2)^ := soundBuffer^.data;

      if audioBytes2 <> nil then
        audioBytes2^ := writeBytes - (soundBuffer^.size - writePos);
    end;

    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferUnlock(soundBufferIndex: Integer; audioPtr1: Pointer; audioBytes1: LongWord;
  audioPtr2: Pointer; audioBytes2: LongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);
    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

function audioEngineSoundBufferGetStatus(soundBufferIndex: Integer; statusPtr: PLongWord): Boolean;
var
  soundBuffer: ^TAudioEngineSoundBuffer;
begin
  if not audioEngineIsInitialized then Exit(False);
  if not soundBufferIsValid(soundBufferIndex) then Exit(False);

  soundBuffer := @gAudioEngineSoundBuffers[soundBufferIndex];
  EnterCriticalSection(soundBuffer^.lock);
  try
    if not soundBuffer^.active then Exit(False);

    if statusPtr = nil then Exit(False);

    statusPtr^ := 0;

    if soundBuffer^.playing then
    begin
      statusPtr^ := statusPtr^ or AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING;

      if soundBuffer^.looping then
        statusPtr^ := statusPtr^ or AUDIO_ENGINE_SOUND_BUFFER_STATUS_LOOPING;
    end;

    Result := True;
  finally
    LeaveCriticalSection(soundBuffer^.lock);
  end;
end;

end.
