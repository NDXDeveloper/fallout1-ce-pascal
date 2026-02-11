# Fallout 1 CE -- C++ API Quick Reference

Complete public function listing organized by module. Each table lists the function name and a brief description of its purpose.

---

## Table of Contents

1. [game/main.cc](#gamemaincc)
2. [game/game.cc](#gamegamecc)
3. [game/object.cc](#gameobjectcc)
4. [game/proto.cc](#gameprotocc)
5. [game/map.cc](#gamemapcc)
6. [game/tile.cc](#gametilecc)
7. [game/combat.cc](#gamecombatcc)
8. [game/combatai.cc](#gamecombataicc)
9. [game/stat.cc](#gamestatcc)
10. [game/skill.cc](#gameskillcc)
11. [game/perk.cc](#gameperkcc)
12. [game/trait.cc](#gametraitcc)
13. [game/critter.cc](#gamecrittercc)
14. [game/item.cc](#gameitemcc)
15. [game/inventry.cc](#gameinventrycc)
16. [game/anim.cc](#gameanimcc)
17. [game/art.cc](#gameartcc)
18. [game/gsound.cc](#gamegsoundcc)
19. [game/scripts.cc](#gamescriptscc)
20. [game/gdialog.cc](#gamegdialogcc)
21. [game/intface.cc](#gameintfacecc)
22. [game/gmouse.cc](#gamegmousecc)
23. [game/worldmap.cc](#gameworldmapcc)
24. [game/loadsave.cc](#gameloadsavecc)
25. [game/queue.cc](#gamequeuecc)
26. [game/palette.cc](#gamepalettecc)
27. [game/cache.cc](#gamecachecc)
28. [game/message.cc](#gamemessagecc)
29. [game/config.cc](#gameconfigcc)
30. [game/party.cc](#gamepartycc)
31. [int/intrpret.cc](#intintrpretcc)
32. [int/sound.cc](#intsoundcc)
33. [int/window.cc](#intwindowcc)
34. [int/movie.cc](#intmoviecc)
35. [plib/gnw/gnw.cc](#plibgnwgnwcc)
36. [plib/gnw/input.cc](#plibgnwinputcc)
37. [plib/gnw/svga.cc](#plibgnwsvgacc)
38. [plib/gnw/mouse.cc](#plibgnwmousecc)
39. [plib/gnw/kb.cc](#plibgnwkbcc)
40. [plib/gnw/button.cc](#plibgnwbuttoncc)
41. [plib/gnw/text.cc](#plibgnwtextcc)
42. [plib/db/db.cc](#plibdbdbcc)
43. [plib/color/color.cc](#plibcolorcolorcc)
44. [audio_engine.cc](#audio_enginecc)
45. [fps_limiter.cc](#fps_limitercc)
46. [platform_compat.cc](#platform_compatcc)
47. [movie_lib.cc](#movie_libcc)

---

## game/main.cc

Top-level game entry point, main loop, and system initialization/teardown.

| Function | Description |
|---|---|
| `gnw_main` | Entry point called by the GNW windowing system after platform init |
| `main_game_loop` | Primary game loop; processes input, updates world, renders each frame |
| `game_handle_input` | Dispatches keyboard/mouse input to the appropriate game subsystem |
| `main_load_new` | Starts a new game by loading the starting map and initializing the player |
| `main_init_system` | Initializes all engine subsystems (video, audio, input, DB) in order |
| `main_exit_system` | Shuts down all engine subsystems in reverse order |

---

## game/game.cc

High-level game state management: initialization, reset, and UI toggling.

| Function | Description |
|---|---|
| `game_init` | Initializes the game layer (loads master data, protos, scripts, etc.) |
| `game_reset` | Resets game state to defaults (used when starting a new game or loading) |
| `game_exit` | Frees all game-layer resources and shuts down subsystems |
| `game_ui_disable` | Disables the game UI (hides interface bar, disables mouse) |
| `game_ui_enable` | Re-enables the game UI after a disable call |

---

## game/object.cc

Object creation, destruction, movement, rendering, and serialization.

| Function | Description |
|---|---|
| `obj_new` | Allocates and initializes a new game object from a prototype |
| `obj_delete` | Destroys an object and frees its memory |
| `obj_move_to_tile` | Moves an object to a specified hex tile and elevation |
| `obj_change_fid` | Changes the frame ID (art) of an object |
| `obj_turn_on` | Sets the object's "on" flag (e.g., lights, traps) |
| `obj_turn_off` | Clears the object's "on" flag |
| `obj_set_light` | Sets the light radius and intensity for an object |
| `obj_save` | Serializes an object to a save file |
| `obj_load` | Deserializes an object from a save file |

---

## game/proto.cc

Prototype (template) management for all game object types.

| Function | Description |
|---|---|
| `proto_init` | Loads prototype list files and initializes the proto cache |
| `proto_reset` | Clears cached prototypes, forcing reload on next access |
| `proto_exit` | Frees all prototype data and shuts down the subsystem |
| `proto_load_pid` | Loads a specific prototype by PID from disk into cache |
| `proto_ptr` | Returns a pointer to the prototype data for a given PID |
| `proto_name` | Returns the display name string for a prototype |

---

## game/map.cc

Map loading, saving, and state management.

| Function | Description |
|---|---|
| `map_init` | Initializes the map subsystem and allocates per-elevation data |
| `map_reset` | Clears the current map state (objects, tiles, scripts) |
| `map_exit` | Frees all map resources and shuts down the subsystem |
| `map_load` | Loads a map by name (handles entrance placement, scripts, etc.) |
| `map_load_file` | Low-level map file reader; parses header, tiles, objects, scripts |
| `map_save_file` | Writes the current map state to a file |
| `map_check_state` | Checks and handles map state transitions (e.g., random encounters) |

---

## game/tile.cc

Hex tile engine: coordinate conversion, scrolling, and display refresh.

| Function | Description |
|---|---|
| `tile_init` | Initializes tile rendering buffers and lookup tables |
| `tile_reset` | Resets tile state (scroll position, roof visibility) |
| `tile_exit` | Frees tile buffers and lookup tables |
| `tile_coord` | Converts a tile number to screen pixel coordinates |
| `tile_num` | Converts screen pixel coordinates to a tile number |
| `tile_scroll_to` | Scrolls the viewport to center on a given tile |
| `tile_refresh_display` | Redraws the visible tile area and all objects on it |

---

## game/combat.cc

Turn-based combat system: sequencing, attacks, and hit resolution.

| Function | Description |
|---|---|
| `combat_init` | Initializes combat subsystem state and lookup tables |
| `combat_reset` | Resets combat state between encounters |
| `combat_exit` | Frees combat resources |
| `combat` | Enters combat mode; runs the turn-based combat loop until resolved |
| `combat_check_bad_shot` | Checks if a shot is blocked or invalid (friendlies in line of fire, etc.) |
| `combat_attack` | Executes a single attack action (to-hit roll, damage, animation) |
| `combat_load` | Loads combat state from a save file |
| `combat_save` | Saves combat state to a save file |

---

## game/combatai.cc

AI decision-making for NPCs during combat.

| Function | Description |
|---|---|
| `combat_ai_init` | Loads AI packet data (disposition tables) from ai.txt |
| `combat_ai_reset` | Resets AI state between encounters |
| `combat_ai_exit` | Frees AI data |
| `combat_ai` | Main AI entry point; decides and executes actions for one NPC turn |
| `combat_ai_load` | Loads AI state from a save file |
| `combat_ai_save` | Saves AI state to a save file |

---

## game/stat.cc

SPECIAL stats, derived stats, and stat queries.

| Function | Description |
|---|---|
| `stat_init` | Initializes stat subsystem and loads stat description messages |
| `stat_reset` | Resets stat state |
| `stat_exit` | Frees stat resources |
| `stat_level` | Returns the effective (base + bonus + trait/perk) value of a stat |
| `stat_get_base` | Returns the base value of a stat for a critter |
| `stat_set_base` | Sets the base value of a stat for a critter |
| `stat_get_bonus` | Returns the temporary bonus value of a stat |
| `stat_set_bonus` | Sets the temporary bonus value of a stat |
| `inc_stat` | Increments a stat by 1 (with validation and limits) |
| `dec_stat` | Decrements a stat by 1 (with validation and limits) |
| `stat_recalc_derived` | Recalculates all derived stats (HP, AC, AP, etc.) from base SPECIAL |
| `stat_result` | Performs a stat check roll and returns the result (critical/success/fail) |
| `stat_pc_get` | Gets a PC-specific stat value (age, gender, etc.) |
| `stat_pc_set` | Sets a PC-specific stat value |
| `stat_name` | Returns the display name of a stat |
| `stat_description` | Returns the description text of a stat |
| `stat_load` | Loads stat data from a save file |
| `stat_save` | Saves stat data to a save file |

---

## game/skill.cc

Character skills: levels, point spending, skill checks, and skill use.

| Function | Description |
|---|---|
| `skill_init` | Initializes skill subsystem and loads skill description messages |
| `skill_reset` | Resets skill state to defaults |
| `skill_exit` | Frees skill resources |
| `skill_level` | Returns the effective skill level (base + bonuses + perks + traits) |
| `skill_base` | Returns the base skill level derived from SPECIAL stats |
| `skill_points` | Returns the raw skill points invested in a skill |
| `skill_inc_point` | Spends skill points to increment a skill by one level |
| `skill_dec_point` | Refunds skill points by decrementing a skill by one level |
| `skill_result` | Performs a skill check roll; returns critical/success/fail |
| `skill_contest` | Performs an opposed skill contest between two critters |
| `skill_use` | Attempts to use a skill on a target (lockpick, first aid, etc.) |
| `skill_check_stealing` | Performs a steal attempt, checking detection probability |
| `skill_name` | Returns the display name of a skill |
| `skill_description` | Returns the description text of a skill |
| `skill_load` | Loads skill data from a save file |
| `skill_save` | Saves skill data to a save file |

---

## game/perk.cc

Perk system: granting, removing, and applying perk effects.

| Function | Description |
|---|---|
| `perk_init` | Initializes perk subsystem and loads perk description messages |
| `perk_reset` | Resets perk state to defaults |
| `perk_exit` | Frees perk resources |
| `perk_add` | Grants a perk to a critter (increments rank) |
| `perk_sub` | Removes a perk rank from a critter |
| `perk_level` | Returns the current rank of a perk for a critter |
| `perk_add_effect` | Applies the stat/skill bonuses granted by a perk |
| `perk_remove_effect` | Removes the stat/skill bonuses of a perk |
| `perk_adjust_skill` | Returns the total skill bonus from all perks for a given skill |
| `perk_name` | Returns the display name of a perk |
| `perk_description` | Returns the description text of a perk |
| `perk_load` | Loads perk data from a save file |
| `perk_save` | Saves perk data to a save file |

---

## game/trait.cc

Trait system: selection and stat/skill adjustments.

| Function | Description |
|---|---|
| `trait_init` | Initializes trait subsystem and loads trait description messages |
| `trait_reset` | Resets trait selections to none |
| `trait_exit` | Frees trait resources |
| `trait_set` | Sets the two selected traits for the player character |
| `trait_get` | Gets the currently selected traits |
| `trait_adjust_stat` | Returns the stat modifier from selected traits for a given stat |
| `trait_adjust_skill` | Returns the skill modifier from selected traits for a given skill |
| `trait_name` | Returns the display name of a trait |
| `trait_description` | Returns the description text of a trait |
| `trait_load` | Loads trait data from a save file |
| `trait_save` | Saves trait data to a save file |

---

## game/critter.cc

Critter (living object) operations: HP, poison, rads, death, and healing.

| Function | Description |
|---|---|
| `critter_init` | Initializes critter subsystem |
| `critter_reset` | Resets critter state |
| `critter_exit` | Frees critter resources |
| `critter_name` | Returns the display name of a critter |
| `critter_pc_set_name` | Sets the player character's name |
| `critter_get_hits` | Returns the current hit points of a critter |
| `critter_adjust_hits` | Adds or subtracts hit points from a critter |
| `critter_get_poison` | Returns the current poison level of a critter |
| `critter_adjust_poison` | Adds or subtracts from a critter's poison level |
| `critter_get_rads` | Returns the current radiation level of a critter |
| `critter_adjust_rads` | Adds or subtracts from a critter's radiation level |
| `critter_kill` | Kills a critter (sets flags, plays death animation, updates kill count) |
| `critter_is_dead` | Returns whether a critter is dead |
| `critter_is_crippled` | Returns whether a critter has any crippled limbs |
| `critter_heal_hours` | Heals a critter based on elapsed game hours (rest/travel) |
| `critter_sneak_check` | Performs a sneak skill check for the player |
| `critter_load` | Loads critter data from a save file |
| `critter_save` | Saves critter data to a save file |

---

## game/item.cc

Item properties, inventory manipulation, weapon/armor/drug queries.

| Function | Description |
|---|---|
| `item_init` | Initializes item subsystem |
| `item_reset` | Resets item state |
| `item_exit` | Frees item resources |
| `item_add_mult` | Adds a quantity of an item to a container/critter inventory |
| `item_remove_mult` | Removes a quantity of an item from a container/critter inventory |
| `item_move` | Moves an item from one container to another |
| `item_drop_all` | Drops all items from a critter's inventory onto the ground |
| `item_name` | Returns the display name of an item |
| `item_get_type` | Returns the item type (weapon, armor, ammo, drug, container, misc) |
| `item_size` | Returns the inventory size (weight units) of an item |
| `item_weight` | Returns the weight of an item (or stack) |
| `item_cost` | Returns the base cost of an item (before barter modifiers) |
| `item_w_damage` | Returns the damage range (min/max) of a weapon |
| `item_w_range` | Returns the effective range of a weapon |
| `item_w_try_reload` | Attempts to reload a weapon from available ammo in inventory |
| `item_ar_ac` | Returns the armor class bonus of an armor item |
| `item_ar_dr` | Returns the damage resistance percentage of an armor for a damage type |
| `item_ar_dt` | Returns the damage threshold of an armor for a damage type |
| `item_d_take_drug` | Applies drug effects to a critter (stat changes, addiction check) |
| `item_load` | Loads item data from a save file |
| `item_save` | Saves item data to a save file |

---

## game/inventry.cc

Inventory UI screens: inventory, loot, barter, and steal interfaces.

| Function | Description |
|---|---|
| `handle_inventory` | Opens and runs the main inventory screen |
| `inven_wield` | Equips an item into a critter's hand slot or armor slot |
| `inven_unwield` | Unequips an item from a critter's hand or armor slot |
| `inven_right_hand` | Returns the item in the critter's right hand slot |
| `inven_left_hand` | Returns the item in the critter's left hand slot |
| `inven_worn` | Returns the item in the critter's armor slot |
| `loot_container` | Opens the loot/container UI for transferring items |
| `barter_inventory` | Opens the barter UI for trading items with an NPC |
| `inven_steal_container` | Opens the steal UI for pickpocketing an NPC |

---

## game/anim.cc

Animation sequencing engine: queuing, path-finding, and execution.

| Function | Description |
|---|---|
| `anim_init` | Initializes the animation subsystem and sequence queues |
| `anim_reset` | Clears all pending animation sequences |
| `anim_exit` | Frees animation resources |
| `register_begin` | Begins recording a new animation sequence |
| `register_end` | Finalizes and submits the current animation sequence for playback |
| `register_priority` | Sets the priority of the current animation sequence |
| `register_object_move_to_tile` | Queues an object walk-to-tile animation |
| `register_object_run_to_tile` | Queues an object run-to-tile animation |
| `register_object_animate` | Queues a generic animation (e.g., use, dodge, hit) for an object |
| `register_object_change_fid` | Queues a frame ID change for an object |
| `register_object_call` | Queues a callback function to be called during the sequence |
| `register_object_play_sfx` | Queues a sound effect to play during the sequence |
| `make_path` | Computes an A* hex path between two tiles, avoiding obstacles |
| `make_straight_path` | Computes a straight-line path (for line-of-sight/fire checks) |
| `dude_move` | Initiates a walk animation for the player character |
| `dude_run` | Initiates a run animation for the player character |
| `dude_fidget` | Triggers a random idle fidget animation for the player |

---

## game/art.cc

Art/sprite asset loading, caching, and frame queries.

| Function | Description |
|---|---|
| `art_init` | Initializes the art subsystem; loads art database lists |
| `art_reset` | Resets art cache state |
| `art_exit` | Frees art resources and cache |
| `art_ptr_lock` | Locks an art asset in cache and returns a pointer to frame data |
| `art_lock` | Locks an art asset and returns the full art structure |
| `art_ptr_unlock` | Unlocks a previously locked art asset |
| `art_exists` | Checks whether an art asset exists for a given FID |
| `art_fid_valid` | Validates that a FID is well-formed and references existing art |
| `art_frame_width` | Returns the pixel width of a specific frame |
| `art_frame_length` | Returns the pixel height of a specific frame |
| `art_frame_data` | Returns a pointer to the raw pixel data of a frame |
| `art_id` | Constructs a FID from object type, index, animation, and direction |
| `art_get_name` | Returns the file path string for a given FID |

---

## game/gsound.cc

Game sound: background music, speech, and sound effect playback.

| Function | Description |
|---|---|
| `gsound_init` | Initializes the game sound subsystem |
| `gsound_reset` | Resets sound state (stops all playing sounds) |
| `gsound_exit` | Shuts down the game sound subsystem |
| `gsound_background_play` | Starts playing a background music track by name |
| `gsound_background_stop` | Stops the currently playing background music |
| `gsound_speech_play` | Plays a speech audio file (voice-over) |
| `gsound_speech_stop` | Stops the currently playing speech audio |
| `gsound_play_sfx_file` | Plays a one-shot sound effect file |
| `gsound_set_master_volume` | Sets the master volume level |
| `gsound_set_sfx_volume` | Sets the sound effects volume level |
| `gsnd_build_character_sfx_name` | Builds a sound file name for character actions (hit, death, etc.) |
| `gsnd_build_weapon_sfx_name` | Builds a sound file name for weapon actions (fire, reload, etc.) |

---

## game/scripts.cc

Script instance management and execution interface.

| Function | Description |
|---|---|
| `scr_init` | Initializes the scripting subsystem |
| `scr_reset` | Resets all script instances and global script state |
| `scr_exit` | Frees all script data and shuts down the subsystem |
| `scr_new` | Creates a new script instance and assigns it a script ID |
| `scr_remove` | Removes and frees a script instance |
| `scr_ptr` | Returns a pointer to the script data for a given script ID |
| `scr_set_objs` | Sets the self/target object references for a script instance |
| `exec_script_proc` | Executes a named procedure within a script instance |
| `scr_load` | Loads script state from a save file |
| `scr_save` | Saves script state to a save file |
| `loadProgram` | Loads a compiled script program (.int file) into memory |

---

## game/gdialog.cc

NPC dialogue system: conversation flow, options, and barter.

| Function | Description |
|---|---|
| `gdialog_init` | Initializes the dialogue subsystem |
| `gdialog_reset` | Resets dialogue state |
| `gdialog_exit` | Frees dialogue resources |
| `gdialog_enter` | Enters dialogue mode with an NPC (sets up UI, runs talk script) |
| `gDialogStart` | Starts a dialogue sequence (called from scripts) |
| `gDialogSayMessage` | Displays an NPC message line in the dialogue window |
| `gDialogOption` | Adds a player dialogue option/response choice |
| `gDialogReply` | Sets the NPC reply text for the current dialogue node |
| `gDialogGo` | Displays the current dialogue node and waits for player choice |
| `gdActivateBarter` | Switches from dialogue mode to barter mode |

---

## game/intface.cc

HUD / interface bar: action points, HP, AC, active items, combat buttons.

| Function | Description |
|---|---|
| `intface_init` | Initializes the interface bar window and all HUD elements |
| `intface_reset` | Resets the interface bar to default state |
| `intface_exit` | Frees interface bar resources |
| `intface_show` | Shows the interface bar at the bottom of the screen |
| `intface_hide` | Hides the interface bar |
| `intface_enable` | Enables interface bar input (buttons become clickable) |
| `intface_disable` | Disables interface bar input |
| `intface_update_hit_points` | Refreshes the HP display on the interface bar |
| `intface_update_ac` | Refreshes the AC display on the interface bar |
| `intface_update_move_points` | Refreshes the action/move points display (combat mode) |
| `intface_update_items` | Refreshes the active item slots display |

---

## game/gmouse.cc

Game mouse cursor: mode switching, hex highlighting, and event dispatch.

| Function | Description |
|---|---|
| `gmouse_init` | Initializes game mouse subsystem and loads cursor art |
| `gmouse_reset` | Resets mouse state |
| `gmouse_exit` | Frees mouse cursor resources |
| `gmouse_enable` | Enables game mouse processing |
| `gmouse_disable` | Disables game mouse processing |
| `gmouse_set_cursor` | Sets the current mouse cursor graphic |
| `gmouse_3d_set_mode` | Sets the 3D (hex) mouse cursor mode (move, look, use, etc.) |
| `gmouse_handle_event` | Processes a mouse event and dispatches to the appropriate handler |

---

## game/worldmap.cc

World map: travel, encounters, and town entry.

| Function | Description |
|---|---|
| `init_world_map` | Initializes world map data (cities, encounters, terrain) |
| `save_world_map` | Saves world map state to a save file |
| `load_world_map` | Loads world map state from a save file |
| `world_map` | Opens and runs the world map travel screen |
| `town_map` | Opens and runs the town map (local area) screen |
| `worldmap_script_jump` | Teleports the player to a location via script command |

---

## game/loadsave.cc

Save/load game UI and serialization orchestration.

| Function | Description |
|---|---|
| `InitLoadSave` | Initializes the save/load subsystem |
| `ResetLoadSave` | Resets save/load state |
| `SaveGame` | Opens the save game UI and writes a save file |
| `LoadGame` | Opens the load game UI and reads a save file |
| `isLoadingGame` | Returns whether a game load is currently in progress |

---

## game/queue.cc

Timed event queue: scheduled callbacks for drugs, radiation, healing, etc.

| Function | Description |
|---|---|
| `queue_init` | Initializes the event queue |
| `queue_reset` | Clears all pending events from the queue |
| `queue_exit` | Frees queue resources |
| `queue_add` | Adds a timed event to the queue (fires after N ticks) |
| `queue_remove` | Removes all events of a given type for a given object |
| `queue_find` | Searches the queue for an event matching type and object |
| `queue_process` | Processes all events whose scheduled time has elapsed |
| `queue_load` | Loads queue state from a save file |
| `queue_save` | Saves queue state to a save file |

---

## game/palette.cc

Palette management: fading and color table transitions.

| Function | Description |
|---|---|
| `palette_init` | Initializes the palette subsystem |
| `palette_reset` | Resets palette to default state |
| `palette_exit` | Frees palette resources |
| `palette_fade_to` | Smoothly fades the screen palette to a target palette |

---

## game/cache.cc

Generic asset cache with LRU eviction (used by art, proto, etc.).

| Function | Description |
|---|---|
| `cache_init` | Initializes a cache instance with a size limit and load callback |
| `cache_exit` | Frees all cached entries and the cache structure |
| `cache_lock` | Locks (loads if needed) an entry in the cache by key; returns data pointer |
| `cache_unlock` | Unlocks a previously locked cache entry, allowing eviction |

---

## game/message.cc

Message file (.msg) loader for localized UI strings and descriptions.

| Function | Description |
|---|---|
| `message_init` | Initializes a message list structure |
| `message_exit` | Frees a message list structure |
| `message_load` | Loads a .msg file into a message list |
| `message_unload` | Unloads a .msg file and frees its strings |
| `message_search` | Searches a message list by numeric ID and returns the text |

---

## game/config.cc

INI-style configuration file reader/writer.

| Function | Description |
|---|---|
| `config_init` | Initializes a config structure |
| `config_exit` | Frees a config structure and all its entries |
| `config_load` | Loads a .cfg/.ini file into a config structure |
| `config_save` | Writes a config structure out to a .cfg/.ini file |
| `config_get_string` | Retrieves a string value by section and key name |
| `config_set_string` | Sets a string value by section and key name |

---

## game/party.cc

Party member (companion) management.

| Function | Description |
|---|---|
| `partyMemberInit` | Initializes party member subsystem and loads party data |
| `partyMemberReset` | Resets party state (clears all party members) |
| `partyMemberExit` | Frees party member resources |
| `partyMemberAdd` | Adds a critter to the player's party |
| `partyMemberRemove` | Removes a critter from the player's party |
| `partyMemberLoad` | Loads party member data from a save file |
| `partyMemberSave` | Saves party member data to a save file |

---

## int/intrpret.cc

Script interpreter: bytecode VM for .int scripts.

| Function | Description |
|---|---|
| `allocateProgram` | Allocates and initializes a new program (script VM) instance |
| `interpretFreeProgram` | Frees a program instance and all its associated data |
| `runScript` | Loads and starts execution of a script by file name |
| `runProgram` | Starts or resumes execution of an already-loaded program |
| `interpret` | Executes bytecode instructions for one time slice |
| `executeProc` | Queues a named procedure for execution in a program |
| `executeProcedure` | Immediately executes a procedure by index in a program |
| `interpretFindProcedure` | Looks up a procedure index by name in a program |
| `clearPrograms` | Stops and frees all currently loaded programs |
| `updatePrograms` | Updates all active programs (runs one time slice for each) |
| `interpretAddFunc` | Registers an external (C/engine) function callable from scripts |

---

## int/sound.cc

Low-level sound system: allocation, loading, playback, and mixing.

| Function | Description |
|---|---|
| `soundInit` | Initializes the sound system with a given configuration |
| `soundClose` | Shuts down the sound system and frees all sounds |
| `soundAllocate` | Allocates a new sound handle |
| `soundDelete` | Frees a sound handle and its associated buffer |
| `soundLoad` | Loads audio data into a sound handle from a file |
| `soundPlay` | Begins playback of a sound |
| `soundStop` | Stops playback of a sound |
| `soundVolume` | Sets the volume of a sound |
| `soundFade` | Fades a sound's volume over a duration |
| `soundUpdate` | Updates the sound system (called each frame to process fades, streaming) |

---

## int/window.cc

Script-accessible windowing system for in-game UI screens.

| Function | Description |
|---|---|
| `initWindow` | Initializes the script window subsystem |
| `windowClose` | Shuts down the script window subsystem |
| `createWindow` | Creates a new script window with position, size, and flags |
| `deleteWindow` | Destroys a script window by name |
| `selectWindow` | Sets a script window as the current target for drawing operations |
| `windowDraw` | Redraws the current script window to the screen |
| `windowOutput` | Outputs text to the current script window at a position |
| `windowPrint` | Prints formatted text to the current script window |
| `windowAddButton` | Adds a clickable button to the current script window |
| `windowPlayMovie` | Plays an MVE movie within the current script window |

---

## int/movie.cc

MVE movie playback interface.

| Function | Description |
|---|---|
| `initMovie` | Initializes the movie playback subsystem |
| `movieClose` | Shuts down the movie subsystem |
| `movieRun` | Loads and begins playing an MVE movie file |
| `movieStop` | Stops the currently playing movie |
| `moviePlaying` | Returns whether a movie is currently playing |
| `movieSetVolume` | Sets the audio volume for movie playback |

---

## plib/gnw/gnw.cc

GNW windowing core: window creation, drawing, and buffer management.

| Function | Description |
|---|---|
| `win_init` | Initializes the GNW windowing system |
| `win_exit` | Shuts down the GNW windowing system and frees all windows |
| `win_add` | Creates a new window with position, size, color, and flags |
| `win_delete` | Destroys a window and frees its resources |
| `win_draw` | Redraws a window (blits its buffer to the screen) |
| `win_draw_rect` | Redraws a rectangular region of a window |
| `win_get_buf` | Returns a pointer to the pixel buffer of a window |

---

## plib/gnw/input.cc

GNW input system: event loop, timing, and background processes.

| Function | Description |
|---|---|
| `GNW_input_init` | Initializes the GNW input subsystem |
| `GNW_input_exit` | Shuts down the GNW input subsystem |
| `get_input` | Polls for and returns the next input event (key/mouse/button) |
| `get_time` | Returns the current time in millisecond ticks |
| `elapsed_time` | Returns the elapsed time since a given timestamp |
| `pause_for_tocks` | Blocks for a specified number of milliseconds |
| `add_bk_process` | Registers a background process (callback called each input cycle) |
| `remove_bk_process` | Unregisters a background process |

---

## plib/gnw/svga.cc

Video output: SDL surface management, palette, and screen rendering.

| Function | Description |
|---|---|
| `svga_init` | Initializes the video output subsystem (creates SDL window/surface) |
| `svga_exit` | Shuts down the video output subsystem |
| `screenGetWidth` | Returns the logical screen width in pixels |
| `screenGetHeight` | Returns the logical screen height in pixels |
| `GNW95_SetPalette` | Sets the 256-color VGA palette |
| `GNW95_ShowRect` | Blits a rectangular region from the back buffer to the screen |
| `renderPresent` | Presents the current frame (flips buffers / updates display) |

---

## plib/gnw/mouse.cc

Low-level mouse input: position, buttons, and cursor visibility.

| Function | Description |
|---|---|
| `GNW_mouse_init` | Initializes the mouse subsystem |
| `GNW_mouse_exit` | Shuts down the mouse subsystem |
| `mouse_show` | Shows the mouse cursor |
| `mouse_hide` | Hides the mouse cursor |
| `mouse_get_position` | Returns the current mouse X/Y position |
| `mouse_set_position` | Warps the mouse cursor to a given X/Y position |
| `mouse_get_buttons` | Returns the current mouse button state (left, right, middle) |

---

## plib/gnw/kb.cc

Keyboard input: raw key reading and keyboard state management.

| Function | Description |
|---|---|
| `GNW_kb_set` | Installs the GNW keyboard handler |
| `GNW_kb_restore` | Restores the original keyboard handler |
| `kb_getch` | Returns the next key from the keyboard buffer |
| `kb_clear` | Clears the keyboard input buffer |
| `kb_disable` | Disables keyboard input processing |
| `kb_enable` | Enables keyboard input processing |

---

## plib/gnw/button.cc

GNW button widgets: registration, images, and sound callbacks.

| Function | Description |
|---|---|
| `win_register_button` | Creates and registers a clickable button in a window |
| `win_register_button_image` | Sets the up/down/hover images for a button |
| `win_register_button_sound_func` | Sets the sound callback functions for button press/release/hover |

---

## plib/gnw/text.cc

Bitmap font rendering: loading fonts and drawing text to buffers.

| Function | Description |
|---|---|
| `text_font` | Sets the active font by font index |
| `text_width` | Returns the pixel width of a string in the current font |
| `text_height` | Returns the pixel height of the current font |
| `text_to_buf` | Renders a text string into a pixel buffer at a given position |

---

## plib/db/db.cc

Database / virtual filesystem: file access through DAT archives and directories.

| Function | Description |
|---|---|
| `db_init` | Initializes the database subsystem (opens DAT files, sets search paths) |
| `db_select` | Selects the active database for subsequent file operations |
| `db_close` | Closes a database (DAT file) |
| `db_exit` | Shuts down the database subsystem and closes all open databases |
| `db_fopen` | Opens a file from the database (DAT or filesystem) |
| `db_fclose` | Closes a database file handle |
| `db_fread` | Reads data from a database file |
| `db_fwrite` | Writes data to a database file |
| `db_fseek` | Seeks to a position in a database file |
| `db_ftell` | Returns the current position in a database file |
| `db_read_to_buf` | Reads an entire file into a pre-allocated buffer |
| `db_filelength` | Returns the size in bytes of a database file |
| `db_get_file_list` | Returns a list of files matching a pattern in the database |

---

## plib/color/color.cc

256-color palette operations: mixing, gamma, and color tables.

| Function | Description |
|---|---|
| `initColors` | Initializes the color subsystem and builds color lookup tables |
| `colorsClose` | Frees color resources and lookup tables |
| `setSystemPalette` | Sets the active 256-color palette and rebuilds color tables |
| `fadeSystemPalette` | Smoothly fades the system palette over multiple frames |
| `colorMixAdd` | Returns the color index resulting from additive blending of two colors |
| `colorMixMul` | Returns the color index resulting from multiplicative blending |
| `colorGamma` | Sets the gamma correction level and rebuilds the gamma table |
| `loadColorTable` | Loads a color translation table (.clt) from disk |

---

## audio_engine.cc

SDL-based audio engine: buffer management and playback.

| Function | Description |
|---|---|
| `audioEngineInit` | Initializes the SDL audio engine |
| `audioEngineExit` | Shuts down the audio engine and frees all buffers |
| `audioEngineCreateSoundBuffer` | Allocates a new sound buffer with a given format and size |
| `audioEngineSoundBufferPlay` | Begins playback of a sound buffer (one-shot or looping) |
| `audioEngineSoundBufferStop` | Stops playback of a sound buffer |
| `audioEngineSoundBufferRelease` | Frees a sound buffer and its associated memory |

---

## fps_limiter.cc

Frame rate limiter utility.

| Function | Description |
|---|---|
| `FpsLimiter::mark` | Records the timestamp at the start of a frame |
| `FpsLimiter::throttle` | Sleeps if necessary to maintain the target frame rate |

---

## platform_compat.cc

Cross-platform compatibility wrappers (replacing Win32 API calls).

| Function | Description |
|---|---|
| `compat_stricmp` | Case-insensitive string comparison (portable `_stricmp`) |
| `compat_strupr` | Converts a string to uppercase in-place (portable `_strupr`) |
| `compat_splitpath` | Splits a file path into drive, directory, name, and extension |
| `compat_makepath` | Builds a file path from drive, directory, name, and extension |
| `compat_fopen` | Opens a file with path separator normalization |
| `compat_mkdir` | Creates a directory with platform-appropriate permissions |
| `compat_timeGetTime` | Returns a monotonic time in milliseconds (replaces `timeGetTime`) |
| `compat_windows_path_to_native` | Converts backslash paths to forward-slash (native) paths |

---

## movie_lib.cc

MVE (Interplay movie) decoder library: frame stepping and configuration.

| Function | Description |
|---|---|
| `_MVE_rmPrepMovie` | Prepares an MVE file for playback (reads header, sets up decoder) |
| `_MVE_rmStepMovie` | Decodes and displays the next frame of an MVE movie |
| `_MVE_rmEndMovie` | Ends MVE playback and frees decoder resources |
| `movieLibSetVolume` | Sets the audio volume for the MVE audio decoder |
| `movieLibSetReadProc` | Sets the file read callback used by the MVE decoder |
