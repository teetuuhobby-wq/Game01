# STATUS: start here

**New session? Read this first**, then `docs/TASTE.md`, `docs/GAME.md` and the end of `docs/DECISIONS.md` (as `CLAUDE.md` says). For the user's own words and reactions, read `docs/history/`.

_Last updated: 2026-10-26, session 02 (work laptop): code review and fixes, hidden test runs. The open questions below are still unasked._

## Where we are

- ✅ **Phase 1: Discover**: done. Three core desires confirmed (see TASTE.md).
- ✅ **Phase 2: Pick a direction**: done. **"Strider Home"**: you're one ordinary resident of a living walking city crossing a dangerous wasteland, plus the night danger from pitch B. See GAME.md.
- ➡️ **Phase 3: First playable toy**: **built, waiting for the user to play it** (`game/`, double-click `game/run.bat`). Scope is in GAME.md. Next: the user plays it; their complaints are the next to-do list.

## Open questions for the user (ask these first, one or two at a time)

0. **City size (raised last thing in session 01):** the user said the HD city "feels a bit small, needs to be several times the current size." **Answered in session 02: (b) more streets and districts matters most; (a) and (c) are liked too. The user picked the terraced city (`prototypes/look_test_terraced/`). They then asked to see 10x: built on branch `experiment/city-10x`, too heavy as is (see DECISIONS). **Look tests are now frozen. The first toy uses the terraced city; revisit size after the user has walked around in it.** Original question was: (a) the awe of a *huge* walking city seen from outside, (b) more streets and districts to live in and wander, or (c) more people and bustle? Then offer options with sizes:
   - **Bigger deck with chunked rendering:** you see one neighbourhood at a time in diorama view. Medium.
   - **Terraced, multi-level city** (stacked districts climbing a central hill or spire): feels much bigger for less area, and gives great silhouettes. Medium.
   - **The clever fake:** the near districts are detailed, the far ones are lower-detail blocks. Small–Medium.
   *Claude's lean: terraced and bigger, tested as a quick look-test change first.* Bigger also means legs and hull scale up.
1. **Camera for the first toy (and the game):** a close third-person view behind the resident, or a zoomed-out diorama view? Compare `docs/screens/2026-10-26_hd_diorama.png` and `2026-10-26_hd_close.png`. *Claude's default changed after seeing them: **diorama**. It looks far better with today's art and shows the whole living town; close-up exposes the coarse voxels and would need much more art work. Possible middle ground: diorama with a zoom-in.*
2. **Which pitch-B elements?** Claude suggested: the city kneels at night and things climb the legs. Not confirmed yet.
3. **Nano Banana Pro access:** the Gemini app or website (Claude writes prompts, the user pastes images back) or an API key (Claude generates directly, with a cost estimate first)? Only matters once we do concept art.

## Suggested next step

Propose the **first toy** with default answers, get a yes, then build it in a new Godot project at `game/` (leave `prototypes/look_test_hd/` as reference). A likely scope:
- one resident you control, walking around the town deck **while the city walks and sways**
- 3–5 other residents on simple daily loops (the "alive" feeling, done cheaply)
- one tiny thing to do (e.g. fix the rain-catcher) plus some sound
- meet the minimum bar in CLAUDE.md (runs, visible player, controls, one challenge, sound, can be won or progressed)

