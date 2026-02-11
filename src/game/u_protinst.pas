unit u_protinst;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/protinst.h + protinst.cc
// Prototype instance operations: use, examine, look-at, pickup, drop,
// door/container/lock manipulation, skill-on, placement.

interface

uses
  u_object_types, u_proto_types, u_rect;

type
  TDisplayPrintProc = procedure(str: PAnsiChar);

function obj_sid(obj: PObject; sidPtr: PInteger): Integer;
function obj_new_sid(obj: PObject; sidPtr: PInteger): Integer;
function obj_new_sid_inst(obj: PObject; scriptType: Integer; a3: Integer): Integer;
function obj_look_at(a1: PObject; a2: PObject): Integer;
function obj_look_at_func(a1: PObject; a2: PObject; a3: TDisplayPrintProc): Integer;
function obj_examine(a1: PObject; a2: PObject): Integer;
function obj_examine_func(critter: PObject; target: PObject; fn: TDisplayPrintProc): Integer;
function obj_pickup(critter: PObject; item: PObject): Integer;
function obj_remove_from_inven(critter: PObject; item: PObject): Integer;
function obj_drop(a1: PObject; a2: PObject): Integer;
function obj_destroy(obj: PObject): Integer;
function obj_use_radio(item: PObject): Integer;
function protinst_use_item(critter: PObject; item: PObject): Integer;
function obj_use_item(a1: PObject; a2: PObject): Integer;
function protinst_use_item_on(a1: PObject; a2: PObject; item: PObject): Integer;
function obj_use_item_on(a1: PObject; a2: PObject; a3: PObject): Integer;
function check_scenery_ap_cost(obj: PObject; a2: PObject): Integer;
function obj_use(a1: PObject; a2: PObject): Integer;
function obj_use_door(a1: PObject; a2: PObject; a3: Integer): Integer;
function obj_use_container(critter: PObject; item: PObject): Integer;
function obj_use_skill_on(source: PObject; target: PObject; skill: Integer): Integer;
function obj_is_a_portal(obj: PObject): Boolean;
function obj_is_lockable(obj: PObject): Boolean;
function obj_is_locked(obj: PObject): Boolean;
function obj_lock(obj: PObject): Integer;
function obj_unlock(obj: PObject): Integer;
function obj_is_openable(obj: PObject): Boolean;
function obj_is_open(obj: PObject): Integer;
function obj_toggle_open(obj: PObject): Integer;
function obj_open(obj: PObject): Integer;
function obj_close(obj: PObject): Integer;
function obj_lock_is_jammed(obj: PObject): Boolean;
function obj_jam_lock(obj: PObject): Integer;
function obj_unjam_lock(obj: PObject): Integer;
function obj_unjam_all_locks: Integer;
function obj_attempt_placement(obj: PObject; tile: Integer; elevation: Integer; a4: Integer): Integer;

implementation

uses
  SysUtils, u_cache, u_proto, u_art, u_anim, u_palette, u_color, u_debug,
  u_message, u_object, u_display, u_critter, u_item, u_inventry,
  u_intface, u_scripts, u_stat, u_skill, u_perk, u_roll,
  u_tile, u_queue, u_gsound, u_game, u_map, u_combat;


// -----------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------
const
  // ScriptType
  SCRIPT_TYPE_SYSTEM  = 0;
  SCRIPT_TYPE_SPATIAL = 1;
  SCRIPT_TYPE_TIMED   = 2;
  SCRIPT_TYPE_ITEM    = 3;
  SCRIPT_TYPE_CRITTER = 4;

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
  SCRIPT_PROC_LOOK_AT       = 21;
  SCRIPT_PROC_MAP_UPDATE    = 23;

  // Skill enum values
  SKILL_SMALL_GUNS    = 0;
  SKILL_FIRST_AID     = 6;
  SKILL_DOCTOR        = 7;
  SKILL_TRAPS         = 11;
  SKILL_SCIENCE       = 12;
  SKILL_REPAIR        = 13;
  SKILL_OUTDOORSMAN   = 17;

  // Stat enum values
  STAT_INTELLIGENCE          = 4;
  STAT_MAXIMUM_HIT_POINTS    = 7;
  STAT_GENDER                = 34;
  STAT_CURRENT_HIT_POINTS    = 35;

  // PcStat enum values
  PC_STAT_UNSPENT_SKILL_POINTS = 0;

  // Perk enum values
  PERK_AWARENESS = 0;

  // Roll enum values
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

  // EventType enum values
  EVENT_TYPE_FLARE             = 7;
  EVENT_TYPE_EXPLOSION         = 8;
  EVENT_TYPE_EXPLOSION_FAILURE = 11;

  // BodyType
  BODY_TYPE_BIPED = 0;

  // ScenerySoundEffect
  SCENERY_SOUND_EFFECT_OPEN     = 0;
  SCENERY_SOUND_EFFECT_CLOSED   = 1;
  SCENERY_SOUND_EFFECT_LOCKED   = 2;
  SCENERY_SOUND_EFFECT_UNLOCKED = 3;
  SCENERY_SOUND_EFFECT_USED     = 4;

  // Animation constants
  ANIMATION_REQUEST_RESERVED = $02;

// -----------------------------------------------------------------------
// Forward declarations of static (local) functions
// -----------------------------------------------------------------------
function obj_use_book(book: PObject): Integer; forward;
function obj_use_flare(critter_obj: PObject; flare: PObject): Integer; forward;
function obj_use_explosive(explosive: PObject): Integer; forward;
function protinst_default_use_item(a1: PObject; a2: PObject; item: PObject): Integer; forward;
function rebuild_all_light: Integer; forward;
function set_door_state_open(a1: PObject; a2: PObject): Integer; cdecl; forward;
function set_door_state_closed(a1: PObject; a2: PObject): Integer; cdecl; forward;
function check_door_state(a1: PObject; a2: PObject): Integer; cdecl; forward;

// =======================================================================
// obj_sid
// 0x489F60
// =======================================================================
function obj_sid(obj: PObject; sidPtr: PInteger): Integer;
begin
  sidPtr^ := obj^.Sid;
  if sidPtr^ = -1 then
  begin
    Result := -1;
    Exit;
  end;
  Result := 0;
end;

// =======================================================================
// obj_new_sid
// 0x489F74
// =======================================================================
function obj_new_sid(obj: PObject; sidPtr: PInteger): Integer;
var
  proto: PProto;
  sid: Integer;
  objectType: Integer;
  scriptType: Integer;
  script: PScript;
