{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/anim.h + anim.cc
// Animation system: registration, sequencing, pathfinding, and playback.
unit u_anim;

interface

uses
  u_object_types, u_rect;

// ---------------------------------------------------------------------------
// AnimationRequestOptions
// ---------------------------------------------------------------------------
const
  ANIMATION_REQUEST_UNRESERVED   = $01;
  ANIMATION_REQUEST_RESERVED     = $02;
  ANIMATION_REQUEST_NO_STAND     = $04;
  ANIMATION_REQUEST_0x100        = $100;
  ANIMATION_REQUEST_INSIGNIFICANT = $200;

// ---------------------------------------------------------------------------
// AnimationType constants (65 values)
// ---------------------------------------------------------------------------
const
  ANIM_STAND                     = 0;
  ANIM_WALK                      = 1;
  ANIM_JUMP_BEGIN                = 2;
  ANIM_JUMP_END                  = 3;
  ANIM_CLIMB_LADDER              = 4;
  ANIM_FALLING                   = 5;
  ANIM_UP_STAIRS_RIGHT           = 6;
  ANIM_UP_STAIRS_LEFT            = 7;
  ANIM_DOWN_STAIRS_RIGHT         = 8;
  ANIM_DOWN_STAIRS_LEFT          = 9;
  ANIM_MAGIC_HANDS_GROUND        = 10;
  ANIM_MAGIC_HANDS_MIDDLE        = 11;
  ANIM_MAGIC_HANDS_UP            = 12;
  ANIM_DODGE_ANIM                = 13;
  ANIM_HIT_FROM_FRONT            = 14;
  ANIM_HIT_FROM_BACK             = 15;
  ANIM_THROW_PUNCH               = 16;
  ANIM_KICK_LEG                  = 17;
  ANIM_THROW_ANIM                = 18;
  ANIM_RUNNING                   = 19;
  ANIM_FALL_BACK                 = 20;
  ANIM_FALL_FRONT                = 21;
  ANIM_BAD_LANDING               = 22;
  ANIM_BIG_HOLE                  = 23;
  ANIM_CHARRED_BODY              = 24;
  ANIM_CHUNKS_OF_FLESH           = 25;
  ANIM_DANCING_AUTOFIRE          = 26;
  ANIM_ELECTRIFY                 = 27;
  ANIM_SLICED_IN_HALF            = 28;
  ANIM_BURNED_TO_NOTHING         = 29;
  ANIM_ELECTRIFIED_TO_NOTHING    = 30;
  ANIM_EXPLODED_TO_NOTHING       = 31;
  ANIM_MELTED_TO_NOTHING         = 32;
  ANIM_FIRE_DANCE                = 33;
  ANIM_FALL_BACK_BLOOD           = 34;
  ANIM_FALL_FRONT_BLOOD          = 35;
  ANIM_PRONE_TO_STANDING         = 36;
  ANIM_BACK_TO_STANDING          = 37;
  ANIM_TAKE_OUT                  = 38;
  ANIM_PUT_AWAY                  = 39;
  ANIM_PARRY_ANIM                = 40;
  ANIM_THRUST_ANIM               = 41;
  ANIM_SWING_ANIM                = 42;
  ANIM_POINT                     = 43;
  ANIM_UNPOINT                   = 44;
  ANIM_FIRE_SINGLE               = 45;
  ANIM_FIRE_BURST                = 46;
  ANIM_FIRE_CONTINUOUS            = 47;
  ANIM_FALL_BACK_SF              = 48;
  ANIM_FALL_FRONT_SF             = 49;
  ANIM_BAD_LANDING_SF            = 50;
  ANIM_BIG_HOLE_SF               = 51;
  ANIM_CHARRED_BODY_SF           = 52;
  ANIM_CHUNKS_OF_FLESH_SF        = 53;
  ANIM_DANCING_AUTOFIRE_SF       = 54;
  ANIM_ELECTRIFY_SF              = 55;
  ANIM_SLICED_IN_HALF_SF         = 56;
  ANIM_BURNED_TO_NOTHING_SF      = 57;
  ANIM_ELECTRIFIED_TO_NOTHING_SF = 58;
  ANIM_EXPLODED_TO_NOTHING_SF    = 59;
  ANIM_MELTED_TO_NOTHING_SF      = 60;
  ANIM_FIRE_DANCE_SF             = 61;
  ANIM_FALL_BACK_BLOOD_SF        = 62;
  ANIM_FALL_FRONT_BLOOD_SF       = 63;
  ANIM_CALLED_SHOT_PIC           = 64;
  ANIM_COUNT                     = 65;

  FIRST_KNOCKDOWN_AND_DEATH_ANIM = ANIM_FALL_BACK;
  LAST_KNOCKDOWN_AND_DEATH_ANIM  = ANIM_FALL_FRONT_BLOOD;
  FIRST_SF_DEATH_ANIM            = ANIM_FALL_BACK_SF;
  LAST_SF_DEATH_ANIM             = ANIM_FALL_FRONT_BLOOD_SF;

// ---------------------------------------------------------------------------
// FID_ANIM_TYPE macro
// ---------------------------------------------------------------------------
function FID_ANIM_TYPE(value: Integer): Integer; inline;

// ---------------------------------------------------------------------------
// Callback types
// ---------------------------------------------------------------------------
type
  TAnimationCallback  = function(a1, a2: Pointer): Integer; cdecl;
  PAnimationCallback  = ^TAnimationCallback;
  TAnimationCallback3 = function(a1, a2, a3: Pointer): Integer; cdecl;
  PAnimationCallback3 = ^TAnimationCallback3;

  TPathBuilderCallback = function(obj: PObject; tile, elevation: Integer): PObject; cdecl;
  PPathBuilderCallback = ^TPathBuilderCallback;

// ---------------------------------------------------------------------------
// StraightPathNode
// ---------------------------------------------------------------------------
type
  PStraightPathNode = ^TStraightPathNode;
  TStraightPathNode = record
    tile: Integer;
    elevation: Integer;
    x: Integer;
    y: Integer;
  end;

// ---------------------------------------------------------------------------
// Public functions (from anim.h)
// ---------------------------------------------------------------------------
procedure anim_init;
procedure anim_reset;
procedure anim_exit;
function register_begin(requestOptions: Integer): Integer;
function register_priority(a1: Integer): Integer;
function register_clear(a1: PObject): Integer;
function register_end: Integer;
function check_registry(obj: PObject): Integer;
function anim_busy(a1: PObject): Integer;
function register_object_move_to_object(owner, destination: PObject; actionPoints, delay: Integer): Integer;
function register_object_run_to_object(owner, destination: PObject; actionPoints, delay: Integer): Integer;
function register_object_move_to_tile(owner: PObject; tile, elevation, actionPoints, delay: Integer): Integer;
function register_object_run_to_tile(owner: PObject; tile, elevation, actionPoints, delay: Integer): Integer;
function register_object_move_straight_to_tile(obj: PObject; tile, elevation, anim, delay: Integer): Integer;
function register_object_animate_and_move_straight(owner: PObject; tile, elev, anim, delay: Integer): Integer;
function register_object_move_on_stairs(owner, stairs: PObject; delay: Integer): Integer;
function register_object_check_falling(owner: PObject; delay: Integer): Integer;
function register_object_animate(owner: PObject; anim, delay: Integer): Integer;
function register_object_animate_reverse(owner: PObject; anim, delay: Integer): Integer;
function register_object_animate_and_hide(owner: PObject; anim, delay: Integer): Integer;
function register_object_turn_towards(owner: PObject; tile: Integer): Integer;
function register_object_inc_rotation(owner: PObject): Integer;
function register_object_dec_rotation(owner: PObject): Integer;
function register_object_erase(obj: PObject): Integer;
function register_object_must_erase(obj: PObject): Integer;
function register_object_call(a1, a2: Pointer; proc: TAnimationCallback; delay: Integer): Integer;
function register_object_call3(a1, a2, a3: Pointer; proc: TAnimationCallback3; delay: Integer): Integer;
function register_object_must_call(a1, a2: Pointer; proc: TAnimationCallback; delay: Integer): Integer;
function register_object_fset(obj: PObject; flag, delay: Integer): Integer;
function register_object_funset(obj: PObject; flag, delay: Integer): Integer;
function register_object_flatten(obj: PObject; delay: Integer): Integer;
function register_object_change_fid(owner: PObject; fid, delay: Integer): Integer;
function register_object_take_out(owner: PObject; weaponAnimationCode, delay: Integer): Integer;
function register_object_light(owner: PObject; lightDistance, delay: Integer): Integer;
function register_object_outline(obj: PObject; outline: Boolean; delay: Integer): Integer;
function register_object_play_sfx(owner: PObject; soundEffectName: PAnsiChar; delay: Integer): Integer;
function register_object_animate_forever(owner: PObject; anim, delay: Integer): Integer;
function register_ping(a1, a2: Integer): Integer;
function make_path(obj: PObject; from_, to_: Integer; a4: PByte; a5: Integer): Integer;
function make_path_func(obj: PObject; from_, to_: Integer; rotations: PByte; a5: Integer; callback: TPathBuilderCallback): Integer;
function idist(a1, a2, a3, a4: Integer): Integer;
function EST(tile1, tile2: Integer): Integer;
function make_straight_path(a1: PObject; from_, to_: Integer; pathNodes: PStraightPathNode; a5: PPObject; a6: Integer): Integer;
function make_straight_path_func(a1: PObject; from_, to_: Integer; pathNodes: PStraightPathNode; a5: PPObject; a6: Integer; callback: TPathBuilderCallback): Integer;
function anim_move_on_stairs(obj: PObject; tile, elevation, anim, animationSequenceIndex: Integer): Integer;
function check_for_falling(obj: PObject; anim, a3: Integer): Integer;
procedure object_animate;
function check_move(a1: PInteger): Integer;
function dude_move(a1: Integer): Integer;
function dude_run(a1: Integer): Integer;
procedure dude_fidget;
procedure dude_stand(obj: PObject; rotation, fid: Integer);
procedure dude_standup(a1: PObject);
function anim_hide(obj: PObject; animationSequenceIndex: Integer): Integer;
function anim_change_fid(obj: PObject; animationSequenceIndex, fid: Integer): Integer;
procedure anim_stop;
function compute_tpf(obj: PObject; fid: Integer): LongWord;

implementation

uses
  SysUtils, u_debug, u_input, u_config, u_gconfig, u_map_defs, u_cache,
  u_kb, u_mouse, u_svga, u_sdl2, u_vcr,
  u_art, u_combat, u_critter, u_gsound, u_int_sound, u_intface, u_item,
  u_object, u_perk, u_proto, u_protinst, u_roll, u_scripts,
  u_stat, u_tile, u_map, u_game, u_proto_types;


// ---------------------------------------------------------------------------
// Constants from other modules needed locally
// ---------------------------------------------------------------------------
const
  // critter.h
  PC_FLAG_SNEAKING = 0;

  // perk_defs.h
  PERK_SILENT_RUNNING = 15;

  // proto_types.h
  BODY_TYPE_BIPED    = 0;
  BODY_TYPE_ROBOTIC  = 2;
  SCENERY_TYPE_DOOR  = 0;

  // gsound.h
  CHARACTER_SOUND_EFFECT_UNUSED = 0;

  // stat_defs.h
  STAT_PERCEPTION = 1;

// =========================================================================
// Internal constants
// =========================================================================
const
  ANIMATION_SEQUENCE_LIST_CAPACITY    = 21;
  ANIMATION_DESCRIPTION_LIST_CAPACITY = 40;
  ANIMATION_SAD_LIST_CAPACITY         = 16;

  ANIMATION_SEQUENCE_FORCED = $01;

// ---------------------------------------------------------------------------
// AnimationKind (internal enum)
// ---------------------------------------------------------------------------
const
  ANIM_KIND_MOVE_TO_OBJECT                           = 0;
  ANIM_KIND_MOVE_TO_TILE                             = 1;
  ANIM_KIND_MOVE_TO_TILE_STRAIGHT                    = 2;
  ANIM_KIND_MOVE_TO_TILE_STRAIGHT_AND_WAIT_FOR_COMPLETE = 3;
  ANIM_KIND_ANIMATE                                  = 4;
  ANIM_KIND_ANIMATE_REVERSED                         = 5;
  ANIM_KIND_ANIMATE_AND_HIDE                         = 6;
  ANIM_KIND_ROTATE_TO_TILE                           = 7;
  ANIM_KIND_ROTATE_CLOCKWISE                         = 8;
  ANIM_KIND_ROTATE_COUNTER_CLOCKWISE                 = 9;
  ANIM_KIND_HIDE                                     = 10;
  ANIM_KIND_CALLBACK                                 = 11;
  ANIM_KIND_CALLBACK3                                = 12;
  ANIM_KIND_SET_FLAG                                 = 14;
  ANIM_KIND_UNSET_FLAG                               = 15;
  ANIM_KIND_TOGGLE_FLAT                              = 16;
  ANIM_KIND_SET_FID                                  = 17;
  ANIM_KIND_TAKE_OUT_WEAPON                          = 18;
  ANIM_KIND_SET_LIGHT_DISTANCE                       = 19;
  ANIM_KIND_MOVE_ON_STAIRS                           = 20;
  ANIM_KIND_CHECK_FALLING                            = 23;
  ANIM_KIND_TOGGLE_OUTLINE                           = 24;
  ANIM_KIND_ANIMATE_FOREVER                          = 25;
  ANIM_KIND_26                                       = 26;
  ANIM_KIND_27                                       = 27;
  ANIM_KIND_NOOP                                     = 28;

// ---------------------------------------------------------------------------
// AnimationSequenceFlags
// ---------------------------------------------------------------------------
const
  ANIM_SEQ_PRIORITIZED         = $01;
  ANIM_SEQ_COMBAT_ANIM_STARTED = $02;
  ANIM_SEQ_RESERVED            = $04;
  ANIM_SEQ_ACCUMULATING        = $08;
  ANIM_SEQ_0x10                = $10;
  ANIM_SEQ_0x20                = $20;
  ANIM_SEQ_INSIGNIFICANT       = $40;
  ANIM_SEQ_NO_STAND            = $80;

// ---------------------------------------------------------------------------
// AnimationSadFlags
// ---------------------------------------------------------------------------
const
  ANIM_SAD_REVERSE              = $01;
  ANIM_SAD_STRAIGHT             = $02;
  ANIM_SAD_NO_ANIM              = $04;
  ANIM_SAD_WAIT_FOR_COMPLETION  = $10;
  ANIM_SAD_0x20                 = $20;
  ANIM_SAD_HIDE_ON_END          = $40;
  ANIM_SAD_FOREVER              = $80;

// =========================================================================
// Internal record types
// =========================================================================
type
  PAnimationDescription = ^TAnimationDescription;
  TAnimationDescription = record
    kind: Integer;
    case Integer of
      0: (
        owner: PObject;    // or param2 for callbacks
        destination: PObject; // or param1 for callbacks
        // union: tile/elevation or fid or weaponAnimationCode or lightDistance or outline
        tile_or_fid: Integer;
        elevation_or_pad: Integer;
        anim: Integer;
        delay: Integer;
        callback: TAnimationCallback;
        callback3: TAnimationCallback3;
        objectFlag_or_extendedFlags: LongWord;
        actionPoints_or_seqIndex: Integer; // or param3
        artCacheKey: PCacheEntry;
      );
  end;

  // We use an untyped overlay approach. Due to the complex C unions
  // we access fields via helper functions and direct pointer offsets.

  // Redefine using a flat record with explicit field offsets matching
  // the C layout. The C struct has these fields at these conceptual offsets:
  //   kind: 0
  //   owner/param2: 4 (pointer)
  //   destination/param1: 8 (pointer)
  //   tile/fid/weaponAnimationCode/lightDistance/outline: 12
  //   elevation: 16
  //   anim: 20
  //   delay: 24
  //   callback: 28 (pointer)
  //   callback3: 32 (pointer)
  //   objectFlag/extendedFlags: 36
  //   actionPoints/animationSequenceIndex/param3: 40
  //   artCacheKey: 44 (pointer)

  // Since Pascal variant records are cumbersome for this, we define a clean
  // record and access union members through the same field names, relying
  // on them being at the same offset.
  TAnimDesc = record
    kind: Integer;
    owner: PObject;        // also param2 for CALLBACK types
    destination: PObject;  // also param1 for CALLBACK types
    tile: Integer;         // also fid, weaponAnimationCode, lightDistance; outline as Integer
    elevation: Integer;    // second word of tile/elevation union
    anim: Integer;
    delay: Integer;
    callback: TAnimationCallback;
    callback3: TAnimationCallback3;
    objectFlag: LongWord;  // also extendedFlags
    actionPoints: Integer; // also animationSequenceIndex, param3
    artCacheKey: PCacheEntry;
  end;
  PAnimDesc = ^TAnimDesc;

  PAnimationSequence = ^TAnimationSequence;
  TAnimationSequence = record
    field_0: Integer;
    animationIndex: Integer;
    length: Integer;
    flags: LongWord;
    animations: array[0..ANIMATION_DESCRIPTION_LIST_CAPACITY - 1] of TAnimDesc;
  end;

  PPathNode = ^TPathNode;
  TPathNode = record
    tile: Integer;
    from_: Integer;
    rotation: Integer;
    field_C: Integer;
    field_10: Integer;
  end;

  PAnimationSad = ^TAnimationSad;
  TAnimationSad = record
    flags: LongWord;
    obj: PObject;
    fid: Integer;
    anim: Integer;
    animationTimestamp: LongWord;
    ticksPerFrame: LongWord;
    animationSequenceIndex: Integer;
    field_1C: Integer;
    field_20: Integer;
    field_24: Integer;
    case Integer of
      0: (rotations: array[0..3199] of Byte);
      1: (field_28: array[0..199] of TStraightPathNode);
  end;

// =========================================================================
// Forward declarations (internal)
// =========================================================================
function anim_free_slot(requestOptions: Integer): Integer; forward;
function anim_preload(obj: PObject; fid: Integer; cacheEntryPtr: PPCacheEntry): Integer; forward;
procedure anim_cleanup; forward;
function anim_set_check(animationSequenceIndex: Integer): Integer; forward;
function anim_set_continue(animationSequenceIndex, a2: Integer): Integer; forward;
function anim_set_end(animationSequenceIndex: Integer): Integer; forward;
function anim_can_use_door(critter, door: PObject): Boolean; forward;
function anim_move_to_object(from_, to_: PObject; a3, anim, animationSequenceIndex: Integer): Integer; forward;
function make_stair_path(obj: PObject; from_, fromElevation, to_, toElevation: Integer; a6: PStraightPathNode; obstaclePtr: PPObject): Integer; forward;
function anim_move_to_tile(obj: PObject; tile_num_, elev, a4, anim, animationSequenceIndex: Integer): Integer; forward;
function anim_move(obj: PObject; tile, elev, a3, anim, a5, animationSequenceIndex: Integer): Integer; forward;
function anim_move_straight_to_tile(obj: PObject; tile, elevation, anim, animationSequenceIndex, flags: Integer): Integer; forward;
procedure object_move(index: Integer); forward;
procedure object_straight_move(index: Integer); forward;
function anim_animate(obj: PObject; anim, animationSequenceIndex, flags: Integer): Integer; forward;
procedure object_anim_compact; forward;
function anim_turn_towards(obj: PObject; delta, animationSequenceIndex: Integer): Integer; forward;
function check_gravity(tile, elevation: Integer): Integer; forward;

// =========================================================================
// Static (unit-level) variables
// =========================================================================
var
  curr_sad: Integer = 0;
  curr_anim_set: Integer = -1;
  anim_in_init: Boolean = False;
  anim_in_anim_stop: Boolean = False;
  anim_in_bk: Boolean = False;

  sad: array[0..ANIMATION_SAD_LIST_CAPACITY - 1] of TAnimationSad;
  dad: array[0..1999] of TPathNode;
  anim_set: array[0..ANIMATION_SEQUENCE_LIST_CAPACITY - 1] of TAnimationSequence;
  seen: array[0..4999] of Byte;
  child: array[0..1999] of TPathNode;
  curr_anim_counter: Integer;

// dude_move static
var
  dude_move_lastDestination: Integer = -2;

// dude_fidget statics
var
  dude_fidget_last_time: LongWord = 0;
  dude_fidget_next_time: LongWord = 0;
  fidget_ptr: array[0..99] of PObject;

// =========================================================================
// FID_ANIM_TYPE inline
// =========================================================================
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// =========================================================================
// anim_init
// =========================================================================
procedure anim_init;
begin
  anim_in_init := True;
  anim_reset;
  anim_in_init := False;
end;

// =========================================================================
// anim_reset
// =========================================================================
procedure anim_reset;
var
  index: Integer;
begin
  if not anim_in_init then
    anim_stop;

  curr_sad := 0;
  curr_anim_set := -1;

  for index := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    anim_set[index].field_0 := -1000;
    anim_set[index].flags := 0;
  end;
end;

// =========================================================================
// anim_exit
// =========================================================================
procedure anim_exit;
begin
  anim_stop;
end;

// =========================================================================
// register_begin
// =========================================================================
function register_begin(requestOptions: Integer): Integer;
var
  v1: Integer;
  animationSequence: PAnimationSequence;
begin
  if curr_anim_set <> -1 then
    Exit(-1);

  if anim_in_anim_stop then
    Exit(-1);

  v1 := anim_free_slot(requestOptions);
  if v1 = -1 then
    Exit(-1);

  animationSequence := @anim_set[v1];
  animationSequence^.flags := animationSequence^.flags or ANIM_SEQ_ACCUMULATING;

  if (requestOptions and ANIMATION_REQUEST_RESERVED) <> 0 then
    animationSequence^.flags := animationSequence^.flags or ANIM_SEQ_RESERVED;

  if (requestOptions and ANIMATION_REQUEST_INSIGNIFICANT) <> 0 then
    animationSequence^.flags := animationSequence^.flags or ANIM_SEQ_INSIGNIFICANT;

  if (requestOptions and ANIMATION_REQUEST_NO_STAND) <> 0 then
    animationSequence^.flags := animationSequence^.flags or ANIM_SEQ_NO_STAND;

  curr_anim_set := v1;
  curr_anim_counter := 0;

  Result := 0;
end;

// =========================================================================
// anim_free_slot
// =========================================================================
function anim_free_slot(requestOptions: Integer): Integer;
var
  v1, v2, index: Integer;
  animationSequence: PAnimationSequence;
begin
  v1 := -1;
  v2 := 0;
  for index := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    animationSequence := @anim_set[index];
    if (animationSequence^.field_0 <> -1000) or
       ((animationSequence^.flags and ANIM_SEQ_ACCUMULATING) <> 0) or
       ((animationSequence^.flags and ANIM_SEQ_0x20) <> 0) then
    begin
      if (animationSequence^.flags and ANIM_SEQ_RESERVED) = 0 then
        Inc(v2);
    end
    else if (v1 = -1) and
            (((requestOptions and ANIMATION_REQUEST_0x100) = 0) or
             ((animationSequence^.flags and ANIM_SEQ_0x10) = 0)) then
    begin
      v1 := index;
    end;
  end;

  if v1 = -1 then
  begin
    if (requestOptions and ANIMATION_REQUEST_RESERVED) <> 0 then
      debug_printf('Unable to begin reserved animation!'#10);
    Exit(-1);
  end
  else if ((requestOptions and ANIMATION_REQUEST_RESERVED) <> 0) or (v2 < 13) then
    Exit(v1);

  Result := -1;
end;

// =========================================================================
// register_priority
// =========================================================================
function register_priority(a1: Integer): Integer;
begin
  if curr_anim_set = -1 then
    Exit(-1);

  if a1 = 0 then
    Exit(-1);

  anim_set[curr_anim_set].flags := anim_set[curr_anim_set].flags or ANIM_SEQ_PRIORITIZED;
  Result := 0;
end;

// =========================================================================
// register_clear
// =========================================================================
function register_clear(a1: PObject): Integer;
var
  animationSequenceIndex: Integer;
  animationSequence: PAnimationSequence;
  animationDescriptionIndex: Integer;
  animationDescription: PAnimDesc;
begin
  for animationSequenceIndex := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    animationSequence := @anim_set[animationSequenceIndex];
    if animationSequence^.field_0 = -1000 then
      Continue;

    animationDescriptionIndex := 0;
    while animationDescriptionIndex < animationSequence^.length do
    begin
      animationDescription := @animationSequence^.animations[animationDescriptionIndex];
      if (a1 = animationDescription^.owner) and (animationDescription^.kind <> 11) then
        Break;
      Inc(animationDescriptionIndex);
    end;

    if animationDescriptionIndex = animationSequence^.length then
      Continue;

    if (animationSequence^.flags and ANIM_SEQ_PRIORITIZED) <> 0 then
      Exit(-2);

    anim_set_end(animationSequenceIndex);
    Exit(0);
  end;

  Result := -1;
end;

// =========================================================================
// register_end
// =========================================================================
function register_end: Integer;
var
  animationSequence: PAnimationSequence;
  v1: Integer;
begin
  if curr_anim_set = -1 then
    Exit(-1);

  animationSequence := @anim_set[curr_anim_set];
  animationSequence^.field_0 := 0;
  animationSequence^.length := curr_anim_counter;
  animationSequence^.animationIndex := -1;
  animationSequence^.flags := animationSequence^.flags and (not LongWord(ANIM_SEQ_ACCUMULATING));
  animationSequence^.animations[0].delay := 0;

  if isInCombat then
  begin
    combat_anim_begin;
    animationSequence^.flags := animationSequence^.flags or ANIM_SEQ_COMBAT_ANIM_STARTED;
  end;

  v1 := curr_anim_set;
  curr_anim_set := -1;

  if (animationSequence^.flags and ANIM_SEQ_0x10) = 0 then
    anim_set_continue(v1, 1);

  Result := 0;
end;

// =========================================================================
// anim_preload
// =========================================================================
function anim_preload(obj: PObject; fid: Integer; cacheEntryPtr: PPCacheEntry): Integer;
begin
  cacheEntryPtr^ := nil;

  if art_ptr_lock(fid, cacheEntryPtr) <> nil then
  begin
    art_ptr_unlock(cacheEntryPtr^);
    cacheEntryPtr^ := nil;
    Exit(0);
  end;

  Result := -1;
end;

// =========================================================================
// anim_cleanup
// =========================================================================
procedure anim_cleanup;
var
  index: Integer;
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if curr_anim_set = -1 then
    Exit;

  for index := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
    anim_set[index].flags := anim_set[index].flags and (not LongWord(ANIM_SEQ_ACCUMULATING or ANIM_SEQ_0x10));

  animationSequence := @anim_set[curr_anim_set];
  for index := 0 to curr_anim_counter - 1 do
  begin
    animationDescription := @animationSequence^.animations[index];
    if animationDescription^.artCacheKey <> nil then
      art_ptr_unlock(animationDescription^.artCacheKey);

    if (animationDescription^.kind = ANIM_KIND_CALLBACK) and
       (Pointer(animationDescription^.callback) = Pointer(@gsnd_anim_sound)) then
      gsound_delete_sfx(PSound(Pointer(animationDescription^.destination))); // param1
  end;

  curr_anim_set := -1;
end;

// =========================================================================
// check_registry
// =========================================================================
function check_registry(obj: PObject): Integer;
var
  animationSequenceIndex: Integer;
  animationSequence: PAnimationSequence;
  animationDescriptionIndex: Integer;
  animationDescription: PAnimDesc;
begin
  if curr_anim_set = -1 then
    Exit(-1);

  if curr_anim_counter >= ANIMATION_DESCRIPTION_LIST_CAPACITY then
    Exit(-1);

  if obj = nil then
    Exit(0);

  for animationSequenceIndex := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    animationSequence := @anim_set[animationSequenceIndex];
    if (animationSequenceIndex <> curr_anim_set) and (animationSequence^.field_0 <> -1000) then
    begin
      for animationDescriptionIndex := 0 to animationSequence^.length - 1 do
      begin
        animationDescription := @animationSequence^.animations[animationDescriptionIndex];
        if (obj = animationDescription^.owner) and (animationDescription^.kind <> 11) then
        begin
          if (animationSequence^.flags and ANIM_SEQ_INSIGNIFICANT) = 0 then
            Exit(-1);
          anim_set_end(animationSequenceIndex);
        end;
      end;
    end;
  end;

  Result := 0;
end;

// =========================================================================
// anim_busy
// =========================================================================
function anim_busy(a1: PObject): Integer;
var
  animationSequenceIndex: Integer;
  animationSequence: PAnimationSequence;
  animationDescriptionIndex: Integer;
  animationDescription: PAnimDesc;
begin
  if (curr_anim_counter >= ANIMATION_DESCRIPTION_LIST_CAPACITY) or (a1 = nil) then
    Exit(0);

  for animationSequenceIndex := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    animationSequence := @anim_set[animationSequenceIndex];
    if (animationSequenceIndex <> curr_anim_set) and (animationSequence^.field_0 <> -1000) then
    begin
      for animationDescriptionIndex := 0 to animationSequence^.length - 1 do
      begin
        animationDescription := @animationSequence^.animations[animationDescriptionIndex];
        if a1 <> animationDescription^.owner then
          Continue;
        if animationDescription^.kind = ANIM_KIND_CALLBACK then
          Continue;
        if (animationSequence^.length = 1) and (animationDescription^.anim = ANIM_STAND) then
          Continue;
        Exit(-1);
      end;
    end;
  end;

  Result := 0;
end;

// =========================================================================
// register_object_move_to_object
// =========================================================================
function register_object_move_to_object(owner, destination: PObject; actionPoints, delay: Integer): Integer;
var
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if (check_registry(owner) = -1) or (actionPoints = 0) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (owner^.Tile = destination^.Tile) and (owner^.Elevation = destination^.Elevation) then
    Exit(0);

  animationDescription := @anim_set[curr_anim_set].animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_OBJECT;
  animationDescription^.anim := ANIM_WALK;
  animationDescription^.owner := owner;
  animationDescription^.destination := destination;
  animationDescription^.actionPoints := actionPoints;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := register_object_turn_towards(owner, destination^.Tile);
end;

// =========================================================================
// register_object_run_to_object
// =========================================================================
function register_object_run_to_object(owner, destination: PObject; actionPoints, delay: Integer): Integer;
var
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if (check_registry(owner) = -1) or (actionPoints = 0) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (owner^.Tile = destination^.Tile) and (owner^.Elevation = destination^.Elevation) then
    Exit(0);

  animationDescription := @anim_set[curr_anim_set].animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_OBJECT;
  animationDescription^.owner := owner;
  animationDescription^.destination := destination;

  if (FID_TYPE(owner^.Fid) = OBJ_TYPE_CRITTER) and
     ((owner^.Data.AsData.Critter.Combat.Results and DAM_CRIP_LEG_ANY) <> 0) then
    animationDescription^.anim := ANIM_WALK
  else if (owner = obj_dude) and is_pc_flag(PC_FLAG_SNEAKING) and (perk_level(PERK_SILENT_RUNNING) = 0) then
    animationDescription^.anim := ANIM_WALK
  else if not art_exists(art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, ANIM_RUNNING, 0, owner^.Rotation + 1)) then
    animationDescription^.anim := ANIM_WALK
  else
    animationDescription^.anim := ANIM_RUNNING;

  animationDescription^.actionPoints := actionPoints;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := register_object_turn_towards(owner, destination^.Tile);
end;

// =========================================================================
// register_object_move_to_tile
// =========================================================================
function register_object_move_to_tile(owner: PObject; tile, elevation, actionPoints, delay: Integer): Integer;
var
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if (check_registry(owner) = -1) or (actionPoints = 0) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (tile = owner^.Tile) and (elevation = owner^.Elevation) then
    Exit(0);

  animationDescription := @anim_set[curr_anim_set].animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_TILE;
  animationDescription^.anim := ANIM_WALK;
  animationDescription^.owner := owner;
  animationDescription^.tile := tile;
  animationDescription^.elevation := elevation;
  animationDescription^.actionPoints := actionPoints;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_run_to_tile
// =========================================================================
function register_object_run_to_tile(owner: PObject; tile, elevation, actionPoints, delay: Integer): Integer;
var
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if (check_registry(owner) = -1) or (actionPoints = 0) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (tile = owner^.Tile) and (elevation = owner^.Elevation) then
    Exit(0);

  animationDescription := @anim_set[curr_anim_set].animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_TILE;
  animationDescription^.owner := owner;
  animationDescription^.tile := tile;
  animationDescription^.elevation := elevation;

  if (FID_TYPE(owner^.Fid) = OBJ_TYPE_CRITTER) and
     ((owner^.Data.AsData.Critter.Combat.Results and DAM_CRIP_LEG_ANY) <> 0) then
    animationDescription^.anim := ANIM_WALK
  else if (owner = obj_dude) and is_pc_flag(PC_FLAG_SNEAKING) and (perk_level(PERK_SILENT_RUNNING) = 0) then
    animationDescription^.anim := ANIM_WALK
  else if not art_exists(art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, ANIM_RUNNING, 0, owner^.Rotation + 1)) then
    animationDescription^.anim := ANIM_WALK
  else
    animationDescription^.anim := ANIM_RUNNING;

  animationDescription^.actionPoints := actionPoints;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_move_straight_to_tile
