unit u_stat;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/stat.h + stat.cc + stat_defs.h
// Character stat management: SPECIAL, derived stats, PC stats, experience.

interface

uses
  u_db,
  u_object_types,
  u_proto_types,
  u_stat_defs;

const
  STAT_ERR_INVALID_STAT = -5;

function stat_init: Integer;
function stat_reset: Integer;
function stat_exit: Integer;
function stat_load(stream: PDB_FILE): Integer;
function stat_save(stream: PDB_FILE): Integer;
function stat_level(critter: PObject; stat: Integer): Integer;
function stat_get_base(critter: PObject; stat: Integer): Integer;
function stat_get_base_direct(critter: PObject; stat: Integer): Integer;
function stat_get_bonus(critter: PObject; stat: Integer): Integer;
function stat_set_base(critter: PObject; stat: Integer; value: Integer): Integer;
function inc_stat(critter: PObject; stat: Integer): Integer;
function dec_stat(critter: PObject; stat: Integer): Integer;
function stat_set_bonus(critter: PObject; stat: Integer; value: Integer): Integer;
procedure stat_set_defaults(data: PCritterProtoData);
procedure stat_recalc_derived(critter: PObject);
function stat_name(stat: Integer): PAnsiChar;
function stat_description(stat: Integer): PAnsiChar;
function stat_level_description(value: Integer): PAnsiChar;
function stat_pc_get(pc_stat: Integer): Integer;
function stat_pc_set(pc_stat: Integer; value: Integer): Integer;
procedure stat_pc_set_defaults;
function stat_pc_min_exp: Integer;
function stat_pc_name(pcStat: Integer): PAnsiChar;
function stat_pc_description(pcStat: Integer): PAnsiChar;
function stat_picture(stat: Integer): Integer;
function stat_result(critter: PObject; stat: Integer; modifier: Integer; howMuch: PInteger): Integer;
function stat_pc_add_experience(xp: Integer): Integer;

implementation

uses
  SysUtils,
  u_message,
  u_proto,
  u_critter,
  u_combat,
  u_scripts,
  u_display,
  u_gsound,
  u_intface,
  u_roll,
  u_trait,
  u_perk,
  u_game,
  u_object,
  u_platform_compat;

const
  // From scripts.h
  GAME_TIME_TICKS_PER_YEAR = 365 * 24 * 60 * 60 * 10;

  // From roll.h
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

  // From critter.h
  PC_FLAG_LEVEL_UP_AVAILABLE = 3;

type
  PPProto = ^PProto;

  TStatDescription = record
    name: PAnsiChar;
    description: PAnsiChar;
    art_num: Integer;
    minimumValue: Integer;
    maximumValue: Integer;
    defaultValue: Integer;
  end;

const
  // Perk constants used in this module
  PERK_SWIFT_LEARNER = 50;
  PERK_LIFEGIVER     = 28;

