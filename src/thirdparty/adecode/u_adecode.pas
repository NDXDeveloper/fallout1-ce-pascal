{$MODE OBJFPC}{$H+}
{$POINTERMATH ON}
// Converted from: third_party/adecode (https://github.com/alexbatalov/adecode)
// ACM audio decoder library - Interplay ACM format.
unit u_adecode;

interface

type
  PAudioDecoder = Pointer;

  TAudioDecoderReadFunc = function(Data: Pointer; Buf: Pointer; Size: LongWord): LongWord; cdecl;

function Create_AudioDecoder(ReadFunc: TAudioDecoderReadFunc; Data: Pointer;
  Channels: PInteger; SampleRate: PInteger; SampleCount: PInteger): PAudioDecoder;
function AudioDecoder_Read(Decoder: PAudioDecoder; Buf: Pointer; Count: Integer): Integer;
procedure AudioDecoder_Close(Decoder: PAudioDecoder);

implementation

const
  ACM_BUFFER_SIZE  = 512;
  ACM_FILE_ID      = $32897;
  ACM_FILE_VERSION = 1;

type
  TByteReader = record
    ReadFunc: TAudioDecoderReadFunc;
    Data: Pointer;
    Buf: PByte;
    BufSize: Integer;
    BufPtr: PByte;
    BufCnt: Integer;
  end;

  TBitReader = record
    Bytes: TByteReader;
    Data: LongWord;
    BitCnt: Integer;
  end;

  PAudioDecoderRec = ^TAudioDecoderRec;
  TAudioDecoderRec = record
    Bits: TBitReader;
    Levels: Integer;
    Subbands: Integer;
    SamplesPerSubband: Integer;
    TotalSamples: Integer;
    PrevSamples: PInteger;
    Samples: PInteger;
    BlockSamplesPerSubband: Integer;
    BlockTotalSamples: Integer;
    Chans: Integer;
    Rate: Integer;
    FileCnt: Integer;
    SampPtr: PInteger;
    SampCnt: Integer;
  end;

var
  gDecoderCnt: Integer = 0;
  gScaleTbl: PSmallInt = nil;
  gScale0: PSmallInt = nil;
  gPackInited: Boolean = False;
  pack11_2: array[0..127] of Byte;
  pack3_3: array[0..31] of Byte;
  pack5_3: array[0..127] of SmallInt;

// ---------------------------------------------------------------------------
// Byte reader
// ---------------------------------------------------------------------------

function bytes_init(var br: TByteReader; rf: TAudioDecoderReadFunc; d: Pointer): Boolean;
begin
  br.ReadFunc := rf;
  br.Data := d;
  br.Buf := GetMem(ACM_BUFFER_SIZE);
  if br.Buf = nil then
    Exit(False);
  br.BufSize := ACM_BUFFER_SIZE;
  br.BufCnt := 0;
  Result := True;
end;

function ByteReaderFill(var br: TByteReader): Byte;
begin
  br.BufCnt := br.ReadFunc(br.Data, br.Buf, br.BufSize);
  if br.BufCnt = 0 then
  begin
    FillByte(br.Buf^, br.BufSize, 0);
    br.BufCnt := br.BufSize;
  end;
  br.BufPtr := br.Buf;
  Dec(br.BufCnt);
  Result := br.BufPtr^;
  Inc(br.BufPtr);
end;

// ---------------------------------------------------------------------------
// Bit reader
// ---------------------------------------------------------------------------

function bits_init(var bits: TBitReader; rf: TAudioDecoderReadFunc; d: Pointer): Boolean;
begin
  if not bytes_init(bits.Bytes, rf, d) then
    Exit(False);
  bits.Data := 0;
  bits.BitCnt := 0;
  Result := True;
end;

procedure requireBits(ad: PAudioDecoderRec; n: Integer); inline;
var
  b: Byte;
begin
  while ad^.Bits.BitCnt < n do
  begin
    Dec(ad^.Bits.Bytes.BufCnt);
    if ad^.Bits.Bytes.BufCnt < 0 then
      b := ByteReaderFill(ad^.Bits.Bytes)
    else
    begin
      b := ad^.Bits.Bytes.BufPtr^;
      Inc(ad^.Bits.Bytes.BufPtr);
    end;
    ad^.Bits.Data := ad^.Bits.Data or (LongWord(b) shl ad^.Bits.BitCnt);
    Inc(ad^.Bits.BitCnt, 8);
  end;
