unit u_proto;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/proto.h + proto.cc
// Prototype loading, caching, and data member access.

interface

uses
  u_object_types, u_proto_types, u_db, u_stat_defs, u_perk_defs,
  u_platform_compat, u_message;

type
  PPProto = ^PProto;

  // ProtoDataMemberValue (union)
  TProtoDataMemberValue = record
    case Integer of
      0: (integerValue: Integer);
      1: (stringValue: PAnsiChar);
  end;
  PProtoDataMemberValue = ^TProtoDataMemberValue;

const
  // ItemDataMember
  ITEM_DATA_MEMBER_PID             = 0;
  ITEM_DATA_MEMBER_NAME            = 1;
  ITEM_DATA_MEMBER_DESCRIPTION     = 2;
  ITEM_DATA_MEMBER_FID             = 3;
  ITEM_DATA_MEMBER_LIGHT_DISTANCE  = 4;
  ITEM_DATA_MEMBER_LIGHT_INTENSITY = 5;
  ITEM_DATA_MEMBER_FLAGS           = 6;
  ITEM_DATA_MEMBER_EXTENDED_FLAGS  = 7;
  ITEM_DATA_MEMBER_SID             = 8;
  ITEM_DATA_MEMBER_TYPE            = 9;
  ITEM_DATA_MEMBER_MATERIAL        = 11;
  ITEM_DATA_MEMBER_SIZE            = 12;
  ITEM_DATA_MEMBER_WEIGHT          = 13;
  ITEM_DATA_MEMBER_COST            = 14;
  ITEM_DATA_MEMBER_INVENTORY_FID   = 15;

  // CritterDataMember
  CRITTER_DATA_MEMBER_PID             = 0;
  CRITTER_DATA_MEMBER_NAME            = 1;
  CRITTER_DATA_MEMBER_DESCRIPTION     = 2;
  CRITTER_DATA_MEMBER_FID             = 3;
  CRITTER_DATA_MEMBER_LIGHT_DISTANCE  = 4;
  CRITTER_DATA_MEMBER_LIGHT_INTENSITY = 5;
  CRITTER_DATA_MEMBER_FLAGS           = 6;
  CRITTER_DATA_MEMBER_EXTENDED_FLAGS  = 7;
  CRITTER_DATA_MEMBER_SID             = 8;
  CRITTER_DATA_MEMBER_DATA            = 9;
  CRITTER_DATA_MEMBER_HEAD_FID        = 10;

  // SceneryDataMember
  SCENERY_DATA_MEMBER_PID             = 0;
  SCENERY_DATA_MEMBER_NAME            = 1;
  SCENERY_DATA_MEMBER_DESCRIPTION     = 2;
  SCENERY_DATA_MEMBER_FID             = 3;
  SCENERY_DATA_MEMBER_LIGHT_DISTANCE  = 4;
  SCENERY_DATA_MEMBER_LIGHT_INTENSITY = 5;
  SCENERY_DATA_MEMBER_FLAGS           = 6;
  SCENERY_DATA_MEMBER_EXTENDED_FLAGS  = 7;
  SCENERY_DATA_MEMBER_SID             = 8;
  SCENERY_DATA_MEMBER_TYPE            = 9;
  SCENERY_DATA_MEMBER_DATA            = 10;
  SCENERY_DATA_MEMBER_MATERIAL        = 11;

  // WallDataMember
  WALL_DATA_MEMBER_PID             = 0;
  WALL_DATA_MEMBER_NAME            = 1;
  WALL_DATA_MEMBER_DESCRIPTION     = 2;
  WALL_DATA_MEMBER_FID             = 3;
  WALL_DATA_MEMBER_LIGHT_DISTANCE  = 4;
  WALL_DATA_MEMBER_LIGHT_INTENSITY = 5;
  WALL_DATA_MEMBER_FLAGS           = 6;
  WALL_DATA_MEMBER_EXTENDED_FLAGS  = 7;
  WALL_DATA_MEMBER_SID             = 8;
  WALL_DATA_MEMBER_MATERIAL        = 9;

  // MiscDataMember
  MISC_DATA_MEMBER_PID             = 0;
  MISC_DATA_MEMBER_NAME            = 1;
  MISC_DATA_MEMBER_DESCRIPTION     = 2;
  MISC_DATA_MEMBER_FID             = 3;
  MISC_DATA_MEMBER_LIGHT_DISTANCE  = 4;
  MISC_DATA_MEMBER_LIGHT_INTENSITY = 5;
  MISC_DATA_MEMBER_FLAGS           = 6;
  MISC_DATA_MEMBER_EXTENDED_FLAGS  = 7;

  // ProtoDataMemberType
  PROTO_DATA_MEMBER_TYPE_INT    = 1;
  PROTO_DATA_MEMBER_TYPE_STRING = 2;

  // PrototypeMessage
  PROTOTYPE_MESSAGE_NAME        = 0;
  PROTOTYPE_MESSAGE_DESCRIPTION = 1;

var
  cd_path_base: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  proto_path_base: array[0..6] of AnsiChar; // "proto\"
  mp_critter_stats_list: array[0..(2 + Ord(STAT_COUNT)) - 1] of PAnsiChar;
  proto_msg_files: array[0..5] of TMessageList;
  race_type_strs: array[0..RACE_TYPE_COUNT - 1] of PAnsiChar;
  scenery_pro_type: array[0..SCENERY_TYPE_COUNT - 1] of PAnsiChar;
  proto_main_msg_file: TMessageList;
  cal_type_strs: array[0..CALIBER_TYPE_COUNT - 1] of PAnsiChar;
  item_pro_material: array[0..MATERIAL_TYPE_COUNT - 1] of PAnsiChar;
  mp_perk_code_strs: array[0..Ord(PERK_COUNT)] of PAnsiChar;
  proto_none_str: PAnsiChar;
  body_type_strs: array[0..BODY_TYPE_COUNT - 1] of PAnsiChar;
  item_pro_type: array[0..ITEM_TYPE_COUNT - 1] of PAnsiChar;
  damage_code_strs: array[0..DAMAGE_TYPE_COUNT - 1] of PAnsiChar;
  perk_code_strs: PPAnsiChar;
  critter_stats_list: PPAnsiChar;

procedure proto_make_path(path: PAnsiChar; pid: Integer);
function proto_list_str(pid: Integer; proto_path: PAnsiChar): Integer;
function proto_size(atype: Integer): SizeUInt;
function proto_action_can_use(pid: Integer): Boolean;
function proto_action_can_use_on(pid: Integer): Boolean;
function proto_action_can_look_at(pid: Integer): Boolean;
function proto_action_can_talk_to(pid: Integer): Boolean;
function proto_action_can_pickup(pid: Integer): Integer;
function proto_name(pid: Integer): PAnsiChar;
function proto_description(pid: Integer): PAnsiChar;
function proto_critter_init(a1: PProto; a2: Integer): Integer;
procedure clear_pupdate_data(obj: PObject);
function proto_read_protoUpdateData(obj: PObject; stream: PDB_FILE): Integer;
function proto_write_protoUpdateData(obj: PObject; stream: PDB_FILE): Integer;
function proto_update_gen(obj: PObject): Integer;
function proto_update_init(obj: PObject): Integer;
function proto_dude_update_gender: Integer;
function proto_dude_init(const path: PAnsiChar): Integer;
function proto_data_member(pid: Integer; member: Integer; value: PProtoDataMemberValue): Integer;
function proto_init: Integer;
procedure proto_reset;
procedure proto_exit;
function proto_header_load: Integer;
function proto_save_pid(pid: Integer): Integer;
function proto_load_pid(pid: Integer; protoPtr: PPProto): Integer;
function proto_find_free_subnode(atype: Integer; protoPtr: PPProto): Integer;
procedure proto_remove_all;
function proto_ptr(pid: Integer; protoPtr: PPProto): Integer;
function proto_undo_new_id(atype: Integer): Integer;
function proto_max_id(a1: Integer): Integer;
function ResetPlayer: Integer;

implementation

uses
  SysUtils, u_art, u_debug, u_memory, u_gconfig, u_config,
  u_critter, u_combat, u_stat, u_skill, u_perk, u_trait, u_editor,
  u_object, u_game, u_inventry;

