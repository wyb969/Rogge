# ROGGE · AI 开发交接

## 2026-11-12 主分支发布整合（进行中）

- 用户授权将最新版合入主分支并更新itch。仓库实际默认分支为`master`，不存在`main`；不另建竞争主分支。已核对远端最新开发提交为`c6171513c438842ed4eade5a7bd5595aa51b6c79`，与11月10日一致。
- 隔离发布分支`release/master-itch-20261112`从master `7e81adf`合并完整开发历史，保留Cursor配色、22卡数值比较、移动/相机、脚下HUD、残影/投弹与命中反馈。仅更新版本与README发布说明，不修改游戏逻辑。新版本 **20261112-230737**（北京时间）。原工作树与未跟踪文件保留。
- 本轮Godot4.7两次导入、正常入口Web导出通过；7项实际导出PCK专项全过：palette、347项卡牌、32项移动、170项运动VFX、78项顿帧、异常跳字、dash无敌。正常Web Chromium900×600进入Debug第一项、两种真实受击按钮、Home通过，无脚本错误/WebGL丢失、无QA遥测。截图与本地构件哈希见`validation/master-itch-20261112-230737.json`。既有CLI退出ObjectDB/资源引用警告单独记录；没有Safari真机/完整流程结论。
- 下一步：PR合入master后，将最终master SHA与版本钉在PixelFishing `automation/rogge-itch-release`工作流；从17项扩至24项实际PCK检查，上传原`ybwangrogger/rogue-white:html`（upload20115514），使用Actions已有Secret。发布后记录CI清单、build/readiness和线上资源核验，不能用本地PCK哈希替代CI清单。


## 2026-11-10 命中白闪 / 受伤淡红与短顿帧（最新）

