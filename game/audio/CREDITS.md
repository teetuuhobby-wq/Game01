# Sound credits

Recordings used in the game, where they came from, and their licence.
Each sound's folder here (`audio/<sound name>/`) holds the recordings the sound board (F4) can pick from. A subfolder is a **set**: the game plays a random file from it each time.

All of these are **CC0** (public domain: free to use, no credit required). They're credited anyway, with thanks.

| Sound | Files | Source | Author | Licence |
|---|---|---|---|---|
| Your footsteps, set `stone` | `footstep/stone/footstep_concrete_000–004.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney (kenney.nl) | CC0 |
| Your footsteps, set `wood` | `footstep/wood/footstep_wood_000–004.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney (kenney.nl) | CC0 |
| Your footsteps, set `rpg` | `footstep/rpg/footstep00–09.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney (kenney.nl) | CC0 |
| Coins | `coins/handleCoins.ogg`, `handleCoins2.ogg` | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney (kenney.nl) | CC0 |
| Crates set down | `crate/impactWood_medium_000–004.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney (kenney.nl) | CC0 |
| Crowd chatter | `crowd/market_france_SamuelGremaud.mp3` | ["CROWD" (market, south of France)](https://freesound.org/people/SamuelGremaud/sounds/545756/) | SamuelGremaud (Freesound) | CC0 |
| Crowd chatter | `crowd/market_sofia_bruno-auzet.mp3` | ["sophia open air vegetable market"](https://freesound.org/people/bruno.auzet/sounds/782314/) | bruno.auzet (Freesound) | CC0 |
| Crowd chatter | `crowd/market_london_ilmari.mp3` | ["2022-11-12 binaural london market ambience"](https://freesound.org/people/ilmari_freesound/sounds/659634/) | ilmari_freesound (Freesound) | CC0 |
| Desert wind | `wind/825860_vrymaa_dune_loop.wav` | ["Desert sand - Dune atmosphere"](https://freesound.org/people/Vrymaa/sounds/825860/) | Vrymaa (Freesound) | CC0 |
| Town life | `town/818390_sounds_from_palestine_village_loop.wav` | ["Street Village Ambience on a Summer Windy Day"](https://freesound.org/people/sounds_from_palestine/sounds/818390/) | sounds_from_palestine (Freesound) | CC0 |
| Town bell | `bell/378799_kgeshev_bell.wav` | ["BELL.wav"](https://freesound.org/people/kgeshev/sounds/378799/) | kgeshev (Freesound) | CC0 |
| City creaks | `creak/456814_breviceps_creaking_wood.wav` | ["Creaking Wood"](https://freesound.org/people/Breviceps/sounds/456814/) | Breviceps (Freesound) | CC0 |
| City creaks | `creak/113361_shipcreaks1.wav`, `113362_shipcreaks2.wav` | ["shipcreaks1.wav"](https://freesound.org/s/113361/), ["shipcreaks2.wav"](https://freesound.org/s/113362/) | a Freesound user whose account was later deleted | CC0 |
| City creaks | `creak/496836_hinchinbrook_metallic_groan.wav` | ["Metallic Groan"](https://freesound.org/people/hinchinbrook/sounds/496836/) | hinchinbrook (Freesound) | CC0 |

The three crowd files are Freesound's public **preview MP3s** (about 128 kbps), not the full-quality originals, which need a Freesound account to download. Downloaded 2026-10-26.

The wind, town, bell and creak files were downloaded by the user in full quality (2026-10-27), kept in `audio_originals/` (not in git), and turned into the game's copies by `tools/prepare_sounds.py`: the wind and town are the calmest 60 s of each recording, with the end blended into the start so the loop has no seam, at 32 kHz; the one-off sounds have the silence at the start cut. To change how they're cut, edit that script and run it again.
