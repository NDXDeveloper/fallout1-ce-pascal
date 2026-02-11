{$MODE OBJFPC}{$H+}
{$R-} // Disable range checks - low-level binary MVE decoder with extensive bit manipulation
// Converted from: src/int/movie.h + movie.cc + src/movie_lib.h + movie_lib.cc
// High-level movie playback API and low-level MVE (Interplay Movie) decoder.
unit u_movie_lib;

interface

uses
  u_rect, u_sdl2;

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
  // movie.h callback types
  TMovieSubtitleFunc = function(movieFilePath: PAnsiChar): PAnsiChar; cdecl;
  TMoviePaletteFunc = procedure(palette: PByte; start, end_: Integer); cdecl;
  TMovieUpdateCallbackProc = procedure(frame: Integer); cdecl;
  TMovieFrameGrabProc = procedure(data: PByte; width, height, pitch: Integer); cdecl;
  TMovieCaptureFrameProc = procedure(data: PByte; width, height, pitch, movieX_, movieY_, movieWidth, movieHeight: Integer); cdecl;
  TMoviePreDrawFunc = procedure(win: Integer; rect: PRect); cdecl;
  TMovieStartFunc = procedure(win: Integer); cdecl;
  TMovieEndFunc = procedure(win, x, y, width, height: Integer); cdecl;
  TMovieFailedOpenFunc = function(path: PAnsiChar): Integer; cdecl;

  PMovieSubtitleFunc = ^TMovieSubtitleFunc;
  PMoviePaletteFunc = ^TMoviePaletteFunc;
  PMovieUpdateCallbackProc = ^TMovieUpdateCallbackProc;
  PMovieFrameGrabProc = ^TMovieFrameGrabProc;
  PMovieCaptureFrameProc = ^TMovieCaptureFrameProc;
  PMoviePreDrawFunc = ^TMoviePreDrawFunc;
  PMovieStartFunc = ^TMovieStartFunc;
  PMovieEndFunc = ^TMovieEndFunc;
  PMovieFailedOpenFunc = ^TMovieFailedOpenFunc;

  // movie_lib.h callback types
  TMveMallocFunc = function(size: SizeUInt): Pointer; cdecl;
  TMveFreeFunc = procedure(ptr: Pointer); cdecl;
  TMovieReadProc = function(handle: Pointer; buffer: Pointer; count: Integer): Boolean; cdecl;
  TMovieShowFrameProc = procedure(surface: PSDL_Surface; a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl;

  // movie.cc internal types
  TMovieCallback = procedure; cdecl;
  TMovieBlitFunc = function(win: Integer; data: PByte; width, height, pitch: Integer): Integer;

  PMovieSubtitleListNode = ^TMovieSubtitleListNode;
  TMovieSubtitleListNode = record
    num: Integer;
    text: PAnsiChar;
    next: PMovieSubtitleListNode;
  end;

// ===== movie.h public API =====
procedure movieSetPreDrawFunc(func: TMoviePreDrawFunc);
procedure movieSetFailedOpenFunc(func: TMovieFailedOpenFunc);
procedure movieSetFunc(startFunc: TMovieStartFunc; endFunc: TMovieEndFunc);
procedure movieSetFrameGrabFunc(func: TMovieFrameGrabProc);
procedure movieSetCaptureFrameFunc(func: TMovieCaptureFrameProc);
procedure initMovie;
procedure movieClose;
procedure movieStop;
function movieSetFlags(a1: Integer): Integer;
procedure movieSetSubtitleFont(font: Integer);
procedure movieSetSubtitleColor(r, g, b: Single);
procedure movieSetPaletteFunc(func: TMoviePaletteFunc);
procedure movieSetCallback(func: TMovieUpdateCallbackProc);
function movieRun(win: Integer; filePath: PAnsiChar): Integer;
function movieRunRect(win: Integer; filePath: PAnsiChar; a3, a4, a5, a6: Integer): Integer;
procedure movieSetSubtitleFunc(func: TMovieSubtitleFunc);
procedure movieSetVolume(volume: Integer);
procedure movieUpdate;
function moviePlaying: Integer;

// ===== movie_lib.h public API =====
procedure movieLibSetMemoryProcs(mallocProc: TMveMallocFunc; freeProc: TMveFreeFunc);
procedure movieLibSetReadProc(readProc: TMovieReadProc);
procedure movieLibSetVolume(volume: Integer);
procedure movieLibSetPan(pan: Integer);
procedure _MVE_sfSVGA(a1, a2, a3, a4, a5, a6, a7, a8, a9: Integer);
procedure _MVE_sfCallbacks(proc: TMovieShowFrameProc);
procedure movieLibSetPaletteEntriesProc(fn: TMoviePaletteFunc);
procedure _MVE_rmCallbacks(fn: Pointer);
procedure _sub_4F4BB(a1: Integer);
procedure _MVE_rmFrameCounts(a1, a2: PInteger);
function _MVE_rmPrepMovie(handle: Pointer; a2, a3: Integer; a4: AnsiChar): Integer;
function _MVE_rmStepMovie: Integer;
procedure _MVE_rmEndMovie;
procedure _MVE_ReleaseMem;

implementation

uses
  SysUtils, u_db, u_debug, u_memory, u_gnw, u_svga, u_input,
  u_text, u_grbuf, u_color, u_audio_engine, u_platform_compat,
  u_memdbg, u_int_sound, u_int_window;

// ===== SDL2 functions not yet in u_sdl2 =====
function SDL_LockSurface(surface: PSDL_Surface): Integer; cdecl; external SDL2_LIB;
procedure SDL_UnlockSurface(surface: PSDL_Surface); cdecl; external SDL2_LIB;
function SDL_SetSurfacePalette(surface: PSDL_Surface; palette: PSDL_Palette): Integer; cdecl; external SDL2_LIB;

const
  TEXT_ALIGNMENT_CENTER = 1;

// ===================================================================
// movie_lib.cc types and structures
// ===================================================================

type
  PSTRUCT_6B3690 = ^TSTRUCT_6B3690;
  TSTRUCT_6B3690 = record
    field_0: Pointer;
    field_4: LongWord;
    field_8: Integer;
  end;

{$PACKRECORDS 2}
  TMve = record
    sig: array[0..19] of AnsiChar;
    field_14: SmallInt;
    field_16: SmallInt;
    field_18: SmallInt;
    field_1A: Integer;
  end;
{$PACKRECORDS DEFAULT}

  PSTRUCT_4F6930 = ^TSTRUCT_4F6930;
  TSTRUCT_4F6930 = record
    field_0: Integer;
    readProc: TMovieReadProc;
    field_8: TSTRUCT_6B3690;
    fileHandle: Pointer;
    field_18: Integer;
    field_24: PSDL_Surface;
    field_28: PSDL_Surface;
    field_2C: Integer;
    field_30: PByte;
    field_34: PByte;
    field_38: Byte;
    field_39: Byte;
    field_3A: Byte;
    field_3B: Byte;
    field_3C: Integer;
    field_40: Integer;
    field_44: Integer;
    field_48: Integer;
    field_4C: Integer;
    field_50: Integer;
  end;

// ===================================================================
// movie_lib.cc static variables
// ===================================================================
var
  dword_51EBD8: Integer = 0;
  dword_51EBDC: Integer = 4;

  word_51EBE0: array[0..255] of Word = (
    $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007,
    $0008, $0009, $000A, $000B, $000C, $000D, $000E, $000F,
    $0010, $0011, $0012, $0013, $0014, $0015, $0016, $0017,
    $0018, $0019, $001A, $001B, $001C, $001D, $001E, $001F,
    $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027,
    $0028, $0029, $002A, $002B, $002F, $0033, $0038, $003D,
    $0042, $0048, $004F, $0056, $005E, $0066, $0070, $007A,
    $0085, $0091, $009E, $00AD, $00BD, $00CE, $00E1, $00F5,
    $010B, $0124, $013E, $015C, $017B, $019E, $01C4, $01ED,
    $021A, $024B, $0280, $02BB, $02FB, $0340, $038C, $03DF,
    $0439, $049C, $0508, $057D, $05FE, $0689, $0722, $07C9,
    $087F, $0945, $0A1E, $0B0A, $0C0C, $0D25, $0E58, $0FA8,
    $1115, $12A4, $1458, $1633, $183A, $1A6F, $1CD9, $1F7B,
    $225A, $257D, $28E8, $2CA4, $30B7, $3529, $3A03, $3F4E,
    $4515, $4B62, $5244, $59C5, $61F6, $6AE7, $74A8, $7F4D,
    $8AEB, $9798, $A56E, $B486, $C4FF, $D6F9, $EA97, $FFFF,
    $0001, $0001, $1569, $2907, $3B01, $4B7A, $5A92, $6868,
    $7515, $80B3, $8B58, $9519, $9E0A, $A63B, $ADBC, $B49E,
    $BAEB, $C0B2, $C5FD, $CAD7, $CF49, $D35C, $D718, $DA83,
    $DDA6, $E085, $E327, $E591, $E7C6, $E9CD, $EBA8, $ED5C,
    $EEEB, $F058, $F1A8, $F2DB, $F3F4, $F4F6, $F5E2, $F6BB,
    $F781, $F837, $F8DE, $F977, $FA02, $FA83, $FAF8, $FB64,
    $FBC7, $FC21, $FC74, $FCC0, $FD05, $FD45, $FD80, $FDB5,
    $FDE6, $FE13, $FE3C, $FE62, $FE85, $FEA4, $FEC2, $FEDC,
    $FEF5, $FF0B, $FF1F, $FF32, $FF43, $FF53, $FF62, $FF6F,
    $FF7B, $FF86, $FF90, $FF9A, $FFA2, $FFAA, $FFB1, $FFB8,
    $FFBE, $FFC3, $FFC8, $FFCD, $FFD1, $FFD5, $FFD6, $FFD7,
    $FFD8, $FFD9, $FFDA, $FFDB, $FFDC, $FFDD, $FFDE, $FFDF,
    $FFE0, $FFE1, $FFE2, $FFE3, $FFE4, $FFE5, $FFE6, $FFE7,
    $FFE8, $FFE9, $FFEA, $FFEB, $FFEC, $FFEE, $FFED, $FFEF,
    $FFF0, $FFF1, $FFF2, $FFF3, $FFF4, $FFF5, $FFF6, $FFF7,
    $FFF8, $FFF9, $FFFA, $FFFB, $FFFC, $FFFD, $FFFE, $FFFF
  );

  _sync_active: Integer = 0;
  _sync_late: Integer = 0;
  _sync_FrameDropped: Integer = 0;
  gMovieLibVolume: Integer = 0;
  gMovieLibPan: Integer = 0;
  _sf_ShowFrame: TMovieShowFrameProc = nil;
  dword_51EE0C: Integer = 1;
  _pal_SetPalette: TMoviePaletteFunc = nil;
  _rm_hold: Integer = 0;
  _rm_active: Integer = 0;
  dword_51EE20: Boolean = False;

  dword_51F018: array[0..255] of Integer;

  word_51F418: array[0..255] of Word = (
    $F8F8, $F8F9, $F8FA, $F8FB, $F8FC, $F8FD, $F8FE, $F8FF,
    $F800, $F801, $F802, $F803, $F804, $F805, $F806, $F807,
    $F9F8, $F9F9, $F9FA, $F9FB, $F9FC, $F9FD, $F9FE, $F9FF,
    $F900, $F901, $F902, $F903, $F904, $F905, $F906, $F907,
    $FAF8, $FAF9, $FAFA, $FAFB, $FAFC, $FAFD, $FAFE, $FAFF,
    $FA00, $FA01, $FA02, $FA03, $FA04, $FA05, $FA06, $FA07,
    $FBF8, $FBF9, $FBFA, $FBFB, $FBFC, $FBFD, $FBFE, $FBFF,
    $FB00, $FB01, $FB02, $FB03, $FB04, $FB05, $FB06, $FB07,
    $FCF8, $FCF9, $FCFA, $FCFB, $FCFC, $FCFD, $FCFE, $FCFF,
    $FC00, $FC01, $FC02, $FC03, $FC04, $FC05, $FC06, $FC07,
    $FDF8, $FDF9, $FDFA, $FDFB, $FDFC, $FDFD, $FDFE, $FDFF,
    $FD00, $FD01, $FD02, $FD03, $FD04, $FD05, $FD06, $FD07,
    $FEF8, $FEF9, $FEFA, $FEFB, $FEFC, $FEFD, $FEFE, $FEFF,
    $FE00, $FE01, $FE02, $FE03, $FE04, $FE05, $FE06, $FE07,
    $FFF8, $FFF9, $FFFA, $FFFB, $FFFC, $FFFD, $FFFE, $FFFF,
    $FF00, $FF01, $FF02, $FF03, $FF04, $FF05, $FF06, $FF07,
    $00F8, $00F9, $00FA, $00FB, $00FC, $00FD, $00FE, $00FF,
    $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007,
    $01F8, $01F9, $01FA, $01FB, $01FC, $01FD, $01FE, $01FF,
    $0100, $0101, $0102, $0103, $0104, $0105, $0106, $0107,
    $02F8, $02F9, $02FA, $02FB, $02FC, $02FD, $02FE, $02FF,
    $0200, $0201, $0202, $0203, $0204, $0205, $0206, $0207,
    $03F8, $03F9, $03FA, $03FB, $03FC, $03FD, $03FE, $03FF,
    $0300, $0301, $0302, $0303, $0304, $0305, $0306, $0307,
    $04F8, $04F9, $04FA, $04FB, $04FC, $04FD, $04FE, $04FF,
    $0400, $0401, $0402, $0403, $0404, $0405, $0406, $0407,
    $05F8, $05F9, $05FA, $05FB, $05FC, $05FD, $05FE, $05FF,
    $0500, $0501, $0502, $0503, $0504, $0505, $0506, $0507,
    $06F8, $06F9, $06FA, $06FB, $06FC, $06FD, $06FE, $06FF,
    $0600, $0601, $0602, $0603, $0604, $0605, $0606, $0607,
    $07F8, $07F9, $07FA, $07FB, $07FC, $07FD, $07FE, $07FF,
    $0700, $0701, $0702, $0703, $0704, $0705, $0706, $0707
  );

  word_51F618: array[0..255] of Word = (
    $0008, $0009, $000A, $000B, $000C, $000D, $000E, $0108,
    $0109, $010A, $010B, $010C, $010D, $010E, $0208, $0209,
    $020A, $020B, $020C, $020D, $020E, $0308, $0309, $030A,
    $030B, $030C, $030D, $030E, $0408, $0409, $040A, $040B,
    $040C, $040D, $040E, $0508, $0509, $050A, $050B, $050C,
    $050D, $050E, $0608, $0609, $060A, $060B, $060C, $060D,
    $060E, $0708, $0709, $070A, $070B, $070C, $070D, $070E,
    $08F2, $08F3, $08F4, $08F5, $08F6, $08F7, $08F8, $08F9,
    $08FA, $08FB, $08FC, $08FD, $08FE, $08FF, $0800, $0801,
    $0802, $0803, $0804, $0805, $0806, $0807, $0808, $0809,
    $080A, $080B, $080C, $080D, $080E, $09F2, $09F3, $09F4,
    $09F5, $09F6, $09F7, $09F8, $09F9, $09FA, $09FB, $09FC,
    $09FD, $09FE, $09FF, $0900, $0901, $0902, $0903, $0904,
    $0905, $0906, $0907, $0908, $0909, $090A, $090B, $090C,
    $090D, $090E, $0AF2, $0AF3, $0AF4, $0AF5, $0AF6, $0AF7,
    $0AF8, $0AF9, $0AFA, $0AFB, $0AFC, $0AFD, $0AFE, $0AFF,
    $0A00, $0A01, $0A02, $0A03, $0A04, $0A05, $0A06, $0A07,
    $0A08, $0A09, $0A0A, $0A0B, $0A0C, $0A0D, $0A0E, $0BF2,
    $0BF3, $0BF4, $0BF5, $0BF6, $0BF7, $0BF8, $0BF9, $0BFA,
    $0BFB, $0BFC, $0BFD, $0BFE, $0BFF, $0B00, $0B01, $0B02,
    $0B03, $0B04, $0B05, $0B06, $0B07, $0B08, $0B09, $0B0A,
    $0B0B, $0B0C, $0B0D, $0B0E, $0CF2, $0CF3, $0CF4, $0CF5,
    $0CF6, $0CF7, $0CF8, $0CF9, $0CFA, $0CFB, $0CFC, $0CFD,
    $0CFE, $0CFF, $0C00, $0C01, $0C02, $0C03, $0C04, $0C05,
    $0C06, $0C07, $0C08, $0C09, $0C0A, $0C0B, $0C0C, $0C0D,
    $0C0E, $0DF2, $0DF3, $0DF4, $0DF5, $0DF6, $0DF7, $0DF8,
    $0DF9, $0DFA, $0DFB, $0DFC, $0DFD, $0DFE, $0DFF, $0D00,
    $0D01, $0D02, $0D03, $0D04, $0D05, $0D06, $0D07, $0D08,
    $0D09, $0D0A, $0D0B, $0D0C, $0D0D, $0D0E, $0EF2, $0EF3,
    $0EF4, $0EF5, $0EF6, $0EF7, $0EF8, $0EF9, $0EFA, $0EFB,
    $0EFC, $0EFD, $0EFE, $0EFF, $0E00, $0E01, $0E02, $0E03,
    $0E04, $0E05, $0E06, $0E07, $0E08, $0E09, $0E0A, $0E0B
  );

  _dollar_R0053: array[0..15] of LongWord = (
    $C3C3C3C3, $C3C3C1C3, $C3C3C3C1, $C3C3C1C1, $C1C3C3C3, $C1C3C1C3, $C1C3C3C1, $C1C3C1C1,
    $C3C1C3C3, $C3C1C1C3, $C3C1C3C1, $C3C1C1C1, $C1C1C3C3, $C1C1C1C3, $C1C1C3C1, $C1C1C1C1
  );

  _dollar_R0004: array[0..255] of LongWord = (
    $C3C3C3C3, $C3C3C2C3, $C3C3C1C3, $C3C3C5C3, $C3C3C3C2, $C3C3C2C2, $C3C3C1C2, $C3C3C5C2,
    $C3C3C3C1, $C3C3C2C1, $C3C3C1C1, $C3C3C5C1, $C3C3C3C5, $C3C3C2C5, $C3C3C1C5, $C3C3C5C5,
    $C2C3C3C3, $C2C3C2C3, $C2C3C1C3, $C2C3C5C3, $C2C3C3C2, $C2C3C2C2, $C2C3C1C2, $C2C3C5C2,
    $C2C3C3C1, $C2C3C2C1, $C2C3C1C1, $C2C3C5C1, $C2C3C3C5, $C2C3C2C5, $C2C3C1C5, $C2C3C5C5,
    $C1C3C3C3, $C1C3C2C3, $C1C3C1C3, $C1C3C5C3, $C1C3C3C2, $C1C3C2C2, $C1C3C1C2, $C1C3C5C2,
    $C1C3C3C1, $C1C3C2C1, $C1C3C1C1, $C1C3C5C1, $C1C3C3C5, $C1C3C2C5, $C1C3C1C5, $C1C3C5C5,
    $C5C3C3C3, $C5C3C2C3, $C5C3C1C3, $C5C3C5C3, $C5C3C3C2, $C5C3C2C2, $C5C3C1C2, $C5C3C5C2,
    $C5C3C3C1, $C5C3C2C1, $C5C3C1C1, $C5C3C5C1, $C5C3C3C5, $C5C3C2C5, $C5C3C1C5, $C5C3C5C5,
    $C3C2C3C3, $C3C2C2C3, $C3C2C1C3, $C3C2C5C3, $C3C2C3C2, $C3C2C2C2, $C3C2C1C2, $C3C2C5C2,
    $C3C2C3C1, $C3C2C2C1, $C3C2C1C1, $C3C2C5C1, $C3C2C3C5, $C3C2C2C5, $C3C2C1C5, $C3C2C5C5,
    $C2C2C3C3, $C2C2C2C3, $C2C2C1C3, $C2C2C5C3, $C2C2C3C2, $C2C2C2C2, $C2C2C1C2, $C2C2C5C2,
    $C2C2C3C1, $C2C2C2C1, $C2C2C1C1, $C2C2C5C1, $C2C2C3C5, $C2C2C2C5, $C2C2C1C5, $C2C2C5C5,
    $C1C2C3C3, $C1C2C2C3, $C1C2C1C3, $C1C2C5C3, $C1C2C3C2, $C1C2C2C2, $C1C2C1C2, $C1C2C5C2,
    $C1C2C3C1, $C1C2C2C1, $C1C2C1C1, $C1C2C5C1, $C1C2C3C5, $C1C2C2C5, $C1C2C1C5, $C1C2C5C5,
    $C5C2C3C3, $C5C2C2C3, $C5C2C1C3, $C5C2C5C3, $C5C2C3C2, $C5C2C2C2, $C5C2C1C2, $C5C2C5C2,
    $C5C2C3C1, $C5C2C2C1, $C5C2C1C1, $C5C2C5C1, $C5C2C3C5, $C5C2C2C5, $C5C2C1C5, $C5C2C5C5,
    $C3C1C3C3, $C3C1C2C3, $C3C1C1C3, $C3C1C5C3, $C3C1C3C2, $C3C1C2C2, $C3C1C1C2, $C3C1C5C2,
    $C3C1C3C1, $C3C1C2C1, $C3C1C1C1, $C3C1C5C1, $C3C1C3C5, $C3C1C2C5, $C3C1C1C5, $C3C1C5C5,
    $C2C1C3C3, $C2C1C2C3, $C2C1C1C3, $C2C1C5C3, $C2C1C3C2, $C2C1C2C2, $C2C1C1C2, $C2C1C5C2,
    $C2C1C3C1, $C2C1C2C1, $C2C1C1C1, $C2C1C5C1, $C2C1C3C5, $C2C1C2C5, $C2C1C1C5, $C2C1C5C5,
    $C1C1C3C3, $C1C1C2C3, $C1C1C1C3, $C1C1C5C3, $C1C1C3C2, $C1C1C2C2, $C1C1C1C2, $C1C1C5C2,
    $C1C1C3C1, $C1C1C2C1, $C1C1C1C1, $C1C1C5C1, $C1C1C3C5, $C1C1C2C5, $C1C1C1C5, $C1C1C5C5,
    $C5C1C3C3, $C5C1C2C3, $C5C1C1C3, $C5C1C5C3, $C5C1C3C2, $C5C1C2C2, $C5C1C1C2, $C5C1C5C2,
    $C5C1C3C1, $C5C1C2C1, $C5C1C1C1, $C5C1C5C1, $C5C1C3C5, $C5C1C2C5, $C5C1C1C5, $C5C1C5C5,
    $C3C5C3C3, $C3C5C2C3, $C3C5C1C3, $C3C5C5C3, $C3C5C3C2, $C3C5C2C2, $C3C5C1C2, $C3C5C5C2,
    $C3C5C3C1, $C3C5C2C1, $C3C5C1C1, $C3C5C5C1, $C3C5C3C5, $C3C5C2C5, $C3C5C1C5, $C3C5C5C5,
    $C2C5C3C3, $C2C5C2C3, $C2C5C1C3, $C2C5C5C3, $C2C5C3C2, $C2C5C2C2, $C2C5C1C2, $C2C5C5C2,
    $C2C5C3C1, $C2C5C2C1, $C2C5C1C1, $C2C5C5C1, $C2C5C3C5, $C2C5C2C5, $C2C5C1C5, $C2C5C5C5,
    $C1C5C3C3, $C1C5C2C3, $C1C5C1C3, $C1C5C5C3, $C1C5C3C2, $C1C5C2C2, $C1C5C1C2, $C1C5C5C2,
    $C1C5C3C1, $C1C5C2C1, $C1C5C1C1, $C1C5C5C1, $C1C5C3C5, $C1C5C2C5, $C1C5C1C5, $C1C5C5C5,
    $C5C5C3C3, $C5C5C2C3, $C5C5C1C3, $C5C5C5C3, $C5C5C3C2, $C5C5C2C2, $C5C5C1C2, $C5C5C5C2,
    $C5C5C3C1, $C5C5C2C1, $C5C5C1C1, $C5C5C5C1, $C5C5C3C5, $C5C5C2C5, $C5C5C1C5, $C5C5C5C5
  );

  _dollar_R0063: array[0..255] of LongWord = (
    $E3C3E3C3, $E3C7E3C3, $E3C1E3C3, $E3C5E3C3, $E7C3E3C3, $E7C7E3C3, $E7C1E3C3, $E7C5E3C3,
    $E1C3E3C3, $E1C7E3C3, $E1C1E3C3, $E1C5E3C3, $E5C3E3C3, $E5C7E3C3, $E5C1E3C3, $E5C5E3C3,
    $E3C3E3C7, $E3C7E3C7, $E3C1E3C7, $E3C5E3C7, $E7C3E3C7, $E7C7E3C7, $E7C1E3C7, $E7C5E3C7,
    $E1C3E3C7, $E1C7E3C7, $E1C1E3C7, $E1C5E3C7, $E5C3E3C7, $E5C7E3C7, $E5C1E3C7, $E5C5E3C7,
    $E3C3E3C1, $E3C7E3C1, $E3C1E3C1, $E3C5E3C1, $E7C3E3C1, $E7C7E3C1, $E7C1E3C1, $E7C5E3C1,
    $E1C3E3C1, $E1C7E3C1, $E1C1E3C1, $E1C5E3C1, $E5C3E3C1, $E5C7E3C1, $E5C1E3C1, $E5C5E3C1,
    $E3C3E3C5, $E3C7E3C5, $E3C1E3C5, $E3C5E3C5, $E7C3E3C5, $E7C7E3C5, $E7C1E3C5, $E7C5E3C5,
    $E1C3E3C5, $E1C7E3C5, $E1C1E3C5, $E1C5E3C5, $E5C3E3C5, $E5C7E3C5, $E5C1E3C5, $E5C5E3C5,
    $E3C3E7C3, $E3C7E7C3, $E3C1E7C3, $E3C5E7C3, $E7C3E7C3, $E7C7E7C3, $E7C1E7C3, $E7C5E7C3,
    $E1C3E7C3, $E1C7E7C3, $E1C1E7C3, $E1C5E7C3, $E5C3E7C3, $E5C7E7C3, $E5C1E7C3, $E5C5E7C3,
    $E3C3E7C7, $E3C7E7C7, $E3C1E7C7, $E3C5E7C7, $E7C3E7C7, $E7C7E7C7, $E7C1E7C7, $E7C5E7C7,
    $E1C3E7C7, $E1C7E7C7, $E1C1E7C7, $E1C5E7C7, $E5C3E7C7, $E5C7E7C7, $E5C1E7C7, $E5C5E7C7,
    $E3C3E7C1, $E3C7E7C1, $E3C1E7C1, $E3C5E7C1, $E7C3E7C1, $E7C7E7C1, $E7C1E7C1, $E7C5E7C1,
    $E1C3E7C1, $E1C7E7C1, $E1C1E7C1, $E1C5E7C1, $E5C3E7C1, $E5C7E7C1, $E5C1E7C1, $E5C5E7C1,
    $E3C3E7C5, $E3C7E7C5, $E3C1E7C5, $E3C5E7C5, $E7C3E7C5, $E7C7E7C5, $E7C1E7C5, $E7C5E7C5,
    $E1C3E7C5, $E1C7E7C5, $E1C1E7C5, $E1C5E7C5, $E5C3E7C5, $E5C7E7C5, $E5C1E7C5, $E5C5E7C5,
    $E3C3E1C3, $E3C7E1C3, $E3C1E1C3, $E3C5E1C3, $E7C3E1C3, $E7C7E1C3, $E7C1E1C3, $E7C5E1C3,
    $E1C3E1C3, $E1C7E1C3, $E1C1E1C3, $E1C5E1C3, $E5C3E1C3, $E5C7E1C3, $E5C1E1C3, $E5C5E1C3,
    $E3C3E1C7, $E3C7E1C7, $E3C1E1C7, $E3C5E1C7, $E7C3E1C7, $E7C7E1C7, $E7C1E1C7, $E7C5E1C7,
    $E1C3E1C7, $E1C7E1C7, $E1C1E1C7, $E1C5E1C7, $E5C3E1C7, $E5C7E1C7, $E5C1E1C7, $E5C5E1C7,
    $E3C3E1C1, $E3C7E1C1, $E3C1E1C1, $E3C5E1C1, $E7C3E1C1, $E7C7E1C1, $E7C1E1C1, $E7C5E1C1,
    $E1C3E1C1, $E1C7E1C1, $E1C1E1C1, $E1C5E1C1, $E5C3E1C1, $E5C7E1C1, $E5C1E1C1, $E5C5E1C1,
    $E3C3E1C5, $E3C7E1C5, $E3C1E1C5, $E3C5E1C5, $E7C3E1C5, $E7C7E1C5, $E7C1E1C5, $E7C5E1C5,
    $E1C3E1C5, $E1C7E1C5, $E1C1E1C5, $E1C5E1C5, $E5C3E1C5, $E5C7E1C5, $E5C1E1C5, $E5C5E1C5,
    $E3C3E5C3, $E3C7E5C3, $E3C1E5C3, $E3C5E5C3, $E7C3E5C3, $E7C7E5C3, $E7C1E5C3, $E7C5E5C3,
    $E1C3E5C3, $E1C7E5C3, $E1C1E5C3, $E1C5E5C3, $E5C3E5C3, $E5C7E5C3, $E5C1E5C3, $E5C5E5C3,
    $E3C3E5C7, $E3C7E5C7, $E3C1E5C7, $E3C5E5C7, $E7C3E5C7, $E7C7E5C7, $E7C1E5C7, $E7C5E5C7,
    $E1C3E5C7, $E1C7E5C7, $E1C1E5C7, $E1C5E5C7, $E5C3E5C7, $E5C7E5C7, $E5C1E5C7, $E5C5E5C7,
    $E3C3E5C1, $E3C7E5C1, $E3C1E5C1, $E3C5E5C1, $E7C3E5C1, $E7C7E5C1, $E7C1E5C1, $E7C5E5C1,
    $E1C3E5C1, $E1C7E5C1, $E1C1E5C1, $E1C5E5C1, $E5C3E5C1, $E5C7E5C1, $E5C1E5C1, $E5C5E5C1,
    $E3C3E5C5, $E3C7E5C5, $E3C1E5C5, $E3C5E5C5, $E7C3E5C5, $E7C7E5C5, $E7C1E5C5, $E7C5E5C5,
    $E1C3E5C5, $E1C7E5C5, $E1C1E5C5, $E1C5E5C5, $E5C3E5C5, $E5C7E5C5, $E5C1E5C5, $E5C5E5C5
  );

  // movie_lib.cc global variables
  dword_6B3660: Integer = 0;
  _sf_ScreenWidth: Integer = 0;
  dword_6B3680: Integer = 0;
  _rm_FrameDropCount: Integer = 0;
  _snd_buf: Integer = 0;
  _io_mem_buf: TSTRUCT_6B3690;
  _io_next_hdr: Integer = 0;
  dword_6B36A0: Integer = 0;
  dword_6B36A4: LongWord = 0;
  _rm_FrameCount: Integer = 0;
  _sf_ScreenHeight: Integer = 0;
  dword_6B36B0: Integer = 0;
  _palette_entries1: array[0..767] of Byte;
  gMovieLibMallocProc: TMveMallocFunc = nil;
  _rm_ctl: Pointer = nil;
  _rm_dx: Integer = 0;
  _rm_dy: Integer = 0;
  _gSoundTimeBase: Integer = 0;
  _io_handle: Pointer = nil;
  _rm_len: Integer = 0;
  gMovieLibFreeProc: TMveFreeFunc = nil;
  _snd_comp: Integer = 0;
  _rm_p: PByte = nil;
  dword_6B39E0: array[0..59] of Integer;
  _sync_wait_quanta: Integer = 0;
  dword_6B3AD4: Integer = 0;
  _rm_track_bit: Integer = 0;
  _sync_time: Integer = 0;
  gMovieLibReadProc: TMovieReadProc = nil;
  dword_6B3AE4: Integer = 0;
  dword_6B3AE8: Integer = 0;
  dword_6B3CEC: Integer = 0;
  dword_6B3CF0: Integer = 0;
  dword_6B3CF4: Integer = 0;
  dword_6B3CF8: Integer = 0;
  _mveBW: Integer = 0;
  dword_6B3D00: Integer = 0;
  dword_6B3D04: Integer = 0;
  dword_6B3D08: Integer = 0;
  _pal_tbl: array[0..767] of Byte;
  byte_6B400C: Byte = 0;
  byte_6B400D: Byte = 0;
  dword_6B400E: Integer = 0;
  dword_6B4012: Integer = 0;
  byte_6B4016: Byte = 0;
  dword_6B4017: Integer = 0;
  dword_6B401B: Integer = 0;
  dword_6B401F: Integer = 0;
  dword_6B4023: Integer = 0;
  dword_6B4027: Integer = 0;
  dword_6B402B: Integer = 0;
  _mveBH: Integer = 0;
  gMovieDirectDrawSurfaceBuffer1: PByte = nil;
  gMovieDirectDrawSurfaceBuffer2: PByte = nil;
  dword_6B403B: Integer = 0;
  dword_6B403F: Integer = 0;

  gMovieSdlSurface1: PSDL_Surface = nil;
  gMovieSdlSurface2: PSDL_Surface = nil;
  gMveSoundBuffer: Integer = -1;
  gMveBufferBytes: LongWord = 0;

// ===================================================================
// movie.cc static variables
// ===================================================================
var
  GNWWin: Integer = -1;
  subtitleFont: Integer = -1;
  paletteFunc: TMoviePaletteFunc = nil;
  subtitleR: Integer = 31;
  subtitleG: Integer = 31;
  subtitleB: Integer = 31;
  winRect_: TRect;
  movieRect_: TRect;
  movieCallback_: TMovieCallback = nil;
  endMovieFunc: TMovieEndFunc = nil;
  updateCallbackFunc: TMovieUpdateCallbackProc = nil;
  failedOpenFunc: TMovieFailedOpenFunc = nil;
  subtitleFilenameFunc: TMovieSubtitleFunc = nil;
  startMovieFunc: TMovieStartFunc = nil;
  subtitleW: Integer = 0;
  lastMovieBH: Integer = 0;
  lastMovieBW: Integer = 0;
  lastMovieSX: Integer = 0;
  lastMovieSY: Integer = 0;
  movieScaleFlag: Integer = 0;
  preDrawFunc: TMoviePreDrawFunc = nil;
  lastMovieH: Integer = 0;
  lastMovieW: Integer = 0;
  lastMovieX: Integer = 0;
  lastMovieY_: Integer = 0;
  subtitleList: PMovieSubtitleListNode = nil;
  movieFlags_: LongWord = 0;
  movieAlphaFlag: Integer = 0;
  movieSubRectFlag: Integer = 0;
  movieH_: Integer = 0;
  movieOffset_: Integer = 0;
  movieCaptureFrameFunc: TMovieCaptureFrameProc = nil;
  lastMovieBuffer: PByte = nil;
  movieW_: Integer = 0;
  movieFrameGrabFunc: TMovieFrameGrabProc = nil;
  subtitleH: Integer = 0;
  running_: Integer = 0;
  handle_: PDB_FILE = nil;
  alphaWindowBuf: PByte = nil;
  movieX_: Integer = 0;
  movieY_: Integer = 0;
  alphaHandle_: PDB_FILE = nil;
  alphaBuf_: PByte = nil;
  gMovieSdlSurface_movie: PSDL_Surface = nil;

// ===================================================================
// Forward declarations - movie_lib.cc internal functions
// ===================================================================
procedure _MVE_MemInit(a1: PSTRUCT_6B3690; a2: Integer; a3: Pointer); forward;
procedure _MVE_MemFree(a1: PSTRUCT_6B3690); forward;
procedure _do_nothing_2(a1: PSDL_Surface; a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl; forward;
function _sub_4F4B5: Integer; forward;
function _ioReset(ahandle: Pointer): Integer; forward;
function _ioRead(size: Integer): Pointer; forward;
function _MVE_MemAlloc(a1: PSTRUCT_6B3690; a2: LongWord): Pointer; forward;
function _ioNextRecord: PByte; forward;
procedure _sub_4F4DD; forward;
function _MVE_rmHoldMovie: Integer; forward;
function _syncWait: Integer; forward;
procedure _MVE_sndPause; forward;
function _syncInit(a1, a2: Integer): Integer; forward;
procedure _syncReset(a1: Integer); forward;
function _MVE_sndConfigure(a1, a2, a3, a4, a5, a6: Integer): Integer; forward;
procedure _MVE_syncSync; forward;
procedure _MVE_sndReset; forward;
procedure _MVE_sndSync; forward;
function _syncWaitLevel(a1: Integer): Integer; forward;
procedure _CallsSndBuff_Loc(a1: PByte; a2: Integer); forward;
function _MVE_sndAdd(dest: PByte; src_ptr: PPByte; a3, a4, a5: Integer): Integer; forward;
procedure _MVE_sndResume; forward;
function _nfConfig(a1, a2, a3, a4: Integer): Integer; forward;
function movieLockSurfaces: Boolean; forward;
procedure movieUnlockSurfaces; forward;
procedure movieSwapSurfaces; forward;
procedure _sfShowFrame(a1, a2, a3: Integer); forward;
procedure _do_nothing_(a1, a2: Integer; a3: PWord); forward;
procedure _SetPalette_1(a1, a2: Integer); forward;
procedure _SetPalette_(a1, a2: Integer); forward;
procedure _palMakeSynthPalette(a1, a2, a3, a4, a5, a6: Integer); forward;
procedure _palLoadPalette(palette: PByte; a2, a3: Integer); forward;
procedure _syncRelease; forward;
procedure _ioRelease; forward;
procedure _MVE_sndRelease; forward;
procedure _nfRelease; forward;
procedure _frLoad(a1: PSTRUCT_4F6930); forward;
procedure _frSave(a1: PSTRUCT_4F6930); forward;
procedure _MVE_frClose(a1: PSTRUCT_4F6930); forward;
function _MVE_sndDecompM16(a1: PWord; a2: PByte; a3, a4: Integer): Integer; forward;
function _MVE_sndDecompS16(a1: PWord; a2: PByte; a3, a4: Integer): Integer; forward;
procedure _nfPkConfig; forward;
procedure _nfPkDecomp(a1, a2: PByte; a3, a4, a5, a6: Integer); forward;

// ===================================================================
// Forward declarations - movie.cc internal functions
// ===================================================================
function movieMalloc(size: SizeUInt): Pointer; cdecl; forward;
procedure movieFree(ptr: Pointer); cdecl; forward;
function movieRead(ahandle: Pointer; buf: Pointer; count: Integer): Boolean; cdecl; forward;
procedure movie_MVE_ShowFrame(surface: PSDL_Surface; srcWidth, srcHeight, srcX, srcY, destWidth, destHeight, a8, a9: Integer); cdecl; forward;
procedure movieShowFrame(a1: PSDL_Surface; a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl; forward;
function movieScaleSubRect(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
function movieScaleWindowAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
function movieScaleSubRectAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
function blitAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
function movieScaleWindow(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
function blitNormal(win: Integer; data: PByte; width, height, pitch: Integer): Integer; forward;
procedure movieSetPalette_internal(palette: PByte; start, end_: Integer); cdecl; forward;
function noop: Integer; forward;
procedure cleanupMovie(a1: Integer); forward;
procedure cleanupLast; forward;
function openFile(filePath: PAnsiChar): PDB_FILE; forward;
procedure openSubtitle(filePath: PAnsiChar); forward;
procedure doSubtitle; forward;
function movieStart(win: Integer; filePath: PAnsiChar; a3: Pointer): Integer; forward;
function localMovieCallback: Boolean; forward;
function stepMovie_internal: Integer; forward;

// Utility functions
function loadUInt16LE(b: PByte): Word; inline;
begin
  Result := PWord(b)^;
end;

function loadUInt32LE(b: PByte): LongWord; inline;
begin
  Result := PLongWord(b)^;
end;

function getOffset(v: Word): PtrInt;
begin
  Result := PtrInt(ShortInt(v and $FF)) + PtrInt(dword_51F018[v shr 8]);
end;

// ===================================================================
// movie.cc - showFrameFuncs array (initialized in initialization section)
// ===================================================================
var
  showFrameFuncs: array[0..1, 0..1, 0..1] of TMovieBlitFunc;

// ===================================================================
// movie_lib.cc implementation
// ===================================================================

procedure movieLibSetMemoryProcs(mallocProc: TMveMallocFunc; freeProc: TMveFreeFunc);
begin
  gMovieLibMallocProc := mallocProc;
  gMovieLibFreeProc := freeProc;
end;

procedure movieLibSetReadProc(readProc: TMovieReadProc);
begin
  gMovieLibReadProc := readProc;
end;

procedure _MVE_MemInit(a1: PSTRUCT_6B3690; a2: Integer; a3: Pointer);
begin
  if a3 = nil then
    Exit;

  _MVE_MemFree(a1);

  a1^.field_0 := a3;
  a1^.field_4 := a2;
  a1^.field_8 := 0;
end;

procedure _MVE_MemFree(a1: PSTRUCT_6B3690);
begin
  if (a1^.field_8 <> 0) and Assigned(gMovieLibFreeProc) then
  begin
    gMovieLibFreeProc(a1^.field_0);
    a1^.field_8 := 0;
  end;
  a1^.field_4 := 0;
end;

procedure movieLibSetVolume(volume: Integer);
begin
  gMovieLibVolume := volume;

  if gMveSoundBuffer <> -1 then
    audioEngineSoundBufferSetVolume(gMveSoundBuffer, volume);
end;

procedure movieLibSetPan(pan: Integer);
begin
  gMovieLibPan := pan;

  if gMveSoundBuffer <> -1 then
    audioEngineSoundBufferSetPan(gMveSoundBuffer, pan);
end;

procedure _MVE_sfSVGA(a1, a2, a3, a4, a5, a6, a7, a8, a9: Integer);
begin
  _sf_ScreenWidth := a1;
  _sf_ScreenHeight := a2;
  dword_6B3AD4 := a1;
  dword_6B36B0 := a2;
  dword_6B3D04 := a3;
  if (dword_51EBD8 and 4) <> 0 then
    dword_6B3D04 := 2 * a3;
  dword_6B403F := a4;
  dword_6B3CF4 := a6;
  dword_6B400E := a5;
  dword_6B403B := a7;
  dword_6B3CF0 := a6 + a5;
  dword_6B3D08 := a8;
  if a7 <> 0 then
    dword_6B4012 := a6 div a7
  else
    dword_6B4012 := 1;
  dword_51EE0C := 0;
  dword_6B3680 := a9;
end;

procedure _MVE_sfCallbacks(proc: TMovieShowFrameProc);
begin
  _sf_ShowFrame := proc;
end;

procedure _do_nothing_2(a1: PSDL_Surface; a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl;
begin
  // empty
end;

procedure movieLibSetPaletteEntriesProc(fn: TMoviePaletteFunc);
begin
  _pal_SetPalette := fn;
end;

function _sub_4F4B5: Integer;
begin
  Result := 0;
end;

procedure _MVE_rmCallbacks(fn: Pointer);
begin
  _rm_ctl := fn;
end;

procedure _sub_4F4BB(a1: Integer);
begin
  if a1 = 3 then
    dword_51EBDC := 3
  else
    dword_51EBDC := 4;
end;

procedure _MVE_rmFrameCounts(a1, a2: PInteger);
begin
  a1^ := _rm_FrameCount;
  a2^ := _rm_FrameDropCount;
end;

function _MVE_rmPrepMovie(handle: Pointer; a2, a3: Integer; a4: AnsiChar): Integer;
begin
  _sub_4F4DD;

  _rm_dx := a2;
  _rm_dy := a3;
  _rm_track_bit := 1 shl Ord(a4);

  if _rm_track_bit = 0 then
    _rm_track_bit := 1;

  if _ioReset(handle) = 0 then
  begin
    _MVE_rmEndMovie;
    Exit(-8);
  end;

  _rm_p := _ioNextRecord;
  _rm_len := 0;

  if _rm_p = nil then
  begin
    _MVE_rmEndMovie;
    Exit(-2);
  end;

  _rm_active := 1;
  _rm_hold := 0;
  _rm_FrameCount := 0;
  _rm_FrameDropCount := 0;

  Result := 0;
end;

function _ioReset(ahandle: Pointer): Integer;
var
  mve: ^TMve;
begin
  _io_handle := ahandle;

  mve := _ioRead(SizeOf(TMve));
  if mve = nil then
    Exit(0);

  if StrLComp(@mve^.sig[0], 'Interplay MVE File'#$1A#$00, 20) <> 0 then
    Exit(0);

  if (not mve^.field_16) - mve^.field_18 <> SmallInt($EDCC) then
    Exit(0);

  if mve^.field_16 <> 256 then
    Exit(0);

  if mve^.field_14 <> 26 then
    Exit(0);

  _io_next_hdr := mve^.field_1A;

  Result := 1;
end;

function _ioRead(size: Integer): Pointer;
var
  buf: Pointer;
begin
  buf := _MVE_MemAlloc(@_io_mem_buf, size);
  if buf = nil then
  begin
    WriteLn(StdErr, '[MVE] _ioRead: MemAlloc failed for size=', size);
    Exit(nil);
  end;

  if not gMovieLibReadProc(_io_handle, buf, size) then
  begin
    WriteLn(StdErr, '[MVE] _ioRead: read failed for size=', size);
    Result := nil;
  end
  else
    Result := buf;
end;

function _MVE_MemAlloc(a1: PSTRUCT_6B3690; a2: LongWord): Pointer;
var
  ptr: Pointer;
begin
  if a1^.field_4 >= a2 then
    Exit(a1^.field_0);

  if not Assigned(gMovieLibMallocProc) then
    Exit(nil);

  _MVE_MemFree(a1);

  ptr := gMovieLibMallocProc(a2 + 100);
  if ptr = nil then
    Exit(nil);

  _MVE_MemInit(a1, a2 + 100, ptr);

  a1^.field_8 := 1;

  Result := a1^.field_0;
end;

function _ioNextRecord: PByte;
var
  buf: PByte;
begin
  buf := PByte(_ioRead((_io_next_hdr and $FFFF) + 4));
  if buf = nil then
    Exit(nil);

  _io_next_hdr := loadUInt32LE(buf + (_io_next_hdr and $FFFF));

  Result := buf;
end;

procedure _sub_4F4DD;
begin
  if dword_51EE20 then
    Exit;

  // TODO: Incomplete.

  dword_51EE20 := True;
end;

function _MVE_rmHoldMovie: Integer;
begin
  if _rm_hold = 0 then
  begin
    _MVE_sndPause;
    _rm_hold := 1;
  end;
  _syncWait;
  Result := 0;
end;

function _syncWait: Integer;
begin
  Result := 0;
  if _sync_active <> 0 then
  begin
    if ((_sync_time + 1000 * Integer(compat_timeGetTime)) and Integer($80000000)) <> 0 then
    begin
      Result := 1;
      while ((_sync_time + 1000 * Integer(compat_timeGetTime)) and Integer($80000000)) <> 0 do
        ;
    end;
    _sync_time := _sync_time + _sync_wait_quanta;
    if (_rm_FrameCount <= 10) or ((_rm_FrameCount mod 50) = 0) then
      WriteLn(StdErr, '[SYNCWAIT] frame=', _rm_FrameCount, ' sync_time=', _sync_time, ' t=', compat_timeGetTime);
  end;
end;

procedure _MVE_sndPause;
begin
  if gMveSoundBuffer <> -1 then
    audioEngineSoundBufferStop(gMveSoundBuffer);
end;

function _MVE_rmStepMovie: Integer;
var
  v0: Integer;
  v1: PWord;
  v5: LongWord;
  v6, v7, v8, v9, v10, v11, v12, v13: Integer;
  v3, v21: PWord;
  v18, v19, v20: Integer;
  v14: PByte;
  dumpF: File;
  dumpI: Integer;
  dumpPal: PSDL_Palette;
  chk_sum: LongWord;
  chk_i: Integer;
begin
  v0 := _rm_len;
  v1 := PWord(_rm_p);

  if _rm_active = 0 then
    Exit(-10);

  if _rm_hold <> 0 then
  begin
    _MVE_sndResume;
    _rm_hold := 0;
  end;

  // LABEL_5
  while True do
  begin
    v21 := nil;
    v3 := nil;
    if v1 = nil then
    begin
      WriteLn(StdErr, '[MVE] v1=nil, ending movie with -2, frames=', _rm_FrameCount);
      _MVE_rmEndMovie;
      Exit(-2);
    end;

    while True do
    begin
      v5 := loadUInt32LE(PByte(v1) + v0);
      v1 := PWord(PByte(v1) + v0 + 4);
      v0 := v5 and $FFFF;

      if _rm_FrameCount < 3 then
        WriteLn(StdErr, '[MVE] opcode=', (v5 shr 16) and $FF, ' len=', v0, ' ver=', v5 shr 24);

      case (v5 shr 16) and $FF of
        0: begin
          WriteLn(StdErr, '[MVE] opcode 0 (end), frames=', _rm_FrameCount);
          _MVE_rmEndMovie;
          Exit(-1);
        end;
        1: begin
          v0 := 0;
          v1 := PWord(_ioNextRecord);
          if v1 = nil then
            WriteLn(StdErr, '[MVE] case 1: _ioNextRecord returned nil, frames=', _rm_FrameCount);
          Break; // goto LABEL_5
        end;
        2: begin
          WriteLn(StdErr, '[MVE] opcode2: a1=', v1[0], ' a2=', v1[2], ' frame=', _rm_FrameCount);
          if _syncInit(v1[0], v1[2]) = 0 then
          begin
            _MVE_rmEndMovie;
            Exit(-3);
          end;
          Continue;
        end;
        3: begin
          if (v5 shr 24) < 1 then
            v7 := 0
          else
            v7 := (v1[1] and $04) shr 2;
          v8 := loadUInt32LE(PByte(v1) + 6);
          if (v5 shr 24) = 0 then
            v8 := v8 and $FFFF;

          if _MVE_sndConfigure(v1[0], v8, v1[1] and $01, v1[2], (v1[1] and $02) shr 1, v7) <> 0 then
            Continue;

          _MVE_rmEndMovie;
          Exit(-4);
        end;
        4: begin
          _MVE_sndSync;
          Continue;
        end;
        5: begin
          v9 := 0;
          if (v5 shr 24) >= 2 then
            v9 := v1[3];

          v10 := 1;
          if (v5 shr 24) >= 1 then
            v10 := v1[2];

          if _nfConfig(v1[0], v1[1], v10, v9) = 0 then
          begin
            _MVE_rmEndMovie;
            Exit(-5);
          end;

          v11 := (4 * _mveBW div dword_51EBDC) and Integer($FFFFFFF0);
          if dword_6B4027 <> 0 then
            v11 := v11 shr 1;

          v12 := _rm_dx;
          if v12 < 0 then
            v12 := 0;

          if v11 + v12 > _sf_ScreenWidth then
          begin
            _MVE_rmEndMovie;
            Exit(-6);
          end;

          v13 := _rm_dy;
          if v13 < 0 then
            v13 := 0;

          if _mveBH + v13 > _sf_ScreenHeight then
          begin
            _MVE_rmEndMovie;
            Exit(-6);
          end;

          if (dword_6B4027 <> 0) and (dword_6B3680 = 0) then
          begin
            _MVE_rmEndMovie;
            Exit(-6);
          end;

          Continue;
        end;
        7: begin
          Inc(_rm_FrameCount);
          if (_rm_FrameCount <= 5) or ((_rm_FrameCount mod 50) = 0) then
            WriteLn(StdErr, '[MVE] frame ', _rm_FrameCount, ' t=', compat_timeGetTime);

          // DEBUG: dump frame 430 pixels and palette
          if (_rm_FrameCount = 100) and (not FileExists('/tmp/frame100_pas.raw')) then
          begin
            // Dump pixel data (first movie only)
            if gMovieSdlSurface1 <> nil then
            begin
              Assign(dumpF, '/tmp/frame100_pas.raw');
              Rewrite(dumpF, 1);
              for dumpI := 0 to gMovieSdlSurface1^.h - 1 do
                BlockWrite(dumpF, PByte(gMovieSdlSurface1^.pixels)[dumpI * gMovieSdlSurface1^.pitch], gMovieSdlSurface1^.w);
              Close(dumpF);
              WriteLn(StdErr, '[DEBUG] Dumped frame 100: ', gMovieSdlSurface1^.w, 'x', gMovieSdlSurface1^.h, ' pitch=', gMovieSdlSurface1^.pitch);
              // Dump palette
              dumpPal := gMovieSdlSurface1^.format^.palette;
              if dumpPal <> nil then
              begin
                Assign(dumpF, '/tmp/frame100_pas.pal');
                Rewrite(dumpF, 1);
                BlockWrite(dumpF, dumpPal^.colors^, dumpPal^.ncolors * SizeOf(TSDL_Color));
                Close(dumpF);
                WriteLn(StdErr, '[DEBUG] Dumped palette: ', dumpPal^.ncolors, ' colors');
              end;
            end;
          end;

          v18 := 0;
          if (v5 shr 24) >= 1 then
            v18 := v1[2];

          v19 := v1[1];
          // Palette checksum before applying
          chk_sum := 0;
          for chk_i := 0 to 767 do
            chk_sum := chk_sum + _pal_tbl[chk_i];
          WriteLn(StdErr, '[PCHK] frame=', _rm_FrameCount, ' pal_sum=', chk_sum,
            ' start=', v1[0], ' count=', v19,
            ' path=', Ord((v19 = 0) or (v21 <> nil) or (dword_6B3680 <> 0)));

          if (v19 = 0) or (v21 <> nil) or (dword_6B3680 <> 0) then
            _SetPalette_1(v1[0], v19)
          else
            _SetPalette_(v1[0], v19);

          if v21 <> nil then
            _do_nothing_(_rm_dx, _rm_dy, v21)
          else if (_sync_late = 0) or (v1[1] <> 0) then
            _sfShowFrame(_rm_dx, _rm_dy, v18)
          else
          begin
            _sync_FrameDropped := 1;
            Inc(_rm_FrameDropCount);
          end;

          v20 := v1[1];
          if (v20 <> 0) and (v21 = nil) and (dword_6B3680 = 0) then
            _SetPalette_1(v1[0], v20);

          _rm_p := PByte(v1);
          _rm_len := v0;

          Exit(0);
        end;
        8, 9: begin
          if (v1[1] and _rm_track_bit) <> 0 then
          begin
            v14 := PByte(v1) + 6;
            if ((v5 shr 16) and $FF) <> 8 then
              v14 := nil;
            _CallsSndBuff_Loc(v14, v1[2]);
          end;
          Continue;
        end;
        10: begin
          if dword_51EE0C = 0 then
            Continue;
          // TODO: Probably never reached.
          Continue;
        end;
        11: begin
          _palMakeSynthPalette(v1[0], v1[1], v1[2], v1[3], v1[4], v1[5]);
          Continue;
        end;
        12: begin
          _palLoadPalette(PByte(v1) + 4, v1[0], v1[1]);
          Continue;
        end;
        14: begin
          v21 := v1;
          Continue;
        end;
        15: begin
          v3 := v1;
          Continue;
        end;
        17: begin
          if (v5 shr 24) < 3 then
          begin
            _MVE_rmEndMovie;
            Exit(-8);
          end;

          if (v1[6] and $01) <> 0 then
            movieSwapSurfaces;

          if dword_6B4027 <> 0 then
          begin
            if dword_51EBD8 <> 0 then
            begin
              _MVE_rmEndMovie;
              Exit(-8);
            end;

            if not movieLockSurfaces then
            begin
              _MVE_rmEndMovie;
              Exit(-12);
            end;

            // TODO: Incomplete (_nfHPkDecomp not implemented).
            movieUnlockSurfaces;
            Continue;
          end;

          if (dword_51EBD8 and 3) = 1 then
          begin
            if not movieLockSurfaces then
            begin
              _MVE_rmEndMovie;
              Exit(-12);
            end;
            // TODO: Incomplete (_nfPkDecompH not implemented).
            movieUnlockSurfaces;
            Continue;
          end;

          if (dword_51EBD8 and 3) = 2 then
          begin
            if not movieLockSurfaces then
            begin
              _MVE_rmEndMovie;
              Exit(-12);
            end;
            // TODO: Incomplete.
            movieUnlockSurfaces;
            Continue;
          end;

          if not movieLockSurfaces then
          begin
            _MVE_rmEndMovie;
            Exit(-12);
          end;

          _nfPkDecomp(PByte(v3), PByte(@v1[7]), v1[2], v1[3], v1[4], v1[5]);

          // Frame checksum for debugging
          chk_sum := 0;
          for chk_i := 0 to gMovieSdlSurface1^.h * gMovieSdlSurface1^.pitch - 1 do
            chk_sum := chk_sum + PByte(gMovieSdlSurface1^.pixels)[chk_i];
          WriteLn(StdErr, '[FCHK] frame=', _rm_FrameCount, ' sum=', chk_sum,
            ' params=', v1[2], ',', v1[3], ',', v1[4], ',', v1[5]);

          movieUnlockSurfaces;
          Continue;
        end;
      else
        Continue;
      end;

      // If we reach here with a break from case 1, go back to LABEL_5
      Break;
    end;
  end;
end;

function _syncInit(a1, a2: Integer): Integer;
var
  v2: Integer;
begin
  v2 := -((a2 shr 1) + a1 * a2);

  if (_sync_active <> 0) and (_sync_wait_quanta = v2) then
    Exit(1);

  _syncWait;

  _sync_wait_quanta := v2;

  _syncReset(v2);

  Result := 1;
end;

procedure _syncReset(a1: Integer);
begin
  _sync_active := 1;
  _sync_time := -1000 * Integer(compat_timeGetTime) + a1;
  WriteLn(StdErr, '[SYNCRESET] sync_time=', _sync_time, ' a1=', a1, ' t=', compat_timeGetTime);
end;

function _MVE_sndConfigure(a1, a2, a3, a4, a5, a6: Integer): Integer;
var
  ch: Integer;
begin
  _MVE_sndReset;

  _snd_comp := a3;
  dword_6B36A0 := a5;
  _snd_buf := a6;

  gMveBufferBytes := (LongWord(a2) + (LongWord(a2) shr 1)) and $FFFFFFFC;

  dword_6B3AE4 := 0;
  dword_6B3660 := 0;

  if a3 < 1 then
    ch := 8
  else
    ch := 16;

  if a3 < 1 then
    ch := 2
  else
    ch := 1;

  gMveSoundBuffer := audioEngineCreateSoundBuffer(gMveBufferBytes,
    (Ord(a5 >= 1) * 8) + 8,
    2 - Ord(a3 < 1),
    a4);
  if gMveSoundBuffer = -1 then
    Exit(0);

  audioEngineSoundBufferSetVolume(gMveSoundBuffer, gMovieLibVolume);
  audioEngineSoundBufferSetPan(gMveSoundBuffer, gMovieLibPan);

  dword_6B36A4 := 0;

  Result := 1;
end;

procedure _MVE_syncSync;
begin
  if _sync_active <> 0 then
  begin
    while ((_sync_time + 1000 * Integer(compat_timeGetTime)) and Integer($80000000)) <> 0 do
      ;
  end;
end;

procedure _MVE_sndReset;
begin
  if gMveSoundBuffer <> -1 then
  begin
    audioEngineSoundBufferStop(gMveSoundBuffer);
    audioEngineSoundBufferRelease(gMveSoundBuffer);
    gMveSoundBuffer := -1;
  end;
end;

procedure _MVE_sndSync;
var
  dwCurrentPlayCursor: LongWord;
  dwCurrentWriteCursor: LongWord;
  v10, v0, v2, v5: Boolean;
  dwStatus: LongWord;
  v1: LongWord;
  v3: Integer;
  v4, v6, v9: LongWord;
  v7, v8: Integer;
begin
  v0 := False;

  if _syncWaitLevel(SarLongint(_sync_wait_quanta, 2)) > ((-_sync_wait_quanta) shr 1) then
    _sync_late := Ord(not Boolean(_sync_FrameDropped))
  else
    _sync_late := 0;
  _sync_FrameDropped := 0;

  if gMveSoundBuffer = -1 then
    Exit;

  while True do
  begin
    if not audioEngineSoundBufferGetStatus(gMveSoundBuffer, @dwStatus) then
      Exit;

    if not audioEngineSoundBufferGetCurrentPosition(gMveSoundBuffer, @dwCurrentPlayCursor, @dwCurrentWriteCursor) then
      Exit;

    dwCurrentWriteCursor := dword_6B36A4;

    v1 := (gMveBufferBytes + LongWord(dword_6B39E0[dword_6B3660]) - LongWord(_gSoundTimeBase))
        mod gMveBufferBytes;

    if (_rm_FrameCount <= 6) then
      WriteLn(StdErr, '[SNDSYNC] frame=', _rm_FrameCount, ' v0=', v0,
        ' play=', dwCurrentPlayCursor, ' write=', dword_6B36A4,
        ' v1=', v1, ' bufSz=', gMveBufferBytes, ' status=', dwStatus);

    if dwCurrentPlayCursor <= dword_6B36A4 then
    begin
      if (v1 < dwCurrentPlayCursor) or (v1 >= dword_6B36A4) then
        v2 := False
      else
        v2 := True;
    end
    else
    begin
      if (v1 < dwCurrentPlayCursor) and (v1 >= dword_6B36A4) then
        v2 := False
      else
        v2 := True;
    end;

    if (not v2) or ((dwStatus and AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING) = 0) then
    begin
      if v0 then
        _syncReset(_sync_wait_quanta + SarLongint(_sync_wait_quanta, 2));

      v3 := dword_6B39E0[dword_6B3660];

      if (dwStatus and AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING) = 0 then
      begin
        v4 := (gMveBufferBytes + LongWord(v3)) mod gMveBufferBytes;

        if dwCurrentWriteCursor >= dwCurrentPlayCursor then
        begin
          if (v4 >= dwCurrentPlayCursor) and (v4 < dwCurrentWriteCursor) then
            v5 := True
          else
            v5 := False;
        end
        else if (v4 >= dwCurrentPlayCursor) or (v4 < dwCurrentWriteCursor) then
          v5 := True
        else
          v5 := False;

        if v5 then
        begin
          if not audioEngineSoundBufferSetCurrentPosition(gMveSoundBuffer, v4) then
            Exit;

          if not audioEngineSoundBufferPlay(gMveSoundBuffer, 1) then
            Exit;
        end;

        Break;
      end;

      v6 := (gMveBufferBytes + LongWord(_gSoundTimeBase) + LongWord(v3)) mod gMveBufferBytes;
      v7 := Integer(dwCurrentWriteCursor) - Integer(dwCurrentPlayCursor);

      if (LongWord(v7) and $80000000) <> 0 then
        v7 := v7 + Integer(gMveBufferBytes);

      v8 := Integer(gMveBufferBytes) - v7 - 1;
      if Integer(gMveBufferBytes) div 2 < v8 then
        v8 := Integer(gMveBufferBytes) shr 1;

      v9 := (gMveBufferBytes + dwCurrentPlayCursor - LongWord(v8)) mod gMveBufferBytes;

      dwCurrentPlayCursor := v9;

      if dwCurrentWriteCursor >= v9 then
      begin
        if (v6 < dwCurrentPlayCursor) or (v6 >= dwCurrentWriteCursor) then
          v10 := False
        else
          v10 := True;
      end
      else
      begin
        if (v6 >= v9) or (v6 < dwCurrentWriteCursor) then
          v10 := True
        else
          v10 := False;
      end;

      if not v10 then
        audioEngineSoundBufferStop(gMveSoundBuffer);

      Break;
    end;
    v0 := True;
  end;

  if dword_6B3660 <> dword_6B3AE4 then
  begin
    if dword_6B3660 = 59 then
      dword_6B3660 := 0
    else
      Inc(dword_6B3660);
  end;
end;

function _syncWaitLevel(a1: Integer): Integer;
var
  v2: Integer;
  t_before: Cardinal;
begin
  if _sync_active = 0 then
    Exit(0);

  t_before := compat_timeGetTime;
  v2 := _sync_time + a1;
  repeat
    Result := v2 + 1000 * Integer(compat_timeGetTime);
  until Result >= 0;

  if (_rm_FrameCount <= 10) or ((_rm_FrameCount mod 50) = 0) then
    WriteLn(StdErr, '[SYNC] frame=', _rm_FrameCount, ' waited=', compat_timeGetTime - t_before,
      'ms level=', Result, ' quanta=', _sync_wait_quanta, ' late=', _sync_late);

  _sync_time := _sync_time + _sync_wait_quanta;
end;

procedure _CallsSndBuff_Loc(a1: PByte; a2: Integer);
var
  v2, v3, v5: Integer;
  dwCurrentPlayCursor: LongWord;
  dwCurrentWriteCursor: LongWord;
  lpvAudioPtr1: Pointer;
  dwAudioBytes1: LongWord;
  lpvAudioPtr2: Pointer;
  dwAudioBytes2: LongWord;
begin
  _gSoundTimeBase := a2;

  if gMveSoundBuffer = -1 then
    Exit;

  v5 := 60;
  if dword_6B3660 <> 0 then
    v5 := dword_6B3660;

  if dword_6B3AE4 - v5 = -1 then
    Exit;

  if not audioEngineSoundBufferGetCurrentPosition(gMveSoundBuffer, @dwCurrentPlayCursor, @dwCurrentWriteCursor) then
    Exit;

  dwCurrentWriteCursor := dword_6B36A4;

  if not audioEngineSoundBufferLock(gMveSoundBuffer, dword_6B36A4, a2, @lpvAudioPtr1, @dwAudioBytes1, @lpvAudioPtr2, @dwAudioBytes2, 0) then
    Exit;

  v2 := 0;
  v3 := 1;
  if dwAudioBytes1 <> 0 then
  begin
    v2 := _MVE_sndAdd(PByte(lpvAudioPtr1), @a1, dwAudioBytes1, 0, 1);
    v3 := 0;
    dword_6B36A4 := dword_6B36A4 + dwAudioBytes1;
  end;

  if dwAudioBytes2 <> 0 then
  begin
    _MVE_sndAdd(PByte(lpvAudioPtr2), @a1, dwAudioBytes2, v2, v3);
    dword_6B36A4 := dwAudioBytes2;
  end;

  if dword_6B36A4 = gMveBufferBytes then
    dword_6B36A4 := 0;

  audioEngineSoundBufferUnlock(gMveSoundBuffer, lpvAudioPtr1, dwAudioBytes1, lpvAudioPtr2, dwAudioBytes2);

  dword_6B39E0[dword_6B3AE4] := dwCurrentWriteCursor;

  if dword_6B3AE4 = 59 then
    dword_6B3AE4 := 0
  else
    Inc(dword_6B3AE4);
end;

function _MVE_sndAdd(dest: PByte; src_ptr: PPByte; a3, a4, a5: Integer): Integer;
var
  src: PByte;
  v9, v11, v14: Integer;
  v10, v13: PWord;
  v12: Integer;
begin
  src := src_ptr^;

  if src = nil then
  begin
    if dword_6B36A0 < 1 then
      FillChar(dest^, a3, $80)
    else
      FillChar(dest^, a3, 0);
    src_ptr^ := nil;
    Exit(a4);
  end;

  if _snd_buf = 0 then
  begin
    Move(src^, dest^, a3);
    src_ptr^ := src + a3;
    Exit(a4);
  end;

  if _snd_comp = 0 then
  begin
    if a5 <> 0 then
    begin
      v9 := PWord(src)^;
      Inc(src, 2);
      PWord(dest)^ := v9;
      v10 := PWord(dest + 2);
      v11 := a3 - 2;
    end
    else
    begin
      v9 := a4;
      v10 := PWord(dest);
      v11 := a3;
    end;

    Result := _MVE_sndDecompM16(v10, src, v11 shr 1, v9);
    src_ptr^ := src + (v11 shr 1);
    Exit;
  end;

  if a5 <> 0 then
  begin
    v12 := loadUInt32LE(src);
    Inc(src, 4);
    PLongWord(dest)^ := v12;
    v13 := PWord(dest + 4);
    v14 := a3 - 4;
  end
  else
  begin
    v13 := PWord(dest);
    v14 := a3;
    v12 := a4;
  end;

  Result := _MVE_sndDecompS16(v13, src, v14 shr 2, v12);
  src_ptr^ := src + (v14 shr 1);
end;

procedure _MVE_sndResume;
begin
  // empty
end;

function _nfConfig(a1, a2, a3, a4: Integer): Integer;
var
  depth: Integer;
  rmask, gmask, bmask: LongWord;
begin
  if gMovieSdlSurface1 <> nil then
  begin
    SDL_FreeSurface(gMovieSdlSurface1);
    gMovieSdlSurface1 := nil;
  end;

  if gMovieSdlSurface2 <> nil then
  begin
    SDL_FreeSurface(gMovieSdlSurface2);
    gMovieSdlSurface2 := nil;
  end;

  byte_6B400D := a1;
  byte_6B400C := a2;
  byte_6B4016 := a3;
  _mveBW := 8 * a1;
  _mveBH := 8 * a2 * a3;

  if dword_51EBD8 <> 0 then
    _mveBH := _mveBH shr 1;

  if a4 <> 0 then
  begin
    depth := 16;
    rmask := $7C00;
    gmask := $3E0;
    bmask := $1F;
  end
  else
  begin
    depth := 8;
    rmask := 0;
    gmask := 0;
    bmask := 0;
  end;

  gMovieSdlSurface1 := SDL_CreateRGBSurface(0, _mveBW, _mveBH, depth, rmask, gmask, bmask, 0);
  if gMovieSdlSurface1 = nil then
    Exit(0);

  gMovieSdlSurface2 := SDL_CreateRGBSurface(0, _mveBW, _mveBH, depth, rmask, gmask, bmask, 0);
  if gMovieSdlSurface2 = nil then
    Exit(0);

  dword_6B4027 := a4;
  dword_6B402B := a3 * _mveBW - 8;

  if a4 <> 0 then
  begin
    _mveBW := _mveBW * 2;
    dword_6B402B := dword_6B402B * 2;
  end;

  dword_6B3D00 := 8 * a3 * _mveBW;
  dword_6B3CEC := 7 * a3 * _mveBW;

  _nfPkConfig;

  Result := 1;
end;

function movieLockSurfaces: Boolean;
begin
  Result := True;
  if (gMovieSdlSurface1 <> nil) and (gMovieSdlSurface2 <> nil) then
  begin
    if SDL_LockSurface(gMovieSdlSurface1) <> 0 then
      Exit(False);

    gMovieDirectDrawSurfaceBuffer1 := PByte(gMovieSdlSurface1^.pixels);

    if SDL_LockSurface(gMovieSdlSurface2) <> 0 then
      Exit(False);

    gMovieDirectDrawSurfaceBuffer2 := PByte(gMovieSdlSurface2^.pixels);
  end;
end;

procedure movieUnlockSurfaces;
begin
  SDL_UnlockSurface(gMovieSdlSurface1);
  SDL_UnlockSurface(gMovieSdlSurface2);
end;

procedure movieSwapSurfaces;
var
  tmp: PSDL_Surface;
begin
  tmp := gMovieSdlSurface2;
  gMovieSdlSurface2 := gMovieSdlSurface1;
  gMovieSdlSurface1 := tmp;
end;

procedure _sfShowFrame(a1, a2, a3: Integer);
var
  v3, v4, v5, v6, v7: Integer;
begin
  v4 := ((4 * _mveBW div dword_51EBDC - 12) and Integer($FFFFFFF0)) + 12;

  dword_6B3CF8 := _mveBW - dword_51EBDC * (v4 shr 2);

  v3 := a1;
  if a1 < 0 then
  begin
    if dword_6B4027 <> 0 then
      v3 := (_sf_ScreenWidth - (v4 shr 1)) shr 1
    else
      v3 := (_sf_ScreenWidth - v4) shr 1;
  end;

  if dword_6B4027 <> 0 then
    v3 := v3 * 2;

  v5 := a2;
  if a2 >= 0 then
    v6 := _mveBH
  else
  begin
    v6 := _mveBH;
    if (dword_51EBD8 and 4) <> 0 then
      v5 := (_sf_ScreenHeight - 2 * _mveBH) shr 1
    else
      v5 := (_sf_ScreenHeight - _mveBH) shr 1;
  end;

  v7 := v3 and Integer($FFFFFFFC);
  if (dword_51EBD8 and 4) <> 0 then
    v5 := v5 shr 1;

  if a3 <> 0 then
  begin
    // TODO: Incomplete (_mve_ShowFrameField not implemented).
  end
  else if dword_51EBDC = 4 then
    _sf_ShowFrame(gMovieSdlSurface1, _mveBW, v6, dword_6B401B, dword_6B401F, dword_6B4017, dword_6B4023, v7, v5)
  else
    _sf_ShowFrame(gMovieSdlSurface1, _mveBW, v6, 0, dword_6B401F,
      ((4 * _mveBW div dword_51EBDC - 12) and Integer($FFFFFFF0)) + 12, dword_6B4023, v7, v5);
end;

procedure _do_nothing_(a1, a2: Integer; a3: PWord);
begin
  // empty
end;

procedure _SetPalette_1(a1, a2: Integer);
begin
  WriteLn(StdErr, '[SETPAL1] a1=', a1, ' a2=', a2, ' dword_6B4027=', dword_6B4027,
    ' _pal_SetPalette_assigned=', Assigned(_pal_SetPalette));
  if dword_6B4027 = 0 then
    _pal_SetPalette(@_pal_tbl[0], a1, a2);
end;

procedure _SetPalette_(a1, a2: Integer);
begin
  if dword_6B4027 = 0 then
    _pal_SetPalette(@_palette_entries1[0], a1, a2);
end;

procedure _palMakeSynthPalette(a1, a2, a3, a4, a5, a6: Integer);
var
  i, j: Integer;
begin
  for i := 0 to a2 - 1 do
    for j := 0 to a3 - 1 do
    begin
      _pal_tbl[3 * a1 + 3 * j] := (63 * i) div (a2 - 1);
      _pal_tbl[3 * a1 + 3 * j + 1] := 0;
      _pal_tbl[3 * a1 + 3 * j + 2] := 5 * ((63 * j) div (a3 - 1)) div 8;
    end;

  for i := 0 to a5 - 1 do
    for j := 0 to a6 - 1 do
    begin
      _pal_tbl[3 * a4 + 3 * j] := 0;
      _pal_tbl[3 * a4 + 3 * j + 1] := (63 * i) div (a5 - 1);
      _pal_tbl[3 * a1 + 3 * j + 2] := 5 * ((63 * j) div (a6 - 1)) div 8;
    end;
end;

procedure _palLoadPalette(palette: PByte; a2, a3: Integer);
begin
  Move(palette^, _pal_tbl[3 * a2], 3 * a3);
end;

procedure _MVE_rmEndMovie;
begin
  if _rm_active <> 0 then
  begin
    _syncWait;
    _syncRelease;
    _MVE_sndReset;
    _rm_active := 0;
  end;
end;

procedure _syncRelease;
begin
  _sync_active := 0;
end;

procedure _MVE_ReleaseMem;
begin
  _MVE_rmEndMovie;
  _ioRelease;
  _MVE_sndRelease;
  _nfRelease;
end;

procedure _ioRelease;
begin
  _MVE_MemFree(@_io_mem_buf);
end;

procedure _MVE_sndRelease;
begin
  // empty
end;

procedure _nfRelease;
begin
  if gMovieSdlSurface1 <> nil then
  begin
    SDL_FreeSurface(gMovieSdlSurface1);
    gMovieSdlSurface1 := nil;
  end;

  if gMovieSdlSurface2 <> nil then
  begin
    SDL_FreeSurface(gMovieSdlSurface2);
    gMovieSdlSurface2 := nil;
  end;
end;

procedure _frLoad(a1: PSTRUCT_4F6930);
begin
  gMovieLibReadProc := a1^.readProc;
  _io_mem_buf.field_0 := a1^.field_8.field_0;
  _io_mem_buf.field_4 := a1^.field_8.field_4;
  _io_mem_buf.field_8 := a1^.field_8.field_8;
  _io_handle := a1^.fileHandle;
  _io_next_hdr := a1^.field_18;
  gMovieSdlSurface1 := a1^.field_24;
  gMovieSdlSurface2 := a1^.field_28;
  dword_6B3AE8 := a1^.field_2C;
  gMovieDirectDrawSurfaceBuffer1 := a1^.field_30;
  gMovieDirectDrawSurfaceBuffer2 := a1^.field_34;
  byte_6B400D := a1^.field_38;
  byte_6B400C := a1^.field_39;
  byte_6B4016 := a1^.field_3A;
  dword_6B4027 := a1^.field_3C;
  _mveBW := a1^.field_40;
  _mveBH := a1^.field_44;
  dword_6B402B := a1^.field_48;
  dword_6B3D00 := a1^.field_4C;
  dword_6B3CEC := a1^.field_50;
end;

procedure _frSave(a1: PSTRUCT_4F6930);
begin
  a1^.readProc := gMovieLibReadProc;
  a1^.field_8.field_0 := _io_mem_buf.field_0;
  a1^.field_8.field_4 := _io_mem_buf.field_4;
  a1^.field_8.field_8 := _io_mem_buf.field_8;
  a1^.fileHandle := _io_handle;
  a1^.field_18 := _io_next_hdr;
  a1^.field_24 := gMovieSdlSurface1;
  a1^.field_28 := gMovieSdlSurface2;
  a1^.field_2C := dword_6B3AE8;
  a1^.field_30 := gMovieDirectDrawSurfaceBuffer1;
  a1^.field_34 := gMovieDirectDrawSurfaceBuffer2;
  a1^.field_38 := byte_6B400D;
  a1^.field_39 := byte_6B400C;
  a1^.field_3A := byte_6B4016;
  a1^.field_3C := dword_6B4027;
  a1^.field_40 := _mveBW;
  a1^.field_44 := _mveBH;
  a1^.field_48 := dword_6B402B;
  a1^.field_4C := dword_6B3D00;
  a1^.field_50 := dword_6B3CEC;
end;

procedure _MVE_frClose(a1: PSTRUCT_4F6930);
var
  v1: TSTRUCT_4F6930;
begin
  _frSave(@v1);
  _frLoad(a1);
  _ioRelease;
  _nfRelease;
  _frLoad(@v1);

  if Assigned(gMovieLibFreeProc) then
    gMovieLibFreeProc(a1);
end;

function _MVE_sndDecompM16(a1: PWord; a2: PByte; a3, a4: Integer): Integer;
var
  i: Integer;
  v8: Integer;
  sresult: Word;
begin
  sresult := a4;
  v8 := 0;
  for i := 0 to a3 - 1 do
  begin
    v8 := a2^;
    Inc(a2);
    sresult := sresult + word_51EBE0[v8];
    a1^ := sresult;
    Inc(a1);
  end;

  Result := sresult;
end;

function _MVE_sndDecompS16(a1: PWord; a2: PByte; a3, a4: Integer): Integer;
var
  i: Integer;
  v4, v5, v9: Word;
begin
  v4 := a4 and $FFFF;
  v5 := (a4 shr 16) and $FFFF;

  v9 := 0;
  for i := 0 to a3 - 1 do
  begin
    v9 := a2^;
    Inc(a2);
    v4 := (word_51EBE0[v9] + v4) and $FFFF;
    a1^ := v4;
    Inc(a1);

    v9 := a2^;
    Inc(a2);
    v5 := (word_51EBE0[v9] + v5) and $FFFF;
    a1^ := v5;
    Inc(a1);
  end;

  Result := (Integer(v5) shl 16) or v4;
end;

procedure _nfPkConfig;
var
  ptr: PInteger;
  v1, v2, v3, v4, v5: Integer;
begin
  ptr := @dword_51F018[0];
  v1 := _mveBW;
  v2 := 0;

  v3 := 128;
  while v3 > 0 do
  begin
    ptr^ := v2;
    Inc(ptr);
    v2 := v2 + v1;
    Dec(v3);
  end;

  v4 := -128 * v1;
  v5 := 128;
  while v5 > 0 do
  begin
    ptr^ := v4;
    Inc(ptr);
    v4 := v4 + v1;
    Dec(v5);
  end;
end;

procedure _nfPkDecomp(a1, a2: PByte; a3, a4, a5, a6: Integer);
var
  v49: Integer;
  dest: PByte;
  v8, v7, i, j: Integer;
  v10: PtrInt;
  aByte: Integer;
  value1, value2: LongWord;
  var_10, var_8: Integer;
  map1: array[0..511] of Byte;
  map2: array[0..255] of LongWord;
  nibbles: array[0..1] of LongWord;
  src_ptr, dest_ptr: PLongWord;
  offset16: Word;
  dbg_blockIdx: Integer;
  dbg_dest_before: PByte;
  dbg_row, dbg_col: Integer;
  dbg_found: Boolean;
begin
  dbg_blockIdx := 0;

  dword_6B401B := 8 * a3;
  dword_6B4017 := 8 * a5;
  dword_6B401F := 8 * a4 * byte_6B4016;
  dword_6B4023 := 8 * a6 * byte_6B4016;

  var_8 := dword_6B3D00 - dword_6B4017;
  dest := gMovieDirectDrawSurfaceBuffer1;

  var_10 := dword_6B3CEC - 8;

  if (a3 <> 0) or (a4 <> 0) then
    dest := gMovieDirectDrawSurfaceBuffer1 + dword_6B401B + _mveBW * dword_6B401F;

  while a6 > 0 do
  begin
    Dec(a6);
    v49 := a5 shr 1;
    while v49 > 0 do
    begin
      Dec(v49);
      v8 := a1^;
      Inc(a1);
      nibbles[0] := v8 and $F;
      nibbles[1] := v8 shr 4;
      for j := 0 to 1 do
      begin
        v7 := nibbles[j];
        dbg_dest_before := dest;

        case v7 of
          1: begin
            dest := dest + 8;
          end;
          0, 2, 3, 4, 5: begin
            case v7 of
              0: v10 := gMovieDirectDrawSurfaceBuffer2 - gMovieDirectDrawSurfaceBuffer1;
              2, 3: begin
                aByte := a2^;
                Inc(a2);
                offset16 := word_51F618[aByte];
                if v7 = 3 then
                  offset16 := (((-Integer(offset16 and $FF)) and $FF)) or ((((-Integer(offset16 shr 8)) and $FF)) shl 8);
                v10 := getOffset(offset16);
              end;
              4, 5: begin
                if v7 = 4 then
                begin
                  aByte := a2^;
                  Inc(a2);
                  offset16 := word_51F418[aByte];
                end
                else
                begin
                  offset16 := loadUInt16LE(a2);
                  Inc(a2, 2);
                end;
                v10 := getOffset(offset16) + (gMovieDirectDrawSurfaceBuffer2 - gMovieDirectDrawSurfaceBuffer1);
              end;
            else
              v10 := 0;
            end;

            value2 := _mveBW;

            for i := 0 to 7 do
            begin
              Move((dest + v10)^, dest^, 8);
              dest := dest + value2;
            end;

            dest := dest - value2;
            dest := dest - var_10;
          end;
          6: begin
            nibbles[0] := nibbles[0] + 2;
            while nibbles[0] > 0 do
            begin
              Dec(nibbles[0]);
              dest := dest + 16;

              if v49 > 0 then
              begin
                Dec(v49);
                Continue;
              end;

              dest := dest + var_8;

              Dec(a6);
              v49 := (a5 shr 1) - 1;
            end;
          end;
          7: begin
            if a2[0] > a2[1] then
            begin
              // 7/1
              for i := 0 to 1 do
              begin
                value1 := _dollar_R0053[a2[2 + i] and $F];
                map1[i * 8] := value1 and $FF;
                map1[i * 8 + 1] := (value1 shr 8) and $FF;
                map1[i * 8 + 2] := (value1 shr 16) and $FF;
                map1[i * 8 + 3] := (value1 shr 24) and $FF;

                value1 := _dollar_R0053[a2[2 + i] shr 4];
                map1[i * 8 + 4] := value1 and $FF;
                map1[i * 8 + 5] := (value1 shr 8) and $FF;
                map1[i * 8 + 6] := (value1 shr 16) and $FF;
                map1[i * 8 + 7] := (value1 shr 24) and $FF;
              end;

              map2[$C1] := (LongWord(a2[1]) shl 8) or a2[1];
              map2[$C3] := (LongWord(a2[0]) shl 8) or a2[0];

              value2 := _mveBW;

              for i := 0 to 3 do
              begin
                dest_ptr := PLongWord(dest);
                dest_ptr[0] := (map2[map1[i * 4]] shl 16) or (map2[map1[i * 4 + 1]]);

                dest_ptr := PLongWord(dest + value2);
                dest_ptr[0] := (map2[map1[i * 4]] shl 16) or (map2[map1[i * 4 + 1]]);

                dest_ptr := PLongWord(dest);
                dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 16) or (map2[map1[i * 4 + 3]]);

                dest_ptr := PLongWord(dest + value2);
                dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 16) or (map2[map1[i * 4 + 3]]);

                dest := dest + value2 * 2;
              end;

              dest := dest - value2;

              a2 := a2 + 4;
              dest := dest - var_10;
            end
            else
            begin
              // 7/2
              for i := 0 to 7 do
              begin
                value1 := _dollar_R0004[a2[2 + i]];
                map1[i * 4] := value1 and $FF;
                map1[i * 4 + 1] := (value1 shr 8) and $FF;
                map1[i * 4 + 2] := (value1 shr 16) and $FF;
                map1[i * 4 + 3] := (value1 shr 24) and $FF;
              end;

              map2[$C1] := (LongWord(a2[1]) shl 8) or a2[0];
              map2[$C3] := (LongWord(a2[0]) shl 8) or a2[0];
              map2[$C2] := (LongWord(a2[0]) shl 8) or a2[1];
              map2[$C5] := (LongWord(a2[1]) shl 8) or a2[1];

              value2 := _mveBW;

              for i := 0 to 7 do
              begin
                dest_ptr := PLongWord(dest);
                dest_ptr[0] := (map2[map1[i * 4]] shl 16) or map2[map1[i * 4 + 1]];
                dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 16) or map2[map1[i * 4 + 3]];

                dest := dest + value2;
              end;

              dest := dest - value2;

              a2 := a2 + 10;
              dest := dest - var_10;
            end;
          end;
          8, 9, 10, 11, 12, 13, 14, 15: begin
            // For cases 8-15, use raw pixel copy for 8x8 blocks.
            // Cases 8-10 are complex multi-color block decompression using
            // _dollar_R0004 and _dollar_R0063 lookup tables.
            // Cases 11-15 are simpler fill/copy patterns.
            case v7 of
              11: begin
                // raw 8x8 copy
                value2 := _mveBW;
                for i := 0 to 7 do
                begin
                  Move(a2[i * 8], dest^, 8);
                  dest := dest + value2;
                end;
                dest := dest - value2;
                a2 := a2 + 64;
                dest := dest - var_10;
              end;
              12: begin
                // 2x2 block fill
                value2 := _mveBW;
                for i := 0 to 3 do
                begin
                  aByte := a2[i * 4 + 0];
                  value1 := aByte or (aByte shl 8);
                  aByte := a2[i * 4 + 1];
                  value1 := value1 or (LongWord(aByte) shl 16) or (LongWord(aByte) shl 24);

                  aByte := a2[i * 4 + 2];
                  value2 := aByte or (aByte shl 8);
                  aByte := a2[i * 4 + 3];
                  value2 := value2 or (LongWord(aByte) shl 16) or (LongWord(aByte) shl 24);

                  dest_ptr := PLongWord(dest);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest_ptr := PLongWord(dest + _mveBW);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest := dest + LongWord(_mveBW) * 2;
                  value2 := _mveBW;
                end;
                dest := dest - value2;
                a2 := a2 + 16;
                dest := dest - var_10;
              end;
              13: begin
                // 4x4 block fill with 2 color pairs
                aByte := a2[0];
                value1 := aByte or (aByte shl 8) or (aByte shl 16) or (aByte shl 24);
                aByte := a2[1];
                value2 := aByte or (aByte shl 8) or (aByte shl 16) or (aByte shl 24);

                for i := 0 to 1 do
                begin
                  dest_ptr := PLongWord(dest);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest_ptr := PLongWord(dest + _mveBW);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest := dest + LongWord(_mveBW) * 2;
                end;

                aByte := a2[2];
                value1 := aByte or (aByte shl 8) or (aByte shl 16) or (aByte shl 24);
                aByte := a2[3];
                value2 := aByte or (aByte shl 8) or (aByte shl 16) or (aByte shl 24);

                for i := 0 to 1 do
                begin
                  dest_ptr := PLongWord(dest);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest_ptr := PLongWord(dest + _mveBW);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value2;

                  dest := dest + LongWord(_mveBW) * 2;
                end;

                dest := dest - _mveBW;
                a2 := a2 + 4;
                dest := dest - var_10;
              end;
              14, 15: begin
                // solid fill
                if v7 = 14 then
                begin
                  aByte := a2^;
                  Inc(a2);
                  value1 := aByte or (aByte shl 8) or (aByte shl 16) or (aByte shl 24);
                  value2 := value1;
                end
                else
                begin
                  aByte := loadUInt16LE(a2);
                  Inc(a2, 2);
                  value1 := aByte or (LongWord(aByte) shl 16);
                  value2 := value1;
                  value2 := (value2 shl 8) or (value2 shr 24);
                end;

                for i := 0 to 3 do
                begin
                  dest_ptr := PLongWord(dest);
                  dest_ptr[0] := value1;
                  dest_ptr[1] := value1;
                  dest := dest + _mveBW;

                  dest_ptr := PLongWord(dest);
                  dest_ptr[0] := value2;
                  dest_ptr[1] := value2;
                  dest := dest + _mveBW;
                end;

                dest := dest - _mveBW;
                dest := dest - var_10;
              end;
              8: begin
                if a2[0] > a2[1] then
                begin
                  if a2[6] > a2[7] then
                  begin
                    // 8/1: two 2-color 4x4 top/bottom blocks, horizontal pattern
                    for i := 0 to 3 do
                    begin
                      value1 := _dollar_R0004[a2[2 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    for i := 0 to 3 do
                    begin
                      value1 := _dollar_R0004[a2[8 + i]];
                      map1[16 + i * 4] := value1 and $FF;
                      map1[16 + i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[16 + i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[16 + i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    value2 := _mveBW;

                    map2[$C1] := (LongWord(a2[1]) shl 8) or a2[0];
                    map2[$C3] := (LongWord(a2[0]) shl 8) or a2[0];
                    map2[$C2] := (LongWord(a2[0]) shl 8) or a2[1];
                    map2[$C5] := (LongWord(a2[1]) shl 8) or a2[1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4]] shl 16) or map2[map1[i * 4 + 1]];
                      dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 16) or map2[map1[i * 4 + 3]];
                      dest := dest + value2;
                    end;

                    map2[$C1] := (LongWord(a2[7]) shl 8) or a2[6];
                    map2[$C3] := (LongWord(a2[6]) shl 8) or a2[6];
                    map2[$C2] := (LongWord(a2[6]) shl 8) or a2[7];
                    map2[$C5] := (LongWord(a2[7]) shl 8) or a2[7];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[16 + i * 4]] shl 16) or map2[map1[16 + i * 4 + 1]];
                      dest_ptr[1] := (map2[map1[16 + i * 4 + 2]] shl 16) or map2[map1[16 + i * 4 + 3]];
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 12;
                    dest := dest - var_10;
                  end
                  else
                  begin
                    // 8/2: two 2-color 4x8 left/right blocks, vertical pattern
                    for i := 0 to 3 do
                    begin
                      value1 := _dollar_R0004[a2[2 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    for i := 0 to 3 do
                    begin
                      value1 := _dollar_R0004[a2[8 + i]];
                      map1[16 + i * 4] := value1 and $FF;
                      map1[16 + i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[16 + i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[16 + i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    value2 := _mveBW;

                    map2[$C1] := (LongWord(a2[1]) shl 8) or a2[0];
                    map2[$C3] := (LongWord(a2[0]) shl 8) or a2[0];
                    map2[$C2] := (LongWord(a2[0]) shl 8) or a2[1];
                    map2[$C5] := (LongWord(a2[1]) shl 8) or a2[1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4]] shl 16) or map2[map1[i * 4 + 1]];
                      dest := dest + value2;

                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4 + 2]] shl 16) or map2[map1[i * 4 + 3]];
                      dest := dest + value2;
                    end;

                    dest := dest - value2 * 8 + 4;

                    map2[$C1] := (LongWord(a2[7]) shl 8) or a2[6];
                    map2[$C3] := (LongWord(a2[6]) shl 8) or a2[6];
                    map2[$C2] := (LongWord(a2[6]) shl 8) or a2[7];
                    map2[$C5] := (LongWord(a2[7]) shl 8) or a2[7];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[16 + i * 4]] shl 16) or map2[map1[16 + i * 4 + 1]];
                      dest := dest + value2;

                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[16 + i * 4 + 2]] shl 16) or map2[map1[16 + i * 4 + 3]];
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 12;
                    dest := dest - 4;
                    dest := dest - var_10;
                  end;
                end
                else
                begin
                  // 8/3: four 2-color 4x4 quadrant blocks
                  for i := 0 to 1 do
                  begin
                    value1 := _dollar_R0004[a2[2 + i]];
                    map1[i * 4] := value1 and $FF;
                    map1[i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 1 do
                  begin
                    value1 := _dollar_R0004[a2[6 + i]];
                    map1[8 + i * 4] := value1 and $FF;
                    map1[8 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[8 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[8 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 1 do
                  begin
                    value1 := _dollar_R0004[a2[10 + i]];
                    map1[16 + i * 4] := value1 and $FF;
                    map1[16 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[16 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[16 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 1 do
                  begin
                    value1 := _dollar_R0004[a2[14 + i]];
                    map1[24 + i * 4] := value1 and $FF;
                    map1[24 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[24 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[24 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  value2 := _mveBW;

                  // top-left quadrant
                  map2[$C1] := (LongWord(a2[1]) shl 8) or a2[0];
                  map2[$C3] := (LongWord(a2[0]) shl 8) or a2[0];
                  map2[$C2] := (LongWord(a2[0]) shl 8) or a2[1];
                  map2[$C5] := (LongWord(a2[1]) shl 8) or a2[1];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[i * 4]] shl 16) or map2[map1[i * 4 + 1]];
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[i * 4 + 2]] shl 16) or map2[map1[i * 4 + 3]];
                    dest := dest + value2;
                  end;

                  // bottom-left quadrant
                  map2[$C1] := (LongWord(a2[5]) shl 8) or a2[4];
                  map2[$C3] := (LongWord(a2[4]) shl 8) or a2[4];
                  map2[$C2] := (LongWord(a2[4]) shl 8) or a2[5];
                  map2[$C5] := (LongWord(a2[5]) shl 8) or a2[5];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[8 + i * 4]] shl 16) or map2[map1[8 + i * 4 + 1]];
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[8 + i * 4 + 2]] shl 16) or map2[map1[8 + i * 4 + 3]];
                    dest := dest + value2;
                  end;

                  dest := dest - value2 * 8 + 4;

                  // top-right quadrant
                  map2[$C1] := (LongWord(a2[9]) shl 8) or a2[8];
                  map2[$C3] := (LongWord(a2[8]) shl 8) or a2[8];
                  map2[$C2] := (LongWord(a2[8]) shl 8) or a2[9];
                  map2[$C5] := (LongWord(a2[9]) shl 8) or a2[9];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[16 + i * 4]] shl 16) or map2[map1[16 + i * 4 + 1]];
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[16 + i * 4 + 2]] shl 16) or map2[map1[16 + i * 4 + 3]];
                    dest := dest + value2;
                  end;

                  // bottom-right quadrant
                  map2[$C1] := (LongWord(a2[13]) shl 8) or a2[12];
                  map2[$C3] := (LongWord(a2[12]) shl 8) or a2[12];
                  map2[$C2] := (LongWord(a2[12]) shl 8) or a2[13];
                  map2[$C5] := (LongWord(a2[13]) shl 8) or a2[13];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[24 + i * 4]] shl 16) or map2[map1[24 + i * 4 + 1]];
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[24 + i * 4 + 2]] shl 16) or map2[map1[24 + i * 4 + 3]];
                    dest := dest + value2;
                  end;

                  dest := dest - value2;
                  a2 := a2 + 16;
                  dest := dest - 4;
                  dest := dest - var_10;
                end;
              end;
              9: begin
                if a2[0] > a2[1] then
                begin
                  if a2[2] > a2[3] then
                  begin
                    // 9/1: 4-color 8x8, 2x2 pixel blocks, doubled rows
                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    value2 := _mveBW;

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                      dest_ptr[1] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);

                      dest_ptr := PLongWord(dest + value2);
                      dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                      dest_ptr[1] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);

                      dest := dest + value2 * 2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 12;
                    dest := dest - var_10;
                  end
                  else
                  begin
                    // 9/2: 4-color 8x8, 2x1 pixel blocks (doubled columns)
                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4 + 3] := value1 and $FF;
                      map1[i * 4 + 2] := (value1 shr 8) and $FF;
                      map1[i * 4 + 1] := (value1 shr 16) and $FF;
                      map1[i * 4] := (value1 shr 24) and $FF;
                    end;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    value2 := _mveBW;

                    for i := 0 to 7 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4]] shl 24) or (map2[map1[i * 4]] shl 16) or (map2[map1[i * 4 + 1]] shl 8) or (map2[map1[i * 4 + 1]]);
                      dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 24) or (map2[map1[i * 4 + 2]] shl 16) or (map2[map1[i * 4 + 3]] shl 8) or (map2[map1[i * 4 + 3]]);
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 12;
                    dest := dest - var_10;
                  end;
                end
                else
                begin
                  if a2[2] > a2[3] then
                  begin
                    // 9/3: 4-color 8x8, 2x2 pixel blocks (no doubling)
                    for i := 0 to 3 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4 + 3] := value1 and $FF;
                      map1[i * 4 + 2] := (value1 shr 8) and $FF;
                      map1[i * 4 + 1] := (value1 shr 16) and $FF;
                      map1[i * 4] := (value1 shr 24) and $FF;
                    end;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    value2 := _mveBW;

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4]] shl 24) or (map2[map1[i * 4]] shl 16) or (map2[map1[i * 4 + 1]] shl 8) or (map2[map1[i * 4 + 1]]);
                      dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 24) or (map2[map1[i * 4 + 2]] shl 16) or (map2[map1[i * 4 + 3]] shl 8) or (map2[map1[i * 4 + 3]]);
                      dest := dest + value2;

                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 4]] shl 24) or (map2[map1[i * 4]] shl 16) or (map2[map1[i * 4 + 1]] shl 8) or (map2[map1[i * 4 + 1]]);
                      dest_ptr[1] := (map2[map1[i * 4 + 2]] shl 24) or (map2[map1[i * 4 + 2]] shl 16) or (map2[map1[i * 4 + 3]] shl 8) or (map2[map1[i * 4 + 3]]);
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 8;
                    dest := dest - var_10;
                  end
                  else
                  begin
                    // 9/4: 4-color 8x8, 1x1 pixel blocks (full resolution)
                    for i := 0 to 15 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    value2 := _mveBW;

                    for i := 0 to 7 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                      dest_ptr[1] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 20;
                    dest := dest - var_10;
                  end;
                end;
              end;
              10: begin
                if a2[0] > a2[1] then
                begin
                  if a2[12] > a2[13] then
                  begin
                    // 10/1: 4-color two 4x8 halves (top/bottom), 1x1 pixel blocks
                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[16 + i]];
                      map1[32 + i * 4] := value1 and $FF;
                      map1[32 + i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[32 + i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[32 + i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    value2 := _mveBW;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                      dest_ptr[1] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);
                      dest := dest + value2;
                    end;

                    map2[$C1] := a2[$0C + 2];
                    map2[$C3] := a2[$0C + 0];
                    map2[$C5] := a2[$0C + 3];
                    map2[$C7] := a2[$0C + 1];
                    map2[$E1] := a2[$0C + 2];
                    map2[$E3] := a2[$0C + 0];
                    map2[$E5] := a2[$0C + 3];
                    map2[$E7] := a2[$0C + 1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[32 + i * 8]] shl 16) or (map2[map1[32 + i * 8 + 1]] shl 24) or (map2[map1[32 + i * 8 + 2]]) or (map2[map1[32 + i * 8 + 3]] shl 8);
                      dest_ptr[1] := (map2[map1[32 + i * 8 + 4]] shl 16) or (map2[map1[32 + i * 8 + 5]] shl 24) or (map2[map1[32 + i * 8 + 6]]) or (map2[map1[32 + i * 8 + 7]] shl 8);
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 24;
                    dest := dest - var_10;
                  end
                  else
                  begin
                    // 10/2: 4-color two 8x4 halves (left/right), 1x1 pixel blocks
                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[4 + i]];
                      map1[i * 4] := value1 and $FF;
                      map1[i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    for i := 0 to 7 do
                    begin
                      value1 := _dollar_R0063[a2[16 + i]];
                      map1[32 + i * 4] := value1 and $FF;
                      map1[32 + i * 4 + 1] := (value1 shr 8) and $FF;
                      map1[32 + i * 4 + 2] := (value1 shr 16) and $FF;
                      map1[32 + i * 4 + 3] := (value1 shr 24) and $FF;
                    end;

                    value2 := _mveBW;

                    map2[$C1] := a2[2];
                    map2[$C3] := a2[0];
                    map2[$C5] := a2[3];
                    map2[$C7] := a2[1];
                    map2[$E1] := a2[2];
                    map2[$E3] := a2[0];
                    map2[$E5] := a2[3];
                    map2[$E7] := a2[1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                      dest := dest + value2;

                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);
                      dest := dest + value2;
                    end;

                    dest := dest - value2 * 8 + 4;

                    map2[$C1] := a2[$0C + 2];
                    map2[$C3] := a2[$0C + 0];
                    map2[$C5] := a2[$0C + 3];
                    map2[$C7] := a2[$0C + 1];
                    map2[$E1] := a2[$0C + 2];
                    map2[$E3] := a2[$0C + 0];
                    map2[$E5] := a2[$0C + 3];
                    map2[$E7] := a2[$0C + 1];

                    for i := 0 to 3 do
                    begin
                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[32 + i * 8]] shl 16) or (map2[map1[32 + i * 8 + 1]] shl 24) or (map2[map1[32 + i * 8 + 2]]) or (map2[map1[32 + i * 8 + 3]] shl 8);
                      dest := dest + value2;

                      dest_ptr := PLongWord(dest);
                      dest_ptr[0] := (map2[map1[32 + i * 8 + 4]] shl 16) or (map2[map1[32 + i * 8 + 5]] shl 24) or (map2[map1[32 + i * 8 + 6]]) or (map2[map1[32 + i * 8 + 7]] shl 8);
                      dest := dest + value2;
                    end;

                    dest := dest - value2;
                    a2 := a2 + 24;
                    dest := dest - 4;
                    dest := dest - var_10;
                  end;
                end
                else
                begin
                  // 10/3: 4-color four 4x4 quadrant blocks, 1x1 pixel blocks
                  for i := 0 to 3 do
                  begin
                    value1 := _dollar_R0063[a2[4 + i]];
                    map1[i * 4] := value1 and $FF;
                    map1[i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 3 do
                  begin
                    value1 := _dollar_R0063[a2[12 + i]];
                    map1[16 + i * 4] := value1 and $FF;
                    map1[16 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[16 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[16 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 3 do
                  begin
                    value1 := _dollar_R0063[a2[20 + i]];
                    map1[32 + i * 4] := value1 and $FF;
                    map1[32 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[32 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[32 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  for i := 0 to 3 do
                  begin
                    value1 := _dollar_R0063[a2[28 + i]];
                    map1[48 + i * 4] := value1 and $FF;
                    map1[48 + i * 4 + 1] := (value1 shr 8) and $FF;
                    map1[48 + i * 4 + 2] := (value1 shr 16) and $FF;
                    map1[48 + i * 4 + 3] := (value1 shr 24) and $FF;
                  end;

                  value2 := _mveBW;

                  // top-left quadrant
                  map2[$C1] := a2[2];
                  map2[$C3] := a2[0];
                  map2[$C5] := a2[3];
                  map2[$C7] := a2[1];
                  map2[$E1] := a2[2];
                  map2[$E3] := a2[0];
                  map2[$E5] := a2[3];
                  map2[$E7] := a2[1];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[i * 8]] shl 16) or (map2[map1[i * 8 + 1]] shl 24) or (map2[map1[i * 8 + 2]]) or (map2[map1[i * 8 + 3]] shl 8);
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[i * 8 + 4]] shl 16) or (map2[map1[i * 8 + 5]] shl 24) or (map2[map1[i * 8 + 6]]) or (map2[map1[i * 8 + 7]] shl 8);
                    dest := dest + value2;
                  end;

                  // bottom-left quadrant
                  map2[$C1] := a2[$08 + 2];
                  map2[$C3] := a2[$08 + 0];
                  map2[$C5] := a2[$08 + 3];
                  map2[$C7] := a2[$08 + 1];
                  map2[$E1] := a2[$08 + 2];
                  map2[$E3] := a2[$08 + 0];
                  map2[$E5] := a2[$08 + 3];
                  map2[$E7] := a2[$08 + 1];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[16 + i * 8]] shl 16) or (map2[map1[16 + i * 8 + 1]] shl 24) or (map2[map1[16 + i * 8 + 2]]) or (map2[map1[16 + i * 8 + 3]] shl 8);
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[16 + i * 8 + 4]] shl 16) or (map2[map1[16 + i * 8 + 5]] shl 24) or (map2[map1[16 + i * 8 + 6]]) or (map2[map1[16 + i * 8 + 7]] shl 8);
                    dest := dest + value2;
                  end;

                  dest := dest - value2 * 8 + 4;

                  // top-right quadrant
                  map2[$C1] := a2[$10 + 2];
                  map2[$C3] := a2[$10 + 0];
                  map2[$C5] := a2[$10 + 3];
                  map2[$C7] := a2[$10 + 1];
                  map2[$E1] := a2[$10 + 2];
                  map2[$E3] := a2[$10 + 0];
                  map2[$E5] := a2[$10 + 3];
                  map2[$E7] := a2[$10 + 1];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[32 + i * 8]] shl 16) or (map2[map1[32 + i * 8 + 1]] shl 24) or (map2[map1[32 + i * 8 + 2]]) or (map2[map1[32 + i * 8 + 3]] shl 8);
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[32 + i * 8 + 4]] shl 16) or (map2[map1[32 + i * 8 + 5]] shl 24) or (map2[map1[32 + i * 8 + 6]]) or (map2[map1[32 + i * 8 + 7]] shl 8);
                    dest := dest + value2;
                  end;

                  // bottom-right quadrant
                  map2[$C1] := a2[$18 + 2];
                  map2[$C3] := a2[$18 + 0];
                  map2[$C5] := a2[$18 + 3];
                  map2[$C7] := a2[$18 + 1];
                  map2[$E1] := a2[$18 + 2];
                  map2[$E3] := a2[$18 + 0];
                  map2[$E5] := a2[$18 + 3];
                  map2[$E7] := a2[$18 + 1];

                  for i := 0 to 1 do
                  begin
                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[48 + i * 8]] shl 16) or (map2[map1[48 + i * 8 + 1]] shl 24) or (map2[map1[48 + i * 8 + 2]]) or (map2[map1[48 + i * 8 + 3]] shl 8);
                    dest := dest + value2;

                    dest_ptr := PLongWord(dest);
                    dest_ptr[0] := (map2[map1[48 + i * 8 + 4]] shl 16) or (map2[map1[48 + i * 8 + 5]] shl 24) or (map2[map1[48 + i * 8 + 6]]) or (map2[map1[48 + i * 8 + 7]] shl 8);
                    dest := dest + value2;
                  end;

                  dest := dest - value2;
                  a2 := a2 + 32;
                  dest := dest - 4;
                  dest := dest - var_10;
                end;
              end;
            end;
          end;
        end;
      end;

      // DEBUG: check block output for bad pixels
      if (_rm_FrameCount = 429) and (v7 >= 7) then
      begin
        dbg_found := False;
        for dbg_row := 0 to 7 do
          for dbg_col := 0 to 7 do
            if dbg_dest_before[dbg_row * Integer(_mveBW) + dbg_col] >= 229 then
              dbg_found := True;
        if dbg_found then
          WriteLn(StdErr, '[BADPX] block=', dbg_blockIdx, ' type=', v7, ' pos=(', (dbg_blockIdx mod (Integer(_mveBW) div 8)) * 8, ',', (dbg_blockIdx div (Integer(_mveBW) div 8)) * 8, ')');
      end;
      Inc(dbg_blockIdx);

    end;

    dest := dest + var_8;
  end;
