# Fallout 1 CE - Data Formats and I/O Systems

This document describes the data formats, archive systems, and I/O subsystems used throughout
the Fallout 1 Community Edition C++ codebase. These systems collectively handle reading and
writing all game assets, configuration, save data, and runtime lookup tables.

---

## 1. DAT Archive System (`plib/db/db.cc/h`)

### Overview

Fallout uses `.DAT` archives (`master.dat`, `critter.dat`) containing all game assets: art,
maps, prototypes, scripts, sounds, and text. The DB module provides a stdio-like API for
transparent access to files inside these archives. From the perspective of calling code,
opening a file from a DAT archive looks exactly the same as opening a file from disk.

The system supports a **patch overlay** mechanism: files in a patch directory on disk take
priority over files inside DAT archives. This allows modding and development without
repacking archives. The lookup order is:

1. Patch directory (loose files on disk)
2. Primary DAT archive

### Database Management

- **`db_init(patches, main_file, patch_flags)`** - Initialize the database system. Opens the
  main DAT archive (`main_file`) and registers a patch directory (`patches`). The
  `patch_flags` parameter controls patch behavior. This must be called before any file
  access. Typically called twice: once for `master.dat` and once for `critter.dat`.

- **`db_select(db_index)`** - Switch the active database when multiple archives are open.
  Returns the previously selected database index.

- **`db_current()`** - Returns the index of the currently selected database.

- **`db_total()`** - Returns the total number of open databases.

- **`db_close(db_index)`** - Close a specific database by index, releasing its resources.

- **`db_exit()`** - Shut down the entire database system. Closes all open databases and
  frees all associated memory. Called during program shutdown.

### File Access API (mirrors stdio)

The DB module provides a complete set of file I/O functions that mirror the C standard
library `stdio.h` interface. All of these operate transparently on files whether they
reside inside a DAT archive or on the filesystem as patch files.

- **`db_fopen(path, mode)`** - Open a file for reading or writing. Returns a `DB_FILE*`
  handle (analogous to `FILE*`). The path uses forward slashes. Mode strings follow stdio
  conventions (`"r"`, `"rb"`, `"w"`, `"wb"`, etc.). When reading, the system first checks
  the patch directory, then the DAT archive. Writing always goes to disk.

- **`db_fclose(stream)`** - Close an open file handle and free associated buffers.

- **`db_fread(buf, size, count, stream)`** - Read `count` elements of `size` bytes each
  from the stream into `buf`. Returns the number of elements successfully read.

- **`db_fwrite(buf, size, count, stream)`** - Write `count` elements of `size` bytes each
  from `buf` to the stream. Returns the number of elements successfully written.

- **`db_fgetc(stream)`** - Read a single byte from the stream. Returns the byte value or
  -1 on EOF.

- **`db_fputc(ch, stream)`** - Write a single byte to the stream.

- **`db_fgets(buf, max, stream)`** - Read a line of text (up to `max - 1` characters or
  until newline). Null-terminates the result. Returns `buf` on success, `NULL` on EOF.

- **`db_fputs(str, stream)`** - Write a null-terminated string to the stream.

- **`db_fprintf(stream, format, ...)`** - Formatted output to a stream, following
  `printf`-style format strings.

- **`db_fseek(stream, offset, origin)`** - Reposition the stream. `origin` uses the same
  constants as `fseek`: `SEEK_SET`, `SEEK_CUR`, `SEEK_END`.

- **`db_ftell(stream)`** - Return the current position in the stream.

- **`db_rewind(stream)`** - Reset the stream position to the beginning. Equivalent to
  `db_fseek(stream, 0, SEEK_SET)`.

- **`db_feof(stream)`** - Returns non-zero if the end of the stream has been reached.

### Typed I/O (Endian-Safe)

These functions handle reading and writing of typed values with consistent byte order.
The original game was little-endian (x86), and these functions ensure correct byte ordering
regardless of the host platform.

**Single-value readers:**
- **`db_freadByte(stream, &value)`** - Read one unsigned 8-bit byte.
- **`db_freadShort(stream, &value)`** - Read one unsigned 16-bit short.
- **`db_freadInt(stream, &value)`** - Read one signed 32-bit integer.
- **`db_freadLong(stream, &value)`** - Read one signed 32-bit long (same as Int in practice).
- **`db_freadFloat(stream, &value)`** - Read one 32-bit IEEE float.

