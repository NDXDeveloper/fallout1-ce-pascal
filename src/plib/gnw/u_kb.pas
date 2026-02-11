{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/kb.h + kb.cc
// Keyboard input system with key mapping and layout support.
unit u_kb;

interface

uses
  u_sdl2, u_dxinput;

const
  KEY_STATE_UP     = 0;
  KEY_STATE_DOWN   = 1;
  KEY_STATE_REPEAT = 2;

  MODIFIER_KEY_STATE_NUM_LOCK    = $01;
  MODIFIER_KEY_STATE_CAPS_LOCK   = $02;
  MODIFIER_KEY_STATE_SCROLL_LOCK = $04;

  KEYBOARD_EVENT_MODIFIER_CAPS_LOCK     = $0001;
  KEYBOARD_EVENT_MODIFIER_NUM_LOCK      = $0002;
  KEYBOARD_EVENT_MODIFIER_SCROLL_LOCK   = $0004;
  KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT    = $0008;
  KEYBOARD_EVENT_MODIFIER_RIGHT_SHIFT   = $0010;
  KEYBOARD_EVENT_MODIFIER_LEFT_ALT      = $0020;
  KEYBOARD_EVENT_MODIFIER_RIGHT_ALT     = $0040;
  KEYBOARD_EVENT_MODIFIER_LEFT_CONTROL  = $0080;
  KEYBOARD_EVENT_MODIFIER_RIGHT_CONTROL = $0100;
  KEYBOARD_EVENT_MODIFIER_ANY_SHIFT     = KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT or KEYBOARD_EVENT_MODIFIER_RIGHT_SHIFT;
  KEYBOARD_EVENT_MODIFIER_ANY_ALT       = KEYBOARD_EVENT_MODIFIER_LEFT_ALT or KEYBOARD_EVENT_MODIFIER_RIGHT_ALT;
  KEYBOARD_EVENT_MODIFIER_ANY_CONTROL   = KEYBOARD_EVENT_MODIFIER_LEFT_CONTROL or KEYBOARD_EVENT_MODIFIER_RIGHT_CONTROL;

  KEY_QUEUE_SIZE = 64;

  // KeyboardLayout
  KEYBOARD_LAYOUT_QWERTY  = 0;
  KEYBOARD_LAYOUT_FRENCH  = 1;
  KEYBOARD_LAYOUT_GERMAN  = 2;
  KEYBOARD_LAYOUT_ITALIAN = 3;
  KEYBOARD_LAYOUT_SPANISH = 4;

  // Key constants (matching C++ enum values)
  KEY_ESCAPE    = $1B;
  KEY_TAB       = $09;
  KEY_BACKSPACE = $08;
  KEY_RETURN    = $0D;

  KEY_SPACE        = $20;
  KEY_EXCLAMATION  = $21;
  KEY_QUOTE        = $22;
  KEY_NUMBER_SIGN  = $23;
  KEY_DOLLAR       = $24;
  KEY_PERCENT      = $25;
  KEY_AMPERSAND    = $26;
  KEY_SINGLE_QUOTE = $27;
  KEY_PAREN_LEFT   = $28;
  KEY_PAREN_RIGHT  = $29;
  KEY_ASTERISK     = $2A;
  KEY_PLUS         = $2B;
  KEY_COMMA        = $2C;
  KEY_MINUS        = $2D;
  KEY_DOT          = $2E;
  KEY_SLASH        = $2F;
  KEY_0 = $30; KEY_1 = $31; KEY_2 = $32; KEY_3 = $33; KEY_4 = $34;
  KEY_5 = $35; KEY_6 = $36; KEY_7 = $37; KEY_8 = $38; KEY_9 = $39;
  KEY_COLON      = $3A;
  KEY_SEMICOLON  = $3B;
  KEY_LESS       = $3C;
  KEY_EQUAL      = $3D;
  KEY_GREATER    = $3E;
  KEY_QUESTION   = $3F;
  KEY_AT         = $40;

  KEY_UPPERCASE_A = $41; KEY_UPPERCASE_B = $42; KEY_UPPERCASE_C = $43;
  KEY_UPPERCASE_D = $44; KEY_UPPERCASE_E = $45; KEY_UPPERCASE_F = $46;
  KEY_UPPERCASE_G = $47; KEY_UPPERCASE_H = $48; KEY_UPPERCASE_I = $49;
  KEY_UPPERCASE_J = $4A; KEY_UPPERCASE_K = $4B; KEY_UPPERCASE_L = $4C;
  KEY_UPPERCASE_M = $4D; KEY_UPPERCASE_N = $4E; KEY_UPPERCASE_O = $4F;
  KEY_UPPERCASE_P = $50; KEY_UPPERCASE_Q = $51; KEY_UPPERCASE_R = $52;
  KEY_UPPERCASE_S = $53; KEY_UPPERCASE_T = $54; KEY_UPPERCASE_U = $55;
  KEY_UPPERCASE_V = $56; KEY_UPPERCASE_W = $57; KEY_UPPERCASE_X = $58;
  KEY_UPPERCASE_Y = $59; KEY_UPPERCASE_Z = $5A;

  KEY_BRACKET_LEFT  = $5B;
  KEY_BACKSLASH     = $5C;
  KEY_BRACKET_RIGHT = $5D;
  KEY_CARET         = $5E;
  KEY_UNDERSCORE    = $5F;
  KEY_GRAVE         = $60;

  KEY_LOWERCASE_A = $61; KEY_LOWERCASE_B = $62; KEY_LOWERCASE_C = $63;
  KEY_LOWERCASE_D = $64; KEY_LOWERCASE_E = $65; KEY_LOWERCASE_F = $66;
  KEY_LOWERCASE_G = $67; KEY_LOWERCASE_H = $68; KEY_LOWERCASE_I = $69;
  KEY_LOWERCASE_J = $6A; KEY_LOWERCASE_K = $6B; KEY_LOWERCASE_L = $6C;
  KEY_LOWERCASE_M = $6D; KEY_LOWERCASE_N = $6E; KEY_LOWERCASE_O = $6F;
  KEY_LOWERCASE_P = $70; KEY_LOWERCASE_Q = $71; KEY_LOWERCASE_R = $72;
  KEY_LOWERCASE_S = $73; KEY_LOWERCASE_T = $74; KEY_LOWERCASE_U = $75;
  KEY_LOWERCASE_V = $76; KEY_LOWERCASE_W = $77; KEY_LOWERCASE_X = $78;
  KEY_LOWERCASE_Y = $79; KEY_LOWERCASE_Z = $7A;

  KEY_BRACE_LEFT  = $7B;
  KEY_BAR         = $7C;
  KEY_BRACE_RIGHT = $7D;
  KEY_TILDE       = $7E;
  KEY_DEL         = 127;

  // Extended keys (international characters)
  KEY_136 = 136; KEY_146 = 146; KEY_149 = 149; KEY_150 = 150;
  KEY_151 = 151; KEY_152 = 152; KEY_161 = 161; KEY_163 = 163;
  KEY_164 = 164; KEY_166 = 166; KEY_167 = 167; KEY_168 = 168;
  KEY_170 = 170; KEY_172 = 172; KEY_176 = 176; KEY_178 = 178;
  KEY_179 = 179; KEY_180 = 180; KEY_181 = 181; KEY_186 = 186;
  KEY_191 = 191; KEY_196 = 196; KEY_199 = 199; KEY_209 = 209;
  KEY_214 = 214; KEY_215 = 215; KEY_220 = 220; KEY_223 = 223;
  KEY_224 = 224; KEY_228 = 228; KEY_231 = 231; KEY_232 = 232;
  KEY_233 = 233; KEY_241 = 241; KEY_246 = 246; KEY_247 = 247;
  KEY_249 = 249; KEY_252 = 252;

  // Alt keys
  KEY_ALT_Q = 272; KEY_ALT_W = 273; KEY_ALT_E = 274; KEY_ALT_R = 275;
  KEY_ALT_T = 276; KEY_ALT_Y = 277; KEY_ALT_U = 278; KEY_ALT_I = 279;
  KEY_ALT_O = 280; KEY_ALT_P = 281;
  KEY_ALT_A = 286; KEY_ALT_S = 287; KEY_ALT_D = 288; KEY_ALT_F = 289;
  KEY_ALT_G = 290; KEY_ALT_H = 291; KEY_ALT_J = 292; KEY_ALT_K = 293;
  KEY_ALT_L = 294;
  KEY_ALT_Z = 300; KEY_ALT_X = 301; KEY_ALT_C = 302; KEY_ALT_V = 303;
  KEY_ALT_B = 304; KEY_ALT_N = 305; KEY_ALT_M = 306;

  // Ctrl keys
  KEY_CTRL_Q = 17; KEY_CTRL_W = 23; KEY_CTRL_E = 5; KEY_CTRL_R = 18;
  KEY_CTRL_T = 20; KEY_CTRL_Y = 25; KEY_CTRL_U = 21; KEY_CTRL_I = 9;
  KEY_CTRL_O = 15; KEY_CTRL_P = 16;
  KEY_CTRL_A = 1; KEY_CTRL_S = 19; KEY_CTRL_D = 4; KEY_CTRL_F = 6;
  KEY_CTRL_G = 7; KEY_CTRL_H = 8; KEY_CTRL_J = 10; KEY_CTRL_K = 11;
  KEY_CTRL_L = 12;
  KEY_CTRL_Z = 26; KEY_CTRL_X = 24; KEY_CTRL_C = 3; KEY_CTRL_V = 22;
  KEY_CTRL_B = 2; KEY_CTRL_N = 14; KEY_CTRL_M = 13;

  // Function keys
  KEY_F1 = 315; KEY_F2 = 316; KEY_F3 = 317; KEY_F4 = 318;
  KEY_F5 = 319; KEY_F6 = 320; KEY_F7 = 321; KEY_F8 = 322;
  KEY_F9 = 323; KEY_F10 = 324; KEY_F11 = 389; KEY_F12 = 390;

  KEY_SHIFT_F1 = 340; KEY_SHIFT_F2 = 341; KEY_SHIFT_F3 = 342;
  KEY_SHIFT_F4 = 343; KEY_SHIFT_F5 = 344; KEY_SHIFT_F6 = 345;
  KEY_SHIFT_F7 = 346; KEY_SHIFT_F8 = 347; KEY_SHIFT_F9 = 348;
  KEY_SHIFT_F10 = 349; KEY_SHIFT_F11 = 391; KEY_SHIFT_F12 = 392;

  KEY_CTRL_F1 = 350; KEY_CTRL_F2 = 351; KEY_CTRL_F3 = 352;
  KEY_CTRL_F4 = 353; KEY_CTRL_F5 = 354; KEY_CTRL_F6 = 355;
  KEY_CTRL_F7 = 356; KEY_CTRL_F8 = 357; KEY_CTRL_F9 = 358;
  KEY_CTRL_F10 = 359; KEY_CTRL_F11 = 393; KEY_CTRL_F12 = 394;

  KEY_ALT_F1 = 360; KEY_ALT_F2 = 361; KEY_ALT_F3 = 362;
  KEY_ALT_F4 = 363; KEY_ALT_F5 = 364; KEY_ALT_F6 = 365;
  KEY_ALT_F7 = 366; KEY_ALT_F8 = 367; KEY_ALT_F9 = 368;
  KEY_ALT_F10 = 369; KEY_ALT_F11 = 395; KEY_ALT_F12 = 396;

  // Navigation keys
  KEY_HOME      = 327; KEY_CTRL_HOME      = 375; KEY_ALT_HOME      = 407;
  KEY_PAGE_UP   = 329; KEY_CTRL_PAGE_UP   = 388; KEY_ALT_PAGE_UP   = 409;
  KEY_INSERT    = 338; KEY_CTRL_INSERT    = 402; KEY_ALT_INSERT    = 418;
  KEY_DELETE    = 339; KEY_CTRL_DELETE    = 403; KEY_ALT_DELETE    = 419;
  KEY_END       = 335; KEY_CTRL_END       = 373; KEY_ALT_END       = 415;
  KEY_PAGE_DOWN = 337; KEY_CTRL_PAGE_DOWN = 374; KEY_ALT_PAGE_DOWN = 417;

  // Arrow keys
  KEY_ARROW_UP    = 328; KEY_CTRL_ARROW_UP    = 397; KEY_ALT_ARROW_UP    = 408;
  KEY_ARROW_DOWN  = 336; KEY_CTRL_ARROW_DOWN  = 401; KEY_ALT_ARROW_DOWN  = 416;
  KEY_ARROW_LEFT  = 331; KEY_CTRL_ARROW_LEFT  = 371; KEY_ALT_ARROW_LEFT  = 411;
  KEY_ARROW_RIGHT = 333; KEY_CTRL_ARROW_RIGHT = 372; KEY_ALT_ARROW_RIGHT = 413;

  KEY_CTRL_BACKSLASH = 192;

  KEY_NUMBERPAD_5      = 332;
  KEY_CTRL_NUMBERPAD_5 = 399;
  KEY_ALT_NUMBERPAD_5  = 9999;

  KEY_FIRST_INPUT_CHARACTER = KEY_SPACE;
  KEY_LAST_INPUT_CHARACTER  = KEY_LOWERCASE_Z;

var
  keys: array[0..SDL_NUM_SCANCODES - 1] of Byte;
  kb_layout: Integer = KEYBOARD_LAYOUT_QWERTY;
  keynumpress: Byte = 0;

function GNW_kb_set: Integer;
procedure GNW_kb_restore;
procedure kb_wait;
procedure kb_clear;
function kb_getch: Integer;
procedure kb_disable;
procedure kb_enable;
function kb_is_disabled: Boolean;
procedure kb_disable_numpad;
procedure kb_enable_numpad;
function kb_numpad_is_disabled: Boolean;
procedure kb_disable_numlock;
procedure kb_enable_numlock;
function kb_numlock_is_disabled: Boolean;
procedure kb_set_layout(layout: Integer);
function kb_get_layout: Integer;
function kb_ascii_to_scan(ascii: Integer): Integer;
function kb_elapsed_time: LongWord;
procedure kb_reset_elapsed_time;
procedure kb_simulate_key(data: PKeyboardData);

implementation

uses
  u_input, u_vcr;

type
  TKeyAnsi = record
    keys: SmallInt;
    normal: SmallInt;
    shift: SmallInt;
    left_alt: SmallInt;
    right_alt: SmallInt;
    ctrl: SmallInt;
  end;
  PKeyAnsi = ^TKeyAnsi;

  TKeyData = record
    scan_code: Byte;
    modifiers: Word;
  end;
  PKeyData = ^TKeyData;

  TAsciiConvert = function: Integer;

var
  kb_installed: Byte = 0;
  kb_disabled: Boolean = False;
  kb_numpad_disabled: Boolean = False;
  kb_numlock_disabled: Boolean = False;
  kb_put: Integer = 0;
  kb_get: Integer = 0;
  extended_code: Word = 0;
  kb_lock_flags: Byte = 0;
  kb_scan_to_ascii: TAsciiConvert = nil;
  kb_buffer: array[0..KEY_QUEUE_SIZE - 1] of TKeyData;
  ascii_table: array[0..255] of TKeyAnsi;
  kb_idle_start_time: LongWord = 0;
  temp: TKeyData;

// Forward declarations for internal functions
function kb_next_ascii_English_US: Integer; forward;
function kb_next_ascii_French: Integer; forward;
function kb_next_ascii_German: Integer; forward;
function kb_next_ascii_Italian: Integer; forward;
function kb_next_ascii_Spanish: Integer; forward;
function kb_next_ascii: Integer; forward;
procedure kb_map_ascii_English_US; forward;
procedure kb_map_ascii_French; forward;
procedure kb_map_ascii_German; forward;
procedure kb_map_ascii_Italian; forward;
procedure kb_map_ascii_Spanish; forward;
procedure kb_init_lock_status; forward;
procedure kb_toggle_caps; forward;
procedure kb_toggle_num; forward;
procedure kb_toggle_scroll; forward;
function kb_buffer_put(key_data: PKeyData): Integer; forward;
function kb_buffer_get(key_data: PKeyData): Integer; forward;
function kb_buffer_peek(index: Integer; out keyboardEventPtr: PKeyData): Integer; forward;

// --- Public function implementations ---

function GNW_kb_set: Integer;
begin
  if kb_installed <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  kb_installed := 1;

  // NOTE: Uninline.
  kb_clear;

  kb_init_lock_status;
  kb_set_layout(KEYBOARD_LAYOUT_QWERTY);

  kb_idle_start_time := get_time;

  Result := 0;
end;

procedure GNW_kb_restore;
begin
  if kb_installed <> 0 then
    kb_installed := 0;
end;

procedure kb_wait;
begin
  if kb_installed <> 0 then
  begin
    // NOTE: Uninline.
    kb_clear;

    repeat
      GNW95_process_message;
    until keynumpress <> 0;

    // NOTE: Uninline.
    kb_clear;
  end;
end;

procedure kb_clear;
var
  i: Integer;
begin
  if kb_installed <> 0 then
  begin
    keynumpress := 0;

    for i := 0 to 255 do
      keys[i] := 0;

    kb_put := 0;
    kb_get := 0;
  end;

  dxinput_flush_keyboard_buffer;
  GNW95_clear_time_stamps;
end;

function kb_getch: Integer;
begin
  Result := -1;

  if kb_installed <> 0 then
    Result := kb_scan_to_ascii();
end;

procedure kb_disable;
begin
  kb_disabled := True;
end;

procedure kb_enable;
begin
  kb_disabled := False;
end;

function kb_is_disabled: Boolean;
begin
  Result := kb_disabled;
end;

procedure kb_disable_numpad;
begin
  kb_numpad_disabled := True;
end;

procedure kb_enable_numpad;
begin
  kb_numpad_disabled := False;
end;

function kb_numpad_is_disabled: Boolean;
begin
  Result := kb_numpad_disabled;
end;

procedure kb_disable_numlock;
begin
  kb_numlock_disabled := True;
end;

procedure kb_enable_numlock;
begin
  kb_numlock_disabled := False;
end;

function kb_numlock_is_disabled: Boolean;
begin
  Result := kb_numlock_disabled;
end;

procedure kb_set_layout(layout: Integer);
var
  old_layout: Integer;
begin
  old_layout := kb_layout;
  kb_layout := layout;

  case layout of
    KEYBOARD_LAYOUT_QWERTY:
    begin
      kb_scan_to_ascii := @kb_next_ascii_English_US;
      kb_map_ascii_English_US;
    end;
    // NOTE: Other layouts commented out in fallout-ce.
    // KEYBOARD_LAYOUT_FRENCH:
    // begin
    //   kb_scan_to_ascii := @kb_next_ascii_French;
    //   kb_map_ascii_French;
    // end;
    // KEYBOARD_LAYOUT_GERMAN:
    // begin
    //   kb_scan_to_ascii := @kb_next_ascii_German;
    //   kb_map_ascii_German;
    // end;
    // KEYBOARD_LAYOUT_ITALIAN:
    // begin
    //   kb_scan_to_ascii := @kb_next_ascii_Italian;
    //   kb_map_ascii_Italian;
    // end;
    // KEYBOARD_LAYOUT_SPANISH:
    // begin
    //   kb_scan_to_ascii := @kb_next_ascii_Spanish;
    //   kb_map_ascii_Spanish;
    // end;
  else
    kb_layout := old_layout;
  end;
end;

function kb_get_layout: Integer;
begin
  Result := kb_layout;
end;

function kb_ascii_to_scan(ascii: Integer): Integer;
var
  k: Integer;
begin
  // NOTE: The C++ code compares against k (loop index), not ascii (parameter).
  // This appears to be a bug in the original code, preserved here for fidelity.
  for k := 0 to 255 do
  begin
    if (ascii_table[k].normal = k)
      or (ascii_table[k].shift = k)
      or (ascii_table[k].left_alt = k)
      or (ascii_table[k].right_alt = k)
      or (ascii_table[k].ctrl = k) then
    begin
      Result := k;
      Exit;
    end;
  end;

  Result := -1;
end;

function kb_elapsed_time: LongWord;
begin
  Result := elapsed_time(kb_idle_start_time);
end;

procedure kb_reset_elapsed_time;
begin
  kb_idle_start_time := get_time;
end;

procedure kb_simulate_key(data: PKeyboardData);
var
  keyState: Integer;
  physicalKey: Integer;
  vcrEntry: PVcrEntry;
begin
  if vcr_state = VCR_STATE_RECORDING then
  begin
    if vcr_buffer_index <> VCR_BUFFER_CAPACITY - 1 then
    begin
      vcrEntry := @PVcrEntry(vcr_buffer)[vcr_buffer_index];
      vcrEntry^.EntryType := VCR_ENTRY_TYPE_KEYBOARD_EVENT;
      vcrEntry^.KeyboardEvent.Key := SmallInt(data^.Key and $FFFF);
      vcrEntry^.Time := vcr_time;
      vcrEntry^.Counter := vcr_counter;
      Inc(vcr_buffer_index);
    end;
  end;

  kb_idle_start_time := get_bk_time;

  physicalKey := data^.Key;

  if data^.Down = 1 then
    keyState := KEY_STATE_DOWN
  else
    keyState := KEY_STATE_UP;

  if (keyState <> KEY_STATE_UP) and (keys[physicalKey] <> KEY_STATE_UP) then
    keyState := KEY_STATE_REPEAT;

  if keys[physicalKey] <> keyState then
  begin
    keys[physicalKey] := keyState;
    if keyState = KEY_STATE_DOWN then
      Inc(keynumpress)
    else if keyState = KEY_STATE_UP then
      Dec(keynumpress);
  end;

  if keyState <> KEY_STATE_UP then
  begin
    temp.scan_code := physicalKey and $FF;
    temp.modifiers := 0;

    if physicalKey = SDL_SCANCODE_CAPSLOCK then
    begin
      if (keys[SDL_SCANCODE_LCTRL] = KEY_STATE_UP) and (keys[SDL_SCANCODE_RCTRL] = KEY_STATE_UP) then
        kb_toggle_caps;
    end
    else if physicalKey = SDL_SCANCODE_NUMLOCKCLEAR then
    begin
      if (keys[SDL_SCANCODE_LCTRL] = KEY_STATE_UP) and (keys[SDL_SCANCODE_RCTRL] = KEY_STATE_UP) then
        kb_toggle_num;
    end
    else if physicalKey = SDL_SCANCODE_SCROLLLOCK then
    begin
      if (keys[SDL_SCANCODE_LCTRL] = KEY_STATE_UP) and (keys[SDL_SCANCODE_RCTRL] = KEY_STATE_UP) then
        kb_toggle_scroll;
    end
    else if ((physicalKey = SDL_SCANCODE_LSHIFT) or (physicalKey = SDL_SCANCODE_RSHIFT))
      and ((kb_lock_flags and MODIFIER_KEY_STATE_CAPS_LOCK) <> 0)
      and (kb_layout <> 0) then
    begin
      if (keys[SDL_SCANCODE_LCTRL] = KEY_STATE_UP) and (keys[SDL_SCANCODE_RCTRL] = KEY_STATE_UP) then
        kb_toggle_caps;
    end;

    if kb_lock_flags <> 0 then
    begin
      if ((kb_lock_flags and MODIFIER_KEY_STATE_NUM_LOCK) <> 0) and (not kb_numlock_disabled) then
        temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_NUM_LOCK;

      if (kb_lock_flags and MODIFIER_KEY_STATE_CAPS_LOCK) <> 0 then
        temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_CAPS_LOCK;

      if (kb_lock_flags and MODIFIER_KEY_STATE_SCROLL_LOCK) <> 0 then
        temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_SCROLL_LOCK;
    end;

    if keys[SDL_SCANCODE_LSHIFT] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT;

    if keys[SDL_SCANCODE_RSHIFT] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_RIGHT_SHIFT;

    if keys[SDL_SCANCODE_LALT] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_LEFT_ALT;

    if keys[SDL_SCANCODE_RALT] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_RIGHT_ALT;

    if keys[SDL_SCANCODE_LCTRL] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_LEFT_CONTROL;

    if keys[SDL_SCANCODE_RCTRL] <> KEY_STATE_UP then
      temp.modifiers := temp.modifiers or KEYBOARD_EVENT_MODIFIER_RIGHT_CONTROL;

    // NOTE: Uninline.
    kb_buffer_put(@temp);
  end;
end;

// --- Internal function implementations ---

function kb_next_ascii_English_US: Integer;
var
  keyboardEvent: PKeyData;
  a, m, q, w, y, z, scanCode: Byte;
begin
  if kb_buffer_peek(0, keyboardEvent) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_CAPS_LOCK) <> 0 then
  begin
    if kb_layout <> KEYBOARD_LAYOUT_FRENCH then
      a := SDL_SCANCODE_A
    else
      a := SDL_SCANCODE_Q;

    if kb_layout <> KEYBOARD_LAYOUT_FRENCH then
      m := SDL_SCANCODE_M
    else
      m := SDL_SCANCODE_SEMICOLON;

    if kb_layout <> KEYBOARD_LAYOUT_FRENCH then
      q := SDL_SCANCODE_Q
    else
      q := SDL_SCANCODE_A;

    if kb_layout <> KEYBOARD_LAYOUT_FRENCH then
      w := SDL_SCANCODE_W
    else
      w := SDL_SCANCODE_Z;

    case kb_layout of
      KEYBOARD_LAYOUT_QWERTY,
      KEYBOARD_LAYOUT_FRENCH,
      KEYBOARD_LAYOUT_ITALIAN,
      KEYBOARD_LAYOUT_SPANISH:
        y := SDL_SCANCODE_Y;
    else
      // GERMAN
      y := SDL_SCANCODE_Z;
    end;

    case kb_layout of
      KEYBOARD_LAYOUT_QWERTY,
      KEYBOARD_LAYOUT_ITALIAN,
      KEYBOARD_LAYOUT_SPANISH:
        z := SDL_SCANCODE_Z;
      KEYBOARD_LAYOUT_FRENCH:
        z := SDL_SCANCODE_W;
    else
      // GERMAN
      z := SDL_SCANCODE_Y;
    end;

    scanCode := keyboardEvent^.scan_code;
    if (scanCode = a)
      or (scanCode = SDL_SCANCODE_B)
      or (scanCode = SDL_SCANCODE_C)
      or (scanCode = SDL_SCANCODE_D)
      or (scanCode = SDL_SCANCODE_E)
      or (scanCode = SDL_SCANCODE_F)
      or (scanCode = SDL_SCANCODE_G)
      or (scanCode = SDL_SCANCODE_H)
      or (scanCode = SDL_SCANCODE_I)
      or (scanCode = SDL_SCANCODE_J)
      or (scanCode = SDL_SCANCODE_K)
      or (scanCode = SDL_SCANCODE_L)
      or (scanCode = m)
      or (scanCode = SDL_SCANCODE_N)
      or (scanCode = SDL_SCANCODE_O)
      or (scanCode = SDL_SCANCODE_P)
      or (scanCode = q)
      or (scanCode = SDL_SCANCODE_R)
      or (scanCode = SDL_SCANCODE_S)
      or (scanCode = SDL_SCANCODE_T)
      or (scanCode = SDL_SCANCODE_U)
      or (scanCode = SDL_SCANCODE_V)
      or (scanCode = w)
      or (scanCode = SDL_SCANCODE_X)
      or (scanCode = y)
      or (scanCode = z) then
    begin
      if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_ANY_SHIFT) <> 0 then
        keyboardEvent^.modifiers := keyboardEvent^.modifiers and Word(not KEYBOARD_EVENT_MODIFIER_ANY_SHIFT)
      else
        keyboardEvent^.modifiers := keyboardEvent^.modifiers or KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT;
    end;
  end;

  Result := kb_next_ascii;
