# Kevencre : peint tous les visuels à l'aquarelle (procédural) à partir des grilles des niveaux.
# Usage : python3 tools/paint.py [dossier du projet]
import os, sys, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..')
ART = os.path.join(ROOT, 'art')
S = 24            # pixels par case dans les peintures (affichées x2 dans le jeu)
rng = np.random.default_rng(11)


# ------------------------------------------------------------------ outils
def box(a, r, axis):
    if r < 1:
        return a
    c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode='edge'), axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def blur(a, r, it=3):
    r = int(max(1, r))
    for _ in range(it):
        a = box(box(a, r, 0), r, 1)
    return a


def noise(h, w, scale, seed=None, aniso=1.0):
    g = np.random.default_rng(seed if seed is not None else rng.integers(1 << 30))
    gh = max(2, int(h / scale) + 2)
    gw = max(2, int(w / (scale * aniso)) + 2)
    small = g.random((gh, gw)).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0


def fbm(h, w, scale, oct=4, seed=None, aniso=1.0):
    seed = seed if seed is not None else int(rng.integers(1 << 30))
    acc = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(oct):
        acc += noise(h, w, max(1.5, scale / (2 ** o)), seed + o * 17, aniso) * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def periodic_noise(n, freq, seed):
    g = np.random.default_rng(seed)
    white = g.standard_normal((n, n))
    F = np.fft.fft2(white)
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2) * n
    filt = np.exp(-(f / freq) ** 2)
    out = np.real(np.fft.ifft2(F * filt))
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out


def hexc(s):
    s = s.lstrip('#')
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def new_canvas(h, w, paper=(0.96, 0.94, 0.89)):
    c = np.ones((h, w, 3), np.float32)
    c[:] = paper
    return c


def soft_mask(binary, r=2, rough=0.25, scale=6):
    m = blur(binary.astype(np.float32), r, 2)
    if rough > 0:
        m = m + (fbm(m.shape[0], m.shape[1], scale, 3) - 0.5) * rough
    return np.clip((m - 0.5) * 4 + 0.5, 0, 1)


def wash(canvas, mask, color, opacity=0.8, edge=0.5, gran=0.25, bleed=1):
    """Glacis d'aquarelle : multiplie la couleur, assombrit les bords, granule."""
    h, w = mask.shape
    m = mask
    if bleed > 0:
        m = np.maximum(m, blur(m, bleed, 1) * 0.9)
    g = 1.0 - gran + gran * 2 * fbm(h, w, 3, 2)
    a = np.clip(m * opacity * g, 0, 1)
    e = np.clip(m - blur(m, 4, 2), 0, 1) * edge * 2.2
    a = np.clip(a + e * opacity, 0, 1)[..., None]
    col = np.asarray(color, np.float32)[None, None, :]
    canvas *= (1 - a) + a * col
    return canvas


def poly_mask(h, w, pts):
    im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
    return np.asarray(im, np.float32) / 255.0


def ellipse_mask(h, w, items):
    im = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(im)
    for (x, y, rx, ry) in items:
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=255)
    return np.asarray(im, np.float32) / 255.0


def to_img(canvas, alpha=None):
    c = np.clip(canvas * 255, 0, 255).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(c, 'RGB')
    a = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([c, a]), 'RGBA')


def ridge(w, base, amp, scale, seed, oct=4):
    n = fbm(1, w, scale, oct, seed)[0]
    return base - (n - 0.5) * 2 * amp


def ridge_periodic(w, base, amp, waves, seed):
    g = np.random.default_rng(seed)
    x = np.arange(w) / w * 2 * np.pi
    y = np.zeros(w)
    for k in range(1, waves + 1):
        y += g.uniform(0.3, 1.0) / k * np.sin(k * x + g.uniform(0, 6.28))
    y = y / np.abs(y).max()
    return base - y * amp


def fill_below(h, w, line):
    yy = np.arange(h)[:, None]
    return (yy >= line[None, :]).astype(np.float32)


# ------------------------------------------------------------------ papier
def paper():
    n = 512
    a = periodic_noise(n, 60, 1) * 0.5 + periodic_noise(n, 180, 2) * 0.35 + periodic_noise(n, 12, 3) * 0.15
    fib = periodic_noise(n, 220, 4)
    v = 0.84 + 0.16 * a - 0.05 * (fib > 0.7)
    img = np.dstack([v * 1.0, v * 0.985, v * 0.955])
    to_img(np.clip(img, 0, 1)).save(os.path.join(ART, 'papier.png'))


