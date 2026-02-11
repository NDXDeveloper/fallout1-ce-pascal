{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/mouse.h + mouse.cc
// Mouse input, cursor management, and hit testing.
unit u_mouse;

interface

uses
  u_rect, u_svga_types;

const
  MOUSE_DEFAULT_CURSOR_WIDTH  = 8;
  MOUSE_DEFAULT_CURSOR_HEIGHT = 8;
  MOUSE_DEFAULT_CURSOR_SIZE   = MOUSE_DEFAULT_CURSOR_WIDTH * MOUSE_DEFAULT_CURSOR_HEIGHT;

  MOUSE_STATE_LEFT_BUTTON_DOWN  = $01;
  MOUSE_STATE_RIGHT_BUTTON_DOWN = $02;

  MOUSE_EVENT_LEFT_BUTTON_DOWN         = $01;
  MOUSE_EVENT_RIGHT_BUTTON_DOWN        = $02;
  MOUSE_EVENT_LEFT_BUTTON_REPEAT       = $04;
  MOUSE_EVENT_RIGHT_BUTTON_REPEAT      = $08;
  MOUSE_EVENT_LEFT_BUTTON_UP           = $10;
  MOUSE_EVENT_RIGHT_BUTTON_UP          = $20;
  MOUSE_EVENT_ANY_BUTTON_DOWN          = MOUSE_EVENT_LEFT_BUTTON_DOWN or MOUSE_EVENT_RIGHT_BUTTON_DOWN;
  MOUSE_EVENT_ANY_BUTTON_REPEAT        = MOUSE_EVENT_LEFT_BUTTON_REPEAT or MOUSE_EVENT_RIGHT_BUTTON_REPEAT;
  MOUSE_EVENT_ANY_BUTTON_UP            = MOUSE_EVENT_LEFT_BUTTON_UP or MOUSE_EVENT_RIGHT_BUTTON_UP;
  MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT  = MOUSE_EVENT_LEFT_BUTTON_DOWN or MOUSE_EVENT_LEFT_BUTTON_REPEAT;
  MOUSE_EVENT_RIGHT_BUTTON_DOWN_REPEAT = MOUSE_EVENT_RIGHT_BUTTON_DOWN or MOUSE_EVENT_RIGHT_BUTTON_REPEAT;
  MOUSE_EVENT_WHEEL                    = $40;

  BUTTON_REPEAT_TIME = 250;

var
  mouse_blit_trans: TScreenTransBlitFunc;
  mouse_blit: TScreenBlitFunc;

function GNW_mouse_init: Integer;
procedure GNW_mouse_exit;
procedure mouse_get_shape(out buf: PByte; out width, length_, full, hotx, hoty: Integer; out trans: AnsiChar);
function mouse_set_shape(buf: PByte; width, length_, full, hotx, hoty: Integer; trans: AnsiChar): Integer;
function mouse_get_anim(out frames: PByte; out num_frames, width, length_, hotx, hoty: Integer; out trans: AnsiChar; out speed: Integer): Integer;
function mouse_set_anim_frames(frames: PByte; num_frames, start_frame, width, length_, hotx, hoty: Integer; trans: AnsiChar; speed: Integer): Integer;
procedure mouse_show;
procedure mouse_hide;
procedure mouse_info;
procedure mouse_simulate_input(delta_x, delta_y, buttons: Integer);
function mouse_in(left, top, right, bottom: Integer): Boolean;
function mouse_click_in(left, top, right, bottom: Integer): Boolean;
procedure mouse_get_rect(rect: PRect);
procedure mouse_get_position(x, y: PInteger);
procedure mouse_set_position(x, y: Integer);
function mouse_get_buttons: Integer;
function mouse_hidden: Boolean;
procedure mouse_get_hotspot(hotx, hoty: PInteger);
procedure mouse_set_hotspot(hotx, hoty: Integer);
function mouse_query_exist: Boolean;
procedure mouse_get_raw_state(x, y: PInteger; buttons: PInteger);
procedure mouse_disable;
procedure mouse_enable;
function mouse_is_disabled: Boolean;
procedure mouse_set_sensitivity(value: Double);
function mouse_get_sensitivity: Double;
function mouse_elapsed_time: LongWord;
procedure mouse_reset_elapsed_time;

procedure mouseGetPositionInWindow(win: Integer; x, y: PInteger);
function mouseHitTestInWindow(win: Integer; left, top, right, bottom: Integer): Boolean;
procedure mouseGetWheel(x, y: PInteger);
procedure convertMouseWheelToArrowKey(keyCodePtr: PInteger);

implementation

uses
  u_sdl2, u_dxinput, u_vcr, u_touch, u_svga, u_input, u_color, u_memory, u_gnw;

// Default cursor mask: 0=transparent, 1=white border, 15=black fill
var
  or_mask: array[0..MOUSE_DEFAULT_CURSOR_SIZE - 1] of Byte = (
    1,  1,  1,  1,  1,  1,  1, 0,
    1, 15, 15, 15, 15, 15,  1, 0,
    1, 15, 15, 15, 15,  1,  1, 0,
    1, 15, 15, 15, 15,  1,  1, 0,
    1, 15, 15, 15, 15, 15,  1, 1,
    1, 15,  1,  1, 15, 15, 15, 1,
    1,  1,  1,  1,  1, 15, 15, 1,
    0,  0,  0,  0,  1,  1,  1, 1
  );

procedure mouse_colorize; forward;

var
  mouse_x: Integer = 0;
  mouse_y: Integer = 0;
  mouse_buttons: Integer = 0;       // raw button state (MOUSE_STATE_* flags)
  mouse_event: Integer = 0;         // event flags (MOUSE_EVENT_* flags), returned by mouse_get_buttons
  raw_buttons: Integer = 0;         // copy of mouse_event
  mouse_is_hidden: Boolean = True;
  mouse_exists: Boolean = False;
  mouse_disabled: Boolean = False;
  mouse_hotspot_x: Integer = 0;
  mouse_hotspot_y: Integer = 0;
  mouse_cursor_width: Integer = MOUSE_DEFAULT_CURSOR_WIDTH;
  mouse_cursor_height: Integer = MOUSE_DEFAULT_CURSOR_HEIGHT;
  mouse_full: Integer = MOUSE_DEFAULT_CURSOR_WIDTH;
  mouse_trans: AnsiChar = #0;
  mouse_sensitivity: Double = 1.0;
  mouse_start_time: LongWord = 0;
  mouse_wheel_x: Integer = 0;
  mouse_wheel_y: Integer = 0;

  // Button repeat timing
  left_time: LongWord = 0;
  right_time: LongWord = 0;

  // Idle tracking
  mouse_idling: Boolean = False;
  mouse_idle_start_time: LongWord = 0;

  // Animation
  mouse_fptr: PByte = nil;
  mouse_num_frames: Integer = 0;
  mouse_curr_frame: Integer = 0;
  mouse_speed: Integer = 0;
  mouse_anim_ticker: LongWord = 0;

  // Cursor rendering
  mouse_buf: PByte = nil;
  mouse_shape: PByte = nil;
  have_mouse: Boolean = False;
  mouse_length: Integer = 0;
  mouse_width: Integer = 0;

  // Touch gesture previous position
  touch_prev_x: Integer = 0;
  touch_prev_y: Integer = 0;

procedure mouse_colorize;
var
  index: Integer;
begin
  for index := 0 to MOUSE_DEFAULT_CURSOR_SIZE - 1 do
  begin
    case or_mask[index] of
      0: or_mask[index] := colorTable[0];
      1: or_mask[index] := colorTable[8456];
      15: or_mask[index] := colorTable[32767];
    end;
  end;
end;

procedure mouse_clip;
begin
  if mouse_x <= scr_size.ulx then
    mouse_x := scr_size.ulx;
  if mouse_x >= scr_size.lrx then
    mouse_x := scr_size.lrx;
  if mouse_y <= scr_size.uly then
    mouse_y := scr_size.uly;
  if mouse_y >= scr_size.lry then
    mouse_y := scr_size.lry;
end;

procedure mouse_anim; cdecl;
begin
  if (SDL_GetTicks - mouse_anim_ticker) >= LongWord(mouse_speed) then
  begin
    mouse_anim_ticker := SDL_GetTicks;
    Inc(mouse_curr_frame);
    if mouse_curr_frame >= mouse_num_frames then
      mouse_curr_frame := 0;
    mouse_set_shape(mouse_fptr + mouse_curr_frame * mouse_full * mouse_cursor_height,
      mouse_full, mouse_cursor_height, mouse_full,
      mouse_hotspot_x, mouse_hotspot_y, mouse_trans);
  end;
end;

function GNW_mouse_init: Integer;
begin
  have_mouse := False;
  mouse_disabled := False;
  mouse_is_hidden := True;

  mouse_colorize;

  if mouse_set_shape(nil, 0, 0, 0, 0, 0, #0) = -1 then
    Exit(-1);

  if not dxinput_acquire_mouse then
    Exit(-1);

  have_mouse := True;
  mouse_exists := True;
  mouse_x := scr_size.lrx div 2;
  mouse_y := scr_size.lry div 2;
  mouse_buttons := 0;
  mouse_idle_start_time := get_time;
  mouse_start_time := SDL_GetTicks;
  Result := 0;
end;

procedure GNW_mouse_exit;
begin
  mouse_exists := False;
end;

procedure mouse_get_shape(out buf: PByte; out width, length_, full, hotx, hoty: Integer; out trans: AnsiChar);
begin
  buf := nil;
  width := mouse_cursor_width;
  length_ := mouse_cursor_height;
  full := mouse_cursor_width;
  hotx := mouse_hotspot_x;
  hoty := mouse_hotspot_y;
  trans := #0;
end;

function mouse_set_shape(buf: PByte; width, length_, full, hotx, hoty: Integer; trans: AnsiChar): Integer;
var
  rect: TRect;
  cursorWasHidden: Boolean;
  newBuf: PByte;
  v11, v12: Integer;
begin
  // Handle NULL buf - use default cursor
  if buf = nil then
    Exit(mouse_set_shape(@or_mask[0], MOUSE_DEFAULT_CURSOR_WIDTH, MOUSE_DEFAULT_CURSOR_HEIGHT,
      MOUSE_DEFAULT_CURSOR_WIDTH, 1, 1, AnsiChar(colorTable[0])));

  cursorWasHidden := mouse_is_hidden;
  if (not mouse_is_hidden) and have_mouse then
  begin
    mouse_is_hidden := True;
    mouse_get_rect(@rect);
    win_refresh_all(@rect);
  end;

  // Allocate new buffer if size changed
  if (width <> mouse_width) or (length_ <> mouse_length) then
  begin
    newBuf := PByte(mem_malloc(width * length_));
    if newBuf = nil then
    begin
      if not cursorWasHidden then
        mouse_show;
      Exit(-1);
    end;

    if mouse_buf <> nil then
      mem_free(mouse_buf);

    mouse_buf := newBuf;
  end;

  mouse_width := width;
  mouse_length := length_;
  mouse_cursor_width := width;
  mouse_cursor_height := length_;
  mouse_full := full;
  mouse_shape := buf;
  mouse_trans := trans;

  if mouse_fptr <> nil then
  begin
    remove_bk_process(@mouse_anim);
    mouse_fptr := nil;
  end;

  v11 := mouse_hotspot_x - hotx;
  mouse_hotspot_x := hotx;
  mouse_x := mouse_x + v11;

  v12 := mouse_hotspot_y - hoty;
  mouse_hotspot_y := hoty;
  mouse_y := mouse_y + v12;

  mouse_clip;

  if not cursorWasHidden then
    mouse_show;

  Result := 0;
end;

function mouse_get_anim(out frames: PByte; out num_frames, width, length_, hotx, hoty: Integer; out trans: AnsiChar; out speed: Integer): Integer;
begin
  frames := nil;
  num_frames := 0;
  width := 0;
  length_ := 0;
  hotx := 0;
  hoty := 0;
  trans := #0;
  speed := 0;
  Result := -1;
end;

function mouse_set_anim_frames(frames: PByte; num_frames, start_frame, width, length_, hotx, hoty: Integer; trans: AnsiChar; speed: Integer): Integer;
begin
  if mouse_set_shape(frames + start_frame * width * length_, width, length_, width, hotx, hoty, trans) = -1 then
    Exit(-1);

  mouse_fptr := frames;
  mouse_num_frames := num_frames;
  mouse_curr_frame := start_frame;
  mouse_speed := speed;

  add_bk_process(@mouse_anim);

  Result := 0;
end;

procedure mouse_show;
var
  i, v3, v4: Integer;
  v7, v8, v9, v10: Integer;
  v6: Byte;
begin
  if not have_mouse then
    Exit;

  if (mouse_blit_trans = nil) or (not mouse_is_hidden) then
  begin
    win_get_mouse_buf(mouse_buf);
    v3 := 0;

    for i := 0 to mouse_length - 1 do
    begin
      for v4 := 0 to mouse_width - 1 do
      begin
        v6 := mouse_shape[i * mouse_full + v4];
        if AnsiChar(v6) <> mouse_trans then
          mouse_buf[v3] := v6;
        Inc(v3);
      end;
    end;
  end;

  // Clip to screen
  if mouse_x >= scr_size.ulx then
  begin
    if mouse_width + mouse_x - 1 <= scr_size.lrx then
    begin
      v8 := mouse_width;
      v7 := 0;
    end
    else
    begin
      v7 := 0;
      v8 := scr_size.lrx - mouse_x + 1;
    end;
  end
  else
  begin
    v7 := scr_size.ulx - mouse_x;
    v8 := mouse_width - (scr_size.ulx - mouse_x);
  end;

  if mouse_y >= scr_size.uly then
  begin
    if mouse_length + mouse_y - 1 <= scr_size.lry then
    begin
      v9 := 0;
      v10 := mouse_length;
    end
    else
    begin
      v9 := 0;
      v10 := scr_size.lry - mouse_y + 1;
    end;
  end
  else
  begin
    v9 := scr_size.uly - mouse_y;
    v10 := mouse_length - (scr_size.uly - mouse_y);
  end;

  if Assigned(mouse_blit_trans) and mouse_is_hidden then
    mouse_blit_trans(mouse_shape, mouse_full, mouse_length, v7, v9, v8, v10, v7 + mouse_x, v9 + mouse_y, Byte(mouse_trans))
  else
    mouse_blit(mouse_buf, mouse_width, mouse_length, v7, v9, v8, v10, v7 + mouse_x, v9 + mouse_y);

  mouse_is_hidden := False;
end;

procedure mouse_hide;
begin
  mouse_is_hidden := True;
end;

procedure mouse_info;
var
  gesture: TGesture;
  mouseData: TMouseData;
  x, y, buttons: Integer;
begin
  if not mouse_exists then Exit;
  if mouse_is_hidden then Exit;
  if mouse_disabled then Exit;

  // Touch gesture handling
  if touch_get_gesture(@gesture) then
  begin
    case gesture.GestureType of
      GESTURE_TAP:
      begin
        if gesture.NumberOfTouches = 1 then
          mouse_simulate_input(0, 0, MOUSE_STATE_LEFT_BUTTON_DOWN)
        else if gesture.NumberOfTouches = 2 then
          mouse_simulate_input(0, 0, MOUSE_STATE_RIGHT_BUTTON_DOWN);
      end;
      GESTURE_LONG_PRESS, GESTURE_PAN:
      begin
        if gesture.State = GESTURE_BEGAN then
        begin
          touch_prev_x := gesture.X;
          touch_prev_y := gesture.Y;
        end;

        if gesture.GestureType = GESTURE_LONG_PRESS then
        begin
          if gesture.NumberOfTouches = 1 then
            mouse_simulate_input(gesture.X - touch_prev_x, gesture.Y - touch_prev_y, MOUSE_STATE_LEFT_BUTTON_DOWN)
          else if gesture.NumberOfTouches = 2 then
            mouse_simulate_input(gesture.X - touch_prev_x, gesture.Y - touch_prev_y, MOUSE_STATE_RIGHT_BUTTON_DOWN);
        end
        else if gesture.GestureType = GESTURE_PAN then
        begin
          if gesture.NumberOfTouches = 1 then
            mouse_simulate_input(gesture.X - touch_prev_x, gesture.Y - touch_prev_y, 0)
          else if gesture.NumberOfTouches = 2 then
          begin
            mouse_wheel_x := (touch_prev_x - gesture.X) div 2;
            mouse_wheel_y := (gesture.Y - touch_prev_y) div 2;
            if (mouse_wheel_x <> 0) or (mouse_wheel_y <> 0) then
            begin
              mouse_event := mouse_event or MOUSE_EVENT_WHEEL;
              raw_buttons := raw_buttons or MOUSE_EVENT_WHEEL;
            end;
          end;
        end;

        touch_prev_x := gesture.X;
        touch_prev_y := gesture.Y;
      end;
    end;
    Exit;
  end;

  // Read hardware mouse state
  buttons := 0;
  if dxinput_get_mouse_state(@mouseData) then
  begin
    x := mouseData.X;
    y := mouseData.Y;
    if mouseData.Buttons[0] = 1 then
      buttons := buttons or MOUSE_STATE_LEFT_BUTTON_DOWN;
    if mouseData.Buttons[1] = 1 then
      buttons := buttons or MOUSE_STATE_RIGHT_BUTTON_DOWN;
  end
  else
  begin
    x := 0;
    y := 0;
  end;

  // Apply sensitivity
  x := Trunc(x * mouse_sensitivity);
  y := Trunc(y * mouse_sensitivity);

  // VCR playback handling
  if vcr_state = VCR_STATE_PLAYING then
  begin
    if (((vcr_terminate_flags and VCR_TERMINATE_ON_MOUSE_PRESS) <> 0) and (buttons <> 0))
      or (((vcr_terminate_flags and VCR_TERMINATE_ON_MOUSE_MOVE) <> 0) and ((x <> 0) or (y <> 0))) then
    begin
      vcr_terminated_condition := VCR_PLAYBACK_COMPLETION_REASON_TERMINATED;
      vcr_stop;
      Exit;
    end;
    x := 0;
    y := 0;
    buttons := mouse_buttons;
  end;

  mouse_simulate_input(x, y, buttons);

  // Wheel events
  mouse_wheel_x := mouseData.WheelX;
  mouse_wheel_y := mouseData.WheelY;
  if (mouse_wheel_x <> 0) or (mouse_wheel_y <> 0) then
  begin
    mouse_event := mouse_event or MOUSE_EVENT_WHEEL;
    raw_buttons := raw_buttons or MOUSE_EVENT_WHEEL;
  end;
end;

procedure mouse_simulate_input(delta_x, delta_y, buttons: Integer);
var
  old_event: Integer;
  vcrEntry: PVcrEntry;
  mouseRect: TRect;
begin
  if (not mouse_exists) or mouse_is_hidden then
    Exit;

  if (delta_x <> 0) or (delta_y <> 0) or (buttons <> mouse_buttons) then
  begin
    // Record to VCR if recording
    if vcr_state = VCR_STATE_RECORDING then
    begin
      if vcr_buffer_index = VCR_BUFFER_CAPACITY - 1 then
        vcr_dump_buffer;

      vcrEntry := @PVcrEntry(vcr_buffer)[vcr_buffer_index];
      vcrEntry^.EntryType := VCR_ENTRY_TYPE_MOUSE_EVENT;
      vcrEntry^.Time := vcr_time;
      vcrEntry^.Counter := vcr_counter;
      vcrEntry^.MouseEvent.Dx := delta_x;
      vcrEntry^.MouseEvent.Dy := delta_y;
      vcrEntry^.MouseEvent.Buttons := buttons;

      Inc(vcr_buffer_index);
    end;
  end
  else
  begin
    if mouse_buttons = 0 then
    begin
      if not mouse_idling then
      begin
        mouse_idle_start_time := SDL_GetTicks;
        mouse_idling := True;
      end;

      mouse_buttons := 0;
      raw_buttons := 0;
      mouse_event := 0;
      Exit;
    end;
  end;

  mouse_idling := False;
  mouse_buttons := buttons;
  old_event := mouse_event;
  mouse_event := 0;

  // Left button events
  if (old_event and MOUSE_EVENT_LEFT_BUTTON_DOWN_REPEAT) <> 0 then
  begin
    if (buttons and MOUSE_STATE_LEFT_BUTTON_DOWN) <> 0 then
    begin
      mouse_event := mouse_event or MOUSE_EVENT_LEFT_BUTTON_REPEAT;
      if (SDL_GetTicks - left_time) > BUTTON_REPEAT_TIME then
      begin
        mouse_event := mouse_event or MOUSE_EVENT_LEFT_BUTTON_DOWN;
        left_time := SDL_GetTicks;
      end;
    end
    else
      mouse_event := mouse_event or MOUSE_EVENT_LEFT_BUTTON_UP;
  end
  else
  begin
    if (buttons and MOUSE_STATE_LEFT_BUTTON_DOWN) <> 0 then
    begin
      mouse_event := mouse_event or MOUSE_EVENT_LEFT_BUTTON_DOWN;
      left_time := SDL_GetTicks;
    end;
  end;

  // Right button events
  if (old_event and MOUSE_EVENT_RIGHT_BUTTON_DOWN_REPEAT) <> 0 then
  begin
    if (buttons and MOUSE_STATE_RIGHT_BUTTON_DOWN) <> 0 then
    begin
      mouse_event := mouse_event or MOUSE_EVENT_RIGHT_BUTTON_REPEAT;
      if (SDL_GetTicks - right_time) > BUTTON_REPEAT_TIME then
      begin
        mouse_event := mouse_event or MOUSE_EVENT_RIGHT_BUTTON_DOWN;
        right_time := SDL_GetTicks;
      end;
    end
    else
      mouse_event := mouse_event or MOUSE_EVENT_RIGHT_BUTTON_UP;
  end
  else
  begin
    if (buttons and MOUSE_STATE_RIGHT_BUTTON_DOWN) <> 0 then
    begin
      mouse_event := mouse_event or MOUSE_EVENT_RIGHT_BUTTON_DOWN;
      right_time := SDL_GetTicks;
    end;
  end;

  raw_buttons := mouse_event;

  if (delta_x <> 0) or (delta_y <> 0) then
  begin
    mouseRect.ulx := mouse_x;
    mouseRect.uly := mouse_y;
    mouseRect.lrx := mouse_width + mouse_x - 1;
    mouseRect.lry := mouse_length + mouse_y - 1;

    mouse_x := mouse_x + delta_x;
    mouse_y := mouse_y + delta_y;
    mouse_clip;

    win_refresh_all(@mouseRect);
    mouse_show;
  end;
end;

function mouse_in(left, top, right, bottom: Integer): Boolean;
begin
  Result := (mouse_x >= left) and (mouse_x <= right) and
            (mouse_y >= top) and (mouse_y <= bottom);
end;

function mouse_click_in(left, top, right, bottom: Integer): Boolean;
begin
  Result := mouse_in(left, top, right, bottom);
end;

procedure mouse_get_rect(rect: PRect);
begin
  rect^.ulx := mouse_x - mouse_hotspot_x;
  rect^.uly := mouse_y - mouse_hotspot_y;
  rect^.lrx := rect^.ulx + mouse_cursor_width - 1;
  rect^.lry := rect^.uly + mouse_cursor_height - 1;
end;

procedure mouse_get_position(x, y: PInteger);
begin
  x^ := mouse_x;
  y^ := mouse_y;
end;

procedure mouse_set_position(x, y: Integer);
begin
  mouse_x := x;
  mouse_y := y;
end;

function mouse_get_buttons: Integer;
begin
  Result := mouse_event;
end;

function mouse_hidden: Boolean;
begin
  Result := mouse_is_hidden;
end;

procedure mouse_get_hotspot(hotx, hoty: PInteger);
begin
  hotx^ := mouse_hotspot_x;
  hoty^ := mouse_hotspot_y;
end;

procedure mouse_set_hotspot(hotx, hoty: Integer);
begin
  mouse_hotspot_x := hotx;
  mouse_hotspot_y := hoty;
end;

function mouse_query_exist: Boolean;
begin
  Result := mouse_exists;
end;

procedure mouse_get_raw_state(x, y: PInteger; buttons: PInteger);
begin
  x^ := mouse_x;
  y^ := mouse_y;
  buttons^ := mouse_buttons;
end;

procedure mouse_disable;
begin
  mouse_disabled := True;
end;

procedure mouse_enable;
begin
  mouse_disabled := False;
end;

function mouse_is_disabled: Boolean;
begin
  Result := mouse_disabled;
end;

procedure mouse_set_sensitivity(value: Double);
begin
  mouse_sensitivity := value;
end;

function mouse_get_sensitivity: Double;
begin
  Result := mouse_sensitivity;
end;

function mouse_elapsed_time: LongWord;
begin
  Result := SDL_GetTicks - mouse_start_time;
end;

procedure mouse_reset_elapsed_time;
begin
  mouse_start_time := SDL_GetTicks;
end;

procedure mouseGetPositionInWindow(win: Integer; x, y: PInteger);
begin
  // TODO: Adjust position relative to window
  x^ := mouse_x;
  y^ := mouse_y;
end;

function mouseHitTestInWindow(win: Integer; left, top, right, bottom: Integer): Boolean;
begin
  // TODO: Adjust for window position
  Result := mouse_in(left, top, right, bottom);
end;

procedure mouseGetWheel(x, y: PInteger);
begin
  x^ := mouse_wheel_x;
  y^ := mouse_wheel_y;
  mouse_wheel_x := 0;
  mouse_wheel_y := 0;
end;

procedure convertMouseWheelToArrowKey(keyCodePtr: PInteger);
begin
  if mouse_wheel_y > 0 then
    keyCodePtr^ := 328  // KEY_ARROW_UP
  else if mouse_wheel_y < 0 then
    keyCodePtr^ := 336; // KEY_ARROW_DOWN
end;

end.
