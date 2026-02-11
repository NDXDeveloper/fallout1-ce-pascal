unit u_perk_defs;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

type
  TPerk = (
    PERK_AWARENESS            = 0,
    PERK_BONUS_HTH_ATTACKS    = 1,
    PERK_BONUS_HTH_DAMAGE     = 2,
    PERK_BONUS_MOVE           = 3,
    PERK_BONUS_RANGED_DAMAGE  = 4,
    PERK_BONUS_RATE_OF_FIRE   = 5,
    PERK_EARLIER_SEQUENCE     = 6,
    PERK_FASTER_HEALING       = 7,
    PERK_MORE_CRITICALS       = 8,
    PERK_NIGHT_VISION         = 9,
    PERK_PRESENCE             = 10,
    PERK_RAD_RESISTANCE       = 11,
    PERK_TOUGHNESS            = 12,
    PERK_STRONG_BACK          = 13,
    PERK_SHARPSHOOTER         = 14,
    PERK_SILENT_RUNNING       = 15,
    PERK_SURVIVALIST          = 16,
    PERK_MASTER_TRADER        = 17,
    PERK_EDUCATED             = 18,
    PERK_HEALER               = 19,
    PERK_FORTUNE_FINDER       = 20,
    PERK_BETTER_CRITICALS     = 21,
    PERK_EMPATHY              = 22,
    PERK_SLAYER               = 23,
    PERK_SNIPER               = 24,
    PERK_SILENT_DEATH         = 25,
    PERK_ACTION_BOY           = 26,
    PERK_MENTAL_BLOCK         = 27,
    PERK_LIFEGIVER            = 28,
    PERK_DODGER               = 29,
    PERK_SNAKEATER            = 30,
    PERK_MR_FIXIT             = 31,
    PERK_MEDIC                = 32,
    PERK_MASTER_THIEF         = 33,
    PERK_SPEAKER              = 34,
    PERK_HEAVE_HO             = 35,
    PERK_FRIENDLY_FOE         = 36,
    PERK_PICKPOCKET           = 37,
    PERK_GHOST                = 38,
    PERK_CULT_OF_PERSONALITY  = 39,
    PERK_SCROUNGER            = 40,
    PERK_EXPLORER             = 41,
    PERK_FLOWER_CHILD         = 42,
    PERK_PATHFINDER           = 43,
    PERK_ANIMAL_FRIEND        = 44,
    PERK_SCOUT                = 45,
    PERK_MYSTERIOUS_STRANGER  = 46,
    PERK_RANGER               = 47,
    PERK_QUICK_POCKETS        = 48,
    PERK_SMOOTH_TALKER        = 49,
    PERK_SWIFT_LEARNER        = 50,
    PERK_TAG                  = 51,
    PERK_MUTATE               = 52,
    PERK_NUKA_COLA_ADDICTION  = 53,
    PERK_BUFFOUT_ADDICTION    = 54,
    PERK_MENTATS_ADDICTION    = 55,
    PERK_PSYCHO_ADDICTION     = 56,
    PERK_RADAWAY_ADDICTION    = 57,
    PERK_WEAPON_LONG_RANGE    = 58,
    PERK_WEAPON_ACCURATE      = 59,
    PERK_WEAPON_PENETRATE     = 60,
    PERK_WEAPON_KNOCKBACK     = 61,
    PERK_POWERED_ARMOR        = 62,
    PERK_COMBAT_ARMOR         = 63,
    PERK_COUNT                = 64
  );
  PPerk = ^TPerk;

implementation

end.
