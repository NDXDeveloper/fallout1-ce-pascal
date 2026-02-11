unit u_actions;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/actions.h + actions.cc
// Player/NPC actions: attack, use items, pick up, loot, talk, explode, skill use, etc.

interface

uses
  u_object_types,
  u_combat_defs,
  u_proto_types;

var
  rotation: LongWord;
  obj_fid: Integer;
  obj_pid_old: Integer;

procedure switch_dude;
function action_knockback(obj: PObject; anim: PInteger; maxDistance: Integer; rotation_: Integer; delay: Integer): Integer;
function action_blood(obj: PObject; anim: Integer; delay: Integer): Integer;
procedure show_damage_to_object(defender: PObject; damage: Integer; flags: Integer; weapon: PObject; hit_from_front: Boolean; knockback_distance: Integer; knockback_rotation: Integer; a8: Integer; attacker: PObject; delay: Integer);
function show_damage_target(attack: PAttack): Integer;
function show_damage_extras(attack: PAttack): Integer;
procedure show_damage(attack: PAttack; a2: Integer; delay: Integer);
function action_attack(attack: PAttack): Integer;
function use_an_object(item: PObject): Integer;
function a_use_obj(a1: PObject; a2: PObject; a3: PObject): Integer;
function action_use_an_item_on_object(critter: PObject; item: PObject; target: PObject): Integer;
function action_use_an_object(critter: PObject; item: PObject): Integer;
function get_an_object(item: PObject): Integer;
function action_get_an_object(critter: PObject; item: PObject): Integer;
function action_loot_container(critter: PObject; container: PObject): Integer;
function action_skill_use(skill: Integer): Integer;
function action_use_skill_in_combat_error(critter: PObject): Integer;
function action_use_skill_on(a1: PObject; a2: PObject; skill: Integer): Integer;
function pick_object(objectType: Integer; a2: Boolean): PObject;
function pick_hex: Integer;
function is_hit_from_front(a1: PObject; a2: PObject): Boolean;
function can_see(a1: PObject; a2: PObject): Boolean;
function pick_fall(obj: PObject; anim: Integer): Integer;
function action_explode(tile: Integer; elevation: Integer; minDamage: Integer; maxDamage: Integer; a5: PObject; premature: Boolean): Integer;
function action_talk_to(a1: PObject; a2: PObject): Integer;
procedure action_dmg(tile: Integer; elevation: Integer; minDamage: Integer; maxDamage: Integer; damageType: Integer; animated: Boolean; bypassArmor: Boolean);

implementation

uses
  SysUtils,
  u_anim,
  u_config,
  u_gconfig,
  u_roll,
  u_item,
  u_stat,
  u_stat_defs,
  u_skill_defs,
  u_critter,
  u_combatai,
  u_trait,
  u_proto,
  u_protinst,
  u_art,
  u_rect,
  u_object,
  u_gsound,
  u_combat,
  u_scripts,
  u_intface,
  u_display,
  u_message,
  u_gmouse,
  u_input,
  u_mouse,
  u_game,
  u_map,
  u_svga,
  u_memory,
  u_tile,
  u_debug;

// =========================================================================
// Constants
// =========================================================================
const
  ROTATION_COUNT = 6;

  MOUSE_EVENT_LEFT_BUTTON_REPEAT = $04;
  MOUSE_EVENT_LEFT_BUTTON_UP     = $10;
  MOUSE_EVENT_LEFT_BUTTON_DOWN   = $01;
  MOUSE_EVENT_RIGHT_BUTTON_DOWN  = $20;

  MOUSE_CURSOR_ARROW = 1;
  MOUSE_CURSOR_PLUS  = 2;

  PC_FLAG_SNEAKING = 0;

  // WeaponSoundEffect (from gsound.h)
  WEAPON_SOUND_EFFECT_READY       = 0;
  WEAPON_SOUND_EFFECT_ATTACK      = 1;
  WEAPON_SOUND_EFFECT_OUT_OF_AMMO = 2;
  WEAPON_SOUND_EFFECT_AMMO_FLYING = 3;
  WEAPON_SOUND_EFFECT_HIT         = 4;

  // CharacterSoundEffect (from gsound.h)
  CHARACTER_SOUND_EFFECT_UNUSED    = 0;
  CHARACTER_SOUND_EFFECT_KNOCKDOWN = 1;
  CHARACTER_SOUND_EFFECT_PASS_OUT  = 2;
  CHARACTER_SOUND_EFFECT_DIE       = 3;
  CHARACTER_SOUND_EFFECT_CONTACT   = 4;

// =========================================================================
// External declarations that must be kept
// =========================================================================
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// =========================================================================
// Module-level variables (C++ static)
// =========================================================================
var
  action_in_explode: Boolean = False;

  death_2: array[0..DAMAGE_TYPE_COUNT - 1] of Integer = (
    ANIM_DANCING_AUTOFIRE,
    ANIM_SLICED_IN_HALF,
    ANIM_CHARRED_BODY,
    ANIM_CHARRED_BODY,
    ANIM_ELECTRIFY,
    ANIM_FALL_BACK,
    ANIM_BIG_HOLE
  );

  death_3: array[0..DAMAGE_TYPE_COUNT - 1] of Integer = (
    ANIM_CHUNKS_OF_FLESH,
    ANIM_SLICED_IN_HALF,
    ANIM_FIRE_DANCE,
    ANIM_MELTED_TO_NOTHING,
    ANIM_ELECTRIFIED_TO_NOTHING,
    ANIM_FALL_BACK,
    ANIM_EXPLODED_TO_NOTHING
  );

// =========================================================================
// Forward declarations for static functions
// =========================================================================
function pick_death(attacker: PObject; defender: PObject; damage: Integer; damage_type: Integer; anim: Integer; hit_from_front: Boolean): Integer; forward;
function check_death(obj: PObject; anim: Integer; min_violence_level: Integer; hit_from_front: Boolean): Integer; forward;
function internal_destroy(a1: PObject; a2: PObject): Integer; forward;
function show_death(obj: PObject; anim: Integer): Integer; forward;
function action_melee(attack: PAttack; anim: Integer): Integer; forward;
function action_ranged(attack: PAttack; anim: Integer): Integer; forward;
function is_next_to(a1: PObject; a2: PObject): Integer; forward;
function action_climb_ladder(a1: PObject; a2: PObject): Integer; forward;
function report_explosion(attack: PAttack; a2: PObject): Integer; forward;
function finished_explosion(a1: PObject; a2: PObject): Integer; forward;
function compute_explosion_damage(min_: Integer; max_: Integer; a3: PObject; a4: PInteger): Integer; forward;
function can_talk_to(a1: PObject; a2: PObject): Integer; forward;
function talk_to(a1: PObject; a2: PObject): Integer; forward;
function report_dmg(attack: PAttack; a2: PObject): Integer; forward;
function compute_dmg_damage(min_damage: Integer; max_damage: Integer; obj: PObject; knockback_distance: PInteger; damage_type: Integer): Integer; forward;

// =========================================================================
// Implementation
// =========================================================================

// 0x410410
procedure switch_dude;
var
  critter: PObject;
  gender: Integer;
begin
  critter := pick_object(OBJ_TYPE_CRITTER, False);
  if critter <> nil then
  begin
    gender := stat_level(critter, Ord(STAT_GENDER));
    stat_set_base(obj_dude, Ord(STAT_GENDER), gender);

    obj_dude := critter;
    obj_fid := critter^.Fid;
    obj_pid_old := critter^.Pid;
    critter^.Pid := $1000000;
  end;
end;

// 0x410468
function action_knockback(obj: PObject; anim: PInteger; maxDistance: Integer; rotation_: Integer; delay: Integer): Integer;
var
  fid: Integer;
  distance: Integer;
  tile: Integer;
  soundEffectName: PAnsiChar;
  d: Integer;
begin
  if anim^ = ANIM_FALL_FRONT then
  begin
    fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, anim^, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
    if not art_exists(fid) then
      anim^ := ANIM_FALL_BACK;
  end;

  tile := 0;
  distance := 0;
  d := 1;
  while d <= maxDistance do
  begin
    tile := tile_num_in_direction(obj^.Tile, rotation_, d);
    if obj_blocking_at(obj, tile, obj^.Elevation) <> nil then
    begin
      distance := d - 1;
      Break;
    end;
    distance := d;
    Inc(d);
  end;

  soundEffectName := gsnd_build_character_sfx_name(obj, anim^, CHARACTER_SOUND_EFFECT_KNOCKDOWN);
  register_object_play_sfx(obj, soundEffectName, delay);

  // Step back
  Dec(distance);

  if distance <= 0 then
  begin
    tile := obj^.Tile;
    register_object_animate(obj, anim^, 0);
  end
  else
  begin
    tile := tile_num_in_direction(obj^.Tile, rotation_, distance);
    register_object_animate_and_move_straight(obj, tile, obj^.Elevation, anim^, 0);
  end;

  Result := tile;
end;

// 0x410548
function action_blood(obj: PObject; anim: Integer; delay: Integer): Integer;
var
  violence_level: Integer;
  bloodyAnim: Integer;
  fid: Integer;
begin
  violence_level := VIOLENCE_LEVEL_MAXIMUM_BLOOD;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violence_level);
  if violence_level = VIOLENCE_LEVEL_NONE then
  begin
    Result := anim;
    Exit;
  end;

  if anim = ANIM_FALL_BACK then
    bloodyAnim := ANIM_FALL_BACK_BLOOD
  else if anim = ANIM_FALL_FRONT then
    bloodyAnim := ANIM_FALL_FRONT_BLOOD
  else
  begin
    Result := anim;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, bloodyAnim, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  if art_exists(fid) then
    register_object_animate(obj, bloodyAnim, delay)
  else
    bloodyAnim := anim;

  Result := bloodyAnim;
