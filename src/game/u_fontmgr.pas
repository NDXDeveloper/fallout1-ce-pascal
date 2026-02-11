{$MODE OBJFPC}{$H+}
// Converted from: src/game/fontmgr.h + fontmgr.cc
// Interface font manager: loads .AAF font files and provides text rendering.
unit u_fontmgr;

interface

function FMInit: Integer; cdecl;
procedure FMExit; cdecl;
procedure FMtext_font(font: Integer); cdecl;
function FMtext_height: Integer; cdecl;
function FMtext_width(str: PAnsiChar): Integer; cdecl;
function FMtext_char_width(c: AnsiChar): Integer; cdecl;
function FMtext_mono_width(str: PAnsiChar): Integer; cdecl;
function FMtext_spacing: Integer; cdecl;
function FMtext_size(str: PAnsiChar): Integer; cdecl;
function FMtext_max: Integer; cdecl;
function FMtext_curr: Integer; cdecl;
procedure FMtext_to_buf(buf: PByte; str: PAnsiChar; length_, pitch, color: Integer); cdecl;

implementation

uses
  SysUtils,
  u_memdbg, u_color, u_db, u_text;

const
  INTERFACE_FONT_MAX = 16;

type
  PInterfaceFontGlyph = ^TInterfaceFontGlyph;
  TInterfaceFontGlyph = record
    width: SmallInt;
    height: SmallInt;
    offset: Integer;
  end;

  PInterfaceFontDescriptor = ^TInterfaceFontDescriptor;
  TInterfaceFontDescriptor = record
    maxHeight: SmallInt;
    letterSpacing: SmallInt;
    wordSpacing: SmallInt;
    lineSpacing: SmallInt;
    field_8: SmallInt;
    field_A: SmallInt;
    glyphs: array[0..255] of TInterfaceFontGlyph;
    data: PByte;
  end;

var
  gFMInit: Boolean = False;
  gNumFonts: Integer = 0;
  gFontCache: array[0..INTERFACE_FONT_MAX - 1] of TInterfaceFontDescriptor;
  gCurrentFontNum: Integer;
  gCurrentFont: PInterfaceFontDescriptor;

procedure swapUInt16(value: PWord);
var
  swapped: Word;
begin
  swapped := value^;
  swapped := Word((swapped shr 8) or (swapped shl 8));
  value^ := swapped;
end;

procedure swapUInt32(value: PLongWord);
var
  swapped: LongWord;
  high_, low_: Word;
begin
  swapped := value^;
  high_ := Word(swapped shr 16);
  swapUInt16(@high_);
  low_ := Word(swapped and $FFFF);
  swapUInt16(@low_);
  value^ := (LongWord(low_) shl 16) or high_;
end;

procedure swapInt16(value: PSmallInt);
begin
  swapUInt16(PWord(value));
end;

procedure swapInt32(value: PInteger);
begin
  swapUInt32(PLongWord(value));
end;

function FMLoadFont(font_index: Integer): Integer;
var
  fontDescriptor: PInterfaceFontDescriptor;
  path: array[0..55] of AnsiChar;
  stream: PDB_FILE;
  fileSize: Integer;
  sig: Integer;
  glyphDataSize: Integer;
  idx: Integer;
  glyph: PInterfaceFontGlyph;
