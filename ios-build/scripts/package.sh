#!/usr/bin/env bash
set -euo pipefail

echo "[package] Create artifacts (tar.gz and .deb)"

: "${IOS_PREFIX:?IOS_PREFIX missing}"

BUILD_DIR="$IOS_PREFIX/bin"
OUT_DIR=ffmpeg-ios-arm64
DEB_ROOT=ffmpeg-ios-deb

for bin in ffmpeg ffprobe; do
  test -f "$BUILD_DIR/$bin" || { echo "missing $BUILD_DIR/$bin"; exit 1; }
done

# Check if ffplay exists (optional)
if [ ! -f "$BUILD_DIR/ffplay" ]; then
  echo "Warning: ffplay not found, continuing without it"
fi

rm -rf "$OUT_DIR" "$DEB_ROOT" *.tar.gz *.deb
mkdir -p "$OUT_DIR"

cp "$BUILD_DIR/ffmpeg" "$OUT_DIR/"
if [ -f "$BUILD_DIR/ffplay" ]; then
  cp "$BUILD_DIR/ffplay" "$OUT_DIR/"
fi
cp "$BUILD_DIR/ffprobe" "$OUT_DIR/"

cat > "$OUT_DIR/install.sh" <<'EOS'
#!/bin/bash
set -e
if [ ! -d "/var/jb" ]; then
  echo "This package requires a jailbroken iOS device with /var/jb bootstrap" >&2
  exit 1
fi
mkdir -p /var/jb/usr/bin /var/jb/usr/share/man/man1
cp ffmpeg ffprobe /var/jb/usr/bin/
if [ -f ffplay ]; then
  cp ffplay /var/jb/usr/bin/
fi
chmod 755 /var/jb/usr/bin/ffmpeg /var/jb/usr/bin/ffprobe
if [ -f /var/jb/usr/bin/ffplay ]; then
  chmod 755 /var/jb/usr/bin/ffplay
fi
echo "FFmpeg installed to /var/jb/usr/bin"
EOS
chmod +x "$OUT_DIR/install.sh"

cat > "$OUT_DIR/README.md" <<'EOS'
# FFmpeg for iOS ARM64 (Jailbroken)

用法：
- 手动安装：解压后在设备上执行 ./install.sh
- DEB 安装：安装 .deb 包（推荐）

建议使用 ldid 为二进制签名：
ldid -S /var/jb/usr/bin/ffmpeg
ldid -S /var/jb/usr/bin/ffplay
ldid -S /var/jb/usr/bin/ffprobe
EOS

tar -czf ffmpeg-8.0-ios-arm64.tar.gz "$OUT_DIR"/

mkdir -p "$DEB_ROOT/DEBIAN" "$DEB_ROOT/var/jb/usr/bin"
cp "$BUILD_DIR/ffmpeg" "$DEB_ROOT/var/jb/usr/bin/"
if [ -f "$BUILD_DIR/ffplay" ]; then
  cp "$BUILD_DIR/ffplay" "$DEB_ROOT/var/jb/usr/bin/"
fi
cp "$BUILD_DIR/ffprobe" "$DEB_ROOT/var/jb/usr/bin/"

cat > "$DEB_ROOT/DEBIAN/control" <<'EOF'
Package: com.ffmpeg.ios
Name: FFmpeg 8.0
Version: 8.0-1
Architecture: iphoneos-arm64
Description: Complete FFmpeg 8.0 suite with codec support for jailbroken iOS
Homepage: https://github.com/RhineLT/FFmpeg
Maintainer: RhineLT
Section: Multimedia
Depends: firmware (>= 12.0)
EOF

cat > "$DEB_ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/bash
chmod 755 /var/jb/usr/bin/ffmpeg /var/jb/usr/bin/ffplay /var/jb/usr/bin/ffprobe
if command -v ldid >/dev/null 2>&1; then
  ldid -S /var/jb/usr/bin/ffmpeg || true
  ldid -S /var/jb/usr/bin/ffplay || true
  ldid -S /var/jb/usr/bin/ffprobe || true
fi
echo "FFmpeg 8.0 installed"
EOF
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

dpkg-deb --build "$DEB_ROOT" ffmpeg-8.0-ios-arm64.deb

echo "[package] Artifacts: ffmpeg-8.0-ios-arm64.tar.gz, ffmpeg-8.0-ios-arm64.deb"
