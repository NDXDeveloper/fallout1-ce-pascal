unit u_tile;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
{$R-} // Disable range checks - low-level tile coordinate arithmetic

// Converted from: src/game/tile.h + tile.cc
// Hex tile system: coordinate conversion, scrolling, rendering.

interface

uses
  u_object_types, u_map_defs, u_rect;

const
  TILE_SET_CENTER_REFRESH_WINDOW = $01;
  TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS = $02;

type
  TTileWindowRefreshProc = procedure(rect: PRect);
  TTileWindowRefreshElevationProc = procedure(rect: PRect; elevation: Integer);

  PTileData = ^TTileData;
  PPTileData = ^PTileData;
  TTileData = record
    field_0: array[0..SQUARE_GRID_SIZE - 1] of Integer;
  end;

var
  off_tile: array[0..1, 0..5] of Integer;
  tile_center_tile: Integer;

function tile_init(a1: PPTileData; squareGridWidth, squareGridHeight,
  hexGridWidth, hexGridHeight: Integer; buffer: PByte;
  windowWidth, windowHeight, windowPitch: Integer;
  windowRefreshProc: TTileWindowRefreshProc): Integer;
procedure tile_set_border(windowWidth, windowHeight, hexGridWidth, hexGridHeight: Integer);
procedure tile_reset;
procedure tile_exit;
procedure tile_disable_refresh;
procedure tile_enable_refresh;
procedure tile_refresh_rect(rect: PRect; elevation: Integer);
procedure tile_refresh_display;
function tile_set_center(tile, flags: Integer): Integer;
procedure tile_toggle_roof(a1: Integer);
function tile_roof_visible: Integer;
function tile_coord(tile: Integer; screenX, screenY: PInteger; elevation: Integer): Integer;
function tile_num(screenX, screenY, elevation: Integer; ignoreBounds: Boolean = False): Integer;
function tile_dist(tile1, tile2: Integer): Integer;
function tile_in_front_of(tile1, tile2: Integer): Boolean;
function tile_to_right_of(tile1, tile2: Integer): Boolean;
function tile_num_in_direction(tile, rotation, distance: Integer): Integer;
function tile_dir(tile1, tile2: Integer): Integer;
function tile_num_beyond(from_, to_, distance: Integer): Integer;
procedure tile_enable_scroll_blocking;
procedure tile_disable_scroll_blocking;
function tile_get_scroll_blocking: Boolean;
procedure tile_enable_scroll_limiting;
procedure tile_disable_scroll_limiting;
function tile_get_scroll_limiting: Boolean;
function square_coord(squareTile: Integer; coordX, coordY: PInteger; elevation: Integer): Integer;
function square_coord_roof(squareTile: Integer; screenX, screenY: PInteger; elevation: Integer): Integer;
function square_num(screenX, screenY, elevation: Integer): Integer;
function square_num_roof(screenX, screenY, elevation: Integer): Integer;
procedure square_xy(screenX, screenY, elevation: Integer; coordX, coordY: PInteger);
procedure square_xy_roof(screenX, screenY, elevation: Integer; coordX, coordY: PInteger);
procedure square_render_roof(rect: PRect; elevation: Integer);
procedure tile_fill_roof(x, y, elevation: Integer; flag: Boolean);
procedure square_render_floor(rect: PRect; elevation: Integer);
function square_roof_intersect(x, y, elevation: Integer): Boolean;
procedure grid_toggle;
procedure grid_on;
procedure grid_off;
function get_grid_flag: Integer;
procedure grid_render(rect: PRect; elevation: Integer);
procedure grid_draw(tile, elevation: Integer);
procedure draw_grid(tile, elevation: Integer; rect: PRect);
procedure floor_draw(fid, x, y: Integer; rect: PRect);
function tile_make_line(from_, to_: Integer; tiles: PInteger; tilesCapacity: Integer): Integer;
function tile_scroll_to(tile, flags: Integer): Integer;

procedure tile_update_bounds_base;
procedure tile_update_bounds_rect;
function tile_inside_bound(rect: PRect): Integer;
function tile_point_inside_bound(x, y: Integer): Boolean;
procedure bounds_render(rect: PRect; elevation: Integer);

implementation

uses
  Math, SysUtils,
  u_color, u_grbuf, u_cache, u_art, u_light, u_object, u_config, u_gconfig,
  u_platform_compat, u_map, u_gmouse;

// Internal forward declarations
procedure refresh_mapper(rect: PRect; elevation: Integer); forward;
procedure refresh_game(rect: PRect; elevation: Integer); forward;
function tile_on_edge(tile: Integer): Boolean; forward;
procedure roof_fill_on(x, y, elevation: Integer); forward;
procedure roof_fill_off(x, y, elevation: Integer); forward;
procedure roof_draw(fid, x, y: Integer; rect: PRect; light: Integer); forward;

const
  ORIGINAL_ISO_WINDOW_WIDTH  = 640;
  ORIGINAL_ISO_WINDOW_HEIGHT = 380;

  ROTATION_NE_CONST = 0;
  ROTATION_E_CONST = 1;
  ROTATION_SE_CONST = 2;
  ROTATION_SW_CONST = 3;
  ROTATION_W_CONST = 4;
  ROTATION_NW_CONST = 5;
  ROTATION_COUNT_CONST = 6;

type
  TRightsideUpTableEntry = record
    field_0: Integer;
    field_4: Integer;
  end;

  TUpsideDownTableEntry = record
    field_0: Integer;
    field_4: Integer;
  end;

  TSTRUCT_51DA6C = record
    field_0: Integer;
    offsets: array[0..1] of Integer;
    intensity: Integer;
  end;

  TRightsideUpTriangle = record
    field_0: Integer;
    field_4: Integer;
    field_8: Integer;
  end;

  TUpsideDownTriangle = record
    field_0: Integer;
    field_4: Integer;
    field_8: Integer;
  end;

var
  // 0x508330
  borderInitialized: Boolean = False;

  // 0x508334
  scroll_blocking_on: Boolean = True;

  // 0x508338
  scroll_limiting_on: Boolean = True;

  // 0x50833C
  show_roof: Boolean = True;

  // 0x508340
  show_grid: Boolean = False;

  // 0x508344
  tile_refresh_proc: TTileWindowRefreshElevationProc = nil;

  // 0x508348
  refresh_enabled: Boolean = True;

  // 0x50837C
  rightside_up_table: array[0..12] of TRightsideUpTableEntry = (
    (field_0: -1; field_4: 2),
    (field_0: 78; field_4: 2),
    (field_0: 76; field_4: 6),
    (field_0: 73; field_4: 8),
    (field_0: 71; field_4: 10),
    (field_0: 68; field_4: 14),
    (field_0: 65; field_4: 16),
    (field_0: 63; field_4: 18),
    (field_0: 61; field_4: 20),
    (field_0: 58; field_4: 24),
    (field_0: 55; field_4: 26),
    (field_0: 53; field_4: 28),
    (field_0: 50; field_4: 32)
  );

  // 0x5083E4
  upside_down_table: array[0..12] of TUpsideDownTableEntry = (
    (field_0: 0; field_4: 32),
    (field_0: 48; field_4: 32),
    (field_0: 49; field_4: 30),
    (field_0: 52; field_4: 26),
    (field_0: 55; field_4: 24),
    (field_0: 57; field_4: 22),
    (field_0: 60; field_4: 18),
    (field_0: 63; field_4: 16),
    (field_0: 65; field_4: 14),
    (field_0: 67; field_4: 12),
    (field_0: 70; field_4: 8),
    (field_0: 73; field_4: 6),
    (field_0: 75; field_4: 4)
  );

  // 0x50844C
  verticies: array[0..9] of TSTRUCT_51DA6C = (
    (field_0: 16;   offsets: (-1, -201); intensity: 0),
    (field_0: 48;   offsets: (-2, -2);   intensity: 0),
    (field_0: 960;  offsets: (0, 0);     intensity: 0),
    (field_0: 992;  offsets: (199, -1);  intensity: 0),
    (field_0: 1024; offsets: (198, 198); intensity: 0),
    (field_0: 1936; offsets: (200, 200); intensity: 0),
    (field_0: 1968; offsets: (399, 199); intensity: 0),
    (field_0: 2000; offsets: (398, 398); intensity: 0),
    (field_0: 2912; offsets: (400, 400); intensity: 0),
    (field_0: 2944; offsets: (599, 399); intensity: 0)
  );

  // 0x5084EC
  rightside_up_triangles: array[0..4] of TRightsideUpTriangle = (
    (field_0: 2; field_4: 3; field_8: 0),
    (field_0: 3; field_4: 4; field_8: 1),
    (field_0: 5; field_4: 6; field_8: 3),
    (field_0: 6; field_4: 7; field_8: 4),
    (field_0: 8; field_4: 9; field_8: 6)
  );

  // 0x508528
  upside_down_triangles: array[0..4] of TUpsideDownTriangle = (
    (field_0: 0; field_4: 3; field_8: 1),
    (field_0: 2; field_4: 5; field_8: 3),
    (field_0: 3; field_4: 6; field_8: 4),
    (field_0: 5; field_4: 8; field_8: 6),
    (field_0: 6; field_4: 9; field_8: 7)
  );

  // 0x665274
  intensity_map: array[0..3279] of Integer;

  // 0x6685B4
  dir_tile: array[0..1, 0..5] of Integer;

  // 0x6685E4
  tile_border: TRect;

  // 0x6685F4
  buf_rect: TRect;

  // 0x668604
  tile_grid_blocked: array[0..511] of Byte;

  // 0x668804
  tile_grid_occupied: array[0..511] of Byte;

  // 0x668A04
  tile_mask: array[0..511] of Byte;

  // 0x668C04
  tile_grid: array[0..32 * 16 - 1] of Byte;

  // 0x668E04
  tile_offy: Integer;

  // 0x668E08
  tile_offx: Integer;

  // 0x668E0C
  square_y_var: Integer;

  // 0x668E10
  square_x_var: Integer;

  // 0x668E14
  square_offx: Integer;

  // 0x668E18
  square_offy: Integer;

  // 0x668E1C
  buf_length: Integer;

  // 0x668E20
  blit: TTileWindowRefreshProc;

  // 0x668E24
  tile_x: Integer;

  // 0x668E28
  tile_y: Integer;

  // 0x668E2C
  buf_full: Integer;

  // 0x668E30
  buf_width: Integer;

  // 0x668E34
  square_size_var: Integer;

  // 0x668E38
  grid_width: Integer;

  // 0x668E3C
  squares: PPTileData;

  // 0x668E40
  buf_var: PByte;

  // 0x668E44
  grid_length: Integer;

  // 0x668E48
  grid_size: Integer;

  // 0x668E4C
  square_length_var: Integer;

  // 0x668E50
  square_width_var: Integer;

  // Bounds
  tile_bounds_rect: TRect;
  tile_bounds_left_off: Integer;
  tile_bounds_top_off: Integer;
  tile_bounds_right_off: Integer;
  tile_bounds_bottom_off: Integer;

