unit u_mainmenu;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  MAIN_MENU_INTRO       = 0;
  MAIN_MENU_NEW_GAME    = 1;
  MAIN_MENU_LOAD_GAME   = 2;
  MAIN_MENU_SCREENSAVER = 3;
  MAIN_MENU_TIMEOUT     = 4;
  MAIN_MENU_CREDITS     = 5;
  MAIN_MENU_QUOTES      = 6;
  MAIN_MENU_EXIT        = 7;
  MAIN_MENU_SELFRUN     = 8;
  MAIN_MENU_OPTIONS     = 9;

var
  in_main_menu: Boolean;

function main_menu_create: Integer;
procedure main_menu_destroy;
procedure main_menu_hide(animate: Boolean);
procedure main_menu_show(animate: Boolean);
function main_menu_is_shown: Integer;
function main_menu_is_enabled: Integer;
procedure main_menu_set_timeout(timeout: LongWord);
function main_menu_get_timeout: LongWord;
function main_menu_loop: Integer;

implementation

uses
  SysUtils,
  u_cache,
  u_gnw, u_button, u_text, u_input, u_mouse, u_grbuf, u_svga, u_color,
  u_palette, u_art, u_version, u_message, u_gsound, u_int_sound,
  u_options, u_game, u_kb;

const
  MAIN_MENU_WINDOW_WIDTH  = 640;
  MAIN_MENU_WINDOW_HEIGHT = 480;

  MAIN_MENU_BUTTON_INTRO    = 0;
  MAIN_MENU_BUTTON_NEW_GAME = 1;
  MAIN_MENU_BUTTON_LOAD_GAME = 2;
  MAIN_MENU_BUTTON_CREDITS  = 3;
  MAIN_MENU_BUTTON_EXIT     = 4;
  MAIN_MENU_BUTTON_COUNT    = 5;

  VERSION_MAX   = 32;

  WINDOW_HIDDEN      = $08;
  WINDOW_MOVE_ON_TOP = $04;

  BUTTON_FLAG_TRANSPARENT = $20;

  KEY_ESCAPE      = $1B;
  KEY_PLUS        = $2B;
  KEY_MINUS       = $2D;
  KEY_EQUAL       = $3D;
  KEY_UNDERSCORE  = $5F;
  KEY_UPPERCASE_D = $44;
  KEY_LOWERCASE_D = $64;
  KEY_LOWERCASE_I = $69;
  KEY_LOWERCASE_N = $6E;
  KEY_LOWERCASE_L = $6C;
  KEY_LOWERCASE_C = $63;
  KEY_LOWERCASE_E = $65;
  KEY_CTRL_R      = 18;

  KEY_STATE_UP = 0;

  MOUSE_EVENT_LEFT_BUTTON_REPEAT = $04;

  SDL_NUM_SCANCODES    = 512;
  SDL_SCANCODE_LSHIFT  = 225;
  SDL_SCANCODE_RSHIFT  = 229;

  OBJ_TYPE_INTERFACE_VAL = 6;

type
  // FPS limiter stub
  TFpsLimiter = record
    dummy: Integer;
  end;

// Module-level (static) variables
var
  main_window: Integer = -1;
  main_window_buf: PByte = nil;
  background_data: PByte = nil;
  button_up_data: PByte = nil;
  button_down_data: PByte = nil;
  main_menu_created: Boolean = False;
  main_menu_timeout_ms: LongWord = 120000;

  button_values: array[0..MAIN_MENU_BUTTON_COUNT - 1] of Integer = (
    KEY_LOWERCASE_I,
    KEY_LOWERCASE_N,
    KEY_LOWERCASE_L,
    KEY_LOWERCASE_C,
    KEY_LOWERCASE_E
  );

  return_values: array[0..MAIN_MENU_BUTTON_COUNT - 1] of Integer = (
    MAIN_MENU_INTRO,
    MAIN_MENU_NEW_GAME,
    MAIN_MENU_LOAD_GAME,
    MAIN_MENU_CREDITS,
    MAIN_MENU_EXIT
  );

  buttons: array[0..MAIN_MENU_BUTTON_COUNT - 1] of Integer;
  main_menu_is_hidden_flag: Boolean;
  button_up_key: PCacheEntry;
  button_down_key: PCacheEntry;
  background_key: PCacheEntry;

  sharedFpsLimiter: TFpsLimiter;

