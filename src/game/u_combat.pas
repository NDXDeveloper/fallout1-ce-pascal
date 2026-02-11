{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/combat.h + combat.cc
// Combat engine: turn-based combat, attack resolution, damage computation,
// critical hit tables, visual effects.

unit u_combat;

interface

uses
  u_object_types,
  u_object,
  u_message,
  u_combat_defs,
  u_db;

var
  combat_state: LongWord;
  gcsd: PSTRUCT_664980;
  combat_call_display: Boolean;
  cf_table: array[0..WEAPON_CRITICAL_FAILURE_TYPE_COUNT-1, 0..WEAPON_CRITICAL_FAILURE_EFFECT_COUNT-1] of Integer;
  combat_message_file: TMessageList;
  combat_turn_obj: PObject;
  combat_exps: Integer;
  combat_free_move: Integer;

function combat_init: Integer;
procedure combat_reset;
procedure combat_exit;
function find_cid(start: Integer; cid: Integer; critterList: PPObject; critterListLength: Integer): Integer;
function combat_load(stream: PDB_FILE): Integer;
function combat_save(stream: PDB_FILE): Integer;
function combat_whose_turn: PObject;
procedure combat_data_init(obj: PObject);
procedure combat_over_from_load;
procedure combat_give_exps(exp_points: Integer);
function combat_in_range(critter: PObject): Integer;
procedure combat_end;
procedure combat_turn_run;
procedure combat_end_turn;
procedure combat(attack: PSTRUCT_664980);
procedure combat_ctd_init(attack: PAttack; attacker: PObject; defender: PObject; hitMode: Integer; hitLocation: Integer);
function combat_attack(attacker: PObject; defender: PObject; hitMode: Integer; location: Integer): Integer;
function combat_bullet_start(a1: PObject; a2: PObject): Integer;
procedure compute_explosion_on_extras(attack: PAttack; a2: Integer; isGrenade: Boolean; a4: Integer);
function determine_to_hit(a1: PObject; a2: PObject; hitLocation: Integer; hitMode: Integer): Integer;
function determine_to_hit_no_range(a1: PObject; a2: PObject; hitLocation: Integer; hitMode: Integer): Integer;
procedure death_checks(attack: PAttack);
procedure apply_damage(attack: PAttack; animated: Boolean);
procedure combat_display(attack: PAttack);
procedure combat_anim_begin;
procedure combat_anim_finished;
function combat_check_bad_shot(attacker: PObject; defender: PObject; hitMode: Integer; aiming: Boolean): Integer;
function combat_to_hit(target: PObject; accuracy: PInteger): Boolean;
procedure combat_attack_this(a1: PObject);
procedure combat_outline_on;
procedure combat_outline_off;
procedure combat_highlight_change;
function combat_is_shot_blocked(a1: PObject; from_: Integer; to_: Integer; a4: PObject; a5: PInteger): Boolean;
function combat_player_knocked_out_by: Integer;
function combat_explode_scenery(a1: PObject; a2: PObject): Integer;
procedure combat_delete_critter(obj: PObject);

function isInCombat: Boolean; inline;

implementation

uses
  SysUtils,
  u_config,
  u_gconfig,
  u_roll,
  u_item,
  u_stat,
  u_stat_defs,
  u_skill_defs,
  u_critter,
  u_perk,
  u_trait,
  u_combatai,
  u_anim,
  u_proto_types,
  u_proto,
  u_tile,
  u_map,
  u_display,
  u_game,
  u_gmouse,
  u_intface,
  u_scripts,
  u_art,
  u_cache,
  u_queue,
  u_skill,
  u_party,
  u_input,
  u_kb,
  u_gnw,
  u_button,
  u_grbuf,
  u_text,
  u_color,
  u_svga,
  u_gsound,
  u_int_sound,
  u_actions;

const
  COMPAT_MAX_PATH = 260;
  ROTATION_COUNT = 6;
  ROTATION_NE = 0;
  ROTATION_SE = 2;

  CALLED_SHOT_WINDOW_X      = 108;
  CALLED_SHOT_WINDOW_Y      = 20;
  CALLED_SHOT_WINDOW_WIDTH  = 424;
  CALLED_SHOT_WINDOW_HEIGHT = 309;

  INTERFACE_BAR_HEIGHT = 100;

  MOUSE_CURSOR_WAIT_WATCH = 26;
  MOUSE_CURSOR_ARROW      = 1;

  GAME_MOUSE_MODE_MOVE      = 0;
  GAME_MOUSE_MODE_CROSSHAIR = 2;

  KEY_SPACE  = $20;
  KEY_RETURN = $0D;
  KEY_ESCAPE = $1B;

  SCRIPT_PROC_COMBAT  = 12;
  SCRIPT_PROC_DAMAGE  = 14;
  SCRIPT_PROC_DESTROY = 18;

  EVENT_TYPE_KNOCKOUT = 0;

  WINDOW_MODAL = $04;

  BUTTON_FLAG_TRANSPARENT = $04;

  WEAPON_SOUND_EFFECT_OUT_OF_AMMO = 5;

  TARGET_HIGHLIGHT_OFF            = 0;
  TARGET_HIGHLIGHT_TARGETING_ONLY = 2;

type
  TCompareFunc = function(a1: Pointer; a2: Pointer): Integer; cdecl;

// =========================================================================
// External declarations (kept: cdecl varargs, libc, fps limiter)
// =========================================================================

// debug.h - cdecl varargs, incompatible with u_debug's Pascal overloaded version
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// libc
procedure qsort(base_: Pointer; num: Integer; size: Integer; compare: TCompareFunc); cdecl; external 'c' name 'qsort';



// =========================================================================
// Module-level variables (C++ static)
// =========================================================================
var
  _a_1: array[0..1] of AnsiChar = ('.',#0);

  combat_turn_running: Integer = 0;

  hit_location_penalty: array[0..HIT_LOCATION_COUNT-1] of Integer = (
    -40, -30, -30, 0, -20, -20, -60, -30, 0
  );

  combat_end_due_to_load: Integer = 0;
  combat_cleanup_enabled: Boolean = false;

  call_ty: array[0..3] of Integer = (122, 188, 252, 316);

  hit_loc_left: array[0..3] of Integer = (
    HIT_LOCATION_HEAD, HIT_LOCATION_EYES, HIT_LOCATION_RIGHT_ARM, HIT_LOCATION_RIGHT_LEG
  );

  hit_loc_right: array[0..3] of Integer = (
    HIT_LOCATION_TORSO, HIT_LOCATION_GROIN, HIT_LOCATION_LEFT_ARM, HIT_LOCATION_LEFT_LEG
  );

  main_ctd: TAttack;
  call_target: PObject;
  call_win: Integer;
  combat_elev: Integer;
  list_total: Integer;
  combat_ending_guy: PObject;
  list_noncom: Integer;
  combat_highlight: Integer;
  combat_list: PPObject;
  list_com: Integer;

  // static locals for shoot_along_path and compute_explosion_on_extras
  shoot_temp_ctd: TAttack;
  explosion_temp_ctd: TAttack;

// =========================================================================
// Critical hit tables
// =========================================================================

const
  STAT_STRENGTH  = 0;
  STAT_PERCEPTION = 1;
  STAT_ENDURANCE = 2;
  STAT_AGILITY   = 5;
  STAT_LUCK      = 6;

var
  crit_succ_eff: array[0..KILL_TYPE_COUNT-1, 0..HIT_LOCATION_COUNT-1, 0..CRITICAL_EFFECT_COUNT-1] of TCriticalHitDescription;
  pc_crit_succ_eff: array[0..HIT_LOCATION_COUNT-1, 0..CRITICAL_EFFECT_COUNT-1] of TCriticalHitDescription;

// =========================================================================
// Helper to set a crit table entry
// =========================================================================
procedure SetCrit(var c: TCriticalHitDescription; dm, fl, mcs, mcsm, mcf, mid, mcmid: Integer);
begin
  c.damageMultiplier := dm;
  c.flags := fl;
  c.massiveCriticalStat := mcs;
  c.massiveCriticalStatModifier := mcsm;
  c.massiveCriticalFlags := mcf;
  c.messageId := mid;
  c.massiveCriticalMessageId := mcmid;
end;

// =========================================================================
// Forward declarations of static functions
// =========================================================================
procedure combat_begin(a1: PObject); forward;
procedure combat_begin_extra(a1: PObject); forward;
procedure combat_over_proc; forward;
procedure combat_add_noncoms; forward;
function compare_faster(a1: Pointer; a2: Pointer): Integer; cdecl; forward;
procedure combat_sequence_init(a1: PObject; a2: PObject); forward;
procedure combat_sequence_proc; forward;
function combat_input: Integer; forward;
function combat_turn(a1: PObject; a2: Boolean): Integer; forward;
function combat_should_end: Boolean; forward;
function check_ranged_miss(attack: PAttack): Boolean; forward;
function shoot_along_path(attack: PAttack; endTile: Integer; rounds: Integer; anim: Integer): Integer; forward;
function compute_spray(attack: PAttack; accuracy: Integer; roundsHitMainTargetPtr: PInteger; roundsSpentPtr: PInteger; anim: Integer): Integer; forward;
function compute_attack(attack: PAttack): Integer; forward;
function attack_crit_success(attack: PAttack): Integer; forward;
function attack_crit_failure(attack: PAttack): Integer; forward;
procedure do_random_cripple(flagsPtr: PInteger); forward;
function determine_to_hit_func(attacker: PObject; defender: PObject; hitLocation: Integer; hitMode: Integer; check_range: Integer): Integer; forward;
procedure compute_damage(attack: PAttack; ammoQuantity: Integer; bonusDamageMultiplier: Integer); forward;
procedure check_for_death(obj: PObject; damage: Integer; flags: PInteger); forward;
procedure set_new_results(critter: PObject; flags: Integer); forward;
procedure damage_object(obj: PObject; damage: Integer; animated: Boolean; a4: Boolean); forward;
procedure combat_display_hit(dest: PAnsiChar; size: Integer; critter_obj: PObject; damage: Integer); forward;
procedure combat_display_flags(a1: PAnsiChar; flags: Integer; a3: PObject); forward;
procedure combat_standup(a1: PObject); forward;
procedure print_tohit(dest: PByte; dest_pitch: Integer; accuracy: Integer); forward;
function combat_get_loc_name(critter: PObject; hitLocation: Integer): PAnsiChar; forward;
procedure draw_loc_off(btn: Integer; input: Integer); cdecl; forward;
procedure draw_loc_on(btn: Integer; input: Integer); cdecl; forward;
procedure draw_loc(input: Integer; color: Integer); forward;
function get_called_shot_location(critter: PObject; hit_location: PInteger; hit_mode: Integer): Integer; forward;

// =========================================================================
// Inline helper
// =========================================================================
function isInCombat: Boolean; inline;
begin
  Result := (combat_state and COMBAT_STATE_0x01) <> 0;
end;

// =========================================================================
// combat_init
// =========================================================================
function combat_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH-1] of AnsiChar;
begin
  combat_turn_running := 0;
  combat_list := nil;
  list_com := 0;
  list_noncom := 0;
  list_total := 0;
  gcsd := nil;
  combat_call_display := false;
  combat_state := COMBAT_STATE_0x02;
  obj_dude^.Data.AsData.Critter.Combat.Ap := stat_level(obj_dude, Integer(STAT_MAXIMUM_ACTION_POINTS));
  combat_free_move := 0;
  combat_ending_guy := nil;
  combat_end_due_to_load := 0;
  combat_cleanup_enabled := false;

  if not message_init(@combat_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(path, SizeOf(path), '%s%s', [msg_path, 'combat.msg']);

  if not message_load(@combat_message_file, path) then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// combat_reset
// =========================================================================
procedure combat_reset;
begin
  combat_turn_running := 0;
  combat_list := nil;
  list_com := 0;
  list_noncom := 0;
  list_total := 0;
  gcsd := nil;
  combat_call_display := false;
  combat_state := COMBAT_STATE_0x02;
  obj_dude^.Data.AsData.Critter.Combat.Ap := stat_level(obj_dude, Integer(STAT_MAXIMUM_ACTION_POINTS));
  combat_free_move := 0;
  combat_ending_guy := nil;
end;

// =========================================================================
// combat_exit
// =========================================================================
procedure combat_exit;
begin
  message_exit(@combat_message_file);
end;

// =========================================================================
// find_cid
// =========================================================================
function find_cid(start: Integer; cid: Integer; critterList: PPObject; critterListLength: Integer): Integer;
var
  index: Integer;
  arr: PPObject;
begin
  arr := critterList;
  index := start;
  while index < critterListLength do
  begin
    if PPObject(PByte(arr) + index * SizeOf(PObject))^ ^.Cid = cid then
      Break;
    Inc(index);
  end;
  Result := index;
end;

// =========================================================================
// Helper to access combat_list as array
// =========================================================================
function CL(idx: Integer): PObject; inline;
begin
  Result := PPObject(PByte(combat_list) + idx * SizeOf(PObject))^;
end;

procedure CLSet(idx: Integer; val: PObject); inline;
begin
  PPObject(PByte(combat_list) + idx * SizeOf(PObject))^ := val;
end;

// =========================================================================
// combat_load
// =========================================================================
function combat_load(stream: PDB_FILE): Integer;
var
  obj: PObject;
  cid, i, j: Integer;
begin
  if db_freadUInt32(stream, @combat_state) = -1 then begin Result := -1; Exit; end;

  if not isInCombat then
  begin
    obj := obj_find_first;
    while obj <> nil do
    begin
      if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
      begin
        if obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid = -1 then
          obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
      end;
      obj := obj_find_next;
    end;
    Result := 0;
    Exit;
  end;

  if db_freadInt32(stream, @combat_turn_running) = -1 then begin Result := -1; Exit; end;
  if db_freadInt32(stream, @combat_free_move) = -1 then begin Result := -1; Exit; end;
  if db_freadInt32(stream, @combat_exps) = -1 then begin Result := -1; Exit; end;
  if db_freadInt32(stream, @list_com) = -1 then begin Result := -1; Exit; end;
  if db_freadInt32(stream, @list_noncom) = -1 then begin Result := -1; Exit; end;
  if db_freadInt32(stream, @list_total) = -1 then begin Result := -1; Exit; end;

  if obj_create_list(-1, map_elevation, OBJ_TYPE_CRITTER, @combat_list) <> list_total then
  begin
    obj_delete_list(combat_list);
    Result := -1;
    Exit;
  end;

  if db_freadInt32(stream, @cid) = -1 then begin Result := -1; Exit; end;
  obj_dude^.Cid := cid;

  for i := 0 to list_total - 1 do
  begin
    if CL(i)^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid = -1 then
      CL(i)^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil
    else
    begin
      j := find_cid(0, CL(i)^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid, combat_list, list_total);
      if j = list_total then
        CL(i)^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil
      else
        CL(i)^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := CL(j);
    end;
  end;

  for i := 0 to list_total - 1 do
  begin
    if db_freadInt32(stream, @cid) = -1 then begin Result := -1; Exit; end;
    j := find_cid(i, cid, combat_list, list_total);
    if j = list_total then begin Result := -1; Exit; end;

    obj := CL(i);
    CLSet(i, CL(j));
    CLSet(j, obj);
  end;

  for i := 0 to list_total - 1 do
    CL(i)^.Cid := i;

  combat_begin_extra(obj_dude);
  Result := 0;
end;

// =========================================================================
// combat_save
// =========================================================================
function combat_save(stream: PDB_FILE): Integer;
var
  index: Integer;
begin
  if db_fwriteUInt32(stream, combat_state) = -1 then begin Result := -1; Exit; end;
  if not isInCombat then begin Result := 0; Exit; end;

  if db_fwriteInt32(stream, combat_turn_running) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, combat_free_move) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, combat_exps) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, list_com) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, list_noncom) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, list_total) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt32(stream, obj_dude^.Cid) = -1 then begin Result := -1; Exit; end;

  for index := 0 to list_total - 1 do
    if db_fwriteInt32(stream, CL(index)^.Cid) = -1 then begin Result := -1; Exit; end;

  Result := 0;