end;

// 0x4105EC
function pick_death(attacker: PObject; defender: PObject; damage: Integer; damage_type: Integer; anim: Integer; hit_from_front: Boolean): Integer;
var
  violence_level: Integer;
  has_bloody_mess: Boolean;
  death_anim: Integer;
begin
  violence_level := VIOLENCE_LEVEL_MAXIMUM_BLOOD;
  has_bloody_mess := False;

  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violence_level);

  if (defender^.Pid = 16777239) or (defender^.Pid = 16777266) or (defender^.Pid = 16777265) then
  begin
    Result := check_death(defender, ANIM_EXPLODED_TO_NOTHING, VIOLENCE_LEVEL_NORMAL, hit_from_front);
    Exit;
  end;

  if attacker = obj_dude then
  begin
    if trait_level(TRAIT_BLOODY_MESS) <> 0 then
      has_bloody_mess := True;
  end;

  if (anim = ANIM_THROW_PUNCH)
    or (anim = ANIM_KICK_LEG)
    or (anim = ANIM_THRUST_ANIM)
    or (anim = ANIM_SWING_ANIM)
    or (anim = ANIM_THROW_ANIM) then
  begin
    if (violence_level = VIOLENCE_LEVEL_MAXIMUM_BLOOD) and has_bloody_mess then
      death_anim := ANIM_BIG_HOLE
    else
      death_anim := ANIM_FALL_BACK;
  end
  else if (anim = ANIM_FIRE_SINGLE) and (damage_type = DAMAGE_TYPE_NORMAL) then
  begin
    if (violence_level = VIOLENCE_LEVEL_MAXIMUM_BLOOD) and (has_bloody_mess or (damage >= 45)) then
      death_anim := ANIM_BIG_HOLE
    else
      death_anim := ANIM_FALL_BACK;
  end
  else
  begin
    if (violence_level > VIOLENCE_LEVEL_NORMAL) and (has_bloody_mess or (damage >= 45)) then
    begin
      death_anim := death_3[damage_type];
      if check_death(defender, death_anim, VIOLENCE_LEVEL_MAXIMUM_BLOOD, hit_from_front) <> death_anim then
        death_anim := death_2[damage_type];
    end
    else if (violence_level > VIOLENCE_LEVEL_MINIMAL) and (has_bloody_mess or (damage >= 15)) then
      death_anim := death_2[damage_type]
    else
      death_anim := ANIM_FALL_BACK;
  end;

  if (not hit_from_front) and (death_anim = ANIM_FALL_BACK) then
    death_anim := ANIM_FALL_FRONT;

  Result := check_death(defender, death_anim, VIOLENCE_LEVEL_NONE, hit_from_front);
end;

// 0x410754
function check_death(obj: PObject; anim: Integer; min_violence_level: Integer; hit_from_front: Boolean): Integer;
var
  fid: Integer;
  violence_level: Integer;
begin
  violence_level := VIOLENCE_LEVEL_MAXIMUM_BLOOD;

  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violence_level);
  if violence_level >= min_violence_level then
  begin
    fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, anim, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
    if art_exists(fid) then
    begin
      Result := anim;
      Exit;
    end;
  end;

  if hit_from_front then
  begin
    Result := ANIM_FALL_BACK;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, ANIM_FALL_FRONT, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
  if art_exists(fid) then
    Result := ANIM_FALL_BACK
  else
    Result := ANIM_FALL_FRONT;
end;

// 0x410808
function internal_destroy(a1: PObject; a2: PObject): Integer;
begin
  Result := obj_destroy(a2);
end;

// 0x410810
procedure show_damage_to_object(defender: PObject; damage: Integer; flags: Integer; weapon: PObject; hit_from_front: Boolean; knockback_distance: Integer; knockback_rotation: Integer; a8: Integer; attacker: PObject; delay: Integer);
var
  anim: Integer;
  fid: Integer;
  sfx_name: PAnsiChar;
  randomDistance: Integer;
  randomRotation: Integer;
  v35: PObject;
  tile: Integer;
begin
  anim := FID_ANIM_TYPE(defender^.Fid);
  if not critter_is_prone(defender) then
  begin
    if (flags and DAM_DEAD) <> 0 then
    begin
      fid := art_id(OBJ_TYPE_MISC, 10, 0, 0, 0);
      if fid = attacker^.Fid then
        anim := check_death(defender, ANIM_EXPLODED_TO_NOTHING, VIOLENCE_LEVEL_MAXIMUM_BLOOD, hit_from_front)
      else if attacker^.Pid = PROTO_ID_0x20001EB then
        anim := check_death(defender, ANIM_ELECTRIFIED_TO_NOTHING, VIOLENCE_LEVEL_MAXIMUM_BLOOD, hit_from_front)
      else if attacker^.Fid = FID_0x20001F5 then
        anim := check_death(defender, a8, VIOLENCE_LEVEL_MAXIMUM_BLOOD, hit_from_front)
      else
        anim := pick_death(attacker, defender, damage, item_w_damage_type(weapon), a8, hit_from_front);

      if anim <> ANIM_FIRE_DANCE then
      begin
        if (knockback_distance <> 0) and ((anim = ANIM_FALL_FRONT) or (anim = ANIM_FALL_BACK)) then
        begin
          action_knockback(defender, @anim, knockback_distance, knockback_rotation, delay);
          anim := action_blood(defender, anim, -1);
        end
        else
        begin
          sfx_name := gsnd_build_character_sfx_name(defender, anim, CHARACTER_SOUND_EFFECT_DIE);
          register_object_play_sfx(defender, sfx_name, delay);

          anim := pick_fall(defender, anim);
          register_object_animate(defender, anim, 0);

          if (anim = ANIM_FALL_FRONT) or (anim = ANIM_FALL_BACK) then
            anim := action_blood(defender, anim, -1);
        end;
      end
      else
      begin
        fid := art_id(OBJ_TYPE_CRITTER, defender^.Fid and $FFF, ANIM_FIRE_DANCE, (defender^.Fid and $F000) shr 12, defender^.Rotation + 1);
        if art_exists(fid) then
        begin
          sfx_name := gsnd_build_character_sfx_name(defender, anim, CHARACTER_SOUND_EFFECT_UNUSED);
          register_object_play_sfx(defender, sfx_name, delay);

          register_object_animate(defender, anim, 0);

          randomDistance := roll_random(2, 5);
          randomRotation := roll_random(0, 5);

          while randomDistance > 0 do
          begin
            tile := tile_num_in_direction(defender^.Tile, randomRotation, randomDistance);
            v35 := nil;
            make_straight_path(defender, defender^.Tile, tile, nil, @v35, 4);
            if v35 = nil then
            begin
              register_object_turn_towards(defender, tile);
              register_object_move_straight_to_tile(defender, tile, defender^.Elevation, anim, 0);
              Break;
            end;
            Dec(randomDistance);
          end;
        end;

        anim := ANIM_BURNED_TO_NOTHING;
        sfx_name := gsnd_build_character_sfx_name(defender, anim, CHARACTER_SOUND_EFFECT_UNUSED);
        register_object_play_sfx(defender, sfx_name, -1);
        register_object_animate(defender, anim, 0);
      end;
    end
    else
    begin
      if (flags and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) <> 0 then
      begin
        if hit_from_front then
          anim := ANIM_FALL_BACK
        else
          anim := ANIM_FALL_FRONT;

        sfx_name := gsnd_build_character_sfx_name(defender, anim, CHARACTER_SOUND_EFFECT_UNUSED);
        register_object_play_sfx(defender, sfx_name, delay);
        if knockback_distance <> 0 then
          action_knockback(defender, @anim, knockback_distance, knockback_rotation, 0)
        else
        begin
          anim := pick_fall(defender, anim);
          register_object_animate(defender, anim, 0);
        end;
      end
      else if ((flags and DAM_ON_FIRE) <> 0) and art_exists(art_id(OBJ_TYPE_CRITTER, defender^.Fid and $FFF, ANIM_FIRE_DANCE, (defender^.Fid and $F000) shr 12, defender^.Rotation + 1)) then
      begin
        register_object_animate(defender, ANIM_FIRE_DANCE, delay);

        fid := art_id(OBJ_TYPE_CRITTER, defender^.Fid and $FFF, ANIM_STAND, (defender^.Fid and $F000) shr 12, defender^.Rotation + 1);
        register_object_change_fid(defender, fid, -1);
      end
      else
      begin
        if knockback_distance <> 0 then
        begin
          if hit_from_front then
            anim := ANIM_FALL_BACK
          else
            anim := ANIM_FALL_FRONT;
          action_knockback(defender, @anim, knockback_distance, knockback_rotation, delay);
          if anim = ANIM_FALL_BACK then
            register_object_animate(defender, ANIM_BACK_TO_STANDING, -1)
          else
            register_object_animate(defender, ANIM_PRONE_TO_STANDING, -1);
        end
        else
        begin
          if hit_from_front or (not art_exists(art_id(OBJ_TYPE_CRITTER, defender^.Fid and $FFF, ANIM_HIT_FROM_BACK, (defender^.Fid and $F000) shr 12, defender^.Rotation + 1))) then
            anim := ANIM_HIT_FROM_FRONT
          else
            anim := ANIM_HIT_FROM_BACK;

          sfx_name := gsnd_build_character_sfx_name(defender, anim, CHARACTER_SOUND_EFFECT_UNUSED);
          register_object_play_sfx(defender, sfx_name, delay);

          register_object_animate(defender, anim, 0);
        end;
      end;
    end;
  end
  else
  begin
    if ((flags and DAM_DEAD) <> 0) and ((defender^.Data.AsData.Critter.Combat.Results and DAM_DEAD) = 0) then
      anim := action_blood(defender, anim, delay)
    else
      Exit;
  end;

  if weapon <> nil then
  begin
    if (flags and DAM_EXPLODE) <> 0 then
    begin
      register_object_must_call(defender, weapon, TAnimationCallback(@obj_drop), -1);
      fid := art_id(OBJ_TYPE_MISC, 10, 0, 0, 0);
      register_object_change_fid(weapon, fid, 0);
      register_object_animate_and_hide(weapon, ANIM_STAND, 0);

      sfx_name := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_HIT, weapon, HIT_MODE_RIGHT_WEAPON_PRIMARY, defender);
      register_object_play_sfx(weapon, sfx_name, 0);

      register_object_must_erase(weapon);
    end
    else if (flags and DAM_DESTROY) <> 0 then
      register_object_must_call(defender, weapon, TAnimationCallback(@internal_destroy), -1)
    else if (flags and DAM_DROP) <> 0 then
      register_object_must_call(defender, weapon, TAnimationCallback(@obj_drop), -1);
  end;

  if (flags and DAM_DEAD) <> 0 then
    register_object_must_call(defender, Pointer(PtrInt(anim)), TAnimationCallback(@show_death), -1);
