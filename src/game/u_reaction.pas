{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

unit u_reaction;

interface

uses
  u_object_types,
  u_perk_defs,
  u_stat_defs,
  u_game_vars;

const
  NPC_REACTION_BAD     = 0;
  NPC_REACTION_NEUTRAL = 1;
  NPC_REACTION_GOOD    = 2;

function reaction_set(critter: PObject; value: Integer): Integer;
function level_to_reaction: Integer;
function reaction_to_level_internal(sid: Integer; reaction: Integer): Integer;
function reaction_to_level(reaction: Integer): Integer;
function reaction_roll(a1: Integer; a2: Integer; a3: Integer): Integer;
function reaction_influence(a1: Integer; a2: Integer; a3: Integer): Integer;
function reaction_get(critter: PObject): Integer;

implementation

uses
  u_intrpret,
  u_scripts,
  u_stat,
  u_perk,
  u_game,
  u_object;

const
  VALUE_TYPE_INT = $C001;

{ =========================================================================
  compat_scr_set_local_var - helper to set a script local var from an integer
  ========================================================================= }
function compat_scr_set_local_var(sid: Integer; variable: Integer; value: Integer): Integer; forward;

{ =========================================================================
  compat_scr_get_local_var - helper to get a script local var as an integer
  ========================================================================= }
function compat_scr_get_local_var(sid: Integer; variable: Integer; value: PInteger): Integer; forward;

{ =========================================================================
  reaction_set
  ========================================================================= }
function reaction_set(critter: PObject; value: Integer): Integer;
begin
  compat_scr_set_local_var(critter^.Sid, 0, value);
  Result := 0;
end;

{ =========================================================================
  level_to_reaction
  ========================================================================= }
function level_to_reaction: Integer;
begin
  Result := 0;
end;

{ =========================================================================
  reaction_to_level_internal
  ========================================================================= }
function reaction_to_level_internal(sid: Integer; reaction: Integer): Integer;
begin
  if reaction > 75 then
  begin
    compat_scr_set_local_var(sid, 1, 3);
    { level := 2; (unused) }
  end
  else if reaction > 25 then
  begin
    compat_scr_set_local_var(sid, 1, 2);
    { level := 1; (unused) }
  end
  else
  begin
    compat_scr_set_local_var(sid, 1, 1);
    { level := 0; (unused) }
  end;

  Result := 0;
end;

{ =========================================================================
  reaction_to_level
  ========================================================================= }
function reaction_to_level(reaction: Integer): Integer;
begin
  if reaction > 75 then
    Result := 2
  else if reaction > 25 then
    Result := 1
  else
    Result := 0;
end;

{ =========================================================================
  reaction_roll
  ========================================================================= }
function reaction_roll(a1: Integer; a2: Integer; a3: Integer): Integer;
begin
  Result := 0;
end;

{ =========================================================================
  reaction_influence
  ========================================================================= }
function reaction_influence(a1: Integer; a2: Integer; a3: Integer): Integer;
begin
  Result := 0;
end;

{ =========================================================================
  reaction_get
  ========================================================================= }
function reaction_get(critter: PObject): Integer;
var
  sid: Integer;
  v1: Integer;
  v2: Integer;
begin
  v1 := 0;
  v2 := 0;

  sid := critter^.Sid;

  if compat_scr_get_local_var(sid, 2, @v1) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if v1 <> 0 then
  begin
    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    Result := v2;
    Exit;
  end;

  compat_scr_set_local_var(sid, 0, 50);
  compat_scr_set_local_var(sid, 1, 2);
  compat_scr_set_local_var(sid, 2, 1);

  if compat_scr_get_local_var(sid, 0, @v2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  compat_scr_set_local_var(sid, 0, v2 + 5 * stat_level(obj_dude, Ord(STAT_CHARISMA)) - 25);

  if compat_scr_get_local_var(sid, 0, @v2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  compat_scr_set_local_var(sid, 0, v2 + 10 * perk_level(Ord(PERK_PRESENCE)));

  if perk_level(Ord(PERK_CULT_OF_PERSONALITY)) > 0 then
  begin
    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if game_get_global_var(Ord(GVAR_PLAYER_REPUATION)) > 0 then
      compat_scr_set_local_var(sid, 0, game_get_global_var(Ord(GVAR_PLAYER_REPUATION)) + v2)
    else
      compat_scr_set_local_var(sid, 0, v2 - game_get_global_var(Ord(GVAR_PLAYER_REPUATION)));
  end
  else
  begin
    if compat_scr_get_local_var(sid, 3, @v1) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if v1 <> 1 then
      compat_scr_set_local_var(sid, 0, game_get_global_var(Ord(GVAR_PLAYER_REPUATION)) + v2)
    else
      compat_scr_set_local_var(sid, 0, v2 - game_get_global_var(Ord(GVAR_PLAYER_REPUATION)));
  end;

  if game_get_global_var(Ord(GVAR_CHILDKILLER_REPUATION)) > 2 then
  begin
    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    compat_scr_set_local_var(sid, 0, v2 - 30);
  end;

  if (game_get_global_var(Ord(GVAR_BAD_MONSTER)) > 3 * game_get_global_var(Ord(GVAR_GOOD_MONSTER)))
    or (game_get_global_var(Ord(GVAR_CHAMPION_REPUTATION)) = 1) then
  begin
    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    compat_scr_set_local_var(sid, 0, v2 + 20);
  end;

  if (game_get_global_var(Ord(GVAR_GOOD_MONSTER)) > 2 * game_get_global_var(Ord(GVAR_BAD_MONSTER)))
    or (game_get_global_var(Ord(GVAR_BERSERKER_REPUTATION)) = 1) then
  begin
    if compat_scr_get_local_var(sid, 0, @v2) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    compat_scr_set_local_var(sid, 0, v2 - 20);
  end;

  if compat_scr_get_local_var(sid, 0, @v2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  reaction_to_level_internal(sid, v2);

  if compat_scr_get_local_var(sid, 0, @v2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := v2;
end;

{ =========================================================================
  compat_scr_set_local_var
  ========================================================================= }
function compat_scr_set_local_var(sid: Integer; variable: Integer; value: Integer): Integer;
var
  programValue: TProgramValue;
begin
  programValue.opcode := VALUE_TYPE_INT;
  programValue.integerValue := value;
  Result := scr_set_local_var(sid, variable, programValue);
end;

{ =========================================================================
  compat_scr_get_local_var
  ========================================================================= }
function compat_scr_get_local_var(sid: Integer; variable: Integer; value: PInteger): Integer;
var
  programValue: TProgramValue;
begin
  if scr_get_local_var(sid, variable, programValue) <> 0 then
  begin
    value^ := -1;
    Result := -1;
    Exit;
  end;

  value^ := programValue.integerValue;
  Result := 0;
end;

end.
