{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/elevator.h + elevator.cc
// Elevator dialog: lets the player pick a destination level in multi-floor locations.
unit u_elevator;

interface

const
  // Elevator enum
  ELEVATOR_BROTHERHOOD_OF_STEEL_MAIN    = 0;
  ELEVATOR_BROTHERHOOD_OF_STEEL_SURFACE = 1;
  ELEVATOR_MASTER_UPPER                 = 2;
  ELEVATOR_MASTER_LOWER                 = 3;
  ELEVATOR_MILITARY_BASE_UPPER          = 4;
  ELEVATOR_MILITARY_BASE_LOWER          = 5;
  ELEVATOR_GLOW_UPPER                   = 6;
  ELEVATOR_GLOW_LOWER                   = 7;
  ELEVATOR_VAULT_13                     = 8;
  ELEVATOR_NECROPOLIS                   = 9;
  ELEVATOR_SIERRA_1                     = 10;
  ELEVATOR_SIERRA_2                     = 11;
  ELEVATOR_COUNT                        = 12;

function elevator_select(elevator: Integer; mapPtr: PInteger; elevationPtr: PInteger; tilePtr: PInteger): Integer;

implementation

uses
  u_object_types,
  u_cache,
  u_rect,
  u_gnw_types,
  u_button,
  u_gnw,
  u_grbuf,
  u_input,
  u_svga,
  u_kb,
  u_debug,
  u_art,
  u_cycle,
  u_gmouse,
  u_map,
  u_fps_limiter,
  u_gsound;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const
  ELEVATOR_LEVEL_MAX = 4;

  // ElevatorFrm
  ELEVATOR_FRM_BUTTON_DOWN   = 0;
  ELEVATOR_FRM_BUTTON_UP     = 1;
  ELEVATOR_FRM_GAUGE         = 2;
  ELEVATOR_FRM_BACKGROUND    = 3;
  ELEVATOR_FRM_PANEL         = 4;
  ELEVATOR_FRM_COUNT         = 5;
  ELEVATOR_FRM_STATIC_COUNT  = 3;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type
  TElevatorBackground = record
    backgroundFrmId: Integer;
    panelFrmId: Integer;
  end;

  TElevatorDescription = record
    map: Integer;
    elevation: Integer;
    tile: Integer;
  end;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------

function elevator_start(elevator: Integer): Integer; forward;
procedure elevator_end; forward;
function Check4Keys(elevator: Integer; keyCode: Integer): Integer; forward;

// ---------------------------------------------------------------------------
// Static data tables
// ---------------------------------------------------------------------------

const
  grph_id: array[0..ELEVATOR_FRM_STATIC_COUNT - 1] of Integer = (
    141, // ebut_in.frm
    142, // ebut_out.frm
    149  // gaj000.frm
  );

  intotal: array[0..ELEVATOR_COUNT - 1] of TElevatorBackground = (
    (backgroundFrmId: 143; panelFrmId: -1),   // BROTHERHOOD_OF_STEEL_MAIN
    (backgroundFrmId: 143; panelFrmId: 150),   // BROTHERHOOD_OF_STEEL_SURFACE
    (backgroundFrmId: 144; panelFrmId: -1),    // MASTER_UPPER
    (backgroundFrmId: 144; panelFrmId: 145),   // MASTER_LOWER
    (backgroundFrmId: 146; panelFrmId: -1),    // MILITARY_BASE_UPPER
    (backgroundFrmId: 146; panelFrmId: 147),   // MILITARY_BASE_LOWER
    (backgroundFrmId: 146; panelFrmId: -1),    // GLOW_UPPER
    (backgroundFrmId: 146; panelFrmId: 151),   // GLOW_LOWER
    (backgroundFrmId: 148; panelFrmId: -1),    // VAULT_13
    (backgroundFrmId: 148; panelFrmId: -1),    // NECROPOLIS
    (backgroundFrmId: 148; panelFrmId: -1),    // SIERRA_1
    (backgroundFrmId: 146; panelFrmId: 152)    // SIERRA_2
  );

  btncnt: array[0..ELEVATOR_COUNT - 1] of Integer = (
    4,  // BROTHERHOOD_OF_STEEL_MAIN
    2,  // BROTHERHOOD_OF_STEEL_SURFACE
    3,  // MASTER_UPPER
    2,  // MASTER_LOWER
    3,  // MILITARY_BASE_UPPER
    2,  // MILITARY_BASE_LOWER
    3,  // GLOW_UPPER
    3,  // GLOW_LOWER
    3,  // VAULT_13
    3,  // NECROPOLIS
    3,  // SIERRA_1
    3   // SIERRA_2
  );

  retvals: array[0..ELEVATOR_COUNT - 1, 0..ELEVATOR_LEVEL_MAX - 1] of TElevatorDescription = (
    ( (map: 14; elevation: 0; tile: 18940),
      (map: 14; elevation: 1; tile: 18936),
      (map: 15; elevation: 0; tile: 21340),
      (map: 15; elevation: 1; tile: 21340) ),
    ( (map: 13; elevation: 0; tile: 20502),
      (map: 14; elevation: 0; tile: 14912),
      (map:  0; elevation: 0; tile: -1),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 33; elevation: 0; tile: 12498),
      (map: 33; elevation: 1; tile: 20094),
      (map: 34; elevation: 0; tile: 17312),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 34; elevation: 0; tile: 16140),
      (map: 34; elevation: 1; tile: 16140),
      (map:  0; elevation: 0; tile: -1),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 31; elevation: 0; tile: 14920),
      (map: 31; elevation: 1; tile: 14920),
      (map: 32; elevation: 0; tile: 12944),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 32; elevation: 0; tile: 24520),
      (map: 32; elevation: 1; tile: 24520),
      (map:  0; elevation: 0; tile: -1),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 42; elevation: 0; tile: 22526),
      (map: 42; elevation: 1; tile: 22526),
      (map: 42; elevation: 2; tile: 22526),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 42; elevation: 2; tile: 14086),
      (map: 43; elevation: 0; tile: 14086),
      (map: 43; elevation: 2; tile: 14086),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map:  6; elevation: 0; tile: 14104),
      (map:  6; elevation: 1; tile: 22504),
      (map:  6; elevation: 2; tile: 17312),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map:  9; elevation: 0; tile: 13704),
      (map:  9; elevation: 1; tile: 23302),
      (map:  9; elevation: 2; tile: 17308),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map:  9; elevation: 0; tile: 13704),
      (map:  9; elevation: 1; tile: 23302),
      (map:  9; elevation: 2; tile: 17308),
      (map:  0; elevation: 0; tile: -1) ),
    ( (map: 43; elevation: 0; tile: 14130),
      (map: 43; elevation: 1; tile: 14130),
      (map: 43; elevation: 2; tile: 14130),
      (map:  0; elevation: 0; tile: -1) )
  );

  keytable: array[0..ELEVATOR_COUNT - 1, 0..ELEVATOR_LEVEL_MAX - 1] of AnsiChar = (
    ('1', '2', '3', '4'),
    ('G', '1', #0,  #0),
    ('1', '2', '3', #0),
    ('3', '4', #0,  #0),
    ('1', '2', '3', #0),
    ('3', '4', #0,  #0),
    ('1', '2', '3', #0),
    ('3', '4', '6', #0),
    ('1', '2', '3', #0),
    ('1', '2', '3', #0),
    ('1', '2', '3', #0),
    ('4', '5', '6', #0)
  );

  sfxtable: array[0..ELEVATOR_LEVEL_MAX - 2, 0..ELEVATOR_LEVEL_MAX - 1] of PAnsiChar = (
    ('ELV1_1', 'ELV1_1', 'ERROR',  'ERROR'),
    ('ELV1_2', 'ELV1_2', 'ELV1_1', 'ERROR'),
    ('ELV1_3', 'ELV1_3', 'ELV2_3', 'ELV1_1')
  );

// ---------------------------------------------------------------------------
// Module-level (static) variables
// ---------------------------------------------------------------------------

var
  GInfo: array[0..ELEVATOR_FRM_COUNT - 1] of TSize;
  elev_win: Integer;
  win_buf: PByte;
  bk_enable: Boolean;
  grph_key: array[0..ELEVATOR_FRM_COUNT - 1] of PCacheEntry;
  grphbmp: array[0..ELEVATOR_FRM_COUNT - 1] of PByte;

// ---------------------------------------------------------------------------
// ELEVATOR_BACKGROUND_NULL sentinel
// ---------------------------------------------------------------------------

function ELEVATOR_BACKGROUND_NULL: PByte; inline;
begin
  Result := PByte(PtrUInt(-1));
end;

// ---------------------------------------------------------------------------
// elevator_select
// ---------------------------------------------------------------------------

function elevator_select(elevator: Integer; mapPtr: PInteger; elevationPtr: PInteger; tilePtr: PInteger): Integer;
var
  idx: Integer;
  v18: Integer;
  v42: Single;
  done: Boolean;
  keyCode: Integer;
  level: Integer;
  v43: Single;
  delay: LongWord;
  numberOfLevelsTravelled: Integer;
  v41: Single;
  v44: Single;
  tick: LongWord;
begin
  if (elevator < 0) or (elevator >= ELEVATOR_COUNT) then
    Exit(-1);

  if elevator_start(elevator) = -1 then
    Exit(-1);

  idx := 0;
  while idx < ELEVATOR_LEVEL_MAX do
  begin
    if retvals[elevator][idx].map = mapPtr^ then
      Break;
    Inc(idx);
  end;

  if idx < ELEVATOR_LEVEL_MAX then
  begin
    if retvals[elevator][elevationPtr^ + idx].tile <> -1 then
      elevationPtr^ := elevationPtr^ + idx;
  end;

  if (elevator = ELEVATOR_GLOW_LOWER) and (mapPtr^ = 42) then
    elevationPtr^ := elevationPtr^ - 2;

  debug_printf(#10' the start elev level %d'#10, [elevationPtr^]);

  v18 := (GInfo[ELEVATOR_FRM_GAUGE].Width * GInfo[ELEVATOR_FRM_GAUGE].Height) div 13;
  v42 := 12.0 / Single(btncnt[elevator] - 1);

  buf_to_buf(
    grphbmp[ELEVATOR_FRM_GAUGE] + v18 * Trunc(Single(elevationPtr^) * v42),
    GInfo[ELEVATOR_FRM_GAUGE].Width,
    GInfo[ELEVATOR_FRM_GAUGE].Height div 13,
    GInfo[ELEVATOR_FRM_GAUGE].Width,
    win_buf + GInfo[ELEVATOR_FRM_BACKGROUND].Width * 41 + 121,
    GInfo[ELEVATOR_FRM_BACKGROUND].Width);

  win_draw(elev_win);

  done := False;
  keyCode := 0;
  while not done do
  begin
    if sharedFpsLimiter <> nil then
      sharedFpsLimiter.Mark;

    keyCode := get_input;

    if keyCode = KEY_ESCAPE then
      done := True;

    if (keyCode >= 500) and (keyCode < 504) then
      done := True;

    if (keyCode > 0) and (keyCode < 500) then
    begin
      level := Check4Keys(elevator, keyCode);
      if level <> 0 then
      begin
        keyCode := 500 + level - 1;
        done := True;
      end;
    end;

    renderPresent;

    if sharedFpsLimiter <> nil then
      sharedFpsLimiter.Throttle;
  end;

  if keyCode <> KEY_ESCAPE then
  begin
    keyCode := keyCode - 500;

    if elevationPtr^ <> keyCode then
    begin
      v43 := Single(btncnt[elevator] - 1) / 12.0;

      delay := Trunc(v43 * 276.92307);

      if keyCode < elevationPtr^ then
        v43 := -v43;

      numberOfLevelsTravelled := keyCode - elevationPtr^;
      if numberOfLevelsTravelled < 0 then
        numberOfLevelsTravelled := -numberOfLevelsTravelled;

      gsound_play_sfx_file(sfxtable[btncnt[elevator] - 2][numberOfLevelsTravelled]);

      v41 := Single(keyCode) * v42;
      v44 := Single(elevationPtr^) * v42;

      repeat
        if sharedFpsLimiter <> nil then
          sharedFpsLimiter.Mark;

        tick := get_time;
        v44 := v44 + v43;

        buf_to_buf(
          grphbmp[ELEVATOR_FRM_GAUGE] + v18 * Trunc(v44),
          GInfo[ELEVATOR_FRM_GAUGE].Width,
          GInfo[ELEVATOR_FRM_GAUGE].Height div 13,
          GInfo[ELEVATOR_FRM_GAUGE].Width,
          win_buf + GInfo[ELEVATOR_FRM_BACKGROUND].Width * 41 + 121,
          GInfo[ELEVATOR_FRM_BACKGROUND].Width);

        win_draw(elev_win);

        while elapsed_time(tick) < delay do
          { busy wait };

        renderPresent;

        if sharedFpsLimiter <> nil then
          sharedFpsLimiter.Throttle;
      until not (((v43 <= 0.0) or (v44 < v41)) and ((v43 > 0.0) or (v44 > v41)));

      pause_for_tocks(200);
    end;
  end;

  elevator_end;

  if keyCode <> KEY_ESCAPE then
  begin
    mapPtr^ := retvals[elevator][keyCode].map;
    elevationPtr^ := retvals[elevator][keyCode].elevation;
    tilePtr^ := retvals[elevator][keyCode].tile;
  end
  else
  begin
    if elevator = ELEVATOR_GLOW_LOWER then
      elevationPtr^ := elevationPtr^ + 2;
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// elevator_start
// ---------------------------------------------------------------------------

function elevator_start(elevator: Integer): Integer;
var
  idx: Integer;
  reversedIndex: Integer;
  fid: Integer;
  backgroundsLoaded: Boolean;
  backgroundFid: Integer;
  panelFid: Integer;
  elevatorWindowX: Integer;
  elevatorWindowY: Integer;
  y: Integer;
  level: Integer;
  btn: Integer;
begin
  bk_enable := map_disable_bk_processes;
  cycle_disable;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  gmouse_3d_off;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  idx := 0;
  while idx < ELEVATOR_FRM_STATIC_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, grph_id[idx], 0, 0, 0);
    grphbmp[idx] := art_lock(fid, @grph_key[idx], @GInfo[idx].Width, @GInfo[idx].Height);
    if grphbmp[idx] = nil then
      Break;
    Inc(idx);
  end;

  if idx <> ELEVATOR_FRM_STATIC_COUNT then
  begin
    reversedIndex := idx - 1;
    while reversedIndex >= 0 do
    begin
      art_ptr_unlock(grph_key[reversedIndex]);
      Dec(reversedIndex);
    end;

    if bk_enable then
      map_enable_bk_processes;

    cycle_enable;
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    Exit(-1);
  end;

  grphbmp[ELEVATOR_FRM_PANEL] := ELEVATOR_BACKGROUND_NULL;
  grphbmp[ELEVATOR_FRM_BACKGROUND] := ELEVATOR_BACKGROUND_NULL;

  backgroundsLoaded := True;

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, intotal[elevator].backgroundFrmId, 0, 0, 0);
  grphbmp[ELEVATOR_FRM_BACKGROUND] := art_lock(backgroundFid,
    @grph_key[ELEVATOR_FRM_BACKGROUND],
    @GInfo[ELEVATOR_FRM_BACKGROUND].Width,
    @GInfo[ELEVATOR_FRM_BACKGROUND].Height);

  if grphbmp[ELEVATOR_FRM_BACKGROUND] <> nil then
  begin
    if intotal[elevator].panelFrmId <> -1 then
    begin
      panelFid := art_id(OBJ_TYPE_INTERFACE, intotal[elevator].panelFrmId, 0, 0, 0);
      grphbmp[ELEVATOR_FRM_PANEL] := art_lock(panelFid,
        @grph_key[ELEVATOR_FRM_PANEL],
        @GInfo[ELEVATOR_FRM_PANEL].Width,
        @GInfo[ELEVATOR_FRM_PANEL].Height);
      if grphbmp[ELEVATOR_FRM_PANEL] = nil then
      begin
        grphbmp[ELEVATOR_FRM_PANEL] := ELEVATOR_BACKGROUND_NULL;
        backgroundsLoaded := False;
      end;
    end;
  end
  else
  begin
    grphbmp[ELEVATOR_FRM_BACKGROUND] := ELEVATOR_BACKGROUND_NULL;
    backgroundsLoaded := False;
  end;

  if not backgroundsLoaded then
  begin
    if grphbmp[ELEVATOR_FRM_BACKGROUND] <> ELEVATOR_BACKGROUND_NULL then
      art_ptr_unlock(grph_key[ELEVATOR_FRM_BACKGROUND]);

    if grphbmp[ELEVATOR_FRM_PANEL] <> ELEVATOR_BACKGROUND_NULL then
      art_ptr_unlock(grph_key[ELEVATOR_FRM_PANEL]);

    idx := 0;
    while idx < ELEVATOR_FRM_STATIC_COUNT do
    begin
      art_ptr_unlock(grph_key[idx]);
      Inc(idx);
    end;

    if bk_enable then
      map_enable_bk_processes;

    cycle_enable;
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    Exit(-1);
  end;

  elevatorWindowX := (screenGetWidth - GInfo[ELEVATOR_FRM_BACKGROUND].Width) div 2;
  elevatorWindowY := (screenGetHeight - INTERFACE_BAR_HEIGHT - 1 - GInfo[ELEVATOR_FRM_BACKGROUND].Height) div 2;

  elev_win := win_add(
    elevatorWindowX,
    elevatorWindowY,
    GInfo[ELEVATOR_FRM_BACKGROUND].Width,
    GInfo[ELEVATOR_FRM_BACKGROUND].Height,
    256,
    WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);

  if elev_win = -1 then
  begin
    if grphbmp[ELEVATOR_FRM_BACKGROUND] <> ELEVATOR_BACKGROUND_NULL then
      art_ptr_unlock(grph_key[ELEVATOR_FRM_BACKGROUND]);

    if grphbmp[ELEVATOR_FRM_PANEL] <> ELEVATOR_BACKGROUND_NULL then
      art_ptr_unlock(grph_key[ELEVATOR_FRM_PANEL]);

    idx := 0;
    while idx < ELEVATOR_FRM_STATIC_COUNT do
    begin
      art_ptr_unlock(grph_key[idx]);
      Inc(idx);
    end;

    if bk_enable then
      map_enable_bk_processes;

    cycle_enable;
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    Exit(-1);
  end;

  win_buf := win_get_buf(elev_win);
  Move(grphbmp[ELEVATOR_FRM_BACKGROUND]^, win_buf^,
    GInfo[ELEVATOR_FRM_BACKGROUND].Width * GInfo[ELEVATOR_FRM_BACKGROUND].Height);

  if grphbmp[ELEVATOR_FRM_PANEL] <> ELEVATOR_BACKGROUND_NULL then
  begin
    buf_to_buf(
      grphbmp[ELEVATOR_FRM_PANEL],
      GInfo[ELEVATOR_FRM_PANEL].Width,
      GInfo[ELEVATOR_FRM_PANEL].Height,
      GInfo[ELEVATOR_FRM_PANEL].Width,
      win_buf + GInfo[ELEVATOR_FRM_BACKGROUND].Width *
        (GInfo[ELEVATOR_FRM_BACKGROUND].Height - GInfo[ELEVATOR_FRM_PANEL].Height),
      GInfo[ELEVATOR_FRM_BACKGROUND].Width);
  end;

  y := 40;
  level := 0;
  while level < btncnt[elevator] do
  begin
    btn := win_register_button(elev_win,
      13,
      y,
      GInfo[ELEVATOR_FRM_BUTTON_DOWN].Width,
      GInfo[ELEVATOR_FRM_BUTTON_DOWN].Height,
      -1,
      -1,
      -1,
      500 + level,
      grphbmp[ELEVATOR_FRM_BUTTON_UP],
      grphbmp[ELEVATOR_FRM_BUTTON_DOWN],
      nil,
      BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, nil);
    y := y + 60;
    Inc(level);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------------------
// elevator_end
// ---------------------------------------------------------------------------

procedure elevator_end;
var
  idx: Integer;
begin
  win_delete(elev_win);

  if grphbmp[ELEVATOR_FRM_BACKGROUND] <> ELEVATOR_BACKGROUND_NULL then
    art_ptr_unlock(grph_key[ELEVATOR_FRM_BACKGROUND]);

  if grphbmp[ELEVATOR_FRM_PANEL] <> ELEVATOR_BACKGROUND_NULL then
    art_ptr_unlock(grph_key[ELEVATOR_FRM_PANEL]);

  idx := 0;
  while idx < ELEVATOR_FRM_STATIC_COUNT do
  begin
    art_ptr_unlock(grph_key[idx]);
    Inc(idx);
  end;

  if bk_enable then
    map_enable_bk_processes;

  cycle_enable;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
end;

// ---------------------------------------------------------------------------
// Check4Keys
// ---------------------------------------------------------------------------

function Check4Keys(elevator: Integer; keyCode: Integer): Integer;
var
  idx: Integer;
  c: AnsiChar;
begin
  // NOTE: Original C++ calls toupper(keyCode) but discards the result
  // (the comment says "Check if result is really unused?").
  // We replicate the behaviour: the comparison below uses the original keyCode.

  idx := 0;
  while idx < ELEVATOR_LEVEL_MAX do
  begin
    c := keytable[elevator][idx];
    if c = #0 then
      Break;

    if c = AnsiChar(keyCode and $FF) then
      Exit(idx + 1);

    Inc(idx);
  end;

  Result := 0;
end;

end.
