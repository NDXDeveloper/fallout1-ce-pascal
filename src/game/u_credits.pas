{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}
// Converted from: src/game/credits.h + credits.cc
// Credits screen: scrolling text display over background image.
unit u_credits;

interface

procedure credits(filePath: PAnsiChar; backgroundFid: Integer; useReversedStyle: Boolean);

implementation

uses
  SysUtils,
  u_cache,
  u_db,
  u_art,
  u_color,
  u_gconfig,
  u_config,
  u_message,
  u_palette,
  u_platform_compat,
  u_grbuf,
  u_gnw,
  u_input,
  u_mouse,
  u_text,
  u_svga,
  u_fps_limiter,
  u_memory,
  u_object_types,
  u_cycle,
  u_gmouse,
  u_int_sound;

const
  CREDITS_WINDOW_SCROLLING_DELAY = 38;
  MOUSE_CURSOR_NONE  = 0;
  MOUSE_CURSOR_ARROW = 1;

// Forward declaration
function credits_get_next_line(dest: PAnsiChar; font: PInteger; color: PInteger): Boolean; forward;

// Module-level implementation variables (from C static)
var
  credits_file: PDB_FILE;
  name_color: Integer;
  title_font: Integer;
  name_font: Integer;
  title_color: Integer;

// 0x426FE0
procedure credits(filePath: PAnsiChar; backgroundFid: Integer; useReversedStyle: Boolean);
var
  oldFont: Integer;
  localizedPath: array[0..COMPAT_MAX_PATH - 1] of AnsiChar;
  cursorWasHidden: Boolean;
  windowWidth, windowHeight: Integer;
  window: Integer;
  windowBuffer: PByte;
  backgroundBuffer: PByte;
  backgroundFrmHandle: PCacheEntry;
  frm: PArt;
  width, height: Integer;
  backgroundFrmData: PByte;
  intermediateBuffer: PByte;
  titleFontLineHeight: Integer;
  nameFontLineHeight: Integer;
  lineHeight: Integer;
  stringBufferSize: Integer;
  stringBuffer: PByte;
  boom: PAnsiChar;
  exploding_head_frame: Integer;
  exploding_head_cycle: Integer;
  violence_level: Integer;
  str: array[0..259] of AnsiChar;
  font: Integer;
  color: Integer;
  tick: LongWord;
  stop: Boolean;
  v19: Integer;
  dest: PByte;
  src: PByte;
  idx: Integer;
  inputVal: Integer;
  exploding_head_key: PCacheEntry;
  exploding_head_fid: Integer;
  exploding_head_frm: PArt;
  ehWidth, ehHeight: Integer;
  logoData: PByte;