end;

// ===================================================================
// movie.cc implementation
// ===================================================================

function movieMalloc(size: SizeUInt): Pointer; cdecl;
begin
  Result := mymalloc(size, 'MOVIE.C', 209);
end;

procedure movieFree(ptr: Pointer); cdecl;
begin
  myfree(ptr, 'MOVIE.C', 213);
end;

function movieRead(ahandle: Pointer; buf: Pointer; count: Integer): Boolean; cdecl;
begin
  Result := db_fread(buf, 1, count, PDB_FILE(ahandle)) = count;
end;

procedure movie_MVE_ShowFrame(surface: PSDL_Surface; srcWidth, srcHeight, srcX, srcY, destWidth, destHeight, a8, a9: Integer); cdecl;
var
  v14, v15: Integer;
  srcRect, destRect: TSDL_Rect;
  sdl_pal_chk: LongWord;
  sdl_pi: Integer;
  pc: PSDL_Color;
begin
  srcRect.x := srcX;
  srcRect.y := srcY;
  srcRect.w := srcWidth;
  srcRect.h := srcHeight;

  v14 := winRect_.lrx - winRect_.ulx;
  v15 := winRect_.lrx - winRect_.ulx + 1;

  if movieScaleFlag <> 0 then
  begin
    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x08) <> 0 then
    begin
      destRect.y := (winRect_.lry - winRect_.uly + 1 - destHeight) div 2;
      destRect.x := (v15 - 4 * srcWidth div 3) div 2;
    end
    else
    begin
      destRect.y := movieY_ + winRect_.uly;
      destRect.x := winRect_.ulx + movieX_;
    end;

    destRect.w := 4 * srcWidth div 3 + destRect.x;
    destRect.h := destHeight + destRect.y;
  end
  else
  begin
    if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x08) <> 0 then
    begin
      destRect.y := (winRect_.lry - winRect_.uly + 1 - destHeight) div 2;
      destRect.x := (v15 - destWidth) div 2;
    end
    else
    begin
      destRect.y := movieY_ + winRect_.uly;
      destRect.x := winRect_.ulx + movieX_;
    end;
    destRect.w := destWidth;
    destRect.h := destHeight;
  end;

  lastMovieSX := srcX;
  lastMovieSY := srcY;
  lastMovieX := destRect.x;
  lastMovieY_ := destRect.y;
  lastMovieBH := srcHeight;
  lastMovieW := destRect.w;
  gMovieSdlSurface_movie := surface;
  lastMovieBW := srcWidth;
  lastMovieH := destRect.h;

  destRect.x := destRect.x + winRect_.ulx;
  destRect.y := destRect.y + winRect_.uly;

  if Assigned(movieCaptureFrameFunc) then
  begin
    if SDL_LockSurface(surface) = 0 then
    begin
      movieCaptureFrameFunc(PByte(surface^.pixels),
        srcWidth, srcHeight, surface^.pitch,
        destRect.x, destRect.y, destRect.w, destRect.h);
      SDL_UnlockSurface(surface);
    end;
  end;

  // Debug: check SDL palette before blit
  if (gSdlSurface <> nil) and (gSdlSurface^.format <> nil) and
     (gSdlSurface^.format^.palette <> nil) then
  begin
    sdl_pal_chk := 0;
    pc := gSdlSurface^.format^.palette^.colors;
    for sdl_pi := 0 to gSdlSurface^.format^.palette^.ncolors - 1 do
      sdl_pal_chk := sdl_pal_chk + pc[sdl_pi].r + pc[sdl_pi].g + pc[sdl_pi].b;
    WriteLn(StdErr, '[SDLPAL] frame=', _rm_FrameCount, ' sdl_sum=', sdl_pal_chk,
      ' ncolors=', gSdlSurface^.format^.palette^.ncolors,
      ' r0=', pc[0].r, ' g0=', pc[0].g, ' b0=', pc[0].b,
      ' r128=', pc[128].r, ' g128=', pc[128].g, ' b128=', pc[128].b);
  end
  else
    WriteLn(StdErr, '[SDLPAL] frame=', _rm_FrameCount, ' NO PALETTE!');

  SDL_SetSurfacePalette(surface, gSdlSurface^.format^.palette);
  SDL_BlitSurface(surface, @srcRect, gSdlSurface, @destRect);
  SDL_BlitSurface(gSdlSurface, nil, gSdlTextureSurface, nil);
  renderPresent;
