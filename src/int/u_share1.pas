{$MODE OBJFPC}{$H+}
// Converted from: src/int/share1.cc/h
// Shared file list utilities for the script interpreter.
unit u_share1;

interface

function getFileList(const pattern: PAnsiChar; fileNameListLengthPtr: PInteger): PPAnsiChar;
procedure freeFileList(fileList: PPAnsiChar);

implementation

uses
  SysUtils,
  u_db;

type
  TPAnsiCharArray = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;
  PPAnsiCharArray = ^TPAnsiCharArray;

procedure SortFileList(list: PPAnsiChar; count: Integer);
var
  arr: PPAnsiCharArray;
  i, j: Integer;
  temp: PAnsiChar;
begin
  if count <= 1 then Exit;
  arr := PPAnsiCharArray(list);
  // Insertion sort - adequate for file lists
  for i := 1 to count - 1 do
  begin
    temp := arr^[i];
    j := i - 1;
    while (j >= 0) and (StrComp(arr^[j], temp) > 0) do
    begin
      arr^[j + 1] := arr^[j];
      Dec(j);
    end;
    arr^[j + 1] := temp;
  end;
end;

function getFileList(const pattern: PAnsiChar; fileNameListLengthPtr: PInteger): PPAnsiChar;
var
  fileNameList: PPAnsiChar;
  fileNameListLength: Integer;
begin
  fileNameList := nil;
  fileNameListLength := db_get_file_list(pattern, @fileNameList, nil, 0);
  fileNameListLengthPtr^ := fileNameListLength;
  if fileNameListLength = 0 then
    Exit(nil);

  SortFileList(fileNameList, fileNameListLength);

  Result := fileNameList;
end;

procedure freeFileList(fileList: PPAnsiChar);
begin
  db_free_file_list(@fileList, nil);
end;

end.
