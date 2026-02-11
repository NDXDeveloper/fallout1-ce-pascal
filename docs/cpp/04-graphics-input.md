# Fallout 1 CE -- Graphics, Windowing, and Input Systems

This document covers the C++ source code for all graphics rendering, windowing,
button/widget UI, and input handling in Fallout 1 Community Edition. Everything
lives under two main directories: `plib/gnw/` (the low-level "GNW" platform
library) and `int/` (the higher-level interpreter/scripting window system).

All code resides in the `fallout` namespace.

---

## 1. GNW Window Manager (`plib/gnw/gnw.cc` / `gnw.h`)

The GNW window manager is the core windowing system. It manages up to
**50 windows** (`MAX_WINDOW_COUNT`) stored in a flat array `window[]`, with
z-ordering determined by array index (index 0 is the background, higher indices
are on top). A parallel `window_index[]` array maps window IDs to their
position in the window array.

### 1.1 Window Structure

```cpp
struct Window {
    int id;
    int flags;            // WindowFlags bitmask
    Rect rect;            // screen-space position (ulx, uly, lrx, lry)
    int width;
    int height;
    int color;            // fill color or 256 for textured
    int tx, ty;           // texture offset (randomized on creation)
    unsigned char* buffer; // the pixel buffer (width * height bytes, 8-bit indexed)
    Button* buttonListHead;
    Button* hoveredButton;
    Button* clickedButton;
    MenuBar* menuBar;
    WindowBlitProc* blitProc; // defaults to trans_buf_to_buf
};
```

### 1.2 WindowFlags

| Flag                  | Value  | Meaning                                          |
|-----------------------|--------|--------------------------------------------------|
| `WINDOW_USE_DEFAULTS` | 0x01   | Inherit system-level flags set during `win_init`  |
| `WINDOW_DONT_MOVE_TOP`| 0x02   | Do not bring to front on show                    |
| `WINDOW_MOVE_ON_TOP`  | 0x04   | Always on top                                    |
| `WINDOW_HIDDEN`       | 0x08   | Currently hidden                                 |
| `WINDOW_MODAL`        | 0x10   | Exclusive / modal (blocks input to windows below)|
| `WINDOW_TRANSPARENT`  | 0x20   | Uses transparent blitting (blitProc)             |
| `WINDOW_FLAG_0x40`    | 0x40   | Unknown                                          |
| `WINDOW_FLAG_0x80`    | 0x80   | Likely draggable                                 |
| `WINDOW_MANAGED`      | 0x100  | Managed by the INT window system                 |

### 1.3 Initialization and Shutdown

**`win_init(VideoOptions* video_options, int flags) -> int`**

Full system initialization sequence:
1. Initializes the database system (`db_init`) if no databases are open.
2. Initializes text/font subsystem (`GNW_text_init`).
3. Initializes SVGA/SDL2 video (`svga_init`).
4. Optionally allocates a full-screen back buffer (`screen_buffer`) if `flags & 1`.
5. Initializes the color system (`colorInitIO`, `initColors`).
6. Initializes debug output (`GNW_debug_init`).
7. Initializes the input subsystem (`GNW_input_init`).
8. Initializes the interface/dialog subsystem (`GNW_intr_init`).
9. Creates window 0 (the background/desktop window) spanning the full screen.
10. Sets default window colors (`GNW_wcolor[6]`) and registers `win_exit` with `atexit`.

Returns `WINDOW_MANAGER_OK` (0) on success or one of the `WindowManagerErr` codes.

**`win_exit(void)`**

Shuts down everything in reverse order. Deletes all windows, frees the texture
and screen buffer, shuts down SVGA, input, rectangles, text, and colors. Uses
a static `insideWinExit` flag to prevent re-entrant calls.

### 1.4 Window Creation and Deletion

**`win_add(int x, int y, int width, int height, int color, int flags) -> int`**

Creates a new window and returns its integer ID (or -1 on failure). Steps:
1. Allocates a `Window` struct and a `width * height` pixel buffer.
2. Assigns the next available ID by scanning `GNW_find(index)`.
3. If `WINDOW_USE_DEFAULTS` is set, merges in the system-wide `window_flags`.
4. Sets random texture offsets (`tx`, `ty`).
5. Handles color: value 256 means "use texture" (falls back to `GNW_wcolor[0]`
   if no texture loaded); values with `(color & 0xFF00) != 0` index into
   `GNW_wcolor[]`.
6. Default `blitProc` is `trans_buf_to_buf`.
7. Fills the buffer with the window color.
8. Inserts into the window array respecting `WINDOW_MOVE_ON_TOP` ordering.

**`win_delete(int win)`**

Frees the window (buffer, menu bar, all buttons via `GNW_delete_button`),
removes it from the window array, shifts remaining windows down, and refreshes
the vacated screen area.

### 1.5 Visibility and Movement

- **`win_show(int win)`** -- Clears `WINDOW_HIDDEN` flag, moves window toward
  top of z-order (respecting `WINDOW_DONT_MOVE_TOP` and `WINDOW_MOVE_ON_TOP`),
  triggers refresh.
- **`win_hide(int win)`** -- Sets `WINDOW_HIDDEN` flag, refreshes the area.
- **`win_move(int win, int x, int y)`** -- Clamps position to screen bounds,
  applies 4-byte alignment for managed windows (`x &= ~0x03`), refreshes both
  old and new positions.
- **`win_drag(int win)`** -- Shows the window and enters an interactive drag
  loop (processes background tasks and mouse input).

### 1.6 Drawing Primitives

All drawing functions write into a window's pixel buffer. They do NOT
automatically refresh the screen; the caller must call `win_draw` or
`win_draw_rect` afterward.

- **`win_print(win, str, width, x, y, color)`** -- Renders text. If
  `width == 0`, auto-calculates from string. Clears background to window color
  first (unless `color & 0x02000000`). Auto-refreshes if `color & 0x01000000`.
- **`win_text(win, fileNameList, count, maxWidth, x, y, color)`** -- Renders a
  list of strings, drawing separator lines for empty strings.
- **`win_line(win, left, top, right, bottom, color)`** -- Draws a line using
  `draw_line`.
- **`win_box(win, left, top, right, bottom, color)`** -- Draws a rectangle
  outline using `draw_box`.
- **`win_shaded_box(win, ulx, uly, lrx, lry, color1, color2)`** -- Draws a
  3D-effect box with highlight and shadow colors.
- **`win_fill(win, x, y, width, height, color)`** -- Fills a rectangle. Color
  256 uses texture; otherwise fills with solid color.
- **`win_border(win)`** -- Draws the standard GNW window border: lightened
  edges, black outline, and 3D-shaded inner and outer frames using
  `GNW_wcolor[1]` (highlight) and `GNW_wcolor[2]` (shadow).

### 1.7 Screen Refresh and Damage Tracking

The refresh system uses rectangle clipping to avoid overdrawing windows that
are above the target window.

**`win_draw(int win)`** -- Refreshes the entire window area.

**`win_draw_rect(int win, const Rect* rect)`** -- Refreshes a sub-rectangle
(coordinates relative to the window). Internally offsets by `w->rect.ulx/uly`
to convert to screen coordinates.

**`GNW_win_refresh(Window* w, Rect* rect, unsigned char* a3)`**

The core refresh routine. Performs these steps:
1. Skips hidden windows.
2. Allocates a rect node clipped to the intersection of the window rect and
   the requested rect.
3. Calls `win_clip` to subtract all higher-z windows from the rect list (by
   calling `rect_clip_list` for each overlapping window above).
4. For each remaining visible rect fragment:
   - Calls `GNW_button_refresh` to redraw buttons in the area.
   - If `a3` (destination buffer) is provided, blits to that buffer.
   - If `a3` is NULL and `buffering` is true, blits to `screen_buffer`, then
     copies from `screen_buffer` to the screen via `scr_blit`.
   - If `a3` is NULL and `buffering` is false, blits directly to the screen
     via `scr_blit`.
5. For the background window (id 0), fills fragments with `bk_color`.
6. Handles mouse cursor clipping and re-show.

**`win_refresh_all(Rect* rect)`** / **`refresh_all(Rect* rect, unsigned char* a2)`**

Refreshes all windows (from bottom to top) that intersect the given rect. Sets
`doing_refresh_all = 1` during the sweep to prevent recursive transparent
window refreshes.

### 1.8 Utility Functions

- **`GNW_find(int win) -> Window*`** -- Looks up window by ID via
  `window_index[]`. Returns NULL for ID -1 or unregistered IDs.
- **`win_get_buf(int win) -> unsigned char*`** -- Returns the raw pixel buffer.
- **`win_get_top_win(int x, int y) -> int`** -- Returns the top-most window ID
  at screen position (x, y), scanning from highest z-order down.
- **`win_width(int win)`, `win_height(int win)`** -- Dimension queries.
- **`win_get_rect(int win, Rect* rect)`** -- Copies the window's screen rect.
- **`win_check_all_buttons() -> int`** -- Iterates all windows top-to-bottom,
  calling `GNW_check_buttons`. Stops at modal windows.
- **`GNW_find_button(int btn, Window** out) -> Button*`** -- Searches all
  windows for a button by ID.
- **`GNW_check_menu_bars(int keyCode) -> int`** -- Checks if a key matches any
  menu bar pulldown trigger.
- **`win_set_minimized_title(const char* title)`** -- Sets the SDL window title.
- **`win_set_trans_b2b(int id, WindowBlitProc* proc)`** -- Sets a custom
  transparent blit procedure for a window (must have `WINDOW_TRANSPARENT`).
