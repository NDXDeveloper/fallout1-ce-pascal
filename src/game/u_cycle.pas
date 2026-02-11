{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/cycle.h + cycle.cc
// Color cycling for palette animation (slime, shoreline, fire, monitors, bobber).
unit u_cycle;

interface

const
  COLOR_CYCLE_PERIOD_SLOW      = 200;
  COLOR_CYCLE_PERIOD_MEDIUM    = 142;
  COLOR_CYCLE_PERIOD_FAST      = 100;
  COLOR_CYCLE_PERIOD_VERY_FAST = 33;

var
  slime: array[0..11] of Byte = (
    0, 108, 0,
    11, 115, 7,
    27, 123, 15,
    43, 131, 27
  );

  shoreline: array[0..17] of Byte = (
    83, 63, 43,
    75, 59, 43,
    67, 55, 39,
    63, 51, 39,
    55, 47, 35,
    51, 43, 35
  );

  fire_slow: array[0..14] of Byte = (
    255, 0, 0,
    215, 0, 0,
    147, 43, 11,
    255, 119, 0,
    255, 59, 0
  );

  fire_fast: array[0..14] of Byte = (
    71, 0, 0,
    123, 0, 0,
    179, 0, 0,
    123, 0, 0,
    71, 0, 0
  );

  monitors: array[0..14] of Byte = (
    107, 107, 111,
    99, 103, 127,
    87, 107, 143,
    0, 147, 163,
    107, 187, 255
  );

procedure cycle_init;
procedure cycle_reset;
procedure cycle_exit;
procedure cycle_disable;
procedure cycle_enable;
function cycle_is_enabled: Boolean;
procedure change_cycle_speed(value: Integer);
function get_cycle_speed: Integer;

implementation

uses
  u_config, u_gconfig, u_palette, u_color, u_input;

var
  // Module-level variables (were C++ file-scope statics)
  cycle_speed_factor: Integer = 1;
  cycle_initialized: Boolean = False;
  cycle_enabled: Boolean = False;

  last_cycle_fast: LongWord;
  last_cycle_slow: LongWord;
  last_cycle_medium: LongWord;
  last_cycle_very_fast: LongWord;

  // Static locals from cycle_colors
  slime_start: Integer = 0;
  shoreline_start: Integer = 0;
  fire_slow_start: Integer = 0;
  fire_fast_start: Integer = 0;
  monitors_start: Integer = 0;
  bobber_red: Byte = 0;
  bobber_diff: ShortInt = -4;

procedure cycle_colors; cdecl; forward;

// 0x428D60
procedure cycle_init;
var
  colorCycling: Boolean;
  idx: Integer;
  cycleSpeedFactor: Integer;
begin
  if cycle_initialized then
    Exit;

  if not configGetBool(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_COLOR_CYCLING_KEY, @colorCycling) then
    colorCycling := True;

  if not colorCycling then
    Exit;

  idx := 0;
  while idx < 12 do
  begin
    slime[idx] := slime[idx] shr 2;
    Inc(idx);
  end;

  idx := 0;
  while idx < 18 do
  begin
    shoreline[idx] := shoreline[idx] shr 2;
    Inc(idx);
  end;

  idx := 0;
  while idx < 15 do
  begin
    fire_slow[idx] := fire_slow[idx] shr 2;
    Inc(idx);
  end;

  idx := 0;
  while idx < 15 do
  begin
    fire_fast[idx] := fire_fast[idx] shr 2;
    Inc(idx);
  end;

  idx := 0;
  while idx < 15 do
  begin
    monitors[idx] := monitors[idx] shr 2;
    Inc(idx);
  end;

  add_bk_process(@cycle_colors);

  cycle_initialized := True;
  cycle_enabled := True;

  if not config_get_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CYCLE_SPEED_FACTOR_KEY, @cycleSpeedFactor) then
    cycleSpeedFactor := 1;

  change_cycle_speed(cycleSpeedFactor);
end;

// 0x428EAC
procedure cycle_reset;
begin
  if cycle_initialized then
  begin
    last_cycle_slow := 0;
    last_cycle_medium := 0;
    last_cycle_fast := 0;
    last_cycle_very_fast := 0;
    add_bk_process(@cycle_colors);
    cycle_enabled := True;
  end;
end;

// 0x428EEC
procedure cycle_exit;
begin
  if cycle_initialized then
  begin
    remove_bk_process(@cycle_colors);
    cycle_initialized := False;
    cycle_enabled := False;
  end;
