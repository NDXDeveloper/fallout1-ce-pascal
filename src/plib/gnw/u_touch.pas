{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/touch.h + touch.cc
// Touch input and gesture recognition system.
unit u_touch;

interface

uses
  u_sdl2;

const
  // GestureType
  GESTURE_UNRECOGNIZED = 0;
  GESTURE_TAP          = 1;
  GESTURE_LONG_PRESS   = 2;
  GESTURE_PAN          = 3;

  // GestureState
  GESTURE_POSSIBLE = 0;
  GESTURE_BEGAN    = 1;
  GESTURE_CHANGED  = 2;
  GESTURE_ENDED    = 3;

type
  PGesture = ^TGesture;
  TGesture = record
    GestureType: Integer;
    State: Integer;
    NumberOfTouches: Integer;
    X: Integer;
    Y: Integer;
  end;

procedure touch_handle_start(event: PSDL_TouchFingerEvent);
procedure touch_handle_move(event: PSDL_TouchFingerEvent);
procedure touch_handle_end(event: PSDL_TouchFingerEvent);
procedure touch_process_gesture;
function touch_get_gesture(gesture: PGesture): Boolean;

implementation

var
  current_gesture: TGesture;
  gesture_available: Boolean = False;

procedure touch_handle_start(event: PSDL_TouchFingerEvent);
begin
  current_gesture.GestureType := GESTURE_TAP;
  current_gesture.State := GESTURE_BEGAN;
  current_gesture.NumberOfTouches := 1;
  current_gesture.X := Trunc(event^.x);
  current_gesture.Y := Trunc(event^.y);
  gesture_available := True;
end;

procedure touch_handle_move(event: PSDL_TouchFingerEvent);
begin
  current_gesture.GestureType := GESTURE_PAN;
  current_gesture.State := GESTURE_CHANGED;
  current_gesture.X := Trunc(event^.x);
  current_gesture.Y := Trunc(event^.y);
  gesture_available := True;
end;

procedure touch_handle_end(event: PSDL_TouchFingerEvent);
begin
  current_gesture.State := GESTURE_ENDED;
  current_gesture.X := Trunc(event^.x);
  current_gesture.Y := Trunc(event^.y);
  gesture_available := True;
end;

procedure touch_process_gesture;
begin
  // TODO: Implement gesture state machine (long press detection, etc.)
end;

function touch_get_gesture(gesture: PGesture): Boolean;
begin
  if gesture_available then
  begin
    gesture^ := current_gesture;
    gesture_available := False;
    Result := True;
  end
  else
    Result := False;
end;

end.
