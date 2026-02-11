{$MODE OBJFPC}{$H+}
// Minimal SDL2 bindings needed by the Fallout-CE Pascal port.
// Only the subset of SDL2 used by the engine is declared here.
unit u_sdl2;

interface

{$IFDEF UNIX}
  {$LINKLIB SDL2}
{$ENDIF}

const
  {$IFDEF WINDOWS}
  SDL2_LIB = 'SDL2.dll';
  {$ELSE}
  SDL2_LIB = 'libSDL2.so';
  {$ENDIF}

const
  // SDL_Init flags
  SDL_INIT_TIMER          = $00000001;
  SDL_INIT_AUDIO          = $00000010;
  SDL_INIT_VIDEO          = $00000020;
  SDL_INIT_JOYSTICK       = $00000200;
  SDL_INIT_HAPTIC         = $00001000;
  SDL_INIT_GAMECONTROLLER = $00002000;
  SDL_INIT_EVENTS         = $00004000;
  SDL_INIT_EVERYTHING     = SDL_INIT_TIMER or SDL_INIT_AUDIO or SDL_INIT_VIDEO
                            or SDL_INIT_EVENTS or SDL_INIT_JOYSTICK
                            or SDL_INIT_HAPTIC or SDL_INIT_GAMECONTROLLER;

  // SDL_WindowFlags
  SDL_WINDOW_FULLSCREEN         = $00000001;
  SDL_WINDOW_OPENGL             = $00000002;
  SDL_WINDOW_SHOWN              = $00000004;
  SDL_WINDOW_HIDDEN             = $00000008;
  SDL_WINDOW_BORDERLESS         = $00000010;
  SDL_WINDOW_RESIZABLE          = $00000020;
  SDL_WINDOW_MINIMIZED          = $00000040;
  SDL_WINDOW_MAXIMIZED          = $00000080;
  SDL_WINDOW_FULLSCREEN_DESKTOP = SDL_WINDOW_FULLSCREEN or $00001000;
  SDL_WINDOW_ALLOW_HIGHDPI      = $00002000;

  SDL_WINDOWPOS_UNDEFINED = $1FFF0000;

  // SDL_RendererFlags
  SDL_RENDERER_SOFTWARE      = $00000001;
  SDL_RENDERER_ACCELERATED   = $00000002;
  SDL_RENDERER_PRESENTVSYNC  = $00000004;
  SDL_RENDERER_TARGETTEXTURE = $00000008;

  // SDL_TextureAccess
  SDL_TEXTUREACCESS_STATIC    = 0;
  SDL_TEXTUREACCESS_STREAMING = 1;
  SDL_TEXTUREACCESS_TARGET    = 2;

  // Pixel formats
  SDL_PIXELFORMAT_RGB888  = $16161804; // SDL_DEFINE_PIXELFORMAT(...)
  SDL_PIXELFORMAT_INDEX8  = $13000001;

  // SDL_EventType
  SDL_QUIT_EVENT            = $100;
  SDL_WINDOWEVENT           = $200;
  SDL_KEYDOWN               = $300;
  SDL_KEYUP                 = $301;
  SDL_TEXTINPUT             = $303;
  SDL_MOUSEMOTION           = $400;
  SDL_MOUSEBUTTONDOWN       = $401;
  SDL_MOUSEBUTTONUP         = $402;
  SDL_MOUSEWHEEL            = $403;
  SDL_FINGERDOWN            = $700;
  SDL_FINGERMOTION          = $701;
  SDL_FINGERUP              = $702;

  // SDL_WindowEventID
  SDL_WINDOWEVENT_SIZE_CHANGED = 6;
  SDL_WINDOWEVENT_FOCUS_GAINED = 12;
  SDL_WINDOWEVENT_FOCUS_LOST   = 13;
  SDL_WINDOWEVENT_EXPOSED      = 3;

  // Scancodes (subset used by engine)
  SDL_NUM_SCANCODES = 512;

  SDL_SCANCODE_A = 4;
  SDL_SCANCODE_B = 5;
  SDL_SCANCODE_C = 6;
  SDL_SCANCODE_D = 7;
  SDL_SCANCODE_E = 8;
  SDL_SCANCODE_F = 9;
  SDL_SCANCODE_G = 10;
  SDL_SCANCODE_H = 11;
  SDL_SCANCODE_I = 12;
  SDL_SCANCODE_J = 13;
  SDL_SCANCODE_K = 14;
  SDL_SCANCODE_L = 15;
  SDL_SCANCODE_M = 16;
  SDL_SCANCODE_N = 17;
  SDL_SCANCODE_O = 18;
  SDL_SCANCODE_P = 19;
  SDL_SCANCODE_Q = 20;
  SDL_SCANCODE_R = 21;
  SDL_SCANCODE_S = 22;
  SDL_SCANCODE_T = 23;
  SDL_SCANCODE_U = 24;
  SDL_SCANCODE_V = 25;
  SDL_SCANCODE_W = 26;
  SDL_SCANCODE_X = 27;
  SDL_SCANCODE_Y = 28;
  SDL_SCANCODE_Z = 29;

  SDL_SCANCODE_1 = 30;
  SDL_SCANCODE_2 = 31;
  SDL_SCANCODE_3 = 32;
  SDL_SCANCODE_4 = 33;
  SDL_SCANCODE_5 = 34;
  SDL_SCANCODE_6 = 35;
  SDL_SCANCODE_7 = 36;
  SDL_SCANCODE_8 = 37;
  SDL_SCANCODE_9 = 38;
  SDL_SCANCODE_0 = 39;

  SDL_SCANCODE_RETURN    = 40;
  SDL_SCANCODE_ESCAPE    = 41;
  SDL_SCANCODE_BACKSPACE = 42;
  SDL_SCANCODE_TAB       = 43;
  SDL_SCANCODE_SPACE     = 44;

  SDL_SCANCODE_MINUS        = 45;
  SDL_SCANCODE_EQUALS       = 46;
  SDL_SCANCODE_LEFTBRACKET  = 47;
  SDL_SCANCODE_RIGHTBRACKET = 48;
  SDL_SCANCODE_BACKSLASH    = 49;
  SDL_SCANCODE_SEMICOLON    = 51;
  SDL_SCANCODE_APOSTROPHE   = 52;
  SDL_SCANCODE_GRAVE        = 53;
  SDL_SCANCODE_COMMA        = 54;
  SDL_SCANCODE_PERIOD       = 55;
  SDL_SCANCODE_SLASH        = 56;

  SDL_SCANCODE_CAPSLOCK = 57;

  SDL_SCANCODE_F1  = 58;
  SDL_SCANCODE_F2  = 59;
  SDL_SCANCODE_F3  = 60;
  SDL_SCANCODE_F4  = 61;
  SDL_SCANCODE_F5  = 62;
  SDL_SCANCODE_F6  = 63;
  SDL_SCANCODE_F7  = 64;
  SDL_SCANCODE_F8  = 65;
  SDL_SCANCODE_F9  = 66;
  SDL_SCANCODE_F10 = 67;
  SDL_SCANCODE_F11 = 68;
  SDL_SCANCODE_F12 = 69;

  SDL_SCANCODE_SCROLLLOCK = 71;
  SDL_SCANCODE_INSERT     = 73;
  SDL_SCANCODE_HOME       = 74;
  SDL_SCANCODE_PAGEUP     = 75;
  SDL_SCANCODE_DELETE     = 76;
  SDL_SCANCODE_END        = 77;
  SDL_SCANCODE_PAGEDOWN   = 78;
  SDL_SCANCODE_RIGHT      = 79;
  SDL_SCANCODE_LEFT       = 80;
  SDL_SCANCODE_DOWN       = 81;
  SDL_SCANCODE_UP         = 82;

  SDL_SCANCODE_NUMLOCKCLEAR = 83;
  SDL_SCANCODE_KP_DIVIDE   = 84;
  SDL_SCANCODE_KP_MULTIPLY = 85;
  SDL_SCANCODE_KP_MINUS    = 86;
  SDL_SCANCODE_KP_PLUS     = 87;
  SDL_SCANCODE_KP_ENTER    = 88;
  SDL_SCANCODE_KP_1        = 89;
  SDL_SCANCODE_KP_2        = 90;
  SDL_SCANCODE_KP_3        = 91;
  SDL_SCANCODE_KP_4        = 92;
  SDL_SCANCODE_KP_5        = 93;
  SDL_SCANCODE_KP_6        = 94;
  SDL_SCANCODE_KP_7        = 95;
  SDL_SCANCODE_KP_8        = 96;
  SDL_SCANCODE_KP_9        = 97;
  SDL_SCANCODE_KP_0        = 98;
  SDL_SCANCODE_KP_PERIOD   = 99;

  SDL_SCANCODE_KP_DECIMAL  = 99;  // same as KP_PERIOD
  SDL_SCANCODE_F13 = 104;
  SDL_SCANCODE_F14 = 105;
  SDL_SCANCODE_F15 = 106;
  SDL_SCANCODE_KP_EQUALS = 103;
  SDL_SCANCODE_KP_COMMA  = 133;
  SDL_SCANCODE_STOP      = 120;
  SDL_SCANCODE_APPLICATION = 101;
  SDL_SCANCODE_PRIOR     = 75;  // alias for SDL_SCANCODE_PAGEUP

  SDL_SCANCODE_LCTRL  = 224;
  SDL_SCANCODE_LSHIFT = 225;
  SDL_SCANCODE_LALT   = 226;
  SDL_SCANCODE_LGUI   = 227;
  SDL_SCANCODE_RCTRL  = 228;
  SDL_SCANCODE_RSHIFT = 229;
  SDL_SCANCODE_RALT   = 230;
  SDL_SCANCODE_RGUI   = 231;

  SDL_PRESSED  = 1;
  SDL_RELEASED = 0;

  // SDL_Keymod constants
  KMOD_CAPS   = $2000;
  KMOD_NUM    = $1000;
  KMOD_SCROLL = $8000;

  // Hint strings
  SDL_HINT_RENDER_DRIVER: PAnsiChar = 'SDL_RENDER_DRIVER';

