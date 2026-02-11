{$MODE OBJFPC}{$H+}
// Converted from: src/int/intrpret.cc/h
// Main bytecode interpreter for the Fallout scripting engine.
// setjmp/longjmp replaced with Pascal exceptions.
unit u_intrpret;

interface

uses
  SysUtils;

const
  // Opcodes
  OPCODE_NOOP                            = $8000;
  OPCODE_PUSH                            = $8001;
  OPCODE_ENTER_CRITICAL_SECTION          = $8002;
  OPCODE_LEAVE_CRITICAL_SECTION          = $8003;
  OPCODE_JUMP                            = $8004;
  OPCODE_CALL                            = $8005;
  OPCODE_CALL_AT                         = $8006;
  OPCODE_CALL_WHEN                       = $8007;
  OPCODE_CALLSTART                       = $8008;
  OPCODE_EXEC                            = $8009;
  OPCODE_SPAWN                           = $800A;
  OPCODE_FORK                            = $800B;
  OPCODE_A_TO_D                          = $800C;
  OPCODE_D_TO_A                          = $800D;
  OPCODE_EXIT                            = $800E;
  OPCODE_DETACH                          = $800F;
  OPCODE_EXIT_PROGRAM                    = $8010;
  OPCODE_STOP_PROGRAM                    = $8011;
  OPCODE_FETCH_GLOBAL                    = $8012;
  OPCODE_STORE_GLOBAL                    = $8013;
  OPCODE_FETCH_EXTERNAL                  = $8014;
  OPCODE_STORE_EXTERNAL                  = $8015;
  OPCODE_EXPORT_VARIABLE                 = $8016;
  OPCODE_EXPORT_PROCEDURE                = $8017;
  OPCODE_SWAP                            = $8018;
  OPCODE_SWAPA                           = $8019;
  OPCODE_POP                             = $801A;
  OPCODE_DUP                             = $801B;
  OPCODE_POP_RETURN                      = $801C;
  OPCODE_POP_EXIT                        = $801D;
  OPCODE_POP_ADDRESS                     = $801E;
  OPCODE_POP_FLAGS                       = $801F;
  OPCODE_POP_FLAGS_RETURN                = $8020;
  OPCODE_POP_FLAGS_EXIT                  = $8021;
  OPCODE_POP_FLAGS_RETURN_EXTERN         = $8022;
  OPCODE_POP_FLAGS_EXIT_EXTERN           = $8023;
  OPCODE_POP_FLAGS_RETURN_VAL_EXTERN     = $8024;
  OPCODE_POP_FLAGS_RETURN_VAL_EXIT       = $8025;
  OPCODE_POP_FLAGS_RETURN_VAL_EXIT_EXTERN = $8026;
  OPCODE_CHECK_PROCEDURE_ARGUMENT_COUNT  = $8027;
  OPCODE_LOOKUP_PROCEDURE_BY_NAME        = $8028;
  OPCODE_POP_BASE                        = $8029;
  OPCODE_POP_TO_BASE                     = $802A;
  OPCODE_PUSH_BASE                       = $802B;
  OPCODE_SET_GLOBAL                      = $802C;
  OPCODE_FETCH_PROCEDURE_ADDRESS         = $802D;
  OPCODE_DUMP                            = $802E;
  OPCODE_IF                              = $802F;
  OPCODE_WHILE                           = $8030;
  OPCODE_STORE                           = $8031;
  OPCODE_FETCH                           = $8032;
  OPCODE_EQUAL                           = $8033;
  OPCODE_NOT_EQUAL                       = $8034;
  OPCODE_LESS_THAN_EQUAL                 = $8035;
  OPCODE_GREATER_THAN_EQUAL              = $8036;
  OPCODE_LESS_THAN                       = $8037;
  OPCODE_GREATER_THAN                    = $8038;
  OPCODE_ADD                             = $8039;
  OPCODE_SUB                             = $803A;
  OPCODE_MUL                             = $803B;
  OPCODE_DIV                             = $803C;
  OPCODE_MOD                             = $803D;
  OPCODE_AND                             = $803E;
  OPCODE_OR                              = $803F;
  OPCODE_BITWISE_AND                     = $8040;
  OPCODE_BITWISE_OR                      = $8041;
  OPCODE_BITWISE_XOR                     = $8042;
  OPCODE_BITWISE_NOT                     = $8043;
  OPCODE_FLOOR                           = $8044;
  OPCODE_NOT                             = $8045;
  OPCODE_NEGATE                          = $8046;
  OPCODE_WAIT                            = $8047;
  OPCODE_CANCEL                          = $8048;
  OPCODE_CANCEL_ALL                      = $8049;
  OPCODE_START_CRITICAL                  = $804A;
  OPCODE_END_CRITICAL                    = $804B;

  // ProcedureFlags
  PROCEDURE_FLAG_TIMED       = $01;
  PROCEDURE_FLAG_CONDITIONAL = $02;
  PROCEDURE_FLAG_IMPORTED    = $04;
  PROCEDURE_FLAG_EXPORTED    = $08;
  PROCEDURE_FLAG_CRITICAL    = $10;

  // ProgramFlags
  PROGRAM_FLAG_EXITED           = $01;
  PROGRAM_FLAG_0x02             = $02;
  PROGRAM_FLAG_0x04             = $04;
  PROGRAM_FLAG_STOPPED          = $08;
  PROGRAM_IS_WAITING            = $10;
  PROGRAM_FLAG_0x20             = $20;
  PROGRAM_FLAG_0x40             = $40;
  PROGRAM_FLAG_CRITICAL_SECTION = $80;
  PROGRAM_FLAG_0x0100           = $0100;

  // RawValueType
  RAW_VALUE_TYPE_OPCODE         = $8000;
  RAW_VALUE_TYPE_INT            = $4000;
  RAW_VALUE_TYPE_FLOAT          = $2000;
  RAW_VALUE_TYPE_STATIC_STRING  = $1000;
  RAW_VALUE_TYPE_DYNAMIC_STRING = $0800;

  VALUE_TYPE_MASK           = $F7FF;
  VALUE_TYPE_INT            = $C001;
  VALUE_TYPE_FLOAT          = $A001;
  VALUE_TYPE_STRING         = $9001;
  VALUE_TYPE_DYNAMIC_STRING = $9801;
  VALUE_TYPE_PTR            = $E001;

