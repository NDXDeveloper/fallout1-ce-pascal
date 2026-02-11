{$MODE OBJFPC}{$H+}
// Converted from: src/int/support/intextra.cc/h
// Script opcode handlers for Fallout's scripting engine.
// This is the largest file, containing all game-specific opcode handler
// procedures that are registered with the interpreter.
unit u_intextra;

interface

uses
  u_intrpret, u_object_types;

const
  // ScriptError
  SCRIPT_ERROR_NOT_IMPLEMENTED           = 0;
  SCRIPT_ERROR_OBJECT_IS_NULL            = 1;
  SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID = 2;
  SCRIPT_ERROR_FOLLOWS                   = 3;
  SCRIPT_ERROR_COUNT                     = 4;

procedure dbg_error(program_: PProgram; name: PAnsiChar; error: Integer);
function correctDeath(critter: PObject; anim: Integer; forceBack: Boolean): Integer;
procedure intExtraClose;
procedure initIntExtra;
procedure updateIntExtra;
procedure intExtraRemoveProgramReferences(program_: PProgram);

implementation

uses
  SysUtils, Math,
  u_debug, u_rect, u_color, u_anim, u_art,
  u_gconfig, u_config, u_gmovie,
  u_proto_types, u_stat_defs, u_skill_defs, u_perk_defs,
  u_combat_defs, u_map_defs, u_game_vars,
  u_svga, u_vcr,
  u_scripts, u_stat, u_skill, u_perk, u_trait,
  u_critter, u_object, u_protinst, u_proto,
  u_item, u_inventry,
  u_tile, u_map, u_gsound, u_display, u_intface,
  u_combat, u_combatai, u_actions,
  u_game, u_loadsave, u_palette, u_queue,
  u_reaction, u_roll, u_party, u_textobj,
  u_gdialog, u_light, u_endgame, u_cache;

{ =========================================================================
  Constants from various C headers (game modules not yet converted)
  ========================================================================= }
const
  // Metarule
  METARULE_SIGNAL_END_GAME = 13;
  METARULE_FIRST_RUN       = 14;
  METARULE_ELEVATOR        = 15;
  METARULE_PARTY_COUNT     = 16;
  METARULE_IS_LOADGAME     = 22;

  // CritterTrait
  CRITTER_TRAIT_PERK   = 0;
  CRITTER_TRAIT_OBJECT = 1;
  CRITTER_TRAIT_TRAIT  = 2;

  // CritterTraitObject
  CRITTER_TRAIT_OBJECT_AI_PACKET            = 5;
  CRITTER_TRAIT_OBJECT_TEAM                 = 6;
  CRITTER_TRAIT_OBJECT_ROTATION             = 10;
  CRITTER_TRAIT_OBJECT_IS_INVISIBLE         = 666;
  CRITTER_TRAIT_OBJECT_GET_INVENTORY_WEIGHT = 669;

  // CritterState
  CRITTER_STATE_NORMAL = $00;
  CRITTER_STATE_DEAD   = $01;
  CRITTER_STATE_PRONE  = $02;

  // InvenType
  INVEN_TYPE_WORN       = 0;
  INVEN_TYPE_RIGHT_HAND = 1;
  INVEN_TYPE_LEFT_HAND  = 2;
  INVEN_TYPE_INV_COUNT  = -2;

  // FloatingMessageType
  FLOATING_MESSAGE_TYPE_WARNING        = -2;
  FLOATING_MESSAGE_TYPE_COLOR_SEQUENCE = -1;
  FLOATING_MESSAGE_TYPE_NORMAL         = 0;
  FLOATING_MESSAGE_TYPE_BLACK          = 1;
  FLOATING_MESSAGE_TYPE_RED            = 2;
  FLOATING_MESSAGE_TYPE_GREEN          = 3;
  FLOATING_MESSAGE_TYPE_BLUE           = 4;
  FLOATING_MESSAGE_TYPE_PURPLE         = 5;
  FLOATING_MESSAGE_TYPE_NEAR_WHITE     = 6;
  FLOATING_MESSAGE_TYPE_LIGHT_RED      = 7;
  FLOATING_MESSAGE_TYPE_YELLOW         = 8;
  FLOATING_MESSAGE_TYPE_WHITE          = 9;
  FLOATING_MESSAGE_TYPE_GREY           = 10;
  FLOATING_MESSAGE_TYPE_DARK_GREY      = 11;
  FLOATING_MESSAGE_TYPE_LIGHT_GREY     = 12;
  FLOATING_MESSAGE_TYPE_COUNT          = 13;

  // OpRegAnimFunc
  OP_REG_ANIM_FUNC_BEGIN = 1;
  OP_REG_ANIM_FUNC_CLEAR = 2;
  OP_REG_ANIM_FUNC_END   = 3;

  // From scripts.h
  GAME_TIME_TICKS_PER_DAY  = 24 * 60 * 60 * 10;
  SCRIPT_TYPE_SYSTEM   = 0;
  SCRIPT_TYPE_SPATIAL  = 1;
  SCRIPT_TYPE_TIMED    = 2;
  SCRIPT_TYPE_ITEM     = 3;
  SCRIPT_TYPE_CRITTER  = 4;

  // From tile.h
  TILE_SET_CENTER_REFRESH_WINDOW                  = $01;
  TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS = $02;

  // From intface.h
  HAND_LEFT  = 0;
  HAND_RIGHT = 1;

  // From roll.h
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

  // From critter.h
  PC_FLAG_SNEAKING = 0;

  // From reaction.h
  NPC_REACTION_BAD     = 0;
  NPC_REACTION_NEUTRAL = 1;
  NPC_REACTION_GOOD    = 2;

  // From worldmap.h
  MAP_SAVED = $01;

  // From game.h
  GAME_STATE_4 = 4;

  // From trait.h
  TRAIT_COUNT = 16;

{ Types are now imported from: u_scripts (PScript, TScript, PPScript),
  u_map (TMapHeader, PMapTransition, TMapTransition),
  u_proto (PPProto, PProtoDataMemberValue, TProtoDataMemberValue),
  u_cache (PCacheEntry), u_art (PArt) }

{ All external declarations have been removed.
  Variables and functions are now imported from their respective units:
  u_object (obj_dude), u_tile (tile_center_tile),
  u_map (map_elevation, map_data), u_game (num_game_global_vars,
  game_global_vars, game_user_wants_to_quit), u_gdialog (dialogue_head,
  dialogue_scr_id, dialog_target), u_palette (black_palette),
  u_scripts, u_stat, u_skill, u_perk, u_trait, u_critter, u_protinst,
  u_proto, u_item, u_inventry, u_gsound, u_display, u_intface,
  u_combat, u_combatai, u_actions, u_loadsave, u_queue, u_reaction,
  u_roll, u_party, u_textobj, u_light, u_endgame, u_vcr, u_cache }

{ =========================================================================
  Module-level implementation variables (C++ static locals)
  ========================================================================= }
var
  _aCritter: array[0..9] of AnsiChar = '<Critter>'#0;
  dialogue_mood: Integer = 0;
  // static in op_float_msg
  last_color: Integer = 1;
  // static in op_obj_name
  strName: PAnsiChar = nil;
  // static in objs_area_turn_on_off
  objs_area_rect: TRect;

{ =========================================================================
  dbg_error_strs (static const in dbg_error)
  ========================================================================= }
const
  dbg_error_strs: array[0..SCRIPT_ERROR_COUNT - 1] of PAnsiChar = (
    'unimped',
    'obj is NULL',
    'can''t match program to sid',
    'follows'
  );

{ =========================================================================
  Helper: int_debug  (C++ static void int_debug(const char* format, ...))
  ========================================================================= }
procedure int_debug(const fmt: PAnsiChar); overload;
begin
  debug_printf(fmt);
end;

procedure int_debug(const fmt: string; const args: array of const); overload;
begin
  debug_printf(fmt, args);
end;

{ =========================================================================
  dbg_error
  ========================================================================= }
procedure dbg_error(program_: PProgram; name: PAnsiChar; error: Integer);
var
  s: string;
begin
  s := Format('Script Error: %s: op_%s: %s', [string(program_^.name), string(name), string(dbg_error_strs[error])]);
  debug_printf(PAnsiChar(s));
end;

{ =========================================================================
  scripts_tile_is_visible
  ========================================================================= }
function scripts_tile_is_visible(tile: Integer): Integer;
begin
  if (Abs(tile_center_tile - tile) mod 200) < 5 then
    Exit(1);
  if (Abs(tile_center_tile - tile) div 200) < 5 then
    Exit(1);
  Result := 0;
end;

{ =========================================================================
  correctFidForRemovedItem
  ========================================================================= }
function correctFidForRemovedItem(critter, item: PObject; flags: Integer): Integer;
var
  fid, anim_, newFid: Integer;
  rect: TRect;
begin
  if critter = obj_dude then
    intface_update_items(True);

  fid := critter^.Fid;
  anim_ := (fid and $F000) shr 12;
  newFid := -1;

  if (flags and OBJECT_IN_ANY_HAND) <> 0 then
  begin
    if critter = obj_dude then
    begin
      if intface_is_item_right_hand() <> 0 then
      begin
        if (flags and OBJECT_IN_RIGHT_HAND) <> 0 then
          anim_ := 0;
      end
      else
      begin
        if (flags and OBJECT_IN_LEFT_HAND) <> 0 then
          anim_ := 0;
      end;
    end
    else
    begin
      if (flags and OBJECT_IN_RIGHT_HAND) <> 0 then
        anim_ := 0;
    end;

    if anim_ = 0 then
      newFid := art_id(FID_TYPE(fid), fid and $FFF, FID_ANIM_TYPE(fid), 0, (fid and $70000000) shr 28);
  end
  else
  begin
    if critter = obj_dude then
    begin
      newFid := art_id(FID_TYPE(fid), art_vault_guy_num, FID_ANIM_TYPE(fid), anim_, (fid and $70000000) shr 28);
      adjust_ac(obj_dude, item, nil);
    end;
  end;

  if newFid <> -1 then
  begin
    obj_change_fid(critter, newFid, @rect);
    tile_refresh_rect(@rect, map_elevation);
  end;

  Result := 0;
end;

{ =========================================================================
  op_give_exp_points
  ========================================================================= }
procedure op_give_exp_points(program_: PProgram); cdecl;
var
  xp: Integer;
begin
  xp := programStackPopInteger(program_);
  if stat_pc_add_experience(xp) <> 0 then
    int_debug(#10'Script Error: %s: op_give_exp_points: stat_pc_set failed', [string(program_^.name)]);
end;

{ =========================================================================
  op_scr_return
  ========================================================================= }
procedure op_scr_return(program_: PProgram); cdecl;
var
  data, sid: Integer;
  script: PScript;
begin
  data := programStackPopInteger(program_);
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    script^.field_28 := data;
end;

{ =========================================================================
  op_play_sfx
  ========================================================================= }
procedure op_play_sfx(program_: PProgram); cdecl;
var
  name: PAnsiChar;
begin
  name := programStackPopString(program_);
  gsound_play_sfx_file(name);
end;

{ =========================================================================
  op_set_map_start
  ========================================================================= }
procedure op_set_map_start(program_: PProgram); cdecl;
var
  rotation, elevation, y, x, tile: Integer;
begin
  rotation := programStackPopInteger(program_);
  elevation := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  if map_set_elevation(elevation) <> 0 then
  begin
    int_debug(#10'Script Error: %s: op_set_map_start: map_set_elevation failed', [string(program_^.name)]);
    Exit;
  end;

  tile := 200 * y + x;
  if tile_set_center(tile, TILE_SET_CENTER_REFRESH_WINDOW or TILE_SET_CENTER_FLAG_IGNORE_SCROLL_RESTRICTIONS) <> 0 then
  begin
    int_debug(#10'Script Error: %s: op_set_map_start: tile_set_center failed', [string(program_^.name)]);
    Exit;
  end;

  map_set_entrance_hex(tile, elevation, rotation);
end;

{ =========================================================================
  op_override_map_start
  ========================================================================= }
procedure op_override_map_start(program_: PProgram); cdecl;
var
  rotation, elevation, y, x, tile, previousTile: Integer;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  rotation := programStackPopInteger(program_);
  elevation := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  debug_printf('OVERRIDE_MAP_START: x: %d, y: %d', [x, y]);

  tile := 200 * y + x;
  previousTile := tile_center_tile;
  if tile <> -1 then
  begin
    if obj_set_rotation(obj_dude, rotation, nil) <> 0 then
      int_debug(#10'Error: %s: obj_set_rotation failed in override_map_start!', [string(program_^.name)]);

    if obj_move_to_tile(obj_dude, tile, elevation, nil) <> 0 then
    begin
      int_debug(#10'Error: %s: obj_move_to_tile failed in override_map_start!', [string(program_^.name)]);

      if obj_move_to_tile(obj_dude, previousTile, elevation, nil) <> 0 then
      begin
        int_debug(#10'Error: %s: obj_move_to_tile RECOVERY Also failed!', [string(program_^.name)]);
        Halt(1);
      end;
    end;

    tile_set_center(tile, TILE_SET_CENTER_REFRESH_WINDOW);
    tile_refresh_display;
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_has_skill
  ========================================================================= }
procedure op_has_skill(program_: PProgram); cdecl;
var
  skill: Integer;
  obj: PObject;
  result_: Integer;
begin
  skill := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  result_ := 0;
  if obj <> nil then
  begin
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
      result_ := skill_level(obj, skill);
  end
  else
    dbg_error(program_, 'has_skill', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_using_skill
  ========================================================================= }
procedure op_using_skill(program_: PProgram); cdecl;
var
  skill: Integer;
  obj: PObject;
  result_: Integer;
begin
  skill := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  result_ := 0;
  if (skill = Ord(SKILL_SNEAK)) and (obj = obj_dude) then
    result_ := Ord(is_pc_flag(PC_FLAG_SNEAKING));

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_roll_vs_skill
  ========================================================================= }
procedure op_roll_vs_skill(program_: PProgram); cdecl;
var
  modifier, skill, sid: Integer;
  obj: PObject;
  roll: Integer;
  script: PScript;
begin
  modifier := programStackPopInteger(program_);
  skill := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  roll := ROLL_CRITICAL_FAILURE;
  if obj <> nil then
  begin
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    begin
      sid := scr_find_sid_from_program(program_);
      if scr_ptr(sid, @script) <> -1 then
        roll := skill_result(obj, skill, modifier, @(script^.howMuch));
    end;
  end
  else
    dbg_error(program_, 'roll_vs_skill', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, roll);
end;

{ =========================================================================
  op_skill_contest
  ========================================================================= }
procedure op_skill_contest(program_: PProgram); cdecl;
var
  data: array[0..2] of Integer;
  arg: Integer;
begin
  for arg := 0 to 2 do
    data[arg] := programStackPopInteger(program_);

  dbg_error(program_, 'skill_contest', SCRIPT_ERROR_NOT_IMPLEMENTED);
  programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_do_check
  ========================================================================= }
procedure op_do_check(program_: PProgram); cdecl;
var
  mod_, stat_, sid, roll: Integer;
  obj: PObject;
  script: PScript;
begin
  mod_ := programStackPopInteger(program_);
  stat_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  roll := 0;
  if obj <> nil then
  begin
    sid := scr_find_sid_from_program(program_);
    if scr_ptr(sid, @script) <> -1 then
    begin
      case stat_ of
        Ord(STAT_STRENGTH)..Ord(STAT_LUCK):
          roll := stat_result(obj, stat_, mod_, @(script^.howMuch));
      else
        int_debug(#10'Script Error: %s: op_do_check: Stat out of range', [string(program_^.name)]);
      end;
    end;
  end
  else
    dbg_error(program_, 'do_check', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, roll);
end;

{ =========================================================================
  op_is_success
  ========================================================================= }
procedure op_is_success(program_: PProgram); cdecl;
var
  data, result_: Integer;
begin
  data := programStackPopInteger(program_);
  result_ := -1;
  case data of
    ROLL_CRITICAL_FAILURE, ROLL_FAILURE:
      result_ := 0;
    ROLL_SUCCESS, ROLL_CRITICAL_SUCCESS:
      result_ := 1;
  end;
  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_is_critical
  ========================================================================= }
procedure op_is_critical(program_: PProgram); cdecl;
var
  data, result_: Integer;
begin
  data := programStackPopInteger(program_);
  result_ := -1;
  case data of
    ROLL_CRITICAL_FAILURE, ROLL_CRITICAL_SUCCESS:
      result_ := 1;
    ROLL_FAILURE, ROLL_SUCCESS:
      result_ := 0;
  end;
  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_how_much
  ========================================================================= }
procedure op_how_much(program_: PProgram); cdecl;
var
  data, result_, sid: Integer;
  script: PScript;
begin
  data := programStackPopInteger(program_);
  result_ := 0;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    result_ := script^.howMuch
  else
    dbg_error(program_, 'how_much', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_reaction_roll
  ========================================================================= }
procedure op_reaction_roll(program_: PProgram); cdecl;
var
  data: array[0..2] of Integer;
  arg: Integer;
begin
  for arg := 0 to 2 do
    data[arg] := programStackPopInteger(program_);
  programStackPushInteger(program_, reaction_roll(data[2], data[1], data[0]));
end;

{ =========================================================================
  op_reaction_influence
  ========================================================================= }
procedure op_reaction_influence(program_: PProgram); cdecl;
var
  data: array[0..2] of Integer;
  arg: Integer;
begin
  for arg := 0 to 2 do
    data[arg] := programStackPopInteger(program_);
  programStackPushInteger(program_, reaction_influence(data[2], data[1], data[0]));
end;

{ =========================================================================
  op_random
  ========================================================================= }
procedure op_random(program_: PProgram); cdecl;
var
  data: array[0..1] of Integer;
  arg, result_: Integer;
begin
  for arg := 0 to 1 do
    data[arg] := programStackPopInteger(program_);

  if vcr_status() = VCR_STATE_TURNED_OFF then
    result_ := roll_random(data[1], data[0])
  else
    result_ := (data[0] - data[1]) div 2;

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_roll_dice
  ========================================================================= }
procedure op_roll_dice(program_: PProgram); cdecl;
var
  data: array[0..1] of Integer;
  arg: Integer;
begin
  for arg := 0 to 1 do
    data[arg] := programStackPopInteger(program_);
  dbg_error(program_, 'roll_dice', SCRIPT_ERROR_NOT_IMPLEMENTED);
  programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_move_to
  ========================================================================= }
