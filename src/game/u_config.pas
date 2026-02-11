{$MODE OBJFPC}{$H+}
// Converted from: src/game/config.h + config.cc
// INI file parser/writer backed by assoc_array.
unit u_config;

interface

uses
  u_assoc;

const
  CONFIG_FILE_MAX_LINE_LENGTH = 256;
  CONFIG_INITIAL_CAPACITY = 10;

type
  // Config is just an assoc_array of sections.
  // Each section is itself an assoc_array storing char* pointers.
  TConfig = TAssocArray;
  PConfig = PAssocArray;
  TConfigSection = TAssocArray;
  PConfigSection = PAssocArray;

function config_init(config: PConfig): Boolean;
procedure config_exit(config: PConfig);
function config_cmd_line_parse(config: PConfig; argc: Integer; argv: PPAnsiChar): Boolean;
function config_get_string(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PPAnsiChar): Boolean;
function config_set_string(config: PConfig; sectionKey, key, value: PAnsiChar): Boolean;
function config_get_value(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PInteger): Boolean;
function config_get_values(config: PConfig; sectionKey, key: PAnsiChar; arr: PInteger; count: Integer): Boolean;
function config_set_value(config: PConfig; sectionKey, key: PAnsiChar; value: Integer): Boolean;
function config_load(config: PConfig; filePath: PAnsiChar; isDb: Boolean): Boolean;
function config_save(config: PConfig; filePath: PAnsiChar; isDb: Boolean): Boolean;
function config_get_double(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PDouble): Boolean;
function config_set_double(config: PConfig; sectionKey, key: PAnsiChar; value: Double): Boolean;
function configGetBool(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PBoolean): Boolean;
function configSetBool(config: PConfig; sectionKey, key: PAnsiChar; value: Boolean): Boolean;

implementation

uses
  SysUtils, u_memory, u_platform_compat, u_db;

// libc imports
function libc_fgets(s: PAnsiChar; n: Integer; stream: Pointer): PAnsiChar; cdecl; external 'c' name 'fgets';
function libc_fclose(stream: Pointer): Integer; cdecl; external 'c' name 'fclose';
function libc_fprintf(stream: Pointer; format: PAnsiChar): Integer; cdecl; varargs; external 'c' name 'fprintf';

// ---------------------------------------------------------------------------
// Helpers to access assoc_pair by index
// ---------------------------------------------------------------------------

function GetPairAt(list: PAssocPair; index: Integer): PAssocPair; inline;
begin
  Result := PAssocPair(PByte(list) + index * SizeOf(TAssocPair));
end;

// ---------------------------------------------------------------------------
// Static section buffer for parse_line (matches C static variable)
// ---------------------------------------------------------------------------
var
  parse_section: array[0..CONFIG_FILE_MAX_LINE_LENGTH - 1] of AnsiChar;

// ---------------------------------------------------------------------------
// Internal: strip leading/trailing whitespace in-place
// ---------------------------------------------------------------------------

function config_strip_white_space(str: PAnsiChar): Boolean;
var
  len: Integer;
  pch: PAnsiChar;
