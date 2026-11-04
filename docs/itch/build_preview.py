"""Build a static design concept; this does not publish or automate itch."""

from html import escape
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent
settings = json.loads((ROOT / "theme-settings.json").read_text(encoding="utf-8"))
description = (ROOT / settings["description_source"]).read_text(encoding="utf-8")
# The preview uses local captures so the downloadable kit works offline.
for name in ("combat", "wind-guardians"):
    remote = (
        "https://raw.githubusercontent.com/wyb969/Rogge/"
        "1b2f5699777403b76797861652c5cb760435d545/docs/screenshots/"
        f"{name}.png"
    )
    description = description.replace(remote, f"../screenshots/{name}.png")

page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>ROGGE — itch page design preview</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400;500;600;700&amp;family=Press+Start+2P&amp;display=swap" rel="stylesheet">
<style>
:root { --ink:#0D1720; --panel:#142A32; --line:#35515A; --paper:#E7EDD5; --mint:#5DDBB0; --gold:#FFD98A; }
* { box-sizing:border-box; }
body { margin:0; background:var(--ink); color:var(--paper); font-family:'Pixelify Sans',monospace; font-size:20px; line-height:1.55; }
.notice { padding:14px 20px; border-bottom:1px solid var(--line); text-align:center; font:12px/1.6 monospace; color:#B8C9BC; }
.notice strong { color:var(--gold); }
.page { width:min(1040px,100%); margin:auto; background:var(--panel); border-inline:1px solid var(--line); }
.masthead { padding:30px 28px; text-align:center; border-bottom:1px solid var(--line); }
.masthead a { color:var(--mint); text-decoration:none; font-size:16px; }
h1,h2,h3,.play { font-family:'Press Start 2P',monospace; }
h1 { margin:0 0 12px; font-size:clamp(24px,6vw,38px); letter-spacing:4px; color:var(--gold); }
.hero { padding:32px; display:grid; grid-template-columns:1fr 1fr; gap:32px; align-items:center; }
.cover { width:100%; height:auto; display:block; border:2px solid var(--line); box-shadow:8px 8px 0 #091820; }
.eyebrow { margin:0 0 18px; color:var(--mint); font-size:16px; letter-spacing:2px; }
.hero h2 { margin:0 0 22px; border:0; padding:0; font-size:clamp(15px,2.2vw,23px); line-height:1.8; color:var(--paper); }
.hero p { color:#C8D8C7; }
.tags { display:flex; gap:8px; flex-wrap:wrap; margin:22px 0; }
.tags span { border:1px solid var(--line); padding:3px 9px; font-size:15px; }
.play { display:inline-block; margin:6px 0 0; padding:16px 20px; font-size:12px; line-height:1.8; color:#10272B; background:var(--mint); text-decoration:none; box-shadow:5px 5px 0 #081B21; }
.play:hover { background:#84F2C5; }
a { color:var(--mint); text-underline-offset:4px; }
a:focus-visible { outline:3px solid var(--gold); outline-offset:5px; }
main { padding:0 64px 48px; }
h2 { margin:46px 0 22px; padding-top:30px; border-top:2px solid var(--line); color:var(--gold); font-size:17px; line-height:1.9; }
p { margin:0 0 19px; }
strong { color:#F2F3DA; font-weight:700; }
ul { padding-left:24px; margin:0 0 28px; }
li { padding-left:4px; margin:0 0 14px; }
li::marker { color:var(--mint); }
main img,.gallery img { width:100%; height:auto; display:block; border:1px solid var(--line); }
main em { color:#B5CBC3; font-size:17px; font-style:normal; }
.gallery { display:grid; grid-template-columns:1fr 1fr; gap:22px; }
figure { margin:0; }
figcaption { font-size:16px; padding:10px 0; color:#B5CBC3; }
footer { padding:22px; border-top:1px solid var(--line); text-align:center; color:#B5CBC3; font-size:16px; }
@media(max-width:700px) { .hero { grid-template-columns:1fr; padding:24px; gap:25px; } .cover { max-width:460px; margin:auto; } main { padding:0 24px 32px; } h2 { font-size:14px; } .gallery { grid-template-columns:1fr; } .hero h2 { font-size:20px; } }
@media(prefers-reduced-motion:reduce) { * { scroll-behavior:auto; } }
</style>
</head>
<body>
<div class="notice"><strong>DESIGN PREVIEW · NOT YET LIVE</strong><br>This concept shows the proposed art, copy, and palette. The itch editor controls the final layout.</div>
<div class="page">
<header class="masthead"><h1>ROGGE</h1><a href="https://ybwangrogger.itch.io/rogue-white">A game by ybwangRogger</a></header>
<section class="hero" aria-label="Game cover and quick introduction">
<img class="cover" src="cover.png" width="1402" height="1122" alt="ROGGE promotional pixel art: the blue hero dashes with orbiting books and a drone beneath two wind falcons.">
<div><p class="eyebrow">PIXEL SURVIVAL ROGUELITE</p><h2>ONE MORE<br>UPGRADE.<br>ONE MORE RUN.</h2><p>@@PITCH@@</p><div class="tags"><span>HTML5</span><span>Auto-attacks</span><span>Keyboard + touch</span></div><a class="play" href="https://ybwangrogger.itch.io/rogue-white">PLAY IN BROWSER</a></div>
</section>
<main>
@@DESCRIPTION@@
<section aria-label="More actual gameplay screenshots">
<h2>A LOOK INSIDE THE ARENA</h2>
<div class="gallery">
<figure><img loading="lazy" src="../screenshots/boss-rush.png" width="1066" height="600" alt="The charging bull boss marks a rush lane before attacking."><figcaption>Read the lane. Time your dash.</figcaption></figure>
<figure><img loading="lazy" src="../screenshots/snow-poison.png" width="1066" height="600" alt="A blue hero leaves a poison cloud trail while dashing through a snowy arena."><figcaption>Turn your escape route into a trap.</figcaption></figure>
<figure><img loading="lazy" src="../screenshots/upgrade-cards.png" width="1066" height="600" alt="The real upgrade screen offers three equipment cards and a reroll."><figcaption>Three choices. A new direction for your build. Current game UI: Chinese.</figcaption></figure>
</div>
</section>
</main>
<footer>Made with Godot 4.7 · Active development · <a href="https://github.com/wyb969/Rogge">Follow the project</a></footer>
</div>
</body>
</html>
"""
page = page.replace("@@PITCH@@", escape(settings["short_description"]))
page = page.replace("@@DESCRIPTION@@", description)
(ROOT / "preview.html").write_text(page, encoding="utf-8")
print("Built preview.html (design concept; itch publication remains pending).")
