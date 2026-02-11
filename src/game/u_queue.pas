{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/queue.h + queue.cc
// Event queue system: timed events for drugs, explosions, scripts, radiation, etc.
unit u_queue;

interface

uses
  u_object_types, u_db;

const
  EVENT_TYPE_DRUG              = 0;
  EVENT_TYPE_KNOCKOUT          = 1;
  EVENT_TYPE_WITHDRAWAL        = 2;
  EVENT_TYPE_SCRIPT            = 3;
  EVENT_TYPE_GAME_TIME         = 4;
  EVENT_TYPE_POISON            = 5;
  EVENT_TYPE_RADIATION         = 6;
  EVENT_TYPE_FLARE             = 7;
  EVENT_TYPE_EXPLOSION         = 8;
  EVENT_TYPE_ITEM_TRICKLE      = 9;
  EVENT_TYPE_SNEAK             = 10;
  EVENT_TYPE_EXPLOSION_FAILURE = 11;
  EVENT_TYPE_MAP_UPDATE_EVENT  = 12;
  EVENT_TYPE_COUNT             = 13;

type
  PDrugEffectEvent = ^TDrugEffectEvent;
  TDrugEffectEvent = record
    drugPid: Integer;
    stats: array[0..2] of Integer;
    modifiers: array[0..2] of Integer;
  end;

  PWithdrawalEvent = ^TWithdrawalEvent;
  TWithdrawalEvent = record
    field_0: Integer;
    pid: Integer;
    perk: Integer;
  end;

  PScriptEvent = ^TScriptEvent;
  TScriptEvent = record
    sid: Integer;
    fixedParam: Integer;
  end;

  PRadiationEvent = ^TRadiationEvent;
  TRadiationEvent = record
    radiationLevel: Integer;
    isHealing: Integer;
  end;

  PAmbientSoundEffectEvent = ^TAmbientSoundEffectEvent;
  TAmbientSoundEffectEvent = record
    ambientSoundEffectIndex: Integer;
  end;

  TQueueEventHandler = function(owner: PObject; data: Pointer): Integer; cdecl;
  TQueueEventDataFreeProc = procedure(data: Pointer); cdecl;
  TQueueEventDataReadProc = function(stream: PDB_FILE; dataPtr: PPointer): Integer; cdecl;
  TQueueEventDataWriteProc = function(stream: PDB_FILE; data: Pointer): Integer; cdecl;

  PEventTypeDescription = ^TEventTypeDescription;
  TEventTypeDescription = record
    handlerProc: TQueueEventHandler;
    freeProc: TQueueEventDataFreeProc;
    readProc: TQueueEventDataReadProc;
    writeProc: TQueueEventDataWriteProc;
    field_10: Boolean;
    field_14: TQueueEventHandler;
  end;

var
  // 0x5076FC
  q_func: array[0..EVENT_TYPE_COUNT - 1] of TEventTypeDescription;

procedure queue_init;
function queue_reset: Integer;
function queue_exit: Integer;
function queue_load(stream: PDB_FILE): Integer;
function queue_save(stream: PDB_FILE): Integer;
function queue_add(delay: Integer; owner: PObject; data: Pointer; eventType: Integer): Integer;
function queue_remove(owner: PObject): Integer;
function queue_remove_this(owner: PObject; eventType: Integer): Integer;
function queue_find(owner: PObject; eventType: Integer): Boolean;
function queue_process: Integer;
procedure queue_clear;
procedure queue_clear_type(eventType: Integer; fn: TQueueEventHandler);
function queue_next_time: Integer;
procedure queue_leaving_map;

implementation

uses
  u_memory, u_proto_types, u_message, u_object, u_protinst, u_item,
  u_actions, u_display, u_scripts, u_critter, u_intface, u_game,
  u_inventry;

// -----------------------------------------------------------------------
// Internal linked list node
// -----------------------------------------------------------------------
type
  PQueueListNode = ^TQueueListNode;
  PPQueueListNode = ^PQueueListNode;
  TQueueListNode = record
    time: Integer;
    type_: Integer;
    owner: PObject;
    data: Pointer;
    next: PQueueListNode;
  end;

// (External declarations removed -- now imported via uses clause)

// -----------------------------------------------------------------------
// cdecl wrapper for mem_free (which uses register calling convention)
// -----------------------------------------------------------------------
procedure mem_free_cdecl(data: Pointer); cdecl; forward;

// -----------------------------------------------------------------------
// Forward declarations for static functions
// -----------------------------------------------------------------------
function queue_destroy(obj: PObject; data: Pointer): Integer; cdecl; forward;
function queue_explode(obj: PObject; data: Pointer): Integer; cdecl; forward;
function queue_explode_exit(obj: PObject; data: Pointer): Integer; cdecl; forward;
function queue_do_explosion(explosive: PObject; premature: Boolean): Integer; forward;
function queue_premature(obj: PObject; data: Pointer): Integer; cdecl; forward;

// -----------------------------------------------------------------------
// Module-level variables
// -----------------------------------------------------------------------
var
  // 0x662F4C
  queue_head: PQueueListNode = nil;

// =======================================================================
// queue_init
// 0x490670
// =======================================================================
procedure queue_init;
begin
  queue_head := nil;
end;

// =======================================================================
// queue_reset
// 0x490680
// =======================================================================
function queue_reset: Integer;
begin
  queue_clear;
  Result := 0;
end;

// =======================================================================
// queue_exit
// 0x490680
// =======================================================================
function queue_exit: Integer;
begin
  queue_clear;
  Result := 0;
end;

// =======================================================================
// queue_load
// 0x490688
// =======================================================================
function queue_load(stream: PDB_FILE): Integer;
var
  count: Integer;
  nextPtr: PPQueueListNode;
  rc: Integer;
  idx: Integer;
  queueListNode: PQueueListNode;
  objectId: Integer;
  obj: PObject;
  eventTypeDescription: PEventTypeDescription;
  nextNode: PQueueListNode;
begin
  if db_freadInt(stream, @count) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  queue_head := nil;
  nextPtr := @queue_head;

  rc := 0;
  idx := 0;
  while idx < count do
  begin
    queueListNode := PQueueListNode(mem_malloc(SizeOf(TQueueListNode)));
    if queueListNode = nil then
    begin
      rc := -1;
      Break;
    end;

    if db_freadInt(stream, @queueListNode^.time) = -1 then
    begin
      mem_free(queueListNode);
      rc := -1;
      Break;
    end;

    if db_freadInt(stream, @queueListNode^.type_) = -1 then
    begin
      mem_free(queueListNode);
      rc := -1;
      Break;
    end;

    if db_freadInt(stream, @objectId) = -1 then
    begin
      mem_free(queueListNode);
      rc := -1;
      Break;
    end;

    if objectId = -2 then
    begin
      obj := nil;
    end
    else
    begin
      obj := obj_find_first();
      while obj <> nil do
      begin
        obj := inven_find_id(obj, objectId);
        if obj <> nil then
          Break;
        obj := obj_find_next();
      end;
    end;

    queueListNode^.owner := obj;

    eventTypeDescription := @q_func[queueListNode^.type_];
    if eventTypeDescription^.readProc <> nil then
    begin
      if eventTypeDescription^.readProc(stream, @queueListNode^.data) = -1 then
      begin
        mem_free(queueListNode);
        rc := -1;
        Break;
      end;
    end
    else
    begin
      queueListNode^.data := nil;
    end;

    queueListNode^.next := nil;

    nextPtr^ := queueListNode;
    nextPtr := @queueListNode^.next;

    Inc(idx);
  end;

  if rc = -1 then
  begin
    while queue_head <> nil do
    begin
      nextNode := queue_head^.next;

      eventTypeDescription := @q_func[queue_head^.type_];
      if eventTypeDescription^.freeProc <> nil then
        eventTypeDescription^.freeProc(queue_head^.data);

      mem_free(queue_head);

      queue_head := nextNode;
    end;
  end;

  Result := rc;
end;

// =======================================================================
// queue_save
// 0x4907F4
// =======================================================================
function queue_save(stream: PDB_FILE): Integer;
var
  queueListNode: PQueueListNode;
  count: Integer;
  objectObj: PObject;
  objectId: Integer;
  eventTypeDescription: PEventTypeDescription;
begin
  count := 0;

  queueListNode := queue_head;
  while queueListNode <> nil do
  begin
    Inc(count);
    queueListNode := queueListNode^.next;
  end;

  if db_fwriteInt(stream, count) = -1 then
  begin
    Result := -1;
    Exit;
  end;

  queueListNode := queue_head;
  while queueListNode <> nil do
  begin
    objectObj := queueListNode^.owner;
    if objectObj <> nil then
      objectId := objectObj^.Id
    else
      objectId := -2;

    if db_fwriteInt(stream, queueListNode^.time) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if db_fwriteInt(stream, queueListNode^.type_) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    if db_fwriteInt(stream, objectId) = -1 then
    begin
      Result := -1;
      Exit;
    end;

    eventTypeDescription := @q_func[queueListNode^.type_];
    if eventTypeDescription^.writeProc <> nil then
    begin
      if eventTypeDescription^.writeProc(stream, queueListNode^.data) = -1 then
      begin
        Result := -1;
        Exit;
      end;
    end;

    queueListNode := queueListNode^.next;
  end;

  Result := 0;
end;

// =======================================================================
// queue_add
// 0x4908A0
// =======================================================================
function queue_add(delay: Integer; owner: PObject; data: Pointer; eventType: Integer): Integer;
var
  newQueueListNode: PQueueListNode;
  v2: Integer;
  v3: PPQueueListNode;
  v4: PQueueListNode;
begin
  newQueueListNode := PQueueListNode(mem_malloc(SizeOf(TQueueListNode)));
  if newQueueListNode = nil then
  begin
    Result := -1;
    Exit;
  end;

  v2 := game_time() + delay;
  newQueueListNode^.time := v2;
  newQueueListNode^.type_ := eventType;
  newQueueListNode^.owner := owner;
  newQueueListNode^.data := data;

  if owner <> nil then
    owner^.Flags := owner^.Flags or OBJECT_USED;

  v3 := @queue_head;

  if queue_head <> nil then
  begin
    repeat
      v4 := v3^;
      if v2 < v4^.time then
        Break;
      v3 := @v4^.next;
    until v4^.next = nil;
  end;

  newQueueListNode^.next := v3^;
  v3^ := newQueueListNode;

  Result := 0;
end;

// =======================================================================
// queue_remove
// 0x490908
// =======================================================================
function queue_remove(owner: PObject): Integer;
var
  queueListNode: PQueueListNode;
  queueListNodePtr: PPQueueListNode;
  temp: PQueueListNode;
  eventTypeDescription: PEventTypeDescription;
begin
  queueListNode := queue_head;
  queueListNodePtr := @queue_head;

  while queueListNode <> nil do
  begin
    if queueListNode^.owner = owner then
    begin
      temp := queueListNode;

      queueListNode := queueListNode^.next;
      queueListNodePtr^ := queueListNode;

      eventTypeDescription := @q_func[temp^.type_];
      if eventTypeDescription^.freeProc <> nil then
        eventTypeDescription^.freeProc(temp^.data);

      mem_free(temp);
    end
    else
    begin
      queueListNodePtr := @queueListNode^.next;
      queueListNode := queueListNode^.next;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// queue_remove_this
// 0x490960
// =======================================================================
function queue_remove_this(owner: PObject; eventType: Integer): Integer;
var
  queueListNode: PQueueListNode;
  queueListNodePtr: PPQueueListNode;
  temp: PQueueListNode;
  eventTypeDescription: PEventTypeDescription;
begin
  queueListNode := queue_head;
  queueListNodePtr := @queue_head;

  while queueListNode <> nil do
  begin
    if (queueListNode^.owner = owner) and (queueListNode^.type_ = eventType) then
    begin
      temp := queueListNode;

      queueListNode := queueListNode^.next;
      queueListNodePtr^ := queueListNode;

      eventTypeDescription := @q_func[temp^.type_];
      if eventTypeDescription^.freeProc <> nil then
        eventTypeDescription^.freeProc(temp^.data);

      mem_free(temp);
    end
    else
    begin
      queueListNodePtr := @queueListNode^.next;
      queueListNode := queueListNode^.next;
    end;
  end;

  Result := 0;
end;

// =======================================================================
// queue_find
// Returns true if there is at least one event of given type scheduled.
// 0x4909BC
// =======================================================================
function queue_find(owner: PObject; eventType: Integer): Boolean;
var
  queueListEvent: PQueueListNode;
begin
  queueListEvent := queue_head;
  while queueListEvent <> nil do
  begin
    if (owner = queueListEvent^.owner) and (eventType = queueListEvent^.type_) then
    begin
      Result := True;
      Exit;
    end;

    queueListEvent := queueListEvent^.next;
  end;

  Result := False;
end;

// =======================================================================
// queue_process
// 0x4909E4
// =======================================================================
function queue_process: Integer;
var
  time: Integer;
  v1: Integer;
  queueListNode: PQueueListNode;
  eventTypeDescription: PEventTypeDescription;
begin
  time := game_time();
  v1 := 0;

  while queue_head <> nil do
  begin
    queueListNode := queue_head;
    if (time < queueListNode^.time) or (v1 <> 0) then
      Break;

    queue_head := queueListNode^.next;

    eventTypeDescription := @q_func[queueListNode^.type_];
    v1 := eventTypeDescription^.handlerProc(queueListNode^.owner, queueListNode^.data);

    if eventTypeDescription^.freeProc <> nil then
      eventTypeDescription^.freeProc(queueListNode^.data);

    mem_free(queueListNode);
  end;

  Result := v1;
end;

// =======================================================================
// queue_clear
// 0x490A5C
// =======================================================================
procedure queue_clear;
var
  queueListNode: PQueueListNode;
  nextNode: PQueueListNode;
  eventTypeDescription: PEventTypeDescription;
begin
  queueListNode := queue_head;
  while queueListNode <> nil do
  begin
    nextNode := queueListNode^.next;

    eventTypeDescription := @q_func[queueListNode^.type_];
    if eventTypeDescription^.freeProc <> nil then
      eventTypeDescription^.freeProc(queueListNode^.data);

    mem_free(queueListNode);

    queueListNode := nextNode;
  end;

  queue_head := nil;
end;

// =======================================================================
// queue_clear_type
// 0x490AA4
// =======================================================================
procedure queue_clear_type(eventType: Integer; fn: TQueueEventHandler);
var
  ptr: PPQueueListNode;
  curr: PQueueListNode;
  tmp: PQueueListNode;
  eventTypeDescription: PEventTypeDescription;
begin
  ptr := @queue_head;
  curr := ptr^;

  while curr <> nil do
  begin
    if eventType = curr^.type_ then
    begin
      tmp := curr;

      ptr^ := curr^.next;
      curr := ptr^;

      if (fn <> nil) and (fn(tmp^.owner, tmp^.data) <> 1) then
      begin
        ptr^ := tmp;
        ptr := @tmp^.next;
      end
      else
      begin
        eventTypeDescription := @q_func[tmp^.type_];
        if eventTypeDescription^.freeProc <> nil then
          eventTypeDescription^.freeProc(tmp^.data);

        mem_free(tmp);
      end;
    end
    else
    begin
      ptr := @curr^.next;
      curr := ptr^;
    end;
  end;
end;

// =======================================================================
// queue_next_time
// 0x490B1C
// =======================================================================
function queue_next_time: Integer;
begin
  if queue_head = nil then
  begin
    Result := 0;
    Exit;
  end;

  Result := queue_head^.time;
end;

// =======================================================================
// queue_destroy (static)
// 0x490B30
// =======================================================================
function queue_destroy(obj: PObject; data: Pointer): Integer; cdecl;
begin
  obj_destroy(obj);
  Result := 1;
end;

// =======================================================================
// queue_explode (static)
// 0x490B3C
// =======================================================================
function queue_explode(obj: PObject; data: Pointer): Integer; cdecl;
begin
  Result := queue_do_explosion(obj, True);
end;

// =======================================================================
// queue_explode_exit (static)
// 0x490B44
// =======================================================================
function queue_explode_exit(obj: PObject; data: Pointer): Integer; cdecl;
begin
  Result := queue_do_explosion(obj, False);
end;

// =======================================================================
// queue_do_explosion (static)
// 0x490B48
// =======================================================================
function queue_do_explosion(explosive: PObject; premature: Boolean): Integer;
var
  owner: PObject;
  tile: Integer;
  elevation: Integer;
  min_damage: Integer;
  max_damage: Integer;
begin
  owner := obj_top_environment(explosive);
  if owner <> nil then
  begin
    tile := owner^.Tile;
    elevation := owner^.Elevation;
  end
  else
  begin
    tile := explosive^.Tile;
    elevation := explosive^.Elevation;
  end;

  if (explosive^.Pid = PROTO_ID_DYNAMITE_I) or (explosive^.Pid = PROTO_ID_DYNAMITE_II) then
  begin
    // Dynamite
    min_damage := 30;
    max_damage := 50;
  end
  else
  begin
    // Plastic explosive
    min_damage := 40;
    max_damage := 80;
  end;

  if action_explode(tile, elevation, min_damage, max_damage, obj_dude, premature) = -2 then
    queue_add(50, explosive, nil, EVENT_TYPE_EXPLOSION)
  else
    obj_destroy(explosive);

  Result := 1;
end;

// =======================================================================
// queue_premature (static)
// 0x490BCC
// =======================================================================
function queue_premature(obj: PObject; data: Pointer): Integer; cdecl;
var
  msg: TMessageListItem;
begin
  // Due to your inept handling, the explosive detonates prematurely.
  msg.num := 4000;
  if message_search(@misc_message_file, @msg) then
    display_print(msg.text);

  Result := queue_do_explosion(obj, True);
end;

// =======================================================================
// queue_leaving_map
// 0x490C08
// =======================================================================
procedure queue_leaving_map;
var
  index: Integer;
begin
  index := 0;
  while index < EVENT_TYPE_COUNT do
  begin
    if q_func[index].field_10 then
      queue_clear_type(index, q_func[index].field_14);
    Inc(index);
  end;
end;

// =======================================================================
// mem_free_cdecl - cdecl wrapper for mem_free
// =======================================================================
procedure mem_free_cdecl(data: Pointer); cdecl;
begin
  mem_free(data);
end;

// =======================================================================
// Initialization: fill q_func table
// =======================================================================
procedure InitQFunc;
begin
  // EVENT_TYPE_DRUG (0)
  q_func[0].handlerProc := @item_d_process;
  q_func[0].freeProc := @mem_free_cdecl;
  q_func[0].readProc := @item_d_load;
  q_func[0].writeProc := @item_d_save;
  q_func[0].field_10 := True;
  q_func[0].field_14 := @item_d_clear;

  // EVENT_TYPE_KNOCKOUT (1)
  q_func[1].handlerProc := @critter_wake_up;
  q_func[1].freeProc := nil;
  q_func[1].readProc := nil;
  q_func[1].writeProc := nil;
  q_func[1].field_10 := True;
  q_func[1].field_14 := @critter_wake_clear;

  // EVENT_TYPE_WITHDRAWAL (2)
  q_func[2].handlerProc := @item_wd_process;
  q_func[2].freeProc := @mem_free_cdecl;
  q_func[2].readProc := @item_wd_load;
  q_func[2].writeProc := @item_wd_save;
  q_func[2].field_10 := True;
  q_func[2].field_14 := @item_wd_clear;

  // EVENT_TYPE_SCRIPT (3)
  q_func[3].handlerProc := @script_q_process;
  q_func[3].freeProc := @mem_free_cdecl;
  q_func[3].readProc := @script_q_load;
  q_func[3].writeProc := @script_q_save;
  q_func[3].field_10 := True;
  q_func[3].field_14 := nil;

  // EVENT_TYPE_GAME_TIME (4)
  q_func[4].handlerProc := @gtime_q_process;
  q_func[4].freeProc := nil;
  q_func[4].readProc := nil;
  q_func[4].writeProc := nil;
  q_func[4].field_10 := True;
  q_func[4].field_14 := nil;

  // EVENT_TYPE_POISON (5)
  q_func[5].handlerProc := @critter_check_poison;
  q_func[5].freeProc := nil;
  q_func[5].readProc := nil;
  q_func[5].writeProc := nil;
  q_func[5].field_10 := False;
  q_func[5].field_14 := nil;

  // EVENT_TYPE_RADIATION (6)
  q_func[6].handlerProc := @critter_process_rads;
  q_func[6].freeProc := @mem_free_cdecl;
  q_func[6].readProc := @critter_load_rads;
  q_func[6].writeProc := @critter_save_rads;
  q_func[6].field_10 := False;
  q_func[6].field_14 := nil;

  // EVENT_TYPE_FLARE (7)
  q_func[7].handlerProc := @queue_destroy;
  q_func[7].freeProc := nil;
  q_func[7].readProc := nil;
  q_func[7].writeProc := nil;
  q_func[7].field_10 := True;
  q_func[7].field_14 := @queue_destroy;

  // EVENT_TYPE_EXPLOSION (8)
  q_func[8].handlerProc := @queue_explode;
  q_func[8].freeProc := nil;
  q_func[8].readProc := nil;
  q_func[8].writeProc := nil;
  q_func[8].field_10 := True;
  q_func[8].field_14 := @queue_explode_exit;

  // EVENT_TYPE_ITEM_TRICKLE (9)
  q_func[9].handlerProc := @item_m_trickle;
  q_func[9].freeProc := nil;
  q_func[9].readProc := nil;
  q_func[9].writeProc := nil;
  q_func[9].field_10 := True;
  q_func[9].field_14 := @item_m_turn_off_from_queue;

  // EVENT_TYPE_SNEAK (10)
  q_func[10].handlerProc := @critter_sneak_check;
  q_func[10].freeProc := nil;
  q_func[10].readProc := nil;
  q_func[10].writeProc := nil;
  q_func[10].field_10 := True;
  q_func[10].field_14 := @critter_sneak_clear;

  // EVENT_TYPE_EXPLOSION_FAILURE (11)
  q_func[11].handlerProc := @queue_premature;
  q_func[11].freeProc := nil;
  q_func[11].readProc := nil;
  q_func[11].writeProc := nil;
  q_func[11].field_10 := True;
  q_func[11].field_14 := @queue_explode_exit;

  // EVENT_TYPE_MAP_UPDATE_EVENT (12)
  q_func[12].handlerProc := @scr_map_q_process;
  q_func[12].freeProc := nil;
  q_func[12].readProc := nil;
  q_func[12].writeProc := nil;
  q_func[12].field_10 := True;
  q_func[12].field_14 := nil;
end;

initialization
  InitQFunc;

end.
