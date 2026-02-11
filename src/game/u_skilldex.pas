unit u_skilldex;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  SKILLDEX_RC_ERROR    = -1;
  SKILLDEX_RC_CANCELED = 0;
  SKILLDEX_RC_SNEAK    = 1;
  SKILLDEX_RC_LOCKPICK = 2;
  SKILLDEX_RC_STEAL    = 3;
  SKILLDEX_RC_TRAPS    = 4;
  SKILLDEX_RC_FIRST_AID = 5;
  SKILLDEX_RC_DOCTOR   = 6;
  SKILLDEX_RC_SCIENCE  = 7;
  SKILLDEX_RC_REPAIR   = 8;

function skilldex_select: Integer;

implementation

uses
  SysUtils,
  u_cache,
  u_input,
  u_svga,
  u_gnw,
  u_grbuf,
  u_art,
  u_gmouse,
  u_gsound,
  u_message,
  u_skill,
  u_map,
  u_cycle,
  u_memory,
  u_object,
  u_text,
  u_game,
  u_object_types,
  u_color,
  u_button;

const
  COMPAT_MAX_PATH = 260;

  SKILLDEX_WINDOW_RIGHT_MARGIN  = 4;
  SKILLDEX_WINDOW_BOTTOM_MARGIN = 6;

  SKILLDEX_FRM_BACKGROUND             = 0;
  SKILLDEX_FRM_BUTTON_ON              = 1;
  SKILLDEX_FRM_BUTTON_OFF             = 2;
  SKILLDEX_FRM_LITTLE_RED_BUTTON_UP   = 3;
  SKILLDEX_FRM_LITTLE_RED_BUTTON_DOWN = 4;
  SKILLDEX_FRM_BIG_NUMBERS            = 5;
  SKILLDEX_FRM_COUNT                  = 6;

  SKILLDEX_SKILL_SNEAK    = 0;
  SKILLDEX_SKILL_LOCKPICK = 1;
  SKILLDEX_SKILL_STEAL    = 2;
  SKILLDEX_SKILL_TRAPS    = 3;
  SKILLDEX_SKILL_FIRST_AID = 4;
  SKILLDEX_SKILL_DOCTOR   = 5;
  SKILLDEX_SKILL_SCIENCE  = 6;
  SKILLDEX_SKILL_REPAIR   = 7;
  SKILLDEX_SKILL_COUNT    = 8;

  SKILLDEX_SKILL_BUTTON_BUFFER_COUNT = SKILLDEX_SKILL_COUNT * 2;

  SKILL_SNEAK     = 8;
  SKILL_LOCKPICK  = 9;
  SKILL_STEAL     = 10;
  SKILL_TRAPS     = 11;
  SKILL_FIRST_AID = 12;
  SKILL_DOCTOR    = 13;
  SKILL_SCIENCE   = 14;
  SKILL_REPAIR    = 15;

  INTERFACE_BAR_WIDTH  = 640;
  INTERFACE_BAR_HEIGHT = 100;

  MOUSE_CURSOR_ARROW = 0;

  WINDOW_MODAL          = $20;
  WINDOW_DONT_MOVE_TOP  = $100;

  BUTTON_FLAG_TRANSPARENT = $20;

  KEY_ESCAPE      = 27;
  KEY_RETURN      = 13;
  KEY_UPPERCASE_S = 83;
  KEY_LOWERCASE_S = 115;

  MESSAGE_LIST_ITEM_FIELD_MAX_SIZE = 1024;

type
  TSize = record
    width: Integer;
    height: Integer;
  end;

// External declarations
procedure debug_printf(fmt: PAnsiChar); cdecl; varargs; external name 'debug_printf';

// colorTable imported from u_color