- 当前开发基线 `feature/vfx-motion-20261110` / `3f6375b08d378d7dafd8cbcc2d2a35ed97b7da5b`。按“玩家打中敌人白闪，玩家实际受伤淡红闪”实现用户要求；原句第二处对象重复，未收到相反澄清。沿用Cursor配色、卡牌/移动/冲刺/投弹修复。本轮版本 **20261110-194311**（北京时间），已同步并推送当前分支；已验证游戏源码 `2bc121dd64e5c84c92a8cd0ff563fff080e1a9a9`，后续仅文档。已更新 [PR #10](https://github.com/wyb969/Rogge/pull/10)，仍以PR #9分支为base，不合并master/不上传itch。
- `hit_feedback.gd` 是唯一战斗顿帧控制器：普通命中目标28ms、实际HP受伤65ms，临时速度0.05；全局普通命中间隔200ms，不续长；玩家受伤可升级正在进行的普通命中停顿，但总长不超过起始65ms，受伤独立400ms门限。全部使用真实时间截止，不为每次命中创建Timer/Tween/Node。恢复只处理自身持有的0.05，死亡0.08、Boss死亡0.06/0.2等外部慢动作优先。
- 同一个固定48槽轮廓池（玩家保留0号槽、敌方47槽），白色85ms、淡红115ms、同目标140ms间隔。复用现有unshaded轮廓shader，只读取源alpha；支持AnimatedSprite/普通帧表、UV、翻转、缩放和旋转。活着随sprite，致死后暂留捕获的真实帧，避免一击死亡看不到闪色。材质/中毒/冻结染色、碰撞与伤害数值不被覆盖。
- EnemyShell只对实际正伤害、非from_status请求新反馈；Boss仍经真实伤害和原冷却门限，但旧独立time_scale/异步Timer已改为委托共享控制器。持续毒/火和二次伤害不触发。玩家仅HP损失触发淡红；护盾完全吸收、Dash/军械无敌、受伤保护与0伤害不误触发。限时试炼保留闪色，不施加全局慢动作，以保护原始倒计时/锁定/闪避窗口。
- 移除玩家旧乘红闪烁循环和普通怪旧乘亮闪光，受击形变/击退保持；跳字放在轮廓上方并忽略时间缩放，血迹改用独立真实时钟，避免开始顿帧的同帧delta/新time_scale让新血迹突然前进。原2秒停留/2.5秒消失和Ink Surf判定不变。暂停、转场、休整、重试、结束、Home和释放节点都清理自身时间/快照。
- Debug首页新增 **命中顿帧 · 白色 / 淡红**，18项继续分页。复用既有安静测试场，按钮交替打普通怪/精英和走真实玩家受击流程；无自动投弹，原动态表现入口仍保留。新局/Retry/Home不继承状态。
- 证据与边界见 [hitstop.md](hitstop.md) 和 [validation/hitstop-20261110.json](validation/hitstop-20261110.json)。新增专项78断言已通过，另有反馈、状态字、无敌、Boss、试炼、血迹、彩墨和卡牌等回归；本轮14项不同原生、7项最终实际Web PCK专项通过。Chromium软件WebGL2桌面900×600、390×844/DPR2实际菜单/按钮已核验，白色与淡红真实渲染帧的像素明显高于基线，并观察到0.05短停顿和恢复1；Home清理通过。正常原始Web也测试进入新Debug、两种受击和返回主页，确认没有QA遥测。772个源/资源/素材与QA副本一致，只有QA main_scene不同；最新所有者私有试玩：<https://rogge-palette-playtest-20261109.whiteber.chatgpt.site>，当前账号登录，主页→Debug第一项“命中顿帧 · 白色 / 淡红”。Site source `560c995d874016a0204292a44d3a3e08d184c6b9`，deployment `appgdep_6af30946706c81918127f0cbff7e8675`，version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_a6d0af061d5881918249c5a0b21fc8a6`，北京时间2026-11-10 20:08:48发布succeeded。PCK `5e5461fca143823b3bb7deb49340a273bc131b1a3c93c508d52aa5d5232db837`；WASM解压/PCK原字节一致，11资产均低于25MiB；托管适配器/线上私有页未浏览器复测。软件浏览器的短闪色使用渲染完成帧读回，不延长/冻结游戏时钟；这只在QA入口启用，正常包入口没有采集开销。已有CLI退出资源警告独立保留，无Safari真机或密集怪性能结论。

## 2026-11-10 用 Cursor 配色替换两轮旧颜色（上一轮）

- 用户指定将 `cursor/color-palette-v4-4455` 的颜色用于当前开发分支，替代先前两轮配色。颜色来源已从远端核对为 `137fa6d7968617eefed4e19fad76cf0983e408d1`；当前开发起点 `feature/vfx-motion-20261110` / `d9dcb3da2447be5807f357204f06e0b2383c9cd9`。已在隔离integration工作树完成整理与验证，并快进同步/推送当前分支，已验证游戏提交 `ec012230bc0146e2b04653e25f9c36c48e198e9f`；后续仅发布记录文档。已更新 [PR #10](https://github.com/wyb969/Rogge/pull/10)，保持以PR #9分支为base。不改写历史、不合并master、不发布itch。
- 新版本 **20261110-150638**（北京时间）。`GamePalette`原始Cursor定义/方法保持完整，尾部只保留现有卡牌UI、脚下提示与残影所需的角色别名/中性样式包装；所有别名解析到同一套Cursor颜色。移除`semantic_ramp.gdshader`及全局`game_ui_theme.gd`，原贴图不再被上两轮色阶映射盖住。
- 同步Cursor共享body_tint、角色/怪物/Boss染色及状态恢复、原武器/无人机/金币/书卷/图标色彩、紫毒、红橙预警、原生命/经验条、技能/组合颜色、黑色椭圆影子与共享局部光、分关地面/装饰/暗角、灰色摇杆和Dash。第一关地面固定深青苔、后续按Cursor表轮换，替代旧三组随机色族。绿色生命条/蓝色经验条等以用户本次选定样式为准，不再套旧版“绿仅拾取”等条款。
- 保留卡牌数值前后比较、固定移速卡+20、实际参数共用计算、手机卡牌滑动与点击选择、17项Debug分页/设置持久化。移除全局主题后，卡牌独立使用Cursor中性面板，防止文字直接压在战斗画面上。普通伤害暖白、暴击金色及加大/加粗、异常黄→红恢复Cursor风格，同时保留当前的紫色毒伤通道。
- 移动/冲刺/投弹修复保留：左右步态、实际位移步频、无走路粒子、单层相机跟随、脚下HUD固定在Player、0.22秒/0.48透明度/8槽按距离残影、双投弹渲染插值；物理伤害时钟不改。静态审计确认14个核心文件与当前起点逐字一致、22个关键移动/卡牌/命中方法逐字一致；GamePalette原Cursor前缀逐字一致。
- 本轮专项与截图、构件哈希收尾见 [validation/palette-sync-20261110.json](validation/palette-sync-20261110.json) 和 [palette-sync.md](palette-sync.md)。原生已通过17项不同专项（含22卡347断言、运动表现170断言、真实120Hz渲染采样30Hz物理、Debug4654断言）；6项最终实际Web PCK专项通过；Chromium原始正常入口、横屏/竖屏固定场景（三种Cursor地面）、彩色与灰度、Dash四状态、数值卡牌、真实手机滑动不误选/点击选择均通过，无脚本/Shader错误或WebGL丢失。正常Web入口也保留键鼠/双指移动和Dash检查。仅QA副本启用固定场景与遥测，763个源/资源/素材文件逐字一致。旧配色文档已标记历史，数值/功能条款仍有效。
- 最新试玩：<https://rogge-palette-playtest-20261109.whiteber.chatgpt.site>（现有所有者私有权限，登录当前账号），版本20261110-150638；普通Start或Debug第一项动态表现均可。Site source `3c2a320bbf5b3bccdc815e4953eca5fa1ad9d585`，deployment `appgdep_6af2c579ccc481918e7dcf7d7d7b3550`，version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_40aa335d30148191b706ba6466e252b3`；北京时间2026-11-10 15:19:34发布succeeded。PCK `aaf96070a6579a70a6c095860ece1eefac0310e40eab2135f078b34a059188ab`；WASM解压/原PCK字节一致，11资产均低于25MiB。官方helper/浏览器工具缺失，沿用隐藏stdin普通Git与精确dist tar；托管适配器/线上私有页未浏览器复测。
- 边界：仅颜色/材质/UI外观替换，不回退卡牌功能、不调整伤害/冷却/移速/血量，不清理或覆盖用户工作区。CLI既有ObjectDB/资源退出警告独立记录；无Safari真机、全流程或密集怪性能结论。临时路径 `/workspace/Rogge-palette-sync-20261110T065217Z/` 不是持久依赖。

## 2026-11-10 彩墨提示 / 冲刺残影 / 投弹平滑（上一轮）

- 分支 `feature/vfx-motion-20261110` 基于已核对的移动分支 `cca3e4551270bcb805fbb14e8977f58418b0d209`；PR #9仍未合并，默认分支为master `7e81adf`。已提交 [PR #10](https://github.com/wyb969/Rogge/pull/10)（以移动分支为base），已验证源码 `53b9906f6c2b33af9fd053d3b1e54f6fca6278af`，后续仅收尾文档。本轮不合并master、不更新itch。版本 **20261110-132712**（北京时间）。
- 代码确认：彩墨提示与投弹均有30Hz重绘门限，提示另行采样玩家坐标；投弹年龄本来已经用physics delta推进，因此不称其为“没有使用delta”。旧残影仅0.10秒/0.16透明度，暗贴图乘色进一步削弱可见度。
- `ink_surf.gd`的3格与Label移入Player下固定`InkFootHud`，不挂AnimatedSprite，不拷贝世界坐标、不受冲刺拉伸；只有数值/增益动画/冷却改变时重绘，冲浪震波仍留在世界坐标。3处彩墨/6秒/60伤害/90半径与实际dash信号判定未改。
- `player.gd`沿move_and_slide后的真实路径每18世界单位留下残影，启动即有一帧，每物理步最多4次、总池8；0.22秒/0.48透明度。`combat_feedback.gd`新增一个共享绘制层和unshaded纯轮廓shader，青蓝色不再与暗贴图RGB相乘；保留旧ShadowTimer回调供兼容检查，正常冲刺不启动它。无走路残影/新粒子/逐残影节点。
- `arc_motion.gd`统一抛物线视觉（相同端点/高度/时长）。炸弹与EnemyAttackField记录previous/current物理年龄，在渲染帧使用Engine插值分数采样，空池停止process。命中/引信/冷却/落点锁定/来源死亡及控制取消/一次命中/上限不变；敌方危险激活仍以物理时钟立即切换。此方案最多落后一物理tick，不预测未来伤害。
- Debug首页第一项 **动态表现 · 彩墨 / 残影 / 投弹**：停普通波次、装备1级炸弹，固定两只耐久测试怪、自动每2秒重放双方实际投弹，敌方落点位于玩家下方90单位以避开脚下提示。该专属练习敌方伤害为0。按钮“重放投弹”“重置冲刺”；可上下走/任意方向冲刺，提供可再生彩墨。17个入口继续分页，CSS/DPR触控尺寸保留；Retry保留preset，Home/普通Start清除装备和练习UI。
- 本轮**11项不同原生专项、4项最终Web PCK专项通过**。新增170断言：脚下坐标随真实玩家且不随sprite形变、30/60/120Hz等间隔残影/弧线、真实120Hz引擎帧对30Hz物理（双方各>10个物理tick内中间采样）、渲染不推进伤害时钟、池上限/清理/实际Debug按钮/Retry/Home。其余覆盖彩墨、炸弹、战术怪、dash无敌/方向、步态、相机、反馈、Debug 4654断言和工具栏。
- 真实Chromium软件WebGL2：900×600及390×844/DPR2双指操作，实际Debug菜单/按钮、纵向HUD固定[-50,32]、冲刺残影、双方投弹、暂停/恢复、Home和普通原始Web入口通过；无脚本/Shader错误或WebGL丢失。正常入口不暴露QA遥测。763个脚本/场景/资源/素材文件与QA副本一致，仅QA main_scene加载专属观测入口。
- 限制：软件录屏渲染较慢，最终浏览器未观察到30Hz物理tick内的连续渲染对，不能据此做60/120FPS或真机性能结论；插值引擎专项由上述原生实际帧确认。Dash截图可能晚于短暂拖尾，活跃残影由遥测和录屏确认。退出ObjectDB/资源仍被引用警告独立保留。未做Safari真机、密集怪负载或完整游戏回归。
- 文档/命令：[motion-vfx.md](motion-vfx.md)；源/导出哈希、检查、浏览器数据：[validation/motion-vfx-20261110.json](validation/motion-vfx-20261110.json)。临时产物 `/workspace/Rogge-vfx-motion-20261110/`，不是持久依赖。已更新既有所有者私有试玩：<https://rogge-palette-playtest-20261109.whiteber.chatgpt.site>，当前所有者账号登录；主页→Debug→动态表现。Site source `81392fe86eead527db39049ef999ffdfef60545a`，deployment `appgdep_6af2ae797ea48191881a2d0420e9544f`，version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_5781671132748191936bf6e3b95e4e13`，2026-11-10 13:41:33北京时间发布succeeded，受众不变。PCK `4dbe4bd19f751aa64df913b2c827212e0351645379c032a1bec035d410747932`；WASM解压/PCK原字节和11资产25MiB限制均校验。官方Site helper/浏览器工具缺失，沿用隐藏stdin普通Git和精确dist tar；托管适配器/线上私有页未浏览器复测。

## 2026-11-10 玩家移动与跟随（上一轮）

- 新分支 `feature/player-motion-20261110` 基于v4 `a5e3b0e`，PR #7尚未合并，已提交 [PR #9](https://github.com/wyb969/Rogge/pull/9)，以v4分支为base保持增量清晰；不合并master/不更新itch。已验证游戏源码 `e24861d0f675c2a428fa817ae23d04794ea99217`，后续仅文档。
- 代码确认旧问题：固定5/6FPS、鼠标8向动画且站立仍播；走路反复触发无贴图旋转大方块粒子；像素角色持续缩放/旋转；相机内置平滑叠加意图速度拖拽。未证明move_and_slide位置积分本身错误，也不声称所有设备锯齿原因已排除。
- `player.gd`按move_and_slide之后实际位移驱动0/1/0/2侧向步态，50单位一周期，极快上限18姿态/秒。左右面向，不随鼠标转身；上下/停步保持上次侧向，停下/顶墙/锁定回中立帧，冲刺固定发力帧。360度移动/冲刺保留，闲置键盘冲刺改用最近移动方向。移速100、卡+20、加速900/摩擦600、dash780/0.14秒/结束0.5秒无敌/冷却均未改。
- 走路旧粒子隐藏且不发射，常态不旋转/伸缩；仅受击/冲刺有短形变，Sprite5/3缩放配1.8相机约3倍源像素，AtlasTexture开启filter_clip，碰撞体不变。残影仍8槽，改0.10秒/0.16透明度/0.035秒采样，不新增脚步节点或噪音。
- `camera_motion.gd`用实际世界位置单层临界阻尼跟随，响应20/冲刺30、最大16单位拖拽，禁用内置第二平滑；暂停冻结、240单位瞬移重置、舒适度0关闭、返回主页/新局清零，不改FOV/旋转。
- 11项不同原生专项、6项最终实际PCK通过；新移动32断言涵盖真实30/60Hz输入位移、加速卡、鼠标/上下/停步/顶墙、冲刺/锁定/清理，旧dash方向/无敌、相机、雪、卡牌/返回等通过。原反馈测试改用固定初始子节点数兼容已有DeathStains，并保留池/无新节点断言。最终原工程/QA无头导入与导出无脚本/shader/构建错误；已知退出资源警告保留。
- Chromium真实WebGL2桌面与390×844/DPR2触屏：55组运动数据、100→160步频/面向、无走路粒子/残影、相机≤16、双指摇杆/Dash、暂停恢复通过。旧v4与新正常入口相同键鼠序列也录屏，无脚本错误/WebGL丢失；天气随机不同，不是同场景性能对照。冲刺wait观察到true，随后截图可能已恢复，不误称都捕获活动帧。没有Safari真机/高刷新率/密集群怪性能结论。
- 文件/设计/命令/演示见 [player-motion.md](player-motion.md)，全部检查/原包哈希/QA源等价/视频记录见 [validation/player-motion-20261110.json](validation/player-motion-20261110.json)。截图/视频目录有 `.gdignore`不进入游戏包；测试入口preview_player_motion只在QA副本启用，普通游戏无测试键/遥测。临时产物 `/workspace/Rogge-player-motion-20261110/`。
- 下一步重点收集真机行走/反向/冲刺恢复观感与相机舒适度。保持表现位移和物理/数值分离，不能恢复鼠标转身、空转步态或叠加第二个跟随平滑。


### 移动优化试玩（已更新）

- <https://rogge-palette-playtest-20261109.whiteber.chatgpt.site> 已更新为本轮移动/相机版本，正常游戏入口，保持所有者私有。下文v4/PR #6的同URL发布信息是历史版本。
- Site源 `b9ce5cad9ad8e607d8180ba16f82c5f893c8e157`；deployment `appgdep_6af29d70514c8191ae932b511dd9e3f2` 返回succeeded（北京时间2026-11-10 12:28:52），version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_f11e69b5f9ec8191a62238a3687a73d0`。PCK `15a8dec5be3544b592eeb5e680ae99baa98a4b4970bee17ce10d88b8905247c3` 与已验证正常Web导出完全相同。
- 11文件字节/大小/JS语法检查通过，WASM gzip解压等价；没有改游戏或重复完整回归。Sites专用helper和managed浏览器仍不可用，使用隐藏stdin凭据/Git打包；线上私有页/托管压缩适配器没有浏览器复测。原始Web导出的桌面/触屏检查与平台发布成功分开记录，不作Safari真机承诺。
- 完整发布状态写入 [validation/player-motion-20261110.json](validation/player-motion-20261110.json) 的playtest字段；未改变itch或主分支。

## 2026-11-10 配色稿v4（本轮新PR）

- 主分支实际为 `master`，从最新 `7e81adf` 新建 `feature/palette-v4-20261110`。PR #6仍未合并，因此带入其三次提交（保留cherry-pick来源）后实现v4；下文PR #6旧色板与旧试玩是历史结果。已提交 [PR #7](https://github.com/wyb969/Rogge/pull/7)，未合并/未部署新包，版本仍为 `20261109-192900`。已验证游戏源码提交 `1389bc80b1cc2ccc5f7dbfb8cc35aa877e2315be`，后续仅补交接/记录。
- `GamePalette` v4：玩家/友攻青蓝，敌人按原型深红/橙/锈红，精英描边也属敌色；红色敌弹白芯红晕，预警红填充/亮红边/暗红内弧；毒紫、治疗绿、金币金、书本羊皮纸、护盾金，UI中性底色。功能技能边框按稿用玫红/浅黄/蓝/金；数量白粗黑描边。玩家原图片文件和角色碰撞均未改，仅加青蓝材质/局部轻光。
- **金币原始设计已读代码确认：金币就是经验载体，没有独立货币或另一套经验球掉落。** 按用户本轮明确要求恢复金色，仍由原接口给经验；回血球用#22C55E+白加号，保留#4ADE80独立有益拾取语义。不拆掉落、不改数值。继承卡牌比较及移速固定+20。
- 第一关四种暗青苔，第二关四种暖褐，第三关四种暗紫，后续色组轮换；同关缓存、不重复开局与单次随机抽取保留。现有地面shader增加世界噪点、平滑暗斑、轻暗角；72个草装饰池不扩容。未改敌人主题、刷怪比例、伤害/血量/时序。
- 黑椭圆阴影替换旧彩色脚底点；保留64怪阴影槽并覆盖EnemyShell子类，新增32拾取阴影缓存、最多8金币暖光，每0.1秒刷新、每类最多看128拾取。复用3批次与共享纹理，无逐怪/逐弹Light2D；四技能各加一个固定图标TextureRect以保留功能边框。超预算只舍弃装饰效果。用户控件大小/透明度/拖动设置保持。
- **17项原生专项、8项最终实际Web PCK专项通过**；卡牌347断言、伤害/奖励/碰撞/池上限均保留。最终原项目及QA无头导入/导出无脚本/shader/构建错误；冷缓存首轮与既有退出ObjectDB/资源警告如实记录。红弹按稿精确色，4.5:1检查改看实际白芯，不谎称红主体达到4.5。
- Chromium/WebGL2三视口900×600、390×844/DPR2、844×390/DPR2，39张彩色/灰度/三地面/DASH/卡片截图；另测手机滑动不选卡、点击领取与正常Web开始/移动/冲刺/短战斗，均无脚本错误或WebGL丢失。截图使用真实场景冻结夹具，仅QA入口不同；正常入口另测。没有Safari真机、itch iframe、全流程/怪潮性能结论。
- 规则/文件分组/图库/命令见 [palette-v4.md](palette-v4.md)，文件清单、源/包哈希、全部专项和浏览器结果见 [validation/palette-v4-20261110.json](validation/palette-v4-20261110.json)。16张精选图有 `.gdignore`，不进入游戏包。临时产物 `/workspace/Rogge-palette-v4-20261110/`。
- 后续重点：用户按稿试玩确认色彩；真机检查不同天气下的低饱和地面、怪物群/毒圈辨识与局部阴影开销。本轮没有新增玩法或已知未修脚本错误。PR评审/发布按新指令执行，不把PR #6旧试玩当v4包。


### v4试玩（用户追加要求，已更新同一站点）

- <https://rogge-palette-playtest-20261109.whiteber.chatgpt.site> 已更新至 **v4 / PR #7**，正常游戏入口；原所有者私有权限保留。下文PR #6曾在此URL部署的版本是历史记录。
- Site源 `3afc9220f0fe595f529bdecf355b30b423ddd97f`；deployment `appgdep_6af27b8ade18819193a1d4d2230df965` 返回succeeded，version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_7d3a43ad5490819199360a70c2677017`。游戏源码 `1389bc80b1cc2ccc5f7dbfb8cc35aa877e2315be`，PCK `5016e08eef0681e284b3675da654124630af93b0b91ee12f9abf07cf57b69087` 与已测试导出一致。
- 仅复用原包/处理托管gzip，未改游戏、合并master或发布itch。11文件校验、WASM解压等价、单文件25MiB限制、JS语法通过；没有重复全量回归。Sites专用helper/浏览器工具仍缺失，凭据仅隐藏stdin/子进程内存使用；托管gzip适配器和线上私有URL未做浏览器复测。平台succeeded只确认发布，原游戏17+8专项与Chromium结果单独保留。
- 发布记录：[validation/palette-v4-playtest-20261110.json](validation/palette-v4-playtest-20261110.json)。Site本地源仍为 `/workspace/sites/rogge-palette-playtest-20261109/`，不要仅按旧目录日期误判版本。

## 2026-11-09 统一颜色与卡牌比较（本轮PR）

- 从最新主分支 `master` / `7e81adf` 新建 `feature/palette-card-readability-20261109`；仓库没有 `main`。本轮只做视觉/UI/文案，已提交 [PR #6](https://github.com/wyb969/Rogge/pull/6)，未合并、未更新itch，版本仍为 `20261109-192900`。已验证源码提交 `c25e98347633b0ca591419b4e6f6c4f82f7f8ec9`；后续仅补本交接和记录。
- `GamePalette` 集中颜色与缓存材质：有益拾取/回血绿、毒紫、危险红橙、盾黄、控件灰白、友方攻击蓝白。毒染色/跳字与风追加毒伤一致；部分绿色敌人和武器原图通过共享ramp运行时重着色。玩家主体素材/场景与关卡地面、天气、音频、设置存储和战斗数值均未改。
- 灰白摇杆/冲刺保留用户大小、透明度与位置；按下1.06视觉放大、冷却遮罩、就绪短亮，触摸边界固定。统一中性按钮/主题和CJK提示字体。红色小敌弹增加浅红亮部，保持12种地面原有4.5:1专项阈值。
- `CardPreview`+`CardNumbers`覆盖22卡，读取真实控制器等级与共用数值helper，显示百分比/固定增幅及当前→下级；增益白、代价橙。用户明确确认**移速卡仍固定+20，只修文案**，首张100→120为+20%。纳入角色等级、双拳、生机组合、难度治疗倍率；不消耗战斗RNG。休息页同步。手机卡片可滚动，完整点击抬手才领取，固定换卡页脚。
- 23项不同原生专项、10项实际Web PCK专项通过；新 `smoke_palette_cards` 347断言逐卡比对真实升级，其他专项覆盖伤害/异常/碰撞与既有生命周期。最终导入、导出无脚本/shader/构建错误；已有退出ObjectDB/资源警告仍保留。没有跑全部smoke。
- Chromium/WebGL2的900×600、390×844/DPR2、844×390/DPR2，39张彩色/灰度/卡片/冲刺状态截图；实际触屏滑动不误选，点击选卡、正常Web入口短时战斗/移动/冲刺通过。截图使用隔离QA入口，游戏代码/资源与正常导出相同；不代表itch iframe、Safari真机、全流程或密集怪性能验证。18张精选截图有 `.gdignore`，只存Git不进入游戏包。
- 设计、文件分组、测试命令与图库见 [palette-readability.md](palette-readability.md)，完整源码清单/23+10检查/浏览器结果/哈希/限制见 [validation/palette-readability-20261109.json](validation/palette-readability-20261109.json)。临时构件 `/workspace/Rogge-palette-20261109/` 不作为持久备份。
- 后续：评审PR，重点真机检查手机竖屏滚动、不同天气下毒/经验/敌弹区分；本轮没有已确认的未修玩法bug。共享ramp不可逐怪修改，新增卡片应复用真实公式与统一formatter。发布itch需另按用户发布指令执行。


### 颜色与卡牌试玩（用户追加要求，已部署）

- <https://rogge-palette-playtest-20261109.whiteber.chatgpt.site>，新建的所有者私有Sites试玩，内容为 [PR #6](https://github.com/wyb969/Rogge/pull/6) 已验证源码 `c25e98347633b0ca591419b4e6f6c4f82f7f8ec9`；正常游戏入口，不是冻结截图夹具。该用户追加要求仅发布试玩；未合并master或更新itch。
- Site源 `9758813b365b394ae107910066197a84572d65e3`；deployment `appgdep_6af1e62ce8008191b4290a9d10773aea` 返回 **succeeded**，version `appgprj_6af1e5b586688191b2677024b2e27023~appgver_524d54826f648191a0d3fcd776bfaab2`。新Site默认私有，未更改受众或原有Sites。
- PCK `e4a8febdb76acdbf3c2c89875dac6fb92ea1924090ee0247efb8e2dccb61c12f` 与原验证导出一致；WASM用gzip适配托管大小限制，解压字节完全一致。原始JS/资源也逐文件校验，所有单文件小于25MiB，loader/engine JS语法通过。只复用已验证导出，没有重跑完整回归。
- 当前环境没有Sites提供的本地helper文件与managed `cua_repl.js`工具；用原生凭据经隐藏stdin完成Git/打包，未写入密钥；未另开浏览器路径。因此**托管gzip适配器和线上私有URL没有浏览器复测**；平台发布成功不等于Safari真机或线上完整游玩验证。记录见 [validation/palette-playtest-20261109.json](validation/palette-playtest-20261109.json)。临时Site源 `/workspace/sites/rogge-palette-playtest-20261109/`。

## 2026-11-09 主分支与itch最新版本（已完成）

- 基于已合并的master `c34a957`（[PR #4](https://github.com/wyb969/Rogge/pull/4)），在 `fix/beast-hover-ink-20261109` 修复用户追加的三项反馈，版本 **`20261109-192900`**。原开发分支工作区保留，没有清理/重置。
- `Spawner.spawn_boss` 删除神兽入场时的 `_clear_minions`；保留场上普通怪与已有敌弹，仍停止新刷怪。击败神兽、休整、跨关和Debug的显式清理保留，风系仍为两个Boss。
- `project.godot` 引用 `resource/ui_tooltip_theme.tres`，为全局 `TooltipLabel` 明确设置打包的像素/符号/中文字体链。Control本身字体override不会自动修复独立悬停提示。四个神兽和22种装备、组合提示均有实际字符覆盖，不依赖系统中文字体。
- 彩墨震波的粉红段改为青绿、浅蓝、白色三段，区别敌方红色预警。伤害60/半径90/冷却6秒与触发规则均未改。
- 7项不同原生检查、4项实际Web PCK检查通过。新增 `smoke_encounter_readability` 84项断言，覆盖四类入场保留小怪/子弹、双风数量、停刷/清理与真实图标字体；已有神兽主线/彩墨/布局检查通过。浏览器900×600 Chromium实战已查看两种装备的中文hover、真实冲刺彩墨冷却和返回主页，无脚本错误/WebGL丢失。短震波截图未捕获，配色由代码确认；神兽图标字符覆盖由原生/PCK检查，未声称浏览器hover验证。详见 `validation/encounter-readability-20261109.json`。
- 修复经 [PR #5](https://github.com/wyb969/Rogge/pull/5) 合入master `d9855b14cbdb5e2ef090d90a4c3e6e79ec995140`；README构建标识已同步192900，24处本地图均存在。今后从master继续切新功能分支，不要把旧开发工作区中的交接文档当作当前发布状态。
- [发布Actions](https://github.com/wyb969/PixelFishing/actions/runs/42609961711) success，17项实际PCK检查全过，官方4.7引擎/模板重新导出，ZIP每个文件与CI清单一致。冷缓存首轮导入警告保留，第二次导入和导出无错误。工作流提交 `083383d`，密钥仍只在Actions中使用。
- itch原通道 `ybwangrogger/rogue-white:html` / upload `20115514` 当前build **2339462**，版本 **20261109-192900**。[只读状态验证](https://github.com/wyb969/PixelFishing/actions/runs/42610504578) 已确认head为该build、state=completed且无pending，没有再次上传或重复游戏检查。
- **线上核验边界：** 主页持续HTTP429，无法提取实际iframe，因此没有完成线上PCK/WASM/JS哈希或itch iframe试玩。按旧版规律推测的两次CDN路径返回404，路径未由本轮页面确认，不能据此认定包损坏。后续等限流解除后提取实际iframe，与本轮Actions清单比对。不能把Butler的completed写成“页面所有资源已实测”。
- 报告：`validation/itch-release-20261109-192900.json`（CI清单/17检查）、`validation/itch-readiness-20261109-192900.json`（通道状态）、`validation/itch-live-20261109-192900.json`（未完成的页面核验）。仍无Safari真机/全量回归结论；现有退出ObjectDB/资源警告保留。未新增灯光、粒子节点或持续遍历。私有Sites试玩未同步此修复，最新正式入口为itch。
- 首轮master包 `20261109-191318` 已通过Actions run `42608443204` 上传build `2339415`，但HTTP核验两次被itch 429限流。已由192900/build2339462替代；不要将首轮构建的15项检查或哈希用于最终修复包。

## 2026-11-09 主分支整合（已完成，首轮发布记录）

用户本轮明确要求合入master、更新GitHub首页并上传最新itch包；下文各轮“未合并/不上传”是历史边界。

- 已在隔离分支 `release/master-itch-20261109-191112` 整合开发分支 `4406463` 与旧master `5971a4f`，保留两边提交历史。两处add/add冲突均为AGENTS/交接文档，按较新的完整开发记录解决；游戏业务代码与开发分支一致。
- 首轮整合版本 **`20261109-191318`**，采用北京时间打包标识。README已更新为22张卡、军械/生机组合、彩墨冲浪、8种小怪与新截图，并保留itch入口、六关/三试炼与操作说明。
- 发布选测15项实际Web PCK脚本，覆盖既有卡片/组合/试炼/菜单及新增血迹、彩墨、新怪与刷怪比例。不做全量61项回归；最终合并、Actions和线上资源核验以本节后续收尾记录为准。
- 复用PixelFishing独立工作流和原 `ybwangrogger/rogue-white:html` 通道；密钥只由Actions的 `BUTLER_API_KEY` 供给，不读取或复制其值。


## 2026-11-08 三种战术小怪（最新开发）

- 版本 **`20261108-010552`**（UTC日期11-07），基于 `13290f1`，继续 `feature/fan-black-hole-20261104`；未合并master、未更新itch。
- 普通池由5种增至8种：刃螳（锁定扇形近战）、回旋镖妖（慢速往返飞刃）、孢子轰炸菌（锁定落点的抛射炮击）。各有32px像素形状SVG和独立固定荧光死亡色，接原有伤害/异常/奖励/掉落接口。数值与躲法见 `docs/tactical-enemies.md`。
- `EnemyData.attack_style` +无Node的 `tactical_enemy_ai.gd` 组合到原EnemyShell；Archetype序号与旧行为保留，新远程仍为RANGED。新刃螳不作整关主怪；主题75%、早期远程5%/后期条件满足10%与共享存活上限保留。每轮20位置结束重建支援组合，避免新远程一直抽不到。
- Game持有 `enemy_attack_field.gd`，12个固定槽位、2个共享音效，无逐攻击Node/粒子/灯光；同时最多斩击3/回旋4/炮击3。预警与伤害同一锁定几何；刀刃145速度、连续路径含折返点检测，每次最多一次接触。身体朝向在蓄力时锁定，轻微碰撞反冲不会使其翻转。
- 击杀、冰冻、风/爆炸控制、明显位移取消攻击；角色dash/护盾仍走receive_attack，转场/休息/结束/主页重置，空池停工。源使用WeakRef，伤害后generation检查防同步清理继续旧循环。普通受击不持续打断。
- Debug新增第三项“新怪物 · 斩击 / 回旋 / 炮击”，共16项仍分页。训练场停普通刷怪、手动加入三只高血量新怪；新局/Retry保持preset但不向普通开局泄漏。神兽/试炼与木头人专用怪潮名单未改。
- 本轮14项不同原生检查、6项实际PCK检查通过；新怪专项72项断言，死亡血迹扩至281项、Debug覆盖16入口，当前61个smoke脚本未全量运行。原生GPU已核对新贴图、预警和生效攻击；真实Chromium分别用900×600与390×844/DPR2进行三种怪物实战、键盘/触屏dash和返回主页，无脚本/Shader错误或WebGL丢失。范围仅原始Web导出和软件WebGL2，不含Sites适配器浏览器QA；构件/退出警告见 `docs/validation/tactical-enemies-20261107.json`，没有Safari真机性能或玩家胜率结论。
- 临时产物 `/workspace/Rogge-new-enemies-20261107/`。后续重点收集支援怪频率、回旋返回是否看得懂、炮击/挥砍是否清楚可躲与手机密集场景性能。下次明确要求发布itch时纳入 `smoke_tactical_enemies`，本轮不触发跨仓库工作流。


### 新怪物试玩（已部署，2026-11-09恢复收尾）

- <https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，仍为所有者私有，访问范围未改。普通刷怪池会出现新怪；Debug第三项“新怪物 · 斩击 / 回旋 / 炮击”可直接练习。
- 版本 `20261108-010552`，游戏源码 `508c9d5321693bbe5b584a11c1f20a69e9f64367`，包含刃螳58单位停步与80单位内才出刀的收尾修正；后续文档提交不改变已验证的游戏包。
- Site源 `18a3e65ba3b3176e78f85d6da29026a3cadb76c2`；deployment `appgdep_6af12ef132948191b52591876b5e0e9c` 已返回succeeded；version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_3e5078576100819185d67523b12d8afc`。
- PCK `c9ccf78d37c07b5db7bb684865e5030abf049479ff2df0dc88e9005f6c53ceac`。恢复时确认代码与打包产物完整、游戏/站点工作区干净、远端分支匹配；归档、manifest与dist字节一致，PCK匹配原始已验证导出，WASM解压一致、每文件小于25MiB。
- 11-09仅复核现有源码/构件/远端状态并完成部署、更新文档，没有新增玩法或重新运行整套测试。上文14项原生、6项实际PCK和Chromium结果来自原开发验证；没有Safari真机性能或托管适配器浏览器QA。
- GitHub继续当前开发分支，未合并master；本次没有更新itch或触发PixelFishing工作流。发布与恢复核验记录已写入 `docs/validation/tactical-enemies-20261107.json`。

## 2026-11-08 定向泼溅与彩墨冲浪（历史记录）

- 版本 **`20261108-004105`**（UTC日期仍11-07），基于 `2330086`，继续 `feature/fan-black-hole-20261104`；没有合并master，没有更新itch。
- 原固定贴图展开改为48种不规则主痕迹+7个独立液滴。方向、延迟/距离/高度/飞行时长/尺寸均有变化；受力明确时沿前方窄锥喷射，无方向时四散。EnemyShell在伤害方向缺失时参考仍有效的风/爆炸/引力；Boss无方向则四散。固定怪种荧光色、2秒停留+0.5秒淡出与2倍基准保留。
- 一个MultiMesh节点预分配128组、1024个Quad实例、256×224共享图集；每帧最多20组，48主痕迹+8液滴图案共享，落地后停止几何更新直到淡出。没有逐死亡节点/粒子/灯光/计时器。满池仍多1次绘制调用；实例/CPU更新量增加，不等于手机成本不变。
- 新默认机制 `ink_surf.gd`：真实dash扫过3处已落地/未淡出墨迹，dash结束在终点释放基础60伤害、90半径、向外击退震波；6秒冷却。不需卡片或新按键。每处仅吸一次、每dash最多一发、伤害from_status不触发暴击/吸血/新异常；先设置冷却和终止追踪再伤害，自己的新血迹不能自续连锁。超220单位的瞬移不扫图。
- Player新增 `dash_started` 信号，Game持有/启动/重置InkSurf；Variety转场清理重置charge/冷却/瞬态，尊重暂停、死亡、木头人移动锁和试炼易伤。玩家脚下有3格充能、短音效、冷却条及三色短震波。详见 `docs/ink-surf.md`。
- Debug新增第二项“彩墨冲浪”，共15项仍分页；练习路径会刷新，退出/Retry/正常开局不会继承Debug路径。旧preset仍可调用，测试计数已适配。新局默认机制的趣味性尚待用户试玩，不是已证明的平衡结论。
- 12项不同原生检查与5项实际PCK检查通过，血迹275项断言、彩墨23项断言；未跑全量60脚本。原生GPU已核对飞行/落地/各方向与震波，动图 `docs/screenshots/ink-splash-motion.gif`。真实Chromium已验证键盘/手机尺寸触屏dash后的彩墨冷却状态及15秒木头人群怪，桌面补测等待落地墨迹后触发；无脚本/Shader错误或WebGL丢失。范围仅原始Web导出和软件WebGL2，不代表Safari真机或Sites适配器浏览器验证。构建哈希和退出警告见 `docs/validation/ink-surf-20261107.json`。
- 临时构件 `/workspace/Rogge-ink-surf-20261107/`；后续重点观察玩家是否会主动选择吸墨冲刺路线、3处/6秒是否合适，以及手机密集飞散帧耗时。本轮不触发itch工作流，下次发布应选测 `smoke_death_stains` 与 `smoke_ink_surf`。


### 定向泼溅与彩墨冲浪试玩（已部署）

- <https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，仍为所有者私有；普通对局默认启用，Debug第二项可用刷新墨迹练习。
- 版本 `20261108-004105`，游戏源码 `20d2a46e6f34a20b2a7106d391fec39c0f3a781b`；之后仅文档。Site源 `e0e22d18709487a60a00b6b4ffb0a6c656efc5e1`。
- Deployment `appgdep_6aef582b07488191a8c9acecb428f3bc` 已返回succeeded，version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_426a05f2979c819193f4b6f8ba85aec3`。
- PCK `ee3c927f007e3e57feeda5116e87fa3f813c5557dd7f6ebceec560b9f04a0908`；托管PCK与原导出一致，gzip WASM解压字节相同，所有资产小于25MiB，加载脚本未改且语法通过。Sites适配器没有真浏览器验证；原始Web导出有上文Chromium验证。
- 当前开发分支已推送GitHub，没有更新itch或触发PixelFishing工作流。

## 2026-11-07 荧光血迹与双倍尺寸（历史记录）

- 版本 **`20261107-201644`**，基于 `c803311`，仍在 `feature/fan-black-hole-20261104`；没有合并master，itch保持182118。本轮按用户要求调整血迹表现，不改战斗数值。
- 宽高各×2，保持随机12图案/旋转/拉伸/透明度；2秒停留+0.5秒淡出、世界坐标、128槽/每帧20处上限、暂停与清理规则保留。
- `DeathStains.PALETTE` 为17个命名类型显式配置荧光颜色（16种实际出场种类，另有风系基础键）。普通怪按EnemyData.title；宝藏守卫覆盖借用的追击数据；Boss/骑士/四神兽/双风角色/两试炼使用 `_death_stain_kind()`。精英与怪潮保留种族色，未知类型回退荧光粉。
- 已移除致命伤害/异常状态决定颜色的逻辑，也移除纹理颜色采样、缓存和预热。Shader使用浅色墨迹中心，不增加灯光/泛光/粒子。尺寸变大会增加像素填充量，不能仅凭绘制次数断言手机耗时不变。
- 6项不同原生检查、3项实际导出PCK检查通过，血迹专项230项断言，含所有普通怪资源、特殊怪/Boss类型映射与异常击杀不变色。原生GPU已核对16种配色、淡出和128处密集画面；隔离满池仍只多1次绘制调用。
- 报告 `docs/validation/neon-splashes-20261107.json`，设计/配色表 `docs/death-stains.md`，新截图 `docs/screenshots/neon-splashes-*.png`。原始Web导出在真实Chromium桌面900×600与手机390×844/DPR2视口通过Debug木头人、15秒实战与返回主页，均无脚本/Shader错误或WebGL上下文丢失；没有物理Safari实测或Sites适配器浏览器验证。退出ObjectDB/资源警告仍单独记录。
- 临时构件 `/workspace/Rogge-neon-splashes-20261107/`。后续新增怪种时明确补配色键，不能恢复按伤害变色；手机Safari群怪/天气叠加性能仍建议后续实测。本轮不触发itch工作流。


### 双倍荧光泼溅试玩（已部署）

- <https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，仍为所有者私有。版本 `20261107-201644`，游戏源码 `3e47faa8023199463d9f4a5c50c90382c11dd5c5`，后续仅文档记录。
- Site源 `ec0c91deed96fee2dcf529bcaabd7d0d6f57db30`；deployment `appgdep_6aef1804de448191b2a4ee6bad9e7d6c` 已返回succeeded，version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_6182f208c53081918252337f3c5bf6cf`。
- PCK `abefe582145be54fb7f457c5e1bfcd50a7b3d6fa4cc4f6d0e745e48838c51c67`；托管PCK与原导出相同，gzip WASM解压字节一致，所有资产小于25MiB，加载脚本未改且语法通过。托管适配器没有真浏览器验证，原始Godot导出有上文Chromium实战验证。
- 当前开发分支已推送GitHub；没有更新itch或触发PixelFishing工作流。下一次明确要求更新itch时，将新版 `smoke_death_stains` 纳入实际PCK检查。

## 2026-11-07 死亡血迹首版（历史记录）

- 版本 **`20261107-175332`**，仍在 `feature/fan-black-hole-20261104`；基于 `85189c2`，没有合并master。本轮只开发死亡地面泼溅，itch保持下文182118版本。
- `death_stains.gd` + `death_stains.gdshader`：一个MultiMesh节点、128槽、每帧最多20处，12种共享像素图案加独立随机旋转/拉伸/透明度，0.12秒展开、2秒停留、0.5秒淡出。世界绑定，位于角色/掉落下方，暂停冻结，空池停工；满池覆盖旧项，密集击杀可跳过超额装饰。
- 普通死亡采样原贴图颜色与本体tint；致命灼烧/毒/冰/闪电/炸弹/黑洞有独立暗色调。普通击杀带异常小怪也有状态回退颜色。缓存最多32种纹理色，开局和Boss准备时预热，不读取受击闪白。
- 小怪 `EnemyShell._apply_health_loss`、Boss致死分支统一接入；未改变伤害/异常触发/奖励。`CombatFeedback.reset` 与 `RunVariety.clear_combat_effects` 清理血迹。详见 `docs/death-stains.md`。
- 本轮16项不同原生检查、5项实际Web PCK检查通过；新增死亡血迹测试176项断言，当前59个smoke脚本，未全量运行。覆盖致死类型/奖励去重、随机流隔离、固定池/限流、世界坐标、暂停/hitstop/淡出、Boss和返回主页。
- 原生GPU核对调色/淡出/密集画面；隔离128处血迹只增加1次绘制调用。真实Chromium WebGL2分别用桌面与手机DPR2尺寸操作木头人、15秒群怪战斗和返回主页，无运行错误或上下文丢失。此为原始Web导出，不是Sites gzip适配器浏览器验证；软件渲染/手机视口模拟不代表Safari真机FPS。
- 报告 `docs/validation/death-stains-20261107.json`，截图 `docs/screenshots/death-stains-*.png`，临时日志/导出 `/workspace/Rogge-death-stains-20261107/`。已有退出ObjectDB/资源警告仍记录，未宣称解决。后续建议手机Safari观察群体死亡、雪雨/燃烧叠加性能；无额外新增功能待做。


### 死亡血迹试玩（已部署）

- <https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，继续所有者私有，未改变访问范围。普通开局或Debug木头人怪潮即可观察。
- 游戏源码 `d0c9e4c0d8a0aaf2ec4a6f1f2dd924c39249eed9`，版本 `20261107-175332`；之后仅文档记录。Site源 `c735b4ea74e160c3fad53d556ace708cea8f0de1`。
- Deployment `appgdep_6aeef83c6c74819189803de8c7201adb` 已返回succeeded；version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_ff3f51082ef88191b685cfd130da6878`。
- PCK `cc8853e9b119cb81e998f5a521f1130445b677eb77a17d764c40fa42bbc46e69`；托管PCK和原导出一致，gzip WASM解压字节一致、各文件小于25MiB，原加载脚本语法通过且未修改。托管适配器没有真浏览器验证，原始Web导出有上文Chromium验证。
- 已推送当前开发分支；本轮没有更新itch或触发PixelFishing发布工作流。下次明确要求更新itch时，应将 `smoke_death_stains` 加入实际PCK聚焦检查。


## 2026-11-06 itch发布（历史记录）

本轮用户明确要求把最新包更新到itch；此前各轮“itch不更新”为历史发布边界。本次仅发布现有版本，没有新增玩法或改动版本号。

- 线上版本 **`20261106-182118`**：<https://ybwangrogger.itch.io/rogue-white>。原 `ybwangrogger/rogue-white:html` channel、upload `20115514` 已更新为 Butler build **`2312775`**；没有新增上传通道或修改商店外观。
- 发布源码 `89545184f37fcb0ef8a47691ee216232a2ac7916`（实际玩法与UI提交 `2c63960dbacf6ca213c98bf14f5f294a13a84cc7`，其后仅文档）。包括炸弹/两套组合、木头人怪潮、Debug分页、粗体数字角标、小尺寸两列装备和右上角返回主页。
- GitHub Actions：<https://github.com/wyb969/PixelFishing/actions/runs/42213352444>，结论success。工作流分支 `automation/rogge-itch-release`，提交 `d8feb8285693b8ae03224c226a8c137b34fff92a`；仍由仓库 `BUTLER_API_KEY` 直接供给Butler，没有取回密钥值。
- CI用官方Godot4.7与匹配模板重新导出；10项实际PCK检查全部通过：菜单、芭蕉扇反馈、控制卡、返回主页、装备角标、木头人、试炼主线、生机、炸弹、军械。保留已有退出资源警告，运行/解析错误不忽略。不是全量58项回归，也不是真浏览器或手机实测。
- itch完成提取后，主页实际iframe为 `https://html.itch.zone/html/20115514-2312775/index.html?v=1793966190`。已下载PCK/WASM/JS核对大小和SHA-256，均与Actions清单一致；PCK为 `ee05299db173955074e7f1dde006b49bfd49b4556eacb8590c27c6f54ce04841`。
- CI重建PCK与Sites使用的本地导出PCK哈希不同；线上核验以对应CI清单为准，不将差异视作丢功能。两个入口的版本均为182118，托管产物与源码来源分别记录。
- 证据：`docs/validation/itch-release-20261106-182118.json`、`docs/validation/itch-live-20261106-182118.json`。Actions artifact `13500117886` 保留到2026-12-06；临时构件和核验脚本在 `/workspace/Rogge-itch-update-20261106T1100Z/`，长期摘要已入Git。
- 下次发布复用同一工作流/通道，按新功能调整聚焦检查名单。itch提取期间可能返回load_url；就绪后iframe可能直接放在主页的转义data-iframe中，不能假设一直存在load_url。更新流程见 `docs/ITCH_PUBLISH.md`。

## 2026-11-06 紧凑装备栏与返回主页（最新开发）

- 版本 `20261106-182118`，仍在 `feature/fan-black-hole-20261104`。用户反馈装备图标太大：去掉上一版竖屏2×放大，scale最多1，只按高度预算缩小；从2件起两列。右下角粗体数字与1.5×组合流光保留。
- 在原FullscreenToggle中加入返回主页按钮，与全屏同高、同样式、间隔8逻辑像素并排。CanvasLayer升到160，暂停/试炼/奖励页上也可点击；主页与结算页隐藏这个额外按钮。
- Main复用结算页返回路径，结束旧局并创建新的准备场景；防重复点击/返回期间开局，清理移动锁、怪潮、装备状态与输入。死亡慢动作中退出会移除SceneTree标记并恢复时间，防旧结算回调。
- 手机输入层优先让出工具栏区域，用户自定义摇杆/DASH位置也不会吞掉按钮点击。全屏处理逻辑保留，原生GPU已实际验证进入/退出全屏。
- 新增 `tools/smoke_session_toolbar.gd`（50项断言），覆盖真实GUI点击、布局、触屏优先级、暂停/活动试炼、死亡慢动作退出、连续点击、结果返回。6项原生与4项实际PCK检查通过，报告 `docs/validation/session-toolbar-20261106.json`；当前58个smoke脚本，未全量运行。
- 原生GPU截图 `docs/screenshots/home-toolbar-*.png`；没有真实浏览器/手机QA。已成功更新现有私有Sites，itch不更新。

### 返回主页与小图标试玩（已部署）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，所有者私有、访问范围不变。进入任意普通/Debug对局，在右上角点击返回主页；说明页和暂停时也可使用。
- 版本 `20261106-182118`，游戏源码 `2c63960dbacf6ca213c98bf14f5f294a13a84cc7`。后续文档提交不改变导出。
- Site源 `4931473d2fc3f7b06066e92bdc9d4046f279a102`；deployment `appgdep_6aedaaf99db081919bba9c38615e41cc` 返回 succeeded；version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_28331672fb148191b75285d45b344b36`。
- PCK `38fc64033844266a6b99b2510aeb21abed186057af8bafa06f616852b8d2395e`，托管PCK哈希和WASM解压字节一致、单文件小于25MiB。加载脚本未改；没有浏览器/物理手机QA。
- 代码已推送当前开发分支。itch仍为 `20261106-011424`，本轮未触发itch工作流。

## 2026-11-06 木头人挑战与装备角标（上一轮记录）

- 版本 `20261106-174113`；仍在 `feature/fan-black-hole-20261104`，未合并master。22种装备的数值/卡片上限未改。详见 `docs/wooden-trial.md`。
- 组合边框线宽×1.5，围绕完整图标框，保留两组颜色和同步相位。移除右侧Lv.N，改为图标右下角粗体纯数字与深色描边，留出彩色边缘；调整槽位和竖屏缩放，22项装备/等级6均有布局检查。
- 用户确认是“潮水般涌来的怪物”。速度试炼结果的继续/放弃都接木头人说明页；木头人存活60秒通过，之后结算或自由试炼。速度页不再直接绕过挑战结算。开始/重试补满血，保留构筑和神兽技能。
- `Trials`新增wooden类型及 `wooden_trial.gd`。每20秒一波，最多32/52/72怪，小批量刷怪，无卡顿后补刷。复用EnemyShell/伤害/奖励接口，HP270/400/530按难度一次缩放；接触伤害14/18/22，避免叠加后期威胁倍率。木头人地面标记无新增粒子/灯光。
- Player权威移动锁同时阻止键盘、触屏和直接dash；取消旧dash/grace，仍处理受伤和被动回复。挑战期间隐藏摇杆/DASH，左侧神兽技能可用；结束、失败、Retry、回主页/新局清除锁与怪潮。
- Debug首项新增木头人60秒预设，现14个测试入口；原测试脚本已适配新增关卡，保留分页和诊断。
- 真实原生60秒样本：斧2/书1/枪6及已获得技能，346次生成、274击杀，末尾886/1150HP；采样峰值71怪。仅一局平衡样本，非胜率/手机性能结论。实战发现并修复死亡对象TypedArray失效引用，改WeakRef并新增释放回归。
- 本轮18个不同原生检查和6项实际导出PCK检查通过（含木头人49项断言）；共57个smoke脚本，未全量运行。报告 `docs/validation/wooden-trial-20261106.json`。原生GPU已核对装备角标、手机说明页、横屏怪潮；浏览器工具缺失，无物理手机/真实Web实测。已成功更新原私有Sites，itch不更新。

### 木头人挑战试玩（已部署）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，所有者私有，访问范围未改。主页 → Debug第一项木头人挑战；自然流程为速度试炼结果 → 木头人说明页。
- 版本 `20261106-174113`，游戏提交 `250680bbeec4ab84fc8aedc1dc72f3fc8d5b8ab6`。后续文档提交不改变已导出代码。
- Site源 `7efaf06dbedc64fb4d38e82c4351c10b5a8913de`；deployment `appgdep_6aeda279db1c81918a258a9b57c8c109` 返回 succeeded；version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_dd8d1107c62c819189199ec1a12f17f6`。
- PCK `9332ce09b296d4d2e9508391a24173285144f05c4ba90c02de78d27a3d35ce90`。托管PCK一致，gzip WASM解压字节一致，每个资产小于25MiB，加载脚本未改。没有浏览器或物理手机QA。
- itch仍为 `20261106-011424`，本轮未触发PixelFishing发布工作流。下一次更新itch建议纳入 `smoke_wooden_trial`、`smoke_equipment_badges` 与新试炼流程检查。

## 2026-11-06 Debug 清理与手机分页（上一轮记录）

- 版本 `20261106-170834`；开发仍在 `feature/fan-black-hole-20261104`，master 未合并。玩法和装备数未改。
- 清理恢复基线的21个旧测试按钮，保留11月4–6日新增的13个入口，以及返回和诊断导出。恢复包没有旧按钮原始日期，不能证实每项都早于11月；当前按“恢复基线旧测试 / 恢复后新增测试”的边界清理，非逐项日期证明。详见 `docs/debug-menu.md`。
- `DebugCenter` 从长 ScrollContainer 改为固定分页面板；窄屏单列最多4项，宽屏两列最多6项，按可用高度缩减。第一页重新打开；横竖屏重排尽量保留原首项，上一页/下一页/页码/返回/诊断位置固定。13个入口在常见竖屏分4页。
- 用 viewport final transform 和Web画布CSS宽度（扣除DPR）将48px测试按钮、44px底部按钮和字体换算到逻辑坐标，修复900宽逻辑视口在手机上缩小点击区的问题。Debug按钮不再使用主页1.15倍放大/旋转脚本；长文字/导出信息省略显示，不扩大布局。
- 保留历史 `_launch_run` 场景和 prepare helpers，8个旧检查改为直接调用预设；音乐回调已兼容试听按钮被移除。近期卡片与组合的真实按钮绑定保留，普通开局不带Debug装备。
- 聚焦检查：14个不同原生脚本通过，实际导出PCK的4项检查通过。Debug检查覆盖7种窗口尺寸及DPR2/3横竖屏模拟、所有页面、触摸高度、重叠/边界、导出、Back、连点、Retry与普通开局隔离。没有运行全量55项。
- 原生GPU已核对390×844、320×568、844×390及竖屏末页截图。工具缺少Sites要求的浏览器控制能力，未做真实浏览器/物理手机验证；退出时已有ObjectDB/资源警告另记，不能当成已解决。
- 报告 `docs/validation/debug-pages-20261106.json`，截图 `docs/screenshots/debug-pages-*.png`。Web导出与日志临时路径 `/workspace/Rogge-debug-pages-20261106/`。
- 已成功更新原有所有者私有Sites试玩；本轮不更新itch，itch仍是 `20261106-011424`。

### Debug 分页试玩（已部署）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，所有者私有，访问范围未改。主页 → Debug → 上一页 / 下一页；手机横竖屏均支持。
- 最终版本 `20261106-170834`，游戏源码 `7c6ee122b5e3f68698a153ac84af4bf718a25d58`，包括Web画布CSS/DPR换算；首版菜单提交 `aa65a27`。文档提交不改变导出。
- Site源 `041fd16f1f9e44359aa7523e298024e33b33efa7`；deployment `appgdep_6aed99de54b4819185c3861007917a99` 返回 succeeded，version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_dac36fc48dec8191aa9994bd24a8429b`。
- PCK `3669159b8004b981c340001e3f0fc480f8777951c720d1f007afee81c17b9689`；托管副本PCK一致、gzip WASM解压后字节一致、所有文件小于25MiB，加载脚本未改。
- DPR补充后重跑2项原生菜单检查和4项实际PCK检查；另外12项为本任务较早的聚焦检查，玩法未变。Node单元检查了15个CSS宽度组合和5个缺失canvas id回退，原生测试模拟DPR2/3的横竖屏；仍不代表真实浏览器/手机实测。

## 2026-11-06 生机组合与同步装备流光（上一轮记录）

- 新增生机组合：`pickup_up` + `speed_up` + `regen_up`，各至少1级，经验获取+30%、最终步行速度+20%、回复效果+20%。没有增加卡片，仍22种。详见 `docs/equipment-combos.md`。
- 当前版本 `20261106-161319`。已成功更新现有私有Sites试玩，itch仍为 `20261106-011424`，不触发跨仓库上传工作流。
- `equipment_combos.gd` 集中成员/颜色/倍率；军械控制器引用同一成员定义。生机图标荧光绿，军械图标金色；`equipment_combo_border.gd` 复用顶点，由装备栏一个时钟约30Hz驱动，组内颜色/相位严格一致，最多6个边框，无额外粒子或灯光。
- 经验加成只在实际领取时叠加到难度处理后的值，直接/预备/合并/全图拾取走统一入口。整数十分之一累计余数，避免小额币重复舍入。角色使用独立移速/回复倍率，不覆盖难度，不重复累乘；生命成长和dash参数保持原值。
- 休息页确认回复奖励也同步装备栏并补齐组合；暂停冻结边框；转场保留被动与余数，新局/回主页清理。
- 检查时修复了旧的共享拾取形状泄漏：每个Player复制自己的CircleShape2D，重试/新局不再继承变大半径。校正旧visual_style检查的默认燃烧断言，书本伤害代码未改。
- 当前162个GDScript、55个smoke脚本、22种装备。19个不同原生检查、6项实际PCK检查通过；新组合测试61项断言。原生GPU核对两组颜色和不同相位截图，未做浏览器/物理手机实测。
- Debug新增 `growth` 与 `equipment_combos` 入口。报告 `docs/validation/equipment-combos-20261106.json`；游戏提交 `d5688bced318369b0c4e05922f4c3a1e6ef7fc88`，后续文档提交不改变已部署代码。

### 生机与双组合试玩（已部署）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，仍为所有者私有页面。主页 → Debug → 测试生机组合 / 测试双组合（荧光绿 / 金色流光）。
- Site `appgprj_6aeb66ad64408191b317328a1063f65c` 继续复用，deployment `appgdep_6aed8f1d38f88191b3ae277fea3a6c8e` 已返回 succeeded。
- Site version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_5cd818196ce48191bef756c761e8004a`；独立托管源提交 `5ab723016ae26968a23f376f076d81fe158f21fd`，锁定游戏提交 `d5688bc`，PCK `18dc58d1967eb3ccd7ea46707470b51a07e204602f656e790488534c1856a62a`。
- 继续使用已有 gzip WASM 适配；检查了PCK、WASM字节和每文件大小限制，加载脚本未改。浏览器工具仍缺失，没有真实网页/手机试玩。
- 本次没有更新itch，也未触发PixelFishing上传工作流。后续发布itch时，建议将 `smoke_growth_combo` 纳入聚焦检查清单。

## 2026-11-06 炸弹卡与军械护盾（上一轮记录）

- 本轮新增 `bomb` 炸弹卡及枪支/无人机/炸弹三件套，详见 `docs/bomb-arsenal.md`。开发分支仍为 `feature/fan-black-hole-20261104`，不合并 master。
- 当前游戏版本 **`20261106-015912`**；已成功更新现有 Sites 私有试玩，itch 当前仍是上一轮 `20261106-011424`，不要混淆两个托管入口。
- 炸弹最高5级：伤害50→110、半径70→118、间隔4.8→2.50563秒；有限抛物线投掷与引信、径向冲击和视觉腾空。直接伤害可暴击/使用已拥有被动，本身不默认点燃、不递归爆炸；Boss/试炼的位移抗性与易伤窗口保留。
- 军械组合以实际装备等级>0判断，集齐后第3/6/9秒各获得1秒无敌；独立 `arsenal_shield_active`，不覆盖 dash grace、玉佩护盾或速度试炼的 dash-only 条件。暂停冻结；休息/转场清当前窗口、保留资格；死亡/新局清理。
- 新模块 `bomb_controller.gd` / `arsenal_combo.gd` 接入 Game 创建、升级、重置与 `variety.clear_combat_effects()`；Debug 有1级/5级炸弹及三件套入口。
- 目前159个GDScript、54个smoke脚本、22种装备。19个不同原生检查、5项实际导出PCK检查通过；真实原生GPU截图已核对。浏览器工具缺失，本轮无浏览器/物理手机试玩，退出时资源警告保留记录。
- 证据：`docs/validation/bomb-arsenal-20261106.json`、`docs/screenshots/bomb-*.png`、`arsenal-shield.png`。游戏提交 `fe2ddb06d2563073eb6bc3174f5d17101ecb27da`；后续文档提交不改变已部署代码。

### 本轮试玩（已部署）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，仍为所有者私有页面。主页 → Debug → 测试炸弹1级 / 5级 / 军械组合。
- Site `appgprj_6aeb66ad64408191b317328a1063f65c` 继续复用；deployment `appgdep_6aecc593a18c819199a4d9d5ddfceecd` 返回 succeeded。
- Site version `appgprj_6aeb66ad64408191b317328a1063f65c~appgver_ef6be86998c48191877b273f74a8e125`；独立托管源提交 `ebba7e7d3fed02c6aa073df5b922996efc939fc5`，锁定游戏提交 `fe2ddb0` 与 PCK `d2d9b800dfa880afce95d1a76002e7169935d7bf6d7958df1131103eb3db2c2c`。
- 继续使用原有 gzip WASM 加载适配，Node 检查了实际解压字节、已由服务器解码的分支、碎片化响应前缀与 PCK 请求透传；不等同真实浏览器试玩。
- 本次没有触发 PixelFishing 的 itch 发布任务。若之后要求更新 itch，使用 `docs/ITCH_PUBLISH.md` 的原 channel，建议给 CI 选测清单加入 `smoke_bomb_card` 与 `smoke_arsenal_combo`，并将源码/版本一同更新后再推工作流文件。

## 2026-11-06 itch 发布完成与趣味性讨论

用户本次明确授权现在更新 itch；下文“明天上传 / 本轮不上传”为上一轮历史约束。本轮没有新增或调整玩法。

- 开发继续使用 `feature/fan-black-hole-20261104`。本次先在独立发布分支 `release/itch-20261105-171424` 准备，发布后将版本与文档快进同步到开发分支；不合并 master。
- 线上版本为北京时间 **`20261106-011424`**，对应发布源码 `4f8577fb7704426df5bae9d7eb147d042dcd431c`，玩法仍为 `c6c0e600943f78da2a333b4f76486e5dbc378996`。后续文档提交不改变发布包。
- 已用官方 Godot 4.7 与匹配模板导出；本地和 Actions 分别通过实际 PCK 的主页布局、芭蕉扇反馈、控制卡片 3 项检查。历史退出 ObjectDB/resources-in-use 警告保留；本轮没有浏览器或物理手机试玩。
- 已更新原 `ybwangrogger/rogue-white:html` channel，upload `20115514`，Butler build **`2307264`**。itch 公共 iframe 已返回新构建，PCK/WASM/JS 三项字节数与 SHA-256 均匹配 Actions 构建清单。
- 在线 PCK：`24de0b0de69c512b0e43fdd104f6c713e91860bc6d0c1321043da527ff7fa458`。本地另一次导出具有不同哈希，不能误当作已发布包。
- Actions 成功记录：<https://github.com/wyb969/PixelFishing/actions/runs/42073745113>。密钥是 PixelFishing 的仓库 Actions Secret `BUTLER_API_KEY`，工作流直接使用，没有取回其原值。当前开发云端没有绑定该变量。
- 独立发布工作流位于 PixelFishing 的 `automation/rogge-itch-release` 分支，文件 `.github/workflows/publish-rogge-itch.yml`；下一次更新完整 `ROGGE_COMMIT` / `BUILD_VERSION` 并推送该文件，会重新编译、聚焦检查、保存构件和上传。详情 `docs/ITCH_PUBLISH.md`。现有 PixelFishing 默认分支发布流程未改。
- 发布证据：`docs/validation/itch-release-20261106.json`、`docs/validation/itch-live-20261106.json`。HTTP 资源比对不等于浏览器游玩验证。Actions artifact 保留 30 天，源码和概要已经进入 Git。
- 趣味性讨论写入 `docs/ROGUELITE_FUN_REVIEW.md`：先验证现有聚怪控场、异常走位、暴击直伤是否形成不同打法。方案尚未实现或经过玩家测试。特别注意：芭蕉扇原本已读取冲刺/最后移动方向，无需再次实现“冲刺定向”。

更新日期：2026-11-05（北京时间，UTC 为 11-04）。本轮将芭蕉扇升级冷却改为×0.7，汽油瓶间隔整体缩短25%，并添加异常追加的深红/深紫身体变色与双异常过渡。已有灼烧/中毒额外一跳及每目标去重保持。伤害、范围、击退成长保留，详见 `docs/control-cards.md`。之前的暴击眼镜与默认点燃修复保持，详见 `docs/critical-glasses.md`。

## 1. 先找到正确的代码

| 项目 | 已确认状态 |
| --- | --- |
| 仓库 | <https://github.com/wyb969/Rogge> |
| 最新玩法分支 | `feature/fan-black-hole-20261104` |
| 最新玩法 | `d5688bced318369b0c4e05922f4c3a1e6ef7fc88`：生机组合与同步装备流光；之后文档提交不改变游戏 |
| 上一玩法提交 | `ebc67f49d6d46e821230d1da3a6b9bd849a6f72a` 为异常追加；`71ada60` 为暴击眼镜/默认点燃，`8bc1fa0` 为 Boss 转向，`04281a9` 为芭蕉扇/黑洞 |
| 默认 `master` 的代码基线 | `d684fa41d9afac8879422c2baf9917996b8f8778`，尚无上述玩法更新 |
| 合并状态 | [PR #3](https://github.com/wyb969/Rogge/pull/3) 在检查时 open、未合并；不要假定已进入 master |
| 游戏版本 | `project.godot` 为 `20261106-161319`，本轮Sites试玩；itch为 `20261106-011424` |
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

- Godot **4.7**，GDScript；当前有 162 个 `.gd` 文件、55 个 `tools/smoke_*.gd` 脚本。没有额外的 npm/Python 运行时依赖。ROGGE 自身仓库没有 Actions 工作流；跨仓库的独立发布任务已在 PixelFishing 验证成功，见文首与 `docs/ITCH_PUBLISH.md`。
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
- 芭蕉扇通过目标的 `get_status_echo_damage(poison_tick)` 读取命中前的已结算数值，再发送独立 `fan_status_bonus` 命中；`damage_is_final: true` 仅用于这类内部已计算的追加，避免再次乘方向/冻伤/暴击或减免。同时使用 `from_status: true`，不复制原始 effect，不重加状态或触发传播；Boss/试炼仍经过它们的 `apply_hit` 保护。

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
| 6 | 熔岩/岩火神兽；领取后进入速度试炼 → 木头人60秒怪潮挑战，之后自由挑战或结算 |

- 宝藏守卫：**第三关经过 24 秒**触发。第三关主 Boss 要求**有效运行计时至少 210 秒（3分30秒）、守卫已解决且抽奖已领取**。不是“第四关固定出现”，也不是只看经验等级。暂停、休息、转场不积累该计时；有效 Boss 战时间计入。
- 每关从合理背景池、主力怪池中选择；20 槽怪物配比中 15 槽为主力，另有少量辅助/远程。第一关远程存活上限早期为 1、升级后为 2；后续随关卡和玩家等级增长。
- 简单：普通怪/Boss 血量×0.5，经验及治疗×1.5；中等维持×1；困难血量×1.5。设置在新局快照生效。
- 玩家每次升级增加最大血量并恢复对应的 25 点；敏捷怪有冲刺节奏、命中后停滞，避免持续贴身扣血。
- 力量试炼：介绍后开始，60 秒内击败慢速高血量机械敌人，锁定音与激光预警。速度试炼：瞬移近身，0.5 秒预警斩击，成功 dash 躲开后有 1.5 秒反击窗口，不限总时间。

### 卡片、神兽技能和输入

当前选卡池及装备定义均为 **22 种**；稳定 ID 如下：

- 武器：`axe_up`、`circle_up`、`gun_up`、`drone_up`、`molotov_up`、`freeze_up`、`bomb`。
- 成长/生存：`pickup_up`、`speed_up`、`left_fist`、`right_fist`、`regen_up`、`lifesteal_up`、`shield_up`、`monster_necklace`。
- 机制卡：`lightning_ring`、`wind_emblem`、`echo_ember`、`poison_trail`、`banana_fan`、`black_hole`、`critical_glasses`。

左右拳卡是方向伤害加成，并非独立拳击武器。斧头和环绕书开局已有 1 级；其余按各自控制器判断，不要由显示文字推断是否已装备。

- 芭蕉扇：最高 5 级，沿冲刺/最后移动方向吹击，基础伤害 12→28，距离 130→230，冷却依次为 3、2.1、1.47、1.029、0.7203 秒；单次气流每敌人只命中一次，实际击退身体、产生有限气流扰动，可打断敏捷怪冲刺。已有灼烧/中毒各补一跳，合并一次追加和一个伤害字，不改原计时/层数，不递归、不主动传播、不再暴击或吸血；新附燃不参与本次快照。
- 追加颜色反馈：`status_echo_feedback.gd` 为芭蕉扇的一个共享子节点，48个固定记录、一个材质、约30Hz绘制，显示约0.34秒。通过 `status_echo_flash.gdshader` 按亮度重新着色实际动画帧，燃烧深红、中毒深紫、双异常红转紫；不改演员颜色通道/碰撞/动画，不逐怪创建节点或光源，重复目标复用同一记录，暂停/删除/转场清理。
- 汽油瓶冷却：`molotov_controller.interval_for(rank)` 统一控制器与卡片说明，间隔为旧公式×0.75，一级2.8875秒、五级1.8375秒、下限1.2秒；升级截短过长的待投掷冷却，伤害/层数/附燃概率不变。
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
| `docs/validation/fan-status-20261105.json` | 19/19 个不同原生检查、3/3 导出 PCK 检查 | 当前芭蕉扇更新，覆盖密集群怪去重、无额外传播、异常时钟、倍率、奖励、Boss/试炼、五级真实自动冷却和 Debug/Retry |
| `docs/validation/fan-feedback-20261105.json` | 14/14 不同原生检查、3/3 PCK检查 | 当前冷却/身体变色版本，另有实际原生GPU截图验证帧/朝向/颜色与淡出；不代表浏览器QA |
| 导出 PCK 内测试日志 | 新卡、最新 Boss 转向检查通过 | 当时云端 `packed-control-smoke.log`、`packed-boss-facing.log`；属于原生引擎加载实际 PCK，不是真浏览器 |
| `docs/screenshots/` 四张新卡截图 | 有实际运行截帧 | 原生运行截图，不是 Safari/itch 浏览器截图 |

当前共有 55 个 smoke 脚本，**没有最新版本全量 55/55 的记录**。生机组合版本选测19项并验证6项PCK，详见文首。炸弹版本选测19项并验证5项PCK，详见文首和对应报告。历史报告不能相加当作独立功能数，也不保证所有分支当前都通过。暴击眼镜版本选测 27 项；本轮芭蕉扇更新选测 19 项，最新新增试炼保护断言后重跑芭蕉扇检查，最终 PCK 内再检查 3 项。旧原生截图保存在 `docs/screenshots/critical-glasses-*.png`。

上一版 `20261105-003002` 的本地 Chromium 155 检查覆盖启动、满级暴击、移动与竖屏，控制台错误为 0。本轮身体变色版的浏览器 QA 尚未完成：环境没有该技能要求的 `cua_repl.js` 工具，按技能跳过浏览器 QA；已有引擎、实际 PCK 和试玩资源加载脚本检查不能代替当前浏览器/物理手机验证。

最新 Boss 修复的代码与测试共同确认：WAIT 追击时朝向玩家并播放循环 walk；RECOVER 每帧更新朝向，冲刺结束立即转向；蓄力/冲刺保持锁定方向，细小横向差有防抖。旧“冲刺后倒着滑行”的修复位于 `boss.gd` 与 `tools/smoke_boss_facing.gd`。

## 6. 尚未完成、已知问题与复现

1. **分支尚未合并。** PR #3 open；下一会话不能只在旧 master 上继续加功能。合并、扩大功能范围按后续用户指示处理，本次没有合并游戏代码。
2. **最新在线资源核验已完成，浏览器/手机试玩仍待进行。** 本轮版本 `20261106-011424`、build `2307264` 已上传且线上 PCK/WASM/JS 匹配 CI 清单。之前 `20261104-233814` 遇到 429/404 的未完成记录已被本轮新发布核验覆盖；本次也曾遇到提取等待与 429，退避后成功。不能由资源哈希一致推断 Safari 游玩已通过。
3. **别的电脑偶发启动报错，用户已要求暂不处理。** 现象为 Godot 加载时弹出 `Couldn't load project data at path "/". Is the .pck file missing?`，尚未进入游戏。用户自己的电脑、手机未复现；Win7 只是用户猜测，没有确认系统、浏览器、网络请求或根因。只有用户重新要求时，才收集那台机器的浏览器版本/控制台/网络失败信息；不要顺带改导出加载器。以前的实验留在项目外 `deferred-web-investigation-20261104/`，未合入、未发布。
4. **诊断 helper 漏打包已确认并修复。** 本轮 Chromium 复现 `RoggeDiagnostics.previous` 未定义，原 PCK 确实缺 JS。Web include_filter 加入该文件后重新导出，PCK 包含路径，浏览器全局 helper 为 object，运行阶段控制台错误为 0。此问题与用户暂停调查的“找不到项目 PCK”启动提示不是同一个已证实根因；不要混为一谈。
5. **物理设备稳定性和新卡平衡需要试玩。** 历史手机 Safari 重载/崩溃报告促成了预算和诊断改造；原生测试不能证明手机在最终神兽、雨雪、高密度汽油瓶+黑洞的长局内存稳定。复现检查应记录设备、版本、天气、装备、关卡，并从 Debug 导出诊断。`stress_stability.gd`、`benchmark_runtime.gd` 可辅助但不能代替设备实测；本次未运行。
6. **itch 商店文案存在时效差异。** `docs/itch/` 的英文封面/文案/像素字体套件是编辑素材，内部保留 prepared_not_published 状态，部分文案仍写 18 种装备（当前为 21）。不能由素材存在推断在线首页已全部应用；用户/其他流程也可能编辑了在线页面。后续更新主页前应读取当时真实页面。

上一轮独立试玩页版本为 `20261105-015239`。用户随后明确授权现在更新 itch，本轮已通过 PixelFishing Actions 发布 `20261106-011424` 并核对线上资源。后续发布复用现有 channel 与 Actions Secret，无需索要密钥原值。

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
| 卡片/持续伤害/击退 | `smoke_fan_feedback.gd`、`smoke_fan_status.gd`、`smoke_critical_glasses.gd`、`smoke_axe.gd`、`smoke_book_growth.gd`、`smoke_control_cards.gd`、`smoke_poison_trail.gd`、`smoke_monster_necklace.gd`、`smoke_status_numbers.gd` |
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
- ROGGE 发布 CI 现位于 PixelFishing 的独立发布分支，使用该仓库 `BUTLER_API_KEY`，详情 `docs/ITCH_PUBLISH.md`。当前开发环境没有绑定该 secret；不要依赖聊天凭据。主页封面/字体/描述更新是另一个流程，Butler 上传不会自动修改它们。

本次环境中可用的本地工具/产物（非持久依赖）：

- 引擎：`/workspace/Rogge-recovery-20261104T024444Z/godot-validation-tool/Godot_v4.7-stable_linux.x86_64`，已有日志版本 `4.7.stable.official.5b4e0cb0f`。
- 已安装 Web release 模板：`/home/agent/.local/share/godot/export_templates/4.7.stable/web_nothreads_release.zip`。
- 当前本地导出与本轮日志：`/workspace/Rogge-fan-feedback-20261105/web-build`；构建版本 `20261105-015239`，14 项相关原生与 3 项 PCK 验证。Sites 测试页源码目录：`/workspace/sites/rogge-fan-status-playtest-20261105`，身份保存在其 `.openai/hosting.json`，不能重复注册。
- 暴击眼镜上一版：`/workspace/Rogge-critical-glasses-20261104/web-build`，版本 `20261105-003002`；该目录名为 UTC 日期，版本号为北京时间。
- 上次已上传导出：`/workspace/Rogge-boss-facing-20261104/web-build`，其 `itch-push.jsonl` 记录 build `2297831`。更早新卡版的线上比对在 `/workspace/Rogge-fan-blackhole-20261104/`。


### 独立试玩页（已更新）

- 链接：<https://rogge-fan-status-playtest-20261105.whiteber.chatgpt.site>，Sites 私有页面，需要当前所有者账号登录。入口为主页 → Debug → 测试芭蕉扇（异常追加），也可普通开局。
- 游戏代码：`c6c0e600943f78da2a333b4f76486e5dbc378996`；版本 `20261105-015239`。14 项原生、3 项 PCK 检查通过，原生GPU已核对颜色变化/双异常/恢复；当前页面没有真实浏览器/手机 QA 记录。
- Site project id：`appgprj_6aeb66ad64408191b317328a1063f65c`；deployment id：`appgdep_6aeb72b13a90819192c6985e3fe01c73`；发布结果 `succeeded`。
- Site version id：`appgprj_6aeb66ad64408191b317328a1063f65c~appgver_fd42df795eb88191b5cfda71d29b18d0`；独立托管源提交：`48b7aacfaa0d81afbd0ff04ca7cb9f93882f3cfd`。后续更新复用这个 Site，不要重复注册或自行改变访问范围。
- 本地托管源码在 `/workspace/sites/rogge-fan-status-playtest-20261105`，`source.json` 锁定 GitHub 游戏提交和 PCK 哈希；`build-preview.py` 可重建输出。原始游戏导出未改加载器，托管副本用流式 gzip 加载 WASM 以满足每文件 25 MiB 的托管限制。
- 加载脚本已用 Node 校验解压后与原 WASM 完全相同，兼容服务器已解码响应，其他资源请求不变。Sites 浏览器工具缺失，按技能没有启动替代浏览器；原生与脚本检查不等同网页实测。
- 环境缺少 Sites 官方源助手，已用标准 Git、隐藏 stdin 凭据和 tar 完成同等源同步/打包，原生发布工具接受并成功部署。Sites 源凭据有效期短，过期应通过 `create_source_repository_write_credential` 为同一 project 刷新，不向用户索要 token，不把 token 写入文件或日志。

## 8. 下一会话维护此文档

开始时核对 Git 和用户目标；结束时更新玩法提交、版本、实际运行的检查、发布与浏览器核验状态。把“代码已存在”“报告曾通过”“本次实测通过”“待验证假设”分别表述，不以旧聊天或上传成功代替证据。保持 `AGENTS.md` 简短稳定，把路径、进度和暂态问题留在本文件。