- **`GNWSystemError(const char* text) -> bool`** -- Shows an SDL error message
  box.

### 1.9 Global State

| Variable         | Type              | Description                           |
|------------------|-------------------|---------------------------------------|
| `GNW_win_init_flag` | `bool`         | True when window system is initialized|
| `GNW_wcolor[6]`  | `int[6]`          | System color indices for borders      |
| `GNW_texture`    | `void*`           | Tiled background texture data         |
| `num_windows`    | `int`             | Current number of open windows        |
| `window_flags`   | `int`             | System-wide default flags             |
| `buffering`      | `bool`            | Double-buffering enabled              |
| `screen_buffer`  | `unsigned char*`  | Full-screen back buffer               |
| `bk_color`       | `int`             | Desktop background fill color         |

---

## 2. Graphics Buffer (`plib/gnw/grbuf.cc` / `grbuf.h`)

Low-level buffer operations for 8-bit indexed pixel data. All functions operate
on raw `unsigned char*` buffers with explicit pitch (stride) values.

### 2.1 Line and Box Drawing

**`draw_line(unsigned char* buf, int pitch, int x1, int y1, int x2, int y2, int color)`**

Bresenham-style line drawing using a 4-way symmetric optimization. Special-cases
vertical lines (pointer arithmetic loop) and horizontal lines (`memset`).

**`draw_box(unsigned char* buf, int pitch, int left, int top, int right, int bottom, int color)`**

Draws a rectangle outline by calling `draw_line` four times (top, bottom, left,
right edges).

**`draw_shaded_box(unsigned char* buf, int pitch, int left, int top, int right, int bottom, int ltColor, int rbColor)`**

Draws a 3D-effect box: top and left edges in `ltColor` (highlight), bottom and
right edges in `rbColor` (shadow).

### 2.2 Blitting Operations

**`buf_to_buf(unsigned char* src, int width, int height, int srcPitch, unsigned char* dest, int destPitch)`**

Opaque copy. Internally calls `srcCopy`, which does a row-by-row `memcpy`.

**`trans_buf_to_buf(unsigned char* src, int width, int height, int srcPitch, unsigned char* dest, int destPitch)`**

Transparent copy. Internally calls `transSrcCopy`, which copies pixel-by-pixel,
skipping source pixels with value 0 (the transparent color index). This is the
default `blitProc` for all windows.

**`mask_buf_to_buf(unsigned char* src, int width, int height, int srcPitch, unsigned char* mask, int maskPitch, unsigned char* dest, int destPitch)`**

Masked copy. Only copies source pixels where the corresponding mask pixel is
non-zero.

### 2.3 Scaling Operations

**`cscale(unsigned char* src, int srcWidth, int srcHeight, int srcPitch, unsigned char* dest, int destWidth, int destHeight, int destPitch)`**

Nearest-neighbor upscaling/downscaling using 16.16 fixed-point step values.
Iterates source pixels and fills corresponding destination rectangles.

**`trans_cscale(...)`**

Same as `cscale` but skips source pixels with value 0 (transparent).

### 2.4 Fill and Effects

- **`buf_fill(buf, width, height, pitch, color)`** -- Row-by-row `memset`.
- **`buf_texture(buf, width, height, pitch, texture, tx, ty)`** -- Tiles a
  texture pattern (implementation incomplete in CE).
- **`lighten_buf(buf, width, height, pitch)`** -- Applies a lightening effect
  using `intensityColorTable[pixel][147]`. Used for window border highlights.
- **`swap_color_buf(buf, width, height, pitch, color1, color2)`** -- Swaps two
  palette indices throughout the buffer.
- **`buf_outline(buf, width, height, pitch, color)`** -- Draws an outline
  around non-transparent pixels (scans both horizontally and vertically for
  edges between zero and non-zero pixels).

### 2.5 Raw Copy Functions

- **`srcCopy(dest, destPitch, src, srcPitch, width, height)`** -- Row-by-row
  `memcpy`.
- **`transSrcCopy(dest, destPitch, src, srcPitch, width, height)`** --
  Pixel-by-pixel copy skipping zero (transparent) bytes.

---

## 3. SVGA / SDL2 Video (`plib/gnw/svga.cc` / `svga.h`)

This module wraps SDL2 for display output. The original Fallout used DirectDraw;
the Community Edition replaces it with SDL2.

### 3.1 Global SDL Objects

| Variable              | Type             | Description                         |
|-----------------------|------------------|-------------------------------------|
| `gSdlWindow`         | `SDL_Window*`    | The main application window         |
| `gSdlSurface`        | `SDL_Surface*`   | 8-bit indexed surface (game pixels) |
| `gSdlRenderer`       | `SDL_Renderer*`  | SDL2 hardware renderer              |
| `gSdlTexture`        | `SDL_Texture*`   | RGB888 streaming texture for display|
| `gSdlTextureSurface` | `SDL_Surface*`   | RGB surface matching texture format |
| `sharedFpsLimiter`   | `FpsLimiter`     | Shared frame rate limiter (60 FPS)  |
| `scr_size`           | `Rect`           | Screen dimensions as rect (0,0 to w-1,h-1)|
| `scr_blit`           | `ScreenBlitFunc*`| Function pointer for screen blitting (default: `GNW95_ShowRect`)|

### 3.2 VideoOptions

```cpp
struct VideoOptions {
    int width;      // Default: 640
    int height;     // Default: 480
    bool fullscreen;
    int scale;      // Window size multiplier
};
```

Configured from `fallout.cfg` entries (SCR_WIDTH, SCR_HEIGHT, WINDOWED, etc.)
and passed into `win_init` -> `svga_init`.

### 3.3 Initialization

**`svga_init(VideoOptions* video_options) -> bool`**

1. Sets the SDL render driver hint to "opengl".
2. Initializes `SDL_INIT_VIDEO`.
3. Creates the SDL window with `SDL_WINDOW_OPENGL | SDL_WINDOW_ALLOW_HIGHDPI`.
   If `fullscreen` is set, adds `SDL_WINDOW_FULLSCREEN`. The window pixel size
   is `width * scale` by `height * scale`.
4. Creates the renderer and texture via `createRenderer`:
   - `SDL_CreateRenderer` with default flags.
   - `SDL_RenderSetLogicalSize` to the game resolution.
   - `SDL_CreateTexture` with `SDL_PIXELFORMAT_RGB888` and
     `SDL_TEXTUREACCESS_STREAMING`.
   - Creates `gSdlTextureSurface` matching the texture's pixel format.
5. Creates `gSdlSurface` as an 8-bit (palettized) surface at game resolution.
6. Initializes a grayscale identity palette (index i -> RGB(i, i, i)).
7. Sets `scr_size` to (0, 0, width-1, height-1).
8. Sets `scr_blit` and `mouse_blit` to `GNW95_ShowRect`.

### 3.4 Palette Handling

The game uses 256-color palettized graphics. Palette values are stored as
6-bit components (0-63) and shifted left by 2 to convert to 8-bit RGB.

**`GNW95_SetPalette(unsigned char* palette)`**

Sets all 256 palette entries. Each entry is 3 bytes (R, G, B) at 6-bit
precision. Converts to `SDL_Color` (shifting `<< 2`), calls
`SDL_SetPaletteColors`, then blits the indexed surface to the texture surface
to update the display.

**`GNW95_SetPaletteEntries(unsigned char* palette, int start, int count)`**

Same as above but for a sub-range of palette entries.

### 3.5 Screen Blitting

**`GNW95_ShowRect(unsigned char* src, unsigned int srcPitch, unsigned int a3, unsigned int srcX, unsigned int srcY, unsigned int srcWidth, unsigned int srcHeight, unsigned int destX, unsigned int destY)`**

The default `scr_blit` implementation. Copies from the source buffer to
`gSdlSurface->pixels` using `buf_to_buf`, then blits the affected rectangle
from `gSdlSurface` to `gSdlTextureSurface` using `SDL_BlitSurface` (which
performs the palette-to-RGB conversion).

### 3.6 Presentation

**`renderPresent()`**

Uploads `gSdlTextureSurface` pixels to the GPU texture via
`SDL_UpdateTexture`, clears the renderer, copies the texture, and calls
`SDL_RenderPresent`. This is the final step that makes a frame visible.

### 3.7 Resize Handling

**`handleWindowSizeChanged()`** -- Destroys and recreates the renderer,
texture, and texture surface at the current game resolution. Called from the
`SDL_WINDOWEVENT_SIZE_CHANGED` event handler.

### 3.8 Query Functions

- **`screenGetWidth()`** -- Returns `scr_size.lrx - scr_size.ulx + 1`.
- **`screenGetHeight()`** -- Returns `scr_size.lry - scr_size.uly + 1`.

### 3.9 FpsLimiter

A simple frame rate limiter class (`fps_limiter.h`):

```cpp
class FpsLimiter {
    FpsLimiter(unsigned int fps = 60);
    void mark();       // Record current time
    void throttle();   // Sleep until next frame time
};
```

The global `sharedFpsLimiter` is used by various game loops to cap frame rate.

---

## 4. Button System (`plib/gnw/button.cc` / `button.h`)

The button system provides clickable UI elements within GNW windows. Buttons
are stored as a doubly-linked list on each `Window` struct.

### 4.1 Button Structure