end;

procedure movieShowFrame(a1: PSDL_Surface; a2, a3, a4, a5, a6, a7, a8, a9: Integer); cdecl;
var
  func: TMovieBlitFunc;
begin
  if GNWWin = -1 then
    Exit;

  lastMovieBW := a2;
  gMovieSdlSurface_movie := a1;
  lastMovieBH := a2;
  lastMovieW := a6;
  lastMovieH := a7;
  lastMovieX := a4;
  lastMovieY_ := a5;
  lastMovieSX := a4;
  lastMovieSY := a5;

  if SDL_LockSurface(a1) <> 0 then
    Exit;

  if Assigned(movieCaptureFrameFunc) then
    movieCaptureFrameFunc(PByte(a1^.pixels), a2, a3, a1^.pitch, movieRect_.ulx, movieRect_.uly, a6, a7);

  if Assigned(movieFrameGrabFunc) then
    movieFrameGrabFunc(PByte(a1^.pixels), a2, a3, a1^.pitch)
  else
  begin
    func := showFrameFuncs[movieAlphaFlag][movieScaleFlag][movieSubRectFlag];
    if func(GNWWin, PByte(a1^.pixels), a2, a3, a1^.pitch) <> 0 then
    begin
      if Assigned(preDrawFunc) then
        preDrawFunc(GNWWin, @movieRect_);

      win_draw_rect(GNWWin, @movieRect_);
    end;
  end;

  SDL_UnlockSurface(a1);
