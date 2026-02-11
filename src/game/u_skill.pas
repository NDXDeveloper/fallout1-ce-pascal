unit u_skill;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/skill.h + skill.cc + skill_defs.h
// Skill system: skill levels, tagged skills, skill usage (first aid, doctor, steal, etc.)

interface

uses
  u_db,
  u_object_types,
  u_proto_types,
  u_stat_defs;

const
  // From skill_defs.h
  SKILL_SMALL_GUNS     = 0;
  SKILL_BIG_GUNS       = 1;
  SKILL_ENERGY_WEAPONS = 2;
  SKILL_UNARMED        = 3;
  SKILL_MELEE_WEAPONS  = 4;
  SKILL_THROWING       = 5;
  SKILL_FIRST_AID      = 6;
  SKILL_DOCTOR         = 7;
  SKILL_SNEAK          = 8;
  SKILL_LOCKPICK       = 9;
  SKILL_STEAL          = 10;
  SKILL_TRAPS          = 11;
  SKILL_SCIENCE        = 12;
  SKILL_REPAIR         = 13;
  SKILL_SPEECH         = 14;
  SKILL_BARTER         = 15;
  SKILL_GAMBLING       = 16;
  SKILL_OUTDOORSMAN    = 17;
  SKILL_COUNT          = 18;

  NUM_TAGGED_SKILLS    = 4;
  DEFAULT_TAGGED_SKILLS = 3;

  SKILL_LEVEL_MAX      = 200;

var
  gIsSteal: Integer;
  gStealCount: Integer;
  gStealSize: Integer;

function skill_init: Integer;
procedure skill_reset;
procedure skill_exit;
function skill_load(stream: PDB_FILE): Integer;
function skill_save(stream: PDB_FILE): Integer;
procedure skill_set_defaults(data: PCritterProtoData);
procedure skill_set_tags(skills: PInteger; count: Integer);
procedure skill_get_tags(skills: PInteger; count: Integer);
function skill_level(critter: PObject; skill: Integer): Integer;
function skill_base(skill: Integer): Integer;
function skill_points(obj: PObject; skill: Integer): Integer;
function skill_inc_point(obj: PObject; skill: Integer): Integer;
function skill_dec_point(critter: PObject; skill: Integer): Integer;
function skill_result(critter: PObject; skill: Integer; modifier: Integer; how_much: PInteger): Integer;
function skill_contest(attacker: PObject; defender: PObject; skill: Integer; attackerModifier: Integer; defenderModifier: Integer; howMuch: PInteger): Integer;
function skill_name(skill: Integer): PAnsiChar;
function skill_description(skill: Integer): PAnsiChar;
function skill_attribute(skill: Integer): PAnsiChar;
function skill_pic(skill: Integer): Integer;
function skill_use(obj: PObject; a2: PObject; skill: Integer; criticalChanceModifier: Integer): Integer;
function skill_check_stealing(a1: PObject; a2: PObject; item: PObject; isPlanting: Boolean): Integer;
function skill_use_slot_save(stream: PDB_FILE): Integer;
function skill_use_slot_load(stream: PDB_FILE): Integer;

implementation

uses
  SysUtils, u_message, u_proto, u_roll, u_critter, u_palette, u_display,
  u_debug, u_intface, u_scripts, u_item, u_actions, u_party, u_object,
  u_config, u_gconfig, u_stat, u_perk, u_trait, u_game, u_color;

const
  COMPAT_MAX_PATH = 260;

  SKILLS_MAX_USES_PER_DAY = 3;

  HEALABLE_DAMAGE_FLAGS_LENGTH = 5;

  // From roll.h
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

  // From gconfig.h
  GAME_DIFFICULTY_EASY   = 0;
  GAME_DIFFICULTY_NORMAL = 1;
  GAME_DIFFICULTY_HARD   = 2;

  GAME_CONFIG_PREFERENCES_KEY: PAnsiChar = 'preferences';
  GAME_CONFIG_GAME_DIFFICULTY_KEY: PAnsiChar = 'game_difficulty';

  // From scripts.h / game.h
  GAME_TIME_TICKS_PER_HOUR = 10 * 60 * 60;

  // Healable damage flags (was C++ static local in skill_use/SKILL_DOCTOR)
  healable_damage_flags: array[0..HEALABLE_DAMAGE_FLAGS_LENGTH - 1] of Integer = (
    DAM_BLIND,
    DAM_CRIP_ARM_LEFT,
    DAM_CRIP_ARM_RIGHT,
    DAM_CRIP_LEG_RIGHT,
    DAM_CRIP_LEG_LEFT
  );