end;

function takeBits(ad: PAudioDecoderRec; n: Integer): LongWord; inline;
begin
  Result := ad^.Bits.Data and ((LongWord(1) shl n) - 1);
end;

procedure dropBits(ad: PAudioDecoderRec; n: Integer); inline;
begin
  ad^.Bits.Data := ad^.Bits.Data shr n;
  Dec(ad^.Bits.BitCnt, n);
end;

// ---------------------------------------------------------------------------
// Pack tables
// ---------------------------------------------------------------------------

procedure init_pack_tables;
var
  i, j, m: Integer;
begin
  if gPackInited then
    Exit;

  for i := 0 to 2 do
    for j := 0 to 2 do
      for m := 0 to 2 do
        pack3_3[i + j * 3 + m * 9] := i + j * 4 + m * 16;

  for i := 0 to 4 do
    for j := 0 to 4 do
      for m := 0 to 4 do
        pack5_3[i + j * 5 + m * 25] := i + j * 8 + m * 64;

  for i := 0 to 10 do
    for j := 0 to 10 do
      pack11_2[i + j * 11] := i + j * 16;

  gPackInited := True;
end;

// ---------------------------------------------------------------------------
// ReadBand functions
// ---------------------------------------------------------------------------

function ReadBand_Fmt0(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  i: Integer;
begin
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    dst^ := 0;
    Inc(dst, ad^.Subbands);
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt3_16(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0 + (-(1 shl (n - 1)));
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, n);
    value := Integer(takeBits(ad, n));
    dropBits(ad, n);
    dst^ := scale[value];
    Inc(dst, ad^.Subbands);
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt17(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 3);
    value := Integer(takeBits(ad, 3));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
      if i = 0 then
        Break;
      dst^ := 0;
      Inc(dst, ad^.Subbands);
    end
    else if (value and $02) = 0 then
    begin
      dropBits(ad, 2);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
    end
    else
    begin
      dropBits(ad, 3);
      if (value and $04) <> 0 then
        dst^ := scale[1]
      else
        dst^ := scale[-1];
      Inc(dst, ad^.Subbands);
    end;
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt18(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 2);
    value := Integer(takeBits(ad, 2));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
    end
    else
    begin
      dropBits(ad, 2);
      if (value and $02) <> 0 then
        dst^ := scale[1]
      else
        dst^ := scale[-1];
      Inc(dst, ad^.Subbands);
    end;
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt19(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
  code: Byte;
begin
  scale := gScale0 + (-1);
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 5);
    value := Integer(takeBits(ad, 5));
    dropBits(ad, 5);
    code := pack3_3[value];
    dst^ := scale[code and $03];
    Inc(dst, ad^.Subbands);
    Dec(i);
    if i = 0 then Break;
    dst^ := scale[(code shr 2) and $03];
    Inc(dst, ad^.Subbands);
    Dec(i);
    if i = 0 then Break;
    dst^ := scale[code shr 4];
    Inc(dst, ad^.Subbands);
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt20(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 4);
    value := Integer(takeBits(ad, 4));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
      if i = 0 then Break;
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else if (value and $02) = 0 then
    begin
      dropBits(ad, 2);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 4);
      if (value and $08) <> 0 then
      begin
        if (value and $04) <> 0 then
          dst^ := scale[2]
        else
          dst^ := scale[1];
      end
      else
      begin
        if (value and $04) <> 0 then
          dst^ := scale[-1]
        else
          dst^ := scale[-2];
      end;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt21(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 3);
    value := Integer(takeBits(ad, 3));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 3);
      if (value and $04) <> 0 then
      begin
        if (value and $02) <> 0 then
          dst^ := scale[2]
        else
          dst^ := scale[1];
      end
      else
      begin
        if (value and $02) <> 0 then
          dst^ := scale[-1]
        else
          dst^ := scale[-2];
      end;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt22(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
  code: Word;
begin
  scale := gScale0 + (-2);
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 7);
    value := Integer(takeBits(ad, 7));
    dropBits(ad, 7);
    code := pack5_3[value];
    dst^ := scale[code and 7];
    Inc(dst, ad^.Subbands);
    Dec(i);
    if i = 0 then Break;
    dst^ := scale[(code shr 3) and 7];
    Inc(dst, ad^.Subbands);
    Dec(i);
    if i = 0 then Break;
    dst^ := scale[code shr 6];
    Inc(dst, ad^.Subbands);
    Dec(i);
  end;
  Result := True;