begin
  sidPtr^ := -1;

  if proto_ptr(obj^.Pid, @proto) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  objectType := PID_TYPE(obj^.Pid);
  if objectType < OBJ_TYPE_TILE then
    sid := proto^.Sid
  else if objectType = OBJ_TYPE_TILE then
    sid := proto^.Tile.Sid
  else if objectType = OBJ_TYPE_MISC then
    sid := -1
  else
    sid := -1; // unreachable

  if sid = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scriptType := SID_TYPE(sid);
  if scr_new(sidPtr, scriptType) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if scr_ptr(sidPtr^, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  script^.scr_script_idx := sid and $FFFFFF;

  if objectType = OBJ_TYPE_CRITTER then
    obj^.Field_80 := script^.scr_script_idx;

  if scriptType = SCRIPT_TYPE_SPATIAL then
  begin
    script^.u.sp.built_tile := BuiltTileCreate(obj^.Tile, obj^.Elevation);
    script^.u.sp.radius := 3;
  end;

  if obj^.Id = -1 then
    obj^.Id := new_obj_id();

  script^.scr_oid := obj^.Id;
  script^.owner := obj;

  scr_find_str_run_info(sid and $FFFFFF, @script^.run_info_flags, sidPtr^);

  Result := 0;
end;

// =======================================================================
// obj_new_sid_inst
// 0x48A080
// =======================================================================
function obj_new_sid_inst(obj: PObject; scriptType: Integer; a3: Integer): Integer;
var
  sid: Integer;
  script: PScript;
begin
  if a3 = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if scr_new(@sid, scriptType) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if scr_ptr(sid, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  script^.scr_script_idx := a3;
  if scriptType = SCRIPT_TYPE_SPATIAL then
  begin
    script^.u.sp.built_tile := BuiltTileCreate(obj^.Tile, obj^.Elevation);
    script^.u.sp.radius := 3;
  end;

  obj^.Sid := sid;

  obj^.Id := new_obj_id();
  script^.scr_oid := obj^.Id;

  script^.owner := obj;

  scr_find_str_run_info(a3 and $FFFFFF, @script^.run_info_flags, sid);

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
    obj^.Field_80 := script^.scr_script_idx;

  Result := 0;
end;

// =======================================================================
// obj_look_at
// 0x48A1FC
// =======================================================================
function obj_look_at(a1: PObject; a2: PObject): Integer;
begin
  Result := obj_look_at_func(a1, a2, @display_print);
end;

// =======================================================================
// obj_look_at_func
// 0x48A20C
// =======================================================================
function obj_look_at_func(a1: PObject; a2: PObject; a3: TDisplayPrintProc): Integer;
var
  sid: Integer;
  scriptOverrides: Boolean;
  proto: PProto;
  script: PScript;
  messageListItem: TMessageListItem;
  objectName: PAnsiChar;
  formattedText: array[0..259] of AnsiChar;
begin
  sid := -1;
  scriptOverrides := False;

  if critter_is_dead(a1) then
  begin
    Result := -1;
    Exit;
  end;

  if FID_TYPE(a2^.Fid) = OBJ_TYPE_TILE then
  begin
    Result := -1;
    Exit;
  end;

  if proto_ptr(a2^.Pid, @proto) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if obj_sid(a2, @sid) <> -1 then
  begin
    scr_set_objs(sid, a1, a2);
    exec_script_proc(sid, SCRIPT_PROC_LOOK_AT);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if not scriptOverrides then
  begin
    if (PID_TYPE(a2^.Pid) = OBJ_TYPE_CRITTER) and critter_is_dead(a2) then
      messageListItem.num := 491 + roll_random(0, 1)
    else
      messageListItem.num := 490;

    if message_search(@proto_main_msg_file, @messageListItem) then
    begin
      objectName := object_name(a2);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text, [objectName]);
      a3(formattedText);
    end;
  end;

  Result := -1;
end;

// =======================================================================
// obj_examine
// 0x48A338
// =======================================================================
function obj_examine(a1: PObject; a2: PObject): Integer;
begin
  Result := obj_examine_func(a1, a2, @display_print);
end;

// =======================================================================
// obj_examine_func
// 0x48A348
// =======================================================================
function obj_examine_func(critter: PObject; target: PObject; fn: TDisplayPrintProc): Integer;
var
  sid: Integer;
  scriptOverrides: Boolean;
  script: PScript;
  description: PAnsiChar;
  messageListItem: TMessageListItem;
  formattedText: array[0..259] of AnsiChar;
  objectType: Integer;
  item2: PObject;
  hpMessageListItem: TMessageListItem;
  weaponMessageListItem: TMessageListItem;
  endingMessageListItem: TMessageListItem;
  v66: TMessageListItem;
  v63: TMessageListItem;
  formatBuf: array[0..79] of AnsiChar;
  ammoTypePid: Integer;
  ammoName: PAnsiChar;
  ammoCapacity: Integer;
  ammoQuantity: Integer;
  weaponName: PAnsiChar;
  maximumHitPoints: Integer;
  currentHitPoints: Integer;
  v12: Integer;
  v16: Integer;
  itemType: Integer;
begin
  sid := -1;
  scriptOverrides := False;

  if critter_is_dead(critter) then
  begin
    Result := -1;
    Exit;
  end;

  if FID_TYPE(target^.Fid) = OBJ_TYPE_TILE then
  begin
    Result := -1;
    Exit;
  end;

  if obj_sid(target, @sid) <> -1 then
  begin
    scr_set_objs(sid, critter, target);
    exec_script_proc(sid, SCRIPT_PROC_DESCRIPTION);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if not scriptOverrides then
  begin
    description := object_description(target);
    if (description <> nil) and (StrComp(description, proto_none_str) = 0) then
      description := nil;

    if (description = nil) or (description^ = #0) then
    begin
      messageListItem.num := 493;
      if not message_search(@proto_main_msg_file, @messageListItem) then
        debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
      fn(messageListItem.text);
    end
    else
    begin
      if (PID_TYPE(target^.Pid) <> OBJ_TYPE_CRITTER) or (not critter_is_dead(target)) then
        fn(description);
    end;
  end;

  if (critter = nil) or (critter <> obj_dude) then
  begin
    Result := 0;
    Exit;
  end;

  objectType := PID_TYPE(target^.Pid);
  if objectType = OBJ_TYPE_CRITTER then
  begin
    if (target <> obj_dude) and (perk_level(PERK_AWARENESS) <> 0) and (not critter_is_dead(target)) then
    begin
      if critter_body_type(target) <> BODY_TYPE_BIPED then
        hpMessageListItem.num := 537
      else
        hpMessageListItem.num := 535 + stat_level(target, STAT_GENDER);

      item2 := inven_right_hand(target);
      if (item2 <> nil) and (item_get_type(item2) <> ITEM_TYPE_WEAPON) then
        item2 := nil;

      if not message_search(@proto_main_msg_file, @hpMessageListItem) then
      begin
        debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
        Halt(1);
      end;

      if item2 <> nil then
      begin
        if item_w_caliber(item2) <> 0 then
          weaponMessageListItem.num := 547
        else
          weaponMessageListItem.num := 546;

        if not message_search(@proto_main_msg_file, @weaponMessageListItem) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        StrLFmt(formatBuf, SizeOf(formatBuf) - 1, '%s%s', [hpMessageListItem.text, weaponMessageListItem.text]);

        if item_w_caliber(item2) <> 0 then
        begin
          ammoTypePid := item_w_ammo_pid(item2);
          ammoName := proto_name(ammoTypePid);
          ammoCapacity := item_w_max_ammo(item2);
          ammoQuantity := item_w_curr_ammo(item2);
          weaponName := object_name(item2);
          maximumHitPoints := stat_level(target, STAT_MAXIMUM_HIT_POINTS);
          currentHitPoints := stat_level(target, STAT_CURRENT_HIT_POINTS);
          StrLFmt(formattedText, SizeOf(formattedText) - 1, formatBuf,
            [currentHitPoints, maximumHitPoints, weaponName, ammoQuantity, ammoCapacity, ammoName]);
        end
        else
        begin
          weaponName := object_name(item2);
          maximumHitPoints := stat_level(target, STAT_MAXIMUM_HIT_POINTS);
          currentHitPoints := stat_level(target, STAT_CURRENT_HIT_POINTS);
          StrLFmt(formattedText, SizeOf(formattedText) - 1, formatBuf,
            [currentHitPoints, maximumHitPoints, weaponName]);
        end;
      end
      else
      begin
        if critter_is_crippled(target) then
          endingMessageListItem.num := 544
        else
          endingMessageListItem.num := 545;

        if not message_search(@proto_main_msg_file, @endingMessageListItem) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        maximumHitPoints := stat_level(target, STAT_MAXIMUM_HIT_POINTS);
        currentHitPoints := stat_level(target, STAT_CURRENT_HIT_POINTS);
        StrLFmt(formattedText, SizeOf(formattedText) - 1, hpMessageListItem.text,
          [currentHitPoints, maximumHitPoints]);
        StrCat(formattedText, endingMessageListItem.text);
      end;
    end
    else
    begin
      v12 := 0;
      if critter_is_crippled(target) then
        Dec(v12, 2);

      maximumHitPoints := stat_level(target, STAT_MAXIMUM_HIT_POINTS);
      currentHitPoints := stat_level(target, STAT_CURRENT_HIT_POINTS);
      if (currentHitPoints <= 0) or critter_is_dead(target) then
        v16 := 0
      else if currentHitPoints = maximumHitPoints then
        v16 := 4
      else
        v16 := (currentHitPoints * 3) div maximumHitPoints + 1;

      hpMessageListItem.num := 500 + v16;
      if not message_search(@proto_main_msg_file, @hpMessageListItem) then
      begin
        debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
        Halt(1);
      end;

      if v16 > 4 then
      begin
        hpMessageListItem.num := 550;
        if not message_search(@proto_main_msg_file, @hpMessageListItem) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        debug_printf(hpMessageListItem.text, []);
        Result := 0;
        Exit;
      end;

      if target = obj_dude then
      begin
        v66.num := 520 + v12;
        if not message_search(@proto_main_msg_file, @v66) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        StrLFmt(formattedText, SizeOf(formattedText) - 1, v66.text,
          [hpMessageListItem.text]);
      end
      else
      begin
        v66.num := 521 + v12;
        if not message_search(@proto_main_msg_file, @v66) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        v63.num := 522 + stat_level(target, STAT_GENDER);
        if not message_search(@proto_main_msg_file, @v63) then
        begin
          debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
          Halt(1);
        end;

        StrLFmt(formattedText, SizeOf(formattedText) - 1, v66.text,
          [v63.text, hpMessageListItem.text]);
      end;
    end;

    if critter_is_crippled(target) then
    begin
      maximumHitPoints := stat_level(target, STAT_MAXIMUM_HIT_POINTS);
      currentHitPoints := stat_level(target, STAT_CURRENT_HIT_POINTS);

      if maximumHitPoints >= currentHitPoints then
        v63.num := 531
      else
        v63.num := 530;

      if target = obj_dude then
        Inc(v63.num, 2);

      if not message_search(@proto_main_msg_file, @v63) then
      begin
        debug_printf(LineEnding + 'Error: Can''t find msg num!', []);
        Halt(1);
      end;

      StrCat(formattedText, v63.text);
    end;

    fn(formattedText);
  end
  else if objectType = OBJ_TYPE_ITEM then
  begin
    itemType := item_get_type(target);
    if itemType = ITEM_TYPE_WEAPON then
    begin
      if item_w_caliber(target) <> 0 then
      begin
        weaponMessageListItem.num := 526;

        if not message_search(@proto_main_msg_file, @weaponMessageListItem) then
          Halt(1);

        ammoTypePid := item_w_ammo_pid(target);
        ammoName := proto_name(ammoTypePid);
        ammoCapacity := item_w_max_ammo(target);
        ammoQuantity := item_w_curr_ammo(target);
        StrLFmt(formattedText, SizeOf(formattedText) - 1, weaponMessageListItem.text,
          [ammoQuantity, ammoCapacity, ammoName]);
        fn(formattedText);
      end;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// obj_pickup
// 0x48AA3C
// =======================================================================
function obj_pickup(critter: PObject; item: PObject): Integer;
var
  sid: Integer;
  overriden: Boolean;
  script: PScript;
  rc: Integer;
  amount: Integer;
  rect: TRect;
  messageListItem: TMessageListItem;
begin
  sid := -1;
  overriden := False;

  if obj_sid(item, @sid) <> -1 then
  begin
    scr_set_objs(sid, critter, item);
    exec_script_proc(sid, SCRIPT_PROC_PICKUP);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    overriden := script^.scriptOverrides <> 0;
  end;

  if not overriden then
  begin
    if item^.Pid = PROTO_ID_MONEY then
    begin
      amount := item_caps_get_amount(item);
      if amount <= 0 then
        amount := 1;

      rc := item_add_mult(critter, item, amount);
      if rc = 0 then
        item_caps_set_amount(item, 0);
    end
    else
      rc := item_add_mult(critter, item, 1);

    if rc = 0 then
    begin
      obj_disconnect(item, @rect);
      tile_refresh_rect(@rect, item^.Elevation);
    end
    else
    begin
      messageListItem.num := 905;
      if message_search(@proto_main_msg_file, @messageListItem) then
        display_print(messageListItem.text);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// obj_remove_from_inven
// 0x48AB24
// =======================================================================
function obj_remove_from_inven(critter: PObject; item: PObject): Integer;
var
  updatedRect: TRect;
  fid: Integer;
  v11: Integer;
  v5: Integer;
  proto: PProto;
  rc: Integer;
begin
  v11 := 0;
  fid := 0;
  if inven_right_hand(critter) = item then
  begin
    if (critter <> obj_dude) or (intface_is_item_right_hand() <> 0) then
    begin
      fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, FID_ANIM_TYPE(critter^.Fid), 0, critter^.Rotation);
      obj_change_fid(critter, fid, @updatedRect);
      v11 := 2;
    end
    else
      v11 := 1;
  end
  else if inven_left_hand(critter) = item then
  begin
    if (critter = obj_dude) and (intface_is_item_right_hand() = 0) then
    begin
      fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, FID_ANIM_TYPE(critter^.Fid), 0, critter^.Rotation);
      obj_change_fid(critter, fid, @updatedRect);
      v11 := 2;
    end
    else
      v11 := 1;
  end
  else if inven_worn(critter) = item then
  begin
    if critter = obj_dude then
    begin
      v5 := 1;

      if proto_ptr($1000000, @proto) <> -1 then
        v5 := proto^.Fid;

      fid := art_id(OBJ_TYPE_CRITTER, v5, FID_ANIM_TYPE(critter^.Fid), (critter^.Fid and $F000) shr 12, critter^.Rotation);
      obj_change_fid(critter, fid, @updatedRect);
      v11 := 3;
    end;
  end;

  rc := item_remove_mult(critter, item, 1);

  if v11 >= 2 then
    tile_refresh_rect(@updatedRect, critter^.Elevation);

  if (v11 <= 2) and (critter = obj_dude) then
    intface_update_items(False);

  Result := rc;
