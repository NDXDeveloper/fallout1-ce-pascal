{$MODE OBJFPC}{$H+}
// Converted from: src/int/movie.cc / src/int/movie.h
// Script interpreter movie playback module.
// This is the high-level movie controller (NOT movie_lib).
unit u_int_movie;

interface

uses
  u_rect;

const
  // MovieFlags
  MOVIE_FLAG_0x01 = $01;
  MOVIE_FLAG_0x02 = $02;
  MOVIE_FLAG_0x04 = $04;
  MOVIE_FLAG_0x08 = $08;

  // MovieExtendedFlags
  MOVIE_EXTENDED_FLAG_0x01 = $01;
  MOVIE_EXTENDED_FLAG_0x02 = $02;
  MOVIE_EXTENDED_FLAG_0x04 = $04;
  MOVIE_EXTENDED_FLAG_0x08 = $08;
  MOVIE_EXTENDED_FLAG_0x10 = $10;

type
  TMovieSubtitleFunc = function(movieFilePath: PAnsiChar): PAnsiChar; cdecl;
  TMoviePaletteFunc = procedure(palette: PByte; start, end_: Integer); cdecl;
  TMovieUpdateCallbackProc = procedure(frame: Integer); cdecl;
  TMovieFrameGrabProc = procedure(data: PByte; width, height, pitch: Integer); cdecl;
  TMovieCaptureFrameProc = procedure(data: PByte; width, height, pitch,
    movieX_, movieY_, movieWidth, movieHeight: Integer); cdecl;
  TMoviePreDrawFunc = procedure(win: Integer; rect: PRect); cdecl;
  TMovieStartFunc = procedure(win: Integer); cdecl;
  TMovieEndFunc = procedure(win, x, y, width, height: Integer); cdecl;
  TMovieFailedOpenFunc = function(path: PAnsiChar): Integer; cdecl;

  TMovieCallback = procedure; cdecl;
  TMovieBlitFunc = function(win: Integer; data: PByte; width, height,
    pitch: Integer): Integer;

  PMovieSubtitleListNode = ^TMovieSubtitleListNode;
  TMovieSubtitleListNode = record
    num: Integer;
    text: PAnsiChar;
    next: PMovieSubtitleListNode;
  end;

procedure movieSetPreDrawFunc(func: TMoviePreDrawFunc);
procedure movieSetFailedOpenFunc(func: TMovieFailedOpenFunc);
procedure movieSetFunc(startFunc: TMovieStartFunc; endFunc: TMovieEndFunc);
procedure movieSetFrameGrabFunc(func: TMovieFrameGrabProc);
procedure movieSetCaptureFrameFunc(func: TMovieCaptureFrameProc);
procedure initMovie;
procedure movieClose;
procedure movieStop;
function movieSetFlags(flags: Integer): Integer;
procedure movieSetSubtitleFont(font: Integer);
procedure movieSetSubtitleColor(r, g, b: Single);
procedure movieSetPaletteFunc(func: TMoviePaletteFunc);
procedure movieSetCallback(func: TMovieUpdateCallbackProc);
function movieRun(win: Integer; filePath: PAnsiChar): Integer;
function movieRunRect(win: Integer; filePath: PAnsiChar;
  a3, a4, a5, a6: Integer): Integer;
procedure movieSetSubtitleFunc(func: TMovieSubtitleFunc);
procedure movieSetVolume(volume: Integer);
procedure movieUpdate;
function moviePlaying: Integer;

implementation

uses
  SysUtils, u_sdl2, u_db, u_debug, u_memdbg, u_int_sound, u_gnw,
  u_grbuf, u_text, u_color, u_svga, u_platform_compat, u_input,
  u_int_window, u_movie_lib;

// ===== SDL2 functions not yet in u_sdl2 =====
function SDL_LockSurface(surface: PSDL_Surface): Integer;
  cdecl; external SDL2_LIB;
procedure SDL_UnlockSurface(surface: PSDL_Surface);
  cdecl; external SDL2_LIB;
function SDL_SetSurfacePalette(surface: PSDL_Surface;
  palette: PSDL_Palette): Integer; cdecl; external SDL2_LIB;

const
  TEXT_ALIGNMENT_CENTER = 1;

// ===== Forward declarations =====
function movieMalloc(size: SizeUInt): Pointer; cdecl; forward;
procedure movieFree(ptr: Pointer); cdecl; forward;
function movieRead(ahandle: Pointer; buf: Pointer;
  count: Integer): Boolean; cdecl; forward;
