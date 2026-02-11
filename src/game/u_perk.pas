unit u_perk;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

uses
  u_db,
  u_object_types;

const
  PERK_AWARENESS          = 0;
  PERK_BONUS_HTH_ATTACKS  = 1;
  PERK_BONUS_HTH_DAMAGE   = 2;
  PERK_BONUS_MOVE         = 3;
  PERK_BONUS_RANGED_DAMAGE = 4;
  PERK_BONUS_RATE_OF_FIRE = 5;
  PERK_EARLIER_SEQUENCE   = 6;
  PERK_FASTER_HEALING     = 7;
  PERK_MORE_CRITICALS     = 8;
  PERK_NIGHT_VISION       = 9;
  PERK_PRESENCE           = 10;
  PERK_RAD_RESISTANCE     = 11;
  PERK_TOUGHNESS          = 12;
  PERK_STRONG_BACK        = 13;
  PERK_SHARPSHOOTER       = 14;
  PERK_SILENT_RUNNING     = 15;
  PERK_SURVIVALIST        = 16;
  PERK_MASTER_TRADER      = 17;
  PERK_EDUCATED           = 18;
  PERK_HEALER             = 19;
  PERK_FORTUNE_FINDER     = 20;
  PERK_BETTER_CRITICALS   = 21;
  PERK_EMPATHY            = 22;
  PERK_SLAYER             = 23;
  PERK_SNIPER             = 24;
  PERK_SILENT_DEATH       = 25;
  PERK_ACTION_BOY         = 26;
  PERK_MENTAL_BLOCK       = 27;
  PERK_LIFEGIVER          = 28;
  PERK_DODGER             = 29;
  PERK_SNAKEATER          = 30;
  PERK_MR_FIXIT           = 31;
  PERK_MEDIC              = 32;
  PERK_MASTER_THIEF       = 33;
  PERK_SPEAKER            = 34;
  PERK_HEAVE_HO           = 35;
  PERK_FRIENDLY_FOE       = 36;
  PERK_PICKPOCKET         = 37;
  PERK_GHOST              = 38;
  PERK_CULT_OF_PERSONALITY = 39;
  PERK_SCROUNGER          = 40;
  PERK_EXPLORER           = 41;
  PERK_FLOWER_CHILD       = 42;
  PERK_PATHFINDER         = 43;
  PERK_ANIMAL_FRIEND      = 44;
  PERK_SCOUT              = 45;
  PERK_MYSTERIOUS_STRANGER = 46;
  PERK_RANGER             = 47;
  PERK_QUICK_POCKETS      = 48;
  PERK_SMOOTH_TALKER      = 49;
  PERK_SWIFT_LEARNER      = 50;
  PERK_TAG                = 51;
  PERK_MUTATE             = 52;
  PERK_NUKA_COLA_ADDICTION = 53;
  PERK_BUFFOUT_ADDICTION  = 54;
  PERK_MENTATS_ADDICTION  = 55;
  PERK_PSYCHO_ADDICTION   = 56;
  PERK_RADAWAY_ADDICTION  = 57;
  PERK_WEAPON_LONG_RANGE  = 58;
  PERK_WEAPON_ACCURATE    = 59;
  PERK_WEAPON_PENETRATE   = 60;
  PERK_WEAPON_KNOCKBACK   = 61;
  PERK_POWERED_ARMOR      = 62;
  PERK_COMBAT_ARMOR       = 63;
  PERK_COUNT              = 64;

function perk_init: Integer;
function perk_reset: Integer;
function perk_exit: Integer;
function perk_load(stream: PDB_FILE): Integer;
function perk_save(stream: PDB_FILE): Integer;
function perk_add(perk: Integer): Integer;
function perk_sub(perk: Integer): Integer;
function perk_make_list(perks: PInteger): Integer;
function perk_level(perk: Integer): Integer;
function perk_name(perk: Integer): PAnsiChar;
function perk_description(perk: Integer): PAnsiChar;
procedure perk_add_effect(critter: PObject; perk: Integer);
procedure perk_remove_effect(critter: PObject; perk: Integer);
function perk_adjust_skill(skill: Integer): Integer;