// Helper macro
function TILE_IS_VALID(tile: Integer): Boolean; inline;
begin
  Result := (tile >= 0) and (tile < grid_size);
end;

// 0x49D880
function tile_init(a1: PPTileData; squareGridWidth, squareGridHeight,
  hexGridWidth, hexGridHeight: Integer; buffer: PByte;
  windowWidth, windowHeight, windowPitch: Integer;
  windowRefreshProc: TTileWindowRefreshProc): Integer;
var
  v11, v12, v13: Integer;
  v20, v21, v22, v23, v24, v25: Integer;
  executable: PAnsiChar;
begin
  square_width_var := squareGridWidth;
  squares := PPTileData(a1);
  grid_length := hexGridHeight;
  square_length_var := squareGridHeight;
  grid_width := hexGridWidth;
  dir_tile[0][0] := -1;
  dir_tile[0][4] := 1;
  dir_tile[1][1] := -1;
  grid_size := hexGridWidth * hexGridHeight;
  dir_tile[1][3] := 1;
  buf_var := buffer;
  buf_width := windowWidth;
  buf_length := windowHeight;
  buf_full := windowPitch;
  buf_rect.lrx := windowWidth - 1;
  square_size_var := squareGridHeight * squareGridWidth;
  buf_rect.lry := windowHeight - 1;
  buf_rect.ulx := 0;
  blit := windowRefreshProc;
  buf_rect.uly := 0;
  dir_tile[0][1] := hexGridWidth - 1;
  dir_tile[0][2] := hexGridWidth;
  show_grid := False;
  dir_tile[0][3] := hexGridWidth + 1;
  dir_tile[1][2] := hexGridWidth;
  dir_tile[0][5] := -hexGridWidth;
  dir_tile[1][0] := -hexGridWidth - 1;
  dir_tile[1][4] := 1 - hexGridWidth;
  dir_tile[1][5] := -hexGridWidth;

  v11 := 0;
  v12 := 0;
  repeat
    v13 := 64;
    repeat
      if v13 > v11 then
        tile_mask[v12] := 1
      else
        tile_mask[v12] := 0;
      Inc(v12);
      Dec(v13, 4);
    until v13 = 0;

    repeat
      if v13 > v11 then
        tile_mask[v12] := 2
      else
        tile_mask[v12] := 0;
      Inc(v12);
      Inc(v13, 4);
    until v13 = 64;

    Inc(v11, 16);
  until v11 = 64;

  v11 := 0;
  repeat
    v13 := 0;
    repeat
      tile_mask[v12] := 0;
      Inc(v12);
      Inc(v13);
    until v13 >= 32;
    Inc(v11);
  until v11 >= 8;

  v11 := 0;
  repeat
    v13 := 0;
    repeat
      if v13 > v11 then
        tile_mask[v12] := 0
      else
        tile_mask[v12] := 3;
      Inc(v12);
      Inc(v13, 4);
    until v13 = 64;

    v13 := 64;
    repeat
      if v13 > v11 then
        tile_mask[v12] := 0
      else
        tile_mask[v12] := 4;
      Inc(v12);
      Dec(v13, 4);
    until v13 = 0;

    Inc(v11, 16);
  until v11 = 64;

  buf_fill(@tile_grid[0], 32, 16, 32, 0);
  draw_line(@tile_grid[0], 32, 16, 0, 31, 4, colorTable[4228]);
  draw_line(@tile_grid[0], 32, 31, 4, 31, 12, colorTable[4228]);
  draw_line(@tile_grid[0], 32, 31, 12, 16, 15, colorTable[4228]);
  draw_line(@tile_grid[0], 32, 0, 12, 16, 15, colorTable[4228]);
  draw_line(@tile_grid[0], 32, 0, 4, 0, 12, colorTable[4228]);
  draw_line(@tile_grid[0], 32, 16, 0, 0, 4, colorTable[4228]);

  buf_fill(@tile_grid_occupied[0], 32, 16, 32, 0);
  draw_line(@tile_grid_occupied[0], 32, 16, 0, 31, 4, colorTable[31]);
  draw_line(@tile_grid_occupied[0], 32, 31, 4, 31, 12, colorTable[31]);
  draw_line(@tile_grid_occupied[0], 32, 31, 12, 16, 15, colorTable[31]);
  draw_line(@tile_grid_occupied[0], 32, 0, 12, 16, 15, colorTable[31]);
  draw_line(@tile_grid_occupied[0], 32, 0, 4, 0, 12, colorTable[31]);
  draw_line(@tile_grid_occupied[0], 32, 16, 0, 0, 4, colorTable[31]);

  buf_fill(@tile_grid_blocked[0], 32, 16, 32, 0);
  draw_line(@tile_grid_blocked[0], 32, 16, 0, 31, 4, colorTable[31744]);
  draw_line(@tile_grid_blocked[0], 32, 31, 4, 31, 12, colorTable[31744]);
  draw_line(@tile_grid_blocked[0], 32, 31, 12, 16, 15, colorTable[31744]);
  draw_line(@tile_grid_blocked[0], 32, 0, 12, 16, 15, colorTable[31744]);
  draw_line(@tile_grid_blocked[0], 32, 0, 4, 0, 12, colorTable[31744]);
  draw_line(@tile_grid_blocked[0], 32, 16, 0, 0, 4, colorTable[31744]);

  for v20 := 0 to 15 do
  begin
    v21 := v20 * 32;
    v22 := 31;
    v23 := v21 + 31;

    if tile_grid_blocked[v23] = 0 then
    begin
      repeat
        Dec(v22);
        Dec(v23);
      until (v22 <= 0) or (tile_grid_blocked[v23] <> 0);
    end;

    v24 := v21;
    v25 := 0;
    if tile_grid_blocked[v21] = 0 then
    begin
      repeat
        Inc(v25);
        Inc(v24);
      until (v25 >= 32) or (tile_grid_blocked[v24] <> 0);
    end;

    draw_line(@tile_grid_blocked[0], 32, v25, v20, v22, v20, colorTable[31744]);
  end;

  // In order to calculate scroll borders correctly we need to pretend we're
  // at original resolution.
  buf_width := ORIGINAL_ISO_WINDOW_WIDTH;
  buf_length := ORIGINAL_ISO_WINDOW_HEIGHT;

  tile_set_center(hexGridWidth * (hexGridHeight div 2) + hexGridWidth div 2,
    TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS);
  tile_set_border(windowWidth, windowHeight, hexGridWidth, hexGridHeight);

  // Restore actual window size and set center one more time
  buf_width := windowWidth;
  buf_length := windowHeight;

  tile_set_center(hexGridWidth * (hexGridHeight div 2) + hexGridWidth div 2,
    TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS);

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_EXECUTABLE_KEY, @executable);
  if compat_stricmp(executable, 'mapper') = 0 then
    tile_refresh_proc := @refresh_mapper
  else
    tile_refresh_proc := @refresh_game;

  Result := 0;
end;

// 0x49DDC8
procedure tile_set_border(windowWidth, windowHeight, hexGridWidth, hexGridHeight: Integer);
var
  v1, v2: Integer;
