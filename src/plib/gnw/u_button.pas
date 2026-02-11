{$MODE OBJFPC}{$H+}
// Converted from: src/plib/gnw/button.h + button.cc
// Button registration, management, and event processing.
unit u_button;

interface

uses
  u_rect, u_gnw_types;

function win_register_button(win, x, y, width, height: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  up, dn, hover: PByte; flags: Integer): Integer;
function win_register_text_button(win, x, y: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  title: PAnsiChar; flags: Integer): Integer;
function win_register_button_disable(btn: Integer; up, down, hover: PByte): Integer;
function win_register_button_image(btn: Integer; up, down, hover: PByte; draw: Boolean): Integer;
function win_register_button_func(btn: Integer;
  mouseEnterProc, mouseExitProc, mouseDownProc, mouseUpProc: TButtonCallback): Integer;
function win_register_right_button(btn, rightMouseDownEventCode, rightMouseUpEventCode: Integer;
  rightMouseDownProc, rightMouseUpProc: TButtonCallback): Integer;
function win_register_button_sound_func(btn: Integer;
  pressSoundFunc, releaseSoundFunc: TButtonCallback): Integer;
function win_register_button_mask(btn: Integer; mask: PByte): Integer;
function win_button_down(btn: Integer): Boolean;
function GNW_check_buttons(window: PWindow; keyCodePtr: PInteger): Integer;
function win_button_winID(btn: Integer): Integer;
function win_last_button_winID: Integer;
function win_delete_button(btn: Integer): Integer;
procedure GNW_delete_button(ptr: PButton);
procedure win_delete_button_win(btn, inputEvent: Integer);
function button_new_id: Integer;
function win_enable_button(btn: Integer): Integer;
function win_disable_button(btn: Integer): Integer;
function win_set_button_rest_state(btn: Integer; checked: Boolean; flags: Integer): Integer;
function win_group_check_buttons(buttonCount: Integer; btns: PInteger;
  maxChecked: Integer; func: TRadioButtonCallback): Integer;
function win_group_radio_buttons(buttonCount: Integer; btns: PInteger): Integer;
procedure GNW_button_refresh(window: PWindow; rect: PRect);
function win_button_press_and_release(btn: Integer): Integer;

implementation

uses
  u_memory, u_gnw, u_color, u_text, u_grbuf, u_mouse, u_input;

const
  BUTTON_GROUP_LIST_CAPACITY = 64;

var
  last_button_winID_: Integer = -1;
  btn_grp: array[0..BUTTON_GROUP_LIST_CAPACITY - 1] of TButtonGroup;

// Forward declarations for static helpers
function button_create(win, x, y, width, height: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  flags: Integer; up, dn, hover: PByte): PButton; forward;
function button_under_mouse(button: PButton; rect: PRect): Boolean; forward;
function button_check_group(button: PButton): Integer; forward;
procedure button_draw(button: PButton; w: PWindow; data: PByte; doDraw: Boolean;
  bound: PRect; sound: Boolean); forward;

// 0x4C5510
function button_new_id: Integer;
var
  btn: Integer;
begin
  btn := 1;
  while GNW_find_button(btn, nil) <> nil do
    Inc(btn);
  Result := btn;
end;

// 0x4C4320
function win_register_button(win, x, y, width, height: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  up, dn, hover: PByte; flags: Integer): Integer;
var
  w: PWindow;
  button: PButton;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(-1);

  if w = nil then
    Exit(-1);

  if (up = nil) and ((dn <> nil) or (hover <> nil)) then
    Exit(-1);

  button := button_create(win, x, y, width, height,
    mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode,
    flags or BUTTON_FLAG_GRAPHIC, up, dn, hover);
  if button = nil then
    Exit(-1);

  button_draw(button, w, button^.NormalImage, False, nil, False);

  Result := button^.Id;
end;

// 0x4C43C8
function win_register_text_button(win, x, y: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  title: PAnsiChar; flags: Integer): Integer;
var
  w: PWindow;
  buttonWidth, buttonHeight: Integer;
  normal, pressed: PByte;
  button: PButton;