end;

procedure movieSetPreDrawFunc(func: TMoviePreDrawFunc);
begin
  preDrawFunc := func;
end;

procedure movieSetFailedOpenFunc(func: TMovieFailedOpenFunc);
begin
  failedOpenFunc := func;
end;

procedure movieSetFunc(startFunc: TMovieStartFunc; endFunc: TMovieEndFunc);
begin
  startMovieFunc := startFunc;
  endMovieFunc := endFunc;
end;

procedure movieSetFrameGrabFunc(func: TMovieFrameGrabProc);
begin
  movieFrameGrabFunc := func;
end;

procedure movieSetCaptureFrameFunc(func: TMovieCaptureFrameProc);
begin
  movieCaptureFrameFunc := func;
end;

function movieScaleSubRect(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
  v1, x, y: Integer;
  value: LongWord;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win) + windowWidth * movieY_ + movieX_;
  if width * 4 div 3 > movieW_ then
  begin
    movieFlags_ := movieFlags_ or $01;
    Exit(0);
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

      windowBuffer := windowBuffer + 4;
      data := data + 3;
    end;

    x := v1 * 3;
    while x < width do
    begin
      windowBuffer^ := data^;
      Inc(windowBuffer);
      Inc(data);
      Inc(x);
    end;

    data := data + (pitch - width);
    windowBuffer := windowBuffer + (windowWidth - movieW_);
  end;

  Result := 1;
