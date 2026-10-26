# GAME — the current game in one page

**Working title:** Strider Home *(placeholder)*
**Status:** Phase 3 done: the first playable toy (`game/`) has been playtested 3 times. The loop below was reshaped by the user in session 02. **Next milestone not locked yet:** it waits on the combat-style decision (see STATUS).

## Pitch (one sentence)

You're one ordinary resident of a small walking city crossing a dangerous wasteland: live your life on its swaying deck, help keep it going, and be there when the big threat finally comes.

## Core loop (the user's version, session 02)

1. **Day in town:** wander the city, gear and supply up in the shops, take requests (the guild), and spend time with people.
2. **The city stops (night):** go down to the desert, solo or with a party of **AI companions** (neighbours, guild members), for resources and to complete requests. **Expeditions are dangerous, and combat is almost always part of them.** Night attacks on the city itself are rare, and become well-paid emergency quests.
3. **Dawn:** get back before the city starts walking again, or be stranded and lost. Then you must catch up with it (on a vehicle), or it's game over. *(Claude suggested a softer fail for a cozy friends game: rescued by a caravan, lose your haul. Not decided.)*

**The city:** full of **places with a purpose**: shops, a guild, workshops, a tavern and so on, enough for a whole daily life. That's what "bigger" means to the user, more than area. Grow it district by district.

**Long-term payoff:** the underdog rising. Guild ranks are a natural home for it. Told mostly through gameplay, with a short story checked blind. The "backwater" city and everything you built face the great threat together.

**Open, decide later:** the kind of combat (action, turn-based like Chrono Ark, or real time with pause; Claude suggested two tiny toys to try); how companions work (Claude suggests solo first, then one simple companion who follows and talks, and fighting companions later); vehicles; the fail state.

## Look and feel

- A cozy voxel diorama in the spirit of Town to City: white walls, terracotta roofs, warm golden-hour light, a tilt-shift miniature feel.
- The wasteland outside is dusty, wide and quietly threatening (bones, wrecks, haze).
- **The world feels alive:** residents go about their day whether or not you're watching. You're one of them, not the centre of the universe.
- Art is built from code (voxels), so it stays consistent. Reference: `prototypes/look_test_hd/`.

## Engine

**Godot 4.7** (already installed). It's strong at 3D voxel looks, runs great on your PC, and I can launch it and take screenshots myself. Friends get a zipped Windows build. A web build is possible later but limited.

## Last milestone: Phase 3, first toy: "Walk your town while it walks" (done, playtested 3 times)

- **In:**
  - You, walking the terraced city's streets and stairs (WASD, Shift to run). You can't pass through houses or walls, or off the edge.
  - The city walks and sways under you, forever: the desert repeats seamlessly.
  - 50 neighbours on their routes, who stop and look at you as you pass.
  - One errand: Mira asks you to fetch a spare valve from Bram's workshop and fit it on the rain-catcher. A gold marker, an edge arrow and a goal line show the way.
  - Camera with mouse look: scroll all the way in for **first person** (through your eyes), out for over the shoulder, then the diorama. Behind you, it looks over or under things in the way instead of jumping in.
  - Playtest tools: recorder, F8 flags, exact replay, F3 debug info.
  - Sounds made from code: footsteps, giant stomps, wind, chime, clunk, bell.
  - `game/tuning.gd` for speeds, sway, camera and volumes.
- **Out (still to come):** night and expeditions, combat, companions, shops and the guild, building, inventory, real dialogue, saving, a bigger city, and the art polish list.
