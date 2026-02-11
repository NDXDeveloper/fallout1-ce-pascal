{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/svga.h + svga.cc
// SDL2-based video subsystem: window, renderer, surface, palette management.
unit u_svga;

interface

uses
  u_sdl2, u_rect, u_svga_types, u_fps_limiter;

var
  scr_size: TRect;
  scr_blit: TScreenBlitFunc;

  gSdlWindow: PSDL_Window = nil;
  gSdlSurface: PSDL_Surface = nil;
  gSdlRenderer: PSDL_Renderer = nil;
  gSdlTexture: PSDL_Texture = nil;
  gSdlTextureSurface: PSDL_Surface = nil;
  sharedFpsLimiter: TFpsLimiter = nil;

procedure GNW95_SetPaletteEntries(palette: PByte; start, count: Integer); cdecl;
procedure GNW95_SetPalette(palette: PByte);
procedure GNW95_ShowRect(src: PByte; srcPitch, a3, srcX, srcY,
  srcWidth, srcHeight, destX, destY: LongWord); cdecl;
function svga_init(video_options: PVideoOptions): Boolean;
procedure svga_exit;
function screenGetWidth: Integer;
function screenGetHeight: Integer;
procedure handleWindowSizeChanged;
procedure renderPresent;

implementation

uses
  u_grbuf, u_winmain, u_mouse;

function createRenderer(width, height: Integer): Boolean; forward;
procedure destroyRenderer; forward;

procedure GNW95_SetPaletteEntries(palette: PByte; start, count: Integer); cdecl;
var
  colors: array[0..255] of TSDL_Color;
  index: Integer;
begin
  if (gSdlSurface <> nil) and (gSdlSurface^.format <> nil) and
     (gSdlSurface^.format^.palette <> nil) then
  begin
    if count <> 0 then
    begin
      for index := 0 to count - 1 do
      begin
        colors[index].r := palette[index * 3] shl 2;
        colors[index].g := palette[index * 3 + 1] shl 2;
        colors[index].b := palette[index * 3 + 2] shl 2;
        colors[index].a := 255;
      end;
    end;
    SDL_SetPaletteColors(gSdlSurface^.format^.palette, @colors[0], start, count);
    SDL_BlitSurface(gSdlSurface, nil, gSdlTextureSurface, nil);
  end;
end;

procedure GNW95_SetPalette(palette: PByte);
var
  colors: array[0..255] of TSDL_Color;
  index: Integer;
begin
  if (gSdlSurface <> nil) and (gSdlSurface^.format <> nil) and
     (gSdlSurface^.format^.palette <> nil) then
  begin
    for index := 0 to 255 do
    begin
      colors[index].r := palette[index * 3] shl 2;
      colors[index].g := palette[index * 3 + 1] shl 2;
      colors[index].b := palette[index * 3 + 2] shl 2;
      colors[index].a := 255;
    end;
    SDL_SetPaletteColors(gSdlSurface^.format^.palette, @colors[0], 0, 256);
    SDL_BlitSurface(gSdlSurface, nil, gSdlTextureSurface, nil);
  end;
end;

procedure GNW95_ShowRect(src: PByte; srcPitch, a3, srcX, srcY,
  srcWidth, srcHeight, destX, destY: LongWord); cdecl;
var
  srcRect, destRect: TSDL_Rect;
begin
  buf_to_buf(
    src + srcPitch * srcY + srcX,
    srcWidth, srcHeight, srcPitch,
    PByte(gSdlSurface^.pixels) + LongWord(gSdlSurface^.pitch) * destY + destX,
    gSdlSurface^.pitch);

  srcRect.x := Integer(destX);
  srcRect.y := Integer(destY);
  srcRect.w := Integer(srcWidth);
  srcRect.h := Integer(srcHeight);

  destRect.x := Integer(destX);
  destRect.y := Integer(destY);
  destRect.w := Integer(srcWidth);
  destRect.h := Integer(srcHeight);

  SDL_BlitSurface(gSdlSurface, @srcRect, gSdlTextureSurface, @destRect);
end;

function svga_init(video_options: PVideoOptions): Boolean;
var
  windowFlags: LongWord;
  colors: array[0..255] of TSDL_Color;
  index: Integer;
begin
  SDL_SetHint(SDL_HINT_RENDER_DRIVER, 'opengl');

  if SDL_InitSubSystem(SDL_INIT_VIDEO) <> 0 then
    Exit(False);

  windowFlags := SDL_WINDOW_OPENGL or SDL_WINDOW_ALLOW_HIGHDPI;

  if video_options^.Fullscreen then
    windowFlags := windowFlags or SDL_WINDOW_FULLSCREEN;

  gSdlWindow := SDL_CreateWindow(
    GNW95_title,
    SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
    video_options^.Width * video_options^.Scale,
    video_options^.Height * video_options^.Scale,
    windowFlags);
  if gSdlWindow = nil then
    Exit(False);

  if not createRenderer(video_options^.Width, video_options^.Height) then
  begin
    destroyRenderer;
    SDL_DestroyWindow(gSdlWindow);
    gSdlWindow := nil;
    Exit(False);
  end;

  gSdlSurface := SDL_CreateRGBSurface(0,
    video_options^.Width, video_options^.Height,
    8, 0, 0, 0, 0);
  if gSdlSurface = nil then
  begin
    destroyRenderer;
    SDL_DestroyWindow(gSdlWindow);
    gSdlWindow := nil;
    Exit(False);
  end;

  for index := 0 to 255 do
  begin
    colors[index].r := Byte(index);
    colors[index].g := Byte(index);
    colors[index].b := Byte(index);
    colors[index].a := 255;
  end;
  SDL_SetPaletteColors(gSdlSurface^.format^.palette, @colors[0], 0, 256);

  scr_size.ulx := 0;
  scr_size.uly := 0;
  scr_size.lrx := video_options^.Width - 1;
  scr_size.lry := video_options^.Height - 1;

  mouse_blit_trans := nil;
  scr_blit := @GNW95_ShowRect;
  mouse_blit := @GNW95_ShowRect;

  Result := True;
end;

procedure svga_exit;
begin
  destroyRenderer;

  if gSdlSurface <> nil then
  begin
    SDL_FreeSurface(gSdlSurface);
    gSdlSurface := nil;
  end;

  if gSdlWindow <> nil then
  begin
    SDL_DestroyWindow(gSdlWindow);
    gSdlWindow := nil;
  end;

  SDL_QuitSubSystem(SDL_INIT_VIDEO);
end;

function screenGetWidth: Integer;
begin
  Result := rectGetWidth(@scr_size);
end;

function screenGetHeight: Integer;
begin
  Result := rectGetHeight(@scr_size);
end;

function createRenderer(width, height: Integer): Boolean;
var
  format: LongWord;
begin
  gSdlRenderer := SDL_CreateRenderer(gSdlWindow, -1, 0);
  if gSdlRenderer = nil then
    Exit(False);

  if SDL_RenderSetLogicalSize(gSdlRenderer, width, height) <> 0 then
    Exit(False);

  gSdlTexture := SDL_CreateTexture(gSdlRenderer,
    SDL_PIXELFORMAT_RGB888, SDL_TEXTUREACCESS_STREAMING,
    width, height);
  if gSdlTexture = nil then
    Exit(False);

  format := 0;
  if SDL_QueryTexture(gSdlTexture, @format, nil, nil, nil) <> 0 then
    Exit(False);

  gSdlTextureSurface := SDL_CreateRGBSurfaceWithFormat(0,
    width, height, SDL_BITSPERPIXEL(format), format);
  if gSdlTextureSurface = nil then
    Exit(False);

  Result := True;
end;

procedure destroyRenderer;
begin
  if gSdlTextureSurface <> nil then
  begin
    SDL_FreeSurface(gSdlTextureSurface);
    gSdlTextureSurface := nil;
  end;

  if gSdlTexture <> nil then
  begin
    SDL_DestroyTexture(gSdlTexture);
    gSdlTexture := nil;
  end;

  if gSdlRenderer <> nil then
  begin
    SDL_DestroyRenderer(gSdlRenderer);
    gSdlRenderer := nil;
  end;
end;

procedure handleWindowSizeChanged;
begin
  destroyRenderer;
  createRenderer(screenGetWidth, screenGetHeight);
end;

procedure renderPresent;
begin
  SDL_UpdateTexture(gSdlTexture, nil, gSdlTextureSurface^.pixels, gSdlTextureSurface^.pitch);
  SDL_RenderClear(gSdlRenderer);
  SDL_RenderCopy(gSdlRenderer, gSdlTexture, nil, nil);
  SDL_RenderPresent(gSdlRenderer);
end;

initialization
  sharedFpsLimiter := TFpsLimiter.Create(60);

finalization
  sharedFpsLimiter.Free;

end.
