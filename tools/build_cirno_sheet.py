# -*- coding: utf-8 -*-
"""用抠好的 cirno_char.png（32x32 透明底）生成游戏精灵表 cirno.png。
布局与 cirno_sprite.gd 约定一致：96x144，24x24/帧，4 列，
行序 idle(4)/walk(4)/attack(4)/cast(4)/hurt(2)/death(4)，朝右绘制。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR = os.path.join(ROOT, "assets", "sprites", "cirno_char.png")
OUT = os.path.join(ROOT, "assets", "sprites", "cirno.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno.png")

FRAME = 24
COLS, ROWS = 4, 6

base = Image.open(CHAR).convert("RGBA")
# 角色主体约 25px 宽，缩到 20px 宽以留出动作空间
bw = 20
bh = round(base.size[1] * bw / base.size[0])
if bh > 22:
    bh = 22
    bw = round(base.size[0] * bh / base.size[1])
char = base.resize((bw, bh), Image.NEAREST)


def place(img, dx=0, dy=0):
    """把角色贴进 24x24 帧，底部对齐（脚底 y=22）。"""
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    ox = (FRAME - img.size[0]) // 2 + dx
    oy = 22 - img.size[1] + dy
    frame.paste(img, (ox, oy), img)
    return frame


def rot(img, deg):
    return img.rotate(deg, resample=Image.NEAREST, expand=False)


sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))

rows = [
    # idle：轻微上下浮动
    [place(char, 0, 0), place(char, 0, -1), place(char, 0, 0), place(char, 0, 1)],
    # walk：左右交替倾斜 + 上下颠
    [place(rot(char, -8), 0, 0), place(char, 0, -1), place(rot(char, 8), 0, 0), place(char, 0, -1)],
    # attack：向前（右）冲刺
    [place(char, 0, 0), place(rot(char, -10), 1, 0), place(rot(char, -14), 3, 0), place(char, 1, 0)],
    # cast：上浮举起
    [place(char, 0, 0), place(char, 0, -2), place(rot(char, -6), 0, -3), place(rot(char, 6), 0, -3)],
    # hurt：左右抖动（白闪由游戏内 modulate 负责）
    [place(char, -2, 0), place(char, 2, 0), place(char, 0, 0), place(char, 0, 0)],
    # death：逐帧倒地淡出
    [place(char, 0, 0), place(rot(char, -30), 0, 1), place(rot(char, -60), 0, 2), place(rot(char, -85), 0, 3)],
]

for row_idx, frames in enumerate(rows):
    for col_idx, frame in enumerate(frames):
        sheet.paste(frame, (col_idx * FRAME, row_idx * FRAME), frame)

sheet.save(OUT)
sheet.resize((FRAME * COLS * 8, FRAME * ROWS * 8), Image.NEAREST).save(PREVIEW)
print("SHEET_OK", OUT, sheet.size, "->", PREVIEW)
