unit u_critter;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/critter.h + critter.cc
// Critter management: name, HP, poison, radiation, kill counts, flags, etc.

interface

uses
  u_db,
  u_object_types,
  u_proto_types,
  u_stat_defs;

const
  // Maximum length of dude's name length.
  DUDE_NAME_MAX_LENGTH = 32;

  // The number of effects caused by radiation.
  RADIATION_EFFECT_COUNT = 8;

  // Radiation levels.
  RADIATION_LEVEL_NONE     = 0;
  RADIATION_LEVEL_MINOR    = 1;
  RADIATION_LEVEL_ADVANCED = 2;
  RADIATION_LEVEL_CRITICAL = 3;
  RADIATION_LEVEL_DEADLY   = 4;
  RADIATION_LEVEL_FATAL    = 5;
  RADIATION_LEVEL_COUNT    = 6;

  // PC flags.
  PC_FLAG_SNEAKING            = 0;
  PC_FLAG_LEVEL_UP_AVAILABLE  = 3;
  PC_FLAG_ADDICTED            = 4;

var
  rad_stat: array[0..RADIATION_EFFECT_COUNT - 1] of Integer;
  rad_bonus: array[0..RADIATION_LEVEL_COUNT - 1, 0..RADIATION_EFFECT_COUNT - 1] of Integer;

