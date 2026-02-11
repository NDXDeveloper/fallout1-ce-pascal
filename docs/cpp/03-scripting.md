# Scripting / Interpreter System

This document describes the Fallout 1 CE scripting and interpreter system, covering
the bytecode VM, script management, cross-script exports, library functions, game-specific
opcode extensions, and the named event system.

Source files (C++): `int/intrpret.cc/h`, `game/scripts.cc/h`, `int/export.cc/h`,
`int/intlib.cc/h`, `int/support/intextra.cc/h`, `int/nevs.cc/h`.

Pascal ports: `u_intrpret.pas`, `u_scripts.pas`, `u_export.pas`, `u_intlib.pas`,
`u_intextra.pas`, `u_nevs.pas`.

---

## 1. Interpreter Architecture (`int/intrpret.cc/h`)

### Overview

The interpreter is a **stack-based bytecode virtual machine** that executes `.int` files
compiled from Fallout's SSL scripting language. Each compiled script is a self-contained
program containing bytecode, string tables, identifier tables, and procedure definitions.

The VM uses **cooperative multitasking**: each program runs for a configurable number of
instructions per tick (`cpuBurstSize`, default 10), then yields. A global linked list of
active programs is traversed every game tick by `updatePrograms`.

Error handling in the C++ code uses `setjmp`/`longjmp` for non-local exits from deeply
nested opcode handlers. The Pascal port replaces this with an `EProgramExit` exception class.

### Program Structure (binary layout)

A `.int` file is loaded into a contiguous byte buffer (`data`). The layout is:

```
Offset 0..41     : Header (42 bytes)
Offset 42+       : Procedure table
                     4 bytes: procedure count (big-endian int32)
                     N * 24 bytes: procedure entries (TProcedure records)
After procedures  : Identifier table
                     4 bytes: total size of identifier data
                     Variable-length null-terminated strings
After identifiers : Static string table
                     4 bytes: total size of string data
                     Entries: 2-byte length prefix + null-terminated string
After strings     : Bytecode instructions
```

All multi-byte values in the bytecode are stored **big-endian** (Motorola byte order),
reflecting the original 68000 heritage. The helper functions `fetchWord`, `fetchLong`,
and `fetchFloat` perform the byte-swapping.

### TProgram Record

```pascal
TProgram = record
  name: PAnsiChar;              // Script file path
  data: PByte;                  // Raw .int file contents
  dataSize: Integer;            // Size of data buffer
  parent: PProgram;             // Linked list - previous program
  child: PProgram;              // Linked list - next program
  instructionPointer: Integer;  // Current bytecode offset
  framePointer: Integer;        // Saved stack frame for calls
  basePointer: Integer;         // Local variable base
  staticStrings: PByte;         // Pointer into data: static string table
  dynamicStrings: PByte;        // Separately allocated: runtime strings
  identifiers: PByte;           // Pointer into data: identifier table
  procedures: PByte;            // Pointer into data: procedure table
  waitEnd: LongWord;            // Timer-based wait target
  waitStart: LongWord;          // Timer-based wait start
  field_78: Integer;            // Internal state (-1 initially)
  checkWaitFunc: function;      // Custom wait predicate (replaces timer wait)
  flags: Integer;               // PROGRAM_FLAG_* bitmask
  windowId: Integer;            // Associated managed window
  exited: Boolean;              // True if program has terminated
  stackValues: PProgramStack;   // Primary execution stack
  returnStackValues: PProgramStack; // Separate return address stack
end;
```

### TProgramValue

Every value on the stack is a tagged union:

```pascal
TProgramValue = record
  opcode: opcode_t;    // Type tag (see VALUE_TYPE_* constants)
  case Integer of
    0: (integerValue: Integer);
    1: (floatValue: Single);
    2: (pointerValue: Pointer);
end;
```

Value type tags (the `opcode` field):

| Constant                | Value    | Meaning                    |
|-------------------------|----------|----------------------------|
| `VALUE_TYPE_INT`        | `$C001`  | 32-bit signed integer      |
| `VALUE_TYPE_FLOAT`      | `$A001`  | 32-bit IEEE 754 float      |
| `VALUE_TYPE_STRING`     | `$9001`  | Static string (offset)     |
| `VALUE_TYPE_DYNAMIC_STRING` | `$9801` | Dynamic string (offset) |
| `VALUE_TYPE_PTR`        | `$E001`  | Raw pointer                |

The type tag encodes raw type bits that can be masked with `VALUE_TYPE_MASK = $F7FF`.

### Dual-Stack Architecture

The VM maintains two separate stacks per program:

- **Data stack** (`stackValues`): Used for operand passing, local variables, expressions,
  and function arguments. Opcodes like `PUSH`, `POP`, `DUP`, `SWAP`, `FETCH`, `STORE`
  operate on this stack.
- **Return stack** (`returnStackValues`): Used for storing return addresses, saved frame
  pointers, and saved flags during procedure calls. Opcodes like `POP_RETURN`,
  `POP_ADDRESS`, `POP_FLAGS` operate on this stack.

Both stacks grow dynamically (Pascal `array of TProgramValue` / C++ `std::vector<ProgramValue>`).

### Frame and Base Pointers

The `basePointer` marks the bottom of the current local variable area on the data stack.
When a procedure is called:

1. The current `basePointer` is pushed (`PUSH_BASE`)
2. `basePointer` is set to the current stack length
3. Local variables are allocated on top of the stack
4. `FETCH` and `STORE` opcodes access locals relative to the stack base
5. On return, `POP_TO_BASE` trims the stack back, then `POP_BASE` restores the caller's base

### Opcodes (76 defined, $8000-$804B)

All opcodes have the high bit `$8000` set. The handler lookup subtracts `$8000` to get an
index into the `opcodeHandlers` array (capacity 342, allowing for library extensions).

#### Control Flow

| Opcode                   | Code     | Description                                      |
|--------------------------|----------|--------------------------------------------------|
| `NOOP`                   | `$8000`  | No operation                                     |
| `JUMP`                   | `$8004`  | Unconditional jump (not currently in handlers)    |
| `CALL`                   | `$8005`  | Call procedure by index                          |
| `CALL_AT`                | `$8006`  | Scheduled call (timed)                           |
| `CALL_WHEN`              | `$8007`  | Conditional call                                 |
| `CALLSTART`              | `$8008`  | Call start procedure                             |
| `EXEC`                   | `$8009`  | Execute external script                          |
| `SPAWN`                  | `$800A`  | Spawn child program                              |
| `FORK`                   | `$800B`  | Fork execution                                   |
| `EXIT`                   | `$800E`  | Exit current procedure                           |
| `DETACH`                 | `$800F`  | Detach child program                             |
| `EXIT_PROGRAM`           | `$8010`  | Exit entire program                              |
| `STOP_PROGRAM`           | `$8011`  | Stop program execution (paused)                  |
| `IF`                     | `$802F`  | Pop condition; if 0, jump to offset              |
| `WHILE`                  | `$8030`  | Pop condition; if nonzero, jump to offset         |
| `WAIT`                   | `$8047`  | Suspend program for duration                     |
| `CANCEL`                 | `$8048`  | Cancel a scheduled call                          |
| `CANCEL_ALL`             | `$8049`  | Cancel all scheduled calls                       |

#### Stack Manipulation

| Opcode                   | Code     | Description                                      |
|--------------------------|----------|--------------------------------------------------|
| `PUSH`                   | `$8001`  | Push immediate value from bytecode               |
| `POP`                    | `$801A`  | Discard top of stack                             |
| `DUP`                    | `$801B`  | Duplicate top of stack                           |
| `SWAP`                   | `$8018`  | Swap top two values on data stack                |
| `SWAPA`                  | `$8019`  | Swap top two values on return stack              |
| `DUMP`                   | `$802E`  | Pop N values (count from stack)                  |
| `PUSH_BASE`              | `$802B`  | Push current basePointer                         |
| `POP_BASE`               | `$8029`  | Pop and restore basePointer                      |
| `POP_TO_BASE`            | `$802A`  | Trim stack down to basePointer                   |
| `A_TO_D`                 | `$800C`  | Move value from return stack to data stack       |
| `D_TO_A`                 | `$800D`  | Move value from data stack to return stack       |

