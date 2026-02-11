unit u_editor;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

// Converted from: src/game/editor.h + editor.cc
// Character editor: creation mode and level-up mode.

interface

uses
  u_db,
  u_object_types,
  u_proto_types;

var
  character_points: Integer;

function editor_design(isCreationMode: Boolean): Integer;
procedure CharEditInit;
function get_input_str(win, cancelKeyCode: Integer; text: PAnsiChar;
  maxLength, x, y, textColor, backgroundColor, flags: Integer): Integer;
function isdoschar(ch: Integer): Boolean;
function strmfe(dest: PAnsiChar; const name_: PAnsiChar; const ext: PAnsiChar): PAnsiChar;
function db_access(const fname: PAnsiChar): Boolean;
function AddSpaces(str: PAnsiChar; length_: Integer): PAnsiChar;
function itostndn(value: Integer; dest: PAnsiChar): PAnsiChar;
function editor_save(stream: PDB_FILE): Integer;
function editor_load(stream: PDB_FILE): Integer;
procedure editor_reset;
procedure RedrwDMPrk;

implementation

uses
  SysUtils,
  u_cache,
  u_rect,
  u_gnw_types,
  u_gnw,
  u_button,
  u_grbuf,
  u_text,
  u_input,
  u_mouse,
  u_svga,
  u_color,
  u_art,
  u_message,
  u_wordwrap,
  u_graphlib,
  u_platform_compat,
  u_debug,
  u_memory,
  u_kb,
  u_stat,
  u_stat_defs,
  u_skill,
  u_trait,
  u_perk,
  u_critter,
  u_bmpdlog,
  u_game_vars,
  u_fps_limiter,
  u_game,
  u_scripts,
  u_gmouse,
  u_cycle,
  u_map,
  u_int_sound,
  u_proto,
  u_palette,
  u_intface,
  u_object,
  u_item,
  u_gsound;

const
  RENDER_ALL_STATS = 7;
  EDITOR_WINDOW_WIDTH = 640;
  EDITOR_WINDOW_HEIGHT = 480;

  NAME_BUTTON_X = 9;
  NAME_BUTTON_Y = 0;
  TAG_SKILLS_BUTTON_X = 347;
  TAG_SKILLS_BUTTON_Y = 26;
  TAG_SKILLS_BUTTON_CODE = 536;

  PRINT_BTN_X = 363;
  PRINT_BTN_Y = 454;
  DONE_BTN_X = 475;
  DONE_BTN_Y = 454;
  CANCEL_BTN_X = 571;
  CANCEL_BTN_Y = 454;

  NAME_BTN_CODE = 517;
  AGE_BTN_CODE = 519;
  SEX_BTN_CODE = 520;

  OPTIONAL_TRAITS_LEFT_BTN_X = 23;
  OPTIONAL_TRAITS_RIGHT_BTN_X = 298;
  OPTIONAL_TRAITS_BTN_Y = 352;
  OPTIONAL_TRAITS_BTN_CODE = 555;
  OPTIONAL_TRAITS_BTN_SPACE = 2;

  SPECIAL_STATS_BTN_X = 149;

  PERK_WINDOW_X = 33;
  PERK_WINDOW_Y = 91;
  PERK_WINDOW_WIDTH = 573;
  PERK_WINDOW_HEIGHT = 230;

  PERK_WINDOW_LIST_X = 45;
  PERK_WINDOW_LIST_Y = 43;
  PERK_WINDOW_LIST_WIDTH = 192;
  PERK_WINDOW_LIST_HEIGHT = 129;

  FLAG_ANIMATE = $01;
  RED_NUMBERS = $02;
  BIG_NUM_WIDTH = 14;
  BIG_NUM_HEIGHT = 24;
  BIG_NUM_ANIMATION_DELAY = 123;
  DIALOG_PICKER_NUM_OPTIONS = 72;

  COMPAT_MAX_PATH = 260;
  PC_TRAIT_MAX = 2;
  PC_LEVEL_MAX = 21;
  SAVEABLE_STAT_COUNT = 35;

  // EditorFolder
  EDITOR_FOLDER_PERKS = 0;
  EDITOR_FOLDER_KARMA = 1;
  EDITOR_FOLDER_KILLS = 2;

  // Editor derived stats
  EDITOR_DERIVED_STAT_ARMOR_CLASS = 0;
  EDITOR_DERIVED_STAT_ACTION_POINTS = 1;
  EDITOR_DERIVED_STAT_CARRY_WEIGHT = 2;
  EDITOR_DERIVED_STAT_MELEE_DAMAGE = 3;
  EDITOR_DERIVED_STAT_DAMAGE_RESISTANCE = 4;
  EDITOR_DERIVED_STAT_POISON_RESISTANCE = 5;
  EDITOR_DERIVED_STAT_RADIATION_RESISTANCE = 6;
  EDITOR_DERIVED_STAT_SEQUENCE = 7;
  EDITOR_DERIVED_STAT_HEALING_RATE = 8;
  EDITOR_DERIVED_STAT_CRITICAL_CHANCE = 9;
  EDITOR_DERIVED_STAT_COUNT = 10;

  // Editor line identifiers
  EDITOR_FIRST_PRIMARY_STAT = 0;
  EDITOR_HIT_POINTS = 43;
  EDITOR_POISONED = 44;
  EDITOR_RADIATED = 45;
  EDITOR_EYE_DAMAGE = 46;
  EDITOR_CRIPPLED_RIGHT_ARM = 47;
  EDITOR_CRIPPLED_LEFT_ARM = 48;
  EDITOR_CRIPPLED_RIGHT_LEG = 49;
  EDITOR_CRIPPLED_LEFT_LEG = 50;
  EDITOR_FIRST_DERIVED_STAT = 51;
  EDITOR_FIRST_SKILL = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_COUNT; // 61
  EDITOR_TAG_SKILL = EDITOR_FIRST_SKILL + SKILL_COUNT; // 79
  EDITOR_SKILLS = 80;
  EDITOR_OPTIONAL_TRAITS = 81;
  EDITOR_FIRST_TRAIT = 82;
  EDITOR_BUTTONS_COUNT = EDITOR_FIRST_TRAIT + TRAIT_COUNT; // 98

  // Editor graphic IDs
  EDITOR_GRAPHIC_BIG_NUMBERS = 0;
  EDITOR_GRAPHIC_AGE_MASK = 1;
  EDITOR_GRAPHIC_AGE_OFF = 2;
  EDITOR_GRAPHIC_DOWN_ARROW_OFF = 3;
  EDITOR_GRAPHIC_DOWN_ARROW_ON = 4;
  EDITOR_GRAPHIC_NAME_MASK = 5;
  EDITOR_GRAPHIC_NAME_ON = 6;
  EDITOR_GRAPHIC_NAME_OFF = 7;
  EDITOR_GRAPHIC_FOLDER_MASK = 8;
  EDITOR_GRAPHIC_SEX_MASK = 9;
  EDITOR_GRAPHIC_SEX_OFF = 10;
  EDITOR_GRAPHIC_SEX_ON = 11;
  EDITOR_GRAPHIC_SLIDER = 12;
  EDITOR_GRAPHIC_SLIDER_MINUS_OFF = 13;
  EDITOR_GRAPHIC_SLIDER_MINUS_ON = 14;
  EDITOR_GRAPHIC_SLIDER_PLUS_OFF = 15;
  EDITOR_GRAPHIC_SLIDER_PLUS_ON = 16;
  EDITOR_GRAPHIC_SLIDER_TRANS_MINUS_OFF = 17;
  EDITOR_GRAPHIC_SLIDER_TRANS_MINUS_ON = 18;
  EDITOR_GRAPHIC_SLIDER_TRANS_PLUS_OFF = 19;
  EDITOR_GRAPHIC_SLIDER_TRANS_PLUS_ON = 20;
  EDITOR_GRAPHIC_UP_ARROW_OFF = 21;
  EDITOR_GRAPHIC_UP_ARROW_ON = 22;
  EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP = 23;
  EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN = 24;
  EDITOR_GRAPHIC_AGE_ON = 25;
  EDITOR_GRAPHIC_AGE_BOX = 26;
  EDITOR_GRAPHIC_ATTRIBOX = 27;
  EDITOR_GRAPHIC_ATTRIBWN = 28;
  EDITOR_GRAPHIC_CHARWIN = 29;
  EDITOR_GRAPHIC_DONE_BOX = 30;
  EDITOR_GRAPHIC_FEMALE_OFF = 31;
  EDITOR_GRAPHIC_FEMALE_ON = 32;
  EDITOR_GRAPHIC_MALE_OFF = 33;
  EDITOR_GRAPHIC_MALE_ON = 34;
  EDITOR_GRAPHIC_NAME_BOX = 35;
  EDITOR_GRAPHIC_LEFT_ARROW_UP = 36;
  EDITOR_GRAPHIC_LEFT_ARROW_DOWN = 37;
  EDITOR_GRAPHIC_RIGHT_ARROW_UP = 38;
  EDITOR_GRAPHIC_RIGHT_ARROW_DOWN = 39;
  EDITOR_GRAPHIC_BARARRWS = 40;
  EDITOR_GRAPHIC_OPTIONS_BASE = 41;
  EDITOR_GRAPHIC_OPTIONS_BUTTON_OFF = 42;
  EDITOR_GRAPHIC_OPTIONS_BUTTON_ON = 43;
  EDITOR_GRAPHIC_KARMA_FOLDER_SELECTED = 44;
  EDITOR_GRAPHIC_KILLS_FOLDER_SELECTED = 45;
  EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED = 46;
  EDITOR_GRAPHIC_KARMAFDR_PLACEHOLDER = 47;
  EDITOR_GRAPHIC_TAG_SKILL_BUTTON_OFF = 48;
  EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON = 49;
  EDITOR_GRAPHIC_COUNT = 50;

  // Stat constants
  STAT_STRENGTH = 0;
  STAT_PERCEPTION = 1;
  STAT_ENDURANCE = 2;
  STAT_CHARISMA = 3;
  STAT_INTELLIGENCE = 4;
  STAT_AGILITY = 5;
  STAT_LUCK = 6;
  STAT_MAXIMUM_HIT_POINTS = 7;
  STAT_MAXIMUM_ACTION_POINTS = 8;
  STAT_ARMOR_CLASS = 9;
  STAT_MELEE_DAMAGE = 11;
  STAT_CARRY_WEIGHT = 12;
  STAT_SEQUENCE = 13;
  STAT_HEALING_RATE = 14;
  STAT_CRITICAL_CHANCE = 15;
  STAT_DAMAGE_RESISTANCE = 17;
  STAT_RADIATION_RESISTANCE = 31;
  STAT_POISON_RESISTANCE = 32;
  STAT_AGE = 33;
  STAT_GENDER = 34;

  // PC stats
  PC_STAT_UNSPENT_SKILL_POINTS = 0;
  PC_STAT_LEVEL = 1;
  PC_STAT_EXPERIENCE = 2;

  // Critter flags
  PC_FLAG_LEVEL_UP_AVAILABLE = 3;

  // Mouse cursor
  MOUSE_CURSOR_ARROW = 1;

type
  PPPAnsiChar = ^PPAnsiChar;

  TEditorSortableEntry = record
    value: Integer;
    name: PAnsiChar;
  end;
  PEditorSortableEntry = ^TEditorSortableEntry;

// Forward declarations
function CharEditStart: Integer; forward;
procedure CharEditEnd; forward;
procedure RstrBckgProc; forward;
procedure DrawFolder; forward;
function ListKills: Integer; forward;
procedure PrintBigNum(x, y, flags, value, previousValue, windowHandle: Integer); forward;
procedure PrintLevelWin; forward;
procedure PrintBasicStat(stat: Integer; animate: Boolean; previousValue: Integer); forward;
procedure PrintGender; forward;
procedure PrintAgeBig; forward;
procedure PrintBigname; forward;
procedure ListDrvdStats; forward;
procedure ListSkills(a1: Integer); forward;
procedure DrawInfoWin; forward;
function NameWindow: Integer; forward;
procedure PrintName(buf: PByte; pitch: Integer); forward;
function AgeWindow: Integer; forward;
procedure SexWindow; forward;
procedure StatButton(eventCode: Integer); forward;
function OptionWindow: Integer; forward;
function Save_as_ASCII(const fileName: PAnsiChar): Integer; forward;
function AddDots(str: PAnsiChar; length_: Integer): PAnsiChar; forward;
procedure ResetScreen; forward;
procedure RegInfoAreas; forward;
function CheckValidPlayer: Integer; forward;
procedure SavePlayer; forward;
procedure RestorePlayer; forward;
function DrawCard(graphicId: Integer; const name_: PAnsiChar; const attributes: PAnsiChar; description: PAnsiChar): Integer; forward;
function XltPerk(search: Integer): Integer; forward;
procedure FldrButton; forward;
procedure InfoButton(eventCode: Integer); forward;
procedure SliderBtn(a1: Integer); forward;
function tagskl_free: Integer; forward;
procedure TagSkillSelect(skill: Integer); forward;
procedure ListTraits; forward;
function get_trait_count: Integer; forward;
procedure TraitSelect(trait_: Integer); forward;
function ListKarma: Integer; forward;
function XlateKarma(search: Integer): Integer; forward;
function UpdateLevel: Integer; forward;
procedure RedrwDPrks; forward;
function perks_dialog: Integer; forward;
function InputPDLoop(count: Integer; refreshProc: TProcedure): Integer; forward;
function ListDPerks: Integer; forward;
function GetMutateTrait: Boolean; forward;
procedure RedrwDMTagSkl; forward;
function Add4thTagSkill: Boolean; forward;
procedure ListNewTagSkills; forward;
function ListMyTraits(a1: Integer): Integer; forward;
function name_sort_comp(a1, a2: Pointer): Integer; forward;
function DrawCard2(frmId: Integer; const name_: PAnsiChar; const rank: PAnsiChar; description: PAnsiChar): Integer; forward;
procedure push_perks; forward;
procedure pop_perks; forward;
function PerkCount: Integer; forward;
function is_supper_bonus: Integer; forward;



// C's qsort
procedure qsort(base: Pointer; num, size: Integer; compar: Pointer); cdecl; external 'c' name 'qsort';
function strcmp(s1, s2: PAnsiChar): Integer; cdecl; external 'c' name 'strcmp';

// Helper to access game_global_vars by index
function ggv(idx: Integer): Integer; inline;
begin
  Result := PInteger(PByte(game_global_vars) + idx * SizeOf(Integer))^;
end;

// Helper: isalnum
function isalnum_c(ch: Integer): Boolean; inline;
begin
  Result := ((ch >= Ord('0')) and (ch <= Ord('9')))
         or ((ch >= Ord('A')) and (ch <= Ord('Z')))
         or ((ch >= Ord('a')) and (ch <= Ord('z')));
end;

// Const arrays
const
  grph_id: array[0..EDITOR_GRAPHIC_COUNT - 1] of Integer = (
    170, 175, 176, 181, 182, 183, 184, 185, 186, 187,
    188, 189, 190, 191, 192, 193, 194, 195, 196, 197,
    198, 199, 200, 8, 9, 204, 205, 206, 207, 208,
    209, 210, 211, 212, 213, 214, 122, 123, 124, 125,
    219, 220, 221, 222, 178, 179, 180, 38, 215, 216
  );

  copyflag: array[0..EDITOR_GRAPHIC_COUNT - 1] of Byte = (
    0, 0, 1, 0, 0, 0, 1, 1, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 1, 1, 1, 1, 0, 0
  );

  ndrvd: array[0..EDITOR_DERIVED_STAT_COUNT - 1] of SmallInt = (
    18, 19, 20, 21, 22, 23, 83, 24, 25, 26
  );

  StatYpos: array[0..6] of Integer = (
    37, 70, 103, 136, 169, 202, 235
  );

  karma_var_table: array[0..8] of Integer = (
    Ord(GVAR_BERSERKER_REPUTATION),
    Ord(GVAR_CHAMPION_REPUTATION),
    Ord(GVAR_CHILDKILLER_REPUATION),
    Ord(GVAR_NUKA_COLA_ADDICT),
    Ord(GVAR_BUFF_OUT_ADDICT),
    Ord(GVAR_MENTATS_ADDICT),
    Ord(GVAR_PSYCHO_ADDICT),
    Ord(GVAR_RADAWAY_ADDICT),
    Ord(GVAR_ALCOHOL_ADDICT)
  );

  karma_pic_table: array[0..9] of Integer = (
    48, 49, 51, 50, 52, 53, 53, 53, 53, 52
  );

  ndinfoxlt: array[0..EDITOR_DERIVED_STAT_COUNT - 1] of SmallInt = (
    STAT_ARMOR_CLASS,
    STAT_MAXIMUM_ACTION_POINTS,
    STAT_CARRY_WEIGHT,
    STAT_MELEE_DAMAGE,
    STAT_DAMAGE_RESISTANCE,
    STAT_POISON_RESISTANCE,
    STAT_RADIATION_RESISTANCE,
    STAT_SEQUENCE,
    STAT_HEALING_RATE,
    STAT_CRITICAL_CHANCE
  );

// Module-level variables (C static -> implementation vars)
var
  byte_431D93: array[0..63] of AnsiChar;

  bk_enable: Boolean = False;
  skill_cursor: Integer = 0;
  slider_y: Integer = 27;

  skillsav: array[0..SKILL_COUNT - 1] of Integer;
  editor_message_file: TMessageList;
  name_sort_list: array[0..DIALOG_PICKER_NUM_OPTIONS - 1] of TEditorSortableEntry;
  old_str1: array[0..47] of AnsiChar;
  old_str2: array[0..47] of AnsiChar;
  name_save: array[0..31] of AnsiChar;
  dude_data: TCritterProtoData;
  perk_back: array[0..PERK_COUNT - 1] of Integer;
  GInfo: array[0..EDITOR_GRAPHIC_COUNT - 1] of TSize;
  grph_key: array[0..EDITOR_GRAPHIC_COUNT - 1] of PCacheEntry;
  grphcpy: array[0..EDITOR_GRAPHIC_COUNT - 1] of PByte;
  grphbmp: array[0..EDITOR_GRAPHIC_COUNT - 1] of PByte;
  pbckgnd: PByte;
  pwin: Integer;
  SliderPlusID: Integer;
  SliderNegID: Integer;
  mesg: TMessageListItem;
  edit_win: Integer;
  pwin_buf: PByte;
  bckgnd: PByte;
  cline: Integer;
  oldsline: Integer;
  upsent_points_back: Integer;
  last_level: Integer;
  karma_count: Integer;
  fontsave: Integer;
  kills_count: Integer;
  bck_key: PCacheEntry;
  win_buf: PByte;
  hp_back: Integer;
  mouse_ypos: Integer;
  mouse_xpos: Integer;
  folder: Integer;
  crow: Integer;
  repFtime: LongWord;
  frame_time: LongWord;
  old_tags: Integer;
  last_level_back: Integer;
  glblmode: Boolean;
  tag_skill_back: array[0..NUM_TAGGED_SKILLS - 1] of Integer;
  old_fid2: Integer;
  old_fid1: Integer;
  trait_back: array[0..2] of Integer;
  trait_bids: array[0..TRAIT_COUNT - 1] of Integer;
  info_line: Integer;
  frstc_draw1: Boolean;
  frstc_draw2: Boolean;
  trait_count: Integer;
  optrt_count: Integer;
  temp_trait: array[0..2] of Integer;
  tagskill_count: Integer;
  temp_tag_skill: array[0..NUM_TAGGED_SKILLS - 1] of Integer;
  free_perk_back: AnsiChar;
  free_perk: Byte;
  first_skill_list: Byte;

// Static local for itostndn
const
  itostndn_v16: array[0..6] of Integer = (
    1000000, 100000, 10000, 1000, 100, 10, 1
  );

// ============================================================
// Implementation of all functions
// ============================================================

function editor_design(isCreationMode: Boolean): Integer;
var
  messageListItemText: PAnsiChar;
  line1: array[0..127] of AnsiChar;
  line2: array[0..127] of AnsiChar;
  lines: array[0..0] of PAnsiChar;
  rc: Integer;
  keyCode: Integer;
  done: Boolean;
