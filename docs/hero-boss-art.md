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
