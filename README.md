# 琪露诺的智商保卫战

Godot 4 塔防 Roguelike 原型。当前仓库包含雾之湖第一关的可运行垂直切片：固定路径、建造与升级不同职阶的琪露诺、6 波青蛙进攻、IQ 核心生命、冻气经济和波间三选一强化。

## 当前原型

- 3 种琪露诺：冰锥（单体）、雾凇（范围减速）、⑨炮（高伤溅射）。
- 5 种青蛙：蝌蚪、跳跳蛙、铁甲蛙、冰肤蛙、雾之湖蛙王。
- 6 波固定关卡与 Boss 波。
- 塔等级 1-3，可花费冻气升级。
- 5 类 Roguelike 强化，支持部分重复叠加。
- 所有占位画面由 `_draw()` 生成，不依赖外部美术即可运行。

## 运行

1. 使用 Godot 4.2 或更高版本打开仓库根目录的 `project.godot`。
2. 按 F6/F5 运行主场景。
3. 左键点击非路径格建造；点击已有塔可查看并升级。
4. 点击“开始第 X 波”；清空后选择一张“笨蛋灵感”继续。

## 目录

```text
assets/                    美术与音频资源
docs/                      设计、架构、美术需求
scenes/                    Godot 场景
scripts/data/              塔、敌人、波次、强化数据
scripts/game/              关卡、地图、波次、强化系统
scripts/entities/          塔、敌人、投射物
scripts/effects/           命中与反馈效果
scripts/ui/                HUD 与 Roguelike 选牌界面
```

详细设计见 [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)，工程架构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，美术需求见 [docs/ART_REQUIREMENTS.md](docs/ART_REQUIREMENTS.md)。