type
  TSDL_Rect = record
    x, y, w, h: Integer;
  end;
  PSDL_Rect = ^TSDL_Rect;

  TSDL_Color = record
    r, g, b, a: Byte;
  end;
  PSDL_Color = ^TSDL_Color;

  TSDL_Palette = record
    ncolors: Integer;
    colors: PSDL_Color;
    version: LongWord;
    refcount: Integer;
  end;
  PSDL_Palette = ^TSDL_Palette;

  TSDL_PixelFormat = record
    format: LongWord;
    palette: PSDL_Palette;
    BitsPerPixel: Byte;
    BytesPerPixel: Byte;
    padding: array[0..1] of Byte;
    Rmask: LongWord;
    Gmask: LongWord;
    Bmask: LongWord;
    Amask: LongWord;
    Rloss: Byte;
    Gloss: Byte;
    Bloss: Byte;
    Aloss: Byte;
    Rshift: Byte;
    Gshift: Byte;
    Bshift: Byte;
    Ashift: Byte;
    refcount: Integer;
    next: Pointer; // PSDL_PixelFormat
  end;
  PSDL_PixelFormat = ^TSDL_PixelFormat;

  TSDL_Surface = record
    flags: LongWord;
    format: PSDL_PixelFormat;
    w, h: Integer;
    pitch: Integer;
    pixels: Pointer;
    userdata: Pointer;
    locked: Integer;
    list_blitmap: Pointer;
    clip_rect: TSDL_Rect;
    map_: Pointer; // avoid 'map' reserved
    refcount: Integer;
  end;
  PSDL_Surface = ^TSDL_Surface;

  // Opaque types - we only use pointers
  TSDL_Window = record end;
  PSDL_Window = ^TSDL_Window;

  TSDL_Renderer = record end;
  PSDL_Renderer = ^TSDL_Renderer;

  TSDL_Texture = record end;
  PSDL_Texture = ^TSDL_Texture;

  // Event structures
  TSDL_CommonEvent = record
    type_: LongWord;
    timestamp: LongWord;
  end;

  TSDL_WindowEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    event: Byte;
    padding1, padding2, padding3: Byte;
    data1: Integer;
    data2: Integer;
  end;

  TSDL_KeyboardEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    state: Byte;
    repeat_: Byte;
    padding2, padding3: Byte;
    // SDL_Keysym inline
    scancode: Integer;
    sym: Integer;
    mod_: Word;
    unused: LongWord;
  end;

  TSDL_TextInputEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    text: array[0..31] of AnsiChar;
  end;

  TSDL_MouseMotionEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    which: LongWord;
    state: LongWord;
    x, y: Integer;
    xrel, yrel: Integer;
  end;

  TSDL_MouseButtonEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    which: LongWord;
    button: Byte;
    state: Byte;
    clicks: Byte;
    padding1: Byte;
    x, y: Integer;
  end;

  TSDL_MouseWheelEvent = record
    type_: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    which: LongWord;
    x, y: Integer;
    direction: LongWord;
  end;

  TSDL_TouchFingerEvent = record
    type_: LongWord;
    timestamp: LongWord;
    touchId: Int64;
    fingerId: Int64;
    x, y: Single;
    dx, dy: Single;
    pressure: Single;
    windowID: LongWord;
  end;
  PSDL_TouchFingerEvent = ^TSDL_TouchFingerEvent;

  TSDL_QuitEvent = record
    type_: LongWord;
    timestamp: LongWord;
  end;

  TSDL_Event = record
    case Integer of
      0: (type_: LongWord);
      1: (common: TSDL_CommonEvent);
      2: (window: TSDL_WindowEvent);
      3: (key: TSDL_KeyboardEvent);
      4: (text: TSDL_TextInputEvent);
      5: (motion: TSDL_MouseMotionEvent);
      6: (button: TSDL_MouseButtonEvent);
      7: (wheel: TSDL_MouseWheelEvent);
      8: (tfinger: TSDL_TouchFingerEvent);
      9: (quit: TSDL_QuitEvent);
      10: (padding: array[0..55] of Byte);
  end;
  PSDL_Event = ^TSDL_Event;