```cpp
struct Button {
    int id;
    int flags;                    // ButtonFlags bitmask
    Rect rect;                    // position within the window
    int mouseEnterEventCode;      // event code pushed when mouse enters
    int mouseExitEventCode;
    int lefMouseDownEventCode;    // (sic -- typo in original)
    int leftMouseUpEventCode;
    int rightMouseDownEventCode;
    int rightMouseUpEventCode;
    unsigned char* normalImage;   // up/normal state graphic
    unsigned char* pressedImage;  // down/pressed state graphic
    unsigned char* hoverImage;    // hover state graphic
    unsigned char* disabledNormalImage;
    unsigned char* disabledPressedImage;
    unsigned char* disabledHoverImage;
    unsigned char* currentImage;  // currently displayed image
    unsigned char* mask;          // optional pixel mask for hit testing
    ButtonCallback* mouseEnterProc;
    ButtonCallback* mouseExitProc;
    ButtonCallback* leftMouseDownProc;
    ButtonCallback* leftMouseUpProc;
    ButtonCallback* rightMouseDownProc;
    ButtonCallback* rightMouseUpProc;
    ButtonCallback* pressSoundFunc;
    ButtonCallback* releaseSoundFunc;
    ButtonGroup* buttonGroup;     // radio button group (or NULL)
    Button* prev;
    Button* next;
};
```

### 4.2 ButtonFlags

| Flag                                       | Value    | Meaning                           |
|--------------------------------------------|----------|-----------------------------------|
| `BUTTON_FLAG_0x01`                         | 0x01     | Unknown                           |
| `BUTTON_FLAG_0x02`                         | 0x02     | Unknown                           |
| `BUTTON_FLAG_0x04`                         | 0x04     | Unknown                           |
| `BUTTON_FLAG_DISABLED`                     | 0x08     | Button is disabled                |
| `BUTTON_FLAG_0x10`                         | 0x10     | Unknown                           |
| `BUTTON_FLAG_TRANSPARENT`                  | 0x20     | Use transparent blitting          |
| `BUTTON_FLAG_GRAPHIC`                      | 0x010000 | Has graphical images              |
| `BUTTON_FLAG_CHECKED`                      | 0x020000 | Currently checked (radio/checkbox)|
| `BUTTON_FLAG_RADIO`                        | 0x040000 | Part of a radio button group      |
| `BUTTON_FLAG_RIGHT_MOUSE_BUTTON_CONFIGURED`| 0x080000 | Right-click handlers registered   |

### 4.3 Button Creation

**`win_register_button(int win, int x, int y, int width, int height, int mouseEnterEventCode, int mouseExitEventCode, int mouseDownEventCode, int mouseUpEventCode, unsigned char* up, unsigned char* dn, unsigned char* hover, int flags) -> int`**

Creates a graphical button. The `up`, `dn`, and `hover` parameters are pixel
buffers for the three visual states (caller-owned). Returns the button ID or -1.

**`win_register_text_button(int win, int x, int y, int mouseEnterEventCode, int mouseExitEventCode, int mouseDownEventCode, int mouseUpEventCode, const char* title, int flags) -> int`**

Creates a text-labeled button with auto-generated 3D-style graphics.

### 4.4 Button Configuration

- **`win_register_button_image(btn, up, down, hover, draw)`** -- Replaces
  button images. If `draw` is true, immediately redraws.
- **`win_register_button_disable(btn, up, down, hover)`** -- Sets disabled
  state images.
- **`win_register_button_func(btn, enterProc, exitProc, downProc, upProc)`** --
  Registers callback functions for mouse events.
- **`win_register_right_button(btn, rightDownCode, rightUpCode, rightDownProc, rightUpProc)`** --
  Configures right-click behavior.
- **`win_register_button_sound_func(btn, pressSoundFunc, releaseSoundFunc)`** --
  Registers sound callbacks for press/release.
- **`win_register_button_mask(btn, mask)`** -- Sets a pixel mask for
  non-rectangular hit testing.

### 4.5 Radio Button Groups

```cpp
struct ButtonGroup {
    int maxChecked;   // max number of simultaneously checked buttons
    int currChecked;  // current number checked
    RadioButtonCallback* func; // called when selection changes
    int buttonsLength;
    Button* buttons[64]; // BUTTON_GROUP_BUTTON_LIST_CAPACITY
};
```

- **`win_group_radio_buttons(int count, int* btns)`** -- Creates a mutually
  exclusive radio group (max 1 checked).
- **`win_group_check_buttons(int count, int* btns, int maxChecked, RadioButtonCallback* func)`** --
  Creates a checkbox group allowing up to `maxChecked` selections.

### 4.6 Button State

- **`win_button_down(int btn) -> bool`** -- Returns true if button is currently
  pressed.
- **`win_enable_button(int btn)`** / **`win_disable_button(int btn)`** -- Toggle
  the `BUTTON_FLAG_DISABLED` flag.
- **`win_set_button_rest_state(int btn, bool checked, int flags)`** -- Sets the
  checked/unchecked rest state.
- **`win_button_press_and_release(int btn)`** -- Simulates a click.

### 4.7 Button Processing

**`GNW_check_buttons(Window* window, int* keyCodePtr) -> int`**

Called each frame by `win_check_all_buttons`. Tests mouse position against all
buttons in the window, handles hover/enter/exit state transitions, fires
callbacks and pushes event codes into the input buffer.

**`GNW_button_refresh(Window* window, Rect* rect)`**

Redraws all buttons in the given area by blitting their `currentImage` into
the window buffer.

---

## 5. Text Rendering (`plib/gnw/text.cc` / `text.h`)

### 5.1 Font System Architecture

The text system uses a pluggable font manager architecture. Up to 10 font
managers (`FONT_MANAGER_MAX`) can be registered, each handling a range of font
numbers.

```cpp
struct FontMgr {
    int low_font_num;
    int high_font_num;
    text_font_func* text_font;
    text_to_buf_func* text_to_buf;
    text_height_func* text_height;
    text_width_func* text_width;
    text_char_width_func* text_char_width;
    text_mono_width_func* text_mono_width;
    text_spacing_func* text_spacing;
    text_size_func* text_size;
    text_max_func* text_max;
};
```

When `text_font(n)` is called, the system finds the appropriate manager for
font number `n` and reassigns all the global function pointers:

```cpp
extern text_to_buf_func* text_to_buf;
extern text_height_func* text_height;
extern text_width_func* text_width;
extern text_char_width_func* text_char_width;
extern text_mono_width_func* text_mono_width;
extern text_spacing_func* text_spacing;
extern text_size_func* text_size;
extern text_max_func* text_max;
```

This indirection allows the game to support both built-in bitmap fonts (fonts
0-9) and external font managers (e.g., for the Fallout game fonts).

### 5.2 Built-in Font Format

Up to 10 bitmap fonts (`TEXT_FONT_MAX`) are loaded from `font0.fon` through
`font9.fon` via the database system.

```cpp
struct Font {
    int num;           // number of glyphs
    int height;        // glyph height in pixels
    int spacing;       // horizontal spacing between characters
    FontInfo* info;    // per-glyph metadata array
    unsigned char* data; // packed 1-bit-per-pixel glyph bitmaps
};

struct FontInfo {
    int width;   // glyph width in pixels
    int offset;  // byte offset into Font.data
};
```

Glyph data is stored as 1-bit-per-pixel bitmaps, packed into bytes
left-to-right, with each row padded to byte boundaries.

### 5.3 Text Rendering Flags

| Flag             | Value    | Effect                                      |
|------------------|----------|---------------------------------------------|
| `FONT_SHADOW`    | 0x10000  | Renders a shadow copy offset by (1,1)       |
| `FONT_UNDERLINE` | 0x20000  | Draws an underline on the last pixel row    |
| `FONT_MONO`      | 0x40000  | Monospaced rendering (all chars same width) |

### 5.4 Key Functions

- **`GNW_text_init() -> int`** -- Loads fonts 0-9, registers the built-in font
  manager, selects the first successfully loaded font.
- **`text_font(int font_num)`** -- Switches the active font.
- **`text_curr() -> int`** -- Returns the current font number.
- **`text_to_buf(buf, str, swidth, fullw, color)`** -- Renders a string into a
  pixel buffer. Supports shadow, underline, and monospace flags. Handles the
  1-bit glyph unpacking inline.
- **`text_width(str) -> int`** -- Calculates the pixel width of a string.
- **`text_height() -> int`** -- Returns the current font height.
- **`text_char_width(c) -> int`** -- Returns the width of a single character.
- **`text_mono_width(str) -> int`** -- Returns `text_max() * strlen(str)`.
- **`text_max() -> int`** -- Returns the width of the widest glyph plus spacing.
- **`text_size(str) -> int`** -- Returns `text_width(str) * text_height()`.
- **`text_add_manager(FontMgrPtr mgr) -> int`** -- Registers a new font manager.
- **`text_remove_manager(int font_num) -> int`** -- Removes the manager that
  handles `font_num`.

---

## 6. Interface Drawing (`plib/gnw/intrface.cc` / `intrface.h`)

Pre-built dialog and menu UI components built on top of the GNW window system.

### 6.1 Dialog Boxes

**`win_list_select(const char* title, char** fileList, int fileListLength, SelectFunc* callback, int x, int y, int color) -> int`**

Displays a scrollable list selection dialog. Returns the selected index or -1.
The `callback` is called when the selection changes, receiving the list and
current index.

**`win_list_select_at(..., int start) -> int`**