# ------------------------------------------------------------------ thèmes
THEMES = {
    1: dict(top='#7fb547', top2='#a7c95a', soil='#9a7650', deep='#5e4634', rock='#b8a68a', ink='#3a3048',
            plank='#8a5a34', flowers=['#e2533f', '#f2c14e', '#ffffff', '#c86fb4', '#5c8fd6'], deco='meadow'),
    2: dict(top='#3f8f6f', top2='#68b08a', soil='#4f5a52', deep='#2c3436', rock='#7e8f8a', ink='#22303a',
            plank='#5c4a36', flowers=['#d8f0ff', '#9fd4ff', '#f6e27a', '#e98ab0'], deco='forest'),
    3: dict(top='#c7a04a', top2='#e0bd63', soil='#b8693a', deep='#7a3f27', rock='#e2b383', ink='#4a2a22',
            plank='#7a4a2a', flowers=['#f3e9c6', '#e9733d', '#ffd36b'], deco='cliff'),
    4: dict(top='#6d6880', top2='#8a85a0', soil='#4a4558', deep='#2c2936', rock='#7a7590', ink='#1c1a26',
            plank='#6a4a32', flowers=['#bbbbbb'], deco='atelier'),
}


def load_grid(n):
    if n == 4:
        g = []
        for y in range(20):
            row = ''
            for x in range(34):
                ch = '.'
                if x < 2 or x > 31 or y > 16 or y == 0:
                    ch = '#'
                elif y == 13 and (5 <= x <= 9 or 24 <= x <= 28):
                    ch = '='
                elif y == 9 and 14 <= x <= 19:
                    ch = '='
                row += ch
            g.append(row)
        return g
    with open(os.path.join(ROOT, 'levels', '%d.txt' % n)) as f:
        return [l.rstrip('\n') for l in f if l.strip()]


def terrain_render(grid, th, solid_chars, seed):
    H, W = len(grid), len(grid[0])
    h, w = H * S, W * S
    binary = np.zeros((h, w), np.float32)
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c in solid_chars:
                binary[y * S:(y + 1) * S, x * S:(x + 1) * S] = 1
    # bords organiques (le bord extérieur du niveau reste plein)
    m = soft_mask(binary, 3, 0.35, 5)
    m = np.maximum(m, binary * (blur(binary, 4, 1) > 0.97))
    alpha = m
    solid = m > 0.5
    # profondeur depuis la surface du dessus
    depth = np.zeros((h, w), np.float32)
    acc = np.zeros(w, np.float32)
    for y in range(h):
        acc = (acc + 1) * solid[y]
        depth[y] = acc
    jag = (fbm(h, w, 4, 3, seed + 1) - 0.5) * 8
    d = depth + jag
    top, top2, soil, deep, rock = (hexc(th[k]) for k in ('top', 'top2', 'soil', 'deep', 'rock'))
    t1 = np.clip(d / 7.0, 0, 1)[..., None]
    t2 = np.clip((d - 7) / 60.0, 0, 1)[..., None]
    t3 = np.clip((d - 60) / 140.0, 0, 1)[..., None]
    col = top2 * (1 - t1) + top * t1
    soilc = soil * (1 - t3) + deep * t3
    is_top = (d < 9)[..., None]
    col = np.where(is_top, col, soilc * (1 - t2 * 0.0))
    # coups de pinceau horizontaux
    strokes = fbm(h, w, 7, 3, seed + 2, aniso=5.0)
    col = col * (0.82 + 0.36 * strokes[..., None])
    gran = fbm(h, w, 1.6, 2, seed + 3)
    col = col * (0.9 + 0.2 * gran[..., None])
    # cailloux dans la terre
    im = Image.new('L', (w, h), 0)
    dr = ImageDraw.Draw(im)
    rr = np.random.default_rng(seed + 4)
    for _ in range(int(w * h / 1700)):
        x, y = rr.integers(0, w), rr.integers(0, h)
        if depth[y, x] > 22:
            rx, ry = rr.uniform(3, 9), rr.uniform(2, 6)
            dr.ellipse([x - rx, y - ry, x + rx, y + ry], fill=int(rr.uniform(120, 255)))
    pebble = np.asarray(im, np.float32)[..., None] / 255.0
    pmask = (pebble > 0).astype(np.float32)
    col = col * (1 - pmask * 0.4) + rock[None, None, :] * pmask * 0.4 * (0.7 + 0.3 * pebble)
    outline_p = np.clip(blur(pmask[..., 0], 1, 1) - pmask[..., 0], 0, 1)[..., None]
    col = col * (1 - outline_p * 0.5)
    # bords : assombrissement façon aquarelle + trait d'encre
    inner = blur(m, 5, 2)
    edge = np.clip((1 - inner) * m * 2.0, 0, 1)[..., None]
    col = col * (1 - edge * 0.35)
    ink = hexc(th['ink'])
    er = np.clip(m - blur(m, 1, 1), 0, 1) * 3.0
    wobble = 0.55 + 0.45 * fbm(h, w, 10, 2, seed + 5)
    line = np.clip(er * wobble, 0, 1)[..., None]
    col = col * (1 - line * 0.85) + ink * line * 0.85
    return col, alpha, depth, binary


