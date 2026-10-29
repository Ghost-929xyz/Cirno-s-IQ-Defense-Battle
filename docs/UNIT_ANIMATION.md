# 四向移动动画

现有 20 个兵种及野怪共用 Warrior、Archer、Pawn、Torch 四组外观。每组提供 `run_left/right/up/down` 六帧循环和对应方向待机；左右方向沿用原图，左向镜像，上下方向使用补充图集。骑兵仍沿用当前步行占位外观，本轮不包含独立马匹或高级职业装备设计。

## 动作衔接

- 对 20 Hz 战斗逻辑的离散位移保留 0.10 秒移动状态，避免高帧率渲染中反复切回待机。
- 转向时保留迈步进度；斜向移动采用方向切换阈值，避免在水平和垂直帧之间抖动。
- 停止和原地防守立即结束移动，保留最后朝向；移动指令可以打断残留攻击表现。
- 迈步速度随兵种移速和减速比例变化。暂停、冰冻和驻军时停止帧播放。
- 每帧按透明区域测量脚点；上下移动帧按原角色高度标定，不改变单位坐标或碰撞范围。
- 上下帧使用蓝色母版，材质只替换蓝色装备区域为红/黄阵营色，保留肤色和火焰。

## 资源与来源

- `assets/sprites/troops_vertical_walk.png`：通过内置 **image_gen** 工具、按现有四组原始素材生成的上下行走补充图集；原始 Tiny Swords PNG 保持不变。
- `assets/sprites/troops_vertical_walk.json`：逐帧图集区域、脚点和缩放标定。
- `tools/build_directional_frames.gd`：扫描 PNG 的 alpha，重建上述标定，不修改位图。Warrior 向下一帧左右手不一致，播放时以相邻姿态替代。
- `scripts/data/tiny_swords_art.gd`：动画、图集与阵营缓存。
- `scripts/entities/tiny_swords_actor.gd`：移动/待机/攻击切换与帧步调。

## 图像生成提示词记录

首次使用四张 Blue 原始图集作为角色和风格参考，提示词要求：单张透明图集，六列八行，依次为 Warrior 上/下、Archer 上/下、Pawn 上/下、Torch 上/下；每行六帧循环行走，保持角色比例、配色和装备，向上显示背面、向下显示正面，不使用倒置图片或攻击动作，不带标签和背景。

最终编辑提示词（内置工具，透明输出）：

> Correct this game animation atlas for exact production grid alignment. Keep EXACTLY 6 columns by 8 rows, same characters, same order of rows and six walking poses. Transparent RGBA canvas, no text or grid lines. Critical corrections: every character is currently too large in its cell. Reduce ALL characters and their held weapons to 65% of current size, leaving generous transparent padding on every side including the right edge. Center each character's BODY exactly horizontally in its cell; every frame's foot/shadow baseline must be at 69% of its cell height (all rows). Use perfectly even grid of square cells: canvas aspect ratio exactly 3:4, preferably 1152x1536 pixels with 192px cells. Preserve relative scale within each family and consistent equipment. Row2 frame4 must hold shield on the same viewer-left side as all other south-facing Warrior frames, sword on viewer-right. Row1 and row3 show actual BACKS, row2 and row4 show fronts. Preserve all 48 separate walk-cycle poses and genuine transparency. No new details, no white background, no cropped swords or flames. Must look like crisp chunky Tiny Swords pixel sprites, no watercolor blur.

生成结果未严格遵守等距排布，所以运行时采用逐帧标定，不能按固定 192 像素网格切割补充图集。

## 验证

`tests/directional_animation_test.gd` 覆盖所有兵种四向选择、六帧循环、逻辑帧间隔、转向步态、停步、速度、暂停/冰冻、攻击切换、驻军及图集边界。实机对照图检查四类外观、三个阵营和四个方向。