Same as above but starts at a specific scroll position.

**`win_get_str(char* dest, int length, const char* title, int x, int y) -> int`**

Displays a text input dialog. Returns 0 on success or -1 on cancel.

**`win_msg(const char* string, int x, int y, int flags) -> int`**

Displays a simple message box with a "Done" button.

**`win_pull_down(char** items, int itemsLength, int x, int y, int color) -> int`**

Displays a pulldown/dropdown menu at the given position. Returns the selected
item index.

### 6.2 Text Input

**`win_input_str(int win, char* dest, int maxLength, int x, int y, int textColor, int backgroundColor) -> int`**

In-window text input with cursor blinking. Handles backspace, character input,
and enter/escape.

### 6.3 Menu Bar System

**`win_register_menu_bar(int win, int x, int y, int width, int height, int fg, int bg) -> int`**

Registers a menu bar on a window. Each window can have at most one menu bar.

```cpp
struct MenuBar {
    int win;
    Rect rect;
    int pulldownsLength;
    MenuPulldown pulldowns[15]; // max 15 pulldown menus
    int foregroundColor;
    int backgroundColor;
};

struct MenuPulldown {
    Rect rect;
    int keyCode;        // keyboard shortcut to activate
    int itemsLength;
    char** items;
    int foregroundColor;
    int backgroundColor;
};
```

**`win_register_menu_pulldown(int win, int x, char* title, int keyCode, int itemsLength, char** items, int fg, int bg) -> int`**

Adds a pulldown to the menu bar with a keyboard shortcut.

**`win_delete_menu_bar(int win)`** -- Removes the menu bar.

**`GNW_process_menu(MenuBar* menuBar, int pulldownIndex) -> int`** --
Internal function that handles menu interaction when a shortcut key is pressed.

### 6.4 Debug Output

**`win_debug(char* string) -> int`**

Displays debug text in a window. This is one of the debug output targets
available via `debug_register_func`.

### 6.5 Configuration

**`win_timed_msg_defaults(unsigned int persistence)`** -- Sets the default
display duration for timed messages.

---

## 7. Input System (`plib/gnw/input.cc` / `input.h`)

The input module is the central event hub, integrating SDL2 events, keyboard,
mouse, touch, background processing, and timing.

### 7.1 Event Ring Buffer

```cpp
struct inputdata {
    int input;  // key code or event code
    int mx;     // mouse X at time of event
    int my;     // mouse Y at time of event
};
```

A ring buffer of 40 entries stores pending input events. `input_put` is the
write index, `input_get` is the read index (-1 when empty).

### 7.2 Main Input Loop

**`get_input() -> int`**

The primary input polling function, called each frame by game code:
1. `GNW95_process_message()` -- Processes all pending SDL events (see below).
2. If the window is not active, enters `GNW95_lost_focus()` (idle loop until
   focus returns).
3. `process_bk()` -- Runs background processes, polls mouse, checks buttons,
   reads keyboard.
4. Dequeues and returns the next event from the ring buffer.
5. Returns -1 if no events, -2 if mouse buttons are held but no event queued.
6. Passes the event through `GNW_check_menu_bars` for menu shortcut handling.

**`GNW95_process_message()`**

Processes the SDL event queue:
- **Mouse events** (`SDL_MOUSEMOTION`, `SDL_MOUSEBUTTONDOWN/UP`,
  `SDL_MOUSEWHEEL`) -> forwarded to `handleMouseEvent`.
- **Touch events** (`SDL_FINGERDOWN/MOTION/UP`) -> forwarded to
  `touch_handle_start/move/end`.
- **Key events** (`SDL_KEYDOWN/UP`) -> if keyboard enabled, maps scancode
  through `GNW95_key_map` (QWERTY normalization), tracks timestamps for repeat,
  sends to `kb_simulate_key`.
- **Window events** -> handles expose (refresh all), resize (recreate renderer),
  focus gain/lost (pause/resume audio).
- **Quit** -> `exit(EXIT_SUCCESS)`.
- After events, calls `touch_process_gesture()`.
- Processes key repeat: for each held key, if enough time has elapsed (initial
  delay `GNW95_repeat_delay` = 500ms, then `GNW95_repeat_rate` = 80ms),
  re-fires the key.

### 7.3 Background Processing

```cpp
struct funcdata {
    unsigned int flags;     // 0x01 = marked for removal
    BackgroundProcess* f;
    funcdata* next;
};
```

Background processes are stored as a singly-linked list.

- **`add_bk_process(BackgroundProcess* f)`** -- Adds a function to the list
  (or un-marks it if already present but flagged for removal).
- **`remove_bk_process(BackgroundProcess* f)`** -- Marks the function for
  removal (lazy deletion).
- **`GNW_do_bk_process()`** -- Iterates the list, executing each non-removed
  function and freeing removed entries. Skipped when game is paused or
  background processing is disabled.
- **`enable_bk()` / `disable_bk()`** -- Toggle background processing.

**`process_bk()`** -- Called by `get_input`. Runs background processes, updates
VCR, polls mouse, checks buttons, reads keyboard.

### 7.4 Timing

All timing uses `SDL_GetTicks()` (milliseconds since SDL init).

- **`get_time() -> unsigned int`** -- Returns `SDL_GetTicks()`.
- **`elapsed_time(unsigned int start) -> unsigned int`** -- Returns
  `SDL_GetTicks() - start` (returns `INT_MAX` on wrap-around).
- **`elapsed_tocks(unsigned int end, unsigned int start) -> unsigned int`** --
  Returns `end - start` (returns `INT_MAX` if `start > end`).
- **`pause_for_tocks(unsigned int ms)`** -- Busy-waits while calling
  `process_bk()`. Game stays responsive.
- **`block_for_tocks(unsigned int ms)`** -- Tight busy-wait, no background
  processing.
- **`get_bk_time() -> unsigned int`** -- Returns the timestamp of the last
  `GNW_do_bk_process` call.

### 7.5 Keyboard Repeat

- **`set_repeat_rate(unsigned int rate)`** / **`get_repeat_rate()`** -- Auto-
  repeat interval (default 80ms).
- **`set_repeat_delay(unsigned int delay)`** / **`get_repeat_delay()`** --
  Initial delay before repeat starts (default 500ms).
- **`GNW95_key_time_stamps[SDL_NUM_SCANCODES]`** -- Tracks press time and
  repeat count for each key.

### 7.6 Focus and Idle Callbacks

- **`set_focus_func(FocusFunc* f)`** / **`get_focus_func()`** -- Called with
  argument 0 on focus loss, 1 on focus gain.
- **`set_idle_func(IdleFunc* f)`** / **`get_idle_func()`** -- Called during
  the lost-focus idle loop. Default implementation: `SDL_Delay(125)`.
- **`GNW95_lost_focus()`** -- Enters a loop calling `GNW95_process_message`
  and `idle_func` until `GNW95_isActive` becomes true again.

### 7.7 Pause and Screen Dump

- **`register_pause(int key, PauseWinFunc* func)`** -- Registers the pause key
  (default `KEY_ALT_P`). The default pause window shows "Paused" with a "Done"
  button.
- **`register_screendump(int key, ScreenDumpFunc* func)`** -- Registers the
  screenshot key (default `KEY_ALT_C`). The default function saves a BMP file
  (`scr00000.bmp` through `scr99999.bmp`).

### 7.8 Text Input Mode

- **`beginTextInput()`** -- Calls `SDL_StartTextInput()`.
- **`endTextInput()`** -- Calls `SDL_StopTextInput()`.

### 7.9 Input Buffer Management

- **`GNW_add_input_buffer(int event)`** -- Enqueues an event (with current
  mouse position). Intercepts pause and screendump keys.
- **`flush_input_buffer()`** -- Clears the ring buffer.

---

## 8. Keyboard (`plib/gnw/kb.cc` / `kb.h`)

### 8.1 Key State Tracking

```cpp
extern unsigned char keys[SDL_NUM_SCANCODES]; // KEY_STATE_UP, KEY_STATE_DOWN, KEY_STATE_REPEAT
extern unsigned char keynumpress;             // count of keys currently pressed
extern int kb_layout;                         // current KeyboardLayout enum
```

Key state constants:

| Constant           | Value | Meaning              |
|--------------------|-------|----------------------|
| `KEY_STATE_UP`     | 0     | Key is released      |
| `KEY_STATE_DOWN`   | 1     | Key is freshly pressed|
| `KEY_STATE_REPEAT` | 2     | Key is auto-repeating|

### 8.2 Modifier Key Tracking

Modifier state is tracked via bitmask constants:

```
KEYBOARD_EVENT_MODIFIER_CAPS_LOCK     = 0x0001
KEYBOARD_EVENT_MODIFIER_NUM_LOCK      = 0x0002
KEYBOARD_EVENT_MODIFIER_SCROLL_LOCK   = 0x0004
KEYBOARD_EVENT_MODIFIER_LEFT_SHIFT    = 0x0008
KEYBOARD_EVENT_MODIFIER_RIGHT_SHIFT   = 0x0010
KEYBOARD_EVENT_MODIFIER_LEFT_ALT      = 0x0020
KEYBOARD_EVENT_MODIFIER_RIGHT_ALT     = 0x0040
KEYBOARD_EVENT_MODIFIER_LEFT_CONTROL  = 0x0080
KEYBOARD_EVENT_MODIFIER_RIGHT_CONTROL = 0x0100
```

