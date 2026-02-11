unit u_combatai;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/combatai.h + combatai.cc
// Combat AI: AI packet loading, danger source detection, combat decisions, messages.

interface

uses
  u_object_types,
  u_object,
  u_combat_defs,
  u_db,
  u_anim;

const
  AI_MESSAGE_TYPE_RUN    = 0;
  AI_MESSAGE_TYPE_MOVE   = 1;
  AI_MESSAGE_TYPE_ATTACK = 2;
  AI_MESSAGE_TYPE_MISS   = 3;
  AI_MESSAGE_TYPE_HIT    = 4;

type
  PAiPacket = ^TAiPacket;
  TAiPacket = record
    name: PAnsiChar;
    packet_num: Integer;
    max_dist: Integer;
    min_to_hit: Integer;
    min_hp: Integer;
    aggression: Integer;
    hurt_too_much: Integer;
    secondary_freq: Integer;
    called_freq: Integer;
    font: Integer;
    color: Integer;
    outline_color: Integer;
    chance: Integer;
    run_start: Integer;
    move_start: Integer;
    attack_start: Integer;
    miss_start: Integer;
    hit_start: array[0..HIT_LOCATION_SPECIFIC_COUNT - 1] of Integer;
    last_msg: Integer;
  end;

function combat_ai_init: Integer;
procedure combat_ai_reset;
function combat_ai_exit: Integer;
function combat_ai_load(stream: PDB_FILE): Integer;
function combat_ai_save(stream: PDB_FILE): Integer;
function combat_ai_num: Integer;
function combat_ai_name(packet_num: Integer): PAnsiChar;
function ai_danger_source(critter: PObject): PObject;
function ai_search_inven(critter: PObject; check_action_points: Integer): PObject;
procedure combat_ai_begin(critters_count: Integer; critters: PPObject);
procedure combat_ai_over;
function combat_ai(critter: PObject; target: PObject): PObject;
function combatai_want_to_join(a1: PObject): Boolean;
function combatai_want_to_stop(a1: PObject): Boolean;
function combatai_switch_team(critter: PObject; team: Integer): Integer;
function combatai_msg(critter: PObject; attack: PAttack; type_: Integer; delay: Integer): Integer;
function combat_ai_random_target(attack: PAttack): PObject;
procedure combatai_check_retaliation(critter: PObject; candidate: PObject);
function is_within_perception(critter1: PObject; critter2: PObject): Boolean;
procedure combatai_refresh_messages;
procedure combatai_notify_onlookers(critter: PObject);
procedure combatai_delete_critter(critter: PObject);

implementation

uses
  SysUtils,
  u_config,
  u_assoc,
  u_memory,
  u_platform_compat,
  u_rect,
  u_proto_types,
  u_stat_defs,
  u_gconfig,
  u_roll,
  u_item,
  u_stat,
  u_critter,
  u_skill,
  u_perk,
  u_art,
  u_party,
  u_message,
  u_combat,
  u_actions,
  u_intface,
  u_scripts,
  u_gsound,
  u_game,
  u_map,
  u_tile,
  u_textobj,
  u_display,
  u_protinst,
  u_inventry,
  u_input;

const
  COMPAT_MAX_PATH = 260;

  // HurtTooMuch enum
  HURT_BLIND         = 0;
  HURT_CRIPPLED      = 1;
  HURT_CRIPPLED_LEGS = 2;
  HURT_CRIPPLED_ARMS = 3;
  HURT_COUNT         = 4;

  // Animation constants
  ANIM_MAGIC_HANDS_MIDDLE = 11;
  ANIM_THROW_PUNCH        = 16;
  ANIMATION_REQUEST_RESERVED = $02;

  // Script proc
  SCRIPT_PROC_COMBAT = 13;

const
  WEAPON_SOUND_EFFECT_READY       = 0;
  WEAPON_SOUND_EFFECT_OUT_OF_AMMO = 2;

// External declarations
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// C qsort
type
  TQSortCompareFunc = function(a, b: Pointer): Integer; cdecl;

procedure qsort(base: Pointer; nmemb: SizeUInt; size: SizeUInt; compar: TQSortCompareFunc); cdecl; external 'c' name 'qsort';

// C string functions used in parse_hurt_str
function strspn(s, accept: PAnsiChar): SizeUInt; cdecl; external 'c' name 'strspn';
function strcspn(s, reject: PAnsiChar): SizeUInt; cdecl; external 'c' name 'strcspn';

// Module-level variables (C++ static)
var
  combat_obj: PObject = nil;
  num_caps: Integer = 0;
  combatai_is_initialized: Boolean = False;

const
  matchHurtStrs: array[0..HURT_COUNT - 1] of PAnsiChar = (
    'blind',
    'crippled',
    'crippled_legs',
    'crippled_arms'
  );

var
  rmatchHurtVals: array[0..HURT_COUNT - 1] of Integer;
  ai_message_file: TMessageList;
  cap: PAiPacket;
  target_str: array[0..79] of AnsiChar;
  curr_crit_num: Integer;
  curr_crit_list: PPObject;
  attack_str: array[0..79] of AnsiChar;

  // static local in combatai_refresh_messages
  old_state: Integer = -1;

// Forward declarations
procedure parse_hurt_str(str: PAnsiChar; value: PInteger); forward;
function ai_cap(obj: PObject): PAiPacket; forward;
function ai_magic_hands(critter: PObject; item: PObject; num: Integer): Integer; forward;
function ai_check_drugs(critter: PObject): Integer; forward;
procedure ai_run_away(critter: PObject); forward;
function compare_nearer(critter_ptr1: Pointer; critter_ptr2: Pointer): Integer; cdecl; forward;
procedure ai_sort_list(critterList: PPObject; length_: Integer; origin: PObject); forward;
function ai_find_nearest_team(critter: PObject; other: PObject; flags: Integer): PObject; forward;
function ai_find_attackers(critter: PObject; a2: PPObject; a3: PPObject; a4: PPObject): Integer; forward;
function ai_have_ammo(critter: PObject; weapon: PObject): PObject; forward;
function ai_best_weapon(weapon1: PObject; weapon2: PObject): PObject; forward;
function ai_can_use_weapon(critter: PObject; weapon: PObject; hitMode: Integer): Boolean; forward;
function ai_search_environ(critter: PObject; itemType: Integer): PObject; forward;
function ai_retrieve_object(critter: PObject; item: PObject): PObject; forward;
function ai_pick_hit_mode(critter: PObject; weapon: PObject): Integer; forward;
function ai_move_closer(critter: PObject; target: PObject; a3: Integer): Integer; forward;
function ai_switch_weapons(critter: PObject; hit_mode: PInteger; weapon: PPObject): Integer; forward;
function ai_called_shot(critter: PObject; target: PObject; hit_mode: Integer): Integer; forward;
function ai_attack(critter: PObject; target: PObject; hit_mode: Integer): Integer; forward;
function ai_try_attack(critter: PObject; target: PObject): Integer; forward;
function ai_print_msg(critter: PObject; type_: Integer): Integer; cdecl; forward;
function combatai_rating(obj: PObject): Integer; forward;
function combatai_load_messages: Integer; forward;
function combatai_unload_messages: Integer; forward;

