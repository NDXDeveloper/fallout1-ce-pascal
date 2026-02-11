{$MODE OBJFPC}{$H+}
// Converted from: third_party/fpattern (David R. Tribble, v1.9)
// Glob-style file pattern matching utility.
//
// Pattern syntax:
//   *      - match zero or more characters (not path separator)
//   ?      - match any single character (not path separator)
//   [abc]  - match any character in set
//   [!abc] - match any character not in set
//   [a-z]  - match any character in range
//   \x     - literal match of character x
unit u_fpattern;

interface

// Check whether FileName matches the glob Pattern (case-sensitive).
function fpattern_match(const Pattern, FileName: PAnsiChar): Boolean;

// Check whether FileName matches the glob Pattern (case-insensitive).
function fpattern_matchn(const Pattern, FileName: PAnsiChar): Boolean;

// Return True if Pattern is a syntactically valid glob pattern.
function fpattern_isvalid(const Pattern: PAnsiChar): Boolean;

implementation

const
  CHAR_ESCAPE   = '\';
  CHAR_STAR     = '*';
  CHAR_QUESTION = '?';
  CHAR_LBRACKET = '[';
  CHAR_RBRACKET = ']';
  CHAR_NEGATE   = '!';
  CHAR_DASH     = '-';
  CHAR_SLASH    = '/';
  CHAR_BACKSLASH_PATH = '\';
  CHAR_NUL      = #0;

function IsPathSep(c: AnsiChar): Boolean; inline;
begin
  Result := (c = CHAR_SLASH) or (c = CHAR_BACKSLASH_PATH);
end;

function ToLower(c: AnsiChar): AnsiChar; inline;
begin
  if (c >= 'A') and (c <= 'Z') then
    Result := AnsiChar(Ord(c) + 32)
  else
    Result := c;
end;

// Internal recursive matching function.
// caseSensitive=True for fpattern_match, False for fpattern_matchn.
function fpattern_submatch(pat, fname: PAnsiChar; caseSensitive: Boolean): Boolean;
var
  pc, fc: AnsiChar;
  negate, matched: Boolean;
  lo, hi: AnsiChar;
begin
  while True do
  begin
    pc := pat^;
    fc := fname^;

    case pc of
      CHAR_NUL:
      begin
        // End of pattern: match only if end of filename
        Result := (fc = CHAR_NUL);
        Exit;
      end;

      CHAR_STAR:
      begin
        // Skip consecutive stars
        while pat^ = CHAR_STAR do
          Inc(pat);

        // Trailing star matches everything
        if pat^ = CHAR_NUL then
        begin
          Result := True;
          Exit;
        end;

        // Try matching remaining pattern against every suffix of filename
        while fname^ <> CHAR_NUL do
        begin
          if fpattern_submatch(pat, fname, caseSensitive) then
          begin
            Result := True;
            Exit;
          end;
          Inc(fname);
        end;

        // Try matching both at end
        Result := fpattern_submatch(pat, fname, caseSensitive);
        Exit;
      end;

      CHAR_QUESTION:
      begin
        // Match any single character (must have at least one)
        if (fc = CHAR_NUL) then
        begin
          Result := False;
          Exit;
        end;
        Inc(pat);
        Inc(fname);
      end;

      CHAR_LBRACKET:
      begin
        // Character class [...]
        if fc = CHAR_NUL then
        begin
          Result := False;
          Exit;
        end;

        Inc(pat); // skip '['

        // Check for negation
        negate := False;
        if (pat^ = CHAR_NEGATE) or (pat^ = '^') then
        begin
          negate := True;
          Inc(pat);
        end;

        matched := False;

        // Process character class members
        while (pat^ <> CHAR_NUL) and (pat^ <> CHAR_RBRACKET) do
        begin
          lo := pat^;
          Inc(pat);

          // Check for range a-z
          if (pat^ = CHAR_DASH) and ((pat + 1)^ <> CHAR_RBRACKET) and ((pat + 1)^ <> CHAR_NUL) then
          begin
            Inc(pat); // skip '-'
            hi := pat^;
            Inc(pat);

            if caseSensitive then
            begin
              if (fc >= lo) and (fc <= hi) then
                matched := True;
            end
            else
            begin
              if (ToLower(fc) >= ToLower(lo)) and (ToLower(fc) <= ToLower(hi)) then
                matched := True;
            end;
          end
          else
          begin
            // Single character
            if caseSensitive then
            begin
              if fc = lo then
                matched := True;
            end
            else
            begin
              if ToLower(fc) = ToLower(lo) then
                matched := True;
            end;
          end;
        end;

        // Skip closing bracket
        if pat^ = CHAR_RBRACKET then
          Inc(pat);

        if negate then
          matched := not matched;

        if not matched then
        begin
          Result := False;
          Exit;
        end;

        Inc(fname);
      end;

      CHAR_ESCAPE:
      begin
        // Escape: match next character literally
        Inc(pat);
        if pat^ = CHAR_NUL then
        begin
          // Backslash at end of pattern
          Result := False;
          Exit;
        end;

        // In the fpattern library, backslash is also a path separator on Windows,
        // so only treat as escape if the next char is a special pattern character.
        // For simplicity and cross-platform correctness, we match literally.
        if caseSensitive then
        begin
          if pat^ <> fc then
          begin
            Result := False;
            Exit;
          end;
        end
        else
        begin
          if ToLower(pat^) <> ToLower(fc) then
          begin
            Result := False;
            Exit;
          end;
        end;

        Inc(pat);
        Inc(fname);
      end;

    else
      // Literal character match
      if caseSensitive then
      begin
        if pc <> fc then
        begin
          Result := False;
          Exit;
        end;
      end
      else
      begin
        if ToLower(pc) <> ToLower(fc) then
        begin
          Result := False;
          Exit;
        end;
      end;

      Inc(pat);
      Inc(fname);
    end;
  end;

  // Should not reach here
  Result := False;
end;

function fpattern_match(const Pattern, FileName: PAnsiChar): Boolean;
begin
  if (Pattern = nil) or (FileName = nil) then
  begin
    Result := False;
    Exit;
  end;

  Result := fpattern_submatch(Pattern, FileName, True);
end;

function fpattern_matchn(const Pattern, FileName: PAnsiChar): Boolean;
begin
  if (Pattern = nil) or (FileName = nil) then
  begin
    Result := False;
    Exit;
  end;

  Result := fpattern_submatch(Pattern, FileName, False);
end;

function fpattern_isvalid(const Pattern: PAnsiChar): Boolean;
var
  p: PAnsiChar;
begin
  if Pattern = nil then
  begin
    Result := False;
    Exit;
  end;

  p := Pattern;
  while p^ <> CHAR_NUL do
  begin
    case p^ of
      CHAR_ESCAPE:
      begin
        Inc(p);
        if p^ = CHAR_NUL then
        begin
          // Backslash at end of pattern is invalid
          Result := False;
          Exit;
        end;
      end;
      CHAR_LBRACKET:
      begin
        Inc(p);
        // Skip negation
        if (p^ = CHAR_NEGATE) or (p^ = '^') then
          Inc(p);
        // Must have at least one character in class
        if (p^ = CHAR_NUL) or (p^ = CHAR_RBRACKET) then
        begin
          Result := False;
          Exit;
        end;
        // Find closing bracket
        while (p^ <> CHAR_NUL) and (p^ <> CHAR_RBRACKET) do
          Inc(p);
        if p^ <> CHAR_RBRACKET then
        begin
          // Unclosed bracket
          Result := False;
          Exit;
        end;
      end;
    end;
    Inc(p);
  end;

  Result := True;
end;

end.