type
  TSkillDescription = record
    name: PAnsiChar;
    description: PAnsiChar;
    attributes: PAnsiChar;
    art_num: Integer;
    default_value: Integer;
    stat_modifier: Integer;
    stat1: Integer;
    stat2: Integer;
    points_modifier: Integer;
    experience: Integer;
    field_28: Integer;
  end;

const
  // Perk constants used in this module
  PERK_HEALER     = 19;
  PERK_PICKPOCKET = 37;

var
  skill_data: array[0..SKILL_COUNT - 1] of TSkillDescription = (
    (name: nil; description: nil; attributes: nil; art_num: 28; default_value: 35; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 29; default_value: 10; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 30; default_value: 10; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 31; default_value: 65; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: Ord(STAT_STRENGTH); points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 32; default_value: 55; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: Ord(STAT_STRENGTH); points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 33; default_value: 40; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 34; default_value: 30; stat_modifier: 1; stat1: Ord(STAT_PERCEPTION);  stat2: Ord(STAT_INTELLIGENCE); points_modifier: 1; experience:  25; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 35; default_value: 15; stat_modifier: 1; stat1: Ord(STAT_PERCEPTION);  stat2: Ord(STAT_INTELLIGENCE); points_modifier: 1; experience:  50; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 36; default_value: 25; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 37; default_value: 20; stat_modifier: 1; stat1: Ord(STAT_PERCEPTION);  stat2: Ord(STAT_AGILITY); points_modifier: 1; experience:  25; field_28: 1),
    (name: nil; description: nil; attributes: nil; art_num: 38; default_value: 20; stat_modifier: 1; stat1: Ord(STAT_AGILITY);     stat2: STAT_INVALID; points_modifier: 1; experience:  25; field_28: 1),
    (name: nil; description: nil; attributes: nil; art_num: 39; default_value: 20; stat_modifier: 1; stat1: Ord(STAT_PERCEPTION);  stat2: Ord(STAT_AGILITY); points_modifier: 1; experience:  25; field_28: 1),
    (name: nil; description: nil; attributes: nil; art_num: 40; default_value: 25; stat_modifier: 2; stat1: Ord(STAT_INTELLIGENCE); stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 41; default_value: 20; stat_modifier: 1; stat1: Ord(STAT_INTELLIGENCE); stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 42; default_value: 25; stat_modifier: 2; stat1: Ord(STAT_CHARISMA);    stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 43; default_value: 20; stat_modifier: 2; stat1: Ord(STAT_CHARISMA);    stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 44; default_value: 20; stat_modifier: 3; stat1: Ord(STAT_LUCK);        stat2: STAT_INVALID; points_modifier: 1; experience:   0; field_28: 0),
    (name: nil; description: nil; attributes: nil; art_num: 45; default_value:  5; stat_modifier: 1; stat1: Ord(STAT_ENDURANCE);   stat2: Ord(STAT_INTELLIGENCE); points_modifier: 1; experience: 100; field_28: 0)
  );

  tag_skill: array[0..NUM_TAGGED_SKILLS - 1] of Integer;
  skill_message_file: TMessageList;
  timesSkillUsed: array[0..SKILL_COUNT - 1, 0..SKILLS_MAX_USES_PER_DAY - 1] of Integer;

// Forward declarations for static functions
procedure show_skill_use_messages(obj: PObject; skill: Integer; a3: PObject; a4: Integer; criticalChanceModifier: Integer); forward;
function skill_game_difficulty(skill: Integer): Integer; forward;
function skill_use_slot_available(skill: Integer): Integer; forward;
function skill_use_slot_add(skill: Integer): Integer; forward;
function skill_use_slot_clear: Integer; forward;

// 0x498174
function skill_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  index: Integer;
  mesg: TMessageListItem;