// Forward declarations
function proto_get_msg_info(pid: Integer; message: Integer): PAnsiChar; forward;
function proto_read_CombatData(data: PCritterCombatData; stream: PDB_FILE): Integer; forward;
function proto_write_CombatData(data: PCritterCombatData; stream: PDB_FILE): Integer; forward;
function proto_read_item_data(item_data: PItemProtoData; atype: Integer; stream: PDB_FILE): Integer; forward;
function proto_read_scenery_data(scenery_data: PSceneryProtoData; atype: Integer; stream: PDB_FILE): Integer; forward;
function proto_read_protoSubNode(proto: PProto; stream: PDB_FILE): Integer; forward;
function proto_write_item_data(item_data: PItemProtoData; atype: Integer; stream: PDB_FILE): Integer; forward;
function proto_write_scenery_data(scenery_data: PSceneryProtoData; atype: Integer; stream: PDB_FILE): Integer; forward;
function proto_write_protoSubNode(proto: PProto; stream: PDB_FILE): Integer; forward;
function proto_new_id(a1: Integer): Integer; forward;

// Module-level variables (C++ static)
var
  protolists: array[0..10] of TProtoList;
  proto_sizes: array[0..10] of SizeUInt;
  protos_been_initialized: Integer = 0;
  pc_proto: TCritterProto;
  proto_blocking_list: array[0..8] of Integer;
  _aDrugStatSpecia: PAnsiChar = 'Drug Stat (Special)';
  _aNone_1: PAnsiChar = 'None';

  // Static locals from proto_dude_init
  proto_dude_init_init_true: Integer = 0;
  proto_dude_init_retval: Integer = 0;

procedure InitProtolists;
var
  i: Integer;
begin
  for i := 0 to 10 do
  begin
    protolists[i].Head := nil;
    protolists[i].Tail := nil;
    protolists[i].Length := 0;
    if i <= 6 then
      protolists[i].MaxEntriesNum := 1
    else
      protolists[i].MaxEntriesNum := 0;
  end;
end;

procedure InitProtoSizes;
begin
  proto_sizes[0] := SizeOf(TItemProto);
  proto_sizes[1] := SizeOf(TCritterProto);
  proto_sizes[2] := SizeOf(TSceneryProto);
  proto_sizes[3] := SizeOf(TWallProto);
  proto_sizes[4] := SizeOf(TTileProto);
  proto_sizes[5] := SizeOf(TMiscProto);
  proto_sizes[6] := 0;
  proto_sizes[7] := 0;
  proto_sizes[8] := 0;
  proto_sizes[9] := 0;
  proto_sizes[10] := 0;
end;

procedure InitPcProto;
var
  i: Integer;
begin
  pc_proto.Pid := $1000000;
  pc_proto.MessageId := -1;
  pc_proto.Fid := $1000001;
  pc_proto.LightDistance := 0;
  pc_proto.LightIntensity := 0;
  pc_proto.Flags := $20000000;
  pc_proto.ExtendedFlags := 0;
  pc_proto.Sid := -1;

  pc_proto.Data.Flags := 0;
  for i := 0 to 34 do
    pc_proto.Data.BaseStats[i] := 5;
  // Overrides from C++ initializer
  pc_proto.Data.BaseStats[7] := 5;
  pc_proto.Data.BaseStats[8] := 5;
  pc_proto.Data.BaseStats[9] := 5;
  pc_proto.Data.BaseStats[10] := 5;
  pc_proto.Data.BaseStats[11] := 5;
  pc_proto.Data.BaseStats[12] := 5;
  pc_proto.Data.BaseStats[13] := 5;
  pc_proto.Data.BaseStats[14] := 5;
  pc_proto.Data.BaseStats[15] := 5;
  pc_proto.Data.BaseStats[16] := 5;
  pc_proto.Data.BaseStats[17] := 5;
  pc_proto.Data.BaseStats[18] := 5;
  pc_proto.Data.BaseStats[19] := 5;
  pc_proto.Data.BaseStats[20] := 18;
  pc_proto.Data.BaseStats[21] := 0;
  pc_proto.Data.BaseStats[22] := 0;
  pc_proto.Data.BaseStats[23] := 0;
  pc_proto.Data.BaseStats[24] := 0;
  pc_proto.Data.BaseStats[25] := 0;
  pc_proto.Data.BaseStats[26] := 0;
  pc_proto.Data.BaseStats[27] := 0;
  pc_proto.Data.BaseStats[28] := 0;
  pc_proto.Data.BaseStats[29] := 100;
  pc_proto.Data.BaseStats[30] := 0;
  pc_proto.Data.BaseStats[31] := 0;
  pc_proto.Data.BaseStats[32] := 0;
  pc_proto.Data.BaseStats[33] := 23;
  pc_proto.Data.BaseStats[34] := 0;

  for i := 0 to 34 do
    pc_proto.Data.BonusStats[i] := 0;
  for i := 0 to 17 do
    pc_proto.Data.Skills[i] := 0;

  pc_proto.Data.BodyType := 0;
  pc_proto.Data.Experience := 0;
  pc_proto.Data.KillType := 0;

  pc_proto.HeadFid := -1;
  pc_proto.AiPacket := 0;
  pc_proto.Team := 0;
end;

procedure InitProtoBlockingList;
begin
  proto_blocking_list[0] := $2000043;
  proto_blocking_list[1] := $2000080;
  proto_blocking_list[2] := $200008D;
  proto_blocking_list[3] := $2000158;
  proto_blocking_list[4] := $300026D;
  proto_blocking_list[5] := $300026E;
  proto_blocking_list[6] := $500000C;
  proto_blocking_list[7] := $5000005;
  proto_blocking_list[8] := $2000031;
end;

