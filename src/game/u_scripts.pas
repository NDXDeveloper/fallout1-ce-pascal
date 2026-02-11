unit u_scripts;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/scripts.h + scripts.cc
// Script engine: game time, script execution, map scripts, dialog messages.

interface

uses
  u_object_types, u_proto_types, u_map_defs, u_db, u_combat_defs, u_message,
  u_intrpret;

const
  SCRIPT_FLAG_0x01 = $01;
  SCRIPT_FLAG_0x02 = $02;
  SCRIPT_FLAG_0x04 = $04;
  SCRIPT_FLAG_0x08 = $08;
  SCRIPT_FLAG_0x10 = $10;

  GAME_TIME_TICKS_PER_HOUR = 60 * 60 * 10;
  GAME_TIME_TICKS_PER_DAY  = 24 * 60 * 60 * 10;
  GAME_TIME_TICKS_PER_YEAR = 365 * 24 * 60 * 60 * 10;

  SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY = 1000;

  // ScriptRequests
  SCRIPT_REQUEST_COMBAT                   = $01;
  SCRIPT_REQUEST_TOWN_MAP                 = $02;
  SCRIPT_REQUEST_WORLD_MAP                = $04;
  SCRIPT_REQUEST_ELEVATOR                 = $08;
  SCRIPT_REQUEST_EXPLOSION                = $10;
  SCRIPT_REQUEST_DIALOG                   = $20;
  SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE  = $40;
  SCRIPT_REQUEST_ENDGAME                  = $80;
  SCRIPT_REQUEST_LOOTING                  = $100;
  SCRIPT_REQUEST_STEALING                 = $200;
  SCRIPT_REQUEST_LOCKED                   = $400;

  // ScriptType
  SCRIPT_TYPE_SYSTEM  = 0;
  SCRIPT_TYPE_SPATIAL = 1;
  SCRIPT_TYPE_TIMED   = 2;
  SCRIPT_TYPE_ITEM    = 3;
  SCRIPT_TYPE_CRITTER = 4;
  SCRIPT_TYPE_COUNT   = 5;

  // ScriptProc
  SCRIPT_PROC_NO_PROC       = 0;
  SCRIPT_PROC_START         = 1;
  SCRIPT_PROC_SPATIAL       = 2;
  SCRIPT_PROC_DESCRIPTION   = 3;
  SCRIPT_PROC_PICKUP        = 4;
  SCRIPT_PROC_DROP          = 5;
  SCRIPT_PROC_USE           = 6;
  SCRIPT_PROC_USE_OBJ_ON    = 7;
  SCRIPT_PROC_USE_SKILL_ON  = 8;
  SCRIPT_PROC_9             = 9;
  SCRIPT_PROC_10            = 10;
  SCRIPT_PROC_TALK          = 11;
  SCRIPT_PROC_CRITTER       = 12;
  SCRIPT_PROC_COMBAT        = 13;
  SCRIPT_PROC_DAMAGE        = 14;
  SCRIPT_PROC_MAP_ENTER     = 15;
  SCRIPT_PROC_MAP_EXIT      = 16;
  SCRIPT_PROC_CREATE        = 17;
  SCRIPT_PROC_DESTROY       = 18;
  SCRIPT_PROC_19            = 19;
  SCRIPT_PROC_20            = 20;
  SCRIPT_PROC_LOOK_AT       = 21;
  SCRIPT_PROC_TIMED         = 22;
  SCRIPT_PROC_MAP_UPDATE    = 23;
  SCRIPT_PROC_COUNT         = 24;

type
  // Forward declarations
  PScript = ^TScript;
  PScriptListExtent = ^TScriptListExtent;
  PScriptList = ^TScriptList;

  PPMessageList = ^PMessageList;

  TSpatialData = record
    built_tile: Integer;
    radius: Integer;
  end;

  TTimedData = record
    time: Integer;
  end;

  TScriptUnion = record
    case Integer of
      0: (sp: TSpatialData);
      1: (tm: TTimedData);
  end;

  TScript = record
    scr_id: Integer;
    scr_next: Integer;
    u: TScriptUnion;
    scr_flags: Integer;
    scr_script_idx: Integer;
    program_: PProgram;
    scr_oid: Integer;
    scr_local_var_offset: Integer;
    scr_num_local_vars: Integer;
    field_28: Integer;
    action: Integer;
    fixedParam: Integer;
    owner: PObject;
    source: PObject;
    target: PObject;
    actionBeingUsed: Integer;
    scriptOverrides: Integer;
    field_48: Integer;
    howMuch: Integer;
    run_info_flags: Integer;
    procs: array[0..SCRIPT_PROC_COUNT - 1] of Integer;
    field_C4: Integer;
    field_C8: Integer;
    field_CC: Integer;
    field_D0: Integer;
    field_D4: Integer;
    field_D8: Integer;
    field_DC: Integer;
  end;

  PPScript = ^PScript;

  TScriptListExtent = record
    scripts: array[0..15] of TScript;
    length: Integer;
    next: PScriptListExtent;
  end;

  TScriptList = record
    head: PScriptListExtent;
    tail: PScriptListExtent;
    length: Integer;
    nextScriptId: Integer;
  end;

  TScriptState = record
    requests: LongWord;
    combatState1: TSTRUCT_664980;
    combatState2: TSTRUCT_664980;
    elevatorType: Integer;
    explosionTile: Integer;
    explosionElevation: Integer;
    explosionMinDamage: Integer;
    explosionMaxDamage: Integer;
    dialogTarget: PObject;
    lootingBy: PObject;
    lootingFrom: PObject;
    stealingBy: PObject;
    stealingFrom: PObject;
  end;
  PScriptState = ^TScriptState;

  TScriptEvent = record
    sid: Integer;
    fixedParam: Integer;
  end;
  PScriptEvent = ^TScriptEvent;

  TBackgroundProcess = procedure; cdecl;

var
  num_script_indexes: Integer;
  script_dialog_msgs: array[0..SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY - 1] of TMessageList;
  script_message_file: TMessageList;

function game_time: Integer;
procedure game_time_date(monthPtr, dayPtr, yearPtr: PInteger);
function game_time_hour: Integer;
function game_time_hour_str: PAnsiChar;
procedure inc_game_time(inc_: Integer);
procedure inc_game_time_in_seconds(inc_: Integer);
procedure set_game_time(time_: Integer);
procedure set_game_time_in_seconds(time_: Integer);
function gtime_q_add: Integer;
function gtime_q_process(obj: PObject; data: Pointer): Integer; cdecl;
function scr_map_q_process(obj: PObject; data: Pointer): Integer; cdecl;
function new_obj_id: Integer;
function scr_find_sid_from_program(program_: PProgram): Integer;
function scr_find_obj_from_program(program_: PProgram): PObject;
function scr_set_objs(sid: Integer; source, target: PObject): Integer;
procedure scr_set_ext_param(sid, value: Integer);
function scr_set_action_num(sid, value: Integer): Integer;
function loadProgram(name: PAnsiChar): PProgram;
procedure scrSetQueueTestVals(a1: PObject; a2: Integer);
function scrQueueRemoveFixed(obj: PObject; data: Pointer): Integer;
function script_q_add(sid, delay, param: Integer): Integer;
function script_q_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
function script_q_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
function script_q_process(obj: PObject; data: Pointer): Integer; cdecl;
function scripts_clear_state: Integer;
function scripts_clear_combat_requests(script: PScript): Integer;
function scripts_check_state: Integer;
function scripts_check_state_in_combat: Integer;
function scripts_request_combat(a1: PSTRUCT_664980): Integer;
procedure scripts_request_townmap;
procedure scripts_request_worldmap;
function scripts_request_elevator(elevator: Integer): Integer;
function scripts_request_explosion(tile, elevation, minDamage, maxDamage: Integer): Integer;
procedure scripts_request_dialog(obj: PObject);
procedure scripts_request_endgame_slideshow;
function scripts_request_loot_container(a1, a2: PObject): Integer;
function scripts_request_steal_container(a1, a2: PObject): Integer;
procedure script_make_path(path: PAnsiChar);
function exec_script_proc(sid, proc: Integer): Integer;
function scr_find_str_run_info(scr_script_idx: Integer; run_info_flags: PInteger; sid: Integer): Integer;
function scr_list_str(index_: Integer; name: PAnsiChar; size: SizeUInt): Integer;
function scr_set_dude_script: Integer;
function scr_clear_dude_script: Integer;
function scr_init: Integer;
function scr_reset: Integer;
function scr_game_init: Integer;
function scr_game_reset: Integer;
function scr_exit: Integer;
function scr_message_free: Integer;
function scr_game_exit: Integer;
function scr_enable: Integer;
function scr_disable: Integer;
procedure scr_enable_critters;
procedure scr_disable_critters;
function scr_game_save(stream: PDB_FILE): Integer;
function scr_game_load(stream: PDB_FILE): Integer;
function scr_game_load2(stream: PDB_FILE): Integer;
function scr_save(stream: PDB_FILE): Integer;
function scr_load(stream: PDB_FILE): Integer;
function scr_ptr(sid: Integer; scriptPtr: PPScript): Integer;
function scr_new(sidPtr: PInteger; scriptType: Integer): Integer;
function scr_remove_local_vars(script: PScript): Integer;
function scr_remove(sid: Integer): Integer;
function scr_remove_all: Integer;
function scr_remove_all_force: Integer;
function scr_find_first_at(elevation: Integer): PScript;
function scr_find_next_at: PScript;
function scr_spatials_enabled: Boolean;
procedure scr_spatials_enable;
procedure scr_spatials_disable;
function scr_chk_spatials_in(obj: PObject; tile, elevation: Integer): Boolean;
function tile_in_tile_bound(tile1, radius, tile2: Integer): Boolean;
function scr_load_all_scripts: Integer;
procedure scr_exec_map_enter_scripts;
procedure scr_exec_map_update_scripts;
procedure scr_exec_map_exit_scripts;
function scr_get_dialog_msg_file(a1: Integer; messageListPtr: PPMessageList): Integer;
function scr_get_msg_str(messageListId, messageId: Integer): PAnsiChar;
function scr_get_msg_str_speech(messageListId, messageId, a3: Integer): PAnsiChar;
function scr_get_local_var(sid, variable: Integer; var value: TProgramValue): Integer;
function scr_set_local_var(sid, variable: Integer; var value: TProgramValue): Integer;
function scr_end_combat: Boolean;
function scr_explode_scenery(a1: PObject; tile, radius, elevation: Integer): Integer;

implementation

uses
  SysUtils, u_platform_compat, u_debug, u_memory, u_game_vars,
  u_queue, u_object, u_gmouse, u_protinst, u_proto,
  u_art, u_tile, u_map,
  u_combat, u_critter, u_game, u_party,
  u_actions, u_elevator, u_automap,
  u_gdialog, u_gmovie, u_endgame,
  u_inventry, u_worldmap,
  u_input, u_plib_intrface,
  u_export, u_int_window,
  u_anim,
  u_intlib;

