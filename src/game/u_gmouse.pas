unit u_gmouse;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/gmouse.h + gmouse.cc
// Game mouse cursor: 3D hex cursor, action menus, scrolling, mode switching.

interface

uses
  u_object_types, u_cache, u_rect;

const
  // GameMouseMode
  GAME_MOUSE_MODE_MOVE           = 0;
  GAME_MOUSE_MODE_ARROW          = 1;
  GAME_MOUSE_MODE_CROSSHAIR      = 2;
  GAME_MOUSE_MODE_USE_CROSSHAIR  = 3;
  GAME_MOUSE_MODE_USE_FIRST_AID  = 4;
  GAME_MOUSE_MODE_USE_DOCTOR     = 5;
  GAME_MOUSE_MODE_USE_LOCKPICK   = 6;
  GAME_MOUSE_MODE_USE_STEAL      = 7;
  GAME_MOUSE_MODE_USE_TRAPS      = 8;
  GAME_MOUSE_MODE_USE_SCIENCE    = 9;
  GAME_MOUSE_MODE_USE_REPAIR     = 10;
  GAME_MOUSE_MODE_COUNT          = 11;
  FIRST_GAME_MOUSE_MODE_SKILL    = GAME_MOUSE_MODE_USE_FIRST_AID;
  GAME_MOUSE_MODE_SKILL_COUNT    = GAME_MOUSE_MODE_COUNT - FIRST_GAME_MOUSE_MODE_SKILL;

  // GameMouseActionMenuItem
  GAME_MOUSE_ACTION_MENU_ITEM_CANCEL    = 0;
  GAME_MOUSE_ACTION_MENU_ITEM_DROP      = 1;
  GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY = 2;
  GAME_MOUSE_ACTION_MENU_ITEM_LOOK      = 3;
  GAME_MOUSE_ACTION_MENU_ITEM_ROTATE    = 4;
  GAME_MOUSE_ACTION_MENU_ITEM_TALK      = 5;
  GAME_MOUSE_ACTION_MENU_ITEM_USE       = 6;
  GAME_MOUSE_ACTION_MENU_ITEM_UNLOAD    = 7;
  GAME_MOUSE_ACTION_MENU_ITEM_USE_SKILL = 8;
  GAME_MOUSE_ACTION_MENU_ITEM_COUNT     = 9;

  // MouseCursorType
  MOUSE_CURSOR_NONE               = 0;
  MOUSE_CURSOR_ARROW              = 1;
  MOUSE_CURSOR_SMALL_ARROW_UP     = 2;
  MOUSE_CURSOR_SMALL_ARROW_DOWN   = 3;
  MOUSE_CURSOR_SCROLL_NW          = 4;
  MOUSE_CURSOR_SCROLL_N           = 5;
  MOUSE_CURSOR_SCROLL_NE          = 6;
  MOUSE_CURSOR_SCROLL_E           = 7;
  MOUSE_CURSOR_SCROLL_SE          = 8;
  MOUSE_CURSOR_SCROLL_S           = 9;
  MOUSE_CURSOR_SCROLL_SW          = 10;
  MOUSE_CURSOR_SCROLL_W           = 11;
  MOUSE_CURSOR_SCROLL_NW_INVALID  = 12;
  MOUSE_CURSOR_SCROLL_N_INVALID   = 13;
  MOUSE_CURSOR_SCROLL_NE_INVALID  = 14;
  MOUSE_CURSOR_SCROLL_E_INVALID   = 15;
  MOUSE_CURSOR_SCROLL_SE_INVALID  = 16;
  MOUSE_CURSOR_SCROLL_S_INVALID   = 17;
  MOUSE_CURSOR_SCROLL_SW_INVALID  = 18;
  MOUSE_CURSOR_SCROLL_W_INVALID   = 19;
  MOUSE_CURSOR_CROSSHAIR          = 20;
  MOUSE_CURSOR_PLUS               = 21;
  MOUSE_CURSOR_DESTROY            = 22;
  MOUSE_CURSOR_USE_CROSSHAIR      = 23;
  MOUSE_CURSOR_WATCH              = 24;
  MOUSE_CURSOR_WAIT_PLANET        = 25;
  MOUSE_CURSOR_WAIT_WATCH         = 26;
  MOUSE_CURSOR_TYPE_COUNT         = 27;
  FIRST_GAME_MOUSE_ANIMATED_CURSOR = MOUSE_CURSOR_WAIT_PLANET;

var
  gmouse_clicked_on_edge: Boolean;
  obj_mouse: PObject;
  obj_mouse_flat: PObject;

function gmouse_init: Integer;
function gmouse_reset: Integer;
procedure gmouse_exit;
procedure gmouse_enable;
procedure gmouse_disable(a1: Integer);
function gmouse_is_enabled: Integer;
procedure gmouse_enable_scrolling;
procedure gmouse_disable_scrolling;
function gmouse_scrolling_is_enabled: Integer;
procedure gmouse_set_click_to_scroll(a1: Integer);
function gmouse_get_click_to_scroll: Integer;
function gmouse_is_scrolling: Integer;
procedure gmouse_bk_process;
procedure gmouse_handle_event(mouseX, mouseY, mouseState: Integer);
function gmouse_set_cursor(cursor: Integer): Integer;
function gmouse_get_cursor: Integer;
procedure gmouse_set_mapper_mode(mode: Integer);
procedure gmouse_3d_enable_modes;
procedure gmouse_3d_disable_modes;
function gmouse_3d_modes_are_enabled: Integer;
procedure gmouse_3d_set_mode(mode: Integer);
function gmouse_3d_get_mode: Integer;
procedure gmouse_3d_toggle_mode;
procedure gmouse_3d_refresh;
function gmouse_3d_set_fid(fid: Integer): Integer;
function gmouse_3d_get_fid: Integer;
procedure gmouse_3d_reset_fid;
procedure gmouse_3d_on;
procedure gmouse_3d_off;
function gmouse_3d_is_on: Boolean;
function object_under_mouse(objectType: Integer; a2: Boolean; elevation: Integer): PObject;
function gmouse_3d_build_pick_frame(x, y, menuItem, width, height: Integer): Integer;
function gmouse_3d_pick_frame_hot(a1, a2: PInteger): Integer;
function gmouse_3d_build_menu_frame(x, y: Integer; menuItems: PInteger; menuItemsCount, width, height: Integer): Integer;
function gmouse_3d_menu_frame_hot(x, y: PInteger): Integer;
function gmouse_3d_highlight_menu_frame(menuItemIndex: Integer): Integer;
function gmouse_3d_build_to_hit_frame(str: PAnsiChar; color: Integer): Integer;
function gmouse_3d_build_hex_frame(str: PAnsiChar; color: Integer): Integer;
procedure gmouse_3d_synch_item_highlight;
procedure gmouse_remove_item_outline(obj: PObject);
procedure gameMouseRefreshImmediately;

implementation

uses
  SysUtils,
  u_art,
  u_color,
  u_config,
  u_gconfig,
  u_grbuf,
  u_gnw,
  u_input,
  u_mouse,
  u_svga,
  u_text,
  u_map,
  u_map_defs,
  u_object,
  u_proto,
  u_protinst,
  u_tile,
  u_combat,
  u_critter,
  u_item,
  u_actions,
  u_anim,
  u_inventry,
  u_skilldex,
  u_kb,
  u_platform_compat,
  u_proto_types,
  u_fps_limiter,
  u_gsound,
  u_intface,
  u_game,
  u_int_sound;

const
  // ScrollableDirections
  SCROLLABLE_W = $01;
  SCROLLABLE_E = $02;
  SCROLLABLE_N = $04;
  SCROLLABLE_S = $08;

  // Skill constants (locally defined)
  SKILL_FIRST_AID = 12;
  SKILL_DOCTOR    = 13;
  SKILL_LOCKPICK  = 9;
  SKILL_STEAL     = 10;
  SKILL_TRAPS     = 11;
  SKILL_SCIENCE   = 14;
  SKILL_REPAIR    = 15;
  SKILL_SNEAK     = 8;

  // SkilldexRC constants
  SKILLDEX_RC_SNEAK    = 1;
  SKILLDEX_RC_LOCKPICK = 2;
  SKILLDEX_RC_STEAL    = 3;
  SKILLDEX_RC_TRAPS    = 4;
  SKILLDEX_RC_FIRST_AID = 5;
  SKILLDEX_RC_DOCTOR   = 6;
  SKILLDEX_RC_SCIENCE  = 7;
  SKILLDEX_RC_REPAIR   = 8;

  // Item type constants
  ITEM_TYPE_CONTAINER = 1;
  ITEM_TYPE_WEAPON    = 3;

  // Hit mode constants
  HIT_MODE_LEFT_WEAPON_PRIMARY  = 0;
  HIT_MODE_RIGHT_WEAPON_PRIMARY = 2;

  // Anim constants
  ANIM_STAND = 0;

  // SDL scancodes
  SDL_SCANCODE_LSHIFT = 225;
  SDL_SCANCODE_RSHIFT = 229;

  // INVALID_CACHE_ENTRY: (CacheEntry*)-1 in C
  INVALID_CACHE_ENTRY = PCacheEntry(PtrInt(-1));

// -----------------------------------------------------------------------
// Forward declarations for static functions
// -----------------------------------------------------------------------
function gmouse_3d_init: Integer; forward;
function gmouse_3d_reset_internal: Integer; forward;
procedure gmouse_3d_exit_internal; forward;
function gmouse_3d_lock_frames: Integer; forward;
procedure gmouse_3d_unlock_frames; forward;
function gmouse_3d_set_flat_fid(fid: Integer; rect: PRect): Integer; forward;
function gmouse_3d_reset_flat_fid(rect: PRect): Integer; forward;
function gmouse_3d_move_to(x, y, elevation: Integer; a4: PRect): Integer; forward;
function gmouse_check_scrolling(x, y, cursor: Integer): Integer; forward;

// FID_ANIM_TYPE inline
function FID_ANIM_TYPE(value: Integer): Integer; inline;
begin
  Result := (value and $FF0000) shr 16;
end;

