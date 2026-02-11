{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/endgame.h + endgame.cc
// Endgame slideshow and movie sequences.
unit u_endgame;

interface

procedure endgame_slideshow;
procedure endgame_movie;

implementation

uses
  SysUtils, Math,
  u_cache, u_art, u_object_types, u_proto_types, u_stat_defs,
  u_game_vars, u_gconfig, u_config, u_palette, u_color,
  u_platform_compat, u_grbuf, u_gnw, u_input, u_mouse, u_text,
  u_svga, u_fps_limiter, u_memory, u_db, u_debug, u_wordwrap,
  u_gmovie, u_credits,
  u_gsound, u_int_sound, u_game, u_stat, u_map, u_cycle, u_gmouse,
  u_object;

const
  ENDGAME_ENDING_MAX_SUBTITLES    = 50;
  ENDGAME_ENDING_WINDOW_WIDTH     = 640;
  ENDGAME_ENDING_WINDOW_HEIGHT    = 480;

  WINDOW_MOVE_ON_TOP = $04;
  WINDOW_MODAL       = $10;

  MOUSE_CURSOR_NONE  = 0;
  MOUSE_CURSOR_ARROW = 1;

  GENDER_MALE = 0;

// ---------------------------------------------------------------------------
// Static (module-level) variables
// ---------------------------------------------------------------------------
var
  endgame_subtitle_count: Integer = 0;
  endgame_subtitle_characters: Integer = 0;
  endgame_current_subtitle: Integer = 0;
  endgame_maybe_done: Integer = 0;

  endgame_voiceover_loaded: Boolean;
  endgame_subtitle_path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  endgame_voiceover_done: Boolean;
  endgame_subtitle_text: PPAnsiChar;
  endgame_do_subtitles: Boolean;
  endgame_subtitle_done: Boolean;
  endgame_map_enabled: Boolean;
  endgame_mouse_state: Boolean;
  endgame_subtitle_loaded: Boolean;
  endgame_subtitle_start_time: LongWord;
  endgame_window_buffer: PByte;
  endgame_subtitle_times: PLongWord;
  endgame_window: Integer;
  endgame_old_font: Integer;
  gEndgameEndingOverlay: Integer;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
procedure endgame_pan_desert(direction: Integer; const narratorFileName: PAnsiChar); forward;
procedure endgame_display_image(fid: Integer; const narratorFileName: PAnsiChar); forward;
function endgame_init: Integer; forward;
procedure endgame_exit; forward;
procedure endgame_load_voiceover(const fileBaseName: PAnsiChar); forward;
procedure endgame_play_voiceover; forward;
procedure endgame_stop_voiceover; forward;
procedure endgame_load_palette(atype, id: Integer); forward;
procedure endgame_voiceover_callback; cdecl; forward;
function endgame_load_subtitles(const filePath: PAnsiChar): Integer; forward;
procedure endgame_show_subtitles; forward;
procedure endgame_clear_subtitles; forward;
procedure endgame_movie_callback; cdecl; forward;
procedure endgame_movie_bk_process; cdecl; forward;
procedure endgameEndingUpdateOverlay; forward;

// ---------------------------------------------------------------------------
// endgame_slideshow
// ---------------------------------------------------------------------------
procedure endgame_slideshow;
var
  fid: Integer;
  v1: Integer;
begin
  if endgame_init <> -1 then
  begin
    if game_get_global_var(Ord(GVAR_VATS_STATUS)) <> 0 then
      endgame_pan_desert(1, 'nar_11')
    else
      endgame_pan_desert(1, 'nar_10');

    if game_get_global_var(Ord(GVAR_NECROPOLIS_INVADED)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 311, 0, 0, 0);
      endgame_display_image(fid, 'nar_15');
    end
    else if game_get_global_var(Ord(GVAR_NECROP_WATER_CHIP_TAKEN)) <> 0 then
    begin
      if game_get_global_var(Ord(GVAR_NECROP_WATER_PUMP_FIXED)) = 2 then
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 312, 0, 0, 0);
        endgame_display_image(fid, 'nar_13');
      end
      else
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 311, 0, 0, 0);
        endgame_display_image(fid, 'nar_12');
      end;
    end;

    if game_get_global_var(Ord(GVAR_FOLLOWERS_INVADED)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 314, 0, 0, 0);
      endgame_display_image(fid, 'nar_18');
    end
    else if game_get_global_var(Ord(GVAR_TRAIN_FOLLOWERS)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 313, 0, 0, 0);
      endgame_display_image(fid, 'nar_16');
    end;

    if game_get_global_var(Ord(GVAR_SHADY_SANDS_INVADED)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 324, 0, 0, 0);
      endgame_display_image(fid, 'nar_23');
    end
    else
    begin
      v1 := game_get_global_var(Ord(GVAR_TANDI_STATUS));
      if game_get_global_var(Ord(GVAR_ARADESH_STATUS)) <> 0 then
      begin
        if (v1 <> 2) and (v1 <> 0) then
        begin
          fid := art_id(OBJ_TYPE_INTERFACE, 324, 0, 0, 0);
          endgame_display_image(fid, 'nar_22');
        end
        else
        begin
          fid := art_id(OBJ_TYPE_INTERFACE, 323, 0, 0, 0);
          endgame_display_image(fid, 'nar_21');
        end;
      end
      else
      begin
        if (v1 <> 2) and (v1 <> 0) then
        begin
          fid := art_id(OBJ_TYPE_INTERFACE, 323, 0, 0, 0);
          endgame_display_image(fid, 'nar_20');
        end
        else
        begin
          fid := art_id(OBJ_TYPE_INTERFACE, 323, 0, 0, 0);
          endgame_display_image(fid, 'nar_19');
        end;
      end;
    end;

    if game_get_global_var(Ord(GVAR_JUNKTOWN_INVADED)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 317, 0, 0, 0);
      endgame_display_image(fid, 'nar_27');
    end
    else if (game_get_global_var(Ord(GVAR_CAPTURE_GIZMO)) <> 2) or
            (game_get_global_var(Ord(GVAR_KILLIAN_DEAD)) <> 0) then
    begin
      if game_get_global_var(Ord(GVAR_GIZMO_DEAD)) = 0 then
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 316, 0, 0, 0);
        endgame_display_image(fid, 'nar_25');
      end;
    end
    else
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 315, 0, 0, 0);
      endgame_display_image(fid, 'nar_24');
    end;

    if (game_get_global_var(Ord(GVAR_BECOME_AN_INITIATE)) = 2) and
       (game_get_global_var(Ord(GVAR_ENEMY_BROTHERHOOD)) <> 0) then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 319, 0, 0, 0);
      endgame_display_image(fid, 'nar_29');
    end
    else
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 318, 0, 0, 0);
      endgame_display_image(fid, 'nar_28');
    end;

    if game_get_global_var(Ord(GVAR_HUB_INVADED)) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 326, 0, 0, 0);
      endgame_display_image(fid, 'nar_34');
    end
    else if game_get_global_var(Ord(GVAR_KIND_TO_HAROLD)) = 1 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 325, 0, 0, 0);
      endgame_display_image(fid, 'nar_32');
    end;

    if game_get_global_var(Ord(GVAR_RAIDERS)) < 2 then
    begin
      fid := art_id(OBJ_TYPE_INTERFACE, 320, 0, 0, 0);
      endgame_display_image(fid, 'nar_37');
    end
    else
    begin
      v1 := game_get_global_var(Ord(GVAR_TOTAL_RAIDERS));
      if ((game_get_global_var(Ord(GVAR_GARL_DEAD)) <> 0) and (v1 < 8)) or (v1 < 4) then
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 320, 0, 0, 0);
        endgame_display_image(fid, 'nar_35');
      end
      else
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 320, 0, 0, 0);
        endgame_display_image(fid, 'nar_36');
      end;
    end;

    endgame_pan_desert(-1, 'nar_40');

    endgame_exit;
  end;

  game_set_global_var(Ord(GVAR_CALM_REBELS_2), 0);
