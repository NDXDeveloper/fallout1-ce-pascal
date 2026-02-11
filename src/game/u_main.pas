unit u_main;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/main.h + main.cc
// Main game loop: initialization, menu dispatch, death scene, selfrun.

interface

var
  main_game_paused: Integer;

function gnw_main(argc: Integer; argv: PPAnsiChar): Integer;

implementation

uses
  SysUtils,
  u_cache,
  u_object_types,
  u_selfrun,
  u_mainmenu,
  u_gmovie,
  u_gconfig,
  u_config,
  u_palette,
  u_color,
  u_art,
  u_roll,
  u_map,
  u_scripts,
  u_gnw,
  u_gnw_types,
  u_grbuf,
  u_input,
  u_plib_intrface,
  u_kb,
  u_mouse,
  u_svga,
  u_fps_limiter,
  u_object,
  u_credits,
  u_loadsave,
  u_debug,
  u_sdl2,
  u_amutex,
  u_game,
  u_gsound,
  u_gmouse,
  u_select,
  u_cycle,
  u_proto,
  u_worldmap,
  u_db;

const
  DEATH_WINDOW_WIDTH  = 640;
  DEATH_WINDOW_HEIGHT = 480;

  MOUSE_CURSOR_NONE  = 0;
  MOUSE_CURSOR_ARROW = 1;

// Module-level (static) variables
var
  mainMap: array[0..10] of AnsiChar = 'V13Ent.map';
  main_selfrun_list: PPAnsiChar = nil;
  main_selfrun_count: Integer = 0;
  main_selfrun_index: Integer = 0;
  main_show_death_scene: Boolean = False;
  main_death_voiceover_done: Boolean = False;

  // Static local variable for main_selfrun_play
  selfrun_play_toggle: Boolean = False;

// Forward declarations
function main_init_system(argc: Integer; argv: PPAnsiChar): Boolean; forward;
function main_reset_system: Integer; forward;
procedure main_exit_system; forward;
function main_load_new(mapFileName: PAnsiChar): Integer; forward;
function main_loadgame_new: Integer; forward;
procedure main_unload_new; forward;
procedure main_game_loop; forward;
function main_selfrun_init: Boolean; forward;
procedure main_selfrun_exit; forward;
procedure main_selfrun_record; forward;
procedure main_selfrun_play; forward;
procedure main_death_scene; forward;
procedure main_death_voiceover_callback; cdecl; forward;

// 0x4725E8
function gnw_main(argc: Integer; argv: PPAnsiChar): Integer;
var
  language_filter: Integer;
  done: Boolean;
  mainMenuRc: Integer;
  win: Integer;
  loadGameRc: Integer;