end;

function kb_next_ascii_French: Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function kb_next_ascii_German: Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function kb_next_ascii_Italian: Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function kb_next_ascii_Spanish: Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function kb_next_ascii: Integer;
var
  keyboardEvent: PKeyData;
  logicalKey: Integer;
  logicalKeyDescription: PKeyAnsi;
begin
  if kb_buffer_peek(0, keyboardEvent) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  case keyboardEvent^.scan_code of
    SDL_SCANCODE_KP_DIVIDE,
    SDL_SCANCODE_KP_MULTIPLY,
    SDL_SCANCODE_KP_MINUS,
    SDL_SCANCODE_KP_PLUS,
    SDL_SCANCODE_KP_ENTER:
    begin
      if kb_numpad_disabled then
      begin
        // NOTE: Uninline.
        kb_buffer_get(nil);
        Result := -1;
        Exit;
      end;
    end;
    SDL_SCANCODE_KP_0,
    SDL_SCANCODE_KP_1,
    SDL_SCANCODE_KP_2,
    SDL_SCANCODE_KP_3,
    SDL_SCANCODE_KP_4,
    SDL_SCANCODE_KP_5,
    SDL_SCANCODE_KP_6,
    SDL_SCANCODE_KP_7,
    SDL_SCANCODE_KP_8,
    SDL_SCANCODE_KP_9:
    begin
      if kb_numpad_disabled then
      begin
        // NOTE: Uninline.
        kb_buffer_get(nil);
        Result := -1;
        Exit;
      end;

      if ((keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_ANY_ALT) = 0)
        and ((keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_NUM_LOCK) <> 0) then
      begin
        if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_ANY_SHIFT) <> 0 then
          keyboardEvent^.modifiers := keyboardEvent^.modifiers and Word(not KEYBOARD_EVENT_MODIFIER_ANY_SHIFT)
        else
          keyboardEvent^.modifiers := keyboardEvent^.modifiers or KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT;
      end;
    end;
  end;

  logicalKey := -1;

  logicalKeyDescription := @ascii_table[keyboardEvent^.scan_code];
  if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_ANY_CONTROL) <> 0 then
    logicalKey := logicalKeyDescription^.ctrl
  else if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_RIGHT_ALT) <> 0 then
    logicalKey := logicalKeyDescription^.right_alt
  else if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_LEFT_ALT) <> 0 then
    logicalKey := logicalKeyDescription^.left_alt
  else if (keyboardEvent^.modifiers and KEYBOARD_EVENT_MODIFIER_ANY_SHIFT) <> 0 then
    logicalKey := logicalKeyDescription^.shift
  else
    logicalKey := logicalKeyDescription^.normal;

  // NOTE: Uninline.
  kb_buffer_get(nil);

  Result := logicalKey;
