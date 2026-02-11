unit u_amutex;

{$MODE OBJFPC}{$H+}
{$PACKRECORDS C}

interface

function autorun_mutex_create: Boolean;
procedure autorun_mutex_destroy;

implementation

// On non-Windows platforms, the mutex is a no-op.
// On Windows, it would use CreateMutexA to prevent multiple instances.

function autorun_mutex_create: Boolean;
begin
  Result := True;
end;

procedure autorun_mutex_destroy;
begin
  // no-op on non-Windows
end;

end.
