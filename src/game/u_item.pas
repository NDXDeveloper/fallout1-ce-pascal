unit u_item;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/item.h + item.cc
// Item management: inventory, weapon, armor, drug, misc item functions.

interface

uses
  u_db,
  u_object_types;

const
  ADDICTION_COUNT = 7;

  ATTACK_TYPE_NONE    = 0;
  ATTACK_TYPE_UNARMED = 1;
  ATTACK_TYPE_MELEE   = 2;
  ATTACK_TYPE_THROW   = 3;
  ATTACK_TYPE_RANGED  = 4;
  ATTACK_TYPE_COUNT   = 5;

function item_init: Integer;
function item_reset: Integer;
function item_exit: Integer;
function item_load(stream: PDB_FILE): Integer;
function item_save(stream: PDB_FILE): Integer;
function item_add_mult(owner: PObject; itemToAdd: PObject; quantity: Integer): Integer;
function item_add_force(owner: PObject; itemToAdd: PObject; quantity: Integer): Integer;
function item_remove_mult(owner: PObject; itemToRemove: PObject; quantity: Integer): Integer;
function item_move(a1: PObject; a2: PObject; a3: PObject; quantity: Integer): Integer;
function item_move_force(a1: PObject; a2: PObject; a3: PObject; quantity: Integer): Integer;
procedure item_move_all(a1: PObject; a2: PObject);
function item_drop_all(critter: PObject; tile: Integer): Integer;
function item_name(obj: PObject): PAnsiChar;
function item_description(obj: PObject): PAnsiChar;
function item_get_type(item: PObject): Integer;
function item_material(item: PObject): Integer;
function item_size(obj: PObject): Integer;
function item_weight(item: PObject): Integer;
function item_cost(obj: PObject): Integer;
function item_total_cost(obj: PObject): Integer;
function item_total_weight(obj: PObject): Integer;
function item_grey(weapon: PObject): Boolean;
function item_inv_fid(item: PObject): Integer;
function item_hit_with(critter: PObject; hit_mode: Integer): PObject;
function item_mp_cost(critter: PObject; hit_mode: Integer; aiming: Boolean): Integer;
function item_count(obj: PObject; a2: PObject): Integer;
function item_queued(obj: PObject): Integer;
function item_replace(a1: PObject; a2: PObject; a3: Integer): PObject;
function item_w_subtype(weapon: PObject; hitMode: Integer): Integer;
function item_w_skill(weapon: PObject; hitMode: Integer): Integer;
function item_w_skill_level(critter: PObject; hit_mode: Integer): Integer;
function item_w_damage_min_max(weapon: PObject; min_damage: PInteger; max_damage: PInteger): Integer;
function item_w_damage(critter: PObject; hit_mode: Integer): Integer;
function item_w_damage_type(weapon: PObject): Integer;
function item_w_is_2handed(weapon: PObject): Integer;
function item_w_anim(critter: PObject; hit_mode: Integer): Integer;
function item_w_anim_weap(weapon: PObject; hit_mode: Integer): Integer;
function item_w_max_ammo(ammoOrWeapon: PObject): Integer;
function item_w_curr_ammo(ammoOrWeapon: PObject): Integer;
function item_w_caliber(ammoOrWeapon: PObject): Integer;
procedure item_w_set_curr_ammo(ammoOrWeapon: PObject; quantity: Integer);
function item_w_try_reload(critter: PObject; weapon: PObject): Integer;
function item_w_can_reload(weapon: PObject; ammo: PObject): Boolean;
function item_w_reload(weapon: PObject; ammo: PObject): Integer;
function item_w_range(critter: PObject; hit_mode: Integer): Integer;
function item_w_mp_cost(critter: PObject; hit_mode: Integer; aiming: Boolean): Integer;
function item_w_min_st(weapon: PObject): Integer;
function item_w_crit_fail(weapon: PObject): Integer;
function item_w_perk(weapon: PObject): Integer;
function item_w_rounds(weapon: PObject): Integer;
function item_w_anim_code(weapon: PObject): Integer;
function item_w_proj_pid(weapon: PObject): Integer;
function item_w_ammo_pid(weapon: PObject): Integer;
function item_w_sound_id(weapon: PObject): AnsiChar;
function item_w_called_shot(critter: PObject; hit_mode: Integer): Integer;
function item_w_can_unload(weapon: PObject): Integer;
function item_w_unload(weapon: PObject): PObject;
function item_w_primary_mp_cost(weapon: PObject): Integer;
function item_w_secondary_mp_cost(weapon: PObject): Integer;
function item_ar_ac(armor: PObject): Integer;
function item_ar_dr(armor: PObject; damageType: Integer): Integer;
function item_ar_dt(armor: PObject; damageType: Integer): Integer;
function item_ar_perk(armor: PObject): Integer;
function item_ar_male_fid(armor: PObject): Integer;
function item_ar_female_fid(armor: PObject): Integer;
function item_m_max_charges(misc_item: PObject): Integer;
function item_m_curr_charges(misc_item: PObject): Integer;
function item_m_set_charges(miscItem: PObject; charges: Integer): Integer;
function item_m_cell(miscItem: PObject): Integer;
function item_m_cell_pid(miscItem: PObject): Integer;
function item_m_uses_charges(miscItem: PObject): Boolean;
function item_m_use_charged_item(critter: PObject; miscItem: PObject): Integer;
function item_m_dec_charges(item: PObject): Integer;
function item_m_trickle(item_obj: PObject; data: Pointer): Integer; cdecl;
function item_m_on(obj: PObject): Boolean;
function item_m_turn_on(item_obj: PObject): Integer;
function item_m_turn_off(item_obj: PObject): Integer;
function item_m_turn_off_from_queue(obj: PObject; data: Pointer): Integer; cdecl;
function item_c_max_size(container: PObject): Integer;
function item_c_curr_size(container: PObject): Integer;
function item_d_take_drug(critter_obj: PObject; item_obj: PObject): Integer;
function item_d_clear(obj: PObject; data: Pointer): Integer; cdecl;
function item_d_process(obj: PObject; data: Pointer): Integer; cdecl;
function item_d_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
function item_d_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
function item_wd_clear(obj: PObject; data: Pointer): Integer; cdecl;
function item_wd_process(obj: PObject; data: Pointer): Integer; cdecl;
function item_wd_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
function item_wd_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
procedure item_d_set_addict(drugPid: Integer);
procedure item_d_unset_addict(drugPid: Integer);
function item_d_check_addict(drugPid: Integer): Boolean;
function item_caps_total(obj: PObject): Integer;
function item_caps_adjust(obj: PObject; amount: Integer): Integer;
function item_caps_get_amount(obj: PObject): Integer;
function item_caps_set_amount(obj: PObject; amount: Integer): Integer;

implementation

uses
  SysUtils,
  u_memory,
  u_proto_types,
  u_stat_defs,
  u_queue,
  u_perk,
  u_message,
  u_proto,
  u_object,
  u_art,
  u_critter,
  u_stat,
  u_skill,
  u_trait,
  u_roll,
  u_intface,
  u_protinst,
  u_party,
  u_automap,
  u_game,
  u_map,
  u_rect,
  u_display,
  u_inventry,
  u_tile;

const
  COMPAT_MAX_PATH = 260;

  // Hit modes
  HIT_MODE_LEFT_WEAPON_PRIMARY    = 0;
  HIT_MODE_LEFT_WEAPON_SECONDARY  = 1;
  HIT_MODE_RIGHT_WEAPON_PRIMARY   = 2;
  HIT_MODE_RIGHT_WEAPON_SECONDARY = 3;
  HIT_MODE_PUNCH                  = 4;
  HIT_MODE_KICK                   = 5;
  HIT_MODE_LEFT_WEAPON_RELOAD     = 6;
  HIT_MODE_RIGHT_WEAPON_RELOAD    = 7;

  // Skill constants
  SKILL_SMALL_GUNS    = 0;
  SKILL_BIG_GUNS      = 1;
  SKILL_ENERGY_WEAPONS = 2;
  SKILL_UNARMED       = 3;
  SKILL_MELEE_WEAPONS = 4;
  SKILL_THROWING      = 5;

  // Trait constants
  TRAIT_FAST_SHOT      = 0;
  TRAIT_CHEM_RELIANT   = 9;
  TRAIT_CHEM_RESISTANT = 10;

  // Anim constants
  ANIM_STAND           = 0;
  ANIM_THROW_PUNCH     = 7;
  ANIM_KICK_LEG        = 8;
  ANIM_SWING_ANIM      = 9;
  ANIM_THRUST_ANIM     = 10;
  ANIM_THROW_ANIM      = 11;
  ANIM_FIRE_SINGLE     = 12;
  ANIM_FIRE_BURST      = 13;
  ANIM_FIRE_CONTINUOUS = 14;

  // GVAR constants
  GVAR_NUKA_COLA_ADDICT = 0;
  GVAR_BUFF_OUT_ADDICT  = 2;
  GVAR_MENTATS_ADDICT   = 3;
  GVAR_PSYCHO_ADDICT    = 4;
  GVAR_RADAWAY_ADDICT   = 5;
  GVAR_ALCOHOL_ADDICT   = 6;

  PC_FLAG_ADDICTED = 4;

// debug
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// -----------------------------------------------------------------------
// FID_ANIM_TYPE inline
// -----------------------------------------------------------------------
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// -----------------------------------------------------------------------
// Static forward declarations
// -----------------------------------------------------------------------
procedure item_compact(inventoryItemIndex: Integer; inventory: PInventory); forward;
function item_move_func(a1: PObject; a2: PObject; a3: PObject; quantity: Integer; a5: Boolean): Integer; forward;
function item_identical(a1: PObject; a2: PObject): Boolean; forward;
function item_m_stealth_effect_on(obj: PObject): Integer; forward;
function item_m_stealth_effect_off(critter: PObject; item: PObject): Integer; forward;
function insert_drug_effect(critter: PObject; item: PObject; a3: Integer; stats: PInteger; mods: PInteger): Integer; forward;
procedure perform_drug_effect(critter: PObject; stats: PInteger; mods: PInteger; is_immediate: Boolean); forward;
function insert_withdrawal(obj: PObject; a2: Integer; duration: Integer; perk: Integer; pid: Integer): Integer; forward;
function item_wd_clear_all(a1: PObject; data: Pointer): Integer; cdecl; forward;
procedure perform_withdrawal_start(obj: PObject; perk: Integer; pid: Integer); forward;
procedure perform_withdrawal_end(obj: PObject; perk: Integer); forward;
function pid_to_gvar(drugPid: Integer): Integer; forward;

