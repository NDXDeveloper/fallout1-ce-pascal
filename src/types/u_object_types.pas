unit u_object_types;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

type
  TRotation = (
    ROTATION_NE    = 0,
    ROTATION_E     = 1,
    ROTATION_SE    = 2,
    ROTATION_SW    = 3,
    ROTATION_W     = 4,
    ROTATION_NW    = 5,
    ROTATION_COUNT = 6
  );
  PRotation = ^TRotation;

const
  OBJ_TYPE_ITEM      = 0;
  OBJ_TYPE_CRITTER   = 1;
  OBJ_TYPE_SCENERY   = 2;
  OBJ_TYPE_WALL      = 3;
  OBJ_TYPE_TILE      = 4;
  OBJ_TYPE_MISC      = 5;
  OBJ_TYPE_INTERFACE = 6;
  OBJ_TYPE_INVENTORY = 7;
  OBJ_TYPE_HEAD      = 8;
  OBJ_TYPE_BACKGROUND = 9;
  OBJ_TYPE_SKILLDEX  = 10;
  OBJ_TYPE_COUNT     = 11;

function FID_TYPE(value: Integer): Integer; inline;
function PID_TYPE(value: Integer): Integer; inline;
function SID_TYPE(value: Integer): Integer; inline;

type
  TOutlineType = (
    OUTLINE_TYPE_HOSTILE  = 1,
    OUTLINE_TYPE_2        = 2,
    OUTLINE_TYPE_4        = 4,
    OUTLINE_TYPE_FRIENDLY = 8,
    OUTLINE_TYPE_ITEM     = 16
  );
  POutlineType = ^TOutlineType;

const
  OBJECT_HIDDEN         = $01;
  OBJECT_NO_SAVE        = $04;
  OBJECT_FLAT           = $08;
  OBJECT_NO_BLOCK       = $10;
  OBJECT_LIGHTING       = $20;
  OBJECT_NO_REMOVE      = $400;
  OBJECT_MULTIHEX       = $800;
  OBJECT_NO_HIGHLIGHT   = $1000;
  OBJECT_USED           = $2000;
  OBJECT_TRANS_RED      = $4000;
  OBJECT_TRANS_NONE     = $8000;
  OBJECT_TRANS_WALL     = $10000;
  OBJECT_TRANS_GLASS    = $20000;
  OBJECT_TRANS_STEAM    = $40000;
  OBJECT_TRANS_ENERGY   = $80000;
  OBJECT_IN_LEFT_HAND   = $1000000;
  OBJECT_IN_RIGHT_HAND  = $2000000;
  OBJECT_WORN           = $4000000;
  OBJECT_WALL_TRANS_END = LongWord($10000000);
  OBJECT_LIGHT_THRU     = LongWord($20000000);
  OBJECT_SEEN           = LongWord($40000000);
  OBJECT_SHOOT_THRU     = LongWord($80000000);
  OBJECT_IN_ANY_HAND    = OBJECT_IN_LEFT_HAND or OBJECT_IN_RIGHT_HAND;
  OBJECT_EQUIPPED       = OBJECT_IN_ANY_HAND or OBJECT_WORN;
  OBJECT_FLAG_0xFC000   = OBJECT_TRANS_ENERGY or OBJECT_TRANS_STEAM
                          or OBJECT_TRANS_GLASS or OBJECT_TRANS_WALL
                          or OBJECT_TRANS_NONE or OBJECT_TRANS_RED;
  OBJECT_OPEN_DOOR      = OBJECT_SHOOT_THRU or OBJECT_LIGHT_THRU
                          or OBJECT_NO_BLOCK;

const
  CRITTER_BARTER        = $02;
  CRITTER_NO_STEAL      = $20;
  CRITTER_NO_DROP       = $40;
  CRITTER_NO_LIMBS      = $80;
  CRITTER_NO_AGE        = $100;
  CRITTER_NO_HEAL       = $200;
  CRITTER_INVULNERABLE  = $400;
  CRITTER_FLAT          = $800;
  CRITTER_SPECIAL_DEATH = $1000;
  CRITTER_LONG_LIMBS    = $2000;
  CRITTER_NO_KNOCKBACK  = $4000;

