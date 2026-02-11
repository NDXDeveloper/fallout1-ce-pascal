{$MODE OBJFPC}{$H+}
// Converted from: src/int/export.cc/h
// Script export/import system for sharing variables and procedures between scripts.
unit u_export;

interface

uses
  u_intrpret;

function exportStoreVariable(program_: PProgram; const name: PAnsiChar;
  var programValue: TProgramValue): Integer;
function exportFetchVariable(program_: PProgram; const name: PAnsiChar;
  var value: TProgramValue): Integer;
function exportExportVariable(program_: PProgram; const identifier: PAnsiChar): Integer;
procedure initExport;
procedure exportClose;
function exportFindProcedure(const identifier: PAnsiChar;
  addressPtr, argumentCountPtr: PInteger): PProgram;
function exportExportProcedure(program_: PProgram; const identifier: PAnsiChar;
  address, argumentCount: Integer): Integer;
procedure exportClearAllVariables;

implementation

uses
  SysUtils, u_memdbg, u_platform_compat;

const
  HASH_TABLE_SIZE = 1013;

type
  TExternalVariable = record
    name: array[0..31] of AnsiChar;
    programName: PAnsiChar;
    value: TProgramValue;
    stringValue: PAnsiChar;
  end;
  PExternalVariable = ^TExternalVariable;

  TExternalProcedure = record
    name: array[0..31] of AnsiChar;
    program_: PProgram;
    argumentCount: Integer;
    address: Integer;
  end;
  PExternalProcedure = ^TExternalProcedure;

var
  procHashTable: array[0..HASH_TABLE_SIZE - 1] of TExternalProcedure;
  varHashTable: array[0..HASH_TABLE_SIZE - 1] of TExternalVariable;

function hashName(const identifier: PAnsiChar): LongWord;
var
  v1: LongWord;
  pch: PAnsiChar;
  ch: Integer;
begin
  v1 := 0;
  pch := identifier;
  while pch^ <> #0 do
  begin
    ch := Ord(pch^) and $FF;
    if (ch >= Ord('A')) and (ch <= Ord('Z')) then
      ch := ch + 32; // tolower
    v1 := v1 + LongWord(ch and $FF) + (v1 * 8) + (v1 shr 29);
    Inc(pch);
  end;
  v1 := v1 mod HASH_TABLE_SIZE;
  Result := v1;
end;

function findProc(const identifier: PAnsiChar): PExternalProcedure;
var
  v1, v2: LongWord;
  ep: PExternalProcedure;
begin
  v1 := hashName(identifier);
  v2 := v1;

  ep := @procHashTable[v1];
  if ep^.program_ <> nil then
  begin
    if compat_stricmp(@ep^.name[0], identifier) = 0 then
      Exit(ep);
  end;

  repeat
    v1 := v1 + 7;
    if v1 >= HASH_TABLE_SIZE then
      v1 := v1 - HASH_TABLE_SIZE;

    ep := @procHashTable[v1];
    if ep^.program_ <> nil then
    begin
      if compat_stricmp(@ep^.name[0], identifier) = 0 then
        Exit(ep);
    end;
  until v1 = v2;

  Result := nil;
end;

function findEmptyProc(const identifier: PAnsiChar): PExternalProcedure;
var
  v1, v2: LongWord;
  ep: PExternalProcedure;
begin
  v1 := hashName(identifier);
  v2 := v1;

  ep := @procHashTable[v1];
  if ep^.name[0] = #0 then
    Exit(ep);

  repeat
    v1 := v1 + 7;
    if v1 >= HASH_TABLE_SIZE then
      v1 := v1 - HASH_TABLE_SIZE;

    ep := @procHashTable[v1];
    if ep^.name[0] = #0 then
      Exit(ep);
  until v1 = v2;

  Result := nil;
end;

function findVar(const identifier: PAnsiChar): PExternalVariable;
var
  v1, v2: LongWord;
  ev: PExternalVariable;
begin
  v1 := hashName(identifier);
  v2 := v1;

  ev := @varHashTable[v1];
  if compat_stricmp(@ev^.name[0], identifier) = 0 then
    Exit(ev);

  repeat
    ev := @varHashTable[v1];
    if ev^.name[0] = #0 then
      Break;

    v1 := v1 + 7;
    if v1 >= HASH_TABLE_SIZE then
      v1 := v1 - HASH_TABLE_SIZE;

    ev := @varHashTable[v1];
    if compat_stricmp(@ev^.name[0], identifier) = 0 then
      Exit(ev);
  until v1 = v2;

  Result := nil;
end;

function findEmptyVar(const identifier: PAnsiChar): PExternalVariable;
var
  v1, v2: LongWord;
  ev: PExternalVariable;
begin
  v1 := hashName(identifier);
  v2 := v1;

  ev := @varHashTable[v1];
  if ev^.name[0] = #0 then
    Exit(ev);

  repeat
    v1 := v1 + 7;
    if v1 >= HASH_TABLE_SIZE then
      v1 := v1 - HASH_TABLE_SIZE;

    ev := @varHashTable[v1];
    if ev^.name[0] = #0 then
      Exit(ev);
  until v1 = v2;

  Result := nil;
