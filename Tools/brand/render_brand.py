#!/usr/bin/env python3
"""Renders SwingPal's brand artwork from the hole-mark geometry.

The same numbers drive `HoleMark` in SwingPal/SwingPalLaunchLogo.swift, so the
Home Screen icon, the launch screen and the in-app mark stay one drawing.

    python3 Tools/brand/render_brand.py          # from the repo root

Needs Python 3 with Pillow and Playwright (Chromium) for SVG rasterising.
Writes:
  SwingPal/Assets.xcassets/AppIcon.appiconset        light, dark and tinted 1024 px icons
  SwingPal/Assets.xcassets/LaunchMark.imageset       200 pt launch mark, day and night
  SwingPalWatch Watch App/Assets.xcassets             watch icon
"""
import io, json, math, os, sys
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# ---- geometry (mirrors HoleMark in Swift) ----
# Centreline of the S-hole, tee (bottom-left) to green (top-right), in a 1024 box.
SEGS = [((292,792),(470,872),(716,812),(700,664)),
        ((700,664),(686,540),(360,528),(344,392)),
        ((344,392),(330,262),(520,214),(640,262))]
def bez(p0,p1,p2,p3,t):
    u=1-t
    return (u**3*p0[0]+3*u*u*t*p1[0]+3*u*t*t*p2[0]+t**3*p3[0], u**3*p0[1]+3*u*u*t*p1[1]+3*u*t*t*p2[1]+t**3*p3[1])
def samples(n=240):
    pts=[]
    for i,s in enumerate(SEGS):
        for k in range(n):
            if i>0 and k==0: continue
            pts.append(bez(*s,k/(n-1)))
    # arc-length param
    L=[0]
    for a,b in zip(pts,pts[1:]): L.append(L[-1]+math.dist(a,b))
    return pts,[l/L[-1] for l in L]
KEYS=[(0,40),(0.2,62),(0.5,80),(0.78,58),(0.93,44),(1.0,52)]
def width(t):
    for (t0,w0),(t1,w1) in zip(KEYS,KEYS[1:]):
        if t<=t1:
            f=(t-t0)/(t1-t0); f=(1-math.cos(math.pi*f))/2
            return w0+(w1-w0)*f
    return KEYS[-1][1]
def outline(scale=1.0, grow=0.0):
    pts,ts=samples()
    L=[];R=[]
    for i,(p,t) in enumerate(zip(pts,ts)):
        a=pts[max(i-1,0)]; b=pts[min(i+1,len(pts)-1)]
        dx,dy=b[0]-a[0],b[1]-a[1]; d=math.hypot(dx,dy) or 1
        nx,ny=-dy/d,dx/d
        w=(width(t)+grow)*scale
        L.append((p[0]+nx*w,p[1]+ny*w)); R.append((p[0]-nx*w,p[1]-ny*w))
    ring=L+R[::-1]
    p0=pts[0]; r0=(width(0)+grow)*scale
    return 'M '+' L '.join(f'{x:.1f} {y:.1f}' for x,y in ring)+f' Z M {p0[0]-r0:.1f} {p0[1]:.1f} a {r0:.1f} {r0:.1f} 0 1 0 {2*r0:.1f} 0 a {r0:.1f} {r0:.1f} 0 1 0 {-2*r0:.1f} 0 Z'

# ---- drawing ----

DAY   = dict(bg='#1E3B2F', bg2='#1A3429', paper='#F2EFE6', fair='#C9D8AA', fairEdge='#8BAA73', green='#A3CA8B', contour='#5F9150', flag='#D4462A', pin='#17261F', tee='#F2EFE6', arc='#F2EFE6', arcOp=0.16, sand='#EDE0BA', sandDot='#B89C5C', stripe=0.18)
NIGHT = dict(DAY, bg='#0F1714', bg2='#0B120F', arcOp=0.14, flag='#FF7452')
TINT  = dict(bg='#000000', bg2='#000000', paper='#FFFFFF', fair='#BDBDBD', fairEdge='#8A8A8A', green='#E2E2E2', contour='#9A9A9A', flag='#FFFFFF', pin='#000000', tee='#FFFFFF', arc='#FFFFFF', arcOp=0.14, sand='#D6D6D6', sandDot='#8A8A8A', stripe=0.12)

