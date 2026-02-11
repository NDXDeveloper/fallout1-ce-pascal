unit u_automap;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/automap.h + automap.cc
// Automap display: in-game map window, Pipboy minimap, and automap database I/O.

interface

uses
  u_object_types, u_proto_types, u_map_defs, u_db;

const
  AUTOMAP_DB  = 'AUTOMAP.DB';
  AUTOMAP_TMP = 'AUTOMAP.TMP';

  AUTOMAP_MAP_COUNT = 66;

type
  PAutomapHeader = ^TAutomapHeader;
  TAutomapHeader = record
    version: Byte;
    dataSize: Integer;
    offsets: array[0..AUTOMAP_MAP_COUNT - 1, 0..ELEVATION_COUNT - 1] of Integer;
  end;

  PPAutomapHeader = ^PAutomapHeader;

  PAutomapEntry = ^TAutomapEntry;
  TAutomapEntry = record
    dataSize: Integer;
    isCompressed: Byte;
  end;

function automap_init: Integer;
function automap_reset: Integer;
procedure automap_exit;
function automap_load(stream: PDB_FILE): Integer;
function automap_save(stream: PDB_FILE): Integer;
procedure automap(isInGame, isUsingScanner: Boolean);
function draw_top_down_map_pipboy(window, map, elevation: Integer): Integer;
function automap_pip_save: Integer;
function YesWriteIndex(mapIndex, elevation: Integer): Boolean;
function ReadAMList(automapHeaderPtr: PPAutomapHeader): Integer;

implementation

uses
  SysUtils, Math,
  u_memory, u_debug, u_color, u_grbuf, u_svga, u_gnw, u_gnw_types,
  u_button, u_text, u_input, u_art, u_object, u_map, u_config, u_gconfig,
  u_platform_compat, u_cache, u_graphlib, u_fps_limiter, u_kb,
  u_gmouse, u_gsound, u_inventry, u_item, u_bmpdlog, u_message, u_game;

// ============================================================================
// Constants
// ============================================================================

const
  AUTOMAP_OFFSET_COUNT = AUTOMAP_MAP_COUNT * ELEVATION_COUNT;

  AUTOMAP_WINDOW_WIDTH  = 519;
  AUTOMAP_WINDOW_HEIGHT = 480;

  AUTOMAP_PIPBOY_VIEW_X = 238;
  AUTOMAP_PIPBOY_VIEW_Y = 105;

  // AutomapFlags
  AUTOMAP_IN_GAME          = $01;
  AUTOMAP_WTH_HIGH_DETAILS = $02;
  AUTOMAP_WITH_SCANNER     = $04;

  // AutomapFrm
  AUTOMAP_FRM_BACKGROUND  = 0;
  AUTOMAP_FRM_BUTTON_UP   = 1;
  AUTOMAP_FRM_BUTTON_DOWN = 2;
  AUTOMAP_FRM_SWITCH_UP   = 3;
  AUTOMAP_FRM_SWITCH_DOWN = 4;
  AUTOMAP_FRM_COUNT       = 5;


// ============================================================================
// Forward declarations
// ============================================================================

procedure draw_top_down_map_internal(window, elevation: Integer; backgroundData: PByte; flags: Integer); forward;
function WriteAM_Entry(stream: PDB_FILE): Integer; forward;
function AM_ReadEntry(map, elevation: Integer): Integer; forward;
function WriteAM_Header(stream: PDB_FILE): Integer; forward;
function AM_ReadMainHeader(stream: PDB_FILE): Integer; forward;
procedure decode_map_data(elevation: Integer); forward;
function am_pip_init: Integer; forward;
function copy_file_data(stream1, stream2: PDB_FILE; length: Integer): Integer; forward;

// ============================================================================
// Static data
// ============================================================================

