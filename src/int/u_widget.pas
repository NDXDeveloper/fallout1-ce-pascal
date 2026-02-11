{$MODE OBJFPC}{$H+}
// Converted from: src/int/widget.cc/h
// Widget system: text regions, text input regions, update regions, status bar.
unit u_widget;

interface

type
  TUpdateRegionShowFunc = procedure(value: Pointer); cdecl;
  TUpdateRegionDrawFunc = procedure(value: Pointer); cdecl;
  TTextInputRegionDeleteFunc = procedure(text: PAnsiChar; userData: Pointer); cdecl;

function win_add_text_input_region(textRegionId: Integer; text: PAnsiChar; a3: Integer; a4: Integer): Integer;
procedure windowSelectTextInputRegion(textInputRegionId: Integer);
function win_delete_all_text_input_regions(win: Integer): Integer;
function win_delete_text_input_region(textInputRegionId: Integer): Integer;
function win_set_text_input_delete_func(textInputRegionId: Integer; deleteFunc: TTextInputRegionDeleteFunc; userData: Pointer): Integer;
function win_add_text_region(win: Integer; x: Integer; y: Integer; width: Integer; font: Integer; textAlignment: Integer; textFlags: Integer; backgroundColor: Integer): Integer;
function win_print_text_region(textRegionId: Integer; str: PAnsiChar): Integer;
function win_print_substr_region(textRegionId: Integer; str: PAnsiChar; stringLength: Integer): Integer;
function win_update_text_region(textRegionId: Integer): Integer;
function win_delete_text_region(textRegionId: Integer): Integer;
function win_delete_all_update_regions(win: Integer): Integer;
function win_text_region_style(textRegionId: Integer; font: Integer; textAlignment: Integer; textFlags: Integer; backgroundColor: Integer): Integer;
procedure win_delete_widgets(win: Integer);
function widgetDoInput: Integer;
function win_center_str(win: Integer; str: PAnsiChar; y: Integer; a4: Integer): Integer;
function draw_widgets: Integer;
function update_widgets: Integer;
function win_register_update(win: Integer; x: Integer; y: Integer; showFunc: TUpdateRegionShowFunc; drawFunc: TUpdateRegionDrawFunc; value: Pointer; atype: LongWord; a8: Integer): Integer;
function win_delete_update_region(updateRegionIndex: Integer): Integer;
procedure win_do_updateregions;
procedure initWidgets;
procedure widgetsClose;
procedure real_win_set_status_bar(a1: Integer; a2: Integer; a3: Integer);
procedure real_win_update_status_bar(a1: Single; a2: Single);
procedure real_win_increment_status_bar(a1: Single);
procedure real_win_add_status_bar(win: Integer; a2: Integer; a3: PAnsiChar; a4: PAnsiChar; x: Integer; y: Integer);
procedure real_win_get_status_info(a1: Integer; a2: PInteger; a3: PInteger; a4: PInteger);
procedure real_win_modify_status_info(a1: Integer; a2: Integer; a3: Integer; a4: Integer);

implementation

uses
  SysUtils,
  u_memdbg,
  u_debug,
  u_text,
  u_rect,
  u_gnw,
  u_gnw_types,
  u_grbuf,
  u_button,
  u_datafile,
  u_int_sound,
  u_int_window;

const
  WIDGET_UPDATE_REGIONS_CAPACITY = 32;

type
  PStatusBar = ^TStatusBar;
  TStatusBar = record
    field_0: PByte;
    field_4: PByte;
    win: Integer;
    x: Integer;
    y: Integer;
    width: Integer;
    height: Integer;
    field_1C: Integer;
    field_20: Integer;
    field_24: Integer;
  end;

  PUpdateRegion = ^TUpdateRegion;
  TUpdateRegion = record
    win: Integer;
    x: Integer;
    y: Integer;
    atype: LongWord;
    field_10: Integer;
    value: Pointer;
    showFunc: TUpdateRegionShowFunc;
    drawFunc: TUpdateRegionDrawFunc;
  end;

  PTextInputRegion = ^TTextInputRegion;
  TTextInputRegion = record
    textRegionId: Integer;
    isUsed: Integer;
    field_8: Integer;
    field_C: Integer;
    field_10: Integer;
    text: PAnsiChar;
    field_18: Integer;
    field_1C: Integer;
    btn: Integer;
    deleteFunc: TTextInputRegionDeleteFunc;
    field_28: Integer;
    deleteFuncUserData: Pointer;
  end;

  PTextRegion = ^TTextRegion;
  TTextRegion = record
    win: Integer;
    isUsed: Integer;
    x: Integer;
    y: Integer;
    width: Integer;
    height: Integer;
    textAlignment: Integer;
    textFlags: Integer;
    backgroundColor: Integer;
    font: Integer;
  end;

