unit u_party;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/party.h + party.cc
// Party member management: add, remove, save, load, heal, item scripts.

interface

uses
  u_object_types, u_db;

type
  PPartyMember = ^TPartyMember;
  TPartyMember = record
    object_: PObject;
    script_: Pointer;  // PScript, stored opaque here
    vars: PInteger;
    next: PPartyMember;
  end;

function partyMemberAdd(object_: PObject): Integer;
function partyMemberRemove(object_: PObject): Integer;
function partyMemberPrepSave: Integer;
function partyMemberUnPrepSave: Integer;
function partyMemberSave(stream: PDB_FILE): Integer;
function partyMemberPrepLoad: Integer;
function partyMemberRecoverLoad: Integer;
function partyMemberLoad(stream: PDB_FILE): Integer;
procedure partyMemberClear;
function partyMemberSyncPosition: Integer;
function partyMemberRestingHeal(a1: Integer): Integer;
function partyMemberFindObjFromPid(pid: Integer): PObject;
function isPartyMember(object_: PObject): Boolean;
function getPartyMemberCount: Integer;
function partyMemberPrepItemSaveAll: Integer;

implementation

uses
  SysUtils,
  u_memory,
  u_debug,
  u_scripts,
  u_critter,
  u_stat,
  u_stat_defs,
  u_queue,
  u_map,
  u_gnw,
  u_object,
  u_protinst,
  u_combatai,
  u_loadsave;

// -----------------------------------------------------------------------
// Forward declarations for static functions
// -----------------------------------------------------------------------
function partyMemberFindID(id: Integer): PObject; forward;
function partyMemberNewObjID: Integer; forward;
function partyMemberNewObjIDRecurseFind(obj: PObject; objectId: Integer): Integer; forward;
function partyMemberPrepItemSave(object_: PObject): Integer; forward;
function partyMemberItemSaveAll(object_: PObject): Integer; forward;
function partyMemberItemSave(object_: PObject): Integer; forward;
function partyMemberItemRecover(partyMember: PPartyMember): Integer; forward;
function partyMemberItemRecoverAll: Integer; forward;
function partyMemberClearItemList: Integer; forward;
function partyFixMultipleMembers: Integer; forward;

// -----------------------------------------------------------------------
// Module-level variables
// -----------------------------------------------------------------------
var
  // 0x50630C
  itemSaveListHead: PPartyMember = nil;

  // 0x662824
  partyMemberList: array[0..19] of TPartyMember;

  // Number of critters added to party.
  // 0x506310
  partyMemberCount: Integer = 0;

  // 0x506314
  partyMemberItemCount: Integer = 20000;

  // 0x506318
  partyStatePrepped: Integer = 0;

  // Static local from partyMemberNewObjID
  // 0x50631C
  partyMemberNewObjID_curID: Integer = 20000;

// =======================================================================
// partyMemberAdd
// 0x485250
// =======================================================================
function partyMemberAdd(object_: PObject): Integer;
var
  index: Integer;
  partyMember: PPartyMember;
  script: PScript;
