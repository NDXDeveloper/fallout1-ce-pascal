{$MODE OBJFPC}{$H+}
// Converted from: src/game/display.h + display.cc
// In-game display monitor (message log in the interface bar).
unit u_display;

interface

function display_init: Integer;
function display_reset: Integer;
procedure display_exit;
procedure display_print(str: PAnsiChar);
procedure display_clear;
procedure display_redraw;
procedure display_scroll_up(btn, keyCode: Integer); cdecl;
procedure display_scroll_down(btn, keyCode: Integer); cdecl;
procedure display_arrow_up(btn, keyCode: Integer); cdecl;
procedure display_arrow_down(btn, keyCode: Integer); cdecl;
procedure display_arrow_restore(btn, keyCode: Integer); cdecl;
procedure display_disable;
procedure display_enable;

implementation

uses
  SysUtils, u_color, u_grbuf, u_gnw, u_button, u_input, u_memory, u_rect, u_text,
  u_art, u_cache, u_combat, u_gmouse, u_gsound, u_intface;

const
  OBJ_TYPE_INTERFACE = 6;

  MOUSE_CURSOR_NONE            = 0;
  MOUSE_CURSOR_ARROW           = 1;
  MOUSE_CURSOR_SMALL_ARROW_UP  = 2;
  MOUSE_CURSOR_SMALL_ARROW_DOWN = 3;

  DISPLAY_MONITOR_LINES_CAPACITY = 100;
  DISPLAY_MONITOR_LINE_LENGTH    = 80;

  DISPLAY_MONITOR_X      = 23;
  DISPLAY_MONITOR_Y      = 24;
  DISPLAY_MONITOR_WIDTH  = 167;
  DISPLAY_MONITOR_HEIGHT = 60;

  DISPLAY_MONITOR_HALF_HEIGHT = DISPLAY_MONITOR_HEIGHT div 2;

  DISPLAY_MONITOR_FONT = 101;

  DISPLAY_MONITOR_BEEP_DELAY = 500;

var
  disp_init_flag: Boolean = False;

  disp_rect: TRect = (
    ulx: DISPLAY_MONITOR_X;
    uly: DISPLAY_MONITOR_Y;
    lrx: DISPLAY_MONITOR_X + DISPLAY_MONITOR_WIDTH - 1;
    lry: DISPLAY_MONITOR_Y + DISPLAY_MONITOR_HEIGHT - 1;
  );

  dn_bid: Integer = -1;
  up_bid: Integer = -1;

  disp_str: array[0..DISPLAY_MONITOR_LINES_CAPACITY - 1, 0..DISPLAY_MONITOR_LINE_LENGTH - 1] of AnsiChar;
  disp_buf: PByte;
  max_disp_ptr: Integer;
  display_enabled: Boolean;
  disp_curr: Integer;
  intface_full_wid: Integer;
  max_ptr: Integer;
  disp_start: Integer;
  display_print_lastTime: LongWord;

function display_init: Integer;
var
  oldFont: Integer;
  backgroundFrmHandle: PCacheEntry;
  backgroundFid: Integer;
  backgroundFrm: PArt;
  backgroundFrmData: PByte;
begin
  if not disp_init_flag then
  begin
    oldFont := text_curr;
    text_font(DISPLAY_MONITOR_FONT);

    max_ptr := DISPLAY_MONITOR_LINES_CAPACITY;
    max_disp_ptr := DISPLAY_MONITOR_HEIGHT div text_height();
    disp_start := 0;
    disp_curr := 0;
    text_font(oldFont);

    disp_buf := PByte(mem_malloc(DISPLAY_MONITOR_WIDTH * DISPLAY_MONITOR_HEIGHT));
    if disp_buf = nil then
      Exit(-1);

    backgroundFrmHandle := nil;
    backgroundFid := art_id(OBJ_TYPE_INTERFACE, 16, 0, 0, 0);
    backgroundFrm := art_ptr_lock(backgroundFid, @backgroundFrmHandle);
    if backgroundFrm = nil then
    begin
      mem_free(disp_buf);
      Exit(-1);
    end;

    backgroundFrmData := art_frame_data(backgroundFrm, 0, 0);
    intface_full_wid := art_frame_width(backgroundFrm, 0, 0);
    buf_to_buf(backgroundFrmData + intface_full_wid * DISPLAY_MONITOR_Y + DISPLAY_MONITOR_X,
      DISPLAY_MONITOR_WIDTH,
      DISPLAY_MONITOR_HEIGHT,
      intface_full_wid,
      disp_buf,
      DISPLAY_MONITOR_WIDTH);

    art_ptr_unlock(backgroundFrmHandle);

    up_bid := win_register_button(interfaceWindow,
      DISPLAY_MONITOR_X,
      DISPLAY_MONITOR_Y,
      DISPLAY_MONITOR_WIDTH,
      DISPLAY_MONITOR_HALF_HEIGHT,
      -1, -1, -1, -1,
      nil, nil, nil, 0);
    if up_bid <> -1 then
      win_register_button_func(up_bid,
        @display_arrow_up,
        @display_arrow_restore,
        @display_scroll_up,
        nil);

    dn_bid := win_register_button(interfaceWindow,
      DISPLAY_MONITOR_X,
      DISPLAY_MONITOR_Y + DISPLAY_MONITOR_HALF_HEIGHT,
      DISPLAY_MONITOR_WIDTH,
      DISPLAY_MONITOR_HEIGHT - DISPLAY_MONITOR_HALF_HEIGHT,
      -1, -1, -1, -1,
      nil, nil, nil, 0);
    if dn_bid <> -1 then
      win_register_button_func(dn_bid,
        @display_arrow_down,
        @display_arrow_restore,
        @display_scroll_down,
        nil);

    display_enabled := True;
    disp_init_flag := True;

    display_clear;
  end;

  Result := 0;
