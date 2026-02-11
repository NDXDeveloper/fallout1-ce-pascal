{$MODE OBJFPC}{$H+}
// Converted from: src/game/gmovie.h + gmovie.cc
// Game movie playback (cutscenes).
unit u_gmovie;

interface

uses
  u_db;

const
  // GameMovieFlags
  GAME_MOVIE_FADE_IN    = $01;
  GAME_MOVIE_FADE_OUT   = $02;
  GAME_MOVIE_STOP_MUSIC = $04;
  GAME_MOVIE_PAUSE_MUSIC = $08;

  // GameMovie
  MOVIE_IPLOGO   = 0;
  MOVIE_MPLOGO   = 1;
  MOVIE_INTRO    = 2;
  MOVIE_VEXPLD   = 3;
  MOVIE_CATHEXP  = 4;
  MOVIE_OVRINTRO = 5;
  MOVIE_BOIL3    = 6;
  MOVIE_OVRRUN   = 7;
  MOVIE_WALKM    = 8;
  MOVIE_WALKW    = 9;
  MOVIE_DIPEDV   = 10;
  MOVIE_BOIL1    = 11;
  MOVIE_BOIL2    = 12;
  MOVIE_RAEKILLS = 13;
  MOVIE_COUNT    = 14;

function gmovie_init: Integer;
procedure gmovie_reset;
procedure gmovie_exit;
function gmovie_load(stream: PDB_FILE): Integer;
function gmovie_save(stream: PDB_FILE): Integer;
function gmovie_play(game_movie, game_movie_flags: Integer): Integer;
function gmovie_has_been_played(game_movie: Integer): Boolean;

implementation

uses
  SysUtils, u_gconfig, u_config, u_moviefx, u_palette, u_color,
  u_debug, u_gnw, u_input, u_svga, u_text, u_touch, u_mouse,
  u_platform_compat, u_cycle,
  u_gsound, u_int_movie, u_gmouse, u_int_window, u_game;


const
  MOUSE_CURSOR_NONE  = 0;
  MOUSE_CURSOR_ARROW = 1;
  WINDOW_MODAL       = $10;

  GAME_MOVIE_WINDOW_WIDTH  = 640;
  GAME_MOVIE_WINDOW_HEIGHT = 480;

var
  movie_list: array[0..MOVIE_COUNT - 1] of PAnsiChar = (
    'iplogo.mve',
    'mplogo.mve',
    'intro.mve',
    'vexpld.mve',
    'cathexp.mve',
    'ovrintro.mve',
    'boil3.mve',
    'ovrrun.mve',
    'walkm.mve',
    'walkw.mve',
    'dipedv.mve',
    'boil1.mve',
    'boil2.mve',
    'raekills.mve'
  );

  gmovie_played_list: array[0..MOVIE_COUNT - 1] of Byte;
  gmovie_subtitle_full_path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;

function gmovie_subtitle_func(movieFilePath: PAnsiChar): PAnsiChar; forward;

function gmovie_init: Integer;
var
  volume: Integer;
begin
  volume := 0;
  if gsound_background_is_enabled <> 0 then
    volume := gsound_background_volume_get;

  movieSetVolume(volume);
  movieSetSubtitleFunc(TMovieSubtitleFunc(@gmovie_subtitle_func));

  FillChar(gmovie_played_list, SizeOf(gmovie_played_list), 0);
  Result := 0;
end;

procedure gmovie_reset;
begin
  FillChar(gmovie_played_list, SizeOf(gmovie_played_list), 0);
end;

procedure gmovie_exit;
begin
  // empty
end;

function gmovie_load(stream: PDB_FILE): Integer;
begin
  if db_fread(@gmovie_played_list[0], SizeOf(Byte), MOVIE_COUNT, stream) <> MOVIE_COUNT then
    Exit(-1);

  Result := 0;
end;

function gmovie_save(stream: PDB_FILE): Integer;
begin
  if db_fwrite(@gmovie_played_list[0], SizeOf(Byte), MOVIE_COUNT, stream) <> MOVIE_COUNT then
    Exit(-1);

  Result := 0;
end;

function gmovie_play(game_movie, game_movie_flags: Integer): Integer;
var
  de: TDirEntry;
  movieFilePath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  gameMovieWindowX, gameMovieWindowY, win: Integer;
  subtitlesEnabled: Boolean;
  movie_flags: Integer;
  subtitlesFilePath: PAnsiChar;
  oldTextColor, oldFont: Integer;
  cursorWasHidden: Boolean;
  v11, buttons, x, y: Integer;
  gesture: TGesture;
  r, g, b: Single;