// -----------------------------------------------------------------------
// Module-level (static) variables
// -----------------------------------------------------------------------
var
  gmouse_initialized: Boolean = False;
  gmouse_enabled: Integer = 0;
  gmouse_mapper_mode: Integer = 0;
  gmouse_click_to_scroll: Integer = 0;
  gmouse_scrolling_enabled: Integer = 1;
  gmouse_current_cursor: Integer = MOUSE_CURSOR_NONE;
  gmouse_current_cursor_key: PCacheEntry = INVALID_CACHE_ENTRY;

  gmouse_cursor_nums: array[0..MOUSE_CURSOR_TYPE_COUNT - 1] of Integer = (
    266, 267, 268, 269, 270, 271, 272, 273,
    274, 275, 276, 277, 330, 331, 329, 328,
    332, 334, 333, 335, 279, 280, 281, 293,
    310, 278, 295
  );

  gmouse_3d_initialized: Boolean = False;
  gmouse_3d_hover_test: Boolean = False;
  gmouse_3d_last_move_time: LongWord = 0;

  // actmenu.frm
  gmouse_3d_menu_frame: PArt = nil;
  gmouse_3d_menu_frame_key: PCacheEntry = INVALID_CACHE_ENTRY;
  gmouse_3d_menu_frame_width: Integer = 0;
  gmouse_3d_menu_frame_height: Integer = 0;
  gmouse_3d_menu_frame_size: Integer = 0;
  gmouse_3d_menu_frame_hot_x: Integer = 0;
  gmouse_3d_menu_frame_hot_y: Integer = 0;
  gmouse_3d_menu_frame_data: PByte = nil;

  // actpick.frm
  gmouse_3d_pick_frame: PArt = nil;
  gmouse_3d_pick_frame_key: PCacheEntry = INVALID_CACHE_ENTRY;
  gmouse_3d_pick_frame_width: Integer = 0;
  gmouse_3d_pick_frame_height: Integer = 0;
  gmouse_3d_pick_frame_size: Integer = 0;
  gmouse_3d_pick_frame_hot_x: Integer = 0;
  gmouse_3d_pick_frame_hot_y: Integer = 0;
  gmouse_3d_pick_frame_data: PByte = nil;

  // acttohit.frm
  gmouse_3d_to_hit_frame: PArt = nil;
  gmouse_3d_to_hit_frame_key: PCacheEntry = INVALID_CACHE_ENTRY;
  gmouse_3d_to_hit_frame_width: Integer = 0;
  gmouse_3d_to_hit_frame_height: Integer = 0;
  gmouse_3d_to_hit_frame_size: Integer = 0;
  gmouse_3d_to_hit_frame_data: PByte = nil;

  // blank.frm
  gmouse_3d_hex_base_frame: PArt = nil;
  gmouse_3d_hex_base_frame_key: PCacheEntry = INVALID_CACHE_ENTRY;
  gmouse_3d_hex_base_frame_width: Integer = 0;
  gmouse_3d_hex_base_frame_height: Integer = 0;
  gmouse_3d_hex_base_frame_size: Integer = 0;
  gmouse_3d_hex_base_frame_data: PByte = nil;

  // msef000.frm
  gmouse_3d_hex_frame: PArt = nil;
  gmouse_3d_hex_frame_key: PCacheEntry = INVALID_CACHE_ENTRY;
  gmouse_3d_hex_frame_width: Integer = 0;
  gmouse_3d_hex_frame_height: Integer = 0;
  gmouse_3d_hex_frame_size: Integer = 0;
  gmouse_3d_hex_frame_data: PByte = nil;

  gmouse_3d_menu_available_actions: Byte = 0;
  gmouse_3d_menu_actions_start: PByte = nil;
  gmouse_3d_menu_current_action_index: Byte = 0;

  gmouse_3d_action_nums: array[0..GAME_MOUSE_ACTION_MENU_ITEM_COUNT - 1] of SmallInt = (
    253, // Cancel
    255, // Drop
    257, // Inventory
    259, // Look
    261, // Rotate
    263, // Talk
    265, // Use/Get
    302, // Unload
    304  // Skill
  );

  gmouse_3d_modes_enabled: Integer = 1;
  gmouse_3d_current_mode: Integer = GAME_MOUSE_MODE_MOVE;

  gmouse_3d_mode_nums: array[0..GAME_MOUSE_MODE_COUNT - 1] of Integer = (
    249, 250, 251, 293, 293, 293, 293, 293, 293, 293, 293
  );

  gmouse_skill_table: array[0..GAME_MOUSE_MODE_SKILL_COUNT - 1] of Integer = (
    SKILL_FIRST_AID,
    SKILL_DOCTOR,
    SKILL_LOCKPICK,
    SKILL_STEAL,
    SKILL_TRAPS,
    SKILL_SCIENCE,
    SKILL_REPAIR
  );

  gmouse_wait_cursor_frame: Integer = 0;
  gmouse_wait_cursor_time: LongWord = 0;
  gmouse_bk_last_cursor: Integer = -1;
  gmouse_3d_item_highlight: Boolean = True;
  outlined_object: PObject = nil;

  gmouse_3d_menu_frame_actions: array[0..GAME_MOUSE_ACTION_MENU_ITEM_COUNT - 1] of Integer;
  gmouse_3d_last_mouse_x: Integer;
  gmouse_3d_last_mouse_y: Integer;

  // static local variables from gmouse_bk_process
  bk_last_object: PObject = nil;
  bk_last_tile: Integer = -1;

// -----------------------------------------------------------------------
// Helper: check if cursor is a scroll cursor
// -----------------------------------------------------------------------
function IsScrollCursor(c: Integer): Boolean; inline;
begin
  Result := ((c >= MOUSE_CURSOR_SCROLL_NW) and (c <= MOUSE_CURSOR_SCROLL_W)) or
            ((c >= MOUSE_CURSOR_SCROLL_NW_INVALID) and (c <= MOUSE_CURSOR_SCROLL_W_INVALID));
end;

// -----------------------------------------------------------------------
// gmouse_init
// -----------------------------------------------------------------------
function gmouse_init: Integer;
begin
  if gmouse_initialized then
  begin
    Result := -1;
    Exit;
  end;

  if gmouse_3d_init() <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  gmouse_initialized := True;
  gmouse_enabled := 1;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_reset
// -----------------------------------------------------------------------
function gmouse_reset: Integer;
begin
  if not gmouse_initialized then
  begin
    Result := -1;
    Exit;
  end;

  if gmouse_3d_reset_internal() <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  gmouse_enable();

  gmouse_scrolling_enabled := 1;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  gmouse_wait_cursor_frame := 0;
  gmouse_wait_cursor_time := 0;
  gmouse_clicked_on_edge := False;

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_exit
// -----------------------------------------------------------------------
procedure gmouse_exit;
begin
  if not gmouse_initialized then
    Exit;

  mouse_hide();
  mouse_set_shape(nil, 0, 0, 0, 0, 0, #0);

  gmouse_3d_exit_internal();

  if gmouse_current_cursor_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_current_cursor_key);
  gmouse_current_cursor_key := INVALID_CACHE_ENTRY;

  gmouse_enabled := 0;
  gmouse_initialized := False;
  gmouse_current_cursor := -1;
end;

// -----------------------------------------------------------------------
// gmouse_enable
// -----------------------------------------------------------------------
procedure gmouse_enable;
begin
  if gmouse_enabled = 0 then
  begin
    gmouse_current_cursor := -1;
    gmouse_set_cursor(MOUSE_CURSOR_NONE);
    gmouse_scrolling_enabled := 1;
    gmouse_enabled := 1;
    gmouse_bk_last_cursor := -1;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_disable
// -----------------------------------------------------------------------
procedure gmouse_disable(a1: Integer);
begin
  if gmouse_enabled <> 0 then
  begin
    gmouse_set_cursor(MOUSE_CURSOR_NONE);
    gmouse_enabled := 0;

    if (a1 and 1) <> 0 then
      gmouse_scrolling_enabled := 1
    else
      gmouse_scrolling_enabled := 0;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_is_enabled
// -----------------------------------------------------------------------
function gmouse_is_enabled: Integer;
begin
  Result := gmouse_enabled;
end;

// -----------------------------------------------------------------------
// gmouse_enable_scrolling
// -----------------------------------------------------------------------
procedure gmouse_enable_scrolling;
begin
  gmouse_scrolling_enabled := 1;
end;

// -----------------------------------------------------------------------
// gmouse_disable_scrolling
// -----------------------------------------------------------------------
procedure gmouse_disable_scrolling;
begin
  gmouse_scrolling_enabled := 0;
end;

// -----------------------------------------------------------------------
// gmouse_scrolling_is_enabled
// -----------------------------------------------------------------------
function gmouse_scrolling_is_enabled: Integer;
begin
  Result := gmouse_scrolling_enabled;
end;

// -----------------------------------------------------------------------
// gmouse_set_click_to_scroll
// -----------------------------------------------------------------------
procedure gmouse_set_click_to_scroll(a1: Integer);
begin
  if a1 <> gmouse_click_to_scroll then
  begin
    gmouse_click_to_scroll := a1;
    gmouse_clicked_on_edge := False;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_get_click_to_scroll
// -----------------------------------------------------------------------
function gmouse_get_click_to_scroll: Integer;
begin
  Result := gmouse_click_to_scroll;
end;

// -----------------------------------------------------------------------
// gmouse_is_scrolling
// -----------------------------------------------------------------------
function gmouse_is_scrolling: Integer;
var
  x, y: Integer;
begin
  Result := 0;

  if gmouse_scrolling_enabled <> 0 then
  begin
    mouse_get_position(@x, @y);
    if (x = scr_size.ulx) or (x = scr_size.lrx) or (y = scr_size.uly) or (y = scr_size.lry) then
    begin
      if IsScrollCursor(gmouse_current_cursor) then
        Result := 1;
    end;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_bk_process
// -----------------------------------------------------------------------
procedure gmouse_bk_process;
var
  mouseX, mouseY: Integer;
  oldMouseCursor: Integer;
  v3: LongWord;
  target: PObject;
  primaryAction: Integer;
  pointedObject: PObject;
  colorVal: Integer;
  accuracy: Integer;
  formattedAccuracy: array[0..7] of AnsiChar;
  formattedActionPoints: array[0..7] of AnsiChar;
  v6, v7, v8: Integer;
  tmp, r1, r2, r26: TRect;
  v34: Integer;
  fid: Integer;
