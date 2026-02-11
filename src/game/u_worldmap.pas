{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/worldmap.h + worldmap.cc
// World map navigation, town map selection, and random encounter system.
unit u_worldmap;

interface

uses
  u_db;

const
  // MapFlags
  MAP_SAVED              = $01;
  MAP_DEAD_BODIES_AGE    = $02;
  MAP_PIPBOY_ACTIVE      = $04;
  MAP_CAN_REST_ELEVATION_0 = $08;
  MAP_CAN_REST_ELEVATION_1 = $10;
  MAP_CAN_REST_ELEVATION_2 = $20;

  // City
  TOWN_VAULT_13      = 0;
  TOWN_VAULT_15      = 1;
  TOWN_SHADY_SANDS   = 2;
  TOWN_JUNKTOWN      = 3;
  TOWN_RAIDERS       = 4;
  TOWN_NECROPOLIS    = 5;
  TOWN_THE_HUB       = 6;
  TOWN_BROTHERHOOD   = 7;
  TOWN_MILITARY_BASE = 8;
  TOWN_THE_GLOW      = 9;
  TOWN_BONEYARD      = 10;
  TOWN_CATHEDRAL     = 11;
  TOWN_COUNT         = 12;
  TOWN_SPECIAL_12    = 12;
  TOWN_SPECIAL_13    = 13;
  TOWN_SPECIAL_14    = 14;

  // Map
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
  MAP_RAIDERS_MAP = 24;
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

  // TerrainType
  TERRAIN_TYPE_DESERT   = 0;
  TERRAIN_TYPE_MOUNTAIN = 1;
  TERRAIN_TYPE_CITY     = 2;
  TERRAIN_TYPE_COAST    = 3;

  // WorldmapFrm
  WORLDMAP_FRM_LITTLE_RED_BUTTON_NORMAL  = 0;
  WORLDMAP_FRM_LITTLE_RED_BUTTON_PRESSED = 1;
  WORLDMAP_FRM_BOX                       = 2;
  WORLDMAP_FRM_LABELS                    = 3;
  WORLDMAP_FRM_LOCATION_MARKER           = 4;
  WORLDMAP_FRM_DESTINATION_MARKER_BRIGHT = 5;
  WORLDMAP_FRM_DESTINATION_MARKER_DARK   = 6;
  WORLDMAP_FRM_RANDOM_ENCOUNTER_BRIGHT   = 7;
  WORLDMAP_FRM_RANDOM_ENCOUNTER_DARK     = 8;
  WORLDMAP_FRM_WORLDMAP                  = 9;
  WORLDMAP_FRM_MONTHS                    = 10;
  WORLDMAP_FRM_NUMBERS                   = 11;
  WORLDMAP_FRM_HOTSPOT_NORMAL            = 12;
  WORLDMAP_FRM_HOTSPOT_PRESSED           = 13;
  WORLDMAP_FRM_COUNT                     = 14;

  // TownmapFrm
  TOWNMAP_FRM_BOX                       = 0;
  TOWNMAP_FRM_LABELS                    = 1;
  TOWNMAP_FRM_HOTSPOT_PRESSED           = 2;
  TOWNMAP_FRM_HOTSPOT_NORMAL            = 3;
  TOWNMAP_FRM_LITTLE_RED_BUTTON_NORMAL  = 4;
  TOWNMAP_FRM_LITTLE_RED_BUTTON_PRESSED = 5;
  TOWNMAP_FRM_MONTHS                    = 6;
  TOWNMAP_FRM_NUMBERS                   = 7;
  TOWNMAP_FRM_COUNT                     = 8;

type
  PWorldMapContext = ^TWorldMapContext;
  TWorldMapContext = record
    state: SmallInt;
    town: SmallInt;
    section: SmallInt;
  end;

var
  world_win: Integer;
  our_section: Integer;
  our_town: Integer;

function init_world_map: Integer;
function save_world_map(stream: PDB_FILE): Integer;
function load_world_map(stream: PDB_FILE): Integer;
function world_map(ctx: TWorldMapContext): Integer;
function town_map(ctx: TWorldMapContext): TWorldMapContext;
procedure KillWorldWin;
function worldmap_script_jump(city, a2: Integer): Integer;
function xlate_mapidx_to_town(map_idx: Integer): Integer;
function PlayCityMapMusic: Integer;

implementation

uses
  SysUtils,
  u_platform_compat,
  u_art,
  u_color,
  u_debug,
  u_memory,
  u_gnw,
  u_gnw_types,
  u_button,
  u_text,
  u_mouse,
  u_input,
  u_svga,
  u_grbuf,
  u_kb,
  u_object_types,
  u_game_vars,
  u_perk_defs,
  u_stat_defs,
  u_skill_defs,
  u_fps_limiter,
  u_graphlib,
  u_gmouse,
  u_gsound,
  u_game,
  u_stat,
  u_perk,
  u_skill,
  u_roll,
  u_queue,
  u_party,
  u_map,
  u_cycle,
  u_object,
  u_intface,
  u_display,
  u_gmovie,
  u_options,
  u_bmpdlog,
  u_message,
  u_int_sound,
  u_scripts,
  u_critter,
  u_tile,
  u_worldmap_walkmask;

const
  WM_WINDOW_WIDTH  = 640;
  WM_WINDOW_HEIGHT = 480;
  WM_WORLDMAP_WIDTH = 1400;

  LOCATION_MARKER_WIDTH  = 5;
  LOCATION_MARKER_HEIGHT = 5;

  DESTINATION_MARKER_WIDTH  = 11;
  DESTINATION_MARKER_HEIGHT = 11;

  RANDOM_ENCOUNTER_ICON_WIDTH  = 7;
  RANDOM_ENCOUNTER_ICON_HEIGHT = 11;

  HOTSPOT_WIDTH  = 25;
  HOTSPOT_HEIGHT = 13;

  DAY_X   = 487;
  DAY_Y   = 12;
  MONTH_X = 513;
  MONTH_Y = 12;
  YEAR_X  = 548;
  YEAR_Y  = 12;
  TIME_X  = 593;
  TIME_Y  = 12;

  VIEWPORT_MAX_X = 950;
  VIEWPORT_MAX_Y = 1058;

  // Mouse cursor types from gmouse.h
  MOUSE_CURSOR_NONE                   = 0;
  MOUSE_CURSOR_ARROW                  = 1;
  MOUSE_CURSOR_SMALL_ARROW_UP         = 2;
  MOUSE_CURSOR_SMALL_ARROW_DOWN       = 3;
  MOUSE_CURSOR_SCROLL_NW              = 4;
  MOUSE_CURSOR_SCROLL_N               = 5;
  MOUSE_CURSOR_SCROLL_NE              = 6;
  MOUSE_CURSOR_SCROLL_E               = 7;
  MOUSE_CURSOR_SCROLL_SE              = 8;
  MOUSE_CURSOR_SCROLL_S               = 9;
  MOUSE_CURSOR_SCROLL_SW              = 10;
  MOUSE_CURSOR_SCROLL_W               = 11;
  MOUSE_CURSOR_SCROLL_NW_INVALID      = 12;
  MOUSE_CURSOR_SCROLL_N_INVALID       = 13;
  MOUSE_CURSOR_SCROLL_NE_INVALID      = 14;
  MOUSE_CURSOR_SCROLL_E_INVALID       = 15;
  MOUSE_CURSOR_SCROLL_SE_INVALID      = 16;
  MOUSE_CURSOR_SCROLL_S_INVALID       = 17;
  MOUSE_CURSOR_SCROLL_SW_INVALID      = 18;
  MOUSE_CURSOR_SCROLL_W_INVALID       = 19;

type
  TCityLocationEntry = record
    column: Integer;
    row: Integer;
  end;

  TTownHotSpotEntry = record
    x: SmallInt;
    y: SmallInt;
    map_idx: SmallInt;
    name: array[0..15] of AnsiChar;
  end;

  TSpclEncRangeEntry = record
    start_: SmallInt;
    end_: SmallInt;
  end;

  TBrnPosEntry = record
    x: SmallInt;
    y: SmallInt;
    bid: Integer;
  end;

{ Forward declarations of statics }
procedure UpdVisualArea; forward;
function CheckEvents: Integer; forward;
function LoadTownMap(const filename: PAnsiChar; map_idx: Integer): Integer; forward;
procedure TargetTown(city: Integer); forward;
function InitWorldMapData: Integer; forward;
procedure UnInitWorldMapData; forward;
procedure UpdateTownStatus; forward;
function InCity(x, y: LongWord): Integer; forward;
procedure world_move_init; forward;
function world_move_step: Integer; forward;
procedure block_map(x, y: LongWord; dst: PByte); forward;
procedure DrawTownLabels(src, dst: PByte); forward;
procedure DrawMapTime(is_town_map: Integer); forward;
procedure map_num(value, digits, x, y, is_town_map: Integer); forward;
procedure HvrOffBtn(a1, a2: Integer); cdecl; forward;
function RegTMAPsels(win, city: Integer): Integer; forward;
procedure UnregTMAPsels(count: Integer); forward;
procedure DrawTMAPsels(win, city: Integer); forward;
procedure CalcTimeAdder; forward;
procedure BlackOut; forward;

const
  mouse_table1: array[0..2, 0..2, 0..1] of Byte = (
    ((1, 1), (0, 1), (1, 1)),
    ((1, 0), (0, 0), (1, 0)),
    ((1, 1), (0, 1), (1, 1))
  );

  mouse_table2: array[0..2, 0..2, 0..3] of Integer = (
    ((MOUSE_CURSOR_SCROLL_NW, 0, 0, 0), (MOUSE_CURSOR_SCROLL_N, 0, 0, 0), (MOUSE_CURSOR_SCROLL_NE, 0, 0, 0)),
    ((MOUSE_CURSOR_SCROLL_W, 0, 0, 0),  (MOUSE_CURSOR_ARROW, 0, 0, 0),    (MOUSE_CURSOR_SCROLL_E, 0, 0, 0)),
    ((MOUSE_CURSOR_SCROLL_SW, 0, 0, 0), (MOUSE_CURSOR_SCROLL_S, 0, 0, 0), (MOUSE_CURSOR_SCROLL_SE, 0, 0, 0))
  );

  mouse_table3: array[0..2, 0..2, 0..3] of Integer = (
    ((MOUSE_CURSOR_SCROLL_NW_INVALID, 0, 0, 0), (MOUSE_CURSOR_SCROLL_N_INVALID, 0, 0, 0), (MOUSE_CURSOR_SCROLL_NE_INVALID, 0, 0, 0)),
    ((MOUSE_CURSOR_SCROLL_W_INVALID, 0, 0, 0),  (MOUSE_CURSOR_ARROW, 0, 0, 0),            (MOUSE_CURSOR_SCROLL_E_INVALID, 0, 0, 0)),
    ((MOUSE_CURSOR_SCROLL_SW_INVALID, 0, 0, 0), (MOUSE_CURSOR_SCROLL_S_INVALID, 0, 0, 0), (MOUSE_CURSOR_SCROLL_SE_INVALID, 0, 0, 0))
  );

  wmapids: array[0..WORLDMAP_FRM_COUNT - 1] of Integer = (
    8, 9, 136, 137, 138, 139, 153, 154, 155, 135, 129, 82, 168, 223
  );

  tmapids: array[0..TOWNMAP_FRM_COUNT - 1] of Integer = (
    136, 137, 223, 168, 8, 9, 129, 82
  );

  BttnYtab: array[0..TOWN_COUNT - 1] of SmallInt = (
    61, 88, 115, 143, 171, 200, 228, 256, 283, 310, 338, 367
  );

  OceanSeeXTable: array[0..29] of Integer = (
    0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 3, 4, 5, 5,
    5, 5, 8, 11, 12, 14, 14, 17, 18, 19, 19, 20, 20, 20, 21
  );

  SpclEncRange: array[0..5] of TSpclEncRangeEntry = (
    (start_: 1;  end_: 30),
    (start_: 31; end_: 50),
    (start_: 51; end_: 70),
    (start_: 71; end_: 80),
    (start_: 81; end_: 90),
    (start_: 91; end_: 100)
  );

  WorldTerraTable: array[0..29, 0..27] of Byte = (
    (1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0),
    (1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0),
    (1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,1,1,0,0,0,0),
    (1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,1,0,0,0,0),
    (1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,0,1,1,1,0,0,0,0,0,0,0,0),
    (1,1,1,1,2,0,0,0,0,0,0,0,1,1,1,1,0,0,0,1,1,0,1,0,0,0,0,0),
    (3,1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,1,0,0,0,0,0,2,2),
    (3,3,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,1,0,1,0,0,0,2,0),
    (3,3,3,1,0,0,0,0,0,0,0,0,0,1,2,1,1,0,0,0,1,1,1,0,0,0,0,0),
    (3,3,3,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0),
    (3,3,3,3,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0),
    (3,3,3,3,3,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0),
    (3,3,3,3,3,0,0,0,0,2,0,0,0,0,1,1,0,0,0,0,0,0,2,0,0,0,0,0),
    (3,3,3,3,3,3,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,2,2,0,0,0,0,0),
    (3,3,3,3,3,3,2,1,0,0,0,0,0,0,0,0,0,2,0,0,0,0,2,0,0,0,0,0),
    (3,3,3,3,3,3,2,2,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0),
    (3,3,3,3,3,3,3,3,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,0,0,0,2,1,1,1,0,0,0,0,0,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,2,2,0,2,2,2,2,0,0,1,1,0,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,2,0,0,0,0,1,0,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,3,0,0,1,1,1,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,1,1,1,1,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,1,1,1,1,1,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,1,1,1,1,1,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,1,1,1,1,1,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,0,0,0,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,1,0,0,0),
    (3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0)
  );

  WorldEcountChanceTable: array[0..29, 0..27] of Byte = (
    (3,3,3,3,3,3,3,3,3,2,2,1,1,1,0,0,0,0,1,1,1,2,2,2,3,3,3,3),
    (3,3,3,3,3,3,3,3,3,2,2,1,1,1,0,0,0,0,0,1,1,1,2,2,2,3,3,3),
    (3,3,3,3,3,3,3,3,3,2,2,2,1,1,0,0,0,0,0,1,1,1,1,1,1,1,3,3),
    (3,3,3,3,3,3,3,3,3,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,3,3),
    (3,3,3,3,3,3,3,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2),
    (2,2,2,0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,1,1,1,1,1,1,2,2,2),
    (2,2,2,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,2,1,1,1,1,1,1,2,2,2),
    (2,2,2,2,2,2,2,2,0,0,1,1,1,1,2,2,2,2,2,1,1,1,1,1,1,2,2,2),
    (2,2,2,2,2,2,1,1,1,1,1,1,1,2,2,2,2,2,2,1,1,1,1,1,1,1,2,2),
    (2,2,2,2,2,1,1,2,2,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2),
    (2,2,2,2,2,1,1,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2),
    (2,2,2,2,2,2,1,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,2,2,2,2,1,2,1,1,1,1,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,1,1,1,1,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,2,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,2,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,2,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,2,2),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3),
    (2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3)
  );

  WorldEcounTable: array[0..29, 0..27] of Byte = (
    (11,11,11,11,11,11,11,11,11, 2, 2, 2, 2, 2, 2, 4, 4, 4, 2, 2, 5, 5, 5, 0, 0, 0, 0, 0),
    (11,11,11,11,11,11,11,11,11, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 5, 5, 5, 5, 5, 0, 0, 0, 0),
    (11,11,11,11,11,11,11,11,11, 0, 2, 2, 2, 2, 2, 4, 4, 4, 4, 2, 5, 5, 5, 5, 2, 0, 0, 0),
    (11,11,11,11,11,11,11,11,11, 0, 0, 2, 2, 2, 2, 2, 4, 4, 4, 2, 0, 0, 6, 6, 2, 0, 0, 0),
    (11,11,11,11,11,11,11,11,11, 0, 0, 0, 2, 2, 2, 2, 4, 4, 2, 2, 0, 0, 6, 6, 2, 0, 0, 0),
    (11,11,11,11,11,11,11,11,11, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 2, 2, 0, 2, 0, 0, 0, 0, 0),
    (15, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0),
    (15,15, 2, 2, 2, 0, 0, 0, 0, 0,10,10,10, 2, 2, 2, 2, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0),
    (15,15,15, 2, 0, 0, 0, 0, 0,10,10,10,10, 2, 0, 2, 2, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0),
    (15,15,15, 0, 0, 0, 0, 0, 0,10,10,10,10, 2, 2, 2, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0),
    (15,15,15,15, 0, 0, 0, 0, 0,10,10,10,10, 2, 2, 2, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0),
    (15,15,15,15,15, 0, 0, 0, 0, 0,10,10,10, 0, 2, 2, 7, 7, 7, 7, 7, 9, 9, 9, 9, 0, 0, 0),
    (15,15,15,15,15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 8, 8, 0, 9, 9, 9, 9, 9, 0, 0, 0),
    (15,15,15,15,15,15, 0, 2, 0, 0, 0, 0, 0, 0, 2,14, 8, 8, 8, 0, 9, 9, 9, 9, 9, 0, 0, 0),
    (15,15,15,15,15,15, 0, 2, 0, 0, 0, 0, 0, 0,14,14, 8, 8, 8, 0, 9, 9, 9, 9, 9, 0, 0, 0),
    (15,15,15,15,15,15, 1, 1, 1, 3, 1, 1, 1, 1, 1,14, 8, 8, 8, 8, 8, 9, 9, 9, 9,10, 1, 1),
    (15,15,15,15,15,15,15,15, 1, 1, 3, 3, 3,13,13,13,13,13,13,13,13, 1, 9, 9, 9, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15, 1, 1,13,13,13,13,13,13,13,13, 1, 1, 1, 1, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,13,13,13,13,13,13,13,13,13,13, 3, 1, 1, 1, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,13,13,13,13,13,13,13, 3, 1, 1, 1, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,13,13,15,13,13,13, 3, 3, 3, 1, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1, 1, 3, 3, 3, 3, 3, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1, 1, 3, 3, 3, 3, 3, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1, 3, 3, 3, 3, 3, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1, 3, 3, 3,12,12,12,12, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 3, 3, 3,12,12,12,12, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 3, 3,12,12,12,12, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 3,12,12,12,12,12, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1,12,12, 3, 1, 1, 1),
    (15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15, 1, 1, 1, 1, 1, 1, 1)
  );

  city_location: array[0..TOWN_COUNT - 1] of TCityLocationEntry = (
    (column: 16; row: 1),
    (column: 25; row: 1),
    (column: 21; row: 1),
    (column: 17; row: 10),
    (column: 22; row: 3),
    (column: 22; row: 13),
    (column: 17; row: 14),
    (column: 12; row: 9),
    (column: 3;  row: 1),
    (column: 24; row: 25),
    (column: 15; row: 18),
    (column: 15; row: 20)
  );

  cityXgvar: array[0..11] of SmallInt = (
    67, 70, 68, 71, 69, 72, 73, 74, 78, 76, 75, 77
  );

  ElevXgvar: array[0..11, 0..6] of SmallInt = (
    (558, 559, 560, 561, 0, 0, 0),
    (562, 563, 564, 565, 0, 0, 0),
    (566, 567, 568, 0, 0, 0, 0),
    (569, 570, 571, 0, 0, 0, 0),
    (572, 0, 0, 0, 0, 0, 0),
    (573, 574, 575, 0, 0, 0, 0),
    (576, 577, 578, 579, 580, 581, 0),
    (582, 583, 584, 585, 586, 0, 0),
    (587, 588, 589, 590, 591, 0, 0),
    (592, 593, 0, 0, 0, 0, 0),
    (594, 595, 596, 597, 598, 0, 0),
    (599, 600, 0, 0, 0, 0, 0)
  );

  xlate_town_table: array[0..MAP_COUNT - 1] of SmallInt = (
    TOWN_VAULT_15, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_NECROPOLIS, TOWN_NECROPOLIS, TOWN_NECROPOLIS,
    TOWN_VAULT_13, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_NECROPOLIS, TOWN_JUNKTOWN, TOWN_JUNKTOWN,
    TOWN_JUNKTOWN, TOWN_BROTHERHOOD, TOWN_BROTHERHOOD,
    TOWN_BROTHERHOOD, TOWN_SHADY_SANDS, TOWN_CATHEDRAL,
    TOWN_CATHEDRAL, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_VAULT_15, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_RAIDERS, TOWN_SHADY_SANDS, TOWN_SHADY_SANDS,
    TOWN_THE_GLOW, TOWN_BONEYARD, TOWN_BONEYARD,
    TOWN_MILITARY_BASE, TOWN_MILITARY_BASE, TOWN_MILITARY_BASE,
    TOWN_CATHEDRAL, TOWN_CATHEDRAL, TOWN_VAULT_13,
    TOWN_THE_HUB, TOWN_THE_HUB, TOWN_THE_HUB,
    TOWN_THE_HUB, TOWN_THE_HUB, TOWN_THE_HUB,
    TOWN_THE_GLOW, TOWN_THE_GLOW, TOWN_BONEYARD,
    TOWN_BONEYARD, TOWN_BONEYARD, TOWN_CATHEDRAL,
    TOWN_MILITARY_BASE, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_VAULT_15, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_VAULT_15, TOWN_BROTHERHOOD, TOWN_VAULT_15,
    TOWN_VAULT_15, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_VAULT_15, TOWN_VAULT_15, TOWN_VAULT_15,
    TOWN_VAULT_13, TOWN_VAULT_13, TOWN_VAULT_13
  );