// Forward declarations of static helpers
procedure deleteChar(str: PAnsiChar; pos: Integer; len: Integer); forward;
procedure insertChar(str: PAnsiChar; ch: AnsiChar; pos: Integer; len: Integer); forward;
procedure textInputRegionDispatch(btn: Integer; inputEvent: Integer); cdecl; forward;
procedure showRegion(updateRegion: PUpdateRegion); forward;
procedure freeStatusBar; forward;
procedure drawStatusBar; forward;

var
  // 0x66B6C0
  updateRegions: array[0..WIDGET_UPDATE_REGIONS_CAPACITY - 1] of PUpdateRegion;

  // 0x66B740
  statusBar: TStatusBar;

  // 0x66B770
  textInputRegions: PTextInputRegion;

  // 0x66B774
  numTextInputRegions: Integer;

  // 0x66B778
  textRegions: PTextRegion;

  // 0x66B77C
  statusBarActive: Integer;

  // 0x66B780
  numTextRegions: Integer;

// 0x4A10E0
procedure deleteChar(str: PAnsiChar; pos: Integer; len: Integer);
begin
  if len > pos then
    Move((str + pos + 1)^, (str + pos)^, len - pos);
end;

// 0x4A1108
procedure insertChar(str: PAnsiChar; ch: AnsiChar; pos: Integer; len: Integer);
begin
  if len >= pos then
  begin
    if len > pos then
      Move((str + pos)^, (str + pos + 1)^, len - pos);
    (str + pos)^ := ch;
  end;
end;

// 0x4A12C4
procedure textInputRegionDispatch(btn: Integer; inputEvent: Integer); cdecl;
begin
  // TODO: Incomplete.
end;

// 0x4A1D14
function win_add_text_input_region(textRegionId: Integer; text: PAnsiChar; a3: Integer; a4: Integer): Integer;
var
  textInputRegionIndex: Integer;
  oldFont: Integer;
  btn_: Integer;
begin
  if (textRegionId <= 0) or (textRegionId > numTextRegions) then
    Exit(0);

  if (textRegions + (textRegionId - 1))^.isUsed = 0 then
    Exit(0);

  textInputRegionIndex := 0;
  while textInputRegionIndex < numTextInputRegions do
  begin
    if (textInputRegions + textInputRegionIndex)^.isUsed = 0 then
      Break;
    Inc(textInputRegionIndex);
  end;

  if textInputRegionIndex = numTextInputRegions then
  begin
    if textInputRegions = nil then
      textInputRegions := PTextInputRegion(mymalloc(SizeOf(TTextInputRegion), PAnsiChar('widget.pas'), 0))
    else
      textInputRegions := PTextInputRegion(myrealloc(textInputRegions, SizeOf(TTextInputRegion) * (numTextInputRegions + 1), PAnsiChar('widget.pas'), 0));
    Inc(numTextInputRegions);
  end;

  (textInputRegions + textInputRegionIndex)^.field_28 := a4;
  (textInputRegions + textInputRegionIndex)^.textRegionId := textRegionId;
  (textInputRegions + textInputRegionIndex)^.isUsed := 1;
  (textInputRegions + textInputRegionIndex)^.field_8 := a3;
  (textInputRegions + textInputRegionIndex)^.field_C := 0;
  (textInputRegions + textInputRegionIndex)^.text := text;
  (textInputRegions + textInputRegionIndex)^.field_10 := StrLen(text);
  (textInputRegions + textInputRegionIndex)^.deleteFunc := nil;
  (textInputRegions + textInputRegionIndex)^.deleteFuncUserData := nil;

  oldFont := text_curr();
  text_font((textRegions + (textRegionId - 1))^.font);

  btn_ := win_register_button(
    (textRegions + (textRegionId - 1))^.win,
    (textRegions + (textRegionId - 1))^.x,
    (textRegions + (textRegionId - 1))^.y,
    (textRegions + (textRegionId - 1))^.width,
    text_height(),
    -1,
    -1,
    -1,
    (textInputRegionIndex + 1) or $400,
    nil,
    nil,
    nil,
    0);
  win_register_button_func(btn_, nil, nil, nil, TButtonCallback(@textInputRegionDispatch));

  // NOTE: Uninline.
  win_print_text_region(textRegionId, text);

  (textInputRegions + textInputRegionIndex)^.btn := btn_;

  text_font(oldFont);

  Result := textInputRegionIndex + 1;
