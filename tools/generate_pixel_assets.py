# -*- coding: utf-8 -*-
"""像素风素材生成器：地图 / 琪露诺精灵表 / UI 九宫格贴图。

用法：python tools/generate_pixel_assets.py
- 地图：读取 assets/maps/map_user_backup.png 的逻辑格（路径/核心/出生点/空地），
  以完全相同的逻辑重新绘制美术，输出 assets/maps/map.png。生成后会按游戏同样的
  采样规则回读校验，逻辑格不一致则报错退出。
- 精灵表：assets/sprites/cirno.png，24x24/帧，行=动画（idle/walk/attack/cast/hurt/death）。
- UI：assets/ui/*.png 九宫格贴图（面板/按钮/进度条/卡牌）。
"""
import os
import random
import shutil
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP_OUT = os.path.join(ROOT, "assets", "maps", "map.png")
MAP_BACKUP = os.path.join(ROOT, "assets", "maps", "map_user_backup.png")
SPRITE_OUT = os.path.join(ROOT, "assets", "sprites", "cirno.png")
UI_DIR = os.path.join(ROOT, "assets", "ui")

CELL = 2            # 每逻辑格 2x2 图像像素
COLS, ROWS = 128, 96
W, H = COLS * CELL, ROWS * CELL

# 逻辑色（与 scripts/game/map_view.gd 保持一致）
COLOR_PATH = (10, 15, 20)
COLOR_CORE = (255, 226, 107)
COLOR_SPAWN = (126, 240, 164)
TOL = 45  # 0.18 * 255 取整，留一点余量


def _close(a, b, tol=TOL):
    return all(abs(a[i] - b[i]) <= tol for i in range(3))


def classify(pixel):
    """与 map_view.gd 的采样判定一致。返回 path/core/spawn/land。"""
    r, g, b, a = pixel
    if a < 128:
        return "land"
    c = (r, g, b)
    if _close(c, COLOR_CORE):
        return "core"
    if _close(c, COLOR_SPAWN):
        return "spawn"
    if _close(c, COLOR_PATH):
        return "path"
    return "land"


def read_grid(img):
    grid = {}
    for cy in range(ROWS):
        for cx in range(COLS):
            grid[(cx, cy)] = classify(img.getpixel((cx * CELL + 1, cy * CELL + 1)))
    return grid


# ---------------------------------------------------------------- 地图

