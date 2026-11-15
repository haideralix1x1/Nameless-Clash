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


def write_png(path: str, width: int, height: int, pixels: bytearray) -> None:
    ensure_dir(os.path.dirname(path))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

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
    """Lightweight anti-aliased 2D RGBA vector rasterizer."""

    def __init__(self, width: int, height: int, bg=(0, 0, 0, 0)):
        self.w = width
        self.h = height
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

    def _apply_sdf(self, px: int, py: int, sdist: float, fill: tuple[int, int, int, int],
                   outline: tuple[int, int, int, int] | None, outline_w: float) -> None:
        if outline:
            if sdist <= outline_w + 0.5:
                cov_out = max(0.0, min(1.0, outline_w + 0.5 - sdist))
                if sdist > -0.5:
                    self.blend_pixel(px, py, outline, cov_out)
                if sdist <= 0.5:
                    cov_in = max(0.0, min(1.0, 0.5 - sdist))
                    self.blend_pixel(px, py, fill, cov_in)
        else:
            if sdist <= 0.5:
                cov = max(0.0, min(1.0, 0.5 - sdist))
                self.blend_pixel(px, py, fill, cov)

    def fill_circle(self, cx: float, cy: float, r: float, fill: tuple[int, int, int, int],
                    outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4) -> None:
        total_r = r + (outline_w if outline else 0.0)
        x0 = max(0, int(math.floor(cx - total_r - 2)))
        x1 = min(self.w - 1, int(math.ceil(cx + total_r + 2)))
        y0 = max(0, int(math.floor(cy - total_r - 2)))
        y1 = min(self.h - 1, int(math.ceil(cy + total_r + 2)))
        for py in range(y0, y1 + 1):
            for px in range(x0, x1 + 1):
                sdist = math.hypot(px + 0.5 - cx, py + 0.5 - cy) - r
                self._apply_sdf(px, py, sdist, fill, outline, outline_w)

    def fill_ellipse(self, cx: float, cy: float, rx: float, ry: float, fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4) -> None:
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
                self._apply_sdf(px, py, sdist, fill, outline, outline_w)

    def fill_round_rect(self, x: float, y: float, w: float, h: float, radius: float,
                        fill: tuple[int, int, int, int],
                        outline: tuple[int, int, int, int] | None = None,
                        outline_w: float = 2.4) -> None:
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
        for py in range(y0, y1 + 1):
            pyf = py + 0.5
            dy = 0.0
            if pyf < cy_min:
                dy = cy_min - pyf
            elif pyf > cy_max:
                dy = pyf - cy_max
            for px in range(x0, x1 + 1):
                pxf = px + 0.5
                dx = 0.0
                if pxf < cx_min:
                    dx = cx_min - pxf
                elif pxf > cx_max:
                    dx = pxf - cx_max
                sdist = math.hypot(dx, dy) - rad
                self._apply_sdf(px, py, sdist, fill, outline, outline_w)

    def fill_capsule(self, x1: float, y1: float, x2: float, y2: float, r: float,
                     fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None,
                     outline_w: float = 2.4) -> None:
        pad = r + (outline_w if outline else 0.0) + 2.0
        minx = max(0, int(math.floor(min(x1, x2) - pad)))
        maxx = min(self.w - 1, int(math.ceil(max(x1, x2) + pad)))
        miny = max(0, int(math.floor(min(y1, y2) - pad)))
        maxy = min(self.h - 1, int(math.ceil(max(y1, y2) + pad)))
        vx, vy = x2 - x1, y2 - y1
        seg_len2 = vx * vx + vy * vy
        for py in range(miny, maxy + 1):
            for px in range(minx, maxx + 1):
                pxf, pyf = px + 0.5, py + 0.5
                if seg_len2 <= 1e-6:
                    d = math.hypot(pxf - x1, pyf - y1)
                else:
                    t = max(0.0, min(1.0, ((pxf - x1) * vx + (pyf - y1) * vy) / seg_len2))
                    d = math.hypot(pxf - (x1 + t * vx), pyf - (y1 + t * vy))
                self._apply_sdf(px, py, d - r, fill, outline, outline_w)

    def fill_polygon(self, points: list[tuple[float, float]], fill: tuple[int, int, int, int],
                     outline: tuple[int, int, int, int] | None = None, outline_w: float = 2.4) -> None:
        n = len(points)
        if n < 3:
            return
        pad = (outline_w if outline else 0.0) + 2.0
        minx = max(0, int(math.floor(min(p[0] for p in points) - pad)))
        maxx = min(self.w - 1, int(math.ceil(max(p[0] for p in points) + pad)))
        miny = max(0, int(math.floor(min(p[1] for p in points) - pad)))
        maxy = min(self.h - 1, int(math.ceil(max(p[1] for p in points) + pad)))

        edges = []
        for i in range(n):
            ax, ay = points[i]
            bx, by = points[(i + 1) % n]
            ex, ey = bx - ax, by - ay
            l2 = ex * ex + ey * ey
            edges.append((ax, ay, bx, by, ex, ey, l2))

        for py in range(miny, maxy + 1):
            pyf = py + 0.5
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
                self._apply_sdf(px, py, sdist, fill, outline, outline_w)

    def fill_triangle(self, p1: tuple[float, float], p2: tuple[float, float], p3: tuple[float, float],
                      fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None,
                      outline_w: float = 2.0) -> None:
        self.fill_polygon([p1, p2, p3], fill, outline, outline_w)

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

    def save(self, rel_path: str) -> None:
        write_png(os.path.join(ROOT, rel_path), self.w, self.h, self.buf)