function critter_init: Integer; cdecl;
procedure critter_reset; cdecl;
procedure critter_exit; cdecl;
function critter_load(stream: PDB_FILE): Integer;
function critter_save(stream: PDB_FILE): Integer;
function critter_name(critter: PObject): PAnsiChar; cdecl;
procedure critter_copy(dest: PCritterProtoData; src: PCritterProtoData); cdecl;
function critter_pc_set_name(name: PAnsiChar): Integer; cdecl;
procedure critter_pc_reset_name; cdecl;
function critter_get_hits(critter: PObject): Integer; cdecl;
function critter_adjust_hits(critter: PObject; amount: Integer): Integer; cdecl;
function critter_get_poison(critter: PObject): Integer; cdecl;
function critter_adjust_poison(critter: PObject; amount: Integer): Integer; cdecl;
function critter_check_poison(obj: PObject; data: Pointer): Integer; cdecl;
function critter_get_rads(obj: PObject): Integer; cdecl;
function critter_adjust_rads(obj: PObject; amount: Integer): Integer; cdecl;
function critter_check_rads(obj: PObject): Integer; cdecl;
function critter_process_rads(obj: PObject; data: Pointer): Integer; cdecl;
function critter_load_rads(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
function critter_save_rads(stream: PDB_FILE; data: Pointer): Integer; cdecl;
function critter_kill_count_inc(critter_type: Integer): Integer; cdecl;
function critter_kill_count(critter_type: Integer): Integer; cdecl;
function critter_kill_count_load(stream: PDB_FILE): Integer;
function critter_kill_count_save(stream: PDB_FILE): Integer;
function critter_kill_count_type(obj: PObject): Integer; cdecl;
function critter_kill_name(critter_type: Integer): PAnsiChar; cdecl;
function critter_kill_info(critter_type: Integer): PAnsiChar; cdecl;
function critter_heal_hours(critter: PObject; hours: Integer): Integer; cdecl;
procedure critter_kill(critter: PObject; anim: Integer; refresh_window: Boolean); cdecl;
function critter_kill_exps(critter: PObject): Integer; cdecl;
function critter_is_active(critter: PObject): Boolean; cdecl;
function critter_is_dead(critter: PObject): Boolean; cdecl;
function critter_is_crippled(critter: PObject): Boolean; cdecl;
function critter_is_prone(critter: PObject): Boolean; cdecl;
function critter_body_type(critter: PObject): Integer; cdecl;
function critter_load_data(critterData: PCritterProtoData; path: PAnsiChar): Integer; cdecl;
function pc_load_data(path: PAnsiChar): Integer; cdecl;
function critter_read_data(stream: PDB_FILE; critterData: PCritterProtoData): Integer; cdecl;
function critter_save_data(critterData: PCritterProtoData; path: PAnsiChar): Integer; cdecl;
function pc_save_data(path: PAnsiChar): Integer; cdecl;
function critter_write_data(stream: PDB_FILE; critterData: PCritterProtoData): Integer; cdecl;
procedure pc_flag_off(pc_flag: Integer); cdecl;
procedure pc_flag_on(pc_flag: Integer); cdecl;
procedure pc_flag_toggle(pc_flag: Integer); cdecl;
function is_pc_flag(pc_flag: Integer): Boolean; cdecl;
function critter_sneak_check(obj: PObject; data: Pointer): Integer; cdecl;
function critter_sneak_clear(obj: PObject; data: Pointer): Integer; cdecl;
function is_pc_sneak_working: Boolean; cdecl;
function critter_wake_up(obj: PObject; data: Pointer): Integer; cdecl;
function critter_wake_clear(obj: PObject; data: Pointer): Integer; cdecl;
function critter_set_who_hit_me(critter: PObject; who_hit_me: PObject): Integer; cdecl;
function critter_can_obj_dude_rest: Boolean; cdecl;
function critter_compute_ap_from_distance(critter: PObject; distance: Integer): Integer; cdecl;

implementation

uses
  SysUtils,
  u_memory,
  u_queue,
  u_message,
  u_proto,
  u_art,
  u_object,
  u_anim,
  u_combat,
  u_party,
  u_map,
  u_worldmap,
  u_intface,
  u_scripts,
  u_roll,
  u_stat,
  u_skill,
  u_trait,
  u_reaction,
  u_game,
  u_rect,
  u_display,
  u_item,
  u_inventry,
  u_tile,
  u_debug,
  u_editor;

const
  COMPAT_MAX_PATH = 260;

  // Denotes how many primary stats at the top of rad_stat array.
  RADIATION_EFFECT_PRIMARY_STAT_COUNT = 6;

  // From roll.h
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

  // From scripts.h / game.h
  GAME_TIME_TICKS_PER_HOUR = 10 * 60 * 60;
  GAME_TIME_TICKS_PER_DAY  = 24 * GAME_TIME_TICKS_PER_HOUR;

  // Map constants (from worldmap.h)
  MAP_DESERT1   = 0;
  MAP_DESERT2   = 1;
  MAP_DESERT3   = 2;
  MAP_HALLDED   = 3;
  MAP_HOTEL     = 4;
  MAP_WATRSHD   = 5;
  MAP_VAULT13   = 6;
  MAP_VAULTENT  = 7;
  MAP_VAULTBUR  = 8;
  MAP_VAULTNEC  = 9;
  MAP_JUNKENT   = 10;
  MAP_JUNKCSNO  = 11;
  MAP_JUNKKILL  = 12;
  MAP_BROHDENT  = 13;
  MAP_BROHD12   = 14;
  MAP_BROHD34   = 15;
  MAP_CAVES     = 16;
  MAP_CHILDRN1  = 17;
  MAP_CHILDRN2  = 18;
  MAP_CITY1     = 19;
  MAP_COAST1    = 20;
  MAP_COAST2    = 21;
  MAP_COLATRUK  = 22;
  MAP_FSAUSER   = 23;
  MAP_RAIDERS   = 24;
  MAP_SHADYE    = 25;
  MAP_SHADYW    = 26;
  MAP_GLOWENT   = 27;
  MAP_LAADYTUM  = 28;
  MAP_LAFOLLWR  = 29;
  MAP_MBENT     = 30;
  MAP_MBSTRG12  = 31;
  MAP_MBVATS12  = 32;
  MAP_MSTRLR12  = 33;
  MAP_MSTRLR34  = 34;
  MAP_V13ENT    = 35;
  MAP_HUBENT    = 36;
  MAP_DETHCLAW  = 37;
  MAP_HUBDWNTN  = 38;
  MAP_HUBHEIGT  = 39;
  MAP_HUBOLDTN  = 40;
  MAP_HUBWATER  = 41;
  MAP_GLOW1     = 42;
  MAP_GLOW2     = 43;
  MAP_LABLADES  = 44;
  MAP_LARIPPER  = 45;
  MAP_LAGUNRUN  = 46;

  // Town constants (from worldmap.h)
  TOWN_VAULT_13     = 0;
  TOWN_VAULT_15     = 1;
  TOWN_SHADY_SANDS  = 2;
  TOWN_JUNKTOWN     = 3;
  TOWN_RAIDERS      = 4;
  TOWN_NECROPOLIS   = 5;
  TOWN_THE_HUB      = 6;
  TOWN_BROTHERHOOD  = 7;
  TOWN_MILITARY_BASE = 8;
  TOWN_THE_GLOW     = 9;
  TOWN_BONEYARD     = 10;
  TOWN_CATHEDRAL    = 11;

  // Animation constants (from anim.h)
  ANIM_STAND                     = 0;
  ANIM_FALL_BACK                 = 20;
  ANIM_FALL_FRONT                = 21;
  ANIM_FALL_BACK_BLOOD_SF        = 62;
  ANIM_FALL_FRONT_BLOOD_SF       = 63;
  ANIM_FALL_BACK_SF              = 48;
  ANIM_FALL_FRONT_SF             = 49;
  FIRST_KNOCKDOWN_AND_DEATH_ANIM = 20;
  LAST_KNOCKDOWN_AND_DEATH_ANIM  = 35;
  FIRST_SF_DEATH_ANIM            = 48;
  LAST_SF_DEATH_ANIM             = 63;

  // Skill constants
  SKILL_SNEAK = 8;
  SKILL_COUNT = 18;

// scr_ptr imported from u_scripts

// -----------------------------------------------------------------------
// Static (module-level) forward declarations
// -----------------------------------------------------------------------
function get_rad_damage_level(obj: PObject; data: Pointer): Integer; cdecl; forward;
function clear_rad_damage(obj: PObject; data: Pointer): Integer; cdecl; forward;
procedure process_rads(obj: PObject; radiationLevel: Integer; isHealing: Boolean); forward;
function critter_kill_count_clear: Integer; forward;

// -----------------------------------------------------------------------
// Module-level variables
// -----------------------------------------------------------------------

// TODO: Remove.
// 0x4F0DF4
var
  _aCorpse: array[0..6] of AnsiChar = 'corpse';

// TODO: Remove.
// 0x501494
  byte_501494: array[0..0] of AnsiChar = '';

// scrname.msg
// 0x56BEF4
  critter_scrmsg_file: TMessageList;

// 0x56BEFC
  pc_name: array[0..DUDE_NAME_MAX_LENGTH - 1] of AnsiChar;

// 0x56BF1C
  sneak_working: Integer;

// 0x56BF24
  pc_kill_counts: array[0..KILL_TYPE_COUNT - 1] of Integer;

// 0x56BF20
  old_rad_level: Integer;

// Static local from critter_name
  _name_critter: PAnsiChar;

// Static local from critter_check_rads
  check_rads_bonus: array[0..RADIATION_LEVEL_COUNT - 1] of Integer;

// -----------------------------------------------------------------------
// FID_ANIM_TYPE inline
// -----------------------------------------------------------------------
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// =======================================================================
// critter_init
// 0x427860
// =======================================================================
function critter_init: Integer; cdecl;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  critter_pc_reset_name();

  // NOTE: Uninline.
  critter_kill_count_clear();

  if not message_init(@critter_scrmsg_file) then
  begin
    debug_printf(PAnsiChar(#10'Error: Initing critter name message file!'));
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%sscrname.msg', [msg_path]);

  if not message_load(@critter_scrmsg_file, @path[0]) then
  begin
    debug_printf(PAnsiChar(#10'Error: Loading critter name message file!'));
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// critter_reset
// 0x4278F4
// =======================================================================
procedure critter_reset; cdecl;
begin
  critter_pc_reset_name();

  // NOTE: Uninline.
  critter_kill_count_clear();
end;

// =======================================================================
// critter_exit
// 0x427914
// =======================================================================
procedure critter_exit; cdecl;
begin
  message_exit(@critter_scrmsg_file);
end;

// =======================================================================
// critter_load
// 0x42792C
// =======================================================================
function critter_load(stream: PDB_FILE): Integer;
var
  proto: PProto;
begin
  if db_freadInt(stream, @sneak_working) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj_dude^.Pid, @proto);

  Result := critter_read_data(stream, @(proto^.Critter.Data));
end;

// =======================================================================
// critter_save
// 0x427968
// =======================================================================
function critter_save(stream: PDB_FILE): Integer;
var
  proto: PProto;
begin
  if db_fwriteInt(stream, sneak_working) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj_dude^.Pid, @proto);

  Result := critter_write_data(stream, @(proto^.Critter.Data));
end;

// =======================================================================
// critter_copy
// 0x4279A4
// =======================================================================
procedure critter_copy(dest: PCritterProtoData; src: PCritterProtoData); cdecl;
begin
  Move(src^, dest^, SizeOf(TCritterProtoData));
end;

// =======================================================================
// critter_name
// 0x4279B8
// =======================================================================
function critter_name(critter: PObject): PAnsiChar; cdecl;
var
  script: PScript;
  name: PAnsiChar;
  messageListItem: TMessageListItem;
begin
  if critter = obj_dude then
  begin
    Result := @pc_name[0];
    Exit;
  end;

  if critter^.Field_80 = -1 then
  begin
    if critter^.Sid <> -1 then
    begin
      if scr_ptr(critter^.Sid, @script) <> -1 then
      begin
        critter^.Field_80 := script^.scr_script_idx;
      end;
    end;
  end;

  name := nil;
  if critter^.Field_80 <> -1 then
  begin
    messageListItem.num := 101 + critter^.Field_80;
    if message_search(@critter_scrmsg_file, @messageListItem) then
    begin
      name := messageListItem.text;
    end;
  end;

  if (name = nil) or (name^ = #0) then
  begin
    name := proto_name(critter^.Pid);
  end;

  _name_critter := name;

  Result := name;
end;

// =======================================================================
// critter_pc_set_name
// 0x427A48
// =======================================================================
function critter_pc_set_name(name: PAnsiChar): Integer; cdecl;
begin
  if StrLen(name) <= DUDE_NAME_MAX_LENGTH then
  begin
    StrLCopy(@pc_name[0], name, DUDE_NAME_MAX_LENGTH);
    Result := 0;
    Exit;
  end;

  Result := -1;
end;

// =======================================================================
// critter_pc_reset_name
// 0x427A80
// =======================================================================
procedure critter_pc_reset_name; cdecl;
begin
  StrLCopy(@pc_name[0], 'None', DUDE_NAME_MAX_LENGTH);
end;

// =======================================================================
// critter_get_hits
// 0x427A9C
// =======================================================================
function critter_get_hits(critter: PObject): Integer; cdecl;
begin
  Result := critter^.Data.AsData.Critter.Hp;
end;

// =======================================================================
// critter_adjust_hits
// 0x427AA0
// =======================================================================
function critter_adjust_hits(critter: PObject; amount: Integer): Integer; cdecl;
var
  maximumHp: Integer;
  newHp: Integer;
begin
  maximumHp := stat_level(critter, Ord(STAT_MAXIMUM_HIT_POINTS));
  newHp := critter^.Data.AsData.Critter.Hp + amount;

  critter^.Data.AsData.Critter.Hp := newHp;
  if maximumHp >= newHp then
  begin
    if (newHp <= 0) and ((critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
    begin
      critter_kill(critter, -1, True);
    end;
  end
  else
  begin
    critter^.Data.AsData.Critter.Hp := maximumHp;
  end;

  Result := 0;
end;

// =======================================================================
// critter_get_poison
// 0x427AE8
// =======================================================================
function critter_get_poison(critter: PObject): Integer; cdecl;
begin
  Result := critter^.Data.AsData.Critter.Poison;
end;

// =======================================================================
// critter_adjust_poison
// 0x427AEC
// =======================================================================
function critter_adjust_poison(critter: PObject; amount: Integer): Integer; cdecl;
var
  messageListItem: TMessageListItem;
begin
  if critter <> obj_dude then
  begin
    Result := -1;
    Exit;
  end;

  if amount > 0 then
  begin
    // Take poison resistance into account.
    amount := amount - amount * stat_level(critter, Ord(STAT_POISON_RESISTANCE)) div 100;
  end;

  critter^.Data.AsData.Critter.Poison := critter^.Data.AsData.Critter.Poison + amount;
  if critter^.Data.AsData.Critter.Poison > 0 then
  begin
    queue_clear_type(EVENT_TYPE_POISON, nil);
    queue_add(10 * (505 - 5 * critter^.Data.AsData.Critter.Poison), obj_dude, nil, EVENT_TYPE_POISON);

    // You have been poisoned!
    messageListItem.num := 3000;
    if message_search(@misc_message_file, @messageListItem) then
    begin
      display_print(messageListItem.text);
    end;
  end
  else
  begin
    critter^.Data.AsData.Critter.Poison := 0;
  end;

  Result := 0;
end;

// =======================================================================
// critter_check_poison
// 0x427BAC
// =======================================================================
function critter_check_poison(obj: PObject; data: Pointer): Integer; cdecl;
var
  messageListItem: TMessageListItem;
begin
  if obj <> obj_dude then
  begin
    Result := 0;
    Exit;
  end;

  critter_adjust_poison(obj, -2);
  critter_adjust_hits(obj, -1);

  intface_update_hit_points(False);

  // You take damage from poison.
  messageListItem.num := 3001;
  if message_search(@misc_message_file, @messageListItem) then
  begin
    display_print(messageListItem.text);
  end;

  // NOTE: Uninline.
  if critter_get_hits(obj) > 5 then
  begin
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

// =======================================================================
// critter_get_rads
// 0x427C14
// =======================================================================
function critter_get_rads(obj: PObject): Integer; cdecl;
begin
  Result := obj^.Data.AsData.Critter.Radiation;
end;

// =======================================================================
// critter_adjust_rads
// 0x427C18
// =======================================================================
function critter_adjust_rads(obj: PObject; amount: Integer): Integer; cdecl;
var
  messageListItem: TMessageListItem;
  proto: PProto;
  item: PObject;
  geiger_counter: PObject;
begin
  if obj <> obj_dude then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj_dude^.Pid, @proto);

  if amount > 0 then
  begin
    amount := amount - stat_level(obj, Ord(STAT_RADIATION_RESISTANCE)) * amount div 100;
  end;

  if amount > 0 then
  begin
    proto^.Critter.Data.Flags := proto^.Critter.Data.Flags or CRITTER_BARTER;
  end;

  if amount > 0 then
  begin
    geiger_counter := nil;

    item := inven_left_hand(obj_dude);
    if item <> nil then
    begin
      if (item^.Pid = PROTO_ID_GEIGER_COUNTER_I) or (item^.Pid = PROTO_ID_GEIGER_COUNTER_II) then
      begin
        geiger_counter := item;
      end;
    end;

    item := inven_right_hand(obj_dude);
    if item <> nil then
    begin
      if (item^.Pid = PROTO_ID_GEIGER_COUNTER_I) or (item^.Pid = PROTO_ID_GEIGER_COUNTER_II) then
      begin
        geiger_counter := item;
      end;
    end;

    if geiger_counter <> nil then
    begin
      if item_m_on(geiger_counter) then
      begin
        if amount > 5 then
        begin
          // The geiger counter is clicking wildly.
          messageListItem.num := 1009;
        end
        else
        begin
          // The geiger counter is clicking.
          messageListItem.num := 1008;
        end;

        if message_search(@misc_message_file, @messageListItem) then
        begin
          display_print(messageListItem.text);
        end;
      end;
    end;
  end;

  if amount >= 10 then
  begin
    // You have received a large dose of radiation.
    messageListItem.num := 1007;

    if message_search(@misc_message_file, @messageListItem) then
    begin
      display_print(messageListItem.text);
    end;
  end;

  obj^.Data.AsData.Critter.Radiation := obj^.Data.AsData.Critter.Radiation + amount;
  if obj^.Data.AsData.Critter.Radiation < 0 then
  begin
    obj^.Data.AsData.Critter.Radiation := 0;
  end;

  Result := 0;
end;

// =======================================================================
// critter_check_rads
// 0x427D58
// =======================================================================
function critter_check_rads(obj: PObject): Integer; cdecl;
var
  proto: PProto;
  radiation: Integer;
  radiation_level: Integer;
  radiationEvent: PRadiationEvent;
begin
  if obj <> obj_dude then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(obj^.Pid, @proto);
  if (proto^.Critter.Data.Flags and CRITTER_BARTER) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  old_rad_level := 0;

  queue_clear_type(EVENT_TYPE_RADIATION, @get_rad_damage_level);

  // NOTE: Uninline
  radiation := critter_get_rads(obj);

  if radiation > 999 then
    radiation_level := RADIATION_LEVEL_FATAL
  else if radiation > 599 then
    radiation_level := RADIATION_LEVEL_DEADLY
  else if radiation > 399 then
    radiation_level := RADIATION_LEVEL_CRITICAL
  else if radiation > 199 then
    radiation_level := RADIATION_LEVEL_ADVANCED
  else if radiation > 99 then
    radiation_level := RADIATION_LEVEL_MINOR
  else
    radiation_level := RADIATION_LEVEL_NONE;

  if stat_result(obj, Ord(STAT_ENDURANCE), check_rads_bonus[radiation_level], nil) <= ROLL_FAILURE then
  begin
    radiation_level := radiation_level + 1;
  end;

  if radiation_level > old_rad_level then
  begin
    // Create timer event for applying radiation damage.
    radiationEvent := PRadiationEvent(mem_malloc(SizeOf(TRadiationEvent)));
    if radiationEvent = nil then
    begin
      Result := 0;
      Exit;
    end;

    radiationEvent^.radiationLevel := radiation_level;
    radiationEvent^.isHealing := 0;
    queue_add(GAME_TIME_TICKS_PER_HOUR * roll_random(4, 18), obj, radiationEvent, EVENT_TYPE_RADIATION);
  end;

  proto^.Critter.Data.Flags := proto^.Critter.Data.Flags and (not CRITTER_BARTER);

  Result := 0;
end;

// =======================================================================
// get_rad_damage_level (static)
// 0x427E6C
// =======================================================================
function get_rad_damage_level(obj: PObject; data: Pointer): Integer; cdecl;
var
  radiationEvent: PRadiationEvent;
begin
  radiationEvent := PRadiationEvent(data);

  old_rad_level := radiationEvent^.radiationLevel;

  Result := 0;
end;

// =======================================================================
// clear_rad_damage (static)
// 0x427E78
// =======================================================================
function clear_rad_damage(obj: PObject; data: Pointer): Integer; cdecl;
var
  radiationEvent: PRadiationEvent;
begin
  radiationEvent := PRadiationEvent(data);

  if radiationEvent^.isHealing <> 0 then
  begin
    process_rads(obj, radiationEvent^.radiationLevel, True);
  end;

  Result := 1;
end;

// =======================================================================
// process_rads (static)
// Applies radiation.
// 0x427E90
// =======================================================================
procedure process_rads(obj: PObject; radiationLevel: Integer; isHealing: Boolean);
var
  messageListItem: TMessageListItem;
  radiationLevelIndex: Integer;
  modifier: Integer;
  effect: Integer;
  value: Integer;
  base: Integer;
  bonus_val: Integer;
begin
  if radiationLevel = RADIATION_LEVEL_NONE then
    Exit;

  radiationLevelIndex := radiationLevel - 1;
  if isHealing then
    modifier := -1
  else
    modifier := 1;

  if obj = obj_dude then
  begin
    // Radiation level message, higher is worse.
    messageListItem.num := 1000 + radiationLevelIndex;
    if message_search(@misc_message_file, @messageListItem) then
    begin
      display_print(messageListItem.text);
    end;
  end;

  for effect := 0 to RADIATION_EFFECT_COUNT - 1 do
  begin
    value := stat_get_bonus(obj, rad_stat[effect]);
    value := value + modifier * rad_bonus[radiationLevelIndex][effect];
    stat_set_bonus(obj, rad_stat[effect], value);
  end;

  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
  begin
    // Loop thru effects affecting primary stats. If any of the primary stat
    // dropped below minimal value, kill it.
    for effect := 0 to RADIATION_EFFECT_PRIMARY_STAT_COUNT - 1 do
    begin
      base := stat_get_base(obj, rad_stat[effect]);
      bonus_val := stat_get_bonus(obj, rad_stat[effect]);
      if base + bonus_val < PRIMARY_STAT_MIN then
      begin
        critter_kill(obj, -1, True);
        Break;
      end;
    end;
  end;

  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    if obj = obj_dude then
    begin
      // You have died from radiation sickness.
      messageListItem.num := 1006;
      if message_search(@misc_message_file, @messageListItem) then
      begin
        display_print(messageListItem.text);
      end;
    end;
  end;
end;

// =======================================================================
// critter_process_rads
// 0x427F94
// =======================================================================
function critter_process_rads(obj: PObject; data: Pointer): Integer; cdecl;
var
  radiationEvent: PRadiationEvent;
  newRadiationEvent: PRadiationEvent;
begin
  radiationEvent := PRadiationEvent(data);
  if radiationEvent^.isHealing = 0 then
  begin
    // Schedule healing stats event in 7 days.
    newRadiationEvent := PRadiationEvent(mem_malloc(SizeOf(TRadiationEvent)));
    if newRadiationEvent <> nil then
    begin
      queue_clear_type(EVENT_TYPE_RADIATION, @clear_rad_damage);
      newRadiationEvent^.radiationLevel := radiationEvent^.radiationLevel;
      newRadiationEvent^.isHealing := 1;
      queue_add(GAME_TIME_TICKS_PER_DAY * 7, obj, newRadiationEvent, EVENT_TYPE_RADIATION);
    end;
  end;

  process_rads(obj, radiationEvent^.radiationLevel, radiationEvent^.isHealing <> 0);

  Result := 1;
end;

// =======================================================================
// critter_load_rads
// 0x427FF4
// =======================================================================
function critter_load_rads(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
var
  radiationEvent: PRadiationEvent;
begin
  radiationEvent := PRadiationEvent(mem_malloc(SizeOf(TRadiationEvent)));
  if radiationEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @(radiationEvent^.radiationLevel)) = -1 then
  begin
    mem_free(radiationEvent);
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @(radiationEvent^.isHealing)) = -1 then
  begin
    mem_free(radiationEvent);
    Result := -1;
    Exit;
  end;

  dataPtr^ := radiationEvent;
  Result := 0;
end;

// =======================================================================
// critter_save_rads
// 0x428050
// =======================================================================
function critter_save_rads(stream: PDB_FILE; data: Pointer): Integer; cdecl;
var
  radiationEvent: PRadiationEvent;
begin
  radiationEvent := PRadiationEvent(data);

  if db_fwriteInt(stream, radiationEvent^.radiationLevel) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwriteInt(stream, radiationEvent^.isHealing) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// critter_kill_count_clear (static)
// 0x428080
// =======================================================================
function critter_kill_count_clear: Integer;
begin
  FillChar(pc_kill_counts, SizeOf(pc_kill_counts), 0);
  Result := 0;
end;

// =======================================================================
// critter_kill_count_inc
// 0x428098
// =======================================================================
function critter_kill_count_inc(critter_type: Integer): Integer; cdecl;
begin
  if critter_type = -1 then
  begin
    Result := -1;
    Exit;
  end;

  pc_kill_counts[critter_type] := pc_kill_counts[critter_type] + 1;
  Result := 0;
end;

// =======================================================================
// critter_kill_count
// 0x4280B8
// =======================================================================
function critter_kill_count(critter_type: Integer): Integer; cdecl;
begin
  Result := pc_kill_counts[critter_type];
end;

// =======================================================================
// critter_kill_count_load
// 0x4280C0
// =======================================================================
function critter_kill_count_load(stream: PDB_FILE): Integer;
begin
  if db_freadIntCount(stream, @pc_kill_counts[0], KILL_TYPE_COUNT) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// critter_kill_count_save
// 0x4280F0
// =======================================================================
function critter_kill_count_save(stream: PDB_FILE): Integer;
begin
  if db_fwriteIntCount(stream, @pc_kill_counts[0], KILL_TYPE_COUNT) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// critter_kill_count_type
// 0x428120
// =======================================================================
function critter_kill_count_type(obj: PObject): Integer; cdecl;
var
  proto: PProto;
begin
  if obj = obj_dude then
  begin
    if stat_level(obj, Ord(STAT_GENDER)) = GENDER_FEMALE then
    begin
      Result := KILL_TYPE_WOMAN;
      Exit;
    end;
    Result := KILL_TYPE_MAN;
    Exit;
  end;

  if PID_TYPE(obj^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj^.Pid, @proto);

  Result := proto^.Critter.Data.KillType;
end;

// =======================================================================
// critter_kill_name
// 0x428174
// =======================================================================
function critter_kill_name(critter_type: Integer): PAnsiChar; cdecl;
var
  messageListItem: TMessageListItem;
begin
  if (critter_type >= 0) and (critter_type < KILL_TYPE_COUNT) then
  begin
    Result := getmsg(@proto_main_msg_file, @messageListItem, 450 + critter_type);
  end
  else
  begin
    Result := nil;
  end;
end;

// =======================================================================
// critter_kill_info
// 0x4281A0
// =======================================================================
function critter_kill_info(critter_type: Integer): PAnsiChar; cdecl;
var
  messageListItem: TMessageListItem;
begin
  if (critter_type >= 0) and (critter_type < KILL_TYPE_COUNT) then
  begin
    Result := getmsg(@proto_main_msg_file, @messageListItem, 465 + critter_type);
  end
  else
  begin
    Result := nil;
  end;
end;

// =======================================================================
// critter_heal_hours
// 0x4281CC
// =======================================================================
function critter_heal_hours(critter: PObject; hours: Integer): Integer; cdecl;
begin
  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := -1;
    Exit;
  end;

  if critter^.Data.AsData.Critter.Hp < stat_level(critter, Ord(STAT_MAXIMUM_HIT_POINTS)) then
  begin
    critter_adjust_hits(critter, 14 * (hours div 3));
  end;

  Result := 0;
end;

// =======================================================================
// critter_kill
// 0x428220
// =======================================================================
procedure critter_kill(critter: PObject; anim: Integer; refresh_window: Boolean); cdecl;
var
  elevation: Integer;
  shouldChangeFid: Boolean;
  fid: Integer;
  current: Integer;
  back: Boolean;
  updatedRect: TRect;
  tempRect: TRect;
begin
  elevation := critter^.Elevation;

  partyMemberRemove(critter);

  // NOTE: Original code uses goto to jump out from nested conditions below.
  shouldChangeFid := False;
  fid := 0;
  if critter_is_prone(critter) then
  begin
    current := FID_ANIM_TYPE(critter^.Fid);
    if (current = ANIM_FALL_BACK) or (current = ANIM_FALL_FRONT) then
    begin
      back := False;
      if current = ANIM_FALL_BACK then
      begin
        back := True;
      end
      else
      begin
        fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_FALL_FRONT_SF, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
        if not art_exists(fid) then
        begin
          back := True;
        end;
      end;

      if back then
      begin
        fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_FALL_BACK_SF, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
      end;

      shouldChangeFid := True;
    end;
  end
  else
  begin
    if anim < 0 then
    begin
      anim := LAST_SF_DEATH_ANIM;
    end;

    if anim > LAST_SF_DEATH_ANIM then
    begin
      debug_printf(PAnsiChar(#10'Error: Critter Kill: death_frame out of range!'));
      anim := LAST_SF_DEATH_ANIM;
    end;

    fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, anim, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
    obj_fix_violence_settings(@fid);
    if not art_exists(fid) then
    begin
      debug_printf(PAnsiChar(#10'Error: Critter Kill: Can''t match fid!'));

      fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_FALL_BACK_BLOOD_SF, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
      obj_fix_violence_settings(@fid);
    end;

    shouldChangeFid := True;
  end;

  if shouldChangeFid then
  begin
    obj_set_frame(critter, 0, @updatedRect);

    obj_change_fid(critter, fid, @tempRect);
    rect_min_bound(@updatedRect, @tempRect, @updatedRect);
  end;

  if (critter^.Pid <> 16777265) and (critter^.Pid <> 16777266) and (critter^.Pid <> 16777224) then
  begin
    critter^.Flags := critter^.Flags or OBJECT_NO_BLOCK;
    if (critter^.Flags and OBJECT_FLAT) = 0 then
    begin
      obj_toggle_flat(critter, @tempRect);
    end;
  end;

  // NOTE: using uninitialized updatedRect/tempRect if fid was not set.

  rect_min_bound(@updatedRect, @tempRect, @updatedRect);

  obj_turn_off_light(critter, @tempRect);
  rect_min_bound(@updatedRect, @tempRect, @updatedRect);

  critter^.Data.AsData.Critter.Hp := 0;
  critter^.Data.AsData.Critter.Combat.Results := critter^.Data.AsData.Critter.Combat.Results or DAM_DEAD;

  if critter^.Sid <> -1 then
  begin
    scr_remove(critter^.Sid);
    critter^.Sid := -1;
  end;

  if refresh_window then
  begin
    tile_refresh_rect(@updatedRect, elevation);
  end;

  if critter = obj_dude then
  begin
    game_user_wants_to_quit := 2;
  end;
end;

// =======================================================================
// critter_kill_exps
// 0x42844C
// =======================================================================
function critter_kill_exps(critter: PObject): Integer; cdecl;
var
  proto: PProto;
begin
  proto_ptr(critter^.Pid, @proto);
  Result := proto^.Critter.Data.Experience;
end;

// =======================================================================
// critter_is_active
// 0x428470
// =======================================================================
function critter_is_active(critter: PObject): Boolean; cdecl;
begin
  if critter = nil then
  begin
    Result := False;
    Exit;
  end;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := False;
    Exit;
  end;

  if (critter^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD)) <> 0 then
  begin
    Result := False;
    Exit;
  end;

  if (critter^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD or DAM_LOSE_TURN)) <> 0 then
  begin
    Result := False;
    Exit;
  end;

  Result := (critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0;
end;

// =======================================================================
// critter_is_dead
// 0x4284AC
// =======================================================================
function critter_is_dead(critter: PObject): Boolean; cdecl;
begin
  if critter = nil then
  begin
    Result := False;
    Exit;
  end;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := False;
    Exit;
  end;

  if stat_level(critter, Ord(STAT_CURRENT_HIT_POINTS)) <= 0 then
  begin
    Result := True;
    Exit;
  end;

  if (critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    Result := True;
    Exit;
  end;

  Result := False;
end;

// =======================================================================
// critter_is_crippled
// 0x4284EC
// =======================================================================
function critter_is_crippled(critter: PObject): Boolean; cdecl;
begin
  if critter = nil then
  begin
    Result := False;
    Exit;
  end;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := False;
    Exit;
  end;

  Result := (critter^.Data.AsData.Critter.Combat.Results and DAM_CRIP) <> 0;
end;

// =======================================================================
// critter_is_prone
// 0x428514
// =======================================================================
function critter_is_prone(critter: PObject): Boolean; cdecl;
var
  animType: Integer;
begin
  if critter = nil then
  begin
    Result := False;
    Exit;
  end;

  if PID_TYPE(critter^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := False;
    Exit;
  end;

  animType := FID_ANIM_TYPE(critter^.Fid);

  Result := ((critter^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) <> 0)
    or ((animType >= FIRST_KNOCKDOWN_AND_DEATH_ANIM) and (animType <= LAST_KNOCKDOWN_AND_DEATH_ANIM))
    or ((animType >= FIRST_SF_DEATH_ANIM) and (animType <= LAST_SF_DEATH_ANIM));
end;

// =======================================================================
// critter_body_type
// 0x428558
// =======================================================================
function critter_body_type(critter: PObject): Integer; cdecl;
var
  proto: PProto;
begin
  proto_ptr(critter^.Pid, @proto);
  Result := proto^.Critter.Data.BodyType;
end;

// =======================================================================
// critter_load_data
// 0x42857C
// =======================================================================
function critter_load_data(critterData: PCritterProtoData; path: PAnsiChar): Integer; cdecl;
var
  stream: PDB_FILE;
begin
  stream := db_fopen(path, 'rb');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  if critter_read_data(stream, critterData) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fclose(stream);
  Result := 0;
end;

// =======================================================================
// pc_load_data
// 0x4285C4
// =======================================================================
function pc_load_data(path: PAnsiChar): Integer; cdecl;
var
  stream: PDB_FILE;
  proto: PProto;
begin
  stream := db_fopen(path, 'rb');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj_dude^.Pid, @proto);

  if critter_read_data(stream, @(proto^.Critter.Data)) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fread(@pc_name[0], DUDE_NAME_MAX_LENGTH, 1, stream);

  if skill_load(stream) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if trait_load(stream) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @character_points) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  proto^.Critter.Data.BaseStats[Ord(STAT_DAMAGE_RESISTANCE_EMP)] := 100;
  proto^.Critter.Data.BodyType := 0;
  proto^.Critter.Data.Experience := 0;
  proto^.Critter.Data.KillType := 0;

  db_fclose(stream);
  Result := 0;
end;

// =======================================================================
// critter_read_data
// 0x4286DC
// =======================================================================
function critter_read_data(stream: PDB_FILE; critterData: PCritterProtoData): Integer; cdecl;
begin
  if db_freadInt(stream, @(critterData^.Flags)) = -1 then begin Result := -1; Exit; end;
  if db_freadIntCount(stream, @(critterData^.BaseStats[0]), SAVEABLE_STAT_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_freadIntCount(stream, @(critterData^.BonusStats[0]), SAVEABLE_STAT_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_freadIntCount(stream, @(critterData^.Skills[0]), SKILL_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @(critterData^.BodyType)) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @(critterData^.Experience)) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @(critterData^.KillType)) = -1 then begin Result := -1; Exit; end;

  Result := 0;
end;

// =======================================================================
// critter_save_data
// 0x42878C
// =======================================================================
function critter_save_data(critterData: PCritterProtoData; path: PAnsiChar): Integer; cdecl;
var
  stream: PDB_FILE;
begin
  stream := db_fopen(path, 'wb');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  if critter_write_data(stream, critterData) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fclose(stream);
  Result := 0;
end;

// =======================================================================
// pc_save_data
// 0x4287D4
// =======================================================================
function pc_save_data(path: PAnsiChar): Integer; cdecl;
var
  stream: PDB_FILE;
  proto: PProto;
begin
  stream := db_fopen(path, 'wb');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(obj_dude^.Pid, @proto);

  if critter_write_data(stream, @(proto^.Critter.Data)) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fwrite(@pc_name[0], DUDE_NAME_MAX_LENGTH, 1, stream);

  if skill_save(stream) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if trait_save(stream) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  if db_fwriteInt(stream, character_points) = -1 then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fclose(stream);
  Result := 0;
end;

// =======================================================================
// critter_write_data
// 0x4288BC
// =======================================================================
function critter_write_data(stream: PDB_FILE; critterData: PCritterProtoData): Integer; cdecl;
begin
  if db_fwriteInt(stream, critterData^.Flags) = -1 then begin Result := -1; Exit; end;
  if db_fwriteIntCount(stream, @(critterData^.BaseStats[0]), SAVEABLE_STAT_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_fwriteIntCount(stream, @(critterData^.BonusStats[0]), SAVEABLE_STAT_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_fwriteIntCount(stream, @(critterData^.Skills[0]), SKILL_COUNT) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, critterData^.BodyType) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, critterData^.Experience) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, critterData^.KillType) = -1 then begin Result := -1; Exit; end;

  Result := 0;
end;

// =======================================================================
// pc_flag_off
// 0x42895C
// =======================================================================
procedure pc_flag_off(pc_flag: Integer); cdecl;
var
  proto: PProto;
begin
  proto_ptr(obj_dude^.Pid, @proto);

  proto^.Critter.Data.Flags := proto^.Critter.Data.Flags and (not (1 shl pc_flag));

  if pc_flag = PC_FLAG_SNEAKING then
  begin
    queue_remove_this(obj_dude, EVENT_TYPE_SNEAK);
  end;

  refresh_box_bar_win();
end;

// =======================================================================
// pc_flag_on
// 0x4289A8
// =======================================================================
procedure pc_flag_on(pc_flag: Integer); cdecl;
var
  proto: PProto;
begin
  proto_ptr(obj_dude^.Pid, @proto);

  proto^.Critter.Data.Flags := proto^.Critter.Data.Flags or (1 shl pc_flag);

  if pc_flag = PC_FLAG_SNEAKING then
  begin
    critter_sneak_check(nil, nil);
  end;

  refresh_box_bar_win();
end;

// =======================================================================
// pc_flag_toggle
// 0x428A1C
// =======================================================================
procedure pc_flag_toggle(pc_flag: Integer); cdecl;
begin
  // NOTE: Uninline.
  if is_pc_flag(pc_flag) then
  begin
    pc_flag_off(pc_flag);
  end
  else
  begin
    pc_flag_on(pc_flag);
  end;
end;

// =======================================================================
// is_pc_flag
// 0x428A64
// =======================================================================
function is_pc_flag(pc_flag: Integer): Boolean; cdecl;
var
  proto: PProto;
begin
  proto_ptr(obj_dude^.Pid, @proto);
  Result := (proto^.Critter.Data.Flags and (1 shl pc_flag)) <> 0;
end;

// =======================================================================
// critter_sneak_check
// 0x428A98
// =======================================================================
function critter_sneak_check(obj: PObject; data: Pointer): Integer; cdecl;
begin
  if skill_result(obj_dude, SKILL_SNEAK, 0, nil) >= ROLL_SUCCESS then
    sneak_working := 1
  else
    sneak_working := 0;
  queue_add(600, obj_dude, nil, EVENT_TYPE_SNEAK);
  Result := 0;
end;

// =======================================================================
// critter_sneak_clear
// 0x428ADC
// =======================================================================
function critter_sneak_clear(obj: PObject; data: Pointer): Integer; cdecl;
begin
  pc_flag_off(PC_FLAG_SNEAKING);
  Result := 1;
end;

// =======================================================================
// is_pc_sneak_working
// Returns true if dude is really sneaking.
// 0x428AEC
// =======================================================================
function is_pc_sneak_working: Boolean; cdecl;
begin
  // NOTE: Uninline.
  if is_pc_flag(PC_FLAG_SNEAKING) then
  begin
    Result := sneak_working <> 0;
    Exit;
  end;

  Result := False;
end;

// =======================================================================
// critter_wake_up
// 0x428B1C
// =======================================================================
function critter_wake_up(obj: PObject; data: Pointer): Integer; cdecl;
begin
  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    Result := 0;
    Exit;
  end;

  obj^.Data.AsData.Critter.Combat.Results := obj^.Data.AsData.Critter.Combat.Results and (not (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN));
  obj^.Data.AsData.Critter.Combat.Results := obj^.Data.AsData.Critter.Combat.Results or DAM_KNOCKED_DOWN;

  if isInCombat() then
  begin
    obj^.Data.AsData.Critter.Combat.Maneuver := obj^.Data.AsData.Critter.Combat.Maneuver or CRITTER_MANEUVER_ENGAGING;
  end
  else
  begin
    dude_standup(obj);
  end;

  Result := 0;
end;

// =======================================================================
// critter_wake_clear
// 0x428B58
// =======================================================================
function critter_wake_clear(obj: PObject; data: Pointer): Integer; cdecl;
var
  fid: Integer;
begin
  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
  begin
    Result := 0;
    Exit;
  end;

  obj^.Data.AsData.Critter.Combat.Results := obj^.Data.AsData.Critter.Combat.Results and (not (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN));

  fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_STAND, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  obj_change_fid(obj, fid, nil);

  Result := 0;
end;

// =======================================================================
// critter_set_who_hit_me
// 0x428BB0
// =======================================================================
function critter_set_who_hit_me(critter: PObject; who_hit_me: PObject): Integer; cdecl;
begin
  if (who_hit_me <> nil) and (FID_TYPE(who_hit_me^.Fid) <> OBJ_TYPE_CRITTER) then
  begin
    Result := -1;
    Exit;
  end;

  critter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := who_hit_me;

  if who_hit_me = obj_dude then
  begin
    reaction_set(critter, 1);
  end;

  Result := 0;
end;

// =======================================================================
// critter_can_obj_dude_rest
// 0x428C1C
// =======================================================================
function critter_can_obj_dude_rest: Boolean; cdecl;
var
  map_idx: Integer;
  check_team: Integer;
  can_rest: Integer;
  critters: PPObject;
  critters_count: Integer;
  index: Integer;
  aCritter: PObject;
begin
  map_idx := map_get_index_number();
  check_team := 1; // default

  case map_idx of
    MAP_HUBOLDTN,
    MAP_HUBHEIGT,
    MAP_LARIPPER,
    MAP_LAGUNRUN,
    MAP_V13ENT:
      check_team := 1;
    MAP_CHILDRN1:
      check_team := 0;
  else
    begin
      if (map_idx = MAP_HALLDED) and (map_elevation <> 0) then
      begin
        check_team := 0;
      end
      else
      begin
        case xlate_mapidx_to_town(map_idx) of
          TOWN_VAULT_13,
          TOWN_SHADY_SANDS,
          TOWN_JUNKTOWN,
          TOWN_THE_HUB,
          TOWN_BROTHERHOOD,
          TOWN_BONEYARD:
            check_team := 0;
        else
          check_team := 1;
        end;
      end;
    end;
  end;

  can_rest := 1;

  critters_count := obj_create_list(-1, map_elevation, OBJ_TYPE_CRITTER, @critters);
  index := 0;
  while index < critters_count do
  begin
    aCritter := PPObject(PByte(critters) + index * SizeOf(PObject))^;
    if (aCritter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
    begin
      if aCritter <> obj_dude then
      begin
        if aCritter^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe = obj_dude then
        begin
          can_rest := 0;
          Break;
        end;

        if check_team <> 0 then
        begin
          if aCritter^.Data.AsData.Critter.Combat.Team <> obj_dude^.Data.AsData.Critter.Combat.Team then
          begin
            can_rest := 0;
            Break;
          end;
        end;
      end;
    end;
    Inc(index);
  end;

  if critters_count <> 0 then
  begin
    obj_delete_list(critters);
  end;

  Result := can_rest <> 0;
end;

// =======================================================================
// critter_compute_ap_from_distance
// 0x428D28
// =======================================================================
function critter_compute_ap_from_distance(critter: PObject; distance: Integer): Integer; cdecl;
var
  flags: Integer;
begin
  flags := critter^.Data.AsData.Critter.Combat.Results;
  if ((flags and DAM_CRIP_LEG_LEFT) <> 0) and ((flags and DAM_CRIP_LEG_RIGHT) <> 0) then
  begin
    Result := 8 * distance;
  end
  else if (flags and DAM_CRIP_LEG_ANY) <> 0 then
  begin
    Result := 4 * distance;
  end
  else
  begin
    Result := distance;
  end;
end;

// =======================================================================
// Initialization
// =======================================================================

procedure InitRadData;
begin
  // rad_stat
  rad_stat[0] := Ord(STAT_STRENGTH);
  rad_stat[1] := Ord(STAT_PERCEPTION);
  rad_stat[2] := Ord(STAT_ENDURANCE);
  rad_stat[3] := Ord(STAT_CHARISMA);
  rad_stat[4] := Ord(STAT_INTELLIGENCE);
  rad_stat[5] := Ord(STAT_AGILITY);
  rad_stat[6] := Ord(STAT_CURRENT_HIT_POINTS);
  rad_stat[7] := Ord(STAT_HEALING_RATE);

  // rad_bonus
  // RADIATION_LEVEL_NONE
  rad_bonus[0][0] :=  0; rad_bonus[0][1] :=  0; rad_bonus[0][2] :=  0; rad_bonus[0][3] :=  0;
  rad_bonus[0][4] :=  0; rad_bonus[0][5] :=  0; rad_bonus[0][6] :=  0; rad_bonus[0][7] :=  0;
  // RADIATION_LEVEL_MINOR
  rad_bonus[1][0] := -1; rad_bonus[1][1] :=  0; rad_bonus[1][2] :=  0; rad_bonus[1][3] :=  0;
  rad_bonus[1][4] :=  0; rad_bonus[1][5] :=  0; rad_bonus[1][6] :=  0; rad_bonus[1][7] :=  0;
  // RADIATION_LEVEL_ADVANCED
  rad_bonus[2][0] := -1; rad_bonus[2][1] :=  0; rad_bonus[2][2] :=  0; rad_bonus[2][3] :=  0;
  rad_bonus[2][4] :=  0; rad_bonus[2][5] := -1; rad_bonus[2][6] :=  0; rad_bonus[2][7] := -3;
  // RADIATION_LEVEL_CRITICAL
  rad_bonus[3][0] := -2; rad_bonus[3][1] :=  0; rad_bonus[3][2] := -1; rad_bonus[3][3] :=  0;
  rad_bonus[3][4] :=  0; rad_bonus[3][5] := -2; rad_bonus[3][6] := -5; rad_bonus[3][7] := -5;
  // RADIATION_LEVEL_DEADLY
  rad_bonus[4][0] := -4; rad_bonus[4][1] := -3; rad_bonus[4][2] := -3; rad_bonus[4][3] := -3;
  rad_bonus[4][4] := -1; rad_bonus[4][5] := -5; rad_bonus[4][6] :=-15; rad_bonus[4][7] :=-10;
  // RADIATION_LEVEL_FATAL
  rad_bonus[5][0] := -6; rad_bonus[5][1] := -5; rad_bonus[5][2] := -5; rad_bonus[5][3] := -5;
  rad_bonus[5][4] := -3; rad_bonus[5][5] := -6; rad_bonus[5][6] :=-20; rad_bonus[5][7] :=-10;

  // check_rads_bonus (static local in critter_check_rads)
  check_rads_bonus[0] :=  2;
  check_rads_bonus[1] :=  0;
  check_rads_bonus[2] := -2;
  check_rads_bonus[3] := -4;
  check_rads_bonus[4] := -6;
  check_rads_bonus[5] := -8;

  // _name_critter default
  _name_critter := @_aCorpse[0];
end;

initialization
  InitRadData;

end.
