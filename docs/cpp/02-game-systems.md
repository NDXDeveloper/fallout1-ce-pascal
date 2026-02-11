# Fallout 1 Community Edition - Game Systems Technical Reference

This document provides a comprehensive technical reference for the game systems implemented in the Fallout 1 Community Edition C++ source code, located under `src/game/`. It covers data structures, enumerations, constants, function signatures, system interactions, and important global variables.

---

## Table of Contents

1. [Character Stats (stat.cc/h)](#1-character-stats)
2. [Skills (skill.cc/h)](#2-skills)
3. [Perks (perk.cc/h)](#3-perks)
4. [Traits (trait.cc/h)](#4-traits)
5. [Combat System (combat.cc/h)](#5-combat-system)
6. [Combat AI (combatai.cc/h)](#6-combat-ai)
7. [Items and Weapons (item.cc/h)](#7-items-and-weapons)
8. [Inventory (inventry.cc/h)](#8-inventory)
9. [Dialog (gdialog.cc/h)](#9-dialog-system)
10. [World Map (worldmap.cc/h)](#10-world-map)
11. [Save/Load (loadsave.cc/h)](#11-saveload-system)
12. [Animation (anim.cc/h)](#12-animation-system)
13. [Event Queue (queue.cc/h)](#13-event-queue)
14. [Objects (object.cc/h)](#14-object-system)
15. [Prototypes (proto.cc/h)](#15-prototype-system)
16. [Map System (map.cc/h)](#16-map-system)
17. [Critters (critter.cc/h)](#17-critter-system)
18. [Scripts (scripts.cc/h)](#18-script-system)

---

## 1. Character Stats

**Files:** `stat.cc`, `stat.h`, `stat_defs.h`

### Overview

The stat system manages all character attributes: the 7 primary S.P.E.C.I.A.L. stats, derived secondary stats (HP, AC, etc.), and PC-specific stats (level, experience, etc.). Stats are stored as base values and bonus values in the critter's prototype data.

### Key Constants

```cpp
#define PRIMARY_STAT_MIN        1
#define PRIMARY_STAT_MAX        10
#define PRIMARY_STAT_RANGE      10   // MAX - MIN + 1
#define PC_LEVEL_MAX            21
#define PRIMARY_STAT_COUNT      7
#define SPECIAL_STAT_COUNT      33   // primary + all secondary
#define SAVEABLE_STAT_COUNT     35
#define STAT_ERR_INVALID_STAT   -5
```

### Stat Enumeration (38 total stats)

```cpp
typedef enum Stat {
    // Primary (S.P.E.C.I.A.L.) stats: 0-6
    STAT_STRENGTH,              // 0
    STAT_PERCEPTION,            // 1
    STAT_ENDURANCE,             // 2
    STAT_CHARISMA,              // 3
    STAT_INTELLIGENCE,          // 4
    STAT_AGILITY,               // 5
    STAT_LUCK,                  // 6

    // Derived stats: 7-32
    STAT_MAXIMUM_HIT_POINTS,    // 7  = ST + EN*2 + 15
    STAT_MAXIMUM_ACTION_POINTS, // 8  = AG/2 + 5
    STAT_ARMOR_CLASS,           // 9  = AG
    STAT_UNARMED_DAMAGE,        // 10
    STAT_MELEE_DAMAGE,          // 11 = max(ST-5, 1)
    STAT_CARRY_WEIGHT,          // 12 = ST*25 + 25
    STAT_SEQUENCE,              // 13 = PE*2
    STAT_HEALING_RATE,          // 14 = max(EN/3, 1)
    STAT_CRITICAL_CHANCE,       // 15 = LK
    STAT_BETTER_CRITICALS,      // 16
    STAT_DAMAGE_THRESHOLD,      // 17 (Normal)
    STAT_DAMAGE_THRESHOLD_LASER,
    STAT_DAMAGE_THRESHOLD_FIRE,
    STAT_DAMAGE_THRESHOLD_PLASMA,
    STAT_DAMAGE_THRESHOLD_ELECTRICAL,
    STAT_DAMAGE_THRESHOLD_EMP,
    STAT_DAMAGE_THRESHOLD_EXPLOSION,
    STAT_DAMAGE_RESISTANCE,     // 24 (Normal)
    STAT_DAMAGE_RESISTANCE_LASER,
    STAT_DAMAGE_RESISTANCE_FIRE,
    STAT_DAMAGE_RESISTANCE_PLASMA,
    STAT_DAMAGE_RESISTANCE_ELECTRICAL,
    STAT_DAMAGE_RESISTANCE_EMP,
    STAT_DAMAGE_RESISTANCE_EXPLOSION,
    STAT_RADIATION_RESISTANCE,  // 31 = EN*2
    STAT_POISON_RESISTANCE,     // 32 = EN*5
    STAT_AGE,                   // 33 (default: 25)
    STAT_GENDER,                // 34 (0 or 1)

    // Pseudo-stats (current values, not saved in prototype)
    STAT_CURRENT_HIT_POINTS,         // 35
    STAT_CURRENT_POISON_LEVEL,       // 36
    STAT_CURRENT_RADIATION_LEVEL,    // 37
    STAT_COUNT,                      // 38
};
```

### PC-Specific Stats

```cpp
typedef enum PcStat {
    PC_STAT_UNSPENT_SKILL_POINTS,  // 0
    PC_STAT_LEVEL,                 // 1 (min=1, default=1)
    PC_STAT_EXPERIENCE,            // 2
    PC_STAT_REPUTATION,            // 3 (range: -20..20)
    PC_STAT_KARMA,                 // 4
    PC_STAT_COUNT,                 // 5
};
```

### Internal Data Structure

```cpp
typedef struct StatDescription {
    char* name;
    char* description;
    int art_num;
    int minimumValue;
    int maximumValue;
    int defaultValue;
} StatDescription;
```

Each stat has a min, max, and default. Primary stats default to 5 with range [1,10]. Derived stats default to 0 and are recalculated from primaries.

### Derived Stat Formulas (`stat_recalc_derived`)

| Derived Stat | Formula |
|---|---|
| Max HP | `base_ST + base_EN * 2 + 15` |
| Max AP | `AG / 2 + 5` |
| Armor Class | `AG` |
| Melee Damage | `max(ST - 5, 1)` |
| Carry Weight | `ST * 25 + 25` |
| Sequence | `PE * 2` |
| Healing Rate | `max(EN / 3, 1)` |
| Critical Chance | `LK` |
| Better Criticals | `0` |
| Radiation Resistance | `EN * 2` |
| Poison Resistance | `EN * 5` |

### Key Functions

```cpp
int stat_level(Object* critter, int stat);
// Returns effective stat value = base + bonus + special adjustments.
// Special cases:
//   PERCEPTION: -5 if blinded
//   ARMOR_CLASS: +remaining_AP during combat (if not current turn)
//   AGE: +game_years_elapsed
// Result is clamped to [min, max].

int stat_get_base(Object* critter, int stat);
// Returns base stat from prototype + trait adjustments (if dude).

int stat_get_base_direct(Object* critter, int stat);
// Returns raw base stat from prototype, no trait adjustments.

int stat_get_bonus(Object* critter, int stat);
// Returns bonus stat from prototype.

int stat_set_base(Object* critter, int stat, int value);
// Sets base stat. Cannot set derived stats (7-32) directly.
// Recalculates derived stats if a primary stat changes.

void stat_recalc_derived(Object* critter);
// Recalculates all derived stats from current primary stat levels.

int stat_result(Object* critter, int stat, int modifier, int* howMuch);
// Rolls d10 against stat_level + modifier. Returns ROLL_SUCCESS or ROLL_FAILURE.

int stat_pc_add_experience(int xp);
// Adds XP (with Swift Learner bonus: +5% per rank).
// Auto-levels up: HP gain = EN/2 + 2 + Lifegiver*4 per level.
```

### Experience Table

Level-up requires `1000 * exp[level]` total XP, where the table is:
`0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120, 136, 153, 171, 190, 210`

So level 2 needs 1000 XP, level 3 needs 3000 XP, level 21 needs 210000 XP.

### Storage

Stats are stored in `CritterProtoData`:
```cpp
typedef struct CritterProtoData {
    int flags;
    int baseStats[35];   // base values for saveable stats
    int bonusStats[35];  // bonus values for saveable stats
    int skills[18];      // skill point investments
    int bodyType;
    int experience;
    int killType;
} CritterProtoData;
```

### System Interactions

- **Traits** modify base stats via `trait_adjust_stat()` (applied in `stat_get_base()` only for `obj_dude`).
- **Perks** modify bonus stats via `perk_add_effect()` / `perk_remove_effect()`.
- **Skills** use stat levels as modifiers in skill calculations.
- **Combat** reads AC, AP, damage stats, critical chance.
- **Items** (armor) contribute to DT/DR bonus stats.

---

## 2. Skills

**Files:** `skill.cc`, `skill.h`, `skill_defs.h`

### Overview

The skill system manages 18 skills. Each skill's effective level is computed from invested points, governing SPECIAL stats, trait/perk modifiers, tagged skill bonuses, and game difficulty.

### Key Constants

```cpp
#define SKILL_COUNT           18
#define NUM_TAGGED_SKILLS     4
#define DEFAULT_TAGGED_SKILLS 3
#define SKILL_LEVEL_MAX       200
#define SKILLS_MAX_USES_PER_DAY 3
```

### Skill Enumeration

```cpp
typedef enum Skill {
    SKILL_SMALL_GUNS,      // 0  - base 35, governed by AG
    SKILL_BIG_GUNS,        // 1  - base 10, governed by AG
    SKILL_ENERGY_WEAPONS,  // 2  - base 10, governed by AG
    SKILL_UNARMED,         // 3  - base 65, governed by AG+ST
    SKILL_MELEE_WEAPONS,   // 4  - base 55, governed by AG+ST
    SKILL_THROWING,        // 5  - base 40, governed by AG
    SKILL_FIRST_AID,       // 6  - base 30, governed by PE+IN, 25 XP
    SKILL_DOCTOR,          // 7  - base 15, governed by PE+IN, 50 XP
    SKILL_SNEAK,           // 8  - base 25, governed by AG
    SKILL_LOCKPICK,        // 9  - base 20, governed by PE+AG, 25 XP
    SKILL_STEAL,           // 10 - base 20, governed by AG, 25 XP
    SKILL_TRAPS,           // 11 - base 20, governed by PE+AG, 25 XP
    SKILL_SCIENCE,         // 12 - base 25, governed by IN (x2 modifier)
    SKILL_REPAIR,          // 13 - base 20, governed by IN
    SKILL_SPEECH,          // 14 - base 25, governed by CH (x2 modifier)
    SKILL_BARTER,          // 15 - base 20, governed by CH (x2 modifier)
    SKILL_GAMBLING,        // 16 - base 20, governed by LK (x3 modifier)
    SKILL_OUTDOORSMAN,     // 17 - base 5,  governed by EN+IN, 100 XP
    SKILL_COUNT,           // 18
};
```

### Skill Description Structure

```cpp
typedef struct SkillDescription {
    char* name;
    char* description;
    char* attributes;
    int art_num;
    int default_value;      // base percentage
    int stat_modifier;      // multiplier for governing stat(s)
    int stat1;              // primary governing stat
    int stat2;              // secondary governing stat (-1 if none)
    int points_modifier;    // points per invested point
    int experience;         // XP awarded per successful use
    int field_28;           // flag: if true, adds |criticalChanceModifier| to XP
} SkillDescription;
```

### Skill Level Calculation (`skill_level`)

```
effective_level = default_value
                + stat_bonus(stat1, stat2, stat_modifier)
                + invested_points * points_modifier

If critter is obj_dude:
  If tagged: += 20 + invested_points * points_modifier  (doubles point value)
  += trait_adjust_skill(skill)
  += perk_adjust_skill(skill)
  += skill_game_difficulty(skill)

Capped at SKILL_LEVEL_MAX (200).
```

The stat bonus formula:
- If two governing stats: `(stat1_level + stat2_level) * stat_modifier / 2`
- If one governing stat: `stat1_level * stat_modifier`

### Game Difficulty Modifier

For non-combat skills (First Aid through Outdoorsman):
- Easy difficulty: +20
- Normal difficulty: +0
- Hard difficulty: -10

### Skill Check (`skill_result`)

```cpp
int skill_result(Object* critter, int skill, int modifier, int* how_much);
// Uses roll_check(skill_level + modifier, critical_chance, how_much)
// Returns: ROLL_CRITICAL_FAILURE, ROLL_FAILURE, ROLL_SUCCESS, ROLL_CRITICAL_SUCCESS
```

### Stealing Mechanics (`skill_check_stealing`)

Steal chance modifiers:
- `-4%` per item size (unless Pickpocket perk)
- `-25%` if face-to-face (unless Pickpocket perk)
- `+20%` if target is knocked out/down
- `-1%` per previous steal attempt (gStealCount)
- Capped at 95%
- Auto-success against party members
- Critical success = never caught; critical failure = always caught
- Otherwise, defender rolls Steal skill to catch the thief

### Skill Use Limits

First Aid and Doctor have daily use limits tracked in `timesSkillUsed[SKILL_COUNT][3]`. Each skill can be used up to 3 times per 24 game-hour period. Each First Aid use costs 30 minutes of game time; each Doctor use costs 1 hour per healing attempt.

### Key Functions

```cpp
int skill_level(Object* critter, int skill);   // effective skill level
int skill_points(Object* obj, int skill);       // raw invested points
int skill_inc_point(Object* obj, int skill);    // invest 1 skill point
int skill_dec_point(Object* critter, int skill); // remove 1 skill point
void skill_set_tags(int* skills, int count);    // set tagged skills
void skill_get_tags(int* skills, int count);    // get tagged skills
int skill_use(Object* obj, Object* a2, int skill, int a4); // use skill on target
int skill_check_stealing(Object* a1, Object* a2, Object* item, bool isPlanting);
int skill_result(Object* critter, int skill, int modifier, int* how_much);
int skill_contest(Object* attacker, Object* defender, int skill,
                  int attackerModifier, int defenderModifier, int* howMuch);
```

### Important Global Variables

```cpp
extern int gIsSteal;    // flag: currently in steal mode
extern int gStealCount; // number of steal attempts this session
extern int gStealSize;  // cumulative size of stolen items
```

---

## 3. Perks

**Files:** `perk.cc`, `perk.h`, `perk_defs.h`

### Overview

The perk system manages 62 perks (including addictions and weapon perks). Perks are acquired at level-up and provide stat bonuses, skill bonuses, or special gameplay effects. Each perk has prerequisites (level, stats, skills) and a maximum rank.

### Perk Enumeration (62 perks)

```cpp
typedef enum Perk {
    // Player-selectable perks (0-50)
    PERK_AWARENESS,             // 0  - req: PE 5, level 3
    PERK_BONUS_HTH_ATTACKS,     // 1  - req: AG 6, level 6
    PERK_BONUS_HTH_DAMAGE,      // 2  - max 3, gives +2 melee damage
    PERK_BONUS_MOVE,            // 3  - max 3, req: AG 5, level 6
    PERK_BONUS_RANGED_DAMAGE,   // 4  - max 2, +2 damage per rank
    PERK_BONUS_RATE_OF_FIRE,    // 5  - req: PE 6, IN 6, AG 7, level 9
    PERK_EARLIER_SEQUENCE,      // 6  - max 3, +2 sequence
    PERK_FASTER_HEALING,        // 7  - max 3, +1 healing rate
    PERK_MORE_CRITICALS,        // 8  - max 3, +5 critical chance
    PERK_NIGHT_VISION,          // 9  - max 3
    PERK_PRESENCE,              // 10 - max 3
    PERK_RAD_RESISTANCE,        // 11 - max 3, +15 rad resistance
    PERK_TOUGHNESS,             // 12 - max 3, +10 damage resistance
    PERK_STRONG_BACK,           // 13 - max 3, +50 carry weight
    PERK_SHARPSHOOTER,          // 14 - max 2, -2 range penalty
    PERK_SILENT_RUNNING,        // 15 - req: AG 6, Sneak 50
    PERK_SURVIVALIST,           // 16 - max 3, req: EN 6, IN 6, Outdoorsman 40
    PERK_MASTER_TRADER,         // 17 - req: CH 7, Barter 60
    PERK_EDUCATED,              // 18 - max 3, +2 skill points per level
    PERK_HEALER,                // 19 - max 3, +healing with First Aid/Doctor
    PERK_FORTUNE_FINDER,        // 20 - req: LK 8
    PERK_BETTER_CRITICALS,      // 21 - +20 better criticals stat
    PERK_EMPATHY,               // 22 - req: PE 7, IN 5
    PERK_SLAYER,                // 23 - melee always crits, req: ST 8, AG 8, level 18
    PERK_SNIPER,                // 24 - ranged LK-chance crit, req: PE 8, AG 8, level 18
    PERK_SILENT_DEATH,          // 25 - x4 sneak attack damage, req: AG 10, level 18
    PERK_ACTION_BOY,            // 26 - max 3, +1 AP
    PERK_MENTAL_BLOCK,          // 27
    PERK_LIFEGIVER,             // 28 - max 3, +4 HP per level
    PERK_DODGER,                // 29 - max 2, +5 AC
    PERK_SNAKEATER,             // 30 - +25 poison resistance
    PERK_MR_FIXIT,              // 31 - +20 Science/Repair
    PERK_MEDIC,                 // 32 - +20 First Aid/Doctor
    PERK_MASTER_THIEF,          // 33 - +10 Sneak/Lockpick/Steal/Traps
    PERK_SPEAKER,               // 34 - +20 Speech/Barter
    PERK_HEAVE_HO,              // 35 - max 3, +throw range
    PERK_FRIENDLY_FOE,          // 36
    PERK_PICKPOCKET,            // 37 - ignore size/facing in steal
    PERK_GHOST,                 // 38 - +20 Sneak in dark
    PERK_CULT_OF_PERSONALITY,   // 39
    PERK_SCROUNGER,             // 40
    PERK_EXPLORER,              // 41
    PERK_FLOWER_CHILD,          // 42
    PERK_PATHFINDER,            // 43 - max 2, faster travel
    PERK_ANIMAL_FRIEND,         // 44
    PERK_SCOUT,                 // 45
    PERK_MYSTERIOUS_STRANGER,   // 46
    PERK_RANGER,                // 47 - max 3
    PERK_QUICK_POCKETS,         // 48 - max 3
    PERK_SMOOTH_TALKER,         // 49 - max 3
    PERK_SWIFT_LEARNER,         // 50 - max 3, +5% XP per rank
    PERK_TAG,                   // 51 - add another tagged skill
    PERK_MUTATE,                // 52 - change a trait

    // Addiction pseudo-perks (53-57, max_rank = -1)
    PERK_NUKA_COLA_ADDICTION,   // 53
    PERK_BUFFOUT_ADDICTION,     // 54
    PERK_MENTATS_ADDICTION,     // 55
    PERK_PSYCHO_ADDICTION,      // 56
    PERK_RADAWAY_ADDICTION,     // 57

    // Weapon/armor pseudo-perks (58-61, max_rank = -1)
    PERK_WEAPON_LONG_RANGE,     // 58 - doubles perception range modifier
    PERK_WEAPON_ACCURATE,       // 59 - +20 to-hit
    PERK_WEAPON_PENETRATE,      // 60 - ignores DT
    PERK_WEAPON_KNOCKBACK,      // 61 - doubles knockback
    PERK_POWERED_ARMOR,         // 62 - +3 ST
    PERK_COMBAT_ARMOR,          // 63
    PERK_COUNT,                 // 62 (actual count)
};
```

### Perk Description Structure

```cpp
typedef struct PerkDescription {
    char* name;
    char* description;
    int max_rank;                              // -1 = cannot be selected (addiction/weapon perks)
    int min_level;                             // minimum PC level required
    int stat;                                  // stat to modify (-1 if none)
    int stat_modifier;                         // amount to add to stat
    int required_skill;                        // skill requirement (-1 if none)
    int required_skill_level;                  // minimum skill level
    int required_stat_levels[PRIMARY_STAT_COUNT]; // minimum SPECIAL stats (0 = no requirement)
} PerkDescription;
```

### Perk Eligibility Check (`perk_can_add`)

A perk can be added if:
1. `max_rank != -1` (not an addiction/weapon perk)
2. Current rank < max_rank
3. PC level >= min_level
4. Required skill level met (if any)
5. All SPECIAL stat requirements met

### Perk Effects

When a perk is added (`perk_add_effect`):
- If `stat != -1`: adds `stat_modifier` to the bonus value of that stat
- If `max_rank == -1` (addiction/weapon perks): the `required_stat_levels` array is used as bonus/penalty to primary stats

Skill bonuses are computed dynamically via `perk_adjust_skill`:

| Perk | Skill Bonus |
|---|---|
| Medic | +20 First Aid, +20 Doctor |
| Ghost | +20 Sneak (if light <= 45875) |
| Master Thief | +10 Sneak, Lockpick, Steal, Traps |
| Mr. Fixit | +20 Science, +20 Repair |
| Speaker | +20 Speech, +20 Barter |

### Key Functions

```cpp
int perk_add(int perk);           // Add perk if eligible, apply effects
int perk_sub(int perk);           // Remove perk, undo effects
int perk_level(int perk);         // Current rank (0 = not taken)
int perk_make_list(int* perks);   // List of available perks to pick
void perk_add_effect(Object* critter, int perk);    // Apply stat bonuses
void perk_remove_effect(Object* critter, int perk); // Remove stat bonuses
int perk_adjust_skill(int skill); // Compute total perk skill bonus
```

---

## 4. Traits

**Files:** `trait.cc`, `trait.h`

### Overview

Traits are optional character modifiers selected at creation (up to 2). Unlike perks, traits have both positive and negative effects. They modify stats and skills through `trait_adjust_stat()` and `trait_adjust_skill()`, which are called during stat/skill level computation.

### Key Constants

```cpp
#define PC_TRAIT_MAX  2   // max number of selectable traits
#define TRAIT_COUNT   16
```

### Trait Enumeration

```cpp
typedef enum Trait {
    TRAIT_FAST_METABOLISM,   // 0  - +2 healing rate, zero rad/poison resistance
    TRAIT_BRUISER,           // 1  - +2 ST, -2 AP
    TRAIT_SMALL_FRAME,       // 2  - +1 AG, -10*ST carry weight
    TRAIT_ONE_HANDER,        // 3  - +20 one-handed accuracy, -40 two-handed
    TRAIT_FINESSE,           // 4  - +10 crit chance, +30% DR to all attacks
    TRAIT_KAMIKAZE,          // 5  - +5 sequence, zero AC
    TRAIT_HEAVY_HANDED,      // 6  - +4 melee damage, -30 better criticals
    TRAIT_FAST_SHOT,         // 7  - -1 AP cost for ranged, no called shots
    TRAIT_BLOODY_MESS,       // 8  - violent death animations
    TRAIT_JINXED,            // 9  - failures become critical failures (50% chance)
    TRAIT_GOOD_NATURED,      // 10 - +15 non-combat skills, -10 combat skills
    TRAIT_CHEM_RELIANT,      // 11 - double addiction chance, double duration
    TRAIT_CHEM_RESISTANT,    // 12 - half addiction chance, half duration
    TRAIT_NIGHT_PERSON,      // 13 - +1 IN/PE at night (1800-0600), -1 during day
    TRAIT_SKILLED,           // 14 - +10 all skills, perk every 4 levels
    TRAIT_GIFTED,            // 15 - +1 to all SPECIAL, -10 all skills, -5 skill points/level
    TRAIT_COUNT,             // 16
};
```

### Trait Stat Adjustments

`trait_adjust_stat(int stat)` returns a modifier based on selected traits:

| Stat | Trait | Modifier |
|---|---|---|
| Strength | Gifted | +1 |
| Strength | Bruiser | +2 |
| Perception | Gifted | +1 |
| Perception | Night Person | +1 (night) / -1 (day) |
| Endurance | Gifted | +1 |
| Charisma | Gifted | +1 |
| Intelligence | Gifted | +1 |
| Intelligence | Night Person | +1 (night) / -1 (day) |
| Agility | Gifted | +1 |
| Agility | Small Frame | +1 |
| Luck | Gifted | +1 |
| Max AP | Bruiser | -2 |
| Armor Class | Kamikaze | -(base AC) |
| Melee Damage | Heavy Handed | +4 |
| Carry Weight | Small Frame | -10 * ST |
| Sequence | Kamikaze | +5 |
| Healing Rate | Fast Metabolism | +2 |
| Critical Chance | Finesse | +10 |
| Better Criticals | Heavy Handed | -30 |
| Rad Resistance | Fast Metabolism | -(base value) |
| Poison Resistance | Fast Metabolism | -(base value) |

Night is defined as `game_time_hour() - 600 >= 1200` (i.e., after 6 PM or before 6 AM).

### Trait Skill Adjustments

`trait_adjust_skill(int skill)` returns a modifier:

- **Gifted**: -10 to all skills
- **Skilled**: +10 to all skills
- **Good Natured**: -10 to combat skills (Small Guns, Big Guns, Energy Weapons, Unarmed, Melee, Throwing), +15 to non-combat skills (First Aid, Doctor, Speech, Barter)

### Key Functions

```cpp
void trait_set(int trait1, int trait2);    // Set selected traits
void trait_get(int* trait1, int* trait2);  // Get selected traits
int trait_level(int trait);                // Returns 1 if selected, 0 otherwise
int trait_adjust_stat(int stat);           // Stat modifier from traits
int trait_adjust_skill(int skill);         // Skill modifier from traits
```

---

## 5. Combat System

**Files:** `combat.cc`, `combat.h`, `combat_defs.h`

### Overview

The combat system implements Fallout's turn-based tactical combat with action points, to-hit calculations, damage computation, critical hits/failures, burst fire, knockback, and death checks.

### Combat State

```cpp
typedef enum CombatState {
    COMBAT_STATE_0x01 = 0x01,  // in combat
    COMBAT_STATE_0x02 = 0x02,  // combat initialized
    COMBAT_STATE_0x08 = 0x08,
};

static inline bool isInCombat() {
    return (combat_state & COMBAT_STATE_0x01) != 0;
}
```

### Hit Modes (20 modes)

```cpp
typedef enum HitMode {
    HIT_MODE_LEFT_WEAPON_PRIMARY = 0,
    HIT_MODE_LEFT_WEAPON_SECONDARY = 1,
    HIT_MODE_RIGHT_WEAPON_PRIMARY = 2,
    HIT_MODE_RIGHT_WEAPON_SECONDARY = 3,
    HIT_MODE_PUNCH = 4,
    HIT_MODE_KICK = 5,
    HIT_MODE_LEFT_WEAPON_RELOAD = 6,
    HIT_MODE_RIGHT_WEAPON_RELOAD = 7,
    // Advanced unarmed: 8-19 (unlocked by skill level)
    HIT_MODE_STRONG_PUNCH = 8,     // Punch Level 2
    HIT_MODE_HAMMER_PUNCH = 9,     // Punch Level 3
    HIT_MODE_HAYMAKER = 10,        // Lightning Punch
    HIT_MODE_JAB = 11,             // Chop Punch
    HIT_MODE_PALM_STRIKE = 12,     // Dragon Punch
    HIT_MODE_PIERCING_STRIKE = 13, // Force Punch
    HIT_MODE_STRONG_KICK = 14,     // Kick Level 2
    HIT_MODE_SNAP_KICK = 15,       // Kick Level 3
    HIT_MODE_POWER_KICK = 16,      // Roundhouse Kick
    HIT_MODE_HIP_KICK = 17,        // Kick Level 5
    HIT_MODE_HOOK_KICK = 18,       // Jump Kick
    HIT_MODE_PIERCING_KICK = 19,   // Death Blossom Kick
    HIT_MODE_COUNT = 20,
};
```

### Hit Locations (9 locations)

```cpp
typedef enum HitLocation {
    HIT_LOCATION_HEAD,          // 0, penalty: -40
    HIT_LOCATION_LEFT_ARM,      // 1, penalty: -30
    HIT_LOCATION_RIGHT_ARM,     // 2, penalty: -30
    HIT_LOCATION_TORSO,         // 3, penalty:   0
    HIT_LOCATION_RIGHT_LEG,     // 4, penalty: -20
    HIT_LOCATION_LEFT_LEG,      // 5, penalty: -20
    HIT_LOCATION_EYES,          // 6, penalty: -60
    HIT_LOCATION_GROIN,         // 7, penalty: -30
    HIT_LOCATION_UNCALLED,      // 8, penalty:   0 (no called shot)
    HIT_LOCATION_COUNT = 9,
    HIT_LOCATION_SPECIFIC_COUNT = 8,
};
```

### Attack Structure

```cpp
typedef struct Attack {
    Object* attacker;
    int hitMode;
    Object* weapon;
    int attackHitLocation;
    int attackerDamage;       // damage dealt to attacker (crit fail)
    int attackerFlags;        // DAM_* flags for attacker
    int ammoQuantity;         // rounds consumed
    int criticalMessageId;
    Object* defender;
    int tile;                 // target tile (for misses)
    int defenderHitLocation;
    int defenderDamage;       // damage dealt to defender
    int defenderFlags;        // DAM_* flags for defender
    int defenderKnockback;    // knockback distance
    Object* oops;             // unintended target (friendly fire)
    int extrasLength;         // number of explosion extras
    Object* extras[6];        // extra targets (explosions)
    int extrasHitLocation[6];
    int extrasDamage[6];
    int extrasFlags[6];
    int extrasKnockback[6];
} Attack;
```

### Damage Flags

```cpp
typedef enum Dam {
    DAM_KNOCKED_OUT     = 0x01,
    DAM_KNOCKED_DOWN    = 0x02,
    DAM_CRIP_LEG_LEFT   = 0x04,
    DAM_CRIP_LEG_RIGHT  = 0x08,
    DAM_CRIP_ARM_LEFT   = 0x10,
    DAM_CRIP_ARM_RIGHT  = 0x20,
    DAM_BLIND           = 0x40,
    DAM_DEAD            = 0x80,
    DAM_HIT             = 0x100,
    DAM_CRITICAL        = 0x200,
    DAM_ON_FIRE         = 0x400,
    DAM_BYPASS          = 0x800,    // bypass DT/DR
    DAM_EXPLODE         = 0x1000,
    DAM_DESTROY         = 0x2000,
    DAM_DROP            = 0x4000,
    DAM_LOSE_TURN       = 0x8000,
    DAM_HIT_SELF        = 0x10000,
    DAM_LOSE_AMMO       = 0x20000,
    DAM_DUD             = 0x40000,
    DAM_HURT_SELF       = 0x80000,
    DAM_RANDOM_HIT      = 0x100000,
    DAM_CRIP_RANDOM     = 0x200000,
    DAM_BACKWASH        = 0x400000,
    DAM_PERFORM_REVERSE = 0x800000,
};
```

### To-Hit Calculation (`determine_to_hit_func`)

The accuracy calculation follows these steps:

1. **Base accuracy** = weapon skill level (or Unarmed skill if no weapon)
2. **Range penalty** (ranged weapons only):
   - Distance beyond `perception_modifier * PE` is penalized at `-4` per hex
   - Below `-2 * PE` range, no further penalty
   - Sharpshooter: -2 from range penalty per rank
   - Weapon Long Range perk: `perception_modifier = 4` instead of 2
   - If blinded: `-12` per hex (instead of -4)
3. **Obstruction penalty**: `-10` per blocking object in the line of fire
4. **One Hander trait**: `+20` one-handed / `-40` two-handed
5. **Minimum strength penalty**: `-20` per point below weapon's min ST
6. **Weapon Accurate perk**: `+20`
7. **Defender's AC**: subtracted from accuracy
8. **Called shot penalty**: hit location penalty applied (full for ranged, halved for melee)
9. **Multihex targets**: `+15`
10. **Lighting** (player only):
    - Very dark (<=26214): `-40`
    - Dark (<=39321): `-25`
    - Dim (<=52428): `-10`
11. **Attacker blindness**: `-25`
12. **Defender knocked out/down**: `+40`
13. **Combat difficulty** (for non-player teams):
    - Easy: `-20`
    - Hard: `+20`
14. **Cap**: Maximum 95%, minimum -100%

### Damage Calculation (`compute_damage`)

For each round hitting the target:

```
round_damage = item_w_damage(attacker, hitMode) + bonus_ranged_damage
round_damage *= damage_multiplier   // 2 normal, higher for crits
round_damage /= 2
round_damage *= combat_difficulty_multiplier  // 75/100/125
round_damage /= 100
round_damage -= damage_threshold
if round_damage > 0:
    round_damage -= round_damage * damage_resistance / 100
    if round_damage > 0:
        total_damage += round_damage
```

Key modifiers:
- **Bonus Ranged Damage perk**: `+2` per rank (ranged only)
- **Finesse trait**: `+30` to DR
- **DAM_BYPASS flag**: sets both DT and DR to 0
- **Weapon Penetrate perk**: sets DT to 0
- **Combat difficulty multiplier**: 75% (easy), 100% (normal), 125% (hard) -- applied only to non-player-team attackers
- **Knockback**: `damage / 10` hexes (or `/5` with Weapon Knockback perk)

### Critical Hits (`attack_crit_success`)

1. Roll 1-100 + STAT_BETTER_CRITICALS
2. Determine effect tier: <=20 (0), <=45 (1), <=70 (2), <=90 (3), <=100 (4), >100 (5)
3. Look up `CriticalHitDescription` from kill-type-specific table
4. Apply damage multiplier, flags, and check for massive critical (stat check)
5. Returns the damage multiplier (replaces the default 2)

```cpp
typedef struct CriticalHitDescription {
    int damageMultiplier;           // replaces default x2
    int flags;                      // DAM_* flags applied to defender
    int massiveCriticalStat;        // stat to check for massive crit (-1 = none)
    int massiveCriticalStatModifier; // bonus/penalty to stat check
    int massiveCriticalFlags;       // additional flags if massive crit
    int messageId;
    int massiveCriticalMessageId;
} CriticalHitDescription;
```

There are separate critical hit tables for:
- 15 kill types (Man, Woman, Child, Super Mutant, Ghoul, Brahmin, Radscorpion, Rat, Floater, Centaur, Robot, Dog, Mantis, Deathclaw, Plant)
- 9 hit locations each
- 6 effect tiers each
- Plus a separate `pc_crit_succ_eff` table for hits against the player

### Critical Failures (`attack_crit_failure`)

```
chance = roll_random(1,100) - 5 * (LK - 5)
Effect tier: <=20(0), <=50(1), <=75(2), <=95(3), else(4)
Flags from cf_table[weapon_crit_fail_type][effect]
```

The `cf_table` has 7 weapon critical failure types and 5 effects each. Effects include:
- `DAM_LOSE_TURN`, `DAM_DROP`, `DAM_LOSE_AMMO`
- `DAM_RANDOM_HIT`, `DAM_HIT_SELF`, `DAM_HURT_SELF`
- `DAM_DESTROY`, `DAM_EXPLODE`, `DAM_DUD`

### Special Perk Effects in Combat

- **Slayer**: melee/unarmed SUCCESS always becomes CRITICAL SUCCESS
- **Sniper**: ranged SUCCESS has LK/10 chance to become CRITICAL SUCCESS
- **Silent Death**: x4 damage multiplier (instead of x2) when sneaking from behind
- **Jinxed trait**: 50% chance that FAILURE becomes CRITICAL FAILURE

### Key Functions

```cpp
int combat_init();
void combat(STRUCT_664980* attack);               // Enter combat
void combat_ctd_init(Attack* attack, Object* attacker,
                     Object* defender, int hitMode, int hitLocation);
int combat_attack(Object* a1, Object* a2, int hitMode, int location);
int determine_to_hit(Object* a1, Object* a2, int hitLocation, int hitMode);
int determine_to_hit_no_range(Object* a1, Object* a2, int hitLocation, int hitMode);
void compute_explosion_on_extras(Attack* attack, int a2, bool isGrenade, int a4);
void death_checks(Attack* attack);
void apply_damage(Attack* attack, bool animated);
int combat_check_bad_shot(Object* attacker, Object* defender,
                          int hitMode, bool aiming);
void combat_give_exps(int exp_points);
```

### Important Global Variables

```cpp
extern unsigned int combat_state;        // current combat state flags
extern STRUCT_664980* gcsd;              // combat setup data (bonuses)
extern Object* combat_turn_obj;          // whose turn it is
extern int combat_exps;                  // XP earned this combat
extern int combat_free_move;             // free moves remaining
extern MessageList combat_message_file;  // combat.msg
```

---

## 6. Combat AI

**Files:** `combatai.cc`, `combatai.h`

### Overview

The combat AI system controls NPC behavior during combat. It uses AI packets loaded from `ai.txt` that define behavior parameters like aggression, minimum to-hit threshold, weapon preferences, and fleeing conditions.

### AI Packet Structure

```cpp
typedef struct AiPacket {
    char* name;
    int packet_num;
    int max_dist;          // maximum engagement distance
    int min_to_hit;        // minimum acceptable to-hit chance
    int min_hp;            // HP threshold for fleeing
    int aggression;        // aggression level
    int hurt_too_much;     // damage threshold flags
    int secondary_freq;    // frequency of using secondary attack
    int called_freq;       // frequency of called shots
    int font;              // message display font
    int color;             // message text color
    int outline_color;     // message outline color
    int chance;            // chance to display combat message
    int run_start;         // run message range start
    int move_start;        // move message range start
    int attack_start;      // attack message range start
    int miss_start;        // miss message range start
    int hit_start[8];      // hit message ranges per body part
    int last_msg;          // last message index
} AiPacket;
```

### AI Message Types

```cpp
typedef enum AiMessageType {
    AI_MESSAGE_TYPE_RUN,
    AI_MESSAGE_TYPE_MOVE,
    AI_MESSAGE_TYPE_ATTACK,
    AI_MESSAGE_TYPE_MISS,
    AI_MESSAGE_TYPE_HIT,
};
```

### Hurt-Too-Much Flags

```cpp
typedef enum HurtTooMuch {
    HURT_BLIND,
    HURT_CRIPPLED,
    HURT_CRIPPLED_LEGS,
    HURT_CRIPPLED_ARMS,
    HURT_COUNT = 4,
};
```

### AI Decision Process

The AI system performs these key decision steps (in `combat_ai`):
1. **Danger assessment** (`ai_danger_source`): identify the most threatening enemy
2. **Drug use** (`ai_check_drugs`): use healing items if hurt
3. **Weapon selection** (`ai_switch_weapons`, `ai_best_weapon`): pick the best available weapon
4. **Attack or flee** (`ai_try_attack` vs `ai_run_away`): based on HP, aggression, damage state
5. **Called shot selection** (`ai_called_shot`): choose hit location based on `called_freq`
6. **Movement** (`ai_move_closer`): approach target within weapon range

### Key Functions

```cpp
int combat_ai_init();
Object* ai_danger_source(Object* critter);    // Find most dangerous enemy
Object* ai_search_inven(Object* critter, int check_action_points); // Search inventory
void combat_ai_begin(int critters_count, Object** critters);
Object* combat_ai(Object* critter, Object* target);  // Main AI decision
bool combatai_want_to_join(Object* critter);   // Will NPC join combat?
bool combatai_want_to_stop(Object* critter);   // Will NPC stop fighting?
int combatai_switch_team(Object* critter, int team);
int combatai_msg(Object* critter, Attack* attack, int message_type, int delay);
bool is_within_perception(Object* critter1, Object* critter2);
void combatai_check_retaliation(Object* critter, Object* candidate);
void combatai_notify_onlookers(Object* critter);
```

---

## 7. Items and Weapons

**Files:** `item.cc`, `item.h`

### Overview

The item system manages all object types that can be carried: weapons, armor, drugs, ammo, containers, misc items, and keys. It provides functions for weapon statistics, ammunition management, drug effects, and item manipulation.

### Item Types

```cpp
enum {
    ITEM_TYPE_ARMOR,      // 0
    ITEM_TYPE_CONTAINER,  // 1
    ITEM_TYPE_DRUG,       // 2
    ITEM_TYPE_WEAPON,     // 3
    ITEM_TYPE_AMMO,       // 4
    ITEM_TYPE_MISC,       // 5
    ITEM_TYPE_KEY,        // 6
    ITEM_TYPE_COUNT = 7,
};
```

### Attack Types

```cpp
typedef enum AttackType {
    ATTACK_TYPE_NONE,
    ATTACK_TYPE_UNARMED,
    ATTACK_TYPE_MELEE,
    ATTACK_TYPE_THROW,
    ATTACK_TYPE_RANGED,
    ATTACK_TYPE_COUNT = 5,
};
```

### Damage Types

```cpp
enum {
    DAMAGE_TYPE_NORMAL,
    DAMAGE_TYPE_LASER,
    DAMAGE_TYPE_FIRE,
    DAMAGE_TYPE_PLASMA,
    DAMAGE_TYPE_ELECTRICAL,
    DAMAGE_TYPE_EMP,
    DAMAGE_TYPE_EXPLOSION,
    DAMAGE_TYPE_COUNT = 7,
};
```

### Caliber Types

```cpp
enum {
    CALIBER_TYPE_NONE,
    CALIBER_TYPE_ROCKET,
    CALIBER_TYPE_FLAMETHROWER_FUEL,
    CALIBER_TYPE_C_ENERGY_CELL,
    CALIBER_TYPE_D_ENERGY_CELL,
    CALIBER_TYPE_223,
    CALIBER_TYPE_5_MM,
    CALIBER_TYPE_40_CAL,
    CALIBER_TYPE_10_MM,
    CALIBER_TYPE_44_CAL,
    CALIBER_TYPE_14_MM,
    CALIBER_TYPE_12_GAUGE,
    CALIBER_TYPE_9_MM,
    CALIBER_TYPE_BB,
    CALIBER_TYPE_COUNT = 14,
};
```

### Weapon Prototype Data

```cpp
typedef struct ProtoItemWeaponData {
    int animationCode;       // weapon animation type
    int minDamage;
    int maxDamage;
    int damageType;          // DAMAGE_TYPE_*
    int maxRange1;           // primary attack range
    int maxRange2;           // secondary attack range
    int projectilePid;       // projectile prototype ID
    int minStrength;         // minimum ST to wield
    int actionPointCost1;    // AP cost for primary attack
    int actionPointCost2;    // AP cost for secondary attack
    int criticalFailureType; // index into cf_table
    int perk;                // weapon perk (PERK_WEAPON_*)
    int rounds;              // rounds per burst
    int caliber;             // CALIBER_TYPE_*
    int ammoTypePid;         // ammo prototype PID
    int ammoCapacity;        // magazine size
    unsigned char soundCode; // weapon sound identifier
} ProtoItemWeaponData;
```

### Ammo Prototype Data

```cpp
typedef struct ProtoItemAmmoData {
    int caliber;
    int quantity;                // rounds per box
    int armorClassModifier;      // AC adjustment
    int damageResistanceModifier; // DR adjustment
    int damageMultiplier;        // damage multiplier
    int damageDivisor;           // damage divisor
} ProtoItemAmmoData;
```

### Drug Prototype Data

```cpp
typedef struct ProtoItemDrugData {
    int stat[3];             // stats affected
    int amount[3];           // immediate effect amounts
    int duration1;           // first delayed effect time
    int amount1[3];          // first delayed effect amounts
    int duration2;           // second delayed effect time
    int amount2[3];          // second delayed effect amounts
    int addictionChance;     // percentage chance of addiction
    int withdrawalEffect;    // withdrawal perk applied
    int withdrawalOnset;     // time until withdrawal
} ProtoItemDrugData;
```

### Armor Prototype Data

```cpp
typedef struct ProtoItemArmorData {
    int armorClass;
    int damageResistance[7]; // one per damage type
    int damageThreshold[7];  // one per damage type
    int perk;                // armor perk
    int maleFid;             // male character FID
    int femaleFid;           // female character FID
} ProtoItemArmorData;
```

### Key Weapon Functions

```cpp
int item_w_damage(Object* critter, int hit_mode);   // Roll weapon damage
int item_w_damage_min_max(Object* weapon, int* min, int* max);
int item_w_damage_type(Object* weapon);              // DAMAGE_TYPE_*
int item_w_range(Object* critter, int hit_mode);     // Effective range
int item_w_mp_cost(Object* critter, int hit_mode, bool aiming); // AP cost
int item_w_subtype(Object* a1, int a2);              // ATTACK_TYPE_*
int item_w_skill(Object* a1, int a2);                // Required skill
int item_w_skill_level(Object* a1, int a2);           // Attacker's skill level
int item_w_is_2handed(Object* weapon);               // Two-handed check
int item_w_perk(Object* weapon);                     // Weapon perk
int item_w_rounds(Object* weapon);                   // Rounds per burst
int item_w_crit_fail(Object* weapon);                // Critical failure table index
int item_w_min_st(Object* weapon);                   // Minimum strength
int item_w_caliber(Object* ammoOrWeapon);            // Caliber type
int item_w_max_ammo(Object* ammoOrWeapon);           // Magazine capacity
int item_w_curr_ammo(Object* ammoOrWeapon);          // Current ammo count
int item_w_try_reload(Object* critter, Object* weapon); // Attempt reload
bool item_w_can_reload(Object* weapon, Object* ammo);   // Can reload check
int item_w_called_shot(Object* critter, int hit_mode);  // Can do called shot
Object* item_w_unload(Object* weapon);               // Unload ammo from weapon
```

### Key Armor Functions

```cpp
int item_ar_ac(Object* armor);                    // Armor class bonus
int item_ar_dr(Object* armor, int damageType);    // Damage resistance
int item_ar_dt(Object* armor, int damageType);    // Damage threshold
int item_ar_perk(Object* armor);                  // Armor perk
int item_ar_male_fid(Object* armor);              // Male appearance FID
int item_ar_female_fid(Object* armor);            // Female appearance FID
```

### Key Drug Functions

```cpp
int item_d_take_drug(Object* critter_obj, Object* item_obj); // Apply drug
int item_d_process(Object* obj, void* data);   // Process delayed drug effect
int item_d_clear(Object* obj, void* data);     // Clear drug effect (withdrawal)
void item_d_set_addict(int drugPid);           // Flag addiction
void item_d_unset_addict(int drugPid);         // Clear addiction
bool item_d_check_addict(int drugPid);         // Check if addicted
```

### Item Management Functions

```cpp
int item_add_mult(Object* owner, Object* item, int quantity);
int item_add_force(Object* owner, Object* item, int quantity);
int item_remove_mult(Object* a1, Object* a2, int quantity);
int item_move(Object* a1, Object* a2, Object* a3, int quantity);
void item_move_all(Object* a1, Object* a2);
int item_get_type(Object* item);           // ITEM_TYPE_*
int item_size(Object* obj);                // Size in inventory
int item_weight(Object* item);             // Weight in pounds
int item_cost(Object* obj);                // Base cost
int item_total_cost(Object* obj);          // Cost including contents
int item_total_weight(Object* obj);        // Weight including contents
int item_caps_total(Object* obj);          // Total bottle caps
int item_caps_adjust(Object* obj, int amount); // Add/remove caps
Object* item_hit_with(Object* critter, int hit_mode); // Get weapon for hit mode
```

---

## 8. Inventory

**Files:** `inventry.cc`, `inventry.h`

### Overview

The inventory system handles the UI and logic for managing items: the main inventory screen, looting containers/corpses, bartering, and item equipping. It supports multiple window types and cursor modes.

### Inventory Data Structure

```cpp
typedef struct InventoryItem {
    Object* item;
    int quantity;
} InventoryItem;

typedef struct Inventory {
    int length;        // number of distinct item stacks
    int capacity;      // allocated capacity
    InventoryItem* items;
} Inventory;
```

### Window Types

```cpp
typedef enum InventoryWindowType {
    INVENTORY_WINDOW_TYPE_NORMAL,         // Standard inventory + character sheet
    INVENTORY_WINDOW_TYPE_USE_ITEM_ON,    // Narrow "use item on" scroller
    INVENTORY_WINDOW_TYPE_LOOT,           // Looting/stealing interface
    INVENTORY_WINDOW_TYPE_TRADE,          // Barter interface
    INVENTORY_WINDOW_TYPE_MOVE_ITEMS,     // Quantity selector
    INVENTORY_WINDOW_TYPE_SET_TIMER,      // Timer overlay (explosives)
    INVENTORY_WINDOW_TYPE_COUNT = 6,
};
```

### Cursor Modes

```cpp
typedef enum InventoryWindowCursor {
    INVENTORY_WINDOW_CURSOR_HAND,   // Default hand cursor
    INVENTORY_WINDOW_CURSOR_ARROW,  // Arrow cursor
    INVENTORY_WINDOW_CURSOR_PICK,   // Pickup cursor
    INVENTORY_WINDOW_CURSOR_MENU,   // Context menu
    INVENTORY_WINDOW_CURSOR_BLANK,  // Hidden cursor
    INVENTORY_WINDOW_CURSOR_COUNT = 5,
};
```

### Key Functions

```cpp
// Inventory management
void handle_inventory();                          // Main inventory loop
Object* inven_right_hand(Object* obj);            // Right hand item
Object* inven_left_hand(Object* obj);             // Left hand item
Object* inven_worn(Object* obj);                  // Worn armor
int inven_wield(Object* critter, Object* item, int a3);  // Equip item
int inven_unwield(Object* critter, int a2);       // Unequip item
Object* inven_find_type(Object* obj, int a2, int* inout_a3); // Find by type
Object* inven_find_id(Object* obj, int a2);       // Find by object ID
int inven_pid_is_carried(Object* obj, int pid);   // Check if PID is carried
int inven_pid_quantity_carried(Object* obj, int pid); // Count of PID carried
void adjust_ac(Object* critter, Object* oldArmor, Object* newArmor); // Update AC
void adjust_fid();                                 // Update character appearance

// Container interactions
int loot_container(Object* a1, Object* a2);       // Loot interface
int inven_steal_container(Object* a1, Object* a2); // Steal interface
int move_inventory(Object* a1, int a2, Object* a3, bool a4); // Move items
void barter_inventory(int win, Object* a2, Object* a3, Object* a4, int a5);
int drop_into_container(Object* a1, Object* a2, int a3, Object** a4, int quantity);
int drop_ammo_into_weapon(Object* weapon, Object* ammo, Object** a3,
                          int quantity, int keyCode);

// Display
void display_inventory(int a1, int a2, int inventoryWindowType);
void display_target_inventory(int a1, int a2, Inventory* a3, int a4);
void display_body(int fid, int inventoryWindowType);
void display_stats();

// Timer
int inven_set_timer(Object* a1);  // Set explosive timer
```

---

## 9. Dialog System

**Files:** `gdialog.cc`, `gdialog.h`

### Overview

The dialog system manages NPC conversations with a reply-and-options structure. It supports talking head animations, lip sync, dialog review history, barter mode, and script-driven dialog trees.

### Key Constants

```cpp
#define GAME_DIALOG_WINDOW_WIDTH          640
#define GAME_DIALOG_WINDOW_HEIGHT         480
#define GAME_DIALOG_REPLY_WINDOW_WIDTH    379
#define GAME_DIALOG_REPLY_WINDOW_HEIGHT   58
#define GAME_DIALOG_OPTIONS_WINDOW_WIDTH  393
#define GAME_DIALOG_OPTIONS_WINDOW_HEIGHT 117
#define DIALOG_REVIEW_ENTRIES_CAPACITY    80
#define DIALOG_OPTION_ENTRIES_CAPACITY    30
```

### Reaction Types

```cpp
typedef enum GameDialogReaction {
    GAME_DIALOG_REACTION_GOOD    = 49,
    GAME_DIALOG_REACTION_NEUTRAL = 50,
    GAME_DIALOG_REACTION_BAD     = 51,
};
```

### Dialog Entry Structures

```cpp
typedef struct GameDialogReviewEntry {
    int replyMessageListId;
    int replyMessageId;
    char* replyText;           // can be NULL
    int optionMessageListId;
    int optionMessageId;
    char* optionText;
} GameDialogReviewEntry;

typedef struct GameDialogOptionEntry {
    int messageListId;
    int messageId;
    char* text;
    int reaction;              // GOOD/NEUTRAL/BAD
    int proc;                  // callback procedure index
    int btn;                   // button ID
    int field_18;
};
```

### Key Functions

```cpp
// Dialog lifecycle
int gdialog_init();
void gdialog_enter(Object* target, int a2);    // Start dialog with NPC
void dialogue_system_enter();                   // Enter dialog system
bool dialog_active();                           // Is dialog currently active?

// Script interface (called from scripts)
int scr_dialogue_init(int headFid, int reaction);   // Init talking head
int scr_dialogue_exit();                              // End dialog session
int gDialogStart();                                   // Begin dialog tree
int gDialogGo();                                      // Execute dialog tree

// Reply/option building (called from scripts)
int gDialogReply(Program* program, int messageListId, int messageId);
int gDialogReplyStr(Program* program, int messageListId, const char* text);
int gDialogOption(int messageListId, int messageId, const char* proc, int reaction);
int gDialogOptionStr(int messageListId, const char* text, const char* proc, int reaction);
int gDialogOptionProc(int messageListId, int messageId, int proc, int reaction);

// Barter
void gdialogSetBarterMod(int modifier);
int gdActivateBarter(int modifier);
void barter_end_to_talk_to();

// Speech audio
void gdialog_setup_speech(const char* audioFileName);
void gdialog_free_speech();
void talk_to_critter_reacts(int a1);
```

### Important Global Variables

```cpp
extern Object* dialog_target;          // NPC being talked to
extern bool dialog_target_is_party;    // Is target a party member?
extern int dialogue_head;              // Talking head FID
extern int dialogue_scr_id;           // Script ID for dialog
```

### System Interactions

- **Scripts** drive dialog content via `gDialogReply` / `gDialogOption`
- **Reaction** system (`reaction.cc`) determines NPC disposition
- **Lip sync** system (`lip_sync.cc`) syncs mouth animation to audio
- **Barter** system integrates with inventory for trading
- **Skills** (Speech, Barter) affect dialog outcomes

---

## 10. World Map

**Files:** `worldmap.cc`, `worldmap.h`

### Overview

The world map system handles overland travel between locations, random encounters, and the town map sub-screens. The world map is a 1400-pixel-wide scrollable image with marked locations.

### Key Constants

```cpp
#define WM_WINDOW_WIDTH      640
#define WM_WINDOW_HEIGHT     480
#define WM_WORLDMAP_WIDTH    1400
#define TOWN_COUNT           12    // + 3 special locations
#define MAP_COUNT            63    // total map definitions
#define VIEWPORT_MAX_X       950
#define VIEWPORT_MAX_Y       1058
```

### Town Enumeration

```cpp
typedef enum City {
    TOWN_VAULT_13 = 0,
    TOWN_VAULT_15 = 1,
    TOWN_SHADY_SANDS = 2,
    TOWN_JUNKTOWN = 3,
    TOWN_RAIDERS = 4,
    TOWN_NECROPOLIS = 5,
    TOWN_THE_HUB = 6,
    TOWN_BROTHERHOOD = 7,
    TOWN_MILITARY_BASE = 8,
    TOWN_THE_GLOW = 9,
    TOWN_BONEYARD = 10,
    TOWN_CATHEDRAL = 11,
    TOWN_COUNT = 12,
    TOWN_SPECIAL_12 = 12,
    TOWN_SPECIAL_13 = 13,
    TOWN_SPECIAL_14 = 14,
};
```

### Map Enumeration (63 maps)

```cpp
typedef enum Map {
    MAP_DESERT1 = 0,    MAP_DESERT2,     MAP_DESERT3,
    MAP_HALLDED,        MAP_HOTEL,       MAP_WATRSHD,
    MAP_VAULT13,        MAP_VAULTENT,    MAP_VAULTBUR,
    MAP_VAULTNEC,       MAP_JUNKENT,     MAP_JUNKCSNO,
    MAP_JUNKKILL,       MAP_BROHDENT,    MAP_BROHD12,
    MAP_BROHD34,        MAP_CAVES,       MAP_CHILDRN1,
    MAP_CHILDRN2,       MAP_CITY1,       MAP_COAST1,
    MAP_COAST2,         MAP_COLATRUK,    MAP_FSAUSER,
    MAP_RAIDERS,        MAP_SHADYE,      MAP_SHADYW,
    MAP_GLOWENT,        MAP_LAADYTUM,    MAP_LAFOLLWR,
    MAP_MBENT,          MAP_MBSTRG12,    MAP_MBVATS12,
    MAP_MSTRLR12,       MAP_MSTRLR34,    MAP_V13ENT,
    MAP_HUBENT,         MAP_DETHCLAW,    MAP_HUBDWNTN,
    MAP_HUBHEIGT,       MAP_HUBOLDTN,    MAP_HUBWATER,
    MAP_GLOW1,          MAP_GLOW2,       MAP_LABLADES,
    MAP_LARIPPER,       MAP_LAGUNRUN,    MAP_CHILDEAD,
    MAP_MBDEAD,         MAP_MOUNTN1,     MAP_MOUNTN2,
    MAP_FOOT,           MAP_TARDIS,      MAP_TALKCOW,
    MAP_USEDCAR,        MAP_BRODEAD,     MAP_DESCRVN1,
    MAP_DESCRVN2,       MAP_MNTCRVN1,    MAP_MNTCRVN2,
    MAP_VIPERS,         MAP_DESCRVN3,    MAP_MNTCRVN3,
    MAP_DESCRVN4,       MAP_MNTCRVN4,    MAP_HUBMIS1,
    MAP_COUNT = 63,
};
```

### Terrain Types

```cpp
typedef enum TerrainType {
    TERRAIN_TYPE_DESERT,
    TERRAIN_TYPE_MOUNTAIN,
    TERRAIN_TYPE_CITY,
    TERRAIN_TYPE_COAST,
};
```

### Map Flags

```cpp
typedef enum MapFlags {
    MAP_SAVED              = 0x01,
    MAP_DEAD_BODIES_AGE    = 0x02,
    MAP_PIPBOY_ACTIVE      = 0x04,
    MAP_CAN_REST_ELEVATION_0 = 0x08,
    MAP_CAN_REST_ELEVATION_1 = 0x10,
    MAP_CAN_REST_ELEVATION_2 = 0x20,
};
```

### World Map Context

```cpp
typedef struct WorldMapContext {
    short state;     // current state
    short town;      // current/target town
    short section;   // map section within town
} WorldMapContext;
```

### Internal Data Structures

```cpp
typedef struct CityLocationEntry {
    int column;
    int row;
} CityLocationEntry;

typedef struct TownHotSpotEntry {
    short x;
    short y;
    short map_idx;
    char name[16];
} TownHotSpotEntry;
```

### Key Functions

```cpp
int init_world_map();
int save_world_map(DB_FILE* stream);
int load_world_map(DB_FILE* stream);
int world_map(WorldMapContext ctx);             // Main world map loop
WorldMapContext town_map(WorldMapContext ctx);   // Town map sub-screen
void KillWorldWin();                            // Clean up world map window
int worldmap_script_jump(int city, int a2);     // Script-driven travel
int xlate_mapidx_to_town(int map_idx);          // Map index to town ID
int PlayCityMapMusic();
```

### Important Global Variables

```cpp
extern int world_win;      // world map window ID
extern int our_section;    // current map section
extern int our_town;       // current town index
```

### System Interactions

- **Pathfinder perk** reduces travel time
- **Scout perk** increases sight range on world map
- **Outdoorsman skill** reduces random encounter chance
- **Random encounters** trigger combat entry via `scripts_request_combat`
- **Game time** advances during travel

---

## 11. Save/Load System

**Files:** `loadsave.cc`, `loadsave.h`

### Overview

The save/load system serializes the entire game state to disk files. It uses a handler-based architecture with 27 ordered save/load handler pairs.

### Key Constants

```cpp
#define LOAD_SAVE_SIGNATURE          "FALLOUT SAVE FILE"
#define LOAD_SAVE_DESCRIPTION_LENGTH 30
#define LOAD_SAVE_HANDLER_COUNT      27
#define LS_PREVIEW_WIDTH             224
#define LS_PREVIEW_HEIGHT            133
```

### Save Modes

```cpp
typedef enum LoadSaveMode {
    LOAD_SAVE_MODE_FROM_MAIN_MENU,  // Loading from main menu
    LOAD_SAVE_MODE_NORMAL,          // Full-screen save/load
    LOAD_SAVE_MODE_QUICK,           // Quick save/load
};
```

### Save Slot Data

```cpp
typedef struct LoadSaveSlotData {
    char signature[24];           // "FALLOUT SAVE FILE"
    short versionMinor;
    short versionMajor;
    unsigned char versionRelease;
    char characterName[32];
    char description[LOAD_SAVE_DESCRIPTION_LENGTH];
    short fileMonth, fileDay, fileYear;
    int fileTime;
    short gameMonth, gameDay, gameYear;
    int gameTime;
    short elevation;
    short map;
    char fileName[16];
} LoadSaveSlotData;
```

### Save Handler Order (27 handlers)

The save and load operations execute these handlers in order:

| # | Save Handler | Load Handler | System |
|---|---|---|---|
| 0 | DummyFunc | PrepLoad | Initialization |
| 1 | SaveObjDudeCid | LoadObjDudeCid | Player object CID |
| 2 | scr_game_save | scr_game_load | Scripts (pass 1) |
| 3 | GameMap2Slot | SlotMap2Game | Map data |
| 4 | scr_game_save | scr_game_load2 | Scripts (pass 2) |
| 5 | obj_save_dude | obj_load_dude | Player object |
| 6 | critter_save | critter_load | Critter state |
| 7 | critter_kill_count_save | critter_kill_count_load | Kill counts |
| 8 | skill_save | skill_load | Tagged skills |
| 9 | roll_save | roll_load | RNG state |
| 10 | perk_save | perk_load | Perk levels |
| 11 | combat_save | combat_load | Combat state |
| 12 | combat_ai_save | combat_ai_load | AI state |
| 13 | stat_save | stat_load | PC stats |
| 14 | item_save | item_load | Item state (addictions) |
| 15 | queue_save | queue_load | Event queue |
| 16 | trait_save | trait_load | Selected traits |
| 17 | automap_save | automap_load | Automap data |
| 18 | save_options | load_options | Game options |
| 19 | editor_save | editor_load | Character editor state |
| 20 | save_world_map | load_world_map | World map state |
| 21 | save_pipboy | load_pipboy | Pip-Boy data |
| 22 | gmovie_save | gmovie_load | Movie flags |
| 23 | skill_use_slot_save | skill_use_slot_load | Skill use timers |
| 24 | partyMemberSave | partyMemberLoad | Party members |
| 25 | intface_save | intface_load | Interface state |
| 26 | DummyFunc | EndLoad | Finalization |

### Key Functions

```cpp
void InitLoadSave();
void ResetLoadSave();
int SaveGame(int mode);       // Save game (returns 1 on success)
int LoadGame(int mode);       // Load game (returns 1 on success)
int isLoadingGame();          // Is a game currently being loaded?
void KillOldMaps();           // Clean up old map files
int MapDirErase(const char* path, const char* a2);
```

---

## 12. Animation System

**Files:** `anim.cc`, `anim.h`

### Overview

The animation system manages character and object animations through a queuing system. Animations are registered into sequences that play in order. The system handles walking, combat animations, death sequences, and special effects.

### Animation Types (65 types)

```cpp
typedef enum AnimationType {
    // Basic animations: 0-19
    ANIM_STAND = 0,
    ANIM_WALK = 1,
    ANIM_JUMP_BEGIN = 2,
    ANIM_JUMP_END = 3,
    ANIM_CLIMB_LADDER = 4,
    ANIM_FALLING = 5,
    ANIM_UP_STAIRS_RIGHT = 6,
    ANIM_UP_STAIRS_LEFT = 7,
    ANIM_DOWN_STAIRS_RIGHT = 8,
    ANIM_DOWN_STAIRS_LEFT = 9,
    ANIM_MAGIC_HANDS_GROUND = 10,
    ANIM_MAGIC_HANDS_MIDDLE = 11,
    ANIM_MAGIC_HANDS_UP = 12,
    ANIM_DODGE_ANIM = 13,
    ANIM_HIT_FROM_FRONT = 14,
    ANIM_HIT_FROM_BACK = 15,
    ANIM_THROW_PUNCH = 16,
    ANIM_KICK_LEG = 17,
    ANIM_THROW_ANIM = 18,
    ANIM_RUNNING = 19,

    // Knockdown and death: 20-35
    ANIM_FALL_BACK = 20,
    ANIM_FALL_FRONT = 21,
    ANIM_BAD_LANDING = 22,
    ANIM_BIG_HOLE = 23,
    ANIM_CHARRED_BODY = 24,
    ANIM_CHUNKS_OF_FLESH = 25,
    ANIM_DANCING_AUTOFIRE = 26,
    ANIM_ELECTRIFY = 27,
    ANIM_SLICED_IN_HALF = 28,
    ANIM_BURNED_TO_NOTHING = 29,
    ANIM_ELECTRIFIED_TO_NOTHING = 30,
    ANIM_EXPLODED_TO_NOTHING = 31,
    ANIM_MELTED_TO_NOTHING = 32,
    ANIM_FIRE_DANCE = 33,
    ANIM_FALL_BACK_BLOOD = 34,
    ANIM_FALL_FRONT_BLOOD = 35,

    // Position changes: 36-37
    ANIM_PRONE_TO_STANDING = 36,
    ANIM_BACK_TO_STANDING = 37,

    // Weapon animations: 38-47
    ANIM_TAKE_OUT = 38,
    ANIM_PUT_AWAY = 39,
    ANIM_PARRY_ANIM = 40,
    ANIM_THRUST_ANIM = 41,
    ANIM_SWING_ANIM = 42,
    ANIM_POINT = 43,
    ANIM_UNPOINT = 44,
    ANIM_FIRE_SINGLE = 45,
    ANIM_FIRE_BURST = 46,
    ANIM_FIRE_CONTINUOUS = 47,

    // Single-frame death (last frame of death anims): 48-63
    ANIM_FALL_BACK_SF = 48,
    // ... through ...
    ANIM_FALL_FRONT_BLOOD_SF = 63,

    ANIM_CALLED_SHOT_PIC = 64,
    ANIM_COUNT = 65,
};
```

### Animation Request Options

```cpp
typedef enum AnimationRequestOptions {
    ANIMATION_REQUEST_UNRESERVED   = 0x01,
    ANIMATION_REQUEST_RESERVED     = 0x02,
    ANIMATION_REQUEST_NO_STAND     = 0x04,
    ANIMATION_REQUEST_0x100        = 0x100,
    ANIMATION_REQUEST_INSIGNIFICANT = 0x200,
};
```

### Callback Types

```cpp
typedef int AnimationCallback(void*, void*);       // 2-parameter callback
typedef int AnimationCallback3(void*, void*, void*); // 3-parameter callback
typedef Object* PathBuilderCallback(Object* object, int tile, int elevation);
```

### Animation Registration Functions

All animations are registered into sequences:

```cpp
int register_begin(int a1);        // Begin new animation sequence
int register_end();                 // Commit and start sequence
int register_priority(int a1);     // Set sequence priority
int register_clear(Object* a1);    // Clear pending animations

// Movement
int register_object_move_to_object(Object* owner, Object* dest, int ap, int delay);
int register_object_run_to_object(Object* owner, Object* dest, int ap, int delay);
int register_object_move_to_tile(Object* owner, int tile, int elev, int ap, int delay);
int register_object_run_to_tile(Object* owner, int tile, int elev, int ap, int delay);
int register_object_move_straight_to_tile(Object* obj, int tile, int elev, int anim, int delay);

// Animation playback
int register_object_animate(Object* owner, int anim, int delay);
int register_object_animate_reverse(Object* owner, int anim, int delay);
int register_object_animate_and_hide(Object* owner, int anim, int delay);
int register_object_animate_forever(Object* owner, int anim, int delay);

// Object manipulation
int register_object_turn_towards(Object* owner, int tile);
int register_object_erase(Object* object);
int register_object_change_fid(Object* owner, int fid, int delay);
int register_object_take_out(Object* owner, int weaponAnimCode, int delay);
int register_object_light(Object* owner, int lightDistance, int delay);
int register_object_outline(Object* object, bool outline, int delay);
int register_object_fset(Object* object, int flag, int delay);
int register_object_funset(Object* object, int flag, int delay);
int register_object_flatten(Object* object, int delay);

// Callbacks
int register_object_call(void* a1, void* a2, AnimationCallback* proc, int delay);
int register_object_call3(void* a1, void* a2, void* a3, AnimationCallback3* proc, int delay);
int register_object_must_call(void* a1, void* a2, AnimationCallback* proc, int delay);

// Sound
int register_object_play_sfx(Object* owner, const char* sfx, int delay);
```

### Pathfinding

```cpp
int make_path(Object* object, int from, int to, unsigned char* rotations, int a5);
int make_path_func(Object* obj, int from, int to, unsigned char* rotations,
                   int a5, PathBuilderCallback* callback);
int make_straight_path(Object* a1, int from, int to, StraightPathNode* nodes,
                       Object** a5, int a6);
int idist(int a1, int a2, int a3, int a4);   // Integer distance
int EST(int tile1, int tile2);                // Estimated tile distance

typedef struct StraightPathNode {
    int tile;
    int elevation;
    int x;
    int y;
} StraightPathNode;
```

### Player Movement

```cpp
int dude_move(int a1);              // Walk dude to destination
int dude_run(int a1);               // Run dude to destination
void dude_fidget();                  // Idle fidget animation
void dude_stand(Object* obj, int rotation, int fid);
void dude_standup(Object* a1);       // Stand up from prone
void object_animate();               // Process animation frame
int anim_busy(Object* a1);          // Is object currently animating?
void anim_stop();                    // Stop all animations
```

---

## 13. Event Queue

**Files:** `queue.cc`, `queue.h`

### Overview

The event queue is a time-ordered linked list of events that fire at specific game times. It handles drug effects, radiation processing, timed scripts, explosions, sneaking, and map updates.

### Event Types (13 types)

```cpp
typedef enum EventType {
    EVENT_TYPE_DRUG = 0,              // Drug effect wearing off
    EVENT_TYPE_KNOCKOUT = 1,          // Waking up from knockout
    EVENT_TYPE_WITHDRAWAL = 2,        // Drug withdrawal
    EVENT_TYPE_SCRIPT = 3,            // Timed script event
    EVENT_TYPE_GAME_TIME = 4,         // Game time tick
    EVENT_TYPE_POISON = 5,            // Poison damage tick
    EVENT_TYPE_RADIATION = 6,         // Radiation damage
    EVENT_TYPE_FLARE = 7,             // Flare burnout
    EVENT_TYPE_EXPLOSION = 8,         // Timed explosion
    EVENT_TYPE_ITEM_TRICKLE = 9,      // Item charge trickle
    EVENT_TYPE_SNEAK = 10,            // Sneak check
    EVENT_TYPE_EXPLOSION_FAILURE = 11, // Failed explosion
    EVENT_TYPE_MAP_UPDATE_EVENT = 12,  // Map update
    EVENT_TYPE_COUNT = 13,
};
```

### Event Data Structures

```cpp
typedef struct DrugEffectEvent {
    int drugPid;
    int stats[3];       // affected stats
    int modifiers[3];   // stat modifiers to remove
} DrugEffectEvent;

typedef struct WithdrawalEvent {
    int field_0;
    int pid;            // drug prototype ID
    int perk;           // withdrawal perk to apply
} WithdrawalEvent;

typedef struct ScriptEvent {
    int sid;            // script ID
    int fixedParam;     // parameter passed to script
} ScriptEvent;

typedef struct RadiationEvent {
    int radiationLevel;
    int isHealing;
} RadiationEvent;
```

### Event Type Descriptor

```cpp
typedef int QueueEventHandler(Object* owner, void* data);
typedef void QueueEventDataFreeProc(void* data);
typedef int QueueEventDataReadProc(DB_FILE* stream, void** dataPtr);
typedef int QueueEventDataWriteProc(DB_FILE* stream, void* data);

typedef struct EventTypeDescription {
    QueueEventHandler* handlerProc;     // Process this event
    QueueEventDataFreeProc* freeProc;   // Free event data
    QueueEventDataReadProc* readProc;   // Load from save
    QueueEventDataWriteProc* writeProc; // Save to file
    bool field_10;                      // process on map update
    QueueEventHandler* field_14;        // cleanup handler
} EventTypeDescription;
```

### Internal Queue Node

```cpp
typedef struct QueueListNode {
    int time;                  // game time when event fires
    int type;                  // EventType
    Object* owner;             // associated object
    void* data;                // event-specific data
    struct QueueListNode* next;
} QueueListNode;
```

### Event Handler Table

| Event Type | Handler | Free | Read/Write | Cleanup |
|---|---|---|---|---|
| Drug | `item_d_process` | `mem_free` | `item_d_load/save` | `item_d_clear` |
| Knockout | `critter_wake_up` | NULL | NULL | `critter_wake_clear` |
| Withdrawal | `item_wd_process` | `mem_free` | `item_wd_load/save` | `item_wd_clear` |
| Script | `script_q_process` | `mem_free` | `script_q_load/save` | NULL |
| Game Time | `gtime_q_process` | NULL | NULL | NULL |
| Poison | `critter_check_poison` | NULL | NULL | NULL |
| Radiation | `critter_process_rads` | `mem_free` | `critter_load/save_rads` | NULL |
| Flare | `queue_destroy` | NULL | NULL | `queue_destroy` |
| Explosion | `queue_explode` | NULL | NULL | `queue_explode_exit` |
| Item Trickle | `item_m_trickle` | NULL | NULL | `item_m_turn_off_from_queue` |
| Sneak | `critter_sneak_check` | NULL | NULL | `critter_sneak_clear` |
| Explosion Fail | `queue_premature` | NULL | NULL | `queue_explode_exit` |
| Map Update | `scr_map_q_process` | NULL | NULL | NULL |

### Key Functions

```cpp
void queue_init();
int queue_add(int delay, Object* owner, void* data, int eventType);
// Adds event to fire at (current_game_time + delay).

int queue_remove(Object* owner);
// Removes all events for an object.

int queue_remove_this(Object* owner, int eventType);
// Removes events of specific type for an object.

bool queue_find(Object* owner, int eventType);
// Checks if an event exists for object.

int queue_process();
// Processes all events whose time has arrived.

void queue_clear();
// Removes all events.

void queue_leaving_map();
// Called when leaving a map; processes certain event types.

int queue_next_time();
// Returns time of next event.

int queue_load(DB_FILE* stream);
int queue_save(DB_FILE* stream);
```

---

## 14. Object System

**Files:** `object.cc`, `object.h`, `object_types.h`

### Overview

The object system is the foundation of the game world. Every entity -- items, critters, walls, scenery, tiles, and misc objects -- is represented as an `Object` struct. Objects live in a spatial grid organized by tile and elevation.

### Object Types

```cpp
enum {
    OBJ_TYPE_ITEM,        // 0
    OBJ_TYPE_CRITTER,     // 1
    OBJ_TYPE_SCENERY,     // 2
    OBJ_TYPE_WALL,        // 3
    OBJ_TYPE_TILE,        // 4
    OBJ_TYPE_MISC,        // 5
    OBJ_TYPE_INTERFACE,   // 6
    OBJ_TYPE_INVENTORY,   // 7
    OBJ_TYPE_HEAD,        // 8
    OBJ_TYPE_BACKGROUND,  // 9
    OBJ_TYPE_SKILLDEX,    // 10
    OBJ_TYPE_COUNT = 11,
};
```

### Object Structure

```cpp
typedef struct Object {
    int id;               // unique object ID
    int tile;             // hex tile position
    int x;                // pixel x offset
    int y;                // pixel y offset
    int sx;               // screen x
    int sy;               // screen y
    int frame;            // current animation frame
    int rotation;         // facing direction (0-5)
    int fid;              // frame ID (art reference)
    int flags;            // ObjectFlags
    int elevation;        // 0-2
    union {
        int field_2C_array[14];
        ObjectData data;  // type-specific data
    };
    int pid;              // prototype ID
    int cid;              // combat ID (index in combat list)
    int lightDistance;
    int lightIntensity;
    int outline;          // outline color for highlighting
    int sid;              // script ID
    Object* owner;        // owning object (if in inventory)
    int field_80;
} Object;
```

### ID Macros

```cpp
#define FID_TYPE(value) ((value) & 0xF000000) >> 24  // Object type from FID
#define PID_TYPE(value) (value) >> 24                 // Object type from PID
#define SID_TYPE(value) (value) >> 24                 // Script type from SID
#define FID_ANIM_TYPE(value) ((value) & 0xFF0000) >> 16
```

### Object Flags

```cpp
typedef enum ObjectFlags {
    OBJECT_HIDDEN      = 0x01,
    OBJECT_NO_SAVE     = 0x04,      // don't save to file
    OBJECT_FLAT        = 0x08,
    OBJECT_NO_BLOCK    = 0x10,
    OBJECT_LIGHTING    = 0x20,
    OBJECT_NO_REMOVE   = 0x400,     // system object (dude, egg, cursor)
    OBJECT_MULTIHEX    = 0x800,
    OBJECT_NO_HIGHLIGHT = 0x1000,
    OBJECT_USED        = 0x2000,
    // Translucency modes: 0x4000-0x80000
    OBJECT_TRANS_RED   = 0x4000,
    OBJECT_TRANS_NONE  = 0x8000,
    OBJECT_TRANS_WALL  = 0x10000,
    OBJECT_TRANS_GLASS = 0x20000,
    OBJECT_TRANS_STEAM = 0x40000,
    OBJECT_TRANS_ENERGY = 0x80000,
    // Equipment slots
    OBJECT_IN_LEFT_HAND  = 0x1000000,
    OBJECT_IN_RIGHT_HAND = 0x2000000,
    OBJECT_WORN          = 0x4000000,
    // Passthrough flags
    OBJECT_LIGHT_THRU  = 0x20000000,
    OBJECT_SEEN        = 0x40000000,
    OBJECT_SHOOT_THRU  = 0x80000000,
};
```

### Critter Combat Data

```cpp
typedef struct CritterCombatData {
    int maneuver;      // CRITTER_MANEUVER_* flags
    int ap;            // current action points
    int results;       // DAM_* flags (current damage state)
    int damageLastTurn;
    int aiPacket;      // AI behavior packet index
    int team;          // team number
    union {
        Object* whoHitMe;    // who last attacked this critter
        int whoHitMeCid;     // combat ID (used during save/load)
    };
} CritterCombatData;

typedef struct CritterObjectData {
    int field_0;               // reaction to PC
    CritterCombatData combat;
    int hp;                    // current hit points
    int radiation;             // current radiation level
    int poison;                // current poison level
} CritterObjectData;
```

### Built Tile Encoding

```cpp
#define BUILT_TILE_TILE_MASK        0x3FFFFFF
#define BUILT_TILE_ELEVATION_MASK   0xE0000000
#define BUILT_TILE_ELEVATION_SHIFT  29
#define BUILT_TILE_ROTATION_MASK    0x1C000000
#define BUILT_TILE_ROTATION_SHIFT   26

int builtTileGetTile(int builtTile);       // Extract tile number
int builtTileGetElevation(int builtTile);  // Extract elevation
int builtTileGetRotation(int builtTile);   // Extract rotation
int builtTileCreate(int tile, int elevation); // Pack tile + elevation
```

### Key Functions

```cpp
// Lifecycle
int obj_new(Object** objectPtr, int fid, int pid);
int obj_pid_new(Object** objectPtr, int pid);
int obj_copy(Object** a1, Object* a2);
int obj_connect(Object* obj, int tile, int elev, Rect* rect);
int obj_disconnect(Object* obj, Rect* rect);
int obj_erase_object(Object* a1, Rect* a2);
void obj_remove_all();

// Movement and position
int obj_move_to_tile(Object* obj, int tile, int elevation, Rect* rect);
int obj_move(Object* a1, int a2, int a3, int elevation, Rect* a5);
int obj_set_rotation(Object* obj, int direction, Rect* rect);
int obj_dist(Object* object1, Object* object2);

// Visual
int obj_change_fid(Object* obj, int fid, Rect* rect);
int obj_set_frame(Object* obj, int frame, Rect* rect);
void obj_render_pre_roof(Rect* rect, int elevation);
void obj_render_post_roof(Rect* rect, int elevation);
int obj_outline_object(Object* obj, int a2, Rect* rect);
int obj_set_light(Object* obj, int distance, int intensity, Rect* rect);
int obj_get_visible_light(Object* obj);

// Queries
Object* obj_blocking_at(Object* a1, int tile_num, int elev);
Object* obj_sight_blocking_at(Object* a1, int tile_num, int elev);
bool obj_occupied(int tile_num, int elev);
Object* obj_find_first();
Object* obj_find_next();
Object* obj_find_first_at(int elevation);
int obj_create_list(int tile, int elevation, int objectType, Object*** objectsPtr);
void obj_delete_list(Object** objects);

// Serialization
int obj_save_obj(DB_FILE* stream, Object* object);
int obj_load_obj(DB_FILE* stream, Object** objectPtr, int elevation, Object* owner);
int obj_save_dude(DB_FILE* stream);
int obj_load_dude(DB_FILE* stream);
```

### Important Global Variables

```cpp
extern Object* obj_dude;    // The player character object
extern Object* obj_egg;     // The "egg" object (hex cursor)
```

---

## 15. Prototype System

**Files:** `proto.cc`, `proto.h`, `proto_types.h`

### Overview

Prototypes are templates that define the properties of game objects. Each object has a PID (prototype ID) that references its prototype. Prototypes are loaded from `.pro` files on disk and cached in linked lists of extents.

### Prototype Cache

```cpp
#define PROTO_LIST_EXTENT_SIZE  16   // prototypes per extent
#define PROTO_LIST_MAX_ENTRIES  512  // max cached prototypes per type

typedef struct ProtoListExtent {
    Proto* proto[PROTO_LIST_EXTENT_SIZE];
    int length;
    struct ProtoListExtent* next;
} ProtoListExtent;

typedef struct ProtoList {
    ProtoListExtent* head;
    ProtoListExtent* tail;
    int length;            // number of extents
    int max_entries_num;   // lines in .lst file
} ProtoList;
```

### Proto Union

```cpp
typedef union Proto {
    struct {
        int pid;
        int messageId;
        int fid;
        int lightDistance;
        int lightIntensity;
        int flags;
        int extendedFlags;
        int sid;
    };                           // Common header fields
    ItemProto item;              // ITEM_TYPE_* prototypes
    CritterProto critter;        // Critter prototypes
    SceneryProto scenery;        // Scenery prototypes
    WallProto wall;              // Wall prototypes
    TileProto tile;              // Floor tile prototypes
    MiscProto misc;              // Miscellaneous prototypes
} Proto;
```

### Material Types

```cpp
enum {
    MATERIAL_TYPE_GLASS,   MATERIAL_TYPE_METAL,
    MATERIAL_TYPE_PLASTIC, MATERIAL_TYPE_WOOD,
    MATERIAL_TYPE_DIRT,    MATERIAL_TYPE_STONE,
    MATERIAL_TYPE_CEMENT,  MATERIAL_TYPE_LEATHER,
    MATERIAL_TYPE_COUNT = 8,
};
```

### Kill Types

```cpp
enum {
    KILL_TYPE_MAN,         KILL_TYPE_WOMAN,
    KILL_TYPE_CHILD,       KILL_TYPE_SUPER_MUTANT,
    KILL_TYPE_GHOUL,       KILL_TYPE_BRAHMIN,
    KILL_TYPE_RADSCORPION, KILL_TYPE_RAT,
    KILL_TYPE_FLOATER,     KILL_TYPE_CENTAUR,
    KILL_TYPE_ROBOT,       KILL_TYPE_DOG,
    KILL_TYPE_MANTIS,      KILL_TYPE_DEATH_CLAW,
    KILL_TYPE_PLANT,
    KILL_TYPE_COUNT = 15,
};
```

### Notable Prototype IDs

```cpp
PROTO_ID_POWER_ARMOR = 3,
PROTO_ID_STIMPACK = 40,
PROTO_ID_MONEY = 41,            // Bottle caps
PROTO_ID_FIRST_AID_KIT = 47,
PROTO_ID_RADAWAY = 48,
PROTO_ID_MENTATS = 53,
PROTO_ID_FLARE = 79,
PROTO_ID_BUFF_OUT = 87,
PROTO_ID_NUKA_COLA = 106,
PROTO_ID_PSYCHO = 110,
PROTO_ID_SUPER_STIMPACK = 144,
```

### Key Functions

```cpp
int proto_ptr(int pid, Proto** out_proto);    // Get prototype by PID
int proto_load_pid(int pid, Proto** out_proto); // Load prototype from disk
size_t proto_size(int type);                   // Size of prototype struct
char* proto_name(int pid);                     // Prototype name
char* proto_description(int pid);              // Prototype description
bool proto_action_can_use(int pid);            // Can this object be used?
bool proto_action_can_use_on(int pid);         // Can this be used on something?
bool proto_action_can_look_at(int pid);        // Can this be looked at?
bool proto_action_can_talk_to(int pid);        // Can this be talked to?
int proto_action_can_pickup(int pid);          // Can this be picked up?
int proto_critter_init(Proto* a1, int a2);     // Initialize critter proto
int proto_data_member(int pid, int member, ProtoDataMemberValue* value);
void proto_make_path(char* path, int pid);     // Build file path for proto
int proto_init();
void proto_reset();
void proto_exit();
void proto_remove_all();                       // Clear prototype cache
```

---

## 16. Map System

**Files:** `map.cc`, `map.h`, `map_defs.h`

### Overview

The map system manages game maps with up to 3 elevations. Each elevation has a hex grid (200x200 = 40000 tiles) for objects and a square grid (100x100 = 10000 tiles) for floor/roof tiles.

### Key Constants

```cpp
#define ELEVATION_COUNT       3
#define SQUARE_GRID_WIDTH     100
#define SQUARE_GRID_HEIGHT    100
#define SQUARE_GRID_SIZE      10000
#define HEX_GRID_WIDTH        200
#define HEX_GRID_HEIGHT       200
#define HEX_GRID_SIZE         40000
#define ORIGINAL_ISO_WINDOW_WIDTH  640
#define ORIGINAL_ISO_WINDOW_HEIGHT 380
```

### Map Header

```cpp
typedef struct MapHeader {
    int version;
    char name[16];
    int enteringTile;           // default entry tile
    int enteringElevation;      // default entry elevation
    int enteringRotation;       // default entry rotation
    int localVariablesCount;    // number of local script variables
    int scriptIndex;            // map script index
    int flags;                  // MapFlags
    int darkness;               // ambient light level
    int globalVariablesCount;   // number of global map variables
    int field_34;               // map number
    int lastVisitTime;          // game time of last visit
    int field_3C[44];           // reserved
} MapHeader;
```

### Map Transition

```cpp
typedef struct MapTransition {
    int map;        // target map index
    int elevation;  // target elevation
    int tile;       // target tile
    int rotation;   // target rotation
} MapTransition;
```

### Tile Data

```cpp
typedef struct TileData {
    int field_0[SQUARE_GRID_SIZE]; // 10000 tile entries
} TileData;

extern TileData square_data[ELEVATION_COUNT]; // actual tile data
extern TileData* square[ELEVATION_COUNT];     // pointers to tile data
```

### Key Functions

```cpp
// Initialization
int iso_init();
void map_init();
void map_reset();
void map_exit();

// Map loading
int map_load(char* fileName);
int map_load_idx(int map_index);
int map_load_file(DB_FILE* stream);
int map_load_in_game(char* fileName);

// Map saving
int map_save();
int map_save_file(DB_FILE* stream);
int map_save_in_game(bool a1);

// Elevation
int map_set_elevation(int elevation);
bool map_is_elevation_empty(int elevation);

// Variables
int map_set_global_var(int var, ProgramValue& value);
int map_get_global_var(int var, ProgramValue& value);
int map_set_local_var(int var, ProgramValue& value);
int map_get_local_var(int var, ProgramValue& value);

// Transitions
int map_leave_map(MapTransition* transition);
int map_check_state();

// Scrolling
int map_scroll(int dx, int dy);

// Naming
void map_set_name(const char* name);
void map_get_name(char* name);
char* map_get_short_name(int map_num);
char* map_get_description();
```

### Important Global Variables

```cpp
extern int map_elevation;         // current elevation (0-2)
extern int* map_local_vars;       // map local variables
extern int* map_global_vars;      // map global variables
extern int num_map_local_vars;
extern int num_map_global_vars;
extern MapHeader map_data;        // current map header
extern int display_win;           // isometric view window ID
extern int map_script_id;         // current map script SID
extern MessageList map_msg_file;  // map message file
```

---

## 17. Critter System

**Files:** `critter.cc`, `critter.h`

### Overview

The critter system manages NPC and player character state including hit points, radiation, poison, kill counts, healing, and special flags. It works closely with the stat, combat, and object systems.

### Key Constants

```cpp
#define DUDE_NAME_MAX_LENGTH       32
#define RADIATION_EFFECT_COUNT     8
#define RADIATION_LEVEL_COUNT      6
```

### Radiation Levels

```cpp
typedef enum RadiationLevel {
    RADIATION_LEVEL_NONE,       // Very nauseous
    RADIATION_LEVEL_MINOR,      // Slightly fatigued
    RADIATION_LEVEL_ADVANCED,   // Vomiting does not stop
    RADIATION_LEVEL_CRITICAL,   // Hair is falling out
    RADIATION_LEVEL_DEADLY,     // Skin is falling off
    RADIATION_LEVEL_FATAL,      // Intense agony
    RADIATION_LEVEL_COUNT = 6,
};
```

Radiation effects are defined by two tables:
- `rad_stat[8]`: which stats are affected
- `rad_bonus[6][8]`: stat penalties per radiation level

### PC Flags

```cpp
typedef enum PcFlags {
    PC_FLAG_SNEAKING          = 0,
    PC_FLAG_LEVEL_UP_AVAILABLE = 3,
    PC_FLAG_ADDICTED          = 4,
};
```

### Critter Flags (from prototype)

```cpp
typedef enum CritterFlags {
    CRITTER_BARTER        = 0x02,
    CRITTER_NO_STEAL      = 0x20,
    CRITTER_NO_DROP       = 0x40,
    CRITTER_NO_LIMBS      = 0x80,
    CRITTER_NO_AGE        = 0x100,
    CRITTER_NO_HEAL       = 0x200,
    CRITTER_INVULNERABLE  = 0x400,
    CRITTER_FLAT          = 0x800,
    CRITTER_SPECIAL_DEATH = 0x1000,
    CRITTER_LONG_LIMBS    = 0x2000,
    CRITTER_NO_KNOCKBACK  = 0x4000,
};
```

### Body Types

```cpp
enum {
    BODY_TYPE_BIPED,
    BODY_TYPE_QUADRUPED,
    BODY_TYPE_ROBOTIC,
    BODY_TYPE_COUNT = 3,
};
```

### Key Functions

```cpp
// HP management
int critter_get_hits(Object* critter);
int critter_adjust_hits(Object* critter, int amount);

// Poison
int critter_get_poison(Object* critter);
int critter_adjust_poison(Object* obj, int amount);
int critter_check_poison(Object* obj, void* data);    // Queue handler

// Radiation
int critter_get_rads(Object* critter);
int critter_adjust_rads(Object* obj, int amount);
int critter_check_rads(Object* critter);               // Check radiation effects
int critter_process_rads(Object* obj, void* data);     // Queue handler

// State checks
bool critter_is_active(Object* critter);
bool critter_is_dead(Object* critter);
bool critter_is_crippled(Object* critter);
bool critter_is_prone(Object* critter);
int critter_body_type(Object* critter);

// Kill tracking
int critter_kill_count_inc(int critter_type);
int critter_kill_count(int critter_type);
int critter_kill_count_type(Object* critter);
char* critter_kill_name(int critter_type);

// Name
char* critter_name(Object* critter);
int critter_pc_set_name(const char* name);
void critter_pc_reset_name();

// Healing
int critter_heal_hours(Object* critter, int hours);
void critter_kill(Object* critter, int anim, bool refresh_window);
int critter_kill_exps(Object* critter);

// Combat tracking
int critter_set_who_hit_me(Object* critter, Object* who_hit_me);
int critter_compute_ap_from_distance(Object* critter, int distance);

// PC flags
void pc_flag_on(int pc_flag);
void pc_flag_off(int pc_flag);
void pc_flag_toggle(int pc_flag);
bool is_pc_flag(int pc_flag);

// Sneaking
int critter_sneak_check(Object* obj, void* data);   // Queue handler
bool is_pc_sneak_working();

// Knockout
int critter_wake_up(Object* obj, void* data);        // Queue handler

// Serialization
void critter_copy(CritterProtoData* dest, CritterProtoData* src);
int critter_read_data(DB_FILE* stream, CritterProtoData* critter_data);
int critter_write_data(DB_FILE* stream, CritterProtoData* critter_data);
bool critter_can_obj_dude_rest();
```

---

## 18. Script System

**Files:** `scripts.cc`, `scripts.h`

### Overview

The script system manages all game scripts: map scripts, spatial triggers, timed scripts, item scripts, and critter scripts. Scripts are compiled programs that execute in response to game events. The system also manages game time.

### Game Time Constants

```cpp
#define GAME_TIME_TICKS_PER_HOUR  (60 * 60 * 10)     // 36000
#define GAME_TIME_TICKS_PER_DAY   (24 * 60 * 60 * 10) // 864000
#define GAME_TIME_TICKS_PER_YEAR  (365 * 24 * 60 * 60 * 10) // 315,360,000
#define SCRIPT_DIALOG_MESSAGE_LIST_CAPACITY 1000
```

### Script Types

```cpp
typedef enum ScriptType {
    SCRIPT_TYPE_SYSTEM,   // 0 - System scripts
    SCRIPT_TYPE_SPATIAL,  // 1 - Spatial trigger scripts
    SCRIPT_TYPE_TIMED,    // 2 - Timer scripts
    SCRIPT_TYPE_ITEM,     // 3 - Item scripts
    SCRIPT_TYPE_CRITTER,  // 4 - Critter scripts
    SCRIPT_TYPE_COUNT = 5,
};
```

### Script Procedures (24 event handlers)

```cpp
typedef enum ScriptProc {
    SCRIPT_PROC_NO_PROC = 0,
    SCRIPT_PROC_START = 1,          // Script initialization
    SCRIPT_PROC_SPATIAL = 2,        // Spatial trigger fired
    SCRIPT_PROC_DESCRIPTION = 3,    // Object description requested
    SCRIPT_PROC_PICKUP = 4,         // Item picked up
    SCRIPT_PROC_DROP = 5,           // Item dropped
    SCRIPT_PROC_USE = 6,            // Object used
    SCRIPT_PROC_USE_OBJ_ON = 7,     // Object used on another object
    SCRIPT_PROC_USE_SKILL_ON = 8,   // Skill used on object
    SCRIPT_PROC_TALK = 11,          // Talk to critter
    SCRIPT_PROC_CRITTER = 12,       // Critter heartbeat
    SCRIPT_PROC_COMBAT = 13,        // Combat event
    SCRIPT_PROC_DAMAGE = 14,        // Object took damage
    SCRIPT_PROC_MAP_ENTER = 15,     // Entered map
    SCRIPT_PROC_MAP_EXIT = 16,      // Leaving map
    SCRIPT_PROC_CREATE = 17,        // Object created
    SCRIPT_PROC_DESTROY = 18,       // Object destroyed
    SCRIPT_PROC_LOOK_AT = 21,       // Looked at object
    SCRIPT_PROC_TIMED = 22,         // Timed event
    SCRIPT_PROC_MAP_UPDATE = 23,    // Map time update
    SCRIPT_PROC_COUNT = 24,
};
```

### Script Requests

```cpp
typedef enum ScriptRequests {
    SCRIPT_REQUEST_COMBAT               = 0x01,
    SCRIPT_REQUEST_TOWN_MAP             = 0x02,
    SCRIPT_REQUEST_WORLD_MAP            = 0x04,
    SCRIPT_REQUEST_ELEVATOR             = 0x08,
    SCRIPT_REQUEST_EXPLOSION            = 0x10,
    SCRIPT_REQUEST_DIALOG               = 0x20,
    SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE = 0x40,
    SCRIPT_REQUEST_ENDGAME              = 0x80,
    SCRIPT_REQUEST_LOOTING              = 0x100,
    SCRIPT_REQUEST_STEALING             = 0x200,
    SCRIPT_REQUEST_LOCKED               = 0x400,
};
```

### Script Structure

```cpp
typedef struct Script {
    int scr_id;             // script ID (type | index)
    int scr_next;           // next script in chain

    union {
        struct {
            int built_tile; // spatial trigger location
            int radius;     // trigger radius
        } sp;               // spatial script data
        struct {
            int time;       // trigger time
        } tm;               // timed script data
    };

    int scr_flags;          // SCRIPT_FLAG_*
    int scr_script_idx;     // index into script list
    Program* program;       // compiled program
    int scr_oid;            // associated object ID
    int scr_local_var_offset;
    int scr_num_local_vars;
    int field_28;           // return value
    int action;             // current action being processed
    int fixedParam;         // fixed parameter from script setup
    Object* owner;          // owning object
    Object* source;         // source object (initiator)
    Object* target;         // target object
    int actionBeingUsed;    // skill/action in use
    int scriptOverrides;    // script overrides default behavior
    int field_48;
    int howMuch;            // result value
    int run_info_flags;
    int procs[SCRIPT_PROC_COUNT]; // procedure addresses
    // ... additional fields
} Script;
```

### Game Time Functions

```cpp
int game_time();                          // Current game time in ticks
void game_time_date(int* month, int* day, int* year);
int game_time_hour();                     // Current hour (0-2359)
char* game_time_hour_str();               // Formatted time string
void inc_game_time(int inc);              // Advance by ticks
void inc_game_time_in_seconds(int inc);   // Advance by seconds
void set_game_time(int time);
```

### Script Management Functions

```cpp
// Lifecycle
int scr_init();
int scr_reset();
int scr_game_init();
int scr_exit();

// Script CRUD
int scr_new(int* sidPtr, int scriptType);
int scr_remove(int index);
int scr_remove_all();
int scr_ptr(int sid, Script** script);

// Execution
int exec_script_proc(int sid, int proc);
int scr_set_objs(int sid, Object* source, Object* target);
void scr_set_ext_param(int a1, int a2);
int scr_set_action_num(int sid, int a2);
Program* loadProgram(const char* name);

// Spatial scripts
bool scr_spatials_enabled();
void scr_spatials_enable();
void scr_spatials_disable();
bool scr_chk_spatials_in(Object* obj, int tile, int elevation);

// Map scripts
void scr_exec_map_enter_scripts();
void scr_exec_map_update_scripts();
void scr_exec_map_exit_scripts();
int scr_load_all_scripts();

// Timed scripts
int script_q_add(int sid, int delay, int param);

// Script variables
int scr_get_local_var(int sid, int variable, ProgramValue& value);
int scr_set_local_var(int sid, int variable, ProgramValue& value);

// Request system
int scripts_check_state();
int scripts_check_state_in_combat();
int scripts_request_combat(STRUCT_664980* a1);
void scripts_request_townmap();
void scripts_request_worldmap();
int scripts_request_elevator(int elevator);
int scripts_request_explosion(int tile, int elevation, int minDamage, int maxDamage);
void scripts_request_dialog(Object* a1);
void scripts_request_endgame_slideshow();
int scripts_request_loot_container(Object* a1, Object* a2);
int scripts_request_steal_container(Object* a1, Object* a2);

// Dialog messages
int scr_get_dialog_msg_file(int a1, MessageList** out_message_list);
char* scr_get_msg_str(int messageListId, int messageId);

// IDs
int new_obj_id();
int scr_find_sid_from_program(Program* program);
Object* scr_find_obj_from_program(Program* program);
```

### Important Global Variables

```cpp
extern int num_script_indexes;
extern MessageList script_dialog_msgs[1000]; // Dialog message lists
extern MessageList script_message_file;       // script.msg
```

### System Interactions

- **Combat** is entered via `scripts_request_combat`
- **Dialog** is entered via `scripts_request_dialog`
- **World map** is entered via `scripts_request_worldmap`
- **Explosions** are triggered via `scripts_request_explosion`
- **Queue** system fires timed scripts via `script_q_process`
- **Map system** calls `scr_exec_map_enter_scripts` / `scr_exec_map_exit_scripts`
- **Object system** associates scripts with objects via `sid` field
- Scripts can read/write map local and global variables

---

## Cross-System Dependency Map

```
                    +----------+
                    |  Scripts |
                    +----+-----+
                         |
          +--------------+---------------+
          |              |               |
     +----v----+   +-----v-----+   +-----v-----+
     |  Combat |   |  Dialog   |   | World Map |
     +----+----+   +-----------+   +-----------+
          |
    +-----+------+
    |            |
+---v---+  +----v----+
|  Anim |  |Combat AI|
+-------+  +---------+

     +-------+     +---------+     +--------+
     | Stats |<--->|  Skills |<--->| Perks  |
     +---+---+     +---------+     +--------+
         |                              |
     +---v---+                     +----v---+
     | Traits|                     | Items  |
     +-------+                     +----+---+
                                        |
                                   +----v------+
                                   | Inventory |
                                   +-----------+

     +----------+     +---------+     +--------+
     |  Objects |<--->|  Proto  |<--->|  Maps  |
     +----+-----+     +---------+     +--------+
          |
     +----v------+
     | Critters  |
     +-----------+

     +--------+
     | Queue  |  (connects to: Critters, Items, Scripts)
     +--------+

     +-----------+
     | Save/Load |  (connects to ALL systems)
     +-----------+
```

This diagram shows the primary dependencies between systems. The save/load system serializes all other systems. Stats, skills, perks, and traits form the character mechanics core. Combat integrates with animation, AI, items, and stats. Scripts drive dialog, combat initiation, and world map transitions. The object system is the foundational layer on which all in-world entities are built.