end;

// ---------------------------------------------------------------------------
// endgame_movie
// ---------------------------------------------------------------------------
procedure endgame_movie;
begin
  gsound_background_stop;
  map_disable_bk_processes;
  palette_fade_to(@black_palette[0]);
  endgame_maybe_done := 0;
  add_bk_process(@endgame_movie_bk_process);
  gsound_background_callback_set(@endgame_movie_callback);
  gsound_background_play('maybe', 12, 14, 15);
  pause_for_tocks(3000);

  // NOTE: Result is ignored. Male vs female ending.
  if stat_level(obj_dude, Ord(STAT_GENDER)) = GENDER_MALE then
    gmovie_play(MOVIE_WALKM, 0)
  else
    gmovie_play(MOVIE_WALKW, 0);

  credits('credits.txt', -1, False);
  gsound_background_stop;
  gsound_background_callback_set(nil);
  remove_bk_process(@endgame_movie_bk_process);
  gsound_background_stop;
  game_user_wants_to_quit := 2;
end;

// ---------------------------------------------------------------------------
// endgame_init
// ---------------------------------------------------------------------------
function endgame_init: Integer;
var
  oldCursorIsHidden: Boolean;
  windowEndgameEndingX: Integer;
  windowEndgameEndingY: Integer;
  language: PAnsiChar;
  index: Integer;
