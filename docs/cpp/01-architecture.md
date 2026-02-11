# Architecture Overview

## Layered Design

The codebase follows a strict layered architecture:

```
┌─────────────────────────────────────────────────┐
│  Game Logic (src/game/)                         │
│  Combat, dialog, inventory, worldmap, etc.      │
├─────────────────────────────────────────────────┤
│  Interpreter (src/int/)                         │
│  Script VM, managed windows, sound, movie       │
├─────────────────────────────────────────────────┤
│  Platform Library (src/plib/)                   │
│  GNW windowing, DB file I/O, color, assoc       │
├─────────────────────────────────────────────────┤
│  Utilities (src/ root)                          │
│  audio_engine, fps_limiter, platform_compat     │
├─────────────────────────────────────────────────┤
│  SDL2 + OS                                      │
└─────────────────────────────────────────────────┘
```

Each layer only depends on the layers below it.

## Project Structure

```
src/
├── game/                    # ~85 files, ~2.8 MB
│   ├── main.cc/h            # Entry point: gnw_main()
│   ├── game.cc/h            # Game init/reset/exit
│   ├── map.cc/h             # Map loading and management
│   ├── object.cc/h          # In-world object system
│   ├── proto.cc/h           # Prototype/template system
│   ├── combat.cc/h          # Turn-based combat
│   ├── combatai.cc/h        # NPC AI
│   ├── scripts.cc/h         # Script management
│   ├── gdialog.cc/h         # Dialog system
│   ├── tile.cc/h            # Isometric tile rendering
│   ├── anim.cc/h            # Animation system (65 types)
│   ├── art.cc/h             # Sprite/frame management
│   ├── gsound.cc/h          # Game sound manager
│   ├── intface.cc/h         # In-game interface bar
│   ├── inventry.cc/h        # Inventory system
│   ├── gmouse.cc/h          # Game mouse/cursor
│   ├── worldmap.cc/h        # World map navigation
│   ├── loadsave.cc/h        # Save/load serialization
│   ├── stat.cc/h            # Character stats (S.P.E.C.I.A.L.)
│   ├── skill.cc/h           # 18 skills
│   ├── perk.cc/h            # 43+ perks
│   ├── trait.cc/h           # 16 traits
│   ├── critter.cc/h         # NPC/character management
│   ├── item.cc/h            # Item manipulation
│   ├── queue.cc/h           # Timed event queue
│   ├── palette.cc/h         # Palette effects
│   ├── cycle.cc/h           # Color cycling (day/night)
│   ├── light.cc/h           # Dynamic lighting
│   ├── cache.cc/h           # Resource cache
│   ├── message.cc/h         # Localized message files
│   ├── config.cc/h          # INI config parser
│   ├── editor.cc/h          # Character editor (~182 KB)
│   ├── mainmenu.cc/h        # Main menu state machine
│   ├── select.cc/h          # Character creation
│   ├── options.cc/h         # Options screens
│   ├── pipboy.cc/h          # Pip-Boy interface
│   ├── automap.cc/h         # Local area map
│   ├── party.cc/h           # Party member management
│   ├── elevator.cc/h        # Elevator transitions
│   ├── endgame.cc/h         # End-game slideshow
│   ├── credits.cc/h         # Credits scrolling
│   ├── display.cc/h         # Text display monitor
│   ├── fontmgr.cc/h         # Font management
│   ├── graphlib.cc/h        # Graphics utilities
│   ├── textobj.cc/h         # Floating text
│   ├── wordwrap.cc/h        # Text wrapping
│   ├── reaction.cc/h        # NPC reaction system
│   ├── roll.cc/h            # Random rolls / skill checks
│   ├── actions.cc/h         # Object interaction hooks
│   ├── selfrun.cc/h         # Demo/self-run mode
│   ├── sfxcache.cc/h        # Sound effect cache
│   ├── sfxlist.cc/h         # Sound effect list
│   ├── version.cc/h         # Version info
│   ├── gmovie.cc/h          # Movie playback wrapper
│   ├── gmemory.cc/h         # Game memory manager
│   ├── gdebug.cc/h          # Game debug utilities
│   ├── gconfig.cc/h         # Game config wrapper
│   ├── protinst.cc/h        # Prototype instance
│   ├── amutex.cc/h          # Auto-run mutex
│   ├── lip_sync.cc/h        # Lip sync for dialog
│   ├── bmpdlog.cc/h         # Bitmap dialog helpers
│   ├── *_defs.h             # Type definitions
│   ├── game_vars.h          # ~100+ global game variables
│   ├── object_types.h       # Object structure definitions
│   └── proto_types.h        # Prototype structures
│
├── int/                     # ~20 files
│   ├── intrpret.cc/h        # Bytecode interpreter (87 opcodes)
│   ├── intlib.cc/h          # Standard script library
│   ├── intextra.cc/h        # Extra script utilities
│   ├── export.cc/h          # Cross-script variable/procedure export
│   ├── window.cc/h          # Managed window system (16 max)
│   ├── widget.cc/h          # UI widget base classes
│   ├── dialog.cc/h          # Dialog window management
│   ├── region.cc/h          # Interactive click regions
│   ├── sound.cc/h           # Low-level sound management
│   ├── movie.cc/h           # Movie playback interface
│   ├── audio.cc/h           # Script audio I/O
│   ├── audiof.cc/h          # Audio file operations
│   ├── datafile.cc/h        # Game data file loading
│   ├── pcx.cc/h             # PCX image loader
│   ├── nevs.cc/h            # Named event system
│   ├── mousemgr.cc/h        # Mouse cursor manager
│   ├── memdbg.cc/h          # Memory debugging
│   └── share1.cc/h          # File listing utilities
│
├── plib/
│   ├── gnw/                 # ~30 files
│   │   ├── gnw.cc/h         # Window manager core
│   │   ├── grbuf.cc/h       # Graphics buffer
│   │   ├── svga.cc/h        # SDL2 video backend
│   │   ├── input.cc/h       # Input system (events, timers)
│   │   ├── kb.cc/h          # Keyboard handling (71 KB)
│   │   ├── mouse.cc/h       # Mouse input
│   │   ├── button.cc/h      # Button widget (38 KB)
│   │   ├── text.cc/h        # Text rendering
│   │   ├── intrface.cc/h    # Interface drawing primitives
│   │   ├── vcr.cc/h         # Input recording/playback
│   │   ├── memory.cc/h      # Memory management
│   │   ├── rect.cc/h        # Rectangle utilities
│   │   ├── debug.cc/h       # Debug output
│   │   ├── dxinput.cc/h     # DirectX input (legacy)
│   │   ├── winmain.cc/h     # Windows entry point
│   │   ├── touch.cc/h       # Touch input (mobile)
│   │   ├── gnw_types.h      # GNW type definitions
│   │   └── svga_types.h     # Video type definitions
│   │
│   ├── assoc/
│   │   └── assoc.cc/h       # Sorted key-value store
│   │
│   ├── color/
│   │   └── color.cc/h       # Palette, blending, gamma
│   │
│   └── db/
│       ├── db.cc/h          # DAT archive file I/O
│       └── lzss.cc/h        # LZSS decompression
│
├── platform/
│   └── ios/paths.mm         # iOS-specific file paths
│
├── audio_engine.cc/h        # SDL2 audio backend
├── fps_limiter.cc/h         # Frame rate limiter
├── movie_lib.cc/h           # MVE video codec
├── platform_compat.cc/h     # Cross-platform compat layer
└── pointer_registry.cc/h    # Pointer-to-int mapping
```