begin
  if not gmouse_initialized then
    Exit;

  if gmouse_current_cursor >= FIRST_GAME_MOUSE_ANIMATED_CURSOR then
  begin
    mouse_info();

    if gmouse_scrolling_is_enabled() <> 0 then
    begin
      mouse_get_position(@mouseX, @mouseY);
      oldMouseCursor := gmouse_current_cursor;

      if gmouse_check_scrolling(mouseX, mouseY, gmouse_current_cursor) = 0 then
      begin
        if not IsScrollCursor(oldMouseCursor) then
          gmouse_bk_last_cursor := oldMouseCursor;
        Exit;
      end;

      if gmouse_bk_last_cursor <> -1 then
      begin
        gmouse_set_cursor(gmouse_bk_last_cursor);
        gmouse_bk_last_cursor := -1;
        Exit;
      end;
    end;

    gmouse_set_cursor(gmouse_current_cursor);
    Exit;
  end;

  if gmouse_enabled = 0 then
  begin
    if gmouse_scrolling_is_enabled() <> 0 then
    begin
      mouse_get_position(@mouseX, @mouseY);
      oldMouseCursor := gmouse_current_cursor;

      if gmouse_check_scrolling(mouseX, mouseY, gmouse_current_cursor) = 0 then
      begin
        if not IsScrollCursor(oldMouseCursor) then
          gmouse_bk_last_cursor := oldMouseCursor;
        Exit;
      end;

      if gmouse_bk_last_cursor <> -1 then
      begin
        gmouse_set_cursor(gmouse_bk_last_cursor);
        gmouse_bk_last_cursor := -1;
      end;
    end;

    Exit;
  end;

  mouse_get_position(@mouseX, @mouseY);

  oldMouseCursor := gmouse_current_cursor;
  if gmouse_check_scrolling(mouseX, mouseY, MOUSE_CURSOR_NONE) = 0 then
  begin
    if not IsScrollCursor(oldMouseCursor) then
      gmouse_bk_last_cursor := oldMouseCursor;
    Exit;
  end;

  if gmouse_bk_last_cursor <> -1 then
  begin
    gmouse_set_cursor(gmouse_bk_last_cursor);
    gmouse_bk_last_cursor := -1;
  end;

  if win_get_top_win(mouseX, mouseY) <> display_win then
  begin
    if gmouse_current_cursor = MOUSE_CURSOR_NONE then
    begin
      gmouse_3d_off();
      gmouse_set_cursor(MOUSE_CURSOR_ARROW);

      if (gmouse_3d_current_mode >= 2) and (not isInCombat()) then
        gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
    end;
    Exit;
  end;

  case gmouse_current_cursor of
    MOUSE_CURSOR_NONE,
    MOUSE_CURSOR_ARROW,
    MOUSE_CURSOR_SMALL_ARROW_UP,
    MOUSE_CURSOR_SMALL_ARROW_DOWN,
    MOUSE_CURSOR_CROSSHAIR,
    MOUSE_CURSOR_USE_CROSSHAIR:
    begin
      gmouse_set_cursor(MOUSE_CURSOR_NONE);

      if not gmouse_3d_is_on() then
        gmouse_3d_on();
    end;
  end;

  if gmouse_3d_move_to(mouseX, mouseY, map_elevation, @r1) = 0 then
    tile_refresh_rect(@r1, map_elevation);

  if (not gmouse_3d_is_on()) or (gmouse_mapper_mode <> 0) then
    Exit;

  v3 := get_bk_time();
  if (mouseX = gmouse_3d_last_mouse_x) and (mouseY = gmouse_3d_last_mouse_y) then
  begin
    if gmouse_3d_hover_test or (elapsed_tocks(v3, gmouse_3d_last_move_time) < 250) then
      Exit;

    if gmouse_3d_current_mode <> GAME_MOUSE_MODE_MOVE then
    begin
      if gmouse_3d_current_mode = GAME_MOUSE_MODE_ARROW then
      begin
        gmouse_3d_last_move_time := v3;
        gmouse_3d_hover_test := True;

        target := object_under_mouse(-1, True, map_elevation);
        if target <> nil then
        begin
          primaryAction := -1;

          case FID_TYPE(target^.Fid) of
            OBJ_TYPE_ITEM:
            begin
              primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_USE;
              if gmouse_3d_item_highlight then
              begin
                if obj_outline_object(target, Integer(OUTLINE_TYPE_ITEM), @tmp) = 0 then
                begin
                  tile_refresh_rect(@tmp, map_elevation);
                  outlined_object := target;
                end;
              end;
            end;
            OBJ_TYPE_CRITTER:
            begin
              if target = obj_dude then
                primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_ROTATE
              else
              begin
                if obj_action_can_talk_to(target) then
                begin
                  if isInCombat() then
                    primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_LOOK
                  else
                    primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_TALK;
                end
                else
                  primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_USE;
              end;
            end;
            OBJ_TYPE_SCENERY:
            begin
              if not proto_action_can_use(target^.Pid) then
                primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_LOOK
              else
                primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_USE;
            end;
            OBJ_TYPE_WALL:
              primaryAction := GAME_MOUSE_ACTION_MENU_ITEM_LOOK;
          end;

          if primaryAction <> -1 then
          begin
            if gmouse_3d_build_pick_frame(mouseX, mouseY, primaryAction, scr_size.lrx - scr_size.ulx + 1, scr_size.lry - scr_size.uly - 99) = 0 then
            begin
              fid := art_id(OBJ_TYPE_INTERFACE, 282, 0, 0, 0);
              if gmouse_3d_set_flat_fid(fid, @tmp) = 0 then
                tile_refresh_rect(@tmp, map_elevation);
            end;
          end;

          if target <> bk_last_object then
          begin
            bk_last_object := target;
            obj_look_at(obj_dude, bk_last_object);
          end;
        end;
      end
      else if gmouse_3d_current_mode = GAME_MOUSE_MODE_CROSSHAIR then
      begin
        pointedObject := object_under_mouse(OBJ_TYPE_CRITTER, False, map_elevation);
        if pointedObject <> nil then
        begin
          if combat_to_hit(pointedObject, @accuracy) then
          begin
            StrLFmt(@formattedAccuracy[0], SizeOf(formattedAccuracy) - 1, '%d%%', [accuracy]);
            colorVal := colorTable[32767];
          end
          else
          begin
            StrLFmt(@formattedAccuracy[0], SizeOf(formattedAccuracy) - 1, ' %s ', ['X']);
            colorVal := colorTable[31744];
          end;

          if gmouse_3d_build_to_hit_frame(@formattedAccuracy[0], colorVal) = 0 then
          begin
            fid := art_id(OBJ_TYPE_INTERFACE, 284, 0, 0, 0);
            if gmouse_3d_set_flat_fid(fid, @tmp) = 0 then
              tile_refresh_rect(@tmp, map_elevation);
          end;

          if bk_last_object <> pointedObject then
            bk_last_object := pointedObject;
        end
        else
        begin
          if gmouse_3d_reset_flat_fid(@tmp) = 0 then
            tile_refresh_rect(@tmp, map_elevation);
        end;

        gmouse_3d_last_move_time := v3;
        gmouse_3d_hover_test := True;
      end;
      Exit;
    end;

    // GAME_MOUSE_MODE_MOVE
    v6 := make_path(obj_dude, obj_dude^.Tile, obj_mouse_flat^.Tile, nil, 1);
    if v6 <> 0 then
    begin
      if not isInCombat() then
      begin
        formattedActionPoints[0] := #0;
        colorVal := colorTable[31744];
      end
      else
      begin
        v7 := critter_compute_ap_from_distance(obj_dude, v6);
        if v7 - combat_free_move >= 0 then
          v8 := v7 - combat_free_move
        else
          v8 := 0;

        if v8 <= obj_dude^.Data.AsData.Critter.Combat.Ap then
        begin
          StrLFmt(@formattedActionPoints[0], SizeOf(formattedActionPoints) - 1, '%d', [v8]);
          colorVal := colorTable[32767];
        end
        else
        begin
          StrLFmt(@formattedActionPoints[0], SizeOf(formattedActionPoints) - 1, '%s', ['X']);
          colorVal := colorTable[31744];
        end;
      end;
    end
    else
    begin
      StrLFmt(@formattedActionPoints[0], SizeOf(formattedActionPoints) - 1, '%s', ['X']);
      colorVal := colorTable[31744];
    end;

    if gmouse_3d_build_hex_frame(@formattedActionPoints[0], colorVal) = 0 then
    begin
      obj_bound(obj_mouse_flat, @tmp);
      tile_refresh_rect(@tmp, 0);
    end;

    gmouse_3d_last_move_time := v3;
    gmouse_3d_hover_test := True;
    bk_last_tile := obj_mouse_flat^.Tile;
    Exit;
  end;

  gmouse_3d_last_move_time := v3;
  gmouse_3d_hover_test := False;
  gmouse_3d_last_mouse_x := mouseX;
  gmouse_3d_last_mouse_y := mouseY;

  if gmouse_mapper_mode = 0 then
    gmouse_3d_reset_fid();

  v34 := 0;

  if gmouse_3d_reset_flat_fid(@r2) = 0 then
    v34 := v34 or 1;

  if outlined_object <> nil then
  begin
    if obj_remove_outline(outlined_object, @r26) = 0 then
      v34 := v34 or 2;
    outlined_object := nil;
  end;

  case v34 of
    3:
    begin
      rect_min_bound(@r2, @r26, @r2);
      tile_refresh_rect(@r2, map_elevation);
    end;
    1:
      tile_refresh_rect(@r2, map_elevation);
    2:
      tile_refresh_rect(@r26, map_elevation);
  end;
end;

// -----------------------------------------------------------------------
// gmouse_handle_event
// -----------------------------------------------------------------------
procedure gmouse_handle_event(mouseX, mouseY, mouseState: Integer);
var
  actionPoints: Integer;
  running: Boolean;
  target: PObject;
  weapon: PObject;
  hitMode: Integer;
  actionPointsRequired: Integer;
  ap_: Integer;
  actionMenuItemsCount: Integer;
  actionMenuItems: array[0..5] of Integer;
  v43: TRect;
  fid: Integer;
  v33: Integer;
  actionIndex: Integer;
  v48, v47: Integer;
  skill: Integer;
  rc: Integer;
  a1: TRect;
