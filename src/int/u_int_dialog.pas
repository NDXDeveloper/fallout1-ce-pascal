{$MODE OBJFPC}{$H+}
// Converted from: src/int/dialog.cc/h
// Dialog system for the Fallout scripting engine.
unit u_int_dialog;

interface

uses
  u_intrpret;

type
  TDialogWinDrawCallback = procedure(win: Integer); cdecl;
  PDialogWinDrawCallback = ^TDialogWinDrawCallback;

var
  replyWinDrawCallback: TDialogWinDrawCallback = nil;
  optionsWinDrawCallback: TDialogWinDrawCallback = nil;

function dialogStart(a1: PProgram): Integer;
function dialogRestart: Integer;
function dialogGotoReply(a1: PAnsiChar): Integer;
function dialogTitle(a1: PAnsiChar): Integer;
function dialogReply(a1: PAnsiChar; a2: PAnsiChar): Integer;
function dialogOption(a1: PAnsiChar; a2: PAnsiChar): Integer;
function dialogOptionProc(a1: PAnsiChar; a2: Integer): Integer;
function dialogMessage(a1: PAnsiChar; a2: PAnsiChar; timeout: Integer): Integer;
function dialogGo(a1: Integer): Integer;
function dialogGetExitPoint: Integer;
function dialogQuit: Integer;
function dialogSetOptionWindow(x, y, width, height: Integer; backgroundFileName: PAnsiChar): Integer;
function dialogSetReplyWindow(x, y, width, height: Integer; backgroundFileName: PAnsiChar): Integer;
function dialogSetBorder(a1, a2: Integer): Integer;
function dialogSetScrollUp(a1, a2: Integer; a3, a4, a5, a6: PAnsiChar; a7: Integer): Integer;
function dialogSetScrollDown(a1, a2: Integer; a3, a4, a5, a6: PAnsiChar; a7: Integer): Integer;
function dialogSetSpacing(value: Integer): Integer;
function dialogSetOptionColor(a1, a2, a3: Single): Integer;
function dialogSetReplyColor(a1, a2, a3: Single): Integer;
function dialogSetOptionFlags(flags: SmallInt): Integer;
function dialogSetReplyFlags(flags: SmallInt): Integer;
procedure initDialog;
procedure dialogClose;
function dialogGetDialogDepth: Integer;
procedure dialogRegisterWinDrawCallbacks(reply: TDialogWinDrawCallback; options: TDialogWinDrawCallback);
function dialogToggleMediaFlag(a1: Integer): Integer;
function dialogGetMediaFlag: Integer;

implementation

uses
  SysUtils,
  u_memdbg,
  u_platform_compat,
  u_rect,
  u_gnw,
  u_mouse,
  u_text,
  u_int_window,
  u_int_movie;

type
  PSTRUCT_56DAE0_FIELD_4_FIELD_C = ^TSTRUCT_56DAE0_FIELD_4_FIELD_C;
  TSTRUCT_56DAE0_FIELD_4_FIELD_C = record
    field_0: PAnsiChar;
    case Integer of
      0: (proc: Integer);
      1: (str: PAnsiChar);
  end;

  // Additional fixed-layout fields stored separately because Pascal variant
  // records cannot have fields after the variant part.
  PSTRUCT_56DAE0_FIELD_4_FIELD_C_EXT = ^TSTRUCT_56DAE0_FIELD_4_FIELD_C_EXT;
  TSTRUCT_56DAE0_FIELD_4_FIELD_C_EXT = record
    field_0: PAnsiChar;
    case Integer of
      0: (proc: Integer);
      1: (str: PAnsiChar);
  end;

  // Full option record, laid out matching C struct
  PDialogOptionEntry = ^TDialogOptionEntry;
  TDialogOptionEntry = record
    field_0: PAnsiChar;       // option text (display label)
    proc_or_string: record    // union
      case Integer of
        0: (proc: Integer);
        1: (str: PAnsiChar);
    end;
    kind: Integer;            // 1 = proc, 2 = string/goto
    field_C: Integer;
    field_10: Integer;
    field_14: Integer;
    field_18: SmallInt;       // font number
    field_1A: SmallInt;       // option flags
  end;

  PDialogReplyEntry = ^TDialogReplyEntry;
  TDialogReplyEntry = record
    field_0: Pointer;
    field_4: PAnsiChar;
    field_8: Pointer;
    field_C: PDialogOptionEntry;
    field_10: Integer;
    field_14: Integer;
    field_18: Integer;  // probably font number
  end;

  PDialogEntry = ^TDialogEntry;
  TDialogEntry = record
    field_0: PProgram;
    field_4: PDialogReplyEntry;
    field_8: Integer;
    field_C: Integer;
    field_10: Integer;
    field_14: Integer;
    field_18: Integer;
  end;

  TDialogWindowData = record
    flags: SmallInt;
    width: Integer;
    height: Integer;
    x: Integer;
    y: Integer;
    backgroundFileName: PAnsiChar;
  end;

  TDialogScrollButtonData = record
    field_0: Integer;   // x
    field_4: Integer;   // y
    field_8: Integer;   // flags
    field_C: PAnsiChar; // normal image file name
    field_10: PAnsiChar; // pressed image file name
    field_14: PAnsiChar; // hover image file name
    field_18: PAnsiChar; // mask or disabled image file name
  end;