begin
  if not message_init(@skill_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'skill.msg']);

  if not message_load(@skill_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to SKILL_COUNT - 1 do
  begin
    mesg.num := 100 + index;
    if message_search(@skill_message_file, @mesg) then
      skill_data[index].name := mesg.text;

    mesg.num := 200 + index;
    if message_search(@skill_message_file, @mesg) then
      skill_data[index].description := mesg.text;

    mesg.num := 300 + index;
    if message_search(@skill_message_file, @mesg) then
      skill_data[index].attributes := mesg.text;
  end;

  for index := 0 to NUM_TAGGED_SKILLS - 1 do
    tag_skill[index] := -1;

  // NOTE: Uninline.
  skill_use_slot_clear();

  Result := 0;
end;

// 0x4982A4
procedure skill_reset;
var
  index: Integer;
begin
  for index := 0 to NUM_TAGGED_SKILLS - 1 do
    tag_skill[index] := -1;

  // NOTE: Uninline.
  skill_use_slot_clear();
end;

// 0x4982D4
procedure skill_exit;
begin
  message_exit(@skill_message_file);
end;

// 0x4982E4
function skill_load(stream: PDB_FILE): Integer;
begin
  Result := db_freadIntCount(stream, @tag_skill[0], NUM_TAGGED_SKILLS);
end;

// 0x498304
function skill_save(stream: PDB_FILE): Integer;
begin
  Result := db_fwriteIntCount(stream, @tag_skill[0], NUM_TAGGED_SKILLS);
end;

// 0x498324
procedure skill_set_defaults(data: PCritterProtoData);
var
  index: Integer;
begin
  for index := 0 to SKILL_COUNT - 1 do
    data^.Skills[index] := 0;
end;

// 0x498340
procedure skill_set_tags(skills: PInteger; count: Integer);
var
  index: Integer;
  p: PInteger;
begin
  p := skills;
  for index := 0 to count - 1 do
  begin
    tag_skill[index] := p^;
    Inc(p);
  end;
end;

// 0x498364
procedure skill_get_tags(skills: PInteger; count: Integer);
var
  index: Integer;
  p: PInteger;
begin
  p := skills;
  for index := 0 to count - 1 do
  begin
    p^ := tag_skill[index];
    Inc(p);
  end;
end;

// 0x498388
function skill_level(critter: PObject; skill: Integer): Integer;
var
  skill_desc: ^TSkillDescription;
  points: Integer;
  bonus: Integer;
  value: Integer;
begin
  if (skill < 0) or (skill >= SKILL_COUNT) then
  begin
    Result := -5;
    Exit;
  end;

  points := skill_points(critter, skill);
  if points < 0 then
  begin
    Result := points;
    Exit;
  end;

  skill_desc := @skill_data[skill];

  if skill_desc^.stat2 <> -1 then
    bonus := (stat_level(critter, skill_desc^.stat1) + stat_level(critter, skill_desc^.stat2)) * skill_desc^.stat_modifier div 2
  else
    bonus := stat_level(critter, skill_desc^.stat1) * skill_desc^.stat_modifier;

  value := skill_desc^.default_value + bonus + points * skill_desc^.points_modifier;

  if critter = obj_dude then
  begin
    if (skill = tag_skill[0]) or (skill = tag_skill[1]) or (skill = tag_skill[2]) or (skill = tag_skill[3]) then
      value := value + 20 + points * skill_desc^.points_modifier;

    value := value + trait_adjust_skill(skill);
    value := value + perk_adjust_skill(skill);
    value := value + skill_game_difficulty(skill);
  end;

  if value > SKILL_LEVEL_MAX then
    value := SKILL_LEVEL_MAX;

  Result := value;
end;

// 0x49847C
function skill_base(skill: Integer): Integer;
begin
  if (skill >= 0) and (skill < SKILL_COUNT) then
    Result := skill_data[skill].default_value
  else
    Result := -5;
end;

// 0x4984A8
function skill_points(obj: PObject; skill: Integer): Integer;
var
  proto: PProto;
begin
  if (skill < 0) or (skill >= SKILL_COUNT) then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(obj^.Pid, @proto);

  Result := proto^.Critter.Data.Skills[skill];
end;

// 0x4984E4
function skill_inc_point(obj: PObject; skill: Integer): Integer;
var
  proto: PProto;
  unspent_skill_points: Integer;
  level: Integer;
  rc: Integer;
begin
  if obj <> obj_dude then
  begin
    Result := -5;
    Exit;
  end;

  if (skill < 0) or (skill >= SKILL_COUNT) then
  begin
    Result := -5;
    Exit;
  end;

  proto_ptr(obj^.Pid, @proto);

  unspent_skill_points := stat_pc_get(Ord(PC_STAT_UNSPENT_SKILL_POINTS));
  if unspent_skill_points <= 0 then
  begin
    Result := -4;
    Exit;
  end;

  level := skill_level(obj, skill);
  if level >= SKILL_LEVEL_MAX then
  begin
    Result := -3;
    Exit;
  end;

  rc := stat_pc_set(Ord(PC_STAT_UNSPENT_SKILL_POINTS), unspent_skill_points - 1);
  if rc = 0 then
    proto^.Critter.Data.Skills[skill] := proto^.Critter.Data.Skills[skill] + 1;

  Result := rc;
end;

// 0x498588
function skill_dec_point(critter: PObject; skill: Integer): Integer;
var
  proto: PProto;
  unspent_skill_points: Integer;
  rc: Integer;
begin
  if critter <> obj_dude then
  begin
    Result := -5;
    Exit;
  end;

  if (skill < 0) or (skill >= SKILL_COUNT) then
  begin
    Result := -5;
    Exit;
  end;

  proto_ptr(critter^.Pid, @proto);

  if proto^.Critter.Data.Skills[skill] <= 0 then
  begin
    Result := -2;
    Exit;
  end;

  unspent_skill_points := stat_pc_get(Ord(PC_STAT_UNSPENT_SKILL_POINTS));

  rc := stat_pc_set(Ord(PC_STAT_UNSPENT_SKILL_POINTS), unspent_skill_points + 1);
  if rc = 0 then
    proto^.Critter.Data.Skills[skill] := proto^.Critter.Data.Skills[skill] - 1;

  Result := 0;
end;

// 0x498608
function skill_result(critter: PObject; skill: Integer; modifier: Integer; how_much: PInteger): Integer;
var
  level: Integer;
  critical_chance: Integer;
begin
  if (skill < 0) or (skill >= SKILL_COUNT) then
  begin
    Result := ROLL_FAILURE;
    Exit;
  end;

  level := skill_level(critter, skill);
  critical_chance := stat_level(critter, Ord(STAT_CRITICAL_CHANCE));
  Result := roll_check(level + modifier, critical_chance, how_much);
end;

// 0x498640
function skill_contest(attacker: PObject; defender: PObject; skill: Integer; attackerModifier: Integer; defenderModifier: Integer; howMuch: PInteger): Integer;
var
  attackerRoll: Integer;
  attackerHowMuch: Integer;
  defenderRoll: Integer;
  defenderHowMuch: Integer;
begin
  attackerRoll := skill_result(attacker, skill, attackerModifier, @attackerHowMuch);
  if attackerRoll > ROLL_FAILURE then
  begin
    defenderRoll := skill_result(defender, skill, defenderModifier, @defenderHowMuch);
    if defenderRoll > ROLL_FAILURE then
      attackerHowMuch := attackerHowMuch - defenderHowMuch;

    attackerRoll := roll_check_critical(attackerHowMuch, 0);
  end;

  if howMuch <> nil then
    howMuch^ := attackerHowMuch;

  Result := attackerRoll;
end;

// 0x4986A8
function skill_name(skill: Integer): PAnsiChar;
begin
  if (skill >= 0) and (skill < SKILL_COUNT) then
    Result := skill_data[skill].name
  else
    Result := nil;
end;

// 0x4986CC
function skill_description(skill: Integer): PAnsiChar;
begin
  if (skill >= 0) and (skill < SKILL_COUNT) then
    Result := skill_data[skill].description
  else
    Result := nil;
end;

// 0x4986F0
function skill_attribute(skill: Integer): PAnsiChar;
begin
  if (skill >= 0) and (skill < SKILL_COUNT) then
    Result := skill_data[skill].attributes
  else
    Result := nil;
end;

// 0x498714
function skill_pic(skill: Integer): Integer;
begin
  if (skill >= 0) and (skill < SKILL_COUNT) then
    Result := skill_data[skill].art_num
  else
    Result := 0;
end;

// 0x498738
procedure show_skill_use_messages(obj: PObject; skill: Integer; a3: PObject; a4: Integer; criticalChanceModifier: Integer);
var
  skillDescription: ^TSkillDescription;
  baseExperience: Integer;
  xpToAdd: Integer;
  before: Integer;
  after: Integer;
  messageListItem: TMessageListItem;
  text: array[0..59] of AnsiChar;
begin
  if obj <> obj_dude then
    Exit;

  if a4 <= 0 then
    Exit;

  skillDescription := @skill_data[skill];

  baseExperience := skillDescription^.experience;
  if baseExperience = 0 then
    Exit;

  if (skillDescription^.field_28 <> 0) and (criticalChanceModifier < 0) then
    baseExperience := baseExperience + Abs(criticalChanceModifier);

  xpToAdd := a4 * baseExperience;

  before := stat_pc_get(Ord(PC_STAT_EXPERIENCE));

  if (stat_pc_add_experience(xpToAdd) = 0) and (a4 > 0) then
  begin
    messageListItem.num := 505; // You earn %d XP for honing your skills
    if message_search(@skill_message_file, @messageListItem) then
    begin
      after := stat_pc_get(Ord(PC_STAT_EXPERIENCE));
      StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [after - before]);
      display_print(@text[0]);
    end;
  end;