end;

// --- Key mapping functions ---

procedure kb_map_ascii_English_US;
var
  k: Integer;
begin
  for k := 0 to 255 do
  begin
    ascii_table[k].keys := -1;
    ascii_table[k].normal := -1;
    ascii_table[k].shift := -1;
    ascii_table[k].left_alt := -1;
    ascii_table[k].right_alt := -1;
    ascii_table[k].ctrl := -1;
  end;

  ascii_table[SDL_SCANCODE_ESCAPE].normal := KEY_ESCAPE;
  ascii_table[SDL_SCANCODE_ESCAPE].shift := KEY_ESCAPE;
  ascii_table[SDL_SCANCODE_ESCAPE].left_alt := KEY_ESCAPE;
  ascii_table[SDL_SCANCODE_ESCAPE].right_alt := KEY_ESCAPE;
  ascii_table[SDL_SCANCODE_ESCAPE].ctrl := KEY_ESCAPE;

  ascii_table[SDL_SCANCODE_F1].normal := KEY_F1;
  ascii_table[SDL_SCANCODE_F1].shift := KEY_SHIFT_F1;
  ascii_table[SDL_SCANCODE_F1].left_alt := KEY_ALT_F1;
  ascii_table[SDL_SCANCODE_F1].right_alt := KEY_ALT_F1;
  ascii_table[SDL_SCANCODE_F1].ctrl := KEY_CTRL_F1;

  ascii_table[SDL_SCANCODE_F2].normal := KEY_F2;
  ascii_table[SDL_SCANCODE_F2].shift := KEY_SHIFT_F2;
  ascii_table[SDL_SCANCODE_F2].left_alt := KEY_ALT_F2;
  ascii_table[SDL_SCANCODE_F2].right_alt := KEY_ALT_F2;
  ascii_table[SDL_SCANCODE_F2].ctrl := KEY_CTRL_F2;

  ascii_table[SDL_SCANCODE_F3].normal := KEY_F3;
  ascii_table[SDL_SCANCODE_F3].shift := KEY_SHIFT_F3;
  ascii_table[SDL_SCANCODE_F3].left_alt := KEY_ALT_F3;
  ascii_table[SDL_SCANCODE_F3].right_alt := KEY_ALT_F3;
  ascii_table[SDL_SCANCODE_F3].ctrl := KEY_CTRL_F3;

  ascii_table[SDL_SCANCODE_F4].normal := KEY_F4;
  ascii_table[SDL_SCANCODE_F4].shift := KEY_SHIFT_F4;
  ascii_table[SDL_SCANCODE_F4].left_alt := KEY_ALT_F4;
  ascii_table[SDL_SCANCODE_F4].right_alt := KEY_ALT_F4;
  ascii_table[SDL_SCANCODE_F4].ctrl := KEY_CTRL_F4;

  ascii_table[SDL_SCANCODE_F5].normal := KEY_F5;
  ascii_table[SDL_SCANCODE_F5].shift := KEY_SHIFT_F5;
  ascii_table[SDL_SCANCODE_F5].left_alt := KEY_ALT_F5;
  ascii_table[SDL_SCANCODE_F5].right_alt := KEY_ALT_F5;
  ascii_table[SDL_SCANCODE_F5].ctrl := KEY_CTRL_F5;

  ascii_table[SDL_SCANCODE_F6].normal := KEY_F6;
  ascii_table[SDL_SCANCODE_F6].shift := KEY_SHIFT_F6;
  ascii_table[SDL_SCANCODE_F6].left_alt := KEY_ALT_F6;
  ascii_table[SDL_SCANCODE_F6].right_alt := KEY_ALT_F6;
  ascii_table[SDL_SCANCODE_F6].ctrl := KEY_CTRL_F6;

  ascii_table[SDL_SCANCODE_F7].normal := KEY_F7;
  ascii_table[SDL_SCANCODE_F7].shift := KEY_SHIFT_F7;
  ascii_table[SDL_SCANCODE_F7].left_alt := KEY_ALT_F7;
  ascii_table[SDL_SCANCODE_F7].right_alt := KEY_ALT_F7;
  ascii_table[SDL_SCANCODE_F7].ctrl := KEY_CTRL_F7;

  ascii_table[SDL_SCANCODE_F8].normal := KEY_F8;
  ascii_table[SDL_SCANCODE_F8].shift := KEY_SHIFT_F8;
  ascii_table[SDL_SCANCODE_F8].left_alt := KEY_ALT_F8;
  ascii_table[SDL_SCANCODE_F8].right_alt := KEY_ALT_F8;
  ascii_table[SDL_SCANCODE_F8].ctrl := KEY_CTRL_F8;

  ascii_table[SDL_SCANCODE_F9].normal := KEY_F9;
  ascii_table[SDL_SCANCODE_F9].shift := KEY_SHIFT_F9;
  ascii_table[SDL_SCANCODE_F9].left_alt := KEY_ALT_F9;
  ascii_table[SDL_SCANCODE_F9].right_alt := KEY_ALT_F9;
  ascii_table[SDL_SCANCODE_F9].ctrl := KEY_CTRL_F9;

  ascii_table[SDL_SCANCODE_F10].normal := KEY_F10;
  ascii_table[SDL_SCANCODE_F10].shift := KEY_SHIFT_F10;
  ascii_table[SDL_SCANCODE_F10].left_alt := KEY_ALT_F10;
  ascii_table[SDL_SCANCODE_F10].right_alt := KEY_ALT_F10;
  ascii_table[SDL_SCANCODE_F10].ctrl := KEY_CTRL_F10;

  ascii_table[SDL_SCANCODE_F11].normal := KEY_F11;
  ascii_table[SDL_SCANCODE_F11].shift := KEY_SHIFT_F11;
  ascii_table[SDL_SCANCODE_F11].left_alt := KEY_ALT_F11;
  ascii_table[SDL_SCANCODE_F11].right_alt := KEY_ALT_F11;
  ascii_table[SDL_SCANCODE_F11].ctrl := KEY_CTRL_F11;

  ascii_table[SDL_SCANCODE_F12].normal := KEY_F12;
  ascii_table[SDL_SCANCODE_F12].shift := KEY_SHIFT_F12;
  ascii_table[SDL_SCANCODE_F12].left_alt := KEY_ALT_F12;
  ascii_table[SDL_SCANCODE_F12].right_alt := KEY_ALT_F12;
  ascii_table[SDL_SCANCODE_F12].ctrl := KEY_CTRL_F12;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_GRAVE;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_2;
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := 0;
  else
    k := SDL_SCANCODE_RIGHTBRACKET;
  end;

  ascii_table[k].normal := KEY_GRAVE;
  ascii_table[k].shift := KEY_TILDE;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_1].normal := KEY_1;
  ascii_table[SDL_SCANCODE_1].shift := KEY_EXCLAMATION;
  ascii_table[SDL_SCANCODE_1].left_alt := -1;
  ascii_table[SDL_SCANCODE_1].right_alt := -1;
  ascii_table[SDL_SCANCODE_1].ctrl := -1;

  ascii_table[SDL_SCANCODE_2].normal := KEY_2;
  ascii_table[SDL_SCANCODE_2].shift := KEY_AT;
  ascii_table[SDL_SCANCODE_2].left_alt := -1;
  ascii_table[SDL_SCANCODE_2].right_alt := -1;
  ascii_table[SDL_SCANCODE_2].ctrl := -1;

  ascii_table[SDL_SCANCODE_3].normal := KEY_3;
  ascii_table[SDL_SCANCODE_3].shift := KEY_NUMBER_SIGN;
  ascii_table[SDL_SCANCODE_3].left_alt := -1;
  ascii_table[SDL_SCANCODE_3].right_alt := -1;
  ascii_table[SDL_SCANCODE_3].ctrl := -1;

  ascii_table[SDL_SCANCODE_4].normal := KEY_4;
  ascii_table[SDL_SCANCODE_4].shift := KEY_DOLLAR;
  ascii_table[SDL_SCANCODE_4].left_alt := -1;
  ascii_table[SDL_SCANCODE_4].right_alt := -1;
  ascii_table[SDL_SCANCODE_4].ctrl := -1;

  ascii_table[SDL_SCANCODE_5].normal := KEY_5;
  ascii_table[SDL_SCANCODE_5].shift := KEY_PERCENT;
  ascii_table[SDL_SCANCODE_5].left_alt := -1;
  ascii_table[SDL_SCANCODE_5].right_alt := -1;
  ascii_table[SDL_SCANCODE_5].ctrl := -1;

  ascii_table[SDL_SCANCODE_6].normal := KEY_6;
  ascii_table[SDL_SCANCODE_6].shift := KEY_CARET;
  ascii_table[SDL_SCANCODE_6].left_alt := -1;
  ascii_table[SDL_SCANCODE_6].right_alt := -1;
  ascii_table[SDL_SCANCODE_6].ctrl := -1;

  ascii_table[SDL_SCANCODE_7].normal := KEY_7;
  ascii_table[SDL_SCANCODE_7].shift := KEY_AMPERSAND;
  ascii_table[SDL_SCANCODE_7].left_alt := -1;
  ascii_table[SDL_SCANCODE_7].right_alt := -1;
  ascii_table[SDL_SCANCODE_7].ctrl := -1;

  ascii_table[SDL_SCANCODE_8].normal := KEY_8;
  ascii_table[SDL_SCANCODE_8].shift := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_8].left_alt := -1;
  ascii_table[SDL_SCANCODE_8].right_alt := -1;
  ascii_table[SDL_SCANCODE_8].ctrl := -1;

  ascii_table[SDL_SCANCODE_9].normal := KEY_9;
  ascii_table[SDL_SCANCODE_9].shift := KEY_PAREN_LEFT;
  ascii_table[SDL_SCANCODE_9].left_alt := -1;
  ascii_table[SDL_SCANCODE_9].right_alt := -1;
  ascii_table[SDL_SCANCODE_9].ctrl := -1;

  ascii_table[SDL_SCANCODE_0].normal := KEY_0;
  ascii_table[SDL_SCANCODE_0].shift := KEY_PAREN_RIGHT;
  ascii_table[SDL_SCANCODE_0].left_alt := -1;
  ascii_table[SDL_SCANCODE_0].right_alt := -1;
  ascii_table[SDL_SCANCODE_0].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_MINUS;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_6;
  else
    k := SDL_SCANCODE_SLASH;
  end;

  ascii_table[k].normal := KEY_MINUS;
  ascii_table[k].shift := KEY_UNDERSCORE;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_EQUALS;
  else
    k := SDL_SCANCODE_0;
  end;

  ascii_table[k].normal := KEY_EQUAL;
  ascii_table[k].shift := KEY_PLUS;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_BACKSPACE].normal := KEY_BACKSPACE;
  ascii_table[SDL_SCANCODE_BACKSPACE].shift := KEY_BACKSPACE;
  ascii_table[SDL_SCANCODE_BACKSPACE].left_alt := KEY_BACKSPACE;
  ascii_table[SDL_SCANCODE_BACKSPACE].right_alt := KEY_BACKSPACE;
  ascii_table[SDL_SCANCODE_BACKSPACE].ctrl := KEY_DEL;

  ascii_table[SDL_SCANCODE_TAB].normal := KEY_TAB;
  ascii_table[SDL_SCANCODE_TAB].shift := KEY_TAB;
  ascii_table[SDL_SCANCODE_TAB].left_alt := KEY_TAB;
  ascii_table[SDL_SCANCODE_TAB].right_alt := KEY_TAB;
  ascii_table[SDL_SCANCODE_TAB].ctrl := KEY_TAB;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_A;
  else
    k := SDL_SCANCODE_Q;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_Q;
  ascii_table[k].shift := KEY_UPPERCASE_Q;
  ascii_table[k].left_alt := KEY_ALT_Q;
  ascii_table[k].right_alt := KEY_ALT_Q;
  ascii_table[k].ctrl := KEY_CTRL_Q;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_Z;
  else
    k := SDL_SCANCODE_W;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_W;
  ascii_table[k].shift := KEY_UPPERCASE_W;
  ascii_table[k].left_alt := KEY_ALT_W;
  ascii_table[k].right_alt := KEY_ALT_W;
  ascii_table[k].ctrl := KEY_CTRL_W;

  ascii_table[SDL_SCANCODE_E].normal := KEY_LOWERCASE_E;
  ascii_table[SDL_SCANCODE_E].shift := KEY_UPPERCASE_E;
  ascii_table[SDL_SCANCODE_E].left_alt := KEY_ALT_E;
  ascii_table[SDL_SCANCODE_E].right_alt := KEY_ALT_E;
  ascii_table[SDL_SCANCODE_E].ctrl := KEY_CTRL_E;

  ascii_table[SDL_SCANCODE_R].normal := KEY_LOWERCASE_R;
  ascii_table[SDL_SCANCODE_R].shift := KEY_UPPERCASE_R;
  ascii_table[SDL_SCANCODE_R].left_alt := KEY_ALT_R;
  ascii_table[SDL_SCANCODE_R].right_alt := KEY_ALT_R;
  ascii_table[SDL_SCANCODE_R].ctrl := KEY_CTRL_R;

  ascii_table[SDL_SCANCODE_T].normal := KEY_LOWERCASE_T;
  ascii_table[SDL_SCANCODE_T].shift := KEY_UPPERCASE_T;
  ascii_table[SDL_SCANCODE_T].left_alt := KEY_ALT_T;
  ascii_table[SDL_SCANCODE_T].right_alt := KEY_ALT_T;
  ascii_table[SDL_SCANCODE_T].ctrl := KEY_CTRL_T;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_FRENCH,
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := SDL_SCANCODE_Y;
  else
    k := SDL_SCANCODE_Z;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_Y;
  ascii_table[k].shift := KEY_UPPERCASE_Y;
  ascii_table[k].left_alt := KEY_ALT_Y;
  ascii_table[k].right_alt := KEY_ALT_Y;
  ascii_table[k].ctrl := KEY_CTRL_Y;

  ascii_table[SDL_SCANCODE_U].normal := KEY_LOWERCASE_U;
  ascii_table[SDL_SCANCODE_U].shift := KEY_UPPERCASE_U;
  ascii_table[SDL_SCANCODE_U].left_alt := KEY_ALT_U;
  ascii_table[SDL_SCANCODE_U].right_alt := KEY_ALT_U;
  ascii_table[SDL_SCANCODE_U].ctrl := KEY_CTRL_U;

  ascii_table[SDL_SCANCODE_I].normal := KEY_LOWERCASE_I;
  ascii_table[SDL_SCANCODE_I].shift := KEY_UPPERCASE_I;
  ascii_table[SDL_SCANCODE_I].left_alt := KEY_ALT_I;
  ascii_table[SDL_SCANCODE_I].right_alt := KEY_ALT_I;
  ascii_table[SDL_SCANCODE_I].ctrl := KEY_CTRL_I;

  ascii_table[SDL_SCANCODE_O].normal := KEY_LOWERCASE_O;
  ascii_table[SDL_SCANCODE_O].shift := KEY_UPPERCASE_O;
  ascii_table[SDL_SCANCODE_O].left_alt := KEY_ALT_O;
  ascii_table[SDL_SCANCODE_O].right_alt := KEY_ALT_O;
  ascii_table[SDL_SCANCODE_O].ctrl := KEY_CTRL_O;

  ascii_table[SDL_SCANCODE_P].normal := KEY_LOWERCASE_P;
  ascii_table[SDL_SCANCODE_P].shift := KEY_UPPERCASE_P;
  ascii_table[SDL_SCANCODE_P].left_alt := KEY_ALT_P;
  ascii_table[SDL_SCANCODE_P].right_alt := KEY_ALT_P;
  ascii_table[SDL_SCANCODE_P].ctrl := KEY_CTRL_P;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := SDL_SCANCODE_LEFTBRACKET;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_5;
  else
    k := SDL_SCANCODE_8;
  end;

  ascii_table[k].normal := KEY_BRACKET_LEFT;
  ascii_table[k].shift := KEY_BRACE_LEFT;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := SDL_SCANCODE_RIGHTBRACKET;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_MINUS;
  else
    k := SDL_SCANCODE_9;
  end;

  ascii_table[k].normal := KEY_BRACKET_RIGHT;
  ascii_table[k].shift := KEY_BRACE_RIGHT;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_BACKSLASH;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_8;
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := SDL_SCANCODE_GRAVE;
  else
    k := SDL_SCANCODE_MINUS;
  end;

  ascii_table[k].normal := KEY_BACKSLASH;
  ascii_table[k].shift := KEY_BAR;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := KEY_CTRL_BACKSLASH;

  ascii_table[SDL_SCANCODE_CAPSLOCK].normal := -1;
  ascii_table[SDL_SCANCODE_CAPSLOCK].shift := -1;
  ascii_table[SDL_SCANCODE_CAPSLOCK].left_alt := -1;
  ascii_table[SDL_SCANCODE_CAPSLOCK].right_alt := -1;
  ascii_table[SDL_SCANCODE_CAPSLOCK].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_Q;
  else
    k := SDL_SCANCODE_A;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_A;
  ascii_table[k].shift := KEY_UPPERCASE_A;
  ascii_table[k].left_alt := KEY_ALT_A;
  ascii_table[k].right_alt := KEY_ALT_A;
  ascii_table[k].ctrl := KEY_CTRL_A;

  ascii_table[SDL_SCANCODE_S].normal := KEY_LOWERCASE_S;
  ascii_table[SDL_SCANCODE_S].shift := KEY_UPPERCASE_S;
  ascii_table[SDL_SCANCODE_S].left_alt := KEY_ALT_S;
  ascii_table[SDL_SCANCODE_S].right_alt := KEY_ALT_S;
  ascii_table[SDL_SCANCODE_S].ctrl := KEY_CTRL_S;

  ascii_table[SDL_SCANCODE_D].normal := KEY_LOWERCASE_D;
  ascii_table[SDL_SCANCODE_D].shift := KEY_UPPERCASE_D;
  ascii_table[SDL_SCANCODE_D].left_alt := KEY_ALT_D;
  ascii_table[SDL_SCANCODE_D].right_alt := KEY_ALT_D;
  ascii_table[SDL_SCANCODE_D].ctrl := KEY_CTRL_D;

  ascii_table[SDL_SCANCODE_F].normal := KEY_LOWERCASE_F;
  ascii_table[SDL_SCANCODE_F].shift := KEY_UPPERCASE_F;
  ascii_table[SDL_SCANCODE_F].left_alt := KEY_ALT_F;
  ascii_table[SDL_SCANCODE_F].right_alt := KEY_ALT_F;
  ascii_table[SDL_SCANCODE_F].ctrl := KEY_CTRL_F;

  ascii_table[SDL_SCANCODE_G].normal := KEY_LOWERCASE_G;
  ascii_table[SDL_SCANCODE_G].shift := KEY_UPPERCASE_G;
  ascii_table[SDL_SCANCODE_G].left_alt := KEY_ALT_G;
  ascii_table[SDL_SCANCODE_G].right_alt := KEY_ALT_G;
  ascii_table[SDL_SCANCODE_G].ctrl := KEY_CTRL_G;

  ascii_table[SDL_SCANCODE_H].normal := KEY_LOWERCASE_H;
  ascii_table[SDL_SCANCODE_H].shift := KEY_UPPERCASE_H;
  ascii_table[SDL_SCANCODE_H].left_alt := KEY_ALT_H;
  ascii_table[SDL_SCANCODE_H].right_alt := KEY_ALT_H;
  ascii_table[SDL_SCANCODE_H].ctrl := KEY_CTRL_H;

  ascii_table[SDL_SCANCODE_J].normal := KEY_LOWERCASE_J;
  ascii_table[SDL_SCANCODE_J].shift := KEY_UPPERCASE_J;
  ascii_table[SDL_SCANCODE_J].left_alt := KEY_ALT_J;
  ascii_table[SDL_SCANCODE_J].right_alt := KEY_ALT_J;
  ascii_table[SDL_SCANCODE_J].ctrl := KEY_CTRL_J;

  ascii_table[SDL_SCANCODE_K].normal := KEY_LOWERCASE_K;
  ascii_table[SDL_SCANCODE_K].shift := KEY_UPPERCASE_K;
  ascii_table[SDL_SCANCODE_K].left_alt := KEY_ALT_K;
  ascii_table[SDL_SCANCODE_K].right_alt := KEY_ALT_K;
  ascii_table[SDL_SCANCODE_K].ctrl := KEY_CTRL_K;

  ascii_table[SDL_SCANCODE_L].normal := KEY_LOWERCASE_L;
  ascii_table[SDL_SCANCODE_L].shift := KEY_UPPERCASE_L;
  ascii_table[SDL_SCANCODE_L].left_alt := KEY_ALT_L;
  ascii_table[SDL_SCANCODE_L].right_alt := KEY_ALT_L;
  ascii_table[SDL_SCANCODE_L].ctrl := KEY_CTRL_L;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_SEMICOLON;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_SEMICOLON;
  ascii_table[k].shift := KEY_COLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_APOSTROPHE;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_3;
  else
    k := SDL_SCANCODE_2;
  end;

  ascii_table[k].normal := KEY_SINGLE_QUOTE;
  ascii_table[k].shift := KEY_QUOTE;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_RETURN].normal := KEY_RETURN;
  ascii_table[SDL_SCANCODE_RETURN].shift := KEY_RETURN;
  ascii_table[SDL_SCANCODE_RETURN].left_alt := KEY_RETURN;
  ascii_table[SDL_SCANCODE_RETURN].right_alt := KEY_RETURN;
  ascii_table[SDL_SCANCODE_RETURN].ctrl := KEY_CTRL_J;

  ascii_table[SDL_SCANCODE_LSHIFT].normal := -1;
  ascii_table[SDL_SCANCODE_LSHIFT].shift := -1;
  ascii_table[SDL_SCANCODE_LSHIFT].left_alt := -1;
  ascii_table[SDL_SCANCODE_LSHIFT].right_alt := -1;
  ascii_table[SDL_SCANCODE_LSHIFT].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_ITALIAN,
    KEYBOARD_LAYOUT_SPANISH:
      k := SDL_SCANCODE_Z;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_W;
  else
    k := SDL_SCANCODE_Y;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_Z;
  ascii_table[k].shift := KEY_UPPERCASE_Z;
  ascii_table[k].left_alt := KEY_ALT_Z;
  ascii_table[k].right_alt := KEY_ALT_Z;
  ascii_table[k].ctrl := KEY_CTRL_Z;

  ascii_table[SDL_SCANCODE_X].normal := KEY_LOWERCASE_X;
  ascii_table[SDL_SCANCODE_X].shift := KEY_UPPERCASE_X;
  ascii_table[SDL_SCANCODE_X].left_alt := KEY_ALT_X;
  ascii_table[SDL_SCANCODE_X].right_alt := KEY_ALT_X;
  ascii_table[SDL_SCANCODE_X].ctrl := KEY_CTRL_X;

  ascii_table[SDL_SCANCODE_C].normal := KEY_LOWERCASE_C;
  ascii_table[SDL_SCANCODE_C].shift := KEY_UPPERCASE_C;
  ascii_table[SDL_SCANCODE_C].left_alt := KEY_ALT_C;
  ascii_table[SDL_SCANCODE_C].right_alt := KEY_ALT_C;
  ascii_table[SDL_SCANCODE_C].ctrl := KEY_CTRL_C;

  ascii_table[SDL_SCANCODE_V].normal := KEY_LOWERCASE_V;
  ascii_table[SDL_SCANCODE_V].shift := KEY_UPPERCASE_V;
  ascii_table[SDL_SCANCODE_V].left_alt := KEY_ALT_V;
  ascii_table[SDL_SCANCODE_V].right_alt := KEY_ALT_V;
  ascii_table[SDL_SCANCODE_V].ctrl := KEY_CTRL_V;

  ascii_table[SDL_SCANCODE_B].normal := KEY_LOWERCASE_B;
  ascii_table[SDL_SCANCODE_B].shift := KEY_UPPERCASE_B;
  ascii_table[SDL_SCANCODE_B].left_alt := KEY_ALT_B;
  ascii_table[SDL_SCANCODE_B].right_alt := KEY_ALT_B;
  ascii_table[SDL_SCANCODE_B].ctrl := KEY_CTRL_B;

  ascii_table[SDL_SCANCODE_N].normal := KEY_LOWERCASE_N;
  ascii_table[SDL_SCANCODE_N].shift := KEY_UPPERCASE_N;
  ascii_table[SDL_SCANCODE_N].left_alt := KEY_ALT_N;
  ascii_table[SDL_SCANCODE_N].right_alt := KEY_ALT_N;
  ascii_table[SDL_SCANCODE_N].ctrl := KEY_CTRL_N;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_SEMICOLON;
  else
    k := SDL_SCANCODE_M;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_M;
  ascii_table[k].shift := KEY_UPPERCASE_M;
  ascii_table[k].left_alt := KEY_ALT_M;
  ascii_table[k].right_alt := KEY_ALT_M;
  ascii_table[k].ctrl := KEY_CTRL_M;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_M;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_COMMA;
  ascii_table[k].shift := KEY_LESS;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_COMMA;
  else
    k := SDL_SCANCODE_PERIOD;
  end;

  ascii_table[k].normal := KEY_DOT;
  ascii_table[k].shift := KEY_GREATER;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_SLASH;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_PERIOD;
  else
    k := SDL_SCANCODE_7;
  end;

  ascii_table[k].normal := KEY_SLASH;
  ascii_table[k].shift := KEY_QUESTION;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_RSHIFT].normal := -1;
  ascii_table[SDL_SCANCODE_RSHIFT].shift := -1;
  ascii_table[SDL_SCANCODE_RSHIFT].left_alt := -1;
  ascii_table[SDL_SCANCODE_RSHIFT].right_alt := -1;
  ascii_table[SDL_SCANCODE_RSHIFT].ctrl := -1;

  ascii_table[SDL_SCANCODE_LCTRL].normal := -1;
  ascii_table[SDL_SCANCODE_LCTRL].shift := -1;
  ascii_table[SDL_SCANCODE_LCTRL].left_alt := -1;
  ascii_table[SDL_SCANCODE_LCTRL].right_alt := -1;
  ascii_table[SDL_SCANCODE_LCTRL].ctrl := -1;

  ascii_table[SDL_SCANCODE_LALT].normal := -1;
  ascii_table[SDL_SCANCODE_LALT].shift := -1;
  ascii_table[SDL_SCANCODE_LALT].left_alt := -1;
  ascii_table[SDL_SCANCODE_LALT].right_alt := -1;
  ascii_table[SDL_SCANCODE_LALT].ctrl := -1;

  ascii_table[SDL_SCANCODE_SPACE].normal := KEY_SPACE;
  ascii_table[SDL_SCANCODE_SPACE].shift := KEY_SPACE;
  ascii_table[SDL_SCANCODE_SPACE].left_alt := KEY_SPACE;
  ascii_table[SDL_SCANCODE_SPACE].right_alt := KEY_SPACE;
  ascii_table[SDL_SCANCODE_SPACE].ctrl := KEY_SPACE;

  ascii_table[SDL_SCANCODE_RALT].normal := -1;
  ascii_table[SDL_SCANCODE_RALT].shift := -1;
  ascii_table[SDL_SCANCODE_RALT].left_alt := -1;
  ascii_table[SDL_SCANCODE_RALT].right_alt := -1;
  ascii_table[SDL_SCANCODE_RALT].ctrl := -1;

  ascii_table[SDL_SCANCODE_RCTRL].normal := -1;
  ascii_table[SDL_SCANCODE_RCTRL].shift := -1;
  ascii_table[SDL_SCANCODE_RCTRL].left_alt := -1;
  ascii_table[SDL_SCANCODE_RCTRL].right_alt := -1;
  ascii_table[SDL_SCANCODE_RCTRL].ctrl := -1;

  ascii_table[SDL_SCANCODE_INSERT].normal := KEY_INSERT;
  ascii_table[SDL_SCANCODE_INSERT].shift := KEY_INSERT;
  ascii_table[SDL_SCANCODE_INSERT].left_alt := KEY_ALT_INSERT;
  ascii_table[SDL_SCANCODE_INSERT].right_alt := KEY_ALT_INSERT;
  ascii_table[SDL_SCANCODE_INSERT].ctrl := KEY_CTRL_INSERT;

  ascii_table[SDL_SCANCODE_HOME].normal := KEY_HOME;
  ascii_table[SDL_SCANCODE_HOME].shift := KEY_HOME;
  ascii_table[SDL_SCANCODE_HOME].left_alt := KEY_ALT_HOME;
  ascii_table[SDL_SCANCODE_HOME].right_alt := KEY_ALT_HOME;
  ascii_table[SDL_SCANCODE_HOME].ctrl := KEY_CTRL_HOME;

  ascii_table[SDL_SCANCODE_PAGEUP].normal := KEY_PAGE_UP;
  ascii_table[SDL_SCANCODE_PAGEUP].shift := KEY_PAGE_UP;
  ascii_table[SDL_SCANCODE_PAGEUP].left_alt := KEY_ALT_PAGE_UP;
  ascii_table[SDL_SCANCODE_PAGEUP].right_alt := KEY_ALT_PAGE_UP;
  ascii_table[SDL_SCANCODE_PAGEUP].ctrl := KEY_CTRL_PAGE_UP;

  ascii_table[SDL_SCANCODE_DELETE].normal := KEY_DELETE;
  ascii_table[SDL_SCANCODE_DELETE].shift := KEY_DELETE;
  ascii_table[SDL_SCANCODE_DELETE].left_alt := KEY_ALT_DELETE;
  ascii_table[SDL_SCANCODE_DELETE].right_alt := KEY_ALT_DELETE;
  ascii_table[SDL_SCANCODE_DELETE].ctrl := KEY_CTRL_DELETE;

  ascii_table[SDL_SCANCODE_END].normal := KEY_END;
  ascii_table[SDL_SCANCODE_END].shift := KEY_END;
  ascii_table[SDL_SCANCODE_END].left_alt := KEY_ALT_END;
  ascii_table[SDL_SCANCODE_END].right_alt := KEY_ALT_END;
  ascii_table[SDL_SCANCODE_END].ctrl := KEY_CTRL_END;

  ascii_table[SDL_SCANCODE_PAGEDOWN].normal := KEY_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_PAGEDOWN].shift := KEY_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_PAGEDOWN].left_alt := KEY_ALT_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_PAGEDOWN].right_alt := KEY_ALT_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_PAGEDOWN].ctrl := KEY_CTRL_PAGE_DOWN;

  ascii_table[SDL_SCANCODE_UP].normal := KEY_ARROW_UP;
  ascii_table[SDL_SCANCODE_UP].shift := KEY_ARROW_UP;
  ascii_table[SDL_SCANCODE_UP].left_alt := KEY_ALT_ARROW_UP;
  ascii_table[SDL_SCANCODE_UP].right_alt := KEY_ALT_ARROW_UP;
  ascii_table[SDL_SCANCODE_UP].ctrl := KEY_CTRL_ARROW_UP;

  ascii_table[SDL_SCANCODE_DOWN].normal := KEY_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_DOWN].shift := KEY_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_DOWN].left_alt := KEY_ALT_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_DOWN].right_alt := KEY_ALT_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_DOWN].ctrl := KEY_CTRL_ARROW_DOWN;

  ascii_table[SDL_SCANCODE_LEFT].normal := KEY_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_LEFT].shift := KEY_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_LEFT].left_alt := KEY_ALT_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_LEFT].right_alt := KEY_ALT_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_LEFT].ctrl := KEY_CTRL_ARROW_LEFT;

  ascii_table[SDL_SCANCODE_RIGHT].normal := KEY_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHT].shift := KEY_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHT].left_alt := KEY_ALT_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHT].right_alt := KEY_ALT_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHT].ctrl := KEY_CTRL_ARROW_RIGHT;

  ascii_table[SDL_SCANCODE_NUMLOCKCLEAR].normal := -1;
  ascii_table[SDL_SCANCODE_NUMLOCKCLEAR].shift := -1;
  ascii_table[SDL_SCANCODE_NUMLOCKCLEAR].left_alt := -1;
  ascii_table[SDL_SCANCODE_NUMLOCKCLEAR].right_alt := -1;
  ascii_table[SDL_SCANCODE_NUMLOCKCLEAR].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_DIVIDE].normal := KEY_SLASH;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].shift := KEY_SLASH;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].ctrl := 3;

  ascii_table[SDL_SCANCODE_KP_MULTIPLY].normal := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].shift := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_MINUS].normal := KEY_MINUS;
  ascii_table[SDL_SCANCODE_KP_MINUS].shift := KEY_MINUS;
  ascii_table[SDL_SCANCODE_KP_MINUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MINUS].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MINUS].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_7].normal := KEY_HOME;
  ascii_table[SDL_SCANCODE_KP_7].shift := KEY_7;
  ascii_table[SDL_SCANCODE_KP_7].left_alt := KEY_ALT_HOME;
  ascii_table[SDL_SCANCODE_KP_7].right_alt := KEY_ALT_HOME;
  ascii_table[SDL_SCANCODE_KP_7].ctrl := KEY_CTRL_HOME;

  ascii_table[SDL_SCANCODE_KP_8].normal := KEY_ARROW_UP;
  ascii_table[SDL_SCANCODE_KP_8].shift := KEY_8;
  ascii_table[SDL_SCANCODE_KP_8].left_alt := KEY_ALT_ARROW_UP;
  ascii_table[SDL_SCANCODE_KP_8].right_alt := KEY_ALT_ARROW_UP;
  ascii_table[SDL_SCANCODE_KP_8].ctrl := KEY_CTRL_ARROW_UP;

  ascii_table[SDL_SCANCODE_KP_9].normal := KEY_PAGE_UP;
  ascii_table[SDL_SCANCODE_KP_9].shift := KEY_9;
  ascii_table[SDL_SCANCODE_KP_9].left_alt := KEY_ALT_PAGE_UP;
  ascii_table[SDL_SCANCODE_KP_9].right_alt := KEY_ALT_PAGE_UP;
  ascii_table[SDL_SCANCODE_KP_9].ctrl := KEY_CTRL_PAGE_UP;

  ascii_table[SDL_SCANCODE_KP_PLUS].normal := KEY_PLUS;
  ascii_table[SDL_SCANCODE_KP_PLUS].shift := KEY_PLUS;
  ascii_table[SDL_SCANCODE_KP_PLUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_PLUS].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_PLUS].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_4].normal := KEY_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_KP_4].shift := KEY_4;
  ascii_table[SDL_SCANCODE_KP_4].left_alt := KEY_ALT_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_KP_4].right_alt := KEY_ALT_ARROW_LEFT;
  ascii_table[SDL_SCANCODE_KP_4].ctrl := KEY_CTRL_ARROW_LEFT;

  ascii_table[SDL_SCANCODE_KP_5].normal := KEY_NUMBERPAD_5;
  ascii_table[SDL_SCANCODE_KP_5].shift := KEY_5;
  ascii_table[SDL_SCANCODE_KP_5].left_alt := KEY_ALT_NUMBERPAD_5;
  ascii_table[SDL_SCANCODE_KP_5].right_alt := KEY_ALT_NUMBERPAD_5;
  ascii_table[SDL_SCANCODE_KP_5].ctrl := KEY_CTRL_NUMBERPAD_5;

  ascii_table[SDL_SCANCODE_KP_6].normal := KEY_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_KP_6].shift := KEY_6;
  ascii_table[SDL_SCANCODE_KP_6].left_alt := KEY_ALT_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_KP_6].right_alt := KEY_ALT_ARROW_RIGHT;
  ascii_table[SDL_SCANCODE_KP_6].ctrl := KEY_CTRL_ARROW_RIGHT;

  ascii_table[SDL_SCANCODE_KP_1].normal := KEY_END;
  ascii_table[SDL_SCANCODE_KP_1].shift := KEY_1;
  ascii_table[SDL_SCANCODE_KP_1].left_alt := KEY_ALT_END;
  ascii_table[SDL_SCANCODE_KP_1].right_alt := KEY_ALT_END;
  ascii_table[SDL_SCANCODE_KP_1].ctrl := KEY_CTRL_END;

  ascii_table[SDL_SCANCODE_KP_2].normal := KEY_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_KP_2].shift := KEY_2;
  ascii_table[SDL_SCANCODE_KP_2].left_alt := KEY_ALT_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_KP_2].right_alt := KEY_ALT_ARROW_DOWN;
  ascii_table[SDL_SCANCODE_KP_2].ctrl := KEY_CTRL_ARROW_DOWN;

  ascii_table[SDL_SCANCODE_KP_3].normal := KEY_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_KP_3].shift := KEY_3;
  ascii_table[SDL_SCANCODE_KP_3].left_alt := KEY_ALT_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_KP_3].right_alt := KEY_ALT_PAGE_DOWN;
  ascii_table[SDL_SCANCODE_KP_3].ctrl := KEY_CTRL_PAGE_DOWN;

  ascii_table[SDL_SCANCODE_KP_ENTER].normal := KEY_RETURN;
  ascii_table[SDL_SCANCODE_KP_ENTER].shift := KEY_RETURN;
  ascii_table[SDL_SCANCODE_KP_ENTER].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_ENTER].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_ENTER].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_0].normal := KEY_INSERT;
  ascii_table[SDL_SCANCODE_KP_0].shift := KEY_0;
  ascii_table[SDL_SCANCODE_KP_0].left_alt := KEY_ALT_INSERT;
  ascii_table[SDL_SCANCODE_KP_0].right_alt := KEY_ALT_INSERT;
  ascii_table[SDL_SCANCODE_KP_0].ctrl := KEY_CTRL_INSERT;

  ascii_table[SDL_SCANCODE_KP_PERIOD].normal := KEY_DELETE;
  ascii_table[SDL_SCANCODE_KP_PERIOD].shift := KEY_DOT;
  ascii_table[SDL_SCANCODE_KP_PERIOD].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_PERIOD].right_alt := KEY_ALT_DELETE;
  ascii_table[SDL_SCANCODE_KP_PERIOD].ctrl := KEY_CTRL_DELETE;