**Array readers (count variants):**
- **`db_freadByteCount(stream, buf, count)`** - Read `count` bytes into a buffer.
- **`db_freadShortCount(stream, buf, count)`** - Read `count` 16-bit shorts.
- **`db_freadIntCount(stream, buf, count)`** - Read `count` 32-bit integers.
- **`db_freadLongCount(stream, buf, count)`** - Read `count` 32-bit longs.
- **`db_freadFloatCount(stream, buf, count)`** - Read `count` 32-bit floats.

**Single-value writers:**
- **`db_fwriteByte(stream, value)`** - Write one unsigned 8-bit byte.
- **`db_fwriteShort(stream, value)`** - Write one unsigned 16-bit short.
- **`db_fwriteInt(stream, value)`** - Write one signed 32-bit integer.
- **`db_fwriteLong(stream, value)`** - Write one signed 32-bit long.
- **`db_fwriteFloat(stream, value)`** - Write one 32-bit IEEE float.

**Array writers (count variants):**
- **`db_fwriteByteCount(stream, buf, count)`** - Write `count` bytes from a buffer.
- **`db_fwriteShortCount(stream, buf, count)`** - Write `count` 16-bit shorts.
- **`db_fwriteIntCount(stream, buf, count)`** - Write `count` 32-bit integers.
- **`db_fwriteLongCount(stream, buf, count)`** - Write `count` 32-bit longs.
- **`db_fwriteFloatCount(stream, buf, count)`** - Write `count` 32-bit floats.

**Explicit-width readers (used in CE for clarity):**
- **`db_freadUInt8(stream, &value)`** - Read unsigned 8-bit integer.
- **`db_freadInt8(stream, &value)`** - Read signed 8-bit integer.
- **`db_freadUInt16(stream, &value)`** - Read unsigned 16-bit integer.
- **`db_freadInt16(stream, &value)`** - Read signed 16-bit integer.
- **`db_freadUInt32(stream, &value)`** - Read unsigned 32-bit integer.
- **`db_freadInt32(stream, &value)`** - Read signed 32-bit integer.
- **`db_freadBool(stream, &value)`** - Read a boolean (stored as 32-bit integer).

### Bulk Operations

- **`db_read_to_buf(path, buf, size)`** - Load an entire file into a pre-allocated buffer.
  This is a convenience function that opens the file, reads `size` bytes, and closes it.
  Commonly used for loading art, scripts, and other binary data.

- **`db_filelength(stream)`** - Return the total size of an open file in bytes. Works for
  both DAT archive entries and disk files.

- **`db_dir_entry(path, dir_entry)`** - Query metadata about a file without opening it.
  Populates a `dir_entry` structure with information about the file.

### File Listing

- **`db_get_file_list(pattern, file_list, ...)`** - Find all files matching a wildcard
  pattern (e.g., `"art\\critters\\*.frm"`). Searches both patch directories and DAT
  archives. Populates the provided file list structure. The pattern uses DOS-style wildcards
  (`*` and `?`).

- **`db_free_file_list(file_list)`** - Free the memory allocated by `db_get_file_list`.

### Hash Table Optimization

The database system uses hash tables to cache file location lookups, avoiding repeated
linear scans of the DAT archive directory.

- **`db_enable_hash_table()`** - Enable hash table caching for file lookups. Once enabled,
  the first lookup of a file populates the cache; subsequent lookups are O(1).

- **`db_reset_hash_tables()`** - Clear all cached entries. Used when archives are added or
  removed.

- **`db_add_hash_entry(path, ...)`** - Manually add a cache entry for a specific file path.

### Configuration

- **`db_register_mem(malloc_func, realloc_func, free_func)`** - Register custom memory
  allocation functions. By default, the system uses the standard C allocator. This allows
  integration with the game's memory management system.

- **`db_register_callback(callback, ...)`** - Register a progress callback function that
  is invoked during long file operations (e.g., loading large files from an archive). Used
  to update loading screens.

### dir_entry Structure

The `dir_entry` structure describes a single file within a DAT archive:

- **`flags`** - Bitfield. Indicates whether the entry is compressed, whether it exists in
  the patch directory, etc.
- **`offset`** - Byte offset of the file data within the DAT archive.
- **`compressed_length`** - Size of the file data as stored in the archive (may be smaller
  than the actual file if compressed).
- **`decompressed_length`** - Original (uncompressed) size of the file.

