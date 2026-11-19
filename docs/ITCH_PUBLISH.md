# ROGGE itch 发布流程

当前试玩：<https://ybwangrogger.itch.io/rogue-white>。

## 发布位置和权限

ROGGE 源码仍位于 `wyb969/Rogge`。当前 Butler 密钥为 **`wyb969/PixelFishing` 仓库的 Actions Secret `BUTLER_API_KEY`**，由该仓库 Actions 直接使用。GitHub Secrets 不支持取回原值；不要尝试在日志、构件或聊天里输出它。

独立发布配置位于 `wyb969/PixelFishing` 的 `automation/rogge-itch-release` 分支：

<https://github.com/wyb969/PixelFishing/blob/automation/rogge-itch-release/.github/workflows/publish-rogge-itch.yml>

该分支中的工作流固定 ROGGE 的完整提交 SHA 和版本，目标固定为 `ybwangrogger/rogue-white:html`，先检查已有 upload id `20115514`。它与 PixelFishing 默认分支的游戏发布任务分开。

## 下次更新

1. 在 ROGGE 正确开发分支完成改动，按范围运行聚焦检查，使用北京时间 `yyyyMMdd-HHmmss` 更新 `project.godot` 版本，将源码提交推到 GitHub。
2. 检查发布工作流分支是否有其他未完成修改或正在执行的任务。
3. 在发布工作流文件中更新 `ROGGE_COMMIT` 为完整源码 SHA、`BUILD_VERSION` 为同一源码中的版本。常规发布只改这两个值；新增功能时同步调整聚焦检查名单和摘要数量。如果升级引擎，则另行更新引擎、模板和官方哈希。
4. 提交并推送到 `automation/rogge-itch-release`。只有该分支中这个工作流文件的 push 会触发任务。文件没有进入默认分支，暂不依赖默认分支的 Run workflow 按钮。
5. Actions 使用 Godot 4.7 与匹配 Web 模板重新导出，检查实际 PCK，保存 Web ZIP、哈希清单和日志，再由 Butler 更新原来的 `html` channel。
6. 查看 Actions 成功结果和 Butler build id。Butler 接受上传后可能仍处于 queued/processing，不能立刻宣称网页已切换。
7. 读取itch主页并等待当前build的iframe：提取中通常有 `load_url/html_url`，就绪后也可能直接出现在转义的 `data-iframe` 中。下载PCK、WASM、JS，与 **Actions构建清单** 比对。不同机器重建的 PCK 可能具有不同字节顺序/缓存结果，不要用另一个本地导出的 PCK 哈希代替 CI 清单。
8. 更新 `docs/AI_HANDOFF.md` 和发布报告。标明真实浏览器/物理设备试玩是否执行。

GitHub artifact 默认保留 30 天。长期需要的源码、验证概要和发布信息应进入 ROGGE Git；临时云端路径和 artifact 不替代源码仓库。

## 验证边界

当前发布流程选取36项检查：`smoke_menu_layout`、`smoke_session_toolbar`、`smoke_equipment_badges`、`smoke_three_cards`、`smoke_codex_menu`、`smoke_localization`、`smoke_debug_menu`、`smoke_palette_cards`、`smoke_combat_balance`、`smoke_relic_weapons`、`smoke_arcane_weapons`、`smoke_star_chain`、`smoke_weather_lighting`、`smoke_winter`、`smoke_world_snow`、`smoke_environment_surface`、`smoke_surface_art`、`smoke_wind_trails`、`smoke_electric_grid`、`smoke_minefield`、`smoke_ice_spikes`、`smoke_airborne_feedback`、`smoke_stage_hazards`、`smoke_boss_control_guard`、`smoke_boss_rhythm`、`smoke_beasts`、`smoke_trials`、`smoke_wooden_trial`、`smoke_resource_bounds`、`smoke_hero_art`、`smoke_stage_monster_art`、`smoke_runtime_optimization`、`smoke_boss_facing`。覆盖本次新增的武器、环境、危险地形、中英菜单/词典与卡片，以及Boss控制、试炼和资源上限。检查脚本以当前发布工作流为准；由原生Godot加载实际Web PCK，不等于浏览器/Safari实测，也不是全量回归。

现存脚本退出时的 ObjectDB / resources-in-use 警告保留在报告中，与运行中脚本/解析错误分开。若出现新运行时错误或检查断言失败，发布任务必须停止；不得将其混同于已知退出警告忽略。

发布只替换当前通道的最新版本。Butler 构建历史可供回退；“页面只有一个当前上传项”不要求删除这些历史记录。上传游戏也不会自动修改商店文案、封面或字体。

