{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/options.h + options.cc
// Options and preferences menu dialogs.
unit u_options;

interface

uses
  u_db;

function do_options: Integer;
function PauseWindow(is_world_map: Boolean): Integer;
function init_options_menu: Integer;
function save_options(stream: PDB_FILE): Integer;
function load_options(stream: PDB_FILE): Integer;
procedure IncGamma;
procedure DecGamma;

implementation

uses
  SysUtils, Math,
  u_cache, u_config, u_gconfig, u_platform_compat,
  u_message, u_rect,
  u_gnw, u_button, u_text, u_input, u_mouse, u_svga, u_grbuf,
  u_color, u_memory, u_art, u_gsound,
  u_game, u_map, u_gmouse, u_cycle, u_tile,
  u_graphlib, u_textobj,
  u_combat, u_combatai, u_scripts, u_loadsave, u_worldmap;

// debug_printf cdecl varargs - incompatible with u_debug's Pascal overloaded version
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';


const
  PREFERENCES_WINDOW_WIDTH  = 640;
  PREFERENCES_WINDOW_HEIGHT = 480;

  OPTIONS_WINDOW_BUTTONS_COUNT = 10;
  PRIMARY_OPTION_VALUE_COUNT   = 4;
  SECONDARY_OPTION_VALUE_COUNT = 2;

  GAMMA_MIN  = 1.0;
  GAMMA_MAX  = 1.17999267578125;
  GAMMA_STEP = 0.01124954223632812;

  // Preference enum
  PREF_GAME_DIFFICULTY      = 0;
  PREF_COMBAT_DIFFICULTY    = 1;
  PREF_VIOLENCE_LEVEL       = 2;
  PREF_TARGET_HIGHLIGHT     = 3;
  PREF_RUNNING_BURNING_GUY  = 4;
  PREF_COMBAT_MESSAGES      = 5;
  PREF_COMBAT_TAUNTS        = 6;
  PREF_LANGUAGE_FILTER      = 7;
  PREF_RUNNING              = 8;
  PREF_SUBTITLES            = 9;
  PREF_ITEM_HIGHLIGHT       = 10;
  PREF_COMBAT_SPEED         = 11;
  PREF_TEXT_BASE_DELAY      = 12;
  PREF_MASTER_VOLUME        = 13;
  PREF_MUSIC_VOLUME         = 14;
  PREF_SFX_VOLUME           = 15;
  PREF_SPEECH_VOLUME        = 16;
  PREF_BRIGHTNESS           = 17;
  PREF_MOUSE_SENSITIVIY     = 18;
  PREF_COUNT                = 19;

  FIRST_PRIMARY_PREF   = PREF_GAME_DIFFICULTY;
  LAST_PRIMARY_PREF    = PREF_RUNNING_BURNING_GUY;
  PRIMARY_PREF_COUNT   = LAST_PRIMARY_PREF - FIRST_PRIMARY_PREF + 1;  // 5
  FIRST_SECONDARY_PREF = PREF_COMBAT_MESSAGES;
  LAST_SECONDARY_PREF  = PREF_ITEM_HIGHLIGHT;
  SECONDARY_PREF_COUNT = LAST_SECONDARY_PREF - FIRST_SECONDARY_PREF + 1;  // 6
  FIRST_RANGE_PREF     = PREF_COMBAT_SPEED;
  LAST_RANGE_PREF      = PREF_MOUSE_SENSITIVIY;
  RANGE_PREF_COUNT     = LAST_RANGE_PREF - FIRST_RANGE_PREF + 1;  // 8

  // PauseWindowFrm
  PAUSE_WINDOW_FRM_BACKGROUND              = 0;
  PAUSE_WINDOW_FRM_DONE_BOX                = 1;
  PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_UP    = 2;
  PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN  = 3;
  PAUSE_WINDOW_FRM_COUNT                   = 4;

  // OptionsWindowFrm
  OPTIONS_WINDOW_FRM_BACKGROUND  = 0;
  OPTIONS_WINDOW_FRM_BUTTON_ON   = 1;
  OPTIONS_WINDOW_FRM_BUTTON_OFF  = 2;
  OPTIONS_WINDOW_FRM_COUNT       = 3;

  // PreferencesWindowFrm
  PREFERENCES_WINDOW_FRM_BACKGROUND              = 0;
  PREFERENCES_WINDOW_FRM_KNOB_OFF                = 1;
  PREFERENCES_WINDOW_FRM_PRIMARY_SWITCH          = 2;
  PREFERENCES_WINDOW_FRM_SECONDARY_SWITCH        = 3;
  PREFERENCES_WINDOW_FRM_CHECKBOX_ON             = 4;
  PREFERENCES_WINDOW_FRM_CHECKBOX_OFF            = 5;
  PREFERENCES_WINDOW_FRM_6                       = 6;
  PREFERENCES_WINDOW_FRM_KNOB_ON                 = 7;
  PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP    = 8;
  PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN  = 9;
  PREFERENCES_WINDOW_FRM_COUNT                   = 10;

  // Key codes used in this module
  KEY_ESCAPE    = $1B;
  KEY_RETURN    = $0D;
  KEY_PLUS      = $2B;
  KEY_EQUAL     = $3D;
  KEY_MINUS     = $2D;
  KEY_UNDERSCORE = $5F;

  KEY_UPPERCASE_D = $44;
  KEY_UPPERCASE_E = $45;
  KEY_UPPERCASE_L = $4C;
  KEY_UPPERCASE_O = $4F;
  KEY_UPPERCASE_P = $50;
  KEY_UPPERCASE_S = $53;

  KEY_LOWERCASE_D = $64;
  KEY_LOWERCASE_E = $65;
  KEY_LOWERCASE_L = $6C;
  KEY_LOWERCASE_O = $6F;
  KEY_LOWERCASE_P = $70;
  KEY_LOWERCASE_S = $73;

  KEY_CTRL_Q = 17;
  KEY_CTRL_X = 24;
  KEY_F10    = 324;
  KEY_F12    = 390;

  // Mouse cursor
  MOUSE_CURSOR_ARROW = 1;

  // Window flags
  WINDOW_MODAL         = $10;
  WINDOW_DONT_MOVE_TOP = $02;

  // Button flags
  BUTTON_FLAG_TRANSPARENT = $20;
  BUTTON_FLAG_0x01        = $01;
  BUTTON_FLAG_0x02        = $02;

  // Object types
  OBJ_TYPE_INTERFACE = 6;

  // Volume
  VOLUME_MAX = $7FFF;

  // GVAR
  GVAR_RUNNING_BURNING_GUY = 603;

  // LoadSaveMode
  LOAD_SAVE_MODE_NORMAL = 0;

type
  PPreferenceDescription = ^TPreferenceDescription;
  TPreferenceDescription = record
    valuesCount: SmallInt;
    direction: SmallInt;
    knobX: SmallInt;
    knobY: SmallInt;
    minX: SmallInt;
    maxX: SmallInt;
    labelIds: array[0..PRIMARY_OPTION_VALUE_COUNT - 1] of SmallInt;
    btn: Integer;
    name: array[0..31] of AnsiChar;
    minValue: Double;
    maxValue: Double;
    valuePtr: PInteger;
  end;

// ---------------------------------------------------------------
// Static tables
// ---------------------------------------------------------------

const
  row1Ytab: array[0..PRIMARY_PREF_COUNT - 1] of SmallInt = (
    48, 125, 203, 286, 363
  );

  row2Ytab: array[0..SECONDARY_PREF_COUNT - 1] of SmallInt = (
    49, 116, 181, 247, 313, 380
  );

  row3Ytab: array[0..RANGE_PREF_COUNT - 1] of SmallInt = (
    19, 94, 165, 216, 268, 319, 369, 420
  );

  bglbx: array[0..PRIMARY_OPTION_VALUE_COUNT - 1] of SmallInt = (
    2, 25, 46, 46
  );

  bglby: array[0..PRIMARY_OPTION_VALUE_COUNT - 1] of SmallInt = (
    10, -4, 10, 31
  );

  smlbx: array[0..SECONDARY_OPTION_VALUE_COUNT - 1] of SmallInt = (
    4, 21
  );

  opgrphs: array[0..OPTIONS_WINDOW_FRM_COUNT - 1] of Integer = (
    220, 222, 221
  );

  prfgrphs: array[0..PREFERENCES_WINDOW_FRM_COUNT - 1] of Integer = (
    240, 241, 242, 243, 244, 245, 246, 247, 8, 9
  );

// ---------------------------------------------------------------
// Static (module-level) variables
// ---------------------------------------------------------------
var
  ginfo: array[0..OPTIONS_WINDOW_FRM_COUNT - 1] of TSize;
  optn_msgfl: TMessageList;
  ginfo2: array[0..PREFERENCES_WINDOW_FRM_COUNT - 1] of TSize;
  prfbmp: array[0..PREFERENCES_WINDOW_FRM_COUNT - 1] of PByte;
  opbtns: array[0..OPTIONS_WINDOW_BUTTONS_COUNT - 1] of PByte;
  grphkey2: array[0..PREFERENCES_WINDOW_FRM_COUNT - 1] of PCacheEntry;

  text_delay_back: Double;
  gamma_value_back: Double;
  mouse_sens_back: Double;
  gamma_value: Double;
  text_delay: Double;
  mouse_sens: Double;

  winbuf: PByte;
  prefbuf: PByte;
  optnmesg: TMessageListItem;
  grphkey: array[0..OPTIONS_WINDOW_FRM_COUNT - 1] of PCacheEntry;
  mouse_3d_was_on: Boolean;
  optnwin: Integer;
  prfwin: Integer;
  opbmp: array[0..OPTIONS_WINDOW_FRM_COUNT - 1] of PByte;
  settings_backup: array[0..PREF_COUNT - 1] of Integer;
  fontsave: Integer;
  plyrspdbid: Integer;
  changed: Boolean;
  sndfx_volume: Integer;
  subtitles: Integer;
  language_filter: Integer;
  speech_volume: Integer;
  master_volume: Integer;
  player_speedup: Integer;
  combat_taunts: Integer;
  combat_messages: Integer;
  target_highlight: Integer;
  music_volume: Integer;
  bk_enable: Boolean;
  prf_running: Integer;
  combat_speed: Integer;
  item_highlight: Integer;
  running_burning_guy: Integer;
  combat_difficulty: Integer;
  violence_level: Integer;
  game_difficulty: Integer;

  // Static local for PauseWindow
  PauseWindow_graphicIds: array[0..PAUSE_WINDOW_FRM_COUNT - 1] of Integer = (
    208, 209, 8, 9
  );

  // Static locals for UpdateThing
  UpdateThing_primaryOffsets: array[0..PRIMARY_PREF_COUNT - 1] of Integer = (
    66, 143, 222, 304, 382
  );
  UpdateThing_secondaryOffsets: array[0..SECONDARY_PREF_COUNT - 1] of Integer = (
    66, 133, 200, 264, 331, 397
  );

  btndat: array[0..PREF_COUNT - 1] of TPreferenceDescription;

// ---------------------------------------------------------------
// Helper: access game_global_vars as array
// ---------------------------------------------------------------
function GetGameGlobalVar(idx: Integer): Integer;
begin
  Result := PInteger(PByte(game_global_vars) + SizeUInt(idx) * SizeOf(Integer))^;
end;

// ---------------------------------------------------------------
// Helper: clamp integer
// ---------------------------------------------------------------
function ClampInt(value, lo, hi: Integer): Integer;
begin
  if value < lo then
    Result := lo
  else if value > hi then
    Result := hi
  else
    Result := value;
end;

// ---------------------------------------------------------------
// Helper: clamp double
// ---------------------------------------------------------------
function ClampDbl(value, lo, hi: Double): Double;
begin
  if value < lo then
    Result := lo
  else if value > hi then
    Result := hi
  else
    Result := value;
end;

// ---------------------------------------------------------------
// Initialize btndat table
// ---------------------------------------------------------------
procedure InitBtnDat;

  procedure SetEntry(idx: Integer; vc, dir, kx, ky, mnx, mxx: SmallInt;
    l0, l1, l2, l3: SmallInt; bt: Integer; const nm: PAnsiChar;
    mnv, mxv: Double; vp: PInteger);
  begin
    btndat[idx].valuesCount := vc;
    btndat[idx].direction := dir;
    btndat[idx].knobX := kx;
    btndat[idx].knobY := ky;
    btndat[idx].minX := mnx;
    btndat[idx].maxX := mxx;
    btndat[idx].labelIds[0] := l0;
    btndat[idx].labelIds[1] := l1;
    btndat[idx].labelIds[2] := l2;
    btndat[idx].labelIds[3] := l3;
    btndat[idx].btn := bt;
    StrLCopy(@btndat[idx].name[0], nm, 31);
    btndat[idx].minValue := mnv;
    btndat[idx].maxValue := mxv;
    btndat[idx].valuePtr := vp;
  end;

begin
  SetEntry(PREF_GAME_DIFFICULTY,     3,0,76, 71,0,0, 203,204,205,0, 0, GAME_CONFIG_GAME_DIFFICULTY_KEY,    0,0, @game_difficulty);
  SetEntry(PREF_COMBAT_DIFFICULTY,   3,0,76,149,0,0, 206,204,208,0, 0, GAME_CONFIG_COMBAT_DIFFICULTY_KEY,  0,0, @combat_difficulty);
  SetEntry(PREF_VIOLENCE_LEVEL,      4,0,76,226,0,0, 214,215,204,216,0, GAME_CONFIG_VIOLENCE_LEVEL_KEY,    0,0, @violence_level);
  SetEntry(PREF_TARGET_HIGHLIGHT,    3,0,76,309,0,0, 202,201,213,0, 0, GAME_CONFIG_TARGET_HIGHLIGHT_KEY,   0,0, @target_highlight);
  SetEntry(PREF_RUNNING_BURNING_GUY, 2,0,76,387,0,0, 202,201,0,0,  0, GAME_CONFIG_RUNNING_BURNING_GUY_KEY,0,0, @running_burning_guy);
  SetEntry(PREF_COMBAT_MESSAGES,     2,0,299, 74,0,0, 211,212,0,0,  0, GAME_CONFIG_COMBAT_MESSAGES_KEY,    0,0, @combat_messages);
  SetEntry(PREF_COMBAT_TAUNTS,       2,0,299,141,0,0, 202,201,0,0,  0, GAME_CONFIG_COMBAT_TAUNTS_KEY,      0,0, @combat_taunts);
  SetEntry(PREF_LANGUAGE_FILTER,     2,0,299,207,0,0, 202,201,0,0,  0, GAME_CONFIG_LANGUAGE_FILTER_KEY,    0,0, @language_filter);
  SetEntry(PREF_RUNNING,             2,0,299,271,0,0, 209,219,0,0,  0, GAME_CONFIG_RUNNING_KEY,            0,0, @prf_running);
  SetEntry(PREF_SUBTITLES,           2,0,299,338,0,0, 202,201,0,0,  0, GAME_CONFIG_SUBTITLES_KEY,          0,0, @subtitles);
  SetEntry(PREF_ITEM_HIGHLIGHT,      2,0,299,404,0,0, 202,201,0,0,  0, GAME_CONFIG_ITEM_HIGHLIGHT_KEY,     0,0, @item_highlight);
  SetEntry(PREF_COMBAT_SPEED,        2,0,374, 50,0,0, 207,210,0,0,  0, GAME_CONFIG_COMBAT_SPEED_KEY,       0.0,50.0, @combat_speed);
  SetEntry(PREF_TEXT_BASE_DELAY,     3,0,374,125,0,0, 217,209,218,0, 0, GAME_CONFIG_TEXT_BASE_DELAY_KEY,    1.0,6.0,  nil);
  SetEntry(PREF_MASTER_VOLUME,       4,0,374,196,0,0, 202,221,209,222, 0, GAME_CONFIG_MASTER_VOLUME_KEY,   0,32767.0, @master_volume);
  SetEntry(PREF_MUSIC_VOLUME,        4,0,374,247,0,0, 202,221,209,222, 0, GAME_CONFIG_MUSIC_VOLUME_KEY,    0,32767.0, @music_volume);
  SetEntry(PREF_SFX_VOLUME,          4,0,374,298,0,0, 202,221,209,222, 0, GAME_CONFIG_SNDFX_VOLUME_KEY,    0,32767.0, @sndfx_volume);
  SetEntry(PREF_SPEECH_VOLUME,       4,0,374,349,0,0, 202,221,209,222, 0, GAME_CONFIG_SPEECH_VOLUME_KEY,   0,32767.0, @speech_volume);
  SetEntry(PREF_BRIGHTNESS,          2,0,374,400,0,0, 207,223,0,0,  0, GAME_CONFIG_BRIGHTNESS_KEY,         1.0,1.17999267578125, nil);
  SetEntry(PREF_MOUSE_SENSITIVIY,    2,0,374,451,0,0, 207,218,0,0,  0, GAME_CONFIG_MOUSE_SENSITIVITY_KEY,  1.0,2.5, nil);
end;

// ---------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------
function OptnStart: Integer; forward;
function OptnEnd: Integer; forward;
procedure ShadeScreen(a1: Boolean); forward;
function do_prefscreen: Integer; forward;
function PrefStart: Integer; forward;
procedure DoThing(eventCode: Integer); forward;
procedure UpdateThing(index: Integer); forward;
function PrefEnd: Integer; forward;
procedure SetSystemPrefs; forward;
function SavePrefs(save: Boolean): Integer; forward;
procedure SetDefaults(a1: Boolean); forward;
procedure SaveSettings; forward;
procedure RestoreSettings; forward;
procedure JustUpdate; forward;

// ---------------------------------------------------------------
// do_options
// ---------------------------------------------------------------
function do_options: Integer;
var
  rc, keyCode: Integer;
  showPreferences: Boolean;
begin
  if OptnStart() = -1 then
  begin
    debug_printf(PAnsiChar(#10'OPTION MENU: Error loading option dialog data!'#10));
    Result := -1;
    Exit;
  end;

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input();
    showPreferences := False;

    if (keyCode = KEY_ESCAPE) or (keyCode = 504) or (game_user_wants_to_quit <> 0) then
    begin
      rc := 0;
    end
    else
    begin
      case keyCode of
        KEY_RETURN, KEY_UPPERCASE_O, KEY_LOWERCASE_O,
        KEY_UPPERCASE_D, KEY_LOWERCASE_D:
        begin
          gsound_play_sfx_file('ib1p1xx1');
          rc := 0;
        end;
        KEY_UPPERCASE_S, KEY_LOWERCASE_S, 500:
        begin
          if SaveGame(LOAD_SAVE_MODE_NORMAL) = 1 then
            rc := 1;
        end;
        KEY_UPPERCASE_L, KEY_LOWERCASE_L, 501:
        begin
          if LoadGame(LOAD_SAVE_MODE_NORMAL) = 1 then
            rc := 1;
        end;
        KEY_UPPERCASE_P, KEY_LOWERCASE_P:
        begin
          gsound_play_sfx_file('ib1p1xx1');
          showPreferences := True;
        end;
        502:
        begin
          showPreferences := True;
        end;
        KEY_PLUS, KEY_EQUAL:
          IncGamma;
        KEY_UNDERSCORE, KEY_MINUS:
          DecGamma;
      end;
    end;

    if showPreferences then
    begin
      do_prefscreen;
    end
    else
    begin
      case keyCode of
        KEY_F12:
          dump_screen;
        KEY_UPPERCASE_E, KEY_LOWERCASE_E, KEY_CTRL_Q, KEY_CTRL_X, KEY_F10, 503:
          game_quit_with_confirm;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  OptnEnd;
  Result := rc;
end;

// ---------------------------------------------------------------
// OptnStart
// ---------------------------------------------------------------
function OptnStart: Integer;
var
  index, cycle_val, fid, textY, buttonY, textX, btn: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  text_buf_arr: array[0..127] of AnsiChar;
  msgStr: PAnsiChar;
  optionsWindowX, optionsWindowY: Integer;
begin
  fontsave := text_curr();

  if not message_init(@optn_msgfl) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('options.msg')]);
  if not message_load(@optn_msgfl, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  index := 0;
  while index < OPTIONS_WINDOW_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, opgrphs[index], 0, 0, 0);
    opbmp[index] := art_lock(fid, @grphkey[index], @ginfo[index].Width, @ginfo[index].Height);

    if opbmp[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        art_ptr_unlock(grphkey[index]);
        Dec(index);
      end;
      message_exit(@optn_msgfl);
      Result := -1;
      Exit;
    end;
    Inc(index);
  end;

  cycle_val := 0;
  index := 0;
  while index < OPTIONS_WINDOW_BUTTONS_COUNT do
  begin
    opbtns[index] := PByte(mem_malloc(ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width * ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Height + 1024));
    if opbtns[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        mem_free(opbtns[index]);
        Dec(index);
      end;

      index := 0;
      while index < OPTIONS_WINDOW_FRM_COUNT do
      begin
        art_ptr_unlock(grphkey[index]);
        Inc(index);
      end;

      message_exit(@optn_msgfl);
      Result := -1;
      Exit;
    end;

    cycle_val := cycle_val xor 1;
    Move(opbmp[cycle_val + 1]^, opbtns[index]^,
         ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width * ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Height);
    Inc(index);
  end;

  optionsWindowX := (screenGetWidth() - ginfo[OPTIONS_WINDOW_FRM_BACKGROUND].Width) div 2;
  optionsWindowY := (screenGetHeight() - ginfo[OPTIONS_WINDOW_FRM_BACKGROUND].Height) div 2 - 60;
  optnwin := win_add(optionsWindowX, optionsWindowY,
    ginfo[0].Width, ginfo[0].Height, 256,
    WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);

  if optnwin = -1 then
  begin
    index := 0;
    while index < OPTIONS_WINDOW_BUTTONS_COUNT do
    begin
      mem_free(opbtns[index]);
      Inc(index);
    end;

    index := 0;
    while index < OPTIONS_WINDOW_FRM_COUNT do
    begin
      art_ptr_unlock(grphkey[index]);
      Inc(index);
    end;

    message_exit(@optn_msgfl);
    Result := -1;
    Exit;
  end;

  bk_enable := map_disable_bk_processes();

  mouse_3d_was_on := gmouse_3d_is_on();
  if mouse_3d_was_on then
    gmouse_3d_off;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  winbuf := win_get_buf(optnwin);
  Move(opbmp[OPTIONS_WINDOW_FRM_BACKGROUND]^, winbuf^,
       ginfo[OPTIONS_WINDOW_FRM_BACKGROUND].Width * ginfo[OPTIONS_WINDOW_FRM_BACKGROUND].Height);

  text_font(103);

  textY := (ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Height - text_height()) div 2 + 1;
  buttonY := 17;

  index := 0;
  while index < OPTIONS_WINDOW_BUTTONS_COUNT do
  begin
    msgStr := getmsg(@optn_msgfl, @optnmesg, index div 2);
    StrCopy(@text_buf_arr[0], msgStr);

    textX := (ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width - text_width(@text_buf_arr[0])) div 2;
    if textX < 0 then
      textX := 0;

    text_to_buf(opbtns[index] + ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width * textY + textX,
      @text_buf_arr[0],
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width,
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width,
      colorTable[18979]);
    text_to_buf(opbtns[index + 1] + ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width * textY + textX,
      @text_buf_arr[0],
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width,
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width,
      colorTable[14723]);

    btn := win_register_button(optnwin, 13, buttonY,
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Width,
      ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Height,
      -1, -1, -1, index div 2 + 500,
      opbtns[index], opbtns[index + 1], nil, 32);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_lrg_butt_press, @gsound_lrg_butt_release);

    buttonY := buttonY + ginfo[OPTIONS_WINDOW_FRM_BUTTON_ON].Height + 3;
    Inc(index, 2);
  end;

  text_font(101);
  win_draw(optnwin);
  Result := 0;
end;

// ---------------------------------------------------------------
// OptnEnd
// ---------------------------------------------------------------
function OptnEnd: Integer;
var
  index: Integer;
begin
  win_delete(optnwin);
  text_font(fontsave);
  message_exit(@optn_msgfl);

  index := 0;
  while index < OPTIONS_WINDOW_BUTTONS_COUNT do
  begin
    mem_free(opbtns[index]);
    Inc(index);
  end;

  index := 0;
  while index < OPTIONS_WINDOW_FRM_COUNT do
  begin
    art_ptr_unlock(grphkey[index]);
    Inc(index);
  end;

  if mouse_3d_was_on then
    gmouse_3d_on;

  if bk_enable then
    map_enable_bk_processes;

  Result := 0;
end;

// ---------------------------------------------------------------
// PauseWindow
// ---------------------------------------------------------------
function PauseWindow(is_world_map: Boolean): Integer;
var
  frmData: array[0..PAUSE_WINDOW_FRM_COUNT - 1] of PByte;
  frmHandles: array[0..PAUSE_WINDOW_FRM_COUNT - 1] of PCacheEntry;
  frmSizes: array[0..PAUSE_WINDOW_FRM_COUNT - 1] of TSize;
  gameMouseWasVisible: Boolean;
  index, fid, pauseWindowX, pauseWindowY, window_: Integer;
  windowBuffer: PByte;
  messageItemText: PAnsiChar;
  length_: Integer;
  doneBtn: Integer;
  done: Boolean;
  keyCode: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  gameMouseWasVisible := False;
  if not is_world_map then
  begin
    bk_enable := map_disable_bk_processes();
    cycle_disable;

    gameMouseWasVisible := gmouse_3d_is_on();
    if gameMouseWasVisible then
      gmouse_3d_off;
  end;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  ShadeScreen(is_world_map);

  index := 0;
  while index < PAUSE_WINDOW_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, PauseWindow_graphicIds[index], 0, 0, 0);
    frmData[index] := art_lock(fid, @frmHandles[index], @frmSizes[index].Width, @frmSizes[index].Height);
    if frmData[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        art_ptr_unlock(frmHandles[index]);
        Dec(index);
      end;
      debug_printf(PAnsiChar(#10'** Error loading pause window graphics! **'#10));
      Result := -1;
      Exit;
    end;
    Inc(index);
  end;

  if not message_init(@optn_msgfl) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('options.msg')]);
  if not message_load(@optn_msgfl, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  pauseWindowX := (screenGetWidth() - frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width) div 2;
  pauseWindowY := (screenGetHeight() - frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Height) div 2;

  if is_world_map then
  begin
    Dec(pauseWindowX, 65);
    Dec(pauseWindowY, 24);
  end
  else
  begin
    Dec(pauseWindowY, 54);
  end;

  window_ := win_add(pauseWindowX, pauseWindowY,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Height,
    256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if window_ = -1 then
  begin
    index := 0;
    while index < PAUSE_WINDOW_FRM_COUNT do
    begin
      art_ptr_unlock(frmHandles[index]);
      Inc(index);
    end;
    message_exit(@optn_msgfl);
    debug_printf(PAnsiChar(#10'** Error opening pause window! **'#10));
    Result := -1;
    Exit;
  end;

  windowBuffer := win_get_buf(window_);
  Move(frmData[PAUSE_WINDOW_FRM_BACKGROUND]^, windowBuffer^,
       frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width * frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Height);

  trans_buf_to_buf(frmData[PAUSE_WINDOW_FRM_DONE_BOX],
    frmSizes[PAUSE_WINDOW_FRM_DONE_BOX].Width,
    frmSizes[PAUSE_WINDOW_FRM_DONE_BOX].Height,
    frmSizes[PAUSE_WINDOW_FRM_DONE_BOX].Width,
    windowBuffer + frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width * 42 + 13,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width);

  fontsave := text_curr();
  text_font(103);

  messageItemText := getmsg(@optn_msgfl, @optnmesg, 300);
  text_to_buf(windowBuffer + frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width * 45 + 52,
    messageItemText,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width,
    colorTable[18979]);

  text_font(104);

  messageItemText := getmsg(@optn_msgfl, @optnmesg, 301);
  StrCopy(@path[0], messageItemText);

  length_ := text_width(@path[0]);
  text_to_buf(windowBuffer + frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width * 10 + 2 +
    (frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width - length_) div 2,
    @path[0],
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width,
    frmSizes[PAUSE_WINDOW_FRM_BACKGROUND].Width,
    colorTable[18979]);

  doneBtn := win_register_button(window_, 26, 46,
    frmSizes[PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_UP].Width,
    frmSizes[PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 504,
    frmData[PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_UP],
    frmData[PAUSE_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_draw(window_);

  done := False;
  while not done do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input();
    case keyCode of
      KEY_PLUS, KEY_EQUAL:
        IncGamma;
      KEY_MINUS, KEY_UNDERSCORE:
        DecGamma;
    else
      begin
        if (keyCode <> -1) and (keyCode <> -2) then
          done := True;
        if game_user_wants_to_quit <> 0 then
          done := True;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if not is_world_map then
    tile_refresh_display;

  win_delete(window_);

  index := 0;
  while index < PAUSE_WINDOW_FRM_COUNT do
  begin
    art_ptr_unlock(frmHandles[index]);
    Inc(index);
  end;

  message_exit(@optn_msgfl);

  if not is_world_map then
  begin
    if gameMouseWasVisible then
      gmouse_3d_on;
    if bk_enable then
      map_enable_bk_processes;
    cycle_enable;
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  end;

  text_font(fontsave);
  Result := 0;
end;

// ---------------------------------------------------------------
// ShadeScreen
// ---------------------------------------------------------------
procedure ShadeScreen(a1: Boolean);
var
  windowWidth, windowHeight: Integer;
  windowBuffer: PByte;
begin
  if a1 then
  begin
    mouse_hide;
    grey_buf(win_get_buf(world_win) + 640 * 21 + 22, 450, 442, 640);
    win_draw(world_win);
  end
  else
  begin
    mouse_hide;
    tile_refresh_display;

    windowWidth := 640;
    windowHeight := win_height(display_win);
    windowBuffer := win_get_buf(display_win);
    grey_buf(windowBuffer, windowWidth, windowHeight, windowWidth);

    win_draw(display_win);
  end;

  mouse_show;
end;

// ---------------------------------------------------------------
// do_prefscreen
// ---------------------------------------------------------------
function do_prefscreen: Integer;
var
  rc, eventCode: Integer;
begin
  if PrefStart() = -1 then
  begin
    debug_printf(PAnsiChar(#10'PREFERENCE MENU: Error loading preference dialog data!'#10));
    Result := -1;
    Exit;
  end;

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    eventCode := get_input();

    case eventCode of
      KEY_RETURN, KEY_UPPERCASE_P, KEY_LOWERCASE_P:
      begin
        gsound_play_sfx_file('ib1p1xx1');
        rc := 1;
      end;
      504:
        rc := 1;
      KEY_CTRL_Q, KEY_CTRL_X, KEY_F10:
        game_quit_with_confirm;
      KEY_EQUAL, KEY_PLUS:
        IncGamma;
      KEY_MINUS, KEY_UNDERSCORE:
        DecGamma;
      KEY_F12:
        dump_screen;
      527:
        SetDefaults(True);
    else
      begin
        if (eventCode = KEY_ESCAPE) or (eventCode = 528) or (game_user_wants_to_quit <> 0) then
        begin
          RestoreSettings;
          rc := 0;
        end
        else if (eventCode >= 505) and (eventCode <= 524) then
          DoThing(eventCode);
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  PrefEnd;
  Result := rc;
end;

// ---------------------------------------------------------------
// PrefStart
// ---------------------------------------------------------------
function PrefStart: Integer;
var
  i, fid, x, y, width, height, messageItemId, btn, button_count: Integer;
  messageItemText: PAnsiChar;
  preferencesWindowX, preferencesWindowY: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
begin
  SaveSettings;

  i := 0;
  while i < PREFERENCES_WINDOW_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, prfgrphs[i], 0, 0, 0);
    prfbmp[i] := art_lock(fid, @grphkey2[i], @ginfo2[i].Width, @ginfo2[i].Height);
    if prfbmp[i] = nil then
    begin
      Dec(i);
      while i >= 0 do
      begin
        art_ptr_unlock(grphkey2[i]);
        Dec(i);
      end;
      Result := -1;
      Exit;
    end;
    Inc(i);
  end;

  changed := False;

  preferencesWindowX := (screenGetWidth() - PREFERENCES_WINDOW_WIDTH) div 2;
  preferencesWindowY := (screenGetHeight() - PREFERENCES_WINDOW_HEIGHT) div 2;
  prfwin := win_add(preferencesWindowX, preferencesWindowY,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_HEIGHT,
    256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if prfwin = -1 then
  begin
    i := 0;
    while i < PREFERENCES_WINDOW_FRM_COUNT do
    begin
      art_ptr_unlock(grphkey2[i]);
      Inc(i);
    end;
    Result := -1;
    Exit;
  end;

  prefbuf := win_get_buf(prfwin);
  Move(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND]^, prefbuf^,
       ginfo2[PREFERENCES_WINDOW_FRM_BACKGROUND].Width * ginfo2[PREFERENCES_WINDOW_FRM_BACKGROUND].Height);

  text_font(104);

  messageItemText := getmsg(@optn_msgfl, @optnmesg, 100);
  text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * 10 + 74, messageItemText,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);

  text_font(103);

  if GetGameGlobalVar(GVAR_RUNNING_BURNING_GUY) <> 0 then
    button_count := 5
  else
  begin
    buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_6],
      ginfo2[PREFERENCES_WINDOW_FRM_6].Width,
      ginfo2[PREFERENCES_WINDOW_FRM_6].Height,
      ginfo2[PREFERENCES_WINDOW_FRM_6].Width,
      prefbuf + PREFERENCES_WINDOW_WIDTH * 356 + 0,
      PREFERENCES_WINDOW_WIDTH);
    button_count := 4;
  end;

  messageItemId := 101;
  i := 0;
  while i < button_count do
  begin
    messageItemText := getmsg(@optn_msgfl, @optnmesg, messageItemId);
    Inc(messageItemId);
    x := 99 - text_width(messageItemText) div 2;
    text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * row1Ytab[i] + x,
      messageItemText, PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH,
      colorTable[18979]);
    Inc(i);
  end;

  if GetGameGlobalVar(GVAR_RUNNING_BURNING_GUY) = 0 then
    Inc(messageItemId);

  i := 0;
  while i < SECONDARY_PREF_COUNT do
  begin
    messageItemText := getmsg(@optn_msgfl, @optnmesg, messageItemId);
    Inc(messageItemId);
    text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * row2Ytab[i] + 206,
      messageItemText, PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH,
      colorTable[18979]);
    Inc(i);
  end;

  i := 0;
  while i < RANGE_PREF_COUNT do
  begin
    messageItemText := getmsg(@optn_msgfl, @optnmesg, messageItemId);
    Inc(messageItemId);
    text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * row3Ytab[i] + 384,
      messageItemText, PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH,
      colorTable[18979]);
    Inc(i);
  end;

  // DEFAULT
  messageItemText := getmsg(@optn_msgfl, @optnmesg, 120);
  text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * 449 + 43, messageItemText,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);

  // DONE
  messageItemText := getmsg(@optn_msgfl, @optnmesg, 4);
  text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * 449 + 169, messageItemText,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);

  // CANCEL
  messageItemText := getmsg(@optn_msgfl, @optnmesg, 121);
  text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * 449 + 283, messageItemText,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);

  // Affect player speed
  text_font(101);
  messageItemText := getmsg(@optn_msgfl, @optnmesg, 122);
  text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * 72 + 405, messageItemText,
    PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);

  i := 0;
  while i < PREF_COUNT do
  begin
    UpdateThing(i);
    Inc(i);
  end;

  i := 0;
  while i < PREF_COUNT do
  begin
    if i >= FIRST_RANGE_PREF then
    begin
      x := 384;
      y := btndat[i].knobY - 12;
      width := 240;
      height := 23;
      mouseEnterEventCode := 526;
      mouseExitEventCode := 526;
      mouseDownEventCode := 505 + i;
      mouseUpEventCode := 526;
    end
    else if i >= FIRST_SECONDARY_PREF then
    begin
      x := btndat[i].minX;
      y := btndat[i].knobY - 5;
      width := btndat[i].maxX - x;
      height := 28;
      mouseEnterEventCode := -1;
      mouseExitEventCode := -1;
      mouseDownEventCode := -1;
      mouseUpEventCode := 505 + i;
    end
    else
    begin
      x := btndat[i].minX;
      y := btndat[i].knobY - 4;
      width := btndat[i].maxX - x;
      height := 48;
      mouseEnterEventCode := -1;
      mouseExitEventCode := -1;
      mouseDownEventCode := -1;
      mouseUpEventCode := 505 + i;
    end;

    btndat[i].btn := win_register_button(prfwin, x, y, width, height,
      mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode,
      nil, nil, nil, 32);
    Inc(i);
  end;

  plyrspdbid := win_register_button(prfwin,
    383, 68,
    ginfo2[PREFERENCES_WINDOW_FRM_CHECKBOX_OFF].Width,
    ginfo2[PREFERENCES_WINDOW_FRM_CHECKBOX_ON].Height,
    -1, -1, 524, 524,
    prfbmp[PREFERENCES_WINDOW_FRM_CHECKBOX_OFF],
    prfbmp[PREFERENCES_WINDOW_FRM_CHECKBOX_ON],
    nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x01 or BUTTON_FLAG_0x02);
  if plyrspdbid <> -1 then
    win_set_button_rest_state(plyrspdbid, player_speedup <> 0, 0);

  win_register_button_sound_func(plyrspdbid, @gsound_med_butt_press, @gsound_med_butt_press);

  // DEFAULT
  btn := win_register_button(prfwin,
    23, 450,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP].Width,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN].Height,
    -1, -1, -1, 527,
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP],
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  // DONE
  btn := win_register_button(prfwin,
    148, 450,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP].Width,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN].Height,
    -1, -1, -1, 504,
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP],
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  // CANCEL
  btn := win_register_button(prfwin,
    263, 450,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP].Width,
    ginfo2[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN].Height,
    -1, -1, -1, 528,
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_UP],
    prfbmp[PREFERENCES_WINDOW_FRM_LITTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  text_font(101);
  win_draw(prfwin);
  Result := 0;
end;

// ---------------------------------------------------------------
// DoThing
// ---------------------------------------------------------------
procedure DoThing(eventCode: Integer);
var
  x, y: Integer;
  preferenceIndex: Integer;
  meta: PPreferenceDescription;
  valuePtr: PInteger;
  value: Integer;
  valueChanged: Boolean;
  v1, v2, v14, v19, v23: Integer;
  dValue, newValue: Double;
  knobX, v31: Integer;
  sfxVolumeExample, speechVolumeExample: Integer;
  v52: Integer;
  off, optionIndex: Integer;
  str: PAnsiChar;
  tick: LongWord;
  lx: Integer;
begin
  mouseGetPositionInWindow(prfwin, @x, @y);

  preferenceIndex := eventCode - 505;

  if (preferenceIndex >= FIRST_PRIMARY_PREF) and (preferenceIndex <= LAST_PRIMARY_PREF) then
  begin
    meta := @btndat[preferenceIndex];
    valuePtr := meta^.valuePtr;
    value := valuePtr^;
    valueChanged := False;

    v1 := meta^.knobX + 23;
    v2 := meta^.knobY + 21;

    if Sqrt(Sqr(Double(x) - Double(v1)) + Sqr(Double(y) - Double(v2))) > 16.0 then
    begin
      if y > meta^.knobY then
      begin
        v14 := meta^.knobY + bglby[0];
        if (y >= v14) and (y <= v14 + text_height()) then
        begin
          if (x >= meta^.minX) and (x <= meta^.knobX) then
          begin
            valuePtr^ := 0;
            meta^.direction := 0;
            valueChanged := True;
          end
          else
          begin
            if (meta^.valuesCount >= 3) and (x >= meta^.knobX + bglbx[2]) and (x <= meta^.maxX) then
            begin
              valuePtr^ := 2;
              meta^.direction := 0;
              valueChanged := True;
            end;
          end;
        end;
      end
      else
      begin
        if (x >= meta^.knobX + 9) and (x <= meta^.knobX + 37) then
        begin
          valuePtr^ := 1;
          if value <> 0 then
            meta^.direction := 1
          else
            meta^.direction := 0;
          valueChanged := True;
        end;
      end;

      if meta^.valuesCount = 4 then
      begin
        v19 := meta^.knobY + bglby[3];
        if (y >= v19) and (y <= v19 + 2 * text_height()) and
           (x >= meta^.knobX + bglbx[3]) and (x <= meta^.maxX) then
        begin
          valuePtr^ := 3;
          meta^.direction := 1;
          valueChanged := True;
        end;
      end;
    end
    else
    begin
      if meta^.direction <> 0 then
      begin
        if value = 0 then
          meta^.direction := 0;
      end
      else
      begin
        if value = meta^.valuesCount - 1 then
          meta^.direction := 1;
      end;

      if meta^.direction <> 0 then
        valuePtr^ := value - 1
      else
        valuePtr^ := value + 1;

      valueChanged := True;
    end;

    if valueChanged then
    begin
      gsound_play_sfx_file('ib3p1xx1');
      block_for_tocks(70);
      gsound_play_sfx_file('ib3lu1x1');
      UpdateThing(preferenceIndex);
      win_draw(prfwin);
      changed := True;
      Exit;
    end;
  end
  else if (preferenceIndex >= FIRST_SECONDARY_PREF) and (preferenceIndex <= LAST_SECONDARY_PREF) then
  begin
    meta := @btndat[preferenceIndex];
    valuePtr := meta^.valuePtr;
    value := valuePtr^;
    valueChanged := False;

    v1 := meta^.knobX + 11;
    v2 := meta^.knobY + 12;

    if Sqrt(Sqr(Double(x) - Double(v1)) + Sqr(Double(y) - Double(v2))) > 10.0 then
    begin
      v23 := meta^.knobY - 5;
      if (y >= v23) and (y <= v23 + text_height() + 2) then
      begin
        if (x >= meta^.minX) and (x <= meta^.knobX) then
        begin
          if preferenceIndex = PREF_COMBAT_MESSAGES then
            valuePtr^ := 1
          else
            valuePtr^ := 0;
          valueChanged := True;
        end
        else if (Double(x) >= meta^.knobX + 22.0) and (x <= meta^.maxX) then
        begin
          if preferenceIndex = PREF_COMBAT_MESSAGES then
            valuePtr^ := 0
          else
            valuePtr^ := 1;
          valueChanged := True;
        end;
      end;
    end
    else
    begin
      valuePtr^ := valuePtr^ xor 1;
      valueChanged := True;
    end;

    if valueChanged then
    begin
      gsound_play_sfx_file('ib2p1xx1');
      block_for_tocks(70);
      gsound_play_sfx_file('ib2lu1x1');
      UpdateThing(preferenceIndex);
      win_draw(prfwin);
      changed := True;
      Exit;
    end;
  end
  else if (preferenceIndex >= FIRST_RANGE_PREF) and (preferenceIndex <= LAST_RANGE_PREF) then
  begin
    meta := @btndat[preferenceIndex];
    valuePtr := meta^.valuePtr;

    gsound_play_sfx_file('ib1p1xx1');

    case preferenceIndex of
      PREF_TEXT_BASE_DELAY:
        dValue := 6.0 - text_delay + 1.0;
      PREF_BRIGHTNESS:
        dValue := gamma_value;
      PREF_MOUSE_SENSITIVIY:
        dValue := mouse_sens;
    else
      dValue := valuePtr^;
    end;

    knobX := Trunc(219.0 / (meta^.maxValue - meta^.minValue));
    v31 := Trunc((dValue - meta^.minValue) * (219.0 / (meta^.maxValue - meta^.minValue)) + 384.0);
    buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + PREFERENCES_WINDOW_WIDTH * meta^.knobY + 384,
      240, 12, PREFERENCES_WINDOW_WIDTH,
      prefbuf + PREFERENCES_WINDOW_WIDTH * meta^.knobY + 384, PREFERENCES_WINDOW_WIDTH);
    trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_ON], 21, 12, 21,
      prefbuf + PREFERENCES_WINDOW_WIDTH * meta^.knobY + v31, PREFERENCES_WINDOW_WIDTH);

    win_draw(prfwin);

    sfxVolumeExample := 0;
    speechVolumeExample := 0;
    while True do
    begin
      sharedFpsLimiter.Mark;

      get_input();

      tick := get_time();

      mouseGetPositionInWindow(prfwin, @x, @y);

      if (mouse_get_buttons() and $10) <> 0 then
      begin
        gsound_play_sfx_file('ib1lu1x1');
        UpdateThing(preferenceIndex);
        win_draw(prfwin);
        renderPresent;
        changed := True;
        Exit;
      end;

      if v31 + 14 > x then
      begin
        if v31 + 6 > x then
        begin
          v31 := x - 6;
          if v31 < 384 then
            v31 := 384;
        end;
      end
      else
      begin
        v31 := x - 6;
        if v31 > 603 then
          v31 := 603;
      end;

      newValue := (Double(v31) - 384.0) / (219.0 / (meta^.maxValue - meta^.minValue)) + meta^.minValue;

      v52 := 0;

      case preferenceIndex of
        PREF_COMBAT_SPEED:
          meta^.valuePtr^ := Trunc(newValue);
        PREF_TEXT_BASE_DELAY:
          text_delay := 6.0 - newValue + 1.0;
        PREF_MASTER_VOLUME:
        begin
          meta^.valuePtr^ := Trunc(newValue);
          gsound_set_master_volume(master_volume);
          v52 := 1;
        end;
        PREF_MUSIC_VOLUME:
        begin
          meta^.valuePtr^ := Trunc(newValue);
          gsound_background_volume_set(music_volume);
          v52 := 1;
        end;
        PREF_SFX_VOLUME:
        begin
          meta^.valuePtr^ := Trunc(newValue);
          gsound_set_sfx_volume(sndfx_volume);
          v52 := 1;
          if sfxVolumeExample = 0 then
          begin
            gsound_play_sfx_file('butin1');
            sfxVolumeExample := 7;
          end
          else
            Dec(sfxVolumeExample);
        end;
        PREF_SPEECH_VOLUME:
        begin
          meta^.valuePtr^ := Trunc(newValue);
          gsound_speech_volume_set(speech_volume);
          v52 := 1;
          if speechVolumeExample = 0 then
          begin
            gsound_speech_play('narrator\options', 12, 13, 15);
            speechVolumeExample := 40;
          end
          else
            Dec(speechVolumeExample);
        end;
        PREF_BRIGHTNESS:
        begin
          gamma_value := newValue;
          colorGamma(newValue);
        end;
        PREF_MOUSE_SENSITIVIY:
          mouse_sens := newValue;
      end;

      if v52 <> 0 then
      begin
        off := PREFERENCES_WINDOW_WIDTH * (meta^.knobY - 12) + 384;
        buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + off, 240, 24, PREFERENCES_WINDOW_WIDTH,
          prefbuf + off, PREFERENCES_WINDOW_WIDTH);

        optionIndex := 0;
        while optionIndex < meta^.valuesCount do
        begin
          str := getmsg(@optn_msgfl, @optnmesg, meta^.labelIds[optionIndex]);

          lx := 0;
          case optionIndex of
            0:
              lx := 384;
            1:
              case meta^.valuesCount of
                2: lx := 624 - text_width(str);
                3: lx := 504 - text_width(str) div 2 - 2;
                4: lx := 444 + text_width(str) div 2 - 8;
              end;
            2:
              case meta^.valuesCount of
                3: lx := 624 - text_width(str);
                4: lx := 564 - text_width(str) - 4;
              end;
            3:
              lx := 624 - text_width(str);
          end;
          text_to_buf(prefbuf + PREFERENCES_WINDOW_WIDTH * (meta^.knobY - 12) + lx,
            str, PREFERENCES_WINDOW_WIDTH, PREFERENCES_WINDOW_WIDTH, colorTable[18979]);
          Inc(optionIndex);
        end;
      end
      else
      begin
        off := PREFERENCES_WINDOW_WIDTH * meta^.knobY + 384;
        buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + off, 240, 12, PREFERENCES_WINDOW_WIDTH,
          prefbuf + off, PREFERENCES_WINDOW_WIDTH);
      end;

      trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_ON], 21, 12, 21,
        prefbuf + PREFERENCES_WINDOW_WIDTH * meta^.knobY + v31, PREFERENCES_WINDOW_WIDTH);
      win_draw(prfwin);

      while elapsed_time(tick) < 35 do
        { spin }
        ;

      renderPresent;
      sharedFpsLimiter.Throttle;
    end;
  end
  else if preferenceIndex = 19 then
  begin
    player_speedup := player_speedup xor 1;
  end;

  changed := True;
