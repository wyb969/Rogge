# Rogge Web / Mobile 导出说明

## 已完成的手机适配

- 左下角虚拟摇杆（移动）
- 右下角 **DASH** 按钮
- 横屏优先：`window/handheld/orientation = sensor landscape`
- 画布拉伸：`canvas_items` + `expand`
- Web 导出预设指向 `export/web/index.html`，PWA orientation = landscape
- 仅在触屏 / Web / 移动端显示虚拟控件；电脑键鼠仍可用

## 在你本机用 Godot 4.7 导出（推荐）

当前仓库的 `config/features` 是 **4.7**。请用本机 Godot **4.7** 打开项目：

1. 菜单 **Project → Export…**
2. 选择 **Web** 预设
3. 确认 Export Path 为 `export/web/index.html`
4. 若提示缺少模板：安装 **4.7 Web Export Templates**
5. 点 **Export Project**

## 局域网手机测试

导出完成后，在项目根目录执行：

```bash
python3 -m http.server 8080 --directory export/web
```

手机与电脑同一 Wi‑Fi，浏览器打开：

```text
http://<电脑局域网IP>:8080
```

建议锁定手机横屏。首次点页面以聚焦画布。

## 辅助脚本

```bash
# 若本机 GODOT_BIN 指向 Godot 可执行文件：
GODOT_BIN="/path/to/Godot" ./tools/export_web.sh
```

> 注意：云端环境里的 Godot 4.3 与本项目 4.7 不匹配，headless 导出可能失败。请以本机 4.7 编辑器导出为准。