const
  OUTLINE_TYPE_MASK      = $FFFFFF;
  OUTLINE_PALETTED       = LongWord($40000000);
  OUTLINE_DISABLED       = LongWord($80000000);
  CONTAINER_FLAG_JAMMED  = $04000000;
  DOOR_FLAG_JAMMGED      = $04000000;
  CONTAINER_FLAG_LOCKED  = $02000000;
  DOOR_FLAG_LOCKED       = $02000000;

const
  CRITTER_MANEUVER_NONE        = 0;
  CRITTER_MANEUVER_ENGAGING    = $01;
  CRITTER_MANEUVER_DISENGAGING = $02;
  CRITTER_MANUEVER_FLEEING     = $04;

const
  DAM_KNOCKED_OUT     = $01;
  DAM_KNOCKED_DOWN    = $02;
  DAM_CRIP_LEG_LEFT   = $04;
  DAM_CRIP_LEG_RIGHT  = $08;
  DAM_CRIP_ARM_LEFT   = $10;
  DAM_CRIP_ARM_RIGHT  = $20;
  DAM_BLIND           = $40;
  DAM_DEAD            = $80;
  DAM_HIT             = $100;
  DAM_CRITICAL        = $200;
  DAM_ON_FIRE         = $400;
  DAM_BYPASS          = $800;
  DAM_EXPLODE         = $1000;
  DAM_DESTROY         = $2000;
  DAM_DROP            = $4000;
  DAM_LOSE_TURN       = $8000;
  DAM_HIT_SELF        = $10000;
  DAM_LOSE_AMMO       = $20000;
  DAM_DUD             = $40000;
  DAM_HURT_SELF       = $80000;
  DAM_RANDOM_HIT      = $100000;
  DAM_CRIP_RANDOM     = $200000;
  DAM_BACKWASH        = $400000;
  DAM_PERFORM_REVERSE = $800000;
  DAM_CRIP_LEG_ANY    = DAM_CRIP_LEG_LEFT or DAM_CRIP_LEG_RIGHT;
  DAM_CRIP_ARM_ANY    = DAM_CRIP_ARM_LEFT or DAM_CRIP_ARM_RIGHT;
  DAM_CRIP            = DAM_CRIP_LEG_ANY or DAM_CRIP_ARM_ANY or DAM_BLIND;

const
  OBJ_LOCKED = $02000000;
  OBJ_JAMMED = $04000000;