begin
  if not gmouse_initialized then
    Exit;

  if gmouse_current_cursor >= MOUSE_CURSOR_WAIT_PLANET then
    Exit;

  if gmouse_enabled = 0 then
    Exit;

  if gmouse_clicked_on_edge then
  begin
    if gmouse_get_click_to_scroll() <> 0 then
      Exit;
  end;

  if not mouse_click_in(0, 0, scr_size.lrx - scr_size.ulx, scr_size.lry - scr_size.uly - 100) then
    Exit;

  // CE: Make sure we cannot go outside of the map.
  if not tile_point_inside_bound(mouseX, mouseY) then
    Exit;

  if (mouseState and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0 then
  begin
    if (mouseState and MOUSE_EVENT_RIGHT_BUTTON_REPEAT) = 0 then
    begin
      if gmouse_3d_is_on() then
        gmouse_3d_toggle_mode();
    end;
    Exit;
  end;

  if (mouseState and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
  begin
    if gmouse_3d_current_mode = GAME_MOUSE_MODE_MOVE then
    begin
      if isInCombat() then
        actionPoints := combat_free_move + obj_dude^.Data.AsData.Critter.Combat.Ap
      else
        actionPoints := -1;

      configGetBool(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_RUNNING_KEY, @running);

      if (keys[SDL_SCANCODE_LSHIFT] <> 0) or (keys[SDL_SCANCODE_RSHIFT] <> 0) then
      begin
        if running then
        begin
          dude_move(actionPoints);
          Exit;
        end;
      end
      else
      begin
        if not running then
        begin
          dude_move(actionPoints);
          Exit;
        end;
      end;

      dude_run(actionPoints);
      Exit;
    end;

    if gmouse_3d_current_mode = GAME_MOUSE_MODE_ARROW then
    begin
      target := object_under_mouse(-1, True, map_elevation);
      if target <> nil then
      begin
        case FID_TYPE(target^.Fid) of
          OBJ_TYPE_ITEM:
            action_get_an_object(obj_dude, target);
          OBJ_TYPE_CRITTER:
          begin
            if target = obj_dude then
            begin
              if FID_ANIM_TYPE(obj_dude^.Fid) = ANIM_STAND then
              begin
                if obj_inc_rotation(target, @a1) = 0 then
                  tile_refresh_rect(@a1, target^.Elevation);
              end;
            end
            else
            begin
              if obj_action_can_talk_to(target) then
              begin
                if isInCombat() then
                begin
                  if obj_examine(obj_dude, target) = -1 then
                    obj_look_at(obj_dude, target);
                end
                else
                  action_talk_to(obj_dude, target);
              end
              else
                action_loot_container(obj_dude, target);
            end;
          end;
          OBJ_TYPE_SCENERY:
          begin
            if proto_action_can_use(target^.Pid) then
              action_use_an_object(obj_dude, target)
            else
            begin
              if obj_examine(obj_dude, target) = -1 then
                obj_look_at(obj_dude, target);
            end;
          end;
          OBJ_TYPE_WALL:
          begin
            if obj_examine(obj_dude, target) = -1 then
              obj_look_at(obj_dude, target);
          end;
        end;
      end;
      Exit;
    end;

    if gmouse_3d_current_mode = GAME_MOUSE_MODE_CROSSHAIR then
    begin
      target := object_under_mouse(OBJ_TYPE_CRITTER, False, map_elevation);
      if target <> nil then
      begin
        combat_attack_this(target);
        gmouse_3d_hover_test := True;
        gmouse_3d_last_mouse_y := mouseY;
        gmouse_3d_last_mouse_x := mouseX;
        gmouse_3d_last_move_time := get_time() - 250;
      end;
      Exit;
    end;

    if gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_CROSSHAIR then
    begin
      target := object_under_mouse(-1, True, map_elevation);
      if target <> nil then
      begin
        if intface_get_current_item(@weapon) <> -1 then
        begin
          if isInCombat() then
          begin
            if intface_is_item_right_hand() <> 0 then
              hitMode := HIT_MODE_RIGHT_WEAPON_PRIMARY
            else
              hitMode := HIT_MODE_LEFT_WEAPON_PRIMARY;

            actionPointsRequired := item_mp_cost(obj_dude, hitMode, False);
            if actionPointsRequired <= obj_dude^.Data.AsData.Critter.Combat.Ap then
            begin
              if action_use_an_item_on_object(obj_dude, target, weapon) <> -1 then
              begin
                ap_ := obj_dude^.Data.AsData.Critter.Combat.Ap;
                if actionPointsRequired > ap_ then
                  obj_dude^.Data.AsData.Critter.Combat.Ap := 0
                else
                  obj_dude^.Data.AsData.Critter.Combat.Ap := obj_dude^.Data.AsData.Critter.Combat.Ap - actionPointsRequired;
                intface_update_move_points(obj_dude^.Data.AsData.Critter.Combat.Ap, combat_free_move);
              end;
            end;
          end
          else
            action_use_an_item_on_object(obj_dude, target, weapon);
        end;
      end;
      gmouse_set_cursor(MOUSE_CURSOR_NONE);
      gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
      Exit;
    end;

    if (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_FIRST_AID) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_DOCTOR) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_LOCKPICK) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_STEAL) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_TRAPS) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_SCIENCE) or
       (gmouse_3d_current_mode = GAME_MOUSE_MODE_USE_REPAIR) then
    begin
      target := object_under_mouse(-1, True, map_elevation);
      if (target = nil) or (action_use_skill_on(obj_dude, target, gmouse_skill_table[gmouse_3d_current_mode - FIRST_GAME_MOUSE_MODE_SKILL]) <> -1) then
      begin
        gmouse_set_cursor(MOUSE_CURSOR_NONE);
        gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
      end;
      Exit;
    end;
  end;

  if ((mouseState and MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT) = MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT) and
     (gmouse_3d_current_mode = GAME_MOUSE_MODE_ARROW) then
  begin
    target := object_under_mouse(-1, True, map_elevation);
    if target <> nil then
    begin
      actionMenuItemsCount := 0;
      case FID_TYPE(target^.Fid) of
        OBJ_TYPE_ITEM:
        begin
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_LOOK;
          Inc(actionMenuItemsCount);
          if item_get_type(target) = ITEM_TYPE_CONTAINER then
          begin
            actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY;
            Inc(actionMenuItemsCount);
            actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE_SKILL;
            Inc(actionMenuItemsCount);
          end;
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_CANCEL;
          Inc(actionMenuItemsCount);
        end;
        OBJ_TYPE_CRITTER:
        begin
          if target = obj_dude then
          begin
            actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_ROTATE;
            Inc(actionMenuItemsCount);
          end
          else
          begin
            if obj_action_can_talk_to(target) then
            begin
              if not isInCombat() then
              begin
                actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_TALK;
                Inc(actionMenuItemsCount);
              end;
            end
            else
            begin
              actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE;
              Inc(actionMenuItemsCount);
            end;
          end;

          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_LOOK;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE_SKILL;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_CANCEL;
          Inc(actionMenuItemsCount);
        end;
        OBJ_TYPE_SCENERY:
        begin
          if proto_action_can_use(target^.Pid) then
          begin
            actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE;
            Inc(actionMenuItemsCount);
          end;

          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_LOOK;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_USE_SKILL;
          Inc(actionMenuItemsCount);
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_CANCEL;
          Inc(actionMenuItemsCount);
        end;
        OBJ_TYPE_WALL:
        begin
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_LOOK;
          Inc(actionMenuItemsCount);
          if proto_action_can_use(target^.Pid) then
          begin
            actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY;
            Inc(actionMenuItemsCount);
          end;
          actionMenuItems[actionMenuItemsCount] := GAME_MOUSE_ACTION_MENU_ITEM_CANCEL;
          Inc(actionMenuItemsCount);
        end;
      end;

      if gmouse_3d_build_menu_frame(mouseX, mouseY, @actionMenuItems[0], actionMenuItemsCount, scr_size.lrx - scr_size.ulx + 1, scr_size.lry - scr_size.uly - 99) = 0 then
      begin
        fid := art_id(OBJ_TYPE_INTERFACE, 283, 0, 0, 0);
        if (gmouse_3d_set_flat_fid(fid, @v43) = 0) and (gmouse_3d_move_to(mouseX, mouseY, map_elevation, @v43) = 0) then
        begin
          tile_refresh_rect(@v43, map_elevation);
          map_disable_bk_processes();

          v33 := mouseY;
          actionIndex := 0;
          while (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_UP) = 0 do
          begin
            sharedFpsLimiter.mark();

            get_input();

            if game_user_wants_to_quit <> 0 then
              actionMenuItems[actionIndex] := 0;

            mouse_get_position(@v48, @v47);

            if Abs(v47 - v33) > 10 then
            begin
              if v33 >= v47 then
                actionIndex := actionIndex - 1
              else
                actionIndex := actionIndex + 1;

              if gmouse_3d_highlight_menu_frame(actionIndex) = 0 then
                tile_refresh_rect(@v43, map_elevation);
              v33 := v47;
            end;

            renderPresent();
            sharedFpsLimiter.throttle();
          end;

          map_enable_bk_processes();

          gmouse_3d_hover_test := False;
          gmouse_3d_last_mouse_x := mouseX;
          gmouse_3d_last_mouse_y := mouseY;
          gmouse_3d_last_move_time := get_time();

          mouse_set_position(mouseX, v33);

          if gmouse_3d_reset_flat_fid(@v43) = 0 then
            tile_refresh_rect(@v43, map_elevation);

          case actionMenuItems[actionIndex] of
            GAME_MOUSE_ACTION_MENU_ITEM_INVENTORY:
              use_inventory_on(target);
            GAME_MOUSE_ACTION_MENU_ITEM_LOOK:
            begin
              if obj_examine(obj_dude, target) = -1 then
                obj_look_at(obj_dude, target);
            end;
            GAME_MOUSE_ACTION_MENU_ITEM_ROTATE:
            begin
              if obj_inc_rotation(target, @v43) = 0 then
                tile_refresh_rect(@v43, target^.Elevation);
            end;
            GAME_MOUSE_ACTION_MENU_ITEM_TALK:
              action_talk_to(obj_dude, target);
            GAME_MOUSE_ACTION_MENU_ITEM_USE:
            begin
              case FID_TYPE(target^.Fid) of
                OBJ_TYPE_SCENERY:
                  action_use_an_object(obj_dude, target);
                OBJ_TYPE_CRITTER:
                  action_loot_container(obj_dude, target);
              else
                action_get_an_object(obj_dude, target);
              end;
            end;
            GAME_MOUSE_ACTION_MENU_ITEM_USE_SKILL:
            begin
              skill := -1;

              rc := skilldex_select();
              case rc of
                SKILLDEX_RC_SNEAK:
                  action_skill_use(SKILL_SNEAK);
                SKILLDEX_RC_LOCKPICK:
                  skill := SKILL_LOCKPICK;
                SKILLDEX_RC_STEAL:
                  skill := SKILL_STEAL;
                SKILLDEX_RC_TRAPS:
                  skill := SKILL_TRAPS;
                SKILLDEX_RC_FIRST_AID:
                  skill := SKILL_FIRST_AID;
                SKILLDEX_RC_DOCTOR:
                  skill := SKILL_DOCTOR;
                SKILLDEX_RC_SCIENCE:
                  skill := SKILL_SCIENCE;
                SKILLDEX_RC_REPAIR:
                  skill := SKILL_REPAIR;
              end;

              if skill <> -1 then
                action_use_skill_on(obj_dude, target, skill);
            end;
          end;
        end;
      end;
    end;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_set_cursor
// -----------------------------------------------------------------------
function gmouse_set_cursor(cursor: Integer): Integer;
var
  mouseCursorFrmHandle: PCacheEntry;
  fid: Integer;
  mouseCursorFrm: PArt;
  shouldUpdate: Boolean;
  frame: Integer;
  tick: LongWord;
  delay: LongWord;
  width, height: Integer;
  offsetX, offsetY: Integer;
  mouseCursorFrmData: PByte;
