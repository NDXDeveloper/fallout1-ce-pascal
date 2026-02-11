{$MODE OBJFPC}{$H+}
// Converted from: src/game/gsound.h + gsound.cc
// Game sound system: background music, speech, sound effects, UI button sounds.
unit u_gsound;

interface

uses
  u_config, u_object_types, u_rect, u_proto_types, u_int_sound;

const
  // Volume constants (from sound.h)
  VOLUME_MIN = 0;
  VOLUME_MAX = $7FFF;

  // SoundError
  SOUND_NO_ERROR = 0;

  // WeaponSoundEffect
  WEAPON_SOUND_EFFECT_READY       = 0;
  WEAPON_SOUND_EFFECT_ATTACK      = 1;
  WEAPON_SOUND_EFFECT_OUT_OF_AMMO = 2;
  WEAPON_SOUND_EFFECT_AMMO_FLYING = 3;
  WEAPON_SOUND_EFFECT_HIT         = 4;
  WEAPON_SOUND_EFFECT_COUNT       = 5;

  // SoundEffectActionType
  SOUND_EFFECT_ACTION_TYPE_ACTIVE  = 0;
  SOUND_EFFECT_ACTION_TYPE_PASSIVE = 1;

  // ScenerySoundEffect
  SCENERY_SOUND_EFFECT_OPEN     = 0;
  SCENERY_SOUND_EFFECT_CLOSED   = 1;
  SCENERY_SOUND_EFFECT_LOCKED   = 2;
  SCENERY_SOUND_EFFECT_UNLOCKED = 3;
  SCENERY_SOUND_EFFECT_USED     = 4;
  SCENERY_SOUND_EFFECT_COUNT    = 5;

  // CharacterSoundEffect
  CHARACTER_SOUND_EFFECT_UNUSED    = 0;
  CHARACTER_SOUND_EFFECT_KNOCKDOWN = 1;
  CHARACTER_SOUND_EFFECT_PASS_OUT  = 2;
  CHARACTER_SOUND_EFFECT_DIE       = 3;
  CHARACTER_SOUND_EFFECT_CONTACT   = 4;

type
  TSoundEndCallback = procedure; cdecl;
  PSoundEndCallback = ^TSoundEndCallback;

// Public path strings (used by other modules)
var
  _aSoundSfx: array[0..15] of AnsiChar;
  _aSoundMusic_0: array[0..15] of AnsiChar;
  _aSoundSpeech_0: array[0..15] of AnsiChar;

function gsound_init: Integer;
procedure gsound_reset;
function gsound_exit: Integer;
procedure gsound_sfx_enable;
procedure gsound_sfx_disable;
function gsound_sfx_is_enabled: Integer;
function gsound_set_master_volume(value: Integer): Integer;
function gsound_get_master_volume: Integer;
function gsound_set_sfx_volume(value: Integer): Integer;
function gsound_get_sfx_volume: Integer;
procedure gsound_background_disable;
procedure gsound_background_enable;
function gsound_background_is_enabled: Integer;
procedure gsound_background_volume_set(value: Integer);
function gsound_background_volume_get: Integer;
function gsound_background_volume_get_set(a1: Integer): Integer;
procedure gsound_background_fade_set(value: Integer);
function gsound_background_fade_get: Integer;
function gsound_background_fade_get_set(value: Integer): Integer;
procedure gsound_background_callback_set(callback: TSoundEndCallback);
function gsound_background_callback_get: TSoundEndCallback;
function gsound_background_callback_get_set(callback: TSoundEndCallback): TSoundEndCallback;
function gsound_background_length_get: Integer;
function gsound_background_play(const fileName: PAnsiChar; a2, a3, a4: Integer): Integer;
function gsound_background_play_level_music(const a1: PAnsiChar; a2: Integer): Integer;
function gsound_background_play_preloaded: Integer;
procedure gsound_background_stop;
procedure gsound_background_restart_last(value: Integer);
procedure gsound_background_pause;
procedure gsound_background_unpause;
procedure gsound_speech_disable;
procedure gsound_speech_enable;
function gsound_speech_is_enabled: Integer;
procedure gsound_speech_volume_set(value: Integer);
function gsound_speech_volume_get: Integer;
function gsound_speech_volume_get_set(volume: Integer): Integer;
procedure gsound_speech_callback_set(callback: TSoundEndCallback);
function gsound_speech_callback_get: TSoundEndCallback;
function gsound_speech_callback_get_set(callback: TSoundEndCallback): TSoundEndCallback;
function gsound_speech_length_get: Integer;
function gsound_speech_play(const fname: PAnsiChar; a2, a3, a4: Integer): Integer;
function gsound_speech_play_preloaded: Integer;
procedure gsound_speech_stop;
procedure gsound_speech_pause;
procedure gsound_speech_unpause;
function gsound_play_sfx_file_volume(const a1: PAnsiChar; a2: Integer): Integer;
function gsound_load_sound(const name: PAnsiChar; a2: PObject): PSound;
function gsound_load_sound_volume(const a1: PAnsiChar; a2: PObject; a3: Integer): PSound;
procedure gsound_delete_sfx(a1: PSound);
function gsnd_anim_sound(sound: PSound; a2: Pointer): Integer;
function gsound_play_sound(a1: PSound): Integer;
function gsound_compute_relative_volume(obj: PObject): Integer;
function gsnd_build_character_sfx_name(a1: PObject; anim, extra: Integer): PAnsiChar;
function gsnd_build_ambient_sfx_name(const a1: PAnsiChar): PAnsiChar;
function gsnd_build_interface_sfx_name(const a1: PAnsiChar): PAnsiChar;
function gsnd_build_weapon_sfx_name(effectType: Integer; weapon: PObject; hitMode: Integer; target: PObject): PAnsiChar;
function gsnd_build_scenery_sfx_name(actionType, action: Integer; const name: PAnsiChar): PAnsiChar;
function gsnd_build_open_sfx_name(a1: PObject; a2: Integer): PAnsiChar;
procedure gsound_red_butt_press(btn, keyCode: Integer); cdecl;
procedure gsound_red_butt_release(btn, keyCode: Integer); cdecl;
procedure gsound_toggle_butt_press(btn, keyCode: Integer); cdecl;
procedure gsound_toggle_butt_release(btn, keyCode: Integer); cdecl;
procedure gsound_med_butt_press(btn, keyCode: Integer); cdecl;
procedure gsound_med_butt_release(btn, keyCode: Integer); cdecl;
procedure gsound_lrg_butt_press(btn, keyCode: Integer); cdecl;
procedure gsound_lrg_butt_release(btn, keyCode: Integer); cdecl;
function gsound_play_sfx_file(const name: PAnsiChar): Integer;

implementation

uses
  SysUtils,
  u_platform_compat,
  u_gconfig,
  u_debug,
  u_memory,
  u_db,
  u_sfxcache,
  u_input,
  u_int_audio,
  u_int_audiof,
  u_int_movie,
  u_pointer_registry,
  u_object,
  u_map,
  u_stat,
  u_item,
  u_proto,
  u_art,
  u_gnw;

// ---------------------------------------------------------------------------
// Constants not yet available from shared _defs units
// ---------------------------------------------------------------------------
const
  SOUND_EFFECTS_MAX_COUNT = 4;

  // Anim constants (from anim.h)
  ANIM_THROW_PUNCH = 16;
  ANIM_KICK_LEG    = 17;
  ANIM_FALL_BACK   = 20;
  ANIM_FALL_FRONT  = 21;
  ANIM_TAKE_OUT    = 38;

  // HitMode constants (from combat_defs.h)
  HIT_MODE_LEFT_WEAPON_PRIMARY  = 0;
  HIT_MODE_RIGHT_WEAPON_PRIMARY = 2;
  HIT_MODE_PUNCH                = 4;

  // Stat constants (from stat_defs.h)
  STAT_STRENGTH   = 0;
  STAT_PERCEPTION = 1;
  STAT_GENDER     = 34;

