unit u_skill_defs;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  NUM_TAGGED_SKILLS     = 4;
  DEFAULT_TAGGED_SKILLS = 3;

type
  TSkill = (
    SKILL_SMALL_GUNS      = 0,
    SKILL_BIG_GUNS        = 1,
    SKILL_ENERGY_WEAPONS  = 2,
    SKILL_UNARMED         = 3,
    SKILL_MELEE_WEAPONS   = 4,
    SKILL_THROWING        = 5,
    SKILL_FIRST_AID       = 6,
    SKILL_DOCTOR          = 7,
    SKILL_SNEAK           = 8,
    SKILL_LOCKPICK        = 9,
    SKILL_STEAL           = 10,
    SKILL_TRAPS           = 11,
    SKILL_SCIENCE         = 12,
    SKILL_REPAIR          = 13,
    SKILL_SPEECH          = 14,
    SKILL_BARTER          = 15,
    SKILL_GAMBLING        = 16,
    SKILL_OUTDOORSMAN     = 17,
    SKILL_COUNT           = 18
  );
  PSkill = ^TSkill;

implementation

end.