begin
  if partyMemberCount >= 20 then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];
    if (partyMember^.object_ = object_) or (partyMember^.object_^.Pid = object_^.Pid) then
    begin
      Result := 0;
      Exit;
    end;
  end;

  if partyStatePrepped <> 0 then
  begin
    debug_printf(PAnsiChar(#10'partyMemberAdd DENIED: %s'#10), [critter_name(object_)]);
    Result := -1;
    Exit;
  end;

  partyMember := @partyMemberList[partyMemberCount];
  partyMember^.object_ := object_;
  partyMember^.script_ := nil;
  partyMember^.vars := nil;

  object_^.Id := (object_^.Pid and $FFFFFF) + 18000;
  object_^.Flags := object_^.Flags or (OBJECT_NO_REMOVE or OBJECT_NO_SAVE);

  partyMemberCount := partyMemberCount + 1;

  if scr_ptr(object_^.Sid, @script) <> -1 then
  begin
    script^.scr_flags := script^.scr_flags or (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10);
    script^.scr_oid := object_^.Id;

    object_^.Sid := ((object_^.Pid and $FFFFFF) + 18000) or (SCRIPT_TYPE_CRITTER shl 24);
    script^.scr_id := object_^.Sid;
  end;

  combatai_switch_team(object_, 0);

  Result := 0;
end;

// =======================================================================
// partyMemberRemove
// 0x485358
// =======================================================================
function partyMemberRemove(object_: PObject): Integer;
var
  index: Integer;
  script: PScript;
begin
  if partyMemberCount = 0 then
  begin
    Result := -1;
    Exit;
  end;

  if object_ = nil then
  begin
    Result := -1;
    Exit;
  end;

  index := 1;
  while index < partyMemberCount do
  begin
    if partyMemberList[index].object_ = object_ then
      Break;
    index := index + 1;
  end;

  if index = partyMemberCount then
  begin
    Result := -1;
    Exit;
  end;

  if partyStatePrepped <> 0 then
  begin
    debug_printf(PAnsiChar(#10'partyMemberRemove DENIED: %s'#10), [critter_name(object_)]);
    Result := -1;
    Exit;
  end;

  if index < partyMemberCount - 1 then
  begin
    partyMemberList[index].object_ := partyMemberList[partyMemberCount - 1].object_;
  end;

  object_^.Flags := object_^.Flags and (not (OBJECT_NO_REMOVE or OBJECT_NO_SAVE));

  partyMemberCount := partyMemberCount - 1;

  if scr_ptr(object_^.Sid, @script) <> -1 then
  begin
    script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10));
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberPrepSave
// 0x48542C
// =======================================================================
function partyMemberPrepSave: Integer;
var
  index: Integer;
  partyMember: PPartyMember;
  script: PScript;
begin
  partyStatePrepped := 1;

  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];

    if index > 0 then
    begin
      partyMember^.object_^.Flags := partyMember^.object_^.Flags and (not (OBJECT_NO_REMOVE or OBJECT_NO_SAVE));
    end;

    if scr_ptr(partyMember^.object_^.Sid, @script) <> -1 then
    begin
      script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10));
    end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberUnPrepSave
// 0x49466C
// =======================================================================
function partyMemberUnPrepSave: Integer;
var
  index: Integer;
  partyMember: PPartyMember;
  script: PScript;
begin
  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];

    if index > 0 then
    begin
      partyMember^.object_^.Flags := partyMember^.object_^.Flags or (OBJECT_NO_REMOVE or OBJECT_NO_SAVE);
    end;

    if scr_ptr(partyMember^.object_^.Sid, @script) <> -1 then
    begin
      script^.scr_flags := script^.scr_flags or (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10);
    end;
  end;

  partyStatePrepped := 0;

  Result := 0;
end;

// =======================================================================
// partyMemberSave
// 0x4854EC
// =======================================================================
function partyMemberSave(stream: PDB_FILE): Integer;
var
  index: Integer;
  partyMember: PPartyMember;
begin
  if db_fwriteInt(stream, partyMemberCount) = -1 then begin Result := -1; Exit; end;
  if db_fwriteInt(stream, partyMemberItemCount) = -1 then begin Result := -1; Exit; end;

  for index := 1 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];
    if db_fwriteInt(stream, partyMember^.object_^.Id) = -1 then begin Result := -1; Exit; end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberFindID (static)
// 0x485554
// =======================================================================
function partyMemberFindID(id: Integer): PObject;
var
  object_: PObject;
begin
  object_ := obj_find_first();
  while object_ <> nil do
  begin
    if object_^.Id = id then
      Break;
    object_ := obj_find_next();
  end;

  Result := object_;
end;

// =======================================================================
// partyMemberPrepLoad
// 0x485570
// =======================================================================
function partyMemberPrepLoad: Integer;
var
  index: Integer;
  partyMember: PPartyMember;
  script: PScript;