{ Forward declarations for static functions }
function getReply: PDialogReplyEntry; forward;
procedure replyAddOption(a1: PAnsiChar; a2: PAnsiChar; a3: Integer); forward;
procedure replyAddOptionProc(a1: PAnsiChar; a2: Integer; a3: Integer); forward;
procedure optionFree(a1: PDialogOptionEntry); forward;
procedure replyFree_; forward;
function endDialog_: Integer; forward;
procedure printLine(win: Integer; strings: PPAnsiChar; strings_num, a4, a5, a6, a7, a8, a9: Integer); forward;
procedure printStr(win: Integer; a2: PAnsiChar; a3, a4, a5, a6, a7, a8, a9: Integer); forward;
function abortReply(a1: Integer): Integer; forward;
procedure endReply; forward;
procedure drawStr(win: Integer; str: PAnsiChar; font, width, height, left, top, a8, a9, a10: Integer); forward;

var
  // 0x5184B4
  tods: Integer = -1;

  // 0x5184B8
  topDialogLine: Integer = 0;

  // 0x5184BC
  topDialogReply: Integer = 0;

  // 0x5184EC
  defaultBorderX: Integer = 7;

  // 0x5184F0
  defaultBorderY: Integer = 7;

  // 0x5184F4
  defaultSpacing_: Integer = 5;

  // 0x5184F8
  replyRGBset: Integer = 0;

  // 0x5184FC
  optionRGBset: Integer = 0;

  // 0x518500
  exitDialog_var: Integer = 0;

  // 0x518504
  inDialog: Integer = 0;

  // 0x518508
  mediaFlag_: Integer = 2;

  // 0x56DAE0
  dialog: array[0..3] of TDialogEntry;

  // 0x56DB60
  defaultOption: TDialogWindowData;

  // 0x56DB78
  defaultReply: TDialogWindowData;

  // 0x56DB90
  replyPlaying: Integer = 0;

  // 0x56DB94
  replyWin: Integer = -1;

  // 0x56DB98
  replyG: Integer;

  // 0x56DB9C
  replyB: Integer;

  // 0x56DBA4
  optionG: Integer;

  // 0x56DBA8
  replyR: Integer;

  // 0x56DBAC
  optionB: Integer;

  // 0x56DBB0
  optionR: Integer;

  // 0x56DBB4
  downButton: TDialogScrollButtonData;

  // 0x56DBD0
  replyTitleDefault: PAnsiChar;

  // 0x56DBD4
  upButton: TDialogScrollButtonData;

// 0x42F434
function getReply: PDialogReplyEntry;
var
  v0: PDialogReplyEntry;
  v1: PDialogOptionEntry;