type
  opcode_t = Word;

  TProcedure = record
    field_0: Integer;
    field_4: Integer;
    field_8: Integer;
    field_C: Integer;
    field_10: Integer;
    field_14: Integer;
  end;
  PProcedure = ^TProcedure;

  TProgramValue = record
    opcode: opcode_t;
    case Integer of
      0: (integerValue: Integer);
      1: (floatValue: Single);
      2: (pointerValue: Pointer);
  end;
  PProgramValue = ^TProgramValue;

  // Dynamic array used as stack (replaces std::vector<ProgramValue>)
  TProgramStack = array of TProgramValue;
  PProgramStack = ^TProgramStack;

  PProgram = ^TProgram;

  TInterpretCheckWaitFunc = function(program_: PProgram): Integer; cdecl;

  TProgram = record
    name: PAnsiChar;
    data: PByte;
    dataSize: Integer;  // Added for bounds checking
    parent: PProgram;
    child: PProgram;
    instructionPointer: Integer;
    framePointer: Integer;
    basePointer: Integer;
    staticStrings: PByte;
    dynamicStrings: PByte;
    identifiers: PByte;
    procedures: PByte;
    // jmp_buf replaced - use exceptions instead
    waitEnd: LongWord;
    waitStart: LongWord;
    field_78: Integer;
    checkWaitFunc: TInterpretCheckWaitFunc;
    flags: Integer;
    windowId: Integer;
    exited: Boolean;
    stackValues: PProgramStack;
    returnStackValues: PProgramStack;
  end;

  TInterpretMangleFunc = function(fileName: PAnsiChar): PAnsiChar; cdecl;
  TInterpretOutputFunc = function(str: PAnsiChar): Integer; cdecl;
  TInterpretTimerFunc = function: LongWord; cdecl;
  TOpcodeHandler = procedure(program_: PProgram); cdecl;

  // Exception to replace longjmp in the interpreter
  EProgramExit = class(Exception);

function ProgramValueIsEmpty(const v: TProgramValue): Boolean;

procedure interpretSetTimeFunc(timerFunc: TInterpretTimerFunc; timerTick: Integer);
function interpretMangleName(fileName: PAnsiChar): PAnsiChar;
procedure interpretOutputFunc(func: TInterpretOutputFunc);
function interpretOutput(const fmt: PAnsiChar; const args: array of const): Integer;
procedure interpretError(const fmt: PAnsiChar; const args: array of const);
procedure interpretFreeProgram(program_: PProgram);
function allocateProgram(const path: PAnsiChar): PProgram;
function interpretGetString(program_: PProgram; opcode: opcode_t; offset: Integer): PAnsiChar;
function interpretGetName(program_: PProgram; offset: Integer): PAnsiChar;
function interpretAddString(program_: PProgram; str: PAnsiChar): Integer;
procedure initInterpreter;
procedure interpretClose;
procedure interpretEnableInterpreter(enabled: Integer);
procedure interpret(program_: PProgram; a2: Integer);
procedure executeProc(program_: PProgram; procedureIndex: Integer);
function interpretFindProcedure(prg: PProgram; const name: PAnsiChar): Integer;
procedure executeProcedure(program_: PProgram; procedureIndex: Integer);
procedure runProgram(program_: PProgram);
function runScript(name: PAnsiChar): PProgram;
procedure interpretSetCPUBurstSize(value: Integer);
procedure updatePrograms;
procedure clearPrograms;
procedure clearTopProgram;
function getProgramList(programListLengthPtr: PInteger): PPAnsiChar;
procedure freeProgramList(programList: PPAnsiChar; programListLength: Integer);
procedure interpretAddFunc(opcode: Integer; handler: TOpcodeHandler);
procedure interpretSetFilenameFunc(func: TInterpretMangleFunc);
procedure interpretSuspendEvents;
procedure interpretResumeEvents;
function interpretSaveProgramState: Integer;
function interpretLoadProgramState: Integer;

procedure interpretRegisterProgramDeleteCallback(callback: Pointer);

procedure programStackPushValue(program_: PProgram; var programValue: TProgramValue);
procedure programStackPushInteger(program_: PProgram; value: Integer);
procedure programStackPushFloat(program_: PProgram; value: Single);
procedure programStackPushString(program_: PProgram; str: PAnsiChar);
procedure programStackPushPointer(program_: PProgram; value: Pointer);