## Third-Party Dependencies

| Dependency | Purpose | Location |
|---|---|---|
| SDL2 | Graphics, input, audio | `third_party/sdl2/` (or system) |
| adecode | ACM audio codec (Fallout music) | `third_party/adecode/` |
| fpattern | File wildcard pattern matching | `third_party/fpattern/` |

## Build System (CMake)

- **Language**: C++17, no extensions
- **Minimum CMake**: 3.13
- **Platforms**: Windows, macOS, Linux, iOS, Android

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

Platform-specific notes:
- **Windows**: Links `winmm.lib`, uses MSVC resource file
- **macOS**: Universal binary (x86_64 + arm64), app bundle with icon
- **iOS**: arm64 only, LaunchScreen storyboard
- **Android**: Builds as shared library (.so) for JNI
- **Linux**: Uses system SDL2 via `find_package(SDL2)`

## Initialization Flow

Entry point: `gnw_main()` in `src/game/main.cc`

```
gnw_main(argc, argv)
├── autorun_mutex_create()              // Prevent multiple instances
│
├── game_init("FALLOUT", ...)           // Bootstrap all systems
│   ├── Config loading                  // fallout.cfg, f1_res.ini
│   ├── Game global vars allocation
│   ├── db_init()                       // Open master.dat, critter.dat
│   ├── GNW init                        // Video, input, audio
│   │   ├── svga_init()                 // SDL2 window + renderer
│   │   ├── GNW_input_init()            // Keyboard, mouse, timers
│   │   └── audioEngineInit()           // SDL2 audio device
│   ├── Window manager init
│   ├── art_init()                      // Sprite cache
│   ├── proto_init()                    // Prototypes/templates
│   ├── scripts_init()                  // Scripting engine
│   ├── gsound_init()                   // Game audio
│   └── 100+ other subsystems...
│
├── gmovie_play(MOVIE_IPLOGO)           // Interplay logo
├── gmovie_play(MOVIE_INTRO)            // Intro cinematic
│
├── main_menu_create()                  // Menu loop
│   └── while not done:
│       ├── Display menu
│       ├── Handle input
│       │
│       ├── NEW_GAME:
│       │   ├── select_character()      // Character creation
│       │   ├── main_load_new(map)      // Load starting map
│       │   │   ├── map_init()
│       │   │   ├── map_load("V13Ent.map")
│       │   │   └── palette_fade_to()
│       │   └── main_game_loop()        // Main loop
│       │       └── while running:
│       │           ├── get_input()
│       │           ├── game_handle_input()
│       │           ├── scripts_check_state()
│       │           ├── map_check_state()
│       │           └── renderPresent()
│       │
│       └── LOAD_GAME: similar flow
│
└── game_exit()                         // Shutdown all systems
    └── SDL_Quit()
```

