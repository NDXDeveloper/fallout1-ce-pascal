{$MODE OBJFPC}{$H+}
// Converted from: src/int/mousemgr.cc/h
// Mouse cursor manager: caching, animated cursors, static cursors.
unit u_mousemgr;

interface

type
  TMouseManagerNameMangler = function(fileName: PAnsiChar): PAnsiChar; cdecl;
  TMouseManagerRateProvider = function: Integer; cdecl;
  TMouseManagerTimeProvider = function: Integer; cdecl;

procedure mousemgrSetNameMangler(func: TMouseManagerNameMangler);
procedure mousemgrSetTimeCallback(rateFunc: TMouseManagerRateProvider;
  currentTimeFunc: TMouseManagerTimeProvider);
procedure initMousemgr;
procedure mousemgrClose;
procedure mousemgrUpdate;
function mouseSetFrame(fileName: PAnsiChar; a2: Integer): Integer;
function mouseSetMouseShape(fileName: PAnsiChar; a2: Integer; a3: Integer): Boolean;
function mouseSetMousePointer(fileName: PAnsiChar): Boolean;
procedure mousemgrResetMouse;
procedure mouseHide;
procedure mouseShow;

implementation

uses
  SysUtils, u_memdbg, u_datafile, u_platform_compat, u_db, u_debug,
  u_input, u_mouse;

const
  MOUSE_MGR_CACHE_CAPACITY = 32;

  MOUSE_MANAGER_MOUSE_TYPE_NONE     = 0;
  MOUSE_MANAGER_MOUSE_TYPE_STATIC   = 1;
  MOUSE_MANAGER_MOUSE_TYPE_ANIMATED = 2;

type
  PMouseManagerStaticData = ^TMouseManagerStaticData;
  TMouseManagerStaticData = record
    data: PByte;
    field_4: Integer;
    field_8: Integer;
    width: Integer;
    height: Integer;
  end;

  PPByte = ^PByte;

  PMouseManagerAnimatedData = ^TMouseManagerAnimatedData;
  TMouseManagerAnimatedData = record
    field_0: PPByte;       // unsigned char**
    field_4: PPByte;       // unsigned char**
    field_8: PInteger;     // int*
    field_C: PInteger;     // int*
    width: Integer;
    height: Integer;
    field_18: Single;
    field_1C: Integer;
    field_20: Integer;
    field_24: ShortInt;    // signed char
    frameCount: ShortInt;  // signed char
    field_26: ShortInt;    // signed char
  end;

  PMouseManagerCacheEntry = ^TMouseManagerCacheEntry;
  TMouseManagerCacheEntry = record
    data: Pointer;         // union: void*, PMouseManagerStaticData, PMouseManagerAnimatedData
    type_: Integer;
    palette: array[0..256 * 3 - 1] of Byte;
    ref: Integer;
    fileName: array[0..31] of AnsiChar;
    field_32C: array[0..31] of AnsiChar;
  end;

// Forward declarations for static functions
function defaultNameMangler(a1: PAnsiChar): PAnsiChar; cdecl; forward;
function defaultRateCallback: Integer; cdecl; forward;
function defaultTimeCallback: Integer; cdecl; forward;
procedure setShape(buf: PByte; width: Integer; length_: Integer;
  full: Integer; hotx: Integer; hoty: Integer; trans: AnsiChar); forward;
procedure freeCacheEntry(entry: PMouseManagerCacheEntry); forward;
function cacheInsert(data: PPointer; type_: Integer; palette: PByte;
  const fileName: PAnsiChar): Integer; forward;
procedure cacheFlush; forward;
function cacheFind(const fileName: PAnsiChar; palettePtr: PPByte;
  a3: PInteger; a4: PInteger; widthPtr: PInteger; heightPtr: PInteger;
  typePtr: PInteger): PMouseManagerCacheEntry; forward;

// Helper functions - forward declarations
function findChar(s: PAnsiChar; ch: AnsiChar): PAnsiChar; forward;
function findLastChar(s: PAnsiChar; ch: AnsiChar): PAnsiChar; forward;
procedure parseTwoInts(s: PAnsiChar; out val1: Integer; out val2: Integer); forward;
procedure parseIntAndFloat(s: PAnsiChar; out intVal: Integer; out floatVal: Single); forward;