var
  bk_enable: Boolean = False;

  grphfid: array[0..SKILLDEX_FRM_COUNT-1] of Integer = (
    121, 119, 120, 8, 9, 170
  );

  sklxref: array[0..SKILLDEX_SKILL_COUNT-1] of Integer = (
    SKILL_SNEAK,
    SKILL_LOCKPICK,
    SKILL_STEAL,
    SKILL_TRAPS,
    SKILL_FIRST_AID,
    SKILL_DOCTOR,
    SKILL_SCIENCE,
    SKILL_REPAIR
  );

  ginfo: array[0..SKILLDEX_FRM_COUNT-1] of TSize;
  skldxbtn: array[0..SKILLDEX_SKILL_BUTTON_BUFFER_COUNT-1] of PByte;
  skldxmsg: TMessageList;
  mesg: TMessageListItem;
  skldxbmp: array[0..SKILLDEX_FRM_COUNT-1] of PByte;
  grphkey: array[0..SKILLDEX_FRM_COUNT-1] of PCacheEntry;
  skldxwin: Integer;
  winbuf: PByte;
  fontsave: Integer;

// Forward declarations
function skilldex_start: Integer; forward;
procedure skilldex_end; forward;

// Shared FPS limiter stub
type
  TFpsLimiter = record
    dummy: Integer;
  end;

procedure FpsLimiter_mark(var limiter: TFpsLimiter);
begin
  // stub
end;

procedure FpsLimiter_throttle(var limiter: TFpsLimiter);
begin
  // stub
end;

var
  sharedFpsLimiter: TFpsLimiter;

function skilldex_select: Integer;
var
  rc: Integer;
  keyCode: Integer;
