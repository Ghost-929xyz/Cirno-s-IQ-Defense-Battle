# -*- coding: utf-8 -*-
"""把用户提供的琪露诺立绘处理成局内精灵素材：
1. 边缘洪水填充去白底（保留角色身上的白色高光）
2. 边缘去白边（defringe，避免缩放后出现白色毛边）
3. 裁剪到内容包围盒
4. 高清缩放到 512px 高透明底 PNG（不再像素化）
输出 assets/sprites/cirno_char.png
"""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\Xuyize\Downloads\9BCBE0BC383E1F9970F6C790F6399537.png"
OUT = os.path.join(ROOT, "assets", "sprites", "cirno_char.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno_char.png")

TOL = 30  # 与白色的距离容差
TARGET_H = 512

img = Image.open(SRC).convert("RGBA")

# 在 1024 工作分辨率上做背景标记：足够精确且速度快
WORK = 1024
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

# 内容包围盒
minx, miny, maxx, maxy = WORK, WORK, -1, -1
for y in range(WORK):
    for x in range(WORK):
        if not bg[y * WORK + x]:
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y
print("content bbox(work):", minx, miny, maxx, maxy)

pad = 6
cx0 = max(0, minx - pad)
cy0 = max(0, miny - pad)
cx1 = min(WORK, maxx + pad + 1)
cy1 = min(WORK, maxy + pad + 1)
char = work.crop((cx0, cy0, cx1, cy1))
cw, ch = char.size
print("cropped:", char.size)

# 在裁剪图上重做一次洪水填充（坐标系变了），并记录前景边缘带
cpx = char.load()
bg2 = bytearray(cw * ch)
q = deque()
for x in range(cw):
    for y in (0, ch - 1):
        if is_white(cpx[x, y]):
            bg2[y * cw + x] = 1; q.append((x, y))
for y in range(ch):
    for x in (0, cw - 1):
        if is_white(cpx[x, y]):
            bg2[y * cw + x] = 1; q.append((x, y))
while q:
    x, y = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < cw and 0 <= ny < ch and not bg2[ny * cw + nx] and is_white(cpx[nx, ny]):
            bg2[ny * cw + nx] = 1; q.append((nx, ny))

# 背景像素全透明；与背景相邻的前景像素按"白度"给半透明，去掉白边
for y in range(ch):
    for x in range(cw):
        if bg2[y * cw + x]:
            cpx[x, y] = (0, 0, 0, 0)
for y in range(ch):
    for x in range(cw):
        if bg2[y * cw + x]:
            continue
        near_bg = False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < cw and 0 <= ny < ch and bg2[ny * cw + nx]:
                near_bg = True
                break
        if near_bg:
            r, g, b, a = cpx[x, y]
            whiteness = min(r, g, b)
            if whiteness > 160:
                alpha = int(255 * (255 - whiteness) / (255 - 160))
                cpx[x, y] = (r, g, b, max(0, min(255, alpha)))

# 高清缩放（LANCZOS 平滑），不再像素化
target_w = max(1, round(cw * TARGET_H / ch))
sprite = char.resize((target_w, TARGET_H), Image.LANCZOS)
sprite.save(OUT)

# 预览：棋盘格底上看透明效果
preview = Image.new("RGBA", (target_w, TARGET_H), (40, 44, 52, 255))
preview.paste(sprite, (0, 0), sprite)
preview.save(PREVIEW)
print("SPRITE_OK", OUT, sprite.size, "->", PREVIEW)
