{$MODE OBJFPC}{$H+}
// Converted from: src/plib/db/lzss.h + lzss.cc
// LZSS decompression with 4096-byte ring buffer.
unit u_lzss;

interface

function lzss_decode_to_buf(inStream: Pointer; dest: PByte; length_: LongWord): Integer;
procedure lzss_decode_to_file(inStream: Pointer; outStream: Pointer; length_: LongWord);

implementation

// libc imports
function libc_fread(buf: Pointer; size, count: SizeUInt; stream: Pointer): SizeUInt; cdecl; external 'c' name 'fread';
function libc_fputc(c: Integer; stream: Pointer): Integer; cdecl; external 'c' name 'fputc';

var
  decode_buffer: array[0..1023] of Byte;
  decode_buffer_position: PByte;
  decode_bytes_left: LongWord;
  ring_buffer_index: Integer;
  decode_buffer_end: PByte;
  ring_buffer: array[0..4115] of Byte;

procedure lzss_fill_decode_buffer(stream: Pointer);
var
  bytes_to_read, bytes_read: SizeUInt;
  remaining: PtrUInt;
begin
  if (decode_bytes_left <> 0) and ((PtrUInt(decode_buffer_end) - PtrUInt(decode_buffer_position)) <= 16) then
  begin
    if decode_buffer_position = decode_buffer_end then
      decode_buffer_end := @decode_buffer[0]
    else
    begin
      remaining := PtrUInt(decode_buffer_end) - PtrUInt(decode_buffer_position);
      Move(decode_buffer_position^, decode_buffer[0], remaining);
      decode_buffer_end := @decode_buffer[0] + remaining;
    end;

    decode_buffer_position := @decode_buffer[0];

    bytes_to_read := 1024 - (PtrUInt(decode_buffer_end) - PtrUInt(@decode_buffer[0]));
    if bytes_to_read > decode_bytes_left then
      bytes_to_read := decode_bytes_left;

    bytes_read := libc_fread(decode_buffer_end, 1, bytes_to_read, stream);
    decode_buffer_end := decode_buffer_end + bytes_read;
    decode_bytes_left := decode_bytes_left - bytes_read;
  end;
end;

procedure lzss_decode_chunk_to_buf(type_: LongWord; var dest: PByte; var length_: LongWord);
var
  low, high: Byte;
  dict_offset, dict_index, chunk_length, index: Integer;
begin
  if type_ <> 0 then
  begin
    Dec(length_);
    dest^ := decode_buffer_position^;
    ring_buffer[ring_buffer_index] := dest^;
    Inc(decode_buffer_position);
    Inc(dest);
    Inc(ring_buffer_index);
    ring_buffer_index := ring_buffer_index and $FFF;
  end
  else
  begin
    Dec(length_, 2);
    low := decode_buffer_position^;
    Inc(decode_buffer_position);
    high := decode_buffer_position^;
    Inc(decode_buffer_position);
    dict_offset := low or ((high and $F0) shl 4);
    chunk_length := (high and $0F) + 3;

    for index := 0 to chunk_length - 1 do
    begin
      dict_index := (dict_offset + index) and $FFF;
      dest^ := ring_buffer[dict_index];
      ring_buffer[ring_buffer_index] := dest^;
      Inc(dest);
      Inc(ring_buffer_index);
      ring_buffer_index := ring_buffer_index and $FFF;
    end;
  end;
end;

procedure lzss_decode_chunk_to_file(type_: LongWord; stream: Pointer; var length_: LongWord);
var
  low, high: Byte;
  dict_offset, dict_index, chunk_length, index: Integer;