When `compressed_length < decompressed_length`, the file is LZSS-compressed and must be
decompressed on read.

---

## 2. LZSS Compression (`plib/db/lzss.cc/h`)

LZSS (Lempel-Ziv-Storer-Szymanski) is the compression algorithm used for entries inside
DAT archives. It is a dictionary-based compression scheme that replaces repeated sequences
with back-references into a sliding window.

- **`lzss_decode_to_buf(src, src_len, dest, dest_len)`** - Decompress LZSS-encoded data
  from a source buffer into a destination buffer. The caller must provide a destination
  buffer of at least `dest_len` bytes (the known decompressed size from the `dir_entry`).

- **`lzss_decode_to_file(src, src_len, dest_file)`** - Decompress LZSS-encoded data from
  a source buffer and write the decompressed output directly to a file handle. Used when
  the decompressed data is too large to hold in memory, or when extracting to disk.

The LZSS implementation uses a 4096-byte ring buffer (sliding window) with a 16-byte
maximum match length. Compressed data consists of a stream of flag bytes followed by
literal bytes or (offset, length) pairs:

- Flag byte: 8 bits, each indicating whether the next element is a literal (1) or a
  back-reference (0).
- Literal: a single raw byte copied to output.
- Back-reference: 2 bytes encoding a 12-bit offset into the ring buffer and a 4-bit
  match length (plus a minimum match threshold).

---

## 3. Associative Arrays (`plib/assoc/assoc.cc/h`)

The associative array module provides a sorted key-value store, functioning as a dictionary
or map data structure. Keys are null-terminated strings, and values are fixed-size binary
blobs. The array is kept sorted by key for binary search lookup.

- **`assoc_init(assoc, capacity, value_size)`** - Create a new associative array with an
  initial capacity for `capacity` entries, where each value occupies `value_size` bytes.
  The array starts empty.

- **`assoc_resize(assoc, new_capacity)`** - Grow or shrink the array's capacity. Existing
  entries are preserved (up to the new capacity). Used when the array needs to accommodate
  more entries.

- **`assoc_free(assoc)`** - Deallocate all memory used by the associative array, including
  all stored keys and values.

- **`assoc_search(assoc, key)`** - Look up a key in the array using binary search. Returns
  a pointer to the value if found, or `NULL` if the key does not exist. O(log n) time.

- **`assoc_insert(assoc, key, value)`** - Insert a new key-value pair or update an existing
  one. If the key already exists, its value is overwritten. If the array is full, it may
  need to be resized first. Maintains sorted order by shifting entries as needed.

- **`assoc_delete(assoc, key)`** - Remove a key-value pair from the array. Shifts
  subsequent entries to fill the gap.

- **`assoc_copy(dest, src)`** - Deep copy an associative array. Allocates new storage for
  the destination and copies all keys and values.

- **`assoc_load(stream, assoc)`** - Deserialize an associative array from a DB file stream.
  Reads the entry count, key lengths, and values from the stream.

- **`assoc_save(stream, assoc)`** - Serialize an associative array to a DB file stream.
  Writes all entries in a format that `assoc_load` can reconstruct.

**Usage:** Associative arrays are used for configuration files, GCD (Game Configuration
Data) files, and various runtime lookup tables throughout the engine.

---

## 4. Color and Palette System (`plib/color/color.cc/h`)

### Overview

Fallout uses a 256-color indexed palette (VGA-style). Every pixel on screen is an 8-bit
index into a 256-entry color palette. The color system manages this palette and provides
pre-computed lookup tables for fast color operations (blending, intensity adjustment, color
matching).

### Palette Management

- **`initColors()`** - Initialize the color system. Allocates lookup tables and sets up
  the default palette.

- **`colorsClose()`** - Shut down the color system. Frees all lookup tables and palette
  data.

- **`setSystemPalette(palette)`** - Set the entire 256-color system palette. The palette
  is an array of 768 bytes (256 entries x 3 components: R, G, B, each 0-63 in VGA range).
  Rebuilds affected lookup tables.

- **`getSystemPalette(palette)`** - Copy the current system palette into the caller's
  buffer.

- **`setBlackSystemPalette()`** - Set all palette entries to black (0,0,0). Used as the
  first step in fade-in transitions.

- **`setSystemPaletteEntries(palette, start, count)`** - Set a range of palette entries
  starting at index `start`, updating `count` entries.