end;

// 0x428F10
procedure cycle_disable;
begin
  cycle_enabled := False;
end;

// 0x428F1C
procedure cycle_enable;
begin
  cycle_enabled := True;
end;

// 0x428F28
function cycle_is_enabled: Boolean;
begin
  Result := cycle_enabled;
end;

// 0x428F5C
procedure cycle_colors; cdecl;
var
  changed: Boolean;
  palette: PByte;
  time: LongWord;
  paletteIndex: Integer;
  idx: Integer;
begin
  if not cycle_enabled then
    Exit;

  changed := False;
  palette := getSystemPalette;
  time := get_time;

  if elapsed_tocks(time, last_cycle_slow) >= LongWord(COLOR_CYCLE_PERIOD_SLOW * cycle_speed_factor) then
  begin
    changed := True;
    last_cycle_slow := time;

    paletteIndex := 229 * 3;

    idx := slime_start;
    while idx < 12 do
    begin
      palette[paletteIndex] := slime[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    idx := 0;
    while idx < slime_start do
    begin
      palette[paletteIndex] := slime[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    Dec(slime_start, 3);
    if slime_start < 0 then
      slime_start := 9;

    paletteIndex := 248 * 3;

    idx := shoreline_start;
    while idx < 18 do
    begin
      palette[paletteIndex] := shoreline[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    idx := 0;
    while idx < shoreline_start do
    begin
      palette[paletteIndex] := shoreline[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    Dec(shoreline_start, 3);
    if shoreline_start < 0 then
      shoreline_start := 15;

    paletteIndex := 238 * 3;

    idx := fire_slow_start;
    while idx < 15 do
    begin
      palette[paletteIndex] := fire_slow[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    idx := 0;
    while idx < fire_slow_start do
    begin
      palette[paletteIndex] := fire_slow[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    Dec(fire_slow_start, 3);
    if fire_slow_start < 0 then
      fire_slow_start := 12;
  end;

  if elapsed_tocks(time, last_cycle_medium) >= LongWord(COLOR_CYCLE_PERIOD_MEDIUM * cycle_speed_factor) then
  begin
    changed := True;
    last_cycle_medium := time;

    paletteIndex := 243 * 3;

    idx := fire_fast_start;
    while idx < 15 do
    begin
      palette[paletteIndex] := fire_fast[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    idx := 0;
    while idx < fire_fast_start do
    begin
      palette[paletteIndex] := fire_fast[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    Dec(fire_fast_start, 3);
    if fire_fast_start < 0 then
      fire_fast_start := 12;
  end;

  if elapsed_tocks(time, last_cycle_fast) >= LongWord(COLOR_CYCLE_PERIOD_FAST * cycle_speed_factor) then
  begin
    changed := True;
    last_cycle_fast := time;

    paletteIndex := 233 * 3;

    idx := monitors_start;
    while idx < 15 do
    begin
      palette[paletteIndex] := monitors[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    idx := 0;
    while idx < monitors_start do
    begin
      palette[paletteIndex] := monitors[idx];
      Inc(paletteIndex);
      Inc(idx);
    end;

    Dec(monitors_start, 3);
    if monitors_start < 0 then
      monitors_start := 12;
  end;

  if elapsed_tocks(time, last_cycle_very_fast) >= LongWord(COLOR_CYCLE_PERIOD_VERY_FAST * cycle_speed_factor) then
  begin
    changed := True;
    last_cycle_very_fast := time;

    if (bobber_red = 0) or (bobber_red = 60) then
      bobber_diff := -bobber_diff;

    {$PUSH}{$R-}{$Q-}
    bobber_red := bobber_red + Byte(bobber_diff);
    {$POP}

    paletteIndex := 254 * 3;
    palette[paletteIndex] := bobber_red;
    Inc(paletteIndex);
    palette[paletteIndex] := 0;
    Inc(paletteIndex);
    palette[paletteIndex] := 0;
  end;

  if changed then
    palette_set_entries(palette + 229 * 3, 229, 255);
end;

// 0x428F30
procedure change_cycle_speed(value: Integer);
begin
  cycle_speed_factor := value;
  config_set_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_CYCLE_SPEED_FACTOR_KEY, value);
end;

// 0x428F54
function get_cycle_speed: Integer;
begin
  Result := cycle_speed_factor;
end;

end.