end;

// 0x410D50
function show_death(obj: PObject; anim: Integer): Integer;
var
  temp_rect: TRect;
  dirty_rect: TRect;
begin
  obj_bound(obj, @dirty_rect);

  if (obj^.Pid <> 16777266) and (obj^.Pid <> 16777265) and (obj^.Pid <> 16777224) then
  begin
    obj^.Flags := obj^.Flags or OBJECT_NO_BLOCK;
    if obj_toggle_flat(obj, @temp_rect) = 0 then
      rect_min_bound(@dirty_rect, @temp_rect, @dirty_rect);
  end;

  if obj_turn_off_outline(obj, @temp_rect) = 0 then
    rect_min_bound(@dirty_rect, @temp_rect, @dirty_rect);

  if (anim >= ANIM_ELECTRIFIED_TO_NOTHING) and (anim <= ANIM_EXPLODED_TO_NOTHING) then
  begin
    if (obj^.Pid <> 16777265) and (obj^.Pid <> 16777266) and (obj^.Pid <> 16777239) then
      item_drop_all(obj, obj^.Tile);
  end;

  tile_refresh_rect(@dirty_rect, obj^.Elevation);

  Result := 0;
end;

// 0x410E74
function show_damage_target(attack: PAttack): Integer;
var
  frontHit: Integer;
begin
  if FID_TYPE(attack^.defender^.Fid) = OBJ_TYPE_CRITTER then
  begin
    if is_hit_from_front(attack^.attacker, attack^.defender) then
      frontHit := 1
    else
      frontHit := 0;

    register_begin(ANIMATION_REQUEST_RESERVED);
    register_priority(1);
    show_damage_to_object(attack^.defender,
      attack^.defenderDamage,
      attack^.defenderFlags,
      attack^.weapon,
      frontHit <> 0,
      attack^.defenderKnockback,
      tile_dir(attack^.attacker^.Tile, attack^.defender^.Tile),
      item_w_anim(attack^.attacker, attack^.hitMode),
      attack^.attacker,
      0);
    register_end();
  end;

  Result := 0;
end;

// 0x410F18
function show_damage_extras(attack: PAttack): Integer;
var
  index: Integer;
  obj: PObject;
  delta: Integer;
  v6: Integer;
  v8: Integer;
  v9: Integer;
begin
  for index := 0 to attack^.extrasLength - 1 do
  begin
    obj := attack^.extras[index];
    if FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER then
    begin
      delta := attack^.attacker^.Rotation - obj^.Rotation;
      if delta < 0 then
        delta := -delta;

      if (delta <> 0) and (delta <> 1) and (delta <> 5) then
        v6 := 1
      else
        v6 := 0;

      register_begin(ANIMATION_REQUEST_RESERVED);
      register_priority(1);
      v8 := item_w_anim(attack^.attacker, attack^.hitMode);
      v9 := tile_dir(attack^.attacker^.Tile, obj^.Tile);
      show_damage_to_object(obj, attack^.extrasDamage[index], attack^.extrasFlags[index], attack^.weapon, v6 <> 0, attack^.extrasKnockback[index], v9, v8, attack^.attacker, 0);
      register_end();
    end;
  end;

  Result := 0;
end;

// 0x410FD8
procedure show_damage(attack: PAttack; a2: Integer; delay: Integer);
var
  hit_from_front: Boolean;
  index: Integer;
  obj: PObject;
  localDelay: Integer;
begin
  localDelay := delay;

  for index := 0 to attack^.extrasLength - 1 do
  begin
    obj := attack^.extras[index];
    if FID_TYPE(obj^.Fid) = OBJ_TYPE_CRITTER then
    begin
      register_ping(2, localDelay);
      localDelay := 0;
    end;
  end;

  if (attack^.attackerFlags and DAM_HIT) = 0 then
  begin
    if (attack^.attackerFlags and DAM_CRITICAL) <> 0 then
      show_damage_to_object(attack^.attacker, attack^.attackerDamage, attack^.attackerFlags, attack^.weapon, True, 0, 0, a2, attack^.attacker, -1)
    else if (attack^.attackerFlags and DAM_BACKWASH) <> 0 then
      show_damage_to_object(attack^.attacker, attack^.attackerDamage, attack^.attackerFlags, attack^.weapon, True, 0, 0, a2, attack^.attacker, -1);
  end
  else
  begin
    if attack^.defender <> nil then
    begin
      hit_from_front := is_hit_from_front(attack^.attacker, attack^.defender);

      if FID_TYPE(attack^.defender^.Fid) = OBJ_TYPE_CRITTER then
      begin
        if attack^.attacker^.Fid = 33554933 then
          show_damage_to_object(attack^.defender,
            attack^.defenderDamage,
            attack^.defenderFlags,
            attack^.weapon,
            hit_from_front,
            attack^.defenderKnockback,
            tile_dir(attack^.attacker^.Tile, attack^.defender^.Tile),
            a2,
            attack^.attacker, localDelay)
        else
          show_damage_to_object(attack^.defender,
            attack^.defenderDamage,
            attack^.defenderFlags,
            attack^.weapon,
            hit_from_front,
            attack^.defenderKnockback,
            tile_dir(attack^.attacker^.Tile, attack^.defender^.Tile),
            item_w_anim(attack^.attacker, attack^.hitMode),
            attack^.attacker,
            localDelay);
      end;
    end;

    if (attack^.attackerFlags and DAM_DUD) <> 0 then
      show_damage_to_object(attack^.attacker, attack^.attackerDamage, attack^.attackerFlags, attack^.weapon, True, 0, 0, a2, attack^.attacker, -1);
  end;
end;

// 0x411134
function action_attack(attack: PAttack): Integer;
var
  anim: Integer;
  index: Integer;
begin
  if register_clear(attack^.attacker) = -2 then
  begin
    Result := -1;
    Exit;
  end;

  if register_clear(attack^.defender) = -2 then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to attack^.extrasLength - 1 do
  begin
    if register_clear(attack^.extras[index]) = -2 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  anim := item_w_anim(attack^.attacker, attack^.hitMode);
  if (anim < ANIM_FIRE_SINGLE) and (anim <> ANIM_THROW_ANIM) then
    Result := action_melee(attack, anim)
  else
    Result := action_ranged(attack, anim);
end;

// 0x4111C4
function action_melee(attack: PAttack; anim: Integer): Integer;
var
  fid: Integer;
  art: PArt;
  cache_entry: Pointer;
  v17: Integer;
  v18: Integer;
  delta: Integer;
  flag: Integer;
  sfx_name: PAnsiChar;
  sfx_name_temp: array[0..15] of AnsiChar;