// Forward declarations
function main_menu_fatal_error: Integer; forward;
procedure main_menu_play_sound(fileName: PAnsiChar); forward;

// FPS limiter stubs
procedure FpsLimiter_mark(var limiter: TFpsLimiter);
begin
  // stub
end;

procedure FpsLimiter_throttle(var limiter: TFpsLimiter);
begin
  // stub
end;

// Helper: toupper for ASCII
function char_toupper(c: Integer): Integer;
begin
  if (c >= Ord('a')) and (c <= Ord('z')) then
    Result := c - 32
  else
    Result := c;
end;

// 0x472F80
function main_menu_create: Integer;
var
  fid: Integer;
  msg: TMessageListItem;
  len: Integer;
  mainMenuWindowX: Integer;
  mainMenuWindowY: Integer;
  backgroundFid: Integer;
  oldFont: Integer;
  version: array[0..VERSION_MAX - 1] of AnsiChar;
  index: Integer;
begin
  if main_menu_created then
  begin
    Result := 0;
    Exit;
  end;

  loadColorTable('color.pal');

  mainMenuWindowX := (screenGetWidth() - MAIN_MENU_WINDOW_WIDTH) div 2;
  mainMenuWindowY := (screenGetHeight() - MAIN_MENU_WINDOW_HEIGHT) div 2;
  main_window := win_add(mainMenuWindowX,
    mainMenuWindowY,
    MAIN_MENU_WINDOW_WIDTH,
    MAIN_MENU_WINDOW_HEIGHT,
    0,
    WINDOW_HIDDEN or WINDOW_MOVE_ON_TOP);
  if main_window = -1 then
  begin
    // NOTE: Uninline.
    Result := main_menu_fatal_error();
    Exit;
  end;

  main_window_buf := win_get_buf(main_window);

  // mainmenu.frm
  backgroundFid := art_id(OBJ_TYPE_INTERFACE_VAL, 140, 0, 0, 0);
  background_data := art_ptr_lock_data(backgroundFid, 0, 0, @background_key);
  if background_data = nil then
  begin
    // NOTE: Uninline.
    Result := main_menu_fatal_error();
    Exit;
  end;

  buf_to_buf(background_data, MAIN_MENU_WINDOW_WIDTH,
    MAIN_MENU_WINDOW_HEIGHT,
    MAIN_MENU_WINDOW_WIDTH,
    main_window_buf,
    MAIN_MENU_WINDOW_WIDTH);
  art_ptr_unlock(background_key);

  oldFont := text_curr();
  text_font(100);

  // Copyright.
  msg.num := 14;
  if message_search(@misc_message_file, @msg) then
  begin
    win_print(main_window, msg.text, 0, 15, 460, colorTable[21204] or $4000000 or $2000000);
  end;

  // Version.
  getverstr(version, SizeOf(version));
  len := text_width(version);
  win_print(main_window, version, 0, 615 - len, 460, colorTable[21204] or $4000000 or $2000000);

  // menuup.frm
  fid := art_id(OBJ_TYPE_INTERFACE_VAL, 299, 0, 0, 0);
  button_up_data := art_ptr_lock_data(fid, 0, 0, @button_up_key);
  if button_up_data = nil then
  begin
    // NOTE: Uninline.
    Result := main_menu_fatal_error();
    Exit;
  end;

  // menudown.frm
  fid := art_id(OBJ_TYPE_INTERFACE_VAL, 300, 0, 0, 0);
  button_down_data := art_ptr_lock_data(fid, 0, 0, @button_down_key);
  if button_down_data = nil then
  begin
    // NOTE: Uninline.
    Result := main_menu_fatal_error();
    Exit;
  end;

  for index := 0 to MAIN_MENU_BUTTON_COUNT - 1 do
    buttons[index] := -1;

  for index := 0 to MAIN_MENU_BUTTON_COUNT - 1 do
  begin
    buttons[index] := win_register_button(main_window,
      425,
      index * 42 - index + 45,
      26,
      26,
      -1,
      -1,
      1111,
      button_values[index],
      button_up_data,
      button_down_data,
      nil,
      BUTTON_FLAG_TRANSPARENT);
    if buttons[index] = -1 then
    begin
      // NOTE: Uninline.
      Result := main_menu_fatal_error();
      Exit;
    end;

    win_register_button_mask(buttons[index], button_up_data);
  end;

  text_font(104);

  for index := 0 to MAIN_MENU_BUTTON_COUNT - 1 do
  begin
    msg.num := 9 + index;
    if message_search(@misc_message_file, @msg) then
    begin
      len := text_width(msg.text);
      text_to_buf(main_window_buf + MAIN_MENU_WINDOW_WIDTH * (42 * index - index + 46) + 520 - (len div 2),
        msg.text,
        MAIN_MENU_WINDOW_WIDTH - (520 - (len div 2)) - 1,
        MAIN_MENU_WINDOW_WIDTH,
        colorTable[21091]);
    end;
  end;

  text_font(oldFont);

  main_menu_created := True;
  main_menu_is_hidden_flag := True;

  Result := 0;
