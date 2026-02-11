{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/selfrun.h + selfrun.cc
// Self-running demo: record and play back game sessions.
unit u_selfrun;

interface

uses
  u_db;

const
  SELFRUN_RECORDING_FILE_NAME_LENGTH = 13;
  SELFRUN_MAP_FILE_NAME_LENGTH = 13;

type
  PSelfrunData = ^TSelfrunData;
  TSelfrunData = record
    recordingFileName: array[0..SELFRUN_RECORDING_FILE_NAME_LENGTH - 1] of AnsiChar;
    mapFileName: array[0..SELFRUN_MAP_FILE_NAME_LENGTH - 1] of AnsiChar;
    stopKeyCode: Integer;
  end;

function selfrun_get_list(fileListPtr: PPPAnsiChar; fileListLengthPtr: PInteger): Integer;
function selfrun_free_list(fileListPtr: PPPAnsiChar): Integer;
function selfrun_prep_playback(fileName: PAnsiChar; selfrunData: PSelfrunData): Integer;
procedure selfrun_playback_loop(selfrunData: PSelfrunData);
function selfrun_prep_recording(recordingName: PAnsiChar; mapFileName: PAnsiChar; selfrunData: PSelfrunData): Integer;
procedure selfrun_recording_loop(selfrunData: PSelfrunData);

implementation

uses
  SysUtils,
  u_platform_compat, u_input, u_svga, u_vcr, u_mouse, u_fps_limiter,
  u_gconfig, u_config, u_kb,
  u_game;

const
  SELFRUN_STATE_TURNED_OFF = 0;
  SELFRUN_STATE_PLAYING    = 1;
  SELFRUN_STATE_RECORDING  = 2;

// Forward declarations
procedure selfrun_playback_callback(reason: Integer); cdecl; forward;
function selfrun_load_data(path: PAnsiChar; selfrunData: PSelfrunData): Integer; forward;
function selfrun_save_data(path: PAnsiChar; selfrunData: PSelfrunData): Integer; forward;

// 0x507A6C
var
  selfrun_state: Integer = SELFRUN_STATE_TURNED_OFF;

// 0x496D60
function selfrun_get_list(fileListPtr: PPPAnsiChar; fileListLengthPtr: PInteger): Integer;
begin
  if fileListPtr = nil then
    Exit(-1);

  if fileListLengthPtr = nil then
    Exit(-1);

  fileListLengthPtr^ := db_get_file_list('selfrun\*.sdf', fileListPtr, nil, 0);

  Result := 0;
end;

// 0x496D90
function selfrun_free_list(fileListPtr: PPPAnsiChar): Integer;
begin
  if fileListPtr = nil then
    Exit(-1);

  db_free_file_list(fileListPtr, nil);

  Result := 0;
end;

// 0x496DA8
function selfrun_prep_playback(fileName: PAnsiChar; selfrunData: PSelfrunData): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if fileName = nil then
    Exit(-1);

  if selfrunData = nil then
    Exit(-1);

  if vcr_status() <> VCR_STATE_TURNED_OFF then
    Exit(-1);

  if selfrun_state <> SELFRUN_STATE_TURNED_OFF then
    Exit(-1);

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', ['selfrun\', fileName]);

  if selfrun_load_data(@path[0], selfrunData) <> 0 then
    Exit(-1);

  selfrun_state := SELFRUN_STATE_PLAYING;

  Result := 0;
end;

// 0x496E08
procedure selfrun_playback_loop(selfrunData: PSelfrunData);
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  cursorWasHidden: Boolean;
  keyCode: Integer;
begin
  if selfrun_state = SELFRUN_STATE_PLAYING then
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', ['selfrun\', PAnsiChar(@selfrunData^.recordingFileName[0])]);

    if vcr_play(@path[0], VCR_TERMINATE_ON_KEY_PRESS or VCR_TERMINATE_ON_MOUSE_PRESS, @selfrun_playback_callback) then
    begin
      cursorWasHidden := mouse_hidden();
      if cursorWasHidden then
        mouse_show();

      while selfrun_state = SELFRUN_STATE_PLAYING do
      begin
        sharedFpsLimiter.Mark;

        keyCode := get_input();
        if keyCode <> selfrunData^.stopKeyCode then
          game_handle_input(keyCode, False);

        renderPresent;
        sharedFpsLimiter.Throttle;
      end;

      while mouse_get_buttons() <> 0 do
      begin
        sharedFpsLimiter.Mark;

        get_input();

        renderPresent;
        sharedFpsLimiter.Throttle;
      end;

      if cursorWasHidden then
        mouse_hide();
    end;
  end;
end;

// 0x496EA8
function selfrun_prep_recording(recordingName: PAnsiChar; mapFileName: PAnsiChar; selfrunData: PSelfrunData): Integer;
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
begin
  if recordingName = nil then
    Exit(-1);

  if mapFileName = nil then
    Exit(-1);

  if vcr_status() <> VCR_STATE_TURNED_OFF then
    Exit(-1);

  if selfrun_state <> SELFRUN_STATE_TURNED_OFF then
    Exit(-1);

  StrLFmt(@selfrunData^.recordingFileName[0],
    SizeOf(selfrunData^.recordingFileName) - 1,
    '%s%s', [recordingName, '.vcr']);
  StrCopy(@selfrunData^.mapFileName[0], mapFileName);

  selfrunData^.stopKeyCode := KEY_CTRL_R;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s%s', ['selfrun\', recordingName, '.sdf']);

  if selfrun_save_data(@path[0], selfrunData) <> 0 then
    Exit(-1);

  selfrun_state := SELFRUN_STATE_RECORDING;

  Result := 0;
end;

// 0x496F5C
procedure selfrun_recording_loop(selfrunData: PSelfrunData);
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  done: Boolean;
  keyCode: Integer;
begin
  if selfrun_state = SELFRUN_STATE_RECORDING then
  begin
    StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', ['selfrun\', PAnsiChar(@selfrunData^.recordingFileName[0])]);
    if vcr_record(@path[0]) then
    begin
      if not mouse_hidden() then
        mouse_show();

      done := False;
      while not done do
      begin
        sharedFpsLimiter.Mark;

        keyCode := get_input();
        if keyCode = selfrunData^.stopKeyCode then
        begin
          vcr_stop();
          game_user_wants_to_quit := 2;
          done := True;
        end
        else
          game_handle_input(keyCode, False);

        renderPresent;
        sharedFpsLimiter.Throttle;
      end;
    end;
    selfrun_state := SELFRUN_STATE_TURNED_OFF;
  end;
end;

// 0x496FF4
procedure selfrun_playback_callback(reason: Integer); cdecl;
begin
  game_user_wants_to_quit := 2;
  selfrun_state := SELFRUN_STATE_TURNED_OFF;
end;

// 0x49700C
function selfrun_load_data(path: PAnsiChar; selfrunData: PSelfrunData): Integer;
var
  stream: PDB_FILE;
  rc: Integer;
begin
  if path = nil then
    Exit(-1);

  if selfrunData = nil then
    Exit(-1);

  stream := db_fopen(path, 'rb');
  if stream = nil then
    Exit(-1);

  rc := -1;
  if (db_freadInt8List(stream, PShortInt(@selfrunData^.recordingFileName[0]), SELFRUN_RECORDING_FILE_NAME_LENGTH) = 0)
    and (db_freadInt8List(stream, PShortInt(@selfrunData^.mapFileName[0]), SELFRUN_MAP_FILE_NAME_LENGTH) = 0)
    and (db_freadInt32(stream, @selfrunData^.stopKeyCode) = 0) then
  begin
    rc := 0;
  end;

  db_fclose(stream);

  Result := rc;
end;

// 0x497074
function selfrun_save_data(path: PAnsiChar; selfrunData: PSelfrunData): Integer;
var
  masterPatches: PAnsiChar;
  selfrunDirectoryPath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  rc: Integer;
begin
  if path = nil then
    Exit(-1);

  if selfrunData = nil then
    Exit(-1);

  config_get_string(@game_config, GAME_CONFIG_SYSTEM_KEY, GAME_CONFIG_MASTER_PATCHES_KEY, @masterPatches);

  StrLFmt(@selfrunDirectoryPath[0], SizeOf(selfrunDirectoryPath) - 1, '%s\%s', [masterPatches, 'selfrun\']);

  compat_mkdir(@selfrunDirectoryPath[0]);

  stream := db_fopen(path, 'wb');
  if stream = nil then
    Exit(-1);

  rc := -1;
  if (db_fwriteInt8List(stream, PShortInt(@selfrunData^.recordingFileName[0]), SELFRUN_RECORDING_FILE_NAME_LENGTH) = 0)
    and (db_fwriteInt8List(stream, PShortInt(@selfrunData^.mapFileName[0]), SELFRUN_MAP_FILE_NAME_LENGTH) = 0)
    and (db_fwriteInt32(stream, selfrunData^.stopKeyCode) = 0) then
  begin
    rc := 0;
  end;

  db_fclose(stream);

  Result := rc;
end;

end.
