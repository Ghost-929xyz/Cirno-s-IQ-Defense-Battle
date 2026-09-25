# -*- coding: utf-8 -*-
"""生成全套"雾之湖冰晶"像素风 UI 资源到 assets/ui/。
包含：9-patch 面板/卡片/按钮四态/进度条、建筑与技能图标、资源图标、
头像冰晶圆环、稀有度卡框（普通/稀有/冰晶附魔）、标题装饰条。
"""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "ui")
PREVIEW_DIR = os.path.join(ROOT, ".tools")
os.makedirs(OUT_DIR, exist_ok=True)

# ---- 调色板：雾之湖冰晶 ----
INK = (6, 20, 32, 255)           # 最深阴影
DEEP = (10, 32, 52, 255)         # 深底
BODY = (16, 48, 76, 255)         # 主底
BODY_HI = (24, 66, 100, 255)     # 主底亮部
EDGE = (134, 233, 255, 255)      # 冰晶边框
EDGE_DIM = (61, 140, 175, 255)   # 暗边框
SHINE = (216, 251, 255, 255)     # 高光
ICE = (117, 217, 255, 255)       # 冰蓝
GOLD = (255, 214, 110, 255)      # 冰晶附魔金
PURPLE = (196, 148, 255, 255)    # 稀有紫
DISABLED = (88, 104, 118, 255)   # 置灰


def save(img, name):
    img.save(os.path.join(OUT_DIR, name))
    print("gen", name, img.size)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# ---------- 9-patch 面板/卡片/按钮/进度条 ----------

def draw_corner_crystal(d, x, y, color):
    """角部冰晶装饰（3px 小菱形）。"""
    d.point((x + 1, y), fill=color)
    d.point((x, y + 1), fill=color)
    d.point((x + 2, y + 1), fill=color)
    d.point((x + 1, y + 2), fill=color)


