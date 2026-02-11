unit u_bmpdlog;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/bmpdlog.h + bmpdlog.cc
// Bitmap dialog boxes: generic dialogs, file open/save dialogs.

interface

uses
  u_cache;

const
  // DialogBoxOptions
  DIALOG_BOX_LARGE                  = $01;
  DIALOG_BOX_MEDIUM                 = $02;
  DIALOG_BOX_NO_HORIZONTAL_CENTERING = $04;
  DIALOG_BOX_NO_VERTICAL_CENTERING  = $08;
  DIALOG_BOX_YES_NO                 = $10;
  DIALOG_BOX_0x20                   = $20;

  // DialogType
  DIALOG_TYPE_MEDIUM = 0;
  DIALOG_TYPE_LARGE  = 1;
  DIALOG_TYPE_COUNT  = 2;

  // FileDialogFrm
  FILE_DIALOG_FRM_BACKGROUND                = 0;
  FILE_DIALOG_FRM_LITTLE_RED_BUTTON_NORMAL  = 1;
  FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED = 2;
  FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_NORMAL  = 3;
  FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED = 4;
  FILE_DIALOG_FRM_SCROLL_UP_ARROW_NORMAL    = 5;
  FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED   = 6;
  FILE_DIALOG_FRM_COUNT                     = 7;

  // FileDialogScrollDirection
  FILE_DIALOG_SCROLL_DIRECTION_NONE = 0;
  FILE_DIALOG_SCROLL_DIRECTION_UP   = 1;
  FILE_DIALOG_SCROLL_DIRECTION_DOWN = 2;

var
  dbox: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  ytable: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  xtable: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  doneY: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  doneX: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  dblines: array[0..DIALOG_TYPE_COUNT - 1] of Integer;
  flgids: array[0..FILE_DIALOG_FRM_COUNT - 1] of Integer;
  flgids2: array[0..FILE_DIALOG_FRM_COUNT - 1] of Integer;

function dialog_out(title: PAnsiChar; body: PPAnsiChar; bodyLength: Integer;
  x, y, titleColor: Integer; a8: PAnsiChar; bodyColor, flags: Integer): Integer;
function file_dialog(title: PAnsiChar; fileList: PPAnsiChar; dest: PAnsiChar;
  fileListLength, x, y, flags: Integer): Integer;
function save_file_dialog(title: PAnsiChar; fileList: PPAnsiChar; dest: PAnsiChar;
  fileListLength, x, y, flags: Integer): Integer;

implementation

uses
  SysUtils,
  u_rect,
  u_gnw_types,
  u_gnw,
  u_button,
  u_grbuf,
  u_text,
  u_input,
  u_mouse,
  u_svga,
  u_color,
  u_art,
  u_message,
  u_wordwrap,
  u_platform_compat,
  u_debug,
  u_object_types,
  u_fps_limiter,
  u_kb,
  u_gsound,
  u_game,
  u_editor;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const
  FILE_DIALOG_LINE_COUNT = 12;
  FILE_DIALOG_DOUBLE_CLICK_DELAY = 32;

  LOAD_FILE_DIALOG_DONE_BUTTON_X   = 58;
  LOAD_FILE_DIALOG_DONE_BUTTON_Y   = 187;
  LOAD_FILE_DIALOG_DONE_LABEL_X    = 79;
  LOAD_FILE_DIALOG_DONE_LABEL_Y    = 187;
  LOAD_FILE_DIALOG_CANCEL_BUTTON_X = 163;
  LOAD_FILE_DIALOG_CANCEL_BUTTON_Y = 187;
  LOAD_FILE_DIALOG_CANCEL_LABEL_X  = 182;
  LOAD_FILE_DIALOG_CANCEL_LABEL_Y  = 187;

  SAVE_FILE_DIALOG_DONE_BUTTON_X   = 58;
  SAVE_FILE_DIALOG_DONE_BUTTON_Y   = 214;
  SAVE_FILE_DIALOG_DONE_LABEL_X    = 79;
  SAVE_FILE_DIALOG_DONE_LABEL_Y    = 213;
  SAVE_FILE_DIALOG_CANCEL_BUTTON_X = 163;
  SAVE_FILE_DIALOG_CANCEL_BUTTON_Y = 214;
  SAVE_FILE_DIALOG_CANCEL_LABEL_X  = 182;
  SAVE_FILE_DIALOG_CANCEL_LABEL_Y  = 213;

  FILE_DIALOG_TITLE_X = 49;
  FILE_DIALOG_TITLE_Y = 16;

  FILE_DIALOG_SCROLL_BUTTON_X = 36;
  FILE_DIALOG_SCROLL_BUTTON_Y = 44;

  FILE_DIALOG_FILE_LIST_X      = 55;
  FILE_DIALOG_FILE_LIST_Y      = 49;
  FILE_DIALOG_FILE_LIST_WIDTH  = 190;
  FILE_DIALOG_FILE_LIST_HEIGHT = 124;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
procedure PrntFlist(buffer: PByte; fileList: PPAnsiChar; pageOffset, fileListLength, selectedIndex, pitch: Integer); forward;

// ---------------------------------------------------------------------------
// Helper: max of two integers
// ---------------------------------------------------------------------------
function MaxInt(a, b: Integer): Integer; inline;
begin
  if a > b then Result := a else Result := b;
end;

// ---------------------------------------------------------------------------
// 0x41BE70
// ---------------------------------------------------------------------------
function dialog_out(title: PAnsiChar; body: PPAnsiChar; bodyLength: Integer;
  x, y, titleColor: Integer; a8: PAnsiChar; bodyColor, flags: Integer): Integer;
var
  messageList: TMessageList;
  messageListItem: TMessageListItem;
  savedFont: Integer;
  v86: Boolean;
  hasTwoButtons: Boolean;
  hasTitle: Boolean;
  maximumLineWidth: Integer;
  linesCount: Integer;
  index: Integer;
  dialogType: Integer;
  backgroundHandle: PCacheEntry;
  backgroundWidth: Integer;
  backgroundHeight: Integer;
  fid: Integer;
  background: PByte;
  win: Integer;
  windowBuf: PByte;
  doneBoxHandle: PCacheEntry;
  doneBox: PByte;
  doneBoxWidth: Integer;
  doneBoxHeight: Integer;
  downButtonHandle: PCacheEntry;
  downButton: PByte;
  downButtonWidth: Integer;
  downButtonHeight: Integer;
  upButtonHandle: PCacheEntry;
  upButton: PByte;
  v27: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  btn: Integer;
  v23: Integer;
  v41: Integer;
  v94: Integer;
  len: Integer;
  length_: Integer;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  count: SmallInt;
  v48: Integer;
  v51: Integer;
  str: array[0..259] of AnsiChar;
  rc: Integer;
  keyCode: Integer;
  doneBoxFid: Integer;
  downButtonFid: Integer;
  upButtonFid: Integer;
