{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/plib/gnw/vcr.h + vcr.cc
// VCR system: record and play back input events.
unit u_vcr;

interface

const
  VCR_BUFFER_CAPACITY = 4096;

  // VcrState
  VCR_STATE_RECORDING  = 0;
  VCR_STATE_PLAYING    = 1;
  VCR_STATE_TURNED_OFF = 2;

  VCR_STATE_STOP_REQUESTED = LongWord($80000000);

  // VcrTerminationFlags
  VCR_TERMINATE_ON_KEY_PRESS   = $01;
  VCR_TERMINATE_ON_MOUSE_MOVE  = $02;
  VCR_TERMINATE_ON_MOUSE_PRESS = $04;

  // VcrPlaybackCompletionReason
  VCR_PLAYBACK_COMPLETION_REASON_NONE       = 0;
  VCR_PLAYBACK_COMPLETION_REASON_COMPLETED  = 1;
  VCR_PLAYBACK_COMPLETION_REASON_TERMINATED = 2;

  // VcrEntryType
  VCR_ENTRY_TYPE_NONE            = 0;
  VCR_ENTRY_TYPE_INITIAL_STATE   = 1;
  VCR_ENTRY_TYPE_KEYBOARD_EVENT  = 2;
  VCR_ENTRY_TYPE_MOUSE_EVENT     = 3;

type
  TVcrInitialData = record
    MouseX: Integer;
    MouseY: Integer;
    KeyboardLayout: Integer;
  end;

  TVcrKeyboardData = record
    Key: SmallInt;
    _padding: SmallInt;
  end;

  TVcrMouseData = record
    Dx: Integer;
    Dy: Integer;
    Buttons: Integer;
  end;

  PVcrEntry = ^TVcrEntry;
  TVcrEntry = record
    EntryType: LongWord;
    Time: LongWord;
    Counter: LongWord;
    case Integer of
      0: (Initial: TVcrInitialData);
      1: (KeyboardEvent: TVcrKeyboardData);
      2: (MouseEvent: TVcrMouseData);
  end;

  TVcrPlaybackCompletionCallback = procedure(reason: Integer); cdecl;

var
  vcr_buffer: PVcrEntry = nil;
  vcr_buffer_index: Integer = 0;
  vcr_state: LongWord = VCR_STATE_TURNED_OFF;
  vcr_time: LongWord = 0;
  vcr_counter: LongWord = 0;
  vcr_terminate_flags: LongWord = 0;
  vcr_terminated_condition: Integer = 0;

function vcr_record(fileName: PAnsiChar): Boolean;
function vcr_play(fileName: PAnsiChar; terminationFlags: LongWord;
  callback: TVcrPlaybackCompletionCallback): Boolean;
procedure vcr_stop;
function vcr_status: Integer;
function vcr_update: Integer;
function vcr_dump_buffer: Boolean;
function vcr_save_record(ptr: PVcrEntry; stream: Pointer): Boolean;
function vcr_load_record(ptr: PVcrEntry; stream: Pointer): Boolean;

implementation

uses
  u_memory, u_db;

var
  vcr_completion_callback: TVcrPlaybackCompletionCallback = nil;
  vcr_file: Pointer = nil;

function vcr_record(fileName: PAnsiChar): Boolean;
begin
  if vcr_state <> VCR_STATE_TURNED_OFF then
    Exit(False);

  if vcr_buffer = nil then
    vcr_buffer := PVcrEntry(mem_malloc(SizeOf(TVcrEntry) * VCR_BUFFER_CAPACITY));

  if vcr_buffer = nil then
    Exit(False);

  vcr_buffer_index := 0;
  vcr_state := VCR_STATE_RECORDING;
  vcr_counter := 0;
  vcr_time := 0;

  // TODO: Open file for writing using DB_FILE

  Result := True;
end;

function vcr_play(fileName: PAnsiChar; terminationFlags: LongWord;
  callback: TVcrPlaybackCompletionCallback): Boolean;
begin
  if vcr_state <> VCR_STATE_TURNED_OFF then
    Exit(False);

  if vcr_buffer = nil then
    vcr_buffer := PVcrEntry(mem_malloc(SizeOf(TVcrEntry) * VCR_BUFFER_CAPACITY));

  if vcr_buffer = nil then
    Exit(False);

  vcr_buffer_index := 0;
  vcr_state := VCR_STATE_PLAYING;
  vcr_terminate_flags := terminationFlags;
  vcr_completion_callback := callback;
  vcr_terminated_condition := VCR_PLAYBACK_COMPLETION_REASON_NONE;

  // TODO: Open file for reading using DB_FILE

  Result := True;
end;

procedure vcr_stop;
begin
  if vcr_state = VCR_STATE_TURNED_OFF then
    Exit;

  if vcr_state = VCR_STATE_RECORDING then
    vcr_dump_buffer;

  // TODO: Close file

  vcr_state := VCR_STATE_TURNED_OFF;

  if Assigned(vcr_completion_callback) then
  begin
    vcr_completion_callback(vcr_terminated_condition);
    vcr_completion_callback := nil;
  end;
end;

function vcr_status: Integer;
begin
  Result := Integer(vcr_state and (not VCR_STATE_STOP_REQUESTED));
end;

function vcr_update: Integer;
begin
  // TODO: Full implementation - process recorded/played events
  if (vcr_state and VCR_STATE_STOP_REQUESTED) <> 0 then
  begin
    vcr_stop;
    Exit(1);
  end;
  Result := 0;
end;

function vcr_dump_buffer: Boolean;
var
  i: Integer;
  entry: PVcrEntry;
begin
  if vcr_file = nil then
    Exit(False);

  for i := 0 to vcr_buffer_index - 1 do
  begin
    entry := @PVcrEntry(vcr_buffer)[i];
    if not vcr_save_record(entry, vcr_file) then
      Exit(False);
  end;

  vcr_buffer_index := 0;
  Result := True;
end;

function vcr_save_record(ptr: PVcrEntry; stream: Pointer): Boolean;
var
  f: PDB_FILE;
begin
  f := PDB_FILE(stream);
  if db_fwriteUInt32(f, ptr^.EntryType) = -1 then Exit(False);
  if db_fwriteUInt32(f, ptr^.Time) = -1 then Exit(False);
  if db_fwriteUInt32(f, ptr^.Counter) = -1 then Exit(False);

  case ptr^.EntryType of
    VCR_ENTRY_TYPE_INITIAL_STATE:
    begin
      if db_fwriteInt32(f, ptr^.Initial.MouseX) = -1 then Exit(False);
      if db_fwriteInt32(f, ptr^.Initial.MouseY) = -1 then Exit(False);
      if db_fwriteInt32(f, ptr^.Initial.KeyboardLayout) = -1 then Exit(False);
      Result := True;
    end;
    VCR_ENTRY_TYPE_KEYBOARD_EVENT:
    begin
      if db_fwriteInt16(f, ptr^.KeyboardEvent.Key) = -1 then Exit(False);
      Result := True;
    end;
    VCR_ENTRY_TYPE_MOUSE_EVENT:
    begin
      if db_fwriteInt32(f, ptr^.MouseEvent.Dx) = -1 then Exit(False);
      if db_fwriteInt32(f, ptr^.MouseEvent.Dy) = -1 then Exit(False);
      if db_fwriteInt32(f, ptr^.MouseEvent.Buttons) = -1 then Exit(False);
      Result := True;
    end;
  else
    Result := False;
  end;
end;

function vcr_load_record(ptr: PVcrEntry; stream: Pointer): Boolean;
var
  f: PDB_FILE;
begin
  f := PDB_FILE(stream);
  if db_freadUInt32(f, @ptr^.EntryType) = -1 then Exit(False);
  if db_freadUInt32(f, @ptr^.Time) = -1 then Exit(False);
  if db_freadUInt32(f, @ptr^.Counter) = -1 then Exit(False);

  case ptr^.EntryType of
    VCR_ENTRY_TYPE_INITIAL_STATE:
    begin
      if db_freadInt32(f, @ptr^.Initial.MouseX) = -1 then Exit(False);
      if db_freadInt32(f, @ptr^.Initial.MouseY) = -1 then Exit(False);
      if db_freadInt32(f, @ptr^.Initial.KeyboardLayout) = -1 then Exit(False);
      Result := True;
    end;
    VCR_ENTRY_TYPE_KEYBOARD_EVENT:
    begin
      if db_freadInt16(f, @ptr^.KeyboardEvent.Key) = -1 then Exit(False);
      Result := True;
    end;
    VCR_ENTRY_TYPE_MOUSE_EVENT:
    begin
      if db_freadInt32(f, @ptr^.MouseEvent.Dx) = -1 then Exit(False);
      if db_freadInt32(f, @ptr^.MouseEvent.Dy) = -1 then Exit(False);
      if db_freadInt32(f, @ptr^.MouseEvent.Buttons) = -1 then Exit(False);
      Result := True;
    end;
  else
    Result := False;
  end;
end;

end.