begin
  fontDescriptor := @gFontCache[font_index];

  StrLFmt(@path[0], SizeOf(path) - 1, 'font%d.aaf', [font_index]);

  stream := db_fopen(@path[0], 'rb');
  if stream = nil then
    Exit(-1);

  fileSize := db_filelength(stream);

  if db_fread(@sig, 4, 1, stream) <> 1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  swapInt32(@sig);
  if sig <> $41414646 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  if db_fread(@fontDescriptor^.maxHeight, 2, 1, stream) <> 1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;
  swapInt16(@fontDescriptor^.maxHeight);

  if db_fread(@fontDescriptor^.letterSpacing, 2, 1, stream) <> 1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;
  swapInt16(@fontDescriptor^.letterSpacing);

  if db_fread(@fontDescriptor^.wordSpacing, 2, 1, stream) <> 1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;
  swapInt16(@fontDescriptor^.wordSpacing);

  if db_fread(@fontDescriptor^.lineSpacing, 2, 1, stream) <> 1 then
  begin
    db_fclose(stream);
    Exit(-1);
  end;
  swapInt16(@fontDescriptor^.lineSpacing);

  for idx := 0 to 255 do
  begin
    glyph := @fontDescriptor^.glyphs[idx];

    if db_fread(@glyph^.width, 2, 1, stream) <> 1 then
    begin
      db_fclose(stream);
      Exit(-1);
    end;
    swapInt16(@glyph^.width);

    if db_fread(@glyph^.height, 2, 1, stream) <> 1 then
    begin
      db_fclose(stream);
      Exit(-1);
    end;
    swapInt16(@glyph^.height);

    if db_fread(@glyph^.offset, 4, 1, stream) <> 1 then
    begin
      db_fclose(stream);
      Exit(-1);
    end;
    swapInt32(@glyph^.offset);
  end;

  glyphDataSize := fileSize - 2060;

  fontDescriptor^.data := PByte(mymalloc(glyphDataSize, 'FONTMGR.C', 0));
  if fontDescriptor^.data = nil then
  begin
    db_fclose(stream);
    Exit(-1);
  end;

  if db_fread(fontDescriptor^.data, glyphDataSize, 1, stream) <> 1 then
  begin
    myfree(fontDescriptor^.data, 'FONTMGR.C', 0);
    db_fclose(stream);
    Exit(-1);
  end;

  db_fclose(stream);
  Result := 0;
end;

function FMInit: Integer; cdecl;
var
  currentFont: Integer;
  font: Integer;
begin
  currentFont := -1;

  for font := 0 to INTERFACE_FONT_MAX - 1 do
  begin
    if FMLoadFont(font) = -1 then
    begin
      gFontCache[font].maxHeight := 0;
      gFontCache[font].data := nil;
    end
    else
    begin
      Inc(gNumFonts);
      if currentFont = -1 then
        currentFont := font;
    end;
  end;

  if currentFont = -1 then
    Exit(-1);

  gFMInit := True;
  FMtext_font(currentFont + 100);

  Result := 0;
end;

procedure FMExit; cdecl;
var
  font: Integer;
begin
  for font := 0 to INTERFACE_FONT_MAX - 1 do
  begin
    if gFontCache[font].data <> nil then
    begin
      myfree(gFontCache[font].data, 'FONTMGR.C', 0);
      gFontCache[font].data := nil;
    end;
  end;
end;

procedure FMtext_font(font: Integer); cdecl;
begin
  if not gFMInit then
    Exit;

  font := font - 100;

  if (font >= 0) and (font < INTERFACE_FONT_MAX) and (gFontCache[font].data <> nil) then
  begin
    gCurrentFontNum := font;
    gCurrentFont := @gFontCache[font];
  end;
end;

function FMtext_height: Integer; cdecl;
begin
  if not gFMInit then
    Exit(0);

  Result := gCurrentFont^.lineSpacing + gCurrentFont^.maxHeight;
end;

function FMtext_width(str: PAnsiChar): Integer; cdecl;
var
  stringWidth: Integer;
  p: PAnsiChar;
  ch: Byte;
  characterWidth: Integer;
begin
  if not gFMInit then
    Exit(0);

  stringWidth := 0;
  p := str;
  while p^ <> #0 do
  begin
    ch := Byte(p^);
    if ch = 32 then
      characterWidth := gCurrentFont^.wordSpacing
    else
      characterWidth := gCurrentFont^.glyphs[ch].width;
    stringWidth := stringWidth + characterWidth + gCurrentFont^.letterSpacing;
    Inc(p);
  end;

  Result := stringWidth;
end;

function FMtext_char_width(c: AnsiChar): Integer; cdecl;
begin
  if not gFMInit then
    Exit(0);

  if c = ' ' then
    Result := gCurrentFont^.wordSpacing
  else
    Result := gCurrentFont^.glyphs[Byte(c)].width;