begin
  v1 := tile_num(-320, -240, 0);
  v2 := tile_num(-320, ORIGINAL_ISO_WINDOW_HEIGHT + 240, 0);

  tile_border.ulx := abs(hexGridWidth - 1 - v2 mod hexGridWidth - tile_x) + 6;
  tile_border.uly := abs(tile_y - v1 div hexGridWidth) + 7;
  tile_border.lrx := hexGridWidth - tile_border.ulx - 1;
  tile_border.lry := hexGridHeight - tile_border.uly - 1;

  if (tile_border.ulx and 1) = 0 then
    Inc(tile_border.ulx);

  if (tile_border.lrx and 1) = 0 then
    Dec(tile_border.ulx);

  borderInitialized := True;
end;

// 0x49DE80
procedure tile_reset;
begin
end;

// 0x49DE80
procedure tile_exit;
begin
end;

// 0x49DE8C
procedure tile_disable_refresh;
begin
  refresh_enabled := False;
end;

// 0x49DE98
procedure tile_enable_refresh;
begin
  refresh_enabled := True;
end;

// 0x49DEA4
procedure tile_refresh_rect(rect: PRect; elevation: Integer);
begin
  if refresh_enabled then
  begin
    if elevation = map_elevation then
      tile_refresh_proc(rect, elevation);
  end;
end;

// 0x49DEBC
procedure tile_refresh_display;
begin
  if refresh_enabled then
    tile_refresh_proc(@buf_rect, map_elevation);
end;

// 0x49DEDC
function tile_set_center(tile, flags: Integer): Integer;
var
  new_tile_x, new_tile_y: Integer;
  tileScreenX, tileScreenY: Integer;
  dudeScreenX, dudeScreenY: Integer;
  dx, dy: Integer;
begin
  if not TILE_IS_VALID(tile) then
  begin
    Result := -1;
    Exit;
  end;

  if (flags and TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS) = 0 then
  begin
    if scroll_limiting_on then
    begin
      tile_coord(tile, @tileScreenX, @tileScreenY, map_elevation);
      tile_coord(obj_dude^.tile, @dudeScreenX, @dudeScreenY, map_elevation);

      dx := abs(dudeScreenX - tileScreenX);
      dy := abs(dudeScreenY - tileScreenY);

      if (dx > abs(dudeScreenX - tile_offx)) or
         (dy > abs(dudeScreenY - tile_offy)) then
      begin
        if (dx >= 480) or (dy >= 400) then
        begin
          Result := -1;
          Exit;
        end;
      end;
    end;

    if scroll_blocking_on then
    begin
      if obj_scroll_blocking_at(tile, map_elevation) = 0 then
      begin
        Result := -1;
        Exit;
      end;
    end;
  end;

  new_tile_x := grid_width - 1 - tile mod grid_width;
  new_tile_y := tile div grid_width;

  if borderInitialized then
  begin
    if (new_tile_x <= tile_border.ulx) or (new_tile_x >= tile_border.lrx) or
       (new_tile_y <= tile_border.uly) or (new_tile_y >= tile_border.lry) then
    begin
      Result := -1;
      Exit;
    end;
  end;

  tile_y := new_tile_y;
  tile_offx := (buf_width - 32) div 2;
  tile_x := new_tile_x;
  tile_offy := (buf_length - 16) div 2;

  if (tile_x and 1) <> 0 then
  begin
    Dec(tile_x);
    Dec(tile_offx, 32);
  end;

  square_x_var := tile_x div 2;
  square_y_var := tile_y div 2;
  square_offx := tile_offx - 16;
  square_offy := tile_offy - 2;

  if (tile_y and 1) <> 0 then
  begin
    Dec(square_offy, 12);
    Dec(square_offx, 16);
  end;

  tile_center_tile := tile;

  // CE: Updates bounds screen coordinates.
  tile_update_bounds_rect;

  if (flags and TILE_SET_CENTER_REFRESH_WINDOW) <> 0 then
    tile_refresh_display;

  Result := 0;
end;

// 0x49E138
procedure refresh_mapper(rect: PRect; elevation: Integer);
var
  rectToUpdate: TRect;
begin
  if rect_inside_bound(rect, @buf_rect, @rectToUpdate) = -1 then
    Exit;

  buf_fill(buf_var + buf_full * rectToUpdate.uly + rectToUpdate.ulx,
    rectToUpdate.lrx - rectToUpdate.ulx + 1,
    rectToUpdate.lry - rectToUpdate.uly + 1,
    buf_full,
    0);

  square_render_floor(@rectToUpdate, elevation);
  grid_render(@rectToUpdate, elevation);
  obj_render_pre_roof(@rectToUpdate, elevation);
  square_render_roof(@rectToUpdate, elevation);
  obj_render_post_roof(@rectToUpdate, elevation);
  blit(@rectToUpdate);
end;

// 0x49E1CC
procedure refresh_game(rect: PRect; elevation: Integer);
var
  rectToUpdate: TRect;
begin
  if rect_inside_bound(rect, @buf_rect, @rectToUpdate) = -1 then
    Exit;

  buf_fill(buf_var + buf_full * rectToUpdate.uly + rectToUpdate.ulx,
    rectGetWidth(@rectToUpdate),
    rectGetHeight(@rectToUpdate),
    buf_full,
    0);

  square_render_floor(@rectToUpdate, elevation);
  obj_render_pre_roof(@rectToUpdate, elevation);
  square_render_roof(@rectToUpdate, elevation);
  bounds_render(@rectToUpdate, elevation);
  obj_render_post_roof(@rectToUpdate, elevation);
  blit(@rectToUpdate);
end;

// 0x49E218
procedure tile_toggle_roof(a1: Integer);
begin
  show_roof := not show_roof;

  if a1 <> 0 then
    tile_refresh_display;
end;

// 0x49E250
function tile_roof_visible: Integer;
begin
  if show_roof then
    Result := 1
  else
    Result := 0;
end;

// 0x49E258
function tile_coord(tile: Integer; screenX, screenY: PInteger; elevation: Integer): Integer;
var
  v3, v4, v5, v6: Integer;
begin
  if not TILE_IS_VALID(tile) then
  begin
    Result := -1;
    Exit;
  end;

  v3 := grid_width - 1 - tile mod grid_width;
  v4 := tile div grid_width;

  screenX^ := tile_offx;
  screenY^ := tile_offy;

  v5 := (v3 - tile_x) div -2;
  screenX^ := screenX^ + 48 * ((v3 - tile_x) div 2);
  screenY^ := screenY^ + 12 * v5;

  if (v3 and 1) <> 0 then
  begin
    if v3 <= tile_x then
    begin
      screenX^ := screenX^ - 16;
      screenY^ := screenY^ + 12;
    end
    else
      screenX^ := screenX^ + 32;
  end;

  v6 := v4 - tile_y;
  screenX^ := screenX^ + 16 * v6;
  screenY^ := screenY^ + 12 * v6;

  Result := 0;
end;

// 0x49E354
function tile_num(screenX, screenY, elevation: Integer; ignoreBounds: Boolean = False): Integer;
var
  v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12: Integer;
begin
  v2 := screenY - tile_offy;
  if v2 >= 0 then
    v3 := v2 div 12
  else
    v3 := (v2 + 1) div 12 - 1;

  v4 := screenX - tile_offx - 16 * v3;
  v5 := v2 - 12 * v3;

  if v4 >= 0 then
    v6 := v4 div 64
  else
    v6 := (v4 + 1) div 64 - 1;

  v7 := v6 + v3;
  v8 := v4 - (v6 * 64);
  v9 := 2 * v6;

  if v8 >= 32 then
  begin
    Dec(v8, 32);
    Inc(v9);
  end;

  v10 := tile_y + v7;
  v11 := tile_x + v9;

  case tile_mask[32 * v5 + v8] of
    2:
    begin
      Inc(v11);
      if (v11 and 1) <> 0 then
        Dec(v10);
    end;
    1:
      Dec(v10);
    3:
    begin
      Dec(v11);
      if (v11 and 1) = 0 then
        Inc(v10);
    end;
    4:
      Inc(v10);
  end;

  v12 := grid_width - 1 - v11;
  if (v12 >= 0) and (v12 < grid_width) and (v10 >= 0) and (v10 < grid_length) then
  begin
    Result := grid_width * v10 + v12;
    Exit;
  end;

  if ignoreBounds then
  begin
    Result := grid_width * v10 + v12;
    Exit;
  end;

  Result := -1;
end;

// 0x49E45C
function tile_dist(tile1, tile2: Integer): Integer;
var
  tile: Integer;
  distance: Integer;
  parity: Integer;
  dir: Integer;
begin
  tile := tile1;
  distance := 0;

  while tile <> tile2 do
  begin
    parity := (tile mod grid_width) and 1;
    dir := tile_dir(tile, tile2);
    tile := tile + dir_tile[parity][dir];
    Inc(distance);
  end;

  Result := distance;
end;

// 0x49E4A0
function tile_in_front_of(tile1, tile2: Integer): Boolean;
var
  x1, y1, x2, y2: Integer;
  dx, dy: Integer;
