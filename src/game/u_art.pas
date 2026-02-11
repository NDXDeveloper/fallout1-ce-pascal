{$MODE OBJFPC}{$H+}
// Converted from: src/game/art.h + art.cc
// Art/FRM resource management: loading, caching, frame access.
unit u_art;

interface

uses
  u_cache, u_object_types, u_proto_types;

const
  // Head
  HEAD_INVALID       = 0;
  HEAD_MARCUS        = 1;
  HEAD_MYRON         = 2;
  HEAD_ELDER         = 3;
  HEAD_LYNETTE       = 4;
  HEAD_HAROLD        = 5;
  HEAD_TANDI         = 6;
  HEAD_COM_OFFICER   = 7;
  HEAD_SULIK         = 8;
  HEAD_PRESIDENT     = 9;
  HEAD_HAKUNIN       = 10;
  HEAD_BOSS          = 11;
  HEAD_DYING_HAKUNIN = 12;
  HEAD_COUNT         = 13;

  // HeadAnimation
  HEAD_ANIMATION_VERY_GOOD_REACTION = 0;
  FIDGET_GOOD                       = 1;
  HEAD_ANIMATION_GOOD_TO_NEUTRAL    = 2;
  HEAD_ANIMATION_NEUTRAL_TO_GOOD    = 3;
  FIDGET_NEUTRAL                    = 4;
  HEAD_ANIMATION_NEUTRAL_TO_BAD     = 5;
  HEAD_ANIMATION_BAD_TO_NEUTRAL     = 6;
  FIDGET_BAD                        = 7;
  HEAD_ANIMATION_VERY_BAD_REACTION  = 8;
  HEAD_ANIMATION_GOOD_PHONEMES      = 9;
  HEAD_ANIMATION_NEUTRAL_PHONEMES   = 10;
  HEAD_ANIMATION_BAD_PHONEMES       = 11;

  // Background
  BACKGROUND_COUNT = 21;

  // WeaponAnimation
  WEAPON_ANIMATION_NONE         = 0;
  WEAPON_ANIMATION_KNIFE        = 1;
  WEAPON_ANIMATION_CLUB         = 2;
  WEAPON_ANIMATION_HAMMER       = 3;
  WEAPON_ANIMATION_SPEAR        = 4;
  WEAPON_ANIMATION_PISTOL       = 5;
  WEAPON_ANIMATION_SMG          = 6;
  WEAPON_ANIMATION_SHOTGUN      = 7;
  WEAPON_ANIMATION_LASER_RIFLE  = 8;
  WEAPON_ANIMATION_MINIGUN      = 9;
  WEAPON_ANIMATION_LAUNCHER     = 10;
  WEAPON_ANIMATION_COUNT        = 11;

  ROTATION_COUNT_ART = 6;

type
  PArt = ^TArt;
  TArt = packed record
    field_0: Integer;
    framesPerSecond: SmallInt;
    actionFrame: SmallInt;
    frameCount: SmallInt;
    xOffsets: array[0..5] of SmallInt;
    yOffsets: array[0..5] of SmallInt;
    dataOffsets: array[0..5] of Integer;
    padding: array[0..5] of Integer;
    dataSize: Integer;
  end;

  PArtFrame = ^TArtFrame;
  TArtFrame = packed record
    width: SmallInt;
    height: SmallInt;
    size: Integer;
    x: SmallInt;
    y: SmallInt;
  end;

  PHeadDescription = ^THeadDescription;
  THeadDescription = record
    goodFidgetCount: Integer;
    neutralFidgetCount: Integer;
    badFidgetCount: Integer;
  end;

var
  art_vault_guy_num: Integer;
  art_vault_person_nums: array[0..GENDER_COUNT - 1] of Integer;
  art_mapper_blank_tile: Integer;
  art_cache: TCache;
  head_info: PHeadDescription;

function art_init: Integer;
procedure art_reset;
procedure art_exit;
function art_dir(objectType: Integer): PAnsiChar;
function art_get_disable(objectType: Integer): Integer;
procedure art_toggle_disable(objectType: Integer);
function art_total(objectType: Integer): Integer;
function art_head_fidgets(headFid: Integer): Integer;
procedure scale_art(fid: Integer; dest: PByte; width, height, pitch: Integer);
function art_ptr_lock(fid: Integer; cache_entry: PPCacheEntry): PArt;
function art_ptr_lock_data(fid, frame, direction: Integer; handlePtr: PPCacheEntry): PByte;
function art_lock(fid: Integer; handlePtr: PPCacheEntry; widthPtr, heightPtr: PInteger): PByte;
function art_ptr_unlock(cache_entry: PCacheEntry): Integer;
function art_discard(fid: Integer): Integer;
function art_flush: Integer;
function art_get_base_name(objectType, id: Integer; dest: PAnsiChar): Integer;
function art_get_code(animation, weaponType: Integer; a3, a4: PAnsiChar): Integer;
function art_get_name(fid: Integer): PAnsiChar;
function art_read_lst(const path: PAnsiChar; artListPtr: PPAnsiChar; artListSizePtr: PInteger): Integer;
function art_frame_fps(a: PArt): Integer;
function art_frame_action_frame(a: PArt): Integer;
function art_frame_max_frame(a: PArt): Integer;
function art_frame_width(a: PArt; frame, direction: Integer): Integer;
function art_frame_length(a: PArt; frame, direction: Integer): Integer;
function art_frame_width_length(a: PArt; frame, direction: Integer; out_width, out_height: PInteger): Integer;
function art_frame_hot(a: PArt; frame, direction: Integer; xPtr, yPtr: PInteger): Integer;
function art_frame_offset(a: PArt; rotation: Integer; xPtr, yPtr: PInteger): Integer;
function art_frame_data(a: PArt; frame, direction: Integer): PByte;
function frame_ptr(a: PArt; frame, rotation: Integer): PArtFrame;
function art_exists(fid: Integer): Boolean;
function art_fid_valid(fid: Integer): Boolean;
function art_alias_num(index: Integer): Integer;
function art_alias_fid(fid: Integer): Integer;
function art_data_size(fid: Integer; out_size: PInteger): Integer; cdecl;
function art_data_load(fid: Integer; sizePtr: PInteger; data: PByte): Integer; cdecl;
procedure art_data_free(ptr: Pointer); cdecl;
function art_id(objectType, frmId, animType, a4, rotation: Integer): Integer;
function load_frame(const path: PAnsiChar): PArt;
function load_frame_into(const path: PAnsiChar; data: PByte): Integer;
function save_frame(const path: PAnsiChar; data: PByte): Integer;