end;

function movieScaleWindowAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
begin
  movieFlags_ := movieFlags_ or 1;
  Result := 0;
end;

function movieScaleSubRectAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
begin
  movieFlags_ := movieFlags_ or 1;
  Result := 0;
end;

function blitAlpha(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win);
  alphaBltBuf(data, width, height, pitch, alphaWindowBuf, alphaBuf_, windowBuffer + windowWidth * movieY_ + movieX_, windowWidth);
  Result := 1;
end;

function movieScaleWindow(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
  y, scaledWidth, x: Integer;
  value: LongWord;
begin
  windowWidth := win_width(win);
  if width <> 3 * windowWidth div 4 then
  begin
    movieFlags_ := movieFlags_ or 1;
    Exit(0);
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

      windowBuffer := windowBuffer + 4;
      data := data + 3;
    end;
    data := data + (pitch - width);
  end;

  Result := 1;
end;

function blitNormal(win: Integer; data: PByte; width, height, pitch: Integer): Integer;
var
  windowWidth: Integer;
  windowBuffer: PByte;
begin
  windowWidth := win_width(win);
  windowBuffer := win_get_buf(win);
  drawScaled(windowBuffer + windowWidth * movieY_ + movieX_, movieW_, movieH_, windowWidth, data, width, height, pitch);
  Result := 1;
end;

procedure movieSetPalette_internal(palette: PByte; start, end_: Integer); cdecl;
begin
  if end_ <> 0 then
    paletteFunc(palette + start * 3, start, end_ + start - 1);
end;

function noop: Integer;
begin
  Result := 0;
end;

procedure initMovie;
begin
  movieLibSetMemoryProcs(@movieMalloc, @movieFree);
  movieLibSetPaletteEntriesProc(@movieSetPalette_internal);
  _MVE_sfSVGA(640, 480, 480, 0, 0, 0, 0, 0, 0);
  movieLibSetReadProc(@movieRead);
end;

procedure cleanupMovie(a1: Integer);
var
  frame, dropped: Integer;
  next: PMovieSubtitleListNode;
begin
  if running_ = 0 then
    Exit;

  if Assigned(endMovieFunc) then
    endMovieFunc(GNWWin, movieX_, movieY_, movieW_, movieH_);

  _MVE_rmFrameCounts(@frame, @dropped);
  debug_printf('Frames %d, dropped %d'#10, [frame, dropped]);

  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 787);
    lastMovieBuffer := nil;
  end;

  if gMovieSdlSurface_movie <> nil then
  begin
    if SDL_LockSurface(gMovieSdlSurface_movie) = 0 then
    begin
      lastMovieBuffer := PByte(mymalloc(lastMovieBH * lastMovieBW, 'MOVIE.C', 802));
      buf_to_buf(PByte(gMovieSdlSurface_movie^.pixels) + gMovieSdlSurface_movie^.pitch * lastMovieSX + lastMovieSY,
        lastMovieBW, lastMovieBH, gMovieSdlSurface_movie^.pitch, lastMovieBuffer, lastMovieBW);
      SDL_UnlockSurface(gMovieSdlSurface_movie);
    end
    else
      debug_printf('Couldn''t lock movie surface'#10, []);

    gMovieSdlSurface_movie := nil;
  end;

  if a1 <> 0 then
    _MVE_rmEndMovie;

  _MVE_ReleaseMem;

  db_fclose(handle_);

  if alphaWindowBuf <> nil then
  begin
    buf_to_buf(alphaWindowBuf, movieW_, movieH_, movieW_,
      win_get_buf(GNWWin) + movieY_ * win_width(GNWWin) + movieX_, win_width(GNWWin));
    win_draw_rect(GNWWin, @movieRect_);
  end;

  if alphaHandle_ <> nil then
  begin
    db_fclose(alphaHandle_);
    alphaHandle_ := nil;
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

  running_ := 0;
  movieSubRectFlag := 0;
  movieScaleFlag := 0;
  movieAlphaFlag := 0;
  movieFlags_ := 0;
  GNWWin := -1;
end;

procedure movieClose;
begin
  cleanupMovie(1);

  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 869);
    lastMovieBuffer := nil;
  end;
end;

procedure movieStop;
begin
  if running_ <> 0 then
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x02;
end;

function movieSetFlags(a1: Integer): Integer;
begin
  if (a1 and MOVIE_FLAG_0x04) <> 0 then
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x04 or MOVIE_EXTENDED_FLAG_0x08
  else
  begin
    movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x08));
    if (a1 and MOVIE_FLAG_0x02) <> 0 then
      movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x04
    else
      movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x04));
  end;

  if (a1 and MOVIE_FLAG_0x01) <> 0 then
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

  if (a1 and MOVIE_FLAG_0x08) <> 0 then
    movieFlags_ := movieFlags_ or MOVIE_EXTENDED_FLAG_0x10
  else
    movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x10));

  Result := 0;