begin
  tile_coord(tile1, @x1, @y1, 0);
  tile_coord(tile2, @x2, @y2, 0);

  dx := x2 - x1;
  dy := y2 - y1;

  Result := Double(dx) <= Double(dy) * -4.0;
end;

// 0x49E508
function tile_to_right_of(tile1, tile2: Integer): Boolean;
var
  x1, y1, x2, y2: Integer;
  dx, dy: Integer;
begin
  tile_coord(tile1, @x1, @y1, 0);
  tile_coord(tile2, @x2, @y2, 0);

  dx := x2 - x1;
  dy := y2 - y1;

  Result := Double(dx) <= Double(dy) * 1.3333333333333335;
end;

// 0x49E570
function tile_num_in_direction(tile, rotation, distance: Integer): Integer;
var
  newTile: Integer;
  index: Integer;
  parity: Integer;
begin
  newTile := tile;
  for index := 0 to distance - 1 do
  begin
    if tile_on_edge(newTile) then
      Break;
    parity := (newTile mod grid_width) and 1;
    newTile := newTile + dir_tile[parity][rotation];
  end;
  Result := newTile;
end;

// 0x49E5C0
function tile_dir(tile1, tile2: Integer): Integer;
var
  x1, y1, x2, y2: Integer;
  dy: Integer;
  v6, v7: Integer;
begin
  tile_coord(tile1, @x1, @y1, 0);
  tile_coord(tile2, @x2, @y2, 0);

  dy := y2 - y1;
  x2 := x2 - x1;
  y2 := y2 - y1;

  if x2 <> 0 then
  begin
    v6 := Trunc(ArcTan2(Double(-dy), Double(x2)) * 180.0 * 0.3183098862851122);
    v7 := 360 - (v6 + 180) - 90;
    if v7 < 0 then
      Inc(v7, 360);

    v7 := v7 div 60;

    if v7 >= ROTATION_COUNT_CONST then
      v7 := ROTATION_NW_CONST;

    Result := v7;
    Exit;
  end;

  if dy < 0 then
    Result := ROTATION_NE_CONST
  else
    Result := ROTATION_SE_CONST;
end;

// 0x49E680
function tile_num_beyond(from_, to_, distance: Integer): Integer;
var
  fromX, fromY, toX, toY: Integer;
  deltaX, deltaY: Integer;
  v27, v26: Integer;
  stepX, stepY: Integer;
  v28: Integer;
  tileX, tileY: Integer;
  v6: Integer;
  middle: Integer;
  tile: Integer;
begin
  if (distance <= 0) or (from_ = to_) then
  begin
    Result := from_;
    Exit;
  end;

  tile_coord(from_, @fromX, @fromY, 0);
  Inc(fromX, 16);
  Inc(fromY, 8);

  tile_coord(to_, @toX, @toY, 0);
  Inc(toX, 16);
  Inc(toY, 8);

  deltaX := toX - fromX;
  deltaY := toY - fromY;

  v27 := 2 * abs(deltaX);

  stepX := 0;
  if deltaX > 0 then
    stepX := 1
  else if deltaX < 0 then
    stepX := -1;

  v26 := 2 * abs(deltaY);

  stepY := 0;
  if deltaY > 0 then
    stepY := 1
  else if deltaY < 0 then
    stepY := -1;

  v28 := from_;
  tileX := fromX;
  tileY := fromY;

  v6 := 0;

  if v27 > v26 then
  begin
    middle := v26 - v27 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, 0);
      if tile <> v28 then
      begin
        Inc(v6);
        if (v6 = distance) or tile_on_edge(tile) then
        begin
          Result := tile;
          Exit;
        end;
        v28 := tile;
      end;

      if middle >= 0 then
      begin
        Dec(middle, v27);
        Inc(tileY, stepY);
      end;

      Inc(middle, v26);
      Inc(tileX, stepX);
    end;
  end
  else
  begin
    middle := v27 - v26 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, 0);
      if tile <> v28 then
      begin
        Inc(v6);
        if (v6 = distance) or tile_on_edge(tile) then
        begin
          Result := tile;
          Exit;
        end;
        v28 := tile;
      end;

      if middle >= 0 then
      begin
        Dec(middle, v26);
        Inc(tileX, stepX);
      end;

      Inc(middle, v27);
      Inc(tileY, stepY);
    end;
  end;

  // Should be unreachable
  Result := from_;
end;

// 0x49E814
function tile_on_edge(tile: Integer): Boolean;
begin
  if not TILE_IS_VALID(tile) then
  begin
    Result := False;
    Exit;
  end;

  if tile < grid_width then
  begin
    Result := True;
    Exit;
  end;

  if tile >= grid_size - grid_width then
  begin
    Result := True;
    Exit;
  end;

  if tile mod grid_width = 0 then
  begin
    Result := True;
    Exit;
  end;

  if tile mod grid_width = grid_width - 1 then
  begin
    Result := True;
    Exit;
  end;

  Result := False;
end;

// 0x49E874
procedure tile_enable_scroll_blocking;
begin
  scroll_blocking_on := True;
end;

// 0x49E880
procedure tile_disable_scroll_blocking;
begin
  scroll_blocking_on := False;
end;

// 0x49E88C
function tile_get_scroll_blocking: Boolean;
begin
  Result := scroll_blocking_on;
end;

// 0x49E894
procedure tile_enable_scroll_limiting;
begin
  scroll_limiting_on := True;
end;

// 0x49E8A0
procedure tile_disable_scroll_limiting;
begin
  scroll_limiting_on := False;
end;

// 0x49E8AC
function tile_get_scroll_limiting: Boolean;
begin
  Result := scroll_limiting_on;
end;

// 0x49E8B4
function square_coord(squareTile: Integer; coordX, coordY: PInteger; elevation: Integer): Integer;
var
  v5, v6, v7, v8, v9: Integer;
begin
  if (squareTile < 0) or (squareTile >= square_size_var) then
  begin
    Result := -1;
    Exit;
  end;

  v5 := square_width_var - 1 - squareTile mod square_width_var;
  v6 := squareTile div square_width_var;
  v7 := square_x_var;

  coordX^ := square_offx;
  coordY^ := square_offy;

  v8 := v5 - v7;
  coordX^ := coordX^ + 48 * v8;
  coordY^ := coordY^ - 12 * v8;

  v9 := v6 - square_y_var;
  coordX^ := coordX^ + 32 * v9;
  coordY^ := coordY^ + 24 * v9;

  Result := 0;
end;

// 0x49E954
function square_coord_roof(squareTile: Integer; screenX, screenY: PInteger; elevation: Integer): Integer;
var
  v5, v6, v7, v8, v9, v10: Integer;
begin
  if (squareTile < 0) or (squareTile >= square_size_var) then
  begin
    Result := -1;
    Exit;
  end;

  v5 := square_width_var - 1 - squareTile mod square_width_var;
  v6 := squareTile div square_width_var;
  v7 := square_x_var;
  screenX^ := square_offx;
  screenY^ := square_offy;

  v8 := v5 - v7;
  screenX^ := screenX^ + 48 * v8;
  screenY^ := screenY^ - 12 * v8;

  v9 := v6 - square_y_var;
  screenX^ := screenX^ + 32 * v9;
  v10 := 24 * v9 + screenY^;
  screenY^ := v10;
  screenY^ := v10 - 96;

  Result := 0;
end;

// 0x49E9F8
function square_num(screenX, screenY, elevation: Integer): Integer;
var
  coordX, coordY: Integer;
begin
  square_xy(screenX, screenY, elevation, @coordX, @coordY);

  if (coordX >= 0) and (coordX < square_width_var) and
     (coordY >= 0) and (coordY < square_length_var) then
  begin
    Result := coordX + square_width_var * coordY;
    Exit;
  end;

  Result := -1;
end;

// 0x49EA40
function square_num_roof(screenX, screenY, elevation: Integer): Integer;
var
  x, y: Integer;
begin
  square_xy_roof(screenX, screenY, elevation, @x, @y);

  if (x >= 0) and (x < square_width_var) and
     (y >= 0) and (y < square_length_var) then
  begin
    Result := x + square_width_var * y;
    Exit;
  end;

  Result := -1;
end;

// 0x49EA88
procedure square_xy(screenX, screenY, elevation: Integer; coordX, coordY: PInteger);
var
  v4, v5, v6, v8: Integer;
begin
  v4 := screenX - square_offx;
  v5 := screenY - square_offy - 12;
  v6 := 3 * v4 - 4 * v5;
  if v6 >= 0 then
    coordX^ := v6 div 192
  else
    coordX^ := (v6 + 1) div 192 - 1;

  v8 := 4 * v5 + v4;
  if v8 >= 0 then
    coordY^ := v8 div 128
  else
    coordY^ := (v8 + 1) div 128 - 1;

  coordX^ := coordX^ + square_x_var;
  coordY^ := coordY^ + square_y_var;

  coordX^ := square_width_var - 1 - coordX^;
end;

// 0x49EB30
procedure square_xy_roof(screenX, screenY, elevation: Integer; coordX, coordY: PInteger);
var
  v4, v5, v6, v8: Integer;