def gen_panel():
    w = h = 48
    img = new(w, h)
    d = ImageDraw.Draw(img)
    # 主体：微微上亮下暗的两段式底
    d.rectangle([2, 2, w - 3, h // 2], fill=(14, 44, 70, 242))
    d.rectangle([2, h // 2 + 1, w - 3, h - 3], fill=(10, 34, 56, 242))
    # 边框：外亮内暗双线
    d.rectangle([0, 0, w - 1, h - 1], outline=EDGE_DIM)
    d.rectangle([1, 1, w - 2, h - 2], outline=(96, 190, 224, 255))
    # 四角冰晶
    for cx, cy in ((1, 1), (w - 4, 1), (1, h - 4), (w - 4, h - 4)):
        draw_corner_crystal(d, cx, cy, SHINE)
    save(img, "panel.png")


def gen_card():
    w = h = 40
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, w - 3, h - 3], fill=(16, 47, 76, 255))
    d.rectangle([2, 2, w - 3, 8], fill=(22, 62, 96, 255))  # 顶部亮带
    d.rectangle([0, 0, w - 1, h - 1], outline=EDGE_DIM)
    d.rectangle([1, 1, w - 2, h - 2], outline=(46, 114, 146, 255))
    save(img, "card.png")


def gen_card_rarity(name, border, inner, glow):
    """稀有度卡框：普通冰蓝 / 稀有紫 / 冰晶附魔金。"""
    w = h = 40
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([3, 3, w - 4, h - 4], fill=(14, 40, 64, 255))
    d.rectangle([3, 3, w - 4, 9], fill=(20, 56, 88, 255))
    d.rectangle([0, 0, w - 1, h - 1], outline=border)
    d.rectangle([1, 1, w - 2, h - 2], outline=inner)
    # 四角宝石
    for cx, cy in ((1, 1), (w - 4, 1), (1, h - 4), (w - 4, h - 4)):
        draw_corner_crystal(d, cx, cy, glow)
    save(img, name)


def gen_button(name, body, body_hi, border, edge_hi, pressed=False):
    w = h = 32
    img = new(w, h)
    d = ImageDraw.Draw(img)
    if pressed:
        d.rectangle([2, 2, w - 3, h - 3], fill=body)
        d.rectangle([2, 2, w - 3, 4], fill=(8, 24, 40, 255))  # 按下时顶部压暗
    else:
        d.rectangle([2, 2, w - 3, h // 2], fill=body_hi)
        d.rectangle([2, h // 2 + 1, w - 3, h - 3], fill=body)
    d.rectangle([0, 0, w - 1, h - 1], outline=border)
    d.point([(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)], fill=edge_hi)
    save(img, name)


def gen_buttons():
    gen_button("button_normal.png", (16, 45, 70, 255), (24, 62, 94, 255), (44, 108, 142, 255), (120, 200, 240, 255))
    gen_button("button_hover.png", (22, 65, 93, 255), (34, 88, 126, 255), (150, 232, 255, 255), (220, 250, 255, 255))
    gen_button("button_pressed.png", (12, 36, 60, 255), (12, 36, 60, 255), (96, 180, 224, 255), (160, 220, 250, 255), pressed=True)
    gen_button("button_disabled.png", (26, 34, 44, 255), (30, 40, 52, 255), (70, 84, 98, 255), (100, 116, 130, 255))


def gen_bars():
    # 底槽 24x24
    img = new(24, 24)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 1, 22, 22], fill=(8, 24, 40, 255))
    d.rectangle([0, 0, 23, 23], outline=(44, 108, 142, 255))
    save(img, "bar_back.png")

    def fill(name, top, bottom, shine):
        img = new(24, 24)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 23, 10], fill=top)
        d.rectangle([0, 11, 23, 23], fill=bottom)
        d.rectangle([1, 2, 22, 4], fill=shine)  # 顶部冰面高光
        save(img, name)

    fill("bar_fill_green.png", (110, 235, 165, 255), (52, 175, 110, 255), (200, 255, 225, 140))
    fill("bar_fill_amber.png", (240, 205, 105, 255), (200, 150, 55, 255), (255, 240, 190, 140))
    fill("bar_fill_red.png", (240, 110, 130, 255), (185, 60, 82, 255), (255, 185, 195, 140))


# ---------- 图标绘制助手 ----------

def snowflake(d, cx, cy, r, color, width=1):
    """六角雪花。"""
    for k in range(6):
        a = math.radians(k * 60 - 90)
        x1 = cx + r * math.cos(a)
        y1 = cy + r * math.sin(a)
        d.line([cx, cy, x1, y1], fill=color, width=width)
        # 末端小枝
        bx = cx + r * 0.55 * math.cos(a)
        by = cy + r * 0.55 * math.sin(a)
        for da in (-35, 35):
            a2 = math.radians(k * 60 - 90 + da)
            d.line([bx, by, bx + r * 0.3 * math.cos(a2), by + r * 0.3 * math.sin(a2)], fill=color, width=width)


def crystal(d, cx, cy, w, h, body, edge, shine):
    """竖直冰晶（菱形截面柱体）。"""
    top = (cx, cy - h // 2)
    mid_l = (cx - w // 2, cy - h // 6)
    mid_r = (cx + w // 2, cy - h // 6)
    bot = (cx, cy + h // 2)
    d.polygon([top, mid_l, bot], fill=body)
    d.polygon([top, mid_r, bot], fill=tuple(max(0, c - 30) for c in body[:3]) + (255,))
    d.line([top, mid_l, bot, mid_r, top], fill=edge)
    d.line([cx, cy - h // 2 + 2, cx - w // 4, cy - h // 6], fill=shine)


# ---------- 建筑图标 32x32 ----------

def icon_base():
    img = new(32, 32)
    return img, ImageDraw.Draw(img)


def gen_icon_icicle():
    """冰锥琪露诺：一根大冰锥 + 碎冰。"""
    img, d = icon_base()
    crystal(d, 16, 15, 12, 22, (120, 215, 250, 255), (216, 251, 255, 255), (240, 255, 255, 255))
    crystal(d, 8, 21, 7, 12, (90, 185, 230, 255), (180, 240, 255, 255), (230, 250, 255, 255))
    crystal(d, 24, 21, 7, 12, (90, 185, 230, 255), (180, 240, 255, 255), (230, 250, 255, 255))
    d.rectangle([4, 27, 27, 28], fill=(70, 140, 180, 255))  # 底座
    save(img, "icon_icicle.png")


def gen_icon_rime():
    """雾凇琪露诺：大雪花 + 雾点。"""
    img, d = icon_base()
    snowflake(d, 16, 15, 11, (147, 239, 230, 255), width=2)
    snowflake(d, 16, 15, 5, (216, 251, 255, 255), width=1)
    for px, py in ((5, 26), (11, 28), (22, 27), (27, 25)):
        d.point((px, py), fill=(147, 239, 230, 180))
        d.point((px + 1, py), fill=(147, 239, 230, 120))
    save(img, "icon_rime.png")


def gen_icon_baka():
    """⑨式冰炮：炮管 + ⑨冰弹。"""
    img, d = icon_base()
    # 炮身（斜向上）
    d.polygon([(6, 24), (20, 12), (25, 17), (11, 29)], fill=(70, 120, 160, 255))
    d.line([(6, 24), (20, 12), (25, 17), (11, 29), (6, 24)], fill=(140, 210, 245, 255))
    # 炮口冰弹 ⑨
    d.ellipse([19, 3, 29, 13], fill=(117, 217, 255, 255), outline=(216, 251, 255, 255))
    d.arc([21, 5, 27, 11], start=40, end=320, fill=(10, 32, 52, 255), width=1)
    d.line([24, 8, 26, 6], fill=(10, 32, 52, 255))
    # 尾焰冰星
    d.point([(5, 22), (4, 24), (6, 26)], fill=(216, 251, 255, 255))
    save(img, "icon_baka.png")


def gen_icon_guard_barracks():
    """冰晶兵营：盾形要塞。"""
    img, d = icon_base()
    # 盾
    d.polygon([(16, 4), (27, 8), (27, 18), (16, 28), (5, 18), (5, 8)], fill=(97, 185, 240, 255))
    d.line([(16, 4), (27, 8), (27, 18), (16, 28), (5, 18), (5, 8), (16, 4)], fill=(216, 251, 255, 255))
    d.polygon([(16, 7), (24, 10), (24, 17), (16, 24), (8, 17), (8, 10)], fill=(16, 48, 76, 255))
    # 中央冰剑
    d.line([16, 8, 16, 20], fill=(216, 251, 255, 255), width=2)
    d.line([13, 12, 19, 12], fill=(216, 251, 255, 255), width=2)
    d.point((16, 21), fill=(216, 251, 255, 255))
    save(img, "icon_guard_barracks.png")


def gen_icon_archer_barracks():
    """雾矢兵营：弓与冰箭。"""
    img, d = icon_base()
    # 弓（弧形）
    d.arc([6, 4, 22, 28], start=-70, end=70, fill=(200, 245, 255, 255), width=2)
    # 弦
    d.line([19, 6, 19, 26], fill=(147, 239, 230, 255))
    # 冰箭
    d.line([8, 16, 26, 16], fill=(117, 217, 255, 255), width=2)
    d.polygon([(26, 16), (21, 12), (21, 20)], fill=(216, 251, 255, 255))  # 箭头
    d.line([8, 16, 5, 13], fill=(147, 239, 230, 255))
    d.line([8, 16, 5, 19], fill=(147, 239, 230, 255))
    save(img, "icon_archer_barracks.png")


def gen_icon_mage_barracks():
    """暴雪兵营：法杖 + 暴雪。"""
    img, d = icon_base()
    # 法杖
    d.line([10, 28, 20, 8], fill=(140, 110, 200, 255), width=2)
    # 杖顶冰球
    d.ellipse([17, 3, 25, 11], fill=(169, 141, 244, 255), outline=(226, 214, 255, 255))
    d.point((20, 6), fill=(240, 235, 255, 255))
    # 暴雪雪花
    snowflake(d, 9, 10, 5, (216, 251, 255, 255))
    snowflake(d, 24, 22, 4, (196, 148, 255, 255))
    d.point([(6, 20), (14, 24), (27, 15)], fill=(216, 251, 255, 200))
    save(img, "icon_mage_barracks.png")


# ---------- 技能图标 28x28 ----------

def gen_icon_nova():
    """冰霜新星：放射冰爆。"""
    img = new(28, 28)
    d = ImageDraw.Draw(img)
    cx = cy = 14
    d.ellipse([10, 10, 18, 18], fill=(216, 251, 255, 255))
    for k in range(8):
        a = math.radians(k * 45)
        r0, r1 = 5, 13
        d.line([cx + r0 * math.cos(a), cy + r0 * math.sin(a),
                cx + r1 * math.cos(a), cy + r1 * math.sin(a)], fill=(117, 217, 255, 255), width=2)
    d.ellipse([11, 11, 17, 17], fill=(36, 150, 210, 255))
    save(img, "icon_nova.png")


def gen_icon_freeze():
    """完美冻结：表盘 + 雪花。"""
    img = new(28, 28)
    d = ImageDraw.Draw(img)
    d.ellipse([3, 3, 25, 25], outline=(196, 148, 255, 255), width=2)
    snowflake(d, 14, 14, 8, (226, 214, 255, 255), width=1)
    d.point((14, 14), fill=(255, 255, 255, 255))
    save(img, "icon_freeze.png")


# ---------- 资源图标 16x16 ----------

def gen_icon_frost():
    img = new(16, 16)
    d = ImageDraw.Draw(img)
    snowflake(d, 8, 8, 6, (159, 244, 255, 255), width=1)
    d.point((8, 8), fill=(255, 255, 255, 255))
    save(img, "icon_frost.png")


def gen_icon_crystal():
    img = new(16, 16)
    d = ImageDraw.Draw(img)
    crystal(d, 8, 8, 9, 13, (150, 120, 240, 255), (226, 214, 255, 255), (240, 235, 255, 255))
    save(img, "icon_crystal.png")


# ---------- 头像冰晶圆环 64x64 ----------

def gen_portrait_ring():
    img = new(64, 64)
    d = ImageDraw.Draw(img)
    cx = cy = 32
    # 外环
    d.ellipse([2, 2, 62, 62], outline=(96, 190, 224, 255), width=2)
    d.ellipse([5, 5, 59, 59], outline=(134, 233, 255, 255), width=1)
    # 四向冰晶饰
    for k in range(4):
        a = math.radians(k * 90 - 90)
        px = cx + 30 * math.cos(a)
        py = cy + 30 * math.sin(a)
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(216, 251, 255, 255))
        d.ellipse([px - 1, py - 1, px + 1, py + 1], fill=(117, 217, 255, 255))
    save(img, "portrait_ring.png")


# ---------- 标题装饰条 560x24 ----------

def gen_title_banner():
    img = new(560, 24)
    d = ImageDraw.Draw(img)
    cy = 12
    # 中央大冰晶
    crystal(d, 280, cy, 14, 20, (117, 217, 255, 255), (216, 251, 255, 255), (240, 255, 255, 255))
    # 两侧渐变线条
    for x in range(30, 262):
        t = (x - 30) / 232.0
        c = tuple(int(a + (b - a) * t) for a, b in zip((134, 233, 255, 40), (134, 233, 255, 255)))
        d.point((x, cy), fill=c)
        d.point((560 - x, cy), fill=c)
    # 小冰晶点缀
    for px in (200, 360):
        draw_corner_crystal(d, px - 1, cy - 1, (216, 251, 255, 255))
    save(img, "title_banner.png")


# ---------- 小地图边框 (9-patch 32x32) ----------

def gen_minimap_frame():
    w = h = 32
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(96, 190, 224, 230))
    d.rectangle([1, 1, w - 2, h - 2], outline=(40, 100, 135, 230))
    for cx, cy in ((0, 0), (w - 3, 0), (0, h - 3), (w - 3, h - 3)):
        draw_corner_crystal(d, cx, cy, (216, 251, 255, 255))
    save(img, "minimap_frame.png")


gen_panel()
gen_card()
gen_card_rarity("card_common.png", (96, 190, 224, 255), (46, 114, 146, 255), (216, 251, 255, 255))
gen_card_rarity("card_rare.png", PURPLE, (120, 80, 180, 255), (230, 210, 255, 255))
gen_card_rarity("card_enchant.png", GOLD, (180, 140, 60, 255), (255, 240, 190, 255))
gen_buttons()
gen_bars()
gen_icon_icicle()
gen_icon_rime()
gen_icon_baka()
gen_icon_guard_barracks()
gen_icon_archer_barracks()
gen_icon_mage_barracks()
gen_icon_nova()
gen_icon_freeze()
gen_icon_frost()
gen_icon_crystal()
gen_portrait_ring()
gen_title_banner()
gen_minimap_frame()
print("ALL_UI_OK")
