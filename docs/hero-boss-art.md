# Character and boss artwork, 18 November 2026

The normal Start button opens the four-character picker. The selected character receives one rank of an existing card through the usual equipment dispatch. Retry keeps the selection and a new run applies its bonus once. Debug presets keep their own loadouts.

| Character | Starting card |
| --- | --- |
| 游方客 | pickup_up |
| 风信使 | speed_up |
| 机修师 | drone_up |
| 星灯学徒 | rune_bolt |

The four directional player sheets and eight boss sets live under `rogge_art/`. Each player selects authored left or right clips and uses ground displacement after collision for walking. Pure vertical travel keeps its last horizontal side. Boss sheets face right at rest. `boss_pose.gd` selects clips from the encounter state, measures actual travel for the approach stride and leaves locked attack facing with the encounter. Per-boss display scale and foot placement are defined at the pose binding. The 28 equipment and four beast-power icons use the same pack in combat and menus.

`tools/smoke_hero_art.gd` exercises the four selection paths, mobile/desktop layout, retry, starting cards, icon resources, and all eight boss skins. Companion tests cover player locomotion, locked warning geometry, terrain, the bestiary and localized card UI.

### Boss colors, trial visibility and mobile performance (2026-11-18)

Boss pose sheets now render their own RGB. Strength and Speed trials use the complete single-frame mechanical octopus and wizard textures, with their initial position clamped to the camera. The eight authored boss skins and both trial routes are covered by the art and trial smoke tests.

The opening reuses the fresh game behind the menu. Retry still starts a fresh world. Each spawner holds up to seven unused, off-tree shells and replenishes one per active frame. These shells have never entered combat. Ordinary authored walking poses follow distance directly. Touch devices draw projected enemy shadows for up to 16 actors. Stage-enter events use the periodic diagnostic flush. Blood decals submit only the initialized part of the ring buffer, and scenery updates when the visible decoration cells change.

Godot 4.7 headless, fixed 60 Hz simulation, median of five alternating runs against 1217a96. The table reports elapsed CPU-side wall time in ms. The crowd test keeps 96 living chasers for 120 complete simulation frames with collisions and weapons enabled. It excludes browser and GPU presentation.

| Measurement | 1217a96 | This build |
| --- | ---: | ---: |
| Hero confirmation to playable run | 15.144 | 3.875 |
| Stage-change callback, median | 1.671 | 0.697 |
| First five spawns | 0.376 | 0.276 |
| Crowd frame, median | 2.930 | 2.395 |
| Crowd frame, p95 | 4.161 | 3.675 |

Reproduce both revisions with the same absolute path to the new benchmark script. Supply a fresh user-data directory for each run.

```sh
XDG_DATA_HOME="$(mktemp -d)" godot --headless --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --path "$PROJECT" --script "$BENCHMARK"
```

The benchmark is in `tools/benchmark_combat_frames.gd`. Handset WebGL frame pacing still needs a physical-device playthrough.