end;

// ---------------------------------------------------------------
// UpdateThing
// ---------------------------------------------------------------
procedure UpdateThing(index: Integer);
var
  meta: PPreferenceDescription;
  primaryOptionIndex, secondaryOptionIndex: Integer;
  valueIndex: Integer;
  txt: PAnsiChar;
  copyBuf: array[0..99] of AnsiChar;
  x, y, len, value: Integer;
  p: PAnsiChar;
  s: PAnsiChar;
  dv: Double;
  optionIndex: Integer;
  str: PAnsiChar;
  lx: Integer;
begin
  text_font(101);

  meta := @btndat[index];

  if (index >= FIRST_PRIMARY_PREF) and (index <= LAST_PRIMARY_PREF) then
  begin
    primaryOptionIndex := index - FIRST_PRIMARY_PREF;

    if (primaryOptionIndex = PREF_RUNNING_BURNING_GUY) and (GetGameGlobalVar(GVAR_RUNNING_BURNING_GUY) = 0) then
      Exit;

    buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + 640 * UpdateThing_primaryOffsets[primaryOptionIndex] + 23,
      160, 54, 640,
      prefbuf + 640 * UpdateThing_primaryOffsets[primaryOptionIndex] + 23, 640);

    valueIndex := 0;
    while valueIndex < meta^.valuesCount do
    begin
      txt := getmsg(@optn_msgfl, @optnmesg, meta^.labelIds[valueIndex]);
      StrCopy(@copyBuf[0], txt);

      x := meta^.knobX + bglbx[valueIndex];
      len := text_width(@copyBuf[0]);
      case valueIndex of
        0:
        begin
          x := x - text_width(@copyBuf[0]);
          meta^.minX := x;
        end;
        1:
        begin
          x := x - len div 2;
          meta^.maxX := x + len;
        end;
        2, 3:
          meta^.maxX := x + len;
      end;

      p := @copyBuf[0];
      while (p^ <> #0) and (p^ <> ' ') do
        Inc(p);

      y := meta^.knobY + bglby[valueIndex];
      if p^ <> #0 then
      begin
        p^ := #0;
        text_to_buf(prefbuf + 640 * y + x, @copyBuf[0], 640, 640, colorTable[18979]);
        s := p + 1;
        y := y + text_height();
      end
      else
        s := @copyBuf[0];

      text_to_buf(prefbuf + 640 * y + x, s, 640, 640, colorTable[18979]);
      Inc(valueIndex);
    end;

    value := meta^.valuePtr^;
    trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_PRIMARY_SWITCH] + (46 * 47) * value,
      46, 47, 46,
      prefbuf + 640 * meta^.knobY + meta^.knobX, 640);
  end
  else if (index >= FIRST_SECONDARY_PREF) and (index <= LAST_SECONDARY_PREF) then
  begin
    secondaryOptionIndex := index - FIRST_SECONDARY_PREF;

    buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + 640 * UpdateThing_secondaryOffsets[secondaryOptionIndex] + 251,
      113, 34, 640,
      prefbuf + 640 * UpdateThing_secondaryOffsets[secondaryOptionIndex] + 251, 640);

    value := 0;
    while value < 2 do
    begin
      txt := getmsg(@optn_msgfl, @optnmesg, meta^.labelIds[value]);

      if value <> 0 then
      begin
        x := meta^.knobX + smlbx[value];
        meta^.maxX := x + text_width(txt);
      end
      else
      begin
        x := meta^.knobX + smlbx[value] - text_width(txt);
        meta^.minX := x;
      end;
      text_to_buf(prefbuf + 640 * (meta^.knobY - 5) + x, txt, 640, 640, colorTable[18979]);
      Inc(value);
    end;

    value := meta^.valuePtr^;
    if index = PREF_COMBAT_MESSAGES then
      value := value xor 1;
    trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_SECONDARY_SWITCH] + (22 * 25) * value,
      22, 25, 22,
      prefbuf + 640 * meta^.knobY + meta^.knobX, 640);
  end
  else if (index >= FIRST_RANGE_PREF) and (index <= LAST_RANGE_PREF) then
  begin
    buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_BACKGROUND] + 640 * (meta^.knobY - 12) + 384,
      240, 24, 640,
      prefbuf + 640 * (meta^.knobY - 12) + 384, 640);

    case index of
      PREF_COMBAT_SPEED:
      begin
        dv := meta^.valuePtr^;
        if dv < 0.0 then dv := 0.0
        else if dv > 50.0 then dv := 50.0;
        x := Trunc((dv - meta^.minValue) * 219.0 / (meta^.maxValue - meta^.minValue) + 384.0);
        trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_OFF], 21, 12, 21,
          prefbuf + 640 * meta^.knobY + x, 640);
      end;
      PREF_TEXT_BASE_DELAY:
      begin
        if text_delay < 1.0 then text_delay := 1.0
        else if text_delay > 6.0 then text_delay := 6.0;
        x := Trunc((6.0 - text_delay) * 43.8 + 384.0);
        trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_OFF], 21, 12, 21,
          prefbuf + 640 * meta^.knobY + x, 640);

        dv := (text_delay - 1.0) * 0.2 * 2.0;
        if dv < 0.0 then dv := 0.0
        else if dv > 2.0 then dv := 2.0;

        text_object_set_base_delay(text_delay);
        text_object_set_line_delay(dv);
      end;
      PREF_MASTER_VOLUME, PREF_MUSIC_VOLUME, PREF_SFX_VOLUME, PREF_SPEECH_VOLUME:
      begin
        dv := meta^.valuePtr^;
        if dv < meta^.minValue then dv := meta^.minValue
        else if dv > meta^.maxValue then dv := meta^.maxValue;

        x := Trunc((dv - meta^.minValue) * 219.0 / (meta^.maxValue - meta^.minValue) + 384.0);
        trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_OFF], 21, 12, 21,
          prefbuf + 640 * meta^.knobY + x, 640);

        case index of
          PREF_MASTER_VOLUME: gsound_set_master_volume(master_volume);
          PREF_MUSIC_VOLUME: gsound_background_volume_set(music_volume);
          PREF_SFX_VOLUME: gsound_set_sfx_volume(sndfx_volume);
          PREF_SPEECH_VOLUME: gsound_speech_volume_set(speech_volume);
        end;
      end;
      PREF_BRIGHTNESS:
      begin
        if gamma_value < 1.0 then gamma_value := 1.0
        else if gamma_value > 1.17999267578125 then gamma_value := 1.17999267578125;
        x := Trunc((gamma_value - meta^.minValue) * (219.0 / (meta^.maxValue - meta^.minValue)) + 384.0);
        trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_OFF], 21, 12, 21,
          prefbuf + 640 * meta^.knobY + x, 640);
        colorGamma(gamma_value);
      end;
      PREF_MOUSE_SENSITIVIY:
      begin
        if mouse_sens < 1.0 then mouse_sens := 1.0
        else if mouse_sens > 2.5 then mouse_sens := 2.5;
        x := Trunc((mouse_sens - meta^.minValue) * (219.0 / (meta^.maxValue - meta^.minValue)) + 384.0);
        trans_buf_to_buf(prfbmp[PREFERENCES_WINDOW_FRM_KNOB_OFF], 21, 12, 21,
          prefbuf + 640 * meta^.knobY + x, 640);
        mouse_set_sensitivity(mouse_sens);
      end;
    end;

    optionIndex := 0;
    while optionIndex < meta^.valuesCount do
    begin
      str := getmsg(@optn_msgfl, @optnmesg, meta^.labelIds[optionIndex]);

      lx := 0;
      case optionIndex of
        0:
          lx := 384;
        1:
          case meta^.valuesCount of
            2: lx := 624 - text_width(str);
            3: lx := 504 - text_width(str) div 2 - 2;
            4: lx := 444 + text_width(str) div 2 - 8;
          end;
        2:
          case meta^.valuesCount of
            3: lx := 624 - text_width(str);
            4: lx := 564 - text_width(str) - 4;
          end;
        3:
          lx := 624 - text_width(str);
      end;
      text_to_buf(prefbuf + 640 * (meta^.knobY - 12) + lx,
        str, 640, 640, colorTable[18979]);
      Inc(optionIndex);
    end;
  end;
