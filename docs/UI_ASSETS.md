# UI 贴图绘制规范（assets/ui/）

自己画 UI 时，**保持文件名和画布尺寸不变**，直接覆盖对应 PNG（RGBA 透明底）即可。
画完启动游戏会自动重新导入；不启动也可以让我跑 --import。

## 一、九宫格贴图（边框会被拉伸，有结构要求）

九宫格 = 四角固定不变形，边和中心会被拉伸。所以**四角装饰必须画在 margin 范围内**，
中心区域尽量画可平铺的纯色/纹理。margin 定义在 scripts/ui/pixel_ui.gd。

| 文件 | 画布 | margin | 用途 |
|---|---|---|---|
| panel.png | 48x48 | 16px | 大面板（弹窗、顶栏、dock 底） |
| card.png | 40x40 | 14px | 通用卡片（波次徽章、角标） |
| card_common.png | 40x40 | 14px | 祝福卡框·普通 |
| card_rare.png | 40x40 | 14px | 祝福卡框·稀有 |
| card_enchant.png | 40x40 | 14px | 祝福卡框·冰晶附魔 |
| button_normal.png | 32x32 | 10px | 按钮常态 |
| button_hover.png | 32x32 | 10px | 按钮悬停 |
| button_pressed.png | 32x32 | 10px | 按钮按下 |
| button_disabled.png | 32x32 | 10px | 按钮禁用 |
| bar_back.png | 24x24 | 6px | 进度条底槽 |
| bar_fill_green.png | 24x24 | 6px | 血条填充·健康 |
| bar_fill_amber.png | 24x24 | 6px | 血条填充·中等 |
| bar_fill_red.png | 24x24 | 6px | 血条填充·危险 |
| minimap_frame.png | 32x32 | 6px | 小地图边框 |

## 二、图标（自由发挥，只需保持画布尺寸）

| 文件 | 画布 | 用途 |
|---|---|---|
| icon_icicle.png | 32x32 | 冰锥琪露诺（塔·单体） |
| icon_rime.png | 32x32 | 雾凇琪露诺（塔·范围减速） |
| icon_baka.png | 32x32 | ⑨式冰炮（塔·重爆发） |
| icon_guard_barracks.png | 32x32 | 冰晶兵营（近卫） |
| icon_archer_barracks.png | 32x32 | 雾矢兵营（弓手） |
| icon_mage_barracks.png | 32x32 | 暴雪兵营（术士） |
| icon_nova.png | 28x28 | 技能 Q·冰霜新星 |
| icon_freeze.png | 28x28 | 技能 R·完美冻结 |
| icon_frost.png | 16x16 | 冻气（金钱） |
| icon_crystal.png | 16x16 | 冰晶（稀有资源） |
| portrait_ring.png | 64x64 | 顶栏头像外圈（中心留空） |
| title_banner.png | 560x24 | 主菜单/结算标题下装饰条 |

## 三、配色参考（游戏内主色调）

- 深底：#0a2038 / #102f4c
- 冰晶边框：#86e9ff，高光 #d8fbff
- 冻气蓝：#75d9ff，雾凇青：#93efe6，术士紫：#a98df4
- 稀有紫：#c494ff，附魔金：#ffd66e
- 文字主色：#ebfdff，次要文字：#8fb4c8

## 四、想改尺寸怎么办

图标想画大一点（比如建筑图标 32→48），直接告诉我，
我改代码里的显示尺寸和九宫格 margin 就行。

## 五、琪露诺精灵表（想画角色的话）

assets/sprites/cirno.png：384x576，**96x96/帧，4 列 x 6 行**，
行序：idle(4 帧) / walk(4) / attack(4) / cast(4) / hurt(前 2 帧) / death(4)，全部朝右画。