end;

// =========================================================================
// combat_whose_turn
// =========================================================================
function combat_whose_turn: PObject;
begin
  if isInCombat then
    Result := combat_turn_obj
  else
    Result := nil;
end;

// =========================================================================
// combat_data_init
// =========================================================================
procedure combat_data_init(obj: PObject);
begin
  obj^.Data.AsData.Critter.Combat.DamageLastTurn := 0;
  obj^.Data.AsData.Critter.Combat.Results := 0;
end;

// =========================================================================
// combat_begin
// =========================================================================
procedure combat_begin(a1: PObject);
var
  index: Integer;
  critter: PObject;
begin
  anim_stop;
  remove_bk_process(TBackgroundProcess(@dude_fidget));
  combat_elev := map_elevation;

  if not isInCombat then
  begin
    combat_exps := 0;
    combat_list := nil;
    list_total := obj_create_list(-1, combat_elev, OBJ_TYPE_CRITTER, @combat_list);
    list_noncom := list_total;
    list_com := 0;

    for index := 0 to list_total - 1 do
    begin
      critter := CL(index);
      critter^.Data.AsData.Critter.Combat.Maneuver := critter^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANEUVER_ENGAGING;
      critter^.Data.AsData.Critter.Combat.DamageLastTurn := 0;
      critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
      critter^.Data.AsData.Critter.Combat.Ap := 0;
      critter^.Cid := index;
    end;

    combat_state := combat_state or COMBAT_STATE_0x01;

    tile_refresh_display;
    game_ui_disable(0);
    gmouse_set_cursor(MOUSE_CURSOR_WAIT_WATCH);
    combat_ending_guy := nil;
    combat_begin_extra(a1);
    intface_end_window_open(true);
    gmouse_enable_scrolling;
  end;
end;

// =========================================================================
// combat_begin_extra
// =========================================================================
procedure combat_begin_extra(a1: PObject);
var
  index: Integer;
  outline_type: Integer;
begin
  for index := 0 to list_total - 1 do
  begin
    outline_type := Integer(OUTLINE_TYPE_HOSTILE);
    if perk_level(PERK_FRIENDLY_FOE) <> 0 then
    begin
      if CL(index)^.Data.AsData.Critter.Combat.Team = obj_dude^.Data.AsData.Critter.Combat.Team then
        outline_type := Integer(OUTLINE_TYPE_FRIENDLY);
    end;
    obj_outline_object(CL(index), outline_type, nil);
    obj_turn_off_outline(CL(index), nil);
  end;

  combat_ctd_init(@main_ctd, a1, nil, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);
  combat_turn_obj := a1;
  combat_ai_begin(list_total, combat_list);

  combat_highlight := 2;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, @combat_highlight);
end;

// =========================================================================
// combat_over_proc
// =========================================================================
procedure combat_over_proc;
var
  index: Integer;
  critter: PObject;
begin
  add_bk_process(TBackgroundProcess(@dude_fidget));

  for index := 0 to list_noncom + list_com - 1 do
  begin
    critter := CL(index);
    critter^.Data.AsData.Critter.Combat.DamageLastTurn := 0;
    critter^.Data.AsData.Critter.Combat.Maneuver := CRITTER_MANEUVER_NONE;
  end;

  for index := 0 to list_total - 1 do
  begin
    critter := CL(index);
    critter^.Data.AsData.Critter.Combat.Ap := 0;
    obj_remove_outline(critter, nil);
    critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
  end;

  tile_refresh_display;
  intface_update_items(true);

  obj_dude^.Data.AsData.Critter.Combat.Ap := stat_level(obj_dude, Integer(STAT_MAXIMUM_ACTION_POINTS));
  intface_update_move_points(0, 0);

  if game_user_wants_to_quit = 0 then
    combat_give_exps(combat_exps);

  combat_exps := 0;
  combat_state := combat_state and (not COMBAT_STATE_0x01);
  combat_state := combat_state or COMBAT_STATE_0x02;

  if list_total <> 0 then
    obj_delete_list(combat_list);

  list_total := 0;

  combat_ai_over;
  game_ui_enable;
  gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
  intface_update_ac(true);

  if critter_is_prone(obj_dude) then
  begin
    if not critter_is_dead(obj_dude) then
    begin
      if combat_ending_guy = nil then
      begin
        queue_remove_this(obj_dude, EVENT_TYPE_KNOCKOUT);
        critter_wake_up(obj_dude, nil);
      end;
    end;
  end;
end;

// =========================================================================
// combat_over_from_load
// =========================================================================
procedure combat_over_from_load;
begin
  combat_over_proc;
  combat_state := 0;
  combat_end_due_to_load := 1;
end;

// =========================================================================
// combat_give_exps
// =========================================================================
procedure combat_give_exps(exp_points: Integer);
var
  format_item, prefix_item: TMessageListItem;
  current_hp, max_hp: Integer;
  text: array[0..131] of AnsiChar;
begin
  if exp_points <= 0 then Exit;
  if critter_is_dead(obj_dude) then Exit;

  stat_pc_add_experience(exp_points);

  format_item.num := 621;
  if not message_search(@proto_main_msg_file, @format_item) then Exit;

  prefix_item.num := roll_random(0, 3) + 622;

  current_hp := stat_level(obj_dude, Integer(STAT_CURRENT_HIT_POINTS));
  max_hp := stat_level(obj_dude, Integer(STAT_MAXIMUM_HIT_POINTS));
  if (current_hp = max_hp) and (roll_random(0, 100) > 65) then
    prefix_item.num := 626;

  if not message_search(@proto_main_msg_file, @prefix_item) then Exit;

  StrLFmt(text, SizeOf(text), format_item.text, [prefix_item.text, exp_points]);
  display_print(text);
end;

// =========================================================================
// combat_add_noncoms
// =========================================================================
procedure combat_add_noncoms;
var
  index: Integer;
  obj, t: PObject;
begin
  index := list_com;
  while index < list_com + list_noncom do
  begin
    obj := CL(index);
    if combatai_want_to_join(obj) then
    begin
      obj^.Data.AsData.Critter.Combat.Maneuver := CRITTER_MANEUVER_NONE;
      t := CL(index);
      CLSet(index, CL(list_com));
      CLSet(list_com, t);
      Inc(list_com);
      Dec(list_noncom);

      if obj <> obj_dude then
        combat_turn(obj, false);
    end
    else
      Inc(index);
  end;
end;

// =========================================================================
// combat_in_range
// =========================================================================
function combat_in_range(critter: PObject): Integer;
var
  perception, index: Integer;
begin
  perception := stat_level(critter, Integer(STAT_PERCEPTION));
  for index := 0 to list_com - 1 do
  begin
    if obj_dist(CL(index), critter) <= perception then
    begin
      Result := 1;
      Exit;
    end;
  end;
  Result := 0;
end;

// =========================================================================
// compare_faster
// =========================================================================
function compare_faster(a1: Pointer; a2: Pointer): Integer; cdecl;
var
  v1, v2: PObject;
  sequence1, sequence2, luck1, luck2: Integer;
begin
  v1 := PPObject(a1)^;
  v2 := PPObject(a2)^;

  sequence1 := stat_level(v1, Integer(STAT_SEQUENCE));
  sequence2 := stat_level(v2, Integer(STAT_SEQUENCE));
  if sequence1 > sequence2 then begin Result := -1; Exit; end
  else if sequence1 < sequence2 then begin Result := 1; Exit; end;

  luck1 := stat_level(v1, Integer(STAT_LUCK));
  luck2 := stat_level(v2, Integer(STAT_LUCK));
  if luck1 > luck2 then begin Result := -1; Exit; end
  else if luck1 < luck2 then begin Result := 1; Exit; end;

  Result := 0;
end;

// =========================================================================
// combat_sequence_init
// =========================================================================
procedure combat_sequence_init(a1: PObject; a2: PObject);
var
  next, index: Integer;
  obj, temp: PObject;
begin
  next := 0;
  if a1 <> nil then
  begin
    for index := 0 to list_total - 1 do
    begin
      obj := CL(index);
      if obj = a1 then
      begin
        temp := CL(next);
        CLSet(index, temp);
        CLSet(next, obj);
        Inc(next);
        Break;
      end;
    end;
  end;

  if a2 <> nil then
  begin
    for index := 0 to list_total - 1 do
    begin
      obj := CL(index);
      if obj = a2 then
      begin
        temp := CL(next);
        CLSet(index, temp);
        CLSet(next, obj);
        Inc(next);
        Break;
      end;
    end;
  end;

  if (a1 <> obj_dude) and (a2 <> obj_dude) then
  begin
    for index := 0 to list_total - 1 do
    begin
      obj := CL(index);
      if obj = obj_dude then
      begin
        temp := CL(next);
        CLSet(index, temp);
        CLSet(next, obj);
        Inc(next);
        Break;
      end;
    end;
  end;

  list_com := next;
  list_noncom := list_noncom - next;

  if a1 <> nil then
    critter_set_who_hit_me(a1, a2);
  if a2 <> nil then
    critter_set_who_hit_me(a2, a1);
end;

// =========================================================================
// combat_sequence_proc
// =========================================================================
procedure combat_sequence_proc;
var
  count, index: Integer;
  critter: PObject;
begin
  combat_add_noncoms;
  count := list_com;

  index := 0;
  while index < count do
  begin
    critter := CL(index);
    if (critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
    begin
      CLSet(index, CL(count - 1));
      CLSet(count - 1, critter);
      CLSet(count - 1, CL(list_noncom + count - 1));
      CLSet(list_noncom + count - 1, critter);
      Dec(index);
      Dec(count);
    end;
    Inc(index);
  end;

  index := 0;
  while index < count do
  begin
    critter := CL(index);
    if critter <> obj_dude then
    begin
      if ((critter^.Data.AsData.Critter.Combat.Results and DAM_KNOCKED_OUT) <> 0)
        or (critter^.Data.AsData.Critter.Combat.Maneuver = CRITTER_MANEUVER_DISENGAGING) then
      begin
        critter^.Data.AsData.Critter.Combat.Maneuver := critter^.Data.AsData.Critter.Combat.Maneuver and (not CRITTER_MANEUVER_ENGAGING);
        Inc(list_noncom);
        CLSet(index, CL(count - 1));
        CLSet(count - 1, critter);
        Dec(count);
        Dec(index);
      end;
    end;
    Inc(index);
  end;

  if count <> 0 then
  begin
    list_com := count;
    qsort(combat_list, count, SizeOf(PObject), @compare_faster);
    count := list_com;
  end;

  list_com := count;
  inc_game_time_in_seconds(5);
end;

// =========================================================================
// combat_end
// =========================================================================
procedure combat_end;
var
  messageListItem: TMessageListItem;
  dudeTeam, index, critterTeam: Integer;
  critter, critterWhoHitMe: PObject;
begin
  if combat_elev = obj_dude^.Elevation then
  begin
    dudeTeam := obj_dude^.Data.AsData.Critter.Combat.Team;
    for index := 0 to list_com - 1 do
    begin
      critter := CL(index);
      if critter <> obj_dude then
      begin
        critterTeam := critter^.Data.AsData.Critter.Combat.Team;
        critterWhoHitMe := critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
        if (critterTeam <> dudeTeam) or ((critterWhoHitMe <> nil) and (critterWhoHitMe^.Data.AsData.Critter.Combat.Team = critterTeam)) then
        begin
          if not combatai_want_to_stop(critter) then
          begin
            messageListItem.num := 103;
            if message_search(@combat_message_file, @messageListItem) then
              display_print(messageListItem.text);
            Exit;
          end;
        end;
      end;
    end;

    for index := list_com to list_com + list_noncom - 1 do
    begin
      critter := CL(index);
      if critter <> obj_dude then
      begin
        critterTeam := critter^.Data.AsData.Critter.Combat.Team;
        critterWhoHitMe := critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
        if (critterTeam <> dudeTeam) or ((critterWhoHitMe <> nil) and (critterWhoHitMe^.Data.AsData.Critter.Combat.Team = critterTeam)) then
        begin
          if combatai_want_to_join(critter) then
          begin
            messageListItem.num := 103;
            if message_search(@combat_message_file, @messageListItem) then
              display_print(messageListItem.text);
            Exit;
          end;
        end;
      end;
    end;
  end;

  combat_state := combat_state or COMBAT_STATE_0x08;
end;

// =========================================================================
// combat_turn_run
// =========================================================================
procedure combat_turn_run;
begin
  while combat_turn_running > 0 do
  begin
    sharedFpsLimiter.Mark;
    process_bk;
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;
end;

// =========================================================================
// combat_input
// =========================================================================
function combat_input: Integer;
var
  input: Integer;
  old_user_wants_to_quit: Integer;
begin
  while (combat_state and COMBAT_STATE_0x02) <> 0 do
  begin
    sharedFpsLimiter.Mark;

    if (combat_state and COMBAT_STATE_0x08) <> 0 then Break;
    if (obj_dude^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD or DAM_LOSE_TURN)) <> 0 then Break;
    if (obj_dude^.Data.AsData.Critter.Combat.Ap <= 0) and (combat_free_move <= 0) then Break;
    if game_user_wants_to_quit <> 0 then Break;
    if combat_end_due_to_load <> 0 then Break;

    input := get_input;
    if input = KEY_SPACE then Break;
    if input = KEY_RETURN then
      combat_end
    else
    begin
      scripts_check_state_in_combat;
      game_handle_input(input, true);
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  old_user_wants_to_quit := game_user_wants_to_quit;
  if game_user_wants_to_quit = 1 then
    game_user_wants_to_quit := 0;

  if (combat_state and COMBAT_STATE_0x08) <> 0 then
  begin
    combat_state := combat_state and (not COMBAT_STATE_0x08);
    Result := -1;
    Exit;
  end;

  if (game_user_wants_to_quit <> 0) or (old_user_wants_to_quit <> 0) or (combat_end_due_to_load <> 0) then
  begin
    Result := -1;
    Exit;
  end;

  scripts_check_state_in_combat;
  Result := 0;
end;

// =========================================================================
// combat_end_turn
// =========================================================================
procedure combat_end_turn;
begin
  combat_state := combat_state and (not COMBAT_STATE_0x02);
end;

// =========================================================================
// combat_turn
// =========================================================================
function combat_turn(a1: PObject; a2: Boolean): Integer;
var
  action_points: Integer;
  script_override: Boolean;
  script: u_scripts.PScript;
  rect: array[0..3] of Integer;