end;

// ---------------------------------------------------------------
// PrefEnd
// ---------------------------------------------------------------
function PrefEnd: Integer;
var
  index: Integer;
begin
  if changed then
  begin
    SavePrefs(True);
    JustUpdate;
    combat_highlight_change;
  end;

  win_delete(prfwin);

  index := 0;
  while index < PREFERENCES_WINDOW_FRM_COUNT do
  begin
    art_ptr_unlock(grphkey2[index]);
    Inc(index);
  end;

  Result := 0;
end;

// ---------------------------------------------------------------
// init_options_menu
// ---------------------------------------------------------------
function init_options_menu: Integer;
var
  index: Integer;
begin
  InitBtnDat;

  index := 0;
  while index < 11 do
  begin
    btndat[index].direction := 0;
    Inc(index);
  end;

  SetSystemPrefs;
  InitGreyTable(0, 255);
  Result := 0;
end;

// ---------------------------------------------------------------
// IncGamma
// ---------------------------------------------------------------
procedure IncGamma;
begin
  gamma_value := GAMMA_MIN;
  config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, @gamma_value);

  if gamma_value < GAMMA_MAX then
  begin
    gamma_value := gamma_value + GAMMA_STEP;

    if gamma_value >= GAMMA_MIN then
    begin
      if gamma_value > GAMMA_MAX then
        gamma_value := GAMMA_MAX;
    end
    else
      gamma_value := GAMMA_MIN;

    colorGamma(gamma_value);

    config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, gamma_value);
    gconfig_save;
  end;