// -----------------------------------------------------------------------
// Module-level variables (includes C++ static locals)
// -----------------------------------------------------------------------
var
  // Maps weapon extended flags to skill.
  attack_skill: array[0..8] of Integer = (
    -1,
    SKILL_UNARMED,
    SKILL_UNARMED,
    SKILL_MELEE_WEAPONS,
    SKILL_MELEE_WEAPONS,
    SKILL_THROWING,
    SKILL_SMALL_GUNS,
    SKILL_SMALL_GUNS,
    SKILL_SMALL_GUNS
  );

  // A map of item's extendedFlags to animation.
  attack_anim: array[0..8] of Integer = (
    ANIM_STAND,
    ANIM_THROW_PUNCH,
    ANIM_KICK_LEG,
    ANIM_SWING_ANIM,
    ANIM_THRUST_ANIM,
    ANIM_THROW_ANIM,
    ANIM_FIRE_SINGLE,
    ANIM_FIRE_BURST,
    ANIM_FIRE_CONTINUOUS
  );

  // Maps weapon extended flags to weapon class
  attack_subtype: array[0..8] of Integer = (
    ATTACK_TYPE_NONE,
    ATTACK_TYPE_UNARMED,
    ATTACK_TYPE_UNARMED,
    ATTACK_TYPE_MELEE,
    ATTACK_TYPE_MELEE,
    ATTACK_TYPE_THROW,
    ATTACK_TYPE_RANGED,
    ATTACK_TYPE_RANGED,
    ATTACK_TYPE_RANGED
  );

  drug_gvar: array[0..6] of Integer = (
    GVAR_NUKA_COLA_ADDICT,
    GVAR_BUFF_OUT_ADDICT,
    GVAR_MENTATS_ADDICT,
    GVAR_PSYCHO_ADDICT,
    GVAR_RADAWAY_ADDICT,
    GVAR_ALCOHOL_ADDICT,
    GVAR_ALCOHOL_ADDICT
  );

  drug_pid: array[0..6] of Integer = (
    PROTO_ID_NUKA_COLA,
    PROTO_ID_BUFF_OUT,
    PROTO_ID_MENTATS,
    PROTO_ID_PSYCHO,
    PROTO_ID_RADAWAY,
    PROTO_ID_BEER,
    PROTO_ID_BOOZE
  );

  // item.msg
  item_message_file: TMessageList;

  wd_onset: Integer;
  wd_obj: PObject;
  wd_gvar: Integer;

  // Static local from item_name
  _item_name: array[0..6] of AnsiChar = '<item>';
  _item_name_ptr: PAnsiChar = nil;

// =======================================================================
// item_init
// =======================================================================
function item_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if not message_init(@item_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'item.msg']);

  if not message_load(@item_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// item_reset
// =======================================================================
function item_reset: Integer;
begin
  Result := 0;
end;

// =======================================================================
// item_exit
// =======================================================================
function item_exit: Integer;
begin
  message_exit(@item_message_file);
  Result := 0;
end;

// =======================================================================
// item_load
// =======================================================================
function item_load(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// =======================================================================
// item_save
// =======================================================================
function item_save(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// =======================================================================
// item_add_mult
// =======================================================================
function item_add_mult(owner: PObject; itemToAdd: PObject; quantity: Integer): Integer;
var
  parentType: Integer;
  itemType: Integer;
  sizeToAdd: Integer;
  currentSize: Integer;
  maxSize: Integer;
  containerOwner: PObject;
  weightToAdd: Integer;
  currentWeight: Integer;
  maxWeight: Integer;
  powerTypePid: Integer;
begin
  if quantity < 1 then
  begin
    Result := -1;
    Exit;
  end;

  parentType := FID_TYPE(owner^.Fid);
  if parentType = OBJ_TYPE_ITEM then
  begin
    itemType := item_get_type(owner);
    if itemType = ITEM_TYPE_CONTAINER then
    begin
      // NOTE: Uninline.
      sizeToAdd := item_size(itemToAdd);
      sizeToAdd := sizeToAdd * quantity;

      currentSize := item_c_curr_size(owner);
      maxSize := item_c_max_size(owner);
      if currentSize + sizeToAdd >= maxSize then
      begin
        Result := -6;
        Exit;
      end;

      containerOwner := obj_top_environment(owner);
      if containerOwner <> nil then
      begin
        if FID_TYPE(containerOwner^.Fid) = OBJ_TYPE_CRITTER then
        begin
          weightToAdd := item_weight(itemToAdd);
          weightToAdd := weightToAdd * quantity;

          currentWeight := item_total_weight(containerOwner);
          maxWeight := stat_level(containerOwner, Ord(STAT_CARRY_WEIGHT));
          if currentWeight + weightToAdd > maxWeight then
          begin
            Result := -6;
            Exit;
          end;
        end;
      end;
    end
    else if itemType = ITEM_TYPE_MISC then
    begin
      // NOTE: Uninline.
      powerTypePid := item_m_cell_pid(owner);
      if powerTypePid <> itemToAdd^.Pid then
      begin
        Result := -1;
        Exit;
      end;
    end
    else
    begin
      Result := -1;
      Exit;
    end;
  end
  else if parentType = OBJ_TYPE_CRITTER then
  begin
    if critter_body_type(owner) <> BODY_TYPE_BIPED then
    begin
      Result := -5;
      Exit;
    end;

    weightToAdd := item_weight(itemToAdd);
    weightToAdd := weightToAdd * quantity;

    currentWeight := item_total_weight(owner);
    maxWeight := stat_level(owner, Ord(STAT_CARRY_WEIGHT));
    if currentWeight + weightToAdd > maxWeight then
    begin
      Result := -6;
      Exit;
    end;
  end;

  Result := item_add_force(owner, itemToAdd, quantity);
end;

// =======================================================================
// item_add_force
// =======================================================================
function item_add_force(owner: PObject; itemToAdd: PObject; quantity: Integer): Integer;
var
  inventory: PInventory;
  index: Integer;
  inventoryItems: PInventoryItem;
  ammoQuantityToAdd: Integer;
  ammoQuantity: Integer;
  capacity: Integer;
begin
  if quantity < 1 then
  begin
    Result := -1;
    Exit;
  end;

  inventory := @(owner^.Data.AsData.Inventory);

  index := 0;
  while index < inventory^.Length do
  begin
    if item_identical(PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Item, itemToAdd) then
      Break;
    Inc(index);
  end;

  if index = inventory^.Length then
  begin
    if (inventory^.Length = inventory^.Capacity) or (inventory^.Items = nil) then
    begin
      inventoryItems := PInventoryItem(mem_realloc(inventory^.Items, SizeUInt(SizeOf(TInventoryItem)) * SizeUInt(inventory^.Capacity + 10)));
      if inventoryItems = nil then
      begin
        Result := -1;
        Exit;
      end;

      inventory^.Items := inventoryItems;
      inventory^.Capacity := inventory^.Capacity + 10;
    end;

    PInventoryItem(PByte(inventory^.Items) + SizeUInt(inventory^.Length) * SizeOf(TInventoryItem))^.Item := itemToAdd;
    PInventoryItem(PByte(inventory^.Items) + SizeUInt(inventory^.Length) * SizeOf(TInventoryItem))^.Quantity := quantity;

    if itemToAdd^.Pid = PROTO_ID_STEALTH_BOY_II then
    begin
      if (itemToAdd^.Flags and OBJECT_IN_ANY_HAND) <> 0 then
      begin
        // NOTE: Uninline.
        item_m_stealth_effect_on(owner);
      end;
    end;

    inventory^.Length := inventory^.Length + 1;
    itemToAdd^.Owner := owner;

    Result := 0;
    Exit;
  end;

  if itemToAdd = PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Item then
  begin
    debug_printf('Warning! Attempt to add same item twice in item_add()'#10);
    Result := 0;
    Exit;
  end;

  if item_get_type(itemToAdd) = ITEM_TYPE_AMMO then
  begin
    // NOTE: Uninline.
    ammoQuantityToAdd := item_w_curr_ammo(itemToAdd);
    ammoQuantity := item_w_curr_ammo(PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Item);

    // NOTE: Uninline.
    capacity := item_w_max_ammo(itemToAdd);

    ammoQuantity := ammoQuantity + ammoQuantityToAdd;
    if ammoQuantity > capacity then
    begin
      item_w_set_curr_ammo(itemToAdd, ammoQuantity - capacity);
      PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity :=
        PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity + 1;
    end
    else
    begin
      item_w_set_curr_ammo(itemToAdd, ammoQuantity);
    end;

    PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity :=
      PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity + quantity - 1;
  end
  else
  begin
    PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity :=
      PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Quantity + quantity;
  end;

  obj_erase_object(PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Item, nil);
  PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem))^.Item := itemToAdd;
  itemToAdd^.Owner := owner;

  Result := 0;
end;

// =======================================================================
// item_remove_mult
// =======================================================================
function item_remove_mult(owner: PObject; itemToRemove: PObject; quantity: Integer): Integer;
var
  inventory: PInventory;
  item1: PObject;
  item2: PObject;
  index: Integer;
  inventoryItem: PInventoryItem;
  capacity: Integer;
  theOwner: PObject;
begin
  inventory := @(owner^.Data.AsData.Inventory);
  item1 := inven_left_hand(owner);
  item2 := inven_right_hand(owner);

  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    if inventoryItem^.Item = itemToRemove then
      Break;

    if item_get_type(inventoryItem^.Item) = ITEM_TYPE_CONTAINER then
    begin
      if item_remove_mult(inventoryItem^.Item, itemToRemove, quantity) = 0 then
      begin
        Result := 0;
        Exit;
      end;
    end;
    Inc(index);
  end;

  if index = inventory^.Length then
  begin
    Result := -1;
    Exit;
  end;

  inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
  if inventoryItem^.Quantity < quantity then
  begin
    Result := -1;
    Exit;
  end;

  if inventoryItem^.Quantity = quantity then
  begin
    // NOTE: Uninline.
    item_compact(index, inventory);
  end
  else
  begin
    if obj_copy(@(inventoryItem^.Item), itemToRemove) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    obj_disconnect(inventoryItem^.Item, nil);

    inventoryItem^.Quantity := inventoryItem^.Quantity - quantity;

    if item_get_type(itemToRemove) = ITEM_TYPE_AMMO then
    begin
      capacity := item_w_max_ammo(itemToRemove);
      item_w_set_curr_ammo(inventoryItem^.Item, capacity);
    end;
  end;

  if (itemToRemove^.Pid = PROTO_ID_STEALTH_BOY_I) or (itemToRemove^.Pid = PROTO_ID_STEALTH_BOY_II) then
  begin
    if (itemToRemove = item1) or (itemToRemove = item2) then
    begin
      theOwner := obj_top_environment(itemToRemove);
      if theOwner <> nil then
      begin
        item_m_stealth_effect_off(theOwner, itemToRemove);
      end;
    end;
  end;

  itemToRemove^.Owner := nil;
  itemToRemove^.Flags := itemToRemove^.Flags and (not LongWord(OBJECT_EQUIPPED));

  Result := 0;
end;

// =======================================================================
// item_compact (static)
// =======================================================================
procedure item_compact(inventoryItemIndex: Integer; inventory: PInventory);
var
  index: Integer;
  prev: PInventoryItem;
  curr: PInventoryItem;
begin
  index := inventoryItemIndex + 1;
  while index < inventory^.Length do
  begin
    prev := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index - 1) * SizeOf(TInventoryItem));
    curr := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    Move(curr^, prev^, SizeOf(TInventoryItem));
    Inc(index);
  end;
  inventory^.Length := inventory^.Length - 1;
end;

// =======================================================================
// item_move_func (static)
// =======================================================================
function item_move_func(a1: PObject; a2: PObject; a3: PObject; quantity: Integer; a5: Boolean): Integer;
var
  rc: Integer;
  owner: PObject;
  updatedRect: TRect;
