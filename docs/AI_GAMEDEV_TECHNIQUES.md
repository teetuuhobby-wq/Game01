# AI Game Development Techniques — Reference for AI Agents

## How to use this document (read first)

You are an AI agent helping a human build a video game with heavy use of AI-generated assets. This file is a **menu of techniques** collected from community posts, tool docs and research papers (as of October 2026). Use it to:

1. **Suggest** techniques that fit the game the human is making. Do not apply everything; most games need a handful.
2. **Implement** a chosen technique by following its steps, adapting them to the project's engine and tools.
3. **Explain** trade-offs to the human using the "Use when / Avoid when" and "Pitfalls" fields.

### Ground rules
- **Ask before choosing.** Confirm the engine (Godot, Unity, Unreal, three.js/web, etc.), camera style (fixed, top-down, isometric, side-scrolling, free 3D), art style (pixel art, painted, cel-shaded, low-poly) and target platform. Then recommend techniques from the decision guide below.
- **Check what you can actually run.** You may not have image, video, 3D or audio generation available. Many steps need either:
  - an external service (an API key the human must provide), or
  - a local GPU (ComfyUI, Stable Diffusion, Blender).

  Ask the human what they have access to. Never invent API keys or assume a tool is installed.
- **Information may be stale.** Tool names, versions, prices, licenses and API details change quickly. Before relying on a specific tool, check its current docs or repo. Treat any numbers here (settings, step counts) as starting points.
- **Vendor bias.** Several sources are company blogs. Prototype on one asset and show the human the result before building a pipeline around a technique.
- **Prefer reproducible pipelines.** Script steps (Python, shell, Blender scripts, engine tools) and save prompts, seeds, settings and reference images in the repo (e.g. `art/pipeline/` and `art/prompts/`). Consistency comes from fixed references and fixed post-processing, not from luck.
- **Keep generated and source assets separate.** Store raw AI output, cleaned output and final engine-ready assets in different folders so steps can be re-run.
- **Track AI usage for store disclosure.** Keep a simple log (`docs/ai-usage.md`) of which shipped assets/content are AI-generated. Steam requires disclosure (see Appendix Z3).
- **Markers.**
  - **[documented]**: someone has published this exact technique.
  - **[combination]**: joins documented pieces in a way nobody has published; treat it as an experiment and tell the human.
  - **[r/aigamedev]**, or another subreddit name in brackets: from a community post on that subreddit, with its score and date.
    - Posts from other subreddits (r/ClaudeAI, r/LocalLLaMA, r/StableDiffusion, r/comfyui, r/threejs, r/vibecoding, r/ClaudeCode) were found through the [Arctic Shift](https://arctic-shift.photon-reddit.com) Reddit archive in October 2026. That was a keyword search ("game", "sprite", "AI", …) over the past year, so coverage is partial. The same rule applied: only posts that explain a reusable method were kept.
    - Sourced from the [aigamedev-gems](https://github.com/hoveychen/aigamedev-gems) archive (a GitHub scrape of the subreddit with comment threads, snapshot of 25 Oct 2026). About 70 of the highest-scoring and most method-heavy posts from Oct 2025–Oct 2026 were read, including their comment threads, and only posts that explain a reusable method were kept.
    - Many posters promote a tool they built themselves. Those are flagged. Open-source alternatives are often in the comments.

### Decision guide (quick picks by game type)
| Game type | Strong candidates |
|---|---|
| Fixed-camera / isometric 3D-looking world with painted art | O1, A1, A2, A3, A4, A12, B5, E1, E2, F2 |
| 2D game with painted or generated backgrounds | A12, A13, A14, A5, B3 |
| Big tiled worlds or maps (isometric, top-down) | A17, E5, A12 |
| Top-down or side-scrolling pixel art | Z1, B1, C1, C3, C6, C7, C10, D6, D7, D9, E5, E6, E9, B4 |
| 2D with dynamic lighting | B1, B2, B3, B4, B5 |
| Free-camera 3D | A2, A3, A15, B6, B7, C1 (rigging part), C8, C9, D1, D2, E3, A10, F9 |
| Browser game / no external art at all | C9, F10, Z4 (procedural audio), Z8 |
| Character customization (outfits, hair, colors) | D8, D3 |
| Story/dialogue heavy (visual novel, RPG) | D3, D4, D5, D10, F3 |
| AI as part of the gameplay itself (talking NPCs, infinite crafting, music-driven levels) | F3, F13 |
| Procedural/roguelike levels | F1, E5, E6, A10 |
| Trailers, menus, story intros | A11, D11 |
| Any project | F2, F4, F5, F6, F7, F8, F10, F11, F12, E2, E7, E8, Z2, Z3, Z4, Z6, Z7, Z8 |

---

## Origin techniques (the two community posts that inspired this list)

### O1. Blockout → AI paint-over → camera projection  [documented]
- **What:** Build the scene from plain 3D shapes, screenshot it from the game camera, have an image model repaint the screenshot in the target art style, then project the painting back onto the shapes with a shader from that same camera.
- **Why it works:** The AI only has to produce one good 2D image. The hidden 3D geometry still provides depth sorting, collisions, physics and walkable space.
- **Use when:** The camera is fixed or moves only slightly (top-down RPG, fixed isometric, room-by-room interiors).
- **Avoid when:** The camera rotates freely. Surfaces the camera never saw have no paint, and surfaces seen at sharp angles stretch.
- **Steps (as in the original post):**
  1. Generate concept art in the target style.
  2. Build the layout from boxes, cylinders and simple roofs, one flat color each, matching the concept (the original used three.js).
  3. Render or screenshot from the final game camera.
  4. Send the screenshot plus the concept art to an image-edit model. Prompt: "repaint this in the style of image 2, keep everything exactly where it is." (The original used GPT Image 2 via Codex.)
  5. Write a projection shader: for each fragment, project its world position through the capture camera's view-projection matrix to get UVs into the painting, then sample the painting. The capture camera must exactly match the screenshot camera: same position, rotation, FOV and aspect.
  6. Put characters, pickups and physics objects on their own layers on top. The original drew characters with an image model and animated them with the video model MiniMax H3.
  7. Repeat per area (the original did the village exterior, then each interior).
- **Pitfalls:**
  - The paint-over may shift objects slightly. Compare edges against the blockout, regenerate, or use A1 for tighter control.
  - Moving characters are not in the painting, so they need their own lighting and shadows (see B4, B1).
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1x6xh4v/finally_found_a_way_to_get_my_dream_art_style/)

### O2. Sprite Normals — normal maps for pixel art  [documented]
- **What:** An open-source tool (Rust, MIT license) that generates normal maps from sprites so 2D sprites react to dynamic lights.
- **Use when:** 2D or 2.5D game with point lights, torches, day/night or muzzle flashes.
- **Install:** Rust 1.85+, then `cargo install --path . --locked` from the cloned repo. Builds to WebAssembly for browser use.
- **Usage:**
  - Single sprite: `spritefusion-sprite-normals sprite.png -o sprite_n.png`
  - Batch: `spritefusion-sprite-normals sprites/*.png --output-dir normals`
  - Sprite sheet: `spritefusion-sprite-normals sheet.png --frame-size 32x32 -o sheet_n.png`
  - Animation: `spritefusion-sprite-normals walk.gif -o walk_n.png`
    - Outputs a normal atlas, a color atlas (`.color.png`) and a `.frames.json` with layout and timing.
  - Tuning: shape strength (default 1.15), detail strength (6), detail scale (0.6 px), `--normal-strength` (1.5).
  - Unreal/DirectX: add `--normal-format directx` (the default is OpenGL, which Godot and Unity use).
- **Pitfalls:**
  - Import normal maps as non-color data (disable sRGB).
  - Use sprites at native pixel resolution, not upscaled.
  - Painted highlights can become false bumps; lower detail strength if so.
- **Pipeline tips from the thread (856 points, the top tool post of the year):**
  - Let the coding agent call the CLI as part of the asset pipeline.
  - Record the engine's default normal format and strength in CLAUDE.md or agents.md.
  - Works best on small sprites. Very flat color areas give weak results.
  - Sprite DLight is an older alternative.
- **Sources:** [GitHub repo](https://github.com/Hugo-Dz/spritefusion-sprite-normals), [Reddit post](https://www.reddit.com/r/aigamedev/comments/1x9xg1c/made_an_opensource_pixel_art_normal_map_generator/)

---

## A. Turning AI images into 3D space

### A1. Depth-guided paint-over  [documented]
- **What:** Instead of asking an image-edit model to "keep everything where it is," render a depth map (and optionally an edge or line render) of the blockout and generate the painting with Stable Diffusion + ControlNet (depth). This locks the painting to the geometry.
- **Use when:** Doing O1 and the paint-over keeps drifting; or you need many consistent views.
- **Steps:**
  1. Render a depth pass from the game camera (engine depth buffer or Blender Z pass, normalized).
  2. Generate with ControlNet depth, plus a style reference (IP-Adapter or a style LoRA, see Z2).
  3. Project as in O1.
- **Pitfalls:** The workflow is fiddly. Depth alone may lose small details, so add a lineart or canny ControlNet if needed.
- **Sources:** [Polycount thread](https://polycount.com/discussion/233290/blocking-level-to-concept-art-ai-paint-over), [Jason Arts – render blockout from game camera](https://jasonarts.com/blog-ai-concept-art-for-3d-modeling)

### A2. Multi-camera projection texturing  [documented]
- **What:** Project AI-generated paint onto a model from several cameras so all sides get textured. Stable Projectorz (free) does this: several cameras, generation per view, paint over the seams, bake ambient occlusion.
- **Use when:** O1's single-view limitation is a problem: the camera orbits, or objects are seen from multiple sides.
- **Pitfalls:** Some areas can come out black or untextured and need manual paint-over. Seams between projections need blending.
- **Sources:** [CGPress overview](https://cgpress.org/archives/stable-projectorz-an-ai-tool-for-3d-texture-generation.html), [STYLY tutorial](https://styly.cc/tips/ai-stablediffusion-stableprojectorz/)
- **Update** [r/StableDiffusion]: Stable Projectorz is now open source ([repo](https://github.com/IgorAherne/stableprojectorz), AGPL-3). It supports SD 1.5, SDXL, LoRAs and image-to-3D, and a [ComfyUI bridge](https://github.com/tianlang0704/ComfyUI-StableProjectorzBridge) adds Flux and Qwen. ([thread](https://www.reddit.com/r/StableDiffusion/comments/1qnmy1d/))

### A3. Bake projection into UV textures  [documented]
- **What:** In Blender, project the painting onto a mesh from the camera view, then bake the result into the mesh's regular UV texture.
- **Use when:** You want standard textured assets for any engine, with no custom projection shader at runtime.
- **Steps:**
  1. Add a camera matching the capture view.
  2. UV project from view, or texture paint with project-from-view.
  3. Bake to a clean UV unwrap.
  4. Export (glTF/FBX).
  5. Script it with Blender Python for repeatability.
- **Pitfalls:** Stretching on surfaces at a sharp angle to the camera, and no data on hidden faces. Combine with A2 if needed.
- **Source:** [Versluis – Projection painting in Blender](https://www.versluis.com/2021/10/blender-projection-painting/)

### A4. Pre-rendered backdrop + invisible collision geometry  [documented]
- **What:** The classic Final Fantasy VII / Resident Evil approach. Display the AI painting as a flat background. Place invisible 3D proxy geometry where walls and furniture are. It writes to the depth buffer but not the color buffer, so characters are hidden behind objects and collide with them.
- **Use when:** The camera never moves within a room. It's simpler than O1 because it needs no projection shader.
- **Steps:**
  1. Lock the camera.
  2. Background image on a full-screen quad or canvas.
  3. Proxy meshes with a depth-only material.
  4. Colliders on the proxies.
  5. Characters render normally.
- **Source:** [Godot forum – invisible geometry that still occludes](https://godotengine.org/qa/78797/shader-makes-geometry-invisible-still-depth-buffer-opaque)

### A5. Monocular depth → 2.5D diorama / parallax  [documented]
- **What:** Estimate a depth map from one AI image with a depth model such as Depth Anything (V2). Either displace a subdivided plane with it, or cut the image into layers by depth and place them at different distances.
- **Use when:** Painted backgrounds that should shift slightly as the camera moves, parallax layers, or menu/title scenes.
- **Pitfalls:**
  - Only small camera moves look right.
  - Edges between depth layers need inpainting to fill the gaps revealed behind foreground objects.
- **Sources:** [BlenderNation – 2.5D image in Blender](https://www.blendernation.com/2024/02/19/creating-a-2-5d-image-in-blender/), [EZdepth add-on](https://superhivemarket.com/products/ezdepth--ai-depth-map-generator-for-blender), [Research paper – dioramas from one image](https://ceur-ws.org/Vol-3498/paper3.pdf)

### A6. 360° AI skybox → environment mesh  [documented]
- **What:** Blockade Labs Skybox AI generates 360° equirectangular panoramas and can export a GLB mesh with depth, giving parallax instead of a flat sky.
- **Settings:** Mesh export is experimental. Depth scale ranges 3.0–10.0, and files get large at high density.
- **Use when:** Distant surroundings, VR, or quick environment prototypes.
- **Source:** [Blockade Labs – Export 3D models](https://support.blockadelabs.com/hc/en-us/articles/31649281677074-Export-3D-Models-from-Skybox-AI)

### A7. Image → explorable Gaussian-splat world  [documented]
- **What:** World Labs' Marble turns an image, text or video into a navigable Gaussian splat world (a 3D scene made of millions of soft points).
- **Exports:** splat (.spz/.ply), a visual mesh (GLB) and a collider mesh (GLB).
- **Use when:** Prototypes, level greyboxing, backdrops.
- **Avoid when:** You need final, gameplay-ready geometry or tight performance budgets. Splats are heavy and awkward in engines.
- **Sources:** [Scenario – Marble essentials](https://help.scenario.com/articles/4774055514-marble-by-world-labs-the-essentials), [Masterpiece X – splat limits](https://masterpiecex.com/blog/gaussian-splats-look-incredible-heres-what-to-do-when-you-need-real-assets)

### A8. AI orbit video → Gaussian splat  [documented, experimental]
- **What:** Generate a slow orbit video of a subject with a video model, then reconstruct it with standard tools: frame extraction, structure-from-motion, then splat training.
- **Pitfalls:** Video models are not perfectly 3D-consistent, so expect artifacts. Engine integration is the weak link.
- **Sources:** [vid2scene](https://replicate.com/kfarr/vid2scene), [OrbitForge paper](https://arxiv.org/pdf/2606.24799), [Generative Gaussian Splatting paper](https://arxiv.org/pdf/2503.13272)

### A9. Interior mapping with AI-painted rooms  [combination]
- **What:** Interior mapping is a shader that renders a fake 3D room behind a flat window using a cubemap: the back wall, side walls, floor and ceiling. Generate the room faces with AI so every building window shows a distinct room at almost no cost.
- **Steps:**
  1. Generate a room image set (back wall, left, right, floor, ceiling) in a consistent style.
  2. Assemble a cubemap.
  3. Apply an interior-mapping shader to window surfaces.
  4. Randomize per window.
- **Sources (shader only):** [Godot interior mapping shader](https://godotshaders.com/shader/interior-mapping-shader/), [Unreal example](https://www.fab.com/listings/a5062af1-de74-4b3b-97ff-67fd4dca53db)

### A10. AI heightmap → terrain  [documented]
- **What:** Generate a grayscale heightmap (bright = high) from text, or derive one from an AI-painted world map. Import as 16-bit into engine terrain.
- **Pitfalls:**
  - 8-bit heightmaps cause terracing; use 16-bit PNG or RAW.
  - Unity prefers RAW 16-bit.
  - Smooth the map before import.
- **Sources:** [Pixa heightmap generator](https://www.pixa.com/create/height-map-generator), [Unity heightmaps docs](https://docs.unity.com/en-us/engine/6000.0/manual/creating-environments/script-terrain/terrain-heightmaps.md), [Unreal heightmap tutorial](https://3d-mapper.com/unreal-engine-heightmap-terrain/)

### A11. "World Scroll": linked stills + video transitions  [r/aigamedev, 447 points, Jul 2026]
- **What:** Generate about 5 stills of linked locations. Make a video transition between each neighboring pair, using the stills as start and end frames. Map scroll position (or player progress) to video progress, so the viewer travels continuously through one world.
- **Use for:** title screens, story intros, map transitions, trailers, store-page showcases.
- **Steps:**
  1. Write a short script of linked set pieces (e.g. gate → chasm → forest → city → lair).
  2. Generate each still, with lighting, color temperature and camera angle spelled out so they read as one place.
  3. Generate each transition with a video model that supports start and end frames (the post used Seedance 2.0, about $2 per transition).
  4. Drive playback from scroll or progress.
- **Pitfalls:**
  - Consistency breaks when neighboring scenes differ by more than one step in lighting or geography.
  - The video model sometimes invents geometry mid-clip. Locking the camera angle in the prompt helped most.
  - The poster's own code is on a paid platform, but the method is reproducible without it.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1v8x5f1/)

### A12. Make AI maps game-aware: generate collision, depth and effect masks  [r/aigamedev]
- **What:** A pretty AI background is just a "sticker" until the game knows where the floor, walls and depth are. Have the image model (or a depth model) produce gameplay maps that line up exactly with the art. Variants:
  - **Collision mask by recoloring** (94 points): generate the level image, then send it back with "return the same map, but with all collidable surfaces highlighted in hot pink." Detect the pink pixels, smooth them, and use the result as the collision mask.
  - **Depth, hitbox, reflection and light maps for pre-rendered backgrounds:**
    - Draw a box over an object and have the image model generate a depth map for it.
    - Set a starting depth and auto-generate hitboxes from it.
    - Ask for a reflection map (black = puddles) for ripple and reflection shaders, and a light map.
    - Depth Anything V2 is a local, faster alternative for depth.
  - **Maps that ship with masks:** an open-source 2D engine plus asset tool outputs maps with bounding boxes, depth masks and obstacle masks, so characters correctly walk behind a barn instead of over it.
- **Source art for whole levels** [r/StableDiffusion, 208 points]: image models can draw complete, dense level art from one prompt. Have an LLM write the base prompt, and keep the camera wording explicit. Example pattern:
  - "A sprawling 16-bit pixel art jrpg city game level of [setting]. The design features complex, dense architecture with a high variety of structures including stairs, bridges, and stacked buildings. The scene is filled with [details]. Background shows [skyline]. Wide-angle top-down view" (or "side-scrolling view").
  - Then derive the masks as above.
  - **Source:** [thread](https://www.reddit.com/r/StableDiffusion/comments/1vtdr3l/)
- **Pitfalls:**
  - Check that masks line up pixel-for-pixel with the art.
  - Regenerate when the model shifts geometry.
  - Smooth and threshold the masks before using them.
- **Sources:**
  - [Collision mask post](https://www.reddit.com/r/aigamedev/comments/1ut1crf/)
  - [Pre-rendered background tooling post](https://www.reddit.com/r/aigamedev/comments/1pgl89i/)
  - [Capybara 2D engine post](https://www.reddit.com/r/aigamedev/comments/1utjwhq/) and [repo (MIT)](https://github.com/d-liya/capybara_2d_engine)

### A13. "The physics is the prompt": geometry first, then paint art to match it  [r/aigamedev]
- **What:** The 2D version of O1. Build the gameplay geometry first (walls, ramps, platforms, bumpers in exact positions). Export it as a silhouette image and ask the image model to "create a [theme] playfield that exactly matches this silhouette." The art lines up with the physics because the physics was the prompt.
- **Example:** used for a full pinball table built with LittleJS + Box2D.
  - Took many generations plus manual compositing of the best parts.
  - An in-game table editor made placing and tuning parts visual.
- **Why it matters:** AI backgrounds otherwise ignore gameplay spaces (where characters stand, where platforms are). If geometry can't be locked this way, keep gameplay-critical platforms as separate overlay assets on top of the background.
- **Sources:** [Alien Pinball postmortem](https://www.reddit.com/r/aigamedev/comments/1t6k8cl/), [before/after touch-pass thread](https://www.reddit.com/r/aigamedev/comments/1o6im00/)

### A14. Layered 2D scenes by diffing  [r/aigamedev, 98 points]
- **What:** For style consistency, generate each layer (e.g. a road, a building, a tree) as part of the whole image, not separately. Then diff the image before and after the addition to extract that layer with transparency.
  - Edit a region by painting it a marker color (pink) and asking the model to replace only that area.
  - A "global prompt" (camera angle, sun angle, art style) is added to every generation.
- **Pitfalls:** extending the map to neighboring tiles while keeping the style is the hard part.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1pgllhb/)

### A15. Paint semantic zones, let AI texture them (terrain)  [r/aigamedev]
- **What:**
  1. Sculpt terrain in Blender.
  2. Texture-paint zones using the ADE20K color codes (grass, rock, water…).
  3. Feed that image to ComfyUI with the ADE20K segmentation ControlNet to generate a matching texture.
  4. Bring the texture back to Blender.
- **Why:** you control exactly where each material goes.
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1otd9lm/), [workflow](https://pastebin.com/Ad6wjZ6g)

### A16. Frontier: AI that generates the gameplay frames itself (world models)  [r/StableDiffusion, r/LocalLLaMA; experimental]
- **What:** "World models" generate each frame of the game live from the player's input, with no engine underneath. Examples:
  - [Matrix-Game 3.0](https://huggingface.co/Skywork/Matrix-Game-3.0): MIT, 720p at 40 FPS on a 5B model, about a minute of memory consistency.
  - Hobbyists have trained small models that run locally (a 0.5B model turning any image into a playable scene on an RTX 5090; a Pong where every frame is generated).
- **Status:** impressive demos with poor motion, flicker and short memory. Not a basis for a shippable game in 2026. Worth knowing about for a dream-like or experimental project, and for keeping an eye on.

### A17. Huge seamless maps: teach a small edit model to "fill in next to its neighbors"  [Hacker News, 1,325 points]
- **What:** How one developer made a giant isometric pixel-art map of New York (about 40,000 tiles):
  1. **Source geometry:** render each area from Google's 3D map tiles with an orthographic camera. (An earlier attempt with separate 3D building data failed because it didn't line up with the imagery.)
  2. **Style:** a big image model (Nano Banana Pro) could do the style after prompt tuning, but was only about 50% consistent and too slow and expensive at that scale.
  3. **Fine-tune a small edit model** (Qwen Image Edit) on about **40 input/output pairs**: about 4 hours, about $12.
  4. **Seamlessness is built into training:** parts of each target were masked out, so the model learned to generate new tiles that continue already-finished neighbors. Generation is staggered so every new tile has neighbors to match, and rules decide which tile can be generated next.
  5. **Scale:** run the fine-tuned model on rented H100s for under $3/hour and 200+ generations/hour, planned in the evening and generated overnight.
- **Problems:** water and trees were the hardest. Automatic AI quality checks could not reliably spot seams or bad trees, so a human reviewed and fixed tiles using small agent-built tools (water color fixer, tile flagger).
- **Lesson from the author:** coding agents make throwaway tools cheap, but image models lack a tight feedback loop. Expect human judgment and manual polish at the end.
- **Sources:** [project write-up](https://cannoneyed.com/projects/isometric-nyc), [Oxen summary](https://www.oxen.ai/blog/isometric-nyc), [HN thread](https://news.ycombinator.com/item?id=46721802)
- **Sources:** [Matrix-Game thread](https://www.reddit.com/r/StableDiffusion/comments/1s59uzh/), [local world-model thread](https://www.reddit.com/r/StableDiffusion/comments/1uc55ix/), [Pong thread](https://www.reddit.com/r/StableDiffusion/comments/1skmmnp/)

---

## B. Making AI art react to light

### B1. Sprite normal maps  [documented]
- **What:** See O2.
- **Alternatives:** [Laigter](https://azagaya.itch.io/laigter) (free, non-AI), [Godot normal map plugin](https://github.com/krosseye/godot_normalMap_generator).
- **Compare tools first:** [Sprite-AI comparison](https://www.sprite-ai.art/blog/normal-map-generators-compared). Tools that infer depth from brightness often fail on stylized art.

### B2. Normal + height maps for textures  [documented]
- **What:** DeepBump (open source, GPL-3; also a Blender add-on and a ComfyUI node) predicts a normal map from a single color texture and can derive height and curvature from it.
- **Use when:** AI-generated wall, floor or rock textures need surface detail under lighting.
- **Sources:** [DeepBump ComfyUI node](https://www.runcomfy.com/comfyui-nodes/comfy_mtb/Deep-Bump--mtb-), [package listing the repo](https://gpo.zugaina.org/AJAX/Ebuild/54173589)

### B3. Lightable painted backgrounds  [combination]
- **What:** Generate normal maps (B1/B2), or derive normals from a depth map (A5), for AI-painted backgrounds, so in-game lights (torches, day/night) shade them correctly instead of floating over them.
- **Pitfalls:** Baked-in shadows in the painting will conflict with dynamic light. Prompt for flat, evenly lit paintings if you plan to light them dynamically.

### B4. Relight characters to match the scene  [documented]
- **What:** IC-Light (open source, by the ControlNet author) relights an image given a light direction or background, so separately generated characters match scene lighting.
- **Pitfalls:** Check consistency across animation frames. Edges may need cleanup. Pixel art may need re-quantizing afterwards (Z1).
- **Sources:** [Gigazine overview](https://gigazine.net/gsc_news/en/20240510-ic-light-image-relighting), [ComfyUI relighting walkthrough](https://www.trancy.org/pt/youtube/iEpHHnOYn2c)

### B5. Day/night via paired paintings  [combination]
- **What:** Use an image-edit model to make a night (or dusk, or rain) variant of each painted background, keeping the layout identical. A shader blends between variants using a time-of-day value.
- **Tips:** Recoloring with a LUT or palette keeps night blues better than simple darkening.
- **Pitfalls:** Variants must align pixel-for-pixel. Verify by diffing edges, and regenerate if layouts shift.
- **Sources (shader side):** [Day/night color-remap shader](https://marketplace.gamemaker.io/assets/2389/day-night-cycle-shader), [r/godot discussion](https://reddit.birdcat.cafe/r/godot/comments/am0kdo/godot_3_2d_daynight_cycle)

### B6. PBR materials from text or a photo  [documented]
- **What:** Generate full PBR material sets (albedo, normal, roughness, height, sometimes metallic) from a prompt or a photo.
- **Sources:** [Adobe Substance 3D Sampler – Image to Material](https://helpx.adobe.com/substance-3d-sampler/filters/tools/image-to-material.html) (paid subscription), [3D AI Studio material generator](https://docs.3daistudio.com/textures/material-ai) (freemium).

### B7. Retexture an existing mesh from a prompt  [documented]
- **What:** Keep a mesh, generate new textures from a text or image prompt (variants, skins, biome versions). Meshy AI Texturing accepts uploaded meshes and outputs PBR maps.
- **Pitfalls:** Bad or overlapping UVs cause seams; unwrap first. Keep texture resolution appropriate for real-time use.
- **Sources:** [Meshy AI texturing docs](https://docs.meshy.ai/en/webapp/guides/3d-model/ai-texturing), [Layer retexture](https://layer.ai/features/retexture.md)

---

## C. Using 3D as a hidden skeleton for consistent 2D

### C1. 3D → 2D sprite rendering (Dead Cells method, with AI-made 3D)  [documented]
- **What:** Dead Cells rendered animated 3D models into pixel-art sprite frames, so one artist could make and revise many animations. With AI:
  1. Concept image → 3D model (Hunyuan3D, Trellis, Meshy or Tripo).
  2. Retopologize or simplify.
  3. Auto-rig (Mixamo for humanoids; Meshy/Tripo for others).
  4. Apply animations.
  5. Render with an orthographic camera at low resolution:
     - Blender/Eevee: 1 sample, "Standard" view transform, no bloom.
     - Use flat or hand-picked material colors.
  6. Rotate the camera in 45° steps for 8 directions.
  7. Run Z1 cleanup, then pack sprite sheets.
- **Pitfalls:**
  - Auto-rig skin weights often fail at elbows, wrists and spine.
  - AI meshes are often dense.
  - Generate in T-pose or A-pose with separated limbs for better rigging.
- **Sources:**
  - [80.lv – Dead Cells interview](https://80.lv/articles/interview-with-the-developers-of-dead-cells)
  - [BNPR – pixel art rendering in Blender](https://bnpr.gitbook.io/bnpr/pixel-art)
  - [Tripo – rig for Mixamo](https://www.tripo3d.ai/blog/rig-ai-generated-character-for-mixamo)
  - [3D AI Studio – Trellis vs Hunyuan](https://www.3daistudio.com/blog/pixal3d-vs-trellis-2-vs-hunyuan-3d-comparison)
  - Engine pixel cameras: [PixelCamera (Unity)](https://github.com/ekx/PixelCamera), [dddpix (Godot)](https://store.godotengine.org/asset/wing888/dddpix/)
- **Community-endorsed version** [r/aigamedev]: the most-upvoted answer to "most reliable way to make consistent 2D sprites" ([thread](https://www.reddit.com/r/aigamedev/comments/1u363gx/)):
  1. Generate T-pose front, back and side images.
  2. Hunyuan3D → remesh in Blender to remove junk vertices.
  3. AI-texture the model (albedo).
  4. Rigify or Mixamo.
  5. Orthographic camera.
  6. A sprite-sheet render add-on.
  - The commenter says it took months to set up and needs some Blender knowledge.
- **Local 3D generation** [r/aigamedev]: a community build runs TRELLIS.2 on 8 GB NVIDIA GPUs ([thread](https://www.reddit.com/r/aigamedev/comments/1st19u1/)). Retopologize the output (e.g. with InstantMeshes) before rigging.
- **What 3D generation is good and bad at** (one dev's 3-month log): see Z7.

### C2. AI restyle of 3D animation renders  [documented]
- **What:** Render a simple 3D animation, then run each frame through img2img with a depth ControlNet so the AI applies the art style while the 3D motion keeps poses consistent.
- **Settings:**
  - Denoise around 0.7–0.8 with depth control; higher values give more style but more flicker.
  - Render on a green or plain background and composite later.
- **Pitfalls:** Frame-to-frame flicker. Consider multi-frame or temporal methods, or fewer frames.
- **Sources:** [itch.io thread with settings](https://itch.io/post/7466916), [gif2gif extension](https://github.com/metixxx/gif2gif)

### C3. Multi-view generation from one image  [documented]
- **What:** Multi-view diffusion models (MV-Adapter on SDXL; Zero123++) generate consistent views of a character or object from other angles.
- **Use for:** 4- or 8-direction sprite references, or as better input for image-to-3D.
- **Sources:** [ComfyUI-MVAdapter](https://www.runcomfy.com/comfyui-nodes/ComfyUI-MVAdapter), [MV-Adapter paper](https://openaccess.thecvf.com/content/ICCV2025/html/Huang_MV-Adapter_Multi-View_Consistent_Image_Generation_Made_Easy_ICCV_2025_paper.html), [Zero123++ paper](https://ar5iv.labs.arxiv.org/html/2310.15110)
- **Newer local route** [r/comfyui]: Qwen Image Edit 2511 with the [Multiple-Angles LoRA](https://huggingface.co/fal/Qwen-Image-Edit-2511-Multiple-Angles-LoRA) makes the 4 views, which then feed a multi-view TRELLIS.2 workflow. Low-VRAM GGUF versions exist, plus a "Pixal3D" pixel-3D variant. ([thread](https://www.reddit.com/r/comfyui/comments/1umsmau/))

### C4. Sprite stacking  [documented]
- **What:** Pseudo-3D. An object is drawn as horizontal slices stacked with a 1-pixel vertical offset each, and rotates smoothly in a top-down 2D game.
- **With AI:** AI 3D model → voxelize (MagicaVoxel or Goxel) → export slices.
- **Pitfalls:** Many slices on many objects can cost performance.
- **Sources:** [Wee Boats devlog](https://jamespoole.itch.io/wee-boats/devlog/685630/using-sprite-stacking-for-pseudo-3d-in-wee-boats), [MonoGame forum](https://community.monogame.net/t/sprite-stacking/12964)

### C5. AI 3D props → isometric sprites  [documented]
- **What:** Generate props as 3D, then render all of them with one fixed isometric camera and light rig. This guarantees a consistent angle and light direction, which pure image generation struggles with.
- **Sources:** [3D to Iso](https://foundryvtt.com/packages/3d-to-iso), [Scenario – isometric tiles](https://help.scenario.com/articles/3103010885-build-isometric-tiles), [Layer – consistent isometric assets](https://help.layer.ai/en/articles/12055377-how-to-forge-consistent-isometric-game-assets)

### C6. Pose-sheet-driven sprite animation  [documented]
- **What:** Provide a sequence of pose skeletons (OpenPose format) plus a character reference, and generate each frame with pose ControlNet.
- **Pitfalls:** Pose detectors generalize poorly to stylized sprite proportions, so poses may need manual correction. Single-frame ControlNet has no temporal consistency. Reference-conditioned methods (Animate Anyone-style; see the paper) do better.
- **Sources:** [Sprite Sheet Diffusion paper](https://arxiv.org/html/2412.03685v2), [Apatero open-source sprite guide](https://apatero.com/blog/open-source-sprite-generation-ai-complete-guide-2025)

### C7. 8-direction pose sheet in one image (3×3 grid prompt)  [r/aigamedev, 364 points, May 2026; poster runs SpriteCook]
- **What:** Ask an image model for a 3×3 grid with the center cell empty. Each cell holds one full-body view, facing outward toward its own edge or corner. Define directions relative to the canvas, not the character. The sheet is then predictable enough to slice by script.
- **Prompt structure, in blocks:**
  1. Subject.
  2. Layout: 3×3, empty center, one centered full-body view per cell, evenly spaced.
  3. Facing rule per cell: top row = back views, middle row = sides, bottom row = front views; spell out the diagonals.
  4. Consistency: same outfit, scale and palette; no mirroring or duplicated views.
  5. Style: plain background; no text, labels or arrows.
- **Models:** GPT Image 2 (medium quality); Nano Banana fails less often for pixel art. Optionally attach a reference character.
- **Then:** slice the 8 cells automatically and animate each direction separately.
- **Pitfalls:**
  - Left and right are often just mirrored (a weapon switches hands). Fix with follow-up prompts, or generate the character empty-handed and composite the weapon in.
  - For perfect rotation, use C1: convert to 3D (Meshy, Tripo or Trellis), rotate and capture each angle with a script.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1tlidho/) (full prompt in the post)

### C8. Agent-scripted Blender models from a reference image  [r/aigamedev, 639 points, Aug 2026]
- **What:** Instead of an image-to-3D generator, a coding agent writes a Blender Python script that builds the model to match a reference image, through Blender MCP or plain scripts. The script is the source file, so proportions stay editable and related models stay consistent.
- **Use when:** low-poly or stylized assets seen from a distance: props, islands, buildings, boats. The poster dropped a mesh generator (Rodin) because its meshes needed too much cleanup.
- **Steps:**
  1. Generate a reference image in the in-game style.
  2. Ask the agent to rebuild it in Blender by script.
  3. Export.
  4. Judge it from the actual in-game camera (see F4). Islands that looked fine from above were flat "pancakes" in-game.
- **Pitfalls:** don't expect high-detail results; this suits low-poly styles.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1vrj2cl/)
- **Variants:**
  - **[img2threejs](https://github.com/hoainho/img2threejs):** a coding-agent skill that rebuilds an image as a Three.js code model ("keep the proportions, angles, and colours"), then iterate by saying what you don't like. Can be token-expensive: one user reported about $6 for one model via API.
    - **Source:** [thread](https://www.reddit.com/r/aigamedev/comments/1v169hl/)
  - **[godot-create-3d-assets](https://github.com/LuigiDeFacci/godot-create-3d-assets):** an open-source agent skill that builds stylized assets from Godot-native geometry. It profiles the project's existing style, then checks scale, collisions, navigation, LODs and multi-angle screenshots.
    - **Source:** [thread](https://www.reddit.com/r/aigamedev/comments/1uzx3gu/)

### C9. Zero-asset art: everything generated from code  [r/aigamedev]
- **What:** The agent writes the art itself as code, with no image or 3D generators and no asset files. It suits browser games, prototypes and stylized looks.
- **Examples:**
  - **Procedural creatures (692 points):** bodies made of capsules and spheres, visually fused by an SDF blend-shell vertex shader, with toon styling and procedural animation for 2-legged, many-legged, hopping and flying creatures. One long agent run cost about $75 in tokens. ([thread](https://www.reddit.com/r/aigamedev/comments/1umiurs/))
  - **Procedural textures baked at boot:**
    - Each material is a GLSL `surface()` function (dirt, stone, wood, fur, foliage), baked once at load into albedo/normal/ORM maps.
    - Normals come from the same height field as the color, so the lighting matches the painted detail.
    - Rocks are displaced icosahedrons, sounds use Web Audio, and the repo has no asset files at all.
    - ([3D platformer thread](https://www.reddit.com/r/aigamedev/comments/1v9mbbe/))
  - **Sprites as ASCII art in source files:** a "3D pixel" FPS stored each sprite as ASCII art inside a TypeScript file. ([thread](https://www.reddit.com/r/aigamedev/comments/1v88s61/))
  - **Code-built models with pixel textures:** an RTS with 60k units in the browser, built from a prompt to "use code to construct the models and draw textures in a pixel-art style." ([thread](https://www.reddit.com/r/aigamedev/comments/1u43b1s/))
  - **Open-source resources:** [anyCreature](https://github.com/Ariescar/anyCreature) (agent harness for creatures with basic bones), [threejs-procedural-dungeon](https://github.com/majidmanzarpour/threejs-procedural-dungeon), [Kenney Shape](https://kenney.nl/tools/kenney-shape).
  - **Five MIT "assets as code" skills for Claude Code** [r/ClaudeAI]:
    - **The skills:** [pxl](https://github.com/uilianks/pxl) (pixel art, with a lint for common pixel-art mistakes), [vex](https://github.com/uilianks/vex) (vector art, skeletal animation, Spine export, Tiled maps), [kiln](https://github.com/uilianks/kiln) (low-poly and voxel 3D to GLB), [loom](https://github.com/uilianks/loom) (seamless PBR textures), [chirp](https://github.com/uilianks/chirp) (synthesized SFX and music).
    - **The feedback loop:** each has a live viewer with an annotate mode. The human paints on the art or pins a note, then clicks "send to Claude," and Claude receives the exact spot plus the line of code that made it.
    - ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xc30xk/))
  - **Build a small kit first, then compose from it** [r/ClaudeAI]:
    - **Example:** a browser game with 100 collectible cards and 22 ships, with no image or sound files. The agent first wrote an SVG "kit" (stars, skies, planets, ships, trails), then composed every card from parallax layers plus a hero. All 100 cards are 152 kB of code.
    - **Performance lesson:** SVG filters re-rendered on every phone tilt, so each layer is now painted once to a canvas.
    - ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xbirxe/))
  - **Shipped examples with zero asset files:** a Three.js traffic game published on CrazyGames ([thread](https://www.reddit.com/r/ClaudeCode/comments/1skf838/)), and a Balatro-style darts game in one 2,500-line HTML file with canvas-drawn art and synth audio ([thread](https://www.reddit.com/r/vibecoding/comments/1stxr9z/)).
- **Pitfalls:**
  - Long agent runs are expensive.
  - The output is stylized, not realistic.
  - Comment threads note it can look generic. Give a strong, specific art direction (see Z2).

### C10. Many assets on one canvas, then slice  [r/aigamedev]
- **What:** Image models keep style more consistent when assets share one canvas, and it's far cheaper: one post got 49 characters in a single Nano Banana 2 call. Then slice automatically.
- **Slicing tips:**
  - Within each cell, keep only the largest connected "island" of pixels, because AI never spaces items perfectly and parts bleed into neighbors.
  - For animation strips, crop the same region on every frame to keep alignment.
  - For messy sheets, use the open-source [Sprite Extractor](https://extractor.fyrean.com/). It runs in the browser and cuts by exact shape, not bounding box. Raise its alpha threshold if sprites stick together.
  - Afterwards, have the agent sort the pieces by type and re-pack them into texture atlases.
- **Sources:** [slicer post](https://www.reddit.com/r/aigamedev/comments/1t74hr9/) (poster runs SpriteCook), [Sprite Extractor post](https://www.reddit.com/r/aigamedev/comments/1nwjmzm/), [UI extraction post](https://www.reddit.com/r/aigamedev/comments/1s1xvp0/)
- **One layout file as both prompt and parser** [r/comfyui]: write the sprite-sheet layout as Aseprite JSON (frame names and coordinates). Give it to the image model (GPT Image 2 handled this best) as the layout to draw into, then slice the result with the same JSON. ([thread](https://www.reddit.com/r/comfyui/comments/1swunoo/), [nodes](https://github.com/quinteroac/ComfyUI-GameAssetsMaker))

### C11. Use an existing sheet as a layout-only reference  [r/aigamedev, 269 points]
- **What:** To get a structured output, such as a character concept plus move-set sheet, attach an example sheet as reference. Prompt the model to be "inspired only by the overall presentation format of the referenced image, not the character, pose, design, outfit, powers, or moves," and require a different silhouette, palette and effects. Generate 4 at a time and pick the best.
- **Similar trick for UI:** generate hundreds of UI mockups, extract the best elements, and redesign from those.
- **Sources:** [move-set thread](https://www.reddit.com/r/aigamedev/comments/1s9x1q1/) (full prompt in the OP's comment), [UI evolution thread](https://www.reddit.com/r/aigamedev/comments/1s1xvp0/)

---

## D. Animation without hand-animating

### D1. Video motion capture  [documented]
- **What:** Convert webcam or phone video of a person into 3D skeletal animation. The human acts the motion; you retarget it to characters.
- **Tools:** Rokoko Video/Vision (free, browser; cleanup in Rokoko Studio; exports to Blender/Unity/Unreal), Move AI app (iPhone).
- **Pitfalls:** Single-camera capture is noisy. Apply foot locking and filtering.
- **Sources:** [Rokoko Video launch](https://www.rokoko.com/insights/rokoko-video-launch), [Move AI app](https://apps.apple.com/us/app/move-one/id6448635527)

### D2. Text-to-motion  [documented]
- **What:** HY-Motion 1.0 (Tencent, open source) generates 3D skeletal animation from text prompts. It uses the SMPL-H skeleton, so retarget it to your rig.
- **Pitfalls:** Complex athletic motions are weaker. Check the license and hardware requirements in the official repo.
- **Sources:** [HY-Motion paper](https://arxiv.org/html/2512.23464v1), [summary](https://rits.shanghai.nyu.edu/ai/tencent-open-sources-hy-motion-1-0-a-billion-parameter-text-to-motion-ai-model/)
- **Alternative** [r/aigamedev]: an open-source Blender plugin plus self-hostable server for NVIDIA's Kimodo text-to-motion. You can set keyframes and constraints, and the output is ordinary Blender keyframes on the armature.
  - **Sources:** [thread](https://www.reddit.com/r/aigamedev/comments/1swctod/), [write-up](https://animatica.ai/kimodo)

### D3. Single illustration → rigged 2D cutout puppet  [documented, early-stage]
- **What:** Decompose one character illustration into body-part layers, inpaint the hidden regions, and build a bone and mesh rig for Spine or Live2D-style animation.
- **Tools:** OCS / OneClickSpine (open source, PNG → Spine 4.2 rig), img2rig (open source), Layer "Create Spine Components" (hosted).
- **Pitfalls:** Inpainted hidden regions vary in quality. Inspect every layer.
- **Sources:** [OCS](https://github.com/sleeeppy/OCS), [img2rig](https://github.com/SSnemo/img2rig), [Layer Spine components](https://layer.ai/tools/layer--create-spine-components), [Bunraku paper](https://www.alphaxiv.org/abs/2607.27348)
- **More from r/aigamedev:**
  - **[see-through](https://github.com/shitagaki-lab/see-through):** open-source layer decomposition, which OCS builds on. It works well even on complex characters, but expect to rearrange layers and split left and right arms. Rigging and animating is still the bigger job. ([thread](https://www.reddit.com/r/aigamedev/comments/1sdswrw/))
  - **[N-Sprite](https://github.com/lucaspedrajas/N-Sprite):** open-source research pipeline. Gemini plans the parts, SAM3 masks them, inpainting fills hidden areas, then it builds a rig. Splitting the job into narrow steps improved results. ([thread](https://www.reddit.com/r/aigamedev/comments/1qi1img/))
  - **Pin-based mesh deformation instead of bones:** Warp Studio (paid, about $5) lets you, or an agent over MCP, place pins and move them while the mesh bends naturally. It also has swappable part states such as blinking eyes. ([thread](https://www.reddit.com/r/aigamedev/comments/1x2214t/))
    - The poster's broader point: agents do much better when given capable tools (Blender MCP, an animation app) than when asked to build the whole pipeline themselves.
  - **Visual-novel composite sprites:** a ComfyUI/SAM3 workflow separates body, hair, clothes and facial parts into layers. ([thread](https://www.reddit.com/r/aigamedev/comments/1pj17zt/))
    - **Tip:** keep the same seed and change only the prompt when generating expressions, so they stay the same person's face.
  - **Spine-ready parts** [r/StableDiffusion, 193 points]: prompt for cel or flat shading so the parts animate cleanly; heavy painted shading breaks when limbs move. Use ControlNet for pose stability and an image-edit model for the character sheet and the later parts. Qwen or Z-Image edits cost far less than Nano Banana Pro for the same number of iterations. ([thread](https://www.reddit.com/r/StableDiffusion/comments/1ryqfe9/))

### D4. Animated dialogue portraits  [documented]
- **What:** LivePortrait (open source) animates a still portrait's head pose, eyes and mouth from a driving video.
- **Workflow:** Record one short driving clip per emotion and reuse it across characters.
- **Pitfalls:** Expressiveness depends on the driving footage. Test on stylized or anime art before committing.
- **Sources:** [Tom's Guide hands-on](https://www.tomsguide.com/ai/ai-image-video/i-tried-liveportrait-a-fun-way-to-animate-headshots-and-more), [Puppetry – LivePortrait](https://puppetry.com/glossary/liveportrait)
- **Expression and pose sheets for visual novels** [r/StableDiffusion, r/comfyui]:
  - A ComfyUI workflow takes one reference image and outputs 8 sprites (any pose, emotion or outfit) in about 2 minutes on a 16 GB GPU (MiniMax H3 plus [Fizgig nodes](https://github.com/shootthesound/ComfyUI-Fizgig-H3-Still)). ([thread](https://www.reddit.com/r/StableDiffusion/comments/1x1mp6o/))
  - "Pantomime" generates a new facial expression with Flux.2 Klein, refines it with SDXL, and outputs both the full image and a face-only crop. ([thread](https://www.reddit.com/r/StableDiffusion/comments/1sobvch/))

### D5. Lip sync for generated voice lines  [documented]
- **What:** Rhubarb Lip Sync (free) analyzes audio and outputs mouth-shape timings as TSV, XML or JSON, using 6 basic plus 3 optional mouth shapes.
- **Workflow:**
  1. Render each TTS line to WAV.
  2. Run Rhubarb offline at build time.
  3. Ship the JSON and play mouth frames in sync.
- **Pitfalls:** Not suited to live or dynamic speech. For that, use a TTS provider with viseme output.
- **Live 3D lip sync in the browser** [r/threejs]: [react-ai-voice-avatar](https://github.com/927tanmay/react-ai-voice-avatar) is open source. It runs Kokoro TTS on WebGPU, maps phoneme timings to the 52 ARKit face blendshapes, and smooths them each frame. Speech recognition (Whisper) and a small LLM can also run locally, or you can stream text from your own backend. ([thread](https://www.reddit.com/r/threejs/comments/1voiwm9/))
- **Sources:** [Rhubarb Lip Sync](https://awesome.ecosyste.ms/projects/github.com%2Fdanielswolf%2Frhubarb-lip-sync), [lip sync options overview](https://abratabia.com/ai-talking-characters/best-lip-sync-tools.php)

### D6. AI video → sprite frames  [documented]
- **What:** Use a clean character image as the first frame of an AI video on a solid green background.
- **Steps:**
  1. Trim the video.
  2. Chroma-key or matte the background.
  3. Extract frames (e.g. `ffmpeg -i in.mp4 -vf fps=12 frames/%03d.png`).
  4. Align to a fixed canvas and pivot.
  5. Run Z1 cleanup for pixel art.
  6. Pack the sheet and test the loop in the engine.
- **Pitfalls:** Size and pivot drift between frames, and edge halos.
- **Looping tip** [r/aigamedev]: use a video model with first- and last-frame control (e.g. Veo 3.1) and set both to the same standing pose. The animation loops, and the character doesn't drift out of frame or get cropped. Prompt pattern: "start running in the direction he's facing, run for a while, then stop."
  - **Source:** [thread](https://www.reddit.com/r/aigamedev/comments/1u363gx/)
- **Note:** the raw GPT Image 2 model can't output transparency; ChatGPT cuts the background out afterwards. Use E7 or E9 instead.
- **Sources:** [Scenario – sprite methods](https://www.scenario.com/blog/ai-sprite-generator), [Sorceress – background removal for sprite loops](https://sorceress.games/blog/clean-an-ai-video-background-remover-for-sprite-loops), [MP4toSprite](https://yewlark.itch.io/mp4tosprite)

### D7. Pixel animation tool chain + chained clips  [r/aigamedev, 164 points, Mar 2026]
- **What:** No single tool animates pixel art reliably. Use a chain of tools instead.
- **Chain:**
  1. Concept art (ChatGPT image gen, with references).
  2. Gemini turns it into faux sprite art.
  3. Pixel Engine converts that to true pixel art.
  4. Remove the background in Aseprite.
  5. SpriteCook for core animations (walk, idle); Pixel Engine for ability animations.
  6. Manual cleanup in Aseprite, usually eyes and mouths.
- **Long animations:** generate a short clip, use its last frame as the start of the next clip, and repeat. Cover seams with hand-drawn particle effects.
- **Pitfalls:**
  - Both core tools are made by regular posters in the sub.
  - The poster abandoned PixelLab, Ludo, and AI video plus 360° turnarounds after spending hundreds of dollars.
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1s76q5f/), [Pixel Engine](https://pixelengine.ai), [SpriteCook](https://www.spritecook.ai)
- **Related options:**
  - **Keyframe animation:** Pixel Engine added a model that takes any number of keyframe images at chosen frames and animates between them; vendor post. ([thread](https://www.reddit.com/r/aigamedev/comments/1sf4jwi/))
  - **Local alternative:** a ComfyUI workflow with one LoRA trained per animation (idle, walk…) plus a video model, exporting frames with no background. ([thread](https://www.reddit.com/r/aigamedev/comments/1sborjs/))
  - **Agent skill:** [agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) is an open-source Codex skill that goes from one prompt to a sprite sheet, cleanup, transparent PNG and GIF. ([thread](https://www.reddit.com/r/aigamedev/comments/1su1rfy/))

### D8. Layered customizable characters (local ComfyUI)  [r/aigamedev, 110 points, Apr 2026]
- **What:** Animate a bare base character, then inpaint each cosmetic (hair, eyes, shirt) onto that same animation. Every layer lines up pixel-perfectly frame by frame. Output grayscale sheets so each layer can be tinted in-engine.
- **Pipeline:**
  - **Base animations:** Wan 2.2 image-to-video 14B (GGUF Q5_K_M, lightx2v 4-step distill) → BiRefNet for clean alpha → ImageStitch + ImageRGBToYUV nodes build a grayscale sprite sheet.
  - **Each cosmetic:** Wan 2.1 VACE 14B + CausVid distill LoRA inpaints the cosmetic over the base animation video → SAM3 isolates it per frame → same sheet nodes.
- **Hardware:** RTX 3090 (24 GB) with dynamic model unloading. With less memory, rent a GPU (the poster cites about $1/hour for 96 GB).
- **Pitfalls:** Wan 2.2 Animate drifted from the base motion, which is why the poster switched to VACE inpainting.
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1svef6q/), [workflow repo](https://github.com/mor-o/comfyui-2d-character-pipeline)

### D9. Pick the animation method by motion type  [r/aigamedev, 40 points, Oct 2026]
- **What:** One developer tested 8 ways to animate the same 42px chibi characters:
  - AI-drawn sprite sheets
  - a pixel "puppet" (one drawing cut into parts and moved in code)
  - AI-drawn parts on a code rig
  - AI video turned into frames
  - AI video as motion capture (mocap)
  - voxel 3D
  - code-built Blender
  - hand-coded animation and effects
- **Findings:**
  - **AI video mocap failed at tiny sizes:** greatswords swung one-handed, fake kicks, a backflip that tore the sprite apart.
  - **AI video is good for** idle, hit, death and spell casts.
  - **Walks:** drawn walks have more charm; rigged walks keep feet planted. Use both.
  - **Blender** looked great in smooth 3D but not shrunk to 42px.
  - **Hand-coded effects** read best (a cracked floor beat AI rock spikes).
  - Pixel animation should be fast, bouncy and exaggerated, so realistic motion is the wrong reference.
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1x93t4b/), [comparison page with about 50 clips and a Claude Code skill](https://claude.ai/artifact/JJcXi1efGN5qyfdTTj3UAU)

### D10. Full voice acting with AI, at scale  [r/aigamedev, 124 points]
- **What:** One modder voiced a 2013 RPG: 3,900 lines, 126 characters, plus a narrator. Voice generation (ElevenLabs v3) was the easy part. What made it shippable:
  - **An audition tool:** a local web app that generates samples from 180+ candidate voices per character, keeps take history and marks keepers. Casting by ear is only feasible when auditions are instant.
  - **An LLM preprocessing pass:**
    - Lines with variables (`$(player.name)`) are rewritten in context so they can be spoken.
    - Lines that mix narrator prose with dialogue are split into ordered narrator and character segments.
    - The on-screen text stays untouched.
  - **Expressive settings:** generate at maximum expressiveness and regenerate bad takes instead of settling for flat, safe output. Use [tag] guidance for tone.
  - **Human review of every shipped take.**
- **Cost:** about $60–80 for about 420k characters of dialogue.
- **Pitfalls:** names get misread, some lines need several regenerations, and casting consistency still needs a human ear.
- **Sources:** [thread](https://www.reddit.com/r/aigamedev/comments/1uytejb/), [open-source tooling](https://github.com/MartinMouritzen/ShadowRun_VoicePack)

### D11. Agent-directed trailers and cinematics  [r/aigamedev]
- **What:** Give the agent engine access (MCP) and a video-model API with a budget, and ask it to write, generate and edit a trailer.
  - **Example prompt (paraphrased):** "Read my game but don't change it. Make a ~45-second cinematic trailer with snappy editing, different angles and lighting. You may use OpenRouter for assets with a $10 max budget. You create the script, assets and animation. Work autonomously until done."
  - It used Veo 3.1 Lite clips and cost about $3.
- **Pitfall:** be specific about genre and tone. In that example, a cozy tower-defense game got a horror-movie trailer.
- **Alternative for hand-directed cinematics:** [ArtCraft](https://github.com/storytold/artcraft) is an open-source desktop tool that lets you lay out the set, characters and camera in 3D, then render through video models (bring your own API key).
- **Sources:** [trailer thread](https://www.reddit.com/r/aigamedev/comments/1wrgmaw/), [ArtCraft thread](https://www.reddit.com/r/aigamedev/comments/1rco4s2/)
- **Your phone as a virtual camera** [r/comfyui]:
  1. Block out the scene in 3D so character positions are locked.
  2. Film camera moves by moving your phone through the 3D scene.
  3. Render a depth pass, then generate the final shots with a video model in ComfyUI.
  - Good for dialogue scenes and a cinematic feel. ([thread](https://www.reddit.com/r/comfyui/comments/1wako2i/))

---

## E. Unifying mismatched assets

### E1. HD-2D presentation  [documented]
- **What:** 2D sprites as camera-facing billboards in a 3D scene, plus a depth-based tilt-shift or depth-of-field blur and 3D lighting (the Octopath Traveler look). It masks small inconsistencies between AI assets.
- **Sources:** [Godot depth-based tilt-shift](https://godotshaders.com/shader/depth-based-tilt-shift/), [Billboards in Unity](https://gamedevbeginner.com/billboards-in-unity-and-how-to-make-your-own/)

### E2. Global color grading LUT  [documented]
- **What:** Grade a game screenshot in an image editor to match the concept art, export the grade as a LUT (lookup table), and apply it in post-processing. Assets from different AI tools and sessions then share one palette and mood.
- **Pitfalls:** Apply after lighting is final, at moderate strength. In Unreal, LUTs apply to the final sRGB output.
- **Sources:** [Unreal LUT docs](https://dev.epicgames.com/documentation/unreal-engine/using-lookup-tables-for-color-grading-in-unreal-engine), [World of Level Design LUT guide](https://worldofleveldesign.com/categories/ue5/luts-complete-guide.php)

### E3. Toon shading + outlines on AI 3D models  [documented]
- **What:** Cel shading (stepped lighting) plus inverted-hull outlines (a duplicated, slightly enlarged mesh with flipped normals and front-face culling) make AI 3D models read as hand-drawn and match 2D art. Use per-material outline colors, e.g. a darkened albedo.
- **Pitfalls:** AI meshes with messy normals produce broken outlines. Recalculate normals and simplify first.
- **Sources:** [Kodeco toon outlines tutorial](https://www.kodeco.com/92-unreal-engine-4-toon-outlines-tutorial), [Toon Shaders Pro (Unity)](https://danielilett.itch.io/toon-shaders-pro-for-unity-urp)

### E4. Native transparent generation  [documented]
- **What:** LayerDiffuse makes Stable Diffusion generate real alpha channels (RGBA). Edges, hair and glass come out cleaner than when you remove the background afterwards.
- **Pitfalls:** Model weights have their own licenses; check before commercial use.
- **Sources:** [LayerDiffuse paper](https://www.arxiv.org/abs/2402.17113), [Stable Diffusion Art guide](https://stable-diffusion-art.com/?p=12800)

### E5. Wang tiles via inpainting  [documented]
- **What:** Treat tile generation as inpainting with fixed edges, producing Wang or Dual Wang tile sets that connect seamlessly in any valid arrangement.
- **Sources:** [Paper (SIGGRAPH Asia 2024)](https://arxiv.org/html/2409.14184v1), [ComfyUI content_aware_tiles](https://www.runcomfy.com/comfyui-nodes/content_aware_tiles)
- **Pixel-art alternative (non-AI, from a few hand tiles):** [Grimoire](https://blackmagikstudios.itch.io/grimoire-tilemap-generation)

### E6. Seamless tileable textures  [documented]
- **What:** Set the diffusion model's and VAE's convolution padding to circular so generated images wrap at the edges. Verify by offsetting the image by half its size and checking for seams.
- **Sources:** [ComfyUI seamless tiling node](https://www.runcomfy.com/comfyui-nodes/ComfyUI-seamless-tiling), [NVIDIA research](https://research.nvidia.com/publication/2023-07_interactive-ai-material-generation-and-editing-nvidia-omniverse)

### E7. Generate on a key-friendly background  [r/aigamedev, recurring tip]
- **What:** Generate sprites and animation videos on a solid, high-contrast background (bright green for video, plain white or green for stills) so they cut out cleanly with chroma key or background removal. Tell the model explicitly not to put the grid, text or scenery in the background.
- **Wording tip** [r/comfyui]: with SDXL, "transparent background" still produced scenery behind item icons, while "isolated on plain white background" gave clean cut-outs. That poster's pixel-art setup: SDXL + nerijs/pixel-art-xl LoRA at 0.8, all native nodes. ([thread](https://www.reddit.com/r/comfyui/comments/1uuik9k/), [workflow](https://gist.github.com/yangdafish/36b3ff2a3a8923d1848e66f7a022b4e8))
- **Sources:** [My best prompts for sprite generation](https://www.reddit.com/r/aigamedev/comments/1uacn8h/), [8-direction thread comments](https://www.reddit.com/r/aigamedev/comments/1tlidho/)

### E8. UI kit from one generated image  [r/aigamedev]
- **What:** Generate a full UI mockup, or all the UI pieces (frames, buttons, map ring, compass, health orbs) on one transparent image. Then have the agent slice it and assemble the HUD to match the mockup.
- **Tips:**
  - In Godot, Sprite2D's region editor auto-slice cuts the pieces without Photoshop.
  - Layered orb textures can drive animated-liquid shaders.
  - [Game UI Database](https://www.gameuidatabase.com/) is a good source of reference screens.
- **Sources:** [ARPG post](https://www.reddit.com/r/aigamedev/comments/1s72nx6/), [fishing game post](https://www.reddit.com/r/aigamedev/comments/1vrj2cl/)
- **Avoiding the generic "AI menu" look** [r/vibecoding]: agents tend to produce the same centered buttons and default fonts. Two approaches:
  - **Design the UI yourself, hand it over as a contract.** Envy (a $9.99 Figma-like game UI editor; MIT runtimes for Godot and web) exports:
    - a handoff package with agent rules (`AGENTS.md`), a ready-made prompt,
    - a typed `contract.json` of every event and data path (e.g. `boss.hp`, `start_game`), so the agent wires names instead of guessing them,
    - reference renders of every screen and generated controllers.
    - The general pattern works with any tool: a fixed design, a typed list of hooks, and reference images. ([thread](https://www.reddit.com/r/vibecoding/comments/1xdri8e/))
  - **Image → editable layers → code:** 12ui splits a generated UI image into editable layers and exports React. ([thread](https://www.reddit.com/r/vibecoding/comments/1v4xto1/))

### E9. Clean transparency from two backgrounds  [r/aigamedev]
- **What:** Image-edit models often can't output transparency, and background removers leave halos. Instead, generate the same image twice, once on solid white and once on solid black. Compare the two pixel by pixel to compute exact alpha, including soft edges like feathers and hair.
- **Tool:** [NanoAlpha](https://github.com/MarkoUnity/NanoAlpha), free, open source, runs locally.
- **Pitfall:** the two images must be identical apart from the background. Ask the edit model to change only the background.
- **Source:** [thread](https://www.reddit.com/r/aigamedev/comments/1u2vt91/)

---

## F. AI building the game itself

### F1. LLM levels as text grids + deterministic builder + validator  [documented]
- **What:** An LLM outputs a level as an ASCII grid (e.g. `#` wall, `.` floor, `D` door), ideally as strict JSON. Deterministic code (no LLM) normalizes the grid, auto-tiles it into engine tilemaps, and validates it: A* or flood fill for connectivity, plus checks that the start, exit and required items are reachable. Failed layouts are sent back for regeneration.
- **Pitfalls:** LLMs miscount rows and columns and have weak spatial reasoning. Always validate. Never trust raw output.
- **Sources:** [OpenGame paper](https://arxiv.org/pdf/2604.18394), [Word2World paper](https://arxiv.org/pdf/2405.06686), [LLM dungeon maps with A* validation (Portuguese)](https://rd.uffs.edu.br/bitstream/prefix/9395/1/BOIN.pdf), [MarioGPT](https://neurips.cc/virtual/2023/poster/71191)

### F2. Agent ↔ engine via MCP  [documented]
- **What:** MCP servers let a coding agent drive the engine and Blender: create scenes and nodes, run the game, read errors, run tests and export. Review a server's code before enabling any tools that execute code or run the game.
- **Options:**
  - **Godot:** [Coding-Solo/godot-mcp](https://dev.co/ai/mcp/godot-mcp), [struktured-labs/godot-mcp](https://glama.ai/mcp/servers/@struktured-labs/godot-mcp)
  - **Unity:** [official MCP (beta, Unity 6+)](https://gamedev.net/news/4376-unity-ai-open-beta-how-to-get-started-with-mcp/), [Coplay MCP for Unity](https://glama.ai/mcp/servers/@CoplayDev/unity-mcp/blob/84f7b855e85e64c4b282f825dff85a9dad1bca9a/Server/README.md)
  - **Blender:** [Blender MCP](https://github.com/emeryporter/blender-mcp)
- **Working practice:**
  - Keep a short design doc and a CLAUDE.md in the repo.
  - Build in small, testable steps.
  - Commit after each working step.
  - **Source:** [roadmap.sh vibe coding tutorial](https://roadmap.sh/vibe-coding/tutorial)

### F3. Local LLM for in-game NPC dialogue  [documented]
- **What:** Run a small GGUF model locally via llama.cpp-based plugins, with no per-player API cost.
- **Practice:**
  - Stream output.
  - Keep replies short.
  - Constrain output (grammar or JSON schema) when the game must parse it.
  - Filter content: on Steam, you are responsible for what live-generated content shows players.
- **Sources:** [NobodyWho (Godot)](https://forum.godotengine.org/t/nobody-open-ended-dialogue-with-npcs-using-local-llms/78858), [LLMUnity](https://medium.com/data-science/how-to-use-llms-in-unity-308c9c0f637c)
- **From r/aigamedev:**
  - **In-browser models:** [CogentLM](https://www.npmjs.com/package/cogentlm) (MIT) runs small GGUF models inside web games ([thread](https://www.reddit.com/r/aigamedev/comments/1td2stx/)). The maintainer's suggested sizes:
    - about 1.2B parameters (LFM 2.5 or Qwen, Q4_K_M) for persona dialogue,
    - about 350M for fast, continuous decision-making,
    - roughly 200–400 MB downloads, cached after the first visit.
  - **Let the AI narrate a real simulation, not invent the world** (AI RPG lessons, [thread](https://www.reddit.com/r/aigamedev/comments/1t5aixp/)):
    - NPC beliefs, world state and skill-check consequences live in normal game data.
    - The LLM only narrates what that state says, so it can't invent a rope that isn't there.
    - Memory is layered: scene context, structured facts, and summaries of past events retrieved only when relevant.
- **From r/LocalLLaMA and r/ClaudeAI:**
  - **Two-model NPCs** (488 points, [thread](https://www.reddit.com/r/LocalLLaMA/comments/1s2ci9r/)):
    - A roleplay-tuned model writes the dialogue freely; it is never told it's in a game.
    - A tiny second model (e.g. Qwen 0.8B) with structured output reads each reply and maps it to the game's real action functions. Example: the NPC narrates firing back, so the game makes it shoot.
    - Give each NPC its lore from the game's wiki, plus live state (location, player HP) every turn.
  - **Keep the LLM to NPCs; keep game state deterministic.** Quests, story canon and world logic stay in normal code, so the AI can't break the game. One such RPG runs fully locally on an 8 GB GPU. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1wa84sa/))
  - **Generated things become persistent objects:** NPCs, places, items and quests the LLM invents are saved as real game objects you can meet again, revisit, equip and sell. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1u894z7/))
  - **Realtime voiced NPCs:** NPCTalk combined speech recognition (Nemotron ASR), dialogue (Qwen 27B) and cloned voices (Fish Audio) at under 1 second, self-hosted on a serverless GPU. ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xczjez/))
  - **Latency check:** one developer who bundled a local LLM in a Unity game found adding local TTS and translation pushed replies to 10–20 seconds, which broke the game. Budget time per exchange before adding layers. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1u0cpbm/))

### F4. Specialized sessions, a manager, and screenshots as the referee  [r/aigamedev, 639 points, Aug 2026]
- **What:** Run separate agent sessions per job (3D models, engine integration, critique). A "manager" session writes no code; it routes requests between sessions, and the human approves.
- **Rules:**
  - **Screenshots from the real game camera decide** whether a change is good, not how the asset looks in isolation.
  - **For big visual passes, write scoring criteria first.** Score items out of 10 and ship only at 8+. Use a critic session that sees screenshots without knowing which version is newer.
  - **Log every design decision with who made it** (human or AI), so AI suggestions aren't later mistaken for the human's choices.
  - **For hard visual targets** (e.g. a water shader), collect relevant shader write-ups as context, give a reference image per time of day, and iterate until it matches.
  - **Never let the builder judge its own quality.** Use separate critic subagents, especially for animation, where agents can iterate for hours. ([animation thread](https://www.reddit.com/r/aigamedev/comments/1x6unha/))
  - **The "gauntlet loop"** (a long autonomous run; [3D platformer thread](https://www.reddit.com/r/aigamedev/comments/1v9mbbe/)):
    - Set a goal, fan out subagents per item, and loop each item until a harsh critic subagent, comparing screenshots side by side and blind against a reference game, prefers ours.
    - Very token-hungry; it burned several 5-hour usage windows.
    - Only use it with the human's explicit go-ahead on cost.
  - **A non-coder's setup that turned their own drawings into a game** (Opus 5.5 + Godot, 6 weeks, 2,273 points; [thread](https://www.reddit.com/r/ClaudeAI/comments/1xdhkzb/)):
    - **Custom skills:** "route" sends simpler tasks to cheaper models while Opus reviews; "handoff" starts a fresh session with exactly the context needed; "re-searcher" checks research claims and stores the originals in notes, so knowledge doesn't decay into a summary of a summary.
    - **A dedicated art-direction skill:** every successful image prompt is saved as JSON, so each new asset starts from an established visual target.
    - **Documented VFX and shader layering,** so effects stay consistent as the project grows.
    - **One small feature at a time:** research, build, then test and adjust in the actual game before moving on.
  - **A 7-month, 2,500-commit setup for a commercial space strategy game** ([thread](https://www.reddit.com/r/ClaudeCode/comments/1x94ev1/)):
    - **Parallel sessions,** each in its own git worktree, with humans deciding every merge.
    - **A small ticket tracker** (also built with Claude) that the agent reads and writes through a CLI; testers file bugs there too.
    - **An MCP bridge into the running game:** the agent loads a save, reads the state, takes a screenshot and checks a fix for real.
    - **Headless AI-vs-AI batches** for balance.
    - **Memory notes for design rulings,** so a decision from August still holds in October.
    - **Scripted build, signing and Steam upload.**
    - "What still needs humans: what's fun, what's fair, and when it's done."
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1vrj2cl/), [before/after notes 1](https://claude.ai/code/artifact/1c9c24a7-129f-4ccb-b453-d7aed9e5c412), [before/after notes 2](https://claude.ai/code/artifact/2c524964-0cf4-43f6-bd4d-9fdffe04806e)

### F5. Give the agent the engine's source code  [r/aigamedev, 165 points, Jul 2026]
- **What:** Clone the engine repo locally (e.g. [Godot](https://github.com/godotengine/godot)) and add a line to CLAUDE.md with its path, saying the agent may consult it. The agent then checks what the engine actually does instead of relying on outdated docs.
- **Tips:**
  - Use a local clone, not GitHub links; browsing page by page explores far less.
  - The agent opens only the files it needs.
  - [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) can index the repo to save tokens.
  - In Unreal, a user had the agent find engine memory leaks this way.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1uuumle/)

### F6. Questions first, then a tightly scoped vertical slice  [r/aigamedev, 59 points, Oct 2026]
- **What:** A game design doc is the single source of truth. **Any gap you leave gets filled with the most generic assumption.**
- **Steps:**
  1. Attach the design doc to every session. The agent keeps it updated and logs each change.
  2. The agent reads it and asks up to about 8 grouped questions, each with a suggested default answer, then stops.
  3. Scope the slice explicitly: what to build (e.g. one area, one weapon, two enemies, one boss) and what not to build (XP, inventory, saves, cutscenes).
  4. No external art yet: draw everything in code from simple shapes and a fixed palette, to test the fun first.
  5. Deliver a full runnable project. The agent runs it and checks for errors first, adds headless screenshots, and lists what's in the build and what to test first.
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1x1yrzy/) (full prompt in the post), [video walkthrough](https://youtu.be/NNn10FiuZG8)
- **Related spec workflows** [r/aigamedev]:
  - **Spec, then phased designs, then an alignment check:**
    1. A product spec focused on features and outcomes (no implementation), produced through a Q&A loop.
    2. Separate implementation design docs per phase.
    3. A review pass checking the spec and design docs agree with each other in terms, models and use cases.
    - The poster uses the obra/superpowers skill set. ([thread](https://www.reddit.com/r/aigamedev/comments/1s9wjmb/))
  - **Detailed requirements doc plus one rough mockup screenshot** (Excalidraw boxes with text labels are enough), then "implement this end to end" for the first playable. Spend the following days making it fun. ([thread](https://www.reddit.com/r/aigamedev/comments/1rdkvhx/))
  - **Write concrete visual direction.** "Make it not look like AI slop" or "make it like that game" is too vague for the model to act on. Name colors, layout zones, references and constraints. ([UI critique-loop thread](https://www.reddit.com/r/aigamedev/comments/1sh3s7l/))
  - **For layouts that must stay put** (card hand, enemy slots, energy orbs), that thread found Nano Banana 2 followed placement constraints far better than FLUX.
- **Turning vague or chaotic input into games** [Hacker News, 1,106 points]: one developer let their dog type random keys into Claude Code, and it still produced playable Godot games. What made it work (each point applies to any loose, excitable direction):
  - **Frame the input explicitly.** Treat every message as a meaningful game idea from an eccentric designer, and find the intent.
  - **A fixed minimum checklist for every build:** working audio, WASD or arrow controls, at least one enemy or obstacle, and a visible player character.
  - **Automatic verification:** a screenshot tool to confirm it renders, an input-sequence tool so the agent plays its own game, linters for Godot scenes, shaders and input settings, and a winnability check (added after unwinnable games appeared).
  - **Watch persistent memory:** a project memory file can lock in one visual style. Clear or update it deliberately when you want variety.
  - **Godot's text scene files** were much easier for the agent than Unity's hierarchy through an MCP bridge.
  - ([write-up](https://www.calebleak.com/posts/dog-game/))

### F7. Make the agent prove it by playing  [r/aigamedev, 45 points, Jul 2026; poster built the MCP]
- **What:** An acceptance test the agent runs on itself, using simulated player input.
  - **Example:** in a minigolf game, a hole only counted as done when the agent sank the ball within par + 2 through the same input path a player uses. Failures meant redesigning the hole or retuning the physics.
- **Generalize it:** for every feature, define a pass bar the agent can check by actually playing: reach the exit, beat the enemy, finish under a time limit.
- **Pitfalls:** check that the agent doesn't "pass" by cheating, e.g. restarting when something breaks.
- **More ways to let the agent play** [r/aigamedev]:
  - **Browser games are easiest:** an agent with browser access can play the game, take screenshots, find bugs and fix them in the same loop. ([thread](https://www.reddit.com/r/aigamedev/comments/1s45kys/))
  - **Godot:** launch a single screen from the CLI with scripted scenarios (resolutions, enemy sets, specific cards), capture screenshots, and have a critic rate and iterate. ([thread](https://www.reddit.com/r/aigamedev/comments/1sh3s7l/))
- **Remember the limit:** "The model can write the system; a human still has to sit there bouncing balls until it feels right." Agent playtests catch bugs, not fun. ([pinball postmortem](https://www.reddit.com/r/aigamedev/comments/1t6k8cl/))
- **Playtest bots with personalities** [r/ClaudeAI]:
  - A capable model looks at a screenshot about once a second and sets a goal.
  - A small, fast model never sees the screen. It picks from options described in words ("walk to the silver feather 6m west, path clear") about 3 times a second, and an emulator presses the keys.
  - Run several bots with different personalities (impatient, competitive, explorative). They found stuck-in-wall bugs and frustrating spots.
  - Based on [rmalde/minecraft-agent](https://github.com/rmalde/minecraft-agent). ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xa4jp8/))
- **Make the game "legible" to the agent** [Hacker News]: design the game so an agent can see, drive and check it.
  - **From a game developer's harness guide** ([article](https://kylekukshtel.com/ai-harness-engineering-game-development-claude-code)):
    - **Determinism:** route all randomness through one seeded random number generator, and build save/load from the start, so any state can be recreated exactly.
    - **Commands:** express player and game actions as serializable "command" objects. The agent can write a script of commands in a text file and replay it against a running build to reproduce a bug, with no recompile.
    - **Data out of code:** keep balance and tuning numbers in data files, so changes don't need a rebuild.
    - **Simulation separate from rendering:** keep game logic in its own library, so it can be tested without the engine running.
    - **Visual checks:** take screenshots with toggles that hide unrelated UI and layers, crop to the area being changed, and diff before and after with [odiff](https://github.com/dmtrKovalenko/odiff), which gives a similarity score. Full-screen screenshots confuse the judgment.
    - **Profiling:** use text-output profilers the agent can read, such as [samply](https://github.com/mstange/samply).
  - **Text-state playtesting** ([write-up](https://blog.jeffschomay.com/letting-ai-play-my-game)):
    - A small wrapper runs the unmodified browser game and exposes it over local HTTP: an ASCII map plus text panels for state, and endpoints like `/key`.
    - The agent reads text, sends keys and reads the result. That is far cheaper and more reliable than screenshots for turn-based or text-heavy games.
    - Small **fixtures** load specific situations (e.g. a stronger hero, so the mechanic under test isn't skipped by dying).
    - The agent built, playtested and fixed a 5-encounter milestone in about 12 minutes. It found a trap that never cleared, but the human still caught "feel" issues.
- **Bots vs. real players** [r/ClaudeAI]: one multiplayer game's bots predicted the deadliest zone would lose about half its units; 219 real players lost 6% there, so the difficulty curve was upside down. Bots verify rules, not human behavior. The fix:
  - Turn design targets into numbers the game measures itself (19 targets on a dashboard).
  - Open the game to real players for a weekend at a time.
  - Let the agent iterate against the measured gap.
  - ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xedrvq/))
- **Sources:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1upf5z3/), [GodotIQ (poster's MCP)](http://godotiq.com), [GodotPrompter](https://github.com/jame581/GodotPrompter)

### F8. Many cheap prototypes to find the fun  [r/aigamedev, 326 points, Jul 2026]
- **What:** Before committing to one idea, build quick, rough browser prototypes (HTML + Three.js; aim for about 10) and test them constantly. Pick the one that's fun, then rebuild it properly in a full engine.
- **Process:**
  1. Core idea → look at similar games → simplify the core loop.
  2. Low-cost art and a rough prototype.
  3. Add systems, then swap generic content for authored content (e.g. voxel models in [Blockbench](https://www.blockbench.net/)).
  4. Polish only once it exists and is fun.
- **Source:** [Reddit post](https://www.reddit.com/r/aigamedev/comments/1v6zgzm/)

### F9. The agent runs the whole asset pipeline over MCP  [r/aigamedev]
- **What:** In one conversation, the coding agent:
  1. generates concept art in the exact target style (image API key),
  2. sends it to an image-to-3D service over MCP (e.g. Meshy MCP),
  3. converts the model to the engine's format,
  4. imports it into the project.
- **Lessons:**
  - Image-to-3D beats text-to-3D by a wide margin.
  - Commit to one style (e.g. rounded shapes, pastels, miniature diorama) so assets from different generations match.
  - Spend effort on the room or scene (lighting, walls, proportions) rather than individual props. Good art direction made average AI furniture look good.
  - Commenters recommended Tripo as an alternative to Meshy.
- **Example 3D pipeline:**
  - Midjourney or ChatGPT concepts → Meshy image-to-3D → Meshy and Mixamo rigging and animation → Blender weight fixes for equipment → Claude Code writes all code and VFX (shader fire, flipbook smoke, dissolve).
  - The poster's monthly tool cost was about $180.
  - Their tip: run /clear and /plan before every big feature, and paste deep-dive write-ups of the reference game's mechanics as context.
- **Sources:** [iPhone cozy game post](https://www.reddit.com/r/aigamedev/comments/1v0bb03/), [ARPG post](https://www.reddit.com/r/aigamedev/comments/1s72nx6/), [Godot MCP Pro](https://github.com/youichi-uda/godot-mcp-pro)

### F10. Pick a stack the agent can hold in its head  [r/aigamedev]
- **What:** Agents do best with a small engine API and code they can see all at once.
  - **Single-file games:** one developer shipped 50 games on [LittleJS](https://github.com/KilledByAPixel/LittleJS-AI), each one self-contained HTML file. The engine is tiny (rendering, physics, particles, ZzFX sound, input, tilemaps). The repo includes the CLAUDE.md, templates and prompts that made the agent productive, all MIT licensed. ([thread](https://www.reddit.com/r/aigamedev/comments/1tolm7y/))
  - **Godot works well with agents** because scenes and resources are plain text the agent can read and write.
  - **Unity needs a bridge.** Besides MCP, [Unity Bridge](https://github.com/ogulcancelik/unity-bridge) is a single C# file that runs an HTTP server in the editor with a self-describing `/api` schema. Any agent that can make HTTP requests can use it. ([thread](https://www.reddit.com/r/aigamedev/comments/1rnkvvq/))
  - **UI-heavy games** (idle, cards, turn-based): a web stack (e.g. Electron + React + TypeScript) iterates faster than a full game engine. ([thread](https://www.reddit.com/r/aigamedev/comments/1tsv5ha/))
- **Skill packs:** [threejs-game-skills](https://github.com/majidmanzarpour/threejs-game-skills), [GodotPrompter](https://github.com/jame581/GodotPrompter), [godot-create-3d-assets](https://github.com/LuigiDeFacci/godot-create-3d-assets), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (a combined pack with a router that picks the right skill for the task; [thread](https://www.reddit.com/r/ClaudeCode/comments/1uhi12p/)).
- **[godogen](https://github.com/htdt/godogen)** (MIT; 337 points on [Hacker News](https://news.ycombinator.com/item?id=47400868)): skills for Claude Code or Codex that build complete games in Godot (C# or GDScript), Bevy, Babylon.js or three.js.
  - **The loop:** build → generate assets → run the game → prove it. The agent judges from the running game (a live URL or a recorded clip), not from a clean compile, and finishes with a 15–20 second proof video.
  - **Assets:** local generation on an NVIDIA GPU (transparent images, textured 3D, rigged humanoids with animation and lip sync, SFX and voice), with paid APIs filling the gaps.
  - **Engine notes from its docs:**
    - C# type-checks everything before running, while GDScript bugs surface only at runtime.
    - Browser engines give a refreshable URL, which is handy for steering from a phone.
    - The web engines are 3D-first, so Godot suits 2D better.
- **Model choice:** one poster found Codex stronger at functional code and Claude stronger at visual work; another used Codex for the first build and Claude to make it fun. Treat these as anecdotes and test on your own project.

### F11. Architecture guardrails  [r/aigamedev]
- **What:** AI "will confidently generate beautiful-looking spaghetti in seconds." Set the architecture early, document the patterns, and reject changes that break them. One systems architect's setup ([thread](https://www.reddit.com/r/aigamedev/comments/1uigm1p/)):
  - simulation driven by JSON data,
  - isolated systems connected by a single event bus,
  - presentation separated from simulation,
  - moddable content,
  - every significant change reviewed.
- **Related habits:**
  - **Keep one regression scene** you (or the agent) click through after every big AI change. Agents quietly touch systems you didn't ask about. ([thread](https://www.reddit.com/r/aigamedev/comments/1v1kt7j/))
  - **When a conversation drifts,** start a fresh session with only the relevant files instead of trying to save it. ([thread](https://www.reddit.com/r/aigamedev/comments/1r22iyy/))
  - **Answer "is the simplest version fun?"** in a bare HTML prototype before building the full system. (same thread)

### F12. Have the AI build you "director" tools  [r/aigamedev, r/ClaudeAI, r/threejs]
- **What:** Instead of describing every tweak in chat, have the agent build small tools that let the human direct the game by looking, clicking and talking. This is especially valuable for humans who react better than they describe.
- **Examples:**
  - **Map or level editor:** an interactive map for placing items, built by Claude even on the free plan ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xf8tca/)). A pinball developer built an in-game table editor to drag, place and tune every part ([thread](https://www.reddit.com/r/aigamedev/comments/1t6k8cl/)).
  - **Natural-language scene director:** expose the game's look-and-feel settings (weather, lighting, sky, grass, fog, 50+ parameters) to an AI. "Make it rain," "golden hour" and "patchy grass" then change the right settings together. ([thread](https://www.reddit.com/r/threejs/comments/1wn9bl5/))
  - **Annotate-and-send viewers:** the human paints on the art or pins a note and sends it to the agent with the exact location (C9's asset skills).
  - **Tuning panels:** sliders for speed, gravity, spawn rates and difficulty, with a "copy values" button the human can paste back to the agent.
- **Rule of thumb:** if the human asks for the same kind of tweak more than twice, build them a tool for it.
- **"Directing by complaining" from a phone** [r/ClaudeCode; [thread](https://www.reddit.com/r/ClaudeCode/comments/1wxpk01/), [demo](https://relicsoftheancients.io/)]: one developer handed over an old design doc, then mostly played builds on their phone and complained ("the music gets repetitive," "too much on screen on a phone," "I should be able to knock buildings down"). Each complaint came back fixed within minutes. What made it work:
  - **A browser game, not a desktop engine.** The agent can run it, play it by script and screenshot its own work, and the human just refreshes a URL on their phone. (They had planned to use Godot and dropped it for this reason.)
  - **Rules separated from drawing,** so a test plays the entire mission in under a second.
  - **Everything in code:** sprites drawn on canvas, music generated live with WebAudio (the drums follow how many villagers are dancing), and the game deployed to its own URL.
  - **Limit:** the agent can't hear, so the human checks all sound. Ask about volume and mute settings before debugging "no audio."

### F13. AI as a game mechanic, not just a production tool  [r/LocalLLaMA, r/aigamedev, r/threejs]
- **What:** Some of the most original ideas use AI models inside the gameplay itself:
  - **Meaning-based scoring:** a card battler where players pick the card closest to a target like "better when wet." A reranker model (Qwen3-Reranker) scores the cards; it's cheap, fast and deterministic, and it also drives the CPU opponents. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1sr5rwz/))
  - **Infinite crafting:** a cooking game where any ingredient is possible; an LLM resolves the combinations and an image model draws the results. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1qkqjer/))
  - **Levels built from the player's own music:** an open-source rhythm runner ([Struna](https://github.com/Felliks/Struna), MIT) runs 4 small audio models in the browser (beat tracking, note transcription, vocal separation, pitch tracking). Obstacles land on beats, held notes become rails, and sung syllables become rings. It falls back to plain signal processing on weak devices, and the same song always builds the same level. ([thread](https://www.reddit.com/r/LocalLLaMA/comments/1xeia9o/))
  - **Voice-driven building:** the player talks to an AI "architect," and each answer builds the next floor of a tower. Duck the music while it listens so speech recognition works. ([thread](https://www.reddit.com/r/threejs/comments/1vldumv/))
  - **Prompt-a-spell:** players type any spell and the game generates its effect in a multiplayer 3D world. ([thread](https://www.reddit.com/r/aigamedev/comments/1t0dv5h/))
- **Pitfalls:**
  - Latency and cost per player action.
  - Moderating what players can make the AI generate (Steam holds you responsible, see Z3).
  - Keep deterministic fallbacks so the game still works when a model is slow or offline.

### F14. Remakes, remasters and mods: read the original, write a spec, rebuild  [r/ClaudeAI, r/ClaudeCode, r/vibecoding]
- **What:** Agents are very good at understanding an existing game from evidence, which opens remakes of your own old projects, fan remasters and mods.
- **Examples:**
  - **Reviving a 1992 online game:** with no surviving source code, Claude inferred the game's custom scripting language from hundreds of script files and a manual, then rebuilt 2,273 rooms, 297 monster types and 88 spells in a weekend. ([thread](https://www.reddit.com/r/ClaudeAI/comments/1sfsz67/), [code](https://github.com/jonradoff/lofp))
  - **Expanding a 1994 SNES baseball game** to all 30 MLB teams with a franchise mode that fits the cartridge's 8 KB save ([thread](https://www.reddit.com/r/ClaudeCode/comments/1x5ugqa/)):
    - **It needed eyes first:** the agent wrote a headless, deterministic emulator harness that presses buttons on given frames, screenshots, and logs memory, so every bug reproduces on the same frame.
    - **Every build must play four full CPU-vs-CPU games** to the end.
    - **Reverse engineering by evidence, not guesses:** log every place the code compares team-like values, then breakpoint them all.
  - **A 1982 Atari game turned into a spec, then rebuilt** ([thread](https://www.reddit.com/r/vibecoding/comments/1xbn2m5/)):
    1. Map what every byte of memory means by experiment.
    2. Rewrite the game as a model checked against the real game frame by frame (450,000 frames), deliberately breaking rules to prove the checks catch them.
    3. Write a plain-English spec, then build NES and SNES versions from it.
  - **[coop-anything](https://github.com/cranebeaker/coop-anything):** a shared repo where people's agents add co-op to single-player classics and contribute what they learn back. ([thread](https://www.reddit.com/r/ClaudeCode/comments/1x97tke/))
- **Pitfalls:** respect copyright. Remake your own games, or release mods and patches that require the player's own legal copy (as the SNES patch does), rather than redistributing someone else's game.

---

## Z. Baseline practices (apply to most projects)

### Z1. Clean up AI pixel art
- **What:** AI "pixel art" has inconsistent pixel sizes and hundreds of near-duplicate colors.
- **Cleanup pipeline:**
  1. Detect the pixel scale.
  2. Align to the grid.
  3. Downscale with nearest-neighbor.
  4. Quantize to a fixed project palette.
  5. Remove stray pixels.
- **Tools:** [Sprite Fusion pixel snapper](https://github.com/Hugo-Dz/spritefusion-pixel-snapper), [unfake (Python)](https://pypi.org/project/unfake/), [ComfyUI-PixelArt-Detector](https://github.com/dimtoneff/ComfyUI-PixelArt-Detector), [Tidy Pixel Art](https://phaser.io/tools/tidy-pixel-art)
- **Explainer:** [DEV article](https://dev.to/jenissimo/how-to-tame-your-ai-pixel-art-3pk5)
- **Why plain downscaling fails:** AI images contain "mixels", blocks that only look like pixels: they vary in size and color and drift across the image. The snapper finds the implied grid, reduces the palette with k-means, and snaps each cell to one color.
  - **Source:** [snapper breakdown, 154 points](https://www.reddit.com/r/aigamedev/comments/1usqu4s/)
  - **Harder cases:** some AI grids warp or have rectangular "pixels". One developer fits a warped grid to the true corners first ([thread](https://www.reddit.com/r/aigamedev/comments/1u9etqa/)).
  - **More tools:** [proper-pixel-art](https://github.com/KennethJAllen/proper-pixel-art), [pixel-pusher](https://github.com/wjhrdy/pixel-pusher), [PixelAid](https://oms1005.itch.io/pixelaid).
- **Constrain the model up front instead** [r/aigamedev]:
  - **Checkerboard reference:** attach a 16×16 checkerboard upscaled to 1024×1024, and prompt e.g. "a tiny 16x16 pixel art wizard, white background, follow the grid in the style-guide image." The output often lands on exactly 16×16. Finish with a grid detector.
    - **Source:** [post, 207 points](https://www.reddit.com/r/aigamedev/comments/1slkwdu/); poster runs SpriteCook.
  - **Match the model's output resolution when editing existing sprites:**
    1. Scale up by a whole number (96×96 → 960×960, 10×).
    2. Center it on a black 1024×1024 canvas and tell the model to leave the border alone.
    3. Edit.
    4. Crop and scale back down by the same factor, which also cleans small grid errors.
    - 64×64 sprites scale exactly 16× with no border.
    - Explicit rules guard against theme words biasing colors.
    - **Source:** [post, 143 points](https://www.reddit.com/r/aigamedev/comments/1pa9ygr/)
  - **Strict wording:** e.g. "32x32, pixel-perfect, grid-aligned pixels, sprite for pixel art game asset."
- **Quick retro look with no tool:** downscale to 25%, reduce to 12 colors, upscale 400% with nearest-neighbor.
- **Batch it:** have the agent run whole folders through the snapper and strip semi-transparent pixels.
- **More open-source cleanup tools** [r/aigamedev]:
  - [Pixelloid](https://github.com/Fulviuus/pixelloid): desktop app with grid detection, true 1:1 rebuild, background removal and a small pixel editor. ([thread](https://www.reddit.com/r/aigamedev/comments/1v5knqi/))
  - [Unfaker](https://jenissimo.itch.io/unfaker)
  - [pixeldetector](https://github.com/Astropulse/pixeldetector) ([thread](https://www.reddit.com/r/aigamedev/comments/1p5j2rc/))
  - [Pixel-Extractor](https://univeous.github.io/Pixel-Extractor/)
  - [pixel-perfect](https://pixel-perfect.zerofall.top) ([thread](https://www.reddit.com/r/aigamedev/comments/1u20ibf/))
- **Always finish by quantizing to a curated palette.** Experienced pixel artists spot near-duplicate colors immediately. (same thread)
- **True pixel art from an agent:** [Texel Studio](https://github.com/EYamanS/texel-studio) is an open-source agent that paints pixel by pixel on a real 16×16 or 32×32 canvas, using your palette and drawing tools instead of diffusion. ([thread](https://www.reddit.com/r/aigamedev/comments/1sb95eg/))

### Z2. Style consistency
- **Options:**
  - **Style LoRA:** trained on 10–30 curated, consistently styled images with a rare trigger token; test for overfitting.
  - **Edit a master image:** create one master character image and derive turnarounds, poses and expressions by editing it with an image-edit model.
- **Always:** Save prompts, seeds and settings, and run every asset through the same cleanup pass (outline, palette, shading).
- **More options** [r/comfyui]:
  - **Style transfer:** Tele Style LoRA with Qwen Image Edit 2509 was the most stable style-transfer combination one tester found.
  - **Quick style LoRA:** Z-Image's image-to-LoRA builds one from a handful of reference images. ([thread](https://www.reddit.com/r/comfyui/comments/1tmggdb/))
  - **Keeping edits from drifting:** image-edit models often shift pixels and colors, which breaks O1, B5 and E9. The [Flux.2 Klein Consistency LoRA](https://huggingface.co/lrzjason/Consistance_Edit_Lora) at 0.5–0.75, used with [ComfyUI-EditUtils](https://github.com/lrzjason/ComfyUI-EditUtils), is reported to eliminate the offset. ([thread](https://www.reddit.com/r/comfyui/comments/1rtkrej/))
- **Learning ComfyUI from scratch:** [beginner tutorials](https://aarsla.github.io/comfyui-tutorials/), built by a solo game dev with Claude: 16 tested workflows, each node explained. ([thread](https://www.reddit.com/r/comfyui/comments/1wu56py/))
- **ComfyUI now supports MCP,** so a coding agent can drive image and video workflows directly. ([thread](https://www.reddit.com/r/comfyui/comments/1uiwukh/))
- **Sources:** [Scenario – style LoRA](https://help.scenario.com/en/articles/training-a-style-lora), [Scenario – turnarounds](https://help.scenario.com/articles/1419523552-generate-character-turnarounds), [SpriteCook – consistency tips](https://www.spritecook.ai/blog/animating-sprite-sheets-tips-for-consistency)

### Z3. Store disclosure and legal
- **Steam (rules revised January 2026):** disclose AI-generated content players see (assets, store page, marketing) and AI generating content during gameplay. AI coding tools are exempt.
  - **Sources:** [VGC](https://videogameschronicle.com/news/valve-has-significantly-rewritten-steams-rules-for-how-developers-much-disclose-ai-use), [Promise Legal](https://blog.promise.legal/ai-game-assets-copyright-steam-disclosure-2026/)
- **US copyright:** purely prompt-generated images generally aren't copyrightable. Human selection, arrangement and modification can be. Encourage the human to edit key assets meaningfully.
  - **Source:** [Bloomberg Law](https://news.bloomberglaw.com/bloomberg-government-news/ai-assisted-works-eligible-for-protection-says-copyright-office)
- **Model licenses:** check each tool's license (e.g. some weights carry OpenRAIL terms; the ElevenLabs free plan needs attribution on music) before shipping.

### Z4. Audio
- **What:** ElevenLabs sound effects: text to clips of 0.1–30 s, with a looping option for ambience. Its FAQ states the sound effects are royalty-free for commercial use; music on the free plan needs attribution. Re-check the terms.
- **Source:** [ElevenLabs docs](https://elevenlabs.io/docs/product/sound-effects/overview)
- **Procedural audio written by the agent** [r/aigamedev]: no audio files at all.
  - [ZzFX](https://github.com/KilledByAPixel/ZzFX) generates every sound effect from a few parameters at startup; the agent tunes them through listening rounds with the human.
  - [Tone.js](https://tonejs.github.io/) and plain Web Audio cover music and effects in browser games.
  - **Sources:** [pinball postmortem](https://www.reddit.com/r/aigamedev/comments/1t6k8cl/), [one-week game workflow](https://www.reddit.com/r/aigamedev/comments/1rdkvhx/)
- **Music:** Suno was used for soundtrack tracks, with the agent writing the music prompts. Have the agent write image and music prompts too, not just code. (pinball postmortem)
- **Adaptive music in code** [r/ClaudeAI]:
  - **What:** generative scores synthesized live that react to play. Combos add layers (kick, then bass, claps, arpeggio, lead), a power-up brings the full arrangement, a crash muffles the music and drops the band for two bars, and the tempo climbs each level.
  - **How long:** the agent built it in about 30 minutes after the human said "let's just do it in code." ([thread](https://www.reddit.com/r/ClaudeAI/comments/1xbirxe/))
- **Open local game-music model** [r/StableDiffusion]: [Localsong](https://huggingface.co/Localsong/Localsong), an instrumental game-music generator (1.2B, includes a web UI). ([thread](https://www.reddit.com/r/StableDiffusion/comments/1vvn76h/))

### Z5. Pixel-art-specific generators
- **What:** PixelLab (skeleton posing, 4/8-direction rotation, tilesets; Aseprite plugin) and Retro Diffusion (Aseprite extension, one-time purchase, color reduction and palettes).
- **Sources:** [Cinevva comparison](https://app.cinevva.com/guides/ai-pixel-art-generators), [Retro Diffusion](https://astropulse.itch.io/retrodiffusion)

### Z6. Pre-launch checklist for AI-built games  [r/aigamedev, 153 points]
From a contractor who fixes vibe-coded games. These problems show up in nearly every project, because only one person ever tested the game:
1. **API keys and secrets in the client build.** Players can extract them in minutes.
2. **The server trusts the client** on score, currency or inventory. Validate on the server.
3. **No separation between player accounts.** Player A can read or overwrite player B's cloud save by changing an ID.
4. **No crash reporting.** Players don't report bugs; they uninstall. Basic crash logging takes about 20 minutes.
5. **Backups never test-restored.**
6. **In-app purchases that trust the client** on price or purchase state.
7. **AI side effects.** The agent quietly changes systems you didn't ask about, so keep a regression scene (F11).
- **Source:** [thread](https://www.reddit.com/r/aigamedev/comments/1v1kt7j/)
- **Multiplayer lessons** [r/vibecoding]:
  - Put the game logic on the server ("authoritative server") from day one; splitting single-player code later was painful.
  - Test with two browser windows side by side constantly, because desyncs hide otherwise.
  - Don't trust the AI with scale and units; check sizes yourself.
  - **Shrink AI 3D models:** a 40 MB Hunyuan model became 800 KB through low-poly remeshing in Blender.
  - ([thread](https://www.reddit.com/r/vibecoding/comments/1solbuj/))

### Z8. Shipping a browser game  [r/ClaudeCode, r/aigamedev, r/ClaudeAI]
- **Web portals:** itch.io (free, HTML5 upload) and CrazyGames. A Three.js game went through CrazyGames' "Basic Launch" evaluation and got 17K plays on its first day after full publication. ([thread](https://www.reddit.com/r/ClaudeCode/comments/1skf838/))
- **Steam:** wrap the web game as a desktop app with Tauri (lighter) or Electron. Several web-tech games ship on Steam this way. ([Tauri suggestion](https://www.reddit.com/r/aigamedev/comments/1s45kys/), [Electron + React game](https://www.reddit.com/r/aigamedev/comments/1tsv5ha/))
- **Mobile browsers:** test touch controls and memory limits early. WebGPU and heavy SVG filters are the usual problems (see C9).
- **Retro bonus:** [SpriteSwap Studio](https://github.com/lovisdotio/SpriteSwap-Studio) (open source, Windows) turns AI pixel art into a playable Game Boy / Game Boy Color ROM. It handles the hardware limits (4 colors, 256 tiles), animation, a scrolling background and sound. ([thread](https://www.reddit.com/r/StableDiffusion/comments/1q4pgaa/))

### Z7. Realistic expectations  [r/aigamedev]
Share these with the human early, so excitement survives contact with reality:
- **Hit rates and costs** (3 months of AI 3D, [thread](https://www.reddit.com/r/aigamedev/comments/1svicf5/)):
  - About 52% of 3D generations were usable; a 2D pixel-art developer reported about 30%.
  - Cleanup averaged about 15 minutes per asset (5 for props, 45 for characters needing retopology).
  - **Good at:** environment props, rocks, vegetation, organic shapes.
  - **Bad at:** specific character designs, mechanical parts, weapons (always too thin), and consistent style across many assets.
  - The real win is momentum: a needed prop is in-engine in 30 minutes.
- **Batch the art cleanup.** Generate, move on, and come back to fix art in a dedicated pass instead of constantly switching focus. (same thread)
- **One-prompt games are "10 miles wide and a centimeter deep."** Systems are easy now; making it good, unique and coherent is the real work. ([thread](https://www.reddit.com/r/aigamedev/comments/1utgoky/))
- **Design is the new bottleneck.**
  - AI builds whatever you specify, very fast, and first passes at game systems are shallow.
  - Expect several rounds of spec → test → refine per feature.
  - Quality control can't be delegated.
  - ([game-director thread](https://www.reddit.com/r/aigamedev/comments/1tsv5ha/))
- **Do a human touch pass:**
  - Fix missing fingers and nails and AI artifacts with inpainting.
  - Make sure backgrounds leave clean gameplay spaces.
  - Remove color casts ("the yellow filter").
  - The [Krita AI Diffusion plugin](https://github.com/Acly/krita-ai-diffusion) gives fine control (regional prompts, ControlNets, LoRAs).
  - ([before/after thread](https://www.reddit.com/r/aigamedev/comments/1o6im00/))
- **An experienced studio's view** [r/gamedev, 2,466 points; [thread](https://www.reddit.com/r/gamedev/comments/1wo5asm/)]:
  - A 30-year veteran reports about 5x faster Unity development since adopting AI with the Unity CLI.
  - Quality held up because experienced devs kept architecture and design decisions to themselves.
  - Downsides they list: less sense of accomplishment, harder estimates, and people learning less when they stop writing code.
  - Worth reading for balance.
- **Where you share matters.** Some communities (e.g. r/godot) are strongly against AI-generated games, and posts there draw backlash. Share in AI-friendly spaces (r/aigamedev, r/ClaudeAI, r/vibecoding, itch.io), and be upfront about how AI was used.
- **Cost data points:**
  - A browser permadeath ARPG reached 17,000 players after about $1,400 of AI spending over 3–4 weeks. ([thread](https://www.reddit.com/r/threejs/comments/1x76sfc/))
  - A backend developer passed Steam's review with a Unity game built in 10 days of evenings, after upgrading to a bigger Claude plan to stop hitting usage limits. ([thread](https://www.reddit.com/r/ClaudeAI/comments/1s7mfil/))
