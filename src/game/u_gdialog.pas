{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/gdialog.h + gdialog.cc
// Game dialog / conversation tree system.

unit u_gdialog;

interface

uses
  u_cache, u_object_types, u_art, u_intrpret;

var
  light_BlendTable: PByte;
  dark_BlendTable: PByte;
  dialog_target: PObject;
  dialog_target_is_party: Boolean;
  dialogue_head: Integer;
  dialogue_scr_id: Integer;
  light_GrayTable: array[0..255] of Byte;
  dark_GrayTable: array[0..255] of Byte;

function gdialog_init: Integer;
function gdialog_reset: Integer;
function gdialog_exit: Integer;
function dialog_active: Boolean;
procedure gdialog_enter(target: PObject; a2: Integer);
procedure dialogue_system_enter;
procedure gdialog_setup_speech(const audioFileName: PAnsiChar);
procedure gdialog_free_speech;
function gDialogEnableBK: Integer;
function gDialogDisableBK: Integer;
function scr_dialogue_init(headFid, reaction: Integer): Integer;
function scr_dialogue_exit: Integer;
procedure gdialog_set_background(a1: Integer);
procedure gdialog_display_msg(msg: PAnsiChar);
function gDialogStart: Integer;
function gDialogSayMessage: Integer;
function gDialogOption(messageListId, messageId: Integer; proc: PAnsiChar; reaction: Integer): Integer;
function gDialogOptionStr(messageListId: Integer; const text: PAnsiChar; const proc: PAnsiChar; reaction: Integer): Integer;
function gDialogOptionProc(messageListId, messageId, proc, reaction: Integer): Integer;
function gDialogOptionProcStr(messageListId: Integer; const text: PAnsiChar; proc, reaction: Integer): Integer;
function gDialogReply(program_: PProgram; messageListId, messageId: Integer): Integer;
function gDialogReplyStr(program_: PProgram; messageListId: Integer; const text: PAnsiChar): Integer;
function gDialogGo: Integer;
procedure talk_to_critter_reacts(a1: Integer);
procedure gdialogSetBarterMod(modifier: Integer);
function gdActivateBarter(modifier: Integer): Integer;
procedure barter_end_to_talk_to;

implementation

uses
  SysUtils,
  u_color,
  u_gnw, u_gnw_types, u_rect, u_grbuf,
  u_button, u_input, u_text, u_mouse,
  u_memory, u_debug,
  u_lip_sync,
  u_int_dialog, u_int_window,
  u_platform_compat, u_kb,
  u_svga,
  u_gsound, u_int_sound,
  u_game,
  u_object, u_critter, u_proto, u_proto_types,
  u_scripts,
  u_message,
  u_tile, u_map,
  u_display, u_intface,
  u_gmouse, u_textobj, u_cycle, u_anim,
  u_stat, u_perk, u_reaction, u_roll,
  u_combat, u_item, u_inventry;

{ ===================================================================
  Constants
  =================================================================== }

const
  GAME_DIALOG_WINDOW_WIDTH  = 640;
  GAME_DIALOG_WINDOW_HEIGHT = 480;

  GAME_DIALOG_REPLY_WINDOW_X      = 135;
  GAME_DIALOG_REPLY_WINDOW_Y      = 225;
  GAME_DIALOG_REPLY_WINDOW_WIDTH  = 379;
  GAME_DIALOG_REPLY_WINDOW_HEIGHT = 58;

  GAME_DIALOG_OPTIONS_WINDOW_X      = 127;
  GAME_DIALOG_OPTIONS_WINDOW_Y      = 335;
  GAME_DIALOG_OPTIONS_WINDOW_WIDTH  = 393;
  GAME_DIALOG_OPTIONS_WINDOW_HEIGHT = 117;

  GAME_DIALOG_REVIEW_WINDOW_WIDTH  = 640;
  GAME_DIALOG_REVIEW_WINDOW_HEIGHT = 480;

  DIALOG_REVIEW_ENTRIES_CAPACITY = 80;
  DIALOG_OPTION_ENTRIES_CAPACITY = 30;

  GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_UP   = 0;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_DOWN  = 1;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_DONE         = 2;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_COUNT        = 3;

  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_UP_NORMAL   = 0;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_UP_PRESSED  = 1;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_DOWN_NORMAL = 2;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_DOWN_PRESSED= 3;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_DONE_NORMAL       = 4;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_DONE_PRESSED      = 5;
  GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT             = 6;

  GAME_DIALOG_REACTION_GOOD    = 49;
  GAME_DIALOG_REACTION_NEUTRAL = 50;
  GAME_DIALOG_REACTION_BAD     = 51;

  WINDOW_MODAL        = $04;
  BUTTON_FLAG_TRANSPARENT = $04;

  PERK_EMPATHY = 39;

  MOUSE_CURSOR_ARROW           = 1;
  MOUSE_CURSOR_SMALL_ARROW_UP  = 2;
  MOUSE_CURSOR_SMALL_ARROW_DOWN = 3;

  GAME_STATE_2 = 2;

{ ===================================================================
  Types
  =================================================================== }

type
  TGameDialogReviewEntry = record
    replyMessageListId: Integer;
    replyMessageId: Integer;
    replyText: PAnsiChar;
    optionMessageListId: Integer;
    optionMessageId: Integer;
    optionText: PAnsiChar;
  end;
  PGameDialogReviewEntry = ^TGameDialogReviewEntry;

  TGameDialogOptionEntry = record
    messageListId: Integer;
    messageId: Integer;
    reaction: Integer;
    proc: Integer;
    btn: Integer;
    field_14: Integer;
    text: array[0..899] of AnsiChar;
  end;
  PGameDialogOptionEntry = ^TGameDialogOptionEntry;

  TGameDialogBlock = record
    program_: PProgram;
    replyMessageListId: Integer;
    replyMessageId: Integer;
    offset: Integer;
    replyText: array[0..899] of AnsiChar;
    field_394: array[0..1799] of AnsiChar;
    options: array[0..DIALOG_OPTION_ENTRIES_CAPACITY - 1] of TGameDialogOptionEntry;
  end;

  TPathBuilderCallback = function(obj: PObject; tile, elev: Integer): PObject; cdecl;
  TButtonCallback = procedure(btn, keyCode: Integer); cdecl;



{ C library }
function libc_strtok(str: PAnsiChar; delim: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'strtok';

const
  STAT_INTELLIGENCE = 4;
  CRITTER_BARTER = $02;
  SCRIPT_PROC_TALK = 11;
  SCRIPT_TYPE_SPATIAL = 1;

{ ===================================================================
  Forward declarations of static functions
  =================================================================== }

function gdialog_hide: Integer; forward;
function gdialog_unhide: Integer; forward;
function gdialog_unhide_reply: Integer; forward;
function gdAddOption(messageListId, messageId, reaction: Integer): Integer; forward;
function gdAddOptionStr(messageListId: Integer; const text: PAnsiChar; reaction: Integer): Integer; forward;
procedure gdReviewFree; forward;
function gdAddReviewReply(messageListId, messageId: Integer): Integer; forward;
function gdAddReviewReplyStr(const str: PAnsiChar): Integer; forward;
function gdAddReviewOptionChosen(messageListId, messageId: Integer): Integer; forward;
function gdAddReviewOptionChosenStr(const str: PAnsiChar): Integer; forward;
function gDialogProcess: Integer; forward;
procedure gDialogProcessCleanup; forward;
function gDialogProcessChoice(a1: Integer): Integer; forward;
function gDialogProcessInit: Integer; forward;
procedure reply_arrow_up(btn, keyCode: Integer); cdecl; forward;
procedure reply_arrow_down(btn, keyCode: Integer); cdecl; forward;
procedure reply_arrow_restore(btn, keyCode: Integer); cdecl; forward;
procedure gDialogProcessHighlight(index: Integer); forward;
procedure gDialogProcessUnHighlight(index: Integer); forward;
procedure gDialogProcessReply; forward;
procedure gDialogProcessUpdate; forward;
function gDialogProcessExit: Integer; forward;
procedure demo_copy_title(win: Integer); cdecl; forward;
procedure demo_copy_options(win: Integer); cdecl; forward;
procedure gDialogRefreshOptionsRect(win: Integer; drawRect: PRect); forward;
procedure head_bk; cdecl; forward;
procedure talk_to_scroll_subwin(win, a2: Integer; a3, a4, a5: PByte; a6, a7: Integer); forward;
function gdialog_review: Integer; forward;
function gdialog_review_init(win: PInteger): Integer; forward;
function gdialog_review_exit(win: PInteger): Integer; forward;
procedure gdialog_review_display(win, origin: Integer); forward;
function text_to_rect_wrapped(buffer: PByte; rect: PRect; str: PAnsiChar; a4: PInteger; height, pitch, color: Integer): Integer; forward;
function text_to_rect_func(buffer: PByte; rect: PRect; str: PAnsiChar; a4: PInteger; height, pitch, color, a7: Integer): Integer; forward;
function talk_to_create_barter_win: Integer; forward;
procedure talk_to_destroy_barter_win; forward;
procedure dialogue_barter_cleanup_tables; forward;
procedure talk_to_pressed_barter(btn, keyCode: Integer); cdecl; forward;
procedure talk_to_pressed_about(btn, keyCode: Integer); cdecl; forward;
procedure talk_to_pressed_review(btn, keyCode: Integer); cdecl; forward;
function talk_to_create_dialogue_win: Integer; forward;
procedure talk_to_destroy_dialogue_win; forward;
function talk_to_create_background_window: Integer; forward;
function talk_to_refresh_background_window: Integer; forward;
function talk_to_create_head_window: Integer; forward;
procedure talk_to_destroy_head_window; forward;
procedure talk_to_set_up_fidget(headFrmId, reaction: Integer); forward;
procedure talk_to_wait_for_fidget; forward;
procedure talk_to_play_transition(anim: Integer); forward;
procedure talk_to_translucent_trans_buf_to_buf(src: PByte; srcWidth, srcHeight, srcPitch: Integer; dest: PByte; destX, destY, destPitch: Integer; a9, a10: PByte); forward;
procedure talk_to_display_frame(headFrm: PArt; frame: Integer); forward;
procedure talk_to_blend_table_init; forward;
procedure talk_to_blend_table_exit; forward;
function about_init: Integer; forward;
procedure about_exit; forward;
procedure about_loop; forward;
function about_process_input(input: Integer): Integer; forward;
procedure about_update_display(should_redraw: Byte); forward;
procedure about_clear_display(should_redraw: Byte); forward;
procedure about_reset_string; forward;
procedure about_process_string; forward;
function about_lookup_word(const search: PAnsiChar): Integer; forward;
function about_lookup_name(const search: PAnsiChar): Integer; forward;

{ ===================================================================
  Module-level variables (was static in C++)
  =================================================================== }

var
  fidgetFID: Integer = 0;
  fidgetKey: PCacheEntry = nil;
  fidgetFp: PArt = nil;
  backgroundIndex: Integer = 2;
  lipsFID: Integer = 0;
  lipsKey: PCacheEntry = nil;
  lipsFp: PArt = nil;
  gdialog_speech_playing: Boolean = False;
  headWindowBuffer: PByte = nil;
  dialogue_state: Integer = 0;
  dialogue_switch_mode: Integer = 0;
  gdialog_state: Integer = -1;
  gdDialogWentOff: Boolean = False;
  gdDialogTurnMouseOff: Boolean = False;
  peon_table_obj: PObject = nil;
  barterer_table_obj: PObject = nil;
  barterer_temp_obj: PObject = nil;
  gdBarterMod: Integer = 0;
  dialogueBackWindow: Integer = -1;
  dialogueWindow: Integer = -1;

  backgrndRects: array[0..7] of TRect = (
    (ulx: 126; uly: 14; lrx: 152; lry: 40),
    (ulx: 488; uly: 14; lrx: 514; lry: 40),
    (ulx: 126; uly: 188; lrx: 152; lry: 214),
    (ulx: 488; uly: 188; lrx: 514; lry: 214),
    (ulx: 152; uly: 14; lrx: 488; lry: 24),
    (ulx: 152; uly: 204; lrx: 488; lry: 214),
    (ulx: 126; uly: 40; lrx: 136; lry: 188),
    (ulx: 504; uly: 40; lrx: 514; lry: 188)
  );

  talk_need_to_center: Integer = 1;
  can_start_new_fidget: Boolean = False;
  gd_replyWin: Integer = -1;
  gd_optionsWin: Integer = -1;
  gDialogMusicVol: Integer = -1;
  gdCenterTile: Integer = -1;
  gdPlayerTile: Integer = -1;

  dialogue_just_started: Integer = 0;
  dialogue_seconds_since_last_input: Integer = 0;

  head_phoneme_lookup: array[0..PHONEME_COUNT - 1] of Integer = (
    0, 3, 1, 1, 3, 1, 1, 1, 7, 8,
    7, 3, 1, 8, 1, 7, 7, 6, 6, 2,
    2, 2, 2, 4, 4, 5, 5, 2, 2, 2,
    2, 2, 6, 2, 2, 5, 8, 2, 2, 2,
    2, 8
  );

  dialog_state_fix: Integer = 0;
  boxesWereDisabled: Integer = 0;
  curReviewSlot: Integer = 0;
  gdNumOptions: Integer = 0;
  gReplyWin: Integer = -1;
  gOptionWin: Integer = -1;
  gdReenterLevel: Integer = 0;
  gdReplyTooBig: Boolean = False;

  react_strs: array[0..2] of PAnsiChar = (
    'Said Good',
    'Said Neutral',
    'Said Bad'
  );

  dialogue_subwin_len: Integer = 0;

  reviewKeys: array[0..GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT - 1] of PCacheEntry = (
    PCacheEntry(1), PCacheEntry(1), PCacheEntry(1),
    PCacheEntry(1), PCacheEntry(1), PCacheEntry(1)
  );

  reviewBackKey: PCacheEntry = PCacheEntry(1); // INVALID_CACHE_ENTRY = 1

  reviewDispBackKey: PCacheEntry = PCacheEntry(1);
  reviewDispBuf: PByte = nil;

  reviewFidWids: array[0..GAME_DIALOG_REVIEW_WINDOW_BUTTON_COUNT - 1] of Integer = (35, 35, 82);
  reviewFidLens: array[0..GAME_DIALOG_REVIEW_WINDOW_BUTTON_COUNT - 1] of Integer = (35, 37, 46);

  reviewFids: array[0..GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT - 1] of Integer = (
    89, 90, 87, 88, 91, 92
  );

  dgAboutWinKey: Integer = -1;
  gdAboutRebuildButtons: Integer = 1;
  gdAboutWinBuf: PByte = nil;
  dial_win_created: Boolean = False;

  about_win: Integer = -1;
  about_win_buf: PByte = nil;
  about_button_up_key: PCacheEntry = nil;
  about_button_down_key: PCacheEntry = nil;
  about_input_string: PAnsiChar = nil;
  about_input_cursor: AnsiChar = '_';
  about_input_rect: TRect = (ulx: 22; uly: 32; lrx: 265; lry: 45);

  optionRect: TRect;
  replyRect: TRect;

  reviewList: array[0..DIALOG_REVIEW_ENTRIES_CAPACITY - 1] of TGameDialogReviewEntry;

  backgrndBufs: array[0..7] of PByte;

  about_last_time: LongWord;
  about_restore_string: array[0..899] of AnsiChar;
  about_win_width: Integer;
  about_input_index: Integer;
  about_old_font: Integer;
  reviewOldFont: Integer;

  dialogue_rest_Key1: PCacheEntry;
  dialogue_rest_Key2: PCacheEntry;
  dialogue_redbut_Key2: PCacheEntry;
  dialogue_redbut_Key1: PCacheEntry;
  dialogue_bids: array[0..2] of Integer;
  talkOldFont: Integer;

  dialogBlock: TGameDialogBlock;

  upper_hi_key: PCacheEntry;
  lower_hi_len: Integer;
  lower_hi_wid: Integer;
  upper_hi_wid: Integer;
  lower_hi_fp: PArt;
  upper_hi_len: Integer;
  lower_hi_key: PCacheEntry;
  upper_hi_fp: PArt;
  oldFont: Integer;
  fidgetAnim: Integer;
  fidgetTocksPerFrame: LongWord;
  fidgetLastTime: LongWord;
  fidgetFrameCounter: Integer;

  { static locals from head_bk }
  head_bk_loop_cnt: Integer = -1;
  head_bk_tocksWaiting: LongWord = 10000;

  { static local from talk_to_set_up_fidget }
  phone_anim: Integer = 0;

  { static local from talk_to_display_frame }
  totalHotx: Integer = 0;

{ ===================================================================
  Helper: INVALID_CACHE_ENTRY comparison
  =================================================================== }

function IS_INVALID_CACHE_ENTRY(p: PCacheEntry): Boolean; inline;
begin
  Result := (PtrUInt(p) = 1);
end;

{ ===================================================================
  Implementation
  =================================================================== }

function gdialog_init: Integer;
begin
  Result := 0;
end;

function gdialog_reset: Integer;
begin
  gdialog_free_speech;
  Result := 0;
end;

function gdialog_exit: Integer;
begin
  gdialog_free_speech;
  Result := 0;
end;

function dialog_active: Boolean;
begin
  Result := dialog_state_fix <> 0;
end;

procedure gdialog_enter(target: PObject; a2: Integer);
var
  messageListItem: TMessageListItem;
  script: PScript;
  tile: Integer;
begin
  gdDialogWentOff := False;

  if isInCombat then
    Exit;

  if target^.Sid = -1 then
    Exit;

  if (PID_TYPE(target^.Pid) <> OBJ_TYPE_ITEM) and (SID_TYPE(target^.Sid) <> SCRIPT_TYPE_SPATIAL) then
  begin
    if make_path_func(obj_dude, obj_dude^.Tile, target^.Tile, nil, 0, @obj_sight_blocking_at) = 0 then
    begin
      messageListItem.num := 660;
      if message_search(@proto_main_msg_file, @messageListItem) then
      begin
        if a2 <> 0 then
          display_print(messageListItem.text)
        else
          debug_printf(messageListItem.text);
      end
      else
        debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
      Exit;
    end;

    if tile_dist(obj_dude^.Tile, target^.Tile) > 12 then
    begin
      messageListItem.num := 661;
      if message_search(@proto_main_msg_file, @messageListItem) then
      begin
        if a2 <> 0 then
          display_print(messageListItem.text)
        else
          debug_printf(messageListItem.text);
      end
      else
        debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
      Exit;
    end;
  end;

  gdCenterTile := tile_center_tile;
  gdBarterMod := 0;
  gdPlayerTile := obj_dude^.Tile;
  map_disable_bk_processes;

  dialog_state_fix := 1;
  dialog_target := target;
  dialogue_just_started := 1;

  if target^.Sid <> -1 then
    exec_script_proc(target^.Sid, SCRIPT_PROC_TALK);

  if scr_ptr(target^.Sid, @script) = -1 then
  begin
    gmouse_3d_on;
    map_enable_bk_processes;
    scr_exec_map_update_scripts;
    dialog_state_fix := 0;
    Exit;
  end;

  if (script^.scriptOverrides <> 0) or (dialogue_state <> 4) then
  begin
    dialogue_just_started := 0;
    map_enable_bk_processes;
    scr_exec_map_update_scripts;
    dialog_state_fix := 0;
    Exit;
  end;

  gdialog_free_speech;

  if gdialog_state = 1 then
  begin
    case dialogue_switch_mode of
      2: talk_to_destroy_dialogue_win;
      1: talk_to_destroy_barter_win;
    else
      case dialogue_state of
        1: talk_to_destroy_dialogue_win;
        4: talk_to_destroy_barter_win;
      end;
    end;
    scr_dialogue_exit;
  end;

  gdialog_state := 0;
  dialogue_state := 0;

  tile := obj_dude^.Tile;
  if gdPlayerTile <> tile then
    gdCenterTile := tile;

  if gdDialogWentOff then
    tile_scroll_to(gdCenterTile, 2);

  map_enable_bk_processes;
  scr_exec_map_update_scripts;

  dialog_state_fix := 0;
end;

procedure dialogue_system_enter;
begin
  game_state_update;

  gdDialogTurnMouseOff := True;

  soundUpdate;
  gdialog_enter(dialog_target, 0);
  soundUpdate;

  if gdPlayerTile <> obj_dude^.Tile then
    gdCenterTile := obj_dude^.Tile;

  if gdDialogWentOff then
    tile_scroll_to(gdCenterTile, 2);

  game_state_request(GAME_STATE_2);

  game_state_update;
end;

procedure gdialog_setup_speech(const audioFileName: PAnsiChar);
var
  name: array[0..15] of AnsiChar;
begin
  if art_get_base_name(OBJ_TYPE_HEAD, dialogue_head and $FFF, @name[0]) = -1 then
    Exit;

  if lips_load_file(audioFileName, @name[0]) = -1 then
    Exit;

  gdialog_speech_playing := True;

  lips_play_speech;

  debug_printf(PAnsiChar('Starting lipsynch speech'));
end;

procedure gdialog_free_speech;
begin
  if gdialog_speech_playing then
  begin
    debug_printf(PAnsiChar('Ending lipsynch system'));
    gdialog_speech_playing := False;
    lips_free_speech;
  end;
end;

function gDialogEnableBK: Integer;
begin
  add_bk_process(@head_bk);
  Result := 0;
end;

function gDialogDisableBK: Integer;
begin
  remove_bk_process(@head_bk);
  Result := 0;
end;

function scr_dialogue_init(headFid, reaction: Integer): Integer;
begin
  if dialogue_state = 1 then
  begin
    Result := -1;
    Exit;
  end;

  if gdialog_state = 1 then
  begin
    Result := 0;
    Exit;
  end;

  anim_stop;

  boxesWereDisabled := Ord(disable_box_bar_win);
  oldFont := text_curr;
  text_font(101);
  dialogSetReplyWindow(135, 225, 379, 58, nil);
  dialogSetReplyColor(0.3, 0.3, 0.3);
  dialogSetOptionWindow(127, 335, 393, 117, nil);
  dialogSetOptionColor(0.2, 0.2, 0.2);
  dialogTitle(nil);
  dialogRegisterWinDrawCallbacks(@demo_copy_title, @demo_copy_options);
  talk_to_blend_table_init;
  cycle_disable;
  if gdDialogTurnMouseOff then
    gmouse_disable(0);
  gmouse_3d_off;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
  text_object_reset;

  if PID_TYPE(dialog_target^.Pid) <> OBJ_TYPE_ITEM then
    tile_scroll_to(dialog_target^.Tile, 2);

  talk_need_to_center := 1;

  talk_to_create_head_window;
  add_bk_process(@head_bk);
  talk_to_set_up_fidget(headFid, reaction);
  gdialog_state := 1;
  gmouse_disable_scrolling;

  if headFid = -1 then
    gDialogMusicVol := gsound_background_volume_get_set(gDialogMusicVol div 2)
  else
  begin
    gDialogMusicVol := -1;
    gsound_background_stop;
  end;

  gdDialogWentOff := True;

  Result := 0;
end;

function scr_dialogue_exit: Integer;
begin
  if dialogue_switch_mode = 2 then
  begin
    Result := -1;
    Exit;
  end;

  if gdialog_state = 0 then
  begin
    Result := 0;
    Exit;
  end;

  gdialog_free_speech;
  gdReviewFree;
  remove_bk_process(@head_bk);

  if PID_TYPE(dialog_target^.Pid) <> OBJ_TYPE_ITEM then
  begin
    if gdPlayerTile <> obj_dude^.Tile then
      gdCenterTile := obj_dude^.Tile;
    tile_scroll_to(gdCenterTile, 2);
  end;

  talk_to_destroy_head_window;

  text_font(oldFont);

  if fidgetFp <> nil then
  begin
    art_ptr_unlock(fidgetKey);
    fidgetFp := nil;
  end;

  if lipsKey <> nil then
  begin
    if art_ptr_unlock(lipsKey) = -1 then
      debug_printf(PAnsiChar('Failure unlocking lips frame!'#10));
    lipsKey := nil;
    lipsFp := nil;
    lipsFID := 0;
  end;

  talk_to_blend_table_exit;

  gdialog_state := 0;
  dialogue_state := 0;

  cycle_enable;

  gmouse_enable_scrolling;

  if gDialogMusicVol = -1 then
    gsound_background_restart_last(11)
  else
    gsound_background_volume_set(gDialogMusicVol);

  if boxesWereDisabled <> 0 then
    enable_box_bar_win;

  boxesWereDisabled := 0;

  if gdDialogTurnMouseOff then
  begin
    gmouse_enable;
    gdDialogTurnMouseOff := False;
  end;

  gmouse_3d_on;

  gdDialogWentOff := True;

  Result := 0;
end;

procedure gdialog_set_background(a1: Integer);
begin
  if a1 <> -1 then
    backgroundIndex := a1;
end;

function gdialog_hide: Integer;
begin
  if gd_replyWin <> -1 then
    win_hide(gd_replyWin);
  if gd_optionsWin <> -1 then
    win_hide(gd_optionsWin);
  Result := 0;
end;

function gdialog_unhide: Integer;
begin
  if gd_replyWin <> -1 then
    win_show(gd_replyWin);
  if gd_optionsWin <> -1 then
    win_show(gd_optionsWin);
  Result := 0;
end;

function gdialog_unhide_reply: Integer;
begin
  if gd_replyWin <> -1 then
    win_show(gd_replyWin);
  Result := 0;
end;

procedure gdialog_display_msg(msg: PAnsiChar);
var
  a4: Integer;
begin
  if gd_replyWin = -1 then
    debug_printf(PAnsiChar(#10'Error: Reply window doesn''t exist!'));

  replyRect.ulx := 5;
  replyRect.uly := 10;
  replyRect.lrx := 374;
  replyRect.lry := 58;

  perk_level(PERK_EMPATHY);

  demo_copy_title(gReplyWin);

  a4 := 0;

  text_to_rect_wrapped(win_get_buf(gReplyWin),
    @replyRect,
    msg,
    @a4,
    text_height(),
    379,
    colorTable[992] or $2000000);

  win_show(gd_replyWin);
  win_draw(gReplyWin);
end;

function gDialogStart: Integer;
begin
  curReviewSlot := 0;
  gdNumOptions := 0;
  Result := 0;
end;

function gdAddOption(messageListId, messageId, reaction: Integer): Integer;
var
  optionEntry: PGameDialogOptionEntry;
begin
  if gdNumOptions >= DIALOG_OPTION_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: dialog: Ran out of options!'));
    Result := -1;
    Exit;
  end;

  optionEntry := @dialogBlock.options[gdNumOptions];
  optionEntry^.messageListId := messageListId;
  optionEntry^.messageId := messageId;
  optionEntry^.reaction := reaction;
  optionEntry^.btn := -1;
  optionEntry^.text[0] := #0;

  Inc(gdNumOptions);

  Result := 0;
end;

function gdAddOptionStr(messageListId: Integer; const text: PAnsiChar; reaction: Integer): Integer;
var
  optionEntry: PGameDialogOptionEntry;
begin
  if gdNumOptions >= DIALOG_OPTION_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: dialog: Ran out of options!'));
    Result := -1;
    Exit;
  end;

  optionEntry := @dialogBlock.options[gdNumOptions];
  optionEntry^.messageListId := -4;
  optionEntry^.messageId := -4;
  optionEntry^.reaction := reaction;
  optionEntry^.btn := -1;
  StrLFmt(@optionEntry^.text[0], SizeOf(optionEntry^.text) - 1, '%s %s', [AnsiChar(#$95), text]);

  Inc(gdNumOptions);

  Result := 0;
end;

function gDialogOption(messageListId, messageId: Integer; proc: PAnsiChar; reaction: Integer): Integer;
begin
  dialogBlock.options[gdNumOptions].proc := 0;
  Result := gdAddOption(messageListId, messageId, reaction);
end;

function gDialogOptionStr(messageListId: Integer; const text: PAnsiChar; const proc: PAnsiChar; reaction: Integer): Integer;
begin
  dialogBlock.options[gdNumOptions].proc := 0;
  Result := gdAddOptionStr(messageListId, text, reaction);
end;

function gDialogOptionProc(messageListId, messageId, proc, reaction: Integer): Integer;
begin
  dialogBlock.options[gdNumOptions].proc := proc;
  Result := gdAddOption(messageListId, messageId, reaction);
end;

function gDialogOptionProcStr(messageListId: Integer; const text: PAnsiChar; proc, reaction: Integer): Integer;
begin
  dialogBlock.options[gdNumOptions].proc := proc;
  Result := gdAddOptionStr(messageListId, text, reaction);
end;

function gDialogReply(program_: PProgram; messageListId, messageId: Integer): Integer;
begin
  gdAddReviewReply(messageListId, messageId);

  dialogBlock.program_ := program_;
  dialogBlock.replyMessageListId := messageListId;
  dialogBlock.replyMessageId := messageId;
  dialogBlock.offset := 0;
  dialogBlock.replyText[0] := #0;
  gdNumOptions := 0;

  Result := 0;
end;

function gDialogReplyStr(program_: PProgram; messageListId: Integer; const text: PAnsiChar): Integer;
begin
  gdAddReviewReplyStr(text);

  dialogBlock.program_ := program_;
  dialogBlock.offset := 0;
  dialogBlock.replyMessageListId := -4;
  dialogBlock.replyMessageId := -4;

  StrCopy(@dialogBlock.replyText[0], text);

  gdNumOptions := 0;

  Result := 0;
end;

function gDialogGo: Integer;
var
  rc: Integer;
begin
  if dialogBlock.replyMessageListId = -1 then
  begin
    Result := 0;
    Exit;
  end;

  rc := 0;

  if gdNumOptions < 1 then
  begin
    dialogBlock.options[gdNumOptions].proc := 0;

    if gDialogOption(-1, -1, nil, 50) = -1 then
    begin
      interpretError('Error setting option.', []);
      rc := -1;
    end;
  end;

  if rc <> -1 then
    rc := gDialogProcess;

  gdNumOptions := 0;

  Result := rc;
end;

procedure gdReviewFree;
var
  index: Integer;
  entry: PGameDialogReviewEntry;
begin
  index := 0;
  while index < curReviewSlot do
  begin
    entry := @reviewList[index];
    entry^.replyMessageListId := 0;
    entry^.replyMessageId := 0;

    if entry^.replyText <> nil then
    begin
      mem_free(entry^.replyText);
      entry^.replyText := nil;
    end;

    entry^.optionMessageListId := 0;
    entry^.optionMessageId := 0;

    Inc(index);
  end;
end;

function gdAddReviewReply(messageListId, messageId: Integer): Integer;
var
  entry: PGameDialogReviewEntry;
begin
  if curReviewSlot >= DIALOG_REVIEW_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: Ran out of review slots!'));
    Result := -1;
    Exit;
  end;

  entry := @reviewList[curReviewSlot];
  entry^.replyMessageListId := messageListId;
  entry^.replyMessageId := messageId;

  entry^.optionMessageListId := -1;
  entry^.optionMessageId := -1;

  entry^.optionMessageListId := -3;
  entry^.optionMessageId := -3;

  Inc(curReviewSlot);

  Result := 0;
end;

function gdAddReviewReplyStr(const str: PAnsiChar): Integer;
var
  entry: PGameDialogReviewEntry;
begin
  if curReviewSlot >= DIALOG_REVIEW_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: Ran out of review slots!'));
    Result := -1;
    Exit;
  end;

  entry := @reviewList[curReviewSlot];
  entry^.replyMessageListId := -4;
  entry^.replyMessageId := -4;

  if entry^.replyText <> nil then
  begin
    mem_free(entry^.replyText);
    entry^.replyText := nil;
  end;

  entry^.replyText := PAnsiChar(mem_malloc(StrLen(str) + 1));
  StrCopy(entry^.replyText, str);

  entry^.optionMessageListId := -3;
  entry^.optionMessageId := -3;
  entry^.optionText := nil;

  Inc(curReviewSlot);

  Result := 0;
end;

function gdAddReviewOptionChosen(messageListId, messageId: Integer): Integer;
var
  entry: PGameDialogReviewEntry;
begin
  if curReviewSlot >= DIALOG_REVIEW_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: Ran out of review slots!'));
    Result := -1;
    Exit;
  end;

  entry := @reviewList[curReviewSlot - 1];
  entry^.optionMessageListId := messageListId;
  entry^.optionMessageId := messageId;
  entry^.optionText := nil;

  Result := 0;
end;

function gdAddReviewOptionChosenStr(const str: PAnsiChar): Integer;
var
  entry: PGameDialogReviewEntry;
begin
  if curReviewSlot >= DIALOG_REVIEW_ENTRIES_CAPACITY then
  begin
    debug_printf(PAnsiChar(#10'Error: Ran out of review slots!'));
    Result := -1;
    Exit;
  end;

  entry := @reviewList[curReviewSlot - 1];
  entry^.optionMessageListId := -4;
  entry^.optionMessageId := -4;

  entry^.optionText := PAnsiChar(mem_malloc(StrLen(str) + 1));
  StrCopy(entry^.optionText, str);

  Result := 0;
end;

function gDialogSayMessage: Integer;
begin
  mouse_show;
  gDialogGo;

  gdNumOptions := 0;
  dialogBlock.replyMessageListId := -1;

  Result := 0;
end;

function gDialogProcess: Integer;
var
  v18: Integer;
  tick: LongWord;
  pageCount: Integer;
  pageIndex: Integer;
  pageOffsets: array[0..9] of Integer;
  keyCode: Integer;
  v5: Integer;
  v6: LongWord;
  option: Integer;
begin
  if gdReenterLevel = 0 then
  begin
    if gDialogProcessInit = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  Inc(gdReenterLevel);

  gDialogProcessUpdate;

  v18 := 0;
  if dialogBlock.offset <> 0 then
  begin
    v18 := 1;
    gdReplyTooBig := True;
  end;

  tick := get_time;
  pageCount := 0;
  pageIndex := 0;
  pageOffsets[0] := 0;

  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;

    convertMouseWheelToArrowKey(@keyCode);

    if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
      game_quit_with_confirm;

    if game_user_wants_to_quit <> 0 then
      Break;

    if (keyCode = KEY_CTRL_B) and (not mouse_click_in(135, 225, 514, 283)) then
    begin
      if gmouse_get_cursor <> MOUSE_CURSOR_ARROW then
        gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    end
    else
    begin
      if dialogue_switch_mode = 3 then
      begin
        dialogue_state := 4;
        barter_inventory(dialogueWindow, dialog_target, peon_table_obj, barterer_table_obj, gdBarterMod);
        dialogue_barter_cleanup_tables;

        v5 := dialogue_state;
        talk_to_destroy_barter_win;
        dialogue_state := v5;

        if v5 = 4 then
        begin
          dialogue_switch_mode := 1;
          dialogue_state := 1;
        end;

        renderPresent;
        sharedFpsLimiter.Throttle;
        Continue;
      end;

      if dialogue_switch_mode = 6 then
        about_loop
      else if keyCode = KEY_LOWERCASE_B then
        talk_to_pressed_barter(-1, -1)
      else if keyCode = KEY_LOWERCASE_A then
        talk_to_pressed_about(-1, -1);
    end;

    if gdReplyTooBig then
    begin
      v6 := get_bk_time;
      if v18 <> 0 then
      begin
        if (elapsed_tocks(v6, tick) >= 10000) or (keyCode = KEY_SPACE) then
        begin
          Inc(pageCount);
          Inc(pageIndex);
          pageOffsets[pageCount] := dialogBlock.offset;
          gDialogProcessReply;
          tick := v6;
          if dialogBlock.offset = 0 then
            v18 := 0;
        end;
      end;

      if keyCode = KEY_ARROW_UP then
      begin
        if pageIndex > 0 then
        begin
          Dec(pageIndex);
          dialogBlock.offset := pageOffsets[pageIndex];
          v18 := 0;
          gDialogProcessReply;
        end;
      end
      else if keyCode = KEY_ARROW_DOWN then
      begin
        if pageIndex < pageCount then
        begin
          Inc(pageIndex);
          dialogBlock.offset := pageOffsets[pageIndex];
          v18 := 0;
          gDialogProcessReply;
        end
        else
        begin
          if dialogBlock.offset <> 0 then
          begin
            tick := v6;
            Inc(pageIndex);
            Inc(pageCount);
            pageOffsets[pageCount] := dialogBlock.offset;
            v18 := 0;
            gDialogProcessReply;
          end;
        end;
      end;
    end;

    if keyCode <> -1 then
    begin
      if (keyCode >= 1200) and (keyCode <= 1250) then
        gDialogProcessHighlight(keyCode - 1200)
      else if (keyCode >= 1300) and (keyCode <= 1330) then
        gDialogProcessUnHighlight(keyCode - 1300)
      else if (keyCode >= 48) and (keyCode <= 57) then
      begin
        option := keyCode - 49;
        if option < gdNumOptions then
        begin
          pageCount := 0;
          pageIndex := 0;
          pageOffsets[0] := 0;
          gdReplyTooBig := False;

          if gDialogProcessChoice(option) = -1 then
            Break;

          tick := get_time;

          if dialogBlock.offset <> 0 then
          begin
            v18 := 1;
            gdReplyTooBig := True;
          end
          else
            v18 := 0;
        end;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  Dec(gdReenterLevel);

  if gdReenterLevel = 0 then
  begin
    if gDialogProcessExit = -1 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  Result := 0;
end;

procedure gDialogProcessCleanup;
var
  index: Integer;
  optionEntry: PGameDialogOptionEntry;
begin
  index := 0;
  while index < gdNumOptions do
  begin
    optionEntry := @dialogBlock.options[index];
    if optionEntry^.btn <> -1 then
    begin
      win_delete_button(optionEntry^.btn);
      optionEntry^.btn := -1;
    end;
    Inc(index);
  end;
end;

function gDialogProcessChoice(a1: Integer): Integer;
var
  dummy: TGameDialogOptionEntry;
  dialogOptionEntry: PGameDialogOptionEntry;
  v1: Integer;
begin
  FillChar(dummy, SizeOf(dummy), 0);

  mouse_hide;
  gDialogProcessCleanup;

  if a1 <> -1 then
    dialogOptionEntry := @dialogBlock.options[a1]
  else
    dialogOptionEntry := @dummy;

  if dialogOptionEntry^.messageListId = -4 then
    gdAddReviewOptionChosenStr(@dialogOptionEntry^.text[0])
  else
    gdAddReviewOptionChosen(dialogOptionEntry^.messageListId, dialogOptionEntry^.messageId);

  can_start_new_fidget := False;

  gdialog_free_speech;

  v1 := GAME_DIALOG_REACTION_NEUTRAL;
  case dialogOptionEntry^.reaction of
    GAME_DIALOG_REACTION_GOOD:    v1 := -1;
    GAME_DIALOG_REACTION_NEUTRAL: v1 := 0;
    GAME_DIALOG_REACTION_BAD:     v1 := 1;
  else
    begin
      v1 := GAME_DIALOG_REACTION_NEUTRAL;
      debug_printf(PAnsiChar(#10'Error: dialog: Empathy Perk: invalid reaction!'));
    end;
  end;

  demo_copy_title(gReplyWin);
  demo_copy_options(gOptionWin);
  win_draw(gReplyWin);
  win_draw(gOptionWin);

  gDialogProcessHighlight(a1);
  talk_to_critter_reacts(v1);

  gdNumOptions := 0;

  if gdReenterLevel < 2 then
  begin
    if dialogOptionEntry^.proc <> 0 then
      executeProcedure(dialogBlock.program_, dialogOptionEntry^.proc);
  end;

  mouse_show;

  if gdNumOptions = 0 then
  begin
    Result := -1;
    Exit;
  end;

  gDialogProcessUpdate;

  Result := 0;
end;

function gDialogProcessInit: Integer;
var
  upBtn: Integer;
  downBtn: Integer;
  replyWindowX: Integer;
  replyWindowY: Integer;
  optionsWindowX: Integer;
  optionsWindowY: Integer;
begin
  talkOldFont := text_curr;
  text_font(101);

  replyWindowX := (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2 + GAME_DIALOG_REPLY_WINDOW_X;
  replyWindowY := (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2 + GAME_DIALOG_REPLY_WINDOW_Y;
  gReplyWin := win_add(replyWindowX,
    replyWindowY,
    GAME_DIALOG_REPLY_WINDOW_WIDTH,
    GAME_DIALOG_REPLY_WINDOW_HEIGHT,
    256,
    WINDOW_MOVE_ON_TOP);
  if gReplyWin = -1 then
  begin
    Result := -1;
    Exit;
  end;

  upBtn := win_register_button(gReplyWin,
    1, 1, 377, 28,
    -1, -1, KEY_ARROW_UP, -1,
    nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
  if upBtn <> -1 then
  begin
    win_register_button_sound_func(upBtn, @gsound_red_butt_press, @gsound_red_butt_release);
    win_register_button_func(upBtn, @reply_arrow_up, @reply_arrow_restore, nil, nil);
  end;

  downBtn := win_register_button(gReplyWin,
    1, 29, 377, 28,
    -1, -1, KEY_ARROW_DOWN, -1,
    nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
  if downBtn <> -1 then
  begin
    win_register_button_sound_func(downBtn, @gsound_red_butt_press, @gsound_red_butt_release);
    win_register_button_func(downBtn, @reply_arrow_down, @reply_arrow_restore, nil, nil);
  end;

  optionsWindowX := (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2 + GAME_DIALOG_OPTIONS_WINDOW_X;
  optionsWindowY := (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2 + GAME_DIALOG_OPTIONS_WINDOW_Y;
  gOptionWin := win_add(optionsWindowX,
    optionsWindowY,
    GAME_DIALOG_OPTIONS_WINDOW_WIDTH,
    GAME_DIALOG_OPTIONS_WINDOW_HEIGHT,
    256,
    WINDOW_MOVE_ON_TOP);
  if gOptionWin = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

procedure reply_arrow_up(btn, keyCode: Integer); cdecl;
begin
  if gdReplyTooBig then
    gmouse_set_cursor(MOUSE_CURSOR_SMALL_ARROW_UP);
end;

procedure reply_arrow_down(btn, keyCode: Integer); cdecl;
begin
  if gdReplyTooBig then
    gmouse_set_cursor(MOUSE_CURSOR_SMALL_ARROW_DOWN);
end;

procedure reply_arrow_restore(btn, keyCode: Integer); cdecl;
begin
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
end;

procedure gDialogProcessHighlight(index: Integer);
var
  dummy: TGameDialogOptionEntry;
  dialogOptionEntry: PGameDialogOptionEntry;
  color: Integer;
begin
  FillChar(dummy, SizeOf(dummy), 0);

  if index <> -1 then
    dialogOptionEntry := @dialogBlock.options[index]
  else
    dialogOptionEntry := @dummy;

  if dialogOptionEntry^.btn = 0 then
    Exit;

  optionRect.ulx := 0;
  optionRect.uly := dialogOptionEntry^.field_14;
  optionRect.lrx := 391;
  if index < gdNumOptions - 1 then
    optionRect.lry := dialogBlock.options[index + 1].field_14 - 1
  else
    optionRect.lry := 111;

  gDialogRefreshOptionsRect(gOptionWin, @optionRect);

  optionRect.ulx := 5;
  optionRect.lrx := 388;

  color := colorTable[32747] or $2000000;
  if perk_level(PERK_EMPATHY) <> 0 then
  begin
    color := colorTable[32747] or $2000000;
    case dialogOptionEntry^.reaction of
      GAME_DIALOG_REACTION_GOOD:
        color := colorTable[31775] or $2000000;
      GAME_DIALOG_REACTION_NEUTRAL:
        ; { keep default }
      GAME_DIALOG_REACTION_BAD:
        color := colorTable[32074] or $2000000;
    else
      debug_printf(PAnsiChar(#10'Error: dialog: Empathy Perk: invalid reaction!'));
    end;
  end;

  text_to_rect_wrapped(win_get_buf(gOptionWin),
    @optionRect,
    @dialogOptionEntry^.text[0],
    nil,
    text_height(),
    393,
    color);

  optionRect.ulx := 0;
  optionRect.lrx := 391;
  optionRect.uly := dialogOptionEntry^.field_14;
  win_draw_rect(gOptionWin, @optionRect);
end;

procedure gDialogProcessUnHighlight(index: Integer);
var
  dialogOptionEntry: PGameDialogOptionEntry;
  color: Integer;
begin
  dialogOptionEntry := @dialogBlock.options[index];

  optionRect.ulx := 0;
  optionRect.uly := dialogOptionEntry^.field_14;
  optionRect.lrx := 391;
  if index < gdNumOptions - 1 then
    optionRect.lry := dialogBlock.options[index + 1].field_14 - 1
  else
    optionRect.lry := 111;

  gDialogRefreshOptionsRect(gOptionWin, @optionRect);

  color := colorTable[992] or $2000000;
  if perk_level(PERK_EMPATHY) <> 0 then
  begin
    color := colorTable[32747] or $2000000;
    case dialogOptionEntry^.reaction of
      GAME_DIALOG_REACTION_GOOD:
        color := colorTable[31] or $2000000;
      GAME_DIALOG_REACTION_NEUTRAL:
        color := colorTable[992] or $2000000;
      GAME_DIALOG_REACTION_BAD:
        color := colorTable[31744] or $2000000;
    else
      debug_printf(PAnsiChar(#10'Error: dialog: Empathy Perk: invalid reaction!'));
    end;
  end;

  optionRect.ulx := 5;
  optionRect.lrx := 388;

  text_to_rect_wrapped(win_get_buf(gOptionWin),
    @optionRect,
    @dialogOptionEntry^.text[0],
    nil,
    text_height(),
    393,
    color);

  optionRect.lrx := 391;
  optionRect.uly := dialogOptionEntry^.field_14;
  optionRect.ulx := 0;
  win_draw_rect(gOptionWin, @optionRect);
end;

procedure gDialogProcessReply;
begin
  replyRect.ulx := 5;
  replyRect.uly := 10;
  replyRect.lrx := 374;
  replyRect.lry := 58;

  perk_level(PERK_EMPATHY);

  demo_copy_title(gReplyWin);

  text_to_rect_wrapped(win_get_buf(gReplyWin),
    @replyRect,
    @dialogBlock.replyText[0],
    @dialogBlock.offset,
    text_height(),
    379,
    colorTable[992] or $2000000);
  win_draw(gReplyWin);
end;

procedure gDialogProcessUpdate;
var
  s: PAnsiChar;
  color: Integer;
  hasEmpathy: Boolean;
  width: Integer;
  messageListItem: TMessageListItem;
  v21: Integer;
  index: Integer;
  dialogOptionEntry: PGameDialogOptionEntry;
  text: PAnsiChar;
  y: Integer;
  max_y: Integer;
begin
  replyRect.ulx := 5;
  replyRect.uly := 10;
  replyRect.lrx := 374;
  replyRect.lry := 58;

  optionRect.ulx := 5;
  optionRect.uly := 5;
  optionRect.lrx := 388;
  optionRect.lry := 112;

  demo_copy_title(gReplyWin);
  demo_copy_options(gOptionWin);

  if dialogBlock.replyMessageListId > 0 then
  begin
    s := scr_get_msg_str_speech(dialogBlock.replyMessageListId, dialogBlock.replyMessageId, 1);
    StrLCopy(@dialogBlock.replyText[0], s, SizeOf(dialogBlock.replyText) - 1);
    dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
  end;

  gDialogProcessReply;

  color := colorTable[992] or $2000000;

  hasEmpathy := perk_level(PERK_EMPATHY) <> 0;

  width := optionRect.lrx - optionRect.ulx - 4;

  v21 := 0;

  index := 0;
  while index < gdNumOptions do
  begin
    dialogOptionEntry := @dialogBlock.options[index];

    if hasEmpathy then
    begin
      case dialogOptionEntry^.reaction of
        GAME_DIALOG_REACTION_GOOD:
          color := colorTable[31] or $2000000;
        GAME_DIALOG_REACTION_NEUTRAL:
          color := colorTable[992] or $2000000;
        GAME_DIALOG_REACTION_BAD:
          color := colorTable[31744] or $2000000;
      else
        debug_printf(PAnsiChar(#10'Error: dialog: Empathy Perk: invalid reaction!'));
      end;
    end;

    if dialogOptionEntry^.messageListId >= 0 then
    begin
      text := scr_get_msg_str_speech(dialogOptionEntry^.messageListId, dialogOptionEntry^.messageId, 0);
      StrLFmt(@dialogOptionEntry^.text[0], SizeOf(dialogOptionEntry^.text) - 1, '%s %s', [AnsiChar(#$95), text]);
    end
    else if dialogOptionEntry^.messageListId = -1 then
    begin
      if index = 0 then
      begin
        messageListItem.num := 655;
        if stat_level(obj_dude, STAT_INTELLIGENCE) < 4 then
        begin
          if message_search(@proto_main_msg_file, @messageListItem) then
            StrCopy(@dialogOptionEntry^.text[0], messageListItem.text)
          else
          begin
            debug_printf(PAnsiChar(#10'Error...can''t find message!'));
            Exit;
          end;
        end;
      end
      else
        StrCopy(@dialogOptionEntry^.text[0], ' ');
    end
    else if dialogOptionEntry^.messageListId = -2 then
    begin
      messageListItem.num := 650;
      if message_search(@proto_main_msg_file, @messageListItem) then
        StrLFmt(@dialogOptionEntry^.text[0], SizeOf(dialogOptionEntry^.text) - 1, '%s %s', [AnsiChar(#$95), messageListItem.text])
      else
      begin
        debug_printf(PAnsiChar(#10'Error...can''t find message!'));
        Exit;
      end;
    end;

    if optionRect.uly < optionRect.lry then
    begin
      y := optionRect.uly;

      dialogOptionEntry^.field_14 := y;

      if index = 0 then
        y := 0;

      text_to_rect_wrapped(win_get_buf(gOptionWin),
        @optionRect,
        @dialogOptionEntry^.text[0],
        nil,
        text_height(),
        393,
        color);

      optionRect.uly := optionRect.uly + 2;

      if index < gdNumOptions - 1 then
        max_y := optionRect.uly
      else
        max_y := optionRect.lry - 1;

      dialogOptionEntry^.btn := win_register_button(gOptionWin,
        2, y, width, max_y - y - 4,
        1200 + index, 1300 + index,
        -1, 49 + index,
        nil, nil, nil, 0);

      if dialogOptionEntry^.btn <> -1 then
        win_register_button_sound_func(dialogOptionEntry^.btn, @gsound_red_butt_press, @gsound_red_butt_release)
      else
        debug_printf(PAnsiChar(#10'Error: Can''t create button!'));
    end;

    Inc(index);
  end;

  win_draw(gReplyWin);
  win_draw(gOptionWin);
end;

function gDialogProcessExit: Integer;
begin
  gDialogProcessCleanup;

  win_delete(gReplyWin);
  gReplyWin := -1;

  win_delete(gOptionWin);
  gOptionWin := -1;

  text_font(talkOldFont);

  Result := 0;
end;

procedure demo_copy_title(win: Integer); cdecl;
var
  w, h: Integer;
  src, dest: PByte;
begin
  gd_replyWin := win;

  if win = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_title: win invalid!'));
    Exit;
  end;

  w := win_width(win);
  if w < 1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_title: width invalid!'));
    Exit;
  end;

  h := win_height(win);
  if h < 1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_title: length invalid!'));
    Exit;
  end;

  if dialogueBackWindow = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_title: dialogueBackWindow wasn''t created!'));
    Exit;
  end;

  src := win_get_buf(dialogueBackWindow);
  if src = nil then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_title: couldn''t get buffer!'));
    Exit;
  end;

  dest := win_get_buf(win);

  buf_to_buf(src + 640 * 225 + 135, w, h, 640, dest, w);
end;

procedure demo_copy_options(win: Integer); cdecl;
var
  w, h: Integer;
  windowRect: TRect;
  src, dest: PByte;
begin
  gd_optionsWin := win;

  if win = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_options: win invalid!'));
    Exit;
  end;

  w := win_width(win);
  if w < 1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_options: width invalid!'));
    Exit;
  end;

  h := win_height(win);
  if h < 1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_options: length invalid!'));
    Exit;
  end;

  if dialogueBackWindow = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_options: dialogueBackWindow wasn''t created!'));
    Exit;
  end;

  win_get_rect(dialogueWindow, @windowRect);
  windowRect.ulx := windowRect.ulx - (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2;
  windowRect.uly := windowRect.uly - (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2;

  src := win_get_buf(dialogueWindow);
  if src = nil then
  begin
    debug_printf(PAnsiChar(#10'Error: demo_copy_options: couldn''t get buffer!'));
    Exit;
  end;

  dest := win_get_buf(win);
  buf_to_buf(src + 640 * (335 - windowRect.uly) + 127, w, h, 640, dest, w);
end;

procedure gDialogRefreshOptionsRect(win: Integer; drawRect: PRect);
var
  windowRect: TRect;
  src: PByte;
  destWidth: Integer;
  dest: PByte;
begin
  if drawRect = nil then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: drawRect NULL!'));
    Exit;
  end;

  if win = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: win invalid!'));
    Exit;
  end;

  if dialogueBackWindow = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: dialogueBackWindow wasn''t created!'));
    Exit;
  end;

  win_get_rect(dialogueWindow, @windowRect);
  windowRect.ulx := windowRect.ulx - (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2;
  windowRect.uly := windowRect.uly - (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2;

  src := win_get_buf(dialogueWindow);
  if src = nil then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: couldn''t get buffer!'));
    Exit;
  end;

  if drawRect^.uly >= drawRect^.lry then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: Invalid Rect (too many options)!'));
    Exit;
  end;

  if drawRect^.ulx >= drawRect^.lrx then
  begin
    debug_printf(PAnsiChar(#10'Error: gDialogRefreshOptionsRect: Invalid Rect (too many options)!'));
    Exit;
  end;

  destWidth := win_width(win);
  dest := win_get_buf(win);

  buf_to_buf(
    src + (640 * (335 - windowRect.uly) + 127) + (640 * drawRect^.uly + drawRect^.ulx),
    drawRect^.lrx - drawRect^.ulx,
    drawRect^.lry - drawRect^.uly,
    640,
    dest + destWidth * drawRect^.uly,
    destWidth);
end;

procedure head_bk; cdecl;
begin
  case dialogue_switch_mode of
    2:
    begin
      head_bk_loop_cnt := -1;
      dialogue_switch_mode := 3;
      talk_to_destroy_dialogue_win;
      talk_to_create_barter_win;
    end;
    5:
    begin
      head_bk_loop_cnt := -1;
      dialogue_switch_mode := 6;
    end;
    1:
    begin
      head_bk_loop_cnt := -1;
      dialogue_switch_mode := 0;
      talk_to_destroy_barter_win;
      talk_to_create_dialogue_win;
      gdialog_unhide;
    end;
  end;

  if fidgetFp = nil then
    Exit;

  if gdialog_speech_playing then
  begin
    lips_bkg_proc;

    if lips_draw_head then
    begin
      talk_to_display_frame(lipsFp, head_phoneme_lookup[head_phoneme_current]);
      lips_draw_head := False;
    end;

    if not soundPlaying(lip_info.sound) then
    begin
      gdialog_free_speech;
      talk_to_display_frame(lipsFp, 0);
      can_start_new_fidget := True;
      dialogue_seconds_since_last_input := 3;
      fidgetFrameCounter := 0;
    end;
    Exit;
  end;

  if can_start_new_fidget then
  begin
    if elapsed_time(fidgetLastTime) >= head_bk_tocksWaiting then
    begin
      can_start_new_fidget := False;
      dialogue_seconds_since_last_input := dialogue_seconds_since_last_input + Integer(head_bk_tocksWaiting div 1000);
      head_bk_tocksWaiting := 1000 * LongWord(roll_random(0, 3) + 4);
      talk_to_set_up_fidget(fidgetFID and $FFF, (fidgetFID and $FF0000) shr 16);
    end;
    Exit;
  end;

  if elapsed_time(fidgetLastTime) >= fidgetTocksPerFrame then
  begin
    if art_frame_max_frame(fidgetFp) <= fidgetFrameCounter then
    begin
      talk_to_display_frame(fidgetFp, 0);
      can_start_new_fidget := True;
    end
    else
    begin
      talk_to_display_frame(fidgetFp, fidgetFrameCounter);
      fidgetLastTime := get_time;
      Inc(fidgetFrameCounter);
    end;
  end;
end;

procedure talk_to_critter_reacts(a1: Integer);
var
  v1: Integer;
  v3: Integer;
begin
  v1 := a1 + 1;

  debug_printf(PAnsiChar('Dialogue Reaction: '));
  if v1 < 3 then
    debug_printf(react_strs[v1]);

  v3 := a1 + 50;
  dialogue_seconds_since_last_input := 0;

  case v3 of
    GAME_DIALOG_REACTION_GOOD:
    begin
      case fidgetAnim of
        FIDGET_GOOD:
        begin
          talk_to_play_transition(HEAD_ANIMATION_VERY_GOOD_REACTION);
          talk_to_set_up_fidget(dialogue_head, FIDGET_GOOD);
        end;
        FIDGET_NEUTRAL:
        begin
          talk_to_play_transition(HEAD_ANIMATION_NEUTRAL_TO_GOOD);
          talk_to_set_up_fidget(dialogue_head, FIDGET_GOOD);
        end;
        FIDGET_BAD:
        begin
          talk_to_play_transition(HEAD_ANIMATION_BAD_TO_NEUTRAL);
          talk_to_set_up_fidget(dialogue_head, FIDGET_NEUTRAL);
        end;
      end;
    end;
    GAME_DIALOG_REACTION_NEUTRAL:
      ; { do nothing }
    GAME_DIALOG_REACTION_BAD:
    begin
      case fidgetAnim of
        FIDGET_GOOD:
        begin
          talk_to_play_transition(HEAD_ANIMATION_GOOD_TO_NEUTRAL);
          talk_to_set_up_fidget(dialogue_head, FIDGET_NEUTRAL);
        end;
        FIDGET_NEUTRAL:
        begin
          talk_to_play_transition(HEAD_ANIMATION_NEUTRAL_TO_BAD);
          talk_to_set_up_fidget(dialogue_head, FIDGET_BAD);
        end;
        FIDGET_BAD:
        begin
          talk_to_play_transition(HEAD_ANIMATION_VERY_BAD_REACTION);
          talk_to_set_up_fidget(dialogue_head, FIDGET_BAD);
        end;
      end;
    end;
  end;
end;

procedure talk_to_scroll_subwin(win, a2: Integer; a3, a4, a5: PByte; a6, a7: Integer);
var
  v7: Integer;
  v9: PByte;
  rect: TRect;
  tick: LongWord;
  v18: Integer;
  idx: Integer;
begin
  v7 := a6;
  v9 := a4;

  if a2 = 1 then
  begin
    rect.ulx := 0;
    rect.lrx := GAME_DIALOG_WINDOW_WIDTH - 1;
    rect.lry := a6 - 1;

    v18 := a6 div 10;
    if a7 = -1 then
    begin
      rect.uly := 10;
      v18 := 0;
    end
    else
    begin
      rect.uly := v18 * 10;
      v7 := a6 mod 10;
      v9 := v9 + GAME_DIALOG_WINDOW_WIDTH * rect.uly;
    end;

    while v18 >= 0 do
    begin
      sharedFpsLimiter.Mark;

      soundUpdate;
      buf_to_buf(a3,
        GAME_DIALOG_WINDOW_WIDTH, v7, GAME_DIALOG_WINDOW_WIDTH,
        v9, GAME_DIALOG_WINDOW_WIDTH);
      rect.uly := rect.uly - 10;
      win_draw_rect(win, @rect);
      v7 := v7 + 10;
      v9 := v9 - 10 * GAME_DIALOG_WINDOW_WIDTH;

      tick := get_time;
      while elapsed_time(tick) < 33 do
        ; { busy-wait }

      renderPresent;
      sharedFpsLimiter.Throttle;

      Dec(v18);
    end;
  end
  else
  begin
    rect.lrx := GAME_DIALOG_WINDOW_WIDTH - 1;
    rect.lry := a6 - 1;
    rect.ulx := 0;
    rect.uly := 0;

    idx := a6 div 10;
    while idx > 0 do
    begin
      sharedFpsLimiter.Mark;

      soundUpdate;

      buf_to_buf(a5,
        GAME_DIALOG_WINDOW_WIDTH, 10, GAME_DIALOG_WINDOW_WIDTH,
        v9, GAME_DIALOG_WINDOW_WIDTH);

      v9 := v9 + 10 * GAME_DIALOG_WINDOW_WIDTH;
      v7 := v7 - 10;
      a5 := a5 + 10 * GAME_DIALOG_WINDOW_WIDTH;

      buf_to_buf(a3,
        GAME_DIALOG_WINDOW_WIDTH, v7, GAME_DIALOG_WINDOW_WIDTH,
        v9, GAME_DIALOG_WINDOW_WIDTH);

      win_draw_rect(win, @rect);

      rect.uly := rect.uly + 10;

      tick := get_time;
      while elapsed_time(tick) < 33 do
        ; { busy-wait }

      renderPresent;
      sharedFpsLimiter.Throttle;

      Dec(idx);
    end;
  end;
end;

function gdialog_review: Integer;
var
  win: Integer;
  top_line: Integer;
  keyCode: Integer;
begin
  if gdialog_review_init(@win) = -1 then
  begin
    debug_printf(PAnsiChar(#10'Error initializing review window!'));
    Result := -1;
    Exit;
  end;

  top_line := 0;
  gdialog_review_display(win, top_line);

  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;

    if keyCode = KEY_ESCAPE then
      Break;

    if keyCode = KEY_ARROW_UP then
    begin
      Dec(top_line);
      if top_line >= 0 then
        gdialog_review_display(win, top_line)
      else
        top_line := 0;
    end
    else if keyCode = KEY_ARROW_DOWN then
    begin
      Inc(top_line);
      if top_line <= curReviewSlot - 1 then
        gdialog_review_display(win, top_line)
      else
        top_line := curReviewSlot - 1;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if gdialog_review_exit(@win) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function gdialog_review_init(win: PInteger): Integer;
var
  reviewWindowX, reviewWindowY: Integer;
  fid: Integer;
  backgroundFrmData: PByte;
  windowBuffer: PByte;
  buttonFrmData: array[0..GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT - 1] of PByte;
  index: Integer;
  upBtn, downBtn, doneBtn: Integer;
  backgroundFid: Integer;
begin
  if gdialog_speech_playing then
  begin
    if soundPlaying(lip_info.sound) then
      gdialog_free_speech;
  end;

  reviewOldFont := text_curr;

  if win = nil then
  begin
    Result := -1;
    Exit;
  end;

  reviewWindowX := (screenGetWidth - GAME_DIALOG_REVIEW_WINDOW_WIDTH) div 2;
  reviewWindowY := (screenGetHeight - GAME_DIALOG_REVIEW_WINDOW_HEIGHT) div 2;
  win^ := win_add(reviewWindowX,
    reviewWindowY,
    GAME_DIALOG_REVIEW_WINDOW_WIDTH,
    GAME_DIALOG_REVIEW_WINDOW_HEIGHT,
    256,
    WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win^ = -1 then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 102, 0, 0, 0);
  backgroundFrmData := art_ptr_lock_data(fid, 0, 0, @reviewBackKey);
  if backgroundFrmData = nil then
  begin
    win_delete(win^);
    win^ := -1;
    Result := -1;
    Exit;
  end;

  windowBuffer := win_get_buf(win^);
  buf_to_buf(backgroundFrmData,
    GAME_DIALOG_REVIEW_WINDOW_WIDTH,
    GAME_DIALOG_REVIEW_WINDOW_HEIGHT,
    GAME_DIALOG_REVIEW_WINDOW_WIDTH,
    windowBuffer,
    GAME_DIALOG_REVIEW_WINDOW_WIDTH);

  art_ptr_unlock(reviewBackKey);
  reviewBackKey := PCacheEntry(1); // INVALID_CACHE_ENTRY

  index := 0;
  while index < GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, reviewFids[index], 0, 0, 0);
    buttonFrmData[index] := art_ptr_lock_data(fid, 0, 0, @reviewKeys[index]);
    if buttonFrmData[index] = nil then
      Break;
    Inc(index);
  end;

  if index <> GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT then
  begin
    gdialog_review_exit(win);
    Result := -1;
    Exit;
  end;

  upBtn := win_register_button(win^,
    475, 152,
    reviewFidWids[GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_UP],
    reviewFidLens[GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_UP],
    -1, -1, -1, KEY_ARROW_UP,
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_UP_NORMAL],
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_UP_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if upBtn = -1 then
  begin
    gdialog_review_exit(win);
    Result := -1;
    Exit;
  end;
  win_register_button_sound_func(upBtn, @gsound_med_butt_press, @gsound_med_butt_release);

  downBtn := win_register_button(win^,
    475, 191,
    reviewFidWids[GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_DOWN],
    reviewFidLens[GAME_DIALOG_REVIEW_WINDOW_BUTTON_SCROLL_DOWN],
    -1, -1, -1, KEY_ARROW_DOWN,
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_DOWN_NORMAL],
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_ARROW_DOWN_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if downBtn = -1 then
  begin
    gdialog_review_exit(win);
    Result := -1;
    Exit;
  end;
  win_register_button_sound_func(downBtn, @gsound_med_butt_press, @gsound_med_butt_release);

  doneBtn := win_register_button(win^,
    499, 398,
    reviewFidWids[GAME_DIALOG_REVIEW_WINDOW_BUTTON_DONE],
    reviewFidLens[GAME_DIALOG_REVIEW_WINDOW_BUTTON_DONE],
    -1, -1, -1, KEY_ESCAPE,
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_DONE_NORMAL],
    buttonFrmData[GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_DONE_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn = -1 then
  begin
    gdialog_review_exit(win);
    Result := -1;
    Exit;
  end;
  win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  text_font(101);

  win_draw(win^);

  remove_bk_process(@head_bk);

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, 102, 0, 0, 0);
  reviewDispBuf := art_ptr_lock_data(backgroundFid, 0, 0, @reviewDispBackKey);
  if reviewDispBuf = nil then
  begin
    gdialog_review_exit(win);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

function gdialog_review_exit(win: PInteger): Integer;
var
  index: Integer;
begin
  add_bk_process(@head_bk);

  index := 0;
  while index < GAME_DIALOG_REVIEW_WINDOW_BUTTON_FRM_COUNT do
  begin
    if not IS_INVALID_CACHE_ENTRY(reviewKeys[index]) then
    begin
      art_ptr_unlock(reviewKeys[index]);
      reviewKeys[index] := PCacheEntry(1);
    end;
    Inc(index);
  end;

  if not IS_INVALID_CACHE_ENTRY(reviewDispBackKey) then
  begin
    art_ptr_unlock(reviewDispBackKey);
    reviewDispBackKey := PCacheEntry(1);
    reviewDispBuf := nil;
  end;

  text_font(reviewOldFont);

  if win = nil then
  begin
    Result := -1;
    Exit;
  end;

  win_delete(win^);
  win^ := -1;

  Result := 0;
end;

procedure gdialog_review_display(win, origin: Integer);
var
  entriesRect: TRect;
  v20: Integer;
  windowBuffer: PByte;
  w: Integer;
  y: Integer;
  index: Integer;
  dialogReviewEntry: PGameDialogReviewEntry;
  name: array[0..59] of AnsiChar;
  replyText_: PAnsiChar;
  optionText_: PAnsiChar;
begin
  entriesRect.ulx := 113;
  entriesRect.uly := 76;
  entriesRect.lrx := 422;
  entriesRect.lry := 418;

  v20 := text_height() + 2;
  windowBuffer := win_get_buf(win);
  if windowBuffer = nil then
  begin
    debug_printf(PAnsiChar(#10'Error: gdialog: review: can''t find buffer!'));
    Exit;
  end;

  w := GAME_DIALOG_WINDOW_WIDTH;
  buf_to_buf(
    reviewDispBuf + w * entriesRect.uly + entriesRect.ulx,
    w,
    entriesRect.lry - entriesRect.uly + 15,
    w,
    windowBuffer + w * entriesRect.uly + entriesRect.ulx,
    w);

  y := 76;
  index := origin;
  while index < curReviewSlot do
  begin
    dialogReviewEntry := @reviewList[index];

    StrLFmt(@name[0], SizeOf(name) - 1, '%s:', [object_name(dialog_target)]);
    win_print(win, @name[0], 180, 88, y, colorTable[992] or $2000000);
    entriesRect.uly := entriesRect.uly + v20;

    if dialogReviewEntry^.replyMessageListId <= -3 then
      replyText_ := dialogReviewEntry^.replyText
    else
      replyText_ := scr_get_msg_str(dialogReviewEntry^.replyMessageListId, dialogReviewEntry^.replyMessageId);

    if replyText_ = nil then
    begin
      GNWSystemError(PAnsiChar(#10'GDialog::Error Grabbing text message!'));
      Halt(1);
    end;

    y := text_to_rect_wrapped(windowBuffer + 113,
      @entriesRect,
      replyText_,
      nil,
      text_height(),
      640,
      colorTable[768] or $2000000);

    if dialogReviewEntry^.optionMessageListId <> -3 then
    begin
      StrLFmt(@name[0], SizeOf(name) - 1, '%s:', [object_name(obj_dude)]);
      win_print(win, @name[0], 180, 88, y, colorTable[21140] or $2000000);
      entriesRect.uly := entriesRect.uly + v20;

      if dialogReviewEntry^.optionMessageListId <= -3 then
        optionText_ := dialogReviewEntry^.optionText
      else
        optionText_ := scr_get_msg_str(dialogReviewEntry^.optionMessageListId, dialogReviewEntry^.optionMessageId);

      if optionText_ = nil then
      begin
        GNWSystemError(PAnsiChar(#10'GDialog::Error Grabbing text message!'));
        Halt(1);
      end;

      y := text_to_rect_wrapped(windowBuffer + 113,
        @entriesRect,
        optionText_,
        nil,
        text_height(),
        640,
        colorTable[15855] or $2000000);
    end;

    if y >= 407 then
      Break;

    Inc(index);
  end;

  entriesRect.ulx := 88;
  entriesRect.uly := 76;
  entriesRect.lry := entriesRect.lry + 14;
  entriesRect.lrx := 434;
  win_draw_rect(win, @entriesRect);
end;

function text_to_rect_wrapped(buffer: PByte; rect: PRect; str: PAnsiChar; a4: PInteger; height, pitch, color: Integer): Integer;
begin
  Result := text_to_rect_func(buffer, rect, str, a4, height, pitch, color, 1);
end;

function text_to_rect_func(buffer: PByte; rect: PRect; str: PAnsiChar; a4: PInteger; height, pitch, color, a7: Integer): Integer;
var
  start: PAnsiChar;
  maxWidth: Integer;
  endp: PAnsiChar;
  lookahead: PAnsiChar;
  dest: PByte;
begin
  if a4 <> nil then
    start := str + a4^
  else
    start := str;

  maxWidth := rect^.lrx - rect^.ulx;
  endp := nil;

  while (start <> nil) and (start^ <> #0) do
  begin
    if text_width(start) > maxWidth then
    begin
      endp := start + 1;
      while (endp^ <> #0) and (endp^ <> ' ') do
        Inc(endp);

      if endp^ <> #0 then
      begin
        lookahead := endp + 1;
        while lookahead <> nil do
        begin
          while (lookahead^ <> #0) and (lookahead^ <> ' ') do
            Inc(lookahead);

          if lookahead^ = #0 then
            lookahead := nil
          else
          begin
            lookahead^ := #0;
            if text_width(start) >= maxWidth then
            begin
              lookahead^ := ' ';
              lookahead := nil;
            end
            else
            begin
              endp := lookahead;
              lookahead^ := ' ';
              Inc(lookahead);
            end;
          end;
        end;

        if endp^ = ' ' then
          endp^ := #0;
      end
      else
      begin
        if rect^.lry - text_height() < rect^.uly then
        begin
          Result := rect^.uly;
          Exit;
        end;

        if (a7 <> 1) or (start = str) then
          text_to_buf(buffer + pitch * rect^.uly + 10, start, maxWidth, pitch, color)
        else
          text_to_buf(buffer + pitch * rect^.uly, start, maxWidth, pitch, color);

        if a4 <> nil then
          a4^ := a4^ + StrLen(start) + 1;

        rect^.uly := rect^.uly + height;
        Result := rect^.uly;
        Exit;
      end;
    end;

    if text_width(start) > maxWidth then
    begin
      debug_printf(PAnsiChar(#10'Error: display_msg: word too long!'));
      Break;
    end;

    if a7 <> 0 then
    begin
      if rect^.lry - text_height() < rect^.uly then
      begin
        if (endp <> nil) and (endp^ = #0) then
          endp^ := ' ';
        Result := rect^.uly;
        Exit;
      end;

      if (a7 <> 1) or (start = str) then
        dest := buffer + 10
      else
        dest := buffer;
      text_to_buf(dest + pitch * rect^.uly, start, maxWidth, pitch, color);
    end;

    if (a4 <> nil) and (endp <> nil) then
      a4^ := a4^ + StrLen(start) + 1;

    rect^.uly := rect^.uly + height;

    if endp <> nil then
    begin
      start := endp + 1;
      if endp^ = #0 then
        endp^ := ' ';
      endp := nil;
    end
    else
      start := nil;
  end;

  if a4 <> nil then
    a4^ := 0;

  Result := rect^.uly;
end;

procedure gdialogSetBarterMod(modifier: Integer);
begin
  gdBarterMod := modifier;
end;

function gdActivateBarter(modifier: Integer): Integer;
begin
  if dialog_state_fix = 0 then
  begin
    Result := -1;
    Exit;
  end;

  gdBarterMod := modifier;
  talk_to_pressed_barter(-1, -1);
  dialogue_state := 4;
  dialogue_switch_mode := 2;

  Result := 0;
end;

procedure barter_end_to_talk_to;
begin
  dialogQuit;
  dialogClose;
  updatePrograms;
  updateWindows;
  dialogue_state := 1;
  dialogue_switch_mode := 1;
end;

function talk_to_create_barter_win: Integer;
var
  fid: Integer;
  normal, pressed: PByte;
  backgroundFid: Integer;
  backgroundHandle: PCacheEntry;
  backgroundFrm: PArt;
  backgroundData: PByte;
  barterWindowX, barterWindowY: Integer;
  w: Integer;
  windowBuffer, backgroundWindowBuffer: PByte;
begin
  dialogue_state := 4;

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, 111, 0, 0, 0);
  backgroundFrm := art_ptr_lock(backgroundFid, @backgroundHandle);
  if backgroundFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  backgroundData := art_frame_data(backgroundFrm, 0, 0);
  if backgroundData = nil then
  begin
    art_ptr_unlock(backgroundHandle);
    Result := -1;
    Exit;
  end;

  dialogue_subwin_len := art_frame_length(backgroundFrm, 0, 0);

  barterWindowX := (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2;
  barterWindowY := (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2 + GAME_DIALOG_WINDOW_HEIGHT - dialogue_subwin_len;
  dialogueWindow := win_add(barterWindowX,
    barterWindowY,
    GAME_DIALOG_WINDOW_WIDTH,
    dialogue_subwin_len,
    256,
    WINDOW_DONT_MOVE_TOP);
  if dialogueWindow = -1 then
  begin
    art_ptr_unlock(backgroundHandle);
    Result := -1;
    Exit;
  end;

  w := GAME_DIALOG_WINDOW_WIDTH;

  windowBuffer := win_get_buf(dialogueWindow);
  backgroundWindowBuffer := win_get_buf(dialogueBackWindow);
  buf_to_buf(backgroundWindowBuffer + w * (480 - dialogue_subwin_len), w, dialogue_subwin_len, w, windowBuffer, w);

  talk_to_scroll_subwin(dialogueWindow, 1, backgroundData, windowBuffer, nil, dialogue_subwin_len, 0);

  art_ptr_unlock(backgroundHandle);

  fid := art_id(OBJ_TYPE_INTERFACE, 96, 0, 0, 0);
  normal := art_ptr_lock_data(fid, 0, 0, @dialogue_redbut_Key1);
  if normal = nil then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 95, 0, 0, 0);
  pressed := art_ptr_lock_data(fid, 0, 0, @dialogue_redbut_Key2);
  if pressed = nil then
  begin
    Result := -1;
    Exit;
  end;

  // TRADE
  dialogue_bids[0] := win_register_button(dialogueWindow,
    41, 163, 14, 14,
    -1, -1, -1, KEY_LOWERCASE_M,
    normal, pressed, nil, BUTTON_FLAG_TRANSPARENT);
  if dialogue_bids[0] <> -1 then
    win_register_button_sound_func(dialogue_bids[0], @gsound_med_butt_press, @gsound_med_butt_release);

  // TALK
  dialogue_bids[1] := win_register_button(dialogueWindow,
    584, 162, 14, 14,
    -1, -1, -1, KEY_LOWERCASE_T,
    normal, pressed, nil, BUTTON_FLAG_TRANSPARENT);
  if dialogue_bids[1] <> -1 then
    win_register_button_sound_func(dialogue_bids[1], @gsound_med_butt_press, @gsound_med_butt_release);

  if obj_new(@peon_table_obj, -1, -1) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  peon_table_obj^.Flags := peon_table_obj^.Flags or OBJECT_HIDDEN;

  if obj_new(@barterer_table_obj, -1, -1) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  barterer_table_obj^.Flags := barterer_table_obj^.Flags or OBJECT_HIDDEN;

  if obj_new(@barterer_temp_obj, dialog_target^.Fid, -1) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  barterer_temp_obj^.Flags := barterer_temp_obj^.Flags or OBJECT_HIDDEN or OBJECT_NO_SAVE;
  barterer_temp_obj^.Sid := -1;
  Result := 0;
end;

procedure talk_to_destroy_barter_win;
var
  index: Integer;
  backgroundWindowBuffer: PByte;
  backgroundFrmHandle: PCacheEntry;
  fid: Integer;
  backgroundFrmData: PByte;
  windowBuffer: PByte;
begin
  if dialogueWindow = -1 then
    Exit;

  obj_erase_object(barterer_temp_obj, nil);
  obj_erase_object(barterer_table_obj, nil);
  obj_erase_object(peon_table_obj, nil);

  index := 0;
  while index < 2 do
  begin
    win_delete_button(dialogue_bids[index]);
    Inc(index);
  end;

  art_ptr_unlock(dialogue_redbut_Key1);
  art_ptr_unlock(dialogue_redbut_Key2);

  backgroundWindowBuffer := win_get_buf(dialogueBackWindow);
  backgroundWindowBuffer := backgroundWindowBuffer + GAME_DIALOG_WINDOW_WIDTH * (480 - dialogue_subwin_len);

  fid := art_id(OBJ_TYPE_INTERFACE, 111, 0, 0, 0);
  backgroundFrmData := art_ptr_lock_data(fid, 0, 0, @backgroundFrmHandle);
  if backgroundFrmData <> nil then
  begin
    windowBuffer := win_get_buf(dialogueWindow);
    talk_to_scroll_subwin(dialogueWindow, 0, backgroundFrmData, windowBuffer, backgroundWindowBuffer, dialogue_subwin_len, 0);
    art_ptr_unlock(backgroundFrmHandle);
    win_delete(dialogueWindow);
    dialogueWindow := -1;
  end;
end;

procedure dialogue_barter_cleanup_tables;
var
  inventory: PInventory;
  len: Integer;
  index: Integer;
  item: PObject;
  quantity: Integer;
begin
  inventory := @peon_table_obj^.Data.AsData.Inventory;
  len := inventory^.Length;
  index := 0;
  while index < len do
  begin
    item := inventory^.Items^.Item;
    quantity := item_count(peon_table_obj, item);
    item_move_force(peon_table_obj, obj_dude, item, quantity);
    Inc(index);
  end;

  inventory := @barterer_table_obj^.Data.AsData.Inventory;
  len := inventory^.Length;
  index := 0;
  while index < len do
  begin
    item := inventory^.Items^.Item;
    quantity := item_count(barterer_table_obj, item);
    item_move_force(barterer_table_obj, dialog_target, item, quantity);
    Inc(index);
  end;

  if barterer_temp_obj <> nil then
  begin
    inventory := @barterer_temp_obj^.Data.AsData.Inventory;
    len := inventory^.Length;
    index := 0;
    while index < len do
    begin
      item := inventory^.Items^.Item;
      quantity := item_count(barterer_temp_obj, item);
      item_move_force(barterer_temp_obj, dialog_target, item, quantity);
      Inc(index);
    end;
  end;
end;

procedure talk_to_pressed_barter(btn, keyCode: Integer); cdecl;
var
  script: PScript;
  proto: PProto;
  messageListItem: TMessageListItem;
begin
  if PID_TYPE(dialog_target^.Pid) <> OBJ_TYPE_CRITTER then
    Exit;

  if scr_ptr(dialog_target^.Sid, @script) = -1 then
    Exit;

  proto_ptr(dialog_target^.Pid, @proto);
  if (proto^.Critter.Data.Flags and CRITTER_BARTER) <> 0 then
  begin
    if gdialog_speech_playing then
    begin
      if soundPlaying(lip_info.sound) then
        gdialog_free_speech;
    end;

    dialogue_switch_mode := 2;
    dialogue_state := 4;

    gdialog_hide;
  end
  else
  begin
    messageListItem.num := 903;
    if message_search(@proto_main_msg_file, @messageListItem) then
      gdialog_display_msg(messageListItem.text)
    else
      debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
  end;
end;

procedure talk_to_pressed_about(btn, keyCode: Integer); cdecl;
var
  mesg: TMessageListItem;
  react: Integer;
  reaction_level_: Integer;
begin
  if PID_TYPE(dialog_target^.Pid) = OBJ_TYPE_CRITTER then
  begin
    react := reaction_get(dialog_target);
    reaction_level_ := reaction_to_level(react);
    if reaction_level_ <> 0 then
    begin
      if map_data.field_34 <> 35 then
      begin
        if gdialog_speech_playing then
        begin
          if soundPlay(lip_info.sound) <> 0 then
            gdialog_free_speech;
        end;

        dialogue_switch_mode := 5;
        gdialog_hide;
      end
      else
      begin
        mesg.num := 904;
        if not message_search(@proto_main_msg_file, @mesg) then
          debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
        gdialog_display_msg(mesg.text);
      end;
    end
    else
    begin
      mesg.num := 904;
      if not message_search(@proto_main_msg_file, @mesg) then
        debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
    end;
  end
  else
  begin
    mesg.num := 904;
    if not message_search(@proto_main_msg_file, @mesg) then
      debug_printf(PAnsiChar(#10'Error: gdialog: Can''t find message!'));
  end;
end;

procedure talk_to_pressed_review(btn, keyCode: Integer); cdecl;
begin
  gdialog_review;
end;

function talk_to_create_dialogue_win: Integer;
var
  fid: Integer;
  normal, pressed: PByte;
  screenWidth: Integer;
  backgroundFrmHandle: PCacheEntry;
  backgroundFid: Integer;
  backgroundFrm: PArt;
  backgroundFrmData: PByte;
  dialogSubwindowX, dialogSubwindowY: Integer;
  v10, v14: PByte;
begin
  screenWidth := GAME_DIALOG_WINDOW_WIDTH;

  if dial_win_created then
  begin
    Result := -1;
    Exit;
  end;

  dial_win_created := True;

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, 99, 0, 0, 0);
  backgroundFrm := art_ptr_lock(backgroundFid, @backgroundFrmHandle);
  if backgroundFrm = nil then
  begin
    Result := -1;
    Exit;
  end;

  backgroundFrmData := art_frame_data(backgroundFrm, 0, 0);
  if backgroundFrmData = nil then
  begin
    Result := -1;
    Exit;
  end;

  dialogue_subwin_len := art_frame_length(backgroundFrm, 0, 0);

  dialogSubwindowX := (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2;
  dialogSubwindowY := (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2 + GAME_DIALOG_WINDOW_HEIGHT - dialogue_subwin_len;
  dialogueWindow := win_add(dialogSubwindowX,
    dialogSubwindowY,
    screenWidth,
    dialogue_subwin_len,
    256,
    WINDOW_DONT_MOVE_TOP);
  if dialogueWindow = -1 then
  begin
    Result := -1;
    Exit;
  end;

  v10 := win_get_buf(dialogueWindow);
  v14 := win_get_buf(dialogueBackWindow);
  buf_to_buf(v14 + screenWidth * (GAME_DIALOG_WINDOW_HEIGHT - dialogue_subwin_len),
    screenWidth, dialogue_subwin_len, screenWidth,
    v10, screenWidth);

  if dialogue_just_started <> 0 then
  begin
    win_draw(dialogueBackWindow);
    talk_to_scroll_subwin(dialogueWindow, 1, backgroundFrmData, v10, nil, dialogue_subwin_len, -1);
    dialogue_just_started := 0;
  end
  else
    talk_to_scroll_subwin(dialogueWindow, 1, backgroundFrmData, v10, nil, dialogue_subwin_len, 0);

  art_ptr_unlock(backgroundFrmHandle);

  fid := art_id(OBJ_TYPE_INTERFACE, 96, 0, 0, 0);
  normal := art_ptr_lock_data(fid, 0, 0, @dialogue_redbut_Key1);
  if normal = nil then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 95, 0, 0, 0);
  pressed := art_ptr_lock_data(fid, 0, 0, @dialogue_redbut_Key2);
  if pressed = nil then
  begin
    Result := -1;
    Exit;
  end;

  // BARTER/TRADE
  dialogue_bids[0] := win_register_button(dialogueWindow,
    593, 41, 14, 14,
    -1, -1, -1, -1,
    normal, pressed, nil, BUTTON_FLAG_TRANSPARENT);
  if dialogue_bids[0] <> -1 then
  begin
    win_register_button_func(dialogue_bids[0], nil, nil, nil, @talk_to_pressed_barter);
    win_register_button_sound_func(dialogue_bids[0], @gsound_med_butt_press, @gsound_med_butt_release);
  end;

  // ASK ABOUT
  dialogue_bids[1] := win_register_button(dialogueWindow,
    593, 116, 14, 14,
    -1, -1, -1, -1,
    normal, pressed, nil, BUTTON_FLAG_TRANSPARENT);
  if dialogue_bids[1] <> -1 then
  begin
    win_register_button_func(dialogue_bids[1], nil, nil, nil, @talk_to_pressed_about);
    win_register_button_sound_func(dialogue_bids[1], @gsound_med_butt_press, @gsound_med_butt_release);
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 97, 0, 0, 0);
  normal := art_ptr_lock_data(fid, 0, 0, @dialogue_rest_Key1);
  if normal = nil then
  begin
    Result := -1;
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 98, 0, 0, 0);
  pressed := art_ptr_lock_data(fid, 0, 0, @dialogue_rest_Key2);

  // REVIEW
  dialogue_bids[2] := win_register_button(dialogueWindow,
    13, 154, 51, 29,
    -1, -1, -1, -1,
    normal, pressed, nil, 0);
  if dialogue_bids[2] <> -1 then
  begin
    win_register_button_func(dialogue_bids[2], nil, nil, nil, @talk_to_pressed_review);
    win_register_button_sound_func(dialogue_bids[2], @gsound_red_butt_press, @gsound_red_butt_release);
  end;

  Result := 0;
end;

procedure talk_to_destroy_dialogue_win;
var
  index: Integer;
  offset: Integer;
  backgroundWindowBuffer: PByte;
  backgroundFrmHandle: PCacheEntry;
  fid: Integer;
  backgroundFrmData: PByte;
  windowBuffer: PByte;
begin
  if dialogueWindow = -1 then
    Exit;

  index := 0;
  while index < 3 do
  begin
    win_delete_button(dialogue_bids[index]);
    Inc(index);
  end;

  art_ptr_unlock(dialogue_redbut_Key1);
  art_ptr_unlock(dialogue_redbut_Key2);
  art_ptr_unlock(dialogue_rest_Key1);
  art_ptr_unlock(dialogue_rest_Key2);

  offset := GAME_DIALOG_WINDOW_WIDTH * (480 - dialogue_subwin_len);
  backgroundWindowBuffer := win_get_buf(dialogueBackWindow) + offset;

  fid := art_id(OBJ_TYPE_INTERFACE, 99, 0, 0, 0);
  backgroundFrmData := art_ptr_lock_data(fid, 0, 0, @backgroundFrmHandle);
  if backgroundFrmData <> nil then
  begin
    windowBuffer := win_get_buf(dialogueWindow);
    talk_to_scroll_subwin(dialogueWindow, 0, backgroundFrmData, windowBuffer, backgroundWindowBuffer, dialogue_subwin_len, 0);
    art_ptr_unlock(backgroundFrmHandle);
    win_delete(dialogueWindow);
    dial_win_created := False;
    dialogueWindow := -1;
  end;
end;

function talk_to_create_background_window: Integer;
var
  backgroundWindowX, backgroundWindowY: Integer;
begin
  backgroundWindowX := (screenGetWidth - GAME_DIALOG_WINDOW_WIDTH) div 2;
  backgroundWindowY := (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2;
  dialogueBackWindow := win_add(backgroundWindowX,
    backgroundWindowY,
    GAME_DIALOG_WINDOW_WIDTH,
    GAME_DIALOG_WINDOW_HEIGHT,
    256,
    WINDOW_DONT_MOVE_TOP);

  if dialogueBackWindow <> -1 then
    Result := 0
  else
    Result := -1;
end;

function talk_to_refresh_background_window: Integer;
var
  backgroundFrmHandle: PCacheEntry;
  fid: Integer;
  backgroundFrmData: PByte;
  windowWidth: Integer;
  windowBuffer: PByte;
begin
  fid := art_id(OBJ_TYPE_INTERFACE, 103, 0, 0, 0);
  backgroundFrmData := art_ptr_lock_data(fid, 0, 0, @backgroundFrmHandle);
  if backgroundFrmData = nil then
  begin
    Result := -1;
    Exit;
  end;

  windowWidth := GAME_DIALOG_WINDOW_WIDTH;
  windowBuffer := win_get_buf(dialogueBackWindow);
  buf_to_buf(backgroundFrmData, windowWidth, 480, windowWidth, windowBuffer, windowWidth);
  art_ptr_unlock(backgroundFrmHandle);

  if dialogue_just_started = 0 then
    win_draw(dialogueBackWindow);

  Result := 0;
end;

function talk_to_create_head_window: Integer;
var
  windowWidth: Integer;
  buf: PByte;
  index: Integer;
  rect: PRect;
  w, h: Integer;
  src: PByte;
begin
  dialogue_state := 1;

  windowWidth := GAME_DIALOG_WINDOW_WIDTH;

  talk_to_create_background_window;
  talk_to_refresh_background_window;

  buf := win_get_buf(dialogueBackWindow);

  index := 0;
  while index < 8 do
  begin
    soundUpdate;

    rect := @backgrndRects[index];
    w := rect^.lrx - rect^.ulx;
    h := rect^.lry - rect^.uly;
    backgrndBufs[index] := PByte(mem_malloc(w * h));
    if backgrndBufs[index] = nil then
    begin
      Result := -1;
      Exit;
    end;

    src := buf;
    src := src + windowWidth * rect^.uly + rect^.ulx;

    buf_to_buf(src, w, h, windowWidth, backgrndBufs[index], w);

    Inc(index);
  end;

  talk_to_create_dialogue_win;

  headWindowBuffer := win_get_buf(dialogueBackWindow) + windowWidth * 14 + 126;

  if headWindowBuffer = nil then
  begin
    talk_to_destroy_head_window;
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

procedure talk_to_destroy_head_window;
var
  index: Integer;
begin
  if dialogueWindow <> -1 then
    headWindowBuffer := nil;

  if dialogue_state = 1 then
    talk_to_destroy_dialogue_win
  else if dialogue_state = 4 then
    talk_to_destroy_barter_win;

  if dialogueBackWindow <> -1 then
  begin
    win_delete(dialogueBackWindow);
    dialogueBackWindow := -1;
  end;

  index := 0;
  while index < 8 do
  begin
    mem_free(backgrndBufs[index]);
    Inc(index);
  end;
end;

procedure talk_to_set_up_fidget(headFrmId, reaction: Integer);
var
  anim: Integer;
  fid: Integer;
  fidgetCount: Integer;
  chance: Integer;
  fidget: Integer;
  stats: array[0..199] of AnsiChar;
begin
  fidgetFrameCounter := 0;

  if headFrmId = -1 then
  begin
    fidgetFID := -1;
    fidgetFp := nil;
    fidgetKey := PCacheEntry(1); // INVALID_CACHE_ENTRY
    fidgetAnim := -1;
    fidgetTocksPerFrame := 0;
    fidgetLastTime := 0;
    talk_to_display_frame(nil, 0);
    lipsFID := 0;
    lipsKey := nil;
    lipsFp := nil;
    Exit;
  end;

  anim := HEAD_ANIMATION_NEUTRAL_PHONEMES;
  case reaction of
    FIDGET_GOOD: anim := HEAD_ANIMATION_GOOD_PHONEMES;
    FIDGET_BAD:  anim := HEAD_ANIMATION_BAD_PHONEMES;
  end;

  if lipsFID <> 0 then
  begin
    if anim <> phone_anim then
    begin
      if art_ptr_unlock(lipsKey) = -1 then
        debug_printf(PAnsiChar('failure unlocking lips frame!'#10));
      lipsKey := nil;
      lipsFp := nil;
      lipsFID := 0;
    end;
  end;

  if lipsFID = 0 then
  begin
    phone_anim := anim;
    lipsFID := art_id(OBJ_TYPE_HEAD, headFrmId, anim, 0, 0);
    lipsFp := art_ptr_lock(lipsFID, @lipsKey);
    if lipsFp = nil then
    begin
      debug_printf(PAnsiChar('failure!'#10));
      cache_stats(@art_cache, @stats[0], SizeOf(stats));
      debug_printf(@stats[0]);
    end;
  end;

  fid := art_id(OBJ_TYPE_HEAD, headFrmId, reaction, 0, 0);
  fidgetCount := art_head_fidgets(fid);
  if fidgetCount = -1 then
  begin
    debug_printf(PAnsiChar(#9'Error - No available fidgets for given frame id'#10));
    Exit;
  end;

  chance := roll_random(1, 100) + dialogue_seconds_since_last_input div 2;

  fidget := fidgetCount;
  case fidgetCount of
    1: fidget := 1;
    2:
    begin
      if chance < 68 then
        fidget := 1
      else
        fidget := 2;
    end;
    3:
    begin
      dialogue_seconds_since_last_input := 0;
      if chance < 52 then
        fidget := 1
      else if chance < 77 then
        fidget := 2
      else
        fidget := 3;
    end;
  end;

  debug_printf(PAnsiChar('Choosing fidget'#10));

  if fidgetFp <> nil then
  begin
    if art_ptr_unlock(fidgetKey) = -1 then
      debug_printf(PAnsiChar('failure!'#10));
  end;

  fidgetFID := art_id(OBJ_TYPE_HEAD, headFrmId, reaction, fidget, 0);
  fidgetFrameCounter := 0;
  fidgetFp := art_ptr_lock(fidgetFID, @fidgetKey);
  if fidgetFp = nil then
  begin
    debug_printf(PAnsiChar('failure!'#10));
    cache_stats(@art_cache, @stats[0], SizeOf(stats));
    debug_printf(@stats[0]);
  end;

  fidgetLastTime := 0;
  fidgetAnim := reaction;
  fidgetTocksPerFrame := 1000 div LongWord(art_frame_fps(fidgetFp));
end;

procedure talk_to_wait_for_fidget;
begin
  if fidgetFp = nil then
    Exit;

  if dialogueWindow = -1 then
    Exit;

  debug_printf(PAnsiChar('Waiting for fidget to complete...'#10));

  while art_frame_max_frame(fidgetFp) > fidgetFrameCounter do
  begin
    sharedFpsLimiter.Mark;

    if elapsed_time(fidgetLastTime) >= fidgetTocksPerFrame then
    begin
      talk_to_display_frame(fidgetFp, fidgetFrameCounter);
      fidgetLastTime := get_time;
      Inc(fidgetFrameCounter);
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  fidgetFrameCounter := 0;
end;

procedure talk_to_play_transition(anim: Integer);
var
  headFrmHandle: PCacheEntry;
  headFid: Integer;
  headFrm: PArt;
  delay: LongWord;
  frame: Integer;
  time_: LongWord;
begin
  if fidgetFp = nil then
    Exit;

  if dialogueWindow = -1 then
    Exit;

  mouse_hide;

  debug_printf(PAnsiChar('Starting transition...'#10));

  talk_to_wait_for_fidget;

  if fidgetFp <> nil then
  begin
    if art_ptr_unlock(fidgetKey) = -1 then
      debug_printf(PAnsiChar(#9'Error unlocking fidget in transition func...'));
    fidgetFp := nil;
  end;

  headFid := art_id(OBJ_TYPE_HEAD, dialogue_head, anim, 0, 0);
  headFrm := art_ptr_lock(headFid, @headFrmHandle);
  if headFrm = nil then
    debug_printf(PAnsiChar(#9'Error locking transition...'#10));

  delay := 1000 div LongWord(art_frame_fps(headFrm));

  frame := 0;
  time_ := 0;
  while frame < art_frame_max_frame(headFrm) do
  begin
    sharedFpsLimiter.Mark;

    if elapsed_time(time_) >= delay then
    begin
      talk_to_display_frame(headFrm, frame);
      time_ := get_time;
      Inc(frame);
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if art_ptr_unlock(headFrmHandle) = -1 then
    debug_printf(PAnsiChar(#9'Error unlocking transition...'#10));

  debug_printf(PAnsiChar('Finished transition...'#10));
  mouse_show;
end;

procedure talk_to_translucent_trans_buf_to_buf(src: PByte; srcWidth, srcHeight, srcPitch: Integer; dest: PByte; destX, destY, destPitch: Integer; a9, a10: PByte);
var
  srcStep, destStep: Integer;
  y, x: Integer;
  v1, v15: Byte;
begin
  srcStep := srcPitch - srcWidth;
  destStep := destPitch - srcWidth;

  dest := dest + destPitch * destY + destX;

  y := 0;
  while y < srcHeight do
  begin
    x := 0;
    while x < srcWidth do
    begin
      v1 := src^;
      Inc(src);
      if v1 <> 0 then
        v1 := (256 - v1) shr 4;

      v15 := dest^;
      dest^ := a9[256 * v1 + v15];
      Inc(dest);
      Inc(x);
    end;
    src := src + srcStep;
    dest := dest + destStep;
    Inc(y);
  end;
end;

procedure talk_to_display_frame(headFrm: PArt; frame: Integer);
var
  backgroundFid: Integer;
  backgroundHandle: PCacheEntry;
  backgroundFrm: PArt;
  backgroundFrmData: PByte;
  w, h: Integer;
  data: PByte;
  a3, v8: Integer;
  a4, a5: Integer;
  destWidth: Integer;
  destOffset: Integer;
  src: PByte;
  v27: TRect;
  dest: PByte;
  data1, data2: PByte;
  index: Integer;
  rect: PRect;
  rw: Integer;
begin
  if dialogueWindow = -1 then
    Exit;

  if headFrm <> nil then
  begin
    if frame = 0 then
      totalHotx := 0;

    backgroundFid := art_id(OBJ_TYPE_BACKGROUND, backgroundIndex, 0, 0, 0);

    backgroundFrm := art_ptr_lock(backgroundFid, @backgroundHandle);
    if backgroundFrm = nil then
      debug_printf(PAnsiChar(#9'Error locking background in display...'#10));

    backgroundFrmData := art_frame_data(backgroundFrm, 0, 0);
    if backgroundFrmData <> nil then
      buf_to_buf(backgroundFrmData, 388, 200, 388, headWindowBuffer, GAME_DIALOG_WINDOW_WIDTH)
    else
      debug_printf(PAnsiChar(#9'Error getting background data in display...'#10));

    art_ptr_unlock(backgroundHandle);

    w := art_frame_width(headFrm, frame, 0);
    h := art_frame_length(headFrm, frame, 0);
    data := art_frame_data(headFrm, frame, 0);

    art_frame_offset(headFrm, 0, @a3, @v8);
    art_frame_hot(headFrm, frame, 0, @a4, @a5);

    totalHotx := totalHotx + a4;
    a3 := a3 + totalHotx;

    if data <> nil then
    begin
      destWidth := GAME_DIALOG_WINDOW_WIDTH;
      destOffset := destWidth * (200 - h) + a3 + (388 - w) div 2;
      if destOffset + w * v8 > 0 then
        destOffset := destOffset + w * v8;

      trans_buf_to_buf(
        data, w, h, w,
        headWindowBuffer + destOffset,
        destWidth);
    end
    else
      debug_printf(PAnsiChar(#9'Error getting head data in display...'#10));
  end
  else
  begin
    if talk_need_to_center = 1 then
    begin
      talk_need_to_center := 0;
      tile_refresh_display;
    end;

    src := win_get_buf(display_win);
    buf_to_buf(
      src + ((win_height(display_win) - 232) div 2) * win_width(display_win) + (win_width(display_win) - 388) div 2,
      388, 200,
      win_width(display_win),
      headWindowBuffer,
      GAME_DIALOG_WINDOW_WIDTH);
  end;

  v27.ulx := 126;
  v27.uly := 14;
  v27.lrx := 514;
  v27.lry := 214;

  dest := win_get_buf(dialogueBackWindow);

  data1 := art_frame_data(upper_hi_fp, 0, 0);
  talk_to_translucent_trans_buf_to_buf(data1, upper_hi_wid, upper_hi_len, upper_hi_wid, dest, 426, 15, GAME_DIALOG_WINDOW_WIDTH, light_BlendTable, @light_GrayTable[0]);

  data2 := art_frame_data(lower_hi_fp, 0, 0);
  talk_to_translucent_trans_buf_to_buf(data2, lower_hi_wid, lower_hi_len, lower_hi_wid, dest, 129, 214 - lower_hi_len - 2, GAME_DIALOG_WINDOW_WIDTH, dark_BlendTable, @dark_GrayTable[0]);

  index := 0;
  while index < 8 do
  begin
    rect := @backgrndRects[index];
    rw := rect^.lrx - rect^.ulx;

    trans_buf_to_buf(backgrndBufs[index],
      rw,
      rect^.lry - rect^.uly,
      rw,
      dest + GAME_DIALOG_WINDOW_WIDTH * rect^.uly + rect^.ulx,
      GAME_DIALOG_WINDOW_WIDTH);

    Inc(index);
  end;

  win_draw_rect(dialogueBackWindow, @v27);
end;

procedure talk_to_blend_table_init;
var
  clr: Integer;
  r, g, b: Integer;
  upperHighlightFid, lowerHighlightFid: Integer;
begin
  clr := 0;
  while clr < 256 do
  begin
    r := (Color2RGB(clr) and $7C00) shr 10;
    g := (Color2RGB(clr) and $3E0) shr 5;
    b := Color2RGB(clr) and $1F;
    light_GrayTable[clr] := ((r + 2 * g + 2 * b) div 10) shr 2;
    dark_GrayTable[clr] := ((r + g + b) div 10) shr 2;
    Inc(clr);
  end;

  light_GrayTable[0] := 0;
  dark_GrayTable[0] := 0;

  light_BlendTable := getColorBlendTable(colorTable[17969]);
  dark_BlendTable := getColorBlendTable(colorTable[22187]);

  upperHighlightFid := art_id(OBJ_TYPE_INTERFACE, 115, 0, 0, 0);
  upper_hi_fp := art_ptr_lock(upperHighlightFid, @upper_hi_key);
  upper_hi_wid := art_frame_width(upper_hi_fp, 0, 0);
  upper_hi_len := art_frame_length(upper_hi_fp, 0, 0);

  lowerHighlightFid := art_id(OBJ_TYPE_INTERFACE, 116, 0, 0, 0);
  lower_hi_fp := art_ptr_lock(lowerHighlightFid, @lower_hi_key);
  lower_hi_wid := art_frame_width(lower_hi_fp, 0, 0);
  lower_hi_len := art_frame_length(lower_hi_fp, 0, 0);
end;

procedure talk_to_blend_table_exit;
begin
  freeColorBlendTable(colorTable[17969]);
  freeColorBlendTable(colorTable[22187]);

  art_ptr_unlock(upper_hi_key);
  art_ptr_unlock(lower_hi_key);
end;

function about_init: Integer;
var
  fid: Integer;
  background_key: PCacheEntry;
  background_frm: PArt;
  background_data: PByte;
  background_width, background_height: Integer;
  msg_file: TMessageList;
  mesg: TMessageListItem;
  w: Integer;
  button_up_frm: PArt;
  button_up_data: PByte;
  button_down_frm: PArt;
  button_down_data: PByte;
  button_width, button_height: Integer;
  btn: Integer;
begin
  if about_win = -1 then
  begin
    about_old_font := text_curr;

    fid := art_id(OBJ_TYPE_INTERFACE, 238, 0, 0, 0);
    background_frm := art_ptr_lock(fid, @background_key);
    if background_frm <> nil then
    begin
      background_data := art_frame_data(background_frm, 0, 0);
      if background_data <> nil then
      begin
        background_width := art_frame_width(background_frm, 0, 0);
        background_height := art_frame_length(background_frm, 0, 0);
        about_win_width := background_width;
        about_win := win_add((screenGetWidth - background_width) div 2,
          (screenGetHeight - GAME_DIALOG_WINDOW_HEIGHT) div 2 + 356,
          background_width,
          background_height,
          colorTable[0],
          WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
        if about_win <> -1 then
        begin
          about_win_buf := win_get_buf(about_win);
          if about_win_buf <> nil then
          begin
            buf_to_buf(background_data,
              background_width, background_height,
              background_width,
              about_win_buf,
              background_width);

            text_font(103);

            if message_init(@msg_file) and message_load(@msg_file, PAnsiChar('game\misc.msg')) then
            begin
              mesg.num := 6000;
              if message_search(@msg_file, @mesg) then
              begin
                w := text_width(mesg.text);
                text_to_buf(about_win_buf + background_width * 7 + (background_width - w) div 2,
                  mesg.text,
                  background_width - (background_width - w) div 2,
                  background_width,
                  colorTable[18979]);
                message_exit(@msg_file);

                text_font(103);

                if message_init(@msg_file) and message_load(@msg_file, PAnsiChar('game\dbox.msg')) then
                begin
                  mesg.num := 100;
                  if message_search(@msg_file, @mesg) then
                  begin
                    text_to_buf(about_win_buf + background_width * 57 + 56,
                      mesg.text,
                      background_width - 56,
                      background_width,
                      colorTable[18979]);

                    mesg.num := 103;
                    if message_search(@msg_file, @mesg) then
                    begin
                      text_to_buf(about_win_buf + background_width * 57 + 181,
                        mesg.text,
                        background_width - 181,
                        background_width,
                        colorTable[18979]);
                      message_exit(@msg_file);

                      fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
                      button_up_frm := art_ptr_lock(fid, @about_button_up_key);
                      if button_up_frm <> nil then
                      begin
                        button_up_data := art_frame_data(button_up_frm, 0, 0);
                        if button_up_data <> nil then
                        begin
                          fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
                          button_down_frm := art_ptr_lock(fid, @about_button_down_key);
                          if button_down_frm <> nil then
                          begin
                            button_down_data := art_frame_data(button_down_frm, 0, 0);
                            if button_down_data <> nil then
                            begin
                              button_width := art_frame_width(button_down_frm, 0, 0);
                              button_height := art_frame_length(button_down_frm, 0, 0);

                              btn := win_register_button(about_win,
                                34, 58,
                                button_width, button_height,
                                -1, -1, -1, KEY_RETURN,
                                button_up_data, button_down_data,
                                nil, BUTTON_FLAG_TRANSPARENT);
                              if btn <> -1 then
                              begin
                                win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

                                btn := win_register_button(about_win,
                                  160, 58,
                                  button_width, button_height,
                                  -1, -1, -1, KEY_ESCAPE,
                                  button_up_data, button_down_data,
                                  nil, BUTTON_FLAG_TRANSPARENT);
                                if btn <> -1 then
                                begin
                                  win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

                                  about_input_string := PAnsiChar(mem_malloc(128));
                                  if about_input_string <> nil then
                                  begin
                                    StrCopy(@about_restore_string[0], @dialogBlock.replyText[0]);
                                    about_reset_string;
                                    about_last_time := get_time;
                                    about_update_display(0);

                                    art_ptr_unlock(background_key);

                                    win_draw(about_win);
                                    Result := 0;
                                    Exit;
                                  end;
                                end;
                              end;
                            end;
                            art_ptr_unlock(about_button_down_key);
                          end;
                        end;
                        art_ptr_unlock(about_button_up_key);
                      end;
                    end;
                  end;
                end;
              end;
              message_exit(@msg_file);
            end;
          end;
          win_delete(about_win);
          about_win := -1;
        end;
      end;

      art_ptr_unlock(background_key);
    end;
  end;

  text_font(about_old_font);
  GNWSystemError(PAnsiChar('Unable to create dialog box.'));
  Result := -1;
end;

procedure about_exit;
begin
  if about_win <> -1 then
  begin
    if about_input_string <> nil then
    begin
      mem_free(about_input_string);
      about_input_string := nil;
    end;

    if about_button_up_key <> nil then
    begin
      art_ptr_unlock(about_button_up_key);
      about_button_up_key := nil;
    end;

    if about_button_down_key <> nil then
    begin
      art_ptr_unlock(about_button_down_key);
      about_button_down_key := nil;
    end;

    win_delete(about_win);
    about_win := -1;

    text_font(about_old_font);
  end;
end;

procedure about_loop;
begin
  if about_init <> 0 then
    Exit;

  beginTextInput;

  while True do
  begin
    sharedFpsLimiter.Mark;

    if about_process_input(get_input) = -1 then
      Break;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  endTextInput;

  about_exit;
  StrCopy(@dialogBlock.replyText[0], @about_restore_string[0]);
  dialogue_switch_mode := 0;
  talk_to_create_dialogue_win;
  gdialog_unhide;
  gDialogProcessReply;
end;

function about_process_input(input: Integer): Integer;
begin
  if about_win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  case input of
    KEY_BACKSPACE:
    begin
      if about_input_index > 0 then
      begin
        Dec(about_input_index);
        about_input_string[about_input_index] := about_input_cursor;
        about_input_string[about_input_index + 1] := #0;
        about_update_display(1);
      end;
    end;
    KEY_RETURN:
      about_process_string;
    KEY_ESCAPE:
    begin
      if gdialog_speech_playing then
      begin
        if soundPlaying(lip_info.sound) then
          gdialog_free_speech;
      end;
      Result := -1;
      Exit;
    end;
  else
    begin
      if (input >= 0) and (about_input_index < 126) then
      begin
        text_font(101);
        about_input_string[about_input_index] := '_';

        if text_width(about_input_string) + text_char_width(AnsiChar(input)) < 244 then
        begin
          about_input_string[about_input_index] := AnsiChar(input);
          about_input_string[about_input_index + 1] := about_input_cursor;
          about_input_string[about_input_index + 2] := #0;
          Inc(about_input_index);
          about_update_display(1);
        end;

        about_input_string[about_input_index] := about_input_cursor;
      end;
    end;
  end;

  if elapsed_time(about_last_time) > 333 then
  begin
    if about_input_cursor = '_' then
      about_input_cursor := ' '
    else
      about_input_cursor := '_';
    about_input_string[about_input_index] := about_input_cursor;
    about_update_display(1);
    about_last_time := get_time;
  end;

  Result := 0;
end;

procedure about_update_display(should_redraw: Byte);
var
  old_font_: Integer;
  w: Integer;
  skip: Integer;
begin
  skip := 0;

  old_font_ := text_curr;
  about_clear_display(0);
  text_font(101);

  w := text_width(about_input_string) - 244;
  while w > 0 do
  begin
    w := w - text_char_width(about_input_string[skip]);
    Inc(skip);
  end;

  text_to_buf(about_win_buf + about_win_width * 32 + 22,
    about_input_string + skip,
    244,
    about_win_width,
    colorTable[992]);

  if should_redraw <> 0 then
    win_draw_rect(about_win, @about_input_rect);

  text_font(old_font_);
end;

procedure about_clear_display(should_redraw: Byte);
begin
  win_fill(about_win, 22, 32, 244, 14, colorTable[0]);

  if should_redraw <> 0 then
    win_draw_rect(about_win, @about_input_rect);
end;

procedure about_reset_string;
begin
  about_input_index := 0;
  about_input_string[0] := about_input_cursor;
  about_input_string[1] := #0;
end;

procedure about_process_string;
const
  delimiters: PAnsiChar = ' '#9'.,';
var
  found: Integer;
  tok: PAnsiChar;
  scr: PScript;
  count: Integer;
  msg_id: Integer;
  str_: PAnsiChar;
  random_msg_num: Integer;
begin
  about_input_string[about_input_index] := #0;

  if about_input_string[0] <> #0 then
  begin
    found := 0;
    tok := libc_strtok(about_input_string, delimiters);
    while tok <> nil do
    begin
      if (about_lookup_word(tok) <> 0) or (about_lookup_name(tok) <> 0) then
      begin
        found := 1;
        Break;
      end;
      tok := libc_strtok(nil, delimiters);
    end;

    if found = 0 then
    begin
      if scr_ptr(dialog_target^.Sid, @scr) <> -1 then
      begin
        count := 0;
        msg_id := 980;
        while msg_id < 1000 do
        begin
          str_ := scr_get_msg_str(scr^.scr_script_idx + 1, msg_id);
          if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
            Inc(count);
          Inc(msg_id);
        end;

        if count <> 0 then
        begin
          random_msg_num := roll_random(1, count);
          msg_id := 980;
          while msg_id < 1000 do
          begin
            str_ := scr_get_msg_str(scr^.scr_script_idx + 1, msg_id);
            if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
            begin
              Dec(random_msg_num);
              if random_msg_num = 0 then
              begin
                StrLCopy(@dialogBlock.replyText[0], scr_get_msg_str_speech(scr^.scr_script_idx + 1, msg_id, 1), SizeOf(dialogBlock.replyText) - 1);
                dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
                gdialog_unhide_reply;
                gDialogProcessReply;
              end;
            end;
            Inc(msg_id);
          end;
        end
        else
        begin
          msg_id := 980;
          while msg_id < 1000 do
          begin
            str_ := scr_get_msg_str(1, msg_id);
            if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
              Inc(count);
            Inc(msg_id);
          end;

          if count <> 0 then
          begin
            random_msg_num := roll_random(1, count);
            msg_id := 980;
            while msg_id < 1000 do
            begin
              str_ := scr_get_msg_str(1, msg_id);
              if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
              begin
                Dec(random_msg_num);
                if random_msg_num = 0 then
                begin
                  StrLCopy(@dialogBlock.replyText[0], scr_get_msg_str_speech(1, msg_id, 1), SizeOf(dialogBlock.replyText) - 1);
                  dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
                  gdialog_unhide_reply;
                  gDialogProcessReply;
                end;
              end;
              Inc(msg_id);
            end;
          end;
        end;
      end;
    end;
  end;

  about_reset_string;
  about_update_display(1);
end;

function about_lookup_word(const search: PAnsiChar): Integer;
var
  scr: PScript;
  found: Integer;
  message_list_id: Integer;
  msg_id: Integer;
  str_: PAnsiChar;
begin
  found := -1;

  if scr_ptr(dialog_target^.Sid, @scr) <> -1 then
  begin
    message_list_id := scr^.scr_script_idx + 1;
    msg_id := 1000;
    while msg_id < 1100 do
    begin
      str_ := scr_get_msg_str(message_list_id, msg_id);
      if (str_ <> nil) and (compat_stricmp(str_, search) = 0) then
      begin
        found := msg_id + 100;
        Break;
      end;
      Inc(msg_id);
    end;
  end;

  if found = -1 then
  begin
    message_list_id := 1;
    msg_id := 600 * map_data.field_34 + 1000;
    while msg_id < 600 * map_data.field_34 + 1100 do
    begin
      str_ := scr_get_msg_str(message_list_id, msg_id);
      if (str_ <> nil) and (compat_stricmp(str_, search) = 0) then
      begin
        found := msg_id + 100;
        Break;
      end;
      Inc(msg_id);
    end;
  end;

  if found = -1 then
  begin
    Result := 0;
    Exit;
  end;

  StrLCopy(@dialogBlock.replyText[0], scr_get_msg_str_speech(message_list_id, found, 1), SizeOf(dialogBlock.replyText) - 1);
  dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
  gdialog_unhide_reply;
  gDialogProcessReply;
  Result := 1;
end;

function about_lookup_name(const search: PAnsiChar): Integer;
var
  name: PAnsiChar;
  scr: PScript;
  msg_id: Integer;
  str_: PAnsiChar;
  count: Integer;
  random_msg_num: Integer;
begin
  if PID_TYPE(dialog_target^.Pid) <> OBJ_TYPE_CRITTER then
  begin
    Result := 0;
    Exit;
  end;

  name := critter_name(dialog_target);
  if name = nil then
  begin
    Result := 0;
    Exit;
  end;

  if compat_stricmp(search, name) <> 0 then
  begin
    Result := 0;
    Exit;
  end;

  if scr_ptr(dialog_target^.Sid, @scr) = -1 then
  begin
    Result := 0;
    Exit;
  end;

  count := 0;
  msg_id := 970;
  while msg_id < 980 do
  begin
    str_ := scr_get_msg_str(scr^.scr_script_idx + 1, msg_id);
    if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
      Inc(count);
    Inc(msg_id);
  end;

  if count <> 0 then
  begin
    random_msg_num := roll_random(1, count);
    msg_id := 970;
    while msg_id < 980 do
    begin
      str_ := scr_get_msg_str(scr^.scr_script_idx + 1, msg_id);
      if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
      begin
        Dec(random_msg_num);
        if random_msg_num = 0 then
        begin
          StrLCopy(@dialogBlock.replyText[0], scr_get_msg_str_speech(scr^.scr_script_idx + 1, msg_id, 1), SizeOf(dialogBlock.replyText) - 1);
          dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
          gdialog_unhide_reply;
          gDialogProcessReply;
          Result := 1;
          Exit;
        end;
      end;
      Inc(msg_id);
    end;
  end
  else
  begin
    msg_id := 970;
    while msg_id < 980 do
    begin
      str_ := scr_get_msg_str(1, msg_id);
      if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
        Inc(count);
      Inc(msg_id);
    end;

    if count <> 0 then
    begin
      random_msg_num := roll_random(1, count);
      msg_id := 970;
      while msg_id < 980 do
      begin
        str_ := scr_get_msg_str(1, msg_id);
        if (str_ <> nil) and (compat_stricmp(str_, PAnsiChar('error')) <> 0) then
        begin
          Dec(random_msg_num);
          if random_msg_num = 0 then
          begin
            StrLCopy(@dialogBlock.replyText[0], scr_get_msg_str_speech(1, msg_id, 1), SizeOf(dialogBlock.replyText) - 1);
            dialogBlock.replyText[SizeOf(dialogBlock.replyText) - 1] := #0;
            gdialog_unhide_reply;
            gDialogProcessReply;
            Result := 1;
            Exit;
          end;
        end;
        Inc(msg_id);
      end;
    end;
  end;

  Result := 0;
end;

{ Initialize variables that cannot use typed constants }
initialization
  light_BlendTable := nil;
  dark_BlendTable := nil;
  dialog_target := nil;
  dialog_target_is_party := False;
  dialogue_head := 0;
  dialogue_scr_id := -1;
  FillChar(light_GrayTable, SizeOf(light_GrayTable), 0);
  FillChar(dark_GrayTable, SizeOf(dark_GrayTable), 0);

end.