begin
  if item_remove_mult(a1, a3, quantity) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if a5 then
    rc := item_add_force(a2, a3, quantity)
  else
    rc := item_add_mult(a2, a3, quantity);

  if rc <> 0 then
  begin
    if item_add_force(a1, a3, quantity) <> 0 then
    begin
      owner := obj_top_environment(a1);
      if owner = nil then
        owner := a1;

      if owner^.Tile <> -1 then
      begin
        obj_connect(a3, owner^.Tile, owner^.Elevation, @updatedRect);
        tile_refresh_rect(@updatedRect, map_elevation);
      end;
    end;
    Result := -1;
    Exit;
  end;

  a3^.Owner := a2;

  Result := 0;
end;

// =======================================================================
// item_move
// =======================================================================
function item_move(a1: PObject; a2: PObject; a3: PObject; quantity: Integer): Integer;
begin
  Result := item_move_func(a1, a2, a3, quantity, False);
end;

// =======================================================================
// item_move_force
// =======================================================================
function item_move_force(a1: PObject; a2: PObject; a3: PObject; quantity: Integer): Integer;
begin
  Result := item_move_func(a1, a2, a3, quantity, True);
end;

// =======================================================================
// item_move_all
// =======================================================================
procedure item_move_all(a1: PObject; a2: PObject);
var
  inventory: PInventory;
  inventoryItem: PInventoryItem;
begin
  inventory := @(a1^.Data.AsData.Inventory);
  while inventory^.Length > 0 do
  begin
    inventoryItem := PInventoryItem(inventory^.Items);
    item_move_func(a1, a2, inventoryItem^.Item, inventoryItem^.Quantity, True);
  end;
end;

// =======================================================================
// item_drop_all
// =======================================================================
function item_drop_all(critter: PObject; tile: Integer): Integer;
var
  hasEquippedItems: Boolean;
  frmId: Integer;
  inventory: PInventory;
  index: Integer;
  innerIdx: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
  proto: PProto;
  fid: Integer;
  updatedRect: TRect;
  qty: Integer;