procedure InitProtoPathBase;
begin
  StrCopy(@proto_path_base[0], 'proto\');
end;

// 0x48C87C
procedure proto_make_path(path: PAnsiChar; pid: Integer);
begin
  StrCopy(path, @cd_path_base[0]);
  StrCat(path, @proto_path_base[0]);
  if pid <> -1 then
    StrCat(path, art_dir(PID_TYPE(pid)));
end;

// 0x48CD64
function proto_list_str(pid: Integer; proto_path: PAnsiChar): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  i: Integer;
  str_buf: array[0..255] of AnsiChar;
  pch: PAnsiChar;
begin
  if pid = -1 then
    Exit(-1);

  if proto_path = nil then
    Exit(-1);

  proto_make_path(@path[0], pid);
  StrCat(@path[0], '\');
  StrCat(@path[0], art_dir(PID_TYPE(pid)));
  StrCat(@path[0], '.lst');

  stream := db_fopen(@path[0], 'rt');

  i := 1;
  while db_fgets(@str_buf[0], SizeOf(str_buf), stream) <> nil do
  begin
    if i = (pid and $FFFFFF) then
      Break;
    Inc(i);
  end;

  db_fclose(stream);

  if i <> (pid and $FFFFFF) then
    Exit(-1);

  pch := StrScan(@str_buf[0], ' ');
  if pch <> nil then
    pch^ := #0;

  pch := StrScan(@str_buf[0], #10);
  if pch <> nil then
    pch^ := #0;

  StrCopy(proto_path, @str_buf[0]);

  Result := 0;
end;

// 0x48CF90
function proto_size(atype: Integer): SizeUInt;
begin
  if (atype >= 0) and (atype < OBJ_TYPE_COUNT) then
    Result := proto_sizes[atype]
  else
    Result := 0;
end;

// 0x48CFA8
function proto_action_can_use(pid: Integer): Boolean;
var
  proto: PProto;
begin
  if proto_ptr(pid, @proto) = -1 then
    Exit(False);

  if (proto^.Item.ExtendedFlags and $0800) <> 0 then
    Exit(True);

  if (PID_TYPE(pid) = OBJ_TYPE_ITEM) and (proto^.Item.ItemType = ITEM_TYPE_CONTAINER) then
    Exit(True);

  Result := False;
end;

// 0x48CFE8
function proto_action_can_use_on(pid: Integer): Boolean;
var
  proto: PProto;
begin
  if proto_ptr(pid, @proto) = -1 then
    Exit(False);

  if (proto^.Item.ExtendedFlags and $1000) <> 0 then
    Exit(True);

  if (PID_TYPE(pid) = OBJ_TYPE_ITEM) and (proto^.Item.ItemType = ITEM_TYPE_DRUG) then
    Exit(True);

  Result := False;
end;

// 0x48D028
function proto_action_can_look_at(pid: Integer): Boolean;
begin
  Result := True;
end;

// 0x48D030
function proto_action_can_talk_to(pid: Integer): Boolean;
var
  proto: PProto;
begin
  if proto_ptr(pid, @proto) = -1 then
    Exit(False);

  if PID_TYPE(pid) = OBJ_TYPE_CRITTER then
    Exit(True);

  if (proto^.Critter.ExtendedFlags and $4000) <> 0 then
    Exit(True);

  Result := False;
end;

// 0x48D068
function proto_action_can_pickup(pid: Integer): Integer;
var
  proto: PProto;
begin
  if PID_TYPE(pid) <> OBJ_TYPE_ITEM then
    Exit(0);

  if proto_ptr(pid, @proto) = -1 then
    Exit(0);

  if proto^.Item.ItemType = ITEM_TYPE_CONTAINER then
  begin
    if (proto^.Item.ExtendedFlags and $8000) <> 0 then
      Exit(1)
    else
      Exit(0);
  end;

  Result := 1;
end;

// 0x48D0B0
function proto_get_msg_info(pid: Integer; message: Integer): PAnsiChar;
var
  v1: PAnsiChar;
  proto: PProto;
  messageList: PMessageList;
  messageListItem: TMessageListItem;
begin
  v1 := proto_none_str;

  if proto_ptr(pid, @proto) <> -1 then
  begin
    if proto^.MessageId <> -1 then
    begin
      messageList := @proto_msg_files[PID_TYPE(pid)];
      messageListItem.num := proto^.MessageId + message;
      if message_search(messageList, @messageListItem) then
        v1 := messageListItem.text;
    end;
  end;

  Result := v1;
end;

// 0x48D108
function proto_name(pid: Integer): PAnsiChar;
begin
  if pid = $1000000 then
    Exit(critter_name(obj_dude));

  Result := proto_get_msg_info(pid, PROTOTYPE_MESSAGE_NAME);
end;

// 0x48D128
function proto_description(pid: Integer): PAnsiChar;
begin
  Result := proto_get_msg_info(pid, PROTOTYPE_MESSAGE_DESCRIPTION);
end;

// 0x48D3C0
function proto_critter_init(a1: PProto; a2: Integer): Integer;
var
  v1: Integer;
  data: PCritterProtoData;
begin
  if protos_been_initialized = 0 then
    Exit(-1);

  v1 := a2 and $FFFFFF;

  a1^.Pid := -1;
  a1^.MessageId := 100 * v1;
  a1^.Fid := art_id(OBJ_TYPE_CRITTER, v1 - 1, 0, 0, 0);
  a1^.Critter.LightDistance := 0;
  a1^.Critter.LightIntensity := 0;
  a1^.Critter.Flags := $20000000;
  a1^.Critter.ExtendedFlags := $6000;
  a1^.Critter.Sid := -1;
  a1^.Critter.Data.Flags := 0;
  a1^.Critter.Data.BodyType := 0;
  a1^.Critter.HeadFid := -1;
  a1^.Critter.AiPacket := 1;

  if not art_exists(a1^.Fid) then
    a1^.Fid := art_id(OBJ_TYPE_CRITTER, 0, 0, 0, 0);

  data := @a1^.Critter.Data;
  data^.Experience := 60;
  data^.KillType := 0;
  stat_set_defaults(data);
  skill_set_defaults(data);

  Result := 0;
end;

// 0x48D4A8
procedure clear_pupdate_data(obj: PObject);
begin
  FillByte(obj^.Data.AsData, SizeOf(TObjectData), 0);
end;

// 0x48D4BC
function proto_read_CombatData(data: PCritterCombatData; stream: PDB_FILE): Integer;
begin
  if db_freadInt32(stream, @data^.DamageLastTurn) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.Maneuver) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.Ap) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.Results) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.AiPacket) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.Team) = -1 then Exit(-1);
  if db_freadInt32(stream, @data^.WhoHitMeUnion.WhoHitMeCid) = -1 then Exit(-1);

  Result := 0;
end;

// 0x48D544
function proto_write_CombatData(data: PCritterCombatData; stream: PDB_FILE): Integer;
begin
  if db_fwriteInt32(stream, data^.DamageLastTurn) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.Maneuver) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.Ap) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.Results) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.AiPacket) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.Team) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.WhoHitMeUnion.WhoHitMeCid) = -1 then Exit(-1);

  Result := 0;
end;

// 0x48D608
function proto_read_protoUpdateData(obj: PObject; stream: PDB_FILE): Integer;
var
  proto: PProto;
  temp: Integer;
  inventory: PInventory;
begin
  inventory := @obj^.Data.AsData.Inventory;
  if db_freadInt32(stream, @inventory^.Length) = -1 then Exit(-1);
  if db_freadInt32(stream, @inventory^.Capacity) = -1 then Exit(-1);
  // CE: Original code reads inventory items pointer which is meaningless.
  if db_freadInt32(stream, @temp) = -1 then Exit(-1);

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
  begin
    if db_freadInt32(stream, @obj^.Data.AsData.Critter.Field_0) = -1 then Exit(-1);
    if proto_read_CombatData(@obj^.Data.AsData.Critter.Combat, stream) = -1 then Exit(-1);
    if db_freadInt32(stream, @obj^.Data.AsData.Critter.Hp) = -1 then Exit(-1);
    if db_freadInt32(stream, @obj^.Data.AsData.Critter.Radiation) = -1 then Exit(-1);
    if db_freadInt32(stream, @obj^.Data.AsData.Critter.Poison) = -1 then Exit(-1);
  end
  else
  begin
    if db_freadInt32(stream, @obj^.Data.AsData.Flags) = -1 then Exit(-1);

    if LongWord(obj^.Data.AsData.Flags) = $CCCCCCCC then
    begin
      debug_printf(#10'Note: Reading pud: updated_flags was un-Set!');
      obj^.Data.AsData.Flags := 0;
    end;

    case PID_TYPE(obj^.Pid) of
      OBJ_TYPE_ITEM:
      begin
        if proto_ptr(obj^.Pid, @proto) = -1 then Exit(-1);

        case proto^.Item.ItemType of
          ITEM_TYPE_WEAPON:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoQuantity) = -1 then Exit(-1);
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Item.Weapon.AmmoTypePid) = -1 then Exit(-1);
          end;
          ITEM_TYPE_AMMO:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Item.Ammo.Quantity) = -1 then Exit(-1);
          end;
          ITEM_TYPE_MISC:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Item.Misc.Charges) = -1 then Exit(-1);
          end;
          ITEM_TYPE_KEY:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Item.Key.KeyCode) = -1 then Exit(-1);
          end;
        end;
      end;
      OBJ_TYPE_SCENERY:
      begin
        if proto_ptr(obj^.Pid, @proto) = -1 then Exit(-1);

        case proto^.Scenery.SceneryType of
          SCENERY_TYPE_DOOR:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Door.OpenFlags) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_STAIRS:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Stairs.DestinationMap) = -1 then Exit(-1);
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Stairs.DestinationBuiltTile) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_ELEVATOR:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Elevator.SceneryType) = -1 then Exit(-1);
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Elevator.Level) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_LADDER_UP:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Ladder.DestinationBuiltTile) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_LADDER_DOWN:
          begin
            if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Scenery.Ladder.DestinationBuiltTile) = -1 then Exit(-1);
          end;
        end;
      end;
      OBJ_TYPE_MISC:
      begin
        if (obj^.Pid >= $5000010) and (obj^.Pid <= $5000017) then
        begin
          if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Misc.Map) = -1 then Exit(-1);
          if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Misc.Tile) = -1 then Exit(-1);
          if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Misc.Elevation) = -1 then Exit(-1);
          if db_freadInt32(stream, @obj^.Data.AsData.ItemSceneryMisc.Misc.Rotation) = -1 then Exit(-1);
        end;
      end;
    end;
  end;

  Result := 0;
end;

// 0x48D9B4
function proto_write_protoUpdateData(obj: PObject; stream: PDB_FILE): Integer;
var
  proto: PProto;
  data: PObjectData;