Combined masks: `KEYBOARD_EVENT_MODIFIER_ANY_SHIFT`, `_ANY_ALT`, `_ANY_CONTROL`.

### 8.3 Key Code Enum

The `Key` enum defines logical key codes used throughout the game:
- **Printable ASCII**: `KEY_SPACE` (32) through `KEY_TILDE` (126) and `KEY_DEL` (127).
- **Extended characters**: Various accented character codes (136-252) for
  European language support.
- **Alt combinations**: `KEY_ALT_Q` (272) through `KEY_ALT_M` (306).
- **Ctrl combinations**: `KEY_CTRL_Q` (17) through `KEY_CTRL_M` (13) (standard
  ASCII control codes).
- **Function keys**: `KEY_F1` (315) through `KEY_F12` (390), plus Shift/Ctrl/Alt
  variants.
- **Navigation**: `KEY_HOME`, `KEY_END`, `KEY_PAGE_UP`, `KEY_PAGE_DOWN`,
  `KEY_ARROW_UP/DOWN/LEFT/RIGHT`, each with Ctrl and Alt variants.
- **Special**: `KEY_INSERT`, `KEY_DELETE`, `KEY_NUMBERPAD_5`, etc.

### 8.4 Keyboard Layouts

```cpp
enum KeyboardLayout {
    KEYBOARD_LAYOUT_QWERTY,   // 0
    KEYBOARD_LAYOUT_FRENCH,   // 1 (AZERTY)
    KEYBOARD_LAYOUT_GERMAN,   // 2 (QWERTZ)
    KEYBOARD_LAYOUT_ITALIAN,  // 3
    KEYBOARD_LAYOUT_SPANISH,  // 4
};
```

The keyboard layout affects `GNW95_build_key_map()` in `input.cc`, which builds
a translation table `GNW95_key_map[SDL_NUM_SCANCODES]` that remaps physical
scancodes to QWERTY-equivalent scancodes. For example, with French layout, 'A'
scancode maps to `SDL_SCANCODE_Q`, 'Q' maps to `SDL_SCANCODE_A`, 'W' maps to
`SDL_SCANCODE_Z`, 'Z' maps to `SDL_SCANCODE_W`, etc.

### 8.5 Key Functions

- **`GNW_kb_set() -> int`** -- Initializes the keyboard subsystem
  (`dxinput_acquire_keyboard`).
- **`GNW_kb_restore()`** -- Shuts down (`dxinput_unacquire_keyboard`).
- **`kb_getch() -> int`** -- Reads the next key from the internal key queue
  (`KEY_QUEUE_SIZE` = 64). Returns -1 if empty. Applies modifier combinations
  to convert scancodes into the `Key` enum values.
- **`kb_clear()`** -- Clears the key queue and key state arrays.
- **`kb_wait()`** -- Blocks until a key is pressed.
- **`kb_disable()` / `kb_enable()` / `kb_is_disabled()`** -- Toggle keyboard
  input processing.
- **`kb_disable_numpad()` / `kb_enable_numpad()` / `kb_numpad_is_disabled()`**
  -- Toggle numpad input.
- **`kb_disable_numlock()` / `kb_enable_numlock()` / `kb_numlock_is_disabled()`**
  -- Toggle numlock behavior.
- **`kb_set_layout(int layout)` / `kb_get_layout()`** -- Set/get the keyboard
  layout. Triggers a rebuild of the key map.
- **`kb_ascii_to_scan(int ascii) -> int`** -- Converts an ASCII code to a
  scancode.
- **`kb_simulate_key(KeyboardData* data)`** -- Injects a synthetic key event
  into the keyboard processing pipeline (called from `GNW95_process_key` and
  VCR playback).
- **`kb_elapsed_time()` / `kb_reset_elapsed_time()`** -- Track time since last
  key event.

---

## 9. Mouse (`plib/gnw/mouse.cc` / `mouse.h`)

### 9.1 Mouse State Constants

Button state flags:
```
MOUSE_STATE_LEFT_BUTTON_DOWN  = 0x01
MOUSE_STATE_RIGHT_BUTTON_DOWN = 0x02
```

Mouse event flags (from `mouse_get_buttons()`):
```
MOUSE_EVENT_LEFT_BUTTON_DOWN         = 0x01
MOUSE_EVENT_RIGHT_BUTTON_DOWN        = 0x02
MOUSE_EVENT_LEFT_BUTTON_REPEAT       = 0x04
MOUSE_EVENT_RIGHT_BUTTON_REPEAT      = 0x08
MOUSE_EVENT_LEFT_BUTTON_UP           = 0x10
MOUSE_EVENT_RIGHT_BUTTON_UP          = 0x20
MOUSE_EVENT_WHEEL                    = 0x40
```

Combined masks: `MOUSE_EVENT_ANY_BUTTON_DOWN`, `_ANY_BUTTON_REPEAT`,
`_ANY_BUTTON_UP`, `_LEFT_BUTTON_DOWN_REPEAT`, `_RIGHT_BUTTON_DOWN_REPEAT`.

### 9.2 Default Cursor

Default cursor is 8x8 pixels (`MOUSE_DEFAULT_CURSOR_WIDTH/HEIGHT`).

### 9.3 Cursor Management

- **`mouse_show()` / `mouse_hide()`** -- Show/hide the custom cursor. Uses a
  reference-count style (hidden counter incremented/decremented).
- **`mouse_hidden() -> bool`** -- Returns true if cursor is hidden.
- **`mouse_get_shape(buf, width, height, full, hotx, hoty, trans)`** -- Reads
  current cursor shape parameters.
- **`mouse_set_shape(buf, width, height, full, hotx, hoty, trans) -> int`** --
  Sets a new cursor graphic. `full` is the buffer pitch, `hotx`/`hoty` is the
  hotspot, `trans` is the transparent color index.
- **`mouse_set_anim_frames(frames, num_frames, start, width, height, hotx, hoty, trans, speed) -> int`** --
  Sets an animated cursor sequence.
- **`mouse_get_anim(...) -> int`** -- Retrieves current animation parameters.

### 9.4 Position and Buttons

- **`mouse_get_position(int* x, int* y)`** -- Gets current cursor position.
- **`mouse_set_position(int x, int y)`** -- Warps cursor to position.
- **`mouse_get_buttons() -> int`** -- Returns the current button event flags.
- **`mouse_get_raw_state(int* x, int* y, int* buttons)`** -- Returns raw
  position and button state.
- **`mouse_get_hotspot(int* hotx, int* hoty)`** / **`mouse_set_hotspot(hotx, hoty)`**

### 9.5 Hit Testing

- **`mouse_in(int left, int top, int right, int bottom) -> bool`** -- Tests if
  the cursor is within the given rectangle.
- **`mouse_click_in(int left, int top, int right, int bottom) -> bool`** --
  Tests if the last click was within the rectangle.
- **`mouse_get_rect(Rect* rect)`** -- Gets the bounding rectangle of the cursor
  graphic at its current position.

### 9.6 Window-Relative Functions

- **`mouseGetPositionInWindow(int win, int* x, int* y)`** -- Returns mouse
  position relative to a window's top-left corner.
- **`mouseHitTestInWindow(int win, int left, int top, int right, int bottom) -> bool`** --
  Hit test in window-local coordinates.

### 9.7 Mouse Wheel

- **`mouseGetWheel(int* x, int* y)`** -- Returns accumulated wheel delta.
- **`convertMouseWheelToArrowKey(int* keyCodePtr)`** -- Converts wheel events
  into arrow key codes for list scrolling.

### 9.8 Other

- **`mouse_info()`** -- Polls mouse state from the low-level input layer,
  updates position and button events.
- **`mouse_simulate_input(int dx, int dy, int buttons)`** -- Injects synthetic
  mouse movement/clicks.
- **`mouse_set_sensitivity(double value)` / `mouse_get_sensitivity()`** --
  Adjusts mouse movement multiplier.
- **`mouse_disable()` / `mouse_enable()` / `mouse_is_disabled()`** -- Toggle
  mouse processing.
- **`mouse_query_exist() -> bool`** -- Returns true if mouse is available.
- **`mouse_elapsed_time()` / `mouse_reset_elapsed_time()`** -- Track time since
  last mouse event.

### 9.9 Blitting Functions

Two global function pointers control how the cursor is drawn to the screen:

- **`mouse_blit: ScreenBlitFunc*`** -- Opaque blit (default: `GNW95_ShowRect`).
- **`mouse_blit_trans: ScreenTransBlitFunc*`** -- Transparent blit (may be NULL).

`BUTTON_REPEAT_TIME` (250ms) defines the auto-repeat interval for mouse button
held events.

---

## 10. Touch Input (`plib/gnw/touch.cc` / `touch.h`)

Touch support added by the Community Edition for mobile/tablet platforms.

### 10.1 Gesture Types

```cpp
enum GestureType {
    kUnrecognized,
    kTap,
    kLongPress,
    kPan,
};

enum GestureState {
    kPossible,
    kBegan,
    kChanged,
    kEnded,
};

struct Gesture {
    GestureType type;
    GestureState state;
    int numberOfTouches;
    int x;
    int y;
};
```

### 10.2 Functions

- **`touch_handle_start(SDL_TouchFingerEvent* event)`** -- Called on finger down.
- **`touch_handle_move(SDL_TouchFingerEvent* event)`** -- Called on finger
  movement.
