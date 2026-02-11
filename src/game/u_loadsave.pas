{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/loadsave.h + loadsave.cc
// Save/Load game screen: slot management, file I/O, thumbnails.

unit u_loadsave;

interface

uses
  u_db, u_cache, u_object_types;

const
  // LoadSaveMode
  LOAD_SAVE_MODE_FROM_MAIN_MENU = 0;
  LOAD_SAVE_MODE_NORMAL         = 1;
  LOAD_SAVE_MODE_QUICK          = 2;

procedure InitLoadSave;
procedure ResetLoadSave;
function SaveGame(mode: Integer): Integer;
function LoadGame(mode: Integer): Integer;
function isLoadingGame: Integer;
procedure KillOldMaps;
function MapDirErase(const path: PAnsiChar; const a2: PAnsiChar): Integer;
function MapDirEraseFile(const a1: PAnsiChar; const a2: PAnsiChar): Integer;

implementation

uses
  SysUtils,
  u_config,
  u_gconfig,
  u_platform_compat,
  u_message,
  u_wordwrap,
  u_rect,
  u_fps_limiter,
  u_kb,
  u_gsound,
  u_game,
  u_object,
  u_critter,
  u_scripts,
  u_skill,
  u_roll,
  u_perk,
  u_combat,
  u_combatai,
  u_stat,
  u_item,
  u_queue,
  u_trait,
  u_automap,
  u_options,
  u_editor,
  u_worldmap,
  u_pipboy,
  u_gmovie,
  u_party,
  u_intface,
  u_map,
  u_gmouse,
  u_cycle,
  u_display,
  u_tile,
  u_proto,
  u_art,
  u_gnw,
  u_button,
  u_svga,
  u_grbuf,
  u_text,
  u_input,
  u_mouse,
  u_memory,
  u_color,
  u_bmpdlog;

// ---------------------------------------------------------------------------
// Types (local to this unit)
// ---------------------------------------------------------------------------

type
  PPAnsiChar_ = ^PAnsiChar;
  PPPAnsiChar_ = ^PPAnsiChar_;

  TLoadGameHandler = function(stream: PDB_FILE): Integer;
  TSaveGameHandler = function(stream: PDB_FILE): Integer;
  PLoadGameHandler = ^TLoadGameHandler;
  PSaveGameHandler = ^TSaveGameHandler;

  TLoadSaveWindowType = Integer;
  TLoadSaveSlotState = Integer;
  TLoadSaveScrollDirection = Integer;

  PLoadSaveSlotData = ^TLoadSaveSlotData;
  TLoadSaveSlotData = record
    signature: array[0..23] of AnsiChar;
    versionMinor: SmallInt;
    versionMajor: SmallInt;
    versionRelease: Byte;
    characterName: array[0..31] of AnsiChar;
    description: array[0..29] of AnsiChar;
    fileMonth: SmallInt;
    fileDay: SmallInt;
    fileYear: SmallInt;
    fileTime: Integer;
    gameMonth: SmallInt;
    gameDay: SmallInt;
    gameYear: SmallInt;
    gameTime: Integer;
    elevation: SmallInt;
    map: SmallInt;
    fileName: array[0..15] of AnsiChar;
  end;

const
  LOAD_SAVE_SIGNATURE = 'FALLOUT SAVE FILE';
  LOAD_SAVE_DESCRIPTION_LENGTH = 30;
  LOAD_SAVE_HANDLER_COUNT = 27;

  LSGAME_MSG_NAME = 'LSGAME.MSG';

  LS_WINDOW_WIDTH  = 640;
  LS_WINDOW_HEIGHT = 480;

  LS_PREVIEW_WIDTH  = 224;
  LS_PREVIEW_HEIGHT = 133;
  LS_PREVIEW_SIZE   = LS_PREVIEW_WIDTH * LS_PREVIEW_HEIGHT;

  LS_COMMENT_WINDOW_X = 169;
  LS_COMMENT_WINDOW_Y = 116;

  // LoadSaveWindowType
  LOAD_SAVE_WINDOW_TYPE_SAVE_GAME                = 0;
  LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_SAVE_SLOT     = 1;
  LOAD_SAVE_WINDOW_TYPE_LOAD_GAME                = 2;
  LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU = 3;
  LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_LOAD_SLOT     = 4;

  // LoadSaveSlotState
  SLOT_STATE_EMPTY               = 0;
  SLOT_STATE_OCCUPIED            = 1;
  SLOT_STATE_ERROR               = 2;
  SLOT_STATE_UNSUPPORTED_VERSION = 3;

  // LoadSaveScrollDirection
  LOAD_SAVE_SCROLL_DIRECTION_NONE = 0;
  LOAD_SAVE_SCROLL_DIRECTION_UP   = 1;
  LOAD_SAVE_SCROLL_DIRECTION_DOWN = 2;

  // LoadSaveFrm
  LOAD_SAVE_FRM_BACKGROUND          = 0;
  LOAD_SAVE_FRM_BOX                 = 1;
  LOAD_SAVE_FRM_PREVIEW_COVER       = 2;
  LOAD_SAVE_FRM_RED_BUTTON_PRESSED  = 3;
  LOAD_SAVE_FRM_RED_BUTTON_NORMAL   = 4;
  LOAD_SAVE_FRM_ARROW_DOWN_NORMAL   = 5;
  LOAD_SAVE_FRM_ARROW_DOWN_PRESSED  = 6;
  LOAD_SAVE_FRM_ARROW_UP_NORMAL     = 7;
  LOAD_SAVE_FRM_ARROW_UP_PRESSED    = 8;
  LOAD_SAVE_FRM_COUNT               = 9;

  COMPAT_MAX_PATH = 260;

  // DialogBoxOptions (from bmpdlog.h)
  DIALOG_BOX_LARGE                  = $01;
  DIALOG_BOX_MEDIUM                 = $02;
  DIALOG_BOX_NO_HORIZONTAL_CENTERING = $04;
  DIALOG_BOX_NO_VERTICAL_CENTERING  = $08;
  DIALOG_BOX_YES_NO                 = $10;
  DIALOG_BOX_0x20                   = $20;

  ORIGINAL_ISO_WINDOW_WIDTH  = 640;
  ORIGINAL_ISO_WINDOW_HEIGHT = 380;

  VERSION_MAJOR   = 1;
  VERSION_MINOR   = 1;
  VERSION_RELEASE = Byte(Ord('R'));

  WINDOW_MODAL       = $10;
  WINDOW_MOVE_ON_TOP = $04;
  WINDOW_DONT_MOVE_TOP = $02;
  BUTTON_FLAG_TRANSPARENT = $20;

  MOUSE_CURSOR_ARROW       = 1;
  MOUSE_CURSOR_WAIT_PLANET = 27;

  SEEK_SET = 0;
  SEEK_CUR = 1;

  WORD_WRAP_MAX_COUNT_LS = 64;

// ---------------------------------------------------------------------------
// Forward declarations for static functions
// ---------------------------------------------------------------------------
function QuickSnapShot: Integer; forward;
function LSGameStart(windowType: Integer): Integer; forward;
function LSGameEnd(windowType: Integer): Integer; forward;
function SaveSlot: Integer; forward;
function LoadSlot(slot: Integer): Integer; forward;
procedure GetTimeDate(day: PSmallInt; month: PSmallInt; year: PSmallInt; hour: PInteger); forward;
function SaveHeader(slot: Integer): Integer; forward;
function LoadHeader(slot: Integer): Integer; forward;
function GetSlotList: Integer; forward;
procedure ShowSlotList(a1: Integer); forward;
procedure DrawInfoBox(a1: Integer); forward;
function LoadTumbSlot(a1: Integer): Integer; forward;
function GetComment(a1: Integer): Integer; forward;
function get_input_str2(win: Integer; doneKeyCode: Integer; cancelKeyCode: Integer;
  description: PAnsiChar; maxLength: Integer; x: Integer; y: Integer;
  textColor: Integer; backgroundColor: Integer; flags: Integer): Integer; forward;
function DummyFunc(stream: PDB_FILE): Integer; forward;
function PrepLoad(stream: PDB_FILE): Integer; forward;
function EndLoad(stream: PDB_FILE): Integer; forward;
function GameMap2Slot(stream: PDB_FILE): Integer; forward;
function SlotMap2Game(stream: PDB_FILE): Integer; forward;
function mygets(dest: PAnsiChar; stream: PDB_FILE): Integer; forward;
function copy_file(const a1: PAnsiChar; const a2: PAnsiChar): Integer; forward;
function SaveBackup: Integer; forward;
function RestoreSave: Integer; forward;
function LoadObjDudeCid(stream: PDB_FILE): Integer; forward;
function SaveObjDudeCid(stream: PDB_FILE): Integer; forward;
function EraseSave: Integer; forward;

// plib/gnw/debug.h
procedure debug_printf(const fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// C library strcat / strncmp
function libc_strcat(dest: PAnsiChar; const src: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'strcat';
function libc_strncmp(const s1, s2: PAnsiChar; n: SizeUInt): Integer; cdecl; external 'c' name 'strncmp';

// ---------------------------------------------------------------------------
// Module-level implementation variables (C++ static variables)
// ---------------------------------------------------------------------------

const
  lsgrphs: array[0..LOAD_SAVE_FRM_COUNT - 1] of Integer = (
    237, // lsgame.frm
    238, // lsgbox.frm
    239, // lscover.frm
    9,   // lilreddn.frm
    8,   // lilredup.frm
    181, // dnarwoff.frm
    182, // dnarwon.frm
    199, // uparwoff.frm
    200  // uparwon.frm
  );

var
  slot_cursor: Integer = 0;
  quick_done: Boolean = False;
  bk_enable: Boolean = False;
  map_backup_count: Integer = -1;
  automap_db_flag: Integer = 0;
  patches: PAnsiChar = nil;
  emgpath: array[0..24] of AnsiChar = '\FALLOUT\CD\DATA\SAVEGAME';
  loadingGame: Integer = 0;

  ginfo: array[0..LOAD_SAVE_FRM_COUNT - 1] of TSize;
  lsgame_msgfl: TMessageList;
  LSData: array[0..9] of TLoadSaveSlotData;
  LSstatus: array[0..9] of Integer;
  thumbnail_image: array[0..1] of PByte;
  lsgmesg: TMessageListItem;
  dbleclkcntr: Integer;
  lsgwin: Integer;
  lsbmp: array[0..LOAD_SAVE_FRM_COUNT - 1] of PByte;
  snapshot: PByte;
  str2: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  str0: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  str1: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  str: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  lsgbuf: PByte;
  gmpath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  flptr: PDB_FILE;
  ls_error_code: Integer;
  fontsave: Integer;
  grphkey: array[0..LOAD_SAVE_FRM_COUNT - 1] of PCacheEntry;

  // FPS limiter (local instance)
  sharedFpsLimiter: TFpsLimiter;

// ---------------------------------------------------------------------------
// Handler arrays - declared as arrays of function pointers
// We initialize them in a procedure because Pascal const arrays of
// procedure types need initialization.
// ---------------------------------------------------------------------------
var
  master_save_list: array[0..LOAD_SAVE_HANDLER_COUNT - 1] of TSaveGameHandler;
  master_load_list: array[0..LOAD_SAVE_HANDLER_COUNT - 1] of TLoadGameHandler;
  handlers_initialized: Boolean = False;

procedure InitHandlers;
begin
  if handlers_initialized then Exit;
  handlers_initialized := True;

  master_save_list[0]  := @DummyFunc;
  master_save_list[1]  := @SaveObjDudeCid;
  master_save_list[2]  := @scr_game_save;
  master_save_list[3]  := @GameMap2Slot;
  master_save_list[4]  := @scr_game_save;
  master_save_list[5]  := @obj_save_dude;
  master_save_list[6]  := @critter_save;
  master_save_list[7]  := @critter_kill_count_save;
  master_save_list[8]  := @skill_save;
  master_save_list[9]  := @roll_save;
  master_save_list[10] := @perk_save;
  master_save_list[11] := @combat_save;
  master_save_list[12] := @combat_ai_save;
  master_save_list[13] := @stat_save;
  master_save_list[14] := @item_save;
  master_save_list[15] := @queue_save;
  master_save_list[16] := @trait_save;
  master_save_list[17] := @automap_save;
  master_save_list[18] := @save_options;
  master_save_list[19] := @editor_save;
  master_save_list[20] := @save_world_map;
  master_save_list[21] := @save_pipboy;
  master_save_list[22] := @gmovie_save;
  master_save_list[23] := @skill_use_slot_save;
  master_save_list[24] := @partyMemberSave;
  master_save_list[25] := @intface_save;
  master_save_list[26] := @DummyFunc;

  master_load_list[0]  := @PrepLoad;
  master_load_list[1]  := @LoadObjDudeCid;
  master_load_list[2]  := @scr_game_load;
  master_load_list[3]  := @SlotMap2Game;
  master_load_list[4]  := @scr_game_load2;
  master_load_list[5]  := @obj_load_dude;
  master_load_list[6]  := @critter_load;
  master_load_list[7]  := @critter_kill_count_load;
  master_load_list[8]  := @skill_load;
  master_load_list[9]  := @roll_load;
  master_load_list[10] := @perk_load;
  master_load_list[11] := @combat_load;
  master_load_list[12] := @combat_ai_load;
  master_load_list[13] := @stat_load;
  master_load_list[14] := @item_load;
  master_load_list[15] := @queue_load;
  master_load_list[16] := @trait_load;
  master_load_list[17] := @automap_load;
  master_load_list[18] := @load_options;
  master_load_list[19] := @editor_load;
  master_load_list[20] := @load_world_map;
  master_load_list[21] := @load_pipboy;
  master_load_list[22] := @gmovie_load;
  master_load_list[23] := @skill_use_slot_load;
  master_load_list[24] := @partyMemberLoad;
  master_load_list[25] := @intface_load;
  master_load_list[26] := @EndLoad;
end;

// ---------------------------------------------------------------------------
// Helper: get map_data.name (first 16 chars of the map_data structure)
// ---------------------------------------------------------------------------
function map_data_get_name: PAnsiChar;
begin
  Result := @map_data.name[0];
end;

// =========================================================================
// InitLoadSave
// =========================================================================
procedure InitLoadSave;
begin
  InitHandlers;
  quick_done := False;
  slot_cursor := 0;

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @patches) then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: Error reading patches config variable! Using default.'#10));
    patches := @emgpath[0];
  end;

  MapDirErase('MAPS\', 'SAV');
end;

// =========================================================================
// ResetLoadSave
// =========================================================================
procedure ResetLoadSave;
begin
  MapDirErase('MAPS\', 'SAV');
end;

// =========================================================================
// SaveGame
// =========================================================================
function SaveGame(mode: Integer): Integer;
var
  messageListItem: TMessageListItem;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  body: array[0..1] of PAnsiChar;
  v6, v7, v50: Integer;
  windowType: Integer;
  rc: Integer;
  doubleClickSlot: Integer;
  tick: LongWord;
  keyCode: Integer;
  selectionChanged: Boolean;
  scrollDirection: Integer;
  scrollVelocity: LongWord;
  isScrolling: Boolean;
  scrollCounter: Integer;
  start: LongWord;
  mouseX, mouseY: Integer;
  text_: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  title: PAnsiChar;
begin
  InitHandlers;
  ls_error_code := 0;

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @patches) then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: Error reading patches config variable! Using default.'#10));
    patches := @emgpath[0];
  end;

  if (mode = LOAD_SAVE_MODE_QUICK) and quick_done then
  begin
    StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
    libc_strcat(@gmpath[0], 'SAVE.DAT');

    flptr := db_fopen(@gmpath[0], 'rb');
    if flptr <> nil then
    begin
      LoadHeader(slot_cursor);
      db_fclose(flptr);
    end;

    thumbnail_image[1] := nil;
    v6 := QuickSnapShot();
    if v6 = 1 then
    begin
      v7 := SaveSlot();
      if v7 <> -1 then
        v6 := v7;
    end;

    if thumbnail_image[1] <> nil then
      mem_free(snapshot);

    gmouse_set_cursor(MOUSE_CURSOR_ARROW);

    if v6 <> -1 then
    begin
      Result := 1;
      Exit;
    end;

    if not message_init(@lsgame_msgfl) then
    begin
      Result := -1;
      Exit;
    end;

    StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('LSGAME.MSG')]);
    if not message_load(@lsgame_msgfl, @path[0]) then
    begin
      Result := -1;
      Exit;
    end;

    gsound_play_sfx_file('iisxxxx1');

    // Error saving game!
    StrCopy(@str0[0], getmsg(@lsgame_msgfl, @messageListItem, 132));
    // Unable to save game.
    StrCopy(@str1[0], getmsg(@lsgame_msgfl, @messageListItem, 133));

    body[0] := @str1[0];
    dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

    message_exit(@lsgame_msgfl);

    Result := -1;
    Exit;
  end;

  quick_done := False;

  if mode = LOAD_SAVE_MODE_QUICK then
    windowType := LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_SAVE_SLOT
  else
    windowType := LOAD_SAVE_WINDOW_TYPE_SAVE_GAME;

  if LSGameStart(windowType) = -1 then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error loading save game screen data! **'#10));
    Result := -1;
    Exit;
  end;

  if GetSlotList() = -1 then
  begin
    win_draw(lsgwin);

    gsound_play_sfx_file('iisxxxx1');

    // Error loading save game list!
    StrCopy(@str0[0], getmsg(@lsgame_msgfl, @messageListItem, 106));
    // Save game directory:
    StrCopy(@str1[0], getmsg(@lsgame_msgfl, @messageListItem, 107));

    StrLFmt(@str2[0], SizeOf(str2) - 1, '"%s\"', [PAnsiChar('SAVEGAME')]);

    // TODO: Check.
    StrCopy(@str2[0], getmsg(@lsgame_msgfl, @messageListItem, 108));

    body[0] := @str1[0];
    body[1] := @str2[0];
    dialog_out(@str0[0], @body[0], 2, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

    LSGameEnd(0);

    Result := -1;
    Exit;
  end;

  case LSstatus[slot_cursor] of
    SLOT_STATE_EMPTY,
    SLOT_STATE_ERROR,
    SLOT_STATE_UNSUPPORTED_VERSION:
      buf_to_buf(thumbnail_image[1],
          LS_PREVIEW_WIDTH,
          LS_PREVIEW_HEIGHT,
          LS_PREVIEW_WIDTH,
          lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
          LS_WINDOW_WIDTH);
  else
    begin
      LoadTumbSlot(slot_cursor);
      buf_to_buf(thumbnail_image[0],
          LS_PREVIEW_WIDTH,
          LS_PREVIEW_HEIGHT,
          LS_PREVIEW_WIDTH,
          lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
          LS_WINDOW_WIDTH);
    end;
  end;

  ShowSlotList(0);
  DrawInfoBox(slot_cursor);
  win_draw(lsgwin);
  renderPresent();

  dbleclkcntr := 24;

  rc := -1;
  doubleClickSlot := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    tick := get_time();
    keyCode := get_input();
    selectionChanged := False;
    scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_NONE;

    convertMouseWheelToArrowKey(@keyCode);

    if (keyCode = KEY_ESCAPE) or (keyCode = 501) or (game_user_wants_to_quit <> 0) then
    begin
      rc := 0;
    end
    else
    begin
      case keyCode of
        KEY_ARROW_UP:
          begin
            slot_cursor := slot_cursor - 1;
            if slot_cursor < 0 then
              slot_cursor := 0;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_ARROW_DOWN:
          begin
            slot_cursor := slot_cursor + 1;
            if slot_cursor > 9 then
              slot_cursor := 9;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_HOME:
          begin
            slot_cursor := 0;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_END:
          begin
            slot_cursor := 9;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        506:
          scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_UP;
        504:
          scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_DOWN;
        502:
          begin
            mouseGetPositionInWindow(lsgwin, @mouseX, @mouseY);

            slot_cursor := (mouseY - 79) div (3 * text_height() + 4);
            if slot_cursor < 0 then
              slot_cursor := 0;
            if slot_cursor > 9 then
              slot_cursor := 9;

            selectionChanged := True;

            if slot_cursor = doubleClickSlot then
            begin
              keyCode := 500;
              gsound_play_sfx_file('ib1p1xx1');
            end;

            doubleClickSlot := slot_cursor;
            scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_NONE;
          end;
        KEY_CTRL_Q,
        KEY_CTRL_X,
        KEY_F10:
          begin
            game_quit_with_confirm();

            if game_user_wants_to_quit <> 0 then
              rc := 0;
          end;
        KEY_PLUS,
        KEY_EQUAL:
          IncGamma();
        KEY_MINUS,
        KEY_UNDERSCORE:
          DecGamma();
        KEY_RETURN:
          keyCode := 500;
      end;
    end;

    if keyCode = 500 then
    begin
      if LSstatus[slot_cursor] = SLOT_STATE_OCCUPIED then
      begin
        rc := 1;
        // Save game already exists, overwrite?
        title := getmsg(@lsgame_msgfl, @lsgmesg, 131);
        if dialog_out(title, nil, 0, 169, 131, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_YES_NO) = 0 then
          rc := -1;
      end
      else
        rc := 1;

      selectionChanged := True;
      scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_NONE;
    end;

    if scrollDirection <> LOAD_SAVE_SCROLL_DIRECTION_NONE then
    begin
      scrollVelocity := 4;
      isScrolling := False;
      scrollCounter := 0;
      repeat
        sharedFpsLimiter.Mark;

        start := get_time();
        scrollCounter := scrollCounter + 1;

        if ((not isScrolling) and (scrollCounter = 1)) or (isScrolling and (scrollCounter > 14)) then
        begin
          isScrolling := True;

          if scrollCounter > 14 then
          begin
            scrollVelocity := scrollVelocity + 1;
            if scrollVelocity > 24 then
              scrollVelocity := 24;
          end;

          if scrollDirection = LOAD_SAVE_SCROLL_DIRECTION_UP then
          begin
            slot_cursor := slot_cursor - 1;
            if slot_cursor < 0 then
              slot_cursor := 0;
          end
          else
          begin
            slot_cursor := slot_cursor + 1;
            if slot_cursor > 9 then
              slot_cursor := 9;
          end;

          case LSstatus[slot_cursor] of
            SLOT_STATE_EMPTY,
            SLOT_STATE_ERROR:
              buf_to_buf(thumbnail_image[1],
                  LS_PREVIEW_WIDTH,
                  LS_PREVIEW_HEIGHT,
                  LS_PREVIEW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                  LS_WINDOW_WIDTH);
          else
            begin
              LoadTumbSlot(slot_cursor);
              buf_to_buf(thumbnail_image[0],
                  LS_PREVIEW_WIDTH,
                  LS_PREVIEW_HEIGHT,
                  LS_PREVIEW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                  LS_WINDOW_WIDTH);
            end;
          end;

          ShowSlotList(LOAD_SAVE_WINDOW_TYPE_SAVE_GAME);
          DrawInfoBox(slot_cursor);
          win_draw(lsgwin);
        end;

        if scrollCounter > 14 then
        begin
          while elapsed_time(start) < 1000 div scrollVelocity do begin end;
        end
        else
        begin
          while elapsed_time(start) < 1000 div 24 do begin end;
        end;

        keyCode := get_input();

        renderPresent();
        sharedFpsLimiter.Throttle;
      until (keyCode = 505) or (keyCode = 503);
    end
    else
    begin
      if selectionChanged then
      begin
        case LSstatus[slot_cursor] of
          SLOT_STATE_EMPTY,
          SLOT_STATE_ERROR,
          SLOT_STATE_UNSUPPORTED_VERSION:
            buf_to_buf(thumbnail_image[1],
                LS_PREVIEW_WIDTH,
                LS_PREVIEW_HEIGHT,
                LS_PREVIEW_WIDTH,
                lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                LS_WINDOW_WIDTH);
        else
          begin
            LoadTumbSlot(slot_cursor);
            buf_to_buf(thumbnail_image[0],
                LS_PREVIEW_WIDTH,
                LS_PREVIEW_HEIGHT,
                LS_PREVIEW_WIDTH,
                lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                LS_WINDOW_WIDTH);
          end;
        end;

        DrawInfoBox(slot_cursor);
        ShowSlotList(LOAD_SAVE_WINDOW_TYPE_SAVE_GAME);
      end;

      win_draw(lsgwin);

      dbleclkcntr := dbleclkcntr - 1;
      if dbleclkcntr = 0 then
      begin
        dbleclkcntr := 24;
        doubleClickSlot := -1;
      end;

      while elapsed_time(tick) < 1000 div 24 do begin end;
    end;

    if rc = 1 then
    begin
      v50 := GetComment(slot_cursor);
      if v50 = -1 then
      begin
        gmouse_set_cursor(MOUSE_CURSOR_ARROW);
        gsound_play_sfx_file('iisxxxx1');
        debug_printf(PAnsiChar(#10'LOADSAVE: ** Error getting save file comment **'#10));

        // Error saving game!
        StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 132));
        // Unable to save game.
        StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 133));

        body[0] := @str1[0];
        dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
        rc := -1;
      end
      else if v50 = 0 then
      begin
        gmouse_set_cursor(MOUSE_CURSOR_ARROW);
        rc := -1;
      end
      else if v50 = 1 then
      begin
        if SaveSlot() = -1 then
        begin
          gmouse_set_cursor(MOUSE_CURSOR_ARROW);
          gsound_play_sfx_file('iisxxxx1');

          // Error saving game!
          StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 132));
          // Unable to save game.
          StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 133));

          rc := -1;

          body[0] := @str1[0];
          dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

          if GetSlotList() = -1 then
          begin
            win_draw(lsgwin);
            gsound_play_sfx_file('iisxxxx1');

            // Error loading save game list!
            StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 106));
            // Save game directory:
            StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 107));

            StrLFmt(@str2[0], SizeOf(str2) - 1, '"%s\"', [PAnsiChar('SAVEGAME')]);

            // Doesn't exist or is corrupted.
            StrCopy(@text_[0], getmsg(@lsgame_msgfl, @lsgmesg, 107));

            body[0] := @str1[0];
            body[1] := @str2[0];
            dialog_out(@str0[0], @body[0], 2, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

            LSGameEnd(0);

            Result := -1;
            Exit;
          end;

          case LSstatus[slot_cursor] of
            SLOT_STATE_EMPTY,
            SLOT_STATE_ERROR,
            SLOT_STATE_UNSUPPORTED_VERSION:
              buf_to_buf(thumbnail_image[1],
                  LS_PREVIEW_WIDTH,
                  LS_PREVIEW_HEIGHT,
                  LS_PREVIEW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                  LS_WINDOW_WIDTH);
          else
            begin
              LoadTumbSlot(slot_cursor);
              buf_to_buf(thumbnail_image[0],
                  LS_PREVIEW_WIDTH,
                  LS_PREVIEW_HEIGHT,
                  LS_PREVIEW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                  LS_WINDOW_WIDTH);
            end;
          end;

          ShowSlotList(LOAD_SAVE_WINDOW_TYPE_SAVE_GAME);
          DrawInfoBox(slot_cursor);
          win_draw(lsgwin);
          dbleclkcntr := 24;
        end;
      end;
    end;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  LSGameEnd(LOAD_SAVE_WINDOW_TYPE_SAVE_GAME);

  tile_refresh_display();

  if mode = LOAD_SAVE_MODE_QUICK then
  begin
    if rc = 1 then
      quick_done := True;
  end;

  Result := rc;
end;

// =========================================================================
// QuickSnapShot
// =========================================================================
function QuickSnapShot: Integer;
var
  gameMouseWasVisible: Boolean;
  isoWindowWidth, isoWindowHeight: Integer;
  windowBuf: PByte;
begin
  snapshot := PByte(mem_malloc(LS_PREVIEW_SIZE));
  if snapshot = nil then
  begin
    Result := -1;
    Exit;
  end;

  gameMouseWasVisible := gmouse_3d_is_on();
  if gameMouseWasVisible then
    gmouse_3d_off();

  mouse_hide();
  tile_refresh_display();
  mouse_show();

  if gameMouseWasVisible then
    gmouse_3d_on();

  isoWindowWidth := win_width(display_win);
  isoWindowHeight := win_height(display_win);
  windowBuf := win_get_buf(display_win)
      + isoWindowWidth * ((isoWindowHeight - ORIGINAL_ISO_WINDOW_HEIGHT) div 2)
      + ((isoWindowWidth - ORIGINAL_ISO_WINDOW_WIDTH) div 2);
  cscale(windowBuf,
      ORIGINAL_ISO_WINDOW_WIDTH,
      ORIGINAL_ISO_WINDOW_HEIGHT,
      isoWindowWidth,
      snapshot,
      LS_PREVIEW_WIDTH,
      LS_PREVIEW_HEIGHT,
      LS_PREVIEW_WIDTH);

  thumbnail_image[1] := snapshot;

  Result := 1;
end;

// =========================================================================
// LoadGame
// =========================================================================
function LoadGame(mode: Integer): Integer;
var
  messageListItem: TMessageListItem;
  body: array[0..1] of PAnsiChar;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  windowType: Integer;
  rc: Integer;
  doubleClickSlot: Integer;
  time_: LongWord;
  keyCode: Integer;
  selectionChanged: Boolean;
  scrollDirection: Integer;
  scrollVelocity: LongWord;
  isScrolling: Boolean;
  scrollCounter: Integer;
  start: LongWord;
  mouseX, mouseY: Integer;
  clickedSlot: Integer;
  quickSaveWindowX, quickSaveWindowY: Integer;
  window: Integer;
  windowBuffer: PByte;
begin
  InitHandlers;

  body[0] := @str1[0];
  body[1] := @str2[0];

  ls_error_code := 0;

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @patches) then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: Error reading patches config variable! Using default.'#10));
    patches := @emgpath[0];
  end;

  if (mode = LOAD_SAVE_MODE_QUICK) and quick_done then
  begin
    quickSaveWindowX := (screenGetWidth() - LS_WINDOW_WIDTH) div 2;
    quickSaveWindowY := (screenGetHeight() - LS_WINDOW_HEIGHT) div 2;
    window := win_add(quickSaveWindowX,
        quickSaveWindowY,
        LS_WINDOW_WIDTH,
        LS_WINDOW_HEIGHT,
        256,
        WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
    if window <> -1 then
    begin
      windowBuffer := win_get_buf(window);
      buf_fill(windowBuffer, LS_WINDOW_WIDTH, LS_WINDOW_HEIGHT, LS_WINDOW_WIDTH, colorTable[0]);
      win_draw(window);
      renderPresent();
    end;

    if LoadSlot(slot_cursor) <> -1 then
    begin
      if window <> -1 then
        win_delete(window);
      gmouse_set_cursor(MOUSE_CURSOR_ARROW);
      Result := 1;
      Exit;
    end;

    if not message_init(@lsgame_msgfl) then
    begin
      Result := -1;
      Exit;
    end;

    StrLFmt(@path[0], SizeOf(path) - 1, '%s\%s', [msg_path, PAnsiChar('LSGAME.MSG')]);
    if not message_load(@lsgame_msgfl, @path[0]) then
    begin
      Result := -1;
      Exit;
    end;

    if window <> -1 then
      win_delete(window);

    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    gsound_play_sfx_file('iisxxxx1');
    StrCopy(@str0[0], getmsg(@lsgame_msgfl, @messageListItem, 134));
    StrCopy(@str1[0], getmsg(@lsgame_msgfl, @messageListItem, 135));
    dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);

    message_exit(@lsgame_msgfl);
    map_new_map();
    game_user_wants_to_quit := 2;

    Result := -1;
    Exit;
  end;

  quick_done := False;

  case mode of
    LOAD_SAVE_MODE_FROM_MAIN_MENU:
      windowType := LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU;
    LOAD_SAVE_MODE_NORMAL:
      windowType := LOAD_SAVE_WINDOW_TYPE_LOAD_GAME;
    LOAD_SAVE_MODE_QUICK:
      windowType := LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_LOAD_SLOT;
  else
    windowType := LOAD_SAVE_WINDOW_TYPE_LOAD_GAME; // fallback
  end;

  if LSGameStart(windowType) = -1 then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error loading save game screen data! **'#10));
    Result := -1;
    Exit;
  end;

  if GetSlotList() = -1 then
  begin
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    win_draw(lsgwin);
    renderPresent();
    gsound_play_sfx_file('iisxxxx1');
    StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 106));
    StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 107));
    StrLFmt(@str2[0], SizeOf(str2) - 1, '"%s\"', [PAnsiChar('SAVEGAME')]);
    dialog_out(@str0[0], @body[0], 2, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
    LSGameEnd(windowType);
    Result := -1;
    Exit;
  end;

  case LSstatus[slot_cursor] of
    SLOT_STATE_EMPTY,
    SLOT_STATE_ERROR,
    SLOT_STATE_UNSUPPORTED_VERSION:
      buf_to_buf(lsbmp[LOAD_SAVE_FRM_PREVIEW_COVER],
          ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
          ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].height,
          ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
          lsgbuf + LS_WINDOW_WIDTH * 39 + 340,
          LS_WINDOW_WIDTH);
  else
    begin
      LoadTumbSlot(slot_cursor);
      buf_to_buf(thumbnail_image[0],
          LS_PREVIEW_WIDTH,
          LS_PREVIEW_HEIGHT,
          LS_PREVIEW_WIDTH,
          lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
          LS_WINDOW_WIDTH);
    end;
  end;

  ShowSlotList(2);
  DrawInfoBox(slot_cursor);
  win_draw(lsgwin);
  dbleclkcntr := 24;

  rc := -1;
  doubleClickSlot := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    time_ := get_time();
    keyCode := get_input();
    selectionChanged := False;
    scrollDirection := 0;

    convertMouseWheelToArrowKey(@keyCode);

    if (keyCode = KEY_ESCAPE) or (keyCode = 501) or (game_user_wants_to_quit <> 0) then
    begin
      rc := 0;
    end
    else
    begin
      case keyCode of
        KEY_ARROW_UP:
          begin
            slot_cursor := slot_cursor - 1;
            if slot_cursor < 0 then
              slot_cursor := 0;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_ARROW_DOWN:
          begin
            slot_cursor := slot_cursor + 1;
            if slot_cursor > 9 then
              slot_cursor := 9;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_HOME:
          begin
            slot_cursor := 0;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        KEY_END:
          begin
            slot_cursor := 9;
            selectionChanged := True;
            doubleClickSlot := -1;
          end;
        506:
          scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_UP;
        504:
          scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_DOWN;
        502:
          begin
            mouseGetPositionInWindow(lsgwin, @mouseX, @mouseY);

            clickedSlot := (mouseY - 79) div (3 * text_height() + 4);
            if clickedSlot < 0 then
              clickedSlot := 0
            else if clickedSlot > 9 then
              clickedSlot := 9;

            slot_cursor := clickedSlot;
            if clickedSlot = doubleClickSlot then
            begin
              keyCode := 500;
              gsound_play_sfx_file('ib1p1xx1');
            end;

            selectionChanged := True;
            scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_NONE;
            doubleClickSlot := slot_cursor;
          end;
        KEY_MINUS,
        KEY_UNDERSCORE:
          DecGamma();
        KEY_EQUAL,
        KEY_PLUS:
          IncGamma();
        KEY_RETURN:
          keyCode := 500;
        KEY_CTRL_Q,
        KEY_CTRL_X,
        KEY_F10:
          begin
            game_quit_with_confirm();
            if game_user_wants_to_quit <> 0 then
              rc := 0;
          end;
      end;
    end;

    if keyCode = 500 then
    begin
      if LSstatus[slot_cursor] <> SLOT_STATE_EMPTY then
        rc := 1
      else
        rc := -1;

      selectionChanged := True;
      scrollDirection := LOAD_SAVE_SCROLL_DIRECTION_NONE;
    end;

    if scrollDirection <> LOAD_SAVE_SCROLL_DIRECTION_NONE then
    begin
      scrollVelocity := 4;
      isScrolling := False;
      scrollCounter := 0;
      repeat
        sharedFpsLimiter.Mark;

        start := get_time();
        scrollCounter := scrollCounter + 1;

        if ((not isScrolling) and (scrollCounter = 1)) or (isScrolling and (scrollCounter > 14)) then
        begin
          isScrolling := True;

          if scrollCounter > 14 then
          begin
            scrollVelocity := scrollVelocity + 1;
            if scrollVelocity > 24 then
              scrollVelocity := 24;
          end;

          if scrollDirection = LOAD_SAVE_SCROLL_DIRECTION_UP then
          begin
            slot_cursor := slot_cursor - 1;
            if slot_cursor < 0 then
              slot_cursor := 0;
          end
          else
          begin
            slot_cursor := slot_cursor + 1;
            if slot_cursor > 9 then
              slot_cursor := 9;
          end;

          case LSstatus[slot_cursor] of
            SLOT_STATE_EMPTY,
            SLOT_STATE_ERROR,
            SLOT_STATE_UNSUPPORTED_VERSION:
              buf_to_buf(lsbmp[LOAD_SAVE_FRM_PREVIEW_COVER],
                  ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                  ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].height,
                  ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                  lsgbuf + LS_WINDOW_WIDTH * 39 + 340,
                  LS_WINDOW_WIDTH);
          else
            begin
              LoadTumbSlot(slot_cursor);
              buf_to_buf(lsbmp[LOAD_SAVE_FRM_BACKGROUND] + LS_WINDOW_WIDTH * 39 + 340,
                  ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                  ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].height,
                  LS_WINDOW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 39 + 340,
                  LS_WINDOW_WIDTH);
              buf_to_buf(thumbnail_image[0],
                  LS_PREVIEW_WIDTH,
                  LS_PREVIEW_HEIGHT,
                  LS_PREVIEW_WIDTH,
                  lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                  LS_WINDOW_WIDTH);
            end;
          end;

          ShowSlotList(2);
          DrawInfoBox(slot_cursor);
          win_draw(lsgwin);
        end;

        if scrollCounter > 14 then
        begin
          while elapsed_time(start) < 1000 div scrollVelocity do begin end;
        end
        else
        begin
          while elapsed_time(start) < 1000 div 24 do begin end;
        end;

        keyCode := get_input();

        renderPresent();
        sharedFpsLimiter.Throttle;
      until (keyCode = 505) or (keyCode = 503);
    end
    else
    begin
      if selectionChanged then
      begin
        case LSstatus[slot_cursor] of
          SLOT_STATE_EMPTY,
          SLOT_STATE_ERROR,
          SLOT_STATE_UNSUPPORTED_VERSION:
            buf_to_buf(lsbmp[LOAD_SAVE_FRM_PREVIEW_COVER],
                ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].height,
                ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                lsgbuf + LS_WINDOW_WIDTH * 39 + 340,
                LS_WINDOW_WIDTH);
        else
          begin
            LoadTumbSlot(slot_cursor);
            buf_to_buf(lsbmp[LOAD_SAVE_FRM_BACKGROUND] + LS_WINDOW_WIDTH * 39 + 340,
                ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].width,
                ginfo[LOAD_SAVE_FRM_PREVIEW_COVER].height,
                LS_WINDOW_WIDTH,
                lsgbuf + LS_WINDOW_WIDTH * 39 + 340,
                LS_WINDOW_WIDTH);
            buf_to_buf(thumbnail_image[0],
                LS_PREVIEW_WIDTH,
                LS_PREVIEW_HEIGHT,
                LS_PREVIEW_WIDTH,
                lsgbuf + LS_WINDOW_WIDTH * 58 + 366,
                LS_WINDOW_WIDTH);
          end;
        end;

        DrawInfoBox(slot_cursor);
        ShowSlotList(2);
      end;

      win_draw(lsgwin);

      dbleclkcntr := dbleclkcntr - 1;
      if dbleclkcntr = 0 then
      begin
        dbleclkcntr := 24;
        doubleClickSlot := -1;
      end;

      while elapsed_time(time_) < 1000 div 24 do begin end;
    end;

    if rc = 1 then
    begin
      case LSstatus[slot_cursor] of
        SLOT_STATE_UNSUPPORTED_VERSION:
          begin
            gsound_play_sfx_file('iisxxxx1');
            StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 134));
            StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 136));
            StrCopy(@str2[0], getmsg(@lsgame_msgfl, @lsgmesg, 135));
            dialog_out(@str0[0], @body[0], 2, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
            rc := -1;
          end;
        SLOT_STATE_ERROR:
          begin
            gsound_play_sfx_file('iisxxxx1');
            StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 134));
            StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 136));
            dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
            rc := -1;
          end;
      else
        begin
          if LoadSlot(slot_cursor) = -1 then
          begin
            gmouse_set_cursor(MOUSE_CURSOR_ARROW);
            gsound_play_sfx_file('iisxxxx1');
            StrCopy(@str0[0], getmsg(@lsgame_msgfl, @lsgmesg, 134));
            StrCopy(@str1[0], getmsg(@lsgame_msgfl, @lsgmesg, 135));
            dialog_out(@str0[0], @body[0], 1, 169, 116, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
            map_new_map();
            game_user_wants_to_quit := 2;
            rc := -1;
          end;
        end;
      end;
    end;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  if mode = LOAD_SAVE_MODE_FROM_MAIN_MENU then
    LSGameEnd(LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU)
  else
    LSGameEnd(LOAD_SAVE_WINDOW_TYPE_LOAD_GAME);

  if mode = LOAD_SAVE_MODE_QUICK then
  begin
    if rc = 1 then
      quick_done := True;
  end;

  Result := rc;
end;

// =========================================================================
// LSGameStart
// =========================================================================
function LSGameStart(windowType: Integer): Integer;
var
  index: Integer;
  fid: Integer;
  lsWindowX, lsWindowY: Integer;
  messageId: Integer;
  msg: PAnsiChar;
  btn: Integer;
  gameMouseWasVisible: Boolean;
  isoWindowWidth, isoWindowHeight: Integer;
  windowBuf: PByte;
  unlockIdx: Integer;
begin
  fontsave := text_curr();
  text_font(103);

  bk_enable := False;
  if not message_init(@lsgame_msgfl) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@str[0], SizeOf(str) - 1, '%s%s', [msg_path, PAnsiChar(LSGAME_MSG_NAME)]);
  if not message_load(@lsgame_msgfl, @str[0]) then
  begin
    Result := -1;
    Exit;
  end;

  snapshot := PByte(mem_malloc(61632));
  if snapshot = nil then
  begin
    message_exit(@lsgame_msgfl);
    text_font(fontsave);
    Result := -1;
    Exit;
  end;

  thumbnail_image[0] := snapshot;
  thumbnail_image[1] := snapshot + LS_PREVIEW_SIZE;

  if windowType <> LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU then
    bk_enable := map_disable_bk_processes();

  cycle_disable();

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  if (windowType = LOAD_SAVE_WINDOW_TYPE_SAVE_GAME) or (windowType = LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_SAVE_SLOT) then
  begin
    gameMouseWasVisible := gmouse_3d_is_on();
    if gameMouseWasVisible then
      gmouse_3d_off();

    mouse_hide();
    tile_refresh_display();
    mouse_show();

    if gameMouseWasVisible then
      gmouse_3d_on();

    isoWindowWidth := win_width(display_win);
    isoWindowHeight := win_height(display_win);
    windowBuf := win_get_buf(display_win)
        + isoWindowWidth * ((isoWindowHeight - ORIGINAL_ISO_WINDOW_HEIGHT) div 2)
        + ((isoWindowWidth - ORIGINAL_ISO_WINDOW_WIDTH) div 2);
    cscale(windowBuf,
        ORIGINAL_ISO_WINDOW_WIDTH,
        ORIGINAL_ISO_WINDOW_HEIGHT,
        isoWindowWidth,
        thumbnail_image[1],
        LS_PREVIEW_WIDTH,
        LS_PREVIEW_HEIGHT,
        LS_PREVIEW_WIDTH);
  end;

  index := 0;
  while index < LOAD_SAVE_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, lsgrphs[index], 0, 0, 0);
    lsbmp[index] := art_lock(fid,
        @grphkey[index],
        @ginfo[index].width,
        @ginfo[index].height);

    if lsbmp[index] = nil then
    begin
      unlockIdx := index - 1;
      while unlockIdx >= 0 do
      begin
        art_ptr_unlock(grphkey[unlockIdx]);
        unlockIdx := unlockIdx - 1;
      end;
      mem_free(snapshot);
      message_exit(@lsgame_msgfl);
      text_font(fontsave);

      if windowType <> LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU then
      begin
        if bk_enable then
          map_enable_bk_processes();
      end;

      cycle_enable();
      gmouse_set_cursor(MOUSE_CURSOR_ARROW);
      Result := -1;
      Exit;
    end;
    index := index + 1;
  end;

  lsWindowX := (screenGetWidth() - LS_WINDOW_WIDTH) div 2;
  lsWindowY := (screenGetHeight() - LS_WINDOW_HEIGHT) div 2;
  lsgwin := win_add(lsWindowX,
      lsWindowY,
      LS_WINDOW_WIDTH,
      LS_WINDOW_HEIGHT,
      256,
      WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if lsgwin = -1 then
  begin
    // FIXME: Leaking frms.
    mem_free(snapshot);
    message_exit(@lsgame_msgfl);
    text_font(fontsave);

    if windowType <> LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU then
    begin
      if bk_enable then
        map_enable_bk_processes();
    end;

    cycle_enable();
    gmouse_set_cursor(MOUSE_CURSOR_ARROW);
    Result := -1;
    Exit;
  end;

  lsgbuf := win_get_buf(lsgwin);
  Move(lsbmp[LOAD_SAVE_FRM_BACKGROUND]^, lsgbuf^, LS_WINDOW_WIDTH * LS_WINDOW_HEIGHT);

  case windowType of
    LOAD_SAVE_WINDOW_TYPE_SAVE_GAME:
      // SAVE GAME
      messageId := 102;
    LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_SAVE_SLOT:
      // PICK A QUICK SAVE SLOT
      messageId := 103;
    LOAD_SAVE_WINDOW_TYPE_LOAD_GAME,
    LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU:
      // LOAD GAME
      messageId := 100;
    LOAD_SAVE_WINDOW_TYPE_PICK_QUICK_LOAD_SLOT:
      // PICK A QUICK LOAD SLOT
      messageId := 101;
  else
    messageId := 100; // fallback
  end;

  msg := getmsg(@lsgame_msgfl, @lsgmesg, messageId);
  text_to_buf(lsgbuf + LS_WINDOW_WIDTH * 27 + 48, msg, LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, colorTable[18979]);

  // DONE
  msg := getmsg(@lsgame_msgfl, @lsgmesg, 104);
  text_to_buf(lsgbuf + LS_WINDOW_WIDTH * 348 + 410, msg, LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, colorTable[18979]);

  // CANCEL
  msg := getmsg(@lsgame_msgfl, @lsgmesg, 105);
  text_to_buf(lsgbuf + LS_WINDOW_WIDTH * 348 + 515, msg, LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, colorTable[18979]);

  btn := win_register_button(lsgwin,
      391, 349,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].height,
      -1, -1, -1, 500,
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_NORMAL],
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(lsgwin,
      495, 349,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].height,
      -1, -1, -1, 501,
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_NORMAL],
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(lsgwin,
      35, 58,
      ginfo[LOAD_SAVE_FRM_ARROW_UP_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_ARROW_UP_PRESSED].height,
      -1, 505, 506, 505,
      lsbmp[LOAD_SAVE_FRM_ARROW_UP_NORMAL],
      lsbmp[LOAD_SAVE_FRM_ARROW_UP_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(lsgwin,
      35,
      ginfo[LOAD_SAVE_FRM_ARROW_UP_PRESSED].height + 58,
      ginfo[LOAD_SAVE_FRM_ARROW_DOWN_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_ARROW_DOWN_PRESSED].height,
      -1, 503, 504, 503,
      lsbmp[LOAD_SAVE_FRM_ARROW_DOWN_NORMAL],
      lsbmp[LOAD_SAVE_FRM_ARROW_DOWN_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_register_button(lsgwin, 55, 87, 230, 353, -1, -1, -1, 502, nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
  text_font(101);

  Result := 0;
end;

// =========================================================================
// LSGameEnd
// =========================================================================
function LSGameEnd(windowType: Integer): Integer;
var
  index: Integer;
begin
  win_delete(lsgwin);
  text_font(fontsave);
  message_exit(@lsgame_msgfl);

  for index := 0 to LOAD_SAVE_FRM_COUNT - 1 do
    art_ptr_unlock(grphkey[index]);

  mem_free(snapshot);

  if windowType <> LOAD_SAVE_WINDOW_TYPE_LOAD_GAME_FROM_MAIN_MENU then
  begin
    if bk_enable then
      map_enable_bk_processes();
  end;

  cycle_enable();
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  Result := 0;
end;

// =========================================================================
// SaveSlot
// =========================================================================
function SaveSlot: Integer;
var
  pos: LongInt;
  index: Integer;
  handler: TSaveGameHandler;
begin
  ls_error_code := 0;
  map_backup_count := -1;
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_PLANET);

  gsound_background_pause();

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s', [patches, PAnsiChar('SAVEGAME')]);
  compat_mkdir(@gmpath[0]);

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  compat_mkdir(@gmpath[0]);

  if SaveBackup() = -1 then
    debug_printf(PAnsiChar(#10'LOADSAVE: Warning, can''t backup save file!'#10));

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  libc_strcat(@gmpath[0], 'SAVE.DAT');

  debug_printf(PAnsiChar(#10'LOADSAVE: Save name: %s'#10), @gmpath[0]);

  flptr := db_fopen(@gmpath[0], 'wb');
  if flptr = nil then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error opening save game for writing! **'#10));
    RestoreSave();
    StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
    MapDirErase(@gmpath[0], 'BAK');
    partyMemberUnPrepSave();
    gsound_background_unpause();
    Result := -1;
    Exit;
  end;

  pos := db_ftell(flptr);
  if SaveHeader(slot_cursor) = -1 then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error writing save game header! **'#10));
    debug_printf('LOADSAVE: Save file header size written: %d bytes.'#10, db_ftell(flptr) - pos);
    db_fclose(flptr);
    RestoreSave();
    StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
    MapDirErase(@gmpath[0], 'BAK');
    partyMemberUnPrepSave();
    gsound_background_unpause();
    Result := -1;
    Exit;
  end;

  for index := 0 to LOAD_SAVE_HANDLER_COUNT - 1 do
  begin
    pos := db_ftell(flptr);
    handler := master_save_list[index];
    if handler(flptr) = -1 then
    begin
      debug_printf(PAnsiChar(#10'LOADSAVE: ** Error writing save function #%d data! **'#10), index);
      db_fclose(flptr);
      RestoreSave();
      StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
      MapDirErase(@gmpath[0], 'BAK');
      partyMemberUnPrepSave();
      gsound_background_unpause();
      Result := -1;
      Exit;
    end;

    debug_printf('LOADSAVE: Save function #%d data size written: %d bytes.'#10, index, db_ftell(flptr) - pos);
  end;

  debug_printf('LOADSAVE: Total save data written: %ld bytes.'#10, db_ftell(flptr));

  db_fclose(flptr);

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  MapDirErase(@gmpath[0], 'BAK');

  lsgmesg.num := 140;
  if message_search(@lsgame_msgfl, @lsgmesg) then
    display_print(lsgmesg.text)
  else
    debug_printf(PAnsiChar(#10'Error: Couldn''t find LoadSave Message!'));

  gsound_background_unpause();

  Result := 0;
end;

// =========================================================================
// isLoadingGame
// =========================================================================
function isLoadingGame: Integer;
begin
  Result := loadingGame;
end;

// =========================================================================
// LoadSlot
// =========================================================================
function LoadSlot(slot: Integer): Integer;
var
  ptr: PLoadSaveSlotData;
  pos: LongInt;
  index: Integer;
  handler: TLoadGameHandler;
begin
  gmouse_set_cursor(MOUSE_CURSOR_WAIT_PLANET);

  if isInCombat() then
  begin
    intface_end_window_close(False);
    combat_over_from_load();
    gmouse_set_cursor(MOUSE_CURSOR_WAIT_PLANET);
  end;

  loadingGame := 1;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  libc_strcat(@gmpath[0], 'SAVE.DAT');

  ptr := @LSData[slot];
  debug_printf(PAnsiChar(#10'LOADSAVE: Load name: %s'#10), @ptr^.description[0]);

  flptr := db_fopen(@gmpath[0], 'rb');
  if flptr = nil then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error opening load game file for reading! **'#10));
    loadingGame := 0;
    Result := -1;
    Exit;
  end;

  pos := db_ftell(flptr);
  if LoadHeader(slot) = -1 then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Error reading save  game header! **'#10));
    db_fclose(flptr);
    game_reset();
    loadingGame := 0;
    Result := -1;
    Exit;
  end;

  debug_printf('LOADSAVE: Load file header size read: %d bytes.'#10, db_ftell(flptr) - pos);

  index := 0;
  while index < LOAD_SAVE_HANDLER_COUNT do
  begin
    pos := db_ftell(flptr);
    handler := master_load_list[index];
    if handler(flptr) = -1 then
    begin
      debug_printf(PAnsiChar(#10'LOADSAVE: ** Error reading load function #%d data! **'#10), index);
      debug_printf('LOADSAVE: Load function #%d data size read: %d bytes.'#10, index, db_ftell(flptr) - pos);
      db_fclose(flptr);
      game_reset();
      loadingGame := 0;
      Result := -1;
      Exit;
    end;

    debug_printf('LOADSAVE: Load function #%d data size read: %d bytes.'#10, index, db_ftell(flptr) - pos);
    index := index + 1;
  end;

  debug_printf('LOADSAVE: Total load data read: %ld bytes.'#10, db_ftell(flptr));
  db_fclose(flptr);

  StrLFmt(@str[0], SizeOf(str) - 1, '%s\', [PAnsiChar('MAPS')]);
  MapDirErase(@str[0], 'BAK');
  proto_dude_update_gender();

  // Game Loaded.
  lsgmesg.num := 141;
  if message_search(@lsgame_msgfl, @lsgmesg) then
    display_print(lsgmesg.text)
  else
    debug_printf(PAnsiChar(#10'Error: Couldn''t find LoadSave Message!'));

  loadingGame := 0;

  Result := 0;
end;

// =========================================================================
// GetTimeDate
// =========================================================================
procedure GetTimeDate(day: PSmallInt; month: PSmallInt; year: PSmallInt; hour: PInteger);
var
  nowDT: TDateTime;
  y, m, d: Word;
  h, mi, s, ms: Word;
begin
  nowDT := Now;
  DecodeDate(nowDT, y, m, d);
  DecodeTime(nowDT, h, mi, s, ms);

  day^ := SmallInt(d);
  month^ := SmallInt(m);
  year^ := SmallInt(y);
  hour^ := Integer(h) + Integer(mi);
end;

// =========================================================================
// SaveHeader
// =========================================================================
function SaveHeader(slot: Integer): Integer;
var
  ptr: PLoadSaveSlotData;
  temp: array[0..2] of SmallInt;
  characterName: PAnsiChar;
  file_time: Integer;
  month_, day_, year_: Integer;
  mapName: array[0..127] of AnsiChar;
  v1: PAnsiChar;
begin
  ls_error_code := 4;

  ptr := @LSData[slot];
  StrLCopy(@ptr^.signature[0], LOAD_SAVE_SIGNATURE, 23);

  if db_fwrite(@ptr^.signature[0], 1, 24, flptr) = SizeUInt(-1) then
  begin
    Result := -1;
    Exit;
  end;

  temp[0] := VERSION_MAJOR;
  temp[1] := VERSION_MINOR;

  ptr^.versionMinor := temp[0];
  ptr^.versionMajor := temp[1];

  if db_fwriteInt16List(flptr, @temp[0], 2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.versionRelease := VERSION_RELEASE;
  if db_fwriteByte(flptr, VERSION_RELEASE) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  characterName := critter_name(obj_dude);
  StrLCopy(@ptr^.characterName[0], characterName, 31);

  if db_fwrite(@ptr^.characterName[0], 32, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwrite(@ptr^.description[0], 30, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  // NOTE: Uninline.
  GetTimeDate(@temp[0], @temp[1], @temp[2], @file_time);

  ptr^.fileDay := temp[0];
  ptr^.fileMonth := temp[1];
  ptr^.fileYear := temp[2];
  ptr^.fileTime := file_time;

  if db_fwriteInt16List(flptr, @temp[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwriteInt32(flptr, ptr^.fileTime) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  game_time_date(@month_, @day_, @year_);

  temp[0] := SmallInt(month_);
  temp[1] := SmallInt(day_);
  temp[2] := SmallInt(year_);
  ptr^.gameTime := Integer(game_time());

  if db_fwriteInt16List(flptr, @temp[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwriteInt32(flptr, ptr^.gameTime) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.elevation := SmallInt(map_elevation);
  if db_fwriteShort(flptr, Word(ptr^.elevation)) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.map := SmallInt(map_get_index_number());
  if db_fwriteShort(flptr, Word(ptr^.map)) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  StrCopy(@mapName[0], map_data_get_name());

  v1 := strmfe(@str[0], @mapName[0], 'sav');
  StrLCopy(@ptr^.fileName[0], v1, 15);
  if db_fwrite(@ptr^.fileName[0], 16, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwrite(thumbnail_image[1], LS_PREVIEW_SIZE, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  FillChar(mapName, 128, 0);
  if db_fwrite(@mapName[0], 1, 128, flptr) <> 128 then
  begin
    Result := -1;
    Exit;
  end;

  ls_error_code := 0;

  Result := 0;
end;

// =========================================================================
// LoadHeader
// =========================================================================
function LoadHeader(slot: Integer): Integer;
var
  ptr: PLoadSaveSlotData;
  v8: array[0..2] of SmallInt;
begin
  ls_error_code := 3;

  ptr := @LSData[slot];

  if db_fread(@ptr^.signature[0], 1, 24, flptr) <> 24 then
  begin
    Result := -1;
    Exit;
  end;

  if libc_strncmp(@ptr^.signature[0], LOAD_SAVE_SIGNATURE, 18) <> 0 then
  begin
    debug_printf(PAnsiChar(#10'LOADSAVE: ** Invalid save file on load! **'#10));
    ls_error_code := 2;
    Result := -1;
    Exit;
  end;

  if db_freadInt16List(flptr, @v8[0], 2) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.versionMinor := v8[0];
  ptr^.versionMajor := v8[1];

  if db_freadByte(flptr, @ptr^.versionRelease) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fread(@ptr^.characterName[0], 32, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fread(@ptr^.description[0], 30, 1, flptr) <> 1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt16List(flptr, @v8[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.fileMonth := v8[0];
  ptr^.fileDay := v8[1];
  ptr^.fileYear := v8[2];

  if db_freadInt32(flptr, @ptr^.fileTime) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt16List(flptr, @v8[0], 3) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  ptr^.gameMonth := v8[0];
  ptr^.gameDay := v8[1];
  ptr^.gameYear := v8[2];

  if db_freadInt32(flptr, @ptr^.gameTime) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt16(flptr, @ptr^.elevation) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt16(flptr, @ptr^.map) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fread(@ptr^.fileName[0], 1, 16, flptr) <> 16 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fseek(flptr, LS_PREVIEW_SIZE, SEEK_CUR) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fseek(flptr, 128, 1) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  ls_error_code := 0;

  Result := 0;
end;

// =========================================================================
// GetSlotList
// =========================================================================
function GetSlotList: Integer;
var
  de: TDirEntry;
  index: Integer;
begin
  index := 0;
  while index < 10 do
  begin
    StrLFmt(@str[0], SizeOf(str) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), index + 1, PAnsiChar('SAVE.DAT')]);

    if db_dir_entry(@str[0], @de) <> 0 then
    begin
      LSstatus[index] := SLOT_STATE_EMPTY;
    end
    else
    begin
      flptr := db_fopen(@str[0], 'rb');

      if flptr = nil then
      begin
        debug_printf(PAnsiChar(#10'LOADSAVE: ** Error opening save  game for reading! **'#10));
        Result := -1;
        Exit;
      end;

      if LoadHeader(index) = -1 then
      begin
        if ls_error_code = 1 then
        begin
          debug_printf('LOADSAVE: ** save file #%d is an older version! **'#10, slot_cursor);
          LSstatus[index] := SLOT_STATE_UNSUPPORTED_VERSION;
        end
        else
        begin
          debug_printf('LOADSAVE: ** Save file #%d corrupt! **', index);
          LSstatus[index] := SLOT_STATE_ERROR;
        end;
      end
      else
        LSstatus[index] := SLOT_STATE_OCCUPIED;

      db_fclose(flptr);
    end;
    index := index + 1;
  end;
  Result := index;
end;

// =========================================================================
// ShowSlotList
// =========================================================================
procedure ShowSlotList(a1: Integer);
var
  y: Integer;
  index: Integer;
  color: Integer;
  text_: PAnsiChar;
begin
  buf_fill(lsgbuf + LS_WINDOW_WIDTH * 87 + 55, 230, 353, LS_WINDOW_WIDTH, (lsgbuf + LS_WINDOW_WIDTH * 86 + 55)^ and $FF);

  y := 87;
  for index := 0 to 9 do
  begin
    if index = slot_cursor then
      color := colorTable[32747]
    else
      color := colorTable[992];

    if a1 <> 0 then
      text_ := getmsg(@lsgame_msgfl, @lsgmesg, 110)
    else
      text_ := getmsg(@lsgame_msgfl, @lsgmesg, 109);
    StrLFmt(@str[0], SizeOf(str) - 1, '[   %s %.2d:   ]', [text_, index + 1]);
    text_to_buf(lsgbuf + LS_WINDOW_WIDTH * y + 55, @str[0], LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, color);

    y := y + text_height();
    case LSstatus[index] of
      SLOT_STATE_OCCUPIED:
        StrCopy(@str[0], @LSData[index].description[0]);
      SLOT_STATE_EMPTY:
        begin
          // - EMPTY -
          text_ := getmsg(@lsgame_msgfl, @lsgmesg, 111);
          StrLFmt(@str[0], SizeOf(str) - 1, '       %s', [text_]);
        end;
      SLOT_STATE_ERROR:
        begin
          // - CORRUPT SAVE FILE -
          text_ := getmsg(@lsgame_msgfl, @lsgmesg, 112);
          StrLFmt(@str[0], SizeOf(str) - 1, '%s', [text_]);
          color := colorTable[32328];
        end;
      SLOT_STATE_UNSUPPORTED_VERSION:
        begin
          // - OLD VERSION -
          text_ := getmsg(@lsgame_msgfl, @lsgmesg, 113);
          StrLFmt(@str[0], SizeOf(str) - 1, ' %s', [text_]);
          color := colorTable[32328];
        end;
    end;

    text_to_buf(lsgbuf + LS_WINDOW_WIDTH * y + 55, @str[0], LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, color);
    y := y + 2 * text_height() + 4;
  end;
end;

// =========================================================================
// DrawInfoBox
// =========================================================================
procedure DrawInfoBox(a1: Integer);
var
  dest: PByte;
  text_: PAnsiChar;
  color: Integer;
  ptr: PLoadSaveSlotData;
  v4: Integer;
  minutes: Integer;
  v6: Integer;
  time_val: Integer;
  v2: Integer;
  v22: PAnsiChar;
  v9: PAnsiChar;
  y: Integer;
  beginnings: array[0..WORD_WRAP_MAX_COUNT_LS - 1] of SmallInt;
  count: SmallInt;
  windex: Integer;
  beginning: PAnsiChar;
  ending: PAnsiChar;
  c: AnsiChar;
begin
  buf_to_buf(lsbmp[LOAD_SAVE_FRM_BACKGROUND] + LS_WINDOW_WIDTH * 254 + 396, 164, 60, LS_WINDOW_WIDTH, lsgbuf + LS_WINDOW_WIDTH * 254 + 396, 640);

  color := colorTable[992];
  dest := nil;
  text_ := nil;

  case LSstatus[a1] of
    SLOT_STATE_OCCUPIED:
      begin
        ptr := @LSData[a1];
        text_to_buf(lsgbuf + LS_WINDOW_WIDTH * 254 + 396, @ptr^.characterName[0], LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, color);

        v4 := ptr^.gameTime div 600;
        minutes := v4 mod 60;
        v6 := 25 * ((v4 div 60) mod 24);
        time_val := 4 * v6 + minutes;

        text_ := getmsg(@lsgame_msgfl, @lsgmesg, 116 + ptr^.gameMonth);
        StrLFmt(@str[0], SizeOf(str) - 1, '%.2d %s %.4d   %.4d', [Integer(ptr^.gameDay), text_, Integer(ptr^.gameYear), time_val]);

        v2 := text_height();
        text_to_buf(lsgbuf + LS_WINDOW_WIDTH * (256 + v2) + 397, @str[0], LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, color);

        v22 := map_get_elev_idx(ptr^.map, ptr^.elevation);
        v9 := map_get_short_name(ptr^.map);
        StrLFmt(@str[0], SizeOf(str) - 1, '%s %s', [v9, v22]);

        y := v2 + 3 + v2 + 256;
        if word_wrap(@str[0], 164, @beginnings[0], @count) = 0 then
        begin
          windex := 0;
          while windex < count - 1 do
          begin
            beginning := @str[0] + beginnings[windex];
            ending := @str[0] + beginnings[windex + 1];
            c := ending^;
            ending^ := #0;
            text_to_buf(lsgbuf + LS_WINDOW_WIDTH * y + 399, beginning, 164, LS_WINDOW_WIDTH, color);
            y := y + v2 + 2;
            ending^ := c;
            windex := windex + 1;
          end;
        end;
        Exit; // return from the occupied case
      end;
    SLOT_STATE_EMPTY:
      begin
        // Empty.
        text_ := getmsg(@lsgame_msgfl, @lsgmesg, 114);
        dest := lsgbuf + LS_WINDOW_WIDTH * 262 + 404;
      end;
    SLOT_STATE_ERROR:
      begin
        // Error!
        text_ := getmsg(@lsgame_msgfl, @lsgmesg, 115);
        dest := lsgbuf + LS_WINDOW_WIDTH * 262 + 404;
        color := colorTable[32328];
      end;
    SLOT_STATE_UNSUPPORTED_VERSION:
      begin
        // Old version.
        text_ := getmsg(@lsgame_msgfl, @lsgmesg, 116);
        dest := lsgbuf + LS_WINDOW_WIDTH * 262 + 400;
        color := colorTable[32328];
      end;
  end;

  if dest <> nil then
    text_to_buf(dest, text_, LS_WINDOW_WIDTH, LS_WINDOW_WIDTH, color);
end;

// =========================================================================
// LoadTumbSlot
// =========================================================================
function LoadTumbSlot(a1: Integer): Integer;
var
  stream: PDB_FILE;
  v2: Integer;
begin
  v2 := LSstatus[slot_cursor];
  if (v2 <> 0) and (v2 <> 2) and (v2 <> 3) then
  begin
    StrLFmt(@str[0], SizeOf(str) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1, PAnsiChar('SAVE.DAT')]);
    debug_printf(' Filename %s'#10, @str[0]);

    stream := db_fopen(@str[0], 'rb');
    if stream = nil then
    begin
      debug_printf(PAnsiChar(#10'LOADSAVE: ** (A) Error reading thumbnail #%d! **'#10), a1);
      Result := -1;
      Exit;
    end;

    if db_fseek(stream, 131, SEEK_SET) <> 0 then
    begin
      debug_printf(PAnsiChar(#10'LOADSAVE: ** (B) Error reading thumbnail #%d! **'#10), a1);
      db_fclose(stream);
      Result := -1;
      Exit;
    end;

    if db_fread(thumbnail_image[0], LS_PREVIEW_SIZE, 1, stream) <> 1 then
    begin
      debug_printf(PAnsiChar(#10'LOADSAVE: ** (C) Error reading thumbnail #%d! **'#10), a1);
      db_fclose(stream);
      Result := -1;
      Exit;
    end;

    db_fclose(stream);
  end;

  Result := 0;
end;

// =========================================================================
// GetComment
// =========================================================================
function GetComment(a1: Integer): Integer;
var
  commentWindowX, commentWindowY: Integer;
  window: Integer;
  windowBuffer: PByte;
  msg: PAnsiChar;
  title: array[0..259] of AnsiChar;
  width_: Integer;
  btn: Integer;
  description: array[0..LOAD_SAVE_DESCRIPTION_LENGTH - 1] of AnsiChar;
  rc: Integer;
begin
  // Maintain original position in original resolution, otherwise center it.
  if screenGetWidth() <> 640 then
    commentWindowX := (screenGetWidth() - ginfo[LOAD_SAVE_FRM_BOX].width) div 2
  else
    commentWindowX := LS_COMMENT_WINDOW_X;
  if screenGetHeight() <> 480 then
    commentWindowY := (screenGetHeight() - ginfo[LOAD_SAVE_FRM_BOX].height) div 2
  else
    commentWindowY := LS_COMMENT_WINDOW_Y;

  window := win_add(commentWindowX,
      commentWindowY,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      ginfo[LOAD_SAVE_FRM_BOX].height,
      256,
      WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if window = -1 then
  begin
    Result := -1;
    Exit;
  end;

  windowBuffer := win_get_buf(window);
  Move(lsbmp[LOAD_SAVE_FRM_BOX]^, windowBuffer^, ginfo[LOAD_SAVE_FRM_BOX].height * ginfo[LOAD_SAVE_FRM_BOX].width);

  text_font(103);

  // DONE
  msg := getmsg(@lsgame_msgfl, @lsgmesg, 104);
  text_to_buf(windowBuffer + ginfo[LOAD_SAVE_FRM_BOX].width * 57 + 56,
      msg,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      colorTable[18979]);

  // CANCEL
  msg := getmsg(@lsgame_msgfl, @lsgmesg, 105);
  text_to_buf(windowBuffer + ginfo[LOAD_SAVE_FRM_BOX].width * 57 + 181,
      msg,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      colorTable[18979]);

  // DESCRIPTION
  msg := getmsg(@lsgame_msgfl, @lsgmesg, 130);
  StrCopy(@title[0], msg);

  width_ := text_width(@title[0]);
  text_to_buf(windowBuffer + ginfo[LOAD_SAVE_FRM_BOX].width * 7 + (ginfo[LOAD_SAVE_FRM_BOX].width - width_) div 2,
      @title[0],
      ginfo[LOAD_SAVE_FRM_BOX].width,
      ginfo[LOAD_SAVE_FRM_BOX].width,
      colorTable[18979]);

  text_font(101);

  // DONE
  btn := win_register_button(window,
      34, 58,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].height,
      -1, -1, -1, 507,
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_NORMAL],
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn = -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  // CANCEL
  btn := win_register_button(window,
      160, 58,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].width,
      ginfo[LOAD_SAVE_FRM_RED_BUTTON_PRESSED].height,
      -1, -1, -1, 508,
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_NORMAL],
      lsbmp[LOAD_SAVE_FRM_RED_BUTTON_PRESSED],
      nil, BUTTON_FLAG_TRANSPARENT);
  if btn = -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_draw(window);

  if LSstatus[slot_cursor] = SLOT_STATE_OCCUPIED then
    StrLCopy(@description[0], @LSData[a1].description[0], LOAD_SAVE_DESCRIPTION_LENGTH - 1)
  else
    FillChar(description, LOAD_SAVE_DESCRIPTION_LENGTH, 0);

  if get_input_str2(window, 507, 508, @description[0], LOAD_SAVE_DESCRIPTION_LENGTH - 1, 24, 35,
      colorTable[992],
      (lsbmp[LOAD_SAVE_FRM_BOX] + ginfo[1].width * 35 + 24)^,
      0) = 0 then
  begin
    StrLCopy(@LSData[a1].description[0], @description[0], LOAD_SAVE_DESCRIPTION_LENGTH - 1);
    LSData[a1].description[LOAD_SAVE_DESCRIPTION_LENGTH - 1] := #0;
    rc := 1;
  end
  else
    rc := 0;

  win_delete(window);

  Result := rc;
end;

// =========================================================================
// get_input_str2
// =========================================================================
function get_input_str2(win: Integer; doneKeyCode: Integer; cancelKeyCode: Integer;
  description: PAnsiChar; maxLength: Integer; x: Integer; y: Integer;
  textColor: Integer; backgroundColor: Integer; flags: Integer): Integer;
var
  cursorWidth: Integer;
  windowWidth: Integer;
  lineHeight: Integer;
  windowBuffer: PByte;
  text_: array[0..255] of AnsiChar;
  textLength: Integer;
  nameWidth: Integer;
  blinkCounter: Integer;
  blink: Boolean;
  v1: Integer;
  rc: Integer;
  tick: Integer;
  keyCode: Integer;
  color: Integer;
begin
  cursorWidth := text_width('_') - 4;
  windowWidth := win_width(win);
  lineHeight := text_height();
  windowBuffer := win_get_buf(win);
  if maxLength > 255 then
    maxLength := 255;

  StrCopy(@text_[0], description);

  textLength := StrLen(@text_[0]);
  text_[textLength] := ' ';
  text_[textLength + 1] := #0;

  nameWidth := text_width(@text_[0]);

  buf_fill(windowBuffer + windowWidth * y + x, nameWidth, lineHeight, windowWidth, backgroundColor);
  text_to_buf(windowBuffer + windowWidth * y + x, @text_[0], windowWidth, windowWidth, textColor);

  win_draw(win);
  renderPresent();

  beginTextInput();

  blinkCounter := 3;
  blink := False;

  v1 := 0;

  rc := 1;
  while rc = 1 do
  begin
    sharedFpsLimiter.Mark;

    tick := Integer(get_time());

    keyCode := get_input();
    if (keyCode and LongInt($80000000)) = 0 then
      v1 := v1 + 1;

    if (keyCode = doneKeyCode) or (keyCode = KEY_RETURN) then
      rc := 0
    else if (keyCode = cancelKeyCode) or (keyCode = KEY_ESCAPE) then
      rc := -1
    else
    begin
      if ((keyCode = KEY_DELETE) or (keyCode = KEY_BACKSPACE)) and (textLength > 0) then
      begin
        buf_fill(windowBuffer + windowWidth * y + x, text_width(@text_[0]), lineHeight, windowWidth, backgroundColor);

        // TODO: Probably incorrect, needs testing.
        if v1 = 1 then
          textLength := 1;

        text_[textLength - 1] := ' ';
        text_[textLength] := #0;
        text_to_buf(windowBuffer + windowWidth * y + x, @text_[0], windowWidth, windowWidth, textColor);
        textLength := textLength - 1;
      end
      else if (keyCode >= KEY_FIRST_INPUT_CHARACTER) and (keyCode <= KEY_LAST_INPUT_CHARACTER) and (textLength < maxLength) then
      begin
        if (flags and $01) <> 0 then
        begin
          if not isdoschar(keyCode) then
            Break;
        end;

        buf_fill(windowBuffer + windowWidth * y + x, text_width(@text_[0]), lineHeight, windowWidth, backgroundColor);

        text_[textLength] := AnsiChar(keyCode and $FF);
        text_[textLength + 1] := ' ';
        text_[textLength + 2] := #0;
        text_to_buf(windowBuffer + windowWidth * y + x, @text_[0], windowWidth, windowWidth, textColor);
        textLength := textLength + 1;

        win_draw(win);
      end;
    end;

    blinkCounter := blinkCounter - 1;
    if blinkCounter = 0 then
    begin
      blinkCounter := 3;
      blink := not blink;

      if blink then
        color := backgroundColor
      else
        color := textColor;
      buf_fill(windowBuffer + windowWidth * y + x + text_width(@text_[0]) - cursorWidth, cursorWidth, lineHeight - 2, windowWidth, color);
      win_draw(win);
    end;

    while elapsed_time(LongWord(tick)) < 1000 div 24 do begin end;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  endTextInput();

  if rc = 0 then
  begin
    text_[textLength] := #0;
    StrCopy(description, @text_[0]);
  end;

  Result := rc;
end;

// =========================================================================
// DummyFunc
// =========================================================================
function DummyFunc(stream: PDB_FILE): Integer;
begin
  Result := 0;
end;

// =========================================================================
// PrepLoad
// =========================================================================
function PrepLoad(stream: PDB_FILE): Integer;
begin
  game_reset();
  map_data_get_name()^ := #0;
  set_game_time(LongWord(LSData[slot_cursor].gameTime));
  Result := 0;
end;

// =========================================================================
// EndLoad
// =========================================================================
function EndLoad(stream: PDB_FILE): Integer;
begin
  PlayCityMapMusic();
  critter_pc_set_name(@LSData[slot_cursor].characterName[0]);
  intface_redraw();
  refresh_box_bar_win();
  tile_refresh_display();
  if isInCombat() then
    scripts_request_combat(nil);
  Result := 0;
end;

// =========================================================================
// GameMap2Slot
// =========================================================================
function GameMap2Slot(stream: PDB_FILE): Integer;
var
  fileNameList: PPAnsiChar_;
  fileNameListLength: Integer;
  index: Integer;
  str_: PAnsiChar;
  automap_stream: PDB_FILE;
  automap_size: Integer;
begin
  if partyMemberPrepSave() = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if map_save_in_game(False) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\*.%s', [PAnsiChar('MAPS'), PAnsiChar('SAV')]);

  fileNameListLength := db_get_file_list(@str0[0], @fileNameList, nil, 0);
  if fileNameListLength = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_fwriteInt(stream, fileNameListLength) = -1 then
  begin
    db_free_file_list(@fileNameList, nil);
    Result := -1;
    Exit;
  end;

  if fileNameListLength = 0 then
  begin
    db_free_file_list(@fileNameList, nil);
    Result := -1;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);

  if MapDirErase(@gmpath[0], 'SAV') = -1 then
  begin
    db_free_file_list(@fileNameList, nil);
    Result := -1;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  strmfe(@str0[0], 'AUTOMAP.DB', 'SAV');
  libc_strcat(@gmpath[0], @str0[0]);
  compat_remove(@gmpath[0]);

  for index := 0 to fileNameListLength - 1 do
  begin
    str_ := PPAnsiChar_(PByte(fileNameList) + SizeOf(PAnsiChar) * index)^;
    if db_fwrite(str_, StrLen(str_) + 1, 1, stream) = SizeUInt(-1) then
    begin
      db_free_file_list(@fileNameList, nil);
      Result := -1;
      Exit;
    end;

    StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s', [PAnsiChar('MAPS'), str_]);
    StrLFmt(@str1[0], SizeOf(str1) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1, str_]);
    if copy_file(@str0[0], @str1[0]) = -1 then
    begin
      db_free_file_list(@fileNameList, nil);
      Result := -1;
      Exit;
    end;
  end;

  db_free_file_list(@fileNameList, nil);

  strmfe(@str0[0], 'AUTOMAP.DB', 'SAV');
  StrLFmt(@str1[0], SizeOf(str1) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1, PAnsiChar(@str0[0])]);
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s', [PAnsiChar('MAPS'), PAnsiChar('AUTOMAP.DB')]);

  if copy_file(@str0[0], @str1[0]) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s', [PAnsiChar('MAPS'), PAnsiChar('AUTOMAP.DB')]);
  automap_stream := db_fopen(@str0[0], 'rb');
  if automap_stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  automap_size := db_filelength(automap_stream);
  if automap_size = -1 then
  begin
    db_fclose(automap_stream);
    Result := -1;
    Exit;
  end;

  db_fclose(automap_stream);

  if db_fwriteInt(stream, automap_size) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if partyMemberUnPrepSave() = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// SlotMap2Game
// =========================================================================
function SlotMap2Game(stream: PDB_FILE): Integer;
var
  fileNameListLength: Integer;
  index: Integer;
  fileName: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  automapFileName: PAnsiChar;
  saved_automap_size: Integer;
  automap_stream: PDB_FILE;
  automap_size: Integer;
begin
  if db_freadInt(stream, @fileNameListLength) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if fileNameListLength = 0 then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\', [PAnsiChar('MAPS')]);
  if MapDirErase(@str0[0], 'SAV') = -1 then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s\%s', [patches, PAnsiChar('MAPS'), PAnsiChar('AUTOMAP.DB')]);
  compat_remove(@str0[0]);

  for index := 0 to fileNameListLength - 1 do
  begin
    if mygets(@fileName[0], stream) = -1 then
      Break;

    StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1, PAnsiChar(@fileName[0])]);
    StrLFmt(@str1[0], SizeOf(str1) - 1, '%s\%s', [PAnsiChar('MAPS'), PAnsiChar(@fileName[0])]);

    if copy_file(@str0[0], @str1[0]) = -1 then
    begin
      debug_printf('LOADSAVE: returning 7'#10);
      Result := -1;
      Exit;
    end;
  end;

  automapFileName := strmfe(@str1[0], 'AUTOMAP.DB', 'SAV');
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s%.2d\%s', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1, automapFileName]);
  StrLFmt(@str1[0], SizeOf(str1) - 1, '%s\%s', [PAnsiChar('MAPS'), PAnsiChar('AUTOMAP.DB')]);
  if copy_file(@str0[0], @str1[0]) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if db_freadInt(stream, @saved_automap_size) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  automap_stream := db_fopen(@str1[0], 'rb');
  if automap_stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  automap_size := db_filelength(automap_stream);
  if automap_size = -1 then
  begin
    db_fclose(automap_stream);
    Result := -1;
    Exit;
  end;

  db_fclose(automap_stream);
  if saved_automap_size <> automap_size then
  begin
    Result := -1;
    Exit;
  end;

  if map_load_in_game(@LSData[slot_cursor].fileName[0]) = -1 then
  begin
    debug_printf('LOADSAVE: returning 13'#10);
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// mygets
// =========================================================================
function mygets(dest: PAnsiChar; stream: PDB_FILE): Integer;
var
  index: Integer;
  c: Integer;
  p: PAnsiChar;
begin
  index := 14;
  p := dest;
  while True do
  begin
    c := db_fgetc(stream);
    if c = -1 then
    begin
      Result := -1;
      Exit;
    end;

    index := index - 1;

    p^ := AnsiChar(c and $FF);
    p := p + 1;

    if (index = -1) or (c = 0) then
      Break;
  end;

  if index = 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// copy_file
// =========================================================================
function copy_file(const a1: PAnsiChar; const a2: PAnsiChar): Integer;
var
  stream1: PDB_FILE;
  stream2: PDB_FILE;
  length_: Integer;
  chunk_length: Integer;
  buf: Pointer;
  result_: Integer;
begin
  stream1 := nil;
  stream2 := nil;
  buf := nil;
  result_ := -1;

  stream1 := db_fopen(a1, 'rb');
  if stream1 = nil then
  begin
    // goto out
    if stream1 <> nil then db_fclose(stream1);
    if stream2 <> nil then db_fclose(stream2);
    if buf <> nil then mem_free(buf);
    Result := result_;
    Exit;
  end;

  length_ := db_filelength(stream1);
  if length_ = -1 then
  begin
    if stream1 <> nil then db_fclose(stream1);
    if stream2 <> nil then db_fclose(stream2);
    if buf <> nil then mem_free(buf);
    Result := result_;
    Exit;
  end;

  stream2 := db_fopen(a2, 'wb');
  if stream2 = nil then
  begin
    if stream1 <> nil then db_fclose(stream1);
    if stream2 <> nil then db_fclose(stream2);
    if buf <> nil then mem_free(buf);
    Result := result_;
    Exit;
  end;

  buf := mem_malloc($FFFF);
  if buf = nil then
  begin
    if stream1 <> nil then db_fclose(stream1);
    if stream2 <> nil then db_fclose(stream2);
    if buf <> nil then mem_free(buf);
    Result := result_;
    Exit;
  end;

  while length_ <> 0 do
  begin
    if length_ < $FFFF then
      chunk_length := length_
    else
      chunk_length := $FFFF;

    if db_fread(buf, chunk_length, 1, stream1) <> 1 then
      Break;

    if db_fwrite(buf, chunk_length, 1, stream2) <> 1 then
      Break;

    length_ := length_ - chunk_length;
  end;

  if length_ = 0 then
    result_ := 0;

  if stream1 <> nil then db_fclose(stream1);
  if stream2 <> nil then db_fclose(stream2);
  if buf <> nil then mem_free(buf);
  Result := result_;
end;

// =========================================================================
// KillOldMaps
// =========================================================================
procedure KillOldMaps;
begin
  StrLFmt(@str[0], SizeOf(str) - 1, '%s\', [PAnsiChar('MAPS')]);
  MapDirErase(@str[0], 'SAV');
end;

// =========================================================================
// MapDirErase
// =========================================================================
function MapDirErase(const path: PAnsiChar; const a2: PAnsiChar): Integer;
var
  pathBuf: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  fileList: PPAnsiChar_;
  fileListLength: Integer;
begin
  StrLFmt(@pathBuf[0], SizeOf(pathBuf) - 1, '%s*.%s', [path, a2]);

  fileListLength := db_get_file_list(@pathBuf[0], @fileList, nil, 0);
  if fileListLength = -1 then
  begin
    Result := -1;
    Exit;
  end;

  fileListLength := fileListLength - 1;
  while fileListLength >= 0 do
  begin
    StrLFmt(@pathBuf[0], SizeOf(pathBuf) - 1, '%s\%s%s', [patches, path, PPAnsiChar_(PByte(fileList) + SizeOf(PAnsiChar) * fileListLength)^]);
    if compat_remove(@pathBuf[0]) <> 0 then
    begin
      db_free_file_list(@fileList, nil);
      Result := -1;
      Exit;
    end;
    fileListLength := fileListLength - 1;
  end;
  db_free_file_list(@fileList, nil);

  Result := 0;
end;

// =========================================================================
// MapDirEraseFile
// =========================================================================
function MapDirEraseFile(const a1: PAnsiChar; const a2: PAnsiChar): Integer;
var
  pathBuf: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  StrLFmt(@pathBuf[0], SizeOf(pathBuf) - 1, '%s\%s%s', [patches, a1, a2]);
  if compat_remove(@pathBuf[0]) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// SaveBackup
// =========================================================================
function SaveBackup: Integer;
var
  stream1: PDB_FILE;
  stream2: PDB_FILE;
  fileList: PPAnsiChar_;
  fileListLength: Integer;
  index: Integer;
  v1, v2: PAnsiChar;
begin
  debug_printf(PAnsiChar(#10'LOADSAVE: Backing up save slot files..'#10));

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrCopy(@str0[0], @gmpath[0]);

  libc_strcat(@str0[0], 'SAVE.DAT');

  strmfe(@str1[0], @str0[0], 'BAK');

  stream1 := db_fopen(@str0[0], 'rb');
  if stream1 <> nil then
  begin
    db_fclose(stream1);
    if compat_rename(@str0[0], @str1[0]) <> 0 then
    begin
      Result := -1;
      Exit;
    end;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s*.%s', [PAnsiChar(@gmpath[0]), PAnsiChar('SAV')]);

  fileListLength := db_get_file_list(@str0[0], @fileList, nil, 0);
  if fileListLength = -1 then
  begin
    Result := -1;
    Exit;
  end;

  map_backup_count := fileListLength;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  index := fileListLength - 1;
  while index >= 0 do
  begin
    StrCopy(@str0[0], @gmpath[0]);
    libc_strcat(@str0[0], PPAnsiChar_(PByte(fileList) + SizeOf(PAnsiChar) * index)^);

    strmfe(@str1[0], @str0[0], 'BAK');
    if compat_rename(@str0[0], @str1[0]) <> 0 then
    begin
      db_free_file_list(@fileList, nil);
      Result := -1;
      Exit;
    end;
    index := index - 1;
  end;

  db_free_file_list(@fileList, nil);

  debug_printf(PAnsiChar(#10'LOADSAVE: %d map files backed up.'#10), fileListLength);

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);

  v1 := strmfe(@str2[0], 'AUTOMAP.DB', 'SAV');
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s\%s', [PAnsiChar(@gmpath[0]), v1]);

  v2 := strmfe(@str2[0], 'AUTOMAP.DB', 'BAK');
  StrLFmt(@str1[0], SizeOf(str1) - 1, '%s\%s', [PAnsiChar(@gmpath[0]), v2]);

  automap_db_flag := 0;

  stream2 := db_fopen(@str0[0], 'rb');
  if stream2 <> nil then
  begin
    db_fclose(stream2);

    if copy_file(@str0[0], @str1[0]) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    automap_db_flag := 1;
  end;

  Result := 0;
end;

// =========================================================================
// RestoreSave
// =========================================================================
function RestoreSave: Integer;
var
  fileList: PPAnsiChar_;
  fileListLength: Integer;
  index: Integer;
  v1, v2: PAnsiChar;
begin
  debug_printf(PAnsiChar(#10'LOADSAVE: Restoring save file backup...'#10));

  EraseSave();

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrCopy(@str0[0], @gmpath[0]);
  libc_strcat(@str0[0], 'SAVE.DAT');
  strmfe(@str1[0], @str0[0], 'BAK');
  compat_remove(@str0[0]);

  if compat_rename(@str1[0], @str0[0]) <> 0 then
  begin
    EraseSave();
    Result := -1;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s*.%s', [PAnsiChar(@gmpath[0]), PAnsiChar('BAK')]);

  fileListLength := db_get_file_list(@str0[0], @fileList, nil, 0);
  if fileListLength = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if fileListLength <> map_backup_count then
  begin
    // FIXME: Probably leaks fileList.
    EraseSave();
    Result := -1;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);

  index := fileListLength - 1;
  while index >= 0 do
  begin
    StrCopy(@str0[0], @gmpath[0]);
    libc_strcat(@str0[0], PPAnsiChar_(PByte(fileList) + SizeOf(PAnsiChar) * index)^);
    strmfe(@str1[0], @str0[0], 'SAV');
    compat_remove(@str1[0]);
    if compat_rename(@str0[0], @str1[0]) <> 0 then
    begin
      // FIXME: Probably leaks fileList.
      EraseSave();
      Result := -1;
      Exit;
    end;
    index := index - 1;
  end;

  db_free_file_list(@fileList, nil);

  if automap_db_flag = 0 then
  begin
    Result := 0;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  v1 := strmfe(@str2[0], 'AUTOMAP.DB', 'BAK');
  StrCopy(@str0[0], @gmpath[0]);
  libc_strcat(@str0[0], v1);

  v2 := strmfe(@str2[0], 'AUTOMAP.DB', 'SAV');
  StrCopy(@str1[0], @gmpath[0]);
  libc_strcat(@str1[0], v2);

  if compat_rename(@str0[0], @str1[0]) <> 0 then
  begin
    EraseSave();
    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// =========================================================================
// LoadObjDudeCid
// =========================================================================
function LoadObjDudeCid(stream: PDB_FILE): Integer;
var
  value: Integer;
begin
  if db_freadInt(stream, @value) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  obj_dude^.Cid := value;

  Result := 0;
end;

// =========================================================================
// SaveObjDudeCid
// =========================================================================
function SaveObjDudeCid(stream: PDB_FILE): Integer;
begin
  Result := db_fwriteInt(stream, obj_dude^.Cid);
end;

// =========================================================================
// EraseSave
// =========================================================================
function EraseSave: Integer;
var
  fileList: PPAnsiChar_;
  fileListLength: Integer;
  index: Integer;
  v1: PAnsiChar;
begin
  debug_printf(PAnsiChar(#10'LOADSAVE: Erasing save(bad) slot...'#10));

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrCopy(@str0[0], @gmpath[0]);
  libc_strcat(@str0[0], 'SAVE.DAT');
  compat_remove(@str0[0]);

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s%.2d\', [PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  StrLFmt(@str0[0], SizeOf(str0) - 1, '%s*.%s', [PAnsiChar(@gmpath[0]), PAnsiChar('SAV')]);

  fileListLength := db_get_file_list(@str0[0], @fileList, nil, 0);
  if fileListLength = -1 then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);
  index := fileListLength - 1;
  while index >= 0 do
  begin
    StrCopy(@str0[0], @gmpath[0]);
    libc_strcat(@str0[0], PPAnsiChar_(PByte(fileList) + SizeOf(PAnsiChar) * index)^);
    compat_remove(@str0[0]);
    index := index - 1;
  end;

  db_free_file_list(@fileList, nil);

  StrLFmt(@gmpath[0], SizeOf(gmpath) - 1, '%s\%s\%s%.2d\', [patches, PAnsiChar('SAVEGAME'), PAnsiChar('SLOT'), slot_cursor + 1]);

  v1 := strmfe(@str1[0], 'AUTOMAP.DB', 'SAV');
  StrCopy(@str0[0], @gmpath[0]);
  libc_strcat(@str0[0], v1);

  compat_remove(@str0[0]);

  Result := 0;
end;

// =========================================================================
// Initialization
// =========================================================================
initialization
  sharedFpsLimiter := TFpsLimiter.Create(24);

finalization
  sharedFpsLimiter.Free;

end.