// =========================================================================
function register_object_move_straight_to_tile(obj: PObject; tile, elevation, anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (tile = obj^.Tile) and (elevation = obj^.Elevation) then
    Exit(0);

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_TILE_STRAIGHT;
  animationDescription^.owner := obj;
  animationDescription^.tile := tile;
  animationDescription^.elevation := elevation;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, animationDescription^.anim,
                (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);

  if anim_preload(obj, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_animate_and_move_straight
// =========================================================================
function register_object_animate_and_move_straight(owner: PObject; tile, elev, anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if (tile = owner^.Tile) and (elev = owner^.Elevation) then
    Exit(0);

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_TO_TILE_STRAIGHT_AND_WAIT_FOR_COMPLETE;
  animationDescription^.owner := owner;
  animationDescription^.tile := tile;
  animationDescription^.elevation := elev;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_move_on_stairs
// =========================================================================
function register_object_move_on_stairs(owner, stairs: PObject; delay: Integer): Integer;
var
  anim_: Integer;
  destTile: Integer;
  destElevation: Integer;
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  if owner^.Elevation = stairs^.Elevation then
  begin
    anim_ := ANIM_UP_STAIRS_LEFT;
    destTile := stairs^.Tile + 4;
    destElevation := stairs^.Elevation + 1;
  end
  else
  begin
    anim_ := ANIM_DOWN_STAIRS_RIGHT;
    destTile := stairs^.Tile + 200;
    destElevation := stairs^.Elevation;
  end;

  if (destTile = owner^.Tile) and (destElevation = owner^.Elevation) then
    Exit(0);

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_MOVE_ON_STAIRS;
  animationDescription^.owner := owner;
  animationDescription^.tile := destTile;
  animationDescription^.elevation := destElevation;
  animationDescription^.anim := anim_;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_check_falling
// =========================================================================
function register_object_check_falling(owner: PObject; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_CHECK_FALLING;
  animationDescription^.anim := ANIM_FALLING;
  animationDescription^.owner := owner;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_animate
// =========================================================================
function register_object_animate(owner: PObject; anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ANIMATE;
  animationDescription^.owner := owner;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_animate_reverse
// =========================================================================
function register_object_animate_reverse(owner: PObject; anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ANIMATE_REVERSED;
  animationDescription^.owner := owner;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;
  animationDescription^.artCacheKey := nil;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, animationDescription^.anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_animate_and_hide
// =========================================================================
function register_object_animate_and_hide(owner: PObject; anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ANIMATE_AND_HIDE;
  animationDescription^.owner := owner;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;
  animationDescription^.artCacheKey := nil;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_turn_towards
// =========================================================================
function register_object_turn_towards(owner: PObject; tile: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ROTATE_TO_TILE;
  animationDescription^.delay := -1;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := owner;
  animationDescription^.tile := tile;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_inc_rotation
// =========================================================================
function register_object_inc_rotation(owner: PObject): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ROTATE_CLOCKWISE;
  animationDescription^.delay := -1;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := owner;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_dec_rotation
// =========================================================================
function register_object_dec_rotation(owner: PObject): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ROTATE_COUNTER_CLOCKWISE;
  animationDescription^.delay := -1;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := owner;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_erase
// =========================================================================
function register_object_erase(obj: PObject): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_HIDE;
  animationDescription^.delay := -1;
  animationDescription^.artCacheKey := nil;
  animationDescription^.objectFlag := 0;
  animationDescription^.owner := obj;
  Inc(curr_anim_counter);

  Result := 0;
end;

// =========================================================================
// register_object_must_erase
// =========================================================================
function register_object_must_erase(obj: PObject): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_HIDE;
  animationDescription^.delay := -1;
  animationDescription^.artCacheKey := nil;
  animationDescription^.objectFlag := ANIMATION_SEQUENCE_FORCED;
  animationDescription^.owner := obj;
  Inc(curr_anim_counter);

  Result := 0;
end;

// =========================================================================
// register_object_call
// =========================================================================
function register_object_call(a1, a2: Pointer; proc: TAnimationCallback; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if (check_registry(nil) = -1) or (not Assigned(proc)) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_CALLBACK;
  animationDescription^.objectFlag := 0;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := PObject(a2);   // param2
  animationDescription^.destination := PObject(a1); // param1
  animationDescription^.callback := proc;
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_call3
// =========================================================================
function register_object_call3(a1, a2, a3: Pointer; proc: TAnimationCallback3; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if (check_registry(nil) = -1) or (not Assigned(proc)) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_CALLBACK3;
  animationDescription^.objectFlag := 0;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := PObject(a2);   // param2
  animationDescription^.destination := PObject(a1); // param1
  animationDescription^.callback3 := proc;
  animationDescription^.actionPoints := Integer(PtrUInt(a3)); // param3
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_must_call
// =========================================================================
function register_object_must_call(a1, a2: Pointer; proc: TAnimationCallback; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if (check_registry(nil) = -1) or (not Assigned(proc)) then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_CALLBACK;
  animationDescription^.objectFlag := ANIMATION_SEQUENCE_FORCED;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := PObject(a2);   // param2
  animationDescription^.destination := PObject(a1); // param1
  animationDescription^.callback := proc;
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_fset
// =========================================================================
function register_object_fset(obj: PObject; flag, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_SET_FLAG;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := obj;
  animationDescription^.objectFlag := LongWord(flag);
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_funset
// =========================================================================
function register_object_funset(obj: PObject; flag, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_UNSET_FLAG;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := obj;
  animationDescription^.objectFlag := LongWord(flag);
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_flatten
// =========================================================================
function register_object_flatten(obj: PObject; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_TOGGLE_FLAT;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := obj;
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_change_fid
// =========================================================================
function register_object_change_fid(owner: PObject; fid, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_SET_FID;
  animationDescription^.owner := owner;
  animationDescription^.tile := fid; // fid union
  animationDescription^.delay := delay;

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_take_out
// =========================================================================
function register_object_take_out(owner: PObject; weaponAnimationCode, delay: Integer): Integer;
var
  sfx: PAnsiChar;
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  sfx := gsnd_build_character_sfx_name(owner, ANIM_TAKE_OUT, weaponAnimationCode);
  if register_object_play_sfx(owner, sfx, delay) = -1 then
    Exit(-1);

  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_TAKE_OUT_WEAPON;
  animationDescription^.anim := ANIM_TAKE_OUT;
  animationDescription^.delay := 0;
  animationDescription^.owner := owner;
  animationDescription^.tile := weaponAnimationCode; // weaponAnimationCode union

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, ANIM_TAKE_OUT, weaponAnimationCode, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_light
// =========================================================================
function register_object_light(owner: PObject; lightDistance, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_SET_LIGHT_DISTANCE;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := owner;
  animationDescription^.tile := lightDistance; // lightDistance union
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_outline
// =========================================================================
function register_object_outline(obj: PObject; outline: Boolean; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(obj) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_TOGGLE_OUTLINE;
  animationDescription^.artCacheKey := nil;
  animationDescription^.owner := obj;
  animationDescription^.tile := Integer(Ord(outline)); // outline union
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_play_sfx
// =========================================================================
function register_object_play_sfx(owner: PObject; soundEffectName: PAnsiChar; delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  volume: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_CALLBACK;
  animationDescription^.owner := owner;

  if soundEffectName <> nil then
  begin
    volume := gsound_compute_relative_volume(owner);
    animationDescription^.destination := PObject(Pointer(gsound_load_sound_volume(soundEffectName, owner, volume))); // param1
    if animationDescription^.destination <> nil then
      animationDescription^.callback := TAnimationCallback(@gsnd_anim_sound)
    else
      animationDescription^.kind := ANIM_KIND_NOOP;
  end
  else
    animationDescription^.kind := ANIM_KIND_NOOP;

  animationDescription^.artCacheKey := nil;
  animationDescription^.delay := delay;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_object_animate_forever
// =========================================================================
function register_object_animate_forever(owner: PObject; anim, delay: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  fid: Integer;
begin
  if check_registry(owner) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.kind := ANIM_KIND_ANIMATE_FOREVER;
  animationDescription^.owner := owner;
  animationDescription^.anim := anim;
  animationDescription^.delay := delay;

  fid := art_id(FID_TYPE(owner^.Fid), owner^.Fid and $FFF, anim,
                (owner^.Fid and $F000) shr 12, owner^.Rotation + 1);

  if anim_preload(owner, fid, @animationDescription^.artCacheKey) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// register_ping
// =========================================================================
function register_ping(a1, a2: Integer): Integer;
var
  animationSequenceIndex: Integer;
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
begin
  if check_registry(nil) = -1 then
  begin
    anim_cleanup;
    Exit(-1);
  end;

  animationSequenceIndex := anim_free_slot(a1 or ANIMATION_REQUEST_0x100);
  if animationSequenceIndex = -1 then
    Exit(-1);

  anim_set[animationSequenceIndex].flags := ANIM_SEQ_0x10;

  animationSequence := @anim_set[curr_anim_set];
  animationDescription := @animationSequence^.animations[curr_anim_counter];
  animationDescription^.owner := nil;
  animationDescription^.kind := ANIM_KIND_26;
  animationDescription^.artCacheKey := nil;
  animationDescription^.actionPoints := animationSequenceIndex; // animationSequenceIndex union
  animationDescription^.delay := a2;

  Inc(curr_anim_counter);
  Result := 0;
end;

// =========================================================================
// anim_set_check
// =========================================================================
function anim_set_check(animationSequenceIndex: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  rc: Integer;
  rect_: TRect;
  rotation: Integer;
begin
  if animationSequenceIndex = -1 then
    Exit(-1);

  animationSequence := @anim_set[animationSequenceIndex];
  if animationSequence^.field_0 = -1000 then
    Exit(-1);

  while True do
  begin
    if animationSequence^.field_0 >= animationSequence^.length then
      Exit(0);

    if animationSequence^.field_0 > animationSequence^.animationIndex then
    begin
      animationDescription := @animationSequence^.animations[animationSequence^.field_0];
      if animationDescription^.delay < 0 then
        Exit(0);
      if animationDescription^.delay > 0 then
      begin
        Dec(animationDescription^.delay);
        Exit(0);
      end;
    end;

    animationDescription := @animationSequence^.animations[animationSequence^.field_0];
    Inc(animationSequence^.field_0);

    rc := 0;
    case animationDescription^.kind of
      ANIM_KIND_MOVE_TO_OBJECT:
        rc := anim_move_to_object(animationDescription^.owner, animationDescription^.destination,
                                  animationDescription^.actionPoints, animationDescription^.anim,
                                  animationSequenceIndex);

      ANIM_KIND_MOVE_TO_TILE:
        rc := anim_move_to_tile(animationDescription^.owner, animationDescription^.tile,
                                animationDescription^.elevation, animationDescription^.actionPoints,
                                animationDescription^.anim, animationSequenceIndex);

      ANIM_KIND_MOVE_TO_TILE_STRAIGHT:
        rc := anim_move_straight_to_tile(animationDescription^.owner, animationDescription^.tile,
                                         animationDescription^.elevation, animationDescription^.anim,
                                         animationSequenceIndex, 0);

      ANIM_KIND_MOVE_TO_TILE_STRAIGHT_AND_WAIT_FOR_COMPLETE:
        rc := anim_move_straight_to_tile(animationDescription^.owner, animationDescription^.tile,
                                         animationDescription^.elevation, animationDescription^.anim,
                                         animationSequenceIndex, ANIM_SAD_WAIT_FOR_COMPLETION);

      ANIM_KIND_ANIMATE:
        rc := anim_animate(animationDescription^.owner, animationDescription^.anim,
                           animationSequenceIndex, 0);

      ANIM_KIND_ANIMATE_REVERSED:
        rc := anim_animate(animationDescription^.owner, animationDescription^.anim,
                           animationSequenceIndex, ANIM_SAD_REVERSE);

      ANIM_KIND_ANIMATE_AND_HIDE:
      begin
        rc := anim_animate(animationDescription^.owner, animationDescription^.anim,
                           animationSequenceIndex, ANIM_SAD_HIDE_ON_END);
        if rc = -1 then
          rc := anim_hide(animationDescription^.owner, animationSequenceIndex);
      end;

      ANIM_KIND_ANIMATE_FOREVER:
        rc := anim_animate(animationDescription^.owner, animationDescription^.anim,
                           animationSequenceIndex, ANIM_SAD_FOREVER);

      ANIM_KIND_ROTATE_TO_TILE:
      begin
        if not critter_is_prone(animationDescription^.owner) then
        begin
          rotation := tile_dir(animationDescription^.owner^.Tile, animationDescription^.tile);
          dude_stand(animationDescription^.owner, rotation, -1);
        end;
        anim_set_continue(animationSequenceIndex, 0);
        rc := 0;
      end;

      ANIM_KIND_ROTATE_CLOCKWISE:
        rc := anim_turn_towards(animationDescription^.owner, 1, animationSequenceIndex);

      ANIM_KIND_ROTATE_COUNTER_CLOCKWISE:
        rc := anim_turn_towards(animationDescription^.owner, -1, animationSequenceIndex);

      ANIM_KIND_HIDE:
        rc := anim_hide(animationDescription^.owner, animationSequenceIndex);

      ANIM_KIND_CALLBACK:
      begin
        rc := animationDescription^.callback(animationDescription^.destination, // param1
                                              animationDescription^.owner);      // param2
        if rc = 0 then
          rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_CALLBACK3:
      begin
        rc := animationDescription^.callback3(animationDescription^.destination, // param1
                                               animationDescription^.owner,       // param2
                                               Pointer(PtrInt(animationDescription^.actionPoints))); // param3
        if rc = 0 then
          rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_SET_FLAG:
      begin
        if animationDescription^.objectFlag = OBJECT_LIGHTING then
        begin
          if obj_turn_on_light(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end
        else if animationDescription^.objectFlag = OBJECT_HIDDEN then
        begin
          if obj_turn_off(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end
        else
          animationDescription^.owner^.Flags := animationDescription^.owner^.Flags or Integer(animationDescription^.objectFlag);

        rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_UNSET_FLAG:
      begin
        if animationDescription^.objectFlag = OBJECT_LIGHTING then
        begin
          if obj_turn_off_light(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end
        else if animationDescription^.objectFlag = OBJECT_HIDDEN then
        begin
          if obj_turn_on(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end
        else
          animationDescription^.owner^.Flags := animationDescription^.owner^.Flags and (not Integer(animationDescription^.objectFlag));

        rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_TOGGLE_FLAT:
      begin
        if obj_toggle_flat(animationDescription^.owner, @rect_) = 0 then
          tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_SET_FID:
        rc := anim_change_fid(animationDescription^.owner, animationSequenceIndex,
                              animationDescription^.tile); // fid union

      ANIM_KIND_TAKE_OUT_WEAPON:
        rc := anim_animate(animationDescription^.owner, ANIM_TAKE_OUT,
                           animationSequenceIndex, animationDescription^.tile); // weaponAnimationCode

      ANIM_KIND_SET_LIGHT_DISTANCE:
      begin
        obj_set_light(animationDescription^.owner, animationDescription^.tile, // lightDistance
                      animationDescription^.owner^.LightIntensity, @rect_);
        tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_MOVE_ON_STAIRS:
        rc := anim_move_on_stairs(animationDescription^.owner, animationDescription^.tile,
                                  animationDescription^.elevation, animationDescription^.anim,
                                  animationSequenceIndex);

      ANIM_KIND_CHECK_FALLING:
        rc := check_for_falling(animationDescription^.owner, animationDescription^.anim,
                                animationSequenceIndex);

      ANIM_KIND_TOGGLE_OUTLINE:
      begin
        if animationDescription^.tile <> 0 then // outline (Boolean stored as Integer)
        begin
          if obj_turn_on_outline(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end
        else
        begin
          if obj_turn_off_outline(animationDescription^.owner, @rect_) = 0 then
            tile_refresh_rect(@rect_, animationDescription^.owner^.Elevation);
        end;
        rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_26:
      begin
        anim_set[animationDescription^.actionPoints].flags :=
          anim_set[animationDescription^.actionPoints].flags and (not LongWord(ANIM_SEQ_0x10));
        rc := anim_set_continue(animationDescription^.actionPoints, 1);
        if rc <> -1 then
          rc := anim_set_continue(animationSequenceIndex, 0);
      end;

      ANIM_KIND_NOOP:
        rc := anim_set_continue(animationSequenceIndex, 0);
    else
      rc := -1;
    end;

    if rc = -1 then
      anim_set_end(animationSequenceIndex);

    if animationSequence^.field_0 = -1000 then
      Exit(-1);
  end;

  Result := 0; // unreachable but satisfies compiler
end;

// =========================================================================
// anim_set_continue
// =========================================================================
function anim_set_continue(animationSequenceIndex, a2: Integer): Integer;
var
  animationSequence: PAnimationSequence;
begin
  if animationSequenceIndex = -1 then
    Exit(-1);

  animationSequence := @anim_set[animationSequenceIndex];
  if animationSequence^.field_0 = -1000 then
    Exit(-1);

  Inc(animationSequence^.animationIndex);
  if animationSequence^.animationIndex = animationSequence^.length then
    Exit(anim_set_end(animationSequenceIndex))
  else
  begin
    if a2 <> 0 then
      Exit(anim_set_check(animationSequenceIndex));
  end;

  Result := 0;
end;

// =========================================================================
// anim_set_end
// =========================================================================
function anim_set_end(animationSequenceIndex: Integer): Integer;
var
  animationSequence: PAnimationSequence;
  animationDescription: PAnimDesc;
  i, j, k, m: Integer;
  rect_: TRect;
  elev: Integer;
  owner: PObject;
  ad: PAnimDesc;
begin
  if animationSequenceIndex = -1 then
    Exit(-1);

  animationSequence := @anim_set[animationSequenceIndex];
  if animationSequence^.field_0 = -1000 then
    Exit(-1);

  for i := 0 to curr_sad - 1 do
  begin
    if sad[i].animationSequenceIndex = animationSequenceIndex then
      sad[i].field_20 := -1000;
  end;

  for i := 0 to animationSequence^.length - 1 do
  begin
    animationDescription := @animationSequence^.animations[i];
    if (animationDescription^.kind = ANIM_KIND_HIDE) and
       ((i < animationSequence^.animationIndex) or
        ((animationDescription^.objectFlag and ANIMATION_SEQUENCE_FORCED) <> 0)) then
    begin
      elev := animationDescription^.owner^.Elevation;
      obj_erase_object(animationDescription^.owner, @rect_);
      tile_refresh_rect(@rect_, elev);
    end;
  end;

  for i := 0 to animationSequence^.length - 1 do
  begin
    animationDescription := @animationSequence^.animations[i];
    if animationDescription^.artCacheKey <> nil then
      art_ptr_unlock(animationDescription^.artCacheKey);

    if (animationDescription^.kind <> 11) and (animationDescription^.kind <> 12) then
    begin
      if animationDescription^.kind <> ANIM_KIND_26 then
      begin
        owner := animationDescription^.owner;
        if FID_TYPE(owner^.Fid) = OBJ_TYPE_CRITTER then
        begin
          j := 0;
          while j < i do
          begin
            ad := @animationSequence^.animations[j];
            if owner = ad^.owner then
            begin
              if (ad^.kind <> ANIM_KIND_CALLBACK) and (ad^.kind <> ANIM_KIND_CALLBACK3) then
                Break;
            end;
            Inc(j);
          end;

          if i = j then
          begin
            k := 0;
            while k < animationSequence^.animationIndex do
            begin
              ad := @animationSequence^.animations[k];
              if (ad^.kind = ANIM_KIND_HIDE) and (ad^.owner = owner) then
                Break;
              Inc(k);
            end;

            if k = animationSequence^.animationIndex then
            begin
              for m := 0 to curr_sad - 1 do
              begin
                if sad[m].obj = owner then
                begin
                  sad[m].field_20 := -1000;
                  Break;
                end;
              end;

              if ((animationSequence^.flags and ANIM_SEQ_NO_STAND) = 0) and
                 (not critter_is_prone(owner)) then
                dude_stand(owner, owner^.Rotation, -1);
            end;
          end;
        end;
      end;
    end
    else if i >= animationSequence^.field_0 then
    begin
      if (animationDescription^.objectFlag and ANIMATION_SEQUENCE_FORCED) <> 0 then
        animationDescription^.callback(animationDescription^.destination, animationDescription^.owner)
      else
      begin
        if (animationDescription^.kind = ANIM_KIND_CALLBACK) and
           (Pointer(animationDescription^.callback) = Pointer(@gsnd_anim_sound)) then
          gsound_delete_sfx(PSound(Pointer(animationDescription^.destination)));
      end;
    end;
  end;

  animationSequence^.animationIndex := -1;
  animationSequence^.field_0 := -1000;

  if (animationSequence^.flags and ANIM_SEQ_COMBAT_ANIM_STARTED) <> 0 then
    combat_anim_finished;

  if anim_in_bk then
    animationSequence^.flags := ANIM_SEQ_0x20
  else
    animationSequence^.flags := 0;

  Result := 0;
end;

// =========================================================================
// anim_can_use_door
// =========================================================================
function anim_can_use_door(critter, door: PObject): Boolean;
var
  body_type_: Integer;
  door_proto: PProto;
begin
  if critter = obj_dude then
    Exit(False);

  if FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER then
    Exit(False);

  body_type_ := critter_body_type(critter);
  if (body_type_ <> BODY_TYPE_BIPED) and (body_type_ <> BODY_TYPE_ROBOTIC) then
    Exit(False);

  if FID_TYPE(door^.Fid) <> OBJ_TYPE_SCENERY then
    Exit(False);

  door_proto := nil;
  if proto_ptr(door^.Pid, @door_proto) = -1 then
    Exit(False);

  // Check scenery type == SCENERY_TYPE_DOOR (offset in proto struct)
  // The proto scenery type is at a known offset. We access via pointer arithmetic.
  // For safety, we check the door_proto->scenery.type field.
  // In the Proto struct, scenery type is the first field after common header.
  // We approximate: the scenery type is at offset that corresponds to proto_types layout.
  // Since Proto is not yet converted, we do a simple check via the field offset.
  // Proto header is 9 ints (36 bytes on 32-bit). scenery.type is after that.
  // On 64-bit this varies. For now we use a simpler approach: just check obj_is_locked.
  // Actually the C code checks door_proto->scenery.type != SCENERY_TYPE_DOOR,
  // but since we don't have the full Proto type, we'll use a PInteger cast.
  // Proto layout: pid(4), messageId(4), fid(4), lightDistance(4), lightIntensity(4),
  //   flags(4), flagsExt(4), scriptId(4), then type-specific.
  // For scenery: scenery.type is at offset 32 (8 ints).
  // Actually the common header for Proto is not fully known without seeing proto_types fully.
  // We'll forward-declare a helper.
  // For correctness we'll just trust it and read the int at the right offset.
  // The C code casts to Proto* and accesses .scenery.type.
  // Let's use a simpler workaround: PID type check already ensures it's scenery.
  // The scenery type check is at a fixed offset in the proto. We read it raw.
  // Proto common fields (from proto_types.h):
  //   int pid, message_id, fid, lightDistance, lightIntensity, flags, flagsExt, sid
  //   then for scenery: int scenery_type at offset 32
  // This should work for both 32-bit and 64-bit since these are all ints.
  if door_proto^.Scenery.SceneryType <> SCENERY_TYPE_DOOR then
    Exit(False);

  if obj_is_locked(door) then
    Exit(False);

  Result := True;
end;

// =========================================================================
// make_path
// =========================================================================
function make_path(obj: PObject; from_, to_: Integer; a4: PByte; a5: Integer): Integer;
begin
  Result := make_path_func(obj, from_, to_, a4, a5, TPathBuilderCallback(@obj_blocking_at));
end;

// =========================================================================
// make_path_func
// =========================================================================
function make_path_func(obj: PObject; from_, to_: Integer; rotations: PByte; a5: Integer; callback: TPathBuilderCallback): Integer;
var
  isNotInCombat: Boolean;
  toScreenX, toScreenY: Integer;
  closedPathNodeListLength: Integer;
  openPathNodeListLength: Integer;
  temp: TPathNode;
  v63: Integer;
  prev: PPathNode;
  v12: Integer;
  index, rotation, v25: Integer;
  curr: PPathNode;
  tile, bit: Integer;
  v24: PObject;
  v27: PPathNode;
  newX, newY: Integer;
  v39: PByte;
  pathLen: Integer;
  j: Integer;
  v36: PPathNode;
  beginning, ending: PByte;
  middle, idx: Integer;
  rotByte: Byte;
begin
  if a5 <> 0 then
  begin
    if callback(obj, to_, obj^.Elevation) <> nil then
      Exit(0);
  end;

  isNotInCombat := not isInCombat;

  FillChar(seen, SizeOf(seen), 0);

  seen[from_ div 8] := seen[from_ div 8] or (1 shl (from_ and 7));

  child[0].tile := from_;
  child[0].from_ := -1;
  child[0].rotation := 0;
  child[0].field_C := EST(from_, to_);
  child[0].field_10 := 0;

  for index := 1 to 1999 do
    child[index].tile := -1;

  tile_coord(to_, @toScreenX, @toScreenY, obj^.Elevation);

  closedPathNodeListLength := 0;
  openPathNodeListLength := 1;

  while True do
  begin
    v63 := -1;
    prev := nil;
    v12 := 0;
    index := 0;
    while v12 < openPathNodeListLength do
    begin
      curr := @child[index];
      if curr^.tile <> -1 then
      begin
        Inc(v12);
        if (v63 = -1) or ((curr^.field_C + curr^.field_10) < (prev^.field_C + prev^.field_10)) then
        begin
          prev := curr;
          v63 := index;
        end;
      end;
      Inc(index);
    end;

    curr := @child[v63];
    Move(curr^, temp, SizeOf(TPathNode));

    Dec(openPathNodeListLength);
    curr^.tile := -1;

    if temp.tile = to_ then
    begin
      if openPathNodeListLength = 0 then
        openPathNodeListLength := 1;
      Break;
    end;

    Move(temp, dad[closedPathNodeListLength], SizeOf(TPathNode));
    Inc(closedPathNodeListLength);

    if closedPathNodeListLength = 2000 then
      Exit(0);

    for rotation := 0 to Integer(ROTATION_COUNT) - 1 do
    begin
      tile := tile_num_in_direction(temp.tile, rotation, 1);
      bit := 1 shl (tile and 7);
      if (seen[tile div 8] and bit) <> 0 then
        Continue;

      if tile <> to_ then
      begin
        v24 := callback(obj, tile, obj^.Elevation);
        if v24 <> nil then
        begin
          if not anim_can_use_door(obj, v24) then
            Continue;
        end;
      end;

      v25 := 0;
      while v25 < 2000 do
      begin
        if child[v25].tile = -1 then
          Break;
        Inc(v25);
      end;

      Inc(openPathNodeListLength);
      if openPathNodeListLength = 2000 then
        Exit(0);

      seen[tile div 8] := seen[tile div 8] or bit;

      v27 := @child[v25];
      v27^.tile := tile;
      v27^.from_ := temp.tile;
      v27^.rotation := rotation;

      tile_coord(tile, @newX, @newY, obj^.Elevation);

      v27^.field_C := idist(newX, newY, toScreenX, toScreenY);
      v27^.field_10 := temp.field_10 + 50;

      if isNotInCombat and (temp.rotation <> rotation) then
        v27^.field_10 := v27^.field_10 + 10;
    end;

    if openPathNodeListLength = 0 then
      Break;
  end;

  if openPathNodeListLength <> 0 then
  begin
    v39 := rotations;
    pathLen := 0;
    while pathLen < 800 do
    begin
      if temp.tile = from_ then
        Break;

      if v39 <> nil then
      begin
        v39^ := Byte(temp.rotation and $FF);
        Inc(v39);
      end;

      j := 0;
      while dad[j].tile <> temp.from_ do
        Inc(j);

      v36 := @dad[j];
      Move(v36^, temp, SizeOf(TPathNode));
      Inc(pathLen);
    end;

    if rotations <> nil then
    begin
      beginning := rotations;
      ending := rotations + pathLen - 1;
      middle := pathLen div 2;
      for idx := 0 to middle - 1 do
      begin
        rotByte := ending^;
        ending^ := beginning^;
        beginning^ := rotByte;
        Dec(ending);
        Inc(beginning);
      end;
    end;

    Exit(pathLen);
  end;

  Result := 0;
end;

// =========================================================================
// idist
// =========================================================================
function idist(a1, a2, a3, a4: Integer): Integer;
var
  dx, dy, dm: Integer;
begin
  dx := a3 - a1;
  if dx < 0 then dx := -dx;

  dy := a4 - a2;
  if dy < 0 then dy := -dy;

  if dx <= dy then dm := dx else dm := dy;

  Result := dx + dy - (dm div 2);
end;

// =========================================================================
// EST
// =========================================================================
function EST(tile1, tile2: Integer): Integer;
var
  x1, y1, x2, y2: Integer;
begin
  tile_coord(tile1, @x1, @y1, map_elevation);
  tile_coord(tile2, @x2, @y2, map_elevation);
  Result := idist(x1, y1, x2, y2);
end;

// =========================================================================
// make_straight_path
// =========================================================================
function make_straight_path(a1: PObject; from_, to_: Integer; pathNodes: PStraightPathNode; a5: PPObject; a6: Integer): Integer;
begin
  Result := make_straight_path_func(a1, from_, to_, pathNodes, a5, a6, TPathBuilderCallback(@obj_blocking_at));
end;

// =========================================================================
// make_straight_path_func
// =========================================================================
function make_straight_path_func(a1: PObject; from_, to_: Integer; pathNodes: PStraightPathNode; a5: PPObject; a6: Integer; callback: TPathBuilderCallback): Integer;
var
  v11: PObject;
  fromX, fromY, toX, toY: Integer;
  stepX, stepY: Integer;
  deltaX, deltaY: Integer;
  v48, v47: Integer;
  tileX, tileY: Integer;
  pathNodeIndex: Integer;
  prevTile: Integer;
  v22: Integer;
  tile: Integer;
  middle_: Integer;
  pathNode: PStraightPathNode;
  obj_: PObject;
begin
  if a5 <> nil then
  begin
    v11 := callback(a1, from_, a1^.Elevation);
    if v11 <> nil then
    begin
      if (v11 <> a5^) and ((a6 <> 32) or ((v11^.Flags and OBJECT_SHOOT_THRU) = 0)) then
      begin
        a5^ := v11;
        Exit(0);
      end;
    end;
  end;

  tile_coord(from_, @fromX, @fromY, a1^.Elevation);
  fromX := fromX + 16;
  fromY := fromY + 8;

  tile_coord(to_, @toX, @toY, a1^.Elevation);
  toX := toX + 16;
  toY := toY + 8;

  deltaX := toX - fromX;
  if deltaX > 0 then stepX := 1
  else if deltaX < 0 then stepX := -1
  else stepX := 0;

  deltaY := toY - fromY;
  if deltaY > 0 then stepY := 1
  else if deltaY < 0 then stepY := -1
  else stepY := 0;

  v48 := 2 * Abs(toX - fromX);
  v47 := 2 * Abs(toY - fromY);

  tileX := fromX;
  tileY := fromY;

  pathNodeIndex := 0;
  prevTile := from_;
  v22 := 0;

  if v48 <= v47 then
  begin
    middle_ := v48 - v47 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, a1^.Elevation);

      Inc(v22);
      if v22 = a6 then
      begin
        if pathNodeIndex >= 200 then
          Exit(0);

        if pathNodes <> nil then
        begin
          pathNode := @pathNodes[pathNodeIndex];
          pathNode^.tile := tile;
          pathNode^.elevation := a1^.Elevation;

          tile_coord(tile, @fromX, @fromY, a1^.Elevation);
          pathNode^.x := tileX - fromX - 16;
          pathNode^.y := tileY - fromY - 8;
        end;

        v22 := 0;
        Inc(pathNodeIndex);
      end;

      if tileY = toY then
      begin
        if a5 <> nil then
          a5^ := nil;
        Break;
      end;

      if middle_ >= 0 then
      begin
        tileX := tileX + stepX;
        middle_ := middle_ - v47;
      end;

      tileY := tileY + stepY;
      middle_ := middle_ + v48;

      if tile <> prevTile then
      begin
        if a5 <> nil then
        begin
          obj_ := callback(a1, tile, a1^.Elevation);
          if obj_ <> nil then
          begin
            if (obj_ <> a5^) and ((a6 <> 32) or ((obj_^.Flags and OBJECT_SHOOT_THRU) = 0)) then
            begin
              a5^ := obj_;
              Break;
            end;
          end;
        end;
        prevTile := tile;
      end;
    end;
  end
  else
  begin
    middle_ := v47 - v48 div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, a1^.Elevation);

      Inc(v22);
      if v22 = a6 then
      begin
        if pathNodeIndex >= 200 then
          Exit(0);

        if pathNodes <> nil then
        begin
          pathNode := @pathNodes[pathNodeIndex];
          pathNode^.tile := tile;
          pathNode^.elevation := a1^.Elevation;

          tile_coord(tile, @fromX, @fromY, a1^.Elevation);
          pathNode^.x := tileX - fromX - 16;
          pathNode^.y := tileY - fromY - 8;
        end;

        v22 := 0;
        Inc(pathNodeIndex);
      end;

      if tileX = toX then
      begin
        if a5 <> nil then
          a5^ := nil;
        Break;
      end;

      if middle_ >= 0 then
      begin
        tileY := tileY + stepY;
        middle_ := middle_ - v48;
      end;

      tileX := tileX + stepX;
      middle_ := middle_ + v47;

      if tile <> prevTile then
      begin
        if a5 <> nil then
        begin
          obj_ := callback(a1, tile, a1^.Elevation);
          if obj_ <> nil then
          begin
            if (obj_ <> a5^) and ((a6 <> 32) or ((obj_^.Flags and OBJECT_SHOOT_THRU) = 0)) then
            begin
              a5^ := obj_;
              Break;
            end;
          end;
        end;
        prevTile := tile;
      end;
    end;
  end;

  if v22 <> 0 then
  begin
    if pathNodeIndex >= 200 then
      Exit(0);

    if pathNodes <> nil then
    begin
      pathNode := @pathNodes[pathNodeIndex];
      pathNode^.tile := tile;
      pathNode^.elevation := a1^.Elevation;

      tile_coord(tile, @fromX, @fromY, a1^.Elevation);
      pathNode^.x := tileX - fromX - 16;
      pathNode^.y := tileY - fromY - 8;
    end;

    Inc(pathNodeIndex);
  end
  else
  begin
    if (pathNodeIndex > 0) and (pathNodes <> nil) then
      pathNodes[pathNodeIndex - 1].elevation := a1^.Elevation;
  end;

  Result := pathNodeIndex;
end;

// =========================================================================
// anim_move_to_object
// =========================================================================
function anim_move_to_object(from_, to_: PObject; a3, anim, animationSequenceIndex: Integer): Integer;
var
  hidden: Boolean;
  moveSadIndex: Integer;
  sad_entry: PAnimationSad;
  isMultihex: Boolean;
begin
  hidden := (to_^.Flags and OBJECT_HIDDEN) <> 0;
  to_^.Flags := to_^.Flags or OBJECT_HIDDEN;

  moveSadIndex := anim_move(from_, to_^.Tile, to_^.Elevation, -1, anim, 0, animationSequenceIndex);

  if not hidden then
    to_^.Flags := to_^.Flags and (not OBJECT_HIDDEN);

  if moveSadIndex = -1 then
    Exit(-1);

  sad_entry := @sad[moveSadIndex];
  isMultihex := (from_^.Flags and OBJECT_MULTIHEX) <> 0;

  if isMultihex then
    sad_entry^.field_1C := sad_entry^.field_1C - 2
  else
    sad_entry^.field_1C := sad_entry^.field_1C - 1;

  if sad_entry^.field_1C <= 0 then
  begin
    sad_entry^.field_20 := -1000;
    anim_set_continue(animationSequenceIndex, 0);
  end;

  if isMultihex then
    sad_entry^.field_24 := tile_num_in_direction(to_^.Tile, sad_entry^.rotations[sad_entry^.field_1C + 1], 1)
  else
    sad_entry^.field_24 := tile_num_in_direction(to_^.Tile, sad_entry^.rotations[sad_entry^.field_1C], 1);

  if isMultihex then
    sad_entry^.field_24 := tile_num_in_direction(sad_entry^.field_24, sad_entry^.rotations[sad_entry^.field_1C], 1);

  if (a3 <> -1) and (a3 < sad_entry^.field_1C) then
    sad_entry^.field_1C := a3;

  Result := 0;
end;

// =========================================================================
// make_stair_path
// =========================================================================
function make_stair_path(obj: PObject; from_, fromElevation, to_, toElevation: Integer; a6: PStraightPathNode; obstaclePtr: PPObject): Integer;
var
  elevation: Integer;
  fromX, fromY, toX, toY: Integer;
  ddx, ddy: Integer;
  stepX, stepY: Integer;
  deltaX, deltaY: Integer;
  tileX, tileY: Integer;
  pathNodeIndex: Integer;
  prevTile: Integer;
  iteration: Integer;
  tile: Integer;
  middle_: Integer;
  pathNode: PStraightPathNode;
begin
  elevation := fromElevation;
  if elevation > toElevation then
    elevation := toElevation;

  tile_coord(from_, @fromX, @fromY, fromElevation);
  fromX := fromX + 16;
  fromY := fromY + 8;

  tile_coord(to_, @toX, @toY, toElevation);
  toX := toX + 16;
  toY := toY + 8;

  if obstaclePtr <> nil then
    obstaclePtr^ := nil;

  ddx := 2 * Abs(toX - fromX);

  deltaX := toX - fromX;
  if deltaX > 0 then stepX := 1
  else if deltaX < 0 then stepX := -1
  else stepX := 0;

  ddy := 2 * Abs(toY - fromY);

  deltaY := toY - fromY;
  if deltaY > 0 then stepY := 1
  else if deltaY < 0 then stepY := -1
  else stepY := 0;

  tileX := fromX;
  tileY := fromY;

  pathNodeIndex := 0;
  prevTile := from_;
  iteration := 0;

  if ddx > ddy then
  begin
    middle_ := ddy - ddx div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, elevation);

      Inc(iteration);
      if iteration = 16 then
      begin
        if pathNodeIndex >= 200 then
          Exit(0);

        if a6 <> nil then
        begin
          pathNode := @a6[pathNodeIndex];
          pathNode^.tile := tile;
          pathNode^.elevation := elevation;

          tile_coord(tile, @fromX, @fromY, elevation);
          pathNode^.x := tileX - fromX - 16;
          pathNode^.y := tileY - fromY - 8;
        end;

        iteration := 0;
        Inc(pathNodeIndex);
      end;

      if tileX = toX then
        Break;

      if middle_ >= 0 then
      begin
        tileY := tileY + stepY;
        middle_ := middle_ - ddx;
      end;

      tileX := tileX + stepX;
      middle_ := middle_ + ddy;

      if tile <> prevTile then
      begin
        if obstaclePtr <> nil then
        begin
          obstaclePtr^ := obj_blocking_at(obj, tile, obj^.Elevation);
          if obstaclePtr^ <> nil then
            Break;
        end;
        prevTile := tile;
      end;
    end;
  end
  else
  begin
    middle_ := ddx - ddy div 2;
    while True do
    begin
      tile := tile_num(tileX, tileY, elevation);

      Inc(iteration);
      if iteration = 16 then
      begin
        if pathNodeIndex >= 200 then
          Exit(0);

        if a6 <> nil then
        begin
          pathNode := @a6[pathNodeIndex];
          pathNode^.tile := tile;
          pathNode^.elevation := elevation;

          tile_coord(tile, @fromX, @fromY, elevation);
          pathNode^.x := tileX - fromX - 16;
          pathNode^.y := tileY - fromY - 8;
        end;

        iteration := 0;
        Inc(pathNodeIndex);
      end;

      if tileY = toY then
        Break;

      if middle_ >= 0 then
      begin
        tileX := tileX + stepX;
        middle_ := middle_ - ddy;
      end;

      tileY := tileY + stepY;
      middle_ := middle_ + ddx;

      if tile <> prevTile then
      begin
        if obstaclePtr <> nil then
        begin
          obstaclePtr^ := obj_blocking_at(obj, tile, obj^.Elevation);
          if obstaclePtr^ <> nil then
            Break;
        end;
        prevTile := tile;
      end;
    end;
  end;

  if iteration <> 0 then
  begin
    if pathNodeIndex >= 200 then
      Exit(0);

    if a6 <> nil then
    begin
      pathNode := @a6[pathNodeIndex];
      pathNode^.tile := tile;
      pathNode^.elevation := elevation;

      tile_coord(tile, @fromX, @fromY, elevation);
      pathNode^.x := tileX - fromX - 16;
      pathNode^.y := tileY - fromY - 8;
    end;

    Inc(pathNodeIndex);
  end
  else
  begin
    if pathNodeIndex > 0 then
    begin
      if a6 <> nil then
        a6[pathNodeIndex - 1].elevation := toElevation;
    end;
  end;

  Result := pathNodeIndex;
end;

// =========================================================================
// anim_move_to_tile
// =========================================================================
function anim_move_to_tile(obj: PObject; tile_num_, elev, a4, anim, animationSequenceIndex: Integer): Integer;
var
  v1: Integer;
  sad_entry: PAnimationSad;
begin
  v1 := anim_move(obj, tile_num_, elev, -1, anim, 0, animationSequenceIndex);
  if v1 = -1 then
    Exit(-1);

  if obj_blocking_at(obj, tile_num_, elev) <> nil then
  begin
    sad_entry := @sad[v1];
    Dec(sad_entry^.field_1C);
    if sad_entry^.field_1C <= 0 then
    begin
      sad_entry^.field_20 := -1000;
      anim_set_continue(animationSequenceIndex, 0);
    end;

    sad_entry^.field_24 := tile_num_in_direction(tile_num_, sad_entry^.rotations[sad_entry^.field_1C], 1);
    if (a4 <> -1) and (a4 < sad_entry^.field_1C) then
      sad_entry^.field_1C := a4;
  end;

  Result := 0;
end;

// =========================================================================
// anim_move
// =========================================================================
function anim_move(obj: PObject; tile, elev, a3, anim, a5, animationSequenceIndex: Integer): Integer;
var
  sad_entry: PAnimationSad;
begin
  if curr_sad = ANIMATION_SAD_LIST_CAPACITY then
    Exit(-1);

  sad_entry := @sad[curr_sad];
  sad_entry^.obj := obj;

  if a5 <> 0 then
    sad_entry^.flags := ANIM_SAD_0x20
  else
    sad_entry^.flags := 0;

  sad_entry^.field_20 := -2000;
  sad_entry^.fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim,
                           (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  sad_entry^.animationTimestamp := 0;
  sad_entry^.ticksPerFrame := compute_tpf(obj, sad_entry^.fid);
  sad_entry^.field_24 := tile;
  sad_entry^.animationSequenceIndex := animationSequenceIndex;
  sad_entry^.anim := anim;

  sad_entry^.field_1C := make_path(obj, obj^.Tile, tile, @sad_entry^.rotations[0], a5);
  if sad_entry^.field_1C = 0 then
  begin
    sad_entry^.field_20 := -1000;
    Exit(-1);
  end;

  if (a3 <> -1) and (sad_entry^.field_1C > a3) then
    sad_entry^.field_1C := a3;

  Result := curr_sad;
  Inc(curr_sad);
end;

// =========================================================================
// anim_move_straight_to_tile
// =========================================================================
function anim_move_straight_to_tile(obj: PObject; tile, elevation, anim, animationSequenceIndex, flags: Integer): Integer;
var
  sad_entry: PAnimationSad;
  v15: Integer;
begin
  if curr_sad = ANIMATION_SAD_LIST_CAPACITY then
    Exit(-1);

  sad_entry := @sad[curr_sad];
  sad_entry^.obj := obj;
  sad_entry^.flags := LongWord(flags) or ANIM_SAD_STRAIGHT;

  if anim = -1 then
  begin
    sad_entry^.fid := obj^.Fid;
    sad_entry^.flags := sad_entry^.flags or ANIM_SAD_NO_ANIM;
  end
  else
    sad_entry^.fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim,
                             (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);

  sad_entry^.field_20 := -2000;
  sad_entry^.animationTimestamp := 0;
  sad_entry^.ticksPerFrame := compute_tpf(obj, sad_entry^.fid);
  sad_entry^.animationSequenceIndex := animationSequenceIndex;

  if FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER then
  begin
    if FID_ANIM_TYPE(obj^.Fid) = ANIM_JUMP_BEGIN then
      v15 := 16
    else
      v15 := 4;
  end
  else
    v15 := 32;

  sad_entry^.field_1C := make_straight_path(obj, obj^.Tile, tile, @sad_entry^.field_28[0], nil, v15);
  if sad_entry^.field_1C = 0 then
  begin
    sad_entry^.field_20 := -1000;
    Exit(-1);
  end;

  Inc(curr_sad);
  Result := 0;
end;

// =========================================================================
// anim_move_on_stairs
// =========================================================================
function anim_move_on_stairs(obj: PObject; tile, elevation, anim, animationSequenceIndex: Integer): Integer;
var
  sad_entry: PAnimationSad;
begin
  if curr_sad = ANIMATION_SAD_LIST_CAPACITY then
    Exit(-1);

  sad_entry := @sad[curr_sad];
  sad_entry^.flags := ANIM_SAD_STRAIGHT;
  sad_entry^.obj := obj;

  if anim = -1 then
  begin
    sad_entry^.fid := obj^.Fid;
    sad_entry^.flags := sad_entry^.flags or ANIM_SAD_NO_ANIM;
  end
  else
    sad_entry^.fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim,
                             (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);

  sad_entry^.field_20 := -2000;
  sad_entry^.animationTimestamp := 0;
  sad_entry^.ticksPerFrame := compute_tpf(obj, sad_entry^.fid);
  sad_entry^.animationSequenceIndex := animationSequenceIndex;
  sad_entry^.field_1C := make_stair_path(obj, obj^.Tile, obj^.Elevation, tile, elevation,
                                          @sad_entry^.field_28[0], nil);
  if sad_entry^.field_1C = 0 then
  begin
    sad_entry^.field_20 := -1000;
    Exit(-1);
  end;

  Inc(curr_sad);
  Result := 0;
end;

// =========================================================================
// check_for_falling
// =========================================================================
function check_for_falling(obj: PObject; anim, a3: Integer): Integer;
var
  sad_entry: PAnimationSad;
begin
  if curr_sad = ANIMATION_SAD_LIST_CAPACITY then
    Exit(-1);

  if check_gravity(obj^.Tile, obj^.Elevation) = obj^.Elevation then
    Exit(-1);

  sad_entry := @sad[curr_sad];
  sad_entry^.flags := ANIM_SAD_STRAIGHT;
  sad_entry^.obj := obj;

  if anim = -1 then
  begin
    sad_entry^.fid := obj^.Fid;
    sad_entry^.flags := sad_entry^.flags or ANIM_SAD_NO_ANIM;
  end
  else
    sad_entry^.fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim,
                             (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);

  sad_entry^.field_20 := -2000;
  sad_entry^.animationTimestamp := 0;
  sad_entry^.ticksPerFrame := compute_tpf(obj, sad_entry^.fid);
  sad_entry^.animationSequenceIndex := a3;
  sad_entry^.field_1C := make_straight_path_func(obj, obj^.Tile, obj^.Tile,
                                                  @sad_entry^.field_28[0], nil, 16,
                                                  TPathBuilderCallback(@obj_blocking_at));
  if sad_entry^.field_1C = 0 then
  begin
    sad_entry^.field_20 := -1000;
    Exit(-1);
  end;

  Inc(curr_sad);
  Result := 0;
end;

// =========================================================================
// object_move
// =========================================================================
procedure object_move(index: Integer);
var
  sad_entry: PAnimationSad;
  obj_: PObject;
  dirty, temp: TRect;
  frameX, frameY: Integer;
  cacheHandle: PCacheEntry;
  art: PArt;
  rotation_: Integer;
  y, x: Integer;
  v10: Integer;
  v12: PObject;
  v17: Integer;
  v18: Integer;
  ap, v20: Integer;
begin
  sad_entry := @sad[index];
  obj_ := sad_entry^.obj;

  if sad_entry^.field_20 = -2000 then
  begin
    obj_move_to_tile(obj_, obj_^.Tile, obj_^.Elevation, @dirty);
    obj_set_frame(obj_, 0, @temp);
    rect_min_bound(@dirty, @temp, @dirty);

    obj_set_rotation(obj_, sad_entry^.rotations[0], @temp);
    rect_min_bound(@dirty, @temp, @dirty);

    obj_change_fid(obj_, art_id(FID_TYPE(obj_^.Fid), obj_^.Fid and $FFF, sad_entry^.anim,
                   (obj_^.Fid and $F000) shr 12, obj_^.Rotation + 1), @temp);
    rect_min_bound(@dirty, @temp, @dirty);

    sad_entry^.field_20 := 0;
  end
  else
    obj_inc_frame(obj_, @dirty);

  cacheHandle := nil;
  art := art_ptr_lock(obj_^.Fid, @cacheHandle);
  if art <> nil then
  begin
    art_frame_hot(art, obj_^.Frame, obj_^.Rotation, @frameX, @frameY);
    art_ptr_unlock(cacheHandle);
  end
  else
  begin
    frameX := 0;
    frameY := 0;
  end;

  obj_offset(obj_, frameX, frameY, @temp);
  rect_min_bound(@dirty, @temp, @dirty);

  rotation_ := sad_entry^.rotations[sad_entry^.field_20];
  y := off_tile[1][rotation_];
  x := off_tile[0][rotation_];

  if ((x > 0) and (x <= obj_^.X)) or ((x < 0) and (x >= obj_^.X)) or
     ((y > 0) and (y <= obj_^.Y)) or ((y < 0) and (y >= obj_^.Y)) then
  begin
    x := obj_^.X - x;
    y := obj_^.Y - y;

    v10 := tile_num_in_direction(obj_^.Tile, rotation_, 1);
    v12 := obj_blocking_at(obj_, v10, obj_^.Elevation);
    if v12 <> nil then
    begin
      if not anim_can_use_door(obj_, v12) then
      begin
        sad_entry^.field_1C := make_path(obj_, obj_^.Tile, sad_entry^.field_24,
                                          @sad_entry^.rotations[0], 1);
        if sad_entry^.field_1C <> 0 then
        begin
          obj_move_to_tile(obj_, obj_^.Tile, obj_^.Elevation, @temp);
          rect_min_bound(@dirty, @temp, @dirty);

          obj_set_frame(obj_, 0, @temp);
          rect_min_bound(@dirty, @temp, @dirty);

          obj_set_rotation(obj_, sad_entry^.rotations[0], @temp);
          rect_min_bound(@dirty, @temp, @dirty);

          sad_entry^.field_20 := 0;
        end
        else
          sad_entry^.field_20 := -1000;

        v10 := -1;
      end
      else
        obj_use_door(obj_, v12, 0);
    end;

    if v10 <> -1 then
    begin
      obj_move_to_tile(obj_, v10, obj_^.Elevation, @temp);
      rect_min_bound(@dirty, @temp, @dirty);

      v17 := 0;
      if isInCombat and (FID_TYPE(obj_^.Fid) = OBJ_TYPE_CRITTER) then
      begin
        v18 := critter_compute_ap_from_distance(obj_, 1);
        if combat_free_move < v18 then
        begin
          ap := obj_^.Data.AsData.Critter.Combat.Ap;
          v20 := v18 - combat_free_move;
          combat_free_move := 0;
          if v20 > ap then
            obj_^.Data.AsData.Critter.Combat.Ap := 0
          else
            obj_^.Data.AsData.Critter.Combat.Ap := ap - v20;
        end
        else
          combat_free_move := combat_free_move - v18;

        if obj_ = obj_dude then
          intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);

        if (obj_^.Data.AsData.Critter.Combat.Ap + combat_free_move) <= 0 then
          v17 := 1
        else
          v17 := 0;
      end;

      Inc(sad_entry^.field_20);

      if (sad_entry^.field_20 = sad_entry^.field_1C) or (v17 <> 0) then
        sad_entry^.field_20 := -1000
      else
      begin
        obj_set_rotation(obj_, sad_entry^.rotations[sad_entry^.field_20], @temp);
        rect_min_bound(@dirty, @temp, @dirty);

        obj_offset(obj_, x, y, @temp);
        rect_min_bound(@dirty, @temp, @dirty);
      end;
    end;
  end;

  tile_refresh_rect(@dirty, obj_^.Elevation);
  if sad_entry^.field_20 = -1000 then
    anim_set_continue(sad_entry^.animationSequenceIndex, 1);
end;

// =========================================================================
// object_straight_move
// =========================================================================
procedure object_straight_move(index: Integer);
var
  sad_entry: PAnimationSad;
  obj_: PObject;
  dirtyRect, temp: TRect;
  cacheHandle: PCacheEntry;
  art: PArt;
  lastFrame: Integer;
  v12: PStraightPathNode;
begin
  sad_entry := @sad[index];
  obj_ := sad_entry^.obj;

  if sad_entry^.field_20 = -2000 then
  begin
    obj_change_fid(obj_, sad_entry^.fid, @dirtyRect);
    sad_entry^.field_20 := 0;
  end
  else
    obj_bound(obj_, @dirtyRect);

  cacheHandle := nil;
  art := art_ptr_lock(obj_^.Fid, @cacheHandle);
  if art <> nil then
  begin
    lastFrame := art_frame_max_frame(art) - 1;
    art_ptr_unlock(cacheHandle);

    if (sad_entry^.flags and ANIM_SAD_NO_ANIM) = 0 then
    begin
      if ((sad_entry^.flags and ANIM_SAD_WAIT_FOR_COMPLETION) = 0) or (obj_^.Frame < lastFrame) then
      begin
        obj_inc_frame(obj_, @temp);
        rect_min_bound(@dirtyRect, @temp, @dirtyRect);
      end;
    end;

    if sad_entry^.field_20 < sad_entry^.field_1C then
    begin
      v12 := @sad_entry^.field_28[sad_entry^.field_20];

      obj_move_to_tile(obj_, v12^.tile, v12^.elevation, @temp);
      rect_min_bound(@dirtyRect, @temp, @dirtyRect);

      obj_offset(obj_, v12^.x, v12^.y, @temp);
      rect_min_bound(@dirtyRect, @temp, @dirtyRect);

      Inc(sad_entry^.field_20);
    end;

    if sad_entry^.field_20 = sad_entry^.field_1C then
    begin
      if ((sad_entry^.flags and ANIM_SAD_WAIT_FOR_COMPLETION) = 0) or (obj_^.Frame = lastFrame) then
        sad_entry^.field_20 := -1000;
    end;

    tile_refresh_rect(@dirtyRect, sad_entry^.obj^.Elevation);

    if sad_entry^.field_20 = -1000 then
      anim_set_continue(sad_entry^.animationSequenceIndex, 1);
  end;
end;

// =========================================================================
// anim_animate
// =========================================================================
function anim_animate(obj: PObject; anim, animationSequenceIndex, flags: Integer): Integer;
var
  sad_entry: PAnimationSad;
  fid: Integer;
begin
  if curr_sad = ANIMATION_SAD_LIST_CAPACITY then
    Exit(-1);

  sad_entry := @sad[curr_sad];

  if anim = ANIM_TAKE_OUT then
  begin
    sad_entry^.flags := 0;
    fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_TAKE_OUT, flags, obj^.Rotation + 1);
  end
  else
  begin
    sad_entry^.flags := LongWord(flags);
    fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim,
                  (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  end;

  if not art_exists(fid) then
    Exit(-1);

  sad_entry^.obj := obj;
  sad_entry^.fid := fid;
  sad_entry^.animationSequenceIndex := animationSequenceIndex;
  sad_entry^.animationTimestamp := 0;
  sad_entry^.ticksPerFrame := compute_tpf(obj, sad_entry^.fid);
  sad_entry^.field_20 := 0;
  sad_entry^.field_1C := 0;

  Inc(curr_sad);
  Result := 0;
end;

// =========================================================================
// object_animate
// =========================================================================
procedure object_animate;
var
  index, innerIndex: Integer;
  sad_entry, otherSad: PAnimationSad;
  obj_: PObject;
  time_: LongWord;
  savedTile: Integer;
  dirtyRect, tempRect, v29, v19: TRect;
  cacheHandle: PCacheEntry;
  art: PArt;
  lastFrame: Integer;
  frameX, frameY: Integer;
  x, y: Integer;
  frame_: Integer;
begin
  if curr_sad = 0 then
    Exit;

  anim_in_bk := True;

  for index := 0 to curr_sad - 1 do
  begin
    sad_entry := @sad[index];
    if sad_entry^.field_20 = -1000 then
      Continue;

    obj_ := sad_entry^.obj;

    time_ := get_time;
    if elapsed_tocks(time_, sad_entry^.animationTimestamp) < sad_entry^.ticksPerFrame then
      Continue;

    sad_entry^.animationTimestamp := time_;

    if anim_set_check(sad_entry^.animationSequenceIndex) = -1 then
      Continue;

    if sad_entry^.field_1C > 0 then
    begin
      if (sad_entry^.flags and ANIM_SAD_STRAIGHT) <> 0 then
        object_straight_move(index)
      else
      begin
        savedTile := obj_^.Tile;
        object_move(index);
        if savedTile <> obj_^.Tile then
          scr_chk_spatials_in(obj_, obj_^.Tile, obj_^.Elevation);
      end;
      Continue;
    end;

    if sad_entry^.field_20 = 0 then
    begin
      for innerIndex := 0 to curr_sad - 1 do
      begin
        otherSad := @sad[innerIndex];
        if (obj_ = otherSad^.obj) and (otherSad^.field_20 = -2000) then
        begin
          otherSad^.field_20 := -1000;
          anim_set_continue(otherSad^.animationSequenceIndex, 1);
        end;
      end;
      sad_entry^.field_20 := -2000;
    end;

    obj_bound(obj_, @dirtyRect);

    if obj_^.Fid = sad_entry^.fid then
    begin
      if (sad_entry^.flags and ANIM_SAD_REVERSE) = 0 then
      begin
        cacheHandle := nil;
        art := art_ptr_lock(obj_^.Fid, @cacheHandle);
        if art <> nil then
        begin
          if ((sad_entry^.flags and ANIM_SAD_FOREVER) = 0) and
             (obj_^.Frame = art_frame_max_frame(art) - 1) then
          begin
            sad_entry^.field_20 := -1000;
            art_ptr_unlock(cacheHandle);

            if (sad_entry^.flags and ANIM_SAD_HIDE_ON_END) <> 0 then
              anim_hide(obj_, -1);

            anim_set_continue(sad_entry^.animationSequenceIndex, 1);
            Continue;
          end
          else
          begin
            obj_inc_frame(obj_, @tempRect);
            rect_min_bound(@dirtyRect, @tempRect, @dirtyRect);

            art_frame_hot(art, obj_^.Frame, obj_^.Rotation, @frameX, @frameY);

            obj_offset(obj_, frameX, frameY, @tempRect);
            rect_min_bound(@dirtyRect, @tempRect, @dirtyRect);

            art_ptr_unlock(cacheHandle);
          end;
        end;

        tile_refresh_rect(@dirtyRect, map_elevation);
        Continue;
      end;

      // ANIM_SAD_REVERSE
      if ((sad_entry^.flags and ANIM_SAD_FOREVER) <> 0) or (obj_^.Frame <> 0) then
      begin
        x := 0;
        y := 0;
        cacheHandle := nil;
        art := art_ptr_lock(obj_^.Fid, @cacheHandle);
        if art <> nil then
        begin
          art_frame_hot(art, obj_^.Frame, obj_^.Rotation, @x, @y);
          art_ptr_unlock(cacheHandle);
        end;

        obj_dec_frame(obj_, @tempRect);
        rect_min_bound(@dirtyRect, @tempRect, @dirtyRect);

        obj_offset(obj_, -x, -y, @tempRect);
        rect_min_bound(@dirtyRect, @tempRect, @dirtyRect);

        tile_refresh_rect(@dirtyRect, map_elevation);
        Continue;
      end;

      sad_entry^.field_20 := -1000;
      anim_set_continue(sad_entry^.animationSequenceIndex, 1);
    end
    else
    begin
      // fid mismatch - change fid
      x := 0;
      y := 0;

      cacheHandle := nil;
      art := art_ptr_lock(obj_^.Fid, @cacheHandle);
      if art <> nil then
      begin
        art_frame_offset(art, obj_^.Rotation, @x, @y);
        art_ptr_unlock(cacheHandle);
      end;

      obj_change_fid(obj_, sad_entry^.fid, @v29);
      rect_min_bound(@dirtyRect, @v29, @dirtyRect);

      art := art_ptr_lock(obj_^.Fid, @cacheHandle);
      if art <> nil then
      begin
        if (sad_entry^.flags and ANIM_SAD_REVERSE) <> 0 then
          frame_ := art_frame_max_frame(art) - 1
        else
          frame_ := 0;

        obj_set_frame(obj_, frame_, @v29);
        rect_min_bound(@dirtyRect, @v29, @dirtyRect);

        art_frame_hot(art, obj_^.Frame, obj_^.Rotation, @frameX, @frameY);

        obj_offset(obj_, x + frameX, y + frameY, @v19);
        rect_min_bound(@dirtyRect, @v19, @dirtyRect);

        art_ptr_unlock(cacheHandle);
      end
      else
      begin
        obj_set_frame(obj_, 0, @v29);
        rect_min_bound(@dirtyRect, @v29, @dirtyRect);
      end;

      tile_refresh_rect(@dirtyRect, map_elevation);
    end;
  end;

  anim_in_bk := False;
  object_anim_compact;
end;

// =========================================================================
// object_anim_compact
// =========================================================================
procedure object_anim_compact;
var
  index, v2: Integer;
begin
  for index := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
  begin
    if (anim_set[index].flags and ANIM_SEQ_0x20) <> 0 then
      anim_set[index].flags := 0;
  end;

  index := 0;
  while index < curr_sad do
  begin
    if sad[index].field_20 = -1000 then
    begin
      v2 := index + 1;
      while v2 < curr_sad do
      begin
        if sad[v2].field_20 <> -1000 then
          Break;
        Inc(v2);
      end;

      if v2 = curr_sad then
        Break;

      if index <> v2 then
      begin
        Move(sad[v2], sad[index], SizeOf(TAnimationSad));
        sad[v2].field_20 := -1000;
        sad[v2].flags := 0;
      end;
    end;
    Inc(index);
  end;
  curr_sad := index;
end;

// =========================================================================
// check_move
// =========================================================================
function check_move(a1: PInteger): Integer;
var
  x, y: Integer;
  tile: Integer;
  hitMode: Integer;
  aiming: Boolean;
  v6: Integer;
  interruptWalk: Boolean;
begin
  mouse_get_position(@x, @y);

  tile := tile_num(x, y, map_elevation);
  if tile = -1 then
    Exit(-1);

  if isInCombat then
  begin
    if a1^ <> -1 then
    begin
      if (keys[SDL_SCANCODE_RCTRL] <> 0) or (keys[SDL_SCANCODE_LCTRL] <> 0) then
      begin
        hitMode := 0;
        aiming := False;
        intface_get_attack(@hitMode, @aiming);

        v6 := item_mp_cost(obj_dude, hitMode, aiming);
        a1^ := a1^ - v6;
        if a1^ <= 0 then
          Exit(-1);
      end;
    end;
  end
  else
  begin
    interruptWalk := False;
    configGetBool(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_INTERRUPT_WALK_KEY, @interruptWalk);
    if interruptWalk then
      register_clear(obj_dude);
  end;

  Result := tile;
end;

// =========================================================================
// dude_move
// =========================================================================
function dude_move(a1: Integer): Integer;
var
  dest: Integer;
  action_points: Integer;
begin
  action_points := a1;
  dest := check_move(@action_points);
  if dest = -1 then
    Exit(-1);

  if dude_move_lastDestination = dest then
    Exit(dude_run(action_points));

  dude_move_lastDestination := dest;

  register_begin(ANIMATION_REQUEST_RESERVED);
  register_object_move_to_tile(obj_dude, dest, obj_dude^.Elevation, action_points, 0);
  Result := register_end;
end;

// =========================================================================
// dude_run
// =========================================================================
function dude_run(a1: Integer): Integer;
var
  dest: Integer;
  action_points: Integer;
begin
  action_points := a1;
  dest := check_move(@action_points);
  if dest = -1 then
    Exit(-1);

  if perk_level(PERK_SILENT_RUNNING) = 0 then
    pc_flag_off(PC_FLAG_SNEAKING);

  register_begin(ANIMATION_REQUEST_RESERVED);
  register_object_run_to_tile(obj_dude, dest, obj_dude^.Elevation, action_points, 0);
  Result := register_end;
end;

// =========================================================================
// dude_fidget
// =========================================================================
procedure dude_fidget;
var
  now_: LongWord;
  count: Integer;
  obj_: PObject;
  rect_: TRect;
  intersection: TRect;
  r: Integer;
  v8: Boolean;
  v15: array[0..15] of AnsiChar;
  sfx: PAnsiChar;
  v13: Integer;
begin
  if game_user_wants_to_quit <> 0 then
    Exit;

  if isInCombat then
    Exit;

  if vcr_status <> VCR_STATE_TURNED_OFF then
    Exit;

  if (obj_dude^.Flags and OBJECT_HIDDEN) <> 0 then
    Exit;

  now_ := get_bk_time;
  if elapsed_tocks(now_, dude_fidget_last_time) <= dude_fidget_next_time then
    Exit;

  dude_fidget_last_time := now_;

  count := 0;
  obj_ := obj_find_first_at(obj_dude^.Elevation);
  while obj_ <> nil do
  begin
    if count >= 100 then
      Break;

    if ((obj_^.Flags and OBJECT_HIDDEN) = 0) and
       (FID_TYPE(obj_^.Fid) = OBJ_TYPE_CRITTER) and
       (FID_ANIM_TYPE(obj_^.Fid) = ANIM_STAND) and
       (not critter_is_dead(obj_)) then
    begin
      obj_bound(obj_, @rect_);

      if rect_inside_bound(@rect_, @scr_size, @intersection) = 0 then
      begin
        fidget_ptr[count] := obj_;
        Inc(count);
      end;
    end;

    obj_ := obj_find_next_at;
  end;

  if count <> 0 then
  begin
    r := roll_random(0, count - 1);
    obj_ := fidget_ptr[r];

    register_begin(ANIMATION_REQUEST_UNRESERVED or ANIMATION_REQUEST_INSIGNIFICANT);

    v8 := False;
    if obj_ = obj_dude then
      v8 := True
    else
    begin
      v15[0] := #0;
      art_get_base_name(1, obj_^.Fid and $FFF, @v15[0]);
      if (v15[0] = 'm') or (v15[0] = 'M') then
      begin
        if obj_dist(obj_, obj_dude) < stat_level(obj_dude, STAT_PERCEPTION) * 2 then
          v8 := True;
      end;
    end;

    if v8 then
    begin
      sfx := gsnd_build_character_sfx_name(obj_, ANIM_STAND, CHARACTER_SOUND_EFFECT_UNUSED);
      register_object_play_sfx(obj_, sfx, 0);
    end;

    register_object_animate(obj_, ANIM_STAND, 0);
    register_end;

    v13 := 20 div count;
  end
  else
    v13 := 7;

  if v13 < 1 then
    v13 := 1
  else if v13 > 7 then
    v13 := 7;

  dude_fidget_next_time := LongWord(roll_random(0, 3000)) + LongWord(1000 * v13);
end;

// =========================================================================
// dude_stand
// =========================================================================
procedure dude_stand(obj: PObject; rotation, fid: Integer);
var
  rect_, temp: TRect;
  x, y: Integer;
  weaponAnimationCode: Integer;
  takeOutFid: Integer;
  takeOutFrmHandle: PCacheEntry;
  takeOutFrm: PArt;
  frameCount: Integer;
  frame_: Integer;
  offsetX, offsetY: Integer;
  standFrmHandle: PCacheEntry;
  standFid: Integer;
  standFrm: PArt;
  anim_: Integer;
begin
  obj_set_rotation(obj, rotation, @rect_);

  x := 0;
  y := 0;

  weaponAnimationCode := (obj^.Fid and $F000) shr 12;
  if weaponAnimationCode <> 0 then
  begin
    if fid = -1 then
    begin
      takeOutFid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_TAKE_OUT,
                           weaponAnimationCode, obj^.Rotation + 1);
      takeOutFrmHandle := nil;
      takeOutFrm := art_ptr_lock(takeOutFid, @takeOutFrmHandle);
      if takeOutFrm <> nil then
      begin
        frameCount := art_frame_max_frame(takeOutFrm);
        for frame_ := 0 to frameCount - 1 do
        begin
          art_frame_hot(takeOutFrm, frame_, obj^.Rotation, @offsetX, @offsetY);
          x := x + offsetX;
          y := y + offsetY;
        end;
        art_ptr_unlock(takeOutFrmHandle);

        standFrmHandle := nil;
        standFid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, ANIM_STAND, 0, obj^.Rotation + 1);
        standFrm := art_ptr_lock(standFid, @standFrmHandle);
        if standFrm <> nil then
        begin
          if art_frame_offset(standFrm, obj^.Rotation, @offsetX, @offsetY) = 0 then
          begin
            x := x + offsetX;
            y := y + offsetY;
          end;
          art_ptr_unlock(standFrmHandle);
        end;
      end;
    end;
  end;

  if fid = -1 then
  begin
    if FID_ANIM_TYPE(obj^.Fid) = ANIM_FIRE_DANCE then
      anim_ := ANIM_FIRE_DANCE
    else
      anim_ := ANIM_STAND;
    fid := art_id(FID_TYPE(obj^.Fid), obj^.Fid and $FFF, anim_,
                  (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  end;

  obj_change_fid(obj, fid, @temp);
  rect_min_bound(@rect_, @temp, @rect_);

  obj_move_to_tile(obj, obj^.Tile, obj^.Elevation, @temp);
  rect_min_bound(@rect_, @temp, @rect_);

  obj_set_frame(obj, 0, @temp);
  rect_min_bound(@rect_, @temp, @rect_);

  obj_offset(obj, x, y, @temp);
  rect_min_bound(@rect_, @temp, @rect_);

  tile_refresh_rect(@rect_, obj^.Elevation);
end;

// =========================================================================
// dude_standup
// =========================================================================
procedure dude_standup(a1: PObject);
var
  anim_: Integer;
begin
  register_begin(ANIMATION_REQUEST_RESERVED);

  if FID_ANIM_TYPE(a1^.Fid) = ANIM_FALL_BACK then
    anim_ := ANIM_BACK_TO_STANDING
  else
    anim_ := ANIM_PRONE_TO_STANDING;

  register_object_animate(a1, anim_, 0);
  register_end;
  a1^.Data.AsData.Critter.Combat.Results :=
    a1^.Data.AsData.Critter.Combat.Results and (not DAM_KNOCKED_DOWN);
end;

// =========================================================================
// anim_turn_towards (static)
// =========================================================================
function anim_turn_towards(obj: PObject; delta, animationSequenceIndex: Integer): Integer;
var
  rotation_: Integer;
begin
  if not critter_is_prone(obj) then
  begin
    rotation_ := obj^.Rotation + delta;
    if rotation_ >= Integer(ROTATION_COUNT) then
      rotation_ := Integer(ROTATION_NE)
    else if rotation_ < 0 then
      rotation_ := Integer(ROTATION_NW);

    dude_stand(obj, rotation_, -1);
  end;

  anim_set_continue(animationSequenceIndex, 0);
  Result := 0;
end;

// =========================================================================
// anim_hide
// =========================================================================
function anim_hide(obj: PObject; animationSequenceIndex: Integer): Integer;
var
  rect_: TRect;
begin
  if obj_turn_off(obj, @rect_) = 0 then
    tile_refresh_rect(@rect_, obj^.Elevation);

  if animationSequenceIndex <> -1 then
    anim_set_continue(animationSequenceIndex, 0);

  Result := 0;
end;

// =========================================================================
// anim_change_fid
// =========================================================================
function anim_change_fid(obj: PObject; animationSequenceIndex, fid: Integer): Integer;
var
  rect_, v7: TRect;
begin
  if FID_ANIM_TYPE(fid) <> 0 then
  begin
    obj_change_fid(obj, fid, @rect_);
    obj_set_frame(obj, 0, @v7);
    rect_min_bound(@rect_, @v7, @rect_);
    tile_refresh_rect(@rect_, obj^.Elevation);
  end
  else
    dude_stand(obj, obj^.Rotation, fid);

  anim_set_continue(animationSequenceIndex, 0);
  Result := 0;
end;

// =========================================================================
// anim_stop
// =========================================================================
procedure anim_stop;
var
  index: Integer;
begin
  anim_in_anim_stop := True;
  curr_anim_set := -1;

  for index := 0 to ANIMATION_SEQUENCE_LIST_CAPACITY - 1 do
    anim_set_end(index);

  anim_in_anim_stop := False;
  curr_sad := 0;
end;

// =========================================================================
// check_gravity
// =========================================================================
function check_gravity(tile, elevation: Integer): Integer;
var
  x, y: Integer;
  squareTile: Integer;
  fid: Integer;
begin
  while elevation > 0 do
  begin
    tile_coord(tile, @x, @y, elevation);

    squareTile := square_num(x + 2, y + 8, elevation);
    fid := art_id(OBJ_TYPE_TILE, square[elevation]^.field_0[squareTile] and $FFF, 0, 0, 0);
    if fid <> art_id(OBJ_TYPE_TILE, 1, 0, 0, 0) then
      Break;

    Dec(elevation);
  end;
  Result := elevation;
end;

// =========================================================================
// compute_tpf
// =========================================================================
function compute_tpf(obj: PObject; fid: Integer): LongWord;
var
  fps: Integer;
  handle: PCacheEntry;
  frm: PArt;
  playerSpeedup: Integer;
  combatSpeed: Integer;
begin
  handle := nil;
  frm := art_ptr_lock(fid, @handle);
  if frm <> nil then
  begin
    fps := art_frame_fps(frm);
    art_ptr_unlock(handle);
  end
  else
    fps := 10;

  if isInCombat then
  begin
    if FID_ANIM_TYPE(fid) = ANIM_WALK then
    begin
      playerSpeedup := 0;
      config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY,
                       GAME_CONFIG_PLAYER_SPEEDUP_KEY, @playerSpeedup);

      if (obj <> obj_dude) or (playerSpeedup = 1) then
      begin
        combatSpeed := 0;
        config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY,
                         GAME_CONFIG_COMBAT_SPEED_KEY, @combatSpeed);
        fps := fps + combatSpeed;
      end;
    end;
  end;

  Result := LongWord(1000 div fps);
end;

end.
