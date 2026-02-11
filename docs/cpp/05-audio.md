# 05 - Audio System

Developer documentation for the Fallout 1 Community Edition C++ audio system.

---

## 1. Audio Architecture Overview

The audio system is organized into three layers, each with a distinct responsibility:

```
+------------------------------------------------------------+
|  Game Sound Manager  (game/gsound.cc/h)                    |
|  High-level: music, speech, SFX, volume policy, name build |
+------------------------------------------------------------+
         |                          |
         v                          v
+----------------------------+  +--------------------------+
| Script Audio I/O           |  | Sound Effect Cache       |
| (int/audio.cc, audiof.cc)  |  | (game/sfxcache.cc/h)     |
| ACM decompression          |  | + Sound Effect List      |
+----------------------------+  |   (game/sfxlist.cc/h)    |
         |                      +--------------------------+
         v                          |
+------------------------------------------------------------+
|  Sound Engine  (int/sound.cc/h)                            |
|  Mid-level: buffer allocation, playback, fade, update loop |
+------------------------------------------------------------+
         |
         v
+------------------------------------------------------------+
|  Audio Engine / SDL2 Backend  (audio_engine.cc/h)          |
|  Low-level: SDL2 audio device, circular buffers, mixing    |
+------------------------------------------------------------+
```

**Game Sound Manager** -- Knows about game concepts (weapons, critters, ambient sounds, music tracks). Constructs file paths, applies volume policies, manages enable/disable states for music, speech, and SFX channels. Delegates actual sound playback to the Sound Engine.

**Sound Engine** -- Manages a linked list of `Sound` objects. Handles buffer preloading, streaming refill, looping, fading, pause/unpause, and a periodic update loop. Uses pluggable file I/O callbacks, so the same engine works with both raw file handles and compressed ACM streams.

**Audio Engine** -- A thin compatibility shim that replaces the original DirectSound API with SDL2. Manages a fixed pool of 8 `AudioEngineSoundBuffer` slots, each with its own `SDL_AudioStream` for sample-rate conversion. A single SDL audio callback (`audioEngineMixin`) mixes all active buffers into the output stream.

In parallel, there is also a movie audio path:

**Movie Library** (`movie_lib.cc`) -- Low-level Interplay MVE codec that decodes interleaved audio/video frames. Audio is fed directly to the Audio Engine via `movieLibSetVolume`.

**Movie Interface** (`int/movie.cc`) -- Mid-level wrapper that opens MVE files from the game database, manages subtitles, palette changes, and frame blitting.

**Game Movie Wrapper** (`game/gmovie.cc`) -- High-level API that maps game cinematic IDs to `.mve` file names and coordinates music pause/stop, palette fades, and subtitle configuration.

---

## 2. Game Sound Manager (game/gsound.cc / game/gsound.h)

Source addresses are original Fallout 1 offsets preserved in the CE source as comments (e.g., `// 0x4475A0`).

### 2.1. Initialization and Lifecycle

```cpp
int gsound_init();      // 0x4475A0 -- full initialization
void gsound_reset();    // 0x447A94 -- stop everything, flush cache
int gsound_exit();      // 0x447B74 -- tear down sound system
```

`gsound_init` performs the following steps in order:

1. Reads the `[sound]` section of `fallout.cfg` via `configGetBool` / `config_get_value`.
2. Resolves two music search paths (`music_path1`, `music_path2`) from config. Music files are searched on `music_path1` first; if not found, `music_path2` is tried (and optionally copied to `music_path1` -- the "copy" path, used for CD installations).
3. Calls `soundRegisterAlloc` to plug in the GNW memory allocator (`mem_malloc`, `mem_realloc`, `mem_free`).
4. Calls `soundInit(detectDevices, 24, 0x8000, 0x8000, 22050)` -- 24 buffers, 32 KB data size, 32 KB total buffer, 22050 Hz sample rate.
5. Initializes the two Audio file I/O layers (`initAudiof`, `initAudio`) with `gsound_compressed_query` (always returns `true`, meaning all audio files are treated as compressed ACM).
6. Reads `cache_size` from config and initializes the SFX cache (`sfxc_init`). The cache size is in kilobytes, shifted left by 10 to get bytes.
7. Sets the default file I/O for the Sound Engine to route through the game database (`db_fopen`, `db_fread`, etc.).
8. Registers `gsound_bkg_proc` as a background process via `add_bk_process`. This function is called every game tick and simply calls `soundUpdate()`.
9. Reads and applies enable/disable and volume settings for SFX, music, and speech.

`gsound_reset` stops speech, restores background music if it was disabled due to zero volume, stops background music, flushes all sounds and the SFX cache, and resets the active effect counter.

`gsound_exit` removes the background process, stops speech and background music, removes any copied music file, then calls `soundClose`, `sfxc_exit`, `audiofClose`, and `audioClose`.

### 2.2. Background Music

Background music uses **streaming ACM** files. Music is loaded from `sound\music\` or a configurable path.

```cpp
int gsound_background_play(const char* fileName, int a2, int a3, int a4);
```

Parameters:
- `fileName` -- base name without path or extension (e.g., `"07desert"`)
- `a2` -- playback mode: `10` = preload only (do not start), `11` = set read limit before load, `12` = normal start
- `a3` -- storage mode: `13` = find without copy (streaming from path), `14` = find with copy (copy from CD path to local path)
- `a4` -- loop mode: `15` = no loop (fire-and-forget), `16` = loop forever (`0xFFFF`)

The function:
1. Stops any currently playing background music.
2. Allocates a Sound object with `gsound_background_allocate`.
3. Sets file I/O to the `audiof` (Fallout-specific compressed) functions.
4. Sets the channel to stereo (channel 3 maps to 2 channels in the Sound Engine).
5. Finds the file using the copy or no-copy path strategy.
6. Optionally sets looping to `0xFFFF` (infinite).
7. Sets the completion callback to `gsound_internal_background_callback`.
8. Loads the sound data with `soundLoad`.
9. Starts playback with `gsound_background_start` (which applies volume scaling at 94% of `background_volume`).

```cpp
int gsound_background_play_level_music(const char* a1, int a2);
    // Convenience: calls gsound_background_play(a1, a2, 14, 16)
    // i.e., copy-enabled, looping

int gsound_background_play_preloaded();
    // Start playing a previously preloaded (a2=10) background sound

void gsound_background_stop();
    // If fade is enabled, fades to 0 over 2000ms; otherwise deletes immediately

void gsound_background_restart_last(int value);
    // Re-plays the last requested background track

