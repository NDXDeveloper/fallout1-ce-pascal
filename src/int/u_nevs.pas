{$MODE OBJFPC}{$H+}
// Converted from: src/int/nevs.cc/h
// Named event system for scripting engine.
unit u_nevs;

interface

uses
  u_intrpret;

const
  NEVS_TYPE_EVENT   = 0;
  NEVS_TYPE_HANDLER = 1;

type
  TNevsCallback = procedure(const name: PAnsiChar); cdecl;

procedure nevs_close;
procedure nevs_initonce;
function nevs_addevent(const name: PAnsiChar; program_: PProgram;
  proc, type_: Integer): Integer;
function nevs_addCevent(const name: PAnsiChar; callback: TNevsCallback;
  type_: Integer): Integer;
function nevs_clearevent(const name: PAnsiChar): Integer;
function nevs_signal(const name: PAnsiChar): Integer;
procedure nevs_update;

implementation

uses
  SysUtils, u_memdbg, u_debug, u_platform_compat;

const
  NEVS_COUNT = 40;

type
  TNevs = record
    used: Boolean;
    name: array[0..31] of AnsiChar;
    program_: PProgram;
    proc: Integer;
    type_: Integer;
    hits: Integer;
    busy: Boolean;
    callback: TNevsCallback;
  end;
  PNevs = ^TNevs;

var
  nevs: PNevs = nil;
  anyhits: Integer = 0;

function nevs_alloc: PNevs; forward;
procedure nevs_free(entry: PNevs); forward;
procedure nevs_removeprogramreferences(program_: PProgram); forward;
function nevs_find(const name: PAnsiChar): PNevs; forward;

function nevs_alloc: PNevs;
var
  index: Integer;
  entry: PNevs;
begin
  if nevs = nil then
  begin
    debug_printf('nevs_alloc(): nevs_initonce() not called!', []);
    Halt(99);
  end;

  for index := 0 to NEVS_COUNT - 1 do
  begin
    entry := PNevs(PByte(nevs) + SizeOf(TNevs) * index);
    if not entry^.used then
    begin
      nevs_free(entry);
      Exit(entry);
    end;
  end;

  Result := nil;
end;

procedure nevs_free(entry: PNevs);
begin
  entry^.used := False;
  FillChar(entry^, SizeOf(TNevs), 0);
end;

procedure nevs_close;
begin
  if nevs <> nil then
  begin
    myfree(nevs, 'NEVS.C', 97);
    nevs := nil;
  end;
end;

procedure nevs_removeprogramreferences(program_: PProgram);
var
  index: Integer;
  entry: PNevs;
begin
  if nevs <> nil then
  begin
    for index := 0 to NEVS_COUNT - 1 do
    begin
      entry := PNevs(PByte(nevs) + SizeOf(TNevs) * index);
      if entry^.used and (entry^.program_ = program_) then
        nevs_free(entry);
    end;
  end;
end;

procedure nevs_initonce;
begin
  interpretRegisterProgramDeleteCallback(@nevs_removeprogramreferences);

  if nevs = nil then
  begin
    nevs := PNevs(mycalloc(SizeOf(TNevs), NEVS_COUNT, 'NEVS.C', 131));
    if nevs = nil then
    begin
      debug_printf('nevs_initonce(): out of memory', []);
      Halt(99);
    end;
  end;
end;

function nevs_find(const name: PAnsiChar): PNevs;
var
  index: Integer;
  entry: PNevs;
begin
  if nevs = nil then
  begin
    debug_printf('nevs_find(): nevs_initonce() not called!', []);
    Halt(99);
  end;

  for index := 0 to NEVS_COUNT - 1 do
  begin
    entry := PNevs(PByte(nevs) + SizeOf(TNevs) * index);
    if entry^.used and (compat_stricmp(@entry^.name[0], name) = 0) then
      Exit(entry);
  end;

  Result := nil;
end;

function nevs_addevent(const name: PAnsiChar; program_: PProgram;
  proc, type_: Integer): Integer;
var
  entry: PNevs;
begin
  entry := nevs_find(name);
  if entry = nil then
    entry := nevs_alloc;

  if entry = nil then
    Exit(1);

  entry^.used := True;
  StrLCopy(@entry^.name[0], name, 31);
  entry^.program_ := program_;
  entry^.proc := proc;
  entry^.type_ := type_;
  entry^.callback := nil;

  Result := 0;
end;

function nevs_addCevent(const name: PAnsiChar; callback: TNevsCallback;
  type_: Integer): Integer;
var
  entry: PNevs;
begin
  debug_printf('nevs_addCevent( ''%s'', %p);'#10, [name, Pointer(callback)]);

  entry := nevs_find(name);
  if entry = nil then
    entry := nevs_alloc;

  if entry = nil then
    Exit(1);

  entry^.used := True;
  StrLCopy(@entry^.name[0], name, 31);
  entry^.program_ := nil;
  entry^.proc := 0;
  entry^.type_ := type_;
  entry^.callback := nil;

  Result := 0;
end;

function nevs_clearevent(const name: PAnsiChar): Integer;
var
  entry: PNevs;
begin
  debug_printf('nevs_clearevent( ''%s'');'#10, [name]);

  entry := nevs_find(name);
  if entry <> nil then
  begin
    nevs_free(entry);
    Exit(0);
  end;

  Result := 1;
end;

function nevs_signal(const name: PAnsiChar): Integer;
var
  entry: PNevs;
begin
  debug_printf('nevs_signal( ''%s'');'#10, [name]);

  entry := nevs_find(name);
  if entry = nil then
    Exit(1);

  debug_printf('nep: %p,  used = %u, prog = %p, proc = %d', [Pointer(entry),
    Ord(entry^.used), Pointer(entry^.program_), entry^.proc]);

  if entry^.used
     and (((entry^.program_ <> nil) and (entry^.proc <> 0)) or (entry^.callback <> nil))
     and (not entry^.busy) then
  begin
    Inc(entry^.hits);
    Inc(anyhits);
    Exit(0);
  end;

  Result := 1;
end;

procedure nevs_update;
var
  index: Integer;
  entry: PNevs;
begin
  if anyhits = 0 then
    Exit;

  debug_printf('nevs_update(): we have anyhits = %u'#10, [anyhits]);

  anyhits := 0;

  for index := 0 to NEVS_COUNT - 1 do
  begin
    entry := PNevs(PByte(nevs) + SizeOf(TNevs) * index);
    if entry^.used
       and (((entry^.program_ <> nil) and (entry^.proc <> 0)) or (entry^.callback <> nil))
       and (not entry^.busy) then
    begin
      if entry^.hits > 0 then
      begin
        entry^.busy := True;

        Dec(entry^.hits);
        anyhits := anyhits + entry^.hits;

        if entry^.callback = nil then
          executeProc(entry^.program_, entry^.proc)
        else
          entry^.callback(@entry^.name[0]);

        entry^.busy := False;

        if entry^.type_ = NEVS_TYPE_EVENT then
          nevs_free(entry);
      end;
    end;
  end;
end;

end.