begin
  w := GNW_find(win);

  if not GNW_win_init_flag then
    Exit(-1);

  if w = nil then
    Exit(-1);

  buttonWidth := text_width(title) + 16;
  buttonHeight := text_height() + 7;

  normal := PByte(mem_malloc(buttonWidth * buttonHeight));
  if normal = nil then
    Exit(-1);

  pressed := PByte(mem_malloc(buttonWidth * buttonHeight));
  if pressed = nil then
  begin
    mem_free(normal);
    Exit(-1);
  end;

  if (w^.Color = 256) and (GNW_texture <> nil) then
  begin
    // TODO: Incomplete in original C++ too.
  end
  else
  begin
    buf_fill(normal, buttonWidth, buttonHeight, buttonWidth, w^.Color);
    buf_fill(pressed, buttonWidth, buttonHeight, buttonWidth, w^.Color);
  end;

  lighten_buf(normal, buttonWidth, buttonHeight, buttonWidth);

  text_to_buf(normal + buttonWidth * 3 + 8, title, buttonWidth, buttonWidth,
    colorTable[GNW_wcolor[3]]);
  draw_shaded_box(normal, buttonWidth, 2, 2,
    buttonWidth - 3, buttonHeight - 3,
    colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);
  draw_shaded_box(normal, buttonWidth, 1, 1,
    buttonWidth - 2, buttonHeight - 2,
    colorTable[GNW_wcolor[1]], colorTable[GNW_wcolor[2]]);
  draw_box(normal, buttonWidth, 0, 0, buttonWidth - 1, buttonHeight - 1,
    colorTable[0]);

  text_to_buf(pressed + buttonWidth * 4 + 9, title, buttonWidth, buttonWidth,
    colorTable[GNW_wcolor[3]]);
  draw_shaded_box(pressed, buttonWidth, 2, 2,
    buttonWidth - 3, buttonHeight - 3,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);
  draw_shaded_box(pressed, buttonWidth, 1, 1,
    buttonWidth - 2, buttonHeight - 2,
    colorTable[GNW_wcolor[2]], colorTable[GNW_wcolor[1]]);
  draw_box(pressed, buttonWidth, 0, 0, buttonWidth - 1, buttonHeight - 1,
    colorTable[0]);

  button := button_create(win, x, y, buttonWidth, buttonHeight,
    mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode,
    flags, normal, pressed, nil);
  if button = nil then
  begin
    mem_free(normal);
    mem_free(pressed);
    Exit(-1);
  end;

  button_draw(button, w, button^.NormalImage, False, nil, False);

  Result := button^.Id;
end;

// 0x4C4734
function win_register_button_disable(btn: Integer; up, down, hover: PByte): Integer;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(-1);

  button^.DisabledNormalImage := up;
  button^.DisabledPressedImage := down;
  button^.DisabledHoverImage := hover;

  Result := 0;
end;

// 0x4C4768
function win_register_button_image(btn: Integer; up, down, hover: PByte; draw: Boolean): Integer;
var
  w: PWindow;
  button: PButton;
  data: PByte;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  if (up = nil) and ((down <> nil) or (hover <> nil)) then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  if (button^.Flags and BUTTON_FLAG_GRAPHIC) = 0 then
    Exit(-1);

  data := button^.CurrentImage;
  if data = button^.NormalImage then
    button^.CurrentImage := up
  else if data = button^.PressedImage then
    button^.CurrentImage := down
  else if data = button^.HoverImage then
    button^.CurrentImage := hover;

  button^.NormalImage := up;
  button^.PressedImage := down;
  button^.HoverImage := hover;

  button_draw(button, w, button^.CurrentImage, draw, nil, False);

  Result := 0;
end;

// 0x4C4810
function win_register_button_func(btn: Integer;
  mouseEnterProc, mouseExitProc, mouseDownProc, mouseUpProc: TButtonCallback): Integer;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(-1);

  button^.MouseEnterProc := mouseEnterProc;
  button^.MouseExitProc := mouseExitProc;
  button^.LeftMouseDownProc := mouseDownProc;
  button^.LeftMouseUpProc := mouseUpProc;

  Result := 0;
end;

// 0x4C4850
function win_register_right_button(btn, rightMouseDownEventCode, rightMouseUpEventCode: Integer;
  rightMouseDownProc, rightMouseUpProc: TButtonCallback): Integer;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(-1);

  button^.RightMouseDownEventCode := rightMouseDownEventCode;
  button^.RightMouseUpEventCode := rightMouseUpEventCode;
  button^.RightMouseDownProc := rightMouseDownProc;
  button^.RightMouseUpProc := rightMouseUpProc;

  if (rightMouseDownEventCode <> -1) or (rightMouseUpEventCode <> -1) or
     Assigned(rightMouseDownProc) or Assigned(rightMouseUpProc) then
    button^.Flags := button^.Flags or BUTTON_FLAG_RIGHT_MOUSE_BUTTON_CONFIGURED
  else
    button^.Flags := button^.Flags and (not BUTTON_FLAG_RIGHT_MOUSE_BUTTON_CONFIGURED);

  Result := 0;
end;

// 0x4C48B0
function win_register_button_sound_func(btn: Integer;
  pressSoundFunc, releaseSoundFunc: TButtonCallback): Integer;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(-1);

  button^.PressSoundFunc := pressSoundFunc;
  button^.ReleaseSoundFunc := releaseSoundFunc;

  Result := 0;
end;

// 0x4C48E0
function win_register_button_mask(btn: Integer; mask: PByte): Integer;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(-1);

  button^.Mask := mask;

  Result := 0;
end;

// 0x4C490C
function button_create(win, x, y, width, height: Integer;
  mouseEnterEventCode, mouseExitEventCode, mouseDownEventCode, mouseUpEventCode: Integer;
  flags: Integer; up, dn, hover: PByte): PButton;
var
  w: PWindow;
  button: PButton;
  buttonId: Integer;