var
  stat_data: array[0..Ord(STAT_COUNT) - 1] of TStatDescription = (
    (name: nil; description: nil; art_num:  0; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  1; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  2; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  3; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  4; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  5; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num:  6; minimumValue: PRIMARY_STAT_MIN; maximumValue: PRIMARY_STAT_MAX; defaultValue: 5),
    (name: nil; description: nil; art_num: 10; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 75; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 18; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 31; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 32; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 20; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 24; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 25; minimumValue: 0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 26; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    // CE: Fix minimal value (on par with Fallout 2).
    (name: nil; description: nil; art_num: 94; minimumValue: -60; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num: 22; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:  90; defaultValue: 0),
    (name: nil; description: nil; art_num: 83; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num: 23; minimumValue: 0; maximumValue: 100; defaultValue: 0),
    (name: nil; description: nil; art_num:  0; minimumValue: 16; maximumValue: 35; defaultValue: 25),
    (name: nil; description: nil; art_num:  0; minimumValue: 0; maximumValue:   1; defaultValue: 0),
    (name: nil; description: nil; art_num: 10; minimumValue: 0; maximumValue: 2000; defaultValue: 0),
    (name: nil; description: nil; art_num: 11; minimumValue: 0; maximumValue: 2000; defaultValue: 0),
    (name: nil; description: nil; art_num: 12; minimumValue: 0; maximumValue: 2000; defaultValue: 0)
  );

  pc_stat_data: array[0..Ord(PC_STAT_COUNT) - 1] of TStatDescription = (
    (name: nil; description: nil; art_num: 0; minimumValue:   0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 0; minimumValue:   1; maximumValue: MaxInt; defaultValue: 1),
    (name: nil; description: nil; art_num: 0; minimumValue:   0; maximumValue: MaxInt; defaultValue: 0),
    (name: nil; description: nil; art_num: 0; minimumValue: -20; maximumValue:     20; defaultValue: 0),
    (name: nil; description: nil; art_num: 0; minimumValue:   0; maximumValue: MaxInt; defaultValue: 0)
  );

  // Static exp array for stat_pc_min_exp (was C++ static local)
  stat_pc_min_exp_table: array[0..PC_LEVEL_MAX - 1] of Integer = (
    0,
    1,
    3,
    6,
    10,
    15,
    21,
    28,
    36,
    45,
    55,
    66,
    78,
    91,
    105,
    120,
    136,
    153,
    171,
    190,
    210
  );

var
  stat_message_file: TMessageList;
  level_description: array[0..PRIMARY_STAT_RANGE - 1] of PAnsiChar;
  curr_pc_stat: array[0..Ord(PC_STAT_COUNT) - 1] of Integer;

// 0x49C2F0
function stat_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  messageListItem: TMessageListItem;
  index: Integer;
begin
  // NOTE: Uninline.
  stat_pc_set_defaults;

  if not message_init(@stat_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'stat.msg']);

  if not message_load(@stat_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to Ord(STAT_COUNT) - 1 do
  begin
    stat_data[index].name := getmsg(@stat_message_file, @messageListItem, 100 + index);
    stat_data[index].description := getmsg(@stat_message_file, @messageListItem, 200 + index);
  end;

  for index := 0 to Ord(PC_STAT_COUNT) - 1 do
  begin
    pc_stat_data[index].name := getmsg(@stat_message_file, @messageListItem, 400 + index);
    pc_stat_data[index].description := getmsg(@stat_message_file, @messageListItem, 500 + index);
  end;

  for index := 0 to PRIMARY_STAT_RANGE - 1 do
  begin
    level_description[index] := getmsg(@stat_message_file, @messageListItem, 301 + index);
  end;

  Result := 0;
end;

// 0x49C440
function stat_reset: Integer;
begin
  // NOTE: Uninline.
  stat_pc_set_defaults;
  Result := 0;
end;

// 0x49C464
function stat_exit: Integer;
begin
  message_exit(@stat_message_file);
  Result := 0;
end;

// 0x49C474
function stat_load(stream: PDB_FILE): Integer;
var
  pc_stat: Integer;
begin
  for pc_stat := 0 to Ord(PC_STAT_COUNT) - 1 do
  begin
    if db_freadInt(stream, @curr_pc_stat[pc_stat]) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;
  Result := 0;
end;

// 0x49C4A0
function stat_save(stream: PDB_FILE): Integer;
var
  pc_stat: Integer;
begin
  for pc_stat := 0 to Ord(PC_STAT_COUNT) - 1 do
  begin
    if db_fwriteInt(stream, curr_pc_stat[pc_stat]) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;
  Result := 0;
end;

// 0x49C4C8
function stat_level(critter: PObject; stat: Integer): Integer;
var
  value: Integer;
begin
  if (stat >= 0) and (stat < SAVEABLE_STAT_COUNT) then
  begin
    value := stat_get_base(critter, stat);
    value := value + stat_get_bonus(critter, stat);

    case stat of
      Ord(STAT_PERCEPTION):
        begin
          if (critter^.Data.AsData.Critter.Combat.Results and DAM_BLIND) <> 0 then
            value := value - 5;
        end;
      Ord(STAT_ARMOR_CLASS):
        begin
          if isInCombat() then
          begin
            if combat_whose_turn() <> critter then
              value := value + critter^.Data.AsData.Critter.Combat.Ap;
          end;
        end;
      Ord(STAT_AGE):
        begin
          value := value + game_time() div GAME_TIME_TICKS_PER_YEAR;
        end;
    end;

    // std::clamp
    if value < stat_data[stat].minimumValue then
      value := stat_data[stat].minimumValue
    else if value > stat_data[stat].maximumValue then
      value := stat_data[stat].maximumValue;
  end
  else
  begin
    case stat of
      Ord(STAT_CURRENT_HIT_POINTS):
        value := critter_get_hits(critter);
      Ord(STAT_CURRENT_POISON_LEVEL):
        value := critter_get_poison(critter);
      Ord(STAT_CURRENT_RADIATION_LEVEL):
        value := critter_get_rads(critter);
    else
      value := 0;
    end;
  end;

  Result := value;
end;

// Returns base stat value (accounting for traits if critter is dude).
// 0x49C5B8
function stat_get_base(critter: PObject; stat: Integer): Integer;
var
  value: Integer;
begin
  value := stat_get_base_direct(critter, stat);

  if critter = obj_dude then
    value := value + trait_adjust_stat(stat);

  Result := value;
end;

// 0x49C5E0
function stat_get_base_direct(critter: PObject; stat: Integer): Integer;
var
  proto: PProto;
begin
  if (stat >= 0) and (stat < SAVEABLE_STAT_COUNT) then
  begin
    proto_ptr(critter^.Pid, @proto);
    Result := proto^.Critter.Data.BaseStats[stat];
    Exit;
  end
  else
  begin
    case stat of
      Ord(STAT_CURRENT_HIT_POINTS):
        begin
          Result := critter_get_hits(critter);
          Exit;
        end;
      Ord(STAT_CURRENT_POISON_LEVEL):
        begin
          Result := critter_get_poison(critter);
          Exit;
        end;
      Ord(STAT_CURRENT_RADIATION_LEVEL):
        begin
          Result := critter_get_rads(critter);
          Exit;
        end;
    end;
  end;

  Result := 0;
end;

// 0x49C64C
function stat_get_bonus(critter: PObject; stat: Integer): Integer;
var
  proto: PProto;
begin
  if (stat >= 0) and (stat < SAVEABLE_STAT_COUNT) then
  begin
    proto_ptr(critter^.Pid, @proto);
    Result := proto^.Critter.Data.BonusStats[stat];
    Exit;
  end;

  Result := 0;
end;

// 0x49C694
function stat_set_base(critter: PObject; stat: Integer; value: Integer): Integer;
var
  proto: PProto;
begin
  if (stat < 0) or (stat >= Ord(STAT_COUNT)) then
  begin
    Result := -5;
    Exit;
  end;

  if (stat >= 0) and (stat < SAVEABLE_STAT_COUNT) then
  begin
    if (stat > Ord(STAT_LUCK)) and (stat <= Ord(STAT_POISON_RESISTANCE)) then
    begin
      // Cannot change base value of derived stats.
      Result := -1;
      Exit;
    end;

    if critter = obj_dude then
      value := value - trait_adjust_stat(stat);

    if value < stat_data[stat].minimumValue then
    begin
      Result := -2;
      Exit;
    end;

    if value > stat_data[stat].maximumValue then
    begin
      Result := -3;
      Exit;
    end;

    proto_ptr(critter^.Pid, @proto);
    proto^.Critter.Data.BaseStats[stat] := value;

    if (stat >= Ord(STAT_STRENGTH)) and (stat <= Ord(STAT_LUCK)) then
      stat_recalc_derived(critter);

    Result := 0;
    Exit;
  end;

  case stat of
    Ord(STAT_CURRENT_HIT_POINTS):
      begin
        Result := critter_adjust_hits(critter, value - critter_get_hits(critter));
        Exit;
      end;
    Ord(STAT_CURRENT_POISON_LEVEL):
      begin
        Result := critter_adjust_poison(critter, value - critter_get_poison(critter));
        Exit;
      end;
    Ord(STAT_CURRENT_RADIATION_LEVEL):
      begin
        Result := critter_adjust_rads(critter, value - critter_get_rads(critter));
        Exit;
      end;
  end;

  // Should be unreachable
  Result := 0;
end;

// 0x49C7AC
function inc_stat(critter: PObject; stat: Integer): Integer;
var
  value: Integer;
begin
  value := stat_get_base_direct(critter, stat);

  if critter = obj_dude then
    value := value + trait_adjust_stat(stat);

  Result := stat_set_base(critter, stat, value + 1);
end;

// 0x49C7E0
function dec_stat(critter: PObject; stat: Integer): Integer;
var
  value: Integer;
begin
  value := stat_get_base_direct(critter, stat);

  if critter = obj_dude then
    value := value + trait_adjust_stat(stat);

  Result := stat_set_base(critter, stat, value - 1);
end;

// 0x49C814
function stat_set_bonus(critter: PObject; stat: Integer; value: Integer): Integer;
var
  proto: PProto;
begin
  if (stat < 0) or (stat >= Ord(STAT_COUNT)) then
  begin
    Result := -5;
    Exit;
  end;

  if (stat >= 0) and (stat < SAVEABLE_STAT_COUNT) then
  begin
    proto_ptr(critter^.Pid, @proto);
    proto^.Critter.Data.BonusStats[stat] := value;

    if (stat >= Ord(STAT_STRENGTH)) and (stat <= Ord(STAT_LUCK)) then
      stat_recalc_derived(critter);

    Result := 0;
    Exit;
  end
  else
  begin
    case stat of
      Ord(STAT_CURRENT_HIT_POINTS):
        begin
          Result := critter_adjust_hits(critter, value);
          Exit;
        end;
      Ord(STAT_CURRENT_POISON_LEVEL):
        begin
          Result := critter_adjust_poison(critter, value);
          Exit;
        end;
      Ord(STAT_CURRENT_RADIATION_LEVEL):
        begin
          Result := critter_adjust_rads(critter, value);
          Exit;
        end;
    end;
  end;

  // Should be unreachable
  Result := -1;
end;

// 0x49C8A4
procedure stat_set_defaults(data: PCritterProtoData);
var
  stat: Integer;
begin
  for stat := 0 to SAVEABLE_STAT_COUNT - 1 do
  begin
    data^.BaseStats[stat] := stat_data[stat].defaultValue;
    data^.BonusStats[stat] := 0;
  end;
end;

// 0x49C8D4
procedure stat_recalc_derived(critter: PObject);
var
  strength: Integer;
  perception: Integer;
  endurance: Integer;
  intelligence: Integer;
  agility: Integer;
  luck: Integer;
  proto: PProto;
  data: PCritterProtoData;
  meleeDmg: Integer;
  healRate: Integer;
begin
  strength := stat_level(critter, Ord(STAT_STRENGTH));
  perception := stat_level(critter, Ord(STAT_PERCEPTION));
  endurance := stat_level(critter, Ord(STAT_ENDURANCE));
  intelligence := stat_level(critter, Ord(STAT_INTELLIGENCE));
  agility := stat_level(critter, Ord(STAT_AGILITY));
  luck := stat_level(critter, Ord(STAT_LUCK));

  proto_ptr(critter^.Pid, @proto);
  data := @proto^.Critter.Data;

  data^.BaseStats[Ord(STAT_MAXIMUM_HIT_POINTS)] := stat_get_base(critter, Ord(STAT_STRENGTH)) + stat_get_base(critter, Ord(STAT_ENDURANCE)) * 2 + 15;
  data^.BaseStats[Ord(STAT_MAXIMUM_ACTION_POINTS)] := agility div 2 + 5;
  data^.BaseStats[Ord(STAT_ARMOR_CLASS)] := agility;

  // std::max(strength - 5, 1)
  meleeDmg := strength - 5;
  if meleeDmg < 1 then
    meleeDmg := 1;
  data^.BaseStats[Ord(STAT_MELEE_DAMAGE)] := meleeDmg;

  data^.BaseStats[Ord(STAT_CARRY_WEIGHT)] := 25 * strength + 25;
  data^.BaseStats[Ord(STAT_SEQUENCE)] := 2 * perception;

  // std::max(endurance / 3, 1)
  healRate := endurance div 3;
  if healRate < 1 then
    healRate := 1;
  data^.BaseStats[Ord(STAT_HEALING_RATE)] := healRate;

  data^.BaseStats[Ord(STAT_CRITICAL_CHANCE)] := luck;
  data^.BaseStats[Ord(STAT_BETTER_CRITICALS)] := 0;
  data^.BaseStats[Ord(STAT_RADIATION_RESISTANCE)] := 2 * endurance;
  data^.BaseStats[Ord(STAT_POISON_RESISTANCE)] := 5 * endurance;
end;

// 0x49CA2C
function stat_name(stat: Integer): PAnsiChar;
begin
  if (stat >= 0) and (stat < Ord(STAT_COUNT)) then
    Result := stat_data[stat].name
  else
    Result := nil;
end;

// 0x49CA70
function stat_description(stat: Integer): PAnsiChar;
begin
  if (stat >= 0) and (stat < Ord(STAT_COUNT)) then
    Result := stat_data[stat].description
  else
    Result := nil;
end;

// 0x49CAB4
function stat_level_description(value: Integer): PAnsiChar;
begin
  if value < PRIMARY_STAT_MIN then
    value := PRIMARY_STAT_MIN
  else if value > PRIMARY_STAT_MAX then
    value := PRIMARY_STAT_MAX;

  Result := level_description[value - PRIMARY_STAT_MIN];
end;

// 0x49CAD4
function stat_pc_get(pc_stat: Integer): Integer;
begin
  if (pc_stat >= 0) and (pc_stat < Ord(PC_STAT_COUNT)) then
    Result := curr_pc_stat[pc_stat]
  else
    Result := 0;
end;

// 0x49CAE8
function stat_pc_set(pc_stat: Integer; value: Integer): Integer;
var
  rc: Integer;
begin
  if (pc_stat < 0) and (pc_stat >= Ord(PC_STAT_COUNT)) then
  begin
    Result := -5;
    Exit;
  end;

  if value < pc_stat_data[pc_stat].minimumValue then
  begin
    Result := -2;
    Exit;
  end;

  if value > pc_stat_data[pc_stat].maximumValue then
  begin
    Result := -3;
    Exit;
  end;

  curr_pc_stat[pc_stat] := value;

  if pc_stat = Ord(PC_STAT_EXPERIENCE) then
    rc := stat_pc_add_experience(0)
  else
    rc := 0;

  Result := rc;
end;

// 0x49CB3C
procedure stat_pc_set_defaults;
var
  pc_stat: Integer;
begin
  for pc_stat := 0 to Ord(PC_STAT_COUNT) - 1 do
    curr_pc_stat[pc_stat] := pc_stat_data[pc_stat].defaultValue;
end;

// Returns experience to reach next level.
// 0x49CB5C
function stat_pc_min_exp: Integer;
var
  level: Integer;
begin
  level := stat_pc_get(Ord(PC_STAT_LEVEL));
  if level < PC_LEVEL_MAX then
    Result := 1000 * stat_pc_min_exp_table[level]
  else
    Result := -1;
end;

// 0x49CB88
function stat_pc_name(pcStat: Integer): PAnsiChar;
begin
  if (pcStat >= 0) and (pcStat < Ord(PC_STAT_COUNT)) then
    Result := pc_stat_data[pcStat].name
  else
    Result := nil;
end;

// 0x49CBA8
function stat_pc_description(pcStat: Integer): PAnsiChar;
begin
  if (pcStat >= 0) and (pcStat < Ord(PC_STAT_COUNT)) then
    Result := pc_stat_data[pcStat].description
  else
    Result := nil;
end;

// 0x49CBC8
function stat_picture(stat: Integer): Integer;
begin
  if (stat >= 0) and (stat < Ord(STAT_COUNT)) then
    Result := stat_data[stat].art_num
  else
    Result := 0;
end;

// 0x49CC0C
function stat_result(critter: PObject; stat: Integer; modifier: Integer; howMuch: PInteger): Integer;
var
  value: Integer;
  chance: Integer;
begin
  value := stat_level(critter, stat) + modifier;
  chance := roll_random(PRIMARY_STAT_MIN, PRIMARY_STAT_MAX);

  if howMuch <> nil then
    howMuch^ := value - chance;

  if chance <= value then
    Result := ROLL_SUCCESS
  else
    Result := ROLL_FAILURE;
end;

// 0x49CC3C
function stat_pc_add_experience(xp: Integer): Integer;
var
  messageListItem: TMessageListItem;
  hp: Integer;
begin
  xp := xp + perk_level(PERK_SWIFT_LEARNER) * 5 * xp div 100;
  xp := xp + stat_pc_get(Ord(PC_STAT_EXPERIENCE));

  if xp < pc_stat_data[Ord(PC_STAT_EXPERIENCE)].minimumValue then
    xp := pc_stat_data[Ord(PC_STAT_EXPERIENCE)].minimumValue;

  if xp > pc_stat_data[Ord(PC_STAT_EXPERIENCE)].maximumValue then
    xp := pc_stat_data[Ord(PC_STAT_EXPERIENCE)].maximumValue;

  curr_pc_stat[Ord(PC_STAT_EXPERIENCE)] := xp;

  while (stat_pc_get(Ord(PC_STAT_LEVEL)) < PC_LEVEL_MAX) and (xp >= stat_pc_min_exp()) do
  begin
    if stat_pc_set(Ord(PC_STAT_LEVEL), stat_pc_get(Ord(PC_STAT_LEVEL)) + 1) = 0 then
    begin
      // You have gone up a level.
      messageListItem.num := 600;
      if message_search(@stat_message_file, @messageListItem) then
        display_print(messageListItem.text);

      pc_flag_on(PC_FLAG_LEVEL_UP_AVAILABLE);

      gsound_play_sfx_file('levelup');

      // NOTE: Uninline.
      hp := stat_get_base(obj_dude, Ord(STAT_ENDURANCE)) div 2 + 2;
      hp := hp + perk_level(PERK_LIFEGIVER) * 4;
      critter_adjust_hits(obj_dude, hp);

      stat_set_bonus(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS), stat_get_bonus(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS)) + hp);

      intface_update_hit_points(False);
    end;
  end;

  Result := 0;
end;

end.