#### Return Stack / Procedure Mechanics

| Opcode                              | Code     | Description                              |
|--------------------------------------|----------|------------------------------------------|
| `POP_RETURN`                         | `$801C`  | Pop return address from return stack     |
| `POP_EXIT`                           | `$801D`  | Pop and exit procedure                   |
| `POP_ADDRESS`                        | `$801E`  | Pop address from return stack            |
| `POP_FLAGS`                          | `$801F`  | Pop flags from return stack              |
| `POP_FLAGS_RETURN`                   | `$8020`  | Pop flags + return                       |
| `POP_FLAGS_EXIT`                     | `$8021`  | Pop flags + exit                         |
| `POP_FLAGS_RETURN_EXTERN`            | `$8022`  | Pop flags + return from extern           |
| `POP_FLAGS_EXIT_EXTERN`              | `$8023`  | Pop flags + exit from extern             |
| `POP_FLAGS_RETURN_VAL_EXTERN`        | `$8024`  | Pop flags + return value from extern     |
| `POP_FLAGS_RETURN_VAL_EXIT`          | `$8025`  | Pop flags + return value + exit          |
| `POP_FLAGS_RETURN_VAL_EXIT_EXTERN`   | `$8026`  | Pop flags + return value + exit extern   |
| `CHECK_PROCEDURE_ARGUMENT_COUNT`     | `$8027`  | Validate arg count for called procedure  |
| `LOOKUP_PROCEDURE_BY_NAME`           | `$8028`  | Resolve procedure index from name        |
| `FETCH_PROCEDURE_ADDRESS`            | `$802D`  | Get procedure bytecode address           |

#### Variable Access

| Opcode                   | Code     | Description                                      |
|--------------------------|----------|--------------------------------------------------|
| `FETCH_GLOBAL`           | `$8012`  | Load global variable value                       |
| `STORE_GLOBAL`           | `$8013`  | Store to global variable                         |
| `FETCH_EXTERNAL`         | `$8014`  | Load exported/external variable (cross-script)   |
| `STORE_EXTERNAL`         | `$8015`  | Store to exported/external variable              |
| `EXPORT_VARIABLE`        | `$8016`  | Publish variable to export table                 |
| `EXPORT_PROCEDURE`       | `$8017`  | Publish procedure to export table                |
| `FETCH`                  | `$8032`  | Load local variable (stack-relative)             |
| `STORE`                  | `$8031`  | Store local variable (stack-relative)            |
| `SET_GLOBAL`             | `$802C`  | Set global from inline address                   |

#### Arithmetic

| Opcode     | Code     | Description                      |
|------------|----------|----------------------------------|
| `ADD`      | `$8039`  | a + b                            |
| `SUB`      | `$803A`  | a - b                            |
| `MUL`      | `$803B`  | a * b                            |
| `DIV`      | `$803C`  | a div b (integer, safe for b=0)  |
| `MOD`      | `$803D`  | a mod b (safe for b=0)           |
| `NEGATE`   | `$8046`  | -a (unary negation)              |
| `FLOOR`    | `$8044`  | Truncate float to integer        |

#### Comparison

| Opcode              | Code     | Description           |
|---------------------|----------|-----------------------|
| `EQUAL`             | `$8033`  | a == b -> 0 or 1      |
| `NOT_EQUAL`         | `$8034`  | a != b -> 0 or 1      |
| `LESS_THAN`         | `$8037`  | a < b -> 0 or 1       |
| `GREATER_THAN`      | `$8038`  | a > b -> 0 or 1       |
| `LESS_THAN_EQUAL`   | `$8035`  | a <= b -> 0 or 1      |
| `GREATER_THAN_EQUAL`| `$8036`  | a >= b -> 0 or 1      |

#### Logical and Bitwise

| Opcode          | Code     | Description                    |
|-----------------|----------|--------------------------------|
| `AND`           | `$803E`  | Logical AND (nonzero = true)   |
| `OR`            | `$803F`  | Logical OR                     |
| `NOT`           | `$8045`  | Logical NOT                    |
| `BITWISE_AND`   | `$8040`  | a and b                        |
| `BITWISE_OR`    | `$8041`  | a or b                         |
| `BITWISE_XOR`   | `$8042`  | a xor b                        |
| `BITWISE_NOT`   | `$8043`  | not a (complement)             |

#### Critical Sections

| Opcode                       | Code     | Description                          |
|------------------------------|----------|--------------------------------------|
| `ENTER_CRITICAL_SECTION`     | `$8002`  | Set PROGRAM_FLAG_CRITICAL_SECTION    |
| `LEAVE_CRITICAL_SECTION`     | `$8003`  | Clear PROGRAM_FLAG_CRITICAL_SECTION  |
| `START_CRITICAL`             | `$804A`  | Alternate critical section entry     |
| `END_CRITICAL`               | `$804B`  | Alternate critical section exit      |

### Program Flags

```
PROGRAM_FLAG_EXITED           = $01   Program has finished executing
PROGRAM_FLAG_0x02             = $02   Active / running
PROGRAM_FLAG_0x04             = $04   (internal)
PROGRAM_FLAG_STOPPED          = $08   Execution paused by STOP_PROGRAM
PROGRAM_IS_WAITING            = $10   Suspended (timer or custom wait)
PROGRAM_FLAG_0x20             = $20   UI interaction pending
PROGRAM_FLAG_0x40             = $40   (internal)
PROGRAM_FLAG_CRITICAL_SECTION = $80   In critical section (no preemption)
PROGRAM_FLAG_0x0100           = $0100 (internal)
```

### Procedure Flags

```
PROCEDURE_FLAG_TIMED       = $01   Called on a timer
PROCEDURE_FLAG_CONDITIONAL = $02   Called conditionally
PROCEDURE_FLAG_IMPORTED    = $04   Imported from another script
PROCEDURE_FLAG_EXPORTED    = $08   Exported to other scripts
PROCEDURE_FLAG_CRITICAL    = $10   Runs in a critical section
```

### TProcedure Record (24 bytes)

Each procedure entry in the procedure table is 24 bytes (6 x 4-byte fields):

```
field_0   (offset 0):  Name offset into identifier table
field_4   (offset 4):  Procedure flags (PROCEDURE_FLAG_*)
field_8   (offset 8):  (internal, varies)
field_C   (offset 12): (internal, varies)
field_10  (offset 16): Bytecode address (entry point)
field_14  (offset 20): (internal, varies)
```

### Main Execution Loop (`interpret`)

The `interpret` function runs a single burst of instructions for one program:

1. Check if interpreter is enabled and program is not exited/stopped
2. If program is waiting, check the wait condition (timer or custom function)
3. Execute up to `cpuBurstSize` instructions per call
4. For each instruction:
   - Read 2-byte opcode from `data[instructionPointer]`
   - If it is an opcode (`$8000+`), look up the handler in `opcodeHandlers[opcode - $8000]`
   - If it is a value type tag (`VALUE_TYPE_INT`, `VALUE_TYPE_FLOAT`, etc.), read the
     4-byte immediate value and push it onto the stack
   - Stop if any exit/stop/wait flags are set
5. Catch `EProgramExit` exceptions to handle non-local program termination

### Program Lifecycle

```
allocateProgram(path)        Load .int file, parse tables, allocate stacks
    |
runProgram(program)          Set IP to procedure 0, add to linked list
    |
updatePrograms()             Called each game tick: iterate linked list,
    |                        call interpret() for each active program
    v
interpret(program, -1)       Execute burst of instructions
    |
    v (eventually)
interpretFreeProgram()       Free all memory, notify delete callbacks
```

### Key Functions