- **`touch_handle_end(SDL_TouchFingerEvent* event)`** -- Called on finger up.
- **`touch_process_gesture()`** -- Analyzes accumulated touch data and
  recognizes gestures. Called after processing all SDL events in
  `GNW95_process_message`.
- **`touch_get_gesture(Gesture* gesture) -> bool`** -- Retrieves the most
  recently recognized gesture. Returns true if a gesture is available.

Touch events are integrated into the main event loop in `GNW95_process_message`.

---

## 11. Hardware Input (`plib/gnw/dxinput.cc` / `dxinput.h`)

Despite the "dx" (DirectX) name, the Community Edition implements this using
SDL2. This is the lowest-level input abstraction.

### 11.1 Data Structures

```cpp
struct MouseData {
    int x;
    int y;
    unsigned char buttons[2]; // [0] = left, [1] = right
    int wheelX;
    int wheelY;
};

struct KeyboardData {
    int key;              // SDL scancode
    unsigned char down;   // 1 = pressed, 0 = released
};
```

### 11.2 Functions

- **`dxinput_init() -> bool`** -- Initializes the low-level input system.
- **`dxinput_exit()`** -- Cleans up.
- **`dxinput_acquire_mouse() -> bool`** / **`dxinput_unacquire_mouse() -> bool`**
  -- Start/stop mouse acquisition.
- **`dxinput_get_mouse_state(MouseData* mouseData) -> bool`** -- Reads the
  accumulated mouse deltas and button state since the last call. Returns true
  if data is available.
- **`dxinput_acquire_keyboard() -> bool`** / **`dxinput_unacquire_keyboard() -> bool`**
  -- Start/stop keyboard acquisition.
- **`dxinput_flush_keyboard_buffer() -> bool`** -- Discards pending keyboard
  events.
- **`dxinput_read_keyboard_buffer(KeyboardData* data) -> bool`** -- Reads the
  next keyboard event from the buffer.
- **`handleMouseEvent(SDL_Event* event)`** -- SDL event handler that
  accumulates mouse motion deltas and button presses into an internal
  `MouseData` structure, to be read later by `dxinput_get_mouse_state`.

---

## 12. VCR System (`plib/gnw/vcr.cc` / `vcr.h`)

The VCR (Video Cassette Recorder) system records and plays back input sequences,
used for automated testing and demo playback.

### 12.1 VCR Entry

```cpp
struct VcrEntry {
    unsigned int type;     // VcrEntryType
    unsigned int time;     // timestamp
    unsigned int counter;  // sequence number
    union {
        struct { int mouseX; int mouseY; int keyboardLayout; } initial;
        struct { short key; } keyboardEvent;
        struct { int dx; int dy; int buttons; } mouseEvent;
    };
};
```

Entry types:

| Type                          | Value | Description                     |
|-------------------------------|-------|---------------------------------|
| `VCR_ENTRY_TYPE_NONE`        | 0     | Empty                           |
| `VCR_ENTRY_TYPE_INITIAL_STATE`| 1    | Starting state (mouse pos, layout)|
| `VCR_ENTRY_TYPE_KEYBOARD_EVENT`| 2   | Key press/release               |
| `VCR_ENTRY_TYPE_MOUSE_EVENT` | 3     | Mouse movement/click            |

### 12.2 VCR State

```cpp
extern unsigned int vcr_state;           // VcrState enum value | VCR_STATE_STOP_REQUESTED
extern unsigned int vcr_time;
extern unsigned int vcr_counter;
extern unsigned int vcr_terminate_flags;
extern int vcr_terminated_condition;
extern VcrEntry* vcr_buffer;             // ring buffer, capacity 4096
extern int vcr_buffer_index;
```

States:

| State                  | Value | Description     |
|------------------------|-------|-----------------|
| `VCR_STATE_RECORDING`  | 0     | Recording input |
| `VCR_STATE_PLAYING`    | 1     | Playing back    |
| `VCR_STATE_TURNED_OFF` | 2     | Inactive        |

`VCR_STATE_STOP_REQUESTED` (0x80000000) is OR'd in to signal a pending stop.

### 12.3 Termination Flags

| Flag                             | Value | Effect                           |
|----------------------------------|-------|----------------------------------|
| `VCR_TERMINATE_ON_KEY_PRESS`     | 0x01  | Stop playback on any key press   |
| `VCR_TERMINATE_ON_MOUSE_MOVE`    | 0x02  | Stop playback on mouse movement  |
| `VCR_TERMINATE_ON_MOUSE_PRESS`   | 0x04  | Stop playback on mouse click     |

### 12.4 Functions

- **`vcr_record(const char* fileName) -> bool`** -- Starts recording input to
  a file.
- **`vcr_play(const char* fileName, unsigned int terminationFlags, VcrPlaybackCompletionCallback* callback) -> bool`** --
  Starts playback from a file. The callback is invoked when playback ends, with
  a `VcrPlaybackCompletionReason`.
- **`vcr_stop()`** -- Stops recording or playback.
- **`vcr_status() -> int`** -- Returns current `vcr_state`.
- **`vcr_update() -> int`** -- Called each frame by `process_bk`. During
  playback, feeds recorded events into the input system. Returns 3 to indicate
  playback mode (callers skip `mouse_info` in this case).
- **`vcr_dump_buffer() -> bool`** -- Flushes the record buffer to disk.
- **`vcr_save_record(VcrEntry*, DB_FILE*)`** / **`vcr_load_record(VcrEntry*, DB_FILE*)`** --
  Serialize/deserialize a single VCR entry.

---

## 13. INT Window System (`int/window.cc` / `window.h`)

The INT window system is a higher-level managed window layer used by the game's
scripting system (the "interpreter"). It wraps the GNW window manager with
named windows, a window stack, text formatting, image display, regions, buttons,
and movie playback.

### 13.1 Capacity

`MANAGED_WINDOW_COUNT = 16` -- Maximum number of concurrent managed windows.

### 13.2 Types

```cpp
typedef bool(WindowInputHandler)(int key);
typedef void(WindowDeleteCallback)(int windowIndex, const char* windowName);
typedef void(DisplayInWindowCallback)(int windowIndex, const char* windowName,
                                      unsigned char* data, int width, int height);
typedef void(ManagedButtonMouseEventCallback)(void* userData, int eventType);
typedef void(ManagedWindowCreateCallback)(int windowIndex, const char* windowName, int* flagsPtr);
typedef void(ManagedWindowSelectFunc)(int windowIndex, const char* windowName);

enum TextAlignment { TEXT_ALIGNMENT_LEFT, TEXT_ALIGNMENT_RIGHT, TEXT_ALIGNMENT_CENTER };
```

### 13.3 Window Lifecycle

- **`initWindow(VideoOptions*, int flags)`** -- Initializes the managed window
  system. Calls `win_init`.
- **`windowClose()`** -- Shuts down the managed window system.
- **`createWindow(name, x, y, width, height, a6, flags) -> int`** -- Creates a
  named managed window. Calls `win_add` underneath with `WINDOW_MANAGED` flag.
- **`deleteWindow(const char* name) -> bool`** -- Destroys a named window.
- **`selectWindow(const char* name) -> int`** -- Makes a named window the
  "current" window for subsequent operations.
- **`selectWindowID(int index) -> bool`** -- Selects by index.
- **`pushWindow(const char* name) -> int`** -- Pushes the current window onto
  a stack and selects the named window.
- **`popWindow() -> int`** -- Pops the window stack, restoring the previous
  window.
- **`resizeWindow(name, x, y, width, height) -> int`** -- Resizes a window.
- **`scaleWindow(name, x, y, width, height) -> int`** -- Scales window content.

### 13.4 Window Queries

- **`windowWidth()` / `windowHeight()`** -- Current window dimensions.
- **`windowSX()` / `windowSY()`** -- Current window screen position.
- **`windowGetID()` / `windowGetGNWID()` / `windowGetSpecificGNWID(int idx)`** --
  Get managed index or underlying GNW window ID.
- **`windowGetBuffer() -> unsigned char*`** -- Get pixel buffer.
- **`windowGetName() -> char*`** -- Get current window name.
- **`windowGetDefined(name) -> int`** -- Check if a named window exists.
- **`windowGetRect(Rect*) -> int`** -- Get screen rectangle.
- **`pointInWindow(x, y) -> int`** -- Hit test.
- **`windowGetXres()` / `windowGetYres()`** -- Screen resolution.

### 13.5 Display and Drawing

- **`windowHide()` / `windowShow()`** -- Hide/show current window.
- **`windowDraw()`** -- Refresh current window.
- **`windowDrawRect(left, top, right, bottom)`** -- Refresh sub-area.
- **`windowDrawRectID(winId, left, top, right, bottom)`** -- Refresh by GNW ID.

### 13.6 Text Output

The managed window system maintains text rendering state:
- **`windowGetFont()` / `windowSetFont(int)`** -- Current font.
- **`windowGetTextFlags()` / `windowSetTextFlags(int)`** -- Text flags.
- **`windowGetTextColor()` / `windowSetTextColor(float r, float g, float b)`** --
  Text color (specified as RGB floats 0.0-1.0, converted to palette index).
- **`windowGetHighlightColor()` / `windowSetHighlightColor(float r, float g, float b)`**
- **`windowResetTextAttributes()`** -- Resets all text state to defaults.

Text rendering functions:
- **`windowOutput(char* string) -> int`** -- Prints at the current cursor
  position.
- **`windowGotoXY(int x, int y) -> bool`** -- Sets the text cursor position.
- **`windowPrint(string, a2, x, y, a5) -> bool`** -- Prints at explicit
  position.