end;

procedure movieSetSubtitleFont(font: Integer);
begin
  subtitleFont := font;
end;

procedure movieSetSubtitleColor(r, g, b: Single);
begin
  subtitleR := Trunc(r * 31.0);
  subtitleG := Trunc(g * 31.0);
  subtitleB := Trunc(b * 31.0);
end;

procedure movieSetPaletteFunc(func: TMoviePaletteFunc);
begin
  if Assigned(func) then
    paletteFunc := func
  else
    paletteFunc := @GNW95_SetPaletteEntries;
end;

procedure movieSetCallback(func: TMovieUpdateCallbackProc);
begin
  updateCallbackFunc := func;
end;

procedure cleanupLast;
begin
  if lastMovieBuffer <> nil then
  begin
    myfree(lastMovieBuffer, 'MOVIE.C', 981);
    lastMovieBuffer := nil;
  end;

  gMovieSdlSurface_movie := nil;
end;

function openFile(filePath: PAnsiChar): PDB_FILE;
begin
  handle_ := db_fopen(filePath, 'rb');
  if handle_ = nil then
  begin
    if not Assigned(failedOpenFunc) then
    begin
      debug_printf('Couldn''t find movie file %s'#10, [filePath]);
      Exit(nil);
    end;

    while (handle_ = nil) and (failedOpenFunc(filePath) <> 0) do
      handle_ := db_fopen(filePath, 'rb');
  end;
  Result := handle_;
end;

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

  if Assigned(subtitleFilenameFunc) then
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

    subtitle := PMovieSubtitleListNode(mymalloc(SizeOf(TMovieSubtitleListNode), 'MOVIE.C', 1050));
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
      debug_printf('subtitle: couldn''t parse %s'#10, [PAnsiChar(@str[0])]);
  end;

  db_fclose(stream);

  debug_printf('Read %d subtitles'#10, [subtitleCount]);
end;

procedure doSubtitle;
var
  v1, v2: Integer;
  frame, dropped: Integer;
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
  v2 := (480 - lastMovieH - lastMovieY_ - v1) div 2 + lastMovieH + lastMovieY_;

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
      oldFont := text_curr;
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

function movieStart(win: Integer; filePath: PAnsiChar; a3: Pointer): Integer;
var
  v15, v16, v17: Integer;
  tmp: SmallInt;
  size_: LongWord;
  windowBuffer: PByte;
begin
  if running_ <> 0 then
    Exit(1);

  cleanupLast;

  handle_ := openFile(filePath);
  if handle_ = nil then
    Exit(1);

  GNWWin := win;
  running_ := 1;
  movieFlags_ := movieFlags_ and (not LongWord(MOVIE_EXTENDED_FLAG_0x01));

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x10) <> 0 then
    openSubtitle(filePath);

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x04) <> 0 then
  begin
    debug_printf('Direct ', []);
    win_get_rect(GNWWin, @winRect_);
    debug_printf('Playing at (%d, %d)  ', [movieX_ + winRect_.ulx, movieY_ + winRect_.uly]);
    _MVE_rmCallbacks(a3);
    _MVE_sfCallbacks(@movie_MVE_ShowFrame);

    v17 := 0;
    v16 := movieY_ + winRect_.uly;
    v15 := movieX_ + winRect_.ulx;
  end
  else
  begin
    debug_printf('Buffered ', []);
    _MVE_rmCallbacks(a3);
    _MVE_sfCallbacks(@movieShowFrame);
    v17 := 0;
    v16 := 0;
    v15 := 0;
  end;

  _MVE_rmPrepMovie(handle_, v15, v16, AnsiChar(v17));

  if movieScaleFlag <> 0 then
    debug_printf('scaled'#10, [])
  else
    debug_printf('not scaled'#10, []);

  if Assigned(startMovieFunc) then
    startMovieFunc(GNWWin);

  if alphaHandle_ <> nil then
  begin
    db_freadLong(alphaHandle_, @size_);

    db_freadInt16(alphaHandle_, @tmp);
    db_freadInt16(alphaHandle_, @tmp);

    alphaBuf_ := PByte(mymalloc(size_, 'MOVIE.C', 1178));
    alphaWindowBuf := PByte(mymalloc(movieH_ * movieW_, 'MOVIE.C', 1179));

    windowBuffer := win_get_buf(GNWWin);
    buf_to_buf(windowBuffer + win_width(GNWWin) * movieY_ + movieX_,
      movieW_, movieH_, win_width(GNWWin), alphaWindowBuf, movieW_);
  end;

  movieRect_.ulx := movieX_;
  movieRect_.uly := movieY_;
  movieRect_.lrx := movieW_ + movieX_;
  movieRect_.lry := movieH_ + movieY_;

  Result := 0;
end;

function localMovieCallback: Boolean;
begin
  doSubtitle;

  if Assigned(movieCallback_) then
    movieCallback_;

  Result := get_input <> -1;
end;

function movieRun(win: Integer; filePath: PAnsiChar): Integer;
begin
  if running_ <> 0 then
    Exit(1);

  movieX_ := 0;
  movieY_ := 0;
  movieOffset_ := 0;
  movieW_ := win_width(win);
  movieH_ := win_height(win);
  movieSubRectFlag := 0;
  Result := movieStart(win, filePath, @noop);
end;

function movieRunRect(win: Integer; filePath: PAnsiChar; a3, a4, a5, a6: Integer): Integer;
begin
  if running_ <> 0 then
    Exit(1);

  movieX_ := a3;
  movieY_ := a4;
  movieOffset_ := a3 + a4 * win_width(win);
  movieW_ := a5;
  movieH_ := a6;
  movieSubRectFlag := 1;

  Result := movieStart(win, filePath, @noop);
end;

function stepMovie_internal: Integer;
var
  rc: Integer;
  size_: LongWord;
begin
  if alphaHandle_ <> nil then
  begin
    db_freadLong(alphaHandle_, @size_);
    db_fread(alphaBuf_, 1, size_, alphaHandle_);
  end;

  rc := _MVE_rmStepMovie;
  if rc <> -1 then
    doSubtitle;

  Result := rc;
end;

procedure movieSetSubtitleFunc(func: TMovieSubtitleFunc);
begin
  subtitleFilenameFunc := func;
end;

procedure movieSetVolume(volume: Integer);
var
  normalized_volume: Integer;
begin
  normalized_volume := soundVolumeHMItoDirectSound(volume);
  movieLibSetVolume(normalized_volume);
end;

procedure movieUpdate;
var
  frame, dropped: Integer;
begin
  if running_ = 0 then
    Exit;

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x02) <> 0 then
  begin
    debug_printf('Movie aborted'#10, []);
    cleanupMovie(1);
    Exit;
  end;

  if (movieFlags_ and MOVIE_EXTENDED_FLAG_0x01) <> 0 then
  begin
    debug_printf('Movie error'#10, []);
    cleanupMovie(1);
    Exit;
  end;

  if stepMovie_internal = -1 then
  begin
    cleanupMovie(1);
    Exit;
  end;

  if Assigned(updateCallbackFunc) then
  begin
    _MVE_rmFrameCounts(@frame, @dropped);
    updateCallbackFunc(frame);
  end;
end;

function moviePlaying: Integer;
begin
  Result := running_;
end;

// ===================================================================
// Initialization
// ===================================================================
initialization
  // Initialize showFrameFuncs array
  showFrameFuncs[0][0][0] := @blitNormal;
  showFrameFuncs[0][0][1] := @blitNormal;
  showFrameFuncs[0][1][0] := @movieScaleWindow;
  showFrameFuncs[0][1][1] := @movieScaleSubRect;
  showFrameFuncs[1][0][0] := @blitAlpha;
  showFrameFuncs[1][0][1] := @blitAlpha;
  showFrameFuncs[1][1][0] := @movieScaleSubRectAlpha;
  showFrameFuncs[1][1][1] := @movieScaleWindowAlpha;

  // Set default palette function
  paletteFunc := @GNW95_SetPaletteEntries;

  // Initialize _sf_ShowFrame default
  _sf_ShowFrame := @_do_nothing_2;

  // Initialize io_mem_buf
  FillChar(_io_mem_buf, SizeOf(_io_mem_buf), 0);

end.