begin
  if not gmouse_initialized then
  begin
    Result := -1;
    Exit;
  end;

  if (cursor <> MOUSE_CURSOR_ARROW) and (cursor = gmouse_current_cursor) and
     ((gmouse_current_cursor < 25) or (gmouse_current_cursor >= 27)) then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_cursor_nums[cursor], 0, 0, 0);
  mouseCursorFrm := art_ptr_lock(fid, @mouseCursorFrmHandle);
  if mouseCursorFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  shouldUpdate := True;
  frame := 0;
  if cursor >= FIRST_GAME_MOUSE_ANIMATED_CURSOR then
  begin
    tick := get_time();

    if gmouse_3d_is_on() then
      gmouse_3d_off();

    delay := 1000 div art_frame_fps(mouseCursorFrm);
    if elapsed_tocks(tick, gmouse_wait_cursor_time) < delay then
      shouldUpdate := False
    else
    begin
      if art_frame_max_frame(mouseCursorFrm) <= gmouse_wait_cursor_frame then
        gmouse_wait_cursor_frame := 0;

      frame := gmouse_wait_cursor_frame;
      gmouse_wait_cursor_time := tick;
      Inc(gmouse_wait_cursor_frame);
    end;
  end;

  if not shouldUpdate then
  begin
    Result := -1;
    Exit;
  end;

  width := art_frame_width(mouseCursorFrm, frame, 0);
  height := art_frame_length(mouseCursorFrm, frame, 0);

  art_frame_offset(mouseCursorFrm, 0, @offsetX, @offsetY);

  offsetX := width div 2 - offsetX;
  offsetY := height - 1 - offsetY;

  mouseCursorFrmData := art_frame_data(mouseCursorFrm, frame, 0);
  if mouse_set_shape(mouseCursorFrmData, width, height, width, offsetX, offsetY, #0) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if gmouse_current_cursor_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_current_cursor_key);

  gmouse_current_cursor := cursor;
  gmouse_current_cursor_key := mouseCursorFrmHandle;

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_get_cursor
// -----------------------------------------------------------------------
function gmouse_get_cursor: Integer;
begin
  Result := gmouse_current_cursor;
end;

// -----------------------------------------------------------------------
// gmouse_set_mapper_mode
// -----------------------------------------------------------------------
procedure gmouse_set_mapper_mode(mode: Integer);
begin
  gmouse_mapper_mode := mode;
end;

// -----------------------------------------------------------------------
// gmouse_3d_enable_modes
// -----------------------------------------------------------------------
procedure gmouse_3d_enable_modes;
begin
  gmouse_3d_modes_enabled := 1;
end;

// -----------------------------------------------------------------------
// gmouse_3d_disable_modes
// -----------------------------------------------------------------------
procedure gmouse_3d_disable_modes;
begin
  gmouse_3d_modes_enabled := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_modes_are_enabled
// -----------------------------------------------------------------------
function gmouse_3d_modes_are_enabled: Integer;
begin
  Result := gmouse_3d_modes_enabled;
end;

// -----------------------------------------------------------------------
// gmouse_3d_set_mode
// -----------------------------------------------------------------------
procedure gmouse_3d_set_mode(mode: Integer);
var
  fid: Integer;
  rect, r2: TRect;
  mouseX, mouseY: Integer;
  v5: Integer;
begin
  if not gmouse_initialized then
    Exit;

  if gmouse_3d_modes_enabled = 0 then
    Exit;

  if mode = gmouse_3d_current_mode then
    Exit;

  fid := art_id(OBJ_TYPE_INTERFACE, 0, 0, 0, 0);
  gmouse_3d_set_fid(fid);

  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_mode_nums[mode], 0, 0, 0);

  if gmouse_3d_set_flat_fid(fid, @rect) = -1 then
    Exit;

  mouse_get_position(@mouseX, @mouseY);

  if gmouse_3d_move_to(mouseX, mouseY, map_elevation, @r2) = 0 then
    rect_min_bound(@rect, @r2, @rect);

  v5 := 0;
  if gmouse_3d_current_mode = GAME_MOUSE_MODE_CROSSHAIR then
    v5 := -1;

  if mode <> 0 then
  begin
    if mode = GAME_MOUSE_MODE_CROSSHAIR then
      v5 := 1;

    if gmouse_3d_current_mode = 0 then
    begin
      if obj_turn_off_outline(obj_mouse_flat, @r2) = 0 then
        rect_min_bound(@rect, @r2, @rect);
    end;
  end
  else
  begin
    if obj_turn_on_outline(obj_mouse_flat, @r2) = 0 then
      rect_min_bound(@rect, @r2, @rect);
  end;

  gmouse_3d_current_mode := mode;
  gmouse_3d_hover_test := False;
  gmouse_3d_last_move_time := get_time();

  tile_refresh_rect(@rect, map_elevation);

  case v5 of
    1: combat_outline_on();
    -1: combat_outline_off();
  end;
end;

// -----------------------------------------------------------------------
// gmouse_3d_get_mode
// -----------------------------------------------------------------------
function gmouse_3d_get_mode: Integer;
begin
  Result := gmouse_3d_current_mode;
end;

// -----------------------------------------------------------------------
// gmouse_3d_toggle_mode
// -----------------------------------------------------------------------
procedure gmouse_3d_toggle_mode;
var
  mode: Integer;
  item: PObject;
begin
  mode := (gmouse_3d_current_mode + 1) mod 3;

  if isInCombat() then
  begin
    if intface_get_current_item(@item) = 0 then
    begin
      if (item <> nil) and (item_get_type(item) <> ITEM_TYPE_WEAPON) and (mode = GAME_MOUSE_MODE_CROSSHAIR) then
        mode := GAME_MOUSE_MODE_MOVE;
    end;
  end
  else
  begin
    if mode = GAME_MOUSE_MODE_CROSSHAIR then
      mode := GAME_MOUSE_MODE_MOVE;
  end;

  gmouse_3d_set_mode(mode);
end;

// -----------------------------------------------------------------------
// gmouse_3d_refresh
// -----------------------------------------------------------------------
procedure gmouse_3d_refresh;
begin
  gmouse_3d_last_mouse_x := -1;
  gmouse_3d_last_mouse_y := -1;
  gmouse_3d_hover_test := False;
  gmouse_3d_last_move_time := 0;
  gmouse_bk_process();
end;

// -----------------------------------------------------------------------
// gmouse_3d_set_fid
// -----------------------------------------------------------------------
function gmouse_3d_set_fid(fid: Integer): Integer;
var
  v1: Integer;
  oldRect, rect: TRect;
begin
  if not gmouse_initialized then
  begin
    Result := -1;
    Exit;
  end;

  if not art_exists(fid) then
  begin
    Result := -1;
    Exit;
  end;

  if obj_mouse^.Fid = fid then
  begin
    Result := -1;
    Exit;
  end;

  if gmouse_mapper_mode = 0 then
  begin
    Result := obj_change_fid(obj_mouse, fid, nil);
    Exit;
  end;

  v1 := 0;

  if obj_mouse^.Fid <> -1 then
  begin
    obj_bound(obj_mouse, @oldRect);
    v1 := v1 or 1;
  end;

  Result := -1;

  if obj_change_fid(obj_mouse, fid, @rect) = 0 then
  begin
    Result := 0;
    v1 := v1 or 2;
  end;

  if gmouse_3d_is_on() then
  begin
    if v1 = 1 then
      tile_refresh_rect(@oldRect, map_elevation)
    else if v1 = 2 then
      tile_refresh_rect(@rect, map_elevation)
    else if v1 = 3 then
    begin
      rect_min_bound(@oldRect, @rect, @oldRect);
      tile_refresh_rect(@oldRect, map_elevation);
    end;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_3d_get_fid
// -----------------------------------------------------------------------
function gmouse_3d_get_fid: Integer;
begin
  if gmouse_initialized then
    Result := obj_mouse^.Fid
  else
    Result := -1;
end;

// -----------------------------------------------------------------------
// gmouse_3d_reset_fid
// -----------------------------------------------------------------------
procedure gmouse_3d_reset_fid;
var
  fid: Integer;
begin
  fid := art_id(OBJ_TYPE_INTERFACE, 0, 0, 0, 0);
  gmouse_3d_set_fid(fid);
end;

// -----------------------------------------------------------------------
// gmouse_3d_on
// -----------------------------------------------------------------------
procedure gmouse_3d_on;
var
  v2: Integer;
  rect1, rect2, tmp: TRect;
  rect: PRect;
begin
  if not gmouse_initialized then
    Exit;

  v2 := 0;

  if obj_turn_on(obj_mouse, @rect1) = 0 then
    v2 := v2 or 1;

  if obj_turn_on(obj_mouse_flat, @rect2) = 0 then
    v2 := v2 or 2;

  if gmouse_3d_current_mode <> GAME_MOUSE_MODE_MOVE then
  begin
    if obj_turn_off_outline(obj_mouse_flat, @tmp) = 0 then
    begin
      if (v2 and 2) <> 0 then
        rect_min_bound(@rect2, @tmp, @rect2)
      else
      begin
        Move(tmp, rect2, SizeOf(rect2));
        v2 := v2 or 2;
      end;
    end;
  end;

  if gmouse_3d_reset_flat_fid(@tmp) = 0 then
  begin
    if (v2 and 2) <> 0 then
      rect_min_bound(@rect2, @tmp, @rect2)
    else
    begin
      Move(tmp, rect2, SizeOf(rect2));
      v2 := v2 or 2;
    end;
  end;

  if v2 <> 0 then
  begin
    case v2 of
      1: rect := @rect1;
      2: rect := @rect2;
      3:
      begin
        rect_min_bound(@rect1, @rect2, @rect1);
        rect := @rect1;
      end;
    else
      rect := @rect1; // should be unreachable
    end;

    tile_refresh_rect(rect, map_elevation);
  end;

  gmouse_3d_hover_test := False;
  gmouse_3d_last_move_time := get_time() - 250;
end;

// -----------------------------------------------------------------------
// gmouse_3d_off
// -----------------------------------------------------------------------
procedure gmouse_3d_off;
var
  v1: Integer;
  rect1, rect2: TRect;
begin
  if not gmouse_initialized then
    Exit;

  v1 := 0;

  if obj_turn_off(obj_mouse, @rect1) = 0 then
    v1 := v1 or 1;

  if obj_turn_off(obj_mouse_flat, @rect2) = 0 then
    v1 := v1 or 2;

  if v1 = 1 then
    tile_refresh_rect(@rect1, map_elevation)
  else if v1 = 2 then
    tile_refresh_rect(@rect2, map_elevation)
  else if v1 = 3 then
  begin
    rect_min_bound(@rect1, @rect2, @rect1);
    tile_refresh_rect(@rect1, map_elevation);
  end;
end;

// -----------------------------------------------------------------------
// gmouse_3d_is_on
// -----------------------------------------------------------------------
function gmouse_3d_is_on: Boolean;
begin
  Result := (obj_mouse_flat^.Flags and OBJECT_HIDDEN) = 0;
end;

// -----------------------------------------------------------------------
// object_under_mouse
// -----------------------------------------------------------------------
function object_under_mouse(objectType: Integer; a2: Boolean; elevation: Integer): PObject;
var
  mouseX, mouseY: Integer;
  v13: Boolean;
  v4: PObject;
  entries: PObjectWithFlags;
  count: Integer;
  index: Integer;
  ptr: PObjectWithFlags;
begin
  mouse_get_position(@mouseX, @mouseY);

  v13 := False;
  if objectType = -1 then
  begin
    if square_roof_intersect(mouseX, mouseY, elevation) then
    begin
      if obj_intersects_with(obj_egg, mouseX, mouseY) = 0 then
        v13 := True;
    end;
  end;

  v4 := nil;
  if not v13 then
  begin
    count := obj_create_intersect_list(mouseX, mouseY, elevation, objectType, @entries);
    index := count - 1;
    while index >= 0 do
    begin
      ptr := PObjectWithFlags(PByte(entries) + index * SizeOf(TObjectWithFlags));
      if a2 or (obj_dude <> ptr^.Obj) then
      begin
        v4 := ptr^.Obj;
        if (ptr^.Flags and $01) <> 0 then
        begin
          if (ptr^.Flags and $04) = 0 then
          begin
            if (FID_TYPE(ptr^.Obj^.Fid) <> OBJ_TYPE_CRITTER) or
               ((ptr^.Obj^.Data.AsData.Critter.Combat.Results and (DAM_KNOCKED_OUT or DAM_DEAD)) = 0) then
              Break;
          end;
        end;
      end;
      Dec(index);
    end;

    if count <> 0 then
      obj_delete_intersect_list(@entries);
  end;
  Result := v4;
end;

// -----------------------------------------------------------------------
// gmouse_3d_build_pick_frame
// -----------------------------------------------------------------------
function gmouse_3d_build_pick_frame(x, y, menuItem, width, height: Integer): Integer;
var
  menuItemFrmHandle: PCacheEntry;
  menuItemFid: Integer;
  menuItemFrm: PArt;
  arrowFrmHandle: PCacheEntry;
  arrowFid: Integer;
  arrowFrm: PArt;
  arrowFrmData: PByte;
  arrowFrmWidth, arrowFrmHeight: Integer;
  menuItemFrmData: PByte;
  menuItemFrmWidth, menuItemFrmHeight: Integer;
  arrowFrmDest, menuItemFrmDest: PByte;
  maxX, maxY, shiftY: Integer;
