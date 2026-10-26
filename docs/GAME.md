# GAME — the current game in one page

**Working title:** Strider Home *(placeholder)*
**Status:** Phase 3. The **first playable toy** is built (`game/`) and waiting for the user to play it.

## Pitch (one sentence)

You're one ordinary resident of a small walking city crossing a dangerous wasteland: live your life on its swaying deck, help keep it going, and be there when the big threat finally comes.

## Core loop

1. **Day on the deck:** wander a living town full of residents with their own routines; fix, build, help, chat.
2. **The city stops:** go down to the wasteland for parts and secrets, then get back before dark.
3. **Night (from pitch B):** the city kneels to rest, and things come out of the dark and climb the legs. Hold out until dawn.
4. **Dawn:** the city walks on, a little better than yesterday.

**Long-term payoff:** told mostly through gameplay, carried by a short story checked blind. The "backwater" city and everything you built face the great threat together.

## Look and feel

- A cozy voxel diorama in the spirit of Town to City: white walls, terracotta roofs, warm golden-hour light, a tilt-shift miniature feel.
- The wasteland outside is dusty, wide and quietly threatening (bones, wrecks, haze).
- **The world feels alive:** residents go about their day whether or not you're watching. You're one of them, not the centre of the universe.
- Art is built from code (voxels), so it stays consistent. Reference: `prototypes/look_test_hd/`.

## Engine

**Godot 4.7** (already installed). It's strong at 3D voxel looks, runs great on your PC, and I can launch it and take screenshots myself. Friends get a zipped Windows build. A web build is possible later but limited.

## Current milestone: Phase 3, first toy: "Walk your town while it walks" (scope locked 2026-10-26)

- **In:**
  - You, walking the terraced city's streets and stairs (WASD, Shift to run). You can't pass through houses or walls, or off the edge.
  - The city walks and sways under you, forever: the desert repeats seamlessly.
  - 50 neighbours on their routes, who stop and look at you as you pass.
  - One errand: Mira asks you to fetch a spare valve from Bram's workshop and fit it on the rain-catcher. A gold marker, an edge arrow and a goal line show the way.
  - A follow camera: the mouse wheel zooms from close behind you out to the diorama; right-drag or Z/X turns it.
  - Sounds made from code: footsteps, giant stomps, wind, chime, clunk, bell.
  - `game/tuning.gd` for speeds, sway, camera and volumes.
- **Out (until the toy feels good):** night and the climbing creatures, trips down to the desert, building, inventory, real dialogue, saving, a bigger city, and the art polish list.