begin
  v0 := @(dialog[tods].field_4[dialog[tods].field_C]);
  if v0^.field_C = nil then
  begin
    v0^.field_14 := 1;
    v1 := PDialogOptionEntry(mymalloc(SizeOf(TDialogOptionEntry), '..\int\DIALOG.C', 789));
  end
  else
  begin
    Inc(v0^.field_14);
    v1 := PDialogOptionEntry(myrealloc(v0^.field_C, SizeOf(TDialogOptionEntry) * v0^.field_14, '..\int\DIALOG.C', 793));
  end;
  v0^.field_C := v1;

  Result := v0;
end;

// 0x42F4C0
procedure replyAddOption(a1: PAnsiChar; a2: PAnsiChar; a3: Integer);
var
  v18: PDialogReplyEntry;
  v17: Integer;
  v14: PAnsiChar;
  v15: PAnsiChar;
begin
  v18 := getReply;
  v17 := v18^.field_14 - 1;
  v18^.field_C[v17].kind := 2;

  if a1 <> nil then
  begin
    v14 := PAnsiChar(mymalloc(StrLen(a1) + 1, '..\int\DIALOG.C', 805));
    StrCopy(v14, a1);
    v18^.field_C[v17].field_0 := v14;
  end
  else
    v18^.field_C[v17].field_0 := nil;

  if a2 <> nil then
  begin
    v15 := PAnsiChar(mymalloc(StrLen(a2) + 1, '..\int\DIALOG.C', 810));
    StrCopy(v15, a2);
    v18^.field_C[v17].proc_or_string.str := v15;
  end
  else
    v18^.field_C[v17].proc_or_string.str := nil;

  v18^.field_C[v17].field_18 := SmallInt(windowGetFont);
  v18^.field_C[v17].field_1A := defaultOption.flags;
  v18^.field_C[v17].field_14 := a3;
end;

// 0x42F624
procedure replyAddOptionProc(a1: PAnsiChar; a2: Integer; a3: Integer);
var
  v5: PDialogReplyEntry;
  v13: Integer;
  v11: PAnsiChar;
begin
  v5 := getReply;
  v13 := v5^.field_14 - 1;

  v5^.field_C[v13].kind := 1;

  if a1 <> nil then
  begin
    v11 := PAnsiChar(mymalloc(StrLen(a1) + 1, '..\int\DIALOG.C', 830));
    StrCopy(v11, a1);
    v5^.field_C[v13].field_0 := v11;
  end
  else
    v5^.field_C[v13].field_0 := nil;

  v5^.field_C[v13].proc_or_string.proc := a2;

  v5^.field_C[v13].field_18 := SmallInt(windowGetFont);
  v5^.field_C[v13].field_1A := defaultOption.flags;
  v5^.field_C[v13].field_14 := a3;
end;

// 0x42F714
procedure optionFree(a1: PDialogOptionEntry);
begin
  if a1^.field_0 <> nil then
    myfree(a1^.field_0, '..\int\DIALOG.C', 844);

  if a1^.kind = 2 then
  begin
    if a1^.proc_or_string.str <> nil then
      myfree(a1^.proc_or_string.str, '..\int\DIALOG.C', 846);
  end;
end;

// 0x42F754
procedure replyFree_;
var
  i: Integer;
  j: Integer;
  ptr: PDialogEntry;
  v6: PDialogReplyEntry;
begin
  ptr := @(dialog[tods]);
  for i := 0 to ptr^.field_8 - 1 do
  begin
    v6 := @(dialog[tods].field_4[i]);

    if v6^.field_C <> nil then
    begin
      for j := 0 to v6^.field_14 - 1 do
        optionFree(@(v6^.field_C[j]));

      myfree(v6^.field_C, '..\int\DIALOG.C', 857);
    end;

    if v6^.field_8 <> nil then
      myfree(v6^.field_8, '..\int\DIALOG.C', 860);

    if v6^.field_4 <> nil then
      myfree(v6^.field_4, '..\int\DIALOG.C', 862);

    if v6^.field_0 <> nil then
      myfree(v6^.field_0, '..\int\DIALOG.C', 864);
  end;

  if ptr^.field_4 <> nil then
    myfree(ptr^.field_4, '..\int\DIALOG.C', 867);
