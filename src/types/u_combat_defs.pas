{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

unit u_combat_defs;

interface

uses
  u_object_types;

const
  EXPLOSION_TARGET_COUNT = 6;
  CRITICAL_EFFECT_COUNT = 6;
  WEAPON_CRITICAL_FAILURE_TYPE_COUNT = 7;
  WEAPON_CRITICAL_FAILURE_EFFECT_COUNT = 5;

  // CombatState constants
  COMBAT_STATE_0x01 = $01;
  COMBAT_STATE_0x02 = $02;
  COMBAT_STATE_0x08 = $08;

  // HitMode enum values
  HIT_MODE_LEFT_WEAPON_PRIMARY = 0;
  HIT_MODE_LEFT_WEAPON_SECONDARY = 1;
  HIT_MODE_RIGHT_WEAPON_PRIMARY = 2;
  HIT_MODE_RIGHT_WEAPON_SECONDARY = 3;
  HIT_MODE_PUNCH = 4;
  HIT_MODE_KICK = 5;
  HIT_MODE_LEFT_WEAPON_RELOAD = 6;
  HIT_MODE_RIGHT_WEAPON_RELOAD = 7;
  HIT_MODE_STRONG_PUNCH = 8;
  HIT_MODE_HAMMER_PUNCH = 9;
  HIT_MODE_HAYMAKER = 10;
  HIT_MODE_JAB = 11;
  HIT_MODE_PALM_STRIKE = 12;
  HIT_MODE_PIERCING_STRIKE = 13;
  HIT_MODE_STRONG_KICK = 14;
  HIT_MODE_SNAP_KICK = 15;
  HIT_MODE_POWER_KICK = 16;
  HIT_MODE_HIP_KICK = 17;
  HIT_MODE_HOOK_KICK = 18;
  HIT_MODE_PIERCING_KICK = 19;
  HIT_MODE_COUNT = 20;

  // HitMode named aliases (these are separate constants, not enum values)
  FIRST_ADVANCED_PUNCH_HIT_MODE = HIT_MODE_STRONG_PUNCH;
  LAST_ADVANCED_PUNCH_HIT_MODE = HIT_MODE_PIERCING_STRIKE;
  FIRST_ADVANCED_KICK_HIT_MODE = HIT_MODE_STRONG_KICK;
  LAST_ADVANCED_KICK_HIT_MODE = HIT_MODE_PIERCING_KICK;
  FIRST_ADVANCED_UNARMED_HIT_MODE = FIRST_ADVANCED_PUNCH_HIT_MODE;
  LAST_ADVANCED_UNARMED_HIT_MODE = LAST_ADVANCED_KICK_HIT_MODE;

  // HitLocation enum values
  HIT_LOCATION_HEAD = 0;
  HIT_LOCATION_LEFT_ARM = 1;
  HIT_LOCATION_RIGHT_ARM = 2;
  HIT_LOCATION_TORSO = 3;
  HIT_LOCATION_RIGHT_LEG = 4;
  HIT_LOCATION_LEFT_LEG = 5;
  HIT_LOCATION_EYES = 6;
  HIT_LOCATION_GROIN = 7;
  HIT_LOCATION_UNCALLED = 8;
  HIT_LOCATION_COUNT = 9;

  // HitLocation named alias
  HIT_LOCATION_SPECIFIC_COUNT = HIT_LOCATION_COUNT - 1;

  // CombatBadShot enum values
  COMBAT_BAD_SHOT_OK = 0;
  COMBAT_BAD_SHOT_NO_AMMO = 1;
  COMBAT_BAD_SHOT_OUT_OF_RANGE = 2;
  COMBAT_BAD_SHOT_NOT_ENOUGH_AP = 3;
  COMBAT_BAD_SHOT_ALREADY_DEAD = 4;
  COMBAT_BAD_SHOT_AIM_BLOCKED = 5;
  COMBAT_BAD_SHOT_ARM_CRIPPLED = 6;
  COMBAT_BAD_SHOT_BOTH_ARMS_CRIPPLED = 7;

type
  TSTRUCT_664980 = packed record
    attacker: PObject;
    defender: PObject;
    actionPointsBonus: Int32;
    accuracyBonus: Int32;
    damageBonus: Int32;
    minDamage: Int32;
    maxDamage: Int32;
    field_1C: Int32;
    field_20: Int32;
    field_24: Int32;
  end;

  PSTRUCT_664980 = ^TSTRUCT_664980;

  TAttack = packed record
    attacker: PObject;
    hitMode: Int32;
    weapon: PObject;
    attackHitLocation: Int32;
    attackerDamage: Int32;
    attackerFlags: Int32;
    ammoQuantity: Int32;
    criticalMessageId: Int32;
    defender: PObject;
    tile: Int32;
    defenderHitLocation: Int32;
    defenderDamage: Int32;
    defenderFlags: Int32;
    defenderKnockback: Int32;
    oops: PObject;
    extrasLength: Int32;
    extras: array[0..EXPLOSION_TARGET_COUNT-1] of PObject;
    extrasHitLocation: array[0..EXPLOSION_TARGET_COUNT-1] of Int32;
    extrasDamage: array[0..EXPLOSION_TARGET_COUNT-1] of Int32;
    extrasFlags: array[0..EXPLOSION_TARGET_COUNT-1] of Int32;
    extrasKnockback: array[0..EXPLOSION_TARGET_COUNT-1] of Int32;
  end;

  PAttack = ^TAttack;

  TCriticalHitDescription = packed record
    damageMultiplier: Int32;
    flags: Int32;
    massiveCriticalStat: Int32;
    massiveCriticalStatModifier: Int32;
    massiveCriticalFlags: Int32;
    messageId: Int32;
    massiveCriticalMessageId: Int32;
  end;

  PCriticalHitDescription = ^TCriticalHitDescription;

implementation

end.