begin
  lines[0] := @line2[0];
  glblmode := isCreationMode;
  SavePlayer;

  if CharEditStart = -1 then
  begin
    debug_printf(PAnsiChar(#10' ** Error loading character editor data! **'#10));
    Result := -1;
    Exit;
  end;

  if not glblmode then
  begin
    if UpdateLevel <> 0 then
    begin
      stat_recalc_derived(obj_dude);
      ListTraits;
      ListSkills(0);
      PrintBasicStat(RENDER_ALL_STATS, False, 0);
      ListDrvdStats;
      DrawInfoWin;
    end;
  end;

  rc := -1;
  while rc = -1 do
  begin
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    keyCode := get_input;

    done := False;
    if keyCode = 500 then
      done := True;

    if (keyCode = KEY_RETURN) or (keyCode = KEY_UPPERCASE_D) or (keyCode = KEY_LOWERCASE_D) then
    begin
      done := True;
      gsound_play_sfx_file('ib1p1xx1');
    end;

    if done then
    begin
      if glblmode then
      begin
        if character_points <> 0 then
        begin
          gsound_play_sfx_file('iisxxxx1');
          messageListItemText := getmsg(@editor_message_file, @mesg, 118);
          StrCopy(@line1[0], messageListItemText);
          messageListItemText := getmsg(@editor_message_file, @mesg, 119);
          StrCopy(@line2[0], messageListItemText);
          dialog_out(@line1[0], @lines[0], 1, 192, 126, colorTable[32328], nil, colorTable[32328], 0);
          win_draw(edit_win);
          rc := -1;
        end
        else if tagskill_count > 0 then
        begin
          gsound_play_sfx_file('iisxxxx1');
          messageListItemText := getmsg(@editor_message_file, @mesg, 142);
          StrCopy(@line1[0], messageListItemText);
          messageListItemText := getmsg(@editor_message_file, @mesg, 143);
          StrCopy(@line2[0], messageListItemText);
          dialog_out(@line1[0], @lines[0], 1, 192, 126, colorTable[32328], nil, colorTable[32328], 0);
          win_draw(edit_win);
          rc := -1;
        end
        else if is_supper_bonus <> 0 then
        begin
          gsound_play_sfx_file('iisxxxx1');
          messageListItemText := getmsg(@editor_message_file, @mesg, 157);
          StrCopy(@line1[0], messageListItemText);
          messageListItemText := getmsg(@editor_message_file, @mesg, 158);
          StrCopy(@line2[0], messageListItemText);
          dialog_out(@line1[0], @lines[0], 1, 192, 126, colorTable[32328], nil, colorTable[32328], 0);
          win_draw(edit_win);
          rc := -1;
        end
        else
          rc := 0;
      end
      else
        rc := 0;
    end
    else if (keyCode = KEY_CTRL_Q) or (keyCode = KEY_CTRL_X) or (keyCode = KEY_F10) then
      game_quit_with_confirm
    else if (keyCode = 502) or (keyCode = KEY_ESCAPE) or (keyCode = KEY_UPPERCASE_C) or (keyCode = KEY_LOWERCASE_C) or (game_user_wants_to_quit <> 0) then
      rc := 1
    else if glblmode and ((keyCode = 517) or (keyCode = KEY_UPPERCASE_N) or (keyCode = KEY_LOWERCASE_N)) then
      NameWindow
    else if glblmode and ((keyCode = 519) or (keyCode = KEY_UPPERCASE_A) or (keyCode = KEY_LOWERCASE_A)) then
      AgeWindow
    else if glblmode and ((keyCode = 520) or (keyCode = KEY_UPPERCASE_S) or (keyCode = KEY_LOWERCASE_S)) then
      SexWindow
    else if glblmode and (keyCode >= 503) and (keyCode < 517) then
      StatButton(keyCode)
    else if (glblmode and ((keyCode = 501) or (keyCode = KEY_UPPERCASE_O) or (keyCode = KEY_LOWERCASE_O)))
         or ((not glblmode) and ((keyCode = 501) or (keyCode = KEY_UPPERCASE_P) or (keyCode = KEY_LOWERCASE_P))) then
      OptionWindow
    else if (keyCode >= 525) and (keyCode < 535) then
      InfoButton(keyCode)
    else if keyCode = 535 then
      FldrButton
    else if (keyCode = 521) or (keyCode = 523) or (keyCode = KEY_ARROW_RIGHT)
         or (keyCode = KEY_PLUS) or (keyCode = KEY_UPPERCASE_N)
         or (keyCode = KEY_ARROW_LEFT) or (keyCode = KEY_MINUS) or (keyCode = KEY_UPPERCASE_J) then
      SliderBtn(keyCode)
    else if glblmode and (keyCode >= 536) and (keyCode < 555) then
      TagSkillSelect(keyCode - 536)
    else if glblmode and (keyCode >= 555) and (keyCode < 571) then
      TraitSelect(keyCode - 555)
    else if keyCode = 390 then
      dump_screen;

    win_draw(edit_win);
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  if rc = 0 then
  begin
    if isCreationMode then
    begin
      proto_dude_update_gender;
      palette_fade_to(@black_palette[0]);
    end;
  end;

  CharEditEnd;

  if rc = 1 then
    RestorePlayer;

  if is_pc_flag(PC_FLAG_LEVEL_UP_AVAILABLE) then
    pc_flag_off(PC_FLAG_LEVEL_UP_AVAILABLE);

  intface_update_hit_points(False);
  Result := rc;
end;

function CharEditStart: Integer;
var
  i: Integer;
  path: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  fid: Integer;
  str: PAnsiChar;
  len: Integer;
  btn: Integer;
  x, y: Integer;
  perks_str: array[0..31] of AnsiChar;
  karma_str: array[0..31] of AnsiChar;
  kills_str: array[0..31] of AnsiChar;
  editorWindowX, editorWindowY: Integer;
  gsize: Integer;
begin
  fontsave := text_curr;
  old_tags := 0;
  karma_count := 0;
  bk_enable := False;
  old_fid2 := -1;
  old_fid1 := -1;
  frstc_draw2 := False;
  frstc_draw1 := False;
  first_skill_list := 1;
  old_str2[0] := #0;
  old_str1[0] := #0;

  text_font(101);
  slider_y := skill_cursor * (text_height() + 1) + 27;

  skill_get_tags(@temp_tag_skill[0], NUM_TAGGED_SKILLS);
  tagskill_count := tagskl_free;

  trait_get(@temp_trait[0], @temp_trait[1]);
  trait_count := get_trait_count;

  if not glblmode then
    bk_enable := map_disable_bk_processes;

  cycle_disable;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);

  if not message_init(@editor_message_file) then
  begin
    Result := -1;
    Exit;
  end;

  StrLFmt(@path[0], SizeOf(path) - 1, '%s%s', [msg_path, 'editor.msg']);

  if not message_load(@editor_message_file, @path[0]) then
  begin
    Result := -1;
    Exit;
  end;

  if glblmode then
    fid := art_id(OBJ_TYPE_INTERFACE, 169, 0, 0, 0)
  else
    fid := art_id(OBJ_TYPE_INTERFACE, 177, 0, 0, 0);

  bckgnd := art_lock(fid, @bck_key, @GInfo[0].Width, @GInfo[0].Height);
  if bckgnd = nil then
  begin
    message_exit(@editor_message_file);
    Result := -1;
    Exit;
  end;

  soundUpdate;

  i := 0;
  while i < EDITOR_GRAPHIC_COUNT do
  begin
    fid := art_id(OBJ_TYPE_INTERFACE, grph_id[i], 0, 0, 0);
    grphbmp[i] := art_lock(fid, @grph_key[i], @GInfo[i].Width, @GInfo[i].Height);
    if grphbmp[i] = nil then
      Break;
    Inc(i);
  end;

  if i <> EDITOR_GRAPHIC_COUNT then
  begin
    Dec(i);
    while i >= 0 do
    begin
      art_ptr_unlock(grph_key[i]);
      Dec(i);
    end;
    art_ptr_unlock(bck_key);
    message_exit(@editor_message_file);
    RstrBckgProc;
    Result := -1;
    Exit;
  end;

  soundUpdate;

  i := 0;
  while i < EDITOR_GRAPHIC_COUNT do
  begin
    if copyflag[i] <> 0 then
    begin
      gsize := GInfo[i].Width * GInfo[i].Height;
      grphcpy[i] := PByte(mem_malloc(gsize));
      if grphcpy[i] = nil then
        Break;
      Move(grphbmp[i]^, grphcpy[i]^, gsize);
    end
    else
      grphcpy[i] := PByte(PtrUInt(-1));
    Inc(i);
  end;

  if i <> EDITOR_GRAPHIC_COUNT then
  begin
    Dec(i);
    while i >= 0 do
    begin
      if copyflag[i] <> 0 then
        mem_free(grphcpy[i]);
      Dec(i);
    end;
    for i := 0 to EDITOR_GRAPHIC_COUNT - 1 do
      art_ptr_unlock(grph_key[i]);
    art_ptr_unlock(bck_key);
    message_exit(@editor_message_file);
    RstrBckgProc;
    Result := -1;
    Exit;
  end;

  editorWindowX := (screenGetWidth - EDITOR_WINDOW_WIDTH) div 2;
  editorWindowY := (screenGetHeight - EDITOR_WINDOW_HEIGHT) div 2;
  edit_win := win_add(editorWindowX, editorWindowY,
    EDITOR_WINDOW_WIDTH, EDITOR_WINDOW_HEIGHT,
    256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);

  if edit_win = -1 then
  begin
    for i := 0 to EDITOR_GRAPHIC_COUNT - 1 do
    begin
      if copyflag[i] <> 0 then
        mem_free(grphcpy[i]);
      art_ptr_unlock(grph_key[i]);
    end;
    art_ptr_unlock(bck_key);
    message_exit(@editor_message_file);
    RstrBckgProc;
    Result := -1;
    Exit;
  end;

  win_buf := win_get_buf(edit_win);
  Move(bckgnd^, win_buf^, 640 * 480);

  if glblmode then
  begin
    text_font(103);
    str := getmsg(@editor_message_file, @mesg, 116);
    text_to_buf(win_buf + (286 * 640) + 14, str, 640, 640, colorTable[18979]);
    PrintBigNum(126, 282, 0, character_points, 0, edit_win);

    str := getmsg(@editor_message_file, @mesg, 101);
    text_to_buf(win_buf + (454 * 640) + 363, str, 640, 640, colorTable[18979]);

    str := getmsg(@editor_message_file, @mesg, 139);
    text_to_buf(win_buf + (326 * 640) + 52, str, 640, 640, colorTable[18979]);
    PrintBigNum(522, 228, 0, optrt_count, 0, edit_win);

    str := getmsg(@editor_message_file, @mesg, 138);
    text_to_buf(win_buf + (233 * 640) + 422, str, 640, 640, colorTable[18979]);
    PrintBigNum(522, 228, 0, tagskill_count, 0, edit_win);
  end
  else
  begin
    text_font(103);

    str := getmsg(@editor_message_file, @mesg, 109);
    StrCopy(@perks_str[0], str);
    str := getmsg(@editor_message_file, @mesg, 110);
    StrCopy(@karma_str[0], str);
    str := getmsg(@editor_message_file, @mesg, 111);
    StrCopy(@kills_str[0], str);

    // perks selected
    len := text_width(@perks_str[0]);
    text_to_buf(grphcpy[46] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 61 - len div 2,
      @perks_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[18979]);

    len := text_width(@karma_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 159 - len div 2,
      @karma_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[14723]);

    len := text_width(@kills_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 257 - len div 2,
      @kills_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[14723]);

    // karma selected
    len := text_width(@perks_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KARMA_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 61 - len div 2,
      @perks_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[14723]);

    len := text_width(@karma_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KARMA_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 159 - len div 2,
      @karma_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[18979]);

    len := text_width(@kills_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KARMA_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 257 - len div 2,
      @kills_str[0], GInfo[46].Width, GInfo[46].Width, colorTable[14723]);

    // kills selected
    len := text_width(@perks_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KILLS_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 61 - len div 2,
      @perks_str[0], GInfo[46].Width, GInfo[46].Width, colorTable[14723]);

    len := text_width(@karma_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KILLS_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 159 - len div 2,
      @karma_str[0], GInfo[46].Width, GInfo[46].Width, colorTable[14723]);

    len := text_width(@kills_str[0]);
    text_to_buf(grphcpy[EDITOR_GRAPHIC_KILLS_FOLDER_SELECTED] + 5 * GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width + 257 - len div 2,
      @kills_str[0], GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
      GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width, colorTable[18979]);

    DrawFolder;

    text_font(103);
    str := getmsg(@editor_message_file, @mesg, 103);
    text_to_buf(win_buf + (EDITOR_WINDOW_WIDTH * PRINT_BTN_Y) + PRINT_BTN_X, str, EDITOR_WINDOW_WIDTH, EDITOR_WINDOW_WIDTH, colorTable[18979]);
    PrintLevelWin;
  end;

  text_font(103);

  str := getmsg(@editor_message_file, @mesg, 102);
  text_to_buf(win_buf + (EDITOR_WINDOW_WIDTH * CANCEL_BTN_Y) + CANCEL_BTN_X, str, EDITOR_WINDOW_WIDTH, EDITOR_WINDOW_WIDTH, colorTable[18979]);

  str := getmsg(@editor_message_file, @mesg, 100);
  text_to_buf(win_buf + (EDITOR_WINDOW_WIDTH * DONE_BTN_Y) + DONE_BTN_X, str, EDITOR_WINDOW_WIDTH, EDITOR_WINDOW_WIDTH, colorTable[18979]);

  PrintBasicStat(RENDER_ALL_STATS, False, 0);
  ListDrvdStats;

  if not glblmode then
  begin
    SliderPlusID := win_register_button(edit_win, 614, 20,
      GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Width,
      GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Height,
      -1, 522, 521, 522,
      grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_OFF],
      grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_ON],
      nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x40);
    SliderNegID := win_register_button(edit_win, 614,
      20 + GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Height - 1,
      GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Width,
      GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_OFF].Height,
      -1, 524, 523, 524,
      grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_OFF],
      grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_ON],
      nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x40);
    win_register_button_sound_func(SliderPlusID, @gsound_red_butt_press, nil);
    win_register_button_sound_func(SliderNegID, @gsound_red_butt_press, nil);
  end;

  ListSkills(0);
  DrawInfoWin;
  soundUpdate;
  PrintBigname;
  PrintAgeBig;
  PrintGender;

  if glblmode then
  begin
    x := NAME_BUTTON_X;
    btn := win_register_button(edit_win, x, NAME_BUTTON_Y,
      GInfo[EDITOR_GRAPHIC_NAME_ON].Width,
      GInfo[EDITOR_GRAPHIC_NAME_ON].Height,
      -1, -1, -1, NAME_BTN_CODE,
      grphcpy[EDITOR_GRAPHIC_NAME_OFF],
      grphcpy[EDITOR_GRAPHIC_NAME_ON],
      nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
    begin
      win_register_button_mask(btn, grphbmp[EDITOR_GRAPHIC_NAME_MASK]);
      win_register_button_sound_func(btn, @gsound_lrg_butt_press, nil);
    end;

    x := x + GInfo[EDITOR_GRAPHIC_NAME_ON].Width;
    btn := win_register_button(edit_win, x, NAME_BUTTON_Y,
      GInfo[EDITOR_GRAPHIC_AGE_ON].Width,
      GInfo[EDITOR_GRAPHIC_AGE_ON].Height,
      -1, -1, -1, AGE_BTN_CODE,
      grphcpy[EDITOR_GRAPHIC_AGE_OFF],
      grphcpy[EDITOR_GRAPHIC_AGE_ON],
      nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
    begin
      win_register_button_mask(btn, grphbmp[EDITOR_GRAPHIC_AGE_MASK]);
      win_register_button_sound_func(btn, @gsound_lrg_butt_press, nil);
    end;

    x := x + GInfo[EDITOR_GRAPHIC_AGE_ON].Width;
    btn := win_register_button(edit_win, x, NAME_BUTTON_Y,
      GInfo[EDITOR_GRAPHIC_SEX_ON].Width,
      GInfo[EDITOR_GRAPHIC_SEX_ON].Height,
      -1, -1, -1, SEX_BTN_CODE,
      grphcpy[EDITOR_GRAPHIC_SEX_OFF],
      grphcpy[EDITOR_GRAPHIC_SEX_ON],
      nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
    begin
      win_register_button_mask(btn, grphbmp[EDITOR_GRAPHIC_SEX_MASK]);
      win_register_button_sound_func(btn, @gsound_lrg_butt_press, nil);
    end;

    y := TAG_SKILLS_BUTTON_Y;
    for i := 0 to SKILL_COUNT - 1 do
    begin
      btn := win_register_button(edit_win, TAG_SKILLS_BUTTON_X, y,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Width,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height,
        -1, -1, -1, TAG_SKILLS_BUTTON_CODE + i,
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_OFF],
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, nil);
      y := y + GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height;
    end;

    // Register trait buttons (using u_trait.TRAIT_COUNT explicitly due to name resolution issue)
    y := OPTIONAL_TRAITS_BTN_Y;
    for i := 0 to (u_trait.TRAIT_COUNT div 2) - 1 do
    begin
      btn := win_register_button(edit_win, OPTIONAL_TRAITS_LEFT_BTN_X, y,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Width,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height,
        -1, -1, -1, OPTIONAL_TRAITS_BTN_CODE + i,
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_OFF],
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, nil);
      y := y + GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height + OPTIONAL_TRAITS_BTN_SPACE;
    end;

    y := OPTIONAL_TRAITS_BTN_Y;
    for i := u_trait.TRAIT_COUNT div 2 to u_trait.TRAIT_COUNT - 1 do
    begin
      btn := win_register_button(edit_win, OPTIONAL_TRAITS_RIGHT_BTN_X, y,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Width,
        GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height,
        -1, -1, -1, OPTIONAL_TRAITS_BTN_CODE + i,
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_OFF],
        grphbmp[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, nil);
      y := y + GInfo[EDITOR_GRAPHIC_TAG_SKILL_BUTTON_ON].Height + OPTIONAL_TRAITS_BTN_SPACE;
    end;

    ListTraits;
  end
  else
  begin
    x := NAME_BUTTON_X;
    trans_buf_to_buf(grphcpy[EDITOR_GRAPHIC_NAME_OFF],
      GInfo[EDITOR_GRAPHIC_NAME_ON].Width,
      GInfo[EDITOR_GRAPHIC_NAME_ON].Height,
      GInfo[EDITOR_GRAPHIC_NAME_ON].Width,
      win_buf + (EDITOR_WINDOW_WIDTH * NAME_BUTTON_Y) + x,
      EDITOR_WINDOW_WIDTH);

    x := x + GInfo[EDITOR_GRAPHIC_NAME_ON].Width;
    trans_buf_to_buf(grphcpy[EDITOR_GRAPHIC_AGE_OFF],
      GInfo[EDITOR_GRAPHIC_AGE_ON].Width,
      GInfo[EDITOR_GRAPHIC_AGE_ON].Height,
      GInfo[EDITOR_GRAPHIC_AGE_ON].Width,
      win_buf + (EDITOR_WINDOW_WIDTH * NAME_BUTTON_Y) + x,
      EDITOR_WINDOW_WIDTH);

    x := x + GInfo[EDITOR_GRAPHIC_AGE_ON].Width;
    trans_buf_to_buf(grphcpy[EDITOR_GRAPHIC_SEX_OFF],
      GInfo[EDITOR_GRAPHIC_SEX_ON].Width,
      GInfo[EDITOR_GRAPHIC_SEX_ON].Height,
      GInfo[EDITOR_GRAPHIC_SEX_ON].Width,
      win_buf + (EDITOR_WINDOW_WIDTH * NAME_BUTTON_Y) + x,
      EDITOR_WINDOW_WIDTH);

    btn := win_register_button(edit_win, 11, 327,
      GInfo[EDITOR_GRAPHIC_FOLDER_MASK].Width,
      GInfo[EDITOR_GRAPHIC_FOLDER_MASK].Height,
      -1, -1, -1, 535, nil, nil, nil, BUTTON_FLAG_TRANSPARENT);
    if btn <> -1 then
      win_register_button_mask(btn, grphbmp[EDITOR_GRAPHIC_FOLDER_MASK]);
  end;

  if glblmode then
  begin
    for i := 0 to 6 do
    begin
      btn := win_register_button(edit_win, SPECIAL_STATS_BTN_X, StatYpos[i],
        GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Width,
        GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Height,
        -1, 518, 503 + i, 518,
        grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_OFF],
        grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_ON],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, nil);

      btn := win_register_button(edit_win, SPECIAL_STATS_BTN_X,
        StatYpos[i] + GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Height - 1,
        GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Width,
        GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Height,
        -1, 518, 510 + i, 518,
        grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_OFF],
        grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_ON],
        nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_red_butt_press, nil);
    end;
  end;

  RegInfoAreas;
  soundUpdate;

  btn := win_register_button(edit_win, 343, 454,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 501,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(edit_win, 552, 454,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 502,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(edit_win, 455, 454,
    GInfo[23].Width, GInfo[23].Height,
    -1, -1, -1, 500,
    grphbmp[23], grphbmp[24],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_draw(edit_win);
  disable_box_bar_win;

  Result := 0;
end;

procedure CharEditEnd;
var
  index: Integer;
begin
  win_delete(edit_win);

  for index := 0 to EDITOR_GRAPHIC_COUNT - 1 do
  begin
    art_ptr_unlock(grph_key[index]);
    if copyflag[index] <> 0 then
      mem_free(grphcpy[index]);
  end;

  art_ptr_unlock(bck_key);
  message_exit(@editor_message_file);
  intface_redraw;
  RstrBckgProc;
  text_font(fontsave);

  if glblmode then
  begin
    skill_set_tags(@temp_tag_skill[0], 3);
    trait_set(temp_trait[0], temp_trait[1]);
    info_line := 0;
    critter_adjust_hits(obj_dude, 1000);
  end;

  enable_box_bar_win;
end;

procedure RstrBckgProc;
begin
  if bk_enable then
    map_enable_bk_processes;
  cycle_enable;
  gmouse_set_cursor(MOUSE_CURSOR_ARROW);
end;

procedure CharEditInit;
var
  i: Integer;
begin
  info_line := 0;
  skill_cursor := 0;
  slider_y := 27;
  free_perk := 0;
  folder := EDITOR_FOLDER_PERKS;

  for i := 0 to 1 do
  begin
    temp_trait[i] := -1;
    trait_back[i] := -1;
  end;

  character_points := 5;
  last_level := 1;
end;

function get_input_str(win, cancelKeyCode: Integer; text: PAnsiChar;
  maxLength, x, y, textColor, backgroundColor, flags: Integer): Integer;
var
  cursorWidth, windowWidth, v60: Integer;
  windowBuffer: PByte;
  copy_: array[0..256] of AnsiChar;
  nameLength: Integer;
  nameWidth: Integer;
  blinkingCounter: Integer;
  blink: Boolean;
  rc: Integer;
  keyCode: Integer;
  clr: Integer;
begin
  cursorWidth := text_width(PAnsiChar('_')) - 4;
  windowWidth := win_width(win);
  v60 := text_height();
  windowBuffer := win_get_buf(win);
  if maxLength > 255 then
    maxLength := 255;

  StrCopy(@copy_[0], text);
  nameLength := StrLen(text);
  copy_[nameLength] := ' ';
  copy_[nameLength + 1] := #0;

  nameWidth := text_width(@copy_[0]);
  buf_fill(windowBuffer + windowWidth * y + x, nameWidth, text_height(), windowWidth, backgroundColor);
  text_to_buf(windowBuffer + windowWidth * y + x, @copy_[0], windowWidth, windowWidth, textColor);
  win_draw(win);

  beginTextInput;

  blinkingCounter := 3;
  blink := False;

  rc := 1;
  while rc = 1 do
  begin
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    keyCode := get_input;

    if keyCode = cancelKeyCode then
      rc := 0
    else if keyCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      rc := 0;
    end
    else if (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
      rc := -1
    else
    begin
      if ((keyCode = KEY_DELETE) or (keyCode = KEY_BACKSPACE)) and (nameLength >= 1) then
      begin
        buf_fill(windowBuffer + windowWidth * y + x, text_width(@copy_[0]), v60, windowWidth, backgroundColor);
        copy_[nameLength - 1] := ' ';
        copy_[nameLength] := #0;
        text_to_buf(windowBuffer + windowWidth * y + x, @copy_[0], windowWidth, windowWidth, textColor);
        Dec(nameLength);
        win_draw(win);
      end
      else if (keyCode >= KEY_FIRST_INPUT_CHARACTER) and (keyCode <= KEY_LAST_INPUT_CHARACTER) and (nameLength < maxLength) then
      begin
        if (flags and $01) <> 0 then
        begin
          if not isdoschar(keyCode) then
          begin
            // skip this character
            Dec(blinkingCounter);
            if blinkingCounter = 0 then
            begin
              blinkingCounter := 3;
              if blink then clr := backgroundColor else clr := textColor;
              blink := not blink;
              buf_fill(windowBuffer + windowWidth * y + x + text_width(@copy_[0]) - cursorWidth, cursorWidth, v60 - 2, windowWidth, clr);
            end;
            win_draw(win);
            while elapsed_time(frame_time) < (1000 div 24) do ;
            renderPresent;
            sharedFpsLimiter.Throttle;
            Continue;
          end;
        end;

        buf_fill(windowBuffer + windowWidth * y + x, text_width(@copy_[0]), v60, windowWidth, backgroundColor);
        copy_[nameLength] := AnsiChar(keyCode and $FF);
        copy_[nameLength + 1] := ' ';
        copy_[nameLength + 2] := #0;
        text_to_buf(windowBuffer + windowWidth * y + x, @copy_[0], windowWidth, windowWidth, textColor);
        Inc(nameLength);
        win_draw(win);
      end;
    end;

    Dec(blinkingCounter);
    if blinkingCounter = 0 then
    begin
      blinkingCounter := 3;
      if blink then clr := backgroundColor else clr := textColor;
      blink := not blink;
      buf_fill(windowBuffer + windowWidth * y + x + text_width(@copy_[0]) - cursorWidth, cursorWidth, v60 - 2, windowWidth, clr);
    end;

    win_draw(win);
    while elapsed_time(frame_time) < (1000 div 24) do ;
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  endTextInput;

  if (rc = 0) or (nameLength > 0) then
  begin
    copy_[nameLength] := #0;
    StrCopy(text, @copy_[0]);
  end;

  Result := rc;
end;

function isdoschar(ch: Integer): Boolean;
var
  punctuations: PAnsiChar;
  length_: Integer;
  index: Integer;
begin
  punctuations := '#@!$`''~^&()-_=[]{}';

  if isalnum_c(ch) then
  begin
    Result := True;
    Exit;
  end;

  length_ := StrLen(punctuations);
  for index := 0 to length_ - 1 do
  begin
    if Ord(punctuations[index]) = ch then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function strmfe(dest: PAnsiChar; const name_: PAnsiChar; const ext: PAnsiChar): PAnsiChar;
var
  save: PAnsiChar;
  p: PAnsiChar;
begin
  save := dest;
  p := PAnsiChar(name_);

  while (p^ <> #0) and (p^ <> '.') do
  begin
    dest^ := p^;
    Inc(dest);
    Inc(p);
  end;

  dest^ := '.';
  Inc(dest);

  StrCopy(dest, ext);

  Result := save;
end;

procedure DrawFolder;
var
  perkName: array[0..79] of AnsiChar;
  perk: Integer;
  perkLevel: Integer;
  selected_perk_line: Integer;
  count: Integer;
  color: Integer;
  y: Integer;
  v2, v3, v4: Integer;
begin
  if glblmode then
    Exit;

  buf_to_buf(bckgnd + (360 * 640) + 34, 280, 120, 640, win_buf + (360 * 640) + 34, 640);
  text_font(101);

  case folder of
    EDITOR_FOLDER_PERKS:
    begin
      buf_to_buf(grphcpy[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED],
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Height,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        win_buf + (327 * 640) + 11, 640);

      selected_perk_line := -1;
      if (info_line >= 10) and (info_line < 43) then
        selected_perk_line := info_line - 10;

      count := 0;
      y := 364;
      perk := 0;
      while perk < PERK_COUNT do
      begin
        perkLevel := perk_level(perk);
        if perkLevel <> 0 then
        begin
          Inc(count);
          if count > 7 then Break;

          if perkLevel > 1 then
            StrLFmt(@perkName[0], SizeOf(perkName) - 1, '%s (%d)', [perk_name(perk), perkLevel])
          else
            StrCopy(@perkName[0], perk_name(perk));

          if count - 1 = selected_perk_line then
            color := colorTable[32747]
          else
            color := colorTable[992];

          text_to_buf(win_buf + 640 * y + 34, @perkName[0], 640, 640, color);
          y := y + 1 + text_height();
        end;
        Inc(perk);
      end;

      if count > 7 then
        debug_printf(#10' ** To many perks! %d total **'#10, [count]);

      y := 362 + 7 * (text_height() + 1);
      v2 := text_width(getmsg(@editor_message_file, @mesg, 156));
      v3 := (280 - v2) div 2 + 34;
      v4 := (246 - v2) div 2;

      text_to_buf(win_buf + 640 * y + v3 - 3,
        getmsg(@editor_message_file, @mesg, 156), 640, 640, colorTable[992]);

      win_line(edit_win, 34, y + text_height() div 2, v4 + 34, y + text_height() div 2, colorTable[992]);
      win_line(edit_win, v3 + v2 + 34 - 23, y + text_height() div 2, v3 + v2 + 34 + v4 - 23, y + text_height() div 2, colorTable[992]);

      y := y + 1 + text_height();
      if temp_trait[0] <> -1 then
      begin
        if selected_perk_line = 8 then color := colorTable[32747]
        else color := colorTable[992];
        text_to_buf(win_buf + 640 * y + 34, trait_name(temp_trait[0]), 640, 640, color);
        y := y + 1 + text_height();
      end;

      if temp_trait[1] <> -1 then
      begin
        if selected_perk_line = 9 then color := colorTable[32747]
        else color := colorTable[992];
        text_to_buf(win_buf + 640 * y + 34, trait_name(temp_trait[1]), 640, 640, color);
      end;
    end;
    EDITOR_FOLDER_KARMA:
    begin
      buf_to_buf(grphcpy[EDITOR_GRAPHIC_KARMA_FOLDER_SELECTED],
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Height,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        win_buf + (327 * 640) + 11, 640);
      karma_count := ListKarma;
    end;
    EDITOR_FOLDER_KILLS:
    begin
      buf_to_buf(grphcpy[EDITOR_GRAPHIC_KILLS_FOLDER_SELECTED],
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Height,
        GInfo[EDITOR_GRAPHIC_PERKS_FOLDER_SELECTED].Width,
        win_buf + (327 * 640) + 11, 640);
      kills_count := ListKills;
    end
  else
    debug_printf(PAnsiChar(#10' ** Unknown folder type! **'#10));
  end;
end;

function ListKills: Integer;
var
  selected_kill_line: Integer;
  index, count, color, y: Integer;
  temp: array[0..15] of AnsiChar;
begin
  selected_kill_line := -1;
  text_font(101);

  if (info_line >= 10) and (info_line < 43) then
    selected_kill_line := info_line - 10;

  count := 0;
  for index := 0 to KILL_TYPE_COUNT - 1 do
  begin
    if critter_kill_count(index) <> 0 then
    begin
      name_sort_list[count].name := critter_kill_name(index);
      name_sort_list[count].value := index;
      Inc(count);
    end;
  end;

  if count > 1 then
    qsort(@name_sort_list[0], count, SizeOf(TEditorSortableEntry), @name_sort_comp);

  y := 362;
  index := 0;
  while (index < count) and (index < 10) do
  begin
    if index = selected_kill_line then color := colorTable[32747]
    else color := colorTable[992];

    text_to_buf(win_buf + 640 * y + 34, name_sort_list[index].name, 640, 640, color);
    text_to_buf(win_buf + 640 * y + 136, compat_itoa(critter_kill_count(name_sort_list[index].value), @temp[0], 10), 640, 640, color);
    y := y + 1 + text_height();
    Inc(index);
  end;

  if count - 10 > 0 then
  begin
    y := 362;
    for index := 0 to count - 10 - 1 do
    begin
      if index + 10 = selected_kill_line then color := colorTable[32747]
      else color := colorTable[992];

      text_to_buf(win_buf + 640 * y + 191, name_sort_list[index + 10].name, 640, 640, color);
      text_to_buf(win_buf + 640 * y + 293, compat_itoa(critter_kill_count(name_sort_list[index + 10].value), @temp[0], 10), 640, 640, color);
      y := y + 1 + text_height();
    end;
  end;

  Result := count;
end;

procedure PrintBigNum(x, y, flags, value, previousValue, windowHandle: Integer);
var
  rect: TRect;
  windowWidth: Integer;
  windowBuf: PByte;
  tens, ones: Integer;
  tensBufferPtr, onesBufferPtr, numbersGraphicBufferPtr: PByte;
begin
  windowWidth := win_width(windowHandle);
  windowBuf := win_get_buf(windowHandle);

  rect.ulx := x;
  rect.uly := y;
  rect.lrx := x + BIG_NUM_WIDTH * 2;
  rect.lry := y + BIG_NUM_HEIGHT;

  numbersGraphicBufferPtr := grphbmp[0];

  if (flags and RED_NUMBERS) <> 0 then
    numbersGraphicBufferPtr := numbersGraphicBufferPtr + (GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width div 2);

  tensBufferPtr := windowBuf + windowWidth * y + x;
  onesBufferPtr := tensBufferPtr + BIG_NUM_WIDTH;

  if (value >= 0) and (value <= 99) and (previousValue >= 0) and (previousValue <= 99) then
  begin
    tens := value div 10;
    ones := value mod 10;

    if (flags and FLAG_ANIMATE) <> 0 then
    begin
      if (previousValue mod 10) <> ones then
      begin
        frame_time := get_time;
        buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * 11,
          BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
          GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
          onesBufferPtr, windowWidth);
        win_draw_rect(windowHandle, @rect);
        renderPresent;
        while elapsed_time(frame_time) < BIG_NUM_ANIMATION_DELAY do ;
      end;

      buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * ones,
        BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
        GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
        onesBufferPtr, windowWidth);
      win_draw_rect(windowHandle, @rect);
      renderPresent;

      if (previousValue div 10) <> tens then
      begin
        frame_time := get_time;
        buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * 11,
          BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
          GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
          tensBufferPtr, windowWidth);
        win_draw_rect(windowHandle, @rect);
        while elapsed_time(frame_time) < BIG_NUM_ANIMATION_DELAY do ;
      end;

      buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * tens,
        BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
        GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
        tensBufferPtr, windowWidth);
      win_draw_rect(windowHandle, @rect);
      renderPresent;
    end
    else
    begin
      buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * tens,
        BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
        GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
        tensBufferPtr, windowWidth);
      buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * ones,
        BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
        GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
        onesBufferPtr, windowWidth);
    end;
  end
  else
  begin
    buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * 9,
      BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
      GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
      tensBufferPtr, windowWidth);
    buf_to_buf(numbersGraphicBufferPtr + BIG_NUM_WIDTH * 9,
      BIG_NUM_WIDTH, BIG_NUM_HEIGHT,
      GInfo[EDITOR_GRAPHIC_BIG_NUMBERS].Width,
      onesBufferPtr, windowWidth);
  end;
end;

procedure PrintLevelWin;
var
  color, y: Integer;
  formattedValueBuffer: array[0..7] of AnsiChar;
  stringBuffer: array[0..127] of AnsiChar;
  level, exp_, expToNextLevel: Integer;
begin
  if glblmode then Exit;
  text_font(101);

  buf_to_buf(bckgnd + 640 * 280 + 32, 124, 32, 640, win_buf + 640 * 280 + 32, 640);

  y := 280;
  if info_line <> 7 then color := colorTable[992]
  else color := colorTable[32747];

  level := stat_pc_get(PC_STAT_LEVEL);
  StrLFmt(@stringBuffer[0], SizeOf(stringBuffer) - 1, '%s %d',
    [getmsg(@editor_message_file, @mesg, 113), level]);
  text_to_buf(win_buf + 640 * y + 32, @stringBuffer[0], 640, 640, color);

  y := y + text_height() + 1;
  if info_line <> 8 then color := colorTable[992]
  else color := colorTable[32747];

  exp_ := stat_pc_get(PC_STAT_EXPERIENCE);
  StrLFmt(@stringBuffer[0], SizeOf(stringBuffer) - 1, '%s %s',
    [getmsg(@editor_message_file, @mesg, 114), itostndn(exp_, @formattedValueBuffer[0])]);
  text_to_buf(win_buf + 640 * y + 32, @stringBuffer[0], 640, 640, color);

  y := y + text_height() + 1;
  if info_line <> 9 then color := colorTable[992]
  else color := colorTable[32747];

  expToNextLevel := stat_pc_min_exp;
  if expToNextLevel = -1 then
    StrLFmt(@stringBuffer[0], SizeOf(stringBuffer) - 1, '%s %s',
      [getmsg(@editor_message_file, @mesg, 115), '------'])
  else
    StrLFmt(@stringBuffer[0], SizeOf(stringBuffer) - 1, '%s %s',
      [getmsg(@editor_message_file, @mesg, 115), itostndn(expToNextLevel, @formattedValueBuffer[0])]);

  text_to_buf(win_buf + 640 * y + 32, @stringBuffer[0], 640, 640, color);
end;

procedure PrintBasicStat(stat: Integer; animate: Boolean; previousValue: Integer);
var
  off, color, value, flgs, messageListItemId: Integer;
  description: PAnsiChar;
  st: Integer;
begin
  text_font(101);

  if stat = RENDER_ALL_STATS then
  begin
    for st := 0 to 6 do
      PrintBasicStat(st, False, 0);
    Exit;
  end;

  if info_line = stat then color := colorTable[32747]
  else color := colorTable[992];

  off := 640 * (StatYpos[stat] + 8) + 103;

  if glblmode then
  begin
    value := stat_get_base(obj_dude, stat) + stat_get_bonus(obj_dude, stat);
    flgs := 0;
    if animate then flgs := flgs or FLAG_ANIMATE;
    if value > 10 then flgs := flgs or RED_NUMBERS;

    PrintBigNum(58, StatYpos[stat], flgs, value, previousValue, edit_win);
    buf_to_buf(bckgnd + off, 40, text_height(), 640, win_buf + off, 640);

    messageListItemId := stat_level(obj_dude, stat) + 199;
    if messageListItemId > 210 then messageListItemId := 210;

    description := getmsg(@editor_message_file, @mesg, messageListItemId);
    text_to_buf(win_buf + 640 * (StatYpos[stat] + 8) + 103, description, 640, 640, color);
  end
  else
  begin
    value := stat_level(obj_dude, stat);
    PrintBigNum(58, StatYpos[stat], 0, value, 0, edit_win);
    buf_to_buf(bckgnd + off, 40, text_height(), 640, win_buf + off, 640);

    value := stat_level(obj_dude, stat);
    if value > 10 then value := 10;

    description := stat_level_description(value);
    text_to_buf(win_buf + off, description, 640, 640, color);
  end;
end;

procedure PrintGender;
var
  gender: Integer;
  str: PAnsiChar;
  text_: array[0..31] of AnsiChar;
  x, width_: Integer;
begin
  text_font(103);
  gender := stat_level(obj_dude, STAT_GENDER);
  str := getmsg(@editor_message_file, @mesg, 107 + gender);
  StrCopy(@text_[0], str);

  width_ := GInfo[EDITOR_GRAPHIC_SEX_ON].Width;
  x := (width_ div 2) - (text_width(@text_[0]) div 2);

  Move(grphbmp[EDITOR_GRAPHIC_SEX_ON]^, grphcpy[11]^, width_ * GInfo[EDITOR_GRAPHIC_SEX_ON].Height);
  Move(grphbmp[10]^, grphcpy[EDITOR_GRAPHIC_SEX_OFF]^, width_ * GInfo[EDITOR_GRAPHIC_SEX_OFF].Height);

  x := x + 6 * width_;
  text_to_buf(grphcpy[EDITOR_GRAPHIC_SEX_ON] + x, @text_[0], width_, width_, colorTable[14723]);
  text_to_buf(grphcpy[EDITOR_GRAPHIC_SEX_OFF] + x, @text_[0], width_, width_, colorTable[18979]);
end;

procedure PrintAgeBig;
var
  age: Integer;
  str: PAnsiChar;
  text_: array[0..31] of AnsiChar;
  x, width_: Integer;
begin
  text_font(103);
  age := stat_level(obj_dude, STAT_AGE);
  str := getmsg(@editor_message_file, @mesg, 104);
  StrLFmt(@text_[0], SizeOf(text_) - 1, '%s %d', [str, age]);

  width_ := GInfo[EDITOR_GRAPHIC_AGE_ON].Width;
  x := (width_ div 2) + 1 - (text_width(@text_[0]) div 2);

  Move(grphbmp[EDITOR_GRAPHIC_AGE_ON]^, grphcpy[EDITOR_GRAPHIC_AGE_ON]^, width_ * GInfo[EDITOR_GRAPHIC_AGE_ON].Height);
  Move(grphbmp[EDITOR_GRAPHIC_AGE_OFF]^, grphcpy[EDITOR_GRAPHIC_AGE_OFF]^, width_ * GInfo[EDITOR_GRAPHIC_AGE_ON].Height);

  x := x + 6 * width_;
  text_to_buf(grphcpy[EDITOR_GRAPHIC_AGE_ON] + x, @text_[0], width_, width_, colorTable[14723]);
  text_to_buf(grphcpy[EDITOR_GRAPHIC_AGE_OFF] + x, @text_[0], width_, width_, colorTable[18979]);
end;

procedure PrintBigname;
var
  str: PAnsiChar;
  text_: array[0..31] of AnsiChar;
  x, width_: Integer;
  pch: PAnsiChar;
  tmp: AnsiChar;
  has_space: Boolean;
begin
  text_font(103);
  str := critter_name(obj_dude);
  StrCopy(@text_[0], str);

  if text_width(@text_[0]) > 100 then
  begin
    pch := @text_[0];
    has_space := False;
    while pch^ <> #0 do
    begin
      tmp := pch^;
      pch^ := #0;
      if tmp = ' ' then has_space := True;
      if text_width(@text_[0]) > 100 then Break;
      pch^ := tmp;
      Inc(pch);
    end;

    if has_space then
    begin
      pch := @text_[0] + StrLen(@text_[0]);
      while (pch <> @text_[0]) and (pch^ <> ' ') do
      begin
        pch^ := #0;
        Dec(pch);
      end;
    end;
  end;

  width_ := GInfo[EDITOR_GRAPHIC_NAME_ON].Width;
  x := (width_ div 2) + 3 - (text_width(@text_[0]) div 2);

  Move(grphbmp[EDITOR_GRAPHIC_NAME_ON]^, grphcpy[EDITOR_GRAPHIC_NAME_ON]^, GInfo[EDITOR_GRAPHIC_NAME_ON].Width * GInfo[EDITOR_GRAPHIC_NAME_ON].Height);
  Move(grphbmp[EDITOR_GRAPHIC_NAME_OFF]^, grphcpy[EDITOR_GRAPHIC_NAME_OFF]^, GInfo[EDITOR_GRAPHIC_NAME_OFF].Width * GInfo[EDITOR_GRAPHIC_NAME_OFF].Height);

  x := x + 6 * width_;
  text_to_buf(grphcpy[EDITOR_GRAPHIC_NAME_ON] + x, @text_[0], width_, width_, colorTable[14723]);
  text_to_buf(grphcpy[EDITOR_GRAPHIC_NAME_OFF] + x, @text_[0], width_, width_, colorTable[18979]);
end;

procedure ListDrvdStats;
var
  conditions, color, y: Integer;
  messageListItemText: PAnsiChar;
  t: array[0..419] of AnsiChar;
  currHp, maxHp: Integer;
begin
  conditions := obj_dude^.Data.AsData.Critter.Combat.Results;
  text_font(101);

  y := 46;
  buf_to_buf(bckgnd + 640 * y + 194, 118, 108, 640, win_buf + 640 * y + 194, 640);

  // Hit Points
  if info_line = EDITOR_HIT_POINTS then color := colorTable[32747]
  else color := colorTable[992];

  if glblmode then
  begin
    maxHp := stat_level(obj_dude, STAT_MAXIMUM_HIT_POINTS);
    currHp := maxHp;
  end
  else
  begin
    maxHp := stat_level(obj_dude, STAT_MAXIMUM_HIT_POINTS);
    currHp := critter_get_hits(obj_dude);
  end;

  messageListItemText := getmsg(@editor_message_file, @mesg, 300);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s %d/%d', [messageListItemText, currHp, maxHp]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Poisoned
  y := y + text_height() + 3;
  if info_line = EDITOR_POISONED then
  begin
    if critter_get_poison(obj_dude) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if critter_get_poison(obj_dude) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 312);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Radiated
  y := y + text_height() + 3;
  if info_line = EDITOR_RADIATED then
  begin
    if critter_get_rads(obj_dude) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if critter_get_rads(obj_dude) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 313);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Eye Damage
  y := y + text_height() + 3;
  if info_line = EDITOR_EYE_DAMAGE then
  begin
    if (conditions and DAM_BLIND) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if (conditions and DAM_BLIND) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 314);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Crippled Right Arm
  y := y + text_height() + 3;
  if info_line = EDITOR_CRIPPLED_RIGHT_ARM then
  begin
    if (conditions and DAM_CRIP_ARM_RIGHT) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if (conditions and DAM_CRIP_ARM_RIGHT) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 315);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Crippled Left Arm
  y := y + text_height() + 3;
  if info_line = EDITOR_CRIPPLED_LEFT_ARM then
  begin
    if (conditions and DAM_CRIP_ARM_LEFT) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if (conditions and DAM_CRIP_ARM_LEFT) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 316);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Crippled Right Leg
  y := y + text_height() + 3;
  if info_line = EDITOR_CRIPPLED_RIGHT_LEG then
  begin
    if (conditions and DAM_CRIP_LEG_RIGHT) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if (conditions and DAM_CRIP_LEG_RIGHT) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 317);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Crippled Left Leg
  y := y + text_height() + 3;
  if info_line = EDITOR_CRIPPLED_LEFT_LEG then
  begin
    if (conditions and DAM_CRIP_LEG_LEFT) <> 0 then color := colorTable[32747]
    else color := colorTable[15845];
  end
  else
  begin
    if (conditions and DAM_CRIP_LEG_LEFT) <> 0 then color := colorTable[992]
    else color := colorTable[1313];
  end;
  messageListItemText := getmsg(@editor_message_file, @mesg, 318);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);

  // Derived stats
  y := 179;
  buf_to_buf(bckgnd + 640 * y + 194, 116, 130, 640, win_buf + 640 * y + 194, 640);

  // Armor Class
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_ARMOR_CLASS then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 302);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_ARMOR_CLASS), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Action Points
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_ACTION_POINTS then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 301);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_MAXIMUM_ACTION_POINTS), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Carry Weight
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_CARRY_WEIGHT then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 311);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_CARRY_WEIGHT), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Melee Damage
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_MELEE_DAMAGE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 304);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_MELEE_DAMAGE), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Damage Resistance
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_DAMAGE_RESISTANCE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 305);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  StrLFmt(@t[0], SizeOf(t) - 1, '%d%%', [stat_level(obj_dude, STAT_DAMAGE_RESISTANCE)]);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Poison Resistance
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_POISON_RESISTANCE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 306);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  StrLFmt(@t[0], SizeOf(t) - 1, '%d%%', [stat_level(obj_dude, STAT_POISON_RESISTANCE)]);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Radiation Resistance
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_RADIATION_RESISTANCE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 307);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  StrLFmt(@t[0], SizeOf(t) - 1, '%d%%', [stat_level(obj_dude, STAT_RADIATION_RESISTANCE)]);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Sequence
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_SEQUENCE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 308);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_SEQUENCE), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Healing Rate
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_HEALING_RATE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 309);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  compat_itoa(stat_level(obj_dude, STAT_HEALING_RATE), @t[0], 10);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);

  // Critical Chance
  y := y + text_height() + 3;
  if info_line = EDITOR_FIRST_DERIVED_STAT + EDITOR_DERIVED_STAT_CRITICAL_CHANCE then
    color := colorTable[32747]
  else color := colorTable[992];
  messageListItemText := getmsg(@editor_message_file, @mesg, 310);
  StrLFmt(@t[0], SizeOf(t) - 1, '%s', [messageListItemText]);
  text_to_buf(win_buf + 640 * y + 194, @t[0], 640, 640, color);
  StrLFmt(@t[0], SizeOf(t) - 1, '%d%%', [stat_level(obj_dude, STAT_CRITICAL_CHANCE)]);
  text_to_buf(win_buf + 640 * y + 288, @t[0], 640, 640, color);
