unit u_message;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/message.h + message.cc
// Message file loading and management with bad word filtering.

interface

uses
  u_db;

const
  MESSAGE_LIST_ITEM_FIELD_MAX_SIZE = 1024;

type
  PMessageListItem = ^TMessageListItem;
  TMessageListItem = record
    num: Integer;
    audio: PAnsiChar;
    text: PAnsiChar;
  end;

  PMessageList = ^TMessageList;
  TMessageList = record
    entries_num: Integer;
    entries: PMessageListItem;
  end;

function init_message: Integer;
procedure exit_message;
function message_init(msg: PMessageList): Boolean;
function message_exit(msg: PMessageList): Boolean;
function message_load(messageList: PMessageList; path: PAnsiChar): Boolean;
function message_search(msg: PMessageList; entry: PMessageListItem): Boolean;
function message_make_path(dest: PAnsiChar; size: SizeUInt; path: PAnsiChar): Boolean;
function getmsg(msg: PMessageList; entry: PMessageListItem; num: Integer): PAnsiChar;
function message_filter(messageList: PMessageList): Boolean;

implementation

uses
  SysUtils, u_config, u_gconfig, u_platform_compat, u_memory, u_debug, u_roll;

const
  BADWORD_LENGTH_MAX = 80;
  SEEK_SET = 0;

// Forward declarations
function message_find(msg: PMessageList; num: Integer; out_index: PInteger): Boolean; forward;
function message_add(msg: PMessageList; new_entry: PMessageListItem): Boolean; forward;
function message_parse_number(out_num: PInteger; str: PAnsiChar): Boolean; forward;
function message_load_field(file_: PDB_FILE; str: PAnsiChar): Integer; forward;

// Local helper: isdigit
function isdigit_c(ch: AnsiChar): Boolean;
begin
  Result := (ch >= '0') and (ch <= '9');
end;

// Local helper: isalpha
function isalpha_c(ch: AnsiChar): Boolean;
begin
  Result := ((ch >= 'a') and (ch <= 'z')) or ((ch >= 'A') and (ch <= 'Z'));
end;

// Module-level variables (from C static)

// 0x505B10
var
  bad_word: PPAnsiChar = nil;

// 0x505B14
var
  bad_total: Integer = 0;

// 0x505B18
var
  bad_len: PInteger = nil;

// Temporary message list item text used during filtering badwords.
// 0x6305D0
var
  bad_copy: array[0..MESSAGE_LIST_ITEM_FIELD_MAX_SIZE - 1] of AnsiChar;

// Static local from getmsg (C static local variable)
var
  message_error_str: array[0..5] of AnsiChar = 'Error'#0;

// Static local from message_filter (C static const local)
const
  replacements: PAnsiChar = '!@#$%&*@#*!&$%#&%#*%!$&%@*$@&';

// 0x4764E0
function init_message: Integer;
var
  stream: PDB_FILE;
  word_: array[0..BADWORD_LENGTH_MAX - 1] of AnsiChar;
  index: Integer;
  len: Integer;
