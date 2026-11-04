# ROGGE — English itch page kit

**Target:** [ybwangrogger.itch.io/rogue-white](https://ybwangrogger.itch.io/rogue-white)  
**Publication status:** Prepared locally. The live itch page has not been updated by this kit.

A midnight arcade palette, crisp pixel headings, readable pixel body text, original promotional cover, and an English introduction built around the current game.

## Files

| File | Use |
| --- | --- |
| `cover.png` | New promotional cover for the itch project listing. |
| `description.html` | English project description; paste through the editor's HTML/source mode. |
| `theme-settings.json` | Title, short description, native theme settings, screenshot order, and cover disclosure. |
| `preview.html` | Standalone design preview. This is a concept, not a saved itch page. |
| `../screenshots/` | Five actual game captures, already preserved with the recovered project. |

## Apply to itch

1. Open the existing project's [**Edit game** page](https://itch.io/game/edit/3184628) while signed in as its owner. Keep the current URL and playable HTML5 upload.
2. Set the title and short description from `theme-settings.json`. Upload `cover.png` as the cover. Replace the description with `description.html` in the editor's HTML/source view.
3. Add the five screenshots in the listed order. The two images inside the description already use public, commit-pinned GitHub URLs.
4. In **Edit theme**, use the built-in color and Text controls. Set headings to **Press Start 2P**, body to **Pixelify Sans**, and apply the listed colors. These Google Fonts are supported by itch's native theme editor; this kit does not require custom CSS access.
5. Update the AI disclosure accurately for the generated promotional cover. The screenshot gallery remains actual game footage. Save, then inspect the public page on desktop and a narrow viewport before considering publication complete.

The native editor may expose different sizing or layout controls by account. Treat size and alignment entries as targets, not as unsupported API fields. [Official itch design guide](https://itch.io/docs/creators/design).

## Scope and provenance

- The project source, uploaded game, save data, and game controls are unchanged.
- The store copy is English. The current in-game interface is Chinese and is described honestly as such.
- The new cover was created with generative AI using the real combat and Wind Falcons screenshots as references. It is promotional key art, not a gameplay screenshot.
- Copy was checked against the recovered Godot 4.7 build `20261104-002331` and the existing illustrated repository homepage.
- Original public-page HTML was captured before preparing edits and retained separately in the task backup.

The public itch API does not document project-description or theme-writing endpoints. This kit requires an authenticated page editor to publish; a Butler upload alone does not apply it.