implementation

uses
  SysUtils, u_gconfig, u_config, u_platform_compat, u_debug, u_grbuf, u_memory, u_db,
  u_proto, u_game;

// Animation type constants (from anim.h)
const
  ANIM_STAND = 0;
  ANIM_WALK = 1;
  ANIM_DODGE_ANIM = 13;
  ANIM_THROW_ANIM = 18;
  ANIM_FALL_BACK = 20;
  ANIM_ELECTRIFY = 27;
  ANIM_BURNED_TO_NOTHING = 29;
  ANIM_ELECTRIFIED_TO_NOTHING = 30;
  ANIM_FIRE_DANCE = 33;
  ANIM_FALL_FRONT_BLOOD = 35;
  ANIM_PRONE_TO_STANDING = 36;
  ANIM_BACK_TO_STANDING = 37;
  ANIM_TAKE_OUT = 38;
  ANIM_FIRE_CONTINUOUS = 47;
  ANIM_ELECTRIFY_SF = 55;
  ANIM_BURNED_TO_NOTHING_SF = 57;
  ANIM_ELECTRIFIED_TO_NOTHING_SF = 58;
  ANIM_FIRE_DANCE_SF = 61;
  ANIM_CALLED_SHOT_PIC = 64;
  FIRST_KNOCKDOWN_AND_DEATH_ANIM = 20;
  FIRST_SF_DEATH_ANIM = 48;

function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// cd_path_base imported from u_proto
// critter_db_handle imported from u_game

type
  TArtListDescription = record
    flags: Integer;
    dir: array[0..15] of AnsiChar;
    fileNames: PAnsiChar;
    fileNamesLength: Integer;
  end;

var
  art_list: array[0..OBJ_TYPE_COUNT - 1] of TArtListDescription;
  head1: PAnsiChar = 'gggnnnbbbgnb';
  head2: PAnsiChar = 'vfngfbnfvppp';
  art_name_buf: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  anon_alias: PInteger;

function art_readSubFrameData(data: PByte; stream: PDB_FILE; count: Integer; paddingPtr: PInteger): Integer; forward;
function art_readFrameData(a: PArt; stream: PDB_FILE): Integer; forward;
function art_writeSubFrameData(data: PByte; stream: PDB_FILE; count: Integer): Integer; forward;
function art_writeFrameData(a: PArt; stream: PDB_FILE): Integer; forward;
function artGetDataSize(a: PArt): Integer; forward;
function paddingForSize(size: Integer): Integer; forward;

procedure InitArtListDirs;
begin
  StrCopy(@art_list[0].dir[0], 'items');
  StrCopy(@art_list[1].dir[0], 'critters');
  StrCopy(@art_list[2].dir[0], 'scenery');
  StrCopy(@art_list[3].dir[0], 'walls');
  StrCopy(@art_list[4].dir[0], 'tiles');
  StrCopy(@art_list[5].dir[0], 'misc');
  StrCopy(@art_list[6].dir[0], 'intrface');
  StrCopy(@art_list[7].dir[0], 'inven');
  StrCopy(@art_list[8].dir[0], 'heads');
  StrCopy(@art_list[9].dir[0], 'backgrnd');
  StrCopy(@art_list[10].dir[0], 'skilldex');
end;

function art_init: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  str_buf: array[0..199] of AnsiChar;
  old_db_handle: Pointer;
  critter_db_selected: Boolean;
  cacheSize: Integer;
  objectType, critterIndex, tileIndex, headIndex: Integer;
  critterFileNames, tileFileNames: PAnsiChar;
  sep1, sep2, sep3, sep4: PAnsiChar;