| Function                       | Purpose                                            |
|--------------------------------|----------------------------------------------------|
| `allocateProgram(path)`        | Load .int file, parse tables, create TProgram      |
| `interpretFreeProgram(prog)`   | Free program memory, invoke delete callbacks       |
| `runScript(name)`              | Allocate + run (convenience)                       |
| `runProgram(prog)`             | Set flags, execute proc 0, add to linked list      |
| `interpret(prog, a2)`         | Execute one burst of instructions                  |
| `executeProc(prog, idx)`       | Set IP to procedure entry point by index           |
| `executeProcedure(prog, idx)`  | Same as executeProc (wrapper)                      |
| `interpretFindProcedure(prog, name)` | Search procedure table by name              |
| `updatePrograms()`             | Tick all active programs                           |
| `clearPrograms()`              | Free all programs in linked list                   |
| `clearTopProgram()`            | Free only the head program                         |
| `interpretAddFunc(opcode, handler)` | Register an opcode handler (extends the VM)   |
| `interpretSetTimeFunc(fn, tick)` | Set the timer function and tick rate             |
| `interpretSetCPUBurstSize(n)`  | Set instructions per tick (default 10)             |
| `interpretSetFilenameFunc(fn)` | Set path mangling callback                         |
| `interpretSuspendEvents()`     | Increment event suspension counter                 |
| `interpretResumeEvents()`      | Decrement event suspension counter                 |
| `interpretSaveProgramState()`  | Serialize all program state (for save games)       |
| `interpretLoadProgramState()`  | Deserialize program state (for load games)         |
| `interpretRegisterProgramDeleteCallback(cb)` | Register cleanup callback (max 10)    |

### Stack Push/Pop Helpers

```
programStackPushInteger(prog, val)       Push typed int
programStackPushFloat(prog, val)         Push typed float
programStackPushString(prog, str)        Push dynamic string (adds to string table)
programStackPushPointer(prog, ptr)       Push raw pointer

programStackPopInteger(prog) -> int      Pop and coerce (float -> trunc)
programStackPopFloat(prog) -> float      Pop and coerce (int -> float)
programStackPopString(prog) -> PChar     Pop and resolve string offset
programStackPopPointer(prog) -> pointer  Pop raw pointer

programReturnStackPush/Pop Integer/Pointer/Value  (same for return stack)
```

### String Tables

Two string tables exist:

- **Static strings** (`staticStrings`): Compiled into the .int file. Read-only.
  Layout: `[4-byte total size] [2-byte length, string, ...]`

- **Dynamic strings** (`dynamicStrings`): Created at runtime via `interpretAddString`.
  Same layout, but reallocated as strings are added. Used for runtime concatenation,
  format results, etc.

The `interpretGetString` function resolves a string offset given its type tag
(static vs dynamic) and byte offset within the table.

---

## 2. Script Management (`game/scripts.cc/h`)

### Overview

The script management layer sits above the raw interpreter and provides:

- Five categorized script lists (system, spatial, timed, item, critter)
- Game time tracking and advancement
- Script event dispatch and procedure execution
- Timed event queue integration
- Dialog message file loading
- Save/load serialization of all script state

### Script Types

| Constant              | Value | Description                                          |
|-----------------------|-------|------------------------------------------------------|
| `SCRIPT_TYPE_SYSTEM`  | 0     | Global map scripts, run once on map load             |
| `SCRIPT_TYPE_SPATIAL` | 1     | Triggered by proximity (built_tile + radius)         |
| `SCRIPT_TYPE_TIMED`   | 2     | Triggered after a delay                              |
| `SCRIPT_TYPE_ITEM`    | 3     | Attached to items (use, pickup, drop callbacks)      |
| `SCRIPT_TYPE_CRITTER` | 4     | Attached to NPCs (AI, combat, talk behavior)         |

Scripts are stored in `scriptlists[0..4]`, each a linked list of `TScriptListExtent`
nodes. Each extent holds up to **16 scripts** (the `SCRIPT_LIST_EXTENT_SIZE` constant).

### TScript Record

```pascal
TScript = record
  scr_id: Integer;               // Unique script ID (encodes type in bits)
  scr_next: Integer;             // Next script in chain
  u: TScriptUnion;               // Union: spatial data or timed data
    // Spatial: built_tile (packed tile + elevation), radius
    // Timed: time (game ticks until trigger)
  scr_flags: Integer;            // SCRIPT_FLAG_* bitmask
  scr_script_idx: Integer;       // Index into script.lst
  program_: PProgram;            // Loaded bytecode program (nil until loaded)
  scr_oid: Integer;              // Object ID of owner
  scr_local_var_offset: Integer; // Offset into map local vars array
  scr_num_local_vars: Integer;   // Number of local variables
  field_28: Integer;             // (internal)
  action: Integer;               // Current action type
  fixedParam: Integer;           // Parameter passed to timed events
  owner: PObject;                // Game object that owns this script
  source: PObject;               // Source object (who triggered)
  target: PObject;               // Target object (what was targeted)
  actionBeingUsed: Integer;      // Skill/action being applied
  scriptOverrides: Integer;      // If nonzero, default behavior is suppressed
  field_48: Integer;             // (internal)
  howMuch: Integer;              // Damage amount or quantity
  run_info_flags: Integer;       // Runtime flags
  procs: array[0..23] of Integer; // Procedure addresses for each event type
  field_C4..field_DC: Integer;   // (internal fields)
end;
```

### Script List Structure

```
TScriptList
  head -> TScriptListExtent -> TScriptListExtent -> ... -> nil
  tail -> (last extent)
  length: total script count
  nextScriptId: auto-increment ID generator

TScriptListExtent
  scripts: array[0..15] of TScript   (16 slots per extent)
  length: number of used slots
  next: pointer to next extent
```

### Script Procedures (24 event types)

Each script can handle up to 24 event types. The `procs` array stores the bytecode
address for each event handler. The procedure names match the SSL source:

| Index | Constant                    | SSL Name                    | Trigger                         |
|-------|-----------------------------|-----------------------------|----------------------------------|
| 0     | `SCRIPT_PROC_NO_PROC`      | `no_p_proc`                 | (unused placeholder)            |
| 1     | `SCRIPT_PROC_START`         | `start`                     | Script initialization           |
| 2     | `SCRIPT_PROC_SPATIAL`       | `spatial_p_proc`            | Player enters trigger radius    |
| 3     | `SCRIPT_PROC_DESCRIPTION`   | `description_p_proc`        | Object examined                 |
| 4     | `SCRIPT_PROC_PICKUP`        | `pickup_p_proc`             | Object picked up                |
| 5     | `SCRIPT_PROC_DROP`          | `drop_p_proc`               | Object dropped                  |
| 6     | `SCRIPT_PROC_USE`           | `use_p_proc`                | Object used directly            |
| 7     | `SCRIPT_PROC_USE_OBJ_ON`    | `use_obj_on_p_proc`         | Object used on another object   |
| 8     | `SCRIPT_PROC_USE_SKILL_ON`  | `use_skill_on_p_proc`       | Skill used on object            |
| 9     | (reserved)                  | `none_x_bad`                | (unused)                        |
| 10    | (reserved)                  | `none_x_bad`                | (unused)                        |
| 11    | `SCRIPT_PROC_TALK`          | `talk_p_proc`               | NPC conversation initiated      |
| 12    | `SCRIPT_PROC_CRITTER`       | `critter_p_proc`            | NPC idle/behavior tick          |
| 13    | `SCRIPT_PROC_COMBAT`        | `combat_p_proc`             | NPC combat turn                 |
| 14    | `SCRIPT_PROC_DAMAGE`        | `damage_p_proc`             | Object takes damage             |
| 15    | `SCRIPT_PROC_MAP_ENTER`     | `map_enter_p_proc`          | Map loaded                      |
| 16    | `SCRIPT_PROC_MAP_EXIT`      | `map_exit_p_proc`           | Map unloaded                    |
| 17    | `SCRIPT_PROC_CREATE`        | `create_p_proc`             | Object created                  |
| 18    | `SCRIPT_PROC_DESTROY`       | `destroy_p_proc`            | Object destroyed                |
| 19    | (reserved)                  | `none_x_bad`                | (unused)                        |
| 20    | (reserved)                  | `none_x_bad`                | (unused)                        |
| 21    | `SCRIPT_PROC_LOOK_AT`       | `look_at_p_proc`            | Player looks at object          |
| 22    | `SCRIPT_PROC_TIMED`         | `timed_event_p_proc`        | Timed event fires               |
| 23    | `SCRIPT_PROC_MAP_UPDATE`    | `map_update_p_proc`         | Periodic map update (every 600 ticks) |