def gen_map():
    if not os.path.exists(MAP_BACKUP):
        shutil.copy(MAP_OUT, MAP_BACKUP)
    src = Image.open(MAP_BACKUP).convert("RGBA")
    if src.size != (W, H):
        raise SystemExit("备份地图尺寸异常: %s" % (src.size,))
    grid = read_grid(src)

    rng = random.Random(20260925)
    img = Image.new("RGBA", (W, H))
    px = img.load()

    grass = [(52, 88, 74), (58, 98, 80), (48, 82, 70), (62, 104, 84), (55, 92, 78)]
    grass_dark = [(64, 108, 88), (58, 100, 82), (70, 116, 94)]
    path_stone = [(14, 20, 32), (18, 26, 40), (12, 18, 26), (20, 28, 42), (16, 24, 36)]

    def vary(c, amt=6):
        return tuple(max(0, min(255, v + rng.randint(-amt, amt))) for v in c)

    # 池塘（椭圆，格坐标）
    pond_c, pond_rx, pond_ry = (22, 73), 11.0, 6.5

    def pond_kind(cx, cy):
        dx = (cx - pond_c[0]) / pond_rx
        dy = (cy - pond_c[1]) / pond_ry
        d = dx * dx + dy * dy
        if d <= 0.72:
            return "water"
        if d <= 1.0:
            return "water_edge"
        return None

    lilies = {(17, 71), (26, 76), (21, 78)}
    rocks = {(90, 20), (91, 20), (90, 21), (60, 80), (61, 80), (100, 60), (44, 30)}

    def is_border(cx, cy):
        return cx < 2 or cy < 2 or cx >= COLS - 2 or cy >= ROWS - 2

    for cy in range(ROWS):
        for cx in range(COLS):
            kind = grid[(cx, cy)]
            bx, by = cx * CELL, cy * CELL
            if kind == "core":
                for i in range(4):
                    px[bx + i % 2, by + i // 2] = COLOR_CORE + (255,)
                continue
            if kind == "spawn":
                for i in range(4):
                    px[bx + i % 2, by + i // 2] = COLOR_SPAWN + (255,)
                continue
            if kind == "path":
                base = vary(rng.choice(path_stone), 4)
                for i in range(4):
                    px[bx + i % 2, by + i // 2] = vary(base, 5) + (255,)
                # 鹅卵石高光（只放在非采样像素）
                if rng.random() < 0.28:
                    px[bx, by] = (42, 54, 72, 255)
                # 面向空地的路缘提亮（采样像素 (1,1) 保持深色）
                rim = (34, 48, 66, 255)
                if grid.get((cx - 1, cy)) == "land":
                    px[bx, by] = rim
                    px[bx, by + 1] = rim
                if grid.get((cx + 1, cy)) == "land":
                    px[bx + 1, by] = rim
                if grid.get((cx, cy - 1)) == "land":
                    px[bx, by] = rim
                    px[bx + 1, by] = rim
                if grid.get((cx, cy + 1)) == "land":
                    px[bx, by + 1] = rim
                # 边界入口格：外侧像素点青光，提示出怪口
                if is_border(cx, cy):
                    px[bx, by] = (70, 190, 225, 255)
                continue

            # 空地
            pond = pond_kind(cx, cy)
            if pond == "water":
                base = vary((38, 92, 128), 8)
            elif pond == "water_edge":
                base = vary((30, 72, 104), 6)
            elif (cx, cy) in rocks:
                base = vary((100, 108, 118), 6)
            elif (cx, cy) in lilies:
                base = vary((62, 138, 84), 6)
            elif is_border(cx, cy):
                base = vary(rng.choice(grass_dark), 5)
            else:
                base = vary(rng.choice(grass), 5)
            for i in range(4):
                px[bx + i % 2, by + i // 2] = vary(base, 6) + (255,)
            # 非采样像素上的点缀
            r = rng.random()
            if pond == "water":
                if r < 0.10:
                    px[bx, by] = (120, 190, 225, 255)  # 水面闪光
            elif pond is None and (cx, cy) not in rocks and (cx, cy) not in lilies:
                if r < 0.30:
                    px[bx, by] = vary((92, 132, 98), 6) + (255,)  # 草簇
                elif r < 0.36:
                    px[bx, by] = (205, 170, 230, 255)  # 小花
                if 20 <= cy <= 24 or 48 <= cy <= 52 or 76 <= cy <= 80:
                    if rng.random() < 0.35:
                        px[bx + 1, by] = (200, 228, 245, 90)  # 湖面雾气
            elif (cx, cy) in rocks and r < 0.6:
                px[bx, by] = (140, 150, 160, 255)

    # ---- 回读校验：逻辑格必须与备份完全一致 ----
    new_grid = read_grid(img)
    diff = [c for c in grid if grid[c] != new_grid[c]]
    if diff:
        sample = diff[:8]
        raise SystemExit("地图逻辑校验失败，%d 格不一致，示例: %s" % (len(diff), sample))
    img.save(MAP_OUT)
    prev = img.resize((W * 4, H * 4), Image.NEAREST)
    prev.save(os.path.join(ROOT, ".tools", "preview_map.png"))
    counts = {}
    for v in grid.values():
        counts[v] = counts.get(v, 0) + 1
    print("MAP_OK", counts)


# ---------------------------------------------------------------- UI 贴图

def _border_rect(px, w, h, inset, color, thickness=1):
    for t in range(thickness):
        i = inset + t
        for x in range(i, w - i):
            px[x, i] = color
            px[x, h - 1 - i] = color
        for y in range(i, h - i):
            px[i, y] = color
            px[w - 1 - i, y] = color


def _fill_rect(px, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = color


def _save(img, name):
    img.save(os.path.join(UI_DIR, name))
    print("UI_OK", name, img.size)


def gen_ui():
    os.makedirs(UI_DIR, exist_ok=True)

    # 面板 48x48，九宫边距 16
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = img.load()
    _fill_rect(px, 2, 2, 45, 45, (11, 28, 48, 242))
    _border_rect(px, 48, 48, 0, (52, 118, 160, 255), 2)
    _border_rect(px, 48, 48, 3, (140, 220, 250, 110), 1)
    for cx, cy, sx, sy in [(0, 0, 1, 1), (47, 0, -1, 1), (0, 47, 1, -1), (47, 47, -1, -1)]:
        for i in range(1, 6):
            px[cx + sx * i, cy] = (150, 235, 255, 255)
            px[cx, cy + sy * i] = (150, 235, 255, 255)
        px[cx + sx, cy + sy] = (150, 235, 255, 255)
    _save(img, "panel.png")

    # 卡牌 48x48，九宫边距 14（祝福/附魔三选一）
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = img.load()
    _fill_rect(px, 2, 2, 45, 45, (20, 32, 60, 245))
    _border_rect(px, 48, 48, 0, (150, 128, 64, 255), 1)
    _border_rect(px, 48, 48, 1, (216, 184, 96, 255), 1)
    _border_rect(px, 48, 48, 4, (240, 220, 150, 90), 1)
    for cx, cy in [(5, 5), (42, 5), (5, 42), (42, 42)]:
        px[cx, cy] = (255, 236, 170, 255)
    _save(img, "card.png")

    # 按钮 32x32，九宫边距 10
    def button(name, fill, border, hi, hi_top=True):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        px = img.load()
        _fill_rect(px, 2, 2, 29, 29, fill)
        _border_rect(px, 32, 32, 0, border, 2)
        if hi_top:
            for x in range(3, 29):
                px[x, 3] = hi
        else:
            for x in range(3, 29):
                px[x, 28] = hi
        _save(img, name)

    button("button_normal.png", (20, 50, 78, 255), (64, 142, 190, 255), (120, 200, 240, 130))
    button("button_hover.png", (30, 74, 108, 255), (150, 232, 255, 255), (200, 245, 255, 170))
    button("button_pressed.png", (14, 36, 60, 255), (96, 180, 224, 255), (60, 120, 165, 140), hi_top=False)

    # 进度条 24x24，九宫边距 6
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = img.load()
    _fill_rect(px, 1, 1, 22, 22, (8, 20, 34, 255))
    _border_rect(px, 24, 24, 0, (40, 92, 128, 255), 1)
    for x in range(2, 22):
        px[x, 2] = (4, 10, 18, 255)
    _save(img, "bar_back.png")

    def bar_fill(name, top, bottom, edge):
        img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
        px = img.load()
        for y in range(1, 23):
            t = (y - 1) / 21.0
            c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
            for x in range(1, 23):
                px[x, y] = c
        for x in range(2, 22):
            px[x, 2] = tuple(min(255, v + 40) for v in top) + (160,)
        _border_rect(px, 24, 24, 0, edge, 1)
        _save(img, name)

    bar_fill("bar_fill_green.png", (110, 235, 165), (52, 175, 110), (200, 255, 225, 255))
    bar_fill("bar_fill_amber.png", (240, 205, 105), (200, 150, 55), (255, 240, 190, 255))
    bar_fill("bar_fill_red.png", (240, 110, 130), (185, 60, 82), (255, 185, 195, 255))



# ---------------------------------------------------------------- 琪露诺精灵表
# 24x24/帧，朝右绘制，游戏内 flip_h 镜像。行：idle/walk/attack/cast/hurt/death。
FW, FH = 24, 24
ROWS_ANIM = ["idle", "walk", "attack", "cast", "hurt", "death"]
ANIM_COUNTS = {"idle": 4, "walk": 4, "attack": 4, "cast": 4, "hurt": 2, "death": 4}

HAIR = (168, 232, 255)
HAIR_SH = (110, 190, 235)
HAIR_HI = (230, 250, 255)
SKIN = (255, 217, 184)
SKIN_SH = (238, 178, 138)
EYE = (28, 58, 110)
DRESS = (46, 111, 216)
DRESS_SH = (30, 79, 168)
DRESS_HI = (120, 170, 240)
WHITE = (234, 247, 255)
BOW = (36, 86, 200)
WING = (184, 242, 255)
WING_SH = (110, 200, 239)
WING_HI = (255, 255, 255)
SHOE = (30, 55, 96)
OUT = (20, 44, 84)


def _lerp(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


class Frame:
    def __init__(self, sheet, ox, oy):
        self.sheet = sheet
        self.ox = ox
        self.oy = oy

    def p(self, x, y, c):
        if 0 <= x < FW and 0 <= y < FH:
            self.sheet.putpixel((self.ox + x, self.oy + y), c + (255,))

    def pa(self, x, y, c, a):
        if 0 <= x < FW and 0 <= y < FH:
            self.sheet.putpixel((self.ox + x, self.oy + y), c + (a,))

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.p(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.p(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, c)

    def diamond(self, cx, cy, w, h, c):
        for dy in range(-h, h + 1):
            half = int(round(w * (1.0 - abs(dy) / float(h + 0.001))))
            if half < 0:
                continue
            self.hline(cx - half, cx + half, cy + dy, c)

    def sparkle(self, cx, cy, c=WING_HI):
        self.p(cx, cy, c)
        self.p(cx - 1, cy, c)
        self.p(cx + 1, cy, c)
        self.p(cx, cy - 1, c)
        self.p(cx, cy + 1, c)


def _shard(f, sx, sy, tx, ty, c, hi):
    """从肩部 (sx,sy) 向尖端 (tx,ty) 画一枚冰晶翼片。"""
    steps = 5
    for i in range(steps + 1):
        t = i / float(steps)
        x = int(round(sx + (tx - sx) * t))
        y = int(round(sy + (ty - sy) * t))
        w = 1 if t < 0.75 else 0
        f.hline(x - w, x + w, y, c)
    # 白色芯线
    for i in range(2, steps):
        t = i / float(steps)
        x = int(round(sx + (tx - sx) * t))
        y = int(round(sy + (ty - sy) * t))
        f.p(x, y, hi)


def draw_wings(f, dy=0, flap=0, bright=False):
    c = WING if not bright else _lerp(WING, WING_HI, 0.5)
    hi = WING_HI
    tips_l = [(3, 3 - flap), (1, 8), (4, 14 + flap)]
    tips_r = [(20, 3 - flap), (22, 8), (19, 14 + flap)]
    for tx, ty in tips_l:
        _shard(f, 9, 10 + dy, tx, ty + dy, c, hi)
    for tx, ty in tips_r:
        _shard(f, 15, 10 + dy, tx, ty + dy, c, hi)


def draw_head(f, dy=0, lean=0, eyes="open", hair_sway=0):
    cx = 12 + lean
    top = 4 + dy
    # 皮肤圆脸
    for yy in range(top + 3, top + 9):
        half = 4 if top + 4 <= yy <= top + 7 else 3
        f.hline(cx - half, cx + half, yy, SKIN)
    f.p(cx - 3, top + 8, SKIN_SH)
    f.p(cx + 3, top + 8, SKIN_SH)
    # 头发（盖住上半）
    f.hline(cx - 4, cx + 4, top, HAIR)
    f.hline(cx - 5, cx + 5, top + 1, HAIR)
    f.hline(cx - 5, cx + 5, top + 2, HAIR)
    f.hline(cx - 5, cx + 5, top + 3, HAIR)
    # 刘海锯齿
    for bx in range(cx - 5, cx + 6):
        if (bx - cx) % 2 == 0:
            f.p(bx, top + 4, HAIR)
    # 两侧垂发
    f.vline(cx - 5, top + 4, top + 6 + hair_sway, HAIR)
    f.vline(cx + 5, top + 4, top + 5 + hair_sway, HAIR)
    f.p(cx - 5, top + 7 + hair_sway, HAIR_SH)
    # 高光与阴影
    f.p(cx - 3, top + 1, HAIR_HI)
    f.p(cx - 2, top + 1, HAIR_HI)
    f.p(cx + 4, top + 2, HAIR_SH)
    f.p(cx + 4, top + 3, HAIR_SH)
    # 蝴蝶结（头顶）
    f.p(cx - 1, top - 1, BOW)
    f.p(cx + 1, top - 1, BOW)
    f.p(cx - 3, top - 2, BOW)
    f.p(cx - 2, top - 1, BOW)
    f.p(cx + 3, top - 2, BOW)
    f.p(cx + 2, top - 1, BOW)
    f.p(cx, top - 1, OUT)
    # 眼睛（朝右，偏右半个像素位）
    ey = top + 5
    if eyes == "open":
        f.p(cx - 1, ey, EYE)
        f.p(cx - 1, ey + 1, EYE)
        f.p(cx + 2, ey, EYE)
        f.p(cx + 2, ey + 1, EYE)
        f.p(cx - 1, ey, (200, 230, 255)) if False else None
    elif eyes == "closed":
        f.p(cx - 1, ey + 1, OUT)
        f.p(cx + 2, ey + 1, OUT)
    elif eyes == "x":
        f.p(cx - 2, ey, OUT)
        f.p(cx, ey + 1, OUT)
        f.p(cx, ey, OUT)
        f.p(cx - 2, ey + 1, OUT)
        f.p(cx + 1, ey, OUT)
        f.p(cx + 3, ey + 1, OUT)
        f.p(cx + 3, ey, OUT)
        f.p(cx + 1, ey + 1, OUT)
    # 嘴
    if eyes != "x":
        f.p(cx + 1, ey + 3, (200, 120, 110))
    # 腮红
    f.p(cx - 3, ey + 2, (250, 190, 170))
    f.p(cx + 4, ey + 2, (250, 190, 170))


def draw_body(f, dy=0, lean=0, arm="down", leg_phase=0, hem_sway=0):
    cx = 12 + lean
    ty = 12 + dy  # 躯干顶
    # 袖子/手臂
    if arm == "up":
        f.p(cx - 4, ty - 3, WHITE)
        f.p(cx - 4, ty - 4, SKIN)
        f.p(cx + 4, ty - 3, WHITE)
        f.p(cx + 4, ty - 4, SKIN)
        f.p(cx - 4, ty - 2, WHITE)
        f.p(cx + 4, ty - 2, WHITE)
    elif arm == "thrust":
        f.p(cx - 4, ty + 1, WHITE)
        f.p(cx - 4, ty + 2, SKIN)
        f.hline(cx + 4, cx + 7, ty + 1, WHITE)
        f.p(cx + 8, ty + 1, SKIN)
    else:
        f.p(cx - 4, ty + 1, WHITE)
        f.p(cx - 4, ty + 2, SKIN)
        f.p(cx + 4, ty + 1, WHITE)
        f.p(cx + 4, ty + 2, SKIN)
    # 躯干
    f.rect(cx - 2, ty, cx + 2, ty + 3, DRESS)
    # 白领
    f.hline(cx - 2, cx + 2, ty, WHITE)
    f.p(cx - 2, ty + 1, WHITE)
    f.p(cx + 2, ty + 1, WHITE)
    f.p(cx + 2, ty + 2, DRESS_SH)  # 右侧阴影
    f.p(cx + 2, ty + 3, DRESS_SH)
    # 裙摆
    f.hline(cx - 3, cx + 3, ty + 4, DRESS)
    f.hline(cx - 4, cx + 4, ty + 5, DRESS)
    f.p(cx + 3, ty + 4, DRESS_SH)
    f.p(cx + 4, ty + 5, DRESS_SH)
    f.p(cx - 3, ty + 4, DRESS_HI)  # 左侧受光
    # 白色裙边（随步伐摆动）
    hem_y = ty + 6
    for x in range(cx - 4, cx + 5):
        f.p(x + (hem_sway if x < cx else 0), hem_y, WHITE)
    # 腿与鞋
    ly = ty + 7
    if leg_phase == 0:  # 并拢
        f.vline(cx - 1, ly, ly + 1, SKIN)
        f.vline(cx + 1, ly, ly + 1, SKIN)
        f.p(cx - 1, ly + 2, SHOE)
        f.p(cx + 1, ly + 2, SHOE)
        f.p(cx, ly + 2, SHOE)
    elif leg_phase == 1:  # 左腿前
        f.p(cx, ly, SKIN)
        f.p(cx + 1, ly + 1, SKIN)
        f.p(cx + 1, ly + 2, SHOE)
        f.p(cx - 2, ly, SKIN)
        f.p(cx - 2, ly + 1, SHOE)
    else:  # 右腿前
        f.p(cx - 1, ly, SKIN)
        f.p(cx - 2, ly + 1, SKIN)
        f.p(cx - 2, ly + 2, SHOE)
        f.p(cx + 1, ly, SKIN)
        f.p(cx + 2, ly + 1, SHOE)


def draw_standing(f, dy=0, lean=0, wing_flap=0, wing_bright=False, eyes="open",
                  arm="down", leg_phase=0, hair_sway=0, hem_sway=0, sparkles=None,
                  tint=None):
    draw_wings(f, dy=dy, flap=wing_flap, bright=wing_bright)
    draw_body(f, dy=dy, lean=lean, arm=arm, leg_phase=leg_phase, hem_sway=hem_sway)
    draw_head(f, dy=dy, lean=lean, eyes=eyes, hair_sway=hair_sway)
    for sx, sy in (sparkles or []):
        f.sparkle(sx, sy)
    if tint is not None:
        _tint_frame(f, tint)


def draw_lying(f, fade=0.0):
    """倒下：侧躺在地。fade>0 时整体变淡（灵魂消散）。"""
    base_y = 19
    hair = _lerp(HAIR, (220, 245, 255), fade)
    dress = _lerp(DRESS, (190, 225, 250), fade)
    skin = _lerp(SKIN, (235, 225, 220), fade)
    wing = _lerp(WING, (230, 250, 255), fade)
    # 翅膀摊在地上
    _shard(f, 6, base_y + 2, 2, base_y + 3, wing, WING_HI)
    _shard(f, 6, base_y + 2, 4, base_y + 4, wing, WING_HI)
    _shard(f, 16, base_y + 2, 21, base_y + 3, wing, WING_HI)
    _shard(f, 16, base_y + 2, 19, base_y + 4, wing, WING_HI)
    # 头（左侧）
    for yy in range(base_y - 3, base_y + 1):
        half = 3 if base_y - 2 <= yy <= base_y - 1 else 2
        f.hline(6 - half, 6 + half, yy, skin)
    f.hline(3, 9, base_y - 4, hair)
    f.hline(2, 8, base_y - 3, hair)
    f.vline(2, base_y - 3, base_y, hair)
    f.p(3, base_y - 4, HAIR_HI)
    # X 眼
    f.p(5, base_y - 2, OUT)
    f.p(6, base_y - 1, OUT)
    f.p(6, base_y - 2, OUT)
    f.p(5, base_y - 1, OUT)
    # 身体横倒
    f.rect(9, base_y - 2, 16, base_y, dress)
    f.p(10, base_y - 3, WHITE)
    f.hline(17, 18, base_y - 1, skin)
    f.p(19, base_y - 1, SHOE)
    f.hline(17, 18, base_y + 1, skin)
    f.p(19, base_y + 1, SHOE)
    f.p(11, base_y, _lerp(DRESS_SH, (200, 230, 250), fade))
    if fade > 0.3:
        # 灵魂小光点上升
        f.sparkle(12, 8, WING_HI)
        f.sparkle(14, 5, WING)


def _tint_frame(f, toward, t=0.55):
    for y in range(FH):
        for x in range(FW):
            r, g, b, a = f.sheet.getpixel((f.ox + x, f.oy + y))
            if a > 0:
                f.sheet.putpixel((f.ox + x, f.oy + y), _lerp((r, g, b), toward, t) + (a,))


def gen_sprites():
    cols = 4
    sheet = Image.new("RGBA", (cols * FW, len(ROWS_ANIM) * FH), (0, 0, 0, 0))

    def frame(anim, index):
        row = ROWS_ANIM.index(anim)
        return Frame(sheet, index * FW, row * FH)

    # idle：翼尖微颤 + 眨眼
    idle_params = [
        dict(dy=0, wing_flap=0, eyes="open"),
        dict(dy=0, wing_flap=1, eyes="open", hair_sway=0),
        dict(dy=1, wing_flap=0, eyes="closed"),
        dict(dy=0, wing_flap=-1, eyes="open", hair_sway=1),
    ]
    for i, kw in enumerate(idle_params):
        draw_standing(frame("idle", i), **kw)

    # walk：四帧步伐
    walk_params = [
        dict(dy=0, leg_phase=1, wing_flap=1, hem_sway=1, hair_sway=1),
        dict(dy=1, leg_phase=0, wing_flap=0),
        dict(dy=0, leg_phase=2, wing_flap=-1, hem_sway=-1, hair_sway=0),
        dict(dy=1, leg_phase=0, wing_flap=0),
    ]
    for i, kw in enumerate(walk_params):
        draw_standing(frame("walk", i), **kw)

    # attack：蓄力→前刺→回收
    attack_params = [
        dict(dy=0, lean=-1, arm="down", wing_flap=1),
        dict(dy=0, lean=1, arm="thrust", wing_flap=-1, sparkles=[(21, 10)]),
        dict(dy=0, lean=1, arm="thrust", wing_flap=-1, sparkles=[(22, 11)]),
        dict(dy=0, lean=0, arm="down", wing_flap=0),
    ]
    for i, kw in enumerate(attack_params):
        draw_standing(frame("attack", i), **kw)

    # cast：双手举起、翅膀增亮、雪花环绕
    cast_params = [
        dict(dy=1, arm="up", wing_bright=False),
        dict(dy=0, arm="up", wing_bright=True, sparkles=[(4, 5)]),
        dict(dy=0, arm="up", wing_bright=True, sparkles=[(4, 5), (19, 5)]),
        dict(dy=0, arm="up", wing_bright=True, sparkles=[(4, 5), (19, 5), (12, 1)]),
    ]
    for i, kw in enumerate(cast_params):
        draw_standing(frame("cast", i), **kw)

    # hurt：后仰 + X 眼
    draw_standing(frame("hurt", 0), dy=0, lean=-1, eyes="x", wing_flap=1, hair_sway=1)
    draw_standing(frame("hurt", 1), dy=1, lean=-1, eyes="x", wing_flap=0, tint=(255, 255, 255))

    # death：眩晕→跪倒→躺倒→消散
    draw_standing(frame("death", 0), dy=1, lean=0, eyes="x", wing_flap=1, sparkles=[(18, 3)])
    f = frame("death", 1)
    draw_wings(f, dy=3, flap=-1)
    draw_body(f, dy=3, lean=0, arm="down", leg_phase=0)
    draw_head(f, dy=3, lean=0, eyes="x")
    draw_lying(frame("death", 2), fade=0.0)
    draw_lying(frame("death", 3), fade=0.65)

    sheet.save(SPRITE_OUT)
    prev = sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST)
    prev.save(os.path.join(ROOT, ".tools", "preview_cirno.png"))
    print("SPRITE_OK", SPRITE_OUT, sheet.size)


def main():
    gen_map()
    gen_ui()
    gen_sprites()
    print("DONE all")


if __name__ == "__main__":
    main()