begin
  gsound_background_stop;

  endgame_map_enabled := map_disable_bk_processes;

  cycle_disable;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);

  oldCursorIsHidden := mouse_hidden;
  endgame_mouse_state := not oldCursorIsHidden;

  if oldCursorIsHidden then
    mouse_show;

  endgame_old_font := text_curr;
  text_font(101);

  palette_fade_to(@black_palette[0]);

  // CE: Setup overlay to hide everything.
  gEndgameEndingOverlay := win_add(0, 0, screenGetWidth, screenGetHeight,
    colorTable[0], WINDOW_MOVE_ON_TOP);
  if gEndgameEndingOverlay = -1 then
    Exit(-1);

  windowEndgameEndingX := (screenGetWidth - ENDGAME_ENDING_WINDOW_WIDTH) div 2;
  windowEndgameEndingY := (screenGetHeight - ENDGAME_ENDING_WINDOW_HEIGHT) div 2;
  endgame_window := win_add(windowEndgameEndingX,
    windowEndgameEndingY,
    ENDGAME_ENDING_WINDOW_WIDTH,
    ENDGAME_ENDING_WINDOW_HEIGHT,
    colorTable[0],
    WINDOW_MOVE_ON_TOP);
  if endgame_window = -1 then
    Exit(-1);

  endgame_window_buffer := win_get_buf(endgame_window);
  if endgame_window_buffer = nil then
    Exit(-1);

  cycle_disable;

  gsound_speech_callback_set(@endgame_voiceover_callback);

  endgame_do_subtitles := False;
  configGetBool(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_SUBTITLES_KEY, @endgame_do_subtitles);
  if not endgame_do_subtitles then
    Exit(0);

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_LANGUAGE_KEY, @language) then
  begin
    endgame_do_subtitles := False;
    Exit(0);
  end;

  StrLFmt(@endgame_subtitle_path[0], SizeOf(endgame_subtitle_path), 'text\%s\cuts\', [language]);

  endgame_subtitle_text := PPAnsiChar(mem_malloc(SizeOf(PAnsiChar) * ENDGAME_ENDING_MAX_SUBTITLES));
  if endgame_subtitle_text = nil then
  begin
    endgame_do_subtitles := False;
    Exit(0);
  end;

  for index := 0 to ENDGAME_ENDING_MAX_SUBTITLES - 1 do
    endgame_subtitle_text[index] := nil;

  endgame_subtitle_times := PLongWord(mem_malloc(SizeOf(LongWord) * ENDGAME_ENDING_MAX_SUBTITLES));
  if endgame_subtitle_times = nil then
  begin
    mem_free(endgame_subtitle_text);
    endgame_do_subtitles := False;
    Exit(0);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// endgame_exit
// ---------------------------------------------------------------------------
procedure endgame_exit;
begin
  if endgame_do_subtitles then
  begin
    endgame_clear_subtitles;

    mem_free(endgame_subtitle_times);
    mem_free(endgame_subtitle_text);

    endgame_subtitle_text := nil;
    endgame_do_subtitles := False;
  end;

  text_font(endgame_old_font);

  gsound_speech_callback_set(nil);
  win_delete(endgame_window);
  win_delete(gEndgameEndingOverlay);

  if not endgame_mouse_state then
    mouse_hide;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  loadColorTable('color.pal');
  palette_fade_to(@cmap[0]);

  cycle_enable;

  if endgame_map_enabled then
    map_enable_bk_processes;
end;

// ---------------------------------------------------------------------------
// endgame_pan_desert
// ---------------------------------------------------------------------------
procedure endgame_pan_desert(direction: Integer; const narratorFileName: PAnsiChar);
var
  fid: Integer;
  backgroundHandle: PCacheEntry;
  background: PArt;
  width: Integer;
  backgroundData: PByte;
  palette: array[0..767] of Byte;
  v8, v32: Integer;
  v9: LongWord;
  v9_: LongWord;
  v10: LongWord;
  start_, end_: Integer;
  subtitlesLoaded: Boolean;
  since: LongWord;
  v12: Integer;
  v14: Boolean;
  v31: Double;
  v28: Integer;
  darkenedPalette: array[0..767] of Byte;
  idx: Integer;
begin
  fid := art_id(OBJ_TYPE_INTERFACE, 327, 0, 0, 0);

  backgroundHandle := nil;
  background := art_ptr_lock(fid, @backgroundHandle);
  if background <> nil then
  begin
    width := art_frame_width(background, 0, 0);
    art_frame_length(background, 0, 0); // height not used, but called for parity with C++
    backgroundData := art_frame_data(background, 0, 0);
    buf_fill(endgame_window_buffer, ENDGAME_ENDING_WINDOW_WIDTH,
      ENDGAME_ENDING_WINDOW_HEIGHT, ENDGAME_ENDING_WINDOW_WIDTH, colorTable[0]);
    endgame_load_palette(6, 327);

    // CE: Update overlay.
    endgameEndingUpdateOverlay;

    Move(cmap, palette, 768);

    palette_set_to(@black_palette[0]);
    endgame_load_voiceover(narratorFileName);

    // TODO: Unclear math.
    v8 := width - 640;
    v32 := v8 div 4;
    v9 := 16 * LongWord(v8) div LongWord(v8);
    v9_ := 16 * LongWord(v8);

    if endgame_voiceover_loaded then
    begin
      v10 := 1000 * LongWord(gsound_speech_length_get);
      if v10 > v9_ div 2 then
        v9 := (v10 + v9 * LongWord(v8 div 2)) div LongWord(v8);
    end;

    if direction = -1 then
    begin
      start_ := width - 640;
      end_ := 0;
    end
    else
    begin
      start_ := 0;
      end_ := width - 640;
    end;

    disable_bk;

    subtitlesLoaded := False;

    since := 0;
    while start_ <> end_ do
    begin
      sharedFpsLimiter.Mark;

      v12 := 640 - v32;

      if elapsed_time(since) >= v9 then
      begin
        buf_to_buf(backgroundData + start_, ENDGAME_ENDING_WINDOW_WIDTH,
          ENDGAME_ENDING_WINDOW_HEIGHT, width, endgame_window_buffer,
          ENDGAME_ENDING_WINDOW_WIDTH);

        if subtitlesLoaded then
          endgame_show_subtitles;

        win_draw(endgame_window);

        since := get_time;

        v14 := False;
        v31 := 0.0;
        if start_ > v32 then
        begin
          if v12 > start_ then
            v14 := False
          else
          begin
            v28 := v32 - (start_ - v12);
            v31 := v28 / v32;
            v14 := True;
          end;
        end
        else
        begin
          v14 := True;
          v31 := start_ / v32;
        end;

        if v14 then
        begin
          for idx := 0 to 767 do
            darkenedPalette[idx] := Byte(Trunc(palette[idx] * v31));
          palette_set_to(@darkenedPalette[0]);
        end;

        start_ := start_ + direction;

        if (direction = 1) and (start_ = v32) then
        begin
          endgame_play_voiceover;
          subtitlesLoaded := True;
        end
        else if (direction = -1) and (start_ = v12) then
        begin
          endgame_play_voiceover;
          subtitlesLoaded := True;
        end;
      end;

      soundUpdate;

      if get_input <> -1 then
      begin
        endgame_stop_voiceover;
        Break;
      end;

      renderPresent;
      sharedFpsLimiter.Throttle;
    end;

    enable_bk;
    art_ptr_unlock(backgroundHandle);

    palette_fade_to(@black_palette[0]);
    buf_fill(endgame_window_buffer, ENDGAME_ENDING_WINDOW_WIDTH,
      ENDGAME_ENDING_WINDOW_HEIGHT, ENDGAME_ENDING_WINDOW_WIDTH, colorTable[0]);
    win_draw(endgame_window);
  end;

  while mouse_get_buttons <> 0 do
  begin
    sharedFpsLimiter.Mark;

    get_input;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;
end;

// ---------------------------------------------------------------------------
// endgame_display_image
// ---------------------------------------------------------------------------
procedure endgame_display_image(fid: Integer; const narratorFileName: PAnsiChar);
var
  backgroundHandle: PCacheEntry;
  background: PArt;
  backgroundData: PByte;
  delay: LongWord;
  referenceTime: LongWord;
  keyCode: Integer;
begin
  backgroundHandle := nil;
  background := art_ptr_lock(fid, @backgroundHandle);
  if background = nil then
    Exit;

  backgroundData := art_frame_data(background, 0, 0);
  if backgroundData <> nil then
  begin
    buf_to_buf(backgroundData, ENDGAME_ENDING_WINDOW_WIDTH,
      ENDGAME_ENDING_WINDOW_HEIGHT, ENDGAME_ENDING_WINDOW_WIDTH,
      endgame_window_buffer, ENDGAME_ENDING_WINDOW_WIDTH);
    win_draw(endgame_window);

    endgame_load_palette(FID_TYPE(fid), fid and $FFF);

    // CE: Update overlay.
    endgameEndingUpdateOverlay;

    endgame_load_voiceover(narratorFileName);

    if endgame_subtitle_loaded or endgame_voiceover_loaded then
      delay := $FFFFFFFF
    else
      delay := 3000;

    palette_fade_to(@cmap[0]);

    pause_for_tocks(500);

    // NOTE: Uninline.
    endgame_play_voiceover;

    referenceTime := get_time;
    disable_bk;

    keyCode := -1;
    while True do
    begin
      sharedFpsLimiter.Mark;

      keyCode := get_input;
      if keyCode <> -1 then
        Break;

      if endgame_voiceover_done then
        Break;

      if endgame_subtitle_done then
        Break;

      if elapsed_time(referenceTime) > delay then
        Break;

      buf_to_buf(backgroundData, ENDGAME_ENDING_WINDOW_WIDTH,
        ENDGAME_ENDING_WINDOW_HEIGHT, ENDGAME_ENDING_WINDOW_WIDTH,
        endgame_window_buffer, ENDGAME_ENDING_WINDOW_WIDTH);
      endgame_show_subtitles;
      win_draw(endgame_window);
      soundUpdate;

      renderPresent;
      sharedFpsLimiter.Throttle;
    end;

    enable_bk;
    gsound_speech_stop;
    endgame_clear_subtitles;

    endgame_voiceover_loaded := False;
    endgame_subtitle_loaded := False;

    if keyCode = -1 then
      pause_for_tocks(500);

    palette_fade_to(@black_palette[0]);

    while mouse_get_buttons <> 0 do
    begin
      sharedFpsLimiter.Mark;

      get_input;

      renderPresent;
      sharedFpsLimiter.Throttle;
    end;
  end;

  art_ptr_unlock(backgroundHandle);
end;

// ---------------------------------------------------------------------------
// endgame_load_voiceover
// ---------------------------------------------------------------------------
procedure endgame_load_voiceover(const fileBaseName: PAnsiChar);
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  durationPerCharacter: Double;
  timing: LongWord;
  index: Integer;
  charactersCount: Double;
begin
  // NOTE: Uninline.
  endgame_stop_voiceover;

  endgame_voiceover_loaded := False;
  endgame_subtitle_loaded := False;

  // Build speech file path.
  StrLFmt(@path[0], SizeOf(path), '%s%s', [PAnsiChar('narrator\'), fileBaseName]);

  if gsound_speech_play(@path[0], 10, 14, 15) <> -1 then
    endgame_voiceover_loaded := True;

  if endgame_do_subtitles then
  begin
    // Build subtitles file path.
    StrLFmt(@path[0], SizeOf(path), '%s%s.txt', [PAnsiChar(@endgame_subtitle_path[0]), fileBaseName]);

    if endgame_load_subtitles(@path[0]) <> 0 then
      Exit;

    if endgame_voiceover_loaded then
      durationPerCharacter := gsound_speech_length_get / endgame_subtitle_characters
    else
      durationPerCharacter := 0.08;

    timing := 0;
    index := 0;
    while index < endgame_subtitle_count do
    begin
      charactersCount := StrLen(endgame_subtitle_text[index]);
      timing := timing + LongWord(Trunc(charactersCount * durationPerCharacter * 1000.0));
      endgame_subtitle_times[index] := timing;
      Inc(index);
    end;

    endgame_subtitle_loaded := True;
  end;
end;

// ---------------------------------------------------------------------------
// endgame_play_voiceover
// ---------------------------------------------------------------------------
procedure endgame_play_voiceover;
begin
  endgame_subtitle_done := False;
  endgame_voiceover_done := False;

  if endgame_voiceover_loaded then
    gsound_speech_play_preloaded;

  if endgame_subtitle_loaded then
    endgame_subtitle_start_time := get_time;
end;

// ---------------------------------------------------------------------------
// endgame_stop_voiceover
// ---------------------------------------------------------------------------
procedure endgame_stop_voiceover;
begin
  gsound_speech_stop;
  endgame_clear_subtitles;
  endgame_voiceover_loaded := False;
  endgame_subtitle_loaded := False;
end;

// ---------------------------------------------------------------------------
// endgame_load_palette
// ---------------------------------------------------------------------------
procedure endgame_load_palette(atype, id: Integer);
var
  fileName: array[0..12] of AnsiChar;
  pch: PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if art_get_base_name(atype, id, @fileName[0]) <> 0 then
    Exit;

  // Remove extension from file name.
  pch := StrRScan(@fileName[0], '.');
  if pch <> nil then
    pch^ := #0;

  if StrLen(@fileName[0]) <= 8 then
  begin
    StrLFmt(@path[0], SizeOf(path), '%s\%s.pal', [PAnsiChar('art\intrface'), PAnsiChar(@fileName[0])]);
    loadColorTable(@path[0]);
  end;
end;

// ---------------------------------------------------------------------------
// endgame_voiceover_callback
// ---------------------------------------------------------------------------
procedure endgame_voiceover_callback; cdecl;
begin
  endgame_voiceover_done := True;
end;

// ---------------------------------------------------------------------------
// endgame_load_subtitles
// ---------------------------------------------------------------------------
function endgame_load_subtitles(const filePath: PAnsiChar): Integer;
var
  stream: PDB_FILE;
  str: array[0..255] of AnsiChar;
  pch: PAnsiChar;
begin
  endgame_clear_subtitles;

  stream := db_fopen(filePath, 'rt');
  if stream = nil then
    Exit(-1);

  while db_fgets(@str[0], SizeOf(str), stream) <> nil do
  begin
    // Find and clamp string at EOL.
    pch := StrScan(@str[0], #10);
    if pch <> nil then
      pch^ := #0;

    // Find separator.
    pch := StrScan(@str[0], ':');
    if pch <> nil then
    begin
      if endgame_subtitle_count < ENDGAME_ENDING_MAX_SUBTITLES then
      begin
        endgame_subtitle_text[endgame_subtitle_count] := mem_strdup(pch + 1);
        endgame_subtitle_count := endgame_subtitle_count + 1;
        endgame_subtitle_characters := endgame_subtitle_characters + Integer(StrLen(pch + 1));
      end;
    end;
  end;

  db_fclose(stream);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// endgame_show_subtitles
// ---------------------------------------------------------------------------
procedure endgame_show_subtitles;
var
  txt: PAnsiChar;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  count: SmallInt;
  h: Integer;
  y: Integer;
  index: Integer;
  beginning: PAnsiChar;
  ending_: PAnsiChar;
  c: AnsiChar;
  w: Integer;
  x: Integer;
begin
  if endgame_subtitle_count <= endgame_current_subtitle then
  begin
    if endgame_subtitle_loaded then
      endgame_subtitle_done := True;
    Exit;
  end;

  if elapsed_time(endgame_subtitle_start_time) > endgame_subtitle_times[endgame_current_subtitle] then
  begin
    endgame_current_subtitle := endgame_current_subtitle + 1;
    Exit;
  end;

  txt := endgame_subtitle_text[endgame_current_subtitle];
  if txt = nil then
    Exit;

  if word_wrap(txt, 540, @beginnings[0], @count) <> 0 then
    Exit;

  h := text_height();
  y := 480 - h * count;

  index := 0;
  while index < count - 1 do
  begin
    beginning := txt + beginnings[index];
    ending_ := txt + beginnings[index + 1];

    if (ending_ - 1)^ = ' ' then
      Dec(ending_);

    c := ending_^;
    ending_^ := #0;

    w := text_width(beginning);
    x := (640 - w) div 2;
    buf_fill(endgame_window_buffer + 640 * y + x, w, h, 640, colorTable[0]);
    text_to_buf(endgame_window_buffer + 640 * y + x, beginning, w, 640, colorTable[32767]);

    ending_^ := c;

    y := y + h;
    Inc(index);
  end;
end;

// ---------------------------------------------------------------------------
// endgame_clear_subtitles
// ---------------------------------------------------------------------------
procedure endgame_clear_subtitles;
var
  index: Integer;
begin
  for index := 0 to endgame_subtitle_count - 1 do
  begin
    if endgame_subtitle_text[index] <> nil then
    begin
      mem_free(endgame_subtitle_text[index]);
      endgame_subtitle_text[index] := nil;
    end;
  end;

  endgame_current_subtitle := 0;
  endgame_subtitle_characters := 0;
  endgame_subtitle_count := 0;
end;

// ---------------------------------------------------------------------------
// endgame_movie_callback
// ---------------------------------------------------------------------------
procedure endgame_movie_callback; cdecl;
begin
  endgame_maybe_done := 1;
end;

// ---------------------------------------------------------------------------
// endgame_movie_bk_process
// ---------------------------------------------------------------------------
procedure endgame_movie_bk_process; cdecl;
begin
  if endgame_maybe_done <> 0 then
  begin
    gsound_background_play('10labone', 11, 14, 16);
    gsound_background_callback_set(nil);
    remove_bk_process(@endgame_movie_bk_process);
  end;
end;

// ---------------------------------------------------------------------------
// endgameEndingUpdateOverlay
// ---------------------------------------------------------------------------
procedure endgameEndingUpdateOverlay;
begin
  buf_fill(win_get_buf(gEndgameEndingOverlay),
    win_width(gEndgameEndingOverlay),
    win_height(gEndgameEndingOverlay),
    win_width(gEndgameEndingOverlay),
    intensityColorTable[colorTable[0]][0]);
  win_draw(gEndgameEndingOverlay);
end;

end.