const
  defam: array[0..AUTOMAP_MAP_COUNT - 1, 0..ELEVATION_COUNT - 1] of Integer = (
    {  DESERT1 } ( -1, -1, -1 ),
    {  DESERT2 } ( -1, -1, -1 ),
    {  DESERT3 } ( -1, -1, -1 ),
    {  HALLDED } (  0,  0,  0 ),
    {    HOTEL } (  0,  0,  0 ),
    {  WATRSHD } (  0,  0,  0 ),
    {  VAULT13 } (  0,  0,  0 ),
    { VAULTENT } (  0,  0,  0 ),
    { VAULTBUR } (  0,  0,  0 ),
    { VAULTNEC } (  0,  0,  0 ),
    {  JUNKENT } (  0,  0,  0 ),
    { JUNKCSNO } (  0,  0,  0 ),
    { JUNKKILL } (  0,  0,  0 ),
    { BROHDENT } (  0,  0,  0 ),
    {  BROHD12 } (  0,  0,  0 ),
    {  BROHD34 } (  0,  0,  0 ),
    {    CAVES } (  0,  0,  0 ),
    { CHILDRN1 } (  0,  0,  0 ),
    { CHILDRN2 } (  0,  0,  0 ),
    {    CITY1 } ( -1, -1, -1 ),
    {   COAST1 } ( -1, -1, -1 ),
    {   COAST2 } ( -1, -1, -1 ),
    { COLATRUK } ( -1, -1, -1 ),
    {  FSAUSER } ( -1, -1, -1 ),
    {  RAIDERS } (  0,  0,  0 ),
    {   SHADYE } (  0,  0,  0 ),
    {   SHADYW } (  0,  0,  0 ),
    {  GLOWENT } (  0,  0,  0 ),
    { LAADYTUM } (  0,  0,  0 ),
    { LAFOLLWR } (  0,  0,  0 ),
    {    MBENT } (  0,  0,  0 ),
    { MBSTRG12 } (  0,  0,  0 ),
    { MBVATS12 } (  0,  0,  0 ),
    { MSTRLR12 } (  0,  0,  0 ),
    { MSTRLR34 } (  0,  0,  0 ),
    {   V13ENT } (  0,  0,  0 ),
    {   HUBENT } (  0,  0,  0 ),
    { DETHCLAW } (  0,  0,  0 ),
    { HUBDWNTN } (  0,  0,  0 ),
    { HUBHEIGT } (  0,  0,  0 ),
    { HUBOLDTN } (  0,  0,  0 ),
    { HUBWATER } (  0,  0,  0 ),
    {    GLOW1 } (  0,  0,  0 ),
    {    GLOW2 } (  0,  0,  0 ),
    { LABLADES } (  0,  0,  0 ),
    { LARIPPER } (  0,  0,  0 ),
    { LAGUNRUN } (  0,  0,  0 ),
    { CHILDEAD } (  0,  0,  0 ),
    {   MBDEAD } (  0,  0,  0 ),
    {  MOUNTN1 } ( -1, -1, -1 ),
    {  MOUNTN2 } ( -1, -1, -1 ),
    {     FOOT } ( -1, -1, -1 ),
    {   TARDIS } ( -1, -1, -1 ),
    {  TALKCOW } ( -1, -1, -1 ),
    {  USEDCAR } ( -1, -1, -1 ),
    {  BRODEAD } (  0,  0,  0 ),
    { DESCRVN1 } ( -1, -1, -1 ),
    { DESCRVN2 } ( -1, -1, -1 ),
    { MNTCRVN1 } ( -1, -1, -1 ),
    { MNTCRVN2 } ( -1, -1, -1 ),
    {   VIPERS } ( -1, -1, -1 ),
    { DESCRVN3 } ( -1, -1, -1 ),
    { MNTCRVN3 } ( -1, -1, -1 ),
    { DESCRVN4 } ( -1, -1, -1 ),
    { MNTCRVN4 } ( -1, -1, -1 ),
    {  HUBMIS1 } ( -1, -1, -1 )
  );

// Static local from automap() function
var
  frmIds: array[0..AUTOMAP_FRM_COUNT - 1] of Integer = (
    171, // automap.frm - automap window
    8,   // lilredup.frm - little red button up
    9,   // lilreddn.frm - little red button down
    172, // autoup.frm - switch up
    173  // autodwn.frm - switch down
  );

// ============================================================================
// Module-level implementation variables (C++ static globals)
// ============================================================================

var
  autoflags: Integer = 0;
  amdbhead: TAutomapHeader;
  amdbsubhead: TAutomapEntry;
  cmpbuf: PByte;
  ambuf: PByte;

// ============================================================================
// Implementation
// ============================================================================

function automap_init: Integer;
begin
  autoflags := 0;
  am_pip_init;
  Result := 0;
end;

function automap_reset: Integer;
begin
  autoflags := 0;
  am_pip_init;
  Result := 0;
end;

procedure automap_exit;
var
  masterPatchesPath: PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @masterPatchesPath) then
  begin
    StrLFmt(path, SizeOf(path) - 1, '%s\%s\%s', [masterPatchesPath, 'MAPS', AUTOMAP_DB]);
    compat_remove(path);
  end;
end;

function automap_load(stream: PDB_FILE): Integer;
begin
  Result := db_freadInt(stream, @autoflags);
end;

function automap_save(stream: PDB_FILE): Integer;
begin
  Result := db_fwriteInt(stream, autoflags);
end;

