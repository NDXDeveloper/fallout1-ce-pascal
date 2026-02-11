{$MODE OBJFPC}{$H+}
// Converted from: src/game/gconfig.h + gconfig.cc
// Game configuration: defaults, loading, and saving of fallout.cfg.
unit u_gconfig;

interface

uses
  u_config;

const
  GAME_CONFIG_FILE_NAME = 'fallout.cfg';

  GAME_CONFIG_SYSTEM_KEY      = 'system';
  GAME_CONFIG_PREFERENCES_KEY = 'preferences';
  GAME_CONFIG_SOUND_KEY       = 'sound';
  GAME_CONFIG_MAPPER_KEY      = 'mapper';
  GAME_CONFIG_DEBUG_KEY        = 'debug';

  GAME_CONFIG_EXECUTABLE_KEY           = 'executable';
  GAME_CONFIG_MASTER_DAT_KEY           = 'master_dat';
  GAME_CONFIG_MASTER_PATCHES_KEY       = 'master_patches';
  GAME_CONFIG_CRITTER_DAT_KEY          = 'critter_dat';
  GAME_CONFIG_CRITTER_PATCHES_KEY      = 'critter_patches';
  GAME_CONFIG_PATCHES_KEY              = 'patches';
  GAME_CONFIG_LANGUAGE_KEY             = 'language';
  GAME_CONFIG_SCROLL_LOCK_KEY          = 'scroll_lock';
  GAME_CONFIG_INTERRUPT_WALK_KEY       = 'interrupt_walk';
  GAME_CONFIG_ART_CACHE_SIZE_KEY       = 'art_cache_size';
  GAME_CONFIG_COLOR_CYCLING_KEY        = 'color_cycling';
  GAME_CONFIG_CYCLE_SPEED_FACTOR_KEY   = 'cycle_speed_factor';
  GAME_CONFIG_HASHING_KEY              = 'hashing';
  GAME_CONFIG_SPLASH_KEY               = 'splash';
  GAME_CONFIG_FREE_SPACE_KEY           = 'free_space';
  GAME_CONFIG_TIMES_RUN_KEY            = 'times_run';
  GAME_CONFIG_GAME_DIFFICULTY_KEY      = 'game_difficulty';
  GAME_CONFIG_RUNNING_BURNING_GUY_KEY  = 'running_burning_guy';
  GAME_CONFIG_COMBAT_DIFFICULTY_KEY    = 'combat_difficulty';
  GAME_CONFIG_VIOLENCE_LEVEL_KEY       = 'violence_level';
  GAME_CONFIG_TARGET_HIGHLIGHT_KEY     = 'target_highlight';
  GAME_CONFIG_ITEM_HIGHLIGHT_KEY       = 'item_highlight';
  GAME_CONFIG_COMBAT_LOOKS_KEY         = 'combat_looks';
  GAME_CONFIG_COMBAT_MESSAGES_KEY      = 'combat_messages';
  GAME_CONFIG_COMBAT_TAUNTS_KEY        = 'combat_taunts';
  GAME_CONFIG_LANGUAGE_FILTER_KEY      = 'language_filter';
  GAME_CONFIG_RUNNING_KEY              = 'running';
  GAME_CONFIG_SUBTITLES_KEY            = 'subtitles';
  GAME_CONFIG_COMBAT_SPEED_KEY         = 'combat_speed';
  GAME_CONFIG_PLAYER_SPEED_KEY         = 'player_speed';
  GAME_CONFIG_TEXT_BASE_DELAY_KEY      = 'text_base_delay';
  GAME_CONFIG_TEXT_LINE_DELAY_KEY      = 'text_line_delay';
  GAME_CONFIG_BRIGHTNESS_KEY           = 'brightness';
  GAME_CONFIG_MOUSE_SENSITIVITY_KEY    = 'mouse_sensitivity';
  GAME_CONFIG_INITIALIZE_KEY           = 'initialize';
  GAME_CONFIG_DEVICE_KEY               = 'device';
  GAME_CONFIG_PORT_KEY                 = 'port';
  GAME_CONFIG_IRQ_KEY                  = 'irq';
  GAME_CONFIG_DMA_KEY                  = 'dma';
  GAME_CONFIG_SOUNDS_KEY               = 'sounds';
  GAME_CONFIG_MUSIC_KEY                = 'music';
  GAME_CONFIG_SPEECH_KEY               = 'speech';
  GAME_CONFIG_MASTER_VOLUME_KEY        = 'master_volume';
  GAME_CONFIG_MUSIC_VOLUME_KEY         = 'music_volume';
  GAME_CONFIG_SNDFX_VOLUME_KEY         = 'sndfx_volume';
  GAME_CONFIG_SPEECH_VOLUME_KEY        = 'speech_volume';
  GAME_CONFIG_CACHE_SIZE_KEY           = 'cache_size';
  GAME_CONFIG_MUSIC_PATH1_KEY          = 'music_path1';
  GAME_CONFIG_MUSIC_PATH2_KEY          = 'music_path2';
  GAME_CONFIG_DEBUG_SFXC_KEY           = 'debug_sfxc';
  GAME_CONFIG_MODE_KEY                 = 'mode';
  GAME_CONFIG_SHOW_TILE_NUM_KEY        = 'show_tile_num';
  GAME_CONFIG_SHOW_SCRIPT_MESSAGES_KEY = 'show_script_messages';
  GAME_CONFIG_SHOW_LOAD_INFO_KEY       = 'show_load_info';
  GAME_CONFIG_OUTPUT_MAP_DATA_INFO_KEY = 'output_map_data_info';
  GAME_CONFIG_OVERRIDE_LIBRARIAN_KEY   = 'override_librarian';
  GAME_CONFIG_USE_ART_NOT_PROTOS_KEY   = 'use_art_not_protos';
  GAME_CONFIG_REBUILD_PROTOS_KEY       = 'rebuild_protos';
  GAME_CONFIG_FIX_MAP_OBJECTS_KEY      = 'fix_map_objects';
  GAME_CONFIG_FIX_MAP_INVENTORY_KEY    = 'fix_map_inventory';
  GAME_CONFIG_IGNORE_REBUILD_ERRORS_KEY = 'ignore_rebuild_errors';
  GAME_CONFIG_SHOW_PID_NUMBERS_KEY     = 'show_pid_numbers';
  GAME_CONFIG_SAVE_TEXT_MAPS_KEY       = 'save_text_maps';
  GAME_CONFIG_RUN_MAPPER_AS_GAME_KEY   = 'run_mapper_as_game';
  GAME_CONFIG_DEFAULT_F8_AS_GAME_KEY   = 'default_f8_as_game';
  GAME_CONFIG_PLAYER_SPEEDUP_KEY       = 'player_speedup';

  ENGLISH = 'english';
  FRENCH  = 'french';
  GERMAN  = 'german';
  ITALIAN = 'italian';
  SPANISH = 'spanish';

  // GameDifficulty
  GAME_DIFFICULTY_EASY   = 0;
  GAME_DIFFICULTY_NORMAL = 1;
  GAME_DIFFICULTY_HARD   = 2;

  // CombatDifficulty
  COMBAT_DIFFICULTY_EASY   = 0;
  COMBAT_DIFFICULTY_NORMAL = 1;
  COMBAT_DIFFICULTY_HARD   = 2;

  // ViolenceLevel
  VIOLENCE_LEVEL_NONE          = 0;
  VIOLENCE_LEVEL_MINIMAL       = 1;
  VIOLENCE_LEVEL_NORMAL        = 2;
  VIOLENCE_LEVEL_MAXIMUM_BLOOD = 3;

  // TargetHighlight
  TARGET_HIGHLIGHT_OFF            = 0;
  TARGET_HIGHLIGHT_ON             = 1;
  TARGET_HIGHLIGHT_TARGETING_ONLY = 2;