begin
  data := @obj^.Data.AsData;
  if db_fwriteInt32(stream, data^.Inventory.Length) = -1 then Exit(-1);
  if db_fwriteInt32(stream, data^.Inventory.Capacity) = -1 then Exit(-1);
  // CE: Original code writes inventory items pointer, which is meaningless.
  if db_fwriteInt32(stream, 0) = -1 then Exit(-1);

  if PID_TYPE(obj^.Pid) = OBJ_TYPE_CRITTER then
  begin
    if db_fwriteInt32(stream, data^.Flags) = -1 then Exit(-1);
    if proto_write_CombatData(@obj^.Data.AsData.Critter.Combat, stream) = -1 then Exit(-1);
    if db_fwriteInt32(stream, data^.Critter.Hp) = -1 then Exit(-1);
    if db_fwriteInt32(stream, data^.Critter.Radiation) = -1 then Exit(-1);
    if db_fwriteInt32(stream, data^.Critter.Poison) = -1 then Exit(-1);
  end
  else
  begin
    if db_fwriteInt32(stream, data^.Flags) = -1 then Exit(-1);

    case PID_TYPE(obj^.Pid) of
      OBJ_TYPE_ITEM:
      begin
        if proto_ptr(obj^.Pid, @proto) = -1 then Exit(-1);

        case proto^.Item.ItemType of
          ITEM_TYPE_WEAPON:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Item.Weapon.AmmoQuantity) = -1 then Exit(-1);
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Item.Weapon.AmmoTypePid) = -1 then Exit(-1);
          end;
          ITEM_TYPE_AMMO:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Item.Ammo.Quantity) = -1 then Exit(-1);
          end;
          ITEM_TYPE_MISC:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Item.Misc.Charges) = -1 then Exit(-1);
          end;
          ITEM_TYPE_KEY:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Item.Key.KeyCode) = -1 then Exit(-1);
          end;
        end;
      end;
      OBJ_TYPE_SCENERY:
      begin
        if proto_ptr(obj^.Pid, @proto) = -1 then Exit(-1);

        case proto^.Scenery.SceneryType of
          SCENERY_TYPE_DOOR:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Door.OpenFlags) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_STAIRS:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Stairs.DestinationMap) = -1 then Exit(-1);
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Stairs.DestinationBuiltTile) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_ELEVATOR:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Elevator.SceneryType) = -1 then Exit(-1);
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Elevator.Level) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_LADDER_UP:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Ladder.DestinationBuiltTile) = -1 then Exit(-1);
          end;
          SCENERY_TYPE_LADDER_DOWN:
          begin
            if db_fwriteInt32(stream, data^.ItemSceneryMisc.Scenery.Ladder.DestinationBuiltTile) = -1 then Exit(-1);
          end;
        end;
      end;
      OBJ_TYPE_MISC:
      begin
        if (obj^.Pid >= $5000010) and (obj^.Pid <= $5000017) then
        begin
          if db_fwriteInt32(stream, data^.ItemSceneryMisc.Misc.Map) = -1 then Exit(-1);
          if db_fwriteInt32(stream, data^.ItemSceneryMisc.Misc.Tile) = -1 then Exit(-1);
          if db_fwriteInt32(stream, data^.ItemSceneryMisc.Misc.Elevation) = -1 then Exit(-1);
          if db_fwriteInt32(stream, data^.ItemSceneryMisc.Misc.Rotation) = -1 then Exit(-1);
        end;
      end;
    end;
  end;

  Result := 0;
end;

// 0x48DCA0
function proto_update_gen(obj: PObject): Integer;
var
  proto: PProto;
  data: PObjectData;
begin
  if protos_been_initialized = 0 then
    Exit(-1);

  data := @obj^.Data.AsData;
  data^.Inventory.Length := 0;
  data^.Inventory.Capacity := 0;
  data^.Inventory.Items := nil;

  if proto_ptr(obj^.Pid, @proto) = -1 then
    Exit(-1);

  case PID_TYPE(obj^.Pid) of
    OBJ_TYPE_ITEM:
    begin
      case proto^.Item.ItemType of
        ITEM_TYPE_CONTAINER:
          data^.Flags := 0;
        ITEM_TYPE_WEAPON:
        begin
          data^.ItemSceneryMisc.Item.Weapon.AmmoQuantity := proto^.Item.Data.Weapon.AmmoCapacity;
          data^.ItemSceneryMisc.Item.Weapon.AmmoTypePid := proto^.Item.Data.Weapon.AmmoTypePid;
        end;
        ITEM_TYPE_AMMO:
          data^.ItemSceneryMisc.Item.Ammo.Quantity := proto^.Item.Data.Ammo.Quantity;
        ITEM_TYPE_MISC:
          data^.ItemSceneryMisc.Item.Misc.Charges := proto^.Item.Data.Misc.Charges;
        ITEM_TYPE_KEY:
          data^.ItemSceneryMisc.Item.Key.KeyCode := proto^.Item.Data.Key.KeyCode;
      end;
    end;
    OBJ_TYPE_SCENERY:
    begin
      case proto^.Scenery.SceneryType of
        SCENERY_TYPE_DOOR:
          data^.ItemSceneryMisc.Scenery.Door.OpenFlags := proto^.Scenery.Data.Door.OpenFlags;
        SCENERY_TYPE_STAIRS:
        begin
          data^.ItemSceneryMisc.Scenery.Stairs.DestinationMap := proto^.Scenery.Data.Stairs.Field_0;
          data^.ItemSceneryMisc.Scenery.Stairs.DestinationBuiltTile := proto^.Scenery.Data.Stairs.Field_4;
        end;
        SCENERY_TYPE_ELEVATOR:
        begin
          data^.ItemSceneryMisc.Scenery.Elevator.SceneryType := proto^.Scenery.Data.Elevator.ElevatorType;
          data^.ItemSceneryMisc.Scenery.Elevator.Level := proto^.Scenery.Data.Elevator.Level;
        end;
        SCENERY_TYPE_LADDER_UP, SCENERY_TYPE_LADDER_DOWN:
          data^.ItemSceneryMisc.Scenery.Ladder.DestinationBuiltTile := proto^.Scenery.Data.Ladder.Field_0;
      end;
    end;
    OBJ_TYPE_MISC:
    begin
      if (obj^.Pid >= $5000010) and (obj^.Pid <= $5000017) then
      begin
        data^.ItemSceneryMisc.Misc.Tile := -1;
        data^.ItemSceneryMisc.Misc.Elevation := 0;
        data^.ItemSceneryMisc.Misc.Rotation := 0;
        data^.ItemSceneryMisc.Misc.Map := -1;
      end;
    end;
  end;

  Result := 0;
end;

// 0x48DDE4
function proto_update_init(obj: PObject): Integer;
var
  data: PObjectData;
  proto: PProto;
begin
  if protos_been_initialized = 0 then
    Exit(-1);

  if obj = nil then
    Exit(-1);

  if obj^.Pid = -1 then
    Exit(-1);

  clear_pupdate_data(obj);

  if PID_TYPE(obj^.Pid) <> OBJ_TYPE_CRITTER then
    Exit(proto_update_gen(obj));

  data := @obj^.Data.AsData;
  data^.Inventory.Length := 0;
  data^.Inventory.Capacity := 0;
  data^.Inventory.Items := nil;
  combat_data_init(obj);
  data^.Critter.Hp := stat_level(obj, Ord(STAT_MAXIMUM_HIT_POINTS));
  data^.Critter.Combat.Ap := stat_level(obj, Ord(STAT_MAXIMUM_ACTION_POINTS));
  stat_recalc_derived(obj);
  obj^.Data.AsData.Critter.Combat.WhoHitMeUnion.WhoHitMe := nil;

  if proto_ptr(obj^.Pid, @proto) <> -1 then
  begin
    data^.Critter.Combat.AiPacket := proto^.Critter.AiPacket;
    data^.Critter.Combat.Team := proto^.Critter.Team;
  end;

  Result := 0;
end;

// 0x48DEC8
function proto_dude_update_gender: Integer;
var
  proto: PProto;
  art_num: Integer;
  v1: Integer;
  fid: Integer;
begin
  if proto_ptr($1000000, @proto) = -1 then
    Exit(-1);

  if stat_level(obj_dude, Ord(STAT_GENDER)) = GENDER_MALE then
    art_num := art_vault_person_nums[GENDER_MALE]
  else
    art_num := art_vault_person_nums[GENDER_FEMALE];

  art_vault_guy_num := art_num;

  if inven_worn(obj_dude) = nil then
  begin
    v1 := 0;
    if (inven_right_hand(obj_dude) <> nil) or (inven_left_hand(obj_dude) <> nil) then
      v1 := (obj_dude^.Fid and $F000) shr 12;

    fid := art_id(OBJ_TYPE_CRITTER, art_vault_guy_num, 0, v1, 0);
    obj_change_fid(obj_dude, fid, nil);
  end;

  proto^.Fid := art_id(OBJ_TYPE_CRITTER, art_vault_guy_num, 0, 0, 0);

  Result := 0;