Technical plan for the toy (Claude's recommendations from the session-02 review):
- **Walking on a swaying deck:** run the player and residents in the city's own coordinates, as if the deck stood still, and add the walk and sway only to what's drawn. This avoids moving-platform physics bugs.
- **Where you can walk:** the look test's `occ` map (which metre cells are built on) is a ready-made walk map for the player and residents. There is no collision yet.
- **Drawing the city:** reuse the look test's visible-faces mesher (`Faces`, `_emit_grid`). It's what lets weaker PCs run it, and a bigger city needs it.

## Important rules learned (don't break these)

- **It has to look good.** That's the user's #1 fear from past projects. Keep art code-built and consistent, and use screenshots plus a **separate critic** pass on visuals.
- **Never show the user story spoilers.** The payoff is gameplay-first, with a short story checked by blind critic agents ("predict the twist" and "find the clues" tests). The user judges it only by playing blind.
- **Living world = the clever fake:** residents with routines and reactions, not deep AI.
- Don't build Huge things. Ask before paid tools.
- **Tests run hidden.** The user doesn't want the game popping up or grabbing their mouse and keyboard while Claude tests. Use `tools/godot_offscreen.ps1` (see "How to run things"). Open a visible window only when the user asks to see it.

## Art status (look test)

**Current best: `prototypes/look_test_hd/`.** The user asked for Town to City-level detail, so this version uses **20 cm blocks (5 per metre)**, and a resident is 9 blocks tall. Houses are built from templates in code: recessed windows with shutters, flower boxes, arched doors, balconies, cornices, hip/gable/flat roofs with tile rows, chimneys, ivy, pergolas, washing lines. The plaza has a fountain, striped parasols and cafe tables, and 18 residents stroll on simple loops. It is drawn as chunked meshes of only the block faces you can see (about 520k faces), so it starts in ~4 s and runs at 25–28 FPS even on the work laptop (11 FPS before that change).
- Critic: **6/10 appeal, 5/10 closeness to Town to City** (up from 4/10 for the coarse version). After that review, the floating smoke cubes were removed and the grade warmed toward Town to City's amber (not re-scored yet).
- Critic's remaining list for a later art pass: more variety between houses (heights, tints, more vines and flowers, stalls round the plaza); more mechanical detail on the legs and underside (the knee joints read as plain domes); the close camera still looks like "Minecraft Steve" at this block size, so lock the **diorama** camera or use finer blocks for characters.
- The coarse version (`prototypes/look_test/`) is kept for comparison.
- **Terraced test (session 02): `prototypes/look_test_terraced/`.** The deck is 1.5x wider and longer (2.25x the area). It has two raised terraces (6 m and 12 m) shaped like rounded rectangles, because straight walls read better in blocks than curves. Each terrace has stone retaining walls with a ledge, balustrades, lamps, hanging vines, and stairs on the four main streets. The plaza and a taller bell tower sit on top. There are 50 residents (18 at the plaza, 32 strolling along the terrace edges); a headless test found no collisions. It runs at ~21 FPS on the laptop and starts in ~5 s. Screens: `docs/screens/2026-10-26_flat_vs_terraced.jpg`, `..._terraced_diorama.jpg`, `..._terraced_outside.jpg`, `..._terraced_plaza.jpg`.
  - Critic (terraced vs flat): appeal 7 vs 8, Town to City look 6 vs 8, streets to wander 6 vs 4, awe from outside 7.5 vs 5.5, bustle 6.5 vs 4.5. This was a different critic from the 6/10 one, so compare within this pair only.
  - Critic's fix list, if the user keeps it: denser rows of houses with shared walls and smaller gaps (the biggest loss vs flat); 2–3 lanes cutting up through the terraces with arch gates in the walls; walls with buttresses, niches and windows; small buildings or stalls lining the plaza edge; taller 4–5 storey blocks on the lower terrace stepping up toward the tower; a less bare tower; something on the plain hull underside.
- Idea for later: Nano Banana Pro concept art → Claude rebuilds it in code (technique C8).

## Machines

| | Home PC (main) | Work laptop |
|---|---|---|
| Use for | Everything: building, running, screenshots, art | Design, docs, code. Running the game may be slow. |
| GPU | AMD RX 7900 XTX (24 GB) | Intel Iris Xe, much weaker (HD look test: 25–28 FPS). **Design for the home PC**, as the user asked. |
| Godot | 4.7.2 via winget: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` | Same version and path (installed) |
| Python | `py -3` (plain `python` hits the Microsoft Store stub) | `py -3`, with Pillow |
| Other | Blender 4.5, Krita 5.2, Node, VS Code | Git and Claude Code |

### Setting up the work laptop (one time)

1. Install **Git for Windows** (it includes Git Credential Manager), **Claude Code** and **Godot 4.7.2**.
2. Clone: `git clone https://github.com/teetuuhobby-wq/Game01.git`
3. Inside the repo folder, tell git who you are. The repo is public, so use GitHub's private "noreply" address instead of your personal email:
   `git config user.name "teetu"` and `git config user.email "338372523+teetuuhobby-wq@users.noreply.github.com"`
   Done on the work laptop in session 02. **Home PC: run the same two commands there too.** Older commits keep the old address; rewriting history isn't worth it.
4. The first `git push` opens a browser window to sign in to GitHub. Approve it once, and it's remembered after that.
5. If a push is rejected ("fetch first"), the other computer pushed newer work. Run `git pull`, then push again.

**On the laptop:** `--rendering-method mobile` doesn't help (measured: same FPS). Turning off shadows does, but it changes the look. Don't redesign for the laptop. Final visual checks happen on the home PC.

## How to run things

- **The game (first toy):** double-click `game/run.bat`. Keys: WASD or arrows walk, Shift runs, E uses, mouse wheel or + - zooms, right-drag or Z X turns the camera, Esc quits. Tuning: `game/tuning.gd`.
- **Game tests (Claude):**
  - Logic, headless (seconds): `<godot_console.exe> --headless --fixed-fps 30 --path game -- --autoplay`. A bot plays the whole errand along the shortest route; exit code 0 = done (2 stuck, 3 no route, 4 too slow). Last result: done in 43 s of play.
  - With pictures, hidden: `... tools/godot_offscreen.ps1 game --fixed-fps 30 -- --autoplay --shots` saves the in-game camera's views at the start and at each step to `game/shots/`.
  - Performance on the laptop: ~20 FPS.

- **Look test:** double-click `prototypes/look_test_hd/run.bat` (keys 1–6 camera, Space pause, Esc quit). The old coarse version is `prototypes/look_test/run.bat`.
- **Testing (Claude): never pop the game up on the user's screen.** Run it hidden:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot_offscreen.ps1 <project_dir> [godot args] [-- game args]`
  Godot then runs on a separate, never-shown Windows desktop. It can't cover the screen, take keyboard focus or catch the mouse, and sound is off. Screenshots and FPS match a visible run (checked pixel by pixel in session 02). Add `--fixed-fps 60` to make screenshots repeatable, so before/after images can be compared exactly. For logic-only tests, `--headless` is faster.
- **Screenshots for review:** `... tools/godot_offscreen.ps1 prototypes/look_test_hd -- --shots` saves 6 PNGs to `prototypes/look_test_hd/shots/` and quits.
- **Screenshot rule:** every `shots/` folder is git-ignored, because they're re-rendered often and would bloat the repo. Save the ones worth keeping to `docs/screens/` as **JPG** (about 4× smaller), named `YYYY-MM-DD_topic.jpg`:
  `<godot_console.exe> --headless --script tools/to_jpg.gd -- <shot.png> docs/screens/YYYY-MM-DD_topic.jpg`
  The older keepers are PNG; leave them.

## Branches

| Branch | What it is | Status |
|---|---|---|
| `main` | The project. Always work here. | Active |
| `experiment/city-10x` | **Look only, don't merge.** The terraced city at 10x its area (265 x 177 m, 4 terraces, 736 houses), built in session 02 because the user asked to *see* the real scale. Code: `prototypes/look_test_10x/`. Too heavy as is: 6 FPS and a 33 s start on the laptop, 2.7 GB of memory. Result and screenshots are already on main (DECISIONS, `docs/screens/2026-10-26_city_scale_comparison.jpg`). | Parked. Keep it as a reference for a later city-size decision; a playable big city needs chunk streaming and distinct districts (Large). |

To look at the 10x city on either computer: `git fetch`, then `git switch experiment/city-10x`, double-click `prototypes/look_test_10x/run.bat`, and `git switch main` when done. Commit or stash any work first, because switching branches changes the files in the folder.

## Session ritual

- **Start:** `git pull`, read this file, give the user a 3-line recap, and propose the next step.
- **End:** update this file plus TASTE, IDEAS, GAME and DECISIONS, and save the conversation to `docs/history/` with `tools/transcript_to_md.py --chat-only` (usage at the top of the script). The user wants **only the conversation** saved: their messages and Claude's replies, no commands or output. That's what a later session needs to read between the lines. It's published to GitHub, so read the result for anything private before committing. Then commit and `git push`.
