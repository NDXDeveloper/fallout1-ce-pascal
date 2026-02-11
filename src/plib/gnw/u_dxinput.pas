{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/dxinput.h + dxinput.cc
// Input device abstraction (originally DirectInput, now SDL2).
unit u_dxinput;

interface

uses
  u_sdl2;

type
  PMouseData = ^TMouseData;
  TMouseData = record
    X: Integer;
    Y: Integer;
    Buttons: array[0..1] of Byte;
    WheelX: Integer;
    WheelY: Integer;
  end;

  PKeyboardData = ^TKeyboardData;
  TKeyboardData = record
    Key: Integer;
    Down: Byte;
  end;

function dxinput_init: Boolean;
procedure dxinput_exit;
function dxinput_acquire_mouse: Boolean;
function dxinput_unacquire_mouse: Boolean;
function dxinput_get_mouse_state(mouseData: PMouseData): Boolean;
function dxinput_acquire_keyboard: Boolean;
function dxinput_unacquire_keyboard: Boolean;
function dxinput_flush_keyboard_buffer: Boolean;
function dxinput_read_keyboard_buffer(keyboardData: PKeyboardData): Boolean;

procedure handleMouseEvent(event: PSDL_Event);

implementation

var
  gMouseX: Integer = 0;
  gMouseY: Integer = 0;
  gMouseButtons: array[0..1] of Byte;
  gMouseWheelX: Integer = 0;
  gMouseWheelY: Integer = 0;
  gMouseInitialized: Boolean = False;
  gKeyboardInitialized: Boolean = False;

  gKeyboardBuffer: array[0..63] of TKeyboardData;
  gKeyboardBufferReadIndex: Integer = 0;
  gKeyboardBufferWriteIndex: Integer = 0;

function dxinput_init: Boolean;
begin
  if SDL_InitSubSystem(SDL_INIT_EVENTS) <> 0 then
    Exit(False);

  // Initialize mouse with relative mode (SDL_TRUE = 1)
  if SDL_SetRelativeMouseMode(1) <> 0 then
  begin
    SDL_QuitSubSystem(SDL_INIT_EVENTS);
    Exit(False);
  end;

  FillChar(gKeyboardBuffer, SizeOf(gKeyboardBuffer), 0);
  Result := True;
end;

procedure dxinput_exit;
begin
  SDL_QuitSubSystem(SDL_INIT_EVENTS);
end;

function dxinput_acquire_mouse: Boolean;
begin
  gMouseInitialized := True;
  Result := True;
end;

function dxinput_unacquire_mouse: Boolean;
begin
  gMouseInitialized := False;
  Result := True;
end;

function dxinput_get_mouse_state(mouseData: PMouseData): Boolean;
var
  buttons: LongWord;
begin
  if not gMouseInitialized then
    Exit(False);

  // CE: This function is sometimes called outside loops calling `get_input`
  // and subsequently `GNW95_process_message`, so mouse events might not be
  // handled by SDL yet.
  SDL_PumpEvents;

  buttons := SDL_GetRelativeMouseState(@mouseData^.X, @mouseData^.Y);
  if (buttons and SDL_BUTTON(SDL_BUTTON_LEFT)) <> 0 then
    mouseData^.Buttons[0] := 1
  else
    mouseData^.Buttons[0] := 0;
  if (buttons and SDL_BUTTON(SDL_BUTTON_RIGHT)) <> 0 then
    mouseData^.Buttons[1] := 1
  else
    mouseData^.Buttons[1] := 0;
  mouseData^.WheelX := gMouseWheelX;
  mouseData^.WheelY := gMouseWheelY;

  gMouseWheelX := 0;
  gMouseWheelY := 0;

  Result := True;
end;

function dxinput_acquire_keyboard: Boolean;
begin
  gKeyboardInitialized := True;
  Result := True;
end;

function dxinput_unacquire_keyboard: Boolean;
begin
  gKeyboardInitialized := False;
  Result := True;
end;

function dxinput_flush_keyboard_buffer: Boolean;
begin
  gKeyboardBufferReadIndex := 0;
  gKeyboardBufferWriteIndex := 0;
  Result := True;
end;

function dxinput_read_keyboard_buffer(keyboardData: PKeyboardData): Boolean;
begin
  if gKeyboardBufferReadIndex = gKeyboardBufferWriteIndex then
    Exit(False);

  keyboardData^ := gKeyboardBuffer[gKeyboardBufferReadIndex];
  gKeyboardBufferReadIndex := (gKeyboardBufferReadIndex + 1) and 63;
  Result := True;
end;

procedure handleMouseEvent(event: PSDL_Event);
begin
  case event^.type_ of
    SDL_MOUSEMOTION:
    begin
      gMouseX := gMouseX + event^.motion.xrel;
      gMouseY := gMouseY + event^.motion.yrel;
    end;
    SDL_MOUSEBUTTONDOWN:
    begin
      if event^.button.button = 1 then
        gMouseButtons[0] := 1
      else if event^.button.button = 3 then
        gMouseButtons[1] := 1;
    end;
    SDL_MOUSEBUTTONUP:
    begin
      // Button up handled via state in mouse_info
    end;
    SDL_MOUSEWHEEL:
    begin
      gMouseWheelX := gMouseWheelX + event^.wheel.x;
      gMouseWheelY := gMouseWheelY + event^.wheel.y;
    end;
  end;
end;

end.