end;

// ---------------------------------------------------------------
// DecGamma
// ---------------------------------------------------------------
procedure DecGamma;
begin
  gamma_value := GAMMA_MIN;
  config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, @gamma_value);

  if gamma_value > GAMMA_MIN then
  begin
    gamma_value := gamma_value - GAMMA_STEP;

    if gamma_value >= GAMMA_MIN then
    begin
      if gamma_value > GAMMA_MAX then
        gamma_value := GAMMA_MAX;
    end
    else
      gamma_value := GAMMA_MIN;

    colorGamma(gamma_value);

    config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, gamma_value);
    gconfig_save;
  end;
end;

// ---------------------------------------------------------------
// SetSystemPrefs
// ---------------------------------------------------------------
procedure SetSystemPrefs;
begin
  SetDefaults(False);

  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_GAME_DIFFICULTY_KEY, @game_difficulty);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, @combat_difficulty);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violence_level);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, @target_highlight);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_MESSAGES_KEY, @combat_messages);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_BURNING_GUY_KEY, @running_burning_guy);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_TAUNTS_KEY, @combat_taunts);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, @language_filter);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_KEY, @prf_running);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_SUBTITLES_KEY, @subtitles);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_ITEM_HIGHLIGHT_KEY, @item_highlight);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_SPEED_KEY, @combat_speed);
  config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_BASE_DELAY_KEY, @text_delay);
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_PLAYER_SPEEDUP_KEY, @player_speedup);
  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MASTER_VOLUME_KEY, @master_volume);
  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_VOLUME_KEY, @music_volume);
  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SNDFX_VOLUME_KEY, @sndfx_volume);
  config_get_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_VOLUME_KEY, @speech_volume);
  config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, @gamma_value);
  config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_MOUSE_SENSITIVITY_KEY, @mouse_sens);

  JustUpdate;