begin
  w := GNW_find(win);
  if w = nil then
    Exit(nil);

  button := PButton(mem_malloc(SizeOf(TButton)));
  if button = nil then
    Exit(nil);

  if (flags and BUTTON_FLAG_0x01) = 0 then
  begin
    if (flags and BUTTON_FLAG_0x02) <> 0 then
      flags := flags and (not BUTTON_FLAG_0x02);

    if (flags and BUTTON_FLAG_0x04) <> 0 then
      flags := flags and (not BUTTON_FLAG_0x04);
  end;

  // NOTE: Uninline.
  buttonId := button_new_id;

  button^.Id := buttonId;
  button^.Flags := flags;
  button^.Rect.ulx := x;
  button^.Rect.uly := y;
  button^.Rect.lrx := x + width - 1;
  button^.Rect.lry := y + height - 1;
  button^.MouseEnterEventCode := mouseEnterEventCode;
  button^.MouseExitEventCode := mouseExitEventCode;
  button^.LeftMouseDownEventCode := mouseDownEventCode;
  button^.LeftMouseUpEventCode := mouseUpEventCode;
  button^.RightMouseDownEventCode := -1;
  button^.RightMouseUpEventCode := -1;
  button^.NormalImage := up;
  button^.PressedImage := dn;
  button^.HoverImage := hover;
  button^.DisabledNormalImage := nil;
  button^.DisabledPressedImage := nil;
  button^.DisabledHoverImage := nil;
  button^.CurrentImage := nil;
  button^.Mask := nil;
  button^.MouseEnterProc := nil;
  button^.MouseExitProc := nil;
  button^.LeftMouseDownProc := nil;
  button^.LeftMouseUpProc := nil;
  button^.RightMouseDownProc := nil;
  button^.RightMouseUpProc := nil;
  button^.PressSoundFunc := nil;
  button^.ReleaseSoundFunc := nil;
  button^.ButtonGroup_ := nil;
  button^.Prev := nil;

  button^.Next := w^.ButtonListHead;
  if button^.Next <> nil then
    button^.Next^.Prev := button;
  w^.ButtonListHead := button;

  WriteLn(StdErr, '[REG] btn=', button^.Id, ' rect=', x, ',', y, '-', x+width-1, ',', y+height-1, ' down=', mouseDownEventCode, ' up=', mouseUpEventCode);

  Result := button;
end;