end;

// 0x42FB94
function endDialog_: Integer;
begin
  if tods = -1 then
    Exit(-1);

  topDialogReply := dialog[tods].field_10;
  replyFree_;

  if replyTitleDefault <> nil then
  begin
    myfree(replyTitleDefault, '..\int\DIALOG.C', 986);
    replyTitleDefault := nil;
  end;

  Dec(tods);

  Result := 0;
end;

// 0x42FC70
procedure printLine(win: Integer; strings: PPAnsiChar; strings_num, a4, a5, a6, a7, a8, a9: Integer);
var
  i: Integer;
  v11: Integer;
  strArr: PPAnsiChar;
begin
  strArr := strings;
  for i := 0 to strings_num - 1 do
  begin
    v11 := a7 + i * text_height();
    windowPrintBuf(win, PPAnsiChar(PByte(strArr) + SizeUInt(i) * SizeOf(PAnsiChar))^,
      StrLen(PPAnsiChar(PByte(strArr) + SizeUInt(i) * SizeOf(PAnsiChar))^),
      a4, a5 + a7, a6, v11, a8, a9);
  end;
end;

// 0x42FCF0
procedure printStr(win: Integer; a2: PAnsiChar; a3, a4, a5, a6, a7, a8, a9: Integer);
var
  strings: PPAnsiChar;
  strings_num: Integer;
begin
  strings := windowWordWrap(a2, a3, 0, @strings_num);
  printLine(win, strings, strings_num, a3, a4, a5, a6, a7, a8);
  windowFreeWordList(strings, strings_num);
end;

// 0x430104
function abortReply(a1: Integer): Integer;
var
  y: Integer;
  x: Integer;
begin
  if replyPlaying = 2 then
  begin
    if moviePlaying = 0 then
      Result := 1
    else
      Result := 0;
    Exit;
  end
  else if replyPlaying = 3 then
    Exit(1);

  Result := 1;
  if a1 <> 0 then
  begin
    if replyWin <> -1 then
    begin
      if (mouse_get_buttons and $10) = 0 then
        Result := 0
      else
      begin
        mouse_get_position(@x, @y);

        if win_get_top_win(x, y) <> replyWin then
          Result := 0;
      end;
    end;
  end;
end;

// 0x430180
procedure endReply;
begin
  if replyPlaying <> 2 then
  begin
    if replyPlaying = 1 then
    begin
      if ((mediaFlag_ and 2) = 0) and (replyWin <> -1) then
      begin
        win_delete(replyWin);
        replyWin := -1;
      end;
    end
    else if (replyPlaying <> 3) and (replyWin <> -1) then
    begin
      win_delete(replyWin);
      replyWin := -1;
    end;
  end;
end;

// 0x4301E8
procedure drawStr(win: Integer; str: PAnsiChar; font, width, height, left, top, a8, a9, a10: Integer);
var
  old_font: Integer;
  rect: TRect;
begin
  old_font := windowGetFont;
  windowSetFont(font);

  printStr(win, str, width, height, left, top, a8, a9, a10);

  rect.ulx := left;
  rect.uly := top;
  rect.lrx := width + left;
  rect.lry := height + top;
  win_draw_rect(win, @rect);
  windowSetFont(old_font);
end;

// 0x430D40
function dialogStart(a1: PProgram): Integer;
var
  ptr: PDialogEntry;
begin
  if tods = 3 then
    Exit(1);

  ptr := @(dialog[tods]);
  ptr^.field_0 := a1;
  ptr^.field_4 := nil;
  ptr^.field_8 := 0;
  ptr^.field_C := -1;
  ptr^.field_10 := -1;
  ptr^.field_14 := 1;
  ptr^.field_10 := 1;

  Inc(tods);

  Result := 0;
end;

// 0x430DB8
function dialogRestart: Integer;
begin
  if tods = -1 then
    Exit(1);

  dialog[tods].field_10 := 0;

  Result := 0;
end;

// 0x430DE4
function dialogGotoReply(a1: PAnsiChar): Integer;
var
  ptr: PDialogEntry;
  v5: PDialogReplyEntry;
  i: Integer;
