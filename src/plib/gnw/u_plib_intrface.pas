{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/intrface.h + intrface.cc
// High-level UI components: list select, string input, message box, pulldown menus.
unit u_plib_intrface;

interface

uses
  u_rect, u_gnw_types;

type
  TSelectFunc = procedure(items: PPAnsiChar; index: Integer); cdecl;

function win_list_select(title: PAnsiChar; fileList: PPAnsiChar;
  fileListLength: Integer; callback: TSelectFunc;
  x, y, color: Integer): Integer;
function win_list_select_at(title: PAnsiChar; fileList: PPAnsiChar;
  fileListLength: Integer; callback: TSelectFunc;
  x, y, color, start: Integer): Integer;
function win_get_str(dest: PAnsiChar; length_: Integer;
  title: PAnsiChar; x, y: Integer): Integer;
function win_msg(str: PAnsiChar; x, y, flags: Integer): Integer;
function win_pull_down(items: PPAnsiChar; itemsLength, x, y, color: Integer): Integer;
function win_debug(str: PAnsiChar): Integer;
function win_register_menu_bar(win, x, y, width, height,
  foregroundColor, backgroundColor: Integer): Integer;
function win_register_menu_pulldown(win, x: Integer; title: PAnsiChar;
  keyCode, itemsLength: Integer; items: PPAnsiChar;
  foregroundColor, backgroundColor: Integer): Integer;
procedure win_delete_menu_bar(win: Integer);
function win_width_needed(fileNameList: PPAnsiChar; fileNameListLength: Integer): Integer;
function win_input_str(win: Integer; dest: PAnsiChar;
  maxLength, x, y, textColor, backgroundColor: Integer): Integer;
procedure GNW_intr_init;
procedure win_timed_msg_defaults(persistence: LongWord);
procedure GNW_intr_exit;
function GNW_process_menu(menuBar: PMenuBar; pulldownIndex: Integer): Integer;

implementation

uses
  SysUtils,
  u_memory, u_gnw, u_button, u_text, u_grbuf, u_input, u_mouse,
  u_color, u_svga, u_fps_limiter, u_kb;

// Forward declarations for static helpers
function create_pull_down(stringList: PPAnsiChar; stringListLength, x, y,
  foregroundColor, backgroundColor: Integer; rect: PRect): Integer; forward;
procedure win_debug_delete(btn, keyCode: Integer); cdecl; forward;
function find_first_letter(ch: Integer; stringList: PPAnsiChar;
  stringListLength: Integer): Integer; forward;
function process_pull_down(win: Integer; rect: PRect; items: PPAnsiChar;
  itemsLength, foregroundColor, backgroundColor: Integer;
  menuBar: PMenuBar; pulldownIndex: Integer): Integer; forward;
function calc_max_field_chars_wcursor(value1, value2: Integer): Integer; forward;
procedure tm_watch_msgs; cdecl; forward;
procedure tm_kill_msg; forward;
procedure tm_kill_out_of_order(queueIndex: Integer); forward;
procedure tm_click_response(btn: Integer); forward;
function tm_index_active(queueIndex: Integer): Integer; forward;

type
  TTmLocation = record
    taken: Integer;
    y: Integer;
  end;

  TTmQueue = record
    created: Integer;
    id: Integer;
    location: Integer;
  end;

var
  // 0x53A268
  wd: Integer = -1;
  // 0x53A26C
  curr_menu: PMenuBar = nil;

  // 0x53A270
  tm_watch_active: Boolean = False;

  // 0x6B06D0
  tm_location: array[0..4] of TTmLocation;

  // 0x6B06F8
  tm_queue: array[0..4] of TTmQueue;

  // 0x6B0734
  tm_text_y: Integer;
  // 0x6B0738
  tm_text_x: Integer;
  // 0x6B073C
  tm_h: Integer;
  // 0x6B0740
  tm_persistence: LongWord = 3000;
  // 0x6B0744
  tm_kill: Integer = -1;
  // 0x6B0748
  scr_center_x: Integer;
  // 0x6B074C
  tm_add: Integer;

  // Static locals from win_debug
  debug_curry: Integer = 0;
  debug_currx: Integer = 0;

// 0x4C6AA0
function win_list_select(title: PAnsiChar; fileList: PPAnsiChar;
  fileListLength: Integer; callback: TSelectFunc;
  x, y, color: Integer): Integer;
begin
  Result := win_list_select_at(title, fileList, fileListLength, callback, x, y, color, 0);
end;

// 0x4C6AEC
function win_list_select_at(title: PAnsiChar; fileList: PPAnsiChar;
  fileListLength: Integer; callback: TSelectFunc;
  x, y, color, start: Integer): Integer;
var
  listViewWidth, windowWidth, titleWidth: Integer;
  win, windowHeight, listViewCapacity, heightMultiplier: Integer;
  window: PWindow;
  windowRect: PRect;
  windowBuffer: PByte;
  listViewX, listViewY: Integer;
  listViewBuffer: PByte;
  listViewMaxY: Integer;
  scrollOffset, selectedItemIndex, newScrollOffset, oldScrollOffset: Integer;
  scrollbarX, scrollbarY, scrollbarKnobSize, scrollbarHeight: Integer;
  scrollbarBuffer: PByte;
  idx: Integer;
  absoluteSelectedItemIndex: Integer;
  previousSelectedItemIndex: Integer;
  keyCode, mouseX, mouseY: Integer;
  itemRect: TRect;
  textColor, colorIndex: Integer;
  found: Integer;
begin
  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  listViewWidth := win_width_needed(fileList, fileListLength);
  windowWidth := listViewWidth + 16;

  titleWidth := text_width(title);
  if titleWidth > windowWidth then
  begin
    windowWidth := titleWidth;
    listViewWidth := titleWidth - 16;
  end;

  windowWidth := windowWidth + 20;

  win := -1;
  listViewCapacity := 10;
  for heightMultiplier := 13 downto 9 do
  begin
    windowHeight := heightMultiplier * text_height() + 22;
    win := win_add(x, y, windowWidth, windowHeight, 256,
      WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
    if win <> -1 then
      Break;
    Dec(listViewCapacity);
  end;

  if win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  window := GNW_find(win);
  windowRect := @window^.Rect;
  windowBuffer := window^.Buffer;

  draw_box(windowBuffer, windowWidth, 0, 0,
    windowWidth - 1, windowHeight - 1, colorTable[0]);
  draw_shaded_box(windowBuffer, windowWidth, 1, 1,
    windowWidth - 2, windowHeight - 2,
    colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);

  buf_fill(windowBuffer + windowWidth * 5 + 5,
    windowWidth - 11, text_height() + 3, windowWidth,
    colorTable[GNW_wcolor[0]]);

  text_to_buf(windowBuffer + windowWidth div 2 + 8 * windowWidth - text_width(title) div 2,
    title, windowWidth, windowWidth, colorTable[GNW_wcolor[3]]);

  draw_shaded_box(windowBuffer, windowWidth, 5, 5,
    windowWidth - 6, text_height() + 8,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);

  listViewX := 8;
  listViewY := text_height() + 16;
  listViewBuffer := windowBuffer + windowWidth * listViewY + listViewX;
  listViewMaxY := listViewCapacity * text_height() + listViewY;

  buf_fill(listViewBuffer + windowWidth * (-2) + (-3),
    listViewWidth + listViewX - 2,
    listViewCapacity * text_height() + 2,
    windowWidth,
    colorTable[GNW_wcolor[0]]);

  scrollOffset := start;
  if (start < 0) or (start >= fileListLength) then
    scrollOffset := 0;

  if fileListLength - scrollOffset < listViewCapacity then
  begin
    newScrollOffset := fileListLength - listViewCapacity;
    if newScrollOffset < 0 then
      newScrollOffset := 0;
    oldScrollOffset := scrollOffset;
    scrollOffset := newScrollOffset;
    selectedItemIndex := oldScrollOffset - newScrollOffset;
  end
  else
    selectedItemIndex := 0;

  if fileListLength < listViewCapacity then
    win_text(win, fileList + start, fileListLength, listViewWidth,
      listViewX, listViewY, color or $2000000)
  else
    win_text(win, fileList + start, listViewCapacity, listViewWidth,
      listViewX, listViewY, color or $2000000);

  lighten_buf(listViewBuffer + windowWidth * selectedItemIndex * text_height(),
    listViewWidth, text_height(), windowWidth);

  draw_shaded_box(windowBuffer, windowWidth, 5, listViewY - 3,
    listViewWidth + 10, listViewMaxY,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);

  win_register_text_button(win, windowWidth - 25, listViewY - 3,
    -1, -1, KEY_ARROW_UP, -1, #$18, 0);

  win_register_text_button(win, windowWidth - 25,
    listViewMaxY - text_height() - 5,
    -1, -1, KEY_ARROW_DOWN, -1, #$19, 0);

  win_register_text_button(win, windowWidth div 2 - 32,
    windowHeight - 8 - text_height() - 6,
    -1, -1, -1, KEY_ESCAPE, 'Done', 0);

  scrollbarX := windowWidth - 21;
  scrollbarY := listViewY + text_height() + 7;
  scrollbarKnobSize := 14;
  scrollbarHeight := listViewMaxY - scrollbarY;
  scrollbarBuffer := windowBuffer + windowWidth * scrollbarY + scrollbarX;

  buf_fill(scrollbarBuffer, scrollbarKnobSize + 1,
    scrollbarHeight - text_height() - 8, windowWidth,
    colorTable[GNW_wcolor[0]]);

  win_register_button(win, scrollbarX, scrollbarY,
    scrollbarKnobSize + 1, scrollbarHeight - text_height() - 8,
    -1, -1, 2048, -1, nil, nil, nil, 0);

  draw_shaded_box(windowBuffer, windowWidth,
    windowWidth - 22, scrollbarY - 1,
    scrollbarX + scrollbarKnobSize + 1,
    listViewMaxY - text_height() - 9,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);
  draw_shaded_box(windowBuffer, windowWidth,
    scrollbarX, scrollbarY,
    scrollbarX + scrollbarKnobSize,
    scrollbarY + scrollbarKnobSize,
    colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);

  lighten_buf(scrollbarBuffer, scrollbarKnobSize, scrollbarKnobSize, windowWidth);

  for idx := 0 to listViewCapacity - 1 do
    win_register_button(win, listViewX, listViewY + idx * text_height(),
      listViewWidth, text_height(),
      512 + idx, -1, 1024 + idx, -1, nil, nil, nil, 0);

  win_register_button(win, 0, 0, windowWidth, text_height() + 8,
    -1, -1, -1, -1, nil, nil, nil, BUTTON_FLAG_0x10);

  win_draw(win);

  absoluteSelectedItemIndex := -1;
  previousSelectedItemIndex := -1;

  while True do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;
    mouse_get_position(@mouseX, @mouseY);

    if (keyCode = KEY_RETURN) or
       ((keyCode >= 1024) and (keyCode < listViewCapacity + 1024)) then
    begin
      if selectedItemIndex <> -1 then
      begin
        absoluteSelectedItemIndex := scrollOffset + selectedItemIndex;
        if absoluteSelectedItemIndex < fileListLength then
        begin
          if callback = nil then
            Break;
          callback(fileList, absoluteSelectedItemIndex);
        end;
        absoluteSelectedItemIndex := -1;
      end;
    end
    else if keyCode = 2048 then
    begin
      if window^.Rect.uly + scrollbarY > mouseY then
        keyCode := KEY_PAGE_UP
      else if window^.Rect.uly + scrollbarKnobSize + scrollbarY < mouseY then
        keyCode := KEY_PAGE_DOWN;
    end;

    if keyCode = KEY_ESCAPE then
      Break;

    if (keyCode >= 512) and (keyCode < listViewCapacity + 512) then
    begin
      idx := keyCode - 512;
      if (idx <> selectedItemIndex) and (idx < fileListLength) then
      begin
        previousSelectedItemIndex := selectedItemIndex;
        selectedItemIndex := idx;
        keyCode := -3;
      end
      else
        Continue;
    end
    else
    begin
      case keyCode of
        KEY_HOME:
          if scrollOffset > 0 then
          begin
            keyCode := -4;
            scrollOffset := 0;
          end;
        KEY_ARROW_UP:
          if selectedItemIndex > 0 then
          begin
            keyCode := -3;
            previousSelectedItemIndex := selectedItemIndex;
            Dec(selectedItemIndex);
          end
          else if scrollOffset > 0 then
          begin
            keyCode := -4;
            Dec(scrollOffset);
          end;
        KEY_PAGE_UP:
          if scrollOffset > 0 then
          begin
            scrollOffset := scrollOffset - listViewCapacity;
            if scrollOffset < 0 then
              scrollOffset := 0;
            keyCode := -4;
          end;
        KEY_END:
          if scrollOffset < fileListLength - listViewCapacity then
          begin
            keyCode := -4;
            scrollOffset := fileListLength - listViewCapacity;
          end;
        KEY_ARROW_DOWN:
          if (selectedItemIndex < listViewCapacity - 1) and
             (selectedItemIndex < fileListLength - 1) then
          begin
            keyCode := -3;
            previousSelectedItemIndex := selectedItemIndex;
            Inc(selectedItemIndex);
          end
          else if scrollOffset + listViewCapacity < fileListLength then
          begin
            keyCode := -4;
            Inc(scrollOffset);
          end;
        KEY_PAGE_DOWN:
          if scrollOffset < fileListLength - listViewCapacity then
          begin
            scrollOffset := scrollOffset + listViewCapacity;
            if scrollOffset > fileListLength - listViewCapacity then
              scrollOffset := fileListLength - listViewCapacity;
            keyCode := -4;
          end;
      else
        if fileListLength > listViewCapacity then
        begin
          if ((keyCode >= Ord('a')) and (keyCode <= Ord('z'))) or
             ((keyCode >= Ord('A')) and (keyCode <= Ord('Z'))) then
          begin
            found := find_first_letter(keyCode, fileList, fileListLength);
            if found <> -1 then
            begin
              scrollOffset := found;
              if scrollOffset > fileListLength - listViewCapacity then
                scrollOffset := fileListLength - listViewCapacity;
              keyCode := -4;
              selectedItemIndex := found - scrollOffset;
            end;
          end;
        end;
      end;
    end;

    if keyCode = -4 then
    begin
      buf_fill(listViewBuffer, listViewWidth,
        listViewMaxY - listViewY, windowWidth,
        colorTable[GNW_wcolor[0]]);

      if fileListLength < listViewCapacity then
        win_text(win, fileList + scrollOffset, fileListLength,
          listViewWidth, listViewX, listViewY, color or $2000000)
      else
        win_text(win, fileList + scrollOffset, listViewCapacity,
          listViewWidth, listViewX, listViewY, color or $2000000);

      lighten_buf(listViewBuffer + windowWidth * selectedItemIndex * text_height(),
        listViewWidth, text_height(), windowWidth);

      if fileListLength > listViewCapacity then
      begin
        buf_fill(windowBuffer + windowWidth * scrollbarY + scrollbarX,
          scrollbarKnobSize + 1, scrollbarKnobSize + 1, windowWidth,
          colorTable[GNW_wcolor[0]]);

        scrollbarY := (scrollOffset * (listViewMaxY - listViewY - 2 * text_height() - 16 - scrollbarKnobSize - 1)) div (fileListLength - listViewCapacity)
          + listViewY + text_height() + 7;

        draw_shaded_box(windowBuffer, windowWidth,
          scrollbarX, scrollbarY,
          scrollbarX + scrollbarKnobSize,
          scrollbarY + scrollbarKnobSize,
          colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);

        lighten_buf(windowBuffer + windowWidth * scrollbarY + scrollbarX,
          scrollbarKnobSize, scrollbarKnobSize, windowWidth);

        GNW_win_refresh(window, windowRect, nil);
      end;
    end
    else if keyCode = -3 then
    begin
      itemRect.ulx := windowRect^.ulx + listViewX;
      itemRect.lrx := itemRect.ulx + listViewWidth;

      if previousSelectedItemIndex <> -1 then
      begin
        itemRect.uly := windowRect^.uly + listViewY + previousSelectedItemIndex * text_height();
        itemRect.lry := itemRect.uly + text_height();

        buf_fill(listViewBuffer + windowWidth * previousSelectedItemIndex * text_height(),
          listViewWidth, text_height(), windowWidth,
          colorTable[GNW_wcolor[0]]);

        if (color and $FF00) <> 0 then
        begin
          colorIndex := (color and $FF) - 1;
          textColor := (color and (not $FFFF)) or colorTable[GNW_wcolor[colorIndex]];
        end
        else
          textColor := color;

        text_to_buf(listViewBuffer + windowWidth * previousSelectedItemIndex * text_height(),
          PPAnsiChar(fileList)[scrollOffset + previousSelectedItemIndex],
          windowWidth, windowWidth, textColor);

        GNW_win_refresh(window, @itemRect, nil);
      end;

      if selectedItemIndex <> -1 then
      begin
        itemRect.uly := windowRect^.uly + listViewY + selectedItemIndex * text_height();
        itemRect.lry := itemRect.uly + text_height();

        lighten_buf(listViewBuffer + windowWidth * selectedItemIndex * text_height(),
          listViewWidth, text_height(), windowWidth);

        GNW_win_refresh(window, @itemRect, nil);
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  win_delete(win);

  Result := absoluteSelectedItemIndex;
end;

// 0x4C7858
function win_get_str(dest: PAnsiChar; length_: Integer;
  title: PAnsiChar; x, y: Integer): Integer;
var
  titleWidth, windowWidth, windowHeight, win: Integer;
  windowBuffer: PByte;
begin
  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  titleWidth := text_width(title) + 12;
  if titleWidth < text_max() * length_ then
    titleWidth := text_max() * length_;

  windowWidth := titleWidth + 16;
  if windowWidth < 160 then
    windowWidth := 160;

  windowHeight := 5 * text_height() + 16;

  win := win_add(x, y, windowWidth, windowHeight, 256,
    WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  win_border(win);

  windowBuffer := win_get_buf(win);

  buf_fill(windowBuffer + windowWidth * (text_height() + 14) + 14,
    windowWidth - 28, text_height() + 2, windowWidth,
    colorTable[GNW_wcolor[0]]);
  text_to_buf(windowBuffer + windowWidth * 8 + 8,
    title, windowWidth, windowWidth, colorTable[GNW_wcolor[4]]);

  draw_shaded_box(windowBuffer, windowWidth,
    14, text_height() + 14,
    windowWidth - 14, 2 * text_height() + 16,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);

  win_register_text_button(win, windowWidth div 2 - 72,
    windowHeight - 8 - text_height() - 6,
    -1, -1, -1, KEY_RETURN, 'Done', 0);

  win_register_text_button(win, windowWidth div 2 + 8,
    windowHeight - 8 - text_height() - 6,
    -1, -1, -1, KEY_ESCAPE, 'Cancel', 0);

  win_draw(win);

  win_input_str(win, dest, length_, 16, text_height() + 16,
    colorTable[GNW_wcolor[3]], colorTable[GNW_wcolor[0]]);

  win_delete(win);

  Result := 0;
end;

// 0x4C7E78
function win_msg(str: PAnsiChar; x, y, flags: Integer): Integer;
var
  windowHeight, windowWidth, win: Integer;
  window: PWindow;
  windowBuffer: PByte;
  textColor, colorIndex: Integer;
begin
  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  windowHeight := 3 * text_height() + 16;
  windowWidth := text_width(str) + 16;
  if windowWidth < 80 then
    windowWidth := 80;
  windowWidth := windowWidth + 16;

  win := win_add(x, y, windowWidth, windowHeight, 256,
    WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  win_border(win);

  window := GNW_find(win);
  windowBuffer := window^.Buffer;

  if (flags and $FF00) <> 0 then
  begin
    colorIndex := (flags and $FF) - 1;
    textColor := colorTable[GNW_wcolor[colorIndex]];
    textColor := textColor or (flags and (not $FFFF));
  end
  else
    textColor := flags;

  text_to_buf(windowBuffer + windowWidth * 8 + 16,
    str, windowWidth, windowWidth, textColor);

  win_register_text_button(win, windowWidth div 2 - 32,
    windowHeight - 8 - text_height() - 6,
    -1, -1, -1, KEY_ESCAPE, 'Done', 0);

  win_draw(win);

  while get_input <> KEY_ESCAPE do
  begin
    sharedFpsLimiter.Mark;
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  win_delete(win);

  Result := 0;
end;

// 0x4C7FA4
function win_pull_down(items: PPAnsiChar; itemsLength, x, y, color: Integer): Integer;
var
  rect: TRect;
  win: Integer;
begin
  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  win := create_pull_down(items, itemsLength, x, y, color,
    colorTable[GNW_wcolor[0]], @rect);
  if win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := process_pull_down(win, @rect, items, itemsLength, color,
    colorTable[GNW_wcolor[0]], nil, -1);
end;

// 0x4C8014
function create_pull_down(stringList: PPAnsiChar; stringListLength, x, y,
  foregroundColor, backgroundColor: Integer; rect: PRect): Integer;
var
  windowHeight, windowWidth, win: Integer;
begin
  windowHeight := stringListLength * text_height() + 16;
  windowWidth := win_width_needed(stringList, stringListLength) + 4;
  if (windowHeight < 2) or (windowWidth < 2) then
  begin
    Result := -1;
    Exit;
  end;

  win := win_add(x, y, windowWidth, windowHeight, backgroundColor,
    WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    Result := -1;
    Exit;
  end;

  win_text(win, stringList, stringListLength, windowWidth - 4, 2, 8, foregroundColor);
  win_box(win, 0, 0, windowWidth - 1, windowHeight - 1, colorTable[0]);
  win_box(win, 1, 1, windowWidth - 2, windowHeight - 2, foregroundColor);
  win_draw(win);
  win_get_rect(win, rect);

  Result := win;
end;

// 0x4C80E4
function process_pull_down(win: Integer; rect: PRect; items: PPAnsiChar;
  itemsLength, foregroundColor, backgroundColor: Integer;
  menuBar: PMenuBar; pulldownIndex: Integer): Integer;
begin
  // NOTE: Incomplete in the C++ source as well
  Result := -1;
end;

// 0x4C86EC
function win_debug(str: PAnsiChar): Integer;
var
  lineHeight: Integer;
  window: PWindow;
  windowBuffer: PByte;
  btn: Integer;
  temp: array[0..1] of AnsiChar;
  pch: PAnsiChar;
  characterWidth: Integer;
begin
  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  lineHeight := text_height();

  if wd = -1 then
  begin
    wd := win_add(80, 80, 300, 192, 256, WINDOW_MOVE_ON_TOP);
    if wd = -1 then
    begin
      Result := -1;
      Exit;
    end;

    win_border(wd);

    window := GNW_find(wd);
    windowBuffer := window^.Buffer;

    win_fill(wd, 8, 8, 284, lineHeight, $100 or 1);

    win_print(wd, 'Debug', 0,
      (300 - text_width('Debug')) div 2, 8,
      $2000000 or $100 or 4);

    draw_shaded_box(windowBuffer, 300, 8, 8, 291, lineHeight + 8,
      colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);

    win_fill(wd, 9, 26, 282, 135, $100 or 1);

    draw_shaded_box(windowBuffer, 300, 8, 25, 291, lineHeight + 145,
      colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);

    debug_currx := 9;
    debug_curry := 26;

    btn := win_register_text_button(wd,
      (300 - text_width('Close')) div 2,
      192 - 8 - lineHeight - 6,
      -1, -1, -1, -1, 'Close', 0);
    win_register_button_func(btn, nil, nil, nil, @win_debug_delete);

    win_register_button(wd, 8, 8, 284, lineHeight,
      -1, -1, -1, -1, nil, nil, nil, BUTTON_FLAG_0x10);
  end;

  temp[1] := #0;

  pch := str;
  while pch^ <> #0 do
  begin
    characterWidth := text_char_width(pch^);
    if (pch^ = #10) or (debug_currx + characterWidth > 291) then
    begin
      debug_currx := 9;
      debug_curry := debug_curry + lineHeight;
    end;

    while 160 - debug_curry < lineHeight do
    begin
      window := GNW_find(wd);
      windowBuffer := window^.Buffer;
      buf_to_buf(windowBuffer + lineHeight * 300 + 300 * 26 + 9,
        282, 134 - lineHeight - 1, 300,
        windowBuffer + 300 * 26 + 9, 300);
      debug_curry := debug_curry - lineHeight;
      win_fill(wd, 9, debug_curry, 282, lineHeight, $100 or 1);
    end;

    if pch^ <> #10 then
    begin
      temp[0] := pch^;
      win_print(wd, @temp[0], 0, debug_currx, debug_curry,
        $2000000 or $100 or 4);
      debug_currx := debug_currx + characterWidth + text_spacing();
    end;

    Inc(pch);
  end;

  win_draw(wd);

  Result := 0;
end;

// 0x4C8A3C
procedure win_debug_delete(btn, keyCode: Integer); cdecl;
begin
  win_delete(wd);
  wd := -1;
end;

// 0x4C8A54
function win_register_menu_bar(win, x, y, width, height,
  foregroundColor, backgroundColor: Integer): Integer;
var
  window: PWindow;
  right, bottom: Integer;
  mb: PMenuBar;
begin
  window := GNW_find(win);

  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  if window = nil then
  begin
    Result := -1;
    Exit;
  end;

  if window^.MenuBar_ <> nil then
  begin
    Result := -1;
    Exit;
  end;

  right := x + width;
  if right > window^.Width then
  begin
    Result := -1;
    Exit;
  end;

  bottom := y + height;
  if bottom > window^.Height then
  begin
    Result := -1;
    Exit;
  end;

  mb := PMenuBar(mem_malloc(SizeOf(TMenuBar)));
  if mb = nil then
  begin
    Result := -1;
    Exit;
  end;

  window^.MenuBar_ := mb;
  mb^.Win := win;
  mb^.Rect.ulx := x;
  mb^.Rect.uly := y;
  mb^.Rect.lrx := right - 1;
  mb^.Rect.lry := bottom - 1;
  mb^.PulldownsLength := 0;
  mb^.ForegroundColor := foregroundColor;
  mb^.BackgroundColor := backgroundColor;

  win_fill(win, x, y, width, height, backgroundColor);
  win_box(win, x, y, right - 1, bottom - 1, foregroundColor);

  Result := 0;
end;

// 0x4C8B48
function win_register_menu_pulldown(win, x: Integer; title: PAnsiChar;
  keyCode, itemsLength: Integer; items: PPAnsiChar;
  foregroundColor, backgroundColor: Integer): Integer;
var
  window: PWindow;
  mb: PMenuBar;
  titleX, titleY, btn: Integer;
  pulldown: PMenuPulldown;
begin
  window := GNW_find(win);

  if not GNW_win_init_flag then
  begin
    Result := -1;
    Exit;
  end;

  if window = nil then
  begin
    Result := -1;
    Exit;
  end;

  mb := window^.MenuBar_;
  if mb = nil then
  begin
    Result := -1;
    Exit;
  end;

  if mb^.PulldownsLength = 15 then
  begin
    Result := -1;
    Exit;
  end;

  titleX := mb^.Rect.ulx + x;
  titleY := (mb^.Rect.uly + mb^.Rect.lry - text_height()) div 2;
  btn := win_register_button(win, titleX, titleY,
    text_width(title), text_height(),
    -1, -1, keyCode, -1, nil, nil, nil, 0);
  if btn = -1 then
  begin
    Result := -1;
    Exit;
  end;

  win_print(win, title, 0, titleX, titleY,
    mb^.ForegroundColor or $2000000);

  pulldown := @mb^.Pulldowns[mb^.PulldownsLength];
  pulldown^.Rect.ulx := titleX;
  pulldown^.Rect.uly := titleY;
  pulldown^.Rect.lrx := text_width(title) + titleX - 1;
  pulldown^.Rect.lry := text_height() + titleY - 1;
  pulldown^.KeyCode := keyCode;
  pulldown^.ItemsLength := itemsLength;
  pulldown^.Items := items;
  pulldown^.ForegroundColor := foregroundColor;
  pulldown^.BackgroundColor := backgroundColor;

  Inc(mb^.PulldownsLength);

  Result := 0;
end;

// 0x4C8CB0
procedure win_delete_menu_bar(win: Integer);
var
  window: PWindow;
begin
  window := GNW_find(win);

  if not GNW_win_init_flag then
    Exit;

  if window = nil then
    Exit;

  if window^.MenuBar_ = nil then
    Exit;

  win_fill(win,
    window^.MenuBar_^.Rect.ulx,
    window^.MenuBar_^.Rect.uly,
    rectGetWidth(@window^.MenuBar_^.Rect),
    rectGetHeight(@window^.MenuBar_^.Rect),
    window^.Color);

  mem_free(window^.MenuBar_);
  window^.MenuBar_ := nil;
end;

// 0x4C8D10
function GNW_process_menu(menuBar: PMenuBar; pulldownIndex: Integer): Integer;
var
  keyCode: Integer;
  rect: TRect;
  pulldown: PMenuPulldown;
  win: Integer;
begin
  if curr_menu <> nil then
  begin
    Result := -1;
    Exit;
  end;

  curr_menu := menuBar;

  repeat
    pulldown := @menuBar^.Pulldowns[pulldownIndex];
    win := create_pull_down(pulldown^.Items, pulldown^.ItemsLength,
      pulldown^.Rect.ulx, menuBar^.Rect.lry + 1,
      pulldown^.ForegroundColor, pulldown^.BackgroundColor, @rect);
    if win = -1 then
    begin
      curr_menu := nil;
      Result := -1;
      Exit;
    end;

    keyCode := process_pull_down(win, @rect, pulldown^.Items,
      pulldown^.ItemsLength, pulldown^.ForegroundColor,
      pulldown^.BackgroundColor, menuBar, pulldownIndex);
    if keyCode < -1 then
      pulldownIndex := -2 - keyCode;
  until keyCode >= -1;

  if keyCode <> -1 then
  begin
    flush_input_buffer;
    GNW_add_input_buffer(keyCode);
    keyCode := menuBar^.Pulldowns[pulldownIndex].KeyCode;
  end;

  curr_menu := nil;

  Result := keyCode;
end;

// 0x4C8DD0
function find_first_letter(ch: Integer; stringList: PPAnsiChar;
  stringListLength: Integer): Integer;
var
  idx: Integer;
  s: PAnsiChar;
begin
  if (ch >= Ord('A')) and (ch <= Ord('Z')) then
    ch := ch + 32; // lowercase

  for idx := 0 to stringListLength - 1 do
  begin
    s := PPAnsiChar(stringList)[idx];
    if (Ord(s^) = ch) or (Ord(s^) = ch - 32) then
    begin
      Result := idx;
      Exit;
    end;
  end;

  Result := -1;
end;

// 0x4C8E10
function win_width_needed(fileNameList: PPAnsiChar; fileNameListLength: Integer): Integer;
var
  maxWidth, idx, w: Integer;
begin
  maxWidth := 0;
  for idx := 0 to fileNameListLength - 1 do
  begin
    w := text_width(PPAnsiChar(fileNameList)[idx]);
    if w > maxWidth then
      maxWidth := w;
  end;
  Result := maxWidth;
end;

// 0x4C8E3C
function win_input_str(win: Integer; dest: PAnsiChar;
  maxLength, x, y, textColor, backgroundColor: Integer): Integer;
var
  window: PWindow;
  buffer: PByte;
  cursorPos: Integer;
  lineHeight, stringWidth: Integer;
  dirtyRect: TRect;
  isFirstKey: Boolean;
  keyCode: Integer;
begin
  window := GNW_find(win);
  buffer := window^.Buffer + window^.Width * y + x;

  cursorPos := StrLen(dest);
  dest[cursorPos] := '_';
  dest[cursorPos + 1] := #0;

  lineHeight := text_height();
  stringWidth := text_width(dest);
  buf_fill(buffer, stringWidth, lineHeight, window^.Width, backgroundColor);
  text_to_buf(buffer, dest, stringWidth, window^.Width, textColor);

  dirtyRect.ulx := window^.Rect.ulx + x;
  dirtyRect.uly := window^.Rect.uly + y;
  dirtyRect.lrx := dirtyRect.ulx + stringWidth;
  dirtyRect.lry := dirtyRect.uly + lineHeight;
  GNW_win_refresh(window, @dirtyRect, nil);

  isFirstKey := True;
  while cursorPos <= maxLength do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input;
    if keyCode <> -1 then
    begin
      if keyCode = KEY_ESCAPE then
      begin
        dest[cursorPos] := #0;
        Result := -1;
        Exit;
      end;

      if keyCode = KEY_BACKSPACE then
      begin
        if cursorPos > 0 then
        begin
          stringWidth := text_width(dest);

          if isFirstKey then
          begin
            buf_fill(buffer, stringWidth, lineHeight, window^.Width, backgroundColor);

            dirtyRect.ulx := window^.Rect.ulx + x;
            dirtyRect.uly := window^.Rect.uly + y;
            dirtyRect.lrx := dirtyRect.ulx + stringWidth;
            dirtyRect.lry := dirtyRect.uly + lineHeight;
            GNW_win_refresh(window, @dirtyRect, nil);

            dest[0] := '_';
            dest[1] := #0;
            cursorPos := 1;
          end
          else
          begin
            dest[cursorPos] := ' ';
            dest[cursorPos - 1] := '_';
          end;

          buf_fill(buffer, stringWidth, lineHeight, window^.Width, backgroundColor);
          text_to_buf(buffer, dest, stringWidth, window^.Width, textColor);

          dirtyRect.ulx := window^.Rect.ulx + x;
          dirtyRect.uly := window^.Rect.uly + y;
          dirtyRect.lrx := dirtyRect.ulx + stringWidth;
          dirtyRect.lry := dirtyRect.uly + lineHeight;
          GNW_win_refresh(window, @dirtyRect, nil);

          dest[cursorPos] := #0;
          Dec(cursorPos, 2);

          isFirstKey := False;
        end
        else
          Dec(cursorPos);
      end
      else if keyCode = KEY_RETURN then
        Break
      else
      begin
        if cursorPos = maxLength then
          cursorPos := maxLength - 1
        else
        begin
          if (keyCode > 0) and (keyCode < 256) then
          begin
            dest[cursorPos] := AnsiChar(keyCode);
            dest[cursorPos + 1] := '_';
            dest[cursorPos + 2] := #0;

            stringWidth := text_width(dest);
            buf_fill(buffer, stringWidth, lineHeight, window^.Width, backgroundColor);
            text_to_buf(buffer, dest, stringWidth, window^.Width, textColor);

            dirtyRect.ulx := window^.Rect.ulx + x;
            dirtyRect.uly := window^.Rect.uly + y;
            dirtyRect.lrx := dirtyRect.ulx + stringWidth;
            dirtyRect.lry := dirtyRect.uly + lineHeight;
            GNW_win_refresh(window, @dirtyRect, nil);

            isFirstKey := False;
          end
          else
            Dec(cursorPos);
        end;
      end;
    end
    else
      Dec(cursorPos);

    renderPresent;
    sharedFpsLimiter.Throttle;

    Inc(cursorPos);
  end;

  dest[cursorPos] := #0;

  Result := 0;
end;

// 0x4C941C
function calc_max_field_chars_wcursor(value1, value2: Integer): Integer;
var
  s: PAnsiChar;
  len1, len2: Integer;
begin
  s := PAnsiChar(mem_malloc(17));
  if s = nil then
  begin
    Result := -1;
    Exit;
  end;

  len1 := Length(IntToStr(value1));
  len2 := Length(IntToStr(value2));

  mem_free(s);

  if len1 > len2 then
    Result := len1 + 1
  else
    Result := len2 + 1;
end;

// 0x4C97CC
procedure GNW_intr_init;
var
  v1, v2, i: Integer;
begin
  tm_persistence := 3000;
  tm_add := 0;
  tm_kill := -1;
  scr_center_x := scr_size.lrx div 2;

  if scr_size.lry >= 479 then
  begin
    tm_text_y := 16;
    tm_text_x := 16;
  end
  else
  begin
    tm_text_y := 10;
    tm_text_x := 10;
  end;

  tm_h := 2 * tm_text_y + text_height();

  v1 := scr_size.lry shr 3;
  v2 := scr_size.lry shr 2;

  for i := 0 to 4 do
  begin
    tm_location[i].y := v1 * i + v2;
    tm_location[i].taken := 0;
  end;
end;

// 0x4C987C
procedure win_timed_msg_defaults(persistence: LongWord);
begin
  tm_persistence := persistence;
end;

// 0x4C9884
procedure GNW_intr_exit;
begin
  remove_bk_process(@tm_watch_msgs);
  while tm_kill <> -1 do
    tm_kill_msg;
end;

// 0x4C9A48
procedure tm_watch_msgs; cdecl;
begin
  if tm_watch_active then
    Exit;

  tm_watch_active := True;
  while tm_kill <> -1 do
  begin
    if elapsed_time(tm_queue[tm_kill].created) < tm_persistence then
      Break;
    tm_kill_msg;
  end;
  tm_watch_active := False;
end;

// 0x4C9A9C
procedure tm_kill_msg;
var
  v0: Integer;
begin
  v0 := tm_kill;
  if v0 <> -1 then
  begin
    win_delete(tm_queue[tm_kill].id);
    tm_location[tm_queue[tm_kill].location].taken := 0;

    Inc(v0);
    if v0 = 5 then
      v0 := 0;

    if v0 = tm_add then
    begin
      tm_add := 0;
      tm_kill := -1;
      remove_bk_process(@tm_watch_msgs);
      v0 := tm_kill;
    end;
  end;

  tm_kill := v0;
end;

// 0x4C9B20
procedure tm_kill_out_of_order(queueIndex: Integer);
var
  v7, v6: Integer;
begin
  if tm_kill = -1 then
    Exit;

  if tm_index_active(queueIndex) = 0 then
    Exit;

  win_delete(tm_queue[queueIndex].id);
  tm_location[tm_queue[queueIndex].location].taken := 0;

  if queueIndex <> tm_kill then
  begin
    v6 := queueIndex;
    repeat
      v7 := v6 - 1;
      if v7 < 0 then
        v7 := 4;
      tm_queue[v6] := tm_queue[v7];
      v6 := v7;
    until v7 = tm_kill;
  end;

  Inc(tm_kill);
  if tm_kill = 5 then
    tm_kill := 0;

  if tm_add = tm_kill then
  begin
    tm_add := 0;
    tm_kill := -1;
    remove_bk_process(@tm_watch_msgs);
  end;
end;

// 0x4C9C04
procedure tm_click_response(btn: Integer);
var
  win, queueIndex: Integer;
begin
  if tm_kill = -1 then
    Exit;

  win := win_button_winID(btn);
  queueIndex := tm_kill;
  while win <> tm_queue[queueIndex].id do
  begin
    Inc(queueIndex);
    if queueIndex = 5 then
      queueIndex := 0;

    if (queueIndex = tm_kill) or (tm_index_active(queueIndex) = 0) then
      Exit;
  end;

  tm_kill_out_of_order(queueIndex);
end;

// 0x4C9C48
function tm_index_active(queueIndex: Integer): Integer;
begin
  if tm_kill <> tm_add then
  begin
    if tm_kill >= tm_add then
    begin
      if (queueIndex >= tm_add) and (queueIndex < tm_kill) then
      begin
        Result := 0;
        Exit;
      end;
    end
    else
    begin
      if (queueIndex < tm_kill) or (queueIndex >= tm_add) then
      begin
        Result := 0;
        Exit;
      end;
    end;
  end;
  Result := 1;
end;

end.