end;

procedure kb_map_ascii_French;
var
  k: Integer;
begin
  kb_map_ascii_English_US;

  ascii_table[SDL_SCANCODE_GRAVE].normal := KEY_178;
  ascii_table[SDL_SCANCODE_GRAVE].shift := -1;
  ascii_table[SDL_SCANCODE_GRAVE].left_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].right_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].ctrl := -1;

  ascii_table[SDL_SCANCODE_1].normal := KEY_AMPERSAND;
  ascii_table[SDL_SCANCODE_1].shift := KEY_1;
  ascii_table[SDL_SCANCODE_1].left_alt := -1;
  ascii_table[SDL_SCANCODE_1].right_alt := -1;
  ascii_table[SDL_SCANCODE_1].ctrl := -1;

  ascii_table[SDL_SCANCODE_2].normal := KEY_233;
  ascii_table[SDL_SCANCODE_2].shift := KEY_2;
  ascii_table[SDL_SCANCODE_2].left_alt := -1;
  ascii_table[SDL_SCANCODE_2].right_alt := KEY_152;
  ascii_table[SDL_SCANCODE_2].ctrl := -1;

  ascii_table[SDL_SCANCODE_3].normal := KEY_QUOTE;
  ascii_table[SDL_SCANCODE_3].shift := KEY_3;
  ascii_table[SDL_SCANCODE_3].left_alt := -1;
  ascii_table[SDL_SCANCODE_3].right_alt := KEY_NUMBER_SIGN;
  ascii_table[SDL_SCANCODE_3].ctrl := -1;

  ascii_table[SDL_SCANCODE_4].normal := KEY_SINGLE_QUOTE;
  ascii_table[SDL_SCANCODE_4].shift := KEY_4;
  ascii_table[SDL_SCANCODE_4].left_alt := -1;
  ascii_table[SDL_SCANCODE_4].right_alt := KEY_BRACE_LEFT;
  ascii_table[SDL_SCANCODE_4].ctrl := -1;

  ascii_table[SDL_SCANCODE_5].normal := KEY_PAREN_LEFT;
  ascii_table[SDL_SCANCODE_5].shift := KEY_5;
  ascii_table[SDL_SCANCODE_5].left_alt := -1;
  ascii_table[SDL_SCANCODE_5].right_alt := KEY_BRACKET_LEFT;
  ascii_table[SDL_SCANCODE_5].ctrl := -1;

  ascii_table[SDL_SCANCODE_6].normal := KEY_150;
  ascii_table[SDL_SCANCODE_6].shift := KEY_6;
  ascii_table[SDL_SCANCODE_6].left_alt := -1;
  ascii_table[SDL_SCANCODE_6].right_alt := KEY_166;
  ascii_table[SDL_SCANCODE_6].ctrl := -1;

  ascii_table[SDL_SCANCODE_7].normal := KEY_232;
  ascii_table[SDL_SCANCODE_7].shift := KEY_7;
  ascii_table[SDL_SCANCODE_7].left_alt := -1;
  ascii_table[SDL_SCANCODE_7].right_alt := KEY_GRAVE;
  ascii_table[SDL_SCANCODE_7].ctrl := -1;

  ascii_table[SDL_SCANCODE_8].normal := KEY_UNDERSCORE;
  ascii_table[SDL_SCANCODE_8].shift := KEY_8;
  ascii_table[SDL_SCANCODE_8].left_alt := -1;
  ascii_table[SDL_SCANCODE_8].right_alt := KEY_BACKSLASH;
  ascii_table[SDL_SCANCODE_8].ctrl := -1;

  ascii_table[SDL_SCANCODE_9].normal := KEY_231;
  ascii_table[SDL_SCANCODE_9].shift := KEY_9;
  ascii_table[SDL_SCANCODE_9].left_alt := -1;
  ascii_table[SDL_SCANCODE_9].right_alt := KEY_136;
  ascii_table[SDL_SCANCODE_9].ctrl := -1;

  ascii_table[SDL_SCANCODE_0].normal := KEY_224;
  ascii_table[SDL_SCANCODE_0].shift := KEY_0;
  ascii_table[SDL_SCANCODE_0].left_alt := -1;
  ascii_table[SDL_SCANCODE_0].right_alt := KEY_AT;
  ascii_table[SDL_SCANCODE_0].ctrl := -1;

  ascii_table[SDL_SCANCODE_MINUS].normal := KEY_PAREN_RIGHT;
  ascii_table[SDL_SCANCODE_MINUS].shift := KEY_176;
  ascii_table[SDL_SCANCODE_MINUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].right_alt := KEY_BRACKET_RIGHT;
  ascii_table[SDL_SCANCODE_MINUS].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_EQUALS;
  else
    k := SDL_SCANCODE_0;
  end;

  ascii_table[k].normal := KEY_EQUAL;
  ascii_table[k].shift := KEY_PLUS;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := KEY_BRACE_RIGHT;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_LEFTBRACKET].normal := KEY_136;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].shift := KEY_168;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].right_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_RIGHTBRACKET].normal := KEY_DOLLAR;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].shift := KEY_163;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].right_alt := KEY_164;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_APOSTROPHE].normal := KEY_249;
  ascii_table[SDL_SCANCODE_APOSTROPHE].shift := KEY_PERCENT;
  ascii_table[SDL_SCANCODE_APOSTROPHE].left_alt := -1;
  ascii_table[SDL_SCANCODE_APOSTROPHE].right_alt := -1;
  ascii_table[SDL_SCANCODE_APOSTROPHE].ctrl := -1;

  ascii_table[SDL_SCANCODE_BACKSLASH].normal := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_BACKSLASH].shift := KEY_181;
  ascii_table[SDL_SCANCODE_BACKSLASH].left_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].right_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_M;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_COMMA;
  ascii_table[k].shift := KEY_QUESTION;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_SEMICOLON;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_SEMICOLON;
  ascii_table[k].shift := KEY_DOT;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_SEMICOLON;
  else
    k := SDL_SCANCODE_PERIOD;
  end;

  ascii_table[k].normal := KEY_COLON;
  ascii_table[k].shift := KEY_SLASH;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_SLASH].normal := KEY_EXCLAMATION;
  ascii_table[SDL_SCANCODE_SLASH].shift := KEY_167;
  ascii_table[SDL_SCANCODE_SLASH].left_alt := -1;
  ascii_table[SDL_SCANCODE_SLASH].right_alt := -1;
  ascii_table[SDL_SCANCODE_SLASH].ctrl := -1;