begin
  WriteLn(StdErr, '[MAIN] gnw_main: start');
  if not autorun_mutex_create then
  begin
    WriteLn(StdErr, '[MAIN] autorun_mutex_create FAILED');
    Result := 1;
    Exit;
  end;
  WriteLn(StdErr, '[MAIN] autorun_mutex_create OK');

  if not main_init_system(argc, argv) then
  begin
    WriteLn(StdErr, '[MAIN] main_init_system FAILED');
    Result := 1;
    Exit;
  end;
  WriteLn(StdErr, '[MAIN] main_init_system OK');

  gmovie_play(MOVIE_IPLOGO, GAME_MOVIE_FADE_IN);
  WriteLn(StdErr, '[MAIN] IPLOGO movie done');
  gmovie_play(MOVIE_INTRO, 0);
  WriteLn(StdErr, '[MAIN] INTRO movie done');

  if main_menu_create = 0 then
  begin
    language_filter := 1;
    done := False;

    config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, @language_filter);

    while not done do
    begin
      kb_clear;
      gsound_background_play_level_music('07desert', 11);
      main_menu_show(True);

      mouse_show;
      mainMenuRc := main_menu_loop;
      mouse_hide;

      case mainMenuRc of
        MAIN_MENU_INTRO:
        begin
          main_menu_hide(True);
          gmovie_play(MOVIE_INTRO, GAME_MOVIE_PAUSE_MUSIC);
        end;

        MAIN_MENU_NEW_GAME:
        begin
          main_menu_hide(True);
          main_menu_destroy;
          if select_character = 2 then
          begin
            gmovie_play(MOVIE_OVRINTRO, GAME_MOVIE_STOP_MUSIC);
            roll_set_seed(-1);
            main_load_new(@mainMap[0]);
            main_game_loop;
            palette_fade_to(@white_palette[0]);

            // NOTE: Uninline.
            main_unload_new;

            // NOTE: Uninline.
            main_reset_system;

            if main_show_death_scene then
            begin
              main_death_scene;
              main_show_death_scene := False;
            end;
          end;

          main_menu_create;
        end;

        MAIN_MENU_LOAD_GAME:
        begin
          win := win_add(0, 0, screenGetWidth, screenGetHeight, colorTable[0], WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
          main_menu_hide(True);
          main_menu_destroy;
          gsound_background_stop;

          // NOTE: Uninline.
          main_loadgame_new;

          loadColorTable('color.pal');
          palette_fade_to(@cmap[0]);
          loadGameRc := LoadGame(LOAD_SAVE_MODE_FROM_MAIN_MENU);
          if loadGameRc = -1 then
          begin
            debug_printf(#10' ** Error running LoadGame()! **'#10);
          end
          else if loadGameRc <> 0 then
          begin
            win_delete(win);
            win := -1;
            main_game_loop;
          end;
          palette_fade_to(@white_palette[0]);
          if win <> -1 then
            win_delete(win);

          // NOTE: Uninline.
          main_unload_new;

          // NOTE: Uninline.
          main_reset_system;

          if main_show_death_scene then
          begin
            main_death_scene;
            main_show_death_scene := False;
          end;
          main_menu_create;
        end;

        MAIN_MENU_TIMEOUT:
        begin
          debug_printf('Main menu timed-out'#10);
          // FALLTHROUGH to MAIN_MENU_SCREENSAVER
          main_selfrun_play;
        end;

        MAIN_MENU_SCREENSAVER:
        begin
          main_selfrun_play;
        end;

        MAIN_MENU_CREDITS:
        begin
          main_menu_hide(True);
          credits('credits.txt', -1, False);
        end;

        MAIN_MENU_QUOTES:
        begin
          if language_filter = 0 then
          begin
            main_menu_hide(True);
            credits('quotes.txt', -1, True);
          end;
        end;

        MAIN_MENU_EXIT, -1:
        begin
          done := True;
          main_menu_hide(True);
          main_menu_destroy;
          gsound_background_stop;
        end;

        MAIN_MENU_SELFRUN:
        begin
          main_selfrun_record;
        end;
      end; // case
    end; // while
  end;

  // NOTE: Uninline.
  main_exit_system;

  autorun_mutex_destroy;

  Result := 0;
end;

// 0x4728CC
function main_init_system(argc: Integer; argv: PPAnsiChar): Boolean;
begin
  if game_init('FALLOUT', False, 0, 0, argc, argv) = -1 then
  begin
    Result := False;
    Exit;
  end;

  // NOTE: Uninline.
  main_selfrun_init;

  Result := True;
end;

// 0x472918
function main_reset_system: Integer;
begin
  game_reset;
  Result := 1;
end;

// 0x472924
procedure main_exit_system;
begin
  gsound_background_stop;

  // NOTE: Uninline.
  main_selfrun_exit;

  game_exit;

  // TODO: Find a better place for this call.
  SDL_Quit;
end;

// 0x472958
function main_load_new(mapFileName: PAnsiChar): Integer;
var
  win: Integer;
begin
  WriteLn('[MAIN] main_load_new called with map: ', mapFileName);
  game_user_wants_to_quit := 0;
  main_show_death_scene := False;
  obj_dude^.flags := obj_dude^.flags and (not OBJECT_FLAT);
  WriteLn('[MAIN] Calling obj_turn_on for obj_dude...');
  obj_turn_on(obj_dude, nil);
  mouse_hide;

  win := win_add(0, 0, screenGetWidth, screenGetHeight, colorTable[0], WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  win_draw(win);

  loadColorTable('color.pal');
  palette_fade_to(@cmap[0]);
  map_init;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);
  mouse_show;
  map_load(mapFileName);
  PlayCityMapMusic;
  palette_fade_to(@white_palette[0]);
  win_delete(win);
  loadColorTable('color.pal');
  palette_fade_to(@cmap[0]);
  Result := 0;
end;

// 0x472A04
function main_loadgame_new: Integer;
begin
  game_user_wants_to_quit := 0;
  main_show_death_scene := False;

  obj_dude^.flags := obj_dude^.flags and (not OBJECT_FLAT);

  obj_turn_on(obj_dude, nil);
  mouse_hide;

  map_init;

  gmouse_set_cursor(MOUSE_CURSOR_NONE);
  mouse_show;

  Result := 0;
end;

// 0x472A40
procedure main_unload_new;
begin
  obj_turn_off(obj_dude, nil);
  map_exit;
end;

// 0x472A54
procedure main_game_loop;
var
  cursorWasHidden: Boolean;
  keyCode: Integer;
begin
  cursorWasHidden := mouse_hidden;
  if cursorWasHidden then
    mouse_show;

  main_game_paused := 0;

  scr_enable;

  while game_user_wants_to_quit = 0 do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;
    game_handle_input(keyCode, False);

    scripts_check_state;

    map_check_state;

    if main_game_paused <> 0 then
      main_game_paused := 0;

    if (obj_dude^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
    begin
      main_show_death_scene := True;
      game_user_wants_to_quit := 2;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  scr_disable;

  if cursorWasHidden then
    mouse_hide;
end;

// 0x472AE8
function main_selfrun_init: Boolean;
begin
  if main_selfrun_list <> nil then
  begin
    // NOTE: Uninline.
    main_selfrun_exit;
  end;

  if selfrun_get_list(@main_selfrun_list, @main_selfrun_count) <> 0 then
  begin
    Result := False;
    Exit;
  end;

  main_selfrun_index := 0;

  Result := True;
end;

// 0x472B3C
procedure main_selfrun_exit;
begin
  if main_selfrun_list <> nil then
    selfrun_free_list(@main_selfrun_list);

  main_selfrun_count := 0;
  main_selfrun_index := 0;
  main_selfrun_list := nil;
end;

// 0x472B68
procedure main_selfrun_record;
var
  selfrunData: TSelfrunData;
  ready: Boolean;
  fileList: PPAnsiChar;
  fileListLength: Integer;
  selectedFileIndex: Integer;
  recordingName: array[0..SELFRUN_RECORDING_FILE_NAME_LENGTH - 1] of AnsiChar;
  fileListPAnsiChar: PPAnsiChar;
begin
  ready := False;
  fileList := nil;

  fileListLength := db_get_file_list('maps\*.map', @fileList, nil, 0);
  if fileListLength <> 0 then
  begin
    selectedFileIndex := win_list_select('Select Map', fileList, fileListLength, nil, 80, 80, $10000 or $100 or 4);
    if selectedFileIndex <> -1 then
    begin
      recordingName[0] := #0;
      if win_get_str(@recordingName[0], SizeOf(recordingName) - 2, 'Enter name for recording (8 characters max, no extension):', 100, 100) = 0 then
      begin
        FillChar(selfrunData, SizeOf(selfrunData), 0);
        // Get pointer to the selected entry: fileList is PPAnsiChar, index into it
        fileListPAnsiChar := fileList;
        Inc(fileListPAnsiChar, selectedFileIndex);
        if selfrun_prep_recording(@recordingName[0], fileListPAnsiChar^, @selfrunData) = 0 then
          ready := True;
      end;
    end;
    db_free_file_list(@fileList, nil);
  end;

  if ready then
  begin
    main_menu_hide(True);
    main_menu_destroy;
    gsound_background_stop;
    roll_set_seed(Integer($BEEFFEED));

    // NOTE: Uninline.
    main_reset_system;

    proto_dude_init('premade\combat.gcd');
    main_load_new(@selfrunData.mapFileName[0]);
    selfrun_recording_loop(@selfrunData);
    palette_fade_to(@white_palette[0]);

    // NOTE: Uninline.
    main_unload_new;

    // NOTE: Uninline.
    main_reset_system;

    main_menu_create;

    // NOTE: Uninline.
    main_selfrun_init;
  end;
end;

// 0x472CA0
procedure main_selfrun_play;
var
  selfrunData: TSelfrunData;
  entryPtr: PPAnsiChar;
begin
  if (not selfrun_play_toggle) and (main_selfrun_count > 0) then
  begin
    entryPtr := main_selfrun_list;
    Inc(entryPtr, main_selfrun_index);
    if selfrun_prep_playback(entryPtr^, @selfrunData) = 0 then
    begin
      main_menu_hide(True);
      main_menu_destroy;
      gsound_background_stop;
      roll_set_seed(Integer($BEEFFEED));

      // NOTE: Uninline.
      main_reset_system;

      proto_dude_init('premade\combat.gcd');
      main_load_new(@selfrunData.mapFileName[0]);
      selfrun_playback_loop(@selfrunData);
      palette_fade_to(@white_palette[0]);

      // NOTE: Uninline.
      main_unload_new;

      // NOTE: Uninline.
      main_reset_system;

      main_menu_create;
    end;

    Inc(main_selfrun_index);
    if main_selfrun_index >= main_selfrun_count then
      main_selfrun_index := 0;
  end
  else
  begin
    main_menu_hide(True);
    gmovie_play(MOVIE_INTRO, GAME_MOVIE_PAUSE_MUSIC);
  end;

  if selfrun_play_toggle then
    selfrun_play_toggle := False
  else
    selfrun_play_toggle := True;
end;

// 0x472D90
procedure main_death_scene;
const
  deathFileNameList: array[0..3] of PAnsiChar = (
    'narrator\nar_3',
    'narrator\nar_4',
    'narrator\nar_5',
    'narrator\nar_6'
  );
var
  oldCursorIsHidden: Boolean;
  deathWindowX, deathWindowY: Integer;
  win: Integer;
  windowBuffer: PByte;
  backgroundHandle: PCacheEntry;
  fid: Integer;
  background: PByte;
  deathFileNameIndex: Integer;
  delay: LongWord;
  time_: LongWord;
  keyCode: Integer;
begin
  art_flush;
  cycle_disable;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);

  oldCursorIsHidden := mouse_hidden;
  if oldCursorIsHidden then
    mouse_show;

  deathWindowX := (screenGetWidth - DEATH_WINDOW_WIDTH) div 2;
  deathWindowY := (screenGetHeight - DEATH_WINDOW_HEIGHT) div 2;
  win := win_add(deathWindowX, deathWindowY,
    DEATH_WINDOW_WIDTH, DEATH_WINDOW_HEIGHT,
    0, WINDOW_MOVE_ON_TOP);
  if win <> -1 then
  begin
    windowBuffer := win_get_buf(win);
    if windowBuffer <> nil then
    begin
      // DEATH.FRM
      fid := art_id(OBJ_TYPE_INTERFACE, 309, 0, 0, 0);
      background := art_ptr_lock_data(fid, 0, 0, @backgroundHandle);
      if background <> nil then
      begin
        while mouse_get_buttons <> 0 do
        begin
          sharedFpsLimiter.Mark;
          get_input;
          renderPresent;
          sharedFpsLimiter.Throttle;
        end;

        kb_clear;
        flush_input_buffer;

        buf_to_buf(background,
          DEATH_WINDOW_WIDTH,
          DEATH_WINDOW_HEIGHT,
          DEATH_WINDOW_WIDTH,
          windowBuffer,
          DEATH_WINDOW_WIDTH);
        art_ptr_unlock(backgroundHandle);

        win_draw(win);

        loadColorTable('art\intrface\death.pal');
        palette_fade_to(@cmap[0]);

        deathFileNameIndex := roll_random(1, Length(deathFileNameList)) - 1;

        main_death_voiceover_done := False;
        gsound_speech_callback_set(@main_death_voiceover_callback);

        if gsound_speech_play(deathFileNameList[deathFileNameIndex], 10, 14, 15) = -1 then
          delay := 3000
        else
          delay := $FFFFFFFF;

        gsound_speech_play_preloaded;

        time_ := get_time;
        keyCode := -1;
        while elapsed_time(time_) < delay do
        begin
          sharedFpsLimiter.Mark;

          keyCode := get_input;
          if keyCode <> -1 then
            Break;

          if main_death_voiceover_done then
            Break;

          renderPresent;
          sharedFpsLimiter.Throttle;
        end;

        gsound_speech_callback_set(nil);

        gsound_speech_stop;

        while mouse_get_buttons <> 0 do
        begin
          sharedFpsLimiter.Mark;
          get_input;
          renderPresent;
          sharedFpsLimiter.Throttle;
        end;

        if keyCode = -1 then
          pause_for_tocks(500);

        palette_fade_to(@black_palette[0]);
        loadColorTable('color.pal');
      end;
    end;

    win_delete(win);
  end;

  if oldCursorIsHidden then
    mouse_hide;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  cycle_enable;
end;

// 0x472F68
procedure main_death_voiceover_callback; cdecl;
begin
  main_death_voiceover_done := True;
end;

end.