- **`windowPrintFont(string, a2, x, y, a5, font) -> int`** -- Prints with a
  specific font.
- **`windowPrintRect(string, a2, textAlignment) -> bool`** -- Prints within a
  rectangle.
- **`windowFormatMessage(string, x, y, width, height, textAlignment) -> bool`**
  -- Formats text to fit within bounds.
- **`windowFormatMessageColor(string, x, y, width, height, textAlignment, flags) -> int`**
- **`windowPrintBuf(win, string, len, width, maxY, x, y, flags, alignment)`** --
  Low-level print to buffer.
- **`windowWrapLine(win, string, width, height, x, y, flags, alignment)`** --
  Word-wrapped text rendering.
- **`windowWrapLineWithSpacing(..., spacing)`** -- Same with custom line
  spacing.
- **`windowWordWrap(string, maxLength, a3, substringListLengthPtr) -> char**`**
  -- Breaks a string into lines. Caller must free with `windowFreeWordList`.

### 13.7 Image Display

- **`windowDisplay(fileName, x, y, width, height) -> bool`** -- Loads and
  displays an image file.
- **`windowDisplayScaled(fileName, x, y, width, height) -> int`** -- Loads and
  displays with scaling.
- **`windowDisplayBuf(src, srcW, srcH, destX, destY, destW, destH) -> bool`** --
  Displays a raw pixel buffer.
- **`windowDisplayTransBuf(...) -> int`** -- Transparent version.
- **`windowDisplayBufScaled(...) -> int`** -- Scaled version.
- **`displayFile(char* fileName)`** / **`displayFileRaw(char* fileName)`** --
  Display an image file (full window or raw).
- **`displayInWindow(data, width, height, pitch)`** -- Display data in current
  window.

### 13.8 Fill Operations

- **`windowFill(float r, float g, float b) -> bool`** -- Fill entire window
  with RGB color.
- **`windowFillRect(x, y, width, height, float r, float g, float b) -> bool`**
  -- Fill rectangle.

### 13.9 Button Management

Managed buttons are referenced by string names rather than integer IDs.

- **`windowAddButton(name, x, y, width, height, flags) -> bool`**
- **`windowAddButtonGfx(name, normalFile, pressedFile, hoverFile) -> bool`** --
  Load button graphics from files.
- **`windowAddButtonBuf(name, normal, pressed, hover, width, height, pitch) -> int`** --
  Set button graphics from buffers.
- **`windowAddButtonMask(name, buffer) -> int`** -- Set hit test mask.
- **`windowAddButtonText(name, text) -> bool`** -- Set button label text.
- **`windowAddButtonTextWithOffsets(name, text, px, py, nx, ny) -> bool`** --
  Set label with state-specific offsets.
- **`windowAddButtonProc(name, program, enterProc, exitProc, downProc, upProc) -> bool`** --
  Attach script procedures.
- **`windowAddButtonRightProc(name, program, downProc, upProc) -> bool`** --
  Attach right-click script procedures.
- **`windowAddButtonCfunc(name, callback, userData) -> bool`** -- Attach C
  callback.
- **`windowAddButtonRightCfunc(name, callback, userData) -> bool`**
- **`windowDeleteButton(const char* name) -> bool`**
- **`windowEnableButton(name, enabled)`**
- **`windowGetButtonID(name) -> int`**
- **`windowSetButtonFlag(name, value) -> bool`**
- **`windowRegisterButtonSoundFunc(pressFunc, releaseFunc, disableFunc)`**

### 13.10 Regions

Regions are polygonal hotspots within managed windows, used for mouse
interaction.

```cpp
struct Region {
    char name[32];
    Point* points;           // polygon vertices
    int minX, minY, maxX, maxY; // bounding box
    int centerX, centerY;
    int pointsLength, pointsCapacity;
    Program* program;        // attached script
    int procs[4];            // mouse event procedure indices
    int rightProcs[4];       // right-click procedure indices
    int flags;
    RegionMouseEventCallback* mouseEventCallback;
    RegionMouseEventCallback* rightMouseEventCallback;
    void* mouseEventCallbackUserData;
    void* rightMouseEventCallbackUserData;
    void* userData;
};
```

- **`windowStartRegion(int initialCapacity) -> bool`** -- Begin defining a
  region.
- **`windowAddRegionPoint(int x, int y, bool a3) -> bool`** -- Add a vertex.
- **`windowAddRegionRect(a1, a2, a3, a4, a5) -> int`** -- Add a rectangular
  region.
- **`windowEndRegion()`** -- Finish defining the region.
- **`windowAddRegionName(const char* name) -> bool`** -- Name the current
  region.
- **`windowAddRegionProc(name, program, a3, a4, a5, a6) -> bool`** -- Attach
  script procedures.
- **`windowAddRegionRightProc(name, program, a3, a4) -> bool`**
- **`windowAddRegionCfunc(name, callback, userData) -> int`** -- Attach C
  callback.
- **`windowAddRegionRightCfunc(name, callback, userData) -> int`**
- **`windowDeleteRegion(const char* name) -> bool`**
- **`windowSetRegionFlag(name, value) -> bool`**
- **`windowCheckRegionExists(name) -> bool`**
- **`windowRegionGetUserData(name) -> void*`** /
  **`windowRegionSetUserData(name, data)`**
- **`windowCheckRegion(windowIndex, mouseX, mouseY, mouseEvent) -> bool`** --
  Test if a mouse event hits any region.
- **`windowRefreshRegions() -> bool`** -- Refresh all regions.
- **`windowActivateRegion(name, a2) -> bool`** -- Activate a named region.
- **`windowEnableCheckRegion()` / `windowDisableCheckRegion()`** -- Toggle
  region checking.

### 13.11 Movie Playback

- **`windowPlayMovie(filePath) -> bool`** -- Start playing a movie in the
  current window.
- **`windowPlayMovieRect(filePath, a2, a3, a4, a5) -> bool`** -- Play in a
  sub-rectangle.
- **`windowStopMovie()`** -- Stop playback.
- **`windowMoviePlaying() -> int`** -- Returns 1 if a movie is playing.
- **`windowSetMovieFlags(int flags) -> bool`**

### 13.12 Drawing Utilities

- **`drawScaled(dest, destW, destH, destPitch, src, srcW, srcH, srcPitch)`** --
  Nearest-neighbor scaling.
- **`drawScaledBuf(dest, destW, destH, src, srcW, srcH)`** -- Same with
  pitch = width.
- **`alphaBltBuf(src, srcW, srcH, srcPitch, a5, a6, dest, destPitch)`** --
  Alpha-blended blit using lookup tables.
- **`fillBuf3x3(src, srcW, srcH, dest, destW, destH)`** -- 9-slice fill using
  a 3x3 source grid.

### 13.13 Callbacks

**`windowSetWindowFuncs(createCb, selectCb, deleteCb, displayCb)`** -- Register
callbacks for window lifecycle events.

**`windowAddInputFunc(WindowInputHandler* handler)`** -- Register a global
input handler.

**`getInput() -> int`** -- INT system input function. Calls `get_input()`,
processes regions and input handlers.

**`updateWindows()`** -- Updates all managed windows (movie playback, etc.).

### 13.14 Hold Time

**`windowSetHoldTime(int value) -> int`** -- Sets the mouse hold duration
threshold for region interactions.

---

## 14. Widgets (`int/widget.cc` / `widget.h`)

Widgets provide reusable UI elements layered on top of managed windows.

### 14.1 Text Regions

Text regions are scrollable text display areas within windows.

- **`win_add_text_region(win, x, y, width, font, textAlignment, textFlags, backgroundColor) -> int`** --
  Creates a text region. Returns region ID.
- **`win_print_text_region(textRegionId, string) -> int`** -- Append text to
  the region.
- **`win_print_substr_region(textRegionId, string, stringLength) -> int`** --
  Append a substring.
- **`win_update_text_region(textRegionId) -> int`** -- Redraw the region.
- **`win_delete_text_region(textRegionId) -> int`** -- Delete the region.
- **`win_delete_all_update_regions(int a1) -> int`** -- Delete all update
  regions.
- **`win_text_region_style(textRegionId, font, alignment, flags, bgColor) -> int`** --
  Change rendering style.
- **`win_center_str(win, string, y, a4) -> int`** -- Center-print a string.

### 14.2 Text Input Regions

- **`win_add_text_input_region(textRegionId, text, a3, a4) -> int`** -- Creates
  an editable text input linked to a text region.
- **`windowSelectTextInputRegion(textInputRegionId)`** -- Give focus to an
  input region.
- **`win_delete_text_input_region(textInputRegionId) -> int`**
- **`win_delete_all_text_input_regions(int win) -> int`**
- **`win_set_text_input_delete_func(textInputRegionId, TextInputRegionDeleteFunc*, userData) -> int`** --
  Register a callback when text is deleted.

### 14.3 Update Regions

Update regions are areas that self-refresh based on custom draw callbacks.

- **`win_register_update(win, x, y, showFunc, drawFunc, value, type, a8) -> int`** --
  Register an auto-updating region. `showFunc` and `drawFunc` are called with
  the `value` pointer.
- **`win_delete_update_region(updateRegionIndex) -> int`**
- **`win_do_updateregions()`** -- Process all registered update regions.

### 14.4 Status Bars

- **`real_win_add_status_bar(win, a2, a3, a4, x, y)`** -- Creates a status bar
  widget.