// Helper inline
function SDL_BITSPERPIXEL(format: LongWord): Integer; inline;

// --- SDL2 function declarations ---

function SDL_Init(flags: LongWord): Integer; cdecl; external SDL2_LIB;
function SDL_InitSubSystem(flags: LongWord): Integer; cdecl; external SDL2_LIB;
procedure SDL_QuitSubSystem(flags: LongWord); cdecl; external SDL2_LIB;
procedure SDL_Quit; cdecl; external SDL2_LIB;

function SDL_CreateWindow(title: PAnsiChar; x, y, w, h: Integer; flags: LongWord): PSDL_Window; cdecl; external SDL2_LIB;
procedure SDL_DestroyWindow(window: PSDL_Window); cdecl; external SDL2_LIB;
procedure SDL_SetWindowTitle(window: PSDL_Window; title: PAnsiChar); cdecl; external SDL2_LIB;

function SDL_CreateRenderer(window: PSDL_Window; index: Integer; flags: LongWord): PSDL_Renderer; cdecl; external SDL2_LIB;
procedure SDL_DestroyRenderer(renderer: PSDL_Renderer); cdecl; external SDL2_LIB;
function SDL_RenderSetLogicalSize(renderer: PSDL_Renderer; w, h: Integer): Integer; cdecl; external SDL2_LIB;
function SDL_RenderClear(renderer: PSDL_Renderer): Integer; cdecl; external SDL2_LIB;
function SDL_RenderCopy(renderer: PSDL_Renderer; texture: PSDL_Texture; srcrect, dstrect: PSDL_Rect): Integer; cdecl; external SDL2_LIB;
procedure SDL_RenderPresent(renderer: PSDL_Renderer); cdecl; external SDL2_LIB;