implementation

uses
  SysUtils,
  u_message,
  u_stat,
  u_skill,
  u_object,
  u_game;

const
  PRIMARY_STAT_COUNT = 7;
  PC_STAT_LEVEL      = 1;

  // Skill constants
  SKILL_FIRST_AID    = 6;
  SKILL_DOCTOR       = 7;
  SKILL_SNEAK        = 8;
  SKILL_LOCKPICK     = 9;
  SKILL_STEAL        = 10;
  SKILL_TRAPS        = 11;
  SKILL_SCIENCE      = 12;
  SKILL_REPAIR       = 13;
  SKILL_SPEECH       = 14;
  SKILL_BARTER       = 15;

  COMPAT_MAX_PATH = 260;

type
  TPerkDescription = record
    name: PAnsiChar;
    description: PAnsiChar;
    max_rank: Integer;
    min_level: Integer;
    stat: Integer;
    stat_modifier: Integer;
    required_skill: Integer;
    required_skill_level: Integer;
    required_stat_levels: array[0..PRIMARY_STAT_COUNT - 1] of Integer;
  end;

var
  perk_data: array[0..PERK_COUNT - 1] of TPerkDescription = (
    (name: nil; description: nil; max_rank:  1; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 5, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 6, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: 11; stat_modifier:  2; required_skill: -1; required_skill_level: 0; required_stat_levels: (6, 0, 0, 0, 0, 6, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 5, 0)),
    (name: nil; description: nil; max_rank:  2; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 6, 6)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 6, 0, 0, 6, 7, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: 13; stat_modifier:  2; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 6, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: 14; stat_modifier:  1; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 6, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: 15; stat_modifier:  5; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 6)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 6, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 6, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: 31; stat_modifier: 15; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 6, 0, 4, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: 24; stat_modifier: 10; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 6, 0, 0, 0, 6)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: 12; stat_modifier: 50; required_skill: -1; required_skill_level: 0; required_stat_levels: (6, 0, 6, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  2; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 7, 0, 0, 6, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill:  8; required_skill_level: 50; required_stat_levels: (0, 0, 0, 0, 0, 6, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: 17; required_skill_level: 40; required_stat_levels: (0, 0, 6, 0, 6, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: 15; required_skill_level: 60; required_stat_levels: (0, 0, 0, 7, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 6, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill:  6; required_skill_level: 40; required_stat_levels: (0, 7, 0, 0, 5, 6, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 8)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: 16; stat_modifier: 20; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 6, 0, 0, 0, 4, 6)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 7, 0, 0, 5, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 18; stat: -1; stat_modifier:  0; required_skill:  3; required_skill_level: 80; required_stat_levels: (8, 0, 0, 0, 0, 8, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 18; stat: -1; stat_modifier:  0; required_skill:  0; required_skill_level: 80; required_stat_levels: (0, 8, 0, 0, 0, 8, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 18; stat: -1; stat_modifier:  0; required_skill:  8; required_skill_level: 80; required_stat_levels: (0, 0, 0, 0, 0, 10, 0)),
    (name: nil; description: nil; max_rank:  3; min_level: 12; stat:  8; stat_modifier:  1; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 5, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 15; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 4, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  2; min_level:  9; stat:  9; stat_modifier:  5; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 4, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: 32; stat_modifier: 25; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 3, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 4, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill:  8; required_skill_level: 80; required_stat_levels: (0, 0, 0, 0, 0, 8, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill:  8; required_skill_level: 60; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 10, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 8)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 5, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  2; min_level:  6; stat: -1; stat_modifier:  0; required_skill: 17; required_skill_level: 40; required_stat_levels: (0, 0, 6, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: 17; required_skill_level: 25; required_stat_levels: (0, 0, 0, 0, 5, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 8, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 7)),
    (name: nil; description: nil; max_rank:  3; min_level:  6; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 6, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 5, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 4, 0, 0)),
    (name: nil; description: nil; max_rank:  3; min_level:  3; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 4, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level: 12; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank:  1; min_level:  9; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (-2, 0, -2, 0, 0, -3, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, -3, -2, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, -2, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: 31; stat_modifier: -20; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: -1; stat_modifier:  0; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: 31; stat_modifier: 30; required_skill: -1; required_skill_level: 0; required_stat_levels: (3, 0, 0, 0, 0, 0, 0)),
    (name: nil; description: nil; max_rank: -1; min_level:  1; stat: 31; stat_modifier: 20; required_skill: -1; required_skill_level: 0; required_stat_levels: (0, 0, 0, 0, 0, 0, 0))
  );

  perk_lev: array[0..PERK_COUNT - 1] of Integer;
  perk_message_file: TMessageList;

// Forward declarations
function perk_can_add(perk: Integer): Boolean; forward;
procedure perk_defaults; forward;

function perk_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  i: Integer;
  messageListItem: TMessageListItem;
begin
  perk_defaults;

  if not message_init(@perk_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'perk.msg']);

  if not message_load(@perk_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  for i := 0 to PERK_COUNT - 1 do
  begin
    messageListItem.num := 101 + i;
    if message_search(@perk_message_file, @messageListItem) then
      perk_data[i].name := messageListItem.text;

    messageListItem.num := 201 + i;
    if message_search(@perk_message_file, @messageListItem) then
      perk_data[i].description := messageListItem.text;
  end;

  Result := 0;
end;

function perk_reset: Integer;
begin
  perk_defaults;
  Result := 0;
end;

function perk_exit: Integer;
begin
  message_exit(@perk_message_file);
  Result := 0;
end;

function perk_load(stream: PDB_FILE): Integer;
var
  i: Integer;
begin
  for i := 0 to PERK_COUNT - 1 do
  begin
    if db_freadInt(stream, @perk_lev[i]) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;
  Result := 0;
end;

function perk_save(stream: PDB_FILE): Integer;
var
  i: Integer;
begin
  for i := 0 to PERK_COUNT - 1 do
  begin
    if db_fwriteInt(stream, perk_lev[i]) = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;
  Result := 0;
end;

function perk_can_add(perk: Integer): Boolean;
var
  perkDesc: ^TPerkDescription;
  stat: Integer;
begin
  if (perk < 0) or (perk >= PERK_COUNT) then
  begin
    Result := False;
    Exit;
  end;

  perkDesc := @perk_data[perk];

  if perkDesc^.max_rank = -1 then
  begin
    Result := False;
    Exit;
  end;

  if perk_lev[perk] >= perkDesc^.max_rank then
  begin
    Result := False;
    Exit;
  end;

  if stat_pc_get(PC_STAT_LEVEL) < perkDesc^.min_level then
  begin
    Result := False;
    Exit;
  end;

  if perkDesc^.required_skill <> -1 then
  begin
    if skill_level(obj_dude, perkDesc^.required_skill) < perkDesc^.required_skill_level then
    begin
      Result := False;
      Exit;
    end;
  end;

  for stat := 0 to PRIMARY_STAT_COUNT - 1 do
  begin
    if stat_level(obj_dude, stat) < perkDesc^.required_stat_levels[stat] then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

procedure perk_defaults;
var
  i: Integer;
begin
  for i := 0 to PERK_COUNT - 1 do
    perk_lev[i] := 0;
end;

function perk_add(perk: Integer): Integer;
begin
  if (perk < 0) or (perk >= PERK_COUNT) then
  begin
    Result := -1;
    Exit;
  end;

  if not perk_can_add(perk) then
  begin
    Result := -1;
    Exit;
  end;

  perk_lev[perk] += 1;

  perk_add_effect(obj_dude, perk);

  Result := 0;
end;

function perk_sub(perk: Integer): Integer;
begin
  if (perk < 0) or (perk >= PERK_COUNT) then
  begin
    Result := -1;
    Exit;
  end;

  if perk_lev[perk] < 1 then
  begin
    Result := -1;
    Exit;
  end;

  perk_lev[perk] -= 1;

  perk_remove_effect(obj_dude, perk);

  Result := 0;
end;

function perk_make_list(perks: PInteger): Integer;
var
  i: Integer;
  count: Integer;
  p: PInteger;
begin
  count := 0;
  p := perks;
  for i := 0 to PERK_COUNT - 1 do
  begin
    if perk_can_add(i) then
    begin
      p^ := i;
      Inc(p);
      Inc(count);
    end;
  end;
  Result := count;
end;

function perk_level(perk: Integer): Integer;
begin
  if (perk >= 0) and (perk < PERK_COUNT) then
    Result := perk_lev[perk]
  else
    Result := 0;
end;

function perk_name(perk: Integer): PAnsiChar;
begin
  if (perk >= 0) and (perk < PERK_COUNT) then
    Result := perk_data[perk].name
  else
    Result := nil;
end;

function perk_description(perk: Integer): PAnsiChar;
begin
  if (perk >= 0) and (perk < PERK_COUNT) then
    Result := perk_data[perk].description
  else
    Result := nil;
end;

procedure perk_add_effect(critter: PObject; perk: Integer);
var
  perkDesc: ^TPerkDescription;
  value: Integer;
  stat: Integer;
begin
  if (perk < 0) or (perk >= PERK_COUNT) then
    Exit;

  perkDesc := @perk_data[perk];

  if perkDesc^.stat <> -1 then
  begin
    value := stat_get_bonus(critter, perkDesc^.stat);
    stat_set_bonus(critter, perkDesc^.stat, value + perkDesc^.stat_modifier);
  end;

  if perkDesc^.max_rank = -1 then
  begin
    for stat := 0 to PRIMARY_STAT_COUNT - 1 do
    begin
      value := stat_get_bonus(critter, stat);
      stat_set_bonus(critter, stat, value + perkDesc^.required_stat_levels[stat]);
    end;
  end;
end;

procedure perk_remove_effect(critter: PObject; perk: Integer);
var
  perkDesc: ^TPerkDescription;
  value: Integer;
  stat: Integer;
begin
  if (perk < 0) or (perk >= PERK_COUNT) then
    Exit;

  perkDesc := @perk_data[perk];

  if perkDesc^.stat <> -1 then
  begin
    value := stat_get_bonus(critter, perkDesc^.stat);
    stat_set_bonus(critter, perkDesc^.stat, value - perkDesc^.stat_modifier);
  end;

  if perkDesc^.max_rank = -1 then
  begin
    for stat := 0 to PRIMARY_STAT_COUNT - 1 do
    begin
      value := stat_get_bonus(critter, stat);
      stat_set_bonus(critter, stat, value - perkDesc^.required_stat_levels[stat]);
    end;
  end;
end;

function perk_adjust_skill(skill: Integer): Integer;
var
  modifier: Integer;
begin
  modifier := 0;

  case skill of
    SKILL_FIRST_AID,
    SKILL_DOCTOR:
      begin
        if perk_level(PERK_MEDIC) <> 0 then
          modifier += 20;
      end;
    SKILL_SNEAK:
      begin
        if perk_level(PERK_GHOST) <> 0 then
        begin
          if obj_get_visible_light(obj_dude) <= 45875 then
            modifier += 20;
        end;
        // C++ FALLTHROUGH: SNEAK also checks MASTER_THIEF
        if perk_level(PERK_MASTER_THIEF) <> 0 then
          modifier += 10;
      end;
    SKILL_LOCKPICK,
    SKILL_STEAL,
    SKILL_TRAPS:
      begin
        if perk_level(PERK_MASTER_THIEF) <> 0 then
          modifier += 10;
      end;
    SKILL_SCIENCE,
    SKILL_REPAIR:
      begin
        if perk_level(PERK_MR_FIXIT) <> 0 then
          modifier += 20;
      end;
    SKILL_SPEECH,
    SKILL_BARTER:
      begin
        if perk_level(PERK_SPEAKER) <> 0 then
          modifier += 20;
      end;
  end;

  Result := modifier;
end;

end.