begin
  if tods = -1 then
    Exit(1);

  if a1 <> nil then
  begin
    ptr := @(dialog[tods]);
    for i := 0 to ptr^.field_8 - 1 do
    begin
      v5 := @(ptr^.field_4[i]);
      if (v5^.field_4 <> nil) and (compat_stricmp(v5^.field_4, a1) = 0) then
      begin
        ptr^.field_10 := i;
        Exit(0);
      end;
    end;

    Exit(1);
  end;

  dialog[tods].field_10 := 0;

  Result := 0;
end;

// 0x430E84
function dialogTitle(a1: PAnsiChar): Integer;
begin
  if replyTitleDefault <> nil then
    myfree(replyTitleDefault, '..\int\DIALOG.C', 2561);

  if a1 <> nil then
  begin
    replyTitleDefault := PAnsiChar(mymalloc(StrLen(a1) + 1, '..\int\DIALOG.C', 2564));
    StrCopy(replyTitleDefault, a1);
  end
  else
    replyTitleDefault := nil;

  Result := 0;
end;

// 0x430EFC
function dialogReply(a1: PAnsiChar; a2: PAnsiChar): Integer;
begin
  // TODO: Incomplete.
  // _replyAddNew(a1, a2);
  Result := 0;
end;

// 0x430F04
function dialogOption(a1: PAnsiChar; a2: PAnsiChar): Integer;
begin
  if dialog[tods].field_C = -1 then
    Exit(0);

  replyAddOption(a1, a2, 0);

  Result := 0;
end;

// 0x430F38
function dialogOptionProc(a1: PAnsiChar; a2: Integer): Integer;
begin
  if dialog[tods].field_C = -1 then
    Exit(1);

  replyAddOptionProc(a1, a2, 0);

  Result := 0;
end;

// 0x430FD4
function dialogMessage(a1: PAnsiChar; a2: PAnsiChar; timeout: Integer): Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

// 0x431088
function dialogGo(a1: Integer): Integer;
begin
  // TODO: Incomplete.
  Result := -1;
end;

// 0x431184
function dialogGetExitPoint: Integer;
begin
  Result := topDialogLine + (topDialogReply shl 16);
end;

// 0x431198
function dialogQuit: Integer;
begin
  if inDialog <> 0 then
    exitDialog_var := 1
  else
    endDialog_;

  Result := 0;
end;

// 0x4311B8
function dialogSetOptionWindow(x, y, width, height: Integer; backgroundFileName: PAnsiChar): Integer;
begin
  defaultOption.x := x;
  defaultOption.y := y;
  defaultOption.width := width;
  defaultOption.height := height;
  defaultOption.backgroundFileName := backgroundFileName;

  Result := 0;
end;

// 0x4311E0
function dialogSetReplyWindow(x, y, width, height: Integer; backgroundFileName: PAnsiChar): Integer;
begin
  defaultReply.x := x;
  defaultReply.y := y;
  defaultReply.width := width;
  defaultReply.height := height;
  defaultReply.backgroundFileName := backgroundFileName;

  Result := 0;
end;

// 0x431208
function dialogSetBorder(a1, a2: Integer): Integer;
begin
  defaultBorderX := a1;
  defaultBorderY := a2;

  Result := 0;
end;

// 0x431218
function dialogSetScrollUp(a1, a2: Integer; a3, a4, a5, a6: PAnsiChar; a7: Integer): Integer;
begin
  upButton.field_0 := a1;
  upButton.field_4 := a2;

  if upButton.field_C <> nil then
    myfree(upButton.field_C, '..\int\DIALOG.C', 2750);
  upButton.field_C := a3;

  if upButton.field_10 <> nil then
    myfree(upButton.field_10, '..\int\DIALOG.C', 2752);
  upButton.field_10 := a4;

  if upButton.field_14 <> nil then
    myfree(upButton.field_14, '..\int\DIALOG.C', 2754);
  upButton.field_14 := a5;

  if upButton.field_18 <> nil then
    myfree(upButton.field_18, '..\int\DIALOG.C', 2756);
  upButton.field_18 := a6;

  upButton.field_8 := a7;

  Result := 0;
