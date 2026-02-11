unit u_map_defs;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

const
  ELEVATION_COUNT   = 3;
  SQUARE_GRID_WIDTH  = 100;
  SQUARE_GRID_HEIGHT = 100;
  SQUARE_GRID_SIZE   = SQUARE_GRID_WIDTH * SQUARE_GRID_HEIGHT;
  HEX_GRID_WIDTH     = 200;
  HEX_GRID_HEIGHT    = 200;
  HEX_GRID_SIZE      = HEX_GRID_WIDTH * HEX_GRID_HEIGHT;

function ElevationIsValid(elevation: Integer): Boolean; inline;
function SquareGridTileIsValid(tile: Integer): Boolean; inline;
function HexGridTileIsValid(tile: Integer): Boolean; inline;

implementation

function ElevationIsValid(elevation: Integer): Boolean; inline;
begin
  Result := (elevation >= 0) and (elevation < ELEVATION_COUNT);
end;

function SquareGridTileIsValid(tile: Integer): Boolean; inline;
begin
  Result := (tile >= 0) and (tile < SQUARE_GRID_SIZE);
end;

function HexGridTileIsValid(tile: Integer): Boolean; inline;
begin
  Result := (tile >= 0) and (tile < HEX_GRID_SIZE);
end;

end.