void gsound_background_pause();
void gsound_background_unpause();
```

**Fade support**: When `gsound_background_fade` is non-zero, `gsound_background_stop` uses `soundFade(tag, 2000, 0)` instead of immediate deletion. Similarly, `gsound_background_start` fades in from volume 1 to the target volume over 2000 ms.

```cpp
void gsound_background_fade_set(int value);
int gsound_background_fade_get();
int gsound_background_fade_get_set(int value); // returns old value
```

**Callback**: An external callback can be registered for when background music finishes:

```cpp
void gsound_background_callback_set(SoundEndCallback* callback);
SoundEndCallback* gsound_background_callback_get();
SoundEndCallback* gsound_background_callback_get_set(SoundEndCallback* callback);
```

The internal callback `gsound_internal_background_callback` is called by the Sound Engine when playback completes (event code `1`). It sets `gsound_background_tag` to NULL and invokes the registered external callback.

**Volume**:

```cpp
void gsound_background_volume_set(int volume);
int gsound_background_volume_get();
int gsound_background_volume_get_set(int volume); // returns old value
```

Background volume is applied at 94% scaling: `soundVolume(tag, (int)(background_volume * 0.94))`. When the volume is set to 0 (or master volume is 0), background music is automatically disabled. It is automatically re-enabled when a non-zero volume is restored.

**Length**:

```cpp
int gsound_background_length_get(); // returns soundLength(gsound_background_tag)
```

### 2.3. Speech

Speech follows a similar pattern to background music but uses the `audio` (standard compressed) I/O layer rather than `audiof`, and reads from `sound\speech\`.

```cpp
int gsound_speech_play(const char* fname, int a2, int a3, int a4);
int gsound_speech_play_preloaded();
void gsound_speech_stop();
void gsound_speech_pause();
void gsound_speech_unpause();
```

Speech volume is applied at 69% scaling: `soundVolume(tag, (int)(speech_volume * 0.69))`.

```cpp
void gsound_speech_volume_set(int volume);
int gsound_speech_volume_get();
int gsound_speech_volume_get_set(int volume);
```

Speech also supports a completion callback:

```cpp
void gsound_speech_callback_set(SoundEndCallback* callback);
SoundEndCallback* gsound_speech_callback_get();
SoundEndCallback* gsound_speech_callback_get_set(SoundEndCallback* callback);
int gsound_speech_length_get();
```

Speech is used for dialog playback with lip-sync integration (see `game/lip_sync.cc/h`).

```cpp
void gsound_speech_enable();
void gsound_speech_disable();
int gsound_speech_is_enabled();
```

### 2.4. Sound Effects

The SFX subsystem manages up to `SOUND_EFFECTS_MAX_COUNT` (4) simultaneously active effects.

```cpp
Sound* gsound_load_sound(const char* name, Object* object);
```

This is the main SFX loading function. It:
1. Checks the active effect counter against the maximum.
2. Calls `gsound_get_sound_ready_for_effect` which allocates a Sound object (type `5` = `SOUND_TYPE_FIRE_AND_FORGET | SOUND_TYPE_MEMORY`, flags `10`), sets file I/O to either the SFX cache (`sfxc_cached_*`) or the standard audio I/O (`audio*`), and registers `gsound_internal_effect_callback` for automatic cleanup.
3. Constructs the full path: `sound\sfx\<name>.ACM`.
4. Attempts `soundLoad`. If it fails and the object is a critter, tries gender-specific fallbacks (`HF` -> `HM`, etc.) and alias lookups (`MALIEU` -> `MAMTNT`).
5. On success, increments `gsound_active_effect_counter`.

The effect callback (`gsound_internal_effect_callback`) decrements the counter when the sound finishes (event code `1`).

```cpp
Sound* gsound_load_sound_volume(const char* name, Object* object, int volume);
    // Loads a sound and sets volume to (volume * sndfx_volume) / VOLUME_MAX

void gsound_delete_sfx(Sound* sound);
    // Manually delete a sound effect (only if not playing)

int gsound_play_sound(Sound* sound);
    // Play a previously loaded sound

int gsnd_anim_sound(Sound* sound, void* a2);
    // Play sound during animation (called from anim system)

int gsound_play_sfx_file(const char* name);
    // Load and immediately play a sound effect by name

int gsound_play_sfx_file_volume(const char* name, int volume);
    // Load and play with specific volume
```

**Distance attenuation**:

```cpp
int gsound_compute_relative_volume(Object* obj);
```

Computes a volume multiplier (0 to `0x7FFF`) based on the object's distance from the player (`obj_dude`) relative to the player's Perception stat:
- Within Perception range and on-screen: `0x7FFF` (full volume)
- Between 1x and 2x Perception range: linear falloff from `0x7FFF` to `0x2AAA`
- Beyond 2x Perception: `0x2AAA` (minimum)

**Enable/disable**:

```cpp
void gsound_sfx_enable();
void gsound_sfx_disable();
int gsound_sfx_is_enabled();
```

### 2.5. Master Volume

```cpp
int gsound_set_master_volume(int volume);
int gsound_get_master_volume();
```

Volume range: `VOLUME_MIN` (0) to `VOLUME_MAX` (`0x7FFF` = 32767).

Setting master volume to 0 automatically disables background music (tracked via `gsound_background_df_vol` flag). Restoring a non-zero master volume re-enables it.

```cpp
int gsound_set_sfx_volume(int volume);
int gsound_get_sfx_volume();
```

SFX volume is stored locally and applied when effects are loaded. It does not directly call into the Sound Engine for existing sounds.

### 2.6. Sound Name Builders

These functions construct standardized SFX file names from game data. They all write into a shared static buffer `sfx_file_name[13]` and return a pointer to it.

**Character/critter sounds**:

```cpp
char* gsnd_build_character_sfx_name(Object* a1, int anim, int extra);
```

Format: `<base_name><action_code><weapon_code>` (uppercase).
- Gets the base art name for the critter's FID.
- Maps animation and weapon slot to action/weapon codes via `art_get_code`.
- Special overrides: `ANIM_FALL_FRONT`/`ANIM_FALL_BACK` with `PASS_OUT` uses `'Y'`, with `DIE` uses `'Z'`. `ANIM_THROW_PUNCH`/`ANIM_KICK_LEG` with `CONTACT` uses `'Z'`.

**Ambient sounds**:

```cpp
char* gsnd_build_ambient_sfx_name(const char* a1);
```

Format: `A<name:6>1` (e.g., `"AWIND  1"`).

**Interface sounds**:

```cpp
char* gsnd_build_interface_sfx_name(const char* a1);
```

Format: `N<name:6>1` (e.g., `"NIB1P1X1"`).

**Weapon sounds**:

```cpp
char* gsnd_build_weapon_sfx_name(int effectType, Object* weapon, int hitMode, Object* target);
```

Format: `W<effectCode><weaponSoundCode><attackMode><materialCode>XX1`

- `effectCode`: `'R'` (Ready), `'A'` (Attack), `'O'` (Out of ammo), `'F'` (Firing/Flying), `'H'` (Hit)
- `weaponSoundCode`: from `item_w_sound_id(weapon)` (e.g., `'G'` for guns, `'L'` for lasers)
- `attackMode`: `1` for primary attacks/ready/out-of-ammo, `2` for secondary attacks
- `materialCode` (only for Hit): `'M'` (Metal/Glass/Plastic), `'W'` (Wood), `'S'` (Stone/Dirt/Cement), `'F'` (Flesh/default), `'X'` (no target or explosion/plasma/EMP)

**Scenery sounds**:

```cpp
char* gsnd_build_scenery_sfx_name(int actionType, int action, const char* name);
```

Format: `S<typeCode><actionCode><name:4>1`

- `typeCode`: `'A'` (Active) or `'P'` (Passive)
- `actionCode`: `'O'` (Open), `'C'` (Close), `'L'` (Lock), `'N'` (Unlock), `'U'` (Use)

**Door/container sounds**:

```cpp
char* gsnd_build_open_sfx_name(Object* object, int action);
```

For scenery (doors): `S<actionCode>DOORS<soundId>`
For items (containers): `I<actionCode>CNTNR<soundId>`

### 2.7. Sound Effect Enums (gsound.h)

```cpp
typedef enum WeaponSoundEffect {
    WEAPON_SOUND_EFFECT_READY,          // 'R'
    WEAPON_SOUND_EFFECT_ATTACK,         // 'A'
    WEAPON_SOUND_EFFECT_OUT_OF_AMMO,    // 'O'
    WEAPON_SOUND_EFFECT_AMMO_FLYING,    // 'F'
    WEAPON_SOUND_EFFECT_HIT,            // 'H'
    WEAPON_SOUND_EFFECT_COUNT,
} WeaponSoundEffect;

typedef enum ScenerySoundEffect {
    SCENERY_SOUND_EFFECT_OPEN,      // 'O'
    SCENERY_SOUND_EFFECT_CLOSED,    // 'C'
    SCENERY_SOUND_EFFECT_LOCKED,    // 'L'
    SCENERY_SOUND_EFFECT_UNLOCKED,  // 'N'
    SCENERY_SOUND_EFFECT_USED,      // 'U'
    SCENERY_SOUND_EFFECT_COUNT,
} ScenerySoundEffect;

