{$MODE OBJFPC}{$H+}
// Converted from: src/game/graphlib.h + graphlib.cc
// Graphics utility library: LZS compression/decompression, greyscale conversion,
// 1-bit to 8-bit blitting.
unit u_graphlib;

interface

var
  dad: PInteger;
  match_length: Integer;
  textsize: Integer;
  rson: PInteger;
  lson: PInteger;
  text_buf: PByte;
  codesize: Integer;
  match_position: Integer;

function HighRGB(a1: Integer): Integer;
procedure bit1exbit8(ulx, uly, lrx, lry, offset_x, offset_y: Integer;
  src, dest: PByte; src_pitch, dest_pitch: Integer; color: Byte);
function CompLZS(a1, a2: PByte; a3: Integer): Integer;
function DecodeLZS(src, dest: PByte; length: Integer): Integer;
procedure InitGreyTable(a1, a2: Integer);
procedure grey_buf(surface: PByte; width, height, pitch: Integer);

implementation

uses
  u_color, u_debug, u_memory;

var
  GreyTable: array[0..255] of Byte;

procedure InitTree; forward;
procedure InsertNode(a1: Integer); forward;
procedure DeleteNode(a1: Integer); forward;

function HighRGB(a1: Integer): Integer;
var
  v1, r, g, b, res: Integer;
begin
  v1 := Color2RGB(a1);
  r := (v1 and $7C00) shr 10;
  g := (v1 and $3E0) shr 5;
  b := (v1 and $1F);

  res := g;
  if r > res then
    res := r;

  res := res and $FF;
  if res <= b then
    res := b;

  Result := res;
end;

procedure bit1exbit8(ulx, uly, lrx, lry, offset_x, offset_y: Integer;
  src, dest: PByte; src_pitch, dest_pitch: Integer; color: Byte);
var
  x, y, width, height, mask, bits: Integer;
  src_base, src_curr, dest_ptr: PByte;
begin
  width := lrx - ulx + 1;
  height := lry - uly + 1;

  src_base := src + uly * (src_pitch div 8);
  src_curr := src_base + ulx div 8;
  bits := src_curr^;
  Inc(src_curr);

  dest_ptr := dest + dest_pitch * offset_y + offset_x;

  for y := 0 to height - 1 do
  begin
    mask := 128 shr (ulx mod 8);

    for x := 0 to width - 1 do
    begin
      if (bits and mask) <> 0 then
        dest_ptr^ := color;

      mask := mask shr 1;
      if mask = 0 then
      begin
        bits := src_curr^;
        Inc(src_curr);
        mask := 128;
      end;

      Inc(dest_ptr);
    end;

    src_base := src_base + src_pitch div 8;
    src_curr := src_base + ulx div 8;
    bits := src_curr^;
    Inc(src_curr);

    dest_ptr := dest_ptr + (dest_pitch - width);
  end;
end;

function CompLZS(a1, a2: PByte; a3: Integer): Integer;
var
  v29: array[0..31] of Byte;
  v3, v4, v10, v36, v30, count, index, rc: Integer;
  v41: Byte;
  v11, v16, v38: Integer;
  v34: Byte;
  src, dst: PByte;
