# 琪露诺的智商保卫战

Godot 4 塔防 Roguelike 原型，改编自仓库中的 `策划案.docx`。当前版本是雾之湖第一关的可运行垂直切片：从开始菜单进入，首次游玩有新手引导；操作英雄琪露诺，布置防御塔与兵营，击退从西 / 北 / 南 / 东四个方向进攻的 10 波妖精，保护琪露诺不被妖精打倒。

## 当前版本

- 开始菜单（`scenes/menu.tscn`）：开始游戏 / 操作说明 / 退出；战斗结算可「再守一次」或「返回主菜单」。
- 新手引导：欢迎弹窗 + 分步提示（移动 → 建塔 → 建兵营 → 开波）+ 战斗提示，可跳过，完成一次后本会话不再重复。
- 失败条件为琪露诺生命归零（初始 240，护甲 2，准备阶段每秒回 8）；妖精会攻击她，漏过防线的妖精抵达 IQ 结晶也会扣她生命。
- 英雄琪露诺支持右键移动、自动攻击、Q 冰霜新星、R 完美冻结和每 8 杀触发的 Baka 寒气。
- 3 种防御塔：冰锥单体、雾凇范围减速、⑨式冰炮重型溅射。
- 3 种兵营：冰晶近卫、雾矢射手、暴雪术士，只在交战阶段召唤单位。
- 防御塔和兵营均有 HP 与 1-3 级升级；妖精会攻击己方单位与建筑。
- 6 类妖精，其中妖精队长为精英并掉落冰晶，博丽灵梦为第 10 波 Boss。
- 地图四面出兵：西口为主路，第 2 波引入北口、第 4 波南口、第 7 波东口，Boss 从东口压境。
- 10 波固定关卡，波间三选一“笨蛋灵感”，精英触发另一次“冰晶附魔”三选一。
- 冻气、冰晶与琪露诺生命三类资源形成经济、稀有构筑与生存循环。
- 当前视觉全部使用 `_draw()` 占位图形，无需外部素材即可运行。

核心名词见 [docs/CORE_TERMS.md](docs/CORE_TERMS.md)，完整设计见 [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)，工程结构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，数值见 [docs/BALANCE.md](docs/BALANCE.md)，美术交付清单见 [docs/ART_REQUIREMENTS.md](docs/ART_REQUIREMENTS.md)。

## 运行

1. 使用 Godot 4.5 或更高版本打开仓库根目录的 `project.godot`。
2. 运行项目（主场景 `scenes/menu.tscn`），在开始菜单点击「开始游戏」进入战斗。
3. 首次进入会触发新手引导；可跟随引导完成「移动 → 建塔 → 建兵营 → 开波」，也可直接跳过。
4. 选择防御塔或兵营后，左键草地格建造。
5. 点击已有建筑查看 HP、等级和升级费用。
6. 右键空地移动琪露诺；选中防御塔后右键妖精可指定优先目标。
7. 使用 Q/R、1-6、空格和 Esc 完成战斗操作；注意别让琪露诺的生命归零。

## 验证

无窗口烟测会实例化主场景，建造防御塔和兵营、开始第 1 波、等待双方单位生成并释放英雄技能：

```powershell
godot --headless --path . --script .tools/smoke_test.gd
```

成功输出示例：

```text
SMOKE_OK towers=1 barracks=1 allies=1 enemies=3 hp=240/240 frost=99
```

另有两条无窗口测试：

```powershell
godot --headless --path . --script .tools/ui_test.gd      # 菜单、四入口、新手引导、多入口出兵
godot --headless --path . --script .tools/battle_test.gd  # 多入口混编战斗、塔/兵营/英雄技能全链路
```

成功输出示例：

```text
UI_TEST_OK entrances=4 tutorial=done menu=ok
BATTLE_OK spawned=20 alive=1 allies=4 hp=160/240
```

## 目录

```text
assets/                    正式美术与音频资源
docs/                      核心名词、设计、架构、平衡与美术需求
scenes/                    Godot 场景（menu.tscn 开始菜单、main.tscn 战斗关卡）
scripts/autoload/          跨场景会话状态（新手引导完成标记）
scripts/data/              防御塔、兵营、兵种、妖精、波次、强化数据
scripts/game/              关卡、地图、波次、强化系统
scripts/entities/          英雄、建筑、己方兵种、妖精、投射物
scripts/effects/           命中与范围反馈
scripts/ui/                开始菜单、HUD、建造卡、技能按钮、三选一弹窗、新手引导
.tools/                    无窗口烟测与战斗测试
```