def draw_grass(img, grid, depth_bin, th, seed, solid_chars='#'):
    H, W = len(grid), len(grid[0])
    d = ImageDraw.Draw(img, 'RGBA')
    rr = np.random.default_rng(seed)
    top = hexc(th['top']); top2 = hexc(th['top2'])
    fl = [tuple(int(v * 255) for v in hexc(c)) for c in th['flowers']]
    for y in range(1, H):
        for x in range(W):
            if grid[y][x] in solid_chars and grid[y - 1][x] not in solid_chars and grid[y - 1][x] not in 'X':
                y0 = y * S
                for k in range(9):
                    gx = x * S + rr.uniform(0, S)
                    gl = rr.uniform(4, 11) * (0.6 if th['deco'] in ('cliff', 'atelier') else 1.0)
                    lean = rr.uniform(-3, 3)
                    c = top * rr.uniform(0.6, 1.15) if rr.random() < 0.6 else top2 * rr.uniform(0.8, 1.1)
                    c = tuple(int(np.clip(v, 0, 1) * 255) for v in c) + (230,)
                    d.line([(gx, y0 + 2), (gx + lean, y0 - gl)], fill=c, width=2)
                if th['deco'] in ('meadow', 'forest') and rr.random() < 0.35:
                    fx = x * S + rr.uniform(2, S - 2)
                    fy = y0 - rr.uniform(4, 10)
                    c = fl[rr.integers(len(fl))]
                    d.line([(fx, y0), (fx, fy)], fill=(70, 110, 60, 200), width=1)
                    r = rr.uniform(1.6, 3.0)
                    d.ellipse([fx - r, fy - r, fx + r, fy + r], fill=c + (240,))


def draw_planks(img, grid, th, seed):
    d = ImageDraw.Draw(img, 'RGBA')
    rr = np.random.default_rng(seed)
    pc = hexc(th['plank'])
    H, W = len(grid), len(grid[0])
    for y in range(H):
        x = 0
        while x < W:
            if grid[y][x] == '=':
                x2 = x
                while x2 + 1 < W and grid[y][x2 + 1] == '=':
                    x2 += 1
                X1, X2, Y = x * S, (x2 + 1) * S, y * S
                if th['deco'] == 'forest':
                    # branche moussue
                    d.rounded_rectangle([X1 - 4, Y, X2 + 4, Y + 8], 4, fill=tuple(int(v * 255) for v in pc) + (255,), outline=(40, 30, 25, 255), width=1)
                    for k in range((x2 - x + 1) * 4):
                        mx = X1 + rr.uniform(0, X2 - X1)
                        d.ellipse([mx - 3, Y - 2, mx + 3, Y + 2], fill=(80, 150, 100, 230))
                else:
                    d.rounded_rectangle([X1 - 2, Y, X2 + 2, Y + 8], 2, fill=tuple(int(v * 255) for v in pc) + (255,), outline=(45, 30, 22, 255), width=1)
                    d.line([(X1, Y + 3), (X2, Y + 3)], fill=tuple(int(v * 180) for v in pc) + (180,), width=1)
                    for k in range(x, x2 + 2):
                        d.line([(k * S, Y), (k * S, Y + 8)], fill=(45, 30, 22, 150), width=1)
                    # cordes / supports
                    for px_ in (X1 + 4, X2 - 4):
                        d.line([(px_, Y + 8), (px_ + rr.uniform(-3, 3), Y + 18)], fill=(60, 45, 35, 160), width=2)
                x = x2 + 1
            else:
                x += 1