end;

procedure kb_map_ascii_German;
var
  k: Integer;
begin
  kb_map_ascii_English_US;

  ascii_table[SDL_SCANCODE_GRAVE].normal := KEY_136;
  ascii_table[SDL_SCANCODE_GRAVE].shift := KEY_186;
  ascii_table[SDL_SCANCODE_GRAVE].left_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].right_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].ctrl := -1;

  ascii_table[SDL_SCANCODE_2].normal := KEY_2;
  ascii_table[SDL_SCANCODE_2].shift := KEY_QUOTE;
  ascii_table[SDL_SCANCODE_2].left_alt := -1;
  ascii_table[SDL_SCANCODE_2].right_alt := KEY_178;
  ascii_table[SDL_SCANCODE_2].ctrl := -1;

  ascii_table[SDL_SCANCODE_3].normal := KEY_3;
  ascii_table[SDL_SCANCODE_3].shift := KEY_167;
  ascii_table[SDL_SCANCODE_3].left_alt := -1;
  ascii_table[SDL_SCANCODE_3].right_alt := KEY_179;
  ascii_table[SDL_SCANCODE_3].ctrl := -1;

  ascii_table[SDL_SCANCODE_6].normal := KEY_6;
  ascii_table[SDL_SCANCODE_6].shift := KEY_AMPERSAND;
  ascii_table[SDL_SCANCODE_6].left_alt := -1;
  ascii_table[SDL_SCANCODE_6].right_alt := -1;
  ascii_table[SDL_SCANCODE_6].ctrl := -1;

  ascii_table[SDL_SCANCODE_7].normal := KEY_7;
  ascii_table[SDL_SCANCODE_7].shift := KEY_166;
  ascii_table[SDL_SCANCODE_7].left_alt := -1;
  ascii_table[SDL_SCANCODE_7].right_alt := KEY_BRACE_LEFT;
  ascii_table[SDL_SCANCODE_7].ctrl := -1;

  ascii_table[SDL_SCANCODE_8].normal := KEY_8;
  ascii_table[SDL_SCANCODE_8].shift := KEY_PAREN_LEFT;
  ascii_table[SDL_SCANCODE_8].left_alt := -1;
  ascii_table[SDL_SCANCODE_8].right_alt := KEY_BRACKET_LEFT;
  ascii_table[SDL_SCANCODE_8].ctrl := -1;

  ascii_table[SDL_SCANCODE_9].normal := KEY_9;
  ascii_table[SDL_SCANCODE_9].shift := KEY_PAREN_RIGHT;
  ascii_table[SDL_SCANCODE_9].left_alt := -1;
  ascii_table[SDL_SCANCODE_9].right_alt := KEY_BRACKET_RIGHT;
  ascii_table[SDL_SCANCODE_9].ctrl := -1;

  ascii_table[SDL_SCANCODE_0].normal := KEY_0;
  ascii_table[SDL_SCANCODE_0].shift := KEY_EQUAL;
  ascii_table[SDL_SCANCODE_0].left_alt := -1;
  ascii_table[SDL_SCANCODE_0].right_alt := KEY_BRACE_RIGHT;
  ascii_table[SDL_SCANCODE_0].ctrl := -1;

  ascii_table[SDL_SCANCODE_MINUS].normal := KEY_223;
  ascii_table[SDL_SCANCODE_MINUS].shift := KEY_QUESTION;
  ascii_table[SDL_SCANCODE_MINUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].right_alt := KEY_BACKSLASH;
  ascii_table[SDL_SCANCODE_MINUS].ctrl := -1;

  ascii_table[SDL_SCANCODE_EQUALS].normal := KEY_180;
  ascii_table[SDL_SCANCODE_EQUALS].shift := KEY_GRAVE;
  ascii_table[SDL_SCANCODE_EQUALS].left_alt := -1;
  ascii_table[SDL_SCANCODE_EQUALS].right_alt := -1;
  ascii_table[SDL_SCANCODE_EQUALS].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_A;
  else
    k := SDL_SCANCODE_Q;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_Q;
  ascii_table[k].shift := KEY_UPPERCASE_Q;
  ascii_table[k].left_alt := KEY_ALT_Q;
  ascii_table[k].right_alt := KEY_AT;
  ascii_table[k].ctrl := KEY_CTRL_Q;

  ascii_table[SDL_SCANCODE_LEFTBRACKET].normal := KEY_252;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].shift := KEY_220;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].right_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY,
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_EQUALS;
  else
    k := SDL_SCANCODE_RIGHTBRACKET;
  end;

  ascii_table[k].normal := KEY_PLUS;
  ascii_table[k].shift := KEY_ASTERISK;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := KEY_152;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_SEMICOLON].normal := KEY_246;
  ascii_table[SDL_SCANCODE_SEMICOLON].shift := KEY_214;
  ascii_table[SDL_SCANCODE_SEMICOLON].left_alt := -1;
  ascii_table[SDL_SCANCODE_SEMICOLON].right_alt := -1;
  ascii_table[SDL_SCANCODE_SEMICOLON].ctrl := -1;

  ascii_table[SDL_SCANCODE_APOSTROPHE].normal := KEY_228;
  ascii_table[SDL_SCANCODE_APOSTROPHE].shift := KEY_196;
  ascii_table[SDL_SCANCODE_APOSTROPHE].left_alt := -1;
  ascii_table[SDL_SCANCODE_APOSTROPHE].right_alt := -1;
  ascii_table[SDL_SCANCODE_APOSTROPHE].ctrl := -1;

  ascii_table[SDL_SCANCODE_BACKSLASH].normal := KEY_NUMBER_SIGN;
  ascii_table[SDL_SCANCODE_BACKSLASH].shift := KEY_SINGLE_QUOTE;
  ascii_table[SDL_SCANCODE_BACKSLASH].left_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].right_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_SEMICOLON;
  else
    k := SDL_SCANCODE_M;
  end;

  ascii_table[k].normal := KEY_LOWERCASE_M;
  ascii_table[k].shift := KEY_UPPERCASE_M;
  ascii_table[k].left_alt := KEY_ALT_M;
  ascii_table[k].right_alt := KEY_181;
  ascii_table[k].ctrl := KEY_CTRL_M;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_M;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_COMMA;
  ascii_table[k].shift := KEY_SEMICOLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_COMMA;
  else
    k := SDL_SCANCODE_PERIOD;
  end;

  ascii_table[k].normal := KEY_DOT;
  ascii_table[k].shift := KEY_COLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_MINUS;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_6;
  else
    k := SDL_SCANCODE_SLASH;
  end;

  ascii_table[k].normal := KEY_150;
  ascii_table[k].shift := KEY_151;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_DIVIDE].normal := KEY_247;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].shift := KEY_247;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_DIVIDE].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_MULTIPLY].normal := KEY_215;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].shift := KEY_215;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].right_alt := -1;
  ascii_table[SDL_SCANCODE_KP_MULTIPLY].ctrl := -1;

  ascii_table[SDL_SCANCODE_KP_PERIOD].normal := KEY_DELETE;
  ascii_table[SDL_SCANCODE_KP_PERIOD].shift := KEY_COMMA;
  ascii_table[SDL_SCANCODE_KP_PERIOD].left_alt := -1;
  ascii_table[SDL_SCANCODE_KP_PERIOD].right_alt := KEY_ALT_DELETE;
  ascii_table[SDL_SCANCODE_KP_PERIOD].ctrl := KEY_CTRL_DELETE;
