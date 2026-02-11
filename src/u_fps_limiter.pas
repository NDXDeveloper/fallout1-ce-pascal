{$MODE OBJFPC}{$H+}
// Converted from: src/fps_limiter.h + fps_limiter.cc
// Simple frame-rate limiter using SDL2 timing functions.
unit u_fps_limiter;

interface

type
  TFpsLimiter = class
  private
    FFps: Cardinal;
    FTicks: Cardinal;
  public
    constructor Create(AFps: Cardinal = 60);
    procedure Mark;
    procedure Throttle;
  end;

implementation

// SDL2 external declarations. These will be replaced once full SDL2 Pascal
// bindings are integrated into the project.
function SDL_GetTicks: Cardinal; cdecl; external 'SDL2';
procedure SDL_Delay(Ms: Cardinal); cdecl; external 'SDL2';

constructor TFpsLimiter.Create(AFps: Cardinal);
begin
  inherited Create;
  FFps := AFps;
  FTicks := 0;
end;

// Record the current timestamp.
procedure TFpsLimiter.Mark;
begin
  FTicks := SDL_GetTicks;
end;

// Sleep until enough time has elapsed since the last Mark to maintain
// the target frame rate.
procedure TFpsLimiter.Throttle;
var
  FrameTime, Elapsed: Cardinal;
begin
  if FFps = 0 then
    Exit;
  FrameTime := 1000 div FFps;
  Elapsed := SDL_GetTicks - FTicks;
  if FrameTime > Elapsed then
    SDL_Delay(FrameTime - Elapsed);
end;

end.
