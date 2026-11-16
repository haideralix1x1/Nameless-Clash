"""Procedural 2D art and audio asset synthesizer for Nameless Clash.

Generates:
- 60 modular 8-frame character PNG strips in assets/sprites/modular/
  (skin_0..9, legs_0..9, torso_0..9, head_0..9, hands_0..9, accessories_0..9)
- 11x3 real-world weapon sprite sheet (assets/sprites/weapons_sheet.png)
- Projectiles, FX, 3 map backgrounds, multi-biome tileset
- Authentic synthesized SFX per firearm + looping BGM WAV
"""
import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _quantize_to_indexed_png(width: int, height: int, pixels: bytearray, max_colors: int = 96) -> bytes:
    """Convert RGBA bytearray into a compact color-type-3 indexed PNG with PLTE + tRNS."""
    stride = width * 4
    # Index 0 reserved for fully transparent (0,0,0,0)
    buckets: dict[tuple[int, int, int, int], list[int]] = {}
    q_pixels = [0] * (width * height)

    # First pass: bucket opaque/translucent colors at 4-bit-ish precision (step 8)
    coords: list[tuple[int, int, int, int, int]] = []
    for p_i in range(width * height):
        i = p_i * 4
        r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        if a < 16:
            continue
        # Quantize alpha cleanly for anti-aliased edge compactness
        qa = 255 if a >= 235 else (max(32, (a // 48) * 48))
        key = (r >> 3, g >> 3, b >> 3, qa >> 4)
        coords.append((p_i, r, g, b, qa))
        entry = buckets.get(key)
        if entry is None:
            buckets[key] = [1, r, g, b, qa]
        else:
            entry[0] += 1
            entry[1] += r
            entry[2] += g
            entry[3] += b
            entry[4] += qa

    # Sort buckets by frequency and keep up to max_colors - 1 representative colors
    sorted_keys = sorted(buckets.keys(), key=lambda k: buckets[k][0], reverse=True)
    palette: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)]
    key_to_idx: dict[tuple[int, int, int, int], int] = {}
    for k in sorted_keys[: max_colors - 1]:
        cnt, sr, sg, sb, sa = buckets[k]
        idx = len(palette)
        palette.append((sr // cnt, sg // cnt, sb // cnt, sa // cnt))
        key_to_idx[k] = idx

    # Map remaining rare keys to nearest palette color
    for k in sorted_keys[max_colors - 1 :]:
        cnt, sr, sg, sb, sa = buckets[k]
        cr, cg, cb, ca = sr // cnt, sg // cnt, sb // cnt, sa // cnt
        best_idx = 1
        best_d = 10**12
        for idx in range(1, len(palette)):
            pr, pg, pb, pa = palette[idx]
            d = (cr - pr) ** 2 + (cg - pg) ** 2 + (cb - pb) ** 2 + ((ca - pa) ** 2) * 2
            if d < best_d:
                best_d = d
                best_idx = idx
        key_to_idx[k] = best_idx

    for p_i, r, g, b, qa in coords:
        key = (r >> 3, g >> 3, b >> 3, qa >> 4)
        q_pixels[p_i] = key_to_idx[key]

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    plte = bytearray()
    trns = bytearray()
    for r, g, b, a in palette:
        plte.extend((r, g, b))
        trns.append(a)

    if len(palette) <= 16:
        bit_depth = 4
        raw_rows0 = bytearray()
        for y in range(height):
            raw_rows0.append(0)
            row_start = y * width
            for x in range(0, width, 2):
                p0 = q_pixels[row_start + x] & 0x0F
                p1 = q_pixels[row_start + x + 1] & 0x0F if (x + 1) < width else 0
                raw_rows0.append((p0 << 4) | p1)
        idat = zlib.compress(bytes(raw_rows0), 9)
    else:
        bit_depth = 8
        raw_rows0 = bytearray()
        raw_rows1 = bytearray()
        for y in range(height):
            raw_rows0.append(0)
            raw_rows1.append(1)
            row_start = y * width
            prev = 0
            for x in range(width):
                cur = q_pixels[row_start + x]
                raw_rows0.append(cur)
                raw_rows1.append((cur - prev) & 0xFF)
                prev = cur
        c0 = zlib.compress(bytes(raw_rows0), 9)
        c1 = zlib.compress(bytes(raw_rows1), 9)
        idat = c0 if len(c0) <= len(c1) else c1

    ihdr = struct.pack(">IIBBBBB", width, height, bit_depth, 3, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"PLTE", bytes(plte))
        + chunk(b"tRNS", bytes(trns))
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )


def write_png(path: str, width: int, height: int, pixels: bytearray, max_bytes: int = 0) -> None:
    ensure_dir(os.path.dirname(path))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    if max_bytes > 0:
        for cols in (64, 48, 36, 28, 22, 16, 12):
            png_bytes = _quantize_to_indexed_png(width, height, pixels, cols)
            if len(png_bytes) <= max_bytes or cols == 12:
                with open(path, "wb") as f:
                    f.write(png_bytes)
                return

    raw_rows = bytearray()
    stride = width * 4
    for y in range(height):
        raw_rows.append(0)
        raw_rows.extend(pixels[y * stride : (y + 1) * stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw_rows), 9)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png_bytes)


class Canvas:
    """Layer-Lab inspired crisp 2.5D cel-shaded anti-aliased RGBA vector rasterizer."""

    def __init__(self, width: int, height: int, bg=(0, 0, 0, 0), coord_scale: float = 1.0):
        self.w = width
        self.h = height
        self.sc = float(coord_scale)
        self.buf = bytearray(width * height * 4)
        if bg != (0, 0, 0, 0):
            r, g, b, a = bg
            row = bytes([r, g, b, a]) * width
            for y in range(height):
                self.buf[y * width * 4 : (y + 1) * width * 4] = row

    def blend_pixel(self, x: int, y: int, color: tuple[int, int, int, int], alpha_scale: float = 1.0) -> None:
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        sr, sg, sb, sa = color
        sa_f = (sa / 255.0) * alpha_scale
        if sa_f <= 0.0:
            return
        idx = (y * self.w + x) * 4
        dr = self.buf[idx]
        dg = self.buf[idx + 1]
        db = self.buf[idx + 2]
        da = self.buf[idx + 3] / 255.0

        out_a = sa_f + da * (1.0 - sa_f)
        if out_a <= 1e-6:
            return
        out_r = (sr * sa_f + dr * da * (1.0 - sa_f)) / out_a
        out_g = (sg * sa_f + dg * da * (1.0 - sa_f)) / out_a
        out_b = (sb * sa_f + db * da * (1.0 - sa_f)) / out_a

        self.buf[idx] = max(0, min(255, int(out_r + 0.5)))
        self.buf[idx + 1] = max(0, min(255, int(out_g + 0.5)))
        self.buf[idx + 2] = max(0, min(255, int(out_b + 0.5)))
        self.buf[idx + 3] = max(0, min(255, int(out_a * 255.0 + 0.5)))

    @staticmethod
    def _shade_color(
        fill: tuple[int, int, int, int],
        nx: float,
        ny: float,
        nz: float,
        shade: str,
        sdist: float = -4.0,
    ) -> tuple[int, int, int, int]:
        if shade == "flat":
            return fill
        r, g, b, a = fill
        # Key light from upper-left-front
        ndotl = nx * -0.45 + ny * -0.64 + nz * 0.62

        # Smooth 1px anti-aliased cel-shadow transition (no blurry edge AO halo)
        def _step(edge: float, val: float, w: float = 0.06) -> float:
            t = max(0.0, min(1.0, (val - (edge - w)) / (2.0 * w)))
            return t * t * (3.0 - 2.0 * t)

        if shade == "metal":
            in_lit = _step(0.02, ndotl, 0.08)
            diag = nx * 0.70 + ny * 0.68
            bar1 = _step(0.24, diag, 0.05) * (1.0 - _step(0.46, diag, 0.05))
            bar2 = _step(-0.44, diag, 0.04) * (1.0 - _step(-0.30, diag, 0.04))
            hi = max(bar1 * 0.85, bar2 * 0.45, _step(0.76, ndotl, 0.05) * 0.65)
            sh_r, sh_g, sh_b = r * 0.68, g * 0.69, b * 0.76
            cr = sh_r + (r * 1.04 - sh_r) * in_lit + hi * 88.0
            cg = sh_g + (g * 1.04 - sh_g) * in_lit + hi * 92.0
            cb = sh_b + (b * 1.04 - sh_b) * in_lit + hi * 98.0
        elif shade == "crystal":
            facet = 0.80 if (nx * 0.75 - ny * 0.45) > 0.22 else (1.16 if (nx * -0.6 - ny * 0.7) > 0.32 else 1.0)
            glint = _step(0.72, ndotl, 0.04) * 55.0
            cr = r * facet + glint
            cg = g * facet + glint
            cb = b * facet + glint
        elif shade == "flame":
            core = max(0.0, min(1.0, (ny + 0.55) * 0.65 - abs(nx) * 0.25))
            cr = r * (0.86 + 0.18 * core) + core * 36.0
            cg = g * (0.76 + 0.30 * core) + core * 48.0
            cb = b * (0.80 + 0.20 * core) + core * 18.0
        elif shade == "wood":
            in_lit = _step(0.06, ndotl, 0.07)
            hi = _step(0.70, ndotl, 0.05) * 0.55
            sh_r, sh_g, sh_b = r * 0.78, g * 0.64, b * 0.54
            cr = sh_r + (r * 1.05 - sh_r) * in_lit + hi * 52.0
            cg = sh_g + (g * 1.03 - sh_g) * in_lit + hi * 38.0
            cb = sh_b + (b * 1.00 - sh_b) * in_lit + hi * 20.0
        elif shade == "lava":
            in_lit = _step(0.05, ndotl, 0.08)
            warm = _step(0.28, ny, 0.10) * 0.45
            cr = r * (0.70 + 0.34 * in_lit) + warm * 190.0
            cg = g * (0.64 + 0.36 * in_lit) + warm * 75.0
            cb = b * (0.68 + 0.32 * in_lit) + warm * 15.0
        elif shade == "glossy":
            in_lit = _step(0.06, ndotl, 0.07)
            hi = _step(0.69, ndotl, 0.05) * 0.68
            sh_r, sh_g, sh_b = r * 0.75, g * 0.71, b * 0.80
            cr = sh_r + (r * 1.04 - sh_r) * in_lit + hi * 64.0
            cg = sh_g + (g * 1.04 - sh_g) * in_lit + hi * 64.0
            cb = sh_b + (b * 1.03 - sh_b) * in_lit + hi * 64.0
        else:  # "soft" Layer Lab vector character shading
            in_lit = _step(0.04, ndotl, 0.08)
            hi = _step(0.73, ndotl, 0.05) * 0.45
            sh_r, sh_g, sh_b = r * 0.80, g * 0.74, b * 0.81
            cr = sh_r + (r * 1.03 - sh_r) * in_lit + hi * 42.0
            cg = sh_g + (g * 1.03 - sh_g) * in_lit + hi * 38.0
            cb = sh_b + (b * 1.02 - sh_b) * in_lit + hi * 38.0

        return (
            max(0, min(255, int(cr))),
            max(0, min(255, int(cg))),
            max(0, min(255, int(cb))),
            a,
        )

    def _apply_sdf(self, px: int, py: int, sdist: float, fill: tuple[int, int, int, int],
                   outline: tuple[int, int, int, int] | None, outline_w: float,
                   shade_col: tuple[int, int, int, int] | None = None) -> None:
        col = shade_col if shade_col is not None else fill
        if outline:
            if sdist <= outline_w + 0.5:
                cov_out = max(0.0, min(1.0, outline_w + 0.5 - sdist))
                if sdist > -0.5:
                    self.blend_pixel(px, py, outline, cov_out)
                if sdist <= 0.5:
                    cov_in = max(0.0, min(1.0, 0.5 - sdist))
                    self.blend_pixel(px, py, col, cov_in)
        else:
            if sdist <= 0.5:
                cov = max(0.0, min(1.0, 0.5 - sdist))
                self.blend_pixel(px, py, col, cov)

    def fill_circle(self, cx: float, cy: float, r: float, fill: tuple[int, int, int, int],
                    outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4,
                    shade: str = "soft") -> None:
        if self.sc != 1.0:
            cx *= self.sc; cy *= self.sc; r *= self.sc; outline_w *= self.sc * 0.92
        total_r = r + (outline_w if outline else 0.0)
        x0 = max(0, int(math.floor(cx - total_r - 2)))
        x1 = min(self.w - 1, int(math.ceil(cx + total_r + 2)))
        y0 = max(0, int(math.floor(cy - total_r - 2)))
        y1 = min(self.h - 1, int(math.ceil(cy + total_r + 2)))
        inv_r = 1.0 / max(1.0, r)
        for py in range(y0, y1 + 1):
            dy = py + 0.5 - cy
            for px in range(x0, x1 + 1):
                dx = px + 0.5 - cx
                d = math.hypot(dx, dy)
                sdist = d - r
                scol = None
                if shade != "flat" and sdist <= 0.6:
                    nx = max(-1.0, min(1.0, dx * inv_r))
                    ny = max(-1.0, min(1.0, dy * inv_r))
                    nz = math.sqrt(max(0.0, 1.0 - min(1.0, nx * nx + ny * ny)))
                    scol = self._shade_color(fill, nx, ny, nz, shade, sdist)
                self._apply_sdf(px, py, sdist, fill, outline, outline_w, scol)

    def fill_ellipse(self, cx: float, cy: float, rx: float, ry: float, fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4,
                     shade: str = "soft") -> None:
        if self.sc != 1.0:
            cx *= self.sc; cy *= self.sc; rx *= self.sc; ry *= self.sc; outline_w *= self.sc * 0.92
        rx = max(0.5, rx)
        ry = max(0.5, ry)
        pad = (outline_w if outline else 0.0) + 2.5
        x0 = max(0, int(math.floor(cx - rx - pad)))
        x1 = min(self.w - 1, int(math.ceil(cx + rx + pad)))
        y0 = max(0, int(math.floor(cy - ry - pad)))
        y1 = min(self.h - 1, int(math.ceil(cy + ry + pad)))
        min_r = min(rx, ry)
        for py in range(y0, y1 + 1):
            pyf = py + 0.5 - cy
            ny = pyf / ry
            for px in range(x0, x1 + 1):
                pxf = px + 0.5 - cx
                nx = pxf / rx
                k0 = math.hypot(nx, ny)
                if k0 < 1e-6:
                    sdist = -min_r
                else:
                    k1 = math.hypot(nx / rx, ny / ry)
                    sdist = k0 * (k0 - 1.0) / k1
                scol = None
                if shade != "flat" and sdist <= 0.6:
                    sx = max(-1.0, min(1.0, nx))
                    sy = max(-1.0, min(1.0, ny))
                    sz = math.sqrt(max(0.0, 1.0 - min(1.0, sx * sx + sy * sy)))
                    scol = self._shade_color(fill, sx, sy, sz, shade, sdist)
                self._apply_sdf(px, py, sdist, fill, outline, outline_w, scol)

    def fill_round_rect(self, x: float, y: float, w: float, h: float, radius: float,
                        fill: tuple[int, int, int, int],
                        outline: tuple[int, int, int, int] | None = None,
                        outline_w: float = 2.4, shade: str = "soft") -> None:
        if self.sc != 1.0:
            x *= self.sc; y *= self.sc; w *= self.sc; h *= self.sc; radius *= self.sc; outline_w *= self.sc * 0.92
        rad = min(radius, w * 0.5, h * 0.5)
        pad = (outline_w if outline else 0.0) + 2.0
        x0 = max(0, int(math.floor(x - pad)))
        x1 = min(self.w - 1, int(math.ceil(x + w + pad)))
        y0 = max(0, int(math.floor(y - pad)))
        y1 = min(self.h - 1, int(math.ceil(y + h + pad)))
        cx_min = x + rad
        cx_max = x + w - rad
        cy_min = y + rad
        cy_max = y + h - rad
        mx = x + w * 0.5
        my = y + h * 0.5
        inv_hw = 1.0 / max(1.0, w * 0.5)
        inv_hh = 1.0 / max(1.0, h * 0.5)
        for py in range(y0, y1 + 1):
            pyf = py + 0.5
            dy = 0.0
            if pyf < cy_min:
                dy = cy_min - pyf
            elif pyf > cy_max:
                dy = pyf - cy_max
            sy = max(-1.0, min(1.0, (pyf - my) * inv_hh))
            for px in range(x0, x1 + 1):
                pxf = px + 0.5
                dx = 0.0
                if pxf < cx_min:
                    dx = cx_min - pxf
                elif pxf > cx_max:
                    dx = pxf - cx_max
                sdist = math.hypot(dx, dy) - rad
                scol = None
                if shade != "flat" and sdist <= 0.6:
                    sx = max(-1.0, min(1.0, (pxf - mx) * inv_hw))
                    sz = math.sqrt(max(0.0, 1.0 - min(1.0, (sx * sx + sy * sy) * 0.65)))
                    scol = self._shade_color(fill, sx, sy, sz, shade, sdist)
                self._apply_sdf(px, py, sdist, fill, outline, outline_w, scol)

    def fill_capsule(self, x1: float, y1: float, x2: float, y2: float, r: float,
                     fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None,
                     outline_w: float = 2.4, shade: str = "soft") -> None:
        if self.sc != 1.0:
            x1 *= self.sc; y1 *= self.sc; x2 *= self.sc; y2 *= self.sc; r *= self.sc; outline_w *= self.sc * 0.92
        pad = r + (outline_w if outline else 0.0) + 2.0
        minx = max(0, int(math.floor(min(x1, x2) - pad)))
        maxx = min(self.w - 1, int(math.ceil(max(x1, x2) + pad)))
        miny = max(0, int(math.floor(min(y1, y2) - pad)))
        maxy = min(self.h - 1, int(math.ceil(max(y1, y2) + pad)))
        vx, vy = x2 - x1, y2 - y1
        seg_len2 = vx * vx + vy * vy
        inv_r = 1.0 / max(1.0, r)
        for py in range(miny, maxy + 1):
            for px in range(minx, maxx + 1):
                pxf, pyf = px + 0.5, py + 0.5
                if seg_len2 <= 1e-6:
                    cx, cy = x1, y1
                else:
                    t = max(0.0, min(1.0, ((pxf - x1) * vx + (pyf - y1) * vy) / seg_len2))
                    cx, cy = x1 + t * vx, y1 + t * vy
                dx, dy = pxf - cx, pyf - cy
                d = math.hypot(dx, dy)
                sdist = d - r
                scol = None
                if shade != "flat" and sdist <= 0.6:
                    sx = max(-1.0, min(1.0, dx * inv_r))
                    sy = max(-1.0, min(1.0, dy * inv_r))
                    sz = math.sqrt(max(0.0, 1.0 - min(1.0, sx * sx + sy * sy)))
                    scol = self._shade_color(fill, sx, sy, sz, shade, sdist)
                self._apply_sdf(px, py, sdist, fill, outline, outline_w, scol)

    def fill_polygon(self, points: list[tuple[float, float]], fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4,
                     shade: str = "soft") -> None:
        n = len(points)
        if n < 3:
            return
        if self.sc != 1.0:
            points = [(px * self.sc, py * self.sc) for (px, py) in points]
            outline_w *= self.sc * 0.92
        pad = (outline_w if outline else 0.0) + 2.0
        minx_p = min(p[0] for p in points)
        maxx_p = max(p[0] for p in points)
        miny_p = min(p[1] for p in points)
        maxy_p = max(p[1] for p in points)
        minx = max(0, int(math.floor(minx_p - pad)))
        maxx = min(self.w - 1, int(math.ceil(maxx_p + pad)))
        miny = max(0, int(math.floor(miny_p - pad)))
        maxy = min(self.h - 1, int(math.ceil(maxy_p + pad)))
        mx = (minx_p + maxx_p) * 0.5
        my = (miny_p + maxy_p) * 0.5
        inv_hw = 1.0 / max(2.0, (maxx_p - minx_p) * 0.5)
        inv_hh = 1.0 / max(2.0, (maxy_p - miny_p) * 0.5)

        edges = []
        for i in range(n):
            ax, ay = points[i]
            bx, by = points[(i + 1) % n]
            ex, ey = bx - ax, by - ay
            l2 = ex * ex + ey * ey
            edges.append((ax, ay, bx, by, ex, ey, l2))

        for py in range(miny, maxy + 1):
            pyf = py + 0.5
            sy = max(-1.0, min(1.0, (pyf - my) * inv_hh))
            for px in range(minx, maxx + 1):
                pxf = px + 0.5
                inside = False
                min_d2 = 1e12
                for ax, ay, bx, by, ex, ey, l2 in edges:
                    if ((ay > pyf) != (by > pyf)) and (pxf < (bx - ax) * (pyf - ay) / (by - ay + 1e-12) + ax):
                        inside = not inside
                    if l2 <= 1e-9:
                        dx, dy = pxf - ax, pyf - ay
                    else:
                        t = max(0.0, min(1.0, ((pxf - ax) * ex + (pyf - ay) * ey) / l2))
                        dx, dy = pxf - (ax + t * ex), pyf - (ay + t * ey)
                    d2 = dx * dx + dy * dy
                    if d2 < min_d2:
                        min_d2 = d2
                sdist = -math.sqrt(min_d2) if inside else math.sqrt(min_d2)
                scol = None
                if shade != "flat" and sdist <= 0.6:
                    sx = max(-1.0, min(1.0, (pxf - mx) * inv_hw))
                    sz = math.sqrt(max(0.0, 1.0 - min(1.0, (sx * sx + sy * sy) * 0.55)))
                    scol = self._shade_color(fill, sx, sy, sz, shade, sdist)
                self._apply_sdf(px, py, sdist, fill, outline, outline_w, scol)

    def fill_triangle(self, p1: tuple[float, float], p2: tuple[float, float], p3: tuple[float, float],
                      fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None,
                      outline_w: float = 2.0, shade: str = "soft") -> None:
        self.fill_polygon([p1, p2, p3], fill, outline, outline_w, shade=shade)

    def fill_star(self, cx: float, cy: float, r_outer: float, r_inner: float,
                  fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None,
                  outline_w: float = 1.4, shade: str = "flat", points_n: int = 5, rot: float = -math.pi * 0.5) -> None:
        pts: list[tuple[float, float]] = []
        for i in range(points_n * 2):
            ang = rot + i * math.pi / points_n
            r = r_outer if i % 2 == 0 else r_inner
            pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
        self.fill_polygon(pts, fill, outline, outline_w, shade=shade)

    def blit(self, src: "Canvas", dst_x: int, dst_y: int) -> None:
        for sy in range(src.h):
            dy = dst_y + sy
            if dy < 0 or dy >= self.h:
                continue
            for sx in range(src.w):
                dx = dst_x + sx
                if dx < 0 or dx >= self.w:
                    continue
                sidx = (sy * src.w + sx) * 4
                sa = src.buf[sidx + 3]
                if sa > 0:
                    self.blend_pixel(
                        dx,
                        dy,
                        (src.buf[sidx], src.buf[sidx + 1], src.buf[sidx + 2], sa),
                    )

    def save(self, rel_path: str, max_bytes: int = 0) -> None:
        write_png(os.path.join(ROOT, rel_path), self.w, self.h, self.buf, max_bytes=max_bytes)


INK = (20, 16, 22, 255)
SPRITE_SIZE = 128
LAYER_SCALE = SPRITE_SIZE / 96.0


def _pose_metrics(frame_idx: int) -> dict:
    if frame_idx == 7:
        return {
            "dead": True, "firing": False, "hx": 70.0, "hy": 68.0, "ty": 62.0,
            "py": 72.0, "llx": 20.0, "lly": 78.0, "lrx": 28.0, "lry": 73.0, "jet": False,
        }
    bob_y = 0.0
    head_x = 48.0
    head_y = 32.0
    torso_y = 50.0
    hip_y = 69.0
    llx, lly = 42.0, 86.0
    lrx, lry = 55.0, 86.0
    jet = False
    firing = False

    if frame_idx == 1:
        bob_y = 1.6
    elif frame_idx == 2:
        bob_y = -1.6
        head_x = 49.5
        llx, lly = 33.0, 83.0
        lrx, lry = 61.0, 85.0
    elif frame_idx == 3:
        bob_y = 1.0
        head_x = 49.0
        llx, lly = 44.0, 86.0
        lrx, lry = 52.0, 80.0
    elif frame_idx == 4:
        bob_y = -1.6
        head_x = 49.5
        llx, lly = 60.0, 85.0
        lrx, lry = 34.0, 83.0
    elif frame_idx == 5:
        bob_y = -4.0
        llx, lly = 37.0, 82.0
        lrx, lry = 50.0, 85.0
        jet = True
    elif frame_idx == 6:
        bob_y = 3.0
        llx, lly = 36.0, 86.0
        lrx, lry = 59.0, 86.0
        firing = True

    return {
        "dead": False,
        "firing": firing,
        "hx": head_x,
        "hy": head_y + bob_y,
        "ty": torso_y + bob_y,
        "py": hip_y + bob_y,
        "llx": llx, "lly": lly,
        "lrx": lrx, "lry": lry,
        "jet": jet,
    }


def _draw_archetype_skin(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    skin_hi = (248, 198, 168, 255)
    skin_mid = (242, 180, 150, 255)
    skin_sh = (224, 148, 120, 255)
    ear_inner = (205, 118, 96, 255)
    hair_dark = (40, 32, 30, 255)
    hair_brown = (116, 72, 46, 255)
    beard_gray = (138, 134, 130, 255)
    beard_sh = (106, 102, 98, 255)

    # Custom Layer Lab palettes per archetype
    if arch == 4:
        # Blue Star Tank
        skin_hi, skin_mid, skin_sh = (72, 206, 255, 255), (26, 174, 246, 255), (14, 128, 204, 255)
    elif arch == 10:
        # Barrel Pirate (warm oak-backed lower rim)
        skin_hi, skin_mid, skin_sh = (232, 174, 136, 255), (212, 146, 108, 255), (172, 112, 80, 255)
    elif arch == 12:
        skin_hi, skin_mid, skin_sh = (132, 186, 86, 255), (112, 162, 72, 255), (84, 124, 54, 255)
        ear_inner = (72, 108, 46, 255)
    elif arch == 13:
        skin_hi, skin_mid, skin_sh = (242, 240, 232, 255), (222, 218, 206, 255), (185, 180, 168, 255)
    elif arch == 14:
        # Blue/Purple Flame Mage
        skin_hi, skin_mid, skin_sh = (106, 86, 218, 255), (68, 52, 168, 255), (46, 32, 126, 255)
    elif arch == 15:
        skin_hi, skin_mid, skin_sh = (226, 216, 182, 255), (206, 194, 160, 255), (166, 154, 122, 255)
    elif arch == 16:
        # White Cube Mech Robot
        skin_hi, skin_mid, skin_sh = (246, 248, 255, 255), (226, 230, 248, 255), (186, 192, 222, 255)
    elif arch == 17:
        skin_hi, skin_mid, skin_sh = (72, 146, 116, 255), (56, 124, 96, 255), (38, 92, 72, 255)
    elif arch == 18:
        skin_hi, skin_mid, skin_sh = (46, 48, 54, 255), (38, 40, 46, 255), (26, 28, 34, 255)
    elif arch == 20:
        skin_hi, skin_mid, skin_sh = (158, 98, 146, 255), (138, 82, 126, 255), (104, 58, 96, 255)
        ear_inner = (90, 46, 82, 255)
    elif arch == 21:
        # Red Flame Mage (Ignis)
        skin_hi, skin_mid, skin_sh = (255, 68, 52, 255), (242, 32, 36, 255), (186, 20, 28, 255)
    elif arch == 22:
        skin_hi, skin_mid, skin_sh = (246, 166, 218, 255), (228, 132, 198, 255), (192, 92, 162, 255)
    elif arch == 23:
        skin_hi, skin_mid, skin_sh = (224, 168, 118, 255), (204, 148, 100, 255), (170, 118, 76, 255)

    def _glossy_eye(cx: float, cy: float, rx: float = 3.2, ry: float = 5.4, iris: tuple[int, int, int, int] | None = None) -> None:
        c.fill_ellipse(cx, cy, rx, ry, INK, shade="flat")
        if iris is not None:
            c.fill_ellipse(cx + 0.2, cy + 0.5, max(1.4, rx - 0.9), max(2.2, ry - 1.2), iris, shade="glossy")
            c.fill_circle(cx + 0.3, cy, max(1.0, min(rx, ry) * 0.42), INK, shade="flat")
        c.fill_circle(cx - rx * 0.28, cy - ry * 0.36, 1.35, (255, 255, 255, 255), shade="flat")
        c.fill_circle(cx + rx * 0.24, cy + ry * 0.32, 0.72, (255, 255, 255, 210), shade="flat")

    if p["dead"]:
        c.fill_round_rect(54, 52, 34, 30, 11, skin_mid, INK, 2.5)
        c.fill_ellipse(69, 64, 2.4, 2.4, INK, shade="flat")
        c.fill_ellipse(77, 64, 2.4, 2.4, INK, shade="flat")
        return c

    hx, hy, ty = p["hx"], p["hy"], p["ty"]

    # Special integrated Layer Lab silhouette silhouettes for Flagship 5 Showcase Characters
    if arch == 4:
        # Blue Star Tank: continuous wide rounded electric-blue dome body/head
        c.fill_round_rect(hx - 23.0, hy - 18.0, 46.0, 38.0, 17.5, skin_mid, INK, 2.7, shade="glossy")
        # X-scar on cheek
        c.fill_capsule(hx - 5.5, hy + 8.5, hx + 1.5, hy + 15.5, 1.15, skin_sh, shade="flat")
        c.fill_capsule(hx + 1.5, hy + 8.5, hx - 5.5, hy + 15.5, 1.15, skin_sh, shade="flat")
        # Crisp rounded-square dark eye + gleam
        c.fill_round_rect(hx + 2.5, hy - 2.0, 7.5, 9.0, 2.2, INK, shade="flat")
        c.fill_circle(hx + 4.4, hy + 0.2, 1.2, (195, 240, 255, 255), shade="flat")
        return c

    if arch == 10:
        # Barrel Pirate: face merges inside upper barrel stave (drawn mostly in torso, eye + brows on skin)
        c.fill_round_rect(hx - 18.0, hy - 14.0, 38.0, 26.0, 9.0, (242, 146, 34, 255), INK, 2.4, shade="wood")
        # Eye socket + blazing glowing red pirate eye
        c.fill_ellipse(hx + 3.0, hy - 1.0, 6.2, 5.2, (28, 22, 24, 255), INK, 1.8, shade="flat")
        c.fill_circle(hx + 3.5, hy - 1.0, 3.2, (244, 46, 46, 255), shade="glossy")
        c.fill_circle(hx + 3.8, hy - 1.2, 1.2, (255, 198, 198, 255), shade="flat")
        return c

    if arch in (14, 21):
        # Flame Mages: billowing flame head silhouette + glowing inner energy face mask + rectangular eyes
        outer_col = (74, 54, 174, 255) if arch == 14 else (244, 34, 38, 255)
        inner_col = (34, 178, 255, 255) if arch == 14 else (255, 128, 34, 255)
        core_col = (104, 248, 255, 255) if arch == 14 else (255, 224, 68, 255)
        c.fill_ellipse(hx + 1.0, hy - 2.0, 21.5, 19.0, outer_col, INK, 2.7, shade="flame")
        # Inner T-shaped luminous flame glow face
        c.fill_ellipse(hx + 6.5, hy - 0.5, 14.0, 13.5, inner_col, shade="flat")
        c.fill_round_rect(hx - 2.5, hy - 7.5, 19.5, 11.5, 4.5, core_col, shade="flat")
        c.fill_round_rect(hx + 4.5, hy + 1.0, 8.5, 12.0, 3.5, core_col, shade="flat")
        # Glowing slanted rectangular white eyes
        c.fill_polygon(
            [(hx + 0.0, hy - 3.5), (hx + 7.5, hy - 2.2), (hx + 7.0, hy + 2.8), (hx - 0.5, hy + 1.5)],
            (255, 255, 255, 255), shade="flat"
        )
        c.fill_polygon(
            [(hx + 10.5, hy - 2.0), (hx + 17.5, hy - 3.2), (hx + 17.0, hy + 1.8), (hx + 10.0, hy + 3.0)],
            (255, 255, 255, 255), shade="flat"
        )
        return c

    if arch == 16:
        # White Cube Mech Robot: 3D beveled off-white cube head with lavender bevel planes & orange collar
        c.fill_polygon(
            [(hx - 21.0, hy - 14.0), (hx + 18.0, hy - 16.0), (hx + 22.0, hy - 7.0),
             (hx + 21.0, hy + 17.0), (hx - 15.0, hy + 19.0), (hx - 23.0, hy + 11.0)],
            skin_mid, INK, 2.7, shade="flat"
        )
        # Left angled lavender cel-shadow plane
        c.fill_polygon(
            [(hx - 21.0, hy - 14.0), (hx - 11.5, hy - 10.5), (hx - 12.0, hy + 18.5), (hx - 23.0, hy + 11.0)],
            skin_sh, shade="flat"
        )
        # Bright crisp top bevel edge
        c.fill_polygon(
            [(hx - 20.0, hy - 13.5), (hx + 17.5, hy - 15.5), (hx + 20.5, hy - 9.5), (hx - 11.5, hy - 10.5)],
            skin_hi, shade="flat"
        )
        # Burnt-orange circular collar bezel + dark optical core
        c.fill_circle(hx + 11.5, hy + 2.0, 9.5, (238, 128, 38, 255), INK, 2.2, shade="metal")
        c.fill_circle(hx + 11.5, hy + 2.0, 5.8, (26, 30, 54, 255), INK, 1.6, shade="glossy")
        c.fill_circle(hx + 10.0, hy + 0.5, 1.8, (130, 215, 255, 255), shade="flat")
        return c

    head_shade = "crystal" if arch == 22 else ("glossy" if arch == 18 else "soft")
    c.fill_round_rect(hx - 6.0, ty - 5.0, 12.0, 10.0, 3.0, skin_sh, INK, 2.2, shade=head_shade)

    hw, hh = 42.0, 34.0
    if arch in (20, 22):
        hw, hh = 44.0, 35.0
    x0, y0 = hx - hw * 0.5 + 1.0, hy - 17.0
    c.fill_round_rect(x0, y0, hw, hh, 13.5, skin_mid, INK, 2.7, shade=head_shade)
    if arch not in (13, 15, 17, 18, 22):
        c.fill_ellipse(hx + 14.5, hy + 6.5, 4.2, 2.4, (242, 132, 120, 110), shade="flat")
        c.fill_ellipse(hx - 2.5, hy + 6.5, 3.6, 2.2, (242, 132, 120, 95), shade="flat")

    if arch not in (15, 17, 18, 22):
        tuft_col = hair_brown if arch in (1, 3, 7) else ((25, 128, 102, 255) if arch == 19 else (beard_gray if arch == 9 else hair_dark))
        if arch not in (12, 13, 20, 23):
            c.fill_round_rect(x0 - 1.0, hy - 7.0, 8.0, 10.0, 3.0, tuft_col, INK, 1.8)
        c.fill_circle(x0 + 1.5, hy + 2.5, 6.0, skin_mid, INK, 2.4)
        c.fill_circle(x0 + 2.0, hy + 2.8, 2.9, ear_inner, shade="flat")

    ex_l, ex_r, ey = hx + 1.0, hx + 13.5, hy + 1.0

    if arch == 1:
        c.fill_polygon(
            [(hx - 16, hy - 12), (hx + 18, hy - 12), (hx + 20, hy - 5),
             (hx + 11, hy - 7), (hx + 4, hy - 3), (hx - 4, hy - 7), (hx - 12, hy - 4)],
            hair_brown, INK, 2.2, shade="glossy"
        )
        _glossy_eye(ex_l, ey + 0.5, 3.2, 5.6, (88, 62, 42, 255))
        _glossy_eye(ex_r, ey + 0.5, 3.2, 5.6, (88, 62, 42, 255))
        c.fill_round_rect(hx + 3.5, hy + 8.5, 9.5, 5.5, 2.6, (255, 255, 255, 255), INK, 1.6, shade="flat")
    elif arch == 2:
        c.fill_polygon(
            [(hx - 15, hy + 4), (hx + 22, hy + 4), (hx + 20, hy + 17),
             (hx + 8, hy + 19), (hx - 8, hy + 17), (hx - 15, hy + 12)],
            beard_gray, INK, 2.3
        )
        c.fill_ellipse(hx + 7.5, hy + 13.5, 11.0, 4.5, beard_sh)
        c.fill_capsule(ex_l - 4.0, ey - 8.5, ex_l + 3.5, ey - 6.0, 2.2, INK, shade="flat")
        c.fill_capsule(ex_r - 3.5, ey - 6.0, ex_r + 4.0, ey - 8.5, 2.2, INK, shade="flat")
        _glossy_eye(ex_l, ey - 0.5, 3.3, 5.4, (74, 88, 102, 255))
        _glossy_eye(ex_r, ey - 0.5, 3.3, 5.4, (74, 88, 102, 255))
        c.fill_round_rect(hx + 3.5, hy + 9.0, 8.5, 3.2, 1.2, (248, 248, 248, 255), INK, 1.4, shade="flat")
    elif arch == 3:
        c.fill_polygon(
            [(hx - 16, hy - 12), (hx + 18, hy - 12), (hx + 19, hy - 5),
             (hx + 8, hy - 6), (hx - 1, hy - 3), (hx - 12, hy - 6)],
            (58, 42, 30, 255), INK, 2.0, shade="glossy"
        )
        _glossy_eye(ex_l, ey + 0.5, 3.2, 5.6, (72, 102, 56, 255))
        _glossy_eye(ex_r, ey + 0.5, 3.2, 5.6, (72, 102, 56, 255))
        c.fill_ellipse(hx + 8.0, hy + 11.0, 4.5, 3.2, (195, 58, 52, 255), INK, 1.6)
    elif arch == 7:
        beard_ginger = (196, 114, 48, 255)
        beard_g_sh = (146, 80, 32, 255)
        c.fill_ellipse(hx + 4.0, hy + 10.0, 20.0, 10.0, beard_ginger, INK, 2.3, shade="glossy")
        c.fill_polygon(
            [(hx - 12, hy + 10), (hx - 4, hy + 26), (hx + 4, hy + 15),
             (hx + 12, hy + 26), (hx + 20, hy + 10)],
            beard_g_sh, INK, 2.2
        )
        c.fill_capsule(ex_l - 4.0, ey - 8.5, ex_l + 3.5, ey - 6.0, 2.3, INK, shade="flat")
        c.fill_capsule(ex_r - 3.5, ey - 6.0, ex_r + 4.0, ey - 8.5, 2.3, INK, shade="flat")
        _glossy_eye(ex_l, ey - 0.5, 3.2, 5.2, (72, 152, 212, 255))
        _glossy_eye(ex_r, ey - 0.5, 3.2, 5.2, (72, 152, 212, 255))
    elif arch == 9:
        c.fill_polygon(
            [(hx - 15, hy + 4), (hx + 21, hy + 4), (hx + 18, hy + 17),
             (hx + 7, hy + 19), (hx - 6, hy + 17), (hx - 14, hy + 12)],
            (242, 245, 250, 255), INK, 2.2, shade="glossy"
        )
        _glossy_eye(ex_l, ey - 0.5, 3.2, 5.5, (92, 146, 224, 255))
        _glossy_eye(ex_r, ey - 0.5, 3.2, 5.5, (92, 146, 224, 255))
        c.fill_round_rect(hx + 3.0, hy + 9.0, 8.5, 3.5, 1.5, (255, 255, 255, 255), INK, 1.4, shade="flat")
    elif arch == 11:
        c.fill_round_rect(x0 + 1.0, y0 + 1.0, hw - 2.0, hh - 2.0, 12.0, (54, 42, 82, 255), INK, 2.3, shade="glossy")
        c.fill_round_rect(hx - 4.0, hy - 5.5, 23.0, 11.0, 4.5, skin_hi, INK, 1.9)
        c.fill_capsule(ex_l - 3.5, ey - 5.0, ex_l + 3.0, ey - 3.0, 1.8, INK, shade="flat")
        c.fill_capsule(ex_r - 3.0, ey - 3.0, ex_r + 3.5, ey - 5.0, 1.8, INK, shade="flat")
        _glossy_eye(ex_l, ey, 2.8, 4.2, (148, 86, 242, 255))
        _glossy_eye(ex_r, ey, 2.8, 4.2, (148, 86, 242, 255))
    elif arch == 12:
        c.fill_circle(ex_l, ey - 1.0, 5.4, (242, 212, 58, 255), INK, 2.2, shade="glossy")
        c.fill_circle(ex_r, ey - 1.0, 5.4, (242, 212, 58, 255), INK, 2.2, shade="glossy")
        c.fill_circle(ex_l + 0.8, ey - 1.0, 2.0, (192, 32, 32, 255), shade="flat")
        c.fill_circle(ex_r + 0.8, ey - 1.0, 2.0, (192, 32, 32, 255), shade="flat")
        c.fill_circle(ex_l - 1.4, ey - 2.4, 1.2, (255, 255, 255, 255), shade="flat")
        c.fill_circle(ex_r - 1.4, ey - 2.4, 1.2, (255, 255, 255, 255), shade="flat")
        c.fill_round_rect(hx - 2.0, hy + 6.5, 16.0, 9.0, 3.5, (116, 36, 48, 255), INK, 2.0)
        c.fill_triangle((hx + 0.0, hy + 6.5), (hx + 3.5, hy + 10.5), (hx + 6.5, hy + 6.5), (242, 240, 224, 255), shade="flat")
        c.fill_triangle((hx + 8.0, hy + 6.5), (hx + 11.0, hy + 10.5), (hx + 13.5, hy + 6.5), (242, 240, 224, 255), shade="flat")
    elif arch == 13:
        c.fill_circle(ex_l, ey - 1.0, 5.2, INK, shade="flat")
        c.fill_circle(ex_r, ey - 1.0, 5.2, INK, shade="flat")
        c.fill_circle(ex_l + 0.5, ey - 1.5, 1.9, (186, 238, 255, 255), shade="glossy")
        c.fill_circle(ex_r + 0.5, ey - 1.5, 1.9, (186, 238, 255, 255), shade="glossy")
        c.fill_triangle((hx + 6.5, hy + 3.5), (hx + 9.0, hy + 7.5), (hx + 4.5, hy + 7.5), INK, shade="flat")
        c.fill_round_rect(hx - 1.0, hy + 9.0, 17.0, 6.0, 2.0, (242, 240, 232, 255), INK, 1.8)
        for tx in (hx + 3.0, hx + 7.5, hx + 12.0):
            c.fill_capsule(tx, hy + 9.0, tx, hy + 15.0, 0.8, INK, shade="flat")
    elif arch == 15:
        for dy in (-10.0, -3.0, 5.0, 11.0):
            c.fill_capsule(x0 + 3.0, hy + dy, x0 + hw - 3.0, hy + dy + 2.5, 1.1, (152, 140, 108, 255))
        c.fill_round_rect(hx - 5.0, ey - 4.5, 25.0, 8.5, 3.5, (32, 26, 22, 255), INK, 1.5, shade="flat")
        c.fill_circle(ex_l, ey - 0.5, 3.4, (255, 212, 62, 255), shade="glossy")
        c.fill_circle(ex_r, ey - 0.5, 3.4, (255, 212, 62, 255), shade="glossy")
        c.fill_circle(ex_l - 0.9, ey - 1.4, 1.0, (255, 255, 235, 255), shade="flat")
        c.fill_circle(ex_r - 0.9, ey - 1.4, 1.0, (255, 255, 235, 255), shade="flat")
    elif arch == 17:
        c.fill_circle(ex_l, ey - 1.5, 4.8, (255, 232, 92, 255), INK, 2.1, shade="glossy")
        c.fill_circle(ex_r, ey - 1.5, 4.8, (255, 232, 92, 255), INK, 2.1, shade="glossy")
        c.fill_circle(ex_l - 1.3, ey - 3.0, 1.4, (255, 255, 255, 255), shade="flat")
        c.fill_circle(ex_r - 1.3, ey - 3.0, 1.4, (255, 255, 255, 255), shade="flat")
        c.fill_circle(hx + 7.5, hy + 9.5, 5.5, (42, 66, 58, 255), INK, 2.2, shade="metal")
    elif arch == 18:
        c.fill_ellipse(hx + 7.5, hy + 8.5, 10.5, 6.5, (242, 236, 226, 255), INK, 1.8)
        c.fill_circle(ex_l, ey - 1.5, 4.5, (248, 198, 52, 255), INK, 1.8, shade="glossy")
        c.fill_circle(ex_r, ey - 1.5, 4.5, (248, 198, 52, 255), INK, 1.8, shade="glossy")
        c.fill_circle(ex_l + 0.4, ey - 1.5, 1.7, INK, shade="flat")
        c.fill_circle(ex_r + 0.4, ey - 1.5, 1.7, INK, shade="flat")
        c.fill_circle(ex_l - 1.2, ey - 2.8, 1.2, (255, 255, 255, 255), shade="flat")
        c.fill_circle(ex_r - 1.2, ey - 2.8, 1.2, (255, 255, 255, 255), shade="flat")
        c.fill_triangle((hx + 5.0, hy + 5.5), (hx + 10.0, hy + 5.5), (hx + 7.5, hy + 8.8), (244, 124, 148, 255))
        for wy in (hy + 6.0, hy + 9.5):
            c.fill_capsule(hx - 13.0, wy, hx - 4.0, wy - 0.8, 0.9, (242, 240, 235, 255), shade="flat")
            c.fill_capsule(hx + 18.0, wy - 0.8, hx + 25.0, wy, 0.9, (242, 240, 235, 255), shade="flat")
    elif arch == 19:
        _glossy_eye(ex_l, ey, 3.5, 5.8, (244, 146, 46, 255))
        _glossy_eye(ex_r, ey, 3.5, 5.8, (244, 146, 46, 255))
        c.fill_capsule(hx + 4.0, hy + 10.0, hx + 11.5, hy + 9.0, 1.3, INK, shade="flat")
    elif arch == 20:
        c.fill_capsule(ex_l - 4.0, ey - 8.5, ex_l + 4.0, ey - 5.0, 2.4, INK, shade="flat")
        c.fill_capsule(ex_r - 4.0, ey - 5.0, ex_r + 4.0, ey - 8.5, 2.4, INK, shade="flat")
        c.fill_circle(ex_l, ey - 0.5, 4.3, (252, 206, 52, 255), INK, 1.8, shade="glossy")
        c.fill_circle(ex_r, ey - 0.5, 4.3, (252, 206, 52, 255), INK, 1.8, shade="glossy")
        c.fill_circle(ex_l + 0.5, ey - 0.5, 1.5, INK, shade="flat")
        c.fill_circle(ex_r + 0.5, ey - 0.5, 1.5, INK, shade="flat")
        c.fill_circle(ex_l - 1.1, ey - 1.9, 1.1, (255, 255, 255, 255), shade="flat")
        c.fill_circle(ex_r - 1.1, ey - 1.9, 1.1, (255, 255, 255, 255), shade="flat")
        c.fill_capsule(hx + 1.0, hy + 10.0, hx + 14.0, hy + 10.0, 1.6, INK, shade="flat")
        c.fill_triangle((hx + 0.5, hy + 10.5), (hx + 3.0, hy + 4.5), (hx + 5.0, hy + 10.5), (250, 248, 242, 255), INK, 1.3)
        c.fill_triangle((hx + 10.0, hy + 10.5), (hx + 12.0, hy + 4.5), (hx + 14.5, hy + 10.5), (250, 248, 242, 255), INK, 1.3)
    elif arch == 22:
        c.fill_polygon([(x0 + 5, y0 + 3), (hx + 2, y0 + 10), (x0 + 14, hy + 5)], (255, 214, 244, 255), shade="crystal")
        c.fill_ellipse(ex_l, ey, 4.3, 2.8, (255, 224, 108, 255), INK, 1.4, shade="glossy")
        c.fill_ellipse(ex_r, ey, 4.3, 2.8, (255, 224, 108, 255), INK, 1.4, shade="glossy")
        c.fill_circle(ex_l - 1.0, ey - 0.6, 1.0, (255, 255, 255, 255), shade="flat")
        c.fill_circle(ex_r - 1.0, ey - 0.6, 1.0, (255, 255, 255, 255), shade="flat")
        c.fill_capsule(hx + 2.0, hy + 10.5, hx + 12.0, hy + 10.5, 1.4, (162, 68, 132, 255), shade="flat")
    elif arch == 23:
        c.fill_capsule(ex_l - 4.0, ey - 8.5, ex_l + 3.5, ey - 6.0, 2.3, INK, shade="flat")
        c.fill_capsule(ex_r - 3.5, ey - 6.0, ex_r + 4.0, ey - 8.5, 2.3, INK, shade="flat")
        _glossy_eye(ex_l, ey - 0.5, 3.2, 5.4, (92, 64, 42, 255))
        _glossy_eye(ex_r, ey - 0.5, 3.2, 5.4, (92, 64, 42, 255))
        c.fill_polygon([(hx + 2, hy + 10), (hx + 13, hy + 10), (hx + 8, hy + 18)], (36, 28, 24, 255), INK, 1.6)
        c.fill_capsule(hx + 4.0, hy + 10.0, hx + 11.0, hy + 10.0, 1.3, INK, shade="flat")
    elif arch == 24:
        # Raven: shadowed upper face under hood + stubble jaw + glowing violet lightning eye
        c.fill_ellipse(hx + 4.0, hy + 10.0, 19.0, 9.0, (118, 108, 114, 210), shade="flat")
        c.fill_capsule(hx + 3.0, hy + 10.5, hx + 11.5, hy + 10.5, 1.3, INK, shade="flat")
        # Deep shadow covering upper face/brow
        c.fill_ellipse(hx + 2.0, hy - 5.0, 21.0, 12.0, (14, 12, 20, 255), shade="flat")
        # Glowing violet/white lightning eye on right eye + purple flame wisp
        c.fill_ellipse(ex_r, ey, 5.2, 3.0, (172, 78, 248, 255), shade="flat")
        c.fill_ellipse(ex_r, ey, 3.0, 1.6, (255, 242, 255, 255), shade="flat")
        c.fill_polygon([(ex_r + 2, ey - 1), (ex_r + 11, ey - 9), (ex_r + 6, ey - 2)], (196, 112, 255, 235), shade="flat")
        c.fill_polygon([(ex_r, ey + 2), (ex_r - 2, ey + 9), (ex_r + 2, ey + 2)], (162, 68, 238, 220), shade="flat")
    else:
        c.fill_capsule(ex_l - 3.5, ey - 7.5, ex_l + 3.5, ey - 7.2, 2.1, INK, shade="flat")
        c.fill_capsule(ex_r - 3.5, ey - 7.2, ex_r + 3.5, ey - 7.5, 2.1, INK, shade="flat")
        _glossy_eye(ex_l, ey, 3.2, 6.0, (66, 98, 134, 255))
        _glossy_eye(ex_r, ey, 3.2, 6.0, (66, 98, 134, 255))
        if arch in (5, 6):
            c.fill_capsule(hx + 3.0, hy + 10.5, hx + 11.0, hy + 9.5, 1.5, INK, shade="flat")
        else:
            c.fill_capsule(hx + 4.0, hy + 10.5, hx + 10.0, hy + 10.5, 1.4, INK, shade="flat")
    return c


def _draw_archetype_legs(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    pant_palette = [
        ((102, 110, 66, 255), (78, 84, 50, 255), (42, 28, 18, 255)),      # 0 Soldier Olive
        ((124, 104, 80, 255), (96, 80, 62, 255), (40, 26, 18, 255)),      # 1 Explorer Khaki
        ((38, 88, 106, 255), (26, 66, 82, 255), (92, 46, 24, 255)),       # 2 Outlaw Denim
        ((82, 98, 56, 255), (58, 72, 40, 255), (36, 28, 20, 255)),        # 3 Camo
        ((232, 46, 62, 255), (186, 30, 44, 255), (206, 36, 52, 255)),     # 4 Blue Star Tank Red Tights
        ((162, 44, 40, 255), (122, 30, 28, 255), (212, 166, 56, 255)),    # 5 Spartan
        ((158, 42, 38, 255), (118, 28, 26, 255), (110, 64, 34, 255)),     # 6 Centurion
        ((102, 68, 44, 255), (74, 48, 30, 255), (168, 152, 128, 255)),    # 7 Viking
        ((134, 140, 148, 255), (96, 102, 110, 255), (192, 198, 208, 255)),# 8 Crusader
        ((126, 36, 48, 255), (92, 24, 34, 255), (224, 178, 58, 255)),     # 9 King
        ((84, 58, 48, 255), (62, 42, 34, 255), (132, 74, 34, 255)),       # 10 Barrel Pirate
        ((52, 44, 78, 255), (36, 30, 56, 255), (30, 26, 40, 255)),        # 11 Ninja
        ((74, 82, 64, 255), (54, 60, 46, 255), (62, 48, 34, 255)),        # 12 Zombie
        ((38, 40, 46, 255), (28, 30, 34, 255), (235, 232, 222, 255)),     # 13 Skeleton
        ((78, 34, 146, 255), (56, 24, 108, 255), (36, 112, 248, 255)),    # 14 Blue Flame Mage
        ((216, 204, 168, 255), (178, 166, 134, 255), (192, 180, 146, 255)),# 15 Mummy
        ((192, 198, 224, 255), (104, 96, 192, 255), (238, 126, 36, 255)), # 16 White Cube Mech
        ((54, 118, 92, 255), (38, 88, 68, 255), (42, 48, 56, 255)),       # 17 Bio Cyborg
        ((42, 44, 50, 255), (28, 30, 36, 255), (242, 238, 230, 255)),     # 18 Cat
        ((56, 74, 92, 255), (38, 52, 66, 255), (188, 148, 52, 255)),      # 19 Dragon Hero
        ((102, 58, 94, 255), (76, 42, 70, 255), (84, 54, 34, 255)),       # 20 Orc
        ((36, 76, 62, 255), (24, 54, 44, 255), (44, 46, 52, 255)),        # 21 Red Flame Mage (Ignis)
        ((232, 138, 204, 255), (186, 96, 162, 255), (248, 174, 224, 255)),# 22 Crystal
        ((122, 78, 44, 255), (88, 54, 30, 255), (188, 166, 134, 255)),    # 23 Monk
        ((46, 48, 60, 255), (30, 32, 42, 255), (26, 28, 36, 255)),         # 24 Raven
    ]
    p_hi, p_sh, boot = pant_palette[arch % len(pant_palette)]
    leg_shade = "crystal" if arch == 22 else ("metal" if arch in (8, 16) else "soft")
    boot_shade = "metal" if arch in (5, 8, 9, 16, 19) else ("crystal" if arch == 22 else "glossy")

    if p["dead"]:
        c.fill_capsule(20, 78, 38, 80, 5.5, boot, INK, 2.3, shade=boot_shade)
        c.fill_capsule(26, 72, 44, 74, 6.0, p_hi, INK, 2.4, shade=leg_shade)
        return c

    if not p["jet"]:
        c.fill_ellipse(48.0, 91.5, 19.5, 3.3, (14, 18, 28, 115), shade="flat")

    py = p["py"]

    # Custom iconic legs for Barrel Pirate (peg-leg + pirate cuffed boot) & White Cube Mech (piston servo legs)
    if arch == 10:
        c.fill_round_rect(35, py - 4, 27, 9, 4, p_hi, INK, 2.3, shade="soft")
        # Left peg-leg (gunmetal steel collar + tapered iron peg)
        c.fill_round_rect(p["llx"] - 5.5, py + 1, 11, 7, 3, (108, 114, 148, 255), INK, 2.2, shade="metal")
        c.fill_polygon(
            [(p["llx"] - 3.5, py + 7), (p["llx"] + 3.5, py + 7), (p["llx"] + 2.2, p["lly"] + 3), (p["llx"] - 2.2, p["lly"] + 3)],
            (74, 78, 108, 255), INK, 2.2, shade="metal"
        )
        # Right pirate boot + gold cuff trim
        c.fill_capsule(54, py, p["lrx"], p["lry"] - 5, 5.6, p_hi, INK, 2.4)
        c.fill_round_rect(p["lrx"] - 6.0, p["lry"] - 9.0, 14.5, 5.5, 2.0, (176, 134, 48, 255), INK, 1.8, shade="metal")
        c.fill_round_rect(p["lrx"] - 5.5, p["lry"] - 5.0, 14.5, 9.0, 3.0, boot, INK, 2.4, shade="glossy")
        return c

    if arch == 16:
        # Reverse-jointed purple hip servos + metallic silver struts + orange wedge mech feet
        c.fill_circle(38, py + 1, 4.5, p_sh, INK, 2.1, shade="metal")
        c.fill_circle(58, py + 1, 4.5, p_sh, INK, 2.1, shade="metal")
        c.fill_capsule(37, py + 2, p["llx"] + 2, p["lly"] - 2, 3.0, p_hi, INK, 2.0, shade="metal")
        c.fill_capsule(58, py + 2, p["lrx"] - 1, p["lry"] - 2, 3.0, p_hi, INK, 2.0, shade="metal")
        c.fill_polygon([(p["llx"] - 7, p["lly"] + 3), (p["llx"] - 3, p["lly"] - 5), (p["llx"] + 7, p["lly"] + 3)], boot, INK, 2.2, shade="metal")
        c.fill_polygon([(p["lrx"] - 6, p["lry"] + 3), (p["lrx"] - 2, p["lry"] - 5), (p["lrx"] + 8, p["lry"] + 3)], boot, INK, 2.2, shade="metal")
        return c

    thick = 6.2 if arch in (4, 8, 20, 22) else 5.2
    c.fill_capsule(43, py, p["llx"], p["lly"] - 4, thick, p_sh, INK, 2.5, shade=leg_shade)
    c.fill_capsule(52, py, p["lrx"], p["lry"] - 4, thick + 0.4, p_hi, INK, 2.5, shade=leg_shade)
    c.fill_round_rect(39, py - 4, 19, 8, 3, p_hi, INK, 2.0, shade=leg_shade)

    if arch in (5, 6, 8, 19):
        c.fill_round_rect(p["lrx"] - 5, (py + p["lry"]) * 0.5 - 3, 11, 7, 2.5, (216, 174, 64, 255), INK, 1.6, shade="metal")

    bw = 14.0 if arch in (4, 8, 22) else 13.0
    c.fill_round_rect(p["llx"] - 6.0, p["lly"] - 5.0, bw, 9.0, 3.2, boot, INK, 2.5, shade=boot_shade)
    c.fill_round_rect(p["lrx"] - 5.5, p["lry"] - 5.0, bw + 1.0, 9.0, 3.2, boot, INK, 2.5, shade=boot_shade)
    # Crisp folded boot cuff on Flame Mages & rogues
    if arch in (14, 21, 1, 2):
        c.fill_round_rect(p["llx"] - 5.5, p["lly"] - 7.0, bw - 1.0, 4.0, 1.5, boot, INK, 1.6, shade=boot_shade)
        c.fill_round_rect(p["lrx"] - 5.0, p["lry"] - 7.0, bw, 4.0, 1.5, boot, INK, 1.6, shade=boot_shade)
    return c


def _draw_archetype_torso(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    if p["dead"]:
        c.fill_round_rect(34, 62, 26, 18, 6, (120, 128, 140, 255), INK, 2.4, shade="glossy")
        return c

    ty = p["ty"]
    if arch == 0:
        shirt, shirt_sh = (94, 104, 58, 255), (74, 82, 44, 255)
        strap, pouch = (142, 98, 56, 255), (140, 112, 74, 255)
        c.fill_round_rect(33, ty, 30, 22, 6, shirt, INK, 2.6, shade="glossy")
        c.fill_round_rect(28, ty + 2, 10, 15, 4, shirt_sh, INK, 2.2)
        c.fill_round_rect(58, ty + 2, 10, 15, 4, shirt, INK, 2.2)
        c.fill_triangle((42, ty), (54, ty), (48, ty + 6), shirt_sh, INK, 1.8)
        c.fill_round_rect(38, ty + 1, 5, 16, 1.5, strap, INK, 1.6, shade="glossy")
        c.fill_round_rect(51, ty + 1, 5, 16, 1.5, strap, INK, 1.6, shade="glossy")
        c.fill_round_rect(35, ty + 12, 11, 9, 2.5, pouch, INK, 2.0)
        c.fill_round_rect(47, ty + 12, 11, 9, 2.5, pouch, INK, 2.0)
    elif arch == 1:
        shirt, vest, belt, buckle = (220, 204, 180, 255), (96, 70, 44, 255), (58, 40, 28, 255), (212, 220, 228, 255)
        c.fill_round_rect(34, ty, 28, 21, 6, shirt, INK, 2.6)
        c.fill_round_rect(29, ty + 2, 9, 13, 4, shirt, INK, 2.2)
        c.fill_round_rect(58, ty + 2, 9, 13, 4, shirt, INK, 2.2)
        c.fill_round_rect(35, ty + 1, 10, 17, 3, vest, INK, 2.0, shade="glossy")
        c.fill_round_rect(51, ty + 1, 10, 17, 3, vest, INK, 2.0, shade="glossy")
        c.fill_round_rect(34, ty + 15, 28, 6, 2, belt, INK, 2.0)
        c.fill_round_rect(45, ty + 14.5, 8, 7, 1.5, buckle, INK, 1.8, shade="metal")
    elif arch == 2:
        shirt, vest, scarf = (202, 208, 214, 255), (74, 76, 80, 255), (220, 56, 42, 255)
        belt, buckle = (118, 66, 36, 255), (236, 176, 62, 255)
        c.fill_round_rect(33, ty, 30, 22, 6, shirt, INK, 2.6)
        c.fill_round_rect(28, ty + 2, 9, 12, 4, shirt, INK, 2.2)
        c.fill_round_rect(59, ty + 2, 9, 12, 4, shirt, INK, 2.2)
        c.fill_round_rect(35, ty + 1, 11, 16, 3, vest, INK, 2.0, shade="glossy")
        c.fill_round_rect(50, ty + 1, 11, 16, 3, vest, INK, 2.0, shade="glossy")
        c.fill_polygon([(40, ty), (56, ty), (48, ty + 9)], scarf, INK, 1.9, shade="glossy")
        c.fill_round_rect(33, ty + 15, 30, 6, 2, belt, INK, 2.0)
        c.fill_round_rect(44, ty + 14.5, 8, 7, 1.5, buckle, INK, 1.8, shade="metal")
    elif arch == 4:
        # Blue Star Tank: electric blue upper chest + crimson wrestling singlet + white 5-point star!
        blue_mid, red_s = (26, 174, 246, 255), (236, 44, 62, 255)
        c.fill_round_rect(30, ty - 2, 36, 23, 8, blue_mid, INK, 2.6, shade="glossy")
        c.fill_polygon(
            [(30, ty + 6), (66, ty + 6), (66, ty + 20), (30, ty + 20)],
            red_s, INK, 2.5, shade="glossy"
        )
        # Shoulder straps curving over tank top
        c.fill_capsule(31.5, ty - 2.0, 34.5, ty + 7.5, 2.5, red_s, INK, 1.8, shade="glossy")
        c.fill_capsule(64.5, ty - 2.0, 61.5, ty + 7.5, 2.5, red_s, INK, 1.8, shade="glossy")
        # Crisp pure-white 5-point belly star
        c.fill_star(51.5, ty + 13.5, 5.2, 2.3, (255, 255, 255, 255), shade="flat")
    elif arch == 10:
        # Barrel Pirate: wooden orange barrel body + riveted iron hoops + dramatic black mustache!
        oak, seam, hoop = (242, 146, 34, 255), (208, 102, 18, 255), (144, 128, 122, 255)
        c.fill_round_rect(28, ty - 8, 40, 29, 9.5, oak, INK, 2.6, shade="wood")
        # Vertical oak plank stave lines
        for sx in (36, 45, 54, 61):
            c.fill_capsule(sx, ty - 5, sx, ty + 17, 0.9, seam, shade="flat")
        # Upper & lower riveted metal barrel hoops
        c.fill_round_rect(27, ty - 9, 42, 6.5, 2.5, hoop, INK, 2.2, shade="metal")
        c.fill_round_rect(28, ty + 14, 40, 6.5, 2.5, hoop, INK, 2.2, shade="metal")
        # Massive sweeping curved black handlebar pirate mustache across upper barrel
        c.fill_polygon(
            [(30, ty - 4), (47, ty + 3), (62, ty - 6), (66, ty - 2),
             (48, ty + 9), (28, ty + 2)],
            (22, 18, 20, 255), INK, 1.6, shade="flat"
        )
    elif arch in (14, 21):
        # Flame Mages: asymmetrical layered cloak + radiant trim + belt + 3D beveled silver buckle!
        if arch == 21:
            tunic, cloak, trim = (146, 28, 36, 255), (232, 52, 28, 255), (228, 174, 48, 255)
            belt, glove_tone = (78, 52, 42, 255), (192, 198, 212, 255)
        else:
            tunic, cloak, trim = (22, 64, 172, 255), (34, 128, 248, 255), (56, 232, 255, 255)
            belt, glove_tone = (36, 152, 248, 255), (192, 198, 212, 255)

        c.fill_round_rect(34, ty, 28, 22, 5, tunic, INK, 2.5, shade="glossy")
        # Draped asymmetrical diagonal cape over upper torso & collar
        c.fill_polygon(
            [(34, ty - 1), (60, ty - 1), (63, ty + 6), (48, ty + 14),
             (35, ty + 19), (27, ty + 16)],
            cloak, INK, 2.5, shade="glossy"
        )
        # Signature diagonal gold line (arch 21) or glowing cyan jagged flame hem (arch 14)
        if arch == 21:
            c.fill_capsule(31.0, ty + 15.5, 58.0, ty + 1.5, 1.3, trim, shade="flat")
        else:
            c.fill_polygon(
                [(29, ty + 15), (37, ty + 9), (41, ty + 14), (48, ty + 7), (53, ty + 11), (59, ty + 3), (46, ty + 14), (35, ty + 18)],
                trim, shade="flat"
            )
        # Leather/sky waist belt + chunky 3D silver buckle
        c.fill_round_rect(34, ty + 14.5, 28, 5.5, 1.5, belt, INK, 2.0, shade="glossy")
        c.fill_round_rect(44.5, ty + 13.5, 8.5, 7.5, 1.8, glove_tone, INK, 2.0, shade="metal")
        c.fill_round_rect(47.0, ty + 15.8, 3.5, 3.0, 0.8, belt, shade="flat")
    elif arch == 16:
        # White Cube Mech Robot: 3D chassis continuation + stickers (lightning circle & red 3-star rank strip!)
        c.fill_polygon(
            [(28, ty - 4), (66, ty - 4), (66, ty + 16), (29, ty + 17)],
            (226, 230, 248, 255), INK, 2.5, shade="flat"
        )
        c.fill_polygon(
            [(28, ty - 4), (37, ty - 2), (37, ty + 16.5), (29, ty + 17)],
            (186, 192, 222, 255), shade="flat"
        )
        # Black/yellow badge + circular yellow lightning sticker + vertical red 3-star sticker
        c.fill_round_rect(31.5, ty + 0.5, 6.0, 7.0, 1.0, (28, 32, 42, 255), (255, 255, 255, 255), 0.9, shade="flat")
        c.fill_round_rect(34.0, ty + 1.5, 2.5, 5.0, 0.5, (248, 196, 42, 255), shade="flat")
        c.fill_circle(34.0, ty + 8.5, 2.8, (242, 206, 48, 255), (255, 255, 255, 255), 0.8, shade="flat")
        c.fill_round_rect(41.5, ty - 1.5, 5.5, 10.5, 1.0, (216, 46, 56, 255), (255, 255, 255, 255), 0.9, shade="flat")
        for sy in (ty + 0.5, ty + 3.8, ty + 7.1):
            c.fill_circle(44.2, sy, 1.0, (255, 255, 255, 255), shade="flat")
    else:
        style_map = {
            3: ((102, 122, 68, 255), (68, 86, 44, 255), (144, 108, 62, 255)),
            5: ((212, 164, 52, 255), (168, 44, 38, 255), (242, 206, 92, 255)),
            6: ((172, 178, 186, 255), (166, 42, 38, 255), (222, 178, 64, 255)),
            7: ((136, 86, 48, 255), (192, 172, 144, 255), (222, 176, 62, 255)),
            8: ((238, 240, 244, 255), (168, 34, 34, 255), (224, 178, 56, 255)),
            9: ((178, 42, 48, 255), (242, 240, 236, 255), (244, 196, 56, 255)),
            11: ((48, 42, 74, 255), (86, 54, 132, 255), (182, 192, 208, 255)),
            12: ((96, 84, 62, 255), (132, 186, 86, 255), (156, 58, 64, 255)),
            13: ((34, 36, 42, 255), (238, 236, 226, 255), (146, 148, 156, 255)),
            15: ((222, 210, 174, 255), (178, 166, 132, 255), (226, 178, 54, 255)),
            17: ((188, 148, 54, 255), (62, 136, 108, 255), (64, 236, 248, 255)),
            18: ((42, 44, 50, 255), (238, 232, 222, 255), (246, 196, 52, 255)),
            19: ((58, 118, 148, 255), (224, 176, 58, 255), (86, 222, 168, 255)),
            20: ((152, 92, 140, 255), (234, 226, 208, 255), (212, 166, 62, 255)),
            22: ((242, 158, 214, 255), (206, 98, 174, 255), (255, 224, 246, 255)),
            23: ((216, 160, 112, 255), (168, 106, 56, 255), (232, 206, 168, 255)),
            24: ((54, 58, 70, 255), (38, 40, 50, 255), (156, 118, 218, 255)),
        }
        s_col, v_col, acc_col = style_map[arch]
        t_shade = "crystal" if arch == 22 else ("metal" if arch in (5, 6, 8) else "glossy")
        w_t = 34 if arch in (8, 20, 22) else 30
        x_t = 48 - w_t * 0.5
        c.fill_round_rect(x_t, ty, w_t, 22, 6, s_col, INK, 2.6, shade=t_shade)
        c.fill_round_rect(x_t - 5, ty + 2, 9, 13, 4, s_col, INK, 2.2, shade=t_shade)
        c.fill_round_rect(x_t + w_t - 4, ty + 2, 9, 13, 4, s_col, INK, 2.2, shade=t_shade)

        if arch == 8:
            c.fill_round_rect(45, ty + 2, 6, 15, 1, v_col, INK, 1.3, shade="glossy")
            c.fill_round_rect(40, ty + 6, 16, 5, 1, v_col, INK, 1.3, shade="glossy")
        elif arch == 13:
            c.fill_round_rect(46, ty + 2, 4, 16, 1, v_col, shade="glossy")
            for ry in (ty + 4, ty + 9, ty + 14):
                c.fill_round_rect(38, ry, 20, 3, 1.5, v_col, shade="glossy")
        elif arch == 18:
            c.fill_ellipse(48, ty + 12, 8.5, 8.0, v_col)
            c.fill_round_rect(36, ty + 1, 24, 4, 1.5, (186, 44, 44, 255), INK, 1.4, shade="glossy")
            c.fill_circle(48, ty + 5, 3.8, acc_col, INK, 1.6, shade="metal")
        elif arch == 20 or arch == 23:
            for bx in range(38, 60, 5):
                c.fill_circle(bx, ty + 4 + abs(bx - 48) * 0.25, 2.8, acc_col, INK, 1.3, shade="glossy")
        elif arch == 24:
            # Raven: dark neck scarf + raven skull brooch + feathered raven pauldrons
            c.fill_round_rect(x_t + 3, ty + 3, w_t - 6, 12, 3.5, v_col, INK, 1.8, shade="metal")
            c.fill_round_rect(35, ty - 2, 26, 6, 3, (32, 34, 44, 255), INK, 1.8, shade="glossy")
            c.fill_circle(48, ty + 5, 3.4, (78, 82, 96, 255), INK, 1.5, shade="metal")
            c.fill_ellipse(x_t - 2, ty + 3, 7.5, 5.5, (42, 44, 54, 255), INK, 1.8, shade="glossy")
            c.fill_ellipse(x_t + w_t + 2, ty + 3, 7.5, 5.5, (42, 44, 54, 255), INK, 1.8, shade="glossy")
        else:
            c.fill_round_rect(x_t + 3, ty + 3, w_t - 6, 12, 3.5, v_col, INK, 1.8, shade=t_shade)
            c.fill_round_rect(44, ty + 5, 8, 6, 2, acc_col, INK, 1.4, shade="metal" if arch != 22 else "crystal")

        if arch not in (15, 18, 22):
            c.fill_round_rect(x_t, ty + 16, w_t, 5, 2, (48, 44, 42, 255), INK, 1.8)
            c.fill_round_rect(44.5, ty + 15.5, 7, 6, 1.4, acc_col, INK, 1.4, shade="metal")
    return c


def _draw_archetype_headgear(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    if p["dead"]:
        return c

    hx, hy = p["hx"], p["hy"]

    if arch == 0:
        dome, rim = (136, 146, 84, 255), (104, 110, 64, 255)
        c.fill_ellipse(hx, hy - 14.0, 24.5, 14.5, dome, INK, 2.6, shade="glossy")
        c.fill_ellipse(hx + 0.5, hy - 8.0, 26.5, 5.2, rim, INK, 2.5, shade="glossy")
    elif arch == 1:
        dome, band, brim = (164, 136, 104, 255), (86, 92, 98, 255), (142, 114, 86, 255)
        c.fill_ellipse(hx, hy - 14.5, 21.0, 13.0, dome, INK, 2.6, shade="glossy")
        c.fill_round_rect(hx - 20.0, hy - 15.0, 40.0, 6.0, 2.0, band, INK, 2.0, shade="metal")
        c.fill_ellipse(hx + 1.0, hy - 8.5, 31.0, 6.0, brim, INK, 2.6, shade="glossy")
    elif arch == 2:
        crown, band, brim, star = (82, 58, 42, 255), (126, 78, 48, 255), (66, 46, 34, 255), (218, 162, 68, 255)
        c.fill_round_rect(hx - 17.0, hy - 28.0, 34.0, 19.0, 7.0, crown, INK, 2.6, shade="glossy")
        c.fill_round_rect(hx - 17.0, hy - 16.5, 34.0, 6.0, 2.0, band, INK, 1.9, shade="glossy")
        c.fill_star(hx + 4.0, hy - 13.5, 3.8, 1.7, star, INK, 1.2, shade="metal")
        c.fill_polygon(
            [(hx - 30, hy - 14), (hx - 26, hy - 18), (hx - 15, hy - 11),
             (hx + 16, hy - 11), (hx + 27, hy - 18), (hx + 31, hy - 14),
             (hx + 24, hy - 6), (hx - 23, hy - 6)],
            brim, INK, 2.6, shade="glossy"
        )
    elif arch == 3:
        c.fill_ellipse(hx, hy - 14.0, 24.5, 14.5, (124, 152, 72, 255), INK, 2.6, shade="glossy")
        c.fill_ellipse(hx - 9.0, hy - 17.0, 6.0, 4.0, (66, 86, 42, 255))
        c.fill_ellipse(hx + 8.0, hy - 15.0, 7.0, 4.5, (72, 54, 38, 255))
        c.fill_ellipse(hx + 0.5, hy - 8.0, 26.5, 5.2, (86, 108, 48, 255), INK, 2.5, shade="glossy")
    elif arch == 4:
        # Blue Star Tank: twin massive brushed-silver ear-drum cylinders embossed with 5-point metallic stars!
        sil_rim, sil_face, sil_star = (186, 194, 206, 255), (222, 228, 238, 255), (176, 184, 198, 255)
        # Right background ear-drum
        c.fill_ellipse(hx + 21.0, hy - 10.5, 9.5, 11.5, sil_rim, INK, 2.4, shade="metal")
        # Left foreground ear-drum with 3D cylindrical barrel & embossed star
        c.fill_ellipse(hx - 16.0, hy - 9.0, 12.0, 13.5, sil_rim, INK, 2.6, shade="metal")
        c.fill_ellipse(hx - 19.5, hy - 9.0, 9.5, 12.5, sil_face, INK, 2.2, shade="metal")
        c.fill_star(hx - 19.5, hy - 9.0, 7.2, 3.4, sil_star, shade="flat")
    elif arch == 5:
        c.fill_polygon([(hx - 16, hy - 28), (hx + 16, hy - 28), (hx + 18, hy - 16), (hx - 12, hy - 16)], (198, 42, 36, 255), INK, 2.4, shade="glossy")
        c.fill_ellipse(hx, hy - 11.5, 24.5, 14.0, (226, 178, 56, 255), INK, 2.6, shade="metal")
        c.fill_round_rect(hx - 21.0, hy - 11.0, 12.0, 22.0, 4.0, (206, 158, 44, 255), INK, 2.2, shade="metal")
        c.fill_round_rect(hx + 4.0, hy - 11.0, 6.0, 14.0, 2.0, (226, 178, 56, 255), INK, 1.8, shade="metal")
    elif arch == 6:
        c.fill_polygon([(hx - 10, hy - 30), (hx + 12, hy - 30), (hx + 14, hy - 18), (hx - 8, hy - 18)], (196, 44, 38, 255), INK, 2.3, shade="glossy")
        c.fill_ellipse(hx, hy - 12.5, 24.0, 13.5, (176, 184, 196, 255), INK, 2.6, shade="metal")
        c.fill_round_rect(hx - 22.0, hy - 9.0, 44.0, 4.5, 2.0, (232, 182, 58, 255), INK, 2.0, shade="metal")
    elif arch == 7:
        c.fill_polygon([(hx - 16, hy - 15), (hx - 29, hy - 28), (hx - 23, hy - 10)], (246, 240, 218, 255), INK, 2.3, shade="glossy")
        c.fill_polygon([(hx + 16, hy - 15), (hx + 29, hy - 28), (hx + 23, hy - 10)], (246, 240, 218, 255), INK, 2.3, shade="glossy")
        c.fill_ellipse(hx, hy - 13.5, 23.0, 12.5, (118, 126, 138, 255), INK, 2.6, shade="metal")
        c.fill_round_rect(hx - 22.0, hy - 10.5, 44.0, 5.0, 2.0, (196, 154, 64, 255), INK, 2.0, shade="metal")
    elif arch == 8:
        c.fill_polygon([(hx - 18, hy - 17), (hx - 28, hy - 27), (hx - 21, hy - 12)], (236, 228, 204, 255), INK, 2.2, shade="glossy")
        c.fill_polygon([(hx + 18, hy - 17), (hx + 28, hy - 27), (hx + 21, hy - 12)], (236, 228, 204, 255), INK, 2.2, shade="glossy")
        c.fill_ellipse(hx, hy - 12.5, 24.5, 13.5, (238, 242, 248, 255), INK, 2.6, shade="metal")
        c.fill_round_rect(hx - 22.0, hy - 10.0, 44.0, 4.5, 2.0, (232, 182, 54, 255), INK, 2.0, shade="metal")
    elif arch == 9:
        c.fill_ellipse(hx, hy - 13.0, 20.0, 8.0, (176, 36, 46, 255), INK, 2.2, shade="glossy")
        c.fill_polygon(
            [(hx - 18, hy - 8), (hx - 20, hy - 26), (hx - 8, hy - 16),
             (hx, hy - 29), (hx + 8, hy - 16), (hx + 20, hy - 26), (hx + 18, hy - 8)],
            (252, 204, 52, 255), INK, 2.5, shade="metal"
        )
        c.fill_circle(hx, hy - 14.0, 2.9, (236, 42, 68, 255), shade="crystal")
    elif arch == 10:
        # Barrel Pirate: 3 dark cannonballs peeking out, tilted wooden lid, and skull-hat green Pirate Parrot!
        for cx_b, cy_b in ((hx - 11.0, hy - 11.5), (hx - 3.0, hy - 13.0), (hx + 5.0, hy - 11.5)):
            c.fill_circle(cx_b, cy_b, 4.2, (46, 48, 66, 255), INK, 1.8, shade="metal")
        # Tilted wooden orange barrel lid
        c.fill_polygon(
            [(hx - 20.0, hy - 13.0), (hx - 16.0, hy - 20.0), (hx + 16.0, hy - 13.5), (hx + 13.0, hy - 8.5)],
            (238, 140, 32, 255), INK, 2.3, shade="wood"
        )
        # Green Pirate Parrot perched on right rim with yellow beak, eyepatch & skull hat
        px_p, py_p = hx + 11.5, hy - 17.0
        c.fill_ellipse(px_p, py_p, 7.8, 7.2, (42, 168, 76, 255), INK, 2.2, shade="glossy")
        c.fill_ellipse(px_p + 1.5, py_p + 1.5, 4.8, 4.5, (108, 224, 102, 255), shade="flat")
        c.fill_circle(px_p - 1.5, py_p - 1.5, 2.6, (26, 22, 24, 255), shade="flat")
        c.fill_circle(px_p + 3.0, py_p + 0.5, 2.5, (255, 214, 48, 255), INK, 1.4, shade="glossy")
        # Tiny black tricorn skull hat on the parrot!
        c.fill_polygon(
            [(px_p - 7.5, py_p - 5.0), (px_p - 5.0, py_p - 11.0), (px_p + 5.0, py_p - 11.0), (px_p + 7.5, py_p - 5.0)],
            (24, 22, 26, 255), INK, 1.8, shade="flat"
        )
        c.fill_circle(px_p, py_p - 7.5, 2.1, (255, 255, 255, 255), shade="flat")
    elif arch == 11:
        c.fill_ellipse(hx, hy - 12.5, 23.5, 12.5, (64, 48, 96, 255), INK, 2.6, shade="glossy")
        c.fill_round_rect(hx - 12.0, hy - 14.0, 26.0, 7.0, 2.0, (186, 198, 214, 255), INK, 2.0, shade="metal")
        c.fill_polygon([(hx - 22, hy - 12), (hx - 32, hy - 18), (hx - 29, hy - 7)], (84, 52, 134, 255), INK, 2.0, shade="glossy")
    elif arch == 12:
        c.fill_ellipse(hx, hy - 15.5, 21.0, 10.5, (242, 124, 158, 255), INK, 2.5, shade="glossy")
        c.fill_ellipse(hx - 7.0, hy - 16.5, 7.0, 5.0, (255, 158, 186, 255), INK, 1.6, shade="glossy")
        c.fill_ellipse(hx + 6.0, hy - 15.5, 7.5, 5.0, (255, 158, 186, 255), INK, 1.6, shade="glossy")
    elif arch == 13:
        c.fill_polygon([(hx - 16, hy - 14), (hx - 27, hy - 25), (hx - 20, hy - 10)], (220, 216, 198, 255), INK, 2.2, shade="glossy")
        c.fill_polygon([(hx + 16, hy - 14), (hx + 27, hy - 25), (hx + 20, hy - 10)], (220, 216, 198, 255), INK, 2.2, shade="glossy")
        c.fill_ellipse(hx, hy - 13.0, 22.5, 10.0, (48, 52, 62, 255), INK, 2.5, shade="metal")
    elif arch in (14, 21):
        # Swirling Layer Lab Flame Mage Plume + floating ember wisp!
        plume = (74, 54, 174, 255) if arch == 14 else (244, 34, 38, 255)
        wisp = (118, 94, 228, 255) if arch == 14 else (255, 72, 46, 255)
        c.fill_polygon(
            [(hx - 16.0, hy - 8.0), (hx - 19.0, hy - 19.0), (hx - 8.0, hy - 28.0),
             (hx - 12.0, hy - 32.0), (hx - 1.0, hy - 30.0), (hx + 2.0, hy - 21.0),
             (hx + 15.0, hy - 13.0), (hx + 4.0, hy - 13.0), (hx - 6.0, hy - 14.0)],
            plume, INK, 2.3, shade="flame"
        )
        c.fill_polygon(
            [(hx - 25.0, hy - 25.0), (hx - 20.0, hy - 29.0), (hx - 22.0, hy - 22.0)],
            wisp, INK, 1.5, shade="flat"
        )
    elif arch == 15:
        c.fill_round_rect(hx - 21.0, hy - 13.5, 42.0, 6.0, 2.0, (226, 178, 56, 255), INK, 2.0, shade="metal")
        c.fill_polygon([(hx - 20, hy - 12), (hx - 32, hy - 6), (hx - 27, hy + 2)], (222, 210, 174, 255), INK, 2.0)
    elif arch == 16:
        # Twin White-Silver Panel Antennas on Purple Swivel Sockets
        for ax in (hx - 10.5, hx + 8.5):
            c.fill_ellipse(ax, hy - 14.5, 4.8, 3.0, (96, 86, 186, 255), INK, 2.0, shade="metal")
            c.fill_polygon(
                [(ax - 3.5, hy - 15.0), (ax - 5.5, hy - 30.5), (ax + 1.5, hy - 30.5), (ax + 3.0, hy - 15.0)],
                (238, 240, 252, 255), INK, 2.1, shade="metal"
            )
            c.fill_circle(ax - 1.5, hy - 27.5, 1.1, (158, 166, 198, 255), shade="flat")
    elif arch == 17:
        c.fill_ellipse(hx, hy - 13.5, 23.0, 11.5, (52, 134, 102, 255), INK, 2.6, shade="glossy")
        c.fill_round_rect(hx - 5.0, hy - 26.0, 12.0, 12.0, 3.5, (238, 194, 58, 255), INK, 2.2, shade="metal")
    elif arch == 18:
        c.fill_polygon([(hx - 19, hy - 10), (hx - 16, hy - 29), (hx - 3, hy - 14)], (46, 48, 54, 255), INK, 2.5, shade="glossy")
        c.fill_polygon([(hx + 4, hy - 14), (hx + 16, hy - 29), (hx + 20, hy - 10)], (46, 48, 54, 255), INK, 2.5, shade="glossy")
        c.fill_polygon([(hx - 15, hy - 13), (hx - 14, hy - 23), (hx - 7, hy - 15)], (242, 132, 158, 255))
        c.fill_polygon([(hx + 8, hy - 15), (hx + 15, hy - 23), (hx + 17, hy - 13)], (242, 132, 158, 255))
    elif arch == 19:
        c.fill_polygon(
            [(hx - 22, hy - 8), (hx - 24, hy - 24), (hx - 10, hy - 20), (hx + 2, hy - 29),
             (hx + 14, hy - 21), (hx + 26, hy - 23), (hx + 20, hy - 8), (hx + 8, hy - 12), (hx - 6, hy - 9)],
            (28, 148, 118, 255), INK, 2.5, shade="glossy"
        )
    elif arch == 20:
        c.fill_polygon(
            [(hx - 14, hy - 13), (hx - 12, hy - 30), (hx - 2, hy - 24), (hx + 6, hy - 31),
             (hx + 14, hy - 13)],
            (46, 186, 206, 255), INK, 2.5, shade="glossy"
        )
    elif arch == 22:
        c.fill_polygon(
            [(hx - 19, hy - 12), (hx - 14, hy - 29), (hx - 4, hy - 18), (hx + 5, hy - 31),
             (hx + 14, hy - 18), (hx + 22, hy - 25), (hx + 21, hy - 12)],
            (248, 156, 218, 255), INK, 2.5, shade="crystal"
        )
    elif arch == 24:
        # Raven: dark pointed cowl/hood framing the shadowed face
        c.fill_polygon(
            [(hx - 24, hy + 8), (hx - 20, hy - 18), (hx - 4, hy - 29),
             (hx + 14, hy - 25), (hx + 24, hy + 4), (hx + 15, hy - 9),
             (hx - 2, hy - 11), (hx - 16, hy - 6)],
            (44, 46, 58, 255), INK, 2.6, shade="glossy"
        )
    else:
        c.fill_round_rect(hx - 21.0, hy - 12.0, 42.0, 6.5, 2.0, (192, 42, 42, 255), INK, 2.2, shade="glossy")
        c.fill_polygon([(hx - 20, hy - 10), (hx - 32, hy - 15), (hx - 28, hy - 4)], (192, 42, 42, 255), INK, 2.0, shade="glossy")
    return c


def _draw_archetype_hands(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    arm_map = {
        0: (94, 104, 58, 255),
        1: (220, 204, 180, 255),
        2: (202, 208, 214, 255),
        3: (102, 122, 68, 255),
        4: (26, 174, 246, 255),
        5: (226, 180, 150, 255),
        6: (226, 180, 150, 255),
        7: (226, 180, 150, 255),
        8: (182, 190, 202, 255),
        9: (178, 42, 48, 255),
        10: (228, 166, 126, 255),
        11: (54, 42, 82, 255),
        12: (122, 174, 78, 255),
        13: (240, 238, 228, 255),
        14: (162, 170, 182, 255),
        15: (218, 206, 170, 255),
        16: (242, 122, 34, 255),
        17: (64, 134, 106, 255),
        18: (42, 44, 50, 255),
        19: (58, 118, 148, 255),
        20: (148, 88, 136, 255),
        21: (132, 74, 34, 255),
        22: (242, 152, 210, 255),
        23: (214, 158, 108, 255),
        24: (48, 46, 56, 255),
    }
    hand_map = {
        4: (26, 174, 246, 255),
        8: (182, 190, 202, 255),
        10: (228, 166, 126, 255),
        11: (54, 42, 82, 255),
        12: (122, 174, 78, 255),
        13: (240, 238, 228, 255),
        14: (168, 176, 188, 255),
        15: (218, 206, 170, 255),
        16: (242, 122, 34, 255),
        17: (64, 134, 106, 255),
        18: (42, 44, 50, 255),
        20: (148, 88, 136, 255),
        21: (132, 74, 34, 255),
        22: (242, 152, 210, 255),
        23: (214, 158, 108, 255),
        24: (48, 46, 56, 255),
    }
    arm_col = arm_map.get(arch, (242, 180, 150, 255))
    hand_col = hand_map.get(arch, (246, 190, 160, 255))
    h_shade = "crystal" if arch == 22 else ("metal" if arch in (8, 16) else ("glossy" if arch in (4, 14, 21) else "soft"))

    if p["dead"]:
        c.fill_circle(54, 80, 5.8, hand_col, INK, 2.3, shade=h_shade)
        return c

    ty = p["ty"]

    # White Cube Mech: beveled orange side shoulder shields + twin underslung steel piston pincer arms!
    if arch == 16:
        # Left & right beveled orange armor plates
        c.fill_polygon(
            [(22, ty + 1), (32, ty + 2), (34, ty + 16), (25, ty + 19), (21, ty + 11)],
            (244, 124, 34, 255), INK, 2.2, shade="metal"
        )
        c.fill_polygon(
            [(64, ty + 2), (73, ty + 3), (71, ty + 17), (63, ty + 15)],
            (184, 72, 20, 255), INK, 2.2, shade="metal"
        )
        # Underslung dual silver piston arms + orange pincer claws
        for cx_p in (45.0, 56.0):
            c.fill_circle(cx_p, ty + 15.5, 3.6, (94, 86, 182, 255), INK, 1.8, shade="metal")
            c.fill_capsule(cx_p, ty + 16.5, cx_p - 1.5, ty + 25.0, 2.0, (214, 220, 240, 255), INK, 1.7, shade="metal")
            c.fill_circle(cx_p - 1.5, ty + 26.2, 2.6, (242, 124, 34, 255), INK, 1.6, shade="glossy")
        return c

    def _chunky_arm_fist(sx: float, sy: float, fx: float, fy: float, radius: float, tattoo: bool = False) -> None:
        c.fill_capsule(sx, sy, fx, fy, radius * 0.86, arm_col, INK, 2.3, shade=h_shade)
        if tattoo:
            mx, my = (sx + fx) * 0.48, (sy + fy) * 0.48
            c.fill_capsule(mx - 2.0, my - 1.5, mx + 1.8, my + 2.0, 1.0, (108, 62, 46, 255), shade="flat")
            c.fill_capsule(mx - 2.2, my + 0.5, mx + 2.0, my - 0.5, 0.9, (108, 62, 46, 255), shade="flat")
        # Articulated fist oval + thumb + 2 knuckle finger bumps
        c.fill_ellipse(fx, fy, radius + 1.0, radius + 0.6, hand_col, INK, 2.3, shade=h_shade)
        c.fill_circle(fx + (2.6 if fx < 48 else -2.6), fy - 1.4, radius * 0.44, hand_col, INK, 1.6, shade=h_shade)
        c.fill_circle(fx - 1.4, fy + radius * 0.62, radius * 0.36, hand_col, INK, 1.4, shade=h_shade)
        c.fill_circle(fx + 1.6, fy + radius * 0.62, radius * 0.36, hand_col, INK, 1.4, shade=h_shade)

    r_h = 5.4 if arch in (4, 8, 10, 14, 20, 21, 22) else 4.7
    if p["firing"]:
        _chunky_arm_fist(31, ty + 5, 38, ty + 14, r_h, tattoo=(arch == 10))
        _chunky_arm_fist(61, ty + 4, 67, ty + 11, r_h)
    else:
        _chunky_arm_fist(28, ty + 5, 29, ty + 17, r_h, tattoo=(arch == 10))
        _chunky_arm_fist(65, ty + 5, 66, ty + 17, r_h)
    return c


def _draw_archetype_accessories(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE, coord_scale=LAYER_SCALE)
    p = _pose_metrics(f)
    pack_br = (118, 72, 42, 255)
    roll_br = (84, 48, 28, 255)
    holster_br = (116, 62, 34, 255)
    steel = (128, 138, 154, 255)

    if p["dead"]:
        c.fill_round_rect(14, 65, 24, 15, 5, steel, INK, 2.4, shade="metal")
        return c

    ty = p["ty"]
    if p["jet"]:
        c.fill_triangle((22, ty + 18), (34, ty + 18), (26, 90), (255, 130, 24, 255), INK, 1.8, shade="flat")
        c.fill_triangle((24, ty + 18), (32, ty + 18), (27, 83), (255, 242, 150, 255), shade="flat")

    if arch == 1:
        c.fill_round_rect(18, ty - 2, 18, 24, 6, pack_br, INK, 2.6, shade="glossy")
        c.fill_round_rect(19, ty - 8, 16, 9, 4, roll_br, INK, 2.4, shade="glossy")
        c.fill_round_rect(19, ty + 10, 14, 10, 3, roll_br, INK, 2.0, shade="glossy")
    elif arch == 2:
        c.fill_round_rect(28, ty + 16, 11, 14, 3.5, holster_br, INK, 2.4, shade="glossy")
        c.fill_round_rect(20, ty + 2, 12, 16, 4, steel, INK, 2.2, shade="metal")
    elif arch == 4:
        # Clean rounded Blue Star Tank silhouette (no square steel backpack)
        return c
    elif arch in (5, 6, 9):
        cape_col = (168, 36, 36, 255) if arch in (5, 9) else (152, 42, 38, 255)
        c.fill_polygon([(28, ty + 2), (16, ty + 24), (34, ty + 26), (38, ty + 4)], cape_col, INK, 2.4, shade="glossy")
    elif arch == 10:
        # Cutlass hilt peeking behind wooden barrel pirate
        c.fill_polygon([(16, ty - 14), (22, ty - 18), (36, ty + 6), (30, ty + 10)], (216, 226, 242, 255), INK, 2.3, shade="metal")
    elif arch in (14, 21):
        # Trailing flowing Flame Mage back cloak hem
        tail_col = (28, 92, 214, 255) if arch == 14 else (206, 38, 26, 255)
        c.fill_polygon([(30, ty + 2), (20, ty + 22), (35, ty + 24), (40, ty + 4)], tail_col, INK, 2.3, shade="glossy")
    elif arch == 16:
        # Beveled white-lavender mech rear booster pack
        c.fill_polygon([(19, ty - 4), (29, ty - 4), (31, ty + 13), (20, ty + 12)], (216, 220, 242, 255), INK, 2.2, shade="metal")
    elif arch in (8, 11, 19):
        c.fill_polygon([(16, ty - 14), (22, ty - 18), (38, ty + 8), (32, ty + 12)], (216, 226, 242, 255), INK, 2.3, shade="metal")
        c.fill_round_rect(20, ty + 1, 13, 19, 5, steel, INK, 2.3, shade="metal")
    elif arch == 7:
        c.fill_circle(25, ty + 10, 12.5, (148, 94, 48, 255), INK, 2.5, shade="glossy")
        c.fill_circle(25, ty + 10, 4.5, (192, 200, 212, 255), INK, 1.8, shade="metal")
    elif arch == 18:
        c.fill_capsule(32, ty + 18, 16, ty + 12, 3.8, (42, 44, 50, 255), INK, 2.3, shade="glossy")
        c.fill_capsule(16, ty + 12, 18, ty + 3, 3.5, (42, 44, 50, 255), INK, 2.3, shade="glossy")
    elif arch == 22:
        c.fill_polygon([(28, ty + 8), (15, ty - 6), (22, ty + 16)], (248, 156, 218, 255), INK, 2.3, shade="crystal")
        c.fill_polygon([(26, ty + 15), (12, ty + 10), (24, ty + 22)], (228, 118, 192, 255), INK, 2.2, shade="crystal")
    elif arch == 23:
        c.fill_capsule(22, ty - 18, 34, ty + 24, 2.8, (132, 82, 42, 255), INK, 2.2, shade="glossy")
    elif arch == 24:
        # Raven: swirling purple shadow flames + tattered black feather cloak
        c.fill_polygon([(24, ty + 18), (12, ty + 4), (20, ty - 10), (30, ty + 4)], (156, 76, 224, 210), shade="flat")
        c.fill_polygon([(22, ty + 14), (15, ty + 2), (25, ty + 4)], (214, 148, 255, 220), shade="flat")
        c.fill_polygon([(28, ty + 2), (16, ty + 26), (26, ty + 24), (34, ty + 28), (39, ty + 4)], (34, 36, 46, 255), INK, 2.3, shade="glossy")
    else:
        c.fill_round_rect(20, ty + 1, 13, 19, 5, steel, INK, 2.4, shade="metal")
    return c


def build_modular_character_assets() -> None:
    for arch in range(24):
        s_skin = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)
        s_legs = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)
        s_torso = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)
        s_head = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)
        s_hands = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)
        s_acc = Canvas(SPRITE_SIZE * 8, SPRITE_SIZE)

        for f in range(8):
            s_skin.blit(_draw_archetype_skin(arch, f), f * SPRITE_SIZE, 0)
            s_legs.blit(_draw_archetype_legs(arch, f), f * SPRITE_SIZE, 0)
            s_torso.blit(_draw_archetype_torso(arch, f), f * SPRITE_SIZE, 0)
            s_head.blit(_draw_archetype_headgear(arch, f), f * SPRITE_SIZE, 0)
            s_hands.blit(_draw_archetype_hands(arch, f), f * SPRITE_SIZE, 0)
            s_acc.blit(_draw_archetype_accessories(arch, f), f * SPRITE_SIZE, 0)

        # Quantize & compress strictly under 5 KB (4800 bytes target)
        s_skin.save(f"assets/sprites/modular/skin_{arch}.png", max_bytes=4800)
        s_legs.save(f"assets/sprites/modular/legs_{arch}.png", max_bytes=4800)
        s_torso.save(f"assets/sprites/modular/torso_{arch}.png", max_bytes=4800)
        s_head.save(f"assets/sprites/modular/head_{arch}.png", max_bytes=4800)
        s_hands.save(f"assets/sprites/modular/hands_{arch}.png", max_bytes=4800)
        s_acc.save(f"assets/sprites/modular/accessories_{arch}.png", max_bytes=4800)


def _draw_weapon_shape(w_id: int, skin_id: int) -> Canvas:
    w = Canvas(64, 32)
    ol = (18, 22, 28, 255)
    if skin_id == 0:
        body_a = (118, 136, 98, 255)
        body_b = (78, 92, 66, 255)
        accent = (186, 176, 132, 255)
    elif skin_id == 1:
        body_a = (62, 68, 78, 255)
        body_b = (42, 46, 54, 255)
        accent = (140, 150, 165, 255)
    else:
        body_a = (36, 44, 62, 255)
        body_b = (22, 28, 42, 255)
        accent = (0, 235, 255, 255)

    wood = (145, 90, 48, 255) if skin_id != 2 else accent

    if w_id == 0:
        # AK-47
        w.fill_round_rect(6, 14, 14, 7, 2, wood, ol, 1.6)     # stock
        w.fill_round_rect(19, 12, 22, 7, 2, body_a, ol, 1.7)  # receiver
        w.fill_round_rect(36, 12, 21, 3.5, 1, body_b, ol, 1.5) # barrel
        w.fill_round_rect(28, 11, 11, 4, 1, wood, ol, 1.3)    # handguard
        w.fill_capsule(31, 18, 35, 28, 2.3, body_b, ol, 1.4) # banana mag
        w.fill_round_rect(21, 19, 5, 7, 1.5, wood, ol, 1.3)
    elif w_id == 1:
        # M4A1
        w.fill_round_rect(8, 13, 12, 6, 2, body_b, ol, 1.6)
        w.fill_round_rect(19, 12, 20, 7, 2, body_a, ol, 1.7)
        w.fill_round_rect(39, 13, 18, 3.8, 1, accent, ol, 1.5)
        w.fill_round_rect(23, 8, 12, 4, 1.2, body_b, ol, 1.3) # optic rail
        w.fill_round_rect(28, 19, 5, 9, 1.5, body_b, ol, 1.4)
        w.fill_round_rect(20, 19, 5, 7, 1.5, body_b, ol, 1.4)
    elif w_id == 2:
        # SCAR-H
        w.fill_round_rect(8, 12, 13, 8, 2, accent, ol, 1.6)   # ugg-boot stock
        w.fill_round_rect(20, 10, 24, 9, 2, body_a, ol, 1.8)
        w.fill_round_rect(44, 12, 15, 4, 1, body_b, ol, 1.5)
        w.fill_round_rect(30, 19, 6, 9, 1.5, body_b, ol, 1.4) # straight 7.62 mag
        w.fill_round_rect(22, 19, 5, 7, 1.5, body_b, ol, 1.4)
    elif w_id == 3:
        # MP5
        w.fill_round_rect(12, 13, 10, 5, 1.5, body_b, ol, 1.5)
        w.fill_round_rect(20, 11, 20, 7, 2, body_a, ol, 1.7)
        w.fill_round_rect(40, 13, 10, 3.5, 1, body_b, ol, 1.4)
        w.fill_capsule(31, 18, 34, 27, 2.0, body_b, ol, 1.3) # curved 9mm mag
        w.fill_round_rect(22, 18, 5, 7, 1.5, body_b, ol, 1.3)
    elif w_id == 4:
        # Kriss Vector
        w.fill_round_rect(10, 12, 11, 6, 2, body_b, ol, 1.5)
        w.fill_round_rect(20, 10, 23, 8, 2, body_a, ol, 1.7)
        w.fill_round_rect(29, 17, 11, 10, 2, body_a, ol, 1.6) # Super-V block
        w.fill_round_rect(43, 12, 9, 4, 1, accent, ol, 1.4)
        w.fill_round_rect(21, 18, 5, 8, 1.5, body_b, ol, 1.4)
    elif w_id == 5:
        # SPAS-12
        w.fill_round_rect(10, 14, 13, 6, 2, body_b, ol, 1.6)
        w.fill_round_rect(22, 11, 22, 8, 2, body_a, ol, 1.7)
        w.fill_round_rect(44, 12, 14, 4.5, 1, body_b, ol, 1.5)
        w.fill_round_rect(20, 8, 18, 3, 1, accent, ol, 1.2)   # folded stock hook
        w.fill_round_rect(34, 18, 12, 4, 1.5, body_b, ol, 1.4)
    elif w_id == 6:
        # Remington 870
        w.fill_round_rect(7, 15, 15, 7, 2, wood, ol, 1.6)
        w.fill_round_rect(21, 12, 19, 7, 2, body_a, ol, 1.7)
        w.fill_round_rect(40, 12, 20, 3.8, 1, body_b, ol, 1.5)
        w.fill_round_rect(32, 17, 14, 4.5, 1.5, wood, ol, 1.4) # corncob pump
    elif w_id == 7:
        # AWM Sniper
        w.fill_round_rect(6, 13, 15, 7, 2, body_a, ol, 1.6)
        w.fill_round_rect(20, 12, 18, 6.5, 2, body_a, ol, 1.7)
        w.fill_round_rect(38, 13, 24, 3.2, 1, body_b, ol, 1.4) # long barrel
        w.fill_round_rect(22, 7, 16, 4.5, 1.5, body_b, ol, 1.3) # scope
        w.fill_round_rect(28, 18, 6, 6, 1.5, body_b, ol, 1.3)
    elif w_id == 8:
        # Dragunov SVD
        w.fill_round_rect(6, 14, 15, 6.5, 2, wood, ol, 1.6)
        w.fill_round_rect(20, 12, 18, 6, 2, body_a, ol, 1.7)
        w.fill_round_rect(38, 13, 23, 3.0, 1, body_b, ol, 1.4)
        w.fill_round_rect(21, 8, 13, 4.0, 1.2, accent, ol, 1.3)
        w.fill_round_rect(29, 18, 6, 6, 1.5, body_b, ol, 1.3)
    elif w_id == 9:
        # Glock 17
        w.fill_round_rect(20, 11, 22, 6.5, 2, body_a, ol, 1.7)
        w.fill_round_rect(20, 17, 7, 10, 2, body_b, ol, 1.7)
        w.fill_round_rect(37, 12, 4, 3, 0.8, accent)
    else:
        # RPG-7
        w.fill_round_rect(5, 11, 44, 9, 3, body_a, ol, 1.8)
        w.fill_round_rect(3, 9, 6, 13, 2, body_b, ol, 1.6)     # rear exhaust cone
        w.fill_triangle((48, 8), (62, 15.5), (48, 23), (82, 118, 64, 255)) # PG-7V warhead
        w.fill_round_rect(22, 19, 6, 7, 1.5, wood, ol, 1.4)

    if skin_id == 0:
        for px, py in [(22, 13), (28, 15), (34, 13), (24, 15)]:
            w.fill_round_rect(px, py, 3.5, 2.5, 0.5, accent)
    elif skin_id == 2:
        w.fill_round_rect(21, 14, 16, 2, 1.0, (255, 65, 210, 255))
    return w


def build_weapons_sheet() -> None:
    """11 weapons x 3 camo skins = 704x96."""
    sheet = Canvas(64 * 11, 32 * 3)
    for skin_id in range(3):
        for w_id in range(11):
            sheet.blit(_draw_weapon_shape(w_id, skin_id), w_id * 64, skin_id * 32)
    sheet.save("assets/sprites/weapons_sheet.png")


def build_projectiles_and_fx() -> None:
    b = Canvas(24, 8)
    b.fill_round_rect(1, 1.5, 22, 5, 2.5, (255, 175, 40, 220))
    b.fill_round_rect(8, 2, 14, 4, 2.0, (255, 248, 195, 255))
    b.save("assets/sprites/bullet.png")

    l = Canvas(32, 8)
    l.fill_round_rect(0, 1, 32, 6, 3.0, (0, 210, 255, 210))
    l.fill_round_rect(2, 2.5, 28, 3, 1.5, (220, 255, 255, 255))
    l.save("assets/sprites/laser_trail.png")

    m = Canvas(32, 32)
    m.fill_circle(12, 16, 10, (255, 170, 35, 190))
    m.fill_triangle((10, 8), (30, 16), (10, 24), (255, 235, 140, 235))
    m.fill_circle(13, 16, 5, (255, 255, 240, 255))
    m.save("assets/sprites/muzzle_flash.png")

    exp = Canvas(64 * 6, 64)
    for i in range(6):
        f = Canvas(64, 64)
        t = i / 5.0
        r_outer = 10 + t * 21
        alpha_outer = int(255 * (1.0 - t * 0.75))
        f.fill_circle(32, 32, r_outer, (255, 110, 25, alpha_outer))
        if i < 4:
            f.fill_circle(32, 32, r_outer * 0.65, (255, 215, 70, int(255 * (1.0 - t * 0.5))))
        if i < 2:
            f.fill_circle(32, 32, r_outer * 0.35, (255, 255, 235, 255))
        rng = random.Random(42 + i)
        for _ in range(8):
            ang = rng.uniform(0, math.tau)
            dist = r_outer * rng.uniform(0.7, 1.25)
            f.fill_circle(32 + math.cos(ang) * dist, 32 + math.sin(ang) * dist,
                          3.2 * (1.0 - t * 0.6), (255, 180, 60, alpha_outer))
        exp.blit(f, i * 64, 0)
    exp.save("assets/sprites/explosion_sheet.png")

    cr = Canvas(32, 32)
    ol = (18, 22, 28, 255)
    cr.fill_round_rect(2, 2, 28, 28, 4, (74, 112, 74, 255), ol, 2.0)
    cr.fill_round_rect(5, 5, 22, 22, 2, (98, 146, 94, 255), ol, 1.2)
    cr.fill_round_rect(13, 8, 6, 16, 1.5, (245, 225, 90, 255))
    cr.fill_round_rect(8, 13, 16, 6, 1.5, (245, 225, 90, 255))
    cr.save("assets/sprites/weapon_crate.png")


def _draw_tile_row(ts: Canvas, row: int, base_col: tuple, hi_col: tuple, hazard_col: tuple) -> None:
    ol = (20, 24, 30, 255)
    y_off = row * 32

    t0 = Canvas(32, 32)
    t0.fill_round_rect(0, 0, 32, 32, 2, base_col, ol, 1.5)
    t0.fill_round_rect(3, 3, 26, 26, 1, hi_col, ol, 1.0)
    for rx, ry in [(6, 6), (25, 6), (6, 25), (25, 25)]:
        t0.fill_circle(rx, ry, 1.5, (200, 205, 215, 220))
    ts.blit(t0, 0, y_off)

    t1 = Canvas(32, 32)
    t1.fill_round_rect(0, 0, 32, 32, 1, base_col, ol, 1.5)
    t1.fill_round_rect(1, 1, 30, 9, 1, hazard_col)
    for sx in range(-8, 36, 10):
        t1.fill_triangle((sx, 1), (sx + 5, 1), (sx + 1, 10), (30, 34, 40, 255))
        t1.fill_triangle((sx + 5, 1), (sx + 9, 10), (sx + 1, 10), (30, 34, 40, 255))
    ts.blit(t1, 32, y_off)

    t2 = Canvas(32, 32)
    t2.fill_round_rect(0, 0, 32, 6, 1, hi_col, ol, 1.2)
    t2.fill_round_rect(0, 26, 32, 6, 1, base_col, ol, 1.2)
    t2.fill_capsule(4, 6, 28, 26, 2.2, base_col, ol, 1.0)
    t2.fill_capsule(28, 6, 4, 26, 2.2, base_col, ol, 1.0)
    ts.blit(t2, 64, y_off)

    t3 = Canvas(32, 32)
    t3.fill_round_rect(0, 0, 32, 32, 1, base_col, ol, 1.5)
    t3.fill_round_rect(4, 12, 24, 8, 2, hi_col)
    ts.blit(t3, 96, y_off)


def build_tileset_and_bgs() -> None:
    ts = Canvas(256, 128)
    _draw_tile_row(ts, 0, (74, 84, 98, 255), (94, 106, 124, 255), (238, 182, 35, 255))
    _draw_tile_row(ts, 1, (92, 64, 54, 255), (122, 82, 66, 255), (242, 118, 32, 255))
    _draw_tile_row(ts, 2, (132, 108, 76, 255), (164, 136, 96, 255), (222, 168, 62, 255))
    ts.save("assets/tilemaps/bunker_tileset.png")

    specs = [
        ("assets/tilemaps/bunker_bg.png", (22, 27, 36, 255), (28, 34, 46, 255), (17, 21, 29, 255), (42, 50, 66, 255)),
        ("assets/tilemaps/factory_bg.png", (32, 24, 22, 255), (42, 31, 28, 255), (22, 16, 15, 255), (68, 48, 40, 255)),
        ("assets/tilemaps/desert_bg.png", (42, 34, 24, 255), (54, 43, 30, 255), (30, 24, 17, 255), (84, 68, 46, 255)),
    ]
    for path, c_bg, c_panel, c_edge, c_bolt in specs:
        bg = Canvas(512, 512, c_bg)
        for gy in range(0, 512, 128):
            for gx in range(0, 512, 128):
                bg.fill_round_rect(gx + 3, gy + 3, 122, 122, 4, c_panel, c_edge, 1.5)
                for rx in range(gx + 16, gx + 112, 24):
                    bg.fill_round_rect(rx, gy + 16, 8, 96, 2, c_bg)
                for bx, by in [(gx + 10, gy + 10), (gx + 118, gy + 10),
                               (gx + 10, gy + 118), (gx + 118, gy + 118)]:
                    bg.fill_circle(bx, by, 2.2, c_bolt)
        bg.save(path)


def write_wav(rel_path: str, samples: list[float], sample_rate: int = 22050) -> None:
    full_path = os.path.join(ROOT, rel_path)
    ensure_dir(os.path.dirname(full_path))
    pcm = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        pcm.extend(struct.pack("<h", int(v * 32767.0)))
    with wave.open(full_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(bytes(pcm))


def build_audio() -> None:
    sr = 22050
    rng = random.Random(101)

    # Distinct real-world weapon gunfire audio profiles
    # AK-47: deep mechanical 7.62 bark
    write_wav("assets/audio/shoot_ak47.wav", [
        (0.55 * math.sin(math.tau * (210.0 * math.exp(-(i / sr) * 14.0)) * (i / sr))
         + 0.45 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 24.0) * 0.85
        for i in range(int(sr * 0.17))
    ], sr)

    # M4A1: crisp high-pressure 5.56 crack
    write_wav("assets/audio/shoot_m4a1.wav", [
        (0.35 * math.sin(math.tau * (420.0 * math.exp(-(i / sr) * 22.0)) * (i / sr))
         + 0.65 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 34.0) * 0.72
        for i in range(int(sr * 0.13))
    ], sr)

    # SCAR-H: heavy 7.62 battle rifle thump
    write_wav("assets/audio/shoot_scar.wav", [
        (0.62 * math.sin(math.tau * (165.0 * math.exp(-(i / sr) * 12.0)) * (i / sr))
         + 0.38 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 20.0) * 0.90
        for i in range(int(sr * 0.19))
    ], sr)

    # MP5: snappy 9mm submachine pop
    write_wav("assets/audio/shoot_smg.wav", [
        (0.40 * math.sin(math.tau * (520.0 * math.exp(-(i / sr) * 26.0)) * (i / sr))
         + 0.60 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 42.0) * 0.62
        for i in range(int(sr * 0.09))
    ], sr)

    # Kriss Vector: ultra-fast buzz snap
    write_wav("assets/audio/shoot_vector.wav", [
        (0.30 * math.sin(math.tau * (680.0 * math.exp(-(i / sr) * 32.0)) * (i / sr))
         + 0.70 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 52.0) * 0.58
        for i in range(int(sr * 0.07))
    ], sr)

    # AWM / SVD Sniper: sharp supersonic crack + tail
    write_wav("assets/audio/shoot_sniper.wav", [
        (0.50 * math.sin(math.tau * (380.0 * math.exp(-(i / sr) * 8.0) + 95.0) * (i / sr))
         + 0.50 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 11.0) * 0.95
        for i in range(int(sr * 0.32))
    ], sr)

    # RPG-7: rocket ignition whoosh + backblast roar
    rpg_n = int(sr * 0.42)
    rpg_buf = []
    lp_r = 0.0
    for i in range(rpg_n):
        t = i / sr
        lp_r = lp_r * 0.8 + rng.uniform(-1.0, 1.0) * 0.2
        whoosh = math.sin(math.tau * (140.0 + 180.0 * t) * t) * 0.35
        rpg_buf.append((lp_r * 0.65 + whoosh) * math.exp(-t * 4.5) * 0.9)
    write_wav("assets/audio/shoot_rpg.wav", rpg_buf, sr)

    # Shotgun, Explosion, Jetpack, Hit, Jump, Pickup, BGM
    write_wav("assets/audio/shoot_shotgun.wav", [
        (0.4 * math.sin(math.tau * 110.0 * math.exp(-(i / sr) * 8.0) * (i / sr))
         + 0.6 * rng.uniform(-1.0, 1.0)) * math.exp(-(i / sr) * 15.0) * 0.85
        for i in range(int(sr * 0.24))
    ], sr)

    expl = []
    low = 0.0
    for i in range(int(sr * 0.55)):
        t = i / sr
        low = low * 0.86 + rng.uniform(-1.0, 1.0) * 0.14
        rumble = math.sin(math.tau * (75.0 * math.exp(-t * 3.0)) * t)
        expl.append((0.65 * low + 0.35 * rumble) * math.exp(-t * 5.8) * 0.95)
    write_wav("assets/audio/explosion.wav", expl, sr)

    jet = []
    lp = 0.0
    for _ in range(int(sr * 0.25)):
        lp = lp * 0.72 + rng.uniform(-1.0, 1.0) * 0.28
        jet.append(lp * 0.45)
    write_wav("assets/audio/jetpack.wav", jet, sr)

    write_wav("assets/audio/hit.wav", [
        math.sin(math.tau * 220.0 * (i / sr)) * math.exp(-(i / sr) * 40.0) * 0.7
        for i in range(int(sr * 0.09))
    ], sr)

    n_jmp = int(sr * 0.12)
    write_wav("assets/audio/jump.wav", [
        math.sin(math.tau * (240.0 + 480.0 * (i / n_jmp)) * (i / sr)) * math.exp(-(i / sr) * 20.0) * 0.5
        for i in range(n_jmp)
    ], sr)

    write_wav("assets/audio/pickup.wav", [
        math.sin(math.tau * (587.3 if (i / sr) < 0.09 else 880.0) * (i / sr))
        * math.exp(-(i / sr) * 12.0) * 0.55
        for i in range(int(sr * 0.22))
    ], sr)

    dur = 8.0
    total = int(sr * dur)
    bass_notes = [110.0, 110.0, 130.81, 146.83, 110.0, 110.0, 164.81, 146.83]
    lead_notes = [440.0, 523.25, 587.33, 659.25, 587.33, 523.25, 493.88, 440.0]
    bgm = []
    for i in range(total):
        t = i / sr
        beat_pos = (t * 2.0) % 1.0
        step = int(t * 2.0) % len(bass_notes)
        sub_step = int(t * 4.0) % 16
        bass = math.sin(math.tau * bass_notes[step] * t) * math.exp(-((t * 4.0) % 1.0) * 4.5) * 0.28
        l_freq = lead_notes[(sub_step // 2) % len(lead_notes)]
        lead = (math.sin(math.tau * l_freq * t) + 0.35 * math.sin(math.tau * l_freq * 2.0 * t)) * math.exp(-((t * 4.0) % 1.0) * 7.0) * 0.14
        kick = math.sin(math.tau * (95.0 * math.exp(-beat_pos * 12.0)) * beat_pos) * math.exp(-beat_pos * 18.0) * 0.25
        hat = rng.uniform(-1.0, 1.0) * math.exp(-((t * 4.0) % 1.0) * 35.0) * 0.08
        bgm.append(bass + lead + kick + hat)
    write_wav("assets/audio/bgm_loop.wav", bgm, sr)


if __name__ == "__main__":
    build_modular_character_assets()
    build_weapons_sheet()
    build_projectiles_and_fx()
    build_tileset_and_bgs()
    build_audio()
    print("Generated 144 modular character PNGs, 11x3 weapons sheet, and real-world audio WAVs.")