begin
  savedFont := text_curr();
  v86 := False;
  hasTwoButtons := False;

  if a8 <> nil then
    hasTwoButtons := True;

  hasTitle := False;
  if title <> nil then
    hasTitle := True;

  if (flags and DIALOG_BOX_YES_NO) <> 0 then
  begin
    hasTwoButtons := True;
    flags := flags or DIALOG_BOX_LARGE;
    flags := flags and (not DIALOG_BOX_0x20);
  end;

  maximumLineWidth := 0;
  if hasTitle then
    maximumLineWidth := text_width(title);

  linesCount := 0;
  for index := 0 to bodyLength - 1 do
  begin
    maximumLineWidth := MaxInt(text_width(PPAnsiChar(PByte(body) + index * SizeOf(PAnsiChar))^), maximumLineWidth);
    Inc(linesCount);
  end;

  if ((flags and DIALOG_BOX_LARGE) <> 0) or hasTwoButtons then
    dialogType := DIALOG_TYPE_LARGE
  else if (flags and DIALOG_BOX_MEDIUM) <> 0 then
    dialogType := DIALOG_TYPE_MEDIUM
  else
  begin
    if hasTitle then
      Inc(linesCount);

    if (maximumLineWidth > 168) or (linesCount > 5) then
      dialogType := DIALOG_TYPE_LARGE
    else
      dialogType := DIALOG_TYPE_MEDIUM;
  end;

  fid := art_id(OBJ_TYPE_INTERFACE, dbox[dialogType], 0, 0, 0);
  background := art_lock(fid, @backgroundHandle, @backgroundWidth, @backgroundHeight);
  if background = nil then
  begin
    text_font(savedFont);
    Result := -1;
    Exit;
  end;

  // Maintain original position in original resolution, otherwise center it.
  if screenGetWidth() <> 640 then
    x := x + (screenGetWidth() - 640) div 2;
  if screenGetHeight() <> 480 then
    y := y + (screenGetHeight() - 480) div 2;

  win := win_add(x, y, backgroundWidth, backgroundHeight, 256, WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    art_ptr_unlock(backgroundHandle);
    text_font(savedFont);
    Result := -1;
    Exit;
  end;

  windowBuf := win_get_buf(win);
  Move(background^, windowBuf^, backgroundWidth * backgroundHeight);

  doneBoxHandle := nil;
  doneBox := nil;
  downButtonHandle := nil;
  downButton := nil;
  upButtonHandle := nil;
  upButton := nil;

  if (flags and DIALOG_BOX_0x20) = 0 then
  begin
    doneBoxFid := art_id(OBJ_TYPE_INTERFACE, 209, 0, 0, 0);
    doneBox := art_lock(doneBoxFid, @doneBoxHandle, @doneBoxWidth, @doneBoxHeight);
    if doneBox = nil then
    begin
      art_ptr_unlock(backgroundHandle);
      text_font(savedFont);
      win_delete(win);
      Result := -1;
      Exit;
    end;

    downButtonFid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
    downButton := art_lock(downButtonFid, @downButtonHandle, @downButtonWidth, @downButtonHeight);
    if downButton = nil then
    begin
      art_ptr_unlock(doneBoxHandle);
      art_ptr_unlock(backgroundHandle);
      text_font(savedFont);
      win_delete(win);
      Result := -1;
      Exit;
    end;

    upButtonFid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
    upButton := art_ptr_lock_data(upButtonFid, 0, 0, @upButtonHandle);
    if upButton = nil then
    begin
      art_ptr_unlock(downButtonHandle);
      art_ptr_unlock(doneBoxHandle);
      art_ptr_unlock(backgroundHandle);
      text_font(savedFont);
      win_delete(win);
      Result := -1;
      Exit;
    end;

    if hasTwoButtons then
      v27 := doneX[dialogType]
    else
      v27 := (backgroundWidth - doneBoxWidth) div 2;

    buf_to_buf(doneBox, doneBoxWidth, doneBoxHeight, doneBoxWidth,
      windowBuf + backgroundWidth * doneY[dialogType] + v27, backgroundWidth);

    if not message_init(@messageList) then
    begin
      art_ptr_unlock(upButtonHandle);
      art_ptr_unlock(downButtonHandle);
      art_ptr_unlock(doneBoxHandle);
      art_ptr_unlock(backgroundHandle);
      text_font(savedFont);
      win_delete(win);
      Result := -1;
      Exit;
    end;

    StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('DBOX.MSG')]);

    if not message_load(@messageList, @path[0]) then
    begin
      art_ptr_unlock(upButtonHandle);
      art_ptr_unlock(downButtonHandle);
      art_ptr_unlock(doneBoxHandle);
      art_ptr_unlock(backgroundHandle);
      text_font(savedFont);
      // FIXME: Window is not removed.
      Result := -1;
      Exit;
    end;

    text_font(103);

    // 100 - DONE
    // 101 - YES
    if (flags and DIALOG_BOX_YES_NO) = 0 then
      messageListItem.num := 100
    else
      messageListItem.num := 101;

    if message_search(@messageList, @messageListItem) then
      text_to_buf(windowBuf + backgroundWidth * (doneY[dialogType] + 3) + v27 + 35,
        messageListItem.text, backgroundWidth, backgroundWidth, colorTable[18979]);

    btn := win_register_button(win, v27 + 13, doneY[dialogType] + 4,
      downButtonWidth, downButtonHeight, -1, -1, -1, 500, upButton, downButton, nil,
      BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

    v86 := True;
  end;

  if hasTwoButtons and (dialogType = DIALOG_TYPE_LARGE) then
  begin
    if v86 then
    begin
      if (flags and DIALOG_BOX_YES_NO) <> 0 then
        a8 := getmsg(@messageList, @messageListItem, 102);

      text_font(103);

      trans_buf_to_buf(doneBox,
        doneBoxWidth,
        doneBoxHeight,
        doneBoxWidth,
        windowBuf + backgroundWidth * doneY[dialogType] + doneX[dialogType] + doneBoxWidth + 24,
        backgroundWidth);

      text_to_buf(windowBuf + backgroundWidth * (doneY[dialogType] + 3) + doneX[dialogType] + doneBoxWidth + 59,
        a8, backgroundWidth, backgroundWidth, colorTable[18979]);

      btn := win_register_button(win,
        doneBoxWidth + doneX[dialogType] + 37,
        doneY[dialogType] + 4,
        downButtonWidth,
        downButtonHeight,
        -1, -1, -1, 501, upButton, downButton, nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);
    end
    else
    begin
      doneBoxFid := art_id(OBJ_TYPE_INTERFACE, 209, 0, 0, 0);
      doneBox := art_lock(doneBoxFid, @doneBoxHandle, @doneBoxWidth, @doneBoxHeight);
      if doneBox = nil then
      begin
        art_ptr_unlock(backgroundHandle);
        text_font(savedFont);
        win_delete(win);
        Result := -1;
        Exit;
      end;

      downButtonFid := art_id(OBJ_TYPE_INTERFACE, 9, 0, 0, 0);
      downButton := art_lock(downButtonFid, @downButtonHandle, @downButtonWidth, @downButtonHeight);
      if downButton = nil then
      begin
        art_ptr_unlock(doneBoxHandle);
        art_ptr_unlock(backgroundHandle);
        text_font(savedFont);
        win_delete(win);
        Result := -1;
        Exit;
      end;

      upButtonFid := art_id(OBJ_TYPE_INTERFACE, 8, 0, 0, 0);
      upButton := art_ptr_lock_data(upButtonFid, 0, 0, @upButtonHandle);
      if upButton = nil then
      begin
        art_ptr_unlock(downButtonHandle);
        art_ptr_unlock(doneBoxHandle);
        art_ptr_unlock(backgroundHandle);
        text_font(savedFont);
        win_delete(win);
        Result := -1;
        Exit;
      end;

      if not message_init(@messageList) then
      begin
        art_ptr_unlock(upButtonHandle);
        art_ptr_unlock(downButtonHandle);
        art_ptr_unlock(doneBoxHandle);
        art_ptr_unlock(backgroundHandle);
        text_font(savedFont);
        win_delete(win);
        Result := -1;
        Exit;
      end;

      StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('DBOX.MSG')]);

      if not message_load(@messageList, @path[0]) then
      begin
        art_ptr_unlock(upButtonHandle);
        art_ptr_unlock(downButtonHandle);
        art_ptr_unlock(doneBoxHandle);
        art_ptr_unlock(backgroundHandle);
        text_font(savedFont);
        win_delete(win);
        Result := -1;
        Exit;
      end;

      trans_buf_to_buf(doneBox,
        doneBoxWidth,
        doneBoxHeight,
        doneBoxWidth,
        windowBuf + backgroundWidth * doneY[dialogType] + doneX[dialogType],
        backgroundWidth);

      text_font(103);

      text_to_buf(windowBuf + backgroundWidth * (doneY[dialogType] + 3) + doneX[dialogType] + 35,
        a8, backgroundWidth, backgroundWidth, colorTable[18979]);

      btn := win_register_button(win,
        doneX[dialogType] + 13,
        doneY[dialogType] + 4,
        downButtonWidth,
        downButtonHeight,
        -1, -1, -1, 501, upButton, downButton, nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

      v86 := True;
    end;
  end;

  text_font(101);

  v23 := ytable[dialogType];

  if (flags and DIALOG_BOX_NO_VERTICAL_CENTERING) = 0 then
  begin
    v41 := dblines[dialogType] * text_height() div 2 + v23;
    v23 := v41 - ((bodyLength + 1) * text_height() div 2);
  end;

  if hasTitle then
  begin
    if (flags and DIALOG_BOX_NO_HORIZONTAL_CENTERING) <> 0 then
      text_to_buf(windowBuf + backgroundWidth * v23 + xtable[dialogType],
        title, backgroundWidth, backgroundWidth, titleColor)
    else
    begin
      length_ := text_width(title);
      text_to_buf(windowBuf + backgroundWidth * v23 + (backgroundWidth - length_) div 2,
        title, backgroundWidth, backgroundWidth, titleColor);
    end;
    v23 := v23 + text_height();
  end;

  for v94 := 0 to bodyLength - 1 do
  begin
    len := text_width(PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^);
    if len <= backgroundWidth - 26 then
    begin
      if (flags and DIALOG_BOX_NO_HORIZONTAL_CENTERING) <> 0 then
        text_to_buf(windowBuf + backgroundWidth * v23 + xtable[dialogType],
          PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^, backgroundWidth, backgroundWidth, bodyColor)
      else
      begin
        length_ := text_width(PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^);
        text_to_buf(windowBuf + backgroundWidth * v23 + (backgroundWidth - length_) div 2,
          PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^, backgroundWidth, backgroundWidth, bodyColor);
      end;
      v23 := v23 + text_height();
    end
    else
    begin
      if word_wrap(PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^,
          backgroundWidth - 26, @beginnings[0], @count) <> 0 then
        debug_printf(#10'Error: dialog_out');

      for v48 := 1 to count - 1 do
      begin
        v51 := beginnings[v48] - beginnings[v48 - 1];
        if v51 >= 260 then
          v51 := 259;

        StrLCopy(@str[0],
          PPAnsiChar(PByte(body) + v94 * SizeOf(PAnsiChar))^ + beginnings[v48 - 1],
          v51);
        str[v51] := #0;

        if (flags and DIALOG_BOX_NO_HORIZONTAL_CENTERING) <> 0 then
          text_to_buf(windowBuf + backgroundWidth * v23 + xtable[dialogType],
            @str[0], backgroundWidth, backgroundWidth, bodyColor)
        else
        begin
          length_ := text_width(@str[0]);
          text_to_buf(windowBuf + backgroundWidth * v23 + (backgroundWidth - length_) div 2,
            @str[0], backgroundWidth, backgroundWidth, bodyColor);
        end;
        v23 := v23 + text_height();
      end;
    end;
  end;

  win_draw(win);

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    keyCode := get_input();

    if keyCode = 500 then
      rc := 1
    else if keyCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      rc := 1;
    end
    else if (keyCode = KEY_ESCAPE) or (keyCode = 501) then
      rc := 0
    else
    begin
      if (flags and $10) <> 0 then
      begin
        if (keyCode = KEY_UPPERCASE_Y) or (keyCode = KEY_LOWERCASE_Y) then
          rc := 1
        else if (keyCode = KEY_UPPERCASE_N) or (keyCode = KEY_LOWERCASE_N) then
          rc := 0;
      end;
    end;

    if game_user_wants_to_quit <> 0 then
      rc := 1;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  win_delete(win);
  art_ptr_unlock(backgroundHandle);
  text_font(savedFont);

  if v86 then
  begin
    art_ptr_unlock(doneBoxHandle);
    art_ptr_unlock(downButtonHandle);
    art_ptr_unlock(upButtonHandle);
    message_exit(@messageList);
  end;

  Result := rc;
end;

// ---------------------------------------------------------------------------
// 0x41CC40
// ---------------------------------------------------------------------------
function file_dialog(title: PAnsiChar; fileList: PPAnsiChar; dest: PAnsiChar;
  fileListLength, x, y, flags: Integer): Integer;
var
  oldFont: Integer;
  isScrollable: Boolean;
  selectedFileIndex: Integer;
  pageOffset: Integer;
  maxPageOffset: Integer;
  frmBuffers: array[0..FILE_DIALOG_FRM_COUNT - 1] of PByte;
  frmHandles: array[0..FILE_DIALOG_FRM_COUNT - 1] of PCacheEntry;
  frmSizes: array[0..FILE_DIALOG_FRM_COUNT - 1] of TSize;
  index: Integer;
  fid: Integer;
  backgroundWidth: Integer;
  backgroundHeight: Integer;
  win: Integer;
  windowBuffer: PByte;
  messageList: TMessageList;
  messageListItem: TMessageListItem;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  done: PAnsiChar;
  cancel: PAnsiChar;
  doneBtn: Integer;
  cancelBtn: Integer;
  scrollUpBtn: Integer;
  scrollDownButton: Integer;
  doubleClickSelectedFileIndex: Integer;
  doubleClickTimer: Integer;
  rc: Integer;
  tick: LongWord;
  keyCode: Integer;
  scrollDirection: Integer;
  scrollCounter: Integer;
  isScrolling: Boolean;
  mouseX: Integer;
  mouseY: Integer;
  selectedLine: Integer;
  scrollDelay: LongWord;
  scrollTick: LongWord;
  delay: LongWord;
  innerKeyCode: Integer;
begin
  oldFont := text_curr();

  isScrollable := False;
  if fileListLength > FILE_DIALOG_LINE_COUNT then
    isScrollable := True;

  selectedFileIndex := 0;
  pageOffset := 0;
  maxPageOffset := fileListLength - (FILE_DIALOG_LINE_COUNT + 1);
  if maxPageOffset < 0 then
  begin
    maxPageOffset := fileListLength - 1;
    if maxPageOffset < 0 then
      maxPageOffset := 0;
  end;

  index := 0;
  while index < FILE_DIALOG_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, flgids[index], 0, 0, 0);
    frmBuffers[index] := art_lock(fid, @frmHandles[index], @frmSizes[index].Width, @frmSizes[index].Height);
    if frmBuffers[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        art_ptr_unlock(frmHandles[index]);
        Dec(index);
      end;
      Result := -1;
      Exit;
    end;
    Inc(index);
  end;

  backgroundWidth := frmSizes[FILE_DIALOG_FRM_BACKGROUND].Width;
  backgroundHeight := frmSizes[FILE_DIALOG_FRM_BACKGROUND].Height;

  // Maintain original position in original resolution, otherwise center it.
  if screenGetWidth() <> 640 then
    x := x + (screenGetWidth() - 640) div 2;
  if screenGetHeight() <> 480 then
    y := y + (screenGetHeight() - 480) div 2;

  win := win_add(x, y, backgroundWidth, backgroundHeight, 256, WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  windowBuffer := win_get_buf(win);
  Move(frmBuffers[FILE_DIALOG_FRM_BACKGROUND]^, windowBuffer^, backgroundWidth * backgroundHeight);

  if not message_init(@messageList) then
  begin
    win_delete(win);
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('DBOX.MSG')]);

  if not message_load(@messageList, @path[0]) then
  begin
    win_delete(win);
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  text_font(103);

  // DONE
  done := getmsg(@messageList, @messageListItem, 100);
  text_to_buf(windowBuffer + LOAD_FILE_DIALOG_DONE_LABEL_Y * backgroundWidth + LOAD_FILE_DIALOG_DONE_LABEL_X,
    done, backgroundWidth, backgroundWidth, colorTable[18979]);

  // CANCEL
  cancel := getmsg(@messageList, @messageListItem, 103);
  text_to_buf(windowBuffer + LOAD_FILE_DIALOG_CANCEL_LABEL_Y * backgroundWidth + LOAD_FILE_DIALOG_CANCEL_LABEL_X,
    cancel, backgroundWidth, backgroundWidth, colorTable[18979]);

  doneBtn := win_register_button(win,
    LOAD_FILE_DIALOG_DONE_BUTTON_X,
    LOAD_FILE_DIALOG_DONE_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Height,
    -1, -1, -1, 500,
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  cancelBtn := win_register_button(win,
    LOAD_FILE_DIALOG_CANCEL_BUTTON_X,
    LOAD_FILE_DIALOG_CANCEL_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Height,
    -1, -1, -1, 501,
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if cancelBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  scrollUpBtn := win_register_button(win,
    FILE_DIALOG_SCROLL_BUTTON_X,
    FILE_DIALOG_SCROLL_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Height,
    -1, 505, 506, 505,
    frmBuffers[FILE_DIALOG_FRM_SCROLL_UP_ARROW_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if scrollUpBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  scrollDownButton := win_register_button(win,
    FILE_DIALOG_SCROLL_BUTTON_X,
    FILE_DIALOG_SCROLL_BUTTON_Y + frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Height,
    frmSizes[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED].Height,
    -1, 503, 504, 503,
    frmBuffers[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if scrollUpBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_register_button(win,
    FILE_DIALOG_FILE_LIST_X,
    FILE_DIALOG_FILE_LIST_Y,
    FILE_DIALOG_FILE_LIST_WIDTH,
    FILE_DIALOG_FILE_LIST_HEIGHT,
    -1, -1, -1, 502,
    nil, nil, nil, 0);

  if title <> nil then
    text_to_buf(windowBuffer + backgroundWidth * FILE_DIALOG_TITLE_Y + FILE_DIALOG_TITLE_X,
      title, backgroundWidth, backgroundWidth, colorTable[18979]);

  text_font(101);

  PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
  win_draw(win);

  doubleClickSelectedFileIndex := -2;
  doubleClickTimer := FILE_DIALOG_DOUBLE_CLICK_DELAY;

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    tick := get_time();
    keyCode := get_input();
    scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_NONE;
    scrollCounter := 0;
    isScrolling := False;

    convertMouseWheelToArrowKey(@keyCode);

    if keyCode = 500 then
    begin
      if fileListLength <> 0 then
      begin
        StrLCopy(dest, PPAnsiChar(PByte(fileList) + (selectedFileIndex + pageOffset) * SizeOf(PAnsiChar))^, 16);
        rc := 0;
      end
      else
        rc := 1;
    end
    else if (keyCode = 501) or (keyCode = KEY_ESCAPE) then
      rc := 1
    else if (keyCode = 502) and (fileListLength <> 0) then
    begin
      mouse_get_position(@mouseX, @mouseY);

      selectedLine := (mouseY - y - FILE_DIALOG_FILE_LIST_Y) div text_height();
      if selectedLine - 1 < 0 then
        selectedLine := 0;

      if isScrollable or (selectedLine < fileListLength) then
      begin
        if selectedLine >= FILE_DIALOG_LINE_COUNT then
          selectedLine := FILE_DIALOG_LINE_COUNT - 1;
      end
      else
        selectedLine := fileListLength - 1;

      selectedFileIndex := selectedLine;
      if selectedFileIndex = doubleClickSelectedFileIndex then
      begin
        gsound_play_sfx_file('ib1p1xx1');
        StrLCopy(dest, PPAnsiChar(PByte(fileList) + (selectedFileIndex + pageOffset) * SizeOf(PAnsiChar))^, 16);
        rc := 0;
      end;

      doubleClickSelectedFileIndex := selectedFileIndex;
      PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
    end
    else if keyCode = 506 then
      scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_UP
    else if keyCode = 504 then
      scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_DOWN
    else
    begin
      case keyCode of
        KEY_ARROW_UP:
        begin
          Dec(pageOffset);
          if pageOffset < 0 then
          begin
            Dec(selectedFileIndex);
            if selectedFileIndex < 0 then
              selectedFileIndex := 0;
            pageOffset := 0;
          end;
          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          doubleClickSelectedFileIndex := -2;
        end;
        KEY_ARROW_DOWN:
        begin
          if isScrollable then
          begin
            Inc(pageOffset);
            // FIXME: Should be >= maxPageOffset (as in save dialog).
            if pageOffset > maxPageOffset then
            begin
              Inc(selectedFileIndex);
              // FIXME: Should be >= FILE_DIALOG_LINE_COUNT (as in save dialog).
              if selectedFileIndex > FILE_DIALOG_LINE_COUNT then
                selectedFileIndex := FILE_DIALOG_LINE_COUNT - 1;
              pageOffset := maxPageOffset;
            end;
          end
          else
          begin
            Inc(selectedFileIndex);
            if selectedFileIndex > maxPageOffset then
              selectedFileIndex := maxPageOffset;
          end;
          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          doubleClickSelectedFileIndex := -2;
        end;
        KEY_HOME:
        begin
          selectedFileIndex := 0;
          pageOffset := 0;
          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          doubleClickSelectedFileIndex := -2;
        end;
        KEY_END:
        begin
          if isScrollable then
          begin
            selectedFileIndex := FILE_DIALOG_LINE_COUNT - 1;
            pageOffset := maxPageOffset;
          end
          else
          begin
            selectedFileIndex := maxPageOffset;
            pageOffset := 0;
          end;
          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          doubleClickSelectedFileIndex := -2;
        end;
      end;
    end;

    if scrollDirection <> FILE_DIALOG_SCROLL_DIRECTION_NONE then
    begin
      scrollDelay := 4;
      doubleClickSelectedFileIndex := -2;
      while True do
      begin
        scrollTick := get_time();
        scrollCounter := scrollCounter + 1;
        if ((not isScrolling) and (scrollCounter = 1)) or (isScrolling and (scrollCounter > 14)) then
        begin
          isScrolling := True;

          if scrollCounter > 14 then
          begin
            scrollDelay := scrollDelay + 1;
            if scrollDelay > 24 then
              scrollDelay := 24;
          end;

          if scrollDirection = FILE_DIALOG_SCROLL_DIRECTION_UP then
          begin
            Dec(pageOffset);
            if pageOffset < 0 then
            begin
              Dec(selectedFileIndex);
              if selectedFileIndex < 0 then
                selectedFileIndex := 0;
              pageOffset := 0;
            end;
          end
          else
          begin
            if isScrollable then
            begin
              Inc(pageOffset);
              if pageOffset > maxPageOffset then
              begin
                Inc(selectedFileIndex);
                if selectedFileIndex >= FILE_DIALOG_LINE_COUNT then
                  selectedFileIndex := FILE_DIALOG_LINE_COUNT - 1;
                pageOffset := maxPageOffset;
              end;
            end
            else
            begin
              Inc(selectedFileIndex);
              if selectedFileIndex > maxPageOffset then
                selectedFileIndex := maxPageOffset;
            end;
          end;

          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          win_draw(win);
        end;

        if scrollCounter > 14 then
          delay := 1000 div scrollDelay
        else
          delay := 1000 div 24;
        while elapsed_time(scrollTick) < delay do
          { busy wait };

        if game_user_wants_to_quit <> 0 then
        begin
          rc := 1;
          Break;
        end;

        innerKeyCode := get_input();
        if (innerKeyCode = 505) or (innerKeyCode = 503) then
          Break;

        renderPresent();
      end;
    end
    else
    begin
      win_draw(win);

      Dec(doubleClickTimer);
      if doubleClickTimer = 0 then
      begin
        doubleClickTimer := FILE_DIALOG_DOUBLE_CLICK_DELAY;
        doubleClickSelectedFileIndex := -2;
      end;

      while elapsed_time(tick) < (1000 div 24) do
        { busy wait };
    end;

    if game_user_wants_to_quit <> 0 then
      rc := 1;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  win_delete(win);

  for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
    art_ptr_unlock(frmHandles[index]);

  message_exit(@messageList);
  text_font(oldFont);

  Result := rc;
end;

// ---------------------------------------------------------------------------
// 0x41D7A4
// ---------------------------------------------------------------------------
function save_file_dialog(title: PAnsiChar; fileList: PPAnsiChar; dest: PAnsiChar;
  fileListLength, x, y, flags: Integer): Integer;
var
  oldFont: Integer;
  isScrollable: Boolean;
  selectedFileIndex: Integer;
  pageOffset: Integer;
  maxPageOffset: Integer;
  frmBuffers: array[0..FILE_DIALOG_FRM_COUNT - 1] of PByte;
  frmHandles: array[0..FILE_DIALOG_FRM_COUNT - 1] of PCacheEntry;
  frmSizes: array[0..FILE_DIALOG_FRM_COUNT - 1] of TSize;
  index: Integer;
  fid: Integer;
  backgroundWidth: Integer;
  backgroundHeight: Integer;
  win: Integer;
  windowBuffer: PByte;
  messageList: TMessageList;
  messageListItem: TMessageListItem;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  done: PAnsiChar;
  cancel: PAnsiChar;
  doneBtn: Integer;
  cancelBtn: Integer;
  scrollUpBtn: Integer;
  scrollDownButton: Integer;
  cursorHeight: Integer;
  cursorWidth: Integer;
  fileNameLength: Integer;
  pch: PAnsiChar;
  fileNameCopy: array[0..31] of AnsiChar;
  fileNameCopyLength: Integer;
  fileNameBufferPtr: PByte;
  blinkingCounter: Integer;
  blink: Boolean;
  doubleClickSelectedFileIndex: Integer;
  doubleClickTimer: Integer;
  rc: Integer;
  tick: LongWord;
  keyCode: Integer;
  scrollDirection: Integer;
  scrollCounter: Integer;
  isScrolling: Boolean;
  mouseX: Integer;
  mouseY: Integer;
  selectedLine: Integer;
  scrollDelay: LongWord;
  scrollTick: LongWord;
  delay: LongWord;
  clr: Integer;
  innerKey: Integer;
  findIdx: Integer;
begin
  oldFont := text_curr();

  isScrollable := False;
  if fileListLength > FILE_DIALOG_LINE_COUNT then
    isScrollable := True;

  selectedFileIndex := 0;
  pageOffset := 0;
  maxPageOffset := fileListLength - (FILE_DIALOG_LINE_COUNT + 1);
  if maxPageOffset < 0 then
  begin
    maxPageOffset := fileListLength - 1;
    if maxPageOffset < 0 then
      maxPageOffset := 0;
  end;

  index := 0;
  while index < FILE_DIALOG_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, flgids2[index], 0, 0, 0);
    frmBuffers[index] := art_lock(fid, @frmHandles[index], @frmSizes[index].Width, @frmSizes[index].Height);
    if frmBuffers[index] = nil then
    begin
      Dec(index);
      while index >= 0 do
      begin
        art_ptr_unlock(frmHandles[index]);
        Dec(index);
      end;
      Result := -1;
      Exit;
    end;
    Inc(index);
  end;

  backgroundWidth := frmSizes[FILE_DIALOG_FRM_BACKGROUND].Width;
  backgroundHeight := frmSizes[FILE_DIALOG_FRM_BACKGROUND].Height;

  // Maintain original position in original resolution, otherwise center it.
  if screenGetWidth() <> 640 then
    x := x + (screenGetWidth() - 640) div 2;
  if screenGetHeight() <> 480 then
    y := y + (screenGetHeight() - 480) div 2;

  win := win_add(x, y, backgroundWidth, backgroundHeight, 256, WINDOW_MODAL or WINDOW_MOVE_ON_TOP);
  if win = -1 then
  begin
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  windowBuffer := win_get_buf(win);
  Move(frmBuffers[FILE_DIALOG_FRM_BACKGROUND]^, windowBuffer^, backgroundWidth * backgroundHeight);

  if not message_init(@messageList) then
  begin
    win_delete(win);
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('DBOX.MSG')]);

  if not message_load(@messageList, @path[0]) then
  begin
    win_delete(win);
    for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
      art_ptr_unlock(frmHandles[index]);
    Result := -1;
    Exit;
  end;

  text_font(103);

  // DONE
  done := getmsg(@messageList, @messageListItem, 100);
  text_to_buf(windowBuffer + backgroundWidth * SAVE_FILE_DIALOG_DONE_LABEL_Y + SAVE_FILE_DIALOG_DONE_LABEL_X,
    done, backgroundWidth, backgroundWidth, colorTable[18979]);

  // CANCEL
  cancel := getmsg(@messageList, @messageListItem, 103);
  text_to_buf(windowBuffer + backgroundWidth * SAVE_FILE_DIALOG_CANCEL_LABEL_Y + SAVE_FILE_DIALOG_CANCEL_LABEL_X,
    cancel, backgroundWidth, backgroundWidth, colorTable[18979]);

  doneBtn := win_register_button(win,
    SAVE_FILE_DIALOG_DONE_BUTTON_X,
    SAVE_FILE_DIALOG_DONE_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Height,
    -1, -1, -1, 500,
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  cancelBtn := win_register_button(win,
    SAVE_FILE_DIALOG_CANCEL_BUTTON_X,
    SAVE_FILE_DIALOG_CANCEL_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED].Height,
    -1, -1, -1, 501,
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_LITTLE_RED_BUTTON_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if cancelBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  scrollUpBtn := win_register_button(win,
    FILE_DIALOG_SCROLL_BUTTON_X,
    FILE_DIALOG_SCROLL_BUTTON_Y,
    frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Height,
    -1, 505, 506, 505,
    frmBuffers[FILE_DIALOG_FRM_SCROLL_UP_ARROW_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if scrollUpBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  scrollDownButton := win_register_button(win,
    FILE_DIALOG_SCROLL_BUTTON_X,
    FILE_DIALOG_SCROLL_BUTTON_Y + frmSizes[FILE_DIALOG_FRM_SCROLL_UP_ARROW_PRESSED].Height,
    frmSizes[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED].Width,
    frmSizes[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED].Height,
    -1, 503, 504, 503,
    frmBuffers[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_NORMAL],
    frmBuffers[FILE_DIALOG_FRM_SCROLL_DOWN_ARROW_PRESSED],
    nil, BUTTON_FLAG_TRANSPARENT);
  if scrollUpBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_register_button(win,
    FILE_DIALOG_FILE_LIST_X,
    FILE_DIALOG_FILE_LIST_Y,
    FILE_DIALOG_FILE_LIST_WIDTH,
    FILE_DIALOG_FILE_LIST_HEIGHT,
    -1, -1, -1, 502,
    nil, nil, nil, 0);

  if title <> nil then
    text_to_buf(windowBuffer + backgroundWidth * FILE_DIALOG_TITLE_Y + FILE_DIALOG_TITLE_X,
      title, backgroundWidth, backgroundWidth, colorTable[18979]);

  text_font(101);

  cursorHeight := text_height();
  cursorWidth := text_width('_') - 4;
  PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);

  fileNameLength := 0;
  pch := dest;
  while (pch^ <> #0) and (pch^ <> '.') do
  begin
    Inc(fileNameLength);
    if fileNameLength >= 12 then
      Break;
    Inc(pch);
  end;
  dest[fileNameLength] := #0;

  StrLCopy(@fileNameCopy[0], dest, 32);

  fileNameCopyLength := StrLen(@fileNameCopy[0]);
  fileNameCopy[fileNameCopyLength + 1] := #0;
  fileNameCopy[fileNameCopyLength] := ' ';

  fileNameBufferPtr := windowBuffer + backgroundWidth * 190 + 57;

  buf_fill(fileNameBufferPtr, text_width(@fileNameCopy[0]), cursorHeight, backgroundWidth, 100);
  text_to_buf(fileNameBufferPtr, @fileNameCopy[0], backgroundWidth, backgroundWidth, colorTable[992]);

  win_draw(win);

  beginTextInput();

  blinkingCounter := 3;
  blink := False;

  doubleClickSelectedFileIndex := -2;
  doubleClickTimer := FILE_DIALOG_DOUBLE_CLICK_DELAY;

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;

    tick := get_time();
    keyCode := get_input();
    scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_NONE;
    scrollCounter := 0;
    isScrolling := False;

    convertMouseWheelToArrowKey(@keyCode);

    if keyCode = 500 then
      rc := 0
    else if keyCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      rc := 0;
    end
    else if (keyCode = 501) or (keyCode = KEY_ESCAPE) then
      rc := 1
    else if ((keyCode = KEY_DELETE) or (keyCode = KEY_BACKSPACE)) and (fileNameCopyLength > 0) then
    begin
      buf_fill(fileNameBufferPtr, text_width(@fileNameCopy[0]), cursorHeight, backgroundWidth, 100);
      fileNameCopy[fileNameCopyLength - 1] := ' ';
      fileNameCopy[fileNameCopyLength] := #0;
      text_to_buf(fileNameBufferPtr, @fileNameCopy[0], backgroundWidth, backgroundWidth, colorTable[992]);
      Dec(fileNameCopyLength);
      win_draw(win);
    end
    else if (keyCode < KEY_FIRST_INPUT_CHARACTER) or (keyCode > KEY_LAST_INPUT_CHARACTER) or (fileNameCopyLength >= 8) then
    begin
      if (keyCode = 502) and (fileListLength <> 0) then
      begin
        mouse_get_position(@mouseX, @mouseY);

        selectedLine := (mouseY - y - FILE_DIALOG_FILE_LIST_Y) div text_height();
        if selectedLine - 1 < 0 then
          selectedLine := 0;

        if isScrollable or (selectedLine < fileListLength) then
        begin
          if selectedLine >= FILE_DIALOG_LINE_COUNT then
            selectedLine := FILE_DIALOG_LINE_COUNT - 1;
        end
        else
          selectedLine := fileListLength - 1;

        selectedFileIndex := selectedLine;
        if selectedFileIndex = doubleClickSelectedFileIndex then
        begin
          gsound_play_sfx_file('ib1p1xx1');
          StrLCopy(dest, PPAnsiChar(PByte(fileList) + (selectedFileIndex + pageOffset) * SizeOf(PAnsiChar))^, 16);

          findIdx := 0;
          while findIdx < 12 do
          begin
            if (dest[findIdx] = '.') or (dest[findIdx] = #0) then
              Break;
            Inc(findIdx);
          end;

          dest[findIdx] := #0;
          rc := 2;
        end
        else
        begin
          doubleClickSelectedFileIndex := selectedFileIndex;
          buf_fill(fileNameBufferPtr, text_width(@fileNameCopy[0]), cursorHeight, backgroundWidth, 100);
          StrLCopy(@fileNameCopy[0], PPAnsiChar(PByte(fileList) + (selectedFileIndex + pageOffset) * SizeOf(PAnsiChar))^, 16);

          findIdx := 0;
          while findIdx < 12 do
          begin
            if (fileNameCopy[findIdx] = '.') or (fileNameCopy[findIdx] = #0) then
              Break;
            Inc(findIdx);
          end;

          fileNameCopy[findIdx] := #0;
          fileNameCopyLength := StrLen(@fileNameCopy[0]);
          fileNameCopy[fileNameCopyLength] := ' ';
          fileNameCopy[fileNameCopyLength + 1] := #0;

          text_to_buf(fileNameBufferPtr, @fileNameCopy[0], backgroundWidth, backgroundWidth, colorTable[992]);
          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
        end;
      end
      else if keyCode = 506 then
        scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_UP
      else if keyCode = 504 then
        scrollDirection := FILE_DIALOG_SCROLL_DIRECTION_DOWN
      else
      begin
        case keyCode of
          KEY_ARROW_UP:
          begin
            Dec(pageOffset);
            if pageOffset < 0 then
            begin
              Dec(selectedFileIndex);
              if selectedFileIndex < 0 then
                selectedFileIndex := 0;
              pageOffset := 0;
            end;
            PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
            doubleClickSelectedFileIndex := -2;
          end;
          KEY_ARROW_DOWN:
          begin
            if isScrollable then
            begin
              Inc(pageOffset);
              if pageOffset >= maxPageOffset then
              begin
                Inc(selectedFileIndex);
                if selectedFileIndex >= FILE_DIALOG_LINE_COUNT then
                  selectedFileIndex := FILE_DIALOG_LINE_COUNT - 1;
                pageOffset := maxPageOffset;
              end;
            end
            else
            begin
              Inc(selectedFileIndex);
              if selectedFileIndex > maxPageOffset then
                selectedFileIndex := maxPageOffset;
            end;
            PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
            doubleClickSelectedFileIndex := -2;
          end;
          KEY_HOME:
          begin
            selectedFileIndex := 0;
            pageOffset := 0;
            PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
            doubleClickSelectedFileIndex := -2;
          end;
          KEY_END:
          begin
            if isScrollable then
            begin
              selectedFileIndex := 11;
              pageOffset := maxPageOffset;
            end
            else
            begin
              selectedFileIndex := maxPageOffset;
              pageOffset := 0;
            end;
            PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
            doubleClickSelectedFileIndex := -2;
          end;
        end;
      end;
    end
    else if isdoschar(keyCode) then
    begin
      buf_fill(fileNameBufferPtr, text_width(@fileNameCopy[0]), cursorHeight, backgroundWidth, 100);

      fileNameCopy[fileNameCopyLength] := AnsiChar(keyCode and $FF);
      fileNameCopy[fileNameCopyLength + 1] := ' ';
      fileNameCopy[fileNameCopyLength + 2] := #0;
      text_to_buf(fileNameBufferPtr, @fileNameCopy[0], backgroundWidth, backgroundWidth, colorTable[992]);
      Inc(fileNameCopyLength);

      win_draw(win);
    end;

    if scrollDirection <> FILE_DIALOG_SCROLL_DIRECTION_NONE then
    begin
      scrollDelay := 4;
      doubleClickSelectedFileIndex := -2;
      while True do
      begin
        scrollTick := get_time();
        scrollCounter := scrollCounter + 1;
        if ((not isScrolling) and (scrollCounter = 1)) or (isScrolling and (scrollCounter > 14)) then
        begin
          isScrolling := True;

          if scrollCounter > 14 then
          begin
            scrollDelay := scrollDelay + 1;
            if scrollDelay > 24 then
              scrollDelay := 24;
          end;

          if scrollDirection = FILE_DIALOG_SCROLL_DIRECTION_UP then
          begin
            Dec(pageOffset);
            if pageOffset < 0 then
            begin
              Dec(selectedFileIndex);
              if selectedFileIndex < 0 then
                selectedFileIndex := 0;
              pageOffset := 0;
            end;
          end
          else
          begin
            if isScrollable then
            begin
              Inc(pageOffset);
              if pageOffset > maxPageOffset then
              begin
                Inc(selectedFileIndex);
                if selectedFileIndex >= FILE_DIALOG_LINE_COUNT then
                  selectedFileIndex := FILE_DIALOG_LINE_COUNT - 1;
                pageOffset := maxPageOffset;
              end;
            end
            else
            begin
              Inc(selectedFileIndex);
              if selectedFileIndex > maxPageOffset then
                selectedFileIndex := maxPageOffset;
            end;
          end;

          PrntFlist(windowBuffer, fileList, pageOffset, fileListLength, selectedFileIndex, backgroundWidth);
          win_draw(win);
        end;

        // Blinking cursor
        Dec(blinkingCounter);
        if blinkingCounter = 0 then
        begin
          blinkingCounter := 3;
          if blink then
            clr := 100
          else
            clr := colorTable[992];
          blink := not blink;
          buf_fill(fileNameBufferPtr + text_width(@fileNameCopy[0]) - cursorWidth,
            cursorWidth, cursorHeight - 2, backgroundWidth, clr);
        end;

        // FIXME: Missing windowRefresh makes blinking useless.

        if scrollCounter > 14 then
          delay := 1000 div scrollDelay
        else
          delay := 1000 div 24;
        while elapsed_time(scrollTick) < delay do
          { busy wait };

        if game_user_wants_to_quit <> 0 then
        begin
          rc := 1;
          Break;
        end;

        innerKey := get_input();
        if (innerKey = 505) or (innerKey = 503) then
          Break;

        renderPresent();
      end;
    end
    else
    begin
      Dec(blinkingCounter);
      if blinkingCounter = 0 then
      begin
        blinkingCounter := 3;
        if blink then
          clr := 100
        else
          clr := colorTable[992];
        blink := not blink;
        buf_fill(fileNameBufferPtr + text_width(@fileNameCopy[0]) - cursorWidth,
          cursorWidth, cursorHeight - 2, backgroundWidth, clr);
      end;

      win_draw(win);

      Dec(doubleClickTimer);
      if doubleClickTimer = 0 then
      begin
        doubleClickTimer := FILE_DIALOG_DOUBLE_CLICK_DELAY;
        doubleClickSelectedFileIndex := -2;
      end;

      while elapsed_time(tick) < (1000 div 24) do
        { busy wait };
    end;

    if game_user_wants_to_quit <> 0 then
      rc := 1;

    renderPresent();
    sharedFpsLimiter.Throttle;
  end;

  endTextInput();

  if rc = 0 then
  begin
    if fileNameCopyLength <> 0 then
    begin
      fileNameCopy[fileNameCopyLength] := #0;
      StrCopy(dest, @fileNameCopy[0]);
    end
    else
      rc := 1;
  end
  else
  begin
    if rc = 2 then
      rc := 0;
  end;

  win_delete(win);

  for index := 0 to FILE_DIALOG_FRM_COUNT - 1 do
    art_ptr_unlock(frmHandles[index]);

  message_exit(@messageList);
  text_font(oldFont);

  Result := rc;
end;

// ---------------------------------------------------------------------------
// 0x41E8D8
// ---------------------------------------------------------------------------
procedure PrntFlist(buffer: PByte; fileList: PPAnsiChar; pageOffset, fileListLength, selectedIndex, pitch: Integer);
var
  lineHeight: Integer;
  yy: Integer;
  clr: Integer;
  index: Integer;
  localFileListLength: Integer;
begin
  lineHeight := text_height();
  yy := FILE_DIALOG_FILE_LIST_Y;
  buf_fill(buffer + yy * pitch + FILE_DIALOG_FILE_LIST_X,
    FILE_DIALOG_FILE_LIST_WIDTH, FILE_DIALOG_FILE_LIST_HEIGHT, pitch, 100);

  if fileListLength <> 0 then
  begin
    localFileListLength := fileListLength;
    if localFileListLength - pageOffset > FILE_DIALOG_LINE_COUNT then
      localFileListLength := FILE_DIALOG_LINE_COUNT;

    for index := 0 to localFileListLength - 1 do
    begin
      if index = selectedIndex then
        clr := colorTable[32747]
      else
        clr := colorTable[992];
      text_to_buf(buffer + pitch * yy + FILE_DIALOG_FILE_LIST_X,
        PPAnsiChar(PByte(fileList) + (pageOffset + index) * SizeOf(PAnsiChar))^,
        FILE_DIALOG_FILE_LIST_WIDTH, pitch, clr);
      yy := yy + lineHeight;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Initialization of module-level data arrays
// ---------------------------------------------------------------------------
initialization
  // 0x4FEC0C
  dbox[0] := 218;  // MEDIALOG.FRM - Medium generic dialog box
  dbox[1] := 217;  // LGDIALOG.FRM - Large generic dialog box

  // 0x4FEC14
  ytable[0] := 23;
  ytable[1] := 27;

  // 0x4FEC1C
  xtable[0] := 29;
  xtable[1] := 29;

  // 0x4FEC24
  doneY[0] := 81;
  doneY[1] := 98;

  // 0x4FEC2C
  doneX[0] := 51;
  doneX[1] := 37;

  // 0x4FEC34
  dblines[0] := 5;
  dblines[1] := 6;

  // 0x4FEC44
  flgids[0] := 224;  // loadbox.frm
  flgids[1] := 8;    // lilredup.frm
  flgids[2] := 9;    // lilreddn.frm
  flgids[3] := 181;  // dnarwoff.frm
  flgids[4] := 182;  // dnarwon.frm
  flgids[5] := 199;  // uparwoff.frm
  flgids[6] := 200;  // uparwon.frm

  // 0x4FEC60
  flgids2[0] := 225;  // savebox.frm
  flgids2[1] := 8;    // lilredup.frm
  flgids2[2] := 9;    // lilreddn.frm
  flgids2[3] := 181;  // dnarwoff.frm
  flgids2[4] := 182;  // dnarwon.frm
  flgids2[5] := 199;  // uparwoff.frm
  flgids2[6] := 200;  // uparwon.frm

end.