begin
  if type_ <> 0 then
  begin
    Dec(length_);
    libc_fputc(decode_buffer_position^, stream);
    ring_buffer[ring_buffer_index] := decode_buffer_position^;
    Inc(decode_buffer_position);
    Inc(ring_buffer_index);
    ring_buffer_index := ring_buffer_index and $FFF;
  end
  else
  begin
    Dec(length_, 2);
    low := decode_buffer_position^;
    Inc(decode_buffer_position);
    high := decode_buffer_position^;
    Inc(decode_buffer_position);
    dict_offset := low or ((high and $F0) shl 4);
    chunk_length := (high and $0F) + 3;

    for index := 0 to chunk_length - 1 do
    begin
      dict_index := (dict_offset + index) and $FFF;
      libc_fputc(ring_buffer[dict_index], stream);
      ring_buffer[ring_buffer_index] := ring_buffer[dict_index];
      Inc(ring_buffer_index);
      ring_buffer_index := ring_buffer_index and $FFF;
    end;
  end;
end;

function lzss_decode_to_buf(inStream: Pointer; dest: PByte; length_: LongWord): Integer;
var
  curr: PByte;
  b: Byte;
begin
  curr := dest;
  FillByte(ring_buffer, 4078, Ord(' '));
  ring_buffer_index := 4078;
  decode_buffer_end := @decode_buffer[0];
  decode_buffer_position := @decode_buffer[0];
  decode_bytes_left := length_;

  while length_ > 16 do
  begin
    lzss_fill_decode_buffer(inStream);

    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);
    lzss_decode_chunk_to_buf(b and $01, curr, length_);
    lzss_decode_chunk_to_buf(b and $02, curr, length_);
    lzss_decode_chunk_to_buf(b and $04, curr, length_);
    lzss_decode_chunk_to_buf(b and $08, curr, length_);
    lzss_decode_chunk_to_buf(b and $10, curr, length_);
    lzss_decode_chunk_to_buf(b and $20, curr, length_);
    lzss_decode_chunk_to_buf(b and $40, curr, length_);
    lzss_decode_chunk_to_buf(b and $80, curr, length_);
  end;

  // Remaining bytes (do-while(0) pattern from C — handles up to 2 flags bytes)
  repeat
    if length_ = 0 then Break;

    lzss_fill_decode_buffer(inStream);
    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);

    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $01, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $02, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $04, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $08, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $10, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $20, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $40, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $80, curr, length_);

    if length_ = 0 then Break;

    lzss_fill_decode_buffer(inStream);
    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);

    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $01, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $02, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $04, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $08, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $10, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $20, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $40, curr, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_buf(b and $80, curr, length_);
  until True;

  Result := curr - dest;
end;

procedure lzss_decode_to_file(inStream: Pointer; outStream: Pointer; length_: LongWord);
var
  b: Byte;
begin
  FillByte(ring_buffer, 4078, Ord(' '));
  ring_buffer_index := 4078;
  decode_buffer_end := @decode_buffer[0];
  decode_buffer_position := @decode_buffer[0];
  decode_bytes_left := length_;

  while length_ > 16 do
  begin
    lzss_fill_decode_buffer(inStream);

    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);
    lzss_decode_chunk_to_file(b and $01, outStream, length_);
    lzss_decode_chunk_to_file(b and $02, outStream, length_);
    lzss_decode_chunk_to_file(b and $04, outStream, length_);
    lzss_decode_chunk_to_file(b and $08, outStream, length_);
    lzss_decode_chunk_to_file(b and $10, outStream, length_);
    lzss_decode_chunk_to_file(b and $20, outStream, length_);
    lzss_decode_chunk_to_file(b and $40, outStream, length_);
    lzss_decode_chunk_to_file(b and $80, outStream, length_);
  end;

  repeat
    if length_ = 0 then Break;

    lzss_fill_decode_buffer(inStream);
    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);

    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $01, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $02, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $04, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $08, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $10, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $20, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $40, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $80, outStream, length_);

    if length_ = 0 then Break;

    lzss_fill_decode_buffer(inStream);
    Dec(length_);
    b := decode_buffer_position^;
    Inc(decode_buffer_position);

    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $01, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $02, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $04, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $08, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $10, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $20, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $40, outStream, length_);
    if length_ = 0 then Break;
    lzss_decode_chunk_to_file(b and $80, outStream, length_);
  until True;
end;

end.
