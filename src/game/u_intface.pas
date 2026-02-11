{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/intface.h + intface.cc
// Interface bar: main HUD with hit points, armor class, action points,
// inventory/options/skilldex/automap/pipboy/character buttons, item slot,
// end-turn/end-combat curtains, and indicator boxes (sneak, level, addict).
unit u_intface;

interface

uses
  u_db, u_object_types, u_cache;

const
  INTERFACE_BAR_WIDTH  = 640;
  INTERFACE_BAR_HEIGHT = 100;

  // Hand
  HAND_LEFT  = 0;
  HAND_RIGHT = 1;
  HAND_COUNT = 2;

  // InterfaceItemAction
  INTERFACE_ITEM_ACTION_DEFAULT          = -1;
  INTERFACE_ITEM_ACTION_USE              = 0;
  INTERFACE_ITEM_ACTION_PRIMARY          = 1;
  INTERFACE_ITEM_ACTION_PRIMARY_AIMING   = 2;
  INTERFACE_ITEM_ACTION_SECONDARY        = 3;
  INTERFACE_ITEM_ACTION_SECONDARY_AIMING = 4;
  INTERFACE_ITEM_ACTION_RELOAD           = 5;
  INTERFACE_ITEM_ACTION_COUNT            = 6;

var
  interfaceWindow: Integer;
  bar_window: Integer;

function intface_init: Integer;
procedure intface_reset;
procedure intface_exit;
function intface_load(stream: PDB_FILE): Integer;
function intface_save(stream: PDB_FILE): Integer;
procedure intface_hide;
procedure intface_show;
function intface_is_hidden: Integer;
procedure intface_enable;
procedure intface_disable;
function intface_is_enabled: Boolean;
procedure intface_redraw;
procedure intface_update_hit_points(animate: Boolean);
procedure intface_update_ac(animate: Boolean);
procedure intface_update_move_points(actionPointsArg: Integer; bonusMoveArg: Integer);
function intface_get_attack(hitMode: PInteger; aiming: PBoolean): Integer;
function intface_update_items(animated: Boolean): Integer;
function intface_toggle_items(animated: Boolean): Integer;
function intface_toggle_item_state: Integer;
procedure intface_use_item;
function intface_is_item_right_hand: Integer;
function intface_get_current_item(itemPtr: PPObject): Integer;
function intface_update_ammo_lights: Integer;
procedure intface_end_window_open(animated: Boolean);
procedure intface_end_window_close(animated: Boolean);
procedure intface_end_buttons_enable;
procedure intface_end_buttons_disable;
function refresh_box_bar_win: Integer;
function enable_box_bar_win: Boolean;
function disable_box_bar_win: Boolean;

implementation

uses
  SysUtils,
  u_color,
  u_grbuf,
  u_gnw,
  u_gnw_types,
  u_button,
  u_input,
  u_memory,
  u_rect,
  u_text,
  u_svga,
  u_mouse,
  u_kb,
  u_debug,
  u_art,
  u_anim,
  u_item,
  u_critter,
  u_stat,
  u_stat_defs,
  u_proto,
  u_protinst,
  u_proto_types,
  u_combat,
  u_combat_defs,
  u_gmouse,
  u_message,
  u_display,
  u_fps_limiter,
  u_gsound,
  u_inventry,
  u_object,
  u_game;

// ---------------------------------------------------------------------------
// Additional imports
// ---------------------------------------------------------------------------

type
  TCompareFunc = function(a1: Pointer; a2: Pointer): Integer; cdecl;
procedure libc_qsort(base_: Pointer; num: SizeUInt; sz: SizeUInt; compare: TCompareFunc); cdecl; external 'c' name 'qsort';

// ---------------------------------------------------------------------------
// Constants (implementation-only)
// ---------------------------------------------------------------------------
const
  INDICATOR_BOX_CONNECTOR_WIDTH = 3;

  INTERFACE_NUMBERS_COLOR_WHITE  = 0;
  INTERFACE_NUMBERS_COLOR_YELLOW = 120;
  INTERFACE_NUMBERS_COLOR_RED    = 240;

  INDICATOR_BOX_WIDTH  = 130;
  INDICATOR_BOX_HEIGHT = 21;

  INDICATOR_SLOTS_COUNT = 4;

  // Indicator
  INDICATOR_ADDICT = 0;
  INDICATOR_SNEAK  = 1;
  INDICATOR_LEVEL  = 2;
  INDICATOR_COUNT  = 3;

  COMPAT_MAX_PATH = 260;

  WEAPON_SOUND_EFFECT_READY = 0;
  CHARACTER_SOUND_EFFECT_UNUSED = 0;

// ---------------------------------------------------------------------------
// Types (implementation-only)
// ---------------------------------------------------------------------------
type
  PIndicatorDescription = ^TIndicatorDescription;
  TIndicatorDescription = record
    title: Integer;
    isBad: Boolean;
    data: PByte;
  end;

  PInterfaceItemState = ^TInterfaceItemState;
  TInterfaceItemState = record
    item: PObject;
    isDisabled: Byte;
    isWeapon: Byte;
    primaryHitMode: Integer;
    secondaryHitMode: Integer;
    action: Integer;
    itemFid: Integer;
  end;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
function intface_init_items: Integer; forward;
function intface_redraw_items: Integer; forward;
function intface_redraw_items_callback(a1, a2: Pointer): Integer; cdecl; forward;
function intface_change_fid_callback(a1, a2: Pointer): Integer; cdecl; forward;
procedure intface_change_fid_animate(previousWeaponAnimationCode, weaponAnimationCode: Integer); forward;
function intface_create_end_turn_button: Integer; forward;
function intface_destroy_end_turn_button: Integer; forward;
function intface_create_end_combat_button: Integer; forward;
function intface_destroy_end_combat_button: Integer; forward;
procedure intface_draw_ammo_lights(x, ratio: Integer); forward;
function intface_item_reload: Integer; forward;
procedure intface_rotate_numbers(x, y, previousValue, value, offset, delay: Integer); forward;
function intface_fatal_error(rc: Integer): Integer; forward;
function construct_box_bar_win: Integer; forward;
procedure deconstruct_box_bar_win; forward;
procedure reset_box_bar_win; forward;
function bbox_comp(a, b: Pointer): Integer; cdecl; forward;
procedure draw_bboxes(count: Integer); forward;
function add_bar_box(indicator: Integer): Boolean; forward;

// ---------------------------------------------------------------------------
// Module-level variables (static in C++)
// ---------------------------------------------------------------------------
var
  insideInit: Boolean = False;
  intface_fid_is_changing: Boolean = False;
  intfaceEnabled: Boolean = False;
  intfaceHidden: Boolean = False;

  inventoryButton: Integer = -1;
  inventoryButtonUpKey: PCacheEntry = nil;
  inventoryButtonDownKey: PCacheEntry = nil;
  optionsButton: Integer = -1;
  optionsButtonUpKey: PCacheEntry = nil;
  optionsButtonDownKey: PCacheEntry = nil;
  skilldexButton: Integer = -1;
  skilldexButtonUpKey: PCacheEntry = nil;
  skilldexButtonDownKey: PCacheEntry = nil;
  skilldexButtonMaskKey: PCacheEntry = nil;
  automapButton: Integer = -1;
  automapButtonUpKey: PCacheEntry = nil;
  automapButtonDownKey: PCacheEntry = nil;
  automapButtonMaskKey: PCacheEntry = nil;
  pipboyButton: Integer = -1;
  pipboyButtonUpKey: PCacheEntry = nil;
  pipboyButtonDownKey: PCacheEntry = nil;
  characterButton: Integer = -1;
  characterButtonUpKey: PCacheEntry = nil;
  characterButtonDownKey: PCacheEntry = nil;
  itemButton: Integer = -1;
  itemButtonUpKey: PCacheEntry = nil;
  itemButtonDownKey: PCacheEntry = nil;
  itemButtonDisabledKey: PCacheEntry = nil;
  itemCurrentItem: Integer = HAND_LEFT;
  itemButtonRect: TRect = (ulx: 267; uly: 26; lrx: 455; lry: 93);
  toggleButton: Integer = -1;
  toggleButtonUpKey: PCacheEntry = nil;
  toggleButtonDownKey: PCacheEntry = nil;
  toggleButtonMaskKey: PCacheEntry = nil;
  endWindowOpen: Boolean = False;
  endWindowRect: TRect = (ulx: 580; uly: 38; lrx: 637; lry: 96);
  endTurnButton: Integer = -1;
  endTurnButtonUpKey: PCacheEntry = nil;
  endTurnButtonDownKey: PCacheEntry = nil;
  endCombatButton: Integer = -1;
  endCombatButtonUpKey: PCacheEntry = nil;
  endCombatButtonDownKey: PCacheEntry = nil;
  moveLightGreen: PByte = nil;
  moveLightYellow: PByte = nil;
  moveLightRed: PByte = nil;
  movePointRect: TRect = (ulx: 316; uly: 14; lrx: 406; lry: 19);
  numbersBuffer: PByte = nil;

  bbox: array[0..INDICATOR_COUNT - 1] of TIndicatorDescription = (
    (title: 102; isBad: True;  data: nil),
    (title: 100; isBad: False; data: nil),
    (title: 101; isBad: False; data: nil)
  );

var
  bboxslot: array[0..INDICATOR_SLOTS_COUNT - 1] of Integer;
  itemButtonItems: array[0..HAND_COUNT - 1] of TInterfaceItemState;
  moveLightYellowKey: PCacheEntry;
  moveLightRedKey: PCacheEntry;
  numbersKey: PCacheEntry;
  box_status_flag: Boolean;
  toggleButtonUpData: PByte;
  moveLightGreenKey: PCacheEntry;
  endCombatButtonUpData: PByte;
  endCombatButtonDownData: PByte;
  toggleButtonDownData: PByte;
  endTurnButtonDownData: PByte;
  itemButtonDown: array[0..188 * 67 - 1] of Byte;
  endTurnButtonUpData: PByte;
  toggleButtonMaskData: PByte;
  characterButtonUpData: PByte;
  itemButtonUpBlank: PByte;
  itemButtonDisabledData: PByte;
  automapButtonDownData: PByte;
  pipboyButtonUpData: PByte;
  characterButtonDownData: PByte;
  itemButtonDownBlank: PByte;
  pipboyButtonDownData: PByte;
  automapButtonMaskData: PByte;
  itemButtonUp: array[0..188 * 67 - 1] of Byte;
  automapButtonUpData: PByte;
  skilldexButtonMaskData: PByte;
  skilldexButtonDownData: PByte;
  interfaceBuffer: PByte;
  inventoryButtonUpData: PByte;
  optionsButtonUpData: PByte;
  optionsButtonDownData: PByte;
  skilldexButtonUpData: PByte;
  inventoryButtonDownData: PByte;
  movePointBackground: array[0..90 * 5 - 1] of Byte;

// Static locals from intface_update_hit_points
var
  hp_last_points: Integer = 0;
  hp_last_points_color: Integer = INTERFACE_NUMBERS_COLOR_RED;

// Static locals from intface_update_ac
var
  ac_last_ac: Integer = 0;

// Shared FPS limiter
var
  localFpsLimiter: TFpsLimiter = nil;

procedure ensureFpsLimiter;
begin
  if localFpsLimiter = nil then
    localFpsLimiter := TFpsLimiter.Create(60);
end;

// ===================================================================
// intface_init
// ===================================================================
function intface_init: Integer;
var
  fid: Integer;
  backgroundFrmHandle: PCacheEntry;
  backgroundFrmData: PByte;
  interfaceBarWindowX, interfaceBarWindowY: Integer;
begin
  WriteLn(StdErr, '[INTFACE] intface_init: start, interfaceWindow=', interfaceWindow);
  if interfaceWindow <> -1 then
  begin
    WriteLn(StdErr, '[INTFACE] interfaceWindow <> -1, aborting');
    Exit(-1);
  end;

  insideInit := True;

  interfaceBarWindowX := (screenGetWidth - INTERFACE_BAR_WIDTH) div 2;
  interfaceBarWindowY := screenGetHeight - INTERFACE_BAR_HEIGHT;

  interfaceWindow := win_add(interfaceBarWindowX, interfaceBarWindowY,
    INTERFACE_BAR_WIDTH, INTERFACE_BAR_HEIGHT, colorTable[0], WINDOW_HIDDEN);
  if interfaceWindow = -1 then
    Exit(intface_fatal_error(-1));

  interfaceBuffer := win_get_buf(interfaceWindow);
  if interfaceBuffer = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 16, 0, 0, 0);
  WriteLn(StdErr, '[INTFACE] loading background fid=', fid);
  backgroundFrmData := art_ptr_lock_data(fid, 0, 0, @backgroundFrmHandle);
  if backgroundFrmData = nil then
  begin
    WriteLn(StdErr, '[INTFACE] background art_ptr_lock_data FAILED for fid=', fid);
    Exit(intface_fatal_error(-1));
  end;
  WriteLn(StdErr, '[INTFACE] background loaded OK');

  buf_to_buf(backgroundFrmData, INTERFACE_BAR_WIDTH, INTERFACE_BAR_HEIGHT,
    INTERFACE_BAR_WIDTH, interfaceBuffer, 640);
  art_ptr_unlock(backgroundFrmHandle);

  // Inventory button
  fid := art_id(OBJ_TYPE_INTERFACE, 47, 0, 0, 0);
  inventoryButtonUpData := art_ptr_lock_data(fid, 0, 0, @inventoryButtonUpKey);
  if inventoryButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 46, 0, 0, 0);
  inventoryButtonDownData := art_ptr_lock_data(fid, 0, 0, @inventoryButtonDownKey);
  if inventoryButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  inventoryButton := win_register_button(interfaceWindow, 211, 41, 32, 21,
    -1, -1, -1, KEY_LOWERCASE_I, inventoryButtonUpData, inventoryButtonDownData, nil, 0);
  if inventoryButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_sound_func(inventoryButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] inventory button OK');

  // Options button
  fid := art_id(OBJ_TYPE_INTERFACE, 18, 0, 0, 0);
  optionsButtonUpData := art_ptr_lock_data(fid, 0, 0, @optionsButtonUpKey);
  if optionsButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 17, 0, 0, 0);
  optionsButtonDownData := art_ptr_lock_data(fid, 0, 0, @optionsButtonDownKey);
  if optionsButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  optionsButton := win_register_button(interfaceWindow, 210, 62, 34, 34,
    -1, -1, -1, KEY_LOWERCASE_O, optionsButtonUpData, optionsButtonDownData, nil, 0);
  if optionsButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_sound_func(optionsButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] options button OK');

  // Skilldex button
  fid := art_id(OBJ_TYPE_INTERFACE, 6, 0, 0, 0);
  skilldexButtonUpData := art_ptr_lock_data(fid, 0, 0, @skilldexButtonUpKey);
  if skilldexButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 7, 0, 0, 0);
  skilldexButtonDownData := art_ptr_lock_data(fid, 0, 0, @skilldexButtonDownKey);
  if skilldexButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 6, 0, 0, 0);
  skilldexButtonMaskData := art_ptr_lock_data(fid, 0, 0, @skilldexButtonMaskKey);
  if skilldexButtonMaskData = nil then
    Exit(intface_fatal_error(-1));

  skilldexButton := win_register_button(interfaceWindow, 523, 7, 22, 21,
    -1, -1, -1, KEY_LOWERCASE_S, skilldexButtonUpData, skilldexButtonDownData, nil, BUTTON_FLAG_TRANSPARENT);
  if skilldexButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_mask(skilldexButton, skilldexButtonMaskData);
  win_register_button_sound_func(skilldexButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] skilldex button OK');

  // Automap button
  fid := art_id(OBJ_TYPE_INTERFACE, 13, 0, 0, 0);
  automapButtonUpData := art_ptr_lock_data(fid, 0, 0, @automapButtonUpKey);
  if automapButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 10, 0, 0, 0);
  automapButtonDownData := art_ptr_lock_data(fid, 0, 0, @automapButtonDownKey);
  if automapButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 13, 0, 0, 0);
  automapButtonMaskData := art_ptr_lock_data(fid, 0, 0, @automapButtonMaskKey);
  if automapButtonMaskData = nil then
    Exit(intface_fatal_error(-1));

  automapButton := win_register_button(interfaceWindow, 526, 40, 41, 19,
    -1, -1, -1, KEY_TAB, automapButtonUpData, automapButtonDownData, nil, BUTTON_FLAG_TRANSPARENT);
  if automapButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_mask(automapButton, automapButtonMaskData);
  win_register_button_sound_func(automapButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] automap button OK');

  // Pipboy button
  fid := art_id(OBJ_TYPE_INTERFACE, 59, 0, 0, 0);
  pipboyButtonUpData := art_ptr_lock_data(fid, 0, 0, @pipboyButtonUpKey);
  if pipboyButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 58, 0, 0, 0);
  pipboyButtonDownData := art_ptr_lock_data(fid, 0, 0, @pipboyButtonDownKey);
  if pipboyButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  pipboyButton := win_register_button(interfaceWindow, 526, 78, 41, 19,
    -1, -1, -1, KEY_LOWERCASE_P, pipboyButtonUpData, pipboyButtonDownData, nil, 0);
  if pipboyButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_mask(pipboyButton, automapButtonMaskData);
  win_register_button_sound_func(pipboyButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] pipboy button OK');

  // Character button
  fid := art_id(OBJ_TYPE_INTERFACE, 57, 0, 0, 0);
  characterButtonUpData := art_ptr_lock_data(fid, 0, 0, @characterButtonUpKey);
  if characterButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 56, 0, 0, 0);
  characterButtonDownData := art_ptr_lock_data(fid, 0, 0, @characterButtonDownKey);
  if characterButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  characterButton := win_register_button(interfaceWindow, 526, 59, 41, 19,
    -1, -1, -1, KEY_LOWERCASE_C, characterButtonUpData, characterButtonDownData, nil, 0);
  if characterButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_mask(characterButton, automapButtonMaskData);
  win_register_button_sound_func(characterButton, @gsound_med_butt_press, @gsound_med_butt_release);
  WriteLn(StdErr, '[INTFACE] character button OK');

  // Item button
  fid := art_id(OBJ_TYPE_INTERFACE, 32, 0, 0, 0);
  itemButtonUpBlank := art_ptr_lock_data(fid, 0, 0, @itemButtonUpKey);
  if itemButtonUpBlank = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 31, 0, 0, 0);
  itemButtonDownBlank := art_ptr_lock_data(fid, 0, 0, @itemButtonDownKey);
  if itemButtonDownBlank = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 73, 0, 0, 0);
  itemButtonDisabledData := art_ptr_lock_data(fid, 0, 0, @itemButtonDisabledKey);
  if itemButtonDisabledData = nil then
    Exit(intface_fatal_error(-1));

  Move(itemButtonUpBlank^, itemButtonUp[0], SizeOf(itemButtonUp));
  Move(itemButtonDownBlank^, itemButtonDown[0], SizeOf(itemButtonDown));

  itemButton := win_register_button(interfaceWindow, 267, 26, 188, 67,
    -1, -1, -1, -20, @itemButtonUp[0], @itemButtonDown[0], nil, BUTTON_FLAG_TRANSPARENT);
  if itemButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_right_button(itemButton, -1, KEY_LOWERCASE_N, nil, nil);
  win_register_button_sound_func(itemButton, @gsound_lrg_butt_press, @gsound_lrg_butt_release);
  WriteLn(StdErr, '[INTFACE] item button OK');

  // Toggle (swap hands) button
  fid := art_id(OBJ_TYPE_INTERFACE, 6, 0, 0, 0);
  toggleButtonUpData := art_ptr_lock_data(fid, 0, 0, @toggleButtonUpKey);
  if toggleButtonUpData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 7, 0, 0, 0);
  toggleButtonDownData := art_ptr_lock_data(fid, 0, 0, @toggleButtonDownKey);
  if toggleButtonDownData = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 6, 0, 0, 0);
  toggleButtonMaskData := art_ptr_lock_data(fid, 0, 0, @toggleButtonMaskKey);
  if toggleButtonMaskData = nil then
    Exit(intface_fatal_error(-1));

  toggleButton := win_register_button(interfaceWindow, 218, 6, 22, 21,
    -1, -1, -1, KEY_LOWERCASE_B, toggleButtonUpData, toggleButtonDownData, nil, BUTTON_FLAG_TRANSPARENT);
  if toggleButton = -1 then
    Exit(intface_fatal_error(-1));

  win_register_button_mask(toggleButton, toggleButtonMaskData);
  win_register_button_sound_func(toggleButton, @gsound_med_butt_press, @gsound_med_butt_release);

  // Numbers bitmap
  fid := art_id(OBJ_TYPE_INTERFACE, 82, 0, 0, 0);
  numbersBuffer := art_ptr_lock_data(fid, 0, 0, @numbersKey);
  if numbersBuffer = nil then
    Exit(intface_fatal_error(-1));

  // Move point lights
  fid := art_id(OBJ_TYPE_INTERFACE, 83, 0, 0, 0);
  moveLightGreen := art_ptr_lock_data(fid, 0, 0, @moveLightGreenKey);
  if moveLightGreen = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 84, 0, 0, 0);
  moveLightYellow := art_ptr_lock_data(fid, 0, 0, @moveLightYellowKey);
  if moveLightYellow = nil then
    Exit(intface_fatal_error(-1));

  fid := art_id(OBJ_TYPE_INTERFACE, 85, 0, 0, 0);
  moveLightRed := art_ptr_lock_data(fid, 0, 0, @moveLightRedKey);
  if moveLightRed = nil then
    Exit(intface_fatal_error(-1));

  buf_to_buf(interfaceBuffer + 640 * 14 + 316, 90, 5, 640, @movePointBackground[0], 90);

  WriteLn(StdErr, '[INTFACE] all buttons OK, calling construct_box_bar_win');
  if construct_box_bar_win = -1 then
  begin
    WriteLn(StdErr, '[INTFACE] construct_box_bar_win FAILED');
    Exit(intface_fatal_error(-1));
  end;
  WriteLn(StdErr, '[INTFACE] construct_box_bar_win OK');

  itemCurrentItem := HAND_LEFT;

  intface_init_items;
  WriteLn(StdErr, '[INTFACE] intface_init_items OK');

  display_init;
  WriteLn(StdErr, '[INTFACE] display_init OK');

  intfaceEnabled := True;
  insideInit := False;
  intfaceHidden := True;

  WriteLn(StdErr, '[INTFACE] intface_init completed successfully');
  Result := 0;