### Script Requests (cross-system triggers)

Script handlers cannot directly invoke complex game systems (they might be mid-loop).
Instead, they set request flags in `TScriptState.requests`, and the engine processes
them at a safe point via `scripts_check_state`:

| Constant                              | Value    | Action                                  |
|---------------------------------------|----------|-----------------------------------------|
| `SCRIPT_REQUEST_COMBAT`               | `$01`   | Initiate combat                         |
| `SCRIPT_REQUEST_TOWN_MAP`             | `$02`   | Open town map                           |
| `SCRIPT_REQUEST_WORLD_MAP`            | `$04`   | Transition to world map                 |
| `SCRIPT_REQUEST_ELEVATOR`             | `$08`   | Use elevator                            |
| `SCRIPT_REQUEST_EXPLOSION`            | `$10`   | Trigger explosion at tile               |
| `SCRIPT_REQUEST_DIALOG`               | `$20`   | Start dialog with NPC                   |
| `SCRIPT_REQUEST_NO_INITIAL_COMBAT_STATE` | `$40` | Suppress auto-combat on map enter      |
| `SCRIPT_REQUEST_ENDGAME`              | `$80`   | Trigger endgame slideshow               |
| `SCRIPT_REQUEST_LOOTING`              | `$100`  | Open loot container                     |
| `SCRIPT_REQUEST_STEALING`             | `$200`  | Open steal interface                    |
| `SCRIPT_REQUEST_LOCKED`               | `$400`  | Trigger locked-door feedback            |

### TScriptState Record

```pascal
TScriptState = record
  requests: LongWord;             // Bitmask of SCRIPT_REQUEST_*
  combatState1: TSTRUCT_664980;   // Combat initiation parameters
  combatState2: TSTRUCT_664980;   // Secondary combat parameters
  elevatorType: Integer;          // Which elevator to use
  explosionTile: Integer;         // Explosion location
  explosionElevation: Integer;    // Explosion elevation
  explosionMinDamage: Integer;    // Explosion damage range
  explosionMaxDamage: Integer;
  dialogTarget: PObject;          // NPC to talk to
  lootingBy: PObject;             // Who is looting
  lootingFrom: PObject;           // Container being looted
  stealingBy: PObject;            // Who is stealing
  stealingFrom: PObject;          // Target of steal attempt
end;
```

### Game Time

Game time is tracked in **ticks** (1 tick = 0.1 seconds real time).

```
GAME_TIME_TICKS_PER_HOUR = 60 * 60 * 10   = 36,000 ticks/hour
GAME_TIME_TICKS_PER_DAY  = 24 * 36,000    = 864,000 ticks/day
GAME_TIME_TICKS_PER_YEAR = 365 * 864,000  = 315,360,000 ticks/year
```

The game starts at **December 5, 2161, 7:21 AM**.

```
GAME_TIME_START_YEAR   = 2161
GAME_TIME_START_MONTH  = 12   (December)
GAME_TIME_START_DAY    = 5
GAME_TIME_START_HOUR   = 7
GAME_TIME_START_MINUTE = 21
```

Time functions:

| Function                  | Description                                 |
|---------------------------|---------------------------------------------|
| `game_time()`             | Return current game time in ticks           |
| `game_time_date(m,d,y)`  | Decompose ticks into month/day/year         |
| `game_time_hour()`        | Return time as HHMM integer (e.g. 721)     |
| `game_time_hour_str()`    | Return time as "H:MM" string               |
| `inc_game_time(ticks)`    | Advance game time by N ticks               |
| `set_game_time(ticks)`    | Set absolute game time                     |

The `script_chk_timed_events` function increments `fallout_game_time` by 1 every 100ms
of real time (checked via `elapsed_tocks`), and triggers queue processing.

### Background Processing (`doBkProcesses`)

Registered as a GNW background callback, this function:

1. Calls `updatePrograms()` to tick all active script programs
2. Calls `updateWindows()` for managed window animations
3. If the script engine is running and critters are enabled:
   - `script_chk_critters()` - executes one critter script per tick (round-robin)
   - `script_chk_timed_events()` - advances game time and processes the event queue

### Key Functions

| Function                       | Description                                        |
|--------------------------------|----------------------------------------------------|
| `scr_init()`                   | Initialize script lists, load script.lst           |
| `scr_reset()`                  | Reset all script state                             |
| `scr_exit()`                   | Clean up all scripts                               |
| `scr_new(sidPtr, type)`        | Create a new script, return its ID                 |
| `scr_remove(sid)`              | Remove and free a script                           |
| `scr_remove_all()`             | Remove all scripts                                 |
| `scr_ptr(sid, scriptPtr)`      | Look up script by ID                               |
| `scr_set_objs(sid, src, tgt)`  | Set source and target objects                      |
| `scr_set_ext_param(sid, val)`  | Set the fixedParam (passed to timed events)        |
| `exec_script_proc(sid, proc)`  | Execute a specific procedure on a script           |
| `loadProgram(name)`            | Load a .int file from the scripts directory        |
| `script_q_add(sid, delay, param)` | Add a timed script event to the queue           |
| `scr_load(stream)`             | Deserialize all scripts from save file             |
| `scr_save(stream)`             | Serialize all scripts to save file                 |
| `scr_game_save(stream)`        | Save game-level script state                       |
| `scr_game_load(stream)`        | Load game-level script state                       |
| `scr_load_all_scripts()`       | Load .int programs for all scripts on map          |
| `scr_exec_map_enter_scripts()` | Fire MAP_ENTER proc on all scripts                 |
| `scr_exec_map_update_scripts()`| Fire MAP_UPDATE proc on all scripts                |
| `scr_exec_map_exit_scripts()`  | Fire MAP_EXIT proc on all scripts                  |
| `scr_get_dialog_msg_file(id, ptr)` | Get message list for dialog                    |
| `scr_get_msg_str(listId, msgId)` | Get localized string from script messages        |
| `scr_find_sid_from_program(prog)` | Reverse-lookup: program -> script ID            |
| `scr_find_obj_from_program(prog)` | Reverse-lookup: program -> owner object         |
| `scr_chk_spatials_in(obj, tile, elev)` | Check spatial triggers at location        |
| `scr_end_combat()`             | Request combat end from script                     |
| `scr_explode_scenery(obj, tile, r, elev)` | Trigger scenery explosions in radius   |
| `scr_enable() / scr_disable()` | Enable/disable the script engine                  |
| `scr_enable_critters() / scr_disable_critters()` | Enable/disable NPC AI scripts     |

### Script ID Encoding

Script IDs encode the script type in their upper bits. The `SID_TYPE` macro extracts the
type from a script ID. Each script type has its own ID namespace within `scriptlists[type]`.

### Spatial Scripts

Spatial scripts use `built_tile` (a packed value encoding tile index + elevation) and
`radius`. The function `tile_in_tile_bound(tile1, radius, tile2)` checks whether `tile2`
is within `radius` hexes of `tile1`. When the player moves, `scr_chk_spatials_in` iterates
all spatial scripts and fires `SCRIPT_PROC_SPATIAL` for any whose trigger area contains
the player.

---

## 3. Export System (`int/export.cc/h`)

### Overview

The export system allows scripts to share variables and procedures across script boundaries.
It uses two hash tables (size 1013 each) with open addressing (step size 7) and
case-insensitive name matching.

### Data Structures