end;

// 0x498814
function skill_use(obj: PObject; a2: PObject; skill: Integer; criticalChanceModifier: Integer): Integer;
var
  messageListItem: TMessageListItem;
  text: array[0..59] of AnsiChar;
  giveExp: Boolean;
  currentHp: Integer;
  maximumHp: Integer;
  hpToHeal: Integer;
  maximumHpToHeal: Integer;
  minimumHpToHeal: Integer;
  criticalChance: Integer;
  damageHealingAttempts: Integer;
  v1: Integer;
  v2: Integer;
  roll: Integer;
  healerRank: Integer;
  skillValue: Integer;
  index: Integer;
  prefix: TMessageListItem;
begin
  giveExp := True;
  currentHp := stat_level(a2, Ord(STAT_CURRENT_HIT_POINTS));
  maximumHp := stat_level(a2, Ord(STAT_MAXIMUM_HIT_POINTS));

  hpToHeal := 0;
  maximumHpToHeal := 0;
  minimumHpToHeal := 0;

  if obj = obj_dude then
  begin
    if (skill = SKILL_FIRST_AID) or (skill = SKILL_DOCTOR) then
    begin
      healerRank := perk_level(PERK_HEALER);
      minimumHpToHeal := 2 * healerRank;
      maximumHpToHeal := 5 * healerRank;
    end;
  end;

  criticalChance := stat_level(obj, Ord(STAT_CRITICAL_CHANCE)) + criticalChanceModifier;

  damageHealingAttempts := 1;
  v1 := 0;
  v2 := 0;

  case skill of
    SKILL_FIRST_AID:
      begin
        if skill_use_slot_available(SKILL_FIRST_AID) = -1 then
        begin
          // 590: You've taxed your ability with that skill. Wait a while.
          // 591: You're too tired.
          // 592: The strain might kill you.
          messageListItem.num := 590 + roll_random(0, 2);
          if message_search(@skill_message_file, @messageListItem) then
            display_print(messageListItem.text);

          Result := -1;
          Exit;
        end;

        if critter_is_dead(a2) then
        begin
          // 512: You can't heal the dead.
          // 513: Let the dead rest in peace.
          // 514: It's dead, get over it.
          messageListItem.num := 512 + roll_random(0, 2);
          if message_search(@skill_message_file, @messageListItem) then
            debug_printf(messageListItem.text);
        end
        else if currentHp < maximumHp then
        begin
          palette_fade_to(@black_palette[0]);

          if critter_body_type(a2) = BODY_TYPE_ROBOTIC then
            roll := ROLL_FAILURE
          else
            roll := skill_result(obj, skill, criticalChance, @hpToHeal);

          if (roll = ROLL_SUCCESS) or (roll = ROLL_CRITICAL_SUCCESS) then
          begin
            hpToHeal := roll_random(minimumHpToHeal + 1, maximumHpToHeal + 5);
            critter_adjust_hits(a2, hpToHeal);

            if obj = obj_dude then
            begin
              // You heal %d hit points.
              messageListItem.num := 500;
              if not message_search(@skill_message_file, @messageListItem) then
              begin
                Result := -1;
                Exit;
              end;

              if maximumHp - currentHp < hpToHeal then
                hpToHeal := maximumHp - currentHp;

              StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [hpToHeal]);
              display_print(@text[0]);
            end;

            skill_use_slot_add(SKILL_FIRST_AID);

            v1 := 1;

            if a2 = obj_dude then
              intface_update_hit_points(True);
          end
          else
          begin
            // You fail to do any healing.
            messageListItem.num := 503;
            if not message_search(@skill_message_file, @messageListItem) then
            begin
              Result := -1;
              Exit;
            end;

            StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [hpToHeal]);
            display_print(@text[0]);
          end;

          scr_exec_map_update_scripts();
          palette_fade_to(@cmap[0]);
        end
        else
        begin
          if obj = obj_dude then
          begin
            // 501: You look healthy already
            // 502: %s looks healthy already
            if a2 = obj_dude then
              messageListItem.num := 501
            else
              messageListItem.num := 502;

            if not message_search(@skill_message_file, @messageListItem) then
            begin
              Result := -1;
              Exit;
            end;

            if a2 = obj_dude then
              StrCopy(@text[0], messageListItem.text)
            else
              StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [object_name(a2)]);

            display_print(@text[0]);
            giveExp := False;
          end;
        end;

        if obj = obj_dude then
          inc_game_time_in_seconds(1800);
      end;

    SKILL_DOCTOR:
      begin
        if skill_use_slot_available(SKILL_DOCTOR) = -1 then
        begin
          // 590: You've taxed your ability with that skill. Wait a while.
          // 591: You're too tired.
          // 592: The strain might kill you.
          messageListItem.num := 590 + roll_random(0, 2);
          if message_search(@skill_message_file, @messageListItem) then
            display_print(messageListItem.text);

          Result := -1;
          Exit;
        end;

        if critter_is_dead(a2) then
        begin
          // 512: You can't heal the dead.
          // 513: Let the dead rest in peace.
          // 514: It's dead, get over it.
          messageListItem.num := 512 + roll_random(0, 2);
          if message_search(@skill_message_file, @messageListItem) then
            display_print(messageListItem.text);
        end
        else if (currentHp < maximumHp) or critter_is_crippled(a2) then
        begin
          palette_fade_to(@black_palette[0]);

          if (critter_body_type(a2) <> BODY_TYPE_ROBOTIC) and critter_is_crippled(a2) then
          begin
            for index := 0 to HEALABLE_DAMAGE_FLAGS_LENGTH - 1 do
            begin
              if (a2^.Data.AsData.Critter.Combat.Results and healable_damage_flags[index]) <> 0 then
              begin
                damageHealingAttempts := damageHealingAttempts + 1;

                roll := skill_result(obj, skill, criticalChance, @hpToHeal);

                // 530: damaged eye
                // 531: crippled left arm
                // 532: crippled right arm
                // 533: crippled right leg
                // 534: crippled left leg
                messageListItem.num := 530 + index;
                if not message_search(@skill_message_file, @messageListItem) then
                begin
                  Result := -1;
                  Exit;
                end;

                if (roll = ROLL_SUCCESS) or (roll = ROLL_CRITICAL_SUCCESS) then
                begin
                  a2^.Data.AsData.Critter.Combat.Results := a2^.Data.AsData.Critter.Combat.Results and (not healable_damage_flags[index]);

                  // 520: You heal your %s.
                  // 521: You heal the %s.
                  if a2 = obj_dude then
                    prefix.num := 520
                  else
                    prefix.num := 521;

                  skill_use_slot_add(SKILL_DOCTOR);

                  v1 := 1;
                  v2 := 1;
                end
                else
                begin
                  // 525: You fail to heal your %s.
                  // 526: You fail to heal the %s.
                  if a2 = obj_dude then
                    prefix.num := 525
                  else
                    prefix.num := 526;
                end;

                if not message_search(@skill_message_file, @prefix) then
                begin
                  Result := -1;
                  Exit;
                end;

                StrLFmt(@text[0], SizeOf(text) - 1, prefix.text, [messageListItem.text]);
                display_print(@text[0]);
                show_skill_use_messages(obj, skill, a2, v1, criticalChanceModifier);

                giveExp := False;
              end;
            end;
          end;

          if critter_body_type(a2) = BODY_TYPE_ROBOTIC then
            roll := ROLL_FAILURE
          else
          begin
            skillValue := skill_level(obj, skill);
            roll := roll_check(skillValue, criticalChance, @hpToHeal);
          end;

          if (roll = ROLL_SUCCESS) or (roll = ROLL_CRITICAL_SUCCESS) then
          begin
            hpToHeal := roll_random(minimumHpToHeal + 4, maximumHpToHeal + 10);
            critter_adjust_hits(a2, hpToHeal);

            if obj = obj_dude then
            begin
              // You heal %d hit points.
              messageListItem.num := 500;
              if not message_search(@skill_message_file, @messageListItem) then
              begin
                Result := -1;
                Exit;
              end;

              if maximumHp - currentHp < hpToHeal then
                hpToHeal := maximumHp - currentHp;

              StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [hpToHeal]);
              display_print(@text[0]);
            end;

            if v2 = 0 then
              skill_use_slot_add(SKILL_DOCTOR);

            if a2 = obj_dude then
              intface_update_hit_points(True);

            v1 := 1;
            show_skill_use_messages(obj, skill, a2, v1, criticalChanceModifier);
            scr_exec_map_update_scripts();
            palette_fade_to(@cmap[0]);

            giveExp := False;
          end
          else
          begin
            // You fail to do any healing.
            messageListItem.num := 503;
            if not message_search(@skill_message_file, @messageListItem) then
            begin
              Result := -1;
              Exit;
            end;

            StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [hpToHeal]);
            display_print(@text[0]);

            scr_exec_map_update_scripts();
            palette_fade_to(@cmap[0]);
          end;
        end
        else
        begin
          if obj = obj_dude then
          begin
            // 501: You look healthy already
            // 502: %s looks healthy already
            if a2 = obj_dude then
              messageListItem.num := 501
            else
              messageListItem.num := 502;

            if not message_search(@skill_message_file, @messageListItem) then
            begin
              Result := -1;
              Exit;
            end;

            if a2 = obj_dude then
              StrCopy(@text[0], messageListItem.text)
            else
              StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [object_name(a2)]);

            display_print(@text[0]);

            giveExp := False;
          end;
        end;

        if obj = obj_dude then
          inc_game_time_in_seconds(3600 * damageHealingAttempts);
      end;

    SKILL_SNEAK,
    SKILL_LOCKPICK:
      begin
        // do nothing
      end;

    SKILL_STEAL:
      begin
        scripts_request_steal_container(obj, a2);
      end;

    SKILL_TRAPS:
      begin
        // You fail to find any traps.
        messageListItem.num := 551;
        if message_search(@skill_message_file, @messageListItem) then
          display_print(messageListItem.text);

        Result := -1;
        Exit;
      end;

    SKILL_SCIENCE:
      begin
        // You fail to learn anything.
        messageListItem.num := 552;
        if message_search(@skill_message_file, @messageListItem) then
          display_print(messageListItem.text);

        Result := -1;
        Exit;
      end;

    SKILL_REPAIR:
      begin
        // You cannot repair that.
        messageListItem.num := 553;
        if message_search(@skill_message_file, @messageListItem) then
          display_print(messageListItem.text);

        Result := -1;
        Exit;
      end;
  else
    begin
      // skill_use: invalid skill used.
      messageListItem.num := 510;
      if message_search(@skill_message_file, @messageListItem) then
        debug_printf(messageListItem.text);

      Result := -1;
      Exit;
    end;
  end;

  if giveExp then
    show_skill_use_messages(obj, skill, a2, v1, criticalChanceModifier);

  if (skill = SKILL_FIRST_AID) or (skill = SKILL_DOCTOR) then
    scr_exec_map_update_scripts();

  Result := 0;
