{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/text.h + text.cc
// Font management system with pluggable font managers.
unit u_text;

interface

const
  FONT_SHADOW    = $10000;
  FONT_UNDERLINE = $20000;
  FONT_MONO      = $40000;

type
  TTextFontFunc = procedure(font: Integer); cdecl;
  TTextToBufFunc = procedure(buf: PByte; str: PAnsiChar; swidth, fullw, color: Integer); cdecl;
  TTextHeightFunc = function: Integer; cdecl;
  TTextWidthFunc = function(str: PAnsiChar): Integer; cdecl;
  TTextCharWidthFunc = function(c: AnsiChar): Integer; cdecl;
  TTextMonoWidthFunc = function(str: PAnsiChar): Integer; cdecl;
  TTextSpacingFunc = function: Integer; cdecl;
  TTextSizeFunc = function(str: PAnsiChar): Integer; cdecl;
  TTextMaxFunc = function: Integer; cdecl;

  PFontMgr = ^TFontMgr;
  TFontMgr = record
    LowFontNum: Integer;
    HighFontNum: Integer;
    TextFont: TTextFontFunc;
    TextToBuf: TTextToBufFunc;
    TextHeight: TTextHeightFunc;
    TextWidth: TTextWidthFunc;
    TextCharWidth: TTextCharWidthFunc;
    TextMonoWidth: TTextMonoWidthFunc;
    TextSpacing: TTextSpacingFunc;
    TextSize: TTextSizeFunc;
    TextMax: TTextMaxFunc;
  end;

  PFontInfo = ^TFontInfo;
  TFontInfo = record
    Width: Integer;
    Offset: Integer;
  end;

  PFont = ^TFont;
  TFont = record
    Num: Integer;
    Height: Integer;
    Spacing: Integer;
    Info: PFontInfo;
    Data: PByte;
  end;

var
  text_to_buf: TTextToBufFunc;
  text_height: TTextHeightFunc;
  text_width: TTextWidthFunc;
  text_char_width: TTextCharWidthFunc;
  text_mono_width: TTextMonoWidthFunc;
  text_spacing: TTextSpacingFunc;
  text_size: TTextSizeFunc;
  text_max: TTextMaxFunc;

function GNW_text_init: Integer;
procedure GNW_text_exit;
function text_add_manager(mgr: PFontMgr): Integer;
function text_remove_manager(font_num: Integer): Integer;
function text_curr: Integer;
procedure text_font(font_num: Integer);

implementation

uses
  SysUtils, u_db, u_memory, u_color, u_platform_compat;

const
  TEXT_FONT_MAX = 10;
  MAX_FONT_MANAGERS = 10;

var
  font_managers: array[0..MAX_FONT_MANAGERS - 1] of TFontMgr;
  total_managers: Integer = 0;
  curr_font_num: Integer = -1;
  gFonts: array[0..TEXT_FONT_MAX - 1] of TFont;
  curr_font: PFont = nil;

procedure GNW_text_font_cb(font_num: Integer); cdecl; forward;
procedure GNW_text_to_buf_cb(buf: PByte; str: PAnsiChar; swidth, fullw, color: Integer); cdecl; forward;
function GNW_text_height_cb: Integer; cdecl; forward;
function GNW_text_width_cb(str: PAnsiChar): Integer; cdecl; forward;
function GNW_text_char_width_cb(c: AnsiChar): Integer; cdecl; forward;
function GNW_text_mono_width_cb(str: PAnsiChar): Integer; cdecl; forward;
function GNW_text_spacing_cb: Integer; cdecl; forward;
function GNW_text_size_cb(str: PAnsiChar): Integer; cdecl; forward;
function GNW_text_max_cb: Integer; cdecl; forward;

function load_font(n: Integer): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  f: PFont;
  glyphsPtr, dataPtr: Integer;
  dataSize: Integer;
begin
  f := @gFonts[n];
  f^.Data := nil;
  f^.Info := nil;

  StrLFmt(@path[0], SizeOf(path) - 1, 'font%d.fon', [n]);

  stream := db_fopen(@path[0], 'rb');
  if stream = nil then
    Exit(-1);

  if db_fread(@f^.Num, 4, 1, stream) <> 1 then begin db_fclose(stream); Exit(-1); end;
  if db_fread(@f^.Height, 4, 1, stream) <> 1 then begin db_fclose(stream); Exit(-1); end;
  if db_fread(@f^.Spacing, 4, 1, stream) <> 1 then begin db_fclose(stream); Exit(-1); end;
  if db_fread(@glyphsPtr, 4, 1, stream) <> 1 then begin db_fclose(stream); Exit(-1); end;
  if db_fread(@dataPtr, 4, 1, stream) <> 1 then begin db_fclose(stream); Exit(-1); end;

  f^.Info := PFontInfo(mem_malloc(f^.Num * SizeOf(TFontInfo)));
  if f^.Info = nil then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  if db_fread(f^.Info, SizeOf(TFontInfo), f^.Num, stream) <> f^.Num then
  begin
    mem_free(f^.Info);
    f^.Info := nil;
    db_fclose(stream);
    Exit(-1);
  end;

  dataSize := f^.Height * ((PFontInfo(PByte(f^.Info) + SizeOf(TFontInfo) * (f^.Num - 1))^.Width + 7) shr 3)
            + PFontInfo(PByte(f^.Info) + SizeOf(TFontInfo) * (f^.Num - 1))^.Offset;

  f^.Data := PByte(mem_malloc(dataSize));
  if f^.Data = nil then
  begin
    mem_free(f^.Info);
    f^.Info := nil;
    db_fclose(stream);
    Exit(-1);
  end;

  if db_fread(f^.Data, 1, dataSize, stream) <> dataSize then
  begin
    mem_free(f^.Data);
    f^.Data := nil;
    mem_free(f^.Info);
    f^.Info := nil;
    db_fclose(stream);
    Exit(-1);
  end;

  db_fclose(stream);
  Result := 0;
end;

function GNW_text_init: Integer;
const
  GNW_font_mgr: TFontMgr = (
    LowFontNum: 0;
    HighFontNum: 9;
    TextFont: @GNW_text_font_cb;
    TextToBuf: @GNW_text_to_buf_cb;
    TextHeight: @GNW_text_height_cb;
    TextWidth: @GNW_text_width_cb;
    TextCharWidth: @GNW_text_char_width_cb;
    TextMonoWidth: @GNW_text_mono_width_cb;
    TextSpacing: @GNW_text_spacing_cb;
    TextSize: @GNW_text_size_cb;
    TextMax: @GNW_text_max_cb;
  );
var
  i, first_font: Integer;
begin
  total_managers := 0;
  curr_font_num := -1;
  text_to_buf := nil;
  text_height := nil;
  text_width := nil;
  text_char_width := nil;
  text_mono_width := nil;
  text_spacing := nil;
  text_size := nil;
  text_max := nil;

  first_font := -1;

  for i := 0 to TEXT_FONT_MAX - 1 do
  begin
    if load_font(i) = -1 then
      gFonts[i].Num := 0
    else if first_font = -1 then
      first_font := i;
  end;

  if first_font = -1 then
    Exit(-1);

  if text_add_manager(@GNW_font_mgr) = -1 then
    Exit(-1);

  text_font(first_font);

  Result := 0;
end;

procedure GNW_text_exit;
var
  i: Integer;
begin
  for i := 0 to TEXT_FONT_MAX - 1 do
  begin
    if gFonts[i].Num <> 0 then
    begin
      if gFonts[i].Info <> nil then
        mem_free(gFonts[i].Info);
      if gFonts[i].Data <> nil then
        mem_free(gFonts[i].Data);
      gFonts[i].Num := 0;
      gFonts[i].Info := nil;
      gFonts[i].Data := nil;
    end;
  end;

  total_managers := 0;
  curr_font_num := -1;
end;

function text_add_manager(mgr: PFontMgr): Integer;
begin
  if mgr = nil then
    Exit(-1);

  if total_managers >= MAX_FONT_MANAGERS then
    Exit(-1);

  font_managers[total_managers] := mgr^;
  Inc(total_managers);

  Result := 0;
end;

function text_remove_manager(font_num: Integer): Integer;
var
  i, j: Integer;
begin
  for i := 0 to total_managers - 1 do
  begin
    if (font_num >= font_managers[i].LowFontNum) and
       (font_num <= font_managers[i].HighFontNum) then
    begin
      for j := i to total_managers - 2 do
        font_managers[j] := font_managers[j + 1];
      Dec(total_managers);
      Exit(0);
    end;
  end;
  Result := -1;
end;

function text_curr: Integer;
begin
  Result := curr_font_num;
end;

procedure text_font(font_num: Integer);
var
  i: Integer;
begin
  for i := 0 to total_managers - 1 do
  begin
    if (font_num >= font_managers[i].LowFontNum) and
       (font_num <= font_managers[i].HighFontNum) then
    begin
      text_to_buf := font_managers[i].TextToBuf;
      text_height := font_managers[i].TextHeight;
      text_width := font_managers[i].TextWidth;
      text_char_width := font_managers[i].TextCharWidth;
      text_mono_width := font_managers[i].TextMonoWidth;
      text_spacing := font_managers[i].TextSpacing;
      text_size := font_managers[i].TextSize;
      text_max := font_managers[i].TextMax;

      curr_font_num := font_num;

      if Assigned(font_managers[i].TextFont) then
        font_managers[i].TextFont(font_num);

      Break;
    end;
  end;
end;

// Built-in GNW font callbacks

procedure GNW_text_font_cb(font_num: Integer); cdecl;
begin
  if font_num >= TEXT_FONT_MAX then
    Exit;
  if gFonts[font_num].Num = 0 then
    Exit;
  curr_font := @gFonts[font_num];
end;

function GNW_text_height_cb: Integer; cdecl;
begin
  Result := curr_font^.Height;
end;

function GNW_text_width_cb(str: PAnsiChar): Integer; cdecl;
var
  len: Integer;
  fi: PFontInfo;
begin
  len := 0;
  while str^ <> #0 do
  begin
    if Byte(str^) < curr_font^.Num then
    begin
      fi := PFontInfo(PByte(curr_font^.Info) + SizeOf(TFontInfo) * Byte(str^));
      len := len + curr_font^.Spacing + fi^.Width;
    end;
    Inc(str);
  end;
  Result := len;
end;

function GNW_text_char_width_cb(c: AnsiChar): Integer; cdecl;
begin
  Result := PFontInfo(PByte(curr_font^.Info) + SizeOf(TFontInfo) * Byte(c))^.Width;
end;

function GNW_text_mono_width_cb(str: PAnsiChar): Integer; cdecl;
begin
  Result := text_max() * Integer(StrLen(str));
end;

function GNW_text_spacing_cb: Integer; cdecl;
begin
  Result := curr_font^.Spacing;
end;

function GNW_text_size_cb(str: PAnsiChar): Integer; cdecl;
begin
  Result := text_width(str) * text_height();
end;

function GNW_text_max_cb: Integer; cdecl;
var
  i, len: Integer;
  fi: PFontInfo;
begin
  len := 0;
  for i := 0 to curr_font^.Num - 1 do
  begin
    fi := PFontInfo(PByte(curr_font^.Info) + SizeOf(TFontInfo) * i);
    if len < fi^.Width then
      len := fi^.Width;
  end;
  Result := len + curr_font^.Spacing;
end;

procedure GNW_text_to_buf_cb(buf: PByte; str: PAnsiChar; swidth, fullw, color: Integer); cdecl;
var
  monospacedCharacterWidth: Integer;
  ptr, endPtr, glyphData, underlinePtr: PByte;
  ch: Byte;
  glyph: PFontInfo;
  bits, x, y, length_: Integer;
begin
  if (color and FONT_SHADOW) <> 0 then
  begin
    color := color and (not FONT_SHADOW);
    GNW_text_to_buf_cb(buf + fullw + 1, str, swidth, fullw, colorTable[0]);
  end;

  monospacedCharacterWidth := 0;
  if (color and FONT_MONO) <> 0 then
    monospacedCharacterWidth := text_max();

  ptr := buf;
  while str^ <> #0 do
  begin
    ch := Byte(str^);
    Inc(str);

    if ch < curr_font^.Num then
    begin
      glyph := PFontInfo(PByte(curr_font^.Info) + SizeOf(TFontInfo) * ch);

      if (color and FONT_MONO) <> 0 then
      begin
        endPtr := ptr + monospacedCharacterWidth;
        ptr := ptr + (monospacedCharacterWidth - curr_font^.Spacing - glyph^.Width) div 2;
      end
      else
        endPtr := ptr + glyph^.Width + curr_font^.Spacing;

      if PtrUInt(endPtr) - PtrUInt(buf) > PtrUInt(swidth) then
        Break;

      glyphData := curr_font^.Data + glyph^.Offset;

      for y := 0 to curr_font^.Height - 1 do
      begin
        bits := $80;
        for x := 0 to glyph^.Width - 1 do
        begin
          if bits = 0 then
          begin
            bits := $80;
            Inc(glyphData);
          end;

          if (glyphData^ and bits) <> 0 then
            ptr^ := Byte(color and $FF);

          bits := bits shr 1;
          Inc(ptr);
        end;
        Inc(glyphData);
        ptr := ptr + fullw - glyph^.Width;
      end;

      ptr := endPtr;
    end;
  end;

  if (color and FONT_UNDERLINE) <> 0 then
  begin
    length_ := PtrUInt(ptr) - PtrUInt(buf);
    underlinePtr := buf + fullw * (curr_font^.Height - 1);
    for x := 0 to length_ - 1 do
    begin
      underlinePtr^ := Byte(color and $FF);
      Inc(underlinePtr);
    end;
  end;
end;

initialization
  FillByte(gFonts, SizeOf(gFonts), 0);

end.
