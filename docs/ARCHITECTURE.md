# 工程架构

## 1. 分层

```text
Presentation        HUD、选牌界面、地图绘制、命中效果
Game Flow           Game、WaveManager、UpgradeManager
Entity Simulation   Tower、Enemy、Projectile
Data                TowerCatalog、EnemyCatalog、WaveCatalog、UpgradeCatalog
Platform            Godot Node/Scene、输入、渲染
```

规则数据与表现分离是当前第一原则。塔和敌人的数值不写进场景，也不写进 HUD。

## 2. 运行时对象关系

```text
Main (game.gd)
├── LakeMapView              绘制网格、路径、核心、悬停格
├── Towers                   塔节点容器
├── Enemies                  敌人节点容器
├── Projectiles              投射物节点容器
├── Effects                  临时命中效果容器
├── WaveManager              生成事件、存活计数、波次完成事件
└── HUD                     资源栏、建造按钮、升级、三选一
```

`Game` 是当前关卡的组合根和状态所有者。它只协调系统，不实现敌人的移动算法或投射物追踪。

## 3. 核心模块职责

### Game

- 持有 IQ、冻气、胜负与关卡阶段。
- 处理建造、升级、选塔和点击输入。
- 响应敌人生成、击杀、漏怪。
- 在波次结束后调用 UpgradeManager 并展示 HUD 卡牌。

### WaveManager

- 把 `WaveCatalog` 的组数据展开为带时间戳的生成事件。
- 使用独立时钟顺序生成敌人。
- 维护“已生成数 / 存活数”，没有剩余事件且无存活敌人时发出完成事件。
- 不直接操作 HUD。

### Tower

- 从 `TowerCatalog` 获取定义。
- 按射程搜索敌人，选择路径进度最高的目标。
- 创建 Projectile，或执行范围技能。
- 支持 1-3 级升级和全局修正乘区。

### Enemy

- 沿预先传入的路径点移动。
- 处理护甲、减速、受伤闪白、死亡收益和漏怪 IQ 损害。
- 通过信号把结算交回 Game，不自行修改全局资源。

### UpgradeManager

- 维护本局已获得强化和聚合后的 modifier。
- 生成三选一，不允许已满层的强化再次出现。
- 当前 modifier 只包含数值乘区；未来可扩展为事件钩子。

## 4. 数据驱动边界

当前数值位于四个 Catalog 脚本中，足以支撑垂直切片。进入内容生产阶段后，应迁移为 `.tres` Resource：

```text
TowerDefinition: id/name/cost/range/damage/cooldown/attack_kind/upgrade_curve
EnemyDefinition: id/name/hp/speed/armor/reward/iq_damage/slow_resistance
WaveDefinition: id/sequence/group/enemy/count/interval/delay
UpgradeDefinition: id/rarity/tags/max_stacks/effects
```

迁移时保持字段语义不变，实体脚本无需重写。

## 5. 目标扩展结构

```text
scripts/systems/
  economy_system.gd
  combat_system.gd
  reward_system.gd
  run_state.gd
  save_system.gd

scripts/data/
  definitions/*.gd 或 resources/*.tres

scripts/levels/
  level_modifier.gd
  build_rule.gd
  tower_slot_rule.gd
```

爬塔层间状态应由 `RunState` 持有：当前层、IQ、已获得强化、塔蓝图、事件 RNG seed。单个关卡结束后只销毁战斗节点，不销毁 RunState。

## 6. 建议的后续里程碑

### M1：手感稳定

- 塔攻击动画与音效。
- 命中、减速、护甲、Boss 技能反馈。
- 2 倍速、暂停、波次预告。
- 数值调优与 3 轮可重复测试。

### M2：内容框架

- Resource 化所有静态数据。
- 章节/层节点地图。
- 事件节点、商店、休息点。
- 存档与随机种子。

### M3：爬塔

- 多关卡地形和关卡规则 modifier。
- 跨层持久强化与临时强化。
- 精英词缀、Boss 机制、每日挑战。