end;

function FMtext_mono_width(str: PAnsiChar): Integer; cdecl;
begin
  if not gFMInit then
    Exit(0);

  Result := FMtext_max * Integer(StrLen(str));
end;

function FMtext_spacing: Integer; cdecl;
begin
  if not gFMInit then
    Exit(0);

  Result := gCurrentFont^.letterSpacing;
end;

function FMtext_size(str: PAnsiChar): Integer; cdecl;
begin
  if not gFMInit then
    Exit(0);

  Result := FMtext_width(str) * FMtext_height;
end;

function FMtext_max: Integer; cdecl;
var
  v1: Integer;
begin
  if not gFMInit then
    Exit(0);

  if gCurrentFont^.wordSpacing <= gCurrentFont^.field_8 then
    v1 := gCurrentFont^.lineSpacing
  else
    v1 := gCurrentFont^.letterSpacing;

  Result := v1 + gCurrentFont^.maxHeight;
end;

function FMtext_curr: Integer; cdecl;
begin
  Result := gCurrentFontNum;
end;

procedure FMtext_to_buf(buf: PByte; str: PAnsiChar; length_, pitch, color: Integer); cdecl;
var
  palette: PByte;
  monospacedCharacterWidth: Integer;
  ptr: PByte;
  endPtr: PByte;
  p: PAnsiChar;
  ch: Byte;
  characterWidth: Integer;
  glyph: PInterfaceFontGlyph;
  glyphDataPtr: PByte;
  x, y: Integer;
  b: Byte;
  underlinePtr: PByte;
  underlineLen: Integer;
  idx: Integer;
begin
  if not gFMInit then
    Exit;

  if (color and FONT_SHADOW) <> 0 then
  begin
    color := color and (not FONT_SHADOW);
    FMtext_to_buf(buf + pitch + 1, str, length_, pitch, (color and (not $FF)) or colorTable[0]);
  end;

  palette := getColorBlendTable(color and $FF);
  monospacedCharacterWidth := 0;
  if (color and FONT_MONO) <> 0 then
    monospacedCharacterWidth := FMtext_max;

  ptr := buf;
  p := str;
  while p^ <> #0 do
  begin
    ch := Byte(p^);
    Inc(p);

    if ch = 32 then
      characterWidth := gCurrentFont^.wordSpacing
    else
      characterWidth := gCurrentFont^.glyphs[ch].width;

    if (color and FONT_MONO) <> 0 then
    begin
      endPtr := ptr + monospacedCharacterWidth;
      ptr := ptr + (monospacedCharacterWidth - characterWidth - gCurrentFont^.letterSpacing) div 2;
    end
    else
      endPtr := ptr + characterWidth + gCurrentFont^.letterSpacing;

    if PtrUInt(endPtr) - PtrUInt(buf) > PtrUInt(length_) then
      Break;

    glyph := @gCurrentFont^.glyphs[ch];
    glyphDataPtr := gCurrentFont^.data + glyph^.offset;

    ptr := ptr + (gCurrentFont^.maxHeight - glyph^.height) * pitch;

    for y := 0 to glyph^.height - 1 do
    begin
      for x := 0 to glyph^.width - 1 do
      begin
        b := glyphDataPtr^;
        Inc(glyphDataPtr);
        ptr^ := palette[(Integer(b) shl 8) + ptr^];
        Inc(ptr);
      end;
      ptr := ptr + pitch - glyph^.width;
    end;

    ptr := endPtr;
  end;

  if (color and FONT_UNDERLINE) <> 0 then
  begin
    underlineLen := PtrUInt(ptr) - PtrUInt(buf);
    underlinePtr := buf + pitch * (gCurrentFont^.maxHeight - 1);
    for idx := 0 to underlineLen - 1 do
    begin
      underlinePtr^ := Byte(color and $FF);
      Inc(underlinePtr);
    end;
  end;

  freeColorBlendTable(color and $FF);
end;

initialization
  FillByte(gFontCache, SizeOf(gFontCache), 0);

end.
