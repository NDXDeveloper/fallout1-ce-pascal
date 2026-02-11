{$MODE OBJFPC}{$H+}
// Converted from: src/pointer_registry.h + pointer_registry.cc
// Registry that maps integer handles to pointers, used for interop with
// code that cannot store raw pointer values (e.g. scripting engine).
unit u_pointer_registry;

interface

type
  TPointerRegistry = class
  private
    FList: array of Pointer;
    FCount: Integer;
    FCapacity: Integer;
    procedure Grow;
  public
    constructor Create;
    destructor Destroy; override;
    class function Shared: TPointerRegistry;
    function Store(Ptr: Pointer): Integer;
    function Fetch(Ref: Integer; Remove: Boolean = False): Pointer;
  end;

function ptrToInt(Ptr: Pointer): Integer;
function intToPtr(Ref: Integer; Remove: Boolean = False): Pointer;

implementation

uses
  SysUtils;

const
  INITIAL_CAPACITY = 64;
  GROWTH_FACTOR    = 2;

var
  SharedInstance: TPointerRegistry = nil;

constructor TPointerRegistry.Create;
begin
  inherited Create;
  FCapacity := INITIAL_CAPACITY;
  SetLength(FList, FCapacity);
  // Slot 0 is unused so that valid refs start at 1.
  FCount := 1;
  FList[0] := nil;
end;

destructor TPointerRegistry.Destroy;
begin
  SetLength(FList, 0);
  inherited Destroy;
end;

procedure TPointerRegistry.Grow;
var
  NewCap, I: Integer;
begin
  NewCap := FCapacity * GROWTH_FACTOR;
  SetLength(FList, NewCap);
  for I := FCapacity to NewCap - 1 do
    FList[I] := nil;
  FCapacity := NewCap;
end;

class function TPointerRegistry.Shared: TPointerRegistry;
begin
  if SharedInstance = nil then
    SharedInstance := TPointerRegistry.Create;
  Result := SharedInstance;
end;

// Store a pointer and return an integer handle (>= 1).
function TPointerRegistry.Store(Ptr: Pointer): Integer;
begin
  if FCount >= FCapacity then
    Grow;
  FList[FCount] := Ptr;
  Result := FCount;
  Inc(FCount);
end;

// Retrieve a pointer by its integer handle. Optionally remove it.
function TPointerRegistry.Fetch(Ref: Integer; Remove: Boolean): Pointer;
begin
  if (Ref < 1) or (Ref >= FCount) then
    raise ERangeError.CreateFmt('TPointerRegistry.Fetch: invalid ref %d', [Ref]);
  Result := FList[Ref];
  if Remove then
    FList[Ref] := nil;
end;

// Convenience: store a pointer and return its integer handle.
function ptrToInt(Ptr: Pointer): Integer;
begin
  Result := TPointerRegistry.Shared.Store(Ptr);
end;

// Convenience: retrieve a pointer from its integer handle.
function intToPtr(Ref: Integer; Remove: Boolean): Pointer;
begin
  Result := TPointerRegistry.Shared.Fetch(Ref, Remove);
end;

finalization
  FreeAndNil(SharedInstance);

end.