begin
  debug_printf(#10'Playing movie: %s'#10, [movie_list[game_movie]]);

  StrLFmt(@movieFilePath[0], SizeOf(movieFilePath) - 1, 'art\cuts\%s', [movie_list[game_movie]]);

  if db_dir_entry(@movieFilePath[0], @de) <> 0 then
  begin
    debug_printf(#10'gmovie_play() - Error: Unable to open %s'#10, [movie_list[game_movie]]);
    Exit(-1);
  end;

  if (game_movie_flags and GAME_MOVIE_FADE_IN) <> 0 then
    palette_fade_to(@black_palette[0]);

  gameMovieWindowX := (screenGetWidth - GAME_MOVIE_WINDOW_WIDTH) div 2;
  gameMovieWindowY := (screenGetHeight - GAME_MOVIE_WINDOW_HEIGHT) div 2;
  win := win_add(gameMovieWindowX, gameMovieWindowY,
    GAME_MOVIE_WINDOW_WIDTH, GAME_MOVIE_WINDOW_HEIGHT, 0, WINDOW_MODAL);
  if win = -1 then
    Exit(-1);

  if (game_movie_flags and GAME_MOVIE_STOP_MUSIC) <> 0 then
    gsound_background_stop
  else if (game_movie_flags and GAME_MOVIE_PAUSE_MUSIC) <> 0 then
    gsound_background_pause;

  win_draw(win);

  subtitlesEnabled := False;
  if (game_movie = MOVIE_BOIL3) or (game_movie = MOVIE_BOIL1) or (game_movie = MOVIE_BOIL2) then
    subtitlesEnabled := True
  else
    configGetBool(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_SUBTITLES_KEY, @subtitlesEnabled);

  movie_flags := 4;

  if subtitlesEnabled then
  begin
    subtitlesFilePath := gmovie_subtitle_func(@movieFilePath[0]);

    if db_dir_entry(subtitlesFilePath, @de) = 0 then
      movie_flags := movie_flags or $8
    else
      subtitlesEnabled := False;
  end;

  movieSetFlags(movie_flags);

  oldTextColor := 0;
  oldFont := 0;
  if subtitlesEnabled then
  begin
    loadColorTable('art\cuts\subtitle.pal');

    oldTextColor := windowGetTextColor;
    windowSetTextColor(1.0, 1.0, 1.0);

    oldFont := text_curr;
    windowSetFont(101);
  end;

  cursorWasHidden := mouse_hidden;
  if cursorWasHidden then
  begin
    gmouse_set_cursor(MOUSE_CURSOR_NONE);
    mouse_show;
  end;

  while mouse_get_buttons <> 0 do
    mouse_info;

  mouse_hide;
  cycle_disable;

  moviefx_start(@movieFilePath[0]);
  WriteLn(StdErr, '[GMOVIE] calling movieRun');
  movieRun(win, @movieFilePath[0]);
  WriteLn(StdErr, '[GMOVIE] movieRun done, entering loop, moviePlaying=', moviePlaying);

  v11 := 0;
  repeat
    if (moviePlaying = 0) or (game_user_wants_to_quit <> 0) or (get_input <> -1) then
    begin
      WriteLn(StdErr, '[GMOVIE] loop exit: moviePlaying=', moviePlaying,
        ' quit=', game_user_wants_to_quit);
      Break;
    end;

    if touch_get_gesture(@gesture) and (gesture.State = GESTURE_ENDED) then
      Break;

    mouse_get_raw_state(@x, @y, @buttons);
    v11 := v11 or buttons;
  until ((v11 and 1) <> 0) or ((v11 and 2) <> 0);

  movieStop;
  moviefx_stop;
  movieUpdate;
  palette_set_to(@black_palette[0]);

  gmovie_played_list[game_movie] := 1;

  cycle_enable;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  if not cursorWasHidden then
    mouse_show;

  if subtitlesEnabled then
  begin
    loadColorTable('color.pal');

    windowSetFont(oldFont);

    r := ((Color2RGB(oldTextColor) and $7C00) shr 10) / 31.0;
    g := ((Color2RGB(oldTextColor) and $3E0) shr 5) / 31.0;
    b := (Color2RGB(oldTextColor) and $1F) / 31.0;
    windowSetTextColor(r, g, b);
  end;

  win_delete(win);

  win_refresh_all(@scr_size);

  if (game_movie_flags and GAME_MOVIE_PAUSE_MUSIC) <> 0 then
    gsound_background_unpause;

  if (game_movie_flags and GAME_MOVIE_FADE_OUT) <> 0 then
  begin
    if not subtitlesEnabled then
      loadColorTable('color.pal');

    palette_fade_to(@cmap[0]);
  end;

  Result := 0;
end;

function gmovie_has_been_played(game_movie: Integer): Boolean;
begin
  Result := gmovie_played_list[game_movie] = 1;
end;

function gmovie_subtitle_func(movieFilePath: PAnsiChar): PAnsiChar;
var
  language: PAnsiChar;
  separator: PAnsiChar;
begin
  language := nil;
  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_LANGUAGE_KEY, @language);

  separator := StrRScan(movieFilePath, '\');
  if separator <> nil then
    movieFilePath := separator + 1;

  StrLFmt(@gmovie_subtitle_full_path[0], SizeOf(gmovie_subtitle_full_path) - 1, 'text\%s\cuts\%s', [language, movieFilePath]);

  separator := StrRScan(@gmovie_subtitle_full_path[0], '.');
  if (separator <> nil) and (separator^ <> #0) then
    separator^ := #0;

  StrCat(@gmovie_subtitle_full_path[0], '.SVE');

  Result := @gmovie_subtitle_full_path[0];
end;

end.
