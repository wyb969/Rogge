# Debug menu — November cleanup

The Debug page is a compact paginated panel, with recent tests ordered newest first.
Opening it resets to page one. Previous/Next, the page number, Back and diagnostic export
remain in fixed positions on every page, including the last partial page. PageUp/PageDown
also change pages; Escape returns home. Resizing preserves the current first entry where possible.

## Entry scope and provenance

13 retained test entries were introduced after recovery, in commits dated November 4–6:
critical glasses (1/5), fan (1/5/status), black hole (1/5), fan + black hole, bomb (1/5),
Arsenal, Growth and both equipment sets. Back and diagnostic export are utilities, not tests.

21 old interactive test entries from the recovered baseline were removed: lighting,
feedback, first Boss, blessings, knight, meteors, variety, poison (1/5), music, necklace,
treasure, four beasts, two trials, lightning, weather and stability.

**Date limitation:** the recovered baseline commit is dated November 4 but does not retain
the original creation dates of its buttons. It cannot prove all 21 originated before November.
Cleanup uses the recovered-baseline/new-development boundary as the practical interpretation
of the user's request. The optional clarification did not receive an answer before implementation.
No gameplay preset, controller or combat behavior was deleted. Automated checks call the legacy
`Main._launch_run(mode)` presets directly; they no longer depend on removed UI nodes.

## Mobile layout

- Panel width is capped at 620 physical pixels, with margins and room above for fullscreen.
- Narrow screens use one column (up to four entries); wide screens use two (up to three rows).
  Available height determines the actual capacity. A normal 390×844 phone gets four pages.
- The viewport's final transform converts physical touch/font sizes to logical coordinates:
  the game's 900-pixel logical viewport must not shrink buttons on a phone.
- Entries are 48 physical pixels high; Back/export/pager are 44. Labels clip or ellipsize;
  report status stays on one line and its tooltip retains the full message.
- Off-page entries are hidden and disabled. Shared hover/pressed styles keep button bounds fixed;
  the homepage's scale/rotation script is not attached to these Debug buttons.
- `VBoxContainer` is now a plain Control, retaining its historical node path. Add future test
  entries to both the scene's signal bindings and `RECENT_ORDER` in `debug_menu_layout.gd`.

## Focused verification

Use Godot 4.7, `gl_compatibility`, Dummy audio and isolated user data, as described in
`AI_HANDOFF.md`. Primary checks: `smoke_debug_menu.gd` and `smoke_menu_layout.gd`.
The former walks every page at 390×844, 320×568, 280×480, 844×390, 640×360,
900×500 and 1440×900, checking bounds, overlap, touch heights and fixed controls;
it also covers export, Back, double-tap launch, Retry and ordinary Start isolation.

Evidence: `validation/debug-pages-20261106.json` and four `screenshots/debug-pages-*.png`
native GPU captures. Native and PCK checks do not establish physical Safari/Android behavior.