end;

// =======================================================================
// obj_drop
// 0x48AC94
// =======================================================================
function obj_drop(a1: PObject; a2: PObject): Integer;
var
  sid: Integer;
  scriptOverrides: Boolean;
  script: PScript;
  owner: PObject;
  updatedRect: TRect;
begin
  sid := -1;
  scriptOverrides := False;

  if a2 = nil then
  begin
    Result := -1;
    Exit;
  end;

  if obj_sid(a2, @sid) <> -1 then
  begin
    scr_set_objs(sid, a1, a2);
    exec_script_proc(sid, SCRIPT_PROC_DROP);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if scriptOverrides then
  begin
    Result := 0;
    Exit;
  end;

  if obj_remove_from_inven(a1, a2) = 0 then
  begin
    owner := obj_top_environment(a1);
    if owner = nil then
      owner := a1;

    obj_connect(a2, owner^.Tile, owner^.Elevation, @updatedRect);
    tile_refresh_rect(@updatedRect, owner^.Elevation);
  end;

  Result := 0;
end;

// =======================================================================
// obj_destroy
// 0x48AD38
// =======================================================================
function obj_destroy(obj: PObject): Integer;
var
  elev: Integer;
  owner: PObject;
  rect: TRect;
begin
  if obj = nil then
  begin
    Result := -1;
    Exit;
  end;

  elev := 0;
  owner := obj^.Owner;
  if owner <> nil then
    obj_remove_from_inven(owner, obj)
  else
    elev := obj^.Elevation;

  queue_remove(obj);

  obj_erase_object(obj, @rect);

  if owner = nil then
    tile_refresh_rect(@rect, elev);

  Result := 0;
