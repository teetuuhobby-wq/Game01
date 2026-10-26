# 10x city experiment: look only, don't merge

This branch exists to *see* the scale of a much bigger walking city: the terraced
look test at 10x its area (265 x 177 m deck, 4 terraces, 736 houses, 168 residents).
The user asked for it in session 02 (2026-10-26) after Claude pushed back, as a
time-boxed experiment with "screenshots plus honest numbers" as the stopping point.

**Result:** it looks like a real city, but it's too heavy as is. On the work laptop it
runs at 6 FPS (the terraced test gets ~21), takes 33 s to start, and needs 2.7 GB of memory.
A playable version would need chunk streaming and distinct districts (Large).
The decision was to park it: the first playable toy (`game/` on `main`) uses the
terraced city, and the city size is revisited after walking around in it.

The full record is on `main`: `docs/STATUS.md` (Branches), `docs/DECISIONS.md`, and
`docs/screens/2026-10-26_city_scale_comparison.jpg`.

**To look at it:** double-click `run.bat` in this folder (keys 1-6 switch cameras, Esc quits).
Then go back with `git switch main`.
