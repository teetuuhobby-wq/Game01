# CHARACTERS: the town's named residents

*Everyday people only: jobs, habits, opinions about the town. No secrets, backstories or story hooks (a blind "spoiler guard" critic checked every line). They're residents, not companions: who joins your party is still your call.*

**Where they live in the code:** looks and lines in `game/town_data.gd` (edit freely), where they stand in `game/world/facilities.gd` and `outer_places.gd`, their props and habits in `game/world/cast.gd`, their walks through the day in `game/world/town_life.gd` (all on `main` since 2026-10-28).

**How talking works:** press **E** near someone. Each press gives the next line; after their last one the hint says "E: goodbye", the next E ends the conversation, and talking again starts from the top. Some have lines only *before* Mira's errand is done; once it's done, everyone first says their "after" line (news travels), then their usual ones.

| | Who | Where | Look (you can spot them by) | Personality | Habit |
|---|---|---|---|---|---|
| 1 | **Sabeth**, guild clerk | Behind the counter, Adventurers' Guild | Tall, navy dress, gold sash, grey bun, gold-rimmed glasses, a fat ledger | Precise, dry, secretly delighted by anyone who fills in a form properly | Writes in her ledger |
| 2 | **Dorran**, barkeep | Behind the bar, the Kneeling Strider | Big belly, bald, beard, wine-red shirt, white apron, a frothy mug | Big, warm, never forgets an order, always has a story about somebody's cousin | Polishes and glances round |
| 3 | **Bram**, mechanic | Outside his workshop, middle terrace east | Blue-grey overalls, grey beard, brass goggles on his forehead | Gruff, kind underneath, gentler with machines than people | Hammers |
| 4 | **Pell**, shopkeeper | Behind the counter, Pell's Provisions | Green shirt, apron, a wide straw hat with a red feather | Quick-talking, cheerful, thinks there's a right tool for every problem (and she sells it) | Paces behind the counter |
| 5 | **Tamsin**, bath attendant | By the towel shelves, the Bathhouse | Aqua dress, white sash, long hair, a towel wrapped on her head, a stack of towels | Calm, unhurried, speaks softly so everyone else does too | Strolls along the shelves |
| 6 | **Mira**, your neighbour | The plaza (gives you the errand) | Rose shirt, green headscarf, a bright green watering can | Practical, upbeat, keeps half the neighbourhood's plants alive | — |
| 7 | **Old Wendel**, lookout | On a timber lookout by the outer wall, past the bathhouse | Short, long brown coat, wide hat, white beard, brass spyglass at his eye | Weathered, few words, notices everything, likes the desert more than people (mostly) | Scans the horizon |
| 8 | **Pip**, errand runner (a kid) | Running between the guild and the tavern | Lime shirt, red cap, ginger hair, an orange satchel | Fast, curious, knows every shortcut and every rumour (most of them wrong) | Runs errands, stops when you're near |

## Their day (since 2026-10-28, "A day in town")

The day runs 7:00 to 19:00. Times are when they set off; they leave a little early so they arrive on time, then wait at their place. Change any of it in `ROUTINES` in `game/town_data.gd`.

| Who | Their day |
|---|---|
| Sabeth | Home → the guild at 7:30 (opens 8:00) → home at 17:00 |
| Pell | Home → her store at 7:24 (opens 8:00) → **the tavern at 17:00**, for a drink after work |
| Dorran | Home → the tavern at 10:24 (opens 11:00), until the day ends |
| Tamsin | Home → the bathhouse at 8:18 (opens 9:00) |
| Pip | Home → running the south street from 7:36 → home at 18:00 |
| Bram, Old Wendel, Mira | At their spot all day (Mira's errand needs her in the plaza). After 18:00 Bram says the shop's shut. |

At a closed place, the people who work there tell you when it opens ("The guild opens at 8:00…"). You can't talk to anyone who's at home.

**The morning round:** at their stop in the round (`ROUND` in `game/town_data.gd`), Pip, Sabeth, Pell, Dorran, Tamsin, Old Wendel and Bram each say one line of their own instead of their usual ones.

## Sample lines (one each)

- **Sabeth:** "New members start at the bottom of the ledger. Everyone starts at the bottom of the ledger."
- **Dorran:** "My cousin swears he out-drank a sand-crawler. My cousin has never seen a sand-crawler."
- **Bram:** "Hear that groan when the city takes a step? That's the old girl telling us she's fine."
- **Pell:** "Going down to the sand tonight? Take a lantern. Then take a spare lantern."
- **Tamsin:** "Breathe slower. The water will wait for you."
- **Mira:** "These pots won't water themselves. Believe me, I've asked."
- **Old Wendel:** "Forty years on this wall. Seen a dust devil taller than the tavern. Pretty, that."
- **Pip:** "Race you to the stairs! ...Okay, you win, I wasn't ready."

All lines are in `game/town_data.gd`; change any of them freely.

## Critic scores (first draft → after fixes)

- **Recognisable at a glance (character designer):** Sabeth 4→5, Dorran 5→7, Bram 6→8, Pell 8→8, Tamsin 6→6 (then given a brighter dress and a head towel, not re-scored), Mira 3→8, Wendel 4→7, Pip 4→7.
- **Distinct voices (dialogue editor):** Sabeth 8, Dorran 8, Bram 7, Pell 7, Tamsin 7, Mira 6, Wendel 8, Pip 8.
- **Spoiler guard:** clean.

## Things that are flavour only (your decisions, not promises)

The boards and lines mention guild requests, night trips down to the sand, sand-crawlers in the lower hull, and "the bottom of the ledger". None of these are systems yet; they're there to make the town feel lived-in. Keep, change or cut them as you decide the real game.