end;

// =======================================================================
// obj_use_book (static)
// 0x48AD88
// =======================================================================
function obj_use_book(book: PObject): Integer;
var
  messageListItem: TMessageListItem;
  messageId: Integer;
  skill: Integer;
  increase: Integer;
  i: Integer;
  intelligence: Integer;
begin
  messageId := -1;
  skill := -1;

  case book^.Pid of
    PROTO_ID_BIG_BOOK_OF_SCIENCE:
    begin
      messageId := 802;
      skill := SKILL_SCIENCE;
    end;
    PROTO_ID_DEANS_ELECTRONICS:
    begin
      messageId := 803;
      skill := SKILL_REPAIR;
    end;
    PROTO_ID_FIRST_AID_BOOK:
    begin
      messageId := 804;
      skill := SKILL_FIRST_AID;
    end;
    PROTO_ID_SCOUT_HANDBOOK:
    begin
      messageId := 806;
      skill := SKILL_OUTDOORSMAN;
    end;
    PROTO_ID_GUNS_AND_BULLETS:
    begin
      messageId := 805;
      skill := SKILL_SMALL_GUNS;
    end;
  end;

  if messageId = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if isInCombat() then
  begin
    messageListItem.num := 902;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);

    Result := 0;
    Exit;
  end;

  increase := (100 - skill_level(obj_dude, skill)) div 10;
  if increase <= 0 then
    messageId := 801
  else
  begin
    for i := 0 to increase - 1 do
    begin
      if stat_pc_set(PC_STAT_UNSPENT_SKILL_POINTS, stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS) + 1) = 0 then
        skill_inc_point(obj_dude, skill);
    end;
  end;

  palette_fade_to(@black_palette[0]);

  intelligence := stat_level(obj_dude, STAT_INTELLIGENCE);
  inc_game_time_in_seconds(3600 * (11 - intelligence));

  scr_exec_map_update_scripts();

  palette_fade_to(@cmap[0]);

  messageListItem.num := 800;
  if message_search(@proto_main_msg_file, @messageListItem) then
    display_print(messageListItem.text);

  messageListItem.num := messageId;
  if message_search(@proto_main_msg_file, @messageListItem) then
    display_print(messageListItem.text);

  Result := 1;
end;

// =======================================================================
// obj_use_flare (static)
// 0x48AF24
// =======================================================================
function obj_use_flare(critter_obj: PObject; flare: PObject): Integer;
var
  messageListItem: TMessageListItem;
begin
  if flare^.Pid <> PROTO_ID_FLARE then
  begin
    Result := -1;
    Exit;
  end;

  if (flare^.Flags and OBJECT_USED) <> 0 then
  begin
    messageListItem.num := 588;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
  end
  else
  begin
    messageListItem.num := 587;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);

    flare^.Pid := PROTO_ID_LIT_FLARE;

    obj_set_light(flare, 8, $10000, nil);
    queue_add(72000, flare, nil, EVENT_TYPE_FLARE);
  end;

  Result := 0;
end;

// =======================================================================
// obj_use_radio
// 0x48AFC8
// =======================================================================
function obj_use_radio(item: PObject): Integer;
var
  script: PScript;
  sid: Integer;
begin
  if obj_sid(item, @sid) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  scr_set_objs(sid, obj_dude, item);
  exec_script_proc(sid, SCRIPT_PROC_USE);

  if scr_ptr(sid, @script) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// obj_use_explosive (static)
// 0x48B01C
// =======================================================================
function obj_use_explosive(explosive: PObject): Integer;
var
  messageListItem: TMessageListItem;
  pid: Integer;
  seconds: Integer;
  delay: Integer;
  rollResult: Integer;
  eventType: Integer;
begin
  pid := explosive^.Pid;
  if (pid <> PROTO_ID_DYNAMITE_I) and
     (pid <> PROTO_ID_PLASTIC_EXPLOSIVES_I) and
     (pid <> PROTO_ID_DYNAMITE_II) and
     (pid <> PROTO_ID_PLASTIC_EXPLOSIVES_II) then
  begin
    Result := -1;
    Exit;
  end;

  if (explosive^.Flags and OBJECT_USED) <> 0 then
  begin
    messageListItem.num := 590;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
  end
  else
  begin
    seconds := inven_set_timer(explosive);
    if seconds <> -1 then
    begin
      messageListItem.num := 589;
      if message_search(@proto_main_msg_file, @messageListItem) then
        display_print(messageListItem.text);

      if pid = PROTO_ID_DYNAMITE_I then
        explosive^.Pid := PROTO_ID_DYNAMITE_II
      else if pid = PROTO_ID_PLASTIC_EXPLOSIVES_I then
        explosive^.Pid := PROTO_ID_PLASTIC_EXPLOSIVES_II;

      delay := 10 * seconds;
      rollResult := skill_result(obj_dude, SKILL_TRAPS, 0, nil);

      case rollResult of
        ROLL_CRITICAL_FAILURE:
        begin
          delay := 0;
          eventType := EVENT_TYPE_EXPLOSION_FAILURE;
        end;
        ROLL_FAILURE:
        begin
          eventType := EVENT_TYPE_EXPLOSION_FAILURE;
          delay := delay div 2;
        end;
      else
        eventType := EVENT_TYPE_EXPLOSION;
      end;

      queue_add(delay, explosive, nil, eventType);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// protinst_use_item