end;

// ---------------------------------------------------------------
// SavePrefs
// ---------------------------------------------------------------
function SavePrefs(save: Boolean): Integer;
var
  textLineDelay: Double;
begin
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_GAME_DIFFICULTY_KEY, game_difficulty);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_DIFFICULTY_KEY, combat_difficulty);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, violence_level);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TARGET_HIGHLIGHT_KEY, target_highlight);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_MESSAGES_KEY, combat_messages);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_LOOKS_KEY, running_burning_guy);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_TAUNTS_KEY, combat_taunts);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, language_filter);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_KEY, prf_running);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_SUBTITLES_KEY, subtitles);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_ITEM_HIGHLIGHT_KEY, item_highlight);
  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_COMBAT_SPEED_KEY, combat_speed);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_BASE_DELAY_KEY, text_delay);

  textLineDelay := (text_delay - 1.0) / 5.0 * 2.0;
  if textLineDelay >= 0.0 then
  begin
    if textLineDelay > 2.0 then
      textLineDelay := 2.0;
    config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_LINE_DELAY_KEY, textLineDelay);
  end
  else
    config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_LINE_DELAY_KEY, 0.0);

  config_set_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_PLAYER_SPEEDUP_KEY, player_speedup);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MASTER_VOLUME_KEY, master_volume);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_MUSIC_VOLUME_KEY, music_volume);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SNDFX_VOLUME_KEY, sndfx_volume);
  config_set_value(@game_config, GAME_CONFIG_SOUND_KEY, GAME_CONFIG_SPEECH_VOLUME_KEY, speech_volume);

  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_BRIGHTNESS_KEY, gamma_value);
  config_set_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_MOUSE_SENSITIVITY_KEY, mouse_sens);

  if save then
    gconfig_save;

  Result := 0;