- **`getSystemPaletteEntry(index, &r, &g, &b)`** - Retrieve the R, G, B components of a
  single palette entry.

- **`fadeSystemPalette(target_palette, steps)`** - Animate a smooth fade from the current
  palette to a target palette over the specified number of steps. Each step interpolates
  all 256 entries. This is used for screen transitions (fade to black, fade in from black,
  cross-fade between palettes).

### Color Tables (Pre-computed Lookup)

These tables are the heart of the color system's performance. They are computed once when
a palette is loaded and allow O(1) color operations during rendering.

- **`colorTable[32768]`** - The master color-matching table. Maps any 15-bit RGB value
  (5 bits per channel, 32768 entries) to the closest 8-bit palette index. Used by
  `RGB2Color` and whenever the engine needs to find the nearest palette color for an
  arbitrary RGB value.

- **`colorMixAddTable[256][256]`** - Additive color blending table. Given two palette
  indices, returns the palette index of their additive blend. Used for light effects,
  explosions, energy weapons. `colorMixAddTable[a][b]` gives the index of `clamp(color_a + color_b)`.

- **`colorMixMulTable[256][256]`** - Multiplicative color blending table. Given two palette
  indices, returns the palette index of their multiplicative blend. Used for shadows and
  darkening effects. `colorMixMulTable[a][b]` gives the index of `(color_a * color_b) / max`.

- **`intensityColorTable[256][256]`** - Intensity adjustment table. The first index is the
  palette color, the second is the intensity level (0-255). Returns the palette index of the
  color at the given intensity. Used for lighting calculations and distance fog.

- **`mappedColor[256]`** - Gamma-corrected palette mapping. Maps each palette index to
  its gamma-corrected equivalent index.

- **`cmap[768]`** - The current raw 256-color palette stored as a flat array of 768 bytes
  (R0, G0, B0, R1, G1, B1, ..., R255, G255, B255). Each component is in the range 0-63
  (VGA 6-bit per channel).

### Color Operations

- **`colorMixAdd(a, b)`** - Return the palette index of the additive blend of palette
  colors `a` and `b`. Performs a lookup in `colorMixAddTable`.

- **`colorMixMul(a, b)`** - Return the palette index of the multiplicative blend of
  palette colors `a` and `b`. Performs a lookup in `colorMixMulTable`.

- **`RGB2Color(r, g, b)`** - Convert an RGB triplet to the nearest palette index. Quantizes
  each channel to 5 bits and looks up in `colorTable`.

- **`Color2RGB(index, &r, &g, &b)`** - Convert a palette index to its RGB components by
  reading from `cmap`.

- **`calculateColor(r, g, b)`** - Compute a color value from RGB, used during table
  construction.

### Gamma Correction

- **`colorGamma(gamma)`** - Set the gamma correction level. Rebuilds the `mappedColor`
  table to apply the new gamma curve.

- **`colorGetGamma()`** - Return the current gamma correction level.

- **`colorMappedColor(index)`** - Return the gamma-corrected palette index for a given
  original palette index. Looks up in `mappedColor`.

### Palette Stack

- **`colorPushColorPalette()`** - Push the current palette onto an internal stack. Used
  to save the palette state before a temporary change (e.g., entering a special screen or
  viewing an item close-up).

- **`colorPopColorPalette()`** - Pop and restore the previously pushed palette from the
  stack.

### Blend Tables

- **`getColorBlendTable(color)`** - Get or compute a blend table for a specific color.
  These tables pre-compute the result of blending every palette entry with the specified
  color at various intensities. Used for translucent effects (glass, force fields, ghost
  critters).

- **`freeColorBlendTable(color)`** - Free the blend table for a specific color when it is
  no longer needed.

- **`loadColorTable(path)`** - Load a pre-computed color table from a `.col` file on disk.
  Some color tables are too expensive to compute at runtime and are shipped as data files.

### Callbacks

- **`colorInitIO(read_func, ...)`** - Register custom file I/O functions for the color
  system to use when loading palette and table files. Allows the color system to read from
  DAT archives via the DB module.

- **`colorSetNameMangler(mangler_func)`** - Register a path mangling function that
  transforms file paths before opening. Used for localization or platform-specific path
  adjustments.

- **`colorSetFadeBkFunc(callback)`** - Register a callback that is invoked on each frame
  during `fadeSystemPalette`. Allows the game to continue updating the display (e.g.,
  redrawing the scene) while a palette fade is in progress.

