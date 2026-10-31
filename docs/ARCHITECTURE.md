# ARCHITECTURE: how the game's code is organised

*The rules here keep the code easy to work on as the game grows. Follow them, and change them only on purpose (log it in DECISIONS).*

## The pieces (game/)

`main.gd` puts the game together at start-up:

| Node | File | Job |
|---|---|---|
| Controls | `controls.gd` | Reads keys and mouse once per frame into a snapshot (T, the hour jump, too). **All player input goes through here**, which is what makes recording and replay possible. |
| World | `world.gd` + `world/*.gd` | The desert, the walking city, its people, and where you can stand (see below). |
| You | `player.gd` | Walking, stairs, bumping into things (using the world's walk map). |
| Camera | `camera_rig.gd` | Follow camera, first person, the diorama view. |
| Mood | `mood.gd` | The light and colour in plain values; presets; `mood.json`; the day's looks by the hour (`DAY_LOOKS`), which it follows until you touch the mood panel. |
| The day | `day.gd` (rules), `day_view.gd` (on screen) | `day.gd`: the clock (day and hour, 7:00-19:00, T, the end of the day) and the town's timetable as plain rules: opening hours, the market's crowd by the hour, where each resident heads when (read from `town_data.gd`). `day_view.gd` runs the clock and shows it: the light, lamps, bells, the city slowing and kneeling, the "Day 1 done" card, the clock in the corner. |
| Sound | `sfx.gd` | Every sound by name; recordings in `audio/<name>/`; `audio/sound_settings.json`. |
| Panels | `panel_base.gd`, `sound_board.gd` (F4), `mood_panel.gd` (F5) | Tools for the user to direct the game with sliders. |
| Using things | `interact.gd`, `dialogue.gd`, `town_data.gd` | E to talk, read, sit and look; which line each resident says next; the cast and their lines, the opening hours, routines and the market's day as plain data. |
| Errand | `errand.gd` | Mira's job: the valve and the rain-catcher. Waits (`active` false) while the morning round runs, until `begin()`. |
| The morning round | `welcome.gd` | The first walk round the town (Pip's deliveries), stop by stop from `ROUND` in `town_data.gd`; hands over to the errand at Bram's, then the evening. Hears what you use from `interact.gd`. On only in normal play (`main.tscn`, `WELCOME_ROUND` in `tuning.gd`); tests call `start_round()` themselves. |
| Shared builds | `export_presets.cfg`, `tools/export_build.ps1` | Exported games (OS feature `template`) can't write their own files: saves go to `user://`, --shots to `user://shots`; they don't record playtests and hide F2/F3. Recordings in `audio/` are exported as they are (`importer="keep"`). **Free any node you make only to borrow its mesh or looks** (a leftover crashed release builds on quitting). |
| The Esc menu | `game_menu.gd` | Pauses the game (it and `sfx.gd` keep running): Resume, Volume (the master bus, saved in `user://options.cfg`), Quality, Quit. Gets Esc only when no F4/F5 panel took it. |
| The guide on screen | `quest_hud.gd` | The goal line, what someone said, the prompt, the progress bar, the key hints and the gold marker with its edge arrow. Shared by the round and the errand; whoever is guiding sets it. |
| Playtest tools | `recorder.gd`, `replay.gd`, `bot.gd` | Recording every session (with its start time), replaying it exactly (from that time), and the test bot. |
| Tuning | `tuning.gd` | Numbers the user can safely change. |

## The world, in layers

`world.gd` only assembles the world (in a fixed order) and moves it each frame. Everything else is a chain of files in `world/`, **each extending the one before** (15 layers):

| # | File | Job |
|---|---|---|
| 1 | `blocks.gd` | The block grid, palette, materials, blocks → meshes, placing blocks, the deck's shape, shared state |
| 2 | `sky_and_ground.gd` | Sky, sun, light settings, the desert that repeats, bones and wrecks |
| 3 | `buildings.gd` | Templates: paving, houses (windows, doors, balconies, roofs), lamps, parasols, trees |
| 4 | `city.gd` | The layout: deck, hull, wall, terraces, stairs, plaza, tower, homes, trees, underside |
| 5 | `errand_sites.gd` | Bram's workshop and the rain-catcher |
| 6 | `facility_kit.gd` | The building kit: walls, doorways, signs, windows, lanterns, seats; the lists of things to use and where residents stand |
| 7 | `outer_places.gd` | The bathhouse, the workshop's inside, Old Wendel's lookout, Pip's street |
| 8 | `facilities.gd` | The guild hall, the tavern and the store; builds all the places in order |
| 9 | `market.gd` | The market street: shops, stalls, signs, lanterns, the crowd's path |
| 10 | `legs.gd` | The six legs and how they walk |
| 11 | `people.gd` | Building people, neighbours, the market crowd |
| 12 | `cast.gd` | The named residents (from `town_data.gd`), their props and habits, the regulars |
| 13 | `walk_map.gd` | Where people can stand, line-of-sight checks, route finding |
| 14 | `routes.gd` | Routes for the residents: a search that does a little each frame (no stutter), for people slimmer than you |
| 15 | `town_life.gd` | The town following the day: residents walk their routines, the market and the regulars come and go, OPEN / CLOSED plaques, brighter lamps at dusk; nobody appears or vanishes where the camera can see |

## Rules

1. **One job per file.** A new system (combat, inventory, requests…) gets its own file or folder. If a file passes about 600 lines, split it.
2. **A world layer only uses layers below it.** The build order lives in `world.gd` alone. If a lower layer needs something from a higher one, move that thing down a layer, or have `world.gd` pass it in.
3. **Separate random numbers per part.** Every build step starts with `_seed("its name")`, so changing one part (say the market) never reshuffles another (the homes). Per-frame randomness belongs to its own part too.
4. **Numbers the user tunes live in data, not deep in code:**
   - gameplay numbers in `tuning.gd`
   - the look in `mood.json` (set with F5)
   - sounds in `audio/sound_settings.json` (set with F4)
   - layout numbers as named constants at the top of their layer
5. **Game rules separate from visuals.** New gameplay (combat, health, inventory, requests) keeps its state and rules in plain scripts that run and test without graphics. The visuals read that state; they don't own it.
6. **All input through `controls.gd`.** Never read the keyboard or mouse anywhere else, or recording and replay break.
7. **Every system gets a test.** It's a headless test in `game/tests/`, listed in `tools/run_tests.ps1`. Visual changes also get a screenshot scene (hidden run) and a separate critic pass.
8. **Prove refactors change nothing.** Run `tools/world_fingerprint.gd` (with `--fixed-fps 20`, or the people's positions depend on frame timing) before and after (it prints a fingerprint of every block, the walk map, the shops and the people) and compare. Then run all the tests.
9. **Tests run hidden** (`tools/godot_offscreen.ps1`, or `--headless`). The game never pops up on the user's screen.
10. **Sounds are named in `sfx.SOUNDS`.** Recordings go in `audio/<name>/` and get a line in `audio/CREDITS.md` (source, author, licence; CC0 preferred).