// 0x49BF38
// =======================================================================
function protinst_use_item(critter: PObject; item: PObject): Integer;
var
  rc: Integer;
  messageListItem: TMessageListItem;
  doDefault: Boolean;
begin
  case item_get_type(item) of
    ITEM_TYPE_DRUG:
      rc := -1;
    ITEM_TYPE_WEAPON, ITEM_TYPE_MISC:
    begin
      doDefault := False;
      rc := obj_use_book(item);
      if rc <> -1 then
      begin
        Result := rc;
        Exit;
      end;

      rc := obj_use_flare(critter, item);
      if rc = 0 then
      begin
        Result := rc;
        Exit;
      end;

      rc := obj_use_radio(item);
      if rc = 0 then
      begin
        Result := rc;
        Exit;
      end;

      rc := obj_use_explosive(item);
      if rc = 0 then
      begin
        Result := rc;
        Exit;
      end;

      if item_m_uses_charges(item) then
      begin
        rc := item_m_use_charged_item(critter, item);
        if rc = 0 then
        begin
          Result := rc;
          Exit;
        end;
      end;

      // FALLTHROUGH to default
      doDefault := True;
    end;
  else
    doDefault := True;
  end;

  if doDefault then
  begin
    messageListItem.num := 582;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
    rc := -1;
  end;

  Result := rc;
end;

// =======================================================================
// obj_use_item
// 0x48B1DC
// =======================================================================
function obj_use_item(a1: PObject; a2: PObject): Integer;
var
  rc: Integer;
begin
  rc := protinst_use_item(a1, a2);
  if rc = 1 then
  begin
    obj_destroy(a2);
    rc := 0;
  end;

  scr_exec_map_update_scripts();

  Result := rc;
end;

// =======================================================================
// protinst_default_use_item (static)
// 0x48B21C
// =======================================================================
function protinst_default_use_item(a1: PObject; a2: PObject; item: PObject): Integer;
var
  formattedText: array[0..89] of AnsiChar;
  messageListItem: TMessageListItem;
  rc: Integer;
begin
  case item_get_type(item) of
    ITEM_TYPE_DRUG:
    begin
      if PID_TYPE(a2^.Pid) <> OBJ_TYPE_CRITTER then
      begin
        if a1 = obj_dude then
        begin
          messageListItem.num := 582;
          if message_search(@proto_main_msg_file, @messageListItem) then
            display_print(messageListItem.text);
        end;
        Result := -1;
        Exit;
      end;

      if critter_is_dead(a2) then
      begin
        messageListItem.num := 583 + roll_random(0, 3);
        if message_search(@proto_main_msg_file, @messageListItem) then
          display_print(messageListItem.text);
        Result := -1;
        Exit;
      end;

      rc := item_d_take_drug(a2, item);

      if (a1 = obj_dude) and (a2 <> obj_dude) then
      begin
        messageListItem.num := 580 + Ord(a2 <> obj_dude);
        if not message_search(@proto_main_msg_file, @messageListItem) then
        begin
          Result := -1;
          Exit;
        end;

        StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text,
          [object_name(item), object_name(a2)]);
        display_print(formattedText);
      end;

      if a2 = obj_dude then
        intface_update_hit_points(True);

      Result := rc;
      Exit;
    end;
    ITEM_TYPE_WEAPON, ITEM_TYPE_MISC:
    begin
      rc := obj_use_flare(a1, item);
      if rc = 0 then
      begin
        Result := 0;
        Exit;
      end;
    end;
  end;

  messageListItem.num := 582;
  if message_search(@proto_main_msg_file, @messageListItem) then
  begin
    StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s', [messageListItem.text]);
    display_print(formattedText);
  end;
  Result := -1;
end;

// =======================================================================
// protinst_use_item_on
// 0x48B394
// =======================================================================
function protinst_use_item_on(a1: PObject; a2: PObject; item: PObject): Integer;
var
  messageId: Integer;
  criticalChanceModifier: Integer;
  skill: Integer;
  script: PScript;
  sid: Integer;
  messageListItem: TMessageListItem;
  script2: PScript;
begin
  messageId := -1;
  criticalChanceModifier := 0;
  skill := -1;

  case item^.Pid of
    PROTO_ID_DOCTORS_BAG:
    begin
      messageId := 900;
      criticalChanceModifier := 20;
      skill := SKILL_DOCTOR;
    end;
    PROTO_ID_FIRST_AID_KIT:
    begin
      messageId := 901;
      criticalChanceModifier := 20;
      skill := SKILL_FIRST_AID;
    end;
  end;

  if skill = -1 then
  begin
    sid := -1;

    if obj_sid(item, @sid) = -1 then
    begin
      if obj_sid(a2, @sid) = -1 then
      begin
        Result := protinst_default_use_item(a1, a2, item);
        Exit;
      end;

      scr_set_objs(sid, a1, item);
      exec_script_proc(sid, SCRIPT_PROC_USE_OBJ_ON);

      if scr_ptr(sid, @script) = -1 then
      begin
        Result := -1;
        Exit;
      end;

      if script^.scriptOverrides = 0 then
      begin
        Result := protinst_default_use_item(a1, a2, item);
        Exit;
      end;
    end
    else
    begin
      scr_set_objs(sid, a1, a2);
      exec_script_proc(sid, SCRIPT_PROC_USE_OBJ_ON);

      if scr_ptr(sid, @script) = -1 then
      begin
        Result := -1;
        Exit;
      end;

      if script^.field_28 = 0 then
      begin
        if obj_sid(a2, @sid) = -1 then
        begin
          Result := protinst_default_use_item(a1, a2, item);
          Exit;
        end;

        scr_set_objs(sid, a1, item);
        exec_script_proc(sid, SCRIPT_PROC_USE_OBJ_ON);

        if scr_ptr(sid, @script2) = -1 then
        begin
          Result := -1;
          Exit;
        end;

        if script2^.scriptOverrides = 0 then
        begin
          Result := protinst_default_use_item(a1, a2, item);
          Exit;
        end;
      end;
    end;

    Result := script^.field_28;
    Exit;
  end;

  if isInCombat() then
  begin
    messageListItem.num := 902;
    if a1 = obj_dude then
    begin
      if message_search(@proto_main_msg_file, @messageListItem) then
        display_print(messageListItem.text);
    end;
    Result := -1;
    Exit;
  end;

  if skill_use(a1, a2, skill, criticalChanceModifier) <> 0 then
  begin
    Result := 0;
    Exit;
  end;

  if roll_random(1, 10) <> 1 then
  begin
    Result := 0;
    Exit;
  end;

  messageListItem.num := messageId;
  if a1 = obj_dude then
  begin
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
  end;

  Result := 1;
