# STATUS: start here

**New session? Read this first**, then `docs/TASTE.md`, `docs/GAME.md` and the end of `docs/DECISIONS.md` (as `CLAUDE.md` says). For the user's own words and reactions, read `docs/history/` (session 02 is the latest).

_Last updated: 2026-10-26, session 03 (home PC): reviewed session 02's work, tests and hidden runs checked on the AMD card. See "Home PC check after session 02" below._

## Where we are

- ✅ **Phase 1: Discover**: done. Three core desires confirmed (see TASTE.md).
- ✅ **Phase 2: Pick a direction**: done. **"Strider Home"**: you're one resident of a walking city crossing a dangerous wasteland.
- ✅ **Phase 3: First playable toy**: done. `game/` is the terraced city: you walk it (first person or behind you), it walks and sways, there are 50 neighbours, and Mira's errand (valve from Bram's workshop to the rain-catcher). Playtested 3 times, with fixes after each.
- ➡️ **Phase 4: Grow it**: the user reshaped the core loop (see GAME.md): day in town (shops, guild, requests), dangerous night expeditions with combat, then race home at dawn. **The next milestone isn't locked: it waits on the combat-style decision.**
- 🧪 **Session 03 (home PC):** the user said the city feels too small and the paths cramped, and that a big city means "crowds and bustle". So we built the **Market Street test** on branch `experiment/market-street` (see Branches). **Next:** the user plays it (`git switch experiment/market-street`, then `game/run.bat`), then we decide whether to merge it.

### What session 02 did (short)
Code review and fixes; tests run hidden (`tools/godot_offscreen.ps1`); a 2.5x faster mesher; the terraced city; a 10x experiment (branch `experiment/city-10x`, parked); the first playable toy; playtest tools (recorder, F8, exact replay, F3); 3 playtests; first person.

## Open questions for the user (ask one or two at a time)

