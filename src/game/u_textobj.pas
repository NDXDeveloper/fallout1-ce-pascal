unit u_textobj;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/textobj.h + textobj.cc
// Floating text objects attached to map objects.

interface

uses
  u_object_types, u_rect;

function text_object_init(windowBuffer: PByte; width, height: Integer): Integer;
function text_object_reset: Integer;
procedure text_object_exit;
procedure text_object_disable;
procedure text_object_enable;
function text_object_is_enabled: Integer;
procedure text_object_set_base_delay(value: Double);
function text_object_get_base_delay: LongWord;
procedure text_object_set_line_delay(value: Double);
function text_object_get_line_delay: LongWord;
function text_object_create(obj: PObject; str: PAnsiChar; font, color, a5: Integer; rect: PRect): Integer;
procedure text_object_render(rect: PRect);
function text_object_count: Integer;
procedure text_object_remove(obj: PObject);

implementation

uses
  u_gconfig, u_config, u_wordwrap, u_debug, u_grbuf, u_input, u_memory, u_text, u_tile,
  u_map;

const
  // The maximum number of text objects that can exist at the same time.
  TEXT_OBJECTS_MAX_COUNT = 20;

  TEXT_OBJECT_MARKED_FOR_REMOVAL = $01;
  TEXT_OBJECT_UNBOUNDED          = $02;

type
  PTextObject = ^TTextObject;
  TTextObject = record
    flags: Integer;
    owner: PObject;
    time: LongWord;
    linesCount: Integer;
    sx: Integer;
    sy: Integer;
    tile: Integer;
    x: Integer;
    y: Integer;
    width: Integer;
    height: Integer;
    data: PByte;
  end;

// map_elevation imported from u_map

// Forward declarations
procedure text_object_bk; forward;
procedure text_object_get_offset(textObject: PTextObject); forward;

// Module-level (static) variables
var
  // 0x508324
  text_object_index: Integer = 0;

  // 0x508328
  text_object_base_delay: LongWord = 3500;

  // 0x50832C
  text_object_line_delay: LongWord = 1399;

  // 0x665210
  text_object_list: array[0..TEXT_OBJECTS_MAX_COUNT - 1] of PTextObject;

  // 0x665260
  display_width: Integer;

  // 0x665264
  display_height: Integer;

  // 0x665268
  display_buffer: PByte;

  // 0x66526C
  text_object_enabled: Boolean;

  // 0x665270
  text_object_initialized: Boolean;

// 0x49CD80
function text_object_init(windowBuffer: PByte; width, height: Integer): Integer;
var
  textBaseDelay: Double;
  textLineDelay: Double;
begin
  if text_object_initialized then
  begin
    Result := -1;
    Exit;
  end;

  display_buffer := windowBuffer;
  display_width := width;
  display_height := height;
  text_object_index := 0;

  add_bk_process(TBackgroundProcess(@text_object_bk));

  if not config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_BASE_DELAY_KEY, @textBaseDelay) then
    textBaseDelay := 3.5;

  if not config_get_double(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_TEXT_LINE_DELAY_KEY, @textLineDelay) then
    textLineDelay := 1.399993896484375;

  text_object_base_delay := Trunc(textBaseDelay * 1000.0);
  text_object_line_delay := Trunc(textLineDelay * 1000.0);

  text_object_enabled := True;
  text_object_initialized := True;

  Result := 0;
end;

// 0x49CE64
function text_object_reset: Integer;
var
  index: Integer;
begin
  if not text_object_initialized then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to text_object_index - 1 do
  begin
    mem_free(text_object_list[index]^.data);
    mem_free(text_object_list[index]);
  end;

  text_object_index := 0;
  add_bk_process(TBackgroundProcess(@text_object_bk));

  Result := 0;
end;

// 0x49CEC8
procedure text_object_exit;
begin
  if text_object_initialized then
  begin
    text_object_reset;
    remove_bk_process(TBackgroundProcess(@text_object_bk));
    text_object_initialized := False;
  end;
end;

// 0x49CEEC
procedure text_object_disable;
begin
  text_object_enabled := False;
end;

// 0x49CEF8
procedure text_object_enable;
begin
  text_object_enabled := True;
end;

// NOTE: Unused.
// 0x49CF04
function text_object_is_enabled: Integer;
begin
  Result := Ord(text_object_enabled);
end;

// 0x49CF0C
procedure text_object_set_base_delay(value: Double);
begin
  if value < 1.0 then
    value := 1.0;

  text_object_base_delay := Trunc(value * 1000.0);
end;

// 0x49CF50
function text_object_get_base_delay: LongWord;
begin
  Result := text_object_base_delay div 1000;
end;

