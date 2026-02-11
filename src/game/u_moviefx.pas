{$MODE OBJFPC}{$H+}
{$R-} // Disable range checks - low-level palette manipulation with byte arithmetic
// Converted from: src/game/moviefx.h + moviefx.cc
// Movie special effects (fade in/out transitions).
unit u_moviefx;

interface

function moviefx_init: Integer;
procedure moviefx_reset;
procedure moviefx_exit;
function moviefx_start(const filePath: PAnsiChar): Integer;
procedure moviefx_stop;

implementation

uses
  SysUtils, u_config, u_palette, u_debug, u_memory, u_platform_compat,
  u_int_movie;

const
  MOVIE_EFFECT_TYPE_NONE    = 0;
  MOVIE_EFFECT_TYPE_FADE_IN = 1;
  MOVIE_EFFECT_TYPE_FADE_OUT = 2;

type
  PMovieEffect = ^TMovieEffect;
  TMovieEffect = record
    startFrame: Integer;
    endFrame: Integer;
    steps: Integer;
    fadeType: Byte;
    r: Byte;
    g: Byte;
    b: Byte;
    next: PMovieEffect;
  end;

var
  moviefx_initialized: Boolean = False;
  moviefx_effects_list: PMovieEffect = nil;
  source_palette: array[0..767] of Byte;
  inside_fade: Boolean;

procedure moviefx_callback_func(frame: Integer); cdecl; forward;
procedure moviefx_palette_func(palette: PByte; startIdx, endIdx: Integer); cdecl; forward;
procedure moviefx_add(movie_effect: PMovieEffect); forward;
procedure moviefx_remove_all; forward;

function moviefx_init: Integer;
begin
  if moviefx_initialized then
    Exit(-1);

  FillChar(source_palette, SizeOf(source_palette), 0);

  moviefx_initialized := True;
  Result := 0;
end;

procedure moviefx_reset;
begin
  if not moviefx_initialized then
    Exit;

  movieSetCallback(nil);
  movieSetPaletteFunc(nil);
  moviefx_remove_all;

  inside_fade := False;

  FillChar(source_palette, SizeOf(source_palette), 0);
end;

procedure moviefx_exit;
begin
  if not moviefx_initialized then
    Exit;

  movieSetCallback(nil);
  movieSetPaletteFunc(nil);
  moviefx_remove_all;

  inside_fade := False;

  FillChar(source_palette, SizeOf(source_palette), 0);
end;

function moviefx_start(const filePath: PAnsiChar): Integer;
label _out;
var
  config: TConfig;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  pch: PAnsiChar;
  movieEffectsLength: Integer;
  movieEffectFrameList: PInteger;
  frameListRead: Boolean;
  movieEffectsCreated: Integer;
  index: Integer;
  section: array[0..19] of AnsiChar;
  fadeTypeString: PAnsiChar;
  fadeType: Integer;
  fadeColor: array[0..2] of Integer;
  steps: Integer;
  movieEffect: PMovieEffect;
  rc: Integer;
begin

  if not moviefx_initialized then
    Exit(-1);

  movieSetCallback(nil);
  movieSetPaletteFunc(nil);
  moviefx_remove_all;
  inside_fade := False;
  FillChar(source_palette, SizeOf(source_palette), 0);

  if filePath = nil then
    Exit(-1);

  if not config_init(@config) then
    Exit(-1);

  rc := -1;

  StrCopy(@path[0], filePath);

  pch := StrRScan(@path[0], '.');
  if pch <> nil then
    pch^ := #0;

  StrCat(@path[0], '.cfg');

  movieEffectFrameList := nil;

  if not config_load(@config, @path[0], True) then
    goto _out;

  if not config_get_value(@config, 'info', 'total_effects', @movieEffectsLength) then
    goto _out;

  movieEffectFrameList := PInteger(mem_malloc(SizeOf(Integer) * movieEffectsLength));
  if movieEffectFrameList = nil then
    goto _out;

  if movieEffectsLength >= 2 then
    frameListRead := config_get_values(@config, 'info', 'effect_frames', movieEffectFrameList, movieEffectsLength)
  else
    frameListRead := config_get_value(@config, 'info', 'effect_frames', movieEffectFrameList);

  if frameListRead then
  begin
    movieEffectsCreated := 0;
    for index := 0 to movieEffectsLength - 1 do
    begin
      compat_itoa((movieEffectFrameList + index)^, @section[0], 10);

      if not config_get_string(@config, @section[0], 'fade_type', @fadeTypeString) then
        Continue;

      fadeType := MOVIE_EFFECT_TYPE_NONE;
      if compat_stricmp(fadeTypeString, 'in') = 0 then
        fadeType := MOVIE_EFFECT_TYPE_FADE_IN
      else if compat_stricmp(fadeTypeString, 'out') = 0 then
        fadeType := MOVIE_EFFECT_TYPE_FADE_OUT;

      if fadeType = MOVIE_EFFECT_TYPE_NONE then
        Continue;

      if not config_get_values(@config, @section[0], 'fade_color', @fadeColor[0], 3) then
        Continue;

      if not config_get_value(@config, @section[0], 'fade_steps', @steps) then
        Continue;

      movieEffect := PMovieEffect(mem_malloc(SizeOf(TMovieEffect)));
      if movieEffect = nil then
        Continue;

      FillChar(movieEffect^, SizeOf(TMovieEffect), 0);
      movieEffect^.startFrame := (movieEffectFrameList + index)^;
      movieEffect^.endFrame := movieEffect^.startFrame + steps - 1;
      movieEffect^.steps := steps;
      movieEffect^.fadeType := fadeType and $FF;
      movieEffect^.r := fadeColor[0] and $FF;
      movieEffect^.g := fadeColor[1] and $FF;
      movieEffect^.b := fadeColor[2] and $FF;

      if movieEffect^.startFrame <= 1 then
        inside_fade := True;

      moviefx_add(movieEffect);

      Inc(movieEffectsCreated);
    end;

    if movieEffectsCreated <> 0 then
    begin
      movieSetCallback(@moviefx_callback_func);
      movieSetPaletteFunc(@moviefx_palette_func);
      rc := 0;
    end;
  end;

  if movieEffectFrameList <> nil then
    mem_free(movieEffectFrameList);