end;

procedure kb_map_ascii_Italian;
var
  k: Integer;
begin
  kb_map_ascii_English_US;

  ascii_table[SDL_SCANCODE_GRAVE].normal := KEY_BACKSLASH;
  ascii_table[SDL_SCANCODE_GRAVE].shift := KEY_BAR;
  ascii_table[SDL_SCANCODE_GRAVE].left_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].right_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].ctrl := -1;

  ascii_table[SDL_SCANCODE_1].normal := KEY_1;
  ascii_table[SDL_SCANCODE_1].shift := KEY_EXCLAMATION;
  ascii_table[SDL_SCANCODE_1].left_alt := -1;
  ascii_table[SDL_SCANCODE_1].right_alt := -1;
  ascii_table[SDL_SCANCODE_1].ctrl := -1;

  ascii_table[SDL_SCANCODE_2].normal := KEY_2;
  ascii_table[SDL_SCANCODE_2].shift := KEY_QUOTE;
  ascii_table[SDL_SCANCODE_2].left_alt := -1;
  ascii_table[SDL_SCANCODE_2].right_alt := -1;
  ascii_table[SDL_SCANCODE_2].ctrl := -1;

  ascii_table[SDL_SCANCODE_3].normal := KEY_3;
  ascii_table[SDL_SCANCODE_3].shift := KEY_163;
  ascii_table[SDL_SCANCODE_3].left_alt := -1;
  ascii_table[SDL_SCANCODE_3].right_alt := -1;
  ascii_table[SDL_SCANCODE_3].ctrl := -1;

  ascii_table[SDL_SCANCODE_6].normal := KEY_6;
  ascii_table[SDL_SCANCODE_6].shift := KEY_AMPERSAND;
  ascii_table[SDL_SCANCODE_6].left_alt := -1;
  ascii_table[SDL_SCANCODE_6].right_alt := -1;
  ascii_table[SDL_SCANCODE_6].ctrl := -1;

  ascii_table[SDL_SCANCODE_7].normal := KEY_7;
  ascii_table[SDL_SCANCODE_7].shift := KEY_SLASH;
  ascii_table[SDL_SCANCODE_7].left_alt := -1;
  ascii_table[SDL_SCANCODE_7].right_alt := -1;
  ascii_table[SDL_SCANCODE_7].ctrl := -1;

  ascii_table[SDL_SCANCODE_8].normal := KEY_8;
  ascii_table[SDL_SCANCODE_8].shift := KEY_PAREN_LEFT;
  ascii_table[SDL_SCANCODE_8].left_alt := -1;
  ascii_table[SDL_SCANCODE_8].right_alt := -1;
  ascii_table[SDL_SCANCODE_8].ctrl := -1;

  ascii_table[SDL_SCANCODE_9].normal := KEY_9;
  ascii_table[SDL_SCANCODE_9].shift := KEY_PAREN_RIGHT;
  ascii_table[SDL_SCANCODE_9].left_alt := -1;
  ascii_table[SDL_SCANCODE_9].right_alt := -1;
  ascii_table[SDL_SCANCODE_9].ctrl := -1;

  ascii_table[SDL_SCANCODE_0].normal := KEY_0;
  ascii_table[SDL_SCANCODE_0].shift := KEY_EQUAL;
  ascii_table[SDL_SCANCODE_0].left_alt := -1;
  ascii_table[SDL_SCANCODE_0].right_alt := -1;
  ascii_table[SDL_SCANCODE_0].ctrl := -1;

  ascii_table[SDL_SCANCODE_MINUS].normal := KEY_SINGLE_QUOTE;
  ascii_table[SDL_SCANCODE_MINUS].shift := KEY_QUESTION;
  ascii_table[SDL_SCANCODE_MINUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].right_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].ctrl := -1;

  ascii_table[SDL_SCANCODE_LEFTBRACKET].normal := KEY_232;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].shift := KEY_233;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].right_alt := KEY_BRACKET_LEFT;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_RIGHTBRACKET].normal := KEY_PLUS;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].shift := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].right_alt := KEY_BRACKET_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_BACKSLASH].normal := KEY_249;
  ascii_table[SDL_SCANCODE_BACKSLASH].shift := KEY_167;
  ascii_table[SDL_SCANCODE_BACKSLASH].left_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].right_alt := KEY_BRACKET_RIGHT;
  ascii_table[SDL_SCANCODE_BACKSLASH].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_M;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_COMMA;
  ascii_table[k].shift := KEY_SEMICOLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_COMMA;
  else
    k := SDL_SCANCODE_PERIOD;
  end;

  ascii_table[k].normal := KEY_DOT;
  ascii_table[k].shift := KEY_COLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_MINUS;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_6;
  else
    k := SDL_SCANCODE_SLASH;
  end;

  ascii_table[k].normal := KEY_MINUS;
  ascii_table[k].shift := KEY_UNDERSCORE;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;