end;

function display_reset: Integer;
begin
  display_clear;
  Result := 0;
end;

procedure display_exit;
begin
  if disp_init_flag then
  begin
    mem_free(disp_buf);
    disp_init_flag := False;
  end;
end;

procedure display_print(str: PAnsiChar);
var
  oldFont: Integer;
  knob: AnsiChar;
  knobString: array[0..1] of AnsiChar;
  knobWidth: Integer;
  now: LongWord;
  v1, space: PAnsiChar;
  temp: PAnsiChar;
  len: Integer;
begin
  if not disp_init_flag then
    Exit;

  oldFont := text_curr;
  text_font(DISPLAY_MONITOR_FONT);

  knob := #$95;

  knobString[0] := knob;
  knobString[1] := #0;
  knobWidth := text_width(@knobString[0]);

  if not isInCombat then
  begin
    now := get_bk_time;
    if elapsed_tocks(now, display_print_lastTime) >= DISPLAY_MONITOR_BEEP_DELAY then
    begin
      display_print_lastTime := now;
      gsound_play_sfx_file('monitor');
    end;
  end;

  v1 := nil;
  while True do
  begin
    while text_width(str) < DISPLAY_MONITOR_WIDTH - max_disp_ptr - knobWidth do
    begin
      temp := @disp_str[disp_start][0];
      if knob <> #0 then
      begin
        temp^ := knob;
        Inc(temp);
        len := DISPLAY_MONITOR_LINE_LENGTH - 2;
        knob := #0;
        knobWidth := 0;
      end
      else
        len := DISPLAY_MONITOR_LINE_LENGTH - 1;

      StrLCopy(temp, str, len);
      disp_str[disp_start][DISPLAY_MONITOR_LINE_LENGTH - 1] := #0;
      disp_start := (disp_start + 1) mod max_ptr;

      if v1 = nil then
      begin
        text_font(oldFont);
        disp_curr := disp_start;
        display_redraw;
        Exit;
      end;

      str := v1 + 1;
      v1^ := ' ';
      v1 := nil;
    end;

    space := StrRScan(str, ' ');
    if space = nil then
      Break;

    if v1 <> nil then
      v1^ := ' ';

    v1 := space;
    space^ := #0;
  end;

  temp := @disp_str[disp_start][0];
  if knob <> #0 then
  begin
    disp_str[disp_start][0] := knob;
    Inc(temp);
    len := DISPLAY_MONITOR_LINE_LENGTH - 2;
    knob := #0;
  end
  else
    len := DISPLAY_MONITOR_LINE_LENGTH - 1;

  StrLCopy(temp, str, len);

  disp_str[disp_start][DISPLAY_MONITOR_LINE_LENGTH - 1] := #0;
  disp_start := (disp_start + 1) mod max_ptr;

  text_font(oldFont);
  disp_curr := disp_start;
  display_redraw;
end;

procedure display_clear;
var
  index: Integer;
begin
  if disp_init_flag then
  begin
    for index := 0 to max_ptr - 1 do
      disp_str[index][0] := #0;

    disp_start := 0;
    disp_curr := 0;
    display_redraw;
  end;
end;

procedure display_redraw;
var
  buf: PByte;
  oldFont: Integer;
  index, stringIndex: Integer;
begin
  if not disp_init_flag then
    Exit;

  buf := win_get_buf(interfaceWindow);
  if buf = nil then
    Exit;

  buf := buf + intface_full_wid * DISPLAY_MONITOR_Y + DISPLAY_MONITOR_X;
  buf_to_buf(disp_buf,
    DISPLAY_MONITOR_WIDTH,
    DISPLAY_MONITOR_HEIGHT,
    DISPLAY_MONITOR_WIDTH,
    buf,
    intface_full_wid);

  oldFont := text_curr;
  text_font(DISPLAY_MONITOR_FONT);

  for index := 0 to max_disp_ptr - 1 do
  begin
    stringIndex := (disp_curr + max_ptr + index - max_disp_ptr) mod max_ptr;
    text_to_buf(buf + index * intface_full_wid * text_height(),
      @disp_str[stringIndex][0], DISPLAY_MONITOR_WIDTH, intface_full_wid,
      colorTable[992]);
    Inc(buf);
  end;

  win_draw_rect(interfaceWindow, @disp_rect);
  text_font(oldFont);
end;

procedure display_scroll_up(btn, keyCode: Integer); cdecl;
begin
  if (max_ptr + disp_curr - 1) mod max_ptr <> disp_start then
  begin
    disp_curr := (max_ptr + disp_curr - 1) mod max_ptr;
    display_redraw;
  end;
end;

procedure display_scroll_down(btn, keyCode: Integer); cdecl;
begin
  if disp_curr <> disp_start then
  begin
    disp_curr := (disp_curr + 1) mod max_ptr;
    display_redraw;
  end;
end;

procedure display_arrow_up(btn, keyCode: Integer); cdecl;
begin
  gmouse_set_cursor(MOUSE_CURSOR_SMALL_ARROW_UP);
end;

procedure display_arrow_down(btn, keyCode: Integer); cdecl;
begin
  gmouse_set_cursor(MOUSE_CURSOR_SMALL_ARROW_DOWN);
end;

procedure display_arrow_restore(btn, keyCode: Integer); cdecl;
begin
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
end;

procedure display_disable;
begin
  if display_enabled then
  begin
    win_disable_button(dn_bid);
    win_disable_button(up_bid);
    display_enabled := False;
  end;
end;

procedure display_enable;
begin
  if not display_enabled then
  begin
    win_enable_button(dn_bid);
    win_enable_button(up_bid);
    display_enabled := True;
  end;
end;

end.