end;

// ===================================================================
// intface_reset
// ===================================================================
procedure intface_reset;
begin
  intface_enable;
  intface_hide;
  display_reset;
  reset_box_bar_win;
  itemCurrentItem := 0;
end;

// ===================================================================
// intface_exit
// ===================================================================
procedure intface_exit;
begin
  if interfaceWindow <> -1 then
  begin
    display_exit;

    if moveLightRed <> nil then begin art_ptr_unlock(moveLightRedKey); moveLightRed := nil; end;
    if moveLightYellow <> nil then begin art_ptr_unlock(moveLightYellowKey); moveLightYellow := nil; end;
    if moveLightGreen <> nil then begin art_ptr_unlock(moveLightGreenKey); moveLightGreen := nil; end;
    if numbersBuffer <> nil then begin art_ptr_unlock(numbersKey); numbersBuffer := nil; end;

    if toggleButton <> -1 then begin win_delete_button(toggleButton); toggleButton := -1; end;
    if toggleButtonMaskData <> nil then begin art_ptr_unlock(toggleButtonMaskKey); toggleButtonMaskKey := nil; toggleButtonMaskData := nil; end;
    if toggleButtonDownData <> nil then begin art_ptr_unlock(toggleButtonDownKey); toggleButtonDownKey := nil; toggleButtonDownData := nil; end;
    if toggleButtonUpData <> nil then begin art_ptr_unlock(toggleButtonUpKey); toggleButtonUpKey := nil; toggleButtonUpData := nil; end;

    if itemButton <> -1 then begin win_delete_button(itemButton); itemButton := -1; end;
    if itemButtonDisabledData <> nil then begin art_ptr_unlock(itemButtonDisabledKey); itemButtonDisabledKey := nil; itemButtonDisabledData := nil; end;
    if itemButtonDownBlank <> nil then begin art_ptr_unlock(itemButtonDownKey); itemButtonDownKey := nil; itemButtonDownBlank := nil; end;
    if itemButtonUpBlank <> nil then begin art_ptr_unlock(itemButtonUpKey); itemButtonUpKey := nil; itemButtonUpBlank := nil; end;

    if characterButton <> -1 then begin win_delete_button(characterButton); characterButton := -1; end;
    if characterButtonDownData <> nil then begin art_ptr_unlock(characterButtonDownKey); characterButtonDownKey := nil; characterButtonDownData := nil; end;
    if characterButtonUpData <> nil then begin art_ptr_unlock(characterButtonUpKey); characterButtonUpKey := nil; characterButtonUpData := nil; end;

    if pipboyButton <> -1 then begin win_delete_button(pipboyButton); pipboyButton := -1; end;
    if pipboyButtonDownData <> nil then begin art_ptr_unlock(pipboyButtonDownKey); pipboyButtonDownKey := nil; pipboyButtonDownData := nil; end;
    if pipboyButtonUpData <> nil then begin art_ptr_unlock(pipboyButtonUpKey); pipboyButtonUpKey := nil; pipboyButtonUpData := nil; end;

    if automapButton <> -1 then begin win_delete_button(automapButton); automapButton := -1; end;
    if automapButtonMaskData <> nil then begin art_ptr_unlock(automapButtonMaskKey); automapButtonMaskKey := nil; automapButtonMaskData := nil; end;
    if automapButtonDownData <> nil then begin art_ptr_unlock(automapButtonDownKey); automapButtonDownKey := nil; automapButtonDownData := nil; end;
    if automapButtonUpData <> nil then begin art_ptr_unlock(automapButtonUpKey); automapButtonUpKey := nil; automapButtonUpData := nil; end;

    if skilldexButton <> -1 then begin win_delete_button(skilldexButton); skilldexButton := -1; end;
    if skilldexButtonMaskData <> nil then begin art_ptr_unlock(skilldexButtonMaskKey); skilldexButtonMaskKey := nil; skilldexButtonMaskData := nil; end;
    if skilldexButtonDownData <> nil then begin art_ptr_unlock(skilldexButtonDownKey); skilldexButtonDownKey := nil; skilldexButtonDownData := nil; end;
    if skilldexButtonUpData <> nil then begin art_ptr_unlock(skilldexButtonUpKey); skilldexButtonUpKey := nil; skilldexButtonUpData := nil; end;

    if optionsButton <> -1 then begin win_delete_button(optionsButton); optionsButton := -1; end;
    if optionsButtonDownData <> nil then begin art_ptr_unlock(optionsButtonDownKey); optionsButtonDownKey := nil; optionsButtonDownData := nil; end;
    if optionsButtonUpData <> nil then begin art_ptr_unlock(optionsButtonUpKey); optionsButtonUpKey := nil; optionsButtonUpData := nil; end;

    if inventoryButton <> -1 then begin win_delete_button(inventoryButton); inventoryButton := -1; end;
    if inventoryButtonDownData <> nil then begin art_ptr_unlock(inventoryButtonDownKey); inventoryButtonDownKey := nil; inventoryButtonDownData := nil; end;
    if inventoryButtonUpData <> nil then begin art_ptr_unlock(inventoryButtonUpKey); inventoryButtonUpKey := nil; inventoryButtonUpData := nil; end;

    if interfaceWindow <> -1 then begin win_delete(interfaceWindow); interfaceWindow := -1; end;
  end;

  deconstruct_box_bar_win;
