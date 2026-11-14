# Bakes the tileable cloud noise used by Dynamic Sky (512x512 RGB PNG).
#   R = perlin-worley base shape        (sampled at 1 cell / unit)
#   G = worley fbm erosion              (same coordinates as R)
#   B = fine detail fbm                 (sampled at ~7x frequency)

import os
import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(1337)
ys, xs = np.mgrid[0:N, 0:N].astype(np.float64) / N

def worley(cells):
    pts = rng.random((cells, cells, 2))
    x = xs * cells; y = ys * cells
    ci = np.floor(x).astype(int); cj = np.floor(y).astype(int)
    best = np.full((N, N), 9.0)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            ii = (ci + di) % cells; jj = (cj + dj) % cells
            px = ci + di + pts[jj, ii, 0]; py = cj + dj + pts[jj, ii, 1]
            best = np.minimum(best, np.hypot(x - px, y - py))
    return np.clip(best, 0, 1)

def vnoise(cells):
    lat = rng.random((cells, cells))
    x = xs * cells; y = ys * cells
    i = np.floor(x).astype(int); j = np.floor(y).astype(int)
    fx = x - i; fy = y - j
    fx = fx**3 * (fx * (fx * 6 - 15) + 10); fy = fy**3 * (fy * (fy * 6 - 15) + 10)
    i0, i1 = i % cells, (i + 1) % cells; j0, j1 = j % cells, (j + 1) % cells
    a = lat[j0, i0]; b = lat[j0, i1]; c = lat[j1, i0]; d = lat[j1, i1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

puffs = 1.0 - worley(16)
perlin = 0.65 * vnoise(10) + 0.35 * vnoise(21)
R = puffs + (1.0 - puffs) * perlin                       # mix(puffs, 1, perlin)
G = 0.625 * (1.0 - worley(32)) + 0.375 * vnoise(64)
B = 0.65 * vnoise(16) + 0.35 * vnoise(37)

img = np.stack([R, G, B], -1)
img += (rng.random(img.shape) - 0.5) / 255.0               # dither against banding
img = np.clip(img, 0, 1)
Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'files', 'textures', 'cloud_noise.png'), optimize=True)
for n, c in zip('RGB', (R, G, B)):
    print(n, 'mean %.3f  min %.3f  max %.3f' % (c.mean(), c.min(), c.max()))