var
  // 0x505B20
  mouseNameMangler: TMouseManagerNameMangler = @defaultNameMangler;

  // 0x505B24
  rateCallback_: TMouseManagerRateProvider = @defaultRateCallback;

  // 0x505B28
  currentTimeCallback_: TMouseManagerTimeProvider = @defaultTimeCallback;

  // 0x505B2C
  curref: Integer = 1;

  // 0x6309D0
  Cache: array[0..MOUSE_MGR_CACHE_CAPACITY - 1] of TMouseManagerCacheEntry;

  // 0x637358
  animating: Boolean = False;

  // 0x637350
  curPal: PByte = nil;

  // 0x637354
  curAnim: PMouseManagerAnimatedData = nil;

  // 0x63735C
  curMouseBuf: PByte = nil;

  // 0x637360
  lastMouseIndex: Integer = 0;

// Helper to access the PPByte array as an array of PByte
function GetPByteAt(pp: PPByte; index: Integer): PByte; inline;
begin
  Result := PPByte(PByte(pp) + index * SizeOf(PByte))^;
end;

procedure SetPByteAt(pp: PPByte; index: Integer; value: PByte); inline;
begin
  PPByte(PByte(pp) + index * SizeOf(PByte))^ := value;
end;

function GetIntAt(p: PInteger; index: Integer): Integer; inline;
begin
  Result := PInteger(PByte(p) + index * SizeOf(Integer))^;
end;

procedure SetIntAt(p: PInteger; index: Integer; value: Integer); inline;
begin
  PInteger(PByte(p) + index * SizeOf(Integer))^ := value;
end;

// Helper: find first occurrence of ch in PAnsiChar, return pointer or nil
function findChar(s: PAnsiChar; ch: AnsiChar): PAnsiChar;
begin
  Result := s;
  while Result^ <> #0 do
  begin
    if Result^ = ch then
      Exit;
    Inc(Result);
  end;
  Result := nil;
end;

// Helper: find last occurrence of ch in PAnsiChar, return pointer or nil
function findLastChar(s: PAnsiChar; ch: AnsiChar): PAnsiChar;
var
  p: PAnsiChar;
begin
  Result := nil;
  p := s;
  while p^ <> #0 do
  begin
    if p^ = ch then
      Result := p;
    Inc(p);
  end;
end;

// Helper: parse two integers from a string "int int"
procedure parseTwoInts(s: PAnsiChar; out val1: Integer; out val2: Integer);
var
  str: AnsiString;
  p: Integer;
  s1, s2: AnsiString;
  code: Integer;
begin
  val1 := 0;
  val2 := 0;
  str := StrPas(s);
  str := Trim(str);
  p := Pos(' ', str);
  if p = 0 then
    Exit;
  s1 := Trim(Copy(str, 1, p - 1));
  s2 := Trim(Copy(str, p + 1, Length(str)));
  Val(s1, val1, code);
  if code <> 0 then
  begin
    val1 := 0;
    Exit;
  end;
  Val(s2, val2, code);
  if code <> 0 then
    val2 := 0;
end;

// Helper: parse "int float" from a string
procedure parseIntAndFloat(s: PAnsiChar; out intVal: Integer; out floatVal: Single);
var
  str: AnsiString;
  p: Integer;
  s1, s2: AnsiString;
  code: Integer;
  dval: Double;
begin
  intVal := 0;
  floatVal := 0.0;
  str := StrPas(s);
  str := Trim(str);
  p := Pos(' ', str);
  if p = 0 then
    Exit;
  s1 := Trim(Copy(str, 1, p - 1));
  s2 := Trim(Copy(str, p + 1, Length(str)));
  Val(s1, intVal, code);
  if code <> 0 then
  begin
    intVal := 0;
    Exit;
  end;
  Val(s2, dval, code);
  if code <> 0 then
  begin
    floatVal := 0.0;
    Exit;
  end;
  floatVal := dval;
end;