end;

// ===================================================================
// intface_load
// ===================================================================
function intface_load(stream: PDB_FILE): Integer;
var
  enabled, hidden, endButtonsVisible: Boolean;
  hand: Integer;
begin
  if interfaceWindow = -1 then
  begin
    if intface_init = -1 then
      Exit(-1);
  end;

  if db_freadBool(stream, @enabled) = -1 then Exit(-1);
  if db_freadBool(stream, @hidden) = -1 then Exit(-1);
  if db_freadInt32(stream, @hand) = -1 then Exit(-1);
  if db_freadBool(stream, @endButtonsVisible) = -1 then Exit(-1);

  if not intfaceEnabled then
    intface_enable;

  if hidden then
    intface_hide
  else
    intface_show;

  intface_update_hit_points(False);
  intface_update_ac(False);

  itemCurrentItem := hand;

  intface_update_items(False);

  if endButtonsVisible <> endWindowOpen then
  begin
    if endButtonsVisible then
      intface_end_window_open(False)
    else
      intface_end_window_close(False);
  end;

  if not enabled then
    intface_disable;

  refresh_box_bar_win;
  win_draw(interfaceWindow);

  Result := 0;
end;

// ===================================================================
// intface_save
// ===================================================================
function intface_save(stream: PDB_FILE): Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  if db_fwriteBool(stream, intfaceEnabled) = -1 then Exit(-1);
  if db_fwriteBool(stream, intfaceHidden) = -1 then Exit(-1);
  if db_fwriteInt32(stream, itemCurrentItem) = -1 then Exit(-1);
  if db_fwriteBool(stream, endWindowOpen) = -1 then Exit(-1);

  Result := 0;
end;

// ===================================================================
// intface_hide
// ===================================================================
procedure intface_hide;
begin
  if interfaceWindow <> -1 then
  begin
    if not intfaceHidden then
    begin
      win_hide(interfaceWindow);
      intfaceHidden := True;
    end;
  end;
  refresh_box_bar_win;
end;

// ===================================================================
// intface_show
// ===================================================================
procedure intface_show;
begin
  if interfaceWindow <> -1 then
  begin
    if intfaceHidden then
    begin
      intface_update_items(False);
      intface_update_hit_points(False);
      intface_update_ac(False);
      win_show(interfaceWindow);
      intfaceHidden := False;
    end;
  end;
  refresh_box_bar_win;
end;

// ===================================================================
// intface_is_hidden
// ===================================================================
function intface_is_hidden: Integer;
begin
  if intfaceHidden then
    Result := 1
  else
    Result := 0;
end;

// ===================================================================
// intface_enable
// ===================================================================
procedure intface_enable;
begin
  if not intfaceEnabled then
  begin
    win_enable_button(inventoryButton);
    win_enable_button(optionsButton);
    win_enable_button(skilldexButton);
    win_enable_button(automapButton);
    win_enable_button(pipboyButton);
    win_enable_button(characterButton);

    if itemButtonItems[itemCurrentItem].isDisabled = 0 then
      win_enable_button(itemButton);

    win_enable_button(endTurnButton);
    win_enable_button(endCombatButton);
    display_enable;

    intfaceEnabled := True;
  end;
end;

// ===================================================================
// intface_disable
// ===================================================================
procedure intface_disable;
begin
  if intfaceEnabled then
  begin
    display_disable;
    win_disable_button(inventoryButton);
    win_disable_button(optionsButton);
    win_disable_button(skilldexButton);
    win_disable_button(automapButton);
    win_disable_button(pipboyButton);
    win_disable_button(characterButton);
    if itemButtonItems[itemCurrentItem].isDisabled = 0 then
      win_disable_button(itemButton);
    win_disable_button(endTurnButton);
    win_disable_button(endCombatButton);
    intfaceEnabled := False;
  end;
end;

// ===================================================================
// intface_is_enabled
// ===================================================================
function intface_is_enabled: Boolean;
begin
  Result := intfaceEnabled;
end;

// ===================================================================
// intface_redraw
// ===================================================================
procedure intface_redraw;
begin
  if interfaceWindow <> -1 then
  begin
    intface_update_items(False);
    intface_update_hit_points(False);
    intface_update_ac(False);
    refresh_box_bar_win;
    win_draw(interfaceWindow);
  end;
  refresh_box_bar_win;
end;

// ===================================================================
// intface_update_hit_points
// ===================================================================
procedure intface_update_hit_points(animate: Boolean);
var
  hp, maxHp, red, yellow, color_: Integer;
  v1: array[0..3] of Integer;
  v2: array[0..2] of Integer;
  count: Integer;
  delay_, index: Integer;