end;

// 0x48DF90
function proto_dude_init(const path: PAnsiChar): Integer;
var
  proto: PProto;
begin
  pc_proto.Fid := art_id(OBJ_TYPE_CRITTER, art_vault_guy_num, 0, 0, 0);

  if proto_dude_init_init_true <> 0 then
    obj_inven_free(@obj_dude^.Data.AsData.Inventory);

  proto_dude_init_init_true := 1;

  if proto_ptr($1000000, @proto) = -1 then
    Exit(-1);

  proto_ptr(obj_dude^.Pid, @proto);

  proto_update_init(obj_dude);
  obj_dude^.Data.AsData.Critter.Combat.AiPacket := 0;
  obj_dude^.Data.AsData.Critter.Combat.Team := 0;
  ResetPlayer();

  if pc_load_data(path) = -1 then
    proto_dude_init_retval := -1;

  proto^.Critter.Data.BaseStats[Ord(STAT_DAMAGE_RESISTANCE_EMP)] := 100;
  proto^.Critter.Data.BodyType := 0;
  proto^.Critter.Data.Experience := 0;
  proto^.Critter.Data.KillType := 0;

  proto_dude_update_gender();
  inven_reset_dude();

  if (obj_dude^.Flags and OBJECT_FLAT) <> 0 then
    obj_toggle_flat(obj_dude, nil);

  if (obj_dude^.Flags and OBJECT_NO_BLOCK) <> 0 then
    obj_dude^.Flags := obj_dude^.Flags and (not OBJECT_NO_BLOCK);

  stat_recalc_derived(obj_dude);
  critter_adjust_hits(obj_dude, 10000);

  if proto_dude_init_retval <> 0 then
    debug_printf(#10' ** Error in proto_dude_init()! **'#10);

  Result := 0;
end;

// 0x48E534
function proto_data_member(pid: Integer; member: Integer; value: PProtoDataMemberValue): Integer;
var
  proto: PProto;
begin
  if proto_ptr(pid, @proto) = -1 then
    Exit(-1);

  case PID_TYPE(pid) of
    OBJ_TYPE_ITEM:
    begin
      case member of
        ITEM_DATA_MEMBER_PID:
          value^.integerValue := proto^.Pid;
        ITEM_DATA_MEMBER_NAME:
        begin
          value^.stringValue := proto_name(proto^.Scenery.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        ITEM_DATA_MEMBER_DESCRIPTION:
        begin
          value^.stringValue := proto_description(proto^.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        ITEM_DATA_MEMBER_FID:
          value^.integerValue := proto^.Fid;
        ITEM_DATA_MEMBER_LIGHT_DISTANCE:
          value^.integerValue := proto^.Item.LightDistance;
        ITEM_DATA_MEMBER_LIGHT_INTENSITY:
          value^.integerValue := proto^.Item.LightIntensity;
        ITEM_DATA_MEMBER_FLAGS:
          value^.integerValue := proto^.Item.Flags;
        ITEM_DATA_MEMBER_EXTENDED_FLAGS:
          value^.integerValue := proto^.Item.ExtendedFlags;
        ITEM_DATA_MEMBER_SID:
          value^.integerValue := proto^.Item.Sid;
        ITEM_DATA_MEMBER_TYPE:
          value^.integerValue := proto^.Item.ItemType;
        ITEM_DATA_MEMBER_MATERIAL:
          value^.integerValue := proto^.Item.Material;
        ITEM_DATA_MEMBER_SIZE:
          value^.integerValue := proto^.Item.Size;
        ITEM_DATA_MEMBER_WEIGHT:
          value^.integerValue := proto^.Item.Weight;
        ITEM_DATA_MEMBER_COST:
          value^.integerValue := proto^.Item.Cost;
        ITEM_DATA_MEMBER_INVENTORY_FID:
          value^.integerValue := proto^.Item.InventoryFid;
      else
        debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
      end;
    end;
    OBJ_TYPE_CRITTER:
    begin
      case member of
        CRITTER_DATA_MEMBER_PID:
          value^.integerValue := proto^.Critter.Pid;
        CRITTER_DATA_MEMBER_NAME:
        begin
          value^.stringValue := proto_name(proto^.Critter.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        CRITTER_DATA_MEMBER_DESCRIPTION:
        begin
          value^.stringValue := proto_description(proto^.Critter.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        CRITTER_DATA_MEMBER_FID:
          value^.integerValue := proto^.Critter.Fid;
        CRITTER_DATA_MEMBER_LIGHT_DISTANCE:
          value^.integerValue := proto^.Critter.LightDistance;
        CRITTER_DATA_MEMBER_LIGHT_INTENSITY:
          value^.integerValue := proto^.Critter.LightIntensity;
        CRITTER_DATA_MEMBER_FLAGS:
          value^.integerValue := proto^.Critter.Flags;
        CRITTER_DATA_MEMBER_EXTENDED_FLAGS:
          value^.integerValue := proto^.Critter.ExtendedFlags;
        CRITTER_DATA_MEMBER_SID:
          value^.integerValue := proto^.Critter.Sid;
        CRITTER_DATA_MEMBER_HEAD_FID:
          value^.integerValue := proto^.Critter.HeadFid;
      else
        debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
      end;
    end;
    OBJ_TYPE_SCENERY:
    begin
      case member of
        SCENERY_DATA_MEMBER_PID:
          value^.integerValue := proto^.Scenery.Pid;
        SCENERY_DATA_MEMBER_NAME:
        begin
          value^.stringValue := proto_name(proto^.Scenery.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        SCENERY_DATA_MEMBER_DESCRIPTION:
        begin
          value^.stringValue := proto_description(proto^.Scenery.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        SCENERY_DATA_MEMBER_FID:
          value^.integerValue := proto^.Scenery.Fid;
        SCENERY_DATA_MEMBER_LIGHT_DISTANCE:
          value^.integerValue := proto^.Scenery.LightDistance;
        SCENERY_DATA_MEMBER_LIGHT_INTENSITY:
          value^.integerValue := proto^.Scenery.LightIntensity;
        SCENERY_DATA_MEMBER_FLAGS:
          value^.integerValue := proto^.Scenery.Flags;
        SCENERY_DATA_MEMBER_EXTENDED_FLAGS:
          value^.integerValue := proto^.Scenery.ExtendedFlags;
        SCENERY_DATA_MEMBER_SID:
          value^.integerValue := proto^.Scenery.Sid;
        SCENERY_DATA_MEMBER_TYPE:
          value^.integerValue := proto^.Scenery.SceneryType;
        SCENERY_DATA_MEMBER_MATERIAL:
          value^.integerValue := proto^.Scenery.Material;
      else
        debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
      end;
    end;
    OBJ_TYPE_WALL:
    begin
      case member of
        WALL_DATA_MEMBER_PID:
          value^.integerValue := proto^.Wall.Pid;
        WALL_DATA_MEMBER_NAME:
        begin
          value^.stringValue := proto_name(proto^.Wall.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        WALL_DATA_MEMBER_DESCRIPTION:
        begin
          value^.stringValue := proto_description(proto^.Wall.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        WALL_DATA_MEMBER_FID:
          value^.integerValue := proto^.Wall.Fid;
        WALL_DATA_MEMBER_LIGHT_DISTANCE:
          value^.integerValue := proto^.Wall.LightDistance;
        WALL_DATA_MEMBER_LIGHT_INTENSITY:
          value^.integerValue := proto^.Wall.LightIntensity;
        WALL_DATA_MEMBER_FLAGS:
          value^.integerValue := proto^.Wall.Flags;
        WALL_DATA_MEMBER_EXTENDED_FLAGS:
          value^.integerValue := proto^.Wall.ExtendedFlags;
        WALL_DATA_MEMBER_SID:
          value^.integerValue := proto^.Wall.Sid;
        WALL_DATA_MEMBER_MATERIAL:
          value^.integerValue := proto^.Wall.Material;
      else
        debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
      end;
    end;
    OBJ_TYPE_TILE:
      debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
    OBJ_TYPE_MISC:
    begin
      case member of
        MISC_DATA_MEMBER_PID:
          value^.integerValue := proto^.Misc.Pid;
        MISC_DATA_MEMBER_NAME:
        begin
          value^.stringValue := proto_name(proto^.Misc.Pid);
          Exit(PROTO_DATA_MEMBER_TYPE_STRING);
        end;
        MISC_DATA_MEMBER_DESCRIPTION:
        begin
          value^.stringValue := proto_description(proto^.Misc.Pid);
          // FIXME: Erroneously report type as int, should be string.
          Exit(PROTO_DATA_MEMBER_TYPE_INT);
        end;
        MISC_DATA_MEMBER_FID:
        begin
          value^.integerValue := proto^.Misc.Fid;
          Exit(1);
        end;
        MISC_DATA_MEMBER_LIGHT_DISTANCE:
        begin
          value^.integerValue := proto^.Misc.LightDistance;
          Exit(1);
        end;
        MISC_DATA_MEMBER_LIGHT_INTENSITY:
          value^.integerValue := proto^.Misc.LightIntensity;
        MISC_DATA_MEMBER_FLAGS:
          value^.integerValue := proto^.Misc.Flags;
        MISC_DATA_MEMBER_EXTENDED_FLAGS:
          value^.integerValue := proto^.Misc.ExtendedFlags;
      else
        debug_printf(#10#9'Error: Unimp''d data member in member in proto_data_member!');
      end;
    end;
  end;

  Result := PROTO_DATA_MEMBER_TYPE_INT;
end;

// 0x48E84C
function proto_init: Integer;
var
  messageListItem: TMessageListItem;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  i: Integer;
begin
  // TODO: Get rid of cast.
  proto_critter_init(PProto(@pc_proto), $1000000);

  pc_proto.Pid := $1000000;
  pc_proto.Fid := art_id(OBJ_TYPE_CRITTER, 1, 0, 0, 0);

  obj_dude^.Pid := $1000000;
  obj_dude^.Sid := 1;

  // NOTE: Uninline.
  proto_remove_all();

  proto_header_load();

  protos_been_initialized := 1;

  proto_dude_init('premade\player.gcd');

  for i := 0 to 5 do
  begin
    if not message_init(@proto_msg_files[i]) then
    begin
      debug_printf(#10'Error: Initing proto message files!');
      Exit(-1);
    end;
  end;

  for i := 0 to 5 do
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%spro_%.4s%s', [msg_path, art_dir(i), '.msg']);

    if not message_load(@proto_msg_files[i], @path[0]) then
    begin
      debug_printf(#10'Error: Loading proto message files!');
      Exit(-1);
    end;
  end;

  mp_critter_stats_list[0] := _aDrugStatSpecia;
  mp_critter_stats_list[1] := _aNone_1;
  critter_stats_list := @mp_critter_stats_list[2];
  for i := 0 to Ord(STAT_COUNT) - 1 do
  begin
    PPAnsiChar(PByte(critter_stats_list) + i * SizeOf(PAnsiChar))^ := stat_name(i);
    if PPAnsiChar(PByte(critter_stats_list) + i * SizeOf(PAnsiChar))^ = nil then
    begin
      debug_printf(#10'Error: Finding stat names!');
      Exit(-1);
    end;
  end;

  mp_perk_code_strs[0] := _aNone_1;
  perk_code_strs := @mp_perk_code_strs[1];
  for i := 0 to Ord(PERK_COUNT) - 1 do
  begin
    mp_perk_code_strs[i] := perk_name(i);
    if mp_perk_code_strs[i] = nil then
    begin
      debug_printf(#10'Error: Finding perk names!');
      Exit(-1);
    end;
  end;

  if not message_init(@proto_main_msg_file) then
  begin
    debug_printf(#10'Error: Initing main proto message file!');
    Exit(-1);
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%sproto.msg', [msg_path]);

  if not message_load(@proto_main_msg_file, @path[0]) then
  begin
    debug_printf(#10'Error: Loading main proto message file!');
    Exit(-1);
  end;

  proto_none_str := getmsg(@proto_main_msg_file, @messageListItem, 10);

  // material type names
  for i := 0 to MATERIAL_TYPE_COUNT - 1 do
    item_pro_material[i] := getmsg(@proto_main_msg_file, @messageListItem, 100 + i);

  // item type names
  for i := 0 to ITEM_TYPE_COUNT - 1 do
    item_pro_type[i] := getmsg(@proto_main_msg_file, @messageListItem, 150 + i);

  // scenery type names
  for i := 0 to SCENERY_TYPE_COUNT - 1 do
    scenery_pro_type[i] := getmsg(@proto_main_msg_file, @messageListItem, 200 + i);

  // damage code types
  for i := 0 to DAMAGE_TYPE_COUNT - 1 do
    damage_code_strs[i] := getmsg(@proto_main_msg_file, @messageListItem, 250 + i);

  // caliber types
  for i := 0 to CALIBER_TYPE_COUNT - 1 do
    cal_type_strs[i] := getmsg(@proto_main_msg_file, @messageListItem, 300 + i);

  // race types
  for i := 0 to RACE_TYPE_COUNT - 1 do
    race_type_strs[i] := getmsg(@proto_main_msg_file, @messageListItem, 350 + i);

  // body types
  for i := 0 to BODY_TYPE_COUNT - 1 do
    body_type_strs[i] := getmsg(@proto_main_msg_file, @messageListItem, 400 + i);

  Result := 0;
end;

// 0x48EC20
procedure proto_reset;
begin
  // TODO: Get rid of cast.
  proto_critter_init(PProto(@pc_proto), $1000000);
  pc_proto.Pid := $1000000;
  pc_proto.Fid := art_id(OBJ_TYPE_CRITTER, 1, 0, 0, 0);

  obj_dude^.Pid := $1000000;
  obj_dude^.Sid := -1;
  obj_dude^.Flags := obj_dude^.Flags and (not OBJECT_FLAG_0xFC000);

  // NOTE: Uninline.
  proto_remove_all();

  proto_header_load();

  protos_been_initialized := 1;
  proto_dude_init('premade\player.gcd');
end;

// 0x48EC98
procedure proto_exit;
var
  i: Integer;
begin
  // NOTE: Uninline.
  proto_remove_all();

  protos_been_initialized := 0;

  for i := 0 to 5 do
    message_exit(@proto_msg_files[i]);

  message_exit(@proto_main_msg_file);
end;

// 0x48ECD8
function proto_header_load: Integer;
var
  index: Integer;
  ptr: PProtoList;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  ch: Integer;
begin
  for index := 0 to 5 do
  begin
    ptr := @protolists[index];
    ptr^.Head := nil;
    ptr^.Tail := nil;
    ptr^.Length := 0;
    ptr^.MaxEntriesNum := 1;

    proto_make_path(@path[0], index shl 24);
    StrCat(@path[0], '\');
    StrCat(@path[0], art_dir(index));
    StrCat(@path[0], '.lst');

    stream := db_fopen(@path[0], 'rt');
    if stream = nil then
      Exit(-1);

    ch := 0;
    while True do
    begin
      ch := db_fgetc(stream);
      if ch = -1 then
        Break;

      if ch = 10 then // '\n'
        Inc(ptr^.MaxEntriesNum);
    end;

    if ch <> 10 then
      Inc(ptr^.MaxEntriesNum);

    db_fclose(stream);
  end;

  Result := 0;
end;

// 0x48EEE4
function proto_read_item_data(item_data: PItemProtoData; atype: Integer; stream: PDB_FILE): Integer;
begin
  case atype of
    ITEM_TYPE_ARMOR:
    begin
      if db_freadInt32(stream, @item_data^.Armor.ArmorClass) = -1 then Exit(-1);
      if db_freadIntCount(stream, @item_data^.Armor.DamageResistance[0], 7) = -1 then Exit(-1);
      if db_freadIntCount(stream, @item_data^.Armor.DamageThreshold[0], 7) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Armor.Perk) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Armor.MaleFid) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Armor.FemaleFid) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_CONTAINER:
    begin
      if db_freadInt32(stream, @item_data^.Container.MaxSize) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Container.OpenFlags) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_DRUG:
    begin
      if db_freadInt32(stream, @item_data^.Drug.Stat[0]) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.Stat[1]) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.Stat[2]) = -1 then Exit(-1);
      if db_freadIntCount(stream, @item_data^.Drug.Amount[0], 3) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.Duration1) = -1 then Exit(-1);
      if db_freadIntCount(stream, @item_data^.Drug.Amount1[0], 3) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.Duration2) = -1 then Exit(-1);
      if db_freadIntCount(stream, @item_data^.Drug.Amount2[0], 3) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.AddictionChance) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.WithdrawalEffect) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Drug.WithdrawalOnset) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_WEAPON:
    begin
      if db_freadInt32(stream, @item_data^.Weapon.AnimationCode) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.MinDamage) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.MaxDamage) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.DamageType) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.MaxRange1) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.MaxRange2) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.ProjectilePid) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.MinStrength) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.ActionPointCost1) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.ActionPointCost2) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.CriticalFailureType) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.Perk) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.Rounds) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.Caliber) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.AmmoTypePid) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Weapon.AmmoCapacity) = -1 then Exit(-1);
      if db_freadByte(stream, @item_data^.Weapon.SoundCode) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_AMMO:
    begin
      if db_freadInt32(stream, @item_data^.Ammo.Caliber) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Ammo.Quantity) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Ammo.ArmorClassModifier) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Ammo.DamageResistanceModifier) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Ammo.DamageMultiplier) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Ammo.DamageDivisor) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_MISC:
    begin
      if db_freadInt32(stream, @item_data^.Misc.PowerTypePid) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Misc.PowerType) = -1 then Exit(-1);
      if db_freadInt32(stream, @item_data^.Misc.Charges) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_KEY:
    begin
      if db_freadInt32(stream, @item_data^.Key.KeyCode) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := 0;
