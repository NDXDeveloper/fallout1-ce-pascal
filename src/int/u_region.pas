{$MODE OBJFPC}{$H+}
// Converted from: src/int/region.cc/h
// Region management (polygon-based trigger areas).
unit u_region;

interface

uses
  u_rect, u_intrpret;

const
  REGION_NAME_LENGTH = 32;

type
  PRegion = ^TRegion;
  TRegionMouseEventCallback = procedure(region: PRegion; userData: Pointer; event: Integer); cdecl;

  TRegion = record
    name: array[0..REGION_NAME_LENGTH - 1] of AnsiChar;
    points: PPoint;
    minX: Integer;
    minY: Integer;
    maxX: Integer;
    maxY: Integer;
    centerX: Integer;
    centerY: Integer;
    pointsLength: Integer;
    pointsCapacity: Integer;
    program_: PProgram;
    procs: array[0..3] of Integer;
    rightProcs: array[0..3] of Integer;
    field_68: Integer;
    field_6C: Integer;
    field_70: Integer;
    flags: Integer;
    mouseEventCallback: TRegionMouseEventCallback;
    rightMouseEventCallback: TRegionMouseEventCallback;
    mouseEventCallbackUserData: Pointer;
    rightMouseEventCallbackUserData: Pointer;
    userData: Pointer;
  end;

procedure regionSetBound(region: PRegion);
function pointInRegion(region: PRegion; x, y: Integer): Boolean;
function allocateRegion(initialCapacity: Integer): PRegion;
procedure regionAddPoint(region: PRegion; x, y: Integer);
procedure regionDelete(region: PRegion);
procedure regionAddName(region: PRegion; const name: PAnsiChar);
function regionGetName(region: PRegion): PAnsiChar;
function regionGetUserData(region: PRegion): Pointer;
procedure regionSetUserData(region: PRegion; data: Pointer);
procedure regionSetFlag(region: PRegion; value: Integer);
function regionGetFlag(region: PRegion): Integer;

implementation

uses
  SysUtils, u_memdbg, u_debug;

procedure regionSetBound(region: PRegion);
var
  minX_, maxX_, minY_, maxY_: Integer;
  numPoints: Integer;
  totalX, totalY: Integer;
  index: Integer;
  pt: PPoint;
begin
  minX_ := MaxInt;
  maxX_ := -MaxInt - 1;
  minY_ := MaxInt;
  maxY_ := -MaxInt - 1;
  numPoints := 0;
  totalX := 0;
  totalY := 0;

  for index := 0 to region^.pointsLength - 1 do
  begin
    pt := PPoint(PByte(region^.points) + SizeOf(TPoint) * index);
    if minX_ >= pt^.x then minX_ := pt^.x;
    if minY_ >= pt^.y then minY_ := pt^.y;
    if maxX_ <= pt^.x then maxX_ := pt^.x;
    if maxY_ <= pt^.y then maxY_ := pt^.y;
    totalX := totalX + pt^.x;
    totalY := totalY + pt^.y;
    Inc(numPoints);
  end;

  region^.minY := minY_;
  region^.maxX := maxX_;
  region^.maxY := maxY_;
  region^.minX := minX_;

  if numPoints <> 0 then
  begin
    region^.centerX := totalX div numPoints;
    region^.centerY := totalY div numPoints;
  end;
end;

function pointInRegion(region: PRegion; x, y: Integer): Boolean;
var
  v1, v2, v3, v4: Integer;
  index: Integer;
  prev, point: PPoint;
begin
  if region = nil then
    Exit(False);

  if (x < region^.minX) or (x > region^.maxX) or
     (y < region^.minY) or (y > region^.maxY) then
    Exit(False);

  prev := PPoint(PByte(region^.points) + 0);
  if x >= prev^.x then
  begin
    if y >= prev^.y then v1 := 2
    else v1 := 1;
  end
  else
  begin
    if y >= prev^.y then v1 := 3
    else v1 := 0;
  end;

  v4 := 0;
  for index := 0 to region^.pointsLength - 1 do
  begin
    point := PPoint(PByte(region^.points) + SizeOf(TPoint) * (index + 1));
    if x >= point^.x then
    begin
      if y >= point^.y then v2 := 2
      else v2 := 1;
    end
    else
    begin
      if y >= point^.y then v2 := 3
      else v2 := 0;
    end;

    v3 := v2 - v1;
    case v3 of
      -3: v3 := 1;
      -2, 2:
        begin
          if Double(x) < (Double(point^.x) - Double(prev^.x - point^.x) /
             Double(prev^.y - point^.y) * Double(point^.y - y)) then
            v3 := -v3;
        end;
      3: v3 := -1;
    end;

    prev := point;
    v1 := v2;
    v4 := v4 + v3;
  end;

  Result := (v4 = 4) or (v4 = -4);