begin
  if interfaceWindow = -1 then
    Exit;

  hp := critter_get_hits(obj_dude);
  maxHp := stat_level(obj_dude, Integer(STAT_MAXIMUM_HIT_POINTS));

  red := Trunc(Double(maxHp) * 0.25);
  yellow := Trunc(Double(maxHp) * 0.5);

  if hp < red then
    color_ := INTERFACE_NUMBERS_COLOR_RED
  else if hp < yellow then
    color_ := INTERFACE_NUMBERS_COLOR_YELLOW
  else
    color_ := INTERFACE_NUMBERS_COLOR_WHITE;

  count := 1;
  v1[0] := hp_last_points;
  v2[0] := hp_last_points_color;

  if hp_last_points_color <> color_ then
  begin
    if hp >= hp_last_points then
    begin
      if (hp_last_points < red) and (hp >= red) then
      begin
        v1[count] := red;
        v2[count] := INTERFACE_NUMBERS_COLOR_YELLOW;
        Inc(count);
      end;
      if (hp_last_points < yellow) and (hp >= yellow) then
      begin
        v1[count] := yellow;
        v2[count] := INTERFACE_NUMBERS_COLOR_WHITE;
        Inc(count);
      end;
    end
    else
    begin
      if (hp_last_points >= yellow) and (hp < yellow) then
      begin
        v1[count] := yellow;
        v2[count] := INTERFACE_NUMBERS_COLOR_YELLOW;
        Inc(count);
      end;
      if (hp_last_points >= red) and (hp < red) then
      begin
        v1[count] := red;
        v2[count] := INTERFACE_NUMBERS_COLOR_RED;
        Inc(count);
      end;
    end;
  end;

  v1[count] := hp;

  if animate then
  begin
    delay_ := 250 div (Abs(hp_last_points - hp) + 1);
    index := 0;
    while index < count do
    begin
      intface_rotate_numbers(473, 40, v1[index], v1[index + 1], v2[index], delay_);
      Inc(index);
    end;
  end
  else
  begin
    intface_rotate_numbers(473, 40, hp_last_points, hp, color_, 0);
  end;

  hp_last_points := hp;
  hp_last_points_color := color_;
end;

// ===================================================================
// intface_update_ac
// ===================================================================
procedure intface_update_ac(animate: Boolean);
var
  armorClass, delay_: Integer;
begin
  armorClass := stat_level(obj_dude, Integer(STAT_ARMOR_CLASS));

  delay_ := 0;
  if animate then
    delay_ := 250 div (Abs(ac_last_ac - armorClass) + 1);

  intface_rotate_numbers(473, 75, ac_last_ac, armorClass, 0, delay_);

  ac_last_ac := armorClass;
end;

// ===================================================================
// intface_update_move_points
// ===================================================================
procedure intface_update_move_points(actionPointsArg: Integer; bonusMoveArg: Integer);
var
  frmData: PByte;
  circle, index: Integer;
  ap_local, bm_local: Integer;
begin
  if interfaceWindow = -1 then
    Exit;

  ap_local := actionPointsArg;
  bm_local := bonusMoveArg;

  buf_to_buf(@movePointBackground[0], 90, 5, 90, interfaceBuffer + 14 * 640 + 316, 640);

  if ap_local = -1 then
  begin
    frmData := moveLightRed;
    ap_local := 10;
    bm_local := 0;
  end
  else
    frmData := moveLightGreen;

  circle := 0;

  index := 0;
  while (index < ap_local) and (circle < 10) do
  begin
    buf_to_buf(frmData, 5, 5, 5,
      interfaceBuffer + 14 * 640 + 316 + circle * 9, 640);
    Inc(circle);
    Inc(index);
  end;

  index := 0;
  while (index < bm_local) and (circle < 10) do
  begin
    buf_to_buf(moveLightYellow, 5, 5, 5,
      interfaceBuffer + 14 * 640 + 316 + circle * 9, 640);
    Inc(circle);
    Inc(index);
  end;

  if not insideInit then
    win_draw_rect(interfaceWindow, @movePointRect);
end;

// ===================================================================
// intface_get_attack
// ===================================================================
function intface_get_attack(hitMode: PInteger; aiming: PBoolean): Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  aiming^ := False;

  case itemButtonItems[itemCurrentItem].action of
    INTERFACE_ITEM_ACTION_PRIMARY_AIMING:
    begin
      aiming^ := True;
      hitMode^ := itemButtonItems[itemCurrentItem].primaryHitMode;
      Exit(0);
    end;
    INTERFACE_ITEM_ACTION_PRIMARY:
    begin
      hitMode^ := itemButtonItems[itemCurrentItem].primaryHitMode;
      Exit(0);
    end;
    INTERFACE_ITEM_ACTION_SECONDARY_AIMING:
    begin
      aiming^ := True;
      hitMode^ := itemButtonItems[itemCurrentItem].secondaryHitMode;
      Exit(0);
    end;
    INTERFACE_ITEM_ACTION_SECONDARY:
    begin
      hitMode^ := itemButtonItems[itemCurrentItem].secondaryHitMode;
      Exit(0);
    end;
  end;

  Result := -1;
end;

// ===================================================================
// intface_update_items
// ===================================================================
function intface_update_items(animated: Boolean): Integer;
var
  oldCurrentItem, newCurrentItem: PObject;
  leftItemState, rightItemState: PInterfaceItemState;
  item1, item2: PObject;
  animationCode: Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  oldCurrentItem := itemButtonItems[itemCurrentItem].item;

  leftItemState := @itemButtonItems[HAND_LEFT];
  item1 := inven_left_hand(obj_dude);
  if (item1 = leftItemState^.item) and (leftItemState^.item <> nil) then
  begin
    if leftItemState^.item <> nil then
    begin
      leftItemState^.isDisabled := Ord(item_grey(item1));
      leftItemState^.itemFid := item_inv_fid(item1);
    end;
  end
  else
  begin
    leftItemState^.item := item1;
    if item1 <> nil then
    begin
      leftItemState^.isDisabled := Ord(item_grey(item1));
      leftItemState^.primaryHitMode := HIT_MODE_LEFT_WEAPON_PRIMARY;
      leftItemState^.secondaryHitMode := HIT_MODE_LEFT_WEAPON_SECONDARY;
      if item_get_type(item1) = ITEM_TYPE_WEAPON then
        leftItemState^.isWeapon := 1
      else
        leftItemState^.isWeapon := 0;
      if leftItemState^.isWeapon <> 0 then
        leftItemState^.action := INTERFACE_ITEM_ACTION_PRIMARY
      else
        leftItemState^.action := INTERFACE_ITEM_ACTION_USE;
      leftItemState^.itemFid := item_inv_fid(item1);
    end
    else
    begin
      leftItemState^.isDisabled := 0;
      leftItemState^.isWeapon := 1;
      leftItemState^.primaryHitMode := HIT_MODE_PUNCH;
      leftItemState^.secondaryHitMode := HIT_MODE_PUNCH;
      leftItemState^.action := INTERFACE_ITEM_ACTION_PRIMARY;
      leftItemState^.itemFid := -1;
    end;
  end;

  rightItemState := @itemButtonItems[HAND_RIGHT];
  item2 := inven_right_hand(obj_dude);
  if (item2 = rightItemState^.item) and (rightItemState^.item <> nil) then
  begin
    if rightItemState^.item <> nil then
    begin
      rightItemState^.isDisabled := Ord(item_grey(rightItemState^.item));
      rightItemState^.itemFid := item_inv_fid(rightItemState^.item);
    end;
  end
  else
  begin
    rightItemState^.item := item2;
    if item2 <> nil then
    begin
      rightItemState^.isDisabled := Ord(item_grey(item2));
      rightItemState^.primaryHitMode := HIT_MODE_RIGHT_WEAPON_PRIMARY;
      rightItemState^.secondaryHitMode := HIT_MODE_RIGHT_WEAPON_SECONDARY;
      if item_get_type(item2) = ITEM_TYPE_WEAPON then
        rightItemState^.isWeapon := 1
      else
        rightItemState^.isWeapon := 0;
      if rightItemState^.isWeapon <> 0 then
        rightItemState^.action := INTERFACE_ITEM_ACTION_PRIMARY
      else
        rightItemState^.action := INTERFACE_ITEM_ACTION_USE;
      rightItemState^.itemFid := item_inv_fid(item2);
    end
    else
    begin
      rightItemState^.isDisabled := 0;
      rightItemState^.isWeapon := 1;
      rightItemState^.primaryHitMode := HIT_MODE_PUNCH;
      rightItemState^.secondaryHitMode := HIT_MODE_PUNCH;
      rightItemState^.action := INTERFACE_ITEM_ACTION_PRIMARY;
      rightItemState^.itemFid := -1;
    end;
  end;

  if animated then
  begin
    newCurrentItem := itemButtonItems[itemCurrentItem].item;
    if newCurrentItem <> oldCurrentItem then
    begin
      animationCode := 0;
      if newCurrentItem <> nil then
      begin
        if item_get_type(newCurrentItem) = ITEM_TYPE_WEAPON then
          animationCode := item_w_anim_code(newCurrentItem);
      end;

      intface_change_fid_animate((obj_dude^.Fid and $F000) shr 12, animationCode);
      Exit(0);
    end;
  end;

  intface_redraw_items;
  Result := 0;
end;

// ===================================================================
// intface_toggle_items
// ===================================================================
function intface_toggle_items(animated: Boolean): Integer;
var
  item_: PObject;
  animationCode, mode: Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  itemCurrentItem := 1 - itemCurrentItem;

  if animated then
  begin
    item_ := itemButtonItems[itemCurrentItem].item;
    animationCode := 0;
    if item_ <> nil then
    begin
      if item_get_type(item_) = ITEM_TYPE_WEAPON then
        animationCode := item_w_anim_code(item_);
    end;

    intface_change_fid_animate((obj_dude^.Fid and $F000) shr 12, animationCode);
  end
  else
    intface_redraw_items;

  mode := gmouse_3d_get_mode;
  if (mode = GAME_MOUSE_MODE_CROSSHAIR) or (mode = GAME_MOUSE_MODE_USE_CROSSHAIR) then
    gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);

  Result := 0;
end;

