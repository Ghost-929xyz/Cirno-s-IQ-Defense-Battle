# 工程架构

## 1. 设计原则

当前版本采用“组合根 + 数据目录 + 独立实体”的轻量架构：

- 静态数值与行为分离，实体从 Catalog 读取定义。
- 关卡状态集中在 `FogLakeLevel`，实体通过信号把结果交回关卡。
- 防御塔、兵营和己方兵种共享战斗概念，但继承与职责保持简单。
- 占位画面由 `_draw()` 生成，正式美术接入后不需要改玩法数据。
- 所有单位以 Node2D 动态创建，方便后续迁移到 PackedScene 与对象池。

## 2. 分层

```text
Presentation        BattleHUD、LakeMapView、HitEffect
Game Flow           FogLakeLevel、WaveManager、UpgradeManager
Entity Simulation   DefenseStructure、CirnoTower、FairyBarracks
                    CirnoHero、FairyEnemy、AllyUnit、TowerProjectile
Data                BuildCatalog、TowerCatalog、BarracksCatalog
                    AllyCatalog、EnemyCatalog、WaveCatalog、UpgradeCatalog
Platform            Godot Node/Scene、输入、绘制、音频接口预留
```

## 3. 场景树

```text
MainMenu (menu.tscn / main_menu.gd)     开始菜单，change_scene_to_file 进入战斗
└── (代码构建的标题、按钮、帮助面板、飘雪背景)

FogLakeLevel (main.tscn / game.gd)
├── MapView                 path、grid、IQ 结晶、四向出生裂缝、hover
├── Towers                  CirnoTower 实例
├── Barracks                FairyBarracks 实例
├── Allies                  AllyUnit 实例
├── Hero                    单个 CirnoHero
├── Enemies                 FairyEnemy 实例
├── Projectiles             TowerProjectile 实例
├── Effects                 HitEffect 实例
├── HUD                     BattleHUD
└── TutorialOverlay         新手引导（未完成引导时运行时创建）

FogLakeLevel
└── WaveManager             运行时创建
```

`game.gd` 是当前关卡的组合根和状态所有者，持有冻气、冰晶、阶段、选中建筑与英雄引用。它负责输入和跨系统协调，不负责敌人移动、投射物追踪或单位绘制。琪露诺生命（唯一失败条件）由 `CirnoHero` 自己持有，`FogLakeLevel` 只负责扣减、回血与判定。

`scripts/autoload/session.gd` 用静态变量保存跨场景会话状态（当前只有新手引导完成标记），不依赖 autoload 注册，任何运行方式下都可用。

## 4. 类职责

### FogLakeLevel

- 管理准备、交战、附魔、祝福与结算阶段。
- 处理建造、升级、选择建筑和英雄移动。
- 维护 `_structure_cells`，把网格位置映射到建筑实例。
- 接收妖精死亡、漏怪、建筑摧毁和波次结束信号。
- 调用 `UpgradeManager` 取得三选一并同步全局修正。

### WaveManager

- 把 `WaveCatalog` 的群组展开为按时间排序的生成事件，事件携带 `entrance`（west / north / south / east）。
- `spawn_requested(enemy_id, hp_scale, entrance_id)` 把出兵方向交给 `FogLakeLevel`。
- 管理生成计时、暂停状态和存活敌人数。
- 当事件耗尽且敌人归零时发出 `wave_finished`。

### LakeMapView

- 生成路径格、草地格和可玩矩形。
- 维护 `PATHS`（四条出兵路径，全部汇向 `CORE_CELL`）与 `DEFAULT_ENTRANCE`。
- 提供 `world_to_cell`、`is_buildable`、`has_entrance`、`get_path_points(entrance_id)`、`get_core_world_position`。
- 提供 `get_closest_path_world_position`，跨所有路径供兵营确定单位出生点。
- 绘制四向出生裂缝（带方向指示与方位标签）、IQ 结晶和建造悬停状态。

### DefenseStructure

- 保存定义、等级、最大生命与当前生命。
- 统一处理受伤、死亡、摧毁、升级和选择高亮。
- 作为 `CirnoTower` 与 `FairyBarracks` 的基类。

### CirnoTower

