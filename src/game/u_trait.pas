unit u_trait;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

uses
  u_db;

const
  PC_TRAIT_MAX = 2;

  TRAIT_FAST_METABOLISM  = 0;
  TRAIT_BRUISER          = 1;
  TRAIT_SMALL_FRAME      = 2;
  TRAIT_ONE_HANDER       = 3;
  TRAIT_FINESSE          = 4;
  TRAIT_KAMIKAZE         = 5;
  TRAIT_HEAVY_HANDED     = 6;
  TRAIT_FAST_SHOT        = 7;
  TRAIT_BLOODY_MESS      = 8;
  TRAIT_JINXED           = 9;
  TRAIT_GOOD_NATURED     = 10;
  TRAIT_CHEM_RELIANT     = 11;
  TRAIT_CHEM_RESISTANT   = 12;
  TRAIT_NIGHT_PERSON     = 13;
  TRAIT_SKILLED          = 14;
  TRAIT_GIFTED           = 15;
  TRAIT_COUNT            = 16;

function trait_init: Integer;
procedure trait_reset;
procedure trait_exit;
function trait_load(stream: PDB_FILE): Integer;
function trait_save(stream: PDB_FILE): Integer;
procedure trait_set(trait1: Integer; trait2: Integer);
procedure trait_get(trait1: PInteger; trait2: PInteger);
function trait_name(trait_: Integer): PAnsiChar;
function trait_description(trait_: Integer): PAnsiChar;
function trait_pic(trait_: Integer): Integer;
function trait_level(trait_: Integer): Integer;
function trait_adjust_stat(stat: Integer): Integer;
function trait_adjust_skill(skill: Integer): Integer;

implementation

uses
  SysUtils,
  u_object_types,
  u_message,
  u_scripts,
  u_stat,
  u_game,
  u_object;

const
  // Stat constants (from stat_defs.h)
  STAT_STRENGTH               = 0;
  STAT_PERCEPTION              = 1;
  STAT_ENDURANCE               = 2;
  STAT_CHARISMA                = 3;
  STAT_INTELLIGENCE            = 4;
  STAT_AGILITY                 = 5;
  STAT_LUCK                    = 6;
  STAT_MAXIMUM_ACTION_POINTS   = 8;
  STAT_ARMOR_CLASS             = 9;
  STAT_MELEE_DAMAGE            = 11;
  STAT_CARRY_WEIGHT            = 12;
  STAT_SEQUENCE                = 13;
  STAT_HEALING_RATE            = 14;
  STAT_CRITICAL_CHANCE         = 15;
  STAT_BETTER_CRITICALS        = 16;
  STAT_RADIATION_RESISTANCE    = 31;
  STAT_POISON_RESISTANCE       = 32;

  // Skill constants (from skill_defs.h)
  SKILL_SMALL_GUNS      = 0;
  SKILL_BIG_GUNS        = 1;
  SKILL_ENERGY_WEAPONS  = 2;
  SKILL_UNARMED         = 3;
  SKILL_MELEE_WEAPONS   = 4;
  SKILL_THROWING        = 5;
  SKILL_FIRST_AID       = 6;
  SKILL_DOCTOR          = 7;
  SKILL_SPEECH          = 14;
  SKILL_BARTER          = 15;

  COMPAT_MAX_PATH = 260;

type
  TTraitDescription = record
    name: PAnsiChar;
    description: PAnsiChar;
    art_num: Integer;
  end;

var
  trait_data: array[0..TRAIT_COUNT - 1] of TTraitDescription = (
    (name: nil; description: nil; art_num: 55),
    (name: nil; description: nil; art_num: 56),
    (name: nil; description: nil; art_num: 57),
    (name: nil; description: nil; art_num: 58),
    (name: nil; description: nil; art_num: 59),
    (name: nil; description: nil; art_num: 60),
    (name: nil; description: nil; art_num: 61),
    (name: nil; description: nil; art_num: 62),
    (name: nil; description: nil; art_num: 63),
    (name: nil; description: nil; art_num: 64),
    (name: nil; description: nil; art_num: 65),
    (name: nil; description: nil; art_num: 66),
    (name: nil; description: nil; art_num: 67),
    (name: nil; description: nil; art_num: 68),
    (name: nil; description: nil; art_num: 69),
    (name: nil; description: nil; art_num: 70)
  );

  trait_message_file: TMessageList;
  pc_trait: array[0..PC_TRAIT_MAX - 1] of Integer;

function trait_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  i: Integer;
  messageListItem: TMessageListItem;
