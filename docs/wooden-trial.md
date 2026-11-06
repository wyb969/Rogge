# Wooden Dummy challenge and equipment HUD

## Progression and rules

The real route after the fourth beast is now: claim blessing → Speed Trial → its result →
Wooden Dummy explanation → 60 seconds of stationary survival → result → settlement/free play.
Speed success and explicit abandonment both lead to the new explanation. The Speed result
no longer offers a shortcut to settlement. Power Trial progression is unchanged.

The user confirmed “tides” means waves of enemies, not water attacks. Automatic weapons,
owned passives and all earned divine powers remain available. The movement and DASH controls
are hidden, and `Player.movement_locked` also blocks keyboard, joystick, direct dash calls and
cooldown callbacks. A stored world position prevents drift. Passive regeneration and damage
processing continue. Entering the challenge cancels any old dash/grace period.

The explanation is paused and does not count toward the minute. Start/Retry fully heal the
player. The counter uses the existing trial real-time convention, excluding pause and explaining
screens. Only a living player at or beyond 60 seconds passes; killing enemies cannot end it early.
Success, failure, end_game, return home and new runs release the movement lock and clear the crowd.
Failure offers Retry or explicit abandonment; abandonment records `passed=false`.

Debug → **木头人挑战 · 60秒怪潮** opens the explanation with the existing final-trial test build:
level12, axe2, book1, gun6, extra HP and all four divine powers. This is test equipment only.

## Bounded wave controller

`Trials` owns `wooden_trial.gd`; the normal Spawner timers are stopped. The controller reuses
ordinary EnemyShell scenes and two existing chaser appearances, their damage APIs and kill rewards.
Necklace orbs, kill shield, XP and card effects follow the normal paths. Drafts wait until the trial
unblocks rewards. Owned cards and powers are retained on Retry and stage continuation.

| Active seconds | Alive cap | Batch / interval | HP (normal) | Contact hit | Speed |
| --- | --- | --- | --- | --- | --- |
| 0–20 | 32 | 2 / 0.55s | 270 | 14 | 56 |
| 20–40 | 52 | 3 / 0.48s | 400 | 18 | 70 |
| 40–60 | 72 | 4 / 0.38s | 530 | 22 | 84 |

Difficulty scales HP once (easy×0.5, normal×1, hard×1.5). These challenge values avoid applying
late-stage threat multipliers twice. Defense is4%, contact cooldown0.95s, spawn radius235–285 units.
At most four actors spawn in one update; slow frames do not replay missed batches. A bounded
weak-reference list is pruned only on spawn attempts/count queries, with no per-enemy scene scan.
The ground mark uses one local draw node, no added lights or particles.

A real native60-second attempt with the Debug build and earned skills survived at886/1150 HP,
with346 spawns and274 kills; the sampled crowd reached71. This is one balance sample, not a win-rate
estimate or phone performance result. An earlier playtest exposed an invalid freed-node TypedArray
assignment; weak references and a dedicated freed-actor regression fixed it before final export.

## Equipment HUD

The border stroke widths are multiplied by1.5, retaining the green/gold colors, shared phase,
30Hz update budget and empty center. The border now surrounds the icon frame. The side `Lv.N`
label is gone; ranks use bold digits with a dark outline in the bottom-right corner, inset from the
colored perimeter. Values and card caps are unchanged; uncapped rank6 also renders as `6`.
Slots use a64×60 footprint; one/two-column packing and a portrait scale/height budget keep badges
within the viewport. Status lines for the two sets remain below the icon grid.

Primary checks: `smoke_wooden_trial`, `smoke_equipment_badges`, `smoke_trials`, `smoke_beasts`,
`smoke_debug_menu`, dash and combo smoke scripts. Evidence is in
`validation/wooden-trial-20261106.json` and `screenshots/equipment-corner-ranks*.png`,
`screenshots/wooden-trial-*.png`. Native GPU captures include a deliberately arranged crowd;
they are engine captures, not browser/device screenshots.