begin
  menuItemFid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_action_nums[menuItem], 0, 0, 0);
  menuItemFrm := art_ptr_lock(menuItemFid, @menuItemFrmHandle);
  if menuItemFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  arrowFid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_mode_nums[GAME_MOUSE_MODE_ARROW], 0, 0, 0);
  arrowFrm := art_ptr_lock(arrowFid, @arrowFrmHandle);
  if arrowFrm = nil then
  begin
    art_ptr_unlock(menuItemFrmHandle);
    Result := 0;
    Exit;
  end;

  arrowFrmData := art_frame_data(arrowFrm, 0, 0);
  arrowFrmWidth := art_frame_width(arrowFrm, 0, 0);
  arrowFrmHeight := art_frame_length(arrowFrm, 0, 0);

  menuItemFrmData := art_frame_data(menuItemFrm, 0, 0);
  menuItemFrmWidth := art_frame_width(menuItemFrm, 0, 0);
  menuItemFrmHeight := art_frame_length(menuItemFrm, 0, 0);

  arrowFrmDest := gmouse_3d_pick_frame_data;
  menuItemFrmDest := gmouse_3d_pick_frame_data;

  gmouse_3d_pick_frame_hot_x := 0;
  gmouse_3d_pick_frame_hot_y := 0;

  gmouse_3d_pick_frame^.xOffsets[0] := gmouse_3d_pick_frame_width div 2;
  gmouse_3d_pick_frame^.yOffsets[0] := gmouse_3d_pick_frame_height - 1;

  maxX := x + menuItemFrmWidth + arrowFrmWidth - 1;
  maxY := y + menuItemFrmHeight - 1;
  shiftY := maxY - height + 2;

  if maxX < width then
  begin
    menuItemFrmDest := menuItemFrmDest + arrowFrmWidth;
    if maxY >= height then
    begin
      gmouse_3d_pick_frame_hot_y := shiftY;
      gmouse_3d_pick_frame^.yOffsets[0] := gmouse_3d_pick_frame^.yOffsets[0] - SmallInt(shiftY);
      arrowFrmDest := arrowFrmDest + gmouse_3d_pick_frame_width * shiftY;
    end;
  end
  else
  begin
    art_ptr_unlock(arrowFrmHandle);

    arrowFid := art_id(OBJ_TYPE_INTERFACE, 285, 0, 0, 0);
    arrowFrm := art_ptr_lock(arrowFid, @arrowFrmHandle);
    arrowFrmData := art_frame_data(arrowFrm, 0, 0);
    arrowFrmDest := arrowFrmDest + menuItemFrmWidth;

    gmouse_3d_pick_frame^.xOffsets[0] := -gmouse_3d_pick_frame^.xOffsets[0];
    gmouse_3d_pick_frame_hot_x := gmouse_3d_pick_frame_hot_x + menuItemFrmWidth + arrowFrmWidth;

    if maxY >= height then
    begin
      gmouse_3d_pick_frame_hot_y := gmouse_3d_pick_frame_hot_y + shiftY;
      gmouse_3d_pick_frame^.yOffsets[0] := gmouse_3d_pick_frame^.yOffsets[0] - SmallInt(shiftY);
      arrowFrmDest := arrowFrmDest + gmouse_3d_pick_frame_width * shiftY;
    end;
  end;

  FillChar(gmouse_3d_pick_frame_data^, gmouse_3d_pick_frame_size, 0);

  buf_to_buf(arrowFrmData, arrowFrmWidth, arrowFrmHeight, arrowFrmWidth, arrowFrmDest, gmouse_3d_pick_frame_width);
  buf_to_buf(menuItemFrmData, menuItemFrmWidth, menuItemFrmHeight, menuItemFrmWidth, menuItemFrmDest, gmouse_3d_pick_frame_width);

  art_ptr_unlock(arrowFrmHandle);
  art_ptr_unlock(menuItemFrmHandle);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_pick_frame_hot
// -----------------------------------------------------------------------
function gmouse_3d_pick_frame_hot(a1, a2: PInteger): Integer;
begin
  a1^ := gmouse_3d_pick_frame_hot_x;
  a2^ := gmouse_3d_pick_frame_hot_y;
  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_build_menu_frame
// -----------------------------------------------------------------------
function gmouse_3d_build_menu_frame(x, y: Integer; menuItems: PInteger; menuItemsCount, width, height: Integer): Integer;
var
  menuItemFrmHandles: array[0..GAME_MOUSE_ACTION_MENU_ITEM_COUNT - 1] of PCacheEntry;
  menuItemFrms: array[0..GAME_MOUSE_ACTION_MENU_ITEM_COUNT - 1] of PArt;
  index: Integer;
  frmId: Integer;
  fid: Integer;
  arrowFrmHandle: PCacheEntry;
  arrowFrm: PArt;
  arrowWidth, arrowHeight: Integer;
  menuItemWidth, menuItemHeight: Integer;
  v60, v24: Integer;
  v22, v58: PByte;
  arrowData: PByte;
  v38: PByte;
  data: PByte;
  sound: PSound;
  pItems: PInteger;
begin
  gmouse_3d_menu_actions_start := nil;
  gmouse_3d_menu_current_action_index := 0;
  gmouse_3d_menu_available_actions := 0;

  if menuItems = nil then
  begin
    Result := -1;
    Exit;
  end;

  if (menuItemsCount = 0) or (menuItemsCount >= GAME_MOUSE_ACTION_MENU_ITEM_COUNT) then
  begin
    Result := -1;
    Exit;
  end;

  pItems := menuItems;
  index := 0;
  while index < menuItemsCount do
  begin
    frmId := gmouse_3d_action_nums[PInteger(PByte(pItems) + index * SizeOf(Integer))^] and $FFFF;
    if index = 0 then
      Dec(frmId);

    fid := art_id(OBJ_TYPE_INTERFACE, frmId, 0, 0, 0);

    menuItemFrms[index] := art_ptr_lock(fid, @menuItemFrmHandles[index]);
    if menuItemFrms[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        art_ptr_unlock(menuItemFrmHandles[index]);
        Dec(index);
      end;
      Result := -1;
      Exit;
    end;
    Inc(index);
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_mode_nums[GAME_MOUSE_MODE_ARROW], 0, 0, 0);
  arrowFrm := art_ptr_lock(fid, @arrowFrmHandle);
  if arrowFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  arrowWidth := art_frame_width(arrowFrm, 0, 0);
  arrowHeight := art_frame_length(arrowFrm, 0, 0);

  menuItemWidth := art_frame_width(menuItemFrms[0], 0, 0);
  menuItemHeight := art_frame_length(menuItemFrms[0], 0, 0);

  gmouse_3d_menu_frame_hot_x := 0;
  gmouse_3d_menu_frame_hot_y := 0;

  gmouse_3d_menu_frame^.xOffsets[0] := gmouse_3d_menu_frame_width div 2;
  gmouse_3d_menu_frame^.yOffsets[0] := gmouse_3d_menu_frame_height - 1;

  v60 := y + menuItemsCount * menuItemHeight - 1;
  v24 := v60 - height + 2;
  v22 := gmouse_3d_menu_frame_data;
  v58 := v22;

  if x + arrowWidth + menuItemWidth - 1 < width then
  begin
    arrowData := art_frame_data(arrowFrm, 0, 0);
    v58 := v22 + arrowWidth;
    if height <= v60 then
    begin
      gmouse_3d_menu_frame_hot_y := gmouse_3d_menu_frame_hot_y + v24;
      v22 := v22 + gmouse_3d_menu_frame_width * v24;
      gmouse_3d_menu_frame^.yOffsets[0] := gmouse_3d_menu_frame^.yOffsets[0] - SmallInt(v24);
    end;
  end
  else
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, 285, 0, 0, 0);
    arrowFrm := art_ptr_lock(fid, @arrowFrmHandle);
    arrowData := art_frame_data(arrowFrm, 0, 0);
    gmouse_3d_menu_frame^.xOffsets[0] := -gmouse_3d_menu_frame^.xOffsets[0];
    gmouse_3d_menu_frame_hot_x := gmouse_3d_menu_frame_hot_x + menuItemWidth + arrowWidth;
    if v60 >= height then
    begin
      gmouse_3d_menu_frame_hot_y := gmouse_3d_menu_frame_hot_y + v24;
      gmouse_3d_menu_frame^.yOffsets[0] := gmouse_3d_menu_frame^.yOffsets[0] - SmallInt(v24);
      v22 := v22 + gmouse_3d_menu_frame_width * v24;
    end;
  end;

  FillChar(gmouse_3d_menu_frame_data^, gmouse_3d_menu_frame_size, 0);
  buf_to_buf(arrowData, arrowWidth, arrowHeight, arrowWidth, v22, gmouse_3d_pick_frame_width);

  v38 := v58;
  index := 0;
  while index < menuItemsCount do
  begin
    data := art_frame_data(menuItemFrms[index], 0, 0);
    buf_to_buf(data, menuItemWidth, menuItemHeight, menuItemWidth, v38, gmouse_3d_pick_frame_width);
    v38 := v38 + gmouse_3d_menu_frame_width * menuItemHeight;
    Inc(index);
  end;

  art_ptr_unlock(arrowFrmHandle);

  index := 0;
  while index < menuItemsCount do
  begin
    art_ptr_unlock(menuItemFrmHandles[index]);
    Inc(index);
  end;

  Move(menuItems^, gmouse_3d_menu_frame_actions[0], SizeOf(Integer) * menuItemsCount);
  gmouse_3d_menu_available_actions := menuItemsCount;
  gmouse_3d_menu_actions_start := v58;

  sound := gsound_load_sound('iaccuxx1', nil);
  if sound <> nil then
    gsound_play_sound(sound);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_menu_frame_hot
// -----------------------------------------------------------------------
function gmouse_3d_menu_frame_hot(x, y: PInteger): Integer;
begin
  x^ := gmouse_3d_menu_frame_hot_x;
  y^ := gmouse_3d_menu_frame_hot_y;
  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_highlight_menu_frame
// -----------------------------------------------------------------------
function gmouse_3d_highlight_menu_frame(menuItemIndex: Integer): Integer;
var
  handle: PCacheEntry;
  fid: Integer;
  artPtr: PArt;
  width, height: Integer;
  data: PByte;
