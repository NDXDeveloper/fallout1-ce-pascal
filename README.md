# Fallout 1 Community Edition - Pascal Port

A Free Pascal port of [fallout1-ce](https://github.com/alexbatalov/fallout1-ce) by alexbatalov, which is a fully working re-implementation of Fallout 1 using SDL2.

This project is a line-by-line translation of the C++ source code into Object Pascal, targeting Free Pascal Compiler (FPC). It produces a native Linux binary with no C/C++ dependencies beyond SDL2.

## Prerequisites

- [Free Pascal Compiler](https://www.freepascal.org/) 3.2.0 or later
- SDL2 development libraries (`libsdl2-dev` on Debian/Ubuntu)
- A legal copy of Fallout 1 game data (from [GOG](https://www.gog.com/game/fallout) or [Steam](https://store.steampowered.com/app/38400/Fallout_A_Post_Nuclear_Role_Playing_Game/))

### Installing prerequisites on Debian/Ubuntu

```bash
sudo apt install fpc libsdl2-dev
```

## Building

```bash
# Release build (optimized)
make

# Full release rebuild
make rebuild

# Debug build (range checks + line info for tracebacks)
make debug

# Full debug rebuild
make debug-rebuild
```

The compiled binary is placed in `bin/` (intermediate build artifacts go to `lib/`).

## Installation

Copy the compiled binary (`bin/fallout_ce`) into a folder containing the Fallout 1 game data files:

```
your-game-folder/
├── fallout_ce          # compiled binary
├── fallout.cfg
├── MASTER.DAT
├── CRITTER.DAT
└── DATA/
    └── ...
```

The game data files can be found in your GOG or Steam installation of Fallout 1.

## Running

```bash
# Build and run (game data must be in bin/)
make run

# Build debug and run
make run-debug
```

Or run the binary directly from the folder containing the game data:

```bash
cd your-game-folder
./fallout_ce
```

## Current status

This is a work in progress. What works so far:

- Intro cinematics (Interplay logo, nuclear explosion, etc.)
- Main menu (New Game, Load Game, Options, Credits, Exit)
- Starting a new game and entering the first level (Vault 13)
- Walking around the first level

Everything beyond this is not yet functional. Contributions and testing are welcome.

Track the number of remaining C external stubs:

```bash
make count
```

## Author

**Nicolas DEOUX**

- [NDXDev@gmail.com](mailto:NDXDev@gmail.com)
- [LinkedIn](https://www.linkedin.com/in/nicolas-deoux-ab295980/)
- [GitHub](https://github.com/NDXDeveloper)

## License

This project is licensed under the [Sustainable Use License](LICENSE.md).
