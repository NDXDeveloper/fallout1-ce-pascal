unit u_pipboy;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/pipboy.h + pipboy.cc
// Pipboy 2000 personal information processor: status, automaps, archives, alarm/rest.

interface

uses
  u_db, u_cache, u_rect;

const
  PIPBOY_OPEN_INTENT_UNSPECIFIED = 0;
  PIPBOY_OPEN_INTENT_REST        = 1;

type
  TPipboyRenderProc = procedure(a1: Integer);

function pipboy(intent: Integer): Integer;
procedure pip_init;
function save_pipboy(stream: PDB_FILE): Integer;
function load_pipboy(stream: PDB_FILE): Integer;

implementation

uses
  SysUtils,
  u_object_types, u_map_defs, u_game_vars, u_stat_defs,
  u_color, u_text, u_grbuf, u_input, u_gnw, u_gnw_types,
  u_button, u_art, u_config, u_gconfig,
  u_automap, u_gmovie, u_map, u_roll, u_wordwrap,
  u_kb, u_fps_limiter, u_mouse, u_platform_compat,
  u_gsound, u_gmouse, u_game, u_cycle, u_intface, u_scripts,
  u_queue, u_stat, u_critter, u_party, u_object, u_message, u_svga,
  u_bmpdlog, u_memory;

// ============================================================================
// External declarations that cannot be imported via uses
// ============================================================================

procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// libc
type
  TQSortCompareFunc = function(a1, a2: Pointer): Integer; cdecl;
procedure libc_qsort(base: Pointer; num: SizeUInt; sz: SizeUInt; compare: TQSortCompareFunc); cdecl; external 'c' name 'qsort';

// ============================================================================
// Constants
// ============================================================================

const
  PIPBOY_RAND_MAX = 32767;

  PIPBOY_WINDOW_WIDTH  = 640;
  PIPBOY_WINDOW_HEIGHT = 480;

  PIPBOY_WINDOW_DAY_X   = 20;
  PIPBOY_WINDOW_DAY_Y   = 17;

  PIPBOY_WINDOW_MONTH_X = 46;
  PIPBOY_WINDOW_MONTH_Y = 18;

  PIPBOY_WINDOW_YEAR_X  = 83;
  PIPBOY_WINDOW_YEAR_Y  = 17;

  PIPBOY_WINDOW_TIME_X  = 155;
  PIPBOY_WINDOW_TIME_Y  = 17;

  PIPBOY_WINDOW_NOTE_X  = 32;
  PIPBOY_WINDOW_NOTE_Y  = 83;

  PIPBOY_HOLODISK_LINES_MAX = 35;

  PIPBOY_WINDOW_CONTENT_VIEW_X      = 254;
  PIPBOY_WINDOW_CONTENT_VIEW_Y      = 46;
  PIPBOY_WINDOW_CONTENT_VIEW_WIDTH  = 374;
  PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT = 410;

  PIPBOY_IDLE_TIMEOUT = 120000;

  PIPBOY_BOMB_COUNT = 16;

  BACK_BUTTON_INDEX = 20;

  QUEST_LOCATION_COUNT   = 12;
  QUEST_PER_LOCATION_COUNT = 9;
  HOLODISK_COUNT         = 18;

  COMPAT_MAX_PATH = 260;

  MOUSE_CURSOR_ARROW      = 1;
  MOUSE_CURSOR_WAIT_WATCH = 26;

  WINDOW_MODAL = $10;

  DIALOG_BOX_LARGE = $04;

  GAME_TIME_TICKS_PER_HOUR = 600;

  // Holiday enum
  HOLIDAY_NEW_YEAR         = 0;
  HOLIDAY_VALENTINES_DAY   = 1;
  HOLIDAY_FOOLS_DAY        = 2;
  HOLIDAY_SHIPPING_DAY     = 3;
  HOLIDAY_INDEPENDENCE_DAY = 4;
  HOLIDAY_HALLOWEEN        = 5;
  HOLIDAY_THANKSGIVING_DAY = 6;
  HOLIDAY_CRISTMAS         = 7;
  HOLIDAY_COUNT            = 8;

  // PipboyTextOptions
  PIPBOY_TEXT_ALIGNMENT_CENTER              = $02;
  PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN        = $04;
  PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER  = $10;
  PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER = $20;
  PIPBOY_TEXT_STYLE_UNDERLINE               = $08;
  PIPBOY_TEXT_STYLE_STRIKE_THROUGH          = $40;
  PIPBOY_TEXT_NO_INDENT                     = $80;

  // PipboyRestDuration
  PIPBOY_REST_DURATION_TEN_MINUTES       = 0;
  PIPBOY_REST_DURATION_THIRTY_MINUTES    = 1;
  PIPBOY_REST_DURATION_ONE_HOUR          = 2;
  PIPBOY_REST_DURATION_TWO_HOURS         = 3;
  PIPBOY_REST_DURATION_THREE_HOURS       = 4;
  PIPBOY_REST_DURATION_FOUR_HOURS        = 5;
  PIPBOY_REST_DURATION_FIVE_HOURS        = 6;
  PIPBOY_REST_DURATION_SIX_HOURS         = 7;
  PIPBOY_REST_DURATION_UNTIL_MORNING     = 8;
  PIPBOY_REST_DURATION_UNTIL_NOON        = 9;
  PIPBOY_REST_DURATION_UNTIL_EVENING     = 10;
  PIPBOY_REST_DURATION_UNTIL_MIDNIGHT    = 11;
  PIPBOY_REST_DURATION_UNTIL_HEALED      = 12;
  PIPBOY_REST_DURATION_UNTIL_PARTY_HEALED = 13;
  PIPBOY_REST_DURATION_COUNT             = 14;
  PIPBOY_REST_DURATION_COUNT_WITHOUT_PARTY = PIPBOY_REST_DURATION_COUNT - 1;

  // PipboyFrm
  PIPBOY_FRM_LITTLE_RED_BUTTON_UP   = 0;
  PIPBOY_FRM_LITTLE_RED_BUTTON_DOWN = 1;
  PIPBOY_FRM_NUMBERS                = 2;
  PIPBOY_FRM_BACKGROUND             = 3;
  PIPBOY_FRM_NOTE                   = 4;
  PIPBOY_FRM_MONTHS                 = 5;
  PIPBOY_FRM_NOTE_NUMBERS           = 6;
  PIPBOY_FRM_ALARM_DOWN             = 7;
  PIPBOY_FRM_ALARM_UP               = 8;
  PIPBOY_FRM_LOGO                   = 9;
  PIPBOY_FRM_BOMB                   = 10;
  PIPBOY_FRM_COUNT                  = 11;

// ============================================================================
// Types
// ============================================================================

type
  THolidayDescription = record
    month: SmallInt;
    day: SmallInt;
    textId: SmallInt;
  end;

  TPipboySortableEntry = record
    name: PAnsiChar;
    value: SmallInt;
    field_6: SmallInt;
  end;

  TPipboyBomb = record
    x: Integer;
    y: Integer;
    field_8: Single;
    field_C: Single;
    field_10: Byte;
  end;

// ============================================================================
// Helper to access game_global_vars by index
// ============================================================================

function ggv(idx: Integer): Integer; inline;
begin
  Result := PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^;
end;

// ============================================================================
// Forward declarations
// ============================================================================

function StartPipboy(intent: Integer): Integer; forward;
procedure EndPipboy; forward;
procedure pip_days_left(days: Integer); forward;
procedure pip_num(value, digits, x, y: Integer); forward;
procedure pip_date; forward;
procedure pip_print(const text: PAnsiChar; a2, a3: Integer); forward;
procedure pip_back(a1: Integer); forward;
procedure PipStatus(a1: Integer); forward;
procedure ListStatLines(a1: Integer); forward;
procedure ShowHoloDisk; forward;
function ListHoloDiskTitles(a1: Integer): Integer; forward;
function qscmp(a1, a2: Pointer): Integer; cdecl; forward;
procedure PipAutomaps(a1: Integer); forward;
function PrintAMelevList(a1: Integer): Integer; forward;
function PrintAMList(a1: Integer): Integer; forward;
procedure PipArchives(a1: Integer); forward;
function ListArchive(a1: Integer): Integer; forward;
procedure PipAlarm(a1: Integer); forward;
procedure DrawAlarmText(a1: Integer); forward;
procedure DrawAlrmHitPnts; forward;
procedure NewFuncDsply; forward;
procedure AddHotLines(start, count: Integer; add_back_button: Boolean); forward;
procedure NixHotLines; forward;
function TimedRest(hours, minutes, kind: Integer): Boolean; forward;
function Check4Health(a1: Integer): Boolean; forward;
function AddHealth: Boolean; forward;
procedure ClacTime(hours, minutes: PInteger; wakeUpHour: Integer); forward;
function ScreenSaver: Integer; forward;
procedure pip_note; forward;

// ============================================================================
// Static data
// ============================================================================

const
  pip_rect: TRect = (
    ulx: PIPBOY_WINDOW_CONTENT_VIEW_X;
    uly: PIPBOY_WINDOW_CONTENT_VIEW_Y;
    lrx: PIPBOY_WINDOW_CONTENT_VIEW_X + PIPBOY_WINDOW_CONTENT_VIEW_WIDTH;
    lry: PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT
  );

  pipgrphs: array[0..PIPBOY_FRM_COUNT - 1] of Integer = (
    8, 9, 82, 127, 128, 129, 130, 131, 132, 133, 226
  );

  holodisks: array[0..HOLODISK_COUNT - 1] of SmallInt = (
    Ord(GVAR_FEV_DISK),
    Ord(GVAR_SECURITY_DISK),
    Ord(GVAR_ARTIFACT_DISK),
    Ord(GVAR_ALPHA_DISK),
    Ord(GVAR_DELTA_DISK),
    Ord(GVAR_VREE_DISK),
    Ord(GVAR_HONOR_DISK),
    Ord(GVAR_MUTANT_DISK),
    Ord(GVAR_BROTHER_HISTORY),
    Ord(GVAR_SOPHIA_DISK),
    Ord(GVAR_MAXSON_DISK),
    Ord(GVAR_MASTER_FILLER_7),
    Ord(GVAR_MASTER_FILLER_8),
    Ord(GVAR_WATER_CHIP_1),
    Ord(GVAR_WATER_CHIP_2),
    Ord(GVAR_WATER_CHIP_3),
    Ord(GVAR_MASTER_FILLER_10),
    Ord(GVAR_DESTROY_MASTER_7)
  );