end;

// ---------------------------------------------------------------
// SetDefaults
// ---------------------------------------------------------------
procedure SetDefaults(a1: Boolean);
var
  index: Integer;
begin
  combat_difficulty := COMBAT_DIFFICULTY_NORMAL;
  violence_level := VIOLENCE_LEVEL_MAXIMUM_BLOOD;
  target_highlight := TARGET_HIGHLIGHT_TARGETING_ONLY;
  combat_messages := 1;
  running_burning_guy := 1;
  combat_taunts := 1;
  prf_running := 0;
  subtitles := 0;
  item_highlight := 1;
  combat_speed := 0;
  player_speedup := 0;
  text_delay := 3.5;
  gamma_value := 1.0;
  mouse_sens := 1.0;
  game_difficulty := 1;
  language_filter := 0;
  master_volume := 22281;
  music_volume := 22281;
  sndfx_volume := 22281;
  speech_volume := 22281;

  if a1 then
  begin
    index := 0;
    while index < PREF_COUNT do
    begin
      UpdateThing(index);
      Inc(index);
    end;
    win_set_button_rest_state(plyrspdbid, player_speedup <> 0, 0);
    win_draw(prfwin);
    changed := True;
  end;
end;

// ---------------------------------------------------------------
// SaveSettings
// ---------------------------------------------------------------
procedure SaveSettings;
begin
  settings_backup[PREF_GAME_DIFFICULTY] := game_difficulty;
  settings_backup[PREF_COMBAT_DIFFICULTY] := combat_difficulty;
  settings_backup[PREF_VIOLENCE_LEVEL] := violence_level;
  settings_backup[PREF_TARGET_HIGHLIGHT] := target_highlight;
  settings_backup[PREF_RUNNING_BURNING_GUY] := running_burning_guy;
  settings_backup[PREF_COMBAT_MESSAGES] := combat_messages;
  settings_backup[PREF_COMBAT_TAUNTS] := combat_taunts;
  settings_backup[PREF_LANGUAGE_FILTER] := language_filter;
  settings_backup[PREF_RUNNING] := prf_running;
  settings_backup[PREF_SUBTITLES] := subtitles;
  settings_backup[PREF_ITEM_HIGHLIGHT] := item_highlight;
  settings_backup[PREF_COMBAT_SPEED] := combat_speed;
  settings_backup[PREF_TEXT_BASE_DELAY] := player_speedup;
  settings_backup[PREF_MASTER_VOLUME] := master_volume;
  text_delay_back := text_delay;
  settings_backup[PREF_MUSIC_VOLUME] := music_volume;
  gamma_value_back := gamma_value;
  settings_backup[PREF_SFX_VOLUME] := sndfx_volume;
  mouse_sens_back := mouse_sens;
  settings_backup[PREF_SPEECH_VOLUME] := speech_volume;