procedure automap(isInGame, isUsingScanner: Boolean);
var
  frmData: array[0..AUTOMAP_FRM_COUNT - 1] of PByte;
  frmHandle: array[0..AUTOMAP_FRM_COUNT - 1] of PCacheEntry;
  index: Integer;
  fid: Integer;
  color: Integer;
  oldFont: Integer;
  automapWindowX, automapWindowY: Integer;
  window: Integer;
  scannerBtn, cancelBtn, switchBtn: Integer;
  elevation: Integer;
  isoWasEnabled: Boolean;
  done: Boolean;
  needsRefresh: Boolean;
  keyCode: Integer;
  scanner, item1, item2: PObject;
  messageListItem: TMessageListItem;
  title: PAnsiChar;
  j: Integer;
begin
  for index := 0 to AUTOMAP_FRM_COUNT - 1 do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, frmIds[index], 0, 0, 0);
    frmData[index] := art_ptr_lock_data(fid, 0, 0, @frmHandle[index]);
    if frmData[index] = nil then
    begin
      { unlock previously loaded frames }
      for j := index - 1 downto 0 do
        art_ptr_unlock(frmHandle[j]);
      Exit;
    end;
  end;

  if isInGame then
  begin
    color := colorTable[8456];
    obj_process_seen;
  end
  else
    color := colorTable[22025];

  oldFont := text_curr;
  text_font(101);

  automapWindowX := (screenGetWidth - AUTOMAP_WINDOW_WIDTH) div 2;
  automapWindowY := (screenGetHeight - AUTOMAP_WINDOW_HEIGHT) div 2;
  window := win_add(automapWindowX, automapWindowY, AUTOMAP_WINDOW_WIDTH, AUTOMAP_WINDOW_HEIGHT,
    color, WINDOW_MODAL or WINDOW_MOVE_ON_TOP);

  scannerBtn := win_register_button(window, 111, 454, 15, 16, -1, -1, -1, KEY_LOWERCASE_S,
    frmData[AUTOMAP_FRM_BUTTON_UP], frmData[AUTOMAP_FRM_BUTTON_DOWN], nil, BUTTON_FLAG_TRANSPARENT);
  if scannerBtn <> -1 then
    win_register_button_sound_func(scannerBtn, TButtonCallback(@gsound_red_butt_press), TButtonCallback(@gsound_red_butt_release));

  cancelBtn := win_register_button(window, 277, 454, 15, 16, -1, -1, -1, KEY_ESCAPE,
    frmData[AUTOMAP_FRM_BUTTON_UP], frmData[AUTOMAP_FRM_BUTTON_DOWN], nil, BUTTON_FLAG_TRANSPARENT);
  if cancelBtn <> -1 then
    win_register_button_sound_func(cancelBtn, TButtonCallback(@gsound_red_butt_press), TButtonCallback(@gsound_red_butt_release));

  switchBtn := win_register_button(window, 457, 340, 42, 74, -1, -1, KEY_LOWERCASE_L, KEY_LOWERCASE_H,
    frmData[AUTOMAP_FRM_SWITCH_UP], frmData[AUTOMAP_FRM_SWITCH_DOWN], nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x01);
  if switchBtn <> -1 then
    win_register_button_sound_func(switchBtn, TButtonCallback(@gsound_toggle_butt_press), TButtonCallback(@gsound_toggle_butt_release));

  if (autoflags and AUTOMAP_WTH_HIGH_DETAILS) = 0 then
    win_set_button_rest_state(switchBtn, True, 0);

  elevation := map_elevation;

  autoflags := autoflags and AUTOMAP_WTH_HIGH_DETAILS;

  if isInGame then
    autoflags := autoflags or AUTOMAP_IN_GAME;

  if isUsingScanner then
    autoflags := autoflags or AUTOMAP_WITH_SCANNER;

  draw_top_down_map_internal(window, elevation, frmData[AUTOMAP_FRM_BACKGROUND], autoflags);

  isoWasEnabled := map_disable_bk_processes;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  done := False;
  while not done do
  begin
    sharedFpsLimiter.Mark;

    needsRefresh := False;

    keyCode := get_input;
    case keyCode of
      KEY_TAB,
      KEY_ESCAPE,
      KEY_UPPERCASE_A,
      KEY_LOWERCASE_A:
        done := True;

      KEY_UPPERCASE_H,
      KEY_LOWERCASE_H:
        if (autoflags and AUTOMAP_WTH_HIGH_DETAILS) = 0 then
        begin
          autoflags := autoflags or AUTOMAP_WTH_HIGH_DETAILS;
          needsRefresh := True;
        end;

      KEY_UPPERCASE_L,
      KEY_LOWERCASE_L:
        if (autoflags and AUTOMAP_WTH_HIGH_DETAILS) <> 0 then
        begin
          autoflags := autoflags and (not AUTOMAP_WTH_HIGH_DETAILS);
          needsRefresh := True;
        end;

      KEY_UPPERCASE_S,
      KEY_LOWERCASE_S:
        begin
          if elevation <> map_elevation then
          begin
            elevation := map_elevation;
            needsRefresh := True;
          end;

          if (autoflags and AUTOMAP_WITH_SCANNER) = 0 then
          begin
            scanner := nil;

            item1 := inven_left_hand(obj_dude);
            if (item1 <> nil) and (item1^.Pid = PROTO_ID_MOTION_SENSOR) then
              scanner := item1
            else
            begin
              item2 := inven_right_hand(obj_dude);
              if (item2 <> nil) and (item2^.Pid = PROTO_ID_MOTION_SENSOR) then
                scanner := item2;
            end;

            if (scanner <> nil) and (item_m_curr_charges(scanner) > 0) then
            begin
              needsRefresh := True;
              autoflags := autoflags or AUTOMAP_WITH_SCANNER;
              item_m_dec_charges(scanner);
            end
            else
            begin
              gsound_play_sfx_file('iisxxxx1');

              if scanner <> nil then
                title := getmsg(@misc_message_file, @messageListItem, 18)
              else
                title := getmsg(@misc_message_file, @messageListItem, 17);
              dialog_out(title, nil, 0, 165, 140, colorTable[32328], nil, colorTable[32328], 0);
            end;
          end;
        end;

      KEY_CTRL_Q,
      KEY_ALT_X,
      KEY_F10:
        game_quit_with_confirm;

      KEY_F12:
        dump_screen;
    end;

    if game_user_wants_to_quit <> 0 then
      Break;

    if needsRefresh then
    begin
      draw_top_down_map_internal(window, elevation, frmData[AUTOMAP_FRM_BACKGROUND], autoflags);
      needsRefresh := False;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if isoWasEnabled then
    map_enable_bk_processes;

  win_delete(window);
  text_font(oldFont);

  for index := 0 to AUTOMAP_FRM_COUNT - 1 do
    art_ptr_unlock(frmHandle[index]);
