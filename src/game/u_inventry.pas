unit u_inventry;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/inventry.h + inventry.cc
// Inventory UI: main inventory, loot, barter, use-item-on, move-items, set-timer.

interface

uses
  SysUtils, Math,
  u_cache,
  u_object_types,
  u_proto_types,
  u_rect,
  u_art,
  u_color,
  u_item,
  u_stat,
  u_stat_defs,
  u_perk,
  u_skill,
  u_critter;

const
  OFF_59E7BC_COUNT = 12;

  // InventoryWindowCursor
  INVENTORY_WINDOW_CURSOR_HAND  = 0;
  INVENTORY_WINDOW_CURSOR_ARROW = 1;
  INVENTORY_WINDOW_CURSOR_PICK  = 2;
  INVENTORY_WINDOW_CURSOR_MENU  = 3;
  INVENTORY_WINDOW_CURSOR_BLANK = 4;
  INVENTORY_WINDOW_CURSOR_COUNT = 5;

  // InventoryWindowType
  INVENTORY_WINDOW_TYPE_NORMAL      = 0;
  INVENTORY_WINDOW_TYPE_USE_ITEM_ON = 1;
  INVENTORY_WINDOW_TYPE_LOOT        = 2;
  INVENTORY_WINDOW_TYPE_TRADE       = 3;
  INVENTORY_WINDOW_TYPE_MOVE_ITEMS  = 4;
  INVENTORY_WINDOW_TYPE_SET_TIMER   = 5;
  INVENTORY_WINDOW_TYPE_COUNT       = 6;

  // InventoryArrowFrm
  INVENTORY_ARROW_FRM_LEFT_ARROW_UP    = 0;
  INVENTORY_ARROW_FRM_LEFT_ARROW_DOWN  = 1;
  INVENTORY_ARROW_FRM_RIGHT_ARROW_UP   = 2;
  INVENTORY_ARROW_FRM_RIGHT_ARROW_DOWN = 3;
  INVENTORY_ARROW_FRM_COUNT            = 4;

  // Layout constants
  INVENTORY_WINDOW_X = 80;
  INVENTORY_WINDOW_Y = 0;

  INVENTORY_TRADE_WINDOW_X      = 80;
  INVENTORY_TRADE_WINDOW_Y      = 290;
  INVENTORY_TRADE_WINDOW_WIDTH  = 480;
  INVENTORY_TRADE_WINDOW_HEIGHT = 180;

  INVENTORY_LARGE_SLOT_WIDTH  = 90;
  INVENTORY_LARGE_SLOT_HEIGHT = 61;

  INVENTORY_SLOT_WIDTH  = 64;
  INVENTORY_SLOT_HEIGHT = 48;

  INVENTORY_LEFT_HAND_SLOT_X     = 154;
  INVENTORY_LEFT_HAND_SLOT_Y     = 286;
  INVENTORY_LEFT_HAND_SLOT_MAX_X = INVENTORY_LEFT_HAND_SLOT_X + INVENTORY_LARGE_SLOT_WIDTH;
  INVENTORY_LEFT_HAND_SLOT_MAX_Y = INVENTORY_LEFT_HAND_SLOT_Y + INVENTORY_LARGE_SLOT_HEIGHT;

  INVENTORY_RIGHT_HAND_SLOT_X     = 245;
  INVENTORY_RIGHT_HAND_SLOT_Y     = 286;
  INVENTORY_RIGHT_HAND_SLOT_MAX_X = INVENTORY_RIGHT_HAND_SLOT_X + INVENTORY_LARGE_SLOT_WIDTH;
  INVENTORY_RIGHT_HAND_SLOT_MAX_Y = INVENTORY_RIGHT_HAND_SLOT_Y + INVENTORY_LARGE_SLOT_HEIGHT;

  INVENTORY_ARMOR_SLOT_X     = 154;
  INVENTORY_ARMOR_SLOT_Y     = 183;
  INVENTORY_ARMOR_SLOT_MAX_X = INVENTORY_ARMOR_SLOT_X + INVENTORY_LARGE_SLOT_WIDTH;
  INVENTORY_ARMOR_SLOT_MAX_Y = INVENTORY_ARMOR_SLOT_Y + INVENTORY_LARGE_SLOT_HEIGHT;

  INVENTORY_TRADE_SCROLLER_Y       = 30;
  INVENTORY_TRADE_INNER_SCROLLER_Y = 20;

  INVENTORY_TRADE_LEFT_SCROLLER_X = 29;
  INVENTORY_TRADE_LEFT_SCROLLER_Y = INVENTORY_TRADE_SCROLLER_Y;

  INVENTORY_TRADE_RIGHT_SCROLLER_X = 388;
  INVENTORY_TRADE_RIGHT_SCROLLER_Y = INVENTORY_TRADE_SCROLLER_Y;

  INVENTORY_TRADE_INNER_LEFT_SCROLLER_X = 165;
  INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y = INVENTORY_TRADE_INNER_SCROLLER_Y;

  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X = 250;
  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y = INVENTORY_TRADE_INNER_SCROLLER_Y;

  INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_X     = 0;
  INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_Y     = 10;
  INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_MAX_X = INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_X     = 165;
  INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_Y     = 10;
  INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_MAX_X = INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_X     = 250;
  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_Y     = 10;
  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_MAX_X = INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_X     = 395;
  INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_Y     = 10;
  INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_MAX_X = INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_LOOT_LEFT_SCROLLER_X     = 46;
  INVENTORY_LOOT_LEFT_SCROLLER_Y     = 35;
  INVENTORY_LOOT_LEFT_SCROLLER_MAX_X = INVENTORY_LOOT_LEFT_SCROLLER_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_LOOT_RIGHT_SCROLLER_X     = 424;
  INVENTORY_LOOT_RIGHT_SCROLLER_Y     = 35;
  INVENTORY_LOOT_RIGHT_SCROLLER_MAX_X = INVENTORY_LOOT_RIGHT_SCROLLER_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_SCROLLER_X     = 46;
  INVENTORY_SCROLLER_Y     = 35;
  INVENTORY_SCROLLER_MAX_X = INVENTORY_SCROLLER_X + INVENTORY_SLOT_WIDTH;

  INVENTORY_BODY_VIEW_WIDTH  = 60;
  INVENTORY_BODY_VIEW_HEIGHT = 100;

  INVENTORY_PC_BODY_VIEW_X     = 176;
  INVENTORY_PC_BODY_VIEW_Y     = 37;
  INVENTORY_PC_BODY_VIEW_MAX_X = INVENTORY_PC_BODY_VIEW_X + INVENTORY_BODY_VIEW_WIDTH;
  INVENTORY_PC_BODY_VIEW_MAX_Y = INVENTORY_PC_BODY_VIEW_Y + INVENTORY_BODY_VIEW_HEIGHT;

  INVENTORY_LOOT_RIGHT_BODY_VIEW_X = 297;
  INVENTORY_LOOT_RIGHT_BODY_VIEW_Y = 37;

  INVENTORY_LOOT_LEFT_BODY_VIEW_X = 176;
  INVENTORY_LOOT_LEFT_BODY_VIEW_Y = 37;

  INVENTORY_SUMMARY_X     = 297;
  INVENTORY_SUMMARY_Y     = 44;
  INVENTORY_SUMMARY_MAX_X = 440;

  INVENTORY_WINDOW_WIDTH         = 499;
  INVENTORY_USE_ON_WINDOW_WIDTH  = 292;
  INVENTORY_LOOT_WINDOW_WIDTH    = 537;
  INVENTORY_TIMER_WINDOW_WIDTH   = 259;

  INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH  = 640;
  INVENTORY_TRADE_BACKGROUND_WINDOW_HEIGHT = 480;
  INVENTORY_TRADE_WINDOW_OFFSET = (INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH - INVENTORY_TRADE_WINDOW_WIDTH) div 2;

  INVENTORY_SLOT_PADDING = 4;

  INVENTORY_SCROLLER_X_PAD = INVENTORY_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_SCROLLER_Y_PAD = INVENTORY_SCROLLER_Y + INVENTORY_SLOT_PADDING;

  INVENTORY_LOOT_LEFT_SCROLLER_X_PAD  = INVENTORY_LOOT_LEFT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_LOOT_LEFT_SCROLLER_Y_PAD  = INVENTORY_LOOT_LEFT_SCROLLER_Y + INVENTORY_SLOT_PADDING;
  INVENTORY_LOOT_RIGHT_SCROLLER_X_PAD = INVENTORY_LOOT_RIGHT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_LOOT_RIGHT_SCROLLER_Y_PAD = INVENTORY_LOOT_RIGHT_SCROLLER_Y + INVENTORY_SLOT_PADDING;

  INVENTORY_TRADE_LEFT_SCROLLER_X_PAD  = INVENTORY_TRADE_LEFT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_LEFT_SCROLLER_Y_PAD  = INVENTORY_TRADE_LEFT_SCROLLER_Y + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_RIGHT_SCROLLER_X_PAD = INVENTORY_TRADE_RIGHT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_RIGHT_SCROLLER_Y_PAD = INVENTORY_TRADE_RIGHT_SCROLLER_Y + INVENTORY_SLOT_PADDING;

  INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD  = INVENTORY_TRADE_INNER_LEFT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y_PAD  = INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD = INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X + INVENTORY_SLOT_PADDING;
  INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y_PAD = INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y + INVENTORY_SLOT_PADDING;

  INVENTORY_SLOT_WIDTH_PAD  = INVENTORY_SLOT_WIDTH - INVENTORY_SLOT_PADDING * 2;
  INVENTORY_SLOT_HEIGHT_PAD = INVENTORY_SLOT_HEIGHT - INVENTORY_SLOT_PADDING * 2;

  INVENTORY_NORMAL_WINDOW_PC_ROTATION_DELAY = 1000 div 6;

type
  TInventoryPrintItemDescriptionHandler = procedure(str: PAnsiChar);

  PInventoryWindowDescription = ^TInventoryWindowDescription;
  TInventoryWindowDescription = record
    field_0: Integer;
    width: Integer;
    height: Integer;
    x: Integer;
    y: Integer;
  end;

  PInventoryCursorData = ^TInventoryCursorData;
  TInventoryCursorData = record
    frm: PArt;
    frmData: PByte;
    width: Integer;
    height: Integer;
    offsetX: Integer;
    offsetY: Integer;
    frmHandle: PCacheEntry;
  end;

var
  ikey: array[0..OFF_59E7BC_COUNT - 1] of PCacheEntry;

procedure inven_set_dude(obj: PObject; pid: Integer);
procedure inven_reset_dude;
procedure handle_inventory;
function setup_inventory(inventoryWindowType: Integer): Boolean;
procedure exit_inventory(shouldEnableIso: Boolean);
procedure display_inventory(first_item_index, selected_index, inventoryWindowType: Integer);
procedure display_target_inventory(first_item_index, selected_index: Integer; inventory: PInventory; inventoryWindowType: Integer);
procedure display_body(fid, inventoryWindowType: Integer);
function inven_init: Integer;
procedure inven_exit;
procedure inven_set_mouse(cursor: Integer);
procedure inven_hover_on(btn, keyCode: Integer); cdecl;
procedure inven_hover_off(btn, keyCode: Integer); cdecl;
procedure inven_pickup(keyCode, first_item_index: Integer);
procedure switch_hand(a1: PObject; a2: PPObject; a3: PPObject; a4: Integer);
procedure adjust_ac(critter, oldArmor, newArmor: PObject);
procedure adjust_fid;
procedure use_inventory_on(a1: PObject);
function inven_right_hand(critter: PObject): PObject;
function inven_left_hand(critter: PObject): PObject;
function inven_worn(critter: PObject): PObject;
function inven_pid_is_carried(obj: PObject; pid: Integer): Integer;
function inven_pid_is_carried_ptr(obj: PObject; pid: Integer): PObject;
function inven_pid_quantity_carried(obj_: PObject; pid: Integer): Integer;
procedure display_stats;
function inven_find_type(obj: PObject; itemType: Integer; indexPtr: PInteger): PObject;
function inven_find_id(obj: PObject; id: Integer): PObject;
function inven_index_ptr(obj: PObject; a2: Integer): PObject;
function inven_wield(critter, item_: PObject; a3: Integer): Integer;
function inven_unwield(critter: PObject; a2: Integer): Integer;
function inven_from_button(keyCode: Integer; a2: PPObject; a3: PPPObject; a4: PPObject): Integer;
procedure inven_display_msg(str: PAnsiChar);
procedure inven_obj_examine_func(critter, item_: PObject);
procedure inven_action_cursor(eventCode, inventoryWindowType: Integer);
function loot_container(a1, a2: PObject): Integer;
function inven_steal_container(a1, a2: PObject): Integer;
function move_inventory(a1: PObject; a2: Integer; a3: PObject; a4: Boolean): Integer;
procedure barter_inventory(win: Integer; a2, a3, a4: PObject; a5: Integer);
procedure container_enter(keyCode, inventoryWindowType: Integer);
procedure container_exit(keyCode, inventoryWindowType: Integer);
function drop_into_container(a1, a2: PObject; a3: Integer; a4: PPObject; quantity: Integer): Integer;
function drop_ammo_into_weapon(weapon, ammo: PObject; a3: PPObject; quantity, keyCode: Integer): Integer;
procedure draw_amount(value, inventoryWindowType: Integer);
function inven_set_timer(a1: PObject): Integer;

implementation

uses
  u_gnw_types,
  u_gnw,
  u_button,
  u_text,
  u_input,
  u_mouse,
  u_grbuf,
  u_svga,
  u_message,
  u_combat_defs,
  u_object,
  u_proto,
  u_protinst,
  u_combat,
  u_anim,
  u_scripts,
  u_game,
  u_map,
  u_tile,
  u_display,
  u_gsound,
  u_gmouse,
  u_intface,
  u_gdialog,
  u_actions,
  u_bmpdlog,
  u_reaction,
  u_party;

// ---------------------------------------------------------------------------
// Inline helpers
// ---------------------------------------------------------------------------
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// ---------------------------------------------------------------------------
// Type declarations (duplicate types removed - now imported from units above)
// ---------------------------------------------------------------------------

const
  COMPAT_MAX_PATH = 260;

  // Key codes used in the inventory
  KEY_ESCAPE         = 27;
  KEY_RETURN         = 13;
  KEY_ARROW_UP       = 328;
  KEY_ARROW_DOWN     = 336;
  KEY_PAGE_UP        = 329;
  KEY_PAGE_DOWN      = 337;
  KEY_HOME           = 327;
  KEY_END            = 335;
  KEY_CTRL_ARROW_UP    = 397;
  KEY_CTRL_ARROW_DOWN  = 401;
  KEY_CTRL_PAGE_UP     = 398;
  KEY_CTRL_PAGE_DOWN   = 402;
  KEY_CTRL_Q           = 17;
  KEY_CTRL_X           = 24;
  KEY_F10              = 324;
  KEY_UPPERCASE_A      = 65;
  KEY_UPPERCASE_I      = 73;
  KEY_LOWERCASE_I      = 105;
  KEY_LOWERCASE_T      = 116;
  KEY_LOWERCASE_M      = 109;
  KEY_0                = 48;
  KEY_9                = 57;
  KEY_BACKSPACE        = 8;

  // Mouse event flags
  MOUSE_EVENT_LEFT_BUTTON_DOWN        = $01;
  MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT = $02;
  MOUSE_EVENT_LEFT_BUTTON_REPEAT      = $04;
  MOUSE_EVENT_LEFT_BUTTON_UP          = $10;
  MOUSE_EVENT_RIGHT_BUTTON_DOWN       = $20;
  MOUSE_EVENT_WHEEL                   = $0100;

  // Window flags
  WINDOW_MODAL       = $02;
  WINDOW_MOVE_ON_TOP = $04;

  // Button flags
  BUTTON_FLAG_TRANSPARENT = $20;

  // HitMode
  HIT_MODE_PUNCH                  = 0;
  HIT_MODE_LEFT_WEAPON_PRIMARY    = 3;
  HIT_MODE_RIGHT_WEAPON_PRIMARY   = 0;

  // HitLocation
  HIT_LOCATION_TORSO = 3;

  // Hand constants
  HAND_RIGHT = 1;

  // Animation IDs
  ANIM_STAND    = 0;
  ANIM_PUT_AWAY = 15;

  ANIMATION_REQUEST_RESERVED = $100;

  // LIGHT
  LIGHT_LEVEL_MAX = $10000;

  // Game states
  GAME_STATE_5 = 5;

  // Mouse cursor
  MOUSE_CURSOR_ARROW = 0;

  // Weapon sound effects
  WEAPON_SOUND_EFFECT_READY = 1;

  // Character sound effects
  CHARACTER_SOUND_EFFECT_UNUSED = 0;

  // NPC reaction
  NPC_REACTION_BAD     = 0;
  NPC_REACTION_NEUTRAL = 1;
  NPC_REACTION_GOOD    = 2;

  // Game mouse action menu items
  GAME_MOUSE_ACTION_MENU_ITEM_LOOK    = 0;
  GAME_MOUSE_ACTION_MENU_ITEM_USE     = 1;
  GAME_MOUSE_ACTION_MENU_ITEM_DROP    = 2;
  GAME_MOUSE_ACTION_MENU_ITEM_CANCEL  = 3;
  GAME_MOUSE_ACTION_MENU_ITEM_UNLOAD  = 8;

  // ROLL
  ROLL_SUCCESS = 2;

  // SCRIPT_PROC
  SCRIPT_PROC_PICKUP = 12;

// ---------------------------------------------------------------------------
// External declarations kept (cdecl varargs / not yet exported)
// ---------------------------------------------------------------------------
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';



// ---------------------------------------------------------------------------
// Module-level variables
// ---------------------------------------------------------------------------
var
  inven_cur_disp: Integer = 6;
  inven_dude: PObject = nil;
  inven_pid: Integer = -1;
  inven_is_initialized: Boolean = False;
  inven_display_msg_line: Integer = 1;

  iscr_data: array[0..INVENTORY_WINDOW_TYPE_COUNT - 1] of TInventoryWindowDescription = (
    (field_0: 48;  width: INVENTORY_WINDOW_WIDTH;         height: 377; x: 80;  y: 0),
    (field_0: 113; width: INVENTORY_USE_ON_WINDOW_WIDTH;  height: 376; x: 80;  y: 0),
    (field_0: 114; width: INVENTORY_LOOT_WINDOW_WIDTH;    height: 376; x: 80;  y: 0),
    (field_0: 111; width: INVENTORY_TRADE_WINDOW_WIDTH;   height: 180; x: 80;  y: 290),
    (field_0: 305; width: INVENTORY_TIMER_WINDOW_WIDTH;   height: 162; x: 140; y: 80),
    (field_0: 305; width: INVENTORY_TIMER_WINDOW_WIDTH;   height: 162; x: 140; y: 80)
  );

  dropped_explosive: Boolean = False;

  mt_key: array[0..7] of PCacheEntry;
  target_stack_offset: array[0..9] of Integer;
  inventry_message_file: TMessageList;
  target_stack: array[0..9] of PObject;
  stack_offset: array[0..9] of Integer;
  stack: array[0..9] of PObject;
  mt_wid: Integer;
  barter_mod: Integer;
  btable_offset: Integer;
  ptable_offset: Integer;
  ptable_pud: PInventory;
  imdata: array[0..INVENTORY_WINDOW_CURSOR_COUNT - 1] of TInventoryCursorData;
  ptable: PObject;
  display_msg_handler: TDisplayPrintProc;
  im_value: Integer;
  immode: Integer;
  btable: PObject;
  target_curr_stack: Integer;
  btable_pud: PInventory;
  inven_ui_was_disabled: Boolean;
  i_worn: PObject;
  i_lhand: PObject;
  i_fid: Integer;
  pud: PInventory;
  i_wid: Integer;
  i_rhand: PObject;
  curr_stack: Integer;
  i_wid_max_y: Integer;
  i_wid_max_x: Integer;
  target_pud: PInventory;
  barter_back_win: Integer;

  // Static locals promoted to module level
  display_body_ticker: LongWord = 0;
  display_body_curr_rot: Integer = 0;
  inven_hover_on_last_target: PObject = nil;

// Forward declarations for static functions
function inventry_msg_load: Integer; forward;
function inventry_msg_unload: Integer; forward;
procedure display_inventory_info(item_: PObject; quantity: Integer; dest: PByte; pitch: Integer; a5: Boolean); forward;
function barter_compute_value(buyer, seller: PObject): Integer; forward;
function barter_attempt_transaction(a1, a2, a3, a4: PObject): Integer; forward;
procedure barter_move_inventory(a1: PObject; quantity, a3, a4: Integer; a5, a6: PObject; a7: Boolean); forward;
procedure barter_move_from_table_inventory(a1: PObject; quantity, a3: Integer; a4, a5: PObject; a6: Boolean); forward;
procedure display_table_inventories(win: Integer; a2, a3: PObject; a4: Integer); forward;
function do_move_timer(inventoryWindowType: Integer; item_: PObject; max: Integer): Integer; forward;
function setup_move_timer_win(inventoryWindowType: Integer; item_: PObject): Integer; forward;
function exit_move_timer_win(inventoryWindowType: Integer): Integer; forward;

// ========================================================================
// IMPLEMENTATION OF ALL FUNCTIONS
// ========================================================================

procedure inven_set_dude(obj: PObject; pid: Integer);
begin
  inven_dude := obj;
  inven_pid := pid;
end;

procedure inven_reset_dude;
begin
  inven_dude := obj_dude;
  inven_pid := $1000000;
end;

function inventry_msg_load: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if not message_init(@inventry_message_file) then
    Exit(-1);

  StrLFmt(path, COMPAT_MAX_PATH - 1, '%s%s', [msg_path, PAnsiChar('inventry.msg')]);
  if not message_load(@inventry_message_file, @path[0]) then
    Exit(-1);

  Result := 0;
end;

function inventry_msg_unload: Integer;
begin
  message_exit(@inventry_message_file);
  Result := 0;
end;

procedure handle_inventory;
var
  oldArmor, newArmor: PObject;
  isoWasEnabled: Boolean;
  keyCode: Integer;
  actionPointsRequired: Integer;
  messageListItem: TMessageListItem;
  rect_: TRect;
  wheelX, wheelY: Integer;
