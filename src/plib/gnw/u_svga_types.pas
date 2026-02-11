{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/svga_types.h
// Video system callback types and VideoOptions record.
unit u_svga_types;

interface

type
  TUpdatePaletteFunc = procedure; cdecl;
  TResetModeFunc = procedure; cdecl;
  TSetModeFunc = function: Integer; cdecl;

  TScreenTransBlitFunc = procedure(srcBuf: PByte; srcW, srcH, subX, subY,
    subW, subH, dstX, dstY: LongWord; trans: Byte); cdecl;
  PScreenTransBlitFunc = ^TScreenTransBlitFunc;

  TScreenBlitFunc = procedure(srcBuf: PByte; srcW, srcH, subX, subY,
    subW, subH, dstX, dstY: LongWord); cdecl;
  PScreenBlitFunc = ^TScreenBlitFunc;

  PVideoOptions = ^TVideoOptions;
  TVideoOptions = record
    Width: Integer;
    Height: Integer;
    Fullscreen: LongBool;
    Scale: Integer;
  end;

implementation

end.