begin
  v4 := screenX - square_offx;
  v5 := screenY + 96 - square_offy - 12;
  v6 := 3 * v4 - 4 * v5;

  if v6 >= 0 then
    coordX^ := v6 div 192
  else
    coordX^ := (v6 + 1) div 192 - 1;

  v8 := 4 * v5 + v4;
  if v8 >= 0 then
    coordY^ := v8 div 128
  else
    coordY^ := (v8 + 1) div 128 - 1;

  coordX^ := coordX^ + square_x_var;
  coordY^ := coordY^ + square_y_var;

  coordX^ := square_width_var - 1 - coordX^;
end;

// 0x49EBDC
procedure square_render_roof(rect: PRect; elevation: Integer);
var
  temp: Integer;
  minY, minX, maxX, maxY: Integer;
  constrainedRect: TRect;
  light: Integer;
  baseSquareTile: Integer;
  y, x: Integer;
  squareTile: Integer;
  frmId: Integer;
  fid: Integer;
  scrX, scrY: Integer;
  sqPtr: PTileData;
begin
  if not show_roof then
    Exit;

  constrainedRect := rect^;
  if tile_inside_bound(@constrainedRect) <> 0 then
    Exit;

  square_xy_roof(constrainedRect.ulx, constrainedRect.uly, elevation, @temp, @minY);
  square_xy_roof(constrainedRect.lrx, constrainedRect.uly, elevation, @minX, @temp);
  square_xy_roof(constrainedRect.ulx, constrainedRect.lry, elevation, @maxX, @temp);
  square_xy_roof(constrainedRect.lrx, constrainedRect.lry, elevation, @temp, @maxY);

  if minX < 0 then
    minX := 0;

  if minX >= square_width_var then
    minX := square_width_var - 1;

  if minY < 0 then
    minY := 0;

  // FIXME: Probably a bug - testing X, then changing Y.
  if minX >= square_length_var then
    minY := square_length_var - 1;

  light := light_get_ambient;

  sqPtr := PPTileData(squares)[elevation];
  baseSquareTile := square_width_var * minY;

  for y := minY to maxY do
  begin
    for x := minX to maxX do
    begin
      squareTile := baseSquareTile + x;
      frmId := sqPtr^.field_0[squareTile];
      frmId := frmId shr 16;
      if (((frmId and $F000) shr 12) and $01) = 0 then
      begin
        fid := art_id(OBJ_TYPE_TILE, frmId and $FFF, 0, 0, 0);
        if fid <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
        begin
          square_coord_roof(squareTile, @scrX, @scrY, elevation);
          roof_draw(fid, scrX, scrY, @constrainedRect, light);
        end;
      end;
    end;
    Inc(baseSquareTile, square_width_var);
  end;
end;

// 0x49EDC0
procedure roof_fill_on(x, y, elevation: Integer);
var
  squareTileIndex: Integer;
  squareTile: Integer;
  roofVal: Integer;
  id: Integer;
  flag: Integer;
  sqPtr: PTileData;
begin
  if (x >= 0) and (x < square_width_var) and (y >= 0) and (y < square_length_var) then
  begin
    sqPtr := PPTileData(squares)[elevation];
    squareTileIndex := square_width_var * y + x;
    squareTile := sqPtr^.field_0[squareTileIndex];
    roofVal := (squareTile shr 16) and $FFFF;

    id := roofVal and $FFF;
    if art_id(OBJ_TYPE_TILE, id, 0, 0, 0) <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
    begin
      flag := (roofVal and $F000) shr 12;
      if (flag and $01) <> 0 then
      begin
        flag := flag and (not $01);

        sqPtr^.field_0[squareTileIndex] := (squareTile and $FFFF) or (((flag shl 12) or id) shl 16);

        roof_fill_on(x - 1, y, elevation);
        roof_fill_on(x + 1, y, elevation);
        roof_fill_on(x, y - 1, elevation);
        roof_fill_on(x, y + 1, elevation);
      end;
    end;
  end;
end;

// 0x49EEC4
procedure tile_fill_roof(x, y, elevation: Integer; flag: Boolean);
begin
  if flag then
    roof_fill_on(x, y, elevation)
  else
    roof_fill_off(x, y, elevation);
end;

// 0x49EECC
procedure roof_fill_off(x, y, elevation: Integer);
var
  squareTileIndex: Integer;
  squareTile: Integer;
  roofVal: Integer;
  id: Integer;
  flag: Integer;
  sqPtr: PTileData;
begin
  if (x >= 0) and (x < square_width_var) and (y >= 0) and (y < square_length_var) then
  begin
    sqPtr := PPTileData(squares)[elevation];
    squareTileIndex := square_width_var * y + x;
    squareTile := sqPtr^.field_0[squareTileIndex];
    roofVal := (squareTile shr 16) and $FFFF;

    id := roofVal and $FFF;
    if art_id(OBJ_TYPE_TILE, id, 0, 0, 0) <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
    begin
      flag := (roofVal and $F000) shr 12;
      if (flag and $03) = 0 then
      begin
        flag := flag or $01;

        sqPtr^.field_0[squareTileIndex] := (squareTile and $FFFF) or (((flag shl 12) or id) shl 16);

        roof_fill_off(x - 1, y, elevation);
        roof_fill_off(x + 1, y, elevation);
        roof_fill_off(x, y - 1, elevation);
        roof_fill_off(x, y + 1, elevation);
      end;
    end;
  end;
end;

// 0x49EFD0
procedure roof_draw(fid, x, y: Integer; rect: PRect; light: Integer);
var
  tileFrmHandle: PCacheEntry;
  tileFrm: PArt;
  tileWidth, tileHeight: Integer;
  tileRect: TRect;
  tileFrmBuffer: PByte;
  eggFrmHandle: PCacheEntry;
  eggFrm: PArt;
  eggWidth, eggHeight: Integer;
  eggScreenX, eggScreenY: Integer;
  eggRect: TRect;
  intersectedRect: TRect;
  rects: array[0..3] of TRect;
  i: Integer;
  cr: PRect;
  eggBuf: PByte;
begin
  tileFrm := art_ptr_lock(fid, @tileFrmHandle);
  if tileFrm = nil then
    Exit;

  tileWidth := art_frame_width(tileFrm, 0, 0);
  tileHeight := art_frame_length(tileFrm, 0, 0);

  tileRect.ulx := x;
  tileRect.uly := y;
  tileRect.lrx := x + tileWidth - 1;
  tileRect.lry := y + tileHeight - 1;

  if rect_inside_bound(@tileRect, rect, @tileRect) = 0 then
  begin
    tileFrmBuffer := art_frame_data(tileFrm, 0, 0);
    tileFrmBuffer := tileFrmBuffer + tileWidth * (tileRect.uly - y) + (tileRect.ulx - x);

    eggFrm := art_ptr_lock(obj_egg^.fid, @eggFrmHandle);
    if eggFrm <> nil then
    begin
      eggWidth := art_frame_width(eggFrm, 0, 0);
      eggHeight := art_frame_length(eggFrm, 0, 0);

      tile_coord(obj_egg^.tile, @eggScreenX, @eggScreenY, obj_egg^.elevation);

      Inc(eggScreenX, 16);
      Inc(eggScreenY, 8);

      Inc(eggScreenX, eggFrm^.xOffsets[0]);
      Inc(eggScreenY, eggFrm^.yOffsets[0]);

      Inc(eggScreenX, obj_egg^.x);
      Inc(eggScreenY, obj_egg^.y);

      eggRect.ulx := eggScreenX - eggWidth div 2;
      eggRect.uly := eggScreenY - eggHeight + 1;
      eggRect.lrx := eggRect.ulx + eggWidth - 1;
      eggRect.lry := eggScreenY;

      obj_egg^.sx := eggRect.ulx;
      obj_egg^.sy := eggRect.uly;

      if rect_inside_bound(@eggRect, @tileRect, @intersectedRect) = 0 then
      begin
        rects[0].ulx := tileRect.ulx;
        rects[0].uly := tileRect.uly;
        rects[0].lrx := tileRect.lrx;
        rects[0].lry := intersectedRect.uly - 1;

        rects[1].ulx := tileRect.ulx;
        rects[1].uly := intersectedRect.uly;
        rects[1].lrx := intersectedRect.ulx - 1;
        rects[1].lry := intersectedRect.lry;

        rects[2].ulx := intersectedRect.lrx + 1;
        rects[2].uly := intersectedRect.uly;
        rects[2].lrx := tileRect.lrx;
        rects[2].lry := intersectedRect.lry;

        rects[3].ulx := tileRect.ulx;
        rects[3].uly := intersectedRect.lry + 1;
        rects[3].lrx := tileRect.lrx;
        rects[3].lry := tileRect.lry;

        for i := 0 to 3 do
        begin
          cr := @rects[i];
          if (cr^.ulx <= cr^.lrx) and (cr^.uly <= cr^.lry) then
          begin
            dark_trans_buf_to_buf(
              tileFrmBuffer + tileWidth * (cr^.uly - tileRect.uly) + (cr^.ulx - tileRect.ulx),
              cr^.lrx - cr^.ulx + 1,
              cr^.lry - cr^.uly + 1,
              tileWidth,
              buf_var,
              cr^.ulx,
              cr^.uly,
              buf_full,
              light);
          end;
        end;

        eggBuf := art_frame_data(eggFrm, 0, 0);
        intensity_mask_buf_to_buf(
          tileFrmBuffer + tileWidth * (intersectedRect.uly - tileRect.uly) + (intersectedRect.ulx - tileRect.ulx),
          intersectedRect.lrx - intersectedRect.ulx + 1,
          intersectedRect.lry - intersectedRect.uly + 1,
          tileWidth,
          buf_var + buf_full * intersectedRect.uly + intersectedRect.ulx,
          buf_full,
          eggBuf + eggWidth * (intersectedRect.uly - eggRect.uly) + (intersectedRect.ulx - eggRect.ulx),
          eggWidth,
          light);
      end
      else
      begin
        dark_trans_buf_to_buf(tileFrmBuffer,
          tileRect.lrx - tileRect.ulx + 1,
          tileRect.lry - tileRect.uly + 1,
          tileWidth,
          buf_var,
          tileRect.ulx,
          tileRect.uly,
          buf_full,
          light);
      end;

      art_ptr_unlock(eggFrmHandle);
    end;
  end;

  art_ptr_unlock(tileFrmHandle);