function programStackPopValue(program_: PProgram): TProgramValue;
function programStackPopInteger(program_: PProgram): Integer;
function programStackPopFloat(program_: PProgram): Single;
function programStackPopString(program_: PProgram): PAnsiChar;
function programStackPopPointer(program_: PProgram): Pointer;

procedure programReturnStackPushValue(program_: PProgram; var programValue: TProgramValue);
procedure programReturnStackPushInteger(program_: PProgram; value: Integer);
procedure programReturnStackPushPointer(program_: PProgram; value: Pointer);

function programReturnStackPopValue(program_: PProgram): TProgramValue;
function programReturnStackPopInteger(program_: PProgram): Integer;
function programReturnStackPopPointer(program_: PProgram): Pointer;

implementation

uses
  u_memdbg, u_db, u_debug, u_platform_compat;

const
  MAX_OPCODE_HANDLERS = 342;
  PROGRAM_DELETE_CALLBACKS_MAX = 10;

type
  TProgramDeleteCallback = procedure(program_: PProgram);

var
  timerFunc_: TInterpretTimerFunc = nil;
  timerTick_: Integer = 1000;
  outputFunc_: TInterpretOutputFunc = nil;
  filenameFunc_: TInterpretMangleFunc = nil;
  interpreterEnabled: Integer = 1;
  cpuBurstSize: Integer = 10;
  suspendEvents_: Integer = 0;

  opcodeHandlers: array[0..MAX_OPCODE_HANDLERS - 1] of TOpcodeHandler;

  programDeleteCallbacks: array[0..PROGRAM_DELETE_CALLBACKS_MAX - 1] of TProgramDeleteCallback;
  programDeleteCallbacksCount: Integer = 0;

  // Program list (linked list head)
  headProgram: PProgram = nil;
  currentProgram: PProgram = nil;

function ProgramValueIsEmpty(const v: TProgramValue): Boolean;
begin
  Result := (v.opcode = 0) and (v.integerValue = 0);
end;

procedure interpretRegisterProgramDeleteCallback(callback: Pointer);
begin
  if programDeleteCallbacksCount < PROGRAM_DELETE_CALLBACKS_MAX then
  begin
    programDeleteCallbacks[programDeleteCallbacksCount] := TProgramDeleteCallback(callback);
    Inc(programDeleteCallbacksCount);
  end;
end;

procedure interpretSetTimeFunc(timerFunc: TInterpretTimerFunc; timerTick: Integer);
begin
  timerFunc_ := timerFunc;
  timerTick_ := timerTick;
end;

function interpretMangleName(fileName: PAnsiChar): PAnsiChar;
begin
  if filenameFunc_ <> nil then
    Result := filenameFunc_(fileName)
  else
    Result := fileName;
end;

procedure interpretOutputFunc(func: TInterpretOutputFunc);
begin
  outputFunc_ := func;
end;

function interpretOutput(const fmt: PAnsiChar; const args: array of const): Integer;
var
  s: AnsiString;
  buf: array[0..259] of AnsiChar;
begin
  if outputFunc_ = nil then
    Exit(0);

  try
    s := Format(fmt, args);
  except
    s := fmt;
  end;
  if Length(s) > 259 then
    SetLength(s, 259);
  Move(s[1], buf[0], Length(s));
  buf[Length(s)] := #0;
  Result := outputFunc_(@buf[0]);
end;

procedure interpretError(const fmt: PAnsiChar; const args: array of const);
var
  s: AnsiString;