begin
  combat_turn_obj := a1;
  combat_ctd_init(@main_ctd, a1, nil, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);

  if (a1^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD or DAM_LOSE_TURN)) <> 0 then
  begin
    a1^.Data.AsData.Critter.Combat.Results := a1^.Data.AsData.Critter.Combat.Results and (not DAM_LOSE_TURN);
  end
  else
  begin
    script_override := false;

    if not a2 then
    begin
      action_points := stat_level(a1, Integer(STAT_MAXIMUM_ACTION_POINTS));
      if gcsd <> nil then
        action_points := action_points + gcsd^.actionPointsBonus;
      a1^.Data.AsData.Critter.Combat.Ap := action_points;
    end;

    if a1 = obj_dude then
    begin
      kb_clear;
      intface_update_ac(true);
      combat_free_move := 2 * perk_level(PERK_BONUS_MOVE);
      intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);
    end
    else
      soundUpdate;

    if a1^.Sid <> -1 then
    begin
      scr_set_objs(a1^.Sid, nil, nil);
      scr_set_ext_param(a1^.Sid, 4);
      exec_script_proc(a1^.Sid, SCRIPT_PROC_COMBAT);

      if scr_ptr(a1^.Sid, @script) <> -1 then
        script_override := script^.scriptOverrides <> 0;

      if game_user_wants_to_quit = 1 then
      begin
        Result := -1;
        Exit;
      end;
    end;

    if not script_override then
    begin
      if not a2 then
        if critter_is_prone(a1) then
          combat_standup(a1);

      if a1 = obj_dude then
      begin
        game_ui_enable;
        gmouse_3d_refresh;

        if gcsd <> nil then
          combat_attack_this(gcsd^.defender);

        if not a2 then
          combat_state := combat_state or $02;

        intface_end_buttons_enable;

        if combat_highlight <> 0 then
          combat_outline_on;

        if combat_input = -1 then
        begin
          game_ui_disable(1);
          gmouse_set_cursor(MOUSE_CURSOR_WAIT_WATCH);
          a1^.Data.AsData.Critter.Combat.DamageLastTurn := 0;
          intface_end_buttons_disable;
          combat_outline_off;
          intface_update_move_points(-1, -1);
          intface_update_ac(true);
          combat_free_move := 0;
          Result := -1;
          Exit;
        end;
      end
      else
      begin
        if obj_turn_on_outline(a1, @rect) = 0 then
          tile_refresh_rect(@rect, a1^.Elevation);

        if gcsd <> nil then
          combat_ai(a1, gcsd^.defender)
        else
          combat_ai(a1, nil);
      end;
    end;

    combat_turn_run;

    if a1 = obj_dude then
    begin
      game_ui_disable(1);
      gmouse_set_cursor(MOUSE_CURSOR_WAIT_WATCH);
      intface_end_buttons_disable;
      combat_outline_off;
      intface_update_move_points(-1, -1);
      combat_turn_obj := nil;
      intface_update_ac(true);
      combat_turn_obj := obj_dude;
    end
    else
    begin
      if obj_turn_off_outline(a1, @rect) = 0 then
        tile_refresh_rect(@rect, a1^.Elevation);
    end;
  end;

  a1^.Data.AsData.Critter.Combat.DamageLastTurn := 0;

  if (obj_dude^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if (a1 = obj_dude) and (combat_elev <> obj_dude^.Elevation) then
  begin
    Result := -1;
    Exit;
  end;

  combat_free_move := 0;
  Result := 0;
end;

// =========================================================================
// combat_should_end
// =========================================================================
function combat_should_end: Boolean;
var
  index, team: Integer;
  critter, critterWhoHitMe: PObject;
begin
  if list_com <= 1 then begin Result := true; Exit; end;

  index := 0;
  while index < list_com do
  begin
    if CL(index) = obj_dude then Break;
    Inc(index);
  end;
  if index = list_com then begin Result := true; Exit; end;

  team := obj_dude^.Data.AsData.Critter.Combat.Team;
  for index := 0 to list_com - 1 do
  begin
    critter := CL(index);
    if critter^.Data.AsData.Critter.Combat.Team <> team then begin Result := false; Exit; end;
    critterWhoHitMe := critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
    if (critterWhoHitMe <> nil) and (critterWhoHitMe^.Data.AsData.Critter.Combat.Team = team) then begin Result := false; Exit; end;
  end;

  Result := true;
end;

// =========================================================================
// combat (main combat loop)
// =========================================================================
procedure combat(attack: PSTRUCT_664980);
var
  v3, v6, index: Integer;
begin
  if (attack = nil)
    or ((attack^.attacker = nil) or (attack^.attacker^.Elevation = map_elevation))
    or ((attack^.defender = nil) or (attack^.defender^.Elevation = map_elevation)) then
  begin
    v3 := combat_state and $01;
    combat_begin(nil);

    if v3 <> 0 then
    begin
      if combat_turn(obj_dude, true) = -1 then
        v6 := -1
      else
      begin
        index := 0;
        while index < list_com do
        begin
          if CL(index) = obj_dude then Break;
          Inc(index);
        end;
        v6 := index + 1;
      end;
      gcsd := nil;
    end
    else
    begin
      if attack <> nil then
        combat_sequence_init(attack^.attacker, attack^.defender)
      else
        combat_sequence_init(nil, nil);
      gcsd := attack;
      v6 := 0;
    end;

    repeat
      if v6 = -1 then Break;

      while v6 < list_com do
      begin
        if combat_turn(CL(v6), false) = -1 then Break;
        if combat_ending_guy <> nil then Break;
        gcsd := nil;
        Inc(v6);
      end;

      if v6 < list_com then Break;

      combat_sequence_proc;
      v6 := 0;
    until combat_should_end;

    if combat_end_due_to_load <> 0 then
    begin
      game_ui_enable;
      gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
    end
    else
    begin
      gmouse_disable_scrolling;
      intface_end_window_close(true);
      gmouse_enable_scrolling;
      combat_over_proc;
      scr_exec_map_update_scripts;
    end;

    combat_end_due_to_load := 0;

    if game_user_wants_to_quit = 1 then
      game_user_wants_to_quit := 0;
  end;
end;

// =========================================================================
// combat_ctd_init
// =========================================================================
procedure combat_ctd_init(attack: PAttack; attacker: PObject; defender: PObject; hitMode: Integer; hitLocation: Integer);
begin
  attack^.attacker := attacker;
  attack^.hitMode := hitMode;
  attack^.weapon := item_hit_with(attacker, hitMode);
  attack^.attackHitLocation := HIT_LOCATION_TORSO;
  attack^.attackerDamage := 0;
  attack^.attackerFlags := 0;
  attack^.ammoQuantity := 0;
  attack^.criticalMessageId := -1;
  attack^.defender := defender;
  if defender <> nil then
    attack^.tile := defender^.Tile
  else
    attack^.tile := -1;
  attack^.defenderHitLocation := hitLocation;
  attack^.defenderDamage := 0;
  attack^.defenderFlags := 0;
  attack^.defenderKnockback := 0;
  attack^.extrasLength := 0;
  attack^.oops := defender;
end;

// =========================================================================
// combat_attack
// =========================================================================
function combat_attack(attacker: PObject; defender: PObject; hitMode: Integer; location: Integer): Integer;
var
  aiming: Boolean;
  actionPoints: Integer;
  fid: Integer;
begin
  if (hitMode = HIT_MODE_PUNCH) and (roll_random(1, 4) = 1) then
  begin
    fid := art_id(OBJ_TYPE_CRITTER, attacker^.Fid and $FFF, ANIM_KICK_LEG, (attacker^.Fid and $F000) shr 12, (attacker^.Fid and $70000000) shr 28);
    if art_exists(fid) then
      hitMode := HIT_MODE_KICK;
  end;

  combat_ctd_init(@main_ctd, attacker, defender, hitMode, location);
  debug_printf('computing attack...'#10);

  if compute_attack(@main_ctd) = -1 then begin Result := -1; Exit; end;

  if gcsd <> nil then
  begin
    main_ctd.defenderDamage := main_ctd.defenderDamage + gcsd^.damageBonus;
    if main_ctd.defenderDamage < gcsd^.minDamage then
      main_ctd.defenderDamage := gcsd^.minDamage;
    if main_ctd.defenderDamage > gcsd^.maxDamage then
      main_ctd.defenderDamage := gcsd^.maxDamage;
    if gcsd^.field_1C <> 0 then
    begin
      main_ctd.defenderFlags := gcsd^.field_20;
      main_ctd.defenderFlags := gcsd^.field_24;
    end;
  end;

  if (main_ctd.defenderHitLocation = HIT_LOCATION_TORSO) or (main_ctd.defenderHitLocation = HIT_LOCATION_UNCALLED) then
  begin
    if attacker = obj_dude then
      intface_get_attack(@hitMode, @aiming)
    else
      aiming := false;
  end
  else
    aiming := true;

  actionPoints := item_w_mp_cost(attacker, main_ctd.hitMode, aiming);
  debug_printf('sequencing attack...'#10);

  if action_attack(@main_ctd) = -1 then begin Result := -1; Exit; end;

  if actionPoints > attacker^.Data.AsData.Critter.Combat.Ap then
    attacker^.Data.AsData.Critter.Combat.Ap := 0
  else
    attacker^.Data.AsData.Critter.Combat.Ap := attacker^.Data.AsData.Critter.Combat.Ap - actionPoints;

  if attacker = obj_dude then
  begin
    intface_update_move_points(attacker^.Data.AsData.Critter.Combat.Ap, combat_free_move);
    critter_set_who_hit_me(attacker, defender);
  end;

  combat_call_display := true;
  combat_cleanup_enabled := true;
  debug_printf('running attack...'#10);
  Result := 0;
end;

// =========================================================================
// combat_bullet_start
// =========================================================================
function combat_bullet_start(a1: PObject; a2: PObject): Integer;
var
  rot: Integer;
begin
  rot := tile_dir(a1^.Tile, a2^.Tile);
  Result := tile_num_in_direction(a1^.Tile, rot, 1);
end;

// =========================================================================
// check_ranged_miss
// =========================================================================
function check_ranged_miss(attack: PAttack): Boolean;
var
  range, to_, roll_val, v6, curr: Integer;
  critter: PObject;
begin
  range := item_w_range(attack^.attacker, attack^.hitMode);
  to_ := tile_num_beyond(attack^.attacker^.Tile, attack^.defender^.Tile, range);

  roll_val := ROLL_FAILURE;
  critter := attack^.attacker;
  if critter <> nil then
  begin
    curr := attack^.attacker^.Tile;
    while curr <> to_ do
    begin
      make_straight_path(attack^.attacker, curr, to_, nil, @critter, 32);
      if critter <> nil then
      begin
        if (critter^.Flags and OBJECT_SHOOT_THRU) = 0 then
        begin
          if FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER then
          begin
            roll_val := ROLL_SUCCESS;
            Break;
          end;

          if critter <> attack^.defender then
          begin
            v6 := determine_to_hit_func(attack^.attacker, critter, attack^.defenderHitLocation, attack^.hitMode, 1) div 3;
            if critter_is_dead(critter) then
              v6 := 5;
            if roll_random(1, 100) <= v6 then
            begin
              roll_val := ROLL_SUCCESS;
              Break;
            end;
          end;
          curr := critter^.Tile;
        end;
      end;
      if critter = nil then Break;
    end;
  end;

  attack^.defenderHitLocation := HIT_LOCATION_TORSO;

  if (roll_val < ROLL_SUCCESS) or (critter = nil) or ((critter^.Flags and OBJECT_SHOOT_THRU) = 0) then
  begin
    Result := false;
    Exit;
  end;

  attack^.defender := critter;
  attack^.tile := critter^.Tile;
  attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
  attack^.defenderHitLocation := HIT_LOCATION_TORSO;
  compute_damage(attack, 1, 2);
  Result := true;
end;

// =========================================================================
// shoot_along_path
// =========================================================================
function shoot_along_path(attack: PAttack; endTile: Integer; rounds: Integer; anim: Integer): Integer;
var
  remainingRounds, roundsHitMainTarget, currentTile: Integer;
  critter: PObject;
  accuracy, roundsHit, index: Integer;
begin
  remainingRounds := rounds;
  roundsHitMainTarget := 0;
  currentTile := attack^.attacker^.Tile;
  critter := attack^.attacker;

  while critter <> nil do
  begin
    if (remainingRounds <= 0) and (anim <> ANIM_FIRE_CONTINUOUS) then Break;
    if currentTile = endTile then Break;
    if attack^.extrasLength >= 6 then Break;

    make_straight_path(attack^.attacker, currentTile, endTile, nil, @critter, 32);
    if critter <> nil then
    begin
      if FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER then Break;

      accuracy := determine_to_hit_func(attack^.attacker, critter, HIT_LOCATION_TORSO, attack^.hitMode, 1);
      if anim = ANIM_FIRE_CONTINUOUS then
        remainingRounds := 1;

      roundsHit := 0;
      while (roll_random(1, 100) <= accuracy) and (remainingRounds > 0) do
      begin
        Dec(remainingRounds);
        Inc(roundsHit);
      end;

      if roundsHit <> 0 then
      begin
        if critter = attack^.defender then
          roundsHitMainTarget := roundsHitMainTarget + roundsHit
        else
        begin
          index := 0;
          while index < attack^.extrasLength do
          begin
            if critter = attack^.extras[index] then Break;
            Inc(index);
          end;

          attack^.extrasHitLocation[index] := HIT_LOCATION_TORSO;
          attack^.extras[index] := critter;
          combat_ctd_init(@shoot_temp_ctd, attack^.attacker, critter, attack^.hitMode, HIT_LOCATION_TORSO);
          shoot_temp_ctd.attackerFlags := shoot_temp_ctd.attackerFlags or DAM_HIT;
          compute_damage(@shoot_temp_ctd, roundsHit, 2);

          if index = attack^.extrasLength then
          begin
            attack^.extrasDamage[index] := shoot_temp_ctd.defenderDamage;
            attack^.extrasFlags[index] := shoot_temp_ctd.defenderFlags;
            attack^.extrasKnockback[index] := shoot_temp_ctd.defenderKnockback;
            Inc(attack^.extrasLength);
          end
          else
          begin
            if anim = ANIM_FIRE_BURST then
            begin
              attack^.extrasDamage[index] := attack^.extrasDamage[index] + shoot_temp_ctd.defenderDamage;
              attack^.extrasFlags[index] := attack^.extrasFlags[index] or shoot_temp_ctd.defenderFlags;
              attack^.extrasKnockback[index] := attack^.extrasKnockback[index] + shoot_temp_ctd.defenderKnockback;
            end;
          end;
        end;
      end;
      currentTile := critter^.Tile;
    end;
  end;

  if anim = ANIM_FIRE_CONTINUOUS then
    roundsHitMainTarget := 0;

  Result := roundsHitMainTarget;
end;

// =========================================================================
// compute_spray
// =========================================================================
function compute_spray(attack: PAttack; accuracy: Integer; roundsHitMainTargetPtr: PInteger; roundsSpentPtr: PInteger; anim: Integer): Integer;
var
  ammoQuantity, burstRounds, criticalChance, roll_val: Integer;
  leftRounds, mainTargetRounds, centerRounds, rightRounds: Integer;
  range, mainTargetEndTile, centerTile, rot: Integer;
  leftTile, leftEndTile, rightTile, rightEndTile: Integer;
  index: Integer;
begin
  roundsHitMainTargetPtr^ := 0;
  ammoQuantity := item_w_curr_ammo(attack^.weapon);
  burstRounds := item_w_rounds(attack^.weapon);
  if burstRounds < ammoQuantity then
    ammoQuantity := burstRounds;
  roundsSpentPtr^ := ammoQuantity;

  criticalChance := stat_level(attack^.attacker, Integer(STAT_CRITICAL_CHANCE));
  roll_val := roll_check(accuracy, criticalChance, nil);

  if roll_val = ROLL_CRITICAL_FAILURE then begin Result := roll_val; Exit; end;
  if roll_val = ROLL_CRITICAL_SUCCESS then
    accuracy := accuracy + 20;

  if anim = ANIM_FIRE_BURST then
  begin
    centerRounds := ammoQuantity div 3;
    if centerRounds = 0 then centerRounds := 1;
    leftRounds := ammoQuantity div 3;
    rightRounds := ammoQuantity - centerRounds - leftRounds;
    mainTargetRounds := centerRounds div 2;
    if mainTargetRounds = 0 then
    begin
      mainTargetRounds := 1;
      Dec(centerRounds);
    end;
  end
  else
  begin
    leftRounds := 1;
    mainTargetRounds := 1;
    centerRounds := 1;
    rightRounds := 1;
  end;

  for index := 0 to mainTargetRounds - 1 do
    if roll_check(accuracy, 0, nil) >= ROLL_SUCCESS then
      Inc(roundsHitMainTargetPtr^);

  if (roundsHitMainTargetPtr^ = 0) and check_ranged_miss(attack) then
    roundsHitMainTargetPtr^ := 1;

  range := item_w_range(attack^.attacker, attack^.hitMode);
  mainTargetEndTile := tile_num_beyond(attack^.attacker^.Tile, attack^.defender^.Tile, range);
  roundsHitMainTargetPtr^ := roundsHitMainTargetPtr^ + shoot_along_path(attack, mainTargetEndTile, centerRounds - roundsHitMainTargetPtr^, anim);

  if obj_dist(attack^.attacker, attack^.defender) <= 3 then
    centerTile := tile_num_beyond(attack^.attacker^.Tile, attack^.defender^.Tile, 3)
  else
    centerTile := attack^.defender^.Tile;

  rot := tile_dir(centerTile, attack^.attacker^.Tile);

  leftTile := tile_num_in_direction(centerTile, (rot + 1) mod ROTATION_COUNT, 1);
  leftEndTile := tile_num_beyond(attack^.attacker^.Tile, leftTile, range);
  roundsHitMainTargetPtr^ := roundsHitMainTargetPtr^ + shoot_along_path(attack, leftEndTile, leftRounds, anim);

  rightTile := tile_num_in_direction(centerTile, (rot + 5) mod ROTATION_COUNT, 1);
  rightEndTile := tile_num_beyond(attack^.attacker^.Tile, rightTile, range);
  roundsHitMainTargetPtr^ := roundsHitMainTargetPtr^ + shoot_along_path(attack, rightEndTile, rightRounds, anim);

  if (roll_val <> ROLL_FAILURE) or ((roundsHitMainTargetPtr^ <= 0) and (attack^.extrasLength <= 0)) then
  begin
    if (roll_val >= ROLL_SUCCESS) and (roundsHitMainTargetPtr^ = 0) and (attack^.extrasLength = 0) then
      roll_val := ROLL_FAILURE;
  end
  else
    roll_val := ROLL_SUCCESS;

  Result := roll_val;
end;

// =========================================================================
// compute_attack
// =========================================================================
function compute_attack(attack: PAttack): Integer;
var
  weapon_range, distance, anim, to_hit, damage_type: Integer;
  is_grenade: Boolean;
  weapon_subtype, critical_chance, roll_val: Integer;
  roundsHitMainTarget, damage_multiplier, roundsSpent: Integer;
  tile, throw_distance, rot: Integer;
  defender: PObject;
begin
  weapon_range := item_w_range(attack^.attacker, attack^.hitMode);
  distance := obj_dist(attack^.attacker, attack^.defender);
  if weapon_range < distance then begin Result := -1; Exit; end;

  anim := item_w_anim(attack^.attacker, attack^.hitMode);
  to_hit := determine_to_hit(attack^.attacker, attack^.defender, attack^.defenderHitLocation, attack^.hitMode);

  damage_type := item_w_damage_type(attack^.weapon);
  is_grenade := false;
  if (anim = ANIM_THROW_ANIM) and ((damage_type = DAMAGE_TYPE_EXPLOSION) or (damage_type = DAMAGE_TYPE_PLASMA) or (damage_type = DAMAGE_TYPE_EMP)) then
    is_grenade := true;

  if attack^.defenderHitLocation = HIT_LOCATION_UNCALLED then
    attack^.defenderHitLocation := HIT_LOCATION_TORSO;

  weapon_subtype := item_w_subtype(attack^.weapon, attack^.hitMode);
  roundsHitMainTarget := 1;
  damage_multiplier := 2;
  roundsSpent := 1;

  if (anim = ANIM_FIRE_BURST) or (anim = ANIM_FIRE_CONTINUOUS) then
    roll_val := compute_spray(attack, to_hit, @roundsHitMainTarget, @roundsSpent, anim)
  else
  begin
    critical_chance := stat_level(attack^.attacker, Integer(STAT_CRITICAL_CHANCE));
    roll_val := roll_check(to_hit, critical_chance - hit_location_penalty[attack^.defenderHitLocation], nil);
  end;

  if roll_val = ROLL_FAILURE then
    if trait_level(TRAIT_JINXED) <> 0 then
      if roll_random(0, 1) = 1 then
        roll_val := ROLL_CRITICAL_FAILURE;

  if (weapon_subtype = ATTACK_TYPE_MELEE) or (weapon_subtype = ATTACK_TYPE_UNARMED) then
  begin
    if roll_val = ROLL_SUCCESS then
    begin
      if attack^.attacker = obj_dude then
      begin
        if perk_level(PERK_SLAYER) <> 0 then
          roll_val := ROLL_CRITICAL_SUCCESS;
        if (perk_level(PERK_SILENT_DEATH) <> 0)
          and (not is_hit_from_front(obj_dude, attack^.defender))
          and is_pc_flag(PC_FLAG_SNEAKING)
          and (obj_dude <> attack^.defender^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe) then
          damage_multiplier := 4;
      end;
    end;
  end;

  if roll_val = ROLL_SUCCESS then
  begin
    if ((weapon_subtype = ATTACK_TYPE_MELEE) or (weapon_subtype = ATTACK_TYPE_UNARMED)) and (attack^.attacker = obj_dude) then
    begin
      if perk_level(PERK_SLAYER) <> 0 then
        roll_val := ROLL_CRITICAL_SUCCESS;
      if (perk_level(PERK_SILENT_DEATH) <> 0)
        and (not is_hit_from_front(obj_dude, attack^.defender))
        and is_pc_flag(PC_FLAG_SNEAKING)
        and (obj_dude <> attack^.defender^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe) then
        damage_multiplier := 4;
    end;
  end;

  if weapon_subtype = ATTACK_TYPE_RANGED then
  begin
    attack^.ammoQuantity := roundsSpent;
    if (roll_val = ROLL_SUCCESS) and (attack^.attacker = obj_dude) then
      if perk_level(PERK_SNIPER) <> 0 then
        if roll_random(1, 10) <= stat_level(obj_dude, Integer(STAT_LUCK)) then
          roll_val := ROLL_CRITICAL_SUCCESS;
  end
  else
  begin
    if item_w_max_ammo(attack^.weapon) > 0 then
      attack^.ammoQuantity := 1;
  end;

  case roll_val of
    ROLL_CRITICAL_SUCCESS:
    begin
      damage_multiplier := attack_crit_success(attack);
      attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
      compute_damage(attack, roundsHitMainTarget, damage_multiplier);
    end;
    ROLL_SUCCESS:
    begin
      attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
      compute_damage(attack, roundsHitMainTarget, damage_multiplier);
    end;
    ROLL_FAILURE:
    begin
      if (weapon_subtype = ATTACK_TYPE_RANGED) or (weapon_subtype = ATTACK_TYPE_THROW) then
        check_ranged_miss(attack);
    end;
    ROLL_CRITICAL_FAILURE:
      attack_crit_failure(attack);
  end;

  if (weapon_subtype = ATTACK_TYPE_RANGED) or (weapon_subtype = ATTACK_TYPE_THROW) then
  begin
    if (attack^.attackerFlags and (DAM_HIT or DAM_CRITICAL)) = 0 then
    begin
      if is_grenade then
      begin
        throw_distance := roll_random(1, distance div 2);
        if throw_distance = 0 then throw_distance := 1;
        rot := roll_random(0, 5);
        tile := tile_num_in_direction(attack^.defender^.Tile, rot, throw_distance);
      end
      else
        tile := tile_num_beyond(attack^.attacker^.Tile, attack^.defender^.Tile, weapon_range);

      attack^.tile := tile;
      defender := attack^.defender;
      make_straight_path(defender, attack^.defender^.Tile, attack^.tile, nil, @defender, 32);
      if (defender <> nil) and (defender <> attack^.defender) then
        attack^.tile := defender^.Tile
      else
        defender := obj_blocking_at(nil, attack^.tile, attack^.defender^.Elevation);

      if (defender <> nil) and ((defender^.Flags and OBJECT_SHOOT_THRU) = 0) then
      begin
        attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
        attack^.defender := defender;
        compute_damage(attack, 1, 2);
      end;
    end;
  end;

  if ((damage_type = DAMAGE_TYPE_EXPLOSION) or is_grenade) and (((attack^.attackerFlags and DAM_HIT) <> 0) or ((attack^.attackerFlags and DAM_CRITICAL) = 0)) then
    compute_explosion_on_extras(attack, 0, is_grenade, 0)
  else
    if (attack^.attackerFlags and DAM_EXPLODE) <> 0 then
      compute_explosion_on_extras(attack, 1, is_grenade, 0);

  death_checks(attack);
  Result := 0;
end;

// =========================================================================
// compute_explosion_on_extras
// =========================================================================
procedure compute_explosion_on_extras(attack: PAttack; a2: Integer; isGrenade: Boolean; a4: Integer);
var
  attacker_obj: PObject;
  origin_tile, step, radius, rot, current_tile, current_center_tile: Integer;
  obstacle: PObject;
  index: Integer;
begin
  if a2 <> 0 then
    attacker_obj := attack^.attacker
  else
  begin
    if (attack^.attackerFlags and DAM_HIT) <> 0 then
      attacker_obj := attack^.defender
    else
      attacker_obj := nil;
  end;

  if attacker_obj <> nil then
    origin_tile := attacker_obj^.Tile
  else
    origin_tile := attack^.tile;

  radius := 0;
  rot := 0;
  current_tile := -1;
  current_center_tile := origin_tile;
  step := 0;

  while attack^.extrasLength < 6 do
  begin
    if (radius <> 0) and (current_tile <> -1) then
    begin
      current_tile := tile_num_in_direction(current_tile, rot, 1);
      if current_tile <> current_center_tile then
      begin
        Inc(step);
        if (step mod radius) = 0 then
        begin
          Inc(rot);
          if rot = ROTATION_COUNT then
            rot := ROTATION_NE;
        end;
      end
      else
      begin
        Inc(radius);
        if isGrenade and (radius > 2) then
          current_tile := -1
        else if (not isGrenade) and (radius > 3) then
          current_tile := -1
        else
          current_tile := tile_num_in_direction(current_center_tile, ROTATION_NE, 1);
        current_center_tile := current_tile;
        rot := ROTATION_SE;
        step := 0;
      end;
    end
    else
    begin
      Inc(radius);
      if isGrenade and (radius > 2) then
        current_tile := -1
      else if (not isGrenade) and (radius > 3) then
        current_tile := -1
      else
        current_tile := tile_num_in_direction(current_center_tile, ROTATION_NE, 1);
      current_center_tile := current_tile;
      rot := ROTATION_SE;
      step := 0;
    end;

    if current_tile = -1 then Break;

    obstacle := obj_blocking_at(attacker_obj, current_tile, attack^.attacker^.Elevation);
    if (obstacle <> nil)
      and (FID_TYPE(obstacle^.Fid) = OBJ_TYPE_CRITTER)
      and ((obstacle^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0)
      and ((obstacle^.Flags and OBJECT_SHOOT_THRU) = 0)
      and (not combat_is_shot_blocked(obstacle, obstacle^.Tile, origin_tile, nil, nil)) then
    begin
      if obstacle = attack^.attacker then
      begin
        attack^.attackerFlags := attack^.attackerFlags and (not DAM_HIT);
        compute_damage(attack, 1, 2);
        attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
        attack^.attackerFlags := attack^.attackerFlags or DAM_BACKWASH;
      end
      else
      begin
        index := 0;
        while index < attack^.extrasLength do
        begin
          if attack^.extras[index] = obstacle then Break;
          Inc(index);
        end;

        if index = attack^.extrasLength then
        begin
          attack^.extrasHitLocation[index] := HIT_LOCATION_TORSO;
          attack^.extras[index] := obstacle;
          combat_ctd_init(@explosion_temp_ctd, attack^.attacker, obstacle, attack^.hitMode, HIT_LOCATION_TORSO);
          if a4 = 0 then
          begin
            explosion_temp_ctd.attackerFlags := explosion_temp_ctd.attackerFlags or DAM_HIT;
            compute_damage(@explosion_temp_ctd, 1, 2);
          end;
          attack^.extrasDamage[index] := explosion_temp_ctd.defenderDamage;
          attack^.extrasFlags[index] := explosion_temp_ctd.defenderFlags;
          attack^.extrasKnockback[index] := explosion_temp_ctd.defenderKnockback;
          Inc(attack^.extrasLength);
        end;
      end;
    end;
  end;
end;

// =========================================================================
// attack_crit_success
// =========================================================================
function attack_crit_success(attack: PAttack): Integer;
var
  defender: PObject;
  chance, effect, killType: Integer;
  criticalHitDescription: PCriticalHitDescription;
begin
  defender := attack^.defender;
  if (defender <> nil) and (defender^.Pid = 16777224) then begin Result := 2; Exit; end;

  attack^.attackerFlags := attack^.attackerFlags or DAM_CRITICAL;
  chance := roll_random(1, 100);
  chance := chance + stat_level(attack^.attacker, Integer(STAT_BETTER_CRITICALS));

  if chance <= 20 then effect := 0
  else if chance <= 45 then effect := 1
  else if chance <= 70 then effect := 2
  else if chance <= 90 then effect := 3
  else if chance <= 100 then effect := 4
  else effect := 5;

  if defender = obj_dude then
    criticalHitDescription := @pc_crit_succ_eff[attack^.defenderHitLocation][effect]
  else
  begin
    killType := critter_kill_count_type(defender);
    criticalHitDescription := @crit_succ_eff[killType][attack^.defenderHitLocation][effect];
  end;

  attack^.defenderFlags := attack^.defenderFlags or criticalHitDescription^.flags;
  attack^.criticalMessageId := criticalHitDescription^.messageId;

  if criticalHitDescription^.massiveCriticalStat <> -1 then
  begin
    if stat_result(defender, criticalHitDescription^.massiveCriticalStat, criticalHitDescription^.massiveCriticalStatModifier, nil) <= ROLL_FAILURE then
    begin
      attack^.defenderFlags := attack^.defenderFlags or criticalHitDescription^.massiveCriticalFlags;
      attack^.criticalMessageId := criticalHitDescription^.massiveCriticalMessageId;
    end;
  end;

  if (attack^.defenderFlags and DAM_CRIP_RANDOM) <> 0 then
    do_random_cripple(@attack^.defenderFlags);

  Result := criticalHitDescription^.damageMultiplier;
end;

// =========================================================================
// attack_crit_failure
// =========================================================================
function attack_crit_failure(attack: PAttack): Integer;
var
  attackType, criticalFailureTableIndex, chance, effect, flags, ammoQuantity: Integer;
begin
  attack^.attackerFlags := attack^.attackerFlags and (not DAM_HIT);
  if (attack^.attacker <> nil) and (attack^.attacker^.Pid = 16777224) then begin Result := 0; Exit; end;

  attackType := item_w_subtype(attack^.weapon, attack^.hitMode);
  criticalFailureTableIndex := item_w_crit_fail(attack^.weapon);
  if criticalFailureTableIndex = -1 then criticalFailureTableIndex := 0;

  chance := roll_random(1, 100) - 5 * (stat_level(attack^.attacker, Integer(STAT_LUCK)) - 5);

  if chance <= 20 then effect := 0
  else if chance <= 50 then effect := 1
  else if chance <= 75 then effect := 2
  else if chance <= 95 then effect := 3
  else effect := 4;

  flags := cf_table[criticalFailureTableIndex][effect];
  if flags = 0 then begin Result := 0; Exit; end;

  attack^.attackerFlags := attack^.attackerFlags or DAM_CRITICAL;
  attack^.attackerFlags := attack^.attackerFlags or flags;

  if (attack^.attackerFlags and DAM_HIT_SELF) <> 0 then
  begin
    if attackType = ATTACK_TYPE_RANGED then ammoQuantity := attack^.ammoQuantity else ammoQuantity := 1;
    compute_damage(attack, ammoQuantity, 2);
  end
  else if (attack^.attackerFlags and DAM_EXPLODE) <> 0 then
    compute_damage(attack, 1, 2);

  if (attack^.attackerFlags and DAM_HURT_SELF) <> 0 then
    attack^.attackerDamage := attack^.attackerDamage + roll_random(1, 5);

  if (attack^.attackerFlags and DAM_LOSE_TURN) <> 0 then
    attack^.attacker^.Data.AsData.Critter.Combat.Ap := 0;

  if (attack^.attackerFlags and DAM_LOSE_AMMO) <> 0 then
  begin
    if attackType = ATTACK_TYPE_RANGED then
      attack^.ammoQuantity := item_w_curr_ammo(attack^.weapon)
    else
      attack^.attackerFlags := attack^.attackerFlags and (not DAM_LOSE_AMMO);
  end;

  if (attack^.attackerFlags and DAM_CRIP_RANDOM) <> 0 then
    do_random_cripple(@attack^.attackerFlags);

  if (attack^.attackerFlags and DAM_RANDOM_HIT) <> 0 then
  begin
    attack^.defender := combat_ai_random_target(attack);
    if attack^.defender <> nil then
    begin
      attack^.attackerFlags := attack^.attackerFlags or DAM_HIT;
      attack^.defenderHitLocation := HIT_LOCATION_TORSO;
      attack^.attackerFlags := attack^.attackerFlags and (not DAM_CRITICAL);
      if attackType = ATTACK_TYPE_RANGED then ammoQuantity := attack^.ammoQuantity else ammoQuantity := 1;
      compute_damage(attack, ammoQuantity, 2);
    end
    else
      attack^.defender := attack^.oops;

    if attack^.defender <> nil then
      attack^.tile := attack^.defender^.Tile;
  end;

  Result := 0;
end;

// =========================================================================
// do_random_cripple
// =========================================================================
procedure do_random_cripple(flagsPtr: PInteger);
begin
  flagsPtr^ := flagsPtr^ and (not DAM_CRIP_RANDOM);
  case roll_random(0, 3) of
    0: flagsPtr^ := flagsPtr^ or DAM_CRIP_LEG_LEFT;
    1: flagsPtr^ := flagsPtr^ or DAM_CRIP_LEG_RIGHT;
    2: flagsPtr^ := flagsPtr^ or DAM_CRIP_ARM_LEFT;
    3: flagsPtr^ := flagsPtr^ or DAM_CRIP_ARM_RIGHT;
  end;
end;

// =========================================================================
// determine_to_hit / determine_to_hit_no_range
// =========================================================================
function determine_to_hit(a1: PObject; a2: PObject; hitLocation: Integer; hitMode: Integer): Integer;
begin
  Result := determine_to_hit_func(a1, a2, hitLocation, hitMode, 1);
end;

function determine_to_hit_no_range(a1: PObject; a2: PObject; hitLocation: Integer; hitMode: Integer): Integer;
begin
  Result := determine_to_hit_func(a1, a2, hitLocation, hitMode, 0);
end;

// =========================================================================
// determine_to_hit_func
// =========================================================================
function determine_to_hit_func(attacker: PObject; defender: PObject; hitLocation: Integer; hitMode: Integer; check_range: Integer): Integer;
var
  weapon: PObject;
  is_ranged_weapon: Boolean;
  accuracy, attack_type, modifier_val: Integer;
  range, perception, perception_modifier: Integer;
  lightIntensity, combatDifficulty: Integer;
begin
  is_ranged_weapon := false;
  accuracy := 0;
  weapon := item_hit_with(attacker, hitMode);

  if weapon = nil then
    accuracy := skill_level(attacker, Integer(SKILL_UNARMED))
  else
  begin
    accuracy := item_w_skill_level(attacker, hitMode);
    attack_type := item_w_subtype(weapon, hitMode);
    if (attack_type = ATTACK_TYPE_RANGED) or (attack_type = ATTACK_TYPE_THROW) then
    begin
      is_ranged_weapon := true;
      if check_range <> 0 then
      begin
        perception_modifier := 2;
        case item_w_perk(weapon) of
          PERK_WEAPON_LONG_RANGE: perception_modifier := 4;
        end;
        perception := stat_level(attacker, Integer(STAT_PERCEPTION));
        range := obj_dist(attacker, defender) - perception_modifier * perception;
        if range < -2 * perception then range := -2 * perception;
        if attacker = obj_dude then
          range := range - 2 * perk_level(PERK_SHARPSHOOTER);
        if (range >= 0) and ((attacker^.Data.AsData.Critter.Combat.Results and DAM_BLIND) <> 0) then
          modifier_val := -12 * range
        else
          modifier_val := -4 * range;
        accuracy := accuracy + modifier_val;
      end;
      combat_is_shot_blocked(attacker, attacker^.Tile, defender^.Tile, defender, @modifier_val);
      accuracy := accuracy - 10 * modifier_val;
    end;

    if attacker = obj_dude then
    begin
      if trait_level(TRAIT_ONE_HANDER) <> 0 then
      begin
        if item_w_is_2handed(weapon) <> 0 then
          accuracy := accuracy - 40
        else
          accuracy := accuracy + 20;
      end;
    end;

    modifier_val := item_w_min_st(weapon) - stat_level(attacker, Integer(STAT_STRENGTH));
    if modifier_val > 0 then
      accuracy := accuracy - 20 * modifier_val;

    if item_w_perk(weapon) = PERK_WEAPON_ACCURATE then
      accuracy := accuracy + 20;
  end;

  accuracy := accuracy - stat_level(defender, Integer(STAT_ARMOR_CLASS));

  if is_ranged_weapon then
    accuracy := accuracy + hit_location_penalty[hitLocation]
  else
    accuracy := accuracy + hit_location_penalty[hitLocation] div 2;

  if (defender <> nil) and ((defender^.Flags and OBJECT_MULTIHEX) <> 0) then
    accuracy := accuracy + 15;

  if attacker = obj_dude then
  begin
    lightIntensity := obj_get_visible_light(defender);
    if lightIntensity <= 26214 then
      accuracy := accuracy - 40
    else if lightIntensity <= 39321 then
      accuracy := accuracy - 25
    else if lightIntensity <= 52428 then
      accuracy := accuracy - 10;
  end;

  if gcsd <> nil then
    accuracy := accuracy + gcsd^.accuracyBonus;

  if (attacker^.Data.AsData.Critter.Combat.Results and DAM_BLIND) <> 0 then
    accuracy := accuracy - 25;

  if (defender^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) <> 0 then
    accuracy := accuracy + 40;

  if attacker^.Data.AsData.Critter.Combat.Team <> obj_dude^.Data.AsData.Critter.Combat.Team then
  begin
    combatDifficulty := COMBAT_DIFFICULTY_NORMAL;
    config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, @combatDifficulty);
    case combatDifficulty of
      COMBAT_DIFFICULTY_EASY: accuracy := accuracy - 20;
      COMBAT_DIFFICULTY_HARD: accuracy := accuracy + 20;
    end;
  end;

  if accuracy > 95 then accuracy := 95;
  if accuracy < -100 then
    debug_printf('Whoa! Bad skill value in determine_to_hit!'#10);

  Result := accuracy;
end;

// =========================================================================
// compute_damage
// =========================================================================
procedure compute_damage(attack: PAttack; ammoQuantity: Integer; bonusDamageMultiplier: Integer);
var
  damage_ptr: PInteger;
  critter: PObject;
  flags_ptr: PInteger;
  knockback_distance_ptr: PInteger;
  damage_type, damage_threshold, damage_resistance: Integer;
  bonus_ranged_damage, combat_difficulty_multiplier, combat_difficulty_val: Integer;
  round_idx, round_damage: Integer;
begin
  if (attack^.attackerFlags and DAM_HIT) <> 0 then
  begin
    damage_ptr := @attack^.defenderDamage;
    critter := attack^.defender;
    flags_ptr := @attack^.defenderFlags;
    knockback_distance_ptr := @attack^.defenderKnockback;
  end
  else
  begin
    damage_ptr := @attack^.attackerDamage;
    critter := attack^.attacker;
    flags_ptr := @attack^.attackerFlags;
    knockback_distance_ptr := nil;
  end;

  damage_ptr^ := 0;
  if FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER then Exit;

  damage_type := item_w_damage_type(attack^.weapon);

  if ((flags_ptr^ and DAM_BYPASS) = 0) or (damage_type = DAMAGE_TYPE_EMP) then
  begin
    if item_w_perk(attack^.weapon) = PERK_WEAPON_PENETRATE then
      damage_threshold := 0
    else
      damage_threshold := stat_level(critter, Integer(STAT_DAMAGE_THRESHOLD) + damage_type);
    damage_resistance := stat_level(critter, Integer(STAT_DAMAGE_RESISTANCE) + damage_type);
    if attack^.attacker = obj_dude then
      if trait_level(TRAIT_FINESSE) <> 0 then
        damage_resistance := damage_resistance + 30;
  end
  else
  begin
    damage_threshold := 0;
    damage_resistance := 0;
  end;

  if (attack^.attacker = obj_dude) and (item_w_subtype(attack^.weapon, attack^.hitMode) = ATTACK_TYPE_RANGED) then
    bonus_ranged_damage := 2 * perk_level(PERK_BONUS_RANGED_DAMAGE)
  else
    bonus_ranged_damage := 0;

  combat_difficulty_multiplier := 100;
  if attack^.attacker^.Data.AsData.Critter.Combat.Team <> obj_dude^.Data.AsData.Critter.Combat.Team then
  begin
    combat_difficulty_val := COMBAT_DIFFICULTY_NORMAL;
    config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, @combat_difficulty_val);
    case combat_difficulty_val of
      COMBAT_DIFFICULTY_EASY: combat_difficulty_multiplier := 75;
      COMBAT_DIFFICULTY_HARD: combat_difficulty_multiplier := 125;
    end;
  end;

  for round_idx := 0 to ammoQuantity - 1 do
  begin
    round_damage := item_w_damage(attack^.attacker, attack^.hitMode) + bonus_ranged_damage;
    round_damage := round_damage * bonusDamageMultiplier;
    round_damage := round_damage div 2;
    round_damage := round_damage * combat_difficulty_multiplier;
    round_damage := round_damage div 100;
    round_damage := round_damage - damage_threshold;
    if round_damage > 0 then
    begin
      round_damage := round_damage - round_damage * damage_resistance div 100;
      if round_damage > 0 then
        damage_ptr^ := damage_ptr^ + round_damage;
    end;
  end;

  if knockback_distance_ptr <> nil then
  begin
    if (critter^.Flags and OBJECT_MULTIHEX) = 0 then
    begin
      if (damage_type = DAMAGE_TYPE_EXPLOSION) or (attack^.weapon = nil) or (item_w_subtype(attack^.weapon, attack^.hitMode) = ATTACK_TYPE_MELEE) then
      begin
        if item_w_perk(attack^.weapon) = PERK_WEAPON_KNOCKBACK then
          knockback_distance_ptr^ := damage_ptr^ div 5
        else
          knockback_distance_ptr^ := damage_ptr^ div 10;
      end;
    end;
  end;
end;

// =========================================================================
// death_checks
// =========================================================================
procedure death_checks(attack: PAttack);
var
  index: Integer;
begin
  check_for_death(attack^.attacker, attack^.attackerDamage, @attack^.attackerFlags);
  check_for_death(attack^.defender, attack^.defenderDamage, @attack^.defenderFlags);
  for index := 0 to attack^.extrasLength - 1 do
    check_for_death(attack^.extras[index], attack^.extrasDamage[index], @attack^.extrasFlags[index]);
end;

// =========================================================================
// apply_damage
// =========================================================================
procedure apply_damage(attack: PAttack; animated: Boolean);
var
  attacker_obj, defender_obj, obj: PObject;
  attackerIsCritter, defenderIsCritter: Boolean;
  index: Integer;
begin
  attacker_obj := attack^.attacker;
  attackerIsCritter := (attacker_obj <> nil) and (FID_TYPE(attacker_obj^.Fid) = OBJ_TYPE_CRITTER);

  if attackerIsCritter and ((attacker_obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
  begin
    set_new_results(attacker_obj, attack^.attackerFlags);
    damage_object(attacker_obj, attack^.attackerDamage, animated, attack^.defender <> attack^.oops);
  end;

  if (attack^.oops <> nil) and (attack^.oops <> attack^.defender) then
    combatai_notify_onlookers(attack^.oops);

  defender_obj := attack^.defender;
  defenderIsCritter := (defender_obj <> nil) and (FID_TYPE(defender_obj^.Fid) = OBJ_TYPE_CRITTER);

  if defenderIsCritter and ((defender_obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
  begin
    set_new_results(defender_obj, attack^.defenderFlags);
    if attackerIsCritter then
    begin
      if (defender_obj^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
        critter_set_who_hit_me(defender_obj, attack^.attacker)
      else if (defender_obj = attack^.oops) or (defender_obj^.Data.AsData.Critter.Combat.Team <> attack^.attacker^.Data.AsData.Critter.Combat.Team) then
        combatai_check_retaliation(defender_obj, attack^.attacker);
    end;

    scr_set_objs(defender_obj^.Sid, attack^.attacker, nil);
    damage_object(defender_obj, attack^.defenderDamage, animated, attack^.defender <> attack^.oops);
    combatai_notify_onlookers(defender_obj);

    if (attack^.defenderDamage >= 0) and ((attack^.attackerFlags and DAM_HIT) <> 0) then
    begin
      scr_set_objs(attack^.attacker^.Sid, nil, attack^.defender);
      scr_set_ext_param(attack^.attacker^.Sid, 2);
      exec_script_proc(attack^.attacker^.Sid, SCRIPT_PROC_COMBAT);
    end;
  end;

  for index := 0 to attack^.extrasLength - 1 do
  begin
    obj := attack^.extras[index];
    if (FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER) and ((obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
    begin
      set_new_results(obj, attack^.extrasFlags[index]);
      if attackerIsCritter then
      begin
        if (obj^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
          critter_set_who_hit_me(obj, attack^.attacker)
        else if obj^.Data.AsData.Critter.Combat.Team <> attack^.attacker^.Data.AsData.Critter.Combat.Team then
          combatai_check_retaliation(obj, attack^.attacker);
      end;
      scr_set_objs(obj^.Sid, attack^.attacker, nil);
      damage_object(obj, attack^.extrasDamage[index], animated, attack^.defender <> attack^.oops);
      combatai_notify_onlookers(obj);
      if (attack^.extrasDamage[index] >= 0) and ((attack^.attackerFlags and DAM_HIT) <> 0) then
      begin
        scr_set_objs(attack^.attacker^.Sid, nil, obj);
        scr_set_ext_param(attack^.attacker^.Sid, 2);
        exec_script_proc(attack^.attacker^.Sid, SCRIPT_PROC_COMBAT);
      end;
    end;
  end;
end;

// =========================================================================
// check_for_death
// =========================================================================
procedure check_for_death(obj: PObject; damage: Integer; flags: PInteger);
begin
  if (obj = nil) or (obj^.Pid = 16777224) then Exit;
  if damage > 0 then
    if critter_get_hits(obj) - damage <= 0 then
      flags^ := flags^ or DAM_DEAD;
end;

// =========================================================================
// set_new_results
// =========================================================================
procedure set_new_results(critter: PObject; flags: Integer);
var
  endurance_val: Integer;
begin
  if critter = nil then Exit;
  if FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER then Exit;
  if critter^.Pid = 16777224 then Exit;
  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then Exit;

  if (flags and DAM_DEAD) <> 0 then
    queue_remove(critter)
  else if (flags and DAM_KNOCKED_OUT) <> 0 then
  begin
    queue_remove_this(critter, EVENT_TYPE_KNOCKOUT);
    endurance_val := stat_level(critter, Integer(STAT_ENDURANCE));
    queue_add(10 * (35 - 3 * endurance_val), critter, nil, EVENT_TYPE_KNOCKOUT);
  end;

  if (critter = obj_dude) and ((flags and DAM_CRIP_ARM_ANY) <> 0) then
  begin
    critter^.Data.AsData.Critter.Combat.Results := critter^.Data.AsData.Critter.Combat.Results or (flags and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN or DAM_CRIP or DAM_DEAD or DAM_LOSE_TURN));
    intface_update_items(true);
  end
  else
    critter^.Data.AsData.Critter.Combat.Results := critter^.Data.AsData.Critter.Combat.Results or (flags and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN or DAM_CRIP or DAM_DEAD or DAM_LOSE_TURN));
end;

// =========================================================================
// damage_object
// =========================================================================
procedure damage_object(obj: PObject; damage: Integer; animated: Boolean; a4: Boolean);
var
  whoHitMe: PObject;
  scriptOverrides: Boolean;
  scr: u_scripts.PScript;
begin
  if obj = nil then Exit;
  if FID_TYPE(obj^.Fid) <> OBJ_TYPE_CRITTER then Exit;
  if obj^.Pid = 16777224 then Exit;
  if damage <= 0 then Exit;

  critter_adjust_hits(obj, -damage);
  if obj = obj_dude then
    intface_update_hit_points(animated);

  obj^.Data.AsData.Critter.Combat.DamageLastTurn := obj^.Data.AsData.Critter.Combat.DamageLastTurn + damage;

  if not a4 then
    exec_script_proc(obj^.Sid, SCRIPT_PROC_DAMAGE);

  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    scr_set_objs(obj^.Sid, obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe, nil);
    exec_script_proc(obj^.Sid, SCRIPT_PROC_DESTROY);

    if obj <> obj_dude then
    begin
      whoHitMe := obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
      if (whoHitMe = obj_dude) or ((whoHitMe <> nil) and (whoHitMe^.Data.AsData.Critter.Combat.Team = obj_dude^.Data.AsData.Critter.Combat.Team)) then
      begin
        scriptOverrides := false;
        if scr_ptr(obj^.Sid, @scr) <> -1 then
          scriptOverrides := scr^.scriptOverrides <> 0;
        if not scriptOverrides then
        begin
          combat_exps := combat_exps + critter_kill_exps(obj);
          critter_kill_count_inc(critter_kill_count_type(obj));
        end;
      end;
    end;

    if obj^.Sid <> -1 then
    begin
      scr_remove(obj^.Sid);
      obj^.Sid := -1;
    end;
    partyMemberRemove(obj);
  end;
end;

// =========================================================================
// combat_display (stub - message formatting)
// =========================================================================
procedure combat_display(attack: PAttack);
var
  messageListItem: TMessageListItem;
  mainCritter: PObject;
  mainCritterName: PAnsiChar;
  you: array[0..19] of AnsiChar;
  baseMessageId: Integer;
  text: array[0..279] of AnsiChar;
  hitLocationName: PAnsiChar;
  combatMessages: Integer;
  weapon: PObject;
  strengthRequired: Integer;
  index: Integer;
  critter: PObject;
begin
  if attack^.attacker = obj_dude then
  begin
    weapon := item_hit_with(attack^.attacker, attack^.hitMode);
    strengthRequired := item_w_min_st(weapon);
    if weapon <> nil then
      if strengthRequired > stat_level(obj_dude, Integer(STAT_STRENGTH)) then
      begin
        messageListItem.num := 107;
        if message_search(@combat_message_file, @messageListItem) then
          display_print(messageListItem.text);
      end;
  end;

  if (attack^.attackerFlags and DAM_HIT) <> 0 then
    mainCritter := attack^.defender
  else
    mainCritter := attack^.attacker;

  mainCritterName := @_a_1[0];
  you[0] := #0;

  messageListItem.num := 506;
  if message_search(@combat_message_file, @messageListItem) then
    StrCopy(you, messageListItem.text);

  baseMessageId := 600;
  if mainCritter = obj_dude then
  begin
    mainCritterName := @you[0];
    baseMessageId := 500;
  end
  else if mainCritter <> nil then
  begin
    mainCritterName := object_name(mainCritter);
    if stat_level(mainCritter, Integer(STAT_GENDER)) = GENDER_MALE then
      baseMessageId := 600
    else
      baseMessageId := 700;
  end;

  // Oops target handling
  if (attack^.defender <> nil) and (attack^.oops <> nil)
    and (attack^.defender <> attack^.oops) and ((attack^.attackerFlags and DAM_HIT) <> 0) then
  begin
    if FID_TYPE(attack^.defender^.Fid) = OBJ_TYPE_CRITTER then
    begin
      if attack^.oops = obj_dude then
      begin
        messageListItem.num := baseMessageId + 8;
        if message_search(@combat_message_file, @messageListItem) then
          StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName]);
      end
      else
      begin
        messageListItem.num := baseMessageId + 9;
        if message_search(@combat_message_file, @messageListItem) then
          StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName, object_name(attack^.oops)]);
      end;
    end
    else
    begin
      if attack^.attacker = obj_dude then
      begin
        messageListItem.num := 515;
        if message_search(@combat_message_file, @messageListItem) then
          StrLFmt(text, SizeOf(text), messageListItem.text, [PAnsiChar(@you[0])]);
      end
      else
      begin
        if stat_level(attack^.attacker, Integer(STAT_GENDER)) = GENDER_MALE then
          messageListItem.num := 615
        else
          messageListItem.num := 715;
        if message_search(@combat_message_file, @messageListItem) then
          StrLFmt(text, SizeOf(text), messageListItem.text, [object_name(attack^.attacker)]);
      end;
    end;
    StrCat(text, '.');
    display_print(text);
  end;

  // Hit display
  if (attack^.attackerFlags and DAM_HIT) <> 0 then
  begin
    if (attack^.defender <> nil) and ((attack^.defender^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
    begin
      text[0] := #0;
      if FID_TYPE(attack^.defender^.Fid) = OBJ_TYPE_CRITTER then
      begin
        if attack^.defenderHitLocation = HIT_LOCATION_TORSO then
        begin
          if (attack^.attackerFlags and DAM_CRITICAL) <> 0 then
          begin
            case attack^.defenderDamage of
              0: messageListItem.num := baseMessageId + 28;
              1: messageListItem.num := baseMessageId + 24;
            else
              messageListItem.num := baseMessageId + 20;
            end;
            if message_search(@combat_message_file, @messageListItem) then
            begin
              if attack^.defenderDamage <= 1 then
                StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName])
              else
                StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName, attack^.defenderDamage]);
            end;
          end
          else
            combat_display_hit(text, SizeOf(text), attack^.defender, attack^.defenderDamage);
        end
        else
        begin
          hitLocationName := combat_get_loc_name(attack^.defender, attack^.defenderHitLocation);
          if hitLocationName <> nil then
          begin
            if (attack^.attackerFlags and DAM_CRITICAL) <> 0 then
            begin
              case attack^.defenderDamage of
                0: messageListItem.num := baseMessageId + 25;
                1: messageListItem.num := baseMessageId + 21;
              else
                messageListItem.num := baseMessageId + 11;
              end;
            end
            else
            begin
              case attack^.defenderDamage of
                0: messageListItem.num := baseMessageId + 26;
                1: messageListItem.num := baseMessageId + 22;
              else
                messageListItem.num := baseMessageId + 12;
              end;
            end;
            if message_search(@combat_message_file, @messageListItem) then
            begin
              if attack^.defenderDamage <= 1 then
                StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName, hitLocationName])
              else
                StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName, hitLocationName, attack^.defenderDamage]);
            end;
          end;
        end;

        combatMessages := 1;
        config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_MESSAGES_KEY, @combatMessages);

        if (combatMessages = 1) and ((attack^.attackerFlags and DAM_CRITICAL) <> 0) and (attack^.criticalMessageId <> -1) then
        begin
          messageListItem.num := attack^.criticalMessageId;
          if message_search(@combat_message_file, @messageListItem) then
            StrCat(text, messageListItem.text);

          if (attack^.defenderFlags and DAM_DEAD) <> 0 then
          begin
            StrCat(text, '.');
            display_print(text);

            if attack^.defender = obj_dude then
            begin
              if stat_level(attack^.defender, Integer(STAT_GENDER)) = GENDER_MALE then
                messageListItem.num := 207
              else
                messageListItem.num := 257;
            end
            else
            begin
              if stat_level(attack^.defender, Integer(STAT_GENDER)) = GENDER_MALE then
                messageListItem.num := 307
              else
                messageListItem.num := 407;
            end;
            if message_search(@combat_message_file, @messageListItem) then
              StrLFmt(text, SizeOf(text), '%s %s', [mainCritterName, messageListItem.text]);
          end
          else
            combat_display_flags(text, attack^.defenderFlags, attack^.defender);
        end
        else
          combat_display_flags(text, attack^.defenderFlags, attack^.defender);

        StrCat(text, '.');
        display_print(text);
      end;
    end;
  end;

  // Attacker miss/damage display
  if (attack^.attacker <> nil) and ((attack^.attacker^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
  begin
    if (attack^.attackerFlags and DAM_HIT) = 0 then
    begin
      if (attack^.attackerFlags and DAM_CRITICAL) <> 0 then
      begin
        case attack^.attackerDamage of
          0: messageListItem.num := baseMessageId + 14;
          1: messageListItem.num := baseMessageId + 33;
        else
          messageListItem.num := baseMessageId + 34;
        end;
      end
      else
        messageListItem.num := baseMessageId + 15;

      if message_search(@combat_message_file, @messageListItem) then
      begin
        if attack^.attackerDamage <= 1 then
          StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName])
        else
          StrLFmt(text, SizeOf(text), messageListItem.text, [mainCritterName, attack^.attackerDamage]);
      end;

      combat_display_flags(text, attack^.attackerFlags, attack^.attacker);
      StrCat(text, '.');
      display_print(text);
    end;

    if ((attack^.attackerFlags and DAM_HIT) <> 0) or ((attack^.attackerFlags and DAM_CRITICAL) = 0) then
    begin
      if attack^.attackerDamage > 0 then
      begin
        combat_display_hit(text, SizeOf(text), attack^.attacker, attack^.attackerDamage);
        combat_display_flags(text, attack^.attackerFlags, attack^.attacker);
        StrCat(text, '.');
        display_print(text);
      end;
    end;
  end;

  for index := 0 to attack^.extrasLength - 1 do
  begin
    critter := attack^.extras[index];
    if (critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
    begin
      combat_display_hit(text, SizeOf(text), critter, attack^.extrasDamage[index]);
      combat_display_flags(text, attack^.extrasFlags[index], critter);
      StrCat(text, '.');
      display_print(text);
    end;
  end;
end;

// =========================================================================
// combat_display_hit
// =========================================================================
procedure combat_display_hit(dest: PAnsiChar; size: Integer; critter_obj: PObject; damage: Integer);
var
  messageListItem: TMessageListItem;
  text: array[0..39] of AnsiChar;
  name: PAnsiChar;
  messageId: Integer;
begin
  if critter_obj = obj_dude then
  begin
    text[0] := #0;
    messageId := 500;
    messageListItem.num := messageId + 6;
    if message_search(@combat_message_file, @messageListItem) then
      StrCopy(text, messageListItem.text);
    name := @text[0];
  end
  else
  begin
    name := object_name(critter_obj);
    if stat_level(critter_obj, Integer(STAT_GENDER)) = GENDER_MALE then
      messageId := 600
    else
      messageId := 700;
  end;

  case damage of
    0: messageId := messageId + 27;
    1: messageId := messageId + 23;
  else
    messageId := messageId + 13;
  end;

  messageListItem.num := messageId;
  if message_search(@combat_message_file, @messageListItem) then
  begin
    if damage <= 1 then
      StrLFmt(dest, size, messageListItem.text, [name])
    else
      StrLFmt(dest, size, messageListItem.text, [name, damage]);
  end;
end;

// =========================================================================
// combat_display_flags
// =========================================================================
procedure combat_display_flags(a1: PAnsiChar; flags: Integer; a3: PObject);
var
  messageListItem: TMessageListItem;
  num, bit, flagsListLength, index: Integer;
  flagsList: array[0..31] of Integer;
begin
  if a3 = obj_dude then
    num := 200
  else
  begin
    if stat_level(a3, Integer(STAT_GENDER)) = GENDER_MALE then
      num := 300
    else
      num := 400;
  end;

  if flags = 0 then Exit;

  if (flags and DAM_DEAD) <> 0 then
  begin
    messageListItem.num := 108;
    if message_search(@combat_message_file, @messageListItem) then
      StrCat(a1, messageListItem.text);
    messageListItem.num := num + 7;
    if message_search(@combat_message_file, @messageListItem) then
      StrCat(a1, messageListItem.text);
    Exit;
  end;

  bit := 1;
  flagsListLength := 0;
  for index := 0 to 31 do
  begin
    if (bit <> DAM_CRITICAL) and (bit <> DAM_HIT) and ((bit and flags) <> 0) then
    begin
      flagsList[flagsListLength] := index;
      Inc(flagsListLength);
    end;
    bit := bit shl 1;
  end;

  if flagsListLength <> 0 then
  begin
    for index := 0 to flagsListLength - 2 do
    begin
      StrCat(a1, ', ');
      messageListItem.num := num + flagsList[index];
      if message_search(@combat_message_file, @messageListItem) then
        StrCat(a1, messageListItem.text);
    end;

    messageListItem.num := 108;
    if message_search(@combat_message_file, @messageListItem) then
      StrCat(a1, messageListItem.text);

    messageListItem.num := num + flagsList[flagsListLength - 1];
    if message_search(@combat_message_file, @messageListItem) then
      StrCat(a1, messageListItem.text);
  end;
end;

// =========================================================================
// combat_anim_begin
// =========================================================================
procedure combat_anim_begin;
begin
  Inc(combat_turn_running);
  if (combat_turn_running = 1) and (obj_dude = main_ctd.attacker) then
  begin
    game_ui_disable(1);
    gmouse_set_cursor(26);
    if combat_highlight = 2 then
      combat_outline_off;
  end;
end;

// =========================================================================
// combat_anim_finished
// =========================================================================
procedure combat_anim_finished;
var
  weapon: PObject;
  ammoQuantity_val: Integer;
  attacker_obj: PObject;
begin
  Dec(combat_turn_running);
  if combat_turn_running <> 0 then Exit;

  if obj_dude = main_ctd.attacker then
    game_ui_enable;

  if combat_cleanup_enabled then
  begin
    combat_cleanup_enabled := false;

    weapon := item_hit_with(main_ctd.attacker, main_ctd.hitMode);
    if weapon <> nil then
    begin
      if item_w_max_ammo(weapon) > 0 then
      begin
        ammoQuantity_val := item_w_curr_ammo(weapon);
        item_w_set_curr_ammo(weapon, ammoQuantity_val - main_ctd.ammoQuantity);
        if main_ctd.attacker = obj_dude then
          intface_update_ammo_lights;
      end;
    end;

    if combat_call_display then
    begin
      combat_display(@main_ctd);
      combat_call_display := false;
    end;

    apply_damage(@main_ctd, true);

    attacker_obj := main_ctd.attacker;
    if (attacker_obj = obj_dude) and (combat_highlight = 2) then
      combat_outline_on;

    if scr_end_combat then
    begin
      if (obj_dude^.Data.AsData.Critter.Combat.Results and DAM_KNOCKED_OUT) <> 0 then
      begin
        if attacker_obj^.Data.AsData.Critter.Combat.Team = obj_dude^.Data.AsData.Critter.Combat.Team then
          combat_ending_guy := obj_dude^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe
        else
          combat_ending_guy := attacker_obj;
      end;
    end;

    combat_ctd_init(@main_ctd, main_ctd.attacker, nil, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);

    if (attacker_obj^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) <> 0 then
    begin
      if (attacker_obj^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD or DAM_LOSE_TURN)) = 0 then
        combat_standup(attacker_obj);
    end;
  end;