INK = (22, 16, 18, 255)
SPRITE_SIZE = 96


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
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    skin_hi = (248, 198, 168, 255)
    skin_mid = (242, 180, 150, 255)
    skin_sh = (224, 148, 120, 255)
    ear_inner = (205, 118, 96, 255)
    hair_dark = (40, 32, 30, 255)
    hair_brown = (116, 72, 46, 255)
    beard_gray = (138, 134, 130, 255)
    beard_sh = (106, 102, 98, 255)

    if arch == 8:
        skin_hi = (232, 238, 245, 255)
        skin_sh = (182, 192, 206, 255)

    if p["dead"]:
        c.fill_round_rect(54, 52, 34, 30, 11, skin_mid, INK, 2.5)
        c.fill_ellipse(69, 64, 2.4, 2.4, INK)
        c.fill_ellipse(77, 64, 2.4, 2.4, INK)
        return c

    hx, hy, ty = p["hx"], p["hy"], p["ty"]
    # Neck shadow
    c.fill_round_rect(hx - 6.0, ty - 5.0, 12.0, 10.0, 3.0, skin_sh, INK, 2.2)

    # Oversized Chibi Head Box (matches bold reference proportions)
    hw, hh = 42.0, 34.0
    if arch in (2, 9):
        hw, hh = 44.0, 35.0
    x0, y0 = hx - 20.0, hy - 17.0
    c.fill_round_rect(x0, y0, hw, hh, 13.0, skin_hi, INK, 2.7)
    # Soft cartoon cel-shading under hat brim & left jaw
    c.fill_round_rect(x0 + 2.0, y0 + 2.0, hw - 4.0, 9.0, 6.0, skin_sh)
    c.fill_round_rect(x0 + 2.0, y0 + 14.0, 8.0, hh - 16.0, 4.0, skin_sh)

    # Sideburn hair tufts peeking behind ear
    tuft_col = hair_brown if arch in (1, 6) else (beard_gray if arch == 7 else hair_dark)
    c.fill_round_rect(x0 - 1.0, hy - 7.0, 8.0, 10.0, 3.0, tuft_col, INK, 1.8)

    # Distinct Chibi Left Ear with pink inner swirl
    c.fill_circle(x0 + 1.5, hy + 2.5, 6.2, skin_mid, INK, 2.4)
    c.fill_circle(x0 + 2.0, hy + 2.8, 3.0, ear_inner)

    # Facial Expression Variants
    ex_l, ex_r, ey = hx + 1.0, hx + 13.5, hy + 1.0

    if arch == 1:
        # Ref #2 Explorer: swept brown front fringe + cheerful smile
        c.fill_polygon(
            [(hx - 16, hy - 12), (hx + 18, hy - 12), (hx + 20, hy - 5),
             (hx + 11, hy - 7), (hx + 4, hy - 3), (hx - 4, hy - 7), (hx - 12, hy - 4)],
            hair_brown, INK, 2.2
        )
        c.fill_ellipse(ex_l, ey + 0.5, 3.1, 5.6, INK)
        c.fill_ellipse(ex_r, ey + 0.5, 3.1, 5.6, INK)
        # Bright D smile
        c.fill_round_rect(hx + 3.5, hy + 8.5, 9.5, 5.5, 2.6, (255, 255, 255, 255), INK, 1.6)
    elif arch == 2:
        # Ref #3 Bearded Outlaw: sculpted gray beard + gritty scowl
        c.fill_polygon(
            [(hx - 15, hy + 4), (hx + 22, hy + 4), (hx + 20, hy + 17),
             (hx + 8, hy + 19), (hx - 8, hy + 17), (hx - 15, hy + 12)],
            beard_gray, INK, 2.3
        )
        c.fill_ellipse(hx + 7.5, hy + 13.5, 11.0, 4.5, beard_sh)
        # Angry inward thick eyebrows + large oval eyes
        c.fill_capsule(ex_l - 4.0, ey - 8.5, ex_l + 3.5, ey - 6.0, 2.2, INK)
        c.fill_capsule(ex_r - 3.5, ey - 6.0, ex_r + 4.0, ey - 8.5, 2.2, INK)
        c.fill_ellipse(ex_l, ey - 0.5, 3.3, 5.4, INK)
        c.fill_ellipse(ex_r, ey - 0.5, 3.3, 5.4, INK)
        # Gritty clenched teeth line
        c.fill_round_rect(hx + 3.5, hy + 9.0, 8.5, 3.2, 1.2, (248, 248, 248, 255), INK, 1.4)
    elif arch == 3:
        # Tactical Goggles / Eyewear
        c.fill_ellipse(ex_l, ey, 3.0, 5.4, INK)
        c.fill_ellipse(ex_r, ey, 3.0, 5.4, INK)
        c.fill_round_rect(hx - 6.0, ey - 6.5, 12.0, 10.5, 3.5, (72, 185, 235, 220), INK, 2.4)
        c.fill_round_rect(hx + 8.0, ey - 6.5, 12.0, 10.5, 3.5, (72, 185, 235, 220), INK, 2.4)
        c.fill_round_rect(hx - 1.5, hy + 9.5, 12.0, 4.5, 2.0, beard_sh, INK, 1.5)
    elif arch == 4 or arch == 5:
        # Balaclava / Riot Gritty Eyebrows + Intense Eyes
        c.fill_round_rect(hx - 14.0, hy - 10.0, 35.0, 27.0, 9.0, (46, 52, 62, 255), INK, 2.2)
        c.fill_round_rect(hx - 2.0, hy - 4.5, 22.0, 10.0, 4.0, skin_hi, INK, 1.8)
        c.fill_ellipse(ex_l, ey - 0.5, 2.9, 4.6, INK)
        c.fill_ellipse(ex_r, ey - 0.5, 2.9, 4.6, INK)
        if arch == 5:
            c.fill_round_rect(hx + 2.0, hy + 5.5, 16.0, 10.0, 4.0, (92, 98, 108, 255), INK, 2.0)
            c.fill_circle(hx + 12.0, hy + 10.5, 3.8, (64, 68, 76, 255), INK, 1.6)
    elif arch == 8:
        # Half-Chrome Cyborg Face + Glowing Cyan Eye
        c.fill_round_rect(hx + 2.0, y0 + 2.0, 20.0, hh - 4.0, 7.0, (160, 174, 192, 255), INK, 2.0)
        c.fill_ellipse(ex_l, ey, 3.1, 5.6, INK)
        c.fill_round_rect(ex_r - 5.0, ey - 5.0, 12.0, 8.0, 3.0, (25, 32, 42, 255), INK, 1.8)
        c.fill_circle(ex_r + 1.0, ey - 1.0, 3.0, (35, 240, 255, 255))
        c.fill_capsule(hx + 3.0, hy + 10.0, hx + 11.0, hy + 10.0, 1.3, INK)
    else:
        # Neutral / Veteran / Gritty Soldier (Ref #1 style)
        c.fill_capsule(ex_l - 3.5, ey - 7.5, ex_l + 3.5, ey - 7.2, 2.1, INK)
        c.fill_capsule(ex_r - 3.5, ey - 7.2, ex_r + 3.5, ey - 7.5, 2.1, INK)
        c.fill_ellipse(ex_l, ey, 3.2, 6.0, INK)
        c.fill_ellipse(ex_r, ey, 3.2, 6.0, INK)
        if arch == 7:
            c.fill_capsule(hx - 2.0, hy - 1.0, hx + 3.0, hy + 8.0, 1.2, (195, 76, 76, 240))
            c.fill_round_rect(hx - 8.0, hy + 6.5, 26.0, 9.0, 4.0, beard_gray, INK, 1.8)
        elif arch in (6, 9):
            c.fill_round_rect(hx + 2.0, hy + 9.0, 10.0, 3.2, 1.5, (235, 235, 235, 255), INK, 1.5)
        else:
            c.fill_capsule(hx + 4.0, hy + 10.5, hx + 10.0, hy + 10.5, 1.4, INK)
    return c