typedef enum CharacterSoundEffect {
    CHARACTER_SOUND_EFFECT_UNUSED,
    CHARACTER_SOUND_EFFECT_KNOCKDOWN,
    CHARACTER_SOUND_EFFECT_PASS_OUT,
    CHARACTER_SOUND_EFFECT_DIE,
    CHARACTER_SOUND_EFFECT_CONTACT,
} CharacterSoundEffect;

typedef enum SoundEffectActionType {
    SOUND_EFFECT_ACTION_TYPE_ACTIVE,
    SOUND_EFFECT_ACTION_TYPE_PASSIVE,
} SoundEffectActionType;
```

### 2.8. UI Button Sound Callbacks

Pre-wired callbacks for common UI button presses and releases:

```cpp
void gsound_red_butt_press(int btn, int keyCode);    // plays "ib1p1xx1"
void gsound_red_butt_release(int btn, int keyCode);  // plays "ib1lu1x1"
void gsound_toggle_butt_press(int btn, int keyCode);  // plays "toggle"
void gsound_toggle_butt_release(int btn, int keyCode); // plays "toggle"
void gsound_med_butt_press(int btn, int keyCode);     // plays "ib2p1xx1"
void gsound_med_butt_release(int btn, int keyCode);   // plays "ib2lu1x1"
void gsound_lrg_butt_press(int btn, int keyCode);     // plays "ib3p1xx1"
void gsound_lrg_butt_release(int btn, int keyCode);   // plays "ib3lu1x1"
```

### 2.9. Internal Static State

| Variable | Type | Description |
|---|---|---|
| `gsound_initialized` | `bool` | Whether `gsound_init` has succeeded |
| `gsound_debug` | `bool` | Debug logging enabled (from config) |
| `gsound_background_enabled` | `bool` | Background music enabled |
| `gsound_speech_enabled` | `bool` | Speech enabled |
| `gsound_sfx_enabled` | `bool` | Sound effects enabled |
| `gsound_active_effect_counter` | `int` | Number of currently active SFX (max 4) |
| `gsound_background_tag` | `Sound*` | Current background music Sound object |
| `gsound_speech_tag` | `Sound*` | Current speech Sound object |
| `gsound_background_callback_fp` | `SoundEndCallback*` | External music completion callback |
| `gsound_speech_callback_fp` | `SoundEndCallback*` | External speech completion callback |
| `gsound_background_fade` | `int` | Whether background fading is active |
| `gsound_background_df_vol` | `int` | Flag: music was disabled due to zero volume |
| `master_volume` | `int` | Current master volume (0..0x7FFF) |
| `background_volume` | `int` | Current background music volume |
| `speech_volume` | `int` | Current speech volume |
| `sndfx_volume` | `int` | Current SFX volume |
| `sound_sfx_path` | `char*` | `"sound\\sfx\\"` |
| `sound_music_path1` | `char*` | Primary music path (local) |
| `sound_music_path2` | `char*` | Secondary music path (CD) |
| `sound_speech_path` | `char*` | `"sound\\speech\\"` |
| `background_fname_requested` | `char[260]` | Last requested background filename |
| `background_fname_copied` | `char[260]` | Last copied background filename |

### 2.10. Internal File I/O Bridge

The Game Sound Manager provides its own file I/O functions that route through the game database layer (`plib/db`):

```cpp
static int gsound_open(const char* fname, int flags);   // db_fopen("rb")
static int gsound_close(int fileHandle);                  // db_fclose
static int gsound_read(int fileHandle, void* buf, unsigned int size);   // db_fread
static int gsound_write(int fileHandle, const void* buf, unsigned int size);  // always returns -1
static long gsound_seek(int fileHandle, long offset, int origin);  // db_fseek + db_ftell
static long gsound_tell(int fileHandle);                  // db_ftell
static long gsound_filesize(int fileHandle);             // db_filelength
static long gsound_compressed_tell(int fileHandle);      // always returns -1
static bool gsound_compressed_query(char* filePath);     // always returns true
```

File handles are stored as integers by converting `DB_FILE*` pointers to `int` via `ptrToInt`/`intToPtr`.

---

## 3. Sound Engine (int/sound.cc / int/sound.h)

The Sound Engine is a general-purpose sound playback layer originally designed for the HMI Sound Operating System (SOS) on DOS, adapted in the CE to use SDL2 via the Audio Engine.

### 3.1. Sound Structure

```cpp
typedef struct Sound {
    SoundFileIO io;            // Pluggable file I/O callbacks + file descriptor
    unsigned char* data;       // Temporary read buffer (for streaming)
    int soundBuffer;           // Audio Engine buffer index (-1 if not allocated)
    int bitsPerSample;         // 8 or 16
    int channels;              // 1 (mono) or 2 (stereo)
    int rate;                  // Sample rate (typically 22050)
    int soundFlags;            // Combination of SoundFlags
    int statusFlags;           // Runtime state (SoundStatusFlags)
    int type;                  // Combination of SoundType
    int pausePos;              // Buffer position saved during pause
    int volume;                // Per-sound volume (0..0x7FFF)
    int loops;                 // Loop count (-1 = infinite, 0 = no loop)
    int field_54;              // Seek position for loop restart
    int field_58;              // Loop end position (-1 = no limit)
    int minReadBuffer;         // Minimum buffers to read before refill (default 1)
    int fileSize;              // Total file size
    int numBytesRead;          // Bytes read so far (tracks position in stream)
    int field_68;              // (unused)
    int readLimit;             // Maximum bytes to read per refresh cycle
    int lastUpdate;            // Last buffer section index that was refilled
    unsigned int lastPosition; // Last known read position in the audio buffer
    int numBuffers;            // Number of buffer sections
    int dataSize;              // Size of each buffer section
    int field_80;              // (unused)
    void* callbackUserData;    // User data for completion callback
    SoundCallback* callback;   // Completion callback (event 1 = done)
    void* deleteUserData;      // User data for delete callback
    SoundDeleteCallback* deleteCallback; // Called when Sound is being destroyed
    struct Sound* next;        // Linked list: next
    struct Sound* prev;        // Linked list: prev
} Sound;
```

All Sound objects are maintained in a doubly-linked list headed by `soundMgrList`.

### 3.2. Sound Types

```cpp
typedef enum SoundType {
    SOUND_TYPE_MEMORY       = 0x01,  // Entire file loaded into memory
    SOUND_TYPE_STREAMING    = 0x02,  // Data streamed in chunks
    SOUND_TYPE_FIRE_AND_FORGET = 0x04,  // Auto-deletes when done
    SOUND_TYPE_INFINITE     = 0x10,  // Loops forever (-1 loops)
    SOUND_TYPE_0x20         = 0x20,  // Special (used internally)
} SoundType;
```

When a sound is allocated with `SOUND_TYPE_STREAMING`, the engine creates a circular buffer of `numBuffers * dataSize` bytes and refills it incrementally. When allocated as `SOUND_TYPE_MEMORY`, the entire file is loaded into the audio buffer at once.

`SOUND_TYPE_FIRE_AND_FORGET` sounds are automatically deleted when playback completes (in `soundContinue`), rather than just being stopped.

### 3.3. Sound Flags

```cpp
typedef enum SoundFlags {
    SOUND_FLAG_0x02 = 0x02,    // Always set during allocation
    SOUND_FLAG_0x04 = 0x04,    // (unused in CE)
    SOUND_16BIT     = 0x08,    // 16-bit audio
    SOUND_8BIT      = 0x10,    // 8-bit audio
    SOUND_LOOPING   = 0x20,    // Looping playback
    SOUND_FLAG_0x80 = 0x80,    // Playback complete (buffer exhausted)
    SOUND_FLAG_0x100 = 0x100,  // Streaming: one-shot, stop after file ends
    SOUND_FLAG_0x200 = 0x200,  // Streaming: zeroed-out remainder (EOF reached)
} SoundFlags;
```

### 3.4. Status Flags

```cpp
typedef enum SoundStatusFlags {
    SOUND_STATUS_DONE       = 0x01,  // Playback finished
    SOUND_STATUS_IS_PLAYING = 0x02,  // Currently playing
    SOUND_STATUS_IS_FADING  = 0x04,  // Fade in progress
    SOUND_STATUS_IS_PAUSED  = 0x08,  // Currently paused
} SoundStatusFlags;
```

### 3.5. Error Codes

```cpp
typedef enum SoundError {
    SOUND_NO_ERROR                = 0,
    SOUND_SOS_DRIVER_NOT_LOADED   = 1,
    SOUND_SOS_INVALID_POINTER     = 2,
    SOUND_SOS_DETECT_INITIALIZED  = 3,
    SOUND_SOS_FAIL_ON_FILE_OPEN   = 4,
    SOUND_SOS_MEMORY_FAIL         = 5,
    SOUND_SOS_INVALID_DRIVER_ID   = 6,
    SOUND_SOS_NO_DRIVER_FOUND     = 7,
    SOUND_SOS_DETECTION_FAILURE   = 8,
    SOUND_SOS_DRIVER_LOADED       = 9,
    SOUND_SOS_INVALID_HANDLE      = 10,
    SOUND_SOS_NO_HANDLES          = 11,
    SOUND_SOS_PAUSED              = 12,
    SOUND_SOS_NO_PAUSED           = 13,
    SOUND_SOS_INVALID_DATA        = 14,
    SOUND_SOS_DRV_FILE_FAIL       = 15,
    SOUND_SOS_INVALID_PORT        = 16,
    SOUND_SOS_INVALID_IRQ         = 17,
    SOUND_SOS_INVALID_DMA         = 18,
    SOUND_SOS_INVALID_DMA_IRQ     = 19,
    SOUND_NO_DEVICE               = 20,
    SOUND_NOT_INITIALIZED         = 21,
    SOUND_NO_SOUND                = 22,
    SOUND_FUNCTION_NOT_SUPPORTED  = 23,
    SOUND_NO_BUFFERS_AVAILABLE    = 24,
    SOUND_FILE_NOT_FOUND          = 25,
    SOUND_ALREADY_PLAYING         = 26,
    SOUND_NOT_PLAYING             = 27,
    SOUND_ALREADY_PAUSED          = 28,
    SOUND_NOT_PAUSED              = 29,
    SOUND_INVALID_HANDLE          = 30,
    SOUND_NO_MEMORY_AVAILABLE     = 31,
    SOUND_UNKNOWN_ERROR           = 32,
    SOUND_ERR_COUNT,
} SoundError;
```

Error codes 1-19 are legacy SOS (Sound Operating System) codes. Codes 20-32 are used by the CE.

### 3.6. Lifecycle

```cpp
int soundInit(int a1, int num_buffers, int a3, int data_size, int sample_rate);
```

Initializes the Audio Engine via `audioEngineInit()`, stores the buffer configuration (number of buffers, data size, sample rate), and sets master volume to `VOLUME_MAX`. The `a1` parameter is the device selection (ignored in CE). The `a3` parameter is the total buffer size (unused in CE since buffers are sized from `num_buffers * data_size`).

```cpp
void soundClose();
```

Deletes all sounds in the manager list, removes the fade timer, frees the fade free list, and calls `audioEngineExit()`.

### 3.7. Allocation and Deletion

```cpp
Sound* soundAllocate(int type, int soundFlags);
```

Allocates a new Sound object, copies default file I/O, configures bits per sample (8 or 16 from flags), sets mono channel, sets the sample rate from the global, and inserts the sound at the head of `soundMgrList`. If `SOUND_TYPE_INFINITE` is set, automatically enables looping with `loops = -1`.

```cpp
int soundDelete(Sound* sound);
```

Closes the file I/O descriptor if open, then calls `soundMgrDelete` which:
1. Removes any active fade.
2. Stops playback.
3. Invokes the completion callback with event `1`.
4. Releases the audio engine buffer.
5. Invokes the delete callback.
6. Frees the data buffer.
7. Unlinks from the manager list.
8. Frees the Sound struct.

### 3.8. Loading and Data

```cpp
int soundLoad(Sound* sound, char* filePath);
```

Opens the file via the sound's I/O callbacks (using the name mangler), then calls `preloadBuffers`.

`preloadBuffers` determines the buffer strategy:
- **Streaming** (`SOUND_TYPE_STREAMING`): If the file fits in `numBuffers * dataSize`, uses the file-size-rounded buffer. Otherwise, uses the full buffer size. Adds `SOUND_FLAG_0x100 | SOUND_LOOPING` for one-shot streaming (looping buffer with stop-at-end flag).
- **Memory** (otherwise): Converts to `SOUND_TYPE_MEMORY`, loads the entire file.

After reading, creates the audio engine buffer via `soundSetData` and, for streaming sounds, allocates the temporary read buffer (`sound->data`).

```cpp
int soundSetData(Sound* sound, unsigned char* buf, int size);
```

Creates an `audioEngineCreateSoundBuffer` if needed, then locks and fills it via `addSoundData`.

```cpp
int soundRewind(Sound* sound);
```

Resets a sound to the beginning. For streaming sounds, re-seeks the file and re-preloads buffers.

### 3.9. Playback Control

```cpp
int soundPlay(Sound* sound);
```

If the sound is done, rewinds first. Applies volume, then calls `audioEngineSoundBufferPlay` with the looping flag if `SOUND_LOOPING` is set. Sets `SOUND_STATUS_IS_PLAYING` and increments `numSounds`.

```cpp
int soundStop(Sound* sound);
```

Calls `audioEngineSoundBufferStop`, clears `SOUND_STATUS_IS_PLAYING`, decrements `numSounds`.

```cpp
int soundContinue(Sound* sound);
```

The main update function called for each sound in the update loop. Checks the audio engine buffer status:
- If still playing and streaming, calls `refreshSoundBuffers` to refill the circular buffer.
- If stopped (buffer exhausted or flagged done):
  - If `SOUND_TYPE_FIRE_AND_FORGET`, auto-deletes the sound.
  - Otherwise, marks as done and stops.
  - Invokes the completion callback with event `1`.

```cpp
int soundPause(Sound* sound);
```

Saves the current buffer position to `pausePos`, sets `SOUND_STATUS_IS_PAUSED`, and stops playback.

```cpp
int soundUnpause(Sound* sound);
```

Restores the buffer position from `pausePos`, clears `SOUND_STATUS_IS_PAUSED`, and resumes playback.

### 3.10. Volume

```cpp
int soundSetMasterVolume(int volume);
```

Sets the global `masterVol` and reapplies volume to all sounds in the manager list.

```cpp
int soundVolume(Sound* sound, int volume);
```

Sets the per-sound volume. The actual value sent to the audio engine is:
```
normalizedVolume = soundVolumeHMItoDirectSound(masterVol * volume / VOLUME_MAX)
```

```cpp
int soundVolumeHMItoDirectSound(int volume);
```

Converts from HMI volume range (0..`VOLUME_MAX`) to SDL volume range (0..128):
```
result = (volume - VOLUME_MIN) / (VOLUME_MAX - VOLUME_MIN) * 128
```

```cpp
int soundGetVolume(Sound* sound);
```

Returns `sound->volume` (the logical volume, not the normalized value).

### 3.11. Fade

```cpp
int soundFade(Sound* sound, int duration, int targetVolume);
```

Starts a volume fade from the current volume to `targetVolume` over `duration` milliseconds. Internally uses `internalSoundFade` with `a4 = 0` (meaning: when fade reaches 0, stop the sound rather than pause it).

The fade system uses a linked list of `FadeSound` nodes and an SDL timer (`gFadeSoundsTimerId`) that fires every 40 ms. Each tick, `fadeSounds()` adjusts volumes by `deltaVolume`:
```
deltaVolume = 8 * (125 * (targetVolume - initialVolume)) / (40 * duration)
```

When a fade to 0 completes:
- If `field_14` (pause flag) is set, pauses and restores the initial volume.
- If `SOUND_TYPE_FIRE_AND_FORGET`, deletes the sound.
- Otherwise, stops the sound and sets volume to 0.

### 3.12. Query Functions

```cpp
bool soundPlaying(Sound* sound);  // SOUND_STATUS_IS_PLAYING set?
bool soundDone(Sound* sound);     // SOUND_STATUS_DONE set?
bool soundFading(Sound* sound);   // SOUND_STATUS_IS_FADING set?
bool soundPaused(Sound* sound);   // SOUND_STATUS_IS_PAUSED set?
int soundFlags(Sound* sound, int flags);   // sound->soundFlags & flags
int soundType(Sound* sound, int type);     // sound->type & type
int soundLength(Sound* sound);    // Duration in seconds: fileSize / (bitsPerSample/8 * rate)
int numSoundsPlaying();           // Global count of playing sounds
```

### 3.13. Seeking

```cpp
int soundGetPosition(Sound* sound);
int soundSetPosition(Sound* sound, int pos);
```

For streaming sounds, `soundSetPosition` adjusts both the audio buffer position and the file seek position, then calls `soundContinue` to refill.

### 3.14. Other Configuration

```cpp
int soundLoop(Sound* sound, int loops);
    // Set loop count. 0 = no loop, 0xFFFF = infinite (-1 stored internally)