- **`colorRegisterAlloc(malloc_func, realloc_func, free_func)`** - Register custom memory
  allocators for the color system's internal allocations.

---

## 5. Configuration Files (`game/config.cc/h`)

### Overview

The configuration system handles INI-style configuration files used for game settings.
The primary configuration files are:

- **`fallout.cfg`** - Main game configuration (screen resolution, sound settings, game
  preferences, etc.)
- **`f1_res.ini`** - Resolution and display settings (added by high-resolution patch / CE)

Configuration files use a `[Section] / key=value` format:

```ini
[sound]
music_path1=sound\music\
music_path2=sound\music\
sounds=1
music=1
speech=1

[system]
master_db_file=master.dat
critter_db_file=critter.dat
```

### API

- **`config_init(config)`** - Initialize a configuration structure. Must be called before
  any other config operations.

- **`config_exit(config)`** - Free all memory associated with a configuration structure.

- **`config_load(config, path, create_if_missing)`** - Load a configuration file from disk.
  Parses all sections, keys, and values. If the file does not exist and
  `create_if_missing` is true, creates an empty configuration.

- **`config_save(config, path, create_if_missing)`** - Write the current configuration
  state to disk in INI format.

- **`config_get_string(config, section, key, &value)`** - Retrieve a string value. Returns
  `true` if the key exists in the specified section.

- **`config_get_int(config, section, key, &value)`** - Retrieve an integer value. The
  string value is parsed as a decimal integer.

- **`config_get_double(config, section, key, &value)`** - Retrieve a floating-point value.
  The string value is parsed as a double.

- **`config_set_string(config, section, key, value)`** - Set a string value. Creates the
  section and key if they do not exist.

- **`config_set_int(config, section, key, value)`** - Set an integer value (stored as its
  string representation).

- **`config_set_double(config, section, key, value)`** - Set a floating-point value (stored
  as its string representation).

### Implementation Detail

Internally, each section is stored as an associative array (`assoc`) of key-value string
pairs, and the configuration itself is an associative array of sections. This means all
lookups within a section are O(log n) by binary search.

---

## 6. Message Files (`game/message.cc/h`)

### Overview

Message files provide all localized text strings used throughout the game. Every piece of
in-game text -- dialog, item descriptions, skill names, UI labels, error messages -- comes
from `.msg` files. This design allows easy localization: translate the `.msg` files and
the game displays in a new language.

### File Format

Message files are plain text with one message per entry:

```
{100}{}{Welcome to Vault 13.}
{101}{}{You see a large metal door.}
{102}{}{The door is locked.}
```

Each entry has three fields in braces:
1. **Message ID** (integer) - unique within the file
2. **Audio filename** (string, often empty) - associated voice file
3. **Message text** (string) - the actual text content

### API

- **`message_init(message_list)`** - Initialize a `MessageList` structure. Must be called
  before loading.

- **`message_exit(message_list)`** - Free a `MessageList` and all its messages.

- **`message_load(message_list, path)`** - Load a `.msg` file from disk (via the DB
  system). Parses all entries into the message list.

- **`message_unload(message_list)`** - Unload all messages from a list without
  destroying the list structure itself.

- **`message_search(message_list, message)`** - Find a message by ID. The caller sets the
  `num` field of the `message` structure, and on success the `text` and `audio` fields are
  populated. Returns a pointer to the found message entry, or `NULL` if not found.

### MessageList Structure

The `MessageList` structure contains:
- An array of `MessageListItem` entries, each with:
  - `num` - the message ID number
  - `audio` - the associated audio filename (may be empty)
  - `text` - the message text string
- Count of loaded messages
- Messages are sorted by ID for efficient binary search lookup

### Usage Pattern

```c
MessageList messageList;
MessageListItem message;

message_init(&messageList);
message_load(&messageList, "game\\pro_item.msg");

message.num = 100;
if (message_search(&messageList, &message)) {
    printf("%s\n", message.text);  // "Welcome to Vault 13."
}

message_exit(&messageList);
```

---

## 7. Prototype File Format

### Overview

Prototypes define the templates for all game objects -- items, critters, scenery, walls,
tiles, and miscellaneous objects. Every object in the game world is an instance of a
prototype. Prototypes are loaded from `.pro` (prototype) files organized by type in the
`proto/` directory.

### File Organization

