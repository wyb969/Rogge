# Web / Mobile Export (Godot 4.7)

Project features: `4.7` + Forward Plus. Web preset uses **no threads**, landscape-friendly viewport meta, virtual stick + DASH.

## Export (Godot 4.7.x)

```bash
# templates must match editor, e.g. 4.7.2.stable
godot --headless --path . --export-release "Web" export/web/index.html
```

Requires `rendering/textures/vram_compression/import_etc2_astc=true` when mobile VRAM compression is enabled in the Web preset.

## Local / phone test

```bash
python3 tools/serve_web.py 8080 export/web
# then tunnel, e.g. cloudflared tunnel --url http://127.0.0.1:8080
```

Phone: open the HTTPS tunnel URL, lock landscape, use left stick + right DASH.

## Publish to itch.io (playable in browser)

Game page: https://ybwangrogger.itch.io/game-of-biubiu

### 1. Authorize butler (one-time)

1. Open https://itch.io/user/settings/api-keys while logged in as `ybwangrogger`
2. Click **Generate new API key**, copy it
3. In this Cloud Agent / terminal:

```bash
export BUTLER_API_KEY='粘贴你的API密钥'
# or interactive:
# ~/bin/butler login
```

Optional: save the key as a Cursor **Secret** named `BUTLER_API_KEY` or `ITCH_API_KEY` so later agents can upload without pasting again.

### 2. itch.io page settings (Embed)

On the game edit page → **Embed options** / Kind of project:

- Kind: **HTML**
- Check **This file will be played in the browser**
- Viewport usually **900×600** (or match project)
- Enable sharedArrayBuffer / threads only if your export uses threads (this project uses **no threads**)

### 3. Export + upload

```bash
./tools/push_itch.sh --export
# or if export/web is already built:
./tools/push_itch.sh
```

Pushes channel `ybwangrogger/game-of-biubiu:html`. After a minute, refresh the itch page and click **Run game**.

### 4. “Every 3 hours” updates

There is no itch-side auto-schedule. Options:

- Ask the Cloud Agent again when you want a new build (`导出并上传 itch`)
- Or set a Cursor Automation / cron that runs `./tools/push_itch.sh --export` with `BUTLER_API_KEY` in secrets