end;

// =======================================================================
// obj_use_item_on
// 0x48B618
// =======================================================================
function obj_use_item_on(a1: PObject; a2: PObject; a3: PObject): Integer;
var
  rc: Integer;
begin
  rc := protinst_use_item_on(a1, a2, a3);

  if rc = 1 then
  begin
    obj_destroy(a3);
    rc := 0;
  end;

  scr_exec_map_update_scripts();

  Result := rc;
end;

// =======================================================================
// rebuild_all_light (static)
// 0x48B63C
// =======================================================================
function rebuild_all_light: Integer;
begin
  obj_rebuild_all_light();
  tile_refresh_display();
  Result := 0;
end;

// =======================================================================
// check_scenery_ap_cost
// 0x48B64C
// =======================================================================
function check_scenery_ap_cost(obj: PObject; a2: PObject): Integer;
var
  actionPoints: Integer;
  messageListItem: TMessageListItem;
begin
  if not isInCombat() then
  begin
    Result := 0;
    Exit;
  end;

  actionPoints := obj^.Data.AsData.Critter.Combat.Ap;
  if actionPoints >= 3 then
  begin
    obj^.Data.AsData.Critter.Combat.Ap := actionPoints - 3;

    if obj = obj_dude then
      intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);

    Result := 0;
    Exit;
  end;

  messageListItem.num := 700;
  if obj = obj_dude then
  begin
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
  end;

  Result := -1;
end;

// =======================================================================
// obj_use
// 0x48B6C4
// =======================================================================
function obj_use(a1: PObject; a2: PObject): Integer;
var
  atype: Integer;
  sid: Integer;
  scriptOverrides: Boolean;
  sceneryProto: PProto;
  script: PScript;
  messageListItem: TMessageListItem;
  formattedText: array[0..259] of AnsiChar;
  name: PAnsiChar;
begin
  atype := FID_TYPE(a2^.Fid);
  sid := -1;
  scriptOverrides := False;

  if a1 = obj_dude then
  begin
    if atype <> OBJ_TYPE_SCENERY then
    begin
      Result := -1;
      Exit;
    end;
  end
  else
  begin
    if atype <> OBJ_TYPE_SCENERY then
    begin
      Result := 0;
      Exit;
    end;
  end;

  if proto_ptr(a2^.Pid, @sceneryProto) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if sceneryProto^.Scenery.SceneryType = SCENERY_TYPE_DOOR then
  begin
    Result := obj_use_door(a1, a2, 0);
    Exit;
  end;

  if obj_sid(a2, @sid) <> -1 then
  begin
    scr_set_objs(sid, a1, a2);
    exec_script_proc(sid, SCRIPT_PROC_USE);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if not scriptOverrides then
  begin
    if a1 = obj_dude then
    begin
      messageListItem.num := 480;
      if not message_search(@proto_main_msg_file, @messageListItem) then
      begin
        Result := -1;
        Exit;
      end;

      name := object_name(a2);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text, [name]);
      display_print(formattedText);
    end;
  end;

  scr_exec_map_update_scripts();

  Result := 0;
end;

// =======================================================================
// set_door_state_open (static, AnimationCallback)
// 0x48B7FC
// =======================================================================
function set_door_state_open(a1: PObject; a2: PObject): Integer; cdecl;
begin
  a1^.Data.AsData.Flags := a1^.Data.AsData.Flags;
  // Access the door openFlags through the overlay
  a1^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
    a1^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags or $01;
  Result := 0;
end;

// =======================================================================
// set_door_state_closed (static, AnimationCallback)
// 0x48B80C
// =======================================================================
function set_door_state_closed(a1: PObject; a2: PObject): Integer; cdecl;
begin
  a1^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
    a1^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and (not $01);
  Result := 0;
end;

// =======================================================================
// check_door_state (static, AnimationCallback)
// 0x48B81C
// =======================================================================
function check_door_state(a1: PObject; a2: PObject): Integer; cdecl;
var
  artHandle: PCacheEntry;
  anArt: PArt;
  dirty: TRect;
  temp: TRect;
  frameCount: Integer;
  frame: Integer;
  x, y: Integer;
begin
  if (a1^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and $01) = 0 then
  begin
    a1^.Flags := a1^.Flags and (not OBJECT_OPEN_DOOR);

    rebuild_all_light();

    if a1^.Frame = 0 then
    begin
      Result := 0;
      Exit;
    end;

    anArt := art_ptr_lock(a1^.Fid, @artHandle);
    if anArt = nil then
    begin
      Result := -1;
      Exit;
    end;

    obj_bound(a1, @dirty);

    for frame := a1^.Frame - 1 downto 0 do
    begin
      art_frame_hot(anArt, frame, a1^.Rotation, @x, @y);
      obj_offset(a1, -x, -y, @temp);
    end;

    obj_set_frame(a1, 0, @temp);
    rect_min_bound(@dirty, @temp, @dirty);

    tile_refresh_rect(@dirty, map_elevation);

    art_ptr_unlock(artHandle);
    Result := 0;
  end
  else
  begin
    a1^.Flags := a1^.Flags or OBJECT_OPEN_DOOR;

    rebuild_all_light();

    anArt := art_ptr_lock(a1^.Fid, @artHandle);
    if anArt = nil then
    begin
      Result := -1;
      Exit;
    end;

    frameCount := art_frame_max_frame(anArt);
    if a1^.Frame = frameCount - 1 then
    begin
      art_ptr_unlock(artHandle);
      Result := 0;
      Exit;
    end;

    obj_bound(a1, @dirty);

    for frame := a1^.Frame + 1 to frameCount - 1 do
    begin
      art_frame_hot(anArt, frame, a1^.Rotation, @x, @y);
      obj_offset(a1, x, y, @temp);
    end;

    obj_set_frame(a1, frameCount - 1, @temp);
    rect_min_bound(@dirty, @temp, @dirty);

    tile_refresh_rect(@dirty, map_elevation);

    art_ptr_unlock(artHandle);
    Result := 0;
  end;
end;

// =======================================================================
// obj_use_door
// 0x48B9C0
// =======================================================================
function obj_use_door(a1: PObject; a2: PObject; a3: Integer): Integer;
var
  sid: Integer;
  scriptOverrides: Boolean;
  sfx: PAnsiChar;
  script: PScript;
  startVal: Integer;
  endVal: Integer;
  step: Integer;
  i: Integer;