const
  GAME_TIME_START_YEAR   = 2161;
  GAME_TIME_START_MONTH  = 12;
  GAME_TIME_START_DAY    = 5;
  GAME_TIME_START_HOUR   = 7;
  GAME_TIME_START_MINUTE = 21;

  SCRIPT_LIST_EXTENT_SIZE = 16;

  VALUE_TYPE_INT = $C001;

  // GameState
  GAME_STATE_4 = 4;

  // Event types (from queue)
  EVENT_TYPE_SCRIPT           = 3;
  EVENT_TYPE_GAME_TIME        = 4;
  EVENT_TYPE_MAP_UPDATE_EVENT = 12;

const
  GAME_MOVIE_FADE_IN    = $01;
  GAME_MOVIE_FADE_OUT   = $02;
  GAME_MOVIE_STOP_MUSIC = $04;

  MOVIE_BOIL1 = 11;
  MOVIE_BOIL2 = 12;
  MOVIE_BOIL3 = 6;

// ============================================================================
// Module-level (static) variables
// ============================================================================

var
  scr_find_first_idx: Integer = 0;
  scr_find_first_ptr: PScriptListExtent = nil;
  scr_find_first_elev: Integer = 0;
  scrSpatialsEnabled_: Boolean = True;
  scriptlists: array[0..SCRIPT_TYPE_COUNT - 1] of TScriptList;
  script_path_base: array[0..8] of AnsiChar;
  script_engine_running: Boolean = False;
  script_engine_run_critters: Integer = 0;
  script_engine_game_mode: Integer = 0;
  fallout_game_time: Integer = (GAME_TIME_START_HOUR * 60 * 60 + GAME_TIME_START_MINUTE * 60) * 10;
  days_in_month: array[0..11] of Integer = (
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  );
  procTableStrs: array[0..SCRIPT_PROC_COUNT - 1] of PAnsiChar;
  water_movie_play_flag: Byte = 0;
  scriptState: TScriptState;

  // Static locals (C++ static in functions)
  hour_str: array[0..6] of AnsiChar;
  gtime_q_process_moviePlaying: Integer = 0;
  new_obj_id_cur_id: Integer = 4;
  doBkProcesses_set: Boolean = False;
  doBkProcesses_lasttime: Integer = 0;
  script_chk_critters_count: Integer = 0;
  script_chk_timed_events_last_time: Integer = 0;
  script_chk_timed_events_last_light_time: Integer = 0;
  scr_get_msg_str_speech_err_str: array[0..5] of AnsiChar;
  scr_get_msg_str_speech_blank_str: array[0..0] of AnsiChar;

// ============================================================================
// Forward declarations for static (private) procedures
// ============================================================================

procedure doBkProcesses; cdecl; forward;
procedure script_chk_critters; forward;
procedure script_chk_timed_events; forward;
function scr_build_lookup_table(scr: PScript): Integer; forward;
function scr_index_to_name(scr_script_idx: Integer; name: PAnsiChar; size: SizeUInt): Integer; forward;
function scr_header_load: Integer; forward;
function scr_write_ScriptSubNode(scr: PScript; stream: PDB_FILE): Integer; forward;
function scr_write_ScriptNode(a1: PScriptListExtent; stream: PDB_FILE): Integer; forward;
function scr_read_ScriptSubNode(scr: PScript; stream: PDB_FILE): Integer; forward;
function scr_read_ScriptNode(a1: PScriptListExtent; stream: PDB_FILE): Integer; forward;
function scr_new_id(scriptType: Integer): Integer; forward;
procedure scrExecMapProcScripts(a1: Integer); forward;

// ============================================================================
// Initialization of string arrays
// ============================================================================

procedure InitProcTableStrs;
begin
  procTableStrs[0]  := 'no_p_proc';
  procTableStrs[1]  := 'start';
  procTableStrs[2]  := 'spatial_p_proc';
  procTableStrs[3]  := 'description_p_proc';
  procTableStrs[4]  := 'pickup_p_proc';
  procTableStrs[5]  := 'drop_p_proc';
  procTableStrs[6]  := 'use_p_proc';
  procTableStrs[7]  := 'use_obj_on_p_proc';
  procTableStrs[8]  := 'use_skill_on_p_proc';
  procTableStrs[9]  := 'none_x_bad';
  procTableStrs[10] := 'none_x_bad';
  procTableStrs[11] := 'talk_p_proc';
  procTableStrs[12] := 'critter_p_proc';
  procTableStrs[13] := 'combat_p_proc';
  procTableStrs[14] := 'damage_p_proc';
  procTableStrs[15] := 'map_enter_p_proc';
  procTableStrs[16] := 'map_exit_p_proc';
  procTableStrs[17] := 'create_p_proc';
  procTableStrs[18] := 'destroy_p_proc';
  procTableStrs[19] := 'none_x_bad';
  procTableStrs[20] := 'none_x_bad';
  procTableStrs[21] := 'look_at_p_proc';
  procTableStrs[22] := 'timed_event_p_proc';
  procTableStrs[23] := 'map_update_p_proc';
end;

// ============================================================================
// Implementation
// ============================================================================

function game_time: Integer;
begin
  Result := fallout_game_time;
end;

procedure game_time_date(monthPtr, dayPtr, yearPtr: PInteger);
var
  year, month, day, daysInMonth_: Integer;
begin
  year := (fallout_game_time div GAME_TIME_TICKS_PER_DAY + (GAME_TIME_START_DAY - 1)) div 365 + GAME_TIME_START_YEAR;
  month := GAME_TIME_START_MONTH - 1;
  day := (fallout_game_time div GAME_TIME_TICKS_PER_DAY + (GAME_TIME_START_DAY - 1)) mod 365;

  while True do
  begin
    daysInMonth_ := days_in_month[month];
    if day < daysInMonth_ then
      Break;

    Inc(month);
    Dec(day, daysInMonth_);

    if month = 12 then
    begin
      Inc(year);
      month := 0;
    end;
  end;

  if dayPtr <> nil then
    dayPtr^ := day + 1;

  if monthPtr <> nil then
    monthPtr^ := month + 1;

  if yearPtr <> nil then
    yearPtr^ := year;
end;

function game_time_hour: Integer;
begin
  Result := 100 * ((fallout_game_time div 600) div 60 mod 24) + (fallout_game_time div 600) mod 60;
end;

function game_time_hour_str: PAnsiChar;
begin
  StrLFmt(hour_str, SizeOf(hour_str) - 1, '%d:%02d',
    [(fallout_game_time div 600) div 60 mod 24, (fallout_game_time div 600) mod 60]);
  Result := @hour_str[0];
end;

procedure set_game_time(time_: Integer);
begin
  if time_ = 0 then
    time_ := 1;
  fallout_game_time := time_;
end;

procedure set_game_time_in_seconds(time_: Integer);
begin
  set_game_time(time_ * 10);
end;

procedure inc_game_time(inc_: Integer);
begin
  fallout_game_time := fallout_game_time + inc_;
end;

procedure inc_game_time_in_seconds(inc_: Integer);
begin
  inc_game_time(inc_ * 10);
end;

function gtime_q_add: Integer;
var
  delay: Integer;
begin
  delay := 10 * (60 * (60 - (fallout_game_time div 600) mod 60 - 1) + 3600 * (24 - (fallout_game_time div 600) div 60 mod 24 - 1) + 60);
  if queue_add(delay, nil, nil, EVENT_TYPE_GAME_TIME) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if map_data.name[0] <> #0 then
  begin
    if queue_add(600, nil, nil, EVENT_TYPE_MAP_UPDATE_EVENT) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

function gtime_q_process(obj: PObject; data: Pointer): Integer; cdecl;
var
  movie, rc, flags_: Integer;
