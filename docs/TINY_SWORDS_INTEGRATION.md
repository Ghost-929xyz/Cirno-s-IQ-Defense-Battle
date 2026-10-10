# Tiny Swords 瓦片地图与角色接入

本轮使用用户提供的 Tiny Swords Update 010，将远征战场的地形、角色和建筑替换为瓦片与精灵素材。游戏仍从主菜单进入 `scenes/expedition.tscn`，2026-10-10 已扩展地图并调整移速与指挥界面，见 [扩展战场说明](EXPANDED_BATTLEFIELD.md)。

## 可编辑地图

在 Godot 打开 `scenes/maps/fog_lake_tiles.tscn`，即可查看和编辑原生 `TileMapLayer`。瓦片集保存在 `resources/tilesets/tiny_swords.tres`，包含草地与沙地两种 Terrain Painting 地形，以及 `terrain`、`walkable` 自定义数据。

地图为 80×50 格，素材瓦片为 64×64 像素。战场视野为 1180×660，默认每格显示 21 像素，支持滚轮缩放和视野移动。不要将素材像素坐标与逻辑格坐标混用。HUD 悬浮于战场上；右下角圆形地图可用 Tab 展开为俯瞰地图。

| 层 | 内容 | 编辑说明 |
| --- | --- | --- |
| Water | 4000 格水底 | 保持完整铺底 |
| ShoreFoam | 8 帧循环岸边浪花 | 放在岸边陆地下方，中心白色块由 Ground 遮住 |
| Ground | 草地、岸线和岛屿 | 使用 Terrain Painting 绘制；移除地面即可露出水面 |
| Paths | 北、中、南三路与纵向支路 | 只改变外观；水上通道使用 Crossings |
| Crossings | 三处木桥 | 木桥覆盖格可通行 |
| Decorations | 树木、石头、草丛、蘑菇 | 树木循环动画；装饰暂不阻路 |
| Ice | 冰桥 | 运行时从冻结的水面格生成 |
| IceWalls | 冰墙 | 运行时生成，失效后移除 |
| Actors | 角色、建筑、探索奖励点 | 按脚点 Y 坐标排序，运行时创建 |

启动时，有水底、没有 Ground、也没有 Crossings 的格子作为水域交给 AStarGrid2D。魔法在同一套格坐标中更新寻路和动态瓦片。编辑 Ground 或 Crossings 会实际改变通行情况。固定基地候选点、敌营、房屋与奖励点仍由玩法数据放置，编辑地图时需为这些点保留陆地。

三处木桥分别连接两岸，湖泊形成绕行与分岔，湖岛在施放冰桥前没有陆地路径。道路和装饰不额外阻挡单位，建筑仍采用点位与距离交互。

## 素材映射

单位使用 `AnimatedSprite2D` 与缓存的 `SpriteFrames`。Warrior、Archer、Pawn、Torch 的帧尺寸均为 192×192，不能按 64×64 瓦片切割。按移动方向翻转精灵，按目标方向选择侧向、向上、向下攻击行。

| 游戏内容 | 当前素材 | 尚缺内容 |
| --- | --- | --- |
| 剑士、近卫、圣骑、重装步兵 | Warrior 待机、移动、攻击 | 高级装备差异暂用职业字标 |
| 弓箭手、狙击手、寒冰弓手 | Archer 待机、移动、上/侧/下射击；寒冰弓手加冷色 | 高级装备与技能专用动画 |
| 刺客、隐士、狂战士及变体 | Pawn 斧兵动作加职业字标 | 各职业独立外形 |
| 骑兵、游骑兵、枪骑兵、具装骑兵 | Warrior 加职业字标 | 原包没有骑乘动画，暂为步行外观；数值和技能仍为骑兵规则 |
| 斥候 | Archer | 骑乘远程动作 |
| 建造、修复中的单位 | Pawn 劳动动作 | 抵达施工范围切换，完成后恢复兵种形象 |
| 中立野怪 | Yellow Torch Goblin | 可用待机、移动与攻击 |
| 主基地 | Castle | 蓝/红/施工/毁坏素材已接入 |
| 兵营、房屋 | House | 通过颜色、尺寸与建筑名称区分 |
| 魔力井 | Tower | 原包没有专用魔力井，暂用高塔 |
| 敌军营地 | Goblin House | 施工暂用 House Construction，毁坏后显示废墟 |
| 宝箱奖励点 | Gold Bag 与金色圈 | 原包没有宝箱；右键领取原宝箱奖励 |
| 冰桥、冰墙 | Elevation 瓦片加冷色 | 专用冰系地形仍待补齐 |

蓝色角色为己方，红色角色为敌军，黄色哥布林为野怪。高级兵种有职业字标。驻军隐藏场外精灵，撤离后恢复；死亡和建筑废墟仅存在于表现层，不保留战斗或碰撞能力。

角色动画在暂停与冰冻时停止。训练列表显示对应头像；远程攻击使用 Arrow 弹道，近战命中由攻击帧反馈。树木和岸边浪花保持装饰性瓦片循环动画。

## 文件与重建

- `assets/tiny_swords/`：63 张未经修改的源 PNG，保留原目录结构。
- `assets/tiny_swords/manifest.json`：来源、相对路径和 SHA256。
- `scripts/data/tiny_swords_art.gd`：素材路径、动画行与职业映射。
- `scripts/entities/tiny_swords_actor.gd`：动作、朝向、暂停、冰冻和死亡表现。
- `scripts/game/tiny_swords_map.gd`：静态地形读取、魔法瓦片与实体视图同步。
- `tools/import_tiny_swords.py`：复制指定原图，不复制外部 `.import`、`.DS_Store` 或编辑源文件。
- `tools/build_tiny_swords_map.gd`：重建默认 TileSet 与地图，会覆盖保存的默认地图；手工绘制新地图后不要直接覆盖自己的修改。

```powershell
python tools/import_tiny_swords.py 'C:/Users/Xuyize/Documents/东方冰华战线/resources/Tiny Swords (Update 010)'
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_tiny_swords_map.gd
```

游戏运行不依赖素材包的外部绝对路径。

## 验证

```powershell
godot --headless --path . --script tests/tiny_swords_test.gd
godot --headless --path . --script tests/rts_test.gd
godot --path . --script tests/rts_visual_test.gd
```

结果为 `TINY_SWORDS_TEST checks=45 failures=0`、`RTS_TEST checks=77 failures=0` 与 `RTS_VISUAL_OK`。覆盖可编辑 TileMapLayer、4000 格与扩展地图拓扑一致性、桥梁通行、魔法与路径联动、读档恢复、全部图集区域边界、角色动作/朝向/暂停/驻军，以及 20 个兵种头像映射。截图检查了岸线、建筑脚点、地图裁切和界面图标。

下一批独立美术主要缺骑乘、高级职业、专用冰系、魔力井和宝箱。长期正式美术目标见 [美术清单](ART_REQUIREMENTS_RTS.md)，当前临时素材覆盖范围以本页为准。