end;

// 0x48F2C8
function proto_read_scenery_data(scenery_data: PSceneryProtoData; atype: Integer; stream: PDB_FILE): Integer;
begin
  case atype of
    SCENERY_TYPE_DOOR:
    begin
      if db_freadInt32(stream, @scenery_data^.Door.OpenFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @scenery_data^.Door.KeyCode) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_STAIRS:
    begin
      if db_freadInt32(stream, @scenery_data^.Stairs.Field_0) = -1 then Exit(-1);
      if db_freadInt32(stream, @scenery_data^.Stairs.Field_4) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_ELEVATOR:
    begin
      if db_freadInt32(stream, @scenery_data^.Elevator.ElevatorType) = -1 then Exit(-1);
      if db_freadInt32(stream, @scenery_data^.Elevator.Level) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_LADDER_UP, SCENERY_TYPE_LADDER_DOWN:
    begin
      if db_freadInt32(stream, @scenery_data^.Ladder.Field_0) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_GENERIC:
    begin
      if db_freadInt32(stream, @scenery_data^.Generic.Field_0) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := 0;
end;

// 0x48F398
function proto_read_protoSubNode(proto: PProto; stream: PDB_FILE): Integer;
begin
  if db_freadInt32(stream, @proto^.Pid) = -1 then Exit(-1);
  if db_freadInt32(stream, @proto^.MessageId) = -1 then Exit(-1);
  if db_freadInt32(stream, @proto^.Fid) = -1 then Exit(-1);

  case PID_TYPE(proto^.Pid) of
    OBJ_TYPE_ITEM:
    begin
      if db_freadInt32(stream, @proto^.Item.LightDistance) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.LightIntensity) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.ExtendedFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Sid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.ItemType) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Material) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Size) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Weight) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.Cost) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Item.InventoryFid) = -1 then Exit(-1);
      if db_freadByte(stream, @proto^.Item.Field_80) = -1 then Exit(-1);
      if proto_read_item_data(@proto^.Item.Data, proto^.Item.ItemType, stream) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_CRITTER:
    begin
      if db_freadInt32(stream, @proto^.Critter.LightDistance) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.LightIntensity) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.ExtendedFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.Sid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.HeadFid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.AiPacket) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Critter.Team) = -1 then Exit(-1);
      if critter_read_data(stream, @proto^.Critter.Data) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_SCENERY:
    begin
      if db_freadInt32(stream, @proto^.Scenery.LightDistance) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.LightIntensity) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.ExtendedFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.Sid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.SceneryType) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Scenery.Material) = -1 then Exit(-1);
      if db_freadByte(stream, @proto^.Scenery.Field_34) = -1 then Exit(-1);
      if proto_read_scenery_data(@proto^.Scenery.Data, proto^.Scenery.SceneryType, stream) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_WALL:
    begin
      if db_freadInt32(stream, @proto^.Wall.LightDistance) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Wall.LightIntensity) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Wall.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Wall.ExtendedFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Wall.Sid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Wall.Material) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_TILE:
    begin
      if db_freadInt32(stream, @proto^.Tile.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Tile.ExtendedFlags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Tile.Sid) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Tile.Material) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_MISC:
    begin
      if db_freadInt32(stream, @proto^.Misc.LightDistance) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Misc.LightIntensity) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Misc.Flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @proto^.Misc.ExtendedFlags) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := -1;