end;

function ReadBand_Fmt23(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 5);
    value := Integer(takeBits(ad, 5));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
      if i = 0 then Break;
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else if (value and $02) = 0 then
    begin
      dropBits(ad, 2);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else if (value and $04) = 0 then
    begin
      dropBits(ad, 4);
      if (value and $08) <> 0 then
        dst^ := scale[1]
      else
        dst^ := scale[-1];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 5);
      value := (value shr 3) and $03;
      if value > 1 then
        Inc(value, 3);
      dst^ := scale[value - 3];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt24(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 4);
    value := Integer(takeBits(ad, 4));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else if (value and $02) = 0 then
    begin
      dropBits(ad, 3);
      if (value and $04) <> 0 then
        dst^ := scale[1]
      else
        dst^ := scale[-1];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 4);
      value := (value shr 2) and $03;
      if value > 1 then
        Inc(value, 3);
      dst^ := scale[value - 3];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt26(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 5);
    value := Integer(takeBits(ad, 5));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
      if i = 0 then Break;
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else if (value and $02) = 0 then
    begin
      dropBits(ad, 2);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 5);
      value := (value shr 2) and $07;
      if value > 3 then
        Inc(value, 1);
      dst^ := scale[value - 4];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt27(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 4);
    value := Integer(takeBits(ad, 4));
    if (value and $01) = 0 then
    begin
      dropBits(ad, 1);
      dst^ := 0;
      Inc(dst, ad^.Subbands);
      Dec(i);
    end
    else
    begin
      dropBits(ad, 4);
      value := (value shr 1) and $07;
      if value > 3 then
        Inc(value, 1);
      dst^ := scale[value - 4];
      Inc(dst, ad^.Subbands);
      Dec(i);
    end;
  end;
  Result := True;
end;

function ReadBand_Fmt29(ad: PAudioDecoderRec; subband, n: Integer): Boolean;
var
  dst: PInteger;
  scale: PSmallInt;
  value: Integer;
  i: Integer;
  code: Byte;
begin
  scale := gScale0;
  dst := ad^.Samples + subband;
  i := ad^.SamplesPerSubband;
  while i <> 0 do
  begin
    requireBits(ad, 7);
    value := Integer(takeBits(ad, 7));
    dropBits(ad, 7);
    code := pack11_2[value];
    dst^ := scale[Integer(code and $0F) - 5];
    Inc(dst, ad^.Subbands);
    Dec(i);
    if i = 0 then Break;
    dst^ := scale[Integer(code shr 4) - 5];
    Inc(dst, ad^.Subbands);
    Dec(i);
  end;
  Result := True;
end;

// ---------------------------------------------------------------------------
// ReadBands - reads all subbands for one block
// ---------------------------------------------------------------------------

function ReadBands(ad: PAudioDecoderRec): Boolean;
var
  bits: Integer;
  scaleStep: SmallInt;
  scale: PSmallInt;
  sum: Integer;
  i, n: Integer;
begin
  requireBits(ad, 4);
  bits := 1 shl Integer(takeBits(ad, 4));
  dropBits(ad, 4);

  requireBits(ad, 16);
  scaleStep := SmallInt(takeBits(ad, 16));
  dropBits(ad, 16);

  // Fill positive scale values: scale0[0..bits-1]
  scale := gScale0;
  i := bits;
  sum := 0;
  while i <> 0 do
  begin
    scale^ := SmallInt(sum);
    Inc(scale);
    Inc(sum, scaleStep);
    Dec(i);
  end;

  // Fill negative scale values: scale0[-1..-bits]
  scale := gScale0 + (-1);
  i := bits;
  sum := -scaleStep;
  while i <> 0 do
  begin
    scale^ := SmallInt(sum);
    Dec(scale);
    Dec(sum, scaleStep);
    Dec(i);
  end;

  init_pack_tables;

  for i := 0 to ad^.Subbands - 1 do
  begin
    requireBits(ad, 5);
    n := Integer(takeBits(ad, 5));
    dropBits(ad, 5);

    case n of
      0:     if not ReadBand_Fmt0(ad, i, n) then Exit(False);
      3..16: if not ReadBand_Fmt3_16(ad, i, n) then Exit(False);
      17:    if not ReadBand_Fmt17(ad, i, n) then Exit(False);
      18:    if not ReadBand_Fmt18(ad, i, n) then Exit(False);
      19:    if not ReadBand_Fmt19(ad, i, n) then Exit(False);
      20:    if not ReadBand_Fmt20(ad, i, n) then Exit(False);
      21:    if not ReadBand_Fmt21(ad, i, n) then Exit(False);
      22:    if not ReadBand_Fmt22(ad, i, n) then Exit(False);
      23:    if not ReadBand_Fmt23(ad, i, n) then Exit(False);
      24:    if not ReadBand_Fmt24(ad, i, n) then Exit(False);
      26:    if not ReadBand_Fmt26(ad, i, n) then Exit(False);
      27:    if not ReadBand_Fmt27(ad, i, n) then Exit(False);
      29:    if not ReadBand_Fmt29(ad, i, n) then Exit(False);
    else
      Exit(False);
    end;
  end;

  Result := True;