begin
  try
    s := Format(fmt, args);
  except
    s := fmt;
  end;
  debug_printf('Error: %s'#10, [PAnsiChar(s)]);
end;

function getTimeSinceEpoch: LongWord;
begin
  if timerFunc_ <> nil then
    Result := timerFunc_()
  else
    Result := 0;
end;

// Stack operations

procedure programStackPushValue(program_: PProgram; var programValue: TProgramValue);
var
  len: Integer;
begin
  len := Length(program_^.stackValues^);
  SetLength(program_^.stackValues^, len + 1);
  program_^.stackValues^[len] := programValue;
end;

procedure programStackPushInteger(program_: PProgram; value: Integer);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_INT;
  pv.integerValue := value;
  programStackPushValue(program_, pv);
end;

procedure programStackPushFloat(program_: PProgram; value: Single);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_FLOAT;
  pv.floatValue := value;
  programStackPushValue(program_, pv);
end;

procedure programStackPushString(program_: PProgram; str: PAnsiChar);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_DYNAMIC_STRING;
  pv.integerValue := interpretAddString(program_, str);
  programStackPushValue(program_, pv);
end;

procedure programStackPushPointer(program_: PProgram; value: Pointer);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_PTR;
  pv.pointerValue := value;
  programStackPushValue(program_, pv);
end;

function programStackPopValue(program_: PProgram): TProgramValue;
var
  len: Integer;
begin
  len := Length(program_^.stackValues^);
  if len = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  Result := program_^.stackValues^[len - 1];
  SetLength(program_^.stackValues^, len - 1);
end;

function programStackPopInteger(program_: PProgram): Integer;
var
  pv: TProgramValue;
begin
  pv := programStackPopValue(program_);
  if (pv.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_FLOAT then
    Result := Trunc(pv.floatValue)
  else
    Result := pv.integerValue;
end;

function programStackPopFloat(program_: PProgram): Single;
var
  pv: TProgramValue;
begin
  pv := programStackPopValue(program_);
  if (pv.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    Result := Single(pv.integerValue)
  else
    Result := pv.floatValue;
end;

function programStackPopString(program_: PProgram): PAnsiChar;
var
  pv: TProgramValue;
begin
  pv := programStackPopValue(program_);
  Result := interpretGetString(program_, pv.opcode, pv.integerValue);
end;

function programStackPopPointer(program_: PProgram): Pointer;
var
  pv: TProgramValue;
begin
  pv := programStackPopValue(program_);
  Result := pv.pointerValue;
end;

// Return stack operations

procedure programReturnStackPushValue(program_: PProgram; var programValue: TProgramValue);
var
  len: Integer;
begin
  len := Length(program_^.returnStackValues^);
  SetLength(program_^.returnStackValues^, len + 1);
  program_^.returnStackValues^[len] := programValue;
end;

procedure programReturnStackPushInteger(program_: PProgram; value: Integer);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_INT;
  pv.integerValue := value;
  programReturnStackPushValue(program_, pv);
end;

procedure programReturnStackPushPointer(program_: PProgram; value: Pointer);
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_PTR;
  pv.pointerValue := value;
  programReturnStackPushValue(program_, pv);
end;

function programReturnStackPopValue(program_: PProgram): TProgramValue;
var
  len: Integer;
begin
  len := Length(program_^.returnStackValues^);
  if len = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;
  Result := program_^.returnStackValues^[len - 1];
  SetLength(program_^.returnStackValues^, len - 1);
end;

function programReturnStackPopInteger(program_: PProgram): Integer;
var
  pv: TProgramValue;
begin
  pv := programReturnStackPopValue(program_);
  Result := pv.integerValue;
end;

function programReturnStackPopPointer(program_: PProgram): Pointer;
var
  pv: TProgramValue;
begin
  pv := programReturnStackPopValue(program_);
  Result := pv.pointerValue;
end;

// Read helpers for bytecode data

function fetchWord(data: PByte; offset: Integer): Word;
begin
  Result := Word(data[offset]) shl 8 or Word(data[offset + 1]);
end;

function fetchLong(data: PByte; offset: Integer): Integer;
begin
  Result := Integer(data[offset]) shl 24
         or Integer(data[offset + 1]) shl 16
         or Integer(data[offset + 2]) shl 8
         or Integer(data[offset + 3]);
end;

function fetchFloat(data: PByte; offset: Integer): Single;
var
  intVal: LongWord;
begin
  intVal := LongWord(data[offset]) shl 24
         or LongWord(data[offset + 1]) shl 16
         or LongWord(data[offset + 2]) shl 8
         or LongWord(data[offset + 3]);
  Result := PSingle(@intVal)^;
end;

procedure storeWord(data: PByte; offset: Integer; value: Word);
begin
  data[offset] := Byte(value shr 8);
  data[offset + 1] := Byte(value);
end;

procedure storeLong(data: PByte; offset: Integer; value: Integer);
begin
  data[offset] := Byte(value shr 24);
  data[offset + 1] := Byte(value shr 16);
  data[offset + 2] := Byte(value shr 8);
  data[offset + 3] := Byte(value);
end;

// String table operations

function interpretGetString(program_: PProgram; opcode: opcode_t; offset: Integer): PAnsiChar;
var
  table: PByte;
begin
  if (opcode and RAW_VALUE_TYPE_DYNAMIC_STRING) <> 0 then
    table := program_^.dynamicStrings
  else
    table := program_^.staticStrings;

  if table = nil then
    Exit(nil);

  Result := PAnsiChar(table + 4 + offset + 2);
end;

function interpretGetName(program_: PProgram; offset: Integer): PAnsiChar;
begin
  if program_^.identifiers = nil then
    Exit(nil);
  Result := PAnsiChar(program_^.identifiers + 4 + offset);
end;

function interpretAddString(program_: PProgram; str: PAnsiChar): Integer;
var
  table: PByte;
  tableSize: Integer;
  stringLen: Integer;
  offset: Integer;
  newTable: PByte;
begin
  table := program_^.dynamicStrings;
  if table = nil then
  begin
    // Allocate initial dynamic string table: 4 byte size header
    tableSize := 4 + 2; // header + length word for first string
    stringLen := StrLen(str) + 1;
    table := PByte(mymalloc(tableSize + stringLen, 'INTRPRET.C', 0));
    FillChar(table^, tableSize + stringLen, 0);
    storeLong(table, 0, tableSize + stringLen);
    storeWord(table, 4, stringLen);
    Move(str^, (table + 4 + 2)^, stringLen);
    program_^.dynamicStrings := table;
    Result := 0;
    Exit;
  end;

  tableSize := fetchLong(table, 0);
  stringLen := StrLen(str) + 1;
  offset := tableSize - 4;

  newTable := PByte(myrealloc(table, tableSize + 2 + stringLen, 'INTRPRET.C', 0));
  storeLong(newTable, 0, tableSize + 2 + stringLen);
  storeWord(newTable, tableSize, stringLen);
  Move(str^, (newTable + tableSize + 2)^, stringLen);
  program_^.dynamicStrings := newTable;
  Result := offset;
end;

procedure interpretFreeProgram(program_: PProgram);
var
  i: Integer;
begin
  // Notify callbacks
  for i := 0 to programDeleteCallbacksCount - 1 do
    programDeleteCallbacks[i](program_);

  if program_^.dynamicStrings <> nil then
    myfree(program_^.dynamicStrings, 'INTRPRET.C', 0);

  if program_^.data <> nil then
    myfree(program_^.data, 'INTRPRET.C', 0);

  if program_^.name <> nil then
    myfree(program_^.name, 'INTRPRET.C', 0);

  if program_^.stackValues <> nil then
  begin
    SetLength(program_^.stackValues^, 0);
    Dispose(program_^.stackValues);
  end;

  if program_^.returnStackValues <> nil then
  begin
    SetLength(program_^.returnStackValues^, 0);
    Dispose(program_^.returnStackValues);
  end;

  myfree(program_, 'INTRPRET.C', 0);
end;

function allocateProgram(const path: PAnsiChar): PProgram;
var
  program_: PProgram;
  mangledPath: PAnsiChar;
  stream: PDB_FILE;
  size: Integer;
  data: PByte;
  nameCopy: PAnsiChar;
  nameLen: Integer;
begin
  mangledPath := interpretMangleName(PAnsiChar(path));

  stream := db_fopen(mangledPath, 'rb');
  if stream = nil then
  begin
    debug_printf('interpretAllocateProgram: failed to open %s'#10, [mangledPath]);
    Exit(nil);
  end;

  size := db_filelength(stream);
  WriteLn('[SCRIPT] Loading ', mangledPath, ' size=', size);
  data := PByte(mymalloc(size, 'INTRPRET.C', 0));
  db_fread(data, 1, size, stream);
  db_fclose(stream);
  if size > 12 then
    WriteLn('[SCRIPT] First 12 bytes: ', data[0], ' ', data[1], ' ', data[2], ' ', data[3],
            ' ', data[4], ' ', data[5], ' ', data[6], ' ', data[7],
            ' ', data[8], ' ', data[9], ' ', data[10], ' ', data[11]);

  program_ := PProgram(mymalloc(SizeOf(TProgram), 'INTRPRET.C', 0));
  FillChar(program_^, SizeOf(TProgram), 0);

  nameLen := StrLen(path) + 1;
  nameCopy := PAnsiChar(mymalloc(nameLen, 'INTRPRET.C', 0));
  Move(path^, nameCopy^, nameLen);
  program_^.name := nameCopy;

  program_^.data := data;
  program_^.dataSize := size;
  program_^.instructionPointer := 0;
  program_^.framePointer := 0;
  program_^.basePointer := 0;
  program_^.field_78 := -1;
  program_^.flags := 0;
  program_^.windowId := 0;
  program_^.exited := False;

  // Read string/procedure tables from data
  // Data layout: header (42 bytes), then procedures table, then identifiers, then strings
  if size > 42 then
  begin
    program_^.procedures := data + 42;
    program_^.identifiers := program_^.procedures + 4 + SizeOf(TProcedure) * fetchLong(program_^.procedures, 0);
    program_^.staticStrings := program_^.identifiers + 4 + fetchLong(program_^.identifiers, 0);
    WriteLn('[SCRIPT] procedures at +42, procCount=', fetchLong(program_^.procedures, 0));
  end
  else
    WriteLn('[SCRIPT] WARNING: size <= 42, tables not initialized');

  // Allocate stacks
  New(program_^.stackValues);
  SetLength(program_^.stackValues^, 0);
  New(program_^.returnStackValues);
  SetLength(program_^.returnStackValues^, 0);

  program_^.dynamicStrings := nil;
  program_^.parent := nil;
  program_^.child := nil;
  program_^.checkWaitFunc := nil;

  Result := program_;
end;

// Basic opcode handlers
procedure op_noop(program_: PProgram); cdecl;
begin
  // Do nothing
end;

procedure op_push_base(program_: PProgram); cdecl;
var
  pv: TProgramValue;
begin
  pv.opcode := VALUE_TYPE_INT;
  pv.integerValue := program_^.basePointer;
  programStackPushValue(program_, pv);
end;

procedure op_pop_base(program_: PProgram); cdecl;
begin
  program_^.basePointer := programStackPopInteger(program_);
end;

procedure op_pop_to_base(program_: PProgram); cdecl;
var
  len, newLen: Integer;
begin
  len := Length(program_^.stackValues^);
  newLen := program_^.basePointer;
  if newLen < len then
    SetLength(program_^.stackValues^, newLen);
end;

procedure op_dump(program_: PProgram); cdecl;
var
  count: Integer;
begin
  count := programStackPopInteger(program_);
  while (count > 0) and (Length(program_^.stackValues^) > 0) do
  begin
    programStackPopValue(program_);
    Dec(count);
  end;
end;

procedure op_fetch(program_: PProgram); cdecl;
var
  addr: Integer;
  pv: TProgramValue;
begin
  addr := programStackPopInteger(program_);
  if (addr >= 0) and (addr < Length(program_^.stackValues^)) then
    pv := program_^.stackValues^[addr]
  else
  begin
    pv.opcode := VALUE_TYPE_INT;
    pv.integerValue := 0;
  end;
  programStackPushValue(program_, pv);
end;

procedure op_store(program_: PProgram); cdecl;
var
  addr: Integer;
  pv: TProgramValue;
begin
  addr := programStackPopInteger(program_);
  pv := programStackPopValue(program_);
  if (addr >= 0) and (addr < Length(program_^.stackValues^)) then
    program_^.stackValues^[addr] := pv;
end;

procedure op_if(program_: PProgram); cdecl;
var
  cond, offset: Integer;
begin
  cond := programStackPopInteger(program_);
  offset := fetchLong(program_^.data, program_^.instructionPointer);
  program_^.instructionPointer := program_^.instructionPointer + 4;
  if cond = 0 then
    program_^.instructionPointer := offset;
end;

procedure op_while(program_: PProgram); cdecl;
var
  cond, offset: Integer;
begin
  cond := programStackPopInteger(program_);
  offset := fetchLong(program_^.data, program_^.instructionPointer);
  program_^.instructionPointer := program_^.instructionPointer + 4;
  if cond <> 0 then
    program_^.instructionPointer := offset;
end;

procedure op_equal(program_: PProgram); cdecl;
var
  a, b: TProgramValue;
  result_: Integer;
begin
  b := programStackPopValue(program_);
  a := programStackPopValue(program_);
  if a.integerValue = b.integerValue then
    result_ := 1
  else
    result_ := 0;
  programStackPushInteger(program_, result_);
end;

procedure op_not_equal(program_: PProgram); cdecl;
var
  a, b: TProgramValue;
  result_: Integer;
begin
  b := programStackPopValue(program_);
  a := programStackPopValue(program_);
  if a.integerValue <> b.integerValue then
    result_ := 1
  else
    result_ := 0;
  programStackPushInteger(program_, result_);
end;

procedure op_less_than(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if a < b then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_greater_than(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if a > b then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_less_than_equal(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if a <= b then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_greater_than_equal(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if a >= b then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_add(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a + b);
end;

procedure op_sub(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a - b);
end;

procedure op_mul(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a * b);
end;

procedure op_div_(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if b <> 0 then
    programStackPushInteger(program_, a div b)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_mod(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if b <> 0 then
    programStackPushInteger(program_, a mod b)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_and_(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if (a <> 0) and (b <> 0) then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_or_(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  if (a <> 0) or (b <> 0) then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_not(program_: PProgram); cdecl;
var
  a: Integer;
begin
  a := programStackPopInteger(program_);
  if a = 0 then
    programStackPushInteger(program_, 1)
  else
    programStackPushInteger(program_, 0);
end;

procedure op_negate(program_: PProgram); cdecl;
var
  a: Integer;
begin
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, -a);
end;

procedure op_bitwise_and(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a and b);
end;

procedure op_bitwise_or(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a or b);
end;

procedure op_bitwise_xor(program_: PProgram); cdecl;
var
  a, b: Integer;
begin
  b := programStackPopInteger(program_);
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, a xor b);
end;

procedure op_bitwise_not(program_: PProgram); cdecl;
var
  a: Integer;
begin
  a := programStackPopInteger(program_);
  programStackPushInteger(program_, not a);
end;

procedure op_floor_(program_: PProgram); cdecl;
var
  pv: TProgramValue;
begin
  pv := programStackPopValue(program_);
  if (pv.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_FLOAT then
    programStackPushInteger(program_, Trunc(pv.floatValue))
  else
    programStackPushInteger(program_, pv.integerValue);
end;

procedure op_set_global(program_: PProgram); cdecl;
var
  addr: Integer;
  pv: TProgramValue;
begin
  addr := fetchLong(program_^.data, program_^.instructionPointer);
  program_^.instructionPointer := program_^.instructionPointer + 4;
  pv := programStackPopValue(program_);
  // Store to global variable space (at address from stack base)
  if (addr >= 0) and (addr < Length(program_^.stackValues^)) then
    program_^.stackValues^[addr] := pv;
end;

procedure initInterpreter;
begin
  FillChar(opcodeHandlers, SizeOf(opcodeHandlers), 0);
  programDeleteCallbacksCount := 0;

  // Register basic opcode handlers
  interpretAddFunc(OPCODE_NOOP, @op_noop);
  interpretAddFunc(OPCODE_PUSH_BASE, @op_push_base);
  interpretAddFunc(OPCODE_POP_BASE, @op_pop_base);
  interpretAddFunc(OPCODE_POP_TO_BASE, @op_pop_to_base);
  interpretAddFunc(OPCODE_DUMP, @op_dump);
  interpretAddFunc(OPCODE_FETCH, @op_fetch);
  interpretAddFunc(OPCODE_STORE, @op_store);
  interpretAddFunc(OPCODE_IF, @op_if);
  interpretAddFunc(OPCODE_WHILE, @op_while);
  interpretAddFunc(OPCODE_EQUAL, @op_equal);
  interpretAddFunc(OPCODE_NOT_EQUAL, @op_not_equal);
  interpretAddFunc(OPCODE_LESS_THAN, @op_less_than);
  interpretAddFunc(OPCODE_GREATER_THAN, @op_greater_than);
  interpretAddFunc(OPCODE_LESS_THAN_EQUAL, @op_less_than_equal);
  interpretAddFunc(OPCODE_GREATER_THAN_EQUAL, @op_greater_than_equal);
  interpretAddFunc(OPCODE_ADD, @op_add);
  interpretAddFunc(OPCODE_SUB, @op_sub);
  interpretAddFunc(OPCODE_MUL, @op_mul);
  interpretAddFunc(OPCODE_DIV, @op_div_);
  interpretAddFunc(OPCODE_MOD, @op_mod);
  interpretAddFunc(OPCODE_AND, @op_and_);
  interpretAddFunc(OPCODE_OR, @op_or_);
  interpretAddFunc(OPCODE_NOT, @op_not);
  interpretAddFunc(OPCODE_NEGATE, @op_negate);
  interpretAddFunc(OPCODE_BITWISE_AND, @op_bitwise_and);
  interpretAddFunc(OPCODE_BITWISE_OR, @op_bitwise_or);
  interpretAddFunc(OPCODE_BITWISE_XOR, @op_bitwise_xor);
  interpretAddFunc(OPCODE_BITWISE_NOT, @op_bitwise_not);
  interpretAddFunc(OPCODE_FLOOR, @op_floor_);
  interpretAddFunc(OPCODE_SET_GLOBAL, @op_set_global);
end;

procedure interpretClose;
begin
  clearPrograms;
end;

procedure interpretEnableInterpreter(enabled: Integer);
begin
  interpreterEnabled := enabled;
end;

procedure interpretSetCPUBurstSize(value: Integer);
begin
  cpuBurstSize := value;
end;

procedure interpretSetFilenameFunc(func: TInterpretMangleFunc);
begin
  filenameFunc_ := func;
end;

procedure interpretSuspendEvents;
begin
  Inc(suspendEvents_);
end;

procedure interpretResumeEvents;
begin
  Dec(suspendEvents_);
  if suspendEvents_ < 0 then
    suspendEvents_ := 0;
end;

procedure interpretAddFunc(opcode: Integer; handler: TOpcodeHandler);
var
  index: Integer;
begin
  index := opcode - $8000;
  if (index >= 0) and (index < MAX_OPCODE_HANDLERS) then
    opcodeHandlers[index] := handler;
end;

procedure interpret(program_: PProgram; a2: Integer);
var
  opcode: Word;
  index: Integer;
  count: Integer;
  pv: TProgramValue;
begin
  if interpreterEnabled = 0 then
    Exit;

  if program_ = nil then
    Exit;

  if (program_^.flags and PROGRAM_FLAG_EXITED) <> 0 then
    Exit;

  if (program_^.flags and PROGRAM_FLAG_STOPPED) <> 0 then
    Exit;

  if (program_^.flags and PROGRAM_IS_WAITING) <> 0 then
  begin
    if program_^.checkWaitFunc <> nil then
    begin
      if program_^.checkWaitFunc(program_) <> 0 then
      begin
        program_^.flags := program_^.flags and (not PROGRAM_IS_WAITING);
        program_^.checkWaitFunc := nil;
      end
      else
        Exit;
    end
    else
    begin
      if getTimeSinceEpoch >= program_^.waitEnd then
        program_^.flags := program_^.flags and (not PROGRAM_IS_WAITING)
      else
        Exit;
    end;
  end;

  currentProgram := program_;
  count := 0;

  try
    while count < cpuBurstSize do
    begin
      if program_^.data = nil then
      begin
        WriteLn('[INTERP] ERROR: data is nil for ', program_^.name);
        Break;
      end;
      if (program_^.instructionPointer < 0) or (program_^.instructionPointer >= program_^.dataSize - 1) then
      begin
        // Script has run past its data - stop execution
        program_^.flags := program_^.flags or PROGRAM_FLAG_EXITED;
        Break;
      end;
      opcode := fetchWord(program_^.data, program_^.instructionPointer);
      //WriteLn('[INTERP] opcode=', IntToHex(opcode, 4));
      program_^.instructionPointer := program_^.instructionPointer + 2;

      index := opcode - $8000;
      if (index >= 0) and (index < MAX_OPCODE_HANDLERS) and
         (opcodeHandlers[index] <> nil) then
      begin
        opcodeHandlers[index](program_);
      end
      else if opcode = VALUE_TYPE_INT then
      begin
        // Push immediate integer value
        programStackPushInteger(program_, fetchLong(program_^.data, program_^.instructionPointer));
        program_^.instructionPointer := program_^.instructionPointer + 4;
      end
      else if opcode = VALUE_TYPE_FLOAT then
      begin
        // Push immediate float value
        programStackPushFloat(program_, fetchFloat(program_^.data, program_^.instructionPointer));
        program_^.instructionPointer := program_^.instructionPointer + 4;
      end
      else if (opcode = VALUE_TYPE_STRING) or (opcode = VALUE_TYPE_DYNAMIC_STRING) or (opcode = VALUE_TYPE_PTR) then
      begin
        // Push string/pointer value (raw value with type preserved)
        pv.opcode := opcode;
        pv.integerValue := fetchLong(program_^.data, program_^.instructionPointer);
        programStackPushValue(program_, pv);
        program_^.instructionPointer := program_^.instructionPointer + 4;
      end
      else if (opcode and RAW_VALUE_TYPE_OPCODE) = 0 then
      begin
        // Raw value - push to stack
        // This handles inline values in the bytecode
      end
      else
      begin
        interpretError('Unknown opcode %04X at %d', [Integer(opcode), program_^.instructionPointer - 2]);
      end;

      if (program_^.flags and (PROGRAM_FLAG_EXITED or PROGRAM_FLAG_STOPPED or
         PROGRAM_IS_WAITING or PROGRAM_FLAG_0x20 or PROGRAM_FLAG_0x40)) <> 0 then
        Break;

      Inc(count);
    end;
  except
    on E: EProgramExit do
    begin
      program_^.flags := program_^.flags or PROGRAM_FLAG_EXITED;
    end;
  end;

  currentProgram := nil;
end;

function interpretFindProcedure(prg: PProgram; const name: PAnsiChar): Integer;
var
  procTable: PByte;
  procCount: Integer;
  i: Integer;
  procOffset: Integer;
  procNameOffset: Integer;
  procName: PAnsiChar;
begin
  if prg = nil then
    Exit(-1);

  procTable := prg^.procedures;
  if procTable = nil then
    Exit(-1);

  procCount := fetchLong(procTable, 0);

  for i := 0 to procCount - 1 do
  begin
    procNameOffset := fetchLong(procTable, 4 + i * SizeOf(TProcedure));
    procName := interpretGetName(prg, procNameOffset);
    if (procName <> nil) and (compat_stricmp(procName, name) = 0) then
      Exit(i);
  end;

  Result := -1;
end;

procedure executeProc(program_: PProgram; procedureIndex: Integer);
var
  procedurePtr: PByte;
  procedureFlags: Integer;
  procedureAddress: Integer;
  procOffset: Integer;
  procCount: Integer;
begin
  if program_ = nil then Exit;
  if program_^.procedures = nil then Exit;

  // Get procedure count for bounds check
  procCount := fetchLong(program_^.procedures, 0);
  if (procedureIndex < 0) or (procedureIndex >= procCount) then
  begin
    WriteLn('[EXEC] ERROR: procedureIndex=', procedureIndex, ' out of range (0..', procCount-1, ') in ', program_^.name);
    Exit;
  end;

  // Get pointer to procedure entry in procedure table
  // Layout: 4 bytes count, then array of TProcedure (24 bytes each)
  procOffset := 4 + SizeOf(TProcedure) * procedureIndex;
  procedurePtr := program_^.procedures + procOffset;

  // Get procedure flags (offset 4 in TProcedure = field_4)
  procedureFlags := fetchLong(procedurePtr, 4);

  // Get procedure start address (offset 16 in TProcedure = field_10)
  procedureAddress := fetchLong(procedurePtr, 16);

  // Bounds check: address must be within data
  if (procedureAddress < 0) or (procedureAddress >= program_^.dataSize) then
  begin
    WriteLn('[EXEC] ERROR: addr=', procedureAddress, ' out of bounds (0..', program_^.dataSize-1, ') in ', program_^.name);
    Exit;
  end;

  // Set instruction pointer to procedure start
  program_^.instructionPointer := procedureAddress;
end;

procedure executeProcedure(program_: PProgram; procedureIndex: Integer);
begin
  executeProc(program_, procedureIndex);
end;

procedure runProgram(program_: PProgram);
begin
  if program_ = nil then Exit;

  program_^.flags := program_^.flags or $02;  // PROGRAM_FLAG_0x02
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_EXITED);
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_STOPPED);

  // Set instruction pointer to start procedure (procedure 0)
  executeProc(program_, 0);

  // Add to linked list
  if headProgram = nil then
  begin
    headProgram := program_;
  end
  else
  begin
    program_^.parent := nil;
    program_^.child := headProgram;
    if headProgram <> nil then
      headProgram^.parent := program_;
    headProgram := program_;
  end;
end;

function runScript(name: PAnsiChar): PProgram;
var
  program_: PProgram;
begin
  program_ := allocateProgram(name);
  if program_ = nil then
    Exit(nil);
  runProgram(program_);
  Result := program_;
end;

procedure updatePrograms;
var
  program_: PProgram;
begin
  if interpreterEnabled = 0 then
    Exit;

  program_ := headProgram;
  while program_ <> nil do
  begin
    interpret(program_, -1);
    program_ := program_^.child;
  end;
end;

procedure clearPrograms;
var
  program_, next: PProgram;
begin
  program_ := headProgram;
  while program_ <> nil do
  begin
    next := program_^.child;
    interpretFreeProgram(program_);
    program_ := next;
  end;
  headProgram := nil;
end;

procedure clearTopProgram;
var
  program_: PProgram;
begin
  if headProgram = nil then Exit;
  program_ := headProgram;
  headProgram := program_^.child;
  if headProgram <> nil then
    headProgram^.parent := nil;
  interpretFreeProgram(program_);
end;

function getProgramList(programListLengthPtr: PInteger): PPAnsiChar;
var
  count: Integer;
  program_: PProgram;
  list: PPAnsiChar;
  arr: ^PAnsiChar;
  i: Integer;
begin
  count := 0;
  program_ := headProgram;
  while program_ <> nil do
  begin
    Inc(count);
    program_ := program_^.child;
  end;

  programListLengthPtr^ := count;
  if count = 0 then
    Exit(nil);

  list := PPAnsiChar(mymalloc(SizeOf(PAnsiChar) * count, 'INTRPRET.C', 0));
  arr := Pointer(list);
  program_ := headProgram;
  for i := 0 to count - 1 do
  begin
    PPAnsiChar(PByte(arr) + SizeOf(PAnsiChar) * i)^ := program_^.name;
    program_ := program_^.child;
  end;

  Result := list;
end;

procedure freeProgramList(programList: PPAnsiChar; programListLength: Integer);
begin
  if programList <> nil then
    myfree(programList, 'INTRPRET.C', 0);
end;

function interpretSaveProgramState: Integer;
begin
  // TODO: Stub for now
  Result := 0;
end;

function interpretLoadProgramState: Integer;
begin
  // TODO: Stub for now
  Result := 0;
end;

end.
