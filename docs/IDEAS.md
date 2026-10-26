# IDEAS — the parking lot

Every idea goes here, used or not. Nothing gets lost.

**Fit tags:** 🟢 fits the core desires · 🟡 maybe / unclear · 🔴 fights the core desires · ⚪ not judged yet

| Date | Idea | Fit | Notes |
|---|---|---|---|
| 2026-10-25 | **Setting like Chrome Shelled Regios:** you live in a city that is a safe island in a monster-filled wasteland | 🟢 | Hits "safe home in a dangerous world" strongly. Regios is someone else's world, so we'd make an *original* setting with the same feeling. |
| 2026-10-25 | **Play as a combatant living daily life in one of those cities** | 🟢/🟡 | The combatant part fits the hidden-power and spectacle desires. The "living a life" part isn't clear yet (daily-life scenes? relationships? just flavour?). |
| 2026-10-25 | **Town to City art style + world sculpting** | 🟢 | We can recreate a cozy voxel/diorama look in our own game. Sculpting the city fits "shaping your safe home." |
| 2026-10-25 | **Make it as a mod of an existing game (e.g. Town to City), using REA** | 🟡 | Claude pushed back (see DECISIONS). Turning a calm city-builder into a combat game is a Huge total conversion: no source code, unknown engine and mod support, updates could break it, and every friend must own the game. Round 3 showed the real goal: **good-looking content**, not reverse engineering for its own sake. Better answer: pick an art style AI does reliably well (e.g. code-built voxels). |
| 2026-10-25 | **The city itself walks** (from Regios): the home is a giant walking city crossing a wasteland | 🟢 | Strongest signal so far (core desire #1). |
| 2026-10-25 | **Everyday life in the city between dangers** (from Regios) | 🟢 | Core desire #2. |
| 2026-10-26 | **Pitch A, Strider Home: live on the walking city as a resident** | 🟢 | ✅ Chosen direction. |
| 2026-10-26 | **Pitch B, Strider Nights: city kneels at night, things climb the legs** | 🟢 | Partly chosen. Some elements go into A. |
| 2026-10-26 | **Pitch C, Heartwalker: you ARE the city** | 🟡 | Parked. Could return as a mini-game (e.g. steering the city during a crisis). |
| 2026-10-26 | **The city should be several times bigger** (said after seeing the HD look test) | 🟢/🟡 | Session 02: **more streets and districts to wander** matters most; the awe of a huge walking city and more bustle are liked too. Size not decided yet. Cost: 3× wider is about 9× the area and blocks, which needs chunking/LOD. That's **Medium** at diorama distance. Cheaper fakes: terraced multi-level districts, or far districts at lower detail. |
| 2026-10-26 | **The world feels alive; you're merely one resident** | 🟢 | Pushback: a truly "alive" town with deep NPCs is **Large**. The clever fake is residents with daily schedules, little loops and reactions to the city's steps, which is **Medium** and grows over time. |
| 2026-10-26 | **Make the city ~10 times bigger** (said after seeing the terraced test, which is already 2.25x the flat one) | 🟢/🟡 | Same feeling as before: a real city you can get lost in, where you're merely one resident. Real 10x area is **Large** (weeks). It needs streaming chunks and low-detail far districts, about 10M faces (2–3 FPS on the laptop), ~400 MB of block data, a slow build, and hundreds of houses that would all look alike without distinct districts. Cheaper ways to get the feeling: grow by distinct districts, and fake the far ones. **Tried as a time-boxed experiment (branch `experiment/city-10x`, see DECISIONS): looks like a real city, but too heavy as is. Parked: the first toy uses the terraced city, and size is revisited after walking around in it.** |
| 2026-10-26 | **First-person camera** (raised in playtest 2, after the third-person camera clipped through buildings in tight streets) | 🟢 | Fits being "one resident" at street level (they played 92% zoomed in). Never clips. **Chosen: both** (scroll all the way in for first person). See DECISIONS. |
| 2026-10-26 | **Many facilities in the city: shops, a guild, etc.** (said after playtest 3, with "even the 10x city may not be big enough") | 🟢 | Fits everyday life (#2) strongly. A guild with jobs and ranks could carry the underdog payoff (#3), and shops give a reason to bring things back from the desert. Each facility needs its own things to do, so this is content-heavy (Large overall). Grow district by district. Not decided yet. |