begin
  movie := -1;

  debug_printf(#10'QUEUE PROCESS: Midnight!');

  if gtime_q_process_moviePlaying = 1 then
  begin
    Result := 0;
    Exit;
  end;

  obj_unjam_all_locks;

  if PInteger(PByte(game_global_vars) + Ord(GVAR_FIND_WATER_CHIP) * SizeOf(Integer))^ <> 2 then
  begin
    if PInteger(PByte(game_global_vars) + Ord(GVAR_VAULT_WATER) * SizeOf(Integer))^ > 0 then
    begin
      Dec(PInteger(PByte(game_global_vars) + Ord(GVAR_VAULT_WATER) * SizeOf(Integer))^);
      if not dialog_active then
      begin
        if (PInteger(PByte(game_global_vars) + Ord(GVAR_VAULT_WATER) * SizeOf(Integer))^ <= 100) and ((water_movie_play_flag and $2) = 0) then
        begin
          water_movie_play_flag := water_movie_play_flag or $2;
          movie := MOVIE_BOIL1;
        end
        else if (PInteger(PByte(game_global_vars) + Ord(GVAR_VAULT_WATER) * SizeOf(Integer))^ <= 50) and ((water_movie_play_flag and $4) = 0) then
        begin
          water_movie_play_flag := water_movie_play_flag or $4;
          movie := MOVIE_BOIL2;
        end
        else if PInteger(PByte(game_global_vars) + Ord(GVAR_VAULT_WATER) * SizeOf(Integer))^ = 0 then
        begin
          movie := MOVIE_BOIL3;
        end;
      end;
    end;
  end;

  if not dialog_active then
  begin
    if movie <> -1 then
    begin
      if not gmovie_has_been_played(movie) then
      begin
        if movie = MOVIE_BOIL3 then
          flags_ := GAME_MOVIE_FADE_IN or GAME_MOVIE_STOP_MUSIC
        else
          flags_ := GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_STOP_MUSIC;

        gtime_q_process_moviePlaying := 1;
        if gmovie_play(movie, flags_) = -1 then
          debug_printf(#10'Error playing movie!');
        gtime_q_process_moviePlaying := 0;

        tile_refresh_display;

        if movie = MOVIE_BOIL3 then
          game_user_wants_to_quit := 2
        else
          movie := -1;
      end
      else
        movie := -1;
    end;
  end;

  rc := critter_check_rads(obj_dude);

  queue_clear_type(EVENT_TYPE_GAME_TIME, nil);

  gtime_q_add;

  if movie <> -1 then
    rc := 1;

  Result := rc;
end;

function scr_map_q_process(obj: PObject; data: Pointer): Integer; cdecl;
begin
  scr_exec_map_update_scripts;

  queue_clear_type(EVENT_TYPE_MAP_UPDATE_EVENT, nil);

  if map_data.name[0] = #0 then
  begin
    Result := 0;
    Exit;
  end;

  if queue_add(600, nil, nil, EVENT_TYPE_MAP_UPDATE_EVENT) <> -1 then
  begin
    Result := 0;
    Exit;
  end;

  Result := -1;
end;

function new_obj_id: Integer;
var
  ptr: PObject;
begin
  repeat
    Inc(new_obj_id_cur_id);
    ptr := obj_find_first;

    while ptr <> nil do
    begin
      if new_obj_id_cur_id = ptr^.Id then
        Break;
      ptr := obj_find_next;
    end;
  until ptr = nil;

  if new_obj_id_cur_id >= 18000 then
    debug_printf(#10'    ERROR: new_obj_id() !!!! Picked PLAYER ID!!!!');

  Inc(new_obj_id_cur_id);

  Result := new_obj_id_cur_id;
end;

function scr_find_sid_from_program(program_: PProgram): Integer;
var
  type_: Integer;
  extent: PScriptListExtent;
  index_: Integer;
  script: PScript;
begin
  for type_ := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    extent := scriptlists[type_].head;
    while extent <> nil do
    begin
      for index_ := 0 to extent^.length - 1 do
      begin
        script := @extent^.scripts[index_];
        if script^.program_ = program_ then
        begin
          Result := script^.scr_id;
          Exit;
        end;
      end;
      extent := extent^.next;
    end;
  end;

  Result := -1;
end;

function scr_find_obj_from_program(program_: PProgram): PObject;
var
  sid, fid, elevation_: Integer;
  script, v1, spatialScript: PScript;
  obj: PObject;
begin
  sid := scr_find_sid_from_program(program_);

  if scr_ptr(sid, @script) = -1 then
  begin
    Result := nil;
    Exit;
  end;

  if script^.owner <> nil then
  begin
    Result := script^.owner;
    Exit;
  end;

  if SID_TYPE(sid) <> SCRIPT_TYPE_SPATIAL then
  begin
    Result := nil;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 3, 0, 0, 0);
  obj_new(@obj, fid, -1);
  obj_turn_off(obj, nil);
  obj_toggle_flat(obj, nil);
  obj^.Sid := sid;

  if scr_ptr(sid, @v1) = -1 then
  begin
    Result := PObject(Pointer(PtrInt(-1)));
    Exit;
  end;

  obj^.Id := new_obj_id;
  v1^.scr_oid := obj^.Id;
  v1^.owner := obj;

  for elevation_ := 0 to ELEVATION_COUNT - 1 do
  begin
    spatialScript := scr_find_first_at(elevation_);
    while spatialScript <> nil do
    begin
      if spatialScript = script then
      begin
        obj_move_to_tile(obj, BuiltTileGetTile(script^.u.sp.built_tile), elevation_, nil);
        Result := obj;
        Exit;
      end;
      spatialScript := scr_find_next_at;
    end;
  end;

  Result := obj;
end;

function scr_set_objs(sid: Integer; source, target: PObject): Integer;
var
  script: PScript;
begin
  if scr_ptr(sid, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  script^.source := source;
  script^.target := target;

  Result := 0;
end;

procedure scr_set_ext_param(sid, value: Integer);
var
  script: PScript;
begin
  if scr_ptr(sid, @script) <> -1 then
    script^.fixedParam := value;
end;

function scr_set_action_num(sid, value: Integer): Integer;
var
  scr: PScript;
begin
  if scr_ptr(sid, @scr) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scr^.actionBeingUsed := value;
  Result := 0;
end;

function loadProgram(name: PAnsiChar): PProgram;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrCopy(path, cd_path_base);
  StrCat(path, script_path_base);
  StrCat(path, name);
  StrCat(path, '.int');

  Result := allocateProgram(path);
end;

procedure scrSetQueueTestVals(a1: PObject; a2: Integer);
begin
  // Not implemented in scripts.cc - stub
end;

function scrQueueRemoveFixed(obj: PObject; data: Pointer): Integer;
begin
  // Not implemented in scripts.cc - stub
  Result := 0;
end;

procedure doBkProcesses; cdecl;
var
  v0: Integer;
  index_: Integer;
begin
  if not doBkProcesses_set then
  begin
    doBkProcesses_lasttime := get_bk_time;
    doBkProcesses_set := True;
  end;

  v0 := get_bk_time;
  if script_engine_running then
  begin
    doBkProcesses_lasttime := v0;
    for index_ := 0 to 0 do
      updatePrograms;
  end;

  updateWindows;

  if script_engine_running and (script_engine_run_critters <> 0) then
  begin
    if not dialog_active then
    begin
      script_chk_critters;
      script_chk_timed_events;
    end;
  end;
end;

procedure script_chk_critters;
var
  scriptList: PScriptList;
  scriptListExtent: PScriptListExtent;
  scriptsCount, proc_, extentIndex, scriptIndex: Integer;
  script: PScript;
begin
  if dialog_active or isInCombat then
    Exit;

  scriptsCount := 0;

  scriptList := @scriptlists[SCRIPT_TYPE_CRITTER];
  scriptListExtent := scriptList^.head;
  while scriptListExtent <> nil do
  begin
    scriptsCount := scriptsCount + scriptListExtent^.length;
    scriptListExtent := scriptListExtent^.next;
  end;

  script_chk_critters_count := script_chk_critters_count + 1;
  if script_chk_critters_count >= scriptsCount then
    script_chk_critters_count := 0;

  if script_chk_critters_count < scriptsCount then
  begin
    if isInCombat then
      proc_ := SCRIPT_PROC_COMBAT
    else
      proc_ := SCRIPT_PROC_CRITTER;

    extentIndex := script_chk_critters_count div SCRIPT_LIST_EXTENT_SIZE;
    scriptIndex := script_chk_critters_count mod SCRIPT_LIST_EXTENT_SIZE;

    scriptList := @scriptlists[SCRIPT_TYPE_CRITTER];
    scriptListExtent := scriptList^.head;
    while (scriptListExtent <> nil) and (extentIndex <> 0) do
    begin
      Dec(extentIndex);
      scriptListExtent := scriptListExtent^.next;
    end;

    if scriptListExtent <> nil then
    begin
      script := @scriptListExtent^.scripts[scriptIndex];
      exec_script_proc(script^.scr_id, proc_);
    end;
  end;
end;

procedure script_chk_timed_events;
var
  now_: LongWord;
  should_process_queue: Boolean;
begin
  now_ := get_bk_time;
  should_process_queue := False;

  if not isInCombat then
    should_process_queue := True;

  if game_state <> GAME_STATE_4 then
  begin
    if elapsed_tocks(now_, script_chk_timed_events_last_light_time) >= 30000 then
    begin
      script_chk_timed_events_last_light_time := now_;
      scr_exec_map_update_scripts;
    end;
  end
  else
    should_process_queue := False;

  if elapsed_tocks(now_, script_chk_timed_events_last_time) >= 100 then
  begin
    script_chk_timed_events_last_time := now_;
    if not isInCombat then
      fallout_game_time := fallout_game_time + 1;
    should_process_queue := True;
  end;

  if should_process_queue then
    queue_process;
end;

function script_q_add(sid, delay, param: Integer): Integer;
var
  scriptEvent: PScriptEvent;
  script: PScript;
begin
  scriptEvent := PScriptEvent(mem_malloc(SizeOf(TScriptEvent)));
  if scriptEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  scriptEvent^.sid := sid;
  scriptEvent^.fixedParam := param;

  if scr_ptr(sid, @script) = -1 then
  begin
    mem_free(scriptEvent);
    Result := -1;
    Exit;
  end;

  if queue_add(delay, script^.owner, scriptEvent, EVENT_TYPE_SCRIPT) = -1 then
  begin
    mem_free(scriptEvent);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function script_q_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
var
  scriptEvent: PScriptEvent;
begin
  scriptEvent := PScriptEvent(data);

  if db_fwriteInt(stream, scriptEvent^.sid) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scriptEvent^.fixedParam) = -1 then begin Result := -1; Exit; end;

  Result := 0;
end;

function script_q_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
var
  scriptEvent: PScriptEvent;
begin
  scriptEvent := PScriptEvent(mem_malloc(SizeOf(TScriptEvent)));
  if scriptEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @scriptEvent^.sid) = -1 then
  begin
    mem_free(scriptEvent);
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @scriptEvent^.fixedParam) = -1 then
  begin
    mem_free(scriptEvent);
    Result := -1;
    Exit;
  end;

  dataPtr^ := scriptEvent;
  Result := 0;
end;

function script_q_process(obj: PObject; data: Pointer): Integer; cdecl;
var
  scriptEvent: PScriptEvent;
  script: PScript;
begin
  scriptEvent := PScriptEvent(data);

  if scr_ptr(scriptEvent^.sid, @script) = -1 then
  begin
    Result := 0;
    Exit;
  end;

  script^.fixedParam := scriptEvent^.fixedParam;
  exec_script_proc(scriptEvent^.sid, SCRIPT_PROC_TIMED);

  Result := 0;
end;

function scripts_clear_state: Integer;
begin
  scriptState.requests := 0;
  Result := 0;
end;

function scripts_clear_combat_requests(script: PScript): Integer;
begin
  if ((scriptState.requests and SCRIPT_REQUEST_COMBAT) <> 0) and (scriptState.combatState1.attacker = script^.owner) then
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_COMBAT));
  Result := 0;
end;

function scripts_check_state: Integer;
var
  ctx: TWorldMapContext;
  map_, elevation_, tile_, pid: Integer;
  elevatorDoors: PObject;
  transition: TMapTransition;
