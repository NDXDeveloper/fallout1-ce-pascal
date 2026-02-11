{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/grbuf.h + grbuf.cc
// Graphics buffer operations: line drawing, scaling, blitting, fills.
unit u_grbuf;

interface

procedure draw_line(buf: PByte; pitch, left, top, right, bottom, color: Integer);
procedure draw_box(buf: PByte; pitch, left, top, right, bottom, color: Integer);
procedure draw_shaded_box(buf: PByte; pitch, left, top, right, bottom, color1, color2: Integer);
procedure cscale(src: PByte; srcWidth, srcHeight, srcPitch: Integer;
  dest: PByte; destWidth, destHeight, destPitch: Integer);
procedure trans_cscale(src: PByte; srcWidth, srcHeight, srcPitch: Integer;
  dest: PByte; destWidth, destHeight, destPitch: Integer);
procedure buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  dest: PByte; destPitch: Integer);
procedure trans_buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  dest: PByte; destPitch: Integer);
procedure mask_buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  mask: PByte; maskPitch: Integer; dest: PByte; destPitch: Integer);
procedure buf_fill(buf: PByte; width, height, pitch, color: Integer);
procedure buf_texture(buf: PByte; width, height, pitch: Integer;
  texture: Pointer; texWidth, texHeight: Integer);
procedure lighten_buf(buf: PByte; width, height, pitch: Integer);
procedure swap_color_buf(buf: PByte; width, height, pitch, color1, color2: Integer);
procedure buf_outline(buf: PByte; width, height, pitch, color: Integer);
procedure srcCopy(dest: PByte; destPitch: Integer; src: PByte; srcPitch, width, height: Integer);
procedure transSrcCopy(dest: PByte; destPitch: Integer; src: PByte; srcPitch, width, height: Integer);

implementation

uses
  u_color;

procedure draw_line(buf: PByte; pitch, left, top, right, bottom, color: Integer);
var
  dx, dy, sx, sy, err, e2: Integer;
begin
  dx := Abs(right - left);
  dy := Abs(bottom - top);
  if left < right then sx := 1 else sx := -1;
  if top < bottom then sy := 1 else sy := -1;
  err := dx - dy;

  while True do
  begin
    buf[top * pitch + left] := Byte(color);
    if (left = right) and (top = bottom) then
      Break;
    e2 := 2 * err;
    if e2 > -dy then
    begin
      err := err - dy;
      left := left + sx;
    end;
    if e2 < dx then
    begin
      err := err + dx;
      top := top + sy;
    end;
  end;
end;

procedure draw_box(buf: PByte; pitch, left, top, right, bottom, color: Integer);
begin
  draw_line(buf, pitch, left, top, right, top, color);
  draw_line(buf, pitch, right, top, right, bottom, color);
  draw_line(buf, pitch, left, bottom, right, bottom, color);
  draw_line(buf, pitch, left, top, left, bottom, color);
end;

procedure draw_shaded_box(buf: PByte; pitch, left, top, right, bottom, color1, color2: Integer);
begin
  draw_line(buf, pitch, left, top, right, top, color1);
  draw_line(buf, pitch, left, top, left, bottom, color1);
  draw_line(buf, pitch, right, top, right, bottom, color2);
  draw_line(buf, pitch, left, bottom, right, bottom, color2);
end;

procedure cscale(src: PByte; srcWidth, srcHeight, srcPitch: Integer;
  dest: PByte; destWidth, destHeight, destPitch: Integer);
var
  xRatio, yRatio: Integer;
  srcX, srcY: Integer;
  dx, dy: Integer;
begin
  if (destWidth = 0) or (destHeight = 0) then Exit;
  xRatio := (srcWidth shl 16) div destWidth;
  yRatio := (srcHeight shl 16) div destHeight;
  srcY := 0;
  for dy := 0 to destHeight - 1 do
  begin
    srcX := 0;
    for dx := 0 to destWidth - 1 do
    begin
      dest[dy * destPitch + dx] := src[(srcY shr 16) * srcPitch + (srcX shr 16)];
      srcX := srcX + xRatio;
    end;
    srcY := srcY + yRatio;
  end;
end;

procedure trans_cscale(src: PByte; srcWidth, srcHeight, srcPitch: Integer;
  dest: PByte; destWidth, destHeight, destPitch: Integer);
var
  xRatio, yRatio: Integer;
  srcX, srcY: Integer;
  dx, dy: Integer;
  pixel: Byte;