begin
  if (menuItemIndex < 0) or (menuItemIndex >= gmouse_3d_menu_available_actions) then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_action_nums[gmouse_3d_menu_frame_actions[gmouse_3d_menu_current_action_index]], 0, 0, 0);
  artPtr := art_ptr_lock(fid, @handle);
  if artPtr = nil then
  begin
    Result := -1;
    Exit;
  end;

  width := art_frame_width(artPtr, 0, 0);
  height := art_frame_length(artPtr, 0, 0);
  data := art_frame_data(artPtr, 0, 0);
  buf_to_buf(data, width, height, width, gmouse_3d_menu_actions_start + gmouse_3d_menu_frame_width * height * gmouse_3d_menu_current_action_index, gmouse_3d_menu_frame_width);
  art_ptr_unlock(handle);

  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_action_nums[gmouse_3d_menu_frame_actions[menuItemIndex]] - 1, 0, 0, 0);
  artPtr := art_ptr_lock(fid, @handle);
  if artPtr = nil then
  begin
    Result := -1;
    Exit;
  end;

  data := art_frame_data(artPtr, 0, 0);
  buf_to_buf(data, width, height, width, gmouse_3d_menu_actions_start + gmouse_3d_menu_frame_width * height * menuItemIndex, gmouse_3d_menu_frame_width);
  art_ptr_unlock(handle);

  gmouse_3d_menu_current_action_index := menuItemIndex;

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_build_to_hit_frame
// -----------------------------------------------------------------------
function gmouse_3d_build_to_hit_frame(str: PAnsiChar; color: Integer): Integer;
var
  crosshairFrmHandle: PCacheEntry;
  fid: Integer;
  crosshairFrm: PArt;
  crosshairFrmWidth, crosshairFrmHeight: Integer;
  crosshairFrmData: PByte;
  oldFont: Integer;
begin
  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_mode_nums[GAME_MOUSE_MODE_CROSSHAIR], 0, 0, 0);
  crosshairFrm := art_ptr_lock(fid, @crosshairFrmHandle);
  if crosshairFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  FillChar(gmouse_3d_to_hit_frame_data^, gmouse_3d_to_hit_frame_size, 0);

  crosshairFrmWidth := art_frame_width(crosshairFrm, 0, 0);
  crosshairFrmHeight := art_frame_length(crosshairFrm, 0, 0);
  crosshairFrmData := art_frame_data(crosshairFrm, 0, 0);
  buf_to_buf(crosshairFrmData,
    crosshairFrmWidth,
    crosshairFrmHeight,
    crosshairFrmWidth,
    gmouse_3d_to_hit_frame_data,
    gmouse_3d_to_hit_frame_width);

  oldFont := text_curr();
  text_font(101);

  text_to_buf(gmouse_3d_to_hit_frame_data + gmouse_3d_to_hit_frame_width + crosshairFrmWidth + 1,
    str,
    gmouse_3d_to_hit_frame_width - crosshairFrmWidth,
    gmouse_3d_to_hit_frame_width,
    color);

  buf_outline(gmouse_3d_to_hit_frame_data + crosshairFrmWidth,
    gmouse_3d_to_hit_frame_width - crosshairFrmWidth,
    gmouse_3d_to_hit_frame_height,
    gmouse_3d_to_hit_frame_width,
    colorTable[0]);

  text_font(oldFont);

  art_ptr_unlock(crosshairFrmHandle);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_build_hex_frame
// -----------------------------------------------------------------------
function gmouse_3d_build_hex_frame(str: PAnsiChar; color: Integer): Integer;
var
  oldFont: Integer;
  len: Integer;
  fid: Integer;
begin
  FillChar(gmouse_3d_hex_frame_data^, gmouse_3d_hex_frame_width * gmouse_3d_hex_frame_height, 0);

  if str^ = #0 then
  begin
    Result := 0;
    Exit;
  end;

  oldFont := text_curr();
  text_font(101);

  len := text_width(str);
  text_to_buf(
    gmouse_3d_hex_frame_data + gmouse_3d_hex_frame_width * ((gmouse_3d_hex_frame_height - text_height()) div 2) + ((gmouse_3d_hex_frame_width - len) div 2),
    str,
    gmouse_3d_hex_frame_width,
    gmouse_3d_hex_frame_width,
    color);

  buf_outline(gmouse_3d_hex_frame_data, gmouse_3d_hex_frame_width, gmouse_3d_hex_frame_height, gmouse_3d_hex_frame_width, colorTable[0]);

  text_font(oldFont);

  fid := art_id(OBJ_TYPE_INTERFACE, 1, 0, 0, 0);
  gmouse_3d_set_fid(fid);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_synch_item_highlight
// -----------------------------------------------------------------------
procedure gmouse_3d_synch_item_highlight;
var
  itemHighlight: Boolean;
begin
  if configGetBool(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_ITEM_HIGHLIGHT_KEY, @itemHighlight) then
    gmouse_3d_item_highlight := itemHighlight;
end;

// -----------------------------------------------------------------------
// gmouse_3d_init (static)
// -----------------------------------------------------------------------
function gmouse_3d_init: Integer;
var
  fid: Integer;
  x, y: Integer;
  v9: TRect;
begin
  if gmouse_3d_initialized then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 0, 0, 0, 0);
  if obj_new(@obj_mouse, fid, -1) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 1, 0, 0, 0);
  if obj_new(@obj_mouse_flat, fid, -1) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if obj_outline_object(obj_mouse_flat, Integer(OUTLINE_PALETTED) or Integer(OUTLINE_TYPE_2), nil) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if gmouse_3d_lock_frames() <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  obj_mouse^.Flags := obj_mouse^.Flags or Integer(OBJECT_LIGHT_THRU);
  obj_mouse^.Flags := obj_mouse^.Flags or OBJECT_NO_SAVE;
  obj_mouse^.Flags := obj_mouse^.Flags or OBJECT_NO_REMOVE;
  obj_mouse^.Flags := obj_mouse^.Flags or Integer(OBJECT_SHOOT_THRU);
  obj_mouse^.Flags := obj_mouse^.Flags or OBJECT_NO_BLOCK;

  obj_mouse_flat^.Flags := obj_mouse_flat^.Flags or OBJECT_NO_REMOVE;
  obj_mouse_flat^.Flags := obj_mouse_flat^.Flags or OBJECT_NO_SAVE;
  obj_mouse_flat^.Flags := obj_mouse_flat^.Flags or Integer(OBJECT_LIGHT_THRU);
  obj_mouse_flat^.Flags := obj_mouse_flat^.Flags or Integer(OBJECT_SHOOT_THRU);
  obj_mouse_flat^.Flags := obj_mouse_flat^.Flags or OBJECT_NO_BLOCK;

  obj_toggle_flat(obj_mouse_flat, nil);

  mouse_get_position(@x, @y);

  gmouse_3d_move_to(x, y, map_elevation, @v9);

  gmouse_3d_initialized := True;

  gmouse_3d_synch_item_highlight();

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_reset_internal (static)
// -----------------------------------------------------------------------
function gmouse_3d_reset_internal: Integer;
begin
  if not gmouse_3d_initialized then
  begin
    Result := -1;
    Exit;
  end;

  gmouse_3d_enable_modes();
  gmouse_3d_reset_fid();

  gmouse_3d_set_mode(GAME_MOUSE_MODE_MOVE);
  gmouse_3d_on();

  gmouse_3d_last_mouse_x := -1;
  gmouse_3d_last_mouse_y := -1;
  gmouse_3d_hover_test := False;
  gmouse_3d_last_move_time := get_time();
  gmouse_3d_synch_item_highlight();

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_exit_internal (static)
// -----------------------------------------------------------------------
procedure gmouse_3d_exit_internal;
begin
  if gmouse_3d_initialized then
  begin
    gmouse_3d_unlock_frames();

    obj_mouse^.Flags := obj_mouse^.Flags and (not OBJECT_NO_SAVE);
    obj_mouse_flat^.Flags := obj_mouse_flat^.Flags and (not OBJECT_NO_SAVE);

    obj_erase_object(obj_mouse, nil);
    obj_erase_object(obj_mouse_flat, nil);

    gmouse_3d_initialized := False;
  end;
end;

// -----------------------------------------------------------------------
// gmouse_3d_lock_frames (static)
// -----------------------------------------------------------------------
function gmouse_3d_lock_frames: Integer;
var
  fid: Integer;
begin
  // actmenu.frm - action menu
  fid := art_id(OBJ_TYPE_INTERFACE, 283, 0, 0, 0);
  gmouse_3d_menu_frame := art_ptr_lock(fid, @gmouse_3d_menu_frame_key);
  if gmouse_3d_menu_frame = nil then
  begin
    gmouse_3d_unlock_frames();
    Result := -1;
    Exit;
  end;

  // actpick.frm - action pick
  fid := art_id(OBJ_TYPE_INTERFACE, 282, 0, 0, 0);
  gmouse_3d_pick_frame := art_ptr_lock(fid, @gmouse_3d_pick_frame_key);
  if gmouse_3d_pick_frame = nil then
  begin
    gmouse_3d_unlock_frames();
    Result := -1;
    Exit;
  end;

  // acttohit.frm - action to hit
  fid := art_id(OBJ_TYPE_INTERFACE, 284, 0, 0, 0);
  gmouse_3d_to_hit_frame := art_ptr_lock(fid, @gmouse_3d_to_hit_frame_key);
  if gmouse_3d_to_hit_frame = nil then
  begin
    gmouse_3d_unlock_frames();
    Result := -1;
    Exit;
  end;

  // blank.frm
  fid := art_id(OBJ_TYPE_INTERFACE, 0, 0, 0, 0);
  gmouse_3d_hex_base_frame := art_ptr_lock(fid, @gmouse_3d_hex_base_frame_key);
  if gmouse_3d_hex_base_frame = nil then
  begin
    gmouse_3d_unlock_frames();
    Result := -1;
    Exit;
  end;

  // msef000.frm - hex mouse cursor
  fid := art_id(OBJ_TYPE_INTERFACE, 1, 0, 0, 0);
  gmouse_3d_hex_frame := art_ptr_lock(fid, @gmouse_3d_hex_frame_key);
  if gmouse_3d_hex_frame = nil then
  begin
    gmouse_3d_unlock_frames();
    Result := -1;
    Exit;
  end;

  gmouse_3d_menu_frame_width := art_frame_width(gmouse_3d_menu_frame, 0, 0);
  gmouse_3d_menu_frame_height := art_frame_length(gmouse_3d_menu_frame, 0, 0);
  gmouse_3d_menu_frame_size := gmouse_3d_menu_frame_width * gmouse_3d_menu_frame_height;
  gmouse_3d_menu_frame_data := art_frame_data(gmouse_3d_menu_frame, 0, 0);

  gmouse_3d_pick_frame_width := art_frame_width(gmouse_3d_pick_frame, 0, 0);
  gmouse_3d_pick_frame_height := art_frame_length(gmouse_3d_pick_frame, 0, 0);
  gmouse_3d_pick_frame_size := gmouse_3d_pick_frame_width * gmouse_3d_pick_frame_height;
  gmouse_3d_pick_frame_data := art_frame_data(gmouse_3d_pick_frame, 0, 0);

  gmouse_3d_to_hit_frame_width := art_frame_width(gmouse_3d_to_hit_frame, 0, 0);
  gmouse_3d_to_hit_frame_height := art_frame_length(gmouse_3d_to_hit_frame, 0, 0);
  gmouse_3d_to_hit_frame_size := gmouse_3d_to_hit_frame_width * gmouse_3d_to_hit_frame_height;
  gmouse_3d_to_hit_frame_data := art_frame_data(gmouse_3d_to_hit_frame, 0, 0);

  gmouse_3d_hex_base_frame_width := art_frame_width(gmouse_3d_hex_base_frame, 0, 0);
  gmouse_3d_hex_base_frame_height := art_frame_length(gmouse_3d_hex_base_frame, 0, 0);
  gmouse_3d_hex_base_frame_size := gmouse_3d_hex_base_frame_width * gmouse_3d_hex_base_frame_height;
  gmouse_3d_hex_base_frame_data := art_frame_data(gmouse_3d_hex_base_frame, 0, 0);

  gmouse_3d_hex_frame_width := art_frame_width(gmouse_3d_hex_frame, 0, 0);
  gmouse_3d_hex_frame_height := art_frame_length(gmouse_3d_hex_frame, 0, 0);
  gmouse_3d_hex_frame_size := gmouse_3d_hex_frame_width * gmouse_3d_hex_frame_height;
  gmouse_3d_hex_frame_data := art_frame_data(gmouse_3d_hex_frame, 0, 0);

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_unlock_frames (static)
// -----------------------------------------------------------------------
procedure gmouse_3d_unlock_frames;
begin
  if gmouse_3d_hex_base_frame_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_3d_hex_base_frame_key);
  gmouse_3d_hex_base_frame := nil;
  gmouse_3d_hex_base_frame_key := INVALID_CACHE_ENTRY;

  if gmouse_3d_hex_frame_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_3d_hex_frame_key);
  gmouse_3d_hex_frame := nil;
  gmouse_3d_hex_frame_key := INVALID_CACHE_ENTRY;

  if gmouse_3d_to_hit_frame_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_3d_to_hit_frame_key);
  gmouse_3d_to_hit_frame := nil;
  gmouse_3d_to_hit_frame_key := INVALID_CACHE_ENTRY;

  if gmouse_3d_menu_frame_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_3d_menu_frame_key);
  gmouse_3d_menu_frame := nil;
  gmouse_3d_menu_frame_key := INVALID_CACHE_ENTRY;

  if gmouse_3d_pick_frame_key <> INVALID_CACHE_ENTRY then
    art_ptr_unlock(gmouse_3d_pick_frame_key);

  gmouse_3d_pick_frame := nil;
  gmouse_3d_pick_frame_key := INVALID_CACHE_ENTRY;

  gmouse_3d_pick_frame_data := nil;
  gmouse_3d_pick_frame_width := 0;
  gmouse_3d_pick_frame_height := 0;
  gmouse_3d_pick_frame_size := 0;