function SDL_CreateTexture(renderer: PSDL_Renderer; format: LongWord; access, w, h: Integer): PSDL_Texture; cdecl; external SDL2_LIB;
procedure SDL_DestroyTexture(texture: PSDL_Texture); cdecl; external SDL2_LIB;
function SDL_UpdateTexture(texture: PSDL_Texture; rect: PSDL_Rect; pixels: Pointer; pitch: Integer): Integer; cdecl; external SDL2_LIB;
function SDL_QueryTexture(texture: PSDL_Texture; format: PLongWord; access, w, h: PInteger): Integer; cdecl; external SDL2_LIB;

function SDL_CreateRGBSurface(flags: LongWord; width, height, depth: Integer; Rmask, Gmask, Bmask, Amask: LongWord): PSDL_Surface; cdecl; external SDL2_LIB;
function SDL_CreateRGBSurfaceWithFormat(flags: LongWord; width, height, depth: Integer; format: LongWord): PSDL_Surface; cdecl; external SDL2_LIB;
procedure SDL_FreeSurface(surface: PSDL_Surface); cdecl; external SDL2_LIB;
function SDL_SetPaletteColors(palette: PSDL_Palette; colors: PSDL_Color; firstcolor, ncolors: Integer): Integer; cdecl; external SDL2_LIB;