begin
  dad := nil;
  rson := nil;
  lson := nil;
  text_buf := nil;

  lson := PInteger(mem_malloc(SizeOf(Integer) * 4104));
  rson := PInteger(mem_malloc(SizeOf(Integer) * 4376));
  dad := PInteger(mem_malloc(SizeOf(Integer) * 4104));
  text_buf := PByte(mem_malloc(SizeOf(Byte) * 4122));

  if (lson = nil) or (rson = nil) or (dad = nil) or (text_buf = nil) then
  begin
    debug_printf(#10'GRAPHLIB: Error allocating compression buffers!'#10);

    if dad <> nil then mem_free(dad);
    if rson <> nil then mem_free(rson);
    if lson <> nil then mem_free(lson);
    if text_buf <> nil then mem_free(text_buf);

    Exit(-1);
  end;

  InitTree;

  FillChar(text_buf^, 4078, Ord(' '));

  src := a1;
  count := 0;
  v30 := 0;
  for index := 4078 to 4095 do
  begin
    (text_buf + index)^ := src^;
    Inc(src);
    if v30 > a3 then
      Break;
    Inc(v30);
    Inc(count);
  end;

  textsize := count;

  for index := 4077 downto 4060 do
    InsertNode(index);

  InsertNode(4078);

  v29[1] := 0;
  v3 := 4078;
  v4 := 0;
  v10 := 0;
  v36 := 1;
  v41 := 1;
  rc := 0;
  dst := a2;

  while count <> 0 do
  begin
    if count < match_length then
      match_length := count;

    v11 := v36 + 1;
    if match_length > 2 then
    begin
      v29[v36 + 1] := Byte(match_position);
      v29[v36 + 2] := ((match_length - 3) or ((match_position shr 4) and $F0));
      v36 := v11 + 1;
    end
    else
    begin
      match_length := 1;
      v29[1] := v29[1] or v41;
      v29[v36 + 1] := (text_buf + v3)^;
      Inc(v36);
    end;

    if v41 = 128 then
      v41 := 0
    else
      v41 := v41 * 2;

    if v41 = 0 then
    begin
      v11 := 0;
      if v36 <> 0 then
      begin
        while True do
        begin
          Inc(v4);
          dst^ := v29[v11 + 1];
          Inc(dst);
          if v4 > a3 then
          begin
            rc := -1;
            Break;
          end;

          Inc(v11);
          if v11 >= v36 then
            Break;
        end;

        if rc = -1 then
          Break;
      end;

      codesize := codesize + v36;
      v29[1] := 0;
      v36 := 1;
      v41 := 1;
    end;

    v38 := match_length;
    for v16 := 0 to v38 - 1 do
    begin
      v34 := src^;
      Inc(src);
      if v30 >= a3 then
        Break;
      Inc(v30);

      DeleteNode(v10);

      (text_buf + v10)^ := v34;

      if v10 < 17 then
        (text_buf + v10 + 4096)^ := v34;

      v3 := (v3 + 1) and $FFF;
      v10 := (v10 + 1) and $FFF;
      InsertNode(v3);
    end;

    while v16 < v38 do
    begin
      DeleteNode(v10);
      v3 := (v3 + 1) and $FFF;
      v10 := (v10 + 1) and $FFF;
      Dec(count);
      if count <> 0 then
        InsertNode(v3);
      Inc(v16);
    end;
  end;

  if rc <> -1 then
  begin
    for v11 := 0 to v36 - 1 do
    begin
      Inc(v4);
      Inc(v10);
      dst^ := v29[v11 + 1];
      Inc(dst);
      if v10 > a3 then
      begin
        rc := -1;
        Break;
      end;
    end;

    codesize := codesize + v36;
  end;

  mem_free(lson);
  mem_free(rson);
  mem_free(dad);
  mem_free(text_buf);

  if rc = -1 then
    v4 := -1;

  Result := v4;
end;

procedure InitTree;
var
  index: Integer;
begin
  for index := 4097 to 4352 do
    (rson + index)^ := 4096;

  for index := 0 to 4095 do
    (dad + index)^ := 4096;
end;

procedure InsertNode(a1: Integer);
var
  v2, v10: PByte;
  v21, v5, v6, v9, v11: Integer;
begin
  (lson + a1)^ := 4096;
  (rson + a1)^ := 4096;
  match_length := 0;

  v2 := text_buf + a1;
  v21 := 4097 + (text_buf + a1)^;
  v5 := 1;

  while True do
  begin
    v6 := v21;
    if v5 < 0 then
    begin
      if (lson + v6)^ = 4096 then
      begin
        (lson + v6)^ := a1;
        (dad + a1)^ := v21;
        Exit;
      end;
      v21 := (lson + v6)^;
    end
    else
    begin
      if (rson + v6)^ = 4096 then
      begin
        (rson + v6)^ := a1;
        (dad + a1)^ := v21;
        Exit;
      end;
      v21 := (rson + v6)^;
    end;

    v10 := v2 + 1;
    v11 := v21 + 1;
    for v9 := 1 to 17 do
    begin
      v5 := Integer(v10^) - Integer((text_buf + v11)^);
      if v5 <> 0 then
        Break;
      Inc(v10);
      Inc(v11);
    end;

    if v9 > match_length then
    begin
      match_length := v9;
      match_position := v21;
      if v9 >= 18 then
        Break;
    end;
  end;

  (dad + a1)^ := (dad + v21)^;
  (lson + a1)^ := (lson + v21)^;
  (rson + a1)^ := (rson + v21)^;

  (dad + (lson + v21)^)^ := a1;
  (dad + (rson + v21)^)^ := a1;

  if (rson + (dad + v21)^)^ = v21 then
    (rson + (dad + v21)^)^ := a1
  else
    (lson + (dad + v21)^)^ := a1;

  (dad + v21)^ := 4096;
end;

procedure DeleteNode(a1: Integer);
var
  v5: Integer;
begin
  if (dad + a1)^ <> 4096 then
  begin
    if (rson + a1)^ = 4096 then
      v5 := (lson + a1)^
    else if (lson + a1)^ = 4096 then
      v5 := (rson + a1)^
    else
    begin
      v5 := (lson + a1)^;

      if (rson + v5)^ <> 4096 then
      begin
        repeat
          v5 := (rson + v5)^;
        until (rson + v5)^ = 4096;

        (rson + (dad + v5)^)^ := (lson + v5)^;
        (dad + (lson + v5)^)^ := (dad + v5)^;
        (lson + v5)^ := (lson + a1)^;
        (dad + (lson + a1)^)^ := v5;
      end;

      (rson + v5)^ := (rson + a1)^;
      (dad + (rson + a1)^)^ := v5;
    end;

    (dad + v5)^ := (dad + a1)^;

    if (rson + (dad + a1)^)^ = a1 then
      (rson + (dad + a1)^)^ := v5
    else
      (lson + (dad + a1)^)^ := v5;

    (dad + a1)^ := 4096;
  end;
end;

function DecodeLZS(src, dest: PByte; length: Integer): Integer;
var
  v8, v21, index, v10, v11, v16, v17: Integer;
  ch: Byte;
  srcPtr, destPtr: PByte;
begin
  text_buf := PByte(mem_malloc(SizeOf(Byte) * 4122));
  if text_buf = nil then
  begin
    debug_printf(#10'GRAPHLIB: Error allocating decompression buffer!'#10);
    Exit(-1);
  end;

  v8 := 4078;
  FillChar(text_buf^, v8, Ord(' '));

  v21 := 0;
  index := 0;
  srcPtr := src;
  destPtr := dest;

  while index < length do
  begin
    v21 := v21 shr 1;
    if (v21 and $100) = 0 then
    begin
      v21 := srcPtr^;
      Inc(srcPtr);
      v21 := v21 or $FF00;
    end;

    if (v21 and $01) = 0 then
    begin
      v10 := srcPtr^;
      Inc(srcPtr);
      v11 := srcPtr^;
      Inc(srcPtr);

      v10 := v10 or ((v11 and $F0) shl 4);
      v11 := (v11 and $0F) + 2;

      for v16 := 0 to v11 do
      begin
        v17 := (v10 + v16) and $FFF;

        ch := (text_buf + v17)^;
        (text_buf + v8)^ := ch;
        destPtr^ := ch;
        Inc(destPtr);

        v8 := (v8 + 1) and $FFF;

        Inc(index);
        if index >= length then
          Break;
      end;
    end
    else
    begin
      ch := srcPtr^;
      Inc(srcPtr);
      (text_buf + v8)^ := ch;
      destPtr^ := ch;
      Inc(destPtr);

      v8 := (v8 + 1) and $FFF;

      Inc(index);
    end;
  end;

  mem_free(text_buf);

  Result := 0;
end;

procedure InitGreyTable(a1, a2: Integer);
var
  index: Integer;
  v1_r, v1_g, v1_b: Integer;
  v1_max, v1_min, v3, v4: Integer;
  paletteIndex: Integer;
  rgb: Integer;
begin
  if (a1 >= 0) and (a2 <= 255) then
  begin
    for index := a1 to a2 do
    begin
      rgb := Color2RGB(index);
      v1_r := (rgb and $7C00) shr 10;
      v1_g := (rgb and $3E0) shr 5;
      v1_b := rgb and $1F;

      // max
      v1_max := v1_g;
      if v1_r > v1_max then v1_max := v1_r;
      if v1_b > v1_max then v1_max := v1_b;

      // min
      v1_min := v1_g;
      if v1_r < v1_min then v1_min := v1_r;
      if v1_b < v1_min then v1_min := v1_b;

      v3 := v1_max + v1_min;
      v4 := Trunc(v3 * 240.0 / 510.0);

      paletteIndex := ((v4 and $FF) shl 10) or ((v4 and $FF) shl 5) or (v4 and $FF);
      GreyTable[index] := colorTable[paletteIndex];
    end;
  end;
end;

procedure grey_buf(surface: PByte; width, height, pitch: Integer);
var
  ptr: PByte;
  skip, x, y: Integer;
begin
  ptr := surface;
  skip := pitch - width;

  for y := 0 to height - 1 do
  begin
    for x := 0 to width - 1 do
    begin
      ptr^ := GreyTable[ptr^];
      Inc(ptr);
    end;
    ptr := ptr + skip;
  end;
end;

end.