begin
  if scriptState.requests = 0 then
  begin
    Result := 0;
    Exit;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_COMBAT) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_COMBAT));
    Move(scriptState.combatState1, scriptState.combatState2, SizeOf(scriptState.combatState2));

    if (scriptState.requests and SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE) <> 0 then
    begin
      scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE));
      combat(nil);
    end
    else
    begin
      combat(@scriptState.combatState2);
      FillChar(scriptState.combatState2, SizeOf(scriptState.combatState2), 0);
    end;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_TOWN_MAP) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_TOWN_MAP));
    ctx.state := 0;
    ctx.town := 0;
    world_map(ctx);
    KillWorldWin;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_WORLD_MAP) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_WORLD_MAP));
    ctx.state := 0;
    ctx.town := our_town;
    ctx := town_map(ctx);
    world_map(ctx);
    KillWorldWin;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_ELEVATOR) <> 0 then
  begin
    map_ := map_data.field_34;
    elevation_ := map_elevation;
    tile_ := -1;

    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_ELEVATOR));

    if elevator_select(scriptState.elevatorType, @map_, @elevation_, @tile_) <> -1 then
    begin
      automap_pip_save;

      if map_ = map_data.field_34 then
      begin
        if elevation_ = map_elevation then
        begin
          register_clear(obj_dude);
          obj_set_rotation(obj_dude, Ord(ROTATION_SE), nil);
          obj_attempt_placement(obj_dude, tile_, elevation_, 0);
        end
        else
        begin
          elevatorDoors := obj_find_first_at(obj_dude^.Elevation);
          while elevatorDoors <> nil do
          begin
            pid := elevatorDoors^.Pid;
            if (PID_TYPE(pid) = OBJ_TYPE_SCENERY)
              and ((pid = PROTO_ID_0x2000099) or (pid = PROTO_ID_0x20001A5) or (pid = PROTO_ID_0x20001D6))
              and (tile_dist(elevatorDoors^.Tile, obj_dude^.Tile) <= 4) then
              Break;
            elevatorDoors := obj_find_next_at;
          end;

          register_clear(obj_dude);
          obj_set_rotation(obj_dude, Ord(ROTATION_SE), nil);
          obj_attempt_placement(obj_dude, tile_, elevation_, 0);

          if elevatorDoors <> nil then
          begin
            obj_set_frame(elevatorDoors, 0, nil);
            obj_move_to_tile(elevatorDoors, elevatorDoors^.Tile, elevatorDoors^.Elevation, nil);
            elevatorDoors^.Flags := elevatorDoors^.Flags and (not Integer(OBJECT_OPEN_DOOR));
            elevatorDoors^.Data.AsData.Flags := elevatorDoors^.Data.AsData.Flags and (not $01);
            obj_rebuild_all_light;
          end
          else
            debug_printf(#10'Warning: Elevator: Couldn''t find old elevator doors!');
        end;
      end
      else
      begin
        elevatorDoors := obj_find_first_at(obj_dude^.Elevation);
        while elevatorDoors <> nil do
        begin
          pid := elevatorDoors^.Pid;
          if (PID_TYPE(pid) = OBJ_TYPE_SCENERY)
            and ((pid = PROTO_ID_0x2000099) or (pid = PROTO_ID_0x20001A5) or (pid = PROTO_ID_0x20001D6))
            and (tile_dist(elevatorDoors^.Tile, obj_dude^.Tile) <= 4) then
            Break;
          elevatorDoors := obj_find_next_at;
        end;

        if elevatorDoors <> nil then
        begin
          obj_set_frame(elevatorDoors, 0, nil);
          obj_move_to_tile(elevatorDoors, elevatorDoors^.Tile, elevatorDoors^.Elevation, nil);
          elevatorDoors^.Flags := elevatorDoors^.Flags and (not Integer(OBJECT_OPEN_DOOR));
          elevatorDoors^.Data.AsData.Flags := elevatorDoors^.Data.AsData.Flags and (not $01);
          obj_rebuild_all_light;
        end
        else
          debug_printf(#10'Warning: Elevator: Couldn''t find old elevator doors!');

        FillChar(transition, SizeOf(transition), 0);
        transition.map := map_;
        transition.elevation := elevation_;
        transition.tile := tile_;
        transition.rotation := Ord(ROTATION_SE);

        map_leave_map(@transition);
      end;
    end;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_EXPLOSION) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_EXPLOSION));
    action_explode(scriptState.explosionTile, scriptState.explosionElevation, scriptState.explosionMinDamage, scriptState.explosionMaxDamage, nil, True);
  end;

  if (scriptState.requests and SCRIPT_REQUEST_DIALOG) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_DIALOG));
    gdialog_enter(scriptState.dialogTarget, 0);
  end;

  if (scriptState.requests and SCRIPT_REQUEST_ENDGAME) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_ENDGAME));
    endgame_slideshow;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_LOOTING) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_LOOTING));
    loot_container(scriptState.lootingBy, scriptState.lootingFrom);
  end;

  if (scriptState.requests and SCRIPT_REQUEST_STEALING) <> 0 then
  begin
    scriptState.requests := scriptState.requests and (not LongWord(SCRIPT_REQUEST_STEALING));
    inven_steal_container(scriptState.stealingBy, scriptState.stealingFrom);
  end;

  Result := 0;
end;

function scripts_check_state_in_combat: Integer;
var
  map_, elevation_, tile_, pid: Integer;
  elevatorDoors: PObject;
  transition: TMapTransition;