var
  game_config: TConfig;

function gconfig_init(isMapper: Boolean; argc: Integer; argv: PPAnsiChar): Boolean;
function gconfig_save: Boolean;
function gconfig_exit(shouldSave: Boolean): Boolean;

implementation

uses
  SysUtils, u_platform_compat;

var
  gconfig_initialized: Boolean = False;
  gconfig_file_name: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;

function gconfig_init(isMapper: Boolean; argc: Integer; argv: PPAnsiChar): Boolean;
var
  sep: PAnsiChar;
  arg0: PAnsiChar;
begin
  if gconfig_initialized then
    Exit(False);

  if not config_init(@game_config) then
    Exit(False);

  // Initialize defaults
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_EXECUTABLE_KEY, 'game');
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_DAT_KEY, 'master.dat');
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, 'data');
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CRITTER_DAT_KEY, 'critter.dat');
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CRITTER_PATCHES_KEY, 'data');
  config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_LANGUAGE_KEY, ENGLISH);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_SCROLL_LOCK_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_INTERRUPT_WALK_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_ART_CACHE_SIZE_KEY, 8);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_COLOR_CYCLING_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_HASHING_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_SPLASH_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_FREE_SPACE_KEY, 20480);

  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_GAME_DIFFICULTY_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, 3);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, 2);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_ITEM_HIGHLIGHT_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_BURNING_GUY_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_MESSAGES_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_TAUNTS_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_SUBTITLES_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_SPEED_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_PLAYER_SPEED_KEY, 0);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_BASE_DELAY_KEY, 3.5);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_LINE_DELAY_KEY, 1.399994);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, 1.0);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_MOUSE_SENSITIVITY_KEY, 1.0);

  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_INITIALIZE_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_DEVICE_KEY, -1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_PORT_KEY, -1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_IRQ_KEY, -1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_DMA_KEY, -1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SOUNDS_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_KEY, 1);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MASTER_VOLUME_KEY, 22281);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_VOLUME_KEY, 22281);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SNDFX_VOLUME_KEY, 22281);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_VOLUME_KEY, 22281);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_CACHE_SIZE_KEY, 448);
  config_set_string(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_PATH1_KEY, 'sound\music\');
  config_set_string(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_PATH2_KEY, 'sound\music\');

  config_set_string(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_MODE_KEY, 'environment');
  config_set_value(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_TILE_NUM_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_SCRIPT_MESSAGES_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_LOAD_INFO_KEY, 0);
  config_set_value(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_OUTPUT_MAP_DATA_INFO_KEY, 0);

  if isMapper then
  begin
    config_set_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_EXECUTABLE_KEY, 'mapper');
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_OVERRIDE_LIBRARIAN_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_USE_ART_NOT_PROTOS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_REBUILD_PROTOS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_FIX_MAP_OBJECTS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_FIX_MAP_INVENTORY_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_IGNORE_REBUILD_ERRORS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_SHOW_PID_NUMBERS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_SAVE_TEXT_MAPS_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_RUN_MAPPER_AS_GAME_KEY, 0);
    config_set_value(@game_config, GAME_CONFIG_MAPPER_KEY, GAME_CONFIG_DEFAULT_F8_AS_GAME_KEY, 1);
  end;

  // Build fallout.cfg path from argv[0]
  arg0 := PPAnsiChar(argv)^;
  sep := StrRScan(arg0, '\');
  if sep <> nil then
  begin
    sep^ := #0;
    StrLFmt(@gconfig_file_name[0], SizeOf(gconfig_file_name) - 1, '%s\%s', [arg0, GAME_CONFIG_FILE_NAME]);
    sep^ := '\';
  end
  else
    StrCopy(@gconfig_file_name[0], GAME_CONFIG_FILE_NAME);

  // Load config file (overrides defaults)
  config_load(@game_config, @gconfig_file_name[0], False);

  // Parse command line args (overrides config file)
  config_cmd_line_parse(@game_config, argc, PPAnsiChar(argv));

  gconfig_initialized := True;
  Result := True;
end;

function gconfig_save: Boolean;
begin
  if not gconfig_initialized then
    Exit(False);

  if not config_save(@game_config, @gconfig_file_name[0], False) then
    Exit(False);

  Result := True;
end;

function gconfig_exit(shouldSave: Boolean): Boolean;
begin
  if not gconfig_initialized then
    Exit(False);

  Result := True;

  if shouldSave then
  begin
    if not config_save(@game_config, @gconfig_file_name[0], False) then
      Result := False;
  end;

  config_exit(@game_config);
  gconfig_initialized := False;
end;

end.
