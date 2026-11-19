#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP_BUNDLE="$ROOT_DIR/build/Calculator.app"

echo "==> Building CalculatorMac ($CONFIG) natively for macOS ($(uname -m))..."
cd "$ROOT_DIR"
swift build --disable-sandbox -c "$CONFIG" --product CalculatorMac

BIN_DIR="$(swift build --disable-sandbox -c "$CONFIG" --show-bin-path)"
BINARY_PATH="$BIN_DIR/CalculatorMac"
RESOURCE_BUNDLE="$BIN_DIR/WindowsCalculatorMac_CalculatorCore.bundle"

echo "==> Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/CalculatorMac"
chmod +x "$APP_BUNDLE/Contents/MacOS/CalculatorMac"

if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Generate native macOS .icns directly (no external tools required, works in sandboxed builds)
if command -v python3 >/dev/null 2>&1; then
    python3 - "$APP_BUNDLE/Contents/Resources/AppIcon.icns" << 'PYEOF'
import sys, struct, zlib

def make_png(size):
    w = h = size
    rows = []
    pad_x = int(w * 0.14)
    pad_y = int(h * 0.08)
    bw = w - 2 * pad_x
    bh = h - 2 * pad_y
    rad = max(2, int(w * 0.10))

    lcd_x0 = pad_x + int(bw * 0.10)
    lcd_x1 = pad_x + int(bw * 0.90)
    lcd_y0 = pad_y + int(bh * 0.09)
    lcd_y1 = pad_y + int(bh * 0.32)

    grid_y0 = pad_y + int(bh * 0.39)
    grid_y1 = pad_y + int(bh * 0.91)
    gap = max(1, int(bw * 0.05))
    cell_w = max(1, (lcd_x1 - lcd_x0 - 2 * gap) // 3)
    cell_h = max(1, (grid_y1 - grid_y0 - 2 * gap) // 3)

    def in_round_rect(x, y, x0, y0, x1, y1, r):
        if x < x0 or x >= x1 or y < y0 or y >= y1:
            return False
        cx = max(x0 + r, min(x, x1 - r - 1))
        cy = max(y0 + r, min(y, y1 - r - 1))
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            if not in_round_rect(x, y, pad_x, pad_y, pad_x + bw, pad_y + bh, rad):
                row.extend((0, 0, 0, 0))
                continue
            t = (y - pad_y) / max(1, bh)
            r = int(184 * (1 - t) + 122 * t)
            g = int(194 * (1 - t) + 134 * t)
            b = int(204 * (1 - t) + 148 * t)
            if in_round_rect(x, y, lcd_x0, lcd_y0, lcd_x1, lcd_y1, max(1, rad // 3)):
                r, g, b = 30, 41, 59
            elif grid_y0 <= y < grid_y1 and lcd_x0 <= x < lcd_x1:
                rx = x - lcd_x0
                ry = y - grid_y0
                col = rx // (cell_w + gap)
                row_i = ry // (cell_h + gap)
                lx = rx % (cell_w + gap)
                ly = ry % (cell_h + gap)
                if col < 3 and row_i < 3 and lx < cell_w and ly < cell_h:
                    if col == 2 and row_i == 2:
                        r, g, b = 41, 169, 255
                    else:
                        r, g, b = 245, 247, 250
            row.extend((r, g, b, 255))
        rows.append(bytes(row))

    raw = b"".join(rows)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")

icns_chunks = []
for ostype, sz in [(b"icp4", 16), (b"icp5", 32), (b"icp6", 64), (b"ic07", 128), (b"ic08", 256), (b"ic09", 512)]:
    png_data = make_png(sz)
    icns_chunks.append(ostype + struct.pack(">I", 8 + len(png_data)) + png_data)

body = b"".join(icns_chunks)
with open(sys.argv[1], "wb") as f:
    f.write(b"icns" + struct.pack(">I", 8 + len(body)) + body)
PYEOF
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CalculatorMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.microsoft.calculator.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Calculator</string>
    <key>CFBundleDisplayName</key>
    <string>Calculator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>11.2607.0</string>
    <key>CFBundleVersion</key>
    <string>11.2607.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc code sign for local macOS execution
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
fi

echo "==> Successfully built native macOS app: $APP_BUNDLE"
