{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/gnw.h + gnw.cc
// Window manager: creation, drawing, event routing, refresh.
unit u_gnw;

interface

uses
  u_rect, u_gnw_types, u_svga_types;

const
  WINDOW_MANAGER_OK                             = 0;
  WINDOW_MANAGER_ERR_INITIALIZING_VIDEO_MODE    = 1;
  WINDOW_MANAGER_ERR_NO_MEMORY                  = 2;
  WINDOW_MANAGER_ERR_INITIALIZING_TEXT_FONTS     = 3;
  WINDOW_MANAGER_ERR_WINDOW_SYSTEM_ALREADY_INITIALIZED = 4;
  WINDOW_MANAGER_ERR_WINDOW_SYSTEM_NOT_INITIALIZED = 5;
  WINDOW_MANAGER_ERR_CURRENT_WINDOWS_TOO_BIG    = 6;
  WINDOW_MANAGER_ERR_INITIALIZING_DEFAULT_DATABASE = 7;
  WINDOW_MANAGER_ERR_8                          = 8;
  WINDOW_MANAGER_ERR_ALREADY_RUNNING            = 9;
  WINDOW_MANAGER_ERR_TITLE_NOT_SET              = 10;
  WINDOW_MANAGER_ERR_INITIALIZING_INPUT         = 11;

type
  PPWindow = ^PWindow;

var
  GNW_win_init_flag: Boolean = False;
  GNW_wcolor: array[0..5] of Integer;
  GNW_texture: Pointer = nil;

function win_init(video_options: PVideoOptions; flags: Integer): Integer;
function win_active: Integer;
procedure win_exit;
function win_add(x, y, width, height, color, flags: Integer): Integer;
procedure win_delete(win: Integer);
procedure win_buffering(a1: Boolean);
procedure win_border(win: Integer);
procedure win_no_texture;
procedure win_set_bk_color(color: Integer);
procedure win_print(win: Integer; str: PAnsiChar; width, x, y, color: Integer);
procedure win_text(win: Integer; fileNameList: PPAnsiChar;
  fileNameListLength, maxWidth, x, y, color: Integer);
procedure win_line(win, left, top, right, bottom, color: Integer);
procedure win_box(win, left, top, right, bottom, color: Integer);
procedure win_shaded_box(id, ulx, uly, lrx, lry, color1, color2: Integer);
procedure win_fill(win, x, y, width, height, color: Integer);
procedure win_show(win: Integer);
procedure win_hide(win: Integer);
procedure win_move(win_id, x, y: Integer);
procedure win_draw(win: Integer);
procedure win_draw_rect(win: Integer; rect: PRect);
procedure GNW_win_refresh(w: PWindow; rect: PRect; a3: PByte);
procedure win_refresh_all(rect: PRect);
procedure win_drag(win: Integer);
procedure win_get_mouse_buf(a1: PByte);
function GNW_find(win: Integer): PWindow;
function win_get_buf(win: Integer): PByte;
function win_get_top_win(x, y: Integer): Integer;
function win_width(win: Integer): Integer;
function win_height(win: Integer): Integer;
function win_get_rect(win: Integer; rect: PRect): Integer;
function win_check_all_buttons: Integer;
function GNW_find_button(btn: Integer; out_win: PPWindow): PButton;
function GNW_check_menu_bars(a1: Integer): Integer;
procedure win_set_minimized_title(title: PAnsiChar);
procedure win_set_trans_b2b(id: Integer; trans_b2b: TWindowBlitProc);
function GNWSystemError(str: PAnsiChar): Boolean;

implementation

uses
  u_memory, u_svga, u_input, u_text, u_grbuf, u_mouse, u_sdl2, u_winmain,
  u_button, u_color, u_db, u_plib_intrface, u_vcr, u_debug;

const
  MAX_WINDOW_COUNT = 50;

var
  win_index: array[0..MAX_WINDOW_COUNT - 1] of Integer;
  win_list: array[0..MAX_WINDOW_COUNT - 1] of PWindow;
  num_windows: Integer = 0;
  screen_buffer: PByte = nil;
  buffering_: Boolean = False;
  bk_color: Integer = 0;
  doing_refresh_all: Integer = 0;
  window_flags_: Integer = 0;

// Forward declarations
procedure win_free(win: Integer); forward;
procedure win_clip(w: PWindow; rectListNodePtr: PPRectData; a3: PByte); forward;
procedure refresh_all(rect: PRect; a2: PByte); forward;
function colorOpen_cb(const path: PAnsiChar): Pointer; cdecl; forward;
function colorRead_cb(handle: Pointer; buf: Pointer; count: SizeUInt): Integer; cdecl; forward;
function colorClose_cb(handle: Pointer): Integer; cdecl; forward;

// cdecl wrappers for color system registration
function mem_malloc_cdecl(size: SizeUInt): Pointer; cdecl;
begin Result := mem_malloc(size); end;

function mem_realloc_cdecl(ptr: Pointer; size: SizeUInt): Pointer; cdecl;
begin Result := mem_realloc(ptr, size); end;

procedure mem_free_cdecl(ptr: Pointer); cdecl;
begin mem_free(ptr); end;

// 0x4C1CF0
function win_init(video_options: PVideoOptions; flags: Integer): Integer;
var
  index: Integer;
  w: PWindow;
  palette: PByte;
begin
  if GNW_win_init_flag then
    Exit(WINDOW_MANAGER_ERR_WINDOW_SYSTEM_ALREADY_INITIALIZED);

  for index := 0 to MAX_WINDOW_COUNT - 1 do
    win_index[index] := -1;

  if db_total = 0 then
  begin
    if db_init(nil, nil, '', 1) = INVALID_DATABASE_HANDLE then
      Exit(WINDOW_MANAGER_ERR_INITIALIZING_DEFAULT_DATABASE);
  end;

  if GNW_text_init <> 0 then
    Exit(WINDOW_MANAGER_ERR_INITIALIZING_TEXT_FONTS);

  if not svga_init(video_options) then
  begin
    svga_exit;
    Exit(WINDOW_MANAGER_ERR_INITIALIZING_VIDEO_MODE);
  end;

  if (flags and 1) <> 0 then
  begin
    screen_buffer := PByte(mem_malloc(
      (scr_size.lry - scr_size.uly + 1) * (scr_size.lrx - scr_size.ulx + 1)));
    if screen_buffer = nil then
    begin
      svga_exit;
      Exit(WINDOW_MANAGER_ERR_NO_MEMORY);
    end;
  end;

  buffering_ := False;
  doing_refresh_all := 0;

  colorInitIO(@colorOpen_cb, @colorRead_cb, @colorClose_cb);
  colorRegisterAlloc(@mem_malloc_cdecl, @mem_realloc_cdecl, @mem_free_cdecl);

  if not initColors then
  begin
    palette := PByte(mem_malloc(768));
    if palette = nil then
    begin
      svga_exit;
      if screen_buffer <> nil then
        mem_free(screen_buffer);
      Exit(WINDOW_MANAGER_ERR_NO_MEMORY);
    end;

    buf_fill(palette, 768, 1, 768, 0);
    // TODO: Incomplete.
    // colorBuildColorTable(getSystemPalette(), palette);
    mem_free(palette);
  end;

  GNW_debug_init;

  if GNW_input_init(flags) = -1 then
    Exit(WINDOW_MANAGER_ERR_INITIALIZING_INPUT);

  GNW_intr_init;

  w := PWindow(mem_malloc(SizeOf(TWindow)));
  if w = nil then
  begin
    svga_exit;
    if screen_buffer <> nil then
      mem_free(screen_buffer);
    Exit(WINDOW_MANAGER_ERR_NO_MEMORY);
  end;

  win_list[0] := w;

  w^.Id := 0;
  w^.Flags := 0;
  w^.Rect.ulx := scr_size.ulx;
  w^.Rect.uly := scr_size.uly;
  w^.Rect.lrx := scr_size.lrx;
  w^.Rect.lry := scr_size.lry;
  w^.Width := scr_size.lrx - scr_size.ulx + 1;
  w^.Height := scr_size.lry - scr_size.uly + 1;
  w^.Tx := 0;
  w^.Ty := 0;
  w^.Buffer := nil;
  w^.ButtonListHead := nil;
  w^.HoveredButton := nil;
  w^.ClickedButton := nil;
  w^.MenuBar_ := nil;
  w^.BlitProc := nil;

  num_windows := 1;
  GNW_win_init_flag := True;
  win_index[0] := 0;
  bk_color := 0;
  window_flags_ := flags;

  // NOTE: Uninline.
  win_no_texture;

  Result := WINDOW_MANAGER_OK;
end;

// 0x4C2224
function win_active: Integer;
begin
  if GNW_win_init_flag then
    Result := 1
  else
    Result := 0;
end;

// 0x4C222C
procedure win_exit;
var
  index: Integer;
begin
  if not GNW_win_init_flag then Exit;

  GNW_intr_exit;

  for index := num_windows - 1 downto 0 do
    win_free(win_list[index]^.Id);

  if GNW_texture <> nil then
    mem_free(GNW_texture);

  if screen_buffer <> nil then
    mem_free(screen_buffer);

  svga_exit;
  GNW_input_exit;
  GNW_rect_exit;
  GNW_text_exit;
  colorsClose;

  GNW_win_init_flag := False;
end;

// 0x4C22F8
function win_add(x, y, width, height, color, flags: Integer): Integer;
var
  w: PWindow;
  index: Integer;
  v23, v25, v26: Integer;
  tmp: PWindow;
  colorIndex: Integer;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  if num_windows = MAX_WINDOW_COUNT then
    Exit(-1);

  if width > rectGetWidth(@scr_size) then
    Exit(-1);

  if height > rectGetHeight(@scr_size) then
    Exit(-1);

  w := PWindow(mem_malloc(SizeOf(TWindow)));
  if w = nil then
    Exit(-1);

  win_list[num_windows] := w;

  w^.Buffer := PByte(mem_malloc(width * height));
  if w^.Buffer = nil then
  begin
    mem_free(w);
    Exit(-1);
  end;

  index := 1;
  while GNW_find(index) <> nil do
    Inc(index);

  w^.Id := index;

  if (flags and WINDOW_USE_DEFAULTS) <> 0 then
    flags := flags or window_flags_;

  w^.Width := width;
  w^.Height := height;
  w^.Flags := flags;
  w^.Tx := Random(MaxInt) and $FFFE;
  w^.Ty := Random(MaxInt) and $FFFE;

  if color = 256 then
  begin
    if GNW_texture = nil then
      color := colorTable[GNW_wcolor[0]];
  end
  else if (color and $FF00) <> 0 then
  begin
    colorIndex := (color and $FF) - 1;
    color := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
  end;

  w^.ButtonListHead := nil;
  w^.HoveredButton := nil;
  w^.ClickedButton := nil;
  w^.MenuBar_ := nil;
  w^.BlitProc := TWindowBlitProc(@trans_buf_to_buf);
  w^.Color := color;
  win_index[index] := num_windows;
  Inc(num_windows);

  win_fill(index, 0, 0, width, height, color);

  w^.Flags := w^.Flags or WINDOW_HIDDEN;
  win_move(index, x, y);
  w^.Flags := flags;

  if (flags and WINDOW_MOVE_ON_TOP) = 0 then
  begin
    v23 := num_windows - 2;
    while v23 > 0 do
    begin
      if (win_list[v23]^.Flags and WINDOW_MOVE_ON_TOP) = 0 then
        Break;
      Dec(v23);
    end;

    if v23 <> num_windows - 2 then
    begin
      v25 := v23 + 1;
      v26 := num_windows - 1;
      while v26 > v25 do
      begin
        tmp := win_list[v26 - 1];
        win_list[v26] := tmp;
        win_index[tmp^.Id] := v26;
        Dec(v26);
      end;

      win_list[v25] := w;
      win_index[index] := v25;
    end;
  end;

  Result := index;
end;

// 0x4C2524
procedure win_delete(win: Integer);
var
  w: PWindow;
  rect: TRect;
  v1, index: Integer;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  rectCopy(@rect, @w^.Rect);

  v1 := win_index[w^.Id];
  win_free(win);

  win_index[win] := -1;

  for index := v1 to num_windows - 2 do
  begin
    win_list[index] := win_list[index + 1];
    win_index[win_list[index]^.Id] := index;
  end;

  Dec(num_windows);

  // NOTE: Uninline.
  win_refresh_all(@rect);
end;

// 0x4C25C8
procedure win_free(win: Integer);
var
  w: PWindow;
  curr, next_: PButton;
begin
  w := GNW_find(win);
  if w = nil then
    Exit;

  if w^.Buffer <> nil then
    mem_free(w^.Buffer);

  if w^.MenuBar_ <> nil then
    mem_free(w^.MenuBar_);

  curr := w^.ButtonListHead;
  while curr <> nil do
  begin
    next_ := curr^.Next;
    GNW_delete_button(curr);
    curr := next_;
  end;

  mem_free(w);
end;

// 0x4C2614
procedure win_buffering(a1: Boolean);
begin
  if screen_buffer <> nil then
    buffering_ := a1;
end;

// 0x4C2624
procedure win_border(win: Integer);
var
  w: PWindow;
begin
  if not GNW_win_init_flag then
    Exit;

  w := GNW_find(win);
  if w = nil then
    Exit;

  lighten_buf(w^.Buffer + 5, w^.Width - 10, 5, w^.Width);
  lighten_buf(w^.Buffer, 5, w^.Height, w^.Width);
  lighten_buf(w^.Buffer + w^.Width - 5, 5, w^.Height, w^.Width);
  lighten_buf(w^.Buffer + w^.Width * (w^.Height - 5) + 5, w^.Width - 10, 5, w^.Width);

  draw_box(w^.Buffer, w^.Width, 0, 0, w^.Width - 1, w^.Height - 1, colorTable[0]);

  draw_shaded_box(w^.Buffer, w^.Width, 1, 1, w^.Width - 2, w^.Height - 2,
    colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);
  draw_shaded_box(w^.Buffer, w^.Width, 5, 5, w^.Width - 6, w^.Height - 6,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);
end;

// 0x4C2754
procedure win_no_texture;
begin
  if GNW_win_init_flag then
  begin
    if GNW_texture <> nil then
    begin
      mem_free(GNW_texture);
      GNW_texture := nil;
    end;

    GNW_wcolor[0] := 10570;
    GNW_wcolor[1] := 15855;
    GNW_wcolor[2] := 8456;
    GNW_wcolor[3] := 21140;
    GNW_wcolor[4] := 32747;
    GNW_wcolor[5] := 31744;
  end;
end;

// 0x4C28D4
procedure win_set_bk_color(color: Integer);
begin
  if GNW_win_init_flag then
  begin
    bk_color := color;
    win_draw(0);
  end;
end;

// 0x4C2908
procedure win_print(win: Integer; str: PAnsiChar; width, x, y, color: Integer);
var
  w: PWindow;
  buf: PByte;
  textColor: Integer;
  colorIndex: Integer;
  refreshRect: TRect;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if width = 0 then
  begin
    if (color and $040000) <> 0 then
      width := text_mono_width(str)
    else
      width := text_width(str);
  end;

  if width + x > w^.Width then
  begin
    if (color and $04000000) = 0 then
      Exit;
    width := w^.Width - x;
  end;

  buf := w^.Buffer + x + y * w^.Width;

  if text_height() + y > w^.Height then
    Exit;

  if (color and $02000000) = 0 then
  begin
    if (w^.Color = 256) and (GNW_texture <> nil) then
      buf_texture(buf, width, text_height(), w^.Width, PByte(GNW_texture), w^.Tx + x, w^.Ty + y)
    else
      buf_fill(buf, width, text_height(), w^.Width, w^.Color);
  end;

  if (color and $FF00) <> 0 then
  begin
    colorIndex := (color and $FF) - 1;
    textColor := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
  end
  else
    textColor := color;

  text_to_buf(buf, str, width, w^.Width, textColor);

  if (color and $01000000) <> 0 then
  begin
    // TODO: Check.
    refreshRect.ulx := w^.Rect.ulx + x;
    refreshRect.uly := w^.Rect.uly + y;
    refreshRect.lrx := refreshRect.ulx + width;
    refreshRect.lry := refreshRect.uly + text_height();
    GNW_win_refresh(w, @refreshRect, nil);
  end;
end;

// 0x4C2A98
procedure win_text(win: Integer; fileNameList: PPAnsiChar;
  fileNameListLength, maxWidth, x, y, color: Integer);
var
  w: PWindow;
  width: Integer;
  ptr: PByte;
  lineHeight: Integer;
  step: Integer;
  v1, v2, v3: Integer;
  index: Integer;
  fileName: PAnsiChar;
  fileNamePtr: PPAnsiChar;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  width := w^.Width;
  ptr := w^.Buffer + y * width + x;
  lineHeight := text_height();

  step := width * lineHeight;
  v1 := lineHeight div 2;
  v2 := v1 + 1;
  v3 := maxWidth - 1;

  fileNamePtr := fileNameList;
  for index := 0 to fileNameListLength - 1 do
  begin
    fileName := fileNamePtr^;
    if fileName^ <> #0 then
    begin
      win_print(win, fileName, maxWidth, x, y, color);
    end
    else
    begin
      if maxWidth <> 0 then
      begin
        draw_line(ptr, width, 0, v1, v3, v1, colorTable[GNW_wcolor[2]]);
        draw_line(ptr, width, 0, v2, v3, v2, colorTable[GNW_wcolor[1]]);
      end;
    end;

    ptr := ptr + step;
    y := y + lineHeight;
    Inc(fileNamePtr);
  end;
end;

// 0x4C2BE0
procedure win_line(win, left, top, right, bottom, color: Integer);
var
  w: PWindow;
  colorIndex: Integer;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if (color and $FF00) <> 0 then
  begin
    colorIndex := (color and $FF) - 1;
    color := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
  end;

  draw_line(w^.Buffer, w^.Width, left, top, right, bottom, color);
end;

// 0x4C2C44
procedure win_box(win, left, top, right, bottom, color: Integer);
var
  w: PWindow;
  colorIndex: Integer;
  tmp: Integer;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if (color and $FF00) <> 0 then
  begin
    colorIndex := (color and $FF) - 1;
    color := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
  end;

  if right < left then
  begin
    tmp := left;
    left := right;
    right := tmp;
  end;

  if bottom < top then
  begin
    tmp := top;
    top := bottom;
    bottom := tmp;
  end;

  draw_box(w^.Buffer, w^.Width, left, top, right, bottom, color);
end;

// 0x4C2CD4
procedure win_shaded_box(id, ulx, uly, lrx, lry, color1, color2: Integer);
var
  w: PWindow;
begin
  w := GNW_find(id);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if (color1 and $FF00) <> 0 then
    color1 := (color1 and Integer($FFFF0000)) or colorTable[GNW_wcolor[(color1 and $FFFF) - 257]];

  if (color2 and $FF00) <> 0 then
    color2 := (color2 and Integer($FFFF0000)) or colorTable[GNW_wcolor[(color2 and $FFFF) - 257]];

  draw_shaded_box(w^.Buffer, w^.Width, ulx, uly, lrx, lry, color1, color2);
end;

// 0x4C2D84
procedure win_fill(win, x, y, width, height, color: Integer);
var
  w: PWindow;
  colorIndex: Integer;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if color = 256 then
  begin
    if GNW_texture <> nil then
    begin
      buf_texture(w^.Buffer + w^.Width * y + x, width, height, w^.Width,
        PByte(GNW_texture), x + w^.Tx, y + w^.Ty);
      Exit;
    end
    else
      color := colorTable[GNW_wcolor[0]] and $FF;
  end
  else if (color and $FF00) <> 0 then
  begin
    colorIndex := (color and $FF) - 1;
    color := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
  end;

  if color < 256 then
    buf_fill(w^.Buffer + w^.Width * y + x, width, height, w^.Width, color);
end;

// 0x4C2E68
procedure win_show(win: Integer);
var
  w: PWindow;
  v3, v5, v7: Integer;
  v6: PWindow;
begin
  w := GNW_find(win);
  if w = nil then
    Exit;

  v3 := win_index[w^.Id];

  if not GNW_win_init_flag then
    Exit;

  if (w^.Flags and WINDOW_HIDDEN) <> 0 then
  begin
    w^.Flags := w^.Flags and (not WINDOW_HIDDEN);
    if v3 = num_windows - 1 then
      GNW_win_refresh(w, @w^.Rect, nil);
  end;

  v5 := num_windows - 1;
  if (v3 < v5) and ((w^.Flags and WINDOW_DONT_MOVE_TOP) = 0) then
  begin
    v7 := v3;
    while (v3 < v5) and (((w^.Flags and WINDOW_MOVE_ON_TOP) <> 0) or
          ((win_list[v7 + 1]^.Flags and WINDOW_MOVE_ON_TOP) = 0)) do
    begin
      v6 := win_list[v7 + 1];
      win_list[v7] := v6;
      Inc(v7);
      win_index[v6^.Id] := v3;
      Inc(v3);
    end;

    win_list[v3] := w;
    win_index[w^.Id] := v3;
    GNW_win_refresh(w, @w^.Rect, nil);
  end;
end;

// 0x4C2F20
procedure win_hide(win: Integer);
var
  w: PWindow;
begin
  if not GNW_win_init_flag then
    Exit;

  w := GNW_find(win);
  if w = nil then
    Exit;

  if (w^.Flags and WINDOW_HIDDEN) = 0 then
  begin
    w^.Flags := w^.Flags or WINDOW_HIDDEN;
    refresh_all(@w^.Rect, nil);
  end;
end;

// 0x4C2F5C
procedure win_move(win_id, x, y: Integer);
var
  w: PWindow;
  rect: TRect;
begin
  w := GNW_find(win_id);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  rectCopy(@rect, @w^.Rect);

  if x < 0 then
    x := 0;

  if y < 0 then
    y := 0;

  if (w^.Flags and WINDOW_MANAGED) <> 0 then
    x := x + 2;

  if x + w^.Width - 1 > scr_size.lrx then
    x := scr_size.lrx - w^.Width + 1;

  if y + w^.Height - 1 > scr_size.lry then
    y := scr_size.lry - w^.Height + 1;

  if (w^.Flags and WINDOW_MANAGED) <> 0 then
    x := x and (not $03);

  w^.Rect.ulx := x;
  w^.Rect.uly := y;
  w^.Rect.lrx := w^.Width + x - 1;
  w^.Rect.lry := w^.Height + y - 1;

  if (w^.Flags and WINDOW_HIDDEN) = 0 then
  begin
    GNW_win_refresh(w, @w^.Rect, nil);

    if GNW_win_init_flag then
      refresh_all(@rect, nil);
  end;
end;

// 0x4C3018
procedure win_draw(win: Integer);
var
  w: PWindow;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  GNW_win_refresh(w, @w^.Rect, nil);
end;

// 0x4C303C
procedure win_draw_rect(win: Integer; rect: PRect);
var
  w: PWindow;
  newRect: TRect;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  rectCopy(@newRect, rect);
  rectOffset(@newRect, w^.Rect.ulx, w^.Rect.uly);

  GNW_win_refresh(w, @newRect, nil);
end;

// 0x4C3094
procedure GNW_win_refresh(w: PWindow; rect: PRect; a3: PByte);
var
  v26, v20, v23, v24: TRectPtr;
  v16: PRectData;
  dest_pitch: Integer;
  scrWidth, rWidth, rHeight: Integer;
  buf: PByte;
begin
  dest_pitch := 0;

  if (w^.Flags and WINDOW_HIDDEN) <> 0 then
    Exit;

  if ((w^.Flags and WINDOW_TRANSPARENT) <> 0) and buffering_ and (doing_refresh_all = 0) then
  begin
    // TODO: Incomplete - transparent window with buffering.
  end
  else
  begin
    v26 := rect_malloc;
    if v26 = nil then
      Exit;

    v26^.Next := nil;

    if w^.Rect.ulx > rect^.ulx then
      v26^.Rect.ulx := w^.Rect.ulx
    else
      v26^.Rect.ulx := rect^.ulx;

    if w^.Rect.uly > rect^.uly then
      v26^.Rect.uly := w^.Rect.uly
    else
      v26^.Rect.uly := rect^.uly;

    if w^.Rect.lrx < rect^.lrx then
      v26^.Rect.lrx := w^.Rect.lrx
    else
      v26^.Rect.lrx := rect^.lrx;

    if w^.Rect.lry < rect^.lry then
      v26^.Rect.lry := w^.Rect.lry
    else
      v26^.Rect.lry := rect^.lry;

    if (v26^.Rect.lrx >= v26^.Rect.ulx) and (v26^.Rect.lry >= v26^.Rect.uly) then
    begin
      if a3 <> nil then
        dest_pitch := rect^.lrx - rect^.ulx + 1;

      win_clip(w, @v26, a3);

      scrWidth := scr_size.lrx - scr_size.ulx + 1;

      if w^.Id <> 0 then
      begin
        v20 := v26;
        while v20 <> nil do
        begin
          GNW_button_refresh(w, @v20^.Rect);

          rWidth := v20^.Rect.lrx - v20^.Rect.ulx + 1;
          rHeight := v20^.Rect.lry - v20^.Rect.uly + 1;

          if a3 <> nil then
          begin
            if buffering_ and ((w^.Flags and WINDOW_TRANSPARENT) <> 0) then
            begin
              if Assigned(w^.BlitProc) then
                w^.BlitProc(
                  w^.Buffer + v20^.Rect.ulx - w^.Rect.ulx + (v20^.Rect.uly - w^.Rect.uly) * w^.Width,
                  rWidth, rHeight, w^.Width,
                  a3 + dest_pitch * (v20^.Rect.uly - rect^.uly) + v20^.Rect.ulx - rect^.ulx,
                  dest_pitch);
            end
            else
            begin
              buf_to_buf(
                w^.Buffer + v20^.Rect.ulx - w^.Rect.ulx + (v20^.Rect.uly - w^.Rect.uly) * w^.Width,
                rWidth, rHeight, w^.Width,
                a3 + dest_pitch * (v20^.Rect.uly - rect^.uly) + v20^.Rect.ulx - rect^.ulx,
                dest_pitch);
            end;
          end
          else
          begin
            if buffering_ then
            begin
              if (w^.Flags and WINDOW_TRANSPARENT) <> 0 then
              begin
                if Assigned(w^.BlitProc) then
                  w^.BlitProc(
                    w^.Buffer + v20^.Rect.ulx - w^.Rect.ulx + (v20^.Rect.uly - w^.Rect.uly) * w^.Width,
                    rWidth, rHeight, w^.Width,
                    screen_buffer + v20^.Rect.uly * scrWidth + v20^.Rect.ulx,
                    scrWidth);
              end
              else
              begin
                buf_to_buf(
                  w^.Buffer + v20^.Rect.ulx - w^.Rect.ulx + (v20^.Rect.uly - w^.Rect.uly) * w^.Width,
                  rWidth, rHeight, w^.Width,
                  screen_buffer + v20^.Rect.uly * scrWidth + v20^.Rect.ulx,
                  scrWidth);
              end;
            end
            else
            begin
              if Assigned(scr_blit) then
                scr_blit(
                  w^.Buffer + v20^.Rect.ulx - w^.Rect.ulx + (v20^.Rect.uly - w^.Rect.uly) * w^.Width,
                  w^.Width,
                  rHeight,
                  0,
                  0,
                  rWidth,
                  rHeight,
                  v20^.Rect.ulx,
                  v20^.Rect.uly);
            end;
          end;

          v20 := v20^.Next;
        end;
      end
      else
      begin
        // Background window (id = 0)
        v16 := v26;
        while v16 <> nil do
        begin
          rWidth := v16^.Rect.lrx - v16^.Rect.ulx + 1;
          rHeight := v16^.Rect.lry - v16^.Rect.uly + 1;
          buf := PByte(mem_malloc(rWidth * rHeight));
          if buf <> nil then
          begin
            buf_fill(buf, rWidth, rHeight, rWidth, bk_color);
            if dest_pitch <> 0 then
            begin
              buf_to_buf(buf, rWidth, rHeight, rWidth,
                a3 + dest_pitch * (v16^.Rect.uly - rect^.uly) + v16^.Rect.ulx - rect^.ulx,
                dest_pitch);
            end
            else
            begin
              if buffering_ then
              begin
                buf_to_buf(buf, rWidth, rHeight, rWidth,
                  screen_buffer + v16^.Rect.uly * scrWidth + v16^.Rect.ulx,
                  scrWidth);
              end
              else
              begin
                if Assigned(scr_blit) then
                  scr_blit(buf, rWidth, rHeight, 0, 0, rWidth, rHeight,
                    v16^.Rect.ulx, v16^.Rect.uly);
              end;
            end;
            mem_free(buf);
          end;
          v16 := v16^.Next;
        end;
      end;

      // Final blit from screen_buffer if buffering
      v23 := v26;
      while v23 <> nil do
      begin
        v24 := v23^.Next;

        if buffering_ and (a3 = nil) then
        begin
          if Assigned(scr_blit) then
            scr_blit(
              screen_buffer + v23^.Rect.ulx + scrWidth * v23^.Rect.uly,
              scrWidth,
              v23^.Rect.lry - v23^.Rect.uly + 1,
              0,
              0,
              v23^.Rect.lrx - v23^.Rect.ulx + 1,
              v23^.Rect.lry - v23^.Rect.uly + 1,
              v23^.Rect.ulx,
              v23^.Rect.uly);
        end;

        rect_free(v23);
        v23 := v24;
      end;

      if (doing_refresh_all = 0) and (a3 = nil) and (not mouse_hidden) then
      begin
        if mouse_in(rect^.ulx, rect^.uly, rect^.lrx, rect^.lry) then
          mouse_show;
      end;
    end
    else
    begin
      rect_free(v26);
    end;
  end;
end;

// 0x4C3654
procedure win_refresh_all(rect: PRect);
begin
  if GNW_win_init_flag then
    refresh_all(rect, nil);
end;

// 0x4C3668
procedure win_clip(w: PWindow; rectListNodePtr: PPRectData; a3: PByte);
var
  winIdx: Integer;
  upperW: PWindow;
  rect: TRect;
begin
  winIdx := win_index[w^.Id] + 1;
  while winIdx < num_windows do
  begin
    if rectListNodePtr^ = nil then
      Break;

    upperW := win_list[winIdx];
    if (upperW^.Flags and WINDOW_HIDDEN) = 0 then
    begin
      if (not buffering_) or ((upperW^.Flags and WINDOW_TRANSPARENT) = 0) then
      begin
        rect_clip_list(rectListNodePtr, @upperW^.Rect);
      end
      else
      begin
        if doing_refresh_all = 0 then
        begin
          GNW_win_refresh(upperW, @upperW^.Rect, nil);
          rect_clip_list(rectListNodePtr, @upperW^.Rect);
        end;
      end;
    end;

    Inc(winIdx);
  end;

  if (a3 = screen_buffer) or (a3 = nil) then
  begin
    if not mouse_hidden then
    begin
      mouse_get_rect(@rect);
      rect_clip_list(rectListNodePtr, @rect);
    end;
  end;
end;

// 0x4C3714
procedure win_drag(win: Integer);
var
  w: PWindow;
  rect: TRect;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  win_show(win);

  rectCopy(@rect, @w^.Rect);

  GNW_do_bk_process;

  if vcr_update <> 3 then
    mouse_info;

  if ((w^.Flags and WINDOW_MANAGED) <> 0) and ((w^.Rect.ulx and 3) <> 0) then
    win_move(w^.Id, w^.Rect.ulx, w^.Rect.uly);
end;

// 0x4C38B0
procedure win_get_mouse_buf(a1: PByte);
var
  rect: TRect;
begin
  mouse_get_rect(@rect);
  refresh_all(@rect, a1);
end;

// 0x4C38CC
procedure refresh_all(rect: PRect; a2: PByte);
var
  index: Integer;
begin
  doing_refresh_all := 1;

  for index := 0 to num_windows - 1 do
    GNW_win_refresh(win_list[index], rect, a2);

  doing_refresh_all := 0;

  if a2 = nil then
  begin
    if not mouse_hidden then
    begin
      if mouse_in(rect^.ulx, rect^.uly, rect^.lrx, rect^.lry) then
        mouse_show;
    end;
  end;
end;

// 0x4C3940
function GNW_find(win: Integer): PWindow;
var
  v0: Integer;
begin
  if win = -1 then
    Exit(nil);

  if (win < 0) or (win >= MAX_WINDOW_COUNT) then
    Exit(nil);

  v0 := win_index[win];
  if v0 = -1 then
    Exit(nil);

  Result := win_list[v0];
end;

// 0x4C3968
function win_get_buf(win: Integer): PByte;
var
  w: PWindow;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(nil);

  if w = nil then
    Exit(nil);

  Result := w^.Buffer;
end;

// 0x4C3984
function win_get_top_win(x, y: Integer): Integer;
var
  index: Integer;
  w: PWindow;
begin
  for index := num_windows - 1 downto 0 do
  begin
    w := win_list[index];
    if (x >= w^.Rect.ulx) and (x <= w^.Rect.lrx) and
       (y >= w^.Rect.uly) and (y <= w^.Rect.lry) then
      Exit(w^.Id);
  end;
  Result := -1;
end;

// 0x4C39D0
function win_width(win: Integer): Integer;
var
  w: PWindow;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(-1);

  if w = nil then
    Exit(-1);

  Result := w^.Width;
end;

// 0x4C39EC
function win_height(win: Integer): Integer;
var
  w: PWindow;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(-1);

  if w = nil then
    Exit(-1);

  Result := w^.Height;
end;

// 0x4C3A08
function win_get_rect(win: Integer; rect: PRect): Integer;
var
  w: PWindow;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(-1);

  if w = nil then
    Exit(-1);

  rectCopy(rect, @w^.Rect);
  Result := 0;
end;

// 0x4C3A34
function win_check_all_buttons: Integer;
var
  i, v1: Integer;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  v1 := -1;
  for i := num_windows - 1 downto 1 do
  begin
    if GNW_check_buttons(win_list[i], @v1) = 0 then
      Break;

    if (win_list[i]^.Flags and WINDOW_MODAL) <> 0 then
      Break;
  end;

  Result := v1;
end;

// 0x4C3A94
function GNW_find_button(btn: Integer; out_win: PPWindow): PButton;
var
  i: Integer;
  w: PWindow;
  button: PButton;
begin
  for i := 0 to num_windows - 1 do
  begin
    w := win_list[i];
    button := w^.ButtonListHead;
    while button <> nil do
    begin
      if button^.Id = btn then
      begin
        if out_win <> nil then
          out_win^ := w;
        Exit(button);
      end;
      button := button^.Next;
    end;
  end;
  Result := nil;
end;

// 0x4C3AEC
function GNW_check_menu_bars(a1: Integer): Integer;
var
  v1: Integer;
  index: Integer;
  w: PWindow;
  pulldownIndex: Integer;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  v1 := a1;
  for index := num_windows - 1 downto 1 do
  begin
    w := win_list[index];
    if w^.MenuBar_ <> nil then
    begin
      for pulldownIndex := 0 to w^.MenuBar_^.PulldownsLength - 1 do
      begin
        if v1 = w^.MenuBar_^.Pulldowns[pulldownIndex].KeyCode then
        begin
          v1 := GNW_process_menu(w^.MenuBar_, pulldownIndex);
          Break;
        end;
      end;
    end;

    if (w^.Flags and WINDOW_MODAL) <> 0 then
      Break;
  end;

  Result := v1;
end;

// 0x4C4190
procedure win_set_minimized_title(title: PAnsiChar);
var
  len: Integer;
begin
  if title = nil then
    Exit;

  len := Length(title);
  if len > 255 then
    len := 255;
  Move(title^, GNW95_title[0], len);
  GNW95_title[len] := #0;

  if gSdlWindow <> nil then
    SDL_SetWindowTitle(gSdlWindow, @GNW95_title[0]);
end;

// 0x4C4204
procedure win_set_trans_b2b(id: Integer; trans_b2b: TWindowBlitProc);
var
  w: PWindow;
begin
  w := GNW_find(id);

  if not GNW_win_init_flag then
    Exit;

  if w = nil then
    Exit;

  if (w^.Flags and WINDOW_TRANSPARENT) = 0 then
    Exit;

  if Assigned(trans_b2b) then
    w^.BlitProc := trans_b2b
  else
    w^.BlitProc := TWindowBlitProc(@trans_buf_to_buf);
end;

// 0x4C422C
function colorOpen_cb(const path: PAnsiChar): Pointer; cdecl;
begin
  Result := db_fopen(path, 'rb');
end;

// 0x4C4298
function colorRead_cb(handle: Pointer; buf: Pointer; count: SizeUInt): Integer; cdecl;
begin
  Result := Integer(db_fread(buf, 1, count, PDB_FILE(handle)));
end;

// 0x4C42A0
function colorClose_cb(handle: Pointer): Integer; cdecl;
begin
  Result := db_fclose(PDB_FILE(handle));
end;

// 0x4C42B8
function GNWSystemError(str: PAnsiChar): Boolean;
begin
  SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, 'Error', str, nil);
  Result := True;
end;

finalization
  // Equivalent to atexit(win_exit) in C++ - ensures video mode is restored on exit
  if GNW_win_init_flag then
    win_exit;

end.