```
proto/
  items/       # Item prototypes (.pro) - weapons, armor, ammo, drugs, etc.
  critters/    # Critter prototypes (.pro) - NPCs, monsters, the player
  scenery/     # Scenery prototypes (.pro) - furniture, debris, elevators, ladders
  walls/       # Wall prototypes (.pro) - wall segments
  tiles/       # Tile prototypes (.pro) - floor and roof tiles
  misc/        # Misc prototypes (.pro) - spatial scripts, exit grids
```

### Prototype ID (PID)

Every prototype has a unique PID that encodes both its type and its index:

- Bits 24-27: Object type (0=item, 1=critter, 2=scenery, 3=wall, 4=tile, 5=misc)
- Bits 0-23: Index within the type (the file number)

For example, PID `0x00000032` is item #50, while PID `0x01000010` is critter #16.

### Proto Structure (Common Fields)

All prototypes share these common header fields:

- **`pid`** - Prototype ID (type + index encoding described above).
- **`message_id`** - Reference to the prototype's name and description text in the
  corresponding `.msg` file (e.g., `pro_item.msg` for items).
- **`fid`** - Frame ID referencing the graphical art (FRM file) used to display this
  object. The FID encodes the art type, index, and any variation.
- **`light_distance`** - How far this object emits light (in hexagonal tiles). 0 means
  no light emission.
- **`light_intensity`** - Brightness of emitted light (0-65536 range).
- **`flags`** - General object flags (e.g., flat, no-block, no-highlight, wall-trans-end,
  light-thru).
- **`extended_flags`** - Additional flags specific to the object type.

### Type-Specific Fields

**Items** additionally store: item type (weapon/armor/ammo/drug/container/misc), weight,
cost, material, weapon damage, armor stats, ammo data, etc.

**Critters** additionally store: base stats (SPECIAL attributes), skills, hit points,
action points, armor class, sequence, healing rate, critical chance, body type, kill type,
AI packet, team number.

**Scenery** additionally store: scenery type (door/stairs/elevator/ladder/generic), action
flags, sound ID.

**Walls** additionally store: wall flags (light-thru, shoot-thru).

**Tiles** additionally store: material ID.

**Misc** has only the common fields.

---

## 8. Art / Frame File Format

### Overview

FRM (Frame) files contain all the 2D sprite graphics used in the game: character animations,
item art, scenery, interface elements, and more. Each FRM file can contain multiple frames
organized by direction (orientation).

### Art Structure

The FRM file header contains:

- **`version`** - File format version (always 4).
- **`framesPerSecond`** - Animation playback speed in frames per second.
- **`actionFrame`** - The frame index within the animation that corresponds to the "action
  point" (e.g., the frame where a weapon fires, a punch connects, or a door is fully open).
- **`frameCount`** - Total number of frames per direction.

### Direction Data

Each FRM file supports up to **6 directions** (orientations), numbered 0-5, corresponding
to the hexagonal grid directions:

- 0: Northeast
- 1: East
- 2: Southeast
- 3: Southwest
- 4: West
- 5: Northwest

For each direction, the header stores:

- **`shiftX[dir]`** - Horizontal pixel offset for the entire animation in this direction.
- **`shiftY[dir]`** - Vertical pixel offset for the entire animation in this direction.
- **`dataOffset[dir]`** - Byte offset from the start of the frame data section to this
  direction's frame data.

Not all FRM files use all 6 directions. Static objects (items, scenery) typically have only
direction 0. Critter animations use all 6 directions.

### Frame Data

Each individual frame within a direction contains:

- **`width`** - Frame width in pixels.
- **`height`** - Frame height in pixels.
- **`size`** - Total pixel data size (`width * height`).
- **`offsetX`** - Horizontal pixel offset of this frame relative to the animation center.
- **`offsetY`** - Vertical pixel offset of this frame relative to the animation center.
- **`pixel data`** - Raw 8-bit indexed pixel data, row by row, top to bottom. Each byte
  is a palette index (0-255). Index 0 is typically transparent.

### Frame ID (FID)

Analogous to PID for prototypes, each art resource is referenced by a FID that encodes:

- Bits 24-27: Art type (0=item, 1=critter, 2=scenery, 3=wall, 4=tile, 5=misc,
  6=interface, 7=inventory, 8=head, 9=background, 10=skilldex)