def deco_layer(grid, th, seed):
    """Arbres, buissons, rochers derrière le terrain (moins contrastés)."""
    H, W = len(grid), len(grid[0])
    h, w = H * S, W * S
    canvas = np.ones((h, w, 3), np.float32)
    alpha = np.zeros((h, w), np.float32)
    rr = np.random.default_rng(seed)
    kind = th['deco']
    spots = []
    for y in range(4, H):
        for x in range(2, W - 2):
            if grid[y][x] == '#' and grid[y - 1][x] == '.' and all(grid[yy][x] == '.' for yy in range(max(0, y - 4), y)):
                spots.append((x, y))
    rr.shuffle(spots)
    used = set()
    count = 0
    for (x, y) in spots:
        if any((x + k, y) in used for k in range(-5, 6)):
            continue
        if rr.random() > 0.5:
            continue
        used.add((x, y))
        count += 1
        bx, by = x * S + S // 2, y * S + 4
        if kind == 'meadow':
            if rr.random() < 0.55:
                th_ = rr.uniform(60, 95)
                trunk = poly_mask(h, w, [(bx - 3, by), (bx + 3, by), (bx + 2, by - th_ * 0.6), (bx - 2, by - th_ * 0.6)])
                wash(canvas, trunk, hexc('#7a5a44'), 0.9, 0.4, 0.2, 0); alpha = np.maximum(alpha, trunk)
                blobs = [(bx + rr.uniform(-18, 18), by - th_ * rr.uniform(0.6, 1.0), rr.uniform(16, 26), rr.uniform(14, 22)) for _ in range(6)]
                m = soft_mask(ellipse_mask(h, w, blobs) > 0.5, 2, 0.3, 4)
                c = hexc(['#6fa64a', '#86b552', '#5d9a55'][rr.integers(3)])
                wash(canvas, m, c, 0.85, 0.6, 0.35, 1); alpha = np.maximum(alpha, m)
                m2 = soft_mask(ellipse_mask(h, w, [(b[0] - 5, b[1] - 6, b[2] * 0.5, b[3] * 0.4) for b in blobs[:3]]) > 0.5, 1, 0.2, 3)
                wash(canvas, m2, hexc('#c9e08a'), 0.5, 0.2, 0.3, 0)
            else:
                blobs = [(bx + rr.uniform(-14, 14), by - rr.uniform(4, 12), rr.uniform(9, 15), rr.uniform(7, 11)) for _ in range(4)]
                m = soft_mask(ellipse_mask(h, w, blobs) > 0.5, 1, 0.25, 3)
                wash(canvas, m, hexc('#7cae4e'), 0.85, 0.6, 0.3, 1); alpha = np.maximum(alpha, m)
                for _ in range(3):
                    fx, fy = bx + rr.uniform(-12, 12), by - rr.uniform(6, 16)
                    fm = ellipse_mask(h, w, [(fx, fy, 2.5, 2.5)])
                    wash(canvas, fm, hexc(th['flowers'][rr.integers(len(th['flowers']))]), 0.95, 0.1, 0.1, 0)
        elif kind == 'forest':
            if rr.random() < 0.6:
                th_ = rr.uniform(110, 170)
                trunk = poly_mask(h, w, [(bx - 6, by), (bx + 6, by), (bx + 3, by - th_), (bx - 3, by - th_)])
                wash(canvas, trunk, hexc('#4c4a46'), 0.85, 0.5, 0.25, 0); alpha = np.maximum(alpha, trunk)
                blobs = [(bx + rr.uniform(-30, 30), by - th_ + rr.uniform(-20, 25), rr.uniform(22, 36), rr.uniform(14, 24)) for _ in range(7)]
                m = soft_mask(ellipse_mask(h, w, blobs) > 0.5, 3, 0.35, 5)
                wash(canvas, m, hexc(['#2f7d68', '#3c8f74', '#2a6d63'][rr.integers(3)]), 0.8, 0.7, 0.35, 2); alpha = np.maximum(alpha, m * 0.95)
            else:
                # fougères
                for k in range(5):
                    a = -math.pi / 2 + rr.uniform(-0.9, 0.9)
                    L = rr.uniform(16, 30)
                    pts = [(bx, by), (bx + math.cos(a - 0.15) * L * 0.6, by + math.sin(a - 0.15) * L * 0.6), (bx + math.cos(a) * L, by + math.sin(a) * L), (bx + math.cos(a + 0.15) * L * 0.6, by + math.sin(a + 0.15) * L * 0.6)]
                    m = poly_mask(h, w, pts)
                    wash(canvas, m, hexc('#4f9f72'), 0.8, 0.4, 0.2, 0); alpha = np.maximum(alpha, m)
        elif kind == 'cliff':
            if rr.random() < 0.5:
                blobs = [(bx + rr.uniform(-12, 12), by - rr.uniform(2, 8), rr.uniform(8, 14), rr.uniform(6, 10)) for _ in range(3)]
                m = soft_mask(ellipse_mask(h, w, blobs) > 0.5, 1, 0.2, 3)
                wash(canvas, m, hexc('#9a8a5a'), 0.85, 0.6, 0.3, 1); alpha = np.maximum(alpha, m)
            else:
                pts = [(bx - 14, by), (bx - 10, by - rr.uniform(12, 20)), (bx + 2, by - rr.uniform(16, 26)), (bx + 13, by - rr.uniform(8, 14)), (bx + 15, by)]
                m = soft_mask(poly_mask(h, w, pts) > 0.5, 1, 0.2, 3)
                wash(canvas, m, hexc('#c98a5a'), 0.85, 0.7, 0.35, 1); alpha = np.maximum(alpha, m)
    return canvas, alpha