begin
  if (destWidth = 0) or (destHeight = 0) then Exit;
  xRatio := (srcWidth shl 16) div destWidth;
  yRatio := (srcHeight shl 16) div destHeight;
  srcY := 0;
  for dy := 0 to destHeight - 1 do
  begin
    srcX := 0;
    for dx := 0 to destWidth - 1 do
    begin
      pixel := src[(srcY shr 16) * srcPitch + (srcX shr 16)];
      if pixel <> 0 then
        dest[dy * destPitch + dx] := pixel;
      srcX := srcX + xRatio;
    end;
    srcY := srcY + yRatio;
  end;
end;

procedure buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  dest: PByte; destPitch: Integer);
var
  y: Integer;
begin
  for y := 0 to height - 1 do
    Move(src[y * srcPitch], dest[y * destPitch], width);
end;

procedure trans_buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  dest: PByte; destPitch: Integer);
var
  x, y: Integer;
  pixel: Byte;
begin
  for y := 0 to height - 1 do
    for x := 0 to width - 1 do
    begin
      pixel := src[y * srcPitch + x];
      if pixel <> 0 then
        dest[y * destPitch + x] := pixel;
    end;
end;

procedure mask_buf_to_buf(src: PByte; width, height, srcPitch: Integer;
  mask: PByte; maskPitch: Integer; dest: PByte; destPitch: Integer);
var
  x, y: Integer;
begin
  for y := 0 to height - 1 do
    for x := 0 to width - 1 do
      if mask[y * maskPitch + x] <> 0 then
        dest[y * destPitch + x] := src[y * srcPitch + x];
end;

procedure buf_fill(buf: PByte; width, height, pitch, color: Integer);
var
  y: Integer;
begin
  for y := 0 to height - 1 do
    FillByte(buf[y * pitch], width, Byte(color));
end;

procedure buf_texture(buf: PByte; width, height, pitch: Integer;
  texture: Pointer; texWidth, texHeight: Integer);
var
  texBuf: PByte;
  x, y: Integer;
begin
  texBuf := PByte(texture);
  if texBuf = nil then Exit;
  for y := 0 to height - 1 do
    for x := 0 to width - 1 do
      buf[y * pitch + x] := texBuf[(y mod texHeight) * texWidth + (x mod texWidth)];
end;

procedure lighten_buf(buf: PByte; width, height, pitch: Integer);
var
  skip, x, y: Integer;
begin
  skip := pitch - width;
  for y := 0 to height - 1 do
  begin
    for x := 0 to width - 1 do
    begin
      buf^ := intensityColorTable[buf^][147];
      Inc(buf);
    end;
    Inc(buf, skip);
  end;
end;

procedure swap_color_buf(buf: PByte; width, height, pitch, color1, color2: Integer);
var
  x, y: Integer;
begin
  for y := 0 to height - 1 do
    for x := 0 to width - 1 do
    begin
      if buf[y * pitch + x] = Byte(color1) then
        buf[y * pitch + x] := Byte(color2);
    end;
end;

procedure buf_outline(buf: PByte; width, height, pitch, color: Integer);
var
  x, y: Integer;
  p: PByte;
begin
  // Outline non-zero pixels that border zero pixels
  // This is a simplified version
  for y := 0 to height - 1 do
  begin
    p := @buf[y * pitch];
    for x := 0 to width - 1 do
    begin
      if p[x] = 0 then
      begin
        if (x > 0) and (p[x - 1] <> 0) then
          p[x] := Byte(color)
        else if (x < width - 1) and (p[x + 1] <> 0) then
          p[x] := Byte(color)
        else if (y > 0) and (buf[(y - 1) * pitch + x] <> 0) then
          p[x] := Byte(color)
        else if (y < height - 1) and (buf[(y + 1) * pitch + x] <> 0) then
          p[x] := Byte(color);
      end;
    end;
  end;
end;

procedure srcCopy(dest: PByte; destPitch: Integer; src: PByte; srcPitch, width, height: Integer);
var
  y: Integer;
begin
  for y := 0 to height - 1 do
    Move(src[y * srcPitch], dest[y * destPitch], width);
end;

procedure transSrcCopy(dest: PByte; destPitch: Integer; src: PByte; srcPitch, width, height: Integer);
var
  x, y: Integer;
  pixel: Byte;
begin
  for y := 0 to height - 1 do
    for x := 0 to width - 1 do
    begin
      pixel := src[y * srcPitch + x];
      if pixel <> 0 then
        dest[y * destPitch + x] := pixel;
    end;
end;

end.
