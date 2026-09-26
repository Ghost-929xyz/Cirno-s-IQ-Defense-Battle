# -*- coding: utf-8 -*-
"""把 1536x1024 的四向行走原表（8 列 x 4 行，单元格 192x256）归一化为
游戏直接可用的 768x384 精灵表（96x96/帧）。
行序保持源表顺序：down / left / right / up（与 cirno_sprite.gd 约定一致）。
每帧按 alpha 内容包围盒裁剪，缩放到固定高度后底部对齐、水平居中。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get("CIRNO_SRC", os.path.join(ROOT, "assets", "sprites", "cirno_directional_raw.png"))
OUT = os.path.join(ROOT, "assets", "sprites", "cirno.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno_directional.png")

COLS, ROWS = 8, 4
FRAME = 96
FOOT_Y = 88        # 脚底在帧内的 y 坐标
BODY_H = 84        # 归一化后的内容高度上限
BODY_W = 92        # 内容宽度上限

src = Image.open(SRC).convert("RGBA")
cell_w = src.size[0] // COLS   # 192
cell_h = src.size[1] // ROWS   # 256
print("source", src.size, "cell", cell_w, cell_h)

sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))

for row in range(ROWS):
    for col in range(COLS):
        cell = src.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        bbox = cell.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if bbox is None:
            print("empty cell", row, col)
            continue
        content = cell.crop(bbox)
        cw, ch = content.size
        scale = min(BODY_H / ch, BODY_W / cw)
        nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
        content = content.resize((nw, nh), Image.LANCZOS)
        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        ox = (FRAME - nw) // 2
        oy = FOOT_Y - nh
        frame.paste(content, (ox, oy), content)
        sheet.paste(frame, (col * FRAME, row * FRAME))

sheet.save(OUT)
# 预览：放大 2 倍 + 网格线
preview = sheet.resize((FRAME * COLS * 2, FRAME * ROWS * 2), Image.NEAREST)
grid = Image.new("RGBA", preview.size, (0, 0, 0, 0))
from PIL import ImageDraw
d = ImageDraw.Draw(grid)
for i in range(COLS + 1):
    d.line([(i * FRAME * 2, 0), (i * FRAME * 2, FRAME * ROWS * 2)], fill=(255, 64, 64, 180))
for i in range(ROWS + 1):
    d.line([(0, i * FRAME * 2), (FRAME * COLS * 2, i * FRAME * 2)], fill=(255, 64, 64, 180))
preview = Image.alpha_composite(preview, grid)
preview.save(PREVIEW)
print("saved", OUT, sheet.size)
