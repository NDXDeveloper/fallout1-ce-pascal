{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/select.h + select.cc
// Premade character selection screen.
unit u_select;

interface

uses
  u_cache, u_object_types;

var
  select_window_id: Integer;

function select_character: Integer;
function select_init: Boolean;

implementation

uses
  SysUtils,
  u_db,
  u_art,
  u_proto_types,
  u_stat_defs,
  u_platform_compat,
  u_debug,
  u_memory,
  u_color,
  u_grbuf,
  u_text,
  u_rect,
  u_gnw,
  u_button,
  u_gnw_types,
  u_input,
  u_mouse,
  u_svga,
  u_fps_limiter,
  u_palette,
  u_stat,
  u_skill,
  u_trait,
  u_object,
  u_critter,
  u_proto,
  u_editor,
  u_options,
  u_game,
  u_message,
  u_gsound;


// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const
  CS_WINDOW_WIDTH  = 640;
  CS_WINDOW_HEIGHT = 480;

  CS_WINDOW_BACKGROUND_X      = 40;
  CS_WINDOW_BACKGROUND_Y      = 30;
  CS_WINDOW_BACKGROUND_WIDTH   = 560;
  CS_WINDOW_BACKGROUND_HEIGHT  = 300;

  CS_WINDOW_PREVIOUS_BUTTON_X = 292;
  CS_WINDOW_PREVIOUS_BUTTON_Y = 320;

  CS_WINDOW_NEXT_BUTTON_X = 318;
  CS_WINDOW_NEXT_BUTTON_Y = 320;

  CS_WINDOW_TAKE_BUTTON_X = 81;
  CS_WINDOW_TAKE_BUTTON_Y = 323;

  CS_WINDOW_MODIFY_BUTTON_X = 435;
  CS_WINDOW_MODIFY_BUTTON_Y = 320;

  CS_WINDOW_CREATE_BUTTON_X = 80;
  CS_WINDOW_CREATE_BUTTON_Y = 425;

  CS_WINDOW_BACK_BUTTON_X = 461;
  CS_WINDOW_BACK_BUTTON_Y = 425;

  CS_WINDOW_NAME_MID_X           = 318;
  CS_WINDOW_PRIMARY_STAT_MID_X   = 348;
  CS_WINDOW_SECONDARY_STAT_MID_X = 365;
  CS_WINDOW_BIO_X                = 420;

  // Key constants
  KEY_MINUS       = $2D;
  KEY_UNDERSCORE  = $5F;
  KEY_EQUAL       = $3D;
  KEY_PLUS        = $2B;
  KEY_ESCAPE      = $1B;
  KEY_UPPERCASE_B = $42;
  KEY_LOWERCASE_B = $62;
  KEY_UPPERCASE_C = $43;
  KEY_LOWERCASE_C = $63;
  KEY_UPPERCASE_M = $4D;
  KEY_LOWERCASE_M = $6D;
  KEY_UPPERCASE_T = $54;
  KEY_LOWERCASE_T = $74;
  KEY_F10         = 324;
  KEY_ARROW_LEFT  = 331;
  KEY_ARROW_RIGHT = 333;

  // PremadeCharacter
  PREMADE_CHARACTER_NARG   = 0;
  PREMADE_CHARACTER_CHITSA = 1;
  PREMADE_CHARACTER_MINGUN = 2;
  PREMADE_CHARACTER_COUNT  = 3;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
type
  TPremadeCharacterDescription = record
    fileName: array[0..19] of AnsiChar;
    face: Integer;
    vid: array[0..19] of AnsiChar;
  end;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
procedure select_exit; forward;
function select_update_display: Boolean; forward;
function select_display_portrait: Boolean; forward;
function select_display_stats: Boolean; forward;
function select_display_bio: Boolean; forward;
function select_fatal_error(rc: Boolean): Boolean; forward;

// ---------------------------------------------------------------------------
// Module-level variables (C++ static globals)
// ---------------------------------------------------------------------------
var
  select_window_buffer: PByte = nil;
  monitor: PByte = nil;
  monitor_rect: TRect;

  previous_button_id: Integer = -1;
  previous_button_up_key: PCacheEntry = nil;
  previous_button_down_key: PCacheEntry = nil;

  next_button_id: Integer = -1;
  next_button_up_key: PCacheEntry = nil;
  next_button_down_key: PCacheEntry = nil;

  take_button_id: Integer = -1;
  take_button_up_key: PCacheEntry = nil;
  take_button_down_key: PCacheEntry = nil;

  modify_button_id: Integer = -1;
  modify_button_up_key: PCacheEntry = nil;
  modify_button_down_key: PCacheEntry = nil;

  create_button_id: Integer = -1;
  create_button_up_key: PCacheEntry = nil;
  create_button_down_key: PCacheEntry = nil;

  back_button_id: Integer = -1;
  back_button_up_key: PCacheEntry = nil;
  back_button_down_key: PCacheEntry = nil;

  premade_index: Integer = PREMADE_CHARACTER_NARG;

  premade_characters: array[0..PREMADE_CHARACTER_COUNT - 1] of TPremadeCharacterDescription;

  premade_total: Integer = PREMADE_CHARACTER_COUNT;

  // Uninitialized bss pointers for button graphics
  take_button_up_data: PByte;
  modify_button_down_data: PByte;
  back_button_up_data: PByte;
  create_button_up_data: PByte;
  modify_button_up_data: PByte;
  back_button_down_data: PByte;
  create_button_down_data: PByte;
  take_button_down_data: PByte;
  next_button_down_data: PByte;
  next_button_up_data: PByte;
  previous_button_up_data: PByte;
  previous_button_down_data: PByte;

// ---------------------------------------------------------------------------
// Helper to initialize premade character data
// ---------------------------------------------------------------------------
procedure InitPremadeCharacters;
begin
  FillChar(premade_characters, SizeOf(premade_characters), 0);

  StrCopy(@premade_characters[0].fileName[0], 'premade\combat');
  premade_characters[0].face := 201;
  StrCopy(@premade_characters[0].vid[0], 'VID 208-197-88-125');

  StrCopy(@premade_characters[1].fileName[0], 'premade\stealth');
  premade_characters[1].face := 202;
  StrCopy(@premade_characters[1].vid[0], 'VID 208-206-49-229');

  StrCopy(@premade_characters[2].fileName[0], 'premade\diplomat');
  premade_characters[2].face := 203;
  StrCopy(@premade_characters[2].vid[0], 'VID 208-206-49-227');
end;

// ---------------------------------------------------------------------------
// 0x495260
// select_character
// ---------------------------------------------------------------------------
function select_character: Integer;
var
  cursorWasHidden: Boolean;
  rc: Integer;
  done: Boolean;
  keyCode: Integer;
begin
  if not select_init then
  begin
    Result := 0;
    Exit;
  end;

  cursorWasHidden := mouse_hidden;
  if cursorWasHidden then
    mouse_show;

  loadColorTable('color.pal');
  palette_fade_to(@cmap[0]);

  rc := 0;
  done := False;
  while not done do
  begin
    sharedFpsLimiter.Mark;

    if game_user_wants_to_quit <> 0 then
      Break;

    keyCode := get_input;

    case keyCode of
      KEY_MINUS,
      KEY_UNDERSCORE:
        DecGamma;

      KEY_EQUAL,
      KEY_PLUS:
        IncGamma;

      KEY_UPPERCASE_B,
      KEY_LOWERCASE_B,
      KEY_ESCAPE:
      begin
        rc := 3;
        done := True;
      end;

      KEY_UPPERCASE_C,
      KEY_LOWERCASE_C:
      begin
        ResetPlayer;
        if editor_design(True) = 0 then
        begin
          rc := 2;
          done := True;
        end
        else
          select_update_display;
      end;

      KEY_UPPERCASE_M,
      KEY_LOWERCASE_M:
      begin
        if editor_design(True) = 0 then
        begin
          rc := 2;
          done := True;
        end
        else
          select_update_display;
      end;

      KEY_UPPERCASE_T,
      KEY_LOWERCASE_T:
      begin
        rc := 2;
        done := True;
      end;

      KEY_F10:
        game_quit_with_confirm;

      KEY_ARROW_LEFT:
      begin
        gsound_play_sfx_file('ib2p1xx1');
        premade_index := premade_index - 1;
        if premade_index < 0 then
          premade_index := premade_total - 1;
        select_update_display;
      end;

      500:
      begin
        premade_index := premade_index - 1;
        if premade_index < 0 then
          premade_index := premade_total - 1;
        select_update_display;
      end;

      KEY_ARROW_RIGHT:
      begin
        gsound_play_sfx_file('ib2p1xx1');
        premade_index := premade_index + 1;
        if premade_index >= premade_total then
          premade_index := 0;
        select_update_display;
      end;

      501:
      begin
        premade_index := premade_index + 1;
        if premade_index >= premade_total then
          premade_index := 0;
        select_update_display;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  palette_fade_to(@black_palette[0]);
  select_exit;

  if cursorWasHidden then
    mouse_hide;

  Result := rc;
end;

// ---------------------------------------------------------------------------
// 0x4954F8
// select_init
// ---------------------------------------------------------------------------
function select_init: Boolean;
var
  backgroundFid: Integer;
  backgroundFrmData: PByte;
  backgroundFrmHandle: PCacheEntry;
  characterSelectorWindowX: Integer;
  characterSelectorWindowY: Integer;
  fid: Integer;
begin
  InitPremadeCharacters;

  if select_window_id <> -1 then
  begin
    Result := False;
    Exit;
  end;

  characterSelectorWindowX := (screenGetWidth - CS_WINDOW_WIDTH) div 2;
  characterSelectorWindowY := (screenGetHeight - CS_WINDOW_HEIGHT) div 2;
  select_window_id := win_add(characterSelectorWindowX, characterSelectorWindowY,
    CS_WINDOW_WIDTH, CS_WINDOW_HEIGHT, colorTable[0], 0);
  if select_window_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  select_window_buffer := win_get_buf(select_window_id);
  if select_window_buffer = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  backgroundFid := art_id(OBJ_TYPE_INTERFACE, 174, 0, 0, 0);
  backgroundFrmData := art_ptr_lock_data(backgroundFid, 0, 0, @backgroundFrmHandle);
  if backgroundFrmData = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  buf_to_buf(backgroundFrmData,
    CS_WINDOW_WIDTH,
    CS_WINDOW_HEIGHT,
    CS_WINDOW_WIDTH,
    select_window_buffer,
    CS_WINDOW_WIDTH);

  monitor := PByte(mem_malloc(CS_WINDOW_BACKGROUND_WIDTH * CS_WINDOW_BACKGROUND_HEIGHT));
  if monitor = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  buf_to_buf(backgroundFrmData + CS_WINDOW_WIDTH * CS_WINDOW_BACKGROUND_Y + CS_WINDOW_BACKGROUND_X,
    CS_WINDOW_BACKGROUND_WIDTH,
    CS_WINDOW_BACKGROUND_HEIGHT,
    CS_WINDOW_WIDTH,
    monitor,
    CS_WINDOW_BACKGROUND_WIDTH);

  art_ptr_unlock(backgroundFrmHandle);

  // Setup "Previous" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 122, 0, 0, 0);
  previous_button_up_data := art_ptr_lock_data(fid, 0, 0, @previous_button_up_key);
  if previous_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 123, 0, 0, 0);
  previous_button_down_data := art_ptr_lock_data(fid, 0, 0, @previous_button_down_key);
  if previous_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  previous_button_id := win_register_button(select_window_id,
    CS_WINDOW_PREVIOUS_BUTTON_X,
    CS_WINDOW_PREVIOUS_BUTTON_Y,
    20,
    18,
    -1,
    -1,
    -1,
    500,
    previous_button_up_data,
    previous_button_down_data,
    nil,
    0);
  if previous_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(previous_button_id, @gsound_med_butt_press, @gsound_med_butt_release);

  // Setup "Next" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 124, 0, 0, 0);
  next_button_up_data := art_ptr_lock_data(fid, 0, 0, @next_button_up_key);
  if next_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 125, 0, 0, 0);
  next_button_down_data := art_ptr_lock_data(fid, 0, 0, @next_button_down_key);
  if next_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  next_button_id := win_register_button(select_window_id,
    CS_WINDOW_NEXT_BUTTON_X,
    CS_WINDOW_NEXT_BUTTON_Y,
    20,
    18,
    -1,
    -1,
    -1,
    501,
    next_button_up_data,
    next_button_down_data,
    nil,
    0);
  if next_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(next_button_id, @gsound_med_butt_press, @gsound_med_butt_release);

  // Setup "Take" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  take_button_up_data := art_ptr_lock_data(fid, 0, 0, @take_button_up_key);
  if take_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  take_button_down_data := art_ptr_lock_data(fid, 0, 0, @take_button_down_key);
  if take_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  take_button_id := win_register_button(select_window_id,
    CS_WINDOW_TAKE_BUTTON_X,
    CS_WINDOW_TAKE_BUTTON_Y,
    15,
    16,
    -1,
    -1,
    -1,
    KEY_LOWERCASE_T,
    take_button_up_data,
    take_button_down_data,
    nil,
    BUTTON_FLAG_TRANSPARENT);
  if take_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(take_button_id, @gsound_red_butt_press, @gsound_red_butt_release);

  // Setup "Modify" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  modify_button_up_data := art_ptr_lock_data(fid, 0, 0, @modify_button_up_key);
  if modify_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  modify_button_down_data := art_ptr_lock_data(fid, 0, 0, @modify_button_down_key);
  if modify_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  modify_button_id := win_register_button(select_window_id,
    CS_WINDOW_MODIFY_BUTTON_X,
    CS_WINDOW_MODIFY_BUTTON_Y,
    15,
    16,
    -1,
    -1,
    -1,
    KEY_LOWERCASE_M,
    modify_button_up_data,
    modify_button_down_data,
    nil,
    BUTTON_FLAG_TRANSPARENT);
  if modify_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(modify_button_id, @gsound_red_butt_press, @gsound_red_butt_release);

  // Setup "Create" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  create_button_up_data := art_ptr_lock_data(fid, 0, 0, @create_button_up_key);
  if create_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  create_button_down_data := art_ptr_lock_data(fid, 0, 0, @create_button_down_key);
  if create_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  create_button_id := win_register_button(select_window_id,
    CS_WINDOW_CREATE_BUTTON_X,
    CS_WINDOW_CREATE_BUTTON_Y,
    15,
    16,
    -1,
    -1,
    -1,
    KEY_LOWERCASE_C,
    create_button_up_data,
    create_button_down_data,
    nil,
    BUTTON_FLAG_TRANSPARENT);
  if create_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(create_button_id, @gsound_red_butt_press, @gsound_red_butt_release);

  // Setup "Back" button.
  fid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
  back_button_up_data := art_ptr_lock_data(fid, 0, 0, @back_button_up_key);
  if back_button_up_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
  back_button_down_data := art_ptr_lock_data(fid, 0, 0, @back_button_down_key);
  if back_button_down_data = nil then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  back_button_id := win_register_button(select_window_id,
    CS_WINDOW_BACK_BUTTON_X,
    CS_WINDOW_BACK_BUTTON_Y,
    15,
    16,
    -1,
    -1,
    -1,
    KEY_ESCAPE,
    back_button_up_data,
    back_button_down_data,
    nil,
    BUTTON_FLAG_TRANSPARENT);
  if back_button_id = -1 then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  win_register_button_sound_func(back_button_id, @gsound_red_butt_press, @gsound_red_butt_release);

  premade_index := PREMADE_CHARACTER_NARG;

  win_draw(select_window_id);

  if not select_update_display then
  begin
    Result := select_fatal_error(False);
    Exit;
  end;

  Result := True;