begin
  if isInCombat() then
  begin
    if combat_whose_turn() <> inven_dude then
      Exit;
  end;

  if inven_init() = -1 then
    Exit;

  if isInCombat() then
  begin
    if inven_dude = obj_dude then
    begin
      actionPointsRequired := 4 - perk_level(PERK_QUICK_POCKETS);
      if (actionPointsRequired > 0) and (actionPointsRequired > obj_dude^.Data.AsData.Critter.Combat.Ap) then
      begin
        messageListItem.num := 19;
        if message_search(@inventry_message_file, @messageListItem) then
          display_print(messageListItem.text);
        inven_exit;
        Exit;
      end;
      obj_dude^.Data.AsData.Critter.Combat.Ap := obj_dude^.Data.AsData.Critter.Combat.Ap - actionPointsRequired;
      intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);
    end;
  end;

  oldArmor := inven_worn(inven_dude);
  isoWasEnabled := setup_inventory(INVENTORY_WINDOW_TYPE_NORMAL);
  register_clear(inven_dude);
  display_stats;
  display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_NORMAL);
  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);

  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;
    if (keyCode = KEY_ESCAPE) or (keyCode = KEY_UPPERCASE_I) or (keyCode = KEY_LOWERCASE_I) then
      Break;

    if game_user_wants_to_quit <> 0 then
      Break;

    display_body(-1, INVENTORY_WINDOW_TYPE_NORMAL);

    if game_state() = GAME_STATE_5 then
      Break;

    if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) then
      game_quit_with_confirm
    else if keyCode = KEY_ARROW_UP then
    begin
      if stack_offset[curr_stack] > 0 then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_NORMAL);
      end;
    end
    else if keyCode = KEY_ARROW_DOWN then
    begin
      if inven_cur_disp + stack_offset[curr_stack] < pud^.Length then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_NORMAL);
      end;
    end
    else if keyCode = 2500 then
      container_exit(keyCode, INVENTORY_WINDOW_TYPE_NORMAL)
    else
    begin
      if (mouse_get_buttons and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
      begin
        if immode = INVENTORY_WINDOW_CURSOR_HAND then
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW)
        else if immode = INVENTORY_WINDOW_CURSOR_ARROW then
        begin
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
          display_stats;
          win_draw(i_wid);
        end;
      end
      else if (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
      begin
        if (keyCode >= 1000) and (keyCode <= 1008) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_NORMAL)
          else
            inven_pickup(keyCode, stack_offset[curr_stack]);
        end;
      end
      else if (mouse_get_buttons and MOUSE_EVENT_WHEEL) <> 0 then
      begin
        if mouseHitTestInWindow(i_wid, INVENTORY_SCROLLER_X, INVENTORY_SCROLLER_Y, INVENTORY_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_SCROLLER_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if stack_offset[curr_stack] > 0 then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_NORMAL);
            end;
          end
          else if wheelY < 0 then
          begin
            if inven_cur_disp + stack_offset[curr_stack] < pud^.Length then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_NORMAL);
            end;
          end;
        end;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  inven_dude := stack[0];
  adjust_fid;

  if inven_dude = obj_dude then
  begin
    obj_change_fid(inven_dude, i_fid, @rect_);
    tile_refresh_rect(@rect_, inven_dude^.Elevation);
  end;

  newArmor := inven_worn(inven_dude);
  if inven_dude = obj_dude then
  begin
    if oldArmor <> newArmor then
      intface_update_ac(True);
  end;

  exit_inventory(isoWasEnabled);
  inven_exit;

  if inven_dude = obj_dude then
    intface_update_items(False);
end;

function setup_inventory(inventoryWindowType: Integer): Boolean;
var
  windowDescription: PInventoryWindowDescription;
  inventoryWindowX, inventoryWindowY: Integer;
  dest, src: PByte;
  backgroundFid, btn, fid: Integer;
  backgroundFrmHandle: PCacheEntry;
  backgroundFrmData: PByte;
  buttonUpData, buttonDownData: PByte;
  index: Integer;
  y1, y2: Integer;
  inventoryItem: PInventoryItem;
  item_: PObject;