```pascal
TExternalVariable = record
  name: array[0..31] of AnsiChar;   // Variable name (max 31 chars)
  programName: PAnsiChar;           // Owning program's name
  value: TProgramValue;             // Current value
  stringValue: PAnsiChar;           // Copy of string value (if string type)
end;

TExternalProcedure = record
  name: array[0..31] of AnsiChar;   // Procedure name
  program_: PProgram;               // Owning program
  argumentCount: Integer;           // Number of arguments
  address: Integer;                 // Bytecode address
end;
```

### Functions

| Function                                    | Description                              |
|---------------------------------------------|------------------------------------------|
| `initExport()`                              | Register cleanup callback                |
| `exportClose()`                             | Free all variable string storage         |
| `exportExportVariable(prog, name)`          | Publish a variable (creates entry)       |
| `exportFetchVariable(prog, name, value)`    | Read an exported variable                |
| `exportStoreVariable(prog, name, value)`    | Write to an exported variable            |
| `exportExportProcedure(prog, name, addr, argc)` | Publish a procedure                 |
| `exportFindProcedure(name, addr, argc)`     | Look up an exported procedure            |
| `exportClearAllVariables()`                 | Clear all exported variables             |

### Hash Algorithm

The hash function processes each character of the identifier (lowercased), accumulating:

```
hash = hash + char + (hash * 8) + (hash >> 29)
```

The result is taken modulo 1013. Collisions are resolved by linear probing with step 7.

### Lifetime Management

When a program is freed, `exportRemoveProgramReferences` is called (registered as a
program delete callback). This clears all procedure entries owned by the freed program.
Variable entries are NOT automatically removed (they persist as long as their value is
needed by other scripts).

---

## 4. Script Library (`int/intlib.cc/h`)

### Overview

The script library (`intlib`) registers opcode handlers in the range `$804C`-`$80A0`.
These provide mid-level functionality: window management, dialog trees, palette effects,
movie playback, region/button UI, sound, mouse control, named events, and keyboard input.

### Opcode Groups Registered by `initIntlib`

#### Window Operations ($8062-$806D)

| Opcode | Handler              | Description                              |
|--------|----------------------|------------------------------------------|
| $8062  | `op_createwin`       | Create a managed window                  |
| $8063  | `op_deletewin`       | Delete a managed window                  |
| $8064  | `op_selectwin`       | Set active window for drawing            |
| $8065  | `op_resizewin`       | Resize a window                          |
| $8066  | `op_scalewin`        | Scale a window                           |
| $8067  | `op_showwin`         | Make window visible                      |
| $8068  | `op_fillwin`         | Fill window with color                   |
| $8069  | `op_fillrect`        | Fill a rectangle                         |
| $806A  | `op_fillwin3x3`      | Fill window with 3x3 tiled image         |
| $806B  | `op_display`         | Display an image file                    |
| $806C  | `op_displaygfx`      | Display graphics at position             |
| $806D  | `op_displayraw`      | Display raw (unprocessed) image          |

#### Text Operations ($8072-$8078)

| Opcode | Handler               | Description                             |
|--------|-----------------------|-----------------------------------------|
| $8071  | `op_gotoxy`           | Set text cursor position                |
| $8072  | `op_print`            | Print value (int/float/string)          |
| $8073  | `op_format`           | Print with alignment and bounds         |
| $8074  | `op_printrect`        | Print text in rectangle                 |
| $8075  | `op_setfont`          | Set current font                        |
| $8076  | `op_settextflags`     | Set text rendering flags                |
| $8077  | `op_settextcolor`     | Set text color                          |
| $8078  | `op_sethighlightcolor`| Set text highlight color                |

#### Palette and Fade ($806E-$8070)

| Opcode | Handler                | Description                            |
|--------|------------------------|----------------------------------------|
| $806E  | `op_loadpalettetable`  | Load palette from file                 |
| $806F  | `op_fadein`            | Fade screen in from black              |
| $8070  | `op_fadeout`           | Fade screen out to black               |

#### Movie ($8079-$807C)

| Opcode | Handler              | Description                              |
|--------|----------------------|------------------------------------------|
| $8079  | `op_stopmovie`       | Stop currently playing movie             |
| $807A  | `op_playmovie`       | Play a movie file                        |
| $807B  | `op_movieflags`      | Set movie playback flags                 |
| $807C  | `op_playmovierect`   | Play movie in a specific rectangle       |

#### Region/Button UI ($807F-$8091)

| Opcode | Handler                  | Description                          |
|--------|--------------------------|--------------------------------------|
| $807F  | `op_addregion`           | Add a clickable region               |
| $8080  | `op_addregionflag`       | Set region flags                     |
| $8081  | `op_addregionproc`       | Set left-click handler for region    |
| $8082  | `op_addregionrightproc`  | Set right-click handler for region   |
| $8083  | `op_deleteregion`        | Remove a region                      |
| $8084  | `op_activateregion`      | Enable/disable a region              |
| $8085  | `op_checkregion`         | Test if point is in a region         |
| $8086  | `op_addbutton`           | Create a button                      |
| $8087  | `op_addbuttontext`       | Set button label text                |
| $8088  | `op_addbuttonflag`       | Set button flags                     |
| $8089  | `op_addbuttongfx`        | Set button graphics                  |
| $808A  | `op_addbuttonproc`       | Set button click handler             |
| $808B  | `op_addbuttonrightproc`  | Set button right-click handler       |
| $808C  | `op_deletebutton`        | Remove a button                      |
| $808D  | `op_hidemouse`           | Hide mouse cursor                    |
| $808E  | `op_showmouse`           | Show mouse cursor                    |
| $808F  | `op_mouseshape`          | Set mouse cursor shape               |
| $8090  | `op_refreshmouse`        | Refresh mouse cursor display         |
| $8091  | `op_setglobalmousefunc`  | Set global mouse handler             |

#### Dialog / Say System ($804C-$8061)

| Opcode | Handler                 | Description                           |
|--------|-------------------------|---------------------------------------|
| $804C  | `op_sayquit`            | Abort dialog                          |
| $804D  | `op_sayend`             | End dialog (process choices)          |
| $804E  | `op_saystart`           | Begin a dialog tree                   |
| $804F  | `op_saystartpos`        | Begin dialog at position              |
| $8050  | `op_sayreplytitle`      | Set reply title text                  |
| $8051  | `op_saygotoreply`       | Jump to a reply node                  |
| $8052  | `op_sayreply`           | Add a reply option                    |
| $8053  | `op_sayoption`          | Add a player choice                   |
| $8054  | `op_saymessage`         | Display a dialog message              |
| $8055  | `op_sayreplywindow`     | Set reply window parameters           |
| $8056  | `op_sayoptionwindow`    | Set option window parameters          |
| $8057  | `op_sayborder`          | Set dialog border                     |
| $8058  | `op_sayscrollup`        | Set scroll-up button                  |
| $8059  | `op_sayscrolldown`      | Set scroll-down button                |
| $805A  | `op_saysetspacing`      | Set text line spacing                 |
| $805B  | `op_sayoptioncolor`     | Set option text color                 |
| $805C  | `op_sayreplycolor`      | Set reply text color                  |
| $805D  | `op_sayrestart`         | Restart dialog                        |
| $805E  | `op_saygetlastpos`      | Get last cursor position              |
| $805F  | `op_sayreplyflags`      | Set reply flags                       |
| $8060  | `op_sayoptionflags`     | Set option flags                      |
| $8061  | `op_saymessagetimeout`  | Set message display timeout           |

#### Named Events ($8092-$8095)

| Opcode | Handler              | Description                              |
|--------|----------------------|------------------------------------------|
| $8092  | `op_addNamedEvent`   | Register a named event listener          |
| $8093  | `op_addNamedHandler` | Register a named event handler           |
| $8094  | `op_clearNamed`      | Remove a named event                     |
| $8095  | `op_signalNamed`     | Fire a named event                       |

#### Keyboard ($8096-$8097)

| Opcode | Handler         | Description                                   |
|--------|-----------------|-----------------------------------------------|
| $8096  | `op_addkey`     | Register a key handler (key -> procedure)      |
| $8097  | `op_deletekey`  | Remove a key handler                           |