begin
  InitArtListDirs;

  art_vault_guy_num := 0;
  art_mapper_blank_tile := 1;

  if not config_get_value(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_ART_CACHE_SIZE_KEY, @cacheSize) then
    cacheSize := 8;

  if not cache_init(@art_cache, @art_data_size, @art_data_load, @art_data_free, cacheSize shl 20) then
  begin
    debug_printf('cache_init failed in art_init'#10);
    Exit(-1);
  end;

  critter_db_selected := False;
  for objectType := 0 to OBJ_TYPE_COUNT - 1 do
  begin
    art_list[objectType].flags := 0;
    StrLFmt(@path[0], SizeOf(path) - 1, '%sart\%s\%s.lst',
      [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[objectType].dir[0]), PAnsiChar(@art_list[objectType].dir[0])]);

    old_db_handle := nil;
    if objectType = OBJ_TYPE_CRITTER then
    begin
      old_db_handle := db_current;
      critter_db_selected := True;
      db_select(critter_db_handle);
    end;

    if art_read_lst(@path[0], @art_list[objectType].fileNames, @art_list[objectType].fileNamesLength) <> 0 then
    begin
      debug_printf('art_read_lst failed in art_init'#10);
      if critter_db_selected then
        db_select(old_db_handle);
      cache_exit(@art_cache);
      Exit(-1);
    end;

    if objectType = OBJ_TYPE_CRITTER then
    begin
      critter_db_selected := False;
      db_select(old_db_handle);
    end;
  end;

  anon_alias := PInteger(mem_malloc(SizeOf(Integer) * art_list[OBJ_TYPE_CRITTER].fileNamesLength));
  if anon_alias = nil then
  begin
    art_list[OBJ_TYPE_CRITTER].fileNamesLength := 0;
    debug_printf('Out of memory for anon_alias in art_init'#10);
    cache_exit(@art_cache);
    Exit(-1);
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%sart\%s\%s.lst',
    [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_CRITTER].dir[0]), PAnsiChar(@art_list[OBJ_TYPE_CRITTER].dir[0])]);

  old_db_handle := db_current;
  db_select(critter_db_handle);

  stream := db_fopen(@path[0], 'rt');
  if stream = nil then
  begin
    debug_printf('Unable to open %s in art_init'#10, [PAnsiChar(@path[0])]);
    db_select(old_db_handle);
    cache_exit(@art_cache);
    Exit(-1);
  end;

  critterFileNames := art_list[OBJ_TYPE_CRITTER].fileNames;
  for critterIndex := 0 to art_list[OBJ_TYPE_CRITTER].fileNamesLength - 1 do
  begin
    if compat_stricmp(critterFileNames, 'hmjmps') = 0 then
      art_vault_person_nums[GENDER_MALE] := critterIndex
    else if compat_stricmp(critterFileNames, 'hfjmps') = 0 then
      art_vault_person_nums[GENDER_FEMALE] := critterIndex;

    critterFileNames := critterFileNames + 13;
  end;

  for critterIndex := 0 to art_list[OBJ_TYPE_CRITTER].fileNamesLength - 1 do
  begin
    if db_fgets(@str_buf[0], SizeOf(str_buf), stream) = nil then
      Break;

    sep1 := StrScan(@str_buf[0], ',');
    if sep1 <> nil then
      (anon_alias + critterIndex)^ := StrToIntDef(AnsiString(sep1 + 1), art_vault_guy_num)
    else
      (anon_alias + critterIndex)^ := art_vault_guy_num;
  end;

  db_fclose(stream);
  db_select(old_db_handle);

  tileFileNames := art_list[OBJ_TYPE_TILE].fileNames;
  for tileIndex := 0 to art_list[OBJ_TYPE_TILE].fileNamesLength - 1 do
  begin
    if compat_stricmp(tileFileNames, 'grid001.frm') = 0 then
      art_mapper_blank_tile := tileIndex;
    tileFileNames := tileFileNames + 13;
  end;

  head_info := PHeadDescription(mem_malloc(SizeOf(THeadDescription) * art_list[OBJ_TYPE_HEAD].fileNamesLength));
  if head_info = nil then
  begin
    art_list[OBJ_TYPE_HEAD].fileNamesLength := 0;
    debug_printf('Out of memory for head_info in art_init'#10);
    cache_exit(@art_cache);
    Exit(-1);
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%sart\%s\%s.lst',
    [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_HEAD].dir[0]), PAnsiChar(@art_list[OBJ_TYPE_HEAD].dir[0])]);

  stream := db_fopen(@path[0], 'rt');
  if stream = nil then
  begin
    debug_printf('Unable to open %s in art_init'#10, [PAnsiChar(@path[0])]);
    cache_exit(@art_cache);
    Exit(-1);
  end;

  for headIndex := 0 to art_list[OBJ_TYPE_HEAD].fileNamesLength - 1 do
  begin
    if db_fgets(@str_buf[0], SizeOf(str_buf), stream) = nil then
      Break;

    sep1 := StrScan(@str_buf[0], ',');
    if sep1 <> nil then
      sep1^ := #0
    else
      sep1 := @str_buf[0];

    sep2 := StrScan(sep1 + 1, ',');
    if sep2 <> nil then
      sep2^ := #0
    else
      sep2 := sep1;

    head_info[headIndex].goodFidgetCount := StrToIntDef(AnsiString(sep1 + 1), 0);

    sep3 := StrScan(sep2 + 1, ',');
    if sep3 <> nil then
      sep3^ := #0
    else
      sep3 := sep2;

    head_info[headIndex].neutralFidgetCount := StrToIntDef(AnsiString(sep2 + 1), 0);

    sep4 := StrScan(sep3 + 1, ' ');
    if sep4 = nil then sep4 := StrScan(sep3 + 1, ',');
    if sep4 = nil then sep4 := StrScan(sep3 + 1, ';');
    if sep4 = nil then sep4 := StrScan(sep3 + 1, #9);
    if sep4 = nil then sep4 := StrScan(sep3 + 1, #10);
    if sep4 <> nil then
      sep4^ := #0;

    head_info[headIndex].badFidgetCount := StrToIntDef(AnsiString(sep3 + 1), 0);
  end;

  db_fclose(stream);
  Result := 0;
end;

procedure art_reset;
begin
  // empty
end;

procedure art_exit;
var
  index: Integer;
begin
  cache_exit(@art_cache);

  mem_free(anon_alias);

  for index := 0 to OBJ_TYPE_COUNT - 1 do
  begin
    mem_free(art_list[index].fileNames);
    art_list[index].fileNames := nil;
  end;

  mem_free(head_info);
end;

function art_dir(objectType: Integer): PAnsiChar;
begin
  if (objectType >= OBJ_TYPE_ITEM) and (objectType < OBJ_TYPE_COUNT) then
    Result := @art_list[objectType].dir[0]
  else
    Result := nil;
end;

function art_get_disable(objectType: Integer): Integer;
begin
  if (objectType >= OBJ_TYPE_ITEM) and (objectType < OBJ_TYPE_COUNT) then
    Result := art_list[objectType].flags and 1
  else
    Result := 0;
end;

procedure art_toggle_disable(objectType: Integer);
begin
  if (objectType >= 0) and (objectType < OBJ_TYPE_COUNT) then
    art_list[objectType].flags := art_list[objectType].flags xor 1;
end;

function art_total(objectType: Integer): Integer;
begin
  if (objectType >= 0) and (objectType < OBJ_TYPE_COUNT) then
    Result := art_list[objectType].fileNamesLength
  else
    Result := 0;
end;

function art_head_fidgets(headFid: Integer): Integer;
var
  head, fidget: Integer;
  headDescription: PHeadDescription;
begin
  if FID_TYPE(headFid) <> OBJ_TYPE_HEAD then
    Exit(0);

  head := headFid and $FFF;

  if head > art_list[OBJ_TYPE_HEAD].fileNamesLength then
    Exit(0);

  headDescription := @head_info[head];

  fidget := (headFid and $FF0000) shr 16;
  case fidget of
    FIDGET_GOOD:    Result := headDescription^.goodFidgetCount;
    FIDGET_NEUTRAL: Result := headDescription^.neutralFidgetCount;
    FIDGET_BAD:     Result := headDescription^.badFidgetCount;
  else
    Result := 0;
  end;
end;

procedure scale_art(fid: Integer; dest: PByte; width, height, pitch: Integer);
var
  handle: PCacheEntry;
  frm: PArt;
  frameData: PByte;
  frameWidth, frameHeight: Integer;
  remainingWidth, remainingHeight: Integer;
begin
  frm := art_ptr_lock(fid, @handle);
  if frm = nil then
    Exit;

  frameData := art_frame_data(frm, 0, 0);
  frameWidth := art_frame_width(frm, 0, 0);
  frameHeight := art_frame_length(frm, 0, 0);

  remainingWidth := width - frameWidth;
  remainingHeight := height - frameHeight;
  if (remainingWidth < 0) or (remainingHeight < 0) then
  begin
    if height * frameWidth >= width * frameHeight then
    begin
      trans_cscale(frameData, frameWidth, frameHeight, frameWidth,
        dest + pitch * ((height - width * frameHeight div frameWidth) div 2),
        width, width * frameHeight div frameWidth, pitch);
    end
    else
    begin
      trans_cscale(frameData, frameWidth, frameHeight, frameWidth,
        dest + (width - height * frameWidth div frameHeight) div 2,
        height * frameWidth div frameHeight, height, pitch);
    end;
  end
  else
  begin
    trans_buf_to_buf(frameData, frameWidth, frameHeight, frameWidth,
      dest + pitch * (remainingHeight div 2) + remainingWidth div 2, pitch);
  end;

  art_ptr_unlock(handle);
end;

function art_ptr_lock(fid: Integer; cache_entry: PPCacheEntry): PArt;
var
  a: PArt;
begin
  if cache_entry = nil then
    Exit(nil);

  a := nil;
  cache_lock(@art_cache, fid, @a, cache_entry);
  Result := a;
end;

function art_ptr_lock_data(fid, frame, direction: Integer; handlePtr: PPCacheEntry): PByte;
var
  a: PArt;
  frm: PArtFrame;
begin
  a := nil;
  if handlePtr <> nil then
    cache_lock(@art_cache, fid, @a, handlePtr);

  if a <> nil then
  begin
    frm := frame_ptr(a, frame, direction);
    if frm <> nil then
      Exit(PByte(frm) + SizeOf(TArtFrame));
  end;

  Result := nil;
end;

function art_lock(fid: Integer; handlePtr: PPCacheEntry; widthPtr, heightPtr: PInteger): PByte;
var
  a: PArt;
begin
  handlePtr^ := nil;

  a := nil;
  cache_lock(@art_cache, fid, @a, handlePtr);

  if a = nil then
    Exit(nil);

  widthPtr^ := art_frame_width(a, 0, 0);
  if widthPtr^ = -1 then
    Exit(nil);

  heightPtr^ := art_frame_length(a, 0, 0);
  if heightPtr^ = -1 then
    Exit(nil);

  Result := art_frame_data(a, 0, 0);
end;

function art_ptr_unlock(cache_entry: PCacheEntry): Integer;
begin
  Result := Ord(cache_unlock(@art_cache, cache_entry));
end;

function art_flush: Integer;
begin
  Result := Ord(cache_flush(@art_cache));
end;

function art_discard(fid: Integer): Integer;
begin
  if cache_discard(@art_cache, fid) = 0 then
    Exit(-1);
  Result := 0;
end;

function art_get_base_name(objectType, id: Integer; dest: PAnsiChar): Integer;
var
  ptr: ^TArtListDescription;
begin
  if (objectType < OBJ_TYPE_ITEM) or (objectType >= OBJ_TYPE_COUNT) then
    Exit(-1);

  ptr := @art_list[objectType];

  if id >= ptr^.fileNamesLength then
    Exit(-1);

  StrCopy(dest, ptr^.fileNames + id * 13);
  Result := 0;
end;

function art_get_code(animation, weaponType: Integer; a3, a4: PAnsiChar): Integer;
begin
  if (weaponType < 0) or (weaponType >= WEAPON_ANIMATION_COUNT) then
    Exit(-1);

  if (animation >= ANIM_TAKE_OUT) and (animation <= ANIM_FIRE_CONTINUOUS) then
  begin
    a4^ := AnsiChar(Ord('c') + (animation - ANIM_TAKE_OUT));
    if weaponType = WEAPON_ANIMATION_NONE then
      Exit(-1);
    a3^ := AnsiChar(Ord('d') + (weaponType - 1));
    Exit(0);
  end
  else if animation = ANIM_PRONE_TO_STANDING then
  begin
    a4^ := 'h';
    a3^ := 'c';
    Exit(0);
  end
  else if animation = ANIM_BACK_TO_STANDING then
  begin
    a4^ := 'j';
    a3^ := 'c';
    Exit(0);
  end
  else if animation = ANIM_CALLED_SHOT_PIC then
  begin
    a4^ := 'a';
    a3^ := 'n';
    Exit(0);
  end
  else if animation >= FIRST_SF_DEATH_ANIM then
  begin
    a4^ := AnsiChar(Ord('a') + (animation - FIRST_SF_DEATH_ANIM));
    a3^ := 'r';
    Exit(0);
  end
  else if animation >= FIRST_KNOCKDOWN_AND_DEATH_ANIM then
  begin
    a4^ := AnsiChar(Ord('a') + (animation - FIRST_KNOCKDOWN_AND_DEATH_ANIM));
    a3^ := 'b';
    Exit(0);
  end
  else if animation = ANIM_THROW_ANIM then
  begin
    if weaponType = WEAPON_ANIMATION_KNIFE then
    begin
      a3^ := 'd';
      a4^ := 'm';
    end
    else if weaponType = WEAPON_ANIMATION_SPEAR then
    begin
      a3^ := 'g';
      a4^ := 'm';
    end
    else
    begin
      a3^ := 'a';
      a4^ := 's';
    end;
    Exit(0);
  end
  else if animation = ANIM_DODGE_ANIM then
  begin
    if weaponType <= 0 then
    begin
      a3^ := 'a';
      a4^ := 'n';
    end
    else
    begin
      a3^ := AnsiChar(Ord('d') + (weaponType - 1));
      a4^ := 'e';
    end;
    Exit(0);
  end;

  a4^ := AnsiChar(Ord('a') + animation);
  if (animation <= ANIM_WALK) and (weaponType > 0) then
  begin
    a3^ := AnsiChar(Ord('d') + (weaponType - 1));
    Exit(0);
  end;
  a3^ := 'a';
  Result := 0;
end;

var
  artNameDebug: Integer = 0;

function art_get_name(fid: Integer): PAnsiChar;
var
  alias_fid, index, anim, weapon_anim, objType, v1: Integer;
  code1, code2: AnsiChar;
begin
  v1 := (fid and $70000000) shr 28;

  alias_fid := art_alias_fid(fid);
  if alias_fid <> -1 then
    fid := alias_fid;

  art_name_buf[0] := #0;

  index := fid and $FFF;
  anim := FID_ANIM_TYPE(fid);
  weapon_anim := (fid and $F000) shr 12;
  objType := FID_TYPE(fid);

  if index >= art_list[objType].fileNamesLength then
  begin
    if (objType = OBJ_TYPE_CRITTER) and (artNameDebug < 3) then
    begin
      Inc(artNameDebug);
      WriteLn(StdErr, '[ART_NAME] index=', index, ' >= fileNamesLength=', art_list[objType].fileNamesLength, ' for fid=$', IntToHex(fid, 8));
    end;
    Exit(nil);
  end;

  if (objType < OBJ_TYPE_ITEM) or (objType >= OBJ_TYPE_COUNT) then
    Exit(nil);

  case objType of
    OBJ_TYPE_CRITTER:
    begin
      if art_get_code(anim, weapon_anim, @code1, @code2) = -1 then
        Exit(nil);

      if v1 <> 0 then
        StrLFmt(@art_name_buf[0], SizeOf(art_name_buf) - 1, '%sart\%s\%s%s%s.fr%s',
          [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_CRITTER].dir[0]),
           art_list[OBJ_TYPE_CRITTER].fileNames + index * 13,
           code1, code2, AnsiChar(v1 + 47)])
      else
        StrLFmt(@art_name_buf[0], SizeOf(art_name_buf) - 1, '%sart\%s\%s%s%s.frm',
          [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_CRITTER].dir[0]),
           art_list[OBJ_TYPE_CRITTER].fileNames + index * 13,
           code1, code2]);
    end;
    OBJ_TYPE_HEAD:
    begin
      if (head2 + anim)^ = 'f' then
        StrLFmt(@art_name_buf[0], SizeOf(art_name_buf) - 1, '%sart\%s\%s%s%s%d.frm',
          [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_HEAD].dir[0]),
           art_list[OBJ_TYPE_HEAD].fileNames + index * 13,
           (head1 + anim)^, (head2 + anim)^, weapon_anim])
      else
        StrLFmt(@art_name_buf[0], SizeOf(art_name_buf) - 1, '%sart\%s\%s%s%s.frm',
          [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[OBJ_TYPE_HEAD].dir[0]),
           art_list[OBJ_TYPE_HEAD].fileNames + index * 13,
           (head1 + anim)^, (head2 + anim)^]);
    end;
  else
    StrLFmt(@art_name_buf[0], SizeOf(art_name_buf) - 1, '%sart\%s\%s',
      [PAnsiChar(@cd_path_base[0]), PAnsiChar(@art_list[objType].dir[0]),
       art_list[objType].fileNames + index * 13]);
  end;

  Result := @art_name_buf[0];