begin
  if partyStatePrepped <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  partyStatePrepped := 1;

  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];

    if scr_ptr(partyMember^.object_^.Sid, @script) <> -1 then
    begin
      partyMember^.script_ := mem_malloc(SizeOf(TScript));
      if partyMember^.script_ = nil then
      begin
        GNWSystemError(PAnsiChar(#10'  Error!: partyMemberPrepLoad: Out of memory!'));
        Halt(1);
      end;

      Move(script^, partyMember^.script_^, SizeOf(TScript));

      if (script^.scr_num_local_vars <> 0) and (script^.scr_local_var_offset <> -1) then
      begin
        partyMember^.vars := PInteger(mem_malloc(SizeOf(Integer) * script^.scr_num_local_vars));
        if partyMember^.vars = nil then
        begin
          GNWSystemError(PAnsiChar(#10'  Error!: partyMemberPrepLoad: Out of memory!'));
          Halt(1);
        end;

        Move(PInteger(PByte(map_local_vars) + script^.scr_local_var_offset * SizeOf(Integer))^,
             partyMember^.vars^,
             SizeOf(Integer) * script^.scr_num_local_vars);
      end;

      // NOTE: Uninline.
      if partyMemberItemSaveAll(partyMember^.object_) = -1 then
      begin
        GNWSystemError(PAnsiChar(#10'  Error!: partyMemberPrepLoad: partyMemberItemSaveAll failed!'));
        Halt(1);
      end;

      script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10));

      scr_remove(script^.scr_id);
    end
    else
    begin
      debug_printf(PAnsiChar(#10'  Error!: partyMemberPrepLoad: Can''t find script!'));
    end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberRecoverLoad
// 0x4856C8
// =======================================================================
function partyMemberRecoverLoad: Integer;
var
  index: Integer;
  partyMember: PPartyMember;
  script: PScript;
  sid: Integer;
  savedScript: PScript;
begin
  sid := -1;

  if partyStatePrepped <> 1 then
  begin
    debug_printf(PAnsiChar(#10'partyMemberRecoverLoad DENIED'));
    Result := -1;
    Exit;
  end;

  debug_printf(PAnsiChar(#10));

  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];
    if partyMember^.script_ <> nil then
    begin
      if scr_new(@sid, SCRIPT_TYPE_CRITTER) = -1 then
      begin
        GNWSystemError(PAnsiChar(#10'  Error!: partyMemberRecoverLoad: Can''t create script!'));
        Halt(1);
      end;

      if scr_ptr(sid, @script) = -1 then
      begin
        GNWSystemError(PAnsiChar(#10'  Error!: partyMemberRecoverLoad: Can''t find script!'));
        Halt(1);
      end;

      savedScript := PScript(partyMember^.script_);
      Move(savedScript^, script^, SizeOf(TScript));

      partyMember^.object_^.Sid := ((partyMember^.object_^.Pid and $FFFFFF) + 18000) or (SCRIPT_TYPE_CRITTER shl 24);
      script^.scr_id := partyMember^.object_^.Sid;

      script^.program_ := nil;
      script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x01 or SCRIPT_FLAG_0x04));

      mem_free(partyMember^.script_);
      partyMember^.script_ := nil;

      script^.scr_flags := script^.scr_flags or (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10);

      if partyMember^.vars <> nil then
      begin
        script^.scr_local_var_offset := map_malloc_local_var(script^.scr_num_local_vars);
        Move(partyMember^.vars^,
             PInteger(PByte(map_local_vars) + script^.scr_local_var_offset * SizeOf(Integer))^,
             SizeOf(Integer) * script^.scr_num_local_vars);
      end;

      debug_printf('[Party Member %d]: %s'#10, [index, critter_name(partyMember^.object_)]);
    end;
  end;

  // NOTE: Uninline.
  if partyMemberItemRecoverAll() = -1 then
  begin
    GNWSystemError(PAnsiChar(#10'  Error!: partyMemberRecoverLoad: Can''t recover item scripts!'));
    Halt(1);
  end;

  partyStatePrepped := 0;

  if isLoadingGame() = 0 then
  begin
    partyFixMultipleMembers();
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberLoad
// 0x485888
// =======================================================================
function partyMemberLoad(stream: PDB_FILE): Integer;
var
  objectIds: array[0..19] of Integer;
  index: Integer;
  object_: PObject;
begin
  if db_freadInt(stream, @partyMemberCount) = -1 then begin Result := -1; Exit; end;
  if db_freadInt(stream, @partyMemberItemCount) = -1 then begin Result := -1; Exit; end;

  partyMemberList[0].object_ := obj_dude;

  if partyMemberCount <> 0 then
  begin
    for index := 1 to partyMemberCount - 1 do
    begin
      if db_freadInt(stream, @objectIds[index]) = -1 then begin Result := -1; Exit; end;
    end;

    for index := 1 to partyMemberCount - 1 do
    begin
      object_ := partyMemberFindID(objectIds[index]);

      if object_ = nil then
      begin
        debug_printf(PAnsiChar(#10'  Error: partyMemberLoad: Can''t match ID!'));
        Result := -1;
        Exit;
      end;

      partyMemberList[index].object_ := object_;
    end;

    if partyMemberUnPrepSave() = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  partyFixMultipleMembers();

  Result := 0;
end;

// =======================================================================
// partyMemberClear
// 0x485978
// =======================================================================
procedure partyMemberClear;
var
  index: Integer;
begin
  if partyStatePrepped <> 0 then
  begin
    partyMemberUnPrepSave();
  end;

  index := partyMemberCount;
  while index > 1 do
  begin
    partyMemberRemove(partyMemberList[1].object_);
    index := index - 1;
  end;

  partyMemberCount := 1;

  scr_remove_all();
  partyMemberClearItemList();

  partyStatePrepped := 0;
end;

// =======================================================================
// partyMemberSyncPosition
// 0x4859C8
// =======================================================================
function partyMemberSyncPosition: Integer;
var
  index: Integer;
  partyMember: PPartyMember;
begin
  for index := 1 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];
    if (partyMember^.object_^.Flags and OBJECT_HIDDEN) = 0 then
    begin
      obj_attempt_placement(partyMember^.object_, obj_dude^.Tile, obj_dude^.Elevation, 2);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberRestingHeal
// Heals party members according to their healing rate.
// 0x485A18
// =======================================================================
function partyMemberRestingHeal(a1: Integer): Integer;
var
  v1: Integer;
  index: Integer;
  partyMember: PPartyMember;
  healingRate: Integer;
begin
  v1 := a1 div 3;
  if v1 = 0 then
  begin
    Result := 0;
    Exit;
  end;

  for index := 0 to partyMemberCount - 1 do
  begin
    partyMember := @partyMemberList[index];
    if PID_TYPE(partyMember^.object_^.Pid) = OBJ_TYPE_CRITTER then
    begin
      healingRate := stat_level(partyMember^.object_, Ord(STAT_HEALING_RATE));
      critter_adjust_hits(partyMember^.object_, v1 * healingRate);
    end;
  end;

  Result := 1;
end;

// =======================================================================
// partyMemberFindObjFromPid
// 0x485A78
// =======================================================================
function partyMemberFindObjFromPid(pid: Integer): PObject;
var
  index: Integer;
  object_: PObject;
begin
  for index := 0 to partyMemberCount - 1 do
  begin
    object_ := partyMemberList[index].object_;
    if object_^.Pid = pid then
    begin
      Result := object_;
      Exit;
    end;
  end;

  Result := nil;
end;

// =======================================================================
// isPartyMember
// Returns true if specified object is a party member.
// 0x485AAC
// =======================================================================
function isPartyMember(object_: PObject): Boolean;
var
  index: Integer;
begin
  if object_^.Id < 18000 then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to partyMemberCount - 1 do
  begin
    if partyMemberList[index].object_ = object_ then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

// =======================================================================
// getPartyMemberCount
// Returns number of active critters in the party.
// 0x485AE8
// =======================================================================
function getPartyMemberCount: Integer;
var
  index: Integer;
  object_: PObject;
  count: Integer;
begin
  count := partyMemberCount;

  for index := 1 to partyMemberCount - 1 do
  begin
    object_ := partyMemberList[index].object_;
    if (object_^.Flags and OBJECT_HIDDEN) <> 0 then
    begin
      count := count - 1;
    end;
  end;

  Result := count;
end;

// =======================================================================
// partyMemberNewObjID (static)
// 0x485B1C
// =======================================================================
function partyMemberNewObjID: Integer;
var
  object_: PObject;
  inventory: PInventory;
  invIndex: Integer;
  inventoryItem: PInventoryItem;
  item: PObject;
  found: Boolean;
begin
  repeat
    partyMemberNewObjID_curID := partyMemberNewObjID_curID + 1;

    object_ := obj_find_first();
    while object_ <> nil do
    begin
      if object_^.Id = partyMemberNewObjID_curID then
        Break;

      inventory := @object_^.Data.AsData.Inventory;

      found := False;
      invIndex := 0;
      while invIndex < inventory^.Length do
      begin
        inventoryItem := PInventoryItem(PByte(inventory^.Items) + invIndex * SizeOf(TInventoryItem));
        item := inventoryItem^.Item;
        if item^.Id = partyMemberNewObjID_curID then
        begin
          found := True;
          Break;
        end;

        if partyMemberNewObjIDRecurseFind(item, partyMemberNewObjID_curID) <> 0 then
        begin
          found := True;
          Break;
        end;

        invIndex := invIndex + 1;
      end;

      if found then
        Break;

      object_ := obj_find_next();
    end;
  until object_ = nil;

  partyMemberNewObjID_curID := partyMemberNewObjID_curID + 1;

  Result := partyMemberNewObjID_curID;
end;

// =======================================================================
// partyMemberNewObjIDRecurseFind (static)
// 0x485BA0
// =======================================================================
function partyMemberNewObjIDRecurseFind(obj: PObject; objectId: Integer): Integer;
var
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
begin
  inventory := @obj^.Data.AsData.Inventory;
  for index := 0 to inventory^.Length - 1 do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + index * SizeOf(TInventoryItem));
    if inventoryItem^.Item^.Id = objectId then
    begin
      Result := 1;
      Exit;
    end;

    if partyMemberNewObjIDRecurseFind(inventoryItem^.Item, objectId) <> 0 then
    begin
      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberPrepItemSaveAll
// 0x485BEC
// =======================================================================
function partyMemberPrepItemSaveAll: Integer;
var
  partyMemberIndex: Integer;
  object_: PObject;
  inventory: PInventory;
  inventoryItemIndex: Integer;
  inventoryItem: PInventoryItem;
begin
  for partyMemberIndex := 0 to partyMemberCount - 1 do
  begin
    object_ := partyMemberList[partyMemberIndex].object_;

    inventory := @object_^.Data.AsData.Inventory;
    for inventoryItemIndex := 0 to inventory^.Length - 1 do
    begin
      inventoryItem := PInventoryItem(PByte(inventory^.Items) + inventoryItemIndex * SizeOf(TInventoryItem));
      partyMemberPrepItemSave(inventoryItem^.Item);
    end;
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberPrepItemSave (static)
// 0x485C40
// =======================================================================
function partyMemberPrepItemSave(object_: PObject): Integer;
var
  script: PScript;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
begin
  if object_^.Sid <> -1 then
  begin
    if scr_ptr(object_^.Sid, @script) = -1 then
    begin
      GNWSystemError(PAnsiChar(#10'  Error!: partyMemberPrepItemSaveAll: Can''t find script!'));
      Halt(1);
    end;

    script^.scr_flags := script^.scr_flags or (SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10);
  end;

  inventory := @object_^.Data.AsData.Inventory;
  for index := 0 to inventory^.Length - 1 do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + index * SizeOf(TInventoryItem));
    partyMemberPrepItemSave(inventoryItem^.Item);
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberItemSaveAll (static)
// 0x485CAC
// =======================================================================
function partyMemberItemSaveAll(object_: PObject): Integer;
var
  inventory: PInventory;
  inventoryItem: PInventoryItem;
  index: Integer;
begin
  inventory := @object_^.Data.AsData.Inventory;
  for index := 0 to inventory^.Length - 1 do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + index * SizeOf(TInventoryItem));
    partyMemberItemSave(inventoryItem^.Item);
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberItemSave (static)
// 0x485CDC
// =======================================================================
function partyMemberItemSave(object_: PObject): Integer;
var
  script: PScript;
  node: PPartyMember;
  temp: PPartyMember;
  inventory: PInventory;
  index: Integer;
  inventoryItem: PInventoryItem;
begin
  if object_^.Sid <> -1 then
  begin
    if scr_ptr(object_^.Sid, @script) = -1 then
    begin
      GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemSave: Can''t find script!'));
      Halt(1);
    end;

    if object_^.Id < 20000 then
    begin
      script^.scr_oid := partyMemberNewObjID();
      object_^.Id := script^.scr_oid;
    end;

    node := PPartyMember(mem_malloc(SizeOf(TPartyMember)));
    if node = nil then
    begin
      GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemSave: Out of memory!'));
      Halt(1);
    end;

    node^.object_ := object_;

    node^.script_ := mem_malloc(SizeOf(TScript));
    if node^.script_ = nil then
    begin
      GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemSave: Out of memory!'));
      Halt(1);
    end;

    Move(script^, node^.script_^, SizeOf(TScript));

    if (script^.scr_num_local_vars <> 0) and (script^.scr_local_var_offset <> -1) then
    begin
      node^.vars := PInteger(mem_malloc(SizeOf(Integer) * script^.scr_num_local_vars));
      if node^.vars = nil then
      begin
        GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemSave: Out of memory!'));
        Halt(1);
      end;

      Move(PInteger(PByte(map_local_vars) + script^.scr_local_var_offset * SizeOf(Integer))^,
           node^.vars^,
           SizeOf(Integer) * script^.scr_num_local_vars);
    end
    else
    begin
      node^.vars := nil;
    end;

    temp := itemSaveListHead;
    itemSaveListHead := node;
    node^.next := temp;
  end;

  inventory := @object_^.Data.AsData.Inventory;
  for index := 0 to inventory^.Length - 1 do
  begin
    inventoryItem := PInventoryItem(PByte(inventory^.Items) + index * SizeOf(TInventoryItem));
    partyMemberItemSave(inventoryItem^.Item);
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberItemRecover (static)
// 0x485E30
// =======================================================================
function partyMemberItemRecover(partyMember: PPartyMember): Integer;
var
  sid: Integer;
  script: PScript;
  savedScript: PScript;
begin
  sid := -1;

  if scr_new(@sid, SCRIPT_TYPE_ITEM) = -1 then
  begin
    GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemRecover: Can''t create script!'));
    Halt(1);
  end;

  if scr_ptr(sid, @script) = -1 then
  begin
    GNWSystemError(PAnsiChar(#10'  Error!: partyMemberItemRecover: Can''t find script!'));
    Halt(1);
  end;

  savedScript := PScript(partyMember^.script_);
  Move(savedScript^, script^, SizeOf(TScript));

  partyMember^.object_^.Sid := partyMemberItemCount or (SCRIPT_TYPE_ITEM shl 24);
  script^.scr_id := partyMemberItemCount or (SCRIPT_TYPE_ITEM shl 24);

  script^.program_ := nil;
  script^.scr_flags := script^.scr_flags and (not (SCRIPT_FLAG_0x01 or SCRIPT_FLAG_0x04 or SCRIPT_FLAG_0x08 or SCRIPT_FLAG_0x10));

  partyMemberItemCount := partyMemberItemCount + 1;

  mem_free(partyMember^.script_);
  partyMember^.script_ := nil;

  if partyMember^.vars <> nil then
  begin
    script^.scr_local_var_offset := map_malloc_local_var(script^.scr_num_local_vars);
    Move(partyMember^.vars^,
         PInteger(PByte(map_local_vars) + script^.scr_local_var_offset * SizeOf(Integer))^,
         SizeOf(Integer) * script^.scr_num_local_vars);
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberItemRecoverAll (static)
// 0x485F38
// =======================================================================
function partyMemberItemRecoverAll: Integer;
var
  partyMember: PPartyMember;
begin
  while itemSaveListHead <> nil do
  begin
    partyMember := itemSaveListHead;
    itemSaveListHead := itemSaveListHead^.next;
    partyMemberItemRecover(partyMember);
    mem_free(partyMember);
  end;

  Result := 0;
end;

// =======================================================================
// partyMemberClearItemList (static)
// 0x485F6C
// =======================================================================
function partyMemberClearItemList: Integer;
var
  node: PPartyMember;
begin
  while itemSaveListHead <> nil do
  begin
    node := itemSaveListHead;
    itemSaveListHead := itemSaveListHead^.next;

    if node^.script_ <> nil then
    begin
      mem_free(node^.script_);
    end;

    if node^.vars <> nil then
    begin
      mem_free(node^.vars);
    end;

    mem_free(node);
  end;

  partyMemberItemCount := 20000;

  Result := 0;
end;

// =======================================================================
// partyFixMultipleMembers (static)
// 0x485FC8
// =======================================================================
function partyFixMultipleMembers: Integer;
var
  object_: PObject;
  critterCount: Integer;
  v1: Boolean;
  v2: Boolean;
  candidate: PObject;
  index: Integer;
  script: PScript;
begin
  debug_printf(PAnsiChar(#10#10#10'[Party Members]:'));

  critterCount := 0;

  // TODO: This loop is wrong. Looks like it can restart itself from the
  // beginning. Probably was implemented with two nested loops.
  object_ := obj_find_first();
  while object_ <> nil do
  begin
    v1 := False;

    if PID_TYPE(object_^.Pid) = OBJ_TYPE_CRITTER then
    begin
      critterCount := critterCount + 1;
    end;

    case object_^.Pid of
      $100004C,
      $100007A,
      $10000D2,
      $100003F,
      $100012E:
        v1 := True;
    end;

    if v1 then
    begin
      debug_printf(#10'   PM: %s', [critter_name(object_)]);

      v2 := False;
      if object_^.Sid <> -1 then
      begin
        candidate := partyMemberFindObjFromPid(object_^.Pid);
        if (candidate <> nil) and (candidate <> object_) then
        begin
          if candidate^.Sid <> object_^.Sid then
          begin
            object_^.Sid := -1;
          end;
          v2 := True;
        end;
      end
      else
      begin
        v2 := True;
      end;

      if v2 then
      begin
        candidate := partyMemberFindObjFromPid(object_^.Pid);
        if candidate <> object_ then
        begin
          debug_printf(PAnsiChar(#10'Destroying evil critter doppleganger!'));

          if object_^.Sid <> -1 then
          begin
            scr_remove(object_^.Sid);
            object_^.Sid := -1;
          end
          else
          begin
            if queue_remove_this(object_, EVENT_TYPE_SCRIPT) = -1 then
            begin
              debug_printf(PAnsiChar(#10'ERROR Removing Timed Events on FIX remove!!'#10));
            end;
          end;

          obj_erase_object(object_, nil);
        end
        else
        begin
          debug_printf(PAnsiChar(#10'Error: Attempting to destroy evil critter doppleganger FAILED!'));
        end;
      end;
    end;

    object_ := obj_find_next();
  end;

  for index := 0 to partyMemberCount - 1 do
  begin
    object_ := partyMemberList[index].object_;

    if scr_ptr(object_^.Sid, @script) <> -1 then
    begin
      script^.owner := object_;
    end
    else
    begin
      debug_printf(PAnsiChar(#10'Error: Failed to fix party member critter scripts!'));
    end;
  end;

  debug_printf(#10'Total Critter Count: %d'#10#10, [critterCount]);

  Result := 0;
end;

end.