begin
  register_begin(ANIMATION_REQUEST_RESERVED);
  register_priority(1);

  fid := art_id(OBJ_TYPE_CRITTER, attack^.attacker^.Fid and $FFF, anim, (attack^.attacker^.Fid and $F000) shr 12, attack^.attacker^.Rotation + 1);
  art := art_ptr_lock(fid, @cache_entry);
  if art <> nil then
    v17 := art_frame_action_frame(art)
  else
    v17 := 0;
  art_ptr_unlock(cache_entry);

  tile_num_in_direction(attack^.attacker^.Tile, attack^.attacker^.Rotation, 1);
  register_object_turn_towards(attack^.attacker, attack^.defender^.Tile);

  delta := attack^.attacker^.Rotation - attack^.defender^.Rotation;
  if delta < 0 then
    delta := -delta;

  if (delta <> 0) and (delta <> 1) and (delta <> 5) then
    flag := 1
  else
    flag := 0;

  if (anim <> ANIM_THROW_PUNCH) and (anim <> ANIM_KICK_LEG) then
    sfx_name := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_ATTACK, attack^.weapon, attack^.hitMode, attack^.defender)
  else
    sfx_name := gsnd_build_character_sfx_name(attack^.attacker, anim, CHARACTER_SOUND_EFFECT_UNUSED);

  StrLCopy(sfx_name_temp, sfx_name, SizeOf(sfx_name_temp) - 1);

  combatai_msg(attack^.attacker, attack, AI_MESSAGE_TYPE_ATTACK, 0);

  if (attack^.attackerFlags and $0300) <> 0 then
  begin
    register_object_play_sfx(attack^.attacker, sfx_name_temp, 0);
    if (anim <> ANIM_THROW_PUNCH) and (anim <> ANIM_KICK_LEG) then
      sfx_name := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_HIT, attack^.weapon, attack^.hitMode, attack^.defender)
    else
      sfx_name := gsnd_build_character_sfx_name(attack^.attacker, anim, CHARACTER_SOUND_EFFECT_CONTACT);

    StrLCopy(sfx_name_temp, sfx_name, SizeOf(sfx_name_temp) - 1);

    register_object_animate(attack^.attacker, anim, 0);
    register_object_play_sfx(attack^.attacker, sfx_name_temp, v17);
    show_damage(attack, anim, 0);
  end
  else
  begin
    if (attack^.defender^.Data.AsData.Critter.Combat.Results and $03) <> 0 then
    begin
      register_object_play_sfx(attack^.attacker, sfx_name_temp, -1);
      register_object_animate(attack^.attacker, anim, 0);
    end
    else
    begin
      fid := art_id(OBJ_TYPE_CRITTER, attack^.defender^.Fid and $FFF, ANIM_DODGE_ANIM, (attack^.defender^.Fid and $F000) shr 12, attack^.defender^.Rotation + 1);
      art := art_ptr_lock(fid, @cache_entry);
      if art <> nil then
      begin
        v18 := art_frame_action_frame(art);
        art_ptr_unlock(cache_entry);

        if v18 <= v17 then
        begin
          register_object_play_sfx(attack^.attacker, sfx_name_temp, -1);
          register_object_animate(attack^.attacker, anim, 0);

          sfx_name := gsnd_build_character_sfx_name(attack^.defender, ANIM_DODGE_ANIM, CHARACTER_SOUND_EFFECT_UNUSED);
          register_object_play_sfx(attack^.defender, sfx_name, v17 - v18);
          register_object_animate(attack^.defender, ANIM_DODGE_ANIM, 0);
        end
        else
        begin
          sfx_name := gsnd_build_character_sfx_name(attack^.defender, ANIM_DODGE_ANIM, CHARACTER_SOUND_EFFECT_UNUSED);
          register_object_play_sfx(attack^.defender, sfx_name, -1);
          register_object_animate(attack^.defender, ANIM_DODGE_ANIM, 0);
          register_object_play_sfx(attack^.attacker, sfx_name_temp, v18 - v17);
          register_object_animate(attack^.attacker, anim, 0);
        end;
      end;
    end;
  end;

  if (attack^.attackerFlags and DAM_HIT) <> 0 then
  begin
    if (attack^.defenderFlags and DAM_DEAD) = 0 then
      combatai_msg(attack^.attacker, attack, AI_MESSAGE_TYPE_HIT, -1);
  end
  else
    combatai_msg(attack^.attacker, attack, AI_MESSAGE_TYPE_MISS, -1);

  if register_end() = -1 then
  begin
    Result := -1;
    Exit;
  end;

  show_damage_extras(attack);

  Result := 0;
end;

// 0x4114DC
function action_ranged(attack: PAttack; anim: Integer): Integer;
var
  neighboors: array[0..5] of PObject;
  projectile: PObject;
  v50: PObject;
  weaponFid: Integer;
  weaponProto: PProto;
  weapon: PObject;
  fid: Integer;
  artHandle: Pointer;
  art: PArt;
  actionFrame: Integer;
  damageType: Integer;
  isGrenade: Boolean;
  sfx: PAnsiChar;
  l56: Boolean;
  projectilePid: Integer;
  projectileProto: PProto;
  projectileOrigin: Integer;
  projectileRotation: Integer;
  v24: Integer;
  explosionFrmId: Integer;
  explosionFid: Integer;
  rot: Integer;
  v31: Integer;
  localDelay: Integer;
  v38: Integer;
  l9: Boolean;
  weaponFlags: Integer;
  index: Integer;