// ---------------------------------------------------------------------------
// parse_hurt_str
// ---------------------------------------------------------------------------
procedure parse_hurt_str(str: PAnsiChar; value: PInteger);
var
  comma_pos: SizeUInt;
  comma: AnsiChar;
  index: Integer;
begin
  value^ := 0;

  compat_strlwr(str);

  while str^ <> #0 do
  begin
    str := str + strspn(str, ' ');

    comma_pos := strcspn(str, ',');
    comma := (str + comma_pos)^;
    (str + comma_pos)^ := #0;

    index := 0;
    while index < HURT_COUNT do
    begin
      if StrComp(str, matchHurtStrs[index]) = 0 then
      begin
        value^ := value^ or rmatchHurtVals[index];
        Break;
      end;
      Inc(index);
    end;

    if index = HURT_COUNT then
      debug_printf('Unrecognized flag: %s'#10, str);

    (str + comma_pos)^ := comma;

    if comma = #0 then
      Break;

    str := str + comma_pos + 1;
  end;
end;

// ---------------------------------------------------------------------------
// combat_ai_init
// ---------------------------------------------------------------------------
function combat_ai_init: Integer;
var
  index: Integer;
  aconfig: TConfig;
  rc: Integer;
  sectionEntry: PAssocPair;
  ai: PAiPacket;
  stringValue: PAnsiChar;
begin
  rc := 0;

  if combatai_load_messages() = -1 then
    Exit(-1);

  num_caps := 0;

  if not config_init(@aconfig) then
    Exit(-1);

  if config_load(@aconfig, 'data\ai.txt', True) then
  begin
    cap := PAiPacket(mem_malloc(SizeOf(TAiPacket) * SizeUInt(aconfig.Size)));
    if cap <> nil then
    begin
      index := 0;
      while index < aconfig.Size do
      begin
        (cap + index)^.name := nil;
        Inc(index);
      end;

      index := 0;
      while index < aconfig.Size do
      begin
        sectionEntry := PAssocPair(PByte(aconfig.List) + SizeUInt(index) * SizeOf(TAssocPair));
        ai := cap + index;

        ai^.name := mem_strdup(sectionEntry^.Name);
        if ai^.name = nil then Break;

        if not config_get_value(@aconfig, sectionEntry^.Name, 'packet_num', @ai^.packet_num) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'max_dist', @ai^.max_dist) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'min_to_hit', @ai^.min_to_hit) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'min_hp', @ai^.min_hp) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'aggression', @ai^.aggression) then Break;
        if not config_get_string(@aconfig, sectionEntry^.Name, 'hurt_too_much', @stringValue) then Break;
        parse_hurt_str(stringValue, @ai^.hurt_too_much);
        if not config_get_value(@aconfig, sectionEntry^.Name, 'secondary_freq', @ai^.secondary_freq) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'called_freq', @ai^.called_freq) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'font', @ai^.font) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'color', @ai^.color) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'outline_color', @ai^.outline_color) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'chance', @ai^.chance) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'run_start', @ai^.run_start) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'move_start', @ai^.move_start) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'attack_start', @ai^.attack_start) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'miss_start', @ai^.miss_start) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_head_start', @ai^.hit_start[HIT_LOCATION_HEAD]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_left_arm_start', @ai^.hit_start[HIT_LOCATION_LEFT_ARM]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_right_arm_start', @ai^.hit_start[HIT_LOCATION_RIGHT_ARM]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_torso_start', @ai^.hit_start[HIT_LOCATION_TORSO]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_right_leg_start', @ai^.hit_start[HIT_LOCATION_RIGHT_LEG]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_left_leg_start', @ai^.hit_start[HIT_LOCATION_LEFT_LEG]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_eyes_start', @ai^.hit_start[HIT_LOCATION_EYES]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'hit_groin_start', @ai^.hit_start[HIT_LOCATION_GROIN]) then Break;
        if not config_get_value(@aconfig, sectionEntry^.Name, 'last_msg', @ai^.last_msg) then Break;

        Inc(index);
      end;

      if index < aconfig.Size then
      begin
        index := 0;
        while index < aconfig.Size do
        begin
          if (cap + index)^.name <> nil then
            mem_free((cap + index)^.name);
          Inc(index);
        end;
        mem_free(cap);
        debug_printf('Error processing ai.txt');
        rc := -1;
      end
      else
      begin
        num_caps := aconfig.Size;
      end;
    end
    else
    begin
      rc := -1;
    end;
  end
  else
  begin
    rc := -1;
  end;

  config_exit(@aconfig);

  if rc = 0 then
    combatai_is_initialized := True;

  Result := rc;
end;

// ---------------------------------------------------------------------------
// combat_ai_reset
// ---------------------------------------------------------------------------
procedure combat_ai_reset;
begin
  // empty
end;

// ---------------------------------------------------------------------------
// combat_ai_exit
// ---------------------------------------------------------------------------
function combat_ai_exit: Integer;
var
  index: Integer;
  ai: PAiPacket;
begin
  index := 0;
  while index < num_caps do
  begin
    ai := cap + index;
    if ai^.name <> nil then
    begin
      mem_free(ai^.name);
      ai^.name := nil;
    end;
    Inc(index);
  end;

  mem_free(cap);
  num_caps := 0;

  combatai_is_initialized := False;

  if combatai_unload_messages() <> 0 then
    Exit(-1);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// combat_ai_load