begin
  if (scriptState.requests and SCRIPT_REQUEST_ELEVATOR) <> 0 then
  begin
    map_ := map_data.field_34;
    elevation_ := map_elevation;
    tile_ := -1;

    if elevator_select(scriptState.elevatorType, @map_, @elevation_, @tile_) <> -1 then
    begin
      automap_pip_save;

      if map_ = map_data.field_34 then
      begin
        if elevation_ = map_elevation then
        begin
          register_clear(obj_dude);
          obj_set_rotation(obj_dude, Ord(ROTATION_SE), nil);
          obj_attempt_placement(obj_dude, tile_, elevation_, 0);
        end
        else
        begin
          elevatorDoors := obj_find_first_at(obj_dude^.Elevation);
          while elevatorDoors <> nil do
          begin
            pid := elevatorDoors^.Pid;
            if (PID_TYPE(pid) = OBJ_TYPE_SCENERY)
              and ((pid = PROTO_ID_0x2000099) or (pid = PROTO_ID_0x20001A5) or (pid = PROTO_ID_0x20001D6))
              and (tile_dist(elevatorDoors^.Tile, obj_dude^.Tile) <= 4) then
              Break;
            elevatorDoors := obj_find_next_at;
          end;

          register_clear(obj_dude);
          obj_set_rotation(obj_dude, Ord(ROTATION_SE), nil);
          obj_attempt_placement(obj_dude, tile_, elevation_, 0);

          if elevatorDoors <> nil then
          begin
            obj_set_frame(elevatorDoors, 0, nil);
            obj_move_to_tile(elevatorDoors, elevatorDoors^.Tile, elevatorDoors^.Elevation, nil);
            elevatorDoors^.Flags := elevatorDoors^.Flags and (not Integer(OBJECT_OPEN_DOOR));
            elevatorDoors^.Data.AsData.Flags := elevatorDoors^.Data.AsData.Flags and (not $01);
            obj_rebuild_all_light;
          end
          else
            debug_printf(#10'Warning: Elevator: Couldn''t find old elevator doors!');
        end;
      end
      else
      begin
        FillChar(transition, SizeOf(transition), 0);
        transition.map := map_;
        transition.elevation := elevation_;
        transition.tile := tile_;
        transition.rotation := Ord(ROTATION_SE);
        map_leave_map(@transition);
      end;
    end;
  end;

  if (scriptState.requests and SCRIPT_REQUEST_LOOTING) <> 0 then
    loot_container(scriptState.lootingBy, scriptState.lootingFrom);

  scripts_clear_state;

  Result := 0;
end;

function scripts_request_combat(a1: PSTRUCT_664980): Integer;
begin
  if a1 <> nil then
    Move(a1^, scriptState.combatState1, SizeOf(scriptState.combatState1))
  else
    scriptState.requests := scriptState.requests or SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE;

  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_COMBAT;
  Result := 0;
end;

procedure scripts_request_townmap;
begin
  if isInCombat then
    game_user_wants_to_quit := 1;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_TOWN_MAP;
end;

procedure scripts_request_worldmap;
begin
  if isInCombat then
    game_user_wants_to_quit := 1;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_WORLD_MAP;
end;

function scripts_request_elevator(elevator: Integer): Integer;
begin
  scriptState.elevatorType := elevator;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_ELEVATOR;
  Result := 0;
end;

function scripts_request_explosion(tile, elevation, minDamage, maxDamage: Integer): Integer;
begin
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_EXPLOSION;
  scriptState.explosionTile := tile;
  scriptState.explosionElevation := elevation;
  scriptState.explosionMinDamage := minDamage;
  scriptState.explosionMaxDamage := maxDamage;
  Result := 0;
end;

procedure scripts_request_dialog(obj: PObject);
begin
  scriptState.dialogTarget := obj;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_DIALOG;
end;

procedure scripts_request_endgame_slideshow;
begin
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_ENDGAME;
end;

function scripts_request_loot_container(a1, a2: PObject): Integer;
begin
  scriptState.lootingBy := a1;
  scriptState.lootingFrom := a2;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_LOOTING;
  Result := 0;
end;

function scripts_request_steal_container(a1, a2: PObject): Integer;
begin
  scriptState.stealingBy := a1;
  scriptState.stealingFrom := a2;
  scriptState.requests := scriptState.requests or SCRIPT_REQUEST_STEALING;
  Result := 0;
end;

procedure script_make_path(path: PAnsiChar);
begin
  StrCopy(path, cd_path_base);
  StrCat(path, script_path_base);
end;

function exec_script_proc(sid, proc: Integer): Integer;
var
  script: PScript;
  programLoaded: Boolean;
  name: array[0..15] of AnsiChar;
  pch: PAnsiChar;
  program__: PProgram;
  procIdx: Integer;
begin
  if not script_engine_running then
  begin
    Result := -1;
    Exit;
  end;

  if scr_ptr(sid, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  script^.action := proc;
  script^.scriptOverrides := 0;

  programLoaded := False;
  if (script^.scr_flags and SCRIPT_FLAG_0x01) = 0 then
  begin
    if scr_list_str(script^.scr_script_idx, name, SizeOf(name)) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    pch := StrScan(name, '.');
    if pch <> nil then
      pch^ := #0;

    script^.program_ := loadProgram(name);
    if script^.program_ = nil then
    begin
      debug_printf(#10'Error: exec_script_proc: script load failed!');
      Result := -1;
      Exit;
    end;

    programLoaded := True;
    script^.scr_flags := script^.scr_flags or SCRIPT_FLAG_0x01;
  end;

  program__ := script^.program_;
  if program__ = nil then
  begin
    Result := -1;
    Exit;
  end;

  if (program__^.flags and $0124) <> 0 then
  begin
    Result := 0;
    Exit;
  end;

  procIdx := script^.procs[proc];
  if procIdx = 0 then
    procIdx := 1;

  if procIdx = -1 then
  begin
    debug_printf(#10'Error: exec_script_proc: Can''t Find script procedure!!!');
    Result := -1;
    Exit;
  end;

  if script^.target = nil then
    script^.target := script^.owner;

  script^.scr_flags := script^.scr_flags or SCRIPT_FLAG_0x04;

  if programLoaded then
  begin
    scr_build_lookup_table(script);
    runProgram(program__);
    interpretSetCPUBurstSize(5000);
    updatePrograms;
    interpretSetCPUBurstSize(10);
  end
  else
    executeProcedure(program__, procIdx);

  script^.source := nil;

  Result := 0;
end;

function scr_build_lookup_table(scr: PScript): Integer;
var
  action_, proc_: Integer;
begin
  for action_ := 0 to SCRIPT_PROC_COUNT - 1 do
  begin
    proc_ := interpretFindProcedure(scr^.program_, procTableStrs[action_]);
    if proc_ = -1 then
      proc_ := SCRIPT_PROC_NO_PROC;
    scr^.procs[action_] := proc_;
  end;

  Result := 0;
end;

function scr_find_str_run_info(scr_script_idx: Integer; run_info_flags: PInteger; sid: Integer): Integer;
var
  rc: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  idx: Integer;
  str_: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  sep: PAnsiChar;
  script: PScript;
begin
  if scr_script_idx < 0 then
  begin
    Result := -1;
    Exit;
  end;

  if run_info_flags = nil then
  begin
    Result := -1;
    Exit;
  end;

  script_make_path(path);
  StrCat(path, 'scripts.lst');

  stream := db_fopen(path, 'rt');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  rc := -1;
  idx := 0;
  while idx <= scr_script_idx do
  begin
    if db_fgets(str_, SizeOf(str_), stream) = nil then
      Break;
    Inc(idx);
  end;

  if idx - 1 = scr_script_idx then
  begin
    rc := 0;
    sep := StrScan(str_, '#');
    if sep <> nil then
    begin
      if (sep + 1)^ <> #0 then
      begin
        if StrPos(sep, 'map_init') <> nil then
          run_info_flags^ := run_info_flags^ or $1;

        if StrPos(sep, 'map_exit') <> nil then
          run_info_flags^ := run_info_flags^ or $2;

        sep := StrPos(sep, 'local_vars=');
        if sep <> nil then
        begin
          if scr_ptr(sid, @script) <> -1 then
            script^.scr_num_local_vars := StrToIntDef(String(AnsiString(sep + 11)), 0)
          else
            rc := -1;
        end;
      end;
    end;
  end;

  db_fclose(stream);
  Result := rc;
end;

function scr_index_to_name(scr_script_idx: Integer; name: PAnsiChar; size: SizeUInt): Integer;
var
  rc: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  idx: Integer;
  str_: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  sep: PAnsiChar;
begin
  if scr_script_idx < 0 then
  begin
    Result := -1;
    Exit;
  end;

  if name = nil then
  begin
    Result := -1;
    Exit;
  end;

  script_make_path(path);
  StrCat(path, 'scripts.lst');

  stream := db_fopen(path, 'rt');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  rc := -1;
  idx := 0;
  while idx <= scr_script_idx do
  begin
    if db_fgets(str_, SizeOf(str_), stream) = nil then
      Break;
    Inc(idx);
  end;

  if idx - 1 = scr_script_idx then
  begin
    sep := StrScan(str_, '.');
    if sep <> nil then
    begin
      sep^ := #0;
      StrLFmt(name, size - 1, '%s.%s', [str_, 'int']);
      rc := 0;
    end;
  end;

  db_fclose(stream);
  Result := rc;
end;

function scr_list_str(index_: Integer; name: PAnsiChar; size: SizeUInt): Integer;
begin
  name^ := #0;
  Result := scr_index_to_name(index_ and $FFFFFF, name, size);
end;

function scr_set_dude_script: Integer;
var
  proto_: PProto;
  script: PScript;
begin
  if scr_clear_dude_script = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if obj_dude = nil then
  begin
    debug_printf('Error in scr_set_dude_script: obj_dude uninitialized!');
    Result := -1;
    Exit;
  end;

  if proto_ptr($1000000, @proto_) = -1 then
  begin
    debug_printf('Error in scr_set_dude_script: can''t find obj_dude proto!');
    Result := -1;
    Exit;
  end;

  proto_^.Critter.Sid := $4000000;

  obj_new_sid(obj_dude, @obj_dude^.Sid);

  if scr_ptr(obj_dude^.Sid, @script) = -1 then
  begin
    debug_printf('Error in scr_set_dude_script: can''t find obj_dude script!');
    Result := -1;
    Exit;
  end;

  script^.scr_flags := script^.scr_flags or (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10);

  Result := 0;
end;

function scr_clear_dude_script: Integer;
var
  script: PScript;
begin
  if obj_dude = nil then
  begin
    debug_printf(#10'Error in scr_clear_dude_script: obj_dude uninitialized!');
    Result := -1;
    Exit;
  end;

  if obj_dude^.Sid <> -1 then
  begin
    if scr_ptr(obj_dude^.Sid, @script) <> -1 then
      script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10));

    scr_remove(obj_dude^.Sid);
    obj_dude^.Sid := -1;
  end;

  Result := 0;
end;

function scr_init: Integer;
var
  index_: Integer;
begin
  if not message_init(@script_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  for index_ := 0 to SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY - 1 do
  begin
    if not message_init(@script_dialog_msgs[index_]) then
    begin
      Result := -1;
      Exit;
    end;
  end;

  scr_remove_all;
  interpretOutputFunc(TInterpretOutputFunc(@win_debug));
  initInterpreter;
  scr_header_load;

  scripts_clear_state;
  partyMemberClear;

  Result := 0;
end;

function scr_reset: Integer;
begin
  scr_remove_all;
  scripts_clear_state;
  partyMemberClear;
  Result := 0;
end;

function scr_game_init: Integer;
var
  index_: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  // Initialize interpreter opcode handlers
  initIntlib;

  if not message_init(@script_message_file) then
  begin
    debug_printf(#10'Error initing script message file!');
    Result := -1;
    Exit;
  end;

  for index_ := 0 to SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY - 1 do
  begin
    if not message_init(@script_dialog_msgs[index_]) then
    begin
      debug_printf(#10'ERROR IN SCRIPT_DIALOG_MSGS!');
      Result := -1;
      Exit;
    end;
  end;

  StrLFmt(path, SizeOf(path) - 1, '%s%s', [msg_path, 'script.msg']);
  if not message_load(@script_message_file, path) then
  begin
    debug_printf(#10'Error loading script message file!');
    Result := -1;
    Exit;
  end;

  script_engine_running := True;
  script_engine_game_mode := 1;
  fallout_game_time := 1;
  water_movie_play_flag := 0;
  set_game_time_in_seconds(GAME_TIME_START_HOUR * 60 * 60 + GAME_TIME_START_MINUTE * 60);
  add_bk_process(@doBkProcesses);

  if scr_set_dude_script = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scripts_clear_state;
  scr_spatials_enable;

  Result := 0;
end;

function scr_game_reset: Integer;
begin
  debug_printf(#10'Scripts: [Game Reset]');
  scr_game_exit;
  scr_game_init;
  partyMemberClear;
  scr_remove_all_force;
  water_movie_play_flag := 0;
  Result := scr_set_dude_script;
end;

function scr_exit: Integer;
begin
  script_engine_running := False;
  script_engine_run_critters := 0;
  if not message_exit(@script_message_file) then
  begin
    debug_printf(#10'Error exiting script message file!');
    Result := -1;
    Exit;
  end;

  scr_remove_all;
  scr_remove_all_force;
  interpretClose;
  clearPrograms;

  remove_bk_process(@doBkProcesses);
  scripts_clear_state;

  Result := 0;
end;

function scr_message_free: Integer;
var
  index_: Integer;
  message_list: PMessageList;
begin
  for index_ := 0 to SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY - 1 do
  begin
    message_list := @script_dialog_msgs[index_];
    if message_list^.entries_num <> 0 then
    begin
      if not message_exit(message_list) then
      begin
        debug_printf(#10'ERROR in scr_message_free!');
        Result := -1;
        Exit;
      end;

      if not message_init(message_list) then
      begin
        debug_printf(#10'ERROR in scr_message_free!');
        Result := -1;
        Exit;
      end;
    end;
  end;

  Result := 0;
end;

function scr_game_exit: Integer;
begin
  script_engine_game_mode := 0;
  script_engine_running := False;
  script_engine_run_critters := 0;
  scr_message_free;
  scr_remove_all;
  clearPrograms;
  remove_bk_process(@doBkProcesses);
  message_exit(@script_message_file);
  if scr_clear_dude_script = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scripts_clear_state;
  Result := 0;
end;

function scr_enable: Integer;
begin
  if script_engine_game_mode = 0 then
  begin
    Result := -1;
    Exit;
  end;

  script_engine_run_critters := 1;
  script_engine_running := True;
  Result := 0;
end;

function scr_disable: Integer;
begin
  script_engine_running := False;
  Result := 0;
end;

procedure scr_enable_critters;
begin
  script_engine_run_critters := 1;
end;

procedure scr_disable_critters;
begin
  script_engine_run_critters := 0;
end;

function scr_game_save(stream: PDB_FILE): Integer;
begin
  if db_fwriteIntCount(stream, game_global_vars, num_game_global_vars) = -1 then begin Result := -1; Exit; end;
  if db_fwriteByte(stream, water_movie_play_flag) = -1 then begin Result := -1; Exit; end;
  Result := 0;
end;

function scr_game_load(stream: PDB_FILE): Integer;
begin
  if db_freadIntCount(stream, game_global_vars, num_game_global_vars) = -1 then begin Result := -1; Exit; end;
  if db_freadByte(stream, @water_movie_play_flag) = -1 then begin Result := -1; Exit; end;
  Result := 0;
end;

function scr_game_load2(stream: PDB_FILE): Integer;
var
  temp_vars: PInteger;
  temp_water_movie_play_flag: Byte;
begin
  temp_vars := PInteger(mem_malloc(SizeOf(Integer) * num_game_global_vars));
  if temp_vars = nil then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadIntCount(stream, temp_vars, num_game_global_vars) = -1 then
  begin
    mem_free(temp_vars);
    Result := -1;
    Exit;
  end;

  if db_freadByte(stream, @temp_water_movie_play_flag) = -1 then
  begin
    mem_free(temp_vars);
    Result := -1;
    Exit;
  end;

  mem_free(temp_vars);
  Result := 0;
end;

function scr_header_load: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  ch, scriptType: Integer;
  scriptList: PScriptList;
begin
  num_script_indexes := 0;

  script_make_path(path);
  StrCat(path, 'scripts.lst');

  stream := db_fopen(path, 'rt');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  while True do
  begin
    ch := db_fgetc(stream);
    if ch = -1 then
      Break;
    if ch = Ord(#10) then
      Inc(num_script_indexes);
  end;

  Inc(num_script_indexes);

  db_fclose(stream);

  for scriptType := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    scriptList := @scriptlists[scriptType];
    scriptList^.head := nil;
    scriptList^.tail := nil;
    scriptList^.length := 0;
    scriptList^.nextScriptId := 0;
  end;

  Result := 0;
end;

function scr_write_ScriptSubNode(scr: PScript; stream: PDB_FILE): Integer;
begin
  if db_fwriteInt(stream, scr^.scr_id) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scr_next) = -1 then begin Result := -1; Exit; end;

  case SID_TYPE(scr^.scr_id) of
    SCRIPT_TYPE_SPATIAL:
    begin
      if db_fwriteInt(stream, scr^.u.sp.built_tile) = -1 then begin Result := -1; Exit; end;
      if db_fwriteInt(stream, scr^.u.sp.radius) = -1 then begin Result := -1; Exit; end;
    end;
    SCRIPT_TYPE_TIMED:
    begin
      if db_fwriteInt(stream, scr^.u.tm.time) = -1 then begin Result := -1; Exit; end;
    end;
  end;

  if db_fwriteInt(stream, scr^.scr_flags) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scr_script_idx) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, 0) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scr_oid) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scr_local_var_offset) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scr_num_local_vars) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.field_28) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.action) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.fixedParam) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.actionBeingUsed) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.scriptOverrides) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.field_48) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.howMuch) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, scr^.run_info_flags) = -1 then begin Result := -1; Exit; end;

  Result := 0;
end;

function scr_write_ScriptNode(a1: PScriptListExtent; stream: PDB_FILE): Integer;
var
  index_: Integer;
  script: PScript;
begin
  for index_ := 0 to SCRIPT_LIST_EXTENT_SIZE - 1 do
  begin
    script := @a1^.scripts[index_];
    if scr_write_ScriptSubNode(script, stream) <> 0 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  if db_fwriteInt(stream, a1^.length) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwriteInt(stream, 0) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function scr_save(stream: PDB_FILE): Integer;
var
  scriptType, scriptCount, index_, backwardsIndex, len_: Integer;
  scriptList: PScriptList;
  scriptExtent, lastScriptExtent, previousScriptExtent: PScriptListExtent;
  script, backwardsScript: PScript;
  temp: TScript;