int soundSetChannel(Sound* sound, int channels);
    // If channels == 3, sets sound->channels = 2 (stereo)

int soundSetReadLimit(Sound* sound, int readLimit);
    // Maximum bytes to read per refresh cycle

int soundSetCallback(Sound* sound, SoundCallback* callback, void* userData);
    // Set completion callback

int soundSetFileIO(Sound* sound, ...);
    // Override file I/O functions for this specific sound

int soundSetDefaultFileIO(...);
    // Override the default file I/O for all new sounds

void soundRegisterAlloc(SoundMallocFunc*, SoundReallocFunc*, SoundFreeFunc*);
    // Set memory allocation functions

const char* soundError(int err);
    // Get human-readable error message
```

### 3.15. Update Loop

```cpp
void soundUpdate();
```

Iterates through all sounds in `soundMgrList` and calls `soundContinue` on each. Called from the game's background process system via `gsound_bkg_proc`.

```cpp
void soundFlushAllSounds();
```

Deletes all sounds from the manager list.

### 3.16. File I/O Abstraction

The Sound Engine uses a `SoundFileIO` struct for all file operations:

```cpp
typedef struct SoundFileIO {
    SoundOpenProc* open;
    SoundCloseProc* close;
    SoundReadProc* read;
    SoundWriteProc* write;
    SoundSeekProc* seek;
    SoundTellProc* tell;
    SoundFileLengthProc* filelength;
    int fd;                 // File descriptor/handle
} SoundFileIO;
```

Each Sound object gets a copy of the default I/O at allocation time. Individual sounds can override their I/O (e.g., background music uses `audiof*` functions, SFX use `sfxc_cached_*` when the cache is active).

The default I/O uses raw POSIX file operations (`open`/`close`/`read`/`write`/`lseek`/`tell`). `gsound_init` replaces this with database-layer I/O via `soundSetDefaultFileIO`.

---

## 4. Audio Engine / SDL2 Backend (audio_engine.cc / audio_engine.h)

The Audio Engine replaces the original Win32 DirectSound backend with SDL2 audio. It provides a fixed pool of 8 sound buffers and a single audio callback that mixes them together.

### 4.1. Sound Buffer Structure

```cpp
#define AUDIO_ENGINE_SOUND_BUFFERS 8