function SDL_BlitSurface(src: PSDL_Surface; srcrect: PSDL_Rect; dst: PSDL_Surface; dstrect: PSDL_Rect): Integer; cdecl; external SDL2_LIB name 'SDL_UpperBlit';

function SDL_SetHint(name, value: PAnsiChar): LongBool; cdecl; external SDL2_LIB;

function SDL_PollEvent(event: PSDL_Event): Integer; cdecl; external SDL2_LIB;
function SDL_PushEvent(event: PSDL_Event): Integer; cdecl; external SDL2_LIB;
procedure SDL_PumpEvents; cdecl; external SDL2_LIB;
procedure SDL_FlushEvents(minType, maxType: LongWord); cdecl; external SDL2_LIB;
function SDL_GetRelativeMouseState(x, y: PInteger): LongWord; cdecl; external SDL2_LIB;
function SDL_SetRelativeMouseMode(enabled: Integer): Integer; cdecl; external SDL2_LIB;  // SDL_bool is 0 or 1

const
  SDL_BUTTON_LEFT   = 1;
  SDL_BUTTON_MIDDLE = 2;
  SDL_BUTTON_RIGHT  = 3;

function SDL_BUTTON(X: Integer): LongWord; inline;

function SDL_GetTicks: LongWord; cdecl; external SDL2_LIB;
procedure SDL_Delay(ms: LongWord); cdecl; external SDL2_LIB;

type
  TSDL_TimerID = Integer;
  TSDL_TimerCallback = function(interval: LongWord; param: Pointer): LongWord; cdecl;

function SDL_AddTimer(interval: LongWord; callback: TSDL_TimerCallback; param: Pointer): TSDL_TimerID; cdecl; external SDL2_LIB;
function SDL_RemoveTimer(id: TSDL_TimerID): LongBool; cdecl; external SDL2_LIB;

function SDL_GetKeyboardState(numkeys: PInteger): PByte; cdecl; external SDL2_LIB;
function SDL_GetModState: Integer; cdecl; external SDL2_LIB;

procedure SDL_StartTextInput; cdecl; external SDL2_LIB;
procedure SDL_StopTextInput; cdecl; external SDL2_LIB;