begin
  sid := -1;
  scriptOverrides := False;

  if obj_is_locked(a2) then
  begin
    sfx := gsnd_build_open_sfx_name(a2, SCENERY_SOUND_EFFECT_LOCKED);
    gsound_play_sfx_file(sfx);
  end;

  if obj_sid(a2, @sid) <> -1 then
  begin
    scr_set_objs(sid, a1, a2);
    exec_script_proc(sid, SCRIPT_PROC_USE);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if not scriptOverrides then
  begin
    if a2^.Frame <> 0 then
    begin
      startVal := 1;
      endVal := Ord(a3 = 0) - 1;
      step := -1;
    end
    else
    begin
      if (a2^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and $01) <> 0 then
      begin
        Result := -1;
        Exit;
      end;

      startVal := 0;
      endVal := Ord(a3 <> 0) + 1;
      step := 1;
    end;

    register_begin(ANIMATION_REQUEST_RESERVED);

    i := startVal;
    while i <> endVal do
    begin
      if i <> 0 then
      begin
        if a3 = 0 then
          register_object_call(a2, a2, TAnimationCallback(@set_door_state_closed), -1);

        sfx := gsnd_build_open_sfx_name(a2, SCENERY_SOUND_EFFECT_CLOSED);
        register_object_play_sfx(a2, sfx, -1);

        register_object_animate_reverse(a2, ANIM_STAND, 0);
      end
      else
      begin
        if a3 = 0 then
          register_object_call(a2, a2, TAnimationCallback(@set_door_state_open), -1);

        sfx := gsnd_build_open_sfx_name(a2, SCENERY_SOUND_EFFECT_OPEN);
        register_object_play_sfx(a2, sfx, -1);

        register_object_animate(a2, ANIM_STAND, 0);
      end;

      Inc(i, step);
    end;

    register_object_must_call(a2, a2, TAnimationCallback(@check_door_state), -1);

    register_end();
  end;

  Result := 0;
end;

// =======================================================================
// obj_use_container
// 0x48BB50
// =======================================================================
function obj_use_container(critter: PObject; item: PObject): Integer;
var
  sid: Integer;
  overriden: Boolean;
  itemProto: PProto;
  sfx: PAnsiChar;
  script: PScript;
  messageListItem: TMessageListItem;
  formattedText: array[0..259] of AnsiChar;
  objectName: PAnsiChar;
begin
  sid := -1;
  overriden := False;

  if FID_TYPE(item^.Fid) <> OBJ_TYPE_ITEM then
  begin
    Result := -1;
    Exit;
  end;

  if proto_ptr(item^.Pid, @itemProto) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if itemProto^.Item.ItemType <> ITEM_TYPE_CONTAINER then
  begin
    Result := -1;
    Exit;
  end;

  if obj_is_locked(item) then
  begin
    sfx := gsnd_build_open_sfx_name(item, SCENERY_SOUND_EFFECT_LOCKED);
    gsound_play_sfx_file(sfx);

    if critter = obj_dude then
    begin
      messageListItem.num := 487;
      if not message_search(@proto_main_msg_file, @messageListItem) then
      begin
        Result := -1;
        Exit;
      end;

      display_print(messageListItem.text);
    end;

    Result := -1;
    Exit;
  end;

  if obj_sid(item, @sid) <> -1 then
  begin
    scr_set_objs(sid, critter, item);
    exec_script_proc(sid, SCRIPT_PROC_USE);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    overriden := script^.scriptOverrides <> 0;
  end;

  if overriden then
  begin
    Result := 0;
    Exit;
  end;

  register_begin(ANIMATION_REQUEST_RESERVED);

  if item^.Frame = 0 then
  begin
    sfx := gsnd_build_open_sfx_name(item, SCENERY_SOUND_EFFECT_OPEN);
    register_object_play_sfx(item, sfx, 0);
    register_object_animate(item, ANIM_STAND, 0);
  end
  else
  begin
    sfx := gsnd_build_open_sfx_name(item, SCENERY_SOUND_EFFECT_CLOSED);
    register_object_play_sfx(item, sfx, 0);
    register_object_animate_reverse(item, ANIM_STAND, 0);
  end;

  register_end();

  if critter = obj_dude then
  begin
    if item^.Frame <> 0 then
      messageListItem.num := 486
    else
      messageListItem.num := 485;

    if not message_search(@proto_main_msg_file, @messageListItem) then
    begin
      Result := -1;
      Exit;
    end;

    objectName := object_name(item);
    StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text, [objectName]);
    display_print(formattedText);
  end;

  Result := 0;
end;

// =======================================================================
// obj_use_skill_on
// 0x48BD4C
// =======================================================================
function obj_use_skill_on(source: PObject; target: PObject; skill: Integer): Integer;
var
  sid: Integer;
  scriptOverrides: Boolean;
  messageListItem: TMessageListItem;
  proto: PProto;
  script: PScript;
begin
  sid := -1;
  scriptOverrides := False;

  if obj_lock_is_jammed(target) then
  begin
    if source = obj_dude then
    begin
      messageListItem.num := 2001;
      if message_search(@misc_message_file, @messageListItem) then
        display_print(messageListItem.text);
    end;
    Result := -1;
    Exit;
  end;

  if proto_ptr(target^.Pid, @proto) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if obj_sid(target, @sid) <> -1 then
  begin
    scr_set_objs(sid, source, target);
    scr_set_action_num(sid, skill);
    exec_script_proc(sid, SCRIPT_PROC_USE_SKILL_ON);

    if scr_ptr(sid, @script) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scriptOverrides := script^.scriptOverrides <> 0;
  end;

  if not scriptOverrides then
    skill_use(source, target, skill, 0);

  Result := 0;
end;

// =======================================================================
// obj_is_a_portal
// 0x48BE14
// =======================================================================
function obj_is_a_portal(obj: PObject): Boolean;
var
  proto: PProto;
begin
  if obj = nil then
  begin
    Result := False;
    Exit;
  end;

  if proto_ptr(obj^.Pid, @proto) = -1 then
  begin
    Result := False;
    Exit;
  end;

  Result := proto^.Scenery.SceneryType = SCENERY_TYPE_DOOR;
end;

// =======================================================================
// obj_is_lockable
// 0x48BE4C
// =======================================================================
function obj_is_lockable(obj: PObject): Boolean;
var
  proto: PProto;
begin
  if obj = nil then
  begin
    Result := False;
    Exit;
  end;

  if proto_ptr(obj^.Pid, @proto) = -1 then
  begin
    Result := False;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
      if proto^.Item.ItemType = ITEM_TYPE_CONTAINER then
      begin
        Result := True;
        Exit;
      end;
    OBJ_TYPE_SCENERY:
      if proto^.Scenery.SceneryType = SCENERY_TYPE_DOOR then
      begin
        Result := True;
        Exit;
      end;
  end;

  Result := False;
end;

// =======================================================================
// obj_is_locked
// 0x48BE9C
// =======================================================================
function obj_is_locked(obj: PObject): Boolean;
begin
  if obj = nil then
  begin
    Result := False;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
    begin
      Result := (obj^.Data.AsData.Flags and CONTAINER_FLAG_LOCKED) <> 0;
      Exit;
    end;
    OBJ_TYPE_SCENERY:
    begin
      Result := (obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and DOOR_FLAG_LOCKED) <> 0;
      Exit;
    end;
  end;

  Result := False;
end;