#### Sound ($8098-$809D)

| Opcode | Handler            | Description                                |
|--------|--------------------|--------------------------------------------|
| $8098  | `op_soundplay`     | Play a sound file                          |
| $8099  | `op_soundpause`    | Pause a sound                              |
| $809A  | `op_soundresume`   | Resume a paused sound                      |
| $809B  | `op_soundstop`     | Stop a sound                               |
| $809C  | `op_soundrewind`   | Rewind a sound to beginning                |
| $809D  | `op_sounddelete`   | Delete a sound resource                    |

#### Misc ($809E-$80A0)

| Opcode | Handler               | Description                             |
|--------|-----------------------|-----------------------------------------|
| $809E  | `op_setoneoptpause`   | Set one-option dialog pause             |
| $809F  | `op_selectfilelist`   | Show file selection dialog              |
| $80A0  | `op_tokenize`         | Split string into tokens                |

### Palette Functions (exposed to game code)

| Function                        | Description                              |
|---------------------------------|------------------------------------------|
| `interpretFadePalette(old, new, a3, duration)` | Smooth palette transition   |
| `interpretFadeIn(duration)`     | Fade screen in from black                |
| `interpretFadeOut(duration)`    | Fade screen out to black                 |
| `interpretFadeInNoBK(duration)` | Fade in without background processing    |
| `interpretFadeOutNoBK(duration)`| Fade out without background processing   |
| `intlibGetFadeIn()`             | Return current fade-in state             |

### Utility Functions

| Function                        | Description                              |
|---------------------------------|------------------------------------------|
| `checkMovie(prog)`              | Check if a movie is still playing        |
| `getTimeOut() / setTimeOut(v)`  | Get/set dialog timeout                   |
| `soundStartInterpret(fn, mode)` | Start a sound from script context        |
| `soundCloseInterpret()`         | Close all script sounds                  |
| `updateIntLib()`                | Per-tick update                          |
| `intlibClose()`                 | Shut down the library                    |
| `initIntlib()`                  | Register all opcodes, init subsystems    |

### Initialization Chain

`initIntlib()` performs:
1. Register the keyboard input handler (`windowAddInputFunc`)
2. Register all ~80 opcode handlers via `interpretAddFunc`
3. Call `nevs_initonce()` to initialize the named event system
4. Call `initIntExtra()` to register game-specific opcodes
5. Call `initDialog()` to initialize the dialog subsystem

---

## 5. Game-Specific Script Functions (`int/support/intextra.cc/h`)

### Overview

This is the **largest file** in the scripting system. It registers ~181 opcode handlers
in the range `$80A1`-`$8155`, covering all game-specific functionality exposed to the
SSL scripting language. These opcodes bridge the VM to every major game system.

### Opcode Groups (by game system)

#### Experience and Stats ($80A1, $80A5-$80A6, $80AA-$80B1, $80CA-$80CB)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $80A1  | `op_give_exp_points`       | `give_exp_points`          |
| $80A6  | `op_get_pc_stat`           | `get_pc_stat`              |
| $80AA  | `op_has_skill`             | `has_skill`                |
| $80AB  | `op_using_skill`           | `using_skill`              |
| $80AC  | `op_roll_vs_skill`         | `roll_vs_skill`            |
| $80AD  | `op_skill_contest`         | `skill_contest`            |
| $80AE  | `op_do_check`              | `do_check`                 |
| $80AF  | `op_is_success`            | `is_success`               |
| $80B0  | `op_is_critical`           | `is_critical`              |
| $80B1  | `op_how_much`              | `how_much`                 |
| $80CA  | `op_get_critter_stat`      | `get_critter_stat`         |
| $80CB  | `op_set_critter_stat`      | `set_critter_stat`         |
| $813C  | `op_critter_mod_skill`     | `critter_mod_skill`        |

#### Script Control ($80A2, $80B9, $80BC-$80BF, $80C0-$80C7, $80F7, $80FA)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $80A2  | `op_scr_return`            | `scr_return`               |
| $80B9  | `op_script_overrides`      | `script_overrides`         |
| $80BC  | `op_self_obj`              | `self_obj`                 |
| $80BD  | `op_source_obj`            | `source_obj`               |
| $80BE  | `op_target_obj`            | `target_obj`               |
| $80BF  | `op_dude_obj`              | `dude_obj`                 |
| $80C0  | `op_obj_being_used_with`   | `obj_being_used_with`      |
| $80C1  | `op_local_var`             | `local_var`                |
| $80C2  | `op_set_local_var`         | `set_local_var`            |
| $80C3  | `op_map_var`               | `map_var`                  |
| $80C4  | `op_set_map_var`           | `set_map_var`              |
| $80C5  | `op_global_var`            | `global_var`               |
| $80C6  | `op_set_global_var`        | `set_global_var`           |
| $80C7  | `op_script_action`         | `script_action`            |
| $80F7  | `op_fixed_param`           | `fixed_param`              |
| $80FA  | `op_action_being_used`     | `action_being_used`        |

#### Object Manipulation ($80A4, $80A7-$80A9, $80B6-$80B8, $80C8-$80C9, $80D4-$80D9, $80E3, $8100, $8104, $8149)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80A4  | `op_obj_name`                    | `obj_name`                  |
| $80A7  | `op_tile_contains_pid_obj`       | `tile_contains_pid_obj`     |
| $80B6  | `op_move_to`                     | `move_to`                   |
| $80B7  | `op_create_object_sid`           | `create_object_sid`         |
| $80B8  | `op_display_msg`                 | `display_msg`               |
| $80BA  | `op_obj_is_carrying_obj_pid`     | `obj_is_carrying_obj_pid`   |
| $80BB  | `op_tile_contains_obj_pid`       | `tile_contains_obj_pid`     |
| $80C8  | `op_obj_type`                    | `obj_type`                  |
| $80C9  | `op_obj_item_subtype`            | `obj_item_subtype`          |
| $80D4  | `op_tile_num`                    | `tile_num`                  |
| $80D5  | `op_tile_num_in_direction`       | `tile_num_in_direction`     |
| $80D6  | `op_pickup_obj`                  | `pickup_obj`                |
| $80D7  | `op_drop_obj`                    | `drop_obj`                  |
| $80D8  | `op_add_obj_to_inven`            | `add_obj_to_inven`          |
| $80D9  | `op_rm_obj_from_inven`           | `rm_obj_from_inven`         |
| $80DA  | `op_wield_obj_critter`           | `wield_obj_critter`         |
| $80DB  | `op_use_obj`                     | `use_obj`                   |
| $80E3  | `op_set_obj_visibility`          | `set_obj_visibility`        |
| $80F4  | `op_destroy_object`              | `destroy_object`            |
| $8100  | `op_obj_pid`                     | `obj_pid`                   |
| $8104  | `op_proto_data`                  | `proto_data`                |
| $8107  | `op_obj_set_light_level`         | `obj_set_light_level`       |
| $8144  | `op_destroy_mult_objs`           | `destroy_mult_objs`         |
| $8145  | `op_use_obj_on_obj`              | `use_obj_on_obj`            |
| $8147  | `op_move_obj_inven_to_obj`       | `move_obj_inven_to_obj`     |
| $8149  | `op_obj_art_fid`                 | `obj_art_fid`               |
| $814A  | `op_art_anim`                    | `art_anim`                  |
| $8150  | `op_obj_on_screen`               | `obj_on_screen`             |

#### Animation ($80CC-$80CF, $810C-$8114, $8126, $813A-$813B)