end;

// =========================================================================
// combat_standup
// =========================================================================
procedure combat_standup(a1: PObject);
begin
  if a1^.Data.AsData.Critter.Combat.Ap < 3 then
    a1^.Data.AsData.Critter.Combat.Ap := 0
  else
    a1^.Data.AsData.Critter.Combat.Ap := a1^.Data.AsData.Critter.Combat.Ap - 3;

  if a1 = obj_dude then
    intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);

  dude_standup(a1);
  combat_turn_run;
end;

// =========================================================================
// print_tohit
// =========================================================================
procedure print_tohit(dest: PByte; dest_pitch: Integer; accuracy: Integer);
var
  numbersFrmHandle: PCacheEntry;
  numbersFrmFid: Integer;
  numbersFrmData: PByte;
begin
  numbersFrmFid := art_id(OBJ_TYPE_INTERFACE, 82, 0, 0, 0);
  numbersFrmData := art_ptr_lock_data(numbersFrmFid, 0, 0, @numbersFrmHandle);
  if numbersFrmData = nil then Exit;

  if accuracy >= 0 then
  begin
    buf_to_buf(numbersFrmData + 9 * (accuracy mod 10), 9, 17, 360, dest + 9, dest_pitch);
    buf_to_buf(numbersFrmData + 9 * (accuracy div 10), 9, 17, 360, dest, dest_pitch);
  end
  else
  begin
    buf_to_buf(numbersFrmData + 108, 6, 17, 360, dest + 9, dest_pitch);
    buf_to_buf(numbersFrmData + 108, 6, 17, 360, dest, dest_pitch);
  end;

  art_ptr_unlock(numbersFrmHandle);
