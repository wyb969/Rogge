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
