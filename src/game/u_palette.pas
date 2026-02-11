{$MODE OBJFPC}{$H+}
// Converted from: src/game/palette.h + palette.cc
// Palette fading, setting, and initialization.
unit u_palette;

interface

var
  white_palette: array[0..767] of Byte;
  black_palette: array[0..767] of Byte;

procedure palette_init;
procedure palette_reset;
procedure palette_exit;
procedure palette_fade_to(palette: PByte);
procedure palette_set_to(palette: PByte);
procedure palette_set_entries(palette: PByte; startIdx, endIdx: Integer);

implementation

uses
  u_color, u_debug, u_input,
  u_cycle, u_gsound, u_int_sound;

var
  current_palette: array[0..767] of Byte;
  fade_steps: Integer;

procedure soundUpdate_cdecl; cdecl;
begin soundUpdate; end;

procedure palette_init;
var
  tick, actualFadeDuration: LongWord;
begin
  FillChar(black_palette, SizeOf(black_palette), 0);
  FillChar(white_palette, SizeOf(white_palette), 63);
  Move(cmap, current_palette, 768);

  tick := get_time;
  if (gsound_background_is_enabled <> 0) or (gsound_speech_is_enabled <> 0) then
    colorSetFadeBkFunc(@soundUpdate_cdecl);

  fadeSystemPalette(@current_palette[0], @current_palette[0], 60);

  colorSetFadeBkFunc(nil);

  actualFadeDuration := elapsed_time(tick);

  if actualFadeDuration = 0 then
    actualFadeDuration := 1;
  fade_steps := 60 * 700 div Integer(actualFadeDuration);

  debug_printf(#10'Fade time is %u'#10'Fade steps are %d'#10, [actualFadeDuration, fade_steps]);
end;

procedure palette_reset;
begin
  // empty
end;

procedure palette_exit;
begin
  // empty
end;

procedure palette_fade_to(palette: PByte);
var
  colorCycleWasEnabled: Boolean;
begin
  colorCycleWasEnabled := cycle_is_enabled;
  cycle_disable;

  if (gsound_background_is_enabled <> 0) or (gsound_speech_is_enabled <> 0) then
    colorSetFadeBkFunc(@soundUpdate_cdecl);

  fadeSystemPalette(@current_palette[0], palette, fade_steps);
  colorSetFadeBkFunc(nil);

  Move(palette^, current_palette, 768);

  if colorCycleWasEnabled then
    cycle_enable;
end;

procedure palette_set_to(palette: PByte);
begin
  Move(palette^, current_palette, SizeOf(current_palette));
  setSystemPalette(palette);
end;

procedure palette_set_entries(palette: PByte; startIdx, endIdx: Integer);
begin
  Move(palette^, current_palette[3 * startIdx], 3 * (endIdx - startIdx + 1));
  setSystemPaletteEntries(palette, startIdx, endIdx);
end;

end.