end;

// ---------------------------------------------------------------------------
// Untransform (inverse subband synthesis)
// ---------------------------------------------------------------------------

procedure untransform_subband0(prv: PSmallInt; buf: PInteger; step, count: Integer);
var
  i: Integer;
  h1, h2, l1, l2: Integer;
  c: Integer;
  b: PInteger;
begin
  if count = 2 then
  begin
    for i := step downto 1 do
    begin
      l2 := prv[0];
      h2 := prv[1];
      l1 := buf[0];
      buf[0] := 2 * h2 + l2 + l1;
      h1 := buf[step];
      buf[step] := 2 * l1 - h2 - h1;
      prv[0] := SmallInt(l1);
      prv[1] := SmallInt(h1);
      Inc(prv, 2);
      Inc(buf);
    end;
  end
  else if count = 4 then
  begin
    for i := step downto 1 do
    begin
      l1 := prv[0];
      h1 := prv[1];
      l2 := buf[0];
      buf[0] := 2 * h1 + l1 + l2;
      h2 := buf[step];
      buf[step] := 2 * l2 - h1 - h2;
      l1 := buf[step * 2];
      buf[step * 2] := 2 * h2 + l2 + l1;
      h1 := buf[step * 3];
      buf[step * 3] := 2 * l1 - h2 - h1;
      prv[0] := SmallInt(l1);
      prv[1] := SmallInt(h1);
      Inc(prv, 2);
      Inc(buf);
    end;
  end
  else
  begin
    for i := step downto 1 do
    begin
      c := count shr 2;
      b := buf;

      if (count and 2) <> 0 then
      begin
        l2 := prv[0];
        h2 := prv[1];
        l1 := buf[0];
        buf[0] := 2 * h2 + l2 + l1;
        h1 := buf[step];
        buf[step] := 2 * l2 - h2 - h1;
      end
      else
      begin
        l1 := prv[0];
        h1 := prv[1];
      end;

      while c <> 0 do
      begin
        l2 := b[0];
        b[0] := 2 * h1 + l1 + l2;
        h2 := b[step];
        b[step] := 2 * l2 - h1 - h2;
        l1 := b[step * 2];
        b[step * 2] := 2 * h2 + l2 + l1;
        h1 := b[step * 3];
        b[step * 3] := 2 * l1 - h2 - h1;
        Inc(b, step * 4);
        Dec(c);
      end;

      prv[0] := SmallInt(l1);
      prv[1] := SmallInt(h1);
      Inc(prv, 2);
      Inc(buf);
    end;
  end;
end;

procedure untransform_subband(prv: PInteger; buf: PInteger; step, count: Integer);
var
  i: Integer;
  h1, h2, l1, l2: Integer;
  c: Integer;
  b: PInteger;
begin
  if count = 4 then
  begin
    for i := step downto 1 do
    begin
      l1 := prv[0];
      h1 := prv[1];
      l2 := buf[0];
      buf[0] := 2 * h1 + l1 + l2;
      h2 := buf[step];
      buf[step] := 2 * l2 - h1 - h2;
      l1 := buf[step * 2];
      buf[step * 2] := 2 * h2 + l2 + l1;
      h1 := buf[step * 3];
      buf[step * 3] := 2 * l1 - h2 - h1;
      prv[0] := l1;
      prv[1] := h1;
      Inc(prv, 2);
      Inc(buf);
    end;
  end
  else
  begin
    for i := step downto 1 do
    begin
      c := count shr 2;
      b := buf;
      l1 := prv[0];
      h1 := prv[1];

      while c <> 0 do
      begin
        l2 := b[0];
        b[0] := 2 * h1 + l1 + l2;
        h2 := b[step];
        b[step] := 2 * l2 - h1 - h2;
        l1 := b[step * 2];
        b[step * 2] := 2 * h2 + l2 + l1;
        h1 := b[step * 3];
        b[step * 3] := 2 * l1 - h2 - h1;
        Inc(b, step * 4);
        Dec(c);
      end;

      prv[0] := l1;
      prv[1] := h1;
      Inc(prv, 2);
      Inc(buf);
    end;
  end;