end;

procedure kb_map_ascii_Spanish;
var
  k: Integer;
begin
  kb_map_ascii_English_US;

  ascii_table[SDL_SCANCODE_1].normal := KEY_1;
  ascii_table[SDL_SCANCODE_1].shift := KEY_EXCLAMATION;
  ascii_table[SDL_SCANCODE_1].left_alt := -1;
  ascii_table[SDL_SCANCODE_1].right_alt := KEY_BAR;
  ascii_table[SDL_SCANCODE_1].ctrl := -1;

  ascii_table[SDL_SCANCODE_2].normal := KEY_2;
  ascii_table[SDL_SCANCODE_2].shift := KEY_QUOTE;
  ascii_table[SDL_SCANCODE_2].left_alt := -1;
  ascii_table[SDL_SCANCODE_2].right_alt := KEY_AT;
  ascii_table[SDL_SCANCODE_2].ctrl := -1;

  ascii_table[SDL_SCANCODE_3].normal := KEY_3;
  ascii_table[SDL_SCANCODE_3].shift := KEY_149;
  ascii_table[SDL_SCANCODE_3].left_alt := -1;
  ascii_table[SDL_SCANCODE_3].right_alt := KEY_NUMBER_SIGN;
  ascii_table[SDL_SCANCODE_3].ctrl := -1;

  ascii_table[SDL_SCANCODE_6].normal := KEY_6;
  ascii_table[SDL_SCANCODE_6].shift := KEY_AMPERSAND;
  ascii_table[SDL_SCANCODE_6].left_alt := -1;
  ascii_table[SDL_SCANCODE_6].right_alt := KEY_172;
  ascii_table[SDL_SCANCODE_6].ctrl := -1;

  ascii_table[SDL_SCANCODE_7].normal := KEY_7;
  ascii_table[SDL_SCANCODE_7].shift := KEY_SLASH;
  ascii_table[SDL_SCANCODE_7].left_alt := -1;
  ascii_table[SDL_SCANCODE_7].right_alt := -1;
  ascii_table[SDL_SCANCODE_7].ctrl := -1;

  ascii_table[SDL_SCANCODE_8].normal := KEY_8;
  ascii_table[SDL_SCANCODE_8].shift := KEY_PAREN_LEFT;
  ascii_table[SDL_SCANCODE_8].left_alt := -1;
  ascii_table[SDL_SCANCODE_8].right_alt := -1;
  ascii_table[SDL_SCANCODE_8].ctrl := -1;

  ascii_table[SDL_SCANCODE_9].normal := KEY_9;
  ascii_table[SDL_SCANCODE_9].shift := KEY_PAREN_RIGHT;
  ascii_table[SDL_SCANCODE_9].left_alt := -1;
  ascii_table[SDL_SCANCODE_9].right_alt := -1;
  ascii_table[SDL_SCANCODE_9].ctrl := -1;

  ascii_table[SDL_SCANCODE_0].normal := KEY_0;
  ascii_table[SDL_SCANCODE_0].shift := KEY_EQUAL;
  ascii_table[SDL_SCANCODE_0].left_alt := -1;
  ascii_table[SDL_SCANCODE_0].right_alt := -1;
  ascii_table[SDL_SCANCODE_0].ctrl := -1;

  ascii_table[SDL_SCANCODE_MINUS].normal := KEY_146;
  ascii_table[SDL_SCANCODE_MINUS].shift := KEY_QUESTION;
  ascii_table[SDL_SCANCODE_MINUS].left_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].right_alt := -1;
  ascii_table[SDL_SCANCODE_MINUS].ctrl := -1;

  ascii_table[SDL_SCANCODE_EQUALS].normal := KEY_161;
  ascii_table[SDL_SCANCODE_EQUALS].shift := KEY_191;
  ascii_table[SDL_SCANCODE_EQUALS].left_alt := -1;
  ascii_table[SDL_SCANCODE_EQUALS].right_alt := -1;
  ascii_table[SDL_SCANCODE_EQUALS].ctrl := -1;

  ascii_table[SDL_SCANCODE_GRAVE].normal := KEY_176;
  ascii_table[SDL_SCANCODE_GRAVE].shift := KEY_170;
  ascii_table[SDL_SCANCODE_GRAVE].left_alt := -1;
  ascii_table[SDL_SCANCODE_GRAVE].right_alt := KEY_BACKSLASH;
  ascii_table[SDL_SCANCODE_GRAVE].ctrl := -1;

  ascii_table[SDL_SCANCODE_LEFTBRACKET].normal := KEY_GRAVE;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].shift := KEY_CARET;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].right_alt := KEY_BRACKET_LEFT;
  ascii_table[SDL_SCANCODE_LEFTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_RIGHTBRACKET].normal := KEY_PLUS;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].shift := KEY_ASTERISK;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].left_alt := -1;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].right_alt := KEY_BRACKET_RIGHT;
  ascii_table[SDL_SCANCODE_RIGHTBRACKET].ctrl := -1;

  ascii_table[SDL_SCANCODE_SEMICOLON].normal := KEY_241;
  ascii_table[SDL_SCANCODE_SEMICOLON].shift := KEY_209;
  ascii_table[SDL_SCANCODE_SEMICOLON].left_alt := -1;
  ascii_table[SDL_SCANCODE_SEMICOLON].right_alt := -1;
  ascii_table[SDL_SCANCODE_SEMICOLON].ctrl := -1;

  ascii_table[SDL_SCANCODE_APOSTROPHE].normal := KEY_168;
  ascii_table[SDL_SCANCODE_APOSTROPHE].shift := KEY_180;
  ascii_table[SDL_SCANCODE_APOSTROPHE].left_alt := -1;
  ascii_table[SDL_SCANCODE_APOSTROPHE].right_alt := KEY_BRACE_LEFT;
  ascii_table[SDL_SCANCODE_APOSTROPHE].ctrl := -1;

  ascii_table[SDL_SCANCODE_BACKSLASH].normal := KEY_231;
  ascii_table[SDL_SCANCODE_BACKSLASH].shift := KEY_199;
  ascii_table[SDL_SCANCODE_BACKSLASH].left_alt := -1;
  ascii_table[SDL_SCANCODE_BACKSLASH].right_alt := KEY_BRACE_RIGHT;
  ascii_table[SDL_SCANCODE_BACKSLASH].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_M;
  else
    k := SDL_SCANCODE_COMMA;
  end;

  ascii_table[k].normal := KEY_COMMA;
  ascii_table[k].shift := KEY_SEMICOLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_COMMA;
  else
    k := SDL_SCANCODE_PERIOD;
  end;

  ascii_table[k].normal := KEY_DOT;
  ascii_table[k].shift := KEY_COLON;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;

  case kb_layout of
    KEYBOARD_LAYOUT_QWERTY:
      k := SDL_SCANCODE_MINUS;
    KEYBOARD_LAYOUT_FRENCH:
      k := SDL_SCANCODE_6;
  else
    k := SDL_SCANCODE_SLASH;
  end;

  ascii_table[k].normal := KEY_MINUS;
  ascii_table[k].shift := KEY_UNDERSCORE;
  ascii_table[k].left_alt := -1;
  ascii_table[k].right_alt := -1;
  ascii_table[k].ctrl := -1;
