# ROGGE · AI 开发交接

更新日期：2026-11-05（北京时间，UTC 为 11-04）。本轮新增暴击眼镜卡、修复开局武器无条件点燃，并补齐 Web 诊断 JS 的导出；详细行为见 `docs/critical-glasses.md`。初始交接时仅整理文档，本次已恢复功能开发。

## 1. 先找到正确的代码

| 项目 | 已确认状态 |
| --- | --- |
| 仓库 | <https://github.com/wyb969/Rogge> |
| 最新玩法分支 | `feature/fan-black-hole-20261104` |
| 最新玩法 | 暴击眼镜与默认点燃修复，与本次文档同提交；实际 SHA 用 `git log -1` 核对 |
| 上一玩法提交 | `8bc1fa0a5969be34639f36b6698a804fbbc4b628`，第一关 Boss 转向与行走动画修复；更早的 `04281a9` 为芭蕉扇/黑洞 |
| 默认 `master` 的代码基线 | `d684fa41d9afac8879422c2baf9917996b8f8778`，尚无上述玩法更新 |
| 合并状态 | [PR #3](https://github.com/wyb969/Rogge/pull/3) 在检查时 open、未合并；不要假定已进入 master |
| 游戏版本 | `project.godot` 的 `application/config/version = 20261105-003002`；当前本地构建，尚未更新 itch |
| 工作区状态 | 本轮开始时开发分支干净；完成后重新检查 `git status`，不要依赖本行判断后续编辑 |

最初的交接文档曾同步到 master；本轮进度和功能更新在开发分支，尚未合并。新会话先重新检查远端和本地状态，切到开发分支读取最新本文件。

已有工作区先执行 `git status --short --branch`、`git worktree list`、`git log -5 --oneline`。不要覆盖工作区或重新从 itch 反编译。全新机器可克隆仓库后切到开发分支：

```bash
git clone https://github.com/wyb969/Rogge.git
cd Rogge
git switch --track origin/feature/fan-black-hole-20261104
git status --short --branch
```

本次云端路径仅供定位，下一会话可能不存在：

- 最新源码：`/workspace/Rogge-fan-blackhole-20261104/project`（关联 worktree）。
- master：`/workspace/Rogge-recovery-20261104T024444Z/github-recovered-project`（共用 Git 主目录）。
- `Rogge-homepage-20261104/project`、`Rogge-itch-page-20261104/project` 是旧 detached worktree；`validated-project` 是旧验证副本，均不是当前开发入口。

## 2. 引擎、资源与恢复来源

- Godot **4.7**，GDScript；当前有 152 个 `.gd` 文件、50 个 `tools/smoke_*.gd` 脚本。没有额外的 npm/Python 运行时依赖，也没有 GitHub Actions 发布工作流。
- 主场景 `res://scenes/main.tscn`，逻辑视口 900×600。配置 features 写有 Forward Plus，项目没有显式渲染器覆盖；已有原生检查和 Web 导出使用命令行 `--rendering-method gl_compatibility`。
- Web 预设关闭线程、扩展和 PWA，使用默认 HTML shell；`include_filter` 显式包含 `script/web_diagnostics.js`，确保 `FileAccess` 可读取诊断 helper。另有 Windows Desktop 预设，但不能据此声称 Windows 包已构建测试。
- 资源主目录故意沿用 `assest/` 拼写。保留 `.uid`、`.import`，尤其音频循环参数；`.godot` 是可重建缓存。`docs/.gdignore` 将文档素材排除出游戏导入。
- 源码曾从公开 itch 包 `20261104-002331` 恢复。详见 `RECOVERY_README.md`、`RECOVERY_PROVENANCE.json`：146 个脚本反编译无失败，343 个资源转换无失败，其中 49 项有损。音频曾从压缩资源还原 PCM WAV 并恢复循环设置。
- 恢复版不是丢失工作区的逐字备份：原注释、未导出资源、未推送历史和原始美术母版不能保证恢复。以当前 Git 源码为维护基线，避免批量格式化反编译文件。

## 3. 实际架构和依赖

| 模块 | 文件与职责 |
| --- | --- |
| 应用外壳 | `scenes/main.tscn`、`script/main.gd`：主页、设置、Debug、结果页、全屏和移动 UI；每次运行创建新的 `game.tscn`，防止重复启动 |
| 单局编排 | `scenes/game.tscn`、`script/game.gd`：玩家与控制器、升级分发、奖励队列、暂停、结算和清理；实例加入 `game` 组 |
| 玩家 | `script/player.gd`：移动、朝向、冲刺、伤害、成长、治疗及状态 |
| 关卡/刷怪 | `script/spawner.gd`：主题怪池、远程上限、Boss/宝藏守卫计时、休息与转场 |
| 经验/升级 | `scenes/level_bar.gd`；`script/pasue_menu.gd` 及 `scenes/PasueMenu.tscn` 为选卡 UI；`upgrade_card.gd` 渲染卡片，`equipment_panel.gd` 管装备图标与等级 |
| 普通敌人 | **`scenes/enemy_shell.tscn` / `script/enemy_shell.gd`** 为实际主力；`enemy_meta.gd` 定义 `EnemyData`，`.tres` 配置敌人。旧 `enemy.gd`、恐龙/状态机脚本不能直接当作全部敌人入口 |
| Boss/试炼 | `boss.gd` 基类；骑士继承它，`beast_boss.gd` 和风 Boss 管神兽；`trial_enemy.gd`、`trials.gd` 管试炼；宝藏守卫、掉宝信使继承普通敌人实现 |
| 武器/卡片 | 场景内枪、斧头、环绕书、无人机、汽油瓶、冰冻控制器；`game._ready()` 动态创建剧毒、闪电戒指、芭蕉扇、黑洞等控制器 |
| 奖励/关卡 UI | `treasure_lottery.gd`、`rest_hub.gd`、`beast_powers.gd`；卡片、抽奖、技能领取、试炼、休息共享游戏奖励队列 |
| 环境与反馈 | `environment_weather.gd`、`weather_audio.gd`、`meteor_shower.gd`；`combat_feedback.gd`、`combat_lighting.gd`、`elemental_attack_visual.gd`、`visual_style.gd` |
| 性能与诊断 | `combat_targets.gd`、`burn_spread.gd`、`feedback_budget.gd`、`run_diagnostics.gd`、`diagnostic_logger.gd`、`web_diagnostics.js` |

五个 autoload：`SettingsStore`（设置持久化）、`RunDiagnostics`（诊断）、`AudioManager`（音频场景）、`MobileInput`（触屏输入）、`CombatTargets`（活跃战斗目标登记）。

依赖方向：应用外壳创建单局 → 单局连接玩家、刷怪、经验、卡片与技能 → 敌人和武器通过伤害/死亡接口交互 → 单局处理奖励/转场 → 反馈系统显示、播放音效并记录诊断。不要反向让某个卡片接管关卡推进。

生命周期要点：

- `LevelManager.signal_level_up` 进入 `game.on_level_up`，应用玩家成长、刷怪压力并排队选卡；选卡进入 `_on_upgrade_selected(id)`，更新控制器和装备栏。
- `game._reset_skill_controllers()` 管新局和结束清理；`variety.clear_combat_effects()` 清除跨战斗瞬时状态，同时保留已拥有卡片等级。暂停、休息、试炼介绍、死亡及隐藏游戏不能继续结算攻击。
- `_show_next_reward()` 排队解决抽奖、神兽领取、升级卡、试炼、休息；试炼和模态窗口有阻塞条件，避免两个暂停窗口同时开启。
- `game.tscn` 内名为 `Node2D` 的实例实际是升级 UI；场景根名与运行时 `game` 实例名也不同。定位时看脚本和 ownership，别只看节点名。
- 敌人在 `EnemyGroup`；掉落物和特效分别归 `pickup_container`、`effect_container`。伤害走 `apply_hit(Dictionary)`，保留 `vulnerable()`、防御、死亡奖励。`from_status: true` 用于避免持续伤害递归触发被动；并非跳过所有伤害修正。

## 4. 当前玩法与已实现内容

以下实现可从代码确认；测试证据范围见第 5 节，不能把“有测试脚本”自动视为“当前所有设备验证通过”。

### 关卡、Boss 与难度

| 关卡 | 主要内容 |
| --- | --- |
| 1 | 冲刺公牛 Boss；蓄力、锁定冲刺、恢复、行走追击 |
| 2 | 骑士 Boss，冲刺加挥剑、红色预警、二阶段 |
| 3 | 潮汐神兽；本关还会出现宝藏守卫与老虎机 |
| 4 | 雷霆神兽；击败并领取技能后进入力量试炼 |
| 5 | 双风隼，一近战一远程；必须击败两只 |
| 6 | 熔岩/岩火神兽；领取后进入速度试炼，后续可继续自由挑战或结束 |

- 宝藏守卫：**第三关经过 24 秒**触发。第三关主 Boss 要求**有效运行计时至少 210 秒（3分30秒）、守卫已解决且抽奖已领取**。不是“第四关固定出现”，也不是只看经验等级。暂停、休息、转场不积累该计时；有效 Boss 战时间计入。
- 每关从合理背景池、主力怪池中选择；20 槽怪物配比中 15 槽为主力，另有少量辅助/远程。第一关远程存活上限早期为 1、升级后为 2；后续随关卡和玩家等级增长。
- 简单：普通怪/Boss 血量×0.5，经验及治疗×1.5；中等维持×1；困难血量×1.5。设置在新局快照生效。
- 玩家每次升级增加最大血量并恢复对应的 25 点；敏捷怪有冲刺节奏、命中后停滞，避免持续贴身扣血。
- 力量试炼：介绍后开始，60 秒内击败慢速高血量机械敌人，锁定音与激光预警。速度试炼：瞬移近身，0.5 秒预警斩击，成功 dash 躲开后有 1.5 秒反击窗口，不限总时间。

### 卡片、神兽技能和输入

当前选卡池及装备定义均为 **21 种**；稳定 ID 如下：

- 武器：`axe_up`、`circle_up`、`gun_up`、`drone_up`、`molotov_up`、`freeze_up`。
- 成长/生存：`pickup_up`、`speed_up`、`left_fist`、`right_fist`、`regen_up`、`lifesteal_up`、`shield_up`、`monster_necklace`。
- 机制卡：`lightning_ring`、`wind_emblem`、`echo_ember`、`poison_trail`、`banana_fan`、`black_hole`、`critical_glasses`。

左右拳卡是方向伤害加成，并非独立拳击武器。斧头和环绕书开局已有 1 级；其余按各自控制器判断，不要由显示文字推断是否已装备。

- 芭蕉扇：最高 5 级，沿冲刺/最后移动方向吹击，基础伤害 12→28，距离 130→230，间隔 3.2→1.4 秒；单次气流每敌人只命中一次，实际击退身体、产生有限气流扰动，可打断敏捷怪冲刺。
- 黑洞：最高 5 级，持续 3 秒，DPS 6→18，半径 70→118，间隔 10→6 秒；在附近目标处生成、中心距玩家至少 88，平滑牵引和旋转。持续伤害不递归触发燃烧、冰冻、吸血，击杀仍正常给经验和项链掉落。
- Boss/试炼敌人承受卡片伤害，但免疫这两张卡的强制位移；速度试炼无敌期仍受保护。宝藏守卫继承普通敌人行为，有自身质量/抗性，不能泛称所有小 Boss 都完全免疫。
- 剧毒踪迹：最高 5 级，DPS 为 5×等级，5 级减速 25%；云团有寿命与数量上限，重叠不重复叠伤，毒色与灼烧/冰冻区分。
- 暴击眼镜：墨镜图标，最高 5 级，每级 +20% 暴击率；1～4 级暴击伤害 150%，5 级为 100% 暴击率和 200% 伤害（用户已确认）。`critical_glasses.gd` 为无节点的规则模块，等级和独立 RNG 在玩家身上，普通怪/Boss 的 `apply_hit` 调用同一接口。持续伤害不再次暴击，弹字更大、描边更厚并加 `!`；转场保留等级，返回/新局清零。
- 斧头和开局环绕书的命中数据均已移除默认燃烧，不再无卡点燃群怪。只有显式燃烧攻击/汽油瓶卡的正常附燃等来源应引入灼烧；勿将旧烟雾/火焰模板重新复制到普通攻击。
- 怪物项链杀敌掉绿色治疗球，1 级基础治疗 5，后续升级增加；治疗走难度和玩家治疗倍率。闪电戒指随等级增加伤害、数量及范围。
- 选卡有重选；宝藏抽奖通常给随机卡 +2（80%），+3 为 15%，+1 为 5%，不超过卡片上限。休息奖励可在最终确认前改选，确认后只领取一次。
- 四神兽技能依次为治疗、屏幕雷击与清弹、全地图已掉落物牵引、6 秒减伤 90%；基础冷却分别 35/45/22/40 秒。治疗基础为最大血量 45%，Boss 雷击为最大血量 6% 且上限 420。左侧图标直接释放并显示冷却，另保留 Q 切换、E 释放当前技能。
- 移动支持方向键、WASD、移动端摇杆；Shift/dash 持续 0.14 秒，结束后仍有 0.5 秒无敌，冷却约 3 秒。按钮灰底、绿色填充及就绪反馈已实现。
- 主页有独立 Debug 页和返回；含 Boss、试炼、卡片等测试入口。芭蕉扇/黑洞提供 1级、5级和双5级组合入口，详见 `docs/control-cards.md`。

### 画面、声音与性能措施

- 已有昼夜、晴/阴/雨/雪、天气环境音、阴天/夜间流星事件、世界坐标雪；随机冒险音乐、Boss 8bit 曲目和独立 Music/SFX/Ambience 混音。
- 已有受伤红闪、Boss 属性预警与实际攻击特效、技能展开/淡出、相机拖拽与有限震动、局部光影、拾取音高/经验条连击热度、短枪声音色变化。具体效果是否足够清晰和有趣仍需试玩判断。
- `visual_style.gd` 定义友军青色、危险红色、治疗绿色等语义；不要让天气或发光遮挡敌弹和掉落。
- `CombatTargets` 监听节点生灭并缓存活跃对象，但半径/最近目标查询仍为**线性扫描**。不是空间哈希；应复用输出数组，降低频率并避免逐敌重复调用。
- 燃烧传播使用批量队列/空间分桶；天气、弹链、光影、伤害字和反馈都有预算。反馈池上限为碎片 128/环 16/残影 8；雨 96/雪 64；新卡扫描间隔 0.05 秒、绘制约 30 Hz，黑洞最多 1 个、气流扰动记录 24 个。
- `SettingsStore` 保存 `user://rogge_settings.cfg`，包括难度、触控布局和音量。默认 Music 0.55、SFX 1.0、Ambience 0.35；测试不要污染用户设置。

## 5. 验证证据和边界

| 证据 | 已记录结果 | 解释 |
| --- | --- | --- |
| `RECOVERY_TEST_RESULTS.json` | 47/47 | 恢复基线的原生检查，历史记录 |
| `docs/validation/control-cards-20261104.json` | 48/48 | 两张新卡加入后的原生回归，版本 `20261104-210610` |
| `docs/validation/boss-facing-20261104.json` | 8/8 | 历史 `20261104-233814` 的聚焦检查：转向、冲刺节奏、重叠、骑士、双风、神兽、属性攻击、新卡 |
| `docs/validation/critical-glasses-20261105.json` | 27/27 个不同原生检查 | 本轮暴击、两种开局武器的默认点燃、相关战斗/关卡/奖励及诊断检查；之后另有实际导出 PCK 与 Chromium Web 检查 |
| 导出 PCK 内测试日志 | 新卡、最新 Boss 转向检查通过 | 当时云端 `packed-control-smoke.log`、`packed-boss-facing.log`；属于原生引擎加载实际 PCK，不是真浏览器 |
| `docs/screenshots/` 四张新卡截图 | 有实际运行截帧 | 原生运行截图，不是 Safari/itch 浏览器截图 |

当前共有 50 个 smoke 脚本，**没有最新版本全量 50/50 的记录**。历史报告不能相加当作独立功能数，也不保证所有分支当前都通过。本轮针对共享战斗改动选测 27 项；最终修复书本后复跑 7 项相关检查，再验证实际 PCK。原生截图新增两张，位于 `docs/screenshots/critical-glasses-*.png`。

本地 Chromium 155.0.8059.79 已实测当前 Web 导出：新启动、Debug 满级卡、战斗/伤害字、移动与 Shift 冲刺、390×844 竖屏调整，控制台错误为 0。它运行于云端软件图形环境，不是 itch CDN 或物理手机 Safari 验证。

最新 Boss 修复的代码与测试共同确认：WAIT 追击时朝向玩家并播放循环 walk；RECOVER 每帧更新朝向，冲刺结束立即转向；蓄力/冲刺保持锁定方向，细小横向差有防抖。旧“冲刺后倒着滑行”的修复位于 `boss.gd` 与 `tools/smoke_boss_facing.gd`。

## 6. 尚未完成、已知问题与复现

1. **分支尚未合并。** PR #3 open；下一会话不能只在旧 master 上继续加功能。合并、扩大功能范围按后续用户指示处理，本次没有合并游戏代码。
2. **最新在线包的端到端核验未完成。** Butler 接受了版本 `20261104-233814`、build `2297831` 的上传，但当时在线资源核验遇到 429/新 CDN 404，未完成最新版 PCK 哈希比对和真实浏览器试玩。复核方式：打开 itch，核对左下角版本，重载并进入第一关测试转向；必要时比对实际 iframe/CDN 的 PCK 与本地导出。不要仅凭上传成功就宣称已在 Safari 验证。
3. **别的电脑偶发启动报错，用户已要求暂不处理。** 现象为 Godot 加载时弹出 `Couldn't load project data at path "/". Is the .pck file missing?`，尚未进入游戏。用户自己的电脑、手机未复现；Win7 只是用户猜测，没有确认系统、浏览器、网络请求或根因。只有用户重新要求时，才收集那台机器的浏览器版本/控制台/网络失败信息；不要顺带改导出加载器。以前的实验留在项目外 `deferred-web-investigation-20261104/`，未合入、未发布。
4. **诊断 helper 漏打包已确认并修复。** 本轮 Chromium 复现 `RoggeDiagnostics.previous` 未定义，原 PCK 确实缺 JS。Web include_filter 加入该文件后重新导出，PCK 包含路径，浏览器全局 helper 为 object，运行阶段控制台错误为 0。此问题与用户暂停调查的“找不到项目 PCK”启动提示不是同一个已证实根因；不要混为一谈。
5. **物理设备稳定性和新卡平衡需要试玩。** 历史手机 Safari 重载/崩溃报告促成了预算和诊断改造；原生测试不能证明手机在最终神兽、雨雪、高密度汽油瓶+黑洞的长局内存稳定。复现检查应记录设备、版本、天气、装备、关卡，并从 Debug 导出诊断。`stress_stability.gd`、`benchmark_runtime.gd` 可辅助但不能代替设备实测；本次未运行。
6. **itch 商店文案存在时效差异。** `docs/itch/` 的英文封面/文案/像素字体套件是编辑素材，内部保留 prepared_not_published 状态，部分文案仍写 18 种装备（当前为 21）。不能由素材存在推断在线首页已全部应用；用户/其他流程也可能编辑了在线页面。后续更新主页前应读取当时真实页面。

本轮需求已实现，尚需用户试玩反馈。`20261105-003002` Web 包已在本地构建/验证，Butler 只读状态检查明确返回未配置 `BUTLER_API_KEY`，所以本轮未上传 itch。下一次若要发布，先在环境配置该 secret，复用既有 channel，发布后核对线上版本；不要让用户把密钥写进源码或聊天。

## 7. 测试、排查与发布命令

在源码根目录执行。先确认 `godot --version` 为 4.7；`GODOT_BIN` 可替换成实际二进制路径。首次克隆/无缓存先导入，下面命令是操作手册，**不表示本次已执行**：

```bash
GODOT_BIN=godot
"$GODOT_BIN" --version
"$GODOT_BIN" --headless --rendering-method gl_compatibility --audio-driver Dummy --path . --editor --import --quit
XDG_DATA_HOME="$(mktemp -d)" "$GODOT_BIN" --headless --rendering-method gl_compatibility --audio-driver Dummy --path . --script res://tools/smoke_boss_facing.gd
```

原生 smoke 使用临时 `XDG_DATA_HOME` 隔离设置；`--audio-driver Dummy` 不能验证听感。每项检查退出码及 PASS/OK 标记和脚本错误；已有日志中存在退出时 ObjectDB/resources-in-use 警告，不要据此掩盖新运行时错误。

| 改动范围 | 优先选择的 `tools/` 检查 |
| --- | --- |
| 第一关 Boss | `smoke_boss_facing.gd`、`smoke_boss_rhythm.gd`、`smoke_first_boss_overlap.gd` |
| 卡片/持续伤害/击退 | `smoke_critical_glasses.gd`、`smoke_axe.gd`、`smoke_book_growth.gd`、`smoke_control_cards.gd`、`smoke_poison_trail.gd`、`smoke_monster_necklace.gd`、`smoke_status_numbers.gd` |
| 骑士/神兽/试炼 | `smoke_knight_boss.gd`、`smoke_beasts.gd`、`smoke_wind_duo.gd`、`smoke_elemental_attacks.gd`、`smoke_trials.gd` |
| 休息/全局拾取/奖励 | `smoke_rest_selection.gd`、`smoke_rest_pickup_clock.gd`、`smoke_global_pickup.gd`、`smoke_treasure_lottery.gd` |
| 性能/天气/声音 | `smoke_resource_bounds.gd`、`smoke_runtime_optimization.gd`、`smoke_molotov_spread.gd`、`smoke_world_snow.gd`、`smoke_weather_audio.gd`、`smoke_audio_mix.gd` |

诊断：`RunDiagnostics` 保存 `user://rogge_diagnostics.json`，最多 60 个采样、96 个事件，约每 5 秒保存；记录 160ms 以上长帧（限频）、引擎错误、节点/内存/目标/装备等。主页 Debug 有诊断导出和压力测试入口。Web 有 localStorage/上下文丢失捕获，当前已包含必要 JS；诊断不能覆盖加载 PCK 之前的启动失败。

Web 构建要求匹配的 4.7 导出模板。使用新的构建输出目录并指定路径；不要沿用预设中旧机器的相对输出位置：

```bash
mkdir -p export/web
"$GODOT_BIN" --headless --rendering-method gl_compatibility --audio-driver Dummy --path . --export-release Web export/web/index.html
```

导出时不要套用测试的临时 `XDG_DATA_HOME`，否则标准位置模板可能不可见。检查 HTML/JS/WASM/PCK 文件齐全、名称一致、资源和版本正确，再测试真实 Web。仅在用户任务包含上传时执行发布；将 `BUILD_VERSION` 设为本次 `project.godot` 版本，API key 由环境 secret `BUTLER_API_KEY` 提供，不能写进命令参数/仓库：

```bash
butler push export/web ybwangrogger/rogue-white:html --userversion "$BUILD_VERSION"
```

- 试玩：<https://ybwangrogger.itch.io/rogue-white>；编辑页：<https://itch.io/game/edit/3184628>。
- 复用 `html` channel（已有 upload id `20115514`）；不要为普通更新创建另一公开包。Butler 保留构建历史与“页面只显示一个当前文件”是两回事。
- 版本号使用打包日期时分秒，沿用北京时间 `yyyyMMdd-HHmmss`。文档提交不触发版本变更。
- `20261104-210610` 的卡片版本曾完成线上 PCK 比对，SHA-256 为 `3f53d74ed57a004690683dac0a9ffc8d858a4d8e1ce08a7af8f904b2f26fe8c6`；这个哈希**不属于**最新 Boss 修复包。
- 仓库没有自动编译上传 CI。当前环境也没有绑定发布 secret；之前聊天中的凭据不能作为新会话依赖。主页封面/字体/描述更新是另一个流程，Butler 上传不会自动修改它们。

本次环境中可用的本地工具/产物（非持久依赖）：

- 引擎：`/workspace/Rogge-recovery-20261104T024444Z/godot-validation-tool/Godot_v4.7-stable_linux.x86_64`，已有日志版本 `4.7.stable.official.5b4e0cb0f`。
- 已安装 Web release 模板：`/home/agent/.local/share/godot/export_templates/4.7.stable/web_nothreads_release.zip`。
- 当前本地导出与本轮日志：`/workspace/Rogge-critical-glasses-20261104/web-build`；构建版本 `20261105-003002`。该目录使用 UTC 日期命名，版本号使用北京时间。测试/浏览器记录位于同级目录，Web ZIP 也在此处。
- 上次已上传导出：`/workspace/Rogge-boss-facing-20261104/web-build`，其 `itch-push.jsonl` 记录 build `2297831`。更早新卡版的线上比对在 `/workspace/Rogge-fan-blackhole-20261104/`。

## 8. 下一会话维护此文档

开始时核对 Git 和用户目标；结束时更新玩法提交、版本、实际运行的检查、发布与浏览器核验状态。把“代码已存在”“报告曾通过”“本次实测通过”“待验证假设”分别表述，不以旧聊天或上传成功代替证据。保持 `AGENTS.md` 简短稳定，把路径、进度和暂态问题留在本文件。
