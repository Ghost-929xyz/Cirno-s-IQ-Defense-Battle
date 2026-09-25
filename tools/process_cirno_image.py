# -*- coding: utf-8 -*-
"""把用户提供的琪露诺立绘处理成局内精灵：
1. 边缘洪水填充去白底（保留角色身上的白色高光）
2. 裁剪到内容包围盒
3. 像素化缩放到 32x32
输出 assets/sprites/cirno_char.png
"""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\Xuyize\Downloads\9BCBE0BC383E1F9970F6C790F6399537.png"
OUT = os.path.join(ROOT, "assets", "sprites", "cirno_char.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno_char.png")

TOL = 28  # 与白色的距离容差

img = Image.open(SRC).convert("RGBA")
# 先在低分辨率上做背景标记，速度快且能平滑噪点
WORK = 640
work = img.resize((WORK, WORK), Image.LANCZOS)
px = work.load()

def is_white(c):
    return c[0] >= 255 - TOL and c[1] >= 255 - TOL and c[2] >= 255 - TOL

bg = bytearray(WORK * WORK)  # 1 = 背景
q = deque()
for x in range(WORK):
    for y in (0, WORK - 1):
        if is_white(px[x, y]):
            bg[y * WORK + x] = 1
            q.append((x, y))
for y in range(WORK):
    for x in (0, WORK - 1):
        if is_white(px[x, y]):
            bg[y * WORK + x] = 1
            q.append((x, y))
while q:
    x, y = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < WORK and 0 <= ny < WORK and not bg[ny * WORK + nx] and is_white(px[nx, ny]):
            bg[ny * WORK + nx] = 1
            q.append((nx, ny))

# 内容包围盒（低分辨率坐标）
minx, miny, maxx, maxy = WORK, WORK, -1, -1
for y in range(WORK):
    for x in range(WORK):
        if not bg[y * WORK + x]:
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y
print("content bbox(work):", minx, miny, maxx, maxy)

# 映射回原图裁剪（留一点边距）
scale = img.size[0] / WORK
pad = 4
cx0 = max(0, int((minx - pad) * scale))
cy0 = max(0, int((miny - pad) * scale))
cx1 = min(img.size[0], int((maxx + pad) * scale))
cy1 = min(img.size[1], int((maxy + pad) * scale))
char = img.crop((cx0, cy0, cx1, cy1))
print("cropped:", char.size)

# 在高分辨率裁剪图上重新做一次背景透明化（用相同的洪水填充）
cw, ch = char.size
SMALL = 320
csmall = char.resize((SMALL, int(SMALL * ch / cw)), Image.LANCZOS)
spx = csmall.load()
sw, sh = csmall.size
bg2 = bytearray(sw * sh)
q = deque()
for x in range(sw):
    for y in (0, sh - 1):
        if is_white(spx[x, y]):
            bg2[y * sw + x] = 1; q.append((x, y))
for y in range(sh):
    for x in (0, sw - 1):
        if is_white(spx[x, y]):
            bg2[y * sw + x] = 1; q.append((x, y))
while q:
    x, y = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < sw and 0 <= ny < sh and not bg2[ny * sw + nx] and is_white(spx[nx, ny]):
            bg2[ny * sw + nx] = 1; q.append((nx, ny))
for y in range(sh):
    for x in range(sw):
        if bg2[y * sw + x]:
            spx[x, y] = (0, 0, 0, 0)

# 像素化：缩到 32 高（保持比例），NEAREST 还原像素感
target_h = 32
target_w = max(1, round(sw * target_h / sh))
sprite = csmall.resize((target_w, target_h), Image.NEAREST)

# 放进 32x32 画布居中（底部对齐，方便局内锚点在中心）
canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
ox = (32 - target_w) // 2
oy = 32 - target_h
canvas.paste(sprite, (ox, oy), sprite)
canvas.save(OUT)
canvas.resize((256, 256), Image.NEAREST).save(PREVIEW)
print("SPRITE_OK", OUT, canvas.size, "->", PREVIEW)