end;

// 0x49F3EC
procedure square_render_floor(rect: PRect; elevation: Integer);
var
  minY, maxX, maxY, minX: Integer;
  temp: Integer;
  constrainedRect: TRect;
  baseSquareTile: Integer;
  y, x: Integer;
  squareTile: Integer;
  frmId: Integer;
  tileScreenX, tileScreenY: Integer;
  fid: Integer;
  sqPtr: PTileData;
begin
  constrainedRect := rect^;
  if tile_inside_bound(@constrainedRect) <> 0 then
    Exit;

  square_xy(constrainedRect.ulx, constrainedRect.uly, elevation, @temp, @minY);
  square_xy(constrainedRect.lrx, constrainedRect.uly, elevation, @minX, @temp);
  square_xy(constrainedRect.ulx, constrainedRect.lry, elevation, @maxX, @temp);
  square_xy(constrainedRect.lrx, constrainedRect.lry, elevation, @temp, @maxY);

  if minX < 0 then
    minX := 0;

  if minX >= square_width_var then
    minX := square_width_var - 1;

  if minY < 0 then
    minY := 0;

  if minX >= square_length_var then
    minY := square_length_var - 1;

  light_get_ambient;

  sqPtr := PPTileData(squares)[elevation];
  baseSquareTile := square_width_var * minY;

  for y := minY to maxY do
  begin
    for x := minX to maxX do
    begin
      squareTile := baseSquareTile + x;
      frmId := sqPtr^.field_0[squareTile];
      if (((frmId and $F000) shr 12) and $01) = 0 then
      begin
        square_coord(squareTile, @tileScreenX, @tileScreenY, elevation);
        fid := art_id(OBJ_TYPE_TILE, frmId and $FFF, 0, 0, 0);
        floor_draw(fid, tileScreenX, tileScreenY, @constrainedRect);
      end;
    end;
    Inc(baseSquareTile, square_width_var);
  end;
end;

// 0x49F5B4
function square_roof_intersect(x, y, elevation: Integer): Boolean;
var
  tileX, tileY: Integer;
  ptr: PTileData;
  idx: Integer;
  upper: Integer;
  fid: Integer;
  handle: PCacheEntry;
  art: PArt;
  data: PByte;
  v18, v17: Integer;
  width: Integer;
begin
  Result := False;

  if not show_roof then
    Exit;

  square_xy_roof(x, y, elevation, @tileX, @tileY);

  ptr := PPTileData(squares)[elevation];
  idx := square_width_var * tileY + tileX;
  upper := ptr^.field_0[idx] shr 16;
  fid := art_id(OBJ_TYPE_TILE, upper and $FFF, 0, 0, 0);
  if fid <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
  begin
    if (((upper and $F000) shr 12) and 1) = 0 then
    begin
      fid := art_id(OBJ_TYPE_TILE, upper and $FFF, 0, 0, 0);
      art := art_ptr_lock(fid, @handle);
      if art <> nil then
      begin
        data := art_frame_data(art, 0, 0);
        if data <> nil then
        begin
          square_coord_roof(idx, @v18, @v17, elevation);

          width := art_frame_width(art, 0, 0);
          if data[width * (y - v17) + x - v18] <> 0 then
            Result := True;
        end;
        art_ptr_unlock(handle);
      end;
    end;
  end;
end;

// 0x49F900
procedure grid_toggle;
begin
  show_grid := not show_grid;
end;

// 0x49F918
procedure grid_on;
begin
  show_grid := True;
end;

// 0x49F924
procedure grid_off;
begin
  show_grid := False;
end;

// 0x49F930
function get_grid_flag: Integer;
begin
  if show_grid then
    Result := 1
  else
    Result := 0;
end;

// 0x49F938
procedure grid_render(rect: PRect; elevation: Integer);
var
  y, x: Integer;
  tile: Integer;
begin
  if not show_grid then
    Exit;

  y := rect^.uly - 12;
  while y < rect^.lry + 12 do
  begin
    x := rect^.ulx - 32;
    while x < rect^.lrx + 32 do
    begin
      tile := tile_num(x, y, elevation);
      draw_grid(tile, elevation, rect);
      Inc(x, 16);
    end;
    Inc(y, 6);
  end;
end;

// 0x49F990
procedure grid_draw(tile, elevation: Integer);
var
  rect: TRect;
begin
  tile_coord(tile, @rect.ulx, @rect.uly, elevation);

  rect.lrx := rect.ulx + 32 - 1;
  rect.lry := rect.uly + 16 - 1;
  if rect_inside_bound(@rect, @buf_rect, @rect) <> -1 then
  begin
    draw_grid(tile, elevation, @rect);
    blit(@rect);
  end;
end;

// 0x49F9EC
procedure draw_grid(tile, elevation: Integer; rect: PRect);
var
  x, y: Integer;
  r: TRect;
begin
  if tile = -1 then
    Exit;

  tile_coord(tile, @x, @y, elevation);

  r.ulx := x;
  r.uly := y;
  r.lrx := x + 32 - 1;
  r.lry := y + 16 - 1;

  if rect_inside_bound(@r, rect, @r) = -1 then
    Exit;

  if obj_blocking_at(nil, tile, elevation) <> nil then
  begin
    trans_buf_to_buf(@tile_grid_blocked[32 * (r.uly - y) + (r.ulx - x)],
      r.lrx - r.ulx + 1,
      r.lry - r.uly + 1,
      32,
      buf_var + buf_full * r.uly + r.ulx,
      buf_full);
    Exit;
  end;

  if obj_occupied(tile, elevation) then
  begin
    trans_buf_to_buf(@tile_grid_occupied[32 * (r.uly - y) + (r.ulx - x)],
      r.lrx - r.ulx + 1,
      r.lry - r.uly + 1,
      32,
      buf_var + buf_full * r.uly + r.ulx,
      buf_full);
    Exit;
  end;

  translucent_trans_buf_to_buf(@tile_grid_occupied[32 * (r.uly - y) + (r.ulx - x)],
    r.lrx - r.ulx + 1,
    r.lry - r.uly + 1,
    32,
    buf_var + buf_full * r.uly + r.ulx,
    0,
    0,
    buf_full,
    wallBlendTable,
    @commonGrayTable[0]);
end;

// 0x49FB64
procedure floor_draw(fid, x, y: Integer; rect: PRect);
var
  cacheEntry: PCacheEntry;
  art: PArt;
  elev: Integer;
  left, top, width, height: Integer;
  frameWidth, frameHeight: Integer;
  tile: Integer;
  v76, v77, v78, v79: Integer;
  savedX, savedY: Integer;
  parity: Integer;
  ambientIntensity: Integer;
  tileIntensity: Integer;
  v23: Integer;
  frame_data: PByte;
  triangle: ^TRightsideUpTriangle;
  triangle2: ^TUpsideDownTriangle;
  v32, v33, v34, v35, v36: Integer;
  v37: PInteger;
  v38, v39, v41, v42, v44, v46: Integer;
  v50, v51, v52, v53, v54: Integer;
  v55: PInteger;
  v56, v57, v59, v60, v62, v64: Integer;
  v66: PByte;
  v67: PByte;
  v68: PInteger;
  v86, v85, v87: Integer;
  ii, jj, kk: Integer;
  i_loop: Integer;