struct AudioEngineSoundBuffer {
    bool active;                   // Slot is in use
    unsigned int size;             // Total buffer size in bytes
    int bitsPerSample;             // 8 or 16
    int channels;                  // 1 or 2
    int rate;                      // Source sample rate
    void* data;                    // Raw PCM buffer (malloc'd)
    int volume;                    // SDL volume (0..SDL_MIX_MAXVOLUME=128)
    bool playing;                  // Currently playing
    bool looping;                  // Loop when reaching end
    unsigned int pos;              // Current read position in buffer
    SDL_AudioStream* stream;       // SDL audio stream for format conversion
    std::recursive_mutex mutex;    // Thread-safety lock
};
```

All operations on a sound buffer are protected by a per-buffer `std::recursive_mutex`.

### 4.2. Initialization

```cpp
bool audioEngineInit();
```

Initializes SDL audio subsystem, opens a device at 22050 Hz, 16-bit signed, stereo, 1024-sample buffer, with `audioEngineMixin` as the callback. Immediately unpauses the device.

```cpp
void audioEngineExit();
```

Closes the SDL audio device and quits the audio subsystem.

```cpp
void audioEnginePause();
void audioEngineResume();
```

Pause/unpause the SDL audio device (silences output without closing).

### 4.3. Buffer Management

```cpp
int audioEngineCreateSoundBuffer(unsigned int size, int bitsPerSample, int channels, int rate);
```

Finds the first inactive slot, allocates `size` bytes of buffer memory, creates an `SDL_AudioStream` for converting from the source format to the output device format, and returns the slot index (-1 on failure).

```cpp
bool audioEngineSoundBufferRelease(int soundBufferIndex);
```

Frees the buffer data and SDL_AudioStream, marks the slot as inactive.

### 4.4. Playback

```cpp
bool audioEngineSoundBufferPlay(int soundBufferIndex, unsigned int flags);
```

Sets `playing = true`. If `flags & AUDIO_ENGINE_SOUND_BUFFER_PLAY_LOOPING`, also sets `looping = true`.

```cpp
bool audioEngineSoundBufferStop(int soundBufferIndex);
```

Sets `playing = false`.

### 4.5. Volume and Pan

```cpp
bool audioEngineSoundBufferSetVolume(int soundBufferIndex, int volume);
bool audioEngineSoundBufferGetVolume(int soundBufferIndex, int* volumePtr);
bool audioEngineSoundBufferSetPan(int soundBufferIndex, int pan);
```

Volume is in SDL range (0..128). Pan is accepted but silently ignored (not implemented in CE).

### 4.6. Position

```cpp
bool audioEngineSoundBufferGetCurrentPosition(int soundBufferIndex,
    unsigned int* readPosPtr, unsigned int* writePosPtr);
bool audioEngineSoundBufferSetCurrentPosition(int soundBufferIndex, unsigned int pos);
```

`GetCurrentPosition` returns the current read position. The write position is calculated as `readPos + rate/150` (15 ms lead, mimicking DirectSound behavior).

`SetCurrentPosition` sets `pos % size` to allow wrapping.

### 4.7. Lock/Unlock (Direct Buffer Access)

```cpp
bool audioEngineSoundBufferLock(int soundBufferIndex,
    unsigned int writePos, unsigned int writeBytes,
    void** audioPtr1, unsigned int* audioBytes1,
    void** audioPtr2, unsigned int* audioBytes2,
    unsigned int flags);

bool audioEngineSoundBufferUnlock(int soundBufferIndex,
    void* audioPtr1, unsigned int audioBytes1,
    void* audioPtr2, unsigned int audioBytes2);
