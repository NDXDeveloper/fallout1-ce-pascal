{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/lip_sync.h + lip_sync.cc
// Lip sync system: loads and plays phoneme-driven lip animation data for speech.
unit u_lip_sync;

interface

uses
  u_int_sound, u_db;

const
  PHONEME_COUNT = 42;

  // LipsFlags
  LIPS_FLAG_0x01 = $01;
  LIPS_FLAG_0x02 = $02;

type
  PSpeechMarker = ^TSpeechMarker;
  TSpeechMarker = record
    marker: Integer;
    position: Integer;
  end;

  PLipsData = ^TLipsData;
  TLipsData = record
    version: Integer;
    field_4: Integer;
    flags: Integer;
    sound: PSound;
    field_10: Integer;
    field_14: Pointer;
    phonemes: PByte;
    field_1C: Integer;
    field_20: Integer;
    phoneme_count: Integer;
    field_28: Integer;
    marker_count: Integer;
    markers: PSpeechMarker;
    field_34: Integer;
    field_38: Integer;
    field_3C: Integer;
    field_40: Integer;
    field_44: Integer;
    field_48: Integer;
    field_4C: Integer;
    file_name: array[0..7] of AnsiChar;
    field_58: array[0..3] of AnsiChar;
    field_5C: array[0..3] of AnsiChar;
    field_60: array[0..3] of AnsiChar;
    field_64: array[0..259] of AnsiChar;
  end;

var
  // 0x5057E4
  head_phoneme_current: Byte = 0;
  // 0x5057E5
  head_phoneme_drawn: Byte = 0;
  // 0x5057E8
  head_marker_current: Integer = 0;
  // 0x5057EC
  lips_draw_head: Boolean = True;
  // 0x5057F0
  lip_info: TLipsData = (
    version: 2;
    field_4: 22528;
    flags: 0;
    sound: nil;
    field_10: -1;
    field_14: nil;
    phonemes: nil;
    field_1C: 0;
    field_20: 0;
    phoneme_count: 0;
    field_28: 0;
    marker_count: 0;
    markers: nil;
    field_34: 0;
    field_38: 0;
    field_3C: 50;
    field_40: 100;
    field_44: 0;
    field_48: 0;
    field_4C: 0;
    file_name: 'TEST'#0#0#0#0;
    field_58: 'VOC'#0;
    field_5C: 'TXT'#0;
    field_60: 'LIP'#0;
    field_64: (#0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0,
               #0, #0, #0, #0, #0, #0, #0, #0, #0, #0);
  );
  // 0x505958
  speechStartTime: Integer = 0;

procedure lips_bkg_proc;
function lips_play_speech: Integer;
function lips_load_file(const audioFileName: PAnsiChar; const headFileName: PAnsiChar): Integer;
function lips_free_speech: Integer;

implementation

uses
  SysUtils,
  u_platform_compat,
  u_debug,
  u_input,
  u_memory,
  u_int_audio,
  u_gsound;

// Forward declarations
function lips_fix_string(const fileName: PAnsiChar; length_: SizeUInt): PAnsiChar; forward;
function lips_stop_speech: Integer; forward;
function lips_read_phoneme_type(phoneme_type: PByte; stream: PDB_FILE): Integer; forward;
function lips_read_marker_type(marker_type: PSpeechMarker; stream: PDB_FILE): Integer; forward;
function lips_read_lipsynch_info(lipsData: PLipsData; stream: PDB_FILE): Integer; forward;
function lips_make_speech: Integer; forward;

var
  // 0x612220
  lips_subdir_name: array[0..13] of AnsiChar;

  // 0x61222E - static local in lips_fix_string
  lips_fix_string_tmp_str: array[0..49] of AnsiChar;

// 0x46CC30
function lips_fix_string(const fileName: PAnsiChar; length_: SizeUInt): PAnsiChar;
begin
  StrLCopy(@lips_fix_string_tmp_str[0], fileName, length_);
  Result := @lips_fix_string_tmp_str[0];
end;

// 0x46CC48
procedure lips_bkg_proc;
var
  v0: Integer;
  speech_marker: PSpeechMarker;
  v5: Integer;
  v1: Integer;
begin
  v0 := head_marker_current;

  if (lip_info.flags and LIPS_FLAG_0x02) <> 0 then
  begin
    v1 := soundGetPosition(lip_info.sound);

    speech_marker := @lip_info.markers[v0];
    while v1 > speech_marker^.position do
    begin
      head_phoneme_current := lip_info.phonemes[v0];
      Inc(v0);

      if v0 >= lip_info.marker_count then
      begin
        v0 := 0;
        head_phoneme_current := lip_info.phonemes[0];

        if (lip_info.flags and LIPS_FLAG_0x01) = 0 then
        begin
          // NOTE: Uninline.
          lips_stop_speech;
          v0 := head_marker_current;
        end;

        Break;
      end;

      speech_marker := @lip_info.markers[v0];
    end;

    if v0 >= lip_info.marker_count - 1 then
    begin
      head_marker_current := v0;

      v5 := 0;
      if lip_info.marker_count <= 5 then
        debug_printf('Error: Too few markers to stop speech!')
      else
        v5 := 3;

      speech_marker := @lip_info.markers[v5];
      if v1 < speech_marker^.position then
      begin
        v0 := 0;
        head_phoneme_current := lip_info.phonemes[0];

        if (lip_info.flags and LIPS_FLAG_0x01) = 0 then
        begin
          // NOTE: Uninline.
          lips_stop_speech;
          v0 := head_marker_current;
        end;
      end;
    end;
  end;

  if head_phoneme_drawn <> head_phoneme_current then
  begin
    head_phoneme_drawn := head_phoneme_current;
    lips_draw_head := True;
  end;

  head_marker_current := v0;

  soundUpdate;
end;

// 0x46CD9C
function lips_play_speech: Integer;
var
  v2: Integer;
  speechEntry: PSpeechMarker;
  speechVolume: Integer;
begin
  lip_info.flags := lip_info.flags or LIPS_FLAG_0x02;
  head_marker_current := 0;

  if soundSetPosition(lip_info.sound, lip_info.field_20) <> 0 then
    debug_printf('Failed set of start_offset!'#10);

  v2 := head_marker_current;
  while True do
  begin
    head_marker_current := v2;

    speechEntry := @lip_info.markers[v2];
    if lip_info.field_20 <= speechEntry^.position then
      Break;

    Inc(v2);

    head_phoneme_current := lip_info.phonemes[v2];
  end;

  speechVolume := gsound_speech_volume_get;
  soundVolume(lip_info.sound, Trunc(speechVolume * 0.69));

  speechStartTime := get_time;

  if soundPlay(lip_info.sound) <> 0 then
  begin
    debug_printf('Failed play!'#10);

    // NOTE: Uninline.
    lips_stop_speech;
  end;

  Result := 0;
end;

// 0x46CE9C
function lips_stop_speech: Integer;
begin
  head_marker_current := 0;
  soundStop(lip_info.sound);
  lip_info.flags := lip_info.flags and (not (LIPS_FLAG_0x01 or LIPS_FLAG_0x02));
  Result := 0;
end;

// 0x46CEBC
function lips_read_phoneme_type(phoneme_type: PByte; stream: PDB_FILE): Integer;
begin
  Result := db_freadByte(stream, phoneme_type);
end;

// 0x46CECC
function lips_read_marker_type(marker_type: PSpeechMarker; stream: PDB_FILE): Integer;
var
  marker: Integer;
begin
  // Marker is read into temporary variable.
  if db_freadInt32(stream, @marker) = -1 then
    Exit(-1);

  // Position is read directly into struct.
  if db_freadInt32(stream, @marker_type^.position) = -1 then
    Exit(-1);

  marker_type^.marker := marker;

  Result := 0;
end;

// 0x46CF08
function lips_read_lipsynch_info(lipsData: PLipsData; stream: PDB_FILE): Integer;
var
  sound_: Integer;
  field_14_: Integer;
  phonemes_: Integer;
  markers_: Integer;
begin
  if db_freadInt32(stream, @lipsData^.version) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_4) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.flags) = -1 then Exit(-1);
  if db_freadInt32(stream, @sound_) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_10) = -1 then Exit(-1);
  if db_freadInt32(stream, @field_14_) = -1 then Exit(-1);
  if db_freadInt32(stream, @phonemes_) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_1C) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_20) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.phoneme_count) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_28) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.marker_count) = -1 then Exit(-1);
  if db_freadInt32(stream, @markers_) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_34) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_38) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_3C) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_40) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_44) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_48) = -1 then Exit(-1);
  if db_freadInt32(stream, @lipsData^.field_4C) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@lipsData^.file_name[0]), 8) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@lipsData^.field_58[0]), 4) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@lipsData^.field_5C[0]), 4) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@lipsData^.field_60[0]), 4) = -1 then Exit(-1);
  if db_freadInt8List(stream, PShortInt(@lipsData^.field_64[0]), 260) = -1 then Exit(-1);

  // NOTE: Original code is different. For unknown reason it assigns values
  // from file (integers) and treat them as pointers, which is obviously wrong.
  lipsData^.sound := nil;
  lipsData^.field_14 := nil;
  lipsData^.phonemes := nil;
  lipsData^.markers := nil;

  Result := 0;
