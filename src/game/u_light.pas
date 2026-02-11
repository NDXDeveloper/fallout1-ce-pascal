{$MODE OBJFPC}{$H+}
// Converted from: src/game/light.h + light.cc
// Tile lighting system.
unit u_light;

interface

uses
  u_map_defs;

const
  LIGHT_LEVEL_MAX = 65536;
  LIGHT_LEVEL_MIN = LIGHT_LEVEL_MAX div 4;
  LIGHT_LEVEL_NIGHT_VISION_BONUS = LIGHT_LEVEL_MAX div 10;

type
  TAdjustLightIntensityProc = procedure(elevation, tile, intensity: Integer);

function light_init: Integer;
procedure light_reset;
procedure light_exit;
function light_get_ambient: Integer;
procedure light_set_ambient(new_ambient_light: Integer; refresh_screen: Boolean);
procedure light_increase_ambient(value: Integer; refresh_screen: Boolean);
procedure light_decrease_ambient(value: Integer; refresh_screen: Boolean);
function light_get_tile(elevation, tile: Integer): Integer;
function light_get_tile_true(elevation, tile: Integer): Integer;
procedure light_set_tile(elevation, tile, intensity: Integer);
procedure light_add_to_tile(elevation, tile, intensity: Integer);
procedure light_subtract_from_tile(elevation, tile, intensity: Integer);
procedure light_reset_tiles;

implementation

uses
  u_perk,
  u_tile;

var
  ambient_light: Integer = LIGHT_LEVEL_MAX;
  tile_intensity: array[0..ELEVATION_COUNT - 1, 0..HEX_GRID_SIZE - 1] of Integer;

function light_init: Integer;
begin
  light_reset_tiles;
  Result := 0;
end;

procedure light_reset;
begin
  light_reset_tiles;
end;

procedure light_exit;
begin
  light_reset_tiles;
end;

function light_get_ambient: Integer;
begin
  Result := ambient_light;
end;

procedure light_set_ambient(new_ambient_light: Integer; refresh_screen: Boolean);
var
  normalized: Integer;
  old_ambient_light: Integer;
begin
  normalized := new_ambient_light + perk_level(PERK_NIGHT_VISION) * LIGHT_LEVEL_NIGHT_VISION_BONUS;

  if normalized < LIGHT_LEVEL_MIN then
    normalized := LIGHT_LEVEL_MIN;

  if normalized > LIGHT_LEVEL_MAX then
    normalized := LIGHT_LEVEL_MAX;

  old_ambient_light := ambient_light;
  ambient_light := normalized;

  if refresh_screen then
  begin
    if old_ambient_light <> normalized then
      tile_refresh_display;
  end;
end;

procedure light_increase_ambient(value: Integer; refresh_screen: Boolean);
begin
  light_set_ambient(ambient_light + value, refresh_screen);
end;

procedure light_decrease_ambient(value: Integer; refresh_screen: Boolean);
begin
  light_set_ambient(ambient_light - value, refresh_screen);
end;

function light_get_tile(elevation, tile: Integer): Integer;
var
  intensity: Integer;
begin
  if not ElevationIsValid(elevation) then
    Exit(0);

  if not HexGridTileIsValid(tile) then
    Exit(0);

  intensity := tile_intensity[elevation][tile];
  if intensity >= LIGHT_LEVEL_MAX then
    intensity := LIGHT_LEVEL_MAX;

  Result := intensity;
end;

function light_get_tile_true(elevation, tile: Integer): Integer;
begin
  if not ElevationIsValid(elevation) then
    Exit(0);

  if not HexGridTileIsValid(tile) then
    Exit(0);

  Result := tile_intensity[elevation][tile];
end;

procedure light_set_tile(elevation, tile, intensity: Integer);
begin
  if not ElevationIsValid(elevation) then
    Exit;

  if not HexGridTileIsValid(tile) then
    Exit;

  tile_intensity[elevation][tile] := intensity;
end;

procedure light_add_to_tile(elevation, tile, intensity: Integer);
begin
  if not ElevationIsValid(elevation) then
    Exit;

  if not HexGridTileIsValid(tile) then
    Exit;

  tile_intensity[elevation][tile] := tile_intensity[elevation][tile] + intensity;
end;

procedure light_subtract_from_tile(elevation, tile, intensity: Integer);
begin
  if not ElevationIsValid(elevation) then
    Exit;

  if not HexGridTileIsValid(tile) then
    Exit;

  tile_intensity[elevation][tile] := tile_intensity[elevation][tile] - intensity;
end;

procedure light_reset_tiles;
var
  elev, t: Integer;
begin
  for elev := 0 to ELEVATION_COUNT - 1 do
    for t := 0 to HEX_GRID_SIZE - 1 do
      tile_intensity[elev][t] := 655;
end;

end.