```

Provides DirectSound-compatible circular buffer locking. Returns one or two pointers depending on whether the write wraps around the buffer boundary.

**Lock flags**:
- `AUDIO_ENGINE_SOUND_BUFFER_LOCK_FROM_WRITE_POS` (0x01): Start from current write position.
- `AUDIO_ENGINE_SOUND_BUFFER_LOCK_ENTIRE_BUFFER` (0x02): Lock the entire buffer.

### 4.8. Status

```cpp
bool audioEngineSoundBufferGetStatus(int soundBufferIndex, unsigned int* statusPtr);
```

**Status flags**:
- `AUDIO_ENGINE_SOUND_BUFFER_STATUS_PLAYING` (0x01): Buffer is playing.
- `AUDIO_ENGINE_SOUND_BUFFER_STATUS_LOOPING` (0x04): Buffer is looping.

### 4.9. The Mixing Callback

```cpp
static void audioEngineMixin(void* userData, Uint8* stream, int length);
```

Called by SDL on the audio thread. For each active and playing buffer:
1. Feeds source samples one frame at a time to the `SDL_AudioStream` for format/rate conversion.
2. Reads converted samples into a temporary 1024-byte buffer.
3. Mixes into the output stream using `SDL_MixAudioFormat` at the buffer's volume level.
4. Advances `pos`. If `pos >= size`, wraps to 0 if looping, otherwise stops.

The callback does nothing when `GNW95_isActive` is false (game window inactive).

---

## 5. Sound Effect Cache (game/sfxcache.cc / game/sfxcache.h)

The SFX cache keeps decoded sound effect data in memory to avoid re-reading and re-decoding ACM files for frequently used effects.

### 5.1. Architecture

The cache wraps the generic `Cache` system (`game/cache.cc`):

```
sfxc_init(cacheSize, effectsPath)
  -> sfxl_init(effectsPath)     // Initialize the SFX list
  -> sfxc_handle_list_create()  // Create SOUND_EFFECTS_MAX_COUNT=4 SoundEffect slots
  -> cache_init(sfxc_pcache, ...)  // Initialize the LRU cache
```

### 5.2. SoundEffect Structure

```cpp
typedef struct SoundEffect {
    bool used;                // Slot is active
    CacheEntry* cacheHandle;  // Reference into the Cache system
    int tag;                  // SFX list tag (identifies the sound file)
    int dataSize;             // Decompressed (full) size
    int fileSize;             // Compressed (cached) size
    int position;             // Current read position (for decompression)
    int dataPosition;         // Current position in raw data (for decoder)
    unsigned char* data;      // Pointer to cached compressed data
} SoundEffect;
```

### 5.3. Cache File I/O Interface

The cache provides a complete set of file I/O functions that can be plugged into the Sound Engine:

```cpp
int sfxc_cached_open(const char* fname, int mode);
    // Converts filename to tag via sfxl_name_to_tag, locks cache entry

int sfxc_cached_close(int handle);
    // Unlocks cache entry, destroys handle

int sfxc_cached_read(int handle, void* buf, unsigned int size);
    // Reads from cached data, decompressing on-the-fly if compressed (sfxc_cmpr=1)
    // Uses Create_AudioDecoder for ACM decompression

int sfxc_cached_write(int handle, const void* buf, unsigned int size);
    // Always returns -1 (not supported)

long sfxc_cached_seek(int handle, long offset, int origin);
    // Adjusts the logical position (SEEK_SET, SEEK_CUR, SEEK_END)

long sfxc_cached_tell(int handle);
    // Returns current position

long sfxc_cached_file_size(int handle);
    // Returns decompressed data size
```

### 5.4. Decompression

When `sfxc_cmpr` is 1 (the default), `sfxc_cached_read` creates a new `AudioDecoder` each time, skips to the current position by reading and discarding, then reads the requested amount. This is inefficient but correct, since the ACM decoder is not seekable.

### 5.5. Other Functions

```cpp
int sfxc_init(int cache_size, const char* effectsPath);
void sfxc_exit();
int sfxc_is_initialized();
void sfxc_flush();   // Flush all cached entries
```

The minimum cache size is `SOUND_EFFECTS_CACHE_MIN_SIZE` = 0x40000 (256 KB). The `gsound_init` function reads the cache size from config in kilobytes and shifts left by 10.

---

## 6. Sound Effect List (game/sfxlist.cc / game/sfxlist.h)

The SFX list maps sound effect file names to integer tags for cache lookups.

### 6.1. SoundEffectsListEntry

```cpp
typedef struct SoundEffectsListEntry {
    char* name;      // Filename (e.g., "GUNFIRE.ACM")
    int dataSize;    // Decompressed size in bytes
    int fileSize;    // Compressed file size
} SoundEffectsListEntry;
```

### 6.2. Initialization

```cpp
int sfxl_init(const char* soundEffectsPath, int compression, int debugLevel);
```

1. Saves the effects path and compression mode.
2. Calls `sfxl_get_names()` which uses `db_get_file_list("sound\\sfx\\*.ACM")` to enumerate all sound effect files.
3. Calls `sfxl_get_sizes()` which:
   - For uncompressed (`compression=0`): uses file size directly.
   - For compressed (`compression=1`): opens each file, creates an `AudioDecoder` to determine the decompressed sample count, computes `dataSize = 2 * sampleCount` (16-bit samples).
4. Sorts the list by name using `qsort` for binary search lookups.

```cpp
void sfxl_exit();
```

Frees all name strings and the list array.

### 6.3. Tag System

Tags are computed as `2 * (index + 1)`, so tag values are always even and positive (starting at 2). This makes tag 0 and odd values invalid, providing a simple validation mechanism.

```cpp
int sfxl_name_to_tag(char* name, int* tagPtr);
    // Binary search by name -> tag

int sfxl_name(int tag, char** pathPtr);
    // Tag -> full path (effectsPath + name)

int sfxl_size_full(int tag, int* sizePtr);
    // Tag -> decompressed size

int sfxl_size_cached(int tag, int* sizePtr);
    // Tag -> compressed size

bool sfxl_tag_is_legal(int tag);
    // Validates a tag
```

### 6.4. Return Codes

```cpp
#define SFXL_OK              0
#define SFXL_ERR             1
#define SFXL_ERR_TAG_INVALID 2
```

---

## 7. MVE Movie Playback

Movie playback spans three layers: the low-level MVE codec, the mid-level movie interface, and the high-level game movie wrapper.

### 7.1. Movie Library -- Low-Level MVE Codec (movie_lib.cc / movie_lib.h)

This is the Interplay MVE (Multi-Video Engine) decoder. MVE files contain interleaved audio and video chunks.

**Types**:

```cpp
typedef void*(MveMallocFunc)(size_t size);
typedef void(MveFreeFunc)(void* ptr);
typedef bool MovieReadProc(void* handle, void* buffer, int count);
typedef void(MovieShowFrameProc)(SDL_Surface*, int, int, int, int, int, int, int, int);
```

**Configuration**:

```cpp
void movieLibSetMemoryProcs(MveMallocFunc* mallocProc, MveFreeFunc* freeProc);
    // Set custom allocator for all MVE memory operations

void movieLibSetReadProc(MovieReadProc* readProc);
    // Set the file reading callback

void movieLibSetVolume(int volume);
void movieLibSetPan(int pan);
    // Set audio volume and panning for the movie
```

**Video surface setup**:

```cpp
void _MVE_sfSVGA(int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9);
    // Configure the video output surface dimensions and offset

void _MVE_sfCallbacks(MovieShowFrameProc* proc);
    // Set the callback for displaying decoded video frames

void _MVE_rmCallbacks(int (*fn)());
    // Set the callback called each frame for user input / abort checking
```

**Palette**:

```cpp
void movieLibSetPaletteEntriesProc(void (*fn)(unsigned char*, int, int));
    // Set the callback for palette changes during playback
```

**Playback lifecycle**:

```cpp
int _MVE_rmPrepMovie(void* handle, int a2, int a3, char a4);
    // Initialize MVE playback from a file handle
    // a2, a3: display position offset
    // a4: flags

int _MVE_rmStepMovie();
    // Decode and display the next frame
    // Returns 0 on success, -1 when movie is finished

void _MVE_rmEndMovie();
    // Clean up current movie playback

void _MVE_ReleaseMem();
    // Free all allocated MVE memory
```

**Frame info**:

```cpp
void _MVE_rmFrameCounts(int* a1, int* a2);
    // Get frame count information