begin
  if skilldex_start() = -1 then
  begin
    debug_printf(PAnsiChar(#10' ** Error loading skilldex dialog data! **'#10));
    Result := -1;
    Exit;
  end;

  rc := -1;
  while rc = -1 do
  begin
    FpsLimiter_mark(sharedFpsLimiter);

    keyCode := get_input();

    if (keyCode = KEY_ESCAPE) or (keyCode = KEY_UPPERCASE_S) or (keyCode = KEY_LOWERCASE_S) or (keyCode = 500) or (game_user_wants_to_quit <> 0) then
      rc := 0
    else if keyCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      rc := 0;
    end
    else if (keyCode >= 501) and (keyCode <= 509) then
      rc := keyCode - 500;

    renderPresent();
    FpsLimiter_throttle(sharedFpsLimiter);
  end;

  if rc <> 0 then
    block_for_tocks(1000 div 9);

  skilldex_end();

  Result := rc;
end;

function skilldex_start: Integer;
var
  path: array[0..COMPAT_MAX_PATH-1] of AnsiChar;
  frmIndex: Integer;
  fid: Integer;
  cycle: Boolean;
  buttonDataIndex: Integer;
  data: PByte;
  size: Integer;
  skilldexWindowX, skilldexWindowY: Integer;
  valueY: Integer;
  index: Integer;
  value: Integer;
  hundreds, tens, ones: Integer;
  lineHeight: Integer;
  buttonY, nameY: Integer;
  name: array[0..MESSAGE_LIST_ITEM_FIELD_MAX_SIZE-1] of AnsiChar;
  nameX: Integer;
  btn: Integer;
  cancel: PAnsiChar;
  cancelBtn: Integer;
  title: PAnsiChar;
begin
  fontsave := text_curr();
  bk_enable := False;

  gmouse_3d_off();
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  if not message_init(@skldxmsg) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(path, SizeOf(path) - 1, '%s%s', [msg_path, PAnsiChar('skilldex.msg')]);

  if not message_load(@skldxmsg, path) then
  begin
    Result := -1;
    Exit;
  end;

  frmIndex := 0;
  while frmIndex < SKILLDEX_FRM_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, grphfid[frmIndex], 0, 0, 0);
    skldxbmp[frmIndex] := art_lock(fid, @grphkey[frmIndex], @ginfo[frmIndex].width, @ginfo[frmIndex].height);
    if skldxbmp[frmIndex] = nil then
      Break;
    Inc(frmIndex);
  end;

  if frmIndex < SKILLDEX_FRM_COUNT then
  begin
    Dec(frmIndex);
    while frmIndex >= 0 do
    begin
      art_ptr_unlock(grphkey[frmIndex]);
      Dec(frmIndex);
    end;
    message_exit(@skldxmsg);
    Result := -1;
    Exit;
  end;

  cycle := False;
  buttonDataIndex := 0;
  while buttonDataIndex < SKILLDEX_SKILL_BUTTON_BUFFER_COUNT do
  begin
    skldxbtn[buttonDataIndex] := PByte(mem_malloc(ginfo[SKILLDEX_FRM_BUTTON_ON].height * ginfo[SKILLDEX_FRM_BUTTON_ON].width + 512));
    if skldxbtn[buttonDataIndex] = nil then
      Break;

    cycle := not cycle;

    if cycle then
    begin
      size := ginfo[SKILLDEX_FRM_BUTTON_OFF].width * ginfo[SKILLDEX_FRM_BUTTON_OFF].height;
      data := skldxbmp[SKILLDEX_FRM_BUTTON_OFF];
    end
    else
    begin
      size := ginfo[SKILLDEX_FRM_BUTTON_ON].width * ginfo[SKILLDEX_FRM_BUTTON_ON].height;
      data := skldxbmp[SKILLDEX_FRM_BUTTON_ON];
    end;

    Move(data^, skldxbtn[buttonDataIndex]^, size);
    Inc(buttonDataIndex);
  end;

  if buttonDataIndex < SKILLDEX_SKILL_BUTTON_BUFFER_COUNT then
  begin
    Dec(buttonDataIndex);
    while buttonDataIndex >= 0 do
    begin
      mem_free(skldxbtn[buttonDataIndex]);
      Dec(buttonDataIndex);
    end;

    for index := 0 to SKILLDEX_FRM_COUNT - 1 do
      art_ptr_unlock(grphkey[index]);

    message_exit(@skldxmsg);
    Result := -1;
    Exit;
  end;

  skilldexWindowX := (screenGetWidth() - INTERFACE_BAR_WIDTH) div 2 + INTERFACE_BAR_WIDTH - ginfo[SKILLDEX_FRM_BACKGROUND].width - SKILLDEX_WINDOW_RIGHT_MARGIN;
  skilldexWindowY := screenGetHeight() - INTERFACE_BAR_HEIGHT - 1 - ginfo[SKILLDEX_FRM_BACKGROUND].height - SKILLDEX_WINDOW_BOTTOM_MARGIN;
  skldxwin := win_add(skilldexWindowX,
    skilldexWindowY,
    ginfo[SKILLDEX_FRM_BACKGROUND].width,
    ginfo[SKILLDEX_FRM_BACKGROUND].height,
    256,
    WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);

  if skldxwin = -1 then
  begin
    for index := 0 to SKILLDEX_SKILL_BUTTON_BUFFER_COUNT - 1 do
      mem_free(skldxbtn[index]);

    for index := 0 to SKILLDEX_FRM_COUNT - 1 do
      art_ptr_unlock(grphkey[index]);

    message_exit(@skldxmsg);
    Result := -1;
    Exit;
  end;

  bk_enable := map_disable_bk_processes();

  cycle_disable();
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  winbuf := win_get_buf(skldxwin);
  Move(skldxbmp[SKILLDEX_FRM_BACKGROUND]^, winbuf^,
    ginfo[SKILLDEX_FRM_BACKGROUND].width * ginfo[SKILLDEX_FRM_BACKGROUND].height);

  text_font(103);

  // Render "SKILLDEX" title
  title := getmsg(@skldxmsg, @mesg, 100);
  text_to_buf(winbuf + 14 * ginfo[SKILLDEX_FRM_BACKGROUND].width + 55,
    title,
    ginfo[SKILLDEX_FRM_BACKGROUND].width,
    ginfo[SKILLDEX_FRM_BACKGROUND].width,
    colorTable[18979]);

  // Render skill values
  valueY := 48;
  for index := 0 to SKILLDEX_SKILL_COUNT - 1 do
  begin
    value := skill_level(obj_dude, sklxref[index]);
    if value = -1 then
      value := 0;

    hundreds := value div 100;
    buf_to_buf(skldxbmp[SKILLDEX_FRM_BIG_NUMBERS] + 14 * hundreds,
      14, 24, 336,
      winbuf + ginfo[SKILLDEX_FRM_BACKGROUND].width * valueY + 110,
      ginfo[SKILLDEX_FRM_BACKGROUND].width);

    tens := (value mod 100) div 10;
    buf_to_buf(skldxbmp[SKILLDEX_FRM_BIG_NUMBERS] + 14 * tens,
      14, 24, 336,
      winbuf + ginfo[SKILLDEX_FRM_BACKGROUND].width * valueY + 124,
      ginfo[SKILLDEX_FRM_BACKGROUND].width);

    ones := (value mod 100) mod 10;
    buf_to_buf(skldxbmp[SKILLDEX_FRM_BIG_NUMBERS] + 14 * ones,
      14, 24, 336,
      winbuf + ginfo[SKILLDEX_FRM_BACKGROUND].width * valueY + 138,
      ginfo[SKILLDEX_FRM_BACKGROUND].width);

    valueY := valueY + 36;
  end;

  // Render skill buttons
  lineHeight := text_height();

  buttonY := 45;
  nameY := ((ginfo[SKILLDEX_FRM_BUTTON_OFF].height - lineHeight) div 2) + 1;
  for index := 0 to SKILLDEX_SKILL_COUNT - 1 do
  begin
    StrCopy(name, getmsg(@skldxmsg, @mesg, 102 + index));

    nameX := ((ginfo[SKILLDEX_FRM_BUTTON_OFF].width - text_width(name)) div 2) + 1;
    if nameX < 0 then
      nameX := 0;

    text_to_buf(skldxbtn[index * 2] + ginfo[SKILLDEX_FRM_BUTTON_ON].width * nameY + nameX,
      name,
      ginfo[SKILLDEX_FRM_BUTTON_ON].width,
      ginfo[SKILLDEX_FRM_BUTTON_ON].width,
      colorTable[18979]);

    text_to_buf(skldxbtn[index * 2 + 1] + ginfo[SKILLDEX_FRM_BUTTON_OFF].width * nameY + nameX,
      name,
      ginfo[SKILLDEX_FRM_BUTTON_OFF].width,
      ginfo[SKILLDEX_FRM_BUTTON_OFF].width,
      colorTable[14723]);

    btn := win_register_button(skldxwin,
      15,
      buttonY,
      ginfo[SKILLDEX_FRM_BUTTON_OFF].width,
      ginfo[SKILLDEX_FRM_BUTTON_OFF].height,
      -1, -1, -1,
      501 + index,
      skldxbtn[index * 2],
      skldxbtn[index * 2 + 1],
      nil,
      BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_sound_func(btn, @gsound_lrg_butt_press, @gsound_lrg_butt_release);

    buttonY := buttonY + 36;
  end;

  // Render "CANCEL" button
  cancel := getmsg(@skldxmsg, @mesg, 101);
  text_to_buf(winbuf + ginfo[SKILLDEX_FRM_BACKGROUND].width * 337 + 72,
    cancel,
    ginfo[SKILLDEX_FRM_BACKGROUND].width,
    ginfo[SKILLDEX_FRM_BACKGROUND].width,
    colorTable[18979]);

  cancelBtn := win_register_button(skldxwin,
    48, 338,
    ginfo[SKILLDEX_FRM_LITTLE_RED_BUTTON_UP].width,
    ginfo[SKILLDEX_FRM_LITTLE_RED_BUTTON_UP].height,
    -1, -1, -1,
    500,
    skldxbmp[SKILLDEX_FRM_LITTLE_RED_BUTTON_UP],
    skldxbmp[SKILLDEX_FRM_LITTLE_RED_BUTTON_DOWN],
    nil,
    BUTTON_FLAG_TRANSPARENT);
  if cancelBtn <> -1 then
    win_register_button_sound_func(cancelBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_draw(skldxwin);

  Result := 0;
end;

procedure skilldex_end;
var
  index: Integer;
begin
  win_delete(skldxwin);

  for index := 0 to SKILLDEX_SKILL_BUTTON_BUFFER_COUNT - 1 do
    mem_free(skldxbtn[index]);

  for index := 0 to SKILLDEX_FRM_COUNT - 1 do
    art_ptr_unlock(grphkey[index]);

  message_exit(@skldxmsg);

  text_font(fontsave);

  if bk_enable then
    map_enable_bk_processes();

  cycle_enable();

  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
end;

end.