end;

// ---------------------------------------------------------------
// RestoreSettings
// ---------------------------------------------------------------
procedure RestoreSettings;
begin
  game_difficulty := settings_backup[PREF_GAME_DIFFICULTY];
  combat_difficulty := settings_backup[PREF_COMBAT_DIFFICULTY];
  violence_level := settings_backup[PREF_VIOLENCE_LEVEL];
  target_highlight := settings_backup[PREF_TARGET_HIGHLIGHT];
  running_burning_guy := settings_backup[PREF_RUNNING_BURNING_GUY];
  combat_messages := settings_backup[PREF_COMBAT_MESSAGES];
  combat_taunts := settings_backup[PREF_COMBAT_TAUNTS];
  language_filter := settings_backup[PREF_LANGUAGE_FILTER];
  prf_running := settings_backup[PREF_RUNNING];
  subtitles := settings_backup[PREF_SUBTITLES];
  item_highlight := settings_backup[PREF_ITEM_HIGHLIGHT];
  combat_speed := settings_backup[PREF_COMBAT_SPEED];
  player_speedup := settings_backup[PREF_TEXT_BASE_DELAY];
  master_volume := settings_backup[PREF_MASTER_VOLUME];
  text_delay := text_delay_back;
  music_volume := settings_backup[PREF_MUSIC_VOLUME];
  gamma_value := gamma_value_back;
  sndfx_volume := settings_backup[PREF_SFX_VOLUME];
  mouse_sens := mouse_sens_back;
  speech_volume := settings_backup[PREF_SPEECH_VOLUME];

  JustUpdate;
