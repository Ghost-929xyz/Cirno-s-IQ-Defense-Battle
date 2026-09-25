# 琪露诺的智商保卫战

Godot 4 塔防 Roguelike 原型，改编自仓库中的 `策划案.docx`。当前版本是雾之湖第一关的可运行垂直切片：从开始菜单进入，首次游玩有新手引导；操作英雄琪露诺，布置防御塔与兵营，击退从西 / 北 / 南 / 东四个方向进攻的 10 波妖精，保护琪露诺不被妖精打倒。

## 当前版本

- 开始菜单（`scenes/menu.tscn`）：开始游戏 / 操作说明 / 退出；战斗结算可「再守一次」或「返回主菜单」。
- 新手引导：欢迎弹窗 + 分步提示（移动 → 建塔 → 建兵营 → 开波）+ 战斗提示，可跳过，完成一次后本会话不再重复。
- 地图：可替换的 `assets/maps/map.png` 像素画，推荐 **256 × 192 图像像素**；**2×2 图像像素 = 1 个逻辑格**，对应 **128 × 96 格**并固定缩放到单屏，无需移动镜头。道路建议 4～5 格宽，深色路径从四边入口汇向 IQ 结晶，建筑物不能落在道路或核心上。
- 失败条件为琪露诺生命归零（初始 190，护甲 2，准备阶段每秒回 6）；妖精会攻击她，漏过防线的妖精抵达 IQ 结晶也会扣她生命。
- 界面布局：琪露诺血条位于顶部横贯状态栏，可购买的塔与兵营位于底部半透明可收起的 dock 栏，右侧完全解放。
- 英雄琪露诺支持右键移动（脚底箭头指示方向）、自动攻击、Q 冰霜新星、R 完美冻结和每 8 杀触发的 Baka 寒气。
- 3 种防御塔：冰锥单体、雾凇范围减速、⑨式冰炮重型溅射；防御塔占地 3×3 格（共 9 格）。
- 3 种兵营：冰晶近卫、雾矢射手、暴雪术士，占地 2×2 格（共 4 格），只在交战阶段召唤单位；波次结束后存活兵种回到出生兵营附近 7×7 格内驻扎。
- 防御塔和兵营均有 HP 与 1-3 级升级；妖精会攻击己方单位与建筑。
- 6 类妖精，其中妖精队长为精英，博丽灵梦为第 10 波 Boss；精英被击杀后掉落十字芒星高亮附魔，左键点击拾取，不再直接弹窗。
- 地图四面出兵：西口为主路，第 2 波引入北口、第 4 波南口、第 7 波东口，Boss 从东口压境。
- 10 波固定关卡；每波结束后有短暂结算环节（计算本波金钱收益），随后「笨蛋灵感」祝福以横向三选项弹窗出现，必须在当前波次选择。
- 左键可框选或点选友方军队与防御塔，实现主动选择攻击目标。
- 数值曲线：第二波起敌军数量大幅上调，友军与防御塔伤害整体下调约 25%（×0.75）。
- 准备阶段不再按时间恢复冻气；每个非最终波选择「笨蛋灵感」后，一次性领取随波次增长的冻气奖励，相关经济强化会提高每次波末奖励。
- 冻气、冰晶与琪露诺生命三类资源形成经济、稀有构筑与生存循环。
- 当前视觉全部使用 `_draw()` 占位图形，无需外部素材即可运行。

核心名词见 [docs/CORE_TERMS.md](docs/CORE_TERMS.md)，完整设计见 [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)，工程结构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，数值见 [docs/BALANCE.md](docs/BALANCE.md)，单位、建筑、敌人与攻击方式见 [docs/COMBAT_CATALOG.md](docs/COMBAT_CATALOG.md)，美术交付清单见 [docs/ART_REQUIREMENTS.md](docs/ART_REQUIREMENTS.md)。

## 运行

1. 使用 Godot 4.5 或更高版本打开仓库根目录的 `project.godot`。
2. 运行项目（主场景 `scenes/menu.tscn`），在开始菜单点击「开始游戏」进入战斗。
3. 首次进入会触发新手引导；可跟随引导完成「移动 → 建塔 → 建兵营 → 开波」，也可直接跳过。
4. 选择防御塔或兵营后，左键草地格建造（路线与已占用格不可建）。
5. 点击已有建筑查看 HP、等级和升级费用；左键点选或框选友方单位 / 塔后，右键指定攻击目标。
6. 右键空地移动琪露诺（脚底出现方向箭头）；右键妖精可让选中的塔 / 单位优先攻击该目标。
7. 精英掉落的十字芒星附魔需左键点击拾取。
8. 波末点击结算弹窗的「选择祝福 →」，在横向三选项中挑选笨蛋灵感，然后准备下一波。
9. 使用 Q/R、1-6、空格和 Esc 完成战斗操作；注意别让琪露诺的生命归零。

## 验证

当前已提交的缺陷回归测试覆盖快捷键选择、接敌距离、英雄 R、精英掉落、附魔暂停、结束态冻结、漏怪结算、生命祝福、建造占地与手动目标：

```powershell
godot --headless --path . --script tests/bug_regression_test.gd
```

成功输出：

```text
BUG_REGRESSION_OK checks=50
```

无窗口烟测会实例化主场景，建造防御塔和兵营、开始第 1 波、等待双方单位生成并释放英雄技能：

```powershell
godot --headless --path . --script .tools/smoke_test.gd
```

成功输出示例：

```text
SMOKE_OK towers=1 barracks=1 allies=1 enemies=4 hp=190/190 frost=85
```

另有几条无窗口测试：

```powershell
godot --headless --path . --script .tools/ui_test.gd        # 菜单、四入口、新手引导、多入口出兵
godot --headless --path . --script .tools/battle_test.gd    # 多入口混编战斗、塔/兵营/英雄技能全链路
godot --headless --path . --script .tools/settlement_test.gd  # 波末结算 -> 祝福三选一 -> 准备 全链路
godot --headless --path . --script .tools/path_test.gd        # 地图路径坐标/出生点回归
```

成功输出示例：

```text
UI_TEST_OK entrances=4 tutorial=done menu=ok
BATTLE_OK spawned=20 alive=1 allies=2 hp=0/190
SETTLEMENT_OK choices=3 phase=0
```

窗口截图验证（需要真实渲染）：

```powershell
godot --path . --script .tools/screenshot.gd   # 输出到 %TEMP%/gamemakers_shots/
```

## 目录

```text
assets/                    正式美术与音频资源
docs/                      核心名词、设计、架构、平衡与美术需求
scenes/                    Godot 场景（menu.tscn 开始菜单、main.tscn 战斗关卡）
scripts/autoload/          跨场景会话状态（新手引导完成标记）
scripts/data/              防御塔、兵营、兵种、妖精、波次、强化数据
scripts/game/              关卡、地图、波次、强化系统
scripts/entities/          英雄、建筑、己方兵种、妖精、投射物、掉落物
scripts/effects/           命中与范围反馈
scripts/ui/                开始菜单、HUD、建造 dock、三选一弹窗、新手引导
.tools/                    无窗口烟测与战斗测试
```
