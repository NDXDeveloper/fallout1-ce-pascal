{$MODE OBJFPC}{$H+}
// Converted from: src/int/pcx.cc/h
// PCX image file loader.
unit u_pcx;

interface

function loadPCX(const path: PAnsiChar; widthPtr, heightPtr: PInteger;
  palette: PByte): PByte;

implementation

uses
  u_memdbg, u_db;

type
  TPcxHeader = record
    identifier: Byte;
    version: Byte;
    encoding: Byte;
    bitsPerPixel: Byte;
    minX: SmallInt;
    minY: SmallInt;
    maxX: SmallInt;
    maxY: SmallInt;
    horizontalResolution: SmallInt;
    verticalResolution: SmallInt;
    palette: array[0..47] of Byte;
    reserved1: Byte;
    planeCount: Byte;
    bytesPerLine: SmallInt;
    paletteType: SmallInt;
    horizontalScreenSize: SmallInt;
    verticalScreenSize: SmallInt;
    reserved2: array[0..53] of Byte;
  end;

var
  runcount: Byte = 0;
  runvalue: Byte = 0;

function getWord(stream: PDB_FILE): SmallInt;
var
  value: SmallInt;
begin
  db_fread(@value, SizeOf(value), 1, stream);
  Result := value;
end;

procedure readPcxHeader(var pcxHeader: TPcxHeader; stream: PDB_FILE);
var
  index: Integer;
begin
  pcxHeader.identifier := Byte(db_fgetc(stream));
  pcxHeader.version := Byte(db_fgetc(stream));
  pcxHeader.encoding := Byte(db_fgetc(stream));
  pcxHeader.bitsPerPixel := Byte(db_fgetc(stream));
  pcxHeader.minX := getWord(stream);
  pcxHeader.minY := getWord(stream);
  pcxHeader.maxX := getWord(stream);
  pcxHeader.maxY := getWord(stream);
  pcxHeader.horizontalResolution := getWord(stream);
  pcxHeader.verticalResolution := getWord(stream);

  for index := 0 to 47 do
    pcxHeader.palette[index] := Byte(db_fgetc(stream));

  pcxHeader.reserved1 := Byte(db_fgetc(stream));
  pcxHeader.planeCount := Byte(db_fgetc(stream));
  pcxHeader.bytesPerLine := getWord(stream);
  pcxHeader.paletteType := getWord(stream);
  pcxHeader.horizontalScreenSize := getWord(stream);
  pcxHeader.verticalScreenSize := getWord(stream);

  for index := 0 to 53 do
    pcxHeader.reserved2[index] := Byte(db_fgetc(stream));
end;

function pcxDecodeScanline(data: PByte; size: Integer; stream: PDB_FILE): Integer;
var
  runLength: Byte;
  value: Byte;
  uncompressedSize: Integer;
  index: Integer;
begin
  runLength := runcount;
  value := runvalue;

  uncompressedSize := 0;
  index := 0;
  repeat
    uncompressedSize := uncompressedSize + runLength;
    while (runLength > 0) and (index < size) do
    begin
      data[index] := value;
      Dec(runLength);
      Inc(index);
    end;

    runcount := runLength;
    runvalue := value;

    if runLength <> 0 then
    begin
      uncompressedSize := uncompressedSize - runLength;
      Break;
    end;

    value := Byte(db_fgetc(stream));
    if (value and $C0) = $C0 then
    begin
      runcount := value and $3F;
      value := Byte(db_fgetc(stream));
      runLength := runcount;
    end
    else
    begin
      runLength := 1;
    end;
  until index >= size;

  runcount := runLength;
  runvalue := value;

  Result := uncompressedSize;
end;

function readPcxVgaPalette(var pcxHeader: TPcxHeader; palette: PByte;
  stream: PDB_FILE): Integer;
var
  pos, size: LongInt;
  index: Integer;
begin
  if pcxHeader.version <> 5 then
    Exit(0);

  pos := db_ftell(stream);
  size := db_filelength(stream);
  db_fseek(stream, size - 769, 0); // SEEK_SET = 0
  if db_fgetc(stream) <> 12 then
  begin
    db_fseek(stream, pos, 0);
    Exit(0);
  end;

  for index := 0 to 767 do
    palette[index] := Byte(db_fgetc(stream));

  db_fseek(stream, pos, 0);

  Result := 1;
end;

function loadPCX(const path: PAnsiChar; widthPtr, heightPtr: PInteger;
  palette: PByte): PByte;
var
  stream: PDB_FILE;
  pcxHeader: TPcxHeader;
  width, height: Integer;
  bytesPerLine: Integer;
  data, ptr: PByte;
  y: Integer;
begin
  stream := db_fopen(path, 'rb');
  if stream = nil then
    Exit(nil);

  readPcxHeader(pcxHeader, stream);

  width := pcxHeader.maxX - pcxHeader.minX + 1;
  height := pcxHeader.maxY - pcxHeader.minY + 1;

  widthPtr^ := width;
  heightPtr^ := height;

  bytesPerLine := pcxHeader.planeCount * pcxHeader.bytesPerLine;
  data := PByte(mymalloc(bytesPerLine * height, 'PCX.C', 195));
  if data = nil then
  begin
    db_fclose(stream);
    Exit(nil);
  end;

  runcount := 0;
  runvalue := 0;

  ptr := data;
  for y := 0 to height - 1 do
  begin
    pcxDecodeScanline(ptr, bytesPerLine, stream);
    ptr := ptr + width;
  end;

  readPcxVgaPalette(pcxHeader, palette, stream);

  db_fclose(stream);

  Result := data;
end;

end.