// 0x477060
function defaultNameMangler(a1: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := a1;
end;

// 0x477064
function defaultRateCallback: Integer; cdecl;
begin
  Result := 1000;
end;

// 0x47706C
function defaultTimeCallback: Integer; cdecl;
begin
  Result := Integer(get_time);
end;

// 0x477074
procedure setShape(buf: PByte; width: Integer; length_: Integer;
  full: Integer; hotx: Integer; hoty: Integer; trans: AnsiChar);
begin
  mouse_set_shape(buf, width, length_, full, hotx, hoty, trans);
end;

// 0x477098
procedure mousemgrSetNameMangler(func: TMouseManagerNameMangler);
begin
  mouseNameMangler := func;
end;

// 0x4770A0
procedure mousemgrSetTimeCallback(rateFunc: TMouseManagerRateProvider;
  currentTimeFunc: TMouseManagerTimeProvider);
begin
  if rateFunc <> nil then
    rateCallback_ := rateFunc
  else
    rateCallback_ := @defaultRateCallback;

  if currentTimeFunc <> nil then
    currentTimeCallback_ := currentTimeFunc
  else
    currentTimeCallback_ := @defaultTimeCallback;
end;

// 0x4770C8
procedure freeCacheEntry(entry: PMouseManagerCacheEntry);
var
  staticData: PMouseManagerStaticData;
  animatedData: PMouseManagerAnimatedData;
  index: Integer;
begin
  case entry^.type_ of
    MOUSE_MANAGER_MOUSE_TYPE_STATIC:
    begin
      staticData := PMouseManagerStaticData(entry^.data);
      if staticData <> nil then
      begin
        if staticData^.data <> nil then
        begin
          myfree(staticData^.data, '..\int\MOUSEMGR.C', 120);
          staticData^.data := nil;
        end;
        myfree(staticData, '..\int\MOUSEMGR.C', 123);
        entry^.data := nil;
      end;
    end;
    MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
    begin
      animatedData := PMouseManagerAnimatedData(entry^.data);
      if animatedData <> nil then
      begin
        if animatedData^.field_0 <> nil then
        begin
          for index := 0 to animatedData^.frameCount - 1 do
          begin
            myfree(GetPByteAt(animatedData^.field_0, index), '..\int\MOUSEMGR.C', 134);
            myfree(GetPByteAt(animatedData^.field_4, index), '..\int\MOUSEMGR.C', 135);
          end;
          myfree(animatedData^.field_0, '..\int\MOUSEMGR.C', 137);
          myfree(animatedData^.field_4, '..\int\MOUSEMGR.C', 138);
          myfree(animatedData^.field_8, '..\int\MOUSEMGR.C', 139);
          myfree(animatedData^.field_C, '..\int\MOUSEMGR.C', 140);
        end;
        myfree(animatedData, '..\int\MOUSEMGR.C', 143);
        entry^.data := nil;
      end;
    end;
  end;

  entry^.type_ := 0;
  entry^.fileName[0] := #0;
end;

// 0x477208
function cacheInsert(data: PPointer; type_: Integer; palette: PByte;
  const fileName: PAnsiChar): Integer;
var
  foundIndex: Integer;
  index: Integer;
  cacheEntry: PMouseManagerCacheEntry;
  v2: Integer;
  v1: Integer;
  innerIndex: Integer;
begin
  foundIndex := -1;
  index := 0;
  while index < MOUSE_MGR_CACHE_CAPACITY do
  begin
    cacheEntry := @Cache[index];
    if (cacheEntry^.type_ = MOUSE_MANAGER_MOUSE_TYPE_NONE) and (foundIndex = -1) then
      foundIndex := index;

    if compat_stricmp(fileName, @cacheEntry^.fileName[0]) = 0 then
    begin
      freeCacheEntry(cacheEntry);
      foundIndex := index;
      Break;
    end;
    Inc(index);
  end;

  if foundIndex <> -1 then
    index := foundIndex;

  if index = MOUSE_MGR_CACHE_CAPACITY then
  begin
    v2 := -1;
    v1 := curref;
    for innerIndex := 0 to MOUSE_MGR_CACHE_CAPACITY - 1 do
    begin
      cacheEntry := @Cache[innerIndex];
      if v1 > cacheEntry^.ref then
      begin
        v1 := cacheEntry^.ref;
        v2 := innerIndex;
      end;
    end;

    if v2 = -1 then
    begin
      debug_printf('Mouse cache overflow!!!!'#10);
      Halt(1);
    end;

    index := v2;
    freeCacheEntry(@Cache[index]);
  end;

  cacheEntry := @Cache[index];
  cacheEntry^.type_ := type_;
  Move(palette^, cacheEntry^.palette[0], SizeOf(cacheEntry^.palette));
  cacheEntry^.ref := curref;
  Inc(curref);
  StrLCopy(@cacheEntry^.fileName[0], fileName, SizeOf(cacheEntry^.fileName) - 1);
  cacheEntry^.field_32C[0] := #0;
  cacheEntry^.data := data^;

  Result := index;
end;

// 0x4771E4
procedure cacheFlush;
var
  index: Integer;
begin
  for index := 0 to MOUSE_MGR_CACHE_CAPACITY - 1 do
    freeCacheEntry(@Cache[index]);
end;

// 0x47735C
function cacheFind(const fileName: PAnsiChar; palettePtr: PPByte;
  a3: PInteger; a4: PInteger; widthPtr: PInteger; heightPtr: PInteger;
  typePtr: PInteger): PMouseManagerCacheEntry;
var
  index: Integer;
  cacheEntry: PMouseManagerCacheEntry;
  staticData: PMouseManagerStaticData;
  animatedData: PMouseManagerAnimatedData;
begin
  for index := 0 to MOUSE_MGR_CACHE_CAPACITY - 1 do
  begin
    cacheEntry := @Cache[index];
    if (compat_strnicmp(@cacheEntry^.fileName[0], fileName, 31) = 0) or
       (compat_strnicmp(@cacheEntry^.field_32C[0], fileName, 31) = 0) then
    begin
      palettePtr^ := @cacheEntry^.palette[0];
      typePtr^ := cacheEntry^.type_;

      lastMouseIndex := index;

      case cacheEntry^.type_ of
        MOUSE_MANAGER_MOUSE_TYPE_STATIC:
        begin
          staticData := PMouseManagerStaticData(cacheEntry^.data);
          a3^ := staticData^.field_4;
          a4^ := staticData^.field_8;
          widthPtr^ := staticData^.width;
          heightPtr^ := staticData^.height;
        end;
        MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
        begin
          animatedData := PMouseManagerAnimatedData(cacheEntry^.data);
          widthPtr^ := animatedData^.width;
          heightPtr^ := animatedData^.height;
          a3^ := GetIntAt(animatedData^.field_8, animatedData^.field_26);
          a4^ := GetIntAt(animatedData^.field_C, animatedData^.field_26);
        end;
      end;

      Exit(cacheEntry);
    end;
  end;

  Result := nil;
end;

// 0x47749C
procedure initMousemgr;
begin
  mouse_set_sensitivity(1.0);
end;

// 0x4774AC
procedure mousemgrClose;
begin
  setShape(nil, 0, 0, 0, 0, 0, #0);

  if curMouseBuf <> nil then
  begin
    myfree(curMouseBuf, '..\int\MOUSEMGR.C', 243);
    curMouseBuf := nil;
  end;

  // NOTE: Uninline.
  cacheFlush;

  curPal := nil;
  curAnim := nil;
end;

// 0x477514
procedure mousemgrUpdate;
var
  v1: Integer;
begin
  if not animating then
    Exit;

  if curAnim = nil then
    debug_printf('Animating == 1 but curAnim == 0'#10);

  if currentTimeCallback_() >= curAnim^.field_1C then
  begin
    curAnim^.field_1C := Trunc(curAnim^.field_18 / curAnim^.frameCount * rateCallback_() + currentTimeCallback_());
    if curAnim^.field_24 <> curAnim^.field_26 then
    begin
      v1 := curAnim^.field_26 + curAnim^.field_20;
      if v1 < 0 then
        v1 := curAnim^.frameCount - 1
      else if v1 >= curAnim^.frameCount then
        v1 := 0;

      curAnim^.field_26 := v1;
      Move(GetPByteAt(curAnim^.field_4, curAnim^.field_26)^,
        GetPByteAt(curAnim^.field_0, curAnim^.field_26)^,
        curAnim^.width * curAnim^.height);

      datafileConvertData(GetPByteAt(curAnim^.field_0, curAnim^.field_26),
        curPal,
        curAnim^.width,
        curAnim^.height);

      setShape(GetPByteAt(curAnim^.field_0, v1),
        curAnim^.width,
        curAnim^.height,
        curAnim^.width,
        GetIntAt(curAnim^.field_8, v1),
        GetIntAt(curAnim^.field_C, v1),
        #0);
    end;
  end;
end;

// 0x477678
function mouseSetFrame(fileName: PAnsiChar; a2: Integer): Integer;
var
  mangledFileName: PAnsiChar;
  palette: PByte;
  temp: Integer;
  type_: Integer;
  cacheEntry: PMouseManagerCacheEntry;
  animatedData: PMouseManagerAnimatedData;
  v1, v2: Integer;
  stream: PDB_FILE;
  str: array[0..79] of AnsiChar;
  sep: PAnsiChar;
  v3: Integer;
  v4: Single;
  width, height: Integer;
  index: Integer;
  v5, v6: Integer;
  dataPtr: Pointer;
begin
  mangledFileName := mouseNameMangler(fileName);

  palette := nil;
  cacheEntry := cacheFind(fileName, @palette, @temp, @temp, @temp, @temp, @type_);
  if cacheEntry <> nil then
  begin
    if type_ = MOUSE_MANAGER_MOUSE_TYPE_ANIMATED then
    begin
      animatedData := PMouseManagerAnimatedData(cacheEntry^.data);
      animatedData^.field_24 := a2;
      if animatedData^.field_24 >= animatedData^.field_26 then
      begin
        v1 := animatedData^.field_24 - animatedData^.field_26;
        v2 := animatedData^.frameCount + animatedData^.field_26 - animatedData^.field_24;
        if v1 >= v2 then
          animatedData^.field_20 := -1
        else
          animatedData^.field_20 := 1;
      end
      else
      begin
        v1 := animatedData^.field_26 - animatedData^.field_24;
        v2 := animatedData^.frameCount + animatedData^.field_24 - animatedData^.field_26;
        if v1 < v2 then
          animatedData^.field_20 := -1
        else
          animatedData^.field_20 := 1;
      end;

      if (not animating) or (curAnim <> animatedData) then
      begin
        Move(GetPByteAt(animatedData^.field_4, animatedData^.field_26)^,
          GetPByteAt(animatedData^.field_0, animatedData^.field_26)^,
          animatedData^.width * animatedData^.height);

        setShape(GetPByteAt(animatedData^.field_0, animatedData^.field_26),
          animatedData^.width,
          animatedData^.height,
          animatedData^.width,
          GetIntAt(animatedData^.field_8, animatedData^.field_26),
          GetIntAt(animatedData^.field_C, animatedData^.field_26),
          #0);

        animating := True;
      end;

      curAnim := animatedData;
      curPal := palette;
      curAnim^.field_1C := currentTimeCallback_();
      Exit(Integer(True));
    end;

    mouseSetMousePointer(fileName);
    Exit(Integer(True));
  end;

  if animating then
  begin
    curPal := nil;
    animating := False;
    curAnim := nil;
  end
  else
  begin
    if curMouseBuf <> nil then
    begin
      myfree(curMouseBuf, '..\int\MOUSEMGR.C', 337);
      curMouseBuf := nil;
    end;
  end;

  stream := db_fopen(mangledFileName, 'r');
  if stream = nil then
  begin
    debug_printf('mouseSetFrame: couldn''t find %s'#10, [mangledFileName]);
    Exit(Integer(False));
  end;

  db_fgets(@str[0], SizeOf(str), stream);
  if compat_strnicmp(@str[0], 'anim', 4) <> 0 then
  begin
    db_fclose(stream);
    mouseSetMousePointer(fileName);
    Exit(Integer(True));
  end;

  // NOTE: Uninline.
  sep := findChar(@str[0], ' ');
  if sep = nil then
  begin
    // FIXME: Leaks stream.
    Exit(Integer(False));
  end;

  v3 := 0;
  v4 := 0.0;
  parseIntAndFloat(sep + 1, v3, v4);

  animatedData := PMouseManagerAnimatedData(mymalloc(SizeOf(TMouseManagerAnimatedData), '..\int\MOUSEMGR.C', 359));
  animatedData^.field_0 := PPByte(mymalloc(SizeOf(PByte) * v3, '..\int\MOUSEMGR.C', 360));
  animatedData^.field_4 := PPByte(mymalloc(SizeOf(PByte) * v3, '..\int\MOUSEMGR.C', 361));
  animatedData^.field_8 := PInteger(mymalloc(SizeOf(Integer) * v3, '..\int\MOUSEMGR.C', 362));
  animatedData^.field_C := PInteger(mymalloc(SizeOf(Integer) * v3, '..\int\MOUSEMGR.C', 363));
  animatedData^.field_18 := v4;
  animatedData^.field_1C := currentTimeCallback_();
  animatedData^.field_26 := 0;
  animatedData^.field_24 := a2;
  animatedData^.frameCount := v3;
  if animatedData^.frameCount div 2 <= a2 then
    animatedData^.field_20 := -1
  else
    animatedData^.field_20 := 1;

  width := 0;
  height := 0;
  for index := 0 to v3 - 1 do
  begin
    str[0] := #0;
    db_fgets(@str[0], SizeOf(str), stream);
    if str[0] = #0 then
    begin
      debug_printf('Not enough frames in %s, got %d, needed %d', [mangledFileName, index, v3]);
      Break;
    end;

    // NOTE: Uninline.
    sep := findChar(@str[0], ' ');
    if sep = nil then
    begin
      debug_printf('Bad line %s in %s'#10, [PAnsiChar(@str[0]), fileName]);
      // FIXME: Leaking stream.
      Exit(Integer(False));
    end;

    sep^ := #0;

    v5 := 0;
    v6 := 0;
    parseTwoInts(sep + 1, v5, v6);

    SetPByteAt(animatedData^.field_4, index,
      loadRawDataFile(mouseNameMangler(@str[0]), @width, @height));
    SetPByteAt(animatedData^.field_0, index,
      PByte(mymalloc(width * height, '..\int\MOUSEMGR.C', 390)));
    Move(GetPByteAt(animatedData^.field_4, index)^,
      GetPByteAt(animatedData^.field_0, index)^,
      width * height);
    datafileConvertData(GetPByteAt(animatedData^.field_0, index),
      datafileGetPalette, width, height);
    SetIntAt(animatedData^.field_8, index, v5);
    SetIntAt(animatedData^.field_C, index, v6);
  end;

  db_fclose(stream);

  animatedData^.width := width;
  animatedData^.height := height;

  dataPtr := Pointer(animatedData);
  lastMouseIndex := cacheInsert(@dataPtr, MOUSE_MANAGER_MOUSE_TYPE_ANIMATED, datafileGetPalette, fileName);
  StrLCopy(@Cache[lastMouseIndex].field_32C[0], fileName, 31);

  curAnim := animatedData;
  curPal := @Cache[lastMouseIndex].palette[0];
  animating := True;

  setShape(GetPByteAt(animatedData^.field_0, 0),
    animatedData^.width,
    animatedData^.height,
    animatedData^.width,
    GetIntAt(animatedData^.field_8, 0),
    GetIntAt(animatedData^.field_C, 0),
    #0);

  Result := Integer(True);
end;

// 0x477C68
function mouseSetMouseShape(fileName: PAnsiChar; a2: Integer; a3: Integer): Boolean;
var
  palette: PByte;
  temp: Integer;
  width, height: Integer;
  type_: Integer;
  cacheEntry: PMouseManagerCacheEntry;
  mangledFileName: PAnsiChar;
  staticData: PMouseManagerStaticData;
  dataPtr: Pointer;
begin
  palette := nil;
  cacheEntry := cacheFind(fileName, @palette, @temp, @temp, @width, @height, @type_);
  mangledFileName := mouseNameMangler(fileName);

  if cacheEntry = nil then
  begin
    staticData := PMouseManagerStaticData(mymalloc(SizeOf(TMouseManagerStaticData), '..\int\MOUSEMGR.C', 430));
    staticData^.data := loadRawDataFile(mangledFileName, @width, @height);
    staticData^.field_4 := a2;
    staticData^.field_8 := a3;
    staticData^.width := width;
    staticData^.height := height;
    dataPtr := Pointer(staticData);
    lastMouseIndex := cacheInsert(@dataPtr, MOUSE_MANAGER_MOUSE_TYPE_STATIC, datafileGetPalette, fileName);

    // NOTE: Original code is slightly different. It obtains address of
    // staticData and sets it into cacheEntry, which is a bit awkward.
    cacheEntry := @Cache[lastMouseIndex];

    type_ := MOUSE_MANAGER_MOUSE_TYPE_STATIC;
    palette := @Cache[lastMouseIndex].palette[0];
  end;

  case type_ of
    MOUSE_MANAGER_MOUSE_TYPE_STATIC:
    begin
      if curMouseBuf <> nil then
        myfree(curMouseBuf, '..\int\MOUSEMGR.C', 446);

      curMouseBuf := PByte(mymalloc(width * height, '..\int\MOUSEMGR.C', 448));
      Move(PMouseManagerStaticData(cacheEntry^.data)^.data^, curMouseBuf^, width * height);
      datafileConvertData(curMouseBuf, palette, width, height);
      setShape(curMouseBuf, width, height, width, a2, a3, #0);
      animating := False;
    end;
    MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
    begin
      curAnim := PMouseManagerAnimatedData(cacheEntry^.data);
      animating := True;
      curPal := palette;
    end;
  end;

  Result := True;
end;

// 0x477E20
function mouseSetMousePointer(fileName: PAnsiChar): Boolean;
var
  palette: PByte;
  v1, v2: Integer;
  width, height: Integer;
  type_: Integer;
  cacheEntry: PMouseManagerCacheEntry;
  dot: PAnsiChar;
  mangledFileName: PAnsiChar;
  stream: PDB_FILE;
  str: array[0..79] of AnsiChar;
  rc: Boolean;
  sep: PAnsiChar;
  v3, v4: Integer;
  animatedData: PMouseManagerAnimatedData;
begin
  palette := nil;
  cacheEntry := cacheFind(fileName, @palette, @v1, @v2, @width, @height, @type_);
  if cacheEntry <> nil then
  begin
    if curMouseBuf <> nil then
    begin
      myfree(curMouseBuf, '..\int\MOUSEMGR.C', 482);
      curMouseBuf := nil;
    end;

    curPal := nil;
    animating := False;
    curAnim := nil;

    case type_ of
      MOUSE_MANAGER_MOUSE_TYPE_STATIC:
      begin
        curMouseBuf := PByte(mymalloc(width * height, '..\int\MOUSEMGR.C', 492));
        Move(PMouseManagerStaticData(cacheEntry^.data)^.data^, curMouseBuf^, width * height);
        datafileConvertData(curMouseBuf, palette, width, height);
        setShape(curMouseBuf, width, height, width, v1, v2, #0);
        animating := False;
      end;
      MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
      begin
        animatedData := PMouseManagerAnimatedData(cacheEntry^.data);
        curAnim := animatedData;
        curPal := palette;
        curAnim^.field_26 := 0;
        curAnim^.field_24 := 0;
        setShape(GetPByteAt(curAnim^.field_0, 0),
          curAnim^.width,
          curAnim^.height,
          curAnim^.width,
          GetIntAt(curAnim^.field_8, 0),
          GetIntAt(curAnim^.field_C, 0),
          #0);
        animating := True;
      end;
    end;
    Exit(True);
  end;

  dot := findLastChar(fileName, '.');
  if (dot <> nil) and (compat_stricmp(dot + 1, 'mou') = 0) then
    Exit(mouseSetMouseShape(fileName, 0, 0));

  mangledFileName := mouseNameMangler(fileName);
  stream := db_fopen(mangledFileName, 'r');
  if stream = nil then
  begin
    debug_printf('Can''t find %s'#10, [mangledFileName]);
    Exit(False);
  end;

  str[0] := #0;
  db_fgets(@str[0], SizeOf(str) - 1, stream);
  if str[0] = #0 then
    Exit(False);

  if compat_strnicmp(@str[0], 'anim', 4) = 0 then
  begin
    db_fclose(stream);
    rc := mouseSetFrame(fileName, 0) <> 0;
  end
  else
  begin
    // NOTE: Uninline.
    sep := findChar(@str[0], ' ');
    if sep = nil then
      Exit(False);

    sep^ := #0;

    v3 := 0;
    v4 := 0;
    parseTwoInts(sep + 1, v3, v4);

    db_fclose(stream);

    rc := mouseSetMouseShape(@str[0], v3, v4);
  end;

  StrLCopy(@Cache[lastMouseIndex].field_32C[0], fileName, 31);

  Result := rc;
end;

// 0x4780BC
procedure mousemgrResetMouse;
var
  entry: PMouseManagerCacheEntry;
  imageWidth, imageHeight: Integer;
  staticData: PMouseManagerStaticData;
  index: Integer;
begin
  entry := @Cache[lastMouseIndex];

  imageWidth := 0;
  imageHeight := 0;
  case entry^.type_ of
    MOUSE_MANAGER_MOUSE_TYPE_STATIC:
    begin
      staticData := PMouseManagerStaticData(entry^.data);
      imageWidth := staticData^.width;
      imageHeight := staticData^.height;
    end;
    MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
    begin
      imageWidth := PMouseManagerAnimatedData(entry^.data)^.width;
      imageHeight := PMouseManagerAnimatedData(entry^.data)^.height;
    end;
  end;

  case entry^.type_ of
    MOUSE_MANAGER_MOUSE_TYPE_STATIC:
    begin
      if curMouseBuf <> nil then
      begin
        if curMouseBuf <> nil then
          myfree(curMouseBuf, '..\int\MOUSEMGR.C', 572);

        curMouseBuf := PByte(mymalloc(imageWidth * imageHeight, '..\int\MOUSEMGR.C', 574));
        staticData := PMouseManagerStaticData(entry^.data);
        Move(staticData^.data^, curMouseBuf^, imageWidth * imageHeight);
        datafileConvertData(curMouseBuf, @entry^.palette[0], imageWidth, imageHeight);

        setShape(curMouseBuf,
          imageWidth,
          imageHeight,
          imageWidth,
          staticData^.field_4,
          staticData^.field_8,
          #0);
      end
      else
      begin
        debug_printf('Hm, current mouse type is M_STATIC, but no current mouse pointer'#10);
      end;
    end;
    MOUSE_MANAGER_MOUSE_TYPE_ANIMATED:
    begin
      if curAnim <> nil then
      begin
        for index := 0 to curAnim^.frameCount - 1 do
        begin
          Move(GetPByteAt(curAnim^.field_4, index)^,
            GetPByteAt(curAnim^.field_0, index)^,
            imageWidth * imageHeight);
          datafileConvertData(GetPByteAt(curAnim^.field_0, index),
            @entry^.palette[0], imageWidth, imageHeight);
        end;

        setShape(GetPByteAt(curAnim^.field_0, curAnim^.field_26),
          imageWidth,
          imageHeight,
          imageWidth,
          GetIntAt(curAnim^.field_8, curAnim^.field_26),
          GetIntAt(curAnim^.field_C, curAnim^.field_26),
          #0);
      end
      else
      begin
        debug_printf('Hm, current mouse type is M_ANIMATED, but no current mouse pointer'#10);
      end;
    end;
  end;
end;

// 0x4783D4
procedure mouseHide;
begin
  mouse_hide;
end;

// 0x4783DC
procedure mouseShow;
begin
  mouse_show;
end;

end.