end;

procedure ListSkills(a1: Integer);
var
  selectedSkill: Integer;
  str: PAnsiChar;
  i, color, y, value: Integer;
  valueString: array[0..31] of AnsiChar;
begin
  selectedSkill := -1;
  if (info_line >= EDITOR_FIRST_SKILL) and (info_line < 79) then
    selectedSkill := info_line - EDITOR_FIRST_SKILL;

  if (not glblmode) and (a1 = 0) then
  begin
    win_delete_button(SliderPlusID);
    win_delete_button(SliderNegID);
    SliderNegID := -1;
    SliderPlusID := -1;
  end;

  buf_to_buf(bckgnd + 370, 270, 252, 640, win_buf + 370, 640);
  text_font(103);

  str := getmsg(@editor_message_file, @mesg, 117);
  text_to_buf(win_buf + 640 * 5 + 380, str, 640, 640, colorTable[18979]);

  if not glblmode then
  begin
    str := getmsg(@editor_message_file, @mesg, 112);
    text_to_buf(win_buf + 640 * 233 + 400, str, 640, 640, colorTable[18979]);
    value := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
    PrintBigNum(522, 228, 0, value, 0, edit_win);
  end
  else
  begin
    str := getmsg(@editor_message_file, @mesg, 138);
    text_to_buf(win_buf + 640 * 233 + 422, str, 640, 640, colorTable[18979]);
    if (a1 = 2) and (first_skill_list = 0) then
      PrintBigNum(522, 228, FLAG_ANIMATE, tagskill_count, old_tags, edit_win)
    else
    begin
      PrintBigNum(522, 228, 0, tagskill_count, 0, edit_win);
      first_skill_list := 0;
    end;
  end;

  skill_set_tags(@temp_tag_skill[0], NUM_TAGGED_SKILLS);
  text_font(101);

  y := 27;
  for i := 0 to SKILL_COUNT - 1 do
  begin
    if i = selectedSkill then
    begin
      if (i <> temp_tag_skill[0]) and (i <> temp_tag_skill[1]) and (i <> temp_tag_skill[2]) and (i <> temp_tag_skill[3]) then
        color := colorTable[32747]
      else
        color := colorTable[32767];
    end
    else
    begin
      if (i <> temp_tag_skill[0]) and (i <> temp_tag_skill[1]) and (i <> temp_tag_skill[2]) and (i <> temp_tag_skill[3]) then
        color := colorTable[992]
      else
        color := colorTable[21140];
    end;

    str := skill_name(i);
    text_to_buf(win_buf + 640 * y + 380, str, 640, 640, color);

    value := skill_level(obj_dude, i);
    StrLFmt(@valueString[0], SizeOf(valueString) - 1, '%d%%', [value]);
    text_to_buf(win_buf + 640 * y + 573, @valueString[0], 640, 640, color);

    y := y + text_height() + 1;
  end;

  if not glblmode then
  begin
    y := skill_cursor * (text_height() + 1);
    slider_y := y + 27;

    trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_SLIDER],
      GInfo[EDITOR_GRAPHIC_SLIDER].Width,
      GInfo[EDITOR_GRAPHIC_SLIDER].Height,
      GInfo[EDITOR_GRAPHIC_SLIDER].Width,
      win_buf + 640 * (y + 16) + 592, 640);

    if a1 = 0 then
    begin
      if SliderPlusID = -1 then
      begin
        SliderPlusID := win_register_button(edit_win, 614, slider_y - 7,
          GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Width,
          GInfo[EDITOR_GRAPHIC_SLIDER_PLUS_ON].Height,
          -1, 522, 521, 522,
          grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_OFF],
          grphbmp[EDITOR_GRAPHIC_SLIDER_PLUS_ON],
          nil, 96);
        win_register_button_sound_func(SliderPlusID, @gsound_red_butt_press, nil);
      end;

      if SliderNegID = -1 then
      begin
        SliderNegID := win_register_button(edit_win, 614,
          slider_y + 4 - 12 + GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Height,
          GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_ON].Width,
          GInfo[EDITOR_GRAPHIC_SLIDER_MINUS_OFF].Height,
          -1, 524, 523, 524,
          grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_OFF],
          grphbmp[EDITOR_GRAPHIC_SLIDER_MINUS_ON],
          nil, 96);
        win_register_button_sound_func(SliderNegID, @gsound_red_butt_press, nil);
      end;
    end;
  end;
