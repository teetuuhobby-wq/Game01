# Session 06: a build for a friend, playtest 4, quick fixes, the character look test, folders (home PC, 2026-10-29 to 10-31)

Cleaned transcript of a Claude Code session: the user's messages and Claude's replies.
Only the conversation is kept: Claude's final reply each turn, with no tool calls, tool output or system text.
Read it for *how the user thinks*: what they reacted to, what they picked, what they pushed back on.

This picks up the same conversation as session 05, right after the user's first account-switch message (2026-10-29). It ends with the switch to the user's main Claude account (2026-10-31); the reply to that is the docs and this file.

## 🧑 User

Can you build the game so that my friend can take a look?


### 🤖 Claude

(Asked: How strong is your friend's computer? Options: Don't know: start high (Recommended) / Gaming PC / Laptop / weak PC)


---

## 🧑 User (answering Claude's multiple-choice question)

Your questions have been answered: "How should your friend get the game?"="Windows zip (Recommended)", "Do you want your friend's feedback recorded?"="No recording", "How strong is your friend's computer?"="Don't know: start high (Recommended)".


### 🤖 Claude

The build for your friend is ready: **`builds/Strider Home.zip`** (59 MB, attached above). 🎉

**How to send it:** the zip is too big for most email, so use Discord, Google Drive, WeTransfer or similar. Your friend unzips it and double-clicks **`Strider Home.exe`**.
- Windows will probably say "Windows protected your PC", because the game isn't from a store. They click **More info**, then **Run anyway**.
- If it runs slowly, they press **F6**, or start it with **"Play (low quality).bat"** instead.
- The included README.txt explains all of this, plus the controls.

**What they'll get:** the game opens with the morning round (about 10 minutes, with Mira, Pip and the deliveries), and then they can roam freely. Your playtest tools are hidden (F2, F3 and the recorder), and a small tip under the clock says "Running slowly? Press F6 for low quality."

**What I fixed so it would work outside this PC:**
- **Sounds:** an exported game couldn't find the recorded sounds (crowd, creaks, wind…). They're now packed in as they are, and the build finds all 37.
- **Settings:** the F4/F5 settings now save to your friend's own user folder.
- **A crash when quitting:** testing the real build turned up a crash on quitting that only happens in exported builds. The game was making 42 people models "just to borrow their looks" and never cleaning them up. That's fixed, and the build now quits cleanly 5 times out of 5.

I tested the finished build hidden on your graphics card. It starts, plays its sounds, shows the round and the tip, and quits cleanly. All 17 test groups pass too.