begin
  if str = nil then
    Exit(False);

  len := StrLen(str);
  if len = 0 then
    Exit(True);

  // Trim trailing whitespace
  pch := str + len - 1;
  while (len <> 0) and (pch^ in [' ', #9, #10, #13]) do
  begin
    Dec(len);
    Dec(pch);
  end;
  (pch + 1)^ := #0;

  // Trim leading whitespace
  pch := str;
  while pch^ in [' ', #9, #10, #13] do
  begin
    Inc(pch);
    Dec(len);
  end;

  if pch <> str then
    Move(pch^, str^, len + 1);

  Result := True;
end;

// ---------------------------------------------------------------------------
// Internal: split "key=value" into key and value buffers
// ---------------------------------------------------------------------------

function config_split_line(str: PAnsiChar; key, value: PAnsiChar): Boolean;
var
  pch: PAnsiChar;
begin
  if (str = nil) or (key = nil) or (value = nil) then
    Exit(False);

  pch := StrScan(str, '=');
  if pch = nil then
    Exit(False);

  pch^ := #0;

  StrCopy(key, str);
  StrCopy(value, pch + 1);

  pch^ := '=';

  config_strip_white_space(key);
  config_strip_white_space(value);

  Result := True;
end;

// ---------------------------------------------------------------------------
// Internal: ensure section exists in config
// ---------------------------------------------------------------------------

function config_add_section(config: PConfig; sectionKey: PAnsiChar): Boolean;
var
  section: TConfigSection;
begin
  if (config = nil) or (sectionKey = nil) then
    Exit(False);

  if assoc_search(config, sectionKey) <> -1 then
    Exit(True);

  if assoc_init(@section, CONFIG_INITIAL_CAPACITY, SizeOf(PAnsiChar), nil) = -1 then
    Exit(False);

  if assoc_insert(config, sectionKey, @section) = -1 then
    Exit(False);

  Result := True;
end;

// ---------------------------------------------------------------------------
// Internal: parse one line from .INI file
// ---------------------------------------------------------------------------

function config_parse_line(config: PConfig; str: PAnsiChar): Boolean;
var
  pch: PAnsiChar;
  sectionKey: PAnsiChar;
  key: array[0..259] of AnsiChar;
  value: array[0..259] of AnsiChar;
begin
  // Strip comments
  pch := StrScan(str, ';');
  if pch <> nil then
    pch^ := #0;

  // Check for [section]
  pch := StrScan(str, '[');
  if pch <> nil then
  begin
    sectionKey := pch + 1;
    pch := StrScan(sectionKey, ']');
    if pch <> nil then
    begin
      pch^ := #0;
      StrCopy(parse_section, sectionKey);
      Exit(config_strip_white_space(parse_section));
    end;
  end;

  if not config_split_line(str, @key[0], @value[0]) then
    Exit(False);

  Result := config_set_string(config, parse_section, @key[0], @value[0]);
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function config_init(config: PConfig): Boolean;
begin
  if config = nil then
    Exit(False);

  if assoc_init(config, CONFIG_INITIAL_CAPACITY, SizeOf(TConfigSection), nil) <> 0 then
    Exit(False);

  Result := True;
end;

procedure config_exit(config: PConfig);
var
  sectionIndex, kvIndex: Integer;
  sectionPair, kvPair: PAssocPair;
  section: PConfigSection;
  valuePtr: PPAnsiChar;
begin
  if config = nil then
    Exit;

  for sectionIndex := 0 to config^.Size - 1 do
  begin
    sectionPair := GetPairAt(config^.List, sectionIndex);
    section := PConfigSection(sectionPair^.Data);

    for kvIndex := 0 to section^.Size - 1 do
    begin
      kvPair := GetPairAt(section^.List, kvIndex);
      valuePtr := PPAnsiChar(kvPair^.Data);
      if valuePtr^ <> nil then
      begin
        mem_free(valuePtr^);
        valuePtr^ := nil;
      end;
    end;

    assoc_free(section);
  end;

  assoc_free(config);
end;

function config_cmd_line_parse(config: PConfig; argc: Integer; argv: PPAnsiChar): Boolean;
var
  arg: Integer;
  str: PAnsiChar;
  pch: PAnsiChar;
  sectionKey: PAnsiChar;
  key: array[0..259] of AnsiChar;
  value: array[0..259] of AnsiChar;
begin
  if config = nil then
    Exit(False);

  for arg := 0 to argc - 1 do
  begin
    str := PPAnsiChar(PByte(argv) + arg * SizeOf(PAnsiChar))^;

    // Find opening bracket
    pch := StrScan(str, '[');
    if pch = nil then
      Continue;

    sectionKey := pch + 1;

    // Find closing bracket
    pch := StrScan(sectionKey, ']');
    if pch = nil then
      Continue;

    pch^ := #0;

    if config_split_line(pch + 1, @key[0], @value[0]) then
    begin
      if not config_set_string(config, sectionKey, @key[0], @value[0]) then
      begin
        pch^ := ']';
        Exit(False);
      end;
    end;

    pch^ := ']';
  end;

  Result := True;
end;

function config_get_string(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PPAnsiChar): Boolean;
var
  sectionIndex, kvIndex: Integer;
  sectionPair, kvPair: PAssocPair;
  section: PConfigSection;
begin
  if (config = nil) or (sectionKey = nil) or (key = nil) or (valuePtr = nil) then
    Exit(False);

  sectionIndex := assoc_search(config, sectionKey);
  if sectionIndex = -1 then
    Exit(False);

  sectionPair := GetPairAt(config^.List, sectionIndex);
  section := PConfigSection(sectionPair^.Data);

  kvIndex := assoc_search(section, key);
  if kvIndex = -1 then
    Exit(False);

  kvPair := GetPairAt(section^.List, kvIndex);
  valuePtr^ := PPAnsiChar(kvPair^.Data)^;

  Result := True;
end;

function config_set_string(config: PConfig; sectionKey, key, value: PAnsiChar): Boolean;
var
  sectionIndex, kvIndex: Integer;
  sectionPair, kvPair: PAssocPair;
  section: PConfigSection;
  existingValue: PPAnsiChar;
  valueCopy: PAnsiChar;
begin
  if (config = nil) or (sectionKey = nil) or (key = nil) or (value = nil) then
    Exit(False);

  sectionIndex := assoc_search(config, sectionKey);
  if sectionIndex = -1 then
  begin
    if not config_add_section(config, sectionKey) then
      Exit(False);
    sectionIndex := assoc_search(config, sectionKey);
  end;

  sectionPair := GetPairAt(config^.List, sectionIndex);
  section := PConfigSection(sectionPair^.Data);

  kvIndex := assoc_search(section, key);
  if kvIndex <> -1 then
  begin
    kvPair := GetPairAt(section^.List, kvIndex);
    existingValue := PPAnsiChar(kvPair^.Data);
    mem_free(existingValue^);
    existingValue^ := nil;
    assoc_delete(section, key);
  end;

  valueCopy := mem_strdup(value);
  if valueCopy = nil then
    Exit(False);

  if assoc_insert(section, key, @valueCopy) = -1 then
  begin
    mem_free(valueCopy);
    Exit(False);
  end;

  Result := True;
end;

function config_get_value(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PInteger): Boolean;
var
  stringValue: PAnsiChar;
  code: Integer;
begin
  if valuePtr = nil then
    Exit(False);

  stringValue := nil;
  if not config_get_string(config, sectionKey, key, @stringValue) then
    Exit(False);

  Val(StrPas(stringValue), valuePtr^, code);
  Result := True;
end;

function config_get_values(config: PConfig; sectionKey, key: PAnsiChar; arr: PInteger; count: Integer): Boolean;
var
  str: PAnsiChar;
  temp: array[0..CONFIG_FILE_MAX_LINE_LENGTH - 1] of AnsiChar;
  p, pch: PAnsiChar;
begin
  if (arr = nil) or (count < 2) then
    Exit(False);

  str := nil;
  if not config_get_string(config, sectionKey, key, @str) then
    Exit(False);

  StrLCopy(@temp[0], str, CONFIG_FILE_MAX_LINE_LENGTH - 1);
  p := @temp[0];

  while True do
  begin
    pch := StrScan(p, ',');
    if pch = nil then
      Break;

    Dec(count);
    if count = 0 then
      Break;

    pch^ := #0;
    arr^ := StrToIntDef(StrPas(p), 0);
    Inc(arr);
    p := pch + 1;
  end;

  if count <= 1 then
  begin
    arr^ := StrToIntDef(StrPas(p), 0);
    Exit(True);
  end;

  Result := False;
end;

function config_set_value(config: PConfig; sectionKey, key: PAnsiChar; value: Integer): Boolean;
var
  stringValue: array[0..19] of AnsiChar;
begin
  compat_itoa(value, @stringValue[0], 10);
  Result := config_set_string(config, sectionKey, key, @stringValue[0]);
end;

function config_load(config: PConfig; filePath: PAnsiChar; isDb: Boolean): Boolean;
var
  str: array[0..CONFIG_FILE_MAX_LINE_LENGTH - 1] of AnsiChar;
  stream: Pointer;
begin
  if (config = nil) or (filePath = nil) then
    Exit(False);

  StrCopy(parse_section, 'unknown');

  if isDb then
  begin
    stream := db_fopen(filePath, 'rb');
    if stream <> nil then
    begin
      while db_fgets(@str[0], SizeOf(str), PDB_FILE(stream)) <> nil do
        config_parse_line(config, @str[0]);
      db_fclose(PDB_FILE(stream));
    end;
  end
  else
  begin
    stream := compat_fopen(filePath, 'rt');
    if stream <> nil then
    begin
      while libc_fgets(@str[0], SizeOf(str), stream) <> nil do
        config_parse_line(config, @str[0]);
      libc_fclose(stream);
    end;
  end;

  Result := True;
end;

function config_save(config: PConfig; filePath: PAnsiChar; isDb: Boolean): Boolean;
var
  sectionIndex, kvIndex: Integer;
  sectionPair, kvPair: PAssocPair;
  section: PConfigSection;
  stream: Pointer;
  dbStream: PDB_FILE;
  line: AnsiString;
begin
  if (config = nil) or (filePath = nil) then
    Exit(False);

  if isDb then
  begin
    dbStream := db_fopen(filePath, 'wt');
    if dbStream = nil then
      Exit(False);

    for sectionIndex := 0 to config^.Size - 1 do
    begin
      sectionPair := GetPairAt(config^.List, sectionIndex);

      line := '[' + StrPas(sectionPair^.Name) + ']'#10;
      db_fputs(PAnsiChar(line), dbStream);

      section := PConfigSection(sectionPair^.Data);
      for kvIndex := 0 to section^.Size - 1 do
      begin
        kvPair := GetPairAt(section^.List, kvIndex);
        line := StrPas(kvPair^.Name) + '=' + StrPas(PPAnsiChar(kvPair^.Data)^) + #10;
        db_fputs(PAnsiChar(line), dbStream);
      end;

      db_fputs(#10, dbStream);
    end;

    db_fclose(dbStream);
  end
  else
  begin
    stream := compat_fopen(filePath, 'wt');
    if stream = nil then
      Exit(False);

    for sectionIndex := 0 to config^.Size - 1 do
    begin
      sectionPair := GetPairAt(config^.List, sectionIndex);
      libc_fprintf(stream, '[%s]'#10, sectionPair^.Name);

      section := PConfigSection(sectionPair^.Data);
      for kvIndex := 0 to section^.Size - 1 do
      begin
        kvPair := GetPairAt(section^.List, kvIndex);
        libc_fprintf(stream, '%s=%s'#10, kvPair^.Name, PPAnsiChar(kvPair^.Data)^);
      end;

      libc_fprintf(stream, #10);
    end;

    libc_fclose(stream);
  end;

  Result := True;
end;

function config_get_double(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PDouble): Boolean;
var
  stringValue: PAnsiChar;
  code: Integer;
begin
  if valuePtr = nil then
    Exit(False);

  stringValue := nil;
  if not config_get_string(config, sectionKey, key, @stringValue) then
    Exit(False);

  Val(StrPas(stringValue), valuePtr^, code);
  Result := True;
end;

function config_set_double(config: PConfig; sectionKey, key: PAnsiChar; value: Double): Boolean;
var
  stringValue: array[0..31] of AnsiChar;
  s: AnsiString;
begin
  s := FormatFloat('0.000000', value);
  if Length(s) >= SizeOf(stringValue) then
    Exit(False);
  StrPCopy(@stringValue[0], s);
  Result := config_set_string(config, sectionKey, key, @stringValue[0]);
end;

function configGetBool(config: PConfig; sectionKey, key: PAnsiChar; valuePtr: PBoolean): Boolean;
var
  intValue: Integer;
begin
  if valuePtr = nil then
    Exit(False);

  if not config_get_value(config, sectionKey, key, @intValue) then
    Exit(False);

  valuePtr^ := (intValue <> 0);
  Result := True;
end;

function configSetBool(config: PConfig; sectionKey, key: PAnsiChar; value: Boolean): Boolean;
begin
  if value then
    Result := config_set_value(config, sectionKey, key, 1)
  else
    Result := config_set_value(config, sectionKey, key, 0);
end;

initialization
  StrCopy(parse_section, 'unknown');

end.
