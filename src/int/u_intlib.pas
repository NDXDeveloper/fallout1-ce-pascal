{$MODE OBJFPC}{$H+}
// Converted from: src/int/intlib.cc/h
// Script interpreter library: opcode handlers for window, dialog, sound,
// palette, movie, region, button, mouse, and named-event operations.
unit u_intlib;

interface

uses
  u_intrpret;

type
  TIntLibProgramDeleteCallback = procedure(program_: PProgram); cdecl;
  PIntLibProgramDeleteCallback = ^TIntLibProgramDeleteCallback;
  PPIntLibProgramDeleteCallback = ^PIntLibProgramDeleteCallback;

procedure interpretFadePalette(oldPalette: PByte; newPalette: PByte; a3: Integer; duration: Single);
function intlibGetFadeIn: Integer;
procedure interpretFadeOut(duration: Single);
procedure interpretFadeIn(duration: Single);
procedure interpretFadeOutNoBK(duration: Single);
procedure interpretFadeInNoBK(duration: Single);
function checkMovie(program_: PProgram): Integer;
function getTimeOut: Integer;
procedure setTimeOut(value: Integer);
procedure soundCloseInterpret;
function soundStartInterpret(fileName: PAnsiChar; mode: Integer): Integer;
procedure updateIntLib;
procedure intlibClose;
procedure initIntlib;
procedure interpretRegisterProgramDeleteCallback_intlib(callback: PIntLibProgramDeleteCallback);
procedure removeProgramReferences(program_: PProgram);

implementation

uses
  SysUtils,
  u_memdbg,
  u_datafile,
  u_nevs,
  u_share1,
  u_int_sound,
  u_color,
  u_debug,
  u_input,
  u_plib_intrface,
  u_text,
  u_mouse,
  u_svga,
  u_int_window,
  u_int_dialog,
  u_mousemgr,
  u_intextra;

const
  INT_LIB_SOUNDS_CAPACITY = 32;
  INT_LIB_KEY_HANDLERS_CAPACITY = 256;

type
  TIntLibKeyHandlerEntry = record
    program_: PProgram;
    proc: Integer;
  end;

{ Forward declarations for internal procedures }
procedure op_fillwin3x3(program_: PProgram); cdecl; forward;
procedure op_format(program_: PProgram); cdecl; forward;
procedure op_print(program_: PProgram); cdecl; forward;
procedure op_selectfilelist(program_: PProgram); cdecl; forward;
procedure op_tokenize(program_: PProgram); cdecl; forward;
procedure op_printrect(program_: PProgram); cdecl; forward;
procedure op_selectwin(program_: PProgram); cdecl; forward;
procedure op_display(program_: PProgram); cdecl; forward;
procedure op_displayraw(program_: PProgram); cdecl; forward;
procedure op_fadein(program_: PProgram); cdecl; forward;
procedure op_fadeout(program_: PProgram); cdecl; forward;
procedure op_movieflags(program_: PProgram); cdecl; forward;
procedure op_playmovie(program_: PProgram); cdecl; forward;
procedure op_playmovierect(program_: PProgram); cdecl; forward;
procedure op_stopmovie(program_: PProgram); cdecl; forward;
procedure op_addregionproc(program_: PProgram); cdecl; forward;
procedure op_addregionrightproc(program_: PProgram); cdecl; forward;
procedure op_createwin(program_: PProgram); cdecl; forward;
procedure op_resizewin(program_: PProgram); cdecl; forward;
procedure op_scalewin(program_: PProgram); cdecl; forward;
procedure op_deletewin(program_: PProgram); cdecl; forward;
procedure op_saystart(program_: PProgram); cdecl; forward;
procedure op_deleteregion(program_: PProgram); cdecl; forward;
procedure op_activateregion(program_: PProgram); cdecl; forward;
procedure op_checkregion(program_: PProgram); cdecl; forward;
procedure op_addregion(program_: PProgram); cdecl; forward;
procedure op_saystartpos(program_: PProgram); cdecl; forward;
procedure op_sayreplytitle(program_: PProgram); cdecl; forward;
procedure op_saygotoreply(program_: PProgram); cdecl; forward;
procedure op_sayoption(program_: PProgram); cdecl; forward;
procedure op_sayreply(program_: PProgram); cdecl; forward;
function checkDialog(program_: PProgram): Integer; cdecl; forward;
procedure op_sayend(program_: PProgram); cdecl; forward;
procedure op_saygetlastpos(program_: PProgram); cdecl; forward;
procedure op_sayquit(program_: PProgram); cdecl; forward;
procedure op_saymessagetimeout(program_: PProgram); cdecl; forward;
procedure op_saymessage(program_: PProgram); cdecl; forward;
procedure op_gotoxy(program_: PProgram); cdecl; forward;
procedure op_addbuttonflag(program_: PProgram); cdecl; forward;
procedure op_addregionflag(program_: PProgram); cdecl; forward;
procedure op_addbutton(program_: PProgram); cdecl; forward;
procedure op_addbuttontext(program_: PProgram); cdecl; forward;
procedure op_addbuttongfx(program_: PProgram); cdecl; forward;
procedure op_addbuttonproc(program_: PProgram); cdecl; forward;
procedure op_addbuttonrightproc(program_: PProgram); cdecl; forward;
procedure op_showwin(program_: PProgram); cdecl; forward;
procedure op_deletebutton(program_: PProgram); cdecl; forward;
procedure op_fillwin(program_: PProgram); cdecl; forward;
procedure op_fillrect(program_: PProgram); cdecl; forward;
procedure op_hidemouse(program_: PProgram); cdecl; forward;
procedure op_showmouse(program_: PProgram); cdecl; forward;
procedure op_mouseshape(program_: PProgram); cdecl; forward;
procedure op_setglobalmousefunc(program_: PProgram); cdecl; forward;
procedure op_displaygfx(program_: PProgram); cdecl; forward;
procedure op_loadpalettetable(program_: PProgram); cdecl; forward;
procedure op_addNamedEvent(program_: PProgram); cdecl; forward;
procedure op_addNamedHandler(program_: PProgram); cdecl; forward;
procedure op_clearNamed(program_: PProgram); cdecl; forward;
procedure op_signalNamed(program_: PProgram); cdecl; forward;
procedure op_addkey(program_: PProgram); cdecl; forward;
procedure op_deletekey(program_: PProgram); cdecl; forward;
procedure op_refreshmouse(program_: PProgram); cdecl; forward;
procedure op_setfont(program_: PProgram); cdecl; forward;
procedure op_settextflags(program_: PProgram); cdecl; forward;
procedure op_settextcolor(program_: PProgram); cdecl; forward;
procedure op_sayoptioncolor(program_: PProgram); cdecl; forward;
procedure op_sayreplycolor(program_: PProgram); cdecl; forward;
procedure op_sethighlightcolor(program_: PProgram); cdecl; forward;
procedure op_sayreplywindow(program_: PProgram); cdecl; forward;
procedure op_sayreplyflags(program_: PProgram); cdecl; forward;
procedure op_sayoptionflags(program_: PProgram); cdecl; forward;
procedure op_sayoptionwindow(program_: PProgram); cdecl; forward;
procedure op_sayborder(program_: PProgram); cdecl; forward;
procedure op_sayscrollup(program_: PProgram); cdecl; forward;
procedure op_sayscrolldown(program_: PProgram); cdecl; forward;
procedure op_saysetspacing(program_: PProgram); cdecl; forward;
procedure op_sayrestart(program_: PProgram); cdecl; forward;
procedure op_soundplay(program_: PProgram); cdecl; forward;
procedure op_soundpause(program_: PProgram); cdecl; forward;
procedure op_soundresume(program_: PProgram); cdecl; forward;
procedure op_soundstop(program_: PProgram); cdecl; forward;
procedure op_soundrewind(program_: PProgram); cdecl; forward;
procedure op_sounddelete(program_: PProgram); cdecl; forward;
procedure op_setoneoptpause(program_: PProgram); cdecl; forward;

procedure interpretFadePaletteBK(oldPalette: PByte; newPalette: PByte;
  a3: Integer; duration: Single; shouldProcessBk: Integer); forward;
procedure soundCallbackInterpret(userData: Pointer; a2: Integer); cdecl; forward;
function soundDeleteInterpret(value: Integer): Integer; forward;
function soundPauseInterpret(value: Integer): Integer; forward;
function soundRewindInterpret(value: Integer): Integer; forward;
function soundUnpauseInterpret(value: Integer): Integer; forward;
function intLibDoInput(key: Integer): Boolean; forward;

var
  // Static variables (C++ static locals and file-scope statics)
  TimeOut: Integer = 0;
  interpretSounds: array[0..INT_LIB_SOUNDS_CAPACITY - 1] of PSound;
  blackPal: array[0..256 * 3 - 1] of Byte;
  inputProc: array[0..INT_LIB_KEY_HANDLERS_CAPACITY - 1] of TIntLibKeyHandlerEntry;
  currentlyFadedIn: Boolean = False;
  anyKeyOffset: Integer = 0;
  numCallbacks: Integer = 0;
  anyKeyProg: PProgram = nil;
  callbacks: PPIntLibProgramDeleteCallback = nil;
  sayStartingPosition: Integer = 0;

  // C++ static locals from op_playmovie / op_playmovierect
  playmovie_name: array[0..99] of AnsiChar;
  playmovierect_name: array[0..99] of AnsiChar;

// -----------------------------------------------------------------------
// op_fillwin3x3
// -----------------------------------------------------------------------
procedure op_fillwin3x3(program_: PProgram); cdecl;
var
  fileName: PAnsiChar;
  mangledFileName: PAnsiChar;
  imageWidth: Integer;
  imageHeight: Integer;
  imageData: PByte;