GX, GY = 686, 282   # green centre
TX, TY = 208, 754   # tee block

def mark(c, arcs=True, bg=True, detail=True):
    fair = outline(); edge = outline(grow=7)
    bands = ''.join(f"<rect x='{-700+i*60}' y='-300' width='30' height='1700' fill='#ffffff' opacity='{c['stripe']}' transform='rotate(-40 512 512)'/>" for i in range(46))
    arc = ''
    if arcs:
        arc = ''.join(f"<circle cx='{GX}' cy='{GY}' r='{r}' fill='none' stroke='{c['arc']}' stroke-opacity='{c['arcOp']}' stroke-width='6'/>" for r in (250, 420, 590))
    contours = ''.join(f"<ellipse cx='{GX+6}' cy='{GY+6}' rx='{rx}' ry='{rx*0.84:.0f}' fill='none' stroke='{c['contour']}' stroke-opacity='0.5' stroke-width='5'/>" for rx in (70, 46, 22)) if detail else ''
    dots = ''.join(f"<circle cx='{x}' cy='{y}' r='4.5' fill='{c['sandDot']}'/>" for x,y in [(516,300),(540,318),(562,298),(530,336),(556,344),(584,322),(548,284)]) if detail else ''
    bunker = f"<path d='M 500 300 C 510 262, 580 256, 600 290 C 612 318, 590 356, 552 352 C 520 350, 494 330, 500 300 Z' fill='{c['sand']}'/>{dots}"
    back = f"<rect width='1024' height='1024' fill='{c['bg']}'/>" if bg else ''
    return f"""<defs><clipPath id='fwc'><path d='{fair}' fill-rule='nonzero'/></clipPath></defs>
{back}
{arc}
<path d='{edge}' fill='{c['fairEdge']}'/>
<path d='{fair}' fill='{c['fair']}'/>
<g clip-path='url(#fwc)'>{bands}</g>
<ellipse cx='{GX}' cy='{GY}' rx='112' ry='96' fill='{c['fairEdge']}'/>
<ellipse cx='{GX}' cy='{GY}' rx='104' ry='88' fill='{c['green']}'/>
{contours}
<rect x='{TX-38}' y='{TY-22}' width='76' height='44' rx='9' fill='{c['tee']}' transform='rotate(24 {TX} {TY})'/>
<line x1='{GX}' y1='{GY}' x2='{GX}' y2='{GY-162}' stroke='{c['paper']}' stroke-width='13' stroke-linecap='round'/>
<path d='M {GX+5} {GY-166} L {GX+128} {GY-128} L {GX+5} {GY-90} Z' fill='{c['flag']}'/>
<circle cx='{GX}' cy='{GY}' r='12' fill='{c['pin']}'/>"""

def icon(c, size=1024, **kw):
    return f"<svg xmlns='http://www.w3.org/2000/svg' width='{size}' height='{size}' viewBox='0 0 1024 1024'><g transform='translate(512 512) scale(0.94) translate(-500 -488)'>{mark(c, **kw)}</g></svg>".replace("<rect width='1024' height='1024'", "<rect x='-200' y='-200' width='1424' height='1424'")

PAGE_DAY   = dict(DAY, bg='#F2EFE6', arc='#596159', arcOp=0.30, paper='#17261F', tee='#1E3B2F', fair='#B9CE92', fairEdge='#6F9160', green='#8FBF74', contour='#4F7F44', pin='#17261F', stripe=0.22)
PAGE_NIGHT = dict(DAY, bg='#101714', arc='#A4AAA0', arcOp=0.26, paper='#ECE7DA', tee='#CFE3C4', fair='#3F6243', fairEdge='#6C9867', green='#5A8C52', contour='#9CC98C', pin='#101714', flag='#FF7452', stripe=0.07)

