# Fallout 1 Community Edition - C++ Developer Documentation

Comprehensive developer documentation for the [fallout1-ce](https://github.com/alexbatalov/fallout1-ce) C++ source code by alexbatalov. This documentation serves as a reference for understanding the codebase architecture, subsystems, and APIs.

## Table of Contents

1. **[Architecture Overview](01-architecture.md)**
   - Project structure, layered design, initialization flow, build system

2. **[Game Systems](02-game-systems.md)**
   - Combat, character stats/skills/perks, items/weapons, inventory, dialog, world map, save/load, animation, event queue

3. **[Scripting & Interpreter](03-scripting.md)**
   - Bytecode VM, opcodes, script types, procedures, cross-script exports, game-script integration

4. **[Graphics, Windowing & Input](04-graphics-input.md)**
   - GNW window manager, SVGA/SDL2 video, buttons, text rendering, mouse, keyboard, touch input

5. **[Audio System](05-audio.md)**
   - Game sound manager, sound engine, audio engine backend, MVE movie playback

6. **[Data Formats & I/O](06-data-formats.md)**
   - DAT archive format, prototype structures, color/palette system, LZSS compression, config files

7. **[API Reference](07-api-reference.md)**
   - Complete function listings organized by module

## Source Code Layout

```
src/
├── game/           # High-level game logic (~85 files)
├── int/            # Interpreter/scripting engine (~20 files)
├── plib/
│   ├── gnw/        # Graphics, windowing, input (~30 files)
│   ├── assoc/      # Hash table / key-value store
│   ├── color/      # Palette and color management
│   └── db/         # DAT archive file I/O
├── platform/       # Platform-specific code (iOS paths)
├── audio_engine.cc # SDL2 audio backend
├── fps_limiter.cc  # Frame rate control
├── movie_lib.cc    # MVE video codec
├── platform_compat.cc # Cross-platform compatibility
└── pointer_registry.cc # Pointer lifecycle tracking
```

## Key Design Principles

- **Layered architecture**: Game logic -> Interpreter -> Platform library (GNW) -> SDL2
- **All code in `fallout` namespace**
- **Callback-driven**: Extensive use of function pointers for I/O, events, UI
- **Global state**: Module-level static variables, initialized/cleaned in order
- **8-bit indexed color**: 256-color palette with gamma correction and blend tables
- **Stack-based scripting VM**: Custom bytecode interpreter for game scripts