begin
  dropped_explosive := False;
  curr_stack := 0;
  stack_offset[0] := 0;
  inven_cur_disp := 6;
  pud := @inven_dude^.Data.AsData.Inventory;
  stack[0] := inven_dude;

  if inventoryWindowType <= INVENTORY_WINDOW_TYPE_LOOT then
  begin
    windowDescription := @iscr_data[inventoryWindowType];

    if screenGetWidth <> 640 then
      inventoryWindowX := (screenGetWidth - windowDescription^.width) div 2
    else
      inventoryWindowX := INVENTORY_WINDOW_X;
    if screenGetHeight <> 480 then
      inventoryWindowY := (screenGetHeight - windowDescription^.height) div 2
    else
      inventoryWindowY := INVENTORY_WINDOW_Y;

    i_wid := win_add(inventoryWindowX, inventoryWindowY,
      windowDescription^.width, windowDescription^.height, 257,
      WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
    i_wid_max_x := windowDescription^.width + inventoryWindowX;
    i_wid_max_y := windowDescription^.height + inventoryWindowY;

    dest := win_get_buf(i_wid);
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, windowDescription^.field_0, 0, 0, 0);
    backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
    if backgroundFrmData <> nil then
    begin
      buf_to_buf(backgroundFrmData, windowDescription^.width, windowDescription^.height,
        windowDescription^.width, dest, windowDescription^.width);
      art_ptr_unlock(backgroundFrmHandle);
    end;

    display_msg_handler := @display_print;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    if barter_back_win = -1 then
      Halt(1);

    inven_cur_disp := 3;

    inventoryWindowX := (screenGetWidth - INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH) div 2 + INVENTORY_TRADE_WINDOW_X;
    inventoryWindowY := (screenGetHeight - INVENTORY_TRADE_BACKGROUND_WINDOW_HEIGHT) div 2 + INVENTORY_TRADE_WINDOW_Y;
    i_wid := win_add(inventoryWindowX, inventoryWindowY,
      INVENTORY_TRADE_WINDOW_WIDTH, INVENTORY_TRADE_WINDOW_HEIGHT, 257, 0);
    i_wid_max_x := inventoryWindowX + INVENTORY_TRADE_WINDOW_WIDTH;
    i_wid_max_y := inventoryWindowY + INVENTORY_TRADE_WINDOW_HEIGHT;

    dest := win_get_buf(i_wid);
    src := win_get_buf(barter_back_win);
    buf_to_buf(src + INVENTORY_TRADE_WINDOW_X,
      INVENTORY_TRADE_WINDOW_WIDTH, INVENTORY_TRADE_WINDOW_HEIGHT,
      INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH, dest, INVENTORY_TRADE_WINDOW_WIDTH);

    display_msg_handler := @gdialog_display_msg;
  end;

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
  begin
    for index := 0 to inven_cur_disp - 1 do
    begin
      btn := win_register_button(i_wid,
        INVENTORY_LOOT_LEFT_SCROLLER_X,
        INVENTORY_LOOT_LEFT_SCROLLER_Y + index * INVENTORY_SLOT_HEIGHT,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        1000 + index, -1, 1000 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);
    end;

    for index := 0 to 5 do
    begin
      btn := win_register_button(i_wid,
        INVENTORY_LOOT_RIGHT_SCROLLER_X,
        INVENTORY_LOOT_RIGHT_SCROLLER_Y + index * INVENTORY_SLOT_HEIGHT,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        2000 + index, -1, 2000 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    y1 := INVENTORY_TRADE_SCROLLER_Y;
    y2 := INVENTORY_TRADE_INNER_SCROLLER_Y;

    for index := 0 to inven_cur_disp - 1 do
    begin
      btn := win_register_button(i_wid, INVENTORY_TRADE_LEFT_SCROLLER_X, y1,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        1000 + index, -1, 1000 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

      btn := win_register_button(i_wid, INVENTORY_TRADE_RIGHT_SCROLLER_X, y1,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        2000 + index, -1, 2000 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

      btn := win_register_button(i_wid, INVENTORY_TRADE_INNER_LEFT_SCROLLER_X, y2,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        2300 + index, -1, 2300 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

      btn := win_register_button(i_wid, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X, y2,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        2400 + index, -1, 2400 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

      y1 := y1 + INVENTORY_SLOT_HEIGHT;
      y2 := y2 + INVENTORY_SLOT_HEIGHT;
    end;
  end
  else
  begin
    for index := 0 to inven_cur_disp - 1 do
    begin
      btn := win_register_button(i_wid,
        INVENTORY_SCROLLER_X,
        INVENTORY_SLOT_HEIGHT * index + INVENTORY_SCROLLER_Y,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT,
        1000 + index, -1, 1000 + index, -1, nil, nil, nil, 0);
      if btn <> -1 then
        win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);
    end;
  end;

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL then
  begin
    btn := win_register_button(i_wid,
      INVENTORY_RIGHT_HAND_SLOT_X, INVENTORY_RIGHT_HAND_SLOT_Y,
      INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT,
      1006, -1, 1006, -1, nil, nil, nil, 0);
    if btn <> -1 then
      win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

    btn := win_register_button(i_wid,
      INVENTORY_LEFT_HAND_SLOT_X, INVENTORY_LEFT_HAND_SLOT_Y,
      INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT,
      1007, -1, 1007, -1, nil, nil, nil, 0);
    if btn <> -1 then
      win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);

    btn := win_register_button(i_wid,
      INVENTORY_ARMOR_SLOT_X, INVENTORY_ARMOR_SLOT_Y,
      INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT,
      1008, -1, 1008, -1, nil, nil, nil, 0);
    if btn <> -1 then
      win_register_button_func(btn, @inven_hover_on, @inven_hover_off, nil, nil);
  end;

  FillChar(ikey, SizeOf(ikey), 0);

  fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[0]);
  fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[1]);

  if (buttonUpData <> nil) and (buttonDownData <> nil) then
  begin
    btn := -1;
    case inventoryWindowType of
      INVENTORY_WINDOW_TYPE_NORMAL:
        btn := win_register_button(i_wid, 437, 329, 15, 16, -1, -1, -1, KEY_ESCAPE,
          buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
      INVENTORY_WINDOW_TYPE_USE_ITEM_ON:
        btn := win_register_button(i_wid, 233, 328, 15, 16, -1, -1, -1, KEY_ESCAPE,
          buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
      INVENTORY_WINDOW_TYPE_LOOT:
        btn := win_register_button(i_wid, 288, 328, 15, 16, -1, -1, -1, KEY_ESCAPE,
          buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
    end;
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
  end;

  // Up/down scroll arrows - trade vs normal
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 100, 0, 0, 0);
    fid := art_id(OBJ_TYPE_INTERFACE, fid, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[2]);
    fid := art_id(OBJ_TYPE_INTERFACE, 101, 0, 0, 0);
    fid := art_id(OBJ_TYPE_INTERFACE, fid, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[3]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      btn := win_register_button(i_wid, 109, 56, 23, 24, -1, -1, KEY_ARROW_UP, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      btn := win_register_button(i_wid, 342, 56, 23, 24, -1, -1, KEY_CTRL_ARROW_UP, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
    end;
  end
  else
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 49, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[2]);
    fid := art_id(OBJ_TYPE_INTERFACE, 50, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[3]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      if inventoryWindowType <> INVENTORY_WINDOW_TYPE_TRADE then
      begin
        btn := win_register_button(i_wid, 128, 39, 22, 23, -1, -1, KEY_ARROW_UP, -1,
          buttonUpData, buttonDownData, nil, 0);
        if btn <> -1 then
          win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
      end;

      if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
      begin
        btn := win_register_button(i_wid, 379, 39, 22, 23, -1, -1, KEY_CTRL_ARROW_UP, -1,
          buttonUpData, buttonDownData, nil, 0);
        if btn <> -1 then
          win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
      end;
    end;
  end;

  // Down arrows
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 93, 0, 0, 0);
    fid := art_id(OBJ_TYPE_INTERFACE, fid, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[5]);
    fid := art_id(OBJ_TYPE_INTERFACE, 94, 0, 0, 0);
    fid := art_id(OBJ_TYPE_INTERFACE, fid, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[6]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      btn := win_register_button(i_wid, 109, 82, 24, 25, -1, -1, KEY_ARROW_DOWN, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      btn := win_register_button(i_wid, 342, 82, 24, 25, -1, -1, KEY_CTRL_ARROW_DOWN, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      win_register_button(barter_back_win, 15, 25, INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, -1, -1, 2500, -1, nil, nil, nil, 0);
      win_register_button(barter_back_win, 560, 25, INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, -1, -1, 2501, -1, nil, nil, nil, 0);
    end;
  end
  else
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 51, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[5]);
    fid := art_id(OBJ_TYPE_INTERFACE, 52, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[6]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      btn := win_register_button(i_wid, 128, 62, 22, 23, -1, -1, KEY_ARROW_DOWN, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
      begin
        win_register_button(i_wid, INVENTORY_LOOT_LEFT_BODY_VIEW_X, INVENTORY_LOOT_LEFT_BODY_VIEW_Y,
          INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, -1, -1, 2500, -1, nil, nil, nil, 0);

        btn := win_register_button(i_wid, 379, 62, 22, 23, -1, -1, KEY_CTRL_ARROW_DOWN, -1,
          buttonUpData, buttonDownData, nil, 0);
        if btn <> -1 then
          win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

        win_register_button(i_wid, INVENTORY_LOOT_RIGHT_BODY_VIEW_X, INVENTORY_LOOT_RIGHT_BODY_VIEW_Y,
          INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, -1, -1, 2501, -1, nil, nil, nil, 0);
      end
      else
      begin
        win_register_button(i_wid, INVENTORY_PC_BODY_VIEW_X, INVENTORY_PC_BODY_VIEW_Y,
          INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, -1, -1, 2500, -1, nil, nil, nil, 0);
      end;
    end;
  end;

  // Trade: offered inventory buttons
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 49, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[8]);
    fid := art_id(OBJ_TYPE_INTERFACE, 50, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[9]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      btn := win_register_button(i_wid, 128, 113, 22, 23, -1, -1, KEY_PAGE_UP, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      btn := win_register_button(i_wid, 333, 113, 22, 23, -1, -1, KEY_CTRL_PAGE_UP, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
    end;

    fid := art_id(OBJ_TYPE_INTERFACE, 51, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid, 0, 0, @ikey[8]);
    fid := art_id(OBJ_TYPE_INTERFACE, 52, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid, 0, 0, @ikey[9]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      btn := win_register_button(i_wid, 128, 136, 22, 23, -1, -1, KEY_PAGE_DOWN, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      btn := win_register_button(i_wid, 333, 136, 22, 23, -1, -1, KEY_CTRL_PAGE_DOWN, -1,
        buttonUpData, buttonDownData, nil, 0);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
    end;
  end;

  i_rhand := nil;
  i_worn := nil;
  i_lhand := nil;

  index := 0;
  while index < pud^.Length do
  begin
    inventoryItem := @pud^.Items[index];
    item_ := inventoryItem^.Item;
    if (item_^.Flags and OBJECT_IN_LEFT_HAND) <> 0 then
    begin
      if (item_^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
        i_rhand := item_;
      i_lhand := item_;
    end
    else if (item_^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
      i_rhand := item_
    else if (item_^.Flags and OBJECT_WORN) <> 0 then
      i_worn := item_;
    Inc(index);
  end;

  if i_lhand <> nil then
    item_remove_mult(inven_dude, i_lhand, 1);

  if (i_rhand <> nil) and (i_rhand <> i_lhand) then
    item_remove_mult(inven_dude, i_rhand, 1);

  if i_worn <> nil then
    item_remove_mult(inven_dude, i_worn, 1);

  adjust_fid;

  Result := map_disable_bk_processes;
  gmouse_disable(0);
end;

procedure exit_inventory(shouldEnableIso: Boolean);
var
  v1: TAttack;
  v2: PObject;
  v3: TSTRUCT_664980;
  index: Integer;
  critter: PObject;
  rect_: TRect;
begin
  inven_dude := stack[0];

  if i_lhand <> nil then
  begin
    i_lhand^.Flags := i_lhand^.Flags or OBJECT_IN_LEFT_HAND;
    if i_lhand = i_rhand then
      i_lhand^.Flags := i_lhand^.Flags or OBJECT_IN_RIGHT_HAND;
    item_add_force(inven_dude, i_lhand, 1);
  end;

  if (i_rhand <> nil) and (i_rhand <> i_lhand) then
  begin
    i_rhand^.Flags := i_rhand^.Flags or OBJECT_IN_RIGHT_HAND;
    item_add_force(inven_dude, i_rhand, 1);
  end;

  if i_worn <> nil then
  begin
    i_worn^.Flags := i_worn^.Flags or OBJECT_WORN;
    item_add_force(inven_dude, i_worn, 1);
  end;

  i_rhand := nil;
  i_worn := nil;
  i_lhand := nil;

  for index := 0 to OFF_59E7BC_COUNT - 1 do
    art_ptr_unlock(ikey[index]);

  if shouldEnableIso then
    map_enable_bk_processes;

  win_delete(i_wid);
  gmouse_enable;

  if dropped_explosive then
  begin
    combat_ctd_init(@v1, obj_dude, nil, HIT_MODE_PUNCH, HIT_LOCATION_TORSO);
    v1.attackerFlags := DAM_HIT;
    v1.tile := obj_dude^.Tile;
    compute_explosion_on_extras(@v1, 0, False, 1);

    v2 := nil;
    index := 0;
    while index < v1.extrasLength do
    begin
      critter := v1.extras[index];
      if (critter <> obj_dude) and
         (critter^.Data.AsData.Critter.Combat.Team <> obj_dude^.Data.AsData.Critter.Combat.Team) and
         (stat_result(critter, Integer(STAT_PERCEPTION), 0, nil) >= ROLL_SUCCESS) then
      begin
        critter_set_who_hit_me(critter, obj_dude);
        if v2 = nil then
          v2 := critter;
      end;
      Inc(index);
    end;

    if v2 <> nil then
    begin
      if not isInCombat() then
      begin
        v3.attacker := v2;
        v3.defender := obj_dude;
        v3.actionPointsBonus := 0;
        v3.accuracyBonus := 0;
        v3.damageBonus := 0;
        v3.minDamage := 0;
        v3.maxDamage := MaxInt;
        v3.field_1C := 0;
        scripts_request_combat(@v3);
      end;
    end;

    dropped_explosive := False;
  end;
end;

procedure display_inventory(first_item_index, selected_index, inventoryWindowType: Integer);
var
  windowBuffer, backgroundFrmData, data: PByte;
  pitch, backgroundFid, offset, inventoryFid: Integer;
  backgroundFrmHandle, itemBackgroundFrmHandle, key: PCacheEntry;
  itemBackgroundFrm: PArt;
  widthLoc, heightLoc: Integer;
  y, index: Integer;
  inventoryItem: PInventoryItem;
  formattedText: array[0..19] of AnsiChar;
  oldFont: Integer;
  color_: Byte;
  object_: PObject;
  carryWeight, inventoryWeight, tw: Integer;
begin
  windowBuffer := win_get_buf(i_wid);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL then
  begin
    pitch := INVENTORY_WINDOW_WIDTH;
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, 48, 0, 0, 0);
    backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
    if backgroundFrmData <> nil then
    begin
      buf_to_buf(backgroundFrmData + pitch * INVENTORY_SCROLLER_Y + INVENTORY_SCROLLER_X,
        INVENTORY_SLOT_WIDTH, inven_cur_disp * INVENTORY_SLOT_HEIGHT, pitch,
        windowBuffer + pitch * INVENTORY_SCROLLER_Y + INVENTORY_SCROLLER_X, pitch);

      buf_to_buf(backgroundFrmData + pitch * INVENTORY_ARMOR_SLOT_Y + INVENTORY_ARMOR_SLOT_X,
        INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT, pitch,
        windowBuffer + pitch * INVENTORY_ARMOR_SLOT_Y + INVENTORY_ARMOR_SLOT_X, pitch);

      if (i_lhand <> nil) and (i_lhand = i_rhand) then
      begin
        backgroundFid := art_id(OBJ_TYPE_INTERFACE, 32, 0, 0, 0);
        itemBackgroundFrm := art_ptr_lock(backgroundFid, @itemBackgroundFrmHandle);
        if itemBackgroundFrm <> nil then
        begin
          data := art_frame_data(itemBackgroundFrm, 0, 0);
          widthLoc := art_frame_width(itemBackgroundFrm, 0, 0);
          heightLoc := art_frame_length(itemBackgroundFrm, 0, 0);
          buf_to_buf(data, widthLoc, heightLoc, widthLoc,
            windowBuffer + pitch * 284 + 152, pitch);
          art_ptr_unlock(itemBackgroundFrmHandle);
        end;
      end
      else
      begin
        buf_to_buf(backgroundFrmData + pitch * INVENTORY_LEFT_HAND_SLOT_Y + INVENTORY_LEFT_HAND_SLOT_X,
          INVENTORY_LARGE_SLOT_WIDTH * 2, INVENTORY_LARGE_SLOT_HEIGHT, pitch,
          windowBuffer + pitch * INVENTORY_LEFT_HAND_SLOT_Y + INVENTORY_LEFT_HAND_SLOT_X, pitch);
      end;

      art_ptr_unlock(backgroundFrmHandle);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_USE_ITEM_ON then
  begin
    pitch := INVENTORY_USE_ON_WINDOW_WIDTH;
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, 113, 0, 0, 0);
    backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
    if backgroundFrmData <> nil then
    begin
      buf_to_buf(backgroundFrmData + pitch * 35 + 44, 64, inven_cur_disp * 48, pitch,
        windowBuffer + pitch * 35 + 44, pitch);
      art_ptr_unlock(backgroundFrmHandle);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
  begin
    pitch := INVENTORY_LOOT_WINDOW_WIDTH;
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
    backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
    if backgroundFrmData <> nil then
    begin
      buf_to_buf(backgroundFrmData + pitch * INVENTORY_SCROLLER_Y + INVENTORY_SCROLLER_X,
        INVENTORY_SLOT_WIDTH, inven_cur_disp * INVENTORY_SLOT_HEIGHT, pitch,
        windowBuffer + pitch * INVENTORY_SCROLLER_Y + INVENTORY_SCROLLER_X, pitch);
      art_ptr_unlock(backgroundFrmHandle);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    pitch := INVENTORY_TRADE_WINDOW_WIDTH;
    windowBuffer := win_get_buf(i_wid);
    buf_to_buf(win_get_buf(barter_back_win) + INVENTORY_TRADE_LEFT_SCROLLER_Y * INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH + INVENTORY_TRADE_LEFT_SCROLLER_X + INVENTORY_TRADE_WINDOW_OFFSET,
      INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT * inven_cur_disp,
      INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH,
      windowBuffer + pitch * INVENTORY_TRADE_LEFT_SCROLLER_Y + INVENTORY_TRADE_LEFT_SCROLLER_X, pitch);
  end
  else
  begin
    pitch := INVENTORY_WINDOW_WIDTH; // fallback
  end;

  y := 0;
  index := 0;
  while (index + first_item_index < pud^.Length) and (index < inven_cur_disp) do
  begin
    if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
      offset := pitch * (y + INVENTORY_TRADE_LEFT_SCROLLER_Y_PAD) + INVENTORY_TRADE_LEFT_SCROLLER_X_PAD
    else
      offset := pitch * (y + INVENTORY_LOOT_LEFT_SCROLLER_Y_PAD) + INVENTORY_SCROLLER_X_PAD;

    inventoryItem := @pud^.Items[index + first_item_index];
    inventoryFid := item_inv_fid(inventoryItem^.Item);
    scale_art(inventoryFid, windowBuffer + offset, INVENTORY_SLOT_WIDTH_PAD, INVENTORY_SLOT_HEIGHT_PAD, pitch);

    if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
      offset := pitch * (y + INVENTORY_LOOT_LEFT_SCROLLER_Y_PAD) + INVENTORY_LOOT_LEFT_SCROLLER_X_PAD
    else if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
      offset := pitch * (y + INVENTORY_TRADE_LEFT_SCROLLER_Y_PAD) + INVENTORY_TRADE_LEFT_SCROLLER_X_PAD
    else
      offset := pitch * (y + INVENTORY_SCROLLER_Y_PAD) + INVENTORY_SCROLLER_X_PAD;

    display_inventory_info(inventoryItem^.Item, inventoryItem^.Quantity, windowBuffer + offset, pitch, index = selected_index);

    y := y + INVENTORY_SLOT_HEIGHT;
    Inc(index);
  end;

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL then
  begin
    if i_rhand <> nil then
    begin
      if i_rhand = i_lhand then
        widthLoc := INVENTORY_LARGE_SLOT_WIDTH * 2
      else
        widthLoc := INVENTORY_LARGE_SLOT_WIDTH;
      inventoryFid := item_inv_fid(i_rhand);
      scale_art(inventoryFid, windowBuffer + 499 * INVENTORY_RIGHT_HAND_SLOT_Y + INVENTORY_RIGHT_HAND_SLOT_X, widthLoc, INVENTORY_LARGE_SLOT_HEIGHT, 499);
    end;

    if (i_lhand <> nil) and (i_lhand <> i_rhand) then
    begin
      inventoryFid := item_inv_fid(i_lhand);
      scale_art(inventoryFid, windowBuffer + 499 * INVENTORY_LEFT_HAND_SLOT_Y + INVENTORY_LEFT_HAND_SLOT_X, INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT, 499);
    end;

    if i_worn <> nil then
    begin
      inventoryFid := item_inv_fid(i_worn);
      scale_art(inventoryFid, windowBuffer + 499 * INVENTORY_ARMOR_SLOT_Y + INVENTORY_ARMOR_SLOT_X, INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT, 499);
    end;
  end;

  // Show items weight in loot mode
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
  begin
    oldFont := text_curr;
    text_font(101);

    backgroundFid := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
    data := art_ptr_lock_data(backgroundFid, 0, 0, @key);
    if data <> nil then
    begin
      widthLoc := INVENTORY_LOOT_LEFT_SCROLLER_X;
      heightLoc := INVENTORY_LOOT_LEFT_SCROLLER_Y + inven_cur_disp * INVENTORY_SLOT_HEIGHT + 2;
      buf_to_buf(data + pitch * heightLoc + widthLoc, INVENTORY_SLOT_WIDTH, text_height(), pitch,
        windowBuffer + pitch * heightLoc + widthLoc, pitch);
      art_ptr_unlock(key);
    end;

    object_ := stack[0];
    color_ := colorTable[992];

    if PID_TYPE(object_^.Pid) = OBJ_TYPE_CRITTER then
    begin
      carryWeight := stat_level(object_, Integer(STAT_CARRY_WEIGHT));
      inventoryWeight := item_total_weight(object_);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d/%d', [inventoryWeight, carryWeight]);
    end
    else
    begin
      inventoryWeight := item_total_weight(object_);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d', [inventoryWeight]);
    end;

    tw := text_width(@formattedText[0]);
    widthLoc := INVENTORY_LOOT_LEFT_SCROLLER_X + INVENTORY_SLOT_WIDTH div 2 - tw div 2;
    heightLoc := INVENTORY_LOOT_LEFT_SCROLLER_Y + INVENTORY_SLOT_HEIGHT * inven_cur_disp + 2;
    text_to_buf(windowBuffer + pitch * heightLoc + widthLoc, @formattedText[0], tw, pitch, color_);

    text_font(oldFont);
  end;

  win_draw(i_wid);
end;

procedure display_target_inventory(first_item_index, selected_index: Integer; inventory: PInventory; inventoryWindowType: Integer);
var
  windowBuffer, data, src: PByte;
  pitch, fid_, offset, inventoryFid: Integer;
  handle, key: PCacheEntry;
  y, index: Integer;
  inventoryItem: PInventoryItem;
  formattedText: array[0..19] of AnsiChar;
  oldFont: Integer;
  color_: Byte;
  object_: PObject;
  tw, currentWeight, maxWeight, currentSize, maxSize: Integer;
begin
  windowBuffer := win_get_buf(i_wid);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
  begin
    pitch := INVENTORY_LOOT_WINDOW_WIDTH;
    fid_ := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
    data := art_ptr_lock_data(fid_, 0, 0, @handle);
    if data <> nil then
    begin
      buf_to_buf(data + pitch * 35 + 422, 64, 48 * inven_cur_disp, pitch,
        windowBuffer + pitch * 35 + 422, pitch);
      art_ptr_unlock(handle);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    pitch := INVENTORY_TRADE_WINDOW_WIDTH;
    src := win_get_buf(barter_back_win);
    buf_to_buf(src + INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH * INVENTORY_TRADE_RIGHT_SCROLLER_Y + INVENTORY_TRADE_RIGHT_SCROLLER_X + INVENTORY_TRADE_WINDOW_OFFSET,
      INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT * inven_cur_disp,
      INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH,
      windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_TRADE_RIGHT_SCROLLER_Y + INVENTORY_TRADE_RIGHT_SCROLLER_X,
      INVENTORY_TRADE_WINDOW_WIDTH);
  end
  else
    pitch := INVENTORY_LOOT_WINDOW_WIDTH; // fallback

  y := 0;
  index := 0;
  while (index < inven_cur_disp) and (first_item_index + index < inventory^.Length) do
  begin
    case inventoryWindowType of
      INVENTORY_WINDOW_TYPE_LOOT:
        offset := pitch * (y + INVENTORY_LOOT_RIGHT_SCROLLER_Y_PAD) + INVENTORY_LOOT_RIGHT_SCROLLER_X_PAD;
      INVENTORY_WINDOW_TYPE_TRADE:
        offset := pitch * (y + INVENTORY_TRADE_RIGHT_SCROLLER_Y_PAD) + INVENTORY_TRADE_RIGHT_SCROLLER_X_PAD;
    else
      offset := 0;
    end;

    inventoryItem := @inventory^.Items[first_item_index + index];
    inventoryFid := item_inv_fid(inventoryItem^.Item);
    scale_art(inventoryFid, windowBuffer + offset, INVENTORY_SLOT_WIDTH_PAD, INVENTORY_SLOT_HEIGHT_PAD, pitch);
    display_inventory_info(inventoryItem^.Item, inventoryItem^.Quantity, windowBuffer + offset, pitch, index = selected_index);

    y := y + INVENTORY_SLOT_HEIGHT;
    Inc(index);
  end;

  // Show weight in loot mode
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT then
  begin
    formattedText[0] := #0;
    oldFont := text_curr;
    text_font(101);

    fid_ := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
    data := art_ptr_lock_data(fid_, 0, 0, @key);
    if data <> nil then
    begin
      offset := INVENTORY_LOOT_RIGHT_SCROLLER_X;
      y := INVENTORY_LOOT_RIGHT_SCROLLER_Y + INVENTORY_SLOT_HEIGHT * inven_cur_disp + 2;
      buf_to_buf(data + pitch * y + offset, INVENTORY_SLOT_WIDTH, text_height(), pitch,
        windowBuffer + pitch * y + offset, pitch);
      art_ptr_unlock(key);
    end;

    object_ := target_stack[target_curr_stack];
    color_ := colorTable[992];

    if PID_TYPE(object_^.Pid) = OBJ_TYPE_CRITTER then
    begin
      currentWeight := item_total_weight(object_);
      maxWeight := stat_level(object_, Integer(STAT_CARRY_WEIGHT));
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d/%d', [currentWeight, maxWeight]);
    end
    else if PID_TYPE(object_^.Pid) = OBJ_TYPE_ITEM then
    begin
      if item_get_type(object_) = ITEM_TYPE_CONTAINER then
      begin
        currentSize := item_c_curr_size(object_);
        maxSize := item_c_max_size(object_);
        StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d/%d', [currentSize, maxSize]);
      end;
    end
    else
    begin
      tw := item_total_weight(object_);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d', [tw]);
    end;

    tw := text_width(@formattedText[0]);
    offset := INVENTORY_LOOT_RIGHT_SCROLLER_X + INVENTORY_SLOT_WIDTH div 2 - tw div 2;
    y := INVENTORY_LOOT_RIGHT_SCROLLER_Y + INVENTORY_SLOT_HEIGHT * inven_cur_disp + 2;
    text_to_buf(windowBuffer + pitch * y + offset, @formattedText[0], tw, pitch, color_);

    text_font(oldFont);
  end;
end;

procedure display_inventory_info(item_: PObject; quantity: Integer; dest: PByte; pitch: Integer; a5: Boolean);
var
  oldFont: Integer;
  formattedText: array[0..11] of AnsiChar;
  draw_: Boolean;
  ammoQuantity, v9: Integer;
begin
  oldFont := text_curr;
  text_font(101);

  draw_ := False;

  if item_get_type(item_) = ITEM_TYPE_AMMO then
  begin
    ammoQuantity := item_w_max_ammo(item_) * (quantity - 1);
    if not a5 then
      ammoQuantity := ammoQuantity + item_w_curr_ammo(item_);
    if ammoQuantity > 99999 then
      ammoQuantity := 99999;
    StrLFmt(formattedText, SizeOf(formattedText) - 1, 'x%d', [ammoQuantity]);
    draw_ := True;
  end
  else
  begin
    if quantity > 1 then
    begin
      v9 := quantity;
      if a5 then
        v9 := v9 - 1;
      if quantity > 1 then
      begin
        if v9 > 99999 then
          v9 := 99999;
        StrLFmt(formattedText, SizeOf(formattedText) - 1, 'x%d', [v9]);
        draw_ := True;
      end;
    end;
  end;

  if draw_ then
    text_to_buf(dest, @formattedText[0], 80, pitch, colorTable[32767]);

  text_font(oldFont);
end;

procedure display_body(fid, inventoryWindowType: Integer);
var
  rotations: array[0..1] of Integer;
  fids: array[0..1] of Integer;
  index, frame_, rotation_: Integer;
  handle, backrgroundFrmHandle: PCacheEntry;
  art_: PArt;
  frameData, windowBuffer, srcData: PByte;
  framePitch, frameWidth, frameHeight, windowPitch: Integer;
  rect_: TRect;
  backgroundFid_: Integer;
begin
  if elapsed_time(display_body_ticker) < INVENTORY_NORMAL_WINDOW_PC_ROTATION_DELAY then
    Exit;

  display_body_curr_rot := display_body_curr_rot + 1;
  if display_body_curr_rot = Integer(ROTATION_COUNT) then
    display_body_curr_rot := 0;

  if fid = -1 then
  begin
    rotations[0] := display_body_curr_rot;
    rotations[1] := Integer(ROTATION_SE);
  end
  else
  begin
    rotations[0] := Integer(ROTATION_SW);
    rotations[1] := target_stack[target_curr_stack]^.Rotation;
  end;

  fids[0] := i_fid;
  fids[1] := fid;

  for index := 0 to 1 do
  begin
    if fids[index] = -1 then
      Continue;

    art_ := art_ptr_lock(fids[index], @handle);
    if art_ = nil then
      Continue;

    frame_ := 0;
    if index = 1 then
      frame_ := art_frame_max_frame(art_) - 1;

    rotation_ := rotations[index];
    frameData := art_frame_data(art_, frame_, rotation_);
    framePitch := art_frame_width(art_, frame_, rotation_);
    frameWidth := Min(framePitch, INVENTORY_BODY_VIEW_WIDTH);
    frameHeight := art_frame_length(art_, frame_, rotation_);
    if frameHeight > INVENTORY_BODY_VIEW_HEIGHT then
      frameHeight := INVENTORY_BODY_VIEW_HEIGHT;

    if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
    begin
      windowBuffer := win_get_buf(barter_back_win);
      windowPitch := win_width(barter_back_win);

      if index = 1 then
      begin
        rect_.ulx := 560;
        rect_.uly := 25;
      end
      else
      begin
        rect_.ulx := 15;
        rect_.uly := 25;
      end;

      rect_.lrx := rect_.ulx + INVENTORY_BODY_VIEW_WIDTH - 1;
      rect_.lry := rect_.uly + INVENTORY_BODY_VIEW_HEIGHT - 1;

      backgroundFid_ := art_id(OBJ_TYPE_INTERFACE, 111, 0, 0, 0);
      srcData := art_ptr_lock_data(backgroundFid_, 0, 0, @backrgroundFrmHandle);
      if srcData <> nil then
        buf_to_buf(srcData + rect_.uly * 640 + rect_.ulx,
          INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, 640,
          windowBuffer + windowPitch * rect_.uly + rect_.ulx, windowPitch);

      trans_buf_to_buf(frameData, frameWidth, frameHeight, framePitch,
        windowBuffer + windowPitch * (rect_.uly + (INVENTORY_BODY_VIEW_HEIGHT - frameHeight) div 2) + (INVENTORY_BODY_VIEW_WIDTH - frameWidth) div 2 + rect_.ulx,
        windowPitch);

      win_draw_rect(barter_back_win, @rect_);
    end
    else
    begin
      windowBuffer := win_get_buf(i_wid);
      windowPitch := win_width(i_wid);

      if index = 1 then
      begin
        rect_.ulx := 297;
        rect_.uly := 37;
      end
      else
      begin
        rect_.ulx := 176;
        rect_.uly := 37;
      end;

      rect_.lrx := rect_.ulx + INVENTORY_BODY_VIEW_WIDTH - 1;
      rect_.lry := rect_.uly + INVENTORY_BODY_VIEW_HEIGHT - 1;

      backgroundFid_ := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
      srcData := art_ptr_lock_data(backgroundFid_, 0, 0, @backrgroundFrmHandle);
      if srcData <> nil then
        buf_to_buf(srcData + INVENTORY_LOOT_WINDOW_WIDTH * rect_.uly + rect_.ulx,
          INVENTORY_BODY_VIEW_WIDTH, INVENTORY_BODY_VIEW_HEIGHT, INVENTORY_LOOT_WINDOW_WIDTH,
          windowBuffer + windowPitch * rect_.uly + rect_.ulx, windowPitch);

      trans_buf_to_buf(frameData, frameWidth, frameHeight, framePitch,
        windowBuffer + windowPitch * (rect_.uly + (INVENTORY_BODY_VIEW_HEIGHT - frameHeight) div 2) + (INVENTORY_BODY_VIEW_WIDTH - frameWidth) div 2 + rect_.ulx,
        windowPitch);

      win_draw_rect(i_wid, @rect_);
    end;

    art_ptr_unlock(backrgroundFrmHandle);
    art_ptr_unlock(handle);
  end;

  display_body_ticker := get_time;
end;

function inven_init: Integer;
const
  num: array[0..INVENTORY_WINDOW_CURSOR_COUNT - 1] of Integer = (286, 250, 282, 283, 266);
var
  index: Integer;
  cursorData: PInventoryCursorData;
  fid_: Integer;
  frm_: PArt;
begin
  if inventry_msg_load = -1 then
    Exit(-1);

  inven_ui_was_disabled := game_ui_is_disabled;
  if inven_ui_was_disabled then
    game_ui_enable;

  gmouse_3d_off;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  index := 0;
  while index < INVENTORY_WINDOW_CURSOR_COUNT do
  begin
    cursorData := @imdata[index];
    fid_ := art_id(OBJ_TYPE_INTERFACE, num[index], 0, 0, 0);
    frm_ := art_ptr_lock(fid_, @cursorData^.frmHandle);
    if frm_ = nil then
      Break;

    cursorData^.frm := frm_;
    cursorData^.frmData := art_frame_data(frm_, 0, 0);
    cursorData^.width := art_frame_width(frm_, 0, 0);
    cursorData^.height := art_frame_length(frm_, 0, 0);
    art_frame_hot(frm_, 0, 0, @cursorData^.offsetX, @cursorData^.offsetY);
    Inc(index);
  end;

  if index <> INVENTORY_WINDOW_CURSOR_COUNT then
  begin
    while index >= 0 do
    begin
      art_ptr_unlock(imdata[index].frmHandle);
      Dec(index);
    end;
    if inven_ui_was_disabled then
      game_ui_disable(0);
    message_exit(@inventry_message_file);
    Exit(-1);
  end;

  inven_is_initialized := True;
  im_value := -1;
  Result := 0;
end;

procedure inven_exit;
var
  index: Integer;
begin
  for index := 0 to INVENTORY_WINDOW_CURSOR_COUNT - 1 do
    art_ptr_unlock(imdata[index].frmHandle);

  if inven_ui_was_disabled then
    game_ui_disable(0);

  inventry_msg_unload;
  inven_is_initialized := False;
end;

procedure inven_set_mouse(cursor: Integer);
var
  cursorData: PInventoryCursorData;
begin
  immode := cursor;
  if (cursor <> INVENTORY_WINDOW_CURSOR_ARROW) or (im_value = -1) then
  begin
    cursorData := @imdata[cursor];
    mouse_set_shape(cursorData^.frmData, cursorData^.width, cursorData^.height, cursorData^.width, cursorData^.offsetX, cursorData^.offsetY, #0);
  end
  else
    inven_hover_on(-1, im_value);
end;

procedure inven_hover_on(btn, keyCode: Integer); cdecl;
var
  x, y, v5, v6: Integer;
  a2a: PObject;
  cursorData: PInventoryCursorData;
begin
  if immode = INVENTORY_WINDOW_CURSOR_ARROW then
  begin
    mouseGetPositionInWindow(i_wid, @x, @y);
    a2a := nil;
    if inven_from_button(keyCode, @a2a, nil, nil) <> 0 then
    begin
      gmouse_3d_build_pick_frame(x, y, 3, i_wid_max_x, i_wid_max_y);
      v5 := 0;
      v6 := 0;
      gmouse_3d_pick_frame_hot(@v5, @v6);
      cursorData := @imdata[INVENTORY_WINDOW_CURSOR_PICK];
      mouse_set_shape(cursorData^.frmData, cursorData^.width, cursorData^.height, cursorData^.width, v5, v6, #0);
      if a2a <> inven_hover_on_last_target then
        obj_look_at_func(stack[0], a2a, display_msg_handler);
    end
    else
    begin
      cursorData := @imdata[INVENTORY_WINDOW_CURSOR_ARROW];
      mouse_set_shape(cursorData^.frmData, cursorData^.width, cursorData^.height, cursorData^.width, cursorData^.offsetX, cursorData^.offsetY, #0);
    end;
    inven_hover_on_last_target := a2a;
  end;
  im_value := keyCode;
end;

procedure inven_hover_off(btn, keyCode: Integer); cdecl;
var
  cursorData: PInventoryCursorData;
begin
  if immode = INVENTORY_WINDOW_CURSOR_ARROW then
  begin
    cursorData := @imdata[INVENTORY_WINDOW_CURSOR_ARROW];
    mouse_set_shape(cursorData^.frmData, cursorData^.width, cursorData^.height, cursorData^.width, cursorData^.offsetX, cursorData^.offsetY, #0);
  end;
  im_value := -1;
end;

// ---- Remaining function implementations ----

function inven_right_hand(critter: PObject): PObject;
var
  i: Integer;
  inventory: PInventory;
begin
  if (i_rhand <> nil) and (critter = inven_dude) then
    Exit(i_rhand);

  inventory := @critter^.Data.AsData.Inventory;
  i := 0;
  while i < inventory^.Length do
  begin
    if (inventory^.Items[i].Item^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
      Exit(inventory^.Items[i].Item);
    Inc(i);
  end;
  Result := nil;
end;

function inven_left_hand(critter: PObject): PObject;
var
  i: Integer;
  inventory: PInventory;
begin
  if (i_lhand <> nil) and (critter = inven_dude) then
    Exit(i_lhand);

  inventory := @critter^.Data.AsData.Inventory;
  i := 0;
  while i < inventory^.Length do
  begin
    if (inventory^.Items[i].Item^.Flags and OBJECT_IN_LEFT_HAND) <> 0 then
      Exit(inventory^.Items[i].Item);
    Inc(i);
  end;
  Result := nil;
end;

function inven_worn(critter: PObject): PObject;
var
  i: Integer;
  inventory: PInventory;
begin
  if (i_worn <> nil) and (critter = inven_dude) then
    Exit(i_worn);

  inventory := @critter^.Data.AsData.Inventory;
  i := 0;
  while i < inventory^.Length do
  begin
    if (inventory^.Items[i].Item^.Flags and OBJECT_WORN) <> 0 then
      Exit(inventory^.Items[i].Item);
    Inc(i);
  end;
  Result := nil;
end;

function inven_pid_is_carried(obj: PObject; pid: Integer): Integer;
var
  index: Integer;
  inventory: PInventory;
begin
  inventory := @obj^.Data.AsData.Inventory;
  index := 0;
  while index < inventory^.Length do
  begin
    if inventory^.Items[index].Item^.Pid = pid then
      Exit(1);
    Inc(index);
  end;
  Result := 0;
end;

function inven_pid_is_carried_ptr(obj: PObject; pid: Integer): PObject;
var
  index: Integer;
  inventory: PInventory;
begin
  inventory := @obj^.Data.AsData.Inventory;
  index := 0;
  while index < inventory^.Length do
  begin
    if inventory^.Items[index].Item^.Pid = pid then
      Exit(inventory^.Items[index].Item);
    Inc(index);
  end;
  Result := nil;
end;

function inven_pid_quantity_carried(obj_: PObject; pid: Integer): Integer;
var
  quantity, index: Integer;
  inventory: PInventory;
begin
  quantity := 0;
  inventory := @obj_^.Data.AsData.Inventory;
  index := 0;
  while index < inventory^.Length do
  begin
    if inventory^.Items[index].Item^.Pid = pid then
      quantity := quantity + inventory^.Items[index].Quantity;
    Inc(index);
  end;
  Result := quantity;
end;

procedure display_stats;
const
  stats1: array[0..6] of Integer = (
    Integer(STAT_CURRENT_HIT_POINTS),
    Integer(STAT_ARMOR_CLASS),
    Integer(STAT_DAMAGE_THRESHOLD),
    Integer(STAT_DAMAGE_THRESHOLD_LASER),
    Integer(STAT_DAMAGE_THRESHOLD_FIRE),
    Integer(STAT_DAMAGE_THRESHOLD_PLASMA),
    Integer(STAT_DAMAGE_THRESHOLD_EXPLOSION)
  );
  stats2: array[0..6] of Integer = (
    Integer(STAT_MAXIMUM_HIT_POINTS),
    -1,
    Integer(STAT_DAMAGE_RESISTANCE),
    Integer(STAT_DAMAGE_RESISTANCE_LASER),
    Integer(STAT_DAMAGE_RESISTANCE_FIRE),
    Integer(STAT_DAMAGE_RESISTANCE_PLASMA),
    Integer(STAT_DAMAGE_RESISTANCE_EXPLOSION)
  );
var
  formattedText: array[0..79] of AnsiChar;
  oldFont: Integer;
  windowBuffer, backgroundData: PByte;
  fid_: Integer;
  backgroundHandle: PCacheEntry;
  critterName, itemName, ammoName: PAnsiChar;
  messageListItem, rangeMessageListItem: TMessageListItem;
  offset, stat, value, index: Integer;
  value1, value2: Integer;
  itemsInHands: array[0..1] of PObject;
  hitModes: array[0..1] of Integer;
  item_: PObject;
  itemType: Integer;
  range_, damageMin, damageMax, attackType, meleeDamage: Integer;
  carryWeight, inventoryWeight: Integer;
begin
  oldFont := text_curr;
  text_font(101);

  windowBuffer := win_get_buf(i_wid);

  fid_ := art_id(OBJ_TYPE_INTERFACE, 48, 0, 0, 0);
  backgroundData := art_ptr_lock_data(fid_, 0, 0, @backgroundHandle);
  if backgroundData <> nil then
    buf_to_buf(backgroundData + INVENTORY_WINDOW_WIDTH * INVENTORY_SUMMARY_Y + INVENTORY_SUMMARY_X,
      152, 188, INVENTORY_WINDOW_WIDTH,
      windowBuffer + INVENTORY_WINDOW_WIDTH * INVENTORY_SUMMARY_Y + INVENTORY_SUMMARY_X,
      INVENTORY_WINDOW_WIDTH);
  art_ptr_unlock(backgroundHandle);

  critterName := critter_name(stack[0]);
  text_to_buf(windowBuffer + INVENTORY_WINDOW_WIDTH * INVENTORY_SUMMARY_Y + INVENTORY_SUMMARY_X,
    critterName, 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);

  draw_line(windowBuffer, INVENTORY_WINDOW_WIDTH,
    INVENTORY_SUMMARY_X, 3 * text_height() div 2 + INVENTORY_SUMMARY_Y,
    INVENTORY_SUMMARY_MAX_X, 3 * text_height() div 2 + INVENTORY_SUMMARY_Y,
    colorTable[992]);

  offset := INVENTORY_WINDOW_WIDTH * 2 * text_height() + INVENTORY_WINDOW_WIDTH * INVENTORY_SUMMARY_Y + INVENTORY_SUMMARY_X;
  stat := 0;
  while stat < 7 do
  begin
    messageListItem.num := stat;
    if message_search(@inventry_message_file, @messageListItem) then
      text_to_buf(windowBuffer + offset, messageListItem.text, 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);

    value := stat_level(stack[0], stat);
    StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d', [value]);
    text_to_buf(windowBuffer + offset + 24, @formattedText[0], 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);

    offset := offset + INVENTORY_WINDOW_WIDTH * text_height();
    Inc(stat);
  end;

  offset := offset - INVENTORY_WINDOW_WIDTH * 7 * text_height();

  index := 0;
  while index < 7 do
  begin
    messageListItem.num := 7 + index;
    if message_search(@inventry_message_file, @messageListItem) then
      text_to_buf(windowBuffer + offset + 40, messageListItem.text, 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);

    if stats2[index] = -1 then
    begin
      value := stat_level(stack[0], stats1[index]);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '   %d', [value]);
    end
    else
    begin
      value1 := stat_level(stack[0], stats1[index]);
      value2 := stat_level(stack[0], stats2[index]);
      if index <> 0 then
        StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d/%d%%', [value1, value2])
      else
        StrLFmt(formattedText, SizeOf(formattedText) - 1, '%d/%d', [value1, value2]);
    end;

    text_to_buf(windowBuffer + offset + 104, @formattedText[0], 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);

    offset := offset + INVENTORY_WINDOW_WIDTH * text_height();
    Inc(index);
  end;

  draw_line(windowBuffer, INVENTORY_WINDOW_WIDTH,
    INVENTORY_SUMMARY_X, 18 * text_height() div 2 + 48,
    INVENTORY_SUMMARY_MAX_X, 18 * text_height() div 2 + 48, colorTable[992]);
  draw_line(windowBuffer, INVENTORY_WINDOW_WIDTH,
    INVENTORY_SUMMARY_X, 26 * text_height() div 2 + 48,
    INVENTORY_SUMMARY_MAX_X, 26 * text_height() div 2 + 48, colorTable[992]);

  itemsInHands[0] := i_lhand;
  itemsInHands[1] := i_rhand;
  hitModes[0] := HIT_MODE_LEFT_WEAPON_PRIMARY;
  hitModes[1] := HIT_MODE_RIGHT_WEAPON_PRIMARY;

  offset := offset + INVENTORY_WINDOW_WIDTH * text_height();

  index := 0;
  while index < 2 do
  begin
    item_ := itemsInHands[index];
    if item_ = nil then
    begin
      formattedText[0] := #0;

      messageListItem.num := 14;
      if message_search(@inventry_message_file, @messageListItem) then
        text_to_buf(windowBuffer + offset, messageListItem.text, 120, INVENTORY_WINDOW_WIDTH, colorTable[992]);

      offset := offset + INVENTORY_WINDOW_WIDTH * text_height();

      messageListItem.num := 24;
      if message_search(@inventry_message_file, @messageListItem) then
      begin
        value := stat_level(stack[0], Integer(STAT_MELEE_DAMAGE)) + 2;
        StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s 1-%d', [messageListItem.text, value]);
      end;

      text_to_buf(windowBuffer + offset, @formattedText[0], 120, INVENTORY_WINDOW_WIDTH, colorTable[992]);

      offset := offset + 3 * INVENTORY_WINDOW_WIDTH * text_height();
      Inc(index);
      Continue;
    end;

    itemName := item_name(item_);
    text_to_buf(windowBuffer + offset, itemName, 140, INVENTORY_WINDOW_WIDTH, colorTable[992]);

    offset := offset + INVENTORY_WINDOW_WIDTH * text_height();

    itemType := item_get_type(item_);
    if itemType <> ITEM_TYPE_WEAPON then
    begin
      if itemType = ITEM_TYPE_ARMOR then
      begin
        messageListItem.num := 18;
        if message_search(@inventry_message_file, @messageListItem) then
          text_to_buf(windowBuffer + offset, messageListItem.text, 120, INVENTORY_WINDOW_WIDTH, colorTable[992]);
      end;

      offset := offset + 3 * INVENTORY_WINDOW_WIDTH * text_height();
      Inc(index);
      Continue;
    end;

    range_ := item_w_range(stack[0], hitModes[index]);
    item_w_damage_min_max(item_, @damageMin, @damageMax);
    attackType := item_w_subtype(item_, hitModes[index]);

    formattedText[0] := #0;

    if (attackType = ATTACK_TYPE_MELEE) or (attackType = ATTACK_TYPE_UNARMED) then
      meleeDamage := stat_level(stack[0], Integer(STAT_MELEE_DAMAGE))
    else
      meleeDamage := 0;

    messageListItem.num := 15;
    if message_search(@inventry_message_file, @messageListItem) then
    begin
      if (attackType = ATTACK_TYPE_RANGED) or (range_ > 1) then
      begin
        rangeMessageListItem.num := 16;
        if message_search(@inventry_message_file, @rangeMessageListItem) then
          StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d-%d   %s %d', [messageListItem.text, damageMin, damageMax + meleeDamage, rangeMessageListItem.text, range_]);
      end
      else
        StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d-%d', [messageListItem.text, damageMin, damageMax + meleeDamage]);

      text_to_buf(windowBuffer + offset, @formattedText[0], 140, INVENTORY_WINDOW_WIDTH, colorTable[992]);
    end;

    offset := offset + INVENTORY_WINDOW_WIDTH * text_height();

    if item_w_max_ammo(item_) > 0 then
    begin
      formattedText[0] := #0;

      messageListItem.num := 17;
      if message_search(@inventry_message_file, @messageListItem) then
      begin
        value1 := item_w_ammo_pid(item_);
        if value1 <> 0 then
        begin
          ammoName := proto_name(value1);
          value := item_w_max_ammo(item_);
          value2 := item_w_curr_ammo(item_);
          StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d/%d %s', [messageListItem.text, value2, value, ammoName]);
        end
        else
        begin
          value := item_w_max_ammo(item_);
          value2 := item_w_curr_ammo(item_);
          StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d/%d', [messageListItem.text, value2, value]);
        end;
      end;

      text_to_buf(windowBuffer + offset, @formattedText[0], 140, INVENTORY_WINDOW_WIDTH, colorTable[992]);
    end;

    offset := offset + 2 * INVENTORY_WINDOW_WIDTH * text_height();
    Inc(index);
  end;

  messageListItem.num := 20;
  if message_search(@inventry_message_file, @messageListItem) then
  begin
    if PID_TYPE(stack[0]^.Pid) = OBJ_TYPE_CRITTER then
    begin
      carryWeight := stat_level(stack[0], Integer(STAT_CARRY_WEIGHT));
      inventoryWeight := item_total_weight(stack[0]);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d/%d', [messageListItem.text, inventoryWeight, carryWeight]);
      text_to_buf(windowBuffer + offset + 15, @formattedText[0], 120, INVENTORY_WINDOW_WIDTH, colorTable[992]);
    end
    else
    begin
      inventoryWeight := item_total_weight(stack[0]);
      StrLFmt(formattedText, SizeOf(formattedText) - 1, '%s %d', [messageListItem.text, inventoryWeight]);
      text_to_buf(windowBuffer + offset + 30, @formattedText[0], 80, INVENTORY_WINDOW_WIDTH, colorTable[992]);
    end;
  end;

  text_font(oldFont);
end;

function inven_find_type(obj: PObject; itemType: Integer; indexPtr: PInteger): PObject;
var
  dummy: Integer;
  inventory: PInventory;
  localIndex: PInteger;
begin
  dummy := -1;
  if indexPtr = nil then
    localIndex := @dummy
  else
    localIndex := indexPtr;

  localIndex^ := localIndex^ + 1;
  inventory := @obj^.Data.AsData.Inventory;

  if localIndex^ >= inventory^.Length then
    Exit(nil);

  while (itemType <> -1) and (item_get_type(inventory^.Items[localIndex^].Item) <> itemType) do
  begin
    localIndex^ := localIndex^ + 1;
    if localIndex^ >= inventory^.Length then
      Exit(nil);
  end;

  Result := inventory^.Items[localIndex^].Item;
end;

function inven_find_id(obj: PObject; id: Integer): PObject;
var
  index: Integer;
  inventory: PInventory;
  inventoryItem: PInventoryItem;
  item_: PObject;
begin
  if obj^.Id = id then
    Exit(obj);

  inventory := @obj^.Data.AsData.Inventory;
  index := 0;
  while index < inventory^.Length do
  begin
    inventoryItem := @inventory^.Items[index];
    item_ := inventoryItem^.Item;
    if item_^.Id = id then
      Exit(item_);

    if item_get_type(item_) = ITEM_TYPE_CONTAINER then
    begin
      item_ := inven_find_id(item_, id);
      if item_ <> nil then
        Exit(item_);
    end;
    Inc(index);
  end;
  Result := nil;
end;

function inven_index_ptr(obj: PObject; a2: Integer): PObject;
var
  inventory: PInventory;
begin
  inventory := @obj^.Data.AsData.Inventory;
  if (a2 < 0) or (a2 >= inventory^.Length) then
    Exit(nil);
  Result := inventory^.Items[a2].Item;
end;

function inven_wield(critter, item_: PObject; a3: Integer): Integer;
var
  itemType, baseFrmId, hand, weaponAnimationCode, hitModeAnimationCode: Integer;
  fid_: Integer;
  armor, v17: PObject;
  rect_: TRect;
  lightIntensity, lightDistance: Integer;
  proto: PProto;
  sfx: PAnsiChar;
begin
  register_begin(ANIMATION_REQUEST_RESERVED);

  itemType := item_get_type(item_);
  if itemType = ITEM_TYPE_ARMOR then
  begin
    armor := inven_worn(critter);
    if armor <> nil then
      armor^.Flags := armor^.Flags and (not OBJECT_WORN);

    item_^.Flags := item_^.Flags or OBJECT_WORN;

    if stat_level(critter, Integer(STAT_GENDER)) = GENDER_FEMALE then
      baseFrmId := item_ar_female_fid(item_)
    else
      baseFrmId := item_ar_male_fid(item_);

    if baseFrmId = -1 then
      baseFrmId := 1;

    if critter = obj_dude then
    begin
      fid_ := art_id(OBJ_TYPE_CRITTER, baseFrmId, 0, (critter^.Fid and $F000) shr 12, critter^.Rotation + 1);
      register_object_change_fid(critter, fid_, 0);
    end
    else
      adjust_ac(critter, armor, item_);
  end
  else
  begin
    if critter = obj_dude then
      hand := intface_is_item_right_hand
    else
      hand := HAND_RIGHT;

    weaponAnimationCode := item_w_anim_code(item_);
    hitModeAnimationCode := item_w_anim_weap(item_, HIT_MODE_RIGHT_WEAPON_PRIMARY);
    fid_ := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, hitModeAnimationCode, weaponAnimationCode, critter^.Rotation + 1);
    if not art_exists(fid_) then
    begin
      debug_printf(PAnsiChar(#10'inven_wield failed!  ERROR ERROR ERROR!'));
      Result := -1;
      Exit;
    end;

    if a3 <> 0 then
    begin
      v17 := inven_right_hand(critter);
      item_^.Flags := item_^.Flags or OBJECT_IN_RIGHT_HAND;
    end
    else
    begin
      v17 := inven_left_hand(critter);
      item_^.Flags := item_^.Flags or OBJECT_IN_LEFT_HAND;
    end;

    if v17 <> nil then
    begin
      v17^.Flags := v17^.Flags and (not OBJECT_IN_ANY_HAND);

      if v17^.Pid = PROTO_ID_LIT_FLARE then
      begin
        if critter = obj_dude then
        begin
          lightIntensity := LIGHT_LEVEL_MAX;
          lightDistance := 4;
        end
        else
        begin
          if proto_ptr(critter^.Pid, @proto) = -1 then
          begin
            Result := -1;
            Exit;
          end;
          lightDistance := proto^.LightDistance;
          lightIntensity := proto^.LightIntensity;
        end;
        obj_set_light(critter, lightDistance, lightIntensity, @rect_);
      end;
    end;

    if item_^.Pid = PROTO_ID_LIT_FLARE then
    begin
      lightDistance := item_^.LightDistance;
      if lightDistance < critter^.LightDistance then
        lightDistance := critter^.LightDistance;

      lightIntensity := item_^.LightIntensity;
      if lightIntensity < critter^.LightIntensity then
        lightIntensity := critter^.LightIntensity;

      obj_set_light(critter, lightDistance, lightIntensity, @rect_);
      tile_refresh_rect(@rect_, map_elevation);
    end;

    if item_get_type(item_) = ITEM_TYPE_WEAPON then
      weaponAnimationCode := item_w_anim_code(item_)
    else
      weaponAnimationCode := 0;

    if hand = a3 then
    begin
      if (critter^.Fid and $F000) shr 12 <> 0 then
      begin
        sfx := gsnd_build_character_sfx_name(critter, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
        register_object_play_sfx(critter, sfx, 0);
        register_object_animate(critter, ANIM_PUT_AWAY, 0);
      end;

      if weaponAnimationCode <> 0 then
        register_object_take_out(critter, weaponAnimationCode, -1)
      else
      begin
        fid_ := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, 0, 0, critter^.Rotation + 1);
        register_object_change_fid(critter, fid_, -1);
      end;
    end;
  end;

  Result := register_end;
end;

function inven_unwield(critter: PObject; a2: Integer): Integer;
var
  hand: Integer;
  item_: PObject;
  fid_: Integer;
  sfx: PAnsiChar;
begin
  if critter = obj_dude then
    hand := intface_is_item_right_hand
  else
    hand := 1;

  if a2 <> 0 then
    item_ := inven_right_hand(critter)
  else
    item_ := inven_left_hand(critter);

  if item_ <> nil then
    item_^.Flags := item_^.Flags and (not OBJECT_IN_ANY_HAND);

  if (hand = a2) and (((critter^.Fid and $F000) shr 12) <> 0) then
  begin
    register_begin(ANIMATION_REQUEST_RESERVED);

    sfx := gsnd_build_character_sfx_name(critter, ANIM_PUT_AWAY, CHARACTER_SOUND_EFFECT_UNUSED);
    register_object_play_sfx(critter, sfx, 0);
    register_object_animate(critter, ANIM_PUT_AWAY, 0);

    fid_ := art_id(OBJ_TYPE_CRITTER, critter^.Fid and $FFF, 0, 0, critter^.Rotation + 1);
    register_object_change_fid(critter, fid_, -1);

    Result := register_end;
    Exit;
  end;

  Result := 0;
end;

function inven_from_button(keyCode: Integer; a2: PPObject; a3: PPPObject; a4: PPObject): Integer;
var
  slot_ptr: PPObject;
  owner, item_: PObject;
  quantity, index: Integer;
  inventoryItem: PInventoryItem;
begin
  slot_ptr := nil;
  owner := nil;
  item_ := nil;
  quantity := 0;

  case keyCode of
    1006:
    begin
      slot_ptr := @i_rhand;
      owner := stack[0];
      item_ := i_rhand;
    end;
    1007:
    begin
      slot_ptr := @i_lhand;
      owner := stack[0];
      item_ := i_lhand;
    end;
    1008:
    begin
      slot_ptr := @i_worn;
      owner := stack[0];
      item_ := i_worn;
    end;
  else
    begin
      if keyCode < 2000 then
      begin
        index := stack_offset[curr_stack] + keyCode - 1000;
        if index < pud^.Length then
        begin
          inventoryItem := @pud^.Items[index];
          item_ := inventoryItem^.Item;
          owner := stack[curr_stack];
          quantity := inventoryItem^.Quantity;
        end;
      end
      else if keyCode < 2300 then
      begin
        index := target_stack_offset[target_curr_stack] + keyCode - 2000;
        if index < target_pud^.Length then
        begin
          inventoryItem := @target_pud^.Items[index];
          item_ := inventoryItem^.Item;
          owner := target_stack[target_curr_stack];
          quantity := inventoryItem^.Quantity;
        end;
      end
      else if keyCode < 2400 then
      begin
        index := ptable_offset + keyCode - 2300;
        if index < ptable_pud^.Length then
        begin
          inventoryItem := @ptable_pud^.Items[index];
          item_ := inventoryItem^.Item;
          owner := ptable;
          quantity := inventoryItem^.Quantity;
        end;
      end
      else
      begin
        index := btable_offset + keyCode - 2400;
        if index < btable_pud^.Length then
        begin
          inventoryItem := @btable_pud^.Items[index];
          item_ := inventoryItem^.Item;
          owner := btable;
          quantity := inventoryItem^.Quantity;
        end;
      end;
    end;
  end;

  if a3 <> nil then
    a3^ := slot_ptr;
  if a2 <> nil then
    a2^ := item_;
  if a4 <> nil then
    a4^ := owner;

  if (quantity = 0) and (item_ <> nil) then
    quantity := 1;

  Result := quantity;
end;

procedure inven_display_msg(str: PAnsiChar);
var
  oldFont: Integer;
  windowBuffer: PByte;
  c, space, nextSpace: PAnsiChar;
begin
  oldFont := text_curr;
  text_font(101);

  windowBuffer := win_get_buf(i_wid);
  windowBuffer := windowBuffer + 499 * 44 + 297;

  c := str;
  while (c <> nil) and (c^ <> #0) do
  begin
    inven_display_msg_line := inven_display_msg_line + 1;
    if inven_display_msg_line > 17 then
    begin
      debug_printf(PAnsiChar(#10'Error: inven_display_msg: out of bounds!'));
      Exit;
    end;

    space := nil;
    if text_width(c) > 152 then
    begin
      space := c + 1;
      while (space^ <> #0) and (space^ <> ' ') do
        Inc(space);

      if space^ = #0 then
      begin
        text_to_buf(windowBuffer + 499 * inven_display_msg_line * text_height(), c, 152, 499, colorTable[992]);
        text_font(oldFont);
        Exit;
      end;

      nextSpace := space + 1;
      while True do
      begin
        while (nextSpace^ <> #0) and (nextSpace^ <> ' ') do
          Inc(nextSpace);

        if nextSpace^ = #0 then
          Break;

        nextSpace^ := #0;
        if text_width(c) >= 152 then
        begin
          nextSpace^ := ' ';
          Break;
        end;

        space := nextSpace;
        nextSpace^ := ' ';
        Inc(nextSpace);
      end;

      if space^ = ' ' then
        space^ := #0;
    end;

    if text_width(c) > 152 then
    begin
      debug_printf(PAnsiChar(#10'Error: inven_display_msg: word too long!'));
      text_font(oldFont);
      Exit;
    end;

    text_to_buf(windowBuffer + 499 * inven_display_msg_line * text_height(), c, 152, 499, colorTable[992]);

    if space <> nil then
    begin
      c := space + 1;
      if space^ = #0 then
        space^ := ' ';
    end
    else
      c := nil;
  end;

  text_font(oldFont);
end;

procedure inven_obj_examine_func(critter, item_: PObject);
var
  oldFont: Integer;
  windowBuffer, backgroundData: PByte;
  backgroundFid: Integer;
  handle: PCacheEntry;
  itemName_: PAnsiChar;
  lineHeight, weight_: Integer;
  messageListItem: TMessageListItem;
  formattedText: array[0..39] of AnsiChar;
begin
  oldFont := text_curr;
  text_font(101);

  windowBuffer := win_get_buf(i_wid);

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, 48, 0, 0, 0);
  backgroundData := art_ptr_lock_data(backgroundFid, 0, 0, @handle);
  if backgroundData <> nil then
    buf_to_buf(backgroundData + 499 * 44 + 297, 152, 188, 499, windowBuffer + 499 * 44 + 297, 499);
  art_ptr_unlock(handle);

  inven_display_msg_line := 0;

  itemName_ := object_name(item_);
  inven_display_msg(itemName_);

  inven_display_msg_line := inven_display_msg_line + 1;

  lineHeight := text_height();

  draw_line(windowBuffer, 499, 297, 3 * lineHeight div 2 + 49, 440, 3 * lineHeight div 2 + 49, colorTable[992]);

  obj_examine_func(critter, item_, @inven_display_msg);

  weight_ := item_weight(item_);
  if weight_ <> 0 then
  begin
    messageListItem.num := 540;
    if weight_ = 1 then
      messageListItem.num := 541;

    if not message_search(@proto_main_msg_file, @messageListItem) then
      debug_printf(PAnsiChar(#10'Error: Couldn''t find message!'));

    StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text, [weight_]);
    inven_display_msg(@formattedText[0]);
  end;

  text_font(oldFont);
end;

procedure inven_action_cursor(eventCode, inventoryWindowType: Integer);
const
  act_use: array[0..3] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_USE,
    GAME_MOUSE_ACTION_MENU_ITEM_DROP,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
  act_no_use: array[0..2] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_DROP,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
  act_just_use: array[0..2] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_USE,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
  act_nothing: array[0..1] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
  act_weap: array[0..3] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_UNLOAD,
    GAME_MOUSE_ACTION_MENU_ITEM_DROP,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
  act_weap2: array[0..2] of Integer = (
    GAME_MOUSE_ACTION_MENU_ITEM_LOOK,
    GAME_MOUSE_ACTION_MENU_ITEM_UNLOAD,
    GAME_MOUSE_ACTION_MENU_ITEM_CANCEL
  );
var
  item_: PObject;
  v43: PPObject;
  v41: PObject;
  v56: Integer;
  itemType, mouseState: Integer;
  windowBuffer: PByte;
  x, y: Integer;
  actionMenuItemsLength: Integer;
  actionMenuItems: PInteger;
  windowDescription: PInventoryWindowDescription;
  windowRect, rect_: TRect;
  inventoryWindowX, inventoryWindowY: Integer;
  cursorData: PInventoryCursorData;
  offsetX, offsetY: Integer;
  menuButtonHeight, btn: Integer;
  menuItemIndex, previousMouseY: Integer;
  actionMenuItem: Integer;
  ammo, a2: PObject;
  backgroundFid: Integer;
  backgroundFrmHandle: PCacheEntry;
  backgroundFrmData, src: PByte;
  pitch: Integer;
  v21: Integer;
  idx: Integer;
begin
  v43 := nil;
  v41 := nil;
  v56 := inven_from_button(eventCode, @item_, @v43, @v41);
  if v56 = 0 then
    Exit;

  itemType := item_get_type(item_);

  repeat
    sharedFpsLimiter.Mark;
    get_input;

    if inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL then
      display_body(-1, INVENTORY_WINDOW_TYPE_NORMAL);

    mouseState := mouse_get_buttons;
    if (mouseState and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
    begin
      if inventoryWindowType <> INVENTORY_WINDOW_TYPE_NORMAL then
        obj_look_at_func(stack[0], item_, display_msg_handler)
      else
        inven_obj_examine_func(stack[0], item_);
      win_draw(i_wid);
      Exit;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  until (mouseState and MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT) = MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT;

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_BLANK);

  windowBuffer := win_get_buf(i_wid);
  mouse_get_position(@x, @y);

  if (itemType = ITEM_TYPE_WEAPON) and (item_w_can_unload(item_) <> 0) then
  begin
    if (inventoryWindowType <> INVENTORY_WINDOW_TYPE_NORMAL) and (obj_top_environment(item_) <> obj_dude) then
    begin
      actionMenuItemsLength := 3;
      actionMenuItems := @act_weap2[0];
    end
    else
    begin
      actionMenuItemsLength := 4;
      actionMenuItems := @act_weap[0];
    end;
  end
  else
  begin
    if inventoryWindowType <> INVENTORY_WINDOW_TYPE_NORMAL then
    begin
      if obj_top_environment(item_) <> obj_dude then
      begin
        if itemType = ITEM_TYPE_CONTAINER then
        begin
          actionMenuItemsLength := 3;
          actionMenuItems := @act_just_use[0];
        end
        else
        begin
          actionMenuItemsLength := 2;
          actionMenuItems := @act_nothing[0];
        end;
      end
      else
      begin
        if itemType = ITEM_TYPE_CONTAINER then
        begin
          actionMenuItemsLength := 4;
          actionMenuItems := @act_use[0];
        end
        else
        begin
          actionMenuItemsLength := 3;
          actionMenuItems := @act_no_use[0];
        end;
      end;
    end
    else
    begin
      if (itemType = ITEM_TYPE_CONTAINER) and (v43 <> nil) then
      begin
        actionMenuItemsLength := 3;
        actionMenuItems := @act_no_use[0];
      end
      else
      begin
        if proto_action_can_use(item_^.Pid) or proto_action_can_use_on(item_^.Pid) then
        begin
          actionMenuItemsLength := 4;
          actionMenuItems := @act_use[0];
        end
        else
        begin
          actionMenuItemsLength := 3;
          actionMenuItems := @act_no_use[0];
        end;
      end;
    end;
  end;

  windowDescription := @iscr_data[inventoryWindowType];

  win_get_rect(i_wid, @windowRect);
  inventoryWindowX := windowRect.ulx;
  inventoryWindowY := windowRect.uly;

  gmouse_3d_build_menu_frame(x, y, actionMenuItems, actionMenuItemsLength,
    windowDescription^.width + inventoryWindowX,
    windowDescription^.height + inventoryWindowY);

  cursorData := @imdata[INVENTORY_WINDOW_CURSOR_MENU];
  art_frame_offset(cursorData^.frm, 0, @offsetX, @offsetY);

  rect_.ulx := x - inventoryWindowX - cursorData^.width div 2 + offsetX;
  rect_.uly := y - inventoryWindowY - cursorData^.height + 1 + offsetY;
  rect_.lrx := rect_.ulx + cursorData^.width - 1;
  rect_.lry := rect_.uly + cursorData^.height - 1;

  menuButtonHeight := cursorData^.height;
  if rect_.uly + menuButtonHeight > windowDescription^.height then
    menuButtonHeight := windowDescription^.height - rect_.uly;

  btn := win_register_button(i_wid, rect_.ulx, rect_.uly,
    cursorData^.width, menuButtonHeight, -1, -1, -1, -1,
    cursorData^.frmData, cursorData^.frmData, nil, BUTTON_FLAG_TRANSPARENT);
  win_draw_rect(i_wid, @rect_);

  menuItemIndex := 0;
  previousMouseY := y;
  while (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_UP) = 0 do
  begin
    sharedFpsLimiter.Mark;
    get_input;

    if inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL then
      display_body(-1, INVENTORY_WINDOW_TYPE_NORMAL);

    mouse_get_position(@x, @y);
    if (y - previousMouseY > 10) or (previousMouseY - y > 10) then
    begin
      if (y >= previousMouseY) or (menuItemIndex <= 0) then
      begin
        if (previousMouseY < y) and (menuItemIndex < actionMenuItemsLength - 1) then
          Inc(menuItemIndex);
      end
      else
        Dec(menuItemIndex);
      gmouse_3d_highlight_menu_frame(menuItemIndex);
      win_draw_rect(i_wid, @rect_);
      previousMouseY := y;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  win_delete_button(btn);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
  begin
    src := win_get_buf(barter_back_win);
    pitch := INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH;
    buf_to_buf(src + pitch * rect_.uly + rect_.ulx + INVENTORY_TRADE_WINDOW_OFFSET,
      cursorData^.width, menuButtonHeight, pitch,
      windowBuffer + windowDescription^.width * rect_.uly + rect_.ulx,
      windowDescription^.width);
  end
  else
  begin
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, windowDescription^.field_0, 0, 0, 0);
    backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
    buf_to_buf(backgroundFrmData + windowDescription^.width * rect_.uly + rect_.ulx,
      cursorData^.width, menuButtonHeight, windowDescription^.width,
      windowBuffer + windowDescription^.width * rect_.uly + rect_.ulx,
      windowDescription^.width);
    art_ptr_unlock(backgroundFrmHandle);
  end;

  mouse_set_position(x, y);
  display_inventory(stack_offset[curr_stack], -1, inventoryWindowType);

  actionMenuItem := PInteger(PByte(actionMenuItems) + menuItemIndex * SizeOf(Integer))^;
  case actionMenuItem of
    GAME_MOUSE_ACTION_MENU_ITEM_DROP:
    begin
      if v43 <> nil then
      begin
        if v43 = @i_worn then
          adjust_ac(stack[0], item_, nil);
        item_add_force(v41, item_, 1);
        v56 := 1;
        v43^ := nil;
      end;

      if item_^.Pid = PROTO_ID_MONEY then
      begin
        if v56 > 1 then
          v56 := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, item_, v56)
        else
          v56 := 1;

        if v56 > 0 then
        begin
          if v56 = 1 then
          begin
            item_caps_set_amount(item_, 1);
            obj_drop(v41, item_);
          end
          else
          begin
            if item_remove_mult(v41, item_, v56 - 1) = 0 then
            begin
              if inven_from_button(eventCode, @a2, @v43, @v41) <> 0 then
              begin
                item_caps_set_amount(a2, v56);
                obj_drop(v41, a2);
              end
              else
                item_add_force(v41, item_, v56 - 1);
            end;
          end;
        end;
      end
      else if (item_^.Pid = PROTO_ID_DYNAMITE_II) or (item_^.Pid = PROTO_ID_PLASTIC_EXPLOSIVES_II) then
      begin
        dropped_explosive := True;
        obj_drop(v41, item_);
      end
      else
      begin
        if v56 > 1 then
        begin
          v56 := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, item_, v56);
          idx := 0;
          while idx < v56 do
          begin
            if inven_from_button(eventCode, @item_, @v43, @v41) <> 0 then
              obj_drop(v41, item_);
            Inc(idx);
          end;
        end
        else
          obj_drop(v41, item_);
      end;
    end;

    GAME_MOUSE_ACTION_MENU_ITEM_LOOK:
    begin
      if inventoryWindowType <> INVENTORY_WINDOW_TYPE_NORMAL then
        obj_examine_func(stack[0], item_, display_msg_handler)
      else
        inven_obj_examine_func(stack[0], item_);
    end;

    GAME_MOUSE_ACTION_MENU_ITEM_USE:
    begin
      case itemType of
        ITEM_TYPE_CONTAINER:
          container_enter(eventCode, inventoryWindowType);
        ITEM_TYPE_DRUG:
        begin
          if item_d_take_drug(stack[0], item_) <> 0 then
          begin
            if v43 <> nil then
              v43^ := nil
            else
              item_remove_mult(v41, item_, 1);

            obj_connect(item_, obj_dude^.Tile, obj_dude^.Elevation, nil);
            obj_destroy(item_);
          end;
          intface_update_hit_points(True);
        end;
        ITEM_TYPE_WEAPON, ITEM_TYPE_MISC:
        begin
          if v43 = nil then
            item_remove_mult(v41, item_, 1);

          if proto_action_can_use(item_^.Pid) then
            v21 := protinst_use_item(stack[0], item_)
          else
            v21 := protinst_use_item_on(stack[0], stack[0], item_);

          if v21 = 1 then
          begin
            if v43 <> nil then
              v43^ := nil;
            obj_connect(item_, obj_dude^.Tile, obj_dude^.Elevation, nil);
            obj_destroy(item_);
          end
          else
          begin
            if v43 = nil then
              item_add_force(v41, item_, 1);
          end;
        end;
      end;
    end;

    GAME_MOUSE_ACTION_MENU_ITEM_UNLOAD:
    begin
      if v43 = nil then
        item_remove_mult(v41, item_, 1);

      while True do
      begin
        ammo := item_w_unload(item_);
        if ammo = nil then
          Break;
        obj_disconnect(ammo, @rect_);
        item_add_force(v41, ammo, 1);
      end;

      if v43 = nil then
        item_add_force(v41, item_, 1);
    end;
  end;

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW);

  if (inventoryWindowType = INVENTORY_WINDOW_TYPE_NORMAL) and (actionMenuItem <> GAME_MOUSE_ACTION_MENU_ITEM_LOOK) then
    display_stats;

  if (inventoryWindowType = INVENTORY_WINDOW_TYPE_LOOT) or (inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE) then
    display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, inventoryWindowType);

  display_inventory(stack_offset[curr_stack], -1, inventoryWindowType);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_TRADE then
    display_table_inventories(barter_back_win, ptable, btable, -1);

  adjust_fid;
end;

procedure inven_pickup(keyCode, first_item_index: Integer);
var
  a1a: PObject;
  v29: PPObject;
  count, v3: Integer;
  rect_: TRect;
  windowBuffer, backgroundFrmData, itemInventoryFrmData: PByte;
  backgroundFrmHandle, itemInventoryFrmHandle: PCacheEntry;
  backgroundFid, itemInventoryFid: Integer;
  itemInventoryFrm: PArt;
  width_, height_: Integer;
  x, y, index: Integer;
  v19, v21: PObject;
  v22: Integer;
begin
  v29 := nil;
  count := inven_from_button(keyCode, @a1a, @v29, nil);
  if count = 0 then
    Exit;

  v3 := -1;
  case keyCode of
    1006:
    begin
      rect_.ulx := 245;
      rect_.uly := 286;
    end;
    1007:
    begin
      rect_.ulx := 154;
      rect_.uly := 286;
    end;
    1008:
    begin
      rect_.ulx := 154;
      rect_.uly := 183;
    end;
  else
    v3 := keyCode - 1000;
    rect_.ulx := 44;
    rect_.uly := 48 * v3 + 35;
  end;

  if (v3 = -1) or (pud^.Items[first_item_index + v3].Quantity <= 1) then
  begin
    windowBuffer := win_get_buf(i_wid);
    if (i_rhand <> i_lhand) or (a1a <> i_lhand) then
    begin
      if v3 = -1 then
      begin
        height_ := INVENTORY_LARGE_SLOT_HEIGHT;
        width_ := INVENTORY_LARGE_SLOT_WIDTH;
      end
      else
      begin
        height_ := INVENTORY_SLOT_HEIGHT;
        width_ := INVENTORY_SLOT_WIDTH;
      end;

      backgroundFid := art_id(OBJ_TYPE_INTERFACE, 48, 0, 0, 0);
      backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
      if backgroundFrmData <> nil then
      begin
        buf_to_buf(backgroundFrmData + 499 * rect_.uly + rect_.ulx, width_, height_, 499, windowBuffer + 499 * rect_.uly + rect_.ulx, 499);
        art_ptr_unlock(backgroundFrmHandle);
      end;

      rect_.lrx := rect_.ulx + width_ - 1;
      rect_.lry := rect_.uly + height_ - 1;
    end
    else
    begin
      backgroundFid := art_id(OBJ_TYPE_INTERFACE, 48, 0, 0, 0);
      backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
      if backgroundFrmData <> nil then
      begin
        buf_to_buf(backgroundFrmData + 499 * 286 + 154, 180, 61, 499, windowBuffer + 499 * 286 + 154, 499);
        art_ptr_unlock(backgroundFrmHandle);
      end;

      rect_.ulx := 154;
      rect_.uly := 286;
      rect_.lrx := rect_.ulx + 180 - 1;
      rect_.lry := rect_.uly + 61 - 1;
    end;
    win_draw_rect(i_wid, @rect_);
  end
  else
    display_inventory(first_item_index, v3, INVENTORY_WINDOW_TYPE_NORMAL);

  itemInventoryFid := item_inv_fid(a1a);
  itemInventoryFrm := art_ptr_lock(itemInventoryFid, @itemInventoryFrmHandle);
  if itemInventoryFrm <> nil then
  begin
    width_ := art_frame_width(itemInventoryFrm, 0, 0);
    height_ := art_frame_length(itemInventoryFrm, 0, 0);
    itemInventoryFrmData := art_frame_data(itemInventoryFrm, 0, 0);
    mouse_set_shape(itemInventoryFrmData, width_, height_, width_, width_ div 2, height_ div 2, #0);
    gsound_play_sfx_file('ipickup1');
  end;

  repeat
    sharedFpsLimiter.Mark;
    get_input;
    display_body(-1, INVENTORY_WINDOW_TYPE_NORMAL);
    renderPresent;
    sharedFpsLimiter.Throttle;
  until (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0;

  if itemInventoryFrm <> nil then
  begin
    art_ptr_unlock(itemInventoryFrmHandle);
    gsound_play_sfx_file('iputdown');
  end;

  if mouseHitTestInWindow(i_wid, INVENTORY_SCROLLER_X, INVENTORY_SCROLLER_Y, INVENTORY_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_SCROLLER_Y) then
  begin
    mouseGetPositionInWindow(i_wid, @x, @y);

    index := (y - 39) div 48;
    if index + first_item_index < pud^.Length then
    begin
      v19 := pud^.Items[index + first_item_index].Item;
      if v19 <> a1a then
      begin
        if item_get_type(v19) = ITEM_TYPE_CONTAINER then
        begin
          if drop_into_container(v19, a1a, v3, v29, count) = 0 then
            v3 := 0;
        end
        else
        begin
          if drop_ammo_into_weapon(v19, a1a, v29, count, keyCode) = 0 then
            v3 := 0;
        end;
      end;
    end;

    if v3 = -1 then
    begin
      v29^ := nil;
      if item_add_force(inven_dude, a1a, 1) <> 0 then
        v29^ := a1a
      else if v29 = @i_worn then
        adjust_ac(stack[0], a1a, nil)
      else if i_rhand = i_lhand then
      begin
        i_lhand := nil;
        i_rhand := nil;
      end;
    end;
  end
  else if mouseHitTestInWindow(i_wid, INVENTORY_LEFT_HAND_SLOT_X, INVENTORY_LEFT_HAND_SLOT_Y, INVENTORY_LEFT_HAND_SLOT_MAX_X, INVENTORY_LEFT_HAND_SLOT_MAX_Y) then
  begin
    if (i_lhand <> nil) and (item_get_type(i_lhand) = ITEM_TYPE_CONTAINER) and (i_lhand <> a1a) then
      drop_into_container(i_lhand, a1a, v3, v29, count)
    else if (i_lhand = nil) or (drop_ammo_into_weapon(i_lhand, a1a, v29, count, keyCode) <> 0) then
      switch_hand(a1a, @i_lhand, v29, keyCode);
  end
  else if mouseHitTestInWindow(i_wid, INVENTORY_RIGHT_HAND_SLOT_X, INVENTORY_RIGHT_HAND_SLOT_Y, INVENTORY_RIGHT_HAND_SLOT_MAX_X, INVENTORY_RIGHT_HAND_SLOT_MAX_Y) then
  begin
    if (i_rhand <> nil) and (item_get_type(i_rhand) = ITEM_TYPE_CONTAINER) and (i_rhand <> a1a) then
      drop_into_container(i_rhand, a1a, v3, v29, count)
    else if (i_rhand = nil) or (drop_ammo_into_weapon(i_rhand, a1a, v29, count, keyCode) <> 0) then
      switch_hand(a1a, @i_rhand, v29, v3);
  end
  else if mouseHitTestInWindow(i_wid, INVENTORY_ARMOR_SLOT_X, INVENTORY_ARMOR_SLOT_Y, INVENTORY_ARMOR_SLOT_MAX_X, INVENTORY_ARMOR_SLOT_MAX_Y) then
  begin
    if item_get_type(a1a) = ITEM_TYPE_ARMOR then
    begin
      v21 := i_worn;
      v22 := 0;
      if v3 <> -1 then
        item_remove_mult(inven_dude, a1a, 1);

      if i_worn <> nil then
      begin
        if v29 <> nil then
          v29^ := i_worn
        else
        begin
          i_worn := nil;
          v22 := item_add_force(inven_dude, v21, 1);
        end;
      end
      else
      begin
        if v29 <> nil then
          v29^ := i_worn;
      end;

      if v22 <> 0 then
      begin
        i_worn := v21;
        if v3 <> -1 then
          item_add_force(inven_dude, a1a, 1);
      end
      else
      begin
        adjust_ac(stack[0], v21, a1a);
        i_worn := a1a;
      end;
    end;
  end
  else if mouseHitTestInWindow(i_wid, INVENTORY_PC_BODY_VIEW_X, INVENTORY_PC_BODY_VIEW_Y, INVENTORY_PC_BODY_VIEW_MAX_X, INVENTORY_PC_BODY_VIEW_MAX_Y) then
  begin
    if curr_stack <> 0 then
      drop_into_container(stack[curr_stack - 1], a1a, v3, v29, count);
  end;

  adjust_fid;
  display_stats;
  display_inventory(first_item_index, -1, INVENTORY_WINDOW_TYPE_NORMAL);
  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
end;

procedure switch_hand(a1: PObject; a2: PPObject; a3: PPObject; a4: Integer);
var
  itemToAdd: PObject;
begin
  if a2^ <> nil then
  begin
    if (item_get_type(a2^) = ITEM_TYPE_WEAPON) and (item_get_type(a1) = ITEM_TYPE_AMMO) then
      Exit;

    if (a3 <> nil) and ((a3 <> @i_worn) or (item_get_type(a2^) = ITEM_TYPE_ARMOR)) then
    begin
      if a3 = @i_worn then
        adjust_ac(stack[0], i_worn, a2^);
      a3^ := a2^;
    end
    else
    begin
      if a4 <> -1 then
        item_remove_mult(inven_dude, a1, 1);

      itemToAdd := a2^;
      a2^ := nil;
      if item_add_force(inven_dude, itemToAdd, 1) <> 0 then
      begin
        item_add_force(inven_dude, a1, 1);
        Exit;
      end;

      a4 := -1;

      if a3 <> nil then
      begin
        if a3 = @i_worn then
          adjust_ac(stack[0], i_worn, nil);
        a3^ := nil;
      end;
    end;
  end
  else
  begin
    if a3 <> nil then
    begin
      if a3 = @i_worn then
        adjust_ac(stack[0], i_worn, nil);
      a3^ := nil;
    end;
  end;

  a2^ := a1;

  if a4 <> -1 then
    item_remove_mult(inven_dude, a1, 1);
end;

procedure adjust_ac(critter, oldArmor, newArmor: PObject);
var
  armorClassBonus, oldArmorClass, newArmorClass: Integer;
  damageResistanceStat, damageThresholdStat: Integer;
  damageType: Integer;
  drBonus, oldDr, newDr: Integer;
  dtBonus, oldDt, newDt: Integer;
  perkVal: Integer;
begin
  if critter = obj_dude then
  begin
    armorClassBonus := stat_get_bonus(critter, Integer(STAT_ARMOR_CLASS));
    oldArmorClass := item_ar_ac(oldArmor);
    newArmorClass := item_ar_ac(newArmor);
    stat_set_bonus(critter, Integer(STAT_ARMOR_CLASS), armorClassBonus - oldArmorClass + newArmorClass);

    damageResistanceStat := Integer(STAT_DAMAGE_RESISTANCE);
    damageThresholdStat := Integer(STAT_DAMAGE_THRESHOLD);
    damageType := 0;
    while damageType < DAMAGE_TYPE_COUNT do
    begin
      drBonus := stat_get_bonus(critter, damageResistanceStat);
      oldDr := item_ar_dr(oldArmor, damageType);
      newDr := item_ar_dr(newArmor, damageType);
      stat_set_bonus(critter, damageResistanceStat, drBonus - oldDr + newDr);

      dtBonus := stat_get_bonus(critter, damageThresholdStat);
      oldDt := item_ar_dt(oldArmor, damageType);
      newDt := item_ar_dt(newArmor, damageType);
      stat_set_bonus(critter, damageThresholdStat, dtBonus - oldDt + newDt);

      Inc(damageResistanceStat);
      Inc(damageThresholdStat);
      Inc(damageType);
    end;

    if oldArmor <> nil then
    begin
      perkVal := item_ar_perk(oldArmor);
      perk_remove_effect(critter, perkVal);
    end;

    if newArmor <> nil then
    begin
      perkVal := item_ar_perk(newArmor);
      perk_add_effect(critter, perkVal);
    end;
  end;
end;

procedure adjust_fid;
var
  fid_: Integer;
  proto: PProto;
  v0, animationCode: Integer;
begin
  if FID_TYPE(inven_dude^.Fid) = OBJ_TYPE_CRITTER then
  begin
    v0 := art_vault_guy_num;

    if proto_ptr(inven_pid, @proto) = -1 then
      v0 := proto^.Fid and $FFF;

    if i_worn <> nil then
    begin
      proto_ptr(i_worn^.Pid, @proto);
      if stat_level(inven_dude, Integer(STAT_GENDER)) = GENDER_FEMALE then
        v0 := proto^.Item.Data.Armor.FemaleFid
      else
        v0 := proto^.Item.Data.Armor.MaleFid;

      if v0 = -1 then
        v0 := art_vault_guy_num;
    end;

    animationCode := 0;
    if intface_is_item_right_hand <> 0 then
    begin
      if i_rhand <> nil then
      begin
        proto_ptr(i_rhand^.Pid, @proto);
        if proto^.Item.ItemType = ITEM_TYPE_WEAPON then
          animationCode := proto^.Item.Data.Weapon.AnimationCode;
      end;
    end
    else
    begin
      if i_lhand <> nil then
      begin
        proto_ptr(i_lhand^.Pid, @proto);
        if proto^.Item.ItemType = ITEM_TYPE_WEAPON then
          animationCode := proto^.Item.Data.Weapon.AnimationCode;
      end;
    end;

    fid_ := art_id(OBJ_TYPE_CRITTER, v0, 0, animationCode, 0);
  end
  else
    fid_ := inven_dude^.Fid;

  i_fid := fid_;
end;

procedure use_inventory_on(a1: PObject);
var
  isoWasEnabled: Boolean;
  keyCode, inventoryItemIndex: Integer;
  inventoryItem: PInventoryItem;
  wheelX, wheelY: Integer;
begin
  if inven_init = -1 then
    Exit;

  isoWasEnabled := setup_inventory(INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
  display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);

  while True do
  begin
    sharedFpsLimiter.Mark;

    if game_user_wants_to_quit <> 0 then
      Break;

    display_body(-1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);

    keyCode := get_input;
    if keyCode = KEY_HOME then
    begin
      stack_offset[curr_stack] := 0;
      display_inventory(0, -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
    end
    else if keyCode = KEY_ARROW_UP then
    begin
      if stack_offset[curr_stack] > 0 then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
      end;
    end
    else if keyCode = KEY_PAGE_UP then
    begin
      stack_offset[curr_stack] := stack_offset[curr_stack] - inven_cur_disp;
      if stack_offset[curr_stack] < 0 then
      begin
        stack_offset[curr_stack] := 0;
        display_inventory(stack_offset[curr_stack], -1, 1);
      end;
    end
    else if keyCode = KEY_END then
    begin
      stack_offset[curr_stack] := pud^.Length - inven_cur_disp;
      if stack_offset[curr_stack] < 0 then
        stack_offset[curr_stack] := 0;
      display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
    end
    else if keyCode = KEY_ARROW_DOWN then
    begin
      if stack_offset[curr_stack] + inven_cur_disp < pud^.Length then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
      end;
    end
    else if keyCode = KEY_PAGE_DOWN then
    begin
      stack_offset[curr_stack] := stack_offset[curr_stack] + inven_cur_disp;
      if stack_offset[curr_stack] + inven_cur_disp >= pud^.Length then
      begin
        stack_offset[curr_stack] := pud^.Length - inven_cur_disp;
        if stack_offset[curr_stack] < 0 then
          stack_offset[curr_stack] := 0;
      end;
      display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
    end
    else if keyCode = 2500 then
      container_exit(keyCode, INVENTORY_WINDOW_TYPE_USE_ITEM_ON)
    else
    begin
      if (mouse_get_buttons and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
      begin
        if immode = INVENTORY_WINDOW_CURSOR_HAND then
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW)
        else
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
      end
      else if (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
      begin
        if (keyCode >= 1000) and (keyCode < 1000 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_USE_ITEM_ON)
          else
          begin
            inventoryItemIndex := stack_offset[curr_stack] + keyCode - 1000;
            if inventoryItemIndex < pud^.Length then
            begin
              inventoryItem := @pud^.Items[inventoryItemIndex];
              action_use_an_item_on_object(stack[0], a1, inventoryItem^.Item);
              keyCode := KEY_ESCAPE;
            end
            else
              keyCode := -1;
          end;
        end;
      end
      else if (mouse_get_buttons and MOUSE_EVENT_WHEEL) <> 0 then
      begin
        if mouseHitTestInWindow(i_wid, INVENTORY_SCROLLER_X, INVENTORY_SCROLLER_Y, INVENTORY_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_SCROLLER_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if stack_offset[curr_stack] > 0 then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
            end;
          end
          else if wheelY < 0 then
          begin
            if inven_cur_disp + stack_offset[curr_stack] < pud^.Length then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_USE_ITEM_ON);
            end;
          end;
        end;
      end;
    end;

    if keyCode = KEY_ESCAPE then
      Break;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  exit_inventory(isoWasEnabled);
  inven_exit;
end;

function loot_container(a1, a2: PObject): Integer;
const
  arrowFrmIds: array[0..INVENTORY_ARROW_FRM_COUNT - 1] of Integer = (122, 123, 124, 125);
var
  arrowFrmHandles: array[0..INVENTORY_ARROW_FRM_COUNT - 1] of PCacheEntry;
  messageListItem: TMessageListItem;
  a1a, item1, item2, armor: PObject;
  isoWasEnabled, isCaughtStealing: Boolean;
  critters: PPObject;
  critterCount, critterIndex: Integer;
  endIndex, index, keyCode, rc: Integer;
  critter_: PObject;
  fid_, btn, sid: Integer;
  buttonUpData, buttonDownData: PByte;
  inventoryItem: PInventoryItem;
  stealingXp, stealingXpBonus: Integer;
  script: PScript;
  frm: PArt;
  handle: PCacheEntry;
  frameCount: Integer;
  wheelX, wheelY: Integer;
  formattedText: array[0..199] of AnsiChar;
begin
  if a1 <> inven_dude then
    Exit(0);

  if FID_TYPE(a2^.Fid) = OBJ_TYPE_ITEM then
  begin
    if item_get_type(a2) = ITEM_TYPE_CONTAINER then
    begin
      if a2^.Frame = 0 then
      begin
        frm := art_ptr_lock(a2^.Fid, @handle);
        if frm <> nil then
        begin
          frameCount := art_frame_max_frame(frm);
          art_ptr_unlock(handle);
          if frameCount > 1 then
            Exit(0);
        end;
      end;
    end;
  end;

  sid := -1;
  if gIsSteal = 0 then
  begin
    if obj_sid(a2, @sid) <> -1 then
    begin
      scr_set_objs(sid, a1, nil);
      exec_script_proc(sid, SCRIPT_PROC_PICKUP);

      if scr_ptr(sid, @script) <> -1 then
      begin
        if script^.scriptOverrides <> 0 then
          Exit(0);
      end;
    end;
  end;

  if inven_init = -1 then
    Exit(0);

  target_pud := @a2^.Data.AsData.Inventory;
  target_curr_stack := 0;
  target_stack_offset[0] := 0;
  target_stack[0] := a2;

  a1a := nil;
  if obj_new(@a1a, 0, 467) = -1 then
    Exit(0);

  item1 := nil;
  item2 := nil;
  armor := nil;

  if gIsSteal <> 0 then
  begin
    item1 := inven_left_hand(a2);
    if item1 <> nil then
      item_remove_mult(a2, item1, 1);

    item2 := inven_right_hand(a2);
    if item2 <> nil then
      item_remove_mult(a2, item2, 1);

    armor := inven_worn(a2);
    if armor <> nil then
      item_remove_mult(a2, armor, 1);
  end;

  isoWasEnabled := setup_inventory(INVENTORY_WINDOW_TYPE_LOOT);

  critters := nil;
  critterCount := 0;
  critterIndex := 0;
  if gIsSteal = 0 then
  begin
    if FID_TYPE(a2^.Fid) = OBJ_TYPE_CRITTER then
    begin
      critterCount := obj_create_list(a2^.Tile, a2^.Elevation, OBJ_TYPE_CRITTER, @critters);
      endIndex := critterCount - 1;
      index := 0;
      while index < critterCount do
      begin
        critter_ := PPObject(PByte(critters) + index * SizeOf(PObject))^;
        if (critter_^.Data.AsData.Critter.Combat.Results and (DAM_DEAD or DAM_KNOCKED_OUT)) = 0 then
        begin
          PPObject(PByte(critters) + index * SizeOf(PObject))^ := PPObject(PByte(critters) + endIndex * SizeOf(PObject))^;
          PPObject(PByte(critters) + endIndex * SizeOf(PObject))^ := critter_;
          Dec(critterCount);
          Dec(index);
          Dec(endIndex);
        end
        else
          Inc(critterIndex);
        Inc(index);
      end;

      if critterCount = 1 then
      begin
        obj_delete_list(critters);
        critterCount := 0;
      end;

      if critterCount > 1 then
      begin
        for index := 0 to INVENTORY_ARROW_FRM_COUNT - 1 do
          arrowFrmHandles[index] := PCacheEntry(Pointer(-1));

        fid_ := art_id(OBJ_TYPE_INTERFACE, arrowFrmIds[INVENTORY_ARROW_FRM_LEFT_ARROW_UP], 0, 0, 0);
        buttonUpData := art_ptr_lock_data(fid_, 0, 0, @arrowFrmHandles[INVENTORY_ARROW_FRM_LEFT_ARROW_UP]);
        fid_ := art_id(OBJ_TYPE_INTERFACE, arrowFrmIds[INVENTORY_ARROW_FRM_LEFT_ARROW_DOWN], 0, 0, 0);
        buttonDownData := art_ptr_lock_data(fid_, 0, 0, @arrowFrmHandles[INVENTORY_ARROW_FRM_LEFT_ARROW_DOWN]);

        if (buttonUpData <> nil) and (buttonDownData <> nil) then
        begin
          btn := win_register_button(i_wid, 307, 149, 20, 18, -1, -1, KEY_PAGE_UP, -1, buttonUpData, buttonDownData, nil, 0);
          if btn <> -1 then
            win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
        end;

        fid_ := art_id(OBJ_TYPE_INTERFACE, arrowFrmIds[INVENTORY_ARROW_FRM_RIGHT_ARROW_UP], 0, 0, 0);
        buttonUpData := art_ptr_lock_data(fid_, 0, 0, @arrowFrmHandles[INVENTORY_ARROW_FRM_RIGHT_ARROW_UP]);
        fid_ := art_id(OBJ_TYPE_INTERFACE, arrowFrmIds[INVENTORY_ARROW_FRM_RIGHT_ARROW_DOWN], 0, 0, 0);
        buttonDownData := art_ptr_lock_data(fid_, 0, 0, @arrowFrmHandles[INVENTORY_ARROW_FRM_RIGHT_ARROW_DOWN]);

        if (buttonUpData <> nil) and (buttonDownData <> nil) then
        begin
          btn := win_register_button(i_wid, 327, 149, 20, 18, -1, -1, KEY_PAGE_DOWN, -1, buttonUpData, buttonDownData, nil, 0);
          if btn <> -1 then
            win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
        end;

        for index := 0 to critterCount - 1 do
          if a2 = PPObject(PByte(critters) + index * SizeOf(PObject))^ then
            critterIndex := index;
      end;
    end;
  end;

  display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
  display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
  display_body(a2^.Fid, INVENTORY_WINDOW_TYPE_LOOT);
  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);

  isCaughtStealing := False;
  stealingXp := 0;
  stealingXpBonus := 10;

  while True do
  begin
    sharedFpsLimiter.Mark;
    if game_user_wants_to_quit <> 0 then Break;
    if isCaughtStealing then Break;

    keyCode := get_input;
    if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
      game_quit_with_confirm;
    if game_user_wants_to_quit <> 0 then Break;

    if keyCode = KEY_UPPERCASE_A then
    begin
      if gIsSteal = 0 then
      begin
        if item_total_weight(a2) <= stat_level(a1, Integer(STAT_CARRY_WEIGHT)) - item_total_weight(a1) then
        begin
          item_move_all(a2, a1);
          display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
          display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
        end
        else
        begin
          messageListItem.num := 31;
          if message_search(@inventry_message_file, @messageListItem) then
            dialog_out(messageListItem.text, nil, 0, 169, 117, colorTable[32328], nil, colorTable[32328], 0);
        end;
      end;
    end
    else if keyCode = KEY_ARROW_UP then
    begin
      if stack_offset[curr_stack] > 0 then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
      end;
    end
    else if keyCode = KEY_PAGE_UP then
    begin
      if critterCount <> 0 then
      begin
        if critterIndex > 0 then Dec(critterIndex) else critterIndex := critterCount - 1;
        a2 := PPObject(PByte(critters) + critterIndex * SizeOf(PObject))^;
        target_pud := @a2^.Data.AsData.Inventory;
        target_stack[0] := a2;
        target_curr_stack := 0;
        target_stack_offset[0] := 0;
        display_target_inventory(0, -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
        display_body(a2^.Fid, INVENTORY_WINDOW_TYPE_LOOT);
      end;
    end
    else if keyCode = KEY_ARROW_DOWN then
    begin
      if stack_offset[curr_stack] + inven_cur_disp < pud^.Length then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
      end;
    end
    else if keyCode = KEY_PAGE_DOWN then
    begin
      if critterCount <> 0 then
      begin
        if critterIndex < critterCount - 1 then Inc(critterIndex) else critterIndex := 0;
        a2 := PPObject(PByte(critters) + critterIndex * SizeOf(PObject))^;
        target_pud := @a2^.Data.AsData.Inventory;
        target_stack[0] := a2;
        target_curr_stack := 0;
        target_stack_offset[0] := 0;
        display_target_inventory(0, -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
        display_body(a2^.Fid, INVENTORY_WINDOW_TYPE_LOOT);
      end;
    end
    else if keyCode = KEY_CTRL_ARROW_UP then
    begin
      if target_stack_offset[target_curr_stack] > 0 then
      begin
        target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] - 1;
        display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
        win_draw(i_wid);
      end;
    end
    else if keyCode = KEY_CTRL_ARROW_DOWN then
    begin
      if target_stack_offset[target_curr_stack] + inven_cur_disp < target_pud^.Length then
      begin
        target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] + 1;
        display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
        win_draw(i_wid);
      end;
    end
    else if (keyCode >= 2500) and (keyCode <= 2501) then
      container_exit(keyCode, INVENTORY_WINDOW_TYPE_LOOT)
    else
    begin
      if (mouse_get_buttons and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
      begin
        if immode = INVENTORY_WINDOW_CURSOR_HAND then inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW)
        else inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
      end
      else if (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
      begin
        if (keyCode >= 1000) and (keyCode <= 1000 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_LOOT)
          else
          begin
            index := keyCode - 1000;
            if index + stack_offset[curr_stack] < pud^.Length then
            begin
              gStealCount := gStealCount + 1;
              gStealSize := gStealSize + item_size(stack[curr_stack]);
              inventoryItem := @pud^.Items[index + stack_offset[curr_stack]];
              rc := move_inventory(inventoryItem^.Item, index, target_stack[target_curr_stack], True);
              if rc = 1 then isCaughtStealing := True
              else if rc = 2 then begin stealingXp := stealingXp + stealingXpBonus; stealingXpBonus := stealingXpBonus + 10; end;
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
            end;
            keyCode := -1;
          end;
        end
        else if (keyCode >= 2000) and (keyCode <= 2000 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_LOOT)
          else
          begin
            index := keyCode - 2000;
            if index + target_stack_offset[target_curr_stack] < target_pud^.Length then
            begin
              gStealCount := gStealCount + 1;
              gStealSize := gStealSize + item_size(stack[curr_stack]);
              inventoryItem := @target_pud^.Items[index + target_stack_offset[target_curr_stack]];
              rc := move_inventory(inventoryItem^.Item, index, target_stack[target_curr_stack], False);
              if rc = 1 then isCaughtStealing := True
              else if rc = 2 then begin stealingXp := stealingXp + stealingXpBonus; stealingXpBonus := stealingXpBonus + 10; end;
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT);
            end;
          end;
        end;
      end
      else if (mouse_get_buttons and MOUSE_EVENT_WHEEL) <> 0 then
      begin
        if mouseHitTestInWindow(i_wid, INVENTORY_LOOT_LEFT_SCROLLER_X, INVENTORY_LOOT_LEFT_SCROLLER_Y, INVENTORY_LOOT_LEFT_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_LOOT_LEFT_SCROLLER_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then begin if stack_offset[curr_stack] > 0 then begin stack_offset[curr_stack] := stack_offset[curr_stack] - 1; display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT); end; end
          else if wheelY < 0 then begin if stack_offset[curr_stack] + inven_cur_disp < pud^.Length then begin stack_offset[curr_stack] := stack_offset[curr_stack] + 1; display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_LOOT); end; end;
        end
        else if mouseHitTestInWindow(i_wid, INVENTORY_LOOT_RIGHT_SCROLLER_X, INVENTORY_LOOT_RIGHT_SCROLLER_Y, INVENTORY_LOOT_RIGHT_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_LOOT_RIGHT_SCROLLER_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then begin if target_stack_offset[target_curr_stack] > 0 then begin target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] - 1; display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT); win_draw(i_wid); end; end
          else if wheelY < 0 then begin if target_stack_offset[target_curr_stack] + inven_cur_disp < target_pud^.Length then begin target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] + 1; display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_LOOT); win_draw(i_wid); end; end;
        end;
      end;
    end;

    if keyCode = KEY_ESCAPE then Break;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if critterCount <> 0 then
  begin
    obj_delete_list(critters);
    for index := 0 to INVENTORY_ARROW_FRM_COUNT - 1 do
      art_ptr_unlock(arrowFrmHandles[index]);
  end;

  if gIsSteal <> 0 then
  begin
    if item1 <> nil then begin item1^.Flags := item1^.Flags or OBJECT_IN_LEFT_HAND; item_add_force(a2, item1, 1); end;
    if item2 <> nil then begin item2^.Flags := item2^.Flags or OBJECT_IN_RIGHT_HAND; item_add_force(a2, item2, 1); end;
    if armor <> nil then begin armor^.Flags := armor^.Flags or OBJECT_WORN; item_add_force(a2, armor, 1); end;
  end;

  item_move_all(a1a, a2);
  obj_erase_object(a1a, nil);

  if gIsSteal <> 0 then
  begin
    if not isCaughtStealing then
    begin
      if stealingXp > 0 then
      begin
        if not isPartyMember(a2) then
        begin
          if stealingXp > 300 - skill_level(a1, SKILL_STEAL) then
            stealingXp := 300 - skill_level(a1, SKILL_STEAL);
          messageListItem.num := 29;
          if message_search(@inventry_message_file, @messageListItem) then
          begin
            StrLFmt(formattedText, SizeOf(formattedText) - 1, messageListItem.text, [stealingXp]);
            display_print(@formattedText[0]);
          end;
          stat_pc_add_experience(stealingXp);
        end;
      end;
    end;
  end;

  exit_inventory(isoWasEnabled);
  inven_exit;

  if gIsSteal <> 0 then
    if isCaughtStealing then
      if gStealCount > 0 then
        if obj_sid(a2, @sid) <> -1 then
        begin
          scr_set_objs(sid, a1, nil);
          exec_script_proc(sid, SCRIPT_PROC_PICKUP);
          scr_ptr(sid, @script);
        end;

  Result := 0;
end;

function inven_steal_container(a1, a2: PObject): Integer;
begin
  if a1 = a2 then
    Exit(-1);

  gIsSteal := Ord(PID_TYPE(a1^.Pid) = OBJ_TYPE_CRITTER) * Ord(critter_is_active(a2));
  gStealCount := 0;
  gStealSize := 0;

  Result := loot_container(a1, a2);

  gIsSteal := 0;
  gStealCount := 0;
  gStealSize := 0;
end;

function move_inventory(a1: PObject; a2: Integer; a3: PObject; a4: Boolean): Integer;
var
  v38: Boolean;
  rect_: TRect;
  quantity, quantityToMove: Integer;
  inventoryItem: PInventoryItem;
  windowBuffer, data: PByte;
  handle: PCacheEntry;
  fid_: Integer;
  inventoryFrmHandle: PCacheEntry;
  inventoryFrm: PArt;
  width_, height_: Integer;
  rc: Integer;
  messageListItem: TMessageListItem;
begin
  v38 := True;

  if a4 then
  begin
    rect_.ulx := INVENTORY_LOOT_LEFT_SCROLLER_X;
    rect_.uly := INVENTORY_SLOT_HEIGHT * a2 + INVENTORY_LOOT_LEFT_SCROLLER_Y;
    inventoryItem := @pud^.Items[a2 + stack_offset[curr_stack]];
    quantity := inventoryItem^.Quantity;
    if quantity > 1 then
    begin
      display_inventory(stack_offset[curr_stack], a2, INVENTORY_WINDOW_TYPE_LOOT);
      v38 := False;
    end;
  end
  else
  begin
    rect_.ulx := INVENTORY_LOOT_RIGHT_SCROLLER_X;
    rect_.uly := INVENTORY_SLOT_HEIGHT * a2 + INVENTORY_LOOT_RIGHT_SCROLLER_Y;
    inventoryItem := @target_pud^.Items[a2 + target_stack_offset[target_curr_stack]];
    quantity := inventoryItem^.Quantity;
    if quantity > 1 then
    begin
      display_target_inventory(target_stack_offset[target_curr_stack], a2, target_pud, INVENTORY_WINDOW_TYPE_LOOT);
      win_draw(i_wid);
      v38 := False;
    end;
  end;

  if v38 then
  begin
    windowBuffer := win_get_buf(i_wid);
    fid_ := art_id(OBJ_TYPE_INTERFACE, 114, 0, 0, 0);
    data := art_ptr_lock_data(fid_, 0, 0, @handle);
    if data <> nil then
    begin
      buf_to_buf(data + INVENTORY_LOOT_WINDOW_WIDTH * rect_.uly + rect_.ulx,
        INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT, INVENTORY_LOOT_WINDOW_WIDTH,
        windowBuffer + INVENTORY_LOOT_WINDOW_WIDTH * rect_.uly + rect_.ulx,
        INVENTORY_LOOT_WINDOW_WIDTH);
      art_ptr_unlock(handle);
    end;
    rect_.lrx := rect_.ulx + INVENTORY_SLOT_WIDTH - 1;
    rect_.lry := rect_.uly + INVENTORY_SLOT_HEIGHT - 1;
    win_draw_rect(i_wid, @rect_);
  end;

  fid_ := item_inv_fid(a1);
  inventoryFrm := art_ptr_lock(fid_, @inventoryFrmHandle);
  if inventoryFrm <> nil then
  begin
    width_ := art_frame_width(inventoryFrm, 0, 0);
    height_ := art_frame_length(inventoryFrm, 0, 0);
    data := art_frame_data(inventoryFrm, 0, 0);
    mouse_set_shape(data, width_, height_, width_, width_ div 2, height_ div 2, #0);
    gsound_play_sfx_file('ipickup1');
  end;

  repeat
    sharedFpsLimiter.Mark;
    get_input;
    renderPresent;
    sharedFpsLimiter.Throttle;
  until (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0;

  if inventoryFrm <> nil then
  begin
    art_ptr_unlock(inventoryFrmHandle);
    gsound_play_sfx_file('iputdown');
  end;

  rc := 0;

  if a4 then
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_LOOT_RIGHT_SCROLLER_X, INVENTORY_LOOT_RIGHT_SCROLLER_Y, INVENTORY_LOOT_RIGHT_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_LOOT_RIGHT_SCROLLER_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;

      if quantityToMove <> -1 then
      begin
        if gIsSteal <> 0 then
          if skill_check_stealing(inven_dude, a3, a1, True) = 0 then
            rc := 1;

        if rc <> 1 then
        begin
          if item_move(inven_dude, a3, a1, quantityToMove) <> -1 then
            rc := 2
          else
          begin
            messageListItem.num := 26;
            if message_search(@inventry_message_file, @messageListItem) then
              display_print(messageListItem.text);
          end;
        end;
      end;
    end;
  end
  else
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_LOOT_LEFT_SCROLLER_X, INVENTORY_LOOT_LEFT_SCROLLER_Y, INVENTORY_LOOT_LEFT_SCROLLER_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_LOOT_LEFT_SCROLLER_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;

      if quantityToMove <> -1 then
      begin
        if gIsSteal <> 0 then
          if skill_check_stealing(inven_dude, a3, a1, False) = 0 then
            rc := 1;

        if rc <> 1 then
        begin
          if item_move(a3, inven_dude, a1, quantityToMove) = 0 then
          begin
            if (a1^.Flags and OBJECT_IN_RIGHT_HAND) <> 0 then
              a3^.Fid := art_id(FID_TYPE(a3^.Fid), a3^.Fid and $FFF, FID_ANIM_TYPE(a3^.Fid), 0, a3^.Rotation + 1);
            a3^.Flags := a3^.Flags and (not OBJECT_EQUIPPED);
            rc := 2;
          end
          else
          begin
            messageListItem.num := 25;
            if message_search(@inventry_message_file, @messageListItem) then
              display_print(messageListItem.text);
          end;
        end;
      end;
    end;
  end;

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
  Result := rc;
end;

procedure barter_inventory(win: Integer; a2, a3, a4: PObject; a5: Integer);
var
  armor, item1, item2, a1a: PObject;
  isoWasEnabled: Boolean;
  modifier, npcReactionValue, npcReactionType: Integer;
  keyCode, index: Integer;
  messageListItem: TMessageListItem;
  inventoryItem: PInventoryItem;
  wheelX, wheelY: Integer;
begin
  barter_mod := a5;

  if inven_init = -1 then
    Exit;

  armor := inven_worn(a2);
  if armor <> nil then
    item_remove_mult(a2, armor, 1);

  item1 := nil;
  item2 := inven_right_hand(a2);
  if item2 <> nil then
    item_remove_mult(a2, item2, 1)
  else
  begin
    item1 := inven_find_type(a2, ITEM_TYPE_WEAPON, nil);
    if item1 <> nil then
      item_remove_mult(a2, item1, 1);
  end;

  a1a := nil;
  if obj_new(@a1a, 0, 467) = -1 then
    Exit;

  pud := @inven_dude^.Data.AsData.Inventory;
  btable := a4;
  ptable := a3;

  ptable_offset := 0;
  btable_offset := 0;

  ptable_pud := @a3^.Data.AsData.Inventory;
  btable_pud := @a4^.Data.AsData.Inventory;

  barter_back_win := win;
  target_curr_stack := 0;
  target_pud := @a2^.Data.AsData.Inventory;

  target_stack[0] := a2;
  target_stack_offset[0] := 0;

  isoWasEnabled := setup_inventory(INVENTORY_WINDOW_TYPE_TRADE);
  display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
  display_inventory(stack_offset[0], -1, INVENTORY_WINDOW_TYPE_TRADE);
  display_body(a2^.Fid, INVENTORY_WINDOW_TYPE_TRADE);
  win_draw(barter_back_win);
  display_table_inventories(win, a3, a4, -1);

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);

  npcReactionValue := reaction_get(a2);
  npcReactionType := reaction_to_level(npcReactionValue);
  case npcReactionType of
    NPC_REACTION_BAD:     modifier := -25;
    NPC_REACTION_NEUTRAL: modifier := 0;
    NPC_REACTION_GOOD:    modifier := 50;
  else
    modifier := 0;
  end;

  keyCode := -1;
  while True do
  begin
    sharedFpsLimiter.Mark;

    if (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
      Break;

    keyCode := get_input;
    if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
      game_quit_with_confirm;

    if game_user_wants_to_quit <> 0 then
      Break;

    barter_mod := a5 + modifier;

    if (keyCode = KEY_LOWERCASE_T) or (modifier <= -30) then
    begin
      item_move_all(a4, a2);
      item_move_all(a3, obj_dude);
      barter_end_to_talk_to;
      Break;
    end
    else if keyCode = KEY_LOWERCASE_M then
    begin
      if (a3^.Data.AsData.Inventory.Length <> 0) or (btable^.Data.AsData.Inventory.Length <> 0) then
      begin
        if barter_attempt_transaction(inven_dude, a3, a2, a4) = 0 then
        begin
          display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
          display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
          display_table_inventories(win, a3, a4, -1);
          // Ok, that's a good trade.
          messageListItem.num := 27;
        end
        else
        begin
          // No, your offer is not good enough.
          messageListItem.num := 28;
        end;

        if message_search(@inventry_message_file, @messageListItem) then
          gdialog_display_msg(messageListItem.text);
      end;
    end
    else if keyCode = KEY_ARROW_UP then
    begin
      if stack_offset[curr_stack] > 0 then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
      end;
    end
    else if keyCode = KEY_PAGE_UP then
    begin
      if ptable_offset > 0 then
      begin
        ptable_offset := ptable_offset - 1;
        display_table_inventories(win, a3, a4, -1);
      end;
    end
    else if keyCode = KEY_ARROW_DOWN then
    begin
      if stack_offset[curr_stack] + inven_cur_disp < pud^.Length then
      begin
        stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
        display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
      end;
    end
    else if keyCode = KEY_PAGE_DOWN then
    begin
      if ptable_offset + inven_cur_disp < ptable_pud^.Length then
      begin
        ptable_offset := ptable_offset + 1;
        display_table_inventories(win, a3, a4, -1);
      end;
    end
    else if keyCode = KEY_CTRL_PAGE_DOWN then
    begin
      if btable_offset + inven_cur_disp < btable_pud^.Length then
      begin
        btable_offset := btable_offset + 1;
        display_table_inventories(win, a3, a4, -1);
      end;
    end
    else if keyCode = KEY_CTRL_PAGE_UP then
    begin
      if btable_offset > 0 then
      begin
        btable_offset := btable_offset - 1;
        display_table_inventories(win, a3, a4, -1);
      end;
    end
    else if keyCode = KEY_CTRL_ARROW_UP then
    begin
      if target_stack_offset[target_curr_stack] > 0 then
      begin
        target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] - 1;
        display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
        win_draw(i_wid);
      end;
    end
    else if keyCode = KEY_CTRL_ARROW_DOWN then
    begin
      if target_stack_offset[target_curr_stack] + inven_cur_disp < target_pud^.Length then
      begin
        target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] + 1;
        display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
        win_draw(i_wid);
      end;
    end
    else if (keyCode >= 2500) and (keyCode <= 2501) then
    begin
      container_exit(keyCode, INVENTORY_WINDOW_TYPE_TRADE);
    end
    else
    begin
      if (mouse_get_buttons and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
      begin
        if immode = INVENTORY_WINDOW_CURSOR_HAND then
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW)
        else
          inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
      end
      else if (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
      begin
        if (keyCode >= 1000) and (keyCode <= 1000 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
          begin
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_TRADE);
            display_table_inventories(win, a3, nil, -1);
          end
          else
          begin
            index := keyCode - 1000;
            if index + stack_offset[curr_stack] < pud^.Length then
            begin
              inventoryItem := @pud^.Items[index + stack_offset[curr_stack]];
              barter_move_inventory(inventoryItem^.Item, inventoryItem^.Quantity, index, stack_offset[curr_stack], a2, a3, True);
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
              display_table_inventories(win, a3, nil, -1);
            end;
          end;
          keyCode := -1;
        end
        else if (keyCode >= 2000) and (keyCode <= 2000 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
          begin
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_TRADE);
            display_table_inventories(win, nil, a4, -1);
          end
          else
          begin
            index := keyCode - 2000;
            if index + target_stack_offset[target_curr_stack] < target_pud^.Length then
            begin
              inventoryItem := @target_pud^.Items[index + target_stack_offset[target_curr_stack]];
              barter_move_inventory(inventoryItem^.Item, inventoryItem^.Quantity, index, target_stack_offset[target_curr_stack], a2, a4, False);
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
              display_table_inventories(win, nil, a4, -1);
            end;
          end;
          keyCode := -1;
        end
        else if (keyCode >= 2300) and (keyCode <= 2300 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
          begin
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_TRADE);
            display_table_inventories(win, a3, nil, -1);
          end
          else
          begin
            index := keyCode - 2300;
            if index < ptable_pud^.Length then
            begin
              inventoryItem := @ptable_pud^.Items[index + ptable_offset];
              barter_move_from_table_inventory(inventoryItem^.Item, inventoryItem^.Quantity, index, a2, a3, True);
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
              display_table_inventories(win, a3, nil, -1);
            end;
          end;
          keyCode := -1;
        end
        else if (keyCode >= 2400) and (keyCode <= 2400 + inven_cur_disp) then
        begin
          if immode = INVENTORY_WINDOW_CURSOR_ARROW then
          begin
            inven_action_cursor(keyCode, INVENTORY_WINDOW_TYPE_TRADE);
            display_table_inventories(win, nil, a4, -1);
          end
          else
          begin
            index := keyCode - 2400;
            if index < btable_pud^.Length then
            begin
              inventoryItem := @btable_pud^.Items[index + btable_offset];
              barter_move_from_table_inventory(inventoryItem^.Item, inventoryItem^.Quantity, index, a2, a4, False);
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
              display_table_inventories(win, nil, a4, -1);
            end;
          end;
          keyCode := -1;
        end;
      end
      else if (mouse_get_buttons and MOUSE_EVENT_WHEEL) <> 0 then
      begin
        if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_X, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if stack_offset[curr_stack] > 0 then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] - 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
            end;
          end
          else if wheelY < 0 then
          begin
            if stack_offset[curr_stack] + inven_cur_disp < pud^.Length then
            begin
              stack_offset[curr_stack] := stack_offset[curr_stack] + 1;
              display_inventory(stack_offset[curr_stack], -1, INVENTORY_WINDOW_TYPE_TRADE);
            end;
          end;
        end
        else if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_X, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if ptable_offset > 0 then
            begin
              ptable_offset := ptable_offset - 1;
              display_table_inventories(win, a3, a4, -1);
            end;
          end
          else if wheelY < 0 then
          begin
            if ptable_offset + inven_cur_disp < ptable_pud^.Length then
            begin
              ptable_offset := ptable_offset + 1;
              display_table_inventories(win, a3, a4, -1);
            end;
          end;
        end
        else if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_X, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if target_stack_offset[target_curr_stack] > 0 then
            begin
              target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] - 1;
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              win_draw(i_wid);
            end;
          end
          else if wheelY < 0 then
          begin
            if target_stack_offset[target_curr_stack] + inven_cur_disp < target_pud^.Length then
            begin
              target_stack_offset[target_curr_stack] := target_stack_offset[target_curr_stack] + 1;
              display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
              win_draw(i_wid);
            end;
          end;
        end
        else if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_X, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_Y) then
        begin
          mouseGetWheel(@wheelX, @wheelY);
          if wheelY > 0 then
          begin
            if btable_offset > 0 then
            begin
              btable_offset := btable_offset - 1;
              display_table_inventories(win, a3, a4, -1);
            end;
          end
          else if wheelY < 0 then
          begin
            if btable_offset + inven_cur_disp < btable_pud^.Length then
            begin
              btable_offset := btable_offset + 1;
              display_table_inventories(win, a3, a4, -1);
            end;
          end;
        end;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  item_move_all(a1a, a2);
  obj_erase_object(a1a, nil);

  if armor <> nil then
  begin
    armor^.Flags := armor^.Flags or OBJECT_WORN;
    item_add_force(a2, armor, 1);
  end;

  if item2 <> nil then
  begin
    item2^.Flags := item2^.Flags or OBJECT_IN_RIGHT_HAND;
    item_add_force(a2, item2, 1);
  end;

  if item1 <> nil then
    item_add_force(a2, item1, 1);

  exit_inventory(isoWasEnabled);

  // NOTE: Uninline.
  inven_exit;
end;

procedure container_enter(keyCode, inventoryWindowType: Integer);
var
  index: Integer;
  inventoryItem: PInventoryItem;
  item_: PObject;
begin
  if keyCode >= 2000 then
  begin
    index := target_stack_offset[target_curr_stack] + keyCode - 2000;
    if (index < target_pud^.Length) and (target_curr_stack < 9) then
    begin
      inventoryItem := @target_pud^.Items[index];
      item_ := inventoryItem^.Item;
      if item_get_type(item_) = ITEM_TYPE_CONTAINER then
      begin
        target_curr_stack := target_curr_stack + 1;
        target_stack[target_curr_stack] := item_;
        target_stack_offset[target_curr_stack] := 0;
        target_pud := @item_^.Data.AsData.Inventory;
        display_body(item_^.Fid, inventoryWindowType);
        display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, inventoryWindowType);
        win_draw(i_wid);
      end;
    end;
  end
  else
  begin
    index := stack_offset[curr_stack] + keyCode - 1000;
    if (index < pud^.Length) and (curr_stack < 9) then
    begin
      inventoryItem := @pud^.Items[index];
      item_ := inventoryItem^.Item;
      if item_get_type(item_) = ITEM_TYPE_CONTAINER then
      begin
        curr_stack := curr_stack + 1;
        stack[curr_stack] := item_;
        stack_offset[curr_stack] := 0;
        inven_dude := stack[curr_stack];
        pud := @item_^.Data.AsData.Inventory;
        adjust_fid;
        display_body(-1, inventoryWindowType);
        display_inventory(stack_offset[curr_stack], -1, inventoryWindowType);
      end;
    end;
  end;
end;

procedure container_exit(keyCode, inventoryWindowType: Integer);
var
  v5: PObject;
begin
  if keyCode = 2500 then
  begin
    if curr_stack > 0 then
    begin
      curr_stack := curr_stack - 1;
      inven_dude := stack[curr_stack];
      pud := @inven_dude^.Data.AsData.Inventory;
      adjust_fid;
      display_body(-1, inventoryWindowType);
      display_inventory(stack_offset[curr_stack], -1, inventoryWindowType);
    end;
  end
  else if keyCode = 2501 then
  begin
    if target_curr_stack > 0 then
    begin
      target_curr_stack := target_curr_stack - 1;
      v5 := target_stack[target_curr_stack];
      target_pud := @v5^.Data.AsData.Inventory;
      display_body(v5^.Fid, inventoryWindowType);
      display_target_inventory(target_stack_offset[target_curr_stack], -1, target_pud, inventoryWindowType);
      win_draw(i_wid);
    end;
  end;
end;

function drop_into_container(a1, a2: PObject; a3: Integer; a4: PPObject; quantity: Integer): Integer;
var
  quantityToMove, rc: Integer;
begin
  if quantity > 1 then
    quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a2, quantity)
  else
    quantityToMove := 1;

  if quantityToMove = -1 then
    Exit(-1);

  if a3 <> -1 then
  begin
    if item_remove_mult(inven_dude, a2, quantityToMove) = -1 then
      Exit(-1);
  end;

  rc := item_add_mult(a1, a2, quantityToMove);
  if rc <> 0 then
  begin
    if a3 <> -1 then
      item_add_mult(inven_dude, a2, quantityToMove);
  end
  else
  begin
    if a4 <> nil then
    begin
      if a4 = @i_worn then
        adjust_ac(stack[0], i_worn, nil);
      a4^ := nil;
    end;
  end;

  Result := rc;
end;

function drop_ammo_into_weapon(weapon, ammo: PObject; a3: PPObject; quantity, keyCode: Integer): Integer;
var
  quantityToMove: Integer;
  v14: PObject;
  v17: Boolean;
  rc, index, v11: Integer;
  sfx: PAnsiChar;
begin
  if item_get_type(weapon) <> ITEM_TYPE_WEAPON then
    Exit(-1);
  if item_get_type(ammo) <> ITEM_TYPE_AMMO then
    Exit(-1);
  if not item_w_can_reload(weapon, ammo) then
    Exit(-1);

  if quantity > 1 then
    quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, ammo, quantity)
  else
    quantityToMove := 1;

  if quantityToMove = -1 then
    Exit(-1);

  v14 := ammo;
  v17 := False;
  rc := item_remove_mult(inven_dude, weapon, 1);

  index := 0;
  while index < quantityToMove do
  begin
    v11 := item_w_reload(weapon, v14);
    if v11 = 0 then
    begin
      if a3 <> nil then
        a3^ := nil;

      obj_destroy(v14);

      v17 := True;
      if inven_from_button(keyCode, @v14, nil, nil) = 0 then
        Break;
    end;
    if v11 <> -1 then
      v17 := True;
    if v11 <> 0 then
      Break;
    index := index + 1;
  end;

  if rc <> -1 then
    item_add_force(inven_dude, weapon, 1);

  if not v17 then
    Exit(-1);

  sfx := gsnd_build_weapon_sfx_name(WEAPON_SOUND_EFFECT_READY, weapon, HIT_MODE_RIGHT_WEAPON_PRIMARY, nil);
  gsound_play_sfx_file(sfx);

  Result := 0;
end;

procedure draw_amount(value, inventoryWindowType: Integer);
var
  handle: PCacheEntry;
  fid_: Integer;
  data, windowBuffer: PByte;
  rect_: TRect;
  windowWidth: Integer;
  ranks: array[0..2] of Integer;
  index: Integer;
begin
  fid_ := art_id(OBJ_TYPE_INTERFACE, 170, 0, 0, 0);
  data := art_ptr_lock_data(fid_, 0, 0, @handle);
  if data = nil then
    Exit;

  windowWidth := win_width(mt_wid);
  windowBuffer := win_get_buf(mt_wid);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
  begin
    rect_.ulx := 153;
    rect_.uly := 45;
    rect_.lrx := 195;
    rect_.lry := 69;

    ranks[2] := value mod 10;
    ranks[1] := (value div 10) mod 10;
    ranks[0] := (value div 100) mod 10;

    windowBuffer := windowBuffer + rect_.uly * windowWidth + rect_.ulx;
    for index := 0 to 2 do
    begin
      buf_to_buf(data + 14 * ranks[index], 14, 24, 336, windowBuffer, windowWidth);
      windowBuffer := windowBuffer + 14;
    end;
  end
  else
  begin
    rect_.ulx := 133;
    rect_.uly := 64;
    rect_.lrx := 189;
    rect_.lry := 88;

    windowBuffer := windowBuffer + windowWidth * rect_.uly + rect_.ulx;
    buf_to_buf(data + 14 * (value div 60), 14, 24, 336, windowBuffer, windowWidth);
    buf_to_buf(data + 14 * ((value mod 60) div 10), 14, 24, 336, windowBuffer + 14 * 2, windowWidth);
    buf_to_buf(data + 14 * (value mod 10), 14, 24, 336, windowBuffer + 14 * 3, windowWidth);
  end;

  art_ptr_unlock(handle);
  win_draw_rect(mt_wid, @rect_);
end;

function do_move_timer(inventoryWindowType: Integer; item_: PObject; max: Integer): Integer;
var
  value, min_, keyCode, number: Integer;
  v5: Boolean;
begin
  setup_move_timer_win(inventoryWindowType, item_);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
  begin
    value := 1;
    if max > 999 then
      max := 999;
    min_ := 1;
  end
  else
  begin
    value := 60;
    min_ := 10;
  end;

  draw_amount(value, inventoryWindowType);

  v5 := False;
  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;
    if keyCode = KEY_ESCAPE then
    begin
      exit_move_timer_win(inventoryWindowType);
      Exit(-1);
    end;

    if keyCode = KEY_RETURN then
    begin
      if (value >= min_) and (value <= max) then
      begin
        if (inventoryWindowType <> INVENTORY_WINDOW_TYPE_SET_TIMER) or ((value mod 10) = 0) then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          Break;
        end;
      end;
      gsound_play_sfx_file('iisxxxx1');
    end
    else if keyCode = 5000 then
    begin
      v5 := False;
      value := max;
      draw_amount(value, inventoryWindowType);
    end
    else if keyCode = 6000 then
    begin
      v5 := False;
      if value < max then
      begin
        if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
          value := value + 1
        else
          value := value + 10;
        draw_amount(value, inventoryWindowType);
        Continue;
      end;
    end
    else if keyCode = 7000 then
    begin
      v5 := False;
      if value > min_ then
      begin
        if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
          value := value - 1
        else
          value := value - 10;
        draw_amount(value, inventoryWindowType);
        Continue;
      end;
    end;

    if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
    begin
      if (keyCode >= KEY_0) and (keyCode <= KEY_9) then
      begin
        number := keyCode - KEY_0;
        if not v5 then
          value := 0;
        value := (10 * value) mod 1000 + number;
        v5 := True;
        draw_amount(value, inventoryWindowType);
        Continue;
      end
      else if keyCode = KEY_BACKSPACE then
      begin
        if not v5 then
          value := 0;
        value := value div 10;
        v5 := True;
        draw_amount(value, inventoryWindowType);
        Continue;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  exit_move_timer_win(inventoryWindowType);
  Result := value;
end;

function setup_move_timer_win(inventoryWindowType: Integer; item_: PObject): Integer;
var
  oldFont: Integer;
  index: Integer;
  windowDescription: PInventoryWindowDescription;
  quantityWindowX, quantityWindowY: Integer;
  windowBuffer, backgroundData, buttonUpData, buttonDownData, overlayFrmData: PByte;
  backgroundHandle, overlayFrmHandle: PCacheEntry;
  backgroundFid, fid_, btn, overlayFid: Integer;
  messageListItem: TMessageListItem;
  length_, x, y: Integer;
begin
  oldFont := text_curr;
  text_font(103);

  for index := 0 to 7 do
    mt_key[index] := nil;

  windowDescription := @iscr_data[inventoryWindowType];

  if screenGetWidth <> 640 then
    quantityWindowX := (screenGetWidth - windowDescription^.width) div 2
  else
    quantityWindowX := windowDescription^.x;
  if screenGetHeight <> 480 then
    quantityWindowY := (screenGetHeight - windowDescription^.height) div 2
  else
    quantityWindowY := windowDescription^.y;

  mt_wid := win_add(quantityWindowX, quantityWindowY, windowDescription^.width, windowDescription^.height, 257, WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  windowBuffer := win_get_buf(mt_wid);

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, windowDescription^.field_0, 0, 0, 0);
  backgroundData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundHandle);
  if backgroundData <> nil then
  begin
    buf_to_buf(backgroundData, windowDescription^.width, windowDescription^.height, windowDescription^.width, windowBuffer, windowDescription^.width);
    art_ptr_unlock(backgroundHandle);
  end;

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
  begin
    messageListItem.num := 21;
    if message_search(@inventry_message_file, @messageListItem) then
    begin
      length_ := text_width(messageListItem.text);
      text_to_buf(windowBuffer + windowDescription^.width * 9 + (windowDescription^.width - length_) div 2,
        messageListItem.text, 200, windowDescription^.width, colorTable[21091]);
    end;
  end
  else if inventoryWindowType = INVENTORY_WINDOW_TYPE_SET_TIMER then
  begin
    messageListItem.num := 23;
    if message_search(@inventry_message_file, @messageListItem) then
    begin
      length_ := text_width(messageListItem.text);
      text_to_buf(windowBuffer + windowDescription^.width * 9 + (windowDescription^.width - length_) div 2,
        messageListItem.text, 200, windowDescription^.width, colorTable[21091]);
    end;

    overlayFid := art_id(OBJ_TYPE_INTERFACE, 306, 0, 0, 0);
    overlayFrmData := art_ptr_lock_data(overlayFid, 0, 0, @overlayFrmHandle);
    if overlayFrmData <> nil then
    begin
      buf_to_buf(overlayFrmData, 105, 81, 105, windowBuffer + 34 * windowDescription^.width + 113, windowDescription^.width);
      art_ptr_unlock(overlayFrmHandle);
    end;
  end;

  fid_ := item_inv_fid(item_);
  scale_art(fid_, windowBuffer + windowDescription^.width * 46 + 16, INVENTORY_LARGE_SLOT_WIDTH, INVENTORY_LARGE_SLOT_HEIGHT, windowDescription^.width);

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
  begin
    x := 200;
    y := 46;
  end
  else
  begin
    x := 194;
    y := 64;
  end;

  // Plus button
  fid_ := art_id(OBJ_TYPE_INTERFACE, 193, 0, 0, 0);
  buttonUpData := art_ptr_lock_data(fid_, 0, 0, @mt_key[0]);
  fid_ := art_id(OBJ_TYPE_INTERFACE, 194, 0, 0, 0);
  buttonDownData := art_ptr_lock_data(fid_, 0, 0, @mt_key[1]);

  if (buttonUpData <> nil) and (buttonDownData <> nil) then
  begin
    btn := win_register_button(mt_wid, x, y, 16, 12, -1, -1, 6000, -1, buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
  end;

  // Minus button
  fid_ := art_id(OBJ_TYPE_INTERFACE, 191, 0, 0, 0);
  buttonUpData := art_ptr_lock_data(fid_, 0, 0, @mt_key[2]);
  fid_ := art_id(OBJ_TYPE_INTERFACE, 192, 0, 0, 0);
  buttonDownData := art_ptr_lock_data(fid_, 0, 0, @mt_key[3]);

  if (buttonUpData <> nil) and (buttonDownData <> nil) then
  begin
    btn := win_register_button(mt_wid, x, y + 12, 17, 12, -1, -1, 7000, -1, buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
  end;

  // Done / Cancel
  fid_ := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  buttonUpData := art_ptr_lock_data(fid_, 0, 0, @mt_key[4]);
  fid_ := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  buttonDownData := art_ptr_lock_data(fid_, 0, 0, @mt_key[5]);

  if (buttonUpData <> nil) and (buttonDownData <> nil) then
  begin
    btn := win_register_button(mt_wid, 98, 128, 15, 16, -1, -1, -1, KEY_RETURN, buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

    btn := win_register_button(mt_wid, 148, 128, 15, 16, -1, -1, -1, KEY_ESCAPE, buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
  end;

  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
  begin
    fid_ := art_id(OBJ_TYPE_INTERFACE, 307, 0, 0, 0);
    buttonUpData := art_ptr_lock_data(fid_, 0, 0, @mt_key[6]);
    fid_ := art_id(OBJ_TYPE_INTERFACE, 308, 0, 0, 0);
    buttonDownData := art_ptr_lock_data(fid_, 0, 0, @mt_key[7]);

    if (buttonUpData <> nil) and (buttonDownData <> nil) then
    begin
      messageListItem.num := 22;
      if message_search(@inventry_message_file, @messageListItem) then
      begin
        length_ := text_width(messageListItem.text);
        text_to_buf(buttonUpData + (94 - length_) div 2 + 376, messageListItem.text, 200, 94, colorTable[21091]);
        text_to_buf(buttonDownData + (94 - length_) div 2 + 376, messageListItem.text, 200, 94, colorTable[18977]);

        btn := win_register_button(mt_wid, 120, 80, 94, 33, -1, -1, -1, 5000, buttonUpData, buttonDownData, nil, BUTTON_FLAG_TRANSPARENT);
        if btn <> -1 then
          win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
      end;
    end;
  end;

  win_draw(mt_wid);
  inven_set_mouse(INVENTORY_WINDOW_CURSOR_ARROW);
  text_font(oldFont);

  Result := 0;
end;

function exit_move_timer_win(inventoryWindowType: Integer): Integer;
var
  count, index: Integer;
begin
  if inventoryWindowType = INVENTORY_WINDOW_TYPE_MOVE_ITEMS then
    count := 8
  else
    count := 6;

  for index := 0 to count - 1 do
    art_ptr_unlock(mt_key[index]);

  win_delete(mt_wid);
  Result := 0;
end;

function inven_set_timer(a1: PObject): Integer;
var
  v1: Boolean;
  seconds: Integer;
begin
  v1 := inven_is_initialized;

  if not v1 then
  begin
    if inven_init = -1 then
      Exit(-1);
  end;

  seconds := do_move_timer(INVENTORY_WINDOW_TYPE_SET_TIMER, a1, 180);

  if not v1 then
    inven_exit;

  Result := seconds;
end;

function barter_compute_value(buyer, seller: PObject): Integer;
var
  modVal, buyer_mod, seller_mod, cost, caps: Integer;
begin
  modVal := 100;
  if buyer = obj_dude then
  begin
    if perk_level(PERK_MASTER_TRADER) <> 0 then
      modVal := modVal + 25;
  end;

  buyer_mod := skill_level(buyer, SKILL_BARTER);
  seller_mod := skill_level(seller, SKILL_BARTER);
  modVal := modVal + buyer_mod - seller_mod + barter_mod;

  modVal := EnsureRange(modVal, 10, 300);

  cost := item_total_cost(btable);
  caps := item_caps_total(btable);

  Result := 100 * (cost - caps) div modVal + caps;
end;

function barter_attempt_transaction(a1, a2, a3, a4: PObject): Integer;
begin
  if a2^.Data.AsData.Inventory.Length = 0 then
    Exit(-1);
  if item_queued(a2) <> 0 then
    Exit(-1);
  if barter_compute_value(a1, a3) > item_total_cost(a2) then
    Exit(-1);
  item_move_all(a4, a1);
  item_move_all(a2, a3);
  Result := 0;
end;

procedure barter_move_inventory(a1: PObject; quantity, a3, a4: Integer; a5, a6: PObject; a7: Boolean);
var
  rect_: TRect;
  dest, src: PByte;
  pitch: Integer;
  inventoryFrmHandle: PCacheEntry;
  inventoryFid: Integer;
  inventoryFrm: Pointer;
  width_, height_: Integer;
  data: PByte;
  messageListItem: TMessageListItem;
  quantityToMove: Integer;
begin
  if a7 then
  begin
    rect_.ulx := 23;
    rect_.uly := 48 * a3 + 34;
  end
  else
  begin
    rect_.ulx := 395;
    rect_.uly := 48 * a3 + 31;
  end;

  if quantity > 1 then
  begin
    if a7 then
      display_inventory(a4, a3, INVENTORY_WINDOW_TYPE_TRADE)
    else
      display_target_inventory(a4, a3, target_pud, INVENTORY_WINDOW_TYPE_TRADE);
  end
  else
  begin
    dest := win_get_buf(i_wid);
    src := win_get_buf(barter_back_win);

    pitch := INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH;
    buf_to_buf(src + pitch * rect_.uly + rect_.ulx + INVENTORY_TRADE_WINDOW_OFFSET, INVENTORY_SLOT_WIDTH, INVENTORY_SLOT_HEIGHT, pitch, dest + INVENTORY_TRADE_WINDOW_WIDTH * rect_.uly + rect_.ulx, INVENTORY_TRADE_WINDOW_WIDTH);

    rect_.lrx := rect_.ulx + INVENTORY_SLOT_WIDTH - 1;
    rect_.lry := rect_.uly + INVENTORY_SLOT_HEIGHT - 1;
    win_draw_rect(i_wid, @rect_);
  end;

  inventoryFid := item_inv_fid(a1);
  inventoryFrm := art_ptr_lock(inventoryFid, @inventoryFrmHandle);
  if inventoryFrm <> nil then
  begin
    width_ := art_frame_width(inventoryFrm, 0, 0);
    height_ := art_frame_length(inventoryFrm, 0, 0);
    data := art_frame_data(inventoryFrm, 0, 0);
    mouse_set_shape(data, width_, height_, width_, width_ div 2, height_ div 2, #0);
    gsound_play_sfx_file('ipickup1');
  end;

  repeat
    sharedFpsLimiter.Mark;
    get_input;
    renderPresent;
    sharedFpsLimiter.Throttle;
  until (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0;

  if inventoryFrm <> nil then
  begin
    art_ptr_unlock(inventoryFrmHandle);
    gsound_play_sfx_file('iputdown');
  end;

  if a7 then
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_X, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_INNER_LEFT_SCROLLER_TRACKING_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;
      if quantityToMove <> -1 then
      begin
        if item_move_force(inven_dude, a6, a1, quantityToMove) = -1 then
        begin
          // There is no space left for that item.
          messageListItem.num := 26;
          if message_search(@inventry_message_file, @messageListItem) then
            display_print(messageListItem.text);
        end;
      end;
    end;
  end
  else
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_X, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_TRACKING_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;
      if quantityToMove <> -1 then
      begin
        if item_move_force(a5, a6, a1, quantityToMove) = -1 then
        begin
          // You cannot pick that up. You are at your maximum weight capacity.
          messageListItem.num := 25;
          if message_search(@inventry_message_file, @messageListItem) then
            display_print(messageListItem.text);
        end;
      end;
    end;
  end;

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
end;

procedure barter_move_from_table_inventory(a1: PObject; quantity, a3: Integer; a4, a5: PObject; a6: Boolean);
var
  rect_: TRect;
  dest, src: PByte;
  pitch: Integer;
  inventoryFrmHandle: PCacheEntry;
  inventoryFid: Integer;
  inventoryFrm: Pointer;
  width_, height_: Integer;
  data: PByte;
  messageListItem: TMessageListItem;
  quantityToMove: Integer;
begin
  if a6 then
  begin
    rect_.ulx := INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD;
    rect_.uly := INVENTORY_SLOT_HEIGHT * a3 + INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y_PAD;
  end
  else
  begin
    rect_.ulx := INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD;
    rect_.uly := INVENTORY_SLOT_HEIGHT * a3 + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y_PAD;
  end;

  if quantity > 1 then
  begin
    if a6 then
      display_table_inventories(barter_back_win, a5, nil, a3)
    else
      display_table_inventories(barter_back_win, nil, a5, a3);
  end
  else
  begin
    dest := win_get_buf(i_wid);
    src := win_get_buf(barter_back_win);

    pitch := INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH;
    buf_to_buf(src + pitch * rect_.uly + rect_.ulx + INVENTORY_TRADE_WINDOW_OFFSET,
      INVENTORY_SLOT_WIDTH,
      INVENTORY_SLOT_HEIGHT,
      pitch,
      dest + INVENTORY_TRADE_WINDOW_WIDTH * rect_.uly + rect_.ulx,
      INVENTORY_TRADE_WINDOW_WIDTH);

    rect_.lrx := rect_.ulx + INVENTORY_SLOT_WIDTH - 1;
    rect_.lry := rect_.uly + INVENTORY_SLOT_HEIGHT - 1;
    win_draw_rect(i_wid, @rect_);
  end;

  inventoryFid := item_inv_fid(a1);
  inventoryFrm := art_ptr_lock(inventoryFid, @inventoryFrmHandle);
  if inventoryFrm <> nil then
  begin
    width_ := art_frame_width(inventoryFrm, 0, 0);
    height_ := art_frame_length(inventoryFrm, 0, 0);
    data := art_frame_data(inventoryFrm, 0, 0);
    mouse_set_shape(data, width_, height_, width_, width_ div 2, height_ div 2, #0);
    gsound_play_sfx_file('ipickup1');
  end;

  repeat
    sharedFpsLimiter.Mark;
    get_input;
    renderPresent;
    sharedFpsLimiter.Throttle;
  until (mouse_get_buttons and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0;

  if inventoryFrm <> nil then
  begin
    art_ptr_unlock(inventoryFrmHandle);
    gsound_play_sfx_file('iputdown');
  end;

  if a6 then
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_X, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_LEFT_SCROLLER_TRACKING_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;
      if quantityToMove <> -1 then
      begin
        if item_move_force(a5, inven_dude, a1, quantityToMove) = -1 then
        begin
          // There is no space left for that item.
          messageListItem.num := 26;
          if message_search(@inventry_message_file, @messageListItem) then
            display_print(messageListItem.text);
        end;
      end;
    end;
  end
  else
  begin
    if mouseHitTestInWindow(i_wid, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_X, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_Y, INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_MAX_X, INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_RIGHT_SCROLLER_TRACKING_Y) then
    begin
      if quantity > 1 then
        quantityToMove := do_move_timer(INVENTORY_WINDOW_TYPE_MOVE_ITEMS, a1, quantity)
      else
        quantityToMove := 1;
      if quantityToMove <> -1 then
      begin
        if item_move_force(a5, a4, a1, quantityToMove) = -1 then
        begin
          // You cannot pick that up. You are at your maximum weight capacity.
          messageListItem.num := 25;
          if message_search(@inventry_message_file, @messageListItem) then
            display_print(messageListItem.text);
        end;
      end;
    end;
  end;

  inven_set_mouse(INVENTORY_WINDOW_CURSOR_HAND);
end;

procedure display_table_inventories(win: Integer; a2, a3: PObject; a4: Integer);
var
  windowBuffer, src, dest: PByte;
  oldFont: Integer;
  formattedText: array[0..79] of AnsiChar;
  v45: Integer;
  inventory: PInventory;
  index, inventoryFid, cost: Integer;
  inventoryItem: PInventoryItem;
  rect_: TRect;
begin
  windowBuffer := win_get_buf(i_wid);

  oldFont := text_curr;
  text_font(101);

  v45 := text_height() + INVENTORY_SLOT_HEIGHT * inven_cur_disp;

  if a2 <> nil then
  begin
    src := win_get_buf(win);
    buf_to_buf(src + INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH * INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y + INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD + INVENTORY_TRADE_WINDOW_OFFSET,
      INVENTORY_SLOT_WIDTH,
      v45 + 1,
      INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH,
      windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y + INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD,
      INVENTORY_TRADE_WINDOW_WIDTH);

    dest := windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y_PAD + INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD;
    inventory := @a2^.Data.AsData.Inventory;
    index := 0;
    while (index < inven_cur_disp) and (index + ptable_offset < inventory^.Length) do
    begin
      inventoryItem := @inventory^.Items[index + ptable_offset];
      inventoryFid := item_inv_fid(inventoryItem^.Item);
      scale_art(inventoryFid,
        dest,
        INVENTORY_SLOT_WIDTH_PAD,
        INVENTORY_SLOT_HEIGHT_PAD,
        INVENTORY_TRADE_WINDOW_WIDTH);
      display_inventory_info(inventoryItem^.Item,
        inventoryItem^.Quantity,
        dest,
        INVENTORY_TRADE_WINDOW_WIDTH,
        index = a4);

      dest := dest + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_SLOT_HEIGHT;
      index := index + 1;
    end;

    cost := item_total_cost(a2);
    StrLFmt(@formattedText[0], SizeOf(formattedText) - 1, '$%d', [cost]);

    text_to_buf(windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * (INVENTORY_SLOT_HEIGHT * inven_cur_disp + INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y_PAD) + INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD,
      @formattedText[0],
      80,
      INVENTORY_TRADE_WINDOW_WIDTH,
      colorTable[32767]);

    rect_.ulx := INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD;
    rect_.uly := INVENTORY_TRADE_INNER_LEFT_SCROLLER_Y_PAD;
    // NOTE: Odd math, the only way to get 223 is to subtract 2.
    rect_.lrx := INVENTORY_TRADE_INNER_LEFT_SCROLLER_X_PAD + INVENTORY_SLOT_WIDTH_PAD - 2;
    rect_.lry := rect_.uly + v45;
    win_draw_rect(i_wid, @rect_);
  end;

  if a3 <> nil then
  begin
    src := win_get_buf(win);
    buf_to_buf(src + INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH * INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD + INVENTORY_TRADE_WINDOW_OFFSET,
      INVENTORY_SLOT_WIDTH,
      v45 + 1,
      INVENTORY_TRADE_BACKGROUND_WINDOW_WIDTH,
      windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD,
      INVENTORY_TRADE_WINDOW_WIDTH);

    dest := windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y_PAD + INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD;
    inventory := @a3^.Data.AsData.Inventory;
    index := 0;
    while (index < inven_cur_disp) and (index + btable_offset < inventory^.Length) do
    begin
      inventoryItem := @inventory^.Items[index + btable_offset];
      inventoryFid := item_inv_fid(inventoryItem^.Item);
      scale_art(inventoryFid,
        dest,
        INVENTORY_SLOT_WIDTH_PAD,
        INVENTORY_SLOT_HEIGHT_PAD,
        INVENTORY_TRADE_WINDOW_WIDTH);
      display_inventory_info(inventoryItem^.Item,
        inventoryItem^.Quantity,
        dest,
        INVENTORY_TRADE_WINDOW_WIDTH,
        index = a4);

      dest := dest + INVENTORY_TRADE_WINDOW_WIDTH * INVENTORY_SLOT_HEIGHT;
      index := index + 1;
    end;

    cost := barter_compute_value(obj_dude, target_stack[0]);
    StrLFmt(@formattedText[0], SizeOf(formattedText) - 1, '$%d', [cost]);

    text_to_buf(windowBuffer + INVENTORY_TRADE_WINDOW_WIDTH * (INVENTORY_SLOT_HEIGHT * inven_cur_disp + 24) + 254,
      @formattedText[0],
      80,
      INVENTORY_TRADE_WINDOW_WIDTH,
      colorTable[32767]);

    rect_.ulx := INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD;
    rect_.uly := INVENTORY_TRADE_INNER_RIGHT_SCROLLER_Y_PAD;
    // NOTE: Odd math, likely should be INVENTORY_SLOT_WIDTH_PAD.
    rect_.lrx := INVENTORY_TRADE_INNER_RIGHT_SCROLLER_X_PAD + INVENTORY_SLOT_WIDTH;
    rect_.lry := rect_.uly + v45;
    win_draw_rect(i_wid, @rect_);
  end;

  text_font(oldFont);
end;

end.