- Bits 0-11: Art index (file number within the type)
- Bits 12-15: Animation code (for critters: walk, run, attack, etc.)
- Bits 16-23: Weapon code (for critters: what weapon they are holding)

---

## 9. Map File Format

### Overview

Map files (`.map`) define the game world areas. Each map contains tile data, placed objects,
scripts, and spatial triggers. Maps are stored in the `maps/` directory within the DAT
archive.

### MapHeader

The map file begins with a header structure:

- **`version`** - Map format version.
- **`name`** - Map filename (null-terminated string).
- **`entering_tile`** - The default tile index where the player enters the map.
- **`entering_elevation`** - The default elevation (0-2) for the entering tile.
- **`entering_rotation`** - The default facing direction for the player on entry.
- **`num_local_vars`** - Number of local script variables stored in the map.
- **`script_id`** - The map's own script (controls random encounters, ambient events, etc.).
- **`flags`** - Map flags (e.g., save-on-enter, dead-bodies-age).
- **`darkness`** - Ambient light level.
- **`num_global_vars`** - Number of global variable references.

### Elevation Data

Fallout maps support up to **3 elevations** (floors), numbered 0-2. Each elevation
contains:

- **Floor tile grid** - A 100x100 grid of tile indices (10000 tiles total). Each entry is
  a 16-bit value referencing a tile art FRM.
- **Roof tile grid** - A matching 100x100 grid for roof tiles. Roof tiles are drawn over
  objects when the player is on a lower elevation.

### Object List

After the tile data, the map stores all placed objects organized by elevation. Each object
record contains:

- Object position (tile index, elevation)
- Prototype ID (PID) referencing the object's prototype
- Frame ID (FID) and current frame number
- Direction/orientation
- Object flags and state
- Type-specific data (inventory for containers/critters, combat data, etc.)

### Script Data

Maps can contain multiple types of scripts:

- **Spatial scripts** - Triggered when the player enters specific tiles.
- **Timed scripts** - Triggered after a delay.
- **Object scripts** - Attached to specific objects.

### Map Local Variables

Local variables are script-accessible integers stored per-map. They persist within a play
session and are saved with the game state. Used for tracking quest progress, door states,
and other map-specific conditions.

### Map Global Variable References

Maps reference global variables that are shared across all maps. These track game-wide
state: quest completions, faction reputations, time-dependent events.

---

## 10. Save File Format

### Overview

Save games are stored in the `SAVEGAME/` directory, with each save slot in a numbered
subdirectory:

```
SAVEGAME/
  SLOT01/
    SAVE.DAT     # Main save file
    <map files>  # Saved state of visited maps
  SLOT02/
    SAVE.DAT
    ...
```

### SAVE.DAT Structure

The main save file contains serialized state from multiple game subsystems, written
sequentially:

1. **Save header** - Slot description, character name, save date/time, thumbnail image.
2. **Player state** - Player object data, current stats, position, HP, AP, level, XP.
3. **Map state** - Current map, elevation, tile position, visited map list.
4. **Object states** - All active game objects and their current state (position,
   inventory, flags, combat state).
5. **Script states** - All running scripts and their local variable values, timers, and
   execution state.
6. **Combat state** - If combat is in progress: turn order, current combatant, combat
   flags.
7. **World state** - Game time, global variables, world map state, encounter tables.
8. **Party member state** - Companion NPCs, their inventories, and current orders.

### Serialization Pattern

Each subsystem implements its own `save` and `load` functions following a consistent
pattern:

```c
int game_save(DB_FILE* stream) {
    // Write subsystem header/version
    db_fwriteInt(stream, SAVE_VERSION);
    // Write each field using typed I/O
    db_fwriteInt(stream, game_time);
    db_fwriteInt(stream, num_global_vars);
    db_fwriteIntCount(stream, global_vars, num_global_vars);
    // ... etc
    return 0;  // success
}

int game_load(DB_FILE* stream) {
    int version;
    db_freadInt(stream, &version);
    db_freadInt(stream, &game_time);
    // ... etc
    return 0;
}
```

### Map State Files

In addition to `SAVE.DAT`, each save slot contains copies of map files for every map the
player has visited. These contain the modified state of objects, scripts, and tiles on those
maps (doors opened, items taken, NPCs killed, etc.). When the player revisits a map, the
saved version is loaded instead of the pristine version from the DAT archive.

---

## 11. Platform Compatibility (`platform_compat.cc/h`)

### Overview