end;

// ---------------------------------------------------------------------------
// 0x495B64
// select_exit
// ---------------------------------------------------------------------------
procedure select_exit;
begin
  if select_window_id = -1 then
    Exit;

  if previous_button_id <> -1 then
  begin
    win_delete_button(previous_button_id);
    previous_button_id := -1;
  end;

  if previous_button_down_data <> nil then
  begin
    art_ptr_unlock(previous_button_down_key);
    previous_button_down_key := nil;
    previous_button_down_data := nil;
  end;

  if previous_button_up_data <> nil then
  begin
    art_ptr_unlock(previous_button_up_key);
    previous_button_up_key := nil;
    previous_button_up_data := nil;
  end;

  if next_button_id <> -1 then
  begin
    win_delete_button(next_button_id);
    next_button_id := -1;
  end;

  if next_button_down_data <> nil then
  begin
    art_ptr_unlock(next_button_down_key);
    next_button_down_key := nil;
    next_button_down_data := nil;
  end;

  if next_button_up_data <> nil then
  begin
    art_ptr_unlock(next_button_up_key);
    next_button_up_key := nil;
    next_button_up_data := nil;
  end;

  if take_button_id <> -1 then
  begin
    win_delete_button(take_button_id);
    take_button_id := -1;
  end;

  if take_button_down_data <> nil then
  begin
    art_ptr_unlock(take_button_down_key);
    take_button_down_key := nil;
    take_button_down_data := nil;
  end;

  if take_button_up_data <> nil then
  begin
    art_ptr_unlock(take_button_up_key);
    take_button_up_key := nil;
    take_button_up_data := nil;
  end;

  if modify_button_id <> -1 then
  begin
    win_delete_button(modify_button_id);
    modify_button_id := -1;
  end;

  if modify_button_down_data <> nil then
  begin
    art_ptr_unlock(modify_button_down_key);
    modify_button_down_key := nil;
    modify_button_down_data := nil;
  end;

  if modify_button_up_data <> nil then
  begin
    art_ptr_unlock(modify_button_up_key);
    modify_button_up_key := nil;
    modify_button_up_data := nil;
  end;

  if create_button_id <> -1 then
  begin
    win_delete_button(create_button_id);
    create_button_id := -1;
  end;

  if create_button_down_data <> nil then
  begin
    art_ptr_unlock(create_button_down_key);
    create_button_down_key := nil;
    create_button_down_data := nil;
  end;

  if create_button_up_data <> nil then
  begin
    art_ptr_unlock(create_button_up_key);
    create_button_up_key := nil;
    create_button_up_data := nil;
  end;

  if back_button_id <> -1 then
  begin
    win_delete_button(back_button_id);
    back_button_id := -1;
  end;

  if back_button_down_data <> nil then
  begin
    art_ptr_unlock(back_button_down_key);
    back_button_down_key := nil;
    back_button_down_data := nil;
  end;

  if back_button_up_data <> nil then
  begin
    art_ptr_unlock(back_button_up_key);
    back_button_up_key := nil;
    back_button_up_data := nil;
  end;

  if monitor <> nil then
  begin
    mem_free(monitor);
    monitor := nil;
  end;

  win_delete(select_window_id);
  select_window_id := -1;