// ===================================================================
// intface_toggle_item_state
// ===================================================================
function intface_toggle_item_state: Integer;
var
  itemState: PInterfaceItemState;
  oldAction: Integer;
  done: Boolean;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  itemState := @itemButtonItems[itemCurrentItem];
  oldAction := itemState^.action;

  if itemState^.isWeapon <> 0 then
  begin
    done := False;
    while not done do
    begin
      Inc(itemState^.action);
      case itemState^.action of
        INTERFACE_ITEM_ACTION_PRIMARY:
          done := True;
        INTERFACE_ITEM_ACTION_PRIMARY_AIMING:
          if item_w_called_shot(obj_dude, itemState^.primaryHitMode) <> 0 then
            done := True;
        INTERFACE_ITEM_ACTION_SECONDARY:
          if (itemState^.secondaryHitMode <> HIT_MODE_PUNCH) and
             (itemState^.secondaryHitMode <> HIT_MODE_KICK) and
             (item_w_subtype(itemState^.item, itemState^.secondaryHitMode) <> ATTACK_TYPE_NONE) then
            done := True;
        INTERFACE_ITEM_ACTION_SECONDARY_AIMING:
          if (itemState^.secondaryHitMode <> HIT_MODE_PUNCH) and
             (itemState^.secondaryHitMode <> HIT_MODE_KICK) and
             (item_w_subtype(itemState^.item, itemState^.secondaryHitMode) <> ATTACK_TYPE_NONE) and
             (item_w_called_shot(obj_dude, itemState^.secondaryHitMode) <> 0) then
            done := True;
        INTERFACE_ITEM_ACTION_RELOAD:
          if item_w_max_ammo(itemState^.item) <> item_w_curr_ammo(itemState^.item) then
            done := True;
        INTERFACE_ITEM_ACTION_COUNT:
          itemState^.action := INTERFACE_ITEM_ACTION_USE;
      end;
    end;
  end;

  if oldAction <> itemState^.action then
    intface_redraw_items;

  Result := 0;
end;

// ===================================================================
// intface_use_item
// ===================================================================
procedure intface_use_item;
var
  ptr: PInterfaceItemState;
  hitMode_, actionPointsRequired: Integer;
begin
  if interfaceWindow = -1 then
    Exit;

  ptr := @itemButtonItems[itemCurrentItem];

  if ptr^.isWeapon <> 0 then
  begin
    if ptr^.action = INTERFACE_ITEM_ACTION_RELOAD then
    begin
      if isInCombat then
      begin
        if itemCurrentItem = HAND_LEFT then
          hitMode_ := HIT_MODE_LEFT_WEAPON_RELOAD
        else
          hitMode_ := HIT_MODE_RIGHT_WEAPON_RELOAD;

        actionPointsRequired := item_mp_cost(obj_dude, hitMode_, False);
        if actionPointsRequired <= obj_dude^.Data.AsData.Critter.Combat.Ap then
        begin
          if intface_item_reload = 0 then
          begin
            if actionPointsRequired > obj_dude^.Data.AsData.Critter.Combat.Ap then
              obj_dude^.Data.AsData.Critter.Combat.Ap := 0
            else
              obj_dude^.Data.AsData.Critter.Combat.Ap :=
                obj_dude^.Data.AsData.Critter.Combat.Ap - actionPointsRequired;
            intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);
          end;
        end;
      end
      else
        intface_item_reload;
    end
    else
    begin
      gmouse_set_cursor(MOUSE_CURSOR_CROSSHAIR);
      gmouse_3d_set_mode(GAME_MOUSE_MODE_CROSSHAIR);
      if not isInCombat then
        combat(nil);
    end;
  end
  else if proto_action_can_use_on(ptr^.item^.Pid) then
  begin
    gmouse_set_cursor(MOUSE_CURSOR_USE_CROSSHAIR);
    gmouse_3d_set_mode(GAME_MOUSE_MODE_USE_CROSSHAIR);
  end
  else if proto_action_can_use(ptr^.item^.Pid) then
  begin
    if isInCombat then
    begin
      actionPointsRequired := item_mp_cost(obj_dude, ptr^.secondaryHitMode, False);
      if actionPointsRequired <= obj_dude^.Data.AsData.Critter.Combat.Ap then
      begin
        obj_use_item(obj_dude, ptr^.item);
        intface_update_items(False);
        if actionPointsRequired > obj_dude^.Data.AsData.Critter.Combat.Ap then
          obj_dude^.Data.AsData.Critter.Combat.Ap := 0
        else
          obj_dude^.Data.AsData.Critter.Combat.Ap :=
            obj_dude^.Data.AsData.Critter.Combat.Ap - actionPointsRequired;
        intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);
      end;
    end
    else
    begin
      obj_use_item(obj_dude, ptr^.item);
      intface_update_items(False);
    end;
  end;
end;

// ===================================================================
// intface_is_item_right_hand
// ===================================================================
function intface_is_item_right_hand: Integer;
begin
  Result := itemCurrentItem;
end;

// ===================================================================
// intface_get_current_item
// ===================================================================
function intface_get_current_item(itemPtr: PPObject): Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  itemPtr^ := itemButtonItems[itemCurrentItem].item;
  Result := 0;
end;

// ===================================================================
// intface_update_ammo_lights
// ===================================================================
function intface_update_ammo_lights: Integer;
var
  p: PInterfaceItemState;
  ratio, maximum, current: Integer;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  p := @itemButtonItems[itemCurrentItem];
  ratio := 0;

  if p^.isWeapon <> 0 then
  begin
    maximum := item_w_max_ammo(p^.item);
    if maximum > 0 then
    begin
      current := item_w_curr_ammo(p^.item);
      ratio := Trunc(Double(current) / Double(maximum) * 70.0);
    end;
  end
  else
  begin
    if item_get_type(p^.item) = ITEM_TYPE_MISC then
    begin
      maximum := item_m_max_charges(p^.item);
      if maximum > 0 then
      begin
        current := item_m_curr_charges(p^.item);
        ratio := Trunc(Double(current) / Double(maximum) * 70.0);
      end;
    end;
  end;

  intface_draw_ammo_lights(463, ratio);
  Result := 0;
end;

// ===================================================================
// intface_end_window_open
// ===================================================================
procedure intface_end_window_open(animated: Boolean);
var
  fid, frameCount, frame_: Integer;
  handle: PCacheEntry;
  artPtr: PArt;
  delay_, time_: LongWord;
  src: PByte;
begin
  if interfaceWindow = -1 then Exit;
  if endWindowOpen then Exit;

  fid := art_id(OBJ_TYPE_INTERFACE, 104, 0, 0, 0);
  artPtr := art_ptr_lock(fid, @handle);
  if artPtr = nil then Exit;

  frameCount := art_frame_max_frame(artPtr);
  gsound_play_sfx_file('iciboxx1');

  ensureFpsLimiter;
  if animated then
  begin
    delay_ := 1000 div LongWord(art_frame_fps(artPtr));
    time_ := 0;
    frame_ := 0;
    while frame_ < frameCount do
    begin
      localFpsLimiter.Mark;
      if elapsed_time(time_) >= delay_ then
      begin
        src := art_frame_data(artPtr, frame_, 0);
        if src <> nil then
        begin
          buf_to_buf(src, 57, 58, 57, interfaceBuffer + 640 * 38 + 580, 640);
          win_draw_rect(interfaceWindow, @endWindowRect);
        end;
        time_ := get_time;
        Inc(frame_);
      end;
      gmouse_bk_process;
      renderPresent;
      localFpsLimiter.Throttle;
    end;
  end
  else
  begin
    src := art_frame_data(artPtr, frameCount - 1, 0);
    buf_to_buf(src, 57, 58, 57, interfaceBuffer + 640 * 38 + 580, 640);
    win_draw_rect(interfaceWindow, @endWindowRect);
  end;

  art_ptr_unlock(handle);
  endWindowOpen := True;
  intface_create_end_turn_button;
  intface_create_end_combat_button;
  intface_end_buttons_disable;
end;

// ===================================================================
// intface_end_window_close
// ===================================================================
procedure intface_end_window_close(animated: Boolean);
var
  fid, frame_: Integer;
  handle: PCacheEntry;
  artPtr: PArt;
  delay_, time_: LongWord;
  src, dest: PByte;
begin
  if interfaceWindow = -1 then Exit;
  if not endWindowOpen then Exit;

  fid := art_id(OBJ_TYPE_INTERFACE, 104, 0, 0, 0);
  artPtr := art_ptr_lock(fid, @handle);
  if artPtr = nil then Exit;

  intface_destroy_end_turn_button;
  intface_destroy_end_combat_button;
  gsound_play_sfx_file('icibcxx1');

  ensureFpsLimiter;
  if animated then
  begin
    delay_ := 1000 div LongWord(art_frame_fps(artPtr));
    time_ := 0;
    frame_ := art_frame_max_frame(artPtr);
    while frame_ <> 0 do
    begin
      localFpsLimiter.Mark;
      if elapsed_time(time_) >= delay_ then
      begin
        src := art_frame_data(artPtr, frame_ - 1, 0);
        dest := interfaceBuffer + 640 * 38 + 580;
        if src <> nil then
        begin
          buf_to_buf(src, 57, 58, 57, dest, 640);
          win_draw_rect(interfaceWindow, @endWindowRect);
        end;
        time_ := get_time;
        Dec(frame_);
      end;
      gmouse_bk_process;
      renderPresent;
      localFpsLimiter.Throttle;
    end;
  end
  else
  begin
    dest := interfaceBuffer + 640 * 38 + 580;
    src := art_frame_data(artPtr, 0, 0);
    buf_to_buf(src, 57, 58, 57, dest, 640);
    win_draw_rect(interfaceWindow, @endWindowRect);
  end;

  art_ptr_unlock(handle);
  endWindowOpen := False;
end;

// ===================================================================
// intface_end_buttons_enable
// ===================================================================
procedure intface_end_buttons_enable;
var
  lightsFid: Integer;
  lightsFrmHandle: PCacheEntry;
  lightsFrmData: PByte;
begin
  if endWindowOpen then
  begin
    win_enable_button(endTurnButton);
    win_enable_button(endCombatButton);

    lightsFid := art_id(OBJ_TYPE_INTERFACE, 109, 0, 0, 0);
    lightsFrmData := art_ptr_lock_data(lightsFid, 0, 0, @lightsFrmHandle);
    if lightsFrmData = nil then Exit;

    gsound_play_sfx_file('icombat2');
    trans_buf_to_buf(lightsFrmData, 57, 58, 57, interfaceBuffer + 38 * 640 + 580, 640);
    win_draw_rect(interfaceWindow, @endWindowRect);

    art_ptr_unlock(lightsFrmHandle);
  end;
end;

// ===================================================================
// intface_end_buttons_disable
// ===================================================================
procedure intface_end_buttons_disable;
var
  lightsFid: Integer;
  lightsFrmHandle: PCacheEntry;
  lightsFrmData: PByte;
begin
  if endWindowOpen then
  begin
    win_disable_button(endTurnButton);
    win_disable_button(endCombatButton);

    lightsFid := art_id(OBJ_TYPE_INTERFACE, 110, 0, 0, 0);
    lightsFrmData := art_ptr_lock_data(lightsFid, 0, 0, @lightsFrmHandle);
    if lightsFrmData = nil then Exit;

    gsound_play_sfx_file('icombat1');
    trans_buf_to_buf(lightsFrmData, 57, 58, 57, interfaceBuffer + 38 * 640 + 580, 640);
    win_draw_rect(interfaceWindow, @endWindowRect);

    art_ptr_unlock(lightsFrmHandle);
  end;
end;