1. **What kind of combat?** The user postponed this at the end of session 02. Options: (a) action, real time; (b) turn-based tactics like Chrono Ark (a game they love; it makes AI companions easy); (c) real time with pause to order the party. Ask "what part?" (the rush of reflexes, a clever plan, or the party's spectacle). *Claude's suggestion: two tiny combat toys on a branch (an afternoon each), one action and one turn-based, against the same desert creature. Let the user play both and react.*
2. **Companions:** the user wants a party of AI companions (neighbours, guild members). *Claude's lean: the first expedition solo, then one simple companion who follows, talks, carries and warns at dawn (no fighting), and fighting companions once combat exists.* Not confirmed.
3. **Fail state when stranded:** the user said "catch up on a vehicle, or game over and reload." *Claude suggested softer (a caravan rescues you, you lose your haul) and no vehicles in the first version (a sprint on foot after the rising city).* Not confirmed.
4. **Which facilities first** (shops, guild, tavern, workshop…) and how the city grows to hold them (district by district).
5. *(Low priority)* **Nano Banana Pro access** for concept art: the Gemini app or an API key? Only matters once we do concept art.

## Suggested next step

Settle question 1 (combat style). Then propose the first Phase 4 milestone with defaults. Claude's draft is **"One night out"**: a guild request at dusk → the city kneels → ride the cargo lift down → a dangerous desert night with combat → race home as dawn breaks and the legs rise. Keep it one request and one area, and add facilities and companions after.

## Important rules learned (don't break these)

- **It has to look good.** That's the user's #1 fear from past projects. Keep art code-built and consistent, and use screenshots plus a **separate critic** pass on visuals.
- **The user lives at street level.** They play in first person most of the time (69% in playtest 3). Judge things at human scale: door sizes, things in the way, what you see from your own eyes.
- **"Bigger city" means more places with a purpose** (confirmed), not more area. Never grow the city by repeating the same houses.
- **Never show the user story spoilers.** The payoff is gameplay-first, with a short story checked by blind critic agents ("predict the twist" and "find the clues" tests). The user judges it only by playing blind.
- **Living world = the clever fake:** residents with routines and reactions, not deep AI.
- Don't build Huge things. Ask before paid tools.
- **Tests run hidden.** The game must never pop up on the user's screen or grab their mouse and keyboard while Claude tests. Use `tools/godot_offscreen.ps1`, or `--headless` for logic. Open a visible window only when the user asks to see it.
- **After every change to `game/`, run `tools/run_tests.ps1`.** When a test fails after a change, check whether the test or the game is wrong before "fixing" either.
- **Playtests are the main feedback loop.** The user plays and presses F8; Claude reads the logs, replays the session to see the flagged moments, fixes, and proves the fix with a test that reproduces the user's exact situation.
- **Save only the conversation to `docs/history/`** (`--chat-only`): the user wants later sessions to read between the lines, not the commands.

## Art status

- **The game (`game/world.gd`) is now the reference for the look.** It's the terraced city from the look test, plus: legs attached outside the deck on struts, 2.4 m doors, lamps off the main streets, wade-through plaza flowers, Bram's workshop and the rain-catcher.
- **Look tests (frozen, for comparison):** `prototypes/look_test_hd/` (flat, 20 cm blocks), `prototypes/look_test_terraced/`, `prototypes/look_test/` (coarse). Critic scores (terraced vs flat): appeal 7 vs 8, Town to City look 6 vs 8, streets to wander 6 vs 4, awe from outside 7.5 vs 5.5, bustle 6.5 vs 4.5.
- **Art polish list for later** (from critics): denser rows of houses with shared walls; lanes and arched gates through the terraces; walls with buttresses, niches and windows; stalls round the plaza; taller blocks stepping up to the tower; more detail on the legs and the hull underside.
- **Screens worth a look:** `docs/screens/2026-10-26_toy_fp_*.jpg` (first person), `..._toy_*.jpg`, `..._city_scale_comparison.jpg`, `..._flat_vs_terraced.jpg`.
- Idea for later: Nano Banana Pro concept art → Claude rebuilds it in code (technique C8).

## Machines

| | Home PC (main) | Work laptop |
|---|---|---|
| Use for | Everything: building, running, screenshots, art | Session 02 happened here. Design, docs, code, tests, playtests. |
| GPU | AMD RX 7900 XTX (24 GB) | Intel Iris Xe, much weaker: the game runs at ~20–28 FPS. **Design for the home PC**, as the user asked. |
| Godot | 4.7.2 via winget: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` | Same version and path (installed) |
| Python | `py -3` (plain `python` hits the Microsoft Store stub) | `py -3`, with Pillow |
| Other | Blender 4.5, Krita 5.2, Node, VS Code | Git and Claude Code |

### Home PC check after session 02 (done 2026-10-26, session 03)

1. ✅ Pulled. ✅ Git now uses the noreply address on the home PC too.
2. ✅ All 5 test groups pass (bot errand done in 42 s of play).
3. ✅ `tools/godot_offscreen.ps1` works on the AMD card: the bot errand with 7 screenshots in 12 s.
   - **Gotcha:** when you call the script from *inside* PowerShell (`& .\tools\godot_offscreen.ps1 ...`), PowerShell eats a bare `--`, so the game never sees `--autoplay` or `--shots` and it just times out. Quote it: `'--'`. With `powershell -File ...` a bare `--` is fine.
   - Claude's auto mode on the home PC refuses `powershell -ExecutionPolicy Bypass -File ...`. Inside the PowerShell tool, the process policy is already Bypass, so call the scripts directly with `&`, or run the Godot commands from `run_tests.ps1` one by one.
4. ✅ **Speed on the home PC (RX 7900 XTX):** the toy runs at **~440 FPS** uncapped (laptop: 25). **The 10x city runs at ~80–95 FPS** (laptop: 6), and building it takes ~25 s at start. So on the home PC, a much bigger city is affordable; the laptop is the limit, and startup time is the main cost.
5. ✅ The user played at home (112 s, errand done, 240 FPS, 72% first person): "runs much better than on the laptop", "the city looks bigger than in screenshots but still feels too small", **"the paths to get around are very narrow."** Measured: 40% of path length under 2 m, 75% under 3 m, ~3,000 m² walkable. Answered: the narrow paths feel cramped and are a bit hard to walk; it doesn't feel like walking a real city (Tokyo). The user floated a real-city size with buses (Claude: Huge; suggested districts joined by a tram). **What part of Tokyo: "crowds and bustle: lots of people, shops, signs and life everywhere."** Claude proposed a **Market Street test** (see the session 03 history / DECISIONS once agreed): one wide, busy shopping street, walkable in first person.
6. **Repo visibility:** session 02's docs say the repo is public, but from the home PC an anonymous visit gets a 404, so it's **private**. Keeping the noreply email and the history scrubbing does no harm. Ask the user whether they made it public for a while.

### Setting up another machine (one time)

1. Install **Git for Windows** (it includes Git Credential Manager), **Claude Code** and **Godot 4.7.2** (`winget install GodotEngine.GodotEngine`).
2. Clone: `git clone https://github.com/teetuuhobby-wq/Game01.git`
3. Set the git name and email as in step 2 above. Older commits keep the old address; rewriting history isn't worth it.
4. The first `git push` opens a browser window to sign in to GitHub. Approve it once, and it's remembered after that.
5. If a push is rejected ("fetch first"), the other computer pushed newer work. Run `git pull`, then push again.

## How to run things

- **Play the game:** double-click `game/run.bat`. Click in the window, then the mouse looks around. WASD or arrows walk, Shift runs, E uses, the mouse wheel or + - zooms (all the way in = first person), Z X turn. F8 = "that felt off", F3 = debug info. Esc frees the mouse; Esc again quits. Tuning numbers: `game/tuning.gd`.
- **All tests (Claude, after every change):** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1`. Headless, about 35 s. It runs the bot errand plus key, stairs, first-person and flower tests (`game/tests/`). Exit code 0 = all passed.
- **Hidden runs with pictures:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot_offscreen.ps1 <project_dir> [godot args] [-- game args]`. Godot runs on a separate, never-shown Windows desktop with sound off; screenshots and FPS match a visible run. Add `--fixed-fps 60` for repeatable screenshots. It stops at once if a script fails to load.
  - Bot errand with screenshots: `... godot_offscreen.ps1 game --fixed-fps 30 -- --autoplay --shots` (into `game/shots/`).
- **Playtests (recorded automatically):** every normal play session writes `game/playtests/<date_time>/`. It's git-ignored, so it stays on the machine it was played on.
  - `events.csv`: start here. The user's **F8 flags** with notes and a screenshot (`flag_NN.png`), plus automatic flags: `stuck`, `camera_jump`, `low_fps`, errand steps.
  - `log.csv`: 10 times a second: position, floor, camera (zoom; negative = first person), FPS, errand step.
  - `inputs.csv`: every frame's keys and mouse, for replay.
  - `session.txt`: machine, tuning values, and the **game version (git commit)**.
- **After a playtest (Claude):** read `events.csv` and `log.csv`, then replay hidden to *see* the flagged moments:
  `... godot_offscreen.ps1 game --fixed-fps 60 -- --replay playtests/<folder> --shots` (shots into `<folder>/replay/`). Replays only match the game version they were recorded on. If the code has changed since, replay from a copy of that commit: `git archive <commit> game`, extract it, copy the playtest folder into its `game/playtests/`, and run from there.
- **Look tests:** `prototypes/*/run.bat` (keys 1–6 camera). Screenshots: `... godot_offscreen.ps1 prototypes/look_test_hd -- --shots`.
- **Screenshot rule:** every `shots/` folder is git-ignored. Save keepers to `docs/screens/` as **JPG**: `<godot_console.exe> --headless --script tools/to_jpg.gd -- <shot.png> docs/screens/YYYY-MM-DD_topic.jpg`.

## Branches

| Branch | What it is | Status |
|---|---|---|
| `main` | The project. Always work here. | Active |
| `experiment/market-street` | **The Market Street test (session 03), waiting for the user to play it.** Bigger outer ring (deck 120 x 88 m), a ~140 m market street with ~35 shops, stalls, lanterns, ~235 people and crowd chatter (see DECISIONS). All 6 test groups pass, including the new `tests/market_test`. ~200–240 FPS uncapped on the home PC; **it will be slow on the laptop.** Critic (first pass): bustle 7/10, big city from street level 5/10, looks 5/10 in first person, 7/10 from above. After that pass: people within 0.9 m of the camera are hidden, signs are bigger and brighter, most shops have tall Tokyo-style banners, shops have 3–4 floors, there are washing lines, ~45% of people wear hats, and the close-camera background blur starts at 40 m. Not re-scored. **Still open from the critic:** glare and bloom from the low sun; people all share one blocky build; you can still see the city's edge from some spots (no bends, arches or landmarks at the ends of views). Screenshots: `game/tests/market_shots.tscn` (hidden run), keepers in `docs/screens/2026-10-26_market_*.jpg`. | If the user likes it: merge into `main`. If not: fix on the branch, or park it. |
| `experiment/city-10x` | **Look only, don't merge.** The terraced city at 10x its area (265 x 177 m, 4 terraces, 736 houses), built because the user asked to *see* the real scale. Code: `prototypes/look_test_10x/`. 6 FPS and a 33 s start on the laptop, 2.7 GB of memory. | Parked. The user later said even 10x may not be big enough, but what they mean is more *places with a purpose* (see TASTE). |

To look at the 10x city: `git fetch`, `git switch experiment/city-10x`, double-click `prototypes/look_test_10x/run.bat`, then `git switch main`. Commit or stash any work first.

## Session ritual

- **Start:** `git pull`, read this file, give the user a 3-line recap, and propose the next step.
- **End:** update this file plus TASTE, IDEAS, GAME and DECISIONS, and save the conversation to `docs/history/` with `tools/transcript_to_md.py --chat-only` (usage at the top of the script). The user wants **only the conversation** saved: their messages and Claude's replies, no commands or output. It's published to GitHub, so read the result for anything private before committing. Then run the tests, commit and `git push`.