end;

// ---------------------------------------------------------------------------
// 0x495DE8
// select_update_display
// ---------------------------------------------------------------------------
function select_update_display: Boolean;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  success: Boolean;
begin
  StrLFmt(@path[0], SizeOf(path) - 1, '%s.gcd',
    [PAnsiChar(@premade_characters[premade_index].fileName[0])]);

  if proto_dude_init(@path[0]) = -1 then
  begin
    debug_printf(#10' ** Error in dude init! **'#10);
    Result := False;
    Exit;
  end;

  buf_to_buf(monitor,
    CS_WINDOW_BACKGROUND_WIDTH,
    CS_WINDOW_BACKGROUND_HEIGHT,
    CS_WINDOW_BACKGROUND_WIDTH,
    select_window_buffer + CS_WINDOW_WIDTH * CS_WINDOW_BACKGROUND_Y + CS_WINDOW_BACKGROUND_X,
    CS_WINDOW_WIDTH);

  success := False;
  if select_display_portrait then
  begin
    if select_display_stats then
      success := select_display_bio;
  end;

  win_draw_rect(select_window_id, @monitor_rect);

  Result := success;
end;

// ---------------------------------------------------------------------------
// 0x495E9C
// select_display_portrait
// ---------------------------------------------------------------------------
function select_display_portrait: Boolean;
var
  old_font: Integer;
  id_width: Integer;
  success: Boolean;
  faceFrmHandle: PCacheEntry;
  faceFid: Integer;
  frm: PArt;
  data: PByte;
  width, height: Integer;
  y: Integer;
begin
  success := False;

  faceFid := art_id(OBJ_TYPE_INTERFACE, premade_characters[premade_index].face, 0, 0, 0);
  frm := art_ptr_lock(faceFid, @faceFrmHandle);
  if frm <> nil then
  begin
    data := art_frame_data(frm, 0, 0);
    if data <> nil then
    begin
      width := art_frame_width(frm, 0, 0);
      height := art_frame_length(frm, 0, 0);

      y := 1;
      while y < height do
      begin
        FillChar((data + y * width)^, width, 0);
        y := y + 2;
      end;

      trans_buf_to_buf(data,
        width,
        height,
        width,
        select_window_buffer + CS_WINDOW_WIDTH * (240 - height) + 150 - (width div 2),
        CS_WINDOW_WIDTH);

      old_font := text_curr;
      text_font(101);

      id_width := text_width(@premade_characters[premade_index].vid[0]);
      text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * 252 + 150 - id_width div 2,
        @premade_characters[premade_index].vid[0],
        id_width,
        CS_WINDOW_WIDTH,
        colorTable[992]);

      text_font(old_font);

      success := True;
    end;
    art_ptr_unlock(faceFrmHandle);
  end;

  Result := success;