end;

// -----------------------------------------------------------------------
// gmouse_3d_set_flat_fid (static)
// -----------------------------------------------------------------------
function gmouse_3d_set_flat_fid(fid: Integer; rect: PRect): Integer;
begin
  if obj_change_fid(obj_mouse_flat, fid, rect) = 0 then
    Result := 0
  else
    Result := -1;
end;

// -----------------------------------------------------------------------
// gmouse_3d_reset_flat_fid (static)
// -----------------------------------------------------------------------
function gmouse_3d_reset_flat_fid(rect: PRect): Integer;
var
  fid: Integer;
begin
  fid := art_id(OBJ_TYPE_INTERFACE, gmouse_3d_mode_nums[gmouse_3d_current_mode], 0, 0, 0);
  if obj_mouse_flat^.Fid = fid then
  begin
    Result := -1;
    Exit;
  end;

  Result := gmouse_3d_set_flat_fid(fid, rect);
end;

// -----------------------------------------------------------------------
// gmouse_3d_move_to (static)
// -----------------------------------------------------------------------
function gmouse_3d_move_to(x, y, elevation: Integer; a4: PRect): Integer;
var
  offsetX, offsetY: Integer;
  hexCursorFrmHandle: PCacheEntry;
  hexCursorFrm: PArt;
  frameOffsetX, frameOffsetY: Integer;
  tile_: Integer;
  screenX, screenY: Integer;
  v1: Boolean;
  rect1, rect2: TRect;
  x1, y1: Integer;
  fid_: Integer;
  squareTile: Integer;
  executable: PAnsiChar;
begin
  if gmouse_mapper_mode = 0 then
  begin
    if gmouse_3d_current_mode <> GAME_MOUSE_MODE_MOVE then
    begin
      offsetX := 0;
      offsetY := 0;
      hexCursorFrm := art_ptr_lock(obj_mouse_flat^.Fid, @hexCursorFrmHandle);
      if hexCursorFrm <> nil then
      begin
        art_frame_offset(hexCursorFrm, 0, @offsetX, @offsetY);

        art_frame_hot(hexCursorFrm, 0, 0, @frameOffsetX, @frameOffsetY);

        offsetX := offsetX + frameOffsetX;
        offsetY := offsetY + frameOffsetY;

        art_ptr_unlock(hexCursorFrmHandle);
      end;

      obj_move(obj_mouse_flat, x + offsetX, y + offsetY, elevation, a4);
    end
    else
    begin
      tile_ := tile_num(x, y, 0);
      if tile_ <> -1 then
      begin
        v1 := False;
        if tile_coord(tile_, @screenX, @screenY, 0) = 0 then
        begin
          if obj_move(obj_mouse, screenX + 16, screenY + 15, 0, @rect1) = 0 then
            v1 := True;
        end;

        if obj_move_to_tile(obj_mouse_flat, tile_, elevation, @rect2) = 0 then
        begin
          if v1 then
            rect_min_bound(@rect1, @rect2, @rect1)
          else
            rectCopy(@rect1, @rect2);

          rectCopy(a4, @rect1);
        end;
      end;
    end;
    Result := 0;
    Exit;
  end;

  x1 := 0;
  y1 := 0;

  fid_ := obj_mouse^.Fid;
  if FID_TYPE(fid_) = OBJ_TYPE_TILE then
  begin
    squareTile := square_num(x, y, elevation);
    if squareTile = -1 then
    begin
      tile_ := HEX_GRID_WIDTH * (2 * (squareTile div SQUARE_GRID_WIDTH) + 1) + 2 * (squareTile mod SQUARE_GRID_WIDTH) + 1;
      x1 := -8;
      y1 := 13;

      if config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_EXECUTABLE_KEY, @executable) then
      begin
        if compat_stricmp(executable, 'mapper') = 0 then
        begin
          if tile_roof_visible() <> 0 then
          begin
            if (obj_dude^.Flags and OBJECT_HIDDEN) = 0 then
              y1 := -83;
          end;
        end;
      end;
    end
    else
      tile_ := -1;
  end
  else
    tile_ := tile_num(x, y, elevation);

  if tile_ <> -1 then
  begin
    v1 := False;

    if obj_move_to_tile(obj_mouse, tile_, elevation, @rect1) = 0 then
    begin
      if (x1 <> 0) or (y1 <> 0) then
      begin
        if obj_offset(obj_mouse, x1, y1, @rect2) = 0 then
          rect_min_bound(@rect1, @rect2, @rect1);
      end;
      v1 := True;
    end;

    if gmouse_3d_current_mode <> GAME_MOUSE_MODE_MOVE then
    begin
      offsetX := 0;
      offsetY := 0;
      hexCursorFrm := art_ptr_lock(obj_mouse_flat^.Fid, @hexCursorFrmHandle);
      if hexCursorFrm <> nil then
      begin
        art_frame_offset(hexCursorFrm, 0, @offsetX, @offsetY);

        art_frame_hot(hexCursorFrm, 0, 0, @frameOffsetX, @frameOffsetY);

        offsetX := offsetX + frameOffsetX;
        offsetY := offsetY + frameOffsetY;

        art_ptr_unlock(hexCursorFrmHandle);
      end;

      if obj_move(obj_mouse_flat, x + offsetX, y + offsetY, elevation, @rect2) = 0 then
      begin
        if v1 then
          rect_min_bound(@rect1, @rect2, @rect1)
        else
        begin
          rectCopy(@rect1, @rect2);
          v1 := True;
        end;
      end;
    end
    else
    begin
      if obj_move_to_tile(obj_mouse_flat, tile_, elevation, @rect2) = 0 then
      begin
        if v1 then
          rect_min_bound(@rect1, @rect2, @rect1)
        else
        begin
          rectCopy(@rect1, @rect2);
          v1 := True;
        end;
      end;
    end;

    if v1 then
      rectCopy(a4, @rect1);
  end;

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_check_scrolling (static)
// -----------------------------------------------------------------------
function gmouse_check_scrolling(x, y, cursor: Integer): Integer;
var
  flags: Integer;
  dx, dy: Integer;
  rc: Integer;
begin
  if gmouse_scrolling_enabled = 0 then
  begin
    Result := -1;
    Exit;
  end;

  flags := 0;

  if x <= scr_size.ulx then
    flags := flags or SCROLLABLE_W;

  if x >= scr_size.lrx then
    flags := flags or SCROLLABLE_E;

  if y <= scr_size.uly then
    flags := flags or SCROLLABLE_N;

  if y >= scr_size.lry then
    flags := flags or SCROLLABLE_S;

  dx := 0;
  dy := 0;

  case flags of
    SCROLLABLE_W:
    begin
      dx := -1;
      cursor := MOUSE_CURSOR_SCROLL_W;
    end;
    SCROLLABLE_E:
    begin
      dx := 1;
      cursor := MOUSE_CURSOR_SCROLL_E;
    end;
    SCROLLABLE_N:
    begin
      dy := -1;
      cursor := MOUSE_CURSOR_SCROLL_N;
    end;
    SCROLLABLE_N or SCROLLABLE_W:
    begin
      dx := -1;
      dy := -1;
      cursor := MOUSE_CURSOR_SCROLL_NW;
    end;
    SCROLLABLE_N or SCROLLABLE_E:
    begin
      dx := 1;
      dy := -1;
      cursor := MOUSE_CURSOR_SCROLL_NE;
    end;
    SCROLLABLE_S:
    begin
      dy := 1;
      cursor := MOUSE_CURSOR_SCROLL_S;
    end;
    SCROLLABLE_S or SCROLLABLE_W:
    begin
      dx := -1;
      dy := 1;
      cursor := MOUSE_CURSOR_SCROLL_SW;
    end;
    SCROLLABLE_S or SCROLLABLE_E:
    begin
      dx := 1;
      dy := 1;
      cursor := MOUSE_CURSOR_SCROLL_SE;
    end;
  end;

  if (dx = 0) and (dy = 0) then
  begin
    Result := -1;
    Exit;
  end;

  rc := map_scroll(dx, dy);
  case rc of
    -1:
    begin
      // Scrolling is blocked, upgrade cursor to blocked version
      cursor := cursor + 8;
      gmouse_set_cursor(cursor);
    end;
    0:
      gmouse_set_cursor(cursor);
  end;

  Result := 0;
end;

// -----------------------------------------------------------------------
// gmouse_remove_item_outline
// -----------------------------------------------------------------------
procedure gmouse_remove_item_outline(obj: PObject);
var
  rect: TRect;
begin
  if (outlined_object <> nil) and (outlined_object = obj) then
  begin
    if obj_remove_outline(obj, @rect) = 0 then
      tile_refresh_rect(@rect, map_elevation);
    outlined_object := nil;
  end;
end;

// -----------------------------------------------------------------------
// gameMouseRefreshImmediately
// -----------------------------------------------------------------------
procedure gameMouseRefreshImmediately;
begin
  gmouse_bk_process();
  renderPresent();
end;

end.