end;

// 0x4991C8
function skill_check_stealing(a1: PObject; a2: PObject; item: PObject; isPlanting: Boolean): Integer;
var
  howMuch: Integer;
  stealModifier: Integer;
  stealChance: Integer;
  stealRoll: Integer;
  catchRoll: Integer;
  catchChance: Integer;
  criticalChance: Integer;
  messageListItem: TMessageListItem;
  text: array[0..59] of AnsiChar;
begin
  stealModifier := 1 - gStealCount;

  if (a1 <> obj_dude) or (perk_level(PERK_PICKPOCKET) = 0) then
  begin
    // -4% per item size
    stealModifier := stealModifier - 4 * item_size(item);

    if FID_TYPE(a2^.Fid) = OBJ_TYPE_CRITTER then
    begin
      // check facing: -25% if face to face
      if is_hit_from_front(a1, a2) then
        stealModifier := stealModifier - 25;
    end;
  end;

  if (a2^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) <> 0 then
    stealModifier := stealModifier + 20;

  stealChance := stealModifier + skill_level(a1, SKILL_STEAL);
  if stealChance > 95 then
    stealChance := 95;

  if (a1 = obj_dude) and isPartyMember(a2) then
    stealRoll := ROLL_CRITICAL_SUCCESS
  else
  begin
    criticalChance := stat_level(a1, Ord(STAT_CRITICAL_CHANCE));
    stealRoll := roll_check(stealChance, criticalChance, @howMuch);
  end;

  if stealRoll = ROLL_CRITICAL_SUCCESS then
    catchRoll := ROLL_CRITICAL_FAILURE
  else if stealRoll = ROLL_CRITICAL_FAILURE then
    catchRoll := ROLL_SUCCESS
  else
  begin
    if PID_TYPE(a2^.Pid) = OBJ_TYPE_CRITTER then
      catchChance := skill_level(a2, SKILL_STEAL) - stealModifier
    else
      catchChance := 30 - stealModifier;

    catchRoll := roll_check(catchChance, 0, @howMuch);
  end;

  if (catchRoll <> ROLL_SUCCESS) and (catchRoll <> ROLL_CRITICAL_SUCCESS) then
  begin
    // 571: You steal the %s.
    // 573: You plant the %s.
    if isPlanting then
      messageListItem.num := 573
    else
      messageListItem.num := 571;

    if not message_search(@skill_message_file, @messageListItem) then
    begin
      Result := -1;
      Exit;
    end;

    StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [object_name(item)]);
    display_print(@text[0]);

    Result := 1;
  end
  else
  begin
    // 570: You're caught stealing the %s.
    // 572: You're caught planting the %s.
    if isPlanting then
      messageListItem.num := 572
    else
      messageListItem.num := 570;

    if not message_search(@skill_message_file, @messageListItem) then
    begin
      Result := -1;
      Exit;
    end;

    StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [object_name(item)]);
    display_print(@text[0]);

    Result := 0;
  end;