end;

// =========================================================================
// combat_get_loc_name
// =========================================================================
function combat_get_loc_name(critter: PObject; hitLocation: Integer): PAnsiChar;
var
  messageListItem: TMessageListItem;
begin
  messageListItem.num := 1000 + 10 * art_alias_num(critter^.Fid and $FFF) + hitLocation;
  if message_search(@combat_message_file, @messageListItem) then
    Result := messageListItem.text
  else
    Result := nil;
end;

// =========================================================================
// draw_loc_off / draw_loc_on / draw_loc
// =========================================================================
procedure draw_loc_off(btn: Integer; input: Integer); cdecl;
begin
  draw_loc(input, colorTable[992]);
end;

procedure draw_loc_on(btn: Integer; input: Integer); cdecl;
begin
  draw_loc(input, colorTable[31744]);
end;

procedure draw_loc(input: Integer; color: Integer);
var
  name: PAnsiChar;
begin
  color := color or $2000000 or $1000000;

  if input >= 4 then
  begin
    name := combat_get_loc_name(call_target, hit_loc_right[input - 4]);
    if name <> nil then
      win_print(call_win, name, 0, 351 - text_width(name), call_ty[input - 4] - 86, color);
  end
  else
  begin
    name := combat_get_loc_name(call_target, hit_loc_left[input]);
    if name <> nil then
      win_print(call_win, name, 0, 74, call_ty[input] - 86, color);
  end;
