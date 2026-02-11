unit u_proto_types;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

uses
  u_object_types;

const
  // Macros
  PROTO_LIST_EXTENT_SIZE = 16;
  PROTO_LIST_MAX_ENTRIES = 512;
  WEAPON_TWO_HAND        = $00000200;

  // Gender
  GENDER_MALE   = 0;
  GENDER_FEMALE = 1;
  GENDER_COUNT  = 2;

  // Item types
  ITEM_TYPE_ARMOR     = 0;
  ITEM_TYPE_CONTAINER = 1;
  ITEM_TYPE_DRUG      = 2;
  ITEM_TYPE_WEAPON    = 3;
  ITEM_TYPE_AMMO      = 4;
  ITEM_TYPE_MISC      = 5;
  ITEM_TYPE_KEY       = 6;
  ITEM_TYPE_COUNT     = 7;

  // Scenery types
  SCENERY_TYPE_DOOR        = 0;
  SCENERY_TYPE_STAIRS      = 1;
  SCENERY_TYPE_ELEVATOR    = 2;
  SCENERY_TYPE_LADDER_UP   = 3;
  SCENERY_TYPE_LADDER_DOWN = 4;
  SCENERY_TYPE_GENERIC     = 5;
  SCENERY_TYPE_COUNT       = 6;

  // Material types
  MATERIAL_TYPE_GLASS   = 0;
  MATERIAL_TYPE_METAL   = 1;
  MATERIAL_TYPE_PLASTIC = 2;
  MATERIAL_TYPE_WOOD    = 3;
  MATERIAL_TYPE_DIRT    = 4;
  MATERIAL_TYPE_STONE   = 5;
  MATERIAL_TYPE_CEMENT  = 6;
  MATERIAL_TYPE_LEATHER = 7;
  MATERIAL_TYPE_COUNT   = 8;

  // Damage types
  DAMAGE_TYPE_NORMAL     = 0;
  DAMAGE_TYPE_LASER      = 1;
  DAMAGE_TYPE_FIRE       = 2;
  DAMAGE_TYPE_PLASMA     = 3;
  DAMAGE_TYPE_ELECTRICAL = 4;
  DAMAGE_TYPE_EMP        = 5;
  DAMAGE_TYPE_EXPLOSION  = 6;
  DAMAGE_TYPE_COUNT      = 7;

  // Caliber types
  CALIBER_TYPE_NONE              = 0;
  CALIBER_TYPE_ROCKET            = 1;
  CALIBER_TYPE_FLAMETHROWER_FUEL = 2;
  CALIBER_TYPE_C_ENERGY_CELL     = 3;
  CALIBER_TYPE_D_ENERGY_CELL     = 4;
  CALIBER_TYPE_223               = 5;
  CALIBER_TYPE_5_MM              = 6;
  CALIBER_TYPE_40_CAL            = 7;
  CALIBER_TYPE_10_MM             = 8;
  CALIBER_TYPE_44_CAL            = 9;
  CALIBER_TYPE_14_MM             = 10;
  CALIBER_TYPE_12_GAUGE          = 11;
  CALIBER_TYPE_9_MM              = 12;
  CALIBER_TYPE_BB                = 13;
  CALIBER_TYPE_COUNT             = 14;

  // Race types
  RACE_TYPE_CAUCASIAN = 0;
  RACE_TYPE_AFRICAN   = 1;
  RACE_TYPE_COUNT     = 2;

  // Body types
  BODY_TYPE_BIPED     = 0;
  BODY_TYPE_QUADRUPED = 1;
  BODY_TYPE_ROBOTIC   = 2;
  BODY_TYPE_COUNT     = 3;

  // Kill types
  KILL_TYPE_MAN         = 0;
  KILL_TYPE_WOMAN       = 1;
  KILL_TYPE_CHILD       = 2;
  KILL_TYPE_SUPER_MUTANT = 3;
  KILL_TYPE_GHOUL       = 4;
  KILL_TYPE_BRAHMIN     = 5;
  KILL_TYPE_RADSCORPION = 6;
  KILL_TYPE_RAT         = 7;
  KILL_TYPE_FLOATER     = 8;
  KILL_TYPE_CENTAUR     = 9;
  KILL_TYPE_ROBOT       = 10;
  KILL_TYPE_DOG         = 11;
  KILL_TYPE_MANTIS      = 12;
  KILL_TYPE_DEATH_CLAW  = 13;
  KILL_TYPE_PLANT       = 14;
  KILL_TYPE_COUNT       = 15;

  // Proto IDs (named)
  PROTO_ID_POWER_ARMOR          = 3;
  PROTO_ID_SMALL_ENERGY_CELL    = 38;
  PROTO_ID_MICRO_FUSION_CELL    = 39;
  PROTO_ID_STIMPACK             = 40;
  PROTO_ID_MONEY                = 41;
  PROTO_ID_FIRST_AID_KIT        = 47;
  PROTO_ID_RADAWAY              = 48;
  PROTO_ID_DYNAMITE_I           = 51;
  PROTO_ID_GEIGER_COUNTER_I     = 52;
  PROTO_ID_MENTATS              = 53;
  PROTO_ID_STEALTH_BOY_I        = 54;
  PROTO_ID_MOTION_SENSOR        = 59;
  PROTO_ID_BIG_BOOK_OF_SCIENCE  = 73;
  PROTO_ID_DEANS_ELECTRONICS    = 76;
  PROTO_ID_FLARE                = 79;
  PROTO_ID_FIRST_AID_BOOK       = 80;
  PROTO_ID_PLASTIC_EXPLOSIVES_I = 85;
  PROTO_ID_SCOUT_HANDBOOK       = 86;
  PROTO_ID_BUFF_OUT             = 87;
  PROTO_ID_DOCTORS_BAG          = 91;
  PROTO_ID_GUNS_AND_BULLETS     = 102;
  PROTO_ID_NUKA_COLA            = 106;
  PROTO_ID_PSYCHO               = 110;
  PROTO_ID_BEER                 = 124;
  PROTO_ID_BOOZE                = 125;
  PROTO_ID_SUPER_STIMPACK       = 144;
  PROTO_ID_MOLOTOV_COCKTAIL     = 159;
  PROTO_ID_LIT_FLARE            = 205;
  PROTO_ID_DYNAMITE_II          = 206;
  PROTO_ID_GEIGER_COUNTER_II    = 207;
  PROTO_ID_PLASTIC_EXPLOSIVES_II = 209;
  PROTO_ID_STEALTH_BOY_II       = 210;
  PROTO_ID_HARDENED_POWER_ARMOR = 232;

  // Proto IDs (hex-defined)
  PROTO_ID_0x1000098 = $1000098;
  PROTO_ID_0x10001E0 = $10001E0;
  PROTO_ID_0x2000031 = $2000031;
  PROTO_ID_0x2000158 = $2000158;
  PROTO_ID_CAR       = $20003F1;
  PROTO_ID_0x200050D = $200050D;
  PROTO_ID_0x2000099 = $2000099;
  PROTO_ID_0x20001A5 = $20001A5;
  PROTO_ID_0x20001D6 = $20001D6;
  PROTO_ID_0x20001EB = $20001EB;
  FID_0x20001F5      = $20001F5;
  PROTO_ID_0x5000010 = $5000010;
  PROTO_ID_0x5000017 = $5000017;

  // ItemProtoFlags
  ItemProtoFlags_0x08         = $08;
  ItemProtoFlags_0x10         = $10;
  ItemProtoFlags_0x1000       = $1000;
  ItemProtoFlags_0x8000       = $8000;
  ItemProtoFlags_0x20000000   = $20000000;
  ItemProtoFlags_0x80000000   = LongWord($80000000);

  // ItemProtoExtendedFlags
  ItemProtoExtendedFlags_BigGun        = $0100;
  ItemProtoExtendedFlags_IsTwoHanded   = $0200;
  ItemProtoExtendedFlags_0x0800        = $0800;
  ItemProtoExtendedFlags_0x1000        = $1000;
  ItemProtoExtendedFlags_0x2000        = $2000;
  ItemProtoExtendedFlags_0x8000        = $8000;
  ItemProtoExtendedFlags_NaturalWeapon = $08000000;