The platform compatibility layer abstracts operating system differences behind a consistent
API. The original Fallout was a Windows-only DOS/Win32 application. The Community Edition
must run on Windows, Linux, and macOS. This module provides portable wrappers for string
operations, file I/O, path manipulation, and time functions.

### String Operations

- **`compat_stricmp(s1, s2)`** - Case-insensitive string comparison. Equivalent to
  `_stricmp` on Windows or `strcasecmp` on POSIX. Returns 0 if strings are equal
  (ignoring case), negative if `s1 < s2`, positive if `s1 > s2`.

- **`compat_strnicmp(s1, s2, n)`** - Case-insensitive comparison of at most `n` characters.
  Equivalent to `_strnicmp` on Windows or `strncasecmp` on POSIX.

- **`compat_strupr(s)`** - Convert a string to uppercase in-place. Returns the string
  pointer.

- **`compat_strlwr(s)`** - Convert a string to lowercase in-place. Returns the string
  pointer.

- **`compat_itoa(value, buf, radix)`** - Convert an integer to a string representation
  in the given radix (base). Equivalent to `_itoa` on Windows. On POSIX, implemented
  manually using `sprintf` or division loops.

### Path Manipulation

- **`compat_splitpath(path, drive, dir, fname, ext)`** - Split a full file path into its
  components: drive letter, directory, filename, and extension. Equivalent to
  `_splitpath` on Windows. On POSIX, drive is always empty.

- **`compat_makepath(path, drive, dir, fname, ext)`** - Construct a full file path from
  components. Equivalent to `_makepath` on Windows.

- **`compat_windows_path_to_native(path)`** - Convert backslash (`\`) path separators to
  the native platform separator (forward slash `/` on POSIX). The original game data uses
  backslashes throughout. This function normalizes paths for the host OS.

- **`compat_resolve_path(path)`** - Normalize a file path: resolve `.` and `..` segments,
  collapse multiple separators, and ensure consistent case handling on case-sensitive
  filesystems. On case-sensitive systems (Linux), this may search the filesystem to find
  the correct case for each path component.

### File I/O

- **`compat_fopen(path, mode)`** - Open a file, applying path normalization. On Linux,
  performs case-insensitive path resolution since the game data files may have inconsistent
  case (a file referenced as `ART\CRITTERS\HMWARRAA.FRM` might be stored as
  `art/critters/hmwarraa.frm`).

- **`compat_read(fd, buf, size)`** / **`compat_write(fd, buf, size)`** - Low-level
  read/write on a file descriptor.

- **`compat_lseek(fd, offset, origin)`** / **`compat_tell(fd)`** - Low-level seek and
  tell on a file descriptor.

- **`compat_filelength(fd)`** - Return the total size of a file given its file descriptor.
  On Windows, uses `_filelength`. On POSIX, uses `fstat`.

- **`compat_remove(path)`** - Delete a file, applying path normalization.

- **`compat_rename(old_path, new_path)`** - Rename or move a file, applying path
  normalization to both paths.

- **`compat_mkdir(path)`** - Create a directory, applying path normalization. Creates only
  the leaf directory (does not create intermediate directories).

### Time

- **`compat_timeGetTime()`** - Return the current time in milliseconds since an arbitrary
  epoch. On Windows, wraps `timeGetTime()`. On POSIX, uses `clock_gettime` with
  `CLOCK_MONOTONIC`. Used throughout the engine for animation timing, input delays, and
  performance measurement.

---

## Summary of File Extensions

| Extension | Description                         | Module           |
|-----------|-------------------------------------|------------------|
| `.dat`    | DAT archive (master.dat, critter.dat) | db             |
| `.frm`    | Frame / sprite animation            | art              |
| `.pro`    | Prototype definition                | proto            |
| `.map`    | Game map                            | map              |
| `.msg`    | Message / text strings              | message          |
| `.cfg`    | Configuration file (INI format)     | config           |
| `.ini`    | Configuration file (INI format)     | config           |
| `.col`    | Pre-computed color table            | color            |
| `.pal`    | Palette file (768 bytes)            | color            |
| `.gam`    | Game global data                    | game             |
| `.sav`    | Save game data                      | save             |
| `.acm`    | ACM compressed audio                | sound            |
| `.mve`    | MVE video (Interplay format)        | movie            |
| `.int`    | Compiled script bytecode            | interpreter      |
| `.ssl`    | Script source (not shipped)         | --               |