// ---------------------------------------------------------------------------
function combat_ai_load(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// ---------------------------------------------------------------------------
// combat_ai_save
// ---------------------------------------------------------------------------
function combat_ai_save(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// ---------------------------------------------------------------------------
// combat_ai_num
// ---------------------------------------------------------------------------
function combat_ai_num: Integer;
begin
  Result := num_caps;
end;

// ---------------------------------------------------------------------------
// combat_ai_name
// ---------------------------------------------------------------------------
function combat_ai_name(packet_num: Integer): PAnsiChar;
var
  index: Integer;
begin
  if (packet_num < 0) or (packet_num >= num_caps) then
    Exit(nil);

  index := 0;
  while index < num_caps do
  begin
    if (cap + index)^.packet_num = packet_num then
      Exit((cap + index)^.name);
    Inc(index);
  end;

  Result := nil;
end;

// ---------------------------------------------------------------------------
// ai_cap
// ---------------------------------------------------------------------------
function ai_cap(obj: PObject): PAiPacket;
var
  index: Integer;
  pkt_num: Integer;
begin
  pkt_num := obj^.Data.AsData.Critter.Combat.AiPacket;
  index := 0;
  while index < num_caps do
  begin
    if pkt_num = (cap + index)^.packet_num then
      Exit(cap + index);
    Inc(index);
  end;

  debug_printf('Missing AI Packet'#10);

  Result := cap;
end;

// ---------------------------------------------------------------------------
// ai_magic_hands
// ---------------------------------------------------------------------------
function ai_magic_hands(critter: PObject; item: PObject; num: Integer): Integer;
var
  messageListItem: TMessageListItem;
  text: array[0..199] of AnsiChar;
begin
  register_begin(ANIMATION_REQUEST_RESERVED);
  register_object_animate(critter, ANIM_MAGIC_HANDS_MIDDLE, 0);
  if register_end() = 0 then
    combat_turn_run();

  if num <> -1 then
  begin
    messageListItem.num := num;
    if message_search(@misc_message_file, @messageListItem) then
    begin
      if item <> nil then
        StrLFmt(@text[0], SizeOf(text) - 1, '%s %s %s.', [object_name(critter), messageListItem.text, object_name(item)])
      else
        StrLFmt(@text[0], SizeOf(text) - 1, '%s %s.', [object_name(critter), messageListItem.text]);

      display_print(@text[0]);
    end;
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_check_drugs
// ---------------------------------------------------------------------------
function ai_check_drugs(critter: PObject): Integer;
var
  bloodied: Integer;
  index: Integer;
  drug: PObject;
begin
  if critter_body_type(critter) <> BODY_TYPE_BIPED then
    Exit(0);

  bloodied := stat_level(critter, Integer(STAT_MAXIMUM_HIT_POINTS)) div 2;
  index := -1;

  while stat_level(critter, Integer(STAT_CURRENT_HIT_POINTS)) < bloodied do
  begin
    if critter^.Data.AsData.Critter.Combat.Ap < 2 then
      Break;

    drug := inven_find_type(critter, ITEM_TYPE_DRUG, @index);
    if drug = nil then
      Break;

    if (drug^.Pid = PROTO_ID_STIMPACK) or (drug^.Pid = PROTO_ID_SUPER_STIMPACK) then
    begin
      if item_remove_mult(critter, drug, 1) = 0 then
      begin
        if item_d_take_drug(critter, drug) = -1 then
          item_add_force(critter, drug, 1)
        else
        begin
          ai_magic_hands(critter, drug, 5000);
          obj_connect(drug, critter^.Tile, critter^.Elevation, nil);
          obj_destroy(drug);
        end;

        if critter^.Data.AsData.Critter.Combat.Ap < 2 then
          critter^.Data.AsData.Critter.Combat.Ap := 0
        else
          critter^.Data.AsData.Critter.Combat.Ap := critter^.Data.AsData.Critter.Combat.Ap - 2;

        index := -1;
      end;
    end;
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_run_away
// ---------------------------------------------------------------------------
procedure ai_run_away(critter: PObject);
var
  combatData: PCritterCombatData;
  ai: PAiPacket;
  distance: Integer;
  rotation: Integer;
  destination: Integer;
  action_points: Integer;
begin
  combatData := @critter^.Data.AsData.Critter.Combat;
  ai := ai_cap(critter);
  distance := obj_dist(critter, obj_dude);

  if distance < ai^.max_dist then
  begin
    combatData^.Maneuver := combatData^.Maneuver or CRITTER_MANUEVER_FLEEING;

    rotation := tile_dir(obj_dude^.Tile, critter^.Tile);
    action_points := combatData^.Ap;
    destination := 0;

    while action_points > 0 do
    begin
      destination := tile_num_in_direction(critter^.Tile, rotation, action_points);
      if make_path(critter, critter^.Tile, destination, nil, 1) > 0 then
        Break;

      destination := tile_num_in_direction(critter^.Tile, (rotation + 1) mod Integer(ROTATION_COUNT), action_points);
      if make_path(critter, critter^.Tile, destination, nil, 1) > 0 then
        Break;

      destination := tile_num_in_direction(critter^.Tile, (rotation + 5) mod Integer(ROTATION_COUNT), action_points);
      if make_path(critter, critter^.Tile, destination, nil, 1) > 0 then
        Break;

      Dec(action_points);
    end;

    if action_points > 0 then
    begin
      register_begin(ANIMATION_REQUEST_RESERVED);
      combatai_msg(critter, nil, AI_MESSAGE_TYPE_RUN, 0);
      register_object_run_to_tile(critter, destination, critter^.Elevation, combatData^.Ap, 0);
      if register_end() = 0 then
        combat_turn_run();
    end;
  end
  else
  begin
    combatData^.Maneuver := combatData^.Maneuver or CRITTER_MANEUVER_DISENGAGING;
  end;
end;

// ---------------------------------------------------------------------------
// compare_nearer
// ---------------------------------------------------------------------------
function compare_nearer(critter_ptr1: Pointer; critter_ptr2: Pointer): Integer; cdecl;
var
  c1, c2: PObject;
  distance1, distance2: Integer;
begin
  c1 := PPObject(critter_ptr1)^;
  c2 := PPObject(critter_ptr2)^;

  if c1 = nil then
  begin
    if c2 = nil then
      Exit(0);
    Exit(1);
  end
  else
  begin
    if c2 = nil then
      Exit(-1);
  end;

  distance1 := obj_dist(c1, combat_obj);
  distance2 := obj_dist(c2, combat_obj);

  if distance1 < distance2 then
    Result := -1
  else if distance1 > distance2 then
    Result := 1
  else
    Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_sort_list
// ---------------------------------------------------------------------------
procedure ai_sort_list(critterList: PPObject; length_: Integer; origin: PObject);
begin
  combat_obj := origin;
  qsort(critterList, SizeUInt(length_), SizeOf(PObject), @compare_nearer);
end;

// ---------------------------------------------------------------------------
// ai_find_nearest_team
// ---------------------------------------------------------------------------
function ai_find_nearest_team(critter: PObject; other: PObject; flags: Integer): PObject;
var
  index: Integer;
  candidate: PObject;
begin
  if other = nil then
    Exit(nil);

  if curr_crit_num = 0 then
    Exit(nil);

  ai_sort_list(curr_crit_list, curr_crit_num, critter);

  index := 0;
  while index < curr_crit_num do
  begin
    candidate := PPObject(PByte(curr_crit_list) + SizeUInt(index) * SizeOf(PObject))^;
    if critter <> candidate then
    begin
      if (candidate^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
      begin
        if (flags and $2) <> 0 then
        begin
          if other^.Data.AsData.Critter.Combat.Team <> candidate^.Data.AsData.Critter.Combat.Team then
            Exit(candidate);
        end;

        if (flags and $1) <> 0 then
        begin
          if other^.Data.AsData.Critter.Combat.Team = candidate^.Data.AsData.Critter.Combat.Team then
            Exit(candidate);
        end;
      end;
    end;
    Inc(index);
  end;

  Result := nil;
end;

// ---------------------------------------------------------------------------
// ai_find_attackers
// ---------------------------------------------------------------------------
function ai_find_attackers(critter: PObject; a2: PPObject; a3: PPObject; a4: PPObject): Integer;
var
  foundTargetCount: Integer;
  team: Integer;
  index: Integer;
  candidate: PObject;
  whoHitCandidate: PObject;
begin
  if a2 <> nil then
    a2^ := nil;

  if a3 <> nil then
    a3^ := nil;

  if a4 <> nil then
    a4^ := nil;

  if curr_crit_num = 0 then
    Exit(0);

  ai_sort_list(curr_crit_list, curr_crit_num, critter);

  foundTargetCount := 0;
  team := critter^.Data.AsData.Critter.Combat.Team;

  index := 0;
  while (foundTargetCount < 3) and (index < curr_crit_num) do
  begin
    candidate := PPObject(PByte(curr_crit_list) + SizeUInt(index) * SizeOf(PObject))^;
    if candidate <> critter then
    begin
      if (a2 <> nil) and (a2^ = nil) then
      begin
        if ((candidate^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0)
          and (candidate^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe = critter) then
        begin
          Inc(foundTargetCount);
          a2^ := candidate;
        end;
      end;

      if (a3 <> nil) and (a3^ = nil) then
      begin
        if team = candidate^.Data.AsData.Critter.Combat.Team then
        begin
          whoHitCandidate := candidate^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
          if (whoHitCandidate <> nil)
            and (whoHitCandidate <> critter)
            and (team <> whoHitCandidate^.Data.AsData.Critter.Combat.Team)
            and ((whoHitCandidate^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
          begin
            Inc(foundTargetCount);
            a3^ := whoHitCandidate;
          end;
        end;
      end;

      if (a4 <> nil) and (a4^ = nil) then
      begin
        if (candidate^.Data.AsData.Critter.Combat.Team <> team)
          and ((candidate^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
        begin
          whoHitCandidate := candidate^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
          if (whoHitCandidate <> nil)
            and (whoHitCandidate^.Data.AsData.Critter.Combat.Team = team) then
          begin
            Inc(foundTargetCount);
            a4^ := candidate;
          end;
        end;
      end;
    end;
    Inc(index);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_danger_source
// ---------------------------------------------------------------------------
function ai_danger_source(critter: PObject): PObject;
var
  who_hit_me: PObject;
  targets: array[0..3] of PObject;
  index: Integer;
begin
  who_hit_me := critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
  if (who_hit_me = nil) or (critter = who_hit_me) then
  begin
    targets[0] := nil;
  end
  else
  begin
    if (who_hit_me^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
      Exit(who_hit_me);

    if who_hit_me^.Data.AsData.Critter.Combat.Team <> critter^.Data.AsData.Critter.Combat.Team then
      targets[0] := ai_find_nearest_team(critter, who_hit_me, 1)
    else
      targets[0] := nil;
  end;

  ai_find_attackers(critter, @targets[1], @targets[2], @targets[3]);
  ai_sort_list(@targets[0], 4, critter);

  for index := 0 to 3 do
  begin
    if (targets[index] <> nil) and is_within_perception(critter, targets[index]) then
      Exit(targets[index]);
  end;

  Result := nil;
end;

// ---------------------------------------------------------------------------
// ai_have_ammo
// ---------------------------------------------------------------------------
function ai_have_ammo(critter: PObject; weapon: PObject): PObject;
var
  inventory_item_index: Integer;
  ammo: PObject;
begin
  inventory_item_index := -1;

  while True do
  begin
    ammo := inven_find_type(critter, ITEM_TYPE_AMMO, @inventory_item_index);
    if ammo = nil then
      Break;

    if item_w_can_reload(weapon, ammo) then
      Exit(ammo);
  end;

  Result := nil;
end;

// ---------------------------------------------------------------------------
// ai_best_weapon
// ---------------------------------------------------------------------------
function ai_best_weapon(weapon1: PObject; weapon2: PObject): PObject;
var
  attack_type1: Integer;
  attack_type2: Integer;
begin
  if weapon1 = nil then
    Exit(weapon2);

  if weapon2 = nil then
    Exit(weapon1);

  attack_type1 := item_w_subtype(weapon1, HIT_MODE_LEFT_WEAPON_PRIMARY);
  attack_type2 := item_w_subtype(weapon2, HIT_MODE_LEFT_WEAPON_PRIMARY);

  if attack_type1 <> attack_type2 then
  begin
    if attack_type1 = ATTACK_TYPE_RANGED then
      Exit(weapon1);

    if attack_type2 = ATTACK_TYPE_RANGED then
      Exit(weapon2);

    if attack_type1 = ATTACK_TYPE_THROW then
      Exit(weapon1);

    if attack_type2 = ATTACK_TYPE_THROW then
      Exit(weapon2);
  end;

  if item_cost(weapon2) > item_cost(weapon1) then
    Result := weapon2
  else
    Result := weapon1;
end;

// ---------------------------------------------------------------------------
// ai_can_use_weapon
// ---------------------------------------------------------------------------
function ai_can_use_weapon(critter: PObject; weapon: PObject; hitMode: Integer): Boolean;
var
  damageFlags: Integer;
  fid: Integer;
begin
  damageFlags := critter^.Data.AsData.Critter.Combat.Results;
  if ((damageFlags and DAM_CRIP_ARM_LEFT) <> 0) and ((damageFlags and DAM_CRIP_ARM_RIGHT) <> 0) then
    Exit(False);

  if ((damageFlags and DAM_CRIP_ARM_ANY) <> 0) and (item_w_is_2handed(weapon) <> 0) then
    Exit(False);

  fid := art_id(OBJ_TYPE_CRITTER,
    critter^.Fid and $FFF,
    item_w_anim_weap(weapon, hitMode),
    item_w_anim_code(weapon),
    critter^.Rotation + 1);
  if not art_exists(fid) then
    Exit(False);

  if skill_level(critter, item_w_skill(weapon, hitMode)) < ai_cap(critter)^.min_to_hit then
    Exit(False);

  Result := True;
end;

// ---------------------------------------------------------------------------
// ai_search_inven
// ---------------------------------------------------------------------------
function ai_search_inven(critter: PObject; check_action_points: Integer): PObject;
var
  body_type: Integer;
  inventory_item_index: Integer;
  best_weapon: PObject;
  current_item: PObject;
  candidate: PObject;
begin
  body_type := critter_body_type(critter);
  if (body_type <> BODY_TYPE_BIPED) and (body_type <> BODY_TYPE_ROBOTIC) then
    Exit(nil);

  best_weapon := nil;
  current_item := inven_right_hand(critter);
  inventory_item_index := -1;

  while True do
  begin
    candidate := inven_find_type(critter, ITEM_TYPE_WEAPON, @inventory_item_index);
    if candidate = nil then
      Break;

    if candidate = current_item then
      Continue;

    if check_action_points <> 0 then
    begin
      if item_w_primary_mp_cost(candidate) > critter^.Data.AsData.Critter.Combat.Ap then
        Continue;
    end;

    if not ai_can_use_weapon(critter, candidate, HIT_MODE_RIGHT_WEAPON_PRIMARY) then
      Continue;

    if item_w_subtype(candidate, HIT_MODE_RIGHT_WEAPON_PRIMARY) = ATTACK_TYPE_RANGED then
    begin
      if item_w_curr_ammo(candidate) = 0 then
      begin
        if ai_have_ammo(critter, candidate) = nil then
          Continue;
      end;
    end;

    best_weapon := ai_best_weapon(best_weapon, candidate);
  end;

  Result := best_weapon;
end;

// ---------------------------------------------------------------------------
// ai_search_environ
// ---------------------------------------------------------------------------
function ai_search_environ(critter: PObject; itemType: Integer): PObject;
var
  objects: PPObject;
  count: Integer;
  max_distance: Integer;
  current_item: PObject;
  found_item: PObject;
  index: Integer;
  distance: Integer;
  item: PObject;
begin
  if critter_body_type(critter) <> BODY_TYPE_BIPED then
    Exit(nil);

  count := obj_create_list(-1, map_elevation, OBJ_TYPE_ITEM, @objects);
  if count = 0 then
    Exit(nil);

  ai_sort_list(objects, count, critter);

  max_distance := stat_level(critter, Integer(STAT_PERCEPTION)) + 5;
  current_item := inven_right_hand(critter);

  found_item := nil;

  index := 0;
  while index < count do
  begin
    item := PPObject(PByte(objects) + SizeUInt(index) * SizeOf(PObject))^;
    distance := obj_dist(critter, item);
    if distance > max_distance then
      Break;

    if item_get_type(item) = itemType then
    begin
      case itemType of
        ITEM_TYPE_WEAPON:
          if ai_can_use_weapon(critter, item, HIT_MODE_RIGHT_WEAPON_PRIMARY) then
            found_item := item;
        ITEM_TYPE_AMMO:
          if item_w_can_reload(current_item, item) then
            found_item := item;
      end;

      if found_item <> nil then
        Break;
    end;
    Inc(index);
  end;

  obj_delete_list(objects);

  Result := found_item;
end;

// ---------------------------------------------------------------------------
// ai_retrieve_object
// ---------------------------------------------------------------------------
function ai_retrieve_object(critter: PObject; item: PObject): PObject;
begin
  if action_get_an_object(critter, item) <> 0 then
    Exit(nil);

  combat_turn_run();

  Result := inven_find_id(critter, item^.Id);
end;

// ---------------------------------------------------------------------------
// ai_pick_hit_mode
// ---------------------------------------------------------------------------
function ai_pick_hit_mode(critter: PObject; weapon: PObject): Integer;
var
  attack_type: Integer;
begin
  if weapon = nil then
    Exit(HIT_MODE_PUNCH);

  if item_get_type(weapon) <> ITEM_TYPE_WEAPON then
    Exit(HIT_MODE_PUNCH);

  attack_type := item_w_subtype(weapon, HIT_MODE_RIGHT_WEAPON_SECONDARY);
  if attack_type = ATTACK_TYPE_NONE then
    Exit(HIT_MODE_RIGHT_WEAPON_PRIMARY);

  if not ai_can_use_weapon(critter, weapon, HIT_MODE_RIGHT_WEAPON_SECONDARY) then
    Exit(HIT_MODE_RIGHT_WEAPON_PRIMARY);

  if roll_random(1, ai_cap(critter)^.secondary_freq) <> 1 then
    Exit(HIT_MODE_RIGHT_WEAPON_PRIMARY);

  if attack_type = ATTACK_TYPE_THROW then
  begin
    if ai_search_inven(critter, 0) = nil then
    begin
      if stat_result(critter, Integer(STAT_INTELLIGENCE), 0, nil) > 1 then
        Exit(HIT_MODE_RIGHT_WEAPON_PRIMARY);
    end;
  end;

  Result := HIT_MODE_RIGHT_WEAPON_SECONDARY;
end;

// ---------------------------------------------------------------------------
// ai_move_closer
// ---------------------------------------------------------------------------
function ai_move_closer(critter: PObject; target: PObject; a3: Integer): Integer;
begin
  if obj_dist(critter, target) <= 1 then
    Exit(-1);

  register_begin(ANIMATION_REQUEST_RESERVED);

  if a3 <> 0 then
    combatai_msg(critter, nil, AI_MESSAGE_TYPE_MOVE, 0);

  register_object_move_to_object(critter, target, critter^.Data.AsData.Critter.Combat.Ap, 0);

  if register_end() <> 0 then
    Exit(-1);

  combat_turn_run();

  Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_switch_weapons
// ---------------------------------------------------------------------------
function ai_switch_weapons(critter: PObject; hit_mode: PInteger; weapon: PPObject): Integer;
var
  best_weapon: PObject;
  retrieved_best_weapon: PObject;
begin
  weapon^ := nil;
  hit_mode^ := HIT_MODE_PUNCH;

  best_weapon := ai_search_inven(critter, 1);
  if best_weapon <> nil then
  begin
    weapon^ := best_weapon;
    hit_mode^ := ai_pick_hit_mode(critter, best_weapon);
  end
  else
  begin
    best_weapon := ai_search_environ(critter, ITEM_TYPE_WEAPON);
    if best_weapon <> nil then
    begin
      retrieved_best_weapon := ai_retrieve_object(critter, best_weapon);
      if retrieved_best_weapon <> nil then
      begin
        weapon^ := retrieved_best_weapon;
        hit_mode^ := ai_pick_hit_mode(critter, retrieved_best_weapon);
      end;
    end;
  end;

  if weapon^ <> nil then
  begin
    inven_wield(critter, weapon^, 1);
    combat_turn_run();
    if item_w_mp_cost(critter, hit_mode^, False) <= critter^.Data.AsData.Critter.Combat.Ap then
      Exit(0);
  end;

  Result := -1;
end;

// ---------------------------------------------------------------------------
// ai_called_shot
// ---------------------------------------------------------------------------
function ai_called_shot(critter: PObject; target: PObject; hit_mode: Integer): Integer;
var
  ai: PAiPacket;
  hit_location: Integer;
  min_intelligence: Integer;
  to_hit: Integer;
  combat_difficulty: Integer;
begin
  hit_location := HIT_LOCATION_TORSO;

  if item_w_mp_cost(critter, hit_mode, True) <= critter^.Data.AsData.Critter.Combat.Ap then
  begin
    if item_w_called_shot(critter, hit_mode) <> 0 then
    begin
      ai := ai_cap(critter);
      if roll_random(1, ai^.called_freq) = 1 then
      begin
        combat_difficulty := COMBAT_DIFFICULTY_NORMAL;
        config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, @combat_difficulty);

        min_intelligence := 5;
        case combat_difficulty of
          COMBAT_DIFFICULTY_EASY:
            min_intelligence := 7;
          COMBAT_DIFFICULTY_NORMAL:
            min_intelligence := 5;
          COMBAT_DIFFICULTY_HARD:
            min_intelligence := 3;
        end;

        if stat_level(critter, Integer(STAT_INTELLIGENCE)) >= min_intelligence then
        begin
          hit_location := roll_random(0, 8);
          to_hit := determine_to_hit(critter, target, hit_location, hit_mode);
          if to_hit < ai^.min_to_hit then
            hit_location := HIT_LOCATION_TORSO;
        end;
      end;
    end;
  end;

  Result := hit_location;
end;

// ---------------------------------------------------------------------------
// ai_attack
// ---------------------------------------------------------------------------
function ai_attack(critter: PObject; target: PObject; hit_mode: Integer): Integer;
var
  hit_location: Integer;
begin
  if (critter^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0 then
    Exit(-1);

  register_begin(ANIMATION_REQUEST_RESERVED);
  register_object_turn_towards(critter, target^.Tile);
  register_end();
  combat_turn_run();

  hit_location := ai_called_shot(critter, target, hit_mode);
  if combat_attack(critter, target, hit_mode, hit_location) <> 0 then
    Exit(-1);

  combat_turn_run();

  Result := 0;
end;

// ---------------------------------------------------------------------------
// ai_try_attack
// ---------------------------------------------------------------------------
function ai_try_attack(critter: PObject; target: PObject): Integer;
var
  combat_taunts: Integer;
  weapon: PObject;
  hit_mode: Integer;
  attempt: Integer;
  bad_shot: Integer;
  ammo: PObject;
  remaining_rounds: Integer;
  volume: Integer;
  sfx: PAnsiChar;
  action_points: Integer;
  to_hit: Integer;
begin
  combat_taunts := 1;

  critter_set_who_hit_me(critter, target);

  weapon := inven_right_hand(critter);
  if (weapon <> nil) and (item_get_type(weapon) <> ITEM_TYPE_WEAPON) then
    weapon := nil;

  hit_mode := ai_pick_hit_mode(critter, weapon);

  if weapon = nil then
  begin
    if (critter_body_type(target) <> BODY_TYPE_BIPED)
      or (((target^.Fid and $F000) shr 12) <> 0)
      or (not art_exists(art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_THROW_PUNCH, 0, critter^.Rotation + 1))) then
    begin
      ai_switch_weapons(critter, @hit_mode, @weapon);
    end;
  end;

  attempt := 0;
  while attempt < 10 do
  begin
    if (critter^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD or DAM_LOSE_TURN)) <> 0 then
      Break;

    bad_shot := combat_check_bad_shot(critter, target, hit_mode, False);

    case bad_shot of
      COMBAT_BAD_SHOT_OK:
      begin
        to_hit := determine_to_hit(critter, target, HIT_LOCATION_UNCALLED, hit_mode);
        if to_hit >= ai_cap(critter)^.min_to_hit then
        begin
          if ai_attack(critter, target, hit_mode) = -1 then
            Exit(-1);

          if item_w_mp_cost(critter, hit_mode, False) > critter^.Data.AsData.Critter.Combat.Ap then
            Exit(-1);
        end
        else
        begin
          to_hit := determine_to_hit_no_range(critter, target, HIT_LOCATION_UNCALLED, hit_mode);
          if to_hit < ai_cap(critter)^.min_to_hit then
          begin
            ai_run_away(critter);
            Exit(0);
          end;

          if ai_move_closer(critter, target, combat_taunts) = -1 then
          begin
            ai_run_away(critter);
            Exit(0);
          end;

          combat_taunts := 0;
        end;
      end;

      COMBAT_BAD_SHOT_NO_AMMO:
      begin
        ammo := ai_have_ammo(critter, weapon);
        if ammo <> nil then
        begin
          remaining_rounds := item_w_reload(weapon, ammo);
          if remaining_rounds = 0 then
            obj_destroy(ammo);

          if remaining_rounds <> -1 then
          begin
            volume := gsound_compute_relative_volume(critter);
            sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_READY, weapon, hit_mode, nil);
            gsound_play_sfx_file_volume(sfx, volume);
            ai_magic_hands(critter, weapon, 5002);

            action_points := critter^.Data.AsData.Critter.Combat.Ap;
            if action_points >= 2 then
              critter^.Data.AsData.Critter.Combat.Ap := action_points - 2
            else
              critter^.Data.AsData.Critter.Combat.Ap := 0;
          end;
        end
        else
        begin
          ammo := ai_search_environ(critter, ITEM_TYPE_AMMO);
          if ammo <> nil then
          begin
            ammo := ai_retrieve_object(critter, ammo);
            if ammo <> nil then
            begin
              remaining_rounds := item_w_reload(weapon, ammo);
              if remaining_rounds = 0 then
                obj_destroy(ammo);

              if remaining_rounds <> -1 then
              begin
                volume := gsound_compute_relative_volume(critter);
                sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_READY, weapon, hit_mode, nil);
                gsound_play_sfx_file_volume(sfx, volume);
                ai_magic_hands(critter, weapon, 5002);

                action_points := critter^.Data.AsData.Critter.Combat.Ap;
                if action_points >= 2 then
                  critter^.Data.AsData.Critter.Combat.Ap := action_points - 2
                else
                  critter^.Data.AsData.Critter.Combat.Ap := 0;
              end;
            end;
          end
          else
          begin
            volume := gsound_compute_relative_volume(critter);
            sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_OUT_OF_AMMO, weapon, hit_mode, nil);
            gsound_play_sfx_file_volume(sfx, volume);
            ai_magic_hands(critter, weapon, 5001);

            if inven_unwield(critter, 1) = 0 then
              combat_turn_run();

            ai_switch_weapons(critter, @hit_mode, @weapon);
          end;
        end;
      end;

      COMBAT_BAD_SHOT_OUT_OF_RANGE:
      begin
        to_hit := determine_to_hit_no_range(critter, target, HIT_LOCATION_UNCALLED, hit_mode);
        if to_hit < ai_cap(critter)^.min_to_hit then
        begin
          ai_run_away(critter);
          Exit(0);
        end;

        if (weapon <> nil) or (ai_switch_weapons(critter, @hit_mode, @weapon) = -1) or (weapon = nil) then
        begin
          if ai_move_closer(critter, target, combat_taunts) = -1 then
            Exit(-1);

          combat_taunts := 0;
        end;
      end;

      COMBAT_BAD_SHOT_NOT_ENOUGH_AP,
      COMBAT_BAD_SHOT_ARM_CRIPPLED,
      COMBAT_BAD_SHOT_BOTH_ARMS_CRIPPLED:
      begin
        if ai_switch_weapons(critter, @hit_mode, @weapon) = -1 then
          Exit(-1);
      end;

      COMBAT_BAD_SHOT_AIM_BLOCKED:
      begin
        if ai_move_closer(critter, target, combat_taunts) = -1 then
          Exit(-1);
        combat_taunts := 0;
      end;
    end;

    Inc(attempt);
  end;

  Result := -1;
end;

// ---------------------------------------------------------------------------
// combat_ai_begin
// ---------------------------------------------------------------------------
procedure combat_ai_begin(critters_count: Integer; critters: PPObject);
begin
  curr_crit_num := critters_count;

  if critters_count <> 0 then
  begin
    curr_crit_list := PPObject(mem_malloc(SizeOf(PObject) * SizeUInt(critters_count)));
    if curr_crit_list <> nil then
      Move(critters^, curr_crit_list^, SizeOf(PObject) * SizeUInt(critters_count))
    else
      curr_crit_num := 0;
  end;
end;

// ---------------------------------------------------------------------------
// combat_ai_over
// ---------------------------------------------------------------------------
procedure combat_ai_over;
begin
  if curr_crit_num <> 0 then
    mem_free(curr_crit_list);

  curr_crit_num := 0;
end;

// ---------------------------------------------------------------------------
// combat_ai
// ---------------------------------------------------------------------------
function combat_ai(critter: PObject; target: PObject): PObject;
var
  ai: PAiPacket;
  combatData: PCritterCombatData;
  whoHitMe: PObject;
begin
  combatData := @critter^.Data.AsData.Critter.Combat;
  ai := ai_cap(critter);

  if ((combatData^.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0)
    or ((combatData^.Results and ai^.hurt_too_much) <> 0)
    or (stat_level(critter, Integer(STAT_CURRENT_HIT_POINTS)) < ai^.min_hp) then
  begin
    ai_run_away(critter);
    Exit(target);
  end;

  if target = nil then
  begin
    if ai_check_drugs(critter) <> 0 then
      ai_run_away(critter)
    else
    begin
      target := ai_danger_source(critter);
      if target <> nil then
        ai_try_attack(critter, target);
    end;
  end
  else
  begin
    ai_try_attack(critter, target);
  end;

  if target <> nil then
  begin
    if (target^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
    begin
      if critter^.Data.AsData.Critter.Combat.Ap <> 0 then
      begin
        if obj_dist(critter, target) > ai^.max_dist then
          combatData^.Maneuver := combatData^.Maneuver or CRITTER_MANEUVER_DISENGAGING;
      end;
    end;
  end;

  if target = nil then
  begin
    if not isPartyMember(critter) then
    begin
      whoHitMe := combatData^.WhoHitMeUnion.WhoHitMe;
      if whoHitMe <> nil then
      begin
        if ((whoHitMe^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0)
          and (combatData^.DamageLastTurn > 0) then
        begin
          ai_run_away(critter);
        end;
      end;
    end;
  end;

  if target = nil then
  begin
    if isPartyMember(critter) then
    begin
      if obj_dist(critter, obj_dude) > 5 then
        ai_move_closer(critter, obj_dude, 0);
    end;
  end;

  Result := target;
end;

// ---------------------------------------------------------------------------
// combatai_want_to_join
// ---------------------------------------------------------------------------
function combatai_want_to_join(a1: PObject): Boolean;
begin
  process_bk();

  if (a1^.Flags and OBJECT_HIDDEN) <> 0 then
    Exit(False);

  if a1^.Elevation <> obj_dude^.Elevation then
    Exit(False);

  if (a1^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
    Exit(False);

  if a1^.Data.AsData.Critter.Combat.DamageLastTurn > 0 then
    Exit(True);

  if a1^.Sid <> -1 then
  begin
    scr_set_objs(a1^.Sid, nil, nil);
    scr_set_ext_param(a1^.Sid, 5);
    exec_script_proc(a1^.Sid, SCRIPT_PROC_COMBAT);
  end;

  if (a1^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANEUVER_ENGAGING) <> 0 then
    Exit(True);

  if (a1^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANEUVER_DISENGAGING) <> 0 then
    Exit(False);

  if (a1^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0 then
    Exit(False);

  if ai_danger_source(a1) = nil then
    Exit(False);

  Result := True;
end;

// ---------------------------------------------------------------------------
// combatai_want_to_stop
// ---------------------------------------------------------------------------
function combatai_want_to_stop(a1: PObject): Boolean;
var
  danger: PObject;
begin
  process_bk();

  if (a1^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANEUVER_DISENGAGING) <> 0 then
    Exit(True);

  if (a1^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD)) <> 0 then
    Exit(True);

  if (a1^.Data.AsData.Critter.Combat.Maneuver and CRITTER_MANUEVER_FLEEING) <> 0 then
    Exit(True);

  danger := ai_danger_source(a1);
  if danger = nil then
    Exit(True);

  if not is_within_perception(a1, danger) then
    Exit(True);

  if a1^.Data.AsData.Critter.Combat.Ap = stat_level(a1, Integer(STAT_MAXIMUM_ACTION_POINTS)) then
    Exit(True);

  Result := False;
end;

// ---------------------------------------------------------------------------
// combatai_switch_team
// ---------------------------------------------------------------------------
function combatai_switch_team(critter: PObject; team: Integer): Integer;
var
  who_hit_me: PObject;
  outline_was_enabled: Boolean;
  outline_type: Integer;
  rect: TRect;
begin
  critter^.Data.AsData.Critter.Combat.Team := team;

  if critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMeCid = -1 then
  begin
    critter_set_who_hit_me(critter, nil);
    debug_printf(#10'Error: CombatData found with invalid who_hit_me!');
    Exit(-1);
  end;

  who_hit_me := critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe;
  if who_hit_me <> nil then
  begin
    if who_hit_me^.Data.AsData.Critter.Combat.Team = team then
      critter_set_who_hit_me(critter, nil);
  end;

  if isInCombat() then
  begin
    outline_was_enabled := (critter^.Outline <> 0) and ((critter^.Outline and Integer(OUTLINE_DISABLED)) = 0);

    obj_remove_outline(critter, nil);

    outline_type := Integer(OUTLINE_TYPE_HOSTILE);
    if perk_level(PERK_FRIENDLY_FOE) <> 0 then
    begin
      if critter^.Data.AsData.Critter.Combat.Team = obj_dude^.Data.AsData.Critter.Combat.Team then
        outline_type := Integer(OUTLINE_TYPE_FRIENDLY);
    end;

    obj_outline_object(critter, outline_type, nil);

    if outline_was_enabled then
    begin
      obj_turn_on_outline(critter, @rect);
      tile_refresh_rect(@rect, critter^.Elevation);
    end;
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// combatai_msg
// ---------------------------------------------------------------------------
function combatai_msg(critter: PObject; attack: PAttack; type_: Integer; delay: Integer): Integer;
var
  combat_taunts: Integer;
  ai: PAiPacket;
  start_: Integer;
  end_: Integer;
  str: PAnsiChar;
  messageListItem: TMessageListItem;
begin
  combat_taunts := 1;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
    Exit(-1);

  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_TAUNTS_KEY, @combat_taunts);
  if combat_taunts = 0 then
    Exit(-1);

  if critter = obj_dude then
    Exit(-1);

  if (critter^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
    Exit(-1);

  ai := ai_cap(critter);

  debug_printf('%s is using %s packet with a %d%% chance to taunt'#10, object_name(critter), ai^.name, ai^.chance);

  if roll_random(1, 100) > ai^.chance then
    Exit(-1);

  start_ := 0;
  end_ := 0;
  str := nil;

  case type_ of
    AI_MESSAGE_TYPE_RUN:
    begin
      start_ := ai^.run_start;
      end_ := ai^.move_start;
      str := @attack_str[0];
    end;
    AI_MESSAGE_TYPE_MOVE:
    begin
      start_ := ai^.move_start;
      end_ := ai^.attack_start;
      str := @attack_str[0];
    end;
    AI_MESSAGE_TYPE_ATTACK:
    begin
      start_ := ai^.attack_start;
      end_ := ai^.miss_start;
      str := @attack_str[0];
    end;
    AI_MESSAGE_TYPE_MISS:
    begin
      start_ := ai^.miss_start;
      end_ := ai^.hit_start[0];
      str := @target_str[0];
    end;
    AI_MESSAGE_TYPE_HIT:
    begin
      start_ := ai^.hit_start[attack^.defenderHitLocation];
      end_ := ai^.hit_start[attack^.defenderHitLocation + 1];
      str := @target_str[0];
    end;
  else
    Exit(-1);
  end;

  if end_ < start_ then
    Exit(-1);

  messageListItem.num := roll_random(start_, end_);
  if not message_search(@ai_message_file, @messageListItem) then
    Exit(-1);

  debug_printf('%s said message %d'#10, object_name(critter), messageListItem.num);
  StrLCopy(str, messageListItem.text, 79);

  // TODO: Get rid of casts.
  Result := register_object_call(critter, Pointer(PtrUInt(type_)), TAnimationCallback(@ai_print_msg), delay);
end;

// ---------------------------------------------------------------------------
// ai_print_msg
// ---------------------------------------------------------------------------
function ai_print_msg(critter: PObject; type_: Integer): Integer; cdecl;
var
  str: PAnsiChar;
  ai: PAiPacket;
  rect: TRect;
begin
  if text_object_count() > 0 then
    Exit(0);

  case type_ of
    AI_MESSAGE_TYPE_HIT,
    AI_MESSAGE_TYPE_MISS:
      str := @target_str[0];
  else
    str := @attack_str[0];
  end;

  ai := ai_cap(critter);

  if text_object_create(critter, str, ai^.font, ai^.color, ai^.outline_color, @rect) = 0 then
    tile_refresh_rect(@rect, critter^.Elevation);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// combat_ai_random_target
// ---------------------------------------------------------------------------
function combat_ai_random_target(attack: PAttack): PObject;
var
  critter: PObject;
  start_: Integer;
  index: Integer;
  obj: PObject;
begin
  // Looks like this function does nothing because its result is not used. I
  // suppose it was planned to use range as a condition below, but it was
  // later moved, but remained here.
  item_w_range(attack^.attacker, attack^.hitMode);

  critter := nil;

  if curr_crit_num <> 0 then
  begin
    start_ := roll_random(0, curr_crit_num - 1);
    index := start_;

    while True do
    begin
      obj := PPObject(PByte(curr_crit_list) + SizeUInt(index) * SizeOf(PObject))^;
      if (obj <> attack^.attacker)
        and (obj <> attack^.defender)
        and can_see(attack^.attacker, obj)
        and (combat_check_bad_shot(attack^.attacker, obj, attack^.hitMode, False) = COMBAT_BAD_SHOT_OK) then
      begin
        critter := obj;
        Break;
      end;

      Inc(index);
      if index = curr_crit_num then
        index := 0;

      if index = start_ then
        Break;
    end;
  end;

  Result := critter;
end;

// ---------------------------------------------------------------------------
// combatai_rating
// ---------------------------------------------------------------------------
function combatai_rating(obj: PObject): Integer;
var
  melee_damage: Integer;
  item: PObject;
  weapon_damage_min: Integer;
  weapon_damage_max: Integer;
begin
  if obj = nil then
    Exit(0);

  if FID_TYPE(obj^.Fid) <> OBJ_TYPE_CRITTER then
    Exit(0);

  if (obj^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) <> 0 then
    Exit(0);

  melee_damage := stat_level(obj, Integer(STAT_MELEE_DAMAGE));

  item := inven_right_hand(obj);
  if (item <> nil) and (item_get_type(item) = ITEM_TYPE_WEAPON)
    and (item_w_damage_min_max(item, @weapon_damage_min, @weapon_damage_max) <> -1)
    and (melee_damage < weapon_damage_max) then
  begin
    melee_damage := weapon_damage_max;
  end;

  item := inven_left_hand(obj);
  if (item <> nil) and (item_get_type(item) = ITEM_TYPE_WEAPON)
    and (item_w_damage_min_max(item, @weapon_damage_min, @weapon_damage_max) <> -1)
    and (melee_damage < weapon_damage_max) then
  begin
    melee_damage := weapon_damage_max;
  end;

  Result := melee_damage + stat_level(obj, Integer(STAT_ARMOR_CLASS));
end;

// ---------------------------------------------------------------------------
// combatai_check_retaliation
// ---------------------------------------------------------------------------
procedure combatai_check_retaliation(critter: PObject; candidate: PObject);
var
  rating_new: Integer;
  rating_current: Integer;
begin
  rating_new := combatai_rating(candidate);
  rating_current := combatai_rating(critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe);
  if rating_new > rating_current then
    critter_set_who_hit_me(critter, candidate);
end;

// ---------------------------------------------------------------------------
// is_within_perception
// ---------------------------------------------------------------------------
function is_within_perception(critter1: PObject; critter2: PObject): Boolean;
var
  distance: Integer;
  perception: Integer;
  max_distance: Integer;
begin
  distance := obj_dist(critter2, critter1);
  perception := stat_level(critter1, Integer(STAT_PERCEPTION));

  if can_see(critter1, critter2) then
  begin
    max_distance := perception * 5;
    if (critter2^.Flags and OBJECT_TRANS_GLASS) <> 0 then
      max_distance := max_distance div 2;

    if critter2 = obj_dude then
    begin
      if is_pc_sneak_working() then
        max_distance := max_distance div 4;
    end;

    if distance <= max_distance then
      Exit(True);
  end
  else
  begin
    if isInCombat() then
      max_distance := perception * 2
    else
      max_distance := perception;

    if critter2 = obj_dude then
    begin
      if is_pc_sneak_working() then
        max_distance := max_distance div 4;
    end;

    if distance <= max_distance then
      Exit(True);
  end;

  Result := False;
end;

// ---------------------------------------------------------------------------
// combatai_load_messages
// ---------------------------------------------------------------------------
function combatai_load_messages: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  language_filter: Integer;
begin
  language_filter := 0;

  if not message_init(@ai_message_file) then
    Exit(-1);

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'combatai.msg']);

  if not message_load(@ai_message_file, @path[0]) then
    Exit(-1);

  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, @language_filter);

  if language_filter <> 0 then
    message_filter(@ai_message_file);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// combatai_unload_messages
// ---------------------------------------------------------------------------
function combatai_unload_messages: Integer;
begin
  if not message_exit(@ai_message_file) then
    Exit(-1);

  Result := 0;
end;

// ---------------------------------------------------------------------------
// combatai_refresh_messages
// ---------------------------------------------------------------------------
procedure combatai_refresh_messages;
var
  language_filter: Integer;
begin
  language_filter := 0;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, @language_filter);

  if language_filter <> old_state then
  begin
    old_state := language_filter;

    if language_filter = 1 then
      message_filter(@ai_message_file)
    else
    begin
      if combatai_unload_messages() = 0 then
        combatai_load_messages();
    end;
  end;
end;

// ---------------------------------------------------------------------------
// combatai_notify_onlookers
// ---------------------------------------------------------------------------
procedure combatai_notify_onlookers(critter: PObject);
var
  index: Integer;
  crit: PObject;
begin
  index := 0;
  while index < curr_crit_num do
  begin
    crit := PPObject(PByte(curr_crit_list) + SizeUInt(index) * SizeOf(PObject))^;
    if is_within_perception(crit, critter) then
      crit^.Data.AsData.Critter.Combat.Maneuver := crit^.Data.AsData.Critter.Combat.Maneuver or CRITTER_MANEUVER_ENGAGING;
    Inc(index);
  end;
end;

// ---------------------------------------------------------------------------
// combatai_delete_critter
// ---------------------------------------------------------------------------
procedure combatai_delete_critter(critter: PObject);
var
  index: Integer;
  p: PPObject;
  last: PPObject;
begin
  index := 0;
  while index < curr_crit_num do
  begin
    p := PPObject(PByte(curr_crit_list) + SizeUInt(index) * SizeOf(PObject));
    if critter = p^ then
    begin
      Dec(curr_crit_num);
      last := PPObject(PByte(curr_crit_list) + SizeUInt(curr_crit_num) * SizeOf(PObject));
      p^ := last^;
      last^ := critter;
      Break;
    end;
    Inc(index);
  end;
end;

// ---------------------------------------------------------------------------
// Initialization of rmatchHurtVals
// ---------------------------------------------------------------------------
initialization
  rmatchHurtVals[HURT_BLIND] := DAM_BLIND;
  rmatchHurtVals[HURT_CRIPPLED] := DAM_CRIP_LEG_LEFT or DAM_CRIP_LEG_RIGHT or DAM_CRIP_ARM_LEFT or DAM_CRIP_ARM_RIGHT;
  rmatchHurtVals[HURT_CRIPPLED_LEGS] := DAM_CRIP_LEG_LEFT or DAM_CRIP_LEG_RIGHT;
  rmatchHurtVals[HURT_CRIPPLED_ARMS] := DAM_CRIP_ARM_LEFT or DAM_CRIP_ARM_RIGHT;

end.