end;

procedure DrawInfoWin;
var
  graphicId: Integer;
  title_, description: PAnsiChar;
  buffer: array[0..127] of AnsiChar;
  formatted: array[0..149] of AnsiChar;
  base_: PAnsiChar;
  defaultValue, derivedStatIndex, sk: Integer;
  attributesDescription: PAnsiChar;
begin
  if (info_line < 0) or (info_line >= 98) then Exit;

  buf_to_buf(bckgnd + (640 * 267) + 345, 277, 170, 640, win_buf + (267 * 640) + 345, 640);

  if (info_line >= 0) and (info_line < 7) then
  begin
    description := stat_description(info_line);
    title_ := stat_name(info_line);
    graphicId := stat_picture(info_line);
    DrawCard(graphicId, title_, nil, description);
  end
  else if (info_line >= 7) and (info_line < 10) then
  begin
    if glblmode then
    begin
      if info_line = 7 then
      begin
        description := getmsg(@editor_message_file, @mesg, 121);
        title_ := getmsg(@editor_message_file, @mesg, 120);
        DrawCard(7, title_, nil, description);
      end;
    end
    else
    begin
      case info_line of
        7: begin
          description := stat_pc_description(PC_STAT_LEVEL);
          title_ := stat_pc_name(PC_STAT_LEVEL);
          DrawCard(7, title_, nil, description);
        end;
        8: begin
          description := stat_pc_description(PC_STAT_EXPERIENCE);
          title_ := stat_pc_name(PC_STAT_EXPERIENCE);
          DrawCard(8, title_, nil, description);
        end;
        9: begin
          description := getmsg(@editor_message_file, @mesg, 123);
          title_ := getmsg(@editor_message_file, @mesg, 122);
          DrawCard(9, title_, nil, description);
        end;
      end;
    end;
  end
  else if (info_line >= 10) and (info_line < 43) then
  begin
    trait_count := get_trait_count;
    case folder of
      EDITOR_FOLDER_PERKS:
      begin
        if (PerkCount <> 0) and (info_line - 10 < PerkCount) then
        begin
          graphicId := XltPerk(info_line - 10);
          if graphicId <> -1 then
          begin
            title_ := perk_name(graphicId);
            description := perk_description(graphicId);
            DrawCard(graphicId + 72, title_, nil, description);
          end;
        end
        else if (info_line - 10 >= 7) and (info_line - 10 < 11) then
        begin
          if (trait_count < 2) and (info_line - 10 >= 8) and (info_line - 10 <= 9) then
          begin
            title_ := trait_name(temp_trait[info_line - 10 - 8]);
            description := trait_description(temp_trait[info_line - 10 - 8]);
            graphicId := trait_pic(temp_trait[info_line - 10 - 8]);
            DrawCard(graphicId, title_, nil, description);
          end
          else
          begin
            title_ := getmsg(@editor_message_file, @mesg, 146);
            description := getmsg(@editor_message_file, @mesg, 147);
            DrawCard(54, title_, nil, description);
          end;
        end
        else
        begin
          title_ := getmsg(@editor_message_file, @mesg, 124);
          description := getmsg(@editor_message_file, @mesg, 127);
          DrawCard(71, title_, nil, description);
        end;
      end;
      EDITOR_FOLDER_KARMA:
      begin
        if info_line - 10 < karma_count then
        begin
          graphicId := info_line - 10;
          if graphicId > 0 then
            graphicId := XlateKarma(info_line - 11) + 1;
          title_ := getmsg(@editor_message_file, @mesg, 1000 + graphicId);
          description := getmsg(@editor_message_file, @mesg, 1100 + graphicId);
          DrawCard(karma_pic_table[graphicId], title_, nil, description);
        end
        else
        begin
          title_ := getmsg(@editor_message_file, @mesg, 125);
          description := getmsg(@editor_message_file, @mesg, 128);
          DrawCard(47, title_, nil, description);
        end;
      end;
      EDITOR_FOLDER_KILLS:
      begin
        if info_line - 10 < kills_count then
        begin
          DrawFolder;
          StrLFmt(@buffer[0], SizeOf(buffer) - 1, '%s %s',
            [name_sort_list[info_line - 10].name,
             getmsg(@editor_message_file, @mesg, 126)]);
          title_ := @buffer[0];
          description := critter_kill_info(name_sort_list[info_line - 10].value);
          DrawCard(46, title_, nil, description);
        end
        else
        begin
          title_ := getmsg(@editor_message_file, @mesg, 126);
          description := getmsg(@editor_message_file, @mesg, 129);
          DrawCard(46, title_, nil, description);
        end;
      end;
    end;
  end
  else if (info_line >= 82) and (info_line < 98) then
  begin
    graphicId := trait_pic(info_line - 82);
    title_ := trait_name(info_line - 82);
    description := trait_description(info_line - 82);
    DrawCard(graphicId, title_, nil, description);
  end
  else if (info_line >= 43) and (info_line < 51) then
  begin
    case info_line of
      EDITOR_HIT_POINTS: begin
        description := stat_description(STAT_MAXIMUM_HIT_POINTS);
        title_ := getmsg(@editor_message_file, @mesg, 300);
        graphicId := stat_picture(STAT_MAXIMUM_HIT_POINTS);
        DrawCard(graphicId, title_, nil, description);
      end;
      EDITOR_POISONED: begin
        description := getmsg(@editor_message_file, @mesg, 400);
        title_ := getmsg(@editor_message_file, @mesg, 312);
        DrawCard(11, title_, nil, description);
      end;
      EDITOR_RADIATED: begin
        description := getmsg(@editor_message_file, @mesg, 401);
        title_ := getmsg(@editor_message_file, @mesg, 313);
        DrawCard(12, title_, nil, description);
      end;
      EDITOR_EYE_DAMAGE: begin
        description := getmsg(@editor_message_file, @mesg, 402);
        title_ := getmsg(@editor_message_file, @mesg, 314);
        DrawCard(13, title_, nil, description);
      end;
      EDITOR_CRIPPLED_RIGHT_ARM: begin
        description := getmsg(@editor_message_file, @mesg, 403);
        title_ := getmsg(@editor_message_file, @mesg, 315);
        DrawCard(14, title_, nil, description);
      end;
      EDITOR_CRIPPLED_LEFT_ARM: begin
        description := getmsg(@editor_message_file, @mesg, 404);
        title_ := getmsg(@editor_message_file, @mesg, 316);
        DrawCard(15, title_, nil, description);
      end;
      EDITOR_CRIPPLED_RIGHT_LEG: begin
        description := getmsg(@editor_message_file, @mesg, 405);
        title_ := getmsg(@editor_message_file, @mesg, 317);
        DrawCard(16, title_, nil, description);
      end;
      EDITOR_CRIPPLED_LEFT_LEG: begin
        description := getmsg(@editor_message_file, @mesg, 406);
        title_ := getmsg(@editor_message_file, @mesg, 318);
        DrawCard(17, title_, nil, description);
      end;
    end;
  end
  else if (info_line >= EDITOR_FIRST_DERIVED_STAT) and (info_line < 61) then
  begin
    derivedStatIndex := info_line - 51;
    graphicId := ndrvd[derivedStatIndex];
    title_ := stat_name(ndinfoxlt[derivedStatIndex]);
    description := stat_description(ndinfoxlt[derivedStatIndex]);
    DrawCard(graphicId, title_, nil, description);
  end
  else if (info_line >= EDITOR_FIRST_SKILL) and (info_line < 79) then
  begin
    sk := info_line - 61;
    attributesDescription := skill_attribute(sk);

    base_ := getmsg(@editor_message_file, @mesg, 137);
    defaultValue := skill_base(sk);
    StrLFmt(@formatted[0], SizeOf(formatted) - 1, '%s %d%% %s', [base_, defaultValue, attributesDescription]);

    graphicId := skill_pic(sk);
    title_ := skill_name(sk);
    description := skill_description(sk);
    DrawCard(graphicId, title_, @formatted[0], description);
  end
  else if (info_line >= 79) and (info_line < 82) then
  begin
    case info_line of
      EDITOR_TAG_SKILL:
      begin
        if glblmode then
        begin
          description := getmsg(@editor_message_file, @mesg, 145);
          title_ := getmsg(@editor_message_file, @mesg, 144);
          DrawCard(27, title_, nil, description);
        end
        else
        begin
          description := getmsg(@editor_message_file, @mesg, 131);
          title_ := getmsg(@editor_message_file, @mesg, 130);
          DrawCard(27, title_, nil, description);
        end;
      end;
      EDITOR_SKILLS:
      begin
        description := getmsg(@editor_message_file, @mesg, 151);
        title_ := getmsg(@editor_message_file, @mesg, 150);
        DrawCard(27, title_, nil, description);
      end;
      EDITOR_OPTIONAL_TRAITS:
      begin
        description := getmsg(@editor_message_file, @mesg, 147);
        title_ := getmsg(@editor_message_file, @mesg, 146);
        DrawCard(27, title_, nil, description);
      end;
    end;
  end;
end;

function NameWindow: Integer;
var
  text_: PAnsiChar;
  windowWidth, windowHeight: Integer;
  nameWindowX, nameWindowY: Integer;
  win_: Integer;
  windowBuf: PByte;
  name_: array[0..63] of AnsiChar;
  nameCopy: array[0..63] of AnsiChar;
  doneBtn: Integer;