| Opcode | Handler                             | SSL Function                   |
|--------|-------------------------------------|--------------------------------|
| $80CC  | `op_animate_stand_obj`              | `animate_stand_obj`            |
| $80CD  | `op_animate_stand_reverse_obj`      | `animate_stand_reverse_obj`    |
| $80CE  | `op_animate_move_obj_to_tile`       | `animate_move_obj_to_tile`     |
| $80CF  | `op_animate_jump`                   | `animate_jump`                 |
| $810C  | `op_anim`                           | `anim`                         |
| $810E  | `op_reg_anim_func`                  | `reg_anim_func`                |
| $810F  | `op_reg_anim_animate`               | `reg_anim_animate`             |
| $8110  | `op_reg_anim_animate_reverse`       | `reg_anim_animate_reverse`     |
| $8111  | `op_reg_anim_obj_move_to_obj`       | `reg_anim_obj_move_to_obj`     |
| $8112  | `op_reg_anim_obj_run_to_obj`        | `reg_anim_obj_run_to_obj`      |
| $8113  | `op_reg_anim_obj_move_to_tile`      | `reg_anim_obj_move_to_tile`    |
| $8114  | `op_reg_anim_obj_run_to_tile`       | `reg_anim_obj_run_to_tile`     |
| $8126  | `op_reg_anim_animate_forever`       | `reg_anim_animate_forever`     |
| $813A  | `op_anim_action_frame`              | `anim_action_frame`            |
| $813B  | `op_reg_anim_play_sfx`              | `reg_anim_play_sfx`            |

#### Combat ($80D0, $80E7, $80ED-$80EF, $80FB, $8128, $8143, $8151-$8155)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80D0  | `op_attack`                      | `attack`                    |
| $80DD  | `op_attack`                      | `attack` (alternate entry)  |
| $80E7  | `op_anim_busy`                   | `anim_busy`                 |
| $80ED  | `op_kill_critter`                | `kill_critter`              |
| $80EE  | `op_kill_critter_type`           | `kill_critter_type`         |
| $80EF  | `op_critter_damage`              | `critter_damage`            |
| $80FB  | `op_critter_state`               | `critter_state`             |
| $8128  | `op_combat_is_initialized`       | `combat_is_initialized`     |
| $8143  | `op_attack_setup`                | `attack_setup`              |
| $8151  | `op_critter_is_fleeing`          | `critter_is_fleeing`        |
| $8152  | `op_critter_set_flee_state`      | `critter_set_flee_state`    |
| $8153  | `op_terminate_combat`            | `terminate_combat`          |
| $8155  | `op_critter_stop_attacking`      | `critter_stop_attacking`    |

#### Critter / NPC ($80E8, $80F3, $80FD-$80FF, $8102-$8103, $8106, $8122-$8127)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80E8  | `op_critter_heal`                | `critter_heal`              |
| $80F3  | `op_has_trait`                   | `has_trait`                 |
| $80F5  | `op_obj_can_hear_obj`            | `obj_can_hear_obj`          |
| $80DC  | `op_obj_can_see_obj`             | `obj_can_see_obj`           |
| $80FD  | `op_radiation_inc`               | `radiation_inc`             |
| $80FE  | `op_radiation_dec`               | `radiation_dec`             |
| $80FF  | `op_critter_attempt_placement`   | `critter_attempt_placement` |
| $8102  | `op_critter_add_trait`           | `critter_add_trait`         |
| $8103  | `op_critter_rm_trait`            | `critter_rm_trait`          |
| $8106  | `op_critter_inven_obj`           | `critter_inven_obj`         |
| $8122  | `op_poison`                      | `poison`                    |
| $8123  | `op_get_poison`                  | `get_poison`                |
| $8127  | `op_critter_injure`              | `critter_injure`            |

#### Dialog ($80DE-$80E0, $80F9, $811C-$8121, $8129, $814E)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80DE  | `op_start_gdialog`               | `start_gdialog`             |
| $80DF  | `op_end_dialogue`                | `end_dialogue`              |
| $80E0  | `op_dialogue_reaction`           | `dialogue_reaction`         |
| $80F9  | `op_dialogue_system_enter`        | `dialogue_system_enter`     |
| $811C  | `op_gsay_start`                  | `gsay_start`                |
| $811D  | `op_gsay_end`                    | `gsay_end`                  |
| $811E  | `op_gsay_reply`                  | `gsay_reply`                |
| $811F  | `op_gsay_option`                 | `gsay_option`               |
| $8120  | `op_gsay_message`                | `gsay_message`              |
| $8121  | `op_giq_option`                  | `giq_option`                |
| $8129  | `op_gdialog_barter`              | `gdialog_barter`            |
| $814E  | `op_gdialog_set_barter_mod`      | `gdialog_set_barter_mod`    |

#### Time ($80D1, $80EA-$80EB, $80F2, $80F6, $80FC, $8118-$8119, $811B)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $80D1  | `op_make_daytime`          | `make_daytime`             |
| $80EA  | `op_game_time`             | `game_time`                |
| $80EB  | `op_game_time_in_seconds`  | `game_time_in_seconds`     |
| $80F2  | `op_game_ticks`            | `game_ticks`               |
| $80F6  | `op_game_time_hour`        | `game_time_hour`           |
| $80FC  | `op_game_time_advance`     | `game_time_advance`        |
| $80F0  | `op_add_timer_event`       | `add_timer_event`          |
| $80F1  | `op_rm_timer_event`        | `rm_timer_event`           |
| $8118  | `op_get_month`             | `get_month`                |
| $8119  | `op_get_day`               | `get_day`                  |
| $811B  | `op_days_since_visited`    | `days_since_visited`       |

#### Map / Tile ($80A8-$80A9, $80D2-$80D3, $80E1-$80E2, $80E4, $80EC, $80F8, $8101, $8108-$8109, $814C)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80A8  | `op_set_map_start`               | `set_map_start`             |
| $80A9  | `op_override_map_start`          | `override_map_start`        |
| $80D2  | `op_tile_distance`               | `tile_distance`             |
| $80D3  | `op_tile_distance_objs`          | `tile_distance_objs`        |
| $80E1  | `op_turn_off_objs_in_area`       | `turn_off_objs_in_area`     |
| $80E2  | `op_turn_on_objs_in_area`        | `turn_on_objs_in_area`      |
| $80E4  | `op_load_map`                    | `load_map`                  |
| $80EC  | `op_elevation`                   | `elevation`                 |
| $80F8  | `op_tile_is_visible`             | `tile_is_visible`           |
| $8101  | `op_cur_map_index`               | `cur_map_index`             |
| $8108  | `op_world_map`                   | `world_map`                 |
| $8109  | `op_town_map`                    | `town_map`                  |
| $814C  | `op_rotation_to_tile`            | `rotation_to_tile`          |

#### Inventory / Items ($80E5-$80E6, $8116-$8117, $8124-$8125, $8138-$8139, $812C)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80E5  | `op_barter_offer`                | `barter_offer`              |
| $80E6  | `op_barter_asking`               | `barter_asking`             |
| $8116  | `op_add_mult_objs_to_inven`      | `add_mult_objs_to_inven`   |
| $8117  | `op_rm_mult_objs_from_inven`     | `rm_mult_objs_from_inven`  |
| $8124  | `op_party_add`                   | `party_add`                 |
| $8125  | `op_party_remove`                | `party_remove`              |
| $8138  | `op_item_caps_total`             | `item_caps_total`           |
| $8139  | `op_item_caps_adjust`            | `item_caps_adjust`          |
| $812C  | `op_inven_unwield`               | `inven_unwield`             |
| $814B  | `op_party_member_obj`            | `party_member_obj`          |

#### Lock / Door ($812D-$8132)

| Opcode | Handler                | SSL Function         |
|--------|------------------------|----------------------|
| $812D  | `op_obj_is_locked`     | `obj_is_locked`      |
| $812E  | `op_obj_lock`          | `obj_lock`           |
| $812F  | `op_obj_unlock`        | `obj_unlock`         |
| $8130  | `op_obj_is_open`       | `obj_is_open`        |
| $8131  | `op_obj_open`          | `obj_open`           |
| $8132  | `op_obj_close`         | `obj_close`          |
| $814D  | `op_jam_lock`          | `jam_lock`           |

