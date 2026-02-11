unit u_map;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/map.h + map.cc
// Map loading, saving, scrolling, and elevation management.

interface

uses
  u_object_types, u_proto_types, u_map_defs, u_rect, u_db,
  u_message, u_intrpret;

const
  ORIGINAL_ISO_WINDOW_WIDTH  = 640;
  ORIGINAL_ISO_WINDOW_HEIGHT = 380;

  INTERFACE_BAR_HEIGHT = 100;

  // MapFlags
  MAP_SAVED              = $01;
  MAP_DEAD_BODIES_AGE    = $02;
  MAP_PIPBOY_ACTIVE      = $04;
  MAP_CAN_REST_ELEVATION_0 = $08;
  MAP_CAN_REST_ELEVATION_1 = $10;
  MAP_CAN_REST_ELEVATION_2 = $20;

  // Map enum
  MAP_DESERT1  = 0;
  MAP_DESERT2  = 1;
  MAP_DESERT3  = 2;
  MAP_HALLDED  = 3;
  MAP_HOTEL    = 4;
  MAP_WATRSHD  = 5;
  MAP_VAULT13  = 6;
  MAP_VAULTENT = 7;
  MAP_VAULTBUR = 8;
  MAP_VAULTNEC = 9;
  MAP_JUNKENT  = 10;
  MAP_JUNKCSNO = 11;
  MAP_JUNKKILL = 12;
  MAP_BROHDENT = 13;
  MAP_BROHD12  = 14;
  MAP_BROHD34  = 15;
  MAP_CAVES    = 16;
  MAP_CHILDRN1 = 17;
  MAP_CHILDRN2 = 18;
  MAP_CITY1    = 19;
  MAP_COAST1   = 20;
  MAP_COAST2   = 21;
  MAP_COLATRUK = 22;
  MAP_FSAUSER  = 23;
  MAP_RAIDERS  = 24;
  MAP_SHADYE   = 25;
  MAP_SHADYW   = 26;
  MAP_GLOWENT  = 27;
  MAP_LAADYTUM = 28;
  MAP_LAFOLLWR = 29;
  MAP_MBENT    = 30;
  MAP_MBSTRG12 = 31;
  MAP_MBVATS12 = 32;
  MAP_MSTRLR12 = 33;
  MAP_MSTRLR34 = 34;
  MAP_V13ENT   = 35;
  MAP_HUBENT   = 36;
  MAP_DETHCLAW = 37;
  MAP_HUBDWNTN = 38;
  MAP_HUBHEIGT = 39;
  MAP_HUBOLDTN = 40;
  MAP_HUBWATER = 41;
  MAP_GLOW1    = 42;
  MAP_GLOW2    = 43;
  MAP_LABLADES = 44;
  MAP_LARIPPER = 45;
  MAP_LAGUNRUN = 46;
  MAP_CHILDEAD = 47;
  MAP_MBDEAD   = 48;
  MAP_MOUNTN1  = 49;
  MAP_MOUNTN2  = 50;
  MAP_FOOT     = 51;
  MAP_TARDIS   = 52;
  MAP_TALKCOW  = 53;
  MAP_USEDCAR  = 54;
  MAP_BRODEAD  = 55;
  MAP_DESCRVN1 = 56;
  MAP_DESCRVN2 = 57;
  MAP_MNTCRVN1 = 58;
  MAP_MNTCRVN2 = 59;
  MAP_VIPERS   = 60;
  MAP_DESCRVN3 = 61;
  MAP_MNTCRVN3 = 62;
  MAP_DESCRVN4 = 63;
  MAP_MNTCRVN4 = 64;
  MAP_HUBMIS1  = 65;
  MAP_COUNT    = 66;

  // Tile set center flags
  TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS = 2;
  TILE_SET_CENTER_REFRESH_WINDOW = 1;

  // Game time
  GAME_TIME_TICKS_PER_HOUR = 600;

  // Script types
  SCRIPT_TYPE_SYSTEM  = 0;
  SCRIPT_TYPE_SPATIAL = 1;
  SCRIPT_TYPE_TIME    = 2;
  SCRIPT_TYPE_ITEM    = 3;
  SCRIPT_TYPE_CRITTER = 4;

  // Script proc
  SCRIPT_PROC_MAP_ENTER   = 15;

  // Script flags
  SCRIPT_FLAG_0x08 = $08;

  // Light level
  LIGHT_LEVEL_MAX = $10000;

  // Mouse cursors
  MOUSE_CURSOR_NONE         = 0;
  MOUSE_CURSOR_ARROW        = 1;
  MOUSE_CURSOR_WAIT_PLANET  = 27;

type
  PTileData = ^TTileData;
  TTileData = record
    field_0: array[0..SQUARE_GRID_SIZE - 1] of Integer;
  end;

  PMapHeader = ^TMapHeader;
  TMapHeader = record
    version: Integer;
    name: array[0..15] of AnsiChar;
    enteringTile: Integer;
    enteringElevation: Integer;
    enteringRotation: Integer;
    localVariablesCount: Integer;
    scriptIndex: Integer;
    flags: Integer;
    darkness: Integer;
    globalVariablesCount: Integer;
    field_34: Integer;
    lastVisitTime: Integer;
    field_3C: array[0..43] of Integer;
  end;

  PMapTransition = ^TMapTransition;
  TMapTransition = record
    map: Integer;
    elevation: Integer;
    tile: Integer;
    rotation: Integer;
  end;

  TIsoWindowRefreshProc = procedure(rect: PRect);

var
  byte_50B058: array[0..0] of AnsiChar;
  _aErrorF2: array[0..8] of AnsiChar;

  map_script_id: Integer;
  map_local_vars: PInteger;
  map_global_vars: PInteger;
  num_map_local_vars: Integer;
  num_map_global_vars: Integer;
  map_elevation: Integer;

  square_data: array[0..ELEVATION_COUNT - 1] of TTileData;
  map_msg_file: TMessageList;
  map_data: TMapHeader;
  square: array[0..ELEVATION_COUNT - 1] of PTileData;
  display_win: Integer;

function iso_init: Integer;
procedure iso_reset;
procedure iso_exit;
procedure map_init;
procedure map_reset;
procedure map_exit;
procedure map_enable_bk_processes;
function map_disable_bk_processes: Boolean;
function map_set_elevation(elevation: Integer): Integer;
function map_is_elevation_empty(elevation: Integer): Boolean;
function map_set_global_var(v: Integer; var value: TProgramValue): Integer;
function map_get_global_var(v: Integer; var value: TProgramValue): Integer;
function map_set_local_var(v: Integer; var value: TProgramValue): Integer;
function map_get_local_var(v: Integer; var value: TProgramValue): Integer;
function map_malloc_local_var(a1: Integer): Integer;
procedure map_set_entrance_hex(a1, a2, a3: Integer);
procedure map_set_name(name: PAnsiChar);
procedure map_get_name(name: PAnsiChar);
function map_get_name_idx(name: PAnsiChar; map: Integer): Integer;
function map_get_elev_idx(map_num, elev: Integer): PAnsiChar;
function is_map_idx_same(map_num1, map_num2: Integer): Boolean;
function get_map_idx_same(map_num1, map_num2: Integer): Integer;
function map_get_short_name(map_num: Integer): PAnsiChar;
function map_get_description: PAnsiChar;
function map_get_description_idx(map_index: Integer): PAnsiChar;
function map_get_index_number: Integer;
function map_scroll(dx, dy: Integer): Integer;
function map_file_path(name: PAnsiChar): PAnsiChar;
procedure map_new_map;
function map_load(fileName: PAnsiChar): Integer;
function map_load_idx(map_index: Integer): Integer;
function map_load_file(stream: PDB_FILE): Integer;
function map_load_in_game(fileName: PAnsiChar): Integer;
function map_leave_map(transition: PMapTransition): Integer;
function map_check_state: Integer;
procedure map_fix_critter_combat_data;
function map_save: Integer;
function map_save_file(stream: PDB_FILE): Integer;
function map_save_in_game(a1: Boolean): Integer;
procedure map_setup_paths;
function map_match_map_name(name: PAnsiChar): Integer;

implementation

uses
  SysUtils,
  u_memory, u_debug, u_svga, u_gnw, u_grbuf, u_input, u_color,
  u_art, u_object, u_config, u_gconfig, u_platform_compat,
  u_proto,
  u_tile,
  u_cycle,
  u_intface,
  u_anim,
  u_critter,
  u_gmouse,
  u_scripts,
  u_combat,
  u_item,
  u_light,
  u_roll,
  u_queue,
  u_textobj,
  u_party,
  u_worldmap,
  u_loadsave,
  u_automap,
  u_editor,
  u_gsound,
  u_game,
  u_plib_intrface,
  u_protinst;