// ===================================================================
// intface_init_items
// ===================================================================
function intface_init_items: Integer;
begin
  itemButtonItems[HAND_LEFT].item := PObject(Pointer(PtrInt(-1)));
  itemButtonItems[HAND_RIGHT].item := PObject(Pointer(PtrInt(-1)));
  Result := 0;
end;

// ===================================================================
// intface_redraw_items
// ===================================================================
function intface_redraw_items: Integer;
var
  itemState: PInterfaceItemState;
  actionPointsLocal: Integer;
  fid_: Integer;
  useTextFrmHandle, bullseyeFrmHandle, primaryFrmHandle, handle: PCacheEntry;
  useTextFrm, bullseyeFrm, primaryFrm, art_: PArt;
  width_, height_: Integer;
  data_: PByte;
  primaryFid, bullseyeFid, hitMode_: Integer;
  id_: Integer;
  anim_: Integer;
  v9, v29, v40, v46, v47, offset_: Integer;
  itemFrmHandle: PCacheEntry;
  itemFrm: PArt;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  win_enable_button(itemButton);
  itemState := @itemButtonItems[itemCurrentItem];
  actionPointsLocal := -1;

  if itemState^.isDisabled = 0 then
  begin
    Move(itemButtonUpBlank^, itemButtonUp[0], SizeOf(itemButtonUp));
    Move(itemButtonDownBlank^, itemButtonDown[0], SizeOf(itemButtonDown));

    if itemState^.isWeapon = 0 then
    begin
      if proto_action_can_use_on(itemState^.item^.Pid) then
        fid_ := art_id(OBJ_TYPE_INTERFACE, 294, 0, 0, 0)
      else if proto_action_can_use(itemState^.item^.Pid) then
        fid_ := art_id(OBJ_TYPE_INTERFACE, 292, 0, 0, 0)
      else
        fid_ := -1;

      if fid_ <> -1 then
      begin
        useTextFrm := art_ptr_lock(fid_, @useTextFrmHandle);
        if useTextFrm <> nil then
        begin
          width_ := art_frame_width(useTextFrm, 0, 0);
          height_ := art_frame_length(useTextFrm, 0, 0);
          data_ := art_frame_data(useTextFrm, 0, 0);
          trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonUp[0] + 188 * 7 + 181 - width_, 188);
          dark_trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonDown[0], 181 - width_ + 1, 5, 188, 59641);
          art_ptr_unlock(useTextFrmHandle);
        end;
        actionPointsLocal := item_mp_cost(obj_dude, itemState^.primaryHitMode, False);
      end;
    end
    else
    begin
      primaryFid := -1;
      bullseyeFid := -1;
      hitMode_ := -1;

      case itemState^.action of
        INTERFACE_ITEM_ACTION_PRIMARY_AIMING:
        begin
          bullseyeFid := art_id(OBJ_TYPE_INTERFACE, 288, 0, 0, 0);
          hitMode_ := itemState^.primaryHitMode;
        end;
        INTERFACE_ITEM_ACTION_PRIMARY:
          hitMode_ := itemState^.primaryHitMode;
        INTERFACE_ITEM_ACTION_SECONDARY_AIMING:
        begin
          bullseyeFid := art_id(OBJ_TYPE_INTERFACE, 288, 0, 0, 0);
          hitMode_ := itemState^.secondaryHitMode;
        end;
        INTERFACE_ITEM_ACTION_SECONDARY:
          hitMode_ := itemState^.secondaryHitMode;
        INTERFACE_ITEM_ACTION_RELOAD:
        begin
          if itemCurrentItem = HAND_LEFT then
            actionPointsLocal := item_mp_cost(obj_dude, HIT_MODE_LEFT_WEAPON_RELOAD, False)
          else
            actionPointsLocal := item_mp_cost(obj_dude, HIT_MODE_RIGHT_WEAPON_RELOAD, False);
          primaryFid := art_id(OBJ_TYPE_INTERFACE, 291, 0, 0, 0);
        end;
      end;

      if bullseyeFid <> -1 then
      begin
        bullseyeFrm := art_ptr_lock(bullseyeFid, @bullseyeFrmHandle);
        if bullseyeFrm <> nil then
        begin
          width_ := art_frame_width(bullseyeFrm, 0, 0);
          height_ := art_frame_length(bullseyeFrm, 0, 0);
          data_ := art_frame_data(bullseyeFrm, 0, 0);
          trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonUp[0] + 188 * (60 - height_) + (181 - width_), 188);

          v9 := 60 - height_ - 2;
          if v9 < 0 then
          begin
            v9 := 0;
            Dec(height_, 2);
          end;

          dark_trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonDown[0], 181 - width_ + 1, v9, 188, 59641);
          art_ptr_unlock(bullseyeFrmHandle);
        end;
      end;

      if hitMode_ <> -1 then
      begin
        actionPointsLocal := item_w_mp_cost(obj_dude, hitMode_, bullseyeFid <> -1);

        anim_ := item_w_anim(obj_dude, hitMode_);
        case anim_ of
          ANIM_THROW_PUNCH, ANIM_KICK_LEG:
            id_ := 287;
          ANIM_THROW_ANIM:
            id_ := 117;
          ANIM_THRUST_ANIM:
            id_ := 45;
          ANIM_SWING_ANIM:
            id_ := 44;
          ANIM_FIRE_SINGLE:
            id_ := 43;
          ANIM_FIRE_BURST, ANIM_FIRE_CONTINUOUS:
            id_ := 40;
        else
          id_ := 0; // fallback
        end;

        primaryFid := art_id(OBJ_TYPE_INTERFACE, id_, 0, 0, 0);
      end;

      if primaryFid <> -1 then
      begin
        primaryFrm := art_ptr_lock(primaryFid, @primaryFrmHandle);
        if primaryFrm <> nil then
        begin
          width_ := art_frame_width(primaryFrm, 0, 0);
          height_ := art_frame_length(primaryFrm, 0, 0);
          data_ := art_frame_data(primaryFrm, 0, 0);
          trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonUp[0] + 188 * 7 + 181 - width_, 188);
          dark_trans_buf_to_buf(data_, width_, height_, width_,
            @itemButtonDown[0], 181 - width_ + 1, 5, 188, 59641);
          art_ptr_unlock(primaryFrmHandle);
        end;
      end;
    end;
  end;

  if (actionPointsLocal >= 0) and (actionPointsLocal < 10) then
  begin
    fid_ := art_id(OBJ_TYPE_INTERFACE, 289, 0, 0, 0);
    art_ := art_ptr_lock(fid_, @handle);
    if art_ <> nil then
    begin
      width_ := art_frame_width(art_, 0, 0);
      height_ := art_frame_length(art_, 0, 0);
      data_ := art_frame_data(art_, 0, 0);

      trans_buf_to_buf(data_, width_, height_, width_,
        @itemButtonUp[0] + 188 * (60 - height_) + 7, 188);

      v29 := 60 - height_ - 2;
      if v29 < 0 then
      begin
        v29 := 0;
        Dec(height_, 2);
      end;

      dark_trans_buf_to_buf(data_, width_, height_, width_,
        @itemButtonDown[0], 7 + 1, v29, 188, 59641);
      art_ptr_unlock(handle);

      offset_ := width_ + 7;

      fid_ := art_id(OBJ_TYPE_INTERFACE, 290, 0, 0, 0);
      art_ := art_ptr_lock(fid_, @handle);
      if art_ <> nil then
      begin
        width_ := art_frame_width(art_, 0, 0);
        height_ := art_frame_length(art_, 0, 0);
        data_ := art_frame_data(art_, 0, 0);

        trans_buf_to_buf(data_ + actionPointsLocal * 10, 10, height_, width_,
          @itemButtonUp[0] + 188 * (60 - height_) + 7 + offset_, 188);

        v40 := 60 - height_ - 2;
        if v40 < 0 then
        begin
          v40 := 0;
          Dec(height_, 2);
        end;
        dark_trans_buf_to_buf(data_ + actionPointsLocal * 10, 10, height_, width_,
          @itemButtonDown[0], offset_ + 7 + 1, v40, 188, 59641);

        art_ptr_unlock(handle);
      end;
    end;
  end
  else
  begin
    Move(itemButtonDisabledData^, itemButtonUp[0], SizeOf(itemButtonUp));
    Move(itemButtonDisabledData^, itemButtonDown[0], SizeOf(itemButtonDown));
  end;

  if itemState^.itemFid <> -1 then
  begin
    itemFrm := art_ptr_lock(itemState^.itemFid, @itemFrmHandle);
    if itemFrm <> nil then
    begin
      width_ := art_frame_width(itemFrm, 0, 0);
      height_ := art_frame_length(itemFrm, 0, 0);
      data_ := art_frame_data(itemFrm, 0, 0);

      v46 := (188 - width_) div 2;
      v47 := (67 - height_) div 2 - 2;

      trans_buf_to_buf(data_, width_, height_, width_,
        @itemButtonUp[0] + 188 * ((67 - height_) div 2) + v46, 188);

      if v47 < 0 then
      begin
        v47 := 0;
        Dec(height_, 2);
      end;

      dark_trans_buf_to_buf(data_, width_, height_, width_,
        @itemButtonDown[0], v46 + 1, v47, 188, 63571);
      art_ptr_unlock(itemFrmHandle);
    end;
  end;

  if not insideInit then
  begin
    intface_update_ammo_lights;
    win_draw_rect(interfaceWindow, @itemButtonRect);

    if itemState^.isDisabled <> 0 then
      win_disable_button(itemButton)
    else
      win_enable_button(itemButton);
  end;

  Result := 0;
end;

// ===================================================================
// intface_redraw_items_callback
// ===================================================================
function intface_redraw_items_callback(a1, a2: Pointer): Integer; cdecl;
begin
  intface_redraw_items;
  Result := 0;
end;

// ===================================================================
// intface_change_fid_callback
// ===================================================================
function intface_change_fid_callback(a1, a2: Pointer): Integer; cdecl;
begin
  intface_fid_is_changing := False;
  Result := 0;
end;

// ===================================================================
// intface_change_fid_animate
// ===================================================================
procedure intface_change_fid_animate(previousWeaponAnimationCode, weaponAnimationCode: Integer);
var
  sfx: PAnsiChar;
  fid_: Integer;
  interfaceBarWasEnabled: Boolean;