end;

// ---------------------------------------------------------------------------
// 0x49602C
// select_display_stats
// ---------------------------------------------------------------------------
function select_display_stats: Boolean;
var
  str: PAnsiChar;
  text: array[0..259] of AnsiChar;
  length_: Integer;
  value: Integer;
  messageListItem: TMessageListItem;
  oldFont: Integer;
  vh: Integer;
  y: Integer;
  skills: array[0..DEFAULT_TAGGED_SKILLS - 1] of Integer;
  traits: array[0..PC_TRAIT_MAX - 1] of Integer;
  idx: Integer;
begin
  oldFont := text_curr;
  text_font(101);

  text_char_width(' ');

  vh := text_height();
  y := 40;

  // NAME
  str := object_name(obj_dude);
  StrCopy(@text[0], str);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_NAME_MID_X - (length_ div 2),
    @text[0], 160, CS_WINDOW_WIDTH, colorTable[992]);

  // STRENGTH
  y := y + vh + vh + vh;

  value := stat_level(obj_dude, Integer(STAT_STRENGTH));
  str := stat_name(Integer(STAT_STRENGTH));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // PERCEPTION
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_PERCEPTION));
  str := stat_name(Integer(STAT_PERCEPTION));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // ENDURANCE
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_ENDURANCE));
  str := stat_name(Integer(STAT_ENDURANCE));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // CHARISMA
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_CHARISMA));
  str := stat_name(Integer(STAT_CHARISMA));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // INTELLIGENCE
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_INTELLIGENCE));
  str := stat_name(Integer(STAT_INTELLIGENCE));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // AGILITY
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_AGILITY));
  str := stat_name(Integer(STAT_AGILITY));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // LUCK
  y := y + vh;

  value := stat_level(obj_dude, Integer(STAT_LUCK));
  str := stat_name(Integer(STAT_LUCK));

  StrLFmt(@text[0], SizeOf(text) - 1, '%s %02d', [str, value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  str := stat_level_description(value);
  StrLFmt(@text[0], SizeOf(text) - 1, '  %s', [str]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_PRIMARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  y := y + vh; // blank line

  // HIT POINTS
  y := y + vh;

  messageListItem.num := 16;
  text[0] := #0;
  if message_search(@misc_message_file, @messageListItem) then
    StrCopy(@text[0], messageListItem.text);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  value := stat_level(obj_dude, Integer(STAT_MAXIMUM_HIT_POINTS));
  StrLFmt(@text[0], SizeOf(text) - 1, ' %d/%d', [critter_get_hits(obj_dude), value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // ARMOR CLASS
  y := y + vh;

  str := stat_name(Integer(STAT_ARMOR_CLASS));
  StrCopy(@text[0], str);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  value := stat_level(obj_dude, Integer(STAT_ARMOR_CLASS));
  StrLFmt(@text[0], SizeOf(text) - 1, ' %d', [value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // ACTION POINTS
  y := y + vh;

  messageListItem.num := 15;
  text[0] := #0;
  if message_search(@misc_message_file, @messageListItem) then
    StrCopy(@text[0], messageListItem.text);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  value := stat_level(obj_dude, Integer(STAT_MAXIMUM_ACTION_POINTS));
  StrLFmt(@text[0], SizeOf(text) - 1, ' %d', [value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  // MELEE DAMAGE
  y := y + vh;

  str := stat_name(Integer(STAT_MELEE_DAMAGE));
  StrCopy(@text[0], str);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  value := stat_level(obj_dude, Integer(STAT_MELEE_DAMAGE));
  StrLFmt(@text[0], SizeOf(text) - 1, ' %d', [value]);

  length_ := text_width(@text[0]);
  text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X,
    @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

  y := y + vh; // blank line

  // SKILLS
  skill_get_tags(@skills[0], DEFAULT_TAGGED_SKILLS);

  for idx := 0 to DEFAULT_TAGGED_SKILLS - 1 do
  begin
    y := y + vh;

    str := skill_name(skills[idx]);
    StrCopy(@text[0], str);

    length_ := text_width(@text[0]);
    text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
      @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);

    value := skill_level(obj_dude, skills[idx]);
    StrLFmt(@text[0], SizeOf(text) - 1, ' %d%%', [value]);

    length_ := text_width(@text[0]);
    text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X,
      @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);
  end;

  // TRAITS
  trait_get(@traits[0], @traits[1]);

  for idx := 0 to PC_TRAIT_MAX - 1 do
  begin
    y := y + vh;

    str := trait_name(traits[idx]);
    StrCopy(@text[0], str);

    length_ := text_width(@text[0]);
    text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_SECONDARY_STAT_MID_X - length_,
      @text[0], length_, CS_WINDOW_WIDTH, colorTable[992]);
  end;

  text_font(oldFont);

  Result := True;
end;

// ---------------------------------------------------------------------------
// 0x496C60
// select_display_bio
// ---------------------------------------------------------------------------
function select_display_bio: Boolean;
var
  oldFont: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  y: Integer;
  lineHeight: Integer;
  str_buf: array[0..255] of AnsiChar;
begin
  oldFont := text_curr;
  text_font(101);

  StrLFmt(@path[0], SizeOf(path) - 1, '%s.bio',
    [PAnsiChar(@premade_characters[premade_index].fileName[0])]);

  stream := db_fopen(@path[0], 'rt');
  if stream <> nil then
  begin
    y := 40;
    lineHeight := text_height();

    while (db_fgets(@str_buf[0], 256, stream) <> nil) and (y < 260) do
    begin
      text_to_buf(select_window_buffer + CS_WINDOW_WIDTH * y + CS_WINDOW_BIO_X,
        @str_buf[0],
        CS_WINDOW_WIDTH - CS_WINDOW_BIO_X,
        CS_WINDOW_WIDTH,
        colorTable[992]);
      y := y + lineHeight;
    end;

    db_fclose(stream);
  end;

  text_font(oldFont);

  Result := True;
end;

// ---------------------------------------------------------------------------
// 0x496D4C
// select_fatal_error
// ---------------------------------------------------------------------------
function select_fatal_error(rc: Boolean): Boolean;
begin
  select_exit;
  Result := rc;
end;

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------
initialization
  select_window_id := -1;
  monitor_rect.ulx := 40;
  monitor_rect.uly := 30;
  monitor_rect.lrx := 599;
  monitor_rect.lry := 329;

end.