// ---------------------------------------------------------------------------
// Forward declarations (static functions)
// ---------------------------------------------------------------------------
procedure gsound_bkg_proc; forward;
function gsound_open(const fname: PAnsiChar; flags: Integer): Integer; cdecl; forward;
function gsound_compressed_tell(handle: Integer): LongInt; cdecl; forward;
function gsound_write(handle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl; forward;
function gsound_close(handle: Integer): Integer; cdecl; forward;
function gsound_read(handle: Integer; buf: Pointer; size: LongWord): Integer; cdecl; forward;
function gsound_seek(handle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl; forward;
function gsound_tell(handle: Integer): LongInt; cdecl; forward;
function gsound_filesize(handle: Integer): LongInt; cdecl; forward;
function gsound_compressed_query(filePath: PAnsiChar): Boolean; cdecl; forward;
procedure gsound_internal_speech_callback(userData: Pointer; a2: Integer); cdecl; forward;
procedure gsound_internal_background_callback(userData: Pointer; a2: Integer); cdecl; forward;
procedure gsound_internal_effect_callback(userData: Pointer; a2: Integer); cdecl; forward;
function gsound_background_allocate(out_s: PPointer; a2, a3: Integer): Integer; forward;
function gsound_background_find_with_copy(dest: PAnsiChar; const src: PAnsiChar): Integer; forward;
function gsound_background_find_dont_copy(dest: PAnsiChar; const src: PAnsiChar): Integer; forward;
function gsound_speech_find_dont_copy(dest: PAnsiChar; const src: PAnsiChar): Integer; forward;
procedure gsound_background_remove_last_copy; forward;
function gsound_background_start: Integer; forward;
function gsound_speech_start: Integer; forward;
function gsound_get_music_path(out_value: PPAnsiChar; const key: PAnsiChar): Integer; forward;
procedure gsound_check_active_effects; forward;
function gsound_get_sound_ready_for_effect: PSound; forward;
function gsound_file_exists_f(const fname: PAnsiChar): Boolean; forward;
function gsound_file_exists_db(const path: PAnsiChar): Integer; forward;
function gsound_setup_paths: Integer; forward;

// ---------------------------------------------------------------------------
// Unit-level variables (C static)
// ---------------------------------------------------------------------------
var
  gsound_initialized: Boolean = False;
  gsound_debug: Boolean = False;
  gsound_background_enabled: Boolean = False;
  gsound_background_df_vol: Integer = 0;
  gsound_background_fade: Integer = 0;
  gsound_speech_enabled: Boolean = False;
  gsound_sfx_enabled: Boolean = False;
  gsound_active_effect_counter: Integer = 0;
  gsound_background_tag: PSound = nil;
  gsound_speech_tag: PSound = nil;
  gsound_background_callback_fp: TSoundEndCallback = nil;
  gsound_speech_callback_fp: TSoundEndCallback = nil;

  snd_lookup_weapon_type: array[0..WEAPON_SOUND_EFFECT_COUNT - 1] of AnsiChar = (
    'R', // Ready
    'A', // Attack
    'O', // Out of ammo
    'F', // Firing
    'H'  // Hit
  );

  snd_lookup_scenery_action: array[0..SCENERY_SOUND_EFFECT_COUNT - 1] of AnsiChar = (
    'O', // Open
    'C', // Close
    'L', // Lock
    'N', // Unlock
    'U'  // Use
  );

  background_storage_requested: Integer = -1;
  background_loop_requested: Integer = -1;

  sound_sfx_path: PAnsiChar;
  sound_music_path1: PAnsiChar;
  sound_music_path2: PAnsiChar;
  sound_speech_path: PAnsiChar;

  master_volume: Integer = VOLUME_MAX;
  background_volume: Integer = VOLUME_MAX;
  speech_volume: Integer = VOLUME_MAX;
  sndfx_volume: Integer = VOLUME_MAX;
  detectDevices: Integer = -1;

  background_fname_copied: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  sfx_file_name: array[0..12] of AnsiChar;
  background_fname_requested: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;

// libc imports
function libc_fopen(path, mode: PAnsiChar): Pointer; cdecl; external 'c' name 'fopen';
function libc_fclose(stream: Pointer): Integer; cdecl; external 'c' name 'fclose';
function libc_fread(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fread';
function libc_fwrite(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fwrite';
function libc_feof(stream: Pointer): Integer; cdecl; external 'c' name 'feof';

// ---------------------------------------------------------------------------
// cdecl wrappers for mem_malloc/mem_realloc/mem_free
// ---------------------------------------------------------------------------
function mem_malloc_cdecl(size: SizeUInt): Pointer; cdecl;
begin
  Result := mem_malloc(size);
end;

function mem_realloc_cdecl(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
begin
  Result := mem_realloc(ptr, size);
end;

procedure mem_free_cdecl(ptr: Pointer); cdecl;
begin
  mem_free(ptr);
end;

// ---------------------------------------------------------------------------
// gsound_init
// ---------------------------------------------------------------------------
function gsound_init: Integer;
var
  initialize: Boolean;
  sounds: Boolean;
  music: Boolean;
  speech: Boolean;
  cacheSize: Integer;
begin
  if gsound_initialized then
  begin
    if gsound_debug then
      debug_printf('Trying to initialize gsound twice.'#10);
    Exit(-1);
  end;

  initialize := False;
  configGetBool(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_INITIALIZE_KEY, @initialize);
  if not initialize then
    Exit(0);

  configGetBool(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_DEBUG_KEY, @gsound_debug);

  if gsound_debug then
    debug_printf('Initializing sound system...');

  if gsound_get_music_path(@sound_music_path1, GAME_CONFIG_MUSIC_PATH1_KEY) <> 0 then
    Exit(-1);

  if gsound_get_music_path(@sound_music_path2, GAME_CONFIG_MUSIC_PATH2_KEY) <> 0 then
    Exit(-1);

  if (StrLen(sound_music_path1) > 247) or (StrLen(sound_music_path2) > 247) then
  begin
    if gsound_debug then
      debug_printf('Music paths way too long.'#10);
    Exit(-1);
  end;

  if gsound_setup_paths <> 0 then
    Exit(-1);

  soundRegisterAlloc(@mem_malloc_cdecl, @mem_realloc_cdecl, @mem_free_cdecl);

  if soundInit(detectDevices, 24, $8000, $8000, 22050) <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed!'#10);
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf('success.'#10);

  initAudiof(@gsound_compressed_query);
  initAudio(@gsound_compressed_query);

  cacheSize := 0;
  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_CACHE_SIZE_KEY, @cacheSize);
  if cacheSize >= $40000 then
  begin
    debug_printf(#10'!!! Config file needs adustment.  Please remove the ');
    debug_printf('cache_size line and run fallout again.  This will reset ');
    debug_printf('cache_size to the new default, which is expressed in K.'#10);
    Exit(-1);
  end;

  if sfxc_init(cacheSize shl 10, sound_sfx_path) <> 0 then
  begin
    if gsound_debug then
      debug_printf('Unable to initialize sound effects cache.'#10);
  end;

  if soundSetDefaultFileIO(@gsound_open, @gsound_close, @gsound_read, @gsound_write, @gsound_seek, @gsound_tell, @gsound_filesize) <> 0 then
  begin
    if gsound_debug then
      debug_printf('Failure setting sound I/O calls.'#10);
    Exit(-1);
  end;

  add_bk_process(TBackgroundProcess(@gsound_bkg_proc));
  gsound_initialized := True;

  // SOUNDS
  sounds := False;
  configGetBool(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SOUNDS_KEY, @sounds);

  if gsound_debug then
    debug_printf('Sounds are ');

  if sounds then
  begin
    gsound_sfx_enable;
  end
  else
  begin
    if gsound_debug then
      debug_printf(' not ');
  end;

  if gsound_debug then
    debug_printf('on.'#10);

  // MUSIC
  music := False;
  configGetBool(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_KEY, @music);

  if gsound_debug then
    debug_printf('Music is ');

  if music then
  begin
    gsound_background_enable;
  end
  else
  begin
    if gsound_debug then
      debug_printf(' not ');
  end;

  if gsound_debug then
    debug_printf('on.'#10);

  // SPEECH
  speech := False;
  configGetBool(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_KEY, @speech);

  if gsound_debug then
    debug_printf('Speech is ');

  if speech then
  begin
    gsound_speech_enable;
  end
  else
  begin
    if gsound_debug then
      debug_printf(' not ');
  end;

  if gsound_debug then
    debug_printf('on.'#10);

  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MASTER_VOLUME_KEY, @master_volume);
  gsound_set_master_volume(master_volume);

  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_VOLUME_KEY, @background_volume);
  gsound_background_volume_set(background_volume);

  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SNDFX_VOLUME_KEY, @sndfx_volume);
  gsound_set_sfx_volume(sndfx_volume);

  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_VOLUME_KEY, @speech_volume);
  gsound_speech_volume_set(speech_volume);

  gsound_background_fade_set(0);
  background_fname_requested[0] := #0;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_reset
// ---------------------------------------------------------------------------
procedure gsound_reset;
begin
  if not gsound_initialized then
    Exit;

  if gsound_debug then
    debug_printf('Resetting sound system...');

  gsound_speech_stop;

  if gsound_background_df_vol <> 0 then
  begin
    gsound_background_enable;
  end;

  gsound_background_stop;

  gsound_background_fade_set(0);

  soundFlushAllSounds;

  sfxc_flush;

  gsound_active_effect_counter := 0;

  if gsound_debug then
    debug_printf('done.'#10);
end;

// ---------------------------------------------------------------------------
// gsound_exit
// ---------------------------------------------------------------------------
function gsound_exit: Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  remove_bk_process(TBackgroundProcess(@gsound_bkg_proc));

  gsound_speech_stop;

  gsound_background_stop;
  gsound_background_remove_last_copy;
  soundClose;
  sfxc_exit;
  audiofClose;
  audioClose;

  gsound_initialized := False;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_sfx_enable / disable / is_enabled
// ---------------------------------------------------------------------------
procedure gsound_sfx_enable;
begin
  if gsound_initialized then
    gsound_sfx_enabled := True;
end;

procedure gsound_sfx_disable;
begin
  if gsound_initialized then
    gsound_sfx_enabled := False;
end;

function gsound_sfx_is_enabled: Integer;
begin
  Result := Ord(gsound_sfx_enabled);
end;

// ---------------------------------------------------------------------------
// gsound_set_master_volume / get
// ---------------------------------------------------------------------------
function gsound_set_master_volume(value: Integer): Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  if (value < VOLUME_MIN) and (value > VOLUME_MAX) then
  begin
    if gsound_debug then
      debug_printf('Requested master volume out of range.'#10);
    Exit(-1);
  end;

  if (gsound_background_df_vol <> 0) and (value <> 0) and (gsound_background_volume_get <> 0) then
  begin
    gsound_background_enable;
    gsound_background_df_vol := 0;
  end;

  if soundSetMasterVolume(value) <> 0 then
  begin
    if gsound_debug then
      debug_printf('Error setting master sound volume.'#10);
    Exit(-1);
  end;

  master_volume := value;
  if gsound_background_enabled and (value = 0) then
  begin
    gsound_background_disable;
    gsound_background_df_vol := 1;
  end;

  Result := 0;
end;

function gsound_get_master_volume: Integer;
begin
  Result := master_volume;
end;

// ---------------------------------------------------------------------------
// gsound_set_sfx_volume / get
// ---------------------------------------------------------------------------
function gsound_set_sfx_volume(value: Integer): Integer;
begin
  if (not gsound_initialized) or (value < VOLUME_MIN) or (value > VOLUME_MAX) then
  begin
    if gsound_debug then
      debug_printf('Error setting sfx volume.'#10);
    Exit(-1);
  end;

  sndfx_volume := value;
  Result := 0;
end;

function gsound_get_sfx_volume: Integer;
begin
  Result := sndfx_volume;
end;

// ---------------------------------------------------------------------------
// gsound_background_disable / enable / is_enabled
// ---------------------------------------------------------------------------
procedure gsound_background_disable;
begin
  if gsound_initialized then
  begin
    if gsound_background_enabled then
    begin
      gsound_background_stop;
      movieSetVolume(0);
      gsound_background_enabled := False;
    end;
  end;
end;

procedure gsound_background_enable;
begin
  if gsound_initialized then
  begin
    if not gsound_background_enabled then
    begin
      movieSetVolume(Trunc(background_volume * 0.94));
      gsound_background_enabled := True;
      gsound_background_restart_last(12);
    end;
  end;
end;

function gsound_background_is_enabled: Integer;
begin
  Result := Ord(gsound_background_enabled);
end;

// ---------------------------------------------------------------------------
// gsound_background_volume_set / get / get_set
// ---------------------------------------------------------------------------
procedure gsound_background_volume_set(value: Integer);
begin
  if not gsound_initialized then
    Exit;

  if (value < VOLUME_MIN) or (value > VOLUME_MAX) then
  begin
    if gsound_debug then
      debug_printf('Requested background volume out of range.'#10);
    Exit;
  end;

  background_volume := value;

  if gsound_background_df_vol <> 0 then
  begin
    gsound_background_enable;
    gsound_background_df_vol := 0;
  end;

  if gsound_background_enabled then
    movieSetVolume(Trunc(value * 0.94));

  if gsound_background_enabled then
  begin
    if gsound_background_tag <> nil then
      soundVolume(gsound_background_tag, Trunc(background_volume * 0.94));
  end;

  if gsound_background_enabled then
  begin
    if (value = 0) or (gsound_get_master_volume = 0) then
    begin
      gsound_background_disable;
      gsound_background_df_vol := 1;
    end;
  end;
end;

function gsound_background_volume_get: Integer;
begin
  Result := background_volume;
end;

function gsound_background_volume_get_set(a1: Integer): Integer;
var
  oldMusicVolume: Integer;
begin
  oldMusicVolume := gsound_background_volume_get;
  gsound_background_volume_set(a1);
  Result := oldMusicVolume;
end;

// ---------------------------------------------------------------------------
// gsound_background_fade_set / get / get_set
// ---------------------------------------------------------------------------
procedure gsound_background_fade_set(value: Integer);
begin
  gsound_background_fade := value;
end;

function gsound_background_fade_get: Integer;
begin
  Result := gsound_background_fade;
end;

function gsound_background_fade_get_set(value: Integer): Integer;
var
  oldValue: Integer;
begin
  oldValue := gsound_background_fade_get;
  gsound_background_fade_set(value);
  Result := oldValue;
end;

// ---------------------------------------------------------------------------
// gsound_background_callback_set / get / get_set
// ---------------------------------------------------------------------------
procedure gsound_background_callback_set(callback: TSoundEndCallback);
begin
  gsound_background_callback_fp := callback;
end;

function gsound_background_callback_get: TSoundEndCallback;
begin
  Result := gsound_background_callback_fp;
end;

function gsound_background_callback_get_set(callback: TSoundEndCallback): TSoundEndCallback;
var
  oldCallback: TSoundEndCallback;
begin
  oldCallback := gsound_background_callback_get;
  gsound_background_callback_set(callback);
  Result := oldCallback;
end;

// ---------------------------------------------------------------------------
// gsound_background_length_get
// ---------------------------------------------------------------------------
function gsound_background_length_get: Integer;
begin
  Result := soundLength(gsound_background_tag);
end;

// ---------------------------------------------------------------------------
// gsound_background_play
// ---------------------------------------------------------------------------
function gsound_background_play(const fileName: PAnsiChar; a2, a3, a4: Integer): Integer;
var
  rc: Integer;
  path: array[0..COMPAT_MAX_PATH] of AnsiChar;
begin
  background_storage_requested := a3;
  background_loop_requested := a4;

  StrCopy(@background_fname_requested[0], fileName);

  if not gsound_initialized then
    Exit(-1);

  if not gsound_background_enabled then
    Exit(-1);

  if gsound_debug then
    debug_printf('Loading background sound file %s%s...', [StrPas(fileName), '.acm']);

  gsound_background_stop;

  rc := gsound_background_allocate(@gsound_background_tag, a3, a4);
  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because sound could not be allocated.'#10);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  rc := soundSetFileIO(gsound_background_tag, @audiofOpen_cdecl, @audiofCloseFile_cdecl, @audiofRead_cdecl, nil, @audiofSeek_cdecl, @gsound_compressed_tell, @audiofFileSize_cdecl);
  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because file IO could not be set for compression.'#10);
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  rc := soundSetChannel(gsound_background_tag, 3);
  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because the channel could not be set.'#10);
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  rc := -1;
  if a3 = 13 then
    rc := gsound_background_find_dont_copy(@path[0], fileName)
  else if a3 = 14 then
    rc := gsound_background_find_with_copy(@path[0], fileName);

  if rc <> SOUND_NO_ERROR then
  begin
    if gsound_debug then
      debug_printf('''failed because the file could not be found.'#10);
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  if a4 = 16 then
  begin
    rc := soundLoop(gsound_background_tag, $FFFF);
    if rc <> SOUND_NO_ERROR then
    begin
      if gsound_debug then
        debug_printf('failed because looping could not be set.'#10);
      soundDelete(gsound_background_tag);
      gsound_background_tag := nil;
      Exit(-1);
    end;
  end;

  rc := soundSetCallback(gsound_background_tag, @gsound_internal_background_callback, nil);
  if rc <> SOUND_NO_ERROR then
  begin
    if gsound_debug then
      debug_printf('soundSetCallback failed for background sound'#10);
  end;

  if a2 = 11 then
  begin
    rc := soundSetReadLimit(gsound_background_tag, $40000);
    if rc <> SOUND_NO_ERROR then
    begin
      if gsound_debug then
        debug_printf('unable to set read limit ');
    end;
  end;

  rc := soundLoad(gsound_background_tag, @path[0]);
  if rc <> SOUND_NO_ERROR then
  begin
    if gsound_debug then
      debug_printf('failed on call to soundLoad.'#10);
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  if a2 <> 11 then
  begin
    rc := soundSetReadLimit(gsound_background_tag, $40000);
    if rc <> 0 then
    begin
      if gsound_debug then
        debug_printf('unable to set read limit ');
    end;
  end;

  if a2 = 10 then
    Exit(0);

  rc := gsound_background_start;
  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed starting to play.'#10);
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf('succeeded.'#10);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_background_play_level_music
// ---------------------------------------------------------------------------
function gsound_background_play_level_music(const a1: PAnsiChar; a2: Integer): Integer;
begin
  Result := gsound_background_play(a1, a2, 14, 16);
end;

// ---------------------------------------------------------------------------
// gsound_background_play_preloaded
// ---------------------------------------------------------------------------
function gsound_background_play_preloaded: Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_background_enabled then
    Exit(-1);

  if gsound_background_tag = nil then
    Exit(-1);

  if soundPlaying(gsound_background_tag) then
    Exit(-1);

  if soundPaused(gsound_background_tag) then
    Exit(-1);

  if soundDone(gsound_background_tag) then
    Exit(-1);

  if gsound_background_start <> 0 then
  begin
    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
    Exit(-1);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_background_stop
// ---------------------------------------------------------------------------
procedure gsound_background_stop;
begin
  if gsound_initialized and gsound_background_enabled and (gsound_background_tag <> nil) then
  begin
    if gsound_background_fade <> 0 then
    begin
      if soundFade(gsound_background_tag, 2000, 0) = 0 then
      begin
        gsound_background_tag := nil;
        Exit;
      end;
    end;

    soundDelete(gsound_background_tag);
    gsound_background_tag := nil;
  end;
end;

// ---------------------------------------------------------------------------
// gsound_background_restart_last
// ---------------------------------------------------------------------------
procedure gsound_background_restart_last(value: Integer);
begin
  if background_fname_requested[0] <> #0 then
  begin
    if gsound_background_play(@background_fname_requested[0], value, background_storage_requested, background_loop_requested) <> 0 then
    begin
      if gsound_debug then
        debug_printf(' background restart failed ');
    end;
  end;
end;

// ---------------------------------------------------------------------------
// gsound_background_pause / unpause
// ---------------------------------------------------------------------------
procedure gsound_background_pause;
begin
  if gsound_background_tag <> nil then
    soundPause(gsound_background_tag);
end;

procedure gsound_background_unpause;
begin
  if gsound_background_tag <> nil then
    soundUnpause(gsound_background_tag);
end;

// ---------------------------------------------------------------------------
// gsound_speech_disable / enable / is_enabled
// ---------------------------------------------------------------------------
procedure gsound_speech_disable;
begin
  if gsound_initialized then
  begin
    if gsound_speech_enabled then
    begin
      gsound_speech_stop;
      gsound_speech_enabled := False;
    end;
  end;
end;

procedure gsound_speech_enable;
begin
  if gsound_initialized then
  begin
    if not gsound_speech_enabled then
      gsound_speech_enabled := True;
  end;
end;

function gsound_speech_is_enabled: Integer;
begin
  Result := Ord(gsound_speech_enabled);
end;

// ---------------------------------------------------------------------------
// gsound_speech_volume_set / get / get_set
// ---------------------------------------------------------------------------
procedure gsound_speech_volume_set(value: Integer);
begin
  if not gsound_initialized then
    Exit;

  if (value < VOLUME_MIN) or (value > VOLUME_MAX) then
  begin
    if gsound_debug then
      debug_printf('Requested speech volume out of range.'#10);
    Exit;
  end;

  speech_volume := value;

  if gsound_speech_enabled then
  begin
    if gsound_speech_tag <> nil then
      soundVolume(gsound_speech_tag, Trunc(value * 0.69));
  end;
end;

function gsound_speech_volume_get: Integer;
begin
  Result := speech_volume;
end;

function gsound_speech_volume_get_set(volume: Integer): Integer;
var
  oldVolume: Integer;
begin
  oldVolume := speech_volume;
  gsound_speech_volume_set(volume);
  Result := oldVolume;
end;

// ---------------------------------------------------------------------------
// gsound_speech_callback_set / get / get_set
// ---------------------------------------------------------------------------
procedure gsound_speech_callback_set(callback: TSoundEndCallback);
begin
  gsound_speech_callback_fp := callback;
end;

function gsound_speech_callback_get: TSoundEndCallback;
begin
  Result := gsound_speech_callback_fp;
end;

function gsound_speech_callback_get_set(callback: TSoundEndCallback): TSoundEndCallback;
var
  oldCallback: TSoundEndCallback;
begin
  oldCallback := gsound_speech_callback_get;
  gsound_speech_callback_set(callback);
  Result := oldCallback;
end;

// ---------------------------------------------------------------------------
// gsound_speech_length_get
// ---------------------------------------------------------------------------
function gsound_speech_length_get: Integer;
begin
  Result := soundLength(gsound_speech_tag);
end;

// ---------------------------------------------------------------------------
// gsound_speech_play
// ---------------------------------------------------------------------------
function gsound_speech_play(const fname: PAnsiChar; a2, a3, a4: Integer): Integer;
var
  path: array[0..COMPAT_MAX_PATH] of AnsiChar;
  rc: Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_speech_enabled then
    Exit(-1);

  if gsound_debug then
    debug_printf('Loading speech sound file %s%s...', [StrPas(fname), '.ACM']);

  gsound_speech_stop;

  if gsound_background_allocate(@gsound_speech_tag, a3, a4) <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because sound could not be allocated.'#10);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  if soundSetFileIO(gsound_speech_tag, @audioOpen_cdecl, @audioCloseFile_cdecl, @audioRead_cdecl, nil, @audioSeek_cdecl, @gsound_compressed_tell, @audioFileSize_cdecl) <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because file IO could not be set for compression.'#10);
    soundDelete(gsound_speech_tag);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  if gsound_speech_find_dont_copy(@path[0], fname) <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because the file could not be found.'#10);
    soundDelete(gsound_speech_tag);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  if a4 = 16 then
  begin
    if soundLoop(gsound_speech_tag, $FFFF) <> 0 then
    begin
      if gsound_debug then
        debug_printf('failed because looping could not be set.'#10);
      soundDelete(gsound_speech_tag);
      gsound_speech_tag := nil;
      Exit(-1);
    end;
  end;

  if soundSetCallback(gsound_speech_tag, @gsound_internal_speech_callback, nil) <> 0 then
  begin
    if gsound_debug then
      debug_printf('soundSetCallback failed for speech sound'#10);
  end;

  if a2 = 11 then
  begin
    if soundSetReadLimit(gsound_speech_tag, $40000) <> 0 then
    begin
      if gsound_debug then
        debug_printf('unable to set read limit ');
    end;
  end;

  if soundLoad(gsound_speech_tag, @path[0]) <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed on call to soundLoad.'#10);
    soundDelete(gsound_speech_tag);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  if a2 <> 11 then
  begin
    if soundSetReadLimit(gsound_speech_tag, $40000) <> 0 then
    begin
      if gsound_debug then
        debug_printf('unable to set read limit ');
    end;
  end;

  if a2 = 10 then
    Exit(0);

  if gsound_speech_start <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed starting to play.'#10);
    soundDelete(gsound_speech_tag);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf('succeeded.'#10);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_speech_play_preloaded
// ---------------------------------------------------------------------------
function gsound_speech_play_preloaded: Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_speech_enabled then
    Exit(-1);

  if gsound_speech_tag = nil then
    Exit(-1);

  if soundPlaying(gsound_speech_tag) then
    Exit(-1);

  if soundPaused(gsound_speech_tag) then
    Exit(-1);

  if soundDone(gsound_speech_tag) then
    Exit(-1);

  if gsound_speech_start <> 0 then
  begin
    soundDelete(gsound_speech_tag);
    gsound_speech_tag := nil;
    Exit(-1);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_speech_stop
// ---------------------------------------------------------------------------
procedure gsound_speech_stop;
begin
  if gsound_initialized and gsound_speech_enabled then
  begin
    if gsound_speech_tag <> nil then
    begin
      soundDelete(gsound_speech_tag);
      gsound_speech_tag := nil;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// gsound_speech_pause / unpause
// ---------------------------------------------------------------------------
procedure gsound_speech_pause;
begin
  if gsound_speech_tag <> nil then
    soundPause(gsound_speech_tag);
end;

procedure gsound_speech_unpause;
begin
  if gsound_speech_tag <> nil then
    soundUnpause(gsound_speech_tag);
end;

// ---------------------------------------------------------------------------
// gsound_play_sfx_file_volume
// ---------------------------------------------------------------------------
function gsound_play_sfx_file_volume(const a1: PAnsiChar; a2: Integer): Integer;
var
  v1: PSound;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_sfx_enabled then
    Exit(-1);

  v1 := gsound_load_sound_volume(a1, nil, a2);
  if v1 = nil then
    Exit(-1);

  soundPlay(v1);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_load_sound
// ---------------------------------------------------------------------------
function gsound_load_sound(const name: PAnsiChar; a2: PObject): PSound;
var
  sound: PSound;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;

  v9: AnsiChar;
begin
  if not gsound_initialized then
    Exit(nil);

  if not gsound_sfx_enabled then
    Exit(nil);

  if gsound_debug then
    debug_printf('Loading sound file %s%s...', [StrPas(name), '.ACM']);

  if gsound_active_effect_counter >= SOUND_EFFECTS_MAX_COUNT then
  begin
    if gsound_debug then
      debug_printf('failed because there are already %d active effects.'#10, [gsound_active_effect_counter]);
    Exit(nil);
  end;

  sound := gsound_get_sound_ready_for_effect;
  if sound = nil then
  begin
    if gsound_debug then
      debug_printf('failed.'#10);
    Exit(nil);
  end;

  Inc(gsound_active_effect_counter);

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', [sound_sfx_path, name, '.ACM']);

  if soundLoad(sound, @path[0]) = 0 then
  begin
    if gsound_debug then
      debug_printf('succeeded.'#10);
    Exit(sound);
  end;

  if a2 <> nil then
  begin
    if (FID_TYPE(a2^.Fid) = OBJ_TYPE_CRITTER) and ((name[0] = 'H') or (name[0] = 'N')) then
    begin
      v9 := name[1];
      if (v9 = 'A') or (v9 = 'F') or (v9 = 'M') then
      begin
        if v9 = 'A' then
        begin
          if stat_level(a2, STAT_GENDER) <> 0 then
            v9 := 'F'
          else
            v9 := 'M';
        end;
      end;

      StrLFmt(@path[0], SizeOf(path) - 1, '%sH%sXXXX%s%s', [sound_sfx_path, v9, name + 6, '.ACM']);

      if gsound_debug then
        debug_printf('tyring %s ', [StrPas(PAnsiChar(@path[0]) + StrLen(sound_sfx_path))]);

      if soundLoad(sound, @path[0]) = 0 then
      begin
        if gsound_debug then
          debug_printf('succeeded (with alias).'#10);
        Exit(sound);
      end;

      if v9 = 'F' then
      begin
        StrLFmt(@path[0], SizeOf(path) - 1, '%sHMXXXX%s%s', [sound_sfx_path, name + 6, '.ACM']);

        if gsound_debug then
          debug_printf('tyring %s ', [StrPas(PAnsiChar(@path[0]) + StrLen(sound_sfx_path))]);

        if soundLoad(sound, @path[0]) = 0 then
        begin
          if gsound_debug then
            debug_printf('succeeded (with male alias).'#10);
          Exit(sound);
        end;
      end;
    end;
  end;

  if (StrLComp(name, 'MALIEU', 6) = 0) or (StrLComp(name, 'MAMTN2', 6) = 0) then
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%sMAMTNT%s%s', [sound_sfx_path, name + 6, '.ACM']);

    if gsound_debug then
      debug_printf('tyring %s ', [StrPas(PAnsiChar(@path[0]) + StrLen(sound_sfx_path))]);

    if soundLoad(sound, @path[0]) = 0 then
    begin
      if gsound_debug then
        debug_printf('succeeded (with alias).'#10);
      Exit(sound);
    end;
  end;

  Dec(gsound_active_effect_counter);

  soundDelete(sound);

  if gsound_debug then
    debug_printf('failed.'#10);

  Result := nil;
end;

// ---------------------------------------------------------------------------
// gsound_load_sound_volume
// ---------------------------------------------------------------------------
function gsound_load_sound_volume(const a1: PAnsiChar; a2: PObject; a3: Integer): PSound;
var
  sound: PSound;
begin
  sound := gsound_load_sound(a1, a2);

  if sound <> nil then
    soundVolume(sound, (a3 * sndfx_volume) div VOLUME_MAX);

  Result := sound;
end;

// ---------------------------------------------------------------------------
// gsound_delete_sfx
// ---------------------------------------------------------------------------
procedure gsound_delete_sfx(a1: PSound);
begin
  if not gsound_initialized then
    Exit;

  if not gsound_sfx_enabled then
    Exit;

  if soundPlaying(a1) then
  begin
    if gsound_debug then
      debug_printf('Trying to manually delete a sound effect after it has started playing.'#10);
    Exit;
  end;

  if soundDelete(a1) <> 0 then
  begin
    if gsound_debug then
      debug_printf('Unable to delete sound effect -- active effect counter may get out of sync.'#10);
    Exit;
  end;

  Dec(gsound_active_effect_counter);
end;

// ---------------------------------------------------------------------------
// gsnd_anim_sound
// ---------------------------------------------------------------------------
function gsnd_anim_sound(sound: PSound; a2: Pointer): Integer;
begin
  if not gsound_initialized then
    Exit(0);

  if not gsound_sfx_enabled then
    Exit(0);

  if sound = nil then
    Exit(0);

  soundPlay(sound);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_play_sound
// ---------------------------------------------------------------------------
function gsound_play_sound(a1: PSound): Integer;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_sfx_enabled then
    Exit(-1);

  if a1 = nil then
    Exit(-1);

  soundPlay(a1);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_compute_relative_volume
// ---------------------------------------------------------------------------
function gsound_compute_relative_volume(obj: PObject): Integer;
var
  objType: Integer;
  v3: Integer;
  v7: PObject;
  v12: TRect;
  v14: TRect;
  iso_win_rect: TRect;
  distance: Integer;
  perception: Integer;

begin
  v3 := $7FFF;

  if obj <> nil then
  begin
    objType := FID_TYPE(obj^.Fid);
    if (objType = 0) or (objType = 1) or (objType = 2) then
    begin
      v7 := obj_top_environment(obj);
      if v7 = nil then
        v7 := obj;

      obj_bound(v7, @v14);

      win_get_rect(display_win, @iso_win_rect);

      if rect_inside_bound(@v14, @iso_win_rect, @v12) = -1 then
      begin
        distance := obj_dist(v7, obj_dude);
        perception := stat_level(obj_dude, STAT_PERCEPTION);
        if distance > perception then
        begin
          if distance < 2 * perception then
            v3 := $7FFF - $5554 * (distance - perception) div perception
          else
            v3 := $2AAA;
        end
        else
          v3 := $7FFF;
      end;
    end;
  end;

  Result := v3;
end;

// ---------------------------------------------------------------------------
// gsnd_build_character_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_character_sfx_name(a1: PObject; anim, extra: Integer): PAnsiChar;
var
  v7: array[0..12] of AnsiChar;
  v8: AnsiChar;
  v9: AnsiChar;

begin
  if art_get_base_name(FID_TYPE(a1^.Fid), a1^.Fid and $FFF, @v7[0]) = -1 then
    Exit(nil);

  if anim = ANIM_TAKE_OUT then
  begin
    if art_get_code(anim, extra, @v8, @v9) = -1 then
      Exit(nil);
  end
  else
  begin
    if art_get_code(anim, (a1^.Fid and $F000) shr 12, @v8, @v9) = -1 then
      Exit(nil);
  end;

  if (anim = ANIM_FALL_FRONT) or (anim = ANIM_FALL_BACK) then
  begin
    if extra = CHARACTER_SOUND_EFFECT_PASS_OUT then
      v8 := 'Y'
    else if extra = CHARACTER_SOUND_EFFECT_DIE then
      v8 := 'Z';
  end
  else if ((anim = ANIM_THROW_PUNCH) or (anim = ANIM_KICK_LEG)) and (extra = CHARACTER_SOUND_EFFECT_CONTACT) then
    v8 := 'Z';

  StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, '%s%s%s', [PAnsiChar(@v7[0]), v8, v9]);
  compat_strupr(@sfx_file_name[0]);
  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// gsnd_build_ambient_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_ambient_sfx_name(const a1: PAnsiChar): PAnsiChar;
begin
  StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'A%6s%1d', [a1, 1]);
  compat_strupr(@sfx_file_name[0]);
  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// gsnd_build_interface_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_interface_sfx_name(const a1: PAnsiChar): PAnsiChar;
begin
  StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'N%6s%1d', [a1, 1]);
  compat_strupr(@sfx_file_name[0]);
  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// gsnd_build_weapon_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_weapon_sfx_name(effectType: Integer; weapon: PObject; hitMode: Integer; target: PObject): PAnsiChar;
var
  v6: Integer;
  weaponSoundCode: AnsiChar;
  effectTypeCode: AnsiChar;
  materialCode: AnsiChar;
  proto: PProto;
  damage_type: Integer;
  targetType: Integer;
  material: Integer;
begin
  weaponSoundCode := item_w_sound_id(weapon);
  effectTypeCode := snd_lookup_weapon_type[effectType];

  if (effectType <> WEAPON_SOUND_EFFECT_READY) and (effectType <> WEAPON_SOUND_EFFECT_OUT_OF_AMMO) then
  begin
    if (hitMode <> HIT_MODE_LEFT_WEAPON_PRIMARY) and (hitMode <> HIT_MODE_RIGHT_WEAPON_PRIMARY) and (hitMode <> HIT_MODE_PUNCH) then
      v6 := 2
    else
      v6 := 1;
  end
  else
    v6 := 1;

  damage_type := item_w_damage_type(weapon);
  if (effectTypeCode <> 'H') or (target = nil) or (damage_type = DAMAGE_TYPE_EXPLOSION) or (damage_type = DAMAGE_TYPE_PLASMA) or (damage_type = DAMAGE_TYPE_EMP) then
  begin
    materialCode := 'X';
  end
  else
  begin
    targetType := FID_TYPE(target^.Fid);
    material := -1;
    proto := nil;
    case targetType of
      OBJ_TYPE_ITEM:
      begin
        proto_ptr(target^.Pid, @proto);
        if proto <> nil then
          material := proto^.Item.Material
        else
          material := -1;
      end;
      OBJ_TYPE_SCENERY:
      begin
        proto_ptr(target^.Pid, @proto);
        if proto <> nil then
          material := proto^.Scenery.Material
        else
          material := -1;
      end;
      OBJ_TYPE_WALL:
      begin
        proto_ptr(target^.Pid, @proto);
        if proto <> nil then
          material := proto^.Wall.Material
        else
          material := -1;
      end;
    else
      material := -1;
    end;

    case material of
      MATERIAL_TYPE_GLASS,
      MATERIAL_TYPE_METAL,
      MATERIAL_TYPE_PLASTIC:
        materialCode := 'M';
      MATERIAL_TYPE_WOOD:
        materialCode := 'W';
      MATERIAL_TYPE_DIRT,
      MATERIAL_TYPE_STONE,
      MATERIAL_TYPE_CEMENT:
        materialCode := 'S';
    else
      materialCode := 'F';
    end;
  end;

  StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'W%s%s%1d%sXX%1d', [effectTypeCode, weaponSoundCode, v6, materialCode, 1]);
  compat_strupr(@sfx_file_name[0]);
  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// gsnd_build_scenery_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_scenery_sfx_name(actionType, action: Integer; const name: PAnsiChar): PAnsiChar;
var
  actionTypeCode: AnsiChar;
  actionCode: AnsiChar;
begin
  if actionType = SOUND_EFFECT_ACTION_TYPE_PASSIVE then
    actionTypeCode := 'P'
  else
    actionTypeCode := 'A';
  actionCode := snd_lookup_scenery_action[action];

  StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'S%s%s%4s%1d', [actionTypeCode, actionCode, name, 1]);
  compat_strupr(@sfx_file_name[0]);

  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// gsnd_build_open_sfx_name
// ---------------------------------------------------------------------------
function gsnd_build_open_sfx_name(a1: PObject; a2: Integer): PAnsiChar;
var
  scenerySoundId: AnsiChar;
  proto: PProto;
begin
  proto := nil;

  if FID_TYPE(a1^.Fid) = OBJ_TYPE_SCENERY then
  begin
    if proto_ptr(a1^.Pid, @proto) <> -1 then
      scenerySoundId := AnsiChar(proto^.Scenery.Field_34)
    else
      scenerySoundId := 'A';
    StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'S%sDOORS%s', [snd_lookup_scenery_action[a2], scenerySoundId]);
  end
  else
  begin
    proto_ptr(a1^.Pid, @proto);
    StrLFmt(@sfx_file_name[0], SizeOf(sfx_file_name) - 1, 'I%sCNTNR%s', [snd_lookup_scenery_action[a2], AnsiChar(proto^.Item.Field_80)]);
  end;
  compat_strupr(@sfx_file_name[0]);
  Result := @sfx_file_name[0];
end;

// ---------------------------------------------------------------------------
// UI button sound callbacks
// ---------------------------------------------------------------------------
procedure gsound_red_butt_press(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib1p1xx1');
end;

procedure gsound_red_butt_release(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib1lu1x1');
end;

procedure gsound_toggle_butt_press(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('toggle');
end;

procedure gsound_toggle_butt_release(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('toggle');
end;

procedure gsound_med_butt_press(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib2p1xx1');
end;

procedure gsound_med_butt_release(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib2lu1x1');
end;

procedure gsound_lrg_butt_press(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib3p1xx1');
end;

procedure gsound_lrg_butt_release(btn, keyCode: Integer); cdecl;
begin
  gsound_play_sfx_file('ib3lu1x1');
end;

// ---------------------------------------------------------------------------
// gsound_play_sfx_file
// ---------------------------------------------------------------------------
function gsound_play_sfx_file(const name: PAnsiChar): Integer;
var
  sound: PSound;
begin
  if not gsound_initialized then
    Exit(-1);

  if not gsound_sfx_enabled then
    Exit(-1);

  sound := gsound_load_sound(name, nil);
  if sound = nil then
    Exit(-1);

  soundPlay(sound);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_bkg_proc (background process callback)
// ---------------------------------------------------------------------------
procedure gsound_bkg_proc;
begin
  soundUpdate;
end;

// ---------------------------------------------------------------------------
// gsound_open (file I/O callback for sound system)
// ---------------------------------------------------------------------------
function gsound_open(const fname: PAnsiChar; flags: Integer): Integer; cdecl;
var
  stream: PDB_FILE;
begin
  if (flags and 2) <> 0 then
    Exit(-1);

  stream := db_fopen(fname, 'rb');
  if stream = nil then
    Exit(-1);

  Result := ptrToInt(stream);
end;

// ---------------------------------------------------------------------------
// gsound_compressed_tell
// ---------------------------------------------------------------------------
function gsound_compressed_tell(handle: Integer): LongInt; cdecl;
begin
  Result := -1;
end;

// ---------------------------------------------------------------------------
// gsound_write
// ---------------------------------------------------------------------------
function gsound_write(handle: Integer; const buf: Pointer; size: LongWord): Integer; cdecl;
begin
  Result := -1;
end;

// ---------------------------------------------------------------------------
// gsound_close
// ---------------------------------------------------------------------------
function gsound_close(handle: Integer): Integer; cdecl;
begin
  if handle = -1 then
    Exit(-1);

  Result := db_fclose(PDB_FILE(intToPtr(handle)));
end;

// ---------------------------------------------------------------------------
// gsound_read
// ---------------------------------------------------------------------------
function gsound_read(handle: Integer; buf: Pointer; size: LongWord): Integer; cdecl;
begin
  if handle = -1 then
    Exit(-1);

  Result := Integer(db_fread(buf, 1, size, PDB_FILE(intToPtr(handle))));
end;

// ---------------------------------------------------------------------------
// gsound_seek
// ---------------------------------------------------------------------------
function gsound_seek(handle: Integer; offset: LongInt; origin: Integer): LongInt; cdecl;
begin
  if handle = -1 then
    Exit(-1);

  if db_fseek(PDB_FILE(intToPtr(handle)), offset, origin) <> 0 then
    Exit(-1);

  Result := db_ftell(PDB_FILE(intToPtr(handle)));
end;

// ---------------------------------------------------------------------------
// gsound_tell
// ---------------------------------------------------------------------------
function gsound_tell(handle: Integer): LongInt; cdecl;
begin
  if handle = -1 then
    Exit(-1);

  Result := db_ftell(PDB_FILE(intToPtr(handle)));
end;

// ---------------------------------------------------------------------------
// gsound_filesize
// ---------------------------------------------------------------------------
function gsound_filesize(handle: Integer): LongInt; cdecl;
begin
  if handle = -1 then
    Exit(-1);

  Result := db_filelength(PDB_FILE(intToPtr(handle)));
end;

// ---------------------------------------------------------------------------
// gsound_compressed_query
// ---------------------------------------------------------------------------
function gsound_compressed_query(filePath: PAnsiChar): Boolean; cdecl;
begin
  Result := True;
end;

// ---------------------------------------------------------------------------
// gsound_internal_speech_callback
// ---------------------------------------------------------------------------
procedure gsound_internal_speech_callback(userData: Pointer; a2: Integer); cdecl;
begin
  if a2 = 1 then
  begin
    gsound_speech_tag := nil;

    if Assigned(gsound_speech_callback_fp) then
      gsound_speech_callback_fp();
  end;
end;

// ---------------------------------------------------------------------------
// gsound_internal_background_callback
// ---------------------------------------------------------------------------
procedure gsound_internal_background_callback(userData: Pointer; a2: Integer); cdecl;
begin
  if a2 = 1 then
  begin
    gsound_background_tag := nil;

    if Assigned(gsound_background_callback_fp) then
      gsound_background_callback_fp();
  end;
end;

// ---------------------------------------------------------------------------
// gsound_internal_effect_callback
// ---------------------------------------------------------------------------
procedure gsound_internal_effect_callback(userData: Pointer; a2: Integer); cdecl;
begin
  if a2 = 1 then
    Dec(gsound_active_effect_counter);
end;

// ---------------------------------------------------------------------------
// gsound_background_allocate
// ---------------------------------------------------------------------------
function gsound_background_allocate(out_s: PPointer; a2, a3: Integer): Integer;
var
  v5: Integer;
  v6: Integer;
  sound: PSound;
begin
  v5 := 10;
  v6 := 0;
  if a2 = 13 then
    v6 := v6 or $01
  else if a2 = 14 then
    v6 := v6 or $02;

  if a3 = 15 then
    v6 := v6 or $04
  else if a3 = 16 then
    v5 := 42;

  sound := soundAllocate(v6, v5);
  if sound = nil then
    Exit(-1);

  out_s^ := sound;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_background_find_with_copy
// ---------------------------------------------------------------------------
function gsound_background_find_with_copy(dest: PAnsiChar; const src: PAnsiChar): Integer;
var
  len: SizeUInt;
  outPath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  inPath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  inStream: Pointer;
  outStream: Pointer;
  buffer: Pointer;
  err: Boolean;
  bytesRead: SizeUInt;
begin
  len := StrLen(src) + StrLen('.ACM');
  if (StrLen(sound_music_path1) + len > COMPAT_MAX_PATH) or (StrLen(sound_music_path2) + len > COMPAT_MAX_PATH) then
  begin
    if gsound_debug then
      debug_printf('Full background path too long.'#10);
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf(' finding background sound ');

  StrLFmt(@outPath[0], SizeOf(outPath) - 1, '%s%s%s', [sound_music_path1, src, '.ACM']);
  if gsound_file_exists_f(@outPath[0]) then
  begin
    StrLCopy(dest, @outPath[0], COMPAT_MAX_PATH);
    dest[COMPAT_MAX_PATH] := #0;
    Exit(0);
  end;

  if gsound_debug then
    debug_printf('by copy ');

  gsound_background_remove_last_copy;

  StrLFmt(@inPath[0], SizeOf(inPath) - 1, '%s%s%s', [sound_music_path2, src, '.ACM']);

  inStream := compat_fopen(@inPath[0], 'rb');
  if inStream = nil then
  begin
    if gsound_debug then
      debug_printf('Unable to find music file %s to copy down.'#10, [StrPas(src)]);
    Exit(-1);
  end;

  outStream := compat_fopen(@outPath[0], 'wb');
  if outStream = nil then
  begin
    if gsound_debug then
      debug_printf('Unable to open music file %s for copying to.', [StrPas(src)]);
    libc_fclose(inStream);
    Exit(-1);
  end;

  buffer := mem_malloc($2000);
  if buffer = nil then
  begin
    if gsound_debug then
      debug_printf('Out of memory in gsound_background_find_with_copy.'#10, [StrPas(src)]);
    libc_fclose(outStream);
    libc_fclose(inStream);
    Exit(-1);
  end;

  err := False;
  while libc_feof(inStream) = 0 do
  begin
    bytesRead := libc_fread(buffer, 1, $2000, inStream);
    if bytesRead = 0 then
      Break;

    if libc_fwrite(buffer, 1, bytesRead, outStream) <> bytesRead then
    begin
      err := True;
      Break;
    end;
  end;

  mem_free(buffer);
  libc_fclose(outStream);
  libc_fclose(inStream);

  if err then
  begin
    if gsound_debug then
    begin
      debug_printf('Background sound file copy failed on write -- ');
      debug_printf('likely out of disc space.'#10);
    end;
    Exit(-1);
  end;

  StrCopy(@background_fname_copied[0], src);

  StrLCopy(dest, @outPath[0], COMPAT_MAX_PATH);
  dest[COMPAT_MAX_PATH] := #0;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_background_find_dont_copy
// ---------------------------------------------------------------------------
function gsound_background_find_dont_copy(dest: PAnsiChar; const src: PAnsiChar): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  len: SizeUInt;
begin
  len := StrLen(src) + StrLen('.ACM');
  if (StrLen(sound_music_path1) + len > COMPAT_MAX_PATH) or (StrLen(sound_music_path2) + len > COMPAT_MAX_PATH) then
  begin
    if gsound_debug then
      debug_printf('Full background path too long.'#10);
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf(' finding background sound ');

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', [sound_music_path1, src, '.ACM']);
  if gsound_file_exists_f(@path[0]) then
  begin
    StrLCopy(dest, @path[0], COMPAT_MAX_PATH);
    dest[COMPAT_MAX_PATH] := #0;
    Exit(0);
  end;

  if gsound_debug then
    debug_printf('in 2nd path ');

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', [sound_music_path2, src, '.ACM']);
  if gsound_file_exists_f(@path[0]) then
  begin
    StrLCopy(dest, @path[0], COMPAT_MAX_PATH);
    dest[COMPAT_MAX_PATH] := #0;
    Exit(0);
  end;

  if gsound_debug then
    debug_printf('-- find failed ');

  Result := -1;
end;

// ---------------------------------------------------------------------------
// gsound_speech_find_dont_copy
// ---------------------------------------------------------------------------
function gsound_speech_find_dont_copy(dest: PAnsiChar; const src: PAnsiChar): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if StrLen(sound_speech_path) + StrLen('.acm') > COMPAT_MAX_PATH then
  begin
    if gsound_debug then
      debug_printf('Full background path too long.'#10);
    Exit(-1);
  end;

  if gsound_debug then
    debug_printf(' finding speech sound ');

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', [sound_speech_path, src, '.ACM']);

  if gsound_file_exists_db(@path[0]) = 0 then
  begin
    if gsound_debug then
      debug_printf('-- find failed ');
    Exit(-1);
  end;

  StrLCopy(dest, @path[0], COMPAT_MAX_PATH);
  dest[COMPAT_MAX_PATH] := #0;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_background_remove_last_copy
// ---------------------------------------------------------------------------
procedure gsound_background_remove_last_copy;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if background_fname_copied[0] <> #0 then
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', ['sound\music\', PAnsiChar(@background_fname_copied[0]), '.ACM']);
    if compat_remove(@path[0]) <> 0 then
    begin
      if gsound_debug then
        debug_printf('Deleting old music file failed.'#10);
    end;

    background_fname_copied[0] := #0;
  end;
end;

// ---------------------------------------------------------------------------
// gsound_background_start
// ---------------------------------------------------------------------------
function gsound_background_start: Integer;
begin
  if gsound_debug then
    debug_printf(' playing ');

  if gsound_background_fade <> 0 then
  begin
    soundVolume(gsound_background_tag, 1);
    Result := soundFade(gsound_background_tag, 2000, Trunc(background_volume * 0.94));
  end
  else
  begin
    soundVolume(gsound_background_tag, Trunc(background_volume * 0.94));
    Result := soundPlay(gsound_background_tag);
  end;

  if Result <> 0 then
  begin
    if gsound_debug then
      debug_printf('Unable to play background sound.'#10);
    Result := -1;
  end;
end;

// ---------------------------------------------------------------------------
// gsound_speech_start
// ---------------------------------------------------------------------------
function gsound_speech_start: Integer;
begin
  if gsound_debug then
    debug_printf(' playing ');

  soundVolume(gsound_speech_tag, Trunc(speech_volume * 0.69));

  if soundPlay(gsound_speech_tag) <> 0 then
  begin
    if gsound_debug then
      debug_printf('Unable to play speech sound.'#10);
    Exit(-1);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_get_music_path
// ---------------------------------------------------------------------------
function gsound_get_music_path(out_value: PPAnsiChar; const key: PAnsiChar): Integer;
var
  len: Integer;
  copy: PAnsiChar;
  value: PAnsiChar;
begin
  config_get_string(@game_config, GAME_CONFIG_SOUND_KEY, key, out_value);

  value := out_value^;
  len := StrLen(value);

  if (value[len - 1] = '\') or (value[len - 1] = '/') then
    Exit(0);

  copy := PAnsiChar(mem_malloc(len + 2));
  if copy = nil then
  begin
    if gsound_debug then
      debug_printf('Out of memory in gsound_get_music_path.'#10);
    Exit(-1);
  end;

  StrCopy(copy, value);
  copy[len] := '\';
  copy[len + 1] := #0;

  if not config_set_string(@game_config, GAME_CONFIG_SOUND_KEY, key, copy) then
  begin
    if gsound_debug then
      debug_printf('config_set_string failed in gsound_music_path.'#10);
    Exit(-1);
  end;

  if config_get_string(@game_config, GAME_CONFIG_SOUND_KEY, key, out_value) then
  begin
    mem_free(copy);
    Exit(0);
  end;

  if gsound_debug then
    debug_printf('config_get_string failed in gsound_music_path.'#10);

  Result := -1;
end;

// ---------------------------------------------------------------------------
// gsound_check_active_effects
// ---------------------------------------------------------------------------
procedure gsound_check_active_effects;
begin
  if (gsound_active_effect_counter < 0) or (gsound_active_effect_counter > 4) then
  begin
    if gsound_debug then
      debug_printf('WARNING: %d active effects.'#10, [gsound_active_effect_counter]);
  end;
end;

// ---------------------------------------------------------------------------
// gsound_get_sound_ready_for_effect
// ---------------------------------------------------------------------------
function gsound_get_sound_ready_for_effect: PSound;
var
  rc: Integer;
  sound: PSound;
begin
  sound := soundAllocate(5, 10);
  if sound = nil then
  begin
    if gsound_debug then
      debug_printf(' Can''t allocate sound for effect. ');
    if gsound_debug then
      debug_printf('soundAllocate returned: %d, %s'#10, [0, StrPas(soundError(0))]);
    Exit(nil);
  end;

  if sfxc_is_initialized <> 0 then
    rc := soundSetFileIO(sound, @sfxc_cached_open, @sfxc_cached_close, @sfxc_cached_read, @sfxc_cached_write, @sfxc_cached_seek, @sfxc_cached_tell, @sfxc_cached_file_size)
  else
    rc := soundSetFileIO(sound, @audioOpen_cdecl, @audioCloseFile_cdecl, @audioRead_cdecl, nil, @audioSeek_cdecl, @gsound_compressed_tell, @audioFileSize_cdecl);

  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('Can''t set file IO on sound effect.'#10);
    if gsound_debug then
      debug_printf('soundSetFileIO returned: %d, %s'#10, [rc, StrPas(soundError(rc))]);
    soundDelete(sound);
    Exit(nil);
  end;

  rc := soundSetCallback(sound, @gsound_internal_effect_callback, nil);
  if rc <> 0 then
  begin
    if gsound_debug then
      debug_printf('failed because the callback could not be set.'#10);
    if gsound_debug then
      debug_printf('soundSetCallback returned: %d, %s'#10, [rc, StrPas(soundError(rc))]);
    soundDelete(sound);
    Exit(nil);
  end;

  soundVolume(sound, sndfx_volume);

  Result := sound;
end;

// ---------------------------------------------------------------------------
// gsound_file_exists_f
// ---------------------------------------------------------------------------
function gsound_file_exists_f(const fname: PAnsiChar): Boolean;
var
  f: Pointer;
begin
  f := compat_fopen(fname, 'rb');
  if f = nil then
    Exit(False);

  libc_fclose(f);

  Result := True;
end;

// ---------------------------------------------------------------------------
// gsound_file_exists_db
// ---------------------------------------------------------------------------
function gsound_file_exists_db(const path: PAnsiChar): Integer;
var
  de: TDirEntry;
begin
  if db_dir_entry(path, @de) = 0 then
    Result := 1
  else
    Result := 0;
end;

// ---------------------------------------------------------------------------
// gsound_setup_paths
// ---------------------------------------------------------------------------
function gsound_setup_paths: Integer;
begin
  // TODO: Incomplete.
  Result := 0;
end;

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------
initialization
  StrCopy(@_aSoundSfx[0], 'sound\sfx\');
  StrCopy(@_aSoundMusic_0[0], 'sound\music\');
  StrCopy(@_aSoundSpeech_0[0], 'sound\speech\');

  sound_sfx_path := @_aSoundSfx[0];
  sound_music_path1 := @_aSoundMusic_0[0];
  sound_music_path2 := @_aSoundMusic_0[0];
  sound_speech_path := @_aSoundSpeech_0[0];

  background_fname_copied[0] := #0;
  sfx_file_name[0] := #0;
  background_fname_requested[0] := #0;

end.
