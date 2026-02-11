unit u_roll;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

uses
  u_db;

const
  ROLL_CRITICAL_FAILURE = 0;
  ROLL_FAILURE          = 1;
  ROLL_SUCCESS          = 2;
  ROLL_CRITICAL_SUCCESS = 3;

procedure roll_init;
function roll_reset: Integer;
function roll_exit: Integer;
function roll_save(stream: PDB_FILE): Integer;
function roll_load(stream: PDB_FILE): Integer;
function roll_check(difficulty: Integer; criticalSuccessModifier: Integer; howMuchPtr: PInteger): Integer;
function roll_check_critical(delta: Integer; criticalSuccessModifier: Integer): Integer;
function roll_random(min_: Integer; max_: Integer): Integer;
procedure roll_set_seed(seed: Integer);

implementation

uses
  u_platform_compat,
  u_scripts;

const
  GAME_TIME_TICKS_PER_DAY = 864000;

// External declarations
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

var
  iy: Integer = 0;
  iv: array[0..31] of Integer;
  idum: Integer;

// Forward declarations
function ran1(max_: Integer): Integer; forward;
procedure init_random; forward;
function random_seed: Integer; forward;
procedure seed_generator(seed: Integer); forward;
function timer_read: LongWord; forward;
procedure check_chi_squared; forward;

procedure roll_init;
begin
  init_random;
  check_chi_squared;
end;

function roll_reset: Integer;
begin
  Result := 0;
end;

function roll_exit: Integer;
begin
  Result := 0;
end;

function roll_save(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

function roll_load(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

function roll_check(difficulty: Integer; criticalSuccessModifier: Integer; howMuchPtr: PInteger): Integer;
var
  delta: Integer;
begin
  delta := difficulty - roll_random(1, 100);
  Result := roll_check_critical(delta, criticalSuccessModifier);

  if howMuchPtr <> nil then
    howMuchPtr^ := delta;
end;

function roll_check_critical(delta: Integer; criticalSuccessModifier: Integer): Integer;
var
  gameTime: Integer;
begin
  gameTime := game_time();

  if delta < 0 then
  begin
    Result := ROLL_FAILURE;

    if (gameTime div GAME_TIME_TICKS_PER_DAY) >= 1 then
    begin
      if roll_random(1, 100) <= (-delta) div 10 then
        Result := ROLL_CRITICAL_FAILURE;
    end;
  end
  else
  begin
    Result := ROLL_SUCCESS;

    if (gameTime div GAME_TIME_TICKS_PER_DAY) >= 1 then
    begin
      if roll_random(1, 100) <= delta div 10 + criticalSuccessModifier then
        Result := ROLL_CRITICAL_SUCCESS;
    end;
  end;
end;

function roll_random(min_: Integer; max_: Integer): Integer;
begin
  if min_ <= max_ then
    Result := min_ + ran1(max_ - min_ + 1)
  else
    Result := max_ + ran1(min_ - max_ + 1);

  if (Result < min_) or (Result > max_) then
  begin
    debug_printf('Random number %d is not in range %d to %d', Result, min_, max_);
    Result := min_;
  end;
end;

function ran1(max_: Integer): Integer;
var
  v1, v2, v3: Integer;
begin
  v1 := 16807 * (idum mod 127773) - 2836 * (idum div 127773);

  if v1 < 0 then
    v1 := v1 + $7FFFFFFF;

  if v1 < 0 then
    v1 := v1 + $7FFFFFFF;

  v2 := iy and $1F;
  v3 := iv[v2];
  iv[v2] := v1;
  iy := v3;
  idum := v1;

  Result := v3 mod max_;
end;

procedure init_random;
begin
  Randomize;
  seed_generator(random_seed);
end;

procedure roll_set_seed(seed: Integer);
begin
  if seed = -1 then
    seed := random_seed;

  seed_generator(seed);
end;

function random_seed: Integer;
begin
  Result := System.Random(MaxInt);
end;

procedure seed_generator(seed: Integer);
var
  num: Integer;
  index: Integer;
begin
  num := seed;
  if num < 1 then
    num := 1;

  index := 40;
  while index > 0 do
  begin
    num := 16807 * (num mod 127773) - 2836 * (num div 127773);

    if num < 0 then
      num := num and MaxInt;

    if index < 32 then
      iv[index] := num;

    Dec(index);
  end;

  iy := iv[0];
  idum := num;
end;

function timer_read: LongWord;
begin
  Result := compat_timeGetTime();
end;

procedure check_chi_squared;
var
  results: array[0..24] of Integer;
  index, attempt, value: Integer;
  v1, v2: Double;
begin
  for index := 0 to 24 do
    results[index] := 0;

  for attempt := 0 to 99999 do
  begin
    value := roll_random(1, 25);
    if value - 1 < 0 then
      debug_printf('I made a negative number %d'#10, value - 1);

    results[value - 1] := results[value - 1] + 1;
  end;

  v1 := 0.0;

  for index := 0 to 24 do
  begin
    v2 := (results[index] - 4000.0) * (results[index] - 4000.0) / 4000.0;
    v1 := v1 + v2;
  end;

  debug_printf('Chi squared is %f, P = %f at 0.05'#10, v1, Double(4000.0));

  if v1 < 36.42 then
    debug_printf('Sequence is random, 95%% confidence.'#10)
  else
    debug_printf('Warning! Sequence is not random, 95%% confidence.'#10);
end;

end.