begin
  if not message_init(@trait_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'trait.msg']);

  if not message_load(@trait_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  for i := 0 to TRAIT_COUNT - 1 do
  begin
    messageListItem.num := 100 + i;
    if message_search(@trait_message_file, @messageListItem) then
      trait_data[i].name := messageListItem.text;

    messageListItem.num := 200 + i;
    if message_search(@trait_message_file, @messageListItem) then
      trait_data[i].description := messageListItem.text;
  end;

  trait_reset;

  Result := 1; // true
end;

procedure trait_reset;
var
  i: Integer;
begin
  for i := 0 to PC_TRAIT_MAX - 1 do
    pc_trait[i] := -1;
end;

procedure trait_exit;
begin
  message_exit(@trait_message_file);
end;

function trait_load(stream: PDB_FILE): Integer;
begin
  Result := db_freadIntCount(stream, @pc_trait[0], PC_TRAIT_MAX);
end;

function trait_save(stream: PDB_FILE): Integer;
begin
  Result := db_fwriteIntCount(stream, @pc_trait[0], PC_TRAIT_MAX);
end;

procedure trait_set(trait1: Integer; trait2: Integer);
begin
  pc_trait[0] := trait1;
  pc_trait[1] := trait2;
end;

procedure trait_get(trait1: PInteger; trait2: PInteger);
begin
  trait1^ := pc_trait[0];
  trait2^ := pc_trait[1];
end;

function trait_name(trait_: Integer): PAnsiChar;
begin
  if (trait_ >= 0) and (trait_ < TRAIT_COUNT) then
    Result := trait_data[trait_].name
  else
    Result := nil;
end;

function trait_description(trait_: Integer): PAnsiChar;
begin
  if (trait_ >= 0) and (trait_ < TRAIT_COUNT) then
    Result := trait_data[trait_].description
  else
    Result := nil;
end;

function trait_pic(trait_: Integer): Integer;
begin
  if (trait_ >= 0) and (trait_ < TRAIT_COUNT) then
    Result := trait_data[trait_].art_num
  else
    Result := 0;
end;

function trait_level(trait_: Integer): Integer;
var
  i: Integer;
begin
  for i := 0 to PC_TRAIT_MAX - 1 do
  begin
    if pc_trait[i] = trait_ then
    begin
      Result := 1;
      Exit;
    end;
  end;
  Result := 0;
end;

function trait_adjust_stat(stat: Integer): Integer;
var
  modifier: Integer;
begin
  modifier := 0;

  case stat of
    STAT_STRENGTH:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
        if trait_level(TRAIT_BRUISER) <> 0 then
          modifier += 2;
      end;
    STAT_PERCEPTION:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
        if trait_level(TRAIT_NIGHT_PERSON) <> 0 then
        begin
          if game_time_hour() - 600 < 1200 then
            modifier -= 1
          else
            modifier += 1;
        end;
      end;
    STAT_ENDURANCE:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
      end;
    STAT_CHARISMA:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
      end;
    STAT_INTELLIGENCE:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
        if trait_level(TRAIT_NIGHT_PERSON) <> 0 then
        begin
          if game_time_hour() - 600 < 1200 then
            modifier -= 1
          else
            modifier += 1;
        end;
      end;
    STAT_AGILITY:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
        if trait_level(TRAIT_SMALL_FRAME) <> 0 then
          modifier += 1;
      end;
    STAT_LUCK:
      begin
        if trait_level(TRAIT_GIFTED) <> 0 then
          modifier += 1;
      end;
    STAT_MAXIMUM_ACTION_POINTS:
      begin
        if trait_level(TRAIT_BRUISER) <> 0 then
          modifier -= 2;
      end;
    STAT_ARMOR_CLASS:
      begin
        if trait_level(TRAIT_KAMIKAZE) <> 0 then
          modifier -= stat_get_base_direct(obj_dude, STAT_ARMOR_CLASS);
      end;
    STAT_MELEE_DAMAGE:
      begin
        if trait_level(TRAIT_HEAVY_HANDED) <> 0 then
          modifier += 4;
      end;
    STAT_CARRY_WEIGHT:
      begin
        if trait_level(TRAIT_SMALL_FRAME) <> 0 then
          modifier -= 10 * stat_get_base_direct(obj_dude, STAT_STRENGTH);
      end;
    STAT_SEQUENCE:
      begin
        if trait_level(TRAIT_KAMIKAZE) <> 0 then
          modifier += 5;
      end;
    STAT_HEALING_RATE:
      begin
        if trait_level(TRAIT_FAST_METABOLISM) <> 0 then
          modifier += 2;
      end;
    STAT_CRITICAL_CHANCE:
      begin
        if trait_level(TRAIT_FINESSE) <> 0 then
          modifier += 10;
      end;
    STAT_BETTER_CRITICALS:
      begin
        if trait_level(TRAIT_HEAVY_HANDED) <> 0 then
          modifier -= 30;
      end;
    STAT_RADIATION_RESISTANCE:
      begin
        if trait_level(TRAIT_FAST_METABOLISM) <> 0 then
          modifier -= stat_get_base_direct(obj_dude, STAT_RADIATION_RESISTANCE);
      end;
    STAT_POISON_RESISTANCE:
      begin
        if trait_level(TRAIT_FAST_METABOLISM) <> 0 then
          modifier -= stat_get_base_direct(obj_dude, STAT_POISON_RESISTANCE);
      end;
  end;

  Result := modifier;
end;

function trait_adjust_skill(skill: Integer): Integer;
var
  modifier: Integer;
begin
  modifier := 0;

  if trait_level(TRAIT_GIFTED) <> 0 then
    modifier -= 10;

  if trait_level(TRAIT_SKILLED) <> 0 then
    modifier += 10;

  if trait_level(TRAIT_GOOD_NATURED) <> 0 then
  begin
    case skill of
      SKILL_SMALL_GUNS,
      SKILL_BIG_GUNS,
      SKILL_ENERGY_WEAPONS,
      SKILL_UNARMED,
      SKILL_MELEE_WEAPONS,
      SKILL_THROWING:
        modifier -= 10;
      SKILL_FIRST_AID,
      SKILL_DOCTOR,
      SKILL_SPEECH,
      SKILL_BARTER:
        modifier += 15;
    end;
  end;

  Result := modifier;
end;

end.