end;

procedure draw_top_down_map_internal(window, elevation: Integer; backgroundData: PByte; flags: Integer);
var
  color: Integer;
  windowBuffer: PByte;
  obj: PObject;
  objectType: Integer;
  objectColor: Byte;
  v10: Integer;
  v12: PByte;
  textColor: Integer;
  areaName: PAnsiChar;
  mapName: PAnsiChar;
begin
  if (flags and AUTOMAP_IN_GAME) <> 0 then
    color := colorTable[8456]
  else
    color := colorTable[22025];

  win_fill(window, 0, 0, AUTOMAP_WINDOW_WIDTH, AUTOMAP_WINDOW_HEIGHT, color);
  win_border(window);

  windowBuffer := win_get_buf(window);
  buf_to_buf(backgroundData, AUTOMAP_WINDOW_WIDTH, AUTOMAP_WINDOW_HEIGHT, AUTOMAP_WINDOW_WIDTH,
    windowBuffer, AUTOMAP_WINDOW_WIDTH);

  obj := obj_find_first_at(elevation);
  while obj <> nil do
  begin
    if obj^.Tile <> -1 then
    begin
      objectType := FID_TYPE(obj^.Fid);
      objectColor := colorTable[0];

      if (flags and AUTOMAP_IN_GAME) <> 0 then
      begin
        if (objectType = OBJ_TYPE_CRITTER) and
           ((obj^.Flags and OBJECT_HIDDEN) = 0) and
           ((flags and AUTOMAP_WITH_SCANNER) <> 0) and
           ((obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
        begin
          objectColor := colorTable[31744];
        end
        else
        begin
          if (obj^.Flags and Integer(OBJECT_SEEN)) = 0 then
          begin
            obj := obj_find_next_at;
            Continue;
          end;

          if obj^.Pid = PROTO_ID_0x2000031 then
            objectColor := colorTable[32328]
          else if objectType = OBJ_TYPE_WALL then
            objectColor := colorTable[992]
          else if (objectType = OBJ_TYPE_SCENERY) and
                  ((flags and AUTOMAP_WTH_HIGH_DETAILS) <> 0) and
                  (obj^.Pid <> PROTO_ID_0x2000158) then
            objectColor := colorTable[480]
          else if obj = obj_dude then
            objectColor := colorTable[31744]
          else
            objectColor := colorTable[0];
        end;
      end;

      v10 := -2 * (obj^.Tile mod 200) - 10 + AUTOMAP_WINDOW_WIDTH * (2 * (obj^.Tile div 200) + 9) - 60;

      if (flags and AUTOMAP_IN_GAME) = 0 then
      begin
        case objectType of
          OBJ_TYPE_ITEM:    objectColor := colorTable[6513];
          OBJ_TYPE_CRITTER: objectColor := colorTable[28672];
          OBJ_TYPE_SCENERY: objectColor := colorTable[448];
          OBJ_TYPE_WALL:    objectColor := colorTable[12546];
          OBJ_TYPE_MISC:    objectColor := colorTable[31650];
        else
          objectColor := colorTable[0];
        end;
      end;

      if objectColor <> colorTable[0] then
      begin
        v12 := windowBuffer + v10;
        if (flags and AUTOMAP_IN_GAME) <> 0 then
        begin
          if (v12[0] <> colorTable[992]) or (objectColor <> colorTable[480]) then
          begin
            v12[0] := objectColor;
            v12[1] := objectColor;
          end;

          if obj = obj_dude then
          begin
            (v12 - 1)^ := objectColor;
            (v12 - AUTOMAP_WINDOW_WIDTH)^ := objectColor;
            (v12 + AUTOMAP_WINDOW_WIDTH)^ := objectColor;
          end;
        end
        else
        begin
          v12[0] := objectColor;
          v12[1] := objectColor;
          (v12 + AUTOMAP_WINDOW_WIDTH)^ := objectColor;
          (v12 + AUTOMAP_WINDOW_WIDTH + 1)^ := objectColor;

          (v12 + AUTOMAP_WINDOW_WIDTH - 1)^ := objectColor;
          (v12 + AUTOMAP_WINDOW_WIDTH + 2)^ := objectColor;
          (v12 + AUTOMAP_WINDOW_WIDTH * 2)^ := objectColor;
          (v12 + AUTOMAP_WINDOW_WIDTH * 2 + 1)^ := objectColor;
        end;
      end;
    end;
    obj := obj_find_next_at;
  end;

  if (flags and AUTOMAP_IN_GAME) <> 0 then
    textColor := colorTable[992]
  else
    textColor := colorTable[12546];

  if map_get_index_number <> -1 then
  begin
    areaName := map_get_short_name(map_get_index_number);
    win_print(window, areaName, 240, 150, 380, textColor or $2000000);

    mapName := map_get_elev_idx(map_get_index_number, elevation);
    win_print(window, mapName, 240, 150, 396, textColor or $2000000);
  end;

  win_draw(window);
end;

function draw_top_down_map_pipboy(window, map, elevation: Integer): Integer;
var
  windowBuffer: PByte;
  wallColor, sceneryColor: Byte;
  v1: Integer;
  v2: Byte;
  ptr: PByte;
  x, y: Integer;
  bits: Integer;
begin
  windowBuffer := win_get_buf(window) + 640 * AUTOMAP_PIPBOY_VIEW_Y + AUTOMAP_PIPBOY_VIEW_X;

  wallColor := colorTable[992];
  sceneryColor := colorTable[480];

  ambuf := PByte(mem_malloc(11024));
  if ambuf = nil then
  begin
    debug_printf(#10'AUTOMAP: Error allocating data buffer!'#10);
    Result := -1;
    Exit;
  end;

  if AM_ReadEntry(map, elevation) = -1 then
  begin
    mem_free(ambuf);
    Result := -1;
    Exit;
  end;

  v1 := 0;
  v2 := 0;
  ptr := ambuf;

  for y := 0 to HEX_GRID_HEIGHT - 1 do
  begin
    for x := 0 to HEX_GRID_WIDTH - 1 do
    begin
      Dec(v1);
      if v1 <= 0 then
      begin
        v1 := 4;
        v2 := ptr^;
        Inc(ptr);
      end;

      bits := (v2 and $C0) shr 6;
      case bits of
        1:
          begin
            windowBuffer^ := wallColor;
            Inc(windowBuffer);
            windowBuffer^ := wallColor;
            Inc(windowBuffer);
          end;
        2:
          begin
            windowBuffer^ := sceneryColor;
            Inc(windowBuffer);
            windowBuffer^ := sceneryColor;
            Inc(windowBuffer);
          end;
      else
        Inc(windowBuffer, 2);
      end;

      v2 := v2 shl 2;
    end;

    Inc(windowBuffer, 640 + 240);
  end;

  mem_free(ambuf);

  Result := 0;
end;

function automap_pip_save: Integer;
var
  map_idx, elev: Integer;
  entryOffset: Integer;
  dataBuffersAllocated: Boolean;
  path: array[0..255] of AnsiChar;
  stream1, stream2: PDB_FILE;
  compressedDataSize: Integer;
  nextEntryDataSize: Integer;
  automapDataSize: LongInt;
  nextEntryOffset: Integer;
  diff: Integer;
  mi, ei: Integer;
  proceed: Boolean;
  masterPatchesPath: PAnsiChar;
  automapDbPath: array[0..511] of AnsiChar;
  automapTmpPath: array[0..511] of AnsiChar;
begin
  map_idx := map_get_index_number;
  elev := map_elevation;

  entryOffset := amdbhead.offsets[map_idx][elev];
  if entryOffset < 0 then
  begin
    Result := 0;
    Exit;
  end;

  debug_printf(#10'AUTOMAP: Saving AutoMap DB index %d, level %d'#10, [map_idx, elev]);

  dataBuffersAllocated := False;
  ambuf := PByte(mem_malloc(11024));
  if ambuf <> nil then
  begin
    cmpbuf := PByte(mem_malloc(11024));
    if cmpbuf <> nil then
      dataBuffersAllocated := True;
  end;

  if not dataBuffersAllocated then
  begin
    // FIXME: Leaking ambuf.
    debug_printf(#10'AUTOMAP: Error allocating data buffers!'#10);
    Result := -1;
    Exit;
  end;

  StrLFmt(path, SizeOf(path) - 1, '%s\%s', ['MAPS', AUTOMAP_DB]);

  stream1 := db_fopen(path, 'r+b');
  if stream1 = nil then
  begin
    debug_printf(#10'AUTOMAP: Error opening automap database file!'#10);
    debug_printf('Error continued: automap_pip_save: path: %s', [path]);
    mem_free(ambuf);
    mem_free(cmpbuf);
    Result := -1;
    Exit;
  end;

  if AM_ReadMainHeader(stream1) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error reading automap database file header!'#10);
    mem_free(ambuf);
    mem_free(cmpbuf);
    db_fclose(stream1);
    Result := -1;
    Exit;
  end;

  decode_map_data(elev);

  compressedDataSize := CompLZS(ambuf, cmpbuf, 10000);
  if compressedDataSize = -1 then
  begin
    amdbsubhead.dataSize := 10000;
    amdbsubhead.isCompressed := 0;
  end
  else
  begin
    amdbsubhead.dataSize := compressedDataSize;
    amdbsubhead.isCompressed := 1;
  end;

  if entryOffset <> 0 then
  begin
    StrLFmt(path, SizeOf(path) - 1, '%s\%s', ['MAPS', AUTOMAP_TMP]);

    stream2 := db_fopen(path, 'wb');
    if stream2 = nil then
    begin
      debug_printf(#10'AUTOMAP: Error creating temp file!'#10);
      mem_free(ambuf);
      mem_free(cmpbuf);
      db_fclose(stream1);
      Result := -1;
      Exit;
    end;

    db_rewind(stream1);

    if copy_file_data(stream1, stream2, entryOffset) = -1 then
    begin
      debug_printf(#10'AUTOMAP: Error copying file data!'#10);
      db_fclose(stream1);
      db_fclose(stream2);
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    if WriteAM_Entry(stream2) = -1 then
    begin
      db_fclose(stream1);
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    if db_freadInt32(stream1, @nextEntryDataSize) = -1 then
    begin
      debug_printf(#10'AUTOMAP: Error reading database #1!'#10);
      db_fclose(stream1);
      db_fclose(stream2);
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    automapDataSize := db_filelength(stream1);
    if automapDataSize = -1 then
    begin
      debug_printf(#10'AUTOMAP: Error reading database #2!'#10);
      db_fclose(stream1);
      db_fclose(stream2);
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    nextEntryOffset := entryOffset + nextEntryDataSize + 5;
    if automapDataSize <> nextEntryOffset then
    begin
      if db_fseek(stream1, nextEntryOffset, 0{SEEK_SET}) = -1 then
      begin
        debug_printf(#10'AUTOMAP: Error writing temp data!'#10);
        db_fclose(stream1);
        db_fclose(stream2);
        mem_free(ambuf);
        mem_free(cmpbuf);
        Result := -1;
        Exit;
      end;

      if copy_file_data(stream1, stream2, automapDataSize - nextEntryOffset) = -1 then
      begin
        debug_printf(#10'AUTOMAP: Error copying file data!'#10);
        db_fclose(stream1);
        db_fclose(stream2);
        mem_free(ambuf);
        mem_free(cmpbuf);
        Result := -1;
        Exit;
      end;
    end;

    diff := amdbsubhead.dataSize - nextEntryDataSize;
    for mi := 0 to AUTOMAP_MAP_COUNT - 1 do
      for ei := 0 to ELEVATION_COUNT - 1 do
        if amdbhead.offsets[mi][ei] > entryOffset then
          amdbhead.offsets[mi][ei] := amdbhead.offsets[mi][ei] + diff;

    amdbhead.dataSize := amdbhead.dataSize + diff;

    if WriteAM_Header(stream2) = -1 then
    begin
      db_fclose(stream1);
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    db_fseek(stream2, 0, 2{SEEK_END});
    db_fclose(stream2);
    db_fclose(stream1);
    mem_free(ambuf);
    mem_free(cmpbuf);

    if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @masterPatchesPath) then
    begin
      debug_printf(#10'AUTOMAP: Error reading config info!'#10);
      Result := -1;
      Exit;
    end;

    StrLFmt(automapDbPath, SizeOf(automapDbPath) - 1, '%s\%s\%s', [masterPatchesPath, 'MAPS', AUTOMAP_DB]);
    if compat_remove(automapDbPath) <> 0 then
    begin
      debug_printf(#10'AUTOMAP: Error removing database!'#10);
      Result := -1;
      Exit;
    end;

    StrLFmt(automapTmpPath, SizeOf(automapTmpPath) - 1, '%s\%s\%s', [masterPatchesPath, 'MAPS', AUTOMAP_TMP]);
    if compat_rename(automapTmpPath, automapDbPath) <> 0 then
    begin
      debug_printf(#10'AUTOMAP: Error renaming database!'#10);
      Result := -1;
      Exit;
    end;
  end
  else
  begin
    proceed := True;
    if db_fseek(stream1, 0, 2{SEEK_END}) <> -1 then
    begin
      if db_ftell(stream1) <> amdbhead.dataSize then
        proceed := False;
    end
    else
      proceed := False;

    if not proceed then
    begin
      debug_printf(#10'AUTOMAP: Error reading automap database file header!'#10);
      mem_free(ambuf);
      mem_free(cmpbuf);
      db_fclose(stream1);
      Result := -1;
      Exit;
    end;

    if WriteAM_Entry(stream1) = -1 then
    begin
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    amdbhead.offsets[map_idx][elev] := amdbhead.dataSize;
    amdbhead.dataSize := amdbhead.dataSize + amdbsubhead.dataSize + 5;

    if WriteAM_Header(stream1) = -1 then
    begin
      mem_free(ambuf);
      mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    db_fseek(stream1, 0, 2{SEEK_END});
    db_fclose(stream1);
    mem_free(ambuf);
    mem_free(cmpbuf);
  end;

  Result := 1;
end;

function WriteAM_Entry(stream: PDB_FILE): Integer;
var
  buffer: PByte;
begin
  if amdbsubhead.isCompressed = 1 then
    buffer := cmpbuf
  else
    buffer := ambuf;

  if db_fwriteLong(stream, LongWord(amdbsubhead.dataSize)) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database entry data!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_fwriteByte(stream, amdbsubhead.isCompressed) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database entry data!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_fwriteByteCount(stream, buffer, amdbsubhead.dataSize) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database entry data!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function AM_ReadEntry(map, elevation: Integer): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  success: Boolean;
  stream: PDB_FILE;
begin
  cmpbuf := nil;

  StrLFmt(path, SizeOf(path) - 1, '%s\%s', ['MAPS', AUTOMAP_DB]);

  success := True;

  stream := db_fopen(path, 'r+b');
  if stream = nil then
  begin
    debug_printf(#10'AUTOMAP: Error opening automap database file!'#10);
    debug_printf('Error continued: AM_ReadEntry: path: %s', [path]);
    Result := -1;
    Exit;
  end;

  if AM_ReadMainHeader(stream) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error reading automap database header!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if amdbhead.offsets[map][elevation] <= 0 then
  begin
    success := False;
    // goto out
    db_fclose(stream);
    if not success then
    begin
      debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
      Result := -1;
      Exit;
    end;
    if cmpbuf <> nil then
      mem_free(cmpbuf);
    Result := 0;
    Exit;
  end;

  if db_fseek(stream, amdbhead.offsets[map][elevation], 0{SEEK_SET}) = -1 then
  begin
    success := False;
    db_fclose(stream);
    debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
    Result := -1;
    Exit;
  end;

  if db_freadInt32(stream, @amdbsubhead.dataSize) = -1 then
  begin
    success := False;
    db_fclose(stream);
    debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
    Result := -1;
    Exit;
  end;

  if db_freadByte(stream, @amdbsubhead.isCompressed) = -1 then
  begin
    success := False;
    db_fclose(stream);
    debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
    Result := -1;
    Exit;
  end;

  if amdbsubhead.isCompressed = 1 then
  begin
    cmpbuf := PByte(mem_malloc(11024));
    if cmpbuf = nil then
    begin
      debug_printf(#10'AUTOMAP: Error allocating decompression buffer!'#10);
      db_fclose(stream);
      Result := -1;
      Exit;
    end;

    if db_freadByteCount(stream, cmpbuf, amdbsubhead.dataSize) = -1 then
    begin
      success := False;
      db_fclose(stream);
      debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
      if cmpbuf <> nil then
        mem_free(cmpbuf);
      Result := -1;
      Exit;
    end;

    if DecodeLZS(cmpbuf, ambuf, 10000) = -1 then
    begin
      debug_printf(#10'AUTOMAP: Error decompressing DB entry!'#10);
      db_fclose(stream);
      Result := -1;
      Exit;
    end;
  end
  else
  begin
    if db_freadByteCount(stream, ambuf, amdbsubhead.dataSize) = -1 then
    begin
      success := False;
      db_fclose(stream);
      debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
      Result := -1;
      Exit;
    end;
  end;

  db_fclose(stream);

  if not success then
  begin
    debug_printf(#10'AUTOMAP: Error reading automap database entry data!'#10);
    Result := -1;
    Exit;
  end;

  if cmpbuf <> nil then
    mem_free(cmpbuf);

  Result := 0;
end;

function WriteAM_Header(stream: PDB_FILE): Integer;
begin
  db_rewind(stream);

  if db_fwriteByte(stream, amdbhead.version) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database header!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_fwriteInt32(stream, amdbhead.dataSize) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database header!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_fwriteInt32List(stream, PInteger(@amdbhead.offsets[0][0]), AUTOMAP_OFFSET_COUNT) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error writing automap database header!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function AM_ReadMainHeader(stream: PDB_FILE): Integer;
begin
  if db_freadByte(stream, @amdbhead.version) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt32(stream, @amdbhead.dataSize) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt32List(stream, PInteger(@amdbhead.offsets[0][0]), AUTOMAP_OFFSET_COUNT) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if amdbhead.version <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

procedure decode_map_data(elevation: Integer);
var
  obj: PObject;
  contentType: Integer;
  objectType: Integer;
  v1, v2, v3: Integer;
begin
  FillChar(ambuf^, SQUARE_GRID_SIZE, 0);

  obj_process_seen;

  obj := obj_find_first_at(elevation);
  while obj <> nil do
  begin
    if (obj^.Tile <> -1) and ((obj^.Flags and Integer(OBJECT_SEEN)) <> 0) then
    begin
      objectType := FID_TYPE(obj^.Fid);
      if (objectType = OBJ_TYPE_SCENERY) and (obj^.Pid <> PROTO_ID_0x2000158) then
        contentType := 2
      else if objectType = OBJ_TYPE_WALL then
        contentType := 1
      else
        contentType := 0;

      if contentType <> 0 then
      begin
        v1 := 200 - obj^.Tile mod 200;
        v2 := v1 div 4 + 50 * (obj^.Tile div 200);
        v3 := 2 * (3 - v1 mod 4);
        ambuf[v2] := ambuf[v2] and (not Byte($03 shl v3));
        ambuf[v2] := ambuf[v2] or Byte(contentType shl v3);
      end;
    end;
    obj := obj_find_next_at;
  end;
end;

function am_pip_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
begin
  amdbhead.version := 1;
  amdbhead.dataSize := 797;
  Move(defam, amdbhead.offsets, SizeOf(defam));

  StrLFmt(path, SizeOf(path) - 1, '%s\%s', ['MAPS', AUTOMAP_DB]);

  stream := db_fopen(path, 'wb');
  if stream = nil then
  begin
    debug_printf(#10'AUTOMAP: Error creating automap database file!'#10);
    Result := -1;
    Exit;
  end;

  if WriteAM_Header(stream) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  db_fclose(stream);

  Result := 0;
end;

function YesWriteIndex(mapIndex, elevation: Integer): Boolean;
begin
  if (mapIndex < AUTOMAP_MAP_COUNT) and (elevation < ELEVATION_COUNT) and
     (mapIndex >= 0) and (elevation >= 0) then
  begin
    Result := defam[mapIndex][elevation] >= 0;
    Exit;
  end;

  Result := False;
end;

function copy_file_data(stream1, stream2: PDB_FILE; length: Integer): Integer;
var
  buffer: Pointer;
  chunkLength: Integer;
begin
  buffer := mem_malloc($FFFF);
  if buffer = nil then
  begin
    Result := -1;
    Exit;
  end;

  while length <> 0 do
  begin
    chunkLength := Min(length, $FFFF);

    if db_fread(buffer, chunkLength, 1, stream1) <> 1 then
      Break;

    if db_fwrite(buffer, chunkLength, 1, stream2) <> 1 then
      Break;

    Dec(length, chunkLength);
  end;

  mem_free(buffer);

  if length <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function ReadAMList(automapHeaderPtr: PPAutomapHeader): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
begin
  StrLFmt(path, SizeOf(path) - 1, '%s\%s', ['MAPS', AUTOMAP_DB]);

  stream := db_fopen(path, 'rb');
  if stream = nil then
  begin
    debug_printf(#10'AUTOMAP: Error opening database file for reading!'#10);
    debug_printf('Error continued: ReadAMList: path: %s', [path]);
    Result := -1;
    Exit;
  end;

  if AM_ReadMainHeader(stream) = -1 then
  begin
    debug_printf(#10'AUTOMAP: Error reading automap database header pt2!'#10);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fclose(stream);

  automapHeaderPtr^ := @amdbhead;

  Result := 0;
end;

end.