begin
  for scriptType := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    scriptList := @scriptlists[scriptType];

    scriptCount := scriptList^.length * SCRIPT_LIST_EXTENT_SIZE;
    if scriptList^.tail <> nil then
      scriptCount := scriptCount + scriptList^.tail^.length - SCRIPT_LIST_EXTENT_SIZE;

    scriptExtent := scriptList^.head;
    lastScriptExtent := nil;
    while scriptExtent <> nil do
    begin
      for index_ := 0 to scriptExtent^.length - 1 do
      begin
        script := @scriptExtent^.scripts[index_];

        lastScriptExtent := scriptList^.tail;
        if (script^.scr_flags and SCRIPT_FLAG_0x08) <> 0 then
        begin
          Dec(scriptCount);

          backwardsIndex := lastScriptExtent^.length - 1;
          if (lastScriptExtent = scriptExtent) and (backwardsIndex <= index_) then
            Break;

          while (lastScriptExtent <> scriptExtent) or (backwardsIndex > index_) do
          begin
            backwardsScript := @lastScriptExtent^.scripts[backwardsIndex];
            if (backwardsScript^.scr_flags and SCRIPT_FLAG_0x08) = 0 then
              Break;

            Dec(backwardsIndex);

            if backwardsIndex < 0 then
            begin
              previousScriptExtent := scriptList^.head;
              while previousScriptExtent^.next <> lastScriptExtent do
                previousScriptExtent := previousScriptExtent^.next;

              lastScriptExtent := previousScriptExtent;
              backwardsIndex := lastScriptExtent^.length - 1;
            end;
          end;

          if (lastScriptExtent <> scriptExtent) or (backwardsIndex > index_) then
          begin
            Move(script^, temp, SizeOf(TScript));
            Move(lastScriptExtent^.scripts[backwardsIndex], script^, SizeOf(TScript));
            Move(temp, lastScriptExtent^.scripts[backwardsIndex], SizeOf(TScript));
            Inc(scriptCount);
          end;
        end;
      end;
      scriptExtent := scriptExtent^.next;
    end;

    if db_fwriteInt(stream, scriptCount) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if scriptCount > 0 then
    begin
      scriptExtent := scriptList^.head;
      while scriptExtent <> lastScriptExtent do
      begin
        if scr_write_ScriptNode(scriptExtent, stream) = -1 then
        begin
          Result := -1;
          Exit;
        end;
        scriptExtent := scriptExtent^.next;
      end;

      if lastScriptExtent <> nil then
      begin
        index_ := 0;
        while index_ < lastScriptExtent^.length do
        begin
          script := @lastScriptExtent^.scripts[index_];
          if (script^.scr_flags and SCRIPT_FLAG_0x08) <> 0 then
            Break;
          Inc(index_);
        end;

        if index_ > 0 then
        begin
          len_ := lastScriptExtent^.length;
          lastScriptExtent^.length := index_;
          if scr_write_ScriptNode(lastScriptExtent, stream) = -1 then
          begin
            Result := -1;
            Exit;
          end;
          lastScriptExtent^.length := len_;
        end;
      end;
    end;
  end;

  Result := 0;
end;

function scr_read_ScriptSubNode(scr: PScript; stream: PDB_FILE): Integer;
var
  prg: Integer;
  index_: Integer;
begin
  if db_freadInt(stream, @scr^.scr_id) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scr_next) = -1 then begin Result := -1; Exit; end;

  case SID_TYPE(scr^.scr_id) of
    SCRIPT_TYPE_SPATIAL:
    begin
      if db_freadInt(stream, @scr^.u.sp.built_tile) = -1 then begin Result := -1; Exit; end;
      if db_freadInt(stream, @scr^.u.sp.radius) = -1 then begin Result := -1; Exit; end;
    end;
    SCRIPT_TYPE_TIMED:
    begin
      if db_freadInt(stream, @scr^.u.tm.time) = -1 then begin Result := -1; Exit; end;
    end;
  end;

  if db_freadInt(stream, @scr^.scr_flags) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scr_script_idx) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @prg) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scr_oid) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scr_local_var_offset) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scr_num_local_vars) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.field_28) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.action) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.fixedParam) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.actionBeingUsed) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.scriptOverrides) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.field_48) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.howMuch) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @scr^.run_info_flags) = -1 then begin Result := -1; Exit; end;

  scr^.program_ := nil;
  scr^.owner := nil;
  scr^.source := nil;
  scr^.target := nil;

  for index_ := 0 to SCRIPT_PROC_COUNT - 1 do
    scr^.procs[index_] := 0;

  if (map_data.flags and 1) = 0 then
    scr^.scr_num_local_vars := 0;

  Result := 0;
end;

function scr_read_ScriptNode(a1: PScriptListExtent; stream: PDB_FILE): Integer;
var
  index_, next_: Integer;
  scr: PScript;
begin
  for index_ := 0 to SCRIPT_LIST_EXTENT_SIZE - 1 do
  begin
    scr := @a1^.scripts[index_];
    if scr_read_ScriptSubNode(scr, stream) <> 0 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  if db_freadInt(stream, @a1^.length) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @next_) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function scr_load(stream: PDB_FILE): Integer;
var
  index_, scriptsCount, scriptIndex, extentIndex: Integer;
  scriptList: PScriptList;
  extent, prevExtent: PScriptListExtent;
  script: PScript;
begin
  for index_ := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    scriptList := @scriptlists[index_];

    scriptsCount := 0;
    if db_freadInt(stream, @scriptsCount) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if scriptsCount <> 0 then
    begin
      scriptList^.length := scriptsCount div 16;

      if scriptsCount mod 16 <> 0 then
        Inc(scriptList^.length);

      extent := PScriptListExtent(mem_malloc(SizeOf(TScriptListExtent)));
      scriptList^.head := extent;
      scriptList^.tail := extent;
      if extent = nil then
      begin
        Result := -1;
        Exit;
      end;

      if scr_read_ScriptNode(extent, stream) <> 0 then
      begin
        Result := -1;
        Exit;
      end;

      for scriptIndex := 0 to extent^.length - 1 do
      begin
        script := @extent^.scripts[scriptIndex];
        script^.owner := nil;
        script^.source := nil;
        script^.target := nil;
        script^.program_ := nil;
        script^.scr_flags := script^.scr_flags and (not SCRIPT_FLAG_0x01);
      end;

      extent^.next := nil;

      prevExtent := extent;
      for extentIndex := 1 to scriptList^.length - 1 do
      begin
        extent := PScriptListExtent(mem_malloc(SizeOf(TScriptListExtent)));
        if extent = nil then
        begin
          Result := -1;
          Exit;
        end;

        if scr_read_ScriptNode(extent, stream) <> 0 then
        begin
          Result := -1;
          Exit;
        end;

        for scriptIndex := 0 to extent^.length - 1 do
        begin
          script := @extent^.scripts[scriptIndex];
          script^.owner := nil;
          script^.source := nil;
          script^.target := nil;
          script^.program_ := nil;
          script^.scr_flags := script^.scr_flags and (not SCRIPT_FLAG_0x01);
        end;

        prevExtent^.next := extent;
        extent^.next := nil;
        prevExtent := extent;
      end;

      scriptList^.tail := prevExtent;
    end
    else
    begin
      scriptList^.head := nil;
      scriptList^.tail := nil;
      scriptList^.length := 0;
    end;
  end;

  Result := 0;
end;

function scr_ptr(sid: Integer; scriptPtr: PPScript): Integer;
var
  scriptList: PScriptList;
  scriptListExtent: PScriptListExtent;
  index_: Integer;
  script: PScript;