procedure op_move_to(program_: PProgram); cdecl;
var
  elevation, tile, newTile: Integer;
  obj: PObject;
  tileLimitingEnabled, tileBlockingEnabled: Boolean;
  rect, before, after: TRect;
begin
  elevation := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj <> nil then
  begin
    if obj = obj_dude then
    begin
      tileLimitingEnabled := tile_get_scroll_limiting;
      tileBlockingEnabled := tile_get_scroll_blocking;

      if tileLimitingEnabled then
        tile_disable_scroll_limiting;
      if tileBlockingEnabled then
        tile_disable_scroll_blocking;

      newTile := obj_move_to_tile(obj, tile, elevation, @rect);
      if newTile <> -1 then
        tile_set_center(obj^.Tile, TILE_SET_CENTER_REFRESH_WINDOW);

      if tileLimitingEnabled then
        tile_enable_scroll_limiting;
      if tileBlockingEnabled then
        tile_enable_scroll_blocking;
    end
    else
    begin
      obj_bound(obj, @before);

      if (obj^.Elevation <> elevation) and (PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER) then
        combat_delete_critter(obj);

      newTile := obj_move_to_tile(obj, tile, elevation, @after);
      if newTile <> -1 then
      begin
        rect_min_bound(@before, @after, @before);
        tile_refresh_rect(@before, map_elevation);
      end;
    end;
  end
  else
  begin
    dbg_error(program_, 'move_to', SCRIPT_ERROR_OBJECT_IS_NULL);
    newTile := -1;
  end;

  programStackPushInteger(program_, newTile);
end;

{ =========================================================================
  op_create_object_sid
  ========================================================================= }
procedure op_create_object_sid(program_: PProgram); cdecl;
label
  lbl_out;
var
  data: array[0..3] of Integer;
  arg, pid, tile, elevation, sid, scriptType: Integer;
  obj: PObject;
  proto: PProto;
  rect: TRect;
  script: PScript;