begin
  if art_get_disable(FID_TYPE(fid)) <> 0 then
    Exit;

  art := art_ptr_lock(fid, @cacheEntry);
  if art = nil then
    Exit;

  elev := map_elevation;
  left := rect^.ulx;
  top := rect^.uly;
  width := rect^.lrx - rect^.ulx + 1;
  height := rect^.lry - rect^.uly + 1;

  savedX := x;
  savedY := y;

  if left < 0 then
    left := 0;

  if top < 0 then
    top := 0;

  if left + width > buf_width then
    width := buf_width - left;

  if top + height > buf_length then
    height := buf_length - top;

  if (x >= buf_width) or (x > rect^.lrx) or (y >= buf_length) or (y > rect^.lry) then
  begin
    art_ptr_unlock(cacheEntry);
    Exit;
  end;

  frameWidth := art_frame_width(art, 0, 0);
  frameHeight := art_frame_length(art, 0, 0);

  if left < x then
  begin
    v79 := 0;
    if frameWidth + x <= left + width then
      v77 := frameWidth
    else
      v77 := left + width - x;
  end
  else
  begin
    v79 := left - x;
    x := left;
    v77 := frameWidth - v79;
    if v77 > width then
      v77 := width;
  end;

  if top < y then
  begin
    v78 := 0;
    if frameHeight + y <= height + top then
      v76 := frameHeight
    else
      v76 := height + top - y;
  end
  else
  begin
    v78 := top - y;
    y := top;
    v76 := frameHeight - v78;
    if v76 > height then
      v76 := height;
  end;

  if (v77 <= 0) or (v76 <= 0) then
  begin
    art_ptr_unlock(cacheEntry);
    Exit;
  end;

  tile := tile_num(savedX, savedY + 13, map_elevation);
  if tile <> -1 then
  begin
    parity := tile and 1;
    ambientIntensity := light_get_ambient;
    for i_loop := 0 to 9 do
    begin
      tileIntensity := light_get_tile(elev, tile + verticies[i_loop].offsets[parity]);
      if tileIntensity <= ambientIntensity then
        tileIntensity := ambientIntensity;

      verticies[i_loop].intensity := tileIntensity;
    end;

    v23 := 0;
    for i_loop := 0 to 8 do
    begin
      if verticies[i_loop + 1].intensity <> verticies[i_loop].intensity then
        Break;
      Inc(v23);
    end;

    if v23 = 9 then
    begin
      frame_data := art_frame_data(art, 0, 0);
      dark_trans_buf_to_buf(frame_data + frameWidth * v78 + v79,
        v77, v76, frameWidth, buf_var, x, y, buf_full, verticies[0].intensity);
      art_ptr_unlock(cacheEntry);
      Exit;
    end;

    for ii := 0 to 4 do
    begin
      triangle := @rightside_up_triangles[ii];
      v32 := verticies[triangle^.field_8].intensity;
      v33 := verticies[triangle^.field_8].field_0;
      v34 := verticies[triangle^.field_4].intensity - verticies[triangle^.field_0].intensity;
      v35 := v34 div 32;
      v36 := (verticies[triangle^.field_0].intensity - v32) div 13;
      v37 := @intensity_map[v33];
      if v35 <> 0 then
      begin
        if v36 <> 0 then
        begin
          for i_loop := 0 to 12 do
          begin
            v41 := v32;
            v42 := rightside_up_table[i_loop].field_4;
            Inc(v37, rightside_up_table[i_loop].field_0);
            for jj := 0 to v42 - 1 do
            begin
              v37^ := v41;
              Inc(v37);
              Inc(v41, v35);
            end;
            Inc(v32, v36);
          end;
        end
        else
        begin
          for i_loop := 0 to 12 do
          begin
            v38 := v32;
            v39 := rightside_up_table[i_loop].field_4;
            Inc(v37, rightside_up_table[i_loop].field_0);
            for jj := 0 to v39 - 1 do
            begin
              v37^ := v38;
              Inc(v37);
              Inc(v38, v35);
            end;
          end;
        end;
      end
      else
      begin
        if v36 <> 0 then
        begin
          for i_loop := 0 to 12 do
          begin
            v46 := rightside_up_table[i_loop].field_4;
            Inc(v37, rightside_up_table[i_loop].field_0);
            for jj := 0 to v46 - 1 do
            begin
              v37^ := v32;
              Inc(v37);
            end;
            Inc(v32, v36);
          end;
        end
        else
        begin
          for i_loop := 0 to 12 do
          begin
            v44 := rightside_up_table[i_loop].field_4;
            Inc(v37, rightside_up_table[i_loop].field_0);
            for jj := 0 to v44 - 1 do
            begin
              v37^ := v32;
              Inc(v37);
            end;
          end;
        end;
      end;
    end;

    for ii := 0 to 4 do
    begin
      triangle2 := @upside_down_triangles[ii];
      v50 := verticies[triangle2^.field_0].intensity;
      v51 := verticies[triangle2^.field_0].field_0;
      v52 := verticies[triangle2^.field_8].intensity - v50;
      v53 := v52 div 32;
      v54 := (verticies[triangle2^.field_4].intensity - v50) div 13;
      v55 := @intensity_map[v51];
      if v53 <> 0 then
      begin
        if v54 <> 0 then
        begin
          for i_loop := 0 to 12 do
          begin
            v59 := v50;
            v60 := upside_down_table[i_loop].field_4;
            Inc(v55, upside_down_table[i_loop].field_0);
            for jj := 0 to v60 - 1 do
            begin
              v55^ := v59;
              Inc(v55);
              Inc(v59, v53);
            end;
            Inc(v50, v54);
          end;
        end
        else
        begin
          for i_loop := 0 to 12 do
          begin
            v56 := v50;
            v57 := upside_down_table[i_loop].field_4;
            Inc(v55, upside_down_table[i_loop].field_0);
            for jj := 0 to v57 - 1 do
            begin
              v55^ := v56;
              Inc(v55);
              Inc(v56, v53);
            end;
          end;
        end;
      end
      else
      begin
        if v54 <> 0 then
        begin
          for i_loop := 0 to 12 do
          begin
            v64 := upside_down_table[i_loop].field_4;
            Inc(v55, upside_down_table[i_loop].field_0);
            for jj := 0 to v64 - 1 do
            begin
              v55^ := v50;
              Inc(v55);
            end;
            Inc(v50, v54);
          end;
        end
        else
        begin
          for i_loop := 0 to 12 do
          begin
            v62 := upside_down_table[i_loop].field_4;
            Inc(v55, upside_down_table[i_loop].field_0);
            for jj := 0 to v62 - 1 do
            begin
              v55^ := v50;
              Inc(v55);
            end;
          end;
        end;
      end;
    end;

    v66 := buf_var + buf_full * y + x;
    v67 := art_frame_data(art, 0, 0) + frameWidth * v78 + v79;
    v68 := @intensity_map[160 + 80 * v78];
    Inc(v68, v79);
    v86 := frameWidth - v77;
    v85 := buf_full - v77;
    v87 := 80 - v77;

    Dec(v76);
    while v76 <> -1 do
    begin
      for kk := 0 to v77 - 1 do
      begin
        if v67^ <> 0 then
          v66^ := intensityColorTable[v67^][v68^ shr 9];
        Inc(v67);
        Inc(v68);
        Inc(v66);
      end;
      Inc(v66, v85);
      Inc(v68, v87);
      Inc(v67, v86);
      Dec(v76);
    end;
  end;

  art_ptr_unlock(cacheEntry);
end;

// 0x4A01CC
function tile_make_line(from_, to_: Integer; tiles: PInteger; tilesCapacity: Integer): Integer;
var
  count: Integer;
  fromX, fromY, toX, toY: Integer;
  stepX, stepY: Integer;
  deltaX, deltaY: Integer;
  v28, v27: Integer;
  tileX, tileY: Integer;
  middleX, middleY: Integer;
  tile: Integer;
  tilesArr: PInteger;
begin
  if tilesCapacity <= 1 then
  begin
    Result := 0;
    Exit;
  end;

  count := 0;

  tile_coord(from_, @fromX, @fromY, map_elevation);
  Inc(fromX, 16);
  Inc(fromY, 8);

  tile_coord(to_, @toX, @toY, map_elevation);
  Inc(toX, 16);
  Inc(toY, 8);

  tilesArr := tiles;
  tilesArr[count] := from_;
  Inc(count);

  deltaX := toX - fromX;
  if deltaX > 0 then
    stepX := 1
  else if deltaX < 0 then
    stepX := -1
  else
    stepX := 0;

  deltaY := toY - fromY;
  if deltaY > 0 then
    stepY := 1
  else if deltaY < 0 then
    stepY := -1
  else
    stepY := 0;

  v28 := 2 * abs(toX - fromX);
  v27 := 2 * abs(toY - fromY);

  tileX := fromX;
  tileY := fromY;

  if v28 <= v27 then
  begin
    middleX := v28 - v27 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, map_elevation);
      tilesArr[count] := tile;

      if tile = to_ then
      begin
        Inc(count);
        Break;
      end;

      if (tile <> tilesArr[count - 1]) and ((count = 1) or (tile <> tilesArr[count - 2])) then
      begin
        Inc(count);
        if count = tilesCapacity then
          Break;
      end;

      if tileY = toY then
        Break;

      if middleX >= 0 then
      begin
        Inc(tileX, stepX);
        Dec(middleX, v27);
      end;

      Inc(middleX, v28);
      Inc(tileY, stepY);
    end;
  end
  else
  begin
    middleY := v27 - v28 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, map_elevation);
      tilesArr[count] := tile;

      if tile = to_ then
      begin
        Inc(count);
        Break;
      end;

      if (tile <> tilesArr[count - 1]) and ((count = 1) or (tile <> tilesArr[count - 2])) then
      begin
        Inc(count);
        if count = tilesCapacity then
          Break;
      end;

      if tileX = toX then
      begin
        Result := count;
        Exit;
      end;

      if middleY >= 0 then
      begin
        Inc(tileY, stepY);
        Dec(middleY, v28);
      end;

      Inc(middleY, v27);
      Inc(tileX, stepX);
    end;
  end;

  Result := count;
