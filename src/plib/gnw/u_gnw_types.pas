{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/plib/gnw/gnw_types.h
// Core window system types: Window, Button, ButtonGroup, MenuBar.
unit u_gnw_types;

interface

uses
  u_rect;

const
  BUTTON_GROUP_BUTTON_LIST_CAPACITY = 64;

  // WindowFlags
  WINDOW_USE_DEFAULTS  = $01;
  WINDOW_DONT_MOVE_TOP = $02;
  WINDOW_MOVE_ON_TOP   = $04;
  WINDOW_HIDDEN        = $08;
  WINDOW_MODAL         = $10;
  WINDOW_TRANSPARENT   = $20;
  WINDOW_FLAG_0x40     = $40;
  WINDOW_FLAG_0x80     = $80;
  WINDOW_MANAGED       = $100;

  // ButtonFlags
  BUTTON_FLAG_0x01       = $01;
  BUTTON_FLAG_0x02       = $02;
  BUTTON_FLAG_0x04       = $04;
  BUTTON_FLAG_DISABLED   = $08;
  BUTTON_FLAG_0x10       = $10;
  BUTTON_FLAG_TRANSPARENT = $20;
  BUTTON_FLAG_0x40       = $40;
  BUTTON_FLAG_GRAPHIC    = $010000;
  BUTTON_FLAG_CHECKED    = $020000;
  BUTTON_FLAG_RADIO      = $040000;
  BUTTON_FLAG_RIGHT_MOUSE_BUTTON_CONFIGURED = $080000;

type
  PButton = ^TButton;
  PButtonGroup = ^TButtonGroup;

  TWindowBlitProc = procedure(src: PByte; width, height, srcPitch: Integer;
    dest: PByte; destPitch: Integer);

  TButtonCallback = procedure(btn, keyCode: Integer); cdecl;
  PButtonCallback = ^TButtonCallback;

  TRadioButtonCallback = procedure(btn: Integer); cdecl;

  PMenuPulldown = ^TMenuPulldown;
  TMenuPulldown = record
    Rect: TRect;
    KeyCode: Integer;
    ItemsLength: Integer;
    Items: PPAnsiChar;
    ForegroundColor: Integer;
    BackgroundColor: Integer;
  end;

  PMenuBar = ^TMenuBar;
  TMenuBar = record
    Win: Integer;
    Rect: TRect;
    PulldownsLength: Integer;
    Pulldowns: array[0..14] of TMenuPulldown;
    ForegroundColor: Integer;
    BackgroundColor: Integer;
  end;

  PWindow = ^TWindow;
  TWindow = record
    Id: Integer;
    Flags: Integer;
    Rect: TRect;
    Width: Integer;
    Height: Integer;
    Color: Integer;
    Tx: Integer;
    Ty: Integer;
    Buffer: PByte;
    ButtonListHead: PButton;
    HoveredButton: PButton;
    ClickedButton: PButton;
    MenuBar_: PMenuBar;
    BlitProc: TWindowBlitProc;
  end;

  TButton = record
    Id: Integer;
    Flags: Integer;
    Rect: TRect;
    MouseEnterEventCode: Integer;
    MouseExitEventCode: Integer;
    LeftMouseDownEventCode: Integer;
    LeftMouseUpEventCode: Integer;
    RightMouseDownEventCode: Integer;
    RightMouseUpEventCode: Integer;
    NormalImage: PByte;
    PressedImage: PByte;
    HoverImage: PByte;
    DisabledNormalImage: PByte;
    DisabledPressedImage: PByte;
    DisabledHoverImage: PByte;
    CurrentImage: PByte;
    Mask: PByte;
    MouseEnterProc: TButtonCallback;
    MouseExitProc: TButtonCallback;
    LeftMouseDownProc: TButtonCallback;
    LeftMouseUpProc: TButtonCallback;
    RightMouseDownProc: TButtonCallback;
    RightMouseUpProc: TButtonCallback;
    PressSoundFunc: TButtonCallback;
    ReleaseSoundFunc: TButtonCallback;
    ButtonGroup_: PButtonGroup;
    Prev: PButton;
    Next: PButton;
  end;

  TButtonGroup = record
    MaxChecked: Integer;
    CurrChecked: Integer;
    Func: TRadioButtonCallback;
    ButtonsLength: Integer;
    Buttons: array[0..BUTTON_GROUP_BUTTON_LIST_CAPACITY - 1] of PButton;
  end;

implementation

end.