end;

// --- Lock status and toggle functions ---

procedure kb_init_lock_status;
var
  modState: Integer;
begin
  modState := SDL_GetModState;

  if (modState and KMOD_CAPS) <> 0 then
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_CAPS_LOCK;

  if (modState and KMOD_NUM) <> 0 then
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_NUM_LOCK;

  if (modState and KMOD_SCROLL) <> 0 then
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_SCROLL_LOCK;
end;

procedure kb_toggle_caps;
begin
  if (kb_lock_flags and MODIFIER_KEY_STATE_CAPS_LOCK) <> 0 then
    kb_lock_flags := kb_lock_flags and (not MODIFIER_KEY_STATE_CAPS_LOCK)
  else
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_CAPS_LOCK;
end;

procedure kb_toggle_num;
begin
  if (kb_lock_flags and MODIFIER_KEY_STATE_NUM_LOCK) <> 0 then
    kb_lock_flags := kb_lock_flags and (not MODIFIER_KEY_STATE_NUM_LOCK)
  else
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_NUM_LOCK;
end;

procedure kb_toggle_scroll;
begin
  if (kb_lock_flags and MODIFIER_KEY_STATE_SCROLL_LOCK) <> 0 then
    kb_lock_flags := kb_lock_flags and (not MODIFIER_KEY_STATE_SCROLL_LOCK)
  else
    kb_lock_flags := kb_lock_flags or MODIFIER_KEY_STATE_SCROLL_LOCK;
end;

// --- Ring buffer functions ---

function kb_buffer_put(key_data: PKeyData): Integer;
begin
  Result := -1;

  if ((kb_put + 1) and (KEY_QUEUE_SIZE - 1)) <> kb_get then
  begin
    kb_buffer[kb_put] := key_data^;
    Inc(kb_put);
    kb_put := kb_put and (KEY_QUEUE_SIZE - 1);
    Result := 0;
  end;
end;

function kb_buffer_get(key_data: PKeyData): Integer;
begin
  Result := -1;

  if kb_get <> kb_put then
  begin
    if key_data <> nil then
      key_data^ := kb_buffer[kb_get];

    Inc(kb_get);
    kb_get := kb_get and (KEY_QUEUE_SIZE - 1);
    Result := 0;
  end;
end;

function kb_buffer_peek(index: Integer; out keyboardEventPtr: PKeyData): Integer;
var
  endIdx: Integer;
  eventIndex: Integer;
begin
  Result := -1;

  if kb_get <> kb_put then
  begin
    if kb_put <= kb_get then
      endIdx := kb_put + KEY_QUEUE_SIZE - kb_get - 1
    else
      endIdx := kb_put - kb_get - 1;

    if index <= endIdx then
    begin
      eventIndex := (kb_get + index) and (KEY_QUEUE_SIZE - 1);
      keyboardEventPtr := @kb_buffer[eventIndex];
      Result := 0;
    end;
  end;
end;

initialization
  kb_scan_to_ascii := @kb_next_ascii_English_US;

end.