begin
  intface_fid_is_changing := True;

  register_clear(obj_dude);
  register_begin(ANIMATION_REQUEST_RESERVED);
  register_object_light(obj_dude, 4, 0);

  if previousWeaponAnimationCode <> 0 then
  begin
    sfx := gsnd_build_character_sfx_name(obj_dude, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
    register_object_play_sfx(obj_dude, sfx, 0);
    register_object_animate(obj_dude, ANIM_PUT_AWAY, 0);
  end;

  register_object_must_call(nil, nil, TAnimationCallback(@intface_redraw_items_callback), -1);

  if weaponAnimationCode <> 0 then
    register_object_take_out(obj_dude, weaponAnimationCode, -1)
  else
  begin
    fid_ := art_id(OBJ_TYPE_CRITTER, obj_dude^.Fid and $FFF, ANIM_STAND, 0, obj_dude^.Rotation + 1);
    register_object_change_fid(obj_dude, fid_, -1);
  end;

  register_object_must_call(nil, nil, TAnimationCallback(@intface_change_fid_callback), -1);

  if register_end = -1 then
    Exit;

  interfaceBarWasEnabled := intfaceEnabled;

  intface_disable;
  gmouse_disable(0);
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_WATCH);

  ensureFpsLimiter;
  while intface_fid_is_changing do
  begin
    localFpsLimiter.Mark;
    if game_user_wants_to_quit <> 0 then
      Break;
    get_input;
    renderPresent;
    localFpsLimiter.Throttle;
  end;

  gmouse_set_cursor(MOUSE_CURSOR_NONE);
  gmouse_enable;

  if interfaceBarWasEnabled then
    intface_enable;
end;

// ===================================================================
// intface_create_end_turn_button
// ===================================================================
function intface_create_end_turn_button: Integer;
var
  fid_: Integer;
begin
  if interfaceWindow = -1 then Exit(-1);
  if not endWindowOpen then Exit(-1);

  fid_ := art_id(OBJ_TYPE_INTERFACE, 105, 0, 0, 0);
  endTurnButtonUpData := art_ptr_lock_data(fid_, 0, 0, @endTurnButtonUpKey);
  if endTurnButtonUpData = nil then Exit(-1);

  fid_ := art_id(OBJ_TYPE_INTERFACE, 106, 0, 0, 0);
  endTurnButtonDownData := art_ptr_lock_data(fid_, 0, 0, @endTurnButtonDownKey);
  if endTurnButtonDownData = nil then Exit(-1);

  endTurnButton := win_register_button(interfaceWindow, 590, 43, 38, 22,
    -1, -1, -1, 32, endTurnButtonUpData, endTurnButtonDownData, nil, 0);
  if endTurnButton = -1 then Exit(-1);

  win_register_button_disable(endTurnButton, endTurnButtonUpData, endTurnButtonUpData, endTurnButtonUpData);
  win_register_button_sound_func(endTurnButton, @gsound_med_butt_press, @gsound_med_butt_release);

  Result := 0;
end;

// ===================================================================
// intface_destroy_end_turn_button
// ===================================================================
function intface_destroy_end_turn_button: Integer;
begin
  if interfaceWindow = -1 then Exit(-1);

  if endTurnButton <> -1 then begin win_delete_button(endTurnButton); endTurnButton := -1; end;
  if endTurnButtonDownData <> nil then begin art_ptr_unlock(endTurnButtonDownKey); endTurnButtonDownKey := nil; endTurnButtonDownData := nil; end;
  if endTurnButtonUpData <> nil then begin art_ptr_unlock(endTurnButtonUpKey); endTurnButtonUpKey := nil; endTurnButtonUpData := nil; end;

  Result := 0;
end;

// ===================================================================
// intface_create_end_combat_button
// ===================================================================
function intface_create_end_combat_button: Integer;
var
  fid_: Integer;
begin
  if interfaceWindow = -1 then Exit(-1);
  if not endWindowOpen then Exit(-1);

  fid_ := art_id(OBJ_TYPE_INTERFACE, 107, 0, 0, 0);
  endCombatButtonUpData := art_ptr_lock_data(fid_, 0, 0, @endCombatButtonUpKey);
  if endCombatButtonUpData = nil then Exit(-1);

  fid_ := art_id(OBJ_TYPE_INTERFACE, 108, 0, 0, 0);
  endCombatButtonDownData := art_ptr_lock_data(fid_, 0, 0, @endCombatButtonDownKey);
  if endCombatButtonDownData = nil then Exit(-1);

  endCombatButton := win_register_button(interfaceWindow, 590, 65, 38, 22,
    -1, -1, -1, 13, endCombatButtonUpData, endCombatButtonDownData, nil, 0);
  if endCombatButton = -1 then Exit(-1);

  win_register_button_disable(endCombatButton, endCombatButtonUpData, endCombatButtonUpData, endCombatButtonUpData);
  win_register_button_sound_func(endCombatButton, @gsound_med_butt_press, @gsound_med_butt_release);

  Result := 0;
end;

// ===================================================================
// intface_destroy_end_combat_button
// ===================================================================
function intface_destroy_end_combat_button: Integer;
begin
  if interfaceWindow = -1 then Exit(-1);

  if endCombatButton <> -1 then begin win_delete_button(endCombatButton); endCombatButton := -1; end;
  if endCombatButtonDownData <> nil then begin art_ptr_unlock(endCombatButtonDownKey); endCombatButtonDownKey := nil; endCombatButtonDownData := nil; end;
  if endCombatButtonUpData <> nil then begin art_ptr_unlock(endCombatButtonUpKey); endCombatButtonUpKey := nil; endCombatButtonUpData := nil; end;

  Result := 0;
end;

// ===================================================================
// intface_draw_ammo_lights
// ===================================================================
procedure intface_draw_ammo_lights(x, ratio: Integer);
var
  dest: PByte;
  index: Integer;
  rect_: TRect;
  localRatio: Integer;
begin
  localRatio := ratio;
  if (localRatio and 1) <> 0 then
    Dec(localRatio);

  dest := interfaceBuffer + 640 * 26 + x;

  index := 70;
  while index > localRatio do
  begin
    dest^ := 14;
    Inc(dest, 640);
    Dec(index);
  end;

  while localRatio > 0 do
  begin
    dest^ := 196;
    Inc(dest, 640);
    dest^ := 14;
    Inc(dest, 640);
    Dec(localRatio, 2);
  end;

  if not insideInit then
  begin
    rect_.ulx := x;
    rect_.uly := 26;
    rect_.lrx := x + 1;
    rect_.lry := 26 + 70;
    win_draw_rect(interfaceWindow, @rect_);
  end;
end;

// ===================================================================
// intface_item_reload
// ===================================================================
function intface_item_reload: Integer;
var
  v0: Boolean;
  sfx: PAnsiChar;
begin
  if interfaceWindow = -1 then
    Exit(-1);

  v0 := False;
  while item_w_try_reload(obj_dude, itemButtonItems[itemCurrentItem].item) <> -1 do
    v0 := True;

  intface_toggle_item_state;
  intface_update_items(False);

  if not v0 then
    Exit(-1);

  sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_READY,
    itemButtonItems[itemCurrentItem].item, HIT_MODE_RIGHT_WEAPON_PRIMARY, nil);
  gsound_play_sfx_file(sfx);

  Result := 0;
end;

// ===================================================================
// intface_rotate_numbers
// ===================================================================
procedure intface_rotate_numbers(x, y, previousValue, value, offset, delay: Integer);
var
  numbers, dest: PByte;
  downSrc, upSrc, minusSrc, plusSrc: PByte;
  signDest, hundredsDest, tensDest, onesDest: PByte;
  normalizedSign, normalizedValue: Integer;
  ones, tens, hundreds: Integer;
  numbersRect: TRect;
  change, v14, v49: Integer;
  val_: Integer;
  prev_: Integer;
begin
  val_ := value;
  prev_ := previousValue;

  if val_ > 999 then val_ := 999
  else if val_ < -999 then val_ := -999;

  numbers := numbersBuffer + offset;
  dest := interfaceBuffer + 640 * y;

  downSrc := numbers + 90;
  upSrc := numbers + 99;
  minusSrc := numbers + 108;
  plusSrc := numbers + 114;

  signDest := dest + x;
  hundredsDest := dest + x + 6;
  tensDest := dest + x + 6 + 9;
  onesDest := dest + x + 6 + 9 * 2;

  if insideInit or (delay = 0) then
  begin
    if val_ >= 0 then normalizedSign := 1
    else normalizedSign := -1;
    normalizedValue := Abs(val_);
  end
  else
  begin
    if prev_ >= 0 then normalizedSign := 1
    else normalizedSign := -1;
    normalizedValue := prev_;
  end;

  ones := normalizedValue mod 10;
  tens := (normalizedValue div 10) mod 10;
  hundreds := normalizedValue div 100;

  buf_to_buf(numbers + 9 * hundreds, 9, 17, 360, hundredsDest, 640);
  buf_to_buf(numbers + 9 * tens, 9, 17, 360, tensDest, 640);
  buf_to_buf(numbers + 9 * ones, 9, 17, 360, onesDest, 640);
  if normalizedSign >= 0 then
    buf_to_buf(plusSrc, 6, 17, 360, signDest, 640)
  else
    buf_to_buf(minusSrc, 6, 17, 360, signDest, 640);

  if not insideInit then
  begin
    numbersRect.ulx := x;
    numbersRect.uly := y;
    numbersRect.lrx := x + 33;
    numbersRect.lry := y + 17;
    win_draw_rect(interfaceWindow, @numbersRect);

    if delay <> 0 then
    begin
      if val_ - prev_ >= 0 then change := 1
      else change := -1;
      if prev_ >= 0 then v14 := 1
      else v14 := -1;
      v49 := change * v14;

      while prev_ <> val_ do
      begin
        if (hundreds or tens or ones) = 0 then
          v49 := 1;

        buf_to_buf(upSrc, 9, 17, 360, onesDest, 640);
        mouse_info;
        gmouse_bk_process;
        renderPresent;
        block_for_tocks(LongWord(delay));
        win_draw_rect(interfaceWindow, @numbersRect);

        ones := ones + v49;

        if (ones > 9) or (ones < 0) then
        begin
          buf_to_buf(upSrc, 9, 17, 360, tensDest, 640);
          mouse_info;
          gmouse_bk_process;
          renderPresent;
          block_for_tocks(LongWord(delay));
          win_draw_rect(interfaceWindow, @numbersRect);

          tens := tens + v49;
          ones := ones - 10 * v49;
          if (tens = 10) or (tens = -1) then
          begin
            buf_to_buf(upSrc, 9, 17, 360, hundredsDest, 640);
            mouse_info;
            gmouse_bk_process;
            block_for_tocks(LongWord(delay));
            win_draw_rect(interfaceWindow, @numbersRect);

            hundreds := hundreds + v49;
            tens := tens - 10 * v49;
            if (hundreds = 10) or (hundreds = -1) then
              hundreds := hundreds - 10 * v49;

            buf_to_buf(downSrc, 9, 17, 360, hundredsDest, 640);
            mouse_info;
            gmouse_bk_process;
            renderPresent;
            block_for_tocks(LongWord(delay));
            win_draw_rect(interfaceWindow, @numbersRect);
          end;

          buf_to_buf(downSrc, 9, 17, 360, tensDest, 640);
          block_for_tocks(LongWord(delay));
          win_draw_rect(interfaceWindow, @numbersRect);
        end;

        buf_to_buf(downSrc, 9, 17, 360, onesDest, 640);
        mouse_info;
        gmouse_bk_process;
        renderPresent;
        block_for_tocks(LongWord(delay));
        win_draw_rect(interfaceWindow, @numbersRect);

        prev_ := prev_ + change;

        buf_to_buf(numbers + 9 * hundreds, 9, 17, 360, hundredsDest, 640);
        buf_to_buf(numbers + 9 * tens, 9, 17, 360, tensDest, 640);
        buf_to_buf(numbers + 9 * ones, 9, 17, 360, onesDest, 640);

        if prev_ >= 0 then
          buf_to_buf(plusSrc, 6, 17, 360, signDest, 640)
        else
          buf_to_buf(minusSrc, 6, 17, 360, signDest, 640);
        mouse_info;
        gmouse_bk_process;
        renderPresent;
        block_for_tocks(LongWord(delay));
        win_draw_rect(interfaceWindow, @numbersRect);
      end;
    end;
  end;