function SDL_ShowSimpleMessageBox(flags: LongWord; title, message: PAnsiChar; window: PSDL_Window): Integer; cdecl; external SDL2_LIB;

const
  SDL_MESSAGEBOX_ERROR       = $00000010;
  SDL_MESSAGEBOX_WARNING     = $00000020;
  SDL_MESSAGEBOX_INFORMATION = $00000040;

  // Audio format constants
  AUDIO_S8  = $8008;
  AUDIO_S16 = $8010;  // AUDIO_S16LSB / AUDIO_S16SYS on little-endian

  SDL_MIX_MAXVOLUME = 128;

  SDL_AUDIO_ALLOW_FREQUENCY_CHANGE = $00000001;
  SDL_AUDIO_ALLOW_FORMAT_CHANGE    = $00000002;
  SDL_AUDIO_ALLOW_CHANNELS_CHANGE  = $00000004;
  SDL_AUDIO_ALLOW_SAMPLES_CHANGE   = $00000008;
  SDL_AUDIO_ALLOW_ANY_CHANGE       = SDL_AUDIO_ALLOW_FREQUENCY_CHANGE or
                                     SDL_AUDIO_ALLOW_FORMAT_CHANGE or
                                     SDL_AUDIO_ALLOW_CHANNELS_CHANGE or
                                     SDL_AUDIO_ALLOW_SAMPLES_CHANGE;

type
  TSDL_AudioDeviceID = LongWord;
  TSDL_AudioFormat = Word;

  TSDL_AudioCallback = procedure(userdata: Pointer; stream: PByte; len: Integer); cdecl;

  TSDL_AudioSpec = record
    freq: Integer;
    format: TSDL_AudioFormat;
    channels: Byte;
    silence: Byte;
    samples: Word;
    padding: Word;
    size: LongWord;
    callback: TSDL_AudioCallback;
    userdata: Pointer;
  end;
  PSDL_AudioSpec = ^TSDL_AudioSpec;

  // SDL_AudioStream is opaque
  TSDL_AudioStream = record end;
  PSDL_AudioStream = ^TSDL_AudioStream;

function SDL_OpenAudioDevice(const device: PAnsiChar; iscapture: Integer;
  const desired: PSDL_AudioSpec; obtained: PSDL_AudioSpec; allowed_changes: Integer): TSDL_AudioDeviceID; cdecl; external SDL2_LIB;
procedure SDL_CloseAudioDevice(dev: TSDL_AudioDeviceID); cdecl; external SDL2_LIB;
procedure SDL_PauseAudioDevice(dev: TSDL_AudioDeviceID; pause_on: Integer); cdecl; external SDL2_LIB;
function SDL_WasInit(flags: LongWord): LongWord; cdecl; external SDL2_LIB;

function SDL_NewAudioStream(src_format: TSDL_AudioFormat; src_channels: Byte; src_rate: Integer;
  dst_format: TSDL_AudioFormat; dst_channels: Byte; dst_rate: Integer): PSDL_AudioStream; cdecl; external SDL2_LIB;
procedure SDL_FreeAudioStream(stream: PSDL_AudioStream); cdecl; external SDL2_LIB;
function SDL_AudioStreamPut(stream: PSDL_AudioStream; const buf: Pointer; len: Integer): Integer; cdecl; external SDL2_LIB;
function SDL_AudioStreamGet(stream: PSDL_AudioStream; buf: Pointer; len: Integer): Integer; cdecl; external SDL2_LIB;
procedure SDL_MixAudioFormat(dst: PByte; const src: PByte; format: TSDL_AudioFormat; len: LongWord; volume: Integer); cdecl; external SDL2_LIB;

implementation

function SDL_BITSPERPIXEL(format: LongWord): Integer; inline;
begin
  Result := Integer((format shr 8) and $FF);
end;

function SDL_BUTTON(X: Integer): LongWord; inline;
begin
  Result := 1 shl (X - 1);
end;

end.