end;

// 0x4993D0
function skill_game_difficulty(skill: Integer): Integer;
var
  game_difficulty: Integer;
begin
  case skill of
    SKILL_FIRST_AID,
    SKILL_DOCTOR,
    SKILL_SNEAK,
    SKILL_LOCKPICK,
    SKILL_STEAL,
    SKILL_TRAPS,
    SKILL_SCIENCE,
    SKILL_REPAIR,
    SKILL_SPEECH,
    SKILL_BARTER,
    SKILL_GAMBLING,
    SKILL_OUTDOORSMAN:
      begin
        game_difficulty := GAME_DIFFICULTY_NORMAL;
        config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_GAME_DIFFICULTY_KEY, @game_difficulty);

        if game_difficulty = GAME_DIFFICULTY_HARD then
        begin
          Result := -10;
          Exit;
        end
        else if game_difficulty = GAME_DIFFICULTY_EASY then
        begin
          Result := 20;
          Exit;
        end;
      end;
  end;

  Result := 0;
end;

// 0x499428
function skill_use_slot_available(skill: Integer): Integer;
var
  slot: Integer;
  time: Integer;
  hoursSinceLastUsage: Integer;
begin
  for slot := 0 to SKILLS_MAX_USES_PER_DAY - 1 do
  begin
    if timesSkillUsed[skill][slot] = 0 then
    begin
      Result := slot;
      Exit;
    end;
  end;

  time := game_time();
  hoursSinceLastUsage := (time - timesSkillUsed[skill][0]) div GAME_TIME_TICKS_PER_HOUR;
  if hoursSinceLastUsage <= 24 then
  begin
    Result := -1;
    Exit;
  end;

  Result := SKILLS_MAX_USES_PER_DAY - 1;
end;

// 0x49949C
function skill_use_slot_add(skill: Integer): Integer;
var
  slot: Integer;
  i: Integer;
begin
  slot := skill_use_slot_available(skill);
  if slot = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if timesSkillUsed[skill][slot] <> 0 then
  begin
    for i := 0 to slot - 1 do
      timesSkillUsed[skill][i] := timesSkillUsed[skill][i + 1];
  end;

  timesSkillUsed[skill][slot] := game_time();

  Result := 0;
end;

// 0x499508
function skill_use_slot_clear: Integer;
begin
  FillChar(timesSkillUsed, SizeOf(timesSkillUsed), 0);
  Result := 0;
end;

// 0x499520
function skill_use_slot_save(stream: PDB_FILE): Integer;
begin
  Result := db_fwriteIntCount(stream, @timesSkillUsed[0][0], SKILL_COUNT * SKILLS_MAX_USES_PER_DAY);
end;

// 0x499540
function skill_use_slot_load(stream: PDB_FILE): Integer;
begin
  Result := db_freadIntCount(stream, @timesSkillUsed[0][0], SKILL_COUNT * SKILLS_MAX_USES_PER_DAY);
end;

initialization
  gIsSteal := 0;
  gStealCount := 0;
  gStealSize := 0;

end.