begin
  scriptPtr^ := nil;

  if sid = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if LongWord(sid) = $CCCCCCCC then
  begin
    debug_printf(#10'ERROR: scr_ptr called with UN-SET id #!!!!');
    Result := -1;
    Exit;
  end;

  scriptList := @scriptlists[SID_TYPE(sid)];
  scriptListExtent := scriptList^.head;

  while scriptListExtent <> nil do
  begin
    for index_ := 0 to scriptListExtent^.length - 1 do
    begin
      script := @scriptListExtent^.scripts[index_];
      if script^.scr_id = sid then
      begin
        scriptPtr^ := script;
        Result := 0;
        Exit;
      end;
    end;
    scriptListExtent := scriptListExtent^.next;
  end;

  Result := -1;
end;

function scr_new_id(scriptType: Integer): Integer;
var
  scriptId, v1: Integer;
  script: PScript;
begin
  scriptId := scriptlists[scriptType].nextScriptId;
  Inc(scriptlists[scriptType].nextScriptId);
  v1 := scriptType shl 24;

  while scriptId < 32000 do
  begin
    if scr_ptr(v1 or scriptId, @script) = -1 then
      Break;
    Inc(scriptId);
  end;

  Result := scriptId;
end;

function scr_new(sidPtr: PInteger; scriptType: Integer): Integer;
var
  scriptList: PScriptList;
  scriptListExtent, newExtent: PScriptListExtent;
  sid, index_: Integer;
  scr: PScript;
begin
  scriptList := @scriptlists[scriptType];
  scriptListExtent := scriptList^.tail;
  if scriptList^.head <> nil then
  begin
    if scriptListExtent^.length = SCRIPT_LIST_EXTENT_SIZE then
    begin
      newExtent := PScriptListExtent(mem_malloc(SizeOf(TScriptListExtent)));
      if newExtent = nil then
      begin
        Result := -1;
        Exit;
      end;

      scriptListExtent^.next := newExtent;
      newExtent^.length := 0;
      newExtent^.next := nil;

      scriptList^.tail := newExtent;
      Inc(scriptList^.length);

      scriptListExtent := newExtent;
    end;
  end
  else
  begin
    scriptListExtent := PScriptListExtent(mem_malloc(SizeOf(TScriptListExtent)));
    if scriptListExtent = nil then
    begin
      Result := -1;
      Exit;
    end;

    scriptListExtent^.length := 0;
    scriptListExtent^.next := nil;

    scriptList^.head := scriptListExtent;
    scriptList^.tail := scriptListExtent;
    scriptList^.length := 1;
  end;

  sid := scr_new_id(scriptType) or (scriptType shl 24);
  sidPtr^ := sid;

  scr := @scriptListExtent^.scripts[scriptListExtent^.length];
  scr^.scr_id := sid;
  scr^.u.sp.built_tile := -1;
  scr^.u.sp.radius := -1;
  scr^.scr_flags := 0;
  scr^.scr_script_idx := -1;
  scr^.program_ := nil;
  scr^.scr_local_var_offset := -1;
  scr^.scr_num_local_vars := 0;
  scr^.field_28 := 0;
  scr^.action := 0;
  scr^.fixedParam := 0;
  scr^.owner := nil;
  scr^.source := nil;
  scr^.target := nil;
  scr^.actionBeingUsed := -1;
  scr^.scriptOverrides := 0;
  scr^.field_48 := 0;
  scr^.howMuch := 0;
  scr^.run_info_flags := 0;

  for index_ := 0 to SCRIPT_PROC_COUNT - 1 do
    scr^.procs[index_] := SCRIPT_PROC_NO_PROC;

  Inc(scriptListExtent^.length);

  Result := 0;
end;

function scr_remove_local_vars(script: PScript): Integer;
var
  oldMapLocalVarsCount, index_, innerIndex: Integer;
  scriptList: PScriptList;
  extent: PScriptListExtent;
  other: PScript;
begin
  if script = nil then
  begin
    Result := -1;
    Exit;
  end;

  if script^.scr_num_local_vars <> 0 then
  begin
    oldMapLocalVarsCount := num_map_local_vars;
    if (oldMapLocalVarsCount > 0) and (script^.scr_local_var_offset >= 0) then
    begin
      num_map_local_vars := num_map_local_vars - script^.scr_num_local_vars;

      if (oldMapLocalVarsCount - script^.scr_num_local_vars <> script^.scr_local_var_offset) and (script^.scr_local_var_offset <> -1) then
      begin
        Move(PInteger(PByte(map_local_vars) + (script^.scr_local_var_offset + script^.scr_num_local_vars) * SizeOf(Integer))^,
             PInteger(PByte(map_local_vars) + script^.scr_local_var_offset * SizeOf(Integer))^,
             SizeOf(Integer) * (oldMapLocalVarsCount - script^.scr_num_local_vars - script^.scr_local_var_offset));

        map_local_vars := PInteger(mem_realloc(map_local_vars, SizeOf(Integer) * num_map_local_vars));
        if map_local_vars = nil then
          debug_printf(#10'Error in mem_realloc in scr_remove_local_vars!'#10);

        for index_ := 0 to SCRIPT_TYPE_COUNT - 1 do
        begin
          scriptList := @scriptlists[index_];
          extent := scriptList^.head;
          while extent <> nil do
          begin
            for innerIndex := 0 to extent^.length - 1 do
            begin
              other := @extent^.scripts[innerIndex];
              if other^.scr_local_var_offset > script^.scr_local_var_offset then
                other^.scr_local_var_offset := other^.scr_local_var_offset - script^.scr_num_local_vars;
            end;
            extent := extent^.next;
          end;
        end;
      end;
    end;
  end;

  Result := 0;
end;

function scr_remove(sid: Integer): Integer;
var
  scriptList: PScriptList;
  scriptListExtent, v13, prev: PScriptListExtent;
  index_: Integer;
  script: PScript;
  found: Boolean;
begin
  if sid = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scriptList := @scriptlists[SID_TYPE(sid)];

  scriptListExtent := scriptList^.head;
  index_ := 0;
  found := False;
  while scriptListExtent <> nil do
  begin
    for index_ := 0 to scriptListExtent^.length - 1 do
    begin
      script := @scriptListExtent^.scripts[index_];
      if script^.scr_id = sid then
      begin
        found := True;
        Break;
      end;
    end;

    if found then
      Break;

    scriptListExtent := scriptListExtent^.next;
  end;

  if scriptListExtent = nil then
  begin
    Result := -1;
    Exit;
  end;

  script := @scriptListExtent^.scripts[index_];
  if (script^.scr_flags and SCRIPT_FLAG_0x02) <> 0 then
  begin
    if script^.program_ <> nil then
      script^.program_ := nil;
  end;

  if (script^.scr_flags and SCRIPT_FLAG_0x10) = 0 then
  begin
    scripts_clear_combat_requests(script);

    if scr_remove_local_vars(script) = -1 then
      debug_printf(#10'ERROR Removing local vars on scr_remove!!'#10);

    if queue_remove_this(script^.owner, EVENT_TYPE_SCRIPT) = -1 then
      debug_printf(#10'ERROR Removing Timed Events on scr_remove!!'#10);

    if (scriptListExtent = scriptList^.tail) and (index_ + 1 = scriptListExtent^.length) then
    begin
      Dec(scriptListExtent^.length);

      if scriptListExtent^.length = 0 then
      begin
        Dec(scriptList^.length);
        mem_free(scriptListExtent);

        if scriptList^.length <> 0 then
        begin
          v13 := scriptList^.head;
          while scriptList^.tail <> v13^.next do
            v13 := v13^.next;
          v13^.next := nil;
          scriptList^.tail := v13;
        end
        else
        begin
          scriptList^.head := nil;
          scriptList^.tail := nil;
        end;
      end;
    end
    else
    begin
      Move(scriptList^.tail^.scripts[scriptList^.tail^.length - 1],
           scriptListExtent^.scripts[index_],
           SizeOf(TScript));

      Dec(scriptList^.tail^.length);

      if scriptList^.tail^.length = 0 then
      begin
        Dec(scriptList^.length);

        prev := scriptList^.head;
        while prev^.next <> scriptList^.tail do
          prev := prev^.next;
        prev^.next := nil;

        mem_free(scriptList^.tail);
        scriptList^.tail := prev;
      end;
    end;
  end;

  Result := 0;
end;

function scr_remove_all: Integer;
var
  scriptType, index_: Integer;
  scriptListExtent: PScriptListExtent;
  script: PScript;
begin
  queue_clear_type(EVENT_TYPE_SCRIPT, nil);
  scr_message_free;

  for scriptType := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    scriptListExtent := scriptlists[scriptType].head;
    while scriptListExtent <> nil do
    begin
      index_ := 0;
      while (scriptListExtent <> nil) and (index_ < scriptListExtent^.length) do
      begin
        script := @scriptListExtent^.scripts[index_];

        if (script^.scr_flags and SCRIPT_FLAG_0x10) <> 0 then
          Inc(index_)
        else
        begin
          if (index_ = 0) and (scriptListExtent^.length = 1) then
          begin
            scriptListExtent := scriptListExtent^.next;
            scr_remove(script^.scr_id);
          end
          else
            scr_remove(script^.scr_id);
        end;
      end;

      if scriptListExtent <> nil then
        scriptListExtent := scriptListExtent^.next;
    end;
  end;

  scr_find_first_idx := 0;
  scr_find_first_ptr := nil;
  scr_find_first_elev := 0;
  map_script_id := -1;

  clearPrograms;
  exportClearAllVariables;

  Result := 0;
end;

function scr_remove_all_force: Integer;
var
  type_: Integer;
  scriptList: PScriptList;
  extent, next_: PScriptListExtent;
begin
  queue_clear_type(EVENT_TYPE_SCRIPT, nil);
  scr_message_free;

  for type_ := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    scriptList := @scriptlists[type_];
    extent := scriptList^.head;
    while extent <> nil do
    begin
      next_ := extent^.next;
      mem_free(extent);
      extent := next_;
    end;

    scriptList^.head := nil;
    scriptList^.tail := nil;
    scriptList^.length := 0;
  end;

  scr_find_first_idx := 0;
  scr_find_first_ptr := nil;
  scr_find_first_elev := 0;
  map_script_id := -1;
  clearPrograms;
  exportClearAllVariables;

  Result := 0;
end;

function scr_find_first_at(elevation: Integer): PScript;
var
  script: PScript;
begin
  scr_find_first_elev := elevation;
  scr_find_first_idx := 0;
  scr_find_first_ptr := scriptlists[SCRIPT_TYPE_SPATIAL].head;

  if scr_find_first_ptr = nil then
  begin
    Result := nil;
    Exit;
  end;

  script := @scr_find_first_ptr^.scripts[0];
  if ((script^.scr_flags and SCRIPT_FLAG_0x02) <> 0) or (BuiltTileGetElevation(script^.u.sp.built_tile) <> elevation) then
    script := scr_find_next_at;

  Result := script;
end;

function scr_find_next_at: PScript;
var
  scriptListExtent: PScriptListExtent;
  scriptIndex: Integer;
  script: PScript;
begin
  scriptListExtent := scr_find_first_ptr;
  scriptIndex := scr_find_first_idx;

  if scriptListExtent = nil then
  begin
    Result := nil;
    Exit;
  end;

  while True do
  begin
    Inc(scriptIndex);

    if scriptIndex = SCRIPT_LIST_EXTENT_SIZE then
    begin
      scriptListExtent := scriptListExtent^.next;
      scriptIndex := 0;
    end
    else if scriptIndex >= scriptListExtent^.length then
      scriptListExtent := nil;

    if scriptListExtent = nil then
      Break;

    script := @scriptListExtent^.scripts[scriptIndex];
    if ((script^.scr_flags and SCRIPT_FLAG_0x02) = 0) and (BuiltTileGetElevation(script^.u.sp.built_tile) = scr_find_first_elev) then
      Break;
  end;

  if scriptListExtent <> nil then
    script := @scriptListExtent^.scripts[scriptIndex]
  else
    script := nil;

  scr_find_first_idx := scriptIndex;
  scr_find_first_ptr := scriptListExtent;

  Result := script;
end;

function scr_spatials_enabled: Boolean;
begin
  Result := scrSpatialsEnabled_;
end;

procedure scr_spatials_enable;
begin
  scrSpatialsEnabled_ := True;
end;

procedure scr_spatials_disable;
begin
  scrSpatialsEnabled_ := False;
end;

function scr_chk_spatials_in(obj: PObject; tile, elevation: Integer): Boolean;
var
  script: PScript;
  built_tile: Integer;
begin
  if obj = obj_mouse then
  begin
    Result := False;
    Exit;
  end;

  if obj = obj_mouse_flat then
  begin
    Result := False;
    Exit;
  end;

  if ((obj^.Flags and OBJECT_HIDDEN) <> 0) or ((obj^.Flags and OBJECT_FLAT) <> 0) then
  begin
    Result := False;
    Exit;
  end;

  if tile < 10 then
  begin
    Result := False;
    Exit;
  end;

  if not scr_spatials_enabled then
  begin
    Result := False;
    Exit;
  end;

  scr_spatials_disable;

  built_tile := BuiltTileCreate(tile, elevation);

  script := scr_find_first_at(elevation);
  while script <> nil do
  begin
    if built_tile = script^.u.sp.built_tile then
    begin
      scr_set_objs(script^.scr_id, obj, nil);
      exec_script_proc(script^.scr_id, SCRIPT_PROC_SPATIAL);
    end
    else
    begin
      if script^.u.sp.radius <> 0 then
      begin
        if tile_in_tile_bound(BuiltTileGetTile(script^.u.sp.built_tile), script^.u.sp.radius, tile) then
        begin
          scr_set_objs(script^.scr_id, obj, nil);
          exec_script_proc(script^.scr_id, SCRIPT_PROC_SPATIAL);
        end;
      end;
    end;

    script := scr_find_next_at;
  end;

  scr_spatials_enable;

  Result := True;
end;

function tile_in_tile_bound(tile1, radius, tile2: Integer): Boolean;
begin
  Result := tile_dist(tile1, tile2) <= radius;
end;

function scr_load_all_scripts: Integer;
var
  scriptListIndex, scriptIndex: Integer;
  extent: PScriptListExtent;
  script: PScript;
begin
  for scriptListIndex := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    extent := scriptlists[scriptListIndex].head;
    while extent <> nil do
    begin
      for scriptIndex := 0 to extent^.length - 1 do
      begin
        script := @extent^.scripts[scriptIndex];
        exec_script_proc(script^.scr_id, SCRIPT_PROC_START);
      end;
      extent := extent^.next;
    end;
  end;

  Result := 0;
end;

procedure scr_exec_map_enter_scripts;
var
  script_type, script_index, sid: Integer;
  script_list_extent: PScriptListExtent;
begin
  scr_spatials_disable;

  for script_type := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    script_list_extent := scriptlists[script_type].head;
    while script_list_extent <> nil do
    begin
      for script_index := 0 to script_list_extent^.length - 1 do
      begin
        if script_list_extent^.scripts[script_index].procs[SCRIPT_PROC_MAP_ENTER] > 0 then
        begin
          sid := script_list_extent^.scripts[script_index].scr_id;
          if sid <> map_script_id then
          begin
            if (map_data.flags and $1) = 0 then
              scr_set_ext_param(sid, 1)
            else
              scr_set_ext_param(sid, 0);
            exec_script_proc(sid, SCRIPT_PROC_MAP_ENTER);
          end;
        end;
      end;
      script_list_extent := script_list_extent^.next;
    end;
  end;

  scr_spatials_enable;
end;

procedure scr_exec_map_update_scripts;
var
  script_type, script_index, sid: Integer;
  script_list_extent: PScriptListExtent;
begin
  scr_spatials_disable;

  exec_script_proc(map_script_id, SCRIPT_PROC_MAP_UPDATE);

  for script_type := 0 to SCRIPT_TYPE_COUNT - 1 do
  begin
    script_list_extent := scriptlists[script_type].head;
    while script_list_extent <> nil do
    begin
      for script_index := 0 to script_list_extent^.length - 1 do
      begin
        if script_list_extent^.scripts[script_index].procs[SCRIPT_PROC_MAP_UPDATE] > 0 then
        begin
          sid := script_list_extent^.scripts[script_index].scr_id;
          if sid <> map_script_id then
            exec_script_proc(sid, SCRIPT_PROC_MAP_UPDATE);
        end;
      end;
      script_list_extent := script_list_extent^.next;
    end;
  end;

  scr_spatials_enable;
end;

procedure scr_exec_map_exit_scripts;
begin
  exec_script_proc(map_script_id, SCRIPT_PROC_MAP_EXIT);
end;

procedure scrExecMapProcScripts(a1: Integer);
begin
  // Stub - not fully implemented in original code
end;

function scr_get_dialog_msg_file(a1: Integer; messageListPtr: PPMessageList): Integer;
var
  messageListIndex: Integer;
  messageList_: PMessageList;
  scriptName: array[0..15] of AnsiChar;
  pch: PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if a1 = -1 then
  begin
    Result := -1;
    Exit;
  end;

  messageListIndex := a1 - 1;
  messageList_ := @script_dialog_msgs[messageListIndex];
  if messageList_^.entries_num = 0 then
  begin
    scr_list_str(messageListIndex, scriptName, SizeOf(scriptName));

    pch := StrRScan(scriptName, '.');
    if pch <> nil then
      pch^ := #0;

    StrLFmt(path, SizeOf(path) - 1, 'dialog\%s.msg', [scriptName]);

    if not message_load(messageList_, path) then
    begin
      debug_printf(#10'Error loading script dialog message file!');
      Result := -1;
      Exit;
    end;

    if not message_filter(messageList_) then
    begin
      debug_printf(#10'Error filtering script dialog message file!');
      Result := -1;
      Exit;
    end;
  end;

  messageListPtr^ := messageList_;
  Result := 0;
end;

function scr_get_msg_str(messageListId, messageId: Integer): PAnsiChar;
begin
  Result := scr_get_msg_str_speech(messageListId, messageId, 0);
end;

function scr_get_msg_str_speech(messageListId, messageId, a3: Integer): PAnsiChar;
var
  messageList_: PMessageList;
  messageListItem: TMessageListItem;
begin
  if (messageListId = 0) and (messageId = 0) then
  begin
    Result := @scr_get_msg_str_speech_blank_str[0];
    Exit;
  end;

  if (messageListId = -1) and (messageId = -1) then
  begin
    Result := @scr_get_msg_str_speech_blank_str[0];
    Exit;
  end;

  if (messageListId = -2) and (messageId = -2) then
  begin
    Result := getmsg(@proto_main_msg_file, @messageListItem, 650);
    Exit;
  end;

  if scr_get_dialog_msg_file(messageListId, @messageList_) = -1 then
  begin
    debug_printf(#10'ERROR: message_str: can''t find message file: List: %d!', [messageListId]);
    Result := nil;
    Exit;
  end;

  if FID_TYPE(dialogue_head) <> OBJ_TYPE_HEAD then
    a3 := 0;

  messageListItem.num := messageId;
  if not message_search(messageList_, @messageListItem) then
  begin
    debug_printf(#10'Error: can''t find message: List: %d, Num: %d!', [messageListId, messageId]);
    Result := @scr_get_msg_str_speech_err_str[0];
    Exit;
  end;

  if a3 <> 0 then
  begin
    if dialog_active then
    begin
      if (messageListItem.audio <> nil) and (messageListItem.audio[0] <> #0) then
        gdialog_setup_speech(messageListItem.audio)
      else
        debug_printf('Missing speech name: %d'#10, [messageListItem.num]);
    end;
  end;

  Result := messageListItem.text;
end;

function scr_get_local_var(sid, variable: Integer; var value: TProgramValue): Integer;
var
  script: PScript;
begin
  if SID_TYPE(sid) = SCRIPT_TYPE_SYSTEM then
  begin
    debug_printf(#10'Error! System scripts/Map scripts not allowed local_vars!'#10);
    value.opcode := VALUE_TYPE_INT;
    value.integerValue := -1;
    Result := -1;
    Exit;
  end;

  if scr_ptr(sid, @script) = -1 then
  begin
    value.opcode := VALUE_TYPE_INT;
    value.integerValue := -1;
    Result := -1;
    Exit;
  end;

  if script^.scr_num_local_vars = 0 then
    scr_find_str_run_info(script^.scr_script_idx, @script^.run_info_flags, sid);

  if script^.scr_num_local_vars > 0 then
  begin
    if script^.scr_local_var_offset = -1 then
      script^.scr_local_var_offset := map_malloc_local_var(script^.scr_num_local_vars);

    if map_get_local_var(script^.scr_local_var_offset + variable, value) = -1 then
    begin
      value.opcode := VALUE_TYPE_INT;
      value.integerValue := -1;
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

function scr_set_local_var(sid, variable: Integer; var value: TProgramValue): Integer;
var
  script: PScript;
begin
  if scr_ptr(sid, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if script^.scr_num_local_vars = 0 then
    scr_find_str_run_info(script^.scr_script_idx, @script^.run_info_flags, sid);

  if script^.scr_num_local_vars <= 0 then
  begin
    Result := -1;
    Exit;
  end;

  if script^.scr_local_var_offset = -1 then
    script^.scr_local_var_offset := map_malloc_local_var(script^.scr_num_local_vars);

  map_set_local_var(script^.scr_local_var_offset + variable, value);

  Result := 0;
end;

function scr_end_combat: Boolean;
var
  team: Integer;
  before_, after_: PScript;
begin
  if (map_script_id = 0) or (map_script_id = -1) then
  begin
    Result := False;
    Exit;
  end;

  team := combat_player_knocked_out_by;
  if team = -1 then
  begin
    Result := False;
    Exit;
  end;

  if scr_ptr(map_script_id, @before_) <> -1 then
    before_^.fixedParam := team;

  exec_script_proc(map_script_id, SCRIPT_PROC_COMBAT);

  Result := False;

  if scr_ptr(map_script_id, @after_) <> -1 then
  begin
    if after_^.scriptOverrides <> 0 then
      Result := True;
  end;
end;

function scr_explode_scenery(a1: PObject; tile, radius, elevation: Integer): Integer;
var
  scriptExtentsCount, scriptsCount, index_: Integer;
  scriptIds: PInteger;
  extent: PScriptListExtent;
  script: PScript;
  self_: PObject;
begin
  scriptExtentsCount := scriptlists[SCRIPT_TYPE_SPATIAL].length + scriptlists[SCRIPT_TYPE_ITEM].length;
  if scriptExtentsCount = 0 then
  begin
    Result := 0;
    Exit;
  end;

  scriptIds := PInteger(mem_malloc(SizeOf(Integer) * scriptExtentsCount * SCRIPT_LIST_EXTENT_SIZE));
  if scriptIds = nil then
  begin
    Result := -1;
    Exit;
  end;

  scriptsCount := 0;

  scr_spatials_disable;

  extent := scriptlists[SCRIPT_TYPE_ITEM].head;
  while extent <> nil do
  begin
    for index_ := 0 to extent^.length - 1 do
    begin
      script := @extent^.scripts[index_];
      if (script^.procs[SCRIPT_PROC_DAMAGE] <= 0) and (script^.program_ = nil) then
        exec_script_proc(script^.scr_id, SCRIPT_PROC_START);

      if script^.procs[SCRIPT_PROC_DAMAGE] > 0 then
      begin
        self_ := script^.owner;
        if self_ <> nil then
        begin
          if (self_^.Elevation = elevation) and (tile_dist(self_^.Tile, tile) <= radius) then
          begin
            PInteger(PByte(scriptIds) + scriptsCount * SizeOf(Integer))^ := script^.scr_id;
            Inc(scriptsCount);
          end;
        end;
      end;
    end;
    extent := extent^.next;
  end;

  extent := scriptlists[SCRIPT_TYPE_SPATIAL].head;
  while extent <> nil do
  begin
    for index_ := 0 to extent^.length - 1 do
    begin
      script := @extent^.scripts[index_];
      if (script^.procs[SCRIPT_PROC_DAMAGE] <= 0) and (script^.program_ = nil) then
        exec_script_proc(script^.scr_id, SCRIPT_PROC_START);

      if (script^.procs[SCRIPT_PROC_DAMAGE] > 0)
        and (BuiltTileGetElevation(script^.u.sp.built_tile) = elevation)
        and (tile_dist(BuiltTileGetTile(script^.u.sp.built_tile), tile) <= radius) then
      begin
        PInteger(PByte(scriptIds) + scriptsCount * SizeOf(Integer))^ := script^.scr_id;
        Inc(scriptsCount);
      end;
    end;
    extent := extent^.next;
  end;

  for index_ := 0 to scriptsCount - 1 do
    exec_script_proc(PInteger(PByte(scriptIds) + index_ * SizeOf(Integer))^, SCRIPT_PROC_DAMAGE);

  if scriptIds <> nil then
    mem_free(scriptIds);

  scr_spatials_enable;

  Result := 0;
end;

initialization
  StrCopy(script_path_base, 'scripts\');
  scr_get_msg_str_speech_err_str[0] := 'E';
  scr_get_msg_str_speech_err_str[1] := 'r';
  scr_get_msg_str_speech_err_str[2] := 'r';
  scr_get_msg_str_speech_err_str[3] := 'o';
  scr_get_msg_str_speech_err_str[4] := 'r';
  scr_get_msg_str_speech_err_str[5] := #0;
  scr_get_msg_str_speech_blank_str[0] := #0;
  InitProcTableStrs;

end.