- **`real_win_update_status_bar(float a1, float a2)`** -- Update progress.
- **`real_win_increment_status_bar(float a1)`** -- Increment progress.
- **`real_win_set_status_bar(int a1, int a2, int a3)`** -- Set status bar
  parameters.
- **`real_win_get_status_info(int a1, int* a2, int* a3, int* a4)`**
- **`real_win_modify_status_info(int a1, int a2, int a3, int a4)`**

### 14.5 Global Widget Functions

- **`draw_widgets() -> int`** -- Draw all widgets.
- **`update_widgets() -> int`** -- Process widget updates.
- **`widgetDoInput() -> int`** -- Process input for active widgets (text input
  regions, etc.).
- **`win_delete_widgets(int win)`** -- Delete all widgets on a window.
- **`initWidgets()` / `widgetsClose()`** -- Initialize/shutdown.

---

## 15. Rectangle Utilities (`plib/gnw/rect.cc` / `rect.h`)

### 15.1 Rect Structure

```cpp
struct Rect {
    int ulx;  // upper-left X
    int uly;  // upper-left Y
    int lrx;  // lower-right X
    int lry;  // lower-right Y
};
```

Coordinates are inclusive: a 640x480 screen has `ulx=0, uly=0, lrx=639, lry=479`.

### 15.2 Rect Linked List

```cpp
struct rectdata {
    Rect rect;
    rectdata* next;
};
typedef rectdata* RectPtr;
```

A free-list pool (`rlist`) pre-allocates nodes in batches of 10. This is used
extensively by the window refresh system for damage tracking.

### 15.3 Functions

**`rect_malloc() -> RectPtr`** -- Allocates a rect node from the free list.
Pre-allocates 10 nodes when the list is empty.

**`rect_free(RectPtr ptr)`** -- Returns a rect node to the free list.

**`rect_clip_list(RectPtr* pCur, Rect* bound)`** -- Clips a linked list of
rectangles against a bounding rectangle. For each rect that overlaps `bound`,
splits it into up to 4 non-overlapping fragments (top strip, left strip, right
strip, bottom strip) and removes the overlapping center portion. This is the
core algorithm for window occlusion during refresh.

**`rect_clip(Rect* b, Rect* t) -> RectPtr`** -- Returns the non-overlapping
fragments of `b` after subtracting `t`.

**`rect_min_bound(const Rect* r1, const Rect* r2, Rect* result)`** -- Computes
the bounding rectangle (union) of two rectangles.

**`rect_inside_bound(const Rect* r1, const Rect* bound, Rect* result) -> int`** --
Computes the intersection of `r1` and `bound`. Returns 0 if they intersect,
-1 if they do not (in which case `result` is a copy of `r1`).

### 15.4 Inline Helper Functions

These are defined in the header and marked with `// TODO: Remove`:

- **`rectCopy(Rect* dest, const Rect* src)`** -- Copies all four fields.
- **`rectGetWidth(const Rect* rect) -> int`** -- Returns `lrx - ulx + 1`.
- **`rectGetHeight(const Rect* rect) -> int`** -- Returns `lry - uly + 1`.
- **`rectOffset(Rect* rect, int dx, int dy)`** -- Translates all four
  coordinates.

### 15.5 Other Types

```cpp
struct Point { int x; int y; };
struct Size { int width; int height; };
```

Both marked `// TODO: Remove` -- they exist for compatibility.

---

## 16. Memory Management (`plib/gnw/memory.cc` / `memory.h`)

A debug-instrumented memory allocator that wraps `malloc`/`realloc`/`free` with
guard values, usage tracking, and pluggable function pointers.

### 16.1 Block Layout

Each allocation has a header and footer:

```
[MemoryBlockHeader: size (size_t) + guard (0xFEEDFACE)]
[user data, padded to sizeof(int) boundary]
[MemoryBlockFooter: guard (0xBEEFCAFE)]
```

### 16.2 Tracking

The allocator tracks:
- `num_blocks` -- Current number of live allocations.
- `max_blocks` -- High-water mark for block count.
- `mem_allocated` -- Current total bytes allocated (including headers/footers).
- `max_allocated` -- High-water mark for total bytes.

### 16.3 Functions

- **`mem_malloc(size_t size) -> void*`** -- Allocates memory. Adds header/footer
  guards, updates counters.
- **`mem_realloc(void* ptr, size_t size) -> void*`** -- Reallocates. Validates
  guards on the old block. If `ptr` is NULL, behaves like `mem_malloc`.
- **`mem_free(void* ptr)`** -- Frees memory. Validates guards, updates counters.
- **`mem_strdup(const char* string) -> char*`** -- Duplicates a string using
  `mem_malloc`.
- **`mem_check()`** -- Prints current and peak memory usage via `debug_printf`.
- **`mem_register_func(MallocFunc*, ReallocFunc*, FreeFunc*)`** -- Replaces the
  allocator functions. Only works before `win_init` (`GNW_win_init_flag` must
  be false).

### 16.4 Guard Validation

On every `mem_realloc` and `mem_free`, the system checks both the header guard
(`0xFEEDFACE`) and footer guard (`0xBEEFCAFE`). If either is corrupted,
`debug_printf` reports "Memory header stomped" or "Memory footer stomped".
This catches buffer overflows and use-after-free in debug builds.

---

## 17. Debug System (`plib/gnw/debug.cc` / `debug.h`)

### 17.1 Output Targets

The debug system supports multiple output backends, selected by setting the
global `debug_func` function pointer:

| Target          | Function              | Description                          |
|-----------------|-----------------------|--------------------------------------|
| Mono            | `debug_mono`          | Direct VGA text-mode memory (0xB0000)|
| Log file        | `debug_log`           | Writes to a file via `fprintf`       |
| Screen (stdout) | `debug_screen`        | Prints to `stdout` via `printf`      |
| GNW window      | `win_debug`           | Displays in a GNW debug window       |
| Custom          | user-provided         | Any function matching `DebugFunc`    |

### 17.2 Registration Functions

- **`GNW_debug_init()`** -- Registers `debug_exit` with `atexit`.
- **`debug_register_mono()`** -- Switch to monochrome VGA output.
- **`debug_register_log(const char* fileName, const char* mode)`** -- Switch to
  file logging.
- **`debug_register_screen()`** -- Switch to stdout output.
- **`debug_register_env()`** -- Reads the `DEBUGACTIVE` environment variable
  and selects the appropriate target: "mono", "log" (writes `debug.log`),
  "screen", or "gnw".
- **`debug_register_func(DebugFunc* func)`** -- Register a custom output
  function.

### 17.3 Output Functions

- **`debug_printf(const char* format, ...) -> int`** -- Formatted output (like
  `printf`). Uses a 260-byte stack buffer. If no debug function is registered,
  falls back to `SDL_LogMessageV` in debug builds.
- **`debug_puts(char* string) -> int`** -- Unformatted string output.
- **`debug_clear()`** -- Clears the mono/screen display.

---

## Appendix A: Initialization Call Chain

```
main / WinMain
  -> win_set_minimized_title(title)
  -> win_init(video_options, flags)
       -> db_init (if needed)
       -> GNW_text_init
            -> load_font (0-9)
            -> text_add_manager
            -> text_font(first_found)
       -> svga_init
            -> SDL_InitSubSystem(SDL_INIT_VIDEO)
            -> SDL_CreateWindow
            -> createRenderer (SDL_CreateRenderer, SDL_CreateTexture)
            -> SDL_CreateRGBSurface (8-bit indexed)
       -> (allocate screen_buffer if buffering)
       -> colorInitIO / initColors
       -> GNW_debug_init
       -> GNW_input_init
            -> dxinput_init
            -> GNW_kb_set
            -> GNW_mouse_init
            -> GNW95_input_init
            -> GNW95_build_key_map
       -> GNW_intr_init
       -> (create background window 0)
```

## Appendix B: Main Loop Data Flow

```
Game Loop:
  get_input()
    -> GNW95_process_message()      [poll SDL events, feed keyboard/mouse/touch]
    -> GNW95_lost_focus() if needed [idle loop until re-focused]
    -> process_bk()
         -> GNW_do_bk_process()     [run background process list]
         -> vcr_update()            [playback VCR if active]
         -> mouse_info()            [poll mouse state]
         -> win_check_all_buttons() [check all buttons in all windows]
         -> kb_getch()              [read keyboard queue]
    -> get_input_buffer()           [dequeue from ring buffer]
    -> GNW_check_menu_bars()        [check menu bar shortcuts]
    -> return event code
```

## Appendix C: Rendering Pipeline

```
Game code writes to window buffer:
  win_fill / win_print / win_line / etc.
    -> modify window->buffer directly

Commit to screen:
  win_draw(win) / win_draw_rect(win, rect)
    -> GNW_win_refresh(window, rect, NULL)
         -> rect_malloc / rect_clip_list  [clip against overlapping windows]
         -> GNW_button_refresh            [redraw buttons in area]
         -> buf_to_buf / blitProc         [copy to screen_buffer or screen]
         -> scr_blit (= GNW95_ShowRect)
              -> buf_to_buf to gSdlSurface->pixels
              -> SDL_BlitSurface to gSdlTextureSurface

Present frame:
  renderPresent()
    -> SDL_UpdateTexture   [upload gSdlTextureSurface to GPU]
    -> SDL_RenderClear
    -> SDL_RenderCopy
    -> SDL_RenderPresent   [swap buffers]
```