#### UI ($8133-$8137, $810A-$810B)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $8133  | `op_game_ui_disable`       | `game_ui_disable`          |
| $8134  | `op_game_ui_enable`        | `game_ui_enable`           |
| $8135  | `op_game_ui_is_disabled`   | `game_ui_is_disabled`      |
| $8136  | `op_gfade_out`             | `gfade_out`                |
| $8137  | `op_gfade_in`              | `gfade_in`                 |
| $810A  | `op_float_msg`             | `float_msg`                |
| $810B  | `op_metarule`              | `metarule`                 |
| $810D  | `op_obj_carrying_pid_obj`  | `obj_carrying_pid_obj`     |
| $8154  | `op_debug_msg`             | `debug_msg`                |

#### Sound ($80A3, $80A5, $813D-$8142)

| Opcode | Handler                          | SSL Function                |
|--------|----------------------------------|-----------------------------|
| $80A3  | `op_play_sfx`                    | `play_sfx`                  |
| $80A5  | `op_sfx_build_open_name`         | `sfx_build_open_name`       |
| $813D  | `op_sfx_build_char_name`         | `sfx_build_char_name`       |
| $813E  | `op_sfx_build_ambient_name`      | `sfx_build_ambient_name`    |
| $813F  | `op_sfx_build_interface_name`    | `sfx_build_interface_name`  |
| $8140  | `op_sfx_build_item_name`         | `sfx_build_item_name`       |
| $8141  | `op_sfx_build_weapon_name`       | `sfx_build_weapon_name`     |
| $8142  | `op_sfx_build_scenery_name`      | `sfx_build_scenery_name`    |

#### Reaction / Random ($80B2-$80B5)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $80B2  | `op_reaction_roll`         | `reaction_roll`            |
| $80B3  | `op_reaction_influence`    | `reaction_influence`       |
| $80B4  | `op_random`                | `random`                   |
| $80B5  | `op_roll_dice`             | `roll_dice`                |

#### Lighting / Explosion ($80E9, $811A, $80F0-$80F1, $8105)

| Opcode | Handler                    | SSL Function               |
|--------|----------------------------|----------------------------|
| $80E9  | `op_set_light_level`       | `set_light_level`          |
| $811A  | `op_explosion`             | `explosion`                |
| $8105  | `op_message_str`           | `message_str`              |

#### Endgame / Movie ($8115, $8146, $8148, $812B, $814F-$812A)

| Opcode | Handler                       | SSL Function                  |
|--------|-------------------------------|-------------------------------|
| $8115  | `op_play_gmovie`              | `play_gmovie`                 |
| $8146  | `op_endgame_slideshow`        | `endgame_slideshow`           |
| $8148  | `op_endgame_movie`            | `endgame_movie`               |
| $812A  | `op_difficulty_level`         | `difficulty_level`            |
| $812B  | `op_running_burning_guy`      | `running_burning_guy`         |
| $814F  | `op_combat_difficulty`        | `combat_difficulty`           |

### Error Handling

The `dbg_error` function logs script errors with standardized categories:

```
SCRIPT_ERROR_NOT_IMPLEMENTED           = 0  "unimped"
SCRIPT_ERROR_OBJECT_IS_NULL            = 1  "obj is NULL"
SCRIPT_ERROR_CANT_MATCH_PROGRAM_TO_SID = 2  "can't match program to sid"
SCRIPT_ERROR_FOLLOWS                   = 3  "follows"
```

Error format: `"Script Error: <script_name>: op_<function>: <error_string>"`

---

## 6. Named Event System (`int/nevs.cc/h`)

### Overview

The named event system (`nevs`) provides a simple **publish-subscribe** mechanism for
inter-script communication. Events are identified by string names (max 31 characters,
case-insensitive). The system supports up to **40 concurrent events** (`NEVS_COUNT`).

### Event Types

| Constant            | Value | Behavior                                         |
|---------------------|-------|--------------------------------------------------|
| `NEVS_TYPE_EVENT`   | 0     | One-shot: automatically freed after firing       |
| `NEVS_TYPE_HANDLER` | 1     | Persistent: survives firing, can fire repeatedly |

### TNevs Record

```pascal
TNevs = record
  used: Boolean;                 // Slot is active
  name: array[0..31] of AnsiChar; // Event name
  program_: PProgram;            // Script that registered the handler
  proc: Integer;                 // Procedure index to call
  type_: Integer;                // NEVS_TYPE_EVENT or NEVS_TYPE_HANDLER
  hits: Integer;                 // Pending signal count
  busy: Boolean;                 // True while handler is executing
  callback: TNevsCallback;       // Alternative: native callback (nil for scripts)
end;
```

### Functions

| Function                             | Description                                |
|--------------------------------------|--------------------------------------------|
| `nevs_initonce()`                    | Allocate event table, register cleanup     |
| `nevs_close()`                       | Free event table                           |
| `nevs_addevent(name, prog, proc, type)` | Register a script event handler         |
| `nevs_addCevent(name, callback, type)`  | Register a native C callback handler    |
| `nevs_clearevent(name)`             | Remove an event by name                    |
| `nevs_signal(name)`                  | Signal an event (increments hit count)     |
| `nevs_update()`                      | Process all pending signals                |

### Execution Flow

1. **Registration**: A script calls `nevs_addevent` (via `op_addNamedEvent` or
   `op_addNamedHandler` opcodes) to register interest in a named event.

2. **Signaling**: Any script calls `nevs_signal` (via `op_signalNamed`) with an event name.
   This increments the `hits` counter and the global `anyhits` counter.

3. **Processing**: `nevs_update` is called during the main update loop. For each event
   with pending hits:
   - Set `busy = True` (prevents re-entrant signaling)
   - Decrement `hits`, call the handler (`executeProc` or native callback)
   - Set `busy = False`
   - If `type_ = NEVS_TYPE_EVENT`, free the slot (one-shot)
   - If `type_ = NEVS_TYPE_HANDLER`, keep the slot (persistent)

4. **Cleanup**: When a program is freed, `nevs_removeprogramreferences` clears all
   events registered by that program (registered as a program delete callback).

### Thread Safety Note

The `busy` flag prevents a handler from being re-signaled while it is executing. This
avoids infinite recursion if a handler signals its own event.

---

## System Interaction Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│  Game Loop (doBkProcesses - background tick)                        │
│    1. updatePrograms()  -->  interpret() for each active Program    │
│    2. updateWindows()                                                │
│    3. script_chk_critters()  -->  exec_script_proc(CRITTER/COMBAT)  │
│    4. script_chk_timed_events()  -->  queue_process()               │
└─────────────────────┬────────────────────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │     interpret()        │
          │  fetch opcode          │
          │  dispatch to handler   │
          └───────────┬───────────┘
                      │
     ┌────────────────┼────────────────┐
     │                │                │
 Core Opcodes    intlib Opcodes    intextra Opcodes
 ($8000-$804B)   ($804C-$80A0)    ($80A1-$8155)
 Control flow,   Window, dialog,  Game-specific:
 arithmetic,     palette, sound,  combat, dialog,
 variables,      movie, region,   inventory, map,
 stack ops       named events     critter, time...
     │                │                │
     │         ┌──────┴──────┐         │
     │         │ nevs system │         │
     │         │ (pub/sub)   │         │
     │         └─────────────┘         │
     │                                 │
     └────────────────┬────────────────┘
                      │
              ┌───────┴───────┐
              │ export system  │
              │ (cross-script  │
              │  variables &   │
              │  procedures)   │
              └───────────────┘
```

---

## Opcode Address Space Summary

| Range           | Count | Module     | Purpose                              |
|-----------------|-------|------------|--------------------------------------|
| `$8000-$804B`   | 76    | intrpret   | Core VM operations                   |
| `$804C-$80A0`   | 85    | intlib     | Library: window, dialog, sound, etc. |
| `$80A1-$8155`   | 181   | intextra   | Game-specific script functions        |
| **Total**       | **342** | —        | Matches `MAX_OPCODE_HANDLERS`        |

The handler array is indexed as `opcodeHandlers[opcode - $8000]`, so the valid range
is `$8000` through `$8155` (indices 0 through 341).
