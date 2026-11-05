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
3. 在发布工作流文件中更新 `ROGGE_COMMIT` 为完整源码 SHA、`BUILD_VERSION` 为同一源码中的版本。只修改这两个值；如果升级引擎，则另行更新引擎、模板和官方哈希。
4. 提交并推送到 `automation/rogge-itch-release`。只有该分支中这个工作流文件的 push 会触发任务。文件没有进入默认分支，暂不依赖默认分支的 Run workflow 按钮。
5. Actions 使用 Godot 4.7 与匹配 Web 模板重新导出，检查实际 PCK，保存 Web ZIP、哈希清单和日志，再由 Butler 更新原来的 `html` channel。
6. 查看 Actions 成功结果和 Butler build id。Butler 接受上传后可能仍处于 queued/processing，不能立刻宣称网页已切换。
7. 读取 itch 主页当前 `html_url` 结果，等待可用 iframe；下载其 PCK、WASM、JS，与 **Actions 构建清单** 比对。不同机器重建的 PCK 可能具有不同字节顺序/缓存结果，不要用另一个本地导出的 PCK 哈希代替 CI 清单。
8. 更新 `docs/AI_HANDOFF.md` 和发布报告。标明真实浏览器/物理设备试玩是否执行。

GitHub artifact 默认保留 30 天。长期需要的源码、验证概要和发布信息应进入 ROGGE Git；临时云端路径和 artifact 不替代源码仓库。

## 验证边界

当前任务选取 `smoke_menu_layout`、`smoke_fan_feedback`、`smoke_control_cards`，由原生 Godot 直接加载实际 Web PCK。它们检查布局、当前技能和控制卡片行为；不等于真实 Web/Safari 测试，也没有宣称覆盖全部 52 个检查脚本。

现存脚本退出时的 ObjectDB / resources-in-use 警告保留在报告中，与运行中脚本/解析错误分开。若出现新运行时错误或检查断言失败，发布任务必须停止；不得将其混同于已知退出警告忽略。

发布只替换当前通道的最新版本。Butler 构建历史可供回退；“页面只有一个当前上传项”不要求删除这些历史记录。上传游戏也不会自动修改商店文案、封面或字体。