end;

function allocateRegion(initialCapacity: Integer): PRegion;
var
  region: PRegion;
begin
  region := PRegion(mymalloc(SizeOf(TRegion), 'REGION.C', 142));
  FillChar(region^, SizeOf(TRegion), 0);

  if initialCapacity <> 0 then
  begin
    region^.points := PPoint(mymalloc(SizeOf(TPoint) * (initialCapacity + 1), 'REGION.C', 147));
    region^.pointsCapacity := initialCapacity + 1;
  end
  else
  begin
    region^.points := nil;
    region^.pointsCapacity := 0;
  end;

  region^.name[0] := #0;
  region^.flags := 0;
  region^.minY := -MaxInt - 1;
  region^.maxY := MaxInt;
  region^.procs[3] := 0;
  region^.rightProcs[1] := 0;
  region^.rightProcs[3] := 0;
  region^.field_68 := 0;
  region^.rightProcs[0] := 0;
  region^.field_70 := 0;
  region^.rightProcs[2] := 0;
  region^.mouseEventCallback := nil;
  region^.rightMouseEventCallback := nil;
  region^.mouseEventCallbackUserData := nil;
  region^.rightMouseEventCallbackUserData := nil;
  region^.pointsLength := 0;
  region^.minX := region^.minY;
  region^.maxX := region^.maxY;
  region^.procs[2] := 0;
  region^.procs[1] := 0;
  region^.procs[0] := 0;
  region^.rightProcs[0] := 0;

  Result := region;
end;

procedure regionAddPoint(region: PRegion; x, y: Integer);
var
  pointIndex: Integer;
  pt, endPt: PPoint;
begin
  if region = nil then
  begin
    debug_printf('regionAddPoint(): null region ptr'#10, []);
    Exit;
  end;

  if region^.points <> nil then
  begin
    if region^.pointsCapacity - 1 = region^.pointsLength then
    begin
      region^.points := PPoint(myrealloc(region^.points,
        SizeOf(TPoint) * (region^.pointsCapacity + 1), 'REGION.C', 190));
      Inc(region^.pointsCapacity);
    end;
  end
  else
  begin
    region^.pointsCapacity := 2;
    region^.pointsLength := 0;
    region^.points := PPoint(mymalloc(SizeOf(TPoint) * 2, 'REGION.C', 185));
  end;

  pointIndex := region^.pointsLength;
  Inc(region^.pointsLength);

  pt := PPoint(PByte(region^.points) + SizeOf(TPoint) * pointIndex);
  pt^.x := x;
  pt^.y := y;

  endPt := PPoint(PByte(region^.points) + SizeOf(TPoint) * (pointIndex + 1));
  endPt^.x := region^.points^.x;
  endPt^.y := region^.points^.y;
end;

procedure regionDelete(region: PRegion);
begin
  if region = nil then
  begin
    debug_printf('regionDelete(): null region ptr'#10, []);
    Exit;
  end;

  if region^.points <> nil then
    myfree(region^.points, 'REGION.C', 206);

  myfree(region, 'REGION.C', 207);
end;

procedure regionAddName(region: PRegion; const name: PAnsiChar);
begin
  if region = nil then
  begin
    debug_printf('regionAddName(): null region ptr'#10, []);
    Exit;
  end;

  if name = nil then
  begin
    region^.name[0] := #0;
    Exit;
  end;

  StrLCopy(@region^.name[0], name, REGION_NAME_LENGTH - 1);
end;

function regionGetName(region: PRegion): PAnsiChar;
begin
  if region = nil then
  begin
    debug_printf('regionGetName(): null region ptr'#10, []);
    Exit('<null>');
  end;
  Result := @region^.name[0];
end;

function regionGetUserData(region: PRegion): Pointer;
begin
  if region = nil then
  begin
    debug_printf('regionGetUserData(): null region ptr'#10, []);
    Exit(nil);
  end;
  Result := region^.userData;
end;

procedure regionSetUserData(region: PRegion; data: Pointer);
begin
  if region = nil then
  begin
    debug_printf('regionSetUserData(): null region ptr'#10, []);
    Exit;
  end;
  region^.userData := data;
end;

procedure regionSetFlag(region: PRegion; value: Integer);
begin
  region^.flags := region^.flags or value;
end;

function regionGetFlag(region: PRegion): Integer;
begin
  Result := region^.flags;
end;

end.