procedure movie_MVE_ShowFrame(surface: PSDL_Surface;
  srcWidth, srcHeight, srcX, srcY, destWidth, destHeight,
  a8, a9: Integer); cdecl; forward;
procedure movieShowFrame(a1: PSDL_Surface;
  a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl; forward;
function movieScaleSubRect(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
function movieScaleWindowAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
function movieScaleSubRectAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
function blitAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
function movieScaleWindow(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
function blitNormal(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer; forward;
procedure movieSetPalette_internal(palette: PByte;
  start, end_: Integer); cdecl; forward;
function noop: Integer; forward;
procedure cleanupMovie(a1: Integer); forward;
procedure cleanupLast; forward;
function openFile(filePath: PAnsiChar): PDB_FILE; forward;
procedure openSubtitle(filePath: PAnsiChar); forward;
procedure doSubtitle; forward;
function movieStart(win: Integer; filePath: PAnsiChar;
  a3: Pointer): Integer; forward;
function localMovieCallback: Boolean; forward;
function stepMovie_internal: Integer; forward;

// ===== Module-level variables (C++ static) =====
var
  // 0x505B30
  GNWWin: Integer = -1;

  // 0x505B34
  subtitleFont: Integer = -1;

  // 0x505B38
  showFrameFuncs: array[0..1, 0..1, 0..1] of TMovieBlitFunc;

  // 0x505B58
  paletteFunc: TMoviePaletteFunc;

  // 0x505B5C
  subtitleR: Integer = 31;

  // 0x505B60
  subtitleG: Integer = 31;

  // 0x505B64
  subtitleB: Integer = 31;

  // 0x637370
  winRect: TRect;

  // 0x637380
  movieRect: TRect;

  // 0x637390
  movieCallback_: TMovieCallback = nil;

  // 0x6373A0
  endMovieFunc: TMovieEndFunc;

  // 0x637394
  updateCallbackFunc: TMovieUpdateCallbackProc;

  // 0x6373C0
  failedOpenFunc: TMovieFailedOpenFunc;

  // 0x6373D4
  subtitleFilenameFunc: TMovieSubtitleFunc;

  // 0x6373DC
  startMovieFunc: TMovieStartFunc;

  // 0x6373E4
  subtitleW: Integer;

  // 0x637398
  lastMovieBH: Integer;

  // 0x63739C
  lastMovieBW: Integer;

  // 0x6373A4
  lastMovieSX: Integer;

  // 0x6373A8
  lastMovieSY: Integer;

  // 0x6373AC
  movieScaleFlag: Integer;

  // 0x6373B0
  preDrawFunc: TMoviePreDrawFunc;

  // 0x6373B4
  lastMovieH: Integer;

  // 0x6373B8
  lastMovieW: Integer;

  // 0x6373F0
  lastMovieX: Integer;

  // 0x6373BC
  lastMovieY: Integer;

  // 0x6373F4
  subtitleList: PMovieSubtitleListNode;

  // 0x6373C4
  movieFlags_: LongWord;

  // 0x6373C8
  movieAlphaFlag: Integer;

  // 0x6373CC
  movieSubRectFlag: Boolean;

  // 0x6373F8
  movieH: Integer;

  // 0x6373FC
  movieOffset: Integer;

  // 0x6373D0
  movieCaptureFrameFunc: TMovieCaptureFrameProc;

  // 0x637410
  lastMovieBuffer: PByte;

  // 0x637414
  movieW: Integer;

  // 0x6373D8
  movieFrameGrabFunc: TMovieFrameGrabProc;

  // 0x637420
  subtitleH: Integer;

  // 0x6373E0
  running: Integer;

  // 0x6373E8
  handle_: PDB_FILE;

  // 0x6373EC
  alphaWindowBuf: PByte;

  // 0x637400
  movieX: Integer;

  // 0x637404
  movieY: Integer;

  // 0x63740C
  alphaHandle: PDB_FILE;

  // 0x637418
  alphaBuf_: PByte;

  gMovieSdlSurface: PSDL_Surface = nil;

  // Debug variables
  dbg_show_frame_count: Integer = 0;
  dbg_pi: Integer;
  dbg_pixel: LongWord;
  dbg_idx: Byte;
  dbg_ppm: File;
  dbg_ppm_hdr: AnsiString;
  dbg_rgb: array[0..2] of Byte;

// 0x4783F0
procedure movieSetPreDrawFunc(func: TMoviePreDrawFunc);
begin
  preDrawFunc := func;
end;

// 0x4783F8
procedure movieSetFailedOpenFunc(func: TMovieFailedOpenFunc);
begin
  failedOpenFunc := func;
end;

// 0x478400
procedure movieSetFunc(startFunc: TMovieStartFunc; endFunc: TMovieEndFunc);
begin
  startMovieFunc := startFunc;
  endMovieFunc := endFunc;
end;

// 0x47840C
function movieMalloc(size: SizeUInt): Pointer; cdecl;
begin
  Result := mymalloc(size, 'MOVIE.C', 209);
end;

// 0x478424
procedure movieFree(ptr: Pointer); cdecl;
begin
  myfree(ptr, 'MOVIE.C', 213);
end;

// 0x47843C
function movieRead(ahandle: Pointer; buf: Pointer;
  count: Integer): Boolean; cdecl;
begin
  Result := db_fread(buf, 1, count, PDB_FILE(ahandle)) = SizeUInt(count);
end;

// 0x478464
procedure movie_MVE_ShowFrame(surface: PSDL_Surface;
  srcWidth, srcHeight, srcX, srcY, destWidth, destHeight,
  a8, a9: Integer); cdecl;
var
  v14: Integer;
  v15: Integer;
  srcRect: TSDL_Rect;
  destRect: TSDL_Rect;
begin
  srcRect.x := srcX;
  srcRect.y := srcY;
  srcRect.w := srcWidth;
  srcRect.h := srcHeight;

  v14 := winRect.lrx - winRect.ulx;
  v15 := winRect.lrx - winRect.ulx + 1;

  if movieScaleFlag <> 0 then
  begin
    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x08) <> 0 then
    begin
      destRect.y := (winRect.lry - winRect.uly + 1 - destHeight) div 2;
      destRect.x := (v15 - 4 * srcWidth div 3) div 2;
    end
    else
    begin
      destRect.y := movieY + winRect.uly;
      destRect.x := winRect.ulx + movieX;
    end;

    destRect.w := 4 * srcWidth div 3 + destRect.x;
    destRect.h := destHeight + destRect.y;
  end
  else
  begin
    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x08) <> 0 then
    begin
      destRect.y := (winRect.lry - winRect.uly + 1 - destHeight) div 2;
      destRect.x := (v15 - destWidth) div 2;
    end
    else
    begin
      destRect.y := movieY + winRect.uly;
      destRect.x := winRect.ulx + movieX;
    end;
    destRect.w := destWidth;
    destRect.h := destHeight;
  end;

  lastMovieSX := srcX;
  lastMovieSY := srcY;
  lastMovieX := destRect.x;
  lastMovieY := destRect.y;
  lastMovieBH := srcHeight;
  lastMovieW := destRect.w;
  gMovieSdlSurface := surface;
  lastMovieBW := srcWidth;
  lastMovieH := destRect.h;

  destRect.x := destRect.x + winRect.ulx;
  destRect.y := destRect.y + winRect.uly;

  if movieCaptureFrameFunc <> nil then
  begin
    if SDL_LockSurface(surface) = 0 then
    begin
      movieCaptureFrameFunc(PByte(surface^.pixels),
        srcWidth,
        srcHeight,
        surface^.pitch,
        destRect.x,
        destRect.y,
        destRect.w,
        destRect.h);
      SDL_UnlockSurface(surface);
    end;
  end;

  SDL_SetSurfacePalette(surface, gSdlSurface^.format^.palette);
  SDL_BlitSurface(surface, @srcRect, gSdlSurface, @destRect);
  SDL_BlitSurface(gSdlSurface, nil, gSdlTextureSurface, nil);

  // Debug: save PPM snapshot at frame 200 of each movie
  Inc(dbg_show_frame_count);
  if dbg_show_frame_count = 200 then
  begin
    Assign(dbg_ppm, '/tmp/pas_frame200.ppm');
    Rewrite(dbg_ppm, 1);
    dbg_ppm_hdr := 'P6' + #10 +
      IntToStr(gSdlTextureSurface^.w) + ' ' + IntToStr(gSdlTextureSurface^.h) + #10 +
      '255' + #10;
    BlockWrite(dbg_ppm, dbg_ppm_hdr[1], Length(dbg_ppm_hdr));
    for dbg_pi := 0 to gSdlTextureSurface^.w * gSdlTextureSurface^.h - 1 do
    begin
      dbg_pixel := PLongWord(PByte(gSdlTextureSurface^.pixels) +
        (dbg_pi div gSdlTextureSurface^.w) * gSdlTextureSurface^.pitch +
        (dbg_pi mod gSdlTextureSurface^.w) * 4)^;
      // XRGB8888: pixel = 0x00RRGGBB
      dbg_rgb[0] := Byte((dbg_pixel shr 16) and $FF); // R
      dbg_rgb[1] := Byte((dbg_pixel shr 8) and $FF);  // G
      dbg_rgb[2] := Byte(dbg_pixel and $FF);           // B
      BlockWrite(dbg_ppm, dbg_rgb, 3);
    end;
    Close(dbg_ppm);
    WriteLn(StdErr, '[SNAPSHOT] Saved /tmp/pas_frame200.ppm');
    // Also save raw 8-bit indices from gSdlSurface
    Assign(dbg_ppm, '/tmp/pas_frame200_idx.raw');
    Rewrite(dbg_ppm, 1);
    for dbg_pi := 0 to gSdlSurface^.h - 1 do
      BlockWrite(dbg_ppm, PByte(gSdlSurface^.pixels)[dbg_pi * gSdlSurface^.pitch],
        gSdlSurface^.w);
    Close(dbg_ppm);
    // Save palette as raw RGB triplets
    Assign(dbg_ppm, '/tmp/pas_frame200_pal.raw');
    Rewrite(dbg_ppm, 1);
    for dbg_pi := 0 to 255 do
    begin
      dbg_rgb[0] := gSdlSurface^.format^.palette^.colors[dbg_pi].r;
      dbg_rgb[1] := gSdlSurface^.format^.palette^.colors[dbg_pi].g;
      dbg_rgb[2] := gSdlSurface^.format^.palette^.colors[dbg_pi].b;
      BlockWrite(dbg_ppm, dbg_rgb, 3);
    end;
    Close(dbg_ppm);
    WriteLn(StdErr, '[SNAPSHOT] Saved idx and pal files');
  end;

  renderPresent;
end;

// 0x478710
procedure movieShowFrame(a1: PSDL_Surface;
  a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl;
var
  func: TMovieBlitFunc;
begin
  if GNWWin = -1 then
    Exit;

  lastMovieBW := a2;
  gMovieSdlSurface := a1;
  lastMovieBH := a2;
  lastMovieW := a6;
  lastMovieH := a7;
  lastMovieX := a4;
  lastMovieY := a5;
  lastMovieSX := a4;
  lastMovieSY := a5;

  if SDL_LockSurface(a1) <> 0 then
    Exit;

  if movieCaptureFrameFunc <> nil then
  begin
    movieCaptureFrameFunc(PByte(a1^.pixels), a2, a3, a1^.pitch,
      movieRect.ulx, movieRect.uly, a6, a7);
  end;

  if movieFrameGrabFunc <> nil then
  begin
    movieFrameGrabFunc(PByte(a1^.pixels), a2, a3, a1^.pitch);
  end
  else
  begin
    func := showFrameFuncs[movieAlphaFlag][movieScaleFlag][Ord(movieSubRectFlag)];
    if func(GNWWin, PByte(a1^.pixels), a2, a3, a1^.pitch) <> 0 then
    begin
      if preDrawFunc <> nil then
        preDrawFunc(GNWWin, @movieRect);

      win_draw_rect(GNWWin, @movieRect);
    end;
  end;

  SDL_UnlockSurface(a1);
end;

// 0x4788A8
procedure movieSetFrameGrabFunc(func: TMovieFrameGrabProc);
begin
  movieFrameGrabFunc := func;
end;

// 0x4788B0
procedure movieSetCaptureFrameFunc(func: TMovieCaptureFrameProc);
begin
  movieCaptureFrameFunc := func;
end;

// 0x478978
function movieScaleSubRect(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
  v1: Integer;
  y, x: Integer;
  value: LongWord;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win) + windowWidth * movieY + movieX;
  if width * 4 div 3 > movieW then
  begin
    movieFlags_ := movieFlags_ or $01;
    Result := 0;
    Exit;
  end;

  v1 := width div 3;
  for y := 0 to height - 1 do
  begin
    for x := 0 to v1 - 1 do
    begin
      value := data[0];
      value := value or (LongWord(data[1]) shl 8);
      value := value or (LongWord(data[2]) shl 16);
      value := value or (LongWord(data[2]) shl 24);

      PLongWord(windowBuffer)^ := value;

      Inc(windowBuffer, 4);
      Inc(data, 3);
    end;

    x := v1 * 3;
    while x < width do
    begin
      windowBuffer^ := data^;
      Inc(windowBuffer);
      Inc(data);
      Inc(x);
    end;

    Inc(data, pitch - width);
    Inc(windowBuffer, windowWidth - movieW);
  end;

  Result := 1;
end;

// 0x478A84
function movieScaleWindowAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
begin
  movieFlags_ := movieFlags_ or 1;
  Result := 0;
end;

// 0x478A84
function movieScaleSubRectAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
begin
  movieFlags_ := movieFlags_ or 1;
  Result := 0;
end;

// 0x478A90
function blitAlpha(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win);
  alphaBltBuf(data, width, height, pitch, alphaWindowBuf, alphaBuf_,
    windowBuffer + windowWidth * movieY + movieX, windowWidth);
  Result := 1;
end;

// 0x478AE4
function movieScaleWindow(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
  y: Integer;
  scaledWidth: Integer;
  x: Integer;
  value: LongWord;
begin
  windowWidth := win_width(win);
  if width <> 3 * windowWidth div 4 then
  begin
    movieFlags_ := movieFlags_ or 1;
    Result := 0;
    Exit;
  end;

  windowBuffer := win_get_buf(win);
  for y := 0 to height - 1 do
  begin
    scaledWidth := width div 3;
    for x := 0 to scaledWidth - 1 do
    begin
      value := data[0];
      value := value or (LongWord(data[1]) shl 8);
      value := value or (LongWord(data[2]) shl 16);
      value := value or (LongWord(data[3]) shl 24);

      PLongWord(windowBuffer)^ := value;

      Inc(windowBuffer, 4);
      Inc(data, 3);
    end;
    Inc(data, pitch - width);
  end;

  Result := 1;
end;

// 0x478B94
function blitNormal(win: Integer; data: PByte;
  width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win);
  drawScaled(windowBuffer + windowWidth * movieY + movieX,
    movieW, movieH, windowWidth, data, width, height, pitch);
  Result := 1;
end;

// 0x478BEC
procedure movieSetPalette_internal(palette: PByte;
  start, end_: Integer); cdecl;
begin
  WriteLn(StdErr, '[INTPAL] movieSetPalette_internal called start=', start,
    ' end_=', end_, ' paletteFunc_assigned=', Assigned(paletteFunc));
  if end_ <> 0 then
  begin
    WriteLn(StdErr, '[INTPAL] calling paletteFunc(pal+', start*3, ', ', start, ', ', end_ + start - 1, ')');
    paletteFunc(palette + start * 3, start, end_ + start - 1);
  end;
end;

// 0x478C18
function noop: Integer;
begin
  Result := 0;
end;

// 0x478C1C
procedure initMovie;
begin
  movieLibSetMemoryProcs(@movieMalloc, @movieFree);
  movieLibSetPaletteEntriesProc(@movieSetPalette_internal);
  _MVE_sfSVGA(640, 480, 480, 0, 0, 0, 0, 0, 0);
  movieLibSetReadProc(@movieRead);
end;

// 0x478CA8
procedure cleanupMovie(a1: Integer);
var
  frame: Integer;
  dropped: Integer;
  next: PMovieSubtitleListNode;
begin
  if running = 0 then
    Exit;

  if endMovieFunc <> nil then
    endMovieFunc(GNWWin, movieX, movieY, movieW, movieH);

  _MVE_rmFrameCounts(@frame, @dropped);
  debug_printf('Frames %d, dropped %d'#10, [frame, dropped]);

  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 787);
    lastMovieBuffer := nil;
  end;

  if gMovieSdlSurface <> nil then
  begin
    if SDL_LockSurface(gMovieSdlSurface) = 0 then
    begin
      lastMovieBuffer := PByte(mymalloc(lastMovieBH * lastMovieBW,
        'MOVIE.C', 802));
      buf_to_buf(PByte(gMovieSdlSurface^.pixels) +
        gMovieSdlSurface^.pitch * lastMovieSX + lastMovieSY,
        lastMovieBW, lastMovieBH, gMovieSdlSurface^.pitch,
        lastMovieBuffer, lastMovieBW);
      SDL_UnlockSurface(gMovieSdlSurface);
    end
    else
    begin
      debug_printf('Couldn''t lock movie surface'#10);
    end;

    gMovieSdlSurface := nil;
  end;

  if a1 <> 0 then
    _MVE_rmEndMovie;

  _MVE_ReleaseMem;

  db_fclose(handle_);

  if alphaWindowBuf <> nil then
  begin
    buf_to_buf(alphaWindowBuf, movieW, movieH, movieW,
      win_get_buf(GNWWin) + movieY * win_width(GNWWin) + movieX,
      win_width(GNWWin));
    win_draw_rect(GNWWin, @movieRect);
  end;

  if alphaHandle <> nil then
  begin
    db_fclose(alphaHandle);
    alphaHandle := nil;
  end;

  if alphaBuf_ <> nil then
  begin
    myfree(alphaBuf_, 'MOVIE.C', 840);
    alphaBuf_ := nil;
  end;

  if alphaWindowBuf <> nil then
  begin
    myfree(alphaWindowBuf, 'MOVIE.C', 845);
    alphaWindowBuf := nil;
  end;

  while subtitleList <> nil do
  begin
    next := subtitleList^.next;
    myfree(subtitleList^.text, 'MOVIE.C', 851);
    myfree(subtitleList, 'MOVIE.C', 852);
    subtitleList := next;
  end;

  running := 0;
  movieSubRectFlag := False;
  movieScaleFlag := 0;
  movieAlphaFlag := 0;
  movieFlags_ := 0;
  GNWWin := -1;
end;

// 0x478F2C
procedure movieClose;
begin
  cleanupMovie(1);

  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 869);
    lastMovieBuffer := nil;
  end;
end;

// 0x478F60
procedure movieStop;
begin
  if running <> 0 then
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x02;
end;

// 0x478F74
function movieSetFlags(flags: Integer): Integer;
begin
  if (flags and MOVIE_FLAG_0x04) <> 0 then
  begin
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x04 or MOVIE_EXTENDED_FLAG_0x08;
  end
  else
  begin
    movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x08));
    if (flags and MOVIE_FLAG_0x02) <> 0 then
      movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x04
    else
      movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x04));
  end;

  if (flags and MOVIE_FLAG_0x01) <> 0 then
  begin
    movieScaleFlag := 1;

    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x04) <> 0 then
      _sub_4F4BB(3);
  end
  else
  begin
    movieScaleFlag := 0;

    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x04) <> 0 then
      _sub_4F4BB(4)
    else
      movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x08));
  end;

  if (flags and MOVIE_FLAG_0x08) <> 0 then
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x10
  else
    movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x10));

  Result := 0;