type
  { Forward declaration }
  PObject = ^TObject;
  PPObject = ^PObject;
  PPPObject = ^PPObject;

  PInventoryItem = ^TInventoryItem;
  TInventoryItem = record
    Item: PObject;
    Quantity: Integer;
  end;

  PInventory = ^TInventory;
  TInventory = record
    Length: Integer;
    Capacity: Integer;
    Items: PInventoryItem;
  end;

  PWeaponObjectData = ^TWeaponObjectData;
  TWeaponObjectData = record
    AmmoQuantity: Integer;
    AmmoTypePid: Integer;
  end;

  PAmmoItemData = ^TAmmoItemData;
  TAmmoItemData = record
    Quantity: Integer;
  end;

  PMiscItemData = ^TMiscItemData;
  TMiscItemData = record
    Charges: Integer;
  end;

  PKeyItemData = ^TKeyItemData;
  TKeyItemData = record
    KeyCode: Integer;
  end;

  PItemObjectData = ^TItemObjectData;
  TItemObjectData = record
    case Integer of
      0: (Weapon: TWeaponObjectData);
      1: (Ammo: TAmmoItemData);
      2: (Misc: TMiscItemData);
      3: (Key: TKeyItemData);
  end;

  PWhoHitMe = ^TWhoHitMe;
  TWhoHitMe = record
    case Integer of
      0: (WhoHitMe: PObject);
      1: (WhoHitMeCid: Integer);
  end;

  PCritterCombatData = ^TCritterCombatData;
  TCritterCombatData = record
    Maneuver: Integer;
    Ap: Integer;
    Results: Integer;
    DamageLastTurn: Integer;
    AiPacket: Integer;
    Team: Integer;
    WhoHitMeUnion: TWhoHitMe;
  end;

  PCritterObjectData = ^TCritterObjectData;
  TCritterObjectData = record
    Field_0: Integer;
    Combat: TCritterCombatData;
    Hp: Integer;
    Radiation: Integer;
    Poison: Integer;
  end;

  PDoorSceneryData = ^TDoorSceneryData;
  TDoorSceneryData = record
    OpenFlags: Integer;
  end;

  PStairsSceneryData = ^TStairsSceneryData;
  TStairsSceneryData = record
    DestinationMap: Integer;
    DestinationBuiltTile: Integer;
  end;

  PElevatorSceneryData = ^TElevatorSceneryData;
  TElevatorSceneryData = record
    SceneryType: Integer;
    Level: Integer;
  end;

  PLadderSceneryData = ^TLadderSceneryData;
  TLadderSceneryData = record
    DestinationBuiltTile: Integer;
  end;

  PSceneryObjectData = ^TSceneryObjectData;
  TSceneryObjectData = record
    case Integer of
      0: (Door: TDoorSceneryData);
      1: (Stairs: TStairsSceneryData);
      2: (Elevator: TElevatorSceneryData);
      3: (Ladder: TLadderSceneryData);
  end;

  PMiscObjectData = ^TMiscObjectData;
  TMiscObjectData = record
    Map: Integer;
    Tile: Integer;
    Elevation: Integer;
    Rotation: Integer;
  end;

  PItemSceneryMiscOverlay = ^TItemSceneryMiscOverlay;
  TItemSceneryMiscOverlay = record
    case Integer of
      0: (Item: TItemObjectData);
      1: (Scenery: TSceneryObjectData);
      2: (Misc: TMiscObjectData);
  end;

  PObjectData = ^TObjectData;
  TObjectData = record
    Inventory: TInventory;
    case Integer of
      0: (Critter: TCritterObjectData);
      1: (Flags: Integer;
          ItemSceneryMisc: TItemSceneryMiscOverlay);
  end;

  PObjectDataOverlay = ^TObjectDataOverlay;
  TObjectDataOverlay = record
    case Integer of
      0: (AsArray: array[0..13] of Integer);
      1: (AsData: TObjectData);
  end;

  TObject = record
    Id: Integer;
    Tile: Integer;
    X: Integer;
    Y: Integer;
    Sx: Integer;
    Sy: Integer;
    Frame: Integer;
    Rotation: Integer;
    Fid: Integer;
    Flags: Integer;
    Elevation: Integer;
    Data: TObjectDataOverlay;
    Pid: Integer;
    Cid: Integer;
    LightDistance: Integer;
    LightIntensity: Integer;
    Outline: Integer;
    Sid: Integer;
    Owner: PObject;
    Field_80: Integer;
  end;

  PObjectListNode = ^TObjectListNode;
  TObjectListNode = record
    Obj: PObject;
    Next: PObjectListNode;
  end;

const
  BUILT_TILE_TILE_MASK       = $3FFFFFF;
  BUILT_TILE_ELEVATION_MASK  = LongWord($E0000000);
  BUILT_TILE_ELEVATION_SHIFT = 29;
  BUILT_TILE_ROTATION_MASK   = $1C000000;
  BUILT_TILE_ROTATION_SHIFT  = 26;

function BuiltTileGetTile(BuiltTile: Integer): Integer; inline;
function BuiltTileGetElevation(BuiltTile: Integer): Integer; inline;
function BuiltTileGetRotation(BuiltTile: Integer): Integer; inline;
function BuiltTileCreate(Tile, Elevation: Integer): Integer; inline;

implementation

function FID_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $F000000) shr 24;
end;

function PID_TYPE(value: Integer): Integer; inline;
begin
  Result := value shr 24;
end;

function SID_TYPE(value: Integer): Integer; inline;
begin
  Result := value shr 24;
end;

function BuiltTileGetTile(BuiltTile: Integer): Integer; inline;
begin
  Result := BuiltTile and Integer(BUILT_TILE_TILE_MASK);
end;

function BuiltTileGetElevation(BuiltTile: Integer): Integer; inline;
begin
  Result := (BuiltTile and Integer(BUILT_TILE_ELEVATION_MASK)) shr BUILT_TILE_ELEVATION_SHIFT;
end;

function BuiltTileGetRotation(BuiltTile: Integer): Integer; inline;
begin
  Result := (BuiltTile and Integer(BUILT_TILE_ROTATION_MASK)) shr BUILT_TILE_ROTATION_SHIFT;
end;

function BuiltTileCreate(Tile, Elevation: Integer): Integer; inline;
begin
  Result := Tile or ((Elevation shl BUILT_TILE_ELEVATION_SHIFT) and Integer(BUILT_TILE_ELEVATION_MASK));
end;

end.