_out:
  config_exit(@config);
  Result := rc;
end;

procedure moviefx_stop;
begin
  if not moviefx_initialized then
    Exit;

  movieSetCallback(nil);
  movieSetPaletteFunc(nil);

  moviefx_remove_all;

  inside_fade := False;
  FillChar(source_palette, SizeOf(source_palette), 0);
end;

procedure moviefx_callback_func(frame: Integer); cdecl;
var
  movieEffect: PMovieEffect;
  palette: array[0..767] of Byte;
  step, idx: Integer;
begin
  movieEffect := moviefx_effects_list;
  while movieEffect <> nil do
  begin
    if (frame >= movieEffect^.startFrame) and (frame <= movieEffect^.endFrame) then
      Break;
    movieEffect := movieEffect^.next;
  end;

  if movieEffect <> nil then
  begin
    step := frame - movieEffect^.startFrame + 1;

    if movieEffect^.fadeType = MOVIE_EFFECT_TYPE_FADE_IN then
    begin
      for idx := 0 to 255 do
      begin
        palette[idx * 3] := movieEffect^.r - Byte(step * (Integer(movieEffect^.r) - Integer(source_palette[idx * 3])) div movieEffect^.steps);
        palette[idx * 3 + 1] := movieEffect^.g - Byte(step * (Integer(movieEffect^.g) - Integer(source_palette[idx * 3 + 1])) div movieEffect^.steps);
        palette[idx * 3 + 2] := movieEffect^.b - Byte(step * (Integer(movieEffect^.b) - Integer(source_palette[idx * 3 + 2])) div movieEffect^.steps);
      end;
    end
    else
    begin
      for idx := 0 to 255 do
      begin
        palette[idx * 3] := source_palette[idx * 3] - Byte(step * (Integer(source_palette[idx * 3]) - Integer(movieEffect^.r)) div movieEffect^.steps);
        palette[idx * 3 + 1] := source_palette[idx * 3 + 1] - Byte(step * (Integer(source_palette[idx * 3 + 1]) - Integer(movieEffect^.g)) div movieEffect^.steps);
        palette[idx * 3 + 2] := source_palette[idx * 3 + 2] - Byte(step * (Integer(source_palette[idx * 3 + 2]) - Integer(movieEffect^.b)) div movieEffect^.steps);
      end;
    end;

    palette_set_to(@palette[0]);
  end;

  inside_fade := movieEffect <> nil;
end;

procedure moviefx_palette_func(palette: PByte; startIdx, endIdx: Integer); cdecl;
begin
  Move(palette^, source_palette[3 * startIdx], 3 * (endIdx - startIdx + 1));

  if not inside_fade then
    palette_set_entries(palette, startIdx, endIdx);
end;

procedure moviefx_add(movie_effect: PMovieEffect);
begin
  movie_effect^.next := moviefx_effects_list;
  moviefx_effects_list := movie_effect;
end;

procedure moviefx_remove_all;
var
  movieEffect, next: PMovieEffect;
begin
  movieEffect := moviefx_effects_list;
  while movieEffect <> nil do
  begin
    next := movieEffect^.next;
    mem_free(movieEffect);
    movieEffect := next;
  end;

  moviefx_effects_list := nil;
end;

end.