end;

// 0x4A03C4
function tile_scroll_to(tile, flags: Integer): Integer;
var
  oldCenterTile: Integer;
  v9: array[0..199] of Integer;
  count: Integer;
  index: Integer;
  rc: Integer;
begin
  if tile = tile_center_tile then
  begin
    Result := -1;
    Exit;
  end;

  oldCenterTile := tile_center_tile;

  count := tile_make_line(tile_center_tile, tile, @v9[0], 200);
  if count = 0 then
  begin
    Result := -1;
    Exit;
  end;

  index := 1;
  while index < count do
  begin
    if tile_set_center(v9[index], 0) = -1 then
      Break;
    Inc(index);
  end;

  rc := 0;
  if (flags and $01) <> 0 then
  begin
    if index <> count then
    begin
      tile_set_center(oldCenterTile, 0);
      rc := -1;
    end;
  end;

  if (flags and $02) <> 0 then
    tile_refresh_display;

  Result := rc;
end;

procedure tile_update_bounds_base;
var
  min_x, min_y, max_x, max_y: Integer;
  tile: Integer;
  x, y: Integer;
  geometric_center_x, geometric_center_y: Integer;
begin
  min_x := High(Integer);
  min_y := High(Integer);
  max_x := Low(Integer);
  max_y := Low(Integer);

  for tile := 0 to grid_size - 1 do
  begin
    if obj_scroll_blocking_at(tile, map_elevation) = 0 then
    begin
      tile_coord(tile, @x, @y, map_elevation);
      Inc(x, 16);
      Inc(y, 8);

      if x < min_x then
        min_x := x;
      if y < min_y then
        min_y := y;
      if x > max_x then
        max_x := x;
      if y > max_y then
        max_y := y;
    end;
  end;

  tile_coord(20100, @geometric_center_x, @geometric_center_y, map_elevation);
  Inc(geometric_center_x, 16);
  Inc(geometric_center_y, 8);

  tile_bounds_left_off := min_x - geometric_center_x;
  tile_bounds_top_off := min_y - geometric_center_y;
  tile_bounds_right_off := max_x - geometric_center_x;
  tile_bounds_bottom_off := max_y - geometric_center_y;
end;

procedure tile_update_bounds_rect;
var
  geometric_center_x, geometric_center_y: Integer;
  tile_center_x, tile_center_y: Integer;
begin
  tile_coord(20100, @geometric_center_x, @geometric_center_y, map_elevation);
  Inc(geometric_center_x, 16);
  Inc(geometric_center_y, 8);

  tile_bounds_rect.ulx := tile_bounds_left_off + geometric_center_x;
  tile_bounds_rect.uly := tile_bounds_top_off + geometric_center_y;
  tile_bounds_rect.lrx := tile_bounds_right_off + geometric_center_x;
  tile_bounds_rect.lry := tile_bounds_bottom_off + geometric_center_y;

  tile_coord(tile_center_tile, @tile_center_x, @tile_center_y, map_elevation);
  Inc(tile_center_x, 16);
  Inc(tile_center_y, 8);

  tile_bounds_rect.ulx := tile_bounds_rect.ulx - (tile_bounds_rect.ulx - tile_center_x) mod 32;
  tile_bounds_rect.uly := tile_bounds_rect.uly - (tile_bounds_rect.uly - tile_center_y) mod 24;
  tile_bounds_rect.lrx := tile_bounds_rect.lrx - (tile_bounds_rect.lrx - tile_center_x) mod 32;
  tile_bounds_rect.lry := tile_bounds_rect.lry - (tile_bounds_rect.lry - tile_center_y) mod 24;

  Inc(tile_bounds_rect.ulx, 32);
  Inc(tile_bounds_rect.uly, 16);
  Dec(tile_bounds_rect.lrx, 32);
  Dec(tile_bounds_rect.lry, 16);

  Dec(tile_bounds_rect.ulx, 640 div 2);
  Dec(tile_bounds_rect.uly, (480 - 100) div 2);
  Inc(tile_bounds_rect.lrx, 640 div 2);
  Inc(tile_bounds_rect.lry, (480 - 100) div 2);

  Inc(tile_bounds_rect.uly, 8);
  Dec(tile_bounds_rect.lry, 8);

  Dec(tile_bounds_rect.lrx, 1);
  Dec(tile_bounds_rect.lry, 1);
end;

function tile_inside_bound(rect: PRect): Integer;
begin
  Result := rect_inside_bound(rect, @tile_bounds_rect, rect);
end;

function tile_point_inside_bound(x, y: Integer): Boolean;
begin
  Result := (x >= tile_bounds_rect.ulx) and (x <= tile_bounds_rect.lrx) and
            (y >= tile_bounds_rect.uly) and (y <= tile_bounds_rect.lry);
end;

procedure bounds_render(rect: PRect; elevation: Integer);
const
  kShadowSize = 16;
var
  edge: TRect;
  y, x: Integer;
  dest: PByte;
  step: Integer;
  color: Byte;
begin
  // Left.
  edge.ulx := tile_bounds_rect.ulx;
  edge.uly := tile_bounds_rect.uly;
  edge.lrx := tile_bounds_rect.ulx + kShadowSize;
  edge.lry := tile_bounds_rect.lry;
  if rect_inside_bound(@edge, rect, @edge) = 0 then
  begin
    for y := edge.uly to edge.lry do
    begin
      dest := buf_var + buf_full * y + edge.ulx;
      step := edge.ulx - tile_bounds_rect.ulx;
      for x := edge.ulx to edge.lrx do
      begin
        color := dest^;
        dest^ := intensityColorTable[color][step * 128 div kShadowSize];
        Inc(dest);
        Inc(step);
      end;
    end;
  end;

  // Top.
  edge.ulx := tile_bounds_rect.ulx;
  edge.uly := tile_bounds_rect.uly;
  edge.lrx := tile_bounds_rect.lrx;
  edge.lry := tile_bounds_rect.uly + kShadowSize;
  if rect_inside_bound(@edge, rect, @edge) = 0 then
  begin
    step := edge.uly - tile_bounds_rect.uly;
    for y := edge.uly to edge.lry do
    begin
      dest := buf_var + buf_full * y + edge.ulx;
      for x := edge.ulx to edge.lrx do
      begin
        color := dest^;
        dest^ := intensityColorTable[color][step * 128 div kShadowSize];
        Inc(dest);
      end;
      Inc(step);
    end;
  end;

  // Right.
  edge.ulx := tile_bounds_rect.lrx - kShadowSize;
  edge.uly := tile_bounds_rect.uly;
  edge.lrx := tile_bounds_rect.lrx;
  edge.lry := tile_bounds_rect.lry;
  if rect_inside_bound(@edge, rect, @edge) = 0 then
  begin
    for y := edge.uly to edge.lry do
    begin
      dest := buf_var + buf_full * y + edge.lrx;
      step := tile_bounds_rect.lrx - edge.lrx;
      for x := edge.lrx downto edge.ulx do
      begin
        color := dest^;
        dest^ := intensityColorTable[color][step * 128 div kShadowSize];
        Dec(dest);
        Inc(step);
      end;
    end;
  end;

  // Bottom.
  edge.ulx := tile_bounds_rect.ulx;
  edge.uly := tile_bounds_rect.lry - kShadowSize;
  edge.lrx := tile_bounds_rect.lrx;
  edge.lry := tile_bounds_rect.lry;
  if rect_inside_bound(@edge, rect, @edge) = 0 then
  begin
    step := tile_bounds_rect.lry - edge.lry;
    for y := edge.lry downto edge.uly do
    begin
      dest := buf_var + buf_full * y + edge.ulx;
      for x := edge.ulx to edge.lrx do
      begin
        color := dest^;
        dest^ := intensityColorTable[color][step * 128 div kShadowSize];
        Inc(dest);
      end;
      Inc(step);
    end;
  end;
end;

initialization
  tile_refresh_proc := @refresh_game;

  off_tile[0][0] :=  16;
  off_tile[0][1] :=  32;
  off_tile[0][2] :=  16;
  off_tile[0][3] := -16;
  off_tile[0][4] := -32;
  off_tile[0][5] := -16;
  off_tile[1][0] := -12;
  off_tile[1][1] :=   0;
  off_tile[1][2] :=  12;
  off_tile[1][3] :=  12;
  off_tile[1][4] :=   0;
  off_tile[1][5] := -12;

end.
