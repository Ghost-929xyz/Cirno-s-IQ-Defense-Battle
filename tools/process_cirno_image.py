# -*- coding: utf-8 -*-
"""把用户提供的琪露诺立绘处理成局内精灵素材：
1. 原图自带透明通道时直接按 alpha 抠图（2026-09-26 新版 5120x5120）
2. 否则回退到边缘洪水填充去白底（保留角色身上的白色高光）
3. 裁剪到内容包围盒，高清缩放到 512px 高透明底 PNG
输出 assets/sprites/cirno_char.png
"""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"C:\Users\Xuyize\Documents\Tencent Files\1951654845\nt_qq\nt_data\Pic\2026-09\Ori\9bcbe0bc383e1f9970f6c790f6399537.png"
OUT = os.path.join(ROOT, "assets", "sprites", "cirno_char.png")
PREVIEW = os.path.join(ROOT, ".tools", "preview_cirno_char.png")

TOL = 30  # 与白色的距离容差（回退路径用）
TARGET_H = 512
PAD = 8

img = Image.open(SRC).convert("RGBA")

# 检测原图是否自带透明背景：四边采样，透明像素占比超过一半即认为有 alpha 底
w, h = img.size
alpha = img.getchannel("A")
border_samples = []
for x in range(0, w, max(1, w // 64)):
    border_samples.append(alpha.getpixel((x, 0)))
    border_samples.append(alpha.getpixel((x, h - 1)))
for y in range(0, h, max(1, h // 64)):
    border_samples.append(alpha.getpixel((0, y)))
    border_samples.append(alpha.getpixel((w - 1, y)))
transparent_ratio = sum(1 for a in border_samples if a < 16) / len(border_samples)
has_alpha_bg = transparent_ratio > 0.5
print("border transparent ratio: %.2f -> has_alpha_bg=%s" % (transparent_ratio, has_alpha_bg))

if has_alpha_bg:
    # 路径 A：直接用 alpha 通道。缩到 1024 工作分辨率提速，再求包围盒
    WORK = 1024
    work = img.resize((WORK, WORK), Image.LANCZOS)
    bbox = work.getchannel("A").getbbox()
    print("content bbox(work):", bbox)
    cx0 = max(0, bbox[0] - PAD)
    cy0 = max(0, bbox[1] - PAD)
    cx1 = min(WORK, bbox[2] + PAD)
    cy1 = min(WORK, bbox[3] + PAD)
    char = work.crop((cx0, cy0, cx1, cy1))
else:
    # 路径 B：白底洪水填充（旧管线）
    WORK = 1024
    work = img.resize((WORK, WORK), Image.LANCZOS)
    px = work.load()

    def is_white(c):
        return c[0] >= 255 - TOL and c[1] >= 255 - TOL and c[2] >= 255 - TOL

    bg = bytearray(WORK * WORK)
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

    minx, miny, maxx, maxy = WORK, WORK, -1, -1
    for y in range(WORK):
        for x in range(WORK):
            if not bg[y * WORK + x]:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    print("content bbox(work):", minx, miny, maxx, maxy)

    cx0 = max(0, minx - PAD)
    cy0 = max(0, miny - PAD)
    cx1 = min(WORK, maxx + PAD + 1)
    cy1 = min(WORK, maxy + PAD + 1)
    char = work.crop((cx0, cy0, cx1, cy1))
    cw, ch = char.size

    # 裁剪图上重做一次洪水填充，背景全透明 + 边缘按白度去白边
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
                    alpha_v = int(255 * (255 - whiteness) / (255 - 160))
                    cpx[x, y] = (r, g, b, max(0, min(255, alpha_v)))

cw, ch = char.size
print("cropped:", char.size)

# 高清缩放（LANCZOS 平滑），512px 高
target_w = max(1, round(cw * TARGET_H / ch))
sprite = char.resize((target_w, TARGET_H), Image.LANCZOS)
sprite.save(OUT)

# 预览：深色底上看透明效果
preview = Image.new("RGBA", (target_w, TARGET_H), (40, 44, 52, 255))
preview.paste(sprite, (0, 0), sprite)
preview.save(PREVIEW)
print("SPRITE_OK", OUT, sprite.size, "->", PREVIEW)