type
  // --- Item proto sub-data ---

  PProtoItemArmorData = ^TProtoItemArmorData;
  TProtoItemArmorData = record
    ArmorClass: Integer;
    DamageResistance: array[0..6] of Integer;
    DamageThreshold: array[0..6] of Integer;
    Perk: Integer;
    MaleFid: Integer;
    FemaleFid: Integer;
  end;

  PProtoItemContainerData = ^TProtoItemContainerData;
  TProtoItemContainerData = record
    MaxSize: Integer;
    OpenFlags: Integer;
  end;

  PProtoItemDrugData = ^TProtoItemDrugData;
  TProtoItemDrugData = record
    Stat: array[0..2] of Integer;
    Amount: array[0..2] of Integer;
    Duration1: Integer;
    Amount1: array[0..2] of Integer;
    Duration2: Integer;
    Amount2: array[0..2] of Integer;
    AddictionChance: Integer;
    WithdrawalEffect: Integer;
    WithdrawalOnset: Integer;
  end;

  PProtoItemWeaponData = ^TProtoItemWeaponData;
  TProtoItemWeaponData = record
    AnimationCode: Integer;
    MinDamage: Integer;
    MaxDamage: Integer;
    DamageType: Integer;
    MaxRange1: Integer;
    MaxRange2: Integer;
    ProjectilePid: Integer;
    MinStrength: Integer;
    ActionPointCost1: Integer;
    ActionPointCost2: Integer;
    CriticalFailureType: Integer;
    Perk: Integer;
    Rounds: Integer;
    Caliber: Integer;
    AmmoTypePid: Integer;
    AmmoCapacity: Integer;
    SoundCode: Byte;
  end;

  PProtoItemAmmoData = ^TProtoItemAmmoData;
  TProtoItemAmmoData = record
    Caliber: Integer;
    Quantity: Integer;
    ArmorClassModifier: Integer;
    DamageResistanceModifier: Integer;
    DamageMultiplier: Integer;
    DamageDivisor: Integer;
  end;

  PProtoItemMiscData = ^TProtoItemMiscData;
  TProtoItemMiscData = record
    PowerTypePid: Integer;
    PowerType: Integer;
    Charges: Integer;
  end;

  PProtoItemKeyData = ^TProtoItemKeyData;
  TProtoItemKeyData = record
    KeyCode: Integer;
  end;

  // --- ItemProtoData (variant record / union) ---

  PItemProtoData = ^TItemProtoData;
  TItemProtoData = record
    case Integer of
      0: (Unknown: record
            Field_0: Integer;
            Field_4: Integer;
            Field_8: Integer;
            Field_C: Integer;
            Field_10: Integer;
            Field_14: Integer;
            Field_18: Integer;
          end);
      1: (Armor: TProtoItemArmorData);
      2: (Container: TProtoItemContainerData);
      3: (Drug: TProtoItemDrugData);
      4: (Weapon: TProtoItemWeaponData);
      5: (Ammo: TProtoItemAmmoData);
      6: (Misc: TProtoItemMiscData);
      7: (Key: TProtoItemKeyData);
  end;

  // --- ItemProto ---

  PItemProto = ^TItemProto;
  TItemProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
    Sid: Integer;
    ItemType: Integer;
    Data: TItemProtoData;
    Material: Integer;
    Size: Integer;
    Weight: Integer;
    Cost: Integer;
    InventoryFid: Integer;
    Field_80: Byte;
  end;

  // --- CritterProto ---

  PCritterProtoData = ^TCritterProtoData;
  TCritterProtoData = record
    Flags: Integer;
    BaseStats: array[0..34] of Integer;
    BonusStats: array[0..34] of Integer;
    Skills: array[0..17] of Integer;
    BodyType: Integer;
    Experience: Integer;
    KillType: Integer;
  end;

  PCritterProto = ^TCritterProto;
  TCritterProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
    Sid: Integer;
    Data: TCritterProtoData;
    HeadFid: Integer;
    AiPacket: Integer;
    Team: Integer;
  end;

  // --- Scenery proto sub-data ---

  PSceneryProtoDoorData = ^TSceneryProtoDoorData;
  TSceneryProtoDoorData = record
    OpenFlags: Integer;
    KeyCode: Integer;
  end;

  PSceneryProtoStairsData = ^TSceneryProtoStairsData;
  TSceneryProtoStairsData = record
    Field_0: Integer;
    Field_4: Integer;
  end;

  PSceneryProtoElevatorData = ^TSceneryProtoElevatorData;
  TSceneryProtoElevatorData = record
    ElevatorType: Integer;
    Level: Integer;
  end;

  PSceneryProtoLadderData = ^TSceneryProtoLadderData;
  TSceneryProtoLadderData = record
    Field_0: Integer;
  end;

  PSceneryProtoGenericData = ^TSceneryProtoGenericData;
  TSceneryProtoGenericData = record
    Field_0: Integer;
  end;

  // --- SceneryProtoData (variant record / union) ---

  PSceneryProtoData = ^TSceneryProtoData;
  TSceneryProtoData = record
    case Integer of
      0: (Door: TSceneryProtoDoorData);
      1: (Stairs: TSceneryProtoStairsData);
      2: (Elevator: TSceneryProtoElevatorData);
      3: (Ladder: TSceneryProtoLadderData);
      4: (Generic: TSceneryProtoGenericData);
  end;

  // --- SceneryProto ---

  PSceneryProto = ^TSceneryProto;
  TSceneryProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
    Sid: Integer;
    SceneryType: Integer;
    Data: TSceneryProtoData;
    Material: Integer;
    Field_30: Integer;
    Field_34: Byte;
  end;

  // --- WallProto ---

  PWallProto = ^TWallProto;
  TWallProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
    Sid: Integer;
    Material: Integer;
  end;

  // --- TileProto (TTileProto to avoid name conflict) ---

  PTileProto = ^TTileProto;
  TTileProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
    Sid: Integer;
    Material: Integer;
  end;

  // --- MiscProto ---

  PMiscProto = ^TMiscProto;
  TMiscProto = record
    Pid: Integer;
    MessageId: Integer;
    Fid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Flags: Integer;
    ExtendedFlags: Integer;
  end;

  // --- Proto (variant record / union) ---

  PProto = ^TProto;
  TProto = record
    case Integer of
      0: (Pid: Integer;
          MessageId: Integer;
          Fid: Integer;
          LightDistance: Integer;
          LightIntensity: Integer;
          Flags: Integer;
          ExtendedFlags: Integer;
          Sid: Integer);
      1: (Item: TItemProto);
      2: (Critter: TCritterProto);
      3: (Scenery: TSceneryProto);
      4: (Wall: TWallProto);
      5: (Tile: TTileProto);
      6: (Misc: TMiscProto);
  end;

  // --- ProtoListExtent ---

  PProtoListExtent = ^TProtoListExtent;
  TProtoListExtent = record
    Proto: array[0..PROTO_LIST_EXTENT_SIZE - 1] of PProto;
    Length: Integer;
    Next: PProtoListExtent;
  end;

  // --- ProtoList ---

  PProtoList = ^TProtoList;
  TProtoList = record
    Head: PProtoListExtent;
    Tail: PProtoListExtent;
    Length: Integer;
    MaxEntriesNum: Integer;
  end;

implementation

end.