## 最新发布记录

2026-11-19 发布 **20261119-174407**，内容为卡片品质、关后锻造及练习补给，游戏源码为 `ff57983`。原网页通道的 itch build 为 **2436221**。[发布任务](https://github.com/wyb969/PixelFishing/actions/runs/44502957016)通过 36 组检查，[通道核验](https://github.com/wyb969/PixelFishing/actions/runs/44503494998)确认该版本为当前构建。 下载方式见[构建包和验证日志](https://github.com/wyb969/PixelFishing/actions/runs/44502957016/artifacts/14518286582)。另有锻造流程、战斗数值与拖拽/补给三组测试。

### 2026-11-19 早期发布

2026-11-19 发布 **`20261119-103149`**。master 源码 `b10a0eb4599719fa7c8fb5635845848822a03c6e` 包含四位可选角色、逐关主题怪物及八套精细 Boss 动作。[发布任务](https://github.com/wyb969/PixelFishing/actions/runs/44447222306)通过 33 项 Web PCK 检查，并产出[可下载的 Web 包和验证日志](https://github.com/wyb969/PixelFishing/actions/runs/44447222306/artifacts/14494321532)。[通道检查](https://github.com/wyb969/PixelFishing/actions/runs/44447598120)确认原 HTML 通道的 build **2433648** 已完成，待处理队列为空。

### 2026-11-16 发布

2026-11-16已发布 **`20261116-202250`**，master源码 `372b8f5be5ffee9f6d455c46ce62a98abf99fb27` / [PR #31](https://github.com/wyb969/Rogge/pull/31)，build **2404997**。29项实际PCK检查和1100键翻译审计通过；[发布](https://github.com/wyb969/PixelFishing/actions/runs/43866453557)与[只读通道核验](https://github.com/wyb969/PixelFishing/actions/runs/43866959069)成功。原html通道completed/current，无pending；主页实际新iframe的PCK/WASM/JS与CI清单哈希一致。没有本轮浏览器/Safari交互实测。证据：`validation/itch-release-20261116-202250.json`，构件14226091335保留到2026-12-16。

### 2026-11-12 发布

2026-11-12已发布 **`20261112-230737`**，源码master `c51afeccba095ea1abcdbfcc51c0f71edbd93862`，build **2366099**。24项实际PCK检查通过，[发布任务](https://github.com/wyb969/PixelFishing/actions/runs/43245465358)成功；[只读核验](https://github.com/wyb969/PixelFishing/actions/runs/43245971065)确认completed/current、无pending。主页HTTP200，实际iframe的PCK/WASM/JS哈希与Actions清单一致；Chromium实际托管入口的Debug/受击/移动/Dash/Home检查通过。没有Safari真机或全流程结论。报告：`validation/itch-release-20261112-230737.json`、`validation/itch-readiness-20261112-230737.json`、`validation/itch-live-20261112-230737.json`。

第一次发布尝试被木头人检查过时的“必须在Debug首页”断言阻止，未上传；PR #12让检查定位按钮实际页，最终24项全过。不要跳过失败检查或为了测试改变按钮排序。HTML提取可能在Butler completed之后仍返回extracting；等待主页实际`load_url`响应，再核验其中的iframe，不猜CDN路径。itch会在HTML尾部加入自己的`htmlgame.js`，因此HTML整体哈希可能不同；仍需核对原始内容/资源配置，PCK/WASM/JS则必须逐字匹配CI。

主页限流时，可使用同一独立分支的 `.github/workflows/verify-rogge-itch.yml`：更新EXPECTED_BUILD/EXPECTED_VERSION并提交该文件，只运行Butler status等待当前head，不重新打包、测试或上传。它同样仅使用Actions Secret。此通道检查不能替代真实iframe/资源核验。

### 历史发布

2026-11-09已发布 **`20261109-192900`**，源码master `d9855b1`，build **2339462**。17项PCK检查通过，[发布任务](https://github.com/wyb969/PixelFishing/actions/runs/42609961711)成功；[只读通道核验](https://github.com/wyb969/PixelFishing/actions/runs/42610504578)确认该版本已是completed的head。主页HTTP429，**线上iframe及资源哈希尚未核验**；详见 `validation/itch-release-20261109-192900.json`、`validation/itch-readiness-20261109-192900.json` 与 `validation/itch-live-20261109-192900.json`。

2026-11-06已发布 `20261106-182118`，build `2312775`。Actions run `42213352444` 的10项PCK检查通过，线上三项资源哈希与CI清单一致。报告见 `validation/itch-release-20261106-182118.json` 和 `validation/itch-live-20261106-182118.json`。