end;

// 0x48F788
function proto_write_item_data(item_data: PItemProtoData; atype: Integer; stream: PDB_FILE): Integer;
begin
  case atype of
    ITEM_TYPE_ARMOR:
    begin
      if db_fwriteInt32(stream, item_data^.Armor.ArmorClass) = -1 then Exit(-1);
      if db_fwriteInt32List(stream, @item_data^.Armor.DamageResistance[0], 7) = -1 then Exit(-1);
      if db_fwriteInt32List(stream, @item_data^.Armor.DamageThreshold[0], 7) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Armor.Perk) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Armor.MaleFid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Armor.FemaleFid) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_CONTAINER:
    begin
      if db_fwriteInt32(stream, item_data^.Container.MaxSize) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Container.OpenFlags) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_DRUG:
    begin
      if db_fwriteInt32(stream, item_data^.Drug.Stat[0]) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.Stat[1]) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.Stat[2]) = -1 then Exit(-1);
      if db_fwriteInt32List(stream, @item_data^.Drug.Amount[0], 3) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.Duration1) = -1 then Exit(-1);
      if db_fwriteInt32List(stream, @item_data^.Drug.Amount1[0], 3) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.Duration2) = -1 then Exit(-1);
      if db_fwriteInt32List(stream, @item_data^.Drug.Amount2[0], 3) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.AddictionChance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.WithdrawalEffect) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Drug.WithdrawalOnset) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_WEAPON:
    begin
      if db_fwriteInt32(stream, item_data^.Weapon.AnimationCode) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.MaxDamage) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.MinDamage) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.DamageType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.MaxRange1) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.MaxRange2) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.ProjectilePid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.MinStrength) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.ActionPointCost1) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.ActionPointCost2) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.CriticalFailureType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.Perk) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.Rounds) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.Caliber) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.AmmoTypePid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Weapon.AmmoCapacity) = -1 then Exit(-1);
      if db_fwriteByte(stream, item_data^.Weapon.SoundCode) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_AMMO:
    begin
      if db_fwriteInt32(stream, item_data^.Ammo.Caliber) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Ammo.Quantity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Ammo.ArmorClassModifier) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Ammo.DamageResistanceModifier) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Ammo.DamageMultiplier) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Ammo.DamageDivisor) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_MISC:
    begin
      if db_fwriteInt32(stream, item_data^.Misc.PowerTypePid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Misc.PowerType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, item_data^.Misc.Charges) = -1 then Exit(-1);
      Exit(0);
    end;
    ITEM_TYPE_KEY:
    begin
      if db_fwriteInt32(stream, item_data^.Key.KeyCode) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := 0;
end;

// 0x48FADC
function proto_write_scenery_data(scenery_data: PSceneryProtoData; atype: Integer; stream: PDB_FILE): Integer;
begin
  case atype of
    SCENERY_TYPE_DOOR:
    begin
      if db_fwriteInt32(stream, scenery_data^.Door.OpenFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, scenery_data^.Door.KeyCode) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_STAIRS:
    begin
      if db_fwriteInt32(stream, scenery_data^.Stairs.Field_0) = -1 then Exit(-1);
      if db_fwriteInt32(stream, scenery_data^.Stairs.Field_4) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_ELEVATOR:
    begin
      if db_fwriteInt32(stream, scenery_data^.Elevator.ElevatorType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, scenery_data^.Elevator.Level) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_LADDER_UP, SCENERY_TYPE_LADDER_DOWN:
    begin
      if db_fwriteInt32(stream, scenery_data^.Ladder.Field_0) = -1 then Exit(-1);
      Exit(0);
    end;
    SCENERY_TYPE_GENERIC:
    begin
      if db_fwriteInt32(stream, scenery_data^.Generic.Field_0) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := 0;
end;