begin
  windowWidth := GInfo[EDITOR_GRAPHIC_CHARWIN].Width;
  windowHeight := GInfo[EDITOR_GRAPHIC_CHARWIN].Height;
  nameWindowX := (screenGetWidth - EDITOR_WINDOW_WIDTH) div 2 + 17;
  nameWindowY := (screenGetHeight - EDITOR_WINDOW_HEIGHT) div 2;
  win_ := win_add(nameWindowX, nameWindowY, windowWidth, windowHeight, 256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if win_ = -1 then begin Result := -1; Exit; end;

  windowBuf := win_get_buf(win_);
  Move(grphbmp[EDITOR_GRAPHIC_CHARWIN]^, windowBuf^, windowWidth * windowHeight);

  trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_NAME_BOX],
    GInfo[EDITOR_GRAPHIC_NAME_BOX].Width, GInfo[EDITOR_GRAPHIC_NAME_BOX].Height,
    GInfo[EDITOR_GRAPHIC_NAME_BOX].Width,
    windowBuf + windowWidth * 13 + 13, windowWidth);
  trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_DONE_BOX],
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width, GInfo[EDITOR_GRAPHIC_DONE_BOX].Height,
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width,
    windowBuf + windowWidth * 40 + 13, windowWidth);

  text_font(103);
  text_ := getmsg(@editor_message_file, @mesg, 100);
  text_to_buf(windowBuf + windowWidth * 44 + 50, text_, windowWidth, windowWidth, colorTable[18979]);

  doneBtn := win_register_button(win_, 26, 44,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 500,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  win_draw(win_);
  text_font(101);

  StrCopy(@name_[0], critter_name(obj_dude));
  if strcmp(@name_[0], 'None') = 0 then
    name_[0] := #0;

  StrCopy(@nameCopy[0], @name_[0]);

  if get_input_str(win_, 500, @name_[0], 11, 23, 19, colorTable[992], 100, 0) <> -1 then
  begin
    if nameCopy[0] <> #0 then
    begin
      critter_pc_set_name(@nameCopy[0]);
      PrintBigname;
      win_delete(win_);
      Result := 0;
      Exit;
    end;
  end;

  text_font(101);
  buf_to_buf(grphbmp[EDITOR_GRAPHIC_NAME_BOX],
    GInfo[EDITOR_GRAPHIC_NAME_BOX].Width, GInfo[EDITOR_GRAPHIC_NAME_BOX].Height,
    GInfo[EDITOR_GRAPHIC_NAME_BOX].Width,
    windowBuf + GInfo[EDITOR_GRAPHIC_CHARWIN].Width * 13 + 13,
    GInfo[EDITOR_GRAPHIC_CHARWIN].Width);

  PrintName(windowBuf, GInfo[EDITOR_GRAPHIC_CHARWIN].Width);
  StrCopy(@nameCopy[0], @name_[0]);
  win_delete(win_);
  Result := 0;
end;

procedure PrintName(buf: PByte; pitch: Integer);
var
  str: array[0..63] of AnsiChar;
  v4: PAnsiChar;
begin
  Move(byte_431D93, str, 64);
  text_font(101);
  v4 := critter_name(obj_dude);
  StrCopy(@str[0], v4);
  text_to_buf(buf + 19 * pitch + 21, @str[0], pitch, pitch, colorTable[992]);
end;

function AgeWindow: Integer;
var
  win_: Integer;
  windowBuf: PByte;
  windowWidth, windowHeight: Integer;
  messageListItemText: PAnsiChar;
  previousAge, age: Integer;
  doneBtn, prevBtn, nextBtn: Integer;
  keyCode, change, flgs: Integer;
  savedAge: Integer;
  ageWindowX, ageWindowY: Integer;
  v32, v33: Integer;
begin
  savedAge := stat_level(obj_dude, STAT_AGE);
  windowWidth := GInfo[EDITOR_GRAPHIC_CHARWIN].Width;
  windowHeight := GInfo[EDITOR_GRAPHIC_CHARWIN].Height;

  ageWindowX := (screenGetWidth - EDITOR_WINDOW_WIDTH) div 2 + GInfo[EDITOR_GRAPHIC_NAME_ON].Width + 9;
  ageWindowY := (screenGetHeight - EDITOR_WINDOW_HEIGHT) div 2;
  win_ := win_add(ageWindowX, ageWindowY, windowWidth, windowHeight, 256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if win_ = -1 then begin Result := -1; Exit; end;

  windowBuf := win_get_buf(win_);
  Move(grphbmp[EDITOR_GRAPHIC_CHARWIN]^, windowBuf^, windowWidth * windowHeight);

  trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_AGE_BOX],
    GInfo[EDITOR_GRAPHIC_AGE_BOX].Width, GInfo[EDITOR_GRAPHIC_AGE_BOX].Height,
    GInfo[EDITOR_GRAPHIC_AGE_BOX].Width,
    windowBuf + windowWidth * 7 + 8, windowWidth);
  trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_DONE_BOX],
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width, GInfo[EDITOR_GRAPHIC_DONE_BOX].Height,
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width,
    windowBuf + windowWidth * 40 + 13, GInfo[EDITOR_GRAPHIC_CHARWIN].Width);

  text_font(103);
  messageListItemText := getmsg(@editor_message_file, @mesg, 100);
  text_to_buf(windowBuf + windowWidth * 44 + 50, messageListItemText, windowWidth, windowWidth, colorTable[18979]);

  age := stat_level(obj_dude, STAT_AGE);
  PrintBigNum(55, 10, 0, age, 0, win_);

  doneBtn := win_register_button(win_, 26, 44,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 500,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  nextBtn := win_register_button(win_, 105, 13,
    GInfo[EDITOR_GRAPHIC_LEFT_ARROW_DOWN].Width,
    GInfo[EDITOR_GRAPHIC_LEFT_ARROW_DOWN].Height,
    -1, 503, 501, 503,
    grphbmp[EDITOR_GRAPHIC_RIGHT_ARROW_UP],
    grphbmp[EDITOR_GRAPHIC_RIGHT_ARROW_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if nextBtn <> -1 then
    win_register_button_sound_func(nextBtn, @gsound_med_butt_press, nil);

  prevBtn := win_register_button(win_, 19, 13,
    GInfo[EDITOR_GRAPHIC_RIGHT_ARROW_DOWN].Width,
    GInfo[EDITOR_GRAPHIC_RIGHT_ARROW_DOWN].Height,
    -1, 504, 502, 504,
    grphbmp[EDITOR_GRAPHIC_LEFT_ARROW_UP],
    grphbmp[EDITOR_GRAPHIC_LEFT_ARROW_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if prevBtn <> -1 then
    win_register_button_sound_func(prevBtn, @gsound_med_butt_press, nil);

  while True do
  begin
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    change := 0;
    v32 := 0;

    keyCode := get_input;
    convertMouseWheelToArrowKey(@keyCode);

    if (keyCode = KEY_RETURN) or (keyCode = 500) then
    begin
      if keyCode <> 500 then
        gsound_play_sfx_file('ib1p1xx1');
      win_delete(win_);
      Result := 0;
      Exit;
    end
    else if (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
      Break
    else if keyCode = 501 then
      change := 1
    else if keyCode = 502 then
      change := -1
    else if (keyCode = KEY_PLUS) or (keyCode = KEY_UPPERCASE_N) or (keyCode = KEY_ARROW_RIGHT) then
    begin
      previousAge := stat_level(obj_dude, STAT_AGE);
      if inc_stat(obj_dude, STAT_AGE) >= 0 then flgs := FLAG_ANIMATE else flgs := 0;
      age := stat_level(obj_dude, STAT_AGE);
      PrintBigNum(55, 10, flgs, age, previousAge, win_);
      if flgs = FLAG_ANIMATE then
      begin
        PrintAgeBig;
        PrintBasicStat(RENDER_ALL_STATS, False, 0);
        ListDrvdStats;
        win_draw(edit_win);
        win_draw(win_);
      end;
    end
    else if (keyCode = KEY_MINUS) or (keyCode = KEY_UPPERCASE_J) or (keyCode = KEY_ARROW_LEFT) then
    begin
      previousAge := stat_level(obj_dude, STAT_AGE);
      if dec_stat(obj_dude, STAT_AGE) >= 0 then flgs := FLAG_ANIMATE else flgs := 0;
      age := stat_level(obj_dude, STAT_AGE);
      PrintBigNum(55, 10, flgs, age, previousAge, win_);
      if flgs = FLAG_ANIMATE then
      begin
        PrintAgeBig;
        PrintBasicStat(RENDER_ALL_STATS, False, 0);
        ListDrvdStats;
        win_draw(edit_win);
        win_draw(win_);
      end;
    end;

    if change <> 0 then
    begin
      v33 := 0;
      repFtime := 4;
      while True do
      begin
        sharedFpsLimiter.Mark;
        frame_time := get_time;
        Inc(v33);

        if ((v32 = 0) and (v33 = 1)) or ((v32 <> 0) and (v33 > 14)) then
        begin
          v32 := 1;
          if v33 > 14 then
          begin
            Inc(repFtime);
            if repFtime > 24 then repFtime := 24;
          end;

          flgs := FLAG_ANIMATE;
          previousAge := stat_level(obj_dude, STAT_AGE);

          if change = 1 then
          begin
            if inc_stat(obj_dude, STAT_AGE) < 0 then flgs := 0;
          end
          else
          begin
            if dec_stat(obj_dude, STAT_AGE) < 0 then flgs := 0;
          end;

          age := stat_level(obj_dude, STAT_AGE);
          PrintBigNum(55, 10, flgs, age, previousAge, win_);
          if flgs = FLAG_ANIMATE then
          begin
            PrintAgeBig;
            PrintBasicStat(RENDER_ALL_STATS, False, 0);
            ListDrvdStats;
            win_draw(edit_win);
            win_draw(win_);
          end;
        end;

        if v33 > 14 then
        begin
          while elapsed_time(frame_time) < (1000 div repFtime) do ;
        end
        else
        begin
          while elapsed_time(frame_time) < (1000 div 24) do ;
        end;

        keyCode := get_input;
        if (keyCode = 503) or (keyCode = 504) or (game_user_wants_to_quit <> 0) then
          Break;

        renderPresent;
        sharedFpsLimiter.Throttle;
      end;
    end
    else
    begin
      win_draw(win_);
      while elapsed_time(frame_time) < (1000 div 24) do ;
      renderPresent;
      sharedFpsLimiter.Throttle;
    end;
  end;

  stat_set_base(obj_dude, STAT_AGE, savedAge);
  PrintAgeBig;
  PrintBasicStat(RENDER_ALL_STATS, False, 0);
  ListDrvdStats;
  win_draw(edit_win);
  win_draw(win_);
  win_delete(win_);
  Result := 0;
end;

procedure SexWindow;
var
  text_: PAnsiChar;
  windowWidth, windowHeight: Integer;
  genderWindowX, genderWindowY: Integer;
  win_: Integer;
  windowBuf: PByte;
  doneBtn: Integer;
  btns: array[0..1] of Integer;
  savedGender, eventCode: Integer;
begin
  windowWidth := GInfo[EDITOR_GRAPHIC_CHARWIN].Width;
  windowHeight := GInfo[EDITOR_GRAPHIC_CHARWIN].Height;
  genderWindowX := (screenGetWidth - EDITOR_WINDOW_WIDTH) div 2 + 9
    + GInfo[EDITOR_GRAPHIC_NAME_ON].Width + GInfo[EDITOR_GRAPHIC_AGE_ON].Width;
  genderWindowY := (screenGetHeight - EDITOR_WINDOW_HEIGHT) div 2;
  win_ := win_add(genderWindowX, genderWindowY, windowWidth, windowHeight, 256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if win_ = -1 then Exit;

  windowBuf := win_get_buf(win_);
  Move(grphbmp[EDITOR_GRAPHIC_CHARWIN]^, windowBuf^, windowWidth * windowHeight);

  trans_buf_to_buf(grphbmp[EDITOR_GRAPHIC_DONE_BOX],
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width, GInfo[EDITOR_GRAPHIC_DONE_BOX].Height,
    GInfo[EDITOR_GRAPHIC_DONE_BOX].Width,
    windowBuf + windowWidth * 44 + 15, windowWidth);

  text_font(103);
  text_ := getmsg(@editor_message_file, @mesg, 100);
  text_to_buf(windowBuf + windowWidth * 48 + 52, text_, windowWidth, windowWidth, colorTable[18979]);

  doneBtn := win_register_button(win_, 28, 48,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 500,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if doneBtn <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, @gsound_red_butt_release);

  btns[0] := win_register_button(win_, 22, 2,
    GInfo[EDITOR_GRAPHIC_MALE_ON].Width, GInfo[EDITOR_GRAPHIC_MALE_ON].Height,
    -1, -1, 501, -1,
    grphbmp[EDITOR_GRAPHIC_MALE_OFF], grphbmp[EDITOR_GRAPHIC_MALE_ON],
    nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x04 or BUTTON_FLAG_0x02 or BUTTON_FLAG_0x01);
  if btns[0] <> -1 then
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, nil);

  btns[1] := win_register_button(win_, 71, 3,
    GInfo[EDITOR_GRAPHIC_FEMALE_ON].Width, GInfo[EDITOR_GRAPHIC_FEMALE_ON].Height,
    -1, -1, 502, -1,
    grphbmp[EDITOR_GRAPHIC_FEMALE_OFF], grphbmp[EDITOR_GRAPHIC_FEMALE_ON],
    nil, BUTTON_FLAG_TRANSPARENT or BUTTON_FLAG_0x04 or BUTTON_FLAG_0x02 or BUTTON_FLAG_0x01);
  if btns[1] <> -1 then
  begin
    win_group_radio_buttons(2, @btns[0]);
    win_register_button_sound_func(doneBtn, @gsound_red_butt_press, nil);
  end;

  savedGender := stat_level(obj_dude, STAT_GENDER);
  win_set_button_rest_state(btns[savedGender], True, 0);

  while True do
  begin
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    eventCode := get_input;

    if eventCode = 500 then Break;
    if eventCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      Break;
    end;
    if (eventCode = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then Break;

    if (eventCode = 501) or (eventCode = 502) then
    begin
      stat_set_base(obj_dude, STAT_GENDER, eventCode - 501);
      PrintBasicStat(RENDER_ALL_STATS, False, 0);
      ListDrvdStats;
    end;

    win_draw(win_);
    while elapsed_time(frame_time) < 41 do ;
    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  PrintGender;
  win_delete(win_);
end;

procedure StatButton(eventCode: Integer);
var
  savedRemainingCharacterPoints: Integer;
  incrementingStat, decrementingStat: Integer;
  v11: Integer;
  cont: Boolean;
  previousValue: Integer;
  delay_: LongWord;
begin
  repFtime := 4;
  savedRemainingCharacterPoints := character_points;

  if not glblmode then Exit;

  incrementingStat := eventCode - 503;
  decrementingStat := eventCode - 510;
  v11 := 0;
  cont := True;

  repeat
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    if v11 <= 19 then Inc(v11);

    if (v11 = 1) or (v11 > 19) then
    begin
      if v11 > 19 then
      begin
        Inc(repFtime);
        if repFtime > 24 then repFtime := 24;
      end;

      if eventCode >= 510 then
      begin
        previousValue := stat_level(obj_dude, decrementingStat);
        if dec_stat(obj_dude, decrementingStat) = 0 then
          Inc(character_points)
        else
          cont := False;

        if cont then
          PrintBasicStat(decrementingStat, True, previousValue)
        else
          PrintBasicStat(decrementingStat, False, previousValue);

        if cont then
          PrintBigNum(126, 282, FLAG_ANIMATE, character_points, savedRemainingCharacterPoints, edit_win)
        else
          PrintBigNum(126, 282, 0, character_points, savedRemainingCharacterPoints, edit_win);

        stat_recalc_derived(obj_dude);
        ListDrvdStats;
        ListSkills(0);
        info_line := decrementingStat;
      end
      else
      begin
        previousValue := stat_get_base(obj_dude, incrementingStat);
        previousValue := previousValue + stat_get_bonus(obj_dude, incrementingStat);
        if (character_points > 0) and (previousValue < 10) and (inc_stat(obj_dude, incrementingStat) = 0) then
          Dec(character_points)
        else
          cont := False;

        if cont then
          PrintBasicStat(incrementingStat, True, previousValue)
        else
          PrintBasicStat(incrementingStat, False, previousValue);

        if cont then
          PrintBigNum(126, 282, FLAG_ANIMATE, character_points, savedRemainingCharacterPoints, edit_win)
        else
          PrintBigNum(126, 282, 0, character_points, savedRemainingCharacterPoints, edit_win);

        stat_recalc_derived(obj_dude);
        ListDrvdStats;
        ListSkills(0);
        info_line := incrementingStat;
      end;

      win_draw(edit_win);
    end;

    if v11 >= 19 then
    begin
      delay_ := 1000 div repFtime;
      while elapsed_time(frame_time) < delay_ do ;
    end
    else
    begin
      while elapsed_time(frame_time) < (1000 div 24) do ;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  until (get_input = 518) or (not cont);

  DrawInfoWin;
end;

function OptionWindow: Integer;
var
  width, height: Integer;
  string1, string2, string3, string4, string5: array[0..511] of AnsiChar;
  dialogBody: array[0..1] of PAnsiChar;
  optionsWindowX, optionsWindowY: Integer;
  win: Integer;
  windowBuffer: PByte;
  err: Integer;
  down, up: array[0..4] of PByte;
  size: Integer;
  y, index, offset_: Integer;
  btn: Integer;
  rc: Integer;
  keyCode: Integer;
  fileList: PPAnsiChar;
  fileListLength: Integer;
  title: PAnsiChar;
  loadFileDialogRc: Integer;
  oldRemainingCharacterPoints: Integer;
  shouldSave: Boolean;
  v42: Integer;
  line2: array[0..511] of AnsiChar;
  lines: array[0..0] of PAnsiChar;
begin
  width := GInfo[43].width;
  height := GInfo[43].height;

  dialogBody[0] := @string5[0];
  dialogBody[1] := @string2[0];

  if glblmode then
  begin
    // Creation mode - full options window
    if screenGetWidth <> 640 then
      optionsWindowX := (screenGetWidth - GInfo[41].width) div 2
    else
      optionsWindowX := 238;

    if screenGetHeight <> 480 then
      optionsWindowY := (screenGetHeight - GInfo[41].height) div 2
    else
      optionsWindowY := 90;

    win := win_add(optionsWindowX, optionsWindowY, GInfo[41].width, GInfo[41].height,
                   256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
    if win = -1 then
    begin
      Result := -1;
      Exit;
    end;

    windowBuffer := win_get_buf(win);
    Move(grphbmp[41]^, windowBuffer^, GInfo[41].width * GInfo[41].height);

    text_font(103);

    err := 0;
    size := width * height;
    y := 17;
    index := 0;

    while (index < 5) and (err = 0) do
    begin
      down[index] := mem_malloc(size);
      if down[index] = nil then
      begin
        err := 1;
        Break;
      end;

      up[index] := mem_malloc(size);
      if up[index] = nil then
      begin
        err := 2;
        Break;
      end;

      Move(grphbmp[43]^, down[index]^, size);
      Move(grphbmp[42]^, up[index]^, size);

      StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 600 + index));

      offset_ := width * 7 + width div 2 - text_width(@string4[0]) div 2;
      text_to_buf(up[index] + offset_, @string4[0], width, width, colorTable[18979]);
      text_to_buf(down[index] + offset_, @string4[0], width, width, colorTable[14723]);

      btn := win_register_button(win, 13, y, width, height, -1, -1, -1, 500 + index,
                                 up[index], down[index], nil, BUTTON_FLAG_TRANSPARENT);
      if btn <> -1 then
        win_register_button_sound_func(btn, @gsound_lrg_butt_press, nil);

      y := y + height + 3;
      Inc(index);
    end;

    if err <> 0 then
    begin
      if err = 2 then
        mem_free(down[index]);

      Dec(index);
      while index >= 0 do
      begin
        mem_free(up[index]);
        mem_free(down[index]);
        Dec(index);
      end;

      Result := -1;
      Exit;
    end;

    text_font(101);

    rc := 0;
    while rc = 0 do
    begin
      sharedFpsLimiter.Mark;

      keyCode := get_input;

      if game_user_wants_to_quit <> 0 then
        rc := 2
      else if keyCode = 504 then
        rc := 2
      else if (keyCode = KEY_RETURN) or (keyCode = KEY_UPPERCASE_D) or (keyCode = KEY_LOWERCASE_D) then
      begin
        // DONE
        rc := 2;
        gsound_play_sfx_file('ib1p1xx1');
      end
      else if keyCode = KEY_ESCAPE then
        rc := 2
      else if (keyCode = 503) or (keyCode = KEY_UPPERCASE_E) or (keyCode = KEY_LOWERCASE_E) then
      begin
        // ERASE
        StrCopy(@string5[0], getmsg(@editor_message_file, @mesg, 605));
        StrCopy(@string2[0], getmsg(@editor_message_file, @mesg, 606));

        if dialog_out(nil, @dialogBody[0], 2, 169, 126, colorTable[992], nil, colorTable[992], DIALOG_BOX_YES_NO) <> 0 then
        begin
          ResetPlayer;
          skill_get_tags(@temp_tag_skill[0], NUM_TAGGED_SKILLS);
          tagskill_count := tagskl_free;
          trait_get(@temp_trait[0], @temp_trait[1]);
          trait_count := get_trait_count;
          stat_recalc_derived(obj_dude);
          ResetScreen;
        end;
      end
      else if (keyCode = 502) or (keyCode = KEY_UPPERCASE_P) or (keyCode = KEY_LOWERCASE_P) then
      begin
        // PRINT TO FILE
        string4[0] := #0;
        StrCat(@string4[0], '*.');
        StrCat(@string4[0], 'TXT');

        fileListLength := db_get_file_list(@string4[0], @fileList, nil, 0);
        if fileListLength <> -1 then
        begin
          // PRINT
          StrCopy(@string1[0], getmsg(@editor_message_file, @mesg, 616));
          // PRINT TO FILE
          StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 602));

          if save_file_dialog(@string4[0], fileList, @string1[0], fileListLength, 168, 80, 0) = 0 then
          begin
            StrCat(@string1[0], '.');
            StrCat(@string1[0], 'TXT');

            string4[0] := #0;
            StrCat(@string4[0], @string1[0]);

            if db_access(@string4[0]) then
            begin
              // already exists
              StrLFmt(@string4[0], SizeOf(string4) - 1, '%s %s',
                [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 609)]);
              StrCopy(@string5[0], getmsg(@editor_message_file, @mesg, 610));

              if dialog_out(@string4[0], @dialogBody[0], 1, 169, 126, colorTable[32328], nil, colorTable[32328], $10) <> 0 then
                rc := 1
              else
                rc := 0;
            end
            else
              rc := 1;

            if rc <> 0 then
            begin
              string4[0] := #0;
              StrCat(@string4[0], @string1[0]);

              if Save_as_ASCII(@string4[0]) = 0 then
              begin
                StrLFmt(@string4[0], SizeOf(string4) - 1, '%s%s',
                  [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 607)]);
                dialog_out(@string4[0], nil, 0, 169, 126, colorTable[992], nil, colorTable[992], 0);
              end
              else
              begin
                gsound_play_sfx_file('iisxxxx1');
                StrLFmt(@string4[0], SizeOf(string4) - 1, '%s%s%s',
                  [getmsg(@editor_message_file, @mesg, 611), compat_strupr(@string1[0]), '!']);
                dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[992], $01);
              end;
            end;
          end;

          db_free_file_list(@fileList, nil);
        end
        else
        begin
          gsound_play_sfx_file('iisxxxx1');
          StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 615));
          dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 0);
          rc := 0;
        end;
      end
      else if (keyCode = 501) or (keyCode = KEY_UPPERCASE_L) or (keyCode = KEY_LOWERCASE_L) then
      begin
        // LOAD
        string4[0] := #0;
        StrCat(@string4[0], '*.');
        StrCat(@string4[0], 'GCD');

        fileListLength := db_get_file_list(@string4[0], @fileList, nil, 0);
        if fileListLength <> -1 then
        begin
          title := getmsg(@editor_message_file, @mesg, 601);
          loadFileDialogRc := file_dialog(title, fileList, @string3[0], fileListLength, 168, 80, 0);
          if loadFileDialogRc = -1 then
          begin
            db_free_file_list(@fileList, nil);
            Result := -1;
            Exit;
          end;

          if loadFileDialogRc = 0 then
          begin
            string4[0] := #0;
            StrCat(@string4[0], @string3[0]);

            oldRemainingCharacterPoints := character_points;

            ResetPlayer;

            if pc_load_data(@string4[0]) = 0 then
            begin
              CheckValidPlayer;
              skill_get_tags(@temp_tag_skill[0], 4);
              tagskill_count := tagskl_free;
              trait_get(@temp_trait[0], @temp_trait[1]);
              trait_count := get_trait_count;
              stat_recalc_derived(obj_dude);
              critter_adjust_hits(obj_dude, 1000);
              rc := 1;
            end
            else
            begin
              RestorePlayer;
              character_points := oldRemainingCharacterPoints;
              critter_adjust_hits(obj_dude, 1000);
              gsound_play_sfx_file('iisxxxx1');

              StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 612));
              StrCat(@string4[0], @string3[0]);
              StrCat(@string4[0], '!');

              dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 0);
            end;

            ResetScreen;
          end;

          db_free_file_list(@fileList, nil);
        end
        else
        begin
          gsound_play_sfx_file('iisxxxx1');
          StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 615));
          rc := 0;
          dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 0);
        end;
      end
      else if (keyCode = 500) or (keyCode = KEY_UPPERCASE_S) or (keyCode = KEY_LOWERCASE_S) then
      begin
        // SAVE
        string4[0] := #0;
        StrCat(@string4[0], '*.');
        StrCat(@string4[0], 'GCD');

        fileListLength := db_get_file_list(@string4[0], @fileList, nil, 0);
        if fileListLength <> -1 then
        begin
          StrCopy(@string1[0], getmsg(@editor_message_file, @mesg, 617));
          StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 600));

          if save_file_dialog(@string4[0], fileList, @string1[0], fileListLength, 168, 80, 0) = 0 then
          begin
            StrCat(@string1[0], '.');
            StrCat(@string1[0], 'GCD');

            string4[0] := #0;
            StrCat(@string4[0], @string1[0]);

            shouldSave := False;
            if db_access(@string4[0]) then
            begin
              StrLFmt(@string4[0], SizeOf(string4) - 1, '%s %s',
                [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 609)]);
              StrCopy(@string5[0], getmsg(@editor_message_file, @mesg, 610));

              if dialog_out(@string4[0], @dialogBody[0], 1, 169, 126, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_YES_NO) <> 0 then
                shouldSave := True
              else
                shouldSave := False;
            end
            else
              shouldSave := True;

            if shouldSave then
            begin
              skill_set_tags(@temp_tag_skill[0], 4);
              trait_set(temp_trait[0], temp_trait[1]);

              string4[0] := #0;
              StrCat(@string4[0], @string1[0]);

              if pc_save_data(@string4[0]) <> 0 then
              begin
                gsound_play_sfx_file('iisxxxx1');
                StrLFmt(@string4[0], SizeOf(string4) - 1, '%s%s!',
                  [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 611)]);
                dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
                rc := 0;
              end
              else
              begin
                StrLFmt(@string4[0], SizeOf(string4) - 1, '%s%s',
                  [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 607)]);
                dialog_out(@string4[0], nil, 0, 169, 126, colorTable[992], nil, colorTable[992], DIALOG_BOX_LARGE);
                rc := 1;
              end;
            end;
          end;

          db_free_file_list(@fileList, nil);
        end
        else
        begin
          gsound_play_sfx_file('iisxxxx1');
          title := getmsg(@editor_message_file, @mesg, 615);
          dialog_out(title, nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 0);
          rc := 0;
        end;
      end;

      win_draw(win);
      renderPresent;
      sharedFpsLimiter.Throttle;
    end;

    win_delete(win);

    for index := 0 to 4 do
    begin
      mem_free(up[index]);
      mem_free(down[index]);
    end;

    Result := 0;
    Exit;
  end;

  // Character Editor is not in creation mode - this button is only for printing
  string4[0] := #0;
  StrCat(@string4[0], '*.TXT');

  fileListLength := db_get_file_list(@string4[0], @fileList, nil, 0);
  if fileListLength = -1 then
  begin
    gsound_play_sfx_file('iisxxxx1');
    StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 615));
    dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 0);
    Result := 0;
    Exit;
  end;

  // PRINT
  StrCopy(@string1[0], getmsg(@editor_message_file, @mesg, 616));
  // PRINT TO FILE
  StrCopy(@string4[0], getmsg(@editor_message_file, @mesg, 602));

  if save_file_dialog(@string4[0], fileList, @string1[0], fileListLength, 168, 80, 0) = 0 then
  begin
    StrCat(@string1[0], '.TXT');

    string4[0] := #0;
    StrCat(@string4[0], @string1[0]);

    v42 := 0;
    if db_access(@string4[0]) then
    begin
      StrLFmt(@string4[0], SizeOf(string4) - 1, '%s %s',
        [compat_strupr(@string1[0]), getmsg(@editor_message_file, @mesg, 609)]);
      StrCopy(@line2[0], getmsg(@editor_message_file, @mesg, 610));

      lines[0] := @line2[0];
      v42 := dialog_out(@string4[0], @lines[0], 1, 169, 126, colorTable[32328], nil, colorTable[32328], $10);
      if v42 <> 0 then
        v42 := 1;
    end
    else
      v42 := 1;

    if v42 <> 0 then
    begin
      string4[0] := #0;
      StrCopy(@string4[0], @string1[0]);

      if Save_as_ASCII(@string4[0]) <> 0 then
      begin
        gsound_play_sfx_file('iisxxxx1');
        StrLFmt(@string4[0], SizeOf(string4) - 1, '%s%s%s',
          [getmsg(@editor_message_file, @mesg, 611), compat_strupr(@string1[0]), '!']);
        dialog_out(@string4[0], nil, 0, 169, 126, colorTable[32328], nil, colorTable[32328], 1);
      end;
    end;
  end;

  db_free_file_list(@fileList, nil);

  Result := 0;
