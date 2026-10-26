# STATUS: start here

**New session? Read this first**, then `docs/TASTE.md`, `docs/GAME.md` and the end of `docs/DECISIONS.md` (as `CLAUDE.md` says). For the user's own words and reactions, read `docs/history/`.

_Last updated: 2026-10-26, end of session 01 (home PC)_

## Where we are

- ✅ **Phase 1: Discover**: done. Three core desires confirmed (see TASTE.md).
- ✅ **Phase 2: Pick a direction**: done. **"Strider Home"**: you're one ordinary resident of a living walking city crossing a dangerous wasteland, plus the night danger from pitch B. See GAME.md.
- ➡️ **Phase 3: First playable toy**: **next.** Nothing built yet except a throwaway art test.

## Open questions for the user (ask these first, one or two at a time)

1. **Camera for the first toy:** a close third-person view behind the resident (feel the deck sway) or a zoomed-out diorama view (see the whole town)? *Claude's default: close third-person, because it sells "I'm one of the residents" and the swaying deck.*
2. **Which pitch-B elements?** Claude suggested: the city kneels at night and things climb the legs. Not confirmed yet.
3. **Nano Banana Pro access:** the Gemini app or website (Claude writes prompts, the user pastes images back) or an API key (Claude generates directly, with a cost estimate first)? Only matters once we do concept art.

## Suggested next step

Propose the **first toy** with default answers, get a yes, then build it in a new Godot project at `game/` (leave `prototypes/look_test/` as reference). A likely scope:
- one resident you control, walking around the town deck **while the city walks and sways**
- 3–5 other residents on simple daily loops (the "alive" feeling, done cheaply)
- one tiny thing to do (e.g. fix the rain-catcher) plus some sound
- meet the minimum bar in CLAUDE.md (runs, visible player, controls, one challenge, sound, can be won or progressed)

## Important rules learned (don't break these)

- **It has to look good.** That's the user's #1 fear from past projects. Keep art code-built and consistent, and use screenshots plus a **separate critic** pass on visuals.
- **Never show the user story spoilers.** The payoff is gameplay-first, with a short story checked by blind critic agents ("predict the twist" and "find the clues" tests). The user judges it only by playing blind.
- **Living world = the clever fake:** residents with routines and reactions, not deep AI.
- Don't build Huge things. Ask before paid tools.

## Art status (look test)

`prototypes/look_test/` is a code-built voxel walking city (Godot 4.7). A critic scored the first pass 4/10 appeal. After one fix pass it's promising, but not at the Town to City bar yet. Known gaps for a later art pass:
- buildings are plain boxes: use finer voxels and hand-designed building templates (doors, balconies, arches, stairs, washing lines)
- the wasteland scrub cubes are too big and too many
- the wide-shot sky is still a flat warm band
- idea: Nano Banana Pro concept art → Claude rebuilds it in code (technique C8)

## Machines

| | Home PC (main) | Work laptop |
|---|---|---|
| Use for | Everything: building, running, screenshots, art | Design, docs, code. Running the game may be slow. |
| GPU | AMD RX 7900 XTX (24 GB) | Much weaker. **Design for the home PC**, as the user asked. |
| Godot | 4.7.2 via winget: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` | Install the same version: `winget install GodotEngine.GodotEngine`, then check it's 4.7.2 |
| Python | `py -3` (plain `python` hits the Microsoft Store stub) | check |
| Other | Blender 4.5, Krita 5.2, Node, VS Code | Git and Claude Code at minimum |

### Setting up the work laptop (one time)

1. Install **Git for Windows** (it includes Git Credential Manager), **Claude Code** and **Godot 4.7.2**.
2. Clone: `git clone https://github.com/teetuuhobby-wq/Game01.git`
3. Inside the repo folder, tell git who you are. Use the **same name and email as the home PC**, so commits match:
   `git config user.name "<your name>"` and `git config user.email "<your email>"`
   (On the home PC, `git config user.name` and `git config user.email` show the current values.)
4. The first `git push` opens a browser window to sign in to GitHub. Approve it once, and it's remembered after that.
5. If a push is rejected ("fetch first"), the other computer pushed newer work. Run `git pull`, then push again.

**On the laptop:** if the game is too slow, run Godot with `--rendering-method mobile` for a rough look. Don't redesign for the laptop. Final visual checks happen on the home PC.

## How to run things

- **Look test:** double-click `prototypes/look_test/run.bat` (keys 1–6 camera, Space pause, Esc quit).
- **Screenshots for review:** `<godot_console.exe> --path prototypes/look_test -- --shots` saves 4 PNGs to `prototypes/look_test/shots/` and quits.
- **Screenshot rule:** every `shots/` folder is git-ignored, because they're re-rendered often and would bloat the repo. Copy the ones worth keeping to `docs/screens/`, named `YYYY-MM-DD_topic.png`.

## Session ritual

- **Start:** `git pull`, read this file, give the user a 3-line recap, and propose the next step.
- **End:** update this file plus TASTE, IDEAS, GAME and DECISIONS, and save the conversation to `docs/history/`: export the session from the app, then run `tools/transcript_to_md.py` (usage at the top of the script) and read the result before committing. Then commit and `git push`.
