{$MODE OBJFPC}{$H+}
// Converted from: src/int/window.cc/h
// Managed window system: windows, buttons, regions, movies, scaled drawing.
unit u_int_window;

interface

uses
  u_rect, u_intrpret, u_region, u_svga_types, u_gnw_types;

const
  MANAGED_WINDOW_COUNT = 16;

type
  TWindowInputHandler = function(key: Integer): Boolean; cdecl;
  PWindowInputHandler = ^TWindowInputHandler;

  TWindowDeleteCallback = procedure(windowIndex: Integer; const windowName: PAnsiChar); cdecl;
  TDisplayInWindowCallback = procedure(windowIndex: Integer; const windowName: PAnsiChar; data: PByte; width, height: Integer); cdecl;
  TManagedButtonMouseEventCallback = procedure(userData: Pointer; eventType: Integer); cdecl;
  TManagedWindowCreateCallback = procedure(windowIndex: Integer; const windowName: PAnsiChar; flagsPtr: PInteger); cdecl;
  TManagedWindowSelectFunc = procedure(windowIndex: Integer; const windowName: PAnsiChar); cdecl;
  TTextInputRegionDeleteFunc = procedure(text: PAnsiChar; userData: Pointer); cdecl;

  TTextAlignment = (
    TEXT_ALIGNMENT_LEFT   = 0,
    TEXT_ALIGNMENT_RIGHT  = 1,
    TEXT_ALIGNMENT_CENTER = 2
  );