end;

procedure untransform_all(ad: PAudioDecoderRec);
var
  remSamplesPerSubband: Integer;
  bufBase: PInteger;
  step, count: Integer;
  prv: PInteger;
  i: Integer;
  buf: PInteger;
begin
  if ad^.Levels = 0 then
    Exit;

  bufBase := ad^.Samples;
  remSamplesPerSubband := ad^.SamplesPerSubband;

  while remSamplesPerSubband > 0 do
  begin
    step := ad^.Subbands shr 1;
    count := ad^.BlockSamplesPerSubband;
    if count > remSamplesPerSubband then
      count := remSamplesPerSubband;
    count := count * 2;

    untransform_subband0(PSmallInt(ad^.PrevSamples), bufBase, step, count);

    buf := bufBase;
    prv := ad^.PrevSamples + step;

    for i := 0 to count - 1 do
    begin
      buf^ := buf^ + 1;
      Inc(buf, step);
    end;

    step := step shr 1;
    count := count * 2;

    while step <> 0 do
    begin
      untransform_subband(prv, bufBase, step, count);
      Inc(prv, step * 2);
      count := count * 2;
      step := step shr 1;
    end;

    Inc(bufBase, ad^.BlockTotalSamples);
    Dec(remSamplesPerSubband, ad^.BlockSamplesPerSubband);
  end;
end;

// ---------------------------------------------------------------------------
// AudioDecoder_fill - decode one block of samples
// ---------------------------------------------------------------------------

function AudioDecoder_fill(ad: PAudioDecoderRec): Boolean;
begin
  if not ReadBands(ad) then
    Exit(False);

  untransform_all(ad);

  Dec(ad^.FileCnt, ad^.TotalSamples);
  ad^.SampPtr := ad^.Samples;
  ad^.SampCnt := ad^.TotalSamples;

  if ad^.FileCnt < 0 then
  begin
    Inc(ad^.SampCnt, ad^.FileCnt);
    ad^.FileCnt := 0;
  end;

  Result := True;
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function AudioDecoder_Read(Decoder: PAudioDecoder; Buf: Pointer; Count: Integer): Integer;
var
  ad: PAudioDecoderRec;
  dst: PWord;
  sampPtr: PInteger;
  sampCnt: Integer;
  i: LongWord;
begin
  ad := PAudioDecoderRec(Decoder);
  dst := PWord(Buf);
  sampPtr := ad^.SampPtr;
  sampCnt := ad^.SampCnt;
  i := 0;

  while i < LongWord(Count) do
  begin
    if sampCnt = 0 then
    begin
      if ad^.FileCnt = 0 then
        Break;
      if not AudioDecoder_fill(ad) then
        Break;
      sampPtr := ad^.SampPtr;
      sampCnt := ad^.SampCnt;
    end;

    dst^ := Word(sampPtr^ shr ad^.Levels);
    Inc(dst);
    Inc(sampPtr);
    Dec(sampCnt);
    Inc(i, 2);
  end;

  ad^.SampPtr := sampPtr;
  ad^.SampCnt := sampCnt;
  Result := Integer(i);
end;

procedure AudioDecoder_Close(Decoder: PAudioDecoder);
var
  ad: PAudioDecoderRec;
begin
  ad := PAudioDecoderRec(Decoder);

  if ad^.Bits.Bytes.Buf <> nil then
    FreeMem(ad^.Bits.Bytes.Buf);

  if ad^.PrevSamples <> nil then
    FreeMem(ad^.PrevSamples);

  if ad^.Samples <> nil then
    FreeMem(ad^.Samples);

  FreeMem(ad);

  Dec(gDecoderCnt);

  if gDecoderCnt = 0 then
  begin
    if gScaleTbl <> nil then
    begin
      FreeMem(gScaleTbl);
      gScaleTbl := nil;
    end;
  end;
end;