def paint_level(n):
    grid = load_grid(n)
    th = THEMES[n]
    H, W = len(grid), len(grid[0])
    out = os.path.join(ART, 'l%d' % n)
    os.makedirs(out, exist_ok=True)
    seed = 100 * n
    col, alpha, depth, binary = terrain_render(grid, th, '#', seed)
    # décor derrière
    dc, da = deco_layer(grid, th, seed + 50)
    da = da * 0.92
    a_t = alpha[..., None]
    comp = col * a_t + dc * (1 - a_t)
    comp_a = np.maximum(alpha, da)
    # mélange : là où il n'y a que du décor, garder sa couleur
    img = to_img(comp, comp_a)
    draw_grass(img, grid, depth, th, seed + 7)
    draw_planks(img, grid, th, seed + 8)
    # découpe en morceaux
    w = W * S
    chunks = []
    CW = 1024
    for i, x0 in enumerate(range(0, w, CW)):
        part = img.crop((x0, 0, min(w, x0 + CW), H * S))
        fn = 'terrain_%d.png' % i
        part.save(os.path.join(out, fn), optimize=True)
        chunks.append({'file': fn, 'x': x0 * 2, 'y': 0})
    # caches des faux murs
    covers = []
    if any('X' in r for r in grid):
        gx = [''.join('X' if (c == 'P' and any(0 <= yy + dy < H and 0 <= xx + dx < W and grid[yy + dy][xx + dx] == 'X' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))) else c for xx, c in enumerate(r)) for yy, r in enumerate(grid)]
        colx, alx, _, binx = terrain_render(gx, th, '#X', seed)
        xmask = np.zeros((H * S, W * S), np.float32)
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                near_x = any(0 <= y + dy < H and 0 <= x + dx < W and grid[y + dy][x + dx] == 'X' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if c == 'X' or (c == 'P' and near_x):
                    xmask[y * S:(y + 1) * S, x * S:(x + 1) * S] = 1
        xm = np.clip(blur(xmask, 2, 1) * 1.5, 0, 1) * alx
        full = to_img(colx, xm)
        seen = set()
        k = 0
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                if c == 'X' and (x, y) not in seen:
                    stack = [(x, y)]; cells = []
                    while stack:
                        cx, cy = stack.pop()
                        if (cx, cy) in seen or not (0 <= cy < H and 0 <= cx < W) or grid[cy][cx] != 'X':
                            continue
                        seen.add((cx, cy)); cells.append((cx, cy))
                        stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
                    tx1 = min(c[0] for c in cells) - 1; ty1 = min(c[1] for c in cells) - 1
                    tx2 = max(c[0] for c in cells) + 1; ty2 = max(c[1] for c in cells) + 1
                    crop = full.crop((tx1 * S, ty1 * S, (tx2 + 1) * S, (ty2 + 1) * S))
                    fn = 'cover_%d.png' % k
                    crop.save(os.path.join(out, fn))
                    covers.append({'file': fn, 'x': tx1 * S * 2, 'y': ty1 * S * 2, 'tx': tx1, 'ty': ty1, 'tw': tx2 - tx1 + 1, 'th': ty2 - ty1 + 1})
                    k += 1
    meta = {'scale': 2, 'chunks': chunks, 'covers': covers}
    meta.update(paint_background(n, out))
    with open(os.path.join(out, 'meta.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('niveau', n, 'peint :', len(chunks), 'morceaux,', len(covers), 'caches')


# ------------------------------------------------------------------ fonds
def sky(h, w, top, bottom, clouds=True, seed=0, cloud_col='#ffffff'):
    t = np.linspace(0, 1, h)[:, None, None]
    c = hexc(top) * (1 - t) + hexc(bottom) * t
    c = np.repeat(c, w, axis=1)
    if clouds:
        n = fbm(h, w, 40, 5, seed, aniso=2.5)
        m = np.clip((n - 0.55) * 4, 0, 1) * np.clip(1.2 - np.linspace(0, 1, h)[:, None] * 1.3, 0, 1)
        cc = hexc(cloud_col)
        c = c * (1 - m[..., None] * 0.6) + cc * m[..., None] * 0.6
        e = np.clip(m - blur(m, 3, 2), 0, 1)
        c = c * (1 - e[..., None] * 0.25)
    g = fbm(h, w, 2, 2, seed + 9)
    return c * (0.95 + 0.08 * g[..., None])


def layer_from_ridge(h, w, line, color, edge=0.6, seed=0, detail=None, opacity=0.9):
    canvas = np.ones((h, w, 3), np.float32)
    m = soft_mask(fill_below(h, w, line), 2, 0.3, 4)
    wash(canvas, m, hexc(color), opacity, edge, 0.3, 1)
    if detail:
        detail(canvas, m)
    # fond légèrement plus sombre vers le bas
    t = np.clip((np.arange(h)[:, None] - line[None, :]) / 200.0, 0, 1)[..., None]
    canvas *= 1 - t * 0.15
    return canvas, m


HAZE = [None]


def save_layer(canvas, alpha, path, haze=0.0):
    if haze > 0 and HAZE[0] is not None:
        canvas = canvas * (1 - haze) + HAZE[0][None, None, :] * haze
    to_img(canvas, alpha).save(path, optimize=True)


def trees_on_ridge(canvas, m, line, colors, density, seed, size=(10, 22), h_px=None):
    h, w = m.shape
    rr = np.random.default_rng(seed)
    items = []
    for x in range(0, w, 3):
        if rr.random() < density:
            r = rr.uniform(*size)
            items.append((x, line[x] - r * 0.6, r * rr.uniform(0.6, 0.9), r))
    tm = soft_mask(ellipse_mask(h, w, items) > 0.5, 2, 0.3, 4)
    wash(canvas, tm, hexc(colors[0]), 0.8, 0.7, 0.3, 1)
    return np.maximum(m, tm)


def paint_background(n, out):
    W, H = 1024, 360   # demi-résolution, affiché x2 (2048 x 720)
    meta = {}
    if n == 1:
        HAZE[0] = hexc('#dfe6e6')
        save_layer(sky(360, 640, '#9cc7e3', '#f3ead2', True, 3), None, os.path.join(out, 'sky.png'))
        meta['sky'] = 'sky.png'
        l1 = ridge_periodic(W, 200, 60, 6, 31)
        c1, m1 = layer_from_ridge(H, W, l1, '#9db7d6', 0.5, 1)
        save_layer(c1, m1, os.path.join(out, 'bg0.png'), 0.3)
        l2 = ridge_periodic(W, 260, 35, 5, 32)
        c2, m2 = layer_from_ridge(H, W, l2, '#a9c977', 0.6, 2)
        m2 = trees_on_ridge(c2, m2, l2, ['#6f9c4f'], 0.05, 5)
        save_layer(c2, m2, os.path.join(out, 'bg1.png'), 0.2)
        l3 = ridge_periodic(W, 315, 25, 8, 33)
        c3, m3 = layer_from_ridge(H, W, l3, '#86b25a', 0.7, 3)
        m3 = trees_on_ridge(c3, m3, l3, ['#5f9446'], 0.08, 6, (14, 30))
        save_layer(c3, m3, os.path.join(out, 'bg2.png'), 0.1)
        meta['bg'] = [
            {'file': 'bg0.png', 'motion': 0.08, 'motion_y': 0.0, 'y': 0},
            {'file': 'bg1.png', 'motion': 0.2, 'motion_y': 0.0, 'y': 40},
            {'file': 'bg2.png', 'motion': 0.4, 'motion_y': 0.0, 'y': 120},
        ]
    elif n == 2:
        HAZE[0] = hexc('#d7e8e2')
        save_layer(sky(360, 640, '#8fc0c4', '#e3efe2', True, 4, '#f2f7f2'), None, os.path.join(out, 'sky.png'))
        meta['sky'] = 'sky.png'
        layers = []
        for i, (base, amp, col, dens, sz, mot, y) in enumerate([
            (150, 30, '#a3c9c4', 0.18, (12, 26), 0.1, 0),
            (210, 30, '#6fa79a', 0.16, (16, 34), 0.25, 60),
            (270, 30, '#3f7f72', 0.14, (20, 42), 0.45, 140)]):
            line = ridge_periodic(W, base, amp, 5, 40 + i)
            c, m = layer_from_ridge(H, W, line, col, 0.6, 10 + i)
            m = trees_on_ridge(c, m, line, [col], dens, 50 + i, sz)
            # troncs
            rr = np.random.default_rng(70 + i)
            for k in range(14 + i * 4):
                x = rr.uniform(0, W)
                tw = 3 + i * 2
                tm = poly_mask(H, W, [(x - tw, H), (x + tw, H), (x + tw * 0.6, line[int(x) % W] - 30), (x - tw * 0.6, line[int(x) % W] - 30)])
                wash(c, tm, hexc(col), 0.7, 0.4, 0.2, 0)
                m = np.maximum(m, tm)
            fn = 'bg%d.png' % i
            save_layer(c, m * (0.85 if i < 2 else 0.95), os.path.join(out, fn), [0.5, 0.35, 0.2][i])
            layers.append({'file': fn, 'motion': mot, 'motion_y': 0.0, 'y': y})
        meta['bg'] = layers
    elif n == 3:
        HAZE[0] = hexc('#f6dcc0')
        save_layer(sky(360, 640, '#f0a37a', '#fbe3b5', True, 5, '#fff1d6'), None, os.path.join(out, 'sky.png'))
        meta['sky'] = 'sky.png'
        # mesas lointaines
        line = ridge_periodic(W, 230, 20, 4, 51)
        line = np.where(fbm(1, W, 60, 2, 52)[0] > 0.5, line - 70, line)
        line = blur(line[None, :], 3, 1)[0]
        c, m = layer_from_ridge(H, W, line, '#d99a7a', 0.6, 20)
        save_layer(c, m, os.path.join(out, 'bg0.png'), 0.3)
        # piliers de roche (répétés verticalement)
        PH = 512
        cc = np.ones((PH, W, 3), np.float32)
        mm = np.zeros((PH, W), np.float32)
        rr = np.random.default_rng(55)
        for k in range(7):
            x = k * W / 7 + rr.uniform(-30, 30)
            pw = rr.uniform(40, 80)
            xs = x + (fbm(PH, 1, 30, 3, 60 + k)[:, 0] - 0.5) * 40
            pm = np.zeros((PH, W), np.float32)
            for y in range(PH):
                a, b = int(xs[y] - pw / 2), int(xs[y] + pw / 2)
                pm[y, max(0, a):min(W, b)] = 1
            # rendre la colonne périodique verticalement
            pm = soft_mask(pm, 2, 0.3, 4)
            wash(cc, pm, hexc('#c7764e'), 0.85, 0.7, 0.35, 1)
            strata = fbm(PH, W, 6, 3, 80 + k, aniso=4)
            cc *= (1 - pm[..., None] * 0.15 * strata[..., None])
            mm = np.maximum(mm, pm)
        # raccord vertical : fondu entre haut et bas
        f = 40
        for i in range(f):
            t = i / f
            cc[i] = cc[i] * t + cc[PH - f + i] * (1 - t)
            mm[i] = mm[i] * t + mm[PH - f + i] * (1 - t)
        cc = cc[:PH - f]; mm = mm[:PH - f]
        save_layer(cc, mm * 0.55, os.path.join(out, 'bg1.png'), 0.45)
        meta['bg'] = [
            {'file': 'bg0.png', 'motion': 0.06, 'motion_y': 0.0, 'y': 0},
            {'file': 'bg1.png', 'motion': 0.3, 'motion_y': 0.3, 'y': 0, 'mirror_y': True},
        ]
    elif n == 4:
        # l'atelier : murs de bois chaud, grande fenêtre de nuit, toiles colorées
        h, w = 360, 640
        c = new_canvas(h, w, (0.93, 0.86, 0.72))
        wall = fbm(h, w, 6, 3, 90, aniso=0.15)
        planks = (np.sin(np.arange(w)[None, :] / 22.0 * np.pi) > 0.96).astype(np.float32)
        wash(c, np.ones((h, w), np.float32), hexc('#c8935e'), 0.55, 0.0, 0.3, 0)
        c *= (0.85 + 0.25 * wall[..., None])
        c *= (1 - planks[..., None] * 0.25)
        win = np.zeros((h, w), np.float32); win[30:230, 370:570] = 1
        wash(c, soft_mask(win, 2, 0.2, 4), hexc('#1f2f6e'), 0.95, 0.5, 0.2, 1)
        stars = np.zeros((h, w), np.float32)
        rr = np.random.default_rng(91)
        for k in range(40):
            x, y = int(rr.uniform(375, 565)), int(rr.uniform(35, 225))
            stars[y, x] = 1
        stars = np.clip(blur(stars, 1, 1) * 6, 0, 1)
        c = c * (1 - stars[..., None]) + stars[..., None]
        moon = ellipse_mask(h, w, [(510, 85, 26, 26)])
        c = c * (1 - moon[..., None]) + hexc('#f6efd2') * moon[..., None]
        for x in (370, 470, 570):
            c[30:230, x - 4:x + 4] = hexc('#5a3a26')
        c[127:134, 370:570] = hexc('#5a3a26')
        cols = ['#dc4538', '#2e5cc7', '#ecad2e', '#2a9a73', '#ae3f9e', '#f08a3c']
        for k in range(6):
            x0, y0 = 20 + k * 55 + rr.uniform(-6, 6), rr.uniform(40, 150)
            cw, ch_ = rr.uniform(38, 50), rr.uniform(45, 70)
            fm = np.zeros((h, w), np.float32)
            fm[int(y0) - 4:int(y0 + ch_) + 4, int(x0) - 4:int(x0 + cw) + 4] = 1
            wash(c, fm, hexc('#6a4428'), 0.9, 0.3, 0.2, 0)
            fm2 = np.zeros((h, w), np.float32)
            fm2[int(y0):int(y0 + ch_), int(x0):int(x0 + cw)] = 1
            c[:] = c * (1 - fm2[..., None]) + hexc('#f6f1e4') * fm2[..., None]
            for j in range(4):
                bl = ellipse_mask(h, w, [(x0 + rr.uniform(6, cw - 6), y0 + rr.uniform(8, ch_ - 8), rr.uniform(6, 14), rr.uniform(5, 12))])
                wash(c, bl, hexc(cols[(k + j) % 6]), 0.8, 0.6, 0.3, 1)
        save_layer(c, None, os.path.join(out, 'sky.png'))
        meta['sky'] = 'sky.png'
        meta['bg'] = []
    return meta


# ------------------------------------------------------------------ illustrations plein écran
def landscape(w, h, grey=0.0, seed=1, sunrise=False):
    c = sky(h, w, '#f6c58f' if sunrise else '#9cc7e3', '#fbeccb' if sunrise else '#f3ead2', True, seed)
    if sunrise:
        sun = ellipse_mask(h, w, [(w * 0.5, h * 0.52, 70, 70)])
        c = c * (1 - sun[..., None] * 0.9) + hexc('#ffe7a0') * sun[..., None] * 0.9
    lines = [(0.48, 0.08, '#9db7d6'), (0.6, 0.06, '#a9c977'), (0.72, 0.05, '#7fb04f'), (0.85, 0.04, '#5f9446')]
    for i, (b, a, col) in enumerate(lines):
        line = ridge(w, h * b, h * a, 200, seed + i)
        m = soft_mask(fill_below(h, w, line), 2, 0.3, 4)
        wash(c, m, hexc(col), 0.85, 0.6, 0.3, 1)
        if i >= 2:
            m2 = trees_on_ridge(c, m, line, [col], 0.04, seed + 30 + i, (14, 34))
    # coquelicots
    rr = np.random.default_rng(seed + 99)
    items = [(rr.uniform(w * grey if grey > 0 else 0, w), rr.uniform(h * 0.88, h), rr.uniform(3, 7), rr.uniform(3, 6)) for _ in range(160)]
    fm = ellipse_mask(h, w, items)
    wash(c, fm, hexc('#e2533f'), 0.85, 0.3, 0.2, 0)
    if grey > 0:
        g = c.mean(axis=2, keepdims=True)
        gm = np.clip(((1 - np.linspace(0, 1, w))[None, :] - (1 - grey)) * 3, 0, 1)
        gm = gm + (fbm(h, w, 60, 3, seed + 5) - 0.5) * 0.6
        gm = np.clip(gm, 0, 1)[..., None]
        c = c * (1 - gm) + (g * 0.95 + 0.03) * gm
    return c


def drop_shape(c, cx, cy, r, color):
    h, w = c.shape[:2]
    pts = []
    for i in range(40):
        a = -math.pi / 2 + 0.75 + i / 39 * (2 * math.pi - 1.5)
        pts.append((cx + math.cos(a) * r, cy + r * 0.2 + math.sin(a) * r))
    pts.append((cx, cy - r * 2.1))
    m = soft_mask(poly_mask(h, w, pts) > 0.5, 1, 0.1, 3)
    wash(c, m, hexc(color), 0.95, 0.5, 0.15, 0)
    eyes = ellipse_mask(h, w, [(cx - r * 0.1, cy + r * 0.05, r * 0.16, r * 0.24), (cx + r * 0.35, cy + r * 0.05, r * 0.16, r * 0.24)])
    c[:] = c * (1 - eyes[..., None]) + hexc('#f8f4e8') * eyes[..., None]
    pup = ellipse_mask(h, w, [(cx - r * 0.06, cy + r * 0.08, r * 0.07, r * 0.13), (cx + r * 0.39, cy + r * 0.08, r * 0.07, r * 0.13)])
    c[:] = c * (1 - pup[..., None]) + hexc('#141322') * pup[..., None]


def illustrations():
    w, h = 1280, 720
    t = landscape(w, h, grey=0.45, seed=7)
    # Sépia sur une colline, écharpe rouge
    drop_shape(t, 900, 560, 42, '#2b2a4a')
    im = to_img(t)
    d = ImageDraw.Draw(im, 'RGBA')
    pts = [(888, 548), (850, 556), (816, 548), (780, 560), (750, 552)]
    d.line(pts, fill=(200, 60, 52, 255), width=12, joint='curve')
    # trait d'encre coloré qui traverse le ciel
    rr = np.random.default_rng(3)
    for k, col in enumerate(['#2e5cc7', '#dc4538', '#ecad2e', '#2a9a73', '#ae3f9e']):
        c = tuple(int(v * 255) for v in hexc(col))
        y0 = 470 - k * 8
        line = [(940 + i * 9, y0 - i * 7 + math.sin(i * 0.5) * 6) for i in range(40)]
        d.line(line, fill=c + (190,), width=7, joint='curve')
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(ART, 'titre.png'), optimize=True)
    # intro : l'atelier du peintre endormi (silhouettes)
    c = new_canvas(h, w, (0.93, 0.9, 0.84))
    win = np.zeros((h, w), np.float32); win[120:430, 760:1080] = 1
    wash(c, soft_mask(win, 2, 0.2, 4), hexc('#9cc7e3'), 0.7, 0.5, 0.2, 1)
    easel = poly_mask(h, w, [(380, 640), (400, 640), (470, 230), (455, 230)])
    easel = np.maximum(easel, poly_mask(h, w, [(560, 640), (540, 640), (470, 230), (485, 230)]))
    wash(c, easel, hexc('#8a6446'), 0.85, 0.4, 0.2, 0)
    canv = np.zeros((h, w), np.float32); canv[260:470, 360:600] = 1
    wash(c, soft_mask(canv, 1, 0.1, 3), hexc('#fbf8ef'), 0.9, 0.4, 0.2, 0)
    for k, col in enumerate(['#2e5cc7', '#dc4538', '#ecad2e', '#2a9a73']):
        bl = ellipse_mask(h, w, [(420 + k * 45, 360 + (k % 2) * 30, 30, 22)])
        wash(c, bl, hexc(col), 0.6, 0.6, 0.3, 1)
    chair = ellipse_mask(h, w, [(900, 560, 140, 80), (870, 470, 70, 60)])
    wash(c, chair, hexc('#7d7a8a'), 0.6, 0.6, 0.3, 2)
    to_img(c).save(os.path.join(ART, 'intro.png'), optimize=True)
    # fins
    to_img(landscape(w, h, 0.0, seed=8)).save(os.path.join(ART, 'fin.png'), optimize=True)
    f = landscape(w, h, 0.0, seed=9, sunrise=True)
    drop_shape(f, 640, 600, 30, '#2b2a4a')
    to_img(f).save(os.path.join(ART, 'fin_vraie.png'), optimize=True)
    print('illustrations peintes')


if __name__ == '__main__':
    os.makedirs(ART, exist_ok=True)
    which = sys.argv[2:] if len(sys.argv) > 2 else ['paper', '1', '2', '3', '4', 'illus']
    for wch in which:
        if wch == 'paper':
            paper()
        elif wch == 'illus':
            illustrations()
        else:
            paint_level(int(wch))