**Next time you want a fresh build:** in PowerShell, from the project folder, run:
```powershell
& .\tools\export_build.ps1
```
The window title is now just "Strider Home". The zip stays only on this PC (the `builds/` folder isn't uploaded to GitHub), but the script and instructions are pushed, so the laptop or a new account can make one too.

When your friend has played it, tell me what they thought.


---

## 🧑 User

can you pull whatever the latest version is and remind me again about what this project is?


### 🤖 Claude

I pulled from GitHub and there was nothing new: this PC already has the latest version. Here's your reminder. 🏙️

## The game: **Strider Home**
You're **one ordinary resident of a giant walking city** that strides on six legs across a dangerous desert. The city is your cozy, safe home and the desert outside is scary. We're making it in Godot, with blocky voxel art built entirely from code. It's a hobby game for you and your friends.

**Why this game:** when we started, you picked three things you love:
1. **A safe home in a dangerous world**, and specifically a home that *moves*.
2. **Everyday life inside it.** You're just one resident, not the chosen hero.
3. **A big, earned payoff someday:** the underdog revealed as one of the strongest.

Plus one hard rule: **it has to look good.**

## What you can play now
Double-click `game/run.bat`:
- **The morning round** opens the game, about 10 minutes long. Mira asks you to help Pip with his deliveries:
  - ink for Sabeth at the Adventurers' Guild
  - lamp wicks for Pell at her store
  - a note for Dorran at the Kneeling Strider tavern (he gives you tea for Old Wendel)
  - soap for Tamsin at the Bathhouse
  - the tea up to Wendel on his lookout
  - then Bram's workshop, where you fix Mira's rain-catcher
- **Then evening:** the bell rings, the lamps glow, the market empties, the city kneels for the night, and Day 2 begins.
- **After that, free play:** a full day passes in 20 minutes, shops open and close, and residents walk to work and home. Press E to talk, read, sit and look, and T to skip an hour.
- **Recorded sounds** throughout, plus **F4** (sounds), **F5** (light and mood) and **F6** (low quality for weaker PCs).

## Where things stand
- **Current milestone, "A day in town":**
  - step 1 (the day) is built
  - the morning round is built
  - **step 2 is next:** a guild board with 3 everyday jobs
- **Combat is parked.** You chose town life instead, twice. Two combat test games wait on a side branch for whenever you want them.
- **A build for your friend** is in `builds/Strider Home.zip`, a Windows zip they unzip and double-click.
- **Health:** all 17 automatic test groups pass, and GitHub is in sync. A new Claude account or the laptop can pick everything up from the docs.

**Not done yet:** nobody has played the morning round or the full day. The newest playtest recordings on this PC are from October 26th. Playing it (with F2 for anything that feels off) is the most useful next step, unless your friend has already played and has something to tell you.


---

## 🧑 User

Play the round


### 🤖 Claude

The game is starting in its own window (it takes a few seconds to build the city). Have fun! 🎒

**Getting going:** click inside the window, then the mouse looks around. Follow the **gold diamond** and the line at the top of the screen. Press **E** to talk, read, sit and look. Scrolling all the way in puts you in first person.

**While you play:**
- **Press F2** whenever something feels off *or* great, and type a few words. The game records which stop you were at, so I'll know exactly where you were.
- T won't work during the round (the clock waits for you). It works again once evening comes.

**Things worth noticing:**
- **The people:** does each resident feel like their own person? Are the lines fun or flat?
- **The places:** which building do you like walking into most, and which feels empty?
- **The pace:** does the round drag anywhere, or feel too short?
- **The ending:** does the evening bell and the city kneeling feel like a good end to the day?
- **Sound:** I can't hear the game, so check that both bells (18:00 and the morning one) are audible and nothing is too loud.

When you've finished, close the game (Esc twice) and tell me, and I'll read your playtest and go through it with you.


---

## 🧑 User

Done playing


### 🤖 Claude

(Asked: Flag 2, 'increase the resolution of the characters': what part? (pick any) Options: Faces up close / Whole body too blocky / Clothes and detail / How they move)


---

## 🧑 User (answering Claude's multiple-choice question)

Your questions have been answered: "Flag 5, 'the navigation system needs work': what bugged you? (pick any)"="The directions,Spotting them on arrival,Getting around", "Flag 2, 'increase the resolution of the characters': what part? (pick any)"="Faces up close,Whole body too blocky,Clothes and detail".


### 🤖 Claude

Great playtest! You played **the whole thing in one go**: the round, the valve, the evening and into Day 2, in 6.6 minutes. That was 84% in first person, at about 240 FPS, and you never got stuck. You didn't flag anything about the round's story or length, so the guided tour itself seems to work.

Here's my read of your five flags:

**Quick fixes (small, about an afternoon together):**
1. **People stopping to stare at you.** Right now anyone within 2.5 m stops walking and looks at you. I'd have walkers **glance as they pass** and keep going.
2. **Conversations never ending.** With Old Wendel the lines just loop forever. I'd make **E close the conversation after the last line**, and talking again starts from the top.
3. **A volume slider.** F4 is really a developer tool. I'd add an **Esc menu** with Resume, Volume, Quality and Quit. That also stops pressing Esc twice from quitting by accident.

**Navigation (small to medium):** you said three things bugged you: the compass directions, spotting the person when you arrive, and getting around. The log backs this up: you walked straight to Bram's in 20 seconds, then stood 6 m away from him for 15 seconds. My suggestion:
- a **glowing trail on the ground** showing the way, which also helps with stairs and "which street?"
- **landmark words** like "in the tavern" instead of "45 m south"
- the person you're looking for **lit up** when you're close

**Characters (medium, needs a test first):** you said faces up close, blocky bodies, and plain clothes. That's your "it has to look good" worry again, and it makes sense: you talk to people face to face. People are currently built from 20 cm blocks. I'd do a **look test first**: rebuild three residents (say Dorran, Tamsin and Pip) at **double the resolution** and show them next to today's versions. Then you decide whether it's worth converting everyone. That would also show the effect on the laptop's speed.

My recommendation is the **quick fixes first**. They're small, they make the town feel natural, and they keep momentum. Then the character look test, since that's the biggest worry, then navigation.

I also spotted one thing for me: the recorder's automatic "camera jumped" flags fire constantly in first person, which is just noise. I'll fix it alongside the next change.

The playtest notes are saved in STATUS, IDEAS and TASTE and pushed, so the laptop and any new session know what you found.


---

## 🧑 User

Quick fixes first


### 🤖 Claude

All three quick fixes from your playtest are done and pushed to GitHub. ✅

1. **No more staring.** Neighbours walking round the plaza and terraces keep walking past you. They only pause if you're standing right in their path, so they don't walk through you. People already standing about just glance at you. The named residents still turn to face you when you come close, since you go to them to talk.
2. **Conversations end.** After someone's last line, the hint says **"E: goodbye"**. The next E closes the conversation, and talking to them again starts from their first line.
3. **An Esc menu** (screenshot above). **Esc** pauses the game and opens it:
   - **Resume** (or Esc again)
   - **Volume**, which is remembered next time you play
   - **Quality** high/low, the same as F6
   - **Quit**

   Pressing Esc twice no longer quits by accident.

**Also:**
- The automatic "camera jumped" alarms no longer fire constantly in first person, so your next playtest log will be cleaner.
- The key hints along the bottom now fit on the screen.
- **Your friend's zip is rebuilt** with all of this (`builds/Strider Home.zip`), and its README mentions the Esc menu.

**Checked:**
- A new test covers all three fixes: neighbours walk past, conversations end, and the menu pauses the game and changes the volume.
- One older test assumed you could keep pressing E on a one-line conversation. I updated it to match the new goodbye rule.
- All 18 test groups pass (145 checks), and the rebuilt friend version quits cleanly.

Next on the list is the **character look test**: three residents rebuilt at double resolution, side by side with today's, so you can decide whether it's worth converting everyone.


---

## 🧑 User

Regarding the character look test can you go into detail on what you plan to do?


### 🤖 Claude

Here's the plan in detail.

## The goal
Answer one question before rebuilding 400+ people: **does doubling the detail fix what bugged you, and does it still fit the town?** You decide by looking at screenshots side by side, not by reading.

## Why people look crude today
Everyone is built from **20 cm blocks**: 9 blocks tall, 3 wide. A whole face is a **3 × 3 grid**: two dark blocks for eyes, one for the mouth, and a single block of nose. Up close at the bar, Dorran's whole face is nine big squares. That's your flag.

## What I'd build (on a side branch, so the game isn't touched)
I'd rebuild three residents, chosen because each tests something different:
- **Dorran:** a big face, beard, bald head, belly and apron, tested face to face at the bar.
- **Tamsin:** long hair, a dress, and the towel on her head.
- **Pip:** a kid, with a cap and satchel, testing small size.

Each in **three versions**, standing side by side:

| | Blocks | Face | What changes |
|---|---|---|---|
| **A. Today's** | 20 cm | 3 × 3 | Nothing, for comparison |
| **B. Double detail** | 10 cm | about 6 × 6 | Eyes with whites, eyebrows, a real nose and mouth, ears. Hair with a fringe and real shape. Collars, buttons, sleeves, belts, shoe tips, apron straps. Same proportions as today. |
| **C. Double detail, cuter** | 10 cm | about 8 × 8 | Same detail as B, but a slightly bigger head and shorter body, like the small cozy people in Town to City. The face reads better from a distance. |

## The four camera shots for each version
1. **Face to face across the bar, in first person.** The exact moment you flagged.
2. **Full body at 3 m**, to judge outfits and proportions.
3. **On the market street, over the shoulder**, mixed into the crowd. This checks whether finer people **clash with the 20 cm buildings**. That's the main risk: they could look like they belong in a different game.
4. **Zoomed-out diorama view**, to check whether the extra detail turns into noise from far away.

## Also measured
- **Speed:** detailed people have roughly 4× more visible block faces. I'd measure FPS on this PC with a full market crowd, estimate the laptop from that, and note how low quality (F6) helps.
- **A separate critic:** another agent scores the screenshots for appeal, how readable the faces are, and style match with the buildings. I won't grade my own work. Only you decide what you like, though.

## What you'd get
One screenshot sheet comparing A, B and C in all four shots, the critic's notes, and the FPS numbers. Then you pick A, B or C (or "B's faces with C's body"), and tell me what part you like.

## Size and cost
- **The look test:** about one session (Small–Medium). Only free tools.
- **If you like B or C, converting everyone comes after** (Medium, a few sessions). That covers all the random townsfolk, sitting and soaking poses, kids, props, hats and carried crates, plus the tests.

## Honest risks
- **Style clash** with the buildings: shot 3 is there to catch exactly that.
- **Speed on the laptop**, which is the weaker machine.
- If neither B nor C looks good enough, there are bigger routes, like characters modelled in Blender or AI concept art to guide the design. I'd only suggest those if this test falls short.


---

## 🧑 User

Go, as planned


### 🤖 Claude

The character look test is done; the two comparison sheets are above. In every row, the left image is **A** (today's people), the middle is **B** (double detail, same proportions) and the right is **C** (double detail, cuter, with a bigger head).

**What changes in B and C:** real eyes with a sparkle, brows, a nose, a mouth, ears and a filled-in beard. The clothes get collars, belt buckles, button plackets, Dorran's apron with shoulder straps, Pip's cap brim and satchel strap, and Tamsin's towel. Today's faces are just two dark bars.

**Speed: not a problem.** I converted *everyone* in town (287 people) to each version and measured on this PC:
- **B:** costs 1–4% of the frame rate.
- **C:** costs 4–10% of the frame rate.

People are a small part of what the graphics card draws next to the city itself, so the laptop should feel about the same too.

**The separate critic's scores** (faces / clothes / fit with the town / overall), after one round of fixes from its notes:

| | Faces | Clothes | Fits the town | Overall |
|---|---|---|---|---|
| A today | 2 | 4 | 8 | 4 |
| **B double** | 6 | **8** | **7** | **7** |
| C cuter | **7** | 6 | 5 | **7** |

**Its recommendation:** B's body and clothes, with a head one block bigger. B fits the town and today's crowd; C's faces read best, but mostly because its bigger head gives the face more room. C also looks a bit childish next to the crowd, and in first person its face sits low enough that the bar's tap hides Dorran's mouth.

**Still not right in either:**
- The small dark-red mouths read as a startled "oh!".
- The brows sit right on top of the eyes.
- Up close, the "E: talk to …" prompt and the gold marker land on the person's face. That's a small fix to the game's interface, separate from this test.

I stopped after one fix round as planned, because the choice between these is yours. Nothing in the game has changed: the look test lives on its own branch, `experiment/people-hd`, and the results are saved in the docs and pushed. Once you pick, the next step would be converting everyone (a few sessions), or a quick extra round to try the critic's B-with-a-bigger-head first.


---

## 🧑 User

C looks better, but the head is too big. Can you adjust it more?


### 🤖 Claude

I made two smaller-head versions of C. The comparison sheets are above, with **C, D, E** left to right in every row:

| | Head | Head as share of height | Feel |
|---|---|---|---|
| **C** (before) | 8 × 8 blocks | 47% | Cutest, most "toy-like" |
| **D** | 7 × 7 blocks | 39% | Still cute, a bit more grown-up |
| **E** | 7 × 7, longer body | 35% | Closest to normal proportions, keeps C's face |

**What else changed:**
- **A little smile** on all three, instead of the dark-red "oh!" mouth that made everyone look startled.
- With a 7-block head there's a true centre block, so the smile and nose sit dead centre.
- **Across the bar in first person,** D's and E's faces now sit fully above the counter. C's face was partly hidden behind the tap, which the critic had flagged.
- **In the street shots,** D and E sit a bit more naturally among today's crowd, while C still reads as a separate cartoon style.

**My read:** D keeps most of what you liked about C and fixes the bar framing. E is the safer fit with the rest of the town. Both cost about the same speed as C (a few percent).

Nothing in the game itself has changed yet. Everything is on the look-test branch, and the sheets and notes are saved on `main`. If you want a size between these, or a different body length, say so and I'll tweak it.


---

## 🧑 User

Can you make another version with increased resolution?


### 🤖 Claude

(Asked: How much finer should the blocks be? Options: 5 cm blocks (Recommended) / Somewhere between)


---

## 🧑 User (answering Claude's multiple-choice question)

The user answered: "Which version should the higher-resolution one be based on?"="Try multiple different methods so we can compare everything.", "How much finer should the blocks be?"="Same as before. Try multiple different versions so we can compare it all.". Read the answers carefully — they may request clarification, changes, or that you not proceed — and follow what they actually say.


### 🤖 Claude

I made six versions using three different ways of adding resolution. The sheets are above, all in the same order: **top row D, C5, D5; bottom row E5, D5h, Dp.**

| Version | How | What it looks like |
|---|---|---|
| **D** | 10 cm blocks (the last round) | Reference |
| **C5** | 5 cm blocks everywhere, big head | Cutest faces, but the big head you said was too big |
| **D5** | 5 cm blocks everywhere, medium head | Eyes with an iris and highlights, thin brows, a curved smile, a tiny nose, textured hair, rounded heads |
| **E5** | Same as D5, longer body | The most "grown-up"; faces sit nicely above the bar in first person |
| **D5h** | **5 cm head only**, normal 10 cm body | Looks the same as D5 on screen |
| **Dp** | 10 cm head with the face **painted on** as a sharp picture | Very crisp, anime-like eyes, but looks like stickers on blocks |

**The critic's scores** (faces / clothes / fit with the town / overall):

| D | C5 | **D5** | **E5** | **D5h** | Dp |
|---|---|---|---|---|---|
| 5/6/7/5 | 9/6/5/7 | **8/7/7/8** | **8/7/7/8** | **8/7/7/8** | 8/6/4/6 |

Its pick is **D5h**. It keeps the cute face you liked on a head that isn't too big, and the extra body detail in D5 never shows. **E5** is its close second.

After its notes I did one fix round:
- smiles now have a flat bottom and raised corners, so they no longer read as a pout
- Tamsin's fringe no longer hides one brow, and her long hair now frames her face
- E5's long dress got a stripe
- the painted version no longer draws brows on top of the hair

**Speed is fine:** in first person the finer versions cost 0–10% of the frame rate. The worst spot (zoomed out over a crowded plaza) drops from 282 to about 230–250 FPS on your PC.

**One important point from the critic:** whichever version you pick, the whole crowd should be converted too. Otherwise the detailed residents look pasted in next to today's blocky people (you can see it in the street shots).

Nothing in the game has changed yet. Everything is on the look-test branch, with the sheets and notes saved on `main`.


---

## 🧑 User

To be honest none of the characters look that nice to me.. Is there anything in the techniques document that might help? Do you have any suggestions?


### 🤖 Claude

Thanks for being honest, that's the most useful feedback you can give me. I agree with you, and I think I know why.

**My read:** the problem isn't resolution, it's design. In all five rounds I designed faces in code with no target picture of what "nice" looks like, then you told me what was wrong. The techniques doc says the same thing in its "realistic expectations" section: AI is *bad at specific character designs*, and *design is the real bottleneck*. Finer blocks just made the same design sharper.

**What the techniques doc offers** (all saved to `docs/IDEAS.md`):

1. **Concept art first, then build to match** (C8/C9 with a target). Small, and free if you have an image tool.
   - I write prompts for 4–6 different looks of the same three residents:
     - chunky voxel figurines like Town to City
     - smooth toy figures
     - low-poly flat-shaded
     - cute painted 2D
   - You make them in Nano Banana Pro (the Gemini app) and paste them back.
   - You pick by reacting, which is what you're best at. Then I rebuild the winner to match a real picture instead of guessing.
2. **Smooth toy-figure people, built in code** (C9: rounded capsules and spheres, soft cartoon shading, painted faces, no blocks for people). Medium, free. It's a different look from blocks, and the doc points to people building nice creatures this way. It would still be me designing without a target, though.
3. **AI 3D models with real animation** (C1/F9): a concept picture becomes a 3D model (Meshy or Tripo, about $20/month, inside your budget; I'd ask before any sign-up), then gets auto-rigged so people actually walk with swinging arms.
   - Biggest jump in quality, but Large.
   - The doc warns AI 3D gets about half of characters usable, and each needs cleanup.
   - Matching the blocky town takes care.
4. **2D characters in the 3D town** (like Octopath Traveler's look; E1, C7): flat painted characters standing in the voxel world. Faces can look great, since 2D is where image AI shines. But it's a style change, and each character needs drawings from 8 directions. Medium–Large.

**My recommendation: start with route 1.** It's cheap and fast. It answers "what does *nice* mean to you?" before we spend real effort, and it tells us which of routes 2–4 can actually reach that look. The one thing I need to know is whether you can use Nano Banana Pro. That's been an open question since the first session, and I can't make images myself.

Your verdict, my read and these four routes are saved in the docs (STATUS, IDEAS and TASTE) and pushed. The game itself hasn't changed, and the look-test branch stays as a record.


---

## 🧑 User

I do have access to Nano Banana Pro and I have actually previously made some character sheets with it from another project. I copied it into the folder so take a look and see if it's helpful.


### 🤖 Claude

I looked at all seven images: the hero shot, the five-view turnaround, the six expressions, the outfit details, the hood-down heads and the rifle. Two big takeaways.

**1. This shows what "nice" means to you, and it's anime.** Clean outlines, flat cel shading, big expressive eyes, and a design with personality: the wolf-eared hood, the plaid, the little wolf pendant. That fits the other things you love, since Chrono Ark and Chrome Shelled Regios are both anime. It also explains why none of my test characters worked. Building faces from blocks can't reach this level, however fine the blocks get. **Is that right: is it the anime look you like?**

**2. You already know how to make exactly the input every route needs.** A turnaround (front, side, back) is the best possible starting point for turning a character into 3D, and an expression sheet is exactly what dialogue portraits need. You did the hard part of a real art pipeline in another project.

**How I'd use this, smallest first:**
- **Anime portraits in the talk panel** (Small–Medium). This is my pick.
  - When you talk to Dorran, his portrait appears beside the text, with an expression that fits the line, as in Stardew Valley, Octopath or Fire Emblem.
  - Your flag was about faces *up close while talking*. This puts the best-looking face exactly where you look at faces.
  - You make the images in Nano Banana Pro (free with your access), from prompts I write to keep all eight residents in one consistent style. I crop, frame and wire them in.
  - The people walking around can stay simple for now.
- **Anime 3D characters in the block town** (Large).
  - Think Dragon Quest Builders: cute, outlined, cel-shaded people in a block world. That game proves the mix can look good.
  - A turnaround sheet goes through an image-to-3D tool, then gets rigged for real walking.
  - It needs a paid tool (Meshy or Tripo, about $20/month; I'd ask before any sign-up) or a fiddly local setup on your AMD card.
  - The techniques doc warns that only about half of AI 3D characters come out usable.
- **2D anime characters standing in the 3D town.** Beautiful faces, but a style shift, and each resident needs drawings from several directions.

I'd start with the portraits. They're cheap, you'd see results fast, and the same prompts and style become the reference later if we go for 3D characters.

**Two small notes:**
- I haven't added `Character_Reference/` to the project's git yet, because it's 37 MB. If we use it, I'd store smaller copies plus the prompts in the repo.
- The rifle and the hunter look belong to your other project. I'd make new designs for Strider Home's residents in the same *style*, rather than reuse her.


---

## 🧑 User

I want to focus on fixing the character models rather then just simply adding portraits to them.


### 🤖 Claude

(Asked: What body proportions should the residents have? Options: Let me compare (Recommended) / Cute anime (~4.5 heads) / Like my sheet (~7 heads))


---

## 🧑 User (answering Claude's multiple-choice question)

The user answered: "Which ways of making the 3D models should we try (we'd compare them in the town, like before)?"="Perhaps we should look into online voxel game assets,Built by script (Recommended)", "What body proportions should the residents have?"="Let me compare (Recommended)". Read the answers carefully — they may request clarification, changes, or that you not proceed — and follow what they actually say.


### 🤖 Claude

Both tracks are set up.

## 1. Ready-made characters online
Three free packs are worth trying, each in a different style:

| Pack | Style | What you get | Licence | Price |
|---|---|---|---|---|
| **[Voxel Village](https://the-voxel-store.itch.io/voxel-village)** | Voxel (blocks), the closest match to our town | **10 townsfolk**: bar landlord, barmaid, butcher, chef, jeweller, market woman, old man and woman, young man and woman. **Rigged and animated** | Free for any game, credit optional | Name your price (can be $0) |
| **[KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers)** | Cute rounded low-poly, not blocks | 5 adventurers in the free tier (knight, mage, rogue, ranger, barbarian). **Rigged and animated** | CC0 (free for anything) | Free, extras optional |
| **[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)** | Simple blocky people | About 20 files | CC0 | Free |

Also found, but weaker: [Voxel Characters by Sorceress Game Lab](https://sorceressgamelab.itch.io/voxel-characters) (14 voxel people, but not animated).

**Honest expectations:**
- These are generic voxel or low-poly styles, not anime. They'll show whether a *professional* voxel or cute style looks better than mine.
- Voxel Village has exactly the kind of people a town needs (a barmaid, a landlord, a market woman), and it moves.
- If one wins, we'd recolour or adapt it to make our own residents.

**To download:** on the itch.io pages, enter $0 (or tip) and click Download. Put the zips in a new folder, `Character_Reference/packs/`. I'll unpack them, bring them into Godot, and shoot them in the town with the same camera shots as before.

## 2. Built by script, from your concept art
The prompts are in **[art/prompts/residents_proportions.md](art/prompts/residents_proportions.md)**. Paste each into Nano Banana Pro:
- **Tamsin** (bath attendant) and **Dorran** (barkeep), each shown **three times side by side**: chibi (about 3 heads tall), cute anime (about 4.5), and anime adult (about 7, like your hooded character).
- Same clean anime cel shading and outlines as your sheet, with simple shapes that will work as a 3D model.
- Save the results in `Character_Reference/strider/`.

Once you pick a proportion, I'll write the prompt for a full turnaround (front, side, back) and build the first resident by script in Blender to match it.

I've kept `Character_Reference/` out of git because the files are large; small copies go into the project when we use them. The prompts are saved and pushed.

Sources:
- [Voxel Village](https://the-voxel-store.itch.io/voxel-village)
- [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers)
- [Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)
- [Sorceress Game Lab Voxel Characters](https://sorceressgamelab.itch.io/voxel-characters)
- [Godot asset library: KayKit Adventurers](https://Godotengine.org/asset-library/asset/2129)
- [Cinevva free rigged characters guide](https://app.cinevva.com/guides/free-rigged-3d-character-models)
- [OpenGameArt: blocky characters](https://opengameart.org/content/blocky-characters)


---

## 🧑 User

All three


### 🤖 Claude

Great, we'll try all three. I made the folders. Here's what to download (exact links):

1. **[Voxel Village](https://the-voxel-store.itch.io/voxel-village)**: click **Download Now**, type **0** (or a tip), then **"No thanks, just take me to the downloads"**, and download the file.
2. **[KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers)**: the same steps, and pick the **free** version.
3. **[Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters)**: click **Download**, then **"Continue without donating"**.

Put all three zips in **`Character_Reference/packs/`**, as they are, no need to unzip. Then tell me, and I'll:
- unpack them and bring the models into Godot
- swap Dorran, Tamsin and Pip for the closest-matching characters from each pack (for example Voxel Village's bar landlord as Dorran)
- shoot them with the same camera shots as before (across the bar, faces, full length, in the market crowd) and show you the comparison sheets

Whenever you have time, run the Nano Banana prompts in [art/prompts/residents_proportions.md](art/prompts/residents_proportions.md) too, and save the images in **`Character_Reference/strider/`**. That's the other track, a model built by script from your own concept art.


---

## 🧑 User

They're in. You should probably reorganize the folders while you look.


### 🤖 Claude

You've hit your session limit · resets 7pm (America/Chicago)


---

## 🧑 User

I hit my usage limit while you were working, but it has reset now. Please continue from where you left off.


### 🤖 Claude

All three packs are in the town, cast as Pip, Tamsin and Dorran next to our best code version, D5h. The sheets are above, in the same order every time: **top left ours (D5h), top right Voxel Village, bottom left KayKit, bottom right Kenney.** The last sheet shows each pack's whole cast.

**What each one is like:**
- **Voxel Village:** made of blocks like our town, but drawn **without arms or legs**, with floating hands and feet like Rayman. That's the pack's design, not a bug. Faces are plain.
- **KayKit:** rounded, polished, cute low-poly people with real sculpted faces. The most "professional" looking, but not blocky, so they stand out from the town. The free pack is fantasy adventurers only (knight, mage, ranger, barbarian), not townsfolk.
- **Kenney:** Minecraft-like blocky bodies with cheerful printed faces. Clean, readable, and they fit the block town naturally.

**Two things worth knowing:**
- **All three come with real animations** (idle, walk and more), so they'd move like people. Our own characters just slide around.
- **Kenney's face and clothes are a painted picture wrapped onto the body**, like a Minecraft skin. So we could paint *our own* residents onto Kenney's bodies, Dorran and Tamsin included, even with an anime-style face drawn from your Nano Banana art. That keeps the blocky town look and gives us the faces and animation for free. To me that's the most promising mix, but it's your call.

**Also done:**
- **Folders reorganized:** everything big from outside now lives in **`originals/`** (not uploaded to GitHub): `audio/` for the sound downloads, `packs/` for these three packs, and `characters/` for your reference images (`npc_1_other_project/`, plus `strider/` for new Nano Banana images). The README now lists every folder.
- I fixed two of my own mistakes along the way: Voxel Village standing upside down, and the wrong Kenney characters cast at first.

Everything is pushed. The look test lives on its branch, `experiment/people-hd`, with credits for the three packs (all free to use in our game). The real game hasn't changed.


---

## 🧑 User

Can you tell me what you did with the assets? Did you use them as it is or did you modify them slightly?


### 🤖 Claude

I used them **as they are**. I didn't change any of the art. I only did the minimum needed to make them stand properly in our town.

**The files:**
- The originals in `originals/packs/` are untouched.
- I copied only the character models, their textures and their animations into the look test's folder (`game/tests/look_packs/` on the test branch). Godot then made its own internal copies to read them, which doesn't change the files.
- I didn't edit any model or texture file.

**What the test scene does to them when it loads them** (in code, not to the files):
- **Turned** them 90°, because our people face a different direction from the packs' models.
- **Sized** them evenly to 1.75 m tall (Pip 1.25 m, as a kid), and put their feet on the ground. Proportions are unchanged; each model is just scaled up or down as a whole.
- **Voxel Village's textures:** its model files point to a texture the pack doesn't include, so I gave each character its own texture from the pack (the barmaid's on the barmaid, and so on). I set them to show as sharp pixels rather than blurred.
- **Animation:** each plays its own pack's idle animation, unchanged. Kenney's is built into its models. KayKit's and Voxel Village's come from the separate animation files in their packs.

**Not changed:** colours, faces, clothes, shapes, materials. KayKit's and Kenney's look exactly as their makers made them. Only the lighting is ours, because they're standing in our town.

**One correction:** at one point I briefly removed part of Voxel Village's animation, thinking it was broken. Their floating hands and feet are actually the pack's design. I put it back, so what you saw in the final shots is the original animation.

All three licences allow changes (recolours, new textures and so on), so if we pick one, adapting it into our own residents is allowed. The Kenney "paint our own skins" idea would be exactly that kind of change.


---

## 🧑 User

I am planning on switching Claude accounts to use my main account which has much bigger usage limits. Can you make sure everything is documented and up to date on GitHub?