begin
  oldFont := text_curr();

  loadColorTable('color.pal');

  if useReversedStyle then
  begin
    title_color := colorTable[18917];
    name_font := 103;
    title_font := 104;
    name_color := colorTable[13673];
  end
  else
  begin
    title_color := colorTable[13673];
    name_font := 104;
    title_font := 103;
    name_color := colorTable[18917];
  end;

  soundUpdate();

  if message_make_path(@localizedPath[0], SizeOf(localizedPath), filePath) then
  begin
    credits_file := db_fopen(@localizedPath[0], 'rt');
    if credits_file <> nil then
    begin
      soundUpdate();

      cycle_disable();
      gmouse_set_cursor(MOUSE_CURSOR_NONE);

      cursorWasHidden := mouse_hidden();
      if cursorWasHidden then
        mouse_show();

      windowWidth := screenGetWidth();
      windowHeight := screenGetHeight();
      window := win_add(0, 0, windowWidth, windowHeight, colorTable[0], 20);
      soundUpdate();

      if window <> -1 then
      begin
        windowBuffer := win_get_buf(window);
        if windowBuffer <> nil then
        begin
          backgroundBuffer := PByte(mem_malloc(windowWidth * windowHeight));
          if backgroundBuffer <> nil then
          begin
            soundUpdate();

            FillChar(backgroundBuffer^, windowWidth * windowHeight, colorTable[0]);

            if backgroundFid <> -1 then
            begin
              frm := art_ptr_lock(backgroundFid, @backgroundFrmHandle);
              if frm <> nil then
              begin
                width := art_frame_width(frm, 0, 0);
                height := art_frame_length(frm, 0, 0);
                backgroundFrmData := art_frame_data(frm, 0, 0);
                buf_to_buf(backgroundFrmData,
                  width,
                  height,
                  width,
                  backgroundBuffer + windowWidth * ((windowHeight - height) div 2) + (windowWidth - width) div 2,
                  windowWidth);
                art_ptr_unlock(backgroundFrmHandle);
              end;
            end;

            intermediateBuffer := PByte(mem_malloc(windowWidth * windowHeight));
            if intermediateBuffer <> nil then
            begin
              FillChar(intermediateBuffer^, windowWidth * windowHeight, 0);

              text_font(title_font);
              titleFontLineHeight := text_height();

              text_font(name_font);
              nameFontLineHeight := text_height();

              if titleFontLineHeight >= nameFontLineHeight then
                lineHeight := nameFontLineHeight + (titleFontLineHeight - nameFontLineHeight)
              else
                lineHeight := nameFontLineHeight;
              stringBufferSize := windowWidth * lineHeight;
              stringBuffer := PByte(mem_malloc(stringBufferSize));
              if stringBuffer <> nil then
              begin
                boom := 'boom';
                exploding_head_frame := 0;
                exploding_head_cycle := 0;
                violence_level := 0;

                config_get_value(@game_config, GAME_CONFIG_PREFERENCES_KEY, GAME_CONFIG_VIOLENCE_LEVEL_KEY, @violence_level);

                buf_to_buf(backgroundBuffer,
                  windowWidth,
                  windowHeight,
                  windowWidth,
                  windowBuffer,
                  windowWidth);

                win_draw(window);

                palette_fade_to(@cmap[0]);

                tick := 0;
                stop := False;

                while credits_get_next_line(@str[0], @font, @color) do
                begin
                  text_font(font);

                  v19 := text_width(@str[0]);
                  if v19 >= windowWidth then
                    Continue;

                  FillChar(stringBuffer^, stringBufferSize, 0);
                  text_to_buf(stringBuffer, @str[0], windowWidth, windowWidth, color);

                  dest := intermediateBuffer + windowWidth * windowHeight - windowWidth + (windowWidth - v19) div 2;
                  src := stringBuffer;

                  idx := 0;
                  while idx < lineHeight do
                  begin
                    if sharedFpsLimiter <> nil then
                      sharedFpsLimiter.Mark;

                    inputVal := get_input();
                    if inputVal <> -1 then
                    begin
                      if inputVal <> Ord(boom^) then
                      begin
                        stop := True;
                        Break;
                      end;

                      Inc(boom);
                      if boom^ = #0 then
                      begin
                        exploding_head_frame := 1;
                        boom := 'boom';
                      end;
                    end;

                    Move((intermediateBuffer + windowWidth)^, intermediateBuffer^, windowWidth * windowHeight - windowWidth);
                    Move(src^, dest^, v19);

                    buf_to_buf(backgroundBuffer,
                      windowWidth,
                      windowHeight,
                      windowWidth,
                      windowBuffer,
                      windowWidth);

                    trans_buf_to_buf(intermediateBuffer,
                      windowWidth,
                      windowHeight,
                      windowWidth,
                      windowBuffer,
                      windowWidth);

                    if violence_level <> VIOLENCE_LEVEL_NONE then
                    begin
                      if exploding_head_frame <> 0 then
                      begin
                        exploding_head_fid := art_id(OBJ_TYPE_INTERFACE, 39, 0, 0, 0);
                        exploding_head_frm := art_ptr_lock(exploding_head_fid, @exploding_head_key);
                        if (exploding_head_frm <> nil) and (exploding_head_frame - 1 < art_frame_max_frame(exploding_head_frm)) then
                        begin
                          ehWidth := art_frame_width(exploding_head_frm, exploding_head_frame - 1, 0);
                          ehHeight := art_frame_length(exploding_head_frm, exploding_head_frame - 1, 0);
                          logoData := art_frame_data(exploding_head_frm, exploding_head_frame - 1, 0);
                          trans_buf_to_buf(logoData,
                            ehWidth,
                            ehHeight,
                            ehWidth,
                            windowBuffer + windowWidth * (windowHeight - ehHeight) + (windowWidth - ehWidth) div 2,
                            windowWidth);
                          art_ptr_unlock(exploding_head_key);

                          if exploding_head_cycle <> 0 then
                            Inc(exploding_head_frame);

                          exploding_head_cycle := 1 - exploding_head_cycle;
                        end
                        else
                        begin
                          exploding_head_frame := 0;
                        end;
                      end;
                    end;

                    while elapsed_time(tick) < CREDITS_WINDOW_SCROLLING_DELAY do
                      { busy wait };

                    tick := get_time();

                    win_draw(window);

                    Inc(src, windowWidth);

                    if sharedFpsLimiter <> nil then
                      sharedFpsLimiter.Throttle;
                    renderPresent();

                    Inc(idx);
                  end;

                  if stop then
                    Break;
                end;

                if not stop then
                begin
                  idx := 0;
                  while idx < windowHeight do
                  begin
                    if sharedFpsLimiter <> nil then
                      sharedFpsLimiter.Mark;

                    if get_input() <> -1 then
                      Break;

                    Move((intermediateBuffer + windowWidth)^, intermediateBuffer^, windowWidth * windowHeight - windowWidth);
                    FillChar((intermediateBuffer + windowWidth * windowHeight - windowWidth)^, windowWidth, 0);

                    buf_to_buf(backgroundBuffer,
                      windowWidth,
                      windowHeight,
                      windowWidth,
                      windowBuffer,
                      windowWidth);

                    trans_buf_to_buf(intermediateBuffer,
                      windowWidth,
                      windowHeight,
                      windowWidth,
                      windowBuffer,
                      windowWidth);

                    while elapsed_time(tick) < CREDITS_WINDOW_SCROLLING_DELAY do
                      { busy wait };

                    tick := get_time();

                    win_draw(window);

                    if sharedFpsLimiter <> nil then
                      sharedFpsLimiter.Throttle;
                    renderPresent();

                    Inc(idx);
                  end;
                end;

                mem_free(stringBuffer);
              end;
              mem_free(intermediateBuffer);
            end;
            mem_free(backgroundBuffer);
          end;
        end;

        soundUpdate();
        palette_fade_to(@black_palette[0]);
        soundUpdate();
        win_delete(window);
      end;

      if cursorWasHidden then
        mouse_hide();

      gmouse_set_cursor(MOUSE_CURSOR_ARROW);
      cycle_enable();
      db_fclose(credits_file);
    end;
  end;

  text_font(oldFont);
end;

// 0x42777C
function credits_get_next_line(dest: PAnsiChar; font: PInteger; color: PInteger): Boolean;
var
  str: array[0..255] of AnsiChar;
  pch: PAnsiChar;
begin
  while db_fgets(@str[0], 256, credits_file) <> nil do
  begin
    if str[0] = ';' then
      Continue
    else if str[0] = '@' then
    begin
      font^ := title_font;
      color^ := title_color;
      pch := @str[1];
    end
    else if str[0] = '#' then
    begin
      font^ := name_font;
      color^ := colorTable[17969];
      pch := @str[1];
    end
    else
    begin
      font^ := name_font;
      color^ := name_color;
      pch := @str[0];
    end;

    StrCopy(dest, pch);

    Exit(True);
  end;

  Result := False;
end;

end.