// =======================================================================
// obj_lock
// 0x48BEE0
// =======================================================================
function obj_lock(obj: PObject): Integer;
begin
  if obj = nil then
  begin
    Result := -1;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
      obj^.Data.AsData.Flags := obj^.Data.AsData.Flags or OBJ_LOCKED;
    OBJ_TYPE_SCENERY:
      obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
        obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags or OBJ_LOCKED;
  else
    begin
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// obj_unlock
// 0x48BF24
// =======================================================================
function obj_unlock(obj: PObject): Integer;
begin
  if obj = nil then
  begin
    Result := -1;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
    begin
      obj^.Data.AsData.Flags := obj^.Data.AsData.Flags and (not OBJ_LOCKED);
      Result := 0;
      Exit;
    end;
    OBJ_TYPE_SCENERY:
    begin
      obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
        obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and (not OBJ_LOCKED);
      Result := 0;
      Exit;
    end;
  end;

  Result := -1;
end;

// =======================================================================
// obj_is_openable
// 0x48BF68
// =======================================================================
function obj_is_openable(obj: PObject): Boolean;
var
  proto: PProto;
begin
  if obj = nil then
  begin
    Result := False;
    Exit;
  end;

  if proto_ptr(obj^.Pid, @proto) = -1 then
  begin
    Result := False;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
      if proto^.Item.ItemType = ITEM_TYPE_CONTAINER then
      begin
        Result := True;
        Exit;
      end;
    OBJ_TYPE_SCENERY:
      if proto^.Scenery.SceneryType = SCENERY_TYPE_DOOR then
      begin
        Result := True;
        Exit;
      end;
  end;

  Result := False;
end;

// =======================================================================
// obj_is_open
// 0x48BFB8
// =======================================================================
function obj_is_open(obj: PObject): Integer;
begin
  Result := Ord(obj^.Frame <> 0);
end;

// =======================================================================
// obj_toggle_open
// 0x48BFC8
// =======================================================================
function obj_toggle_open(obj: PObject): Integer;
var
  sfx: PAnsiChar;
begin
  if obj = nil then
  begin
    Result := -1;
    Exit;
  end;

  if not obj_is_openable(obj) then
  begin
    Result := -1;
    Exit;
  end;

  if obj_is_locked(obj) then
  begin
    Result := -1;
    Exit;
  end;

  obj_unjam_lock(obj);

  register_begin(ANIMATION_REQUEST_RESERVED);

  if obj^.Frame <> 0 then
  begin
    register_object_must_call(obj, obj, TAnimationCallback(@set_door_state_closed), -1);

    sfx := gsnd_build_open_sfx_name(obj, SCENERY_SOUND_EFFECT_CLOSED);
    register_object_play_sfx(obj, sfx, -1);

    register_object_animate_reverse(obj, ANIM_STAND, 0);
  end
  else
  begin
    register_object_must_call(obj, obj, TAnimationCallback(@set_door_state_open), -1);

    sfx := gsnd_build_open_sfx_name(obj, SCENERY_SOUND_EFFECT_OPEN);
    register_object_play_sfx(obj, sfx, -1);
    register_object_animate(obj, ANIM_STAND, 0);
  end;

  register_object_must_call(obj, obj, TAnimationCallback(@check_door_state), -1);

  register_end();

  Result := 0;
end;

// =======================================================================
// obj_open
// 0x48C0AC
// =======================================================================
function obj_open(obj: PObject): Integer;
begin
  if obj^.Frame = 0 then
    obj_toggle_open(obj);

  Result := 0;
end;

// =======================================================================
// obj_close
// 0x48C0C8
// =======================================================================
function obj_close(obj: PObject): Integer;
begin
  if obj^.Frame <> 0 then
    obj_toggle_open(obj);

  Result := 0;
end;

// =======================================================================
// obj_lock_is_jammed
// 0x48C0E4
// =======================================================================
function obj_lock_is_jammed(obj: PObject): Boolean;
begin
  if not obj_is_lockable(obj) then
  begin
    Result := False;
    Exit;
  end;

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_SCENERY then
  begin
    if (obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and OBJ_JAMMED) <> 0 then
    begin
      Result := True;
      Exit;
    end;
  end
  else
  begin
    if (obj^.Data.AsData.Flags and OBJ_JAMMED) <> 0 then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

// =======================================================================
// obj_jam_lock
// 0x48C11C
// =======================================================================
function obj_jam_lock(obj: PObject): Integer;
begin
  if not obj_is_lockable(obj) then
  begin
    Result := -1;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
      obj^.Data.AsData.Flags := obj^.Data.AsData.Flags or CONTAINER_FLAG_JAMMED;
    OBJ_TYPE_SCENERY:
      obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
        obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags or DOOR_FLAG_JAMMGED;
  end;

  Result := 0;
end;

// =======================================================================
// obj_unjam_lock
// 0x48C154
// =======================================================================
function obj_unjam_lock(obj: PObject): Integer;
begin
  if not obj_is_lockable(obj) then
  begin
    Result := -1;
    Exit;
  end;

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
      obj^.Data.AsData.Flags := obj^.Data.AsData.Flags and (not CONTAINER_FLAG_JAMMED);
    OBJ_TYPE_SCENERY:
      obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags :=
        obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags and (not DOOR_FLAG_JAMMGED);
  end;

  Result := 0;
end;

// =======================================================================
// obj_unjam_all_locks
// 0x48C18C
// =======================================================================
function obj_unjam_all_locks: Integer;
var
  obj: PObject;
begin
  obj := obj_find_first();
  while obj <> nil do
  begin
    obj_unjam_lock(obj);
    obj := obj_find_next();
  end;

  Result := 0;
end;

// =======================================================================
// obj_attempt_placement
// 0x48C1A8
// =======================================================================
function obj_attempt_placement(obj: PObject; tile: Integer; elevation: Integer; a4: Integer): Integer;
var
  newTile: Integer;
  v6: Integer;
  rotation: Integer;
  candidate: Integer;
  temp: TRect;
begin
  if tile = -1 then
  begin
    Result := -1;
    Exit;
  end;

  newTile := tile;
  if obj_blocking_at(nil, tile, elevation) <> nil then
  begin
    v6 := a4;
    if v6 < 1 then
      v6 := 1;

    while v6 < 7 do
    begin
      for rotation := 0 to Integer(ROTATION_COUNT) - 1 do
      begin
        newTile := tile_num_in_direction(tile, rotation, v6);
        if (obj_blocking_at(nil, newTile, elevation) = nil) and (v6 > 1) and
           (make_path(obj_dude, obj_dude^.Tile, newTile, nil, 0) <> 0) then
          Break;
      end;

      Inc(v6);
    end;

    if (a4 <> 1) and (v6 > a4 + 2) then
    begin
      for rotation := 0 to Integer(ROTATION_COUNT) - 1 do
      begin
        candidate := tile_num_in_direction(tile, rotation, 1);
        if obj_blocking_at(nil, candidate, elevation) = nil then
        begin
          newTile := candidate;
          Break;
        end;
      end;
    end;
  end;

  obj^.Flags := obj^.Flags and (not OBJECT_HIDDEN);

  if obj_move_to_tile(obj, newTile, elevation, @temp) <> -1 then
  begin
    if elevation = map_elevation then
      tile_refresh_rect(@temp, elevation);
  end;

  Result := 0;
end;

end.