def _draw_archetype_legs(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    pant_palette = [
        ((102, 110, 66, 255), (78, 84, 50, 255), (42, 28, 18, 255)),     # 0 Soldier Olive
        ((124, 104, 80, 255), (96, 80, 62, 255), (40, 26, 18, 255)),     # 1 Explorer Khaki
        ((38, 88, 106, 255), (26, 66, 82, 255), (92, 46, 24, 255)),      # 2 Outlaw Denim + Cowboy Boots
        ((64, 72, 54, 255), (46, 52, 38, 255), (34, 24, 18, 255)),       # 3 Commander
        ((52, 58, 70, 255), (36, 40, 50, 255), (28, 30, 36, 255)),       # 4 Spec-Ops
        ((62, 74, 96, 255), (44, 54, 72, 255), (30, 34, 42, 255)),       # 5 Enforcer
        ((78, 82, 90, 255), (56, 60, 68, 255), (52, 36, 26, 255)),       # 6 Rebel
        ((126, 112, 90, 255), (96, 84, 68, 255), (218, 220, 226, 255)),  # 7 Scout Sneakers
        ((64, 72, 86, 255), (44, 50, 62, 255), (42, 48, 60, 255)),       # 8 Cyborg
        ((76, 82, 92, 255), (52, 58, 66, 255), (34, 36, 42, 255)),       # 9 Breacher
    ]
    p_hi, p_sh, boot = pant_palette[arch % len(pant_palette)]

    if p["dead"]:
        c.fill_capsule(20, 78, 38, 80, 5.5, boot, INK, 2.3)
        c.fill_capsule(26, 72, 44, 74, 6.0, p_hi, INK, 2.4)
        return c

    py = p["py"]
    thick = 6.2 if arch in (5, 9) else 5.2

    # Back Leg
    c.fill_capsule(43, py, p["llx"], p["lly"] - 4, thick, p_sh, INK, 2.5)
    # Front Leg
    c.fill_capsule(52, py, p["lrx"], p["lry"] - 4, thick + 0.4, p_hi, INK, 2.5)

    # Crotch seam overlap clean fill
    c.fill_round_rect(39, py - 4, 19, 8, 3, p_hi, INK, 2.0)

    if arch in (5, 9):
        c.fill_round_rect(p["lrx"] - 5, (py + p["lry"]) * 0.5 - 3, 11, 8, 3, (112, 118, 128, 255), INK, 1.8)
    elif arch == 8:
        c.fill_circle((52 + p["lrx"]) * 0.5, (py + p["lry"]) * 0.5, 4.0, (60, 232, 255, 255), INK, 1.8)

    # Chunky Chibi Boots with Bold Outlines
    bw = 14.0 if arch == 2 else 13.0
    c.fill_round_rect(p["llx"] - 6.0, p["lly"] - 5.0, bw, 9.0, 3.2, boot, INK, 2.5)
    c.fill_round_rect(p["lrx"] - 5.5, p["lry"] - 5.0, bw + 1.0, 9.0, 3.2, boot, INK, 2.5)
    return c


def _draw_archetype_torso(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    if p["dead"]:
        shirt_c = [(94, 102, 58, 255), (218, 202, 178, 255), (198, 204, 210, 255)][min(arch, 2)]
        c.fill_round_rect(34, 62, 26, 18, 6, shirt_c, INK, 2.4)
        return c

    ty = p["ty"]
    # Reference-authentic shirt/vest palettes & details
    if arch == 0:
        # Ref #1 Soldier: olive shirt + collar + brown straps + twin front ammo pouches
        shirt = (94, 104, 58, 255)
        shirt_sh = (74, 82, 44, 255)
        strap = (142, 98, 56, 255)
        pouch = (140, 112, 74, 255)
        c.fill_round_rect(33, ty, 30, 22, 6, shirt, INK, 2.6)
        # Shoulders / sleeves
        c.fill_round_rect(28, ty + 2, 10, 15, 4, shirt_sh, INK, 2.2)
        c.fill_round_rect(58, ty + 2, 10, 15, 4, shirt, INK, 2.2)
        # V Collar
        c.fill_triangle((42, ty), (54, ty), (48, ty + 6), shirt_sh, INK, 1.8)
        # Suspenders & twin front chest/belt pouches
        c.fill_round_rect(38, ty + 1, 5, 16, 1.5, strap, INK, 1.6)
        c.fill_round_rect(51, ty + 1, 5, 16, 1.5, strap, INK, 1.6)
        c.fill_round_rect(35, ty + 12, 11, 9, 2.5, pouch, INK, 2.0)
        c.fill_round_rect(47, ty + 12, 11, 9, 2.5, pouch, INK, 2.0)
    elif arch == 1:
        # Ref #2 Explorer: tan collared button shirt + open brown vest + silver belt buckle
        shirt = (220, 204, 180, 255)
        vest = (96, 70, 44, 255)
        belt = (58, 40, 28, 255)
        buckle = (212, 220, 228, 255)
        c.fill_round_rect(34, ty, 28, 21, 6, shirt, INK, 2.6)
        c.fill_round_rect(29, ty + 2, 9, 13, 4, shirt, INK, 2.2)
        c.fill_round_rect(58, ty + 2, 9, 13, 4, shirt, INK, 2.2)
        # Open vest panels
        c.fill_round_rect(35, ty + 1, 10, 17, 3, vest, INK, 2.0)
        c.fill_round_rect(51, ty + 1, 10, 17, 3, vest, INK, 2.0)
        # Belt & Silver Square Buckle
        c.fill_round_rect(34, ty + 15, 28, 6, 2, belt, INK, 2.0)
        c.fill_round_rect(45, ty + 14.5, 8, 7, 1.5, buckle, INK, 1.8)
    elif arch == 2:
        # Ref #3 Outlaw: light cool gray shirt + red neckerchief + dark charcoal vest + gold buckle
        shirt = (202, 208, 214, 255)
        vest = (74, 76, 80, 255)
        scarf = (220, 56, 42, 255)
        belt = (118, 66, 36, 255)
        buckle = (236, 176, 62, 255)
        c.fill_round_rect(33, ty, 30, 22, 6, shirt, INK, 2.6)
        c.fill_round_rect(28, ty + 2, 9, 12, 4, shirt, INK, 2.2)
        c.fill_round_rect(59, ty + 2, 9, 12, 4, shirt, INK, 2.2)
        # Charcoal vest sides
        c.fill_round_rect(35, ty + 1, 11, 16, 3, vest, INK, 2.0)
        c.fill_round_rect(50, ty + 1, 11, 16, 3, vest, INK, 2.0)
        # Bright red neckerchief triangle at throat
        c.fill_polygon([(40, ty), (56, ty), (48, ty + 9)], scarf, INK, 1.9)
        # Brown gun belt + gold buckle
        c.fill_round_rect(33, ty + 15, 30, 6, 2, belt, INK, 2.0)
        c.fill_round_rect(44, ty + 14.5, 8, 7, 1.5, buckle, INK, 1.8)
    else:
        # Archetypes 3..9 matching rich chibi outfit geometry
        style_map = {
            3: ((84, 94, 66, 255), (120, 96, 64, 255), (235, 192, 68, 255)),    # Commander
            4: ((46, 52, 64, 255), (68, 78, 92, 255), (85, 220, 175, 255)),     # Spec-Ops
            5: ((54, 68, 94, 255), (82, 96, 118, 255), (225, 185, 65, 255)),    # Enforcer Riot
            6: ((126, 64, 52, 255), (72, 66, 64, 255), (210, 175, 78, 255)),    # Urban Rebel
            7: ((196, 174, 136, 255), (96, 110, 78, 255), (240, 125, 45, 255)), # Scout
            8: ((72, 82, 100, 255), (145, 160, 180, 255), (40, 238, 255, 255)), # Cyborg
            9: ((78, 96, 116, 255), (160, 170, 182, 255), (240, 190, 60, 255)), # Breacher
        }
        s_col, v_col, acc_col = style_map[arch]
        w_t = 34 if arch in (5, 9) else 30
        x_t = 48 - w_t * 0.5
        c.fill_round_rect(x_t, ty, w_t, 22, 6, s_col, INK, 2.6)
        c.fill_round_rect(x_t - 5, ty + 2, 9, 13, 4, s_col, INK, 2.2)
        c.fill_round_rect(x_t + w_t - 4, ty + 2, 9, 13, 4, s_col, INK, 2.2)
        c.fill_round_rect(x_t + 3, ty + 3, w_t - 6, 13, 4, v_col, INK, 2.0)
        c.fill_round_rect(44, ty + 6, 8, 6, 2, acc_col, INK, 1.5)
        c.fill_round_rect(x_t, ty + 16, w_t, 5, 2, (48, 44, 42, 255), INK, 1.8)
    return c


def _draw_archetype_headgear(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    if p["dead"]:
        return c

    hx, hy = p["hx"], p["hy"]

    if arch == 0:
        # Ref #1: Steel Military M1 Helmet (Olive dome + wide curved rim)
        dome = (136, 142, 84, 255)
        hi = (158, 166, 102, 255)
        rim = (104, 110, 64, 255)
        c.fill_ellipse(hx, hy - 14.0, 24.5, 14.5, dome, INK, 2.6)
        c.fill_ellipse(hx + 4.0, hy - 18.0, 13.0, 6.0, hi)
        c.fill_ellipse(hx + 0.5, hy - 8.0, 26.5, 5.2, rim, INK, 2.5)
    elif arch == 1:
        # Ref #2: Explorer Sun / Safari Hat (Tan dome + slate hatband + wide curved brim)
        dome = (158, 132, 102, 255)
        band = (86, 92, 98, 255)
        brim = (142, 114, 86, 255)
        c.fill_ellipse(hx, hy - 14.5, 21.0, 13.0, dome, INK, 2.6)
        c.fill_round_rect(hx - 20.0, hy - 15.0, 40.0, 6.0, 2.0, band, INK, 2.0)
        c.fill_ellipse(hx + 1.0, hy - 8.5, 31.0, 6.0, brim, INK, 2.6)
    elif arch == 2:
        # Ref #3: Cowboy / Outback Hat (Dark chocolate crown + brown band + star + upturned brim)
        crown = (75, 53, 40, 255)
        band = (126, 78, 48, 255)
        brim = (62, 43, 32, 255)
        star = (212, 150, 82, 255)
        c.fill_round_rect(hx - 17.0, hy - 28.0, 34.0, 19.0, 7.0, crown, INK, 2.6)
        c.fill_round_rect(hx - 17.0, hy - 16.5, 34.0, 6.0, 2.0, band, INK, 1.9)
        c.fill_circle(hx + 4.0, hy - 13.5, 3.0, star, INK, 1.4)
        # Sculpted curved cowboy brim
        c.fill_polygon(
            [(hx - 30, hy - 14), (hx - 26, hy - 18), (hx - 15, hy - 11),
             (hx + 16, hy - 11), (hx + 27, hy - 18), (hx + 31, hy - 14),
             (hx + 24, hy - 6), (hx - 23, hy - 6)],
            brim, INK, 2.6
        )
    elif arch == 3:
        # Military Beret + Gold Badge
        beret = (166, 40, 44, 255)
        band = (36, 32, 34, 255)
        c.fill_ellipse(hx - 2.0, hy - 15.0, 25.0, 10.5, beret, INK, 2.6)
        c.fill_round_rect(hx - 21.0, hy - 11.5, 42.0, 5.5, 2.0, band, INK, 2.0)
        c.fill_circle(hx + 9.0, hy - 14.5, 3.5, (242, 196, 62, 255), INK, 1.5)
    elif arch == 4:
        # Spec-Ops Helmet + NVG Mount
        c.fill_ellipse(hx, hy - 12.0, 24.0, 14.0, (54, 62, 74, 255), INK, 2.6)
        c.fill_round_rect(hx + 11.0, hy - 20.0, 11.0, 8.0, 2.5, (86, 96, 110, 255), INK, 2.0)
        c.fill_circle(hx + 20.0, hy - 16.0, 3.2, (60, 248, 155, 255), INK, 1.5)
    elif arch == 5:
        # Enforcer Heavy Riot Helmet + Clear Shield
        c.fill_ellipse(hx, hy - 11.0, 26.0, 16.0, (66, 82, 112, 255), INK, 2.7)
        c.fill_round_rect(hx + 2.0, hy - 10.0, 20.0, 13.0, 4.0, (120, 210, 240, 195), INK, 2.2)
    elif arch == 6:
        # Urban Rebel Hood / Scarf Wrap
        c.fill_ellipse(hx - 2.0, hy - 11.0, 24.0, 15.0, (132, 62, 52, 255), INK, 2.6)
        c.fill_round_rect(hx - 6.0, hy + 4.0, 26.0, 13.0, 5.0, (166, 48, 42, 255), INK, 2.2)
    elif arch == 7:
        # Scout Baseball Cap + Headset
        c.fill_ellipse(hx - 1.0, hy - 13.0, 22.0, 11.5, (218, 102, 42, 255), INK, 2.6)
        c.fill_round_rect(hx + 4.0, hy - 9.5, 24.0, 6.0, 2.5, (186, 76, 30, 255), INK, 2.2)
        c.fill_circle(hx - 12.0, hy + 2.0, 5.5, (64, 70, 82, 255), INK, 2.0)
    elif arch == 8:
        # Cyborg Head Crest & Glow Optic Fin
        c.fill_round_rect(hx - 10.0, hy - 23.0, 24.0, 10.0, 4.0, (132, 146, 166, 255), INK, 2.4)
        c.fill_round_rect(hx + 2.0, hy - 21.0, 8.0, 5.0, 2.0, (45, 242, 255, 255))
    else:
        # Heavy Breacher Helmet + Golden Armored Visor
        c.fill_circle(hx, hy - 2.0, 24.5, (92, 112, 138, 255), INK, 2.7)
        c.fill_round_rect(hx + 1.0, hy - 10.0, 22.0, 14.0, 4.5, (40, 46, 56, 255), INK, 2.2)
        c.fill_round_rect(hx + 5.0, hy - 7.0, 14.0, 8.0, 2.5, (248, 198, 64, 255), INK, 1.6)
    return c


def _draw_archetype_hands(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    hand_col = (165, 180, 198, 255) if arch == 8 else ((64, 72, 86, 255) if arch in (4, 5, 9) else (246, 190, 160, 255))
    if p["dead"]:
        c.fill_circle(54, 80, 5.5, hand_col, INK, 2.3)
        return c

    ty = p["ty"]
    r_h = 5.4 if arch in (5, 9) else 4.8
    if p["firing"]:
        # Forward extended braced weapon grip pose
        c.fill_circle(38, ty + 14, r_h, hand_col, INK, 2.4)
        c.fill_circle(65, ty + 11, r_h, hand_col, INK, 2.4)
    else:
        c.fill_circle(31, ty + 15, r_h, hand_col, INK, 2.4)
        c.fill_circle(64, ty + 15, r_h, hand_col, INK, 2.4)
    return c


def _draw_archetype_accessories(arch: int, f: int) -> Canvas:
    c = Canvas(SPRITE_SIZE, SPRITE_SIZE)
    p = _pose_metrics(f)
    pack_br = (118, 72, 42, 255)
    roll_br = (84, 48, 28, 255)
    holster_br = (116, 62, 34, 255)
    steel = (120, 128, 140, 255)

    if p["dead"]:
        c.fill_round_rect(14, 65, 24, 15, 5, steel, INK, 2.4)
        return c

    ty = p["ty"]
    if p["jet"]:
        c.fill_triangle((22, ty + 18), (34, ty + 18), (26, 90), (255, 130, 24, 255), INK, 1.8)
        c.fill_triangle((24, ty + 18), (32, ty + 18), (27, 83), (255, 242, 150, 255))

    if arch == 1:
        # Ref #2 Explorer: Big Backpack + Rolled Sleeping Bag on Back!
        c.fill_round_rect(18, ty - 2, 18, 24, 6, pack_br, INK, 2.6)
        c.fill_round_rect(19, ty - 8, 16, 9, 4, roll_br, INK, 2.4)
        c.fill_round_rect(19, ty + 10, 14, 10, 3, roll_br, INK, 2.0)
    elif arch == 2:
        # Ref #3 Outlaw: Side Gun Holster hanging on Hip
        c.fill_round_rect(28, ty + 16, 11, 14, 3.5, holster_br, INK, 2.4)
        c.fill_round_rect(20, ty + 2, 12, 16, 4, steel, INK, 2.2)
    elif arch == 6:
        # Rebel diagonal brass bullet bandolier
        c.fill_round_rect(20, ty + 1, 13, 18, 5, steel, INK, 2.3)
        c.fill_capsule(35, ty + 2, 57, ty + 16, 3.2, holster_br, INK, 1.8)
        for bx, by in [(40, ty + 6), (46, ty + 10), (52, ty + 13)]:
            c.fill_round_rect(bx, by, 4, 5, 1, (242, 198, 66, 255), INK, 1.2)
    elif arch in (5, 9):
        # Heavy Shoulder Guards + Jetpack Pack
        c.fill_round_rect(19, ty + 1, 14, 19, 5, steel, INK, 2.4)
        c.fill_round_rect(26, ty - 4, 13, 10, 3.5, steel, INK, 2.2)
        c.fill_round_rect(57, ty - 4, 13, 10, 3.5, steel, INK, 2.2)
    else:
        # Compact tactical jetpack / field pack behind torso
        c.fill_round_rect(20, ty + 1, 13, 19, 5, steel, INK, 2.4)
    return c


def build_modular_character_assets() -> None:
    for arch in range(10):
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

        s_skin.save(f"assets/sprites/modular/skin_{arch}.png")
        s_legs.save(f"assets/sprites/modular/legs_{arch}.png")
        s_torso.save(f"assets/sprites/modular/torso_{arch}.png")
        s_head.save(f"assets/sprites/modular/head_{arch}.png")
        s_hands.save(f"assets/sprites/modular/hands_{arch}.png")
        s_acc.save(f"assets/sprites/modular/accessories_{arch}.png")


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
    print("Generated 60 modular character PNGs, 11x3 weapons sheet, and real-world audio WAVs.")