- 按射程寻找优先目标或最近妖精。
- 创建投射物并应用伤害、溅射、减速修正。
- 根据等级和全局 modifier 重算伤害、射程与攻击间隔。

### FairyBarracks

- 只在交战阶段工作。
- 维护存活己方兵种并限制召唤上限。
- 通过 `FogLakeLevel.spawn_ally` 创建单位。

### CirnoHero

- 持有生命值、护甲与准备阶段回血；生命归零时发出 `defeated` 信号，这是关卡唯一失败条件。
- 受右键移动目标和可玩矩形约束。
- 自动索敌、攻击并管理 Q/R 冷却。
- 维护 Baka 寒气击杀阈值被动。

### FairyEnemy

- 沿 PackedVector2Array 路径移动。
- 扫描附近己方兵种、建筑与琪露诺并停下攻击。
- 处理护甲、减速、冻结、死亡奖励与漏怪伤害信号。

### AllyUnit

- 自动寻找最近妖精并追击。
- 根据攻击距离选择近战伤害或投射物。
- 死亡时通知所属兵营移除引用。

### UpgradeManager

- 维护祝福与附魔的层数。
- 聚合数值修正到统一 `modifiers` 字典。
- 过滤已达最大层数的选项并随机提供三张。

## 5. 输入与信号边界

HUD 只发意图，不直接修改游戏状态：

```text
build_item_selected
start_wave_requested
upgrade_structure_requested
modifier_card_selected
hero_skill_requested
restart_requested
menu_requested
```

实体只报告事实，不直接改全局资源：

```text
FairyEnemy.defeated
FairyEnemy.reached_core
DefenseStructure.destroyed
AllyUnit.defeated
WaveManager.wave_started
WaveManager.wave_finished
WaveManager.spawn_requested
TutorialOverlay.finished / skipped
```

例如妖精不会直接扣生命；它发出 `reached_core`，由 `FogLakeLevel` 统一扣除琪露诺生命、刷新 HUD 并判断失败。琪露诺被妖精打死时则由 `CirnoHero.defeated` 通知 `FogLakeLevel` 结算。

## 6. 数据目录

| 文件 | 内容 |
|---|---|
| `tower_catalog.gd` | 3 种防御塔数值 |
| `barracks_catalog.gd` | 3 种兵营与召唤参数 |
| `ally_catalog.gd` | 近卫、射手、法师数值 |
| `build_catalog.gd` | 合并 1-6 建造项并区分塔/兵营 |
| `enemy_catalog.gd` | 普通、精英与 Boss 数值 |
| `wave_catalog.gd` | 10 波生成事件、出兵口与血量倍率 |
| `upgrade_catalog.gd` | 笨蛋灵感与冰晶附魔 |

## 7. 后续扩展

当前 Catalog 是 `Dictionary`，足以支持 demo。进入内容生产后建议迁移到 `.tres` Resource：

```text
TowerDefinition
BarracksDefinition
AllyDefinition
EnemyDefinition
WaveDefinition
ModifierDefinition
```

实体保留相同字段语义即可迁移，无需重写战斗逻辑。爬塔阶段应新增：

```text
scripts/run/run_state.gd
scripts/levels/level_modifier.gd
scripts/systems/reward_service.gd
scripts/systems/save_service.gd
scripts/data/resources/*.tres
```

`RunState` 跨层持有琪露诺生命、英雄成长、冰晶、祝福与随机种子；单关只销毁战斗节点，不销毁局内进度。

## 8. 验证

项目包含三条无窗口测试：

```powershell
godot --headless --path . --script .tools/smoke_test.gd    # 建造、开波、单位生成、英雄技能
godot --headless --path . --script .tools/ui_test.gd       # 菜单、四入口路径、新手引导、多入口出兵
godot --headless --path . --script .tools/battle_test.gd   # 多入口混编战斗全链路
```

`smoke_test` 会实例化主场景，建造一座冰锥塔和一座冰晶兵营，开始第 1 波，等待妖精与己方兵种生成，然后释放 Q/R。`ui_test` 额外校验菜单场景、四条入口路径、波次数据中的 `entrance` 合法性以及引导推进。`battle_test` 从四个入口混编增兵，验证塔、兵营、英雄技能与漏怪扣除琪露诺生命全链路无报错。