end;

// 0x47901C
procedure movieSetSubtitleFont(font: Integer);
begin
  subtitleFont := font;
end;

// 0x479024
procedure movieSetSubtitleColor(r, g, b: Single);
begin
  subtitleR := Trunc(r * 31.0);
  subtitleG := Trunc(g * 31.0);
  subtitleB := Trunc(b * 31.0);
end;

// 0x479060
procedure movieSetPaletteFunc(func: TMoviePaletteFunc);
begin
  if func <> nil then
    paletteFunc := func
  else
    paletteFunc := TMoviePaletteFunc(@setSystemPaletteEntries);
end;

// 0x479078
procedure movieSetCallback(func: TMovieUpdateCallbackProc);
begin
  updateCallbackFunc := func;
end;

// 0x4790EC
procedure cleanupLast;
begin
  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 981);
    lastMovieBuffer := nil;
  end;

  gMovieSdlSurface := nil;
end;

// 0x479120
function openFile(filePath: PAnsiChar): PDB_FILE;
begin
  handle_ := db_fopen(filePath, 'rb');
  if handle_ = nil then
  begin
    if failedOpenFunc = nil then
    begin
      debug_printf('Couldn''t find movie file %s'#10, [filePath]);
      Result := nil;
      Exit;
    end;

    while (handle_ = nil) and (failedOpenFunc(filePath) <> 0) do
      handle_ := db_fopen(filePath, 'rb');
  end;
  Result := handle_;
end;

// 0x479184
procedure openSubtitle(filePath: PAnsiChar);
var
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  stream: PDB_FILE;
  prev: PMovieSubtitleListNode;
  subtitleCount: Integer;
  str: array[0..259] of AnsiChar;
  subtitle: PMovieSubtitleListNode;
  pch: PAnsiChar;
begin
  subtitleW := win_width(GNWWin);
  subtitleH := text_height() + 4;

  if subtitleFilenameFunc <> nil then
    filePath := subtitleFilenameFunc(filePath);

  StrCopy(@path[0], filePath);

  debug_printf('Opening subtitle file %s'#10, [PAnsiChar(@path[0])]);
  stream := db_fopen(@path[0], 'r');
  if stream = nil then
  begin
    debug_printf('Couldn''t open subtitle file %s'#10, [PAnsiChar(@path[0])]);
    movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x10));
    Exit;
  end;

  prev := nil;
  subtitleCount := 0;
  while db_feof(stream) = 0 do
  begin
    str[0] := #0;
    db_fgets(@str[0], 259, stream);
    if str[0] = #0 then
      Break;

    subtitle := PMovieSubtitleListNode(mymalloc(SizeOf(TMovieSubtitleListNode),
      'MOVIE.C', 1050));
    subtitle^.next := nil;

    Inc(subtitleCount);

    pch := StrScan(@str[0], #10);
    if pch <> nil then
      pch^ := #0;

    pch := StrScan(@str[0], #13);
    if pch <> nil then
      pch^ := #0;

    pch := StrScan(@str[0], ':');
    if pch <> nil then
    begin
      pch^ := #0;
      subtitle^.num := StrToIntDef(StrPas(@str[0]), 0);
      subtitle^.text := mystrdup(pch + 1, 'MOVIE.C', 1058);

      if prev <> nil then
        prev^.next := subtitle
      else
        subtitleList := subtitle;

      prev := subtitle;
    end
    else
    begin
      debug_printf('subtitle: couldn''t parse %s'#10, [PAnsiChar(@str[0])]);
    end;
  end;

  db_fclose(stream);

  debug_printf('Read %d subtitles'#10, [subtitleCount]);
end;

// 0x479360
procedure doSubtitle;
var
  v1: Integer;
  v2: Integer;
  frame: Integer;
  dropped: Integer;
  next: PMovieSubtitleListNode;
  oldFont: Integer;
  colorIndex: Integer;
  rect: TRect;
begin
  if subtitleList = nil then
    Exit;

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x10) = 0 then
    Exit;

  v1 := text_height();
  v2 := (480 - lastMovieH - lastMovieY - v1) div 2 + lastMovieH + lastMovieY;

  if subtitleH + v2 > windowGetYres then
    subtitleH := windowGetYres - v2;

  _MVE_rmFrameCounts(@frame, @dropped);

  while subtitleList <> nil do
  begin
    if frame < subtitleList^.num then
      Break;

    next := subtitleList^.next;

    win_fill(GNWWin, 0, v2, subtitleW, subtitleH, 0);

    oldFont := 0;
    if subtitleFont <> -1 then
    begin
      oldFont := text_curr();
      text_font(subtitleFont);
    end;

    colorIndex := (subtitleR shl 10) or (subtitleG shl 5) or subtitleB;
    windowWrapLine(GNWWin, subtitleList^.text, subtitleW, subtitleH, 0, v2,
      colorTable[colorIndex] or $2000000, TEXT_ALIGNMENT_CENTER);

    rect.lrx := subtitleW;
    rect.uly := v2;
    rect.lry := v2 + subtitleH;
    rect.ulx := 0;
    win_draw_rect(GNWWin, @rect);

    myfree(subtitleList^.text, 'MOVIE.C', 1108);
    myfree(subtitleList, 'MOVIE.C', 1109);

    subtitleList := next;

    if subtitleFont <> -1 then
      text_font(oldFont);
  end;
end;

// 0x479514
function movieStart(win: Integer; filePath: PAnsiChar;
  a3: Pointer): Integer;
var
  v15: Integer;
  v16: Integer;
  v17: Integer;
  size: LongWord;
  tmp: SmallInt;
  windowBuffer: PByte;
begin
  dbg_show_frame_count := 0; // Reset frame counter for each movie
  WriteLn(StdErr, '[MOVIE] movieStart: ', filePath);
  if running <> 0 then
  begin
    Result := 1;
    Exit;
  end;

  cleanupLast;

  handle_ := openFile(filePath);
  if handle_ = nil then
  begin
    Result := 1;
    Exit;
  end;

  GNWWin := win;
  running := 1;
  movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x01));

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x10) <> 0 then
    openSubtitle(filePath);

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x04) <> 0 then
  begin
    debug_printf('Direct ');
    win_get_rect(GNWWin, @winRect);
    debug_printf('Playing at (%d, %d)  ', [movieX + winRect.ulx, movieY + winRect.uly]);
    _MVE_rmCallbacks(a3);
    _MVE_sfCallbacks(@movie_MVE_ShowFrame);

    v17 := 0;
    v16 := movieY + winRect.uly;
    v15 := movieX + winRect.ulx;
  end
  else
  begin
    debug_printf('Buffered ');
    _MVE_rmCallbacks(a3);
    _MVE_sfCallbacks(@movieShowFrame);
    v17 := 0;
    v16 := 0;
    v15 := 0;
  end;

  _MVE_rmPrepMovie(handle_, v15, v16, AnsiChar(v17));

  if movieScaleFlag <> 0 then
    debug_printf('scaled'#10)
  else
    debug_printf('not scaled'#10);

  if startMovieFunc <> nil then
    startMovieFunc(GNWWin);

  if alphaHandle <> nil then
  begin
    db_freadLong(alphaHandle, @size);

    db_freadInt16(alphaHandle, @tmp);
    db_freadInt16(alphaHandle, @tmp);

    alphaBuf_ := PByte(mymalloc(size, 'MOVIE.C', 1178));
    alphaWindowBuf := PByte(mymalloc(movieH * movieW, 'MOVIE.C', 1179));

    windowBuffer := win_get_buf(GNWWin);
    buf_to_buf(windowBuffer + win_width(GNWWin) * movieY + movieX,
      movieW,
      movieH,
      win_width(GNWWin),
      alphaWindowBuf,
      movieW);
  end;

  movieRect.ulx := movieX;
  movieRect.uly := movieY;
  movieRect.lrx := movieW + movieX;
  movieRect.lry := movieH + movieY;

  Result := 0;
end;

// 0x479768
function localMovieCallback: Boolean;
begin
  doSubtitle;

  if movieCallback_ <> nil then
    movieCallback_();

  Result := get_input() <> -1;
end;

// 0x4798CC
function movieRun(win: Integer; filePath: PAnsiChar): Integer;
begin
  if running <> 0 then
  begin
    Result := 1;
    Exit;
  end;

  movieX := 0;
  movieY := 0;
  movieOffset := 0;
  movieW := win_width(win);
  movieH := win_height(win);
  movieSubRectFlag := False;
  Result := movieStart(win, filePath, @noop);
end;

// 0x479920
function movieRunRect(win: Integer; filePath: PAnsiChar;
  a3, a4, a5, a6: Integer): Integer;
begin
  if running <> 0 then
  begin
    Result := 1;
    Exit;
  end;

  movieX := a3;
  movieY := a4;
  movieOffset := a3 + a4 * win_width(win);
  movieW := a5;
  movieH := a6;
  movieSubRectFlag := True;

  Result := movieStart(win, filePath, @noop);
end;

// 0x479980
function stepMovie_internal: Integer;
var
  rc: Integer;
  size: LongWord;
begin
  if alphaHandle <> nil then
  begin
    db_freadLong(alphaHandle, @size);
    db_fread(alphaBuf_, 1, size, alphaHandle);
  end;

  rc := _MVE_rmStepMovie;
  if rc <> -1 then
    doSubtitle;

  Result := rc;
end;

// 0x4799CC
procedure movieSetSubtitleFunc(func: TMovieSubtitleFunc);
begin
  subtitleFilenameFunc := func;
end;

// 0x4799D4
procedure movieSetVolume(volume: Integer);
var
  normalized_volume: Integer;
begin
  normalized_volume := soundVolumeHMItoDirectSound(volume);
  movieLibSetVolume(normalized_volume);
end;

// 0x4799F0
procedure movieUpdate;
var
  frame: Integer;
  dropped: Integer;
  rc: Integer;
begin
  if running = 0 then
    Exit;

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x02) <> 0 then
  begin
    debug_printf('Movie aborted'#10);
    cleanupMovie(1);
    Exit;
  end;

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x01) <> 0 then
  begin
    debug_printf('Movie error'#10);
    cleanupMovie(1);
    Exit;
  end;

  rc := stepMovie_internal;
  if rc = -1 then
  begin
    WriteLn(StdErr, '[MOVIE] movieUpdate: movie ended (stepMovie=-1), calling cleanupMovie');
    cleanupMovie(1);
    Exit;
  end;

  if updateCallbackFunc <> nil then
  begin
    _MVE_rmFrameCounts(@frame, @dropped);
    updateCallbackFunc(frame);
  end;
end;

// 0x479A8C
function moviePlaying: Integer;
begin
  Result := running;
end;

// ===== Initialization =====
procedure InitShowFrameFuncs;
begin
  // showFrameFuncs[alpha][scale][subRect]
  // [0][0][0] = blitNormal
  showFrameFuncs[0][0][0] := @blitNormal;
  // [0][0][1] = blitNormal
  showFrameFuncs[0][0][1] := @blitNormal;
  // [0][1][0] = movieScaleWindow
  showFrameFuncs[0][1][0] := @movieScaleWindow;
  // [0][1][1] = movieScaleSubRect
  showFrameFuncs[0][1][1] := @movieScaleSubRect;
  // [1][0][0] = blitAlpha
  showFrameFuncs[1][0][0] := @blitAlpha;
  // [1][0][1] = blitAlpha
  showFrameFuncs[1][0][1] := @blitAlpha;
  // [1][1][0] = movieScaleSubRectAlpha
  showFrameFuncs[1][1][0] := @movieScaleSubRectAlpha;
  // [1][1][1] = movieScaleWindowAlpha
  showFrameFuncs[1][1][1] := @movieScaleWindowAlpha;

  paletteFunc := TMoviePaletteFunc(@setSystemPaletteEntries);
end;

initialization
  InitShowFrameFuncs;

end.