begin
  FillChar(neighboors, SizeOf(neighboors), 0);

  register_begin(ANIMATION_REQUEST_RESERVED);
  register_priority(1);

  projectile := nil;
  v50 := nil;
  weaponFid := -1;

  weapon := attack^.weapon;
  proto_ptr(weapon^.Pid, @weaponProto);

  fid := art_id(OBJ_TYPE_CRITTER, attack^.attacker^.Fid and $FFF, anim, (attack^.attacker^.Fid and $F000) shr 12, attack^.attacker^.Rotation + 1);
  art := art_ptr_lock(fid, @artHandle);
  if art <> nil then
    actionFrame := art_frame_action_frame(art)
  else
    actionFrame := 0;
  art_ptr_unlock(artHandle);

  item_w_range(attack^.attacker, attack^.hitMode);

  damageType := item_w_damage_type(attack^.weapon);

  tile_num_in_direction(attack^.attacker^.Tile, attack^.attacker^.Rotation, 1);

  register_object_turn_towards(attack^.attacker, attack^.defender^.Tile);

  isGrenade := False;
  if anim = ANIM_THROW_ANIM then
  begin
    if (damageType = DAMAGE_TYPE_EXPLOSION) or (damageType = DAMAGE_TYPE_PLASMA) or (damageType = DAMAGE_TYPE_EMP) then
      isGrenade := True;
  end
  else
    register_object_animate(attack^.attacker, ANIM_POINT, -1);

  combatai_msg(attack^.attacker, attack, AI_MESSAGE_TYPE_ATTACK, 0);

  if ((attack^.attacker^.Fid and $F000) shr 12) <> 0 then
    sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_ATTACK, weapon, attack^.hitMode, attack^.defender)
  else
    sfx := gsnd_build_character_sfx_name(attack^.attacker, anim, CHARACTER_SOUND_EFFECT_UNUSED);
  register_object_play_sfx(attack^.attacker, sfx, -1);

  register_object_animate(attack^.attacker, anim, 0);

  if anim <> ANIM_FIRE_CONTINUOUS then
  begin
    if ((attack^.attackerFlags and DAM_HIT) <> 0) or ((attack^.attackerFlags and DAM_CRITICAL) = 0) then
    begin
      l56 := False;

      projectilePid := item_w_proj_pid(weapon);
      if (proto_ptr(projectilePid, @projectileProto) <> -1) and (projectileProto^.Fid <> -1) then
      begin
        if anim = ANIM_THROW_ANIM then
        begin
          projectile := weapon;
          weaponFid := weapon^.Fid;
          weaponFlags := weapon^.Flags;

          item_remove_mult(attack^.attacker, weapon, 1);
          v50 := item_replace(attack^.attacker, weapon, weaponFlags and OBJECT_IN_ANY_HAND);
          obj_change_fid(projectile, projectileProto^.Fid, nil);

          if attack^.attacker = obj_dude then
            intface_update_items(False);

          obj_connect(weapon, attack^.attacker^.Tile, attack^.attacker^.Elevation, nil);
        end
        else
          obj_new(@projectile, projectileProto^.Fid, -1);

        obj_turn_off(projectile, nil);

        obj_set_light(projectile, 9, projectile^.LightIntensity, nil);

        projectileOrigin := combat_bullet_start(attack^.attacker, attack^.defender);
        obj_move_to_tile(projectile, projectileOrigin, attack^.attacker^.Elevation, nil);

        projectileRotation := tile_dir(attack^.attacker^.Tile, attack^.defender^.Tile);
        obj_set_rotation(projectile, projectileRotation, nil);

        register_object_funset(projectile, OBJECT_HIDDEN, actionFrame);

        sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_AMMO_FLYING, weapon, attack^.hitMode, attack^.defender);
        register_object_play_sfx(projectile, sfx, 0);

        if (attack^.attackerFlags and DAM_HIT) <> 0 then
        begin
          register_object_move_straight_to_tile(projectile, attack^.defender^.Tile, attack^.defender^.Elevation, ANIM_WALK, 0);
          actionFrame := make_straight_path(projectile, projectileOrigin, attack^.defender^.Tile, nil, nil, 32) - 1;
          v24 := attack^.defender^.Tile;
        end
        else
        begin
          register_object_move_straight_to_tile(projectile, attack^.tile, attack^.defender^.Elevation, ANIM_WALK, 0);
          actionFrame := 0;
          v24 := attack^.tile;
        end;

        if isGrenade or (damageType = DAMAGE_TYPE_EXPLOSION) then
        begin
          if (attack^.attackerFlags and DAM_DROP) = 0 then
          begin
            if isGrenade then
            begin
              case damageType of
                DAMAGE_TYPE_EMP:    explosionFrmId := 2;
                DAMAGE_TYPE_PLASMA: explosionFrmId := 31;
              else
                explosionFrmId := 29;
              end;
            end
            else
              explosionFrmId := 10;

            if isGrenade then
              register_object_change_fid(projectile, weaponFid, -1);

            explosionFid := art_id(OBJ_TYPE_MISC, explosionFrmId, 0, 0, 0);
            register_object_change_fid(projectile, explosionFid, -1);

            sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_HIT, weapon, attack^.hitMode, attack^.defender);
            register_object_play_sfx(projectile, sfx, 0);

            register_object_animate_and_hide(projectile, ANIM_STAND, 0);

            for rot := 0 to ROTATION_COUNT - 1 do
            begin
              if obj_new(@(neighboors[rot]), explosionFid, -1) <> -1 then
              begin
                obj_turn_off(neighboors[rot], nil);

                v31 := tile_num_in_direction(v24, rot, 1);
                obj_move_to_tile(neighboors[rot], v31, projectile^.Elevation, nil);

                if rot <> Ord(ROTATION_NE) then
                  localDelay := 0
                else
                begin
                  if damageType = DAMAGE_TYPE_PLASMA then
                    localDelay := 4
                  else
                    localDelay := 2;
                end;

                register_object_funset(neighboors[rot], OBJECT_HIDDEN, localDelay);
                register_object_animate_and_hide(neighboors[rot], ANIM_STAND, 0);
              end;
            end;

            l56 := True;
          end;
        end
        else
        begin
          if anim <> ANIM_THROW_ANIM then
            register_object_must_erase(projectile);
        end;

        if not l56 then
        begin
          sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_HIT, weapon, attack^.hitMode, attack^.defender);
          register_object_play_sfx(weapon, sfx, actionFrame);
        end;

        actionFrame := 0;
      end
      else
      begin
        if (attack^.attackerFlags and DAM_HIT) = 0 then
        begin
          if (attack^.defender^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN)) = 0 then
          begin
            register_object_animate(attack^.defender, ANIM_DODGE_ANIM, actionFrame);
            l56 := True;
          end;
        end;
      end;
    end;
  end;

  show_damage(attack, anim, actionFrame);

  if (attack^.attackerFlags and DAM_HIT) = 0 then
    combatai_msg(attack^.defender, attack, AI_MESSAGE_TYPE_MISS, -1)
  else
  begin
    if (attack^.defenderFlags and DAM_DEAD) = 0 then
      combatai_msg(attack^.defender, attack, AI_MESSAGE_TYPE_HIT, -1);
  end;

  if (projectile <> nil) and (isGrenade or (damageType = DAMAGE_TYPE_EXPLOSION)) then
    register_object_must_erase(projectile)
  else if (anim = ANIM_THROW_ANIM) and (projectile <> nil) then
    register_object_change_fid(projectile, weaponFid, -1);

  for rot := 0 to ROTATION_COUNT - 1 do
  begin
    if neighboors[rot] <> nil then
      register_object_must_erase(neighboors[rot]);
  end;

  if (attack^.attackerFlags and (DAM_KNOCKED_OUT or DAM_KNOCKED_DOWN or DAM_DEAD)) = 0 then
  begin
    if anim = ANIM_THROW_ANIM then
    begin
      l9 := False;
      if v50 <> nil then
      begin
        v38 := item_w_anim_code(v50);
        if v38 <> 0 then
        begin
          register_object_take_out(attack^.attacker, v38, -1);
          l9 := True;
        end;
      end;

      if not l9 then
      begin
        fid := art_id(OBJ_TYPE_CRITTER, attack^.attacker^.Fid and $FFF, ANIM_STAND, 0, attack^.attacker^.Rotation + 1);
        register_object_change_fid(attack^.attacker, fid, -1);
      end;
    end
    else
      register_object_animate(attack^.attacker, ANIM_UNPOINT, -1);
  end;

  if register_end() = -1 then
  begin
    debug_printf('Something went wrong with a ranged attack sequence!'#10);
    if (projectile <> nil) and (isGrenade or (damageType = DAMAGE_TYPE_EXPLOSION) or (anim <> ANIM_THROW_ANIM)) then
      obj_erase_object(projectile, nil);

    for rot := 0 to ROTATION_COUNT - 1 do
    begin
      if neighboors[rot] <> nil then
        obj_erase_object(neighboors[rot], nil);
    end;

    Result := -1;
    Exit;
  end;

  show_damage_extras(attack);

  Result := 0;
end;

// 0x411BCC
function use_an_object(item: PObject): Integer;
begin
  Result := action_use_an_object(obj_dude, item);
end;

// 0x411BE4
function is_next_to(a1: PObject; a2: PObject): Integer;
var
  messageListItem: TMessageListItem;
begin
  if obj_dist(a1, a2) > 1 then
  begin
    if a2 = obj_dude then
    begin
      // You cannot get there.
      messageListItem.num := 2000;
      if message_search(@misc_message_file, @messageListItem) then
        display_print(messageListItem.text);
    end;
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// 0x411C30
function action_climb_ladder(a1: PObject; a2: PObject): Integer;
var
  anim: Integer;
  animationRequestOptions: Integer;
  actionPoints: Integer;
  tile: Integer;
  weaponAnimationCode: Integer;
  sfx: PAnsiChar;
begin
  if a1 = obj_dude then
  begin
    anim := FID_ANIM_TYPE(obj_dude^.Fid);
    if (anim = ANIM_WALK) or (anim = ANIM_RUNNING) then
      register_clear(obj_dude);
  end;

  if isInCombat() then
  begin
    animationRequestOptions := ANIMATION_REQUEST_RESERVED;
    actionPoints := a1^.Data.AsData.Critter.Combat.Ap;
  end
  else
  begin
    animationRequestOptions := ANIMATION_REQUEST_UNRESERVED;
    actionPoints := -1;
  end;

  if a1 = obj_dude then
    animationRequestOptions := ANIMATION_REQUEST_RESERVED;

  animationRequestOptions := animationRequestOptions or ANIMATION_REQUEST_NO_STAND;
  register_begin(animationRequestOptions);

  tile := tile_num_in_direction(a2^.Tile, Ord(ROTATION_SE), 1);
  if (actionPoints <> -1) or (obj_dist(a1, a2) < 5) then
    register_object_move_to_tile(a1, tile, a2^.Elevation, actionPoints, 0)
  else
    register_object_run_to_tile(a1, tile, a2^.Elevation, actionPoints, 0);

  register_object_must_call(a1, a2, TAnimationCallback(@is_next_to), -1);
  register_object_turn_towards(a1, a2^.Tile);
  register_object_must_call(a1, a2, TAnimationCallback(@check_scenery_ap_cost), -1);

  weaponAnimationCode := (a1^.Fid and $F000) shr 12;
  if weaponAnimationCode <> 0 then
  begin
    sfx := gsnd_build_character_sfx_name(a1, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
    register_object_play_sfx(a1, sfx, -1);
    register_object_animate(a1, ANIM_PUT_AWAY, 0);
  end;

  sfx := gsnd_build_character_sfx_name(a1, ANIM_CLIMB_LADDER, CHARACTER_SOUND_EFFECT_UNUSED);
  register_object_play_sfx(a1, sfx, -1);
  register_object_animate(a1, ANIM_CLIMB_LADDER, 0);
  register_object_call(a1, a2, TAnimationCallback(@obj_use), -1);

  if weaponAnimationCode <> 0 then
    register_object_take_out(a1, weaponAnimationCode, -1);

  Result := register_end();
end;

// 0x411DA8
function a_use_obj(a1: PObject; a2: PObject; a3: PObject): Integer;
var
  scenery_proto: PProto;
  scenery_type: Integer;
  anim_request_options: Integer;
  action_points: Integer;
  anim: Integer;
  weapon_anim_code: Integer;
  sfx: PAnsiChar;
begin
  scenery_type := -1;

  if FID_TYPE(a2^.Fid) = OBJ_TYPE_SCENERY then
  begin
    if proto_ptr(a2^.Pid, @scenery_proto) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    scenery_type := scenery_proto^.Scenery.SceneryType;
  end;

  if (scenery_type = SCENERY_TYPE_LADDER_UP) and (a3 = nil) then
  begin
    Result := action_climb_ladder(a1, a2);
    Exit;
  end;

  if a1 = obj_dude then
  begin
    anim := FID_ANIM_TYPE(obj_dude^.Fid);
    if (anim = ANIM_WALK) or (anim = ANIM_RUNNING) then
      register_clear(obj_dude);
  end;

  if isInCombat() then
  begin
    anim_request_options := ANIMATION_REQUEST_RESERVED;
    action_points := a1^.Data.AsData.Critter.Combat.Ap;
  end
  else
  begin
    anim_request_options := ANIMATION_REQUEST_UNRESERVED;
    action_points := -1;
  end;

  if a1 = obj_dude then
    anim_request_options := ANIMATION_REQUEST_RESERVED;

  register_begin(anim_request_options);

  if (action_points <> -1) or (obj_dist(a1, a2) < 5) then
    register_object_move_to_object(a1, a2, action_points, 0)
  else
    register_object_run_to_object(a1, a2, -1, 0);

  register_object_must_call(a1, a2, TAnimationCallback(@is_next_to), -1);
  register_object_call(a1, a2, TAnimationCallback(@check_scenery_ap_cost), -1);

  weapon_anim_code := (a1^.Fid and $F000) shr 12;
  if weapon_anim_code <> 0 then
  begin
    sfx := gsnd_build_character_sfx_name(a1, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
    register_object_play_sfx(a1, sfx, -1);
    register_object_animate(a1, ANIM_PUT_AWAY, 0);
  end;

  if (FID_TYPE(a2^.Fid) = OBJ_TYPE_CRITTER) and critter_is_prone(a2) then
    anim := ANIM_MAGIC_HANDS_GROUND
  else if (FID_TYPE(a2^.Fid) = OBJ_TYPE_SCENERY) and ((scenery_proto^.Scenery.ExtendedFlags and $01) <> 0) then
    anim := ANIM_MAGIC_HANDS_GROUND
  else
    anim := ANIM_MAGIC_HANDS_MIDDLE;

  register_object_animate(a1, anim, -1);

  if a3 <> nil then
    register_object_call3(a1, a2, a3, TAnimationCallback3(@obj_use_item_on), -1)
  else
    register_object_call(a1, a2, TAnimationCallback(@obj_use), -1);

  if weapon_anim_code <> 0 then
    register_object_take_out(a1, weapon_anim_code, -1);

  Result := register_end();
end;

// 0x411F2C
function action_use_an_item_on_object(critter: PObject; item: PObject; target: PObject): Integer;
begin
  Result := a_use_obj(critter, item, target);
end;

// 0x411F78
function action_use_an_object(critter: PObject; item: PObject): Integer;
begin
  Result := a_use_obj(critter, item, nil);
end;

// 0x411F84
function get_an_object(item: PObject): Integer;
begin
  Result := action_get_an_object(obj_dude, item);
end;

// 0x411F98
function action_get_an_object(critter: PObject; item: PObject): Integer;
var
  animationCode: Integer;
  itemProto: PProto;
  fid: Integer;
  actionFrame: Integer;
  cacheEntry: Pointer;
  art: PArt;
  sfx: array[0..15] of AnsiChar;
  sfxPtr: PAnsiChar;
  weaponAnimationCode: Integer;
  anim: Integer;
begin
  if FID_TYPE(item^.Fid) <> OBJ_TYPE_ITEM then
  begin
    Result := -1;
    Exit;
  end;

  if critter = obj_dude then
  begin
    animationCode := FID_ANIM_TYPE(obj_dude^.Fid);
    if (animationCode = ANIM_WALK) or (animationCode = ANIM_RUNNING) then
      register_clear(obj_dude);
  end;

  if isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);
    register_object_move_to_object(critter, item, critter^.Data.AsData.Critter.Combat.Ap, 0);
  end
  else
  begin
    if critter = obj_dude then
      register_begin(ANIMATION_REQUEST_RESERVED)
    else
      register_begin(ANIMATION_REQUEST_UNRESERVED);
    if obj_dist(critter, item) >= 5 then
      register_object_run_to_object(critter, item, -1, 0)
    else
      register_object_move_to_object(critter, item, -1, 0);
  end;

  register_object_must_call(critter, item, TAnimationCallback(@is_next_to), -1);
  register_object_call(critter, item, TAnimationCallback(@check_scenery_ap_cost), -1);

  proto_ptr(item^.Pid, @itemProto);

  if (itemProto^.Item.ItemType <> ITEM_TYPE_CONTAINER) or (proto_action_can_pickup(item^.Pid) <> 0) then
  begin
    register_object_animate(critter, ANIM_MAGIC_HANDS_GROUND, 0);

    fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, ANIM_MAGIC_HANDS_GROUND, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);

    art := art_ptr_lock(fid, @cacheEntry);
    if art <> nil then
      actionFrame := art_frame_action_frame(art)
    else
      actionFrame := -1;

    if art_get_base_name(FID_TYPE(item^.Fid), item^.Fid and $FFF, @sfx[0]) = 0 then
      register_object_play_sfx(item, @sfx[0], actionFrame);

    register_object_call(critter, item, TAnimationCallback(@obj_pickup), actionFrame);
  end
  else
  begin
    weaponAnimationCode := (critter^.Fid and $F000) shr 12;
    if weaponAnimationCode <> 0 then
    begin
      sfxPtr := gsnd_build_character_sfx_name(critter, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
      register_object_play_sfx(critter, sfxPtr, -1);
      register_object_animate(critter, ANIM_PUT_AWAY, -1);
    end;

    // ground vs middle animation
    if (itemProto^.Item.Data.Container.OpenFlags and $01) = 0 then
      anim := ANIM_MAGIC_HANDS_MIDDLE
    else
      anim := ANIM_MAGIC_HANDS_GROUND;
    register_object_animate(critter, anim, 0);

    fid := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, anim, 0, critter^.Rotation + 1);

    art := art_ptr_lock(fid, @cacheEntry);
    if art = nil then
    begin
      actionFrame := art_frame_action_frame(art);
      art_ptr_unlock(cacheEntry);
    end
    else
      actionFrame := -1;

    if item^.Pid <> 213 then
      register_object_call(critter, item, TAnimationCallback(@obj_use_container), actionFrame);

    if weaponAnimationCode <> 0 then
      register_object_take_out(critter, weaponAnimationCode, -1);

    if (item^.Frame = 0) or (item^.Pid = 213) then
      register_object_call(critter, item, TAnimationCallback(@scripts_request_loot_container), -1);
  end;

  Result := register_end();
end;

// 0x412254
function action_loot_container(critter: PObject; container: PObject): Integer;
var
  anim: Integer;
begin
  if FID_TYPE(container^.Fid) <> OBJ_TYPE_CRITTER then
  begin
    Result := -1;
    Exit;
  end;

  if critter = obj_dude then
  begin
    anim := FID_ANIM_TYPE(obj_dude^.Fid);
    if (anim = ANIM_WALK) or (anim = ANIM_RUNNING) then
      register_clear(obj_dude);
  end;

  if isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);
    register_object_move_to_object(critter, container, critter^.Data.AsData.Critter.Combat.Ap, 0);
  end
  else
  begin
    if critter = obj_dude then
      register_begin(ANIMATION_REQUEST_RESERVED)
    else
      register_begin(ANIMATION_REQUEST_UNRESERVED);

    if obj_dist(critter, container) < 5 then
      register_object_move_to_object(critter, container, -1, 0)
    else
      register_object_run_to_object(critter, container, -1, 0);
  end;

  register_object_must_call(critter, container, TAnimationCallback(@is_next_to), -1);
  register_object_call(critter, container, TAnimationCallback(@check_scenery_ap_cost), -1);
  register_object_call(critter, container, TAnimationCallback(@scripts_request_loot_container), -1);
  Result := register_end();