begin
  stream := db_fopen('data\badwords.txt', 'rt');
  if stream = nil then
  begin
    Result := -1;
    Exit;
  end;

  bad_total := 0;
  while db_fgets(@word_[0], BADWORD_LENGTH_MAX - 1, stream) <> nil do
    Inc(bad_total);

  bad_word := PPAnsiChar(mem_malloc(SizeOf(PAnsiChar) * bad_total));
  if bad_word = nil then
  begin
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  bad_len := PInteger(mem_malloc(SizeOf(Integer) * bad_total));
  if bad_len = nil then
  begin
    mem_free(bad_word);
    db_fclose(stream);
    Result := -1;
    Exit;
  end;

  db_fseek(stream, 0, SEEK_SET);

  index := 0;
  while index < bad_total do
  begin
    if db_fgets(@word_[0], BADWORD_LENGTH_MAX - 1, stream) = nil then
      Break;

    len := StrLen(@word_[0]);
    if (len > 0) and (word_[len - 1] = #10) then
    begin
      Dec(len);
      word_[len] := #0;
    end;

    PPAnsiChar(PByte(bad_word) + index * SizeOf(PAnsiChar))^ := mem_strdup(@word_[0]);
    if PPAnsiChar(PByte(bad_word) + index * SizeOf(PAnsiChar))^ = nil then
      Break;

    compat_strupr(PPAnsiChar(PByte(bad_word) + index * SizeOf(PAnsiChar))^);

    PInteger(PByte(bad_len) + index * SizeOf(Integer))^ := len;

    Inc(index);
  end;

  db_fclose(stream);

  if index <> bad_total then
  begin
    while index > 0 do
    begin
      mem_free(PPAnsiChar(PByte(bad_word) + (index - 1) * SizeOf(PAnsiChar))^);
      Dec(index);
    end;

    mem_free(bad_word);
    mem_free(bad_len);

    Result := -1;
    Exit;
  end;

  Result := 0;
end;

// 0x476660
procedure exit_message;
var
  index: Integer;
begin
  for index := 0 to bad_total - 1 do
    mem_free(PPAnsiChar(PByte(bad_word) + index * SizeOf(PAnsiChar))^);

  if bad_total <> 0 then
  begin
    mem_free(bad_word);
    mem_free(bad_len);
  end;

  bad_total := 0;
end;

// 0x4766BC
function message_init(msg: PMessageList): Boolean;
begin
  if msg <> nil then
  begin
    msg^.entries_num := 0;
    msg^.entries := nil;
  end;
  Result := True;
end;

// 0x4766D4
function message_exit(msg: PMessageList): Boolean;
var
  i: Integer;
  entry: PMessageListItem;
begin
  if msg = nil then
  begin
    Result := False;
    Exit;
  end;

  for i := 0 to msg^.entries_num - 1 do
  begin
    entry := PMessageListItem(PByte(msg^.entries) + i * SizeOf(TMessageListItem));

    if entry^.audio <> nil then
      mem_free(entry^.audio);

    if entry^.text <> nil then
      mem_free(entry^.text);
  end;

  msg^.entries_num := 0;

  if msg^.entries <> nil then
  begin
    mem_free(msg^.entries);
    msg^.entries := nil;
  end;

  Result := True;
end;

// 0x476814
function message_load(messageList: PMessageList; path: PAnsiChar): Boolean;
label
  err;
var
  language: PAnsiChar;
  localized_path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  file_ptr: PDB_FILE;
  num_buf: array[0..MESSAGE_LIST_ITEM_FIELD_MAX_SIZE - 1] of AnsiChar;
  audio_buf: array[0..MESSAGE_LIST_ITEM_FIELD_MAX_SIZE - 1] of AnsiChar;
  text_buf: array[0..MESSAGE_LIST_ITEM_FIELD_MAX_SIZE - 1] of AnsiChar;
  rc: Integer;
  success: Boolean;
  entry: TMessageListItem;
begin
  success := False;

  if messageList = nil then
  begin
    Result := False;
    Exit;
  end;

  if path = nil then
  begin
    Result := False;
    Exit;
  end;

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_LANGUAGE_KEY, @language) then
  begin
    WriteLn(StdErr, '[MSG] config_get_string for language FAILED');
    Result := False;
    Exit;
  end;
  WriteLn(StdErr, '[MSG] language=', language);

  StrLFmt(@localized_path[0], SizeOf(localized_path) - 1, '%s\%s\%s', [PAnsiChar('text'), language, path]);
  WriteLn(StdErr, '[MSG] localized_path=', PAnsiChar(@localized_path[0]));

  file_ptr := db_fopen(@localized_path[0], 'rt');
  if file_ptr = nil then
  begin
    WriteLn(StdErr, '[MSG] db_fopen FAILED for: ', PAnsiChar(@localized_path[0]));
    Result := False;
    Exit;
  end;
  WriteLn(StdErr, '[MSG] db_fopen OK');

  entry.num := 0;
  entry.audio := @audio_buf[0];
  entry.text := @text_buf[0];

  while True do
  begin
    rc := message_load_field(file_ptr, @num_buf[0]);
    if rc <> 0 then
    begin
      if rc <> 1 then
        WriteLn(StdErr, '[MSG] message_load_field(num) returned ', rc, ' at entry ', messageList^.entries_num);
      Break;
    end;

    rc := message_load_field(file_ptr, @audio_buf[0]);
    if rc <> 0 then
    begin
      WriteLn(StdErr, '[MSG] Error loading audio field, rc=', rc, ' at entry ', messageList^.entries_num);
      debug_printf(#10'Error loading audio field.'#10);
      goto err;
    end;

    rc := message_load_field(file_ptr, @text_buf[0]);
    if rc <> 0 then
    begin
      WriteLn(StdErr, '[MSG] Error loading text field, rc=', rc, ' at entry ', messageList^.entries_num);
      debug_printf(#10'Error loading text field.'#10);
      goto err;
    end;

    if not message_parse_number(@entry.num, @num_buf[0]) then
    begin
      WriteLn(StdErr, '[MSG] Error parsing number: "', PAnsiChar(@num_buf[0]), '" at entry ', messageList^.entries_num);
      debug_printf(#10'Error parsing number.'#10);
      goto err;
    end;

    if not message_add(messageList, @entry) then
    begin
      WriteLn(StdErr, '[MSG] Error adding message num=', entry.num, ' at entry ', messageList^.entries_num);
      debug_printf(#10'Error adding message.'#10);
      goto err;
    end;
  end;
  rc := rc; // preserve for check below

  if rc = 1 then
    success := True;

err:

  if not success then
  begin
    WriteLn(StdErr, '[MSG] FAILED parsing file, rc=', rc, ' entries_num=', messageList^.entries_num, ' offset=', db_ftell(file_ptr));
    debug_printf('Error loading message file %s at offset %x.', [PAnsiChar(@localized_path[0]), db_ftell(file_ptr)]);
  end
  else
    WriteLn(StdErr, '[MSG] parsed OK, entries_num=', messageList^.entries_num);

  db_fclose(file_ptr);

  Result := success;
end;

// 0x476998
function message_search(msg: PMessageList; entry: PMessageListItem): Boolean;
var
  index: Integer;
  ptr: PMessageListItem;
begin
  if msg = nil then
  begin
    Result := False;
    Exit;
  end;

  if entry = nil then
  begin
    Result := False;
    Exit;
  end;

  if msg^.entries_num = 0 then
  begin
    Result := False;
    Exit;
  end;

  if not message_find(msg, entry^.num, @index) then
  begin
    Result := False;
    Exit;
  end;

  ptr := PMessageListItem(PByte(msg^.entries) + index * SizeOf(TMessageListItem));
  entry^.audio := ptr^.audio;
  entry^.text := ptr^.text;

  Result := True;
end;

// Builds language-aware path in "text" subfolder.
// 0x476A20
function message_make_path(dest: PAnsiChar; size: SizeUInt; path: PAnsiChar): Boolean;
var
  language: PAnsiChar;
begin
  if dest = nil then
  begin
    Result := False;
    Exit;
  end;

  if path = nil then
  begin
    Result := False;
    Exit;
  end;

  if not config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_LANGUAGE_KEY, @language) then
  begin
    Result := False;
    Exit;
  end;

  StrLFmt(dest, size - 1, '%s\%s\%s', [PAnsiChar('text'), language, path]);

  Result := True;
end;

// 0x476A78
function message_find(msg: PMessageList; num: Integer; out_index: PInteger): Boolean;
var
  r, l, mid: Integer;
  cmp: Integer;
begin
  if msg^.entries_num = 0 then
  begin
    out_index^ := 0;
    Result := False;
    Exit;
  end;

  r := msg^.entries_num - 1;
  l := 0;

  repeat
    mid := (l + r) div 2;
    cmp := num - PMessageListItem(PByte(msg^.entries) + mid * SizeOf(TMessageListItem))^.num;
    if cmp = 0 then
    begin
      out_index^ := mid;
      Result := True;
      Exit;
    end;

    if cmp > 0 then
      l := l + 1
    else
      r := r - 1;
  until r < l;

  if cmp < 0 then
    out_index^ := mid
  else
    out_index^ := mid + 1;

  Result := False;
end;

// 0x476AD0
function message_add(msg: PMessageList; new_entry: PMessageListItem): Boolean;
var
  index: Integer;
  entries: PMessageListItem;
  existing_entry: PMessageListItem;
begin
  if message_find(msg, new_entry^.num, @index) then
  begin
    existing_entry := PMessageListItem(PByte(msg^.entries) + index * SizeOf(TMessageListItem));

    if existing_entry^.audio <> nil then
      mem_free(existing_entry^.audio);

    if existing_entry^.text <> nil then
      mem_free(existing_entry^.text);
  end
  else
  begin
    if msg^.entries <> nil then
    begin
      entries := PMessageListItem(mem_realloc(msg^.entries, SizeOf(TMessageListItem) * (msg^.entries_num + 1)));
      if entries = nil then
      begin
        Result := False;
        Exit;
      end;

      msg^.entries := entries;

      if index <> msg^.entries_num then
      begin
        // Move all items below insertion point
        Move(
          PByte(msg^.entries)[index * SizeOf(TMessageListItem)],
          PByte(msg^.entries)[(index + 1) * SizeOf(TMessageListItem)],
          SizeOf(TMessageListItem) * (msg^.entries_num - index)
        );
      end;
    end
    else
    begin
      msg^.entries := PMessageListItem(mem_malloc(SizeOf(TMessageListItem)));
      if msg^.entries = nil then
      begin
        Result := False;
        Exit;
      end;
      msg^.entries_num := 0;
      index := 0;
    end;

    existing_entry := PMessageListItem(PByte(msg^.entries) + index * SizeOf(TMessageListItem));
    existing_entry^.audio := nil;
    existing_entry^.text := nil;
    Inc(msg^.entries_num);
  end;

  existing_entry^.audio := mem_strdup(new_entry^.audio);
  if existing_entry^.audio = nil then
  begin
    Result := False;
    Exit;
  end;

  existing_entry^.text := mem_strdup(new_entry^.text);
  if existing_entry^.text = nil then
  begin
    Result := False;
    Exit;
  end;

  existing_entry^.num := new_entry^.num;

  Result := True;
end;

// 0x476D80
function message_parse_number(out_num: PInteger; str: PAnsiChar): Boolean;
var
  ch: PAnsiChar;
  success: Boolean;
  code: Integer;
begin
  ch := str;
  if ch^ = #0 then
  begin
    Result := False;
    Exit;
  end;

  success := True;
  if (ch^ = '+') or (ch^ = '-') then
    Inc(ch);

  while ch^ <> #0 do
  begin
    if not isdigit_c(ch^) then
    begin
      success := False;
      Break;
    end;
    Inc(ch);
  end;

  Val(StrPas(str), out_num^, code);
  Result := success;
end;

// Read next message file field, the str should be at least
// MESSAGE_LIST_ITEM_FIELD_MAX_SIZE bytes long.
//
// Returns:
// 0 - ok
// 1 - eof
// 2 - mismatched delimiters
// 3 - unterminated field
// 4 - limit exceeded (> MESSAGE_LIST_ITEM_FIELD_MAX_SIZE)
//
// 0x476DD4
function message_load_field(file_: PDB_FILE; str: PAnsiChar): Integer;
var
  ch: Integer;
  len: Integer;
begin
  len := 0;

  while True do
  begin
    ch := db_fgetc(file_);
    if ch = -1 then
    begin
      Result := 1;
      Exit;
    end;

    if ch = Ord('}') then
    begin
      debug_printf(#10'Error reading message file - mismatched delimiters.'#10);
      Result := 2;
      Exit;
    end;

    if ch = Ord('{') then
      Break;
  end;

  while True do
  begin
    ch := db_fgetc(file_);

    if ch = -1 then
    begin
      debug_printf(#10'Error reading message file - EOF reached.'#10);
      Result := 3;
      Exit;
    end;

    if ch = Ord('}') then
    begin
      (str + len)^ := #0;
      Result := 0;
      Exit;
    end;

    if ch <> Ord(#10) then
    begin
      (str + len)^ := AnsiChar(ch);
      Inc(len);

      if len >= MESSAGE_LIST_ITEM_FIELD_MAX_SIZE then
      begin
        debug_printf(#10'Error reading message file - text exceeds limit.'#10);
        Result := 4;
        Exit;
      end;
    end;
  end;

  Result := 0;
end;

// 0x476E6C
function getmsg(msg: PMessageList; entry: PMessageListItem; num: Integer): PAnsiChar;
begin
  entry^.num := num;

  if not message_search(msg, entry) then
  begin
    entry^.text := @message_error_str[0];
    debug_printf(#10' ** String not found @ getmsg(), MESSAGE.C **'#10);
  end;

  Result := entry^.text;
end;

// 0x476E98
function message_filter(messageList: PMessageList): Boolean;
var
  languageFilter: Integer;
  replacementsCount: Integer;
  replacementsIndex: Integer;
  index: Integer;
  item: PMessageListItem;
  badwordIndex: Integer;
  p: PAnsiChar;
  substr: PAnsiChar;
  ptr: PAnsiChar;
  j: Integer;
  scan: PAnsiChar;
  needle: PAnsiChar;
  needleLen: Integer;
begin
  if messageList = nil then
  begin
    Result := False;
    Exit;
  end;

  if messageList^.entries_num = 0 then
  begin
    Result := True;
    Exit;
  end;

  if bad_total = 0 then
  begin
    Result := True;
    Exit;
  end;

  languageFilter := 0;
  config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_LANGUAGE_FILTER_KEY, @languageFilter);
  if languageFilter <> 1 then
  begin
    Result := True;
    Exit;
  end;

  replacementsCount := StrLen(replacements);
  replacementsIndex := roll_random(1, replacementsCount) - 1;

  for index := 0 to messageList^.entries_num - 1 do
  begin
    item := PMessageListItem(PByte(messageList^.entries) + index * SizeOf(TMessageListItem));
    StrCopy(@bad_copy[0], item^.text);
    compat_strupr(@bad_copy[0]);

    for badwordIndex := 0 to bad_total - 1 do
    begin
      needle := PPAnsiChar(PByte(bad_word) + badwordIndex * SizeOf(PAnsiChar))^;
      needleLen := PInteger(PByte(bad_len) + badwordIndex * SizeOf(Integer))^;

      p := @bad_copy[0];
      while True do
      begin
        // Manual strstr implementation
        substr := nil;
        scan := p;
        while scan^ <> #0 do
        begin
          if StrLComp(scan, needle, needleLen) = 0 then
          begin
            substr := scan;
            Break;
          end;
          Inc(scan);
        end;

        if substr = nil then
          Break;

        if (substr = @bad_copy[0]) or
           ((not isalpha_c((substr - 1)^)) and (not isalpha_c((substr + needleLen)^))) then
        begin
          ptr := item^.text + (substr - @bad_copy[0]);

          j := 0;
          while j < needleLen do
          begin
            ptr^ := replacements[replacementsIndex];
            Inc(ptr);
            Inc(replacementsIndex);
            if replacementsIndex = replacementsCount then
              replacementsIndex := 0;
            Inc(j);
          end;
        end;

        Inc(p);
      end;
    end;
  end;

  Result := True;
end;

end.
