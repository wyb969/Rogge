<div align="center">

# ⚔️ R O G G E

### 冲进怪潮，把每次升级变成新的连锁反应。

**像素生存 · 随机构筑 · 冲刺走位 · 四神兽挑战**

[![浏览器试玩](https://img.shields.io/badge/立即试玩-itch.io-FA5C5C?style=for-the-badge&logo=itchdotio&logoColor=white)](https://ybwangrogger.itch.io/rogue-white)
[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/)
[![装备卡片](https://img.shields.io/badge/装备卡片-21_种-59C9A5?style=for-the-badge)](#装备图鉴)

[开始一局](https://ybwangrogger.itch.io/rogue-white) · [装备图鉴](#装备图鉴) · [四神兽与祝福](#四神兽与祝福) · [运行项目](#运行项目)

<img src="docs/screenshots/combat.png" alt="Rogge 运行截图：像素怪潮、自动火力、闪电与连续拾取反馈" width="1066">

*武器负责火力，你负责走位、冲刺，以及下一张卡的选择。*

</div>

---

## 一局里会发生什么？

**清怪 → 拾币升级 → 三选一卡 → 叠出构筑 → 挑战 Boss → 带着祝福进入下一关。**

- **每次开局都有变化。** 随机背景色、关卡主力怪主题、升级选项，以及晴、阴、雨、雪与昼夜变化。
- **冲刺是进攻的一部分。** 躲开预警、穿过包围；装备踏风徽记后，冲刺结束还能释放风压。
- **奖励也有意外。** 追逐掉宝的小怪、击败宝藏守卫触发老虎机强化，还可能遇到留下金币或回血球的流星雨。
- **六个主线关卡，逐步升级的挑战。** 从冲锋 Boss、挥剑骑士，到四种属性神兽，再到力量与速度试炼。
- **拾取也能越玩越热。** 连续拾币会升高音调，经验条点燃 COMBO；配上短促枪声、局部光影和 8-bit 配乐。

## 运行画面

以下画面由当前工程实际运行截取，展示不同构筑和 Boss 场景。

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/boss-rush.png" alt="第一关 Boss 的冲锋路径、危险边界与阶段提示"><br><strong>读懂冲锋，再抓反击窗口</strong><br>第一关 Boss：预警、冲刺与硬直节奏。</td>
    <td width="50%"><img src="docs/screenshots/wind-guardians.png" alt="风之双隼 Boss 战：远程风刃与近战俯冲"><br><strong>两只神兽，两种压力</strong><br>风之双隼：远程风刃与近战俯冲配合。</td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/snow-poison.png" alt="雪夜中的剧毒踪迹构筑，玩家移动和冲刺留下毒雾"><br><strong>身后留毒，脚下生风</strong><br>雪夜、毒雾与机动构筑。</td>
    <td><img src="docs/screenshots/upgrade-cards.png" alt="升级时的三选一卡界面与重选机会"><br><strong>下一张卡，改变这一局</strong><br>三选一升级，也可以消耗机会重选。</td>
  </tr>
</table>

## 装备图鉴

21 种装备与成长卡可以交叉搭配。斧头、书本提供开局火力，其余能力在升级过程中逐步加入。

| 类型 | 装备 | 打法与作用 |
| --- | --- | --- |
| <img src="assest/sprites/axe.png" width="28" alt="斧头"> 飞行武器 | **斧头** | 飞出后回收，沿途打击敌人；升级强化伤害与攻击能力。 |
| <img src="assest/sprites/book.png" width="28" alt="书本"> 环绕防线 | **书本** | 围绕玩家攻击，最多 12 本；到达数量上限后继续强化伤害。 |
| <img src="assest/sprites/drone.svg" width="28" alt="无人机"> 自动火力 | **枪支、无人机** | 自动射击与短时激光，持续压制靠近的敌人。 |
| <img src="assest/sprites/lightning_ring.svg" width="28" alt="闪电戒指"> 范围雷击 | **闪电戒指** | 周期雷击周围目标；升级提高伤害、雷击数量与范围。 |
| <img src="assest/sprites/molotov.svg" width="28" alt="汽油瓶"> 点燃与控制 | **汽油瓶、寒冰** | 汽油瓶引燃群怪并传播灼烧；寒冰提供控制与冻伤增伤。 |
| <img src="assest/sprites/poison_trail.svg" width="28" alt="剧毒踪迹"> 移动毒场 | **剧毒踪迹** | 移动时身后留下毒雾，持续伤害其中的敌人；最高 5 级解锁减速。 |
| <img src="assest/sprites/banana_fan.svg" width="28" alt="芭蕉扇"> 定向击退 | **芭蕉扇** | 沿当前或最后移动方向吹出气流，造成伤害并击退小怪；升级提高频率与距离，最高 5 级。 |
| <img src="assest/sprites/black_hole.svg" width="28" alt="黑洞"> 引力聚怪 | **黑洞** | 周期召唤持续 3 秒的小黑洞，聚拢敌人并每秒伤害；升级缩短冷却、扩大范围并提高伤害，最高 5 级。 |
| <img src="assest/sprites/critical_glasses.svg" width="28" alt="暴击眼镜"> 暴击强化 | **暴击眼镜** | 每级增加 20% 直接攻击暴击率，最高 5 级；暴击伤害为 150%，满级提高到 200%，以更大的金色伤害字标记。 |
| <img src="assest/sprites/wind_emblem.svg" width="28" alt="踏风徽记"> 触发连锁 | **踏风徽记、回响火种** | 冲刺结束释放风压；累计击杀后，在最后一次击杀处引爆回响。 |
| <img src="assest/sprites/monster_necklace.png" width="28" alt="怪物项链"> 生存续航 | **怪物项链、回复、吸血、玉佩** | 击杀掉落回血球、周期回复、伤害吸血，以及击杀补充护盾。 |
| <img src="assest/sprites/fist_left.svg" width="28" alt="方向伤害"> 方向与成长 | **左拳、右拳、拾取、移速** | 强化对应方向的伤害，扩大拾取范围，或提高移动速度。 |

### 试试这些搭配

| 构筑方向 | 核心组合 | 体验重点 |
| --- | --- | --- |
| **火力覆盖** | 枪支 + 无人机 + 闪电戒指 | 用自动火力处理近身威胁，雷击补充范围伤害。 |
| **跑毒机动** | 剧毒踪迹 + 踏风徽记 + 移速 | 边移动边铺毒，冲刺脱身时顺手打出风压。 |
| **点燃连爆** | 汽油瓶 + 回响火种 + 寒冰 | 利用灼烧传播和击杀爆发清理聚集的敌人，靠冰冻争取走位空间。 |
| **续航容错** | 怪物项链 + 玉佩 + 回复 / 吸血 | 让击杀转化为回血与护盾，逐步建立更稳的循环。 |
| **风压引力** | 芭蕉扇 + 黑洞 + 汽油瓶 / 闪电戒指 | 用气流打开退路，黑洞重新聚怪，再由范围攻击处理聚集目标。Boss 会受到伤害并抵抗位移。 |

## 四神兽与祝福

击败神兽后，会获得一项主动能力。**直接点击左侧图标释放，图标上的填充变化显示冷却。**

| 神兽 | 战斗特色 | 获得的祝福 |
| --- | --- | --- |
| 🌊 **潮汐巨象** | 水泡落点、潮汐水道与冲锋 | **潮汐复苏**：回复生命。 |
| ⚡ **雷鬃狮王** | 交叉落雷、雷印追击与跳跃突袭 | **雷霆裁决**：雷击屏幕内敌人并清除敌弹。 |
| 🌪️ **苍穹双隼** | 远程风刃与近战俯冲，双 Boss 配合 | **苍风牵引**：牵引全地图已经掉落的金币与回血球。 |
| 🛡️ **熔岩玄龟** | 熔岩环、火种坠落与滚动攻击 | **玄岩壁垒**：短时间大幅降低受到的伤害。 |

神兽拥有二阶段变化。第二、第四位神兽之后，还分别有 **力量试炼** 与 **速度试炼**：应对锁定激光，或把握瞬移斩击后的反击窗口。

## 开始试玩

### [▶ 打开 itch.io，直接在浏览器里玩](https://ybwangrogger.itch.io/rogue-white)

| 操作 | 电脑 | 手机触屏 |
| --- | --- | --- |
| 移动 | 方向键 / WASD | 左侧虚拟摇杆 |
| 冲刺 | **Shift** | 右侧 DASH 按钮 |
| 神兽技能 | 点击左侧图标；E 释放当前技能，Q 切换 | 点击左侧技能图标 |
| 升级选择 | 点击卡片 | 触摸卡片 |

武器自动攻击。可以在设置里选择 **简单、中等、困难**，并调整天气特效、环境音和镜头反馈。

## 运行项目

1. [下载 master 源码 ZIP](https://github.com/wyb969/Rogge/archive/refs/heads/master.zip)，或克隆本仓库。
2. 使用 **Godot 4.7** 导入 `project.godot`。
3. 按 **F5** 运行项目。

<details>
<summary><strong>开发验证与恢复记录</strong></summary>

当前工程来自线上版本 **20261104-002331** 的恢复快照，包含 146 个脚本；恢复后的工程已通过 **47 项功能回归检查**。此次首页截图也来自该工程的实际渲染。

恢复过程、资源转换限制和验证结果保存在：

- [恢复说明](RECOVERY_README.md)
- [来源记录](RECOVERY_PROVENANCE.json)
- [功能检查结果](RECOVERY_TEST_RESULTS.json)

未推送的旧本地 Git 历史、未打包文件，以及部分素材的原始编辑数据不包含在这份恢复工程中。后续源码以 GitHub 上的提交为准。

</details>

---

<div align="center">

**先冲出去，再决定这一局怎么赢。**

[进入怪潮 →](https://ybwangrogger.itch.io/rogue-white)

</div>