begin
  hasEquippedItems := False;

  frmId := critter^.Fid and $FFF;

  inventory := @(critter^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    item := inventoryItem^.Item;
    if item^.Pid = PROTO_ID_MONEY then
    begin
      qty := inventoryItem^.Quantity;
      if item_remove_mult(critter, item, qty) <> 0 then
      begin
        Result := -1;
        Exit;
      end;

      if obj_connect(item, tile, critter^.Elevation, nil) <> 0 then
      begin
        if item_add_force(critter, item, 1) <> 0 then
          obj_destroy(item);
        Result := -1;
        Exit;
      end;

      item^.Data.AsData.Flags := qty;
    end
    else
    begin
      if (item^.Flags and OBJECT_EQUIPPED) <> 0 then
      begin
        hasEquippedItems := True;

        if (item^.Flags and OBJECT_WORN) <> 0 then
        begin
          if proto_ptr(critter^.Pid, @proto) = -1 then
          begin
            Result := -1;
            Exit;
          end;

          frmId := proto^.Fid and $FFF;
          adjust_ac(critter, item, nil);
        end;
      end;

      qty := inventoryItem^.Quantity;
      innerIdx := 0;
      while innerIdx < qty do
      begin
        if item_remove_mult(critter, item, 1) <> 0 then
        begin
          Result := -1;
          Exit;
        end;

        if obj_connect(item, tile, critter^.Elevation, nil) <> 0 then
        begin
          if item_add_force(critter, item, 1) <> 0 then
            obj_destroy(item);
          Result := -1;
          Exit;
        end;
        Inc(innerIdx);
      end;
    end;
    Inc(index);
  end;

  if hasEquippedItems then
  begin
    fid := art_id(OBJ_TYPE_CRITTER, frmId, FID_ANIM_TYPE(critter^.Fid), 0, (critter^.Fid and $70000000) shr 28);
    obj_change_fid(critter, fid, @updatedRect);
    if FID_ANIM_TYPE(critter^.Fid) = ANIM_STAND then
    begin
      tile_refresh_rect(@updatedRect, map_elevation);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// item_identical (static)
// =======================================================================
function item_identical(a1: PObject; a2: PObject): Boolean;
var
  proto: PProto;
  inventory1: PInventory;
  inventory2: PInventory;
  v1: Integer;
  i: Integer;
  p1: PInteger;
  p2: PInteger;
begin
  if a1^.Pid <> a2^.Pid then
  begin
    Result := False;
    Exit;
  end;

  if a1^.Sid <> a2^.Sid then
  begin
    Result := False;
    Exit;
  end;

  if (a1^.Flags and (OBJECT_EQUIPPED or OBJECT_USED)) <> 0 then
  begin
    Result := False;
    Exit;
  end;

  if (a2^.Flags and (OBJECT_EQUIPPED or OBJECT_USED)) <> 0 then
  begin
    Result := False;
    Exit;
  end;

  proto_ptr(a1^.Pid, @proto);
  if proto^.Item.ItemType = ITEM_TYPE_CONTAINER then
  begin
    Result := False;
    Exit;
  end;

  inventory1 := @(a1^.Data.AsData.Inventory);
  inventory2 := @(a2^.Data.AsData.Inventory);
  if (inventory1^.Length <> 0) or (inventory2^.Length <> 0) then
  begin
    Result := False;
    Exit;
  end;

  v1 := 0;
  if (proto^.Item.ItemType = ITEM_TYPE_AMMO) or (a1^.Pid = PROTO_ID_MONEY) then
  begin
    v1 := a2^.Data.AsArray[3];
    a2^.Data.AsArray[3] := a1^.Data.AsArray[3];
  end;

  // NOTE: Probably inlined memcmp, but only checks 32 bytes (8 ints).
  i := 0;
  p1 := @(a1^.Data.AsArray[0]);
  p2 := @(a2^.Data.AsArray[0]);
  while i < 8 do
  begin
    if PInteger(PByte(p1) + SizeUInt(i) * SizeOf(Integer))^ <> PInteger(PByte(p2) + SizeUInt(i) * SizeOf(Integer))^ then
      Break;
    Inc(i);
  end;

  if (proto^.Item.ItemType = ITEM_TYPE_AMMO) or (a1^.Pid = PROTO_ID_MONEY) then
  begin
    a2^.Data.AsArray[3] := v1;
  end;

  Result := (i = 8);
end;

// =======================================================================
// item_name
// =======================================================================
function item_name(obj: PObject): PAnsiChar;
begin
  _item_name_ptr := proto_name(obj^.Pid);
  Result := _item_name_ptr;
end;

// =======================================================================
// item_description
// =======================================================================
function item_description(obj: PObject): PAnsiChar;
begin
  Result := proto_description(obj^.Pid);
end;

// =======================================================================
// item_get_type
// =======================================================================
function item_get_type(item: PObject): Integer;
var
  proto: PProto;
begin
  proto_ptr(item^.Pid, @proto);
  Result := proto^.Item.ItemType;
end;

// =======================================================================
// item_material
// =======================================================================
function item_material(item: PObject): Integer;
var
  proto: PProto;
begin
  proto_ptr(item^.Pid, @proto);
  Result := proto^.Item.Material;
end;

// =======================================================================
// item_size
// =======================================================================
function item_size(obj: PObject): Integer;
var
  proto: PProto;
begin
  proto_ptr(obj^.Pid, @proto);
  Result := proto^.Item.Size;
end;

// =======================================================================
// item_weight
// =======================================================================
function item_weight(item: PObject): Integer;
var
  item_proto: PProto;
  ammo_proto: PProto;
  atype: Integer;
  weight: Integer;
  curr_ammo: Integer;
  ammo_pid: Integer;
begin
  proto_ptr(item^.Pid, @item_proto);
  atype := item_proto^.Item.ItemType;
  weight := item_proto^.Item.Weight;

  case atype of
    ITEM_TYPE_CONTAINER:
      weight := weight + item_total_weight(item);
    ITEM_TYPE_WEAPON:
    begin
      curr_ammo := item_w_curr_ammo(item);
      if curr_ammo > 0 then
      begin
        ammo_pid := item_w_ammo_pid(item);
        if ammo_pid <> -1 then
        begin
          if proto_ptr(ammo_pid, @ammo_proto) <> -1 then
          begin
            weight := weight + ammo_proto^.Item.Weight * ((curr_ammo - 1) div ammo_proto^.Item.Data.Ammo.Quantity + 1);
          end;
        end;
      end;
    end;
  end;

  Result := weight;
end;

// =======================================================================
// item_cost
// =======================================================================
function item_cost(obj: PObject): Integer;
var
  proto: PProto;
  cost: Integer;
  ammoQuantity: Integer;
  ammoTypePid: Integer;
  ammoProto: PProto;
  ammoCapacity: Integer;
begin
  if obj = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(obj^.Pid, @proto);

  cost := proto^.Item.Cost;

  case proto^.Item.ItemType of
    ITEM_TYPE_CONTAINER:
      cost := cost + item_total_cost(obj);
    ITEM_TYPE_WEAPON:
    begin
      // NOTE: Uninline.
      ammoQuantity := item_w_curr_ammo(obj);
      if ammoQuantity > 0 then
      begin
        // NOTE: Uninline.
        ammoTypePid := item_w_ammo_pid(obj);
        if ammoTypePid <> -1 then
        begin
          proto_ptr(ammoTypePid, @ammoProto);
          cost := cost + ammoQuantity * ammoProto^.Item.Cost div ammoProto^.Item.Data.Ammo.Quantity;
        end;
      end;
    end;
    ITEM_TYPE_AMMO:
    begin
      // NOTE: Uninline.
      ammoQuantity := item_w_curr_ammo(obj);
      cost := cost * ammoQuantity;
      // NOTE: Uninline.
      ammoCapacity := item_w_max_ammo(obj);
      cost := cost div ammoCapacity;
    end;
  end;

  Result := cost;
end;

// =======================================================================
// item_total_cost
// =======================================================================
function item_total_cost(obj: PObject): Integer;
var
  cost: Integer;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  proto: PProto;
  item2: PObject;
  item1: PObject;
  armor: PObject;
begin
  if obj = nil then
  begin
    Result := 0;
    Exit;
  end;

  cost := 0;

  inventory := @(obj^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    if item_get_type(inventoryItem^.Item) = ITEM_TYPE_AMMO then
    begin
      proto_ptr(inventoryItem^.Item^.Pid, @proto);
      cost := cost + proto^.Item.Cost * (inventoryItem^.Quantity - 1);
      cost := cost + item_cost(inventoryItem^.Item);
    end
    else
    begin
      cost := cost + item_cost(inventoryItem^.Item) * inventoryItem^.Quantity;
    end;
    Inc(index);
  end;

  if FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER then
  begin
    item2 := inven_right_hand(obj);
    if (item2 <> nil) and ((item2^.Flags and OBJECT_IN_RIGHT_HAND) = 0) then
      cost := cost + item_cost(item2);

    item1 := inven_left_hand(obj);
    if (item1 <> nil) and ((item1^.Flags and OBJECT_IN_LEFT_HAND) = 0) then
      cost := cost + item_cost(item1);

    armor := inven_worn(obj);
    if (armor <> nil) and ((armor^.Flags and OBJECT_WORN) = 0) then
      cost := cost + item_cost(armor);
  end;

  Result := cost;
end;

// =======================================================================
// item_total_weight
// =======================================================================
function item_total_weight(obj: PObject): Integer;
var
  weight: Integer;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
  item2: PObject;
  item1: PObject;
  armor: PObject;
begin
  if obj = nil then
  begin
    Result := 0;
    Exit;
  end;

  weight := 0;

  inventory := @(obj^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    item := inventoryItem^.Item;
    weight := weight + item_weight(item) * inventoryItem^.Quantity;
    Inc(index);
  end;

  if FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER then
  begin
    item2 := inven_right_hand(obj);
    if item2 <> nil then
    begin
      if (item2^.Flags and OBJECT_IN_RIGHT_HAND) = 0 then
        weight := weight + item_weight(item2);
    end;

    item1 := inven_left_hand(obj);
    if item1 <> nil then
    begin
      if (item1^.Flags and OBJECT_IN_LEFT_HAND) = 0 then
        weight := weight + item_weight(item1);
    end;

    armor := inven_worn(obj);
    if armor <> nil then
    begin
      if (armor^.Flags and OBJECT_WORN) = 0 then
        weight := weight + item_weight(armor);
    end;
  end;

  Result := weight;
end;

// =======================================================================
// item_grey
// =======================================================================
function item_grey(weapon: PObject): Boolean;
var
  flags: Integer;
  isTwoHanded: Integer;
begin
  if weapon = nil then
  begin
    Result := False;
    Exit;
  end;

  if item_get_type(weapon) <> ITEM_TYPE_WEAPON then
  begin
    Result := False;
    Exit;
  end;

  flags := obj_dude^.Data.AsData.Critter.Combat.Results;
  if ((flags and DAM_CRIP_ARM_LEFT) <> 0) and ((flags and DAM_CRIP_ARM_RIGHT) <> 0) then
  begin
    Result := True;
    Exit;
  end;

  // NOTE: Uninline.
  isTwoHanded := item_w_is_2handed(weapon);
  if isTwoHanded <> 0 then
  begin
    if ((flags and DAM_CRIP_ARM_LEFT) <> 0) or ((flags and DAM_CRIP_ARM_RIGHT) <> 0) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

// =======================================================================
// item_inv_fid
// =======================================================================
function item_inv_fid(item: PObject): Integer;
var
  proto: PProto;
begin
  proto_ptr(item^.Pid, @proto);
  Result := proto^.Item.InventoryFid;
end;

// =======================================================================
// item_hit_with
// =======================================================================
function item_hit_with(critter: PObject; hit_mode: Integer): PObject;
begin
  case hit_mode of
    HIT_MODE_LEFT_WEAPON_PRIMARY,
    HIT_MODE_LEFT_WEAPON_SECONDARY,
    HIT_MODE_LEFT_WEAPON_RELOAD:
      begin
        Result := inven_left_hand(critter);
        Exit;
      end;
    HIT_MODE_RIGHT_WEAPON_PRIMARY,
    HIT_MODE_RIGHT_WEAPON_SECONDARY,
    HIT_MODE_RIGHT_WEAPON_RELOAD:
      begin
        Result := inven_right_hand(critter);
        Exit;
      end;
  end;

  Result := nil;
end;

// =======================================================================
// item_mp_cost
// =======================================================================
function item_mp_cost(critter: PObject; hit_mode: Integer; aiming: Boolean): Integer;
var
  item: PObject;
begin
  item := item_hit_with(critter, hit_mode);
  if (item <> nil) and (item_get_type(item) <> ITEM_TYPE_WEAPON) then
  begin
    Result := 2;
    Exit;
  end;

  Result := item_w_mp_cost(critter, hit_mode, aiming);
end;

// =======================================================================
// item_count
// =======================================================================
function item_count(obj: PObject; a2: PObject): Integer;
var
  quantity: Integer;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
begin
  quantity := 0;

  inventory := @(obj^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    item := inventoryItem^.Item;
    if item = a2 then
    begin
      quantity := inventoryItem^.Quantity;
      Break;
    end
    else
    begin
      if item_get_type(item) = ITEM_TYPE_CONTAINER then
      begin
        quantity := item_count(item, a2);
        if quantity > 0 then
          Break;
      end;
    end;
    Inc(index);
  end;

  Result := quantity;
end;

// =======================================================================
// item_queued
// =======================================================================
function item_queued(obj: PObject): Integer;
var
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
begin
  if obj = nil then
  begin
    Result := 0;
    Exit;
  end;

  if (obj^.Flags and OBJECT_USED) <> 0 then
  begin
    Result := 1;
    Exit;
  end;

  inventory := @(obj^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    if (inventoryItem^.Item^.Flags and OBJECT_USED) <> 0 then
    begin
      Result := 1;
      Exit;
    end;

    if item_get_type(inventoryItem^.Item) = ITEM_TYPE_CONTAINER then
    begin
      if item_queued(inventoryItem^.Item) <> 0 then
      begin
        Result := 1;
        Exit;
      end;
    end;
    Inc(index);
  end;

  Result := 0;
end;

// =======================================================================
// item_replace
// =======================================================================
function item_replace(a1: PObject; a2: PObject; a3: Integer): PObject;
var
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
  obj: PObject;
begin
  if a1 = nil then
  begin
    Result := nil;
    Exit;
  end;

  if a2 = nil then
  begin
    Result := nil;
    Exit;
  end;

  inventory := @(a1^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    if item_identical(inventoryItem^.Item, a2) then
    begin
      item := inventoryItem^.Item;
      if item_remove_mult(a1, item, 1) = 0 then
      begin
        item^.Flags := item^.Flags or LongWord(a3);
        if item_add_force(a1, item, 1) = 0 then
        begin
          Result := item;
          Exit;
        end;

        item^.Flags := item^.Flags and (not LongWord(a3));
        if item_add_force(a1, item, 1) <> 0 then
          obj_destroy(item);
      end;
    end;

    if item_get_type(inventoryItem^.Item) = ITEM_TYPE_CONTAINER then
    begin
      obj := item_replace(inventoryItem^.Item, a2, a3);
      if obj <> nil then
      begin
        Result := obj;
        Exit;
      end;
    end;
    Inc(index);
  end;

  Result := nil;
end;

// =======================================================================
// item_w_subtype
// =======================================================================
function item_w_subtype(weapon: PObject; hitMode: Integer): Integer;
var
  proto: PProto;
  index: Integer;
begin
  if weapon = nil then
  begin
    Result := ATTACK_TYPE_UNARMED;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if (hitMode = HIT_MODE_LEFT_WEAPON_PRIMARY) or (hitMode = HIT_MODE_RIGHT_WEAPON_PRIMARY) then
    index := proto^.Item.ExtendedFlags and $F
  else
    index := (proto^.Item.ExtendedFlags and $F0) shr 4;

  Result := attack_subtype[index];
end;

// =======================================================================
// item_w_skill
// =======================================================================
function item_w_skill(weapon: PObject; hitMode: Integer): Integer;
var
  proto: PProto;
  index: Integer;
  skill: Integer;
  damageType: Integer;
begin
  if weapon = nil then
  begin
    Result := SKILL_UNARMED;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if (hitMode = HIT_MODE_LEFT_WEAPON_PRIMARY) or (hitMode = HIT_MODE_RIGHT_WEAPON_PRIMARY) then
    index := proto^.Item.ExtendedFlags and $F
  else
    index := (proto^.Item.ExtendedFlags and $F0) shr 4;

  skill := attack_skill[index];

  if skill = SKILL_SMALL_GUNS then
  begin
    damageType := item_w_damage_type(weapon);
    if (damageType = DAMAGE_TYPE_LASER) or (damageType = DAMAGE_TYPE_PLASMA) or (damageType = DAMAGE_TYPE_ELECTRICAL) then
      skill := SKILL_ENERGY_WEAPONS
    else
    begin
      if (proto^.Item.ExtendedFlags and ItemProtoExtendedFlags_BigGun) <> 0 then
        skill := SKILL_BIG_GUNS;
    end;
  end;

  Result := skill;
end;

// =======================================================================
// item_w_skill_level
// =======================================================================
function item_w_skill_level(critter: PObject; hit_mode: Integer): Integer;
var
  weapon: PObject;
  skill: Integer;
begin
  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);
  if weapon <> nil then
    skill := item_w_skill(weapon, hit_mode)
  else
    skill := SKILL_UNARMED;

  Result := skill_level(critter, skill);
end;

// =======================================================================
// item_w_damage_min_max
// =======================================================================
function item_w_damage_min_max(weapon: PObject; min_damage: PInteger; max_damage: PInteger): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if min_damage <> nil then
    min_damage^ := proto^.Item.Data.Weapon.MinDamage;

  if max_damage <> nil then
    max_damage^ := proto^.Item.Data.Weapon.MaxDamage;

  Result := 0;
end;

// =======================================================================
// item_w_damage
// =======================================================================
function item_w_damage(critter: PObject; hit_mode: Integer): Integer;
var
  min_damage: Integer;
  max_damage: Integer;
  bonus_damage: Integer;
  subtype: Integer;
  weapon: PObject;
begin
  min_damage := 0;
  max_damage := 0;
  bonus_damage := 0;

  if critter = nil then
  begin
    Result := 0;
    Exit;
  end;

  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);

  if weapon <> nil then
  begin
    // NOTE: Uninline.
    item_w_damage_min_max(weapon, @min_damage, @max_damage);

    subtype := item_w_subtype(weapon, hit_mode);
    if (subtype = ATTACK_TYPE_MELEE) or (subtype = ATTACK_TYPE_UNARMED) then
      bonus_damage := stat_level(critter, Ord(STAT_MELEE_DAMAGE));
  end
  else
  begin
    min_damage := 1;
    max_damage := stat_level(critter, Ord(STAT_MELEE_DAMAGE)) + 2;
  end;

  Result := roll_random(min_damage, bonus_damage + max_damage);
end;

// =======================================================================
// item_w_damage_type
// =======================================================================
function item_w_damage_type(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon <> nil then
  begin
    proto_ptr(weapon^.Pid, @proto);
    Result := proto^.Item.Data.Weapon.DamageType;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// item_w_is_2handed
// =======================================================================
function item_w_is_2handed(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if (proto^.Item.ExtendedFlags and WEAPON_TWO_HAND) <> 0 then
    Result := 1
  else
    Result := 0;
end;

// =======================================================================
// item_w_anim
// =======================================================================
function item_w_anim(critter: PObject; hit_mode: Integer): Integer;
var
  weapon: PObject;
begin
  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);
  Result := item_w_anim_weap(weapon, hit_mode);
end;

// =======================================================================
// item_w_anim_weap
// =======================================================================
function item_w_anim_weap(weapon: PObject; hit_mode: Integer): Integer;
var
  proto: PProto;
  index: Integer;
begin
  if hit_mode = HIT_MODE_KICK then
  begin
    Result := ANIM_KICK_LEG;
    Exit;
  end;

  if weapon = nil then
  begin
    Result := ANIM_THROW_PUNCH;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if (hit_mode = HIT_MODE_LEFT_WEAPON_PRIMARY) or (hit_mode = HIT_MODE_RIGHT_WEAPON_PRIMARY) then
    index := proto^.Item.ExtendedFlags and $F
  else
    index := (proto^.Item.ExtendedFlags and $F0) shr 4;

  Result := attack_anim[index];
end;

// =======================================================================
// item_w_max_ammo
// =======================================================================
function item_w_max_ammo(ammoOrWeapon: PObject): Integer;
var
  proto: PProto;
begin
  if ammoOrWeapon = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(ammoOrWeapon^.Pid, @proto);

  if proto^.Item.ItemType = ITEM_TYPE_AMMO then
    Result := proto^.Item.Data.Ammo.Quantity
  else
    Result := proto^.Item.Data.Weapon.AmmoCapacity;
end;

// =======================================================================
// item_w_curr_ammo
// =======================================================================
function item_w_curr_ammo(ammoOrWeapon: PObject): Integer;
var
  proto: PProto;
begin
  if ammoOrWeapon = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(ammoOrWeapon^.Pid, @proto);

  if proto^.Item.ItemType = ITEM_TYPE_AMMO then
    Result := ammoOrWeapon^.Data.AsData.ItemSceneryMisc.Item.Ammo.Quantity
  else
    Result := ammoOrWeapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoQuantity;
end;

// =======================================================================
// item_w_caliber
// =======================================================================
function item_w_caliber(ammoOrWeapon: PObject): Integer;
var
  proto: PProto;
begin
  if ammoOrWeapon = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(ammoOrWeapon^.Pid, @proto);

  if proto^.Item.ItemType <> ITEM_TYPE_AMMO then
  begin
    if proto_ptr(ammoOrWeapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoTypePid, @proto) = -1 then
    begin
      Result := 0;
      Exit;
    end;
  end;

  Result := proto^.Item.Data.Ammo.Caliber;
end;

// =======================================================================
// item_w_set_curr_ammo
// =======================================================================
procedure item_w_set_curr_ammo(ammoOrWeapon: PObject; quantity: Integer);
var
  capacity: Integer;
  proto: PProto;
begin
  if ammoOrWeapon = nil then
    Exit;

  // NOTE: Uninline.
  capacity := item_w_max_ammo(ammoOrWeapon);
  if quantity > capacity then
    quantity := capacity;

  proto_ptr(ammoOrWeapon^.Pid, @proto);

  if proto^.Item.ItemType = ITEM_TYPE_AMMO then
    ammoOrWeapon^.Data.AsData.ItemSceneryMisc.Item.Ammo.Quantity := quantity
  else
    ammoOrWeapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoQuantity := quantity;
end;

// =======================================================================
// item_w_try_reload
// =======================================================================
function item_w_try_reload(critter: PObject; weapon: PObject): Integer;
var
  quantity: Integer;
  capacity: Integer;
  inventoryItemIndex: Integer;
  ammo: PObject;
  rc: Integer;
begin
  // NOTE: Uninline.
  quantity := item_w_curr_ammo(weapon);
  capacity := item_w_max_ammo(weapon);
  if quantity = capacity then
  begin
    Result := -1;
    Exit;
  end;

  inventoryItemIndex := -1;
  while True do
  begin
    ammo := inven_find_type(critter, ITEM_TYPE_AMMO, @inventoryItemIndex);
    if ammo = nil then
      Break;

    if item_w_can_reload(weapon, ammo) then
    begin
      rc := item_w_reload(weapon, ammo);
      if rc = 0 then
        obj_destroy(ammo);

      if rc = -1 then
      begin
        Result := -1;
        Exit;
      end;

      Result := 0;
      Exit;
    end;
  end;

  Result := -1;
end;

// =======================================================================
// item_w_can_reload
// =======================================================================
function item_w_can_reload(weapon: PObject; ammo: PObject): Boolean;
var
  weaponProto: PProto;
  ammoProto: PProto;
begin
  if ammo = nil then
  begin
    Result := False;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @weaponProto);
  proto_ptr(ammo^.Pid, @ammoProto);

  if weaponProto^.Item.ItemType <> ITEM_TYPE_WEAPON then
  begin
    Result := False;
    Exit;
  end;

  if ammoProto^.Item.ItemType <> ITEM_TYPE_AMMO then
  begin
    Result := False;
    Exit;
  end;

  // Check ammo matches weapon caliber.
  if weaponProto^.Item.Data.Weapon.Caliber <> ammoProto^.Item.Data.Ammo.Caliber then
  begin
    Result := False;
    Exit;
  end;

  // If weapon is not empty, we should only reload it with the same ammo.
  if item_w_curr_ammo(weapon) <> 0 then
  begin
    if weapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoTypePid <> ammo^.Pid then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

// =======================================================================
// item_w_reload
// =======================================================================
function item_w_reload(weapon: PObject; ammo: PObject): Integer;
var
  ammoQuantity: Integer;
  ammoCapacity: Integer;
  v10: Integer;
  v11: Integer;
  v12: Integer;
begin
  if not item_w_can_reload(weapon, ammo) then
  begin
    Result := -1;
    Exit;
  end;

  // NOTE: Uninline.
  ammoQuantity := item_w_curr_ammo(weapon);
  // NOTE: Uninline.
  ammoCapacity := item_w_max_ammo(weapon);
  // NOTE: Uninline.
  v10 := item_w_curr_ammo(ammo);

  v11 := v10;
  if ammoQuantity < ammoCapacity then
  begin
    if ammoQuantity + v10 > ammoCapacity then
    begin
      v11 := v10 - (ammoCapacity - ammoQuantity);
      v12 := ammoCapacity;
    end
    else
    begin
      v11 := 0;
      v12 := ammoQuantity + v10;
    end;

    weapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoTypePid := ammo^.Pid;

    item_w_set_curr_ammo(ammo, v11);
    item_w_set_curr_ammo(weapon, v12);
  end;

  Result := v11;
end;

// =======================================================================
// item_w_range
// =======================================================================
function item_w_range(critter: PObject; hit_mode: Integer): Integer;
var
  weapon: PObject;
  proto: PProto;
  range: Integer;
  max_range: Integer;
begin
  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);

  if (weapon = nil) or (hit_mode = HIT_MODE_PUNCH) or (hit_mode = HIT_MODE_KICK) then
  begin
    Result := 1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);

  if (hit_mode = HIT_MODE_LEFT_WEAPON_PRIMARY) or (hit_mode = HIT_MODE_RIGHT_WEAPON_PRIMARY) then
    range := proto^.Item.Data.Weapon.MaxRange1
  else
    range := proto^.Item.Data.Weapon.MaxRange2;

  if item_w_subtype(weapon, hit_mode) = ATTACK_TYPE_THROW then
  begin
    if critter = obj_dude then
      max_range := 3 * (stat_level(critter, Ord(STAT_STRENGTH)) + 2 * perk_level(PERK_HEAVE_HO))
    else
      max_range := 3 * stat_level(critter, Ord(STAT_STRENGTH));

    if range > max_range then
      range := max_range;
  end;

  Result := range;
end;

// =======================================================================
// item_w_mp_cost
// =======================================================================
function item_w_mp_cost(critter: PObject; hit_mode: Integer; aiming: Boolean): Integer;
var
  weapon: PObject;
  action_points: Integer;
  weapon_subtype: Integer;
begin
  if (hit_mode = HIT_MODE_LEFT_WEAPON_RELOAD) or (hit_mode = HIT_MODE_RIGHT_WEAPON_RELOAD) then
  begin
    Result := 2;
    Exit;
  end;

  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);
  if (weapon = nil) or (hit_mode = HIT_MODE_PUNCH) or (hit_mode = HIT_MODE_KICK) then
  begin
    action_points := 3;
  end
  else
  begin
    if (hit_mode = HIT_MODE_LEFT_WEAPON_PRIMARY) or (hit_mode = HIT_MODE_RIGHT_WEAPON_PRIMARY) then
      action_points := item_w_primary_mp_cost(weapon)
    else
      action_points := item_w_secondary_mp_cost(weapon);

    if critter = obj_dude then
    begin
      if trait_level(TRAIT_FAST_SHOT) <> 0 then
        action_points := action_points - 1;
    end;
  end;

  if critter = obj_dude then
  begin
    weapon_subtype := item_w_subtype(weapon, hit_mode);

    if perk_level(PERK_BONUS_HTH_ATTACKS) <> 0 then
    begin
      if (weapon_subtype = ATTACK_TYPE_MELEE) or (weapon_subtype = ATTACK_TYPE_UNARMED) then
        action_points := action_points - 1;
    end;

    if perk_level(PERK_BONUS_RATE_OF_FIRE) <> 0 then
    begin
      if weapon_subtype = ATTACK_TYPE_RANGED then
        action_points := action_points - 1;
    end;
  end;

  if aiming then
    action_points := action_points + 1;

  if action_points < 1 then
    action_points := 1;

  Result := action_points;
end;

// =======================================================================
// item_w_min_st
// =======================================================================
function item_w_min_st(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.MinStrength;
end;

// =======================================================================
// item_w_crit_fail
// =======================================================================
function item_w_crit_fail(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.CriticalFailureType;
end;

// =======================================================================
// item_w_perk
// =======================================================================
function item_w_perk(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.Perk;
end;

// =======================================================================
// item_w_rounds
// =======================================================================
function item_w_rounds(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.Rounds;
end;

// =======================================================================
// item_w_anim_code
// =======================================================================
function item_w_anim_code(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.AnimationCode;
end;

// =======================================================================
// item_w_proj_pid
// =======================================================================
function item_w_proj_pid(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.ProjectilePid;
end;

// =======================================================================
// item_w_ammo_pid
// =======================================================================
function item_w_ammo_pid(weapon: PObject): Integer;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  if item_get_type(weapon) <> ITEM_TYPE_WEAPON then
  begin
    Result := -1;
    Exit;
  end;

  Result := weapon^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoTypePid;
end;

// =======================================================================
// item_w_sound_id
// =======================================================================
function item_w_sound_id(weapon: PObject): AnsiChar;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := #0;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := AnsiChar(proto^.Item.Data.Weapon.SoundCode and $FF);
end;

// =======================================================================
// item_w_called_shot
// =======================================================================
function item_w_called_shot(critter: PObject; hit_mode: Integer): Integer;
var
  anim: Integer;
  weapon: PObject;
  damage_type: Integer;
begin
  if critter = obj_dude then
  begin
    if trait_level(TRAIT_FAST_SHOT) <> 0 then
    begin
      Result := 0;
      Exit;
    end;
  end;

  // NOTE: Uninline.
  anim := item_w_anim(critter, hit_mode);
  if (anim = ANIM_FIRE_BURST) or (anim = ANIM_FIRE_CONTINUOUS) then
  begin
    Result := 0;
    Exit;
  end;

  // NOTE: Uninline.
  weapon := item_hit_with(critter, hit_mode);
  damage_type := item_w_damage_type(weapon);

  if (damage_type = DAMAGE_TYPE_EXPLOSION)
      or (damage_type = DAMAGE_TYPE_FIRE)
      or (damage_type = DAMAGE_TYPE_EMP)
      or ((anim = ANIM_THROW_ANIM) and (damage_type = DAMAGE_TYPE_PLASMA)) then
  begin
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

// =======================================================================
// item_w_can_unload
// =======================================================================
function item_w_can_unload(weapon: PObject): Integer;
begin
  if weapon = nil then
  begin
    Result := 0;
    Exit;
  end;

  if item_get_type(weapon) <> ITEM_TYPE_WEAPON then
  begin
    Result := 0;
    Exit;
  end;

  // NOTE: Uninline.
  if item_w_max_ammo(weapon) <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  // NOTE: Uninline.
  if item_w_curr_ammo(weapon) <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  if item_w_ammo_pid(weapon) = -1 then
  begin
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

// =======================================================================
// item_w_unload
// =======================================================================
function item_w_unload(weapon: PObject): PObject;
var
  ammoTypePid: Integer;
  ammo: PObject;
  ammoQuantity: Integer;
  ammoCapacity: Integer;
  remainingQuantity: Integer;
begin
  if item_w_can_unload(weapon) = 0 then
  begin
    Result := nil;
    Exit;
  end;

  // NOTE: Uninline.
  ammoTypePid := item_w_ammo_pid(weapon);
  if ammoTypePid = -1 then
  begin
    Result := nil;
    Exit;
  end;

  if obj_pid_new(@ammo, ammoTypePid) <> 0 then
  begin
    Result := nil;
    Exit;
  end;

  obj_disconnect(ammo, nil);

  // NOTE: Uninline.
  ammoQuantity := item_w_curr_ammo(weapon);
  // NOTE: Uninline.
  ammoCapacity := item_w_max_ammo(ammo);

  if ammoQuantity <= ammoCapacity then
  begin
    item_w_set_curr_ammo(ammo, ammoQuantity);
    remainingQuantity := 0;
  end
  else
  begin
    item_w_set_curr_ammo(ammo, ammoCapacity);
    remainingQuantity := ammoQuantity - ammoCapacity;
  end;
  item_w_set_curr_ammo(weapon, remainingQuantity);

  Result := ammo;
end;

// =======================================================================
// item_w_primary_mp_cost
// =======================================================================
function item_w_primary_mp_cost(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.ActionPointCost1;
end;

// =======================================================================
// item_w_secondary_mp_cost
// =======================================================================
function item_w_secondary_mp_cost(weapon: PObject): Integer;
var
  proto: PProto;
begin
  if weapon = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(weapon^.Pid, @proto);
  Result := proto^.Item.Data.Weapon.ActionPointCost2;
end;

// =======================================================================
// item_ar_ac
// =======================================================================
function item_ar_ac(armor: PObject): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.ArmorClass;
end;

// =======================================================================
// item_ar_dr
// =======================================================================
function item_ar_dr(armor: PObject; damageType: Integer): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.DamageResistance[damageType];
end;

// =======================================================================
// item_ar_dt
// =======================================================================
function item_ar_dt(armor: PObject; damageType: Integer): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.DamageThreshold[damageType];
end;

// =======================================================================
// item_ar_perk
// =======================================================================
function item_ar_perk(armor: PObject): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.Perk;
end;

// =======================================================================
// item_ar_male_fid
// =======================================================================
function item_ar_male_fid(armor: PObject): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.MaleFid;
end;

// =======================================================================
// item_ar_female_fid
// =======================================================================
function item_ar_female_fid(armor: PObject): Integer;
var
  proto: PProto;
begin
  if armor = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(armor^.Pid, @proto);
  Result := proto^.Item.Data.Armor.FemaleFid;
end;

// =======================================================================
// item_m_max_charges
// =======================================================================
function item_m_max_charges(misc_item: PObject): Integer;
var
  proto: PProto;
begin
  if misc_item = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(misc_item^.Pid, @proto);
  Result := proto^.Item.Data.Misc.Charges;
end;

// =======================================================================
// item_m_curr_charges
// =======================================================================
function item_m_curr_charges(misc_item: PObject): Integer;
begin
  if misc_item = nil then
  begin
    Result := 0;
    Exit;
  end;

  Result := misc_item^.Data.AsData.ItemSceneryMisc.Item.Misc.Charges;
end;

// =======================================================================
// item_m_set_charges
// =======================================================================
function item_m_set_charges(miscItem: PObject; charges: Integer): Integer;
var
  maxCharges: Integer;
begin
  // NOTE: Uninline.
  maxCharges := item_m_max_charges(miscItem);

  if charges > maxCharges then
    charges := maxCharges;

  miscItem^.Data.AsData.ItemSceneryMisc.Item.Misc.Charges := charges;

  Result := 0;
end;

// =======================================================================
// item_m_cell
// =======================================================================
function item_m_cell(miscItem: PObject): Integer;
var
  proto: PProto;
begin
  if miscItem = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(miscItem^.Pid, @proto);
  Result := proto^.Item.Data.Misc.PowerType;
end;

// =======================================================================
// item_m_cell_pid
// =======================================================================
function item_m_cell_pid(miscItem: PObject): Integer;
var
  proto: PProto;
begin
  if miscItem = nil then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(miscItem^.Pid, @proto);
  Result := proto^.Item.Data.Misc.PowerTypePid;
end;

// =======================================================================
// item_m_uses_charges
// =======================================================================
function item_m_uses_charges(miscItem: PObject): Boolean;
var
  proto: PProto;
begin
  if miscItem = nil then
  begin
    Result := False;
    Exit;
  end;

  proto_ptr(miscItem^.Pid, @proto);
  Result := proto^.Item.Data.Misc.Charges <> 0;
end;

// =======================================================================
// item_m_use_charged_item
// =======================================================================
function item_m_use_charged_item(critter: PObject; miscItem: PObject): Integer;
var
  pid: Integer;
  isOn: Boolean;
  messageListItem: TMessageListItem;
  text: array[0..79] of AnsiChar;
  itemName: PAnsiChar;
begin
  pid := miscItem^.Pid;
  if (pid = PROTO_ID_STEALTH_BOY_I)
      or (pid = PROTO_ID_GEIGER_COUNTER_I)
      or (pid = PROTO_ID_STEALTH_BOY_II)
      or (pid = PROTO_ID_GEIGER_COUNTER_II) then
  begin
    // NOTE: Uninline.
    isOn := item_m_on(miscItem);

    if isOn then
      item_m_turn_off(miscItem)
    else
      item_m_turn_on(miscItem);
  end
  else if pid = PROTO_ID_MOTION_SENSOR then
  begin
    // NOTE: Uninline.
    if item_m_dec_charges(miscItem) = 0 then
    begin
      automap(True, True);
    end
    else
    begin
      // %s has no charges left.
      messageListItem.num := 5;
      if message_search(@item_message_file, @messageListItem) then
      begin
        itemName := object_name(miscItem);
        StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [itemName]);
        display_print(@text[0]);
      end;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// item_m_dec_charges
// =======================================================================
function item_m_dec_charges(item: PObject): Integer;
var
  charges: Integer;
begin
  // NOTE: Uninline.
  charges := item_m_curr_charges(item);
  if charges <= 0 then
  begin
    Result := -1;
    Exit;
  end;

  // NOTE: Uninline.
  item_m_set_charges(item, charges - 1);

  Result := 0;
end;

// =======================================================================
// item_m_trickle
// =======================================================================
function item_m_trickle(item_obj: PObject; data: Pointer): Integer; cdecl;
var
  delay: Integer;
  critter: PObject;
  messageListItem: TMessageListItem;
  text: array[0..79] of AnsiChar;
  itemName: PAnsiChar;
begin
  // NOTE: Uninline.
  if item_m_dec_charges(item_obj) = 0 then
  begin
    if (item_obj^.Pid = PROTO_ID_STEALTH_BOY_I) or (item_obj^.Pid = PROTO_ID_STEALTH_BOY_II) then
      delay := 600
    else
      delay := 3000;

    queue_add(delay, item_obj, nil, EVENT_TYPE_ITEM_TRICKLE);
  end
  else
  begin
    critter := obj_top_environment(item_obj);
    if critter = obj_dude then
    begin
      // %s has no charges left.
      messageListItem.num := 5;
      if message_search(@item_message_file, @messageListItem) then
      begin
        itemName := object_name(item_obj);
        StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [itemName]);
        display_print(@text[0]);
      end;
    end;
    item_m_turn_off(item_obj);
  end;

  Result := 0;
end;

// =======================================================================
// item_m_on
// =======================================================================
function item_m_on(obj: PObject): Boolean;
begin
  if obj = nil then
  begin
    Result := False;
    Exit;
  end;

  if not item_m_uses_charges(obj) then
  begin
    Result := False;
    Exit;
  end;

  Result := queue_find(obj, EVENT_TYPE_ITEM_TRICKLE);
end;

// =======================================================================
// item_m_turn_on
// =======================================================================
function item_m_turn_on(item_obj: PObject): Integer;
var
  messageListItem: TMessageListItem;
  text: array[0..79] of AnsiChar;
  critter: PObject;
  aname: PAnsiChar;
  radiation: Integer;
begin
  critter := obj_top_environment(item_obj);
  if critter = nil then
  begin
    // This item can only be used from the interface bar.
    messageListItem.num := 9;
    if message_search(@item_message_file, @messageListItem) then
      display_print(messageListItem.text);

    Result := -1;
    Exit;
  end;

  // NOTE: Uninline.
  if item_m_dec_charges(item_obj) <> 0 then
  begin
    if critter = obj_dude then
    begin
      messageListItem.num := 5;
      if message_search(@item_message_file, @messageListItem) then
      begin
        aname := object_name(item_obj);
        StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [aname]);
        display_print(@text[0]);
      end;
    end;

    Result := -1;
    Exit;
  end;

  if (item_obj^.Pid = PROTO_ID_STEALTH_BOY_I) or (item_obj^.Pid = PROTO_ID_STEALTH_BOY_II) then
  begin
    queue_add(600, item_obj, nil, EVENT_TYPE_ITEM_TRICKLE);
    item_obj^.Pid := PROTO_ID_STEALTH_BOY_II;

    if critter <> nil then
    begin
      // NOTE: Uninline.
      item_m_stealth_effect_on(critter);
    end;
  end
  else
  begin
    queue_add(3000, item_obj, nil, EVENT_TYPE_ITEM_TRICKLE);
    item_obj^.Pid := PROTO_ID_GEIGER_COUNTER_II;
  end;

  if critter = obj_dude then
  begin
    // %s is on.
    messageListItem.num := 6;
    if message_search(@item_message_file, @messageListItem) then
    begin
      aname := object_name(item_obj);
      StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [aname]);
      display_print(@text[0]);
    end;

    if item_obj^.Pid = PROTO_ID_GEIGER_COUNTER_II then
    begin
      // You pass the Geiger counter over your body. The rem counter reads: %d
      messageListItem.num := 8;
      if message_search(@item_message_file, @messageListItem) then
      begin
        radiation := critter_get_rads(critter);
        StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [radiation]);
        display_print(@text[0]);
      end;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// item_m_turn_off
// =======================================================================
function item_m_turn_off(item_obj: PObject): Integer;
var
  owner: PObject;
  messageListItem: TMessageListItem;
  aname: PAnsiChar;
  text: array[0..79] of AnsiChar;
begin
  owner := obj_top_environment(item_obj);

  queue_remove_this(item_obj, EVENT_TYPE_ITEM_TRICKLE);

  if (owner <> nil) and (item_obj^.Pid = PROTO_ID_STEALTH_BOY_II) then
    item_m_stealth_effect_off(owner, item_obj);

  if (item_obj^.Pid = PROTO_ID_STEALTH_BOY_I) or (item_obj^.Pid = PROTO_ID_STEALTH_BOY_II) then
    item_obj^.Pid := PROTO_ID_STEALTH_BOY_I
  else
    item_obj^.Pid := PROTO_ID_GEIGER_COUNTER_I;

  if owner = obj_dude then
    intface_update_items(False);

  if owner = obj_dude then
  begin
    // %s is off.
    messageListItem.num := 7;
    if message_search(@item_message_file, @messageListItem) then
    begin
      aname := object_name(item_obj);
      StrLFmt(@text[0], SizeOf(text) - 1, messageListItem.text, [aname]);
      display_print(@text[0]);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// item_m_turn_off_from_queue
// =======================================================================
function item_m_turn_off_from_queue(obj: PObject; data: Pointer): Integer; cdecl;
begin
  item_m_turn_off(obj);
  Result := 1;
end;

// =======================================================================
// item_m_stealth_effect_on (static)
// =======================================================================
function item_m_stealth_effect_on(obj: PObject): Integer;
var
  rect: TRect;
begin
  if (obj^.Flags and OBJECT_TRANS_GLASS) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  obj^.Flags := obj^.Flags or OBJECT_TRANS_GLASS;

  obj_bound(obj, @rect);
  tile_refresh_rect(@rect, obj^.Elevation);

  Result := 0;
end;

// =======================================================================
// item_m_stealth_effect_off (static)
// =======================================================================
function item_m_stealth_effect_off(critter: PObject; item: PObject): Integer;
var
  item1: PObject;
  item2: PObject;
  rect: TRect;
begin
  item1 := inven_left_hand(critter);
  if (item1 <> nil) and (item1 <> item) and (item1^.Pid = PROTO_ID_STEALTH_BOY_II) then
  begin
    Result := -1;
    Exit;
  end;

  item2 := inven_right_hand(critter);
  if (item2 <> nil) and (item2 <> item) and (item2^.Pid = PROTO_ID_STEALTH_BOY_II) then
  begin
    Result := -1;
    Exit;
  end;

  if (critter^.Flags and OBJECT_TRANS_GLASS) = 0 then
  begin
    Result := -1;
    Exit;
  end;

  critter^.Flags := critter^.Flags and (not LongWord(OBJECT_TRANS_GLASS));

  obj_bound(critter, @rect);
  tile_refresh_rect(@rect, critter^.Elevation);

  Result := 0;
end;

// =======================================================================
// item_c_max_size
// =======================================================================
function item_c_max_size(container: PObject): Integer;
var
  proto: PProto;
begin
  if container = nil then
  begin
    Result := 0;
    Exit;
  end;

  proto_ptr(container^.Pid, @proto);
  Result := proto^.Item.Data.Container.MaxSize;
end;

// =======================================================================
// item_c_curr_size
// =======================================================================
function item_c_curr_size(container: PObject): Integer;
var
  totalSize: Integer;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  sz: Integer;
begin
  if container = nil then
  begin
    Result := 0;
    Exit;
  end;

  totalSize := 0;

  inventory := @(container^.Data.AsData.Inventory);
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
    sz := item_size(inventoryItem^.Item);
    totalSize := totalSize + inventoryItem^.Quantity * sz;
    Inc(index);
  end;

  Result := totalSize;
end;

// =======================================================================
// insert_drug_effect (static)
// =======================================================================
function insert_drug_effect(critter: PObject; item: PObject; a3: Integer; stats: PInteger; mods: PInteger): Integer;
var
  index: Integer;
  drugEffectEvent: PDrugEffectEvent;
  delay: Integer;
begin
  index := 0;
  while index < 3 do
  begin
    if PInteger(PByte(mods) + SizeUInt(index) * SizeOf(Integer))^ <> 0 then
      Break;
    Inc(index);
  end;

  if index = 3 then
  begin
    Result := -1;
    Exit;
  end;

  drugEffectEvent := PDrugEffectEvent(mem_malloc(SizeOf(TDrugEffectEvent)));
  if drugEffectEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  drugEffectEvent^.drugPid := item^.Pid;

  for index := 0 to 2 do
  begin
    drugEffectEvent^.stats[index] := PInteger(PByte(stats) + SizeUInt(index) * SizeOf(Integer))^;
    drugEffectEvent^.modifiers[index] := PInteger(PByte(mods) + SizeUInt(index) * SizeOf(Integer))^;
  end;

  delay := 600 * a3;
  if critter = obj_dude then
  begin
    if trait_level(TRAIT_CHEM_RESISTANT) <> 0 then
      delay := delay div 2;
  end;

  if queue_add(delay, critter, drugEffectEvent, EVENT_TYPE_DRUG) = -1 then
  begin
    mem_free(drugEffectEvent);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// perform_drug_effect (static)
// =======================================================================
procedure perform_drug_effect(critter: PObject; stats: PInteger; mods: PInteger; is_immediate: Boolean);
var
  v10: Integer;
  v11: Integer;
  v12: Integer;
  messageListItem: TMessageListItem;
  aname: PAnsiChar;
  text: PAnsiChar;
  v24: array[0..91] of AnsiChar;
  str: array[0..91] of AnsiChar;
  statsChanged: Boolean;
  v5: Integer;
  v32: Boolean;
  index: Integer;
  stat: Integer;
  before: Integer;
  after: Integer;
  statName: PAnsiChar;
begin
  statsChanged := False;

  v5 := 0;
  v32 := False;
  if PInteger(stats)^ = -2 then
  begin
    v5 := 1;
    v32 := True;
  end;

  index := v5;
  while index < 3 do
  begin
    stat := PInteger(PByte(stats) + SizeUInt(index) * SizeOf(Integer))^;
    if stat = -1 then
    begin
      Inc(index);
      Continue;
    end;

    if stat = Ord(STAT_CURRENT_HIT_POINTS) then
    begin
      critter^.Data.AsData.Critter.Combat.Maneuver := critter^.Data.AsData.Critter.Combat.Maneuver and (not CRITTER_MANUEVER_FLEEING);
    end;

    v10 := stat_get_bonus(critter, stat);

    before := 0;
    if critter = obj_dude then
      before := stat_level(obj_dude, stat);

    if v32 then
    begin
      v11 := roll_random(PInteger(PByte(mods) + SizeUInt(index - 1) * SizeOf(Integer))^,
                          PInteger(PByte(mods) + SizeUInt(index) * SizeOf(Integer))^) + v10;
      v32 := False;
    end
    else
    begin
      v11 := PInteger(PByte(mods) + SizeUInt(index) * SizeOf(Integer))^ + v10;
    end;

    if stat = Ord(STAT_CURRENT_HIT_POINTS) then
    begin
      v12 := stat_get_base(critter, Ord(STAT_CURRENT_HIT_POINTS));
      if (v11 + v12 <= 0) and (critter <> obj_dude) then
      begin
        aname := critter_name(critter);
        // %s succumbs to the adverse effects of chems.
        text := getmsg(@item_message_file, @messageListItem, 600);
        StrLFmt(@v24[0], SizeOf(v24) - 1, text, [aname]);
      end;
    end;

    stat_set_bonus(critter, stat, v11);

    if critter = obj_dude then
    begin
      if stat = Ord(STAT_CURRENT_HIT_POINTS) then
        intface_update_hit_points(True);

      after := stat_level(critter, stat);
      if after <> before then
      begin
        // 1 - You gained %d %s.
        // 2 - You lost %d %s.
        if after < before then
          messageListItem.num := 2
        else
          messageListItem.num := 1;
        if message_search(@item_message_file, @messageListItem) then
        begin
          statName := stat_name(stat);
          if after < before then
            StrLFmt(@str[0], SizeOf(str) - 1, messageListItem.text, [before - after, statName])
          else
            StrLFmt(@str[0], SizeOf(str) - 1, messageListItem.text, [after - before, statName]);
          display_print(@str[0]);
          statsChanged := True;
        end;
      end;
    end;
    Inc(index);
  end;

  if stat_level(critter, Ord(STAT_CURRENT_HIT_POINTS)) > 0 then
  begin
    if (critter = obj_dude) and (not statsChanged) and is_immediate then
    begin
      // Nothing happens.
      messageListItem.num := 10;
      if message_search(@item_message_file, @messageListItem) then
        display_print(messageListItem.text);
    end;
  end
  else
  begin
    if critter = obj_dude then
    begin
      // You suffer a fatal heart attack from chem overdose.
      messageListItem.num := 4;
      if message_search(@item_message_file, @messageListItem) then
        StrCopy(@v24[0], messageListItem.text);
    end
    else
    begin
      aname := critter_name(critter);
      // %s succumbs to the adverse effects of chems.
      text := getmsg(@item_message_file, @messageListItem, 600);
      StrLFmt(@v24[0], SizeOf(v24) - 1, text, [aname]);
    end;
  end;
end;

// =======================================================================
// item_d_take_drug
// =======================================================================
function item_d_take_drug(critter_obj: PObject; item_obj: PObject): Integer;
var
  proto: PProto;
  addiction_chance: Integer;
begin
  if critter_is_dead(critter_obj) then
  begin
    Result := -1;
    Exit;
  end;

  if critter_body_type(critter_obj) = BODY_TYPE_ROBOTIC then
  begin
    Result := -1;
    Exit;
  end;

  proto_ptr(item_obj^.Pid, @proto);

  wd_obj := critter_obj;
  wd_gvar := pid_to_gvar(item_obj^.Pid);
  wd_onset := proto^.Item.Data.Drug.WithdrawalOnset;

  queue_clear_type(EVENT_TYPE_WITHDRAWAL, @item_wd_clear_all);
  perform_drug_effect(critter_obj, @proto^.Item.Data.Drug.Stat[0], @proto^.Item.Data.Drug.Amount[0], True);
  insert_drug_effect(critter_obj, item_obj, proto^.Item.Data.Drug.Duration1, @proto^.Item.Data.Drug.Stat[0], @proto^.Item.Data.Drug.Amount1[0]);
  insert_drug_effect(critter_obj, item_obj, proto^.Item.Data.Drug.Duration2, @proto^.Item.Data.Drug.Stat[0], @proto^.Item.Data.Drug.Amount2[0]);

  if not item_d_check_addict(item_obj^.Pid) then
  begin
    addiction_chance := proto^.Item.Data.Drug.AddictionChance;
    if critter_obj = obj_dude then
    begin
      if trait_level(TRAIT_CHEM_RELIANT) <> 0 then
        addiction_chance := addiction_chance * 2;

      if trait_level(TRAIT_CHEM_RESISTANT) <> 0 then
        addiction_chance := addiction_chance div 2;

      if perk_level(PERK_FLOWER_CHILD) <> 0 then
        addiction_chance := addiction_chance div 2;
    end;

    if roll_random(1, 100) <= addiction_chance then
    begin
      insert_withdrawal(critter_obj, 1, proto^.Item.Data.Drug.WithdrawalOnset, proto^.Item.Data.Drug.WithdrawalEffect, item_obj^.Pid);

      if critter_obj = obj_dude then
      begin
        // NOTE: Uninline.
        item_d_set_addict(item_obj^.Pid);
      end;
    end;
  end;

  Result := 1;
end;

// =======================================================================
// item_d_clear
// =======================================================================
function item_d_clear(obj: PObject; data: Pointer): Integer; cdecl;
begin
  if isPartyMember(obj) then
  begin
    Result := 0;
    Exit;
  end;

  item_d_process(obj, data);

  Result := 1;
end;

// =======================================================================
// item_d_process
// =======================================================================
function item_d_process(obj: PObject; data: Pointer): Integer; cdecl;
var
  drug_effect_event: PDrugEffectEvent;
begin
  drug_effect_event := PDrugEffectEvent(data);
  perform_drug_effect(obj, @drug_effect_event^.stats[0], @drug_effect_event^.modifiers[0], False);

  if obj <> obj_dude then
  begin
    Result := 0;
    Exit;
  end;

  if (obj^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

// =======================================================================
// item_d_load
// =======================================================================
function item_d_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
var
  drug_effect_event: PDrugEffectEvent;
begin
  drug_effect_event := PDrugEffectEvent(mem_malloc(SizeOf(TDrugEffectEvent)));
  if drug_effect_event = nil then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadIntCount(stream, @drug_effect_event^.stats[0], 3) = -1 then
  begin
    mem_free(drug_effect_event);
    Result := -1;
    Exit;
  end;

  if db_freadIntCount(stream, @drug_effect_event^.modifiers[0], 3) = -1 then
  begin
    mem_free(drug_effect_event);
    Result := -1;
    Exit;
  end;

  dataPtr^ := drug_effect_event;
  Result := 0;
end;

// =======================================================================
// item_d_save
// =======================================================================
function item_d_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
var
  drugEffectEvent: PDrugEffectEvent;
begin
  drugEffectEvent := PDrugEffectEvent(data);
  if db_fwriteIntCount(stream, @drugEffectEvent^.stats[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;
  if db_fwriteIntCount(stream, @drugEffectEvent^.modifiers[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// insert_withdrawal (static)
// =======================================================================
function insert_withdrawal(obj: PObject; a2: Integer; duration: Integer; perk: Integer; pid: Integer): Integer;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(mem_malloc(SizeOf(TWithdrawalEvent)));
  if withdrawalEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  withdrawalEvent^.field_0 := a2;
  withdrawalEvent^.pid := pid;
  withdrawalEvent^.perk := perk;

  if queue_add(600 * duration, obj, withdrawalEvent, EVENT_TYPE_WITHDRAWAL) = -1 then
  begin
    mem_free(withdrawalEvent);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// item_wd_clear
// =======================================================================
function item_wd_clear(obj: PObject; data: Pointer): Integer; cdecl;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(data);

  if isPartyMember(obj) then
  begin
    Result := 0;
    Exit;
  end;

  if withdrawalEvent^.field_0 = 0 then
    perform_withdrawal_end(obj, withdrawalEvent^.perk);

  Result := 1;
end;

// =======================================================================
// item_wd_clear_all (static)
// =======================================================================
function item_wd_clear_all(a1: PObject; data: Pointer): Integer; cdecl;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(data);

  if a1 <> wd_obj then
  begin
    Result := 0;
    Exit;
  end;

  if pid_to_gvar(withdrawalEvent^.pid) <> wd_gvar then
  begin
    Result := 0;
    Exit;
  end;

  if withdrawalEvent^.field_0 = 0 then
    perform_withdrawal_end(wd_obj, withdrawalEvent^.perk);

  insert_withdrawal(a1, 1, wd_onset, withdrawalEvent^.perk, withdrawalEvent^.pid);

  wd_obj := nil;

  Result := 1;
end;

// =======================================================================
// item_wd_process
// =======================================================================
function item_wd_process(obj: PObject; data: Pointer): Integer; cdecl;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(data);

  if withdrawalEvent^.field_0 <> 0 then
  begin
    perform_withdrawal_start(obj, withdrawalEvent^.perk, withdrawalEvent^.pid);
  end
  else
  begin
    perform_withdrawal_end(obj, withdrawalEvent^.perk);

    if obj = obj_dude then
    begin
      // NOTE: Uninline.
      item_d_unset_addict(withdrawalEvent^.pid);
    end;
  end;

  if obj = obj_dude then
  begin
    Result := 1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// item_wd_load
// =======================================================================
function item_wd_load(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(mem_malloc(SizeOf(TWithdrawalEvent)));
  if withdrawalEvent = nil then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @(withdrawalEvent^.field_0)) = -1 then
  begin
    mem_free(withdrawalEvent);
    Result := -1;
    Exit;
  end;
  if db_freadInt(stream, @(withdrawalEvent^.pid)) = -1 then
  begin
    mem_free(withdrawalEvent);
    Result := -1;
    Exit;
  end;
  if db_freadInt(stream, @(withdrawalEvent^.perk)) = -1 then
  begin
    mem_free(withdrawalEvent);
    Result := -1;
    Exit;
  end;

  dataPtr^ := withdrawalEvent;
  Result := 0;
end;

// =======================================================================
// item_wd_save
// =======================================================================
function item_wd_save(stream: PDB_FILE; data: Pointer): Integer; cdecl;
var
  withdrawalEvent: PWithdrawalEvent;
begin
  withdrawalEvent := PWithdrawalEvent(data);

  if db_fwriteInt(stream, withdrawalEvent^.field_0) = -1 then
  begin
    Result := -1;
    Exit;
  end;
  if db_fwriteInt(stream, withdrawalEvent^.pid) = -1 then
  begin
    Result := -1;
    Exit;
  end;
  if db_fwriteInt(stream, withdrawalEvent^.perk) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =======================================================================
// perform_withdrawal_start (static)
// =======================================================================
procedure perform_withdrawal_start(obj: PObject; perk: Integer; pid: Integer);
var
  duration: Integer;
begin
  perk_add_effect(obj, perk);

  if obj = obj_dude then
    display_print(perk_description(perk));

  duration := 10080;
  if obj = obj_dude then
  begin
    if trait_level(TRAIT_CHEM_RELIANT) <> 0 then
      duration := duration div 2;

    if perk_level(PERK_FLOWER_CHILD) <> 0 then
      duration := duration div 2;
  end;

  insert_withdrawal(obj, 0, duration, perk, pid);
end;

// =======================================================================
// perform_withdrawal_end (static)
// =======================================================================
procedure perform_withdrawal_end(obj: PObject; perk: Integer);
var
  messageListItem: TMessageListItem;
begin
  perk_remove_effect(obj, perk);

  if obj = obj_dude then
  begin
    messageListItem.num := 3;
    if message_search(@item_message_file, @messageListItem) then
      display_print(messageListItem.text);
  end;
end;

// =======================================================================
// pid_to_gvar (static)
// =======================================================================
function pid_to_gvar(drugPid: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to ADDICTION_COUNT - 1 do
  begin
    if drug_pid[index] = drugPid then
    begin
      Result := drug_gvar[index];
      Exit;
    end;
  end;

  Result := -1;
end;

// =======================================================================
// item_d_set_addict
// =======================================================================
procedure item_d_set_addict(drugPid: Integer);
var
  gvar: Integer;
begin
  // NOTE: Uninline.
  gvar := pid_to_gvar(drugPid);
  if gvar <> -1 then
    PInteger(PByte(game_global_vars) + SizeUInt(gvar) * SizeOf(Integer))^ := 1;

  pc_flag_on(PC_FLAG_ADDICTED);
end;

// =======================================================================
// item_d_unset_addict
// =======================================================================
procedure item_d_unset_addict(drugPid: Integer);
var
  gvar: Integer;
begin
  // NOTE: Uninline.
  gvar := pid_to_gvar(drugPid);
  if gvar <> -1 then
    PInteger(PByte(game_global_vars) + SizeUInt(gvar) * SizeOf(Integer))^ := 0;

  if not item_d_check_addict(-1) then
    pc_flag_off(PC_FLAG_ADDICTED);
end;

// =======================================================================
// item_d_check_addict
// =======================================================================
function item_d_check_addict(drugPid: Integer): Boolean;
var
  index: Integer;
begin
  for index := 0 to ADDICTION_COUNT - 1 do
  begin
    if drug_pid[index] = drugPid then
    begin
      Result := PInteger(PByte(game_global_vars) + SizeUInt(drug_gvar[index]) * SizeOf(Integer))^ <> 0;
      Exit;
    end;

    if drugPid = -1 then
    begin
      if PInteger(PByte(game_global_vars) + SizeUInt(drug_gvar[index]) * SizeOf(Integer))^ <> 0 then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

  Result := False;
end;

// =======================================================================
// item_caps_total
// =======================================================================
function item_caps_total(obj: PObject): Integer;
var
  amount: Integer;
  inventory: PInventory;
  i: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
begin
  amount := 0;

  inventory := @(obj^.Data.AsData.Inventory);
  i := 0;
  while i < inventory^.Length do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(i) * SizeOf(TInventoryItem));
    item := inventoryItem^.Item;

    if item^.Pid = PROTO_ID_MONEY then
    begin
      amount := amount + inventoryItem^.Quantity;
    end
    else
    begin
      if item_get_type(item) = ITEM_TYPE_CONTAINER then
        amount := amount + item_caps_total(item);
    end;
    Inc(i);
  end;

  Result := amount;
end;

// =======================================================================
// item_caps_adjust
// =======================================================================
function item_caps_adjust(obj: PObject; amount: Integer): Integer;
var
  caps: Integer;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
  capsInContainer: Integer;
begin
  caps := item_caps_total(obj);
  if (amount < 0) and (caps < -amount) then
  begin
    Result := -1;
    Exit;
  end;

  if (amount <= 0) or (caps <> 0) then
  begin
    inventory := @(obj^.Data.AsData.Inventory);

    index := 0;
    while (index < inventory^.Length) and (amount <> 0) do
    begin
      inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
      item := inventoryItem^.Item;
      if item^.Pid = PROTO_ID_MONEY then
      begin
        if (amount <= 0) and (-amount >= inventoryItem^.Quantity) then
        begin
          obj_erase_object(item, nil);

          amount := amount + inventoryItem^.Quantity;

          // NOTE: Uninline.
          item_compact(index, inventory);

          index := -1;
        end
        else
        begin
          inventoryItem^.Quantity := inventoryItem^.Quantity + amount;
          amount := 0;
        end;
      end;
      Inc(index);
    end;

    index := 0;
    while (index < inventory^.Length) and (amount <> 0) do
    begin
      inventoryItem := PInventoryItem(PByte(inventory^.Items) + SizeUInt(index) * SizeOf(TInventoryItem));
      item := inventoryItem^.Item;
      if item_get_type(item) = ITEM_TYPE_CONTAINER then
      begin
        capsInContainer := item_caps_total(item);
        if (amount <= 0) or (capsInContainer <= 0) then
        begin
          if amount < 0 then
          begin
            if capsInContainer < -amount then
            begin
              if item_caps_adjust(item, capsInContainer) = 0 then
                amount := amount + capsInContainer;
            end
            else
            begin
              if item_caps_adjust(item, amount) = 0 then
                amount := 0;
            end;
          end;
        end
        else
        begin
          if item_caps_adjust(item, amount) = 0 then
            amount := 0;
        end;
      end;
      Inc(index);
    end;

    Result := 0;
    Exit;
  end;

  if obj_pid_new(@item, PROTO_ID_MONEY) = 0 then
  begin
    obj_disconnect(item, nil);
    if item_add_force(obj, item, amount) <> 0 then
    begin
      obj_erase_object(item, nil);
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// item_caps_get_amount
// =======================================================================
function item_caps_get_amount(obj: PObject): Integer;
begin
  if obj^.Pid <> PROTO_ID_MONEY then
  begin
    Result := -1;
    Exit;
  end;

  Result := obj^.Data.AsData.ItemSceneryMisc.Item.Misc.Charges;
end;

// =======================================================================
// item_caps_set_amount
// =======================================================================
function item_caps_set_amount(obj: PObject; amount: Integer): Integer;
begin
  if obj^.Pid <> PROTO_ID_MONEY then
  begin
    Result := -1;
    Exit;
  end;

  obj^.Data.AsData.ItemSceneryMisc.Item.Misc.Charges := amount;

  Result := 0;
end;

initialization
  _item_name_ptr := @_item_name[0];

end.