function Create_AudioDecoder(ReadFunc: TAudioDecoderReadFunc; Data: Pointer;
  Channels: PInteger; SampleRate: PInteger; SampleCount: PInteger): PAudioDecoder;
var
  ad: PAudioDecoderRec;
  tmp: LongWord;
  prevLen: Integer;
begin
  ad := GetMem(SizeOf(TAudioDecoderRec));
  if ad = nil then
    Exit(nil);

  FillByte(ad^, SizeOf(TAudioDecoderRec), 0);
  Inc(gDecoderCnt);

  // Initialize bit reader
  if not bits_init(ad^.Bits, ReadFunc, Data) then
  begin
    AudioDecoder_Close(ad);
    Channels^ := 0;
    SampleRate^ := 0;
    SampleCount^ := 0;
    Exit(nil);
  end;

  // Read file ID (24 bits)
  requireBits(ad, 24);
  tmp := takeBits(ad, 24);
  dropBits(ad, 24);

  if tmp <> ACM_FILE_ID then
  begin
    AudioDecoder_Close(ad);
    Channels^ := 0;
    SampleRate^ := 0;
    SampleCount^ := 0;
    Exit(nil);
  end;

  // Read version (8 bits)
  requireBits(ad, 8);
  tmp := takeBits(ad, 8);
  dropBits(ad, 8);

  if tmp <> ACM_FILE_VERSION then
  begin
    AudioDecoder_Close(ad);
    Channels^ := 0;
    SampleRate^ := 0;
    SampleCount^ := 0;
    Exit(nil);
  end;

  // Read sample count (32 bits in two 16-bit reads)
  requireBits(ad, 16);
  ad^.FileCnt := Integer(takeBits(ad, 16));
  dropBits(ad, 16);

  requireBits(ad, 16);
  ad^.FileCnt := Integer(LongWord(ad^.FileCnt) or (takeBits(ad, 16) shl 16));
  dropBits(ad, 16);

  // Read channels (16 bits)
  requireBits(ad, 16);
  ad^.Chans := Integer(takeBits(ad, 16));
  dropBits(ad, 16);

  // Read sample rate (16 bits)
  requireBits(ad, 16);
  ad^.Rate := Integer(takeBits(ad, 16));
  dropBits(ad, 16);

  // Read levels (4 bits) and samples per subband (12 bits)
  requireBits(ad, 4);
  ad^.Levels := Integer(takeBits(ad, 4));
  dropBits(ad, 4);

  requireBits(ad, 12);
  ad^.Subbands := 1 shl ad^.Levels;
  ad^.SamplesPerSubband := Integer(takeBits(ad, 12));
  ad^.TotalSamples := ad^.SamplesPerSubband * ad^.Subbands;
  dropBits(ad, 12);

  if ad^.Levels <> 0 then
    prevLen := 3 * ad^.Subbands div 2 - 2
  else
    prevLen := 0;

  ad^.BlockSamplesPerSubband := 2048 div ad^.Subbands - 2;
  if ad^.BlockSamplesPerSubband < 1 then
    ad^.BlockSamplesPerSubband := 1;

  ad^.BlockTotalSamples := ad^.BlockSamplesPerSubband * ad^.Subbands;

  // Allocate prev_samples
  if prevLen <> 0 then
  begin
    ad^.PrevSamples := GetMem(SizeOf(Integer) * prevLen);
    if ad^.PrevSamples = nil then
    begin
      AudioDecoder_Close(ad);
      Channels^ := 0;
      SampleRate^ := 0;
      SampleCount^ := 0;
      Exit(nil);
    end;
    FillByte(ad^.PrevSamples^, SizeOf(Integer) * prevLen, 0);
  end;

  // Allocate samples
  ad^.Samples := GetMem(SizeOf(Integer) * ad^.TotalSamples);
  if ad^.Samples = nil then
  begin
    AudioDecoder_Close(ad);
    Channels^ := 0;
    SampleRate^ := 0;
    SampleCount^ := 0;
    Exit(nil);
  end;

  ad^.SampCnt := 0;

  // Allocate shared scale table (first decoder only)
  if gDecoderCnt = 1 then
  begin
    gScaleTbl := GetMem(SizeOf(SmallInt) * $8000 * 2);
    gScale0 := gScaleTbl + $8000;
  end;

  Channels^ := ad^.Chans;
  SampleRate^ := ad^.Rate;
  SampleCount^ := ad^.FileCnt;

  Result := ad;
end;

end.