end;

// ---------------------------------------------------------------
// JustUpdate
// ---------------------------------------------------------------
procedure JustUpdate;
var
  textLineDelay: Double;
begin
  game_difficulty := ClampInt(game_difficulty, 0, 2);
  combat_difficulty := ClampInt(combat_difficulty, 0, 2);
  violence_level := ClampInt(violence_level, 0, 3);
  target_highlight := ClampInt(target_highlight, 0, 2);
  combat_messages := ClampInt(combat_messages, 0, 1);
  running_burning_guy := ClampInt(running_burning_guy, 0, 1);
  combat_taunts := ClampInt(combat_taunts, 0, 1);
  language_filter := ClampInt(language_filter, 0, 1);
  prf_running := ClampInt(prf_running, 0, 1);
  subtitles := ClampInt(subtitles, 0, 1);
  item_highlight := ClampInt(item_highlight, 0, 1);
  combat_speed := ClampInt(combat_speed, 0, 50);
  player_speedup := ClampInt(player_speedup, 0, 1);
  text_delay := ClampDbl(text_delay, 1.0, 6.0);
  master_volume := ClampInt(master_volume, 0, VOLUME_MAX);
  music_volume := ClampInt(music_volume, 0, VOLUME_MAX);
  sndfx_volume := ClampInt(sndfx_volume, 0, VOLUME_MAX);
  speech_volume := ClampInt(speech_volume, 0, VOLUME_MAX);
  gamma_value := ClampDbl(gamma_value, 1.0, 1.17999267578125);
  mouse_sens := ClampDbl(mouse_sens, 1.0, 2.5);

  text_object_set_base_delay(text_delay);
  gmouse_3d_synch_item_highlight;

  textLineDelay := (text_delay + (-1.0)) * 0.2 * 2.0;
  if textLineDelay < 0.0 then textLineDelay := 0.0
  else if textLineDelay > 2.0 then textLineDelay := 2.0;

  text_object_set_line_delay(textLineDelay);
  combatai_refresh_messages;
  scr_message_free;
  gsound_set_master_volume(master_volume);
  gsound_background_volume_set(music_volume);
  gsound_set_sfx_volume(sndfx_volume);
  gsound_speech_volume_set(speech_volume);
  mouse_set_sensitivity(mouse_sens);
  colorGamma(gamma_value);
end;

// ---------------------------------------------------------------
// save_options
// ---------------------------------------------------------------
function save_options(stream: PDB_FILE): Integer;
var
  textBaseDelay, brightness, mouseSensitivity: Single;
begin
  textBaseDelay := Single(text_delay);
  brightness := Single(gamma_value);
  mouseSensitivity := Single(mouse_sens);

  if db_fwriteInt(stream, game_difficulty) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, combat_difficulty) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, violence_level) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, target_highlight) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, running_burning_guy) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, combat_messages) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, combat_taunts) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, language_filter) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, prf_running) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, subtitles) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, item_highlight) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, combat_speed) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, player_speedup) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteFloat(stream, textBaseDelay) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, master_volume) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, music_volume) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, sndfx_volume) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteInt(stream, speech_volume) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteFloat(stream, brightness) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;
  if db_fwriteFloat(stream, mouseSensitivity) = -1 then begin debug_printf(PAnsiChar(#10'OPTION MENU: Error save option data!'#10)); Result := -1; Exit; end;

  Result := 0;
end;

// ---------------------------------------------------------------
// load_options
// ---------------------------------------------------------------
function load_options(stream: PDB_FILE): Integer;
label
  err;
var
  textBaseDelay, brightness, mouseSensitivity: Single;
begin
  SetDefaults(False);

  if db_freadInt(stream, @game_difficulty) = -1 then goto err;
  if db_freadInt(stream, @combat_difficulty) = -1 then goto err;
  if db_freadInt(stream, @violence_level) = -1 then goto err;
  if db_freadInt(stream, @target_highlight) = -1 then goto err;
  if db_freadInt(stream, @running_burning_guy) = -1 then goto err;
  if db_freadInt(stream, @combat_messages) = -1 then goto err;
  if db_freadInt(stream, @combat_taunts) = -1 then goto err;
  if db_freadInt(stream, @language_filter) = -1 then goto err;
  if db_freadInt(stream, @prf_running) = -1 then goto err;
  if db_freadInt(stream, @subtitles) = -1 then goto err;
  if db_freadInt(stream, @item_highlight) = -1 then goto err;
  if db_freadInt(stream, @combat_speed) = -1 then goto err;
  if db_freadInt(stream, @player_speedup) = -1 then goto err;
  if db_freadFloat(stream, @textBaseDelay) = -1 then goto err;
  if db_freadInt(stream, @master_volume) = -1 then goto err;
  if db_freadInt(stream, @music_volume) = -1 then goto err;
  if db_freadInt(stream, @sndfx_volume) = -1 then goto err;
  if db_freadInt(stream, @speech_volume) = -1 then goto err;
  if db_freadFloat(stream, @brightness) = -1 then goto err;
  if db_freadFloat(stream, @mouseSensitivity) = -1 then goto err;

  gamma_value := brightness;
  mouse_sens := mouseSensitivity;
  text_delay := textBaseDelay;

  JustUpdate;
  SavePrefs(False);

  Result := 0;
  Exit;

err:
  debug_printf(PAnsiChar(#10'OPTION MENU: Error loading option data!, using defaults.'#10));

  SetDefaults(False);
  JustUpdate;
  SavePrefs(False);

  Result := -1;
end;


end.