end;

function db_access(const fname: PAnsiChar): Boolean;
var
  stream: PDB_FILE;
begin
  stream := db_fopen(fname, 'rb');
  if stream = nil then
  begin
    Result := False;
    Exit;
  end;
  db_fclose(stream);
  Result := True;
end;

function Save_as_ASCII(const fileName: PAnsiChar): Integer;
var
  stream: PDB_FILE;
  title1, title2, title3, padding: array[0..255] of AnsiChar;
  month, day, year: Integer;
  paddingLength, perk, rank, skill, killType: Integer;
  inventory: PInventory;
  index, column, inventoryItemIndex: Integer;
  inventoryItem: PInventoryItem;
  length_: Integer;
  hasKillType: Boolean;
  killsCount_: Integer;
begin
  stream := db_fopen(fileName, 'wt');
  if stream = nil then begin Result := -1; Exit; end;

  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);

  // FALLOUT
  StrCopy(@title1[0], getmsg(@editor_message_file, @mesg, 620));
  padding[0] := #0;
  AddSpaces(@padding[0], (80 - Integer(StrLen(@title1[0]))) div 2 - 2);
  StrCat(@padding[0], @title1[0]);
  StrCat(@padding[0], PAnsiChar(#10));
  db_fputs(@padding[0], stream);

  // VAULT-13 PERSONNEL RECORD
  StrCopy(@title1[0], getmsg(@editor_message_file, @mesg, 621));
  padding[0] := #0;
  AddSpaces(@padding[0], (80 - Integer(StrLen(@title1[0]))) div 2 - 2);
  StrCat(@padding[0], @title1[0]);
  StrCat(@padding[0], PAnsiChar(#10));
  db_fputs(@padding[0], stream);

  game_time_date(@month, @day, @year);
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%.2d %s %d  %.4d %s',
    [day, getmsg(@editor_message_file, @mesg, 500 + month - 1), year,
     game_time_hour, getmsg(@editor_message_file, @mesg, 622)]);
  padding[0] := #0;
  AddSpaces(@padding[0], (80 - Integer(StrLen(@title1[0]))) div 2 - 2);
  StrCat(@padding[0], @title1[0]);
  StrCat(@padding[0], PAnsiChar(#10));
  db_fputs(@padding[0], stream);

  db_fputs(PAnsiChar(#10), stream);

  // Name
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %s',
    [getmsg(@editor_message_file, @mesg, 642), critter_name(obj_dude)]);
  paddingLength := 27 - Integer(StrLen(@title1[0]));
  if paddingLength > 0 then
  begin
    padding[0] := #0;
    AddSpaces(@padding[0], paddingLength);
    StrCat(@title1[0], @padding[0]);
  end;

  // Age
  StrLFmt(@title2[0], SizeOf(title2) - 1, '%s%s %d',
    [PAnsiChar(@title1[0]), getmsg(@editor_message_file, @mesg, 643), stat_level(obj_dude, STAT_AGE)]);

  // Gender
  StrLFmt(@title3[0], SizeOf(title3) - 1, '%s%s %s',
    [PAnsiChar(@title1[0]), getmsg(@editor_message_file, @mesg, 644),
     getmsg(@editor_message_file, @mesg, 645 + stat_level(obj_dude, STAT_GENDER))]);
  db_fputs(@title3[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %s ',
    [getmsg(@editor_message_file, @mesg, 647), stat_pc_get(PC_STAT_LEVEL),
     getmsg(@editor_message_file, @mesg, 648),
     itostndn(stat_pc_get(PC_STAT_EXPERIENCE), @title3[0])]);
  paddingLength := 12 - Integer(StrLen(@title3[0]));
  if paddingLength > 0 then
  begin
    padding[0] := #0;
    AddSpaces(@padding[0], paddingLength);
    StrCat(@title1[0], @padding[0]);
  end;
  StrLFmt(@title2[0], SizeOf(title2) - 1, '%s%s %s',
    [PAnsiChar(@title1[0]), getmsg(@editor_message_file, @mesg, 649),
     itostndn(stat_pc_min_exp, @title3[0])]);
  db_fputs(@title2[0], stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);

  // Stats
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.3d/%.3d %s %.2d',
    [getmsg(@editor_message_file, @mesg, 624), stat_level(obj_dude, STAT_STRENGTH),
     getmsg(@editor_message_file, @mesg, 625),
     critter_get_hits(obj_dude), stat_level(obj_dude, STAT_MAXIMUM_HIT_POINTS),
     getmsg(@editor_message_file, @mesg, 626), stat_level(obj_dude, STAT_STRENGTH)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.3d %s %.2d',
    [getmsg(@editor_message_file, @mesg, 627), stat_level(obj_dude, STAT_PERCEPTION),
     getmsg(@editor_message_file, @mesg, 628), stat_level(obj_dude, STAT_ARMOR_CLASS),
     getmsg(@editor_message_file, @mesg, 629), stat_level(obj_dude, STAT_HEALING_RATE)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.2d %s %.3d%%',
    [getmsg(@editor_message_file, @mesg, 630), stat_level(obj_dude, STAT_ENDURANCE),
     getmsg(@editor_message_file, @mesg, 631), stat_level(obj_dude, STAT_MAXIMUM_ACTION_POINTS),
     getmsg(@editor_message_file, @mesg, 632), stat_level(obj_dude, STAT_CRITICAL_CHANCE)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.2d %s %.3d lbs.',
    [getmsg(@editor_message_file, @mesg, 633), stat_level(obj_dude, STAT_CHARISMA),
     getmsg(@editor_message_file, @mesg, 634), stat_level(obj_dude, STAT_MELEE_DAMAGE),
     getmsg(@editor_message_file, @mesg, 635), stat_level(obj_dude, STAT_CARRY_WEIGHT)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.3d%%',
    [getmsg(@editor_message_file, @mesg, 636), stat_level(obj_dude, STAT_INTELLIGENCE),
     getmsg(@editor_message_file, @mesg, 637), stat_level(obj_dude, STAT_DAMAGE_RESISTANCE)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.3d%%',
    [getmsg(@editor_message_file, @mesg, 638), stat_level(obj_dude, STAT_AGILITY),
     getmsg(@editor_message_file, @mesg, 639), stat_level(obj_dude, STAT_RADIATION_RESISTANCE)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %.2d %s %.3d%%',
    [getmsg(@editor_message_file, @mesg, 640), stat_level(obj_dude, STAT_LUCK),
     getmsg(@editor_message_file, @mesg, 641), stat_level(obj_dude, STAT_POISON_RESISTANCE)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);

  if temp_trait[0] <> -1 then
  begin
    StrLFmt(@title1[0], SizeOf(title1) - 1, '%s'#10, [getmsg(@editor_message_file, @mesg, 650)]);
    db_fputs(@title1[0], stream);
    for index := 0 to PC_TRAIT_MAX - 1 do
    begin
      if temp_trait[index] <> -1 then
      begin
        StrLFmt(@title1[0], SizeOf(title1) - 1, '  %s', [trait_name(temp_trait[index])]);
        db_fputs(@title1[0], stream);
        db_fputs(PAnsiChar(#10), stream);
      end;
    end;
  end;

  perk := 0;
  while perk < PERK_COUNT do
  begin
    if perk_level(perk) <> 0 then Break;
    Inc(perk);
  end;

  if perk < PERK_COUNT then
  begin
    StrLFmt(@title1[0], SizeOf(title1) - 1, '%s'#10, [getmsg(@editor_message_file, @mesg, 651)]);
    db_fputs(@title1[0], stream);
    for perk := 0 to PERK_COUNT - 1 do
    begin
      rank := perk_level(perk);
      if rank <> 0 then
      begin
        if rank = 1 then
          StrLFmt(@title1[0], SizeOf(title1) - 1, '  %s', [perk_name(perk)])
        else
          StrLFmt(@title1[0], SizeOf(title1) - 1, '  %s (%d)', [perk_name(perk), rank]);
        db_fputs(@title1[0], stream);
        db_fputs(PAnsiChar(#10), stream);
      end;
    end;
  end;

  db_fputs(PAnsiChar(#10), stream);

  // Karma
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s'#10, [getmsg(@editor_message_file, @mesg, 652)]);
  db_fputs(@title1[0], stream);

  db_fputs(PAnsiChar(#10), stream);

  // Skills/Kills
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s'#10, [getmsg(@editor_message_file, @mesg, 653)]);
  db_fputs(@title1[0], stream);

  killType := 0;
  for skill := 0 to SKILL_COUNT - 1 do
  begin
    StrLFmt(@title1[0], SizeOf(title1) - 1, '%s ', [skill_name(skill)]);
    AddDots(@title1[0] + StrLen(@title1[0]), 16 - Integer(StrLen(@title1[0])));

    hasKillType := False;
    while killType < KILL_TYPE_COUNT do
    begin
      killsCount_ := critter_kill_count(killType);
      if killsCount_ > 0 then
      begin
        StrLFmt(@title2[0], SizeOf(title2) - 1, '%s ', [critter_kill_name(killType)]);
        AddDots(@title2[0] + StrLen(@title2[0]), 16 - Integer(StrLen(@title2[0])));
        StrLFmt(@title3[0], SizeOf(title3) - 1, '  %s %.3d%%        %s %.3d'#10,
          [PAnsiChar(@title1[0]), skill_level(obj_dude, skill), PAnsiChar(@title2[0]), killsCount_]);
        hasKillType := True;
        Inc(killType);
        Break;
      end;
      Inc(killType);
    end;

    if not hasKillType then
    begin
      StrLFmt(@title3[0], SizeOf(title3) - 1, '  %s %.3d%%'#10,
        [PAnsiChar(@title1[0]), skill_level(obj_dude, skill)]);
    end;

    db_fputs(@title3[0], stream);
  end;

  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);

  // Inventory
  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s'#10, [getmsg(@editor_message_file, @mesg, 654)]);
  db_fputs(@title1[0], stream);

  inventory := @obj_dude^.Data.AsData.Inventory;
  index := 0;
  while index < inventory^.Length do
  begin
    title1[0] := #0;
    for column := 0 to 2 do
    begin
      inventoryItemIndex := index + column;
      if inventoryItemIndex >= inventory^.Length then Break;
      inventoryItem := PInventoryItem(PByte(inventory^.Items) + inventoryItemIndex * SizeOf(TInventoryItem));
      StrLFmt(@title2[0], SizeOf(title2) - 1, '  %sx %s',
        [itostndn(inventoryItem^.Quantity, @title3[0]),
         object_name(inventoryItem^.Item)]);
      length_ := 25 - Integer(StrLen(@title2[0]));
      if length_ < 0 then length_ := 0;
      AddSpaces(@title2[0], length_);
      StrCat(@title1[0], @title2[0]);
    end;
    StrCat(@title1[0], PAnsiChar(#10));
    db_fputs(@title1[0], stream);
    index := index + 3;
  end;

  db_fputs(PAnsiChar(#10), stream);

  StrLFmt(@title1[0], SizeOf(title1) - 1, '%s %d lbs.',
    [getmsg(@editor_message_file, @mesg, 655), item_total_weight(obj_dude)]);
  db_fputs(@title1[0], stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fputs(PAnsiChar(#10), stream);
  db_fclose(stream);

  Result := 0;
end;

procedure ResetScreen;
begin
  info_line := 0;
  skill_cursor := 0;
  slider_y := 27;
  folder := 0;

  if glblmode then
    PrintBigNum(126, 282, 0, character_points, 0, edit_win)
  else
  begin
    DrawFolder;
    PrintLevelWin;
  end;

  PrintBigname;
  PrintAgeBig;
  PrintGender;
  ListTraits;
  ListSkills(0);
  PrintBasicStat(7, False, 0);
  ListDrvdStats;
  DrawInfoWin;
  win_draw(edit_win);
end;

function AddSpaces(str: PAnsiChar; length_: Integer): PAnsiChar;
var
  pch: PAnsiChar;
  index: Integer;
begin
  pch := str + StrLen(str);
  for index := 0 to length_ - 1 do
  begin
    pch^ := ' ';
    Inc(pch);
  end;
  pch^ := #0;
  Result := str;
end;

function AddDots(str: PAnsiChar; length_: Integer): PAnsiChar;
var
  pch: PAnsiChar;
  index: Integer;
begin
  pch := str + StrLen(str);
  for index := 0 to length_ - 1 do
  begin
    pch^ := '.';
    Inc(pch);
  end;
  pch^ := #0;
  Result := str;
end;

procedure RegInfoAreas;
begin
  win_register_button(edit_win, 19, 38, 125, 227, -1, -1, 525, -1, nil, nil, nil, 0);
  win_register_button(edit_win, 28, 280, 124, 32, -1, -1, 526, -1, nil, nil, nil, 0);

  if glblmode then
  begin
    win_register_button(edit_win, 52, 324, 169, 20, -1, -1, 533, -1, nil, nil, nil, 0);
    win_register_button(edit_win, 47, 353, 245, 100, -1, -1, 534, -1, nil, nil, nil, 0);
  end
  else
    win_register_button(edit_win, 28, 363, 283, 105, -1, -1, 527, -1, nil, nil, nil, 0);

  win_register_button(edit_win, 191, 41, 122, 110, -1, -1, 528, -1, nil, nil, nil, 0);
  win_register_button(edit_win, 191, 175, 122, 135, -1, -1, 529, -1, nil, nil, nil, 0);
  win_register_button(edit_win, 376, 5, 223, 20, -1, -1, 530, -1, nil, nil, nil, 0);
  win_register_button(edit_win, 370, 27, 223, 195, -1, -1, 531, -1, nil, nil, nil, 0);
  win_register_button(edit_win, 396, 228, 171, 25, -1, -1, 532, -1, nil, nil, nil, 0);
end;

function CheckValidPlayer: Integer;
var
  st: Integer;
begin
  stat_recalc_derived(obj_dude);
  stat_pc_set_defaults;
  for st := 0 to SAVEABLE_STAT_COUNT - 1 do
    stat_set_bonus(obj_dude, st, 0);
  perk_reset;
  stat_recalc_derived(obj_dude);
  Result := 1;
end;

procedure SavePlayer;
var
  proto: PProto;
  skill: Integer;
begin
  proto_ptr(obj_dude^.Pid, @proto);
  critter_copy(@dude_data, @PCritterProto(proto)^.Data);
  hp_back := critter_get_hits(obj_dude);
  StrLCopy(@name_save[0], critter_name(obj_dude), 31);
  last_level_back := last_level;
  push_perks;
  free_perk_back := AnsiChar(free_perk);
  upsent_points_back := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
  skill_get_tags(@tag_skill_back[0], NUM_TAGGED_SKILLS);
  trait_get(@trait_back[0], @trait_back[1]);

  if not glblmode then
  begin
    for skill := 0 to SKILL_COUNT - 1 do
      skillsav[skill] := skill_level(obj_dude, skill);
  end;
end;

procedure RestorePlayer;
var
  proto: PProto;
  cur_hp: Integer;
begin
  pop_perks;
  proto_ptr(obj_dude^.Pid, @proto);
  critter_copy(@PCritterProto(proto)^.Data, @dude_data);
  critter_pc_set_name(@name_save[0]);
  last_level := last_level_back;
  free_perk := Byte(free_perk_back);
  stat_pc_set(PC_STAT_UNSPENT_SKILL_POINTS, upsent_points_back);
  skill_set_tags(@tag_skill_back[0], NUM_TAGGED_SKILLS);
  trait_set(trait_back[0], trait_back[1]);
  skill_get_tags(@temp_tag_skill[0], NUM_TAGGED_SKILLS);
  tagskill_count := tagskl_free;
  trait_get(@temp_trait[0], @temp_trait[1]);
  trait_count := get_trait_count;
  stat_recalc_derived(obj_dude);
  cur_hp := critter_get_hits(obj_dude);
  critter_adjust_hits(obj_dude, hp_back - cur_hp);
end;

function itostndn(value: Integer; dest: PAnsiChar): PAnsiChar;
var
  savedDest: PAnsiChar;
  v3: Boolean;
  index, v18: Integer;
  temp: array[0..63] of AnsiChar;
begin
  savedDest := dest;

  if value <> 0 then
  begin
    dest^ := #0;
    v3 := False;
    for index := 0 to 6 do
    begin
      v18 := value div itostndn_v16[index];
      if (v18 > 0) or v3 then
      begin
        compat_itoa(v18, @temp[0], 10);
        StrCat(dest, @temp[0]);
        v3 := True;
        value := value - itostndn_v16[index] * v18;
        if (index = 0) or (index = 3) then
          StrCat(dest, ',');
      end;
    end;
  end
  else
    StrCopy(dest, '0');

  Result := savedDest;
end;

function DrawCard(graphicId: Integer; const name_: PAnsiChar; const attributes: PAnsiChar; description: PAnsiChar): Integer;
var
  graphicHandle: PCacheEntry;
  size: TSize;
  fid: Integer;
  buf_: PByte;
  ptr: PByte;
  v9, x, y: Integer;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  beginningsCount: SmallInt;
  nameFontLineHeight, nameWidth, attributesFontLineHeight, descriptionFontLineHeight: Integer;
  c: AnsiChar;
  i: SmallInt;
begin
  fid := art_id(OBJ_TYPE_SKILLDEX, graphicId, 0, 0, 0);
  buf_ := art_lock(fid, @graphicHandle, @size.Width, @size.Height);
  if buf_ = nil then begin Result := -1; Exit; end;

  buf_to_buf(buf_, size.Width, size.Height, size.Width, win_buf + 640 * 309 + 484, 640);

  v9 := 150;
  ptr := buf_;
  for y := 0 to size.Height - 1 do
  begin
    for x := 0 to size.Width - 1 do
    begin
      if (HighRGB(ptr^) < 2) and (v9 >= x) then
        v9 := x;
      Inc(ptr);
    end;
  end;

  Dec(v9, 8);
  if v9 < 0 then v9 := 0;

  text_font(102);
  text_to_buf(win_buf + 640 * 272 + 348, name_, 640, 640, colorTable[0]);
  nameFontLineHeight := text_height();

  if attributes <> nil then
  begin
    nameWidth := text_width(name_);
    text_font(101);
    attributesFontLineHeight := text_height();
    text_to_buf(win_buf + 640 * (268 + nameFontLineHeight - attributesFontLineHeight) + 348 + nameWidth + 8, attributes, 640, 640, colorTable[0]);
  end;

  y := nameFontLineHeight;
  win_line(edit_win, 348, y + 272, 613, y + 272, colorTable[0]);
  win_line(edit_win, 348, y + 273, 613, y + 273, colorTable[0]);

  text_font(101);
  descriptionFontLineHeight := text_height();

  if word_wrap(description, v9 + 136, @beginnings[0], @beginningsCount) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  y := 315;
  i := 0;
  while i < beginningsCount - 1 do
  begin
    c := description[beginnings[i + 1]];
    description[beginnings[i + 1]] := #0;
    text_to_buf(win_buf + 640 * y + 348, description + beginnings[i], 640, 640, colorTable[0]);
    description[beginnings[i + 1]] := c;
    y := y + descriptionFontLineHeight;
    Inc(i);
  end;

  if (graphicId <> old_fid1) or (strcmp(name_, @old_str1[0]) <> 0) then
  begin
    if frstc_draw1 then
      gsound_play_sfx_file('isdxxxx1');
  end;

  StrCopy(@old_str1[0], name_);
  old_fid1 := graphicId;
  frstc_draw1 := True;

  art_ptr_unlock(graphicHandle);
  Result := 0;
end;

function XltPerk(search: Integer): Integer;
var
  perk, valid_perk: Integer;
begin
  valid_perk := 0;
  for perk := 0 to PERK_COUNT - 1 do
  begin
    if perk_level(perk) <> 0 then
    begin
      if valid_perk = search then
      begin
        Result := perk;
        Exit;
      end;
      Inc(valid_perk);
    end;
  end;
  debug_printf(PAnsiChar(#10' ** Perk not found in translate! **'#10));
  Result := -1;
end;

procedure FldrButton;
begin
  mouseGetPositionInWindow(edit_win, @mouse_xpos, @mouse_ypos);
  gsound_play_sfx_file('ib3p1xx1');

  if mouse_xpos >= 208 then
  begin
    info_line := 41;
    folder := EDITOR_FOLDER_KILLS;
  end
  else if mouse_xpos > 110 then
  begin
    info_line := 42;
    folder := EDITOR_FOLDER_KARMA;
  end
  else
  begin
    info_line := 40;
    folder := EDITOR_FOLDER_PERKS;
  end;

  DrawFolder;
  DrawInfoWin;
end;

procedure InfoButton(eventCode: Integer);
var
  offset_, index: Integer;
  mouseY_, buttonTop, buttonBottom, allowance: Double;
  fontLineHeight, y_: Double;
  step: Double;
begin
  mouseGetPositionInWindow(edit_win, @mouse_xpos, @mouse_ypos);

  case eventCode of
    525:
    begin
      mouseY_ := mouse_ypos;
      for index := 0 to 6 do
      begin
        buttonTop := StatYpos[index];
        buttonBottom := StatYpos[index] + 22;
        allowance := 5.0 - index * 0.25;
        if (mouseY_ >= buttonTop - allowance) and (mouseY_ <= buttonBottom + allowance) then
        begin
          info_line := index;
          Break;
        end;
      end;
    end;
    526:
    begin
      if glblmode then
        info_line := 7
      else
      begin
        offset_ := mouse_ypos - 280;
        if offset_ < 0 then offset_ := 0;
        info_line := offset_ div 10 + 7;
      end;
    end;
    527:
    begin
      if not glblmode then
      begin
        text_font(101);
        offset_ := mouse_ypos - 364;
        if offset_ < 0 then offset_ := 0;
        info_line := offset_ div (text_height() + 1) + 10;
        if (folder = EDITOR_FOLDER_KILLS) and (mouse_xpos > 174) then
          info_line := info_line + 10;
      end;
    end;
    528:
    begin
      offset_ := mouse_ypos - 41;
      if offset_ < 0 then offset_ := 0;
      info_line := offset_ div 13 + 43;
    end;
    529:
    begin
      offset_ := mouse_ypos - 175;
      if offset_ < 0 then offset_ := 0;
      info_line := offset_ div 13 + 51;
    end;
    530: info_line := 80;
    531:
    begin
      offset_ := mouse_ypos - 27;
      if offset_ < 0 then offset_ := 0;
      skill_cursor := Trunc(offset_ * 0.092307694);
      if skill_cursor >= 18 then skill_cursor := 17;
      info_line := skill_cursor + 61;
    end;
    532: info_line := 79;
    533: info_line := 81;
    534:
    begin
      text_font(101);
      mouseY_ := mouse_ypos;
      fontLineHeight := text_height();
      y_ := 353.0;
      step := text_height() + 3 + 0.56;
      index := 0;
      while index < 8 do
      begin
        if (mouseY_ >= y_ - 4.0) and (mouseY_ <= y_ + fontLineHeight) then Break;
        y_ := y_ + step;
        Inc(index);
      end;
      if index = 8 then index := 7;
      info_line := index + 82;
      if mouse_xpos >= 169 then
        info_line := info_line + 8;
    end;
  end;

  ListTraits;
  ListSkills(0);
  PrintLevelWin;
  DrawFolder;
  ListDrvdStats;
  DrawInfoWin;
end;

procedure SliderBtn(a1: Integer);
var
  unspentSp: Integer;
  isUsingKeyboard: Boolean;
  rc: Integer;
  title_: array[0..63] of AnsiChar;
  body1, body2: array[0..63] of AnsiChar;
  body: array[0..1] of PAnsiChar;
  repeatDelay: Integer;
  flgs, keyCode2: Integer;
begin
  if glblmode then Exit;

  unspentSp := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
  repFtime := 4;
  isUsingKeyboard := False;
  rc := 0;

  case a1 of
    KEY_PLUS, KEY_UPPERCASE_N, KEY_ARROW_RIGHT:
    begin
      isUsingKeyboard := True;
      a1 := 521;
    end;
    KEY_MINUS, KEY_UPPERCASE_J, KEY_ARROW_LEFT:
    begin
      isUsingKeyboard := True;
      a1 := 523;
    end;
  end;

  body[0] := @body1[0];
  body[1] := @body2[0];

  repeatDelay := 0;
  while True do
  begin
    sharedFpsLimiter.Mark;
    frame_time := get_time;
    if repeatDelay <= 19 then Inc(repeatDelay);

    if (repeatDelay = 1) or (repeatDelay > 19) then
    begin
      if repeatDelay > 19 then
      begin
        Inc(repFtime);
        if repFtime > 24 then repFtime := 24;
      end;

      rc := 1;
      if a1 = 521 then
      begin
        if stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS) > 0 then
        begin
          if skill_inc_point(obj_dude, skill_cursor) = -3 then
          begin
            gsound_play_sfx_file('iisxxxx1');
            StrLFmt(@title_[0], SizeOf(title_) - 1, '%s:', [skill_name(skill_cursor)]);
            StrCopy(@body1[0], getmsg(@editor_message_file, @mesg, 132));
            StrCopy(@body2[0], getmsg(@editor_message_file, @mesg, 133));
            dialog_out(@title_[0], @body[0], 2, 192, 126, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
            rc := -1;
          end;
        end
        else
        begin
          gsound_play_sfx_file('iisxxxx1');
          StrCopy(@title_[0], getmsg(@editor_message_file, @mesg, 136));
          dialog_out(@title_[0], nil, 0, 192, 126, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
          rc := -1;
        end;
      end
      else if a1 = 523 then
      begin
        if skill_level(obj_dude, skill_cursor) <= skillsav[skill_cursor] then
          rc := 0
        else
        begin
          if skill_dec_point(obj_dude, skill_cursor) = -2 then
            rc := 0;
        end;

        if rc = 0 then
        begin
          gsound_play_sfx_file('iisxxxx1');
          StrLFmt(@title_[0], SizeOf(title_) - 1, '%s:', [skill_name(skill_cursor)]);
          StrCopy(@body1[0], getmsg(@editor_message_file, @mesg, 134));
          StrCopy(@body2[0], getmsg(@editor_message_file, @mesg, 135));
          dialog_out(@title_[0], @body[0], 2, 192, 126, colorTable[32328], nil, colorTable[32328], DIALOG_BOX_LARGE);
          rc := -1;
        end;
      end;

      info_line := skill_cursor + 61;
      DrawInfoWin;
      ListSkills(1);

      if rc = 1 then flgs := FLAG_ANIMATE
      else flgs := 0;

      PrintBigNum(522, 228, flgs, stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS), unspentSp, edit_win);
      win_draw(edit_win);
    end;

    if not isUsingKeyboard then
    begin
      unspentSp := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
      if repeatDelay >= 19 then
      begin
        while elapsed_time(frame_time) < (1000 div repFtime) do ;
      end
      else
      begin
        while elapsed_time(frame_time) < (1000 div 24) do ;
      end;

      keyCode2 := get_input;
      if (keyCode2 <> 522) and (keyCode2 <> 524) and (rc <> -1) then
      begin
        renderPresent;
        sharedFpsLimiter.Throttle;
        Continue;
      end;
    end;
    Exit;
  end;
end;

function tagskl_free: Integer;
var
  taggedSkillCount, index: Integer;
begin
  taggedSkillCount := 0;
  index := 3;
  while index >= 0 do
  begin
    if temp_tag_skill[index] <> -1 then Break;
    Inc(taggedSkillCount);
    Dec(index);
  end;

  if glblmode then
    Dec(taggedSkillCount);

  Result := taggedSkillCount;
end;

procedure TagSkillSelect(skill: Integer);
var
  insertionIndex, index: Integer;
  line1, line2: array[0..127] of AnsiChar;
  lines: array[0..0] of PAnsiChar;
begin
  old_tags := tagskl_free;

  if (skill = temp_tag_skill[0]) or (skill = temp_tag_skill[1]) or (skill = temp_tag_skill[2]) or (skill = temp_tag_skill[3]) then
  begin
    if skill = temp_tag_skill[0] then
    begin
      temp_tag_skill[0] := temp_tag_skill[1];
      temp_tag_skill[1] := temp_tag_skill[2];
      temp_tag_skill[2] := -1;
    end
    else if skill = temp_tag_skill[1] then
    begin
      temp_tag_skill[1] := temp_tag_skill[2];
      temp_tag_skill[2] := -1;
    end
    else
      temp_tag_skill[2] := -1;
  end
  else
  begin
    if tagskill_count > 0 then
    begin
      insertionIndex := 0;
      for index := 0 to 2 do
      begin
        if temp_tag_skill[index] = -1 then Break;
        Inc(insertionIndex);
      end;
      temp_tag_skill[insertionIndex] := skill;
    end
    else
    begin
      gsound_play_sfx_file('iisxxxx1');
      StrCopy(@line1[0], getmsg(@editor_message_file, @mesg, 140));
      StrCopy(@line2[0], getmsg(@editor_message_file, @mesg, 141));
      lines[0] := @line2[0];
      dialog_out(@line1[0], @lines[0], 1, 192, 126, colorTable[32328], nil, colorTable[32328], 0);
    end;
  end;

  tagskill_count := tagskl_free;
  info_line := skill + 61;
  PrintBasicStat(RENDER_ALL_STATS, False, 0);
  ListDrvdStats;
  ListSkills(2);
  DrawInfoWin;
  win_draw(edit_win);
end;

procedure ListTraits;
var
  selected_trait_line, trait_, color: Integer;
  step, y_: Double;
begin
  if not glblmode then Exit;

  selected_trait_line := -1;
  if (info_line >= 82) and (info_line < 98) then
    selected_trait_line := info_line - 82;

  buf_to_buf(bckgnd + 640 * 353 + 47, 245, 100, 640, win_buf + 640 * 353 + 47, 640);
  text_font(101);
  trait_set(temp_trait[0], temp_trait[1]);

  step := text_height() + 3 + 0.56;
  y_ := 353;
  for trait_ := 0 to 7 do
  begin
    if trait_ = selected_trait_line then
    begin
      if (trait_ <> temp_trait[0]) and (trait_ <> temp_trait[1]) then
        color := colorTable[32747]
      else
        color := colorTable[32767];
    end
    else
    begin
      if (trait_ <> temp_trait[0]) and (trait_ <> temp_trait[1]) then
        color := colorTable[992]
      else
        color := colorTable[21140];
    end;
    text_to_buf(win_buf + 640 * Trunc(y_) + 47, trait_name(trait_), 640, 640, color);
    y_ := y_ + step;
  end;

  y_ := 353;
  for trait_ := 8 to 15 do
  begin
    if trait_ = selected_trait_line then
    begin
      if (trait_ <> temp_trait[0]) and (trait_ <> temp_trait[1]) then
        color := colorTable[32747]
      else
        color := colorTable[32767];
    end
    else
    begin
      if (trait_ <> temp_trait[0]) and (trait_ <> temp_trait[1]) then
        color := colorTable[992]
      else
        color := colorTable[21140];
    end;
    text_to_buf(win_buf + 640 * Trunc(y_) + 199, trait_name(trait_), 640, 640, color);
    y_ := y_ + step;
  end;
end;

function get_trait_count: Integer;
var
  traitCount, index: Integer;
begin
  traitCount := 0;
  index := 1;
  while index >= 0 do
  begin
    if temp_trait[index] <> -1 then Break;
    Inc(traitCount);
    Dec(index);
  end;
  Result := traitCount;
end;

procedure TraitSelect(trait_: Integer);
var
  line1, line2: array[0..127] of AnsiChar;
  lines: PAnsiChar;
  index: Integer;
begin
  if (trait_ = temp_trait[0]) or (trait_ = temp_trait[1]) then
  begin
    if trait_ = temp_trait[0] then
    begin
      temp_trait[0] := temp_trait[1];
      temp_trait[1] := -1;
    end
    else
      temp_trait[1] := -1;
  end
  else
  begin
    if trait_count = 0 then
    begin
      gsound_play_sfx_file('iisxxxx1');
      StrCopy(@line1[0], getmsg(@editor_message_file, @mesg, 148));
      StrCopy(@line2[0], getmsg(@editor_message_file, @mesg, 149));
      lines := @line2[0];
      dialog_out(@line1[0], @lines, 1, 192, 126, colorTable[32328], nil, colorTable[32328], 0);
    end
    else
    begin
      for index := 0 to 1 do
      begin
        if temp_trait[index] = -1 then
        begin
          temp_trait[index] := trait_;
          Break;
        end;
      end;
    end;
  end;

  trait_count := get_trait_count;
  info_line := trait_ + EDITOR_FIRST_TRAIT;
  ListTraits;
  ListSkills(0);
  stat_recalc_derived(obj_dude);
  PrintBigNum(126, 282, 0, character_points, 0, edit_win);
  PrintBasicStat(RENDER_ALL_STATS, False, 0);
  ListDrvdStats;
  DrawInfoWin;
  win_draw(edit_win);
end;

function ListKarma: Integer;
var
  selected_karma_line, color, index, count, y: Integer;
  text_: array[0..255] of AnsiChar;
  buffer: array[0..31] of AnsiChar;
begin
  selected_karma_line := -1;
  if (info_line >= 10) and (info_line < 43) then
    selected_karma_line := info_line - 10;

  text_font(101);

  if selected_karma_line <> 0 then color := colorTable[992]
  else color := colorTable[32747];

  StrCopy(@text_[0], getmsg(@editor_message_file, @mesg, 1000));
  StrCat(@text_[0], compat_itoa(ggv(Ord(GVAR_PLAYER_REPUATION)), @buffer[0], 10));
  text_to_buf(win_buf + 640 * 362 + 34, @text_[0], 640, 640, color);

  count := 1;
  y := text_height() + 363;
  for index := 0 to 8 do
  begin
    if ggv(karma_var_table[index]) <> 0 then
    begin
      if count = selected_karma_line then color := colorTable[32747]
      else color := colorTable[992];

      text_to_buf(win_buf + 640 * y + 34,
        getmsg(@editor_message_file, @mesg, 1001 + index), 640, 640, color);
      y := y + 1 + text_height();
      Inc(count);
    end;
  end;

  Result := count;
end;

function XlateKarma(search: Integer): Integer;
var
  karma, valid_karma: Integer;
begin
  valid_karma := 0;
  for karma := 0 to 8 do
  begin
    if ggv(karma_var_table[karma]) <> 0 then
    begin
      if valid_karma = search then
      begin
        Result := karma;
        Exit;
      end;
      Inc(valid_karma);
    end;
  end;
  Result := 0;
end;

function editor_save(stream: PDB_FILE): Integer;
begin
  if db_fwriteInt(stream, last_level) = -1 then
  begin Result := -1; Exit; end;
  if db_fwriteByte(stream, free_perk) = -1 then
  begin Result := -1; Exit; end;
  Result := 0;
end;

function editor_load(stream: PDB_FILE): Integer;
begin
  if db_freadInt(stream, @last_level) = -1 then
  begin Result := -1; Exit; end;
  if db_freadByte(stream, @free_perk) = -1 then
  begin Result := -1; Exit; end;
  Result := 0;
end;

procedure editor_reset;
begin
  character_points := 5;
  last_level := 1;
end;

function UpdateLevel: Integer;
var
  level, nextLevel, sp, selectedPerksCount, progression, rc: Integer;
begin
  level := stat_pc_get(PC_STAT_LEVEL);
  if (level <> last_level) and (level <= PC_LEVEL_MAX) then
  begin
    nextLevel := last_level + 1;
    while nextLevel <= level do
    begin
      sp := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
      sp := sp + 5;
      sp := sp + stat_get_base(obj_dude, STAT_INTELLIGENCE) * 2;
      sp := sp + perk_level(PERK_EDUCATED) * 2;
      if trait_level(TRAIT_GIFTED) <> 0 then
      begin
        sp := sp - 5;
        if sp < 0 then sp := 0;
      end;
      if sp > 99 then sp := 99;
      stat_pc_set(PC_STAT_UNSPENT_SKILL_POINTS, sp);

      selectedPerksCount := PerkCount;
      if selectedPerksCount < 7 then
      begin
        progression := 3;
        if trait_level(TRAIT_SKILLED) <> 0 then Inc(progression);
        if (nextLevel mod progression) = 0 then
          free_perk := 1;
      end;
      Inc(nextLevel);
    end;
  end;

  if free_perk <> 0 then
  begin
    folder := 0;
    DrawFolder;
    win_draw(edit_win);
    rc := perks_dialog;
    if rc = -1 then
    begin
      debug_printf(PAnsiChar(#10' *** Error running perks dialog! ***'#10));
      Result := -1;
      Exit;
    end
    else if rc = 0 then
      DrawFolder
    else if rc = 1 then
    begin
      DrawFolder;
      free_perk := 0;
    end;
  end;

  last_level := level;
  Result := 1;
end;

procedure RedrwDPrks;
var
  perkRankBuffer: array[0..31] of AnsiChar;
begin
  buf_to_buf(pbckgnd + 280, 293, PERK_WINDOW_HEIGHT, PERK_WINDOW_WIDTH, pwin_buf + 280, PERK_WINDOW_WIDTH);
  ListDPerks;

  if perk_level(name_sort_list[crow + cline].value) <> 0 then
  begin
    StrLFmt(@perkRankBuffer[0], SizeOf(perkRankBuffer) - 1, '(%d)', [perk_level(name_sort_list[crow + cline].value)]);
    DrawCard2(name_sort_list[crow + cline].value + 72,
      perk_name(name_sort_list[crow + cline].value),
      @perkRankBuffer[0],
      perk_description(name_sort_list[crow + cline].value));
  end
  else
    DrawCard2(name_sort_list[crow + cline].value + 72,
      perk_name(name_sort_list[crow + cline].value),
      nil,
      perk_description(name_sort_list[crow + cline].value));

  win_draw(pwin);
end;

function perks_dialog: Integer;
var
  backgroundFrmHandle: PCacheEntry;
  backgroundWidth, backgroundHeight: Integer;
  fid, btn, count, rc: Integer;
  perkWindowX, perkWindowY: Integer;
  msg_: PAnsiChar;
  perkRankBuffer: array[0..31] of AnsiChar;
  maxHp, sp: Integer;
begin
  crow := 0;
  cline := 0;
  old_fid2 := -1;
  old_str2[0] := #0;
  frstc_draw2 := False;

  fid := art_id(OBJ_TYPE_INTERFACE, 86, 0, 0, 0);
  pbckgnd := art_lock(fid, @backgroundFrmHandle, @backgroundWidth, @backgroundHeight);
  if pbckgnd = nil then
  begin
    Result := -1;
    Exit;
  end;

  if screenGetWidth <> 640 then
    perkWindowX := (screenGetWidth - PERK_WINDOW_WIDTH) div 2
  else
    perkWindowX := PERK_WINDOW_X;
  if screenGetHeight <> 480 then
    perkWindowY := (screenGetHeight - PERK_WINDOW_HEIGHT) div 2
  else
    perkWindowY := PERK_WINDOW_Y;

  pwin := win_add(perkWindowX, perkWindowY, PERK_WINDOW_WIDTH, PERK_WINDOW_HEIGHT, 256, WINDOW_MODAL or WINDOW_DONT_MOVE_TOP);
  if pwin = -1 then
  begin
    art_ptr_unlock(backgroundFrmHandle);
    Result := -1;
    Exit;
  end;

  pwin_buf := win_get_buf(pwin);
  Move(pbckgnd^, pwin_buf^, PERK_WINDOW_WIDTH * PERK_WINDOW_HEIGHT);

  btn := win_register_button(pwin, 48, 186,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 500,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(pwin, 153, 186,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Width,
    GInfo[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP].Height,
    -1, -1, -1, 502,
    grphbmp[EDITOR_GRAPHIC_LITTLE_RED_BUTTON_UP],
    grphbmp[EDITOR_GRAPHIC_LILTTLE_RED_BUTTON_DOWN],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, @gsound_red_butt_release);

  btn := win_register_button(pwin, 25, 46,
    GInfo[EDITOR_GRAPHIC_UP_ARROW_ON].Width,
    GInfo[EDITOR_GRAPHIC_UP_ARROW_ON].Height,
    -1, 574, 572, 574,
    grphbmp[EDITOR_GRAPHIC_UP_ARROW_OFF],
    grphbmp[EDITOR_GRAPHIC_UP_ARROW_ON],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, nil);

  btn := win_register_button(pwin, 25, 47 + GInfo[EDITOR_GRAPHIC_UP_ARROW_ON].Height,
    GInfo[EDITOR_GRAPHIC_UP_ARROW_ON].Width,
    GInfo[EDITOR_GRAPHIC_UP_ARROW_ON].Height,
    -1, 575, 573, 575,
    grphbmp[EDITOR_GRAPHIC_DOWN_ARROW_OFF],
    grphbmp[EDITOR_GRAPHIC_DOWN_ARROW_ON],
    nil, BUTTON_FLAG_TRANSPARENT);
  if btn <> -1 then
    win_register_button_sound_func(btn, @gsound_red_butt_press, nil);

  win_register_button(pwin, PERK_WINDOW_LIST_X, PERK_WINDOW_LIST_Y,
    PERK_WINDOW_LIST_WIDTH, PERK_WINDOW_LIST_HEIGHT,
    -1, -1, -1, 501, nil, nil, nil, BUTTON_FLAG_TRANSPARENT);

  text_font(103);
  msg_ := getmsg(@editor_message_file, @mesg, 152);
  text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 16 + 49, msg_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[18979]);
  msg_ := getmsg(@editor_message_file, @mesg, 100);
  text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 186 + 69, msg_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[18979]);
  msg_ := getmsg(@editor_message_file, @mesg, 102);
  text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 186 + 171, msg_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[18979]);

  count := ListDPerks;

  if perk_level(name_sort_list[crow + cline].value) <> 0 then
  begin
    StrLFmt(@perkRankBuffer[0], SizeOf(perkRankBuffer) - 1, '(%d)', [perk_level(name_sort_list[crow + cline].value)]);
    DrawCard2(name_sort_list[crow + cline].value + 72,
      perk_name(name_sort_list[crow + cline].value),
      @perkRankBuffer[0],
      perk_description(name_sort_list[crow + cline].value));
  end
  else
    DrawCard2(name_sort_list[crow + cline].value + 72,
      perk_name(name_sort_list[crow + cline].value),
      nil,
      perk_description(name_sort_list[crow + cline].value));

  win_draw(pwin);

  rc := InputPDLoop(count, @RedrwDPrks);

  if rc = 1 then
  begin
    if perk_add(name_sort_list[crow + cline].value) = -1 then
    begin
      debug_printf(PAnsiChar(#10'*** Unable to add perk! ***'#10));
      rc := 2;
    end;
  end;

  rc := rc and 1;

  if rc <> 0 then
  begin
    if (perk_level(PERK_TAG) <> 0) and (perk_back[PERK_TAG] = 0) then
    begin
      if not Add4thTagSkill then
        perk_sub(PERK_TAG);
    end
    else if (perk_level(PERK_MUTATE) <> 0) and (perk_back[PERK_MUTATE] = 0) then
    begin
      if not GetMutateTrait then
        perk_sub(PERK_MUTATE);
    end
    else if perk_level(PERK_LIFEGIVER) <> perk_back[PERK_LIFEGIVER] then
    begin
      maxHp := stat_get_bonus(obj_dude, STAT_MAXIMUM_HIT_POINTS);
      stat_set_bonus(obj_dude, STAT_MAXIMUM_HIT_POINTS, maxHp + 4);
      critter_adjust_hits(obj_dude, 4);
    end
    else if perk_level(PERK_EDUCATED) <> perk_back[PERK_EDUCATED] then
    begin
      sp := stat_pc_get(PC_STAT_UNSPENT_SKILL_POINTS);
      stat_pc_set(PC_STAT_UNSPENT_SKILL_POINTS, sp + 2);
    end;
  end;

  ListSkills(0);
  PrintBasicStat(RENDER_ALL_STATS, False, 0);
  ListDrvdStats;
  DrawFolder;
  DrawInfoWin;
  win_draw(edit_win);

  art_ptr_unlock(backgroundFrmHandle);
  win_delete(pwin);

  Result := rc;
end;

function InputPDLoop(count: Integer; refreshProc: TProcedure): Integer;
var
  v3, height_, v16, v7, rc, keyCode, v19: Integer;
begin
  text_font(101);
  v3 := count - 11;
  height_ := text_height();
  oldsline := -2;
  v16 := height_ + 2;
  v7 := 0;
  rc := 0;

  while rc = 0 do
  begin
    sharedFpsLimiter.Mark;
    keyCode := get_input;
    v19 := 0;

    convertMouseWheelToArrowKey(@keyCode);

    if keyCode = 500 then
      rc := 1
    else if keyCode = KEY_RETURN then
    begin
      gsound_play_sfx_file('ib1p1xx1');
      rc := 1;
    end
    else if keyCode = 501 then
    begin
      mouseGetPositionInWindow(pwin, @mouse_xpos, @mouse_ypos);
      cline := (mouse_ypos - PERK_WINDOW_LIST_Y) div v16;
      if cline >= 0 then
      begin
        if count - 1 < cline then cline := count - 1;
      end
      else
        cline := 0;

      if cline = oldsline then
      begin
        gsound_play_sfx_file('ib1p1xx1');
        rc := 1;
      end;
      oldsline := cline;
      refreshProc;
    end
    else if (keyCode = 502) or (keyCode = KEY_ESCAPE) or (game_user_wants_to_quit <> 0) then
      rc := 2
    else
    begin
      case keyCode of
        KEY_ARROW_UP:
        begin
          oldsline := -2;
          Dec(crow);
          if crow < 0 then
          begin
            crow := 0;
            Dec(cline);
            if cline < 0 then cline := 0;
          end;
          refreshProc;
        end;
        KEY_ARROW_DOWN:
        begin
          oldsline := -2;
          if count > 11 then
          begin
            Inc(crow);
            if crow > count - 11 then
            begin
              crow := count - 11;
              Inc(cline);
              if cline > 10 then cline := 10;
            end;
          end
          else
          begin
            Inc(cline);
            if cline > count - 1 then cline := count - 1;
          end;
          refreshProc;
        end;
        572:
        begin
          repFtime := 4;
          oldsline := -2;
          v19 := 0;
          repeat
            sharedFpsLimiter.Mark;
            frame_time := get_time;
            if v19 <= 14 then Inc(v19);
            if (v19 = 1) or (v19 > 14) then
            begin
              if v19 > 14 then begin Inc(repFtime); if repFtime > 24 then repFtime := 24; end;
              Dec(crow);
              if crow < 0 then begin crow := 0; Dec(cline); if cline < 0 then cline := 0; end;
              refreshProc;
            end;
            if v19 < 14 then
            begin while elapsed_time(frame_time) < (1000 div 24) do ; end
            else
            begin while elapsed_time(frame_time) < (1000 div repFtime) do ; end;
            renderPresent;
            sharedFpsLimiter.Throttle;
          until get_input = 574;
        end;
        573:
        begin
          oldsline := -2;
          repFtime := 4;
          if count > 11 then
          begin
            v19 := 0;
            repeat
              sharedFpsLimiter.Mark;
              frame_time := get_time;
              if v19 <= 14 then Inc(v19);
              if (v19 = 1) or (v19 > 14) then
              begin
                if v19 > 14 then begin Inc(repFtime); if repFtime > 24 then repFtime := 24; end;
                Inc(crow);
                if crow > count - 11 then begin crow := count - 11; Inc(cline); if cline > 10 then cline := 10; end;
                refreshProc;
              end;
              if v19 < 14 then
              begin while elapsed_time(frame_time) < (1000 div 24) do ; end
              else
              begin while elapsed_time(frame_time) < (1000 div repFtime) do ; end;
              renderPresent;
              sharedFpsLimiter.Throttle;
            until get_input = 575;
          end
          else
          begin
            v19 := 0;
            repeat
              sharedFpsLimiter.Mark;
              frame_time := get_time;
              if v19 <= 14 then Inc(v19);
              if (v19 = 1) or (v19 > 14) then
              begin
                if v19 > 14 then begin Inc(repFtime); if repFtime > 24 then repFtime := 24; end;
                Inc(cline);
                if cline > count - 1 then cline := count - 1;
                refreshProc;
              end;
              if v19 < 14 then
              begin while elapsed_time(frame_time) < (1000 div 24) do ; end
              else
              begin while elapsed_time(frame_time) < (1000 div repFtime) do ; end;
              renderPresent;
              sharedFpsLimiter.Throttle;
            until get_input = 575;
          end;
        end;
        KEY_HOME:
        begin
          crow := 0;
          cline := 0;
          oldsline := -2;
          refreshProc;
        end;
        KEY_END:
        begin
          oldsline := -2;
          if count > 11 then
          begin
            crow := count - 11;
            cline := 10;
          end
          else
            cline := count - 1;
          refreshProc;
        end
      else
        begin
          if elapsed_time(frame_time) > 700 then
          begin
            frame_time := get_time;
            oldsline := -2;
          end;
        end;
      end;
    end;

    renderPresent;
    sharedFpsLimiter.Throttle;
  end;

  Result := rc;
end;

function ListDPerks: Integer;
var
  perks_: array[0..PERK_COUNT - 1] of Integer;
  count, perk, index, v16, y, yStep, color: Integer;
  rankString: array[0..255] of AnsiChar;
begin
  buf_to_buf(pbckgnd + PERK_WINDOW_WIDTH * 43 + 45, 192, 129, PERK_WINDOW_WIDTH,
    pwin_buf + PERK_WINDOW_WIDTH * 43 + 45, PERK_WINDOW_WIDTH);

  text_font(101);

  count := perk_make_list(@perks_[0]);
  if count = 0 then begin Result := 0; Exit; end;

  for perk := 0 to PERK_COUNT - 1 do
  begin
    name_sort_list[perk].value := 0;
    name_sort_list[perk].name := nil;
  end;

  for index := 0 to count - 1 do
  begin
    name_sort_list[index].value := perks_[index];
    name_sort_list[index].name := perk_name(perks_[index]);
  end;

  qsort(@name_sort_list[0], count, SizeOf(TEditorSortableEntry), @name_sort_comp);

  v16 := count - crow;
  if v16 > 11 then v16 := 11;
  v16 := v16 + crow;

  y := 43;
  yStep := text_height() + 2;
  for index := crow to v16 - 1 do
  begin
    if index = crow + cline then color := colorTable[32747]
    else color := colorTable[992];

    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 45, name_sort_list[index].name, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, color);

    if perk_level(name_sort_list[index].value) <> 0 then
    begin
      StrLFmt(@rankString[0], SizeOf(rankString) - 1, '(%d)', [perk_level(name_sort_list[index].value)]);
      text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 207, @rankString[0], PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, color);
    end;

    y := y + yStep;
  end;

  Result := count;
end;

procedure RedrwDMPrk;
var
  traitName_: PAnsiChar;
  traitDescription_: PAnsiChar;
  frmId: Integer;
begin
  buf_to_buf(pbckgnd + 280, 293, PERK_WINDOW_HEIGHT, PERK_WINDOW_WIDTH, pwin_buf + 280, PERK_WINDOW_WIDTH);
  ListMyTraits(optrt_count);
  traitName_ := name_sort_list[crow + cline].name;
  traitDescription_ := trait_description(name_sort_list[crow + cline].value);
  frmId := trait_pic(name_sort_list[crow + cline].value);
  DrawCard2(frmId, traitName_, nil, traitDescription_);
  win_draw(pwin);
end;

function GetMutateTrait: Boolean;
var
  result_: Boolean;
  msg_: PAnsiChar;
  rc, count: Integer;
begin
  old_fid2 := -1;
  old_str2[0] := #0;
  frstc_draw2 := False;
  trait_count := PC_TRAIT_MAX - get_trait_count;

  result_ := True;
  if trait_count >= 1 then
  begin
    text_font(103);
    buf_to_buf(pbckgnd + PERK_WINDOW_WIDTH * 14 + 49, 206, text_height() + 2, PERK_WINDOW_WIDTH, pwin_buf + PERK_WINDOW_WIDTH * 15 + 49, PERK_WINDOW_WIDTH);
    msg_ := getmsg(@editor_message_file, @mesg, 154);
    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 16 + 49, msg_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[18979]);

    optrt_count := 0;
    cline := 0;
    crow := 0;
    RedrwDMPrk;

    rc := InputPDLoop(trait_count, @RedrwDMPrk);
    if rc = 1 then
    begin
      if cline = 0 then
      begin
        if trait_count = 1 then
        begin
          temp_trait[0] := -1;
          temp_trait[1] := -1;
        end
        else
        begin
          if name_sort_list[0].value = temp_trait[0] then
          begin
            temp_trait[0] := temp_trait[1];
            temp_trait[1] := -1;
          end
          else
            temp_trait[1] := -1;
        end;
      end
      else
      begin
        if name_sort_list[0].value = temp_trait[0] then
          temp_trait[1] := -1
        else
        begin
          temp_trait[0] := temp_trait[1];
          temp_trait[1] := -1;
        end;
      end;
    end
    else
      result_ := False;
  end;

  if result_ then
  begin
    text_font(103);
    buf_to_buf(pbckgnd + PERK_WINDOW_WIDTH * 14 + 49, 206, text_height() + 2, PERK_WINDOW_WIDTH, pwin_buf + PERK_WINDOW_WIDTH * 15 + 49, PERK_WINDOW_WIDTH);
    msg_ := getmsg(@editor_message_file, @mesg, 153);
    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 16 + 49, msg_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[18979]);

    cline := 0;
    crow := 0;
    optrt_count := 1;
    RedrwDMPrk;

    count := 16 - trait_count;
    if count > 16 then count := 16;

    rc := InputPDLoop(count, @RedrwDMPrk);
    if rc = 1 then
    begin
      if trait_count <> 0 then
        temp_trait[1] := name_sort_list[cline + crow].value
      else
      begin
        temp_trait[0] := name_sort_list[cline + crow].value;
        temp_trait[1] := -1;
      end;
      trait_set(temp_trait[0], temp_trait[1]);
    end
    else
      result_ := False;
  end;

  if not result_ then
    Move(trait_back, temp_trait, SizeOf(temp_trait));

  Result := result_;
end;

procedure RedrwDMTagSkl;
var
  name_: PAnsiChar;
  description: PAnsiChar;
  frmId: Integer;
begin
  buf_to_buf(pbckgnd + 280, 293, PERK_WINDOW_HEIGHT, PERK_WINDOW_WIDTH, pwin_buf + 280, PERK_WINDOW_WIDTH);
  ListNewTagSkills;
  name_ := name_sort_list[crow + cline].name;
  description := skill_description(name_sort_list[crow + cline].value);
  frmId := skill_pic(name_sort_list[crow + cline].value);
  DrawCard2(frmId, name_, nil, description);
  win_draw(pwin);
end;

function Add4thTagSkill: Boolean;
var
  messageListItemText: PAnsiChar;
  rc: Integer;
begin
  text_font(103);
  buf_to_buf(pbckgnd + 573 * 14 + 49, 206, text_height() + 2, 573, pwin_buf + 573 * 15 + 49, 573);

  messageListItemText := getmsg(@editor_message_file, @mesg, 155);
  text_to_buf(pwin_buf + 573 * 16 + 49, messageListItemText, 573, 573, colorTable[18979]);

  cline := 0;
  crow := 0;
  old_fid2 := -1;
  old_str2[0] := #0;
  frstc_draw2 := False;
  RedrwDMTagSkl;

  rc := InputPDLoop(optrt_count, @RedrwDMTagSkl);
  if rc <> 1 then
  begin
    Move(tag_skill_back, temp_tag_skill, SizeOf(temp_tag_skill));
    skill_set_tags(@tag_skill_back[0], NUM_TAGGED_SKILLS);
    Result := False;
    Exit;
  end;

  temp_tag_skill[3] := name_sort_list[crow + cline].value;
  skill_set_tags(@temp_tag_skill[0], NUM_TAGGED_SKILLS);
  Result := True;
end;

procedure ListNewTagSkills;
var
  skill, y, yStep, index, color: Integer;
begin
  buf_to_buf(pbckgnd + PERK_WINDOW_WIDTH * 43 + 45, 192, 129, PERK_WINDOW_WIDTH, pwin_buf + PERK_WINDOW_WIDTH * 43 + 45, PERK_WINDOW_WIDTH);
  text_font(101);

  optrt_count := 0;
  y := 43;
  yStep := text_height() + 2;

  for skill := 0 to SKILL_COUNT - 1 do
  begin
    if (skill <> temp_tag_skill[0]) and (skill <> temp_tag_skill[1]) and (skill <> temp_tag_skill[2]) and (skill <> temp_tag_skill[3]) then
    begin
      name_sort_list[optrt_count].value := skill;
      name_sort_list[optrt_count].name := skill_name(skill);
      Inc(optrt_count);
    end;
  end;

  qsort(@name_sort_list[0], optrt_count, SizeOf(TEditorSortableEntry), @name_sort_comp);

  for index := crow to crow + 10 do
  begin
    if index = cline + crow then color := colorTable[32747]
    else color := colorTable[992];
    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 45, name_sort_list[index].name, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, color);
    y := y + yStep;
  end;
end;

function ListMyTraits(a1: Integer): Integer;
var
  y, yStep, count, index, color, trait_: Integer;
begin
  buf_to_buf(pbckgnd + PERK_WINDOW_WIDTH * 43 + 45, 192, 129, PERK_WINDOW_WIDTH, pwin_buf + PERK_WINDOW_WIDTH * 43 + 45, PERK_WINDOW_WIDTH);
  text_font(101);

  y := 43;
  yStep := text_height() + 2;

  if a1 <> 0 then
  begin
    count := 0;
    for trait_ := 0 to TRAIT_COUNT - 1 do
    begin
      if (trait_ <> trait_back[0]) and (trait_ <> trait_back[1]) then
      begin
        name_sort_list[count].value := trait_;
        name_sort_list[count].name := trait_name(trait_);
        Inc(count);
      end;
    end;

    qsort(@name_sort_list[0], count, SizeOf(TEditorSortableEntry), @name_sort_comp);

    for index := crow to crow + 10 do
    begin
      if index = cline + crow then color := colorTable[32747]
      else color := colorTable[992];
      text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 45, name_sort_list[index].name, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, color);
      y := y + yStep;
    end;
  end
  else
  begin
    for index := 0 to PC_TRAIT_MAX - 1 do
    begin
      name_sort_list[index].value := temp_trait[index];
      name_sort_list[index].name := trait_name(temp_trait[index]);
    end;

    if trait_count > 1 then
      qsort(@name_sort_list[0], trait_count, SizeOf(TEditorSortableEntry), @name_sort_comp);

    for index := 0 to trait_count - 1 do
    begin
      if index = cline then color := colorTable[32747]
      else color := colorTable[992];
      text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 45, name_sort_list[index].name, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, color);
      y := y + yStep;
    end;
  end;

  Result := 0;
end;

function name_sort_comp(a1, a2: Pointer): Integer;
var
  v1, v2: PEditorSortableEntry;
begin
  v1 := PEditorSortableEntry(a1);
  v2 := PEditorSortableEntry(a2);
  Result := strcmp(v1^.name, v2^.name);
end;

function DrawCard2(frmId: Integer; const name_: PAnsiChar; const rank: PAnsiChar; description: PAnsiChar): Integer;
var
  fid: Integer;
  handle: PCacheEntry;
  width_, height_: Integer;
  data_: PByte;
  extraDescriptionWidth: Integer;
  y, x: Integer;
  stride: PByte;
  nameHeight, rankX, rankHeight, yStep: Integer;
  beginnings: array[0..WORD_WRAP_MAX_COUNT - 1] of SmallInt;
  count: SmallInt;
  index: Integer;
  ch: AnsiChar;
  beginning_: PAnsiChar;
  ending_: PAnsiChar;
begin
  fid := art_id(OBJ_TYPE_SKILLDEX, frmId, 0, 0, 0);
  data_ := art_lock(fid, @handle, @width_, @height_);
  if data_ = nil then begin Result := -1; Exit; end;

  buf_to_buf(data_, width_, height_, width_, pwin_buf + PERK_WINDOW_WIDTH * 64 + 413, PERK_WINDOW_WIDTH);

  extraDescriptionWidth := 150;
  for y := 0 to height_ - 1 do
  begin
    stride := data_ + y * width_;
    for x := 0 to width_ - 1 do
    begin
      if HighRGB(stride^) < 2 then
      begin
        if extraDescriptionWidth > x then
          extraDescriptionWidth := x;
      end;
      Inc(stride);
    end;
  end;

  Dec(extraDescriptionWidth, 8);
  if extraDescriptionWidth < 0 then extraDescriptionWidth := 0;

  text_font(102);
  nameHeight := text_height();
  text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * 27 + 280, name_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[0]);

  if rank <> nil then
  begin
    rankX := text_width(name_) + 280 + 8;
    text_font(101);
    rankHeight := text_height();
    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * (23 + nameHeight - rankHeight) + rankX, rank, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[0]);
  end;

  win_line(pwin, 280, 27 + nameHeight, 545, 27 + nameHeight, colorTable[0]);
  win_line(pwin, 280, 28 + nameHeight, 545, 28 + nameHeight, colorTable[0]);

  text_font(101);
  yStep := text_height() + 1;
  y := 70;

  if word_wrap(description, 133 + extraDescriptionWidth, @beginnings[0], @count) <> 0 then
  begin
    Result := -1;
    Exit;
  end;

  for index := 0 to count - 2 do
  begin
    beginning_ := description + beginnings[index];
    ending_ := description + beginnings[index + 1];
    ch := ending_^;
    ending_^ := #0;
    text_to_buf(pwin_buf + PERK_WINDOW_WIDTH * y + 280, beginning_, PERK_WINDOW_WIDTH, PERK_WINDOW_WIDTH, colorTable[0]);
    ending_^ := ch;
    y := y + yStep;
  end;

  if (frmId <> old_fid2) or (strcmp(@old_str2[0], name_) <> 0) then
  begin
    if frstc_draw2 then
      gsound_play_sfx_file('isdxxxx1');
  end;

  StrCopy(@old_str2[0], name_);
  old_fid2 := frmId;
  frstc_draw2 := True;

  art_ptr_unlock(handle);
  Result := 0;
end;

procedure push_perks;
var
  perk: Integer;
begin
  for perk := 0 to PERK_COUNT - 1 do
    perk_back[perk] := perk_level(perk);
end;

procedure pop_perks;
var
  perk: Integer;
begin
  for perk := 0 to PERK_COUNT - 1 do
  begin
    while perk_level(perk) > perk_back[perk] do
      perk_sub(perk);
  end;

  for perk := 0 to PERK_COUNT - 1 do
  begin
    while perk_level(perk) < perk_back[perk] do
      perk_add(perk);
  end;
end;

function PerkCount: Integer;
var
  perk, perkCount_: Integer;
begin
  perkCount_ := 0;
  for perk := 0 to PERK_COUNT - 1 do
  begin
    if perk_level(perk) > 0 then
    begin
      Inc(perkCount_);
      if perkCount_ >= 7 then Break;
    end;
  end;
  Result := perkCount_;
end;

function is_supper_bonus: Integer;
var
  stat, v1, v2: Integer;
begin
  for stat := 0 to 6 do
  begin
    v1 := stat_get_base(obj_dude, stat);
    v2 := stat_get_bonus(obj_dude, stat);
    if v1 + v2 > 10 then
    begin
      Result := 1;
      Exit;
    end;
  end;
  Result := 0;
end;

initialization
  character_points := 0;
  FillChar(byte_431D93, SizeOf(byte_431D93), 0);

end.