const
  VALUE_TYPE_INT = $C001;
  VALUE_TYPE_PTR = $E001;
  ANIM_STAND = 0;

// ============================================================================
// Static forward declarations
// ============================================================================

function map_age_dead_critters: Integer; forward;
procedure map_match_map_number; forward;
procedure map_display_draw(rect: PRect); forward;
procedure map_scroll_refresh_game(rect: PRect); forward;
procedure map_scroll_refresh_mapper(rect: PRect); forward;
function map_allocate_global_vars(count: Integer): Integer; forward;
procedure map_free_global_vars; forward;
function map_load_global_vars(stream: PDB_FILE): Integer; forward;
function map_allocate_local_vars(count: Integer): Integer; forward;
procedure map_free_local_vars; forward;
function map_load_local_vars(stream: PDB_FILE): Integer; forward;
procedure map_place_dude_and_mouse; forward;
procedure square_init_; forward;
procedure square_reset_; forward;
function square_load(stream: PDB_FILE; a2: Integer): Integer; forward;
function map_write_MapData(ptr: PMapHeader; stream: PDB_FILE): Integer; forward;
function map_read_MapData(ptr: PMapHeader; stream: PDB_FILE): Integer; forward;

// FID_ANIM_TYPE inline helper (same as in u_art)
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// ============================================================================
// Static tables
// ============================================================================

const
  city_vs_city_idx_table: array[0..MAP_COUNT - 1, 0..4] of SmallInt = (
    { DESERT1  } ( -1, -1, -1, -1, -1 ),
    { DESERT2  } ( -1, -1, -1, -1, -1 ),
    { DESERT3  } ( -1, -1, -1, -1, -1 ),
    { HALLDED  } ( MAP_VAULTNEC, MAP_HOTEL, MAP_WATRSHD, -1, -1 ),
    { HOTEL    } ( MAP_HALLDED, MAP_VAULTNEC, MAP_WATRSHD, -1, -1 ),
    { WATRSHD  } ( MAP_HALLDED, MAP_HOTEL, MAP_VAULTNEC, -1, -1 ),
    { VAULT13  } ( MAP_V13ENT, -1, -1, -1, -1 ),
    { VAULTENT } ( MAP_VAULTBUR, -1, -1, -1, -1 ),
    { VAULTBUR } ( MAP_VAULTENT, -1, -1, -1, -1 ),
    { VAULTNEC } ( MAP_HALLDED, MAP_HOTEL, MAP_WATRSHD, -1, -1 ),
    { JUNKENT  } ( MAP_JUNKCSNO, MAP_JUNKKILL, -1, -1, -1 ),
    { JUNKCSNO } ( MAP_JUNKENT, MAP_JUNKKILL, -1, -1, -1 ),
    { JUNKKILL } ( MAP_JUNKENT, MAP_JUNKCSNO, -1, -1, -1 ),
    { BROHDENT } ( MAP_BROHD12, MAP_BROHD34, MAP_BRODEAD, -1, -1 ),
    { BROHD12  } ( MAP_BROHDENT, MAP_BROHD34, MAP_BRODEAD, -1, -1 ),
    { BROHD34  } ( MAP_BROHDENT, MAP_BROHD12, MAP_BRODEAD, -1, -1 ),
    { CAVES    } ( MAP_SHADYE, MAP_SHADYW, -1, -1, -1 ),
    { CHILDRN1 } ( MAP_CHILDRN2, MAP_CHILDEAD, MAP_MSTRLR12, MAP_MSTRLR34, -1 ),
    { CHILDRN2 } ( MAP_CHILDRN1, MAP_CHILDEAD, MAP_MSTRLR12, MAP_MSTRLR34, -1 ),
    { CITY1    } ( -1, -1, -1, -1, -1 ),
    { COAST1   } ( -1, -1, -1, -1, -1 ),
    { COAST2   } ( -1, -1, -1, -1, -1 ),
    { COLATRUK } ( -1, -1, -1, -1, -1 ),
    { FSAUSER  } ( -1, -1, -1, -1, -1 ),
    { RAIDERS  } ( -1, -1, -1, -1, -1 ),
    { SHADYE   } ( MAP_CAVES, MAP_SHADYW, -1, -1, -1 ),
    { SHADYW   } ( MAP_CAVES, MAP_SHADYE, -1, -1, -1 ),
    { GLOWENT  } ( MAP_GLOW1, MAP_GLOW2, -1, -1, -1 ),
    { LAADYTUM } ( MAP_LAFOLLWR, MAP_LABLADES, MAP_LARIPPER, MAP_LAGUNRUN, -1 ),
    { LAFOLLWR } ( MAP_LAADYTUM, MAP_LABLADES, MAP_LARIPPER, MAP_LAGUNRUN, -1 ),
    { MBENT    } ( MAP_MBSTRG12, MAP_MBVATS12, MAP_MBDEAD, -1, -1 ),
    { MBSTRG12 } ( MAP_MBENT, MAP_MBVATS12, MAP_MBDEAD, -1, -1 ),
    { MBVATS12 } ( MAP_MBENT, MAP_MBSTRG12, MAP_MBDEAD, -1, -1 ),
    { MSTRLR12 } ( MAP_MSTRLR34, MAP_CHILDEAD, MAP_CHILDRN1, MAP_CHILDRN2, -1 ),
    { MSTRLR34 } ( MAP_MSTRLR12, MAP_CHILDEAD, MAP_CHILDRN1, MAP_CHILDRN2, -1 ),
    { V13ENT   } ( MAP_VAULT13, -1, -1, -1, -1 ),
    { HUBENT   } ( MAP_DETHCLAW, MAP_HUBDWNTN, MAP_HUBHEIGT, MAP_HUBOLDTN, MAP_HUBWATER ),
    { DETHCLAW } ( MAP_HUBENT, MAP_HUBDWNTN, MAP_HUBHEIGT, MAP_HUBOLDTN, MAP_HUBWATER ),
    { HUBDWNTN } ( MAP_HUBENT, MAP_DETHCLAW, MAP_HUBHEIGT, MAP_HUBOLDTN, MAP_HUBWATER ),
    { HUBHEIGT } ( MAP_HUBENT, MAP_DETHCLAW, MAP_HUBDWNTN, MAP_HUBOLDTN, MAP_HUBWATER ),
    { HUBOLDTN } ( MAP_HUBENT, MAP_DETHCLAW, MAP_HUBDWNTN, MAP_HUBHEIGT, MAP_HUBWATER ),
    { HUBWATER } ( MAP_HUBENT, MAP_DETHCLAW, MAP_HUBDWNTN, MAP_HUBHEIGT, MAP_HUBOLDTN ),
    { GLOW1    } ( MAP_GLOWENT, MAP_GLOW2, -1, -1, -1 ),
    { GLOW2    } ( MAP_GLOWENT, MAP_GLOW1, -1, -1, -1 ),
    { LABLADES } ( MAP_LAADYTUM, MAP_LAFOLLWR, MAP_LARIPPER, MAP_LAGUNRUN, -1 ),
    { LARIPPER } ( MAP_LAADYTUM, MAP_LAFOLLWR, MAP_LABLADES, MAP_LAGUNRUN, -1 ),
    { LAGUNRUN } ( MAP_LAADYTUM, MAP_LAFOLLWR, MAP_LABLADES, MAP_LARIPPER, -1 ),
    { CHILDEAD } ( MAP_CHILDRN1, MAP_CHILDRN2, MAP_MSTRLR12, MAP_MSTRLR34, -1 ),
    { MBDEAD   } ( MAP_MBENT, MAP_MBSTRG12, MAP_MBVATS12, -1, -1 ),
    { MOUNTN1  } ( -1, -1, -1, -1, -1 ),
    { MOUNTN2  } ( -1, -1, -1, -1, -1 ),
    { FOOT     } ( -1, -1, -1, -1, -1 ),
    { TARDIS   } ( -1, -1, -1, -1, -1 ),
    { TALKCOW  } ( -1, -1, -1, -1, -1 ),
    { USEDCAR  } ( -1, -1, -1, -1, -1 ),
    { BRODEAD  } ( MAP_BROHDENT, MAP_BROHD12, MAP_BROHD34, -1, -1 ),
    { DESCRVN1 } ( -1, -1, -1, -1, -1 ),
    { DESCRVN2 } ( -1, -1, -1, -1, -1 ),
    { MNTCRVN1 } ( -1, -1, -1, -1, -1 ),
    { MNTCRVN2 } ( -1, -1, -1, -1, -1 ),
    { VIPERS   } ( -1, -1, -1, -1, -1 ),
    { DESCRVN3 } ( -1, -1, -1, -1, -1 ),
    { MNTCRVN3 } ( -1, -1, -1, -1, -1 ),
    { DESCRVN4 } ( -1, -1, -1, -1, -1 ),
    { MNTCRVN4 } ( -1, -1, -1, -1, -1 ),
    { HUBMIS1  } ( -1, -1, -1, -1, -1 )
  );

  shrtnames: array[0..MAP_COUNT - 1] of SmallInt = (
    { DESERT1  } 100,
    { DESERT2  } 100,
    { DESERT3  } 100,
    { HALLDED  } 505,
    { HOTEL    } 505,
    { WATRSHD  } 505,
    { VAULT13  } 500,
    { VAULTENT } 501,
    { VAULTBUR } 501,
    { VAULTNEC } 505,
    { JUNKENT  } 503,
    { JUNKCSNO } 503,
    { JUNKKILL } 503,
    { BROHDENT } 507,
    { BROHD12  } 507,
    { BROHD34  } 507,
    { CAVES    } 116,
    { CHILDRN1 } 511,
    { CHILDRN2 } 511,
    { CITY1    } 119,
    { COAST1   } 120,
    { COAST2   } 120,
    { COLATRUK } 100,
    { FSAUSER  } 100,
    { RAIDERS  } 504,
    { SHADYE   } 502,
    { SHADYW   } 502,
    { GLOWENT  } 509,
    { LAADYTUM } 510,
    { LAFOLLWR } 510,
    { MBENT    } 508,
    { MBSTRG12 } 508,
    { MBVATS12 } 508,
    { MSTRLR12 } 511,
    { MSTRLR34 } 511,
    { V13ENT   } 500,
    { HUBENT   } 506,
    { DETHCLAW } 506,
    { HUBDWNTN } 506,
    { HUBHEIGT } 506,
    { HUBOLDTN } 506,
    { HUBWATER } 506,
    { GLOW1    } 509,
    { GLOW2    } 509,
    { LABLADES } 510,
    { LARIPPER } 510,
    { LAGUNRUN } 510,
    { CHILDEAD } 511,
    { MBDEAD   } 508,
    { MOUNTN1  } 149,
    { MOUNTN2  } 149,
    { FOOT     } 100,
    { TARDIS   } 100,
    { TALKCOW  } 100,
    { USEDCAR  } 100,
    { BRODEAD  } 507,
    { DESCRVN1 } 100,
    { DESCRVN2 } 100,
    { MNTCRVN1 } 149,
    { MNTCRVN2 } 149,
    { VIPERS   } 160,
    { DESCRVN3 } 100,
    { MNTCRVN3 } 149,
    { DESCRVN4 } 100,
    { MNTCRVN4 } 149,
    { HUBMIS1  } 506
  );

