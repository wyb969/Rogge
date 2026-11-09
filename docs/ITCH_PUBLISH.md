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

当前发布流程选取17项实际PCK检查：`smoke_menu_layout`、`smoke_fan_feedback`、`smoke_control_cards`、`smoke_session_toolbar`、`smoke_equipment_badges`、`smoke_wooden_trial`、`smoke_trials`、`smoke_growth_combo`、`smoke_bomb_card`、`smoke_arsenal_combo`、`smoke_death_stains`、`smoke_ink_surf`、`smoke_tactical_enemies`、`smoke_debug_menu`、`smoke_stage_variation`、`smoke_encounter_readability`、`smoke_beasts`。它们覆盖布局、返回主页、装备组合、炸弹、三项试炼、定向泼溅/彩墨、新怪物与共享远程上限；由原生Godot加载实际Web PCK，不等于真实Web/Safari试玩，也不表示全量61个smoke脚本通过。

现存脚本退出时的 ObjectDB / resources-in-use 警告保留在报告中，与运行中脚本/解析错误分开。若出现新运行时错误或检查断言失败，发布任务必须停止；不得将其混同于已知退出警告忽略。

发布只替换当前通道的最新版本。Butler 构建历史可供回退；“页面只有一个当前上传项”不要求删除这些历史记录。上传游戏也不会自动修改商店文案、封面或字体。

## 最新发布记录

2026-11-09已发布 **`20261109-192900`**，源码master `d9855b1`，build **2339462**。17项PCK检查通过，[发布任务](https://github.com/wyb969/PixelFishing/actions/runs/42609961711)成功；[只读通道核验](https://github.com/wyb969/PixelFishing/actions/runs/42610504578)确认该版本已是completed的head。主页HTTP429，**线上iframe及资源哈希尚未核验**；详见 `validation/itch-release-20261109-192900.json`、`validation/itch-readiness-20261109-192900.json` 与 `validation/itch-live-20261109-192900.json`。

主页限流时，可使用同一独立分支的 `.github/workflows/verify-rogge-itch.yml`：更新EXPECTED_BUILD/EXPECTED_VERSION并提交该文件，只运行Butler status等待当前head，不重新打包、测试或上传。它同样仅使用Actions Secret。此通道检查不能替代真实iframe/资源核验。

### 历史发布

2026-11-06已发布 `20261106-182118`，build `2312775`。Actions run `42213352444` 的10项PCK检查通过，线上三项资源哈希与CI清单一致。报告见 `validation/itch-release-20261106-182118.json` 和 `validation/itch-live-20261106-182118.json`。