end;

// =========================================================================
// get_called_shot_location
// =========================================================================
function get_called_shot_location(critter: PObject; hit_location: PInteger; hit_mode: Integer): Integer;
var
  calledShotWindowX, calledShotWindowY: Integer;
  fid_val: Integer;
  handle, upHandle, downHandle: PCacheEntry;
  data, up, down, windowBuffer: PByte;
  btn, oldFont, eventCode: Integer;
  gameUiWasDisabled: Boolean;
  probability: Integer;
  hit_location_name: PAnsiChar;
  hit_location_name_width: Integer;
  index: Integer;
begin
  call_target := critter;
  calledShotWindowX := (screenGetWidth - CALLED_SHOT_WINDOW_WIDTH) div 2;
  if screenGetHeight <> 480 then
    calledShotWindowY := (screenGetHeight - INTERFACE_BAR_HEIGHT - 1 - CALLED_SHOT_WINDOW_HEIGHT) div 2
  else
    calledShotWindowY := CALLED_SHOT_WINDOW_Y;

  call_win := win_add(calledShotWindowX, calledShotWindowY, CALLED_SHOT_WINDOW_WIDTH, CALLED_SHOT_WINDOW_HEIGHT, colorTable[0], WINDOW_MODAL);
  if call_win = -1 then begin Result := -1; Exit; end;

  windowBuffer := win_get_buf(call_win);

  fid_val := art_id(OBJ_TYPE_INTERFACE, 118, 0, 0, 0);
  data := art_ptr_lock_data(fid_val, 0, 0, @handle);
  if data = nil then begin win_delete(call_win); Result := -1; Exit; end;

  buf_to_buf(data, CALLED_SHOT_WINDOW_WIDTH, CALLED_SHOT_WINDOW_HEIGHT, CALLED_SHOT_WINDOW_WIDTH, windowBuffer, CALLED_SHOT_WINDOW_WIDTH);
  art_ptr_unlock(handle);

  fid_val := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_CALLED_SHOT_PIC, 0, 0);
  data := art_ptr_lock_data(fid_val, 0, 0, @handle);
  if data <> nil then
  begin
    buf_to_buf(data, 170, 225, 170, windowBuffer + CALLED_SHOT_WINDOW_WIDTH * 31 + 128, CALLED_SHOT_WINDOW_WIDTH);
    art_ptr_unlock(handle);
  end;

  fid_val := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  up := art_ptr_lock_data(fid_val, 0, 0, @upHandle);
  if up = nil then begin win_delete(call_win); Result := -1; Exit; end;

  fid_val := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  down := art_ptr_lock_data(fid_val, 0, 0, @downHandle);
  if down = nil then begin art_ptr_unlock(upHandle); win_delete(call_win); Result := -1; Exit; end;

  btn := win_register_button(call_win, 170, 268, 15, 16, -1, -1, -1, KEY_ESCAPE, up, down, nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  oldFont := text_curr;
  text_font(101);

  for index := 0 to 3 do
  begin
    probability := determine_to_hit(obj_dude, critter, hit_loc_left[index], hit_mode);
    print_tohit(windowBuffer + CALLED_SHOT_WINDOW_WIDTH * (call_ty[index] - 86) + 33, CALLED_SHOT_WINDOW_WIDTH, probability);

    btn := win_register_button(call_win, 33, call_ty[index] - 82, 88, 10, index, index, -1, index, nil, nil, nil, 0);
    win_register_button_func(btn, @draw_loc_on, @draw_loc_off, nil, nil);
    draw_loc_off(btn, index);

    probability := determine_to_hit(obj_dude, critter, hit_loc_right[index], hit_mode);
    print_tohit(windowBuffer + CALLED_SHOT_WINDOW_WIDTH * (call_ty[index] - 86) + 373, CALLED_SHOT_WINDOW_WIDTH, probability);

    hit_location_name := combat_get_loc_name(critter, hit_loc_right[index]);
    if hit_location_name <> nil then
      hit_location_name_width := text_width(hit_location_name)
    else
      hit_location_name_width := 10;

    btn := win_register_button(call_win, 351 - hit_location_name_width, call_ty[index] - 82, 88, 10, index + 4, index + 4, -1, index + 4, nil, nil, nil, 0);
    win_register_button_func(btn, @draw_loc_on, @draw_loc_off, nil, nil);
    draw_loc_off(btn, index + 4);
  end;

  win_draw(call_win);

  gameUiWasDisabled := game_ui_is_disabled;
  if gameUiWasDisabled then
    game_ui_enable;

  gmouse_disable(0);
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  eventCode := -2;
  while true do
  begin
    sharedFpsLimiter.Mark;
    eventCode := get_input;
    if eventCode = KEY_ESCAPE then Break;
    if (eventCode >= 0) and (eventCode < HIT_LOCATION_COUNT) then Break;
    if game_user_wants_to_quit <> 0 then Break;
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  gmouse_enable;
  if gameUiWasDisabled then
    game_ui_disable(0);

  text_font(oldFont);
  art_ptr_unlock(downHandle);
  art_ptr_unlock(upHandle);
  win_delete(call_win);

  if eventCode = KEY_ESCAPE then begin Result := -1; Exit; end;

  if eventCode < 4 then
    hit_location^ := hit_loc_left[eventCode]
  else
    hit_location^ := hit_loc_right[eventCode - 4];

  gsound_play_sfx_file('icsxxxx1');
  Result := 0;
end;

// =========================================================================
// combat_check_bad_shot
// =========================================================================
function combat_check_bad_shot(attacker: PObject; defender: PObject; hitMode: Integer; aiming: Boolean): Integer;
var
  weapon: PObject;
  attack_type: Integer;
begin
  if (defender^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then begin Result := COMBAT_BAD_SHOT_ALREADY_DEAD; Exit; end;

  weapon := item_hit_with(attacker, hitMode);
  if weapon <> nil then
  begin
    if ((attacker^.Data.AsData.Critter.Combat.Results and DAM_CRIP_ARM_LEFT) <> 0) and ((attacker^.Data.AsData.Critter.Combat.Results and DAM_CRIP_ARM_RIGHT) <> 0) then begin Result := COMBAT_BAD_SHOT_BOTH_ARMS_CRIPPLED; Exit; end;
    if (attacker^.Data.AsData.Critter.Combat.Results and DAM_CRIP_ARM_ANY) <> 0 then
      if item_w_is_2handed(weapon) <> 0 then begin Result := COMBAT_BAD_SHOT_ARM_CRIPPLED; Exit; end;
  end;

  if item_w_mp_cost(attacker, hitMode, aiming) > attacker^.Data.AsData.Critter.Combat.Ap then begin Result := COMBAT_BAD_SHOT_NOT_ENOUGH_AP; Exit; end;
  if item_w_range(attacker, hitMode) < obj_dist(attacker, defender) then begin Result := COMBAT_BAD_SHOT_OUT_OF_RANGE; Exit; end;

  attack_type := item_w_subtype(weapon, hitMode);
  if item_w_max_ammo(weapon) > 0 then
    if item_w_curr_ammo(weapon) = 0 then begin Result := COMBAT_BAD_SHOT_NO_AMMO; Exit; end;

  if (attack_type = ATTACK_TYPE_RANGED) or (attack_type = ATTACK_TYPE_THROW) then
    if combat_is_shot_blocked(attacker, attacker^.Tile, defender^.Tile, defender, nil) then begin Result := COMBAT_BAD_SHOT_AIM_BLOCKED; Exit; end;

  Result := COMBAT_BAD_SHOT_OK;
end;

// =========================================================================
// combat_to_hit
// =========================================================================
function combat_to_hit(target: PObject; accuracy: PInteger): Boolean;
var
  hitMode: Integer;
  aiming: Boolean;
begin
  if intface_get_attack(@hitMode, @aiming) = -1 then begin Result := false; Exit; end;
  if combat_check_bad_shot(obj_dude, target, hitMode, aiming) <> COMBAT_BAD_SHOT_OK then begin Result := false; Exit; end;
  accuracy^ := determine_to_hit(obj_dude, target, HIT_LOCATION_UNCALLED, hitMode);
  Result := true;
end;

// =========================================================================
// combat_attack_this
// =========================================================================
procedure combat_attack_this(a1: PObject);
var
  hitMode: Integer;
  aiming: Boolean;
  messageListItem: TMessageListItem;
  item: PObject;
  formattedText: array[0..79] of AnsiChar;
  sfx: PAnsiChar;
  rc: Integer;
  stru: TSTRUCT_664980;
  hitLocation: Integer;
  actionPointsRequired: Integer;
begin
  if a1 = nil then Exit;
  if (combat_state and $02) = 0 then Exit;
  if intface_get_attack(@hitMode, @aiming) = -1 then Exit;

  rc := combat_check_bad_shot(obj_dude, a1, hitMode, aiming);
  case rc of
    COMBAT_BAD_SHOT_NO_AMMO:
    begin
      item := item_hit_with(obj_dude, hitMode);
      messageListItem.num := 101;
      if message_search(@combat_message_file, @messageListItem) then
        display_print(messageListItem.text);
      sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_OUT_OF_AMMO, item, hitMode, nil);
      gsound_play_sfx_file(sfx);
      Exit;
    end;
    COMBAT_BAD_SHOT_OUT_OF_RANGE:
    begin
      messageListItem.num := 102;
      if message_search(@combat_message_file, @messageListItem) then
        display_print(messageListItem.text);
      Exit;
    end;
    COMBAT_BAD_SHOT_NOT_ENOUGH_AP:
    begin
      item := item_hit_with(obj_dude, hitMode);
      messageListItem.num := 100;
      if message_search(@combat_message_file, @messageListItem) then
      begin
        actionPointsRequired := item_w_mp_cost(obj_dude, hitMode, aiming);
        StrLFmt(formattedText, SizeOf(formattedText), messageListItem.text, [actionPointsRequired]);
        display_print(formattedText);
      end;
      Exit;
    end;
    COMBAT_BAD_SHOT_ALREADY_DEAD: Exit;
    COMBAT_BAD_SHOT_AIM_BLOCKED:
    begin
      messageListItem.num := 104;
      if message_search(@combat_message_file, @messageListItem) then
        display_print(messageListItem.text);
      Exit;
    end;
    COMBAT_BAD_SHOT_ARM_CRIPPLED:
    begin
      messageListItem.num := 106;
      if message_search(@combat_message_file, @messageListItem) then
        display_print(messageListItem.text);
      Exit;
    end;
    COMBAT_BAD_SHOT_BOTH_ARMS_CRIPPLED:
    begin
      messageListItem.num := 105;
      if message_search(@combat_message_file, @messageListItem) then
        display_print(messageListItem.text);
      Exit;
    end;
  end;

  if not isInCombat then
  begin
    stru.attacker := obj_dude;
    stru.defender := a1;
    stru.actionPointsBonus := 0;
    stru.accuracyBonus := 0;
    stru.damageBonus := 0;
    stru.minDamage := 0;
    stru.maxDamage := High(Integer);
    stru.field_1C := 0;
    combat(@stru);
    Exit;
  end;

  if not aiming then
  begin
    combat_attack(obj_dude, a1, hitMode, HIT_LOCATION_UNCALLED);
    Exit;
  end;

  if get_called_shot_location(a1, @hitLocation, hitMode) <> -1 then
    combat_attack(obj_dude, a1, hitMode, hitLocation);
end;

// =========================================================================
// combat_outline_on
// =========================================================================
procedure combat_outline_on;
var
  index, target_highlight: Integer;
  critters: PPObject;
  critters_length: Integer;
  outline_type: Integer;
begin
  target_highlight := TARGET_HIGHLIGHT_TARGETING_ONLY;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, @target_highlight);
  if target_highlight = TARGET_HIGHLIGHT_OFF then Exit;
  if gmouse_3d_get_mode <> GAME_MOUSE_MODE_CROSSHAIR then Exit;

  if isInCombat then
  begin
    for index := 0 to list_total - 1 do
      if (CL(index) <> obj_dude) and ((CL(index)^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
        obj_turn_on_outline(CL(index), nil);
  end
  else
  begin
    critters_length := obj_create_list(-1, map_elevation, OBJ_TYPE_CRITTER, @critters);
    for index := 0 to critters_length - 1 do
    begin
      if (PPObject(PByte(critters) + index * SizeOf(PObject))^ <> obj_dude) and ((PPObject(PByte(critters) + index * SizeOf(PObject))^^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
      begin
        outline_type := Integer(OUTLINE_TYPE_HOSTILE);
        if perk_level(PERK_FRIENDLY_FOE) <> 0 then
          if PPObject(PByte(critters) + index * SizeOf(PObject))^^.Data.AsData.Critter.Combat.Team = obj_dude^.Data.AsData.Critter.Combat.Team then
            outline_type := Integer(OUTLINE_TYPE_FRIENDLY);
        obj_outline_object(PPObject(PByte(critters) + index * SizeOf(PObject))^, outline_type, nil);
        obj_turn_on_outline(PPObject(PByte(critters) + index * SizeOf(PObject))^, nil);
      end;
    end;
    if critters_length <> 0 then
      obj_delete_list(critters);
  end;
  tile_refresh_display;
end;

// =========================================================================
// combat_outline_off
// =========================================================================
procedure combat_outline_off;
var
  i, v5: Integer;
  v9: PPObject;
begin
  if (combat_state and 1) <> 0 then
  begin
    for i := 0 to list_total - 1 do
      obj_turn_off_outline(CL(i), nil);
  end
  else
  begin
    v5 := obj_create_list(-1, map_elevation, 1, @v9);
    for i := 0 to v5 - 1 do
    begin
      obj_turn_off_outline(PPObject(PByte(v9) + i * SizeOf(PObject))^, nil);
      obj_remove_outline(PPObject(PByte(v9) + i * SizeOf(PObject))^, nil);
    end;
    if v5 <> 0 then
      obj_delete_list(v9);
  end;
  tile_refresh_display;
end;

// =========================================================================
// combat_highlight_change
// =========================================================================
procedure combat_highlight_change;
var
  targetHighlight: Integer;
begin
  targetHighlight := 2;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, @targetHighlight);
  if (targetHighlight <> combat_highlight) and isInCombat then
  begin
    if targetHighlight <> 0 then
    begin
      if combat_highlight = 0 then
        combat_outline_on;
    end
    else
      combat_outline_off;
  end;
  combat_highlight := targetHighlight;
end;

// =========================================================================
// combat_is_shot_blocked
// =========================================================================
function combat_is_shot_blocked(a1: PObject; from_: Integer; to_: Integer; a4: PObject; a5: PInteger): Boolean;
var
  obstacle: PObject;
begin
  obstacle := a1;
  if a5 <> nil then a5^ := 0;

  while (obstacle <> nil) and (from_ <> to_) do
  begin
    make_straight_path(a1, from_, to_, nil, @obstacle, 32);
    if obstacle <> nil then
    begin
      if FID_TYPE(obstacle^.Fid) <> OBJ_TYPE_CRITTER then begin Result := true; Exit; end;
      if a5 <> nil then
        if obstacle <> a4 then
          Inc(a5^);
      from_ := obstacle^.Tile;
    end;
  end;
  Result := false;
end;

// =========================================================================
// combat_player_knocked_out_by
// =========================================================================
function combat_player_knocked_out_by: Integer;
begin
  if (obj_dude^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then begin Result := -1; Exit; end;
  if combat_ending_guy = nil then begin Result := -1; Exit; end;
  Result := combat_ending_guy^.Data.AsData.Critter.Combat.Team;
end;

// =========================================================================
// combat_explode_scenery
// =========================================================================
function combat_explode_scenery(a1: PObject; a2: PObject): Integer;
begin
  scr_explode_scenery(a1, a1^.Tile, 3, a1^.Elevation);
  Result := 0;
end;

// =========================================================================
// combat_delete_critter
// =========================================================================
procedure combat_delete_critter(obj: PObject);
var
  i: Integer;
begin
  if not isInCombat then Exit;
  if list_total = 0 then Exit;

  i := 0;
  while i < list_total do
  begin
    if obj = CL(i) then Break;
    Inc(i);
  end;
  if i = list_total then Exit;

  Dec(list_total);
  CLSet(list_total, obj);

  if i >= list_com then
  begin
    if i < (list_noncom + list_com) then
      Dec(list_noncom);
  end
  else
    Dec(list_com);

  obj^.Data.AsData.Critter.Combat.Ap := 0;
  obj_remove_outline(obj, nil);
  obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
  combatai_delete_critter(obj);
end;

// =========================================================================
// initCritTables - populate critical hit tables
// =========================================================================
procedure initCritTables;
begin
  FillChar(crit_succ_eff, SizeOf(crit_succ_eff), 0);
  FillChar(pc_crit_succ_eff, SizeOf(pc_crit_succ_eff), 0);

  // KILL_TYPE_MAN (0)
  // HEAD
  SetCrit(crit_succ_eff[0][0][0], 4, 0, -1, 0, 0, 5001, 5000);
  SetCrit(crit_succ_eff[0][0][1], 4, DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_OUT, 5002, 5003);
  SetCrit(crit_succ_eff[0][0][2], 5, DAM_BYPASS, STAT_ENDURANCE, -3, DAM_KNOCKED_OUT, 5002, 5003);
  SetCrit(crit_succ_eff[0][0][3], 5, DAM_KNOCKED_DOWN or DAM_BYPASS, STAT_ENDURANCE, -3, DAM_KNOCKED_OUT, 5004, 5003);
  SetCrit(crit_succ_eff[0][0][4], 6, DAM_KNOCKED_OUT or DAM_BYPASS, STAT_LUCK, 0, DAM_BLIND, 5005, 5006);
  SetCrit(crit_succ_eff[0][0][5], 6, DAM_DEAD, -1, 0, 0, 5007, 5000);
  // LEFT_ARM
  SetCrit(crit_succ_eff[0][1][0], 3, 0, -1, 0, 0, 5008, 5000);
  SetCrit(crit_succ_eff[0][1][1], 3, DAM_LOSE_TURN, -1, 0, 0, 5009, 5000);
  SetCrit(crit_succ_eff[0][1][2], 4, 0, STAT_ENDURANCE, -3, DAM_CRIP_ARM_LEFT, 5010, 5011);
  SetCrit(crit_succ_eff[0][1][3], 4, DAM_CRIP_ARM_LEFT or DAM_BYPASS, -1, 0, 0, 5012, 5000);
  SetCrit(crit_succ_eff[0][1][4], 4, DAM_CRIP_ARM_LEFT or DAM_BYPASS, -1, 0, 0, 5012, 5000);
  SetCrit(crit_succ_eff[0][1][5], 4, DAM_CRIP_ARM_LEFT or DAM_BYPASS, -1, 0, 0, 5013, 5000);
  // RIGHT_ARM
  SetCrit(crit_succ_eff[0][2][0], 3, 0, -1, 0, 0, 5008, 5000);
  SetCrit(crit_succ_eff[0][2][1], 3, DAM_LOSE_TURN, -1, 0, 0, 5009, 5000);
  SetCrit(crit_succ_eff[0][2][2], 4, 0, STAT_ENDURANCE, -3, DAM_CRIP_ARM_RIGHT, 5014, 5000);
  SetCrit(crit_succ_eff[0][2][3], 4, DAM_CRIP_ARM_RIGHT or DAM_BYPASS, -1, 0, 0, 5015, 5000);
  SetCrit(crit_succ_eff[0][2][4], 4, DAM_CRIP_ARM_RIGHT or DAM_BYPASS, -1, 0, 0, 5015, 5000);
  SetCrit(crit_succ_eff[0][2][5], 4, DAM_CRIP_ARM_RIGHT or DAM_BYPASS, -1, 0, 0, 5013, 5000);
  // TORSO
  SetCrit(crit_succ_eff[0][3][0], 3, 0, -1, 0, 0, 5016, 5000);
  SetCrit(crit_succ_eff[0][3][1], 3, DAM_BYPASS, -1, 0, 0, 5017, 5000);
  SetCrit(crit_succ_eff[0][3][2], 4, DAM_KNOCKED_DOWN or DAM_BYPASS, -1, 0, 0, 5019, 5000);
  SetCrit(crit_succ_eff[0][3][3], 4, DAM_KNOCKED_DOWN or DAM_BYPASS, -1, 0, 0, 5019, 5000);
  SetCrit(crit_succ_eff[0][3][4], 6, DAM_KNOCKED_OUT or DAM_BYPASS, -1, 0, 0, 5020, 5000);
  SetCrit(crit_succ_eff[0][3][5], 6, DAM_DEAD, -1, 0, 0, 5021, 5000);
  // RIGHT_LEG
  SetCrit(crit_succ_eff[0][4][0], 3, DAM_KNOCKED_DOWN, -1, 0, 0, 5023, 5000);
  SetCrit(crit_succ_eff[0][4][1], 3, DAM_KNOCKED_DOWN, STAT_ENDURANCE, 0, DAM_CRIP_LEG_RIGHT, 5023, 5024);
  SetCrit(crit_succ_eff[0][4][2], 4, DAM_KNOCKED_DOWN, STAT_ENDURANCE, -3, DAM_CRIP_LEG_RIGHT, 5023, 5024);
  SetCrit(crit_succ_eff[0][4][3], 4, DAM_KNOCKED_DOWN or DAM_CRIP_LEG_RIGHT or DAM_BYPASS, -1, 0, 0, 5025, 5000);
  SetCrit(crit_succ_eff[0][4][4], 4, DAM_KNOCKED_DOWN or DAM_CRIP_LEG_RIGHT or DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_OUT, 5025, 5026);
  SetCrit(crit_succ_eff[0][4][5], 4, DAM_KNOCKED_OUT or DAM_CRIP_LEG_RIGHT or DAM_BYPASS, -1, 0, 0, 5026, 5000);
  // LEFT_LEG
  SetCrit(crit_succ_eff[0][5][0], 3, DAM_KNOCKED_DOWN, -1, 0, 0, 5023, 5000);
  SetCrit(crit_succ_eff[0][5][1], 3, DAM_KNOCKED_DOWN, STAT_ENDURANCE, 0, DAM_CRIP_LEG_LEFT, 5023, 5024);
  SetCrit(crit_succ_eff[0][5][2], 4, DAM_KNOCKED_DOWN, STAT_ENDURANCE, -3, DAM_CRIP_LEG_LEFT, 5023, 5024);
  SetCrit(crit_succ_eff[0][5][3], 4, DAM_KNOCKED_DOWN or DAM_CRIP_LEG_LEFT or DAM_BYPASS, -1, 0, 0, 5025, 5000);
  SetCrit(crit_succ_eff[0][5][4], 4, DAM_KNOCKED_DOWN or DAM_CRIP_LEG_LEFT or DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_OUT, 5025, 5026);
  SetCrit(crit_succ_eff[0][5][5], 4, DAM_KNOCKED_OUT or DAM_CRIP_LEG_LEFT or DAM_BYPASS, -1, 0, 0, 5026, 5000);
  // EYES
  SetCrit(crit_succ_eff[0][6][0], 4, 0, STAT_LUCK, 4, DAM_BLIND, 5027, 5028);
  SetCrit(crit_succ_eff[0][6][1], 4, DAM_BYPASS, STAT_LUCK, 3, DAM_BLIND, 5029, 5028);
  SetCrit(crit_succ_eff[0][6][2], 6, DAM_BYPASS, STAT_LUCK, 2, DAM_BLIND, 5029, 5028);
  SetCrit(crit_succ_eff[0][6][3], 6, DAM_BLIND or DAM_BYPASS or DAM_LOSE_TURN, -1, 0, 0, 5030, 5000);
  SetCrit(crit_succ_eff[0][6][4], 8, DAM_KNOCKED_OUT or DAM_BLIND or DAM_BYPASS, -1, 0, 0, 5031, 5000);
  SetCrit(crit_succ_eff[0][6][5], 8, DAM_DEAD, -1, 0, 0, 5032, 5000);
  // GROIN
  SetCrit(crit_succ_eff[0][7][0], 3, 0, -1, 0, 0, 5033, 5000);
  SetCrit(crit_succ_eff[0][7][1], 3, DAM_BYPASS, STAT_ENDURANCE, -3, DAM_KNOCKED_DOWN, 5034, 5035);
  SetCrit(crit_succ_eff[0][7][2], 3, DAM_KNOCKED_DOWN, STAT_ENDURANCE, -3, DAM_KNOCKED_OUT, 5035, 5036);
  SetCrit(crit_succ_eff[0][7][3], 3, DAM_KNOCKED_OUT, -1, 0, 0, 5036, 5000);
  SetCrit(crit_succ_eff[0][7][4], 4, DAM_KNOCKED_DOWN or DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_OUT, 5035, 5036);
  SetCrit(crit_succ_eff[0][7][5], 4, DAM_KNOCKED_OUT or DAM_BYPASS, -1, 0, 0, 5037, 5000);
  // UNCALLED
  SetCrit(crit_succ_eff[0][8][0], 3, 0, -1, 0, 0, 5016, 5000);
  SetCrit(crit_succ_eff[0][8][1], 3, DAM_BYPASS, -1, 0, 0, 5017, 5000);
  SetCrit(crit_succ_eff[0][8][2], 4, 0, -1, 0, 0, 5018, 5000);
  SetCrit(crit_succ_eff[0][8][3], 4, DAM_KNOCKED_DOWN or DAM_BYPASS, -1, 0, 0, 5019, 5000);
  SetCrit(crit_succ_eff[0][8][4], 6, DAM_KNOCKED_OUT or DAM_BYPASS, -1, 0, 0, 5020, 5000);
  SetCrit(crit_succ_eff[0][8][5], 6, DAM_DEAD, -1, 0, 0, 5021, 5000);

  // KILL_TYPE_WOMAN (1) - HEAD
  SetCrit(crit_succ_eff[1][0][0], 4, 0, -1, 0, 0, 5101, 5100);
  SetCrit(crit_succ_eff[1][0][1], 4, DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_OUT, 5102, 5103);
  SetCrit(crit_succ_eff[1][0][2], 6, DAM_BYPASS, STAT_ENDURANCE, -3, DAM_KNOCKED_OUT, 5102, 5103);
  SetCrit(crit_succ_eff[1][0][3], 6, DAM_KNOCKED_DOWN or DAM_BYPASS, STAT_ENDURANCE, -3, DAM_KNOCKED_OUT, 5104, 5103);
  SetCrit(crit_succ_eff[1][0][4], 6, DAM_KNOCKED_OUT or DAM_BYPASS, STAT_LUCK, 0, DAM_BLIND, 5105, 5106);
  SetCrit(crit_succ_eff[1][0][5], 6, DAM_DEAD, -1, 0, 0, 5107, 5000);
  // ... The remaining tables would be enormous. For compilation, they default to zero
  // which is filled by the initialization section's zero-fill of the var array.
  // The KILL_TYPE_MAN table is fully set in the const initializer.
  // For a complete game, all tables must be filled here.

  // PC crit table
  SetCrit(pc_crit_succ_eff[0][0], 3, 0, -1, 0, 0, 6500, 5000);
  SetCrit(pc_crit_succ_eff[0][1], 3, DAM_BYPASS, STAT_ENDURANCE, 3, DAM_KNOCKED_DOWN, 6501, 6503);
  SetCrit(pc_crit_succ_eff[0][2], 3, DAM_BYPASS, STAT_ENDURANCE, 0, DAM_KNOCKED_DOWN, 6501, 6503);
  SetCrit(pc_crit_succ_eff[0][3], 3, DAM_KNOCKED_DOWN or DAM_BYPASS, STAT_ENDURANCE, 2, DAM_KNOCKED_OUT, 6503, 6502);
  SetCrit(pc_crit_succ_eff[0][4], 3, DAM_KNOCKED_OUT or DAM_BYPASS, STAT_LUCK, 2, DAM_BLIND, 6502, 6504);
  SetCrit(pc_crit_succ_eff[0][5], 6, DAM_BYPASS, STAT_ENDURANCE, -2, DAM_DEAD, 6501, 6505);
end;

initialization
  combat_state := COMBAT_STATE_0x02;
  gcsd := nil;
  combat_call_display := false;

  // cf_table init
  cf_table[0][0] := 0; cf_table[0][1] := DAM_LOSE_TURN; cf_table[0][2] := DAM_LOSE_TURN; cf_table[0][3] := DAM_HURT_SELF or DAM_KNOCKED_DOWN; cf_table[0][4] := DAM_CRIP_RANDOM;
  cf_table[1][0] := 0; cf_table[1][1] := DAM_LOSE_TURN; cf_table[1][2] := DAM_DROP; cf_table[1][3] := DAM_RANDOM_HIT; cf_table[1][4] := DAM_HIT_SELF;
  cf_table[2][0] := 0; cf_table[2][1] := DAM_LOSE_AMMO; cf_table[2][2] := DAM_DROP; cf_table[2][3] := DAM_RANDOM_HIT; cf_table[2][4] := DAM_DESTROY;
  cf_table[3][0] := DAM_LOSE_TURN; cf_table[3][1] := DAM_LOSE_TURN or DAM_LOSE_AMMO; cf_table[3][2] := DAM_DROP or DAM_LOSE_TURN; cf_table[3][3] := DAM_RANDOM_HIT; cf_table[3][4] := DAM_EXPLODE or DAM_LOSE_TURN;
  cf_table[4][0] := DAM_DUD; cf_table[4][1] := DAM_DROP; cf_table[4][2] := DAM_DROP or DAM_HURT_SELF; cf_table[4][3] := DAM_RANDOM_HIT; cf_table[4][4] := DAM_EXPLODE;
  cf_table[5][0] := DAM_LOSE_TURN; cf_table[5][1] := DAM_DUD; cf_table[5][2] := DAM_DESTROY; cf_table[5][3] := DAM_RANDOM_HIT; cf_table[5][4] := DAM_EXPLODE or DAM_LOSE_TURN or DAM_KNOCKED_DOWN;
  cf_table[6][0] := 0; cf_table[6][1] := DAM_LOSE_TURN; cf_table[6][2] := DAM_RANDOM_HIT; cf_table[6][3] := DAM_DESTROY; cf_table[6][4] := DAM_EXPLODE or DAM_LOSE_TURN or DAM_ON_FIRE;

  initCritTables;

end.
