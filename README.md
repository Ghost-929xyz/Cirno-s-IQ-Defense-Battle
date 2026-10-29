# 东方冰华战线：冰封幻想乡

Godot 4 基地与军团即时战略原型。默认新游戏已按《玩法&机制.docx》和《数值_初版.xlsx》重构为“冰华远征”：手动五选二开局牌、中央火把营地、战争迷雾与资源占领、训练与容量管理、单位建造与驻军、探索、BAKA 魔法、有限波次防守和战后清剿。胜利后保留建筑和军团继续远征。本次九项反馈及新规则见 [反馈修改](docs/DOCUMENT_FEEDBACK.md)。历史逐条核查见 [玩法核查与补充](docs/GAMEPLAY_AUDIT_RTS.md)。

## 运行

使用 Godot 4.5 或更新版本打开 `project.godot`，运行项目。在主菜单点击“新的游戏”，选择存档槽位，确认两张开局牌后直接从地图中央基地开始探索。新入口是 `scenes/expedition.tscn`；已在 Godot 4.7.2 上验证。

旧存档仍可从“继续游戏”进入原塔防场景 `scenes/main.tscn`。项目更名后继续使用原存档目录；Windows 下位于 `%APPDATA%/Godot/app_userdata/琪露诺的智商保卫战/`。选择有存档的槽位创建新游戏仍会覆盖该槽位，菜单会显示提示。

本轮新增战争迷雾、金矿/魔力泉/灵视塔、攻击移动与连续指令；基地停止被动金币。完整规则与快捷键见 [探索与指挥说明](docs/EXPLORATION_COMMANDS.md)。

## 操作

| 操作 | 指令 |
| --- | --- |
| 选择部队 | 左键单选或框选；右键友军单选，Shift＋右键追加；A 首次选同类，再按选全部；左侧兵种卡左/右键选同类并定位 |
| 编队 | Ctrl＋0–9 保存当前选中部队；0–9 选择对应编队（支持小键盘），右键下令只操控该队；双击数字定位，编队随存档保存，阵亡成员召回时剔除 |
| 移动与攻击 | 右键空地移动，右键敌军或敌方建筑进攻 |
| 战斗指令 | F 后点击目标执行攻击移动；S 停止并取消队列；D 原地防守，只攻击射程内敌人 |
| 连续指令与集结 | Shift 追加移动、攻击、占领、驻军或修复指令；选中基地/兵营右键设置集结点，Shift 追加集结路线 |
| 探索与提示 | 右键已发现资源点占领；I 循环定位空闲部队；小地图红圈提示受袭，Tab 查看资源情报 |
| 驻军与修复 | 右键完好的友方/中立建筑驻军，右键受损友方建筑修复；仅剑士和弓箭手可驻军 |
| 建造 | 选中场外单位，在固定建造页点击兵营/魔力井/房屋/科技所，再点击陆地 |
| 寻宝 | 选中单位，右键宝箱 |
| 训练与科技 | 底部紧凑指挥栏切换招募/建造/科技，可收起/展开；科技所开放骑兵和刺客，进阶兵种按互斥路线研究；悬停查看数值 |
| BAKA 魔法 | Q 冰冻、W 冰墙、E 冰桥，再点击目标区域 |
| 其他 | Esc 取消放置/清空选择；P 暂停；Space 提前迎敌；F5 存档 |

默认准备 75 秒，共 6 波，之后清剿敌军及敌方建筑；野怪与宝箱是可选探索。只有己方基地及所有建筑都被摧毁才失败；未完工但仍有生命的己方建筑也计入存活。部队全灭后仍可从存活的基地或兵营招募，基地被毁但其他建筑存活时可继续作战。主基地提供 40 容量，额外完工建筑各加 20。训练队列也占容量。选部队后 G 驻军、R 修复，再点击建筑；受损建筑可直接驻军。战场已接入 Tiny Swords 地形、角色动画和建筑贴图；缺少骑乘等专用素材的兵种暂用现有角色加职业字标。

## 瓦片地图与角色

在 Godot 打开 `scenes/maps/fog_lake_tiles.tscn` 可直接绘制地图，瓦片集位于 `resources/tilesets/tiny_swords.tres`。地图包含水面、岸线、草地、木桥、装饰，以及动态冰桥和冰墙；道路层已清空。修改地面与木桥会影响通行判定。详见 [Tiny Swords 接入说明](docs/TINY_SWORDS_INTEGRATION.md)。

## 文档

- [本轮规则对应与暂定参数](docs/RTS_REFACTOR.md)
- [缺失美术素材和交付规格](docs/ART_REQUIREMENTS_RTS.md)
- [重构前的塔防版本说明](docs/LEGACY_TOWER_DEFENSE.md)

其余旧版设计、平衡和美术文档只对应历史塔防内容；本次选牌、经验、分支和界面以 [反馈修改](docs/DOCUMENT_FEEDBACK.md) 及用户最新附件为准。

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

规则测试当前结果：`RTS_TEST checks=180 failures=0`，最新反馈检查 `DOCUMENT_FEEDBACK_TEST checks=52 failures=0`，瓦片和动画检查 `TINY_SWORDS_TEST checks=45 failures=0`。真实渲染检查输出 `FEEDBACK_VISUAL_OK`，截图位于被 Git 忽略的 `.tools/`。覆盖开局流程、原表数值、容量、训练、施工修复、驻军火力、狙击、兵种技能、经验、地形寻路、存档往返、完整波次长跑和胜负保留。旧版回归 `BUG_REGRESSION_OK checks=50`，菜单与原有引导检查通过。

旧版回归仍可使用 `tests/bug_regression_test.gd`。本轮尚未完成长期难度与经济平衡调优。

## 扩展地图与新版指挥栏

雾之湖已扩展为 80×50 格，包含三处渡口、湖泊绕行、纵向支路和冰桥解锁的湖心岛。滚轮以鼠标位置为中心平滑缩放、中键拖动、方向键或鼠标靠近窗口边缘平移，点击右下角等比例平面小地图定位，Tab 展开俯瞰地图，H 回基地。顶部资源以无边框加粗数字悬浮显示；暂停与菜单采用扁平图标；底部紧凑指挥栏提供常用命令，招募、建造、科技在同一区域切换；右侧按钮可收起为操作条，点击页签直接展开并保留所选分类，左侧军团卡显示各类人数并可点击选择。每波敌军来袭播放全屏暗化、打字提示与淡入淡出。详细路线、移速和旧 RTS 存档迁移说明见 [扩展战场说明](docs/EXPANDED_BATTLEFIELD.md)。

新增验证：`godot --headless --path . --script tests/expanded_battlefield_test.gd`。

本次验证入口：`godot --headless --path . --script tests/document_feedback_test.gd`，覆盖最新九项反馈。击杀经验累计严格超过造价 3 倍时伤害增加 20%，严格超过 6 倍时生命上限增加 20%，并每秒恢复最大生命的 2%。

## Windows Demo

下载 [Windows 64 位免安装 Demo](exports/Icefront-Demo-Windows.zip)，解压后运行 `Icefront-Demo.exe`。操作与存档提示见包内的试玩说明。

重新打包：`powershell -ExecutionPolicy Bypass -File tools/build_demo.ps1 -Godot "你的 Godot 可执行文件路径"`。需要安装与引擎版本一致的 Windows 导出模板；脚本使用临时副本移除开发插件，再导出并生成 ZIP。
