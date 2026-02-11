{$MODE OBJFPC}{$H+}
// Converted from: src/int/datafile.cc/h
// Data file loading, palette conversion, PCX loading.
unit u_datafile;

interface

type
  TDatafileLoader = function(path: PAnsiChar; palette: PByte;
    widthPtr, heightPtr: PInteger): PByte; cdecl;
  TDatafileNameMangler = function(path: PAnsiChar): PAnsiChar; cdecl;

procedure datafileSetFilenameFunc(mangler: TDatafileNameMangler);
procedure setBitmapLoadFunc(loader: TDatafileLoader);
procedure datafileConvertData(data, palette: PByte; width, height: Integer);
procedure datafileConvertDataVGA(data, palette: PByte; width, height: Integer);
function loadRawDataFile(path: PAnsiChar; widthPtr, heightPtr: PInteger): PByte;
function loadDataFile(path: PAnsiChar; widthPtr, heightPtr: PInteger): PByte;
function load256Palette(path: PAnsiChar): PByte;
procedure trimBuffer(data: PByte; widthPtr, heightPtr: PInteger);
function datafileGetPalette: PByte;
function datafileLoadBlock(path: PAnsiChar; sizePtr: PInteger): PByte;

implementation

uses
  SysUtils, u_memdbg, u_pcx, u_platform_compat, u_db, u_color;

function defaultMangleName(path: PAnsiChar): PAnsiChar; cdecl; forward;

var
  loadFunc: TDatafileLoader = nil;
  mangleName: TDatafileNameMangler = @defaultMangleName;
  pal: array[0..767] of Byte;

function defaultMangleName(path: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := path;
end;

procedure datafileSetFilenameFunc(mangler: TDatafileNameMangler);
begin
  mangleName := mangler;
end;

procedure setBitmapLoadFunc(loader: TDatafileLoader);
begin
  loadFunc := loader;
end;

procedure datafileConvertData(data, palette: PByte; width, height: Integer);
var
  indexedPalette: array[0..255] of Byte;
  index: Integer;
  r, g, b: Integer;
  colorTableIndex: Integer;
  size: Integer;
begin
  indexedPalette[0] := 0;
  for index := 1 to 255 do
  begin
    r := palette[index * 3 + 2] shr 3;
    g := palette[index * 3 + 1] shr 3;
    b := palette[index * 3] shr 3;
    colorTableIndex := (r shl 10) or (g shl 5) or b;
    indexedPalette[index] := colorTable[colorTableIndex];
  end;

  size := width * height;
  for index := 0 to size - 1 do
    data[index] := indexedPalette[data[index]];
end;

procedure datafileConvertDataVGA(data, palette: PByte; width, height: Integer);
var
  indexedPalette: array[0..255] of Byte;
  index: Integer;
  r, g, b: Integer;
  colorTableIndex: Integer;
  size: Integer;
begin
  indexedPalette[0] := 0;
  for index := 1 to 255 do
  begin
    r := palette[index * 3 + 2] shr 1;
    g := palette[index * 3 + 1] shr 1;
    b := palette[index * 3] shr 1;
    colorTableIndex := (r shl 10) or (g shl 5) or b;
    indexedPalette[index] := colorTable[colorTableIndex];
  end;

  size := width * height;
  for index := 0 to size - 1 do
    data[index] := indexedPalette[data[index]];
end;

function loadRawDataFile(path: PAnsiChar; widthPtr, heightPtr: PInteger): PByte;
var
  mangledPath: PAnsiChar;
  dot: PAnsiChar;
begin
  mangledPath := mangleName(path);
  dot := StrRScan(mangledPath, '.');
  if dot <> nil then
  begin
    if compat_stricmp(dot + 1, 'pcx') = 0 then
      Exit(loadPCX(mangledPath, widthPtr, heightPtr, @pal[0]));
  end;

  if loadFunc <> nil then
    Exit(loadFunc(mangledPath, @pal[0], widthPtr, heightPtr));

  Result := nil;
end;

function loadDataFile(path: PAnsiChar; widthPtr, heightPtr: PInteger): PByte;
var
  v1: PByte;
begin
  v1 := loadRawDataFile(path, widthPtr, heightPtr);
  if v1 <> nil then
    datafileConvertData(v1, @pal[0], widthPtr^, heightPtr^);
  Result := v1;
end;

function load256Palette(path: PAnsiChar): PByte;
var
  width, height: Integer;
  v3: PByte;
begin
  v3 := loadRawDataFile(path, @width, @height);
  if v3 <> nil then
  begin
    myfree(v3, 'DATAFILE.C', 148);
    Exit(@pal[0]);
  end;
  Result := nil;
end;

procedure trimBuffer(data: PByte; widthPtr, heightPtr: PInteger);
var
  width, height: Integer;
  temp: PByte;
  y, x: Integer;
  src1, src2: PByte;
  tempPtr: PByte;
begin
  width := widthPtr^;
  height := heightPtr^;
  temp := PByte(mymalloc(width * height, 'DATAFILE.C', 157));

  y := 0;
  x := 0;
  src1 := data;
  tempPtr := temp;

  for y := 0 to height - 1 do
  begin
    if src1^ = 0 then
      Break;

    src2 := src1;
    for x := 0 to width - 1 do
    begin
      if src2^ = 0 then
        Break;
      tempPtr^ := src2^;
      Inc(tempPtr);
      Inc(src2);
    end;

    src1 := src1 + width;
  end;

  Move(temp^, data^, x * y);
  myfree(temp, 'DATAFILE.C', 171);
end;

function datafileGetPalette: PByte;
begin
  Result := @pal[0];
end;

function datafileLoadBlock(path: PAnsiChar; sizePtr: PInteger): PByte;
var
  mangledPath: PAnsiChar;
  stream: PDB_FILE;
  size: Integer;
  data: PByte;
begin
  mangledPath := mangleName(path);
  stream := db_fopen(mangledPath, 'rb');
  if stream = nil then
    Exit(nil);

  size := db_filelength(stream);
  data := PByte(mymalloc(size, 'DATAFILE.C', 185));
  if data = nil then
  begin
    sizePtr^ := 0;
    Exit(nil);
  end;

  db_fread(data, 1, size, stream);
  db_fclose(stream);
  sizePtr^ := size;
  Result := data;
end;

end.
