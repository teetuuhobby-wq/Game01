# AI_USAGE — which content is AI-generated

Not required for a friends-only game, but cheap to keep (and essential if we ever release publicly).

| Asset / content | Tool | Date | Notes (prompt file, license) |
|---|---|---|---|
| All code and docs | Claude Code (Claude Opus 5.5) | 2026-10-25 → | Ongoing |
| Look-test voxel art (city, legs, wasteland) | Claude Code, generated from code (technique C9), no image AI | 2026-10-26 | `prototypes/look_test/main.gd` |
| HD look-test art (20 cm blocks: houses, plaza, residents, legs) | Claude Code, generated from code (technique C9), no image AI | 2026-10-26 | `prototypes/look_test_hd/main.gd`. Town to City Steam screenshots were viewed as a style reference only; nothing was copied. |

## Toolkit we have (checked 2026-10-25)

| Tool | What it's for | Notes |
|---|---|---|
| **Godot 4.7.2** | Game engine | Installed via winget, not on PATH yet |
| **Blender 4.5 LTS** | 3D modelling and rendering, scriptable by Claude (technique C8) | `C:\Program Files\Blender Foundation\Blender 4.5\` |
| **Krita 5.2.9** | 2D painting and touch-ups | Can add the Krita AI Diffusion plugin later if needed |
| **Nano Banana Pro** | Image generation (concept art, references, textures, UI) | Access method TBD: Gemini app or API key? No API key in env vars yet. |
| **AMD RX 7900 XTX (24 GB)** | Local GPU | Plenty for Godot/Blender. Local image AI (ComfyUI) is possible on AMD + Windows, but setup is fiddlier than on NVIDIA. Only try it if we need it. |
| **Python 3.14, Node.js, Git, VS Code** | Scripts, pipelines, web builds | |
| **REA** | Reverse engineering | Not needed for the main game; available for side experiments |
| *Audio* | `game/sfx.gd` | All sounds are made from code (footsteps, stomps, wind, chime, clunk, bell); no sound files. Ask before any paid audio tool. |

## Not AI-made

- **Recorded sounds** in `game/audio/` are real recordings from Kenney and Freesound (CC0). See `game/audio/CREDITS.md`.