begin
  for arg := 0 to 3 do
    data[arg] := programStackPopInteger(program_);

  pid := data[3];
  tile := data[2];
  elevation := data[1];
  sid := data[0];

  obj := nil;

  if isLoadingGame() <> 0 then
  begin
    debug_printf(#10'Error: attempt to Create critter in load/save-game: %s!', [string(program_^.name)]);
    goto lbl_out;
  end;

  if proto_ptr(pid, @proto) <> -1 then
  begin
    if obj_new(@obj, proto^.Fid, pid) <> -1 then
    begin
      if tile = -1 then
        tile := 0;

      if obj_move_to_tile(obj, tile, elevation, @rect) <> -1 then
        tile_refresh_rect(@rect, obj^.Elevation);
    end;
  end;

  if sid <> -1 then
  begin
    scriptType := 0;
    case PID_TYPE(obj^.Pid) of
      OBJ_TYPE_CRITTER:
        scriptType := SCRIPT_TYPE_CRITTER;
      OBJ_TYPE_ITEM, OBJ_TYPE_SCENERY:
        scriptType := SCRIPT_TYPE_ITEM;
    end;

    if obj^.Sid <> -1 then
    begin
      scr_remove(obj^.Sid);
      obj^.Sid := -1;
    end;

    if scr_new(@(obj^.Sid), scriptType) = -1 then
      goto lbl_out;

    if scr_ptr(obj^.Sid, @script) = -1 then
      goto lbl_out;

    script^.scr_script_idx := sid - 1;
    obj^.Id := new_obj_id();
    script^.scr_oid := obj^.Id;
    script^.owner := obj;
    scr_find_str_run_info(sid - 1, @(script^.run_info_flags), obj^.Sid);
  end;

lbl_out:
  programStackPushPointer(program_, obj);
end;

{ =========================================================================
  op_destroy_object
  ========================================================================= }
procedure op_destroy_object(program_: PProgram); cdecl;
var
  obj, owner: PObject;
  isSelf: Boolean;
  quantity: Integer;
  rect: TRect;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'destroy_object', SCRIPT_ERROR_OBJECT_IS_NULL);
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    Exit;
  end;

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
  begin
    if isLoadingGame() <> 0 then
    begin
      debug_printf(#10'Error: attempt to destroy critter in load/save-game: %s!', [string(program_^.name)]);
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;
  end;

  isSelf := obj = scr_find_obj_from_program(program_);

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    combat_delete_critter(obj);

  owner := obj_top_environment(obj);
  if owner <> nil then
  begin
    quantity := item_count(owner, obj);
    item_remove_mult(owner, obj, quantity);

    if owner = obj_dude then
      intface_update_items(True);

    obj_connect(obj, 1, 0, nil);

    if isSelf then
    begin
      obj^.Sid := -1;
      obj^.Flags := obj^.Flags or (OBJECT_HIDDEN or OBJECT_NO_SAVE);
    end
    else
    begin
      register_clear(obj);
      obj_erase_object(obj, nil);
    end;
  end
  else
  begin
    register_clear(obj);
    obj_erase_object(obj, @rect);
    tile_refresh_rect(@rect, map_elevation);
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if isSelf then
    program_^.flags := program_^.flags or PROGRAM_FLAG_0x0100;
end;

{ =========================================================================
  op_display_msg
  ========================================================================= }
procedure op_display_msg(program_: PProgram); cdecl;
var
  str: PAnsiChar;
  showScriptMessages: Boolean;
begin
  str := programStackPopString(program_);
  display_print(str);

  showScriptMessages := False;
  configGetBool(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_SCRIPT_MESSAGES_KEY, @showScriptMessages);

  if showScriptMessages then
  begin
    debug_printf(#10);
    debug_printf(str);
  end;
end;

{ =========================================================================
  op_script_overrides
  ========================================================================= }
procedure op_script_overrides(program_: PProgram); cdecl;
var
  sid: Integer;
  script: PScript;
begin
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    script^.scriptOverrides := 1
  else
    dbg_error(program_, 'script_overrides', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
end;

{ =========================================================================
  op_obj_is_carrying_obj_pid
  ========================================================================= }
procedure op_obj_is_carrying_obj_pid(program_: PProgram); cdecl;
var
  pid: Integer;
  obj: PObject;
  result_: Integer;
begin
  pid := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  result_ := 0;
  if obj <> nil then
    result_ := inven_pid_quantity_carried(obj, pid)
  else
    dbg_error(program_, 'obj_is_carrying_obj_pid', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_tile_contains_obj_pid
  ========================================================================= }
procedure op_tile_contains_obj_pid(program_: PProgram); cdecl;
var
  pid, elevation, tile, result_: Integer;
  obj: PObject;
begin
  pid := programStackPopInteger(program_);
  elevation := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);

  result_ := 0;
  obj := obj_find_first_at(elevation);
  while obj <> nil do
  begin
    if (obj^.Tile = tile) and (obj^.Pid = pid) then
    begin
      result_ := 1;
      Break;
    end;
    obj := obj_find_next_at();
  end;

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_self_obj
  ========================================================================= }
procedure op_self_obj(program_: PProgram); cdecl;
begin
  programStackPushPointer(program_, scr_find_obj_from_program(program_));
end;

{ =========================================================================
  op_source_obj
  ========================================================================= }
procedure op_source_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := nil;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    obj := script^.source
  else
    dbg_error(program_, 'source_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushPointer(program_, obj);
end;

{ =========================================================================
  op_target_obj
  ========================================================================= }
procedure op_target_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := nil;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    obj := script^.target
  else
    dbg_error(program_, 'target_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushPointer(program_, obj);
end;

{ =========================================================================
  op_dude_obj
  ========================================================================= }
procedure op_dude_obj(program_: PProgram); cdecl;
begin
  programStackPushPointer(program_, obj_dude);
end;

{ =========================================================================
  op_obj_being_used_with
  ========================================================================= }
procedure op_obj_being_used_with(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := nil;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    obj := script^.target
  else
    dbg_error(program_, 'obj_being_used_with', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushPointer(program_, obj);
end;

{ =========================================================================
  op_local_var
  ========================================================================= }
procedure op_local_var(program_: PProgram); cdecl;
var
  data, sid: Integer;
  value: TProgramValue;
begin
  data := programStackPopInteger(program_);

  value.opcode := VALUE_TYPE_INT;
  value.integerValue := -1;

  sid := scr_find_sid_from_program(program_);
  scr_get_local_var(sid, data, value);

  programStackPushValue(program_, value);
end;

{ =========================================================================
  op_set_local_var
  ========================================================================= }
procedure op_set_local_var(program_: PProgram); cdecl;
var
  value: TProgramValue;
  variable, sid: Integer;
begin
  value := programStackPopValue(program_);
  variable := programStackPopInteger(program_);

  sid := scr_find_sid_from_program(program_);
  scr_set_local_var(sid, variable, value);
end;

{ =========================================================================
  op_map_var
  ========================================================================= }
procedure op_map_var(program_: PProgram); cdecl;
var
  data: Integer;
  value: TProgramValue;
begin
  data := programStackPopInteger(program_);

  if map_get_global_var(data, value) = -1 then
  begin
    value.opcode := VALUE_TYPE_INT;
    value.integerValue := -1;
  end;

  programStackPushValue(program_, value);
end;

{ =========================================================================
  op_set_map_var
  ========================================================================= }
procedure op_set_map_var(program_: PProgram); cdecl;
var
  value: TProgramValue;
  variable: Integer;
begin
  value := programStackPopValue(program_);
  variable := programStackPopInteger(program_);
  map_set_global_var(variable, value);
end;

{ =========================================================================
  op_global_var
  ========================================================================= }
procedure op_global_var(program_: PProgram); cdecl;
var
  data, value: Integer;
begin
  data := programStackPopInteger(program_);
  value := -1;
  if num_game_global_vars <> 0 then
    value := game_get_global_var(data)
  else
    int_debug(#10'Script Error: %s: op_global_var: no global vars found!', [string(program_^.name)]);

  programStackPushInteger(program_, value);
end;

{ =========================================================================
  op_set_global_var
  ========================================================================= }
procedure op_set_global_var(program_: PProgram); cdecl;
var
  value, variable: Integer;
begin
  value := programStackPopInteger(program_);
  variable := programStackPopInteger(program_);
  if num_game_global_vars <> 0 then
    game_set_global_var(variable, value)
  else
    int_debug(#10'Script Error: %s: op_set_global_var: no global vars found!', [string(program_^.name)]);
end;

{ =========================================================================
  op_script_action
  ========================================================================= }
procedure op_script_action(program_: PProgram); cdecl;
var
  action, sid: Integer;
  script: PScript;
begin
  action := 0;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    action := script^.action
  else
    dbg_error(program_, 'script_action', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushInteger(program_, action);
end;

{ =========================================================================
  op_obj_type
  ========================================================================= }
procedure op_obj_type(program_: PProgram); cdecl;
var
  obj: PObject;
  objectType: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  objectType := -1;
  if obj <> nil then
    objectType := FID_TYPE(obj^.Fid);
  programStackPushInteger(program_, objectType);
end;

{ =========================================================================
  op_obj_item_subtype
  ========================================================================= }
procedure op_obj_item_subtype(program_: PProgram); cdecl;
var
  obj: PObject;
  itemType: Integer;
  proto: PProto;
begin
  obj := PObject(programStackPopPointer(program_));
  itemType := -1;
  if obj <> nil then
  begin
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_ITEM then
    begin
      if proto_ptr(obj^.Pid, @proto) <> -1 then
        itemType := item_get_type(obj);
    end;
  end;
  programStackPushInteger(program_, itemType);
end;

{ =========================================================================
  op_get_critter_stat
  ========================================================================= }
procedure op_get_critter_stat(program_: PProgram); cdecl;
var
  stat_: Integer;
  obj: PObject;
  value: Integer;
begin
  stat_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  value := -1;
  if obj <> nil then
    value := stat_level(obj, stat_)
  else
    dbg_error(program_, 'get_critter_stat', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, value);
end;

{ =========================================================================
  op_set_critter_stat
  ========================================================================= }
procedure op_set_critter_stat(program_: PProgram); cdecl;
var
  value, stat_: Integer;
  obj: PObject;
  result_, currentValue: Integer;
begin
  value := programStackPopInteger(program_);
  stat_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  result_ := 0;
  if obj <> nil then
  begin
    if obj = obj_dude then
    begin
      currentValue := stat_get_base(obj, stat_);
      stat_set_base(obj, stat_, currentValue + value);
    end
    else
    begin
      dbg_error(program_, 'set_critter_stat', SCRIPT_ERROR_FOLLOWS);
      debug_printf(' Can''t modify anyone except obj_dude!');
      result_ := -1;
    end;
  end
  else
  begin
    dbg_error(program_, 'set_critter_stat', SCRIPT_ERROR_OBJECT_IS_NULL);
    result_ := -1;
  end;

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_animate_stand_obj
  ========================================================================= }
procedure op_animate_stand_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
  begin
    sid := scr_find_sid_from_program(program_);
    if scr_ptr(sid, @script) = -1 then
    begin
      dbg_error(program_, 'animate_stand_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
      Exit;
    end;
    obj := scr_find_obj_from_program(program_);
  end;

  if not isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_UNRESERVED);
    register_object_animate(obj, ANIM_STAND, 0);
    register_end();
  end;
end;

{ =========================================================================
  op_animate_stand_reverse_obj
  ========================================================================= }
procedure op_animate_stand_reverse_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
  begin
    sid := scr_find_sid_from_program(program_);
    if scr_ptr(sid, @script) = -1 then
    begin
      dbg_error(program_, 'animate_stand_reverse_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
      Exit;
    end;
    obj := scr_find_obj_from_program(program_);
  end;

  if not isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_UNRESERVED);
    register_object_animate_reverse(obj, ANIM_STAND, 0);
    register_end();
  end;
end;

{ =========================================================================
  op_animate_move_obj_to_tile
  ========================================================================= }
procedure op_animate_move_obj_to_tile(program_: PProgram); cdecl;
var
  flags, tile, sid: Integer;
  tileValue: TProgramValue;
  obj: PObject;
  script: PScript;
begin
  flags := programStackPopInteger(program_);
  tileValue := programStackPopValue(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'animate_move_obj_to_tile', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if tileValue.opcode = VALUE_TYPE_INT then
    tile := tileValue.integerValue
  else
  begin
    dbg_error(program_, 'animate_move_obj_to_tile', SCRIPT_ERROR_FOLLOWS);
    debug_printf('Invalid tile type.');
    tile := -1;
  end;

  if tile <= -1 then
    Exit;

  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = -1 then
  begin
    dbg_error(program_, 'animate_move_obj_to_tile', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
    Exit;
  end;

  if not critter_is_active(obj) then
    Exit;

  if isInCombat() then
    Exit;

  if (flags and $10) <> 0 then
  begin
    register_clear(obj);
    flags := flags and (not $10);
  end;

  register_begin(ANIMATION_REQUEST_UNRESERVED);

  if flags = 0 then
    register_object_move_to_tile(obj, tile, obj^.Elevation, -1, 0)
  else
    register_object_run_to_tile(obj, tile, obj^.Elevation, -1, 0);

  register_end();
end;

{ =========================================================================
  op_animate_jump
  ========================================================================= }
procedure op_animate_jump(program_: PProgram); cdecl;
begin
  int_debug(#10'Script Error: %s: op_animate_jump: INVALID ACTION!', [string(program_^.name)]);
end;

{ =========================================================================
  op_make_daytime
  ========================================================================= }
procedure op_make_daytime(program_: PProgram); cdecl;
begin
  // Empty in original
end;

{ =========================================================================
  op_tile_distance
  ========================================================================= }
procedure op_tile_distance(program_: PProgram); cdecl;
var
  tile2, tile1, distance: Integer;
begin
  tile2 := programStackPopInteger(program_);
  tile1 := programStackPopInteger(program_);

  if (tile1 <> -1) and (tile2 <> -1) then
    distance := tile_dist(tile1, tile2)
  else
    distance := 9999;

  programStackPushInteger(program_, distance);
end;

{ =========================================================================
  op_tile_distance_objs
  ========================================================================= }
procedure op_tile_distance_objs(program_: PProgram); cdecl;
var
  object2, object1: PObject;
  distance: Integer;
begin
  object2 := PObject(programStackPopPointer(program_));
  object1 := PObject(programStackPopPointer(program_));

  distance := 9999;
  if (object1 <> nil) and (object2 <> nil) then
  begin
    if (PtrUInt(object2) >= HEX_GRID_SIZE) and (PtrUInt(object1) >= HEX_GRID_SIZE) then
    begin
      if object1^.Elevation = object2^.Elevation then
      begin
        if (object1^.Tile <> -1) and (object2^.Tile <> -1) then
          distance := tile_dist(object1^.Tile, object2^.Tile);
      end;
    end
    else
    begin
      dbg_error(program_, 'tile_distance_objs', SCRIPT_ERROR_FOLLOWS);
      debug_printf(' Passed a tile # instead of an object!!!BADBADBAD!');
    end;
  end;

  programStackPushInteger(program_, distance);
end;

{ =========================================================================
  op_tile_num
  ========================================================================= }
procedure op_tile_num(program_: PProgram); cdecl;
var
  obj: PObject;
  tile: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  tile := -1;
  if obj <> nil then
    tile := obj^.Tile
  else
    dbg_error(program_, 'tile_num', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, tile);
end;

{ =========================================================================
  op_tile_num_in_direction
  ========================================================================= }
procedure op_tile_num_in_direction(program_: PProgram); cdecl;
var
  distance, rotation, origin, tile: Integer;
begin
  distance := programStackPopInteger(program_);
  rotation := programStackPopInteger(program_);
  origin := programStackPopInteger(program_);

  tile := -1;
  if origin <> -1 then
  begin
    if rotation < Ord(ROTATION_COUNT) then
    begin
      if distance <> 0 then
      begin
        tile := tile_num_in_direction(origin, rotation, distance);
        if tile < -1 then
        begin
          debug_printf(#10'Error: %s: op_tile_num_in_direction got #: %d', [string(program_^.name), tile]);
          tile := -1;
        end;
      end;
    end
    else
    begin
      dbg_error(program_, 'tile_num_in_direction', SCRIPT_ERROR_FOLLOWS);
      debug_printf(' rotation out of Range!');
    end;
  end
  else
  begin
    dbg_error(program_, 'tile_num_in_direction', SCRIPT_ERROR_FOLLOWS);
    debug_printf(' tileNum is -1!');
  end;

  programStackPushInteger(program_, tile);
end;

{ =========================================================================
  op_pickup_obj
  ========================================================================= }
procedure op_pickup_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
    Exit;

  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = 1 then
  begin
    dbg_error(program_, 'pickup_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
    Exit;
  end;

  if script^.target = nil then
  begin
    dbg_error(program_, 'pickup_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  action_get_an_object(script^.target, obj);
end;

{ =========================================================================
  op_drop_obj
  ========================================================================= }
procedure op_drop_obj(program_: PProgram); cdecl;
var
  obj: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
    Exit;

  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = -1 then
  begin
    dbg_error(program_, 'drop_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if script^.target = nil then
  begin
    dbg_error(program_, 'drop_obj', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
    Exit;
  end;

  obj_drop(script^.target, obj);
end;

{ =========================================================================
  op_add_obj_to_inven
  ========================================================================= }
procedure op_add_obj_to_inven(program_: PProgram); cdecl;
var
  item, owner: PObject;
  rect: TRect;
begin
  item := PObject(programStackPopPointer(program_));
  owner := PObject(programStackPopPointer(program_));

  WriteLn('[SCRIPT] add_obj_to_inven: owner=', IntToHex(PtrUInt(owner), 16), ' item=', IntToHex(PtrUInt(item), 16));

  if (owner = nil) or (item = nil) then
    Exit;

  // Validate pointer before dereferencing
  if (PtrUInt(item) < $10000) then
  begin
    WriteLn('[SCRIPT] ERROR: item pointer looks like an integer, not a valid pointer');
    Exit;
  end;

  if item^.Owner = nil then
  begin
    if item_add_force(owner, item, 1) = 0 then
    begin
      obj_disconnect(item, @rect);
      tile_refresh_rect(@rect, item^.Elevation);
    end;
  end
  else
  begin
    dbg_error(program_, 'add_obj_to_inven', SCRIPT_ERROR_FOLLOWS);
    debug_printf(' Item was already attached to something else!');
  end;
end;

{ =========================================================================
  op_rm_obj_from_inven
  ========================================================================= }
procedure op_rm_obj_from_inven(program_: PProgram); cdecl;
var
  item, owner: PObject;
  updateFlags: Boolean;
  flags: Integer;
  rect: TRect;
begin
  item := PObject(programStackPopPointer(program_));
  owner := PObject(programStackPopPointer(program_));

  if (owner = nil) or (item = nil) then
    Exit;

  updateFlags := False;
  flags := 0;

  if (item^.Flags and OBJECT_EQUIPPED) <> 0 then
  begin
    if (item^.Flags and OBJECT_IN_LEFT_HAND) <> 0 then
      flags := flags or OBJECT_IN_LEFT_HAND;
    if (item^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
      flags := flags or OBJECT_IN_RIGHT_HAND;
    if (item^.Flags and OBJECT_WORN) <> 0 then
      flags := flags or OBJECT_WORN;
    updateFlags := True;
  end;

  if item_remove_mult(owner, item, 1) = 0 then
  begin
    obj_connect(item, 1, 0, @rect);
    tile_refresh_rect(@rect, item^.Elevation);

    if updateFlags then
      correctFidForRemovedItem(owner, item, flags);
  end;
end;

{ =========================================================================
  op_wield_obj_critter
  ========================================================================= }
procedure op_wield_obj_critter(program_: PProgram); cdecl;
var
  item, critter: PObject;
  hand: Integer;
  shouldAdjustArmorClass: Boolean;
  oldArmor, newArmor: PObject;
begin
  item := PObject(programStackPopPointer(program_));
  critter := PObject(programStackPopPointer(program_));

  if critter = nil then
  begin
    dbg_error(program_, 'wield_obj_critter', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if item = nil then
  begin
    dbg_error(program_, 'wield_obj_critter', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    dbg_error(program_, 'wield_obj_critter', SCRIPT_ERROR_FOLLOWS);
    debug_printf(' Only works for critters!  ERROR ERROR ERROR!');
    Exit;
  end;

  hand := HAND_RIGHT;
  shouldAdjustArmorClass := False;
  oldArmor := nil;
  newArmor := nil;

  if critter = obj_dude then
  begin
    if intface_is_item_right_hand() = HAND_LEFT then
      hand := HAND_LEFT;

    if item_get_type(item) = ITEM_TYPE_ARMOR then
    begin
      oldArmor := inven_worn(obj_dude);
      shouldAdjustArmorClass := True;
      newArmor := item;
    end;
  end;

  inven_wield(critter, item, hand);

  if critter = obj_dude then
  begin
    if shouldAdjustArmorClass then
      adjust_ac(critter, oldArmor, newArmor);
  end;
end;

{ =========================================================================
  op_use_obj
  ========================================================================= }
procedure op_use_obj(program_: PProgram); cdecl;
var
  obj, self_: PObject;
  sid: Integer;
  script: PScript;
begin
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'use_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = -1 then
  begin
    dbg_error(program_, 'use_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if script^.target = nil then
  begin
    dbg_error(program_, 'use_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  self_ := scr_find_obj_from_program(program_);
  if PID_TYPE(self_^.Pid) = OBJ_TYPE_CRITTER then
    action_use_an_object(script^.target, obj)
  else
    obj_use(self_, obj);
end;

{ =========================================================================
  op_obj_can_see_obj
  ========================================================================= }
procedure op_obj_can_see_obj(program_: PProgram); cdecl;
var
  object2, object1, a5: PObject;
  result_: Integer;
begin
  object2 := PObject(programStackPopPointer(program_));
  object1 := PObject(programStackPopPointer(program_));

  result_ := 0;
  if (object1 <> nil) and (object2 <> nil) then
  begin
    if object2^.Tile <> -1 then
    begin
      if object2 = obj_dude then
        is_pc_flag(0);

      stat_level(object1, Ord(STAT_PERCEPTION));

      if is_within_perception(object1, object2) then
      begin
        a5 := nil;
        make_straight_path(object1, object1^.Tile, object2^.Tile, nil, @a5, 16);
        if a5 = object2 then
          result_ := 1;
      end;
    end;
  end
  else
    dbg_error(program_, 'obj_can_see_obj', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  dbg_print_com_data
  ========================================================================= }
function dbg_print_com_data(attacker, defender: PObject): Integer;
begin
  debug_printf(#10'Scripts [Combat]: %s(Team %d) requests attack on %s(Team %d)',
    [string(object_name(attacker)),
     attacker^.Data.AsData.Critter.Combat.Team,
     string(object_name(defender)),
     defender^.Data.AsData.Critter.Combat.Team]);
  Result := 0;
end;

{ =========================================================================
  op_attack
  ========================================================================= }
procedure op_attack(program_: PProgram); cdecl;
var
  data: array[0..7] of Integer;
  arg: Integer;
  target, self_: PObject;
  combatData: PCritterCombatData;
  attack: TSTRUCT_664980;
begin
  for arg := 0 to 6 do
    data[arg] := programStackPopInteger(program_);

  target := PObject(programStackPopPointer(program_));
  if target = nil then
  begin
    dbg_error(program_, 'attack', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  self_ := scr_find_obj_from_program(program_);
  if self_ = nil then
  begin
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    Exit;
  end;

  if not critter_is_active(self_) then
  begin
    dbg_print_com_data(self_, target);
    debug_printf(#10'   But is already Inactive (Dead/Stunned)');
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    Exit;
  end;

  if not critter_is_active(target) then
  begin
    dbg_print_com_data(self_, target);
    debug_printf(#10'   But target is already dead');
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    Exit;
  end;

  if (target^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0 then
  begin
    dbg_print_com_data(self_, target);
    debug_printf(#10'   But target is AFRAID');
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    Exit;
  end;

  if dialog_active() then
    Exit;

  if isInCombat() then
  begin
    combatData := @(self_^.Data.AsData.Critter.Combat);
    if (combatData^.Maneuver and CRITTER_MANEUVER_ENGAGING) = 0 then
    begin
      combatData^.Maneuver := combatData^.Maneuver or CRITTER_MANEUVER_ENGAGING;
      combatData^.WhoHitMeUnion.WhoHitMe := target;
    end;
  end
  else
  begin
    FillChar(attack, SizeOf(attack), 0);
    attack.attacker := self_;
    attack.defender := target;
    attack.actionPointsBonus := 0;
    attack.accuracyBonus := data[4];
    attack.damageBonus := 0;
    attack.minDamage := data[3];
    attack.maxDamage := data[2];

    if data[1] = data[0] then
    begin
      attack.field_1C := 1;
      attack.field_24 := data[0];
      attack.field_20 := data[1];
    end
    else
      attack.field_1C := 0;

    dbg_print_com_data(self_, target);
    scripts_request_combat(@attack);
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_start_gdialog
  ========================================================================= }
procedure op_start_gdialog(program_: PProgram); cdecl;
var
  backgroundId, headId, reactionLevel: Integer;
  obj: PObject;
  proto: PProto;
  npcReactionValue, npcReactionType: Integer;
begin
  backgroundId := programStackPopInteger(program_);
  headId := programStackPopInteger(program_);
  reactionLevel := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));
  programStackPopInteger(program_);

  if isInCombat() then
    Exit;

  if obj = nil then
  begin
    dbg_error(program_, 'start_gdialog', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  dialogue_head := -1;
  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
  begin
    if proto_ptr(obj^.Pid, @proto) = -1 then
      Exit;
  end;

  if headId <> -1 then
    dialogue_head := art_id(OBJ_TYPE_HEAD, headId, 0, 0, 0);

  gdialog_set_background(backgroundId);
  dialogue_mood := reactionLevel;

  if dialogue_head <> -1 then
  begin
    npcReactionValue := reaction_get(dialog_target);
    npcReactionType := reaction_to_level(npcReactionValue);
    case npcReactionType of
      NPC_REACTION_BAD:
        dialogue_mood := FIDGET_BAD;
      NPC_REACTION_NEUTRAL:
        dialogue_mood := FIDGET_NEUTRAL;
      NPC_REACTION_GOOD:
        dialogue_mood := FIDGET_GOOD;
    end;
  end;

  dialogue_scr_id := scr_find_sid_from_program(program_);
  dialog_target := scr_find_obj_from_program(program_);
  scr_dialogue_init(dialogue_head, dialogue_mood);
end;

{ =========================================================================
  op_end_dialogue
  ========================================================================= }
procedure op_end_dialogue(program_: PProgram); cdecl;
begin
  if scr_dialogue_exit() <> -1 then
  begin
    dialog_target := nil;
    dialogue_scr_id := -1;
  end;
end;

{ =========================================================================
  op_dialogue_reaction
  ========================================================================= }
procedure op_dialogue_reaction(program_: PProgram); cdecl;
var
  value: Integer;
begin
  value := programStackPopInteger(program_);
  dialogue_mood := value;
  talk_to_critter_reacts(value);
end;

{ =========================================================================
  objs_area_turn_on_off
  ========================================================================= }
procedure objs_area_turn_on_off(a1, a2, a3, a4, enabled: Integer);
var
  temp: Integer;
  obj: PObject;
  object_bounds: TRect;
begin
  if a1 > a2 then
  begin
    temp := a1; a1 := a2; a2 := temp;
  end;

  if a3 > a4 then
  begin
    temp := a3; a3 := a4; a4 := a3;
  end;

  while a1 <= a2 do
  begin
    obj := obj_find_first_at(a1);
    while obj <> nil do
    begin
      if (obj^.Flags and OBJECT_HIDDEN) = LongWord(enabled) then
      begin
        if (obj^.Tile >= a3) and (obj^.Tile <= a4) and ((obj^.Tile - a3) div 200 <= a4 div 200 - a3 div 200) then
        begin
          obj_bound(obj, @object_bounds);
          if enabled <> 0 then
            obj^.Flags := obj^.Flags and (not OBJECT_HIDDEN)
          else
            obj^.Flags := obj^.Flags or OBJECT_HIDDEN;
          rect_min_bound(@objs_area_rect, @object_bounds, @objs_area_rect);
        end;
      end;
      obj := obj_find_next_at();
    end;
    tile_refresh_rect(@objs_area_rect, a1);
    // NOTE: original code has no increment of a1, likely a bug causing infinite loop
    // but we preserve it faithfully
    Break; // The C code while loop would iterate elevations;
           // actually the original increments a1 implicitly -- but examining the code
           // there is no a1++ which means this is an infinite loop bug in the original.
           // We break to avoid hanging.
  end;
end;

{ =========================================================================
  op_turn_off_objs_in_area
  ========================================================================= }
procedure op_turn_off_objs_in_area(program_: PProgram); cdecl;
var
  data: array[0..3] of Integer;
  arg: Integer;
begin
  for arg := 0 to 3 do
    data[arg] := programStackPopInteger(program_);
  objs_area_turn_on_off(data[3], data[2], data[1], data[0], 0);
end;

{ =========================================================================
  op_turn_on_objs_in_area
  ========================================================================= }
procedure op_turn_on_objs_in_area(program_: PProgram); cdecl;
var
  data: array[0..3] of Integer;
  arg: Integer;
begin
  for arg := 0 to 3 do
    data[arg] := programStackPopInteger(program_);
  objs_area_turn_on_off(data[3], data[2], data[1], data[0], 1);
end;

{ =========================================================================
  op_set_obj_visibility
  ========================================================================= }
procedure op_set_obj_visibility(program_: PProgram); cdecl;
var
  invisible: Integer;
  obj: PObject;
  rect: TRect;
begin
  invisible := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'set_obj_visibility', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if isLoadingGame() <> 0 then
  begin
    debug_printf('Error: attempt to set_obj_visibility in load/save-game: %s!', [string(program_^.name)]);
    Exit;
  end;

  if invisible <> 0 then
  begin
    if (obj^.Flags and OBJECT_HIDDEN) = 0 then
    begin
      obj_bound(obj, @rect);
      obj^.Flags := obj^.Flags or OBJECT_HIDDEN;
      if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
        obj^.Flags := obj^.Flags or OBJECT_NO_BLOCK;
      tile_refresh_rect(@rect, obj^.Elevation);
    end;
  end
  else
  begin
    if (obj^.Flags and OBJECT_HIDDEN) <> 0 then
    begin
      if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
        obj^.Flags := obj^.Flags and (not OBJECT_NO_BLOCK);
      obj^.Flags := obj^.Flags and (not OBJECT_HIDDEN);
      obj_bound(obj, @rect);
      tile_refresh_rect(@rect, obj^.Elevation);
    end;
  end;
end;

{ =========================================================================
  op_load_map
  ========================================================================= }
procedure op_load_map(program_: PProgram); cdecl;
var
  param, mapIndex: Integer;
  mapIndexOrName: TProgramValue;
  mapName: PAnsiChar;
  transition: TMapTransition;
begin
  param := programStackPopInteger(program_);
  mapIndexOrName := programStackPopValue(program_);

  mapName := nil;

  if (mapIndexOrName.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_INT then
  begin
    if (mapIndexOrName.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
      mapName := interpretGetString(program_, mapIndexOrName.opcode, mapIndexOrName.integerValue)
    else
      interpretError('script error: %s: invalid arg 1 to load_map', [string(program_^.name)]);
  end;

  mapIndex := -1;

  if mapName <> nil then
  begin
    game_global_vars[Ord(GVAR_LOAD_MAP_INDEX)] := param;
    mapIndex := map_match_map_name(mapName);
  end
  else
  begin
    if mapIndexOrName.integerValue >= 0 then
    begin
      game_global_vars[Ord(GVAR_LOAD_MAP_INDEX)] := param;
      mapIndex := mapIndexOrName.integerValue;
    end;
  end;

  if mapIndex <> -1 then
  begin
    transition.map := mapIndex;
    transition.elevation := -1;
    transition.tile := -1;
    transition.rotation := -1;
    map_leave_map(@transition);
  end;
end;

{ =========================================================================
  op_barter_offer
  ========================================================================= }
procedure op_barter_offer(program_: PProgram); cdecl;
var
  data: array[0..2] of Integer;
  arg: Integer;
begin
  for arg := 0 to 2 do
    data[arg] := programStackPopInteger(program_);
end;

{ =========================================================================
  op_barter_asking
  ========================================================================= }
procedure op_barter_asking(program_: PProgram); cdecl;
var
  data: array[0..2] of Integer;
  arg: Integer;
begin
  for arg := 0 to 2 do
    data[arg] := programStackPopInteger(program_);
end;

{ =========================================================================
  op_anim_busy
  ========================================================================= }
procedure op_anim_busy(program_: PProgram); cdecl;
var
  obj: PObject;
  rc: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  rc := 0;
  if obj <> nil then
    rc := anim_busy(obj)
  else
    dbg_error(program_, 'anim_busy', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, rc);
end;

{ =========================================================================
  op_critter_heal
  ========================================================================= }
procedure op_critter_heal(program_: PProgram); cdecl;
var
  amount: Integer;
  critter: PObject;
  rc: Integer;
begin
  amount := programStackPopInteger(program_);
  critter := PObject(programStackPopPointer(program_));

  rc := critter_adjust_hits(critter, amount);

  if critter = obj_dude then
    intface_update_hit_points(True);

  programStackPushInteger(program_, rc);
end;

{ =========================================================================
  op_set_light_level
  ========================================================================= }
procedure op_set_light_level(program_: PProgram); cdecl;
const
  dword_453F90: array[0..2] of Integer = ($4000, $A000, $10000);
var
  data, lightIntensity: Integer;
begin
  data := programStackPopInteger(program_);

  if data = 50 then
  begin
    light_set_ambient(dword_453F90[1], True);
    Exit;
  end;

  if data > 50 then
    lightIntensity := dword_453F90[1] + data * (dword_453F90[2] - dword_453F90[1]) div 100
  else
    lightIntensity := dword_453F90[0] + data * (dword_453F90[1] - dword_453F90[0]) div 100;

  light_set_ambient(lightIntensity, True);
end;

{ =========================================================================
  op_game_time
  ========================================================================= }
procedure op_game_time(program_: PProgram); cdecl;
begin
  programStackPushInteger(program_, game_time());
end;

{ =========================================================================
  op_game_time_in_seconds
  ========================================================================= }
procedure op_game_time_in_seconds(program_: PProgram); cdecl;
begin
  programStackPushInteger(program_, game_time() div 10);
end;

{ =========================================================================
  op_elevation
  ========================================================================= }
procedure op_elevation(program_: PProgram); cdecl;
var
  obj: PObject;
  elevation: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  elevation := 0;
  if obj <> nil then
    elevation := obj^.Elevation
  else
    dbg_error(program_, 'elevation', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, elevation);
end;

{ =========================================================================
  op_kill_critter
  ========================================================================= }
procedure op_kill_critter(program_: PProgram); cdecl;
var
  deathFrame: Integer;
  obj, self_: PObject;
  isSelf: Boolean;
begin
  deathFrame := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'kill_critter', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if isLoadingGame() <> 0 then
    debug_printf(#10'Error: attempt to destroy critter in load/save-game: %s!', [string(program_^.name)]);

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  self_ := scr_find_obj_from_program(program_);
  isSelf := self_ = obj;

  register_clear(obj);
  combat_delete_critter(obj);
  critter_kill(obj, deathFrame, True);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if isSelf then
    program_^.flags := program_^.flags or PROGRAM_FLAG_0x0100;
end;

{ =========================================================================
  correctDeath
  ========================================================================= }
function correctDeath(critter: PObject; anim: Integer; forceBack: Boolean): Integer;
var
  violenceLevel, fid: Integer;
  useStandardDeath: Boolean;
begin
  if (anim >= ANIM_BIG_HOLE_SF) and (anim <= ANIM_FALL_FRONT_BLOOD_SF) then
  begin
    violenceLevel := VIOLENCE_LEVEL_MAXIMUM_BLOOD;
    config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violenceLevel);

    useStandardDeath := False;
    if violenceLevel < VIOLENCE_LEVEL_MAXIMUM_BLOOD then
      useStandardDeath := True
    else
    begin
      fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, anim, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
      if not art_exists(fid) then
        useStandardDeath := True;
    end;

    if useStandardDeath then
    begin
      if forceBack then
        anim := ANIM_FALL_BACK
      else
      begin
        fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_FALL_FRONT, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
        if art_exists(fid) then
          anim := ANIM_FALL_FRONT
        else
          anim := ANIM_FALL_BACK;
      end;
    end;
  end;

  Result := anim;
end;

{ =========================================================================
  op_kill_critter_type
  ========================================================================= }
procedure op_kill_critter_type(program_: PProgram); cdecl;
const
  ftList: array[0..10] of Integer = (
    ANIM_FALL_BACK_BLOOD_SF,
    ANIM_BIG_HOLE_SF,
    ANIM_CHARRED_BODY_SF,
    ANIM_CHUNKS_OF_FLESH_SF,
    ANIM_FALL_FRONT_BLOOD_SF,
    ANIM_FALL_BACK_BLOOD_SF,
    ANIM_DANCING_AUTOFIRE_SF,
    ANIM_SLICED_IN_HALF_SF,
    ANIM_EXPLODED_TO_NOTHING_SF,
    ANIM_FALL_BACK_BLOOD_SF,
    ANIM_FALL_FRONT_BLOOD_SF
  );
var
  deathFrame, pid: Integer;
  previousObj, obj: PObject;
  count, v3, anim_: Integer;
  rect: TRect;
begin
  deathFrame := programStackPopInteger(program_);
  pid := programStackPopInteger(program_);

  if isLoadingGame() <> 0 then
  begin
    debug_printf(#10'Error: attempt to destroy critter in load/save-game: %s!', [string(program_^.name)]);
    Exit;
  end;

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  previousObj := nil;
  count := 0;
  v3 := 0;

  obj := obj_find_first();
  while obj <> nil do
  begin
    if FID_ANIM_TYPE(obj^.Fid) >= ANIM_FALL_BACK_SF then
    begin
      obj := obj_find_next();
      Continue;
    end;

    if ((obj^.Flags and OBJECT_HIDDEN) = 0) and (obj^.Pid = pid) and (not critter_is_dead(obj)) then
    begin
      if (obj = previousObj) or (count > 200) then
      begin
        dbg_error(program_, 'kill_critter_type', SCRIPT_ERROR_FOLLOWS);
        debug_printf(' Infinite loop destroying critters!');
        program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
        Exit;
      end;

      register_clear(obj);

      if deathFrame <> 0 then
      begin
        combat_delete_critter(obj);
        if deathFrame = 1 then
        begin
          anim_ := correctDeath(obj, ftList[v3], True);
          critter_kill(obj, anim_, True);
          Inc(v3);
          if v3 >= 11 then
            v3 := 0;
        end
        else
          critter_kill(obj, ANIM_FALL_BACK_SF, True);
      end
      else
      begin
        register_clear(obj);
        obj_erase_object(obj, @rect);
        tile_refresh_rect(@rect, map_elevation);
      end;

      previousObj := obj;
      Inc(count);

      obj_find_first();

      map_data.lastVisitTime := game_time();
    end;

    obj := obj_find_next();
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_critter_damage
  ========================================================================= }
procedure op_critter_damage(program_: PProgram); cdecl;
var
  damageTypeWithFlags, amount: Integer;
  obj, self_: PObject;
  animate, bypassArmor: Boolean;
  damageType: Integer;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  damageTypeWithFlags := programStackPopInteger(program_);
  amount := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'critter_damage', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if PID_TYPE(obj^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    dbg_error(program_, 'critter_damage', SCRIPT_ERROR_FOLLOWS);
    debug_printf(' Can''t call on non-critters!');
    Exit;
  end;

  self_ := scr_find_obj_from_program(program_);
  if obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid = -1 then
    obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;

  animate := (damageTypeWithFlags and $200) = 0;
  bypassArmor := (damageTypeWithFlags and $100) <> 0;
  damageType := damageTypeWithFlags and (not ($100 or $200));
  action_dmg(obj^.Tile, obj^.Elevation, amount, amount, damageType, animate, bypassArmor);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if self_ = obj then
    program_^.flags := program_^.flags or PROGRAM_FLAG_0x0100;
end;

{ =========================================================================
  op_add_timer_event
  ========================================================================= }
procedure op_add_timer_event(program_: PProgram); cdecl;
var
  param, delay: Integer;
  obj: PObject;
begin
  param := programStackPopInteger(program_);
  delay := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    int_debug(#10'Script Error: %s: op_add_timer_event: pobj is NULL!', [string(program_^.name)]);
    Exit;
  end;

  script_q_add(obj^.Sid, delay, param);
end;

{ =========================================================================
  op_rm_timer_event
  ========================================================================= }
procedure op_rm_timer_event(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    int_debug(#10'Script Error: %s: op_add_timer_event: pobj is NULL!', [string(program_^.name)]);
    Exit;
  end;

  queue_remove(obj);
end;

{ =========================================================================
  op_game_ticks
  ========================================================================= }
procedure op_game_ticks(program_: PProgram); cdecl;
var
  ticks: Integer;
begin
  ticks := programStackPopInteger(program_);
  if ticks < 0 then
    ticks := 0;
  programStackPushInteger(program_, ticks * 10);
end;

{ =========================================================================
  op_has_trait
  ========================================================================= }
procedure op_has_trait(program_: PProgram); cdecl;
var
  param: Integer;
  obj: PObject;
  type_, result_: Integer;
begin
  param := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));
  type_ := programStackPopInteger(program_);

  result_ := 0;

  if obj <> nil then
  begin
    case type_ of
      CRITTER_TRAIT_PERK:
        begin
          if param < Ord(PERK_COUNT) then
            result_ := perk_level(param)
          else
            int_debug(#10'Script Error: %s: op_has_trait: Perk out of range', [string(program_^.name)]);
        end;
      CRITTER_TRAIT_OBJECT:
        begin
          case param of
            CRITTER_TRAIT_OBJECT_AI_PACKET:
              if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
                result_ := obj^.Data.AsData.Critter.Combat.AiPacket;
            CRITTER_TRAIT_OBJECT_TEAM:
              if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
                result_ := obj^.Data.AsData.Critter.Combat.Team;
            CRITTER_TRAIT_OBJECT_ROTATION:
              result_ := obj^.Rotation;
            CRITTER_TRAIT_OBJECT_IS_INVISIBLE:
              begin
                if (obj^.Flags and OBJECT_HIDDEN) = 0 then
                  result_ := 1
                else
                  result_ := 0;
              end;
            CRITTER_TRAIT_OBJECT_GET_INVENTORY_WEIGHT:
              result_ := item_total_weight(obj);
          end;
        end;
      CRITTER_TRAIT_TRAIT:
        begin
          if param < TRAIT_COUNT then
            result_ := trait_level(param)
          else
            int_debug(#10'Script Error: %s: op_has_trait: Trait out of range', [string(program_^.name)]);
        end;
    else
      int_debug(#10'Script Error: %s: op_has_trait: Trait out of range', [string(program_^.name)]);
    end;
  end
  else
    dbg_error(program_, 'has_trait', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_obj_can_hear_obj
  ========================================================================= }
procedure op_obj_can_hear_obj(program_: PProgram); cdecl;
var
  object2, object1: PObject;
  canHear: Boolean;
begin
  object2 := PObject(programStackPopPointer(program_));
  object1 := PObject(programStackPopPointer(program_));

  canHear := False;

  // NOTE: Original C++ code has a bug: it checks (object2 == NULL || object1 == NULL)
  // and then dereferences them inside.  Preserving the original logic.
  if (object2 = nil) or (object1 = nil) then
  begin
    if object2^.Elevation = object1^.Elevation then
    begin
      if (object2^.Tile <> -1) and (object1^.Tile <> -1) then
      begin
        if is_within_perception(object1, object2) then
          canHear := True;
      end;
    end;
  end;

  if canHear then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_game_time_hour
  ========================================================================= }
procedure op_game_time_hour(program_: PProgram); cdecl;
begin
  programStackPushInteger(program_, game_time_hour());
end;

{ =========================================================================
  op_fixed_param
  ========================================================================= }
procedure op_fixed_param(program_: PProgram); cdecl;
var
  fixedParam, sid: Integer;
  script: PScript;
begin
  fixedParam := 0;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    fixedParam := script^.fixedParam
  else
    dbg_error(program_, 'fixed_param', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushInteger(program_, fixedParam);
end;

{ =========================================================================
  op_tile_is_visible
  ========================================================================= }
procedure op_tile_is_visible(program_: PProgram); cdecl;
var
  data, isVisible: Integer;
begin
  data := programStackPopInteger(program_);
  isVisible := 0;
  if scripts_tile_is_visible(data) <> 0 then
    isVisible := 1;
  programStackPushInteger(program_, isVisible);
end;

{ =========================================================================
  op_dialogue_system_enter
  ========================================================================= }
procedure op_dialogue_system_enter(program_: PProgram); cdecl;
var
  sid: Integer;
  script: PScript;
  self_: PObject;
begin
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = -1 then
    Exit;

  self_ := scr_find_obj_from_program(program_);
  if PID_TYPE(self_^.Pid) = OBJ_TYPE_CRITTER then
  begin
    if not critter_is_active(self_) then
      Exit;
  end;

  if isInCombat() then
    Exit;

  if game_state_request(GAME_STATE_4) = -1 then
    Exit;

  dialog_target := scr_find_obj_from_program(program_);
end;

{ =========================================================================
  op_action_being_used
  ========================================================================= }
procedure op_action_being_used(program_: PProgram); cdecl;
var
  action, sid: Integer;
  script: PScript;
begin
  action := -1;
  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) <> -1 then
    action := script^.actionBeingUsed
  else
    dbg_error(program_, 'action_being_used', SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID);
  programStackPushInteger(program_, action);
end;

{ =========================================================================
  op_critter_state
  ========================================================================= }
procedure op_critter_state(program_: PProgram); cdecl;
var
  critter: PObject;
  state, anim_: Integer;
begin
  critter := PObject(programStackPopPointer(program_));

  state := CRITTER_STATE_DEAD;
  if (critter <> nil) and (PID_TYPE(critter^.Pid) = OBJ_TYPE_CRITTER) then
  begin
    if critter_is_active(critter) then
    begin
      state := CRITTER_STATE_NORMAL;

      anim_ := FID_ANIM_TYPE(critter^.Fid);
      if (anim_ >= ANIM_FALL_BACK_SF) and (anim_ <= ANIM_FALL_FRONT_SF) then
        state := CRITTER_STATE_PRONE;

      state := state or (critter^.Data.AsData.Critter.Combat.Results and DAM_CRIP);
    end;
  end
  else
    dbg_error(program_, 'critter_state', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, state);
end;

{ =========================================================================
  op_game_time_advance
  ========================================================================= }
procedure op_game_time_advance(program_: PProgram); cdecl;
var
  data, days, remainder, day: Integer;
begin
  data := programStackPopInteger(program_);

  days := data div GAME_TIME_TICKS_PER_DAY;
  remainder := data mod GAME_TIME_TICKS_PER_DAY;

  for day := 0 to days - 1 do
  begin
    inc_game_time(GAME_TIME_TICKS_PER_DAY);
    queue_process;
  end;

  inc_game_time(remainder);
  queue_process;
end;

{ =========================================================================
  op_radiation_inc
  ========================================================================= }
procedure op_radiation_inc(program_: PProgram); cdecl;
var
  amount: Integer;
  obj: PObject;
begin
  amount := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'radiation_inc', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  critter_adjust_rads(obj, amount);
end;

{ =========================================================================
  op_radiation_dec
  ========================================================================= }
procedure op_radiation_dec(program_: PProgram); cdecl;
var
  amount: Integer;
  obj: PObject;
  radiation, adjustment: Integer;
begin
  amount := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'radiation_dec', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  radiation := critter_get_rads(obj);
  if radiation >= 0 then
    adjustment := -amount
  else
    adjustment := 0;

  critter_adjust_rads(obj, adjustment);
end;

{ =========================================================================
  op_critter_attempt_placement
  ========================================================================= }
procedure op_critter_attempt_placement(program_: PProgram); cdecl;
var
  elevation, tile, rc: Integer;
  critter: PObject;
begin
  elevation := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);
  critter := PObject(programStackPopPointer(program_));

  if critter = nil then
  begin
    dbg_error(program_, 'critter_attempt_placement', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if (elevation <> critter^.Elevation) and (PID_TYPE(critter^.Pid) = OBJ_TYPE_CRITTER) then
    combat_delete_critter(critter);

  obj_move_to_tile(critter, 0, elevation, nil);

  rc := obj_attempt_placement(critter, tile, elevation, 1);
  programStackPushInteger(program_, rc);
end;

{ =========================================================================
  op_obj_pid
  ========================================================================= }
procedure op_obj_pid(program_: PProgram); cdecl;
var
  obj: PObject;
  pid: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  pid := -1;
  if obj <> nil then
    pid := obj^.Pid
  else
    dbg_error(program_, 'obj_pid', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, pid);
end;

{ =========================================================================
  op_cur_map_index
  ========================================================================= }
procedure op_cur_map_index(program_: PProgram); cdecl;
begin
  programStackPushInteger(program_, map_get_index_number());
end;

{ =========================================================================
  op_critter_add_trait
  ========================================================================= }
procedure op_critter_add_trait(program_: PProgram); cdecl;
var
  value, param, kind: Integer;
  obj: PObject;
begin
  value := programStackPopInteger(program_);
  param := programStackPopInteger(program_);
  kind := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj <> nil then
  begin
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    begin
      case kind of
        CRITTER_TRAIT_PERK:
          begin
            if perk_add(param) <> 0 then
              int_debug(#10'Script Error: %s: op_critter_add_trait: perk_add failed', [string(program_^.name)]);
          end;
        CRITTER_TRAIT_OBJECT:
          begin
            case param of
              CRITTER_TRAIT_OBJECT_AI_PACKET:
                obj^.Data.AsData.Critter.Combat.AiPacket := value;
              CRITTER_TRAIT_OBJECT_TEAM:
                begin
                  if obj^.Data.AsData.Critter.Combat.Team <> value then
                  begin
                    if isLoadingGame() = 0 then
                      combatai_switch_team(obj, value);
                  end;
                end;
            end;
          end;
      else
        int_debug(#10'Script Error: %s: op_critter_add_trait: Trait out of range', [string(program_^.name)]);
      end;
    end;
  end
  else
    dbg_error(program_, 'critter_add_trait', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, -1);
end;

{ =========================================================================
  op_critter_rm_trait
  ========================================================================= }
procedure op_critter_rm_trait(program_: PProgram); cdecl;
var
  value, param, kind: Integer;
  obj: PObject;
begin
  value := programStackPopInteger(program_);
  param := programStackPopInteger(program_);
  kind := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'critter_rm_trait', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
  begin
    case kind of
      CRITTER_TRAIT_PERK:
        begin
          // NOTE: perk removal was commented out in original code
        end;
    else
      int_debug(#10'Script Error: %s: op_critter_rm_trait: Trait out of range', [string(program_^.name)]);
    end;
  end;

  programStackPushInteger(program_, -1);
end;

{ =========================================================================
  op_proto_data
  ========================================================================= }
procedure op_proto_data(program_: PProgram); cdecl;
var
  member, pid, valueType: Integer;
  value: TProtoDataMemberValue;
begin
  member := programStackPopInteger(program_);
  pid := programStackPopInteger(program_);

  value.integerValue := 0;
  valueType := proto_data_member(pid, member, @value);
  case valueType of
    PROTO_DATA_MEMBER_TYPE_INT:
      programStackPushInteger(program_, value.integerValue);
    PROTO_DATA_MEMBER_TYPE_STRING:
      programStackPushString(program_, value.stringValue);
  else
    programStackPushInteger(program_, 0);
  end;
end;

{ =========================================================================
  op_message_str
  ========================================================================= }
procedure op_message_str(program_: PProgram); cdecl;
const
  errStr: PAnsiChar = 'Error';
var
  messageIndex, messageListIndex: Integer;
  str: PAnsiChar;
begin
  messageIndex := programStackPopInteger(program_);
  messageListIndex := programStackPopInteger(program_);

  if messageIndex >= 1 then
  begin
    str := scr_get_msg_str_speech(messageListIndex, messageIndex, 1);
    if str = nil then
    begin
      debug_printf(#10'Error: No message file EXISTS!: index %d, line %d', [messageListIndex, messageIndex]);
      str := errStr;
    end;
  end
  else
    str := errStr;

  programStackPushString(program_, str);
end;

{ =========================================================================
  op_critter_inven_obj
  ========================================================================= }
procedure op_critter_inven_obj(program_: PProgram); cdecl;
var
  type_: Integer;
  critter: PObject;
begin
  type_ := programStackPopInteger(program_);
  critter := PObject(programStackPopPointer(program_));

  if PID_TYPE(critter^.Pid) = OBJ_TYPE_CRITTER then
  begin
    case type_ of
      INVEN_TYPE_WORN:
        programStackPushPointer(program_, inven_worn(critter));
      INVEN_TYPE_RIGHT_HAND:
        begin
          if critter = obj_dude then
          begin
            if intface_is_item_right_hand() <> HAND_LEFT then
              programStackPushPointer(program_, inven_right_hand(critter))
            else
              programStackPushPointer(program_, nil);
          end
          else
            programStackPushPointer(program_, inven_right_hand(critter));
        end;
      INVEN_TYPE_LEFT_HAND:
        begin
          if critter = obj_dude then
          begin
            if intface_is_item_right_hand() = HAND_LEFT then
              programStackPushPointer(program_, inven_left_hand(critter))
            else
              programStackPushPointer(program_, nil);
          end
          else
            programStackPushPointer(program_, inven_left_hand(critter));
        end;
      INVEN_TYPE_INV_COUNT:
        programStackPushInteger(program_, critter^.Data.AsData.Inventory.Length);
    else
      begin
        int_debug('script error: %s: Error in critter_inven_obj -- wrong type!', [string(program_^.name)]);
        programStackPushInteger(program_, 0);
      end;
    end;
  end
  else
  begin
    dbg_error(program_, 'critter_inven_obj', SCRIPT_ERROR_FOLLOWS);
    debug_printf('  Not a critter!');
    programStackPushInteger(program_, 0);
  end;
end;

{ =========================================================================
  op_obj_set_light_level
  ========================================================================= }
procedure op_obj_set_light_level(program_: PProgram); cdecl;
var
  lightDistance, lightIntensity: Integer;
  obj: PObject;
  rect: TRect;
begin
  lightDistance := programStackPopInteger(program_);
  lightIntensity := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'obj_set_light_level', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if lightIntensity <> 0 then
  begin
    if obj_set_light(obj, lightDistance, (lightIntensity * 65636) div 100, @rect) = -1 then
      Exit;
  end
  else
  begin
    if obj_set_light(obj, lightDistance, 0, @rect) = -1 then
      Exit;
  end;
  tile_refresh_rect(@rect, obj^.Elevation);
end;

{ =========================================================================
  op_world_map
  ========================================================================= }
procedure op_world_map(program_: PProgram); cdecl;
begin
  scripts_request_worldmap;
end;

{ =========================================================================
  op_town_map
  ========================================================================= }
procedure op_town_map(program_: PProgram); cdecl;
begin
  scripts_request_townmap;
end;

{ =========================================================================
  op_float_msg
  ========================================================================= }
procedure op_float_msg(program_: PProgram); cdecl;
var
  floatingMessageType: Integer;
  stringValue: TProgramValue;
  str: PAnsiChar;
  obj: PObject;
  color_, a5, font: Integer;
  rect: TRect;
begin
  floatingMessageType := programStackPopInteger(program_);
  stringValue := programStackPopValue(program_);
  str := nil;
  if (stringValue.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    str := interpretGetString(program_, stringValue.opcode, stringValue.integerValue);
  obj := PObject(programStackPopPointer(program_));

  color_ := colorTable[32747];
  a5 := colorTable[0];
  font := 101;

  if obj = nil then
  begin
    dbg_error(program_, 'float_msg', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if (str = nil) or (str^ = #0) then
  begin
    int_debug(#10'Script Error: %s: op_float_msg: empty or blank string!', [string(program_^.name)]);
    Exit;
  end;

  if obj^.Elevation <> map_elevation then
    Exit;

  if floatingMessageType = FLOATING_MESSAGE_TYPE_COLOR_SEQUENCE then
  begin
    floatingMessageType := last_color + 1;
    if floatingMessageType >= FLOATING_MESSAGE_TYPE_COUNT then
      floatingMessageType := FLOATING_MESSAGE_TYPE_BLACK;
    last_color := floatingMessageType;
  end;

  case floatingMessageType of
    FLOATING_MESSAGE_TYPE_WARNING:
      begin
        color_ := colorTable[31744];
        a5 := colorTable[0];
        font := 103;
        tile_set_center(obj_dude^.Tile, TILE_SET_CENTER_REFRESH_WINDOW);
      end;
    FLOATING_MESSAGE_TYPE_NORMAL, FLOATING_MESSAGE_TYPE_YELLOW:
      color_ := colorTable[32747];
    FLOATING_MESSAGE_TYPE_BLACK, FLOATING_MESSAGE_TYPE_PURPLE, FLOATING_MESSAGE_TYPE_GREY:
      color_ := colorTable[10570];
    FLOATING_MESSAGE_TYPE_RED:
      color_ := colorTable[31744];
    FLOATING_MESSAGE_TYPE_GREEN:
      color_ := colorTable[992];
    FLOATING_MESSAGE_TYPE_BLUE:
      color_ := colorTable[31];
    FLOATING_MESSAGE_TYPE_NEAR_WHITE:
      color_ := colorTable[21140];
    FLOATING_MESSAGE_TYPE_LIGHT_RED:
      color_ := colorTable[32074];
    FLOATING_MESSAGE_TYPE_WHITE:
      color_ := colorTable[32767];
    FLOATING_MESSAGE_TYPE_DARK_GREY:
      color_ := colorTable[8456];
    FLOATING_MESSAGE_TYPE_LIGHT_GREY:
      color_ := colorTable[15855];
  end;

  if text_object_create(obj, str, font, color_, a5, @rect) <> -1 then
    tile_refresh_rect(@rect, obj^.Elevation);
end;

{ =========================================================================
  op_metarule
  ========================================================================= }
procedure op_metarule(program_: PProgram); cdecl;
var
  param: TProgramValue;
  rule: Integer;
begin
  param := programStackPopValue(program_);
  rule := programStackPopInteger(program_);

  case rule of
    METARULE_SIGNAL_END_GAME:
      begin
        game_user_wants_to_quit := 2;
        programStackPushInteger(program_, 0);
      end;
    METARULE_FIRST_RUN:
      begin
        if (map_data.flags and MAP_SAVED) = 0 then
          programStackPushInteger(program_, 1)
        else
          programStackPushInteger(program_, 0);
      end;
    METARULE_ELEVATOR:
      begin
        scripts_request_elevator(param.integerValue);
        programStackPushInteger(program_, 0);
      end;
    METARULE_PARTY_COUNT:
      programStackPushInteger(program_, getPartyMemberCount());
    METARULE_IS_LOADGAME:
      programStackPushInteger(program_, isLoadingGame());
  else
    programStackPushInteger(program_, 0);
  end;
end;

{ =========================================================================
  op_anim
  ========================================================================= }
procedure op_anim(program_: PProgram); cdecl;
var
  frame, anim_: Integer;
  obj: PObject;
  combatData: PCritterCombatData;
  fid: Integer;
  rect: TRect;
begin
  frame := programStackPopInteger(program_);
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'anim', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if anim_ < ANIM_COUNT then
  begin
    combatData := nil;
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
      combatData := @(obj^.Data.AsData.Critter.Combat);

    anim_ := correctDeath(obj, anim_, True);

    register_begin(ANIMATION_REQUEST_UNRESERVED);

    if frame = 0 then
    begin
      register_object_animate(obj, anim_, 0);
      if (anim_ >= ANIM_FALL_BACK) and (anim_ <= ANIM_FALL_FRONT_BLOOD) then
      begin
        fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, anim_ + 28, (obj^.Fid and $F000) shr 12, (obj^.Fid and $70000000) shr 28);
        register_object_change_fid(obj, fid, -1);
      end;

      if combatData <> nil then
        combatData^.Results := combatData^.Results and DAM_KNOCKED_DOWN;
    end
    else
    begin
      fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim_, (obj^.Fid and $F000) shr 12, (obj^.Fid and $70000000) shr 24);
      register_object_animate_reverse(obj, anim_, 0);

      if anim_ = ANIM_PRONE_TO_STANDING then
        fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_FALL_FRONT_SF, (obj^.Fid and $F000) shr 12, (obj^.Fid and $70000000) shr 24)
      else if anim_ = ANIM_BACK_TO_STANDING then
        fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_FALL_BACK_SF, (obj^.Fid and $F000) shr 12, (obj^.Fid and $70000000) shr 24);

      if combatData <> nil then
        combatData^.Results := combatData^.Results or DAM_KNOCKED_DOWN;

      register_object_change_fid(obj, fid, -1);
    end;

    register_end();
  end
  else if anim_ = 1000 then
  begin
    if frame < Ord(ROTATION_COUNT) then
    begin
      obj_set_rotation(obj, frame, @rect);
      tile_refresh_rect(@rect, map_elevation);
    end;
  end
  else if anim_ = 1010 then
  begin
    obj_set_frame(obj, frame, @rect);
    tile_refresh_rect(@rect, map_elevation);
  end
  else
    int_debug(#10'Script Error: %s: op_anim: anim out of range', [string(program_^.name)]);
end;

{ =========================================================================
  op_obj_carrying_pid_obj
  ========================================================================= }
procedure op_obj_carrying_pid_obj(program_: PProgram); cdecl;
var
  pid: Integer;
  obj, result_: PObject;
begin
  pid := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  result_ := nil;
  if obj <> nil then
    result_ := inven_pid_is_carried_ptr(obj, pid)
  else
    dbg_error(program_, 'obj_carrying_pid_obj', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushPointer(program_, result_);
end;

{ =========================================================================
  op_reg_anim_func
  ========================================================================= }
procedure op_reg_anim_func(program_: PProgram); cdecl;
var
  param: TProgramValue;
  cmd: Integer;
begin
  param := programStackPopValue(program_);
  cmd := programStackPopInteger(program_);

  if not isInCombat() then
  begin
    case cmd of
      OP_REG_ANIM_FUNC_BEGIN:
        register_begin(param.integerValue);
      OP_REG_ANIM_FUNC_CLEAR:
        register_clear(PObject(param.pointerValue));
      OP_REG_ANIM_FUNC_END:
        register_end();
    end;
  end;
end;

{ =========================================================================
  op_reg_anim_animate
  ========================================================================= }
procedure op_reg_anim_animate(program_: PProgram); cdecl;
var
  delay, anim_: Integer;
  obj: PObject;
  violenceLevel: Integer;
begin
  delay := programStackPopInteger(program_);
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    violenceLevel := VIOLENCE_LEVEL_NONE;
    if (anim_ <> 20) or (obj = nil) or (obj^.Pid <> $100002F)
      or (config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violenceLevel) and (violenceLevel >= 2))
    then
    begin
      if obj <> nil then
        register_object_animate(obj, anim_, delay)
      else
        dbg_error(program_, 'reg_anim_animate', SCRIPT_ERROR_OBJECT_IS_NULL);
    end;
  end;
end;

{ =========================================================================
  op_reg_anim_animate_reverse
  ========================================================================= }
procedure op_reg_anim_animate_reverse(program_: PProgram); cdecl;
var
  delay, anim_: Integer;
  obj: PObject;
begin
  delay := programStackPopInteger(program_);
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_animate_reverse(obj, anim_, delay)
    else
      dbg_error(program_, 'reg_anim_animate_reverse', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_reg_anim_obj_move_to_obj
  ========================================================================= }
procedure op_reg_anim_obj_move_to_obj(program_: PProgram); cdecl;
var
  delay: Integer;
  dest, obj: PObject;
begin
  delay := programStackPopInteger(program_);
  dest := PObject(programStackPopPointer(program_));
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_move_to_object(obj, dest, -1, delay)
    else
      dbg_error(program_, 'reg_anim_obj_move_to_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_reg_anim_obj_run_to_obj
  ========================================================================= }
procedure op_reg_anim_obj_run_to_obj(program_: PProgram); cdecl;
var
  delay: Integer;
  dest, obj: PObject;
begin
  delay := programStackPopInteger(program_);
  dest := PObject(programStackPopPointer(program_));
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_run_to_object(obj, dest, -1, delay)
    else
      dbg_error(program_, 'reg_anim_obj_run_to_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_reg_anim_obj_move_to_tile
  ========================================================================= }
procedure op_reg_anim_obj_move_to_tile(program_: PProgram); cdecl;
var
  delay, tile: Integer;
  obj: PObject;
begin
  delay := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_move_to_tile(obj, tile, obj^.Elevation, -1, delay)
    else
      dbg_error(program_, 'reg_anim_obj_move_to_tile', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_reg_anim_obj_run_to_tile
  ========================================================================= }
procedure op_reg_anim_obj_run_to_tile(program_: PProgram); cdecl;
var
  delay, tile: Integer;
  obj: PObject;
begin
  delay := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_run_to_tile(obj, tile, obj^.Elevation, -1, delay)
    else
      dbg_error(program_, 'reg_anim_obj_run_to_tile', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_play_gmovie
  ========================================================================= }
procedure op_play_gmovie(program_: PProgram); cdecl;
const
  game_movie_flags: array[0..MOVIE_COUNT - 1] of Word = (
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC,
    GAME_MOVIE_FADE_IN or GAME_MOVIE_PAUSE_MUSIC
  );
var
  movie: Integer;
  isoWasDisabled: Boolean;
  flags: Word;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  movie := programStackPopInteger(program_);

  isoWasDisabled := map_disable_bk_processes;

  gDialogDisableBK;

  flags := game_movie_flags[movie];
  if (movie = MOVIE_VEXPLD) or (movie = MOVIE_CATHEXP) then
  begin
    if map_data.name[0] = #0 then
      flags := flags or GAME_MOVIE_FADE_OUT;
  end;

  if gmovie_play(movie, flags) = -1 then
    debug_printf(#10'Error playing movie %d!', [movie]);

  gDialogEnableBK;

  if isoWasDisabled then
    map_enable_bk_processes;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_add_mult_objs_to_inven
  ========================================================================= }
procedure op_add_mult_objs_to_inven(program_: PProgram); cdecl;
var
  quantity: Integer;
  item, obj: PObject;
  rect: TRect;
begin
  quantity := programStackPopInteger(program_);
  item := PObject(programStackPopPointer(program_));
  obj := PObject(programStackPopPointer(program_));

  if (obj = nil) or (item = nil) then
    Exit;

  if item_add_force(obj, item, quantity) = 0 then
  begin
    obj_disconnect(item, @rect);
    tile_refresh_rect(@rect, item^.Elevation);
  end;
end;

{ =========================================================================
  op_rm_mult_objs_from_inven
  ========================================================================= }
procedure op_rm_mult_objs_from_inven(program_: PProgram); cdecl;
var
  quantityToRemove: Integer;
  item, owner: PObject;
  itemWasEquipped: Boolean;
  quantity: Integer;
  updatedRect: TRect;
begin
  quantityToRemove := programStackPopInteger(program_);
  item := PObject(programStackPopPointer(program_));
  owner := PObject(programStackPopPointer(program_));

  if (owner = nil) or (item = nil) then
    Exit;

  itemWasEquipped := (item^.Flags and OBJECT_EQUIPPED) <> 0;

  quantity := item_count(owner, item);
  if quantity > quantityToRemove then
    quantity := quantityToRemove;

  if quantity <> 0 then
  begin
    if item_remove_mult(owner, item, quantity) = 0 then
    begin
      obj_connect(item, 1, 0, @updatedRect);
      if itemWasEquipped then
      begin
        if owner = obj_dude then
        begin
          intface_update_items(True);
          intface_update_ac(False);
        end;
      end;
    end;
  end;

  programStackPushInteger(program_, quantity);
end;

{ =========================================================================
  op_get_month
  ========================================================================= }
procedure op_get_month(program_: PProgram); cdecl;
var
  month: Integer;
begin
  game_time_date(@month, nil, nil);
  programStackPushInteger(program_, month);
end;

{ =========================================================================
  op_get_day
  ========================================================================= }
procedure op_get_day(program_: PProgram); cdecl;
var
  day: Integer;
begin
  game_time_date(nil, @day, nil);
  programStackPushInteger(program_, day);
end;

{ =========================================================================
  op_explosion
  ========================================================================= }
procedure op_explosion(program_: PProgram); cdecl;
var
  maxDamage, elevation, tile, minDamage: Integer;
begin
  maxDamage := programStackPopInteger(program_);
  elevation := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);

  if tile = -1 then
  begin
    debug_printf(#10'Error: explosion: bad tile_num!');
    Exit;
  end;

  minDamage := 1;
  if maxDamage = 0 then
    minDamage := 0;

  scripts_request_explosion(tile, elevation, minDamage, maxDamage);
end;

{ =========================================================================
  op_days_since_visited
  ========================================================================= }
procedure op_days_since_visited(program_: PProgram); cdecl;
var
  days: Integer;
begin
  if map_data.lastVisitTime <> 0 then
    days := (game_time() - map_data.lastVisitTime) div GAME_TIME_TICKS_PER_DAY
  else
    days := -1;
  programStackPushInteger(program_, days);
end;

{ =========================================================================
  op_gsay_start
  ========================================================================= }
procedure op_gsay_start(program_: PProgram); cdecl;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  if gDialogStart() <> 0 then
  begin
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    interpretError('Error starting dialog.', []);
  end;
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_gsay_end
  ========================================================================= }
procedure op_gsay_end(program_: PProgram); cdecl;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  gDialogGo;
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_gsay_reply
  ========================================================================= }
procedure op_gsay_reply(program_: PProgram); cdecl;
var
  msg: TProgramValue;
  messageListId: Integer;
  str: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  msg := programStackPopValue(program_);
  messageListId := programStackPopInteger(program_);

  if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    str := interpretGetString(program_, msg.opcode, msg.integerValue);
    gDialogReplyStr(program_, messageListId, str);
  end
  else if msg.opcode = VALUE_TYPE_INT then
    gDialogReply(program_, messageListId, msg.integerValue)
  else
    interpretError('script error: %s: invalid arg %d to gsay_reply', [string(program_^.name), 0]);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_gsay_option
  ========================================================================= }
procedure op_gsay_option(program_: PProgram); cdecl;
var
  reaction: Integer;
  proc_, msg: TProgramValue;
  messageListId: Integer;
  procName, str: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  reaction := programStackPopInteger(program_);
  proc_ := programStackPopValue(program_);
  msg := programStackPopValue(program_);
  messageListId := programStackPopInteger(program_);

  if (proc_.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    procName := interpretGetString(program_, proc_.opcode, proc_.integerValue);
    if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    begin
      str := interpretGetString(program_, msg.opcode, msg.integerValue);
      gDialogOptionStr(messageListId, str, procName, reaction);
    end
    else if msg.opcode = VALUE_TYPE_INT then
      gDialogOption(messageListId, msg.integerValue, procName, reaction)
    else
      interpretError('script error: %s: invalid arg %d to gsay_option', [string(program_^.name), 1]);
  end
  else if (proc_.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
  begin
    if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    begin
      str := interpretGetString(program_, msg.opcode, msg.integerValue);
      gDialogOptionProcStr(messageListId, str, proc_.integerValue, reaction);
    end
    else if msg.opcode = VALUE_TYPE_INT then
      gDialogOptionProc(messageListId, msg.integerValue, proc_.integerValue, reaction)
    else
      interpretError('script error: %s: invalid arg %d to gsay_option', [string(program_^.name), 1]);
  end
  else
    interpretError('Invalid arg 3 to sayOption', []);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_gsay_message
  ========================================================================= }
procedure op_gsay_message(program_: PProgram); cdecl;
var
  reaction: Integer;
  msg: TProgramValue;
  messageListId: Integer;
  str: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  reaction := programStackPopInteger(program_);
  msg := programStackPopValue(program_);
  messageListId := programStackPopInteger(program_);

  if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    str := interpretGetString(program_, msg.opcode, msg.integerValue);
    gDialogReplyStr(program_, messageListId, str);
  end
  else if msg.opcode = VALUE_TYPE_INT then
    gDialogReply(program_, messageListId, msg.integerValue)
  else
    interpretError('script error: %s: invalid arg %d to gsay_message', [string(program_^.name), 1]);

  gDialogOption(-2, -2, nil, 50);
  gDialogSayMessage;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_giq_option
  ========================================================================= }
procedure op_giq_option(program_: PProgram); cdecl;
var
  reaction, iq: Integer;
  proc_, msg: TProgramValue;
  messageListId: Integer;
  intelligence: Integer;
  procName, str: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  reaction := programStackPopInteger(program_);
  proc_ := programStackPopValue(program_);
  msg := programStackPopValue(program_);
  messageListId := programStackPopInteger(program_);
  iq := programStackPopInteger(program_);

  intelligence := stat_level(obj_dude, Ord(STAT_INTELLIGENCE));
  intelligence := intelligence + perk_level(Ord(PERK_SMOOTH_TALKER));

  if iq < 0 then
  begin
    if -intelligence < iq then
    begin
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;
  end
  else
  begin
    if intelligence < iq then
    begin
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;
  end;

  if (proc_.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    procName := interpretGetString(program_, proc_.opcode, proc_.integerValue);
    if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    begin
      str := interpretGetString(program_, msg.opcode, msg.integerValue);
      gDialogOptionStr(messageListId, str, procName, reaction);
    end
    else if msg.opcode = VALUE_TYPE_INT then
      gDialogOption(messageListId, msg.integerValue, procName, reaction)
    else
      interpretError('script error: %s: invalid arg %d to giq_option', [string(program_^.name), 1]);
  end
  else if proc_.opcode = VALUE_TYPE_INT then
  begin
    if (msg.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    begin
      str := interpretGetString(program_, msg.opcode, msg.integerValue);
      gDialogOptionProcStr(messageListId, str, proc_.integerValue, reaction);
    end
    else if msg.opcode = VALUE_TYPE_INT then
      gDialogOptionProc(messageListId, msg.integerValue, proc_.integerValue, reaction)
    else
      interpretError('script error: %s: invalid arg %d to giq_option', [string(program_^.name), 1]);
  end
  else
    interpretError('script error: %s: invalid arg %d to giq_option', [string(program_^.name), 3]);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_poison
  ========================================================================= }
procedure op_poison(program_: PProgram); cdecl;
var
  amount: Integer;
  obj: PObject;
begin
  amount := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj = nil then
  begin
    dbg_error(program_, 'poison', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if critter_adjust_poison(obj, amount) <> 0 then
    debug_printf(#10'Script Error: poison: adjust failed!');
end;

{ =========================================================================
  op_get_poison
  ========================================================================= }
procedure op_get_poison(program_: PProgram); cdecl;
var
  obj: PObject;
  poison: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  poison := 0;
  if obj <> nil then
  begin
    if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
      poison := critter_get_poison(obj)
    else
      debug_printf(#10'Script Error: get_poison: who is not a critter!');
  end
  else
    dbg_error(program_, 'get_poison', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, poison);
end;

{ =========================================================================
  op_party_add
  ========================================================================= }
procedure op_party_add(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
  begin
    dbg_error(program_, 'party_add', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;
  partyMemberAdd(obj);
end;

{ =========================================================================
  op_party_remove
  ========================================================================= }
procedure op_party_remove(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj = nil then
  begin
    dbg_error(program_, 'party_remove', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;
  partyMemberRemove(obj);
end;

{ =========================================================================
  op_reg_anim_animate_forever
  ========================================================================= }
procedure op_reg_anim_animate_forever(program_: PProgram); cdecl;
var
  anim_: Integer;
  obj: PObject;
begin
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if not isInCombat() then
  begin
    if obj <> nil then
      register_object_animate_forever(obj, anim_, -1)
    else
      dbg_error(program_, 'reg_anim_animate_forever', SCRIPT_ERROR_OBJECT_IS_NULL);
  end;
end;

{ =========================================================================
  op_critter_injure
  ========================================================================= }
procedure op_critter_injure(program_: PProgram); cdecl;
var
  flags: Integer;
  critter: PObject;
begin
  flags := programStackPopInteger(program_);
  critter := PObject(programStackPopPointer(program_));

  if critter = nil then
  begin
    dbg_error(program_, 'critter_injure', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  flags := flags and DAM_CRIP;
  critter^.Data.AsData.Critter.Combat.Results := critter^.Data.AsData.Critter.Combat.Results or flags;

  if critter = obj_dude then
  begin
    if (flags and DAM_CRIP_ARM_ANY) <> 0 then
      intface_update_items(True);
  end;
end;

{ =========================================================================
  op_combat_is_initialized
  ========================================================================= }
procedure op_combat_is_initialized(program_: PProgram); cdecl;
begin
  if isInCombat() then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_gdialog_barter
  ========================================================================= }
procedure op_gdialog_barter(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  if gdActivateBarter(data) = -1 then
    debug_printf(#10'Script Error: gdialog_barter: failed');
end;

{ =========================================================================
  op_difficulty_level
  ========================================================================= }
procedure op_difficulty_level(program_: PProgram); cdecl;
var
  gameDifficulty: Integer;
begin
  if not config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_GAME_DIFFICULTY_KEY, @gameDifficulty) then
    gameDifficulty := GAME_DIFFICULTY_NORMAL;
  programStackPushInteger(program_, gameDifficulty);
end;

{ =========================================================================
  op_running_burning_guy
  ========================================================================= }
procedure op_running_burning_guy(program_: PProgram); cdecl;
var
  runningBurningGuy: Integer;
begin
  if not config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_BURNING_GUY_KEY, @runningBurningGuy) then
    runningBurningGuy := 1;
  programStackPushInteger(program_, runningBurningGuy);
end;

{ =========================================================================
  op_inven_unwield
  ========================================================================= }
procedure op_inven_unwield(program_: PProgram); cdecl;
var
  obj: PObject;
  v1: Integer;
begin
  obj := scr_find_obj_from_program(program_);
  v1 := 1;

  if (obj = obj_dude) and (intface_is_item_right_hand() = 0) then
    v1 := 0;

  inven_unwield(obj, v1);
end;

{ =========================================================================
  op_obj_is_locked
  ========================================================================= }
procedure op_obj_is_locked(program_: PProgram); cdecl;
var
  obj: PObject;
  locked: Boolean;
begin
  obj := PObject(programStackPopPointer(program_));
  locked := False;
  if obj <> nil then
    locked := obj_is_locked(obj)
  else
    dbg_error(program_, 'obj_is_locked', SCRIPT_ERROR_OBJECT_IS_NULL);

  if locked then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_obj_lock
  ========================================================================= }
procedure op_obj_lock(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj <> nil then
    obj_lock(obj)
  else
    dbg_error(program_, 'obj_lock', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_obj_unlock
  ========================================================================= }
procedure op_obj_unlock(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj <> nil then
    obj_unlock(obj)
  else
    dbg_error(program_, 'obj_unlock', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_obj_is_open
  ========================================================================= }
procedure op_obj_is_open(program_: PProgram); cdecl;
var
  obj: PObject;
  isOpen: Boolean;
begin
  obj := PObject(programStackPopPointer(program_));
  isOpen := False;
  if obj <> nil then
    isOpen := obj_is_open(obj) <> 0
  else
    dbg_error(program_, 'obj_is_open', SCRIPT_ERROR_OBJECT_IS_NULL);

  if isOpen then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_obj_open
  ========================================================================= }
procedure op_obj_open(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj <> nil then
    obj_open(obj)
  else
    dbg_error(program_, 'obj_open', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_obj_close
  ========================================================================= }
procedure op_obj_close(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj <> nil then
    obj_close(obj)
  else
    dbg_error(program_, 'obj_close', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_game_ui_disable
  ========================================================================= }
procedure op_game_ui_disable(program_: PProgram); cdecl;
begin
  game_ui_disable(0);
end;

{ =========================================================================
  op_game_ui_enable
  ========================================================================= }
procedure op_game_ui_enable(program_: PProgram); cdecl;
begin
  game_ui_enable;
end;

{ =========================================================================
  op_game_ui_is_disabled
  ========================================================================= }
procedure op_game_ui_is_disabled(program_: PProgram); cdecl;
begin
  programStackPushInteger(program_, Ord(game_ui_is_disabled()));
end;

{ =========================================================================
  op_gfade_out
  ========================================================================= }
procedure op_gfade_out(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  if data <> 0 then
    palette_fade_to(@black_palette[0])
  else
    dbg_error(program_, 'gfade_out', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_gfade_in
  ========================================================================= }
procedure op_gfade_in(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  if data <> 0 then
    palette_fade_to(@cmap[0])
  else
    dbg_error(program_, 'gfade_in', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_item_caps_total
  ========================================================================= }
procedure op_item_caps_total(program_: PProgram); cdecl;
var
  obj: PObject;
  amount: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  amount := 0;
  if obj <> nil then
    amount := item_caps_total(obj)
  else
    dbg_error(program_, 'item_caps_total', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, amount);
end;

{ =========================================================================
  op_item_caps_adjust
  ========================================================================= }
procedure op_item_caps_adjust(program_: PProgram); cdecl;
var
  amount: Integer;
  obj: PObject;
  rc: Integer;
begin
  amount := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));
  rc := -1;
  if obj <> nil then
    rc := item_caps_adjust(obj, amount)
  else
    dbg_error(program_, 'item_caps_adjust', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, rc);
end;

{ =========================================================================
  op_anim_action_frame
  ========================================================================= }
procedure op_anim_action_frame(program_: PProgram); cdecl;
var
  anim_: Integer;
  obj: PObject;
  actionFrame, fid: Integer;
  frmHandle: PCacheEntry;
  frm: PArt;
begin
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  actionFrame := 0;
  if obj <> nil then
  begin
    fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim_, 0, obj^.Rotation);
    frm := art_ptr_lock(fid, @frmHandle);
    if frm <> nil then
    begin
      actionFrame := art_frame_action_frame(frm);
      art_ptr_unlock(frmHandle);
    end;
  end
  else
    dbg_error(program_, 'anim_action_frame', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, actionFrame);
end;

{ =========================================================================
  op_reg_anim_play_sfx
  ========================================================================= }
procedure op_reg_anim_play_sfx(program_: PProgram); cdecl;
var
  delay: Integer;
  soundEffectName: PAnsiChar;
  obj: PObject;
begin
  delay := programStackPopInteger(program_);
  soundEffectName := programStackPopString(program_);
  obj := PObject(programStackPopPointer(program_));

  if soundEffectName = nil then
  begin
    dbg_error(program_, 'reg_anim_play_sfx', SCRIPT_ERROR_FOLLOWS);
    debug_printf(' Can''t match string!');
  end;

  if obj <> nil then
    register_object_play_sfx(obj, soundEffectName, delay)
  else
    dbg_error(program_, 'reg_anim_play_sfx', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_critter_mod_skill
  ========================================================================= }
procedure op_critter_mod_skill(program_: PProgram); cdecl;
var
  points, skill: Integer;
  critter: PObject;
  it: Integer;
begin
  points := programStackPopInteger(program_);
  skill := programStackPopInteger(program_);
  critter := PObject(programStackPopPointer(program_));

  if (critter <> nil) and (points <> 0) then
  begin
    if PID_TYPE(critter^.Pid) = OBJ_TYPE_CRITTER then
    begin
      if critter = obj_dude then
      begin
        if stat_pc_set(Ord(PC_STAT_UNSPENT_SKILL_POINTS), stat_pc_get(Ord(PC_STAT_UNSPENT_SKILL_POINTS)) + points) = 0 then
        begin
          for it := 0 to points - 1 do
            skill_inc_point(obj_dude, skill);
        end;
      end
      else
      begin
        dbg_error(program_, 'critter_mod_skill', SCRIPT_ERROR_FOLLOWS);
        debug_printf(' Can''t modify anyone except obj_dude!');
      end;
    end;
  end
  else
    dbg_error(program_, 'critter_mod_skill', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_sfx_build_char_name
  ========================================================================= }
procedure op_sfx_build_char_name(program_: PProgram); cdecl;
var
  extra, anim_: Integer;
  obj: PObject;
  soundEffectName: array[0..15] of AnsiChar;
begin
  extra := programStackPopInteger(program_);
  anim_ := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj <> nil then
  begin
    StrCopy(soundEffectName, gsnd_build_character_sfx_name(obj, anim_, extra));
    programStackPushString(program_, soundEffectName);
  end
  else
  begin
    dbg_error(program_, 'sfx_build_char_name', SCRIPT_ERROR_OBJECT_IS_NULL);
    programStackPushString(program_, nil);
  end;
end;

{ =========================================================================
  op_sfx_build_ambient_name
  ========================================================================= }
procedure op_sfx_build_ambient_name(program_: PProgram); cdecl;
var
  baseName: PAnsiChar;
  soundEffectName: array[0..15] of AnsiChar;
begin
  baseName := programStackPopString(program_);
  StrCopy(soundEffectName, gsnd_build_ambient_sfx_name(baseName));
  programStackPushString(program_, soundEffectName);
end;

{ =========================================================================
  op_sfx_build_interface_name
  ========================================================================= }
procedure op_sfx_build_interface_name(program_: PProgram); cdecl;
var
  baseName: PAnsiChar;
  soundEffectName: array[0..15] of AnsiChar;
begin
  baseName := programStackPopString(program_);
  StrCopy(soundEffectName, gsnd_build_interface_sfx_name(baseName));
  programStackPushString(program_, soundEffectName);
end;

{ =========================================================================
  op_sfx_build_item_name
  ========================================================================= }
procedure op_sfx_build_item_name(program_: PProgram); cdecl;
var
  baseName: PAnsiChar;
  soundEffectName: array[0..15] of AnsiChar;
begin
  baseName := programStackPopString(program_);
  StrCopy(soundEffectName, gsnd_build_interface_sfx_name(baseName));
  programStackPushString(program_, soundEffectName);
end;

{ =========================================================================
  op_sfx_build_weapon_name
  ========================================================================= }
procedure op_sfx_build_weapon_name(program_: PProgram); cdecl;
var
  target, weapon: PObject;
  hitMode, weaponSfxType: Integer;
  soundEffectName: array[0..15] of AnsiChar;
begin
  target := PObject(programStackPopPointer(program_));
  hitMode := programStackPopInteger(program_);
  weapon := PObject(programStackPopPointer(program_));
  weaponSfxType := programStackPopInteger(program_);

  StrCopy(soundEffectName, gsnd_build_weapon_sfx_name(weaponSfxType, weapon, hitMode, target));
  programStackPushString(program_, soundEffectName);
end;

{ =========================================================================
  op_sfx_build_scenery_name
  ========================================================================= }
procedure op_sfx_build_scenery_name(program_: PProgram); cdecl;
var
  actionType, action: Integer;
  baseName: PAnsiChar;
  soundEffectName: array[0..15] of AnsiChar;
begin
  actionType := programStackPopInteger(program_);
  action := programStackPopInteger(program_);
  baseName := programStackPopString(program_);

  StrCopy(soundEffectName, gsnd_build_scenery_sfx_name(actionType, action, baseName));
  programStackPushString(program_, soundEffectName);
end;

{ =========================================================================
  op_sfx_build_open_name
  ========================================================================= }
procedure op_sfx_build_open_name(program_: PProgram); cdecl;
var
  action: Integer;
  obj: PObject;
  soundEffectName: array[0..15] of AnsiChar;
begin
  action := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj <> nil then
  begin
    StrCopy(soundEffectName, gsnd_build_open_sfx_name(obj, action));
    programStackPushString(program_, soundEffectName);
  end
  else
  begin
    dbg_error(program_, 'sfx_build_open_name', SCRIPT_ERROR_OBJECT_IS_NULL);
    programStackPushString(program_, nil);
  end;
end;

{ =========================================================================
  op_attack_setup
  ========================================================================= }
procedure op_attack_setup(program_: PProgram); cdecl;
var
  defender, attacker: PObject;
  attack: TSTRUCT_664980;
begin
  defender := PObject(programStackPopPointer(program_));
  attacker := PObject(programStackPopPointer(program_));

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  if attacker <> nil then
  begin
    if not critter_is_active(attacker) then
    begin
      dbg_print_com_data(attacker, defender);
      debug_printf(#10'   But is already dead');
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;

    if not critter_is_active(defender) then
    begin
      dbg_print_com_data(attacker, defender);
      debug_printf(#10'   But target is already dead');
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;

    if (defender^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0 then
    begin
      dbg_print_com_data(attacker, defender);
      debug_printf(#10'   But target is AFRAID');
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      Exit;
    end;

    if isInCombat() then
    begin
      if (attacker^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANEUVER_ENGAGING) = 0 then
      begin
        attacker^.Data.AsData.Critter.Combat.Maneuver := attacker^.Data.AsData.Critter.Combat.Maneuver or CRITTER_MANEUVER_ENGAGING;
        attacker^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := defender;
      end;
    end
    else
    begin
      FillChar(attack, SizeOf(attack), 0);
      attack.attacker := attacker;
      attack.defender := defender;
      attack.actionPointsBonus := 0;
      attack.accuracyBonus := 0;
      attack.damageBonus := 0;
      attack.minDamage := 0;
      attack.maxDamage := MaxInt;
      attack.field_1C := 0;

      dbg_print_com_data(attacker, defender);
      scripts_request_combat(@attack);
    end;
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_destroy_mult_objs
  ========================================================================= }
procedure op_destroy_mult_objs(program_: PProgram); cdecl;
var
  quantity: Integer;
  obj, self_, owner: PObject;
  isSelf: Boolean;
  result_, quantityToDestroy: Integer;
  rect: TRect;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  quantity := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  self_ := scr_find_obj_from_program(program_);
  isSelf := self_ = obj;

  result_ := 0;

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    combat_delete_critter(obj);

  owner := obj_top_environment(obj);
  if owner <> nil then
  begin
    quantityToDestroy := item_count(owner, obj);
    if quantityToDestroy > quantity then
      quantityToDestroy := quantity;

    item_remove_mult(owner, obj, quantityToDestroy);

    if owner = obj_dude then
      intface_update_items(True);

    obj_connect(obj, 1, 0, nil);

    if isSelf then
    begin
      obj^.Sid := -1;
      obj^.Flags := obj^.Flags or (OBJECT_HIDDEN or OBJECT_NO_SAVE);
    end
    else
    begin
      register_clear(obj);
      obj_erase_object(obj, nil);
    end;

    result_ := quantityToDestroy;
  end
  else
  begin
    register_clear(obj);
    obj_erase_object(obj, @rect);
    tile_refresh_rect(@rect, map_elevation);
  end;

  programStackPushInteger(program_, result_);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if isSelf then
    program_^.flags := program_^.flags or PROGRAM_FLAG_0x0100;
end;

{ =========================================================================
  op_use_obj_on_obj
  ========================================================================= }
procedure op_use_obj_on_obj(program_: PProgram); cdecl;
var
  target, item, self_: PObject;
  script: PScript;
  sid: Integer;
begin
  target := PObject(programStackPopPointer(program_));
  item := PObject(programStackPopPointer(program_));

  if item = nil then
  begin
    dbg_error(program_, 'use_obj_on_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if target = nil then
  begin
    dbg_error(program_, 'use_obj_on_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  sid := scr_find_sid_from_program(program_);
  if scr_ptr(sid, @script) = -1 then
  begin
    dbg_error(program_, 'use_obj_on_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  self_ := scr_find_obj_from_program(program_);
  if PID_TYPE(self_^.Pid) = OBJ_TYPE_CRITTER then
    action_use_an_item_on_object(self_, target, item)
  else
    obj_use_item_on(self_, target, item);
end;

{ =========================================================================
  op_endgame_slideshow
  ========================================================================= }
procedure op_endgame_slideshow(program_: PProgram); cdecl;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  scripts_request_endgame_slideshow;
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_move_obj_inven_to_obj
  ========================================================================= }
procedure op_move_obj_inven_to_obj(program_: PProgram); cdecl;
var
  object2, object1, oldArmor, item2: PObject;
  flags: Integer;
begin
  object2 := PObject(programStackPopPointer(program_));
  object1 := PObject(programStackPopPointer(program_));

  if object1 = nil then
  begin
    dbg_error(program_, 'move_obj_inven_to_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  if object2 = nil then
  begin
    dbg_error(program_, 'move_obj_inven_to_obj', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  oldArmor := nil;
  item2 := nil;
  if object1 = obj_dude then
    oldArmor := inven_worn(object1)
  else
    item2 := inven_right_hand(object1);

  if (object1 <> obj_dude) and (item2 <> nil) then
  begin
    flags := 0;
    if (item2^.Flags and OBJECT_IN_LEFT_HAND) <> 0 then
      flags := flags or OBJECT_IN_LEFT_HAND;
    if (item2^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
      flags := flags or OBJECT_IN_RIGHT_HAND;
    correctFidForRemovedItem(object1, item2, flags);
  end;

  item_move_all(object1, object2);

  if object1 = obj_dude then
  begin
    if oldArmor <> nil then
      adjust_ac(obj_dude, oldArmor, nil);
    proto_dude_update_gender;
    intface_update_items(True);
  end;
end;

{ =========================================================================
  op_endgame_movie
  ========================================================================= }
procedure op_endgame_movie(program_: PProgram); cdecl;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  endgame_movie;
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

{ =========================================================================
  op_obj_art_fid
  ========================================================================= }
procedure op_obj_art_fid(program_: PProgram); cdecl;
var
  obj: PObject;
  fid: Integer;
begin
  obj := PObject(programStackPopPointer(program_));
  fid := 0;
  if obj <> nil then
    fid := obj^.Fid
  else
    dbg_error(program_, 'obj_art_fid', SCRIPT_ERROR_OBJECT_IS_NULL);
  programStackPushInteger(program_, fid);
end;

{ =========================================================================
  op_art_anim
  ========================================================================= }
procedure op_art_anim(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  programStackPushInteger(program_, (data and $FF0000) shr 16);
end;

{ =========================================================================
  op_party_member_obj
  ========================================================================= }
procedure op_party_member_obj(program_: PProgram); cdecl;
var
  data: Integer;
  obj: PObject;
begin
  data := programStackPopInteger(program_);
  obj := partyMemberFindObjFromPid(data);
  programStackPushPointer(program_, obj);
end;

{ =========================================================================
  op_rotation_to_tile
  ========================================================================= }
procedure op_rotation_to_tile(program_: PProgram); cdecl;
var
  tile2, tile1, rotation: Integer;
begin
  tile2 := programStackPopInteger(program_);
  tile1 := programStackPopInteger(program_);
  rotation := tile_dir(tile1, tile2);
  programStackPushInteger(program_, rotation);
end;

{ =========================================================================
  op_jam_lock
  ========================================================================= }
procedure op_jam_lock(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  obj_jam_lock(obj);
end;

{ =========================================================================
  op_gdialog_set_barter_mod
  ========================================================================= }
procedure op_gdialog_set_barter_mod(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  gdialogSetBarterMod(data);
end;

{ =========================================================================
  op_combat_difficulty
  ========================================================================= }
procedure op_combat_difficulty(program_: PProgram); cdecl;
var
  combatDifficulty: Integer;
begin
  if not config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, @combatDifficulty) then
    combatDifficulty := 0;
  programStackPushInteger(program_, combatDifficulty);
end;

{ =========================================================================
  op_obj_on_screen
  ========================================================================= }
procedure op_obj_on_screen(program_: PProgram); cdecl;
var
  obj: PObject;
  result_: Integer;
  objectRect: TRect;
begin
  obj := PObject(programStackPopPointer(program_));
  result_ := 0;

  if obj <> nil then
  begin
    if map_elevation = obj^.Elevation then
    begin
      obj_bound(obj, @objectRect);
      if rect_inside_bound(@objectRect, @scr_size, @objectRect) = 0 then
        result_ := 1;
    end;
  end
  else
    dbg_error(program_, 'obj_on_screen', SCRIPT_ERROR_OBJECT_IS_NULL);

  programStackPushInteger(program_, result_);
end;

{ =========================================================================
  op_critter_is_fleeing
  ========================================================================= }
procedure op_critter_is_fleeing(program_: PProgram); cdecl;
var
  obj: PObject;
  fleeing: Boolean;
begin
  obj := PObject(programStackPopPointer(program_));
  fleeing := False;
  if obj <> nil then
    fleeing := (obj^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0
  else
    dbg_error(program_, 'critter_is_fleeing', SCRIPT_ERROR_OBJECT_IS_NULL);

  if fleeing then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

{ =========================================================================
  op_critter_set_flee_state
  ========================================================================= }
procedure op_critter_set_flee_state(program_: PProgram); cdecl;
var
  fleeing: Integer;
  obj: PObject;
begin
  fleeing := programStackPopInteger(program_);
  obj := PObject(programStackPopPointer(program_));

  if obj <> nil then
  begin
    if fleeing <> 0 then
      obj^.Data.AsData.Critter.Combat.Maneuver := obj^.Data.AsData.Critter.Combat.Maneuver or CRITTER_MANUEVER_FLEEING
    else
      obj^.Data.AsData.Critter.Combat.Maneuver := obj^.Data.AsData.Critter.Combat.Maneuver and (not CRITTER_MANUEVER_FLEEING);
  end
  else
    dbg_error(program_, 'critter_set_flee_state', SCRIPT_ERROR_OBJECT_IS_NULL);
end;

{ =========================================================================
  op_terminate_combat
  ========================================================================= }
procedure op_terminate_combat(program_: PProgram); cdecl;
begin
  if isInCombat() then
    game_user_wants_to_quit := 1;
end;

{ =========================================================================
  op_debug_msg
  ========================================================================= }
procedure op_debug_msg(program_: PProgram); cdecl;
var
  str: PAnsiChar;
  showScriptMessages: Boolean;
begin
  str := programStackPopString(program_);

  if str <> nil then
  begin
    showScriptMessages := False;
    configGetBool(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_SCRIPT_MESSAGES_KEY, @showScriptMessages);
    if showScriptMessages then
    begin
      debug_printf(#10);
      debug_printf(str);
    end;
  end;
end;

{ =========================================================================
  op_critter_stop_attacking
  ========================================================================= }
procedure op_critter_stop_attacking(program_: PProgram); cdecl;
var
  critter: PObject;
begin
  critter := PObject(programStackPopPointer(program_));
  if critter = nil then
  begin
    dbg_error(program_, 'critter_stop_attacking', SCRIPT_ERROR_OBJECT_IS_NULL);
    Exit;
  end;

  critter^.Data.AsData.Critter.Combat.Maneuver := critter^.Data.AsData.Critter.Combat.Maneuver or CRITTER_MANEUVER_DISENGAGING;
  critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;
end;

{ =========================================================================
  op_tile_contains_pid_obj
  ========================================================================= }
procedure op_tile_contains_pid_obj(program_: PProgram); cdecl;
var
  pid, elevation, tile: Integer;
  found, obj: PObject;
begin
  pid := programStackPopInteger(program_);
  elevation := programStackPopInteger(program_);
  tile := programStackPopInteger(program_);
  found := nil;

  if tile <> -1 then
  begin
    obj := obj_find_first_at(elevation);
    while obj <> nil do
    begin
      if (obj^.Tile = tile) and (obj^.Pid = pid) then
      begin
        found := obj;
        Break;
      end;
      obj := obj_find_next_at();
    end;
  end;

  programStackPushPointer(program_, found);
end;

{ =========================================================================
  op_obj_name
  ========================================================================= }
procedure op_obj_name(program_: PProgram); cdecl;
var
  obj: PObject;
begin
  obj := PObject(programStackPopPointer(program_));
  if obj <> nil then
    strName := object_name(obj)
  else
  begin
    dbg_error(program_, 'obj_name', SCRIPT_ERROR_OBJECT_IS_NULL);
    if strName = nil then
      strName := @_aCritter[0];
  end;
  programStackPushString(program_, strName);
end;

{ =========================================================================
  op_get_pc_stat
  ========================================================================= }
procedure op_get_pc_stat(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  programStackPushInteger(program_, stat_pc_get(data));
end;

{ =========================================================================
  intExtraClose
  ========================================================================= }
procedure intExtraClose;
begin
  // Empty in original
end;

{ =========================================================================
  initIntExtra
  ========================================================================= }
procedure initIntExtra;
begin
  interpretAddFunc($80A1, @op_give_exp_points);
  interpretAddFunc($80A2, @op_scr_return);
  interpretAddFunc($80A3, @op_play_sfx);
  interpretAddFunc($80A4, @op_obj_name);
  interpretAddFunc($80A5, @op_sfx_build_open_name);
  interpretAddFunc($80A6, @op_get_pc_stat);
  interpretAddFunc($80A7, @op_tile_contains_pid_obj);
  interpretAddFunc($80A8, @op_set_map_start);
  interpretAddFunc($80A9, @op_override_map_start);
  interpretAddFunc($80AA, @op_has_skill);
  interpretAddFunc($80AB, @op_using_skill);
  interpretAddFunc($80AC, @op_roll_vs_skill);
  interpretAddFunc($80AD, @op_skill_contest);
  interpretAddFunc($80AE, @op_do_check);
  interpretAddFunc($80AF, @op_is_success);
  interpretAddFunc($80B0, @op_is_critical);
  interpretAddFunc($80B1, @op_how_much);
  interpretAddFunc($80B2, @op_reaction_roll);
  interpretAddFunc($80B3, @op_reaction_influence);
  interpretAddFunc($80B4, @op_random);
  interpretAddFunc($80B5, @op_roll_dice);
  interpretAddFunc($80B6, @op_move_to);
  interpretAddFunc($80B7, @op_create_object_sid);
  interpretAddFunc($80B8, @op_display_msg);
  interpretAddFunc($80B9, @op_script_overrides);
  interpretAddFunc($80BA, @op_obj_is_carrying_obj_pid);
  interpretAddFunc($80BB, @op_tile_contains_obj_pid);
  interpretAddFunc($80BC, @op_self_obj);
  interpretAddFunc($80BD, @op_source_obj);
  interpretAddFunc($80BE, @op_target_obj);
  interpretAddFunc($80BF, @op_dude_obj);
  interpretAddFunc($80C0, @op_obj_being_used_with);
  interpretAddFunc($80C1, @op_local_var);
  interpretAddFunc($80C2, @op_set_local_var);
  interpretAddFunc($80C3, @op_map_var);
  interpretAddFunc($80C4, @op_set_map_var);
  interpretAddFunc($80C5, @op_global_var);
  interpretAddFunc($80C6, @op_set_global_var);
  interpretAddFunc($80C7, @op_script_action);
  interpretAddFunc($80C8, @op_obj_type);
  interpretAddFunc($80C9, @op_obj_item_subtype);
  interpretAddFunc($80CA, @op_get_critter_stat);
  interpretAddFunc($80CB, @op_set_critter_stat);
  interpretAddFunc($80CC, @op_animate_stand_obj);
  interpretAddFunc($80CD, @op_animate_stand_reverse_obj);
  interpretAddFunc($80CE, @op_animate_move_obj_to_tile);
  interpretAddFunc($80CF, @op_animate_jump);
  interpretAddFunc($80D0, @op_attack);
  interpretAddFunc($80D1, @op_make_daytime);
  interpretAddFunc($80D2, @op_tile_distance);
  interpretAddFunc($80D3, @op_tile_distance_objs);
  interpretAddFunc($80D4, @op_tile_num);
  interpretAddFunc($80D5, @op_tile_num_in_direction);
  interpretAddFunc($80D6, @op_pickup_obj);
  interpretAddFunc($80D7, @op_drop_obj);
  interpretAddFunc($80D8, @op_add_obj_to_inven);
  interpretAddFunc($80D9, @op_rm_obj_from_inven);
  interpretAddFunc($80DA, @op_wield_obj_critter);
  interpretAddFunc($80DB, @op_use_obj);
  interpretAddFunc($80DC, @op_obj_can_see_obj);
  interpretAddFunc($80DD, @op_attack);
  interpretAddFunc($80DE, @op_start_gdialog);
  interpretAddFunc($80DF, @op_end_dialogue);
  interpretAddFunc($80E0, @op_dialogue_reaction);
  interpretAddFunc($80E1, @op_turn_off_objs_in_area);
  interpretAddFunc($80E2, @op_turn_on_objs_in_area);
  interpretAddFunc($80E3, @op_set_obj_visibility);
  interpretAddFunc($80E4, @op_load_map);
  interpretAddFunc($80E5, @op_barter_offer);
  interpretAddFunc($80E6, @op_barter_asking);
  interpretAddFunc($80E7, @op_anim_busy);
  interpretAddFunc($80E8, @op_critter_heal);
  interpretAddFunc($80E9, @op_set_light_level);
  interpretAddFunc($80EA, @op_game_time);
  interpretAddFunc($80EB, @op_game_time_in_seconds);
  interpretAddFunc($80EC, @op_elevation);
  interpretAddFunc($80ED, @op_kill_critter);
  interpretAddFunc($80EE, @op_kill_critter_type);
  interpretAddFunc($80EF, @op_critter_damage);
  interpretAddFunc($80F0, @op_add_timer_event);
  interpretAddFunc($80F1, @op_rm_timer_event);
  interpretAddFunc($80F2, @op_game_ticks);
  interpretAddFunc($80F3, @op_has_trait);
  interpretAddFunc($80F4, @op_destroy_object);
  interpretAddFunc($80F5, @op_obj_can_hear_obj);
  interpretAddFunc($80F6, @op_game_time_hour);
  interpretAddFunc($80F7, @op_fixed_param);
  interpretAddFunc($80F8, @op_tile_is_visible);
  interpretAddFunc($80F9, @op_dialogue_system_enter);
  interpretAddFunc($80FA, @op_action_being_used);
  interpretAddFunc($80FB, @op_critter_state);
  interpretAddFunc($80FC, @op_game_time_advance);
  interpretAddFunc($80FD, @op_radiation_inc);
  interpretAddFunc($80FE, @op_radiation_dec);
  interpretAddFunc($80FF, @op_critter_attempt_placement);
  interpretAddFunc($8100, @op_obj_pid);
  interpretAddFunc($8101, @op_cur_map_index);
  interpretAddFunc($8102, @op_critter_add_trait);
  interpretAddFunc($8103, @op_critter_rm_trait);
  interpretAddFunc($8104, @op_proto_data);
  interpretAddFunc($8105, @op_message_str);
  interpretAddFunc($8106, @op_critter_inven_obj);
  interpretAddFunc($8107, @op_obj_set_light_level);
  interpretAddFunc($8108, @op_world_map);
  interpretAddFunc($8109, @op_town_map);
  interpretAddFunc($810A, @op_float_msg);
  interpretAddFunc($810B, @op_metarule);
  interpretAddFunc($810C, @op_anim);
  interpretAddFunc($810D, @op_obj_carrying_pid_obj);
  interpretAddFunc($810E, @op_reg_anim_func);
  interpretAddFunc($810F, @op_reg_anim_animate);
  interpretAddFunc($8110, @op_reg_anim_animate_reverse);
  interpretAddFunc($8111, @op_reg_anim_obj_move_to_obj);
  interpretAddFunc($8112, @op_reg_anim_obj_run_to_obj);
  interpretAddFunc($8113, @op_reg_anim_obj_move_to_tile);
  interpretAddFunc($8114, @op_reg_anim_obj_run_to_tile);
  interpretAddFunc($8115, @op_play_gmovie);
  interpretAddFunc($8116, @op_add_mult_objs_to_inven);
  interpretAddFunc($8117, @op_rm_mult_objs_from_inven);
  interpretAddFunc($8118, @op_get_month);
  interpretAddFunc($8119, @op_get_day);
  interpretAddFunc($811A, @op_explosion);
  interpretAddFunc($811B, @op_days_since_visited);
  interpretAddFunc($811C, @op_gsay_start);
  interpretAddFunc($811D, @op_gsay_end);
  interpretAddFunc($811E, @op_gsay_reply);
  interpretAddFunc($811F, @op_gsay_option);
  interpretAddFunc($8120, @op_gsay_message);
  interpretAddFunc($8121, @op_giq_option);
  interpretAddFunc($8122, @op_poison);
  interpretAddFunc($8123, @op_get_poison);
  interpretAddFunc($8124, @op_party_add);
  interpretAddFunc($8125, @op_party_remove);
  interpretAddFunc($8126, @op_reg_anim_animate_forever);
  interpretAddFunc($8127, @op_critter_injure);
  interpretAddFunc($8128, @op_combat_is_initialized);
  interpretAddFunc($8129, @op_gdialog_barter);
  interpretAddFunc($812A, @op_difficulty_level);
  interpretAddFunc($812B, @op_running_burning_guy);
  interpretAddFunc($812C, @op_inven_unwield);
  interpretAddFunc($812D, @op_obj_is_locked);
  interpretAddFunc($812E, @op_obj_lock);
  interpretAddFunc($812F, @op_obj_unlock);
  interpretAddFunc($8131, @op_obj_open);
  interpretAddFunc($8130, @op_obj_is_open);
  interpretAddFunc($8132, @op_obj_close);
  interpretAddFunc($8133, @op_game_ui_disable);
  interpretAddFunc($8134, @op_game_ui_enable);
  interpretAddFunc($8135, @op_game_ui_is_disabled);
  interpretAddFunc($8136, @op_gfade_out);
  interpretAddFunc($8137, @op_gfade_in);
  interpretAddFunc($8138, @op_item_caps_total);
  interpretAddFunc($8139, @op_item_caps_adjust);
  interpretAddFunc($813A, @op_anim_action_frame);
  interpretAddFunc($813B, @op_reg_anim_play_sfx);
  interpretAddFunc($813C, @op_critter_mod_skill);
  interpretAddFunc($813D, @op_sfx_build_char_name);
  interpretAddFunc($813E, @op_sfx_build_ambient_name);
  interpretAddFunc($813F, @op_sfx_build_interface_name);
  interpretAddFunc($8140, @op_sfx_build_item_name);
  interpretAddFunc($8141, @op_sfx_build_weapon_name);
  interpretAddFunc($8142, @op_sfx_build_scenery_name);
  interpretAddFunc($8143, @op_attack_setup);
  interpretAddFunc($8144, @op_destroy_mult_objs);
  interpretAddFunc($8145, @op_use_obj_on_obj);
  interpretAddFunc($8146, @op_endgame_slideshow);
  interpretAddFunc($8147, @op_move_obj_inven_to_obj);
  interpretAddFunc($8148, @op_endgame_movie);
  interpretAddFunc($8149, @op_obj_art_fid);
  interpretAddFunc($814A, @op_art_anim);
  interpretAddFunc($814B, @op_party_member_obj);
  interpretAddFunc($814C, @op_rotation_to_tile);
  interpretAddFunc($814D, @op_jam_lock);
  interpretAddFunc($814E, @op_gdialog_set_barter_mod);
  interpretAddFunc($814F, @op_combat_difficulty);
  interpretAddFunc($8150, @op_obj_on_screen);
  interpretAddFunc($8151, @op_critter_is_fleeing);
  interpretAddFunc($8152, @op_critter_set_flee_state);
  interpretAddFunc($8153, @op_terminate_combat);
  interpretAddFunc($8154, @op_debug_msg);
  interpretAddFunc($8155, @op_critter_stop_attacking);
end;

{ =========================================================================
  updateIntExtra
  ========================================================================= }
procedure updateIntExtra;
begin
  // Empty in original
end;

{ =========================================================================
  intExtraRemoveProgramReferences
  ========================================================================= }
procedure intExtraRemoveProgramReferences(program_: PProgram);
begin
  // Empty in original
end;

initialization
  strName := @_aCritter[0];

end.