```

### 7.2. Movie Interface -- Mid-Level (int/movie.cc / int/movie.h)

This layer manages movie playback in the context of the GNW windowing system, handling subtitles, palette management, and various display modes.

**Types**:

```cpp
typedef enum MovieFlags {
    MOVIE_FLAG_0x01 = 0x01,  // (unused)
    MOVIE_FLAG_0x02 = 0x02,  // (unused)
    MOVIE_FLAG_0x04 = 0x04,  // Standard playback
    MOVIE_FLAG_0x08 = 0x08,  // Subtitles enabled
} MovieFlags;

typedef enum MovieExtendedFlags {
    MOVIE_EXTENDED_FLAG_0x01 = 0x01,  // (alpha blending)
    MOVIE_EXTENDED_FLAG_0x02 = 0x02,  // (scaling)
    MOVIE_EXTENDED_FLAG_0x04 = 0x04,  // (sub-rect)
    MOVIE_EXTENDED_FLAG_0x08 = 0x08,  // (unused)
    MOVIE_EXTENDED_FLAG_0x10 = 0x10,  // (unused)
} MovieExtendedFlags;
```

**Callback types**:

```cpp
typedef char*(MovieSubtitleFunc)(char* movieFilePath);
typedef void(MoviePaletteFunc)(unsigned char* palette, int start, int end);
typedef void(MovieUpdateCallbackProc)(int frame);
typedef void(MovieFrameGrabProc)(unsigned char* data, int width, int height, int pitch);
typedef void(MovieCaptureFrameProc)(unsigned char* data, int width, int height, int pitch,
    int movieX, int movieY, int movieWidth, int movieHeight);
typedef void(MoviePreDrawFunc)(int win, Rect* rect);
typedef void(MovieStartFunc)(int win);
typedef void(MovieEndFunc)(int win, int x, int y, int width, int height);
typedef int(MovieFailedOpenFunc)(char* path);
```

**Lifecycle**:

```cpp
void initMovie();
void movieClose();
```

`initMovie` configures the MVE library with GNW memory allocators and database file I/O.

**Playback**:

```cpp
int movieRun(int win, char* filePath);
    // Start playing a movie in the given window

int movieRunRect(int win, char* filePath, int a3, int a4, int a5, int a6);
    // Start playing a movie in a sub-rectangle of the window

void movieStop();
    // Stop current movie playback

int moviePlaying();
    // Returns 1 if a movie is currently playing

void movieUpdate();
    // Update movie state (called from main loop)
```

**Configuration**:

```cpp
void movieSetVolume(int volume);
    // Set movie audio volume (passed through to movieLibSetVolume)

int movieSetFlags(int flags);
    // Set playback flags (MOVIE_FLAG_0x04 for standard, 0x08 for subtitles)

void movieSetPaletteFunc(MoviePaletteFunc* func);
    // Set custom palette handler (default: setSystemPaletteEntries)

void movieSetCallback(MovieUpdateCallbackProc* func);
    // Set per-frame update callback

void movieSetPreDrawFunc(MoviePreDrawFunc* func);
    // Set function called before each frame is drawn

void movieSetFunc(MovieStartFunc* startFunc, MovieEndFunc* endFunc);
    // Set callbacks for movie start and end events

void movieSetFrameGrabFunc(MovieFrameGrabProc* func);
    // Set frame capture callback

void movieSetCaptureFrameFunc(MovieCaptureFrameProc* func);
    // Set frame capture with position info

void movieSetFailedOpenFunc(MovieFailedOpenFunc* func);
    // Set callback for file-not-found errors
```

**Subtitles**:

```cpp
void movieSetSubtitleFunc(MovieSubtitleFunc* proc);
    // Set function that maps movie file path to subtitle file path

void movieSetSubtitleFont(int font);
    // Set font for subtitle rendering

void movieSetSubtitleColor(float r, float g, float b);
    // Set subtitle text color (0.0..1.0 for each component)
```

**Display modes**: The movie interface supports multiple blit strategies selected by a 3-dimensional lookup table `showFrameFuncs[alpha][scaled][subrect]`:
- `blitNormal` -- direct blit to window
- `blitAlpha` -- alpha-blended blit
- `movieScaleWindow` -- scaled to window size
- `movieScaleSubRect` -- scaled to sub-rectangle
- `movieScaleWindowAlpha` / `movieScaleSubRectAlpha` -- combined

### 7.3. Game Movie Wrapper (game/gmovie.cc / game/gmovie.h)

The highest-level API for playing game cinematics.

**Movie IDs**:

```cpp
typedef enum GameMovie {
    MOVIE_IPLOGO,      // iplogo.mve   -- Interplay logo
    MOVIE_MPLOGO,      // mplogo.mve   -- MacPlay logo
    MOVIE_INTRO,       // intro.mve    -- Game introduction
    MOVIE_VEXPLD,      // vexpld.mve   -- Vault explosion
    MOVIE_CATHEXP,     // cathexp.mve  -- Cathedral explosion
    MOVIE_OVRINTRO,    // ovrintro.mve -- Overseer intro
    MOVIE_BOIL3,       // boil3.mve    -- Boiling death 3
    MOVIE_OVRRUN,      // ovrrun.mve   -- Overseer run
    MOVIE_WALKM,       // walkm.mve    -- Walk male
    MOVIE_WALKW,       // walkw.mve    -- Walk female
    MOVIE_DIPEDV,      // dipedv.mve   -- Dipped vault dweller
    MOVIE_BOIL1,       // boil1.mve    -- Boiling death 1
    MOVIE_BOIL2,       // boil2.mve    -- Boiling death 2
    MOVIE_RAEKILLS,    // raekills.mve -- Rae kills
    MOVIE_COUNT,       // 14 total
} GameMovie;
```

**Playback flags**:

```cpp
typedef enum GameMovieFlags {
    GAME_MOVIE_FADE_IN     = 0x01,  // Fade from black before playing
    GAME_MOVIE_FADE_OUT    = 0x02,  // Fade back to game palette after playing
    GAME_MOVIE_STOP_MUSIC  = 0x04,  // Stop background music during movie
    GAME_MOVIE_PAUSE_MUSIC = 0x08,  // Pause (not stop) background music
} GameMovieFlags;
```

**Functions**:

```cpp
int gmovie_init();
    // Sets movie volume to current background music volume,
    // registers subtitle function, clears played-list

void gmovie_reset();
    // Clears the played-list

void gmovie_exit();
    // No-op

int gmovie_load(DB_FILE* stream);
int gmovie_save(DB_FILE* stream);
    // Load/save the played-list from/to a save game

int gmovie_play(int game_movie, int game_movie_flags);
    // Play a cinematic. Full sequence:
    //   1. Fade to black if GAME_MOVIE_FADE_IN
    //   2. Create a 640x480 modal window
    //   3. Stop or pause music as requested
    //   4. Configure subtitles (load subtitle palette, set font 101)
    //   5. Hide cursor
    //   6. Start moviefx
    //   7. movieRun(win, "art\cuts\<name>.mve")
    //   8. Poll for completion, user input, or touch gesture
    //   9. Stop and clean up
    //  10. Record as played
    //  11. Restore cursor, palette, font
    //  12. Unpause music if paused
    //  13. Fade out if GAME_MOVIE_FADE_OUT

bool gmovie_has_been_played(int game_movie);
    // Check if a specific cinematic has been shown this playthrough