def page(c, size=1024, arcs=True):
    fade = "<defs><radialGradient id='fade' cx='0.5' cy='0.5' r='0.5'><stop offset='0.55' stop-color='white' stop-opacity='1'/><stop offset='1' stop-color='white' stop-opacity='0'/></radialGradient><mask id='fm'><rect width='1024' height='1024' fill='url(#fade)'/></mask></defs>"
    inner = mark(c, arcs=False, bg=False)
    arc = ''.join(f"<circle cx='{GX}' cy='{GY}' r='{r}' fill='none' stroke='{c['arc']}' stroke-opacity='{c['arcOp']}' stroke-width='5'/>" for r in (250, 420, 590)) if arcs else ''
    T = "translate(512 512) scale(0.94) translate(-500 -488)"
    return f"<svg xmlns='http://www.w3.org/2000/svg' width='{size}' height='{size}' viewBox='0 0 1024 1024'>{fade}<g mask='url(#fm)'><g transform='{T}'>{arc}</g></g><g transform='{T}'>{inner}</g></svg>"


def raster(jobs):
    """jobs: (svg, px, transparent) -> list of PIL images"""
    out = []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(device_scale_factor=1)
        for svg, px, transparent in jobs:
            page.set_viewport_size({"width": px, "height": px})
            page.set_content(f"<html><body style='margin:0;background:transparent'>{svg}</body></html>")
            png = page.screenshot(omit_background=transparent, clip={"x": 0, "y": 0, "width": px, "height": px})
            out.append(Image.open(io.BytesIO(png)))
        browser.close()
    return out

def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')

def save(img, path, rgb):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert('RGB') if rgb else img.convert('RGBA')).save(path, optimize=True)

def main():
    info = {"author": "xcode", "version": 1}
    light, dark, tinted, watch = raster([(icon(DAY), 1024, False), (icon(NIGHT), 1024, False),
                                         (icon(TINT), 1024, False), (icon(DAY, arcs=True), 1024, False)])
    tinted = tinted.convert('L')
    icons = os.path.join(ROOT, 'SwingPal/Assets.xcassets/AppIcon.appiconset')
    save(light, os.path.join(icons, 'AppIcon.png'), True)
    save(dark, os.path.join(icons, 'AppIcon-Dark.png'), True)
    save(tinted, os.path.join(icons, 'AppIcon-Tinted.png'), True)
    write_json(os.path.join(icons, 'Contents.json'), {"images": [
        {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-Dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-Tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
    ], "info": info})

    launch = os.path.join(ROOT, 'SwingPal/Assets.xcassets/LaunchMark.imageset')
    renders = raster([(page(c, size=px), px, True) for c in (PAGE_DAY, PAGE_NIGHT) for px in (200, 400, 600)])
    images = []
    for i, (name, appearance) in enumerate([('LaunchMark', None), ('LaunchMark-Dark', 'dark')]):
        for j, scale in enumerate((1, 2, 3)):
            filename = f'{name}@{scale}x.png'
            save(renders[i * 3 + j], os.path.join(launch, filename), False)
            entry = {"filename": filename, "idiom": "universal", "scale": f"{scale}x"}
            if appearance:
                entry = {"appearances": [{"appearance": "luminosity", "value": appearance}], **entry}
            images.append(entry)
    write_json(os.path.join(launch, 'Contents.json'), {"images": images, "info": info})

    watch_assets = os.path.join(ROOT, 'SwingPalWatch Watch App/Assets.xcassets')
    write_json(os.path.join(watch_assets, 'Contents.json'), {"info": info})
    save(watch, os.path.join(watch_assets, 'AppIcon.appiconset/AppIcon.png'), True)
    write_json(os.path.join(watch_assets, 'AppIcon.appiconset/Contents.json'), {"images": [
        {"filename": "AppIcon.png", "idiom": "universal", "platform": "watchos", "size": "1024x1024"}
    ], "info": info})
    print('brand artwork written')

if __name__ == '__main__':
    main()