begin
  fileName := programStackPopString(program_);
  mangledFileName := interpretMangleName(fileName);

  imageData := loadDataFile(mangledFileName, @imageWidth, @imageHeight);
  if imageData = nil then
    interpretError('cannot load 3x3 file ''%s''', [mangledFileName]);

  selectWindowID(program_^.windowId);

  fillBuf3x3(imageData,
    imageWidth,
    imageHeight,
    windowGetBuffer(),
    windowWidth(),
    windowHeight());

  myfree(imageData, 'INTLIB.C', 94);
end;

// -----------------------------------------------------------------------
// op_format
// -----------------------------------------------------------------------
procedure op_format(program_: PProgram); cdecl;
var
  textAlignment: Integer;
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  str: PAnsiChar;
begin
  textAlignment := programStackPopInteger(program_);
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  str := programStackPopString(program_);

  if not windowFormatMessage(str, x, y, width, height, textAlignment) then
    interpretError('Error formatting message'#10, []);
end;

// -----------------------------------------------------------------------
// op_print
// -----------------------------------------------------------------------
procedure op_print(program_: PProgram); cdecl;
var
  value: TProgramValue;
  str: array[0..79] of AnsiChar;
begin
  selectWindowID(program_^.windowId);

  value := programStackPopValue(program_);

  case value.opcode and VALUE_TYPE_MASK of
    VALUE_TYPE_STRING:
      windowOutput(interpretGetString(program_, value.opcode, value.integerValue));
    VALUE_TYPE_FLOAT:
    begin
      StrLFmt(@str[0], SizeOf(str) - 1, '%.5f', [Double(value.floatValue)]);
      windowOutput(@str[0]);
    end;
    VALUE_TYPE_INT:
    begin
      StrLFmt(@str[0], SizeOf(str) - 1, '%d', [value.integerValue]);
      windowOutput(@str[0]);
    end;
  end;
end;

// -----------------------------------------------------------------------
// op_selectfilelist
// -----------------------------------------------------------------------
procedure op_selectfilelist(program_: PProgram); cdecl;
var
  pattern: PAnsiChar;
  title: PAnsiChar;
  fileListLength: Integer;
  fileList: PPAnsiChar;
  selectedIndex: Integer;
  titleWidth: Integer;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  pattern := programStackPopString(program_);
  title := programStackPopString(program_);

  fileList := getFileList(interpretMangleName(pattern), @fileListLength);
  if (fileList <> nil) and (fileListLength <> 0) then
  begin
    titleWidth := 0;
    if Assigned(text_width) then
      titleWidth := text_width(title);

    selectedIndex := win_list_select(title,
      fileList,
      fileListLength,
      nil,
      320 - titleWidth div 2,
      200,
      Integer(colorTable[$7FFF]) or $10000);

    if selectedIndex <> -1 then
    begin
      // Access the file list as an array of PAnsiChar
      programStackPushString(program_, PPAnsiChar(PByte(fileList) + SizeOf(PAnsiChar) * selectedIndex)^);
    end
    else
      programStackPushInteger(program_, 0);

    freeFileList(fileList);
  end
  else
    programStackPushInteger(program_, 0);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// op_tokenize
// -----------------------------------------------------------------------
procedure op_tokenize(program_: PProgram); cdecl;
var
  ch: Integer;
  prevValue: TProgramValue;
  prev: PAnsiChar;
  str: PAnsiChar;
  temp: PAnsiChar;
  start: PAnsiChar;
  endp: PAnsiChar;
  length_: Integer;
begin
  ch := programStackPopInteger(program_);

  prevValue := programStackPopValue(program_);

  prev := nil;
  if (prevValue.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
  begin
    if prevValue.integerValue <> 0 then
      interpretError('Error, invalid arg 2 to tokenize. (only accept 0 for int value)', []);
  end
  else if (prevValue.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    prev := interpretGetString(program_, prevValue.opcode, prevValue.integerValue)
  else
    interpretError('Error, invalid arg 2 to tokenize. (string)', []);

  str := programStackPopString(program_);
  temp := nil;

  if prev <> nil then
  begin
    start := StrPos(str, prev);
    if start <> nil then
    begin
      start := start + StrLen(prev);
      while (start^ <> AnsiChar(ch)) and (start^ <> #0) do
        Inc(start);
    end;

    if (start <> nil) and (start^ = AnsiChar(ch)) then
    begin
      length_ := 0;
      endp := start + 1;
      while (endp^ <> AnsiChar(ch)) and (endp^ <> #0) do
      begin
        Inc(endp);
        Inc(length_);
      end;

      temp := PAnsiChar(mycalloc(1, length_ + 1, 'INTLIB.C', 230));
      Move(start^, temp^, length_);
      temp[length_] := #0;
      programStackPushString(program_, temp);
    end
    else
      programStackPushInteger(program_, 0);
  end
  else
  begin
    length_ := 0;
    endp := str;
    while (endp^ <> AnsiChar(ch)) and (endp^ <> #0) do
    begin
      Inc(endp);
      Inc(length_);
    end;

    if str <> nil then
    begin
      temp := PAnsiChar(mycalloc(1, length_ + 1, 'INTLIB.C', 248));
      Move(str^, temp^, length_);
      temp[length_] := #0;
      programStackPushString(program_, temp);
    end
    else
      programStackPushInteger(program_, 0);
  end;

  if temp <> nil then
    myfree(temp, 'INTLIB.C', 260);
end;

// -----------------------------------------------------------------------
// op_printrect
// -----------------------------------------------------------------------
procedure op_printrect(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  value: TProgramValue;
  str: array[0..79] of AnsiChar;
begin
  selectWindowID(program_^.windowId);

  v1 := programStackPopInteger(program_);
  if v1 > 2 then
    interpretError('Invalid arg 3 given to printrect, expecting int', []);

  v2 := programStackPopInteger(program_);

  value := programStackPopValue(program_);
  case value.opcode and VALUE_TYPE_MASK of
    VALUE_TYPE_STRING:
      StrLFmt(@str[0], SizeOf(str) - 1, '%s', [interpretGetString(program_, value.opcode, value.integerValue)]);
    VALUE_TYPE_FLOAT:
      StrLFmt(@str[0], SizeOf(str) - 1, '%.5f', [Double(value.floatValue)]);
    VALUE_TYPE_INT:
      StrLFmt(@str[0], SizeOf(str) - 1, '%d', [value.integerValue]);
  end;

  if not windowPrintRect(@str[0], v2, v1) then
    interpretError('Error in printrect', []);
end;

// -----------------------------------------------------------------------
// op_selectwin
// -----------------------------------------------------------------------
procedure op_selectwin(program_: PProgram); cdecl;
var
  windowName: PAnsiChar;
  win: Integer;
begin
  windowName := programStackPopString(program_);
  win := pushWindow(windowName);
  if win = -1 then
    interpretError('Error selecing window %s'#10, [windowName]);

  program_^.windowId := win;

  interpretOutputFunc(TInterpretOutputFunc(@windowOutput));
end;

// -----------------------------------------------------------------------
// op_display
// -----------------------------------------------------------------------
procedure op_display(program_: PProgram); cdecl;
var
  fileName: PAnsiChar;
  mangledFileName: PAnsiChar;
begin
  fileName := programStackPopString(program_);

  selectWindowID(program_^.windowId);

  mangledFileName := interpretMangleName(fileName);
  displayFile(mangledFileName);
end;

// -----------------------------------------------------------------------
// op_displayraw
// -----------------------------------------------------------------------
procedure op_displayraw(program_: PProgram); cdecl;
var
  fileName: PAnsiChar;
  mangledFileName: PAnsiChar;
begin
  fileName := programStackPopString(program_);

  selectWindowID(program_^.windowId);

  mangledFileName := interpretMangleName(fileName);
  displayFileRaw(mangledFileName);
end;

// -----------------------------------------------------------------------
// interpretFadePaletteBK
// -----------------------------------------------------------------------
procedure interpretFadePaletteBK(oldPalette: PByte; newPalette: PByte;
  a3: Integer; duration: Single; shouldProcessBk: Integer);
var
  time_: LongWord;
  previousTime: LongWord;
  delta: LongWord;
  step: Integer;
  steps: Integer;
  index: Integer;
  palette: array[0..256 * 3 - 1] of Byte;
begin
  time_ := get_time();
  previousTime := time_;
  steps := Trunc(duration);
  step := 0;
  delta := 0;

  if duration <> 0.0 then
  begin
    while step < steps do
    begin
      if delta <> 0 then
      begin
        for index := 0 to 767 do
          palette[index] := oldPalette[index] - Byte((Integer(oldPalette[index]) - Integer(newPalette[index])) * step div steps);

        setSystemPalette(@palette[0]);
        renderPresent();

        previousTime := time_;
        step := step + Integer(delta);
      end;

      if shouldProcessBk <> 0 then
        process_bk();

      time_ := get_time();
      delta := time_ - previousTime;
    end;
  end;

  setSystemPalette(newPalette);
  renderPresent();
end;

// -----------------------------------------------------------------------
// interpretFadePalette
// -----------------------------------------------------------------------
procedure interpretFadePalette(oldPalette: PByte; newPalette: PByte; a3: Integer; duration: Single);
begin
  interpretFadePaletteBK(oldPalette, newPalette, a3, duration, 1);
end;

// -----------------------------------------------------------------------
// intlibGetFadeIn
// -----------------------------------------------------------------------
function intlibGetFadeIn: Integer;
begin
  Result := Ord(currentlyFadedIn);
end;

// -----------------------------------------------------------------------
// interpretFadeOut
// -----------------------------------------------------------------------
procedure interpretFadeOut(duration: Single);
var
  cursorWasHidden: Boolean;
begin
  cursorWasHidden := mouse_hidden();
  mouse_hide();

  interpretFadePaletteBK(getSystemPalette(), @blackPal[0], 64, duration, 1);

  if not cursorWasHidden then
    mouse_show();
end;

// -----------------------------------------------------------------------
// interpretFadeIn
// -----------------------------------------------------------------------
procedure interpretFadeIn(duration: Single);
begin
  interpretFadePaletteBK(@blackPal[0], @cmap[0], 64, duration, 1);
end;

// -----------------------------------------------------------------------
// interpretFadeOutNoBK
// -----------------------------------------------------------------------
procedure interpretFadeOutNoBK(duration: Single);
var
  cursorWasHidden: Boolean;
begin
  cursorWasHidden := mouse_hidden();
  mouse_hide();

  interpretFadePaletteBK(getSystemPalette(), @blackPal[0], 64, duration, 0);

  if not cursorWasHidden then
    mouse_show();
end;

// -----------------------------------------------------------------------
// interpretFadeInNoBK
// -----------------------------------------------------------------------
procedure interpretFadeInNoBK(duration: Single);
begin
  interpretFadePaletteBK(@blackPal[0], @cmap[0], 64, duration, 0);
end;

// -----------------------------------------------------------------------
// op_fadein
// -----------------------------------------------------------------------
procedure op_fadein(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  setSystemPalette(@blackPal[0]);

  interpretFadeIn(Single(data));

  currentlyFadedIn := True;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// op_fadeout
// -----------------------------------------------------------------------
procedure op_fadeout(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  interpretFadeOut(Single(data));

  currentlyFadedIn := False;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// checkMovie
// -----------------------------------------------------------------------
function checkMovie(program_: PProgram): Integer;
begin
  if dialogGetDialogDepth() > 0 then
  begin
    Result := 1;
    Exit;
  end;

  Result := windowMoviePlaying();
end;

// -----------------------------------------------------------------------
// op_movieflags
// -----------------------------------------------------------------------
procedure op_movieflags(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if not windowSetMovieFlags(data) then
    interpretError('Error setting movie flags'#10, []);
end;

// -----------------------------------------------------------------------
// op_playmovie
// -----------------------------------------------------------------------
procedure op_playmovie(program_: PProgram); cdecl;
var
  movieFileName: PAnsiChar;
  mangledFileName: PAnsiChar;
begin
  movieFileName := programStackPopString(program_);

  StrLCopy(@playmovie_name[0], movieFileName, 99);

  if StrRScan(@playmovie_name[0], '.') = nil then
    StrLCat(@playmovie_name[0], '.mve', 99);

  selectWindowID(program_^.windowId);

  program_^.flags := program_^.flags or PROGRAM_IS_WAITING;
  program_^.checkWaitFunc := TInterpretCheckWaitFunc(@checkMovie);

  mangledFileName := interpretMangleName(@playmovie_name[0]);
  if not windowPlayMovie(mangledFileName) then
    interpretError('Error playing movie', []);
end;

// -----------------------------------------------------------------------
// op_playmovierect
// -----------------------------------------------------------------------
procedure op_playmovierect(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  movieFileName: PAnsiChar;
  mangledFileName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  movieFileName := programStackPopString(program_);

  StrLCopy(@playmovierect_name[0], movieFileName, 99);

  if StrRScan(@playmovierect_name[0], '.') = nil then
    StrLCat(@playmovierect_name[0], '.mve', 99);

  selectWindowID(program_^.windowId);

  program_^.checkWaitFunc := TInterpretCheckWaitFunc(@checkMovie);
  program_^.flags := program_^.flags or PROGRAM_IS_WAITING;

  mangledFileName := interpretMangleName(@playmovierect_name[0]);
  if not windowPlayMovieRect(mangledFileName, x, y, width, height) then
    interpretError('Error playing movie', []);
end;

// -----------------------------------------------------------------------
// op_stopmovie
// -----------------------------------------------------------------------
procedure op_stopmovie(program_: PProgram); cdecl;
begin
  windowStopMovie();
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x40;
end;

// -----------------------------------------------------------------------
// op_deleteregion
// -----------------------------------------------------------------------
procedure op_deleteregion(program_: PProgram); cdecl;
var
  value: TProgramValue;
  regionName: PAnsiChar;
begin
  value := programStackPopValue(program_);

  selectWindowID(program_^.windowId);

  if value.integerValue <> -1 then
    regionName := interpretGetString(program_, value.opcode, value.integerValue)
  else
    regionName := nil;
  windowDeleteRegion(regionName);
end;

// -----------------------------------------------------------------------
// op_activateregion
// -----------------------------------------------------------------------
procedure op_activateregion(program_: PProgram); cdecl;
var
  v1: Integer;
  regionName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  regionName := programStackPopString(program_);

  windowActivateRegion(regionName, v1);
end;

// -----------------------------------------------------------------------
// op_checkregion
// -----------------------------------------------------------------------
procedure op_checkregion(program_: PProgram); cdecl;
var
  regionName: PAnsiChar;
  regionExists: Boolean;
begin
  regionName := programStackPopString(program_);

  regionExists := windowCheckRegionExists(regionName);
  programStackPushInteger(program_, Ord(regionExists));
end;

// -----------------------------------------------------------------------
// op_addregion
// -----------------------------------------------------------------------
procedure op_addregion(program_: PProgram); cdecl;
var
  args: Integer;
  y: Integer;
  x: Integer;
  regionName: PAnsiChar;
begin
  args := programStackPopInteger(program_);

  if args < 2 then
    interpretError('addregion call without enough points!', []);

  selectWindowID(program_^.windowId);

  windowStartRegion(args div 2);

  while args >= 2 do
  begin
    y := programStackPopInteger(program_);
    x := programStackPopInteger(program_);

    y := (y * windowGetYres() + 479) div 480;
    x := (x * windowGetXres() + 639) div 640;
    args := args - 2;

    windowAddRegionPoint(x, y, True);
  end;

  if args = 0 then
  begin
    interpretError('Unnamed regions not allowed'#10, []);
    windowEndRegion();
  end
  else
  begin
    regionName := programStackPopString(program_);
    windowAddRegionName(regionName);
    windowEndRegion();
  end;
end;

// -----------------------------------------------------------------------
// op_addregionproc
// -----------------------------------------------------------------------
procedure op_addregionproc(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  v3: Integer;
  v4: Integer;
  regionName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  v2 := programStackPopInteger(program_);
  v3 := programStackPopInteger(program_);
  v4 := programStackPopInteger(program_);
  regionName := programStackPopString(program_);

  selectWindowID(program_^.windowId);

  if not windowAddRegionProc(regionName, program_, v4, v3, v2, v1) then
    interpretError('Error setting procedures to region %s'#10, [regionName]);
end;

// -----------------------------------------------------------------------
// op_addregionrightproc
// -----------------------------------------------------------------------
procedure op_addregionrightproc(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  regionName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  v2 := programStackPopInteger(program_);
  regionName := programStackPopString(program_);
  selectWindowID(program_^.windowId);

  if not windowAddRegionRightProc(regionName, program_, v2, v1) then
    interpretError('ErrorError setting right button procedures to region %s'#10, [regionName]);
end;

// -----------------------------------------------------------------------
// op_createwin
// -----------------------------------------------------------------------
procedure op_createwin(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  windowName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  windowName := programStackPopString(program_);

  x := (x * windowGetXres() + 639) div 640;
  y := (y * windowGetYres() + 479) div 480;
  width := (width * windowGetXres() + 639) div 640;
  height := (height * windowGetYres() + 479) div 480;

  if createWindow(windowName, x, y, width, height, Integer(colorTable[0]), 0) = -1 then
    interpretError('Couldn''t create window.', []);
end;

// -----------------------------------------------------------------------
// op_resizewin
// -----------------------------------------------------------------------
procedure op_resizewin(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  windowName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  windowName := programStackPopString(program_);

  x := (x * windowGetXres() + 639) div 640;
  y := (y * windowGetYres() + 479) div 480;
  width := (width * windowGetXres() + 639) div 640;
  height := (height * windowGetYres() + 479) div 480;

  if resizeWindow(windowName, x, y, width, height) = -1 then
    interpretError('Couldn''t resize window.', []);
end;

// -----------------------------------------------------------------------
// op_scalewin
// -----------------------------------------------------------------------
procedure op_scalewin(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  windowName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  windowName := programStackPopString(program_);

  x := (x * windowGetXres() + 639) div 640;
  y := (y * windowGetYres() + 479) div 480;
  width := (width * windowGetXres() + 639) div 640;
  height := (height * windowGetYres() + 479) div 480;

  if scaleWindow(windowName, x, y, width, height) = -1 then
    interpretError('Couldn''t scale window.', []);
end;

// -----------------------------------------------------------------------
// op_deletewin
// -----------------------------------------------------------------------
procedure op_deletewin(program_: PProgram); cdecl;
var
  windowName: PAnsiChar;
begin
  windowName := programStackPopString(program_);

  if not deleteWindow(windowName) then
    interpretError('Error deleting window %s'#10, [windowName]);

  program_^.windowId := popWindow();
end;

// -----------------------------------------------------------------------
// op_saystart
// -----------------------------------------------------------------------
procedure op_saystart(program_: PProgram); cdecl;
var
  rc: Integer;
begin
  sayStartingPosition := 0;

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  rc := dialogStart(program_);
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if rc <> 0 then
    interpretError('Error starting dialog.', []);
end;

// -----------------------------------------------------------------------
// op_saystartpos
// -----------------------------------------------------------------------
procedure op_saystartpos(program_: PProgram); cdecl;
var
  rc: Integer;
begin
  sayStartingPosition := programStackPopInteger(program_);

  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  rc := dialogStart(program_);
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if rc <> 0 then
    interpretError('Error starting dialog.', []);
end;

// -----------------------------------------------------------------------
// op_sayreplytitle
// -----------------------------------------------------------------------
procedure op_sayreplytitle(program_: PProgram); cdecl;
var
  value: TProgramValue;
  str: PAnsiChar;
begin
  value := programStackPopValue(program_);

  str := nil;
  if (value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    str := interpretGetString(program_, value.opcode, value.integerValue);

  if dialogTitle(str) <> 0 then
    interpretError('Error setting title.', []);
end;

// -----------------------------------------------------------------------
// op_saygotoreply
// -----------------------------------------------------------------------
procedure op_saygotoreply(program_: PProgram); cdecl;
var
  value: TProgramValue;
  str: PAnsiChar;
begin
  value := programStackPopValue(program_);

  str := nil;
  if (value.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    str := interpretGetString(program_, value.opcode, value.integerValue);

  if dialogGotoReply(str) <> 0 then
    interpretError('Error during goto, couldn''t find reply target %s', [str]);
end;

// -----------------------------------------------------------------------
// op_sayoption
// -----------------------------------------------------------------------
procedure op_sayoption(program_: PProgram); cdecl;
var
  v3: TProgramValue;
  v2val: TProgramValue;
  v1: PAnsiChar;
  v2str: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  v3 := programStackPopValue(program_);
  v2val := programStackPopValue(program_);

  if (v2val.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    v1 := interpretGetString(program_, v2val.opcode, v2val.integerValue)
  else
    v1 := nil;

  if (v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v2str := interpretGetString(program_, v3.opcode, v3.integerValue);
    if dialogOption(v1, v2str) <> 0 then
    begin
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      interpretError('Error setting option.', []);
    end;
  end
  else if (v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
  begin
    if dialogOptionProc(v1, v3.integerValue) <> 0 then
    begin
      program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
      interpretError('Error setting option.', []);
    end;
  end
  else
    interpretError('Invalid arg 2 to sayOption', []);

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// op_sayreply
// -----------------------------------------------------------------------
procedure op_sayreply(program_: PProgram); cdecl;
var
  v3: TProgramValue;
  v4: TProgramValue;
  v1: PAnsiChar;
  v2: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  v3 := programStackPopValue(program_);
  v4 := programStackPopValue(program_);

  if (v4.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    v1 := interpretGetString(program_, v4.opcode, v4.integerValue)
  else
    v1 := nil;

  if (v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    v2 := interpretGetString(program_, v3.opcode, v3.integerValue)
  else
    v2 := nil;

  if dialogReply(v1, v2) <> 0 then
  begin
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    interpretError('Error setting option.', []);
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// checkDialog
// -----------------------------------------------------------------------
function checkDialog(program_: PProgram): Integer; cdecl;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x40;
  Result := Ord(dialogGetDialogDepth() <> -1);
end;

// -----------------------------------------------------------------------
// op_sayend
// -----------------------------------------------------------------------
procedure op_sayend(program_: PProgram); cdecl;
var
  rc: Integer;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;
  rc := dialogGo(sayStartingPosition);
  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);

  if rc = -2 then
  begin
    program_^.checkWaitFunc := TInterpretCheckWaitFunc(@checkDialog);
    program_^.flags := program_^.flags or PROGRAM_IS_WAITING;
  end;
end;

// -----------------------------------------------------------------------
// op_saygetlastpos
// -----------------------------------------------------------------------
procedure op_saygetlastpos(program_: PProgram); cdecl;
var
  value: Integer;
begin
  value := dialogGetExitPoint();
  programStackPushInteger(program_, value);
end;

// -----------------------------------------------------------------------
// op_sayquit
// -----------------------------------------------------------------------
procedure op_sayquit(program_: PProgram); cdecl;
begin
  if dialogQuit() <> 0 then
    interpretError('Error quitting option.', []);
end;

// -----------------------------------------------------------------------
// getTimeOut / setTimeOut
// -----------------------------------------------------------------------
function getTimeOut: Integer;
begin
  Result := TimeOut;
end;

procedure setTimeOut(value: Integer);
begin
  TimeOut := value;
end;

// -----------------------------------------------------------------------
// op_saymessagetimeout
// -----------------------------------------------------------------------
procedure op_saymessagetimeout(program_: PProgram); cdecl;
var
  value: TProgramValue;
begin
  value := programStackPopValue(program_);

  if (value.opcode and VALUE_TYPE_MASK) = $4000 then
    interpretError('sayMsgTimeout:  invalid var type passed.', []);

  TimeOut := value.integerValue;
end;

// -----------------------------------------------------------------------
// op_saymessage
// -----------------------------------------------------------------------
procedure op_saymessage(program_: PProgram); cdecl;
var
  v3: TProgramValue;
  v4: TProgramValue;
  v1: PAnsiChar;
  v2: PAnsiChar;
begin
  program_^.flags := program_^.flags or PROGRAM_FLAG_0x20;

  v3 := programStackPopValue(program_);
  v4 := programStackPopValue(program_);

  if (v4.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    v1 := interpretGetString(program_, v4.opcode, v4.integerValue)
  else
    v1 := nil;

  if (v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
    v2 := interpretGetString(program_, v3.opcode, v3.integerValue)
  else
    v2 := nil;

  if dialogMessage(v1, v2, TimeOut) <> 0 then
  begin
    program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
    interpretError('Error setting option.', []);
  end;

  program_^.flags := program_^.flags and (not PROGRAM_FLAG_0x20);
end;

// -----------------------------------------------------------------------
// op_gotoxy
// -----------------------------------------------------------------------
procedure op_gotoxy(program_: PProgram); cdecl;
var
  y: Integer;
  x: Integer;
begin
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  selectWindowID(program_^.windowId);

  windowGotoXY(x, y);
end;

// -----------------------------------------------------------------------
// op_addbuttonflag
// -----------------------------------------------------------------------
procedure op_addbuttonflag(program_: PProgram); cdecl;
var
  flag: Integer;
  buttonName: PAnsiChar;
begin
  flag := programStackPopInteger(program_);
  buttonName := programStackPopString(program_);
  if not windowSetButtonFlag(buttonName, flag) then
    interpretError('Error setting flag on button %s', [buttonName]);
end;

// -----------------------------------------------------------------------
// op_addregionflag
// -----------------------------------------------------------------------
procedure op_addregionflag(program_: PProgram); cdecl;
var
  flag: Integer;
  regionName: PAnsiChar;
begin
  flag := programStackPopInteger(program_);
  regionName := programStackPopString(program_);
  if not windowSetRegionFlag(regionName, flag) then
    interpretError('Error setting flag on region %s', [regionName]);
end;

// -----------------------------------------------------------------------
// op_addbutton
// -----------------------------------------------------------------------
procedure op_addbutton(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  buttonName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  buttonName := programStackPopString(program_);

  selectWindowID(program_^.windowId);

  height := (height * windowGetYres() + 479) div 480;
  width := (width * windowGetXres() + 639) div 640;
  y := (y * windowGetYres() + 479) div 480;
  x := (x * windowGetXres() + 639) div 640;

  windowAddButton(buttonName, x, y, width, height, 0);
end;

// -----------------------------------------------------------------------
// op_addbuttontext
// -----------------------------------------------------------------------
procedure op_addbuttontext(program_: PProgram); cdecl;
var
  text_: PAnsiChar;
  buttonName: PAnsiChar;
begin
  text_ := programStackPopString(program_);
  buttonName := programStackPopString(program_);

  if not windowAddButtonText(buttonName, text_) then
    interpretError('Error setting text to button %s'#10, [buttonName]);
end;

// -----------------------------------------------------------------------
// op_addbuttongfx
// -----------------------------------------------------------------------
procedure op_addbuttongfx(program_: PProgram); cdecl;
var
  v1: TProgramValue;
  v2: TProgramValue;
  v3: TProgramValue;
  buttonName: PAnsiChar;
  pressedFileName: PAnsiChar;
  normalFileName: PAnsiChar;
  hoverFileName: PAnsiChar;
begin
  v1 := programStackPopValue(program_);
  v2 := programStackPopValue(program_);
  v3 := programStackPopValue(program_);
  buttonName := programStackPopString(program_);

  if (((v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING) or (((v3.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v3.integerValue = 0)))
    or (((v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING) or (((v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v2.integerValue = 0)))
    or (((v1.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING) or (((v1.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v1.integerValue = 0))) then
  begin
    pressedFileName := interpretMangleName(interpretGetString(program_, v3.opcode, v3.integerValue));
    normalFileName := interpretMangleName(interpretGetString(program_, v2.opcode, v2.integerValue));
    hoverFileName := interpretMangleName(interpretGetString(program_, v1.opcode, v1.integerValue));

    selectWindowID(program_^.windowId);

    if not windowAddButtonGfx(buttonName, pressedFileName, normalFileName, hoverFileName) then
      interpretError('Error setting graphics to button %s'#10, [buttonName]);
  end
  else
    interpretError('Invalid filename given to addbuttongfx', []);
end;

// -----------------------------------------------------------------------
// op_addbuttonproc
// -----------------------------------------------------------------------
procedure op_addbuttonproc(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  v3: Integer;
  v4: Integer;
  buttonName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  v2 := programStackPopInteger(program_);
  v3 := programStackPopInteger(program_);
  v4 := programStackPopInteger(program_);
  buttonName := programStackPopString(program_);
  selectWindowID(program_^.windowId);

  if not windowAddButtonProc(buttonName, program_, v4, v3, v2, v1) then
    interpretError('Error setting procedures to button %s'#10, [buttonName]);
end;

// -----------------------------------------------------------------------
// op_addbuttonrightproc
// -----------------------------------------------------------------------
procedure op_addbuttonrightproc(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  regionName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  v2 := programStackPopInteger(program_);
  regionName := programStackPopString(program_);
  selectWindowID(program_^.windowId);

  if not windowAddRegionRightProc(regionName, program_, v2, v1) then
    interpretError('Error setting right button procedures to button %s'#10, [regionName]);
end;

// -----------------------------------------------------------------------
// op_showwin
// -----------------------------------------------------------------------
procedure op_showwin(program_: PProgram); cdecl;
begin
  selectWindowID(program_^.windowId);
  windowDraw();
end;

// -----------------------------------------------------------------------
// op_deletebutton
// -----------------------------------------------------------------------
procedure op_deletebutton(program_: PProgram); cdecl;
var
  value: TProgramValue;
  buttonName: PAnsiChar;
begin
  value := programStackPopValue(program_);

  case value.opcode and VALUE_TYPE_MASK of
    VALUE_TYPE_STRING:
      ; // ok
    VALUE_TYPE_INT:
    begin
      if value.integerValue <> -1 then
        interpretError('Invalid type given to delete button', []);
    end;
  else
    interpretError('Invalid type given to delete button', []);
  end;

  selectWindowID(program_^.windowId);

  if (value.opcode and $F7FF) = VALUE_TYPE_INT then
  begin
    if windowDeleteButton(nil) then
      Exit;
  end
  else
  begin
    buttonName := interpretGetString(program_, value.opcode, value.integerValue);
    if windowDeleteButton(buttonName) then
      Exit;
  end;

  interpretError('Error deleting button', []);
end;

// -----------------------------------------------------------------------
// op_fillwin
// -----------------------------------------------------------------------
procedure op_fillwin(program_: PProgram); cdecl;
var
  b: TProgramValue;
  g: TProgramValue;
  r: TProgramValue;
begin
  b := programStackPopValue(program_);
  g := programStackPopValue(program_);
  r := programStackPopValue(program_);

  if (r.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (r.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if r.integerValue = 1 then
        r.floatValue := 1.0
      else if r.integerValue <> 0 then
        interpretError('Invalid red value given to fillwin', []);
    end;
  end;

  if (g.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (g.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if g.integerValue = 1 then
        g.floatValue := 1.0
      else if g.integerValue <> 0 then
        interpretError('Invalid green value given to fillwin', []);
    end;
  end;

  if (b.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (b.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if b.integerValue = 1 then
        b.floatValue := 1.0
      else if b.integerValue <> 0 then
        interpretError('Invalid blue value given to fillwin', []);
    end;
  end;

  selectWindowID(program_^.windowId);

  windowFill(r.floatValue, g.floatValue, b.floatValue);
end;

// -----------------------------------------------------------------------
// op_fillrect
// -----------------------------------------------------------------------
procedure op_fillrect(program_: PProgram); cdecl;
var
  b: TProgramValue;
  g: TProgramValue;
  r: TProgramValue;
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
begin
  b := programStackPopValue(program_);
  g := programStackPopValue(program_);
  r := programStackPopValue(program_);
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  if (r.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (r.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if r.integerValue = 1 then
        r.floatValue := 1.0
      else if r.integerValue <> 0 then
        interpretError('Invalid red value given to fillrect', []);
    end;
  end;

  if (g.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (g.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if g.integerValue = 1 then
        g.floatValue := 1.0
      else if g.integerValue <> 0 then
        interpretError('Invalid green value given to fillrect', []);
    end;
  end;

  if (b.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT then
  begin
    if (b.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
    begin
      if b.integerValue = 1 then
        b.floatValue := 1.0
      else if b.integerValue <> 0 then
        interpretError('Invalid blue value given to fillrect', []);
    end;
  end;

  selectWindowID(program_^.windowId);

  windowFillRect(x, y, width, height, r.floatValue, g.floatValue, b.floatValue);
end;

// -----------------------------------------------------------------------
// op_hidemouse
// -----------------------------------------------------------------------
procedure op_hidemouse(program_: PProgram); cdecl;
begin
  mouse_hide();
end;

// -----------------------------------------------------------------------
// op_showmouse
// -----------------------------------------------------------------------
procedure op_showmouse(program_: PProgram); cdecl;
begin
  mouse_show();
end;

// -----------------------------------------------------------------------
// op_mouseshape
// -----------------------------------------------------------------------
procedure op_mouseshape(program_: PProgram); cdecl;
var
  v1: Integer;
  v2: Integer;
  fileName: PAnsiChar;
begin
  v1 := programStackPopInteger(program_);
  v2 := programStackPopInteger(program_);
  fileName := programStackPopString(program_);

  if not mouseSetMouseShape(fileName, v2, v1) then
    interpretError('Error loading mouse shape.', []);
end;

// -----------------------------------------------------------------------
// op_setglobalmousefunc
// -----------------------------------------------------------------------
procedure op_setglobalmousefunc(program_: PProgram); cdecl;
begin
  interpretError('setglobalmousefunc not defined', []);
end;

// -----------------------------------------------------------------------
// op_displaygfx
// -----------------------------------------------------------------------
procedure op_displaygfx(program_: PProgram); cdecl;
var
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  fileName: PAnsiChar;
  mangledFileName: PAnsiChar;
begin
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);
  fileName := programStackPopString(program_);

  mangledFileName := interpretMangleName(fileName);
  windowDisplay(mangledFileName, x, y, width, height);
end;

// -----------------------------------------------------------------------
// op_loadpalettetable
// -----------------------------------------------------------------------
procedure op_loadpalettetable(program_: PProgram); cdecl;
var
  path: PAnsiChar;
begin
  path := programStackPopString(program_);
  if not loadColorTable(path) then
    interpretError('%s', [colorError()]);
end;

// -----------------------------------------------------------------------
// op_addNamedEvent
// -----------------------------------------------------------------------
procedure op_addNamedEvent(program_: PProgram); cdecl;
var
  proc: Integer;
  name: PAnsiChar;
begin
  proc := programStackPopInteger(program_);
  name := programStackPopString(program_);
  nevs_addevent(name, program_, proc, NEVS_TYPE_EVENT);
end;

// -----------------------------------------------------------------------
// op_addNamedHandler
// -----------------------------------------------------------------------
procedure op_addNamedHandler(program_: PProgram); cdecl;
var
  proc: Integer;
  name: PAnsiChar;
begin
  proc := programStackPopInteger(program_);
  name := programStackPopString(program_);
  nevs_addevent(name, program_, proc, NEVS_TYPE_HANDLER);
end;

// -----------------------------------------------------------------------
// op_clearNamed
// -----------------------------------------------------------------------
procedure op_clearNamed(program_: PProgram); cdecl;
var
  str: PAnsiChar;
begin
  str := programStackPopString(program_);
  nevs_clearevent(str);
end;

// -----------------------------------------------------------------------
// op_signalNamed
// -----------------------------------------------------------------------
procedure op_signalNamed(program_: PProgram); cdecl;
var
  str: PAnsiChar;
begin
  str := programStackPopString(program_);
  nevs_signal(str);
end;

// -----------------------------------------------------------------------
// op_addkey
// -----------------------------------------------------------------------
procedure op_addkey(program_: PProgram); cdecl;
var
  proc: Integer;
  key: Integer;
begin
  proc := programStackPopInteger(program_);
  key := programStackPopInteger(program_);

  if key = -1 then
  begin
    anyKeyOffset := proc;
    anyKeyProg := program_;
  end
  else
  begin
    if key > INT_LIB_KEY_HANDLERS_CAPACITY - 1 then
      interpretError('Key out of range', []);

    inputProc[key].program_ := program_;
    inputProc[key].proc := proc;
  end;
end;

// -----------------------------------------------------------------------
// op_deletekey
// -----------------------------------------------------------------------
procedure op_deletekey(program_: PProgram); cdecl;
var
  key: Integer;
begin
  key := programStackPopInteger(program_);

  if key = -1 then
  begin
    anyKeyOffset := 0;
    anyKeyProg := nil;
  end
  else
  begin
    if key > INT_LIB_KEY_HANDLERS_CAPACITY - 1 then
      interpretError('Key out of range', []);

    inputProc[key].program_ := nil;
    inputProc[key].proc := 0;
  end;
end;

// -----------------------------------------------------------------------
// op_refreshmouse
// -----------------------------------------------------------------------
procedure op_refreshmouse(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if not windowRefreshRegions() then
    executeProc(program_, data);
end;

// -----------------------------------------------------------------------
// op_setfont
// -----------------------------------------------------------------------
procedure op_setfont(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if windowSetFont(data) <> 0 then
    interpretError('Error setting font', []);
end;

// -----------------------------------------------------------------------
// op_settextflags
// -----------------------------------------------------------------------
procedure op_settextflags(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if windowSetTextFlags(data) <> 0 then
    interpretError('Error setting text flags', []);
end;

// -----------------------------------------------------------------------
// op_settextcolor
// -----------------------------------------------------------------------
procedure op_settextcolor(program_: PProgram); cdecl;
var
  value: array[0..2] of TProgramValue;
  arg: Integer;
  r, g, b: Single;
begin
  for arg := 0 to 2 do
    value[arg] := programStackPopValue(program_);

  for arg := 0 to 2 do
  begin
    if ((value[arg].opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT)
      and ((value[arg].opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT)
      and (value[arg].integerValue <> 0) then
      interpretError('Invalid type given to settextcolor', []);
  end;

  r := value[2].floatValue;
  g := value[1].floatValue;
  b := value[0].floatValue;

  if windowSetTextColor(r, g, b) <> 0 then
    interpretError('Error setting text color', []);
end;

// -----------------------------------------------------------------------
// op_sayoptioncolor
// -----------------------------------------------------------------------
procedure op_sayoptioncolor(program_: PProgram); cdecl;
var
  value: array[0..2] of TProgramValue;
  arg: Integer;
  r, g, b: Single;
begin
  for arg := 0 to 2 do
    value[arg] := programStackPopValue(program_);

  for arg := 0 to 2 do
  begin
    if ((value[arg].opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT)
      and ((value[arg].opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT)
      and (value[arg].integerValue <> 0) then
      interpretError('Invalid type given to sayoptioncolor', []);
  end;

  r := value[2].floatValue;
  g := value[1].floatValue;
  b := value[0].floatValue;

  if dialogSetOptionColor(r, g, b) <> 0 then
    interpretError('Error setting option color', []);
end;

// -----------------------------------------------------------------------
// op_sayreplycolor
// -----------------------------------------------------------------------
procedure op_sayreplycolor(program_: PProgram); cdecl;
var
  value: array[0..2] of TProgramValue;
  arg: Integer;
  r, g, b: Single;
begin
  for arg := 0 to 2 do
    value[arg] := programStackPopValue(program_);

  for arg := 0 to 2 do
  begin
    if ((value[arg].opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT)
      and ((value[arg].opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT)
      and (value[arg].integerValue <> 0) then
      interpretError('Invalid type given to sayreplycolor', []);
  end;

  r := value[2].floatValue;
  g := value[1].floatValue;
  b := value[0].floatValue;

  if dialogSetReplyColor(r, g, b) <> 0 then
    interpretError('Error setting reply color', []);
end;

// -----------------------------------------------------------------------
// op_sethighlightcolor
// -----------------------------------------------------------------------
procedure op_sethighlightcolor(program_: PProgram); cdecl;
var
  value: array[0..2] of TProgramValue;
  arg: Integer;
  r, g, b: Single;
begin
  for arg := 0 to 2 do
    value[arg] := programStackPopValue(program_);

  for arg := 0 to 2 do
  begin
    if ((value[arg].opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_FLOAT)
      and ((value[arg].opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT)
      and (value[arg].integerValue <> 0) then
      interpretError('Invalid type given to sayreplycolor', []);
  end;

  r := value[2].floatValue;
  g := value[1].floatValue;
  b := value[0].floatValue;

  if windowSetHighlightColor(r, g, b) <> 0 then
    interpretError('Error setting text highlight color', []);
end;

// -----------------------------------------------------------------------
// op_sayreplywindow
// -----------------------------------------------------------------------
procedure op_sayreplywindow(program_: PProgram); cdecl;
var
  v2: TProgramValue;
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  v1: PAnsiChar;
begin
  v2 := programStackPopValue(program_);
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  if (v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v1 := interpretGetString(program_, v2.opcode, v2.integerValue);
    v1 := interpretMangleName(v1);
    v1 := mystrdup(v1, 'INTLIB.C', 1510);
  end
  else if ((v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v2.integerValue = 0) then
    v1 := nil
  else
  begin
    v1 := nil;
    interpretError('Invalid arg 5 given to sayreplywindow', []);
  end;

  if dialogSetReplyWindow(x, y, width, height, v1) <> 0 then
    interpretError('Error setting reply window', []);
end;

// -----------------------------------------------------------------------
// op_sayreplyflags
// -----------------------------------------------------------------------
procedure op_sayreplyflags(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if dialogSetReplyFlags(SmallInt(data)) <> 0 then
    interpretError('Error setting reply flags', []);
end;

// -----------------------------------------------------------------------
// op_sayoptionflags
// -----------------------------------------------------------------------
procedure op_sayoptionflags(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if dialogSetOptionFlags(SmallInt(data)) <> 0 then
    interpretError('Error setting option flags', []);
end;

// -----------------------------------------------------------------------
// op_sayoptionwindow
// -----------------------------------------------------------------------
procedure op_sayoptionwindow(program_: PProgram); cdecl;
var
  v2: TProgramValue;
  height: Integer;
  width: Integer;
  y: Integer;
  x: Integer;
  v1: PAnsiChar;
begin
  v2 := programStackPopValue(program_);
  height := programStackPopInteger(program_);
  width := programStackPopInteger(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  if (v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v1 := interpretGetString(program_, v2.opcode, v2.integerValue);
    v1 := interpretMangleName(v1);
    v1 := mystrdup(v1, 'INTLIB.C', 1556);
  end
  else if ((v2.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v2.integerValue = 0) then
    v1 := nil
  else
  begin
    v1 := nil;
    interpretError('Invalid arg 5 given to sayoptionwindow', []);
  end;

  if dialogSetOptionWindow(x, y, width, height, v1) <> 0 then
    interpretError('Error setting option window', []);
end;

// -----------------------------------------------------------------------
// op_sayborder
// -----------------------------------------------------------------------
procedure op_sayborder(program_: PProgram); cdecl;
var
  y: Integer;
  x: Integer;
begin
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  if dialogSetBorder(x, y) <> 0 then
    interpretError('Error setting dialog border', []);
end;

// -----------------------------------------------------------------------
// op_sayscrollup
// -----------------------------------------------------------------------
procedure op_sayscrollup(program_: PProgram); cdecl;
var
  v6: TProgramValue;
  v7: TProgramValue;
  v8: TProgramValue;
  v9: TProgramValue;
  y: Integer;
  x: Integer;
  v1: PAnsiChar;
  v2: PAnsiChar;
  v3: PAnsiChar;
  v4: PAnsiChar;
  v5: Integer;
begin
  v6 := programStackPopValue(program_);
  v7 := programStackPopValue(program_);
  v8 := programStackPopValue(program_);
  v9 := programStackPopValue(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  v1 := nil;
  v2 := nil;
  v3 := nil;
  v4 := nil;
  v5 := 0;

  if (v6.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
  begin
    if (v6.integerValue <> -1) and (v6.integerValue <> 0) then
      interpretError('Invalid arg 4 given to sayscrollup', []);

    if v6.integerValue = -1 then
      v5 := 1;
  end
  else
  begin
    if (v6.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING then
      interpretError('Invalid arg 4 given to sayscrollup', []);
  end;

  if ((v7.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v7.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v7.integerValue <> 0) then
    interpretError('Invalid arg 3 given to sayscrollup', []);

  if ((v8.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v8.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v8.integerValue <> 0) then
    interpretError('Invalid arg 2 given to sayscrollup', []);

  if ((v9.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v9.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v9.integerValue <> 0) then
    interpretError('Invalid arg 1 given to sayscrollup', []);

  if (v9.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v1 := interpretGetString(program_, v9.opcode, v9.integerValue);
    v1 := interpretMangleName(v1);
    v1 := mystrdup(v1, 'INTLIB.C', 1611);
  end;

  if (v8.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v2 := interpretGetString(program_, v8.opcode, v8.integerValue);
    v2 := interpretMangleName(v2);
    v2 := mystrdup(v2, 'INTLIB.C', 1613);
  end;

  if (v7.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v3 := interpretGetString(program_, v7.opcode, v7.integerValue);
    v3 := interpretMangleName(v3);
    v3 := mystrdup(v3, 'INTLIB.C', 1615);
  end;

  if (v6.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v4 := interpretGetString(program_, v6.opcode, v6.integerValue);
    v4 := interpretMangleName(v4);
    v4 := mystrdup(v4, 'INTLIB.C', 1617);
  end;

  if dialogSetScrollUp(x, y, v1, v2, v3, v4, v5) <> 0 then
    interpretError('Error setting scroll up', []);
end;

// -----------------------------------------------------------------------
// op_sayscrolldown
// -----------------------------------------------------------------------
procedure op_sayscrolldown(program_: PProgram); cdecl;
var
  v6: TProgramValue;
  v7: TProgramValue;
  v8: TProgramValue;
  v9: TProgramValue;
  y: Integer;
  x: Integer;
  v1: PAnsiChar;
  v2: PAnsiChar;
  v3: PAnsiChar;
  v4: PAnsiChar;
  v5: Integer;
begin
  v6 := programStackPopValue(program_);
  v7 := programStackPopValue(program_);
  v8 := programStackPopValue(program_);
  v9 := programStackPopValue(program_);
  y := programStackPopInteger(program_);
  x := programStackPopInteger(program_);

  v1 := nil;
  v2 := nil;
  v3 := nil;
  v4 := nil;
  v5 := 0;

  if (v6.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT then
  begin
    if (v6.integerValue <> -1) and (v6.integerValue <> 0) then
      interpretError('Invalid arg 4 given to sayscrollup', []);

    if v6.integerValue = -1 then
      v5 := 1;
  end
  else
  begin
    if (v6.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING then
      interpretError('Invalid arg 4 given to sayscrollup', []);
  end;

  if ((v7.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v7.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v7.integerValue <> 0) then
    interpretError('Invalid arg 3 given to sayscrolldown', []);

  if ((v8.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v8.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v8.integerValue <> 0) then
    interpretError('Invalid arg 2 given to sayscrolldown', []);

  if ((v9.opcode and VALUE_TYPE_MASK) <> VALUE_TYPE_STRING) and ((v9.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_INT) and (v9.integerValue <> 0) then
    interpretError('Invalid arg 1 given to sayscrolldown', []);

  if (v9.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v1 := interpretGetString(program_, v9.opcode, v9.integerValue);
    v1 := interpretMangleName(v1);
    v1 := mystrdup(v1, 'INTLIB.C', 1652);
  end;

  if (v8.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v2 := interpretGetString(program_, v8.opcode, v8.integerValue);
    v2 := interpretMangleName(v2);
    v2 := mystrdup(v2, 'INTLIB.C', 1654);
  end;

  if (v7.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v3 := interpretGetString(program_, v7.opcode, v7.integerValue);
    v3 := interpretMangleName(v3);
    v3 := mystrdup(v3, 'INTLIB.C', 1656);
  end;

  if (v6.opcode and VALUE_TYPE_MASK) = VALUE_TYPE_STRING then
  begin
    v4 := interpretGetString(program_, v6.opcode, v6.integerValue);
    v4 := interpretMangleName(v4);
    v4 := mystrdup(v4, 'INTLIB.C', 1658);
  end;

  if dialogSetScrollDown(x, y, v1, v2, v3, v4, v5) <> 0 then
    interpretError('Error setting scroll down', []);
end;

// -----------------------------------------------------------------------
// op_saysetspacing
// -----------------------------------------------------------------------
procedure op_saysetspacing(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if dialogSetSpacing(data) <> 0 then
    interpretError('Error setting option spacing', []);
end;

// -----------------------------------------------------------------------
// op_sayrestart
// -----------------------------------------------------------------------
procedure op_sayrestart(program_: PProgram); cdecl;
begin
  if dialogRestart() <> 0 then
    interpretError('Error restarting option', []);
end;

// -----------------------------------------------------------------------
// soundCallbackInterpret
// -----------------------------------------------------------------------
procedure soundCallbackInterpret(userData: Pointer; a2: Integer); cdecl;
var
  sound: ^PSound;
begin
  if a2 = 1 then
  begin
    sound := userData;
    sound^ := nil;
  end;
end;

// -----------------------------------------------------------------------
// soundDeleteInterpret
// -----------------------------------------------------------------------
function soundDeleteInterpret(value: Integer): Integer;
var
  index: Integer;
  sound: PSound;
begin
  if value = -1 then
  begin
    Result := 1;
    Exit;
  end;

  if (value and LongInt($A0000000)) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  index := value and (not LongInt($A0000000));
  sound := interpretSounds[index];
  if sound = nil then
  begin
    Result := 0;
    Exit;
  end;

  if soundPlaying(sound) then
    soundStop(sound);

  soundDelete(sound);

  interpretSounds[index] := nil;

  Result := 1;
end;

// -----------------------------------------------------------------------
// soundCloseInterpret
// -----------------------------------------------------------------------
procedure soundCloseInterpret;
var
  index: Integer;
begin
  for index := 0 to INT_LIB_SOUNDS_CAPACITY - 1 do
  begin
    if interpretSounds[index] <> nil then
      soundDeleteInterpret(index or LongInt($A0000000));
  end;
end;

// -----------------------------------------------------------------------
// soundStartInterpret
// -----------------------------------------------------------------------
function soundStartInterpret(fileName: PAnsiChar; mode: Integer): Integer;
label
  err;
var
  v3: Integer;
  v5: Integer;
  index: Integer;
  sound: PSound;
  rc: Integer;
begin
  v3 := 1;
  v5 := 0;

  if (mode and $01) <> 0 then
  begin
    // looping
    v5 := v5 or $20;
  end
  else
    v3 := 5;

  if (mode and $02) <> 0 then
    v5 := v5 or $08
  else
    v5 := v5 or $10;

  if (mode and $0100) <> 0 then
  begin
    // memory
    v3 := v3 and (not $03);
    v3 := v3 or $01;
  end;

  if (mode and $0200) <> 0 then
  begin
    // streamed
    v3 := v3 and (not $03);
    v3 := v3 or $02;
  end;

  index := 0;
  while index < INT_LIB_SOUNDS_CAPACITY do
  begin
    if interpretSounds[index] = nil then
      Break;
    Inc(index);
  end;

  if index = INT_LIB_SOUNDS_CAPACITY then
  begin
    Result := -1;
    Exit;
  end;

  sound := soundAllocate(v3, v5);
  interpretSounds[index] := sound;
  if sound = nil then
  begin
    Result := -1;
    Exit;
  end;

  soundSetCallback(sound, @soundCallbackInterpret, @interpretSounds[index]);

  if (mode and $01) <> 0 then
    soundLoop(sound, $FFFF);

  if (mode and $1000) <> 0 then
    soundSetChannel(sound, 2);

  if (mode and $2000) <> 0 then
    soundSetChannel(sound, 3);

  rc := soundLoad(sound, fileName);
  if rc <> SOUND_NO_ERROR then
    goto err;

  rc := soundPlay(sound);

  case rc of
    SOUND_NO_DEVICE:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NO_DEVICE']);
      goto err;
    end;
    SOUND_NOT_INITIALIZED:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NOT_INITIALIZED']);
      goto err;
    end;
    SOUND_NO_SOUND:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NO_SOUND']);
      goto err;
    end;
    SOUND_FUNCTION_NOT_SUPPORTED:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_FUNC_NOT_SUPPORTED']);
      goto err;
    end;
    SOUND_NO_BUFFERS_AVAILABLE:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NO_BUFFERS_AVAILABLE']);
      goto err;
    end;
    SOUND_FILE_NOT_FOUND:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_FILE_NOT_FOUND']);
      goto err;
    end;
    SOUND_ALREADY_PLAYING:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_ALREADY_PLAYING']);
      goto err;
    end;
    SOUND_NOT_PLAYING:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NOT_PLAYING']);
      goto err;
    end;
    SOUND_ALREADY_PAUSED:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_ALREADY_PAUSED']);
      goto err;
    end;
    SOUND_NOT_PAUSED:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NOT_PAUSED']);
      goto err;
    end;
    SOUND_INVALID_HANDLE:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_INVALID_HANDLE']);
      goto err;
    end;
    SOUND_NO_MEMORY_AVAILABLE:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_NO_MEMORY']);
      goto err;
    end;
    SOUND_UNKNOWN_ERROR:
    begin
      debug_printf('soundPlay error: %s'#10, ['SOUND_ERROR']);
      goto err;
    end;
  end;

  Result := index or LongInt($A0000000);
  Exit;

err:
  soundDelete(sound);
  interpretSounds[index] := nil;
  Result := -1;
end;

// -----------------------------------------------------------------------
// soundPauseInterpret
// -----------------------------------------------------------------------
function soundPauseInterpret(value: Integer): Integer;
var
  index: Integer;
  sound: PSound;
  rc: Integer;
begin
  if value = -1 then
  begin
    Result := 1;
    Exit;
  end;

  if (value and LongInt($A0000000)) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  index := value and (not LongInt($A0000000));
  sound := interpretSounds[index];
  if sound = nil then
  begin
    Result := 0;
    Exit;
  end;

  if soundType(sound, $01) <> 0 then
    rc := soundStop(sound)
  else
    rc := soundPause(sound);

  Result := Ord(rc = SOUND_NO_ERROR);
end;

// -----------------------------------------------------------------------
// soundRewindInterpret
// -----------------------------------------------------------------------
function soundRewindInterpret(value: Integer): Integer;
var
  index: Integer;
  sound: PSound;
begin
  if value = -1 then
  begin
    Result := 1;
    Exit;
  end;

  if (value and LongInt($A0000000)) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  index := value and (not LongInt($A0000000));
  sound := interpretSounds[index];
  if sound = nil then
  begin
    Result := 0;
    Exit;
  end;

  if not soundPlaying(sound) then
  begin
    Result := 1;
    Exit;
  end;

  soundStop(sound);

  Result := Ord(soundPlay(sound) = SOUND_NO_ERROR);
end;

// -----------------------------------------------------------------------
// soundUnpauseInterpret
// -----------------------------------------------------------------------
function soundUnpauseInterpret(value: Integer): Integer;
var
  index: Integer;
  sound: PSound;
  rc: Integer;
begin
  if value = -1 then
  begin
    Result := 1;
    Exit;
  end;

  if (value and LongInt($A0000000)) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  index := value and (not LongInt($A0000000));
  sound := interpretSounds[index];
  if sound = nil then
  begin
    Result := 0;
    Exit;
  end;

  if soundType(sound, $01) <> 0 then
    rc := soundPlay(sound)
  else
    rc := soundUnpause(sound);

  Result := Ord(rc = SOUND_NO_ERROR);
end;

// -----------------------------------------------------------------------
// op_soundplay
// -----------------------------------------------------------------------
procedure op_soundplay(program_: PProgram); cdecl;
var
  flags: Integer;
  fileName: PAnsiChar;
  mangledFileName: PAnsiChar;
  rc: Integer;
begin
  flags := programStackPopInteger(program_);
  fileName := programStackPopString(program_);

  mangledFileName := interpretMangleName(fileName);
  rc := soundStartInterpret(mangledFileName, flags);

  programStackPushInteger(program_, rc);
end;

// -----------------------------------------------------------------------
// op_soundpause
// -----------------------------------------------------------------------
procedure op_soundpause(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  soundPauseInterpret(data);
end;

// -----------------------------------------------------------------------
// op_soundresume
// -----------------------------------------------------------------------
procedure op_soundresume(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  soundUnpauseInterpret(data);
end;

// -----------------------------------------------------------------------
// op_soundstop
// -----------------------------------------------------------------------
procedure op_soundstop(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  soundPauseInterpret(data);
end;

// -----------------------------------------------------------------------
// op_soundrewind
// -----------------------------------------------------------------------
procedure op_soundrewind(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  soundRewindInterpret(data);
end;

// -----------------------------------------------------------------------
// op_sounddelete
// -----------------------------------------------------------------------
procedure op_sounddelete(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);
  soundDeleteInterpret(data);
end;

// -----------------------------------------------------------------------
// op_setoneoptpause
// -----------------------------------------------------------------------
procedure op_setoneoptpause(program_: PProgram); cdecl;
var
  data: Integer;
begin
  data := programStackPopInteger(program_);

  if data <> 0 then
  begin
    if (dialogGetMediaFlag() and 8) = 0 then
      Exit;
  end
  else
  begin
    if (dialogGetMediaFlag() and 8) <> 0 then
      Exit;
  end;

  dialogToggleMediaFlag(8);
end;

// -----------------------------------------------------------------------
// updateIntLib
// -----------------------------------------------------------------------
procedure updateIntLib;
begin
  nevs_update();
  updateIntExtra();
end;

// -----------------------------------------------------------------------
// intlibClose
// -----------------------------------------------------------------------
procedure intlibClose;
begin
  dialogClose();
  intExtraClose();

  soundCloseInterpret();

  nevs_close();

  if callbacks <> nil then
  begin
    myfree(callbacks, 'INTLIB.C', 1976);
    callbacks := nil;
    numCallbacks := 0;
  end;
end;

// -----------------------------------------------------------------------
// intLibDoInput
// -----------------------------------------------------------------------
function intLibDoInput(key: Integer): Boolean;
var
  entry: ^TIntLibKeyHandlerEntry;
begin
  if (key < 0) or (key >= INT_LIB_KEY_HANDLERS_CAPACITY) then
  begin
    Result := False;
    Exit;
  end;

  if anyKeyProg <> nil then
  begin
    if anyKeyOffset <> 0 then
      executeProc(anyKeyProg, anyKeyOffset);
    Result := True;
    Exit;
  end;

  entry := @inputProc[key];
  if entry^.program_ = nil then
  begin
    Result := False;
    Exit;
  end;

  if entry^.proc <> 0 then
    executeProc(entry^.program_, entry^.proc);

  Result := True;
end;

// -----------------------------------------------------------------------
// initIntlib
// -----------------------------------------------------------------------
procedure initIntlib;
begin
  windowAddInputFunc(TWindowInputHandler(@intLibDoInput));

  interpretAddFunc($806A, TOpcodeHandler(@op_fillwin3x3));
  interpretAddFunc($808C, TOpcodeHandler(@op_deletebutton));
  interpretAddFunc($8086, TOpcodeHandler(@op_addbutton));
  interpretAddFunc($8088, TOpcodeHandler(@op_addbuttonflag));
  interpretAddFunc($8087, TOpcodeHandler(@op_addbuttontext));
  interpretAddFunc($8089, TOpcodeHandler(@op_addbuttongfx));
  interpretAddFunc($808A, TOpcodeHandler(@op_addbuttonproc));
  interpretAddFunc($808B, TOpcodeHandler(@op_addbuttonrightproc));
  interpretAddFunc($8067, TOpcodeHandler(@op_showwin));
  interpretAddFunc($8068, TOpcodeHandler(@op_fillwin));
  interpretAddFunc($8069, TOpcodeHandler(@op_fillrect));
  interpretAddFunc($8072, TOpcodeHandler(@op_print));
  interpretAddFunc($8073, TOpcodeHandler(@op_format));
  interpretAddFunc($8074, TOpcodeHandler(@op_printrect));
  interpretAddFunc($8075, TOpcodeHandler(@op_setfont));
  interpretAddFunc($8076, TOpcodeHandler(@op_settextflags));
  interpretAddFunc($8077, TOpcodeHandler(@op_settextcolor));
  interpretAddFunc($8078, TOpcodeHandler(@op_sethighlightcolor));
  interpretAddFunc($8064, TOpcodeHandler(@op_selectwin));
  interpretAddFunc($806B, TOpcodeHandler(@op_display));
  interpretAddFunc($806D, TOpcodeHandler(@op_displayraw));
  interpretAddFunc($806C, TOpcodeHandler(@op_displaygfx));
  interpretAddFunc($806F, TOpcodeHandler(@op_fadein));
  interpretAddFunc($8070, TOpcodeHandler(@op_fadeout));
  interpretAddFunc($807A, TOpcodeHandler(@op_playmovie));
  interpretAddFunc($807B, TOpcodeHandler(@op_movieflags));
  interpretAddFunc($807C, TOpcodeHandler(@op_playmovierect));
  interpretAddFunc($8079, TOpcodeHandler(@op_stopmovie));
  interpretAddFunc($807F, TOpcodeHandler(@op_addregion));
  interpretAddFunc($8080, TOpcodeHandler(@op_addregionflag));
  interpretAddFunc($8081, TOpcodeHandler(@op_addregionproc));
  interpretAddFunc($8082, TOpcodeHandler(@op_addregionrightproc));
  interpretAddFunc($8083, TOpcodeHandler(@op_deleteregion));
  interpretAddFunc($8084, TOpcodeHandler(@op_activateregion));
  interpretAddFunc($8085, TOpcodeHandler(@op_checkregion));
  interpretAddFunc($8062, TOpcodeHandler(@op_createwin));
  interpretAddFunc($8063, TOpcodeHandler(@op_deletewin));
  interpretAddFunc($8065, TOpcodeHandler(@op_resizewin));
  interpretAddFunc($8066, TOpcodeHandler(@op_scalewin));
  interpretAddFunc($804E, TOpcodeHandler(@op_saystart));
  interpretAddFunc($804F, TOpcodeHandler(@op_saystartpos));
  interpretAddFunc($8050, TOpcodeHandler(@op_sayreplytitle));
  interpretAddFunc($8051, TOpcodeHandler(@op_saygotoreply));
  interpretAddFunc($8053, TOpcodeHandler(@op_sayoption));
  interpretAddFunc($8052, TOpcodeHandler(@op_sayreply));
  interpretAddFunc($804D, TOpcodeHandler(@op_sayend));
  interpretAddFunc($804C, TOpcodeHandler(@op_sayquit));
  interpretAddFunc($8054, TOpcodeHandler(@op_saymessage));
  interpretAddFunc($8055, TOpcodeHandler(@op_sayreplywindow));
  interpretAddFunc($8056, TOpcodeHandler(@op_sayoptionwindow));
  interpretAddFunc($805F, TOpcodeHandler(@op_sayreplyflags));
  interpretAddFunc($8060, TOpcodeHandler(@op_sayoptionflags));
  interpretAddFunc($8057, TOpcodeHandler(@op_sayborder));
  interpretAddFunc($8058, TOpcodeHandler(@op_sayscrollup));
  interpretAddFunc($8059, TOpcodeHandler(@op_sayscrolldown));
  interpretAddFunc($805A, TOpcodeHandler(@op_saysetspacing));
  interpretAddFunc($805B, TOpcodeHandler(@op_sayoptioncolor));
  interpretAddFunc($805C, TOpcodeHandler(@op_sayreplycolor));
  interpretAddFunc($805D, TOpcodeHandler(@op_sayrestart));
  interpretAddFunc($805E, TOpcodeHandler(@op_saygetlastpos));
  interpretAddFunc($8061, TOpcodeHandler(@op_saymessagetimeout));
  interpretAddFunc($8071, TOpcodeHandler(@op_gotoxy));
  interpretAddFunc($808D, TOpcodeHandler(@op_hidemouse));
  interpretAddFunc($808E, TOpcodeHandler(@op_showmouse));
  interpretAddFunc($8090, TOpcodeHandler(@op_refreshmouse));
  interpretAddFunc($808F, TOpcodeHandler(@op_mouseshape));
  interpretAddFunc($8091, TOpcodeHandler(@op_setglobalmousefunc));
  interpretAddFunc($806E, TOpcodeHandler(@op_loadpalettetable));
  interpretAddFunc($8092, TOpcodeHandler(@op_addNamedEvent));
  interpretAddFunc($8093, TOpcodeHandler(@op_addNamedHandler));
  interpretAddFunc($8094, TOpcodeHandler(@op_clearNamed));
  interpretAddFunc($8095, TOpcodeHandler(@op_signalNamed));
  interpretAddFunc($8096, TOpcodeHandler(@op_addkey));
  interpretAddFunc($8097, TOpcodeHandler(@op_deletekey));
  interpretAddFunc($8098, TOpcodeHandler(@op_soundplay));
  interpretAddFunc($8099, TOpcodeHandler(@op_soundpause));
  interpretAddFunc($809A, TOpcodeHandler(@op_soundresume));
  interpretAddFunc($809B, TOpcodeHandler(@op_soundstop));
  interpretAddFunc($809C, TOpcodeHandler(@op_soundrewind));
  interpretAddFunc($809D, TOpcodeHandler(@op_sounddelete));
  interpretAddFunc($809E, TOpcodeHandler(@op_setoneoptpause));
  interpretAddFunc($809F, TOpcodeHandler(@op_selectfilelist));
  interpretAddFunc($80A0, TOpcodeHandler(@op_tokenize));

  nevs_initonce();
  initIntExtra();
  initDialog();
end;

// -----------------------------------------------------------------------
// interpretRegisterProgramDeleteCallback_intlib
// -----------------------------------------------------------------------
procedure interpretRegisterProgramDeleteCallback_intlib(callback: PIntLibProgramDeleteCallback);
var
  index: Integer;
begin
  index := 0;
  while index < numCallbacks do
  begin
    if callbacks[index] = nil then
      Break;
    Inc(index);
  end;

  if index = numCallbacks then
  begin
    if callbacks <> nil then
      callbacks := PPIntLibProgramDeleteCallback(myrealloc(callbacks, SizeOf(PIntLibProgramDeleteCallback) * (numCallbacks + 1), 'INTLIB.C', 2110))
    else
      callbacks := PPIntLibProgramDeleteCallback(mymalloc(SizeOf(PIntLibProgramDeleteCallback), 'INTLIB.C', 2112));
    Inc(numCallbacks);
  end;

  PPIntLibProgramDeleteCallback(PByte(callbacks) + SizeOf(PIntLibProgramDeleteCallback) * index)^ := callback;
end;

// -----------------------------------------------------------------------
// removeProgramReferences
// -----------------------------------------------------------------------
procedure removeProgramReferences(program_: PProgram);
var
  index: Integer;
  callback: PIntLibProgramDeleteCallback;
begin
  for index := 0 to INT_LIB_KEY_HANDLERS_CAPACITY - 1 do
  begin
    if program_ = inputProc[index].program_ then
      inputProc[index].program_ := nil;
  end;

  intExtraRemoveProgramReferences(program_);

  for index := 0 to numCallbacks - 1 do
  begin
    callback := PPIntLibProgramDeleteCallback(PByte(callbacks) + SizeOf(PIntLibProgramDeleteCallback) * index)^;
    if callback <> nil then
      callback^(program_);
  end;
end;

initialization
  FillChar(interpretSounds, SizeOf(interpretSounds), 0);
  FillChar(blackPal, SizeOf(blackPal), 0);
  FillChar(inputProc, SizeOf(inputProc), 0);
  FillChar(playmovie_name, SizeOf(playmovie_name), 0);
  FillChar(playmovierect_name, SizeOf(playmovierect_name), 0);

end.
