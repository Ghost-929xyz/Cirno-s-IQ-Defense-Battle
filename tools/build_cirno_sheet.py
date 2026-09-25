# -*- coding: utf-8 -*-
"""用抠好的 cirno_char.png（高清透明底）生成游戏精灵表 cirno.png。
布局与 cirno_sprite.gd 约定一致：384x576，96x96/帧，4 列，
行序 idle(4)/walk(4)/attack(4)/cast(4)/hurt(2)/death(4)，朝右绘制。
高清版：LANCZOS 缩放 / BICUBIC 旋转，保留立绘细节。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR = os.path.join(ROOT, "assets", "sprites", "cirno_char.png")
OUT = os.path.join(ROOT, "assets", "sprites", "cirno.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno.png")

FRAME = 96
COLS, ROWS = 4, 6
FOOT_Y = 88  # 脚底在帧内的 y 坐标

base = Image.open(CHAR).convert("RGBA")
# 角色贴进帧内：宽不超过 76，高不超过 86，底部对齐
bw = 76
bh = round(base.size[1] * bw / base.size[0])
if bh > 86:
    bh = 86
    bw = round(base.size[0] * bh / base.size[1])
char = base.resize((bw, bh), Image.LANCZOS)


def place(img, dx=0, dy=0):
    """把角色贴进 96x96 帧，底部对齐（脚底 y=FOOT_Y）。"""
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    ox = (FRAME - img.size[0]) // 2 + dx
    oy = FOOT_Y - img.size[1] + dy
    frame.paste(img, (ox, oy), img)
    return frame


def rot(img, deg):
    return img.rotate(deg, resample=Image.BICUBIC, expand=False)


sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))

rows = [
    # idle：轻微上下浮动
    [place(char, 0, 0), place(char, 0, -3), place(char, 0, 0), place(char, 0, 3)],
    # walk：左右交替倾斜 + 上下颠
    [place(rot(char, -8), 0, 0), place(char, 0, -3), place(rot(char, 8), 0, 0), place(char, 0, -3)],
    # attack：向前（右）冲刺
    [place(char, 0, 0), place(rot(char, -10), 4, 0), place(rot(char, -14), 10, 0), place(char, 4, 0)],
    # cast：上浮举起
    [place(char, 0, 0), place(char, 0, -6), place(rot(char, -6), 0, -9), place(rot(char, 6), 0, -9)],
    # hurt：左右抖动（白闪由游戏内 modulate 负责）
    [place(char, -6, 0), place(char, 6, 0), place(char, 0, 0), place(char, 0, 0)],
    # death：逐帧倒地淡出
    [place(char, 0, 0), place(rot(char, -30), 0, 3), place(rot(char, -60), 0, 6), place(rot(char, -85), 0, 9)],
]

for row_idx, frames in enumerate(rows):
    for col_idx, frame in enumerate(frames):
        sheet.paste(frame, (col_idx * FRAME, row_idx * FRAME), frame)

sheet.save(OUT)

# 预览：深色底 + 网格线
preview = Image.new("RGBA", sheet.size, (40, 44, 52, 255))
preview.paste(sheet, (0, 0), sheet)
from PIL import ImageDraw
draw = ImageDraw.Draw(preview)
for c in range(COLS + 1):
    draw.line([(c * FRAME, 0), (c * FRAME, FRAME * ROWS)], fill=(90, 96, 110, 255))
for r in range(ROWS + 1):
    draw.line([(0, r * FRAME), (FRAME * COLS, r * FRAME)], fill=(90, 96, 110, 255))
preview.save(PREVIEW)
print("SHEET_OK", OUT, sheet.size, "->", PREVIEW)