function windowGetFont: Integer;
function windowSetFont(a1: Integer): Integer;
procedure windowResetTextAttributes;
function windowGetTextFlags: Integer;
function windowSetTextFlags(a1: Integer): Integer;
function windowGetTextColor: Byte;
function windowGetHighlightColor: Byte;
function windowSetTextColor(r, g, b: Single): Integer;
function windowSetHighlightColor(r, g, b: Single): Integer;
function windowCheckRegion(windowIndex, mouseX, mouseY, mouseEvent: Integer): Boolean;
function windowRefreshRegions: Boolean;
procedure windowAddInputFunc(handler: TWindowInputHandler);
function windowActivateRegion(const regionName: PAnsiChar; a2: Integer): Boolean;
function getInput: Integer;
function windowHide: Integer;
function windowShow: Integer;
function windowDraw: Integer;
function windowDrawRect(left, top, right, bottom: Integer): Integer;
function windowDrawRectID(windowId, left, top, right, bottom: Integer): Integer;
function windowWidth: Integer;
function windowHeight: Integer;
function windowSX: Integer;
function windowSY: Integer;
function pointInWindow(x, y: Integer): Integer;
function windowGetRect(rect: PRect): Integer;
function windowGetID: Integer;
function windowGetGNWID: Integer;
function windowGetSpecificGNWID(windowIndex: Integer): Integer;
function deleteWindow(const windowName: PAnsiChar): Boolean;
function resizeWindow(const windowName: PAnsiChar; x, y, width, height: Integer): Integer;
function scaleWindow(const windowName: PAnsiChar; x, y, width, height: Integer): Integer;
function createWindow(const windowName: PAnsiChar; x, y, width, height, a6, flags: Integer): Integer;
function windowOutput(str: PAnsiChar): Integer;
function windowGotoXY(x, y: Integer): Boolean;
function selectWindowID(index: Integer): Boolean;
function selectWindow(const windowName: PAnsiChar): Integer;
function windowGetDefined(const name: PAnsiChar): Integer;
function windowGetBuffer: PByte;
function windowGetName: PAnsiChar;
function pushWindow(const windowName: PAnsiChar): Integer;
function popWindow: Integer;
procedure windowPrintBuf(win: Integer; str: PAnsiChar; stringLength, width, maxY, x, y, flags: Integer; textAlignment: Integer);
function windowWordWrap(str: PAnsiChar; maxLength, a3: Integer; substringListLengthPtr: PInteger): PPAnsiChar;
procedure windowFreeWordList(substringList: PPAnsiChar; substringListLength: Integer);
procedure windowWrapLineWithSpacing(win: Integer; str: PAnsiChar; width, height, x, y, flags: Integer; textAlignment: Integer; a9: Integer);
procedure windowWrapLine(win: Integer; str: PAnsiChar; width, height, x, y, flags: Integer; textAlignment: Integer);
function windowPrintRect(str: PAnsiChar; a2: Integer; textAlignment: Integer): Boolean;
function windowFormatMessage(str: PAnsiChar; x, y, width, height: Integer; textAlignment: Integer): Boolean;
function windowFormatMessageColor(str: PAnsiChar; x, y, width, height: Integer; textAlignment, flags: Integer): Integer;
function windowPrint(str: PAnsiChar; a2, x, y, a5: Integer): Boolean;
function windowPrintFont(str: PAnsiChar; a2, x, y, a5, font: Integer): Integer;
procedure displayInWindow(data: PByte; width, height, pitch: Integer);
procedure displayFile(fileName: PAnsiChar);
procedure displayFileRaw(fileName: PAnsiChar);
function windowDisplayRaw(fileName: PAnsiChar): Integer;
function windowDisplay(fileName: PAnsiChar; x, y, width, height: Integer): Boolean;
function windowDisplayScaled(fileName: PAnsiChar; x, y, width, height: Integer): Integer;
function windowDisplayBuf(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Boolean;
function windowDisplayTransBuf(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Integer;
function windowDisplayBufScaled(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Integer;
function windowGetXres: Integer;
function windowGetYres: Integer;
procedure initWindow(video_options: PVideoOptions; flags: Integer);
procedure windowSetWindowFuncs(createCallback: TManagedWindowCreateCallback;
  selectCallback: TManagedWindowSelectFunc;
  deleteCallback: TWindowDeleteCallback;
  displayCallback: TDisplayInWindowCallback);
procedure windowClose;
function windowDeleteButton(const buttonName: PAnsiChar): Boolean;
procedure windowEnableButton(const buttonName: PAnsiChar; enabled: Integer);
function windowGetButtonID(const buttonName: PAnsiChar): Integer;
function windowSetButtonFlag(const buttonName: PAnsiChar; value: Integer): Boolean;
procedure windowRegisterButtonSoundFunc(aSoundPressFunc, aSoundReleaseFunc, aSoundDisableFunc: TButtonCallback);
function windowAddButton(const buttonName: PAnsiChar; x, y, width, height, flags: Integer): Boolean;
function windowAddButtonGfx(const buttonName: PAnsiChar; pressedFileName, normalFileName, hoverFileName: PAnsiChar): Boolean;
function windowAddButtonMask(const buttonName: PAnsiChar; buffer: PByte): Integer;
function windowAddButtonBuf(const buttonName: PAnsiChar; normal, pressed, hover: PByte; width, height, pitch: Integer): Integer;
function windowAddButtonProc(const buttonName: PAnsiChar; program_: PProgram; mouseEnterProc, mouseExitProc, mouseDownProc, mouseUpProc: Integer): Boolean;
function windowAddButtonRightProc(const buttonName: PAnsiChar; program_: PProgram; rightMouseDownProc, rightMouseUpProc: Integer): Boolean;
function windowAddButtonCfunc(const buttonName: PAnsiChar; callback: TManagedButtonMouseEventCallback; userData: Pointer): Boolean;
function windowAddButtonRightCfunc(const buttonName: PAnsiChar; callback: TManagedButtonMouseEventCallback; userData: Pointer): Boolean;
function windowAddButtonText(const buttonName: PAnsiChar; const text: PAnsiChar): Boolean;
function windowAddButtonTextWithOffsets(const buttonName: PAnsiChar; const text: PAnsiChar; pressedImageOffsetX, pressedImageOffsetY, normalImageOffsetX, normalImageOffsetY: Integer): Boolean;
function windowFill(r, g, b: Single): Boolean;
function windowFillRect(x, y, width, height: Integer; r, g, b: Single): Boolean;
procedure windowEndRegion;
function windowRegionGetUserData(const windowRegionName: PAnsiChar): Pointer;
procedure windowRegionSetUserData(const windowRegionName: PAnsiChar; userData: Pointer);
function windowCheckRegionExists(const regionName: PAnsiChar): Boolean;
function windowStartRegion(initialCapacity: Integer): Boolean;
function windowAddRegionPoint(x, y: Integer; a3: Boolean): Boolean;
function windowAddRegionRect(a1, a2, a3, a4, a5: Integer): Integer;
function windowAddRegionCfunc(const regionName: PAnsiChar; callback: TRegionMouseEventCallback; userData: Pointer): Integer;
function windowAddRegionRightCfunc(const regionName: PAnsiChar; callback: TRegionMouseEventCallback; userData: Pointer): Integer;
function windowAddRegionProc(const regionName: PAnsiChar; program_: PProgram; a3, a4, a5, a6: Integer): Boolean;
function windowAddRegionRightProc(const regionName: PAnsiChar; program_: PProgram; a3, a4: Integer): Boolean;
function windowSetRegionFlag(const regionName: PAnsiChar; value: Integer): Boolean;
function windowAddRegionName(const regionName: PAnsiChar): Boolean;
function windowDeleteRegion(const regionName: PAnsiChar): Boolean;
procedure updateWindows;
function windowMoviePlaying: Integer;
function windowSetMovieFlags(flags: Integer): Boolean;
function windowPlayMovie(filePath: PAnsiChar): Boolean;
function windowPlayMovieRect(filePath: PAnsiChar; a2, a3, a4, a5: Integer): Boolean;
procedure windowStopMovie;
procedure drawScaled(dest: PByte; destWidth, destHeight, destPitch: Integer; src: PByte; srcWidth, srcHeight, srcPitch: Integer);
procedure drawScaledBuf(dest: PByte; destWidth, destHeight: Integer; src: PByte; srcWidth, srcHeight: Integer);
procedure alphaBltBuf(src: PByte; srcWidth, srcHeight, srcPitch: Integer; alphaWindowBuffer, alphaBuffer, dest: PByte; destPitch: Integer);
procedure fillBuf3x3(src: PByte; srcWidth, srcHeight: Integer; dest: PByte; destWidth, destHeight: Integer);
function windowEnableCheckRegion: Integer;
function windowDisableCheckRegion: Integer;
function windowSetHoldTime(value: Integer): Integer;
function windowAddTextRegion(x, y, width, font: Integer; textAlignment, textFlags, backgroundColor: Integer): Integer;
function windowPrintTextRegion(textRegionId: Integer; str: PAnsiChar): Integer;
function windowUpdateTextRegion(textRegionId: Integer): Integer;
function windowDeleteTextRegion(textRegionId: Integer): Integer;
function windowTextRegionStyle(textRegionId, font: Integer; textAlignment, textFlags, backgroundColor: Integer): Integer;
function windowAddTextInputRegion(textRegionId: Integer; text: PAnsiChar; a3, a4: Integer): Integer;
function windowDeleteTextInputRegion(textInputRegionId: Integer): Integer;
function windowSetTextInputDeleteFunc(textInputRegionId: Integer; deleteFunc: TTextInputRegionDeleteFunc; userData: Pointer): Integer;

implementation

uses
  SysUtils,
  u_memdbg,
  u_datafile,
  u_platform_compat,
  u_color,
  u_gnw,
  u_text,
  u_input,
  u_button,
  u_grbuf,
  u_mouse,
  u_db,
  u_kb,
  u_debug,
  u_game,
  u_mousemgr,
  u_int_movie,
  u_widget;

{ ---- Internal types ---- }

const
  MANAGED_BUTTON_MOUSE_EVENT_BUTTON_DOWN = 0;
  MANAGED_BUTTON_MOUSE_EVENT_BUTTON_UP   = 1;
  MANAGED_BUTTON_MOUSE_EVENT_ENTER       = 2;
  MANAGED_BUTTON_MOUSE_EVENT_EXIT        = 3;
  MANAGED_BUTTON_MOUSE_EVENT_COUNT       = 4;

  MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_DOWN = 0;
  MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_UP   = 1;
  MANAGED_BUTTON_RIGHT_MOUSE_EVENT_COUNT       = 2;

type
  PManagedButton = ^TManagedButton;
  TManagedButton = record
    btn: Integer;
    width: Integer;
    height: Integer;
    x: Integer;
    y: Integer;
    flags: Integer;
    field_18: Integer;
    name: array[0..31] of AnsiChar;
    program_: PProgram;
    pressed: PByte;
    normal: PByte;
    hover: PByte;
    field_4C: Pointer;
    field_50: Pointer;
    procs: array[0..MANAGED_BUTTON_MOUSE_EVENT_COUNT - 1] of Integer;
    rightProcs: array[0..MANAGED_BUTTON_RIGHT_MOUSE_EVENT_COUNT - 1] of Integer;
    mouseEventCallback: TManagedButtonMouseEventCallback;
    rightMouseEventCallback: TManagedButtonMouseEventCallback;
    mouseEventCallbackUserData: Pointer;
    rightMouseEventCallbackUserData: Pointer;
  end;

  PManagedWindow = ^TManagedWindow;
  TManagedWindow = record
    name: array[0..31] of AnsiChar;
    window: Integer;
    width: Integer;
    height: Integer;
    regions: ^PRegion;
    currentRegionIndex: Integer;
    regionsLength: Integer;
    field_38: Integer;
    buttons: PManagedButton;
    buttonsLength: Integer;
    field_44: Integer;
    field_48: Integer;
    field_4C: Integer;
    field_50: Integer;
    field_54: Single;
    field_58: Single;
  end;

{ ---- Forward declarations ---- }

function checkRegion(windowIndex, mouseX, mouseY, mouseEvent: Integer): Boolean; forward;
function checkAllRegions: Boolean; forward;
procedure doRegionRightFunc(region: PRegion; a2: Integer); forward;
procedure doRegionFunc(region: PRegion; a2: Integer); forward;
procedure doButtonOn(btn, keyCode: Integer); cdecl; forward;
procedure doButtonProc(btn, mouseEvent: Integer); forward;
procedure doButtonOff(btn, keyCode: Integer); cdecl; forward;
procedure doButtonPress(btn, keyCode: Integer); cdecl; forward;
procedure doButtonRelease(btn, keyCode: Integer); cdecl; forward;
procedure doRightButtonPress(btn, keyCode: Integer); cdecl; forward;
procedure doRightButtonProc(btn, mouseEvent: Integer); forward;
procedure doRightButtonRelease(btn, keyCode: Integer); cdecl; forward;
procedure setButtonGFX(width, height: Integer; normal, pressed, a5: PByte); forward;
procedure redrawButton(button: PManagedButton); forward;
procedure windowRemoveProgramReferences(program_: PProgram); forward;

{ ---- Module-level variables ---- }

var
  holdTime: Integer = 250;
  checkRegionEnable_: Integer = 1;
  winTOS: Integer = -1;
  currentWindow: Integer = -1;
  numInputFunc: Integer = 0;

  winStack: array[0..MANAGED_WINDOW_COUNT - 1] of Integer;
  alphaBlendTable: array[0..64 * 256 - 1] of AnsiChar;
  windows: array[0..MANAGED_WINDOW_COUNT - 1] of TManagedWindow;

  inputFunc: ^TWindowInputHandler = nil;

  currentHighlightColorR: Integer = 0;
  createWindowFunc: TManagedWindowCreateCallback = nil;
  currentFont_: Integer = 0;
  selectWindowFunc: TManagedWindowSelectFunc = nil;
  xres: Integer = 0;
  soundDisableFunc_: TButtonCallback = nil;
  displayFunc: TDisplayInWindowCallback = nil;
  deleteWindowFunc: TWindowDeleteCallback = nil;
  soundPressFunc_: TButtonCallback = nil;
  soundReleaseFunc_: TButtonCallback = nil;
  currentTextColorG: Integer = 0;
  yres: Integer = 0;
  currentTextColorB: Integer = 0;
  currentTextFlags_: Integer = 0;
  currentTextColorR: Integer = 0;
  currentHighlightColorG: Integer = 0;
  currentHighlightColorB: Integer = 0;

  // static locals from checkAllRegions
  lastWin: Integer = -1;
  // static locals from getInput
  said_quit: Integer = 1;

{ ---- Helper to get region pointer by index from the regions array ---- }

{$PUSH}{$R-}
function GetRegionPtr(mw: PManagedWindow; idx: Integer): PRegion; inline;
type
  PRegionArray = ^TRegionArray;
  TRegionArray = array[0..0] of PRegion;
begin
  Result := PRegionArray(mw^.regions)^[idx];
end;

procedure SetRegionPtr(mw: PManagedWindow; idx: Integer; rgn: PRegion); inline;
type
  PRegionArray = ^TRegionArray;
  TRegionArray = array[0..0] of PRegion;
begin
  PRegionArray(mw^.regions)^[idx] := rgn;
end;
{$POP}

{ ---- Helper to get button pointer by index from the buttons array ---- }

function GetButtonPtr(mw: PManagedWindow; idx: Integer): PManagedButton; inline;
begin
  Result := PManagedButton(PByte(mw^.buttons) + SizeOf(TManagedButton) * idx);
end;

{ ---- Helper to get input handler by index from the inputFunc array ---- }

type
  PWindowInputHandlerArray = ^TWindowInputHandlerArray;
  TWindowInputHandlerArray = array[0..0] of TWindowInputHandler;

{$PUSH}{$R-}
function GetInputHandler(idx: Integer): TWindowInputHandler; inline;
begin
  Result := PWindowInputHandlerArray(inputFunc)^[idx];
end;

procedure SetInputHandler(idx: Integer; handler: TWindowInputHandler); inline;
begin
  PWindowInputHandlerArray(inputFunc)^[idx] := handler;
end;
{$POP}

{ ---- Implementation ---- }

function windowGetFont: Integer;
begin
  Result := currentFont_;
end;

function windowSetFont(a1: Integer): Integer;
begin
  currentFont_ := a1;
  text_font(a1);
  Result := 1;
end;

procedure windowResetTextAttributes;
begin
  windowSetTextColor(1.0, 1.0, 1.0);
  windowSetTextFlags($2000000 or $10000);
end;

function windowGetTextFlags: Integer;
begin
  Result := currentTextFlags_;
end;

function windowSetTextFlags(a1: Integer): Integer;
begin
  currentTextFlags_ := a1;
  Result := 1;
end;

function windowGetTextColor: Byte;
begin
  Result := colorTable[currentTextColorB or (currentTextColorG shl 5) or (currentTextColorR shl 10)];
end;

function windowGetHighlightColor: Byte;
begin
  Result := colorTable[currentHighlightColorB or (currentHighlightColorG shl 5) or (currentHighlightColorR shl 10)];
end;

function windowSetTextColor(r, g, b: Single): Integer;
begin
  currentTextColorR := Trunc(r * 31.0);
  currentTextColorG := Trunc(g * 31.0);
  currentTextColorB := Trunc(b * 31.0);
  Result := 1;
end;

function windowSetHighlightColor(r, g, b: Single): Integer;
begin
  currentHighlightColorR := Trunc(r * 31.0);
  currentHighlightColorG := Trunc(g * 31.0);
  currentHighlightColorB := Trunc(b * 31.0);
  Result := 1;
end;

function checkRegion(windowIndex, mouseX, mouseY, mouseEvent: Integer): Boolean;
begin
  // TODO: Incomplete.
  Result := False;
end;

function windowCheckRegion(windowIndex, mouseX, mouseY, mouseEvent: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  v1: Integer;
  index: Integer;
  region: PRegion;
  rc: Boolean;
begin
  rc := checkRegion(windowIndex, mouseX, mouseY, mouseEvent);

  managedWindow := @windows[windowIndex];
  v1 := managedWindow^.field_38;

  for index := 0 to managedWindow^.regionsLength - 1 do
  begin
    region := GetRegionPtr(managedWindow, index);
    if region <> nil then
    begin
      if region^.field_6C <> 0 then
      begin
        region^.field_6C := 0;
        rc := True;

        if Assigned(region^.mouseEventCallback) then
        begin
          region^.mouseEventCallback(region, region^.mouseEventCallbackUserData, 2);
          if v1 <> managedWindow^.field_38 then
          begin
            Result := True;
            Exit;
          end;
        end;

        if Assigned(region^.rightMouseEventCallback) then
        begin
          region^.rightMouseEventCallback(region, region^.rightMouseEventCallbackUserData, 2);
          if v1 <> managedWindow^.field_38 then
          begin
            Result := True;
            Exit;
          end;
        end;

        if (region^.program_ <> nil) and (region^.procs[2] <> 0) then
        begin
          executeProc(region^.program_, region^.procs[2]);
          if v1 <> managedWindow^.field_38 then
          begin
            Result := True;
            Exit;
          end;
        end;
      end;
    end;
  end;

  Result := rc;
end;

function windowRefreshRegions: Boolean;
var
  mouseX, mouseY: Integer;
  win: Integer;
  windowIndex, regionIndex: Integer;
  managedWindow: PManagedWindow;
  region: PRegion;
  mouseEvent: Integer;
begin
  mouse_get_position(@mouseX, @mouseY);

  win := win_get_top_win(mouseX, mouseY);

  for windowIndex := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[windowIndex];
    if managedWindow^.window = win then
    begin
      for regionIndex := 0 to managedWindow^.regionsLength - 1 do
      begin
        region := GetRegionPtr(managedWindow, regionIndex);
        region^.rightProcs[3] := 0;
      end;

      mouseEvent := mouse_get_buttons;
      Result := windowCheckRegion(windowIndex, mouseX, mouseY, mouseEvent);
      Exit;
    end;
  end;

  Result := False;
end;

function checkAllRegions: Boolean;
var
  mouseX, mouseY: Integer;
  mouseEvent: Integer;
  win: Integer;
  windowIndex, regionIndex: Integer;
  managedWindow: PManagedWindow;
  region: PRegion;
  v1: Integer;
begin
  if checkRegionEnable_ = 0 then
  begin
    Result := False;
    Exit;
  end;

  mouse_get_position(@mouseX, @mouseY);
  mouseEvent := mouse_get_buttons;
  win := win_get_top_win(mouseX, mouseY);

  for windowIndex := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[windowIndex];
    if (managedWindow^.window <> -1) and (managedWindow^.window = win) then
    begin
      if (lastWin <> -1) and (lastWin <> windowIndex) and (windows[lastWin].window <> -1) then
      begin
        managedWindow := @windows[lastWin];
        v1 := managedWindow^.field_38;

        for regionIndex := 0 to managedWindow^.regionsLength - 1 do
        begin
          region := GetRegionPtr(managedWindow, regionIndex);
          if (region <> nil) and (region^.rightProcs[3] <> 0) then
          begin
            region^.rightProcs[3] := 0;
            if Assigned(region^.mouseEventCallback) then
            begin
              region^.mouseEventCallback(region, region^.mouseEventCallbackUserData, 3);
              if v1 <> managedWindow^.field_38 then
              begin
                Result := True;
                Exit;
              end;
            end;

            if Assigned(region^.rightMouseEventCallback) then
            begin
              region^.rightMouseEventCallback(region, region^.rightMouseEventCallbackUserData, 3);
              if v1 <> managedWindow^.field_38 then
              begin
                Result := True;
                Exit;
              end;
            end;

            if (region^.program_ <> nil) and (region^.procs[3] <> 0) then
            begin
              executeProc(region^.program_, region^.procs[3]);
              if v1 <> managedWindow^.field_38 then
              begin
                Result := True;
                Exit;
              end;
            end;
          end;
        end;
        lastWin := -1;
      end
      else
      begin
        lastWin := windowIndex;
      end;

      Result := windowCheckRegion(windowIndex, mouseX, mouseY, mouseEvent);
      Exit;
    end;
  end;

  Result := False;
end;

procedure windowAddInputFunc(handler: TWindowInputHandler);
var
  index: Integer;
begin
  index := 0;
  while index < numInputFunc do
  begin
    if not Assigned(GetInputHandler(index)) then
      Break;
    Inc(index);
  end;

  if index = numInputFunc then
  begin
    if inputFunc <> nil then
      inputFunc := myrealloc(inputFunc, SizeOf(TWindowInputHandler) * (numInputFunc + 1), '..\int\WINDOW.C', 521)
    else
      inputFunc := mymalloc(SizeOf(TWindowInputHandler), '..\int\WINDOW.C', 523);
  end;

  SetInputHandler(numInputFunc, handler);
  Inc(numInputFunc);
end;

procedure doRegionRightFunc(region: PRegion; a2: Integer);
var
  v1: Integer;
begin
  v1 := windows[currentWindow].field_38;
  if Assigned(region^.rightMouseEventCallback) then
  begin
    region^.rightMouseEventCallback(region, region^.rightMouseEventCallbackUserData, a2);
    if v1 <> windows[currentWindow].field_38 then
      Exit;
  end;

  if a2 < 4 then
  begin
    if (region^.program_ <> nil) and (region^.rightProcs[a2] <> 0) then
      executeProc(region^.program_, region^.rightProcs[a2]);
  end;
end;

procedure doRegionFunc(region: PRegion; a2: Integer);
var
  v1: Integer;
begin
  v1 := windows[currentWindow].field_38;
  if Assigned(region^.mouseEventCallback) then
  begin
    region^.mouseEventCallback(region, region^.mouseEventCallbackUserData, a2);
    if v1 <> windows[currentWindow].field_38 then
      Exit;
  end;

  if a2 < 4 then
  begin
    if (region^.program_ <> nil) and (region^.rightProcs[a2] <> 0) then
      executeProc(region^.program_, region^.rightProcs[a2]);
  end;
end;

function windowActivateRegion(const regionName: PAnsiChar; a2: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];

  if a2 <= 4 then
  begin
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, index);
      if compat_stricmp(regionGetName(region), regionName) = 0 then
      begin
        doRegionFunc(region, a2);
        Result := True;
        Exit;
      end;
    end;
  end
  else
  begin
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, index);
      if compat_stricmp(regionGetName(region), regionName) = 0 then
      begin
        doRegionRightFunc(region, a2 - 5);
        Result := True;
        Exit;
      end;
    end;
  end;

  Result := False;
end;

function getInput: Integer;
var
  keyCode: Integer;
  index: Integer;
  handler: TWindowInputHandler;
begin
  keyCode := get_input;
  if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
    game_quit_with_confirm;

  if game_user_wants_to_quit <> 0 then
  begin
    said_quit := 1 - said_quit;
    if said_quit <> 0 then
    begin
      Result := -1;
      Exit;
    end;

    Result := KEY_ESCAPE;
    Exit;
  end;

  for index := 0 to numInputFunc - 1 do
  begin
    handler := GetInputHandler(index);
    if Assigned(handler) then
    begin
      if handler(keyCode) then
      begin
        Result := -1;
        Exit;
      end;
    end;
  end;

  Result := keyCode;
end;

procedure doButtonOn(btn, keyCode: Integer); cdecl;
begin
  doButtonProc(btn, MANAGED_BUTTON_MOUSE_EVENT_ENTER);
end;

procedure doButtonProc(btn, mouseEvent: Integer);
var
  win: Integer;
  windowIndex, buttonIndex: Integer;
  managedWindow: PManagedWindow;
  managedButton: PManagedButton;
begin
  win := win_last_button_winID;
  if win = -1 then
    Exit;

  for windowIndex := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[windowIndex];
    if managedWindow^.window = win then
    begin
      for buttonIndex := 0 to managedWindow^.buttonsLength - 1 do
      begin
        managedButton := GetButtonPtr(managedWindow, buttonIndex);
        if managedButton^.btn = btn then
        begin
          if (managedButton^.flags and $02) <> 0 then
          begin
            win_set_button_rest_state(managedButton^.btn, False, 0);
          end
          else
          begin
            if (managedButton^.program_ <> nil) and (managedButton^.procs[mouseEvent] <> 0) then
              executeProc(managedButton^.program_, managedButton^.procs[mouseEvent]);

            if Assigned(managedButton^.mouseEventCallback) then
              managedButton^.mouseEventCallback(managedButton^.mouseEventCallbackUserData, mouseEvent);
          end;
        end;
      end;
    end;
  end;
end;

procedure doButtonOff(btn, keyCode: Integer); cdecl;
begin
  doButtonProc(btn, MANAGED_BUTTON_MOUSE_EVENT_EXIT);
end;

procedure doButtonPress(btn, keyCode: Integer); cdecl;
begin
  doButtonProc(btn, MANAGED_BUTTON_MOUSE_EVENT_BUTTON_DOWN);
end;

procedure doButtonRelease(btn, keyCode: Integer); cdecl;
begin
  doButtonProc(btn, MANAGED_BUTTON_MOUSE_EVENT_BUTTON_UP);
end;

procedure doRightButtonPress(btn, keyCode: Integer); cdecl;
begin
  doRightButtonProc(btn, MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_DOWN);
end;

procedure doRightButtonProc(btn, mouseEvent: Integer);
var
  win: Integer;
  windowIndex, buttonIndex: Integer;
  managedWindow: PManagedWindow;
  managedButton: PManagedButton;
begin
  win := win_last_button_winID;
  if win = -1 then
    Exit;

  for windowIndex := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[windowIndex];
    if managedWindow^.window = win then
    begin
      for buttonIndex := 0 to managedWindow^.buttonsLength - 1 do
      begin
        managedButton := GetButtonPtr(managedWindow, buttonIndex);
        if managedButton^.btn = btn then
        begin
          if (managedButton^.flags and $02) <> 0 then
          begin
            win_set_button_rest_state(managedButton^.btn, False, 0);
          end
          else
          begin
            if (managedButton^.program_ <> nil) and (managedButton^.rightProcs[mouseEvent] <> 0) then
              executeProc(managedButton^.program_, managedButton^.rightProcs[mouseEvent]);

            if Assigned(managedButton^.rightMouseEventCallback) then
              managedButton^.rightMouseEventCallback(managedButton^.rightMouseEventCallbackUserData, mouseEvent);
          end;
        end;
      end;
    end;
  end;
end;

procedure doRightButtonRelease(btn, keyCode: Integer); cdecl;
begin
  doRightButtonProc(btn, MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_UP);
end;

procedure setButtonGFX(width, height: Integer; normal, pressed, a5: PByte);
begin
  if normal <> nil then
  begin
    buf_fill(normal, width, height, width, colorTable[0]);
    buf_fill(normal + width + 1, width - 2, height - 2, width, intensityColorTable[colorTable[32767]][89]);
    draw_line(normal, width, 1, 1, width - 2, 1, colorTable[32767]);
    draw_line(normal, width, 2, 2, width - 3, 2, colorTable[32767]);
    draw_line(normal, width, 1, height - 2, width - 2, height - 2, intensityColorTable[colorTable[32767]][44]);
    draw_line(normal, width, 2, height - 3, width - 3, height - 3, intensityColorTable[colorTable[32767]][44]);
    draw_line(normal, width, width - 2, 1, width - 3, 2, intensityColorTable[colorTable[32767]][89]);
    draw_line(normal, width, 1, 2, 1, height - 3, colorTable[32767]);
    draw_line(normal, width, 2, 3, 2, height - 4, colorTable[32767]);
    draw_line(normal, width, width - 2, 2, width - 2, height - 3, intensityColorTable[colorTable[32767]][44]);
    draw_line(normal, width, width - 3, 3, width - 3, height - 4, intensityColorTable[colorTable[32767]][44]);
    draw_line(normal, width, 1, height - 2, 2, height - 3, intensityColorTable[colorTable[32767]][89]);
  end;

  if pressed <> nil then
  begin
    buf_fill(pressed, width, height, width, colorTable[0]);
    buf_fill(pressed + width + 1, width - 2, height - 2, width, intensityColorTable[colorTable[32767]][89]);
    draw_line(pressed, width, 1, 1, width - 2, 1, colorTable[32767] + 44);
    draw_line(pressed, width, 1, 1, 1, height - 2, colorTable[32767] + 44);
  end;

  if a5 <> nil then
  begin
    buf_fill(a5, width, height, width, colorTable[0]);
    buf_fill(a5 + width + 1, width - 2, height - 2, width, intensityColorTable[colorTable[32767]][89]);
    draw_line(a5, width, 1, 1, width - 2, 1, colorTable[32767]);
    draw_line(a5, width, 2, 2, width - 3, 2, colorTable[32767]);
    draw_line(a5, width, 1, height - 2, width - 2, height - 2, intensityColorTable[colorTable[32767]][44]);
    draw_line(a5, width, 2, height - 3, width - 3, height - 3, intensityColorTable[colorTable[32767]][44]);
    draw_line(a5, width, width - 2, 1, width - 3, 2, intensityColorTable[colorTable[32767]][89]);
    draw_line(a5, width, 1, 2, 1, height - 3, colorTable[32767]);
    draw_line(a5, width, 2, 3, 2, height - 4, colorTable[32767]);
    draw_line(a5, width, width - 2, 2, width - 2, height - 3, intensityColorTable[colorTable[32767]][44]);
    draw_line(a5, width, width - 3, 3, width - 3, height - 4, intensityColorTable[colorTable[32767]][44]);
    draw_line(a5, width, 1, height - 2, 2, height - 3, intensityColorTable[colorTable[32767]][89]);
  end;
end;

procedure redrawButton(button: PManagedButton);
begin
  win_register_button_image(button^.btn, button^.normal, button^.pressed, button^.hover, False);
end;

function windowHide: Integer;
begin
  if windows[currentWindow].window = -1 then
  begin
    Result := 0;
    Exit;
  end;

  win_hide(windows[currentWindow].window);
  Result := 1;
end;

function windowShow: Integer;
begin
  if windows[currentWindow].window = -1 then
  begin
    Result := 0;
    Exit;
  end;

  win_show(windows[currentWindow].window);
  Result := 1;
end;

function windowDraw: Integer;
var
  managedWindow: PManagedWindow;
begin
  managedWindow := @windows[currentWindow];
  if managedWindow^.window = -1 then
  begin
    Result := 0;
    Exit;
  end;

  win_draw(managedWindow^.window);
  Result := 1;
end;

function windowDrawRect(left, top, right, bottom: Integer): Integer;
var
  rect: TRect;
begin
  rect.ulx := left;
  rect.uly := top;
  rect.lrx := right;
  rect.lry := bottom;
  win_draw_rect(windows[currentWindow].window, @rect);
  Result := 1;
end;

function windowDrawRectID(windowId, left, top, right, bottom: Integer): Integer;
var
  rect: TRect;
begin
  rect.ulx := left;
  rect.uly := top;
  rect.lrx := right;
  rect.lry := bottom;
  win_draw_rect(windows[windowId].window, @rect);
  Result := 1;
end;

function windowWidth: Integer;
begin
  Result := windows[currentWindow].width;
end;

function windowHeight: Integer;
begin
  Result := windows[currentWindow].height;
end;

function windowSX: Integer;
var
  rect: TRect;
begin
  win_get_rect(windows[currentWindow].window, @rect);
  Result := rect.ulx;
end;

function windowSY: Integer;
var
  rect: TRect;
begin
  win_get_rect(windows[currentWindow].window, @rect);
  Result := rect.uly;
end;

function pointInWindow(x, y: Integer): Integer;
var
  rect: TRect;
begin
  win_get_rect(windows[currentWindow].window, @rect);
  if (x >= rect.ulx) and (x <= rect.lrx) and (y >= rect.uly) and (y <= rect.lry) then
    Result := 1
  else
    Result := 0;
end;

function windowGetRect(rect: PRect): Integer;
begin
  Result := win_get_rect(windows[currentWindow].window, rect);
end;

function windowGetID: Integer;
begin
  Result := currentWindow;
end;

function windowGetGNWID: Integer;
begin
  Result := windows[currentWindow].window;
end;

function windowGetSpecificGNWID(windowIndex: Integer): Integer;
begin
  if (windowIndex >= 0) and (windowIndex < MANAGED_WINDOW_COUNT) then
    Result := windows[windowIndex].window
  else
    Result := -1;
end;

function deleteWindow(const windowName: PAnsiChar): Boolean;
var
  index, btnIndex: Integer;
  managedWindow: PManagedWindow;
  button: PManagedButton;
  region: PRegion;
begin
  index := 0;
  while index < MANAGED_WINDOW_COUNT do
  begin
    managedWindow := @windows[index];
    if compat_stricmp(managedWindow^.name, windowName) = 0 then
      Break;
    Inc(index);
  end;

  if index = MANAGED_WINDOW_COUNT then
  begin
    Result := False;
    Exit;
  end;

  if Assigned(deleteWindowFunc) then
    deleteWindowFunc(index, windowName);

  managedWindow := @windows[index];
  win_delete_widgets(managedWindow^.window);
  win_delete(managedWindow^.window);
  managedWindow^.window := -1;
  managedWindow^.name[0] := #0;

  if managedWindow^.buttons <> nil then
  begin
    for btnIndex := 0 to managedWindow^.buttonsLength - 1 do
    begin
      button := GetButtonPtr(managedWindow, btnIndex);
      if button^.hover <> nil then
        myfree(button^.hover, '..\int\WINDOW.C', 802);
      if button^.field_4C <> nil then
        myfree(button^.field_4C, '..\int\WINDOW.C', 804);
      if button^.pressed <> nil then
        myfree(button^.pressed, '..\int\WINDOW.C', 806);
      if button^.normal <> nil then
        myfree(button^.normal, '..\int\WINDOW.C', 808);
    end;

    myfree(managedWindow^.buttons, '..\int\WINDOW.C', 810);
  end;

  if managedWindow^.regions <> nil then
  begin
    for btnIndex := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, btnIndex);
      if region <> nil then
        regionDelete(region);
    end;

    myfree(managedWindow^.regions, '..\int\WINDOW.C', 818);
    managedWindow^.regions := nil;
  end;

  Result := True;
end;

function resizeWindow(const windowName: PAnsiChar; x, y, width, height: Integer): Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function scaleWindow(const windowName: PAnsiChar; x, y, width, height: Integer): Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

function createWindow(const windowName: PAnsiChar; x, y, width, height, a6, flags: Integer): Integer;
var
  windowIndex, index: Integer;
  managedWindow: PManagedWindow;
  localFlags: Integer;
begin
  windowIndex := -1;
  localFlags := flags;

  for index := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[index];
    if managedWindow^.window = -1 then
    begin
      windowIndex := index;
      Break;
    end
    else
    begin
      if compat_stricmp(managedWindow^.name, windowName) = 0 then
      begin
        deleteWindow(windowName);
        windowIndex := index;
        Break;
      end;
    end;
  end;

  if windowIndex = -1 then
  begin
    Result := -1;
    Exit;
  end;

  managedWindow := @windows[windowIndex];
  StrLCopy(managedWindow^.name, windowName, 31);
  managedWindow^.name[31] := #0;
  managedWindow^.field_54 := 1.0;
  managedWindow^.field_58 := 1.0;
  managedWindow^.field_38 := 0;
  managedWindow^.regions := nil;
  managedWindow^.regionsLength := 0;
  managedWindow^.width := width;
  managedWindow^.height := height;
  managedWindow^.buttons := nil;
  managedWindow^.buttonsLength := 0;

  localFlags := localFlags or $101;
  if Assigned(createWindowFunc) then
    createWindowFunc(windowIndex, managedWindow^.name, @localFlags);

  managedWindow^.window := win_add(x, y, width, height, a6, localFlags);
  managedWindow^.field_48 := 0;
  managedWindow^.field_44 := 0;
  managedWindow^.field_4C := a6;
  managedWindow^.field_50 := localFlags;

  Result := windowIndex;
end;

function windowOutput(str: PAnsiChar): Integer;
var
  managedWindow: PManagedWindow;
  x, y: Integer;
  flags: Integer;
begin
  if currentWindow = -1 then
  begin
    Result := 0;
    Exit;
  end;

  managedWindow := @windows[currentWindow];

  x := Trunc(managedWindow^.field_44 * managedWindow^.field_54);
  y := Trunc(managedWindow^.field_48 * managedWindow^.field_58);
  // NOTE: Uses `add` not bitwise `or`.
  flags := windowGetTextColor + windowGetTextFlags;
  win_print(managedWindow^.window, str, 0, x, y, flags);

  Result := 1;
end;

function windowGotoXY(x, y: Integer): Boolean;
var
  managedWindow: PManagedWindow;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  managedWindow^.field_44 := Trunc(x * managedWindow^.field_54);
  managedWindow^.field_48 := Trunc(y * managedWindow^.field_58);

  Result := True;
end;

function selectWindowID(index: Integer): Boolean;
var
  managedWindow: PManagedWindow;
begin
  if (index < 0) or (index >= MANAGED_WINDOW_COUNT) then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[index];
  if managedWindow^.window = -1 then
  begin
    Result := False;
    Exit;
  end;

  currentWindow := index;

  if Assigned(selectWindowFunc) then
    selectWindowFunc(index, managedWindow^.name);

  Result := True;
end;

function selectWindow(const windowName: PAnsiChar): Integer;
var
  index: Integer;
  managedWindow: PManagedWindow;
begin
  if currentWindow <> -1 then
  begin
    managedWindow := @windows[currentWindow];
    if compat_stricmp(managedWindow^.name, windowName) = 0 then
    begin
      Result := currentWindow;
      Exit;
    end;
  end;

  index := 0;
  while index < MANAGED_WINDOW_COUNT do
  begin
    managedWindow := @windows[index];
    if managedWindow^.window <> -1 then
    begin
      if compat_stricmp(managedWindow^.name, windowName) = 0 then
        Break;
    end;
    Inc(index);
  end;

  if selectWindowID(index) then
    Result := index
  else
    Result := -1;
end;

function windowGetDefined(const name: PAnsiChar): Integer;
var
  index: Integer;
begin
  for index := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    if (windows[index].window <> -1) and (compat_stricmp(windows[index].name, name) = 0) then
    begin
      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

function windowGetBuffer: PByte;
var
  managedWindow: PManagedWindow;
begin
  if currentWindow <> -1 then
  begin
    managedWindow := @windows[currentWindow];
    Result := win_get_buf(managedWindow^.window);
  end
  else
    Result := nil;
end;

function windowGetName: PAnsiChar;
begin
  if currentWindow <> -1 then
    Result := @windows[currentWindow].name[0]
  else
    Result := nil;
end;

function pushWindow(const windowName: PAnsiChar): Integer;
var
  oldCurrentWindowIndex: Integer;
  windowIndex: Integer;
  index: Integer;
begin
  if winTOS >= MANAGED_WINDOW_COUNT then
  begin
    Result := -1;
    Exit;
  end;

  oldCurrentWindowIndex := currentWindow;

  windowIndex := selectWindow(windowName);
  if windowIndex = -1 then
  begin
    Result := -1;
    Exit;
  end;

  // TODO: Check.
  for index := 0 to winTOS - 1 do
  begin
    if winStack[index] = oldCurrentWindowIndex then
    begin
      Move(winStack[index + 1], winStack[index], SizeOf(Integer) * (winTOS - index));
      Break;
    end;
  end;

  Inc(winTOS);
  winStack[winTOS] := oldCurrentWindowIndex;

  Result := windowIndex;
end;

function popWindow: Integer;
var
  windowIndex: Integer;
  managedWindow: PManagedWindow;
begin
  if winTOS = -1 then
  begin
    Result := -1;
    Exit;
  end;

  windowIndex := winStack[winTOS];
  managedWindow := @windows[windowIndex];
  Dec(winTOS);

  Result := selectWindow(managedWindow^.name);
end;

procedure windowPrintBuf(win: Integer; str: PAnsiChar; stringLength, width, maxY, x, y, flags: Integer; textAlignment: Integer);
var
  stringCopy: PAnsiChar;
  stringWidth, stringHeight: Integer;
  backgroundBuffer, backgroundBufferPtr: PByte;
begin
  if y + text_height() > maxY then
    Exit;

  if stringLength > 255 then
    stringLength := 255;

  stringCopy := PAnsiChar(mymalloc(stringLength + 1, '..\int\WINDOW.C', 1078));
  StrLCopy(stringCopy, str, stringLength);
  stringCopy[stringLength] := #0;

  stringWidth := text_width(stringCopy);
  stringHeight := text_height();
  if (stringWidth = 0) or (stringHeight = 0) then
  begin
    myfree(stringCopy, '..\int\WINDOW.C', 1085);
    Exit;
  end;

  if (flags and FONT_SHADOW) <> 0 then
  begin
    Inc(stringWidth);
    Inc(stringHeight);
  end;

  backgroundBuffer := PByte(mycalloc(stringWidth, stringHeight, '..\int\WINDOW.C', 1093));
  backgroundBufferPtr := backgroundBuffer;
  text_to_buf(backgroundBuffer, stringCopy, stringWidth, stringWidth, flags);

  case TTextAlignment(textAlignment) of
    TEXT_ALIGNMENT_LEFT:
    begin
      if stringWidth < width then
        width := stringWidth;
    end;
    TEXT_ALIGNMENT_RIGHT:
    begin
      if stringWidth <= width then
      begin
        x := x + (width - stringWidth);
        width := stringWidth;
      end
      else
        backgroundBufferPtr := backgroundBuffer + stringWidth - width;
    end;
    TEXT_ALIGNMENT_CENTER:
    begin
      if stringWidth <= width then
      begin
        x := x + (width - stringWidth) div 2;
        width := stringWidth;
      end
      else
        backgroundBufferPtr := backgroundBuffer + (stringWidth - width) div 2;
    end;
  end;

  if stringHeight + y > win_height(win) then
    stringHeight := win_height(win) - y;

  if (flags and $2000000) <> 0 then
    trans_buf_to_buf(backgroundBufferPtr, width, stringHeight, stringWidth, win_get_buf(win) + win_width(win) * y + x, win_width(win))
  else
    buf_to_buf(backgroundBufferPtr, width, stringHeight, stringWidth, win_get_buf(win) + win_width(win) * y + x, win_width(win));

  myfree(backgroundBuffer, '..\int\WINDOW.C', 1130);
  myfree(stringCopy, '..\int\WINDOW.C', 1131);
end;

function windowWordWrap(str: PAnsiChar; maxLength, a3: Integer; substringListLengthPtr: PInteger): PPAnsiChar;
var
  substringList: PPAnsiChar;
  substringListLength: Integer;
  start, pch: PAnsiChar;
  v1: Integer;
  substring: PAnsiChar;
  subLen: PtrUInt;
begin
  if str = nil then
  begin
    substringListLengthPtr^ := 0;
    Result := nil;
    Exit;
  end;

  substringList := nil;
  substringListLength := 0;

  start := str;
  pch := str;
  v1 := a3;
  while pch^ <> #0 do
  begin
    v1 := v1 + text_char_width(AnsiChar(Ord(pch^) and $FF));
    if (pch^ <> #10) and (v1 <= maxLength) then
    begin
      v1 := v1 + text_spacing();
      Inc(pch);
    end
    else
    begin
      while v1 > maxLength do
      begin
        v1 := v1 - text_char_width(pch^);
        Dec(pch);
      end;

      if pch^ <> #10 then
      begin
        while (pch <> start) and (pch^ <> ' ') do
          Dec(pch);
      end;

      if substringList <> nil then
        substringList := PPAnsiChar(myrealloc(substringList, SizeOf(PAnsiChar) * (substringListLength + 1), '..\int\WINDOW.C', 1166))
      else
        substringList := PPAnsiChar(mymalloc(SizeOf(PAnsiChar), '..\int\WINDOW.C', 1167));

      subLen := PtrUInt(pch) - PtrUInt(start);
      substring := PAnsiChar(mymalloc(subLen + 1, '..\int\WINDOW.C', 1169));
      Move(start^, substring^, subLen);
      substring[subLen] := #0;

      PPAnsiChar(PByte(substringList) + SizeOf(PAnsiChar) * substringListLength)^ := substring;

      while pch^ = ' ' do
        Inc(pch);

      v1 := 0;
      start := pch;
      Inc(substringListLength);
    end;
  end;

  if start <> pch then
  begin
    if substringList <> nil then
      substringList := PPAnsiChar(myrealloc(substringList, SizeOf(PAnsiChar) * (substringListLength + 1), '..\int\WINDOW.C', 1184))
    else
      substringList := PPAnsiChar(mymalloc(SizeOf(PAnsiChar), '..\int\WINDOW.C', 1185));

    subLen := PtrUInt(pch) - PtrUInt(start);
    substring := PAnsiChar(mymalloc(subLen + 1, '..\int\WINDOW.C', 1187));
    Move(start^, substring^, subLen);
    substring[subLen] := #0;

    PPAnsiChar(PByte(substringList) + SizeOf(PAnsiChar) * substringListLength)^ := substring;
    Inc(substringListLength);
  end;

  substringListLengthPtr^ := substringListLength;
  Result := substringList;
end;

procedure windowFreeWordList(substringList: PPAnsiChar; substringListLength: Integer);
var
  index: Integer;
  entry: PAnsiChar;
begin
  if substringList = nil then
    Exit;

  for index := 0 to substringListLength - 1 do
  begin
    entry := PPAnsiChar(PByte(substringList) + SizeOf(PAnsiChar) * index)^;
    myfree(entry, '..\int\WINDOW.C', 1200);
  end;

  myfree(substringList, '..\int\WINDOW.C', 1201);
end;

procedure windowWrapLineWithSpacing(win: Integer; str: PAnsiChar; width, height, x, y, flags: Integer; textAlignment: Integer; a9: Integer);
var
  substringListLength: Integer;
  substringList: PPAnsiChar;
  index, v1: Integer;
  entry: PAnsiChar;
begin
  if str = nil then
    Exit;

  substringList := windowWordWrap(str, width, 0, @substringListLength);

  for index := 0 to substringListLength - 1 do
  begin
    v1 := y + index * (a9 + text_height());
    entry := PPAnsiChar(PByte(substringList) + SizeOf(PAnsiChar) * index)^;
    windowPrintBuf(win, entry, StrLen(entry), width, height + y, x, v1, flags, textAlignment);
  end;

  windowFreeWordList(substringList, substringListLength);
end;

procedure windowWrapLine(win: Integer; str: PAnsiChar; width, height, x, y, flags: Integer; textAlignment: Integer);
begin
  windowWrapLineWithSpacing(win, str, width, height, x, y, flags, textAlignment, 0);
end;

function windowPrintRect(str: PAnsiChar; a2: Integer; textAlignment: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  width, height, x, y, flags: Integer;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  width := Trunc(a2 * managedWindow^.field_54);
  height := win_height(managedWindow^.window);
  x := managedWindow^.field_44;
  y := managedWindow^.field_48;
  flags := windowGetTextColor or $2000000;

  windowWrapLine(managedWindow^.window, str, width, height, x, y, flags, textAlignment);

  Result := True;
end;

function windowFormatMessage(str: PAnsiChar; x, y, width, height: Integer; textAlignment: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  flags: Integer;
begin
  managedWindow := @windows[currentWindow];
  flags := windowGetTextColor or $2000000;

  windowWrapLine(managedWindow^.window, str, width, height, x, y, flags, textAlignment);

  Result := True;
end;

function windowFormatMessageColor(str: PAnsiChar; x, y, width, height: Integer; textAlignment, flags: Integer): Integer;
begin
  windowWrapLine(windows[currentWindow].window, str, width, height, x, y, flags, textAlignment);
  Result := 1;
end;

function windowPrint(str: PAnsiChar; a2, x, y, a5: Integer): Boolean;
var
  managedWindow: PManagedWindow;
begin
  managedWindow := @windows[currentWindow];
  x := Trunc(x * managedWindow^.field_54);
  y := Trunc(y * managedWindow^.field_58);

  win_print(managedWindow^.window, str, a2, x, y, a5);

  Result := True;
end;

function windowPrintFont(str: PAnsiChar; a2, x, y, a5, font: Integer): Integer;
var
  oldFont: Integer;
begin
  oldFont := text_curr;
  text_font(font);

  windowPrint(str, a2, x, y, a5);

  text_font(oldFont);

  Result := 1;
end;

procedure displayInWindow(data: PByte; width, height, pitch: Integer);
var
  windowBuffer: PByte;
begin
  if Assigned(displayFunc) then
  begin
    displayFunc(currentWindow,
      @windows[currentWindow].name[0],
      data,
      width,
      height);
  end;

  if width = pitch then
  begin
    if (pitch = windowWidth()) and (height = windowHeight()) then
    begin
      windowBuffer := windowGetBuffer;
      Move(data^, windowBuffer^, height * width);
    end
    else
    begin
      windowBuffer := windowGetBuffer;
      drawScaledBuf(windowBuffer, windowWidth(), windowHeight(), data, width, height);
    end;
  end
  else
  begin
    windowBuffer := windowGetBuffer;
    drawScaled(windowBuffer,
      windowWidth(),
      windowHeight(),
      windowWidth(),
      data,
      width,
      height,
      pitch);
  end;
end;

procedure displayFile(fileName: PAnsiChar);
var
  width, height: Integer;
  data: PByte;
begin
  data := loadDataFile(fileName, @width, @height);
  if data <> nil then
  begin
    displayInWindow(data, width, height, width);
    myfree(data, '..\int\WINDOW.C', 1294);
  end;
end;

procedure displayFileRaw(fileName: PAnsiChar);
var
  width, height: Integer;
  data: PByte;
begin
  data := loadRawDataFile(fileName, @width, @height);
  if data <> nil then
  begin
    displayInWindow(data, width, height, width);
    myfree(data, '..\int\WINDOW.C', 1305);
  end;
end;

function windowDisplayRaw(fileName: PAnsiChar): Integer;
var
  imageWidth, imageHeight: Integer;
  imageData: PByte;
begin
  imageData := loadDataFile(fileName, @imageWidth, @imageHeight);
  if imageData = nil then
  begin
    Result := 0;
    Exit;
  end;

  displayInWindow(imageData, imageWidth, imageHeight, imageWidth);
  myfree(imageData, '..\int\WINDOW.C', 1363);
  Result := 1;
end;

function windowDisplay(fileName: PAnsiChar; x, y, width, height: Integer): Boolean;
var
  imageWidth, imageHeight: Integer;
  imageData: PByte;
begin
  imageData := loadDataFile(fileName, @imageWidth, @imageHeight);
  if imageData = nil then
  begin
    Result := False;
    Exit;
  end;

  windowDisplayBuf(imageData, imageWidth, imageHeight, x, y, width, height);
  myfree(imageData, '..\int\WINDOW.C', 1376);
  Result := True;
end;

function windowDisplayScaled(fileName: PAnsiChar; x, y, width, height: Integer): Integer;
var
  imageWidth, imageHeight: Integer;
  imageData: PByte;
begin
  imageData := loadDataFile(fileName, @imageWidth, @imageHeight);
  if imageData = nil then
  begin
    Result := 0;
    Exit;
  end;

  windowDisplayBufScaled(imageData, imageWidth, imageHeight, x, y, width, height);
  myfree(imageData, '..\int\WINDOW.C', 1389);
  Result := 1;
end;

function windowDisplayBuf(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  windowBuffer: PByte;
begin
  managedWindow := @windows[currentWindow];
  windowBuffer := win_get_buf(managedWindow^.window);

  buf_to_buf(src,
    destWidth,
    destHeight,
    srcWidth,
    windowBuffer + managedWindow^.width * destY + destX,
    managedWindow^.width);

  Result := True;
end;

function windowDisplayTransBuf(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Integer;
var
  windowBuffer: PByte;
begin
  windowBuffer := win_get_buf(windows[currentWindow].window);

  trans_buf_to_buf(src,
    destWidth,
    destHeight,
    srcWidth,
    windowBuffer + destY * windows[currentWindow].width + destX,
    windows[currentWindow].width);

  Result := 1;
end;

function windowDisplayBufScaled(src: PByte; srcWidth, srcHeight, destX, destY, destWidth, destHeight: Integer): Integer;
var
  windowBuffer: PByte;
begin
  windowBuffer := win_get_buf(windows[currentWindow].window);
  drawScaled(windowBuffer + destY * windows[currentWindow].width + destX,
    destWidth,
    destHeight,
    windows[currentWindow].width,
    src,
    srcWidth,
    srcHeight,
    srcWidth);

  Result := 1;
end;

function windowGetXres: Integer;
begin
  Result := xres;
end;

function windowGetYres: Integer;
begin
  Result := yres;
end;

procedure windowRemoveProgramReferences(program_: PProgram);
var
  wndIndex, btnIndex, rgIndex: Integer;
  managedWindow: PManagedWindow;
  managedButton: PManagedButton;
  region: PRegion;
begin
  for wndIndex := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[wndIndex];
    if managedWindow^.window <> -1 then
    begin
      for btnIndex := 0 to managedWindow^.buttonsLength - 1 do
      begin
        managedButton := GetButtonPtr(managedWindow, btnIndex);
        if program_ = managedButton^.program_ then
        begin
          managedButton^.program_ := nil;
          managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_ENTER] := 0;
          managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_EXIT] := 0;
          managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_DOWN] := 0;
          managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_UP] := 0;
        end;
      end;

      for rgIndex := 0 to managedWindow^.regionsLength - 1 do
      begin
        region := GetRegionPtr(managedWindow, rgIndex);
        if region <> nil then
        begin
          if program_ = region^.program_ then
          begin
            region^.program_ := nil;
            region^.procs[1] := 0;
            region^.procs[0] := 0;
            region^.procs[3] := 0;
            region^.procs[2] := 0;
          end;
        end;
      end;
    end;
  end;
end;

procedure initWindow(video_options: PVideoOptions; flags: Integer);
var
  err: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  rc: Integer;
  i, j: Integer;
begin
  interpretRegisterProgramDeleteCallback(@windowRemoveProgramReferences);

  currentTextColorR := 0;
  currentTextColorG := 0;
  currentTextColorB := 0;
  currentHighlightColorR := 0;
  currentHighlightColorG := 0;
  currentHighlightColorB := 0;
  currentTextFlags_ := $2010000;

  // TODO: Review usage.
  yres := 640;
  xres := 480;

  for i := 0 to MANAGED_WINDOW_COUNT - 1 do
    windows[i].window := -1;

  rc := win_init(video_options, flags);
  if rc <> WINDOW_MANAGER_OK then
  begin
    case rc of
      WINDOW_MANAGER_ERR_INITIALIZING_VIDEO_MODE:
      begin
        StrFmt(err, 'Error initializing video mode %dx%d'#10, [xres, yres]);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_NO_MEMORY:
      begin
        StrCopy(err, 'Not enough memory to initialize video mode'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_INITIALIZING_TEXT_FONTS:
      begin
        StrCopy(err, 'Couldn''t find/load text fonts'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_WINDOW_SYSTEM_ALREADY_INITIALIZED:
      begin
        StrCopy(err, 'Attempt to initialize window system twice'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_WINDOW_SYSTEM_NOT_INITIALIZED:
      begin
        StrCopy(err, 'Window system not initialized'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_CURRENT_WINDOWS_TOO_BIG:
      begin
        StrCopy(err, 'Current windows are too big for new resolution'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_INITIALIZING_DEFAULT_DATABASE:
      begin
        StrCopy(err, 'Error initializing default database.'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_8:
      begin
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_ALREADY_RUNNING:
      begin
        StrCopy(err, 'Program already running.'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_TITLE_NOT_SET:
      begin
        StrCopy(err, 'Program title not set.'#10);
        GNWSystemError(err);
        Halt(1);
      end;
      WINDOW_MANAGER_ERR_INITIALIZING_INPUT:
      begin
        StrCopy(err, 'Failure initializing input devices.'#10);
        GNWSystemError(err);
        Halt(1);
      end;
    else
      begin
        StrFmt(err, 'Unknown error code %d'#10, [rc]);
        GNWSystemError(err);
        Halt(1);
      end;
    end;
  end;

  currentFont_ := 100;
  text_font(100);

  initMousemgr;

  mousemgrSetNameMangler(TMouseManagerNameMangler(@interpretMangleName));

  for i := 0 to 63 do
    for j := 0 to 255 do
      alphaBlendTable[(i shl 8) + j] := AnsiChar((i * j) shr 9);
end;

procedure windowSetWindowFuncs(createCallback: TManagedWindowCreateCallback;
  selectCallback: TManagedWindowSelectFunc;
  deleteCallback: TWindowDeleteCallback;
  displayCallback: TDisplayInWindowCallback);
begin
  if Assigned(createCallback) then
    createWindowFunc := createCallback;

  if Assigned(selectCallback) then
    selectWindowFunc := selectCallback;

  if Assigned(deleteCallback) then
    deleteWindowFunc := deleteCallback;

  if Assigned(displayCallback) then
    displayFunc := displayCallback;
end;

procedure windowClose;
var
  index: Integer;
  managedWindow: PManagedWindow;
begin
  for index := 0 to MANAGED_WINDOW_COUNT - 1 do
  begin
    managedWindow := @windows[index];
    if managedWindow^.window <> -1 then
      deleteWindow(managedWindow^.name);
  end;

  if inputFunc <> nil then
    myfree(inputFunc, '..\int\WINDOW.C', 1579);

  mousemgrClose;
  db_exit;
  win_exit;
end;

function windowDeleteButton(const buttonName: PAnsiChar): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttonsLength = 0 then
  begin
    Result := False;
    Exit;
  end;

  if buttonName = nil then
  begin
    for index := 0 to managedWindow^.buttonsLength - 1 do
    begin
      managedButton := GetButtonPtr(managedWindow, index);
      win_delete_button(managedButton^.btn);

      if managedButton^.hover <> nil then
      begin
        myfree(managedButton^.hover, '..\int\WINDOW.C', 1654);
        managedButton^.hover := nil;
      end;

      if managedButton^.field_4C <> nil then
      begin
        myfree(managedButton^.field_4C, '..\int\WINDOW.C', 1655);
        managedButton^.field_4C := nil;
      end;

      if managedButton^.pressed <> nil then
      begin
        myfree(managedButton^.pressed, '..\int\WINDOW.C', 1656);
        managedButton^.pressed := nil;
      end;

      if managedButton^.normal <> nil then
      begin
        myfree(managedButton^.normal, '..\int\WINDOW.C', 1657);
        managedButton^.normal := nil;
      end;

      if managedButton^.field_50 <> nil then
      begin
        myfree(managedButton^.field_50, '..\int\WINDOW.C', 1658);
        managedButton^.field_50 := nil;
      end;
    end;

    myfree(managedWindow^.buttons, '..\int\WINDOW.C', 1660);
    managedWindow^.buttons := nil;
    managedWindow^.buttonsLength := 0;

    Result := True;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      win_delete_button(managedButton^.btn);

      if managedButton^.hover <> nil then
      begin
        myfree(managedButton^.hover, '..\int\WINDOW.C', 1671);
        managedButton^.hover := nil;
      end;

      if managedButton^.field_4C <> nil then
      begin
        myfree(managedButton^.field_4C, '..\int\WINDOW.C', 1672);
        managedButton^.field_4C := nil;
      end;

      if managedButton^.pressed <> nil then
      begin
        myfree(managedButton^.pressed, '..\int\WINDOW.C', 1673);
        managedButton^.pressed := nil;
      end;

      if managedButton^.normal <> nil then
      begin
        myfree(managedButton^.normal, '..\int\WINDOW.C', 1674);
        managedButton^.normal := nil;
      end;

      // FIXME: Probably leaking field_50.

      if index <> managedWindow^.buttonsLength - 1 then
      begin
        Move(PByte(managedWindow^.buttons)[SizeOf(TManagedButton) * (index + 1)],
             PByte(managedWindow^.buttons)[SizeOf(TManagedButton) * index],
             SizeOf(TManagedButton) * (managedWindow^.buttonsLength - index - 1));
      end;

      Dec(managedWindow^.buttonsLength);
      if managedWindow^.buttonsLength = 0 then
      begin
        myfree(managedWindow^.buttons, '..\int\WINDOW.C', 1678);
        managedWindow^.buttons := nil;
      end;

      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

procedure windowEnableButton(const buttonName: PAnsiChar; enabled: Integer);
var
  index: Integer;
begin
  for index := 0 to windows[currentWindow].buttonsLength - 1 do
  begin
    if compat_stricmp(GetButtonPtr(@windows[currentWindow], index)^.name, buttonName) = 0 then
    begin
      if enabled <> 0 then
      begin
        if Assigned(soundPressFunc_) or Assigned(soundReleaseFunc_) then
          win_register_button_sound_func(GetButtonPtr(@windows[currentWindow], index)^.btn, soundPressFunc_, soundReleaseFunc_);

        GetButtonPtr(@windows[currentWindow], index)^.flags := GetButtonPtr(@windows[currentWindow], index)^.flags and (not $02);
      end
      else
      begin
        if Assigned(soundDisableFunc_) then
          win_register_button_sound_func(GetButtonPtr(@windows[currentWindow], index)^.btn, soundDisableFunc_, nil);

        GetButtonPtr(@windows[currentWindow], index)^.flags := GetButtonPtr(@windows[currentWindow], index)^.flags or $02;
      end;
    end;
  end;
end;

function windowGetButtonID(const buttonName: PAnsiChar): Integer;
var
  index: Integer;
begin
  for index := 0 to windows[currentWindow].buttonsLength - 1 do
  begin
    if compat_stricmp(GetButtonPtr(@windows[currentWindow], index)^.name, buttonName) = 0 then
    begin
      Result := GetButtonPtr(@windows[currentWindow], index)^.btn;
      Exit;
    end;
  end;

  Result := -1;
end;

function windowSetButtonFlag(const buttonName: PAnsiChar; value: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      managedButton^.flags := managedButton^.flags or value;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

procedure windowRegisterButtonSoundFunc(aSoundPressFunc, aSoundReleaseFunc, aSoundDisableFunc: TButtonCallback);
begin
  soundPressFunc_ := aSoundPressFunc;
  soundReleaseFunc_ := aSoundReleaseFunc;
  soundDisableFunc_ := aSoundDisableFunc;
end;

function windowAddButton(const buttonName: PAnsiChar; x, y, width, height, flags: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
  normal, pressed: PByte;
  localX, localY, localW, localH: Integer;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  index := 0;
  while index < managedWindow^.buttonsLength do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      win_delete_button(managedButton^.btn);

      if managedButton^.hover <> nil then
      begin
        myfree(managedButton^.hover, '..\int\WINDOW.C', 1754);
        managedButton^.hover := nil;
      end;

      if managedButton^.field_4C <> nil then
      begin
        myfree(managedButton^.field_4C, '..\int\WINDOW.C', 1755);
        managedButton^.field_4C := nil;
      end;

      if managedButton^.pressed <> nil then
      begin
        myfree(managedButton^.pressed, '..\int\WINDOW.C', 1756);
        managedButton^.pressed := nil;
      end;

      if managedButton^.normal <> nil then
      begin
        myfree(managedButton^.normal, '..\int\WINDOW.C', 1757);
        managedButton^.normal := nil;
      end;

      Break;
    end;
    Inc(index);
  end;

  if index = managedWindow^.buttonsLength then
  begin
    if managedWindow^.buttons = nil then
      managedWindow^.buttons := PManagedButton(mymalloc(SizeOf(TManagedButton), '..\int\WINDOW.C', 1764))
    else
      managedWindow^.buttons := PManagedButton(myrealloc(managedWindow^.buttons, SizeOf(TManagedButton) * (managedWindow^.buttonsLength + 1), '..\int\WINDOW.C', 1767));
    managedWindow^.buttonsLength := managedWindow^.buttonsLength + 1;
  end;

  localX := Trunc(x * managedWindow^.field_54);
  localY := Trunc(y * managedWindow^.field_58);
  localW := Trunc(width * managedWindow^.field_54);
  localH := Trunc(height * managedWindow^.field_58);

  managedButton := GetButtonPtr(managedWindow, index);
  StrLCopy(managedButton^.name, buttonName, 31);
  managedButton^.name[31] := #0;
  managedButton^.program_ := nil;
  managedButton^.flags := 0;
  managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_UP] := 0;
  managedButton^.rightProcs[MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_UP] := 0;
  managedButton^.mouseEventCallback := nil;
  managedButton^.rightMouseEventCallback := nil;
  managedButton^.field_50 := nil;
  managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_DOWN] := 0;
  managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_EXIT] := 0;
  managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_ENTER] := 0;
  managedButton^.rightProcs[MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_DOWN] := 0;
  managedButton^.width := localW;
  managedButton^.height := localH;
  managedButton^.x := localX;
  managedButton^.y := localY;

  normal := PByte(mymalloc(localW * localH, '..\int\WINDOW.C', 1798));
  pressed := PByte(mymalloc(localW * localH, '..\int\WINDOW.C', 1799));

  if (flags and BUTTON_FLAG_TRANSPARENT) <> 0 then
  begin
    FillChar(normal^, localW * localH, 0);
    FillChar(pressed^, localW * localH, 0);
  end
  else
    setButtonGFX(localW, localH, normal, pressed, nil);

  managedButton^.btn := win_register_button(
    managedWindow^.window,
    localX,
    localY,
    localW,
    localH,
    -1,
    -1,
    -1,
    -1,
    normal,
    pressed,
    nil,
    flags);

  if Assigned(soundPressFunc_) or Assigned(soundReleaseFunc_) then
    win_register_button_sound_func(managedButton^.btn, soundPressFunc_, soundReleaseFunc_);

  managedButton^.hover := nil;
  managedButton^.pressed := pressed;
  managedButton^.normal := normal;
  managedButton^.field_18 := flags;
  managedButton^.field_4C := nil;
  win_register_button_func(managedButton^.btn, @doButtonOn, @doButtonOff, @doButtonPress, @doButtonRelease);
  windowSetButtonFlag(buttonName, 1);

  if (flags and BUTTON_FLAG_TRANSPARENT) <> 0 then
    win_register_button_mask(managedButton^.btn, normal);

  Result := True;
end;

function windowAddButtonGfx(const buttonName: PAnsiChar; pressedFileName, normalFileName, hoverFileName: PAnsiChar): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
  width, height: Integer;
  pressedData, normalData, hoverData: PByte;
begin
  managedWindow := @windows[currentWindow];
  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      if pressedFileName <> nil then
      begin
        pressedData := loadDataFile(pressedFileName, @width, @height);
        if pressedData <> nil then
        begin
          drawScaledBuf(managedButton^.pressed, managedButton^.width, managedButton^.height, pressedData, width, height);
          myfree(pressedData, '..\int\WINDOW.C', 1840);
        end;
      end;

      if normalFileName <> nil then
      begin
        normalData := loadDataFile(normalFileName, @width, @height);
        if normalData <> nil then
        begin
          drawScaledBuf(managedButton^.normal, managedButton^.width, managedButton^.height, normalData, width, height);
          myfree(normalData, '..\int\WINDOW.C', 1848);
        end;
      end;

      if hoverFileName <> nil then
      begin
        hoverData := loadDataFile(normalFileName, @width, @height);
        if hoverData <> nil then
        begin
          if managedButton^.hover = nil then
            managedButton^.hover := PByte(mymalloc(managedButton^.height * managedButton^.width, '..\int\WINDOW.C', 1855));

          drawScaledBuf(managedButton^.hover, managedButton^.width, managedButton^.height, hoverData, width, height);
          myfree(hoverData, '..\int\WINDOW.C', 1859);
        end;
      end;

      if (managedButton^.field_18 and $20) <> 0 then
        win_register_button_mask(managedButton^.btn, managedButton^.normal);

      win_register_button_image(managedButton^.btn, managedButton^.normal, managedButton^.pressed, managedButton^.hover, False);

      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowAddButtonMask(const buttonName: PAnsiChar; buffer: PByte): Integer;
var
  index: Integer;
  button: PManagedButton;
  copy: PByte;
begin
  for index := 0 to windows[currentWindow].buttonsLength - 1 do
  begin
    button := GetButtonPtr(@windows[currentWindow], index);
    if compat_stricmp(button^.name, buttonName) = 0 then
    begin
      copy := PByte(mymalloc(button^.width * button^.height, '..\int\WINDOW.C', 1877));
      Move(buffer^, copy^, button^.width * button^.height);
      win_register_button_mask(button^.btn, copy);
      button^.field_50 := copy;
      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

function windowAddButtonBuf(const buttonName: PAnsiChar; normal, pressed, hover: PByte; width, height, pitch: Integer): Integer;
var
  index: Integer;
  button: PManagedButton;
begin
  for index := 0 to windows[currentWindow].buttonsLength - 1 do
  begin
    button := GetButtonPtr(@windows[currentWindow], index);
    if compat_stricmp(button^.name, buttonName) = 0 then
    begin
      if normal <> nil then
      begin
        FillChar(button^.normal^, button^.width * button^.height, 0);
        drawScaled(button^.normal,
          button^.width,
          button^.height,
          button^.width,
          normal,
          width,
          height,
          pitch);
      end;

      if pressed <> nil then
      begin
        FillChar(button^.pressed^, button^.width * button^.height, 0);
        drawScaled(button^.pressed,
          button^.width,
          button^.height,
          button^.width,
          pressed,
          width,
          height,
          pitch);
      end;

      if hover <> nil then
      begin
        FillChar(button^.hover^, button^.width * button^.height, 0);
        drawScaled(button^.hover,
          button^.width,
          button^.height,
          button^.width,
          hover,
          width,
          height,
          pitch);
      end;

      if (button^.field_18 and $20) <> 0 then
        win_register_button_mask(button^.btn, button^.normal);

      win_register_button_image(button^.btn, button^.normal, button^.pressed, button^.hover, False);

      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

function windowAddButtonProc(const buttonName: PAnsiChar; program_: PProgram; mouseEnterProc, mouseExitProc, mouseDownProc, mouseUpProc: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_ENTER] := mouseEnterProc;
      managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_EXIT] := mouseExitProc;
      managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_DOWN] := mouseDownProc;
      managedButton^.procs[MANAGED_BUTTON_MOUSE_EVENT_BUTTON_UP] := mouseUpProc;
      managedButton^.program_ := program_;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowAddButtonRightProc(const buttonName: PAnsiChar; program_: PProgram; rightMouseDownProc, rightMouseUpProc: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      managedButton^.rightProcs[MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_UP] := rightMouseUpProc;
      managedButton^.rightProcs[MANAGED_BUTTON_RIGHT_MOUSE_EVENT_BUTTON_DOWN] := rightMouseDownProc;
      managedButton^.program_ := program_;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowAddButtonCfunc(const buttonName: PAnsiChar; callback: TManagedButtonMouseEventCallback; userData: Pointer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      managedButton^.mouseEventCallbackUserData := userData;
      managedButton^.mouseEventCallback := callback;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowAddButtonRightCfunc(const buttonName: PAnsiChar; callback: TManagedButtonMouseEventCallback; userData: Pointer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      managedButton^.rightMouseEventCallback := callback;
      managedButton^.rightMouseEventCallbackUserData := userData;
      win_register_right_button(managedButton^.btn, -1, -1, @doRightButtonPress, @doRightButtonRelease);
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowAddButtonText(const buttonName: PAnsiChar; const text: PAnsiChar): Boolean;
begin
  Result := windowAddButtonTextWithOffsets(buttonName, text, 2, 2, 0, 0);
end;

function windowAddButtonTextWithOffsets(const buttonName: PAnsiChar; const text: PAnsiChar; pressedImageOffsetX, pressedImageOffsetY, normalImageOffsetX, normalImageOffsetY: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  managedButton: PManagedButton;
  normalImageHeight, normalImageWidth: Integer;
  buffer: PByte;
  normalImageX, normalImageY: Integer;
  pressedImageWidth, pressedImageHeight: Integer;
  pressedImageX, pressedImageY: Integer;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.buttons = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.buttonsLength - 1 do
  begin
    managedButton := GetButtonPtr(managedWindow, index);
    if compat_stricmp(managedButton^.name, buttonName) = 0 then
    begin
      normalImageHeight := text_height() + 1;
      normalImageWidth := text_width(text) + 1;
      buffer := PByte(mymalloc(normalImageHeight * normalImageWidth, '..\int\WINDOW.C', 2016));

      normalImageX := (managedButton^.width - normalImageWidth) div 2 + normalImageOffsetX;
      normalImageY := (managedButton^.height - normalImageHeight) div 2 + normalImageOffsetY;

      if normalImageX < 0 then
      begin
        normalImageWidth := normalImageWidth - normalImageX;
        normalImageX := 0;
      end;

      if normalImageX + normalImageWidth >= managedButton^.width then
        normalImageWidth := managedButton^.width - normalImageX;

      if normalImageY < 0 then
      begin
        normalImageHeight := normalImageHeight - normalImageY;
        normalImageY := 0;
      end;

      if normalImageY + normalImageHeight >= managedButton^.height then
        normalImageHeight := managedButton^.height - normalImageY;

      if managedButton^.normal <> nil then
        buf_to_buf(managedButton^.normal + managedButton^.width * normalImageY + normalImageX,
          normalImageWidth,
          normalImageHeight,
          managedButton^.width,
          buffer,
          normalImageWidth)
      else
        FillChar(buffer^, normalImageHeight * normalImageWidth, 0);

      text_to_buf(buffer,
        text,
        normalImageWidth,
        normalImageWidth,
        windowGetTextColor + windowGetTextFlags);

      trans_buf_to_buf(buffer,
        normalImageWidth,
        normalImageHeight,
        normalImageWidth,
        managedButton^.normal + managedButton^.width * normalImageY + normalImageX,
        managedButton^.width);

      pressedImageWidth := text_width(text) + 1;
      pressedImageHeight := text_height() + 1;

      pressedImageX := (managedButton^.width - pressedImageWidth) div 2 + pressedImageOffsetX;
      pressedImageY := (managedButton^.height - pressedImageHeight) div 2 + pressedImageOffsetY;

      if pressedImageX < 0 then
      begin
        pressedImageWidth := pressedImageWidth - pressedImageX;
        pressedImageX := 0;
      end;

      if pressedImageX + pressedImageWidth >= managedButton^.width then
        pressedImageWidth := managedButton^.width - pressedImageX;

      if pressedImageY < 0 then
      begin
        pressedImageHeight := pressedImageHeight - pressedImageY;
        pressedImageY := 0;
      end;

      if pressedImageY + pressedImageHeight >= managedButton^.height then
        pressedImageHeight := managedButton^.height - pressedImageY;

      if managedButton^.pressed <> nil then
        buf_to_buf(managedButton^.pressed + managedButton^.width * pressedImageY + pressedImageX,
          pressedImageWidth,
          pressedImageHeight,
          managedButton^.width,
          buffer,
          pressedImageWidth)
      else
        FillChar(buffer^, pressedImageHeight * pressedImageWidth, 0);

      text_to_buf(buffer,
        text,
        pressedImageWidth,
        pressedImageWidth,
        windowGetTextColor + windowGetTextFlags);

      trans_buf_to_buf(buffer,
        pressedImageWidth,
        normalImageHeight,
        normalImageWidth,
        managedButton^.pressed + managedButton^.width * pressedImageY + pressedImageX,
        managedButton^.width);

      myfree(buffer, '..\int\WINDOW.C', 2084);

      if (managedButton^.field_18 and $20) <> 0 then
        win_register_button_mask(managedButton^.btn, managedButton^.normal);

      win_register_button_image(managedButton^.btn, managedButton^.normal, managedButton^.pressed, managedButton^.hover, False);

      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function windowFill(r, g, b: Single): Boolean;
var
  colorIndex: Integer;
  wid: Integer;
begin
  colorIndex := (Trunc(r * 31.0) shl 10) or (Trunc(g * 31.0) shl 5) or Trunc(b * 31.0);
  wid := windowGetGNWID;
  win_fill(wid, 0, 0, windowWidth, windowHeight, colorTable[colorIndex]);
  Result := True;
end;

function windowFillRect(x, y, width, height: Integer; r, g, b: Single): Boolean;
var
  managedWindow: PManagedWindow;
  colorIndex: Integer;
  wid: Integer;
begin
  managedWindow := @windows[currentWindow];
  x := Trunc(x * managedWindow^.field_54);
  y := Trunc(y * managedWindow^.field_58);
  width := Trunc(width * managedWindow^.field_54);
  height := Trunc(height * managedWindow^.field_58);

  colorIndex := (Trunc(r * 31.0) shl 10) or (Trunc(g * 31.0) shl 5) or Trunc(b * 31.0);
  wid := windowGetGNWID;
  win_fill(wid, x, y, width, height, colorTable[colorIndex]);
  Result := True;
end;

procedure windowEndRegion;
var
  managedWindow: PManagedWindow;
  region: PRegion;
begin
  managedWindow := @windows[currentWindow];
  region := GetRegionPtr(managedWindow, managedWindow^.currentRegionIndex);
  windowAddRegionPoint(region^.points^.x, region^.points^.y, False);
  regionSetBound(region);
end;

function windowRegionGetUserData(const windowRegionName: PAnsiChar): Pointer;
var
  index: Integer;
  rgnName: PAnsiChar;
begin
  if currentWindow = -1 then
  begin
    Result := nil;
    Exit;
  end;

  for index := 0 to windows[currentWindow].regionsLength - 1 do
  begin
    rgnName := GetRegionPtr(@windows[currentWindow], index)^.name;
    if compat_stricmp(rgnName, windowRegionName) = 0 then
    begin
      Result := regionGetUserData(GetRegionPtr(@windows[currentWindow], index));
      Exit;
    end;
  end;

  Result := nil;
end;

procedure windowRegionSetUserData(const windowRegionName: PAnsiChar; userData: Pointer);
var
  index: Integer;
  rgnName: PAnsiChar;
begin
  if currentWindow = -1 then
    Exit;

  for index := 0 to windows[currentWindow].regionsLength - 1 do
  begin
    rgnName := GetRegionPtr(@windows[currentWindow], index)^.name;
    if compat_stricmp(rgnName, windowRegionName) = 0 then
    begin
      regionSetUserData(GetRegionPtr(@windows[currentWindow], index), userData);
      Exit;
    end;
  end;
end;

function windowCheckRegionExists(const regionName: PAnsiChar): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.window = -1 then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.regionsLength - 1 do
  begin
    region := GetRegionPtr(managedWindow, index);
    if region <> nil then
    begin
      if compat_stricmp(regionGetName(region), regionName) = 0 then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

  Result := False;
end;

function windowStartRegion(initialCapacity: Integer): Boolean;
var
  newRegionIndex, index: Integer;
  managedWindow: PManagedWindow;
  newRegion: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.regions = nil then
  begin
    managedWindow^.regions := mymalloc(SizeOf(PRegion), '..\int\WINDOW.C', 2173);
    managedWindow^.regionsLength := 1;
    newRegionIndex := 0;
  end
  else
  begin
    newRegionIndex := 0;
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      if GetRegionPtr(managedWindow, index) = nil then
        Break;
      Inc(newRegionIndex);
    end;

    if newRegionIndex = managedWindow^.regionsLength then
    begin
      managedWindow^.regions := myrealloc(managedWindow^.regions, SizeOf(PRegion) * (managedWindow^.regionsLength + 1), '..\int\WINDOW.C', 2184);
      Inc(managedWindow^.regionsLength);
    end;
  end;

  if initialCapacity <> 0 then
    newRegion := allocateRegion(initialCapacity + 1)
  else
    newRegion := nil;

  SetRegionPtr(managedWindow, newRegionIndex, newRegion);
  managedWindow^.currentRegionIndex := newRegionIndex;

  Result := True;
end;

function windowAddRegionPoint(x, y: Integer; a3: Boolean): Boolean;
var
  managedWindow: PManagedWindow;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  region := GetRegionPtr(managedWindow, managedWindow^.currentRegionIndex);
  if region = nil then
  begin
    region := allocateRegion(1);
    SetRegionPtr(managedWindow, managedWindow^.currentRegionIndex, region);
  end;

  if a3 then
  begin
    x := Trunc(x * managedWindow^.field_54);
    y := Trunc(y * managedWindow^.field_58);
  end;

  regionAddPoint(region, x, y);

  Result := True;
end;

function windowAddRegionRect(a1, a2, a3, a4, a5: Integer): Integer;
begin
  windowAddRegionPoint(a1, a2, a5 <> 0);
  windowAddRegionPoint(a3, a2, a5 <> 0);
  windowAddRegionPoint(a3, a4, a5 <> 0);
  windowAddRegionPoint(a1, a4, a5 <> 0);

  Result := 0;
end;

function windowAddRegionCfunc(const regionName: PAnsiChar; callback: TRegionMouseEventCallback; userData: Pointer): Integer;
var
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := 0;
    Exit;
  end;

  for index := 0 to windows[currentWindow].regionsLength - 1 do
  begin
    region := GetRegionPtr(@windows[currentWindow], index);
    if (region <> nil) and (compat_stricmp(region^.name, regionName) = 0) then
    begin
      region^.mouseEventCallback := callback;
      region^.mouseEventCallbackUserData := userData;
      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

function windowAddRegionRightCfunc(const regionName: PAnsiChar; callback: TRegionMouseEventCallback; userData: Pointer): Integer;
var
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := 0;
    Exit;
  end;

  for index := 0 to windows[currentWindow].regionsLength - 1 do
  begin
    region := GetRegionPtr(@windows[currentWindow], index);
    if (region <> nil) and (compat_stricmp(region^.name, regionName) = 0) then
    begin
      region^.rightMouseEventCallback := callback;
      region^.rightMouseEventCallbackUserData := userData;
      Result := 1;
      Exit;
    end;
  end;

  Result := 0;
end;

function windowAddRegionProc(const regionName: PAnsiChar; program_: PProgram; a3, a4, a5, a6: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  for index := 0 to managedWindow^.regionsLength - 1 do
  begin
    region := GetRegionPtr(managedWindow, index);
    if region <> nil then
    begin
      if compat_stricmp(region^.name, regionName) = 0 then
      begin
        region^.procs[2] := a3;
        region^.procs[3] := a4;
        region^.procs[0] := a5;
        region^.procs[1] := a6;
        region^.program_ := program_;
        Result := True;
        Exit;
      end;
    end;
  end;

  Result := False;
end;

function windowAddRegionRightProc(const regionName: PAnsiChar; program_: PProgram; a3, a4: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  for index := 0 to managedWindow^.regionsLength - 1 do
  begin
    region := GetRegionPtr(managedWindow, index);
    if region <> nil then
    begin
      if compat_stricmp(region^.name, regionName) = 0 then
      begin
        region^.rightProcs[0] := a3;
        region^.rightProcs[1] := a4;
        region^.program_ := program_;
        Result := True;
        Exit;
      end;
    end;
  end;

  Result := False;
end;

function windowSetRegionFlag(const regionName: PAnsiChar; value: Integer): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow <> -1 then
  begin
    managedWindow := @windows[currentWindow];
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, index);
      if region <> nil then
      begin
        if compat_stricmp(region^.name, regionName) = 0 then
        begin
          regionSetFlag(region, value);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;

  Result := False;
end;

function windowAddRegionName(const regionName: PAnsiChar): Boolean;
var
  managedWindow: PManagedWindow;
  region: PRegion;
  index: Integer;
  other: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  region := GetRegionPtr(managedWindow, managedWindow^.currentRegionIndex);
  if region = nil then
  begin
    Result := False;
    Exit;
  end;

  for index := 0 to managedWindow^.regionsLength - 1 do
  begin
    if index <> managedWindow^.currentRegionIndex then
    begin
      other := GetRegionPtr(managedWindow, index);
      if other <> nil then
      begin
        if compat_stricmp(regionGetName(other), regionName) = 0 then
        begin
          regionDelete(other);
          SetRegionPtr(managedWindow, index, nil);
          Break;
        end;
      end;
    end;
  end;

  regionAddName(region, regionName);

  Result := True;
end;

function windowDeleteRegion(const regionName: PAnsiChar): Boolean;
var
  managedWindow: PManagedWindow;
  index: Integer;
  region: PRegion;
begin
  if currentWindow = -1 then
  begin
    Result := False;
    Exit;
  end;

  managedWindow := @windows[currentWindow];
  if managedWindow^.window = -1 then
  begin
    Result := False;
    Exit;
  end;

  if regionName <> nil then
  begin
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, index);
      if region <> nil then
      begin
        if compat_stricmp(regionGetName(region), regionName) = 0 then
        begin
          regionDelete(region);
          SetRegionPtr(managedWindow, index, nil);
          Inc(managedWindow^.field_38);
          Result := True;
          Exit;
        end;
      end;
    end;
    Result := False;
    Exit;
  end;

  Inc(managedWindow^.field_38);

  if managedWindow^.regions <> nil then
  begin
    for index := 0 to managedWindow^.regionsLength - 1 do
    begin
      region := GetRegionPtr(managedWindow, index);
      if region <> nil then
        regionDelete(region);
    end;

    myfree(managedWindow^.regions, '..\int\WINDOW.C', 2359);

    managedWindow^.regions := nil;
    managedWindow^.regionsLength := 0;
  end;

  Result := True;
end;

procedure updateWindows;
begin
  movieUpdate;
  mousemgrUpdate;
  checkAllRegions;
  update_widgets;
end;

function windowMoviePlaying: Integer;
begin
  Result := moviePlaying;
end;

function windowSetMovieFlags(flags: Integer): Boolean;
begin
  if movieSetFlags(flags) <> 0 then
    Result := False
  else
    Result := True;
end;

function windowPlayMovie(filePath: PAnsiChar): Boolean;
var
  wid: Integer;
begin
  wid := windowGetGNWID;
  if movieRun(wid, filePath) <> 0 then
    Result := False
  else
    Result := True;
end;

function windowPlayMovieRect(filePath: PAnsiChar; a2, a3, a4, a5: Integer): Boolean;
var
  wid: Integer;
begin
  wid := windowGetGNWID;
  if movieRunRect(wid, filePath, a2, a3, a4, a5) <> 0 then
    Result := False
  else
    Result := True;
end;

procedure windowStopMovie;
begin
  movieStop;
end;

procedure drawScaled(dest: PByte; destWidth, destHeight, destPitch: Integer; src: PByte; srcWidth, srcHeight, srcPitch: Integer);
var
  incrementX, incrementY: Integer;
  stepX, stepY: Integer;
  destSkip, srcSkip: Integer;
  srcPosY, srcPosX: Integer;
  offset: Integer;
  x, y: Integer;
  destPtr: PByte;
begin
  if (destWidth = srcWidth) and (destHeight = srcHeight) then
  begin
    buf_to_buf(src, srcWidth, srcHeight, srcPitch, dest, destPitch);
    Exit;
  end;

  incrementX := (srcWidth shl 16) div destWidth;
  incrementY := (srcHeight shl 16) div destHeight;
  stepX := incrementX shr 16;
  stepY := incrementY shr 16;
  destSkip := destPitch - destWidth;
  srcSkip := stepY * srcPitch;

  if srcSkip <> 0 then
  begin
    // Downscaling.
    srcPosY := 0;
    for y := 0 to destHeight - 1 do
    begin
      srcPosX := 0;
      offset := 0;
      for x := 0 to destWidth - 1 do
      begin
        dest^ := src[offset];
        Inc(dest);
        offset := offset + stepX;

        srcPosX := srcPosX + incrementX;
        if srcPosX >= $10000 then
          srcPosX := srcPosX and $FFFF;
      end;

      dest := dest + destSkip;
      src := src + srcSkip;

      srcPosY := srcPosY + stepY;
      if srcPosY >= $10000 then
      begin
        srcPosY := srcPosY and $FFFF;
        src := src + srcPitch;
      end;
    end;
  end
  else
  begin
    // Upscaling.
    y := 0;
    srcPosY := 0;
    while y < destHeight do
    begin
      destPtr := dest;

      srcPosX := 0;
      offset := 0;
      for x := 0 to destWidth - 1 do
      begin
        dest^ := src[offset];
        Inc(dest);
        offset := offset + stepX;

        srcPosX := srcPosX + stepX;
        if srcPosX >= $10000 then
        begin
          Inc(offset);
          srcPosX := srcPosX and $FFFF;
        end;
      end;

      Inc(y);
      if y < destHeight then
      begin
        dest := dest + destSkip;
        srcPosY := srcPosY + incrementY;

        while (y < destHeight) and (srcPosY < $10000) do
        begin
          Move(destPtr^, dest^, destWidth);
          dest := dest + destWidth;
          srcPosY := srcPosY + incrementY;
          Inc(y);
        end;

        srcPosY := srcPosY and $FFFF;
        src := src + srcPitch;
      end;
    end;
  end;
end;

procedure drawScaledBuf(dest: PByte; destWidth, destHeight: Integer; src: PByte; srcWidth, srcHeight: Integer);
var
  incrementX, incrementY: Integer;
  stepX, stepY: Integer;
  srcSkip: Integer;
  srcPosY, srcPosX: Integer;
  offset: Integer;
  x, y: Integer;
  destPtr: PByte;
begin
  if (destWidth = srcWidth) and (destHeight = srcHeight) then
  begin
    Move(src^, dest^, srcWidth * srcHeight);
    Exit;
  end;

  incrementX := (srcWidth shl 16) div destWidth;
  incrementY := (srcHeight shl 16) div destHeight;
  stepX := incrementX shr 16;
  stepY := incrementY shr 16;
  srcSkip := stepY * srcWidth;

  if srcSkip <> 0 then
  begin
    // Downscaling.
    srcPosY := 0;
    for y := 0 to destHeight - 1 do
    begin
      srcPosX := 0;
      offset := 0;
      for x := 0 to destWidth - 1 do
      begin
        dest^ := src[offset];
        Inc(dest);
        offset := offset + stepX;

        srcPosX := srcPosX + incrementX;
        if srcPosX >= $10000 then
          srcPosX := srcPosX and $FFFF;
      end;

      src := src + srcSkip;

      srcPosY := srcPosY + stepY;
      if srcPosY >= $10000 then
      begin
        srcPosY := srcPosY and $FFFF;
        src := src + srcWidth;
      end;
    end;
  end
  else
  begin
    // Upscaling.
    y := 0;
    srcPosY := 0;
    while y < destHeight do
    begin
      destPtr := dest;

      srcPosX := 0;
      offset := 0;
      for x := 0 to destWidth - 1 do
      begin
        dest^ := src[offset];
        Inc(dest);
        offset := offset + stepX;

        srcPosX := srcPosX + stepX;
        if srcPosX >= $10000 then
        begin
          Inc(offset);
          srcPosX := srcPosX and $FFFF;
        end;
      end;

      Inc(y);
      if y < destHeight then
      begin
        srcPosY := srcPosY + incrementY;

        while (y < destHeight) and (srcPosY < $10000) do
        begin
          Move(destPtr^, dest^, destWidth);
          dest := dest + destWidth;
          srcPosY := srcPosY + incrementY;
          Inc(y);
        end;

        srcPosY := srcPosY and $FFFF;
        src := src + srcWidth;
      end;
    end;
  end;
end;

procedure alphaBltBuf(src: PByte; srcWidth, srcHeight, srcPitch: Integer; alphaWindowBuffer, alphaBuffer, dest: PByte; destPitch: Integer);
var
  y, x: Integer;
  rle: Integer;
  destPtr, srcPtr, alphaWindowBufferPtr, alphaBufferPtr: PByte;
  idx: Integer;
  v1, v2: PByte;
  alpha_: Byte;
  r, g, b: LongWord;
  colorIndex: LongWord;
begin
  for y := 0 to srcHeight - 1 do
  begin
    for x := 0 to srcWidth - 1 do
    begin
      rle := (alphaBuffer[0] shl 8) + alphaBuffer[1];
      alphaBuffer := alphaBuffer + 2;
      if (rle and $8000) <> 0 then
      begin
        rle := rle and (not $8000);
      end
      else if (rle and $4000) <> 0 then
      begin
        rle := rle and (not $4000);
        Move(src^, dest^, rle);
      end
      else
      begin
        destPtr := dest;
        srcPtr := src;
        alphaWindowBufferPtr := alphaWindowBuffer;
        alphaBufferPtr := alphaBuffer;
        for idx := 0 to rle - 1 do
        begin
          v1 := @cmap[srcPtr^ * 3];
          v2 := @cmap[alphaWindowBufferPtr^ * 3];
          alpha_ := alphaBufferPtr^;

          // NOTE: Original code is slightly different.
          r := Byte(alphaBlendTable[(v1[0] shl 8) or alpha_]) + Byte(alphaBlendTable[(v2[0] shl 8) or alpha_]);
          g := Byte(alphaBlendTable[(v1[1] shl 8) or alpha_]) + Byte(alphaBlendTable[(v2[1] shl 8) or alpha_]);
          b := Byte(alphaBlendTable[(v1[2] shl 8) or alpha_]) + Byte(alphaBlendTable[(v2[2] shl 8) or alpha_]);
          colorIndex := (r shl 10) or (g shl 5) or b;

          destPtr^ := colorTable[colorIndex];

          Inc(destPtr);
          Inc(srcPtr);
          Inc(alphaWindowBufferPtr);
          Inc(alphaBufferPtr);
        end;

        alphaBuffer := alphaBuffer + rle;
        if (rle and 1) <> 0 then
          Inc(alphaBuffer);
      end;

      src := src + rle;
      dest := dest + rle;
      alphaWindowBuffer := alphaWindowBuffer + rle;
    end;

    src := src + (srcPitch - srcWidth);
    dest := dest + (destPitch - srcWidth);
  end;
end;

procedure fillBuf3x3(src: PByte; srcWidth, srcHeight: Integer; dest: PByte; destWidth, destHeight: Integer);
var
  chunkWidth, chunkHeight: Integer;
  ptr: PByte;
  x, y: Integer;
  middleWidth, middleY: Integer;
  topMiddleX, topMiddleHeight: Integer;
  bottomMiddleX: Integer;
  middleLeftWidth, middleLeftY: Integer;
  middleRightY: Integer;
  topLeftWidth, topLeftHeight: Integer;
  bottomLeftHeight: Integer;
  topRightWidth: Integer;
begin
  chunkWidth := srcWidth div 3;
  chunkHeight := srcHeight div 3;

  // Middle Middle
  ptr := src + srcWidth * chunkHeight + chunkWidth;
  x := 0;
  while x < destWidth do
  begin
    y := 0;
    while y < destHeight do
    begin
      if x + chunkWidth >= destWidth then
        middleWidth := destWidth - x
      else
        middleWidth := chunkWidth;
      middleY := y + chunkHeight;
      if middleY >= destHeight then
        middleY := destHeight;
      buf_to_buf(ptr,
        middleWidth,
        middleY - y,
        srcWidth,
        dest + destWidth * y + x,
        destWidth);
      y := y + chunkHeight;
    end;
    x := x + chunkWidth;
  end;

  // Middle Column
  x := 0;
  while x < destWidth do
  begin
    // Top Middle
    topMiddleX := chunkWidth + x;
    if topMiddleX >= destWidth then
      topMiddleX := destWidth;
    topMiddleHeight := chunkHeight;
    if topMiddleHeight >= destHeight then
      topMiddleHeight := destHeight;
    buf_to_buf(src + chunkWidth,
      topMiddleX - x,
      topMiddleHeight,
      srcWidth,
      dest + x,
      destWidth);

    // Bottom Middle
    bottomMiddleX := chunkWidth + x;
    if bottomMiddleX >= destWidth then
      bottomMiddleX := destWidth;
    buf_to_buf(src + srcWidth * 2 * chunkHeight + chunkWidth,
      bottomMiddleX - x,
      destHeight - (destHeight - chunkHeight),
      srcWidth,
      dest + destWidth * (destHeight - chunkHeight) + x,
      destWidth);
    x := x + chunkWidth;
  end;

  // Middle Row
  y := 0;
  while y < destHeight do
  begin
    // Middle Left
    middleLeftWidth := chunkWidth;
    if middleLeftWidth >= destWidth then
      middleLeftWidth := destWidth;
    middleLeftY := chunkHeight + y;
    if middleLeftY >= destHeight then
      middleLeftY := destHeight;
    buf_to_buf(src + srcWidth * chunkHeight,
      middleLeftWidth,
      middleLeftY - y,
      srcWidth,
      dest + destWidth * y,
      destWidth);

    // Middle Right
    middleRightY := chunkHeight + y;
    if middleRightY >= destHeight then
      middleRightY := destHeight;
    buf_to_buf(src + 2 * chunkWidth + srcWidth * chunkHeight,
      destWidth - (destWidth - chunkWidth),
      middleRightY - y,
      srcWidth,
      dest + destWidth * y + destWidth - chunkWidth,
      destWidth);
    y := y + chunkHeight;
  end;

  // Top Left
  topLeftWidth := chunkWidth;
  if topLeftWidth >= destWidth then
    topLeftWidth := destWidth;
  topLeftHeight := chunkHeight;
  if topLeftHeight >= destHeight then
    topLeftHeight := destHeight;
  buf_to_buf(src,
    topLeftWidth,
    topLeftHeight,
    srcWidth,
    dest,
    destWidth);

  // Bottom Left (originally labeled "Bottom Left" but the C++ code uses src + chunkWidth * 2)
  bottomLeftHeight := chunkHeight;
  if chunkHeight >= destHeight then
    bottomLeftHeight := destHeight;
  buf_to_buf(src + chunkWidth * 2,
    destWidth - (destWidth - chunkWidth),
    bottomLeftHeight,
    srcWidth,
    dest + destWidth - chunkWidth,
    destWidth);

  // Top Right
  topRightWidth := chunkWidth;
  if chunkWidth >= destWidth then
    topRightWidth := destWidth;
  buf_to_buf(src + srcWidth * 2 * chunkHeight,
    topRightWidth,
    destHeight - (destHeight - chunkHeight),
    srcWidth,
    dest + destWidth * (destHeight - chunkHeight),
    destWidth);

  // Bottom Right
  buf_to_buf(src + 2 * chunkWidth + srcWidth * 2 * chunkHeight,
    destWidth - (destWidth - chunkWidth),
    destHeight - (destHeight - chunkHeight),
    srcWidth,
    dest + destWidth * (destHeight - chunkHeight) + (destWidth - chunkWidth),
    destWidth);
end;

function windowEnableCheckRegion: Integer;
begin
  checkRegionEnable_ := 1;
  Result := 1;
end;

function windowDisableCheckRegion: Integer;
begin
  checkRegionEnable_ := 0;
  Result := 1;
end;

function windowSetHoldTime(value: Integer): Integer;
begin
  holdTime := value;
  Result := 1;
end;

function windowAddTextRegion(x, y, width, font: Integer; textAlignment, textFlags, backgroundColor: Integer): Integer;
begin
  if currentWindow = -1 then
  begin
    Result := -1;
    Exit;
  end;

  if windows[currentWindow].window = -1 then
  begin
    Result := -1;
    Exit;
  end;

  Result := win_add_text_region(windows[currentWindow].window,
    x, y, width, font, textAlignment, textFlags, backgroundColor);
end;

function windowPrintTextRegion(textRegionId: Integer; str: PAnsiChar): Integer;
begin
  Result := win_print_text_region(textRegionId, str);
end;

function windowUpdateTextRegion(textRegionId: Integer): Integer;
begin
  Result := win_update_text_region(textRegionId);
end;

function windowDeleteTextRegion(textRegionId: Integer): Integer;
begin
  Result := win_delete_text_region(textRegionId);
end;

function windowTextRegionStyle(textRegionId, font: Integer; textAlignment, textFlags, backgroundColor: Integer): Integer;
begin
  Result := win_text_region_style(textRegionId, font, textAlignment, textFlags, backgroundColor);
end;

function windowAddTextInputRegion(textRegionId: Integer; text: PAnsiChar; a3, a4: Integer): Integer;
begin
  Result := win_add_text_input_region(textRegionId, text, a3, a4);
end;

function windowDeleteTextInputRegion(textInputRegionId: Integer): Integer;
begin
  if textInputRegionId <> -1 then
  begin
    Result := win_delete_text_input_region(textInputRegionId);
    Exit;
  end;

  if currentWindow = -1 then
  begin
    Result := 0;
    Exit;
  end;

  if windows[currentWindow].window = -1 then
  begin
    Result := 0;
    Exit;
  end;

  Result := win_delete_all_text_input_regions(windows[currentWindow].window);
end;

function windowSetTextInputDeleteFunc(textInputRegionId: Integer; deleteFunc: TTextInputRegionDeleteFunc; userData: Pointer): Integer;
begin
  Result := win_set_text_input_delete_func(textInputRegionId, deleteFunc, userData);
end;

end.