end;

// 0x473298
procedure main_menu_destroy;
var
  index: Integer;
begin
  if not main_menu_created then
    Exit;

  for index := 0 to MAIN_MENU_BUTTON_COUNT - 1 do
  begin
    // FIXME: Why it tries to free only invalid buttons?
    if buttons[index] = -1 then
      win_delete_button(buttons[index]);
  end;

  if button_down_data <> nil then
  begin
    art_ptr_unlock(button_down_key);
    button_down_key := nil;
    button_down_data := nil;
  end;

  if button_up_data <> nil then
  begin
    art_ptr_unlock(button_up_key);
    button_up_key := nil;
    button_up_data := nil;
  end;

  if main_window <> -1 then
    win_delete(main_window);

  main_menu_created := False;
end;

// 0x473330
procedure main_menu_hide(animate: Boolean);
begin
  if not main_menu_created then
    Exit;

  if main_menu_is_hidden_flag then
    Exit;

  soundUpdate();

  if animate then
  begin
    palette_fade_to(@black_palette[0]);
    soundUpdate();
  end;

  win_hide(main_window);

  main_menu_is_hidden_flag := True;
end;

// 0x473378
procedure main_menu_show(animate: Boolean);
begin
  if not main_menu_created then
    Exit;

  if not main_menu_is_hidden_flag then
    Exit;

  win_show(main_window);

  if animate then
  begin
    loadColorTable('color.pal');
    palette_fade_to(@cmap[0]);
  end;

  main_menu_is_hidden_flag := False;
end;

// 0x4733BC
function main_menu_is_shown: Integer;
begin
  if main_menu_created then
  begin
    if main_menu_is_hidden_flag then
      Result := 0
    else
      Result := 1;
  end
  else
    Result := 0;
end;

// 0x4733D8
function main_menu_is_enabled: Integer;
begin
  Result := 1;
end;

// 0x4733E0
procedure main_menu_set_timeout(timeout: LongWord);
begin
  main_menu_timeout_ms := 60000 * timeout;
end;

// 0x473400
function main_menu_get_timeout: LongWord;
begin
  Result := main_menu_timeout_ms div 1000 div 60;
end;

// 0x47341C
function main_menu_loop: Integer;
var
  oldCursorIsHidden: Boolean;
  tick: LongWord;
  rc: Integer;
  keyCode: Integer;
  buttonIndex: Integer;
  found: Boolean;