var
  { module-level (static) variables }
  bk_enable: Integer = 0;
  reselect: Integer = 0;
  tbutntgl: Byte = 0;

  RandEnctNames: array[0..3, 0..2] of PAnsiChar;
  spcl_map_name: array[0..5] of PAnsiChar;
  CityMusic: array[0..MAP_COUNT - 1] of PAnsiChar;

  TownHotSpots: array[0..14, 0..6] of TTownHotSpotEntry;

  TMSelBttns: array[0..7] of Integer;
  brnpos: array[0..6] of TBrnPosEntry;
  wrldmap_mesg_file: TMessageList;
  hvrtxtbuf: array[0..4095] of Byte;
  tcode_xref: array[0..7] of Integer;
  wmapidsav: array[0..WORLDMAP_FRM_COUNT - 1] of Pointer; { PCacheEntry }
  hvrbtn: array[0..7] of PByte;
  TownBttns: array[0..TOWN_COUNT - 1] of Integer;
  tmapbmp: array[0..TOWNMAP_FRM_COUNT - 1] of PByte;
  mesg: TMessageListItem;
  sea_mask: PByte;
  world_buf: PByte;
  line1bit_buf: PByte;
  encounter_specials: Integer;
  line_error: Integer;
  wmapbmp: array[0..WORLDMAP_FRM_COUNT - 1] of PByte;
  time_adder: Integer;
  tmap_pic: PByte;
  onbtn: PByte;
  bx_enable: Integer;
  first_visit_flag: Integer;
  deltaLineY: Integer;
  deltaLineX: Integer;
  line_index: Integer;
  WrldToggle: Integer;
  btnmsk: PByte;
  y_line_inc: Integer;
  x_line_inc: Integer;
  offbtn: PByte;
  tmapidsav: array[0..TOWNMAP_FRM_COUNT - 1] of Pointer; { PCacheEntry }
  wmap_day: LongWord;
  target_xpos: Integer;
  target_ypos: Integer;
  wmap_mile: LongWord;
  old_world_xpos: Integer;
  old_world_ypos: Integer;
  dropbtn: Integer;
  world_xpos: Integer;
  world_ypos: Integer;
  TwnSelKnwFlag: array[0..14, 0..6] of Byte;
  WorldGrid: array[0..30, 0..28] of Byte;
  wwin_flag: Byte;

{ Helper: access game_global_vars as array }
function ggv(idx: Integer): Integer; inline;
begin
  Result := PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^;
end;

procedure ggv_set(idx, val: Integer); inline;
begin
  PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^ := val;
end;

procedure ggv_inc(idx, val: Integer); inline;
begin
  PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^ :=
    PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^ + val;
end;

procedure ggv_or(idx, val: Integer); inline;
begin
  PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^ :=
    PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^ or val;
end;

{ Helper for filling TTownHotSpotEntry }
procedure InitHotSpot(var e: TTownHotSpotEntry; ax, ay, aidx: SmallInt; const aname: AnsiString);
begin
  e.x := ax;
  e.y := ay;
  e.map_idx := aidx;
  FillChar(e.name, SizeOf(e.name), 0);
  if Length(aname) > 0 then
    Move(aname[1], e.name[0], Length(aname));
end;

{ ================================================================ }
{ init_world_map                                                    }
{ ================================================================ }
function init_world_map: Integer;
var
  column, row: Integer;
begin
  for row := 0 to 28 do
    for column := 0 to 27 do
      WorldGrid[row][column] := 0;

  FillChar(TwnSelKnwFlag, SizeOf(TwnSelKnwFlag), 0);

  encounter_specials := 0;
  first_visit_flag := 0;
  world_xpos := 50 * city_location[TOWN_VAULT_13].column + 50 div 2;
  world_ypos := 50 * city_location[TOWN_VAULT_13].row + 50 div 2;
  our_town := 0;
  our_section := 1;
  first_visit_flag := first_visit_flag or 1;
  TwnSelKnwFlag[TOWN_VAULT_13][0] := 1;
  wwin_flag := 0;

  Result := 0;
end;

{ ================================================================ }
{ save_world_map                                                    }
{ ================================================================ }
function save_world_map(stream: PDB_FILE): Integer;
begin
  if db_fwrite(@WorldGrid[0][0], SizeOf(WorldGrid), 1, stream) <> 1 then Exit(-1);
  if db_fwrite(@TwnSelKnwFlag[0][0], SizeOf(TwnSelKnwFlag), 1, stream) <> 1 then Exit(-1);
  if db_fwriteInt32(stream, first_visit_flag) = -1 then Exit(-1);
  if db_fwriteInt32(stream, encounter_specials) = -1 then Exit(-1);
  if db_fwriteInt32(stream, our_town) = -1 then Exit(-1);
  if db_fwriteInt32(stream, our_section) = -1 then Exit(-1);
  if db_fwriteInt32(stream, world_xpos) = -1 then Exit(-1);
  if db_fwriteInt32(stream, world_ypos) = -1 then Exit(-1);
  Result := 0;
end;

{ ================================================================ }
{ load_world_map                                                    }
{ ================================================================ }
function load_world_map(stream: PDB_FILE): Integer;
begin
  if db_fread(@WorldGrid[0][0], SizeOf(WorldGrid), 1, stream) <> 1 then Exit(-1);
  if db_fread(@TwnSelKnwFlag[0][0], SizeOf(TwnSelKnwFlag), 1, stream) <> 1 then Exit(-1);
  if db_freadInt32(stream, @first_visit_flag) = -1 then Exit(-1);
  if db_freadInt32(stream, @encounter_specials) = -1 then Exit(-1);
  if db_freadInt32(stream, @our_town) = -1 then Exit(-1);
  if db_freadInt32(stream, @our_section) = -1 then Exit(-1);
  if db_freadInt32(stream, @world_xpos) = -1 then Exit(-1);
  if db_freadInt32(stream, @world_ypos) = -1 then Exit(-1);
  Result := 0;
end;

{ ================================================================ }
{ world_map                                                         }
{ ================================================================ }
function world_map(ctx: TWorldMapContext): Integer;
var
  title, text_: PAnsiChar;
  body: array[0..0] of PAnsiChar;
  index, rc: Integer;
  viewport_x, viewport_y: Integer;
  time_: LongWord;
  input: Integer;
  abs_mouse_x, abs_mouse_y: Integer;
  mouse_x, mouse_y: Integer;
  mouse_dx, mouse_dy: Integer;
  hover, should_redraw, done: Integer;
  is_entering_townmap, autofollow: Integer;
  is_entering_city, is_entering_random_encounter: Integer;
  is_entering_random_terrain: Integer;
  terrain, map_index: Integer;
  scroll_dx, scroll_dy: Integer;
  scroll_invalid, scroll_invalid_x, scroll_invalid_y: Integer;
  candidate_viewport_x, candidate_viewport_y: Integer;
  is_moving: Integer;
  temp_x, temp_y, temp_town: Integer;
  entering_city: Integer;
  is_moving_to_town: Integer;
  move_counter: Integer;
  next_event_time, new_game_time: LongWord;
  random_enc_chance: Integer;
  travel_line_cycle: Integer;
  iso_was_disabled: Integer;
  v109, v142: Integer;
  special_enc_chance, special_enc_num: Integer;
  location_name_width, location_name_x, location_name_y: Integer;
  hover_text_x, hover_text_width: Integer;
  wheel_x, wheel_y: Integer;
  goto_out: Boolean;