// ============================================================================
// Module-level implementation variables (static in C++)
// ============================================================================

var
  map_scroll_refresh: TIsoWindowRefreshProc;
  map_data_elev_flags: array[0..ELEVATION_COUNT - 1] of Integer;
  map_last_scroll_time: LongWord = 0;
  map_bk_enabled: Boolean = False;
  map_state: TMapTransition;
  map_display_rect: TRect;
  display_buf: PByte;

  // static local from map_file_path
  map_path_buf: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;

  // Pointer vectors for global/local vars (replaces std::vector<void*>)
  map_global_pointers: array of Pointer;
  map_local_pointers: array of Pointer;

// ============================================================================
// Implementation
// ============================================================================

// 0x4738E8
function iso_init: Integer;
begin
  WriteLn(StdErr, '[ISO] iso_init: start');
  tile_disable_scroll_limiting;
  tile_disable_scroll_blocking;

  // NOTE: Uninline.
  square_init_;
  WriteLn(StdErr, '[ISO] square_init_ OK');

  display_win := win_add(0, 0, screenGetWidth(), screenGetHeight() - INTERFACE_BAR_HEIGHT, 256, 10);
  if display_win = -1 then
  begin
    WriteLn(StdErr, '[ISO] win_add FAILED');
    debug_printf('win_add failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] win_add OK, display_win=', display_win);

  display_buf := win_get_buf(display_win);
  if display_buf = nil then
  begin
    WriteLn(StdErr, '[ISO] win_get_buf FAILED');
    debug_printf('win_get_buf failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] win_get_buf OK');

  if win_get_rect(display_win, @map_display_rect) <> 0 then
  begin
    WriteLn(StdErr, '[ISO] win_get_rect FAILED');
    debug_printf('win_get_rect failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] win_get_rect OK');

  if art_init <> 0 then
  begin
    WriteLn(StdErr, '[ISO] art_init FAILED');
    debug_printf('art_init failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] art_init OK');

  debug_printf('>art_init'#9#9);

  if tile_init(@square[0], SQUARE_GRID_WIDTH, SQUARE_GRID_HEIGHT,
    HEX_GRID_WIDTH, HEX_GRID_HEIGHT, display_buf,
    scr_size.lrx - scr_size.ulx + 1,
    scr_size.lry - scr_size.uly - 99,
    scr_size.lrx - scr_size.ulx + 1,
    @map_display_draw) <> 0 then
  begin
    WriteLn(StdErr, '[ISO] tile_init FAILED');
    debug_printf('tile_init failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] tile_init OK');

  debug_printf('>tile_init'#9#9);

  if obj_init(display_buf,
    scr_size.lrx - scr_size.ulx + 1,
    scr_size.lry - scr_size.uly - 99,
    scr_size.lrx - scr_size.ulx + 1) <> 0 then
  begin
    WriteLn(StdErr, '[ISO] obj_init FAILED');
    debug_printf('obj_init failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] obj_init OK');

  debug_printf('>obj_init'#9#9);

  cycle_init;
  WriteLn(StdErr, '[ISO] cycle_init OK');
  debug_printf('>cycle_init'#9#9);

  tile_enable_scroll_blocking;
  tile_enable_scroll_limiting;

  if intface_init <> 0 then
  begin
    WriteLn(StdErr, '[ISO] intface_init FAILED');
    debug_printf('intface_init failed in iso_init'#10);
    Exit(-1);
  end;
  WriteLn(StdErr, '[ISO] intface_init OK');

  debug_printf('>intface_init'#9#9);

  map_setup_paths;
  WriteLn(StdErr, '[ISO] iso_init completed successfully');

  Result := 0;
end;

// 0x473B04
procedure iso_reset;
begin
  // NOTE: Uninline.
  map_free_global_vars;

  // NOTE: Uninline.
  map_free_local_vars;

  art_reset;
  tile_reset;
  obj_reset;
  cycle_reset;
  intface_reset;
end;

// 0x473B64
procedure iso_exit;
begin
  intface_exit;
  cycle_exit;
  obj_exit;
  tile_exit;
  art_exit;

  win_delete(display_win);

  // NOTE: Uninline.
  map_free_global_vars;

  // NOTE: Uninline.
  map_free_local_vars;
end;

// 0x473BD0
procedure map_init;
var
  executable: PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, 'executable', @executable);
  if compat_stricmp(executable, 'mapper') = 0 then
    map_scroll_refresh := @map_scroll_refresh_mapper;

  if message_init(@map_msg_file) then
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%smap.msg', [msg_path]);

    if not message_load(@map_msg_file, @path[0]) then
      debug_printf(#10'Error loading map_msg_file!');
  end
  else
    debug_printf(#10'Error initing map_msg_file!');

  // NOTE: Uninline.
  map_reset;
end;

// 0x473C80
procedure map_reset;
begin
  map_new_map;
  add_bk_process(TBackgroundProcess(@gmouse_bk_process));
  gmouse_disable(0);
  win_show(display_win);
end;

// 0x473CA0
procedure map_exit;
begin
  win_hide(display_win);
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  remove_bk_process(TBackgroundProcess(@gmouse_bk_process));
  if not message_exit(@map_msg_file) then
    debug_printf(#10'Error exiting map_msg_file!');
end;

// 0x473CDC
procedure map_enable_bk_processes;
begin
  if not map_bk_enabled then
  begin
    text_object_enable;
    gmouse_enable;
    add_bk_process(TBackgroundProcess(@object_animate));
    add_bk_process(TBackgroundProcess(@dude_fidget));
    scr_enable_critters;
    map_bk_enabled := True;
  end;
end;

// 0x473D18
function map_disable_bk_processes: Boolean;
begin
  if not map_bk_enabled then
    Exit(False);

  scr_disable_critters;
  remove_bk_process(TBackgroundProcess(@dude_fidget));
  remove_bk_process(TBackgroundProcess(@object_animate));
  gmouse_disable(0);
  text_object_disable;

  map_bk_enabled := False;

  Result := True;
end;

// 0x473D5C
function map_set_elevation(elevation: Integer): Integer;
begin
  if (elevation < 0) or (elevation >= ELEVATION_COUNT) then
    Exit(-1);

  gmouse_3d_off;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);
  map_elevation := elevation;

  // CE: Recalculate bounds.
  tile_update_bounds_base;

  register_clear(obj_dude);
  dude_stand(obj_dude, obj_dude^.Rotation, obj_dude^.Fid);
  partyMemberSyncPosition;

  if map_script_id <> -1 then
    scr_exec_map_update_scripts;

  gmouse_3d_on;

  Result := 0;
end;

// 0x473DBC
function map_is_elevation_empty(elevation: Integer): Boolean;
begin
  Result := (elevation < 0) or
    (elevation >= ELEVATION_COUNT) or
    ((map_data.flags and map_data_elev_flags[elevation]) <> 0);
end;

// 0x473DE8
function map_set_global_var(v: Integer; var value: TProgramValue): Integer;
begin
  if (v < 0) or (v >= num_map_global_vars) then
  begin
    debug_printf('ERROR: attempt to reference map var out of range: %d', [v]);
    Exit(-1);
  end;

  if value.opcode = VALUE_TYPE_PTR then
  begin
    PInteger(PByte(map_global_vars) + v * SizeOf(Integer))^ := 0;
    map_global_pointers[v] := value.pointerValue;
  end
  else
  begin
    PInteger(PByte(map_global_vars) + v * SizeOf(Integer))^ := value.integerValue;
    map_global_pointers[v] := nil;
  end;

  Result := 0;
end;

// 0x473E18
function map_get_global_var(v: Integer; var value: TProgramValue): Integer;
begin
  if (v < 0) or (v >= num_map_global_vars) then
  begin
    debug_printf('ERROR: attempt to reference map var out of range: %d', [v]);
    Exit(-1);
  end;

  if map_global_pointers[v] <> nil then
  begin
    value.opcode := VALUE_TYPE_PTR;
    value.pointerValue := map_global_pointers[v];
  end
  else
  begin
    value.opcode := VALUE_TYPE_INT;
    value.integerValue := PInteger(PByte(map_global_vars) + v * SizeOf(Integer))^;
  end;

  Result := 0;
end;

// 0x473E48
function map_set_local_var(v: Integer; var value: TProgramValue): Integer;
begin
  if (v < 0) or (v >= num_map_local_vars) then
  begin
    debug_printf('ERROR: attempt to reference local var out of range: %d', [v]);
    Exit(-1);
  end;

  if value.opcode = VALUE_TYPE_PTR then
  begin
    PInteger(PByte(map_local_vars) + v * SizeOf(Integer))^ := 0;
    map_local_pointers[v] := value.pointerValue;
  end
  else
  begin
    PInteger(PByte(map_local_vars) + v * SizeOf(Integer))^ := value.integerValue;
    map_local_pointers[v] := nil;
  end;

  Result := 0;
end;

// 0x473E78
function map_get_local_var(v: Integer; var value: TProgramValue): Integer;
begin
  if (v < 0) or (v >= num_map_local_vars) then
  begin
    debug_printf('ERROR: attempt to reference local var out of range: %d', [v]);
    Exit(-1);
  end;

  if map_local_pointers[v] <> nil then
  begin
    value.opcode := VALUE_TYPE_PTR;
    value.pointerValue := map_local_pointers[v];
  end
  else
  begin
    value.opcode := VALUE_TYPE_INT;
    value.integerValue := PInteger(PByte(map_local_vars) + v * SizeOf(Integer))^;
  end;

  Result := 0;
end;

// 0x473EA8
function map_malloc_local_var(a1: Integer): Integer;
var
  oldMapLocalVarsLength: Integer;
  vars: PInteger;
begin
  oldMapLocalVarsLength := num_map_local_vars;
  num_map_local_vars := num_map_local_vars + a1;

  vars := PInteger(mem_realloc(map_local_vars, SizeOf(Integer) * num_map_local_vars));
  if vars = nil then
    debug_printf(#10'Error: Ran out of memory!');

  map_local_vars := vars;
  FillChar((PByte(vars) + SizeOf(Integer) * oldMapLocalVarsLength)^, SizeOf(Integer) * a1, 0);

  SetLength(map_local_pointers, num_map_local_vars);

  Result := oldMapLocalVarsLength;
end;

// 0x473F14
procedure map_set_entrance_hex(a1, a2, a3: Integer);
begin
  map_data.enteringTile := a1;
  map_data.enteringElevation := a2;
  map_data.enteringRotation := a3;
end;

// 0x474044
procedure map_set_name(name: PAnsiChar);
begin
  StrCopy(map_data.name, name);
end;

// 0x47406C
procedure map_get_name(name: PAnsiChar);
begin
  StrCopy(name, map_data.name);
end;

// 0x474094
function map_get_name_idx(name: PAnsiChar; map: Integer): Integer;
var
  mesg: TMessageListItem;
begin
  if name = nil then
    Exit(-1);

  name[0] := #0;

  // FIXME: Bad check.
  if (map = -1) or (map > MAP_COUNT) then
    Exit(-1);

  mesg.num := map;
  if not message_search(@map_msg_file, @mesg) then
    Exit(-1);

  StrCopy(name, mesg.text);

  Result := 0;
end;

// 0x474104
function map_get_elev_idx(map_num, elev: Integer): PAnsiChar;
var
  mesg: TMessageListItem;
begin
  if (map_num < 0) or (map_num >= MAP_COUNT) then
    Exit(nil);

  if (elev < 0) or (elev >= ELEVATION_COUNT) then
    Exit(nil);

  Result := getmsg(@map_msg_file, @mesg, map_num * 3 + elev + 200);
end;

// 0x474158
function is_map_idx_same(map_num1, map_num2: Integer): Boolean;
var
  index: Integer;
begin
  if (map_num1 < 0) or (map_num1 >= MAP_COUNT) then
    Exit(False);

  if (map_num2 < 0) or (map_num2 >= MAP_COUNT) then
    Exit(False);

  for index := 0 to 4 do
  begin
    if city_vs_city_idx_table[map_num1][index] = map_num2 then
      Exit(True);
  end;

  Result := False;
end;

// 0x4741B8
function get_map_idx_same(map_num1, map_num2: Integer): Integer;
begin
  if (map_num2 < 0) or (map_num2 >= 5) then
    Exit(-1);

  if (map_num1 < 0) or (map_num1 >= MAP_COUNT) then
    Exit(-1);

  Result := city_vs_city_idx_table[map_num1][map_num2];
end;

// 0x4741F4
function map_get_short_name(map_num: Integer): PAnsiChar;
var
  mesg: TMessageListItem;
begin
  Result := getmsg(@map_msg_file, @mesg, shrtnames[map_num]);
end;

// 0x474218
function map_get_description_idx(map_index: Integer): PAnsiChar;
var
  mesg: TMessageListItem;
begin
  if map_index > 0 then
  begin
    mesg.num := map_index + 100;
    if message_search(@map_msg_file, @mesg) then
      Exit(mesg.text);
  end;

  Result := nil;
end;

// 0x474248
function map_get_description: PAnsiChar;
begin
  Result := map_get_description_idx(map_data.field_34);
end;

// 0x47427C
function map_get_index_number: Integer;
begin
  Result := map_data.field_34;
end;

// 0x474284
function map_scroll(dx, dy: Integer): Integer;
var
  screenDx, screenDy: Integer;
  centerScreenX, centerScreenY: Integer;
  newCenterTile: Integer;
  r1, r2: TRect;
  width, pitch, height: Integer;
  src, dest: PByte;
  step: Integer;
  y: Integer;
begin
  if elapsed_time(map_last_scroll_time) < 33 then
    Exit(-2);

  map_last_scroll_time := get_time;

  screenDx := dx * 32;
  screenDy := dy * 24;

  if (screenDx = 0) and (screenDy = 0) then
    Exit(-1);

  gmouse_3d_off;

  tile_coord(tile_center_tile, @centerScreenX, @centerScreenY, map_elevation);
  centerScreenX := centerScreenX + screenDx + 16;
  centerScreenY := centerScreenY + screenDy + 8;

  newCenterTile := tile_num(centerScreenX, centerScreenY, map_elevation);
  if newCenterTile = -1 then
    Exit(-1);

  if tile_set_center(newCenterTile, 0) = -1 then
    Exit(-1);

  rectCopy(@r1, @map_display_rect);
  rectCopy(@r2, @r1);

  width := scr_size.lrx - scr_size.ulx + 1;
  pitch := width;
  height := scr_size.lry - scr_size.uly - 99;

  if screenDx <> 0 then
    width := width - 32;

  if screenDy <> 0 then
    height := height - 24;

  if screenDx < 0 then
    r2.lrx := r2.ulx - screenDx
  else
    r2.ulx := r2.lrx - screenDx;

  if screenDy < 0 then
  begin
    r1.lry := r1.uly - screenDy;
    src := display_buf + pitch * (height - 1);
    dest := display_buf + pitch * (scr_size.lry - scr_size.uly - 100);
    if screenDx < 0 then
      dest := dest + (-screenDx)
    else
      src := src + screenDx;
    step := -pitch;
  end
  else
  begin
    r1.uly := r1.lry - screenDy;
    dest := display_buf;
    src := display_buf + pitch * screenDy;

    if screenDx < 0 then
      dest := dest + (-screenDx)
    else
      src := src + screenDx;
    step := pitch;
  end;

  for y := 0 to height - 1 do
  begin
    Move(src^, dest^, width);
    dest := dest + step;
    src := src + step;
  end;

  if screenDx <> 0 then
    map_scroll_refresh(@r2);

  if screenDy <> 0 then
    map_scroll_refresh(@r1);

  win_draw(display_win);

  Result := 0;
end;

// 0x4744C0
function map_file_path(name: PAnsiChar): PAnsiChar;
begin
  if name^ <> '\' then
  begin
    // NOTE: Uppercased from "maps".
    StrLFmt(@map_path_buf[0], SizeOf(map_path_buf) - 1, 'MAPS\%s', [name]);
    Result := @map_path_buf[0];
  end
  else
    Result := name;
end;

// 0x4744E4
procedure map_new_map;
begin
  map_set_elevation(0);
  tile_set_center(20100, TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS);
  FillChar(map_state, SizeOf(map_state), 0);
  map_data.enteringElevation := 0;
  map_data.enteringRotation := 0;
  map_data.localVariablesCount := 0;
  map_data.version := 19;
  map_data.name[0] := #0;
  map_data.enteringTile := 20100;
  obj_remove_all;
  anim_stop;

  // NOTE: Uninline.
  map_free_global_vars;

  // NOTE: Uninline.
  map_free_local_vars;

  square_reset_;
  map_place_dude_and_mouse;
  tile_refresh_display;
end;

// 0x474614
function map_load(fileName: PAnsiChar): Integer;
var
  rc: Integer;
  stream: PDB_FILE;
  extension: PAnsiChar;
  file_path: PAnsiChar;
begin
  compat_strupr(fileName);

  rc := -1;

  extension := StrPos(fileName, '.MAP');
  if extension <> nil then
  begin
    StrCopy(extension, '.SAV');

    file_path := map_file_path(fileName);

    stream := db_fopen(file_path, 'rb');
    StrCopy(extension, '.MAP');
    db_fclose(stream);

    if stream <> nil then
    begin
      rc := map_load_in_game(fileName);
      PlayCityMapMusic;
    end;
  end;

  if rc = -1 then
  begin
    file_path := map_file_path(fileName);
    stream := db_fopen(file_path, 'rb');
    if stream <> nil then
    begin
      rc := map_load_file(stream);
      db_fclose(stream);
    end;

    if rc = 0 then
    begin
      StrCopy(map_data.name, fileName);
      obj_dude^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
    end;
  end;

  Result := rc;
end;

// 0x4746E4
function map_load_idx(map_index: Integer): Integer;
var
  name: array[0..15] of AnsiChar;
  rc: Integer;
begin
  scr_set_ext_param(map_script_id, map_index);

  if map_get_name_idx(@name[0], map_index) = -1 then
    Exit(-1);

  rc := map_load(@name[0]);

  PlayCityMapMusic;

  Result := rc;
end;

// 0x47471C
function map_load_file(stream: PDB_FILE): Integer;
var
  rc: Integer;
  error: PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  extension: PAnsiChar;
  obj: PObject;
  fid: Integer;
  script: u_scripts.PScript;
  message: array[0..99] of AnsiChar;
begin
  rc := 0;

  map_save_in_game(True);
  gsound_background_play('wind2', 12, 13, 16);
  map_disable_bk_processes;
  partyMemberPrepLoad;
  gmouse_disable_scrolling;
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_PLANET);
  db_register_callback(TDbReadCallback(@gameMouseRefreshImmediately), 8192);
  tile_disable_refresh;
  anim_stop;
  scr_disable;

  map_script_id := -1;

  error := nil;
  repeat
    error := 'Invalid file handle';
    if stream = nil then Break;

    error := 'Error reading header';
    if map_read_MapData(@map_data, stream) <> 0 then Break;

    error := 'Invalid map version';
    if map_data.version <> 19 then Break;

    obj_remove_all;

    if map_data.globalVariablesCount < 0 then
      map_data.globalVariablesCount := 0;

    if map_data.localVariablesCount < 0 then
      map_data.localVariablesCount := 0;

    error := 'Error allocating global vars';
    // NOTE: Uninline.
    if map_allocate_global_vars(map_data.globalVariablesCount) <> 0 then Break;

    error := 'Error loading global vars';
    // NOTE: Uninline.
    if map_load_global_vars(stream) <> 0 then Break;

    error := 'Error allocating local vars';
    // NOTE: Uninline.
    if map_allocate_local_vars(map_data.localVariablesCount) <> 0 then Break;

    error := 'Error loading local vars';
    if map_load_local_vars(stream) <> 0 then Break;

    if square_load(stream, map_data.flags) <> 0 then Break;

    error := 'Error reading scripts';
    if scr_load(stream) <> 0 then Break;

    error := 'Error reading objects';
    if obj_load(stream) <> 0 then Break;

    if (map_data.flags and 1) = 0 then
      map_fix_critter_combat_data;

    error := 'Error setting map elevation';
    if map_set_elevation(map_data.enteringElevation) <> 0 then Break;

    error := 'Error setting tile center';
    if tile_set_center(map_data.enteringTile, TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS) <> 0 then Break;

    light_set_ambient(LIGHT_LEVEL_MAX, False);
    obj_move_to_tile(obj_dude, tile_center_tile, map_elevation, nil);
    obj_set_rotation(obj_dude, map_data.enteringRotation, nil);
    map_match_map_number;

    if (map_data.flags and 1) = 0 then
    begin
      StrLFmt(@path[0], SizeOf(path) - 1, 'maps\%s', [PAnsiChar(@map_data.name[0])]);

      extension := StrPos(@path[0], '.MAP');
      if extension = nil then
        extension := StrPos(@path[0], '.map');

      if extension <> nil then
        extension^ := #0;

      StrCat(@path[0], '.GAM');
      game_load_info_vars(@path[0], 'MAP_GLOBAL_VARS:', @num_map_global_vars, @map_global_vars);
      map_data.globalVariablesCount := num_map_global_vars;
    end;

    scr_enable;

    if map_data.scriptIndex > 0 then
    begin
      error := 'Error creating new map script';
      if scr_new(@map_script_id, SCRIPT_TYPE_SYSTEM) = -1 then Break;

      fid := art_id(OBJ_TYPE_MISC, 12, 0, 0, 0);
      obj_new(@obj, fid, -1);
      obj^.Flags := obj^.Flags or (OBJECT_LIGHT_THRU or OBJECT_NO_SAVE or OBJECT_HIDDEN);
      obj_move_to_tile(obj, 1, 0, nil);
      obj^.Sid := map_script_id;
      if (map_data.flags and 1) = 0 then
        scr_set_ext_param(map_script_id, 1)
      else
        scr_set_ext_param(map_script_id, 0);

      scr_ptr(map_script_id, @script);
      script^.scr_script_idx := map_data.scriptIndex - 1;
      script^.scr_flags := script^.scr_flags or SCRIPT_FLAG_0x08;
      obj^.Id := new_obj_id;
      script^.scr_oid := obj^.Id;
      script^.owner := obj;
      scr_spatials_disable;
      exec_script_proc(map_script_id, SCRIPT_PROC_MAP_ENTER);
      scr_spatials_enable;
    end;

    error := nil;
  until True;

  if error <> nil then
  begin
    StrLFmt(@message[0], SizeOf(message) - 1, '%s while loading map, version = %d', [error, map_data.version]);
    debug_printf(@message[0]);
    map_new_map;
    rc := -1;
  end
  else
    obj_preload_art_cache(map_data.flags);

  partyMemberRecoverLoad;
  intface_show;
  map_place_dude_and_mouse;
  map_enable_bk_processes;
  gmouse_disable_scrolling;
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_PLANET);

  if scr_load_all_scripts = -1 then
    debug_printf(#10'   Error: scr_load_all_scripts failed!');

  scr_exec_map_enter_scripts;
  scr_exec_map_update_scripts;
  tile_enable_refresh;

  if map_state.map > 0 then
  begin
    if map_state.rotation >= 0 then
      obj_set_rotation(obj_dude, map_state.rotation, nil);
  end
  else
    tile_refresh_display;

  gtime_q_add;
  db_register_callback(nil, 0);
  gmouse_enable_scrolling;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);

  Result := rc;
end;

// 0x474D14
function map_load_in_game(fileName: PAnsiChar): Integer;
var
  mapName: array[0..15] of AnsiChar;
  rc: Integer;
begin
  debug_printf(#10'MAP: Loading SAVED map.');

  strmfe(@mapName[0], fileName, 'SAV');

  rc := map_load(@mapName[0]);

  if game_time() >= map_data.lastVisitTime then
  begin
    if ((game_time() - map_data.lastVisitTime) div GAME_TIME_TICKS_PER_HOUR) >= 24 then
      obj_unjam_all_locks;

    if map_age_dead_critters = -1 then
    begin
      debug_printf(#10'Error: Critter aging failed on map load!');
      Exit(-1);
    end;
  end;

  Result := rc;
end;

// 0x474DB0
function map_age_dead_critters: Integer;
var
  hoursSinceLastVisit: Integer;
  obj: PObject;
  agingType: Integer;
  capacity, count: Integer;
  objects: PPObject;
  objType: Integer;
  index: Integer;
  blood_pid: Integer;
  blood: PObject;
  proto: PProto;
  frame: Integer;
begin
  hoursSinceLastVisit := (game_time() - map_data.lastVisitTime) div GAME_TIME_TICKS_PER_HOUR;
  if hoursSinceLastVisit = 0 then
    Exit(0);

  obj := obj_find_first;
  while obj <> nil do
  begin
    if (PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER) and
      (obj <> obj_dude) and
      (not isPartyMember(obj)) and
      (not critter_is_dead(obj)) then
    begin
      obj^.Data.AsData.Critter.Combat.Maneuver := obj^.Data.AsData.Critter.Combat.Maneuver and (not CRITTER_MANUEVER_FLEEING);
      if critter_kill_count_type(obj) <> KILL_TYPE_ROBOT then
        critter_heal_hours(obj, hoursSinceLastVisit);
    end;
    obj := obj_find_next;
  end;

  if hoursSinceLastVisit > 6 * 24 then
    agingType := 1
  else if hoursSinceLastVisit > 14 * 24 then
    agingType := 2
  else
    Exit(0);

  capacity := 100;
  count := 0;
  objects := PPObject(mem_malloc(SizeOf(PObject) * capacity));

  obj := obj_find_first;
  while obj <> nil do
  begin
    objType := PID_TYPE(obj^.Pid);
    if objType = OBJ_TYPE_CRITTER then
    begin
      if (obj <> obj_dude) and critter_is_dead(obj) then
      begin
        if critter_kill_count_type(obj) <> KILL_TYPE_ROBOT then
        begin
          PPObject(PByte(objects) + count * SizeOf(PObject))^ := obj;
          Inc(count);

          if count >= capacity then
          begin
            capacity := capacity * 2;
            objects := PPObject(mem_realloc(objects, SizeOf(PObject) * capacity));
            if objects = nil then
            begin
              debug_printf(#10'Error: Out of Memory!');
              Exit(-1);
            end;
          end;
        end;
      end;
    end
    else if (agingType = 2) and (objType = OBJ_TYPE_MISC) and (obj^.Pid = $500000B) then
    begin
      PPObject(PByte(objects) + count * SizeOf(PObject))^ := obj;
      Inc(count);
      if count >= capacity then
      begin
        capacity := capacity * 2;
        objects := PPObject(mem_realloc(objects, SizeOf(PObject) * capacity));
        if objects = nil then
        begin
          debug_printf(#10'Error: Out of Memory!');
          Exit(-1);
        end;
      end;
    end;
    obj := obj_find_next;
  end;

  Result := 0;
  for index := 0 to count - 1 do
  begin
    obj := PPObject(PByte(objects) + index * SizeOf(PObject))^;
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    begin
      if (obj^.Pid <> 16777265) and (obj^.Pid <> 213) and (obj^.Pid <> 214) then
      begin
        blood_pid := $5000004;
        item_drop_all(obj, obj^.Tile);
      end
      else
        blood_pid := 213;

      if obj_pid_new(@blood, blood_pid) = -1 then
      begin
        Result := -1;
        Break;
      end;

      obj_move_to_tile(blood, obj^.Tile, obj^.Elevation, nil);

      proto_ptr(obj^.Pid, @proto);

      frame := roll_random(0, 3);
      if (proto^.Critter.Data.Flags and $800) <> 0 then
        frame := frame + 6
      else
      begin
        if (critter_kill_count_type(obj) <> KILL_TYPE_RAT) and
          (critter_kill_count_type(obj) <> KILL_TYPE_MANTIS) then
          frame := frame + 3;
      end;

      obj_set_frame(blood, frame, nil);
    end;

    register_clear(obj);
    obj_erase_object(obj, nil);
  end;

  mem_free(objects);

  // Result already set
end;

// 0x475160
function map_leave_map(transition: PMapTransition): Integer;
begin
  if transition = nil then
    Exit(-1);

  Move(transition^, map_state, SizeOf(map_state));

  if map_state.map = 0 then
    map_state.map := -2;

  if isInCombat then
    game_user_wants_to_quit := 1;

  Result := 0;
end;

// 0x4751A4
function map_check_state: Integer;
var
  town: Integer;
  ctx: TWorldMapContext;
begin
  if map_state.map = 0 then
    Exit(0);

  gmouse_3d_off;
  gmouse_set_cursor(MOUSE_CURSOR_NONE);

  if map_state.map = -1 then
  begin
    if not isInCombat then
    begin
      anim_stop;

      ctx.state := 0;
      ctx.town := our_town;
      ctx := town_map(ctx);

      if ctx.state = -1 then
        ctx.town := our_town;

      world_map(ctx);
      KillWorldWin;
      FillChar(map_state, SizeOf(map_state), 0);
    end;
  end
  else if map_state.map = -2 then
  begin
    if not isInCombat then
    begin
      anim_stop;
      ctx.state := 0;
      ctx.town := our_town;
      world_map(ctx);
      KillWorldWin;
      FillChar(map_state, SizeOf(map_state), 0);
    end;
  end
  else
  begin
    if not isInCombat then
    begin
      // NOTE: Uninline.
      map_load_idx(map_state.map);

      if (map_state.tile <> -1) and (map_state.tile <> 0) and
        (map_state.elevation >= 0) and (map_state.elevation < ELEVATION_COUNT) then
      begin
        obj_move_to_tile(obj_dude, map_state.tile, map_state.elevation, nil);
        map_set_elevation(map_state.elevation);
        obj_set_rotation(obj_dude, map_state.rotation, nil);
      end;

      if tile_set_center(obj_dude^.Tile, TILE_SET_CENTER_REFRESH_WINDOW) = -1 then
        debug_printf(#10'Error: map: attempt to center out-of-bounds!');

      FillChar(map_state, SizeOf(map_state), 0);

      town := xlate_mapidx_to_town(map_data.field_34);
      if worldmap_script_jump(town, 0) = -1 then
        debug_printf(#10'Error: couldn''t make jump on worldmap for map jump!');
    end;
  end;

  Result := 0;
end;

// 0x475394
procedure map_fix_critter_combat_data;
var
  obj: PObject;
begin
  obj := obj_find_first;
  while obj <> nil do
  begin
    if obj^.Pid <> -1 then
    begin
      if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
      begin
        if obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid = -1 then
          obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
      end;
    end;
    obj := obj_find_next;
  end;
end;

// 0x475460
function map_save: Integer;
var
  temp: array[0..79] of AnsiChar;
  masterPatchesPath: PAnsiChar;
  rc: Integer;
  mapFileName: PAnsiChar;
  stream: PDB_FILE;
begin
  temp[0] := #0;

  if config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @masterPatchesPath) then
  begin
    StrCat(@temp[0], masterPatchesPath);
    compat_mkdir(@temp[0]);

    StrCat(@temp[0], '\MAPS');
    compat_mkdir(@temp[0]);
  end;

  rc := -1;
  if map_data.name[0] <> #0 then
  begin
    mapFileName := map_file_path(map_data.name);
    stream := db_fopen(mapFileName, 'wb');
    if stream <> nil then
    begin
      rc := map_save_file(stream);
      db_fclose(stream);
    end
    else
    begin
      StrLFmt(@temp[0], SizeOf(temp) - 1, 'Unable to open %s to write!', [PAnsiChar(@map_data.name[0])]);
      debug_printf(@temp[0]);
    end;

    if rc = 0 then
    begin
      StrLFmt(@temp[0], SizeOf(temp) - 1, '%s saved.', [PAnsiChar(@map_data.name[0])]);
      debug_printf(@temp[0]);
    end;
  end
  else
    debug_printf(#10'Error: map_save: map header corrupt!');

  Result := rc;
end;

// 0x475590
function map_save_file(stream: PDB_FILE): Integer;
var
  elevation, tile: Integer;
  fid: Integer;
  obj: PObject;
  err: array[0..79] of AnsiChar;
begin
  if stream = nil then
    Exit(-1);

  scr_disable;

  for elevation := 0 to ELEVATION_COUNT - 1 do
  begin
    tile := 0;
    while tile < SQUARE_GRID_SIZE do
    begin
      fid := art_id(OBJ_TYPE_TILE, square[elevation]^.field_0[tile] and $FFF, 0, 0, 0);
      if fid <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
        Break;

      fid := art_id(OBJ_TYPE_TILE, (square[elevation]^.field_0[tile] shr 16) and $FFF, 0, 0, 0);
      if fid <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
        Break;

      Inc(tile);
    end;

    if tile = SQUARE_GRID_SIZE then
    begin
      obj := obj_find_first_at(elevation);
      if obj <> nil then
      begin
        while (obj <> nil) and ((obj^.Flags and OBJECT_NO_SAVE) <> 0) do
          obj := obj_find_next_at;

        if obj <> nil then
          map_data.flags := map_data.flags and (not map_data_elev_flags[elevation])
        else
          map_data.flags := map_data.flags or map_data_elev_flags[elevation];
      end
      else
        map_data.flags := map_data.flags or map_data_elev_flags[elevation];
    end
    else
      map_data.flags := map_data.flags and (not map_data_elev_flags[elevation]);
  end;

  map_data.localVariablesCount := num_map_local_vars;
  map_data.globalVariablesCount := num_map_global_vars;
  map_data.darkness := 1;

  map_write_MapData(@map_data, stream);

  if map_data.globalVariablesCount <> 0 then
    db_fwriteInt32List(stream, map_global_vars, map_data.globalVariablesCount);

  if map_data.localVariablesCount <> 0 then
    db_fwriteInt32List(stream, map_local_vars, map_data.localVariablesCount);

  for elevation := 0 to ELEVATION_COUNT - 1 do
  begin
    if (map_data.flags and map_data_elev_flags[elevation]) = 0 then
      db_fwriteInt32List(stream, @square[elevation]^.field_0[0], SQUARE_GRID_SIZE);
  end;

  if scr_save(stream) = -1 then
  begin
    StrLFmt(@err[0], SizeOf(err) - 1, 'Error saving scripts in %s', [PAnsiChar(@map_data.name[0])]);
    win_msg(@err[0], 80, 80, colorTable[31744]);
  end;

  if obj_save(stream) = -1 then
  begin
    StrLFmt(@err[0], SizeOf(err) - 1, 'Error saving objects in %s', [PAnsiChar(@map_data.name[0])]);
    win_msg(@err[0], 80, 80, colorTable[31744]);
  end;

  scr_enable;

  Result := 0;
end;

// 0x4758A8
function map_save_in_game(a1: Boolean): Integer;
var
  script: u_scripts.PScript;
  name: array[0..15] of AnsiChar;
begin
  if map_data.name[0] = #0 then
    Exit(0);

  anim_stop;

  if a1 then
  begin
    partyMemberPrepLoad;
    partyMemberPrepItemSaveAll;
    queue_leaving_map;
    scr_exec_map_exit_scripts;

    if map_script_id <> -1 then
      scr_ptr(map_script_id, @script);

    gtime_q_add;
    obj_reset_roof;
  end;

  map_data.flags := map_data.flags or MAP_SAVED;
  map_data.lastVisitTime := game_time();

  if a1 and (not YesWriteIndex(map_get_index_number, map_elevation)) then
  begin
    debug_printf(#10'Not saving RANDOM encounter map.');

    StrCopy(@name[0], map_data.name);
    strmfe(map_data.name, @name[0], 'SAV');
    MapDirEraseFile('MAPS\', map_data.name);
    StrCopy(map_data.name, @name[0]);
  end
  else
  begin
    debug_printf(#10' Saving ".SAV" map.');

    StrCopy(@name[0], map_data.name);
    strmfe(map_data.name, @name[0], 'SAV');
    if map_save = -1 then
      Exit(-1);

    StrCopy(map_data.name, @name[0]);

    automap_pip_save;
  end;

  if a1 then
  begin
    map_data.name[0] := #0;
    obj_remove_all;
    proto_remove_all;
    square_reset_;
    gtime_q_add;
  end;

  Result := 0;
end;

// 0x475A44
procedure map_setup_paths;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  masterPatchesPath: PAnsiChar;
begin
  if config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @masterPatchesPath) then
    StrCopy(@path[0], masterPatchesPath)
  else
    StrCopy(@path[0], 'DATA');

  compat_mkdir(@path[0]);

  StrCat(@path[0], '\MAPS');
  compat_mkdir(@path[0]);
end;

// 0x475AEC
function map_match_map_name(name: PAnsiChar): Integer;
var
  temp: array[0..15] of AnsiChar;
  extension: PAnsiChar;
  index: Integer;
  candidate: array[0..15] of AnsiChar;
begin
  StrCopy(@temp[0], name);
  compat_strupr(@temp[0]);

  extension := StrPos(@temp[0], '.SAV');
  if extension <> nil then
    StrCopy(extension, '.MAP');

  for index := 0 to MAP_COUNT - 1 do
  begin
    if map_get_name_idx(@candidate[0], index) = 0 then
    begin
      if StrComp(@temp[0], @candidate[0]) = 0 then
        Exit(index);
    end;
  end;

  Result := -1;
end;

// 0x475B70
procedure map_match_map_number;
var
  temp: array[0..15] of AnsiChar;
  extension: PAnsiChar;
  index: Integer;
  candidate: array[0..15] of AnsiChar;
begin
  if StrPos(map_data.name, '.sav') <> nil then
    Exit;

  if StrComp(map_data.name, 'TMP$MAP#.MAP') = 0 then
    Exit;

  StrCopy(@temp[0], map_data.name);
  compat_strupr(@temp[0]);

  extension := StrPos(@temp[0], '.SAV');
  if extension <> nil then
    StrCopy(extension, '.MAP');

  for index := 0 to MAP_COUNT - 1 do
  begin
    if map_get_name_idx(@candidate[0], index) = 0 then
    begin
      if StrComp(@temp[0], @candidate[0]) = 0 then
      begin
        map_data.field_34 := index;
        Exit;
      end;
    end;
  end;

  debug_printf(#10'Note: Couldn''t match name for map!');
  map_data.field_34 := -1;
end;

// 0x475C3C
procedure map_display_draw(rect: PRect);
begin
  win_draw_rect(display_win, rect);
end;

// 0x475C50
procedure map_scroll_refresh_game(rect: PRect);
var
  rectToUpdate: TRect;
begin
  if rect_inside_bound(rect, @map_display_rect, @rectToUpdate) = -1 then
    Exit;

  // CE: Clear dirty rect to prevent most of the visual artifacts near map edges.
  buf_fill(display_buf + rectToUpdate.uly * rectGetWidth(@map_display_rect) + rectToUpdate.ulx,
    rectGetWidth(@rectToUpdate),
    rectGetHeight(@rectToUpdate),
    rectGetWidth(@map_display_rect),
    0);

  square_render_floor(@rectToUpdate, map_elevation);
  grid_render(@rectToUpdate, map_elevation);
  obj_render_pre_roof(@rectToUpdate, map_elevation);
  square_render_roof(@rectToUpdate, map_elevation);
  bounds_render(@rectToUpdate, map_elevation);
  obj_render_post_roof(@rectToUpdate, map_elevation);
end;

// 0x475CB0
procedure map_scroll_refresh_mapper(rect: PRect);
var
  rectToUpdate: TRect;
begin
  if rect_inside_bound(rect, @map_display_rect, @rectToUpdate) = -1 then
    Exit;

  buf_fill(display_buf + rectToUpdate.uly * rectGetWidth(@map_display_rect) + rectToUpdate.ulx,
    rectGetWidth(@rectToUpdate),
    rectGetHeight(@rectToUpdate),
    rectGetWidth(@map_display_rect),
    0);

  square_render_floor(@rectToUpdate, map_elevation);
  grid_render(@rectToUpdate, map_elevation);
  obj_render_pre_roof(@rectToUpdate, map_elevation);
  square_render_roof(@rectToUpdate, map_elevation);
  obj_render_post_roof(@rectToUpdate, map_elevation);
end;

// 0x475D50
function map_allocate_global_vars(count: Integer): Integer;
begin
  map_free_global_vars;

  if count <> 0 then
  begin
    map_global_vars := PInteger(mem_malloc(SizeOf(Integer) * count));
    if map_global_vars = nil then
      Exit(-1);

    SetLength(map_global_pointers, count);
  end;

  num_map_global_vars := count;

  Result := 0;
end;

// 0x475DA4
procedure map_free_global_vars;
begin
  if map_global_vars <> nil then
  begin
    mem_free(map_global_vars);
    map_global_vars := nil;
    num_map_global_vars := 0;
  end;

  SetLength(map_global_pointers, 0);
end;

// 0x475DC8
function map_load_global_vars(stream: PDB_FILE): Integer;
begin
  if db_freadInt32List(stream, map_global_vars, num_map_global_vars) <> 0 then
    Exit(-1);

  Result := 0;
end;

// 0x475DEC
function map_allocate_local_vars(count: Integer): Integer;
begin
  map_free_local_vars;

  if count <> 0 then
  begin
    map_local_vars := PInteger(mem_malloc(SizeOf(Integer) * count));
    if map_local_vars = nil then
      Exit(-1);

    SetLength(map_local_pointers, count);
  end;

  num_map_local_vars := count;

  Result := 0;
end;

// 0x475E40
procedure map_free_local_vars;
begin
  if map_local_vars <> nil then
  begin
    mem_free(map_local_vars);
    map_local_vars := nil;
    num_map_local_vars := 0;
  end;

  SetLength(map_local_pointers, 0);
end;

// 0x475E64
function map_load_local_vars(stream: PDB_FILE): Integer;
begin
  if db_freadInt32List(stream, map_local_vars, num_map_local_vars) <> 0 then
    Exit(-1);

  Result := 0;
end;

// 0x475E88
procedure map_place_dude_and_mouse;
begin
  if obj_dude <> nil then
  begin
    if FID_ANIM_TYPE(obj_dude^.Fid) <> ANIM_STAND then
    begin
      obj_set_frame(obj_dude, 0, nil);
      obj_dude^.Fid := art_id(OBJ_TYPE_CRITTER, obj_dude^.Fid and $FFF,
        ANIM_STAND, (obj_dude^.Fid and $F000) shr 12, obj_dude^.Rotation + 1);
    end;

    if obj_dude^.Tile = -1 then
    begin
      obj_move_to_tile(obj_dude, tile_center_tile, map_elevation, nil);
      obj_set_rotation(obj_dude, map_data.enteringRotation, nil);
    end;

    obj_set_light(obj_dude, 4, $10000, nil);
    obj_dude^.Flags := obj_dude^.Flags or OBJECT_NO_SAVE;

    dude_stand(obj_dude, obj_dude^.Rotation, obj_dude^.Fid);
    partyMemberSyncPosition;
  end;

  gmouse_3d_reset_fid;
  gmouse_3d_on;
end;

// 0x475F58
procedure square_init_;
var
  elevation: Integer;
begin
  for elevation := 0 to ELEVATION_COUNT - 1 do
    square[elevation] := @square_data[elevation];
end;

// 0x475F78
procedure square_reset_;
var
  elevation: Integer;
  p: PInteger;
  y, x: Integer;
  fid: Integer;
  v3, v4: Integer;
begin
  for elevation := 0 to ELEVATION_COUNT - 1 do
  begin
    p := @square[elevation]^.field_0[0];
    for y := 0 to SQUARE_GRID_HEIGHT - 1 do
    begin
      for x := 0 to SQUARE_GRID_WIDTH - 1 do
      begin
        fid := p^;
        fid := fid and (not $FFFF);
        p^ := (((art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) and $FFF) or (((fid shr 16) and $F000) shr 12)) shl 16) or (p^ and $FFFF);

        fid := p^;
        v3 := (fid and $F000) shr 12;
        v4 := (art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) and $FFF) or v3;

        fid := fid and (not $FFFF);

        p^ := v4 or ((fid shr 16) shl 16);

        Inc(p);
      end;
    end;
  end;
end;

// 0x476084
function square_load(stream: PDB_FILE; a2: Integer): Integer;
var
  elevation, tile: Integer;
  arr: PInteger;
  v6, v7, v8, v9: Integer;
begin
  square_reset_;

  for elevation := 0 to ELEVATION_COUNT - 1 do
  begin
    if (a2 and map_data_elev_flags[elevation]) = 0 then
    begin
      arr := @square[elevation]^.field_0[0];
      if db_freadInt32List(stream, arr, SQUARE_GRID_SIZE) <> 0 then
        Exit(-1);

      for tile := 0 to SQUARE_GRID_SIZE - 1 do
      begin
        v6 := PInteger(PByte(arr) + tile * SizeOf(Integer))^;
        v6 := v6 and (not $FFFF);
        v6 := v6 shr 16;

        v7 := (v6 and $F000) shr 12;
        v7 := v7 and (not $01);

        v8 := v6 and $FFF;
        v9 := PInteger(PByte(arr) + tile * SizeOf(Integer))^ and $FFFF;
        PInteger(PByte(arr) + tile * SizeOf(Integer))^ := ((v8 or (v7 shl 12)) shl 16) or v9;
      end;
    end;
  end;

  Result := 0;
end;

// 0x476120
function map_write_MapData(ptr: PMapHeader; stream: PDB_FILE): Integer;
begin
  if db_fwriteInt32(stream, ptr^.version) = -1 then Exit(-1);
  if db_fwriteInt8List(stream, PShortInt(@ptr^.name[0]), 16) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.enteringTile) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.enteringElevation) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.enteringRotation) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.localVariablesCount) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.scriptIndex) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.flags) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.darkness) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.globalVariablesCount) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.field_34) = -1 then Exit(-1);
  if db_fwriteInt32(stream, ptr^.lastVisitTime) = -1 then Exit(-1);
  if db_fwriteInt32List(stream, @ptr^.field_3C[0], 44) = -1 then Exit(-1);

  Result := 0;
end;

// 0x47621C
function map_read_MapData(ptr: PMapHeader; stream: PDB_FILE): Integer;
begin
  if db_freadInt32(stream, @ptr^.version) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@ptr^.name[0]), 16) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.enteringTile) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.enteringElevation) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.enteringRotation) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.localVariablesCount) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.scriptIndex) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.flags) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.darkness) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.globalVariablesCount) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.field_34) = -1 then Exit(-1);
  if db_freadInt32(stream, @ptr^.lastVisitTime) = -1 then Exit(-1);
  if db_freadInt32List(stream, @ptr^.field_3C[0], 44) = -1 then Exit(-1);

  Result := 0;
end;

initialization
  byte_50B058[0] := #0;
  StrCopy(@_aErrorF2[0], 'ERROR! F2');

  map_scroll_refresh := @map_scroll_refresh_game;
  map_data_elev_flags[0] := 2;
  map_data_elev_flags[1] := 4;
  map_data_elev_flags[2] := 8;

  map_last_scroll_time := 0;
  map_bk_enabled := False;
  map_script_id := -1;
  map_local_vars := nil;
  map_global_vars := nil;
  num_map_local_vars := 0;
  num_map_global_vars := 0;
  map_elevation := 0;
  FillChar(map_state, SizeOf(map_state), 0);
  FillChar(map_display_rect, SizeOf(map_display_rect), 0);
  display_buf := nil;
  display_win := 0;
  FillChar(map_data, SizeOf(map_data), 0);

end.
