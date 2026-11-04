# Rogge — recovered editable project

This branch preserves the game published on itch as `20261104-002331`. It was recovered after the previous development environment became unavailable. It is a recovery snapshot, not the original working directory or its missing local Git history.

- Source: https://ybwangrogger.itch.io/rogue-white
- Exported pack SHA-256: `f7f0a3ea0b94ab155a354e68248b0db061782d2dd81ee50146880813add323d4` (20,281,940 bytes).
- Engine: Godot 4.7.0. Open `project.godot`.
- Recovery tool: GDRE Tools 2.7.4; 146 scripts decompiled, zero script failures, 343 imported resources converted, zero conversion failures.
- 49 resources were reported as lossy conversions: exported textures/audio can be restored as editable resources, but their original vector/authoring data or original uncompressed audio is not guaranteed.
- Git history from the inaccessible environment, comments/formatting removed by export, Python build/generator tools, non-exported design notes, and unexported/untracked files cannot be reconstructed from the playable package.
- Five music WAV loop import modes were restored against the original pack. All 32 WAV resources retain matching duration, sample rate, channels and loop metadata; exported QOA audio was recovered as PCM.
- The original pack and raw recovery ZIP were preserved separately before validation. Cache/compiled recovery files are omitted from this editable-source branch.
- Functional checks: see `RECOVERY_PROVENANCE.json` and `RECOVERY_TEST_RESULTS.json`.

The repository's existing branches remain untouched. This branch provides a durable starting point while the original environment's availability is investigated.