begin
  title := '';
  text_ := getmsg(@map_msg_file, @mesg, 1000);
  body[0] := text_;

  if map_save_in_game(True) = -1 then
  begin
    debug_printf(#10'WORLD MAP: ** Error saving map! **'#10);
    gmouse_disable(0);
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    gsound_play_sfx_file('iisxxxx1');
    dialog_out(title, @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
    gmouse_enable();
    game_user_wants_to_quit := 2;
    Exit(-1);
  end;

  iso_was_disabled := 0;
  soundUpdate();

  is_moving := 0;
  reselect := 0;
  dropbtn := 1;
  wmap_mile := 0;
  CalcTimeAdder();
  art_flush();

  should_redraw := 1;
  done := 0;
  autofollow := 1;
  is_entering_townmap := 0;
  is_entering_city := 0;
  is_entering_random_encounter := 0;
  is_entering_random_terrain := 0;
  entering_city := 0;
  special_enc_num := 0;
  is_moving_to_town := 0;
  move_counter := 0;
  travel_line_cycle := 0;

  if game_user_wants_to_quit <> 0 then
    ctx.state := 1;

  case ctx.state of
    -1: Exit(-1);
    0, 3:
      reselect := 0;
    1:
      begin
        intface_update_hit_points(False);
        Exit(0);
      end;
    2:
      begin
        if InCity(world_xpos, world_ypos) = ctx.town then
        begin
          our_town := ctx.town;
          our_section := ctx.section;
          reselect := 0;
          for index := 0 to TOWN_COUNT - 1 do
            win_disable_button(TownBttns[index]);
          win_disable_button(WrldToggle);
          rc := LoadTownMap(TownHotSpots[ctx.town][ctx.section].name, TownHotSpots[ctx.town][ctx.section].map_idx);
          if rc = -1 then Exit(-1);
          intface_update_hit_points(False);
          Exit(0);
        end;

        reselect := 1;
        TargetTown(ctx.town);
        entering_city := ctx.town;
        is_moving_to_town := 1;
        is_moving := 1;
        our_section := ctx.section;
      end;
  end;

  while True do
  begin
    goto_out := False;

    if InitWorldMapData() = -1 then Exit(-1);

    viewport_x := world_xpos - 247;
    viewport_y := world_ypos - 242;
    if viewport_x < 0 then viewport_x := 0
    else if viewport_x > VIEWPORT_MAX_X then viewport_x := VIEWPORT_MAX_X;
    if viewport_y < 0 then viewport_y := 0
    else if viewport_y > VIEWPORT_MAX_Y then viewport_y := VIEWPORT_MAX_Y;

    buf_to_buf(wmapbmp[WORLDMAP_FRM_WORLDMAP] + WM_WORLDMAP_WIDTH * viewport_y + viewport_x,
      450, 442, WM_WORLDMAP_WIDTH, world_buf + WM_WINDOW_WIDTH * 21 + 22, WM_WINDOW_WIDTH);
    UpdVisualArea();
    block_map(viewport_x, viewport_y, world_buf);
    trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX], WM_WINDOW_WIDTH, WM_WINDOW_HEIGHT,
      WM_WINDOW_WIDTH, world_buf, WM_WINDOW_WIDTH);
    DrawTownLabels(wmapbmp[WORLDMAP_FRM_LABELS], world_buf);

    temp_x := world_xpos - viewport_x + 10;
    temp_y := world_ypos - viewport_y + 15;
    if (temp_x > -3) and (temp_x < 484) and (temp_y > 8) and (temp_y < 463) then
    begin
      if temp_x > 460 then
        trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_NORMAL], 485 - temp_x, HOTSPOT_HEIGHT,
          HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH)
      else
        trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_NORMAL], HOTSPOT_WIDTH, HOTSPOT_HEIGHT,
          HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
    end;

    DrawMapTime(0);
    win_draw(world_win);
    renderPresent();

    if iso_was_disabled = 0 then
    begin
      intface_hide();
      win_fill(display_win, 0, 0, win_width(display_win), win_height(display_win), colorTable[0]);
      win_draw(display_win);
      bk_enable := Ord(map_disable_bk_processes());
      cycle_disable();
      iso_was_disabled := 1;
    end;

    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    gsound_background_play_level_music('03WRLDMP', 12);

    hover := 0;

    while done = 0 do
    begin
      sharedFpsLimiter.Mark;

      if (is_entering_random_encounter <> 0) or (is_entering_city <> 0) or (is_entering_random_terrain <> 0) then
        Break;

      time_ := get_time();
      input := get_input();
      mouseGetPositionInWindow(world_win, @mouse_x, @mouse_y);

      mouse_dx := Abs(mouse_x - (world_xpos - viewport_x + 22));
      mouse_dy := Abs(mouse_y - (world_ypos - viewport_y + 20));

      if mouse_dx < mouse_dy then
        mouse_dx := mouse_dx div 2
      else
        mouse_dy := mouse_dy div 2;

      if mouse_dx + mouse_dy > 10 then
      begin
        if hover <> 0 then should_redraw := 1;
        hover := 0;
      end
      else
      begin
        if hover = 0 then
        begin
          should_redraw := 1;
          hover := 1;
        end;
      end;

      if (input >= 500) and (input < 512) then
      begin
        if (first_visit_flag and (1 shl (input - 500))) <> 0 then
        begin
          if (is_moving_to_town = 0) or (is_moving = 0) or (InCity(target_xpos, target_ypos) <> input - 500) then
          begin
            target_xpos := 50 * city_location[input - 500].column + 50 div 2;
            target_ypos := 50 * city_location[input - 500].row + 50 div 2;
            temp_town := InCity(target_xpos, target_ypos);
            if (temp_town <> InCity(world_xpos, world_ypos)) or (temp_town = -1) then
            begin
              if is_moving <> 0 then autofollow := 0 else autofollow := 1;
              TargetTown(temp_town);
              is_moving := 1;
              is_moving_to_town := 1;
            end
            else
            begin
              entering_city := temp_town;
              is_entering_city := 1;
              should_redraw := 0;
              is_moving := 0;
            end;
          end;
        end;
      end
      else if input = 512 then
      begin
        should_redraw := 0;
        reselect := 0;
        done := 1;
        is_entering_townmap := 1;
      end
      else if (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
      begin
        if (mouse_x > 22) and (mouse_x < 472) and (mouse_y > 21) and (mouse_y < 463) then
        begin
          if (dropbtn <> 0) and (hover <> 0) then
          begin
            is_entering_city := 0;
            gsound_play_sfx_file('ib2p1xx1');
            reselect := 0;
            is_entering_random_encounter := 0;
            is_entering_random_terrain := 1;
            temp_town := InCity(world_xpos, world_ypos);
            if temp_town <> -1 then
            begin
              entering_city := temp_town;
              is_entering_city := 1;
              is_entering_random_terrain := 0;
            end;
            Break;
          end
          else
          begin
            if is_moving <> 0 then autofollow := 0 else autofollow := 1;
            gsound_play_sfx_file('ib1p1xx1');
            target_xpos := viewport_x + mouse_x - 22;
            target_ypos := viewport_y + mouse_y - 21;
            is_moving := 1;
            world_move_init();
            dropbtn := 0;
            if InCity(target_xpos, target_ypos) <> -1 then
              is_moving_to_town := 1
            else
              is_moving_to_town := 0;
          end;
        end;
      end
      else
      begin
        case input of
          KEY_UPPERCASE_A, KEY_LOWERCASE_A:
            if autofollow <> 0 then autofollow := 0 else autofollow := 1;
          KEY_CTRL_P, KEY_ALT_P, KEY_UPPERCASE_P, KEY_LOWERCASE_P:
            PauseWindow(True);
          KEY_F12:
            dump_screen();
          KEY_CTRL_Q, KEY_CTRL_X, KEY_F10:
            game_quit_with_confirm();
          KEY_EQUAL, KEY_PLUS:
            IncGamma();
          KEY_MINUS, KEY_UNDERSCORE:
            DecGamma();
        end;
      end;

      if game_user_wants_to_quit <> 0 then
      begin
        should_redraw := 0;
        is_entering_city := 0;
        is_entering_townmap := 0;
        is_entering_random_encounter := 0;
        is_entering_random_terrain := 0;
        done := 1;
      end;

      if (input = KEY_HOME) or (input = KEY_UPPERCASE_C) or (input = KEY_LOWERCASE_C) or (autofollow <> 0) then
      begin
        viewport_x := world_xpos - 247;
        viewport_y := world_ypos - 242;
        if viewport_x < 0 then viewport_x := 0
        else if viewport_x > VIEWPORT_MAX_X then viewport_x := VIEWPORT_MAX_X;
        if viewport_y < 0 then viewport_y := 0
        else if viewport_y > VIEWPORT_MAX_Y then viewport_y := VIEWPORT_MAX_Y;
        should_redraw := 1;
      end;

      mouse_get_position(@abs_mouse_x, @abs_mouse_y);

      scroll_dx := 0;
      scroll_dy := 0;
      if abs_mouse_x = 0 then begin scroll_dx := -1; autofollow := 0; end
      else if abs_mouse_x = screenGetWidth() - 1 then begin scroll_dx := 1; autofollow := 0; end;
      if abs_mouse_y = 0 then begin scroll_dy := -1; autofollow := 0; end
      else if abs_mouse_y = screenGetHeight() - 1 then begin scroll_dy := 1; autofollow := 0; end;

      scroll_invalid := 0;
      scroll_invalid_x := 0;
      scroll_invalid_y := 0;

      candidate_viewport_x := viewport_x + 16 * scroll_dx;
      if (candidate_viewport_x < 0) or (candidate_viewport_x > VIEWPORT_MAX_X) then
        scroll_invalid_x := 1;

      candidate_viewport_y := viewport_y + 16 * scroll_dy;
      if (candidate_viewport_y < 0) or (candidate_viewport_y > VIEWPORT_MAX_Y) then
        scroll_invalid_y := 1;

      if mouse_table1[scroll_dy + 1][scroll_dx + 1][0] = scroll_invalid_x then
        Inc(scroll_invalid);
      if mouse_table1[scroll_dy + 1][scroll_dx + 1][1] = scroll_invalid_y then
        Inc(scroll_invalid);

      if scroll_invalid = 2 then
        gmouse_set_cursor(mouse_table3[scroll_dy + 1][scroll_dx + 1][0])
      else
        gmouse_set_cursor(mouse_table2[scroll_dy + 1][scroll_dx + 1][0]);

      case input of
        KEY_ARROW_LEFT:
          if viewport_x <> 0 then begin scroll_dx := -1; autofollow := 0; end;
        KEY_ARROW_RIGHT:
          if viewport_x < VIEWPORT_MAX_X then begin scroll_dx := 1; autofollow := 0; end;
        KEY_ARROW_UP:
          if viewport_y <> 0 then begin scroll_dy := -1; autofollow := 0; end;
        KEY_ARROW_DOWN:
          if viewport_y < VIEWPORT_MAX_Y then begin scroll_dy := 1; autofollow := 0; end;
        KEY_HOME:
          begin scroll_dy := 1; viewport_y := 0; autofollow := 0; end;
        KEY_END:
          begin scroll_dy := 1; viewport_y := VIEWPORT_MAX_Y; autofollow := 0; end;
        -1:
          begin
            if (mouse_get_buttons() and MOUSE_EVENT_WHEEL) <> 0 then
            begin
              mouseGetWheel(@wheel_x, @wheel_y);
              if mouseHitTestInWindow(world_win, 22, 21, 450 + 22, 442 + 21) then
              begin
                if wheel_x > 0 then begin scroll_dx := 1; autofollow := 0; end
                else if wheel_x < 0 then begin scroll_dx := -1; autofollow := 0; end;
                if wheel_y > 0 then begin scroll_dy := -1; autofollow := 0; end
                else if wheel_y < 0 then begin scroll_dy := 1; autofollow := 0; end;
              end;
            end;
          end;
      end;

      if (scroll_dx <> 0) or (scroll_dy <> 0) then
      begin
        viewport_x := viewport_x + 16 * scroll_dx;
        viewport_y := viewport_y + 16 * scroll_dy;
        if viewport_x < 0 then viewport_x := 0
        else if viewport_x > VIEWPORT_MAX_X then viewport_x := VIEWPORT_MAX_X;
        if viewport_y < 0 then viewport_y := 0
        else if viewport_y > VIEWPORT_MAX_Y then viewport_y := VIEWPORT_MAX_Y;
        should_redraw := 1;
      end;

      if is_moving <> 0 then
      begin
        v109 := 0;
        dropbtn := 0;
        while v109 < 2 do
        begin
          if (is_moving = 0) or (is_entering_random_encounter <> 0) or (is_entering_city <> 0) or (done <> 0) then
            Break;

          case WorldTerraTable[world_ypos div 50][world_xpos div 50] of
            TERRAIN_TYPE_MOUNTAIN:
              begin
                Dec(move_counter);
                if move_counter <= 0 then
                begin
                  if world_move_step() = 0 then is_moving := 1 else is_moving := 0;
                  if (world_xpos < 1064) and (world_ypos > 0) then
                    if ((128 shr (world_xpos mod 8)) and WALKMASK_MASK_DATA[world_ypos][world_xpos div 8]) <> 0 then
                    begin
                      world_xpos := old_world_xpos;
                      world_ypos := old_world_ypos;
                      is_moving := 0;
                    end;
                  move_counter := 2;
                end;

                next_event_time := queue_next_time();
                new_game_time := game_time() + LongWord(time_adder);
                if new_game_time >= next_event_time then
                begin
                  set_game_time(next_event_time + 1);
                  if queue_process() <> 0 then
                  begin
                    debug_printf(#10'WORLDMAP: Exiting from Queue trigger...'#10);
                    is_entering_city := 0;
                    is_entering_townmap := 0;
                    is_entering_random_encounter := 0;
                    is_entering_random_terrain := 0;
                    temp_town := InCity(world_xpos, world_ypos);
                    if temp_town <> -1 then
                    begin entering_city := temp_town; is_entering_city := 1; end
                    else
                      is_entering_random_terrain := 1;
                    goto_out := True;
                    Break;
                  end;
                end;
                set_game_time(new_game_time);
              end;
            TERRAIN_TYPE_CITY:
              begin
                if world_move_step() = 0 then is_moving := 1 else is_moving := 0;
                if (world_xpos < 1064) and (world_ypos > 0) then
                  if ((128 shr (world_xpos mod 8)) and WALKMASK_MASK_DATA[world_ypos][world_xpos div 8]) <> 0 then
                  begin
                    world_xpos := old_world_xpos;
                    world_ypos := old_world_ypos;
                    is_moving := 0;
                  end;

                Dec(move_counter);
                if (move_counter <= 0) and (is_moving <> 0) then
                begin
                  if world_move_step() = 0 then is_moving := 1 else is_moving := 0;
                  if (world_xpos < 1064) and (world_ypos > 0) then
                    if ((128 shr (world_xpos mod 8)) and WALKMASK_MASK_DATA[world_ypos][world_xpos div 8]) <> 0 then
                    begin
                      world_xpos := old_world_xpos;
                      world_ypos := old_world_ypos;
                      is_moving := 0;
                    end;
                  move_counter := 4;
                end
                else
                begin
                  next_event_time := queue_next_time();
                  new_game_time := game_time() + LongWord(time_adder);
                  if new_game_time >= next_event_time then
                  begin
                    set_game_time(next_event_time + 1);
                    if queue_process() <> 0 then
                    begin
                      debug_printf(#10'WORLDMAP: Exiting from Queue trigger...'#10);
                      is_entering_city := 0;
                      is_entering_townmap := 0;
                      is_entering_random_encounter := 0;
                      is_entering_random_terrain := 0;
                      temp_town := InCity(world_xpos, world_ypos);
                      if temp_town <> -1 then
                      begin entering_city := temp_town; is_entering_city := 1; end
                      else
                        is_entering_random_terrain := 1;
                      goto_out := True;
                      Break;
                    end;
                  end;
                  set_game_time(new_game_time);
                end;
              end;
          else { default terrain }
            begin
              if world_move_step() = 0 then is_moving := 1 else is_moving := 0;
              if (world_xpos < 1064) and (world_ypos > 0) then
                if ((128 shr (world_xpos mod 8)) and WALKMASK_MASK_DATA[world_ypos][world_xpos div 8]) <> 0 then
                begin
                  world_xpos := old_world_xpos;
                  world_ypos := old_world_ypos;
                  is_moving := 0;
                end;
              move_counter := 0;

              next_event_time := queue_next_time();
              new_game_time := game_time() + LongWord(time_adder);
              if new_game_time >= next_event_time then
              begin
                set_game_time(next_event_time + 1);
                if queue_process() <> 0 then
                begin
                  debug_printf(#10'WORLDMAP: Exiting from Queue trigger...'#10);
                  is_entering_city := 0;
                  is_entering_townmap := 0;
                  is_entering_random_encounter := 0;
                  is_entering_random_terrain := 0;
                  temp_town := InCity(world_xpos, world_ypos);
                  if temp_town <> -1 then
                  begin entering_city := temp_town; is_entering_city := 1; end
                  else
                    is_entering_random_terrain := 1;
                  goto_out := True;
                  Break;
                end;
              end;
              set_game_time(new_game_time);
            end;
          end; { case }

          if goto_out then Break;

          Dec(travel_line_cycle);
          if travel_line_cycle <= 0 then
          begin
            travel_line_cycle := 2;
            index := (WM_WORLDMAP_WIDTH * world_ypos + world_xpos) div 8;
            line1bit_buf[index] := line1bit_buf[index] or (128 shr (world_xpos mod 8));
            UpdVisualArea();
          end;

          Inc(wmap_mile);
          if wmap_mile >= wmap_day then
          begin
            wmap_mile := 0;
            partyMemberRestingHeal(24);

            random_enc_chance := roll_random(1, 6) + roll_random(1, 6) + roll_random(1, 6);
            if InCity(world_xpos, world_ypos) = -1 then
            begin
              case WorldEcountChanceTable[world_ypos div 50][world_xpos div 50] of
                0: if random_enc_chance < 6 then is_entering_random_encounter := 1;
                1: if random_enc_chance < 7 then is_entering_random_encounter := 1;
                2: if random_enc_chance < 9 then is_entering_random_encounter := 1;
                3: if random_enc_chance < 10 then is_entering_random_encounter := 1;
              end;
            end;

            if is_entering_random_encounter <> 0 then
            begin
              v142 := 0;
              while v142 = 0 do
              begin
                special_enc_chance := roll_random(1, 6) + roll_random(1, 6) + roll_random(1, 6) - 5;
                special_enc_chance := special_enc_chance + stat_level(obj_dude, Ord(STAT_LUCK));
                special_enc_chance := special_enc_chance + 2 * perk_level(Ord(PERK_EXPLORER));
                if (special_enc_chance < 18) or (encounter_specials = 63) then
                begin
                  v142 := 1;
                  Break;
                end;

                special_enc_chance := roll_random(1, 100);
                v109 := 0;
                while (v109 < 6) and (v142 = 0) do
                begin
                  if (special_enc_chance >= SpclEncRange[v109].start_) and (special_enc_chance <= SpclEncRange[v109].end_) then
                  begin
                    if (encounter_specials and (1 shl v109)) <> 0 then
                      Break;
                    debug_printf(#10'WORLD MAP: specail index #%d'#10, [v109]);
                    encounter_specials := encounter_specials or (1 shl v109);
                    Inc(v142);
                    special_enc_num := v109 + 1;
                  end;
                  Inc(v109);
                end;
              end;
            end;
          end;

          if is_moving_to_town <> 0 then
          begin
            if (is_moving = 0) and (is_entering_random_encounter = 0) then
            begin
              temp_town := InCity(world_xpos, world_ypos);
              if temp_town <> -1 then
              begin
                dropbtn := 1;
                is_entering_city := 0;
                entering_city := temp_town;
                reselect := 0;
                is_moving_to_town := 0;
                is_entering_random_encounter := 0;
              end;
            end;
          end;

          Inc(v109);
          should_redraw := 1;
        end; { while v109 < 2 }

        if (not goto_out) and (is_moving = 0) then
        begin
          FillChar(line1bit_buf^, 262500, 0);
          if (is_entering_city = 0) and (is_entering_random_encounter = 0) then
          begin
            should_redraw := 1;
            dropbtn := 1;
            reselect := 0;
            is_moving_to_town := 0;
            done := 0;
            is_entering_city := 0;
            is_entering_random_encounter := 0;
            is_entering_random_terrain := 0;
            is_moving := 0;
          end;
        end;
      end; { if is_moving }

      if not goto_out then
      begin
        case CheckEvents() of
          -1: debug_printf(#10'** WORLD MAP: Error running specail event! **'#10);
          1:
            begin
              should_redraw := 0;
              reselect := 0;
              is_entering_townmap := 0;
              is_entering_city := 0;
              is_entering_random_terrain := 0;
              is_entering_random_encounter := 0;
              done := 1;
            end;
        end;
      end;

      if should_redraw <> 0 then
      begin
        buf_to_buf(wmapbmp[WORLDMAP_FRM_WORLDMAP] + WM_WORLDMAP_WIDTH * viewport_y + viewport_x,
          450, 442, WM_WORLDMAP_WIDTH, world_buf + 640 * 21 + 22, 640);
        block_map(viewport_x, viewport_y, world_buf);

        if dropbtn <> 0 then
        begin
          temp_x := world_xpos - viewport_x + 10;
          temp_y := world_ypos - viewport_y + 15;
          if (temp_x > -3) and (temp_x < 484) and (temp_y > 8) and (temp_y < 463) then
          begin
            if temp_x > 460 then
              trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_NORMAL], 485 - temp_x, HOTSPOT_HEIGHT,
                HOTSPOT_WIDTH, world_buf + 640 * temp_y + temp_x, 640)
            else
              trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_NORMAL], HOTSPOT_WIDTH, HOTSPOT_HEIGHT,
                HOTSPOT_WIDTH, world_buf + 640 * temp_y + temp_x, 640);
          end;

          if hover <> 0 then
          begin
            temp_town := InCity(world_xpos, world_ypos);
            if temp_town <> -1 then
            begin
              if (ggv(cityXgvar[temp_town]) = 1) or ((first_visit_flag and (1 shl temp_town)) <> 0) then
                text_ := getmsg(@map_msg_file, @mesg, temp_town + 500)
              else
                text_ := getmsg(@wrldmap_mesg_file, @mesg, 1004);
            end
            else
              text_ := getmsg(@wrldmap_mesg_file, @mesg, WorldTerraTable[world_ypos div 50][world_xpos div 50] + 1000);

            location_name_width := text_width(text_);
            location_name_x := temp_x + (25 - location_name_width) div 2;
            location_name_y := temp_y - 11;
            if (location_name_x > 22 - location_name_width) and (location_name_x < 472) and (location_name_y > 11) and (location_name_y < 463) then
            begin
              if location_name_x < 22 then
              begin
                hover_text_x := 22 - location_name_x;
                if hover_text_x < 0 then hover_text_x := location_name_x - 22;
                location_name_x := 22;
              end
              else
                hover_text_x := 0;
              hover_text_width := location_name_width - hover_text_x;
              if location_name_x + location_name_width > 472 then
                hover_text_width := 472 - hover_text_x - location_name_x;
              if hover_text_width <> 0 then
              begin
                buf_to_buf(world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x,
                  hover_text_width, text_height(), WM_WINDOW_WIDTH, @hvrtxtbuf[0] + hover_text_x, 256);
                text_to_buf(@hvrtxtbuf[0], text_, 256, 256, colorTable[992] or $10000);
                buf_to_buf(@hvrtxtbuf[0] + hover_text_x, hover_text_width, text_height(), 256,
                  world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x, WM_WINDOW_WIDTH);
              end;
            end;
          end;
        end
        else
        begin
          temp_x := world_xpos - viewport_x + 20;
          temp_y := world_ypos - viewport_y + 19;
          if (temp_x > 17) and (temp_x < 474) and (temp_y > 16) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_LOCATION_MARKER], LOCATION_MARKER_WIDTH, LOCATION_MARKER_HEIGHT,
              LOCATION_MARKER_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
        end;

        if is_moving <> 0 then
        begin
          temp_x := target_xpos - viewport_x + 17;
          temp_y := target_ypos - viewport_y + 16;
          if (temp_x > 11) and (temp_x < 474) and (temp_y > 10) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_DESTINATION_MARKER_BRIGHT], DESTINATION_MARKER_WIDTH, DESTINATION_MARKER_HEIGHT,
              DESTINATION_MARKER_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
          bit1exbit8(viewport_x, viewport_y, viewport_x + 449, viewport_y + 441,
            22, 21, line1bit_buf, world_buf, WM_WORLDMAP_WIDTH, WM_WINDOW_WIDTH, colorTable[27648]);
        end;

        trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX], 35, WM_WINDOW_HEIGHT, WM_WINDOW_WIDTH, world_buf, WM_WINDOW_WIDTH);
        trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + 455, 32, WM_WINDOW_HEIGHT, WM_WINDOW_WIDTH, world_buf + 455, WM_WINDOW_WIDTH);
        buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + 35, 422, 21, WM_WINDOW_WIDTH, world_buf + 35, WM_WINDOW_WIDTH);
        buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + WM_WINDOW_WIDTH * 463 + 35, 422, 17, WM_WINDOW_WIDTH, world_buf + WM_WINDOW_WIDTH * 463 + 35, WM_WINDOW_WIDTH);

        DrawMapTime(0);
        win_draw(world_win);
        should_redraw := 0;
        while elapsed_time(time_) < (1000 div 24) do begin end;
      end
      else
      begin
        if done = 0 then DrawMapTime(0);
        win_draw(world_win);
      end;

      renderPresent();
      sharedFpsLimiter.Throttle;
    end; { while not done - inner loop }

    if (not goto_out) and (done = 0) then
    begin
      if (special_enc_num <> 0) or (is_entering_random_encounter <> 0) then
      begin
        viewport_x := world_xpos - 247;
        viewport_y := world_ypos - 242;
        if viewport_x < 0 then viewport_x := 0
        else if viewport_x > VIEWPORT_MAX_X then viewport_x := VIEWPORT_MAX_X;
        if viewport_y < 0 then viewport_y := 0
        else if viewport_y > VIEWPORT_MAX_Y then viewport_y := VIEWPORT_MAX_Y;
      end;

      buf_to_buf(wmapbmp[WORLDMAP_FRM_WORLDMAP] + WM_WORLDMAP_WIDTH * viewport_y + viewport_x,
        450, 442, WM_WORLDMAP_WIDTH, world_buf + 21 * WM_WINDOW_WIDTH + 22, WM_WINDOW_WIDTH);
      block_map(viewport_x, viewport_y, world_buf);
      trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX], 35, WM_WINDOW_HEIGHT, WM_WINDOW_WIDTH, world_buf, WM_WINDOW_WIDTH);
      trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + 455, 32, WM_WINDOW_HEIGHT, WM_WINDOW_WIDTH, world_buf + 455, WM_WINDOW_WIDTH);
      buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + 35, 422, 21, WM_WINDOW_WIDTH, world_buf + 35, WM_WINDOW_WIDTH);
      buf_to_buf(wmapbmp[WORLDMAP_FRM_BOX] + WM_WINDOW_WIDTH * 463 + 35, 422, 17, WM_WINDOW_WIDTH, world_buf + WM_WINDOW_WIDTH * 463 + 35, WM_WINDOW_WIDTH);
    end;

    if (not goto_out) and (is_entering_random_encounter <> 0) then
    begin
      if special_enc_num <> 0 then
      begin
        temp_x := world_xpos - viewport_x + 17;
        temp_y := world_ypos - viewport_y + 16;
        for index := 0 to 6 do
        begin
          if (temp_x > 11) and (temp_x < 474) and (temp_y > 10) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_DESTINATION_MARKER_DARK], DESTINATION_MARKER_WIDTH, DESTINATION_MARKER_HEIGHT,
              DESTINATION_MARKER_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
          win_draw(world_win); renderPresent(); block_for_tocks(199);
          if (temp_x > 11) and (temp_x < 474) and (temp_y > 10) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_DESTINATION_MARKER_BRIGHT], DESTINATION_MARKER_WIDTH, DESTINATION_MARKER_HEIGHT,
              DESTINATION_MARKER_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
          win_draw(world_win); renderPresent(); block_for_tocks(199);
        end;
      end
      else
      begin
        temp_x := world_xpos - viewport_x + 19;
        temp_y := world_ypos - viewport_y + 16;
        for index := 0 to 6 do
        begin
          if (temp_x > 15) and (temp_x < 472) and (temp_y > 10) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_RANDOM_ENCOUNTER_BRIGHT], RANDOM_ENCOUNTER_ICON_WIDTH, RANDOM_ENCOUNTER_ICON_HEIGHT,
              RANDOM_ENCOUNTER_ICON_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
          win_draw(world_win); renderPresent(); block_for_tocks(199);
          if (temp_x > 15) and (temp_x < 472) and (temp_y > 10) and (temp_y < 463) then
            trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_RANDOM_ENCOUNTER_DARK], RANDOM_ENCOUNTER_ICON_WIDTH, RANDOM_ENCOUNTER_ICON_HEIGHT,
              RANDOM_ENCOUNTER_ICON_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
          win_draw(world_win); renderPresent(); block_for_tocks(199);
        end;
      end;
    end
    else if (not goto_out) and (is_entering_city <> 0) then
    begin
      temp_x := world_xpos - viewport_x + 10;
      temp_y := world_ypos - viewport_y + 15;
      if (temp_x > -3) and (temp_x < 484) and (temp_y > 8) and (temp_y < 463) then
      begin
        if temp_x > 460 then
          trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_PRESSED], 485 - temp_x, HOTSPOT_HEIGHT,
            HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH)
        else
          trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_PRESSED], HOTSPOT_WIDTH, HOTSPOT_HEIGHT,
            HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
      end;

      if hover <> 0 then
      begin
        temp_town := InCity(world_xpos, world_ypos);
        if temp_town <> -1 then
        begin
          if (ggv(cityXgvar[temp_town]) = 1) or ((first_visit_flag and (1 shl temp_town)) <> 0) then
            text_ := getmsg(@map_msg_file, @mesg, temp_town + 500)
          else
            text_ := getmsg(@wrldmap_mesg_file, @mesg, 1004);
        end
        else
          text_ := getmsg(@wrldmap_mesg_file, @mesg, WorldTerraTable[world_ypos div 50][world_xpos div 50] + 1000);

        location_name_width := text_width(text_);
        location_name_x := temp_x + (25 - location_name_width) div 2;
        location_name_y := temp_y - 11;
        if (location_name_x > 22 - location_name_width) and (location_name_x < 472) and (location_name_y > 11) and (location_name_y < 463) then
        begin
          if location_name_x < 22 then
          begin
            hover_text_x := 22 - location_name_x;
            if hover_text_x < 0 then hover_text_x := location_name_x - 22;
            location_name_x := 22;
          end
          else hover_text_x := 0;
          hover_text_width := location_name_width - hover_text_x;
          if location_name_x + location_name_width > 472 then
            hover_text_width := 472 - hover_text_x - location_name_x;
          if hover_text_width <> 0 then
          begin
            buf_to_buf(world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x,
              hover_text_width, text_height(), WM_WINDOW_WIDTH, @hvrtxtbuf[0] + hover_text_x, 256);
            text_to_buf(@hvrtxtbuf[0], text_, 256, 256, colorTable[992] or $10000);
            buf_to_buf(@hvrtxtbuf[0] + hover_text_x, hover_text_width, text_height(), 256,
              world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x, WM_WINDOW_WIDTH);
          end;
        end;
      end;

      win_draw(world_win); renderPresent();
      if dropbtn = 0 then block_for_tocks(500)
      else
      begin
        while (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_REPEAT) <> 0 do begin end;
        block_for_tocks(300);
      end;
    end
    else if (not goto_out) and (is_entering_random_terrain <> 0) then
    begin
      temp_x := world_xpos - viewport_x + 10;
      temp_y := world_ypos - viewport_y + 15;
      if (temp_x > -3) and (temp_x < 484) and (temp_y > 8) and (temp_y < 463) then
      begin
        if temp_x > 460 then
          trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_PRESSED], 485 - temp_x, HOTSPOT_HEIGHT,
            HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH)
        else
          trans_buf_to_buf(wmapbmp[WORLDMAP_FRM_HOTSPOT_PRESSED], HOTSPOT_WIDTH, HOTSPOT_HEIGHT,
            HOTSPOT_WIDTH, world_buf + WM_WINDOW_WIDTH * temp_y + temp_x, WM_WINDOW_WIDTH);
      end;

      if hover <> 0 then
      begin
        temp_town := InCity(world_xpos, world_ypos);
        if temp_town <> -1 then
        begin
          if (ggv(cityXgvar[temp_town]) = 1) or ((first_visit_flag and (1 shl temp_town)) <> 0) then
            text_ := getmsg(@map_msg_file, @mesg, temp_town + 500)
          else
            text_ := getmsg(@wrldmap_mesg_file, @mesg, 1004);
        end
        else
          text_ := getmsg(@wrldmap_mesg_file, @mesg, WorldTerraTable[world_ypos div 50][world_xpos div 50] + 1000);

        location_name_width := text_width(text_);
        location_name_x := temp_x + (25 - location_name_width) div 2;
        location_name_y := temp_y - 11;
        if (location_name_x > 22 - location_name_width) and (location_name_x < 472) and (location_name_y > 11) and (location_name_y < 463) then
        begin
          if location_name_x < 22 then
          begin
            hover_text_x := 22 - location_name_x;
            if hover_text_x < 0 then hover_text_x := location_name_x - 22;
            location_name_x := 22;
          end
          else hover_text_x := 0;
          hover_text_width := location_name_width - hover_text_x;
          if location_name_x + location_name_width > 472 then
            hover_text_width := 472 - hover_text_x - location_name_x;
          if hover_text_width <> 0 then
          begin
            buf_to_buf(world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x,
              hover_text_width, text_height(), WM_WINDOW_WIDTH, @hvrtxtbuf[0] + hover_text_x, 256);
            text_to_buf(@hvrtxtbuf[0], text_, 256, 256, colorTable[992] or $10000);
            buf_to_buf(@hvrtxtbuf[0] + hover_text_x, hover_text_width, text_height(), 256,
              world_buf + WM_WINDOW_WIDTH * location_name_y + location_name_x, WM_WINDOW_WIDTH);
          end;
        end;
      end;

      win_draw(world_win); renderPresent();
      while (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_REPEAT) <> 0 do begin end;
      block_for_tocks(300);
    end;

    { out: label equivalent }
    UnInitWorldMapData();
    art_flush();

    if is_entering_random_terrain <> 0 then
    begin
      debug_printf(#10'WORLD MAP: Droping out to random terrain area map.'#10);
      ggv_set(Ord(GVAR_WORLD_TERRAIN), WorldEcounTable[world_ypos div 50][world_xpos div 50]);
      terrain := WorldTerraTable[world_ypos div 50][world_xpos div 50];
      repeat
        map_index := roll_random(0, 2);
      until RandEnctNames[terrain][map_index] <> nil;
      debug_printf(#10'WORLD MAP: Loading rand "drop down" map index #%d, name: %s'#10, [map_index, RandEnctNames[terrain][map_index]]);
      for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
      win_disable_button(WrldToggle);
      if LoadTownMap(RandEnctNames[terrain][map_index], 1) = -1 then Exit(-1);
    end
    else if is_entering_random_encounter <> 0 then
    begin
      if special_enc_num <> 0 then
      begin
        debug_printf(#10'WORLD MAP: Doing specail map index #%d...'#10, [special_enc_num - 1]);
        ggv_set(Ord(GVAR_WORLD_TERRAIN), WorldEcounTable[world_ypos div 50][world_xpos div 50]);
        for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
        win_disable_button(WrldToggle);
        if LoadTownMap(spcl_map_name[special_enc_num - 1], 0) = -1 then Exit(-1);
      end
      else
      begin
        ggv_set(Ord(GVAR_WORLD_TERRAIN), WorldEcounTable[world_ypos div 50][world_xpos div 50]);
        terrain := WorldTerraTable[world_ypos div 50][world_xpos div 50];
        repeat
          map_index := roll_random(0, 2);
        until RandEnctNames[terrain][map_index] <> nil;
        debug_printf(#10'WORLD MAP: Loading rand encounter map index #%d, name: %s'#10, [map_index, RandEnctNames[terrain][map_index]]);
        for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
        win_disable_button(WrldToggle);
        if LoadTownMap(RandEnctNames[terrain][map_index], 2) = -1 then Exit(-1);
      end;
    end
    else if is_entering_city <> 0 then
    begin
      debug_printf(#10'WORLD MAP: Entering into city index #%d.'#10, [entering_city]);
      our_town := entering_city;
      if (first_visit_flag and (1 shl entering_city)) = 0 then
      begin
        for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
        win_disable_button(WrldToggle);
        if LoadTownMap(TownHotSpots[entering_city][0].name, TownHotSpots[entering_city][0].map_idx) = -1 then Exit(-1);
        reselect := 0;
        first_visit_flag := first_visit_flag or (1 shl entering_city);
      end
      else
      begin
        ctx.town := entering_city;
        ctx := town_map(ctx);
        case ctx.state of
          -1:
            begin
              if bx_enable <> 0 then enable_box_bar_win();
              Exit(-1);
            end;
          3:
            begin
              is_moving := 0;
              is_entering_city := 0;
              reselect := 0;
              dropbtn := 1;
              is_moving_to_town := 0;
              is_entering_random_encounter := 0;
              is_entering_townmap := 0;
              autofollow := 1;
              move_counter := 0;
              should_redraw := 1;
              travel_line_cycle := 0;
              Continue; { outer while }
            end;
        else
          begin
            if ctx.town <> entering_city then
            begin
              TargetTown(ctx.town);
              is_entering_city := 0;
              autofollow := 1;
              is_entering_townmap := 0;
              should_redraw := 1;
              our_section := ctx.section;
              reselect := 1;
              is_entering_random_encounter := 0;
              move_counter := 0;
              is_moving := 1;
              travel_line_cycle := 0;
              is_moving_to_town := 1;
              Continue;
            end;
            for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
            win_disable_button(WrldToggle);
            if LoadTownMap(TownHotSpots[ctx.town][ctx.section].name, TownHotSpots[ctx.town][ctx.section].map_idx) = -1 then Exit(-1);
            reselect := 0;
          end;
        end;
      end;
    end
    else if is_entering_townmap <> 0 then
    begin
      if reselect <> 0 then ctx.town := entering_city
      else ctx.town := our_town;

      ctx := town_map(ctx);
      case ctx.state of
        -1: Exit(-1);
        3:
          begin
            is_moving := 0;
            is_entering_random_terrain := 0;
            is_entering_city := 0;
            is_entering_random_encounter := 0;
            entering_city := 0;
            done := 0;
            move_counter := 0;
            travel_line_cycle := 0;
            dropbtn := 1;
            reselect := 0;
            is_entering_townmap := 0;
            should_redraw := 1;
            autofollow := 0;
            Continue;
          end;
        2:
          begin
            temp_town := InCity(world_xpos, world_ypos);
            if temp_town <> ctx.town then
            begin
              entering_city := ctx.town;
              done := 0;
              is_entering_townmap := 0;
              is_entering_random_terrain := 0;
              is_entering_city := 0;
              is_entering_random_encounter := 0;
              autofollow := 1;
              reselect := 1;
              should_redraw := 1;
              TargetTown(ctx.town);
              is_moving := 1;
              is_moving_to_town := 1;
              our_section := ctx.section;
              Continue;
            end;
            our_town := temp_town;
            entering_city := temp_town;
            for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
            win_disable_button(WrldToggle);
            if LoadTownMap(TownHotSpots[entering_city][ctx.section].name, TownHotSpots[entering_city][ctx.section].map_idx) = -1 then Exit(-1);
            reselect := 0;
          end;
      end;
    end;

    if iso_was_disabled <> 0 then
    begin
      if bk_enable <> 0 then map_enable_bk_processes();
      cycle_enable();
    end;

    Exit(0);
  end; { outer while True }
end;

{ ================================================================ }
{ UpdVisualArea                                                     }
{ ================================================================ }

type
  TOffset2 = record
    column_offset: Integer;
    row_offset: Integer;
  end;

const
  uva_offsets: array[0..2, 0..2] of TOffset2 = (
    ((column_offset: -1; row_offset: -1), (column_offset: 0; row_offset: -1), (column_offset: 1; row_offset: -1)),
    ((column_offset: -1; row_offset: 0),  (column_offset: 0; row_offset: 0),  (column_offset: 1; row_offset: 0)),
    ((column_offset: -1; row_offset: 1),  (column_offset: 0; row_offset: 1),  (column_offset: 1; row_offset: 1))
  );

  uva_scout_offsets: array[0..4, 0..4] of TOffset2 = (
    ((column_offset: -2; row_offset: -2), (column_offset: -1; row_offset: -2), (column_offset: 0; row_offset: -2), (column_offset: 1; row_offset: -2), (column_offset: 2; row_offset: -2)),
    ((column_offset: -2; row_offset: -1), (column_offset: -1; row_offset: -1), (column_offset: 0; row_offset: -1), (column_offset: 1; row_offset: -1), (column_offset: 2; row_offset: -1)),
    ((column_offset: -2; row_offset: 0),  (column_offset: -1; row_offset: 0),  (column_offset: 0; row_offset: 0),  (column_offset: 1; row_offset: 0),  (column_offset: 2; row_offset: 0)),
    ((column_offset: -2; row_offset: 1),  (column_offset: -1; row_offset: 1),  (column_offset: 0; row_offset: 1),  (column_offset: 1; row_offset: 1),  (column_offset: 2; row_offset: 1)),
    ((column_offset: -2; row_offset: 2),  (column_offset: -1; row_offset: 2),  (column_offset: 0; row_offset: 2),  (column_offset: 1; row_offset: 2),  (column_offset: 2; row_offset: 2))
  );

procedure UpdVisualArea;
var
  current_column, current_row: Integer;
  column, row: Integer;
  column_offset_index, row_offset_index: Integer;
  first_column_offset_index, last_column_offset_index: Integer;
begin
  current_column := world_xpos div 50;
  current_row := world_ypos div 50;
  first_column_offset_index := 0;

  WorldGrid[current_row][current_column] := 2;

  if perk_level(Ord(PERK_SCOUT)) <> 0 then
  begin
    last_column_offset_index := 5;
    for row_offset_index := 0 to 4 do
    begin
      row := current_row + uva_scout_offsets[row_offset_index][0].row_offset;
      if row >= 30 then Break;
      if row >= 0 then
        for column_offset_index := first_column_offset_index to last_column_offset_index - 1 do
        begin
          column := current_column + uva_scout_offsets[row_offset_index][column_offset_index].column_offset;
          if column < 0 then Inc(first_column_offset_index)
          else if column >= 28 then Dec(last_column_offset_index)
          else if WorldGrid[row][column] <> 2 then WorldGrid[row][column] := 1;
        end;
    end;
  end
  else
  begin
    last_column_offset_index := 3;
    for row_offset_index := 0 to 2 do
    begin
      row := current_row + uva_offsets[row_offset_index][0].row_offset;
      if row >= 30 then Break;
      if row >= 0 then
        for column_offset_index := first_column_offset_index to last_column_offset_index - 1 do
        begin
          column := current_column + uva_offsets[row_offset_index][column_offset_index].column_offset;
          if column < 0 then Inc(first_column_offset_index)
          else if column >= 28 then Dec(last_column_offset_index)
          else if WorldGrid[row][column] <> 2 then WorldGrid[row][column] := 1;
        end;
    end;
  end;

  if current_column <= OceanSeeXTable[current_row] then
    for column := 0 to OceanSeeXTable[current_row] - 1 do
      WorldGrid[current_row][column] := 2;
end;

{ ================================================================ }
{ CheckEvents                                                       }
{ ================================================================ }
function CheckEvents: Integer;
begin
  Result := 0;

  if (ggv(Ord(GVAR_VAULT_WATER)) = 0) and (ggv(Ord(GVAR_FIND_WATER_CHIP)) <> 2) then
  begin
    debug_printf(#10'WORLD MAP: Vault water time ran out (death).'#10);
    BlackOut();
    gmovie_play(MOVIE_BOIL3, GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC);
    game_user_wants_to_quit := 1;
    Result := 1;
  end
  else
  begin
    if ggv(Ord(GVAR_VATS_COUNTDOWN)) <> 0 then
    begin
      if (game_time() - LongWord(ggv(Ord(GVAR_VATS_COUNTDOWN)))) div 10 > 240 then
      begin
        debug_printf(#10'WORLD MAP: Doing "Vats explode" specail.'#10);
        gmovie_play(MOVIE_VEXPLD, GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC);
        ggv_set(Ord(GVAR_DESTROY_MASTER_4), 2);

        if ggv(Ord(GVAR_MASTER_BLOWN)) <> 0 then
        begin
          worldmap_script_jump(0, 0);
          Result := 1;
          if LoadTownMap(TownHotSpots[TOWN_VAULT_13][0].name, TownHotSpots[TOWN_VAULT_13][0].map_idx) = -1 then
            Result := -1;
        end;

        stat_pc_add_experience(10000);
        ggv_inc(Ord(GVAR_PLAYER_REPUATION), 5);
        if ggv(Ord(GVAR_PLAYER_REPUATION)) < -100 then ggv_set(Ord(GVAR_PLAYER_REPUATION), -100)
        else if ggv(Ord(GVAR_PLAYER_REPUATION)) > 100 then ggv_set(Ord(GVAR_PLAYER_REPUATION), 100);

        display_print(getmsg(@wrldmap_mesg_file, @mesg, 500));
        ggv_set(Ord(GVAR_VATS_COUNTDOWN), 0);
        ggv_set(Ord(GVAR_VATS_BLOWN), 1);
      end;
    end;

    if ggv(Ord(GVAR_COUNTDOWN_TO_DESTRUCTION)) <> 0 then
    begin
      if (game_time() - LongWord(ggv(Ord(GVAR_COUNTDOWN_TO_DESTRUCTION)))) div 10 > 240 then
      begin
        debug_printf(#10'WORLD MAP: Doing "Master lair explode" specail.'#10);
        gmovie_play(MOVIE_CATHEXP, GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC);
        ggv_set(Ord(GVAR_DESTROY_MASTER_5), 2);

        if ggv(Ord(GVAR_VATS_BLOWN)) <> 0 then
        begin
          worldmap_script_jump(0, 0);
          Result := 1;
          if LoadTownMap(TownHotSpots[TOWN_VAULT_13][0].name, TownHotSpots[TOWN_VAULT_13][0].map_idx) = -1 then
            Result := -1;
        end;

        stat_pc_add_experience(10000);
        ggv_inc(Ord(GVAR_PLAYER_REPUATION), 10);
        if ggv(Ord(GVAR_PLAYER_REPUATION)) < -100 then ggv_set(Ord(GVAR_PLAYER_REPUATION), -100)
        else if ggv(Ord(GVAR_PLAYER_REPUATION)) > 100 then ggv_set(Ord(GVAR_PLAYER_REPUATION), 100);

        ggv_set(Ord(GVAR_COUNTDOWN_TO_DESTRUCTION), 0);
        ggv_set(Ord(GVAR_MASTER_BLOWN), 1);
      end;
    end;
  end;
end;

{ ================================================================ }
{ LoadTownMap                                                       }
{ ================================================================ }
function LoadTownMap(const filename: PAnsiChar; map_idx: Integer): Integer;
var
  filename_copy: array[0..15] of AnsiChar;
  childead_map_filename: array[0..15] of AnsiChar;
  mbdead_map_filename: array[0..15] of AnsiChar;
  dbg, index: Integer;
  fn: PAnsiChar;
begin
  StrCopy(childead_map_filename, 'CHILDEAD.MAP');
  StrCopy(mbdead_map_filename, 'MBDEAD.MAP');
  fn := filename;

  dbg := 1;
  if (ggv(Ord(GVAR_MASTER_BLOWN)) <> 0) and (StrComp(filename, TownHotSpots[TOWN_CATHEDRAL][0].name) = 0) then
  begin
    fn := childead_map_filename;
    map_idx := 0;
    dbg := 0;
    debug_printf('WORLD MAP: Loading special "crater" map, filename: %s, map index#: %d.'#10, [PAnsiChar(childead_map_filename), 0]);
  end
  else if ggv(Ord(GVAR_VATS_BLOWN)) <> 0 then
  begin
    for index := 0 to 4 do
      if StrComp(filename, TownHotSpots[TOWN_MILITARY_BASE][index].name) = 0 then
      begin
        fn := mbdead_map_filename;
        map_idx := 0;
        dbg := 0;
        debug_printf('WORLD MAP: Loading special "crater" map, filename: %s, map index#: %d.'#10, [PAnsiChar(mbdead_map_filename), 0]);
        Break;
      end;
  end;

  if dbg <> 0 then
    debug_printf('WORLD MAP: Loading map, filename: %s, map index#: %d.'#10, [fn, map_idx]);

  FillChar(world_buf^, WM_WINDOW_WIDTH * WM_WINDOW_HEIGHT, colorTable[0]);
  win_draw(world_win);
  renderPresent();

  ggv_set(Ord(GVAR_LOAD_MAP_INDEX), map_idx);
  StrCopy(filename_copy, fn);

  if map_load(filename_copy) = -1 then
  begin
    debug_printf(#10'WORLD MAP: ** Error loading town map! **'#10);
    Exit(-1);
  end;

  PlayCityMapMusic();
  obj_turn_on(obj_dude, nil);
  tile_refresh_display();

  if bx_enable <> 0 then enable_box_bar_win();

  debug_printf('WORLD MAP: Map load complete.'#10#10);
  Result := 0;
end;

{ ================================================================ }
{ TargetTown                                                        }
{ ================================================================ }
procedure TargetTown(city: Integer);
var
  offset: Integer;
begin
  target_xpos := 50 * city_location[city].column + 50 div 2;
  target_ypos := 50 * city_location[city].row + 50 div 2;

  offset := roll_random(0, 16);
  if roll_random(0, 1) <> 0 then Inc(target_xpos, offset) else Dec(target_xpos, offset);

  offset := roll_random(0, 16);
  if roll_random(0, 1) <> 0 then Inc(target_ypos, offset) else Dec(target_ypos, offset);

  world_move_init();
end;

{ ================================================================ }
{ InitWorldMapData                                                  }
{ ================================================================ }
function InitWorldMapData: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  index, fid: Integer;
begin
  bk_enable := 0;

  if not message_init(@wrldmap_mesg_file) then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading world map graphics! ***'#10);
    Exit(-1);
  end;

  StrLFmt(path, SizeOf(path) - 1, '%s%s', [msg_path, 'worldmap.msg']);

  if not message_load(@wrldmap_mesg_file, @path[0]) then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading world map graphics! ***'#10);
    Exit(-1);
  end;

  for index := 0 to WORLDMAP_FRM_COUNT - 1 do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, wmapids[index], 0, 0, 0);
    wmapbmp[index] := art_ptr_lock_data(fid, 0, 0, @wmapidsav[index]);
    if wmapbmp[index] = nil then Break;
    soundUpdate();
  end;

  if index <> WORLDMAP_FRM_COUNT then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading world map graphics! ***'#10);
    while index > 0 do begin Dec(index); art_ptr_unlock(wmapidsav[index]); end;
    message_exit(@wrldmap_mesg_file);
    Exit(-1);
  end;

  sea_mask := PByte(mem_malloc(263524));
  if sea_mask = nil then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading world map graphics! ***'#10);
    for index := 0 to WORLDMAP_FRM_COUNT - 1 do art_ptr_unlock(wmapidsav[index]);
    message_exit(@wrldmap_mesg_file);
    Exit(-1);
  end;

  line1bit_buf := PByte(mem_malloc(263524));
  if line1bit_buf = nil then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading world map graphics! ***'#10);
    for index := 0 to WORLDMAP_FRM_COUNT - 1 do art_ptr_unlock(wmapidsav[index]);
    mem_free(sea_mask);
    message_exit(@wrldmap_mesg_file);
    Exit(-1);
  end;

  FillChar(line1bit_buf^, 262500, 0);

  if wwin_flag = 0 then
  begin
    world_win := win_add((screenGetWidth() - WM_WINDOW_WIDTH) div 2,
      (screenGetHeight() - WM_WINDOW_HEIGHT) div 2, WM_WINDOW_WIDTH, WM_WINDOW_HEIGHT, 256, WINDOW_DONT_MOVE_TOP);
    if world_win = -1 then
    begin
      debug_printf(#10' *** WORLD MAP: Error adding world map window! ***'#10);
      for index := 0 to WORLDMAP_FRM_COUNT - 1 do art_ptr_unlock(wmapidsav[index]);
      mem_free(sea_mask);
      mem_free(line1bit_buf);
      message_exit(@wrldmap_mesg_file);
      Exit(-1);
    end;
    wwin_flag := 1;
  end;

  world_buf := win_get_buf(world_win);

  if tbutntgl <> 0 then
  begin
    for index := 0 to TOWN_COUNT - 1 do
    begin
      win_register_button_image(TownBttns[index], wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
        wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, False);
      win_enable_button(TownBttns[index]);
    end;
    win_register_button_image(WrldToggle, wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
      wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, False);
    win_enable_button(WrldToggle);
  end
  else
  begin
    for index := 0 to TOWN_COUNT - 1 do
    begin
      TownBttns[index] := win_register_button(world_win, 508, BttnYtab[index], 15, 15,
        -1, -1, -1, 500 + index, wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
        wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, BUTTON_FLAG_TRANSPARENT);
      win_register_button_sound_func(TownBttns[index], @gsound_red_butt_press, @gsound_red_butt_release);
    end;
    WrldToggle := win_register_button(world_win, 520, 439, 15, 15,
      -1, -1, -1, 512, wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
      wmapbmp[WORLDMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, BUTTON_FLAG_TRANSPARENT);
    win_register_button_sound_func(WrldToggle, @gsound_red_butt_press, @gsound_red_butt_release);
    tbutntgl := 1;
  end;

  soundUpdate();
  UpdateTownStatus();
  text_font(101);
  bx_enable := Ord(disable_box_bar_win());
  Result := 0;
end;

{ ================================================================ }
{ UnInitWorldMapData                                                }
{ ================================================================ }
procedure UnInitWorldMapData;
var
  index: Integer;
begin
  mem_free(line1bit_buf);
  mem_free(sea_mask);
  message_exit(@wrldmap_mesg_file);
  for index := 0 to WORLDMAP_FRM_COUNT - 1 do art_ptr_unlock(wmapidsav[index]);
  intface_update_hit_points(False);
end;

{ ================================================================ }
{ UpdateTownStatus                                                  }
{ ================================================================ }
procedure UpdateTownStatus;
var
  city, entrance, gvar: Integer;
begin
  for city := 1 to TOWN_COUNT - 1 do
  begin
    for entrance := 0 to 6 do
    begin
      gvar := ElevXgvar[city][entrance];
      if gvar = 0 then Break;
      TwnSelKnwFlag[city][entrance] := ggv(gvar);
      if TwnSelKnwFlag[city][entrance] <> 0 then TwnSelKnwFlag[city][entrance] := 1;
    end;

    if ggv(cityXgvar[city]) = 1 then
    begin
      if WorldGrid[city_location[city].row][city_location[city].column] = 0 then
        WorldGrid[city_location[city].row][city_location[city].column] := 1;
      first_visit_flag := first_visit_flag or (1 shl city);
      TwnSelKnwFlag[city][0] := 1;
    end;
  end;

  if (game_time() div 864000) <> 0 then
  begin
    TwnSelKnwFlag[TOWN_VAULT_13][0] := 1;
    TwnSelKnwFlag[TOWN_VAULT_13][1] := 1;
    TwnSelKnwFlag[TOWN_VAULT_13][2] := 1;
    TwnSelKnwFlag[TOWN_VAULT_13][3] := 1;
  end
  else
  begin
    TwnSelKnwFlag[TOWN_VAULT_13][0] := 1;
    TwnSelKnwFlag[TOWN_VAULT_13][1] := 0;
    TwnSelKnwFlag[TOWN_VAULT_13][2] := 0;
    TwnSelKnwFlag[TOWN_VAULT_13][3] := 0;
  end;

  if (ggv(Ord(GVAR_MASTER_BLOWN)) <> 0) or (TwnSelKnwFlag[TOWN_CATHEDRAL][0] <> 0) or (TwnSelKnwFlag[TOWN_CATHEDRAL][1] <> 0) then
    TwnSelKnwFlag[TOWN_SPECIAL_12][0] := 1;
  if (ggv(Ord(GVAR_VATS_BLOWN)) <> 0) or (TwnSelKnwFlag[TOWN_MILITARY_BASE][0] <> 0) or (TwnSelKnwFlag[TOWN_MILITARY_BASE][1] <> 0)
    or (TwnSelKnwFlag[TOWN_MILITARY_BASE][2] <> 0) or (TwnSelKnwFlag[TOWN_MILITARY_BASE][3] <> 0) or (TwnSelKnwFlag[TOWN_MILITARY_BASE][4] <> 0) then
    TwnSelKnwFlag[TOWN_SPECIAL_13][0] := 1;
  if (TwnSelKnwFlag[TOWN_BROTHERHOOD][1] <> 0) or (TwnSelKnwFlag[TOWN_BROTHERHOOD][2] <> 0) or (TwnSelKnwFlag[TOWN_BROTHERHOOD][3] <> 0) or (TwnSelKnwFlag[TOWN_BROTHERHOOD][4] <> 0) then
    TwnSelKnwFlag[TOWN_SPECIAL_14][0] := 1;
end;

{ ================================================================ }
{ InCity                                                            }
{ ================================================================ }
function InCity(x, y: LongWord): Integer;
var
  city, column, row: Integer;
begin
  column := x div 50;
  row := y div 50;
  for city := 0 to TOWN_COUNT - 1 do
    if (city_location[city].column = column) and (city_location[city].row = row) then
      Exit(city);
  Result := -1;
end;

{ ================================================================ }
{ world_move_init                                                   }
{ ================================================================ }
procedure world_move_init;
begin
  old_world_xpos := world_xpos;
  old_world_ypos := world_ypos;
  deltaLineX := target_xpos - world_xpos;
  deltaLineY := target_ypos - world_ypos;
  line_error := 0;
  line_index := 0;

  if deltaLineX < 0 then begin x_line_inc := -1; deltaLineX := -deltaLineX; end
  else x_line_inc := 1;

  if deltaLineY < 0 then begin y_line_inc := -1; deltaLineY := -deltaLineY; end
  else y_line_inc := 1;
end;

{ ================================================================ }
{ world_move_step                                                   }
{ ================================================================ }
function world_move_step: Integer;
begin
  old_world_xpos := world_xpos;
  old_world_ypos := world_ypos;

  if deltaLineX <= deltaLineY then
  begin
    Inc(line_index);
    if line_index > deltaLineY then Exit(1);
    Inc(line_error, deltaLineX);
    if line_error > 0 then
    begin
      Dec(line_error, deltaLineY);
      Inc(world_xpos, x_line_inc);
    end;
    Inc(world_ypos, y_line_inc);
  end
  else
  begin
    Inc(line_index);
    if line_index > deltaLineX then Exit(1);
    Inc(line_error, deltaLineY);
    if line_error > deltaLineX then
    begin
      Dec(line_error, deltaLineX);
      Inc(world_ypos, y_line_inc);
    end;
    Inc(world_xpos, x_line_inc);
  end;
  Result := 0;
end;

{ ================================================================ }
{ block_map                                                         }
{ ================================================================ }
procedure block_map(x, y: LongWord; dst: PByte);
var
  first_row, first_column: LongWord;
  column, row: LongWord;
  dst_y, dst_height, first_dst_width: LongWord;
  dst_x, dst_width: LongWord;
begin
  first_row := y div 50;
  first_column := x div 50;
  dst_y := 21;
  dst_height := 50 - (y mod 50);
  first_dst_width := 50 - (x mod 50);

  row := first_row;
  while row < first_row + 10 do
  begin
    dst_x := 22;
    dst_width := first_dst_width;

    column := first_column;
    while column < first_column + 9 do
    begin
      case WorldGrid[row][column] of
        0: buf_fill(dst + 640 * dst_y + dst_x, dst_width, dst_height, 640, colorTable[0]);
        1: dark_trans_buf_to_buf(dst + 640 * dst_y + dst_x, dst_width, dst_height, 640, dst, dst_x, dst_y, 640, 32786);
      end;
      Inc(dst_x, dst_width);
      dst_width := 50;
      Inc(column);
    end;

    case WorldGrid[row][column] of
      0: buf_fill(dst + 640 * dst_y + dst_x, x mod 50, dst_height, 640, colorTable[0]);
      1: dark_trans_buf_to_buf(dst + 640 * dst_y + dst_x, x mod 50, dst_height, 640, dst, dst_x, dst_y, 640, 32786);
    end;

    Inc(dst_y, dst_height);
    dst_height := 50;
    if dst_y + 50 > 463 then
    begin
      dst_height := 463 - dst_y;
      if Integer(dst_height) <= 0 then Break;
    end;

    Inc(row);
  end;
end;

{ ================================================================ }
{ DrawTownLabels                                                    }
{ ================================================================ }
procedure DrawTownLabels(src, dst: PByte);
var
  index: Integer;
  flag: Integer;
begin
  flag := first_visit_flag;
  for index := 0 to TOWN_COUNT - 1 do
  begin
    if (flag and 1) <> 0 then
      trans_buf_to_buf(src + (82 * 18) * index, 82, 18, 82, dst + 640 * BttnYtab[index] + 531, 640);
    flag := flag shr 1;
  end;
end;

{ ================================================================ }
{ DrawMapTime                                                       }
{ ================================================================ }
procedure DrawMapTime(is_town_map: Integer);
var
  month, day, year: Integer;
  src: PByte;
begin
  game_time_date(@month, @day, @year);
  map_num(day, 2, DAY_X, DAY_Y, is_town_map);

  if is_town_map <> 0 then src := tmapbmp[TOWNMAP_FRM_MONTHS]
  else src := wmapbmp[WORLDMAP_FRM_MONTHS];
  buf_to_buf(src + 435 * (month - 1), 29, 14, 29, world_buf + WM_WINDOW_WIDTH * MONTH_Y + MONTH_X, WM_WINDOW_WIDTH);

  map_num(year, 4, YEAR_X, YEAR_Y, is_town_map);
  map_num(game_time_hour(), 4, TIME_X, TIME_Y, is_town_map);
end;

{ ================================================================ }
{ map_num                                                           }
{ ================================================================ }
procedure map_num(value, digits, x, y, is_town_map: Integer);
var
  dst, src: PByte;
begin
  dst := world_buf + WM_WINDOW_WIDTH * y + x + 9 * (digits - 1);
  if is_town_map <> 0 then src := tmapbmp[TOWNMAP_FRM_NUMBERS]
  else src := wmapbmp[WORLDMAP_FRM_NUMBERS];
  while digits > 0 do
  begin
    buf_to_buf(src + 9 * (value mod 10), 9, 17, 360, dst, WM_WINDOW_WIDTH);
    Dec(dst, 9);
    value := value div 10;
    Dec(digits);
  end;
end;

{ ================================================================ }
{ town_map                                                          }
{ ================================================================ }
function town_map(ctx: TWorldMapContext): TWorldMapContext;
var
  title, text_: PAnsiChar;
  body: array[0..0] of PAnsiChar;
  index, fid, j: Integer;
  tmap_pic_key: Pointer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  tmap_sels_count: Integer;
  time_: LongWord;
  input: Integer;
  new_ctx: TWorldMapContext;
begin
  new_ctx.state := -1;
  new_ctx.section := 0;
  new_ctx.town := 0;

  if ctx.town > TOWN_COUNT then begin Result := new_ctx; Exit; end;
  if game_user_wants_to_quit <> 0 then begin Result := new_ctx; Exit; end;

  title := '';
  text_ := getmsg(@map_msg_file, @mesg, 1000);
  body[0] := text_;

  if map_save_in_game(True) = -1 then
  begin
    debug_printf(#10'WORLD MAP: ** Error saving map! **'#10);
    gmouse_disable(0);
    gmouse_set_cursor(1);
    gsound_play_sfx_file('iisxxxx1');
    dialog_out(title, @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
    gmouse_enable();
    game_user_wants_to_quit := 2;
    new_ctx.state := 1;
    Result := new_ctx;
    Exit;
  end;

  for index := 0 to TOWNMAP_FRM_COUNT - 1 do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, tmapids[index], 0, 0, 0);
    tmapbmp[index] := art_ptr_lock_data(fid, 0, 0, @tmapidsav[index]);
    if tmapbmp[index] = nil then Break;
  end;

  if index <> TOWNMAP_FRM_COUNT then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading town map graphics! ***'#10);
    while index > 0 do begin Dec(index); art_ptr_unlock(tmapidsav[index]); end;
    new_ctx.state := 1;
    Result := new_ctx;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, ctx.town + 156, 0, 0, 0);
  tmap_pic := art_ptr_lock_data(fid, 0, 0, @tmap_pic_key);
  if tmap_pic = nil then
  begin
    debug_printf(#10' *** WORLD MAP: Error loading town map graphics! ***'#10);
    for index := 0 to 7 do art_ptr_unlock(tmapidsav[index]);
    Result := new_ctx;
    Exit;
  end;

  text_font(101);

  onbtn := PByte(mem_malloc(4100));
  if onbtn = nil then
  begin
    for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
    art_ptr_unlock(tmap_pic_key);
    Result := new_ctx;
    Exit;
  end;

  offbtn := PByte(mem_malloc(4100));
  if offbtn = nil then
  begin
    for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
    art_ptr_unlock(tmap_pic_key);
    Result := new_ctx;
    Exit;
  end;

  btnmsk := PByte(mem_malloc(4100));
  if btnmsk = nil then
  begin
    for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
    art_ptr_unlock(tmap_pic_key);
    Result := new_ctx;
    Exit;
  end;

  for index := 0 to 6 do
  begin
    hvrbtn[index] := PByte(mem_malloc(4100));
    if hvrbtn[index] = nil then
    begin
      j := index;
      while j > 0 do begin Dec(j); mem_free(hvrbtn[j]); end;
      mem_free(onbtn); mem_free(offbtn); mem_free(btnmsk);
      for j := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[j]);
      art_ptr_unlock(tmap_pic_key);
      Result := new_ctx;
      Exit;
    end;
  end;

  FillChar(onbtn^, 4100, 0);
  buf_to_buf(tmapbmp[TOWNMAP_FRM_HOTSPOT_NORMAL], HOTSPOT_WIDTH, HOTSPOT_HEIGHT, HOTSPOT_WIDTH,
    onbtn + 164 * 12 + 69, 164);
  FillChar(offbtn^, 4100, 0);
  buf_to_buf(tmapbmp[TOWNMAP_FRM_HOTSPOT_PRESSED], HOTSPOT_WIDTH, HOTSPOT_HEIGHT, HOTSPOT_WIDTH,
    offbtn + 164 * 12 + 69, 164);
  FillChar(btnmsk^, 4100, 0);
  buf_to_buf(tmapbmp[TOWNMAP_FRM_HOTSPOT_PRESSED], HOTSPOT_WIDTH, HOTSPOT_HEIGHT, HOTSPOT_WIDTH,
    btnmsk + 164 * 12 + 69, 164);
  trans_buf_to_buf(tmapbmp[TOWNMAP_FRM_HOTSPOT_NORMAL], HOTSPOT_WIDTH, HOTSPOT_HEIGHT, HOTSPOT_WIDTH,
    btnmsk + 164 * 12 + 69, 164);

  if not message_init(@wrldmap_mesg_file) then
  begin
    for index := 0 to 6 do mem_free(hvrbtn[index]);
    mem_free(onbtn); mem_free(offbtn); mem_free(btnmsk);
    for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
    art_ptr_unlock(tmap_pic_key);
    Result := new_ctx;
    Exit;
  end;

  StrLFmt(path, SizeOf(path) - 1, '%s%s', [msg_path, 'worldmap.msg']);

  if not message_load(@wrldmap_mesg_file, @path[0]) then
  begin
    for index := 0 to 6 do mem_free(hvrbtn[index]);
    mem_free(onbtn); mem_free(offbtn); mem_free(btnmsk);
    for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
    art_ptr_unlock(tmap_pic_key);
    Result := new_ctx;
    Exit;
  end;

  if wwin_flag = 0 then
  begin
    world_win := win_add((screenGetWidth() - WM_WINDOW_WIDTH) div 2,
      (screenGetHeight() - WM_WINDOW_HEIGHT) div 2, WM_WINDOW_WIDTH, WM_WINDOW_HEIGHT, 256, WINDOW_DONT_MOVE_TOP);
    if world_win = -1 then
    begin
      debug_printf(#10' *** WORLD MAP: Error adding town map window! ***'#10);
      Result := new_ctx;
      Exit;
    end;
    wwin_flag := 1;
  end;

  if tbutntgl <> 0 then
  begin
    for index := 0 to TOWN_COUNT - 1 do
    begin
      win_register_button_image(TownBttns[index], tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
        tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, False);
      win_enable_button(TownBttns[index]);
    end;
    win_register_button_image(WrldToggle, tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
      tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, False);
    win_enable_button(WrldToggle);
  end
  else
  begin
    for index := 0 to TOWN_COUNT - 1 do
    begin
      TownBttns[index] := win_register_button(world_win, 508, BttnYtab[index], 15, 15,
        -1, -1, -1, 500 + index, tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
        tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, BUTTON_FLAG_TRANSPARENT);
      win_register_button_sound_func(TownBttns[index], @gsound_red_butt_press, @gsound_red_butt_release);
    end;
    WrldToggle := win_register_button(world_win, 520, 439, 15, 15,
      -1, -1, -1, 512, tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_NORMAL],
      tmapbmp[TOWNMAP_FRM_LITTLE_RED_BUTTON_PRESSED], nil, BUTTON_FLAG_TRANSPARENT);
    win_register_button_sound_func(WrldToggle, @gsound_red_butt_press, @gsound_red_butt_release);
    tbutntgl := 1;
  end;

  UpdateTownStatus();
  tmap_sels_count := RegTMAPsels(world_win, ctx.town);

  intface_hide();
  win_fill(display_win, 0, 0, win_width(display_win), win_height(display_win), colorTable[0]);
  win_draw(display_win);

  world_buf := win_get_buf(world_win);
  buf_to_buf(tmap_pic, 453, 444, 453, world_buf + 640 * 20 + 20, 640);
  trans_buf_to_buf(tmapbmp[TOWNMAP_FRM_BOX], 640, 480, 640, world_buf, 640);
  DrawTownLabels(tmapbmp[TOWNMAP_FRM_LABELS], world_buf);
  DrawMapTime(1);
  win_draw(world_win);
  renderPresent();

  bk_enable := Ord(map_disable_bk_processes());
  cycle_disable();
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  while new_ctx.state = -1 do
  begin
    sharedFpsLimiter.Mark;
    time_ := get_time();
    input := get_input();

    if (input >= 500) and (input < 512) then
    begin
      if (first_visit_flag and (1 shl (input - 500))) <> 0 then
      begin
        ctx.town := input - 500;
        UnregTMAPsels(tmap_sels_count);
        art_ptr_unlock(tmap_pic_key);
        fid := art_id(OBJ_TYPE_INTERFACE, input - 344, 0, 0, 0);
        tmap_pic := art_ptr_lock_data(fid, 0, 0, @tmap_pic_key);
        if tmap_pic = nil then
        begin
          debug_printf(#10' *** WORLD MAP: Error loading town map graphic! ***'#10);
          new_ctx.state := -1;
          Break;
        end;
        tmap_sels_count := RegTMAPsels(world_win, ctx.town);
        buf_to_buf(tmap_pic, 453, 444, 453, world_buf + 640 * 20 + 20, 640);
        trans_buf_to_buf(tmapbmp[TOWNMAP_FRM_BOX], 640, 480, 640, world_buf, 640);
        DrawTownLabels(tmapbmp[TOWNMAP_FRM_LABELS], world_buf);
        DrawMapTime(1);
      end;
    end
    else if (input >= 514) and (input < 514 + tmap_sels_count) then
    begin
      new_ctx.state := 2;
      new_ctx.town := ctx.town;
      new_ctx.section := tcode_xref[input - 514];
      debug_printf('The tparm is %d'#10, [new_ctx.section]);
    end
    else
    begin
      case input of
        512: new_ctx.state := 3;
        KEY_CTRL_Q, KEY_CTRL_X, KEY_F10: game_quit_with_confirm();
        KEY_F12: dump_screen();
        KEY_EQUAL, KEY_PLUS: IncGamma();
        KEY_MINUS, KEY_UNDERSCORE: DecGamma();
      end;
    end;

    if game_user_wants_to_quit <> 0 then
    begin
      new_ctx.state := 1;
      Break;
    end;

    win_draw(world_win);
    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  UnregTMAPsels(tmap_sels_count);
  buf_to_buf(tmap_pic, 453, 444, 453, world_buf + 640 * 20 + 20, 640);
  trans_buf_to_buf(tmapbmp[TOWNMAP_FRM_BOX], 640, 480, 640, world_buf, 640);
  DrawTownLabels(tmapbmp[TOWNMAP_FRM_LABELS], world_buf);
  DrawMapTime(1);
  DrawTMAPsels(world_win, ctx.town);
  win_draw(world_win);
  renderPresent();

  for index := 0 to TOWNMAP_FRM_COUNT - 1 do art_ptr_unlock(tmapidsav[index]);
  art_ptr_unlock(tmap_pic_key);

  mem_free(onbtn);
  mem_free(offbtn);
  mem_free(btnmsk);
  for index := 0 to 7 do mem_free(hvrbtn[index]);

  message_exit(@wrldmap_mesg_file);

  if bk_enable <> 0 then map_enable_bk_processes();
  cycle_enable();

  Result := new_ctx;
end;

{ ================================================================ }
{ KillWorldWin                                                      }
{ ================================================================ }
procedure KillWorldWin;
begin
  if wwin_flag <> 0 then
  begin
    win_delete(world_win);
    tbutntgl := 0;
    wwin_flag := 0;
    dropbtn := 0;
  end;
end;

{ ================================================================ }
{ HvrOffBtn                                                         }
{ ================================================================ }
procedure HvrOffBtn(a1, a2: Integer); cdecl;
var
  entrance, px: Integer;
  mask: array[0..4099] of Byte;
begin
  entrance := 0;
  for entrance := 0 to 6 do
    if brnpos[entrance].bid = a1 then Break;

  for px := 0 to 4099 do
    mask[px] := hvrbtn[entrance][px] or btnmsk[px];

  mask_buf_to_buf(tmap_pic + 453 * (brnpos[entrance].y - 20) + brnpos[entrance].x - 20,
    164, 25, 453, @mask[0], 164,
    world_buf + 640 * brnpos[entrance].y + brnpos[entrance].x, 640);
end;

{ ================================================================ }
{ RegTMAPsels                                                       }
{ ================================================================ }
function RegTMAPsels(win, city: Integer): Integer;
var
  count: Integer;
  color: Integer;
  v4, index: Integer;
  name: array[0..63] of AnsiChar;
  name_x: Integer;
  button_x, button_y: Integer;
  entry: ^TTownHotSpotEntry;
begin
  color := colorTable[992] or $10000;
  v4 := 0;

  if (city = TOWN_CATHEDRAL) and (ggv(Ord(GVAR_MASTER_BLOWN)) <> 0) then
  begin city := TOWN_SPECIAL_12; v4 := 1; end
  else if (city = TOWN_MILITARY_BASE) and (ggv(Ord(GVAR_VATS_BLOWN)) <> 0) then
  begin city := TOWN_SPECIAL_13; v4 := 2; end;

  count := 0;
  for index := 0 to 6 do
  begin
    entry := @TownHotSpots[city][index];
    if (entry^.x = 0) or (entry^.y = 0) then Break;

    if TwnSelKnwFlag[city][index] <> 0 then
    begin
      FillChar(hvrbtn[count]^, 164 * 25, 0);
      buf_to_buf(tmapbmp[TOWNMAP_FRM_HOTSPOT_NORMAL], HOTSPOT_WIDTH, HOTSPOT_HEIGHT, HOTSPOT_WIDTH,
        hvrbtn[count] + 164 * 12 + 69, 164);

      case v4 of
        0: StrCopy(name, getmsg(@wrldmap_mesg_file, @mesg, 10 * city + index + 200));
        1: StrCopy(name, getmsg(@wrldmap_mesg_file, @mesg, 290));
        2: StrCopy(name, getmsg(@wrldmap_mesg_file, @mesg, 501));
      end;

      name_x := (164 - text_width(@name[0])) div 2;
      if name_x < 0 then name_x := 0;

      text_to_buf(hvrbtn[count] + name_x, @name[0], 164, 164, color);

      button_x := entry^.x - 57;
      button_y := entry^.y - 6;

      TMSelBttns[count] := win_register_button(win, entry^.x - 57, entry^.y - 6, 164, 25,
        -1, -1, -1, 514 + count, onbtn, offbtn, hvrbtn[count], BUTTON_FLAG_TRANSPARENT);
      win_register_button_mask(TMSelBttns[count], btnmsk);
      win_register_button_func(TMSelBttns[count], nil, @HvrOffBtn, nil, nil);

      debug_printf('button found count=%d, bcount=%d, btnid=%d'#10, [index, count, TMSelBttns[count]]);

      win_register_button_sound_func(TMSelBttns[count], @gsound_med_butt_press, nil);

      brnpos[count].x := button_x;
      brnpos[count].y := button_y;
      brnpos[count].bid := TMSelBttns[count];
      tcode_xref[count] := index;
      Inc(count);
    end;
  end;

  debug_printf('button total bcount=%d'#10, [count]);
  Result := count;
end;

{ ================================================================ }
{ UnregTMAPsels                                                     }
{ ================================================================ }
procedure UnregTMAPsels(count: Integer);
var
  index: Integer;
begin
  for index := 0 to count - 1 do
    win_delete_button(TMSelBttns[index]);
end;

{ ================================================================ }
{ DrawTMAPsels                                                      }
{ ================================================================ }
procedure DrawTMAPsels(win, city: Integer);
var
  index: Integer;
  entry: ^TTownHotSpotEntry;
begin
  if (city = TOWN_CATHEDRAL) and (ggv(Ord(GVAR_MASTER_BLOWN)) <> 0) then
    city := TOWN_SPECIAL_12
  else if (city = TOWN_MILITARY_BASE) and (ggv(Ord(GVAR_VATS_BLOWN)) <> 0) then
    city := TOWN_SPECIAL_13;

  for index := 0 to 6 do
  begin
    entry := @TownHotSpots[city][index];
    if (entry^.x = 0) or (entry^.y = 0) then Break;
    if TwnSelKnwFlag[city][index] <> 0 then
      trans_buf_to_buf(onbtn, 164, 25, 164,
        win_get_buf(win) + entry^.x - 57 + 640 * (entry^.y - 6), 640);
  end;
end;

{ ================================================================ }
{ worldmap_script_jump                                              }
{ ================================================================ }
function worldmap_script_jump(city, a2: Integer): Integer;
var
  v1, rc: Integer;
begin
  if (city < 0) or (city >= TOWN_COUNT) then Exit(-1);

  if InCity(world_xpos, world_ypos) <> city then
  begin
    rc := 0;
    TargetTown(city);
    world_move_init();
    CalcTimeAdder();
    wmap_mile := 0;
    v1 := 0;

    while rc = 0 do
    begin
      case WorldTerraTable[world_ypos div 50][world_xpos div 50] of
        1:
          begin
            Dec(v1);
            if v1 <= 0 then begin v1 := 2; rc := world_move_step(); end;
            inc_game_time(time_adder);
          end;
        2:
          begin
            rc := world_move_step();
            Dec(v1);
            if (v1 <= 0) and (rc = 0) then begin v1 := 4; rc := world_move_step(); end;
          end;
      else
        begin
          rc := world_move_step();
          v1 := 0;
          inc_game_time(time_adder);
        end;
      end;

      Inc(wmap_mile);
      if wmap_mile >= wmap_day then
      begin
        wmap_mile := 0;
        partyMemberRestingHeal(24);
      end;
    end;
  end;

  Result := 0;
end;

{ ================================================================ }
{ CalcTimeAdder                                                     }
{ ================================================================ }
procedure CalcTimeAdder;
var
  outdoorsman: Single;
begin
  outdoorsman := Single(skill_level(obj_dude, Ord(SKILL_OUTDOORSMAN)));
  if outdoorsman > 100.0 then outdoorsman := 100.0;

  wmap_day := Trunc((outdoorsman / 100.0) * 60.0 + 60.0);
  time_adder := Trunc(864000.0 / Single(wmap_day));
  time_adder := Trunc(Single(time_adder) * (1.0 - perk_level(Ord(PERK_PATHFINDER)) * 0.25));
end;

{ ================================================================ }
{ xlate_mapidx_to_town                                              }
{ ================================================================ }
function xlate_mapidx_to_town(map_idx: Integer): Integer;
begin
  if (map_idx >= 0) and (map_idx < MAP_COUNT) then
    Result := xlate_town_table[map_idx]
  else
    Result := -1;
end;

{ ================================================================ }
{ PlayCityMapMusic                                                  }
{ ================================================================ }
function PlayCityMapMusic: Integer;
var
  map_idx: Integer;
begin
  map_idx := map_get_index_number();
  if map_idx <> -1 then
    Exit(gsound_background_play_level_music(CityMusic[map_idx], 12));
  debug_printf(#10'MAP: Failed to find map ID for music!');
  Result := -1;
end;

{ ================================================================ }
{ BlackOut                                                          }
{ ================================================================ }
procedure BlackOut;
var
  index: Integer;
begin
  for index := 0 to TOWN_COUNT - 1 do win_disable_button(TownBttns[index]);
  win_disable_button(WrldToggle);
  FillChar(world_buf^, WM_WINDOW_WIDTH * WM_WINDOW_HEIGHT, colorTable[0]);
end;



{ ================================================================ }
{ Initialization of string table data                               }
{ ================================================================ }
procedure InitStringTables;
begin
  RandEnctNames[0][0] := 'DESERT1.MAP';
  RandEnctNames[0][1] := 'DESERT2.MAP';
  RandEnctNames[0][2] := 'DESERT3.MAP';
  RandEnctNames[1][0] := 'MOUNTN1.MAP';
  RandEnctNames[1][1] := 'MOUNTN2.MAP';
  RandEnctNames[1][2] := nil;
  RandEnctNames[2][0] := 'CITY1.MAP';
  RandEnctNames[2][1] := nil;
  RandEnctNames[2][2] := nil;
  RandEnctNames[3][0] := 'COAST1.MAP';
  RandEnctNames[3][1] := 'COAST2.MAP';
  RandEnctNames[3][2] := nil;

  spcl_map_name[0] := 'FOOT.MAP';
  spcl_map_name[1] := 'TALKCOW.MAP';
  spcl_map_name[2] := 'USEDCAR.MAP';
  spcl_map_name[3] := 'TARDIS.MAP';
  spcl_map_name[4] := 'FSAUSER.MAP';
  spcl_map_name[5] := 'COLATRUK.MAP';

  CityMusic[0]  := '07DESERT'; CityMusic[1]  := '07DESERT'; CityMusic[2]  := '07DESERT';
  CityMusic[3]  := '14NECRO';  CityMusic[4]  := '14NECRO';  CityMusic[5]  := '14NECRO';
  CityMusic[6]  := '06VAULT';  CityMusic[7]  := '13CARVRN'; CityMusic[8]  := '13CARVRN';
  CityMusic[9]  := '14NECRO';  CityMusic[10] := '12JUNKTN'; CityMusic[11] := '12JUNKTN';
  CityMusic[12] := '12JUNKTN'; CityMusic[13] := '04BRTHRH'; CityMusic[14] := '04BRTHRH';
  CityMusic[15] := '04BRTHRH'; CityMusic[16] := '13CARVRN'; CityMusic[17] := '11CHILRN';
  CityMusic[18] := '11CHILRN'; CityMusic[19] := '11CHILRN'; CityMusic[20] := '07DESERT';
  CityMusic[21] := '07DESERT'; CityMusic[22] := '07DESERT'; CityMusic[23] := '07DESERT';
  CityMusic[24] := '05RAIDER'; CityMusic[25] := '15SHADY';  CityMusic[26] := '15SHADY';
  CityMusic[27] := '09GLOW';   CityMusic[28] := '10LABONE'; CityMusic[29] := '16FOLLOW';
  CityMusic[30] := '08VATS';   CityMusic[31] := '08VATS';   CityMusic[32] := '08VATS';
  CityMusic[33] := '02MSTRLR'; CityMusic[34] := '02MSTRLR'; CityMusic[35] := '06VAULT';
  CityMusic[36] := '01HUB';    CityMusic[37] := '13CARVRN'; CityMusic[38] := '01HUB';
  CityMusic[39] := '01HUB';    CityMusic[40] := '01HUB';    CityMusic[41] := '01HUB';
  CityMusic[42] := '09GLOW';   CityMusic[43] := '09GLOW';   CityMusic[44] := '10LABONE';
  CityMusic[45] := '10LABONE'; CityMusic[46] := '10LABONE'; CityMusic[47] := '08VATS';
  CityMusic[48] := '08VATS';   CityMusic[49] := '07DESERT'; CityMusic[50] := '07DESERT';
  CityMusic[51] := '07DESERT'; CityMusic[52] := '07DESERT'; CityMusic[53] := '07DESERT';
  CityMusic[54] := '07DESERT'; CityMusic[55] := '08VATS';   CityMusic[56] := '07DESERT';
  CityMusic[57] := '07DESERT'; CityMusic[58] := '07DESERT'; CityMusic[59] := '07DESERT';
  CityMusic[60] := '07DESERT'; CityMusic[61] := '07DESERT'; CityMusic[62] := '07DESERT';
  CityMusic[63] := '07DESERT'; CityMusic[64] := '07DESERT'; CityMusic[65] := '01HUB';
end;

procedure InitTownHotSpots;
var
  i, j: Integer;
begin
  for i := 0 to 14 do
    for j := 0 to 6 do
      InitHotSpot(TownHotSpots[i][j], 0, 0, 0, '');

  { VAULT 13 }
  InitHotSpot(TownHotSpots[0][0], 202, 303, 0, 'V13ENT.MAP');
  InitHotSpot(TownHotSpots[0][1], 271, 282, 1, 'VAULT13.MAP');
  InitHotSpot(TownHotSpots[0][2], 292, 237, 2, 'VAULT13.MAP');
  InitHotSpot(TownHotSpots[0][3], 309, 204, 3, 'VAULT13.MAP');
  { VAULT 15 }
  InitHotSpot(TownHotSpots[1][0], 68, 250, 0, 'VAULTENT.MAP');
  InitHotSpot(TownHotSpots[1][1], 107, 209, 1, 'VAULTBUR.MAP');
  InitHotSpot(TownHotSpots[1][2], 298, 187, 2, 'VAULTBUR.MAP');
  InitHotSpot(TownHotSpots[1][3], 135, 290, 3, 'VAULTBUR.MAP');
  { SHADY SANDS }
  InitHotSpot(TownHotSpots[2][0], 158, 192, 1, 'SHADYW.MAP');
  InitHotSpot(TownHotSpots[2][1], 270, 253, 2, 'SHADYE.MAP');
  InitHotSpot(TownHotSpots[2][2], 314, 217, 3, 'SHADYE.MAP');
  { JUNKTOWN }
  InitHotSpot(TownHotSpots[3][0], 400, 317, 3, 'JUNKENT.MAP');
  InitHotSpot(TownHotSpots[3][1], 304, 257, 2, 'JUNKKILL.MAP');
  InitHotSpot(TownHotSpots[3][2], 200, 279, 1, 'JUNKCSNO.MAP');
  { RAIDERS }
  InitHotSpot(TownHotSpots[4][0], 241, 398, 1, 'RAIDERS.MAP');
  { NECROPOLIS }
  InitHotSpot(TownHotSpots[5][0], 398, 265, 3, 'HOTEL.MAP');
  InitHotSpot(TownHotSpots[5][1], 239, 224, 2, 'HALLDED.MAP');
  InitHotSpot(TownHotSpots[5][2], 79, 207, 1, 'WATRSHD.MAP');
  { THE HUB }
  InitHotSpot(TownHotSpots[6][0], 238, 78, 1, 'HUBENT.MAP');
  InitHotSpot(TownHotSpots[6][1], 205, 172, 3, 'HUBDWNTN.MAP');
  InitHotSpot(TownHotSpots[6][2], 128, 138, 5, 'HUBHEIGT.MAP');
  InitHotSpot(TownHotSpots[6][3], 306, 137, 2, 'HUBOLDTN.MAP');
  InitHotSpot(TownHotSpots[6][4], 272, 238, 4, 'HUBWATER.MAP');
  InitHotSpot(TownHotSpots[6][5], 125, 216, 0, 'DETHCLAW.MAP');
  { BROTHERHOOD }
  InitHotSpot(TownHotSpots[7][0], 172, 167, 1, 'BROHDENT.MAP');
  InitHotSpot(TownHotSpots[7][1], 254, 194, 2, 'BROHD12.MAP');
  InitHotSpot(TownHotSpots[7][2], 136, 263, 3, 'BROHD12.MAP');
  InitHotSpot(TownHotSpots[7][3], 280, 306, 4, 'BROHD34.MAP');
  InitHotSpot(TownHotSpots[7][4], 161, 373, 5, 'BROHD34.MAP');
  { MILITARY BASE }
  InitHotSpot(TownHotSpots[8][0], 197, 83, 0, 'MBENT.MAP');
  { THE GLOW }
  InitHotSpot(TownHotSpots[9][0], 340, 149, 0, 'GLOWENT.MAP');
  InitHotSpot(TownHotSpots[9][1], 334, 195, 1, 'GLOW1.MAP');
  { BONEYARD }
  InitHotSpot(TownHotSpots[10][0], 276, 239, 3, 'LAADYTUM.MAP');
  InitHotSpot(TownHotSpots[10][1], 229, 195, 4, 'LABLADES.MAP');
  InitHotSpot(TownHotSpots[10][2], 179, 185, 5, 'LAFOLLWR.MAP');
  InitHotSpot(TownHotSpots[10][3], 346, 114, 1, 'LAGUNRUN.MAP');
  InitHotSpot(TownHotSpots[10][4], 285, 159, 2, 'LARIPPER.MAP');
  { CATHEDRAL }
  InitHotSpot(TownHotSpots[11][0], 86, 328, 0, 'CHILDRN1.MAP');
  InitHotSpot(TownHotSpots[11][1], 229, 313, 1, 'CHILDRN1.MAP');
  { SPECIAL 12 (cathedral dead) }
  InitHotSpot(TownHotSpots[12][0], 235, 301, 0, 'CHILDEAD.MAP');
  { SPECIAL 13 (military base dead) }
  InitHotSpot(TownHotSpots[13][0], 106, 64, 0, 'MBDEAD.MAP');
  { SPECIAL 14 (brotherhood dead) }
  InitHotSpot(TownHotSpots[14][0], 172, 167, 0, 'BRODEAD.MAP');
end;

initialization
  InitStringTables;
  InitTownHotSpots;

end.