### Initialization Order (Critical)

Systems must be initialized in this exact order due to dependencies:

1. Mutex / config / paths
2. Video mode (SDL2 window + renderer)
3. Input devices (keyboard, mouse, joystick)
4. Audio system
5. Database (.DAT files)
6. Window manager (GNW)
7. Sprite cache (art)
8. Prototypes (game objects)
9. Scripts (VM)
10. Game variables
11. Map system
12. All remaining subsystems

Shutdown happens in reverse order.

## Key Architectural Patterns

### Namespace
All code is in the `fallout` namespace.

### Init / Reset / Exit Pattern
Every module follows the same lifecycle:
```cpp
int module_init();    // Allocate resources, load data
int module_reset();   // Return to initial state (for new game)
void module_exit();   // Free all resources
```

### Callback-Driven Design
Heavy use of function pointers for:
- File I/O customization (color, database, audio)
- Custom memory allocators (via `register_mem()`)
- Event handlers (UI, scripting, animation completion)
- Progress callbacks (loading screens)

### Global State
Significant use of module-level static variables:
- `obj_dude` - Player character object
- `obj_egg` - Spawn location marker
- `game_global_vars` - Quest/game state variables
- `map_local_vars` - Per-map variables
- `combat_state` - Combat mode flag
- `map_elevation` - Current elevation (0-2)
- `game_ui_disabled` - UI disabled flag

### Registry Pattern
- Pointer registry for object lifecycle tracking
- Script registry for active scripts
- Animation registry for queued animations

### Stack-Based VM
The Fallout script interpreter uses a classic stack machine:
- Operands pushed to stack
- Operations pop operands and push results
- Frame/base pointers for function calls
- Separate return stack for procedure calls