```

**Subtitle path resolution** (`gmovie_subtitle_func`):
- Reads the language setting from config.
- Constructs path: `text\<language>\cuts\<moviename>.SVE`
- Example: `text\english\cuts\intro.SVE`

**Forced subtitles**: The boiling death movies (`MOVIE_BOIL1`, `MOVIE_BOIL2`, `MOVIE_BOIL3`) always enable subtitles regardless of user preference.

---

## 8. Script Audio Integration (int/audio.cc/h, int/audiof.cc/h)

These two modules provide file I/O abstractions for ACM-compressed audio. They are nearly identical in structure but serve different purposes:

- **audio.cc** (standard audio): Uses the game database layer (`db_fopen`/`db_fread`/etc.) for file access. Used for speech playback and SFX when the cache is not active.
- **audiof.cc** (Fallout-specific audio): Uses raw C file I/O (`fopen`/`fread`/etc.) via `compat_fopen`. Used for background music playback, which reads from the filesystem rather than the game database.

### 8.1. Audio Structure

Both modules use the same internal structure (with slightly different names):

```cpp
typedef struct Audio {        // audio.cc
typedef struct AudioFile {    // audiof.cc
    int flags;                // AUDIO_FILE_IN_USE | AUDIO_FILE_COMPRESSED
    DB_FILE* stream;          // audio.cc uses DB_FILE*
    FILE* stream;             // audiof.cc uses FILE*
    AudioDecoder* audioDecoder;  // ACM decoder instance
    int fileSize;             // Decompressed size (sampleCount * 2)
    int sampleRate;           // From ACM header
    int channels;             // From ACM header
    int position;             // Current read position (decompressed bytes)
};
```

### 8.2. Compression Handling

Both modules call a `queryCompressedFunc` callback on open to determine if the file is compressed. In Fallout CE, `gsound_compressed_query` always returns `true`, so all files are treated as ACM compressed.

When a file is opened as compressed:
1. The `AudioDecoder` (from the `adecode` library) is created with a read callback.
2. The decoder determines the number of samples, channels, and sample rate from the ACM header.
3. `fileSize` is set to `sampleCount * 2` (16-bit PCM output).
4. Reads go through `AudioDecoder_Read`.

### 8.3. Functions -- audio.cc

```cpp
int initAudio(AudioQueryCompressedFunc* isCompressedProc);
    // Initialize and set as default file I/O via soundSetDefaultFileIO

void audioClose();
    // Free the audio file array

int audioOpen(const char* fname, int mode);
    // Open via db_fopen, create AudioDecoder if compressed
    // Returns 1-based handle

int audioCloseFile(int fileHandle);
    // Close DB_FILE, destroy decoder, clear slot

int audioRead(int fileHandle, void* buffer, unsigned int size);
    // Read via AudioDecoder_Read or db_fread

long audioSeek(int fileHandle, long offset, int origin);
    // For compressed: seeking backward requires re-creating decoder and
    // re-reading from start (ACM is not seekable)
    // For uncompressed: db_fseek

long audioFileSize(int fileHandle);
    // Returns decompressed file size

long audioTell(int fileHandle);
    // Returns current position

int audioWrite(int handle, const void* buf, unsigned int size);
    // Prints warning, returns 0 (should never be called)
```

### 8.4. Functions -- audiof.cc

```cpp
int initAudiof(AudioFileQueryCompressedFunc* isCompressedProc);
    // Initialize and set as default file I/O

void audiofClose();
    // Free the audiof file array

int audiofOpen(const char* fname, int flags);
    // Open via compat_fopen, create AudioDecoder if compressed
    // Returns 1-based handle

int audiofCloseFile(int fileHandle);
int audiofRead(int fileHandle, void* buf, unsigned int size);
long audiofSeek(int handle, long offset, int origin);
long audiofFileSize(int fileHandle);
long audiofTell(int fileHandle);
int audiofWrite(int handle, const void* buf, unsigned int size);
    // Same semantics as audio.cc but using FILE* instead of DB_FILE*
```

### 8.5. File Handle Convention

Both modules use **1-based** handles externally. Internally, the handle is decremented by 1 to index into the array. Handle 0 and negative values are invalid.

### 8.6. Seeking in Compressed Streams

ACM decoders are forward-only. Seeking backward in a compressed stream requires:
1. Closing the current decoder.
2. Re-seeking the underlying file to offset 0.
3. Creating a new decoder.
4. Reading and discarding bytes until reaching the target position.

This makes backward seeks expensive. Forward seeks also read and discard intermediate data. Both modules allocate temporary buffers (4096 or 1024 bytes) for this purpose.

Note: The `audiof.cc` seek implementation has a known memory leak in the forward-seek path (the temporary buffer is not freed).

### 8.7. Initialization Order

In `gsound_init`, both modules are initialized:
```cpp
initAudiof(gsound_compressed_query);  // Sets audiof* as default file I/O
initAudio(gsound_compressed_query);   // Overrides default file I/O with audio*
```

The last call wins for `soundSetDefaultFileIO`, so `audio*` functions become the default. Background music explicitly overrides its Sound object to use `audiof*` via `soundSetFileIO`.

---

## 9. ACM Audio Format

All Fallout sound files use Interplay's ACM compression format (`.ACM` extension). The decoder is provided by the `adecode` library (`third_party/adecode` or `thirdparty/adecode`).

Key characteristics:
- Forward-only decoder (not seekable).
- Output is 16-bit signed PCM.
- Mono or stereo.
- Variable sample rate (typically 22050 Hz for SFX, may vary for music/speech).
- Header contains sample count, channels, and sample rate.

The decoder API:

```cpp
AudioDecoder* Create_AudioDecoder(ReadFunc* reader, void* stream,
    int* channels, int* sampleRate, int* sampleCount);
size_t AudioDecoder_Read(AudioDecoder* decoder, void* buffer, size_t size);
void AudioDecoder_Close(AudioDecoder* decoder);
```

The `reader` callback is provided by the caller and abstracts the underlying file I/O (database, raw file, or cache).

---

## 10. Data Flow Summary

### Playing a Sound Effect

```
gsound_play_sfx_file("ib1p1xx1")
  -> gsound_load_sound("ib1p1xx1", NULL)
       -> gsound_get_sound_ready_for_effect()
            -> soundAllocate(5, 10)           // fire-and-forget, memory
            -> soundSetFileIO(sfxc_cached_*)  // or audio* if cache inactive
            -> soundSetCallback(gsound_internal_effect_callback)
            -> soundVolume(sound, sndfx_volume)
       -> soundLoad(sound, "sound\\sfx\\ib1p1xx1.ACM")
            -> sound->io.open(path)           // sfxc_cached_open -> cache_lock
            -> preloadBuffers(sound)
                 -> sound->io.read(fd, buf, size)  // ACM decode
                 -> soundSetData(sound, buf, size)
                      -> audioEngineCreateSoundBuffer(size, 16, 1, 22050)
                      -> audioEngineSoundBufferLock + memcpy + Unlock
  -> soundPlay(sound)
       -> soundVolume(sound, volume)
            -> audioEngineSoundBufferSetVolume(idx, normalized)
       -> audioEngineSoundBufferPlay(idx, 0)
```

### Playing Background Music

```
gsound_background_play("07desert", 12, 14, 16)
  -> gsound_background_stop()
  -> gsound_background_allocate(&tag, 14, 16)   // streaming, looping
       -> soundAllocate(0x02, 42)
  -> soundSetFileIO(tag, audiofOpen, audiofCloseFile, audiofRead, ...)
  -> soundSetChannel(tag, 3)  // stereo
  -> gsound_background_find_with_copy(path, "07desert")
  -> soundLoop(tag, 0xFFFF)
  -> soundSetCallback(tag, gsound_internal_background_callback)
  -> soundLoad(tag, path)
       -> audiofOpen(path)  -> compat_fopen -> Create_AudioDecoder
       -> preloadBuffers: streaming mode, circular buffer
  -> gsound_background_start()
       -> soundVolume(tag, background_volume * 0.94)
       -> soundPlay(tag)  // or soundFade if fading enabled
```

### Movie Audio

```
gmovie_play(MOVIE_INTRO, GAME_MOVIE_FADE_IN | GAME_MOVIE_STOP_MUSIC)
  -> gsound_background_stop()
  -> movieRun(win, "art\\cuts\\intro.mve")
       -> movieStart(win, path, localMovieCallback)
            -> _MVE_rmPrepMovie(handle, ...)
            -> stepMovie() loop:
                 -> _MVE_rmStepMovie()
                      // Decodes audio chunks -> audioEngineCreateSoundBuffer
                      // Decodes video chunks -> SDL_Surface -> blit
  -> movieStop()
       -> _MVE_rmEndMovie()
```