end;

function exportStoreVariable(program_: PProgram; const name: PAnsiChar;
  var programValue: TProgramValue): Integer;
var
  ev: PExternalVariable;
  stringValue: PAnsiChar;
begin
  ev := findVar(name);
  if ev = nil then
    Exit(1);

  if (ev^.value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    myfree(ev^.stringValue, 'EXPORT.C', 169);

  if (programValue.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    if program_ <> nil then
    begin
      stringValue := interpretGetString(program_, programValue.opcode, programValue.integerValue);
      ev^.value.opcode := VALUE_TYPE_DYNAMIC_STRING;

      ev^.stringValue := PAnsiChar(mymalloc(StrLen(stringValue) + 1, 'EXPORT.C', 175));
      StrCopy(ev^.stringValue, stringValue);
    end;
  end
  else
  begin
    ev^.value := programValue;
  end;

  Result := 0;
end;

function exportFetchVariable(program_: PProgram; const name: PAnsiChar;
  var value: TProgramValue): Integer;
var
  ev: PExternalVariable;
begin
  ev := findVar(name);
  if ev = nil then
    Exit(1);

  if (ev^.value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    value.opcode := ev^.value.opcode;
    value.integerValue := interpretAddString(program_, ev^.stringValue);
  end
  else
  begin
    value := ev^.value;
  end;

  Result := 0;
end;

function exportExportVariable(program_: PProgram; const identifier: PAnsiChar): Integer;
var
  programName: PAnsiChar;
  ev: PExternalVariable;
begin
  programName := program_^.name;
  ev := findVar(identifier);

  if ev <> nil then
  begin
    if compat_stricmp(ev^.programName, programName) <> 0 then
      Exit(1);

    if (ev^.value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
      myfree(ev^.stringValue, 'EXPORT.C', 234);
  end
  else
  begin
    ev := findEmptyVar(identifier);
    if ev = nil then
      Exit(1);

    StrLCopy(@ev^.name[0], identifier, 31);

    ev^.programName := PAnsiChar(mymalloc(StrLen(programName) + 1, 'EXPORT.C', 243));
    StrCopy(ev^.programName, programName);
  end;

  ev^.value.opcode := VALUE_TYPE_INT;
  ev^.value.integerValue := 0;

  Result := 0;
end;

procedure exportRemoveProgramReferences(program_: PProgram);
var
  index: Integer;
  ep: PExternalProcedure;
begin
  for index := 0 to HASH_TABLE_SIZE - 1 do
  begin
    ep := @procHashTable[index];
    if ep^.program_ = program_ then
    begin
      ep^.name[0] := #0;
      ep^.program_ := nil;
    end;
  end;
end;

procedure initExport;
begin
  interpretRegisterProgramDeleteCallback(@exportRemoveProgramReferences);
end;

procedure exportClose;
var
  index: Integer;
  ev: PExternalVariable;
begin
  for index := 0 to HASH_TABLE_SIZE - 1 do
  begin
    ev := @varHashTable[index];

    if ev^.name[0] <> #0 then
      myfree(ev^.programName, 'EXPORT.C', 274);

    if ev^.value.opcode = VALUE_TYPE_DYNAMIC_STRING then
      myfree(ev^.stringValue, 'EXPORT.C', 276);
  end;
end;

function exportFindProcedure(const identifier: PAnsiChar;
  addressPtr, argumentCountPtr: PInteger): PProgram;
var
  ep: PExternalProcedure;
begin
  ep := findProc(identifier);
  if ep = nil then
    Exit(nil);

  if ep^.program_ = nil then
    Exit(nil);

  addressPtr^ := ep^.address;
  argumentCountPtr^ := ep^.argumentCount;

  Result := ep^.program_;
end;

function exportExportProcedure(program_: PProgram; const identifier: PAnsiChar;
  address, argumentCount: Integer): Integer;
var
  ep: PExternalProcedure;
begin
  ep := findProc(identifier);
  if ep <> nil then
  begin
    if program_ <> ep^.program_ then
      Exit(1);
  end
  else
  begin
    ep := findEmptyProc(identifier);
    if ep = nil then
      Exit(1);

    StrLCopy(@ep^.name[0], identifier, 31);
  end;

  ep^.argumentCount := argumentCount;
  ep^.address := address;
  ep^.program_ := program_;

  Result := 0;
end;

procedure exportClearAllVariables;
var
  index: Integer;
  ev: PExternalVariable;
begin
  for index := 0 to HASH_TABLE_SIZE - 1 do
  begin
    ev := @varHashTable[index];
    if ev^.name[0] <> #0 then
    begin
      if (ev^.value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
      begin
        if ev^.stringValue <> nil then
          myfree(ev^.stringValue, 'EXPORT.C', 387);
      end;

      if ev^.programName <> nil then
      begin
        myfree(ev^.programName, 'EXPORT.C', 393);
        ev^.programName := nil;
      end;

      ev^.name[0] := #0;
      ev^.value.opcode := 0;
    end;
  end;
end;

end.