end;

// 0x46D11C
function lips_load_file(const audioFileName: PAnsiChar; const headFileName: PAnsiChar): Integer;
var
  sep: PAnsiChar;
  i: Integer;
  audioBaseName: array[0..15] of AnsiChar;
  speech_marker: PSpeechMarker;
  prev_speech_marker: PSpeechMarker;
  path: array[0..259] of AnsiChar;
  stream: PDB_FILE;
  phoneme: Byte;
begin
  StrCopy(@path[0], 'SOUND\SPEECH\');

  StrCopy(@lips_subdir_name[0], headFileName);

  StrCat(@path[0], @lips_subdir_name[0]);

  StrCat(@path[0], '\');

  sep := StrScan(@path[0], '.');
  if sep <> nil then
    sep^ := #0;

  StrCopy(@audioBaseName[0], audioFileName);

  sep := StrScan(@audioBaseName[0], '.');
  if sep <> nil then
    sep^ := #0;

  StrLCopy(@lip_info.file_name[0], @audioBaseName[0], SizeOf(lip_info.file_name));

  StrCat(@path[0], lips_fix_string(@lip_info.file_name[0], SizeOf(lip_info.file_name)));
  StrCat(@path[0], '.');
  StrCat(@path[0], @lip_info.field_60[0]);

  lips_free_speech;

  // FIXME: stream is not closed if any error is encountered during reading.
  stream := db_fopen(@path[0], 'rb');
  if stream <> nil then
  begin
    if db_freadInt32(stream, @lip_info.version) = -1 then
      Exit(-1);

    if lip_info.version = 1 then
    begin
      debug_printf(#10'Loading old save-file version (1)');

      if db_fseek(stream, 0, 0{SEEK_SET}) <> 0 then
        Exit(-1);

      if lips_read_lipsynch_info(@lip_info, stream) <> 0 then
        Exit(-1);
    end
    else if lip_info.version = 2 then
    begin
      debug_printf(#10'Loading current save-file version (2)');

      if db_freadInt32(stream, @lip_info.field_4) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.flags) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.field_10) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.field_1C) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.phoneme_count) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.field_28) = -1 then Exit(-1);
      if db_freadInt32(stream, @lip_info.marker_count) = -1 then Exit(-1);
      if db_freadInt8List(stream, PShortInt(@lip_info.file_name[0]), 8) = -1 then Exit(-1);
      if db_freadInt8List(stream, PShortInt(@lip_info.field_58[0]), 4) = -1 then Exit(-1);
    end
    else
    begin
      debug_printf(#10'Error: Lips file WRONG version!');
    end;
  end;

  lip_info.phonemes := PByte(mem_malloc(lip_info.phoneme_count));
  if lip_info.phonemes = nil then
  begin
    debug_printf('Out of memory in lips_load_file.'''#10);
    Exit(-1);
  end;

  if stream <> nil then
  begin
    i := 0;
    while i < lip_info.phoneme_count do
    begin
      if lips_read_phoneme_type(@lip_info.phonemes[i], stream) <> 0 then
      begin
        debug_printf('lips_load_file: Error reading phoneme type.'#10);
        Exit(-1);
      end;
      Inc(i);
    end;

    i := 0;
    while i < lip_info.phoneme_count do
    begin
      phoneme := lip_info.phonemes[i];
      if phoneme >= PHONEME_COUNT then
        debug_printf(#10'Load error: Speech phoneme %d is invalid (%d)!', [i, Integer(phoneme)]);
      Inc(i);
    end;
  end;

  lip_info.markers := PSpeechMarker(mem_malloc(SizeOf(TSpeechMarker) * lip_info.marker_count));
  if lip_info.markers = nil then
  begin
    debug_printf('Out of memory in lips_load_file.'''#10);
    Exit(-1);
  end;

  if stream <> nil then
  begin
    i := 0;
    while i < lip_info.marker_count do
    begin
      // NOTE: Uninline.
      if lips_read_marker_type(@lip_info.markers[i], stream) <> 0 then
      begin
        debug_printf('lips_load_file: Error reading marker type.');
        Exit(-1);
      end;
      Inc(i);
    end;

    speech_marker := @lip_info.markers[0];

    if (speech_marker^.marker <> 1) and (speech_marker^.marker <> 0) then
      debug_printf(#10'Load error: Speech marker 0 is invalid (%d)!', [speech_marker^.marker]);

    if speech_marker^.position <> 0 then
      debug_printf('Load error: Speech marker 0 has invalid position(%d)!', [speech_marker^.position]);

    i := 1;
    while i < lip_info.marker_count do
    begin
      speech_marker := @lip_info.markers[i];
      prev_speech_marker := @lip_info.markers[i - 1];

      if (speech_marker^.marker <> 1) and (speech_marker^.marker <> 0) then
        debug_printf(#10'Load error: Speech marker %d is invalid (%d)!', [i, speech_marker^.marker]);

      if speech_marker^.position < prev_speech_marker^.position then
        debug_printf('Load error: Speech marker %d has invalid position(%d)!', [i, speech_marker^.position]);

      Inc(i);
    end;
  end;

  if stream <> nil then
    db_fclose(stream);

  lip_info.field_38 := 0;
  lip_info.field_34 := 0;
  lip_info.field_48 := 0;
  lip_info.field_20 := 0;
  lip_info.field_3C := 50;
  lip_info.field_40 := 100;

  if lip_info.version = 1 then
    lip_info.field_4 := 22528;

  StrCopy(@lip_info.field_58[0], 'VOC');
  StrCopy(@lip_info.field_58[0], 'ACM');
  StrCopy(@lip_info.field_5C[0], 'TXT');
  StrCopy(@lip_info.field_60[0], 'LIP');

  lips_make_speech;

  head_marker_current := 0;
  head_phoneme_current := lip_info.phonemes[0];

  Result := 0;
end;

// 0x46D740
function lips_make_speech: Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  v1: PAnsiChar;
begin
  if lip_info.field_14 <> nil then
  begin
    mem_free(lip_info.field_14);
    lip_info.field_14 := nil;
  end;

  v1 := lips_fix_string(@lip_info.file_name[0], SizeOf(lip_info.file_name));
  StrLFmt(@path[0], SizeOf(path), '%s%s\%s.%s', ['SOUND\SPEECH\', PAnsiChar(@lips_subdir_name[0]), v1, 'ACM']);

  if lip_info.sound <> nil then
  begin
    soundDelete(lip_info.sound);
    lip_info.sound := nil;
  end;

  lip_info.sound := soundAllocate(1, 8);
  if lip_info.sound = nil then
  begin
    debug_printf(#10'soundAllocate falied in lips_make_speech!');
    Exit(-1);
  end;

  if soundSetFileIO(lip_info.sound,
    TSoundOpenProc(@audioOpen),
    TSoundCloseProc(@audioCloseFile),
    TSoundReadProc(@audioRead),
    nil,
    TSoundSeekProc(@audioSeek),
    nil,
    TSoundFileLengthProc(@audioFileSize)) <> 0 then
  begin
    debug_printf('Ack!');
    debug_printf('Error!');
  end;

  if soundLoad(lip_info.sound, @path[0]) <> 0 then
  begin
    soundDelete(lip_info.sound);
    lip_info.sound := nil;

    debug_printf('lips_make_speech: soundLoad failed with path ');
    debug_printf('%s -- file probably doesn''t exist.'#10, [PAnsiChar(@path[0])]);
    Exit(-1);
  end;

  lip_info.field_34 := 8 * (lip_info.field_1C div lip_info.marker_count);

  Result := 0;
end;

// 0x46D8A0
function lips_free_speech: Integer;
begin
  if lip_info.field_14 <> nil then
  begin
    mem_free(lip_info.field_14);
    lip_info.field_14 := nil;
  end;

  if lip_info.sound <> nil then
  begin
    // NOTE: Uninline.
    lips_stop_speech;

    soundDelete(lip_info.sound);

    lip_info.sound := nil;
  end;

  if lip_info.phonemes <> nil then
  begin
    mem_free(lip_info.phonemes);
    lip_info.phonemes := nil;
  end;

  if lip_info.markers <> nil then
  begin
    mem_free(lip_info.markers);
    lip_info.markers := nil;
  end;

  Result := 0;
end;

end.