end;

function art_read_lst(const path: PAnsiChar; artListPtr: PPAnsiChar; artListSizePtr: PInteger): Integer;
var
  stream: PDB_FILE;
  count: Integer;
  str_buf: array[0..199] of AnsiChar;
  artList, brk: PAnsiChar;
begin
  stream := db_fopen(path, 'rt');
  if stream = nil then
    Exit(-1);

  count := 0;
  while db_fgets(@str_buf[0], SizeOf(str_buf), stream) <> nil do
    Inc(count);

  db_fseek(stream, 0, 0); // SEEK_SET

  artListSizePtr^ := count;

  artList := PAnsiChar(mem_malloc(13 * count));
  artListPtr^ := artList;
  if artList = nil then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  while db_fgets(@str_buf[0], SizeOf(str_buf), stream) <> nil do
  begin
    brk := StrScan(@str_buf[0], ' ');
    if brk = nil then brk := StrScan(@str_buf[0], ',');
    if brk = nil then brk := StrScan(@str_buf[0], ';');
    if brk = nil then brk := StrScan(@str_buf[0], #13);
    if brk = nil then brk := StrScan(@str_buf[0], #9);
    if brk = nil then brk := StrScan(@str_buf[0], #10);
    if brk <> nil then
      brk^ := #0;

    StrLCopy(artList, @str_buf[0], 12);
    (artList + 12)^ := #0;

    artList := artList + 13;
  end;

  db_fclose(stream);
  Result := 0;
end;

function art_frame_fps(a: PArt): Integer;
begin
  if a = nil then
    Exit(10);
  if a^.framesPerSecond = 0 then
    Result := 10
  else
    Result := a^.framesPerSecond;
end;

function art_frame_action_frame(a: PArt): Integer;
begin
  if a = nil then Exit(-1);
  Result := a^.actionFrame;
end;

function art_frame_max_frame(a: PArt): Integer;
begin
  if a = nil then Exit(-1);
  Result := a^.frameCount;
end;

function art_frame_width(a: PArt; frame, direction: Integer): Integer;
var
  frm: PArtFrame;
begin
  frm := frame_ptr(a, frame, direction);
  if frm = nil then Exit(-1);
  Result := frm^.width;
end;

function art_frame_length(a: PArt; frame, direction: Integer): Integer;
var
  frm: PArtFrame;
begin
  frm := frame_ptr(a, frame, direction);
  if frm = nil then Exit(-1);
  Result := frm^.height;
end;

function art_frame_width_length(a: PArt; frame, direction: Integer; out_width, out_height: PInteger): Integer;
var
  frm: PArtFrame;
begin
  frm := frame_ptr(a, frame, direction);
  if frm = nil then
  begin
    if out_width <> nil then out_width^ := 0;
    if out_height <> nil then out_height^ := 0;
    Exit(-1);
  end;
  if out_width <> nil then out_width^ := frm^.width;
  if out_height <> nil then out_height^ := frm^.height;
  Result := 0;
end;

function art_frame_hot(a: PArt; frame, direction: Integer; xPtr, yPtr: PInteger): Integer;
var
  frm: PArtFrame;
begin
  frm := frame_ptr(a, frame, direction);
  if frm = nil then Exit(-1);
  xPtr^ := frm^.x;
  yPtr^ := frm^.y;
  Result := 0;
end;

function art_frame_offset(a: PArt; rotation: Integer; xPtr, yPtr: PInteger): Integer;
begin
  if a = nil then Exit(-1);
  xPtr^ := a^.xOffsets[rotation];
  yPtr^ := a^.yOffsets[rotation];
  Result := 0;
end;

function art_frame_data(a: PArt; frame, direction: Integer): PByte;
var
  frm: PArtFrame;
begin
  frm := frame_ptr(a, frame, direction);
  if frm = nil then Exit(nil);
  Result := PByte(frm) + SizeOf(TArtFrame);
end;

function frame_ptr(a: PArt; frame, rotation: Integer): PArtFrame;
var
  frm: PArtFrame;
  index: Integer;
begin
  if (rotation < 0) or (rotation >= 6) then Exit(nil);
  if a = nil then Exit(nil);
  if (frame < 0) or (frame >= a^.frameCount) then Exit(nil);

  frm := PArtFrame(PByte(a) + SizeOf(TArt) + a^.dataOffsets[rotation] + a^.padding[rotation]);
  for index := 0 to frame - 1 do
    frm := PArtFrame(PByte(frm) + SizeOf(TArtFrame) + frm^.size + paddingForSize(frm^.size));
  Result := frm;
end;

function art_exists(fid: Integer): Boolean;
var
  oldDb: Pointer;
  filePath: PAnsiChar;
  de: TDirEntry;
begin
  Result := False;
  oldDb := INVALID_DATABASE_HANDLE;

  if FID_TYPE(fid) = OBJ_TYPE_CRITTER then
  begin
    oldDb := db_current;
    db_select(critter_db_handle);
  end;

  filePath := art_get_name(fid);
  if filePath <> nil then
  begin
    if db_dir_entry(filePath, @de) <> -1 then
      Result := True;
  end;

  if oldDb <> INVALID_DATABASE_HANDLE then
    db_select(oldDb);
end;

function art_fid_valid(fid: Integer): Boolean;
var
  oldDb: Pointer;
  filePath: PAnsiChar;
  de: TDirEntry;
begin
  Result := False;
  oldDb := INVALID_DATABASE_HANDLE;

  if FID_TYPE(fid) = OBJ_TYPE_CRITTER then
  begin
    oldDb := db_current;
    db_select(critter_db_handle);
  end;

  filePath := art_get_name(fid);
  if filePath <> nil then
  begin
    if db_dir_entry(filePath, @de) <> -1 then
      Result := True;
  end;

  if oldDb <> INVALID_DATABASE_HANDLE then
    db_select(oldDb);
end;

function art_alias_num(index: Integer): Integer;
begin
  Result := (anon_alias + index)^;
end;

function art_alias_fid(fid: Integer): Integer;
var
  objType, anim: Integer;
begin
  objType := FID_TYPE(fid);
  anim := FID_ANIM_TYPE(fid);
  if objType = OBJ_TYPE_CRITTER then
  begin
    if (anim = ANIM_ELECTRIFY)
      or (anim = ANIM_BURNED_TO_NOTHING)
      or (anim = ANIM_ELECTRIFIED_TO_NOTHING)
      or (anim = ANIM_ELECTRIFY_SF)
      or (anim = ANIM_BURNED_TO_NOTHING_SF)
      or (anim = ANIM_ELECTRIFIED_TO_NOTHING_SF)
      or (anim = ANIM_FIRE_DANCE)
      or (anim = ANIM_CALLED_SHOT_PIC) then
    begin
      Exit((fid and $70000000) or ((anim shl 16) and $FF0000) or $1000000 or (fid and $F000) or ((anon_alias + (fid and $FFF))^ and $FFF));
    end;
  end;
  Result := -1;
end;

var
  artSizeDebug: Integer = 0;

function art_data_size(fid: Integer; out_size: PInteger): Integer; cdecl;
var
  oldDb: Pointer;
  artFilePath: PAnsiChar;
  stream: PDB_FILE;
  a: TArt;
  readResult: Integer;
begin
  Result := -1;
  oldDb := INVALID_DATABASE_HANDLE;

  if FID_TYPE(fid) = OBJ_TYPE_CRITTER then
  begin
    oldDb := db_current;
    db_select(critter_db_handle);
  end;

  artFilePath := art_get_name(fid);

  if artFilePath <> nil then
  begin
    stream := db_fopen(artFilePath, 'rb');

    if stream <> nil then
    begin
      readResult := art_readFrameData(@a, stream);
      if readResult = 0 then
      begin
        out_size^ := artGetDataSize(@a);
        Result := 0;
      end;
      db_fclose(stream);
    end
    else
    begin
      // Debug: show failed critter file opens
      if (FID_TYPE(fid) = OBJ_TYPE_CRITTER) and (artSizeDebug < 5) then
      begin
        Inc(artSizeDebug);
        WriteLn(StdErr, '[ART_SIZE] CRITTER db_fopen FAILED: ', artFilePath, ' fid=$', IntToHex(fid, 8), ' db=', PtrUInt(critter_db_handle));
      end;
    end;
  end
  else
  begin
    if (FID_TYPE(fid) = OBJ_TYPE_CRITTER) and (artSizeDebug < 5) then
    begin
      Inc(artSizeDebug);
      WriteLn(StdErr, '[ART_SIZE] art_get_name returned nil for critter fid=$', IntToHex(fid, 8));
    end;
  end;

  if oldDb <> INVALID_DATABASE_HANDLE then
    db_select(oldDb);
end;

function art_data_load(fid: Integer; sizePtr: PInteger; data: PByte): Integer; cdecl;
var
  oldDb: Pointer;
  artFileName: PAnsiChar;
  loadResult: Integer;
begin
  Result := -1;
  oldDb := INVALID_DATABASE_HANDLE;

  if FID_TYPE(fid) = OBJ_TYPE_CRITTER then
  begin
    oldDb := db_current;
    db_select(critter_db_handle);
    if critter_db_handle = nil then
      WriteLn(StdErr, '[ART] ERROR: critter_db_handle is nil for FID=$', IntToHex(fid, 8));
  end;

  artFileName := art_get_name(fid);
  if artFileName = nil then
  begin
    WriteLn(StdErr, '[ART] ERROR: art_get_name returned nil for FID=$', IntToHex(fid, 8));
  end
  else
  begin
    loadResult := load_frame_into(artFileName, data);
    if loadResult = 0 then
    begin
      sizePtr^ := artGetDataSize(PArt(data));
      Result := 0;
    end
    else
      WriteLn(StdErr, '[ART] ERROR: load_frame_into failed for file=', artFileName, ' FID=$', IntToHex(fid, 8), ' result=', loadResult);
  end;

  if oldDb <> INVALID_DATABASE_HANDLE then
    db_select(oldDb);
end;

procedure art_data_free(ptr: Pointer); cdecl;
begin
  mem_free(ptr);
end;

function art_id(objectType, frmId, animType, a4, rotation: Integer): Integer;
label zero, _out;
var
  v7, v8, v9, v10: Integer;
begin
  v10 := rotation;

  if objectType <> OBJ_TYPE_CRITTER then
    goto zero;

  if (animType = ANIM_FIRE_DANCE) or (animType < ANIM_FALL_BACK) or (animType > ANIM_FALL_FRONT_BLOOD) then
    goto zero;

  v7 := ((a4 shl 12) and $F000) or ((animType shl 16) and $FF0000) or $1000000;
  v8 := ((rotation shl 28) and $70000000) or v7;
  v9 := frmId and $FFF;

  if art_exists(v9 or v8) then
    goto _out;

  if objectType = rotation then
    goto zero;

  v10 := objectType;
  if art_exists(v9 or v7 or $10000000) then
    goto _out;

zero:
  v10 := 0;

_out:
  Result := ((v10 shl 28) and $70000000) or (objectType shl 24) or ((animType shl 16) and $FF0000) or ((a4 shl 12) and $F000) or (frmId and $FFF);
end;

function art_readSubFrameData(data: PByte; stream: PDB_FILE; count: Integer; paddingPtr: PInteger): Integer;
var
  ptr: PByte;
  pad, index: Integer;
  frm: PArtFrame;
begin
  ptr := data;
  pad := 0;
  for index := 0 to count - 1 do
  begin
    frm := PArtFrame(ptr);

    if db_freadInt16(stream, @frm^.width) = -1 then Exit(-1);
    if db_freadInt16(stream, @frm^.height) = -1 then Exit(-1);
    if db_freadInt32(stream, @frm^.size) = -1 then Exit(-1);
    if db_freadInt16(stream, @frm^.x) = -1 then Exit(-1);
    if db_freadInt16(stream, @frm^.y) = -1 then Exit(-1);
    if db_fread(ptr + SizeOf(TArtFrame), frm^.size, 1, stream) <> 1 then Exit(-1);

    ptr := ptr + SizeOf(TArtFrame) + frm^.size;
    ptr := ptr + paddingForSize(frm^.size);
    pad := pad + paddingForSize(frm^.size);
  end;

  paddingPtr^ := pad;
  Result := 0;
end;

function art_readFrameData(a: PArt; stream: PDB_FILE): Integer;
begin
  if db_freadInt32(stream, @a^.field_0) = -1 then Exit(-1);
  if db_freadInt16(stream, @a^.framesPerSecond) = -1 then Exit(-1);
  if db_freadInt16(stream, @a^.actionFrame) = -1 then Exit(-1);
  if db_freadInt16(stream, @a^.frameCount) = -1 then Exit(-1);
  if db_freadInt16List(stream, @a^.xOffsets[0], 6) = -1 then Exit(-1);
  if db_freadInt16List(stream, @a^.yOffsets[0], 6) = -1 then Exit(-1);
  if db_freadInt32List(stream, @a^.dataOffsets[0], 6) = -1 then Exit(-1);
  if db_freadInt32(stream, @a^.dataSize) = -1 then Exit(-1);
  Result := 0;
end;

function load_frame(const path: PAnsiChar): PArt;
var
  stream: PDB_FILE;
  header: TArt;
  data: PByte;
begin
  stream := db_fopen(path, 'rb');
  if stream = nil then
    Exit(nil);

  if art_readFrameData(@header, stream) <> 0 then
  begin
    db_fclose(stream);
    Exit(nil);
  end;

  db_fclose(stream);

  data := PByte(mem_malloc(artGetDataSize(@header)));
  if data = nil then
    Exit(nil);

  if load_frame_into(path, data) <> 0 then
  begin
    mem_free(data);
    Exit(nil);
  end;

  Result := PArt(data);
end;

function load_frame_into(const path: PAnsiChar; data: PByte): Integer;
var
  stream: PDB_FILE;
  a: PArt;
  currentPadding, previousPadding: Integer;
  index: Integer;
begin
  stream := db_fopen(path, 'rb');
  if stream = nil then
    Exit(-2);

  a := PArt(data);
  if art_readFrameData(a, stream) <> 0 then
  begin
    db_fclose(stream);
    Exit(-3);
  end;

  currentPadding := paddingForSize(SizeOf(TArt));
  previousPadding := 0;

  for index := 0 to 5 do
  begin
    a^.padding[index] := currentPadding;

    if (index = 0) or (a^.dataOffsets[index - 1] <> a^.dataOffsets[index]) then
    begin
      a^.padding[index] := a^.padding[index] + previousPadding;
      currentPadding := currentPadding + previousPadding;
      if art_readSubFrameData(data + SizeOf(TArt) + a^.dataOffsets[index] + a^.padding[index], stream, a^.frameCount, @previousPadding) <> 0 then
      begin
        db_fclose(stream);
        Exit(-5);
      end;
    end;
  end;

  db_fclose(stream);
  Result := 0;
end;

function art_writeSubFrameData(data: PByte; stream: PDB_FILE; count: Integer): Integer;
var
  ptr: PByte;
  index: Integer;
  frm: PArtFrame;
begin
  ptr := data;
  for index := 0 to count - 1 do
  begin
    frm := PArtFrame(ptr);

    if db_fwriteInt16(stream, frm^.width) = -1 then Exit(-1);
    if db_fwriteInt16(stream, frm^.height) = -1 then Exit(-1);
    if db_fwriteInt32(stream, frm^.size) = -1 then Exit(-1);
    if db_fwriteInt16(stream, frm^.x) = -1 then Exit(-1);
    if db_fwriteInt16(stream, frm^.y) = -1 then Exit(-1);
    if db_fwrite(ptr + SizeOf(TArtFrame), frm^.size, 1, stream) <> 1 then Exit(-1);

    ptr := ptr + SizeOf(TArtFrame) + frm^.size;
    ptr := ptr + paddingForSize(frm^.size);
  end;
  Result := 0;
end;

function art_writeFrameData(a: PArt; stream: PDB_FILE): Integer;
begin
  if db_fwriteInt32(stream, a^.field_0) = -1 then Exit(-1);
  if db_fwriteInt16(stream, a^.framesPerSecond) = -1 then Exit(-1);
  if db_fwriteInt16(stream, a^.actionFrame) = -1 then Exit(-1);
  if db_fwriteInt16(stream, a^.frameCount) = -1 then Exit(-1);
  if db_fwriteInt16List(stream, @a^.xOffsets[0], 6) = -1 then Exit(-1);
  if db_fwriteInt16List(stream, @a^.yOffsets[0], 6) = -1 then Exit(-1);
  if db_fwriteInt32List(stream, @a^.dataOffsets[0], 6) = -1 then Exit(-1);
  if db_fwriteInt32(stream, a^.dataSize) = -1 then Exit(-1);
  Result := 0;
end;

function save_frame(const path: PAnsiChar; data: PByte): Integer;
var
  stream: PDB_FILE;
  a: PArt;
  index: Integer;
begin
  if data = nil then
    Exit(-1);

  stream := db_fopen(path, 'wb');
  if stream = nil then
    Exit(-1);

  a := PArt(data);
  if art_writeFrameData(a, stream) = -1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  for index := 0 to 5 do
  begin
    if (index = 0) or (a^.dataOffsets[index - 1] <> a^.dataOffsets[index]) then
    begin
      if art_writeSubFrameData(data + SizeOf(TArt) + a^.dataOffsets[index], stream, a^.frameCount) <> 0 then
      begin
        db_fclose(stream);
        Exit(-1);
      end;
    end;
  end;

  db_fclose(stream);
  Result := 0;
end;

function artGetDataSize(a: PArt): Integer;
var
  dataSize, index: Integer;
begin
  dataSize := SizeOf(TArt) + a^.dataSize;

  for index := 0 to 5 do
  begin
    if (index = 0) or (a^.dataOffsets[index - 1] <> a^.dataOffsets[index]) then
      dataSize := dataSize + (SizeOf(Integer) - 1) * a^.frameCount;
  end;

  Result := dataSize;
end;

function paddingForSize(size: Integer): Integer;
begin
  Result := (SizeOf(Integer) - size mod SizeOf(Integer)) mod SizeOf(Integer);
end;

end.