begin
  in_main_menu := True;

  oldCursorIsHidden := mouse_hidden();
  if oldCursorIsHidden then
    mouse_show();

  tick := get_time();

  rc := -1;
  while rc = -1 do
  begin
    FpsLimiter_mark(sharedFpsLimiter);

    keyCode := get_input();

    found := False;
    buttonIndex := 0;
    while buttonIndex < MAIN_MENU_BUTTON_COUNT do
    begin
      if (keyCode = button_values[buttonIndex]) or (keyCode = char_toupper(button_values[buttonIndex])) then
      begin
        // NOTE: Uninline.
        main_menu_play_sound('nmselec1');

        rc := return_values[buttonIndex];

        if (buttonIndex = MAIN_MENU_BUTTON_CREDITS) and
           ((keys[SDL_SCANCODE_RSHIFT] <> KEY_STATE_UP) or (keys[SDL_SCANCODE_LSHIFT] <> KEY_STATE_UP)) then
        begin
          rc := MAIN_MENU_QUOTES;
        end;

        found := True;
        Break;
      end;
      Inc(buttonIndex);
    end;

    if found then
    begin
      // Check escape/quit after button match (fall through in C++)
      if (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit = 3) then
      begin
        rc := MAIN_MENU_EXIT;
        main_menu_play_sound('nmselec1');
        Break;
      end
      else if game_user_wants_to_quit = 2 then
        game_user_wants_to_quit := 0
      else
      begin
        if elapsed_time(tick) >= main_menu_timeout_ms then
          rc := MAIN_MENU_TIMEOUT;
      end;

      renderPresent();
      FpsLimiter_throttle(sharedFpsLimiter);
      Continue;
    end;

    if rc = -1 then
    begin
      if keyCode = KEY_CTRL_R then
      begin
        rc := MAIN_MENU_SELFRUN;
        renderPresent();
        FpsLimiter_throttle(sharedFpsLimiter);
        Continue;
      end
      else if (keyCode = KEY_PLUS) or (keyCode = KEY_EQUAL) then
      begin
        IncGamma();
      end
      else if (keyCode = KEY_MINUS) or (keyCode = KEY_UNDERSCORE) then
      begin
        DecGamma();
      end
      else if (keyCode = KEY_UPPERCASE_D) or (keyCode = KEY_LOWERCASE_D) then
      begin
        rc := MAIN_MENU_SCREENSAVER;
        renderPresent();
        FpsLimiter_throttle(sharedFpsLimiter);
        Continue;
      end
      else if keyCode = 1111 then
      begin
        if (mouse_get_buttons() and MOUSE_EVENT_LEFT_BUTTON_REPEAT) = 0 then
        begin
          // NOTE: Uninline.
          main_menu_play_sound('nmselec0');
        end;
        renderPresent();
        FpsLimiter_throttle(sharedFpsLimiter);
        Continue;
      end;
    end;

    if (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit = 3) then
    begin
      rc := MAIN_MENU_EXIT;

      // NOTE: Uninline.
      main_menu_play_sound('nmselec1');
      Break;
    end
    else if game_user_wants_to_quit = 2 then
    begin
      game_user_wants_to_quit := 0;
    end
    else
    begin
      if elapsed_time(tick) >= main_menu_timeout_ms then
        rc := MAIN_MENU_TIMEOUT;
    end;

    renderPresent();
    FpsLimiter_throttle(sharedFpsLimiter);
  end;

  if oldCursorIsHidden then
    mouse_hide();

  in_main_menu := False;

  Result := rc;
end;

// 0x4735B8
function main_menu_fatal_error: Integer;
begin
  main_menu_destroy();
  Result := -1;
end;

// 0x4735C4
procedure main_menu_play_sound(fileName: PAnsiChar);
begin
  gsound_play_sfx_file(fileName);
end;

end.