end;

// 0x41234C
function action_skill_use(skill: Integer): Integer;
begin
  if skill = Ord(SKILL_SNEAK) then
  begin
    register_clear(obj_dude);
    pc_flag_toggle(PC_FLAG_SNEAKING);
    Result := 0;
    Exit;
  end;

  Result := -1;
end;

// 0x41236C
function action_use_skill_in_combat_error(critter: PObject): Integer;
var
  messageListItem: TMessageListItem;
begin
  if critter = obj_dude then
  begin
    messageListItem.num := 902;
    if message_search(@proto_main_msg_file, @messageListItem) then
      display_print(messageListItem.text);
  end;

  Result := -1;
end;

// 0x4123C8
function action_use_skill_on(a1: PObject; a2: PObject; skill: Integer): Integer;
var
  anim: Integer;
  fid: Integer;
  artHandle: Pointer;
  art: PArt;
begin
  case skill of
    Ord(SKILL_FIRST_AID),
    Ord(SKILL_DOCTOR):
    begin
      if isInCombat() then
      begin
        Result := action_use_skill_in_combat_error(a1);
        Exit;
      end;

      if PID_TYPE(a2^.Pid) <> OBJ_TYPE_CRITTER then
      begin
        Result := -1;
        Exit;
      end;
    end;

    Ord(SKILL_SNEAK):
    begin
      pc_flag_toggle(PC_FLAG_SNEAKING);
      Result := 0;
      Exit;
    end;

    Ord(SKILL_LOCKPICK):
    begin
      if isInCombat() then
      begin
        Result := action_use_skill_in_combat_error(a1);
        Exit;
      end;

      if (PID_TYPE(a2^.Pid) <> OBJ_TYPE_ITEM) and (PID_TYPE(a2^.Pid) <> OBJ_TYPE_SCENERY) then
      begin
        Result := -1;
        Exit;
      end;
    end;

    Ord(SKILL_STEAL):
    begin
      if isInCombat() then
      begin
        Result := action_use_skill_in_combat_error(a1);
        Exit;
      end;

      if (PID_TYPE(a2^.Pid) <> OBJ_TYPE_ITEM) and (PID_TYPE(a2^.Pid) <> OBJ_TYPE_CRITTER) and (a2^.Pid <> $2000384) then
      begin
        Result := -1;
        Exit;
      end;

      if a2 = a1 then
      begin
        Result := -1;
        Exit;
      end;
    end;

    Ord(SKILL_TRAPS):
    begin
      if isInCombat() then
      begin
        Result := action_use_skill_in_combat_error(a1);
        Exit;
      end;

      if PID_TYPE(a2^.Pid) = OBJ_TYPE_CRITTER then
      begin
        Result := -1;
        Exit;
      end;
    end;

    Ord(SKILL_SCIENCE),
    Ord(SKILL_REPAIR):
    begin
      if isInCombat() then
      begin
        Result := action_use_skill_in_combat_error(a1);
        Exit;
      end;

      if PID_TYPE(a2^.Pid) = OBJ_TYPE_CRITTER then
      begin
        if critter_kill_count_type(a2) <> KILL_TYPE_ROBOT then
        begin
          if not ((critter_kill_count_type(a2) = KILL_TYPE_BRAHMIN) and (skill = Ord(SKILL_SCIENCE))) then
          begin
            Result := -1;
            Exit;
          end;
        end;
      end;
    end;
  else
    debug_printf(#10'skill_use: invalid skill used.');
  end;

  if a1 = obj_dude then
  begin
    anim := FID_ANIM_TYPE(a1^.Fid);
    if (anim = ANIM_WALK) or (anim = ANIM_RUNNING) then
      register_clear(a1);
  end;

  if isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);
    register_object_move_to_object(a1, a2, a1^.Data.AsData.Critter.Combat.Ap, 0);
  end
  else
  begin
    if a1 = obj_dude then
      register_begin(ANIMATION_REQUEST_RESERVED)
    else
      register_begin(ANIMATION_REQUEST_UNRESERVED);

    if a2 <> obj_dude then
    begin
      if obj_dist(a1, a2) >= 5 then
        register_object_run_to_object(a1, a2, -1, 0)
      else
        register_object_move_to_object(a1, a2, -1, 0);
    end;
  end;

  register_object_must_call(a1, a2, TAnimationCallback(@is_next_to), -1);

  if (FID_TYPE(a2^.Fid) = OBJ_TYPE_CRITTER) and critter_is_prone(a2) then
    anim := ANIM_MAGIC_HANDS_GROUND
  else
    anim := ANIM_MAGIC_HANDS_MIDDLE;

  fid := art_id(OBJ_TYPE_CRITTER, a1^.Fid and $FFF, anim, 0, a1^.Rotation + 1);

  art := art_ptr_lock(fid, @artHandle);
  if art <> nil then
  begin
    art_frame_action_frame(art);
    art_ptr_unlock(artHandle);
  end;

  register_object_animate(a1, anim, -1);
  register_object_call3(a1, a2, Pointer(PtrInt(skill)), TAnimationCallback3(@obj_use_skill_on), -1);
  Result := register_end();