// 0x49CF64
procedure text_object_set_line_delay(value: Double);
begin
  if value < 0.0 then
    value := 0.0;

  text_object_line_delay := Trunc(value * 1000.0);
end;

// 0x49CFA0
function text_object_get_line_delay: LongWord;
begin
  Result := text_object_line_delay div 1000;
end;

// 0x49CFB4
function text_object_create(obj: PObject; str: PAnsiChar; font, color, a5: Integer; rect: PRect): Integer;
var
  textObject: PTextObject;
  oldFont: Integer;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  count: SmallInt;
  index: Integer;
  ending: PAnsiChar;
  beginning: PAnsiChar;
  c: AnsiChar;
  w: Integer;
  size: Integer;
  dest: PByte;
  skip: Integer;
begin
  if not text_object_initialized then
  begin
    Result := -1;
    Exit;
  end;

  if text_object_index >= TEXT_OBJECTS_MAX_COUNT - 1 then
  begin
    Result := -1;
    Exit;
  end;

  if str = nil then
  begin
    Result := -1;
    Exit;
  end;

  if str^ = #0 then
  begin
    Result := -1;
    Exit;
  end;

  textObject := PTextObject(mem_malloc(SizeOf(TTextObject)));
  if textObject = nil then
  begin
    Result := -1;
    Exit;
  end;

  FillChar(textObject^, SizeOf(TTextObject), 0);

  oldFont := text_curr();
  text_font(font);

  if word_wrap(str, 200, @beginnings[0], @count) <> 0 then
  begin
    text_font(oldFont);
    Result := -1;
    Exit;
  end;

  textObject^.linesCount := count - 1;
  if textObject^.linesCount < 1 then
    debug_printf('**Error in text_object_create()'#10);

  textObject^.width := 0;

  for index := 0 to textObject^.linesCount - 1 do
  begin
    ending := str + beginnings[index + 1];
    beginning := str + beginnings[index];
    if (ending - 1)^ = ' ' then
      Dec(ending);

    c := ending^;
    ending^ := #0;

    // NOTE: Calls text_width twice, probably result of using min/max macro
    w := text_width(beginning);
    if w >= textObject^.width then
      textObject^.width := w;

    ending^ := c;
  end;

  textObject^.height := (text_height() + 1) * textObject^.linesCount;

  if a5 <> -1 then
  begin
    textObject^.width := textObject^.width + 2;
    textObject^.height := textObject^.height + 2;
  end;

  size := textObject^.width * textObject^.height;
  textObject^.data := PByte(mem_malloc(size));
  if textObject^.data = nil then
  begin
    text_font(oldFont);
    Result := -1;
    Exit;
  end;

  FillChar(textObject^.data^, size, 0);

  dest := textObject^.data;
  skip := textObject^.width * (text_height() + 1);

  if a5 <> -1 then
    dest := dest + textObject^.width;

  for index := 0 to textObject^.linesCount - 1 do
  begin
    beginning := str + beginnings[index];
    ending := str + beginnings[index + 1];
    if (ending - 1)^ = ' ' then
      Dec(ending);

    c := ending^;
    ending^ := #0;

    w := text_width(beginning);
    text_to_buf(dest + (textObject^.width - w) div 2, beginning, textObject^.width, textObject^.width, color);

    ending^ := c;

    dest := dest + skip;
  end;

  if a5 <> -1 then
    buf_outline(textObject^.data, textObject^.width, textObject^.height, textObject^.width, a5);

  if obj <> nil then
    textObject^.tile := obj^.Tile
  else
  begin
    textObject^.flags := textObject^.flags or TEXT_OBJECT_UNBOUNDED;
    textObject^.tile := tile_center_tile;
  end;

  text_object_get_offset(textObject);

  if rect <> nil then
  begin
    rect^.ulx := textObject^.x;
    rect^.uly := textObject^.y;
    rect^.lrx := textObject^.x + textObject^.width - 1;
    rect^.lry := textObject^.y + textObject^.height - 1;
  end;

  text_object_remove(obj);

  textObject^.owner := obj;
  textObject^.time := get_bk_time();

  text_object_list[text_object_index] := textObject;
  Inc(text_object_index);

  text_font(oldFont);

  Result := 0;
end;

// 0x49D330
procedure text_object_render(rect: PRect);
var
  index: Integer;
  textObject: PTextObject;
  textObjectRect: TRect;
begin
  if not text_object_initialized then
    Exit;

  for index := 0 to text_object_index - 1 do
  begin
    textObject := text_object_list[index];
    tile_coord(textObject^.tile, @textObject^.x, @textObject^.y, map_elevation);
    textObject^.x := textObject^.x + textObject^.sx;
    textObject^.y := textObject^.y + textObject^.sy;

    textObjectRect.ulx := textObject^.x;
    textObjectRect.uly := textObject^.y;
    textObjectRect.lrx := textObject^.width + textObject^.x - 1;
    textObjectRect.lry := textObject^.height + textObject^.y - 1;
    if rect_inside_bound(@textObjectRect, rect, @textObjectRect) = 0 then
    begin
      trans_buf_to_buf(
        textObject^.data + textObject^.width * (textObjectRect.uly - textObject^.y) + (textObjectRect.ulx - textObject^.x),
        textObjectRect.lrx - textObjectRect.ulx + 1,
        textObjectRect.lry - textObjectRect.uly + 1,
        textObject^.width,
        display_buffer + display_width * textObjectRect.uly + textObjectRect.ulx,
        display_width);
    end;
  end;
end;

// 0x49D438
function text_object_count: Integer;
begin
  Result := text_object_index;
end;

// 0x49D440
procedure text_object_bk;
var
  textObjectsRemoved: Boolean;
  dirtyRect: TRect;
  index: Integer;
  textObject: PTextObject;
  delay: LongWord;
  textObjectRect: TRect;
begin
  if not text_object_enabled then
    Exit;

  textObjectsRemoved := False;

  index := 0;
  while index < text_object_index do
  begin
    textObject := text_object_list[index];

    delay := text_object_line_delay * LongWord(textObject^.linesCount) + text_object_base_delay;
    if ((textObject^.flags and TEXT_OBJECT_MARKED_FOR_REMOVAL) <> 0) or (elapsed_tocks(get_bk_time(), textObject^.time) > delay) then
    begin
      tile_coord(textObject^.tile, @textObject^.x, @textObject^.y, map_elevation);
      textObject^.x := textObject^.x + textObject^.sx;
      textObject^.y := textObject^.y + textObject^.sy;

      textObjectRect.ulx := textObject^.x;
      textObjectRect.uly := textObject^.y;
      textObjectRect.lrx := textObject^.width + textObject^.x - 1;
      textObjectRect.lry := textObject^.height + textObject^.y - 1;

      if textObjectsRemoved then
        rect_min_bound(@dirtyRect, @textObjectRect, @dirtyRect)
      else
      begin
        rectCopy(@dirtyRect, @textObjectRect);
        textObjectsRemoved := True;
      end;

      mem_free(textObject^.data);
      mem_free(textObject);

      // memmove: shift list entries down
      if index < text_object_index - 1 then
        Move(text_object_list[index + 1], text_object_list[index],
          SizeOf(PTextObject) * (text_object_index - index - 1));

      Dec(text_object_index);
      Dec(index);
    end;

    Inc(index);
  end;

  if textObjectsRemoved then
    tile_refresh_rect(@dirtyRect, map_elevation);
end;

// Finds best position for placing text object.
// 0x49D59C
procedure text_object_get_offset(textObject: PTextObject);
var
  tileScreenX: Integer;
  tileScreenY: Integer;
begin
  tile_coord(textObject^.tile, @tileScreenX, @tileScreenY, map_elevation);
  textObject^.x := tileScreenX + 16 - textObject^.width div 2;
  textObject^.y := tileScreenY;

  if (textObject^.flags and TEXT_OBJECT_UNBOUNDED) = 0 then
    textObject^.y := textObject^.y - textObject^.height - 60;

  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := textObject^.x - textObject^.width div 2;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := textObject^.x + textObject^.width;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := tileScreenX - 16 - textObject^.width;
  textObject^.y := tileScreenY - 16 - textObject^.height;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := textObject^.x + textObject^.width + 64;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := tileScreenX + 16 - textObject^.width div 2;
  textObject^.y := tileScreenY;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := textObject^.x - textObject^.width div 2;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  textObject^.x := textObject^.x + textObject^.width;
  if (textObject^.x >= 0) and (textObject^.x + textObject^.width - 1 < display_width)
    and (textObject^.y >= 0) and (textObject^.y + textObject^.height - 1 < display_height) then
  begin
    textObject^.sx := textObject^.x - tileScreenX;
    textObject^.sy := textObject^.y - tileScreenY;
    Exit;
  end;

  // Fallback: use default position
  textObject^.x := tileScreenX + 16 - textObject^.width div 2;
  textObject^.y := tileScreenY - (textObject^.height + 60);
  textObject^.sx := textObject^.x - tileScreenX;
  textObject^.sy := textObject^.y - tileScreenY;
end;

// Marks text objects attached to `obj` for removal.
// 0x49D848
procedure text_object_remove(obj: PObject);
var
  index: Integer;
begin
  for index := 0 to text_object_index - 1 do
  begin
    if text_object_list[index]^.owner = obj then
      text_object_list[index]^.flags := text_object_list[index]^.flags or TEXT_OBJECT_MARKED_FOR_REMOVAL;
  end;
end;

end.