// 0x4C4A9C
function win_button_down(btn: Integer): Boolean;
var
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(False);

  button := GNW_find_button(btn, nil);
  if button = nil then
    Exit(False);

  if ((button^.Flags and BUTTON_FLAG_0x01) <> 0) and
     ((button^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
    Exit(True);

  Result := False;
end;

// 0x4C4AC8
function GNW_check_buttons(window: PWindow; keyCodePtr: PInteger): Integer;
var
  v58: TRect;
  hoveredButton: PButton;
  clickedButton: PButton;
  button: PButton;
  mouseEvent: Integer;
  v25: Integer;
  v26: PWindow;
  v28: PButton;
  cb: TButtonCallback;
  v49: PButton;
begin
  if (window^.Flags and WINDOW_HIDDEN) <> 0 then
    Exit(-1);

  mouseEvent := mouse_get_buttons;

  button := window^.ButtonListHead;
  hoveredButton := window^.HoveredButton;
  clickedButton := window^.ClickedButton;

  if hoveredButton <> nil then
  begin
    rectCopy(@v58, @hoveredButton^.Rect);
    rectOffset(@v58, window^.Rect.ulx, window^.Rect.uly);
  end
  else if clickedButton <> nil then
  begin
    rectCopy(@v58, @clickedButton^.Rect);
    rectOffset(@v58, window^.Rect.ulx, window^.Rect.uly);
  end;

  keyCodePtr^ := -1;

  if mouse_click_in(window^.Rect.ulx, window^.Rect.uly,
                     window^.Rect.lrx, window^.Rect.lry) then
  begin
    mouseEvent := mouse_get_buttons;
    if (window^.Flags and WINDOW_FLAG_0x40) <> 0 then
    begin
      // do nothing - no auto-show
    end
    else if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
    begin
      win_show(window^.Id);
    end;

    if mouseEvent = 0 then
      window^.ClickedButton := nil;

    if hoveredButton <> nil then
    begin
      if not button_under_mouse(hoveredButton, @v58) then
      begin
        if (hoveredButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
          keyCodePtr^ := hoveredButton^.MouseExitEventCode;

        if ((hoveredButton^.Flags and BUTTON_FLAG_0x01) <> 0) and
           ((hoveredButton^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
          button_draw(hoveredButton, window, hoveredButton^.PressedImage, True, nil, True)
        else
          button_draw(hoveredButton, window, hoveredButton^.NormalImage, True, nil, True);

        window^.HoveredButton := nil;
        last_button_winID_ := window^.Id;

        if (hoveredButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
        begin
          if Assigned(hoveredButton^.MouseExitProc) then
          begin
            hoveredButton^.MouseExitProc(hoveredButton^.Id, keyCodePtr^);
            if (hoveredButton^.Flags and BUTTON_FLAG_0x40) = 0 then
              keyCodePtr^ := -1;
          end;
        end;
        Exit(0);
      end;
      button := hoveredButton;
    end
    else if clickedButton <> nil then
    begin
      if button_under_mouse(clickedButton, @v58) then
      begin
        if (clickedButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
          keyCodePtr^ := clickedButton^.MouseEnterEventCode;

        if ((clickedButton^.Flags and BUTTON_FLAG_0x01) <> 0) and
           ((clickedButton^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
          button_draw(clickedButton, window, clickedButton^.PressedImage, True, nil, True)
        else
          button_draw(clickedButton, window, clickedButton^.NormalImage, True, nil, True);

        window^.HoveredButton := clickedButton;
        last_button_winID_ := window^.Id;

        if (clickedButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
        begin
          if Assigned(clickedButton^.MouseEnterProc) then
          begin
            clickedButton^.MouseEnterProc(clickedButton^.Id, keyCodePtr^);
            if (clickedButton^.Flags and BUTTON_FLAG_0x40) = 0 then
              keyCodePtr^ := -1;
          end;
        end;
        Exit(0);
      end;
    end;

    v25 := last_button_winID_;
    if (last_button_winID_ <> -1) and (last_button_winID_ <> window^.Id) then
    begin
      v26 := GNW_find(last_button_winID_);
      if v26 <> nil then
      begin
        last_button_winID_ := -1;

        v28 := v26^.HoveredButton;
        if v28 <> nil then
        begin
          if (v28^.Flags and BUTTON_FLAG_DISABLED) = 0 then
            keyCodePtr^ := v28^.MouseExitEventCode;

          if ((v28^.Flags and BUTTON_FLAG_0x01) <> 0) and
             ((v28^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
            button_draw(v28, v26, v28^.PressedImage, True, nil, True)
          else
            button_draw(v28, v26, v28^.NormalImage, True, nil, True);

          v26^.ClickedButton := nil;
          v26^.HoveredButton := nil;

          if (v28^.Flags and BUTTON_FLAG_DISABLED) = 0 then
          begin
            if Assigned(v28^.MouseExitProc) then
            begin
              v28^.MouseExitProc(v28^.Id, keyCodePtr^);
              if (v28^.Flags and BUTTON_FLAG_0x40) = 0 then
                keyCodePtr^ := -1;
            end;
          end;
          Exit(0);
        end;
      end;
    end;

    cb := nil;

    while button <> nil do
    begin
      if (button^.Flags and BUTTON_FLAG_DISABLED) = 0 then
      begin
        rectCopy(@v58, @button^.Rect);
        rectOffset(@v58, window^.Rect.ulx, window^.Rect.uly);
        if button_under_mouse(button, @v58) then
        begin
          if (button^.Flags and BUTTON_FLAG_DISABLED) = 0 then
          begin
            if (mouseEvent and MOUSE_EVENT_ANY_BUTTON_DOWN) <> 0 then
            begin
              if ((mouseEvent and MOUSE_EVENT_RIGHT_BUTTON_DOWN) <> 0) and
                 ((button^.Flags and BUTTON_FLAG_RIGHT_MOUSE_BUTTON_CONFIGURED) = 0) then
              begin
                button := nil;
                Break;
              end;

              if (button <> window^.HoveredButton) and (button <> window^.ClickedButton) then
                Break;

              window^.ClickedButton := button;
              window^.HoveredButton := button;

              if (button^.Flags and BUTTON_FLAG_0x01) <> 0 then
              begin
                if (button^.Flags and BUTTON_FLAG_0x02) <> 0 then
                begin
                  if (button^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
                  begin
                    if (button^.Flags and BUTTON_FLAG_0x04) = 0 then
                    begin
                      if button^.ButtonGroup_ <> nil then
                        Dec(button^.ButtonGroup_^.CurrChecked);

                      if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
                      begin
                        keyCodePtr^ := button^.LeftMouseUpEventCode;
                        cb := button^.LeftMouseUpProc;
                      end
                      else
                      begin
                        keyCodePtr^ := button^.RightMouseUpEventCode;
                        cb := button^.RightMouseUpProc;
                      end;

                      button^.Flags := button^.Flags and (not BUTTON_FLAG_CHECKED);
                    end;
                  end
                  else
                  begin
                    if button_check_group(button) = -1 then
                    begin
                      button := nil;
                      Break;
                    end;

                    if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
                    begin
                      keyCodePtr^ := button^.LeftMouseDownEventCode;
                      cb := button^.LeftMouseDownProc;
                    end
                    else
                    begin
                      keyCodePtr^ := button^.RightMouseDownEventCode;
                      cb := button^.RightMouseDownProc;
                    end;

                    button^.Flags := button^.Flags or BUTTON_FLAG_CHECKED;
                  end;
                end;
              end
              else
              begin
                if button_check_group(button) = -1 then
                begin
                  button := nil;
                  Break;
                end;

                if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_DOWN) <> 0 then
                begin
                  keyCodePtr^ := button^.LeftMouseDownEventCode;
                  cb := button^.LeftMouseDownProc;
                end
                else
                begin
                  keyCodePtr^ := button^.RightMouseDownEventCode;
                  cb := button^.RightMouseDownProc;
                end;
              end;

              button_draw(button, window, button^.PressedImage, True, nil, True);
              Break;
            end;

            v49 := window^.ClickedButton;
            if (button = v49) and ((mouseEvent and MOUSE_EVENT_ANY_BUTTON_UP) <> 0) then
            begin
              WriteLn(StdErr, '[CLICK] btn=', button^.Id, ' mouseUp=', button^.LeftMouseUpEventCode);
              window^.ClickedButton := nil;
              window^.HoveredButton := v49;

              if (v49^.Flags and BUTTON_FLAG_0x01) <> 0 then
              begin
                if (v49^.Flags and BUTTON_FLAG_0x02) = 0 then
                begin
                  if (v49^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
                  begin
                    if (v49^.Flags and BUTTON_FLAG_0x04) = 0 then
                    begin
                      if v49^.ButtonGroup_ <> nil then
                        Dec(v49^.ButtonGroup_^.CurrChecked);

                      if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
                      begin
                        keyCodePtr^ := button^.LeftMouseUpEventCode;
                        cb := button^.LeftMouseUpProc;
                      end
                      else
                      begin
                        keyCodePtr^ := button^.RightMouseUpEventCode;
                        cb := button^.RightMouseUpProc;
                      end;

                      button^.Flags := button^.Flags and (not BUTTON_FLAG_CHECKED);
                    end;
                  end
                  else
                  begin
                    if button_check_group(v49) = -1 then
                    begin
                      button := nil;
                      button_draw(v49, window, v49^.NormalImage, True, nil, True);
                      Break;
                    end;

                    if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
                    begin
                      keyCodePtr^ := v49^.LeftMouseDownEventCode;
                      cb := v49^.LeftMouseDownProc;
                    end
                    else
                    begin
                      keyCodePtr^ := v49^.RightMouseDownEventCode;
                      cb := v49^.RightMouseDownProc;
                    end;

                    v49^.Flags := v49^.Flags or BUTTON_FLAG_CHECKED;
                  end;
                end;
              end
              else
              begin
                if (v49^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
                begin
                  if v49^.ButtonGroup_ <> nil then
                    Dec(v49^.ButtonGroup_^.CurrChecked);
                end;

                if (mouseEvent and MOUSE_EVENT_LEFT_BUTTON_UP) <> 0 then
                begin
                  keyCodePtr^ := v49^.LeftMouseUpEventCode;
                  cb := v49^.LeftMouseUpProc;
                end
                else
                begin
                  keyCodePtr^ := v49^.RightMouseUpEventCode;
                  cb := v49^.RightMouseUpProc;
                end;
              end;

              if button^.HoverImage <> nil then
                button_draw(button, window, button^.HoverImage, True, nil, True)
              else
                button_draw(button, window, button^.NormalImage, True, nil, True);
              Break;
            end;
          end;

          if (window^.HoveredButton = nil) and (mouseEvent = 0) then
          begin
            window^.HoveredButton := button;
            WriteLn(StdErr, '[HOVER] btn=', button^.Id, ' rect=', button^.Rect.ulx, ',', button^.Rect.uly, '-', button^.Rect.lrx, ',', button^.Rect.lry, ' mouseUp=', button^.LeftMouseUpEventCode);
            if (button^.Flags and BUTTON_FLAG_DISABLED) = 0 then
            begin
              keyCodePtr^ := button^.MouseEnterEventCode;
              cb := button^.MouseEnterProc;
            end;

            button_draw(button, window, button^.HoverImage, True, nil, True);
          end;
          Break;
        end;
      end;
      button := button^.Next;
    end;

    if button <> nil then
    begin
      if ((button^.Flags and BUTTON_FLAG_0x10) <> 0) and
         ((mouseEvent and MOUSE_EVENT_ANY_BUTTON_DOWN) <> 0) and
         ((mouseEvent and MOUSE_EVENT_ANY_BUTTON_REPEAT) = 0) then
      begin
        win_drag(window^.Id);
        button_draw(button, window, button^.NormalImage, True, nil, True);
      end;
    end
    else if (window^.Flags and WINDOW_FLAG_0x80) <> 0 then
    begin
      v25 := v25 or (mouseEvent shl 8);
      if ((mouseEvent and MOUSE_EVENT_ANY_BUTTON_DOWN) <> 0) and
         ((mouseEvent and MOUSE_EVENT_ANY_BUTTON_REPEAT) = 0) then
        win_drag(window^.Id);
    end;

    last_button_winID_ := window^.Id;

    if button <> nil then
    begin
      if Assigned(cb) then
      begin
        cb(button^.Id, keyCodePtr^);
        if (button^.Flags and BUTTON_FLAG_0x40) = 0 then
          keyCodePtr^ := -1;
      end;
    end;

    Exit(0);
  end;

  // Mouse is outside the window
  if hoveredButton <> nil then
  begin
    keyCodePtr^ := hoveredButton^.MouseExitEventCode;

    if ((hoveredButton^.Flags and BUTTON_FLAG_0x01) <> 0) and
       ((hoveredButton^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
      button_draw(hoveredButton, window, hoveredButton^.PressedImage, True, nil, True)
    else
      button_draw(hoveredButton, window, hoveredButton^.NormalImage, True, nil, True);

    window^.HoveredButton := nil;
  end;

  if keyCodePtr^ <> -1 then
  begin
    last_button_winID_ := window^.Id;

    if (hoveredButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
    begin
      if Assigned(hoveredButton^.MouseExitProc) then
      begin
        hoveredButton^.MouseExitProc(hoveredButton^.Id, keyCodePtr^);
        if (hoveredButton^.Flags and BUTTON_FLAG_0x40) = 0 then
          keyCodePtr^ := -1;
      end;
    end;
    Exit(0);
  end;

  if hoveredButton <> nil then
  begin
    if (hoveredButton^.Flags and BUTTON_FLAG_DISABLED) = 0 then
    begin
      if Assigned(hoveredButton^.MouseExitProc) then
        hoveredButton^.MouseExitProc(hoveredButton^.Id, keyCodePtr^);
    end;
  end;

  Result := -1;
end;

// 0x4C52CC
function button_under_mouse(button: PButton; rect: PRect): Boolean;
var
  x, y: Integer;
  width: Integer;
begin
  if not mouse_click_in(rect^.ulx, rect^.uly, rect^.lrx, rect^.lry) then
    Exit(False);

  if button^.Mask = nil then
    Exit(True);

  mouse_get_position(@x, @y);
  x := x - rect^.ulx;
  y := y - rect^.uly;

  width := button^.Rect.lrx - button^.Rect.ulx + 1;
  Result := (button^.Mask + width * y + x)^ <> 0;
end;

// 0x4C5334
function win_button_winID(btn: Integer): Integer;
var
  w: PWindow;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  if GNW_find_button(btn, @w) = nil then
    Exit(-1);

  Result := w^.Id;
end;

// 0x4C536C
function win_last_button_winID: Integer;
begin
  Result := last_button_winID_;
end;

// 0x4C5374
function win_delete_button(btn: Integer): Integer;
var
  w: PWindow;
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  if button^.Prev <> nil then
    button^.Prev^.Next := button^.Next
  else
    w^.ButtonListHead := button^.Next;

  if button^.Next <> nil then
    button^.Next^.Prev := button^.Prev;

  win_fill(w^.Id, button^.Rect.ulx, button^.Rect.uly,
    button^.Rect.lrx - button^.Rect.ulx + 1,
    button^.Rect.lry - button^.Rect.uly + 1,
    w^.Color);

  if button = w^.HoveredButton then
    w^.HoveredButton := nil;

  if button = w^.ClickedButton then
    w^.ClickedButton := nil;

  GNW_delete_button(button);

  Result := 0;
end;

// 0x4C542C
procedure GNW_delete_button(ptr: PButton);
var
  buttonGroup: PButtonGroup;
  index: Integer;
begin
  if ptr = nil then Exit;

  if (ptr^.Flags and BUTTON_FLAG_GRAPHIC) = 0 then
  begin
    if ptr^.NormalImage <> nil then
      mem_free(ptr^.NormalImage);

    if ptr^.PressedImage <> nil then
      mem_free(ptr^.PressedImage);

    if ptr^.HoverImage <> nil then
      mem_free(ptr^.HoverImage);

    if ptr^.DisabledNormalImage <> nil then
      mem_free(ptr^.DisabledNormalImage);

    if ptr^.DisabledPressedImage <> nil then
      mem_free(ptr^.DisabledPressedImage);

    if ptr^.DisabledHoverImage <> nil then
      mem_free(ptr^.DisabledHoverImage);
  end;

  buttonGroup := ptr^.ButtonGroup_;
  if buttonGroup <> nil then
  begin
    index := 0;
    while index < buttonGroup^.ButtonsLength do
    begin
      if ptr = buttonGroup^.Buttons[index] then
      begin
        while index < buttonGroup^.ButtonsLength - 1 do
        begin
          buttonGroup^.Buttons[index] := buttonGroup^.Buttons[index + 1];
          Inc(index);
        end;
        Dec(buttonGroup^.ButtonsLength);
        Break;
      end;
      Inc(index);
    end;
  end;

  mem_free(ptr);
end;

// 0x4C54E8
procedure win_delete_button_win(btn, inputEvent: Integer);
var
  button: PButton;
  w: PWindow;
begin
  button := GNW_find_button(btn, @w);
  if button <> nil then
  begin
    win_delete(w^.Id);
    GNW_add_input_buffer(inputEvent);
  end;
end;

// 0x4C552C
function win_enable_button(btn: Integer): Integer;
var
  w: PWindow;
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  if (button^.Flags and BUTTON_FLAG_DISABLED) <> 0 then
  begin
    button^.Flags := button^.Flags and (not BUTTON_FLAG_DISABLED);
    button_draw(button, w, button^.CurrentImage, True, nil, False);
  end;

  Result := 0;
end;

// 0x4C5588
function win_disable_button(btn: Integer): Integer;
var
  w: PWindow;
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  if (button^.Flags and BUTTON_FLAG_DISABLED) = 0 then
  begin
    button^.Flags := button^.Flags or BUTTON_FLAG_DISABLED;

    button_draw(button, w, button^.CurrentImage, True, nil, False);

    if button = w^.HoveredButton then
    begin
      if w^.HoveredButton^.MouseExitEventCode <> -1 then
      begin
        GNW_add_input_buffer(w^.HoveredButton^.MouseExitEventCode);
        w^.HoveredButton := nil;
      end;
    end;
  end;

  Result := 0;
end;

// 0x4C560C
function win_set_button_rest_state(btn: Integer; checked: Boolean; flags: Integer): Integer;
var
  w: PWindow;
  button: PButton;
  keyCode: Integer;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  if (button^.Flags and BUTTON_FLAG_0x01) <> 0 then
  begin
    keyCode := -1;

    if (button^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
    begin
      if not checked then
      begin
        button^.Flags := button^.Flags and (not BUTTON_FLAG_CHECKED);

        if (flags and $02) = 0 then
          button_draw(button, w, button^.NormalImage, True, nil, False);

        if button^.ButtonGroup_ <> nil then
          Dec(button^.ButtonGroup_^.CurrChecked);

        keyCode := button^.LeftMouseUpEventCode;
      end;
    end
    else
    begin
      if checked then
      begin
        button^.Flags := button^.Flags or BUTTON_FLAG_CHECKED;

        if (flags and $02) = 0 then
          button_draw(button, w, button^.PressedImage, True, nil, False);

        if button^.ButtonGroup_ <> nil then
          Inc(button^.ButtonGroup_^.CurrChecked);

        keyCode := button^.LeftMouseDownEventCode;
      end;
    end;

    if keyCode <> -1 then
    begin
      if (flags and $01) <> 0 then
        GNW_add_input_buffer(keyCode);
    end;
  end;

  Result := 0;
end;

// 0x4C56E4
function win_group_check_buttons(buttonCount: Integer; btns: PInteger;
  maxChecked: Integer; func: TRadioButtonCallback): Integer;
var
  groupIndex, buttonIndex: Integer;
  buttonGroup: PButtonGroup;
  button: PButton;
  btnPtr: PInteger;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  if buttonCount >= BUTTON_GROUP_BUTTON_LIST_CAPACITY then
    Exit(-1);

  for groupIndex := 0 to BUTTON_GROUP_LIST_CAPACITY - 1 do
  begin
    buttonGroup := @btn_grp[groupIndex];
    if buttonGroup^.ButtonsLength = 0 then
    begin
      buttonGroup^.CurrChecked := 0;

      btnPtr := btns;
      for buttonIndex := 0 to buttonCount - 1 do
      begin
        button := GNW_find_button(btnPtr^, nil);
        if button = nil then
          Exit(-1);

        buttonGroup^.Buttons[buttonIndex] := button;
        button^.ButtonGroup_ := buttonGroup;

        if (button^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
          Inc(buttonGroup^.CurrChecked);

        Inc(btnPtr);
      end;

      buttonGroup^.ButtonsLength := buttonCount;
      buttonGroup^.MaxChecked := maxChecked;
      buttonGroup^.Func := func;
      Exit(0);
    end;
  end;

  Result := -1;
end;

// 0x4C57A4
function win_group_radio_buttons(buttonCount: Integer; btns: PInteger): Integer;
var
  button: PButton;
  buttonGroup: PButtonGroup;
  index: Integer;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  if win_group_check_buttons(buttonCount, btns, 1, nil) = -1 then
    Exit(-1);

  button := GNW_find_button(btns^, nil);
  buttonGroup := button^.ButtonGroup_;

  for index := 0 to buttonGroup^.ButtonsLength - 1 do
    buttonGroup^.Buttons[index]^.Flags := buttonGroup^.Buttons[index]^.Flags or BUTTON_FLAG_RADIO;

  Result := 0;
end;

// 0x4C57FC
function button_check_group(button: PButton): Integer;
var
  index: Integer;
  otherButton: PButton;
  w: PWindow;
begin
  if button^.ButtonGroup_ = nil then
    Exit(0);

  if (button^.Flags and BUTTON_FLAG_RADIO) <> 0 then
  begin
    if button^.ButtonGroup_^.CurrChecked > 0 then
    begin
      for index := 0 to button^.ButtonGroup_^.ButtonsLength - 1 do
      begin
        otherButton := button^.ButtonGroup_^.Buttons[index];
        if (otherButton^.Flags and BUTTON_FLAG_CHECKED) <> 0 then
        begin
          otherButton^.Flags := otherButton^.Flags and (not BUTTON_FLAG_CHECKED);

          GNW_find_button(otherButton^.Id, @w);
          button_draw(otherButton, w, otherButton^.NormalImage, True, nil, True);

          if Assigned(otherButton^.LeftMouseUpProc) then
            otherButton^.LeftMouseUpProc(otherButton^.Id, otherButton^.LeftMouseUpEventCode);
        end;
      end;
    end;

    if (button^.Flags and BUTTON_FLAG_CHECKED) = 0 then
      Inc(button^.ButtonGroup_^.CurrChecked);

    Exit(0);
  end;

  if button^.ButtonGroup_^.CurrChecked < button^.ButtonGroup_^.MaxChecked then
  begin
    if (button^.Flags and BUTTON_FLAG_CHECKED) = 0 then
      Inc(button^.ButtonGroup_^.CurrChecked);

    Exit(0);
  end;

  if Assigned(button^.ButtonGroup_^.Func) then
    button^.ButtonGroup_^.Func(button^.Id);

  Result := -1;
end;

// 0x4C58C0
procedure button_draw(button: PButton; w: PWindow; data: PByte; doDraw: Boolean;
  bound: PRect; sound: Boolean);
var
  previousImage: PByte;
  v2, v3: TRect;
  width: Integer;
begin
  previousImage := nil;

  if data <> nil then
  begin
    rectCopy(@v2, @button^.Rect);
    rectOffset(@v2, w^.Rect.ulx, w^.Rect.uly);

    if bound <> nil then
    begin
      if rect_inside_bound(@v2, bound, @v2) = -1 then
        Exit;

      rectCopy(@v3, @v2);
      rectOffset(@v3, -w^.Rect.ulx, -w^.Rect.uly);
    end
    else
    begin
      rectCopy(@v3, @button^.Rect);
    end;

    if (data = button^.NormalImage) and ((button^.Flags and BUTTON_FLAG_CHECKED) <> 0) then
      data := button^.PressedImage;

    if (button^.Flags and BUTTON_FLAG_DISABLED) <> 0 then
    begin
      if data = button^.NormalImage then
        data := button^.DisabledNormalImage
      else if data = button^.PressedImage then
        data := button^.DisabledPressedImage
      else if data = button^.HoverImage then
        data := button^.DisabledHoverImage;
    end
    else
    begin
      if data = button^.DisabledNormalImage then
        data := button^.NormalImage
      else if data = button^.DisabledPressedImage then
        data := button^.PressedImage
      else if data = button^.DisabledHoverImage then
        data := button^.HoverImage;
    end;

    if data <> nil then
    begin
      if not doDraw then
      begin
        width := button^.Rect.lrx - button^.Rect.ulx + 1;
        if (button^.Flags and BUTTON_FLAG_TRANSPARENT) <> 0 then
        begin
          trans_buf_to_buf(
            data + (v3.uly - button^.Rect.uly) * width + v3.ulx - button^.Rect.ulx,
            v3.lrx - v3.ulx + 1,
            v3.lry - v3.uly + 1,
            width,
            w^.Buffer + w^.Width * v3.uly + v3.ulx,
            w^.Width);
        end
        else
        begin
          buf_to_buf(
            data + (v3.uly - button^.Rect.uly) * width + v3.ulx - button^.Rect.ulx,
            v3.lrx - v3.ulx + 1,
            v3.lry - v3.uly + 1,
            width,
            w^.Buffer + w^.Width * v3.uly + v3.ulx,
            w^.Width);
        end;
      end;

      previousImage := button^.CurrentImage;
      button^.CurrentImage := data;

      if doDraw then
        GNW_win_refresh(w, @v2, nil);
    end;
  end;

  if sound then
  begin
    if previousImage <> data then
    begin
      if (data = button^.PressedImage) and Assigned(button^.PressSoundFunc) then
        button^.PressSoundFunc(button^.Id, button^.LeftMouseDownEventCode)
      else if (data = button^.NormalImage) and Assigned(button^.ReleaseSoundFunc) then
        button^.ReleaseSoundFunc(button^.Id, button^.LeftMouseUpEventCode);
    end;
  end;
end;

// 0x4C5B10
procedure GNW_button_refresh(window: PWindow; rect: PRect);
var
  button: PButton;
begin
  button := window^.ButtonListHead;
  if button <> nil then
  begin
    while button^.Next <> nil do
      button := button^.Next;
  end;

  while button <> nil do
  begin
    button_draw(button, window, button^.CurrentImage, False, rect, False);
    button := button^.Prev;
  end;
end;

// 0x4C5B58
function win_button_press_and_release(btn: Integer): Integer;
var
  w: PWindow;
  button: PButton;
begin
  if not GNW_win_init_flag then
    Exit(-1);

  button := GNW_find_button(btn, @w);
  if button = nil then
    Exit(-1);

  button_draw(button, w, button^.PressedImage, True, nil, True);

  if Assigned(button^.LeftMouseDownProc) then
  begin
    button^.LeftMouseDownProc(btn, button^.LeftMouseDownEventCode);

    if (button^.Flags and BUTTON_FLAG_0x40) <> 0 then
      GNW_add_input_buffer(button^.LeftMouseDownEventCode);
  end
  else
  begin
    if button^.LeftMouseDownEventCode <> -1 then
      GNW_add_input_buffer(button^.LeftMouseDownEventCode);
  end;

  button_draw(button, w, button^.NormalImage, True, nil, True);

  if Assigned(button^.LeftMouseUpProc) then
  begin
    button^.LeftMouseUpProc(btn, button^.LeftMouseUpEventCode);

    if (button^.Flags and BUTTON_FLAG_0x40) <> 0 then
      GNW_add_input_buffer(button^.LeftMouseUpEventCode);
  end
  else
  begin
    if button^.LeftMouseUpEventCode <> -1 then
      GNW_add_input_buffer(button^.LeftMouseUpEventCode);
  end;

  Result := 0;
end;

initialization
  FillChar(btn_grp, SizeOf(btn_grp), 0);

end.
