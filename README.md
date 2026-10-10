# 东方冰华战线：冰封幻想乡

Godot 4 基地与军团即时战略原型。默认新游戏已按《玩法&机制.docx》和《数值_初版.xlsx》重构为“冰华远征”：随机五抽二开局牌、三处基地选址、训练与容量管理、单位建造与驻军、探索、BAKA 魔法、有限波次防守和战后清剿。胜利后保留建筑和军团继续远征。最新逐条核查见 [玩法核查与补充](docs/GAMEPLAY_AUDIT_RTS.md)。

## 运行

使用 Godot 4.5 或更新版本打开 `project.godot`，运行项目。在主菜单点击“新的游戏”，选择存档槽位，选两张开局牌后点击地图上的基地候选点。新入口是 `scenes/expedition.tscn`；已在 Godot 4.7.2 上验证。

旧存档仍可从“继续游戏”进入原塔防场景 `scenes/main.tscn`。项目更名后继续使用原存档目录；Windows 下位于 `%APPDATA%/Godot/app_userdata/琪露诺的智商保卫战/`。选择有存档的槽位创建新游戏仍会覆盖该槽位，菜单会显示提示。

## 操作

| 操作 | 指令 |
| --- | --- |
| 选择部队 | 左键单选、拖拽框选、A 全选 |
| 移动与攻击 | 右键空地移动，右键敌军或敌方建筑进攻 |
| 驻军与修复 | 右键完好的友方/中立建筑驻军，右键受损友方建筑修复；仅剑士和弓箭手可驻军 |
| 建造 | 选中场外单位，点击兵营/魔力井/房屋，再点击陆地 |
| 寻宝 | 选中单位，右键宝箱 |
| 训练与科技 | 底部“招募军团”按四类筛选 20 种兵种；“科技研究”解锁进阶单位；悬停查看数值 |
| BAKA 魔法 | Q 冰冻、W 冰墙、E 冰桥，再点击目标区域 |
| 其他 | Esc 取消放置/清空选择；P 暂停；Space 提前迎敌；F5 存档 |

默认准备 75 秒，共 6 波，之后清剿敌军及敌方建筑；野怪与宝箱是可选探索。己方部队全部阵亡即失败，驻军也计入存活部队。主基地提供 40 容量，额外完工建筑各加 20。训练队列也占容量。选部队后 G 驻军、R 修复，再点击建筑；受损建筑可直接驻军。战场已接入 Tiny Swords 地形、角色动画和建筑贴图；缺少骑乘等专用素材的兵种暂用现有角色加职业字标。

## 瓦片地图与角色

在 Godot 打开 `scenes/maps/fog_lake_tiles.tscn` 可直接绘制地图，瓦片集位于 `resources/tilesets/tiny_swords.tres`。地图包含水面、岸线、草地、道路、木桥、装饰，以及动态冰桥和冰墙；修改地面与木桥会影响通行判定。详见 [Tiny Swords 接入说明](docs/TINY_SWORDS_INTEGRATION.md)。

## 文档

- [本轮规则对应与暂定参数](docs/RTS_REFACTOR.md)
- [缺失美术素材和交付规格](docs/ART_REQUIREMENTS_RTS.md)
- [重构前的塔防版本说明](docs/LEGACY_TOWER_DEFENSE.md)

其余旧版设计、平衡和美术文档只对应历史塔防内容；与本轮冲突时，以这两份新文档及用户提供的玩法、数值附件为准。

## 数据与工程

`resources/rts/units.json` 保存原表全部 20 种兵种及行号；`scripts/data/rts_rules.gd` 集中存放原文未给出的暂定参数。攻速暂按每秒攻击次数。移速现按每秒 1.6–2.8 格执行，覆盖规则见 `rts_rules.gd` 的 `MOVE_SPEEDS`，源表值保留备查。使用以下命令重新导入数值，不会修改源表：

```powershell
python tools/import_rts_balance.py 'C:/Users/Xuyize/Downloads/数值_初版.xlsx'
```

导入器需要 `openpyxl`。运行游戏只依赖已导出的 JSON，无需 Python。`rts_simulation.gd` 负责规则和存档，`expedition.gd` 负责 UI 和指挥操作，`tiny_swords_map.gd` 负责瓦片与精灵表现；旧版系统保留以兼容历史存档。

## 验证

```powershell
godot --headless --path . --script tests/rts_test.gd
godot --headless --path . --script tests/tiny_swords_test.gd
godot --path . --script tests/rts_visual_test.gd
```

规则测试当前结果：`RTS_TEST checks=77 failures=0`，瓦片和动画检查 `TINY_SWORDS_TEST checks=45 failures=0`。真实渲染测试输出 `RTS_VISUAL_OK`，截图位于被 Git 忽略的 `.tools/`。覆盖开局流程、原表数值、容量、训练、施工修复、驻军火力、狙击、兵种技能、战功、地形寻路、存档往返、完整波次长跑和胜负保留。旧版回归 `BUG_REGRESSION_OK checks=50`，菜单与原有引导检查通过。

旧版回归仍可使用 `tests/bug_regression_test.gd`。本轮尚未完成长期难度与经济平衡调优。

## 扩展地图与新版指挥栏

雾之湖已扩展为 80×50 格，包含三处渡口、湖泊绕行、纵向支路和冰桥解锁的湖心岛。滚轮缩放、中键拖动、方向键平移，点击右下角圆形地图定位，Tab 展开俯瞰地图，H 回基地。顶部资源以无边框加粗数字悬浮显示；暂停与菜单采用扁平图标；底部中央精简指挥栏提供常用命令，招募、建造、科技按需展开。每波敌军来袭播放全屏暗化、打字提示与淡入淡出。详细路线、移速和旧 RTS 存档迁移说明见 [扩展战场说明](docs/EXPANDED_BATTLEFIELD.md)。

新增验证：`godot --headless --path . --script tests/expanded_battlefield_test.gd`。
