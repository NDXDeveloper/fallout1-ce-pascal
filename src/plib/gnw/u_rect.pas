{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/rect.h + rect.cc
// Rectangle operations and pool allocator for linked rect lists.
unit u_rect;

interface

type
  TPoint = record
    X, Y: Integer;
  end;
  PPoint = ^TPoint;

  TSize = record
    Width, Height: Integer;
  end;
  PSize = ^TSize;

  TRect = record
    ulx, uly, lrx, lry: Integer;
  end;
  PRect = ^TRect;

  PRectData = ^TRectData;
  TRectData = record
    Rect: TRect;
    Next: PRectData;
  end;

  TRectPtr = PRectData;

  // Pointer-to-pointer type for rect_clip_list
  PPRectData = ^PRectData;

procedure GNW_rect_exit;
procedure rect_clip_list(pCur: PPRectData; bound: PRect);
function rect_clip(b, t: PRect): TRectPtr;
function rect_malloc: TRectPtr;
procedure rect_free(ptr: TRectPtr);
procedure rect_min_bound(const r1, r2: PRect; min_bound: PRect);
function rect_inside_bound(const r1, bound: PRect; r2: PRect): Integer;

// Inline helpers
procedure rectCopy(dest: PRect; const src: PRect); inline;
function rectGetWidth(const ARect: PRect): Integer; inline;
function rectGetHeight(const ARect: PRect): Integer; inline;
procedure rectOffset(ARect: PRect; dx, dy: Integer); inline;

implementation

uses
  Math,
  u_memory;

var
  // 0x539D58
  // Free list pool for rect nodes
  rlist: TRectPtr = nil;

// Inline helpers

procedure rectCopy(dest: PRect; const src: PRect); inline;
begin
  dest^.ulx := src^.ulx;
  dest^.uly := src^.uly;
  dest^.lrx := src^.lrx;
  dest^.lry := src^.lry;
end;

function rectGetWidth(const ARect: PRect): Integer; inline;
begin
  Result := ARect^.lrx - ARect^.ulx + 1;
end;

function rectGetHeight(const ARect: PRect): Integer; inline;
begin
  Result := ARect^.lry - ARect^.uly + 1;
end;

procedure rectOffset(ARect: PRect; dx, dy: Integer); inline;
begin
  ARect^.ulx := ARect^.ulx + dx;
  ARect^.uly := ARect^.uly + dy;
  ARect^.lrx := ARect^.lrx + dx;
  ARect^.lry := ARect^.lry + dy;
end;

// 0x4B29B0
procedure GNW_rect_exit;
var
  Temp: TRectPtr;
begin
  while rlist <> nil do
  begin
    Temp := rlist^.Next;
    mem_free(rlist);
    rlist := Temp;
  end;
end;

// 0x4B29D4
procedure rect_clip_list(pCur: PPRectData; bound: PRect);
var
  v1, v2: TRect;
  rectListNode: TRectPtr;
  newRectListNode: TRectPtr;
begin
  rectCopy(@v1, bound);

  // NOTE: Original code is slightly different.
  while pCur^ <> nil do
  begin
    rectListNode := pCur^;
    if (v1.lrx >= rectListNode^.Rect.ulx)
      and (v1.lry >= rectListNode^.Rect.uly)
      and (v1.ulx <= rectListNode^.Rect.lrx)
      and (v1.uly <= rectListNode^.Rect.lry) then
    begin
      rectCopy(@v2, @rectListNode^.Rect);

      pCur^ := rectListNode^.Next;

      rectListNode^.Next := rlist;
      rlist := rectListNode;

      if v2.uly < v1.uly then
      begin
        newRectListNode := rect_malloc;
        if newRectListNode = nil then
          Exit;

        rectCopy(@newRectListNode^.Rect, @v2);
        newRectListNode^.Rect.lry := v1.uly - 1;
        newRectListNode^.Next := pCur^;

        pCur^ := newRectListNode;
        pCur := @newRectListNode^.Next;

        v2.uly := v1.uly;
      end;

      if v2.lry > v1.lry then
      begin
        newRectListNode := rect_malloc;
        if newRectListNode = nil then
          Exit;

        rectCopy(@newRectListNode^.Rect, @v2);
        newRectListNode^.Rect.uly := v1.lry + 1;
        newRectListNode^.Next := pCur^;

        pCur^ := newRectListNode;
        pCur := @newRectListNode^.Next;

        v2.lry := v1.lry;
      end;

      if v2.ulx < v1.ulx then
      begin
        newRectListNode := rect_malloc;
        if newRectListNode = nil then
          Exit;

        rectCopy(@newRectListNode^.Rect, @v2);
        newRectListNode^.Rect.lrx := v1.ulx - 1;
        newRectListNode^.Next := pCur^;

        pCur^ := newRectListNode;
        pCur := @newRectListNode^.Next;
      end;

      if v2.lrx > v1.lrx then
      begin
        newRectListNode := rect_malloc;
        if newRectListNode = nil then
          Exit;

        rectCopy(@newRectListNode^.Rect, @v2);
        newRectListNode^.Rect.ulx := v1.lrx + 1;
        newRectListNode^.Next := pCur^;

        pCur^ := newRectListNode;
        pCur := @newRectListNode^.Next;
      end;
    end
    else
    begin
      pCur := @rectListNode^.Next;
    end;
  end;
end;

// 0x4B2B5C
function rect_clip(b, t: PRect): TRectPtr;
var
  clipped_t: TRect;
  list: TRectPtr;
  next: PPRectData;
  clipped_b: array[0..3] of TRect;
  k: Integer;
begin
  list := nil;

  if rect_inside_bound(t, b, @clipped_t) = 0 then
  begin
    clipped_b[0].ulx := b^.ulx;
    clipped_b[0].uly := b^.uly;
    clipped_b[0].lrx := b^.lrx;
    clipped_b[0].lry := clipped_t.uly - 1;

    clipped_b[1].ulx := b^.ulx;
    clipped_b[1].uly := clipped_t.uly;
    clipped_b[1].lrx := clipped_t.ulx - 1;
    clipped_b[1].lry := clipped_t.lry;

    clipped_b[2].ulx := clipped_t.lrx + 1;
    clipped_b[2].uly := clipped_t.uly;
    clipped_b[2].lrx := b^.lrx;
    clipped_b[2].lry := clipped_t.lry;

    clipped_b[3].ulx := b^.ulx;
    clipped_b[3].uly := clipped_t.lry + 1;
    clipped_b[3].lrx := b^.lrx;
    clipped_b[3].lry := b^.lry;

    next := @list;
    for k := 0 to 3 do
    begin
      if (clipped_b[k].lrx >= clipped_b[k].ulx) and (clipped_b[k].lry >= clipped_b[k].uly) then
      begin
        list := rect_malloc;
        next^ := list;
        if list = nil then
        begin
          Result := nil;
          Exit;
        end;

        list^.Rect := clipped_b[k];
        list^.Next := nil;

        next := PPRectData(@list^.Next);
      end;
    end;
  end
  else
  begin
    list := rect_malloc;
    if list <> nil then
    begin
      list^.Rect.ulx := b^.ulx;
      list^.Rect.uly := b^.uly;
      list^.Rect.lrx := b^.lrx;
      list^.Rect.lry := b^.lry;
      list^.Next := nil;
    end;
  end;

  Result := list;
end;

// 0x4B2C68
// Pool allocator: allocates 10 nodes at a time into a free list.
function rect_malloc: TRectPtr;
var
  Temp: TRectPtr;
  i: Integer;
begin
  if rlist = nil then
  begin
    for i := 0 to 9 do
    begin
      Temp := TRectPtr(mem_malloc(SizeOf(TRectData)));
      if Temp = nil then
        Break;

      Temp^.Next := rlist;
      rlist := Temp;
    end;
  end;

  if rlist = nil then
  begin
    Result := nil;
    Exit;
  end;

  Temp := rlist;
  rlist := rlist^.Next;

  Result := Temp;
end;

// 0x4B2CB4
// Returns a node to the free list pool.
procedure rect_free(ptr: TRectPtr);
begin
  ptr^.Next := rlist;
  rlist := ptr;
end;

// 0x4B2CC8
// Calculates a union of two source rectangles and places it into the
// result rectangle (minimum bounding rectangle).
procedure rect_min_bound(const r1, r2: PRect; min_bound: PRect);
begin
  min_bound^.ulx := Min(r1^.ulx, r2^.ulx);
  min_bound^.uly := Min(r1^.uly, r2^.uly);
  min_bound^.lrx := Max(r1^.lrx, r2^.lrx);
  min_bound^.lry := Max(r1^.lry, r2^.lry);
end;

// 0x4B2D18
// Calculates intersection of two source rectangles and places it into r2,
// returning 0 on success. If the rectangles do not intersect, r2 is a copy
// of r1 and the function returns -1.
function rect_inside_bound(const r1, bound: PRect; r2: PRect): Integer;
begin
  r2^.ulx := r1^.ulx;
  r2^.uly := r1^.uly;
  r2^.lrx := r1^.lrx;
  r2^.lry := r1^.lry;

  if (r1^.ulx <= bound^.lrx)
    and (bound^.ulx <= r1^.lrx)
    and (bound^.lry >= r1^.uly)
    and (bound^.uly <= r1^.lry) then
  begin
    if bound^.ulx > r1^.ulx then
      r2^.ulx := bound^.ulx;

    if bound^.lrx < r1^.lrx then
      r2^.lrx := bound^.lrx;

    if bound^.uly > r1^.uly then
      r2^.uly := bound^.uly;

    if bound^.lry < r1^.lry then
      r2^.lry := bound^.lry;

    Result := 0;
  end
  else
    Result := -1;
end;

end.
