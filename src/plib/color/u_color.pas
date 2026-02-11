unit u_color;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/plib/color/color.h + color.cc
// Color palette management system: palette I/O, color tables, blending,
// gamma correction, color mixing, and palette stack.

interface

const
  COLOR_PALETTE_STACK_CAPACITY = 16;

type
  TColor = Byte;
  TColorRGB = LongInt;
  TColorIndex = Byte;
  PColor = ^TColor;

  TColorNameMangleFunc = function(const Path: PAnsiChar): PAnsiChar; cdecl;
  TFadeBkFunc = procedure; cdecl;
  TColorOpenFunc = function(const Path: PAnsiChar): Pointer; cdecl;
  TColorReadFunc = function(FD: Pointer; Buffer: Pointer; Size: SizeUInt): Integer; cdecl;
  TColorCloseFunc = function(FD: Pointer): Integer; cdecl;
  TColorMallocFunc = function(Size: SizeUInt): Pointer; cdecl;
  TColorReallocFunc = function(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl;
  TColorFreeFunc = procedure(Ptr: Pointer); cdecl;

  TColorPaletteStackEntry = record
    MappedColors: array[0..255] of Byte;
    CMap: array[0..767] of Byte;
    ColorTable: array[0..32767] of Byte;
  end;
  PColorPaletteStackEntry = ^TColorPaletteStackEntry;

var
  cmap: array[0..767] of Byte;
  mappedColor: array[0..255] of Byte;
  colorMixAddTable: array[0..255, 0..255] of TColor;
  intensityColorTable: array[0..255, 0..255] of Byte;
  colorMixMulTable: array[0..255, 0..255] of TColor;
  colorTable: array[0..32767] of Byte;

procedure colorInitIO(OpenProc: TColorOpenFunc; ReadProc: TColorReadFunc; CloseProc: TColorCloseFunc);
procedure colorSetNameMangler(C: TColorNameMangleFunc);
function colorMixAdd(A, B: TColor): TColor;
function colorMixMul(A, B: TColor): TColor;
function calculateColor(A1, A2: Integer): Integer;
function RGB2Color(C: TColorRGB): TColor;
function Color2RGB(A1: Integer): Integer;
procedure fadeSystemPalette(OldPalette, NewPalette: PByte; Steps: Integer);
procedure colorSetFadeBkFunc(Callback: TFadeBkFunc);
procedure setBlackSystemPalette;
procedure setSystemPalette(Palette: PByte);
function getSystemPalette: PByte;
procedure setSystemPaletteEntries(A1: PByte; A2, A3: Integer);
procedure getSystemPaletteEntry(Entry: Integer; R, G, B: PByte);
function loadColorTable(const Path: PAnsiChar): Boolean;
function colorError: PAnsiChar;
procedure setColorPalette(Pal: PByte);
procedure setColorPaletteEntry(Entry: Integer; R, G, B: Byte);
procedure getColorPaletteEntry(Entry: Integer; R, G, B: PByte);
function getColorBlendTable(Ch: Integer): PByte;
procedure freeColorBlendTable(A1: Integer);
procedure colorRegisterAlloc(MallocProc: TColorMallocFunc; ReallocProc: TColorReallocFunc; FreeProc: TColorFreeFunc);
procedure colorGamma(Value: Double);
function colorGetGamma: Double;
function colorMappedColor(I: TColorIndex): Integer;
function colorPushColorPalette: Boolean;
function colorPopColorPalette: Boolean;
function initColors: Boolean;
procedure colorsClose;
function getColorPalette: PByte;

implementation

uses
  Math,
  u_svga; // GNW95_SetPalette, GNW95_SetPaletteEntries, renderPresent, sharedFpsLimiter

// Forward declarations for static helpers
procedure setIntensityTableColor(A1: Integer); forward;
procedure setIntensityTables; forward;
procedure setMixTableColor(A1: Integer); forward;
procedure buildBlendTable(Ptr: PByte; Ch: Byte); forward;
procedure rebuildColorBlendTables; forward;

// Static function pointers for color file I/O
function defaultMalloc(Size: SizeUInt): Pointer; cdecl; forward;
function defaultRealloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl; forward;
procedure defaultFree(Ptr: Pointer); cdecl; forward;

var
  // 0x4FE0DC
  _aColor_cNoError: PAnsiChar = 'color.c: No errors'#10;
  // 0x4FE108
  _aColor_cColorTa: PAnsiChar = 'color.c: color table not found'#10;
  // 0x4FE130
  _aColor_cColorpa: PAnsiChar = 'color.c: colorpalettestack overflow';
  // 0x4FE158
  _aColor_cColor_0: PAnsiChar = 'color.c: colorpalettestack underflow';

  // 0x539EE0
  errorStr: PAnsiChar;
  // 0x539EE4
  colorsInited: Boolean = False;
  // 0x539EE8
  currentGamma: Double = 1.0;
  // 0x539EF0
  colorFadeBkFuncP: TFadeBkFunc = nil;
  // 0x539EF4
  mallocPtr: TColorMallocFunc;
  // 0x539EF8
  reallocPtr: TColorReallocFunc;
  // 0x539EFC
  freePtr: TColorFreeFunc;
  // 0x539F00
  colorNameMangler: TColorNameMangleFunc = nil;

  // 0x673280
  colorPaletteStack: array[0..COLOR_PALETTE_STACK_CAPACITY - 1] of PColorPaletteStackEntry;
  // 0x6732C0
  systemCmap: array[0..767] of Byte;
  // 0x6735C0
  currentGammaTable: array[0..63] of Byte;
  // 0x673600
  blendTable: array[0..255] of PByte;
  // 0x6ABB00
  tos: Integer = 0;

  // 0x6ABB58
  readFunc: TColorReadFunc = nil;
  // 0x6ABB5C
  closeFunc: TColorCloseFunc = nil;
  // 0x6ABB60
  openFunc: TColorOpenFunc = nil;

// 0x4BFE1C
function defaultMalloc(Size: SizeUInt): Pointer; cdecl;
begin
  Result := GetMem(Size);
end;

// 0x4BFE24
function defaultRealloc(Ptr: Pointer; Size: SizeUInt): Pointer; cdecl;
begin
  Result := ReAllocMem(Ptr, Size);
end;

// 0x4BFE2C
procedure defaultFree(Ptr: Pointer); cdecl;
begin
  FreeMem(Ptr);
end;

// 0x4BFDC0
function colorOpen(const FilePath: PAnsiChar): Pointer;
begin
  if openFunc <> nil then
    Result := openFunc(FilePath)
  else
    Result := nil;
end;

// 0x4BFDD8
function colorRead(FD: Pointer; Buffer: Pointer; Size: SizeUInt): Integer;
begin
  if readFunc <> nil then
    Result := readFunc(FD, Buffer, Size)
  else
    Result := -1;
end;

// 0x4BFDF0
function colorClose(FD: Pointer): Integer;
begin
  if closeFunc <> nil then
    Result := closeFunc(FD)
  else
    Result := -1;
end;

// 0x4BFE08
procedure colorInitIO(OpenProc: TColorOpenFunc; ReadProc: TColorReadFunc; CloseProc: TColorCloseFunc);
begin
  openFunc := OpenProc;
  readFunc := ReadProc;
  closeFunc := CloseProc;
end;

// 0x4BFE34
procedure colorSetNameMangler(C: TColorNameMangleFunc);
begin
  colorNameMangler := C;
end;

// 0x4BFE3C
function colorMixAdd(A, B: TColor): TColor;
begin
  Result := colorMixAddTable[A][B];
end;

// 0x4BFE58
function colorMixMul(A, B: TColor): TColor;
begin
  Result := colorMixMulTable[A][B];
end;

// 0x4BFE74
function calculateColor(A1, A2: Integer): Integer;
begin
  Result := intensityColorTable[A2][A1 shr 9];
end;

// 0x4BFE8C
function RGB2Color(C: TColorRGB): TColor;
begin
  Result := colorTable[C];
end;

// 0x4BFEA0
function Color2RGB(A1: Integer): Integer;
var
  V1, V2, V3: Integer;
begin
  V1 := cmap[3 * A1] shr 1;
  V2 := cmap[3 * A1 + 1] shr 1;
  V3 := cmap[3 * A1 + 2] shr 1;
  Result := ((V1 shl 5) or V2) shl 5 or V3;
end;

// 0x4BFEE0
procedure fadeSystemPalette(OldPalette, NewPalette: PByte; Steps: Integer);
var
  Step, Index: Integer;
  Palette: array[0..767] of Byte;
begin
  for Step := 0 to Steps - 1 do
  begin
    if sharedFpsLimiter <> nil then
      sharedFpsLimiter.Mark;

    for Index := 0 to 767 do
      Palette[Index] := OldPalette[Index] - (OldPalette[Index] - NewPalette[Index]) * Step div Steps;

    if colorFadeBkFuncP <> nil then
    begin
      if Step mod 128 = 0 then
        colorFadeBkFuncP();
    end;

    setSystemPalette(@Palette[0]);
    renderPresent;
    if sharedFpsLimiter <> nil then
      sharedFpsLimiter.Throttle;
  end;

  if sharedFpsLimiter <> nil then
    sharedFpsLimiter.Mark;
  setSystemPalette(NewPalette);
  renderPresent;
  if sharedFpsLimiter <> nil then
    sharedFpsLimiter.Throttle;
end;

// 0x4BFF94
procedure colorSetFadeBkFunc(Callback: TFadeBkFunc);
begin
  colorFadeBkFuncP := Callback;
end;

// 0x4BFF9C
procedure setBlackSystemPalette;
var
  Tmp: array[0..767] of Byte;
begin
  FillChar(Tmp, SizeOf(Tmp), 0);
  setSystemPalette(@Tmp[0]);
end;

// 0x4BFFA4
procedure setSystemPalette(Palette: PByte);
var
  NewPalette: array[0..767] of Byte;
  Index: Integer;
  v: Byte;
begin
  for Index := 0 to 767 do
  begin
    v := Palette[Index];
    if v > 63 then v := 63;
    NewPalette[Index] := currentGammaTable[v];
    systemCmap[Index] := Palette[Index];
  end;

  GNW95_SetPalette(@NewPalette[0]);
end;

// 0x4BFFE0
function getSystemPalette: PByte;
begin
  Result := @systemCmap[0];
end;

// 0x4BFFE8
procedure setSystemPaletteEntries(A1: PByte; A2, A3: Integer);
var
  NewPalette: array[0..767] of Byte;
  Length, Index: Integer;
  v0, v1, v2: Byte;
begin
  Length := A3 - A2 + 1;
  for Index := 0 to Length - 1 do
  begin
    v0 := A1[Index * 3]; if v0 > 63 then v0 := 63;
    v1 := A1[Index * 3 + 1]; if v1 > 63 then v1 := 63;
    v2 := A1[Index * 3 + 2]; if v2 > 63 then v2 := 63;
    NewPalette[Index * 3] := currentGammaTable[v0];
    NewPalette[Index * 3 + 1] := currentGammaTable[v1];
    NewPalette[Index * 3 + 2] := currentGammaTable[v2];

    systemCmap[A2 * 3 + Index * 3] := A1[Index * 3];
    systemCmap[A2 * 3 + Index * 3 + 1] := A1[Index * 3 + 1];
    systemCmap[A2 * 3 + Index * 3 + 2] := A1[Index * 3 + 2];
  end;

  GNW95_SetPaletteEntries(@NewPalette[0], A2, A3 - A2 + 1);
end;

// 0x4C00D8
procedure getSystemPaletteEntry(Entry: Integer; R, G, B: PByte);
var
  BaseIndex: Integer;
begin
  BaseIndex := Entry * 3;
  R^ := systemCmap[BaseIndex];
  G^ := systemCmap[BaseIndex + 1];
  B^ := systemCmap[BaseIndex + 2];
end;

// 0x4C00FC
procedure setIntensityTableColor(A1: Integer);
var
  V1, V2, V3, V4, V5, V6, V7, V8, V9: Integer;
  Index: Integer;
begin
  V5 := 0;

  for Index := 0 to 127 do
  begin
    V1 := (Color2RGB(A1) and $7C00) shr 10;
    V2 := (Color2RGB(A1) and $3E0) shr 5;
    V3 := Color2RGB(A1) and $1F;

    V4 := (((V1 * V5) shr 16) shl 10) or (((V2 * V5) shr 16) shl 5) or ((V3 * V5) shr 16);
    intensityColorTable[A1][Index] := colorTable[V4];

    V6 := V1 + ((($1F - V1) * V5) shr 16);
    V7 := V2 + ((($1F - V2) * V5) shr 16);
    V8 := V3 + ((($1F - V3) * V5) shr 16);

    V9 := (V6 shl 10) or (V7 shl 5) or V8;
    intensityColorTable[A1][$7F + Index + 1] := colorTable[V9];

    V5 := V5 + $200;
  end;
end;

// 0x4C0204
procedure setIntensityTables;
var
  Index: Integer;
begin
  for Index := 0 to 255 do
  begin
    if mappedColor[Index] <> 0 then
      setIntensityTableColor(Index)
    else
      FillChar(intensityColorTable[Index], 256, 0);
  end;
end;

// 0x4C0248
procedure setMixTableColor(A1: Integer);
var
  I: Integer;
  V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13: Integer;
  V14, V15, V16, V17, V18: Integer;
  V19, V20, V21, V22, V23, V24, V25, V26, V27, V28, V29: Integer;
  PaletteIndex: Integer;
begin
  for I := 0 to 255 do
  begin
    if (mappedColor[A1] <> 0) and (mappedColor[I] <> 0) then
    begin
      V2 := (Color2RGB(A1) and $7C00) shr 10;
      V3 := (Color2RGB(A1) and $3E0) shr 5;
      V4 := Color2RGB(A1) and $1F;

      V5 := (Color2RGB(I) and $7C00) shr 10;
      V6 := (Color2RGB(I) and $3E0) shr 5;
      V7 := Color2RGB(I) and $1F;

      V8 := V2 + V5;
      V9 := V3 + V6;
      V10 := V4 + V7;

      V11 := V8;
      if V9 > V11 then V11 := V9;
      if V10 > V11 then V11 := V10;

      if V11 <= $1F then
      begin
        PaletteIndex := (V8 shl 10) or (V9 shl 5) or V10;
        V12 := colorTable[PaletteIndex];
      end
      else
      begin
        V13 := V11 - $1F;

        V14 := V8 - V13;
        V15 := V9 - V13;
        V16 := V10 - V13;

        if V14 < 0 then V14 := 0;
        if V15 < 0 then V15 := 0;
        if V16 < 0 then V16 := 0;

        V17 := (V14 shl 10) or (V15 shl 5) or V16;
        V18 := colorTable[V17];

        V19 := Trunc(((V11 + (-31.0)) * 0.0078125 + 1.0) * 65536.0);
        V12 := calculateColor(V19, V18);
      end;

      colorMixAddTable[A1][I] := V12;

      V20 := (Color2RGB(A1) and $7C00) shr 10;
      V21 := (Color2RGB(A1) and $3E0) shr 5;
      V22 := Color2RGB(A1) and $1F;

      V23 := (Color2RGB(I) and $7C00) shr 10;
      V24 := (Color2RGB(I) and $3E0) shr 5;
      V25 := Color2RGB(I) and $1F;

      V26 := (V20 * V23) shr 5;
      V27 := (V21 * V24) shr 5;
      V28 := (V22 * V25) shr 5;

      V29 := (V26 shl 10) or (V27 shl 5) or V28;
      colorMixMulTable[A1][I] := colorTable[V29];
    end
    else
    begin
      if mappedColor[I] <> 0 then
      begin
        colorMixAddTable[A1][I] := I;
        colorMixMulTable[A1][I] := I;
      end
      else
      begin
        colorMixAddTable[A1][I] := A1;
        colorMixMulTable[A1][I] := A1;
      end;
    end;
  end;
end;

// 0x4C046C
function loadColorTable(const Path: PAnsiChar): Boolean;
var
  Handle: Pointer;
  ActualPath: PAnsiChar;
  Index: Integer;
  R, G, B: Byte;
  FileType: LongWord;
begin
  ActualPath := Path;
  if colorNameMangler <> nil then
    ActualPath := colorNameMangler(Path);

  // NOTE: Uninline.
  Handle := colorOpen(ActualPath);
  if Handle = nil then
  begin
    errorStr := _aColor_cColorTa;
    Result := False;
    Exit;
  end;

  for Index := 0 to 255 do
  begin
    // NOTE: Uninline.
    colorRead(Handle, @R, SizeOf(R));
    colorRead(Handle, @G, SizeOf(G));
    colorRead(Handle, @B, SizeOf(B));

    if (R <= $3F) and (G <= $3F) and (B <= $3F) then
      mappedColor[Index] := 1
    else
    begin
      R := 0;
      G := 0;
      B := 0;
      mappedColor[Index] := 0;
    end;

    cmap[Index * 3] := R;
    cmap[Index * 3 + 1] := G;
    cmap[Index * 3 + 2] := B;
  end;

  // NOTE: Uninline.
  colorRead(Handle, @colorTable[0], $8000);

  // NOTE: Uninline.
  colorRead(Handle, @FileType, SizeOf(FileType));

  if FileType = $4E455743 then // 'NEWC'
  begin
    // NOTE: Uninline.
    colorRead(Handle, @intensityColorTable[0][0], $10000);
    colorRead(Handle, @colorMixAddTable[0][0], $10000);
    colorRead(Handle, @colorMixMulTable[0][0], $10000);
  end
  else
  begin
    setIntensityTables;

    for Index := 0 to 255 do
      setMixTableColor(Index);
  end;

  rebuildColorBlendTables;

  // NOTE: Uninline.
  colorClose(Handle);

  Result := True;
end;

// 0x4C063C
function colorError: PAnsiChar;
begin
  Result := errorStr;
end;

// 0x4C0644
procedure setColorPalette(Pal: PByte);
begin
  Move(Pal^, cmap[0], SizeOf(cmap));
  FillChar(mappedColor[0], SizeOf(mappedColor), 1);
end;

// 0x4C0680
procedure setColorPaletteEntry(Entry: Integer; R, G, B: Byte);
var
  BaseIndex: Integer;
begin
  BaseIndex := Entry * 3;
  cmap[BaseIndex] := R;
  cmap[BaseIndex + 1] := G;
  cmap[BaseIndex + 2] := B;
end;

// 0x4C06A8
procedure getColorPaletteEntry(Entry: Integer; R, G, B: PByte);
var
  BaseIndex: Integer;
begin
  BaseIndex := Entry * 3;
  R^ := cmap[BaseIndex];
  G^ := cmap[BaseIndex + 1];
  B^ := cmap[BaseIndex + 2];
end;

// 0x4C06CC
procedure buildBlendTable(Ptr: PByte; Ch: Byte);
var
  R, G, B: Integer;
  I, J: Integer;
  V12, V14, V16: Integer;
  R_1, G_1, B_1: Integer;
  R_2, G_2, B_2: Integer;
  V31: Integer;
  V18, V20: Integer;
  PalIndex: Integer;
begin
  R := (Color2RGB(Ch) and $7C00) shr 10;
  G := (Color2RGB(Ch) and $3E0) shr 5;
  B := Color2RGB(Ch) and $1F;

  for I := 0 to 255 do
    Ptr[I] := I;

  Ptr := Ptr + 256;

  B_1 := B;
  V31 := 6;
  G_1 := G;
  R_1 := R;

  B_2 := B_1;
  G_2 := G_1;
  R_2 := R_1;

  for J := 0 to 6 do
  begin
    for I := 0 to 255 do
    begin
      V12 := (Color2RGB(I) and $7C00) shr 10;
      V14 := (Color2RGB(I) and $3E0) shr 5;
      V16 := Color2RGB(I) and $1F;
      PalIndex := 0;
      PalIndex := PalIndex or (((R_2 + V12 * V31) div 7) shl 10);
      PalIndex := PalIndex or (((G_2 + V14 * V31) div 7) shl 5);
      PalIndex := PalIndex or ((B_2 + V16 * V31) div 7);
      Ptr[I] := colorTable[PalIndex];
    end;
    Dec(V31);
    Ptr := Ptr + 256;
    R_2 := R_2 + R_1;
    G_2 := G_2 + G_1;
    B_2 := B_2 + B_1;
  end;

  V18 := 0;
  for J := 0 to 5 do
  begin
    V20 := V18 div 7 + $FFFF;

    for I := 0 to 255 do
      Ptr[I] := calculateColor(V20, Ch);

    V18 := V18 + $10000;
    Ptr := Ptr + 256;
  end;
end;

// 0x4C0918
procedure rebuildColorBlendTables;
var
  I: Integer;
begin
  for I := 0 to 255 do
  begin
    if blendTable[I] <> nil then
      buildBlendTable(blendTable[I], I);
  end;
end;

// 0x4C0948
function getColorBlendTable(Ch: Integer): PByte;
var
  Ptr: PByte;
  CountPtr: PLongInt;
begin
  if blendTable[Ch] = nil then
  begin
    Ptr := mallocPtr(4100);
    PLongInt(Ptr)^ := 1;
    blendTable[Ch] := Ptr + 4;
    buildBlendTable(blendTable[Ch], Ch);
  end;

  Ptr := blendTable[Ch];
  CountPtr := PLongInt(Ptr - 4);
  CountPtr^ := CountPtr^ + 1;

  Result := Ptr;
end;

// 0x4C09A8
procedure freeColorBlendTable(A1: Integer);
var
  V2: PByte;
  CountPtr: PLongInt;
begin
  V2 := blendTable[A1];
  if V2 <> nil then
  begin
    CountPtr := PLongInt(V2 - SizeOf(LongInt));
    CountPtr^ := CountPtr^ - 1;
    if CountPtr^ = 0 then
    begin
      freePtr(CountPtr);
      blendTable[A1] := nil;
    end;
  end;
end;

// 0x4C09E0
procedure colorRegisterAlloc(MallocProc: TColorMallocFunc; ReallocProc: TColorReallocFunc; FreeProc: TColorFreeFunc);
begin
  mallocPtr := MallocProc;
  reallocPtr := ReallocProc;
  freePtr := FreeProc;
end;

// 0x4C09F4
procedure colorGamma(Value: Double);
var
  I: Integer;
  V: Double;
begin
  currentGamma := Value;

  for I := 0 to 63 do
  begin
    V := Power(I, currentGamma);
    if V < 0.0 then
      currentGammaTable[I] := 0
    else if V > 63.0 then
      currentGammaTable[I] := 63
    else
      currentGammaTable[I] := Trunc(V);
  end;

  setSystemPalette(@systemCmap[0]);
end;

// 0x4C0A90
function colorGetGamma: Double;
begin
  Result := currentGamma;
end;

// 0x4C0A98
function colorMappedColor(I: TColorIndex): Integer;
begin
  Result := mappedColor[I];
end;

// 0x4C13AC
function colorPushColorPalette: Boolean;
var
  Entry: PColorPaletteStackEntry;
begin
  if tos >= COLOR_PALETTE_STACK_CAPACITY then
  begin
    errorStr := _aColor_cColorpa;
    Result := False;
    Exit;
  end;

  Entry := GetMem(SizeOf(TColorPaletteStackEntry));
  colorPaletteStack[tos] := Entry;

  Move(mappedColor[0], Entry^.MappedColors[0], SizeOf(mappedColor));
  Move(cmap[0], Entry^.CMap[0], SizeOf(cmap));
  Move(colorTable[0], Entry^.ColorTable[0], SizeOf(colorTable));

  Inc(tos);

  Result := True;
end;

// 0x4C1464
function colorPopColorPalette: Boolean;
var
  Entry: PColorPaletteStackEntry;
  Index: Integer;
begin
  if tos = 0 then
  begin
    errorStr := _aColor_cColor_0;
    Result := False;
    Exit;
  end;

  Dec(tos);

  Entry := colorPaletteStack[tos];

  Move(Entry^.MappedColors[0], mappedColor[0], SizeOf(mappedColor));
  Move(Entry^.CMap[0], cmap[0], SizeOf(cmap));
  Move(Entry^.ColorTable[0], colorTable[0], SizeOf(colorTable));

  FreeMem(Entry);
  colorPaletteStack[tos] := nil;

  setIntensityTables;

  for Index := 0 to 255 do
    setMixTableColor(Index);

  rebuildColorBlendTables;

  Result := True;
end;

// 0x4C1550
function initColors: Boolean;
begin
  if colorsInited then
  begin
    Result := True;
    Exit;
  end;

  colorsInited := True;

  colorGamma(1.0);

  if not loadColorTable('color.pal') then
  begin
    Result := False;
    Exit;
  end;

  setSystemPalette(@cmap[0]);

  Result := True;
end;

// 0x4C159C
procedure colorsClose;
var
  Index: Integer;
begin
  for Index := 0 to 255 do
    freeColorBlendTable(Index);

  for Index := 0 to tos - 1 do
    FreeMem(colorPaletteStack[Index]);

  tos := 0;
end;

// 0x4C15E8
function getColorPalette: PByte;
begin
  Result := @cmap[0];
end;

initialization
  errorStr := _aColor_cNoError;
  mallocPtr := @defaultMalloc;
  reallocPtr := @defaultRealloc;
  freePtr := @defaultFree;
  FillChar(blendTable, SizeOf(blendTable), 0);
  FillChar(colorPaletteStack, SizeOf(colorPaletteStack), 0);
  cmap[0] := $3F;
  cmap[1] := $3F;
  cmap[2] := $3F;

end.
