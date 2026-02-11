unit u_stat_defs;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  PRIMARY_STAT_MIN   = 1;
  PRIMARY_STAT_MAX   = 10;
  PRIMARY_STAT_RANGE = (PRIMARY_STAT_MAX - PRIMARY_STAT_MIN + 1);
  PC_LEVEL_MAX       = 21;

type
  TStat = (
    STAT_STRENGTH                  = 0,
    STAT_PERCEPTION                = 1,
    STAT_ENDURANCE                 = 2,
    STAT_CHARISMA                  = 3,
    STAT_INTELLIGENCE              = 4,
    STAT_AGILITY                   = 5,
    STAT_LUCK                      = 6,
    STAT_MAXIMUM_HIT_POINTS        = 7,
    STAT_MAXIMUM_ACTION_POINTS     = 8,
    STAT_ARMOR_CLASS               = 9,
    STAT_UNARMED_DAMAGE            = 10,
    STAT_MELEE_DAMAGE              = 11,
    STAT_CARRY_WEIGHT              = 12,
    STAT_SEQUENCE                  = 13,
    STAT_HEALING_RATE              = 14,
    STAT_CRITICAL_CHANCE           = 15,
    STAT_BETTER_CRITICALS          = 16,
    STAT_DAMAGE_THRESHOLD          = 17,
    STAT_DAMAGE_THRESHOLD_LASER    = 18,
    STAT_DAMAGE_THRESHOLD_FIRE     = 19,
    STAT_DAMAGE_THRESHOLD_PLASMA   = 20,
    STAT_DAMAGE_THRESHOLD_ELECTRICAL = 21,
    STAT_DAMAGE_THRESHOLD_EMP      = 22,
    STAT_DAMAGE_THRESHOLD_EXPLOSION = 23,
    STAT_DAMAGE_RESISTANCE         = 24,
    STAT_DAMAGE_RESISTANCE_LASER   = 25,
    STAT_DAMAGE_RESISTANCE_FIRE    = 26,
    STAT_DAMAGE_RESISTANCE_PLASMA  = 27,
    STAT_DAMAGE_RESISTANCE_ELECTRICAL = 28,
    STAT_DAMAGE_RESISTANCE_EMP     = 29,
    STAT_DAMAGE_RESISTANCE_EXPLOSION = 30,
    STAT_RADIATION_RESISTANCE      = 31,
    STAT_POISON_RESISTANCE         = 32,
    STAT_AGE                       = 33,
    STAT_GENDER                    = 34,
    STAT_CURRENT_HIT_POINTS        = 35,
    STAT_CURRENT_POISON_LEVEL      = 36,
    STAT_CURRENT_RADIATION_LEVEL   = 37,
    STAT_COUNT                     = 38
  );
  PStat = ^TStat;

const
  PRIMARY_STAT_COUNT  = 7;
  SPECIAL_STAT_COUNT  = 33;
  SAVEABLE_STAT_COUNT = 35;
  STAT_INVALID        = -1;

type
  TPcStat = (
    PC_STAT_UNSPENT_SKILL_POINTS = 0,
    PC_STAT_LEVEL                = 1,
    PC_STAT_EXPERIENCE           = 2,
    PC_STAT_REPUTATION           = 3,
    PC_STAT_KARMA                = 4,
    PC_STAT_COUNT                = 5
  );
  PPcStat = ^TPcStat;

implementation

end.