end;

// ===================================================================
// intface_fatal_error
// ===================================================================
function intface_fatal_error(rc: Integer): Integer;
begin
  WriteLn(StdErr, '[INTFACE] intface_fatal_error called with rc=', rc);
  intface_exit;
  Result := rc;
end;

// ===================================================================
// construct_box_bar_win
// ===================================================================
function construct_box_bar_win: Integer;
var
  oldFont: Integer;
  messageList_: TMessageList;
  messageListItem_: TMessageListItem;
  rc, index: Integer;
  path_: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  indicatorBoxFrmHandle: PCacheEntry;
  width_, height_: Integer;
  indicatorBoxFid: Integer;
  indicatorBoxFrmData: PByte;
  indicatorDescription: PIndicatorDescription;
  text_: array[0..1023] of AnsiChar;
  color_, txtY, txtX: Integer;
begin
  oldFont := text_curr;

  WriteLn(StdErr, '[BOX] construct_box_bar_win: start, bar_window=', bar_window);
  if bar_window <> -1 then
    Exit(0);

  rc := 0;
  if not message_init(@messageList_) then
  begin
    WriteLn(StdErr, '[BOX] message_init FAILED');
    rc := -1;
  end;

  StrLFmt(path_, SizeOf(path_) - 1, '%s%s', [msg_path, 'intrface.msg']);
  WriteLn(StdErr, '[BOX] loading message file: ', PAnsiChar(@path_[0]));

  if rc <> -1 then
  begin
    if not message_load(@messageList_, @path_[0]) then
    begin
      WriteLn(StdErr, '[BOX] message_load FAILED for intrface.msg');
      rc := -1;
    end
    else
      WriteLn(StdErr, '[BOX] message_load OK for intrface.msg');
  end;

  if rc = -1 then
  begin
    WriteLn(StdErr, '[BOX] FAILED: Error indicator box messages');
    debug_printf(PAnsiChar(#10'INTRFACE: Error indicator box messages! **'#10));
    Exit(-1);
  end;

  indicatorBoxFid := art_id(OBJ_TYPE_INTERFACE, 126, 0, 0, 0);
  indicatorBoxFrmData := art_lock(indicatorBoxFid, @indicatorBoxFrmHandle, @width_, @height_);
  if indicatorBoxFrmData = nil then
  begin
    WriteLn(StdErr, '[BOX] art_lock FAILED for indicator box fid=', indicatorBoxFid);
    debug_printf(PAnsiChar(#10'INTRFACE: Error initializing indicator box graphics! **'#10));
    message_exit(@messageList_);
    Exit(-1);
  end;
  WriteLn(StdErr, '[BOX] indicator box graphics loaded OK');

  for index := 0 to INDICATOR_COUNT - 1 do
  begin
    indicatorDescription := @bbox[index];
    indicatorDescription^.data := PByte(mem_malloc(INDICATOR_BOX_WIDTH * INDICATOR_BOX_HEIGHT));
    if indicatorDescription^.data = nil then
    begin
      debug_printf(PAnsiChar(#10'INTRFACE: Error initializing indicator box graphics! **'));
      rc := index - 1;
      while rc >= 0 do
      begin
        mem_free(bbox[rc].data);
        Dec(rc);
      end;
      message_exit(@messageList_);
      art_ptr_unlock(indicatorBoxFrmHandle);
      Exit(-1);
    end;
  end;

  text_font(101);

  for index := 0 to INDICATOR_COUNT - 1 do
  begin
    indicatorDescription := @bbox[index];

    StrCopy(@text_[0], getmsg(@messageList_, @messageListItem_, indicatorDescription^.title));

    if indicatorDescription^.isBad then
      color_ := colorTable[31744]
    else
      color_ := colorTable[992];

    Move(indicatorBoxFrmData^, indicatorDescription^.data^, INDICATOR_BOX_WIDTH * INDICATOR_BOX_HEIGHT);

    txtY := (24 - text_height()) div 2;
    txtX := (INDICATOR_BOX_WIDTH - text_width(@text_[0])) div 2;
    text_to_buf(indicatorDescription^.data + INDICATOR_BOX_WIDTH * txtY + txtX,
      @text_[0], INDICATOR_BOX_WIDTH, INDICATOR_BOX_WIDTH, color_);
  end;

  box_status_flag := True;
  refresh_box_bar_win;

  message_exit(@messageList_);
  art_ptr_unlock(indicatorBoxFrmHandle);
  text_font(oldFont);

  Result := 0;
end;

// ===================================================================
// deconstruct_box_bar_win
// ===================================================================
procedure deconstruct_box_bar_win;
var
  index: Integer;
  indicatorBoxDescription: PIndicatorDescription;
begin
  if bar_window <> -1 then
  begin
    win_delete(bar_window);
    bar_window := -1;
  end;

  for index := 0 to INDICATOR_COUNT - 1 do
  begin
    indicatorBoxDescription := @bbox[index];
    if indicatorBoxDescription^.data <> nil then
    begin
      mem_free(indicatorBoxDescription^.data);
      indicatorBoxDescription^.data := nil;
    end;
  end;
end;

// ===================================================================
// reset_box_bar_win
// ===================================================================
procedure reset_box_bar_win;
begin
  if bar_window <> -1 then
  begin
    win_delete(bar_window);
    bar_window := -1;
  end;
  box_status_flag := True;
end;

// ===================================================================
// refresh_box_bar_win
// ===================================================================
function refresh_box_bar_win: Integer;
var
  index, count: Integer;
  interfaceWindowRect: TRect;
begin
  if (interfaceWindow <> -1) and box_status_flag and (not intfaceHidden) then
  begin
    for index := 0 to INDICATOR_SLOTS_COUNT - 1 do
      bboxslot[index] := -1;

    count := 0;

    if is_pc_flag(PC_FLAG_SNEAKING) then
      if add_bar_box(INDICATOR_SNEAK) then
        Inc(count);

    if is_pc_flag(PC_FLAG_LEVEL_UP_AVAILABLE) then
      if add_bar_box(INDICATOR_LEVEL) then
        Inc(count);

    if is_pc_flag(PC_FLAG_ADDICTED) then
      if add_bar_box(INDICATOR_ADDICT) then
        Inc(count);

    if count > 1 then
      libc_qsort(@bboxslot[0], count, SizeOf(Integer), @bbox_comp);

    if bar_window <> -1 then
    begin
      win_delete(bar_window);
      bar_window := -1;
    end;

    if count <> 0 then
    begin
      win_get_rect(interfaceWindow, @interfaceWindowRect);

      bar_window := win_add(interfaceWindowRect.ulx,
        interfaceWindowRect.uly - INDICATOR_BOX_HEIGHT,
        (INDICATOR_BOX_WIDTH - INDICATOR_BOX_CONNECTOR_WIDTH) * count,
        INDICATOR_BOX_HEIGHT,
        colorTable[0], 0);
      draw_bboxes(count);
      win_draw(bar_window);
    end;

    Exit(count);
  end;

  if bar_window <> -1 then
  begin
    win_delete(bar_window);
    bar_window := -1;
  end;

  Result := 0;
end;

// ===================================================================
// bbox_comp
// ===================================================================
function bbox_comp(a, b: Pointer): Integer; cdecl;
var
  indicatorBox1, indicatorBox2: Integer;
begin
  indicatorBox1 := PInteger(a)^;
  indicatorBox2 := PInteger(b)^;

  if indicatorBox1 = indicatorBox2 then
    Result := 0
  else if indicatorBox1 < indicatorBox2 then
    Result := -1
  else
    Result := 1;
end;

// ===================================================================
// draw_bboxes
// ===================================================================
procedure draw_bboxes(count: Integer);
var
  windowWidth: Integer;
  windowBuffer: PByte;
  connections, unconnectedIndicatorsWidth, x, connectorWidthCompensation: Integer;
  index, indicator: Integer;
  indicatorDescription: PIndicatorDescription;
begin
  if bar_window = -1 then Exit;
  if count = 0 then Exit;

  windowWidth := win_width(bar_window);
  windowBuffer := win_get_buf(bar_window);

  connections := 2;
  unconnectedIndicatorsWidth := 0;
  x := 0;
  connectorWidthCompensation := INDICATOR_BOX_CONNECTOR_WIDTH;

  for index := 0 to count - 1 do
  begin
    indicator := bboxslot[index];
    indicatorDescription := @bbox[indicator];

    trans_buf_to_buf(indicatorDescription^.data + connectorWidthCompensation,
      INDICATOR_BOX_WIDTH - connectorWidthCompensation,
      INDICATOR_BOX_HEIGHT,
      INDICATOR_BOX_WIDTH,
      windowBuffer + x, windowWidth);

    connectorWidthCompensation := 0;
    unconnectedIndicatorsWidth := unconnectedIndicatorsWidth + INDICATOR_BOX_WIDTH;
    x := unconnectedIndicatorsWidth - INDICATOR_BOX_CONNECTOR_WIDTH * connections;
    Inc(connections);
  end;
end;

// ===================================================================
// add_bar_box
// ===================================================================
function add_bar_box(indicator: Integer): Boolean;
var
  index: Integer;
begin
  for index := 0 to INDICATOR_SLOTS_COUNT - 1 do
  begin
    if bboxslot[index] = -1 then
    begin
      bboxslot[index] := indicator;
      Exit(True);
    end;
  end;

  debug_printf(PAnsiChar(#10'INTRFACE: no free bar box slots!'#10));
  Result := False;
end;

// ===================================================================
// enable_box_bar_win
// ===================================================================
function enable_box_bar_win: Boolean;
begin
  Result := box_status_flag;
  box_status_flag := True;
  refresh_box_bar_win;
end;

// ===================================================================
// disable_box_bar_win
// ===================================================================
function disable_box_bar_win: Boolean;
begin
  Result := box_status_flag;
  box_status_flag := False;
  refresh_box_bar_win;
end;

// ===================================================================
// Initialization
// ===================================================================
initialization
  interfaceWindow := -1;
  bar_window := -1;
  localFpsLimiter := nil;

end.
