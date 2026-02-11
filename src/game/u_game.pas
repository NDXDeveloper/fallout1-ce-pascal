{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/game.h + game.cc
// Game initialization, shutdown, input handling, global variables, state machine.
unit u_game;

interface

uses
  u_message, u_db;

type
  PPInteger = ^PInteger;

  GameState = (
    GAME_STATE_0 = 0,
    GAME_STATE_1 = 1,
    GAME_STATE_2 = 2,
    GAME_STATE_3 = 3,
    GAME_STATE_4 = 4,
    GAME_STATE_5 = 5
  );

var
  game_global_vars: PInteger;
  num_game_global_vars: Integer;
  msg_path: PAnsiChar;
  game_user_wants_to_quit: Integer;
  misc_message_file: TMessageList;
  master_db_handle: PDB_DATABASE;
  critter_db_handle: PDB_DATABASE;

function game_init(const windowTitle: PAnsiChar; isMapper: Boolean; font: Integer; flags: Integer; argc: Integer; argv: PPAnsiChar): Integer;
procedure game_reset;
procedure game_exit;
function game_handle_input(eventCode: Integer; isInCombatMode: Boolean): Integer;
procedure game_ui_disable(a1: Integer);
procedure game_ui_enable;
function game_ui_is_disabled: Boolean;
function game_get_global_var(v: Integer): Integer;
function game_set_global_var(v: Integer; value: Integer): Integer;
function game_load_info: Integer;
function game_load_info_vars(const path: PAnsiChar; const section: PAnsiChar; variablesListLengthPtr: PInteger; variablesListPtr: PPInteger): Integer;
function game_state: Integer;
function game_state_request(a1: Integer): Integer;
procedure game_state_update;
function game_quit_with_confirm: Integer;

implementation

uses
  SysUtils,
  u_cache,      // PCacheEntry, PPCacheEntry
  u_config,     // TConfig, config_init, config_load, config_get_value, etc.
  u_gconfig,    // gconfig_init, gconfig_exit, game_config, GAME_CONFIG_* constants
  u_palette,    // palette_init, palette_reset, palette_exit, palette_set_to, palette_fade_to, loadColorTable, black_palette
  u_color,      // colorTable, intensityColorTable, cmap
  u_roll,       // roll_init, roll_reset, roll_exit
  u_skill,      // skill_init, skill_reset, skill_exit
  u_stat,       // stat_init, stat_reset, stat_exit
  u_perk,       // perk_init, perk_reset, perk_exit
  u_trait,      // trait_init, trait_reset, trait_exit
  u_item,       // item_init, item_reset, item_exit
  u_queue,      // queue_init, queue_reset, queue_exit
  u_critter,    // critter_init, critter_reset, critter_exit
  u_combatai,   // combat_ai_init, combat_ai_reset, combat_ai_exit
  u_inventry,   // inven_reset_dude, handle_inventory
  u_anim,       // anim_init, anim_reset, anim_exit, register_begin, register_end, etc.
  u_scripts,    // scr_init, scr_exit, scr_reset, scr_game_init, scr_game_exit, scr_game_reset, scr_disable, game_time_date, game_time_hour_str
  u_combat,     // combat_init, combat_reset, combat_exit, combat
  u_gmouse,     // gmouse_init, gmouse_reset, gmouse_exit, gmouse_3d_off, gmouse_3d_on, etc.
  u_display,    // iso_init (actually in u_map), display_print
  u_proto,      // proto_init, proto_reset, proto_exit
  u_map,        // KillOldMaps (actually in u_loadsave), map_scroll, map_set_elevation, etc.
  u_worldmap,   // init_world_map
  u_editor,     // CharEditInit, editor_design
  u_pipboy,     // pip_init, pipboy
  u_loadsave,   // InitLoadSave, ResetLoadSave, SaveGame, LoadGame, LOAD_SAVE_MODE_*
  u_gdialog,    // gdialog_init, gdialog_reset, gdialog_exit, dialogue_system_enter
  u_automap,    // automap_init, automap_reset, automap_exit, automap
  u_options,    // init_options_menu, do_options, PauseWindow, IncGamma, DecGamma
  u_gmovie,     // gmovie_init, gmovie_reset, gmovie_exit
  u_moviefx,    // moviefx_init, moviefx_reset, moviefx_exit
  u_int_movie,  // initMovie, movieStop, movieClose
  u_cycle,      // cycle_is_enabled, cycle_disable, cycle_enable
  u_intface,    // intface_is_enabled, intface_enable, intface_disable, etc.
  u_art,        // art_id, art_ptr_lock_data, art_ptr_unlock
  u_tile,       // tile_disable_refresh, tile_set_center, tile_scroll_to, TILE_SET_CENTER_REFRESH_WINDOW
  u_gnw,        // win_add, win_delete, win_get_buf, win_show, GNWSystemError, win_set_minimized_title
  u_gnw_types,  // WINDOW_HIDDEN, WINDOW_MOVE_ON_TOP
  u_input,      // get_input, register_screendump, register_pause, default_screendump
  u_mouse,      // mouse_get_buttons, mouse_get_position, mouse_hidden, mouse_show, mouse_hide, mouseGetWheel, MOUSE_EVENT_*
  u_kb,         // kb_disable, kb_enable, kb_clear, keys, KEY_* constants
  u_grbuf,      // buf_to_buf, buf_fill
  u_svga,       // screenGetWidth, screenGetHeight, scr_size, scr_blit, renderPresent, sharedFpsLimiter
  u_svga_types, // TVideoOptions, PVideoOptions
  u_debug,      // debug_printf
  u_memory,     // mem_malloc, mem_free, mem_realloc
  u_text,       // text_add_manager, text_font, TFontMgr
  u_version,    // VERSION_MAX, VERSION_BUILD_TIME, getverstr
  u_bmpdlog,    // dialog_out, DIALOG_BOX_YES_NO
  u_skilldex,   // skilldex_select, SKILLDEX_RC_*
  u_skill_defs, // SKILL_SNEAK
  u_actions,    // action_skill_use
  u_object,     // obj_dude
  u_object_types, // OBJ_TYPE_INTERFACE
  u_platform_compat, // COMPAT_MAX_PATH
  u_fps_limiter,     // TFpsLimiter
  u_gmemory,         // gmemory_init
  u_int_window,      // initWindow, windowClose
  u_combat_defs,     // PSTRUCT_664980
  u_sdl2,            // SDL_NUM_SCANCODES
  u_gsound,          // gsound_init, gsound_reset, gsound_exit, gsound_play_sfx_file, gsound_get_master_volume, gsound_set_master_volume
  u_fontmgr;         // FMInit, FMExit, FMtext_font, FMtext_to_buf, etc.

const
  HELP_SCREEN_WIDTH  = 640;
  HELP_SCREEN_HEIGHT = 480;

  SPLASH_WIDTH  = 640;
  SPLASH_HEIGHT = 480;
  SPLASH_COUNT  = 10;

  // SDL scancodes for alt keys
  SDL_SCANCODE_LALT = 226;
  SDL_SCANCODE_RALT = 230;

// Forward declarations for static functions
function game_screendump(width, height: Integer; buffer, pal: PByte): Integer; cdecl; forward;
procedure game_unload_info; forward;
procedure game_help; forward;
function game_init_databases: Integer; forward;
procedure game_splash_screen; forward;

// Module-level implementation variables (C++ static locals)
var
  alias_mgr: TFontMgr = (
    LowFontNum: 100;
    HighFontNum: 110;
    TextFont: @FMtext_font;
    TextToBuf: @FMtext_to_buf;
    TextHeight: @FMtext_height;
    TextWidth: @FMtext_width;
    TextCharWidth: @FMtext_char_width;
    TextMonoWidth: @FMtext_mono_width;
    TextSpacing: @FMtext_spacing;
    TextSize: @FMtext_size;
    TextMax: @FMtext_max;
  );

  game_ui_disabled: Boolean = False;
  game_state_cur: Integer = 0; // GAME_STATE_0
  game_in_mapper: Boolean = False;
  version_build_time_str: PAnsiChar;

// 0x43B080
function game_init(const windowTitle: PAnsiChar; isMapper: Boolean; font: Integer; flags: Integer; argc: Integer; argv: PPAnsiChar): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  video_options: TVideoOptions;
  resolutionConfig: TConfig;
  screenWidth: Integer;
  screenHeight: Integer;
  windowed: Boolean;
  scaleValue: Integer;
begin
  WriteLn(StdErr, '[INIT] game_init: start');
  if gmemory_init = -1 then
  begin
    WriteLn(StdErr, '[INIT] gmemory_init FAILED');
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] gmemory_init OK');

  gconfig_init(isMapper, argc, argv);
  WriteLn(StdErr, '[INIT] gconfig_init OK');

  game_in_mapper := isMapper;

  if game_init_databases = -1 then
  begin
    WriteLn(StdErr, '[INIT] game_init_databases FAILED');
    gconfig_exit(False);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] game_init_databases OK');

  win_set_minimized_title(windowTitle);

  video_options.Width := 640;
  video_options.Height := 480;
  video_options.Fullscreen := LongBool(True);
  video_options.Scale := 1;

  if config_init(@resolutionConfig) then
  begin
    if config_load(@resolutionConfig, 'f1_res.ini', False) then
    begin
      if config_get_value(@resolutionConfig, 'MAIN', 'SCR_WIDTH', @screenWidth) then
      begin
        if screenWidth > 640 then
          video_options.Width := screenWidth
        else
          video_options.Width := 640;
      end;

      if config_get_value(@resolutionConfig, 'MAIN', 'SCR_HEIGHT', @screenHeight) then
      begin
        if screenHeight > 480 then
          video_options.Height := screenHeight
        else
          video_options.Height := 480;
      end;

      if configGetBool(@resolutionConfig, 'MAIN', 'WINDOWED', @windowed) then
        video_options.Fullscreen := LongBool(not windowed);

      if config_get_value(@resolutionConfig, 'MAIN', 'SCALE_2X', @scaleValue) then
      begin
        video_options.Scale := scaleValue + 1;
        video_options.Width := video_options.Width div video_options.Scale;
        video_options.Height := video_options.Height div video_options.Scale;
      end;
    end;
    config_exit(@resolutionConfig);
  end;

  WriteLn(StdErr, '[INIT] calling initWindow');
  initWindow(@video_options, flags);
  WriteLn(StdErr, '[INIT] initWindow OK');
  palette_init;
  WriteLn(StdErr, '[INIT] palette_init OK');

  if not game_in_mapper then
  begin
    WriteLn(StdErr, '[INIT] calling game_splash_screen');
    game_splash_screen;
    WriteLn(StdErr, '[INIT] game_splash_screen OK');
  end;

  FMInit;
  WriteLn(StdErr, '[INIT] FMInit OK');
  text_add_manager(@alias_mgr);
  text_font(font);

  register_screendump(KEY_F12, @game_screendump);
  register_pause(-1, nil);

  tile_disable_refresh;

  // FIXME: Meaningless, patches path used by this function call is not
  // properly initialized yet.
  KillOldMaps;

  roll_init;
  init_message;
  skill_init;
  stat_init;
  perk_init;
  trait_init;
  item_init;
  queue_init;
  critter_init;
  combat_ai_init;
  inven_reset_dude;
  WriteLn(StdErr, '[INIT] basic inits done (roll..inven_reset_dude)');

  if gsound_init <> 0 then
    debug_printf('Sound initialization failed.'#10, []);
  WriteLn(StdErr, '[INIT] gsound_init done');

  debug_printf('>gsound_init'#9, []);

  initMovie;
  WriteLn(StdErr, '[INIT] initMovie done');
  debug_printf('>initMovie'#9#9, []);

  if gmovie_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] gmovie_init FAILED');
    debug_printf('Failed on gmovie_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] gmovie_init OK');

  debug_printf('>gmovie_init'#9, []);

  if moviefx_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] moviefx_init FAILED');
    debug_printf('Failed on moviefx_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] moviefx_init OK');

  debug_printf('>moviefx_init'#9, []);

  if iso_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] iso_init FAILED');
    debug_printf('Failed on iso_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] iso_init OK');

  debug_printf('>iso_init'#9, []);

  if gmouse_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] gmouse_init FAILED');
    debug_printf('Failed on gmouse_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] gmouse_init OK');

  debug_printf('>gmouse_init'#9, []);

  if proto_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] proto_init FAILED');
    debug_printf('Failed on proto_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] proto_init OK');

  debug_printf('>proto_init'#9, []);

  anim_init;
  WriteLn(StdErr, '[INIT] anim_init OK');
  debug_printf('>anim_init'#9, []);

  if scr_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] scr_init FAILED');
    debug_printf('Failed on scr_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] scr_init OK');

  debug_printf('>scr_init'#9, []);

  if game_load_info <> 0 then
  begin
    WriteLn(StdErr, '[INIT] game_load_info FAILED');
    debug_printf('Failed on game_load_info'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] game_load_info OK');

  debug_printf('>game_load_info'#9, []);

  if scr_game_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] scr_game_init FAILED');
    debug_printf('Failed on scr_game_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] scr_game_init OK');

  debug_printf('>scr_game_init'#9, []);

  if init_world_map <> 0 then
  begin
    WriteLn(StdErr, '[INIT] init_world_map FAILED');
    debug_printf('Failed on init_world_map'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] init_world_map OK');

  debug_printf('>init_world_map'#9, []);

  CharEditInit;
  WriteLn(StdErr, '[INIT] CharEditInit OK');
  debug_printf('>CharEditInit'#9, []);

  pip_init;
  WriteLn(StdErr, '[INIT] pip_init OK');
  debug_printf('>pip_init'#9#9, []);

  InitLoadSave;
  WriteLn(StdErr, '[INIT] InitLoadSave OK');
  debug_printf('>InitLoadSave'#9, []);

  if gdialog_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] gdialog_init FAILED');
    debug_printf('Failed on gdialog_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] gdialog_init OK');

  debug_printf('>gdialog_init'#9, []);

  if combat_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] combat_init FAILED');
    debug_printf('Failed on combat_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] combat_init OK');

  debug_printf('>combat_init'#9, []);

  if automap_init <> 0 then
  begin
    WriteLn(StdErr, '[INIT] automap_init FAILED');
    debug_printf('Failed on automap_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] automap_init OK');

  debug_printf('>automap_init'#9, []);

  if not message_init(@misc_message_file) then
  begin
    WriteLn(StdErr, '[INIT] message_init FAILED');
    debug_printf('Failed on message_init'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] message_init OK');

  debug_printf('>message_init'#9, []);

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'misc.msg']);

  if not message_load(@misc_message_file, @path[0]) then
  begin
    WriteLn(StdErr, '[INIT] message_load (misc.msg) FAILED');
    debug_printf('Failed on message_load'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] message_load OK');

  debug_printf('>message_load'#9, []);

  if scr_disable <> 0 then
  begin
    WriteLn(StdErr, '[INIT] scr_disable FAILED');
    debug_printf('Failed on scr_disable'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] scr_disable OK');

  debug_printf('>scr_disable'#9, []);

  if init_options_menu <> 0 then
  begin
    WriteLn(StdErr, '[INIT] init_options_menu FAILED');
    debug_printf('Failed on init_options_menu'#10, []);
    Exit(-1);
  end;
  WriteLn(StdErr, '[INIT] init_options_menu OK');

  debug_printf('>init_options_menu'#10, []);

  WriteLn(StdErr, '[INIT] game_init completed successfully');
  Result := 0;
end;

// 0x43B5A8
procedure game_reset;
begin
  tile_disable_refresh;
  palette_reset;
  roll_reset;
  skill_reset;
  stat_reset;
  perk_reset;
  trait_reset;
  item_reset;
  queue_reset;
  anim_reset;
  KillOldMaps;
  critter_reset;
  combat_ai_reset;
  inven_reset_dude;
  gsound_reset;
  movieStop;
  moviefx_reset;
  gmovie_reset;
  iso_reset;
  gmouse_reset;
  proto_reset;
  scr_reset;
  game_load_info;
  scr_game_reset;
  init_world_map;
  CharEditInit;
  pip_init;
  ResetLoadSave;
  gdialog_reset;
  combat_reset;
  game_user_wants_to_quit := 0;
  automap_reset;
  init_options_menu;
end;

// 0x43B654
procedure game_exit;
begin
  tile_disable_refresh;
  message_exit(@misc_message_file);
  combat_exit;
  gdialog_exit;
  scr_game_exit;

  // NOTE: Uninline.
  game_unload_info;

  scr_exit;
  anim_exit;
  proto_exit;
  gmouse_exit;
  iso_exit;
  moviefx_exit;
  gmovie_exit;
  movieClose;
  gsound_exit;
  combat_ai_exit;
  critter_exit;
  item_exit;
  queue_exit;
  perk_exit;
  stat_exit;
  skill_exit;
  trait_exit;
  roll_exit;
  exit_message;
  automap_exit;
  palette_exit;
  FMExit;
  windowClose;
  db_exit;
  gconfig_exit(True);
end;

// 0x43B748
function game_handle_input(eventCode: Integer; isInCombatMode: Boolean): Integer;
var
  wheelX, wheelY: Integer;
  dx, dy: Integer;
  mouseState: Integer;
  mouseX, mouseY: Integer;
  isoWasEnabled: Boolean;
  mode: Integer;
  rc: Integer;
  messageListItem: TMessageListItem;
  title: array[0..127] of AnsiChar;
  msg: PAnsiChar;
  month, day, year: Integer;
  messageList: TMessageList;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  timeStr: PAnsiChar;
  dateStr: array[0..127] of AnsiChar;
  version: array[0..VERSION_MAX - 1] of AnsiChar;
begin
  // NOTE: Uninline.
  if game_state = Ord(GAME_STATE_5) then
    dialogue_system_enter;

  if eventCode = -1 then
  begin
    if (mouse_get_buttons and MOUSE_EVENT_WHEEL) <> 0 then
    begin
      mouseGetWheel(@wheelX, @wheelY);

      dx := 0;
      if wheelX > 0 then
        dx := 1
      else if wheelX < 0 then
        dx := -1;

      dy := 0;
      if wheelY > 0 then
        dy := -1
      else if wheelY < 0 then
        dy := 1;

      map_scroll(dx, dy);
    end;
    Exit(0);
  end;

  if eventCode = -2 then
  begin
    mouseState := mouse_get_buttons;
    mouse_get_position(@mouseX, @mouseY);

    if (mouseState and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
    begin
      if (mouseState and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0 then
      begin
        if (mouseX = scr_size.ulx) or (mouseX = scr_size.lrx)
            or (mouseY = scr_size.uly) or (mouseY = scr_size.lry) then
          gmouse_clicked_on_edge := True
        else
          gmouse_clicked_on_edge := False;
      end;
    end
    else
    begin
      if (mouseState and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
        gmouse_clicked_on_edge := False;
    end;

    gmouse_handle_event(mouseX, mouseY, mouseState);
    Exit(0);
  end;

  if gmouse_is_scrolling <> 0 then
    Exit(0);

  case eventCode of
    -20:
      begin
        if intface_is_enabled then
          intface_use_item;
      end;
    KEY_CTRL_Q,
    KEY_CTRL_X,
    KEY_F10:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        game_quit_with_confirm;
      end;
    KEY_TAB:
      begin
        if intface_is_enabled
            and (keys[SDL_SCANCODE_LALT] = 0)
            and (keys[SDL_SCANCODE_RALT] = 0) then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          automap(True, False);
        end;
      end;
    KEY_CTRL_P:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        PauseWindow(False);
      end;
    KEY_UPPERCASE_A,
    KEY_LOWERCASE_A:
      begin
        if intface_is_enabled then
        begin
          if not isInCombatMode then
            combat(nil);
        end;
      end;
    KEY_UPPERCASE_N,
    KEY_LOWERCASE_N:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          intface_toggle_item_state;
        end;
      end;
    KEY_UPPERCASE_M,
    KEY_LOWERCASE_M:
      begin
        gmouse_3d_toggle_mode;
      end;
    KEY_UPPERCASE_B,
    KEY_LOWERCASE_B:
      begin
        // change active hand
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          intface_toggle_items(True);
        end;
      end;
    KEY_UPPERCASE_C,
    KEY_LOWERCASE_C:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          isoWasEnabled := map_disable_bk_processes;
          editor_design(False);
          if isoWasEnabled then
            map_enable_bk_processes;
        end;
      end;
    KEY_UPPERCASE_I,
    KEY_LOWERCASE_I:
      begin
        // open inventory
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          handle_inventory;
        end;
      end;
    KEY_ESCAPE,
    KEY_UPPERCASE_O,
    KEY_LOWERCASE_O:
      begin
        // options
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          do_options;
        end;
      end;
    KEY_UPPERCASE_P,
    KEY_LOWERCASE_P:
      begin
        // pipboy
        if intface_is_enabled then
        begin
          if isInCombatMode then
          begin
            gsound_play_sfx_file('iisxxxx1');

            // Pipboy not available in combat!
            StrCopy(@title[0], getmsg(@misc_message_file, @messageListItem, 7));
            dialog_out(@title[0], nil, 0, 192, 116, colorTable[32328], nil, colorTable[32328], 0);
          end
          else
          begin
            gsound_play_sfx_file('ib1p1xx1');
            pipboy(0); // false
          end;
        end;
      end;
    KEY_UPPERCASE_S,
    KEY_LOWERCASE_S:
      begin
        // skilldex
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');

          mode := -1;

          rc := skilldex_select;

          // Remap Skilldex result code to action.
          case rc of
            SKILLDEX_RC_ERROR:
              debug_printf(#10' ** Error calling skilldex_select()! ** '#10, []);
            SKILLDEX_RC_SNEAK:
              action_skill_use(Ord(SKILL_SNEAK));
            SKILLDEX_RC_LOCKPICK:
              mode := GAME_MOUSE_MODE_USE_LOCKPICK;
            SKILLDEX_RC_STEAL:
              mode := GAME_MOUSE_MODE_USE_STEAL;
            SKILLDEX_RC_TRAPS:
              mode := GAME_MOUSE_MODE_USE_TRAPS;
            SKILLDEX_RC_FIRST_AID:
              mode := GAME_MOUSE_MODE_USE_FIRST_AID;
            SKILLDEX_RC_DOCTOR:
              mode := GAME_MOUSE_MODE_USE_DOCTOR;
            SKILLDEX_RC_SCIENCE:
              mode := GAME_MOUSE_MODE_USE_SCIENCE;
            SKILLDEX_RC_REPAIR:
              mode := GAME_MOUSE_MODE_USE_REPAIR;
          end;

          if mode <> -1 then
          begin
            gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
            gmouse_3d_set_mode(mode);
          end;
        end;
      end;
    KEY_UPPERCASE_Z,
    KEY_LOWERCASE_Z:
      begin
        if intface_is_enabled then
        begin
          if isInCombatMode then
          begin
            gsound_play_sfx_file('iisxxxx1');

            // Pipboy not available in combat!
            StrCopy(@title[0], getmsg(@misc_message_file, @messageListItem, 7));
            dialog_out(@title[0], nil, 0, 192, 116, colorTable[32328], nil, colorTable[32328], 0);
          end
          else
          begin
            gsound_play_sfx_file('ib1p1xx1');
            pipboy(1); // true
          end;
        end;
      end;
    KEY_HOME:
      begin
        if obj_dude^.Elevation <> map_elevation then
          map_set_elevation(obj_dude^.Elevation);

        if game_in_mapper then
          tile_set_center(obj_dude^.tile, TILE_SET_CENTER_REFRESH_WINDOW)
        else
          tile_scroll_to(obj_dude^.tile, 2);
      end;
    KEY_1,
    KEY_EXCLAMATION:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          action_skill_use(Ord(SKILL_SNEAK));
        end;
      end;
    KEY_2,
    KEY_AT:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_LOCKPICK);
        end;
      end;
    KEY_3,
    KEY_NUMBER_SIGN:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_STEAL);
        end;
      end;
    KEY_4,
    KEY_DOLLAR:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_TRAPS);
        end;
      end;
    KEY_5,
    KEY_PERCENT:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_FIRST_AID);
        end;
      end;
    KEY_6,
    KEY_CARET:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_DOCTOR);
        end;
      end;
    KEY_7,
    KEY_AMPERSAND:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_SCIENCE);
        end;
      end;
    KEY_8,
    KEY_ASTERISK:
      begin
        if intface_is_enabled then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
          gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_REPAIR);
        end;
      end;
    KEY_MINUS,
    KEY_UNDERSCORE:
      begin
        DecGamma;
      end;
    KEY_EQUAL,
    KEY_PLUS:
      begin
        IncGamma;
      end;
    KEY_COMMA,
    KEY_LESS:
      begin
        if register_begin(ANIMATION_REQUEST_RESERVED) = 0 then
        begin
          register_object_dec_rotation(obj_dude);
          register_end;
        end;
      end;
    KEY_DOT,
    KEY_GREATER:
      begin
        if register_begin(ANIMATION_REQUEST_RESERVED) = 0 then
        begin
          register_object_inc_rotation(obj_dude);
          register_end;
        end;
      end;
    KEY_SLASH,
    KEY_QUESTION:
      begin
        gsound_play_sfx_file('ib1p1xx1');

        game_time_date(@month, @day, @year);

        if message_init(@messageList) then
        begin
          StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'editor.msg']);

          if message_load(@messageList, @path[0]) then
          begin
            messageListItem.num := 500 + month - 1;
            if message_search(@messageList, @messageListItem) then
            begin
              timeStr := game_time_hour_str;
              StrLFmt(@dateStr[0], SizeOf(dateStr) - 1, '%s %d, %d %s', [messageListItem.text, day, year, timeStr]);
              display_print(@dateStr[0]);
            end;
          end;

          message_exit(@messageList);
        end;
      end;
    KEY_F1:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        game_help;
      end;
    KEY_F2:
      begin
        gsound_set_master_volume(gsound_get_master_volume - 2047);
      end;
    KEY_F3:
      begin
        gsound_set_master_volume(gsound_get_master_volume + 2047);
      end;
    KEY_CTRL_S,
    KEY_F4:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        if SaveGame(1) = -1 then
          debug_printf(#10' ** Error calling SaveGame()! **'#10, []);
      end;
    KEY_CTRL_L,
    KEY_F5:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        if LoadGame(LOAD_SAVE_MODE_NORMAL) = -1 then
          debug_printf(#10' ** Error calling LoadGame()! **'#10, []);
      end;
    KEY_F6:
      begin
        gsound_play_sfx_file('ib1p1xx1');

        rc := SaveGame(LOAD_SAVE_MODE_QUICK);
        if rc = -1 then
          debug_printf(#10' ** Error calling SaveGame()! **'#10, [])
        else if rc = 1 then
        begin
          // Quick save game successfully saved.
          msg := getmsg(@misc_message_file, @messageListItem, 5);
          display_print(msg);
        end;
      end;
    KEY_F7:
      begin
        gsound_play_sfx_file('ib1p1xx1');

        rc := LoadGame(LOAD_SAVE_MODE_QUICK);
        if rc = -1 then
          debug_printf(#10' ** Error calling LoadGame()! **'#10, [])
        else if rc = 1 then
        begin
          // Quick load game successfully loaded.
          msg := getmsg(@misc_message_file, @messageListItem, 4);
          display_print(msg);
        end;
      end;
    KEY_CTRL_V:
      begin
        gsound_play_sfx_file('ib1p1xx1');

        getverstr(@version[0], SizeOf(version));
        display_print(@version[0]);
        display_print(version_build_time_str);
      end;
    KEY_ARROW_LEFT:
      map_scroll(-1, 0);
    KEY_ARROW_RIGHT:
      map_scroll(1, 0);
    KEY_ARROW_UP:
      map_scroll(0, -1);
    KEY_ARROW_DOWN:
      map_scroll(0, 1);
  end;

  Result := 0;
end;

// 0x43C584
procedure game_ui_disable(a1: Integer);
begin
  if not game_ui_disabled then
  begin
    gmouse_3d_off;
    gmouse_disable(a1);
    kb_disable;
    intface_disable;
    game_ui_disabled := True;
  end;
end;

// 0x43C5B8
procedure game_ui_enable;
begin
  if game_ui_disabled then
  begin
    intface_enable;
    kb_enable;
    kb_clear;
    gmouse_enable;
    gmouse_3d_on;
    game_ui_disabled := False;
  end;
end;

// 0x43C5E0
function game_ui_is_disabled: Boolean;
begin
  Result := game_ui_disabled;
end;

// 0x43C5E8
function game_get_global_var(v: Integer): Integer;
begin
  if (v < 0) or (v >= num_game_global_vars) then
  begin
    debug_printf('ERROR: attempt to reference global var out of range: %d', [v]);
    Exit(0);
  end;

  Result := PInteger(PByte(game_global_vars) + v * SizeOf(Integer))^;
end;

// 0x43C618
function game_set_global_var(v: Integer; value: Integer): Integer;
begin
  if (v < 0) or (v >= num_game_global_vars) then
  begin
    debug_printf('ERROR: attempt to reference global var out of range: %d', [v]);
    Exit(-1);
  end;

  PInteger(PByte(game_global_vars) + v * SizeOf(Integer))^ := value;

  Result := 0;
end;

// 0x43C648
function game_load_info: Integer;
begin
  Result := game_load_info_vars('data\vault13.gam', 'GAME_GLOBAL_VARS:', @num_game_global_vars, PPInteger(@game_global_vars));
end;

// 0x43C668
function game_load_info_vars(const path: PAnsiChar; const section: PAnsiChar; variablesListLengthPtr: PInteger; variablesListPtr: PPInteger): Integer;
var
  stream: PDB_FILE;
  str: array[0..259] of AnsiChar;
  semicolon: PAnsiChar;
  equals: PAnsiChar;
  intVal, code: Integer;
  p: PAnsiChar;
begin
  inven_reset_dude;

  stream := db_fopen(path, 'rt');
  if stream = nil then
    Exit(-1);

  if variablesListLengthPtr^ <> 0 then
  begin
    mem_free(variablesListPtr^);
    variablesListPtr^ := nil;
    variablesListLengthPtr^ := 0;
  end;

  if section <> nil then
  begin
    while db_fgets(@str[0], 258, stream) <> nil do
    begin
      if StrLComp(@str[0], section, 16) = 0 then
        Break;
    end;
  end;

  while db_fgets(@str[0], 258, stream) <> nil do
  begin
    if str[0] = #10 then
      Continue;

    if (str[0] = '/') and (str[1] = '/') then
      Continue;

    // Find semicolon and truncate
    semicolon := StrScan(@str[0], ';');
    if semicolon <> nil then
      semicolon^ := #0;

    variablesListLengthPtr^ := variablesListLengthPtr^ + 1;
    variablesListPtr^ := PInteger(mem_realloc(variablesListPtr^, SizeOf(Integer) * variablesListLengthPtr^));

    if variablesListPtr^ = nil then
      Halt(1);

    // Find equals sign
    equals := StrScan(@str[0], '=');
    if equals <> nil then
    begin
      p := equals + 1;
      Val(StrPas(p), intVal, code);
      if code <> 0 then
        intVal := 0;
      PInteger(PByte(variablesListPtr^) + (variablesListLengthPtr^ - 1) * SizeOf(Integer))^ := intVal;
    end
    else
    begin
      PInteger(PByte(variablesListPtr^) + (variablesListLengthPtr^ - 1) * SizeOf(Integer))^ := 0;
    end;
  end;

  db_fclose(stream);

  Result := 0;
end;

// 0x43C7AC
function game_state: Integer;
begin
  Result := game_state_cur;
end;

// 0x43C7B4
function game_state_request(a1: Integer): Integer;
begin
  if a1 = Ord(GAME_STATE_0) then
    a1 := Ord(GAME_STATE_1)
  else if a1 = Ord(GAME_STATE_2) then
    a1 := Ord(GAME_STATE_3)
  else if a1 = Ord(GAME_STATE_4) then
    a1 := Ord(GAME_STATE_5);

  if (game_state_cur <> Ord(GAME_STATE_4)) or (a1 <> Ord(GAME_STATE_5)) then
  begin
    game_state_cur := a1;
    Exit(0);
  end;

  Result := -1;
end;

// 0x43C810
procedure game_state_update;
var
  v0: Integer;
begin
  v0 := game_state_cur;
  case game_state_cur of
    Ord(GAME_STATE_1):
      v0 := Ord(GAME_STATE_0);
    Ord(GAME_STATE_3):
      v0 := Ord(GAME_STATE_2);
    Ord(GAME_STATE_5):
      v0 := Ord(GAME_STATE_4);
  end;

  game_state_cur := v0;
end;

// 0x43D0AC
function game_screendump(width, height: Integer; buffer, pal: PByte): Integer; cdecl;
var
  messageListItem: TMessageListItem;
begin
  if default_screendump(width, height, buffer, pal) <> 0 then
  begin
    // Error saving screenshot.
    messageListItem.num := 8;
    if message_search(@misc_message_file, @messageListItem) then
      display_print(messageListItem.text);

    Exit(-1);
  end;

  // Saved screenshot.
  messageListItem.num := 3;
  if message_search(@misc_message_file, @messageListItem) then
    display_print(messageListItem.text);

  Result := 0;
end;

// 0x43D10C
procedure game_unload_info;
begin
  num_game_global_vars := 0;
  if game_global_vars <> nil then
  begin
    mem_free(game_global_vars);
    game_global_vars := nil;
  end;
end;

// 0x43D130
procedure game_help;
var
  isoWasEnabled: Boolean;
  colorCycleWasEnabled: Boolean;
  overlay: Integer;
  helpWindowX, helpWindowY: Integer;
  win: Integer;
  windowBuffer: PByte;
  backgroundFid: Integer;
  backgroundHandle: PCacheEntry;
  backgroundData: PByte;
begin
  isoWasEnabled := map_disable_bk_processes;
  gmouse_3d_off;

  gmouse_set_cursor(MOUSE_CURSOR_NONE);

  colorCycleWasEnabled := cycle_is_enabled;
  cycle_disable;

  // CE: Help screen uses separate color palette which is incompatible with
  // colors in other windows. Setup overlay to hide everything.
  overlay := win_add(0, 0, screenGetWidth, screenGetHeight, 0, WINDOW_HIDDEN or WINDOW_MOVE_ON_TOP);

  helpWindowX := (screenGetWidth - HELP_SCREEN_WIDTH) div 2;
  helpWindowY := (screenGetHeight - HELP_SCREEN_HEIGHT) div 2;
  win := win_add(helpWindowX, helpWindowY, HELP_SCREEN_WIDTH, HELP_SCREEN_HEIGHT, 0, WINDOW_HIDDEN or WINDOW_MOVE_ON_TOP);
  if win <> -1 then
  begin
    windowBuffer := win_get_buf(win);
    if windowBuffer <> nil then
    begin
      backgroundFid := art_id(OBJ_TYPE_INTERFACE, 297, 0, 0, 0);
      backgroundHandle := nil;
      backgroundData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundHandle);
      if backgroundData <> nil then
      begin
        palette_set_to(@black_palette[0]);
        buf_to_buf(backgroundData, HELP_SCREEN_WIDTH, HELP_SCREEN_HEIGHT, HELP_SCREEN_WIDTH, windowBuffer, HELP_SCREEN_WIDTH);
        art_ptr_unlock(backgroundHandle);
        loadColorTable('art\intrface\helpscrn.pal');
        palette_set_to(@cmap[0]);

        // CE: Fill overlay with darkest color in the palette. It might
        // not be completely black, but at least it's uniform.
        buf_fill(win_get_buf(overlay),
            screenGetWidth,
            screenGetHeight,
            screenGetWidth,
            intensityColorTable[colorTable[0]][0]);

        win_show(overlay);
        win_show(win);

        while (get_input = -1) and (game_user_wants_to_quit = 0) do
        begin
          sharedFpsLimiter.mark;
          renderPresent;
          sharedFpsLimiter.throttle;
        end;

        while mouse_get_buttons <> 0 do
        begin
          sharedFpsLimiter.mark;
          get_input;
          renderPresent;
          sharedFpsLimiter.throttle;
        end;

        palette_set_to(@black_palette[0]);
      end;
    end;

    win_delete(overlay);
    win_delete(win);
    loadColorTable('color.pal');
    palette_set_to(@cmap[0]);
  end;

  if colorCycleWasEnabled then
    cycle_enable;

  gmouse_3d_on;

  if isoWasEnabled then
    map_enable_bk_processes;
end;

// 0x43D274
function game_quit_with_confirm: Integer;
var
  isoWasEnabled: Boolean;
  gameMouseWasVisible: Boolean;
  cursorWasHidden: Boolean;
  oldCursor: Integer;
  rc: Integer;
  messageListItem: TMessageListItem;
begin
  isoWasEnabled := map_disable_bk_processes;

  if isoWasEnabled then
    gameMouseWasVisible := gmouse_3d_is_on
  else
    gameMouseWasVisible := False;

  if gameMouseWasVisible then
    gmouse_3d_off;

  cursorWasHidden := mouse_hidden;
  if cursorWasHidden then
    mouse_show;

  oldCursor := gmouse_get_cursor;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  // Are you sure you want to quit?
  messageListItem.num := 0;
  if message_search(@misc_message_file, @messageListItem) then
  begin
    rc := dialog_out(messageListItem.text, nil, 0, 169, 117, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_YES_NO);
    if rc <> 0 then
      game_user_wants_to_quit := 2;
  end
  else
    rc := -1;

  gmouse_set_cursor(oldCursor);

  if cursorWasHidden then
    mouse_hide;

  if gameMouseWasVisible then
    gmouse_3d_on;

  if isoWasEnabled then
    map_enable_bk_processes;

  Result := rc;
end;

// 0x43D348
function game_init_databases: Integer;
var
  hashing: Integer;
  main_file_name: PAnsiChar;
  patch_file_name: PAnsiChar;
begin
  hashing := 0;
  main_file_name := nil;
  patch_file_name := nil;

  if config_get_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_HASHING_KEY, @hashing) then
    db_enable_hash_table;

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_DAT_KEY, @main_file_name);
  if main_file_name^ = #0 then
    main_file_name := nil;

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @patch_file_name);
  if patch_file_name^ = #0 then
    patch_file_name := nil;

  master_db_handle := db_init(main_file_name, nil, patch_file_name, 1);
  if master_db_handle = INVALID_DATABASE_HANDLE then
  begin
    GNWSystemError('Could not find the master datafile. Please make sure the FALLOUT CD is in the drive and that you are running FALLOUT from the directory you installed it to.');
    Exit(-1);
  end;

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CRITTER_DAT_KEY, @main_file_name);
  if main_file_name^ = #0 then
    main_file_name := nil;

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CRITTER_PATCHES_KEY, @patch_file_name);
  if patch_file_name^ = #0 then
    patch_file_name := nil;

  critter_db_handle := db_init(main_file_name, nil, patch_file_name, 1);
  if critter_db_handle = INVALID_DATABASE_HANDLE then
  begin
    db_select(master_db_handle);
    GNWSystemError('Could not find the critter datafile. Please make sure the FALLOUT CD is in the drive and that you are running FALLOUT from the directory you installed it to.');
    Exit(-1);
  end;

  db_select(master_db_handle);

  Result := 0;
end;

// 0x43D53C
procedure game_splash_screen;
var
  splash: Integer;
  stream: PDB_FILE;
  index: Integer;
  filePath: array[0..63] of AnsiChar;
  pal: PByte;
  data: PByte;
  splashWindowX, splashWindowY: Integer;
begin
  splash := 0;
  config_get_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_SPLASH_KEY, @splash);

  stream := nil;
  index := 0;
  while index < SPLASH_COUNT do
  begin
    StrLFmt(@filePath[0], SizeOf(filePath) - 1, 'art\splash\splash%d.rix', [splash]);
    stream := db_fopen(@filePath[0], 'rb');
    if stream <> nil then
      Break;

    Inc(splash);

    if splash >= SPLASH_COUNT then
      splash := 0;

    Inc(index);
  end;

  if stream = nil then
    Exit;

  pal := PByte(mem_malloc(768));
  if pal = nil then
  begin
    db_fclose(stream);
    Exit;
  end;

  data := PByte(mem_malloc(SPLASH_WIDTH * SPLASH_HEIGHT));
  if data = nil then
  begin
    mem_free(pal);
    db_fclose(stream);
    Exit;
  end;

  palette_set_to(@black_palette[0]);
  db_fseek(stream, 10, 0); // SEEK_SET = 0
  db_fread(pal, 1, 768, stream);
  db_fread(data, 1, SPLASH_WIDTH * SPLASH_HEIGHT, stream);
  db_fclose(stream);

  splashWindowX := (screenGetWidth - SPLASH_WIDTH) div 2;
  splashWindowY := (screenGetHeight - SPLASH_HEIGHT) div 2;
  scr_blit(data, SPLASH_WIDTH, SPLASH_HEIGHT, 0, 0, SPLASH_WIDTH, SPLASH_HEIGHT, LongWord(splashWindowX), LongWord(splashWindowY));
  palette_fade_to(pal);

  mem_free(data);
  mem_free(pal);

  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_SPLASH_KEY, splash + 1);
end;

initialization
  game_global_vars := nil;
  num_game_global_vars := 0;
  msg_path := 'game\';
  game_user_wants_to_quit := 0;
  version_build_time_str := VERSION_BUILD_TIME;

end.