end;

// 0x412758
function pick_object(objectType: Integer; a2: Boolean): PObject;
var
  foundObject: PObject;
  mouseEvent: Integer;
  keyCode: Integer;
begin
  foundObject := nil;

  repeat
    get_input();
  until (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0;

  gmouse_set_cursor(MOUSE_CURSOR_PLUS);
  gmouse_3d_off();

  keyCode := 0;
  repeat
    if get_input() = -2 then
    begin
      mouseEvent := mouse_get_buttons();
      if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
      begin
        keyCode := 0;
        foundObject := object_under_mouse(objectType, a2, map_elevation);
        Break;
      end;

      if (mouseEvent and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
      begin
        keyCode := $1B; // KEY_ESCAPE
        Break;
      end;
    end;
  until game_user_wants_to_quit <> 0;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  gmouse_3d_on();

  if keyCode = $1B then
  begin
    Result := nil;
    Exit;
  end;

  Result := foundObject;
end;

// 0x4127E0
function pick_hex: Integer;
var
  elevation: Integer;
  inputEvent: Integer;
  tile: Integer;
  rect: TRect;
  mx, my: Integer;
begin
  elevation := map_elevation;

  while True do
  begin
    inputEvent := get_input();
    if inputEvent = -2 then
      Break;

    if inputEvent = 372 then // KEY_CTRL_ARROW_RIGHT
    begin
      rotation := rotation + 1;
      if rotation > 5 then
        rotation := 0;

      obj_set_rotation(obj_mouse, rotation, @rect);
      tile_refresh_rect(@rect, obj_mouse^.Elevation);
    end;

    if inputEvent = 371 then // KEY_CTRL_ARROW_LEFT
    begin
      if rotation = 0 then
        rotation := 5
      else
        rotation := rotation - 1;

      obj_set_rotation(obj_mouse, rotation, @rect);
      tile_refresh_rect(@rect, obj_mouse^.Elevation);
    end;

    if (inputEvent = 329) or (inputEvent = 337) then // KEY_PAGE_UP or KEY_PAGE_DOWN
    begin
      if inputEvent = 329 then
        map_set_elevation(map_elevation + 1)
      else
        map_set_elevation(map_elevation - 1);

      rect.ulx := 30;
      rect.uly := 62;
      rect.lrx := 50;
      rect.lry := 88;
    end;

    if game_user_wants_to_quit <> 0 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  if (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_DOWN) = 0 then
  begin
    Result := -1;
    Exit;
  end;

  if not mouse_click_in(0, 0, scr_size.lrx - scr_size.ulx, scr_size.lry - scr_size.uly - 100) then
  begin
    Result := -1;
    Exit;
  end;

  mouse_get_position(@mx, @my);

  tile := tile_num(mx, my, elevation);
  if tile = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := tile;
end;

// 0x412950
function is_hit_from_front(a1: PObject; a2: PObject): Boolean;
var
  diff: Integer;
begin
  diff := a1^.Rotation - a2^.Rotation;
  if diff < 0 then
    diff := -diff;

  Result := (diff <> 0) and (diff <> 1) and (diff <> 5);
end;

// 0x412974
function can_see(a1: PObject; a2: PObject): Boolean;
var
  diff: Integer;
begin
  diff := a1^.Rotation - tile_dir(a1^.Tile, a2^.Tile);
  if diff < 0 then
    diff := -diff;

  Result := (diff = 0) or (diff = 1) or (diff = 5);
end;

// 0x4129A4
function pick_fall(obj: PObject; anim: Integer): Integer;
var
  i: Integer;
  rot: Integer;
  tile_num_: Integer;
  fid: Integer;
  localAnim: Integer;
begin
  localAnim := anim;

  if localAnim = ANIM_FALL_FRONT then
  begin
    rot := obj^.Rotation;
    i := 1;
    while i < 3 do
    begin
      tile_num_ := tile_num_in_direction(obj^.Tile, rot, i);
      if obj_blocking_at(obj, tile_num_, obj^.Elevation) <> nil then
      begin
        localAnim := ANIM_FALL_BACK;
        Break;
      end;
      Inc(i);
    end;
  end
  else if localAnim = ANIM_FALL_BACK then
  begin
    rot := (obj^.Rotation + 3) mod ROTATION_COUNT;
    i := 1;
    while i < 3 do
    begin
      tile_num_ := tile_num_in_direction(obj^.Tile, rot, i);
      if obj_blocking_at(obj, tile_num_, obj^.Elevation) <> nil then
      begin
        localAnim := ANIM_FALL_FRONT;
        Break;
      end;
      Inc(i);
    end;
  end;

  if localAnim = ANIM_FALL_FRONT then
  begin
    fid := art_id(OBJ_TYPE_CRITTER, obj^.Fid and $FFF, ANIM_FALL_FRONT, (obj^.Fid and $F000) shr 12, obj^.Rotation + 1);
    if not art_exists(fid) then
      localAnim := ANIM_FALL_BACK;
  end;

  Result := localAnim;
end;

// 0x412A6C
function action_explode(tile: Integer; elevation: Integer; minDamage: Integer; maxDamage: Integer; a5: PObject; premature: Boolean): Integer;
var
  attack: PAttack;
  explosion: PObject;
  fid: Integer;
  adjacentExplosions: array[0..ROTATION_COUNT - 1] of PObject;
  rot: Integer;
  adjacentTile: Integer;
  critter: PObject;
  index: Integer;
  innerCritter: PObject;
begin
  if premature and action_in_explode then
  begin
    Result := -2;
    Exit;
  end;

  attack := PAttack(mem_malloc(SizeOf(TAttack)));
  if attack = nil then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_MISC, 10, 0, 0, 0);
  if obj_new(@explosion, fid, -1) = -1 then
  begin
    mem_free(attack);
    Result := -1;
    Exit;
  end;

  obj_turn_off(explosion, nil);
  explosion^.Flags := explosion^.Flags or OBJECT_NO_SAVE;

  obj_move_to_tile(explosion, tile, elevation, nil);

  rot := 0;
  while rot < ROTATION_COUNT do
  begin
    fid := art_id(OBJ_TYPE_MISC, 10, 0, 0, 0);
    if obj_new(@(adjacentExplosions[rot]), fid, -1) = -1 then
    begin
      Dec(rot);
      while rot >= 0 do
      begin
        obj_erase_object(adjacentExplosions[rot], nil);
        Dec(rot);
      end;

      obj_erase_object(explosion, nil);
      mem_free(attack);
      Result := -1;
      Exit;
    end;

    obj_turn_off(adjacentExplosions[rot], nil);
    adjacentExplosions[rot]^.Flags := adjacentExplosions[rot]^.Flags or OBJECT_NO_SAVE;

    adjacentTile := tile_num_in_direction(tile, rot, 1);
    obj_move_to_tile(adjacentExplosions[rot], adjacentTile, elevation, nil);
    Inc(rot);
  end;

  critter := obj_blocking_at(nil, tile, elevation);
  if critter <> nil then
  begin
    if (FID_TYPE(critter^.Fid) <> OBJ_TYPE_CRITTER) or ((critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0) then
      critter := nil;
  end;

  combat_ctd_init(attack, explosion, critter, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);

  attack^.tile := tile;
  attack^.attackerFlags := DAM_HIT;

  game_ui_disable(1);

  if critter <> nil then
  begin
    if register_clear(critter) = -2 then
      debug_printf('Cannot clear target''s animation for action_explode!'#10);
    attack^.defenderDamage := compute_explosion_damage(minDamage, maxDamage, critter, @(attack^.defenderKnockback));
  end;

  compute_explosion_on_extras(attack, 0, False, 1);

  for index := 0 to attack^.extrasLength - 1 do
  begin
    innerCritter := attack^.extras[index];
    if register_clear(innerCritter) = -2 then
      debug_printf('Cannot clear extra''s animation for action_explode!'#10);

    attack^.extrasDamage[index] := compute_explosion_damage(minDamage, maxDamage, innerCritter, @(attack^.extrasKnockback[index]));
  end;

  death_checks(attack);

  if premature then
  begin
    action_in_explode := True;

    register_begin(ANIMATION_REQUEST_RESERVED);
    register_priority(1);
    register_object_play_sfx(explosion, 'whn1xxx1', 0);
    register_object_funset(explosion, OBJECT_HIDDEN, 0);
    register_object_animate_and_hide(explosion, ANIM_STAND, 0);
    show_damage(attack, 0, 1);

    for rot := 0 to ROTATION_COUNT - 1 do
    begin
      register_object_funset(adjacentExplosions[rot], OBJECT_HIDDEN, 0);
      register_object_animate_and_hide(adjacentExplosions[rot], ANIM_STAND, 0);
    end;

    register_object_must_call(explosion, nil, TAnimationCallback(@combat_explode_scenery), -1);
    register_object_must_erase(explosion);

    for rot := 0 to ROTATION_COUNT - 1 do
      register_object_must_erase(adjacentExplosions[rot]);

    register_object_must_call(attack, a5, TAnimationCallback(@report_explosion), -1);
    register_object_must_call(nil, nil, TAnimationCallback(@finished_explosion), -1);
    if register_end() = -1 then
    begin
      action_in_explode := False;

      obj_erase_object(explosion, nil);

      for rot := 0 to ROTATION_COUNT - 1 do
        obj_erase_object(adjacentExplosions[rot], nil);

      mem_free(attack);

      game_ui_enable();
      Result := -1;
      Exit;
    end;

    show_damage_extras(attack);
  end
  else
  begin
    if critter <> nil then
    begin
      if (attack^.defenderFlags and DAM_DEAD) <> 0 then
        critter_kill(critter, -1, False);
    end;

    for index := 0 to attack^.extrasLength - 1 do
    begin
      if (attack^.extrasFlags[index] and DAM_DEAD) <> 0 then
        critter_kill(attack^.extras[index], -1, False);
    end;

    report_explosion(attack, a5);

    combat_explode_scenery(explosion, nil);

    obj_erase_object(explosion, nil);

    for rot := 0 to ROTATION_COUNT - 1 do
      obj_erase_object(adjacentExplosions[rot], nil);
  end;

  Result := 0;
end;

// 0x412EBC
function report_explosion(attack: PAttack; a2: PObject): Integer;
var
  mainTargetWasDead: Boolean;
  extrasWasDead: array[0..5] of Boolean;
  index: Integer;
  anyDefender: PObject;
  xp: Integer;
  critter: PObject;
  combat: TSTRUCT_664980;
begin
  if attack^.defender <> nil then
    mainTargetWasDead := (attack^.defender^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0
  else
    mainTargetWasDead := False;

  for index := 0 to attack^.extrasLength - 1 do
    extrasWasDead[index] := (attack^.extras[index]^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0;

  death_checks(attack);
  combat_display(attack);
  apply_damage(attack, False);

  anyDefender := nil;
  xp := 0;
  if a2 <> nil then
  begin
    if (attack^.defender <> nil) and (attack^.defender <> a2) then
    begin
      if (attack^.defender^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
      begin
        if (a2 = obj_dude) and (not mainTargetWasDead) then
          xp := xp + critter_kill_exps(attack^.defender);
      end
      else
      begin
        critter_set_who_hit_me(attack^.defender, a2);
        anyDefender := attack^.defender;
      end;
    end;

    for index := 0 to attack^.extrasLength - 1 do
    begin
      critter := attack^.extras[index];
      if critter <> a2 then
      begin
        if (critter^.Data.AsData.Critter.Combat.Results and DAM_DEAD) <> 0 then
        begin
          if (a2 = obj_dude) and (not extrasWasDead[index]) then
            xp := xp + critter_kill_exps(critter);
        end
        else
        begin
          critter_set_who_hit_me(critter, a2);

          if anyDefender = nil then
            anyDefender := critter;
        end;
      end;
    end;

    if anyDefender <> nil then
    begin
      if not isInCombat() then
      begin
        combat.attacker := anyDefender;
        combat.defender := a2;
        combat.actionPointsBonus := 0;
        combat.accuracyBonus := 0;
        combat.damageBonus := 0;
        combat.minDamage := 0;
        combat.maxDamage := MaxInt;
        combat.field_1C := 0;
        scripts_request_combat(@combat);
      end;
    end;
  end;

  mem_free(attack);
  game_ui_enable();

  if a2 = obj_dude then
    combat_give_exps(xp);

  Result := 0;
end;

// 0x413038
function finished_explosion(a1: PObject; a2: PObject): Integer;
begin
  action_in_explode := False;
  Result := 0;
end;

// 0x413044
function compute_explosion_damage(min_: Integer; max_: Integer; a3: PObject; a4: PInteger): Integer;
var
  v5: Integer;
  v7: Integer;
begin
  v5 := roll_random(min_, max_);
  v7 := v5 - stat_level(a3, Ord(STAT_DAMAGE_THRESHOLD_EXPLOSION));
  if v7 > 0 then
    v7 := v7 - stat_level(a3, Ord(STAT_DAMAGE_RESISTANCE_EXPLOSION)) * v7 div 100;

  if v7 < 0 then
    v7 := 0;

  if a4 <> nil then
  begin
    if (a3^.Flags and OBJECT_MULTIHEX) = 0 then
      a4^ := v7 div 10;
  end;

  Result := v7;
end;

// 0x4130A8
function action_talk_to(a1: PObject; a2: PObject): Integer;
var
  anim: Integer;
begin
  if a1 <> obj_dude then
  begin
    Result := -1;
    Exit;
  end;

  if FID_TYPE(a2^.Fid) <> OBJ_TYPE_CRITTER then
  begin
    Result := -1;
    Exit;
  end;

  anim := FID_ANIM_TYPE(obj_dude^.Fid);
  if (anim = ANIM_WALK) or (anim = ANIM_RUNNING) then
    register_clear(obj_dude);

  if isInCombat() then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);
    register_object_move_to_object(a1, a2, a1^.Data.AsData.Critter.Combat.Ap, 0);
  end
  else
  begin
    if a1 = obj_dude then
      register_begin(ANIMATION_REQUEST_RESERVED)
    else
      register_begin(ANIMATION_REQUEST_UNRESERVED);

    if (obj_dist(a1, a2) >= 9) or combat_is_shot_blocked(a1, a1^.Tile, a2^.Tile, a2, nil) then
      register_object_run_to_object(a1, a2, -1, 0);
  end;

  register_object_must_call(a1, a2, TAnimationCallback(@can_talk_to), -1);
  register_object_call(a1, a2, TAnimationCallback(@talk_to), -1);
  Result := register_end();
end;

// 0x413198
function can_talk_to(a1: PObject; a2: PObject): Integer;
var
  messageListItem: TMessageListItem;
begin
  if combat_is_shot_blocked(a1, a1^.Tile, a2^.Tile, a2, nil) or (obj_dist(a1, a2) >= 9) then
  begin
    if a1 = obj_dude then
    begin
      // You cannot get there. (used in actions.c)
      messageListItem.num := 2000;
      if message_search(@misc_message_file, @messageListItem) then
        display_print(messageListItem.text);
    end;

    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// 0x413200
function talk_to(a1: PObject; a2: PObject): Integer;
begin
  scripts_request_dialog(a2);
  Result := 0;
end;

// 0x41320C
procedure action_dmg(tile: Integer; elevation: Integer; minDamage: Integer; maxDamage: Integer; damageType: Integer; animated: Boolean; bypassArmor: Boolean);
var
  attack: PAttack;
  attacker: PObject;
  defender: PObject;
  damage: Integer;
begin
  attack := PAttack(mem_malloc(SizeOf(TAttack)));
  if attack = nil then
    Exit;

  if obj_new(@attacker, FID_0x20001F5, -1) = -1 then
  begin
    mem_free(attack);
    Exit;
  end;

  obj_turn_off(attacker, nil);

  attacker^.Flags := attacker^.Flags or OBJECT_NO_SAVE;

  obj_move_to_tile(attacker, tile, elevation, nil);

  defender := obj_blocking_at(nil, tile, elevation);
  combat_ctd_init(attack, attacker, defender, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);
  attack^.tile := tile;
  attack^.attackerFlags := DAM_HIT;
  game_ui_disable(1);

  if defender <> nil then
  begin
    register_clear(defender);

    if bypassArmor then
      damage := maxDamage
    else
      damage := compute_dmg_damage(minDamage, maxDamage, defender, @(attack^.defenderKnockback), damageType);

    attack^.defenderDamage := damage;
  end;

  death_checks(attack);

  if animated then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);
    register_object_play_sfx(attacker, 'whc1xxx1', 0);
    show_damage(attack, death_3[damageType], 0);
    register_object_must_call(attack, nil, TAnimationCallback(@report_dmg), 0);
    register_object_must_erase(attacker);

    if register_end() = -1 then
    begin
      obj_erase_object(attacker, nil);
      mem_free(attack);
      game_ui_enable();
      Exit;
    end;
  end
  else
  begin
    if defender <> nil then
    begin
      if (attack^.defenderFlags and DAM_DEAD) <> 0 then
        critter_kill(defender, -1, True);
    end;

    report_dmg(attack, nil);

    obj_erase_object(attacker, nil);
  end;

  game_ui_enable();
end;

// 0x4133B4
function report_dmg(attack: PAttack; a2: PObject): Integer;
begin
  combat_display(attack);
  apply_damage(attack, False);
  mem_free(attack);
  game_ui_enable();
  Result := 0;
end;

// 0x4133D8
function compute_dmg_damage(min_damage: Integer; max_damage: Integer; obj: PObject; knockback_distance: PInteger; damage_type: Integer): Integer;
var
  damage: Integer;
begin
  damage := roll_random(min_damage, max_damage) - stat_level(obj, Ord(STAT_DAMAGE_THRESHOLD) + damage_type);
  if damage > 0 then
    damage := damage - stat_level(obj, Ord(STAT_DAMAGE_RESISTANCE) + damage_type) * damage div 100;

  if damage < 0 then
    damage := 0;

  if knockback_distance <> nil then
  begin
    if ((obj^.Flags and OBJECT_MULTIHEX) = 0) and (damage_type <> DAMAGE_TYPE_ELECTRICAL) then
      knockback_distance^ := damage div 10;
  end;

  Result := damage;
end;

initialization
  rotation := 0;
  obj_fid := -1;
  obj_pid_old := -1;

end.
