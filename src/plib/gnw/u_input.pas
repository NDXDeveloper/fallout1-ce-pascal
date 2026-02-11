{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/input.h + input.cc
// Input event processing, background tasks, and timing.
unit u_input;

interface

uses
  u_sdl2;

type
  TIdleFunc = procedure; cdecl;
  TFocusFunc = procedure(focused: Integer); cdecl;
  TBackgroundProcess = procedure; cdecl;
  TPauseWinFunc = function: Integer; cdecl;
  TScreenDumpFunc = function(width, height: Integer; buffer, palette: PByte): Integer; cdecl;

function GNW_input_init(use_msec_timer: Integer): Integer;
procedure GNW_input_exit;
function get_input: Integer;
procedure get_input_position(x, y: PInteger);
procedure process_bk;
procedure GNW_add_input_buffer(a1: Integer);
procedure flush_input_buffer;
procedure GNW_do_bk_process;
procedure add_bk_process(f: TBackgroundProcess);
procedure remove_bk_process(f: TBackgroundProcess);
procedure enable_bk;
procedure disable_bk;
procedure register_pause(new_pause_key: Integer; new_pause_win_func: TPauseWinFunc);
procedure dump_screen;
function default_screendump(width, height: Integer; data, palette: PByte): Integer;
procedure register_screendump(new_screendump_key: Integer; new_screendump_func: TScreenDumpFunc);
function get_time: LongWord;
procedure pause_for_tocks(ms: LongWord);
procedure block_for_tocks(ms: LongWord);
function elapsed_time(a1: LongWord): LongWord;
function elapsed_tocks(a1, a2: LongWord): LongWord;
function get_bk_time: LongWord;
procedure set_repeat_rate(rate: LongWord);
function get_repeat_rate: LongWord;
procedure set_repeat_delay(delay: LongWord);
function get_repeat_delay: LongWord;
procedure set_focus_func(new_focus_func: TFocusFunc);
function get_focus_func: TFocusFunc;
procedure set_idle_func(new_idle_func: TIdleFunc);
function get_idle_func: TIdleFunc;
function GNW95_input_init: Integer;
procedure GNW95_input_exit;
procedure GNW95_process_message;
procedure GNW95_clear_time_stamps;
procedure GNW95_lost_focus;

procedure beginTextInput;
procedure endTextInput;

implementation

uses
  SysUtils,
  u_kb, u_mouse, u_dxinput, u_touch, u_winmain,
  u_svga, u_svga_types, u_gnw, u_memory, u_color, u_grbuf, u_rect,
  u_vcr;

type
  TGNW95RepeatStruct = record
    time: LongWord;
    count: Integer;
  end;

const
  INPUT_BUFFER_SIZE = 40;
  MAX_BK_PROCESSES  = 16;

var
  input_buffer: array[0..INPUT_BUFFER_SIZE - 1] of Integer;
  input_buffer_read: Integer = 0;
  input_buffer_write: Integer = 0;

  bk_process_list: array[0..MAX_BK_PROCESSES - 1] of TBackgroundProcess;
  bk_process_count: Integer = 0;
  bk_enabled: Boolean = True;

  idle_func: TIdleFunc = nil;
  focus_func: TFocusFunc = nil;
  pause_key: Integer = -1;
  pause_win_func: TPauseWinFunc = nil;
  screendump_key: Integer = -1;
  screendump_func: TScreenDumpFunc = nil;

  repeat_rate: LongWord = 80;
  repeat_delay: LongWord = 500;

  bk_time: LongWord = 0;
  input_mx: Integer = 0;
  input_my: Integer = 0;
  screendump_buf: PByte = nil;

  GNW95_key_map: array[0..SDL_NUM_SCANCODES - 1] of Integer;
  GNW95_key_time_stamps: array[0..SDL_NUM_SCANCODES - 1] of TGNW95RepeatStruct;

procedure screendump_buf_blit(srcBuf: PByte; srcW, srcH, subX, subY,
  subW, subH, dstX, dstY: LongWord); cdecl;
var
  screenWidth: Integer;
begin
  screenWidth := scr_size.lrx - scr_size.ulx + 1;
  buf_to_buf(srcBuf + srcW * subY + subX, Integer(subW), Integer(subH), Integer(srcW),
    screendump_buf + dstY * LongWord(screenWidth) + dstX, screenWidth);
end;

procedure GNW95_build_key_map;
var
  k: Integer;
begin
  FillChar(GNW95_key_map, SizeOf(GNW95_key_map), 0);

  GNW95_key_map[SDL_SCANCODE_ESCAPE] := SDL_SCANCODE_ESCAPE;
  GNW95_key_map[SDL_SCANCODE_1] := SDL_SCANCODE_1;
  GNW95_key_map[SDL_SCANCODE_2] := SDL_SCANCODE_2;
  GNW95_key_map[SDL_SCANCODE_3] := SDL_SCANCODE_3;
  GNW95_key_map[SDL_SCANCODE_4] := SDL_SCANCODE_4;
  GNW95_key_map[SDL_SCANCODE_5] := SDL_SCANCODE_5;
  GNW95_key_map[SDL_SCANCODE_6] := SDL_SCANCODE_6;
  GNW95_key_map[SDL_SCANCODE_7] := SDL_SCANCODE_7;
  GNW95_key_map[SDL_SCANCODE_8] := SDL_SCANCODE_8;
  GNW95_key_map[SDL_SCANCODE_9] := SDL_SCANCODE_9;
  GNW95_key_map[SDL_SCANCODE_0] := SDL_SCANCODE_0;

  case kb_layout of
    1: k := SDL_SCANCODE_6;
  else k := SDL_SCANCODE_MINUS;
  end;
  GNW95_key_map[SDL_SCANCODE_MINUS] := k;

  case kb_layout of
    1: k := SDL_SCANCODE_0;
  else k := SDL_SCANCODE_EQUALS;
  end;
  GNW95_key_map[SDL_SCANCODE_EQUALS] := k;

  GNW95_key_map[SDL_SCANCODE_BACKSPACE] := SDL_SCANCODE_BACKSPACE;
  GNW95_key_map[SDL_SCANCODE_TAB] := SDL_SCANCODE_TAB;

  case kb_layout of
    1: k := SDL_SCANCODE_A;
  else k := SDL_SCANCODE_Q;
  end;
  GNW95_key_map[SDL_SCANCODE_Q] := k;

  case kb_layout of
    1: k := SDL_SCANCODE_Z;
  else k := SDL_SCANCODE_W;
  end;
  GNW95_key_map[SDL_SCANCODE_W] := k;

  GNW95_key_map[SDL_SCANCODE_E] := SDL_SCANCODE_E;
  GNW95_key_map[SDL_SCANCODE_R] := SDL_SCANCODE_R;
  GNW95_key_map[SDL_SCANCODE_T] := SDL_SCANCODE_T;

  case kb_layout of
    0, 1, 3, 4: k := SDL_SCANCODE_Y;
  else k := SDL_SCANCODE_Z;
  end;
  GNW95_key_map[SDL_SCANCODE_Y] := k;

  GNW95_key_map[SDL_SCANCODE_U] := SDL_SCANCODE_U;
  GNW95_key_map[SDL_SCANCODE_I] := SDL_SCANCODE_I;
  GNW95_key_map[SDL_SCANCODE_O] := SDL_SCANCODE_O;
  GNW95_key_map[SDL_SCANCODE_P] := SDL_SCANCODE_P;

  case kb_layout of
    0, 3, 4: k := SDL_SCANCODE_LEFTBRACKET;
    1: k := SDL_SCANCODE_5;
  else k := SDL_SCANCODE_8;
  end;
  GNW95_key_map[SDL_SCANCODE_LEFTBRACKET] := k;

  case kb_layout of
    0, 3, 4: k := SDL_SCANCODE_RIGHTBRACKET;
    1: k := SDL_SCANCODE_MINUS;
  else k := SDL_SCANCODE_9;
  end;
  GNW95_key_map[SDL_SCANCODE_RIGHTBRACKET] := k;

  GNW95_key_map[SDL_SCANCODE_RETURN] := SDL_SCANCODE_RETURN;
  GNW95_key_map[SDL_SCANCODE_LCTRL] := SDL_SCANCODE_LCTRL;

  case kb_layout of
    1: k := SDL_SCANCODE_Q;
  else k := SDL_SCANCODE_A;
  end;
  GNW95_key_map[SDL_SCANCODE_A] := k;

  GNW95_key_map[SDL_SCANCODE_S] := SDL_SCANCODE_S;
  GNW95_key_map[SDL_SCANCODE_D] := SDL_SCANCODE_D;
  GNW95_key_map[SDL_SCANCODE_F] := SDL_SCANCODE_F;
  GNW95_key_map[SDL_SCANCODE_G] := SDL_SCANCODE_G;
  GNW95_key_map[SDL_SCANCODE_H] := SDL_SCANCODE_H;
  GNW95_key_map[SDL_SCANCODE_J] := SDL_SCANCODE_J;
  GNW95_key_map[SDL_SCANCODE_K] := SDL_SCANCODE_K;
  GNW95_key_map[SDL_SCANCODE_L] := SDL_SCANCODE_L;

  case kb_layout of
    0: k := SDL_SCANCODE_SEMICOLON;
  else k := SDL_SCANCODE_COMMA;
  end;
  GNW95_key_map[SDL_SCANCODE_SEMICOLON] := k;

  case kb_layout of
    0: k := SDL_SCANCODE_APOSTROPHE;
    1: k := SDL_SCANCODE_4;
  else k := SDL_SCANCODE_MINUS;
  end;
  GNW95_key_map[SDL_SCANCODE_APOSTROPHE] := k;

  case kb_layout of
    0: k := SDL_SCANCODE_GRAVE;
    1: k := SDL_SCANCODE_2;
    3, 4: k := 0;
  else k := SDL_SCANCODE_RIGHTBRACKET;
  end;
  GNW95_key_map[SDL_SCANCODE_GRAVE] := k;

  GNW95_key_map[SDL_SCANCODE_LSHIFT] := SDL_SCANCODE_LSHIFT;

  case kb_layout of
    0: k := SDL_SCANCODE_BACKSLASH;
    1: k := SDL_SCANCODE_8;
    3, 4: k := SDL_SCANCODE_GRAVE;
  else k := SDL_SCANCODE_Y;
  end;
  GNW95_key_map[SDL_SCANCODE_BACKSLASH] := k;

  case kb_layout of
    0, 3, 4: k := SDL_SCANCODE_Z;
    1: k := SDL_SCANCODE_W;
  else k := SDL_SCANCODE_Y;
  end;
  GNW95_key_map[SDL_SCANCODE_Z] := k;

  GNW95_key_map[SDL_SCANCODE_X] := SDL_SCANCODE_X;
  GNW95_key_map[SDL_SCANCODE_C] := SDL_SCANCODE_C;
  GNW95_key_map[SDL_SCANCODE_V] := SDL_SCANCODE_V;
  GNW95_key_map[SDL_SCANCODE_B] := SDL_SCANCODE_B;
  GNW95_key_map[SDL_SCANCODE_N] := SDL_SCANCODE_N;

  case kb_layout of
    1: k := SDL_SCANCODE_SEMICOLON;
  else k := SDL_SCANCODE_M;
  end;
  GNW95_key_map[SDL_SCANCODE_M] := k;

  case kb_layout of
    1: k := SDL_SCANCODE_M;
  else k := SDL_SCANCODE_COMMA;
  end;
  GNW95_key_map[SDL_SCANCODE_COMMA] := k;

  case kb_layout of
    1: k := SDL_SCANCODE_COMMA;
  else k := SDL_SCANCODE_PERIOD;
  end;
  GNW95_key_map[SDL_SCANCODE_PERIOD] := k;

  case kb_layout of
    0: k := SDL_SCANCODE_SLASH;
    1: k := SDL_SCANCODE_PERIOD;
  else k := SDL_SCANCODE_7;
  end;
  GNW95_key_map[SDL_SCANCODE_SLASH] := k;

  GNW95_key_map[SDL_SCANCODE_RSHIFT] := SDL_SCANCODE_RSHIFT;
  GNW95_key_map[SDL_SCANCODE_KP_MULTIPLY] := SDL_SCANCODE_KP_MULTIPLY;
  GNW95_key_map[SDL_SCANCODE_SPACE] := SDL_SCANCODE_SPACE;
  GNW95_key_map[SDL_SCANCODE_LALT] := SDL_SCANCODE_LALT;
  GNW95_key_map[SDL_SCANCODE_CAPSLOCK] := SDL_SCANCODE_CAPSLOCK;

  GNW95_key_map[SDL_SCANCODE_F1] := SDL_SCANCODE_F1;
  GNW95_key_map[SDL_SCANCODE_F2] := SDL_SCANCODE_F2;
  GNW95_key_map[SDL_SCANCODE_F3] := SDL_SCANCODE_F3;
  GNW95_key_map[SDL_SCANCODE_F4] := SDL_SCANCODE_F4;
  GNW95_key_map[SDL_SCANCODE_F5] := SDL_SCANCODE_F5;
  GNW95_key_map[SDL_SCANCODE_F6] := SDL_SCANCODE_F6;
  GNW95_key_map[SDL_SCANCODE_F7] := SDL_SCANCODE_F7;
  GNW95_key_map[SDL_SCANCODE_F8] := SDL_SCANCODE_F8;
  GNW95_key_map[SDL_SCANCODE_F9] := SDL_SCANCODE_F9;
  GNW95_key_map[SDL_SCANCODE_F10] := SDL_SCANCODE_F10;
  GNW95_key_map[SDL_SCANCODE_NUMLOCKCLEAR] := SDL_SCANCODE_NUMLOCKCLEAR;
  GNW95_key_map[SDL_SCANCODE_SCROLLLOCK] := SDL_SCANCODE_SCROLLLOCK;
  GNW95_key_map[SDL_SCANCODE_KP_7] := SDL_SCANCODE_KP_7;
  GNW95_key_map[SDL_SCANCODE_KP_8] := SDL_SCANCODE_KP_8;
  GNW95_key_map[SDL_SCANCODE_KP_9] := SDL_SCANCODE_KP_9;
  GNW95_key_map[SDL_SCANCODE_KP_MINUS] := SDL_SCANCODE_KP_MINUS;
  GNW95_key_map[SDL_SCANCODE_KP_4] := SDL_SCANCODE_KP_4;
  GNW95_key_map[SDL_SCANCODE_KP_5] := SDL_SCANCODE_KP_5;
  GNW95_key_map[SDL_SCANCODE_KP_6] := SDL_SCANCODE_KP_6;
  GNW95_key_map[SDL_SCANCODE_KP_PLUS] := SDL_SCANCODE_KP_PLUS;
  GNW95_key_map[SDL_SCANCODE_KP_1] := SDL_SCANCODE_KP_1;
  GNW95_key_map[SDL_SCANCODE_KP_2] := SDL_SCANCODE_KP_2;
  GNW95_key_map[SDL_SCANCODE_KP_3] := SDL_SCANCODE_KP_3;
  GNW95_key_map[SDL_SCANCODE_KP_0] := SDL_SCANCODE_KP_0;
  GNW95_key_map[SDL_SCANCODE_KP_DECIMAL] := SDL_SCANCODE_KP_DECIMAL;
  GNW95_key_map[SDL_SCANCODE_F11] := SDL_SCANCODE_F11;
  GNW95_key_map[SDL_SCANCODE_F12] := SDL_SCANCODE_F12;
  GNW95_key_map[SDL_SCANCODE_F13] := -1;
  GNW95_key_map[SDL_SCANCODE_F14] := -1;
  GNW95_key_map[SDL_SCANCODE_F15] := -1;
  GNW95_key_map[SDL_SCANCODE_KP_EQUALS] := -1;
  GNW95_key_map[SDL_SCANCODE_STOP] := -1;
  GNW95_key_map[SDL_SCANCODE_KP_ENTER] := SDL_SCANCODE_KP_ENTER;
  GNW95_key_map[SDL_SCANCODE_RCTRL] := SDL_SCANCODE_RCTRL;
  GNW95_key_map[SDL_SCANCODE_KP_COMMA] := -1;
  GNW95_key_map[SDL_SCANCODE_KP_DIVIDE] := SDL_SCANCODE_KP_DIVIDE;
  GNW95_key_map[SDL_SCANCODE_RALT] := SDL_SCANCODE_RALT;
  GNW95_key_map[SDL_SCANCODE_HOME] := SDL_SCANCODE_HOME;
  GNW95_key_map[SDL_SCANCODE_UP] := SDL_SCANCODE_UP;
  GNW95_key_map[SDL_SCANCODE_PRIOR] := SDL_SCANCODE_PRIOR;
  GNW95_key_map[SDL_SCANCODE_LEFT] := SDL_SCANCODE_LEFT;
  GNW95_key_map[SDL_SCANCODE_RIGHT] := SDL_SCANCODE_RIGHT;
  GNW95_key_map[SDL_SCANCODE_END] := SDL_SCANCODE_END;
  GNW95_key_map[SDL_SCANCODE_DOWN] := SDL_SCANCODE_DOWN;
  GNW95_key_map[SDL_SCANCODE_PAGEDOWN] := SDL_SCANCODE_PAGEDOWN;
  GNW95_key_map[SDL_SCANCODE_INSERT] := SDL_SCANCODE_INSERT;
  GNW95_key_map[SDL_SCANCODE_DELETE] := SDL_SCANCODE_DELETE;
  GNW95_key_map[SDL_SCANCODE_LGUI] := -1;
  GNW95_key_map[SDL_SCANCODE_RGUI] := -1;
  GNW95_key_map[SDL_SCANCODE_APPLICATION] := -1;
end;

procedure GNW95_process_key(data: PKeyboardData);
var
  scanCode: Integer;
begin
  scanCode := data^.Key;
  data^.Key := GNW95_key_map[data^.Key];

  if vcr_state = VCR_STATE_PLAYING then
  begin
    if (vcr_terminate_flags and VCR_TERMINATE_ON_KEY_PRESS) <> 0 then
    begin
      vcr_terminated_condition := VCR_PLAYBACK_COMPLETION_REASON_TERMINATED;
      vcr_stop;
    end;
  end
  else
  begin
    if data^.Down = 1 then
    begin
      GNW95_key_time_stamps[scanCode].time := SDL_GetTicks;
      GNW95_key_time_stamps[scanCode].count := 0;
    end
    else
      GNW95_key_time_stamps[scanCode].time := LongWord(-1);

    if data^.Key = -1 then
      Exit;

    kb_simulate_key(data);
  end;
end;

function GNW_input_init(use_msec_timer: Integer): Integer;
begin
  if GNW95_input_init <> 0 then
    Exit(-1);

  input_buffer_read := 0;
  input_buffer_write := 0;
  bk_process_count := 0;
  bk_enabled := True;
  idle_func := nil;
  focus_func := nil;

  GNW95_build_key_map;
  GNW_kb_set;
  GNW_mouse_init;
  GNW95_clear_time_stamps;

  Result := 0;
end;

procedure GNW_input_exit;
begin
  GNW_mouse_exit;
  GNW_kb_restore;
  GNW95_input_exit;
end;

function get_input: Integer;
var
  rc: Integer;
  mouseButtons: Integer;
begin
  GNW95_process_message;

  if not GNW95_isActive then
  begin
    GNW95_lost_focus;
    GNW95_isActive := True;
  end;

  process_bk;

  if input_buffer_read <> input_buffer_write then
  begin
    rc := input_buffer[input_buffer_read];
    input_buffer_read := (input_buffer_read + 1) mod INPUT_BUFFER_SIZE;
  end
  else
  begin
    rc := -1;
    if Assigned(idle_func) then
      idle_func();
  end;

  // Check for mouse button events (down or up)
  // $33 = MOUSE_EVENT_ANY_BUTTON_DOWN | MOUSE_EVENT_ANY_BUTTON_UP
  if rc = -1 then
  begin
    mouseButtons := mouse_get_buttons;
    if (mouseButtons and $33) <> 0 then
    begin
      mouse_get_position(@input_mx, @input_my);
      Exit(-2);
    end;
  end;

  Result := GNW_check_menu_bars(rc);
end;

procedure get_input_position(x, y: PInteger);
begin
  x^ := input_mx;
  y^ := input_my;
end;

procedure process_bk;
var
  v1: Integer;
begin
  GNW_do_bk_process;

  if vcr_update <> 3 then
    mouse_info;

  v1 := win_check_all_buttons;
  if v1 <> -1 then
  begin
    WriteLn(StdErr, '[INPUT] button keyCode=', v1);
    GNW_add_input_buffer(v1);
    Exit;
  end;

  v1 := kb_getch;
  if v1 <> -1 then
  begin
    GNW_add_input_buffer(v1);
    Exit;
  end;
end;

procedure GNW_add_input_buffer(a1: Integer);
var
  next_write: Integer;
begin
  next_write := (input_buffer_write + 1) mod INPUT_BUFFER_SIZE;
  if next_write <> input_buffer_read then
  begin
    input_buffer[input_buffer_write] := a1;
    input_buffer_write := next_write;
  end;
end;

procedure flush_input_buffer;
begin
  input_buffer_read := 0;
  input_buffer_write := 0;
end;

procedure GNW_do_bk_process;
var
  i: Integer;
begin
  for i := 0 to bk_process_count - 1 do
    if Assigned(bk_process_list[i]) then
      bk_process_list[i]();
end;

procedure add_bk_process(f: TBackgroundProcess);
begin
  if bk_process_count < MAX_BK_PROCESSES then
  begin
    bk_process_list[bk_process_count] := f;
    Inc(bk_process_count);
  end;
end;

procedure remove_bk_process(f: TBackgroundProcess);
var
  i, j: Integer;
begin
  for i := 0 to bk_process_count - 1 do
  begin
    if bk_process_list[i] = f then
    begin
      for j := i to bk_process_count - 2 do
        bk_process_list[j] := bk_process_list[j + 1];
      Dec(bk_process_count);
      Break;
    end;
  end;
end;

procedure enable_bk;
begin
  bk_enabled := True;
end;

procedure disable_bk;
begin
  bk_enabled := False;
end;

procedure register_pause(new_pause_key: Integer; new_pause_win_func: TPauseWinFunc);
begin
  pause_key := new_pause_key;
  pause_win_func := new_pause_win_func;
end;

procedure dump_screen;
var
  old_scr_blit: TScreenBlitFunc;
  old_mouse_blit_val: TScreenBlitFunc;
  old_mouse_blit_trans_val: TScreenTransBlitFunc;
  width, length_: Integer;
  pal: PByte;
begin
  if not Assigned(screendump_func) then
    Exit;

  width := scr_size.lrx - scr_size.ulx + 1;
  length_ := scr_size.lry - scr_size.uly + 1;

  screendump_buf := PByte(mem_malloc(width * length_));
  if screendump_buf = nil then
    Exit;

  old_scr_blit := scr_blit;
  scr_blit := @screendump_buf_blit;

  old_mouse_blit_val := mouse_blit;
  mouse_blit := @screendump_buf_blit;

  old_mouse_blit_trans_val := mouse_blit_trans;
  mouse_blit_trans := nil;

  win_refresh_all(@scr_size);

  mouse_blit_trans := old_mouse_blit_trans_val;
  mouse_blit := old_mouse_blit_val;
  scr_blit := old_scr_blit;

  pal := getSystemPalette;
  screendump_func(width, length_, screendump_buf, pal);
  mem_free(screendump_buf);
end;

function default_screendump(width, height: Integer; data, palette: PByte): Integer;
var
  fileName: string;
  f: Integer;
  index, y: Integer;
  intValue: LongWord;
  shortValue: Word;
  rgbBlue, rgbGreen, rgbRed, rgbReserved: Byte;
begin
  // Find unique filename
  index := 0;
  while index < 100000 do
  begin
    fileName := Format('scr%.5d.bmp', [index]);
    if not FileExists(fileName) then
      Break;
    Inc(index);
  end;

  if index = 100000 then
    Exit(-1);

  f := FileCreate(fileName);
  if f < 0 then
    Exit(-1);

  // BMP file header (14 bytes)
  shortValue := $4D42;
  FileWrite(f, shortValue, 2);

  intValue := LongWord(width * height) + 14 + 40 + 1024;
  FileWrite(f, intValue, 4);

  shortValue := 0;
  FileWrite(f, shortValue, 2);
  FileWrite(f, shortValue, 2);

  intValue := 14 + 40 + 1024;
  FileWrite(f, intValue, 4);

  // BMP info header (40 bytes)
  intValue := 40;
  FileWrite(f, intValue, 4);

  intValue := LongWord(width);
  FileWrite(f, intValue, 4);

  intValue := LongWord(height);
  FileWrite(f, intValue, 4);

  shortValue := 1;
  FileWrite(f, shortValue, 2);

  shortValue := 8;
  FileWrite(f, shortValue, 2);

  intValue := 0;
  FileWrite(f, intValue, 4);
  FileWrite(f, intValue, 4);
  FileWrite(f, intValue, 4);
  FileWrite(f, intValue, 4);
  FileWrite(f, intValue, 4);
  FileWrite(f, intValue, 4);

  // Palette (256 RGBQUAD entries)
  for index := 0 to 255 do
  begin
    rgbRed := palette[index * 3] shl 2;
    rgbGreen := palette[index * 3 + 1] shl 2;
    rgbBlue := palette[index * 3 + 2] shl 2;
    rgbReserved := 0;
    FileWrite(f, rgbBlue, 1);
    FileWrite(f, rgbGreen, 1);
    FileWrite(f, rgbRed, 1);
    FileWrite(f, rgbReserved, 1);
  end;

  // Pixel data bottom-to-top
  for y := height - 1 downto 0 do
    FileWrite(f, data[y * width], width);

  FileClose(f);
  Result := 0;
end;

procedure register_screendump(new_screendump_key: Integer; new_screendump_func: TScreenDumpFunc);
begin
  screendump_key := new_screendump_key;
  screendump_func := new_screendump_func;
end;

function get_time: LongWord;
begin
  Result := SDL_GetTicks;
end;

procedure pause_for_tocks(ms: LongWord);
var
  start: LongWord;
begin
  start := SDL_GetTicks;
  while (SDL_GetTicks - start) < ms do
  begin
    process_bk;
    SDL_Delay(1);
  end;
end;

procedure block_for_tocks(ms: LongWord);
begin
  SDL_Delay(ms);
end;

function elapsed_time(a1: LongWord): LongWord;
begin
  Result := SDL_GetTicks - a1;
end;

function elapsed_tocks(a1, a2: LongWord): LongWord;
begin
  {$PUSH}{$R-}{$Q-}
  Result := a2 - a1;
  {$POP}
end;

function get_bk_time: LongWord;
begin
  Result := bk_time;
end;

procedure set_repeat_rate(rate: LongWord);
begin
  repeat_rate := rate;
end;

function get_repeat_rate: LongWord;
begin
  Result := repeat_rate;
end;

procedure set_repeat_delay(delay: LongWord);
begin
  repeat_delay := delay;
end;

function get_repeat_delay: LongWord;
begin
  Result := repeat_delay;
end;

procedure set_focus_func(new_focus_func: TFocusFunc);
begin
  focus_func := new_focus_func;
end;

function get_focus_func: TFocusFunc;
begin
  Result := focus_func;
end;

procedure set_idle_func(new_idle_func: TIdleFunc);
begin
  idle_func := new_idle_func;
end;

function get_idle_func: TIdleFunc;
begin
  Result := idle_func;
end;

function GNW95_input_init: Integer;
begin
  if not dxinput_init then
    Exit(-1);
  dxinput_acquire_mouse;
  dxinput_acquire_keyboard;
  Result := 0;
end;

procedure GNW95_input_exit;
begin
  dxinput_unacquire_mouse;
  dxinput_unacquire_keyboard;
  dxinput_exit;
end;

procedure GNW95_process_message;
var
  event: TSDL_Event;
  keyboardData: TKeyboardData;
  tick, elapsedTime, delay_: LongWord;
  key: Integer;
begin
  while SDL_PollEvent(@event) <> 0 do
  begin
    case event.type_ of
      SDL_QUIT_EVENT:
        Halt(0);
      SDL_WINDOWEVENT:
      begin
        case event.window.event of
          SDL_WINDOWEVENT_EXPOSED:
            win_refresh_all(@scr_size);
          SDL_WINDOWEVENT_SIZE_CHANGED:
            win_refresh_all(@scr_size);
          SDL_WINDOWEVENT_FOCUS_GAINED:
          begin
            GNW95_isActive := True;
            win_refresh_all(@scr_size);
          end;
          SDL_WINDOWEVENT_FOCUS_LOST:
            GNW95_isActive := False;
        end;
      end;
      SDL_MOUSEMOTION, SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEWHEEL:
        handleMouseEvent(@event);
      SDL_FINGERDOWN:
        touch_handle_start(@event.tfinger);
      SDL_FINGERMOTION:
        touch_handle_move(@event.tfinger);
      SDL_FINGERUP:
        touch_handle_end(@event.tfinger);
      SDL_KEYDOWN, SDL_KEYUP:
      begin
        if not kb_is_disabled then
        begin
          keyboardData.Key := event.key.scancode;
          if (event.key.state and SDL_PRESSED) <> 0 then
            keyboardData.Down := 1
          else
            keyboardData.Down := 0;
          GNW95_process_key(@keyboardData);
        end;
      end;
    end;
  end;

  touch_process_gesture;

  // Key repeat handling
  if GNW95_isActive and (not kb_is_disabled) then
  begin
    tick := SDL_GetTicks;
    for key := 0 to SDL_NUM_SCANCODES - 1 do
    begin
      if GNW95_key_time_stamps[key].time <> LongWord(-1) then
      begin
        if GNW95_key_time_stamps[key].time > tick then
          elapsedTime := High(LongWord)
        else
          elapsedTime := tick - GNW95_key_time_stamps[key].time;

        if GNW95_key_time_stamps[key].count = 0 then
          delay_ := repeat_delay
        else
          delay_ := repeat_rate;

        if elapsedTime > delay_ then
        begin
          keyboardData.Key := key;
          keyboardData.Down := 1;
          GNW95_process_key(@keyboardData);
          GNW95_key_time_stamps[key].time := tick;
          Inc(GNW95_key_time_stamps[key].count);
        end;
      end;
    end;
  end;
end;

procedure GNW95_clear_time_stamps;
var
  i: Integer;
begin
  for i := 0 to SDL_NUM_SCANCODES - 1 do
  begin
    GNW95_key_time_stamps[i].time := LongWord(-1);
    GNW95_key_time_stamps[i].count := 0;
  end;
  kb_reset_elapsed_time;
  mouse_reset_elapsed_time;
end;

procedure GNW95_lost_focus;
begin
  if Assigned(focus_func) then
    focus_func(0);
end;

procedure beginTextInput;
begin
  SDL_StartTextInput;
end;

procedure endTextInput;
begin
  SDL_StopTextInput;
end;

end.
