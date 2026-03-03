#!/bin/bash
# Generate a simple app icon using macOS built-in tools
set -e

ICONSET="AppIcon.iconset"
rm -rf "$ICONSET" AppIcon.icns

mkdir "$ICONSET"

# Create a simple sync icon using Python + Core Graphics
python3 -c "
import subprocess, tempfile, os

# Create SVG
svg = '''<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\">
  <defs>
    <linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">
      <stop offset=\"0%\" stop-color=\"#6366f1\"/>
      <stop offset=\"100%\" stop-color=\"#818cf8\"/>
    </linearGradient>
  </defs>
  <rect width=\"512\" height=\"512\" rx=\"100\" fill=\"url(#bg)\"/>
  <g transform=\"translate(256,256)\" fill=\"none\" stroke=\"white\" stroke-width=\"32\" stroke-linecap=\"round\">
    <path d=\"M-80,-60 L80,-60\" stroke-width=\"36\"/>
    <path d=\"M40,-90 L80,-60 L40,-30\"/>
    <path d=\"M80,60 L-80,60\" stroke-width=\"36\"/>
    <path d=\"M-40,30 L-80,60 L-40,90\"/>
  </g>
</svg>'''

# Write SVG
with open('/tmp/teamsync_icon.svg', 'w') as f:
    f.write(svg)

# Use qlmanage or sips to convert
sizes = [16, 32, 64, 128, 256, 512]
for s in sizes:
    # Render using sips from a large PNG
    pass

print('SVG written to /tmp/teamsync_icon.svg')
"

# Generate PNGs from SVG using built-in tools
# Use python3 with Pillow if available, otherwise use a simpler approach
python3 -c "
import struct, zlib, os

def create_png(width, height, color_func):
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', zlib.crc32(chunk) & 0xFFFFFFFF)

    # IHDR
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)

    # IDAT
    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter none
        for x in range(width):
            r, g, b, a = color_func(x, y, width, height)
            raw += struct.pack('BBBB', r, g, b, a)

    idat = zlib.compress(raw)

    png = b'\x89PNG\r\n\x1a\n'
    png += make_chunk(b'IHDR', ihdr)
    png += make_chunk(b'IDAT', idat)
    png += make_chunk(b'IEND', b'')
    return png

def icon_color(x, y, w, h):
    # Rounded rect with gradient
    cx, cy = w/2, h/2
    rx, ry = abs(x - cx)/(w/2), abs(y - cy)/(h/2)

    # Rounded corners
    corner_r = 0.2
    in_rect = True
    if rx > 1 - corner_r and ry > 1 - corner_r:
        dx = rx - (1 - corner_r)
        dy = ry - (1 - corner_r)
        if (dx*dx + dy*dy) > corner_r*corner_r:
            in_rect = False

    if not in_rect or rx > 1 or ry > 1:
        return (0, 0, 0, 0)

    # Gradient background
    t = (x + y) / (w + h)
    r = int(99 + (129-99)*t)
    g = int(102 + (140-102)*t)
    b = int(241 + (248-241)*t)

    # Draw arrows
    ny, nx = (y - cy) / (h * 0.35), (x - cx) / (w * 0.35)

    # Top arrow (right pointing): line at ny ~ -0.35
    if abs(ny + 0.35) < 0.09 and -0.5 < nx < 0.5:
        return (255, 255, 255, 240)
    # Arrow head top
    if 0.2 < nx < 0.55 and abs(ny + 0.35 - (nx - 0.38)*0.7) < 0.07:
        return (255, 255, 255, 240)
    if 0.2 < nx < 0.55 and abs(ny + 0.35 + (nx - 0.38)*0.7) < 0.07:
        return (255, 255, 255, 240)

    # Bottom arrow (left pointing): line at ny ~ 0.35
    if abs(ny - 0.35) < 0.09 and -0.5 < nx < 0.5:
        return (255, 255, 255, 240)
    # Arrow head bottom
    if -0.55 < nx < -0.2 and abs(ny - 0.35 - (nx + 0.38)*(-0.7)) < 0.07:
        return (255, 255, 255, 240)
    if -0.55 < nx < -0.2 and abs(ny - 0.35 + (nx + 0.38)*(-0.7)) < 0.07:
        return (255, 255, 255, 240)

    return (r, g, b, 255)

sizes = {
    'icon_16x16.png': 16,
    'icon_16x16@2x.png': 32,
    'icon_32x32.png': 32,
    'icon_32x32@2x.png': 64,
    'icon_128x128.png': 128,
    'icon_128x128@2x.png': 256,
    'icon_256x256.png': 256,
    'icon_256x256@2x.png': 512,
    'icon_512x512.png': 512,
    'icon_512x512@2x.png': 1024,
}

iconset = 'AppIcon.iconset'
for name, size in sizes.items():
    png = create_png(size, size, icon_color)
    with open(os.path.join(iconset, name), 'wb') as f:
        f.write(png)
    print(f'  {name} ({size}x{size})')

print('PNGs generated')
"

# Convert iconset to icns
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"
echo "AppIcon.icns created"