var
  bk_enable: Boolean = False;

  sthreads: array[0..QUEST_LOCATION_COUNT - 1, 0..QUEST_PER_LOCATION_COUNT - 1] of SmallInt;

  SpclDate: array[0..HOLIDAY_COUNT - 1] of THolidayDescription;

  PipFnctn: array[0..4] of TPipboyRenderProc;

  ginfo: array[0..PIPBOY_FRM_COUNT - 1] of TSize;

  pipmesg: TMessageListItem;
  pipboy_message_file: TMessageList;

  sortlist: array[0..23] of TPipboySortableEntry;

  statcount: Integer;
  scrn_buf: PByte;
  pipbmp: array[0..PIPBOY_FRM_COUNT - 1] of PByte;
  holocount: Integer;
  mouse_y: Integer;
  mouse_x: Integer;
  wait_time: LongWord;
  holopages: Integer;
  HotLines: array[0..20] of Integer;
  old_mouse_x: Integer;
  old_mouse_y: Integer;
  pip_win: Integer;
  grphkey: array[0..PIPBOY_FRM_COUNT - 1] of PCacheEntry;
  holodisk: Integer;
  hot_line_count: Integer;
  savefont: Integer;
  proc_bail_flag: Boolean;
  amlst_mode: Integer;
  crnt_func: Integer;
  actcnt: Integer;
  hot_line_start: Integer;
  cursor_line: Integer;
  rest_time: Integer;
  amcty_indx: Integer;
  view_page: Integer;
  bottom_line: Integer;
  hot_back_line: Byte;
  holo_flag: Byte;
  stat_flag: Byte;

  sharedFpsLimiter: TFpsLimiter;
  sthreads_inited: Boolean = False;

// ============================================================================
// sthreads / SpclDate / PipFnctn initialisation
// ============================================================================

procedure InitStaticData;
var
  loc, q: Integer;
begin
  if sthreads_inited then Exit;
  sthreads_inited := True;

  for loc := 0 to QUEST_LOCATION_COUNT - 1 do
    for q := 0 to QUEST_PER_LOCATION_COUNT - 1 do
      sthreads[loc][q] := 0;

  // Vault 13
  sthreads[0][0] := Ord(GVAR_CALM_REBELS);
  sthreads[0][1] := Ord(GVAR_DESTROY_MASTER_5);
  sthreads[0][2] := Ord(GVAR_DESTROY_MASTER_4);
  sthreads[0][3] := Ord(GVAR_FIND_WATER_CHIP);
  sthreads[0][4] := Ord(GVAR_WATER_THIEF);

  // Shady Sands
  sthreads[2][0] := Ord(GVAR_CURE_JARVIS);
  sthreads[2][1] := Ord(GVAR_MAKE_ANTIDOTE);
  sthreads[2][2] := Ord(GVAR_RESCUE_TANDI);
  sthreads[2][3] := Ord(GVAR_RADSCORPION_SEED);

  // Junktown
  sthreads[3][0] := Ord(GVAR_SAUL_QUEST);
  sthreads[3][1] := Ord(GVAR_KILL_KILLIAN);
  sthreads[3][2] := Ord(GVAR_SAVE_SINTHIA);
  sthreads[3][3] := Ord(GVAR_TRISH_QUEST);
  sthreads[3][4] := Ord(GVAR_CAPTURE_GIZMO);
  sthreads[3][5] := Ord(GVAR_BUST_SKULZ);

  // Necropolis
  sthreads[5][0] := Ord(GVAR_NECROP_MUTANTS_KILLED);
  sthreads[5][1] := Ord(GVAR_NECROP_WATER_PUMP_FIXED);

  // Hub
  sthreads[6][0] := Ord(GVAR_KILL_DEATHCLAW);
  sthreads[6][1] := Ord(GVAR_KILL_JAIN);
  sthreads[6][2] := Ord(GVAR_KILL_MERCHANT);
  sthreads[6][3] := Ord(GVAR_MISSING_CARAVAN);
  sthreads[6][4] := Ord(GVAR_STEAL_NECKLACE);

  // Brotherhood
  sthreads[7][0] := Ord(GVAR_BECOME_AN_INITIATE);
  sthreads[7][1] := Ord(GVAR_FIND_LOST_INITIATE);

  // Glow
  sthreads[9][0] := Ord(GVAR_WEAPONS_ARMED);
  sthreads[9][1] := Ord(GVAR_START_POWER);

  // Boneyard
  sthreads[10][0] := Ord(GVAR_BECOME_BLADE);
  sthreads[10][1] := Ord(GVAR_ROMEO_JULIET);
  sthreads[10][2] := Ord(GVAR_DESTROY_FOLLOWERS);
  sthreads[10][3] := Ord(GVAR_FIND_AGENT);
  sthreads[10][4] := Ord(GVAR_FIX_FARM);
  sthreads[10][5] := Ord(GVAR_LOST_BROTHER);
  sthreads[10][6] := Ord(GVAR_GANG_WAR);

  // SpclDate
  SpclDate[0].month := 1;  SpclDate[0].day := 1;  SpclDate[0].textId := 100;
  SpclDate[1].month := 2;  SpclDate[1].day := 14; SpclDate[1].textId := 101;
  SpclDate[2].month := 4;  SpclDate[2].day := 1;  SpclDate[2].textId := 102;
  SpclDate[3].month := 7;  SpclDate[3].day := 4;  SpclDate[3].textId := 104;
  SpclDate[4].month := 10; SpclDate[4].day := 6;  SpclDate[4].textId := 103;
  SpclDate[5].month := 10; SpclDate[5].day := 31; SpclDate[5].textId := 105;
  SpclDate[6].month := 11; SpclDate[6].day := 28; SpclDate[6].textId := 106;
  SpclDate[7].month := 12; SpclDate[7].day := 25; SpclDate[7].textId := 107;

  PipFnctn[0] := @PipStatus;
  PipFnctn[1] := @PipAutomaps;
  PipFnctn[2] := @PipArchives;
  PipFnctn[3] := @PipAlarm;
  PipFnctn[4] := @PipAlarm;
end;

// ============================================================================
// Public interface
// ============================================================================

function pipboy(intent: Integer): Integer;
var
  keyCode: Integer;
begin
  InitStaticData;

  intent := StartPipboy(intent);
  if intent = -1 then
  begin
    Result := -1;
    Exit;
  end;

  mouseGetPositionInWindow(pip_win, @old_mouse_x, @old_mouse_y);
  wait_time := get_time();

  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input();

    if intent = PIPBOY_OPEN_INTENT_REST then
    begin
      keyCode := 504;
      intent := PIPBOY_OPEN_INTENT_UNSPECIFIED;
    end;

    mouseGetPositionInWindow(pip_win, @mouse_x, @mouse_y);

    if (keyCode <> -1) or (mouse_x <> old_mouse_x) or (mouse_y <> old_mouse_y) then
    begin
      wait_time := get_time();
      old_mouse_x := mouse_x;
      old_mouse_y := mouse_y;
    end
    else
    begin
      if get_time() - wait_time > PIPBOY_IDLE_TIMEOUT then
      begin
        ScreenSaver;
        wait_time := get_time();
        mouseGetPositionInWindow(pip_win, @old_mouse_x, @old_mouse_y);
      end;
    end;

    if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
    begin
      game_quit_with_confirm;
      Break;
    end;

    if (keyCode = 503) or (keyCode = KEY_ESCAPE) or (keyCode = KEY_RETURN)
      or (keyCode = KEY_UPPERCASE_P) or (keyCode = KEY_LOWERCASE_P)
      or (keyCode = KEY_UPPERCASE_Z) or (keyCode = KEY_LOWERCASE_Z)
      or (game_user_wants_to_quit <> 0) then
    begin
      Break;
    end;

    if keyCode = KEY_F12 then
      dump_screen
    else if (keyCode >= 500) and (keyCode <= 504) then
    begin
      crnt_func := keyCode - 500;
      PipFnctn[crnt_func](1024);
    end
    else if (keyCode >= 505) and (keyCode <= 527) then
    begin
      PipFnctn[crnt_func](keyCode - 506);
    end
    else if keyCode = 528 then
    begin
      PipFnctn[crnt_func](1025);
    end
    else if keyCode = KEY_PAGE_DOWN then
    begin
      PipFnctn[crnt_func](1026);
    end
    else if keyCode = KEY_PAGE_UP then
    begin
      PipFnctn[crnt_func](1027);
    end;

    if proc_bail_flag then
      Break;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  EndPipboy;
  Result := 0;
end;

// ============================================================================
// StartPipboy
// ============================================================================

function StartPipboy(intent: Integer): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  index: Integer;
  fid: Integer;
  pipboyWindowX, pipboyWindowY: Integer;
  alarmButton: Integer;
  y, eventCode: Integer;
  btn: Integer;
  month, day, year: Integer;
  holiday: Integer;
  holidayDescription: ^THolidayDescription;
  holidayName: PAnsiChar;
  holidayNameCopy: array[0..255] of AnsiChar;
  len: Integer;
  text: PAnsiChar;
  idx: Integer;