end;

// 0x4312C0
function dialogSetScrollDown(a1, a2: Integer; a3, a4, a5, a6: PAnsiChar; a7: Integer): Integer;
begin
  downButton.field_0 := a1;
  downButton.field_4 := a2;

  if downButton.field_C <> nil then
    myfree(downButton.field_C, '..\int\DIALOG.C', 2765);
  downButton.field_C := a3;

  if downButton.field_10 <> nil then
    myfree(downButton.field_10, '..\int\DIALOG.C', 2767);
  downButton.field_10 := a4;

  if downButton.field_14 <> nil then
    myfree(downButton.field_14, '..\int\DIALOG.C', 2769);
  downButton.field_14 := a5;

  if downButton.field_18 <> nil then
    myfree(downButton.field_18, '..\int\DIALOG.C', 2771);
  downButton.field_18 := a6;

  downButton.field_8 := a7;

  Result := 0;
end;

// 0x431368
function dialogSetSpacing(value: Integer): Integer;
begin
  defaultSpacing_ := value;

  Result := 0;
end;

// 0x431370
function dialogSetOptionColor(a1, a2, a3: Single): Integer;
begin
  optionR := Trunc(a1 * 31.0);
  optionG := Trunc(a2 * 31.0);
  optionB := Trunc(a3 * 31.0);

  optionRGBset := 1;

  Result := 0;
end;

// 0x4313C8
function dialogSetReplyColor(a1, a2, a3: Single): Integer;
begin
  replyR := Trunc(a1 * 31.0);
  replyG := Trunc(a2 * 31.0);
  replyB := Trunc(a3 * 31.0);

  replyRGBset := 1;

  Result := 0;
end;

// 0x431420
function dialogSetOptionFlags(flags: SmallInt): Integer;
begin
  defaultOption.flags := flags;

  Result := 1;
end;

// 0x431420
function dialogSetReplyFlags(flags: SmallInt): Integer;
begin
  // FIXME: Obvious error, flags should be set on defaultReply.
  defaultOption.flags := flags;

  Result := 1;
end;

// 0x431430
procedure initDialog;
begin
  // Empty in original.
end;

// 0x431434
procedure dialogClose;
begin
  if upButton.field_C <> nil then
    myfree(upButton.field_C, '..\int\DIALOG.C', 2818);

  if upButton.field_10 <> nil then
    myfree(upButton.field_10, '..\int\DIALOG.C', 2819);

  if upButton.field_14 <> nil then
    myfree(upButton.field_14, '..\int\DIALOG.C', 2820);

  if upButton.field_18 <> nil then
    myfree(upButton.field_18, '..\int\DIALOG.C', 2821);

  if downButton.field_C <> nil then
    myfree(downButton.field_C, '..\int\DIALOG.C', 2823);

  if downButton.field_10 <> nil then
    myfree(downButton.field_10, '..\int\DIALOG.C', 2824);

  if downButton.field_14 <> nil then
    myfree(downButton.field_14, '..\int\DIALOG.C', 2825);

  if downButton.field_18 <> nil then
    myfree(downButton.field_18, '..\int\DIALOG.C', 2826);
end;

// 0x431518
function dialogGetDialogDepth: Integer;
begin
  Result := tods;
end;

// 0x431520
procedure dialogRegisterWinDrawCallbacks(reply: TDialogWinDrawCallback; options: TDialogWinDrawCallback);
begin
  replyWinDrawCallback := reply;
  optionsWinDrawCallback := options;
end;

// 0x431530
function dialogToggleMediaFlag(a1: Integer): Integer;
begin
  if (a1 and mediaFlag_) = a1 then
    mediaFlag_ := mediaFlag_ and (not a1)
  else
    mediaFlag_ := mediaFlag_ or a1;

  Result := mediaFlag_;
end;

// 0x431554
function dialogGetMediaFlag: Integer;
begin
  Result := mediaFlag_;
end;

end.