// 0x48FBAC
function proto_write_protoSubNode(proto: PProto; stream: PDB_FILE): Integer;
begin
  if db_fwriteInt32(stream, proto^.Pid) = -1 then Exit(-1);
  if db_fwriteInt32(stream, proto^.MessageId) = -1 then Exit(-1);
  if db_fwriteInt32(stream, proto^.Fid) = -1 then Exit(-1);

  case PID_TYPE(proto^.Pid) of
    OBJ_TYPE_ITEM:
    begin
      if db_fwriteInt32(stream, proto^.Item.LightDistance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.LightIntensity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.ExtendedFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Sid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.ItemType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Material) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Size) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Weight) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.Cost) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Item.InventoryFid) = -1 then Exit(-1);
      if db_fwriteByte(stream, proto^.Item.Field_80) = -1 then Exit(-1);
      if proto_write_item_data(@proto^.Item.Data, proto^.Item.ItemType, stream) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_CRITTER:
    begin
      if db_fwriteInt32(stream, proto^.Critter.LightDistance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.LightIntensity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.ExtendedFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.Sid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.HeadFid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.AiPacket) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Critter.Team) = -1 then Exit(-1);
      if critter_write_data(stream, @proto^.Critter.Data) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_SCENERY:
    begin
      if db_fwriteInt32(stream, proto^.Scenery.LightDistance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.LightIntensity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.ExtendedFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.Sid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.SceneryType) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Scenery.Material) = -1 then Exit(-1);
      if db_fwriteByte(stream, proto^.Scenery.Field_34) = -1 then Exit(-1);
      if proto_write_scenery_data(@proto^.Scenery.Data, proto^.Scenery.SceneryType, stream) = -1 then Exit(-1);
      // NOTE: C++ has fallthrough from SCENERY to WALL here - intentional bug preserved
    end;
    OBJ_TYPE_WALL:
    begin
      if db_fwriteInt32(stream, proto^.Wall.LightDistance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Wall.LightIntensity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Wall.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Wall.ExtendedFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Wall.Sid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Wall.Material) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_TILE:
    begin
      if db_fwriteInt32(stream, proto^.Tile.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Tile.ExtendedFlags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Tile.Sid) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Tile.Material) = -1 then Exit(-1);
      Exit(0);
    end;
    OBJ_TYPE_MISC:
    begin
      if db_fwriteInt32(stream, proto^.Misc.LightDistance) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Misc.LightIntensity) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Misc.Flags) = -1 then Exit(-1);
      if db_fwriteInt32(stream, proto^.Misc.ExtendedFlags) = -1 then Exit(-1);
      Exit(0);
    end;
  end;

  Result := -1;
end;

// 0x48FF28
function proto_save_pid(pid: Integer): Integer;
var
  proto: PProto;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  rc: Integer;
begin
  if proto_ptr(pid, @proto) = -1 then
    Exit(-1);

  proto_make_path(@path[0], pid);
  StrCat(@path[0], '\');

  proto_list_str(pid, @path[0] + StrLen(@path[0]));

  stream := db_fopen(@path[0], 'wb');
  if stream = nil then
    Exit(-1);

  rc := proto_write_protoSubNode(proto, stream);

  db_fclose(stream);

  Result := rc;
end;

// 0x490034
function proto_load_pid(pid: Integer; protoPtr: PPProto): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
begin
  proto_make_path(@path[0], pid);
  StrCat(@path[0], '\');

  if proto_list_str(pid, @path[0] + StrLen(@path[0])) = -1 then
    Exit(-1);

  stream := db_fopen(@path[0], 'rb');
  if stream = nil then
  begin
    debug_printf(#10'Error: Can''t fopen proto!'#10);
    protoPtr^ := nil;
    Exit(-1);
  end;

  if proto_find_free_subnode(PID_TYPE(pid), protoPtr) = -1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  if proto_read_protoSubNode(protoPtr^, stream) <> 0 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  db_fclose(stream);
  Result := 0;
end;

// 0x490190
function proto_find_free_subnode(atype: Integer; protoPtr: PPProto): Integer;
var
  size: SizeUInt;
  proto: PProto;
  protoList: PProtoList;
  protoListExtent: PProtoListExtent;
  newExtent: PProtoListExtent;
begin
  if (atype >= 0) and (atype < 11) then
    size := proto_sizes[atype]
  else
    size := 0;

  proto := PProto(mem_malloc(size));
  protoPtr^ := proto;
  if proto = nil then
    Exit(-1);

  protoList := @protolists[atype];
  protoListExtent := protoList^.Tail;

  if protoList^.Head <> nil then
  begin
    if protoListExtent^.Length = PROTO_LIST_EXTENT_SIZE then
    begin
      newExtent := PProtoListExtent(mem_malloc(SizeOf(TProtoListExtent)));
      protoListExtent^.Next := newExtent;
      if protoListExtent = nil then
      begin
        mem_free(proto);
        protoPtr^ := nil;
        Exit(-1);
      end;

      newExtent^.Length := 0;
      newExtent^.Next := nil;

      protoList^.Tail := newExtent;
      Inc(protoList^.Length);

      protoListExtent := newExtent;
    end;
  end
  else
  begin
    protoListExtent := PProtoListExtent(mem_malloc(SizeOf(TProtoListExtent)));
    if protoListExtent = nil then
    begin
      mem_free(proto);
      protoPtr^ := nil;
      Exit(-1);
    end;

    protoListExtent^.Next := nil;
    protoListExtent^.Length := 0;

    protoList^.Length := 1;
    protoList^.Tail := protoListExtent;
    protoList^.Head := protoListExtent;
  end;

  protoListExtent^.Proto[protoListExtent^.Length] := proto;
  Inc(protoListExtent^.Length);

  Result := 0;
end;

// 0x490438
procedure proto_remove_all;
var
  atype: Integer;
  protoList: PProtoList;
  curr, next_: PProtoListExtent;
  index: Integer;
begin
  for atype := 0 to 5 do
  begin
    protoList := @protolists[atype];

    curr := protoList^.Head;
    while curr <> nil do
    begin
      next_ := curr^.Next;
      for index := 0 to curr^.Length - 1 do
        mem_free(curr^.Proto[index]);
      mem_free(curr);
      curr := next_;
    end;

    protoList^.Head := nil;
    protoList^.Tail := nil;
    protoList^.Length := 0;
  end;
end;

// 0x4904AC
function proto_ptr(pid: Integer; protoPtr: PPProto): Integer;
var
  protoList: PProtoList;
  protoListExtent: PProtoListExtent;
  index: Integer;
  proto: PProto;
begin
  protoPtr^ := nil;

  if pid = -1 then
    Exit(-1);

  if pid = $1000000 then
  begin
    protoPtr^ := PProto(@pc_proto);
    Exit(0);
  end;

  protoList := @protolists[PID_TYPE(pid)];
  protoListExtent := protoList^.Head;
  while protoListExtent <> nil do
  begin
    for index := 0 to protoListExtent^.Length - 1 do
    begin
      proto := PProto(protoListExtent^.Proto[index]);
      if pid = proto^.Pid then
      begin
        protoPtr^ := proto;
        Exit(0);
      end;
    end;
    protoListExtent := protoListExtent^.Next;
  end;

  Result := proto_load_pid(pid, protoPtr);
end;

// 0x490530
function proto_new_id(a1: Integer): Integer;
begin
  Result := protolists[a1].MaxEntriesNum;
  Inc(protolists[a1].MaxEntriesNum);
end;

// 0x49054C
function proto_undo_new_id(atype: Integer): Integer;
begin
  Result := protolists[atype].MaxEntriesNum;
  Dec(protolists[atype].MaxEntriesNum);
end;

// 0x490568
function proto_max_id(a1: Integer): Integer;
begin
  Result := protolists[a1].MaxEntriesNum;
end;

// 0x490614
function ResetPlayer: Integer;
var
  proto: PProto;
begin
  proto_ptr(obj_dude^.Pid, @proto);

  stat_pc_set_defaults();
  stat_set_defaults(@proto^.Critter.Data);
  critter_reset();
  editor_reset();
  skill_set_defaults(@proto^.Critter.Data);
  skill_reset();
  perk_reset();
  trait_reset();
  stat_recalc_derived(obj_dude);
  Result := 0;
end;

initialization
  InitProtolists;
  InitProtoSizes;
  InitPcProto;
  InitProtoBlockingList;
  InitProtoPathBase;

end.