end;

// 0x4A1EE8
procedure windowSelectTextInputRegion(textInputRegionId: Integer);
begin
  textInputRegionDispatch(
    (textInputRegions + (textInputRegionId - 1))^.btn,
    textInputRegionId or $400);
end;

// 0x4A1F10
function win_delete_all_text_input_regions(win: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to numTextInputRegions - 1 do
  begin
    if (textRegions + ((textInputRegions + index)^.textRegionId - 1))^.win = win then
      win_delete_text_input_region(index + 1);
  end;

  Result := 1;
end;

// 0x4A1F5C
function win_delete_text_input_region(textInputRegionId: Integer): Integer;
var
  textInputRegionIndex: Integer;
begin
  textInputRegionIndex := textInputRegionId - 1;
  if (textInputRegionIndex >= 0) and (textInputRegionIndex < numTextInputRegions) then
  begin
    if (textInputRegions + textInputRegionIndex)^.isUsed <> 0 then
    begin
      if (textInputRegions + textInputRegionIndex)^.deleteFunc <> nil then
        (textInputRegions + textInputRegionIndex)^.deleteFunc(
          (textInputRegions + textInputRegionIndex)^.text,
          (textInputRegions + textInputRegionIndex)^.deleteFuncUserData);

      // NOTE: Uninline.
      win_delete_text_region((textInputRegions + textInputRegionIndex)^.textRegionId);

      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A2008
function win_set_text_input_delete_func(textInputRegionId: Integer; deleteFunc: TTextInputRegionDeleteFunc; userData: Pointer): Integer;
var
  textInputRegionIndex: Integer;
begin
  textInputRegionIndex := textInputRegionId - 1;
  if (textInputRegionIndex >= 0) and (textInputRegionIndex < numTextInputRegions) then
  begin
    if (textInputRegions + textInputRegionIndex)^.isUsed <> 0 then
    begin
      (textInputRegions + textInputRegionIndex)^.deleteFunc := deleteFunc;
      (textInputRegions + textInputRegionIndex)^.deleteFuncUserData := userData;
      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A2048
function win_add_text_region(win: Integer; x: Integer; y: Integer; width: Integer; font: Integer; textAlignment: Integer; textFlags: Integer; backgroundColor: Integer): Integer;
var
  textRegionIndex: Integer;
  oldFont: Integer;
  height: Integer;
begin
  textRegionIndex := 0;
  while textRegionIndex < numTextRegions do
  begin
    if (textRegions + textRegionIndex)^.isUsed = 0 then
      Break;
    Inc(textRegionIndex);
  end;

  if textRegionIndex = numTextRegions then
  begin
    if textRegions = nil then
      textRegions := PTextRegion(mymalloc(SizeOf(TTextRegion), PAnsiChar('widget.pas'), 0))
    else
      textRegions := PTextRegion(myrealloc(textRegions, SizeOf(TTextRegion) * (numTextRegions + 1), PAnsiChar('widget.pas'), 0));
    Inc(numTextRegions);
  end;

  oldFont := text_curr();
  text_font(font);

  height := text_height();

  text_font(oldFont);

  if (textFlags and FONT_SHADOW) <> 0 then
  begin
    Inc(width);
    Inc(height);
  end;

  (textRegions + textRegionIndex)^.isUsed := 1;
  (textRegions + textRegionIndex)^.win := win;
  (textRegions + textRegionIndex)^.x := x;
  (textRegions + textRegionIndex)^.y := y;
  (textRegions + textRegionIndex)^.width := width;
  (textRegions + textRegionIndex)^.height := height;
  (textRegions + textRegionIndex)^.font := font;
  (textRegions + textRegionIndex)^.textAlignment := textAlignment;
  (textRegions + textRegionIndex)^.textFlags := textFlags;
  (textRegions + textRegionIndex)^.backgroundColor := backgroundColor;

  Result := textRegionIndex + 1;
end;

// 0x4A2174
function win_print_text_region(textRegionId: Integer; str: PAnsiChar): Integer;
var
  textRegionIndex: Integer;
  oldFont: Integer;
begin
  textRegionIndex := textRegionId - 1;
  if (textRegionIndex >= 0) and (textRegionIndex <= numTextRegions) then
  begin
    if (textRegions + textRegionIndex)^.isUsed <> 0 then
    begin
      oldFont := text_curr();
      text_font((textRegions + textRegionIndex)^.font);

      win_fill((textRegions + textRegionIndex)^.win,
        (textRegions + textRegionIndex)^.x,
        (textRegions + textRegionIndex)^.y,
        (textRegions + textRegionIndex)^.width,
        (textRegions + textRegionIndex)^.height,
        (textRegions + textRegionIndex)^.backgroundColor);

      windowPrintBuf((textRegions + textRegionIndex)^.win,
        str,
        StrLen(str),
        (textRegions + textRegionIndex)^.width,
        win_height((textRegions + textRegionIndex)^.win),
        (textRegions + textRegionIndex)^.x,
        (textRegions + textRegionIndex)^.y,
        (textRegions + textRegionIndex)^.textFlags or $2000000,
        (textRegions + textRegionIndex)^.textAlignment);

      text_font(oldFont);

      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A2254
function win_print_substr_region(textRegionId: Integer; str: PAnsiChar; stringLength: Integer): Integer;
var
  textRegionIndex: Integer;
  oldFont: Integer;
begin
  textRegionIndex := textRegionId - 1;
  if (textRegionIndex >= 0) and (textRegionIndex <= numTextRegions) then
  begin
    if (textRegions + textRegionIndex)^.isUsed <> 0 then
    begin
      oldFont := text_curr();
      text_font((textRegions + textRegionIndex)^.font);

      win_fill((textRegions + textRegionIndex)^.win,
        (textRegions + textRegionIndex)^.x,
        (textRegions + textRegionIndex)^.y,
        (textRegions + textRegionIndex)^.width,
        (textRegions + textRegionIndex)^.height,
        (textRegions + textRegionIndex)^.backgroundColor);

      windowPrintBuf((textRegions + textRegionIndex)^.win,
        str,
        stringLength,
        (textRegions + textRegionIndex)^.width,
        win_height((textRegions + textRegionIndex)^.win),
        (textRegions + textRegionIndex)^.x,
        (textRegions + textRegionIndex)^.y,
        (textRegions + textRegionIndex)^.textFlags or $2000000,
        (textRegions + textRegionIndex)^.textAlignment);

      text_font(oldFont);

      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A2324
function win_update_text_region(textRegionId: Integer): Integer;
var
  textRegionIndex: Integer;
  rect: TRect;
begin
  textRegionIndex := textRegionId - 1;
  if (textRegionIndex >= 0) and (textRegionIndex <= numTextRegions) then
  begin
    if (textRegions + textRegionIndex)^.isUsed <> 0 then
    begin
      rect.ulx := (textRegions + textRegionIndex)^.x;
      rect.uly := (textRegions + textRegionIndex)^.y;
      rect.lrx := (textRegions + textRegionIndex)^.x + (textRegions + textRegionIndex)^.width;
      rect.lry := (textRegions + textRegionIndex)^.y + text_height();
      win_draw_rect((textRegions + textRegionIndex)^.win, @rect);
      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A23A4
function win_delete_text_region(textRegionId: Integer): Integer;
var
  textRegionIndex: Integer;
begin
  textRegionIndex := textRegionId - 1;
  if (textRegionIndex >= 0) and (textRegionIndex <= numTextRegions) then
  begin
    if (textRegions + textRegionIndex)^.isUsed <> 0 then
    begin
      (textRegions + textRegionIndex)^.isUsed := 0;
      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A23E0
function win_delete_all_update_regions(win: Integer): Integer;
var
  index: Integer;
begin
  for index := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
  begin
    if updateRegions[index] <> nil then
    begin
      if win = updateRegions[index]^.win then
      begin
        myfree(updateRegions[index], PAnsiChar('widget.pas'), 0);
        updateRegions[index] := nil;
      end;
    end;
  end;

  Result := 1;
end;

// 0x4A2428
function win_text_region_style(textRegionId: Integer; font: Integer; textAlignment: Integer; textFlags: Integer; backgroundColor: Integer): Integer;
var
  textRegionIndex: Integer;
  oldFont: Integer;
  height: Integer;
begin
  textRegionIndex := textRegionId - 1;
  if (textRegionIndex >= 0) and (textRegionIndex <= numTextRegions) then
  begin
    if (textRegions + textRegionIndex)^.isUsed <> 0 then
    begin
      (textRegions + textRegionIndex)^.font := font;
      (textRegions + textRegionIndex)^.textAlignment := textAlignment;

      oldFont := text_curr();
      text_font(font);

      height := text_height();

      text_font(oldFont);

      if ((textRegions + textRegionIndex)^.textFlags and FONT_SHADOW) = 0 then
      begin
        if (textFlags and FONT_SHADOW) <> 0 then
        begin
          Inc(height);
          Inc((textRegions + textRegionIndex)^.width);
        end;
      end;

      (textRegions + textRegionIndex)^.height := height;
      (textRegions + textRegionIndex)^.textFlags := textFlags;
      (textRegions + textRegionIndex)^.backgroundColor := backgroundColor;

      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A24D8
procedure win_delete_widgets(win: Integer);
var
  index: Integer;
begin
  win_delete_all_text_input_regions(win);

  for index := 0 to numTextRegions - 1 do
  begin
    if (textRegions + index)^.win = win then
    begin
      // NOTE: Uninline.
      win_delete_text_region(index + 1);
    end;
  end;

  win_delete_all_update_regions(win);
end;

// 0x4A2544
function widgetDoInput: Integer;
var
  index: Integer;
begin
  for index := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
  begin
    if updateRegions[index] <> nil then
      showRegion(updateRegions[index]);
  end;

  Result := 0;
end;

// 0x4A256C
function win_center_str(win: Integer; str: PAnsiChar; y: Integer; a4: Integer): Integer;
var
  windowWidth: Integer;
  stringWidth: Integer;
begin
  windowWidth := win_width(win);
  stringWidth := text_width(str);
  win_print(win, str, 0, (windowWidth - stringWidth) div 2, y, a4);

  Result := 1;
end;

// 0x4A25A4
procedure showRegion(updateRegion: PUpdateRegion);
var
  value: Single;
  stringBuffer: array[0..79] of AnsiChar;
  s: AnsiString;
begin
  case updateRegion^.atype and $FF of
    1:
      value := Single(PInteger(updateRegion^.value)^);
    2:
      value := PSingle(updateRegion^.value)^;
    4:
      value := PSingle(updateRegion^.value)^ / 65636.0;
    8:
      begin
        win_print(updateRegion^.win,
          PAnsiChar(updateRegion^.value),
          0,
          updateRegion^.x,
          updateRegion^.y,
          updateRegion^.field_10);
        Exit;
      end;
    $10:
      begin
        // fall through to output section with uninitialized value
      end;
  else
    begin
      debug_printf(PAnsiChar('Invalid input type given to win_register_update'#10));
      Exit;
    end;
  end;

  case updateRegion^.atype and $FF00 of
    $100:
      begin
        s := Format(' %d ', [Trunc(value)]);
        if Length(s) > 79 then SetLength(s, 79);
        Move(s[1], stringBuffer[0], Length(s));
        stringBuffer[Length(s)] := #0;
      end;
    $200:
      begin
        s := Format(' %f ', [value]);
        if Length(s) > 79 then SetLength(s, 79);
        Move(s[1], stringBuffer[0], Length(s));
        stringBuffer[Length(s)] := #0;
      end;
    $400:
      begin
        s := Format(' %6.2f%% ', [value * 100.0]);
        if Length(s) > 79 then SetLength(s, 79);
        Move(s[1], stringBuffer[0], Length(s));
        stringBuffer[Length(s)] := #0;
      end;
    $800:
      begin
        if updateRegion^.showFunc <> nil then
          updateRegion^.showFunc(updateRegion^.value);
        Exit;
      end;
  else
    begin
      debug_printf(PAnsiChar('Invalid output type given to win_register_update'#10));
      Exit;
    end;
  end;

  win_print(updateRegion^.win,
    @stringBuffer[0],
    0,
    updateRegion^.x,
    updateRegion^.y,
    updateRegion^.field_10 or $1000000);
end;

// 0x4A2724
function draw_widgets: Integer;
var
  index: Integer;
begin
  for index := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
  begin
    if updateRegions[index] <> nil then
    begin
      if (updateRegions[index]^.atype and $FF00) = $800 then
        updateRegions[index]^.drawFunc(updateRegions[index]^.value);
    end;
  end;

  Result := 1;
end;

// 0x4A2760
function update_widgets: Integer;
var
  index: Integer;
begin
  for index := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
  begin
    if updateRegions[index] <> nil then
      showRegion(updateRegions[index]);
  end;

  Result := 1;
end;

// 0x4A2788
function win_register_update(win: Integer; x: Integer; y: Integer; showFunc: TUpdateRegionShowFunc; drawFunc: TUpdateRegionDrawFunc; value: Pointer; atype: LongWord; a8: Integer): Integer;
var
  updateRegionIndex: Integer;
begin
  updateRegionIndex := 0;
  while updateRegionIndex < WIDGET_UPDATE_REGIONS_CAPACITY do
  begin
    if updateRegions[updateRegionIndex] = nil then
      Break;
    Inc(updateRegionIndex);
  end;

  if updateRegionIndex = WIDGET_UPDATE_REGIONS_CAPACITY then
    Exit(-1);

  updateRegions[updateRegionIndex] := PUpdateRegion(mymalloc(SizeOf(TUpdateRegion), PAnsiChar('widget.pas'), 0));
  updateRegions[updateRegionIndex]^.win := win;
  updateRegions[updateRegionIndex]^.x := x;
  updateRegions[updateRegionIndex]^.y := y;
  updateRegions[updateRegionIndex]^.atype := atype;
  updateRegions[updateRegionIndex]^.field_10 := a8;
  updateRegions[updateRegionIndex]^.value := value;
  updateRegions[updateRegionIndex]^.showFunc := showFunc;
  updateRegions[updateRegionIndex]^.drawFunc := drawFunc;

  Result := updateRegionIndex;
end;

// 0x4A2848
function win_delete_update_region(updateRegionIndex: Integer): Integer;
begin
  if (updateRegionIndex >= 0) and (updateRegionIndex < WIDGET_UPDATE_REGIONS_CAPACITY) then
  begin
    if updateRegions[updateRegionIndex] <> nil then
    begin
      myfree(updateRegions[updateRegionIndex], PAnsiChar('widget.pas'), 0);
      updateRegions[updateRegionIndex] := nil;
      Exit(1);
    end;
  end;

  Result := 0;
end;

// 0x4A2890
procedure win_do_updateregions;
var
  index: Integer;
begin
  for index := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
  begin
    if updateRegions[index] <> nil then
      showRegion(updateRegions[index]);
  end;
end;

// 0x4A28B4
procedure freeStatusBar;
begin
  if statusBar.field_0 <> nil then
  begin
    myfree(statusBar.field_0, PAnsiChar('widget.pas'), 0);
    statusBar.field_0 := nil;
  end;

  if statusBar.field_4 <> nil then
  begin
    myfree(statusBar.field_4, PAnsiChar('widget.pas'), 0);
    statusBar.field_4 := nil;
  end;

  FillChar(statusBar, SizeOf(statusBar), 0);

  statusBarActive := 0;
end;

// 0x4A2920
procedure initWidgets;
var
  updateRegionIndex: Integer;
begin
  for updateRegionIndex := 0 to WIDGET_UPDATE_REGIONS_CAPACITY - 1 do
    updateRegions[updateRegionIndex] := nil;

  textRegions := nil;
  numTextRegions := 0;

  textInputRegions := nil;
  numTextInputRegions := 0;

  freeStatusBar;
end;

// 0x4A2958
procedure widgetsClose;
begin
  if textRegions <> nil then
    myfree(textRegions, PAnsiChar('widget.pas'), 0);
  textRegions := nil;
  numTextRegions := 0;

  if textInputRegions <> nil then
    myfree(textInputRegions, PAnsiChar('widget.pas'), 0);
  textInputRegions := nil;
  numTextInputRegions := 0;

  freeStatusBar;
end;

// 0x4A29B8
procedure drawStatusBar;
var
  rect: TRect;
  dest: PByte;
begin
  if statusBarActive <> 0 then
  begin
    dest := win_get_buf(statusBar.win) + statusBar.y * win_width(statusBar.win) + statusBar.x;

    buf_to_buf(statusBar.field_0,
      statusBar.width,
      statusBar.height,
      statusBar.width,
      dest,
      win_width(statusBar.win));

    buf_to_buf(statusBar.field_4,
      statusBar.field_1C,
      statusBar.height,
      statusBar.width,
      dest,
      win_width(statusBar.win));

    rect.ulx := statusBar.x;
    rect.uly := statusBar.y;
    rect.lrx := statusBar.x + statusBar.width;
    rect.lry := statusBar.y + statusBar.height;
    win_draw_rect(statusBar.win, @rect);
  end;
end;

// 0x4A2A98
procedure real_win_set_status_bar(a1: Integer; a2: Integer; a3: Integer);
begin
  if statusBarActive <> 0 then
  begin
    statusBar.field_1C := a2;
    statusBar.field_20 := a2;
    statusBar.field_24 := a3;
    drawStatusBar;
  end;
end;

// 0x4A2ABC
procedure real_win_update_status_bar(a1: Single; a2: Single);
begin
  if statusBarActive <> 0 then
  begin
    statusBar.field_1C := Trunc(a1 * statusBar.width);
    statusBar.field_20 := Trunc(a1 * statusBar.width);
    statusBar.field_24 := Trunc(a2 * statusBar.width);
    drawStatusBar;
    soundUpdate;
  end;
end;

// 0x4A2B0C
procedure real_win_increment_status_bar(a1: Single);
begin
  if statusBarActive <> 0 then
  begin
    statusBar.field_1C := statusBar.field_20 + Trunc(a1 * (statusBar.field_24 - statusBar.field_20));
    drawStatusBar;
    soundUpdate;
  end;
end;

// 0x4A2B58
procedure real_win_add_status_bar(win: Integer; a2: Integer; a3: PAnsiChar; a4: PAnsiChar; x: Integer; y: Integer);
var
  imageWidth1: Integer;
  imageHeight1: Integer;
  imageWidth2: Integer;
  imageHeight2: Integer;
begin
  freeStatusBar;

  statusBar.field_0 := loadRawDataFile(a4, @imageWidth1, @imageHeight1);
  statusBar.field_4 := loadRawDataFile(a3, @imageWidth2, @imageHeight2);

  if (imageWidth2 = imageWidth1) and (imageHeight2 = imageHeight1) then
  begin
    statusBar.x := x;
    statusBar.y := y;
    statusBar.width := imageWidth1;
    statusBar.height := imageHeight1;
    statusBar.win := win;
    real_win_set_status_bar(a2, 0, 0);
    statusBarActive := 1;
  end
  else
  begin
    freeStatusBar;
    debug_printf(PAnsiChar('status bar dimensions not the same'#10));
  end;
end;

// 0x4A2C04
procedure real_win_get_status_info(a1: Integer; a2: PInteger; a3: PInteger; a4: PInteger);
begin
  if statusBarActive <> 0 then
  begin
    a2^ := statusBar.field_1C;
    a3^ := statusBar.field_20;
    a4^ := statusBar.field_24;
  end
  else
  begin
    a2^ := -1;
    a3^ := -1;
    a4^ := -1;
  end;
end;

// 0x4A2C38
procedure real_win_modify_status_info(a1: Integer; a2: Integer; a3: Integer; a4: Integer);
begin
  if statusBarActive <> 0 then
  begin
    statusBar.field_1C := a2;
    statusBar.field_20 := a3;
    statusBar.field_24 := a4;
  end;
end;

end.