begin
  bk_enable := map_disable_bk_processes;

  cycle_disable;
  gmouse_3d_off;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  savefont := text_curr;
  text_font(101);

  proc_bail_flag := False;
  rest_time := 0;
  cursor_line := 0;
  hot_line_count := 0;
  bottom_line := PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT div text_height() - 1;
  hot_line_start := 0;
  hot_back_line := 0;

  if not message_init(@pipboy_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('pipboy.msg')]);

  if not message_load(@pipboy_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  index := 0;
  while index < PIPBOY_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, pipgrphs[index], 0, 0, 0);
    pipbmp[index] := art_lock(fid, @grphkey[index], @ginfo[index].Width, @ginfo[index].Height);
    if pipbmp[index] = nil then
      Break;
    Inc(index);
  end;

  if index <> PIPBOY_FRM_COUNT then
  begin
    debug_printf(PAnsiChar(#10'** Error loading pipboy graphics! **'#10));
    Dec(index);
    while index >= 0 do
    begin
      art_ptr_unlock(grphkey[index]);
      Dec(index);
    end;
    Result := -1;
    Exit;
  end;

  pipboyWindowX := (screenGetWidth - PIPBOY_WINDOW_WIDTH) div 2;
  pipboyWindowY := (screenGetHeight - PIPBOY_WINDOW_HEIGHT) div 2;
  pip_win := win_add(pipboyWindowX, pipboyWindowY, PIPBOY_WINDOW_WIDTH, PIPBOY_WINDOW_HEIGHT, colorTable[0], WINDOW_MODAL);
  if pip_win = -1 then
  begin
    debug_printf(PAnsiChar(#10'** Error opening pipboy window! **'#10));
    for idx := 0 to PIPBOY_FRM_COUNT - 1 do
      art_ptr_unlock(grphkey[idx]);
    Result := -1;
    Exit;
  end;

  scrn_buf := win_get_buf(pip_win);
  Move(pipbmp[PIPBOY_FRM_BACKGROUND]^, scrn_buf^, PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_HEIGHT);

  pip_note;
  pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
  pip_date;

  alarmButton := win_register_button(pip_win,
    124, 13,
    ginfo[PIPBOY_FRM_ALARM_UP].Width,
    ginfo[PIPBOY_FRM_ALARM_UP].Height,
    -1, -1, -1, 504,
    pipbmp[PIPBOY_FRM_ALARM_UP],
    pipbmp[PIPBOY_FRM_ALARM_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if alarmButton <> -1 then
    win_register_button_sound_func(alarmButton, @gsound_med_butt_press, @gsound_med_butt_release);

  y := 341;
  eventCode := 500;
  for idx := 0 to 4 do
  begin
    if idx <> 1 then
    begin
      btn := win_register_button(pip_win,
        53, y,
        ginfo[PIPBOY_FRM_LITTLE_RED_BUTTON_UP].Width,
        ginfo[PIPBOY_FRM_LITTLE_RED_BUTTON_UP].Height,
        -1, -1, -1, eventCode,
        pipbmp[PIPBOY_FRM_LITTLE_RED_BUTTON_UP],
        pipbmp[PIPBOY_FRM_LITTLE_RED_BUTTON_DOWN],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
      Inc(eventCode);
    end;
    Inc(y, 27);
  end;

  if intent = PIPBOY_OPEN_INTENT_REST then
  begin
    if not critter_can_obj_dude_rest then
    begin
      trans_buf_to_buf(
        pipbmp[PIPBOY_FRM_LOGO],
        ginfo[PIPBOY_FRM_LOGO].Width,
        ginfo[PIPBOY_FRM_LOGO].Height,
        ginfo[PIPBOY_FRM_LOGO].Width,
        scrn_buf + PIPBOY_WINDOW_WIDTH * 156 + 323,
        PIPBOY_WINDOW_WIDTH);

      game_time_date(@month, @day, @year);

      holiday := 0;
      while holiday < HOLIDAY_COUNT do
      begin
        holidayDescription := @SpclDate[holiday];
        if (holidayDescription^.month = month) and (holidayDescription^.day = day) then
          Break;
        Inc(holiday);
      end;

      if holiday <> HOLIDAY_COUNT then
      begin
        holidayDescription := @SpclDate[holiday];
        holidayName := getmsg(@pipboy_message_file, @pipmesg, holidayDescription^.textId);
        StrCopy(@holidayNameCopy[0], holidayName);

        len := text_width(@holidayNameCopy[0]);
        text_to_buf(scrn_buf + PIPBOY_WINDOW_WIDTH * (ginfo[PIPBOY_FRM_LOGO].Height + 174) + 6 + ginfo[PIPBOY_FRM_LOGO].Width div 2 + 323 - len div 2,
          @holidayNameCopy[0], 350, PIPBOY_WINDOW_WIDTH, colorTable[992]);
      end;

      win_draw(pip_win);

      gsound_play_sfx_file('iisxxxx1');

      text := getmsg(@pipboy_message_file, @pipmesg, 215);
      dialog_out(text, nil, 0, 192, 135, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

      intent := PIPBOY_OPEN_INTENT_UNSPECIFIED;
    end;
  end
  else
  begin
    trans_buf_to_buf(
      pipbmp[PIPBOY_FRM_LOGO],
      ginfo[PIPBOY_FRM_LOGO].Width,
      ginfo[PIPBOY_FRM_LOGO].Height,
      ginfo[PIPBOY_FRM_LOGO].Width,
      scrn_buf + PIPBOY_WINDOW_WIDTH * 156 + 323,
      PIPBOY_WINDOW_WIDTH);

    game_time_date(@month, @day, @year);

    holiday := 0;
    while holiday < HOLIDAY_COUNT do
    begin
      holidayDescription := @SpclDate[holiday];
      if (holidayDescription^.month = month) and (holidayDescription^.day = day) then
        Break;
      Inc(holiday);
    end;

    if holiday <> HOLIDAY_COUNT then
    begin
      holidayDescription := @SpclDate[holiday];
      holidayName := getmsg(@pipboy_message_file, @pipmesg, holidayDescription^.textId);
      StrCopy(@holidayNameCopy[0], holidayName);

      len := text_width(@holidayNameCopy[0]);
      text_to_buf(scrn_buf + PIPBOY_WINDOW_WIDTH * (ginfo[PIPBOY_FRM_LOGO].Height + 174) + 6 + ginfo[PIPBOY_FRM_LOGO].Width div 2 + 323 - len div 2,
        @holidayNameCopy[0], 350, PIPBOY_WINDOW_WIDTH, colorTable[992]);
    end;

    win_draw(pip_win);
  end;

  gsound_play_sfx_file('pipon');
  win_draw(pip_win);

  Result := intent;
end;

// ============================================================================
// EndPipboy
// ============================================================================

procedure EndPipboy;
var
  showScriptMessages: Boolean;
  idx: Integer;
begin
  showScriptMessages := False;
  configGetBool(@game_config, GAME_CONFIG_DEBUG_KEY, GAME_CONFIG_SHOW_SCRIPT_MESSAGES_KEY, @showScriptMessages);

  if showScriptMessages then
    debug_printf(PAnsiChar(#10'Script <Map Update>'));

  scr_exec_map_update_scripts;

  win_delete(pip_win);
  message_exit(@pipboy_message_file);

  for idx := 0 to PIPBOY_FRM_COUNT - 1 do
    art_ptr_unlock(grphkey[idx]);

  NixHotLines;
  text_font(savefont);

  if bk_enable then
    map_enable_bk_processes;

  cycle_enable;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  intface_redraw;
end;

// ============================================================================
// pip_init
// ============================================================================

procedure pip_init;
begin
  // intentionally empty
end;

// ============================================================================
// pip_days_left
// ============================================================================

procedure pip_days_left(days: Integer);
var
  x, y_: Integer;
begin
  x := 92;
  y_ := PIPBOY_WINDOW_WIDTH * 180;

  while days <> 0 do
  begin
    trans_buf_to_buf(pipbmp[PIPBOY_FRM_NOTE_NUMBERS] + 12 * (days mod 10),
      12,
      ginfo[PIPBOY_FRM_NOTE_NUMBERS].Height,
      ginfo[PIPBOY_FRM_NOTE_NUMBERS].Width,
      scrn_buf + y_ + x,
      PIPBOY_WINDOW_WIDTH);

    if (days mod 10) = 1 then
      Inc(x, 6);

    days := days div 10;
    Dec(x, 12);
    Inc(y_, PIPBOY_WINDOW_WIDTH * 2);
  end;
end;

// ============================================================================
// pip_num
// ============================================================================

procedure pip_num(value, digits, x, y: Integer);
var
  offset: Integer;
  idx: Integer;
begin
  offset := PIPBOY_WINDOW_WIDTH * y + x + 9 * (digits - 1);
  idx := 0;
  while idx < digits do
  begin
    buf_to_buf(pipbmp[PIPBOY_FRM_NUMBERS] + 9 * (value mod 10), 9, 17, 360, scrn_buf + offset, PIPBOY_WINDOW_WIDTH);
    Dec(offset, 9);
    value := value div 10;
    Inc(idx);
  end;
end;

// ============================================================================
// pip_date
// ============================================================================

procedure pip_date;
var
  day, month, year: Integer;
begin
  game_time_date(@month, @day, @year);
  pip_num(day, 2, PIPBOY_WINDOW_DAY_X, PIPBOY_WINDOW_DAY_Y);
  buf_to_buf(pipbmp[PIPBOY_FRM_MONTHS] + 435 * (month - 1), 29, 14, 29,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_MONTH_Y + PIPBOY_WINDOW_MONTH_X, PIPBOY_WINDOW_WIDTH);
  pip_num(year, 4, PIPBOY_WINDOW_YEAR_X, PIPBOY_WINDOW_YEAR_Y);
end;

// ============================================================================
// pip_print
// ============================================================================

procedure pip_print(const text: PAnsiChar; a2, a3: Integer);
var
  color: Integer;
  left_: Integer;
  length_: Integer;
  top_: Integer;
begin
  color := a3;
  if (a2 and PIPBOY_TEXT_STYLE_UNDERLINE) <> 0 then
    color := color or FONT_UNDERLINE;

  left_ := 8;
  if (a2 and PIPBOY_TEXT_NO_INDENT) <> 0 then
    Dec(left_, 7);

  length_ := text_width(text);

  if (a2 and PIPBOY_TEXT_ALIGNMENT_CENTER) <> 0 then
    left_ := (350 - length_) div 2
  else if (a2 and PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN) <> 0 then
    Inc(left_, 175)
  else if (a2 and PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER) <> 0 then
    Inc(left_, 86 - length_ + 16)
  else if (a2 and PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER) <> 0 then
    Inc(left_, 260 - length_);

  text_to_buf(
    scrn_buf + PIPBOY_WINDOW_WIDTH * (cursor_line * text_height() + PIPBOY_WINDOW_CONTENT_VIEW_Y) + PIPBOY_WINDOW_CONTENT_VIEW_X + left_,
    text, PIPBOY_WINDOW_WIDTH, PIPBOY_WINDOW_WIDTH, color);

  if (a2 and PIPBOY_TEXT_STYLE_STRIKE_THROUGH) <> 0 then
  begin
    top_ := cursor_line * text_height() + 49;
    draw_line(scrn_buf, PIPBOY_WINDOW_WIDTH,
      PIPBOY_WINDOW_CONTENT_VIEW_X + left_, top_,
      PIPBOY_WINDOW_CONTENT_VIEW_X + left_ + length_, top_, color);
  end;

  if cursor_line < bottom_line then
    Inc(cursor_line);
end;

// ============================================================================
// pip_back
// ============================================================================

procedure pip_back(a1: Integer);
var
  text: PAnsiChar;
begin
  if bottom_line >= 0 then
    cursor_line := bottom_line;

  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * 436 + 254,
    350, 20, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * 436 + 254, PIPBOY_WINDOW_WIDTH);

  // BACK
  text := getmsg(@pipboy_message_file, @pipmesg, 201);
  pip_print(text, PIPBOY_TEXT_ALIGNMENT_CENTER, a1);
end;

// ============================================================================
// save_pipboy / load_pipboy
// ============================================================================

function save_pipboy(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

function load_pipboy(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// ============================================================================
// PipStatus
// ============================================================================

procedure PipStatus(a1: Integer);
var
  idx: Integer;
  v13, location, quest, value: Integer;
  text1, text2: PAnsiChar;
  formattedText: array[0..1023] of AnsiChar;
  number: Integer;
  text: PAnsiChar;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  count: SmallInt;
  line: Integer;
  beginning, ending: PAnsiChar;
  c: AnsiChar;
  flags, clr: Integer;
begin
  if a1 = 1024 then
  begin
    NixHotLines;
    buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
      scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_WIDTH);
    if bottom_line >= 0 then
      cursor_line := 0;

    holo_flag := 0;
    holodisk := -1;
    holocount := 0;
    view_page := 0;
    stat_flag := 0;

    for idx := 0 to HOLODISK_COUNT - 1 do
    begin
      if ggv(holodisks[idx]) <> 0 then
      begin
        Inc(holocount);
        Break;
      end;
    end;

    ListStatLines(-1);

    if statcount = 0 then
    begin
      text := getmsg(@pipboy_message_file, @pipmesg, 203);
      pip_print(text, 0, colorTable[992]);
    end;

    holocount := ListHoloDiskTitles(-1);

    win_draw_rect(pip_win, @pip_rect);
    AddHotLines(2, statcount + holocount + 1, False);
    win_draw(pip_win);
    Exit;
  end;

  if (stat_flag = 0) and (holo_flag = 0) then
  begin
    if (statcount <> 0) and (mouse_x < 429) then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
        PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
        scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
        PIPBOY_WINDOW_WIDTH);
      ListStatLines(a1);
      ListHoloDiskTitles(-1);
      win_draw_rect(pip_win, @pip_rect);
      pause_for_tocks(200);
      stat_flag := 1;
    end
    else
    begin
      if (holocount <> 0) and (holocount >= a1) and (mouse_x > 429) then
      begin
        gsound_play_sfx_file('ib1p1xx1');
        holodisk := 0;

        idx := 0;
        while idx < HOLODISK_COUNT do
        begin
          if ggv(holodisks[idx]) > 0 then
          begin
            if (a1 - 1) = holodisk then
              Break;
            Inc(holodisk);
          end;
          Inc(idx);
        end;
        holodisk := idx;

        buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
          PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
          scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
          PIPBOY_WINDOW_WIDTH);
        ListHoloDiskTitles(holodisk);
        ListStatLines(-1);
        win_draw_rect(pip_win, @pip_rect);
        pause_for_tocks(200);
        NixHotLines;
        ShowHoloDisk;
        AddHotLines(0, 0, True);
        holo_flag := 1;
      end;
    end;
  end;

  if stat_flag = 0 then
  begin
    if (holo_flag = 0) or (a1 < 1025) or (a1 > 1027) then
      Exit;

    if ((mouse_x > 459) and (a1 <> 1027)) or (a1 = 1026) then
    begin
      if holopages <= view_page then
      begin
        if a1 <> 1026 then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * 436 + 254, 350, 20, PIPBOY_WINDOW_WIDTH,
            scrn_buf + PIPBOY_WINDOW_WIDTH * 436 + 254, PIPBOY_WINDOW_WIDTH);

          if bottom_line >= 0 then cursor_line := bottom_line;
          text1 := getmsg(@pipboy_message_file, @pipmesg, 201);
          pip_print(text1, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

          if bottom_line >= 0 then cursor_line := bottom_line;
          text2 := getmsg(@pipboy_message_file, @pipmesg, 214);
          pip_print(text2, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER, colorTable[992]);

          win_draw_rect(pip_win, @pip_rect);
          pause_for_tocks(200);
          PipStatus(1024);
        end;
      end
      else
      begin
        gsound_play_sfx_file('ib1p1xx1');
        buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * 436 + 254, 350, 20, PIPBOY_WINDOW_WIDTH,
          scrn_buf + PIPBOY_WINDOW_WIDTH * 436 + 254, PIPBOY_WINDOW_WIDTH);

        if bottom_line >= 0 then cursor_line := bottom_line;
        text1 := getmsg(@pipboy_message_file, @pipmesg, 201);
        pip_print(text1, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

        if bottom_line >= 0 then cursor_line := bottom_line;
        text2 := getmsg(@pipboy_message_file, @pipmesg, 200);
        pip_print(text2, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER, colorTable[992]);

        win_draw_rect(pip_win, @pip_rect);
        pause_for_tocks(200);

        Inc(view_page);
        ShowHoloDisk;
      end;
      Exit;
    end;

    if a1 = 1027 then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * 436 + 254, 350, 20, PIPBOY_WINDOW_WIDTH,
        scrn_buf + PIPBOY_WINDOW_WIDTH * 436 + 254, PIPBOY_WINDOW_WIDTH);

      if bottom_line >= 0 then cursor_line := bottom_line;
      text1 := getmsg(@pipboy_message_file, @pipmesg, 201);
      pip_print(text1, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

      if bottom_line >= 0 then cursor_line := bottom_line;
      text2 := getmsg(@pipboy_message_file, @pipmesg, 200);
      pip_print(text2, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER, colorTable[992]);

      win_draw_rect(pip_win, @pip_rect);
      pause_for_tocks(200);

      Dec(view_page);
      if view_page < 0 then
      begin
        PipStatus(1024);
        Exit;
      end;
    end
    else
    begin
      if mouse_x > 395 then
        Exit;

      gsound_play_sfx_file('ib1p1xx1');
      buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * 436 + 254, 350, 20, PIPBOY_WINDOW_WIDTH,
        scrn_buf + PIPBOY_WINDOW_WIDTH * 436 + 254, PIPBOY_WINDOW_WIDTH);

      if bottom_line >= 0 then cursor_line := bottom_line;
      text1 := getmsg(@pipboy_message_file, @pipmesg, 201);
      pip_print(text1, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

      if bottom_line >= 0 then cursor_line := bottom_line;
      text2 := getmsg(@pipboy_message_file, @pipmesg, 200);
      pip_print(text2, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER, colorTable[992]);

      win_draw_rect(pip_win, @pip_rect);
      pause_for_tocks(200);

      if view_page <= 0 then
      begin
        PipStatus(1024);
        Exit;
      end;

      Dec(view_page);
    end;

    ShowHoloDisk;
    Exit;
  end;

  if a1 = 1025 then
  begin
    gsound_play_sfx_file('ib1p1xx1');
    pip_back(colorTable[32747]);
    win_draw_rect(pip_win, @pip_rect);
    pause_for_tocks(200);
    PipStatus(1024);
  end;

  if a1 <= statcount then
  begin
    gsound_play_sfx_file('ib1p1xx1');

    v13 := 0;
    location := 0;
    while (location < QUEST_LOCATION_COUNT) and (v13 <> -1) do
    begin
      quest := 0;
      while quest < QUEST_PER_LOCATION_COUNT do
      begin
        if sthreads[location][quest] = 0 then
          Break;

        value := ggv(sthreads[location][quest]);
        if sthreads[location][quest] = Ord(GVAR_FIND_WATER_CHIP) then
          value := 1;

        if value > 0 then
        begin
          if v13 = a1 - 1 then
            v13 := -1
          else
            Inc(v13);
          Break;
        end;
        Inc(quest);
      end;
      Inc(location);
    end;

    NewFuncDsply;

    Dec(location);

    if bottom_line >= 1 then
      cursor_line := 1;

    AddHotLines(0, 0, True);

    text1 := getmsg(@pipboy_message_file, @pipmesg, 210);
    text2 := getmsg(@pipboy_message_file, @pipmesg, 700 + 10 * location);
    StrLFmt(@formattedText[0], SizeOf(formattedText) - 1, '%s %s', [text2, text1]);
    pip_print(@formattedText[0], PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

    if bottom_line >= 3 then
      cursor_line := 3;

    number := 1;
    quest := 0;
    while quest < QUEST_PER_LOCATION_COUNT do
    begin
      if sthreads[location][quest] = 0 then
        Break;

      value := ggv(sthreads[location][quest]);
      if sthreads[location][quest] = Ord(GVAR_FIND_WATER_CHIP) then
      begin
        if value > 1 then
          value := 2
        else
          value := 1;
      end;

      if value > 0 then
      begin
        text := getmsg(@pipboy_message_file, @pipmesg, 701 + 10 * location + quest);
        StrLFmt(@formattedText[0], SizeOf(formattedText) - 1, '%d. %s', [number, text]);
        Inc(number);

        if word_wrap(@formattedText[0], 350, @beginnings[0], @count) = 0 then
        begin
          line := 0;
          while line < count - 1 do
          begin
            beginning := @formattedText[0] + beginnings[line];
            ending := @formattedText[0] + beginnings[line + 1];
            c := ending^;
            ending^ := #0;

            if value = 1 then
            begin
              flags := 0;
              clr := colorTable[992];
            end
            else
            begin
              flags := PIPBOY_TEXT_STYLE_STRIKE_THROUGH;
              clr := colorTable[8804];
            end;

            pip_print(beginning, flags, clr);

            ending^ := c;
            Inc(cursor_line);
            Inc(line);
          end;
        end
        else
        begin
          debug_printf(PAnsiChar(#10' ** Word wrap error in pipboy! **'#10));
        end;
      end;
      Inc(quest);
    end;

    pip_back(colorTable[992]);
    win_draw_rect(pip_win, @pip_rect);
    stat_flag := 1;
  end;
end;

// ============================================================================
// ListStatLines
// ============================================================================

procedure ListStatLines(a1: Integer);
var
  flags_: Integer;
  statusText: PAnsiChar;
  location, quest: Integer;
  value: Integer;
  color: Integer;
  questLocation: PAnsiChar;
begin
  if bottom_line >= 0 then
    cursor_line := 0;

  if holocount <> 0 then
    flags_ := PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER
  else
    flags_ := PIPBOY_TEXT_ALIGNMENT_CENTER;
  flags_ := flags_ or PIPBOY_TEXT_STYLE_UNDERLINE;

  // STATUS
  statusText := getmsg(@pipboy_message_file, @pipmesg, 202);
  pip_print(statusText, flags_, colorTable[992]);

  if bottom_line >= 2 then
    cursor_line := 2;

  statcount := 0;

  for location := 0 to QUEST_LOCATION_COUNT - 1 do
  begin
    quest := 0;
    while quest < 9 do
    begin
      value := ggv(sthreads[location][quest]);
      if sthreads[location][quest] = Ord(GVAR_FIND_WATER_CHIP) then
        value := 1;

      if value > 0 then
      begin
        if (cursor_line - 1) div 2 = (a1 - 1) then
          color := colorTable[32747]
        else
          color := colorTable[992];

        questLocation := getmsg(@pipboy_message_file, @pipmesg, 700 + 10 * location);
        pip_print(questLocation, 0, color);

        Inc(cursor_line);
        Inc(statcount);

        Break;
      end;
      Inc(quest);
    end;
  end;
end;

// ============================================================================
// ShowHoloDisk
// ============================================================================

procedure ShowHoloDisk;
var
  holodiskTextId: Integer;
  linesCount: Integer;
  text: PAnsiChar;
  formattedText: array[0..59] of AnsiChar;
  page, numberOfLines: Integer;
  ofText: PAnsiChar;
  len: Integer;
  line: Integer;
  moreOrDoneTextId: Integer;
  moreOrDoneText, back: PAnsiChar;
begin
  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  if bottom_line >= 0 then
    cursor_line := 0;

  linesCount := 0;
  holopages := 0;

  holodiskTextId := 1000 * holodisk + 1000;
  while holodiskTextId < 1000 * holodisk + 1500 do
  begin
    text := getmsg(@pipboy_message_file, @pipmesg, holodiskTextId);
    if StrComp(text, '**END-DISK**') = 0 then
      Break;

    Inc(linesCount);
    if linesCount >= PIPBOY_HOLODISK_LINES_MAX then
    begin
      linesCount := 0;
      Inc(holopages);
    end;
    Inc(holodiskTextId);
  end;

  if holodiskTextId >= 1000 * holodisk + 1500 then
    debug_printf(PAnsiChar(#10'PIPBOY: #1 Holodisk text end not found!'#10));

  holodiskTextId := 1000 * holodisk + 1000;

  if view_page <> 0 then
  begin
    page := 0;
    numberOfLines := 0;
    while holodiskTextId < 1000 * holodisk + 1500 do
    begin
      text := getmsg(@pipboy_message_file, @pipmesg, holodiskTextId);
      if StrComp(text, '**END-DISK**') = 0 then
      begin
        debug_printf(PAnsiChar(#10'PIPBOY: Premature page end in holodisk page search!'#10));
        Break;
      end;

      Inc(numberOfLines);
      if numberOfLines >= PIPBOY_HOLODISK_LINES_MAX then
      begin
        Inc(page);
        if page >= view_page then
          Break;
        numberOfLines := 0;
      end;
      Inc(holodiskTextId);
    end;

    Inc(holodiskTextId);

    if holodiskTextId >= 1000 * holodisk + 1500 then
      debug_printf(PAnsiChar(#10'PIPBOY: #2 Holodisk text end not found!'#10));
  end
  else
  begin
    text := getmsg(@pipboy_message_file, @pipmesg, holodisk + 400);
    pip_print(text, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);
  end;

  if holopages <> 0 then
  begin
    // of
    ofText := getmsg(@pipboy_message_file, @pipmesg, 212);
    StrLFmt(@formattedText[0], SizeOf(formattedText) - 1, '%d %s %d', [view_page + 1, ofText, holopages + 1]);

    len := text_width(ofText);
    text_to_buf(scrn_buf + PIPBOY_WINDOW_WIDTH * 47 + 616 + 604 - len,
      @formattedText[0], 350, PIPBOY_WINDOW_WIDTH, colorTable[992]);
  end;

  if bottom_line >= 3 then
    cursor_line := 3;

  line := 0;
  while line < PIPBOY_HOLODISK_LINES_MAX do
  begin
    text := getmsg(@pipboy_message_file, @pipmesg, holodiskTextId);
    if StrComp(text, '**END-DISK**') = 0 then
      Break;

    if StrComp(text, '**END-PAR**') = 0 then
      Inc(cursor_line)
    else
      pip_print(text, PIPBOY_TEXT_NO_INDENT, colorTable[992]);

    Inc(holodiskTextId);
    Inc(line);
  end;

  if holopages <= view_page then
  begin
    if bottom_line >= 0 then cursor_line := bottom_line;
    back := getmsg(@pipboy_message_file, @pipmesg, 201);
    pip_print(back, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

    if bottom_line >= 0 then cursor_line := bottom_line;
    moreOrDoneTextId := 214;
  end
  else
  begin
    if bottom_line >= 0 then cursor_line := bottom_line;
    back := getmsg(@pipboy_message_file, @pipmesg, 201);
    pip_print(back, PIPBOY_TEXT_ALIGNMENT_LEFT_COLUMN_CENTER, colorTable[992]);

    if bottom_line >= 0 then cursor_line := bottom_line;
    moreOrDoneTextId := 200;
  end;

  moreOrDoneText := getmsg(@pipboy_message_file, @pipmesg, moreOrDoneTextId);
  pip_print(moreOrDoneText, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER, colorTable[992]);
  win_draw(pip_win);
end;

// ============================================================================
// ListHoloDiskTitles
// ============================================================================

function ListHoloDiskTitles(a1: Integer): Integer;
var
  knownHolodisksCount: Integer;
  idx: Integer;
  color: Integer;
  text: PAnsiChar;
begin
  if bottom_line >= 2 then
    cursor_line := 2;

  knownHolodisksCount := 0;
  for idx := 0 to HOLODISK_COUNT - 1 do
  begin
    if ggv(holodisks[idx]) <> 0 then
    begin
      if (cursor_line - 2) div 2 = a1 then
        color := colorTable[32747]
      else
        color := colorTable[992];

      text := getmsg(@pipboy_message_file, @pipmesg, 400 + idx);
      pip_print(text, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN, color);

      Inc(cursor_line);
      Inc(knownHolodisksCount);
    end;
  end;

  if knownHolodisksCount <> 0 then
  begin
    if bottom_line >= 0 then
      cursor_line := 0;

    text := getmsg(@pipboy_message_file, @pipmesg, 211); // DATA
    pip_print(text, PIPBOY_TEXT_ALIGNMENT_RIGHT_COLUMN_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);
  end;

  Result := knownHolodisksCount;
end;

// ============================================================================
// qscmp
// ============================================================================

function qscmp(a1, a2: Pointer): Integer; cdecl;
var
  v1, v2: ^TPipboySortableEntry;
begin
  v1 := a1;
  v2 := a2;
  Result := StrComp(v1^.name, v2^.name);
end;

// ============================================================================
// PipAutomaps
// ============================================================================

procedure PipAutomaps(a1: Integer);
var
  title: PAnsiChar;
begin
  if a1 = 1024 then
  begin
    NixHotLines;
    buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
      scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_WIDTH);

    if bottom_line >= 0 then
      cursor_line := 0;

    title := getmsg(@pipboy_message_file, @pipmesg, 205);
    pip_print(title, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

    actcnt := PrintAMList(-1);

    AddHotLines(2, actcnt, False);

    win_draw_rect(pip_win, @pip_rect);
    amlst_mode := 0;
    Exit;
  end;

  if amlst_mode <> 0 then
  begin
    if (a1 = 1025) or (a1 <= -1) then
    begin
      PipAutomaps(1024);
      gsound_play_sfx_file('ib1p1xx1');
    end;

    if (a1 >= 1) and (a1 <= actcnt + 3) then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      PrintAMelevList(a1);
      draw_top_down_map_pipboy(pip_win, sortlist[a1 - 1].field_6, sortlist[a1 - 1].value);
      win_draw_rect(pip_win, @pip_rect);
    end;
    Exit;
  end;

  if (a1 > 0) and (a1 <= actcnt) then
  begin
    gsound_play_sfx_file('ib1p1xx1');
    NixHotLines;
    PrintAMList(a1);
    win_draw_rect(pip_win, @pip_rect);
    amcty_indx := sortlist[a1 - 1].value;
    actcnt := PrintAMelevList(1);
    AddHotLines(0, actcnt + 2, True);
    draw_top_down_map_pipboy(pip_win, sortlist[0].field_6, sortlist[0].value);
    win_draw_rect(pip_win, @pip_rect);
    amlst_mode := 1;
  end;
end;

// ============================================================================
// PrintAMelevList
// ============================================================================

function PrintAMelevList(a1: Integer): Integer;
var
  automapHeader: PAutomapHeader;
  line: Integer;
  elevation: Integer;
  idx, mapIdx: Integer;
  msg: PAnsiChar;
  name: PAnsiChar;
  selectedPipboyLine: Integer;
  color: Integer;
begin
  if ReadAMList(@automapHeader) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  line := 0;
  for elevation := 0 to ELEVATION_COUNT - 1 do
  begin
    if automapHeader^.offsets[amcty_indx][elevation] > 0 then
    begin
      sortlist[line].name := map_get_elev_idx(amcty_indx, elevation);
      sortlist[line].value := elevation;
      sortlist[line].field_6 := amcty_indx;
      Inc(line);
    end;
  end;

  for idx := 0 to 4 do
  begin
    mapIdx := get_map_idx_same(amcty_indx, idx);
    if mapIdx <> -1 then
    begin
      for elevation := 0 to ELEVATION_COUNT - 1 do
      begin
        if automapHeader^.offsets[mapIdx][elevation] > 0 then
        begin
          sortlist[line].name := map_get_elev_idx(mapIdx, elevation);
          sortlist[line].value := elevation;
          sortlist[line].field_6 := mapIdx;
          Inc(line);
        end;
      end;
    end;
  end;

  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  if bottom_line >= 0 then
    cursor_line := 0;

  msg := getmsg(@pipboy_message_file, @pipmesg, 205);
  pip_print(msg, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

  if bottom_line >= 2 then
    cursor_line := 2;

  name := map_get_description_idx(amcty_indx);
  pip_print(name, PIPBOY_TEXT_ALIGNMENT_CENTER, colorTable[992]);

  if bottom_line >= 4 then
    cursor_line := 4;

  selectedPipboyLine := (a1 - 1) * 2;

  for idx := 0 to line - 1 do
  begin
    if cursor_line - 4 = selectedPipboyLine then
      color := colorTable[32747]
    else
      color := colorTable[992];

    pip_print(sortlist[idx].name, 0, color);
    Inc(cursor_line);
  end;

  pip_back(colorTable[992]);

  Result := line;
end;

// ============================================================================
// PrintAMList
// ============================================================================

function PrintAMList(a1: Integer): Integer;
var
  automapHeader: PAutomapHeader;
  count: Integer;
  mapIdx, elevation: Integer;
  v7: Integer;
  idx: Integer;
  msg: PAnsiChar;
  color: Integer;
begin
  if ReadAMList(@automapHeader) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  count := 0;

  for mapIdx := 0 to MAP_COUNT - 1 do
  begin
    elevation := 0;
    while elevation < ELEVATION_COUNT do
    begin
      if automapHeader^.offsets[mapIdx][elevation] > 0 then
        Break;
      Inc(elevation);
    end;

    if elevation < ELEVATION_COUNT then
    begin
      if count <> 0 then
      begin
        v7 := 0;
        idx := 0;
        while idx < count do
        begin
          if is_map_idx_same(mapIdx, sortlist[idx].value) then
            Break;
          Inc(v7);
          Inc(idx);
        end;
      end
      else
        v7 := 0;

      if v7 = count then
      begin
        sortlist[count].name := map_get_short_name(mapIdx);
        sortlist[count].value := mapIdx;
        Inc(count);
      end;
    end;
  end;

  if count <> 0 then
  begin
    if count > 1 then
      libc_qsort(@sortlist[0], count, SizeOf(TPipboySortableEntry), @qscmp);

    buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
      scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
      PIPBOY_WINDOW_WIDTH);

    if bottom_line >= 0 then
      cursor_line := 0;

    msg := getmsg(@pipboy_message_file, @pipmesg, 205);
    pip_print(msg, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

    if bottom_line >= 2 then
      cursor_line := 2;

    for idx := 0 to count - 1 do
    begin
      if cursor_line - 1 = a1 then
        color := colorTable[32747]
      else
        color := colorTable[992];

      pip_print(sortlist[idx].name, 0, color);
      Inc(cursor_line);
    end;
  end;

  Result := count;
end;

// ============================================================================
// PipArchives
// ============================================================================

procedure PipArchives(a1: Integer);
var
  movie: Integer;
begin
  if a1 = 1024 then
  begin
    NixHotLines;
    view_page := ListArchive(-1);
    AddHotLines(2, view_page, False);
  end
  else if (a1 >= 0) and (a1 <= view_page) then
  begin
    gsound_play_sfx_file('ib1p1xx1');

    ListArchive(a1);

    movie := MOVIE_VEXPLD;
    while movie < MOVIE_COUNT do
    begin
      if gmovie_has_been_played(movie) then
      begin
        Dec(a1);
        if a1 <= 0 then
          Break;
      end;
      Inc(movie);
    end;

    if movie <= MOVIE_COUNT then
      gmovie_play(movie, GAME_MOVIE_FADE_IN or GAME_MOVIE_FADE_OUT or GAME_MOVIE_PAUSE_MUSIC)
    else
      debug_printf(PAnsiChar(#10' ** Selected movie not found in list! **'#10));

    text_font(101);
    wait_time := get_time();
    ListArchive(-1);
  end;
end;

// ============================================================================
// ListArchive
// ============================================================================

function ListArchive(a1: Integer): Integer;
var
  text: PAnsiChar;
  movie: Integer;
  line: Integer;
  color: Integer;
begin
  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  if bottom_line >= 0 then
    cursor_line := 0;

  // VIDEO ARCHIVES
  text := getmsg(@pipboy_message_file, @pipmesg, 206);
  pip_print(text, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

  if bottom_line >= 2 then
    cursor_line := 2;

  line := 0;

  movie := MOVIE_VEXPLD;
  while movie < MOVIE_COUNT do
  begin
    if gmovie_has_been_played(movie) then
    begin
      if line = a1 - 1 then
        color := colorTable[32747]
      else
        color := colorTable[992];
      Inc(line);

      text := getmsg(@pipboy_message_file, @pipmesg, 500 + movie);
      pip_print(text, 0, color);

      Inc(cursor_line);
    end;
    Inc(movie);
  end;

  win_draw_rect(pip_win, @pip_rect);

  Result := line;
end;

// ============================================================================
// PipAlarm
// ============================================================================

procedure PipAlarm(a1: Integer);
var
  text: PAnsiChar;
  duration: Integer;
  minutes, hours: Integer;
begin
  if a1 = 1024 then
  begin
    if critter_can_obj_dude_rest then
    begin
      NixHotLines;
      DrawAlarmText(0);
      AddHotLines(5, PIPBOY_REST_DURATION_COUNT_WITHOUT_PARTY, False);
    end
    else
    begin
      gsound_play_sfx_file('iisxxxx1');
      // You cannot rest at this location!
      text := getmsg(@pipboy_message_file, @pipmesg, 215);
      dialog_out(text, nil, 0, 192, 135, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
    end;
  end
  else if (a1 >= 4) and (a1 <= 17) then
  begin
    gsound_play_sfx_file('ib1p1xx1');

    DrawAlarmText(a1 - 3);

    duration := a1 - 4;
    minutes := 0;
    hours := 0;

    case duration of
      PIPBOY_REST_DURATION_TEN_MINUTES:
        TimedRest(0, 10, 0);
      PIPBOY_REST_DURATION_THIRTY_MINUTES:
        TimedRest(0, 30, 0);
      PIPBOY_REST_DURATION_ONE_HOUR,
      PIPBOY_REST_DURATION_TWO_HOURS,
      PIPBOY_REST_DURATION_THREE_HOURS,
      PIPBOY_REST_DURATION_FOUR_HOURS,
      PIPBOY_REST_DURATION_FIVE_HOURS,
      PIPBOY_REST_DURATION_SIX_HOURS:
        TimedRest(duration - 1, 0, 0);
      PIPBOY_REST_DURATION_UNTIL_MORNING:
      begin
        ClacTime(@hours, @minutes, 6);
        TimedRest(hours, minutes, 0);
      end;
      PIPBOY_REST_DURATION_UNTIL_NOON:
      begin
        ClacTime(@hours, @minutes, 12);
        TimedRest(hours, minutes, 0);
      end;
      PIPBOY_REST_DURATION_UNTIL_EVENING:
      begin
        ClacTime(@hours, @minutes, 18);
        TimedRest(hours, minutes, 0);
      end;
      PIPBOY_REST_DURATION_UNTIL_MIDNIGHT:
      begin
        ClacTime(@hours, @minutes, 0);
        if not TimedRest(hours, minutes, 0) then
          pip_num(0, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
        win_draw(pip_win);
      end;
      PIPBOY_REST_DURATION_UNTIL_HEALED:
        TimedRest(0, 0, duration);
    end;

    gsound_play_sfx_file('ib2lu1x1');
    DrawAlarmText(0);
  end;
end;

// ============================================================================
// DrawAlarmText
// ============================================================================

procedure DrawAlarmText(a1: Integer);
var
  text: PAnsiChar;
  option: Integer;
  color: Integer;
begin
  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  if bottom_line >= 0 then
    cursor_line := 0;

  // ALARM CLOCK
  text := getmsg(@pipboy_message_file, @pipmesg, 300);
  pip_print(text, PIPBOY_TEXT_ALIGNMENT_CENTER or PIPBOY_TEXT_STYLE_UNDERLINE, colorTable[992]);

  if bottom_line >= 5 then
    cursor_line := 5;

  DrawAlrmHitPnts;

  option := 1;
  while option < PIPBOY_REST_DURATION_COUNT_WITHOUT_PARTY + 1 do
  begin
    text := getmsg(@pipboy_message_file, @pipmesg, 302 + option - 1);
    if option = a1 then
      color := colorTable[32747]
    else
      color := colorTable[992];

    pip_print(text, 0, color);

    Inc(cursor_line);
    Inc(option);
  end;

  win_draw_rect(pip_win, @pip_rect);
end;

// ============================================================================
// DrawAlrmHitPnts
// ============================================================================

procedure DrawAlrmHitPnts;
var
  max_hp, cur_hp: Integer;
  text: PAnsiChar;
  msg: array[0..63] of AnsiChar;
  len: Integer;
begin
  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + 66 * PIPBOY_WINDOW_WIDTH + 254,
    350, 10, PIPBOY_WINDOW_WIDTH,
    scrn_buf + 66 * PIPBOY_WINDOW_WIDTH + 254,
    PIPBOY_WINDOW_WIDTH);

  max_hp := stat_level(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS));
  cur_hp := critter_get_hits(obj_dude);
  text := getmsg(@pipboy_message_file, @pipmesg, 301); // Hit Points
  StrLFmt(@msg[0], SizeOf(msg) - 1, '%s %d/%d', [text, cur_hp, max_hp]);
  len := text_width(@msg[0]);
  text_to_buf(scrn_buf + 66 * PIPBOY_WINDOW_WIDTH + 254 + (350 - len) div 2,
    @msg[0], PIPBOY_WINDOW_WIDTH, PIPBOY_WINDOW_WIDTH, colorTable[992]);
end;

// ============================================================================
// NewFuncDsply
// ============================================================================

procedure NewFuncDsply;
begin
  NixHotLines;
  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  if bottom_line >= 0 then
    cursor_line := 0;
end;

// ============================================================================
// AddHotLines
// ============================================================================

procedure AddHotLines(start, count: Integer; add_back_button: Boolean);
var
  height_: Integer;
  y_: Integer;
  eventCode: Integer;
  idx: Integer;
begin
  text_font(101);
  height_ := text_height();

  hot_line_start := start;
  hot_line_count := count;

  if count <> 0 then
  begin
    y_ := start * height_ + PIPBOY_WINDOW_CONTENT_VIEW_Y;
    eventCode := start + 505;
    idx := start;
    while (idx < hot_line_count + hot_line_start) and (idx < 20) do
    begin
      HotLines[idx] := win_register_button(pip_win,
        254, y_, 350, height_,
        -1, -1, -1, eventCode,
        nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
      Inc(y_, height_ * 2);
      Inc(eventCode);
      Inc(idx);
    end;
  end;

  if add_back_button then
  begin
    HotLines[BACK_BUTTON_INDEX] := win_register_button(pip_win,
      254,
      height_ * bottom_line + PIPBOY_WINDOW_CONTENT_VIEW_Y,
      350, height_,
      -1, -1, -1, 528,
      nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
  end;
end;

// ============================================================================
// NixHotLines
// ============================================================================

procedure NixHotLines;
var
  endIdx: Integer;
  idx: Integer;
begin
  if hot_line_count <> 0 then
  begin
    endIdx := hot_line_start + hot_line_count;
    if endIdx > 20 then
      endIdx := 20;

    idx := hot_line_start;
    while idx < endIdx do
    begin
      win_delete_button(HotLines[idx]);
      Inc(idx);
    end;
  end;

  if hot_back_line <> 0 then
    win_delete_button(HotLines[BACK_BUTTON_INDEX]);

  hot_line_count := 0;
  hot_back_line := 0;
end;

// ============================================================================
// TimedRest
// ============================================================================

function TimedRest(hours, minutes, kind: Integer): Boolean;
var
  rc: Boolean;
  hoursInMinutes: Integer;
  v1, v2, v3, v4, v7: Double;
  gameTimeVal: LongWord;
  v5: Integer;
  start: LongWord;
  v6, nextEventTime: LongWord;
  healthToAdd: Integer;
  hour_: Integer;
  currentHp, maxHp, hpToHeal, healingRate, hoursToHeal: Integer;
  nextEventGameTime: LongWord;
begin
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_WATCH);

  rc := False;

  if kind = 0 then
  begin
    hoursInMinutes := hours * 60;
    v1 := Double(hoursInMinutes) + Double(minutes);
    v2 := v1 * (1.0 / 1440.0) * 3.5 + 0.25;
    v3 := Double(minutes) / v1 * v2;

    if minutes <> 0 then
    begin
      gameTimeVal := game_time;

      v4 := v3 * 20.0;
      v5 := 0;
      while v5 < Trunc(v4) do
      begin
        sharedFpsLimiter.Mark;

        if rc then
          Break;

        start := get_time();

        v6 := LongWord(Trunc(Double(v5) / v4 * (Double(minutes) * 600.0) + Double(gameTimeVal)));
        nextEventTime := queue_next_time;
        if v6 >= nextEventTime then
        begin
          set_game_time(nextEventTime + 1);
          if queue_process <> 0 then
          begin
            rc := True;
            debug_printf(PAnsiChar('PIPBOY: Returning from Queue trigger...'#10));
            proc_bail_flag := True;
            Break;
          end;

          if game_user_wants_to_quit <> 0 then
            rc := True;
        end;

        if not rc then
        begin
          set_game_time(v6);
          if (get_input() = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
            rc := True;

          pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
          pip_date;
          pip_note;
          win_draw(pip_win);

          while elapsed_time(start) < 50 do
          begin
            // busy wait
          end;
        end;

        renderPresent;
        sharedFpsLimiter.Throttle;
        Inc(v5);
      end;

      if not rc then
      begin
        set_game_time(gameTimeVal + LongWord(600 * minutes));

        if Check4Health(minutes) then
          AddHealth;
      end;

      pip_note;
      pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
      pip_date;
      DrawAlrmHitPnts;
      win_draw(pip_win);
    end;

    if (hours <> 0) and (not rc) then
    begin
      gameTimeVal := game_time;
      v7 := (v2 - v3) * 20.0;

      hour_ := 0;
      while hour_ < Trunc(v7) do
      begin
        sharedFpsLimiter.Mark;

        if rc then
          Break;

        start := get_time();

        if (get_input() = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
          rc := True;

        v6 := LongWord(Trunc(Double(hour_) / v7 * Double(hours * GAME_TIME_TICKS_PER_HOUR) + Double(gameTimeVal)));
        nextEventTime := queue_next_time;
        if (not rc) and (v6 >= nextEventTime) then
        begin
          set_game_time(nextEventTime + 1);

          if queue_process <> 0 then
          begin
            rc := True;
            debug_printf(PAnsiChar('PIPBOY: Returning from Queue trigger...'#10));
            proc_bail_flag := True;
            Break;
          end;

          if game_user_wants_to_quit <> 0 then
            rc := True;
        end;

        if not rc then
        begin
          set_game_time(v6);

          healthToAdd := Trunc(Double(hoursInMinutes) / v7);
          if Check4Health(healthToAdd) then
            AddHealth;

          pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
          pip_date;
          pip_note;
          DrawAlrmHitPnts;
          win_draw(pip_win);

          while elapsed_time(start) < 50 do
          begin
            // busy wait
          end;
        end;

        renderPresent;
        sharedFpsLimiter.Throttle;
        Inc(hour_);
      end;

      if not rc then
        set_game_time(gameTimeVal + LongWord(GAME_TIME_TICKS_PER_HOUR * hours));

      pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
      pip_date;
      pip_note;
      DrawAlrmHitPnts;
      win_draw(pip_win);
    end;
  end
  else if kind = PIPBOY_REST_DURATION_UNTIL_HEALED then
  begin
    currentHp := critter_get_hits(obj_dude);
    maxHp := stat_level(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS));
    if currentHp <> maxHp then
    begin
      // First pass
      hpToHeal := maxHp - currentHp;
      healingRate := stat_level(obj_dude, Ord(STAT_HEALING_RATE));
      hoursToHeal := Trunc(Double(hpToHeal) / Double(healingRate) * 3.0);
      while (not rc) and (hoursToHeal <> 0) do
      begin
        if hoursToHeal <= 24 then
        begin
          rc := TimedRest(hoursToHeal, 0, 0);
          hoursToHeal := 0;
        end
        else
        begin
          rc := TimedRest(24, 0, 0);
          Dec(hoursToHeal, 24);
        end;
      end;

      // Second pass
      currentHp := critter_get_hits(obj_dude);
      maxHp := stat_level(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS));
      hpToHeal := maxHp - currentHp;

      while (not rc) and (hpToHeal <> 0) do
      begin
        currentHp := critter_get_hits(obj_dude);
        maxHp := stat_level(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS));
        hpToHeal := maxHp - currentHp;

        rc := TimedRest(3, 0, 0);
      end;
    end
    else
    begin
      // No one needs healing.
      gmouse_set_cursor(MOUSE_CURSOR_ARROW);
      Result := rc;
      Exit;
    end;
  end;

  gameTimeVal := game_time;
  nextEventGameTime := queue_next_time;
  if gameTimeVal > nextEventGameTime then
  begin
    if queue_process <> 0 then
    begin
      debug_printf(PAnsiChar('PIPBOY: Returning from Queue trigger...'#10));
      proc_bail_flag := True;
      rc := True;
    end;
  end;

  pip_num(game_time_hour, 4, PIPBOY_WINDOW_TIME_X, PIPBOY_WINDOW_TIME_Y);
  pip_date;
  pip_note;
  win_draw(pip_win);

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  Result := rc;
end;

// ============================================================================
// Check4Health
// ============================================================================

function Check4Health(a1: Integer): Boolean;
begin
  Inc(rest_time, a1);

  if rest_time < 180 then
  begin
    Result := False;
    Exit;
  end;

  debug_printf(PAnsiChar(#10' health added!'#10));
  rest_time := 0;

  Result := True;
end;

// ============================================================================
// AddHealth
// ============================================================================

function AddHealth: Boolean;
var
  currentHp, maxHp: Integer;
begin
  partyMemberRestingHeal(3);

  currentHp := critter_get_hits(obj_dude);
  maxHp := stat_level(obj_dude, Ord(STAT_MAXIMUM_HIT_POINTS));
  Result := currentHp = maxHp;
end;

// ============================================================================
// ClacTime
// ============================================================================

procedure ClacTime(hours, minutes: PInteger; wakeUpHour: Integer);
var
  gameTimeHour: Integer;
begin
  gameTimeHour := game_time_hour;

  hours^ := gameTimeHour div 100;
  minutes^ := gameTimeHour mod 100;

  if (hours^ <> wakeUpHour) or (minutes^ <> 0) then
  begin
    hours^ := wakeUpHour - hours^;
    if hours^ < 0 then
    begin
      hours^ := hours^ + 24;
      if minutes^ <> 0 then
      begin
        Dec(hours^);
        minutes^ := 60 - minutes^;
      end;
    end
    else
    begin
      if minutes^ <> 0 then
      begin
        Dec(hours^);
        minutes^ := 60 - minutes^;
        if hours^ < 0 then
          hours^ := 23;
      end;
    end;
  end
  else
  begin
    hours^ := 24;
  end;
end;

// ============================================================================
// ScreenSaver
// ============================================================================

function ScreenSaver: Integer;
var
  bombs: array[0..PIPBOY_BOMB_COUNT - 1] of TPipboyBomb;
  idx: Integer;
  buf: PByte;
  v31: Integer;
  time_: LongWord;
  random_: Double;
  v27, v5, v6: Integer;
  bomb: ^TPipboyBomb;
  srcWidth, srcHeight, destX, destY, srcY, srcX: Integer;
begin
  mouseGetPositionInWindow(pip_win, @old_mouse_x, @old_mouse_y);

  for idx := 0 to PIPBOY_BOMB_COUNT - 1 do
    bombs[idx].field_10 := 0;

  gmouse_disable(0);

  buf := PByte(mem_malloc(412 * 374));
  if buf = nil then
  begin
    Result := -1;
    Exit;
  end;

  buf_to_buf(scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    buf, PIPBOY_WINDOW_CONTENT_VIEW_WIDTH);

  buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  v31 := 50;
  while True do
  begin
    sharedFpsLimiter.Mark;

    time_ := get_time();

    mouseGetPositionInWindow(pip_win, @mouse_x, @mouse_y);
    if (get_input() <> -1) or (old_mouse_x <> mouse_x) or (old_mouse_y <> mouse_y) then
      Break;

    random_ := Double(roll_random(0, PIPBOY_RAND_MAX));

    if random_ < 3047.3311 then
    begin
      idx := 0;
      while idx < PIPBOY_BOMB_COUNT do
      begin
        if bombs[idx].field_10 = 0 then
          Break;
        Inc(idx);
      end;

      if idx < PIPBOY_BOMB_COUNT then
      begin
        bomb := @bombs[idx];
        v27 := (350 - ginfo[PIPBOY_FRM_BOMB].Width div 4) + (406 - ginfo[PIPBOY_FRM_BOMB].Height div 4);
        v5 := Trunc(Double(roll_random(0, PIPBOY_RAND_MAX)) / Double(PIPBOY_RAND_MAX) * Double(v27));
        v6 := ginfo[PIPBOY_FRM_BOMB].Height div 4;
        if PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT - v6 >= v5 then
        begin
          bomb^.x := 602;
          bomb^.y := v5 + 48;
        end
        else
        begin
          bomb^.x := v5 - (PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT - v6) + PIPBOY_WINDOW_CONTENT_VIEW_X + ginfo[PIPBOY_FRM_BOMB].Width div 4;
          bomb^.y := PIPBOY_WINDOW_CONTENT_VIEW_Y - ginfo[PIPBOY_FRM_BOMB].Height + 2;
        end;

        bomb^.field_10 := 1;
        bomb^.field_8 := Single(Double(roll_random(0, PIPBOY_RAND_MAX)) * (2.75 / PIPBOY_RAND_MAX) + 0.15);
        bomb^.field_C := 0;
      end;
    end;

    if v31 = 0 then
    begin
      buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
        PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_WIDTH,
        scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
        PIPBOY_WINDOW_WIDTH);
    end;

    for idx := 0 to PIPBOY_BOMB_COUNT - 1 do
    begin
      bomb := @bombs[idx];
      if bomb^.field_10 <> 1 then
        Continue;

      srcWidth := ginfo[PIPBOY_FRM_BOMB].Width;
      srcHeight := ginfo[PIPBOY_FRM_BOMB].Height;
      destX := bomb^.x;
      destY := bomb^.y;
      srcY := 0;
      srcX := 0;

      if destX >= PIPBOY_WINDOW_CONTENT_VIEW_X then
      begin
        if destX + ginfo[PIPBOY_FRM_BOMB].Width >= 604 then
        begin
          srcWidth := 604 - destX;
          if srcWidth < 1 then
            bomb^.field_10 := 0;
        end;
      end
      else
      begin
        srcX := PIPBOY_WINDOW_CONTENT_VIEW_X - destX;
        if srcX >= ginfo[PIPBOY_FRM_BOMB].Width then
          bomb^.field_10 := 0;
        destX := PIPBOY_WINDOW_CONTENT_VIEW_X;
        srcWidth := ginfo[PIPBOY_FRM_BOMB].Width - srcX;
      end;

      if destY >= PIPBOY_WINDOW_CONTENT_VIEW_Y then
      begin
        if destY + ginfo[PIPBOY_FRM_BOMB].Height >= 452 then
        begin
          srcHeight := 452 - destY;
          if srcHeight < 1 then
            bomb^.field_10 := 0;
        end;
      end
      else
      begin
        if destY + ginfo[PIPBOY_FRM_BOMB].Height < PIPBOY_WINDOW_CONTENT_VIEW_Y then
          bomb^.field_10 := 0;

        srcY := PIPBOY_WINDOW_CONTENT_VIEW_Y - destY;
        srcHeight := ginfo[PIPBOY_FRM_BOMB].Height - srcY;
        destY := PIPBOY_WINDOW_CONTENT_VIEW_Y;
      end;

      if (bomb^.field_10 = 1) and (v31 = 0) then
      begin
        trans_buf_to_buf(
          pipbmp[PIPBOY_FRM_BOMB] + ginfo[PIPBOY_FRM_BOMB].Width * srcY + srcX,
          srcWidth, srcHeight,
          ginfo[PIPBOY_FRM_BOMB].Width,
          scrn_buf + PIPBOY_WINDOW_WIDTH * destY + destX,
          PIPBOY_WINDOW_WIDTH);
      end;

      bomb^.field_C := bomb^.field_C + bomb^.field_8;
      if bomb^.field_C >= 1.0 then
      begin
        bomb^.x := Trunc(Single(bomb^.x) - bomb^.field_C);
        bomb^.y := Trunc(Single(bomb^.y) + bomb^.field_C);
        bomb^.field_C := 0.0;
      end;
    end;

    if v31 <> 0 then
      Dec(v31)
    else
    begin
      win_draw_rect(pip_win, @pip_rect);
      while elapsed_time(time_) < 50 do
      begin
        // busy wait
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  buf_to_buf(buf,
    PIPBOY_WINDOW_CONTENT_VIEW_WIDTH, PIPBOY_WINDOW_CONTENT_VIEW_HEIGHT, PIPBOY_WINDOW_CONTENT_VIEW_WIDTH,
    scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_CONTENT_VIEW_Y + PIPBOY_WINDOW_CONTENT_VIEW_X,
    PIPBOY_WINDOW_WIDTH);

  mem_free(buf);

  win_draw_rect(pip_win, @pip_rect);
  gmouse_enable;

  Result := 0;
end;

// ============================================================================
// pip_note
// ============================================================================

procedure pip_note;
begin
  if (ggv(Ord(GVAR_FIND_WATER_CHIP)) = 2) or (ggv(Ord(GVAR_VAULT_WATER)) = 0) then
  begin
    buf_to_buf(pipbmp[PIPBOY_FRM_BACKGROUND] + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_NOTE_Y + PIPBOY_WINDOW_NOTE_X,
      ginfo[PIPBOY_FRM_NOTE].Width,
      ginfo[PIPBOY_FRM_NOTE].Height,
      PIPBOY_WINDOW_WIDTH,
      scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_NOTE_Y + PIPBOY_WINDOW_NOTE_X,
      PIPBOY_WINDOW_WIDTH);
  end
  else
  begin
    buf_to_buf(pipbmp[PIPBOY_FRM_NOTE],
      ginfo[PIPBOY_FRM_NOTE].Width,
      ginfo[PIPBOY_FRM_NOTE].Height,
      ginfo[PIPBOY_FRM_NOTE].Width,
      scrn_buf + PIPBOY_WINDOW_WIDTH * PIPBOY_WINDOW_NOTE_Y + PIPBOY_WINDOW_NOTE_X,
      PIPBOY_WINDOW_WIDTH);

    pip_days_left(ggv(Ord(GVAR_VAULT_WATER)));
  end;
end;

// ============================================================================
// Initialization / Finalization
// ============================================================================

initialization
  sharedFpsLimiter := TFpsLimiter.Create(24);

finalization
  sharedFpsLimiter.Free;

end.
